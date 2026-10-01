extends Node3D
## Kotipihan nurmikko: kasvaa joka päivä ja leikataan ruohonleikkurilla (main.gd: _lawn_logic).
## Pituus tallentuu ruuduittain (CELL m), joten puoliksi leikattu nurmikko jää seuraavaksi päiväksi kesken.
## Siilit ja kivet arvotaan aamulla nurmikolle. Pitkässä ruohossa ne jäävät korsien alle piiloon, ja
## leikkaamaton nurmikko houkuttelee niitä lisää.

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")

const CELL := 0.5
const MAX_LEN := 0.8
const START_LEN := 0.3  # uusi peli: nurmikko kaipaa jo leikkuuta
const GROW := 0.1  # kasvu päivässä (m)
const CUT_LEN := 0.04
const SHORT := 0.1  # tätä lyhyempi lasketaan leikatuksi
const SPACING := 0.13  # ruohotupsujen väli
const HEAD := 0.8  # leikkurin keskipiste pelaajan edessä
const BLADE_R := 0.5  # terän säde

## Nurmikko omassa kehyksessään: rect on paikallinen (keskipiste origossa), pivot = keskipiste maailmassa ja
## angle = paikallisen x-akselin kulma maailmassa (nurmikko talon suuntaisesti).
var rect: Rect2
var pivot := Vector2.ZERO
var angle := 0.0
var mower_park: Vector3
var lengths := PackedFloat32Array()
var cols := 0
var rows := 0
var mower: Node3D
## Nurmikon yllätykset: {kind: "siili" | "kivi", pos: Vector2, r: float, node: Node3D}.
var objects: Array = []
## Maan korkeus maailman x/z:ssä: tyhjä = Saloisten maasto (terrain.gd). Mökin nurmikolla mökin oma maasto.
var height_fn: Callable
## Aamulla arvottavat yllätykset (mökillä vain kiviä).
var kinds: Array = ["siili", "kivi"]

var _img: Image
var _tex: ImageTexture
var _dirty := false
var _engine: AudioStreamPlayer3D
var _cough := 0.0


func _ready() -> void:
	cols = ceili(rect.size.x / CELL)
	rows = ceili(rect.size.y / CELL)
	if lengths.size() != cols * rows:
		lengths.resize(cols * rows)
		lengths.fill(START_LEN)
	_img = Image.create(cols, rows, false, Image.FORMAT_R8)
	_tex = ImageTexture.create_from_image(_img)
	_build_ground()
	_build_grass()
	_build_mower()
	park_mower()
	_refresh()


func _gh(x: float, z: float) -> float:
	return height_fn.call(x, z) if height_fn.is_valid() else T.h(x, z)


func _process(delta: float) -> void:
	if _dirty:
		_dirty = false
		_refresh()
	if _cough > 0.0:
		_cough -= delta
		_engine.pitch_scale = 1.1 + sin(_cough * 40.0) * 0.4
	elif _engine.playing:
		_engine.pitch_scale = move_toward(_engine.pitch_scale, 1.6, delta)


# --- Tila ------------------------------------------------------------------------

## Tallennus: pituudet senttimetreinä tavuina.
func save_state() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(lengths.size())
	for i in lengths.size():
		out[i] = clampi(roundi(lengths[i] * 100.0), 0, 255)
	return out


func load_state(data: PackedByteArray) -> void:
	if data.size() != lengths.size():
		return  # uusi peli tai nurmikon koko muuttui: aloitetaan oletuspituudesta
	for i in data.size():
		lengths[i] = data[i] / 100.0
	_dirty = true


## Uusi päivä: ruoho kasvaa.
func grow() -> void:
	for i in lengths.size():
		lengths[i] = minf(lengths[i] + GROW, MAX_LEN)
	_dirty = true


func avg_len() -> float:
	var s := 0.0
	for l in lengths:
		s += l
	return s / maxf(1.0, lengths.size())


