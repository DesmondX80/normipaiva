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
const SHAFT_RINGS := 8  # varren vaakarenkaat alhaalta yläreunaan
const SHAFT_N := 2.6  # varren poikkileikkauksen superellipsin eksponentti

static var _tip_h := 0.0  # viimeksi rakennetun kengän kärkipisteen korkeus lattiasta (meta "karki", testin profiili)

## Tyyppien parametrit (metrejä mallin mittakaavassa): lift = koko nosto (pohjan alapinta jalkapohjan alimman kärjen alla,
## sama kaikilla tyypeillä, ettei hahmon pituus muutu), sole = näkyvä pohjalaatta (kuoren alapinta lift - sole jalkapohjan
## alla), rand = pohjan reunus kuoren kylkeä ylös, waist = korko (pohjan alapinta nousee kannan ja päkiän välissä),
## top = matalan kengän suu jalkapohjan yläpuolella (enintään), margin = kuoren rako ihoon, flare = pohjan
## reunan ulottuma kuoren ohi, toe_room = kärjen tila varpaiden edessä, toe_round = kärjen pyöristyksen pituus
## (osuus kärjen puolileveydestä), toe_n = kärjen superellipsin eksponentti, toe_low = kärkipisteen korkeus (osuus),
## toe_h = kärkikuvun korkeuskerroin, collar = kengän suu lahkeen alimman kärjen alla, spring = kärjen nousu (pohjan
## alapinta kärjessä), sole_col = pohjan väri, rough = päällisen karheus, sole_rough = pohjan karheus, style = varjostimen
## tyyli (0 lenkkari, 1 varattu nauhakengälle (myöhempi issue), 2 kävelykenkä), spec = päällisen SPECULAR,
## clearcoat = lakkakiilto (0 = ei), shaft = varsi {join = jalkaosan suu, top = varren yläreuna (jalkapohjasta),
## pad = varren paksuus ihon ja raon päälle}, boot = saapas yhtenä kuorena (_build_boot) {top = yläreuna jalkapohjasta,
## pad = varren paksuus, fillet = etujohteen koveran kaaren säde nilkan taitteessa}.
## "paljas" = ei kenkää (vartalon jalkaterä värjätään kuten ennenkin).
const TYPES := {
	"lenkkari": {"lift": 0.023, "sole": 0.020, "rand": 0.0015, "margin": 0.003, "flare": 0.004, "toe_room": 0.015, "toe_round": 1.3,
		"collar": 0.012, "spring": 0.005, "sole_col": Color(0.95, 0.94, 0.9), "rough": 0.62, "sole_rough": 0.8, "style": 0,
		"spec": 0.4, "clearcoat": 0.0},
	"kavelykenka": {"lift": 0.023, "sole": 0.016, "rand": 0.006, "top": 0.07, "margin": 0.004, "flare": 0.004, "toe_room": 0.015,
		"toe_round": 1.0, "toe_n": 3.0, "collar": 0.012, "spring": 0.005, "sole_col": Color(0.72, 0.66, 0.56), "rough": 0.78,
		"sole_rough": 0.85, "style": 2, "spec": 0.3, "clearcoat": 0.0},
	"tyokenka": {"lift": 0.023, "sole": 0.020, "rand": 0.010, "margin": 0.004, "flare": 0.005, "toe_room": 0.016,
		"toe_round": 1.2, "toe_n": 3.0, "toe_h": 1.18, "toe_low": 0.32, "collar": 0.012, "spring": 0.006,
		"sole_col": Color(0.13, 0.12, 0.11), "rough": 0.72, "sole_rough": 0.9, "style": 3, "spec": 0.35, "clearcoat": 0.0,
		"shaft": {"join": 0.07, "top": 0.13, "pad": 0.006}},
	"kumisaapas": {"lift": 0.023, "sole": 0.020, "rand": 0.012, "margin": 0.004, "flare": 0.004, "toe_room": 0.018,
		"toe_round": 1.3, "toe_n": 2.6, "toe_h": 1.1, "toe_low": 0.3, "spring": 0.006, "sole_col": Color(0.8, 0.77, 0.66),
		"rough": 0.25, "sole_rough": 0.9, "style": 4, "spec": 0.6, "clearcoat": 0.6,
		"boot": {"top": 0.26, "pad": 0.010, "fillet": 0.03}},
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
	var varsi := Vector4.ZERO  # varren yläreuna (lepo-y, UV2), yläreuna ja jalkaosan suu (verkon y), UV2.y - y yläreunassa
	for side: float in [1.0, -1.0]:
		if p.has("boot"):  # kumisaapas: yksi kuori kärjestä sääreen (lahje varren sisään)
			var r := _build_boot(st, p, vs, arr[Mesh.ARRAY_TEX_UV2], cs, bi, bw, per, side, skin, skel)
			pohja = r.pohja
			varsi = r.varsi
			continue
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
		var mouth := PackedVector2Array()  # jalkaosan suun ääriviiva (t, s), varrellisella
		pohja = _build_side(st, p, vs, bi, bw, per, foot, cand, pant, side, skin, skel, above, mouth)
		if p.has("shaft"):
			varsi = _build_shaft(st, p, vs, arr[Mesh.ARRAY_TEX_UV2], cs, bi, bw, per, foot, side, skin, skel, mouth)
	st.index()
	st.generate_normals()
	var out := st.commit()
	out.set_meta("pohja", pohja)
	out.set_meta("suu", above)
	out.set_meta("karki", _tip_h)
	out.set_meta("varsi", varsi.x)  # 0 = ei vartta; character.gdshader shoe_top (lahje varren sisään)
	out.set_meta("varsi_v", Vector3(varsi.y, varsi.z, varsi.w))  # skin_outside ja testi (saappaalla (yläreuna, F.y, -))
	out.set_meta("saapas", p.has("boot"))
	return out


## Yhden jalan kuori ja pohja. Palauttaa pohjan alimman kohdan etäisyyden jalkapohjan alimmasta kärjestä.
static func _build_side(st: SurfaceTool, p: Dictionary, vs: PackedVector3Array, bi: PackedInt32Array, bw: PackedFloat32Array,
		per: int, foot: PackedInt32Array, cand: PackedInt32Array, pant: PackedInt32Array, side: float, skin: Skin,
		skel: Skeleton3D, above: PackedInt32Array, mouth: PackedVector2Array) -> float:
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
	if p.has("shaft"):
		top = ymin + float(p.shaft.join)  # varrellinen: jalkaosan suu tasan join, varsi peittää lahkeen
	for i in caps.size():
		caps[i] = top if p.has("shaft") else minf(-caps[i], top)
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
	var tp := _toe_part(p, pts, is_above, at, sc, wd, hu, cap, tmax, margin, y_welt, y_bot, yc, side)
	var tend: float = tp.tend
	var ta: float = tp.ta
	var sc_a: float = tp.sc_a
	var w_a: float = tp.w_a
	var tip_s: float = tp.tip_s
	var toe_n: float = tp.toe_n
	var tipc: Vector2 = tp.tipc
	var toe: Array = tp.toe
	var rings := []  # [t, keskipiste Vector2(s, y), PackedVector2Array (s, y), leveyden kerroin pohjalle]
	for i in at.size():
		if at[i] < ta - step * 0.3:
			rings.append([at[i], Vector2(sc[i], yc), _ring_at(sc[i], yc, wd[i], hu[i], maxf(cap[i], y_welt)), 1.0])
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
	if p.has("shaft"):  # suun reunan pisteet (leikattu tasolle top): varren alin rengas liittyy niihin
		for r in full:
			for q: Vector2 in r[2]:
				if q.y >= top - 1e-5:
					mouth.append(Vector2(float(r[0]), q.x))
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
	var flare: float = p.flare
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
	var fr := {"to3": to3, "fwd": fwd, "tb": tb, "t0": t0, "t1": t1, "ta": ta, "y_welt": y_welt, "y_bot": y_bot, "toe_n": toe_n,
		"tip_s": tip_s, "sc_a": sc_a, "w_a": w_a}
	_build_sole(p, fr, st_t, st_m, st_w, tri)
	return ymin - y_bot


## Pohja (_build_side ja _build_boot): asemat st_t (keskiviiva st_m, puolileveys st_w kuoren alareunassa flaren kanssa)
## ja kärki kehyksestä fr (to3, fwd, tb, t0, t1, ta, y_welt, y_bot, toe_n, tip_s, sc_a, w_a). tri = kolmion lisäys.
static func _build_sole(p: Dictionary, fr: Dictionary, st_t: PackedFloat32Array, st_m: PackedFloat32Array,
		st_w: PackedFloat32Array, tri: Callable) -> void:
	var to3: Callable = fr.to3
	var fwd: Vector3 = fr.fwd
	var tb: float = fr.tb
	var t0: float = fr.t0
	var t1: float = fr.t1
	var ta: float = fr.ta
	var y_welt: float = fr.y_welt
	var y_bot: float = fr.y_bot
	var toe_n: float = fr.toe_n
	var tip_s: float = fr.tip_s
	var sc_a: float = fr.sc_a
	var w_a: float = fr.w_a
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
	var slab := func(t: float, mid: float, hw: float) -> Array:
		var yt := y_welt + rand  # reunus kuoren kylkeä ylös (lenkkari: pieni limitys), myös päissä
		var yb := y_bot + spring * smoothstep(ts0, t1, t)
		if waist > 0.0:
			yb += waist * smoothstep(th - 0.002, th + 0.002, t) * (1.0 - smoothstep(th + 0.002, tf, t))
		var bv := minf(0.004, (yt - yb) / 3.0)
		var pr := PackedVector2Array([Vector2(mid + hw - flare * 0.5, yt), Vector2(mid + hw, yt - bv),
			Vector2(mid + hw, yb + bv), Vector2(mid + hw - bv, yb), Vector2(mid - hw + bv, yb),
			Vector2(mid - hw, yb + bv), Vector2(mid - hw, yt - bv), Vector2(mid - hw + flare * 0.5, yt)])
		return [t, Vector2(mid, (yt + yb) / 2.0), pr]
	var prof := []  # renkaittain [t, keskipiste, 8 pistettä (s, y)]
	var extra := [th - 0.002, th + 0.002] if waist > 0.0 else []
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


## Pyöreä kärki (_build_side ja _build_boot): poikkileikkausten käyrät (asemat at, keskiviiva sc, puolileveys wd,
## yläpuolisko hu, suun yläraja cap) jalan koordinaateissa (t, s, y). Palauttaa kärjen mitat ja renkaat (toe).
static func _toe_part(p: Dictionary, pts: PackedVector3Array, is_above: PackedByteArray, at: PackedFloat32Array,
		sc: PackedFloat32Array, wd: PackedFloat32Array, hu: PackedFloat32Array, cap: PackedFloat32Array, tmax: float,
		margin: float, y_welt: float, y_bot: float, yc: float, side: float) -> Dictionary:
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
	w_a *= grow
	hu_a *= grow * float(p.get("toe_h", 1.0))  # toe_h: korkeampi kärkikupu (turvakärki)
	var ring_a := _ring_at(sc_a, yc, w_a, hu_a, maxf(cap_a, y_welt))
	var toe := []
	for j in TOE_RINGS:
		var t := ta + (tend - ta) * sin(PI / 2.0 * j / TOE_RINGS)
		var f := _toe_f(t, ta, tend, toe_n)
		var ring := PackedVector2Array()
		for q: Vector2 in ring_a:
			ring.append(tipc + (q - tipc) * f)
		toe.append([t, tipc + (Vector2(sc_a, yc) - tipc) * f, ring, f])
	return {"tend": tend, "ta": ta, "sc_a": sc_a, "w_a": w_a, "tip_s": tip_s, "toe_n": toe_n, "tipc": tipc, "toe": toe}


## Varsi (työkenkä, kuukenkä): pystyputki säären ympärillä jalkaosan suusta (join; alin rengas on suun ääriviiva, joten
## pinta jatkuu kuoresta ilman porrasta) varren yläreunaan (top).
## Vaakarenkaat ovat neljän puoliakselin superellipsejä (etu +t, taka, sivut ±s) säären keskipisteestä; puoliakselit
## mitataan kärjistä (kaikki paitsi paita, join - margin:n yläpuolella, joten alin rengas peittää jalkaosan suun) ja
## tasoitetaan _envelope:lla. Yläreunassa pehmustettu reuna ja rengaslevy sääreen, sisäpinta hieman alas; pohja viuhkana.
## UV = (kulma: 0 = etu, -0,5..0,5, saumaton takana; korkeus y_weltistä), UV2 = (sivu -1..1, + = ulkosivu; osa 2).
## Palauttaa Vector4(yläreuna UV2-avaruudessa, yläreuna verkossa, jalkaosan suu verkossa, UV2.y - y yläreunassa).
static func _build_shaft(st: SurfaceTool, p: Dictionary, vs: PackedVector3Array, uv2: PackedVector2Array, cs: PackedColorArray,
		bi: PackedInt32Array, bw: PackedFloat32Array, per: int, foot: PackedInt32Array, side: float, skin: Skin,
		skel: Skeleton3D, mouth: PackedVector2Array) -> Vector4:
	# Jalan kehys kuten _build_side: kannan ja päkiän luiden kärkien keskipisteet.
	var heel := Vector3.ZERO
	var ball := Vector3.ZERO
	var nh := 0
	var nb := 0
	var ymin := INF
	for v in foot:
		ymin = minf(ymin, vs[v].y)
		if _bone_of(v, bi, bw, per, skin, skel).begins_with("ball"):
			ball += vs[v]
			nb += 1
		else:
			heel += vs[v]
			nh += 1
	heel /= maxf(nh, 1)
	ball /= maxf(nb, 1)
	var fwd := Vector3(ball.x - heel.x, 0.0, ball.z - heel.z).normalized()
	var lat := Vector3.UP.cross(fwd)
	var org := Vector3(heel.x, 0.0, heel.z)
	var sh: Dictionary = p.shaft
	var margin: float = p.margin
	var pad: float = sh.pad
	var y_welt: float = ymin - float(p.lift) + float(p.sole)
	var yj: float = ymin + float(sh.join)
	var y0 := yj + 0.012  # alin mitattu rengas; sen alla rengas jalkaosan suun ääriviivalla (yj)
	var y1: float = ymin + float(sh.top)
	var win := (y1 - y0) / float(SHAFT_RINGS - 1) * 0.75 + 0.004
	# Kärjet (t, s, y) säären alaosasta; paita (luokka 1) pois. leg = painojen lähteet.
	var leg := PackedInt32Array()
	var pts := PackedVector3Array()
	var dy_top := 0.0  # UV2.y - y yläreunan kohdalla (lepopaikka ennen vartalon muotoa)
	var ntop := 0
	for v in vs.size():
		if signf(vs[v].x) != side or roundi(cs[v].r * 4.0) == 1 or vs[v].y > y1 + 0.06:
			continue
		leg.append(v)
		if vs[v].y < yj - margin:
			continue
		var d := vs[v] - org
		pts.append(Vector3(d.dot(fwd), d.dot(lat), vs[v].y))
		if absf(vs[v].y - y1) < 0.01:
			dy_top += uv2[v].y - vs[v].y
			ntop += 1
	dy_top /= maxf(ntop, 1)
	var hs := PackedFloat32Array()
	var ct := PackedFloat32Array()  # säären keskipiste (t, s) renkaittain
	var cl := PackedFloat32Array()
	for i in SHAFT_RINGS:
		var h := lerpf(y0, y1, float(i) / float(SHAFT_RINGS - 1))
		hs.append(h)
		var hc := maxf(h, yj + 0.025)  # alarenkaiden keskipiste nilkasta (jalan päällinen ei vedä sitä eteen)
		var c := Vector2.ZERO
		var n := 0
		for q in pts:
			if absf(q.z - hc) <= win:
				c += Vector2(q.x, q.y)
				n += 1
		c /= maxf(n, 1)
		ct.append(c.x)
		cl.append(c.y)
	for it in 2:
		ct = _smooth(ct)
		cl = _smooth(cl)
	var ax := [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]  # etu, taka, +s, -s
	var raw := [0.0, 0.0, 0.0, 0.0]  # yläreunan iho (rengaslevyn sisäreuna)
	for i in SHAFT_RINGS:
		var e := [0.002, 0.002, 0.002, 0.002]
		var sel := PackedVector2Array()
		for q in pts:
			if absf(q.z - maxf(hs[i], yj)) <= win:
				var d := Vector2(q.x - ct[i], q.y - cl[i])
				sel.append(d)
				e[0] = maxf(e[0], d.x)
				e[1] = maxf(e[1], -d.x)
				e[2] = maxf(e[2], d.y)
				e[3] = maxf(e[3], -d.y)
		var g := 1.0  # superellipsin kulma: kasvata, kunnes jokainen kärki on sisällä
		for d in sel:
			var a0: float = e[0] if d.x > 0.0 else e[1]
			var a1: float = e[2] if d.y > 0.0 else e[3]
			g = maxf(g, pow(pow(absf(d.x) / a0, SHAFT_N) + pow(absf(d.y) / a1, SHAFT_N), 1.0 / SHAFT_N))
		for k in 4:
			ax[k].append(e[k] * g + margin + pad)
			if i == SHAFT_RINGS - 1:
				raw[k] = e[k] * g
	for k in 4:
		ax[k] = _envelope(ax[k])
	var ring := func(c: Vector2, a: Array) -> PackedVector2Array:  # superellipsi (t, s); k = 0 takana, RING / 2 edessä
		var out := PackedVector2Array()
		for k in RING:
			var ang := PI + TAU * k / RING
			var x := signf(cos(ang)) * pow(absf(cos(ang)), 2.0 / SHAFT_N)
			var y := signf(sin(ang)) * pow(absf(sin(ang)), 2.0 / SHAFT_N)
			out.append(Vector2(c.x + x * float(a[0] if x > 0.0 else a[1]), c.y + y * float(a[2] if y > 0.0 else a[3])))
		return out
	# Renkaat [korkeus, keskipiste, pisteet (t, s), ulospäin: 0 säteittäin, 1 ylös, 2 sisään].
	var rows := []
	for i in SHAFT_RINGS:
		rows.append([hs[i], Vector2(ct[i], cl[i]), ring.call(Vector2(ct[i], cl[i]), [ax[0][i], ax[1][i], ax[2][i], ax[3][i]]), 0])
	# Alin rengas: jalkaosan suun ääriviiva kunkin pisteen suunnassa keskipisteestä (lähin sektori), tasoitettuna kehää pitkin.
	var c0 := Vector2(ct[0], cl[0])
	var se0: PackedVector2Array = rows[0][2]
	var rad := PackedFloat32Array()
	for k in RING:
		var d := (se0[k] - c0).normalized()
		var r := -1.0
		for m in mouth:
			var dm := m - c0
			if absf(d.angle_to(dm)) < TAU / RING:
				r = maxf(r, dm.dot(d))
		rad.append(maxf(r + 0.0005, (se0[k] - c0).length()))  # ei kapeampi kuin säären tarve (iho pysyy sisällä)
	var rs := PackedFloat32Array()
	for k in RING:
		rs.append((rad[(k + RING - 1) % RING] + rad[k] * 2.0 + rad[(k + 1) % RING]) / 4.0)
	var r0p := PackedVector2Array()
	for k in RING:
		r0p.append(c0 + (se0[k] - c0).normalized() * rs[k])
	# Alarenkaat liukuvat suun ääriviivasta säären mittoihin (ei olkaa suun ja varren välissä): säde vähintään sekoitus.
	for i in SHAFT_RINGS:
		var w := smoothstep(yj, yj + 0.04, float(rows[i][0]))
		var ci: Vector2 = rows[i][1]
		var pi: PackedVector2Array = rows[i][2]
		for k in RING:
			var rse := (pi[k] - ci).length()
			pi[k] = ci + (pi[k] - ci).normalized() * maxf(rse, lerpf(rs[k], rse, w))
		rows[i][2] = pi
	rows.push_front([yj, c0, r0p, 0])
	var c1 := Vector2(ct[SHAFT_RINGS - 1], cl[SHAFT_RINGS - 1])
	var a1 := [ax[0][SHAFT_RINGS - 1], ax[1][SHAFT_RINGS - 1], ax[2][SHAFT_RINGS - 1], ax[3][SHAFT_RINGS - 1]]
	var lip := []
	var inner := []
	for k in 4:
		lip.append(lerpf(float(a1[k]), raw[k] + margin, 0.45))  # pyöristetty pehmustettu yläreuna
		inner.append(raw[k] + 0.001)
	rows.append([y1 + 0.005, c1, ring.call(c1, lip), 0])
	rows.append([y1 + 0.003, c1, ring.call(c1, inner), 1])
	rows.append([y1 - 0.015, c1, ring.call(c1, inner), 2])
	var to3 := func(q: Vector2, h: float) -> Vector3:
		return org + fwd * q.x + lat * q.y + Vector3.UP * h
	var add := func(a: Vector3, k: float, h: float, part: float) -> void:
		var ang := PI + TAU * k / RING
		st.set_uv(Vector2(k / RING - 0.5, h - y_welt))
		st.set_uv2(Vector2(sin(ang) * side, part))
		st.set_color(Color(1, 1, 1, 1))
		_set_weights(st, a, vs, bi, bw, per, leg)
		st.add_vertex(a)
	# Osa 2,0 = varren ulkopinta, 2,2 = yläreunan levy ja sisäpinta (skin_outside ohittaa, varjostimessa sama osa 2).
	var tri := func(pa: Array, pb: Array, pc: Array, out: Vector3, part: float) -> void:  # [paikka, k, h]
		if (pc[0] - pa[0]).cross(pb[0] - pa[0]).dot(out) < 0.0:
			var tmp := pb
			pb = pc
			pc = tmp
		for q in [pa, pb, pc]:
			add.call(q[0], float(q[1]), q[2], part)
	for i in rows.size() - 1:
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		var mode: int = r1[3]
		var p0: PackedVector2Array = r0[2]
		var p1: PackedVector2Array = r1[2]
		var h0: float = r0[0]
		var h1: float = r1[0]
		for k in RING:
			var k2 := (k + 1) % RING
			var a: Vector3 = to3.call(p0[k], h0)
			var b: Vector3 = to3.call(p0[k2], h0)
			var c: Vector3 = to3.call(p1[k], h1)
			var d: Vector3 = to3.call(p1[k2], h1)
			var mid := (a + b + c + d) / 4.0
			var cm: Vector2 = (r0[1] + r1[1]) / 2.0
			var o: Vector3 = mid - to3.call(cm, mid.y)
			o.y = 0.0
			if mode == 1:
				o = Vector3.UP
			elif mode == 2:
				o = -o
			var part := 2.0 if mode == 0 else 2.2
			tri.call([a, k, h0], [b, k + 1, h0], [c, k, h1], o, part)
			tri.call([b, k + 1, h0], [d, k + 1, h1], [c, k, h1], o, part)
	# Pohja viuhkana (jalkaosan suun kohdalla, ulospäin alas).
	var cen: Vector3 = to3.call(c0, yj - 0.002)
	for k in RING:
		tri.call([to3.call(r0p[k], yj), k, yj], [to3.call(r0p[(k + 1) % RING], yj), k + 1, yj], [cen, k + 0.5, yj], Vector3.DOWN, 2.0)
	return Vector4(y1 + dy_top, y1, yj, dy_top)


## Kumisaapas (#273 v2): yksi kuori kärjestä kantaan ja sääreen. Poikkileikkaukset ovat tasoja kahden johteen pisteiden
## Pf (etu: päällinen, nilkan taitteen kovera kaari, varren etulinja) ja Pb (taka: pohja, kantakaari, varren takalinja)
## kautta, sivuakseli lat (_boot_rails). Jokainen leike on sama superellipsi (_ring_se) mitoilla, jotka mitataan ikkunan
## kärjistä ja tasoitetaan yhtenä jonona (_envelope); λ = 0 jalassa, smoothstep siirtymässä ja 1 varressa (kaukopuoli,
## eksponentti ja varren paksuus pad). Tasot eivät leikkaa toisiaan kuoren sisällä, joten kuori ei mene itsensä läpi.
## Kärki ja pohja kuten _build_side. Mesh-avaruudessa +Z = varpaat (fwd), hahmon etu on -Z maailmassa.
## Palauttaa {pohja, varsi: Vector4 kuten _build_shaft (yläreuna UV2, yläreuna, varren alku A.y, UV2.y - y)}.
static func _build_boot(st: SurfaceTool, p: Dictionary, vs: PackedVector3Array, uv2: PackedVector2Array, cs: PackedColorArray,
		bi: PackedInt32Array, bw: PackedFloat32Array, per: int, side: float, skin: Skin, skel: Skeleton3D) -> Dictionary:
	var bt: Dictionary = p.boot
	var margin: float = p.margin
	var pad: float = bt.pad
	var foot := PackedInt32Array()
	for v in vs.size():
		if signf(vs[v].x) == side and roundi(cs[v].r * 4.0) == 3:
			foot.append(v)
	# Kehys kuten _build_side: kannan ja päkiän luiden kärkien keskipisteet.
	var heel := Vector3.ZERO
	var ball := Vector3.ZERO
	var nh := 0
	var nb := 0
	var ymin := INF
	var ball_bind := -1
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
	var lat := Vector3.UP.cross(fwd)
	var org := Vector3(heel.x, 0.0, heel.z)
	var tb := (ball - org).dot(fwd)
	var y_bot: float = ymin - float(p.lift)
	var y_welt: float = y_bot + float(p.sole)
	var y_top: float = ymin + float(bt.top)
	var yc := y_welt + B_LOW
	# Ehdokkaat: jalkaterä ja sääri/lahje (paita pois) yläreunan yläpuolelle asti; painot samoista.
	var cand := PackedInt32Array()
	var pts := PackedVector3Array()  # (t, s, y)
	var dy_top := 0.0
	var ntop := 0
	var tmin := INF
	var tmax := -INF
	for v in vs.size():
		var c := roundi(cs[v].r * 4.0)
		if signf(vs[v].x) != side or c == 1 or vs[v].y > y_top + 0.06:
			continue
		cand.append(v)
		var d := vs[v] - org
		var q := Vector3(d.dot(fwd), d.dot(lat), vs[v].y)
		pts.append(q)
		if c == 3:
			tmin = minf(tmin, q.x)
			tmax = maxf(tmax, q.x)
		if absf(vs[v].y - y_top) < 0.01:
			dy_top += uv2[v].y - vs[v].y
			ntop += 1
	dy_top /= maxf(ntop, 1)
	var foot_pts := PackedVector3Array()
	for v in foot:
		var d := vs[v] - org
		foot_pts.append(Vector3(d.dot(fwd), d.dot(lat), vs[v].y))
	var step := (tmax - tmin) / float(SLICES)
	var win := step * 0.75 + 0.006
	var gap := margin + pad
	# Johteet sivuprofiilissa (_boot_rails): nilkkanivel J = kannan luun (foot) lepopaikka sidonnasta.
	var y_ank := -INF  # jalkaterän (luokka 3) yläreuna: varren suorat johteet alkavat siitä
	for q in foot_pts:
		y_ank = maxf(y_ank, q.z)
	var heel_bind := -1
	for v in foot:
		if not _bone_of(v, bi, bw, per, skin, skel).begins_with("ball"):
			heel_bind = _bind_of(v, bi, bw, per)
			break
	var jp := skin.get_bind_pose(heel_bind).affine_inverse().origin if heel_bind >= 0 else Vector3(heel.x, ymin, heel.z)
	var jt := Vector2((jp - org).dot(fwd), jp.y)
	var res := _boot_rails(pts, tmin, step, win, y_welt, yc, y_top, y_ank, margin, pad, float(bt.fillet))
	var fa: Vector2 = res.a
	if side > 0.0:
		var sl_: Array = res.slices
		var s0 := -1
		var s1 := -1
		for i in sl_.size():
			var pc: Vector2 = sl_[i][0] + sl_[i][1] * float(sl_[i][3])
			var s := smoothstep(jt.y - 0.03, jt.y + 0.12, pc.y)
			if s > 0.0 and s < 1.0:
				s1 = i
				if s0 < 0:
					s0 = i
		print("KENKA saapas johteet %d ristiin %d, J (%.1f, %.1f) mm, A (%.1f, %.1f) B (%.1f, %.1f) C (%.1f, %.1f) mm, liuku %d..%d, varsi %d viuhka %d jalka %d"
			% [sl_.size(), res.crossed, (jt.x - tmin) * 1000.0, (jt.y - ymin) * 1000.0, (fa.x - tmin) * 1000.0, (fa.y - ymin) * 1000.0,
			(res.b.x - tmin) * 1000.0, (res.b.y - ymin) * 1000.0, (res.c.x - tmin) * 1000.0, (res.c.y - ymin) * 1000.0, s0, s1,
			res.nshaft, res.nfan, res.nfoot])
		for e: Array in sl_:  # VÄLIAIKAINEN
			var pf: Vector2 = e[0] + e[1] * (float(e[5]) + float(e[6]))
			print("KENKA rengas Pb (%.0f, %.0f) Pf (%.0f, %.0f) sc %.0f w %.0f an %.0f af %.0f" % [(e[0].x - tmin) * 1000, (e[0].y - ymin) * 1000,
				(pf.x - tmin) * 1000, (pf.y - ymin) * 1000, e[2] * 1000, e[4] * 1000, e[5] * 1000, e[6] * 1000])
	var sl: Array = res.slices  # [O = Pb (t, y), b = (Pf - Pb) / D, sc, vc, w, an, af, n, vfloor]
	var nfoot: int = res.nfoot
	# Kärki jalkaleikkeistä (pystytasot: O = Pb lattiassa, an = Pf.y - yc).
	var at := PackedFloat32Array()
	var a_sc := PackedFloat32Array()
	var a_wd := PackedFloat32Array()
	var a_hu := PackedFloat32Array()
	var a_cap := PackedFloat32Array()
	for i in range(sl.size() - nfoot, sl.size()):
		at.append(sl[i][0].x)
		a_sc.append(sl[i][2])
		a_wd.append(sl[i][4])
		a_hu.append(sl[i][5])
		a_cap.append(INF)
	var no_above := PackedByteArray()
	no_above.resize(foot_pts.size())
	var tp := _toe_part(p, foot_pts, no_above, at, a_sc, a_wd, a_hu, a_cap, tmax, margin, y_welt, y_bot, yc, side)
	var ta: float = tp.ta
	var tend: float = tp.tend
	var tipc: Vector2 = tp.tipc
	var to3 := func(t: float, q: Vector2) -> Vector3:
		return org + fwd * t + lat * q.x + Vector3.UP * q.y
	# Renkaat 3D:nä: [pisteet, keskipiste, tason normaali, sc]; ylhäältä kärkeen.
	var full := []
	for i in sl.size():
		var e: Array = sl[i]
		if i >= sl.size() - nfoot and float(e[0].x) >= ta - step * 0.3:
			continue
		var o2: Vector2 = e[0]
		var b2: Vector2 = e[1]
		var ring := _ring_se(e[2], e[3], e[4], e[5], e[6], e[7], e[8])
		var row := []
		for q: Vector2 in ring:
			row.append(to3.call(o2.x + q.y * b2.x, Vector2(q.x, o2.y + q.y * b2.y)))
		full.append([row, to3.call(o2.x + float(e[3]) * b2.x, Vector2(e[2], o2.y + float(e[3]) * b2.y)),
			fwd * b2.y - Vector3.UP * b2.x, float(e[2])])
	for r: Array in tp.toe:
		var row := []
		for q: Vector2 in r[2]:
			row.append(to3.call(r[0], q))
		full.append([row, to3.call(r[0], r[1]), fwd, float(r[1].x)])
	# Kuoren kantapää (pohjan alku) ja UV:n pituusväli.
	var rand: float = p.rand
	var t0 := INF
	for r in full:
		for a: Vector3 in r[0]:
			if a.y <= y_welt + rand + 1e-4:
				t0 = minf(t0, (a - org).dot(fwd))
	var t1 := tend
	var span := t1 - t0
	var add := func(a: Vector3, uv: Vector2, uv2v: Vector2) -> void:
		st.set_uv(uv)
		st.set_uv2(uv2v)
		st.set_color(Color(1, 1, 1, 1))
		var tw := clampf(((a - org).dot(fwd) - tb + TOE_BLEND) / (2.0 * TOE_BLEND), 0.0, 1.0) if ball_bind >= 0 else 0.0
		_set_weights(st, a, vs, bi, bw, per, cand, ball_bind, tw)
		st.add_vertex(a)
	var uv_of := func(a: Vector3, part: float, c: Vector2) -> Array:
		var d := a - org
		return [Vector2((d.dot(fwd) - t0) / span, a.y - y_welt), Vector2(clampf((d.dot(lat) - c.x) / 0.06, -1.0, 1.0) * side, part)]
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
	# Kuori: renkaat vierekkäin (sama kehän indeksi k koko matkan), ulospäin keskipisteestä tason suunnassa.
	for i in full.size() - 1:
		var ca := Vector2(full[i][3], 0.0)
		var cb := Vector2(full[i + 1][3], 0.0)
		var ctr: Vector3 = (full[i][1] + full[i + 1][1]) / 2.0
		var nrm: Vector3 = (full[i][2] + full[i + 1][2]).normalized()
		for k in RING:
			var k2 := (k + 1) % RING
			var a: Vector3 = full[i][0][k]
			var b: Vector3 = full[i][0][k2]
			var c: Vector3 = full[i + 1][0][k]
			var d: Vector3 = full[i + 1][0][k2]
			var o := (a + b + c + d) / 4.0 - ctr
			o -= nrm * o.dot(nrm)
			tri.call(a, b, c, o, 0.0, ca, ca, cb)
			tri.call(b, d, c, o, 0.0, ca, cb, cb)
	var last: Array = full[full.size() - 1]
	var tip: Vector3 = to3.call(t1, tipc)
	for k in RING:
		var cl := Vector2(last[3], 0.0)
		tri.call(last[0][k], last[0][(k + 1) % RING], tip, fwd, 0.0, cl, cl, cl)
	# Yläreuna: pyöristetty huuli ja sisäpinta (osa 2,2) ihoon päin, sisäpinnan alla tumma viuhka.
	var e0: Array = sl[0]
	var lip_ring := func(shrink: float, h: float) -> Array:
		var ring := _ring_se(e0[2], e0[3], float(e0[4]) - shrink, float(e0[5]) - shrink, float(e0[6]) - shrink, e0[7], -INF)
		var row := []
		for q: Vector2 in ring:
			row.append(to3.call(float(e0[0].x) + q.y, Vector2(q.x, h)))
		return row
	var top_rows := [[full[0][0], 0], [lip_ring.call(pad * 0.45, y_top + 0.005), 0], [lip_ring.call(gap - 0.001, y_top + 0.003), 1],
		[lip_ring.call(gap - 0.001, y_top - 0.015), 2]]
	var c_top: Vector3 = to3.call(float(e0[0].x) + float(e0[3]), Vector2(e0[2], y_top))
	var cs0 := Vector2(e0[2], 0.0)
	for i in top_rows.size() - 1:
		var mode: int = top_rows[i + 1][1]
		var part := 0.0 if mode == 0 else 2.2
		for k in RING:
			var k2 := (k + 1) % RING
			var a: Vector3 = top_rows[i][0][k]
			var b: Vector3 = top_rows[i][0][k2]
			var c: Vector3 = top_rows[i + 1][0][k]
			var d: Vector3 = top_rows[i + 1][0][k2]
			var o := (a + b + c + d) / 4.0 - c_top
			o.y = 0.0
			if mode == 1:
				o = Vector3.UP
			elif mode == 2:
				o = -o
			tri.call(a, b, c, o, part, cs0, cs0, cs0)
			tri.call(b, d, c, o, part, cs0, cs0, cs0)
	var bottom: Array = top_rows[3][0]
	var cen: Vector3 = c_top + Vector3.UP * (-0.015)
	for k in RING:
		tri.call(bottom[k], bottom[(k + 1) % RING], cen, Vector3.UP, 2.2, cs0, cs0, cs0)
	# Pohja: asemat leikkaamalla valmis kuori pystytasoilla nauhassa y <= y_welt + rand (kärki kuten _build_side).
	var segs := []
	for i in full.size():
		for k in RING:
			segs.append([full[i][0][k], full[i][0][(k + 1) % RING]])
			if i + 1 < full.size():
				segs.append([full[i][0][k], full[i + 1][0][k]])
	var flare: float = p.flare
	var st_t := PackedFloat32Array()
	var st_m := PackedFloat32Array()
	var st_w := PackedFloat32Array()
	var ns := 16
	for j in range(1, ns):
		var t := t0 + (ta - t0) * (1.0 - cos(PI / 2.0 * j / ns))
		var lo := INF
		var hi := -INF
		for sg in segs:
			var ta_: float = (sg[0] - org).dot(fwd) - t
			var tb_: float = (sg[1] - org).dot(fwd) - t
			if ta_ * tb_ > 0.0 or ta_ == tb_:
				continue
			var q: Vector3 = sg[0].lerp(sg[1], ta_ / (ta_ - tb_))
			if q.y <= y_welt + rand + 1e-4:
				var s := (q - org).dot(lat)
				lo = minf(lo, s)
				hi = maxf(hi, s)
		if lo >= hi:
			continue
		st_t.append(t)
		st_m.append((lo + hi) / 2.0)
		st_w.append((hi - lo) / 2.0 + flare * minf(1.0, (hi - lo) / 0.04))
	var fr := {"to3": to3, "fwd": fwd, "tb": tb, "t0": t0, "t1": t1, "ta": ta, "y_welt": y_welt, "y_bot": y_bot,
		"toe_n": tp.toe_n, "tip_s": tp.tip_s, "sc_a": tp.sc_a, "w_a": tp.w_a}
	_build_sole(p, fr, st_t, st_m, st_w, tri)
	return {"pohja": ymin - y_bot, "varsi": Vector4(y_top + dy_top, y_top, fa.y, dy_top)}


## Saappaan johteet ja leikkeet (#273 v2) sivuprofiilissa (t, y). Etujohde: jalkaterän päällinen (pystyleikkeiden tarve
## y_ank:n alla, tasoitettuna) kärjestä taaksepäin, kovera kaari (säde fillet, keskipiste C ilmassa) varren etulinjaan ja
## sitä ylös. Takajohde: pohja y_welt kantaan, kupera kaari kannan ympäri ja varren takalinja ylös. Varren linjat ovat
## suoria (_rail_line: pienin suora säären ja lahkeen kärkien + margin + pad ulkopuolella välillä y_ank..y_top).
## Leikkeet Pf (etujohde) - Pb (takajohde), ylhäältä kärkeen: varsi (Pf etulinjalla tasavälein, suunta kääntyy
## vaakatasosta etulinjan normaaliin), siirtymä (Pb takajohteella kaarenpituuden mukaan, Pf = C + fillet · suunta Pb:hen:
## kaikki tasot kulkevat C:n kautta, joten ne eivät leikkaa toisiaan kuoren sisällä) ja jalkaterä (pystytasot samalla t:llä,
## ensimmäiset kaksi kääntyvät B:n normaalista pystyyn). Rengas: O = Pb, b = (Pf - Pb) / D, af = lerp(B_LOW, D / 2, λ),
## vc = af, an = D - af (λ = 1 varressa, 0 jalassa). Leveys w ja keskiviiva sc ikkunan kärjistä (_envelope), varressa w suora.
## Palauttaa {slices: [O, b, sc, vc, w, an, af, n, vfloor], nshaft, nfan, nfoot, crossed, a, b, c}.
static func _boot_rails(pts: PackedVector3Array, tmin: float, step: float, win: float, y_welt: float, yc: float,
		y_top: float, y_ank: float, margin: float, pad: float, fillet: float) -> Dictionary:
	var gap := margin + pad
	# Jalkaterän päällinen: pystyleikkeiden tarve (kärjet y_ank:n alla) ja yläpuoliskon väljyys HU_PAD.
	var at := PackedFloat32Array()
	var dn := PackedFloat32Array()
	for i in SLICES:
		var t := tmin + step * (i + 0.5)
		var hi := yc
		for q in pts:
			if q.z < y_ank and absf(q.x - t) <= win:
				hi = maxf(hi, q.z + margin)
		at.append(t)
		dn.append(hi)
	dn = _envelope(dn)
	var dorsum := PackedVector2Array()
	for i in dn.size():
		dn[i] = yc + (dn[i] - yc) * HU_PAD
		dorsum.append(Vector2(at[i], dn[i]))
	# Varren suorat linjat (t = c + k (y - ym)).
	var ym := (y_ank + y_top) / 2.0
	var up_pts := PackedVector2Array()
	var back_pts := PackedVector2Array()
	for q in pts:
		if q.z <= y_top + 0.005:
			back_pts.append(Vector2(q.x, q.z))
			if q.z >= y_ank:
				up_pts.append(Vector2(q.x, q.z))
	var lf := _rail_line(up_pts, gap, ym, 1.0)
	var lb := _rail_line(back_pts, gap, ym, -1.0)
	var t_f := func(y: float) -> float: return lf.y + lf.x * (y - ym)
	var t_b := func(y: float) -> float: return lb.y + lb.x * (y - ym)
	# Kovera kaari: C etulinjan edessä (normaali n_f) säteen päässä, alin kohta, jossa päällinen on säteen päässä C:stä.
	var n_f := Vector2(1.0, -lf.x).normalized()
	var c := Vector2.ZERO
	var b_pt := Vector2.ZERO
	var yy := y_top
	while yy > yc:
		c = Vector2(t_f.call(yy), yy) + n_f * fillet
		b_pt = _poly_near(dorsum, c)
		if b_pt.distance_to(c) <= fillet:
			break
		yy -= 0.0005
	var a_pt := c - n_f * fillet
	# Takajohde monikulmiona ylhäältä: linja, kantakaari (suurin säde, jonka sisään kannan kärjet mahtuvat) ja pohja.
	var n_b := Vector2(1.0, -lb.x).normalized()
	var rb := 0.004
	var cb := Vector2.ZERO
	for j in 24:
		var r := 0.05 - j * 0.002
		var yb := y_welt + r
		cb = Vector2(t_b.call(yb), yb) + n_b * r
		var ok := true
		for q in back_pts:
			if q.y < cb.y and q.x < cb.x and q.distance_to(cb) > r - 0.002:
				ok = false
				break
		if ok:
			rb = r
			break
	cb = Vector2(t_b.call(y_welt + rb), y_welt + rb) + n_b * rb
	var back := PackedVector2Array([Vector2(t_b.call(y_top + 0.05), y_top + 0.05)])
	var a0 := (-n_b).angle()
	var a1 := Vector2.DOWN.angle()
	for j in 9:
		back.append(cb + Vector2.from_angle(lerp_angle(a0, a1, j / 8.0)) * rb)
	back.append(Vector2(at[at.size() - 1] + 0.2, y_welt))
	var planes := []  # [Pf, Pb, λ]
	# Varsi: Pf etulinjalla, suunta (Pf -> Pb) kääntyy vaakasuorasta A:n suuntaan (A - C).
	var e_a := (a_pt - c).normalized()
	var phi := Vector2.LEFT.angle_to(e_a)
	var nsh := maxi(int(ceil((y_top - a_pt.y) / 0.018)), 2)
	for j in nsh:
		var u := float(j) / nsh
		var yf := lerpf(y_top, a_pt.y, u)
		var pf := Vector2(t_f.call(yf), yf)
		planes.append([pf, _poly_ray(back, pf, Vector2.LEFT.rotated(phi * u))[0], 1.0])
	# Siirtymä: Pb takajohteella kaarenpituuden mukaan A:n ja B:n säteiden välissä, Pf kaarella.
	var e_b := (b_pt - c).normalized()
	var ha := _poly_ray(back, a_pt, e_a)
	var hb := _poly_ray(back, b_pt, e_b)
	var nfan := maxi(int(ceil((float(hb[1]) - float(ha[1])) / step)), 2)
	var ang := e_a.angle_to(e_b)
	for j in nfan + 1:
		var pb := _poly_at(back, lerpf(ha[1], hb[1], float(j) / nfan))
		var e := (pb - c).normalized()
		var u := clampf(e_a.angle_to(e) / ang, 0.0, 1.0) if absf(ang) > 1e-4 else 1.0
		planes.append([c + e * fillet, pb, 1.0 - smoothstep(0.0, 1.0, u)])
	# Jalkaterä: pystytasot B:n edessä; kaksi ensimmäistä kääntyvät B:n normaalista pystyyn.
	var nfoot := 0
	for i in SLICES:
		var t := at[i]
		if t <= b_pt.x + step * 0.3:
			continue
		var pf := Vector2(t, _at(at, dn, t))
		var e := e_b.lerp(Vector2.DOWN, smoothstep(0.0, 1.0, (t - b_pt.x) / (2.0 * step))).normalized()
		planes.append([pf, pf + e * (pf.y - y_welt) / maxf(-e.y, 1e-3), 0.0])
		nfoot += 1
	var crossed := 0
	for i in planes.size() - 1:
		if Geometry2D.segment_intersects_segment(planes[i][0], planes[i][1], planes[i + 1][0], planes[i + 1][1]) != null:
			crossed += 1
	# Leveys ja keskiviiva ikkunan kärjistä tason koordinaateissa (s, v), v = (q - Pb) · b.
	var sels := []
	var sc := PackedFloat32Array()
	for pl in planes:
		var o: Vector2 = pl[1]
		var dd: float = (pl[0] - o).length()
		var b: Vector2 = (pl[0] - o) / dd
		var sel := PackedVector2Array()
		var lo := INF
		var hi := -INF
		for q in pts:
			var d := Vector2(q.x - o.x, q.z - o.y)
			var v := d.dot(b)
			if v < -0.01 or v > dd + 0.01 or absf(d.x * b.y - d.y * b.x) > win:
				continue
			sel.append(Vector2(q.y, v))
			lo = minf(lo, q.y)
			hi = maxf(hi, q.y)
		sels.append(sel)
		sc.append((lo + hi) / 2.0 if lo <= hi else (sc[sc.size() - 1] if sc.size() > 0 else 0.0))
	for it in 3:
		sc = _smooth(sc)
	var out := []
	var wn := PackedFloat32Array()
	var wy := PackedVector2Array()
	for i in planes.size():
		var lam: float = planes[i][2]
		var o: Vector2 = planes[i][1]
		var dd: float = (planes[i][0] - o).length()
		var b: Vector2 = (planes[i][0] - o) / dd
		var af := lerpf(B_LOW, dd / 2.0, lam)
		var an := dd - af
		var n := lerpf(SE_N, SHAFT_N, lam)
		var need := 0.0
		for q: Vector2 in sels[i]:
			var dy := q.y - af
			var r := clampf(absf(dy) / (an if dy > 0.0 else af), 0.0, 0.95)
			need = maxf(need, absf(q.x - sc[i]) / pow(1.0 - pow(r, n), 1.0 / n))
		wn.append(need + margin + pad * lam)
		if i < nsh:
			wy.append(Vector2(wn[i], o.y))
		var vfl: float = (y_welt - o.y) / b.y if b.y > 1e-4 else -INF
		out.append([o, b, sc[i], af, 0.0, an, af, n, vfl])
	var lw := _rail_line(wy, 0.0, ym, 1.0)  # varren leveys suoraksi (pienin suora tarpeen yläpuolella)
	for i in nsh:
		wn[i] = lw.y + lw.x * (out[i][0].y - ym)
	var wd := _envelope(wn)
	for i in out.size():
		out[i][4] = wd[i]
	return {"slices": out, "nshaft": nsh, "nfan": nfan + 1, "nfoot": nfoot, "crossed": crossed, "a": a_pt, "b": b_pt, "c": c}


## Pienin suora t = c + k (y - ym) (k = -0,3..0,3), jonka etupuolelle (sgn 1) tai takapuolelle (sgn -1) kaikki pisteet
## (t, y) jäävät raon gap päähän. Pienin = keskimmäisen korkeuden t lähimpänä pisteitä. Palauttaa (k, c).
static func _rail_line(pl: PackedVector2Array, gap: float, ym: float, sgn: float) -> Vector2:
	var best := Vector2(0.0, INF)
	for j in range(-60, 61):
		var k := j * 0.005
		var c := -INF
		for q in pl:
			c = maxf(c, sgn * (q.x - k * (q.y - ym)) + gap)
		if c < best.y:
			best = Vector2(k, c)
	return Vector2(best.x, best.y * sgn)


## Monikulmion pl lähin piste pisteelle p.
static func _poly_near(pl: PackedVector2Array, p: Vector2) -> Vector2:
	var best := pl[0]
	for i in pl.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, pl[i], pl[i + 1])
		if q.distance_squared_to(p) < best.distance_squared_to(p):
			best = q
	return best


