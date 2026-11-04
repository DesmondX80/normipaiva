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
const TOE_RINGS := 5  # kärjen kapenevat renkaat viimeisen poikkileikkauksen edessä
const TOE_N := 2.5  # kärjen superellipsin eksponentti (2 = ellipsi, suurempi = leveämpi kärki)
const TOE_LOW := 0.45  # kärjen kärkipiste kuoren alapinnan ja renkaan keskipisteen välissä (0 = alapinnassa)

## Tyyppien parametrit (metrejä mallin mittakaavassa): sole = pohjan paksuus, margin = kuoren rako ihoon, flare = pohjan
## reunan ulottuma kuoren ohi, toe_room = kärjen tila varpaiden edessä, toe_round = kärjen pyöristyksen pituus
## (osuus kärjen puolileveydestä), sole_col = pohjan väri, rough = päällisen karheus, sole_rough = pohjan karheus.
## "paljas" = ei kenkää (vartalon jalkaterä värjätään kuten ennenkin).
const TYPES := {
	"lenkkari": {"sole": 0.020, "margin": 0.003, "flare": 0.004, "toe_room": 0.015, "toe_round": 1.3, "collar": 0.012,
		"sole_col": Color(0.95, 0.94, 0.9), "rough": 0.62, "sole_rough": 0.8},
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
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS if per <= 4 else SurfaceTool.SKIN_8_WEIGHTS)
	var pohja := 0.0
	var above := PackedInt32Array()  # jalkaterän kärjet kengän suun yläpuolella (lahkeen alla; skin_outside ohittaa)
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
		pohja = _build_side(st, p, vs, bi, bw, per, foot, cand, pant, side, skin, skel, above)
	st.index()
	st.generate_normals()
	var out := st.commit()
	out.set_meta("pohja", pohja)
	out.set_meta("suu", above)
	return out


