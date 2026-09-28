extends CharacterBody3D
## Paikallinen juntti, Raahen karateklubin perustaja. Vittuilee, juoksee perään ja potkaisee.

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")

const RUN_SPEED := 8.0
const WALK_SPEED := 2.5
const NOTICE := 18.0
const GIVE_UP := 45.0
const KICK_DIST := 1.9
const COOLDOWN := 3.5

const TAUNTS := [
	"Mitä sää siinä polijet?",
	"Ootko sää joku ongelma vai?",
	"Tuu tänne ni jutellaan!",
	"Mää perustin Raahen karateklubin, tiesiksää?",
	"Hei hienohelma! Mihin matka?",
	"Mää oon musta vyö, sää oot kohta musta silmä!",
	"Onko sulla kaljaa? Anna yks!",
]
const KICK_LINES := ["HAI-JAAH!", "Raahen karateklubi, vuodesta -87!", "Tuosta sait!"]
const GIVE_UP_LINES := ["Pelkuri! Ens kerralla!", "Juokse vaan mammas luo!"]

signal kicked(direction: Vector3)

var target: Node3D
var world: Node3D
var home_pos := Vector3.ZERO
var mode := "idle"  # idle, chase, cooldown, return, defeated

var _body: Node3D
var _bubble: Label3D
var _label: Label3D
var _bubble_t := 0.0
var _talk_t := 0.0
var _cool := 0.0
var _anim_t := 0.0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(B.capsule_shape(0.35, 1.8))
	# Musta verkkari, valkoiset raidat, vaalea hiuspehko.
	_body = Looks.make(self, Looks.JUNTTI)
	_label = B.label(self, "Paikallinen juntti", Vector3(0, 2.25, 0), 40, Color(1, 0.9, 0.6), true)
	_bubble = B.label(self, "", Vector3(0, 2.7, 0), 56, Color.WHITE, true)
	home_pos = position


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var to_p := target.global_position - global_position
	to_p.y = 0.0
	var d := to_p.length()

	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""

	var move := Vector3.ZERO
	match mode:
		"idle":
			if d < NOTICE * 1.6:
				_face(to_p)
			if d < NOTICE:
				mode = "chase"
				_say(TAUNTS.pick_random())
				_talk_t = 2.5
		"chase":
			_face(to_p)
			move = to_p.normalized() * RUN_SPEED
			_talk_t -= delta
			if _talk_t <= 0.0:
				_say(TAUNTS.pick_random())
				_talk_t = 2.5
			if d < KICK_DIST:
				_kick(to_p.normalized())
			elif global_position.distance_to(home_pos) > GIVE_UP:
				mode = "return"
				_say(GIVE_UP_LINES.pick_random())
		"cooldown":
			_cool -= delta
			if _cool < COOLDOWN - 0.5:
				_body.set_override("thigh_r", Vector3.RIGHT, 0.0)
			if _cool <= 0.0:
				mode = "chase" if d < NOTICE else "return"
		"defeated":
			var away := home_pos - global_position
			away.y = 0.0
			if away.length() > 1.0:
				_face(away)
				move = away.normalized() * WALK_SPEED * 0.6
		"return":
			var to_home := home_pos - global_position
			to_home.y = 0.0
			if to_home.length() < 1.0:
				mode = "idle"
			else:
				_face(to_home)
				move = to_home.normalized() * WALK_SPEED
				if d < NOTICE * 0.7:
					mode = "chase"

	if world != null:
		move *= world.speed_factor(global_position, "runner")
	velocity = move
	move_and_slide()
	global_position.y = Terrain.h(global_position.x, global_position.z)  # maaston pinnalla (sisätiloissa 0)

	# Animaatio liikkeen mukaan.
	var spd := move.length()
	if mode == "cooldown":
		if _cool < COOLDOWN - 0.6:
			_body.play("Idle_Talking", 0.3)
	elif spd > 5.0:
		_body.play("Sprint", 0.2, spd / 6.5)
	elif spd > 0.5:
		_body.play("Walk", 0.2, spd / 1.4)
	else:
		_body.play("Idle_Talking" if _bubble_t > 0.0 else "Idle", 0.3)


## Hävisi tappelun: nilkuttaa kotiin eikä jahtaa enää.
func defeat() -> void:
	mode = "defeated"
	_say("Äitiii!")
	_label.text = "Nöyrtynyt juntti"


## Voitti tappelun: jää hetkeksi paikalleen nauramaan.
func gloat() -> void:
	mode = "cooldown"
	_cool = COOLDOWN
	_say(["Hähää!", "Ens kerralla enemmän!"].pick_random())


func _kick(dir: Vector3) -> void:
	mode = "cooldown"
	_cool = COOLDOWN
	_say(KICK_LINES.pick_random())
	_body.play("Punch_Cross", 0.1)
	_body.set_override("thigh_r", Vector3.RIGHT, 1.4)  # jalka ilmaan
	kicked.emit(dir)


func _face(dir: Vector3) -> void:
	if dir.length() > 0.1:
		rotation.y = B.yaw_to(dir)


func _say(text: String) -> void:
	_bubble.text = text
	_bubble_t = 2.2
	Sfx.babble(self, "juntti", text)
