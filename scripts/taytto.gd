extends RefCounted
## Maiseman täytetalojen valinta (Saloinen world.gd ja Vaala vaala.gd): tyyppi K1–K5 (scripts/rakennukset.gd),
## värit ja mitat nimettömän rakennuksen pohjasta, tyypistä ja ympäristöstä. Yhteinen rekisteri molemmille kylille;
## kutsuja antaa rakennuksesta siemennetyn rng:n (Saloinen hash(b.c), Vaala id), joten valinta ei riipu
## rakennusjärjestyksestä eikä world._rng:stä.
##
## keep_old(b) -> bool: pohja jää vanhaksi malliksi (koulu, kirkko, hotelli ym. KEEP_T, lv >= 4, L- tai U-muoto
##   r < 0,75 ja ala >= 260 m²). Kutsuja (world.gd, vaala.gd) tarkistaa tämän ennen plan()ia; plan() itse ei jätä
##   pohjaa tyhjäksi, vaan täyttää sen taulun seuraavan rivin mukaan.
## classify(alue, b, ctx) -> String: tyypitystaulu (02-arkkitehtuuri.md Korjaus 2): "VANHA", "K1"–"K5", "K3_ranta",
##   "K6", "K7", "K7_liike", "K8_kone", "K8_teollisuus", "K8_liike", "K8_suoja", "JAKO" (enintään 3 taloa) tai "TALO"
##   (K1/K2/K5 arvotaan painoilla).
## plan(alue, b, ctx, rng) -> Array[Dictionary]: yksi talo pohjaan; JAKO: 1–3 taloa pitkää akselia pitkin (väli
##   vähintään 5 m, talo vähintään 9 m:n tontilla). Jokainen alkio on pick()-tulos; isoissa (K6–K8) lisäksi v, n, krs.
##   Talon kehys pohjan kehyksessä: local_xf(o) = Transform3D(Basis(UP, rot), Vector3(dx, 0, dz)).
## pick(alue, b, ctx, rng) -> {tyyppi, l, d, wall, roof, trim, flat, carport, rima, gate_gap, seed, rot, dx, dz, piha, v, krs, n}
##   alue: "saloinen" tai "vaala".
##   b: {l (pitkä sivu, m), d (lyhyt sivu, m), t (OSM building-tyyppi tai Vaalan kind, "" = tuntematon), lv (kerroksia),
##      r (monikulmion ala / suunnatun laatikon ala; puuttuu = 1)}.
##      Pohjan pitkä sivu on paikallisella X:llä ja julkisivu -Z:ssä (world.gd _osm_fit).
##   ctx: {pelto: bool (pellon laidassa), ranta: bool (rantamökki, julkisivu rantaan), gap: float (etupiha tielle,
##        -1 = ei tietä)}; puuttuvat avaimet = false / -1.
##   Tulos sovitetaan pohjan sisään: l ja d ovat mallin mitat kehyksessä, joka on kierretty rot verran
##   (xf * local_xf(o); rot = PI/2 K3/K4:lle, jotta harja on pohjan pitkän akselin suuntainen, jaetuissa pohjissa
##   heitto ±2–4°). dx siirtää taloa pohjan pitkää akselia pitkin (autokatos pohjan sisällä, tontit), dz syvyyssuunnassa
##   (-dz = julkisivua kohti). piha = true: pohjaan jää pihaa, kutsuja tekee piharakennuksen.
##   carport ja gate_gap ovat toiveita: kutsuja nollaa ne, jos katos tai aita osuisi tiehen tai toiseen pohjaan.