## Yhden jalan kuori ja pohja. Palauttaa pohjan alimman kohdan etäisyyden jalkapohjan alimmasta kärjestä.
static func _build_side(st: SurfaceTool, p: Dictionary, vs: PackedVector3Array, bi: PackedInt32Array, bw: PackedFloat32Array,
		per: int, foot: PackedInt32Array, cand: PackedInt32Array, pant: PackedInt32Array, side: float, skin: Skin,
		skel: Skeleton3D, above: PackedInt32Array) -> float:
	# Jalan pituusakseli: kannan (foot-luu) ja päkiän (ball-luu) kärkien keskipisteiden erotus vaakatasossa.
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
	var fwd := Vector3(ball.x - heel.x, 0.0, ball.z - heel.z).normalized()  # +Z-suuntainen (mesh-avaruuden etu)
	var lat := Vector3.UP.cross(fwd)  # +X-suuntainen
	var org := Vector3(heel.x, 0.0, heel.z)
	var margin: float = p.margin
	var y_welt := ymin - margin  # kuoren tasainen alapinta
	var y_bot: float = y_welt - float(p.sole)
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
	# Poikkileikkaukset: tukifunktio (kuperan verhon etäisyys keskeltä kuhunkin suuntaan) + rako.
	var rings := []  # [t, keskipiste Vector2(s, y), PackedVector2Array (s, y)]
	for i in SLICES:
		var t := tmin + step * (i + 0.5)
		var sel := PackedVector2Array()
		var cap: float = caps[i]
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
		var c := (lo + hi) / 2.0
		var ring := PackedVector2Array()
		for k in RING:
			var a := TAU * k / RING
			var d := Vector2(cos(a), sin(a))
			var h := -INF
			for q in sel:
				h = maxf(h, (q - c).dot(d))
			var r := c + d * (h + margin + 0.004)  # + tasoituksen kutistuma (_smooth)
			r.y = clampf(r.y, y_welt, maxf(cap, y_welt))
			ring.append(r)
		rings.append([t, c, ring, sel, cap])
	_smooth(rings, y_welt)
	# Pyöreä kärki: kärkiosan renkaat kapenevat superellipsin mukaan (ylhäältä pyöreä, sivulta kaartuva yläpinta) kohti
	# kärkeä tend, joka on toe_room varpaiden edessä. Kavennus tapahtuu keskikohdan ja isovarpaan välin (tip_s, varpaiden
	# kärki ei ole jalan keskellä) ympäri, joten kärki on isovarpaan puolelta suorempi kuten oikeassa kengässä. Peittokorjaus alla
	# työntää kehän takaisin varpaiden ulkopuolelle.
	var last: Array = rings[rings.size() - 1]
	var toe_hw := 0.0
	for q: Vector2 in last[2]:
		toe_hw = maxf(toe_hw, absf(q.x - (last[1] as Vector2).x))
	var tip_s := 0.0
	var ntip := 0
	for q in pts:
		if q.x >= tmax - 0.004:
			tip_s += q.y
			ntip += 1
	tip_s /= maxf(ntip, 1)
	tip_s = lerpf((last[1] as Vector2).x, tip_s, 0.5)  # puoliväliin: kärki pyöreä eikä kiila isovarpaan puolelle
	var tend := tmax + margin + float(p.get("toe_room", 0.0))
	var ta := tend - toe_hw * float(p.get("toe_round", 1.0))
	for r in rings:
		r[2] = _toe_scale(r[2], Vector2(tip_s, lerpf(y_welt, (r[1] as Vector2).y, TOE_LOW)), _toe_f(float(r[0]), ta, tend), y_welt)
	# Tasoituksen jälkeen jokainen kehän piste vähintään raon verran ikkunan kärkien tukietäisyyden ulkopuolelle. Kärkiosassa
	# (päkiästä tb tai kavennuksen alusta eteenpäin) koko rengas skaalataan yhdellä kertoimella (_fit_scale): pistekohtainen
	# työntö harvan verkon varpaista teki kärjen etupintaan kuoppia.
	var tb := (ball - org).dot(fwd)
	for r in rings:
		var ring := _fit_scale(r[2], r[1], r[3], margin, y_welt) if float(r[0]) >= minf(ta, tb) else _contain(r[2], r[1], r[3], margin)
		for k in ring.size():
			ring[k] = Vector2(ring[k].x, minf(ring[k].y, maxf(float(r[4]), y_welt)))  # suu tasaisena lahkeen alla
		r[2] = ring
		r.resize(3)
	# Pyöristys päihin: kannan renkaat kutistuvat keskipisteeseen neljännesympyrän mukaan, kärki superellipsinä.
	var full := []
	var tip1: Vector2 = rings[-1][1]
	for end in [0, 1]:
		var e: Array = rings[0] if end == 0 else rings[rings.size() - 1]
		if end == 1:
			# Kärki: renkaat viimeisestä renkaasta kärkeen tend, tiheämmin kärjen lähellä (superellipsi kapenee jyrkästi).
			full.append_array(rings)
			var ue := (float(e[0]) - ta) / (tend - ta)
			var fe := maxf(_toe_f(float(e[0]), ta, tend), 0.05)
			var tc := Vector2(tip_s, lerpf(y_welt, (e[1] as Vector2).y, TOE_LOW))
			var ts := PackedFloat32Array()
			for j in range(1, TOE_RINGS + 1):
				ts.append(ta + (1.0 - (1.0 - ue) * pow(1.0 - float(j) / (TOE_RINGS + 1), 2.0)) * (tend - ta))
			for j in ts.size():
				var f := _toe_f(ts[j], ta, tend) / fe
				# Varpaat renkaan kohdalla (puolen renkaanvälin ikkunassa) jäävät kuoren sisään.
				var half := (ts[j] - (float(e[0]) if j == 0 else ts[j - 1])) * 0.5 + 0.001
				var sel := PackedVector2Array()
				for q in pts:
					if absf(q.x - ts[j]) <= half:
						sel.append(Vector2(q.y, q.z))
				var c2: Vector2 = tc + ((e[1] as Vector2) - tc) * f
				full.append([ts[j], c2, _fit_scale(_toe_scale(e[2], tc, f, y_welt), c2, sel, margin, y_welt), f])
			tip1 = tc
			continue
		var ext: float = float(e[0]) - tmin + margin
		var dir := -1.0
		var dome := []
		for j in range(DOME, 0, -1):
			var phi := PI / 2.0 * j / (DOME + 1)
			var sc := cos(phi)
			var ring := PackedVector2Array()
			for r: Vector2 in e[2]:
				var q: Vector2 = e[1] + (r - e[1]) * sc
				q.y = lerpf(q.y, r.y, clampf(1.0 - (r.y - y_welt) / 0.01, 0.0, 1.0))  # alapinta pysyy pohjan päällä
				ring.append(q)
			dome.append([float(e[0]) + dir * ext * sin(phi), e[1], ring, sc])
		full.append_array(dome)
	var t0: float = float(rings[0][0]) - (float(rings[0][0]) - tmin + margin)
	var t1: float = tend
	var tip0: Vector2 = rings[0][1]
	var to3 := func(t: float, q: Vector2) -> Vector3:
		return org + fwd * t + lat * q.x + Vector3.UP * q.y
	var span := t1 - t0
	# Päällinen: renkaat vierekkäin, päät viuhkana.
	var up := []  # [Vector3 paikka, Vector2 (s, y)] renkaittain
	for r in full:
		r[2] = _even(r[2], r[1])
		var row := []
		for q: Vector2 in r[2]:
			row.append(to3.call(r[0], q))
		up.append(row)
	var add := func(a: Vector3, uv: Vector2, uv2: Vector2) -> void:
		st.set_uv(uv)
		st.set_uv2(uv2)
		st.set_color(Color(1, 1, 1, 1))
		_set_weights(st, a, vs, bi, bw, per, cand)
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
	# Pohja: pyöristetty laatta kuoren leveimmän kohdan mukaan, yläreuna kuoren alapinnan tasalla, alapinta tasainen.
	var flare: float = p.flare
	var prof := []  # renkaittain [t, keskipiste, 8 pistettä (s, y)]
	for r in full:
		var lo := INF
		var hi := -INF
		var base: Array = r
		for q: Vector2 in r[2]:
			lo = minf(lo, q.x)
			hi = maxf(hi, q.x)
		var mid := (lo + hi) / 2.0
		var hw := (hi - lo) / 2.0 + flare * (float(r[3]) if r.size() > 3 else 1.0)
		var bv := 0.004
		var yt := y_welt + 0.0015  # kuoren tasaisen alapinnan tasalle (pieni limitys), myös päissä
		var yb := y_bot
		var pr := PackedVector2Array([Vector2(mid + hw - flare * 0.5, yt), Vector2(mid + hw, yt - bv),
			Vector2(mid + hw, yb + bv), Vector2(mid + hw - bv, yb), Vector2(mid - hw + bv, yb),
			Vector2(mid - hw, yb + bv), Vector2(mid - hw, yt - bv), Vector2(mid - hw + flare * 0.5, yt)])
		prof.append([base[0], Vector2(mid, (yt + yb) / 2.0), pr])
	# Pohja jatkuu kuoren kärjen ja kannan alle (kuoren pää on viimeisen renkaan edessä), kapenevana.
	for end in [0, 1]:
		var e: Array = prof[0] if end == 0 else prof[prof.size() - 1]
		var mid: float = e[1].x
		var pr := PackedVector2Array()
		for q: Vector2 in e[2]:
			pr.append(Vector2(mid + (q.x - mid) * 0.55, q.y))
		var row := [(t0 - flare * 0.5) if end == 0 else (t1 + flare * 0.5), e[1], pr]
		if end == 0:
			prof.push_front(row)
		else:
			prof.append(row)
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
		var cen: Vector3 = to3.call(prof[i][0], c2)
		var o := fwd * (-1.0 if end == 0 else 1.0)
		for k in np:
			tri.call(to3.call(prof[i][0], prof[i][2][k]), to3.call(prof[i][0], prof[i][2][(k + 1) % np]), cen, o, 1.0, c2, c2, c2)
	return ymin - y_bot


