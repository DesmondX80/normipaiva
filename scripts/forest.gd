extends Node3D
## Oikea metsä laserkeilauksesta (MML 2011) ja VMI:stä (Luke 2023): mökin ja Vaalan mopomatkan puut
## (tools/kartta/tarkka.py -> assets/*/puut.bin, muoto ONP3). Puut ovat solmun paikallisessa kehyksessä.
##
## Piirto kuten Oulujärven norpissa: MultiMeshien instanssit ovat identiteettejä ja varjostin lukee puun paikan,
## pituuden, latvuksen ja lajin datatekstuurista (forest_tree.gdshaderinc), joten GDScript ei käy puita läpi.
## Tarkkuustaso valitaan puukohtaisesti etäisyydestä katsojaan (globaali lod_eye): lähellä korttilatvukset
## (foliage.gd), keskellä umpimuodot, kaukana perusmuodot. Lähi- ja keskitason lohkot (64 m) tehdään kameran
## ympärille sitä mukaa kuin se liikkuu, kaukotaso (256 m) kerralla. Rungot törmäävät kameran lähilohkoissa.

const Foliage := preload("res://scripts/foliage.gd")
const B := preload("res://scripts/build.gd")

enum { PINE, SPRUCE, BIRCH, ASPEN, BUSH }
const SPECIES := 5
const NEAR_END := 80.0
const MID_END := 420.0
const FAR_END := 2200.0
const MID_RADIUS := 480.0
const COLLIDE_RADIUS := 1
const MIN_COLLIDE_H := 2.5

var count := 0
var far_chunk := 256.0
var near_chunk := 64.0
var origin := Vector2.ZERO
var nfx := 0
var nfz := 0
var nnx := 0
var nnz := 0
var far_tab := PackedInt32Array()
var near_tab := PackedInt32Array()
var data_a := PackedFloat32Array()

var _tex_a: ImageTexture
var _tex_b: ImageTexture
var _meshes := {}
var _built := {}
var _bodies := {}
var _queue: Array[Vector2i] = []
var _last := Vector2i(-99999, -99999)


## Lataa puut tiedostosta ja rakentaa kaukotason. Palauttaa false, jos dataa ei ole.
func load_data(path: String) -> bool:
	set_meta("ground", true)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != "ONP3":
		push_warning("Puudataa ei löydy (%s): aja tools/kartta/mokki_puut.py tai vaala_bake.py." % path)
		return false
	count = f.get_32()
	var w := f.get_32()
	var h := f.get_32()
	far_chunk = f.get_float()
	near_chunk = f.get_float()
	origin = Vector2(f.get_float(), f.get_float())
	nfx = f.get_32()
	nfz = f.get_32()
	nnx = f.get_32()
	nnz = f.get_32()
	far_tab = f.get_buffer(nfx * nfz * SPECIES * 8).to_int32_array()
	near_tab = f.get_buffer(nnx * nnz * SPECIES * 8).to_int32_array()
	var raw_a := f.get_buffer(w * h * 16)
	var raw_b := f.get_buffer(w * h * 4)
	_setup(raw_a, raw_b, w, h)
	return true