## Leikatun osuus nurmikosta (0–1).
func cut_ratio() -> float:
	var n := 0
	for l in lengths:
		if l <= SHORT:
			n += 1
	return float(n) / maxf(1.0, lengths.size())


## Maailman x/z -> nurmikon paikallinen kehys ja takaisin.
func to_lawn(p: Vector2) -> Vector2:
	return (p - pivot).rotated(-angle)


func to_world(p: Vector2) -> Vector2:
	return p.rotated(angle) + pivot


func has_point(p: Vector3, margin := 0.0) -> bool:
	return rect.grow(margin).has_point(to_lawn(Vector2(p.x, p.z)))


func _refresh() -> void:
	for j in rows:
		for i in cols:
			_img.set_pixel(i, j, Color(lengths[j * cols + i] / MAX_LEN, 0, 0))
	_tex.update(_img)


# --- Leikkuu ---------------------------------------------------------------------

## Leikkaa ruudut, joiden keskipiste on säteellä r pisteestä p. Palauttaa, kuinka paljon ruohoa lähti (m).
func cut(pw: Vector2, r: float) -> float:
	var p := to_lawn(pw)
	var removed := 0.0
	var lo := ((p - Vector2(r, r) - rect.position) / CELL).floor()
	var hi := ((p + Vector2(r, r) - rect.position) / CELL).ceil()
	for j in range(maxi(0, int(lo.y)), mini(rows, int(hi.y))):
		for i in range(maxi(0, int(lo.x)), mini(cols, int(hi.x))):
			var c := rect.position + (Vector2(i, j) + Vector2(0.5, 0.5)) * CELL
			var k := j * cols + i
			if c.distance_to(p) < r and lengths[k] > CUT_LEN:
				removed += lengths[k] - CUT_LEN
				lengths[k] = CUT_LEN
	if removed > 0.0:
		_dirty = true
	return removed


## Leikkurin terän kohta (maailman x/z), kun sitä työnnetään.
func head_pos() -> Vector2:
	return Vector2(mower.global_position.x, mower.global_position.z)


## Osuuko terä siiliin tai kiveen? Palauttaa osuman tai tyhjän.
func hit_test(p: Vector2) -> Dictionary:
	for o in objects:
		if o.pos.distance_to(p) < BLADE_R + o.r:
			return o
	return {}


func remove_object(o: Dictionary) -> void:
	o.node.queue_free()
	objects.erase(o)


## Aamulla siilit ja kivet uusiin paikkoihin. Pitkä ruoho houkuttelee siilejä ja kätkee kiviä.
func spawn_objects() -> void:
	for o in objects:
		o.node.queue_free()
	objects.clear()
	var avg := avg_len()
	var want: Array[String] = []
	if "siili" in kinds:
		for i in 1 + int(avg / 0.25):
			want.append("siili")
	if "kivi" in kinds:
		for i in 2 + int(avg / 0.2):
			want.append("kivi")
	var inner := rect.grow(-0.6)
	var park := Vector2(mower_park.x, mower_park.z)
	for kind in want:
		for attempt in 30:
			var p := to_world(inner.position + Vector2(randf() * inner.size.x, randf() * inner.size.y))
			if p.distance_to(park) < 2.5 or objects.any(func(o: Dictionary) -> bool: return o.pos.distance_to(p) < 1.4):
				continue
			var node := _hedgehog() if kind == "siili" else _rock()
			node.position = Vector3(p.x, _gh(p.x, p.y), p.y)
			node.rotation.y = randf() * TAU
			add_child(node)
			objects.append({"kind": kind, "pos": p, "r": 0.16 if kind == "siili" else 0.18, "node": node})
			break


# --- Leikkuri --------------------------------------------------------------------

func park_mower() -> void:
	mower.global_position = mower_park
	mower.rotation.y = 0.0
	set_running(false)


