extends RefCounted
## Anatomia, moduuli "jalat" (rekisteri: anatomia.gd), osa B: realistisemmat jalkaterät ja ranteen värireuna.
## deform(ctx): pisteiden siirto lepoasennossa + maskit COLOR.r:n murto-osaan (CUSTOM1.a ei saavuta varjostinta Compatibility-
## renderöijässä, ks. anatomia_kadet.gd _code_r). attach(ctx): ei lisäverkkoja. pose(ch): ei muutoksia (luut ennallaan).
##
## RANNE: käden ja kyynärvarren värireuna. Käden pisteet ovat luokkaa 0 (iho) ja kyynärvarren hihaluokkaa 1, joten luokka
## interpoloituu ranteen kolmioissa ja reuna seuraa verkon sahalaitaa; lisäksi käden tekstuuri-iho (t.rgb) ja paljaan kyynärvarren
## tasainen iho (bare_skin) eroavat sävyltään. Korjaus: deform antaa käden pisteille kyynärvarren luokan (ei interpolaatiota
## luokkien välillä), ja varjostin (anat_class_jalat) jakaa luokan fragmentissa lepoasennon x:stä (ranteen luu): sen ulkopuoli on
## kättä (luokka 0), sisäpuoli kyynärvartta. Käden väri = kyynärvarren väri, kun kyynärvarsi on paljas (character.gdshader).

## Ranteen lepo-x (|hand.x| lepoasennossa, mitattu Character-deformin joints-taulusta, m).
const WRIST_X := {"male": 0.7065, "female": 0.6411}
const HAND_BONES := ["hand", "thumb_01", "thumb_02", "thumb_03", "index_01", "index_02", "index_03", "middle_01", "middle_02",
	"middle_03", "ring_01", "ring_02", "ring_03", "pinky_01", "pinky_02", "pinky_03", "thumb_04_leaf", "index_04_leaf",
	"middle_04_leaf", "ring_04_leaf", "pinky_04_leaf"]


static func deform(ctx: Dictionary) -> void:
	_wrist_class(ctx)
	if float(ctx.shape.get("anat_arch", 0.0)) > 0.5:
		_arch(ctx)


## Jalkaholvi ja nilkkaluut vain paljaalle jalalle (shape.anat_arch; kengät rakennetaan Shoes.buildilla muuttamattomasta verkosta,
## koska verkon välimuistiavain ei sisällä kenkätyyppiä, joten kengälliset hahmot saavat alkuperäisen jalkaverkon). Siirrot vain
## ylöspäin ja vain keskijalalle (kantapää ja päkiä ennallaan), joten jalan alin piste ei muutu. Luokan 3 pisteet, positiofunktio.
const ARCH_MM := 0.007  ## sisäholvin nosto (m)
const MALLEOLUS := 0.003  ## nilkkaluiden ulkonema (m)


static func _arch_shift(p: Vector3, fx: float, fy: float, fz: float, bz: float) -> Vector3:
	var d := Vector3.ZERO
	var ax := absf(p.x)
	# sisäholvi: keskijalan pohja (z kantapään ja päkiän välissä), mediaalipuoli (lähempänä keskilinjaa) korkeampi
	var zt := smoothstep(fz + 0.01, fz + 0.055, p.z) * (1.0 - smoothstep(bz - 0.055, bz - 0.01, p.z))
	var med := 0.35 + 0.65 * smoothstep(fx + 0.025, fx - 0.03, ax)
	var wy := 1.0 - smoothstep(0.006, 0.045, p.y)
	d.y += ARCH_MM * zt * med * wy
	# nilkkaluut: sisä (mediaalinen) ja ulko (lateraalinen) nilkkaluu, ulos x-suunnassa
	for side in [-1.0, 1.0]:
		var cx: float = fx + side * 0.033
		var q := Vector3((ax - cx) / 0.02, (p.y - (fy - 0.006)) / 0.022, (p.z - (fz - 0.004)) / 0.022)
		var gk := exp(-q.length_squared())
		d.x += signf(p.x) * MALLEOLUS * (1.0 if side > 0.0 else 0.8) * gk * side
	return d


static func _arch(ctx: Dictionary) -> void:
	var arr: Array = ctx.arr
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var j: Dictionary = ctx.joints
	if not j.has("foot_l") or not j.has("ball_l"):
		return
	var fo: Vector3 = j["foot_l"]
	var ba: Vector3 = j["ball_l"]
	var fx := absf(fo.x)
	var h := 0.003
	for v in vs.size():
		var p := vs[v]
		if p.y > 0.12 or roundi(cols[v].r * 4.0) != 3:
			continue
		var d := _arch_shift(p, fx, fo.y, fo.z, ba.z)
		if d.length_squared() < 1e-12:
			continue
		var jx := (_arch_shift(p + Vector3(h, 0, 0), fx, fo.y, fo.z, ba.z) - d) / h
		var jy := (_arch_shift(p + Vector3(0, h, 0), fx, fo.y, fo.z, ba.z) - d) / h
		var jz := (_arch_shift(p + Vector3(0, 0, h), fx, fo.y, fo.z, ba.z) - d) / h
		var m := Basis(Vector3(1, 0, 0) + jx, Vector3(0, 1, 0) + jy, Vector3(0, 0, 1) + jz)
		vs[v] = p + d
		if m.determinant() > 0.2:
			ns[v] = (m.inverse().transposed() * ns[v]).normalized()
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns


