extends RefCounted
## Maiseman täytetalojen valinta (Saloinen world.gd ja Vaala vaala.gd): tyyppi K1–K5 (scripts/rakennukset.gd),
## värit ja mitat nimettömän rakennuksen pohjasta, tyypistä ja ympäristöstä. Yhteinen rekisteri molemmille kylille;
## kutsuja antaa rakennuksesta siemennetyn rng:n (Saloinen hash(b.c), Vaala id), joten valinta ei riipu
## rakennusjärjestyksestä eikä world._rng:stä.
##
## plan(alue, b, ctx, rng) -> Array[Dictionary]: yksi tai useampi talo pohjaan (iso asuin- tai tuntematon pohja yli
##   260 m² jaetaan pitkää akselia pitkin enintään PLOT_L-pituisiin tontteihin, talo enintään tontti - 3 m). Jokainen alkio on pick()-tulos, jossa lisäksi dx.
## pick(alue, b, ctx, rng) -> {tyyppi, l, d, wall, roof, trim, flat, carport, rima, gate_gap, seed, rot, dx}
##   alue: "saloinen" tai "vaala".
##   b: {l (pitkä sivu, m), d (lyhyt sivu, m), t (OSM building-tyyppi tai Vaalan kind, "" = tuntematon), lv (kerroksia)}.
##      Pohjan pitkä sivu on paikallisella X:llä ja julkisivu -Z:ssä (world.gd _osm_fit).
##   ctx: {pelto: bool (pellon laidassa), ranta: bool (rantamökki, julkisivu rantaan), gap: float (etupiha tielle,
##        -1 = ei tietä)}; puuttuvat avaimet = false / -1.
##   Tulos sovitetaan pohjan sisään: l ja d ovat mallin mitat kehyksessä, joka on kierretty rot verran
##   (xf * Transform3D(Basis(Vector3.UP, rot), Vector3(dx, 0, 0)); rot = PI/2 vain K3/K4:lle, jotta harja on pohjan
##   pitkän akselin suuntainen). dx siirtää taloa pohjan pitkää akselia pitkin (autokatos pohjan sisällä, tontit).
##   carport ja gate_gap ovat toiveita: kutsuja nollaa ne, jos katos tai aita osuisi tiehen tai toiseen pohjaan.