## Käsin sijoitetut puut (esim. mökin pihan männyt) samoilla malleilla kuin laserkeilattu metsä:
## trees = [{pos: Vector3 (y = maanpinta solmun kehyksessä), h: pituus m, sp: laji (PINE...)}]. Yksi lähi- ja
## kaukolohko kattaa kaikki puut.
func load_list(trees: Array, seed := 1) -> void:
	set_meta("ground", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var list := trees.duplicate()
	list.sort_custom(func(a, b) -> bool: return a.sp < b.sp)
	count = list.size()
	var lo := Vector2(INF, INF)
	var hi := -lo
	for t in list:
		lo = lo.min(Vector2(t.pos.x, t.pos.z))
		hi = hi.max(Vector2(t.pos.x, t.pos.z))
	origin = lo - Vector2.ONE
	far_chunk = maxf(hi.x - lo.x, hi.y - lo.y) + 2.0
	near_chunk = far_chunk
	nfx = 1
	nfz = 1
	nnx = 1
	nnz = 1
	var tab := PackedInt32Array()
	tab.resize(SPECIES * 2)
	for i in count:
		var sp: int = list[i].sp
		if tab[sp * 2 + 1] == 0:
			tab[sp * 2] = i
		tab[sp * 2 + 1] += 1
	far_tab = tab
	near_tab = tab
	var a := PackedFloat32Array()
	var b := PackedByteArray()
	for t in list:
		var hh: float = t.h
		a.append_array([t.pos.x, t.pos.y, t.pos.z, hh])
		var r: float = clampf((0.35 + 0.085 * hh) if t.sp == SPRUCE else ((0.5 + 0.1 * hh) if t.sp == PINE else 0.6 + 0.12 * hh), 0.4, 5.0)
		b.append_array([clampi(roundi(r * 40.0), 1, 255), t.sp, rng.randi_range(0, 255), rng.randi_range(0, 255)])
	_setup(a.to_byte_array(), b, count, 1)


func _setup(raw_a: PackedByteArray, raw_b: PackedByteArray, w: int, h: int) -> void:
	data_a = raw_a.to_float32_array()
	_tex_a = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBAF, raw_a))
	_tex_b = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, raw_b))
	_make_meshes()
	_build_far()


func _process(_delta: float) -> void:
	if count == 0 or not is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	RenderingServer.global_shader_parameter_set("lod_eye", cam.global_position)
	var p := to_local(cam.global_position)
	var c := Vector2i(floori((p.x - origin.x) / near_chunk), floori((p.z - origin.y) / near_chunk))
	if c != _last:
		_last = c
		var r := int(ceil(MID_RADIUS / near_chunk))
		var want := {}
		for j in range(c.y - r, c.y + r + 1):
			for i in range(c.x - r, c.x + r + 1):
				if i < 0 or j < 0 or i >= nnx or j >= nnz:
					continue
				var mid := origin + Vector2(i + 0.5, j + 0.5) * near_chunk
				if mid.distance_to(Vector2(p.x, p.z)) > MID_RADIUS + near_chunk:
					continue
				var k := Vector2i(i, j)
				want[k] = true
				if not _built.has(k) and not _queue.has(k):
					_queue.append(k)
		for k in _built.keys():
			if not want.has(k):
				for n in _built[k]:
					n.queue_free()
				_built.erase(k)
		_queue = _queue.filter(func(k: Vector2i) -> bool: return want.has(k))
		_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - c).length_squared() < (b - c).length_squared())
		_update_bodies(c)
	for _i in 8:
		if _queue.is_empty():
			break
		var k: Vector2i = _queue.pop_front()
		_built[k] = _build_near_chunk(k)


func _range(tab: PackedInt32Array, chunk: int, sp: int) -> Vector2i:
	var k := (chunk * SPECIES + sp) * 2
	return Vector2i(tab[k], tab[k + 1])


func _aabb(i: int, j: int, size: float) -> AABB:
	return AABB(Vector3(origin.x + i * size, -60.0, origin.y + j * size), Vector3(size, 200.0, size))


func _build_far() -> void:
	for j in nfz:
		for i in nfx:
			for sp in SPECIES:
				var r := _range(far_tab, j * nfx + i, sp)
				if r.y == 0:
					continue
				var mmi := _mmi(_meshes.far[sp], r, _aabb(i, j, far_chunk))
				mmi.visibility_range_begin = maxf(0.0, MID_END - far_chunk * 0.71 - 20.0)
				mmi.visibility_range_end = FAR_END
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mmi)


func _build_near_chunk(k: Vector2i) -> Array:
	var out := []
	for sp in SPECIES:
		var r := _range(near_tab, k.y * nnx + k.x, sp)
		if r.y == 0:
			continue
		var near := _mmi(_meshes.near[sp], r, _aabb(k.x, k.y, near_chunk))
		near.visibility_range_end = NEAR_END + near_chunk * 0.71 + 10.0
		add_child(near)
		var mid := _mmi(_meshes.mid[sp], r, _aabb(k.x, k.y, near_chunk))
		mid.visibility_range_end = MID_END + near_chunk * 0.71 + 10.0
		add_child(mid)
		out.append_array([near, mid])
	return out