const TYPES := ["K1", "K2", "K3", "K4", "K5", "K6", "K7", "K8"]
## Jakaumat (01-suunnitelma.md "Täytön säännöt"; K5 2–5 % myös Saloisiin ja Vaalaan, 00-ohjeet.md). Painot valitaan
## kelvollisten tyyppien joukosta: K3 ja K4 tulevat pääosin pohjan koosta ja ympäristöstä, painot jakavat päätalot.
const DIST := {
	"saloinen": {"K1": 40.0, "K2": 40.0, "K3": 12.0, "K4": 6.0, "K5": 3.0},  # K5 3,0 -> 3–4 % (mitattu, 03-toteutus-E.md)
	"vaala": {"K1": 35.0, "K2": 30.0, "K3": 20.0, "K4": 10.0, "K5": 1.5},  # K5 1,5 -> noin 3–4 % (dump-mittaus ennen G:tä, pieni otos)
}
## Mittavälit [l_min, l_max, d_min, d_max] (m); K3/K4: l = päädyn leveys, d = harjan suuntainen pituus.
const SIZES := {
	"K1": [8.0, 10.5, 8.6, 10.5],  # runko 8–10,5 x 7–9 + porstua (enimmäisala 108 m² + porstua, 01-esikuvat r. 15)
	"K2": [10.0, 16.0, 8.0, 10.5],
	"K3": [2.8, 4.0, 3.6, 4.8],
	"K3_ranta": [4.0, 5.0, 5.0, 6.0],  # rantamökki tai sauna = suurennettu aitta (avoin kohta 4)
	"K4": [5.0, 7.0, 7.0, 9.0],
	"K5": [10.0, 13.0, 6.6, 8.0],
}
## Värit [väri, paino]; katot ja listat omissa taulukoissaan. Esikuvat 01-esikuvat.md (K1 Imatran ohjeen kuvat,
## K2 Yle 70–80-luvun tiilitalo, K3/K4 Paltamon kaava, K5 Wanha Raahe).
const WHITE := Color(0.95, 0.95, 0.92)
const K1_WALLS := [[Color(0.9, 0.8, 0.45), 30.0], [Color(0.86, 0.8, 0.66), 20.0], [Color(0.93, 0.93, 0.9), 20.0],
	[Color(0.72, 0.82, 0.62), 15.0], [Color(0.6, 0.15, 0.11), 15.0]]
const K1_ROOFS := [Color(0.3, 0.2, 0.15), Color(0.42, 0.16, 0.11), Color(0.3, 0.31, 0.33), Color(0.16, 0.16, 0.17)]
## K2: [väri, paino, peiterima]: vaalea peiterima, keltainen röpelötiili, punatiili, ruskea ja punamullattu peiterima.
## Vaalea on peiterima, ei tiili: sileä vaalea seinä näytti rappaukselta (04-testi-A.md K3, Teemun korjaus 2).
const K2_WALLS := [[Color(0.8, 0.74, 0.62), 30.0, true], [Color(0.84, 0.68, 0.4), 25.0, false],
	[Color(0.62, 0.27, 0.2), 15.0, false], [Color(0.42, 0.28, 0.18), 15.0, true], [Color(0.55, 0.18, 0.12), 15.0, true]]
const K2_ROOFS := [Color(0.12, 0.12, 0.13), Color(0.16, 0.16, 0.17), Color(0.25, 0.17, 0.12)]
const K2_TRIM := Color(0.28, 0.18, 0.12)  # tummanruskea puuosien tehoste
const K3_WALLS := [[Color(0.6, 0.15, 0.11), 60.0], [Color(0.55, 0.52, 0.47), 30.0], [Color(0.42, 0.3, 0.22), 10.0]]
const K3_ROOFS := [Color(0.16, 0.16, 0.17), Color(0.45, 0.46, 0.47), Color(0.42, 0.18, 0.12)]
const K4_WALLS := [[Color(0.6, 0.55, 0.46), 60.0], [Color(0.55, 0.17, 0.12), 25.0], [Color(0.46, 0.43, 0.38), 15.0]]
const K4_ROOFS := [Color(0.5, 0.28, 0.16), Color(0.55, 0.56, 0.57), Color(0.42, 0.18, 0.12)]
const K5_WALLS := [[Color(0.9, 0.76, 0.36), 40.0], [Color(0.93, 0.81, 0.47), 35.0], [Color(0.86, 0.68, 0.28), 25.0]]
const K5_ROOFS := [Color(0.2, 0.2, 0.21), Color(0.3, 0.2, 0.15), Color(0.45, 0.15, 0.1)]
const BARN_T := ["barn", "farm_auxiliary", "cowshed", "stable", "hangar"]
const INDUSTRY_T := ["industrial", "warehouse", "manufacture", "storage_tank", "service"]
const RESIDENTIAL_T := ["", "yes", "house", "detached", "residential", "semidetached_house", "terrace", "apartments",
	"farm", "talo", "house_small"]