## Käden pisteille kyynärvarren luokka (yleisin luokka kyynärvarren pisteillä ranteen tuntumassa).
static func _wrist_class(ctx: Dictionary) -> void:
	var arr: Array = ctx.arr
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var vbone: PackedStringArray = ctx.vbone
	var hand := {}
	for lr in ["_l", "_r"]:
		for b in HAND_BONES:
			hand[b + lr] = true
	var wx: float = WRIST_X["female" if ctx.kind == "female" else "male"]
	var counts := {}
	for v in vs.size():
		var bn := vbone[v]
		if bn == "lowerarm_l" or bn == "lowerarm_r":
			if absf(vs[v].x) > wx - 0.07:
				var k := roundi(cols[v].r * 4.0)
				counts[k] = int(counts.get(k, 0)) + 1
	var cls := 0
	var best := 0
	for k in counts:
		if counts[k] > best:
			best = counts[k]
			cls = k
	if cls == 0:
		return
	for v in vs.size():
		if hand.has(vbone[v]):
			var c := cols[v]
			var frac := c.r * 4.0 - roundf(c.r * 4.0)  # käsimaskin koodi (anatomia_kadet.gd)
			c.r = (float(cls) + frac) / 4.0
			cols[v] = c
	arr[Mesh.ARRAY_COLOR] = cols


## Varpaiden pallon lepo-z (ball-luu, mitattu joints-taulusta): varpaat ovat sen edessä.
const BALL_Z := {"male": 0.0547, "female": 0.0618}
static var _toe_cache := {}


## Varpaankynsien paikat lepoavaruudessa (varjostimen anat_toes: x, y, z, leveyssäde) * 10, oikea jalka ensin; haetaan
## jalkaterän (luokka 3) pisteistä kuten sandaalin kynnet (shoes.gd): kärjen pisteet jaetaan viiteen ryhmään lateraalisuunnassa
## (k-means), kullekin kynsi kärkiosan päällepuolelle. Lepoavaruus ei riipu muodosta (pituus, vyötärö), joten tulos kerran / malli.
static func toe_nails(kind: String, mesh: ArrayMesh) -> Array[Vector4]:
	if _toe_cache.has(kind):
		return _toe_cache[kind]
	var out: Array[Vector4] = []
	var arr := mesh.surface_get_arrays(0)
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	var c0: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
	var bz: float = BALL_Z[kind if BALL_Z.has(kind) else "male"]
	for side in [-1.0, 1.0]:
		var pts: Array[Vector3] = []  # rest (x, y, z)
		var tmax := -INF
		for v in cols.size():
			if roundi(cols[v].r * 4.0) != 3 or signf(uv2[v].x) != side:
				continue
			var z := c0[v * 4]
			if z > bz:
				pts.append(Vector3(uv2[v].x, uv2[v].y, z))
				tmax = maxf(tmax, z)
		var front: Array[Vector3] = []
		var lo := INF
		var hi := -INF
		for q in pts:
			if q.z > tmax - 0.04:
				front.append(q)
				lo = minf(lo, q.x)
				hi = maxf(hi, q.x)
		var cen := PackedFloat32Array()
		for k in 5:
			cen.append(lerpf(lo, hi, (k + 0.5) / 5.0))
		var grp: Array = []
		for it in 12:
			grp = [[], [], [], [], []]
			for q in front:
				var bk := 0
				for k in 5:
					if absf(q.x - cen[k]) < absf(q.x - cen[bk]):
						bk = k
				grp[bk].append(q)
			for k in 5:
				if not grp[k].is_empty():
					var m := 0.0
					for q: Vector3 in grp[k]:
						m += q.x
					cen[k] = m / grp[k].size()
		for k in 5:
			var g: Array = grp[k]
			if g.is_empty():
				out.append(Vector4(0, 0, 0, 0))
				continue
			var tip := -INF
			for q: Vector3 in g:
				tip = maxf(tip, q.z)
			var sx := 0.0
			var top := -INF
			var xl := INF
			var xh := -INF
			var n := 0
			for q: Vector3 in g:
				if q.z > tip - 0.014:
					sx += q.x
					top = maxf(top, q.y)
					xl = minf(xl, q.x)
					xh = maxf(xh, q.x)
					n += 1
			var rx := clampf((xh - xl) * 0.46, 0.0028, 0.0085)
			out.append(Vector4(sx / n, top, tip - 0.0015 - rx, rx))
	_toe_cache[kind] = out
	return out


static func attach(_ctx: Dictionary) -> Array:
	return []


static func pose(_ch: Node3D) -> void:
	pass