## Identiteetti-instanssit; lohkon alku custom datassa kahtena alle 2048 lukuna (yhteensopivuustilassa custom
## data on puolitarkkuutta, eikä instance uniformeja saa olla kuin 4096).
func _mmi(mesh: Mesh, r: Vector2i, aabb: AABB) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = r.y
	var b := PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, r.x % 2048, r.x / 2048, 0, 0])
	while b.size() < r.y * 16:
		b.append_array(b)
	mm.buffer = b.slice(0, r.y * 16)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.custom_aabb = aabb
	return mmi


func _update_bodies(c: Vector2i) -> void:
	var want := {}
	for j in range(c.y - COLLIDE_RADIUS, c.y + COLLIDE_RADIUS + 1):
		for i in range(c.x - COLLIDE_RADIUS, c.x + COLLIDE_RADIUS + 1):
			if i >= 0 and j >= 0 and i < nnx and j < nnz:
				want[Vector2i(i, j)] = true
	for k in _bodies.keys():
		if not want.has(k):
			_bodies[k].queue_free()
			_bodies.erase(k)
	var shape := CylinderShape3D.new()
	shape.radius = 0.22
	shape.height = 4.0
	for k in want:
		if _bodies.has(k):
			continue
		var body := StaticBody3D.new()
		for sp in SPECIES:
			if sp == BUSH:
				continue
			var r := _range(near_tab, k.y * nnx + k.x, sp)
			for i in range(r.x, r.x + r.y):
				if data_a[i * 4 + 3] < MIN_COLLIDE_H:
					continue
				var cs := CollisionShape3D.new()
				cs.shape = shape
				cs.position = Vector3(data_a[i * 4], data_a[i * 4 + 1] + 2.0, data_a[i * 4 + 2])
				body.add_child(cs)
		add_child(body)
		_bodies[k] = body


# --- Puiden mallit --------------------------------------------------------------------------------------------

func _mat(shader: String, params: Dictionary, ref_h: float, ref_r: float) -> ShaderMaterial:
	var p := params.duplicate()
	p.merge({"tree_a": _tex_a, "tree_b": _tex_b, "ref_h": ref_h, "ref_r": ref_r})
	return B.shader_mat(shader, p)


static func _lod(am: ArrayMesh, lo: float, hi: float) -> ArrayMesh:
	for i in am.get_surface_count():
		var m: ShaderMaterial = am.surface_get_material(i).duplicate()
		m.set_shader_parameter("lod_min", lo)
		m.set_shader_parameter("lod_max", hi)
		am.surface_set_material(i, m)
	return am


static func _combine(parts: Array) -> ArrayMesh:
	var am := ArrayMesh.new()
	for part in parts:
		var st := SurfaceTool.new()
		st.append_from(part[0], 0, Transform3D(Basis(), part[1]))
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, part[2])
	return am


static func _flat_sphere(r: float, hgt: float, seg := 8) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = hgt * 2.0
	s.radial_segments = seg
	s.rings = maxi(3, seg / 2)
	return s


