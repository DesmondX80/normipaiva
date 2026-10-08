extends Node3D
## Satunnainen juna Vaalan mopomatkan radalla (vaala.gd _build_train): radan OSM-pätkistä ketjutettua reittiä pitkin
## päästä päähän. Juna lähtee satunnaisin välein siitä päästä, joka on kauempana kamerasta (ilmestyminen ei näy), ja
## katoaa toiseen päähän. Henkilöjuna: punainen sähköveturi ja valkovihreät vaunut 90 km/h; tavarajuna: veturi ja
## tukkivaunut 55 km/h. Jyrinä 3D-äänenä veturissa, vihellys lähtiessä ja ohittaessa kameran.

const B := preload("res://scripts/build.gd")

const WAIT := Vector2(60.0, 180.0)  # junien väli (s)
const RAIL_TOP := 0.22             # kiskon yläpinta reitin pisteiden yläpuolella

var path := PackedVector3Array()   # kiskojen keskilinja (y = ratapölkkyjen taso)
var _cum := PackedFloat32Array()
var _length := 0.0
var _units: Array = []             # [solmu, pituus, keskikohdan etäisyys veturin keulasta]
var _active := false
var _s := 0.0                      # veturin keulan matka reitillä ajosuuntaan
var _dir := 1
var _speed := 25.0
var _wait := 0.0
var _train_len := 0.0
var _rumble: AudioStreamPlayer3D
var _honked := false


func setup(p: PackedVector3Array) -> void:
	path = p
	_cum.resize(path.size())
	_cum[0] = 0.0
	for i in range(1, path.size()):
		_cum[i] = _cum[i - 1] + path[i].distance_to(path[i - 1])
	_length = _cum[path.size() - 1]
	_wait = randf_range(15.0, 45.0)


## Seuraava juna heti (testit).
func spawn_now(passenger := true, from_start := -1) -> void:
	_spawn(passenger, from_start)


func _process(delta: float) -> void:
	if path.size() < 2:
		return
	if not _active:
		_wait -= delta
		if _wait <= 0.0:
			_spawn(randf() < 0.6)
		return
	_s += _speed * delta
	_place()
	var cam := get_viewport().get_camera_3d()
	if cam != null and not _honked and _units.size() > 0:
		var loco: Node3D = _units[0][0]
		if loco.visible and loco.global_position.distance_to(cam.global_position) < 160.0:
			_honked = true
			Sfx.play_on(loco, "horn", 6.0, 0.48, 2.6)
	if _s - _train_len > _length + 5.0:
		_despawn()


func _spawn(passenger: bool, from_start := -1) -> void:
	_despawn()
	var cam := get_viewport().get_camera_3d()
	if from_start < 0:
		var c := to_local(cam.global_position) if cam != null else path[0]
		from_start = 1 if c.distance_to(path[0]) > c.distance_to(path[path.size() - 1]) else 0
	_dir = 1 if from_start == 1 else -1
	_speed = 25.0 if passenger else 15.5
	var specs: Array = [["loco", 18.9]]
	if passenger:
		for i in randi_range(3, 5):
			specs.append(["coach", 26.4])
	else:
		for i in randi_range(8, 14):
			specs.append(["logs", 15.0])
	var off := 0.0
	for sp in specs:
		var n := Node3D.new()
		add_child(n)
		var ln: float = sp[1]
		match sp[0]:
			"loco":
				_build_loco(n, ln)
			"coach":
				_build_coach(n, ln)
			_:
				_build_logs(n, ln)
		_units.append([n, ln, off + ln / 2.0])
		off += ln + 0.8
	_train_len = off
	_s = 0.0
	_active = true
	_honked = false
	_rumble = AudioStreamPlayer3D.new()
	_rumble.stream = Sfx.stream("tractor_engine")
	_rumble.pitch_scale = 0.42
	_rumble.volume_db = 6.0
	_rumble.unit_size = 25.0
	_rumble.max_distance = 700.0
	_rumble.bus = "SFX"
	(_units[0][0] as Node3D).add_child(_rumble)
	_rumble.play()
	_place()


func _despawn() -> void:
	for u in _units:
		(u[0] as Node3D).queue_free()
	_units.clear()
	_active = false
	_wait = randf_range(WAIT.x, WAIT.y)


## Piste reitillä matkan d kohdalla ajosuunnassa (d = 0 lähtöpäässä).
func _at(d: float) -> Vector3:
	var t := d if _dir == 1 else _length - d
	t = clampf(t, 0.0, _length)
	var lo := 0
	var hi := path.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _cum[mid] <= t:
			lo = mid
		else:
			hi = mid
	var seg := maxf(_cum[hi] - _cum[lo], 0.001)
	return path[lo].lerp(path[hi], (t - _cum[lo]) / seg)


func _place() -> void:
	for u in _units:
		var n: Node3D = u[0]
		var ln: float = u[1]
		var c: float = _s - float(u[2])
		var df := c + ln / 2.0 - 2.5
		var dr := c - ln / 2.0 + 2.5
		n.visible = dr >= 0.0 and df <= _length
		if not n.visible:
			continue
		var pf := _at(df)
		var pr := _at(dr)
		var mid := (pf + pr) / 2.0 + Vector3(0, RAIL_TOP, 0)
		n.position = mid  # paikallinen kehys (Vaalan maailma voi olla siirretty)
		if pf.distance_to(pr) > 0.1:
			n.basis = Basis.looking_at(pf - pr, Vector3.UP)


