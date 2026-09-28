extends Node3D
## Laavun valtaajat: joko vittumainen akka, joka asettuu pelaajan ja nuotion väliin, tai teinijengi,
## joka rikkoo paikkoja ja jonka pomo hyökkää kimppuun. Kosketus -> challenge-signaali -> tappelu.

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")

const AKKA_LINES := ["Tää on MEIDÄN laavu!", "Täällä ei kaljoitella!", "Menes siitä kotias!",
	"Kuka sulle luvan antoi?", "Mää soitan poliisille!", "Mää oon varannu tän koko kesäks!"]
const TEEN_LINES := ["Mitä sää tuijotat, setä?", "Tää on meiän mesta!", "Ok boomer.", "Painu kotiis!",
	"Raahe 4ever!", "Onks sulla kaljaa? Anna!"]
const SEE := 26.0
const TOUCH := 1.5

signal challenge(foe_key: String, direction: Vector3)

var kind := "akka"  # akka | teens
var target: Node3D
var world: Node3D
var center := Vector3.ZERO  # nuotio
var mode := "idle"  # idle, guard, cooldown, leave, gone

var _boss: CharacterBody3D
var _boss_body: Node3D
var _crew: Array[Node3D] = []
var _bubble: Label3D
var _bubble_t := 0.0
var _talk_t := 0.0
var _cool := 0.0
var _leave_t := 0.0
var _mess: Array[Node3D] = []


func _ready() -> void:
	_boss = CharacterBody3D.new()
	_boss.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_boss.add_child(B.capsule_shape(0.35, 1.8))
	add_child(_boss)
	if kind == "akka":
		_boss_body = Looks.make(_boss, Looks.AKKA)
		_boss.position = center + Vector3(1.4, 0, -3.3)
		B.label(_boss, "Laavun akka", Vector3(0, 2.05, 0), 40, Color(1, 0.8, 0.8), true)
	else:
		_boss_body = Looks.make(_boss, Looks.TEENS[0])
		_boss.position = center + Vector3(-1.2, 0, -3.4)
		B.label(_boss, "Teinijengin pomo", Vector3(0, 2.1, 0), 40, Color(0.8, 1, 0.8), true)
		_build_vandalism()
	_bubble = B.label(_boss, "", Vector3(0, 2.6, 0), 52, Color.WHITE, true)


## Teinit: kaksi kaveria riehuu, roskis kaatuneena, töhrytys katoksessa.
func _build_vandalism() -> void:
	for i in 2:
		var t := Looks.make(self, Looks.TEENS[i + 1])
		t.position = center + [Vector3(1.3, 0, 1.3), Vector3(3.2, 0, -1.8)][i]
		t.rotation.y = [2.4, -2.2][i]
		t.play(["Punch_Jab", "Dance"][i], 0.0)
		_crew.append(t)
	var bin := Node3D.new()
	bin.position = center + Vector3(3.0, 0.3, 0.8)
	bin.rotation.z = PI / 2.0
	add_child(bin)
	B.mesh(bin, B.cyl(0.3, 0.26, 0.8, 12), Vector3.ZERO, Color(0.2, 0.35, 0.25))
	_mess.append(bin)
	for k in 6:
		B.mesh(self, B.boxm(Vector3(0.15, 0.02, 0.1)), center + Vector3(randf_range(1.5, 4.0), 0.02, randf_range(-1.0, 2.0)),
			[Color(0.9, 0.9, 0.9), Color(0.8, 0.2, 0.2), Color(0.2, 0.5, 0.9)][k % 3])
	var tag := B.label(self, "RAAHE 4EVER", center + Vector3(0, 1.3, 4.9), 90, Color(0.2, 1.0, 0.4))
	tag.rotation_degrees.y = 180.0
	tag.outline_modulate = Color(0.5, 0.0, 0.6)