## Leikkuri pelaajan edessä: kahva käsissä, terä HEAD metrin päässä.
func push_mower(walker: Node3D) -> void:
	var fwd := -walker.global_transform.basis.z
	fwd.y = 0.0
	var p := walker.global_position + fwd.normalized() * HEAD
	mower.global_position = Vector3(p.x, _gh(p.x, p.z), p.z)
	mower.rotation.y = walker.rotation.y


func set_running(on: bool) -> void:
	if on and not _engine.playing:
		_engine.play()
		_engine.pitch_scale = 0.8
	elif not on:
		_engine.stop()
		_cough = 0.0


## Kivi terään: moottori yskii hetken.
func cough() -> void:
	_cough = 1.2


func _build_mower() -> void:
	mower = Node3D.new()
	add_child(mower)
	var red := Color(0.78, 0.12, 0.08)
	var black := Color(0.08, 0.08, 0.08)
	var steel := Color(0.6, 0.62, 0.64)
	B.mesh(mower, B.boxm(Vector3(0.56, 0.12, 0.62)), Vector3(0, 0.2, 0), red)
	B.mesh(mower, B.boxm(Vector3(0.6, 0.06, 0.66)), Vector3(0, 0.12, 0), red.darkened(0.35))
	B.mesh(mower, B.cyl(0.12, 0.14, 0.2, 12), Vector3(0, 0.36, -0.05), black)
	B.mesh(mower, B.cyl(0.035, 0.035, 0.05, 8), Vector3(0.06, 0.48, -0.05), Color(0.9, 0.75, 0.1))
	B.mesh(mower, B.boxm(Vector3(0.38, 0.3, 0.3)), Vector3(0, 0.3, 0.45), Color(0.18, 0.3, 0.14))  # keruusäkki
	for x in [-0.3, 0.3]:
		for z in [-0.24, 0.24]:
			B.mesh(mower, B.cyl(0.09, 0.09, 0.05, 12), Vector3(x, 0.09, z), black, Vector3(0, 0, 90))
		B.tube(mower, Vector3(x * 0.75, 0.24, 0.3), Vector3(x * 0.75, 0.9, 0.62), 0.014, steel)
	B.tube(mower, Vector3(-0.24, 0.9, 0.62), Vector3(0.24, 0.9, 0.62), 0.018, black)
	_engine = Sfx.loop_on(mower, "tractor_engine", -9.0)
	_engine.stop()


## Nurmikon pohja maaston myötäisenä ruudukkona: sävy kertoo, mistä on jo leikattu.
func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var at := func(i: int, j: int) -> Vector3:
		var p := to_world(rect.position + Vector2(i, j) * CELL)
		return Vector3(p.x, _gh(p.x, p.y) + 0.02, p.y)
	st.set_normal(Vector3.UP)
	for j in rows:
		for i in cols:
			for v in [at.call(i, j), at.call(i + 1, j), at.call(i + 1, j + 1), at.call(i, j), at.call(i + 1, j + 1), at.call(i, j + 1)]:
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = B.shader_mat("res://shaders/lawn_ground.gdshader", {
		"origin": rect.position, "size": rect.size, "pivot": pivot, "angle": angle, "cut": _tex, "max_len": MAX_LEN})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_grass() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4 * k
		var dir := Vector3(cos(a), 0, sin(a))
		var off := Vector3(sin(a * 2.3), 0, cos(a * 1.7)) * 0.05
		var lean := Vector3(-dir.z, 0, dir.x) * (0.06 + 0.04 * (k % 2))
		var tall := 0.8 + 0.2 * (k % 3) / 2.0
		st.add_vertex(off - dir * 0.012)
		st.add_vertex(off + dir * 0.012)
		st.add_vertex(off + lean * tall + Vector3.UP * tall)
	var gx := ceili(rect.size.x / SPACING)
	var gz := ceili(rect.size.y / SPACING)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = gx * gz
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = B.shader_mat("res://shaders/lawn.gdshader", {
		"origin": rect.position, "size": rect.size, "pivot": pivot, "angle": angle, "cols": gx, "spacing": SPACING,
		"cut": _tex, "max_len": MAX_LEN,
	})
	if height_fn.is_valid():
		_own_heights(mmi.material_override)
	else:
		var m: ShaderMaterial = mmi.material_override
		m.set_shader_parameter("terrain_h", T.texture())
		m.set_shader_parameter("terrain_origin", T.origin)
		m.set_shader_parameter("terrain_cells", Vector2(T.nx, T.nz))
		m.set_shader_parameter("terrain_cell", T.CELL)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var y := _gh(pivot.x, pivot.y)
	var rad := rect.size.length() / 2.0
	mmi.custom_aabb = AABB(Vector3(pivot.x - rad, y - 20.0, pivot.y - rad), Vector3(rad * 2.0, 40.0, rad * 2.0))
	add_child(mmi)


