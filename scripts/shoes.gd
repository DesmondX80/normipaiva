extends RefCounted
## Kengät: oma skinnattu verkko, joka taipuu samoilla luilla kuin jalkaterä (painot lähimmistä vartaloverkon kärjistä).
## Kuori rakennetaan jalkaterän lepoverkon poikkileikkauksista (kantapäästä varpaisiin), joten jokainen malli ja vartalo
## saa sopivan kengän ilman käsin piirrettyä mallia. Vartalon jalkaterä (vaateluokka 3) painuu varjostimessa kengän sisään
## (character.gdshader shoe_on / shoe_cut), ja Pose.limb_points lukee kengän pinnan kuten muunkin vartalon.
## Mesh-avaruudessa +Z = etupuoli (varpaat), +Y = ylös; hahmon avaruudessa etu on -Z (model.rotation.y = PI).
## Käyttö: Character._attach_shoes. type_for(look) on puhdas funktio.

const SHADER := "res://shaders/shoe.gdshader"
const SLICES := 16  # poikkileikkauksia kannasta varpaisiin
const RING := 24  # pisteitä poikkileikkauksen ympäri
const DOME := 3  # pyöristysrenkaita kannassa
const TOE_RINGS := 8  # kärjen kapenevat renkaat (tiheämmin kärkeä kohti)
const TOE_N := 2.5  # kärjen superellipsin eksponentti oletuksena (2 = ellipsi, suurempi = leveämpi kärki; TYPES toe_n)
const TOE_LOW := 0.22  # kärkipisteen korkeus kuoren alimmasta kohdasta oletuksena (osuus kärkiosan korkeudesta; toe_low)
const SE_N := 3.0  # poikkileikkauksen superellipsin eksponentti (2 = ellipsi, suurempi = laatikkomaisempi)
const B_LOW := 0.006  # poikkileikkauksen alapuoliskon korkeus (kuori kaartuu pohjaan)
const HU_PAD := 1.04  # yläpuoliskon väljyys korkeimman kärjen yli
const PAD := 0.0  # lisärako tarpeeseen (tasoituksen kutistuman kattaa rako; hahmot_kontakti MALLI jalka p90 <= 12 mm)
const TOE_BLEND := 0.015  # kärkiosan painot: päkiästä +-15 mm sekoitus, edessä vain päkiän luu

static var _tip_h := 0.0  # viimeksi rakennetun kengän kärkipisteen korkeus lattiasta (meta "karki", testin profiili)
static var _grow := []  # M1TEMP: kärjen kasvu jaloittain (meta "grow", testin mittaus)

## Tyyppien parametrit (metrejä mallin mittakaavassa): lift = koko nosto (pohjan alapinta jalkapohjan alimman kärjen alla,
## sama kaikilla tyypeillä, ettei hahmon pituus muutu), sole = näkyvä pohjalaatta (kuoren alapinta lift - sole jalkapohjan
## alla), rand = pohjan reunus kuoren kylkeä ylös, waist = korko (pohjan alapinta nousee kannan ja päkiän välissä),
## top = matalan kengän suu jalkapohjan yläpuolella (enintään), margin = kuoren rako ihoon, flare = pohjan
## reunan ulottuma kuoren ohi, toe_room = kärjen tila varpaiden edessä, toe_round = kärjen pyöristyksen pituus
## (osuus kärjen puolileveydestä), toe_n = kärjen superellipsin eksponentti, toe_low = kärkipisteen korkeus (osuus),
## toe_h = kärkikuvun korkeuskerroin, collar = kengän suu lahkeen alimman kärjen alla, spring = kärjen nousu (pohjan
## alapinta kärjessä), sole_col = pohjan väri, rough = päällisen karheus, sole_rough = pohjan karheus, style = varjostimen
## tyyli (0 lenkkari, 1 nauhakenkä, 2 kävelykenkä), spec = päällisen SPECULAR, clearcoat = lakkakiilto (0 = ei),
## toe_tip = kärjen kiila (kuoren yläpinta laskee päkiästä nokkaan tälle korkeudelle kuoren alapinnasta), snug = varpaiden
## tarpeesta vähennetty varjostimen painuma (enintään 6 mm), heel_rand = korkopala (pohjan yläreuna nousee kannassa).
## "paljas" = ei kenkää (vartalon jalkaterä värjätään kuten ennenkin).
const TYPES := {
	"lenkkari": {"lift": 0.023, "sole": 0.020, "rand": 0.0015, "margin": 0.003, "flare": 0.004, "toe_room": 0.015, "toe_round": 1.3,
		"collar": 0.012, "spring": 0.005, "sole_col": Color(0.95, 0.94, 0.9), "rough": 0.62, "sole_rough": 0.8, "style": 0,
		"spec": 0.4, "clearcoat": 0.0},
	"nauhakenka": {"lift": 0.023, "sole": 0.015, "rand": 0.002, "waist": 0.010, "heel_rand": 0.010, "top": 0.055, "margin": 0.002,
		"flare": 0.002, "toe_room": 0.016, "toe_round": 1.6, "toe_n": 2.0, "toe_low": 0.10, "toe_tip": 0.014, "snug": 0.004,
		"collar": 0.012, "spring": 0.010,
		"sole_col": Color(0.24, 0.15, 0.09), "rough": 0.22, "sole_rough": 0.55, "style": 1, "spec": 0.6, "clearcoat": 0.7},
	"kavelykenka": {"lift": 0.023, "sole": 0.016, "rand": 0.006, "top": 0.07, "margin": 0.004, "flare": 0.004, "toe_room": 0.015,
		"toe_round": 1.0, "toe_n": 3.0, "collar": 0.012, "spring": 0.005, "sole_col": Color(0.72, 0.66, 0.56), "rough": 0.78,
		"sole_rough": 0.85, "style": 2, "spec": 0.3, "clearcoat": 0.0},
	"paljas": {},
}