func _physics_process(delta: float) -> void:
	if target == null or mode == "gone":
		return
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""
	var to_p := target.global_position - _boss.global_position
	to_p.y = 0.0
	var d := to_p.length()
	var player_to_fire := Vector2(target.global_position.x - center.x, target.global_position.z - center.z).length()
	var move := Vector3.ZERO

	match mode:
		"idle":
			_face(to_p if player_to_fire < SEE * 1.3 else center - _boss.position)
			if player_to_fire < SEE:
				mode = "guard"
				_say()
		"guard":
			_face(to_p)
			_talk_t -= delta
			if _talk_t <= 0.0:
				_say()
			if kind == "akka":
				# Asettuu pelaajan ja nuotion väliin.
				var dir := Vector3(target.global_position.x - center.x, 0, target.global_position.z - center.z).normalized()
				var goal := center + dir * clampf(player_to_fire - 1.6, 1.2, 6.0)
				var to_g := goal - _boss.position
				to_g.y = 0.0
				if to_g.length() > 0.2:
					move = to_g.normalized() * minf(4.2, to_g.length() * 4.0)
			else:
				move = to_p.normalized() * 6.5
			if d < TOUCH:
				mode = "cooldown"
				_cool = 3.0
				challenge.emit(kind, to_p.normalized())
			elif player_to_fire > SEE * 1.5:
				mode = "idle"
		"cooldown":
			_cool -= delta
			if _cool <= 0.0:
				mode = "guard"
		"leave":
			# Hävisivät: lähtevät pois nuotiolta ja katoavat.
			_leave_t -= delta
			var away := (_boss.position - center)
			away.y = 0.0
			move = (away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * 5.5
			_face(move)
			for t in _crew:
				var a := t.position - center
				a.y = 0.0
				t.position += (a.normalized() if a.length() > 0.1 else Vector3.LEFT) * 5.5 * delta
				t.rotation.y = B.yaw_to(a)
				t.play("Sprint", 0.2)
			if _leave_t <= 0.0:
				mode = "gone"
				visible = false
				# Kappale poistuu fysiikasta heti, joten tässä ruudussa ei enää liikuta.
				_boss.process_mode = Node.PROCESS_MODE_DISABLED
				return

	if world != null:
		move *= world.speed_factor(_boss.global_position, "runner")
	_boss.velocity = move
	_boss.move_and_slide()
	_boss.global_position.y = Terrain.h(_boss.global_position.x, _boss.global_position.z)  # maaston pinnalla
	var spd := move.length()
	if mode == "idle":
		_boss_body.play("Idle_Talking" if kind == "akka" else "Punch_Cross", 0.3)
	elif spd > 4.5:
		_boss_body.play("Sprint", 0.2, spd / 6.5)
	elif spd > 0.3:
		_boss_body.play("Walk", 0.2, spd / 1.4)
	else:
		_boss_body.play("Idle_Talking", 0.3)


## Laavu on jo vallattu aiemmin: valtaajia ei ole.
func vanish() -> void:
	mode = "gone"
	visible = false
	_boss.process_mode = Node.PROCESS_MODE_DISABLED


## Pelaaja voitti tappelun: valtaajat lähtevät.
func defeat() -> void:
	mode = "leave"
	_leave_t = 7.0
	_bubble.text = "Äitiii!" if kind == "akka" else "Juostaan!"
	_bubble_t = 2.0
	Sfx.babble(_boss, "akka" if kind == "akka" else "teini", _bubble.text)


## Valtaajat voittivat: hetken tauko ennen uutta vahtimista.
func gloat() -> void:
	mode = "cooldown"
	_cool = 4.0
	_bubble.text = "Ja pysy poissa!" if kind == "akka" else "Hähää, boomer!"
	_bubble_t = 2.5
	Sfx.babble(_boss, "akka" if kind == "akka" else "teini", _bubble.text)


func is_blocking() -> bool:
	return mode in ["idle", "guard", "cooldown"]


func boss_position() -> Vector3:
	return _boss.global_position


func _face(dir: Vector3) -> void:
	if dir.length() > 0.1:
		_boss.rotation.y = B.yaw_to(dir)


func _say() -> void:
	_bubble.text = (AKKA_LINES if kind == "akka" else TEEN_LINES).pick_random()
	_bubble_t = 2.4
	_talk_t = 3.2
	Sfx.babble(_boss, "akka" if kind == "akka" else "teini", _bubble.text)
