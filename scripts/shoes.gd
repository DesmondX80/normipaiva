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
const DOME := 3  # pyöristysrenkaita kummassakin päässä (kärki ja kanta)

## Tyyppien parametrit (metrejä mallin mittakaavassa): sole = pohjan paksuus, margin = kuoren rako ihoon, flare = pohjan
## reunan ulottuma kuoren ohi, sole_col = pohjan väri, rough = päällisen karheus, sole_rough = pohjan karheus.
## "paljas" = ei kenkää (vartalon jalkaterä värjätään kuten ennenkin).
const TYPES := {
	"lenkkari": {"sole": 0.020, "margin": 0.003, "flare": 0.004, "sole_col": Color(0.95, 0.94, 0.9), "rough": 0.62,
		"sole_rough": 0.8},
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
	for side: float in [1.0, -1.0]:
		var foot := PackedInt32Array()  # jalkaterän kärjet (luokka 3)
		var cand := PackedInt32Array()  # painojen lähteet: jalkaterä ja säären alaosa
		for v in vs.size():
			if signf(vs[v].x) != side:
				continue
			var c := roundi(cs[v].r * 4.0)
			if c == 3:
				foot.append(v)
				cand.append(v)
			elif c == 2 and vs[v].y < 0.25:
				cand.append(v)
		pohja = _build_side(st, p, vs, bi, bw, per, foot, cand, side, skin, skel)
	st.index()
	st.generate_normals()
	var out := st.commit()
	out.set_meta("pohja", pohja)
	return out


## Yhden jalan kuori ja pohja. Palauttaa pohjan alimman kohdan etäisyyden jalkapohjan alimmasta kärjestä.
static func _build_side(st: SurfaceTool, p: Dictionary, vs: PackedVector3Array, bi: PackedInt32Array, bw: PackedFloat32Array,
		per: int, foot: PackedInt32Array, cand: PackedInt32Array, side: float, skin: Skin, skel: Skeleton3D) -> float:
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
	# Poikkileikkaukset: tukifunktio (kuperan verhon etäisyys keskeltä kuhunkin suuntaan) + rako.
	var rings := []  # [t, keskipiste Vector2(s, y), PackedVector2Array (s, y)]
	for i in SLICES:
		var t := tmin + step * (i + 0.5)
		var sel := PackedVector2Array()
		for q in pts:
			if absf(q.x - t) <= win:
				sel.append(Vector2(q.y, q.z))
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
			r.y = maxf(r.y, y_welt)
			ring.append(r)
		rings.append([t, c, ring])
	_smooth(rings, y_welt)
	# Pyöristys päihin: renkaat kutistuvat keskipisteeseen neljännesympyrän mukaan (kärki ja kanta kaartuvat).
	var full := []
	for end in [0, 1]:
		var e: Array = rings[0] if end == 0 else rings[rings.size() - 1]
		var ext: float = (float(e[0]) - tmin if end == 0 else tmax - float(e[0])) + margin
		var dir := -1.0 if end == 0 else 1.0
		var dome := []
		for j in range(DOME, 0, -1):
			var phi := PI / 2.0 * j / (DOME + 1)
			var sc := cos(phi)
			var ring := PackedVector2Array()
			for r: Vector2 in e[2]:
				ring.append(e[1] + (r - e[1]) * sc)  # alapinta kaartuu ylös kärkeä kohti
			dome.append([float(e[0]) + dir * ext * sin(phi), e[1], ring, sc])
		if end == 0:
			full.append_array(dome)
		else:
			full.append_array(rings)
			dome.reverse()
			full.append_array(dome)
	var t0: float = float(rings[0][0]) - (float(rings[0][0]) - tmin + margin)
	var t1: float = float(rings[-1][0]) + (tmax - float(rings[-1][0]) + margin)
	var tip0: Vector2 = rings[0][1]
	var tip1: Vector2 = rings[-1][1]
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
	# Pohja: pyöristetty laatta kuoren leveimmän kohdan mukaan, yläreuna 6 mm kuoren sisällä (ei rakoa), alapinta tasainen.
	var flare: float = p.flare
	var y_top := y_welt + 0.006
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
		var pr := PackedVector2Array([Vector2(mid + hw - flare * 0.5, y_top), Vector2(mid + hw, y_top - bv),
			Vector2(mid + hw, y_bot + bv), Vector2(mid + hw - bv, y_bot), Vector2(mid - hw + bv, y_bot),
			Vector2(mid - hw, y_bot + bv), Vector2(mid - hw, y_top - bv), Vector2(mid - hw + flare * 0.5, y_top)])
		prof.append([base[0], Vector2(mid, (y_top + y_bot) / 2.0), pr])
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
	for v in vs.size():
		if roundi(cs[v].r * 4.0) != 3:
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