## Kenkätyyppi ulkonäöstä: look.shoe voittaa, muuten shoes-värin mukaan. Erä 1: vaaleat ja kirkkaanväriset = lenkkari,
## muut "paljas" (vanha värjätty jalkaterä), kunnes muut tyypit on tehty.
static func type_for(look: Dictionary) -> String:
	var t: String = look.get("shoe", "")
	if t != "":
		return t if TYPES.has(t) else "paljas"
	if not look.has("shoes"):
		return "paljas"
	var c: Color = look.shoes
	var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var sat := (maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))) / maxf(maxf(c.r, maxf(c.g, c.b)), 0.001)
	if lum > 0.75 and sat < 0.2:
		return "lenkkari"  # valkoinen tai vaalea (iho- tai beigesävyt, joissa on väriä, jäävät paljaiksi)
	if sat > 0.6 and c.v > 0.3:
		return "lenkkari"  # kirkas väri
	return "paljas"


## Kenkäverkko kummallekin jalalle (yksi pinta, limb_points lukee vain pinnan 0). arr = vaatetetun vartaloverkon pinnan 0
## taulukot (COLOR.r = vaateluokka / 4). meta "pohja" = kengän alin kohta jalkapohjan alimman kärjen alapuolella (m, malli).
static func build(kind: String, type: String, arr: Array, skin: Skin, skel: Skeleton3D, opts := {}) -> ArrayMesh:
	var p: Dictionary = TYPES[type]
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var bw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bi.size() / vs.size()
	var st := SurfaceTool.new()
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS if per <= 4 else SurfaceTool.SKIN_8_WEIGHTS)  # ennen beginiä (muuten "begun"-virhe)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pohja := 0.0
	var above := PackedInt32Array()  # jalkaterän kärjet kengän suun yläpuolella (lahkeen alla; skin_outside ohittaa)
	_grow = []  # M1TEMP
	for side: float in [1.0, -1.0]:
		var foot := PackedInt32Array()  # jalkaterän kärjet (luokka 3)
		var cand := PackedInt32Array()  # painojen lähteet: jalkaterä ja säären alaosa
		var pant := PackedInt32Array()  # lahkeen alaosa (luokka 2): kengän suu jää sen alle
		for v in vs.size():
			if signf(vs[v].x) != side:
				continue
			var c := roundi(cs[v].r * 4.0)
			if c == 3:
				foot.append(v)
				cand.append(v)
			elif c == 2 and vs[v].y < 0.25:
				cand.append(v)
				pant.append(v)
		pohja = _build_side(st, p, vs, arr[Mesh.ARRAY_NORMAL], bi, bw, per, foot, cand, pant, side, skin, skel, above)
	st.index()
	st.generate_normals()
	var out := st.commit()
	out.set_meta("pohja", pohja)
	out.set_meta("suu", above)
	out.set_meta("karki", _tip_h)
	out.set_meta("grow", _grow)  # M1TEMP
	out.set_meta("snug", float(TYPES[type].get("snug", 0.0)))
	return out