## Oma korkeuskartta korsien juurille (height_fn), 0,5 m ruudukko nurmikon ympäriltä.
func _own_heights(m: ShaderMaterial) -> void:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for c in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var w := to_world(c)
		lo = lo.min(w)
		hi = hi.max(w)
	var cell := 0.5
	lo -= Vector2.ONE * cell * 2.0
	var n := Vector2i(ceili((hi.x - lo.x) / cell) + 4, ceili((hi.y - lo.y) / cell) + 4)
	var img := Image.create(n.x, n.y, false, Image.FORMAT_RF)
	for j in n.y:
		for i in n.x:
			var p := lo + Vector2(i, j) * cell
			img.set_pixel(i, j, Color(_gh(p.x, p.y), 0, 0))
	m.set_shader_parameter("terrain_h", ImageTexture.create_from_image(img))
	m.set_shader_parameter("terrain_origin", lo)
	m.set_shader_parameter("terrain_cells", Vector2(n))
	m.set_shader_parameter("terrain_cell", cell)


## Siili: piikikäs ruskea kumpu, vaalea kuono ja musta nenä (-Z eteen).
func _hedgehog() -> Node3D:
	var n := Node3D.new()
	var spines := Color(0.3, 0.24, 0.17)
	var body := B.mesh(n, B.sphere(0.13, 12), Vector3(0, 0.07, 0.02), spines)
	body.scale = Vector3(1.0, 0.7, 1.25)
	for i in 22:
		var a := randf() * TAU
		var up := randf_range(0.25, 1.0)
		var dir := Vector3(cos(a) * (1.0 - up * 0.6), up, sin(a) * (1.0 - up * 0.6) + 0.25).normalized()
		var base := Vector3(0, 0.07, 0.03) + Vector3(dir.x * 0.11, dir.y * 0.07, dir.z * 0.14)
		B.tube(n, base, base + dir * 0.07, 0.008, spines.lightened(randf_range(0.0, 0.4)))
	B.mesh(n, B.sphere(0.055, 10), Vector3(0, 0.05, -0.13), Color(0.62, 0.5, 0.38))
	B.mesh(n, B.sphere(0.015, 6), Vector3(0, 0.05, -0.185), Color(0.03, 0.03, 0.03))
	for x in [-0.03, 0.03]:
		B.mesh(n, B.sphere(0.009, 6), Vector3(x, 0.08, -0.15), Color(0.02, 0.02, 0.02))
	return n


func _rock() -> Node3D:
	var n := Node3D.new()
	var r := randf_range(0.13, 0.2)
	var s := B.mesh(n, B.sphere(r, 10), Vector3(0, r * 0.35, 0), Color(0.45, 0.44, 0.42).lightened(randf_range(-0.1, 0.15)))
	s.scale = Vector3(randf_range(1.0, 1.4), 0.6, randf_range(0.9, 1.2))
	return n