## Isot: K6 rivitalo, K7 kerrostalo (punatiili, keltatiili, vaalea rappaus), K8 hallin variantit (Rapko: punainen,
## harmaa, tummanvihreä pelti; teollisuus vaalea pelti; liike tiili tai vaalea pelti; suoja harmaa lauta tai pelti).
const K7_WALLS := [[Color(0.62, 0.27, 0.2), 45.0], [Color(0.84, 0.68, 0.4), 25.0], [Color(0.85, 0.83, 0.77), 30.0]]
const K8_WALLS := {
	"kone": [[Color(0.6, 0.15, 0.11), 50.0], [Color(0.55, 0.56, 0.57), 30.0], [Color(0.2, 0.32, 0.22), 20.0]],
	"teollisuus": [[Color(0.74, 0.74, 0.72), 55.0], [Color(0.8, 0.72, 0.55), 45.0]],
	"liike": [[Color(0.62, 0.27, 0.2), 35.0], [Color(0.84, 0.68, 0.4), 30.0], [Color(0.8, 0.8, 0.78), 35.0]],
	"suoja": [[Color(0.55, 0.52, 0.47), 50.0], [Color(0.6, 0.15, 0.11), 30.0], [Color(0.6, 0.61, 0.62), 20.0]],
}
const DARK_GREY := Color(0.3, 0.3, 0.31)
## Vanhaksi jäävät tyypit (keep_old): koulut, julkiset ja kirkot ovat omanlaisiaan, eivät täytetyyppejä.
const KEEP_T := ["school", "kindergarten", "college", "university", "library", "hotel", "hospital", "public", "civic",
	"government", "townhall", "fire_station", "church", "chapel"]
const COMMERCE_T := ["commercial", "retail", "garages", "sports_hall", "warehouse"]
const SPLIT_AREA := 260.0  # tästä alkaen iso pohja (K6–K8 tai JAKO)
const SPLIT_MAX := 3  # jaetun pohjan talot enintään
const SPLIT_HOUSE := 9.0  # jaetun pohjan tontti vähintään (m)
const SPLIT_GAP := 5.0  # jaetun pohjan talojen väli vähintään (m)


static func local_xf(o: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, o.get("rot", 0.0)), Vector3(o.get("dx", 0.0), 0, o.get("dz", 0.0)))


static func keep_old(b: Dictionary) -> bool:
	var area: float = b.l * b.d
	return b.get("t", "") in KEEP_T or b.get("lv", 1) >= 4 or (b.get("r", 1.0) < 0.75 and area >= SPLIT_AREA)


static func classify(alue: String, b: Dictionary, ctx: Dictionary) -> String:
	if keep_old(b):
		return "VANHA"
	return _class(alue, b, ctx)


## Tyypitystaulu rivit 3–9 (ensimmäinen osuva voittaa; rivit 1–2 = kutsuja ja keep_old).
static func _class(alue: String, b: Dictionary, ctx: Dictionary) -> String:
	var l: float = b.l
	var d: float = b.d
	var t: String = b.get("t", "")
	var lv: int = b.get("lv", 1)
	var area := l * d
	var gap: float = ctx.get("gap", -1.0)
	var pelto: bool = ctx.get("pelto", false)
	if area < 45.0 or t == "cabin" or (ctx.get("ranta", false) and area < 80.0):
		pass  # rivi 3: aitta, lato, mökki ja rantamökki (_small_ok)
	elif t in BARN_T:
		if area >= 250.0:
			return "K8_kone"
	elif t in INDUSTRY_T or t in COMMERCE_T:
		if area >= 120.0:
			return "K8_liike" if t in ["commercial", "retail"] else "K8_teollisuus"
	elif (t == "apartments" and area >= 120.0) or (lv >= 2 and area >= 300.0) or (lv >= 3 and area >= 200.0):
		return "K7_liike" if t == "yes" and gap >= 0.0 and gap <= 10.0 else "K7"
	elif (t in ["terrace", "semidetached", "semidetached_house"] and l >= 18.0) or (area >= SPLIT_AREA and l / d >= 2.2 and d >= 8.0 and d <= 14.5 and l >= 22.0):
		return "K6"
	elif area >= SPLIT_AREA and d < 7.0 and l >= 20.0:
		return "K8_suoja"
	elif area >= 500.0 and t in ["yes", ""]:
		if (pelto or gap < 0.0) and d <= 20.0:
			return "K8_kone"
		if alue == "vaala" and gap >= 0.0 and gap <= 10.0:
			return "K8_liike"
		return "K8_teollisuus"
	elif area >= SPLIT_AREA:
		if t in RESIDENTIAL_T:
			return "JAKO"
		return "K8_suoja" if d < 7.0 else "K8_teollisuus"  # muu iso tyyppi (ei taulussa): halli
	var ok := _small_ok(alue, b, ctx)
	if ok.size() == 1:
		var k: String = ok.keys()[0]
		return "K3_ranta" if k == "K3" and ctx.get("ranta", false) else k
	return "TALO"