## Yhden jalan kuori ja pohja. Palauttaa pohjan alimman kohdan etäisyyden jalkapohjan alimmasta kärjestä.
static func _build_side(st: SurfaceTool, p: Dictionary, vs: PackedVector3Array, vn: PackedVector3Array, bi: PackedInt32Array, bw: PackedFloat32Array,
		per: int, foot: PackedInt32Array, cand: PackedInt32Array, pant: PackedInt32Array, side: float, skin: Skin,
		skel: Skeleton3D, above: PackedInt32Array) -> float:
	# Jalan pituusakseli: kannan (foot-luu) ja päkiän (ball-luu) kärkien keskipisteiden erotus vaakatasossa.
	var heel := Vector3.ZERO
	var ball := Vector3.ZERO
	var nh := 0
	var nb := 0
	var ymin := INF
	var ball_bind := -1  # päkiän luu (Skin-sidonnan indeksi): kärkiosan painot
	for v in foot:
		ymin = minf(ymin, vs[v].y)
		if _bone_of(v, bi, bw, per, skin, skel).begins_with("ball"):
			ball += vs[v]
			nb += 1
			ball_bind = _bind_of(v, bi, bw, per)
		else:
			heel += vs[v]
			nh += 1
	heel /= maxf(nh, 1)
	ball /= maxf(nb, 1)
	var fwd := Vector3(ball.x - heel.x, 0.0, ball.z - heel.z).normalized()  # +Z-suuntainen (mesh-avaruuden etu)
	var lat := Vector3.UP.cross(fwd)  # +X-suuntainen
	var org := Vector3(heel.x, 0.0, heel.z)
	var margin: float = p.margin
	var y_bot: float = ymin - float(p.lift)  # pohjan alapinta: nosto sama kaikilla tyypeillä
	var y_welt: float = y_bot + float(p.sole)  # kuoren tasainen alapinta (pohjalaatan yläpinta)
	# Kärjet jalan koordinaateissa: t (pituus), s (sivu), y.
	var pts := PackedVector3Array()
	var tmin := INF
	var tmax := -INF
	for v in foot:
		var d := vs[v] - org
		var q := Vector3(d.dot(fwd), d.dot(lat), vs[v].y)
		pts.append(q)
		tmin = minf(tmin, q.x)
		tmax = maxf(tmax, q.x)
	var step := (tmax - tmin) / float(SLICES)
	var win := step * 0.75 + 0.006
	# Kengän suu: kuoren yläreuna lahkeen alimman kärjen alapuolella (collar) kussakin poikkileikkauksessa, jolloin
	# lahkeen ja jalkaterän välinen vino kaista ei leikkaa kuorta, vaan jalkaterä (lahkeen värinen) nousee suusta.
	var collar: float = p.get("collar", 0.0)
	var pq := PackedVector3Array()
	for v in pant:
		var d := vs[v] - org
		pq.append(Vector3(d.dot(fwd), d.dot(lat), vs[v].y))
	var caps := PackedFloat32Array()  # poikkileikkauksittain
	for i in SLICES:
		var lo := INF
		for q in pq:
			if absf(q.x - (tmin + step * (i + 0.5))) <= win:
				lo = minf(lo, q.z)
		caps.append(lo - collar)
	var cmax := -INF
	for c in caps:
		if c < INF:
			cmax = maxf(cmax, c)
	for i in caps.size():
		caps[i] = -(caps[i] if caps[i] < INF else cmax)  # peilattuna; ei lahjetta ikkunassa = korkein suu
	# Suu tasaisena käyränä lahkeen alapuolella (_envelope peilattuna), ennen kuin kärjet jaetaan suun ylä- ja alapuolelle.
	caps = _envelope(caps)
	var top: float = ymin + float(p.get("top", INF))  # matala kenkä: suu enintään top jalkapohjan yläpuolella
	for i in caps.size():
		caps[i] = minf(-caps[i], top)
	# Suun yläpuolella oleva kärki: yli matalimman suun niistä poikkileikkauksista, joiden ikkunassa se on (kuori on
	# niiden välissä suora), joten yksikään kuoren sisään jäävä kärki ei jää leikatun yläreunan yläpuolelle.
	var is_above := PackedByteArray()
	for i in pts.size():
		var cmin := INF
		for k in SLICES:
			if absf(pts[i].x - (tmin + step * (k + 0.5))) <= win:
				cmin = minf(cmin, caps[k])
		is_above.append(1 if pts[i].z > cmin - margin else 0)
		if is_above[i] == 1:
			above.append(foot[i])
	# Kuori kaavasta: jalasta mitataan asemittain vain mittakäyrät (keskiviiva sc, puolileveys w, yläpuoliskon puoliakseli
	# hu, suun yläraja cap), jotka tasoitetaan pituuden suunnassa (_envelope), ja jokainen poikkileikkaus on sama superellipsi
	# (_ring_at) eri mitoissa. Mitään ei litistetä lattiaan eikä skaalata renkaittain, joten kehän kulmat ovat joka renkaassa
	# samalla indeksillä (renkaittain leikattu kuori rypisti pohjan yläreunan ja kärjen).
	var tb := (ball - org).dot(fwd)  # päkiä
	var yc := y_welt + B_LOW  # poikkileikkauksen keskikorkeus: alapuolisko B_LOW, alin piste tasan y_welt
	var at := PackedFloat32Array()  # asemat (t)
	var sels := []
	var sc := PackedFloat32Array()
	var cap := PackedFloat32Array()
	var hn := PackedFloat32Array()  # yläpuoliskon tarve
	for i in SLICES:
		var t := tmin + step * (i + 0.5)
		var sel := PackedVector2Array()
		for j in pts.size():
			if absf(pts[j].x - t) <= win and is_above[j] == 0:
				sel.append(Vector2(pts[j].y, pts[j].z))
		if sel.size() < 3:
			continue
		var lo := Vector2(INF, INF)
		var hi := -lo
		for q in sel:
			lo = lo.min(q)
			hi = hi.max(q)
		at.append(t)
		sels.append(sel)
		sc.append((lo.x + hi.x) / 2.0)
		cap.append(caps[i])
		hn.append((hi.y + margin + PAD - yc) * HU_PAD)  # väljyys: superellipsin kulma ei leikkaa ylänurkan kärkiä
	for it in 3:
		sc = _smooth(sc)
	var hu := _envelope(hn)
	var wn := PackedFloat32Array()
	for i in at.size():
		var need := 0.0
		for q: Vector2 in sels[i]:
			var dy := q.y - yc
			var r := clampf(absf(dy) / (hu[i] if dy > 0.0 else B_LOW), 0.0, 0.95)
			need = maxf(need, absf(q.x - sc[i]) / pow(1.0 - pow(r, SE_N), 1.0 / SE_N))
		wn.append(need + margin + PAD)
	var wd := _envelope(wn)
	# Pyöreä kärki: kohdasta ta kärkeen tend (toe_room varpaiden edessä) rengas kutistuu kärkipisteen (tip_s, y_tip)
	# ympäri kertoimella f = superellipsi (_toe_f): ylhäältä puoliellipsi, sivulta kaareva nokka. Kärkipiste on keskiviivan
	# ja isovarpaiden kärjen puolivälissä ja matalalla (TOE_LOW kärjen korkeudesta).
	var tend := tmax + margin + float(p.get("toe_room", 0.0))
	var ta := tend - wd[wd.size() - 1] * float(p.get("toe_round", 1.0))
	var sc_a := _at(at, sc, ta)
	var w_a := _at(at, wd, ta)
	var hu_a := _at(at, hu, ta)
	var cap_a := _at(at, cap, ta)
	var tip_s := 0.0
	var ntip := 0
	for q in pts:
		if q.x >= tmax - 0.004:
			tip_s += q.y
			ntip += 1
	tip_s = lerpf(sc_a, tip_s / maxf(ntip, 1), 0.5)
	var toe_n: float = p.get("toe_n", TOE_N)
	var tipc := Vector2(tip_s, y_welt + (B_LOW + hu_a) * float(p.get("toe_low", TOE_LOW)))
	if side > 0.0:
		_tip_h = tipc.y - y_bot  # testin profiili-rivi (kärkipisteen korkeus lattiasta)
	# Varpaat kärkiosan sisään: kutistettu rengas vastaa ta:n rengasta kärkipisteestä 1/f-kertaisesti, joten kärjen tarve
	# on varpaiden superellipsinormi siellä (raon kanssa). Yli 1 => ta:n renkaan leveys ja korkeus kasvavat.
	var grow := 1.0
	for i in pts.size():
		var q := pts[i]
		if q.x <= ta or is_above[i] == 1:
			continue
		var f := maxf(_toe_f(q.x, ta, tend, toe_n), 0.05)
		var d := tipc + (Vector2(q.y, q.z) - tipc) / f - Vector2(sc_a, yc)
		var ex := (absf(d.x) + margin / f) / w_a
		var ey := (absf(d.y) + margin / f) / (hu_a if d.y > 0.0 else B_LOW)
		if d.y > 0.0:
			grow = maxf(grow, pow(pow(ex, SE_N) + pow(ey, SE_N), 1.0 / SE_N))
		else:
			grow = maxf(grow, ex)
	var w_a0 := w_a  # M1TEMP
	var hu_a0 := hu_a  # M1TEMP
	w_a *= grow
	hu_a *= grow * float(p.get("toe_h", 1.0))  # toe_h: korkeampi kärkikupu (turvakärki)
	var il := 0  # M1TEMP: viimeinen tavallinen rengas
	for i in at.size():
		if at[i] < ta - step * 0.3:
			il = i
	_grow.append("side %+.0f grow %.3f step %.1f ta-tb %.1f ta-at_il %.1f wd %.1f hu %.1f w_a0 %.1f hu_a0 %.1f w_a %.1f hu_a %.1f w_a/wd %.3f hu_a/hu %.3f ta-at0 %.1f" % [side, grow,
		step * 1000.0, (ta - tb) * 1000.0, (ta - at[il]) * 1000.0, wd[il] * 1000.0, hu[il] * 1000.0, w_a0 * 1000.0, hu_a0 * 1000.0,
		w_a * 1000.0, hu_a * 1000.0, w_a / wd[il], hu_a / hu[il], (ta - at[0]) * 1000.0])  # M1TEMP
	var ring_a := _ring_at(sc_a, yc, w_a, hu_a, maxf(cap_a, y_welt))
	# Kärjen kiila (toe_tip, nauhakenkä): päkiästä tb nokkaan tend kuoren yläpinta laskee lineaarisesti tasolle
	# y_welt + toe_tip, mutta ei alle varpaiden tarpeen (raon kanssa, snug = varjostimen painuma vähennettynä). Kerroin gu
	# skaalaa valmiin renkaan (suun leikkaus cap mukana) yc:n yläpuolelta: päkiän edessä olevat renkaat ja kärjen renkaat
	# (ring_a ennen f-kutistusta), joten ta:ssa ei synny porrasta. Korkeus eff = yläpinta yc:stä ennen kiilaa.
	var ring_gu := PackedFloat32Array()  # at-renkaittain
	for i in at.size():
		ring_gu.append(1.0)
	var toe_gu := PackedFloat32Array()
	for j in TOE_RINGS:
		toe_gu.append(1.0)
	var toe_tip: float = p.get("toe_tip", -1.0)
	if toe_tip > 0.0:
		var snug: float = p.get("snug", 0.0)
		var sta := PackedFloat32Array()  # asemat: ta:ta edeltävät renkaat päkiän edessä, sitten kärjen renkaat
		var eff := PackedFloat32Array()  # yläpinta yc:stä ennen kiilaa (hu tai suun leikkaus)
		var idx := PackedInt32Array()  # renkaan indeksi at:ssa (-1 - j = kärjen rengas j)
		for i in at.size():
			if at[i] > tb and at[i] < ta - step * 0.3:
				sta.append(at[i])
				eff.append(minf(hu[i], maxf(cap[i], y_welt) - yc))
				idx.append(i)
		for j in TOE_RINGS:
			sta.append(ta + (tend - ta) * sin(PI / 2.0 * j / TOE_RINGS))
			eff.append(minf(hu_a, maxf(cap_a, y_welt) - yc))
			idx.append(-1 - j)
		var need := PackedFloat32Array()  # tarve korkeutena (gu * eff)
		need.resize(sta.size())
		need.fill(0.0)
		for i in pts.size():
			if is_above[i] == 1:
				continue
			var n := vn[foot[i]]  # painuma ihon normaalin suuntaan (varjostin ja skin_outside samoin)
			var q := pts[i] - Vector3(n.dot(fwd), n.dot(lat), n.y) * snug
			if q.x <= sta[0] - step:
				continue
			var k := 0
			while k < sta.size() - 1 and sta[k + 1] <= q.x:
				k += 1
			var py := q.z
			var ex := 0.0
			var dy := 0.0
			var h_full := 0.0  # renkaan yläpuolisko ja suun leikkaus kärjen kohdalla
			var h_cap := 0.0
			if q.x < ta:
				ex = (absf(q.y - _at(at, sc, q.x)) + margin) / _at(at, wd, q.x)
				dy = py + margin - yc
				h_full = _at(at, hu, q.x)
				h_cap = maxf(_at(at, cap, q.x), y_welt) - yc
			else:
				# Kuori on renkaiden välissä suora: kerroin f renkaiden välillä lineaarisesti (ei käyrältä, joka on ulompana).
				var t_k := sta[k]
				var t_n := sta[k + 1] if k < sta.size() - 1 else tend
				var f_n := _toe_f(t_n, ta, tend, toe_n) if k < sta.size() - 1 else 0.0
				var f := maxf(lerpf(_toe_f(t_k, ta, tend, toe_n), f_n, clampf((q.x - t_k) / maxf(t_n - t_k, 1e-5), 0.0, 1.0)), 0.05)
				ex = (absf(tipc.x + (q.y - tipc.x) / f - sc_a) + margin / f) / w_a
				dy = tipc.y + (py - tipc.y) / f + margin / f - yc
				h_full = hu_a
				h_cap = maxf(cap_a, y_welt) - yc
			if dy <= 0.0:
				continue
			var room := minf(h_full * pow(1.0 - pow(minf(ex, 0.999), SE_N), 1.0 / SE_N), h_cap)  # tila ennen kiilaa
			var g := 1.0 if ex >= 0.999 else minf(dy / room, 1.0)
			need[k] = maxf(need[k], g * eff[k])  # kuori on asemien välissä suora: kummankin pään pitää riittää
			var k2 := mini(k + 1, sta.size() - 1)
			need[k2] = maxf(need[k2], g * eff[k2])
		need = _envelope(need)
		var h_b := B_LOW + _at(sta, eff, tb)  # kiila alkaa päkiästä kuoren omalta korkeudelta (myös jos ta < tb)
		for k in sta.size():
			var lin := lerpf(h_b, toe_tip, clampf((sta[k] - tb) / (tend - tb), 0.0, 1.0)) - B_LOW
			var g := 1.0 if sta[k] <= tb else minf(eff[k], maxf(lin, need[k])) / eff[k]
			if idx[k] >= 0:
				ring_gu[idx[k]] = g
			else:
				toe_gu[-1 - idx[k]] = g
		print("A2DEBUG eff %s need %s toe_gu %s" % [eff, need, toe_gu])  # A2DEBUG
	var squash := func(r: PackedVector2Array, g: float) -> PackedVector2Array:  # yläpuolisko yc:n yläpuolelta kertoimella g
		if g < 1.0:
			for k in r.size():
				if r[k].y > yc:
					r[k].y = yc + (r[k].y - yc) * g
		return r
	var rings := []  # [t, keskipiste Vector2(s, y), PackedVector2Array (s, y), leveyden kerroin pohjalle]
	for i in at.size():
		if at[i] < ta - step * 0.3:
			rings.append([at[i], Vector2(sc[i], yc), squash.call(_ring_at(sc[i], yc, wd[i], hu[i], maxf(cap[i], y_welt)), ring_gu[i]), 1.0])
	var toe := []
	for j in TOE_RINGS:
		var t := ta + (tend - ta) * sin(PI / 2.0 * j / TOE_RINGS)
		var f := _toe_f(t, ta, tend, toe_n)
		var ring := PackedVector2Array()
		for q: Vector2 in squash.call(ring_a.duplicate(), toe_gu[j]):
			ring.append(tipc + (q - tipc) * f)
		toe.append([t, tipc + (Vector2(sc_a, yc) - tipc) * f, ring, f])
	var tip1 := tipc
	# Pyöristys kantaan: renkaat kutistuvat keskipisteeseen neljännesympyrän mukaan.
	var full := []
	var e: Array = rings[0]
	var ext: float = float(e[0]) - tmin + margin
	for j in range(DOME, 0, -1):
		var phi := PI / 2.0 * j / (DOME + 1)
		var sk := cos(phi)
		var ring := PackedVector2Array()
		for r: Vector2 in e[2]:
			var q: Vector2 = e[1] + (r - e[1]) * sk
			q.y = lerpf(q.y, r.y, clampf(1.0 - (r.y - y_welt) / 0.01, 0.0, 1.0))  # alapinta pysyy pohjan päällä
			if top < INF:  # matala kenkä: kantakappaleen yläosa pystysuora (kantapää jää sisään), alaosa pyöristyy kuten ennen
				q.y = lerpf(q.y, r.y, clampf((r.y - e[1].y - 0.005) / 0.015, 0.0, 1.0))
			ring.append(q)
		full.append([float(e[0]) - ext * sin(phi), e[1], ring, sk])
	full.append_array(rings)
	full.append_array(toe)
	var t0: float = float(rings[0][0]) - (float(rings[0][0]) - tmin + margin)
	var t1: float = tend
	var tip0: Vector2 = rings[0][1]
	var to3 := func(t: float, q: Vector2) -> Vector3:
		return org + fwd * t + lat * q.x + Vector3.UP * q.y
	var span := t1 - t0
	# Päällinen: renkaat vierekkäin, päät viuhkana.
	var up := []  # [Vector3 paikka, Vector2 (s, y)] renkaittain
	for r in full:
		var row := []
		for q: Vector2 in r[2]:
			row.append(to3.call(r[0], q))
		up.append(row)
	var add := func(a: Vector3, uv: Vector2, uv2: Vector2) -> void:
		st.set_uv(uv)
		st.set_uv2(uv2)
		st.set_color(Color(1, 1, 1, 1))
		# Kärkiosa kokonaan päkiän luulle (jäykkä, ei rypisty), päkiän ympärillä TOE_BLEND-mitan sekoitus.
		var tw := clampf(((a - org).dot(fwd) - tb + TOE_BLEND) / (2.0 * TOE_BLEND), 0.0, 1.0) if ball_bind >= 0 else 0.0
		_set_weights(st, a, vs, bi, bw, per, cand, ball_bind, tw)
		st.add_vertex(a)
	var uv_of := func(a: Vector3, part: float, c: Vector2) -> Array:
		var d := a - org
		var s := d.dot(lat)
		var w := 0.06
		return [Vector2((d.dot(fwd) - t0) / span, a.y - y_welt), Vector2(clampf((s - c.x) / w, -1.0, 1.0) * side, part)]
	var tri := func(a: Vector3, b: Vector3, c: Vector3, out: Vector3, part: float, ca: Vector2, cb: Vector2, cc: Vector2) -> void:
		if (c - a).cross(b - a).dot(out) < 0.0:
			var tmp := b
			b = c
			c = tmp
			var tc := cb
			cb = cc
			cc = tc
		for pr in [[a, ca], [b, cb], [c, cc]]:
			var u: Array = uv_of.call(pr[0], part, pr[1])
			add.call(pr[0], u[0], u[1])
	for i in full.size() - 1:
		var ca: Vector2 = full[i][1]
		var cb: Vector2 = full[i + 1][1]
		var ctr: Vector3 = (to3.call(full[i][0], ca) + to3.call(full[i + 1][0], cb)) / 2.0
		for k in RING:
			var k2 := (k + 1) % RING
			var a: Vector3 = up[i][k]
			var b: Vector3 = up[i][k2]
			var c: Vector3 = up[i + 1][k]
			var d: Vector3 = up[i + 1][k2]
			var o := (a + b + c + d) / 4.0 - ctr
			o -= fwd * o.dot(fwd)
			tri.call(a, b, c, o, 0.0, ca, ca, cb)
			tri.call(b, d, c, o, 0.0, ca, cb, cb)
	for end in [0, 1]:
		var i := 0 if end == 0 else full.size() - 1
		var c2: Vector2 = full[i][1]
		var tip: Vector3 = to3.call(t0 if end == 0 else t1, tip0 if end == 0 else tip1)
		var o := fwd * (-1.0 if end == 0 else 1.0)
		for k in RING:
			tri.call(up[i][k], up[i][(k + 1) % RING], tip, o, 0.0, c2, c2, c2)
	# Pohja: pyöristetty laatta kuoren ääriviivan (sc ± w + flare) mukaan, yläreuna kuoren alapinnan tasalla, alapinta
	# tasainen. Kärjessä sama puoliellipsi kuin kuoressa, flaren verran edempänä (tend + flare), ei kutistettua päätyä.
	var flare: float = p.flare
	# Kärjen nousu (toe spring): pohjan alapinta nousee päkiän edestä (tb:n ja kärjen välin 35 %) smoothstepillä kärkeen
	# spring-mitan verran; kanta ja päkiä pysyvät lattiassa.
	var ts0 := lerpf(tb, t1, 0.35)
	var spring: float = p.get("spring", 0.0)
	# Korko (waist): pohjan alapinta nousee kannan etureunasta (th, jyrkkä +-2 mm) ja laskee päkiän alkuun (tf) mennessä.
	var waist: float = p.get("waist", 0.0)
	var th := t0 + (t1 - t0) * 0.24
	var tf := t0 + (t1 - t0) * 0.58
	var rand: float = p.rand
	# Korkopala (heel_rand): pohjalaatan yläreuna nousee kannassa (t < th, sama +-2 mm reuna kuin korossa) kuoren kylkeä ylös.
	var heel_rand: float = p.get("heel_rand", 0.0)
	var slab := func(t: float, mid: float, hw: float) -> Array:
		var yt := y_welt + rand  # reunus kuoren kylkeä ylös (lenkkari: pieni limitys), myös päissä
		yt += heel_rand * (1.0 - smoothstep(th - 0.002, th + 0.002, t))
		var yb := y_bot + spring * smoothstep(ts0, t1, t)
		if waist > 0.0:
			yb += waist * smoothstep(th - 0.002, th + 0.002, t) * (1.0 - smoothstep(th + 0.002, tf, t))
		var bv := minf(0.004, (yt - yb) / 3.0)
		var pr := PackedVector2Array([Vector2(mid + hw - flare * 0.5, yt), Vector2(mid + hw, yt - bv),
			Vector2(mid + hw, yb + bv), Vector2(mid + hw - bv, yb), Vector2(mid - hw + bv, yb),
			Vector2(mid - hw, yb + bv), Vector2(mid - hw, yt - bv), Vector2(mid - hw + flare * 0.5, yt)])
		return [t, Vector2(mid, (yt + yb) / 2.0), pr]
	var prof := []  # renkaittain [t, keskipiste, 8 pistettä (s, y)]
	var st_t := PackedFloat32Array()  # pohjan asemat: kuoren renkaat (ja korollisella kannan reunan katkokset)
	var st_m := PackedFloat32Array()
	var st_w := PackedFloat32Array()
	for r in full.slice(0, full.size() - TOE_RINGS):
		var lo := INF
		var hi := -INF
		for q: Vector2 in r[2]:
			lo = minf(lo, q.x)
			hi = maxf(hi, q.x)
		st_t.append(float(r[0]))
		st_m.append((lo + hi) / 2.0)
		st_w.append((hi - lo) / 2.0 + flare * float(r[3]))
	var extra := [th - 0.002, th + 0.002] if waist > 0.0 or heel_rand > 0.0 else []
	for i in st_t.size():
		for t: float in extra:
			if t < st_t[i] and (i == 0 or t > st_t[i - 1]):
				prof.append(slab.call(t, _at(st_t, st_m, t), _at(st_t, st_w, t)))
		prof.append(slab.call(st_t[i], st_m[i], st_w[i]))
	for j in TOE_RINGS:
		var t := ta + (t1 + flare - ta) * sin(PI / 2.0 * j / TOE_RINGS)
		var f := _toe_f(t, ta, t1 + flare, toe_n)
		prof.append(slab.call(t, tip_s + (sc_a - tip_s) * f, (w_a + flare) * f))
	# Kanta: pohja jatkuu kuoren pään alle kapenevana.
	var e0: Array = prof[0]
	var pr0 := PackedVector2Array()
	for q: Vector2 in e0[2]:
		pr0.append(Vector2(e0[1].x + (q.x - e0[1].x) * 0.55, q.y))
	prof.push_front([t0 - flare * 0.5, e0[1], pr0])
	var np := 8
	for i in prof.size() - 1:
		var ca: Vector2 = prof[i][1]
		var cb: Vector2 = prof[i + 1][1]
		var ctr: Vector3 = (to3.call(prof[i][0], ca) + to3.call(prof[i + 1][0], cb)) / 2.0
		for k in np:
			var k2 := (k + 1) % np
			var a: Vector3 = to3.call(prof[i][0], prof[i][2][k])
			var b: Vector3 = to3.call(prof[i][0], prof[i][2][k2])
			var c: Vector3 = to3.call(prof[i + 1][0], prof[i + 1][2][k])
			var d: Vector3 = to3.call(prof[i + 1][0], prof[i + 1][2][k2])
			var o := (a + b + c + d) / 4.0 - ctr
			o -= fwd * o.dot(fwd)
			tri.call(a, b, c, o, 1.0, ca, ca, cb)
			tri.call(b, d, c, o, 1.0, ca, cb, cb)
	for end in [0, 1]:
		var i := 0 if end == 0 else prof.size() - 1
		var c2: Vector2 = prof[i][1]
		var cen: Vector3 = to3.call(prof[i][0] if end == 0 else t1 + flare, c2)  # kärki suppenee pisteeseen
		var o := fwd * (-1.0 if end == 0 else 1.0)
		for k in np:
			tri.call(to3.call(prof[i][0], prof[i][2][k]), to3.call(prof[i][0], prof[i][2][(k + 1) % np]), cen, o, 1.0, c2, c2, c2)
	return ymin - y_bot