func _make_meshes() -> void:
	var solid := "res://shaders/forest_solid.gdshader"
	var card := "res://shaders/forest_card.gdshader"
	var spec := {
		PINE: {"h": 10.5, "r": 2.0, "crown": Color(0.24, 0.38, 0.18), "trunk": Color(0.4, 0.3, 0.22)},
		SPRUCE: {"h": 8.6, "r": 2.2, "crown": Color(0.16, 0.3, 0.16), "trunk": Color(0.32, 0.24, 0.17)},
		BIRCH: {"h": 8.2, "r": 1.9, "crown": Color(0.42, 0.6, 0.25), "trunk": Color.WHITE},
		ASPEN: {"h": 8.2, "r": 1.9, "crown": Color(0.36, 0.52, 0.22), "trunk": Color(0.55, 0.58, 0.5)},
		BUSH: {"h": 8.2, "r": 1.9, "crown": Color(0.34, 0.48, 0.22), "trunk": Color(0.35, 0.3, 0.22)},
	}
	_meshes = {"near": [], "mid": [], "far": []}
	for sp in SPECIES:
		var s: Dictionary = spec[sp]
		var H: float = s.h
		var R: float = s.r
		var crown_m := _mat(solid, {"color": s.crown}, H, R)
		var crown_far := _mat(solid, {"color": Color(s.crown).darkened(0.1)}, H, R)
		var trunk_m := _mat(solid, {"bark": sp == BIRCH, "color": s.trunk, "foliage": false, "trunk": true}, H, R)
		var near := []
		var mid := []
		var far := []
		match sp:
			PINE:
				var upper := _mat(solid, {"color": Color(0.72, 0.42, 0.24), "foliage": false, "trunk": true}, H, R)
				var trunk := [B.cyl(0.13, 0.22, 5.0, 7), Vector3(0, 2.5, 0), trunk_m]
				var top := [B.cyl(0.07, 0.13, 4.6, 6), Vector3(0, 7.3, 0), upper]
				near = [trunk, top, [Foliage.pine_crown(3), Vector3.ZERO,
					_mat(card, {"leaf_tex": Foliage.pine_texture(), "color": s.crown, "sway": 0.05}, H, R)]]
				mid = [trunk, top,
					[_flat_sphere(1.7, 0.9), Vector3(0.2, 9.1, 0), crown_m],
					[_flat_sphere(1.3, 0.8), Vector3(-0.8, 8.3, 0.4), crown_m],
					[_flat_sphere(1.2, 0.7), Vector3(0.7, 8.0, -0.6), crown_m]]
				far = [[B.cyl(0.1, 0.2, 7.0, 4), Vector3(0, 3.5, 0), trunk_m], [_flat_sphere(1.9, 1.3, 6), Vector3(0, 8.9, 0), crown_far]]
			SPRUCE:
				var trunk := [B.cyl(0.15, 0.24, 2.2, 6), Vector3(0, 1.1, 0), trunk_m]
				var inner := _mat(solid, {"color": Color(0.1, 0.2, 0.1)}, H, R)
				near = [trunk, [Foliage.spruce_crown(5), Vector3.ZERO,
					_mat(card, {"leaf_tex": Foliage.spruce_texture(), "color": s.crown, "sway": 0.04}, H, R)],
					[B.cyl(0.0, 1.3, 7.6, 7), Vector3(0, 4.6, 0), inner]]
				mid = [trunk,
					[B.cyl(0.0, 2.1, 3.4, 8), Vector3(0, 2.9, 0), crown_m],
					[B.cyl(0.0, 1.65, 3.0, 8), Vector3(0, 4.6, 0), crown_m],
					[B.cyl(0.0, 1.15, 2.6, 8), Vector3(0, 6.2, 0), crown_m],
					[B.cyl(0.0, 0.6, 1.8, 7), Vector3(0, 7.6, 0), crown_m]]
				far = [[B.cyl(0.0, 2.1, 8.0, 5), Vector3(0, 4.6, 0), crown_far]]
			_:
				var trunk := [B.cyl(0.11, 0.2, 6.0, 7), Vector3(0, 3.0, 0), trunk_m]
				near = [trunk, [Foliage.birch_crown(1 + sp), Vector3.ZERO,
					_mat(card, {"leaf_tex": Foliage.leaf_texture(), "color": s.crown, "sway": 0.08}, H, R)]]
				mid = [trunk,
					[B.sphere(1.6, 8), Vector3(0, 5.9, 0), crown_m],
					[B.sphere(1.3, 8), Vector3(0.9, 5.1, 0.35), crown_m],
					[B.sphere(1.25, 8), Vector3(-0.75, 6.7, -0.35), crown_m]]
				far = [[B.cyl(0.08, 0.18, 4.5, 4), Vector3(0, 2.25, 0), trunk_m], [_flat_sphere(1.9, 2.2, 6), Vector3(0, 5.9, 0), crown_far]]
		_meshes.near.append(_lod(_combine(near), 0.0, NEAR_END))
		_meshes.mid.append(_lod(_combine(mid), NEAR_END, MID_END))
		_meshes.far.append(_lod(_combine(far), MID_END, FAR_END))
