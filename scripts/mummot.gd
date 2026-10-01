extends Node3D
## K-Marketin edustan penkin mummot (#14). Liian läheltä ja lujaa pyöräilevä tai kelloa soittava (anger)
## suututtaa heidät: mummot heittelevät kettukarkkeja kaaressa hetken ajan. Osuma horjauttaa (hit). Maahan
## jääneet karkit voi poimia jalan (candy_picked). Paikallinen +Z = penkiltä parkkipaikalle päin.

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")

const ANGER_DIST := 4.0
const ANGER_SPEED := 5.0  # pyörän vauhti (m/s), jota lujempaa ohi kurvaava suututtaa
const ANGER_TIME := 6.0
const THROW_RANGE := 18.0
const FLIGHT := 0.9
const HIT_DIST := 1.1
const PICK_DIST := 0.9
const CANDY_LIFE := 40.0
const ANGRY_LINES := ["Hullu!", "Nuoriso nykyään!", "Katos pyörääs!", "Poliisi pittää kutsua!", "Senki pölijä!"]
const CALM_LINES := ["Kattokaa ny tuota.", "Ennen oli kaikki paremmin.", "Kallistunu taas maito.", "Onko se Päivin mies?"]

signal hit(direction: Vector3)
signal candy_picked
signal angered  # mummot suuttuivat (main.gd: moraali laskee)

var target: Node3D
var anger_speed := ANGER_SPEED  # päivän tilat (#18) säätävät herkkyyttä

var _grans: Array[Node3D] = []
var _bubbles: Array[Label3D] = []
var _bubble_t: Array[float] = [0.0, 0.0, 0.0]
var _throw_t: Array[float] = [0.0, 0.0, 0.0]
var _angry := 0.0
var _chat_t := 6.0
var _flying: Array = []  # {node, from, to, t}
var _ground: Array = []  # {node, age}


func _ready() -> void:
	# Penkki: istuin, selkänoja ja jalat.
	var wood := Color(0.5, 0.33, 0.18)
	B.mesh(self, B.boxm(Vector3(3.0, 0.08, 0.5)), Vector3(0, 0.45, 0), wood)
	B.mesh(self, B.boxm(Vector3(3.0, 0.4, 0.06)), Vector3(0, 0.75, -0.24), wood)
	for x in [-1.35, 1.35]:
		B.mesh(self, B.boxm(Vector3(0.08, 0.45, 0.45)), Vector3(x, 0.22, 0), Color(0.25, 0.25, 0.27))
	var body := StaticBody3D.new()
	add_child(body)
	body.add_child(B.box_shape(Vector3(3.0, 1.0, 0.6), Vector3(0, 0.5, 0)))
	for i in 3:
		var g := Looks.make(self, Looks.MUMMOT[i])
		g.position = Vector3(-1.0 + i, 0.25, 0.05)
		g.play("Sitting_Idle", 0.0)
		_grans.append(g)
		var bubble := B.bubble(self, g.position + Vector3(0, 1.45, 0.1), Color.WHITE)
		_bubbles.append(bubble)


## Kello tai muu kiusanteko: suuttuvat varmasti.
func anger() -> void:
	if _angry <= 0.0:
		angered.emit()
		for i in 3:
			_say(i, "Mummo: " + ANGRY_LINES.pick_random())
			_throw_t[i] = randf_range(0.2, 0.8)
	_angry = ANGER_TIME


func is_angry() -> bool:
	return _angry > 0.0


func distance_to_target() -> float:
	if target == null:
		return INF
	var d := target.global_position - global_position
	return Vector2(d.x, d.z).length()


func _process(delta: float) -> void:
	for i in 3:
		_bubble_t[i] -= delta
		if _bubble_t[i] <= 0.0:
			_bubbles[i].text = ""
	_update_candies(delta)
	if target == null:
		return
	var d := distance_to_target()
	var on_bike := target.has_method("set_rider_visible")
	if on_bike and d < ANGER_DIST and absf(float(target.get("speed"))) > anger_speed:
		anger()
	if _angry > 0.0:
		_angry -= delta
		if d > THROW_RANGE * 1.4:
			_angry = 0.0  # poistui: rauhoittuvat
		for i in 3:
			_grans[i].play("Sitting_Talking", 0.2)
			_throw_t[i] -= delta
			if _throw_t[i] <= 0.0 and d < THROW_RANGE:
				_throw_t[i] = randf_range(1.2, 2.0)
				_throw(i)
		if _angry <= 0.0:
			_say(randi() % 3, "Mummo: No niin. Mennään kattomaan Salkkareita.")
		return
	for g in _grans:
		g.play("Sitting_Idle", 0.3)
	_chat_t -= delta
	if _chat_t <= 0.0 and d < 12.0:
		_chat_t = randf_range(7.0, 12.0)
		_say(randi() % 3, "Mummo: " + CALM_LINES.pick_random())


func _say(i: int, text: String) -> void:
	_bubbles[i].text = text
	_bubble_t[i] = 2.2


## Kettukarkki kaaressa kohti pelaajan ennakoitua paikkaa.
func _throw(i: int) -> void:
	var from: Vector3 = _grans[i].global_position + Vector3(0, 1.1, 0.2)
	var v: Vector3 = target.get("velocity") if target.get("velocity") != null else Vector3.ZERO
	var to := target.global_position + Vector3(v.x, 0, v.z) * FLIGHT + Vector3(randf_range(-1.3, 1.3), 0, randf_range(-1.3, 1.3))
	to.y = T.h(to.x, to.z) + 0.05
	var c := Node3D.new()
	var col: Color = [Color(0.95, 0.45, 0.05), Color(0.85, 0.1, 0.1), Color(0.95, 0.8, 0.1)].pick_random()
	B.mesh(c, B.boxm(Vector3(0.06, 0.04, 0.09)), Vector3.ZERO, col)
	get_tree().current_scene.add_child(c)
	c.global_position = from
	_flying.append({"node": c, "from": from, "to": to, "t": 0.0})
	Sfx.play_at(from, "whoosh", -10.0, 1.8)


func _update_candies(delta: float) -> void:
	for f in _flying.duplicate():
		f.t += delta / FLIGHT
		var u: float = minf(f.t, 1.0)
		var p: Vector3 = f.from.lerp(f.to, u)
		p.y += sin(u * PI) * 2.2
		f.node.global_position = p
		f.node.rotation += Vector3(9.0, 7.0, 0.0) * delta
		if u >= 1.0:
			_flying.erase(f)
			_ground.append({"node": f.node, "age": 0.0})
			if target != null and _flat(target.global_position, f.to) < HIT_DIST:
				var dir: Vector3 = (f.to - f.from)
				dir.y = 0.0
				Sfx.play_at(f.to, "punch", -6.0, 1.6)
				hit.emit(dir.normalized())
	for g in _ground.duplicate():
		g.age += delta
		var node: Node3D = g.node
		if g.age > CANDY_LIFE:
			node.queue_free()
			_ground.erase(g)
		elif target != null and not target.has_method("set_rider_visible") and g.age > 0.5 \
				and _flat(target.global_position, node.global_position) < PICK_DIST:
			node.queue_free()
			_ground.erase(g)
			Sfx.play("pickup", -8.0, 1.5)
			candy_picked.emit()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _exit_tree() -> void:
	for f in _flying:
		f.node.queue_free()
	for g in _ground:
		g.node.queue_free()