const TYPES := ["K1", "K2", "K3", "K4", "K5"]
## Jakaumat (01-suunnitelma.md "Täytön säännöt"; K5 2–5 % myös Saloisiin ja Vaalaan, 00-ohjeet.md). Painot valitaan
## kelvollisten tyyppien joukosta: K3 ja K4 tulevat pääosin pohjan koosta ja ympäristöstä, painot jakavat päätalot.
const DIST := {
	"saloinen": {"K1": 40.0, "K2": 40.0, "K3": 12.0, "K4": 6.0, "K5": 3.0},
	"vaala": {"K1": 35.0, "K2": 30.0, "K3": 20.0, "K4": 10.0, "K5": 5.0},
}
## Mittavälit [l_min, l_max, d_min, d_max] (m); K3/K4: l = päädyn leveys, d = harjan suuntainen pituus.
const SIZES := {
	"K1": [8.0, 10.0, 8.6, 10.2],  # runko 8–10 x 7–8,5 + porstua (d sisältää porstuan)
	"K2": [10.0, 15.0, 8.0, 9.5],
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
const SPLIT_AREA := 260.0
const PLOT_L := 14.0  # jaetun pohjan tontin pituus enintään


static func plan(alue: String, b: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Array:
	var l: float = b.l
	var d: float = b.d
	var t: String = b.get("t", "")
	if l * d > SPLIT_AREA and t in RESIDENTIAL_T:
		var k := ceili(l / PLOT_L)
		var pl := l / k
		var res: Array = []
		for i in k:
			# Talo enintään tontti - 3 m: naapuritalojen väliin jää vähintään 3 m (ei taloja kylki kyljessä).
			var o := pick(alue, {"l": pl - 3.0, "d": d, "t": t, "lv": b.get("lv", 1)}, ctx, rng)
			o.dx += -l / 2.0 + pl * (i + 0.5)
			res.append(o)
		return res
	return [pick(alue, b, ctx, rng)]


static func pick(alue: String, b: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var fl: float = b.l  # pohjan mitat paikallisessa kehyksessä (X, Z)
	var fd: float = b.d
	var t: String = b.get("t", "")
	var area := fl * fd
	var big := maxf(fl, fd)
	var small := minf(fl, fd)
	var w: Dictionary = DIST.get(alue, DIST.saloinen)
	var ok := {}
	if t in BARN_T or (t in INDUSTRY_T and area > 45.0):
		ok = {"K4": 1.0}
	elif area < 45.0:
		if ctx.get("pelto", false) and small >= 4.0:
			ok = {"K4": 1.0}
		else:
			ok = {"K3": 1.0}
	elif ctx.get("ranta", false) and area < 80.0:
		ok = {"K3": 1.0}
	elif ctx.get("pelto", false) and t not in RESIDENTIAL_T:
		ok = {"K4": 1.0}
	else:
		var square := big / small < 1.4 and big <= 12.0
		ok = {"K1": w.K1 * (1.0 if square else 0.5), "K2": w.K2 * (0.25 if square else 1.0)}
		if fl >= 10.0 and fd >= 6.6:
			# K5 vain tien varteen: aita ja portti julkisivun linjassa (gap = etupiha tielle).
			if ctx.get("gap", -1.0) >= 3.0:
				ok.K5 = w.K5
		if fl < 9.0 or fd < 7.0:
			ok.erase("K2")
			ok.K1 = w.K1
	var tyyppi := _weighted(ok, rng)
	var o := {"tyyppi": tyyppi, "flat": false, "carport": 0, "rima": false, "gate_gap": 0.0, "rot": 0.0, "dx": 0.0,
		"seed": rng.randi()}
	match tyyppi:
		"K1":
			var c := _wcol(K1_WALLS, rng)
			o.wall = c[0]
			o.roof = K1_ROOFS[rng.randi() % K1_ROOFS.size()]
			o.trim = WHITE
			o.l = _fit(SIZES.K1, 0, fl, rng)
			o.d = _fit(SIZES.K1, 2, fd, rng)
		"K2":
			var c := _wcol(K2_WALLS, rng)
			o.wall = c[0]
			o.rima = c[2]
			o.roof = K2_ROOFS[rng.randi() % K2_ROOFS.size()]
			# Valkoiset listat vain tummaan peiterimaan; vaaleassa ja tiilessä tummanruskeat (erottuvat seinästä).
			o.trim = WHITE.darkened(0.05) if o.rima and c[0].get_luminance() < 0.5 else K2_TRIM
			o.flat = rng.randf() < 0.25  # 70-luvun tasakatto (00-ohjeet.md: osa tasakattoisia)
			o.d = _fit(SIZES.K2, 2, fd, rng)
			if fl >= 16.0:
				# Pitkä pohja: autokatos (3,4 m) kuuluu pohjaan, talo siirtyy toiseen päähän.
				o.carport = -1 if rng.randf() < 0.5 else 1
				o.l = minf(fl - 3.6, SIZES.K2[1])
				o.dx = -o.carport * 1.8  # talo + katos (3,6 m) keskellä pohjaa
			else:
				o.l = _fit(SIZES.K2, 0, fl, rng)
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
			o.gate_gap = rng.randf_range(4.0, 7.0)
	return o


## Lokirivi (world.fill_log, vaala.fill_log): testit (maisema_kuvat) laskevat jakaumat, värit ja päällekkäisyydet.
static func entry(t: String, c: Vector2, yaw: float, l: float, d: float, wall: Color, foot: PackedVector2Array) -> Dictionary:
	return {"t": t, "c": c, "yaw": yaw, "l": l, "d": d, "wall": wall, "foot": foot}


## Mitta väliltä SIZES[i]..SIZES[i+1], mutta enintään pohjan mitta (talo mahtuu aina pohjaan).
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
