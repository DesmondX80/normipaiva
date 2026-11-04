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
## pad = varren paksuus ihon ja raon päälle, skirt = helma: varsi alkaa näin paljon joinin alapuolelta kuoren kyljestä}.
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
		"shaft": {"join": 0.07, "top": 0.13, "pad": 0.006, "skirt": 0.018}},
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
	var helma := {}  # varren helman mittaus (+X-jalka; testi)
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
		var shell := {}  # kuoren renkaat ja painojen lähteet (varren helma mitataan ja painotetaan niistä)
		pohja = _build_side(st, p, vs, bi, bw, per, foot, cand, pant, side, skin, skel, above, shell)
		if p.has("shaft"):
			varsi = _build_shaft(st, p, vs, arr[Mesh.ARRAY_TEX_UV2], cs, bi, bw, per, foot, side, skin, skel, shell)
			if side > 0.0:
				helma = shell.mitta
	st.index()
	st.generate_normals()
	var out := st.commit()
	out.set_meta("pohja", pohja)
	out.set_meta("suu", above)
	out.set_meta("karki", _tip_h)
	out.set_meta("varsi", varsi.x)  # 0 = ei vartta; character.gdshader shoe_top (lahje varren sisään)
	out.set_meta("varsi_v", Vector3(varsi.y, varsi.z, varsi.w))  # skin_outside ja testi
	out.set_meta("helma", helma)  # testi: KENKA helma
	return out


## Yhden jalan kuori ja pohja. Palauttaa pohjan alimman kohdan etäisyyden jalkapohjan alimmasta kärjestä.
static func _build_side(st: SurfaceTool, p: Dictionary, vs: PackedVector3Array, bi: PackedInt32Array, bw: PackedFloat32Array,
		per: int, foot: PackedInt32Array, cand: PackedInt32Array, pant: PackedInt32Array, side: float, skin: Skin,
		skel: Skeleton3D, above: PackedInt32Array, shell: Dictionary) -> float:
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
	var rings := []  # [t, keskipiste Vector2(s, y), PackedVector2Array (s, y), leveyden kerroin pohjalle]
	for i in at.size():
		if at[i] < ta - step * 0.3:
			rings.append([at[i], Vector2(sc[i], yc), _ring_at(sc[i], yc, wd[i], hu[i], maxf(cap[i], y_welt)), 1.0])
	var toe := []
	for j in TOE_RINGS:
		var t := ta + (tend - ta) * sin(PI / 2.0 * j / TOE_RINGS)
		var f := _toe_f(t, ta, tend, toe_n)
		var ring := PackedVector2Array()
		for q: Vector2 in ring_a:
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
	shell.merge({"up": up, "tips": [to3.call(t0, tip0), to3.call(t1, tip1)], "cand": cand, "ball_bind": ball_bind, "tb": tb,
		"org": org, "fwd": fwd, "lat": lat, "t1": t1})
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
	return ymin - y_bot


