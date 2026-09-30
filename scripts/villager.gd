extends CharacterBody3D
## Naapuri pihallaan (Arto, Pekka, Sinikka): puuhailee pihalla (kävelee puuhapisteestä toiseen ja tekee niissä
## hetken jotain), kääntyy pelaajaa kohti ja juttelee, kun tämä on lähellä.
## Kaupankäynti ja muu toiminta hoidetaan main.gd:ssä (E-näppäin lähellä).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Terrain := preload("res://scripts/terrain.gd")

const WALK_SPEED := 1.1
const NEAR := 14.0  # tätä lähempänä pelaaja: puuhailu keskeytyy ja naapuri kääntyy juttelemaan

var look := {}
var display_name := ""
var lines: Array = []
var voice := "mummo"
var target: Node3D
## Pihan puuhapisteet maailmassa (ensimmäinen = ulko-ovi, lähtöpaikka). Tyhjä = seisoo paikallaan.
var yard: Array[Vector3] = []
## Valinnainen: mihin kukin puuhapiste katsoo (esim. kukkapenkki), sama järjestys kuin yard.
var faces: Array[Vector3] = []
## Puuhailuanimaatiot (Universal Animation Library); arvotaan jokaiseen puuhapisteeseen.
var chores: Array[String] = ["Fixing_Kneeling", "PickUp_Table", "Interact", "Crouch_Idle"]

var _body: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _talk_t := 0.0
var _goal := -1  # yard-indeksi, jota kohti kävellään (-1 = puuhailee paikallaan)
var _spot := 0
var _chore_t := 0.0
var _chore := "Idle"


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(B.capsule_shape(0.35, 1.8))
	_body = Looks.make(self, look)
	B.guide(self, display_name, Vector3(0, 2.1, 0), 40, Color(0.9, 0.95, 1.0), true)
	_bubble = B.label(self, "", Vector3(0, 2.6, 0), 50, Color.WHITE, true)
	_chore_t = randf_range(1.0, 4.0)  # hetki oven edessä ennen ensimmäistä puuhaa


func _physics_process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""
	var d := INF
	var to_p := Vector3.ZERO
	if target != null:
		to_p = target.global_position - global_position
		to_p.y = 0.0
		d = to_p.length()
	if d < NEAR:
		rotation.y = lerp_angle(rotation.y, B.yaw_to(to_p), 1.0 - exp(-4.0 * delta))
		_talk_t -= delta
		if _talk_t <= 0.0 and d < 9.0:
			say(lines.pick_random())
			_talk_t = randf_range(4.5, 7.0)
		_body.play("Idle_Talking" if _bubble_t > 0.0 else "Idle", 0.3)
		return
	_putter(delta)


## Puuhailu pihalla: kävelee seuraavaan puuhapisteeseen ja tekee siinä hetken jotain.
func _putter(delta: float) -> void:
	if yard.size() < 2:
		_body.play("Idle", 0.3)
		return
	if _goal >= 0:
		var to_g := yard[_goal] - global_position
		to_g.y = 0.0
		if to_g.length() < 0.25:
			_spot = _goal
			_goal = -1
			_chore = chores.pick_random()
			_chore_t = randf_range(5.0, 11.0)
			return
		var step := to_g.normalized() * minf(WALK_SPEED * delta, to_g.length())
		var p := global_position + step
		global_position = Vector3(p.x, Terrain.h(p.x, p.z), p.z)
		rotation.y = lerp_angle(rotation.y, B.yaw_to(to_g), 1.0 - exp(-6.0 * delta))
		_body.play("Walk", 0.3)
		return
	if faces.size() == yard.size():
		var to_f := faces[_spot] - global_position
		to_f.y = 0.0
		if to_f.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, B.yaw_to(to_f), 1.0 - exp(-5.0 * delta))
	_body.play(_chore, 0.4)
	_chore_t -= delta
	if _chore_t <= 0.0:
		var nxt := randi() % (yard.size() - 1)
		_goal = nxt if nxt < _spot else nxt + 1  # eri piste kuin nykyinen


func say(text: String) -> void:
	_bubble.text = "%s: %s" % [display_name.trim_prefix("Naapurin "), text] if text != "" else ""
	_bubble_t = 3.0
	Sfx.babble(self, voice, text)


func distance_to_player() -> float:
	if target == null:
		return INF
	var d := target.global_position - global_position
	return Vector2(d.x, d.z).length()
