extends CharacterBody3D
## Liikenteen auto: ajaa oikeaa kaistaa joko kylän tieverkossa (setup_graph, satunnaiset käännökset risteyksissä)
## tai Vaalan mopomatkan tiellä (setup_line, tien näytteitä pitkin). Jarruttaa, kun pelaaja on edessä, mutta
## pysähtymismatka on pitkä: eteen hyppäävä jää alle (hit-signaali, kun auto osuu vauhdissa).

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")

const COLORS := [Color(0.85, 0.85, 0.87), Color(0.08, 0.08, 0.1), Color(0.15, 0.25, 0.5), Color(0.55, 0.56, 0.58),
	Color(0.5, 0.1, 0.1), Color(0.2, 0.35, 0.25), Color(0.75, 0.7, 0.55), Color(0.9, 0.9, 0.9)]
const LOOK := 16.0      # jarrutusetäisyys edessä
const BRAKE := 7.0
const HIT_SPEED := 3.0  # tätä kovempaa osuessa pelaaja kuolee

signal hit

var target_fn: Callable  # palauttaa pelaajan solmun (jalan, pyörä tai mopo)
var cruise := 11.0
var lane := 1.7
var ground_fn: Callable  # (x, z) -> y; oletuksena kylän maasto

var _speed := 0.0
var _honk_t := 0.0
var _engine: AudioStreamPlayer3D
# Tieverkko
var _nodes: Array[Vector3] = []
var _adj: Array = []
var _cur := 0
var _prev := -1
# Tieviiva
var _line: Array = []   # Vector3-pisteet
var _dir := 1
var _t := 0.0           # paikka viivalla (näyteindeksi, liukuluku)
var line_ended: Callable  # kutsutaan, kun auto ajaa viivan päähän (siirto uuteen paikkaan)


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 0  # ei tönäise pelaajaa: osuma tarkistetaan itse
	collision_mask = 0
	B.car(self, COLORS.pick_random())
	_engine = Sfx.loop_on(self, "engine", -10.0)
	_engine.pitch_scale = randf_range(0.85, 1.1)


func setup_graph(nodes: Array[Vector3], adj: Array, start: int) -> void:
	_nodes = nodes
	_adj = adj
	_cur = start
	_prev = -1
	position = nodes[start]
	_speed = cruise * 0.5
	_advance()


func setup_line(pts: Array, t: float, dir: int) -> void:
	_line = pts
	_t = t
	_dir = dir
	_speed = cruise
	_place_on_line(0.0)


func _advance() -> void:
	var opts: Array = _adj[_cur].filter(func(n: int) -> bool: return n != _prev)
	if opts.is_empty():
		opts = _adj[_cur]
	if opts.is_empty():
		return
	_prev = _cur
	_cur = opts.pick_random()


func _physics_process(delta: float) -> void:
	var tgt: Node3D = target_fn.call() if target_fn.is_valid() else null
	var want := cruise
	var fwd := -global_transform.basis.z
	if tgt != null and is_instance_valid(tgt):
		var to := tgt.global_position - global_position
		to.y = 0.0
		var ahead := to.dot(fwd)
		var side := absf(to.dot(fwd.cross(Vector3.UP)))
		if ahead > 0.0 and ahead < LOOK and side < 2.2:
			want = 0.0  # pelaaja edessä: jarrutus ja tööttäys
			_honk_t -= delta
			if _honk_t <= 0.0:
				Sfx.play_on(self, "horn", 0.0, randf_range(0.9, 1.1))
				_honk_t = randf_range(1.5, 2.5)
		# Osuma: pelaaja auton ääriviivojen sisällä ja auto liikkuu.
		if absf(_speed) > HIT_SPEED and ahead > -2.4 and ahead < 2.6 and side < 1.25:
			hit.emit()
			_speed = 0.0
	_speed = move_toward(_speed, want, (BRAKE if want < _speed else 3.0) * delta)
	if not _line.is_empty():
		_place_on_line(_speed * delta)
	elif not _nodes.is_empty():
		_drive_graph(delta)
	if _engine != null:
		_engine.pitch_scale = 0.8 + clampf(_speed / 16.0, 0.0, 1.0) * 0.6


func _drive_graph(delta: float) -> void:
	var a: Vector3 = _nodes[_prev] if _prev >= 0 else global_position
	var b: Vector3 = _nodes[_cur]
	var seg := Vector3(b.x - a.x, 0, b.z - a.z)
	var right := seg.normalized().cross(Vector3.UP)
	var goal := b + right * lane
	var to_g := goal - global_position
	to_g.y = 0.0
	if to_g.length() < 3.0:
		_advance()
		return
	var yaw := B.yaw_to(to_g)
	rotation.y = rotate_toward(rotation.y, yaw, 2.5 * delta)
	var slow := clampf(1.0 - absf(wrapf(yaw - rotation.y, -PI, PI)) / 1.2, 0.3, 1.0)
	_speed = minf(_speed, cruise * slow + 1.0)
	global_position += -global_transform.basis.z * _speed * delta
	global_position.y = ground_fn.call(global_position.x, global_position.z) if ground_fn.is_valid() \
		else Terrain.h(global_position.x, global_position.z)


## Viivalla: näytteiden väli on vakio (vaala.gd STEP 2 m), joten matka / 2 = näytteitä.
func _place_on_line(dist: float) -> void:
	_t += _dir * dist / 2.0
	if _t < 1.0 or _t > _line.size() - 2.0:
		if line_ended.is_valid():
			line_ended.call(self)
		_t = clampf(_t, 1.0, _line.size() - 2.0)
	var i := int(_t)
	var u := _t - i
	var a: Vector3 = _line[i]
	var b: Vector3 = _line[i + 1]
	var p := a.lerp(b, u)
	var d := (b - a)
	d.y = 0.0
	d = d.normalized() * _dir
	var right := d.cross(Vector3.UP)
	position = p + right * lane
	rotation.y = atan2(-d.x, -d.z)


func set_line_t(t: float, dir: int) -> void:
	_t = t
	_dir = dir


func line_t() -> float:
	return _t


func line_dir() -> int:
	return _dir