## Varsi (työkenkä, kuukenkä): pystyputki säären ympärillä helmasta (skirt joinin alapuolella kuoren kyljessä, kuoren
## leikkauksesta mitattuna, joten kuoren kupu jää varren sisään) varren yläreunaan (top).
## Vaakarenkaat ovat neljän puoliakselin superellipsejä (etu +t, taka, sivut ±s) säären keskipisteestä; puoliakselit
## mitataan kärjistä (kaikki paitsi paita, join - margin:n yläpuolella, joten alin rengas peittää jalkaosan suun) ja
## tasoitetaan _envelope:lla. Yläreunassa pehmustettu reuna ja rengaslevy sääreen, sisäpinta hieman alas; pohja viuhkana.
## UV = (kulma: 0 = etu, -0,5..0,5, saumaton takana; korkeus y_weltistä), UV2 = (sivu -1..1, + = ulkosivu; osa 2).
## Palauttaa Vector4(yläreuna UV2-avaruudessa, yläreuna verkossa, jalkaosan suu verkossa, UV2.y - y yläreunassa).
static func _build_shaft(st: SurfaceTool, p: Dictionary, vs: PackedVector3Array, uv2: PackedVector2Array, cs: PackedColorArray,
		bi: PackedInt32Array, bw: PackedFloat32Array, per: int, foot: PackedInt32Array, side: float, skin: Skin,
		skel: Skeleton3D, shell: Dictionary) -> Vector4:
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
	var y0 := yj + 0.012  # alin säären mukaan mitattu rengas; sen alla helmarivit (ys .. yj)
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
	# Helma: varsi alkaa skirt-mitan joinin alapuolelta kuoren kyljestä (kylki on siellä vielä pysty) ja kulkee kuoren
	# kuvun olan ulkopuolelta sääreen, joten kupu jää varren sisään. Helmarivin säde suunnassa k on kuoren vaakaleikkauksen
	# kaukaisin osuma (_slice, _ray_hit) tällä ja ylemmillä riveillä (leveys ei kapene alaspäin), alin rivi tasan kuoren
	# pinnassa, muut eps = 1 mm ulompana (jänteen painuma kuoren kaarella). Ei kapeampi kuin säären tarve (alin rengas).
	var c0 := Vector2(ct[0], cl[0])
	var se0: PackedVector2Array = rows[0][2]
	var skirt: float = sh.get("skirt", 0.0)
	var ys := yj - skirt
	var nsk := maxi(ceili(skirt / 0.006 - 0.01), 1)
	var hh := PackedFloat32Array()
	for j in nsk + 1:
		hh.append(ys + skirt * j / nsk)
	var dirs := PackedVector2Array()
	var need := PackedFloat32Array()
	for k in RING:
		dirs.append((se0[k] - c0).normalized())
		need.append((se0[k] - c0).length())
	var cut := []  # [rivi][k] kuoren leikkauksen säde (-1 = ei osumaa)
	var hits_max := 0
	for j in nsk + 1:
		var segs := _slice(shell, minf(hh[j], yj - 0.0005))  # tasolla join kansi on vaakasuora: leikataan hieman alempaa
		var rr := PackedFloat32Array()
		for k in RING:
			var hit := _ray_hit(segs, c0, dirs[k])
			rr.append(hit.x)
			hits_max = maxi(hits_max, int(hit.y))
		cut.append(rr)
	var hrow := []  # helmarivien säteet [rivi][k]
	for j in nsk + 1:
		var rr := PackedFloat32Array()
		for k in RING:
			var m := need[k]
			for j2 in range(j, nsk + 1):
				m = maxf(m, cut[j2][k])
			rr.append(m + (0.0 if j == 0 else 0.001))
		hrow.append(rr)
	# Pystysuunnassa tasoitus renkaittain k (helma ja varren alarenkaat), ei alle tarpeen; ylin 4 rengasta ennallaan
	# (yläreunan pehmuste ja levy lasketaan niiden mitoista).
	var nlow := SHAFT_RINGS - 4
	for k in RING:
		var col := PackedFloat32Array()
		for j in nsk + 1:
			col.append(hrow[j][k])
		for i in nlow:
			col.append((rows[i][2][k] - rows[i][1]).length())
		var env := _envelope(col)
		for j in nsk + 1:
			hrow[j][k] = maxf(env[j], hrow[j][k]) if j > 0 else hrow[j][k]
		for i in nlow:
			var ci: Vector2 = rows[i][1]
			var pi: PackedVector2Array = rows[i][2]
			pi[k] = ci + (pi[k] - ci).normalized() * maxf(env[nsk + 1 + i], (pi[k] - ci).length())
			rows[i][2] = pi
	for j in range(nsk, -1, -1):
		var pj := PackedVector2Array()
		for k in RING:
			pj.append(c0 + dirs[k] * hrow[j][k])
		rows.push_front([hh[j], c0, pj, 0])
	var r0p: PackedVector2Array = rows[0][2]
	# Mittaus (testi KENKA helma): kuoren kärjet y > ys varren ulkopuolella omalla korkeudellaan (säde lerp rivien välillä),
	# liitosrako (alin rivi - kuoren leikkaus), kuoren säde sivuilla (±lat) join - 24 .. join mm ja etuosan ulottuma.
	var nout := 0
	var worst := 0.0
	for row: Array in shell.up:
		for q3: Vector3 in row:
			if q3.y <= ys + 1e-5:
				continue
			var d3: Vector3 = q3 - org
			var q := Vector2(d3.dot(fwd), d3.dot(lat)) - c0
			var j := 0
			while j < nsk and hh[j + 1] < q3.y:
				j += 1
			var j2 := mini(j + 1, nsk)
			var f := clampf((q3.y - hh[j]) / maxf(hh[j2] - hh[j], 1e-6), 0.0, 1.0)
			var segs := PackedVector2Array()
			for k in RING:
				for e in [k, (k + 1) % RING]:
					segs.append(c0 + dirs[e] * lerpf(hrow[j][e], hrow[j2][e], f))
			var rs := _ray_hit(segs, Vector2.ZERO + c0, q.normalized()).x
			if rs > 0.0 and q.length() > rs + 1e-5:
				nout += 1
				worst = maxf(worst, q.length() - rs)
	var gap := 0.0
	for k in RING:
		if cut[0][k] > 0.0:
			gap = maxf(gap, hrow[0][k] - cut[0][k])
	var sides := PackedFloat32Array()
	for j in 5:
		var segs := _slice(shell, yj - 0.024 + 0.006 * j - (0.0005 if j == 4 else 0.0))
		for sd in [1.0, -1.0]:
			sides.append(_ray_hit(segs, c0, Vector2(0.0, sd)).x)
	var front: float = cut[0][RING / 2]
	if side > 0.0:  # B2DIAG väliaikainen
		var ln := "B2DIAG k dir.x cut_ys cut_join need gap:"
		for k in RING:
			ln += " %d:%.2f/%.0f/%.0f/%.0f/%.1f" % [k, dirs[k].x, cut[0][k] * 1000.0, cut[nsk][k] * 1000.0, need[k] * 1000.0, (hrow[0][k] - cut[0][k]) * 1000.0]
		print(ln)
	shell["mitta"] = {"ys": ys - ymin, "nout": nout, "worst": worst, "gap": gap, "hits": hits_max, "sides": sides,
		"front": front, "reach": float(shell.t1) - c0.x}
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
		if h < yj - 1e-5:  # helma: samat painot kuin kuorella (liitos pysyy kiinni kävelyssä)
			var tw := clampf(((a - org).dot(fwd) - float(shell.tb) + TOE_BLEND) / (2.0 * TOE_BLEND), 0.0, 1.0) \
				if int(shell.ball_bind) >= 0 else 0.0
			_set_weights(st, a, vs, bi, bw, per, shell.cand, shell.ball_bind, tw)
		else:
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
	# Pohja viuhkana (helman alareunassa kuoren sisällä, ulospäin alas).
	var cen: Vector3 = to3.call(c0, ys - 0.002)
	for k in RING:
		tri.call([to3.call(r0p[k], ys), k, ys], [to3.call(r0p[(k + 1) % RING], ys), k + 1, ys], [cen, k + 0.5, ys], Vector3.DOWN, 2.0)
	return Vector4(y1 + dy_top, y1, yj, dy_top)


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


