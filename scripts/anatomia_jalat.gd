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