## Kehän pisteet vähintään raon verran kärkien sel tukietäisyyden ulkopuolelle keskipisteestä c katsoen.
static func _contain(ring: PackedVector2Array, c: Vector2, sel: PackedVector2Array, margin: float) -> PackedVector2Array:
	var out := ring.duplicate()
	if sel.is_empty():
		return out
	for k in out.size():
		var d: Vector2 = (out[k] - c).normalized()
		var h := -INF
		for q in sel:
			h = maxf(h, (q - c).dot(d))
		var need := h + margin - (out[k] - c).dot(d)
		if need > 0.0:
			out[k] += d * need
	return out


## Kärkirengas sisältämään kärjet sel (vähintään raon verran): yksi kerroin k >= 1 koko renkaalle keskipisteen c ympäri
## (k = suurin tarve / säde yli kehän suuntien), joten superellipsin muoto pysyy kuperana ilman kuoppia. Alapinta pysyy.
static func _fit_scale(ring: PackedVector2Array, c: Vector2, sel: PackedVector2Array, margin: float, y_welt: float) -> PackedVector2Array:
	var out := ring
	if sel.is_empty():
		return out
	for it in 3:  # alapuolisko skaalautuu vain sivusuunnassa, joten tarve tarkistetaan uudelleen
		var k := 1.0
		for q in out:
			var rad := (q - c).length()
			if rad < 0.001 or (q - c).y < -0.3 * rad:
				continue  # alapinta: pohja kattaa
			var d := (q - c) / rad
			var h := -INF
			for p in sel:
				h = maxf(h, (p - c).dot(d))
			k = maxf(k, (h + margin) / rad)
		if k <= 1.0001:
			break
		var sc := PackedVector2Array()
		for q in out:
			var d := q - c
			sc.append(Vector2(c.x + d.x * k, maxf(c.y + d.y * k, y_welt)))
		out = sc
	return out