## Pienen pohjan (alle 260 m²) kelvolliset tyypit painoineen (taulun rivit 3, 4 ja 9).
static func _small_ok(alue: String, b: Dictionary, ctx: Dictionary) -> Dictionary:
	var fl: float = b.l
	var fd: float = b.d
	var t: String = b.get("t", "")
	var area := fl * fd
	var big := maxf(fl, fd)
	var small := minf(fl, fd)
	var w: Dictionary = DIST.get(alue, DIST.saloinen)
	if area < 45.0:
		return {"K4": 1.0} if ctx.get("pelto", false) and small >= 4.0 else {"K3": 1.0}
	if t == "cabin":  # mökki: rannalla rantamökki, iso mökki K1 (Vaalan kind shed, 04-sopivuus.md e)
		return {"K1": 1.0} if area >= 60.0 and not ctx.get("ranta", false) else {"K3": 1.0}
	if ctx.get("ranta", false) and area < 80.0:
		return {"K3": 1.0}
	if t in BARN_T:
		return {"K4": 1.0}
	if t in INDUSTRY_T or t in COMMERCE_T:
		return {"K2": 1.0} if t in ["commercial", "retail"] and fl >= 9.0 and fd >= 7.0 else {"K4": 1.0}
	if ctx.get("pelto", false) and t not in RESIDENTIAL_T:
		return {"K4": 1.0}
	var square := big / small < 1.4 and big <= 12.0
	var ok := {"K1": w.K1 * (1.0 if square else 0.5), "K2": w.K2 * (0.25 if square else 1.0)}
	if area > 140.0:
		ok.K1 *= 0.4  # rintamamiestalo enintään noin 110 m² (täyttöaste, 04-sopivuus.md 5): iso pohja K2:lle
	if fl >= 10.0 and fd >= 6.6:
		ok.K5 = w.K5  # aita vain, jos etupihaa on (pick: gate_gap)
	if fl < 9.0 or fd < 7.0:
		ok.erase("K2")
		ok.K1 = w.K1
	return ok