## Kuoren (shell.up, renkaat 3D-pisteinä, ja päätyviuhkat kärkiin shell.tips) vaakaleikkaus tasolla h: janat (t, s)
## pareittain (jalan kehyksessä org, fwd, lat). Jokainen kolmio, jonka särmä ylittää tason, antaa yhden janan.
static func _slice(shell: Dictionary, h: float) -> PackedVector2Array:
	var up: Array = shell.up
	var org: Vector3 = shell.org
	var fwd: Vector3 = shell.fwd
	var lat: Vector3 = shell.lat
	var tris := []
	for i in up.size() - 1:
		for k in RING:
			var k2 := (k + 1) % RING
			tris.append([up[i][k], up[i][k2], up[i + 1][k]])
			tris.append([up[i][k2], up[i + 1][k2], up[i + 1][k]])
	for end in [0, 1]:
		var i := 0 if end == 0 else up.size() - 1
		for k in RING:
			tris.append([up[i][k], up[i][(k + 1) % RING], shell.tips[end]])
	var out := PackedVector2Array()
	for tr: Array in tris:
		var hits := PackedVector2Array()
		for e in 3:
			var a: Vector3 = tr[e]
			var b: Vector3 = tr[(e + 1) % 3]
			if (a.y - h) * (b.y - h) < 0.0:
				var q := a.lerp(b, (h - a.y) / (b.y - a.y)) - org
				hits.append(Vector2(q.dot(fwd), q.dot(lat)))
		if hits.size() == 2:
			out.append_array(hits)
	return out


## Säteen c + u * dir (dir yksikkövektori) osumat janoihin segs (pareittain): Vector2(kaukaisin u (-1 = ei osumaa), osumia).
static func _ray_hit(segs: PackedVector2Array, c: Vector2, dir: Vector2) -> Vector2:
	var best := -1.0
	var n := 0
	for j in range(0, segs.size(), 2):
		var a := segs[j] - c
		var e := segs[j + 1] - segs[j]
		var den := dir.cross(e)
		if absf(den) < 1e-12:
			continue
		var u := a.cross(e) / den
		var v := a.cross(dir) / den
		if v >= 0.0 and v < 1.0 and u > 0.0:
			best = maxf(best, u)
			n += 1
	return Vector2(best, n)


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
	for v in vs.size():
		var c := roundi(cs[v].r * 4.0)
		# Varsi: jalkaosan suun yläpuolinen jalkaterä sekä sääri ja lahje varren yläreunaan asti mitataan varren ulkopintaa vastaan.
		var in_shaft := vv.x > 0.0 and c != 1 and ((c == 3 and v in above) or (c != 3 and vs[v].y >= vv.y and vs[v].y <= vv.x))
		if not in_shaft and (c != 3 or v in above):
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