## Säde p + e·x monikulmioon pl: [osumapiste, kaarenpituus monikulmion alusta] (ensimmäinen osuma säteellä).
static func _poly_ray(pl: PackedVector2Array, p: Vector2, e: Vector2) -> Array:
	var far := p + e * 2.0
	var s := 0.0
	var best := [pl[pl.size() - 1], INF, 0.0]
	for i in pl.size() - 1:
		var hit = Geometry2D.segment_intersects_segment(p, far, pl[i], pl[i + 1])
		if hit != null and (hit - p).length() < best[1]:
			best = [hit, (hit - p).length(), s + (hit - pl[i]).length()]
		s += (pl[i + 1] - pl[i]).length()
	return [best[0], best[2]]


## Monikulmion pl piste kaarenpituudella s.
static func _poly_at(pl: PackedVector2Array, s: float) -> Vector2:
	for i in pl.size() - 1:
		var l := (pl[i + 1] - pl[i]).length()
		if s <= l:
			return pl[i].lerp(pl[i + 1], s / maxf(l, 1e-6))
		s -= l
	return pl[pl.size() - 1]


## Poikkileikkaus tason koordinaateissa (s, v): superellipsi (eksponentti n) keskipisteestä (sc, vc), puolileveys w,
## lähipuoli an (+v, k = RING / 4: jalan päällinen, taite, säären etu) ja kaukopuoli af; v vähintään vfloor (lattia).
## _ring_at:n yleistys (sama kehän indeksointi).
static func _ring_se(sc: float, vc: float, w: float, an: float, af: float, n: float, vfloor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in RING:
		var a := TAU * k / RING
		var x := signf(cos(a)) * pow(absf(cos(a)), 2.0 / n)
		var y := signf(sin(a)) * pow(absf(sin(a)), 2.0 / n)
		out.append(Vector2(sc + w * x, maxf(vc + (an if y > 0.0 else af) * y, vfloor)))
	return out


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
	var worst := -INF
	var above: PackedInt32Array = shoe.get_meta("suu", PackedInt32Array())
	var vv: Vector3 = shoe.get_meta("varsi_v", Vector3.ZERO)  # (yläreuna, jalkaosan suu, -); 0 = ei vartta
	var boot: bool = shoe.get_meta("saapas", false)
	for v in vs.size():
		var c := roundi(cs[v].r * 4.0)
		# Varsi: jalkaosan suun yläpuolinen jalkaterä sekä sääri ja lahje varren yläreunaan asti mitataan varren ulkopintaa vastaan.
		var in_shaft := vv.x > 0.0 and c != 1 and ((c == 3 and v in above) or (c != 3 and vs[v].y >= vv.y and vs[v].y <= vv.x))
		if boot:  # saapas: jalkaterä, sääri ja lahje yläreunan alle mitataan yhtä kuorta (osa 0) vasten
			in_shaft = false
			if c == 1 or vs[v].y > vv.x - 0.02:
				continue
		elif not in_shaft and (c != 3 or v in above):
			continue
		# Lähin päällisen piste (osa 0) ja sen normaali: ihon kärki on ulkona, jos se on pinnan ulkopuolella. Pohja (osa 1)
		# ohitetaan: sen reunuksen sisäpuolen yläreuna osoittaa ylös ja mittasi korkeutta, ei ulkonemaa (A2 M0a).
		var best := INF
		var bj := -1
		for j in sv.size():
			if (su2[j].y > 0.5) if not in_shaft else (su2[j].y < 1.5 or su2[j].y > 2.1):
				continue
			var d := vs[v].distance_squared_to(sv[j])
			if d < best:
				best = d
				bj = j
		var n: Vector3 = (sa[Mesh.ARRAY_NORMAL] as PackedVector3Array)[bj]
		worst = maxf(worst, (vs[v] - sv[bj]).dot(n))
	return worst
