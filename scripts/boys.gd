extends Node3D
## Jalkapallopojat (#29): kolme poikaa, joiden pallo on hukassa. main.gd hoitaa tehtävän (anto, pallo, esinevalikko).
## Tilat: "idle" (odottavat), "play" (pallo palautettu: potkivat palloa keskenään), "flee" (saivat kaljaa: juoksevat
## nauraen pois ja katoavat), "angry" (väärä esine: heittelevät kiviä, osuma = hit).

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")

const THROW_TIME := 6.0
const THROW_RANGE := 16.0
const FLIGHT := 0.8
const HIT_DIST := 1.1

signal hit(direction: Vector3)

var target: Node3D
var mode := "idle"

var _kids: Array[Node3D] = []
var _bubbles: Array[Label3D] = []
var _bubble_t: Array[float] = [0.0, 0.0, 0.0]
var _throw_t: Array[float] = [0.0, 0.0, 0.0]
var _t := 0.0
var _ball: Node3D
var _ball_from := 0
var _ball_to := 1
var _ball_u := 0.0
var _flying: Array = []
var _flee_dir := Vector3.FORWARD


func _ready() -> void:
	for i in 3:
		var a := TAU * i / 3.0
		var k := Looks.make(self, Looks.POJAT[i])
		k.position = Vector3(cos(a), 0, sin(a)) * 1.3
		k.rotation.y = B.yaw_to(-k.position)
		k.play("Idle", 0.0)
		_kids.append(k)
		_bubbles.append(B.bubble(self, k.position + Vector3(0, 1.75, 0), Color.WHITE))


## Pojan repliikki kuplaan (i = -1: satunnainen poika).
func say(text: String, i := -1, seconds := 3.0) -> void:
	if i < 0:
		i = randi() % 3
	_bubbles[i].text = text
	_bubble_t[i] = seconds


func distance_to_target() -> float:
	if target == null:
		return INF
	var d := target.global_position - global_position
	return Vector2(d.x, d.z).length()


## Pallo palautettu: potkivat sitä keskenään.
func play_ball() -> void:
	mode = "play"
	_ball = make_ball()
	add_child(_ball)
	for k in _kids:
		k.play("Idle", 0.2)


## Kaljaa: juoksevat nauraen pois pelaajasta poispäin ja katoavat.
func flee() -> void:
	mode = "flee"
	_t = 0.0
	var away := global_position - target.global_position
	away.y = 0.0
	_flee_dir = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	for i in 3:
		say(["Hähää, kaljaa!", "Juostaan!", "Setä on kännissä!"][i], i, 2.5)


## Väärä esine: heittävät sen takaisin ja alkavat heitellä kiviä hetken ajan.
func stone() -> void:
	mode = "angry"
	_t = THROW_TIME
	for i in 3:
		_throw_t[i] = randf_range(0.2, 0.9)
	say("Mitä sää tolla?! Heitetään setää kivillä!", 0, 3.0)


static func make_ball() -> Node3D:
	var ball := Node3D.new()
	B.mesh(ball, B.sphere(0.11, 14), Vector3.ZERO, Color(0.96, 0.96, 0.96))
	for d in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var patch := B.mesh(ball, B.sphere(0.04, 6), d * 0.095, Color(0.08, 0.08, 0.08))
		patch.scale = Vector3.ONE * 1.0
	return ball


func _process(delta: float) -> void:
	for i in 3:
		_bubble_t[i] -= delta
		if _bubble_t[i] <= 0.0:
			_bubbles[i].text = ""
	_update_stones(delta)
	match mode:
		"idle":
			for k in _kids:
				if target != null:
					var to_p := target.global_position - k.global_position
					if Vector2(to_p.x, to_p.z).length() < 10.0:
						k.rotation.y = lerp_angle(k.rotation.y, B.yaw_to(to_p), 1.0 - exp(-4.0 * delta))
		"play":
			_ball_u += delta / 0.9
			var a: Vector3 = _kids[_ball_from].position
			var b: Vector3 = _kids[_ball_to].position
			var p := a.lerp(b, minf(_ball_u, 1.0))
			p.y = 0.11 + sin(minf(_ball_u, 1.0) * PI) * 0.6
			_ball.position = p
			_ball.rotation.x += delta * 12.0
			_kids[_ball_to].rotation.y = lerp_angle(_kids[_ball_to].rotation.y, B.yaw_to(a - b), 1.0 - exp(-6.0 * delta))
			if _ball_u >= 1.0:
				_ball_u = 0.0
				_ball_from = _ball_to
				_ball_to = (_ball_to + 1 + randi() % 2) % 3
				_kids[_ball_from].play("Punch_Cross", 0.05)
				Sfx.play_on(self, "punch", -12.0, 1.6)
		"flee":
			_t += delta
			for k in _kids:
				k.rotation.y = B.yaw_to(_flee_dir)
				k.position += _flee_dir * 6.0 * delta
				k.position.y = T.h(global_position.x + k.position.x, global_position.z + k.position.z) - global_position.y
				k.play("Sprint", 0.15)
			for i in 3:
				_bubbles[i].position = _kids[i].position + Vector3(0, 1.75, 0)
			if _t > 6.0:
				queue_free()
		"angry":
			_t -= delta
			var d := distance_to_target()
			for i in 3:
				var to_p := target.global_position - _kids[i].global_position
				_kids[i].rotation.y = lerp_angle(_kids[i].rotation.y, B.yaw_to(to_p), 1.0 - exp(-8.0 * delta))
				_throw_t[i] -= delta
				if _throw_t[i] <= 0.0 and d < THROW_RANGE:
					_throw_t[i] = randf_range(1.0, 1.8)
					_throw(i)
			if _t <= 0.0 or d > THROW_RANGE * 1.5:
				mode = "idle"
				say("No mene sitte!", -1, 2.0)


func _throw(i: int) -> void:
	var from: Vector3 = _kids[i].global_position + Vector3(0, 1.2, 0)
	var v: Vector3 = target.get("velocity")
	var to := target.global_position + Vector3(v.x, 0, v.z) * FLIGHT + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
	to.y = T.h(to.x, to.z) + 0.05
	var s := Node3D.new()
	B.mesh(s, B.sphere(0.06, 6), Vector3.ZERO, Color(0.5, 0.49, 0.46))
	get_tree().current_scene.add_child(s)
	s.global_position = from
	_flying.append({"node": s, "from": from, "to": to, "t": 0.0})
	_kids[i].play("Punch_Cross", 0.05)
	Sfx.play_at(from, "whoosh", -10.0, 1.6)


func _update_stones(delta: float) -> void:
	for f in _flying.duplicate():
		f.t += delta / FLIGHT
		var u: float = minf(f.t, 1.0)
		var p: Vector3 = f.from.lerp(f.to, u)
		p.y += sin(u * PI) * 2.0
		f.node.global_position = p
		if u >= 1.0:
			_flying.erase(f)
			f.node.queue_free()
			if target != null:
				var d := Vector2(target.global_position.x - f.to.x, target.global_position.z - f.to.z).length()
				if d < HIT_DIST:
					var dir: Vector3 = f.to - f.from
					dir.y = 0.0
					Sfx.play_at(f.to, "punch", -4.0, 1.3)
					hit.emit(dir.normalized())


func _exit_tree() -> void:
	for f in _flying:
		f.node.queue_free()