# --- Mallit (-Z eteenpäin, kiskon yläpinta y = 0) --------------------------------------------------------------

func _bogies(n: Node3D, ln: float) -> void:
	for z: float in [-(ln / 2.0 - 3.2), ln / 2.0 - 3.2]:
		B.mesh(n, B.boxm(Vector3(2.4, 0.8, 3.2)), Vector3(0, 0.55, z), Color(0.12, 0.12, 0.13))
		for wz: float in [-0.95, 0.95]:
			for wx: float in [-0.75, 0.75]:
				B.mesh(n, B.cyl(0.46, 0.46, 0.14, 12), Vector3(wx, 0.46, z + wz), Color(0.2, 0.19, 0.18), Vector3(0, 0, 90))


func _build_loco(n: Node3D, ln: float) -> void:
	var red := Color(0.72, 0.07, 0.06)
	var white := Color(0.94, 0.94, 0.92)
	_bogies(n, ln)
	B.mesh(n, B.boxm(Vector3(3.0, 2.9, ln - 1.2)), Vector3(0, 2.45, 0), red)
	B.mesh(n, B.boxm(Vector3(3.02, 0.35, ln - 1.0)), Vector3(0, 1.75, 0), white)  # valkoinen raita
	B.mesh(n, B.boxm(Vector3(2.4, 0.3, ln - 4.0)), Vector3(0, 4.05, 0), Color(0.3, 0.3, 0.32))  # katon laitteet
	for zs: float in [-1.0, 1.0]:
		var zf := zs * (ln / 2.0 - 0.6)
		B.mesh(n, B.boxm(Vector3(2.6, 1.0, 0.1)), Vector3(0, 3.1, zf + zs * 0.02), Color(0.06, 0.08, 0.1))  # ohjaamon ikkuna
		for lx: float in [-0.95, 0.95]:
			var lamp := B.mesh(n, B.cyl(0.14, 0.14, 0.08, 10), Vector3(lx, 1.6, zf + zs * 0.05), Color(1.0, 0.95, 0.8), Vector3(90, 0, 0))
			if zs < 0.0:
				lamp.material_override = B.unshaded(Color(1.0, 0.97, 0.85))
	# Virroitin.
	B.tube(n, Vector3(0, 4.2, -2.0), Vector3(0, 5.3, -0.8), 0.04, Color(0.25, 0.25, 0.25))
	B.tube(n, Vector3(0, 5.3, -0.8), Vector3(0, 5.4, 0.6), 0.04, Color(0.25, 0.25, 0.25))
	B.mesh(n, B.boxm(Vector3(1.6, 0.05, 0.2)), Vector3(0, 5.45, 0.6), Color(0.2, 0.2, 0.2))
	var plate := B.label(n, "VR", Vector3(1.53, 2.6, 0), 90, Color(1, 1, 1))
	plate.rotation.y = PI / 2.0


func _build_coach(n: Node3D, ln: float) -> void:
	var white := Color(0.94, 0.94, 0.92)
	var green := Color(0.0, 0.45, 0.25)
	_bogies(n, ln)
	B.mesh(n, B.boxm(Vector3(3.1, 3.0, ln - 0.6)), Vector3(0, 2.6, 0), white)
	B.mesh(n, B.boxm(Vector3(3.12, 0.4, ln - 0.5)), Vector3(0, 1.4, 0), green)
	B.mesh(n, B.boxm(Vector3(3.14, 0.75, ln - 3.0)), Vector3(0, 2.7, 0), Color(0.08, 0.1, 0.12))  # ikkunarivi
	for k in int((ln - 3.0) / 1.8):
		B.mesh(n, B.boxm(Vector3(3.16, 0.75, 0.18)), Vector3(0, 2.7, -(ln - 3.0) / 2.0 + 0.9 + k * 1.8), white)
	B.mesh(n, B.boxm(Vector3(2.9, 0.25, ln - 0.8)), Vector3(0, 4.2, 0), Color(0.7, 0.72, 0.74))


func _build_logs(n: Node3D, ln: float) -> void:
	_bogies(n, ln)
	B.mesh(n, B.boxm(Vector3(2.8, 0.4, ln - 0.4)), Vector3(0, 1.25, 0), Color(0.2, 0.17, 0.15))
	for k in 4:
		var z := -ln / 2.0 + 1.5 + k * (ln - 3.0) / 3.0
		for sx: float in [-1.3, 1.3]:
			B.mesh(n, B.boxm(Vector3(0.14, 2.4, 0.14)), Vector3(sx, 2.6, z), Color(0.2, 0.17, 0.15))
	var bark := Color(0.45, 0.33, 0.22)
	for row in 3:
		for k in 5 - row:
			var x := (k - (4 - row) / 2.0) * 0.5
			B.mesh(n, B.cyl(0.24, 0.24, ln - 1.2, 8), Vector3(x, 1.7 + row * 0.42, 0), bark.darkened(0.08 * ((k + row) % 3)),
				Vector3(90, 0, 0))
