extends CharacterBody3D
## Vaimo Päivin punainen Hyundai: partioi tieverkkoa, jahtaa kun näkee pelaajan.

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")

const PATROL_SPEED := 9.0
const CHASE_SPEED := 12.0
const HUNT_SPEED := 12.5
const TURN_RATE := 2.2
const SIGHT := 32.0
const LOSE_TIME := 4.0
const CATCH_DIST := 3.3
const LANE := 2.5

signal spotted
signal caught

var target: Node3D
var world: Node3D  # alusta hidastaa autoa pellolla ja rämeellä
var safe_zones: Array = []  # [Vector3 keskipiste, float säde]: näihin Päivi ei tule perään
var alerted := false  # naapuri käräytti: vaimo tietää koko ajan missä olet
var speed_mult := 1.0  # päivän tilat (#18): huonon päivän jälkeen nopeampi, hyvän jälkeen hitaampi
var mode := "patrol"  # patrol, chase, return
var parked := false  # yöllä kotipihassa: Päivi sisällä, auto ei liiku eikä jahtaa (main.gd _day_rhythm)

var _nodes: Array[Vector3] = []
var _adj: Array = []
var _cur := 0
var _prev := -1
var _goal := Vector3.ZERO
var _speed := 0.0
var _lost := 0.0
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _reverse := 0.0
var _honk_t := 0.0
var _engine: AudioStreamPlayer3D


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(B.box_shape(Vector3(1.8, 1.4, 4.2), Vector3(0, 0.85, 0)))
	B.car(self, Color(0.78, 0.05, 0.05))
	add_to_group("liikenne")  # muut autot pitävät välimatkan (traffic_car.gd)
	B.guide(self, "Päivin Hyundai", Vector3(0, 2.4, 0), 48, Color(1, 0.8, 0.8), true)
	_engine = Sfx.loop_on(self, "engine", -4.0)


## nodes: tieverkon pisteet, adj: naapuri-indeksit per piste.
func setup(nodes: Array[Vector3], adj: Array, start: int, player: Node3D) -> void:
	_nodes = nodes
	_adj = adj
	target = player
	reset_to(start)


func reset_to(index: int) -> void:
	_cur = index
	_prev = -1
	position = _nodes[index]
	mode = "patrol"
	_speed = 0.0
	_advance()
	rotation.y = B.yaw_to(_goal - position)


func is_target_safe() -> bool:
	if target == null:
		return false
	for z in safe_zones:
		if Vector2(target.global_position.x - z[0].x, target.global_position.z - z[0].z).length() < z[1]:
			return true
	return false


func farthest_node_from(p: Vector3) -> int:
	var best := 0
	for i in _nodes.size():
		if _nodes[i].distance_to(p) > _nodes[best].distance_to(p):
			best = i
	return best


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var to_p := target.global_position - global_position
	to_p.y = 0.0
	var d := to_p.length()
	var in_safe := is_target_safe()
	var sees := not in_safe and (alerted or (d < SIGHT and B.line_of_sight(
		self, global_position + Vector3.UP * 1.3, target.global_position + Vector3.UP,
		[get_rid(), (target as CollisionObject3D).get_rid()])))

	if parked:
		_speed = 0.0
		return  # yöllä Päivi on sisällä, auto pihassa
	if mode != "chase" and sees:
		mode = "chase"
		_honk_t = 0.0
		spotted.emit()
	elif mode == "chase":
		_lost = 0.0 if sees else _lost + delta
		if _lost > LOSE_TIME:
			mode = "return"
			_cur = _nearest_node()
			_goal = _nodes[_cur]

	var want := PATROL_SPEED
	match mode:
		"chase":
			_goal = target.global_position
			want = HUNT_SPEED if alerted else CHASE_SPEED
			_honk_t -= delta
			if _honk_t <= 0.0:
				Sfx.play_on(self, "horn", 2.0)
				_honk_t = randf_range(2.5, 4.0)
		"patrol":
			if _flat_dist(_goal) < 3.0:
				_advance()
		"return":
			if _flat_dist(_goal) < 3.0:
				mode = "patrol"
				_prev = -1
				_advance()
	_drive(delta, want * speed_mult)

	if d < CATCH_DIST and not in_safe:
		caught.emit()


func _drive(delta: float, want: float) -> void:
	var to_g := _goal - global_position
	var diff := wrapf(B.yaw_to(to_g) - rotation.y, -PI, PI)
	var steer_scale := clampf(absf(_speed) / 3.0, 0.3, 1.0)
	if _reverse > 0.0:
		_reverse -= delta
		_speed = -4.0
		rotation.y -= signf(diff) * TURN_RATE * delta
	else:
		var slow := clampf(1.0 - absf(diff) / PI, 0.35, 1.0)
		var ground: float = world.speed_factor(global_position, "car") if world != null else 1.0
		_speed = move_toward(_speed, want * slow * ground, 10.0 * delta)
		rotation.y += clampf(diff, -TURN_RATE * steer_scale * delta, TURN_RATE * steer_scale * delta)
	velocity = -global_transform.basis.z * _speed
	move_and_slide()
	global_position.y = Terrain.h(global_position.x, global_position.z)  # maaston pinnalla (sisätiloissa 0)
	_engine.pitch_scale = 0.75 + absf(_speed) / HUNT_SPEED * 0.55

	# Jumissa seinässä -> peruuta hetki.
	_stuck_t += delta
	if _stuck_t > 1.5:
		if global_position.distance_to(_stuck_pos) < 1.5 and _reverse <= 0.0:
			_reverse = 1.2
		_stuck_t = 0.0
		_stuck_pos = global_position


func _advance() -> void:
	var options: Array = _adj[_cur].filter(func(n: int) -> bool: return n != _prev)
	if options.is_empty():
		options = _adj[_cur]  # umpikuja: käännytään takaisin
	var next: int = options.pick_random()
	var dir := (_nodes[next] - _nodes[_cur]).normalized()
	_prev = _cur
	_cur = next
	_goal = _nodes[next] + Vector3(-dir.z, 0, dir.x) * LANE


func _nearest_node() -> int:
	var best := 0
	for i in _nodes.size():
		if _flat_dist(_nodes[i]) < _flat_dist(_nodes[best]):
			best = i
	return best


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()