## Poikkileikkaus: superellipsi (eksponentti SE_N) keskipisteestä (sc, yc), puolileveys w, yläpuolisko hu ja alapuolisko
## B_LOW (alin piste tasan yc - B_LOW). Kiinteät kulmat: piste k on joka renkaassa samassa kohdassa kehää. Yläreuna
## enintään cap (kengän suu lahkeen alla, ei näy).
static func _ring_at(sc: float, yc: float, w: float, hu: float, cap: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in RING:
		var a := TAU * k / RING
		var x := signf(cos(a)) * pow(absf(cos(a)), 2.0 / SE_N)
		var y := signf(sin(a)) * pow(absf(sin(a)), 2.0 / SE_N)
		out.append(Vector2(sc + w * x, minf(yc + (hu if y > 0.0 else B_LOW) * y, cap)))
	return out


## Kärjen kavennus kohdassa t: 1 ennen ta:ta, superellipsi (eksponentti n) nollaan kärjessä tend.
static func _toe_f(t: float, ta: float, tend: float, n: float) -> float:
	var u := clampf((t - ta) / (tend - ta), 0.0, 1.0)
	return pow(1.0 - pow(u, n), 1.0 / n)


## Käyrän arvo kohdassa t (asemien at välillä lineaarisesti, päiden ulkopuolella päätyarvo).
static func _at(at: PackedFloat32Array, v: PackedFloat32Array, t: float) -> float:
	if t <= at[0]:
		return v[0]
	for i in at.size() - 1:
		if t <= at[i + 1]:
			return lerpf(v[i], v[i + 1], (t - at[i]) / (at[i + 1] - at[i]))
	return v[v.size() - 1]


## Käyrä 1-2-1 (päissä päätyarvo toistuu).
static func _smooth(v: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := v.size()
	for i in n:
		out.append((v[maxi(i - 1, 0)] + v[i] * 2.0 + v[mini(i + 1, n - 1)]) / 4.0)
	return out


## Sileä käyrä tarpeen need yläpuolelle: harvan vartaloverkon (noin 400 kärkeä jalassa) mitat hyppivät asemasta toiseen.
## Kolme kertaa max(tarve, tasoitus), sitten kaksi tasoitusta; huippujen kutistuman kattaa rako (testi: skin_outside).
static func _envelope(need: PackedFloat32Array) -> PackedFloat32Array:
	var a := need
	for it in 3:
		var sm := _smooth(a)
		for i in sm.size():
			sm[i] = maxf(sm[i], need[i])
		a = sm
	return _smooth(_smooth(a))


static func _bone_of(v: int, bi: PackedInt32Array, bw: PackedFloat32Array, per: int, skin: Skin, skel: Skeleton3D) -> String:
	var b := _bind_of(v, bi, bw, per)
	var nm := str(skin.get_bind_name(b))
	return nm if nm != "" else skel.get_bone_name(skin.get_bind_bone(b))


## Kärjen v painavin luu (Skin-sidonnan indeksi).
static func _bind_of(v: int, bi: PackedInt32Array, bw: PackedFloat32Array, per: int) -> int:
	var best := 0
	for k in per:
		if bw[v * per + k] > bw[v * per + best]:
			best = k
	return bi[v * per + best]


## Painot kolmesta lähimmästä vartalon kärjestä etäisyydellä painottaen (kenkä taipuu päkiästä kuten iho). tw > 0:
## sekoitetaan osuus tw jäykästi luulle fixed (kärkiosa päkiän luulla).
static func _set_weights(st: SurfaceTool, a: Vector3, vs: PackedVector3Array, bi: PackedInt32Array, bw: PackedFloat32Array,
		per: int, cand: PackedInt32Array, fixed := -1, tw := 0.0) -> void:
	var near := [[INF, -1], [INF, -1], [INF, -1]]
	for v in cand:
		var d := a.distance_squared_to(vs[v])
		if d < near[2][0]:
			near[2] = [d, v]
			near.sort_custom(func(x, y): return x[0] < y[0])
	var acc := {}
	for n in near:
		if n[1] < 0:
			continue
		var w := 1.0 / (sqrt(n[0]) + 0.004)
		for k in per:
			var wk: float = bw[n[1] * per + k]
			if wk > 0.0:
				acc[bi[n[1] * per + k]] = float(acc.get(bi[n[1] * per + k], 0.0)) + wk * w
	if tw > 0.0:
		var sum := 0.0
		for k in acc:
			sum += acc[k]
		for k in acc:
			acc[k] = acc[k] / sum * (1.0 - tw)
		acc[fixed] = float(acc.get(fixed, 0.0)) + tw
	var keys: Array = acc.keys()
	keys.sort_custom(func(x, y): return acc[x] > acc[y])
	var n4 := 4 if per <= 4 else 8
	var total := 0.0
	for k in mini(n4, keys.size()):
		total += acc[keys[k]]
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	for k in n4:
		bones.append(keys[k] if k < keys.size() else 0)
		wts.append(acc[keys[k]] / total if k < keys.size() else 0.0)
	st.set_bones(bones)
	st.set_weights(wts)


## Jalkaterän ihon pahin ulkonema kuoren ulkopuolelle lepoasennossa (m; < 0 = kaikki sisällä). Testikohtaukselle:
## säde jokaisen kärjen suunnassa verrattuna kuoren säteeseen samassa poikkileikkauksessa (lähin rengas).
static func skin_outside(shoe: ArrayMesh, arr: Array) -> float:
	var sa := shoe.surface_get_arrays(0)
	var sv: PackedVector3Array = sa[Mesh.ARRAY_VERTEX]
	var su2: PackedVector2Array = sa[Mesh.ARRAY_TEX_UV2]
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var vn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var snug: float = shoe.get_meta("snug", 0.0)  # kuori mitoitettu varjostimen painuman verran tiukemmaksi (TYPES snug)
	var worst := -INF
	var above: PackedInt32Array = shoe.get_meta("suu", PackedInt32Array())
	for v in vs.size():
		if roundi(cs[v].r * 4.0) != 3 or v in above:
			continue
		var pv := vs[v] - vn[v] * snug
		# Lähin päällisen piste (osa 0) ja sen normaali: ihon kärki on ulkona, jos se on pinnan ulkopuolella. Pohja (osa 1)
		# ohitetaan: sen reunuksen sisäpuolen yläreuna osoittaa ylös ja mittasi korkeutta, ei ulkonemaa (A2 M0a).
		var best := INF
		var bj := -1
		for j in sv.size():
			if su2[j].y > 0.5:
				continue
			var d := pv.distance_squared_to(sv[j])
			if d < best:
				best = d
				bj = j
		var n: Vector3 = (sa[Mesh.ARRAY_NORMAL] as PackedVector3Array)[bj]
		worst = maxf(worst, (pv - sv[bj]).dot(n))
	return worst