## Rengas uudelleen tasaisin kulmin keskipisteestä c (säteen ja monikulmion leikkaus): työnnöt, skaalaukset ja alapinnan
## rajaus siirtävät pisteitä pois omalta säteeltään, ja niihin kasautuneet lähes päällekkäiset pisteet tummensivat
## kärjen ja alareunan normaaleja kuopiksi.
static func _even(ring: PackedVector2Array, c: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ring.size()
	for k in n:
		var a := TAU * k / n
		var d := Vector2(cos(a), sin(a))
		var best := -1.0
		for i in n:
			var p := ring[i] - c
			var e := ring[(i + 1) % n] - ring[i]
			var den := d.cross(e)
			if absf(den) < 1e-9:
				continue
			var s := p.cross(d) / den  # leikkaus reunalla: p + e * s
			var t := p.cross(e) / den  # säteellä: d * t
			if s >= -1e-4 and s <= 1.0001 and t > best:
				best = t
		out.append(c + d * best if best > 0.0 else ring[k])
	return out


## Kärjen kavennus kohdassa t: 1 ennen ta:ta, superellipsi (eksponentti TOE_N) nollaan kärjessä tend.
static func _toe_f(t: float, ta: float, tend: float) -> float:
	var u := clampf((t - ta) / (tend - ta), 0.0, 1.0)
	return pow(1.0 - pow(u, TOE_N), 1.0 / TOE_N)


## Rengas kavennettuna pisteen c ympäri kertoimella f kaikkiin suuntiin (alapinta ei alle y_weltin). c on matalalla
## (TOE_LOW), joten kärki pyöristyy myös alhaalta: vain sivusuunnassa kavennettu alaosa jäi pystyseinäksi, jonka
## ryppyiset alakulmat näkyivät kärjen etupinnassa kuoppina.
static func _toe_scale(ring: PackedVector2Array, c: Vector2, f: float, y_welt: float) -> PackedVector2Array:
	if f >= 1.0:
		return ring
	var out := PackedVector2Array()
	for q in ring:
		var d := q - c
		out.append(Vector2(c.x + d.x * f, maxf(c.y + d.y * f, y_welt)))
	return out


## Renkaat pehmeiksi: harvan vartaloverkon (noin 400 kärkeä jalassa) tukifunktio on kuhmurainen. Keskipisteet ja
## keskipisteestä mitatut siirrot tasoitetaan kehän ja pituuden suunnassa (1-2-1); rako (margin) kattaa kutistuman, ja
## testi mittaa sen (skin_outside). Alapinta pysyy tasaisena.
static func _smooth(rings: Array, y_welt: float) -> void:
	for it in 2:
		for r in rings:
			var ring: PackedVector2Array = r[2]
			var n := ring.size()
			var sm := PackedVector2Array()
			for k in n:
				sm.append((ring[(k + n - 1) % n] + ring[k] * 2.0 + ring[(k + 1) % n]) / 4.0)
			r[2] = sm
		var offs := []
		var cens := []
		for r in rings:
			var o := PackedVector2Array()
			for q: Vector2 in r[2]:
				o.append(q - (r[1] as Vector2))
			offs.append(o)
			cens.append(r[1])
		for i in rings.size():
			var a := maxi(i - 1, 0)
			var b := mini(i + 1, rings.size() - 1)
			var c: Vector2 = (cens[a] + cens[i] * 2.0 + cens[b]) / 4.0
			var ring := PackedVector2Array()
			for k in (offs[i] as PackedVector2Array).size():
				var q: Vector2 = c + (offs[a][k] + offs[i][k] * 2.0 + offs[b][k]) / 4.0
				q.y = maxf(q.y, y_welt)
				ring.append(q)
			rings[i][1] = c
			rings[i][2] = ring


static func _bone_of(v: int, bi: PackedInt32Array, bw: PackedFloat32Array, per: int, skin: Skin, skel: Skeleton3D) -> String:
	var best := 0
	for k in per:
		if bw[v * per + k] > bw[v * per + best]:
			best = k
	var nm := str(skin.get_bind_name(bi[v * per + best]))
	return nm if nm != "" else skel.get_bone_name(skin.get_bind_bone(bi[v * per + best]))


## Painot kolmesta lähimmästä vartalon kärjestä etäisyydellä painottaen (kenkä taipuu päkiästä kuten iho).
static func _set_weights(st: SurfaceTool, a: Vector3, vs: PackedVector3Array, bi: PackedInt32Array, bw: PackedFloat32Array,
		per: int, cand: PackedInt32Array) -> void:
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
	for v in vs.size():
		if roundi(cs[v].r * 4.0) != 3 or v in above:
			continue
		# Lähin kuoren piste (päällinen tai pohja) ja sen normaali: ihon kärki on ulkona, jos se on pinnan ulkopuolella.
		var best := INF
		var bj := -1
		for j in sv.size():
			var d := vs[v].distance_squared_to(sv[j])
			if d < best:
				best = d
				bj = j
		var n: Vector3 = (sa[Mesh.ARRAY_NORMAL] as PackedVector3Array)[bj]
		worst = maxf(worst, (vs[v] - sv[bj]).dot(n))
	return worst