static func plan(alue: String, b: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Array:
	# keep_old ei tässä: kutsuja jättää vanhat pohjat vanhoiksi ennen plania (F, G); siihen asti nekin täytetään.
	var cls := _class(alue, b, ctx)
	if cls.begins_with("K6") or cls.begins_with("K7") or cls.begins_with("K8"):
		return [_big(cls, b, ctx, rng)]
	if cls == "JAKO":
		return _split(alue, b, ctx, rng)
	return [pick(alue, b, ctx, rng)]


## Iso asuin- tai tuntematon pohja 1–3 taloksi: väli G = 5–6 m, talo vähintään 9 m:n tontilla, k = floor((l+G)/(9+G)).
## Talolle heitto dx ±0,4, dz ±0,8 ja kierto ±2–4°, kun kulmat (myös autokatos) pysyvät tontilla ((G - 5)/2 yli)
## ja pohjassa (+0,3 m); muuten talo suoraan tontin keskelle. Peräkkäisillä eri tyyppi tai väri (enintään 3 arvontaa).
## k = 1: talo julkisivun puolelle ja piha = true (kutsuja tekee piharakennuksen).
static func _split(alue: String, b: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Array:
	var l: float = b.l
	var fd: float = b.d
	var g := rng.randf_range(SPLIT_GAP, SPLIT_GAP + 1.0)
	var k := clampi(floori((l + g) / (SPLIT_HOUSE + g)), 1, SPLIT_MAX)
	var pl := (l - (k - 1) * g) / k
	var res: Array = []
	var prev := {}
	for i in k:
		var o := {}
		for tries in 3:
			o = pick(alue, {"l": pl, "d": fd, "t": b.get("t", ""), "lv": b.get("lv", 1)}, ctx, rng)
			if prev.is_empty() or o.tyyppi != prev.tyyppi or o.wall != prev.wall:
				break
		if k > 1 and pl < 16.0:
			o.carport = 0  # katos tontin ulkopuolella osuisi naapurien väliin
		if k > 1 and i < k - 1:
			o.gate_gap = 0.0  # aita +X-päätyyn vain viimeiselle
		var cx := -l / 2.0 + pl / 2.0 + i * (pl + g)
		var x0 := cx - pl / 2.0 - (g - SPLIT_GAP) / 2.0
		var x1 := cx + pl / 2.0 + (g - SPLIT_GAP) / 2.0
		var base_dx: float = o.dx
		o.dx = cx + base_dx
		if k == 1:
			o.piha = true
			o.dz = -minf(3.0, maxf(0.0, (fd - o.d) / 2.0 - 0.3))
		else:
			var sg := 1.0 if rng.randf() < 0.5 else -1.0
			var try := o.duplicate()
			try.rot = sg * deg_to_rad(rng.randf_range(2.0, 4.0))
			try.dx = o.dx + rng.randf_range(-0.4, 0.4)
			try.dz = rng.randf_range(-1.0, 1.0) * minf(0.8, maxf(0.0, (fd - o.d) / 2.0))
			if _fits(try, x0, x1, l, fd):
				o = try
		if not _fits(o, x0, x1, l, fd):
			o.rot = 0.0
			o.dz = 0.0
		res.append(o)
		prev = o
	return res


## Talon (ja autokatoksen) kulmat local_xf:llä tontin [x0, x1] ja pohjan (+0,3 m) sisällä; myös dz = 0:lla
## (world.gd ja vaala.gd ennen local_xf-vaihtoa).
static func _fits(o: Dictionary, x0: float, x1: float, fl: float, fd: float) -> bool:
	var pts: Array[Vector2] = []
	var hl: float = o.l / 2.0
	var hd: float = o.d / 2.0
	for q in [Vector2(-hl, -hd), Vector2(hl, -hd), Vector2(hl, hd), Vector2(-hl, hd)]:
		pts.append(q)
	if o.get("carport", 0) != 0:
		var cp: float = o.carport
		var cd := minf(o.d, 6.0)
		var cx := cp * (hl + 3.65)
		for q in [Vector2(cx, -hd), Vector2(cx, -hd + cd + 0.1)]:
			pts.append(q)
	for dz: float in [o.get("dz", 0.0), 0.0]:
		var o2 := o.duplicate()
		o2.dz = dz
		var tx := local_xf(o2)
		for q in pts:
			var w := tx * Vector3(q.x, 0, q.y)
			if w.x < x0 - 0.001 or w.x > x1 + 0.001 or absf(w.x) > fl / 2.0 + 0.3 or absf(w.z) > fd / 2.0 + 0.3:
				return false
	return true


## K6–K8 pohjan pituuteen: moduulit (asunto, porras, kehäväli) toistuvat, malli ei jakaudu taloiksi.
static func _big(cls: String, b: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var fl: float = b.l
	var fd: float = b.d
	var lv: int = b.get("lv", 1)
	var tyyppi := cls.substr(0, 2)
	var v := cls.substr(3) if cls.length() > 3 else ""
	var o := {"tyyppi": tyyppi, "v": v, "flat": false, "carport": 0, "rima": false, "gate_gap": 0.0, "rot": 0.0,
		"dx": 0.0, "dz": 0.0, "piha": false, "krs": 1, "n": 1, "seed": rng.randi()}
	match tyyppi:
		"K6":
			var c := _wcol(K2_WALLS, rng)
			o.wall = c[0]
			o.rima = c[2]
			o.roof = K2_ROOFS[rng.randi() % K2_ROOFS.size()]
			o.trim = WHITE.darkened(0.05) if o.rima and c[0].get_luminance() < 0.5 else K2_TRIM
			o.flat = rng.randf() < 0.15
			o.krs = 2 if lv >= 2 else 1
			var n := clampi(roundi(fl / 8.0), 2, 8)
			var w := 0.96 * fl / n * rng.randf_range(0.92, 1.0)
			while n > 2 and w < 7.0:
				n -= 1
				w = 0.96 * fl / n * rng.randf_range(0.92, 1.0)
			w = minf(clampf(w, 7.0, 9.0), 0.96 * fl / n)
			o.n = n
			o.l = n * w
			o.d = minf(rng.randf_range(9.0, 11.0), fd)
			# Runko julkisivun puolelle, takapihaa enintään 4 m; aidat vain dz:stä riippumattomaan tilaan.
			var spare: float = fd - o.d
			o.dz = maxf(0.0, spare - 4.0) - spare / 2.0
			o.taka = spare / 2.0
		"K7":
			var c := _wcol(K7_WALLS, rng)
			o.wall = c[0]
			o.flat = rng.randf() < 0.5
			o.roof = Color(0.2, 0.2, 0.21) if o.flat else K2_ROOFS[rng.randi() % K2_ROOFS.size()]
			o.trim = DARK_GREY if c[0].get_luminance() > 0.5 else Color(0.36, 0.36, 0.37)
			o.krs = clampi(lv, 2, 3)
			o.liike = v == "liike"
			var n := maxi(1, roundi(fl / 16.0))
			var w := minf(clampf(0.96 * fl / n, 14.0, 18.0), 0.96 * fl / n)
			o.n = n
			o.l = n * w
			o.d = minf(rng.randf_range(10.0, 12.0), fd)
		"K8":
			if v == "":
				v = "teollisuus"
				o.v = v
			var c := _wcol(K8_WALLS[v], rng)
			o.wall = c[0]
			o.l = minf(clampf(0.95 * fl, 12.0, 120.0), fl)
			o.d = minf(clampf(0.95 * fd, 5.0, 40.0), fd)
			match v:
				"kone":
					o.d = minf(o.d, 20.0)
					o.roof = Color(0.16, 0.16, 0.17)
					o.trim = WHITE
				"teollisuus":
					o.roof = Color(0.4, 0.41, 0.42)
					o.trim = c[0].darkened(0.3)
				"liike":
					o.roof = Color(0.2, 0.2, 0.21)
					o.trim = DARK_GREY
				"suoja":
					o.roof = [Color(0.4, 0.41, 0.42), Color(0.5, 0.28, 0.16)][rng.randi() % 2]
					o.trim = c[0].darkened(0.15)
			o.n = maxi(2, roundi(o.l / 6.0))
	return o


static func pick(alue: String, b: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var fl: float = b.l  # pohjan mitat paikallisessa kehyksessä (X, Z)
	var fd: float = b.d
	var t: String = b.get("t", "")
	var ok := _small_ok(alue, b, ctx)
	var tyyppi := _weighted(ok, rng)
	var o := {"tyyppi": tyyppi, "flat": false, "carport": 0, "rima": false, "gate_gap": 0.0, "rot": 0.0, "dx": 0.0,
		"dz": 0.0, "piha": false, "v": "", "krs": 1, "n": 1, "seed": rng.randi()}
	match tyyppi:
		"K1":
			var c := _wcol(K1_WALLS, rng)
			o.wall = c[0]
			o.roof = K1_ROOFS[rng.randi() % K1_ROOFS.size()]
			o.trim = WHITE
			o.l = _fill_to(SIZES.K1, 0, fl, rng)
			o.d = _fill_to(SIZES.K1, 2, fd, rng)
		"K2":
			var c := _wcol(K2_WALLS, rng)
			o.wall = c[0]
			o.rima = c[2]
			o.roof = K2_ROOFS[rng.randi() % K2_ROOFS.size()]
			# Valkoiset listat vain tummaan peiterimaan; vaaleassa ja tiilessä tummanruskeat (erottuvat seinästä).
			o.trim = WHITE.darkened(0.05) if o.rima and c[0].get_luminance() < 0.5 else K2_TRIM
			o.flat = rng.randf() < 0.25  # 70-luvun tasakatto (00-ohjeet.md: osa tasakattoisia)
			o.d = _fill_to(SIZES.K2, 2, fd, rng)
			if fl >= 16.0:
				# Pitkä pohja: autokatos (3,6 m) kuuluu pohjaan, talo siirtyy toiseen päähän.
				o.carport = -1 if rng.randf() < 0.5 else 1
				o.l = minf(fl - 3.6, SIZES.K2[1])
				o.dx = -o.carport * 1.8  # talo + katos (3,6 m) keskellä pohjaa
			else:
				o.l = _fill_to(SIZES.K2, 0, fl, rng)
				o.carport = 0 if rng.randf() < 0.4 else (-1 if rng.randf() < 0.5 else 1)


		"K3", "K4":
			var key: String = tyyppi
			if tyyppi == "K3" and ctx.get("ranta", false):
				key = "K3_ranta"
			var c := _wcol(K3_WALLS if tyyppi == "K3" else K4_WALLS, rng)
			o.wall = c[0]
			o.roof = (K3_ROOFS if tyyppi == "K3" else K4_ROOFS)[rng.randi() % 3]
			o.trim = WHITE if c[0].r > 0.55 and c[0].g < 0.3 else c[0].darkened(0.15)
			# Harja (mallin d) pohjan pitkän akselin suuntaan: pitkä pohja X:llä -> käännös 90°.
			var along_x: bool = fl > fd * 1.1 and not ctx.get("ranta", false)
			var ax := fd if along_x else fl
			var az := fl if along_x else fd
			o.rot = PI / 2.0 if along_x else 0.0
			if tyyppi == "K4" and (t in BARN_T or t in INDUSTRY_T):
				o.l = minf(ax, SIZES.K4[1])  # maksimikoko
				o.d = minf(az, SIZES.K4[3])
			else:
				o.l = _fit(SIZES[key], 0, ax, rng)
				o.d = _fit(SIZES[key], 2, az, rng)
		"K5":
			var c := _wcol(K5_WALLS, rng)
			o.wall = c[0]
			o.roof = K5_ROOFS[rng.randi() % K5_ROOFS.size()]
			o.trim = WHITE
			o.l = _fit(SIZES.K5, 0, fl, rng)
			o.d = _fit(SIZES.K5, 2, fd, rng)
			# Aita ja ajoportti julkisivun linjassa vain, jos etupihaa on (gap >= 3); muuten talo ilman aitaa.
			o.gate_gap = rng.randf_range(4.0, 7.0) if ctx.get("gap", -1.0) >= 3.0 else 0.0
	return o




## Lokirivi (world.fill_log, vaala.fill_log): testit (maisema_kuvat) laskevat jakaumat, värit ja päällekkäisyydet.
static func entry(t: String, c: Vector2, yaw: float, l: float, d: float, wall: Color, foot: PackedVector2Array, v := "") -> Dictionary:
	return {"t": t, "c": c, "yaw": yaw, "l": l, "d": d, "wall": wall, "foot": foot, "v": v}


## Mitta väliltä SIZES[i]..SIZES[i+1], mutta enintään pohjan mitta (talo mahtuu aina pohjaan).
## Täyttö pohjaan: 86–96 % pohjan mitasta SIZES-välille rajattuna, enintään pohjan mitta (04-sopivuus.md 5).
static func _fill_to(r: Array, i: int, limit: float, rng: RandomNumberGenerator) -> float:
	return minf(clampf(limit * rng.randf_range(0.86, 0.96), r[i], r[i + 1]), limit)


static func _fit(r: Array, i: int, limit: float, rng: RandomNumberGenerator) -> float:
	return minf(rng.randf_range(r[i], r[i + 1]), limit)


static func _wcol(table: Array, rng: RandomNumberGenerator) -> Array:
	var sum := 0.0
	for c in table:
		sum += c[1]
	var x := rng.randf() * sum
	for c in table:
		x -= c[1]
		if x <= 0.0:
			return c
	return table[table.size() - 1]


static func _weighted(ok: Dictionary, rng: RandomNumberGenerator) -> String:
	var sum := 0.0
	for k in ok:
		sum += ok[k]
	var x := rng.randf() * sum
	for k in ok:
		x -= ok[k]
		if x <= 0.0:
			return k
	return ok.keys()[ok.size() - 1]
