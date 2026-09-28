extends CharacterBody3D
## Naapuri pihallaan (Arto, Pekka): kääntyy pelaajaa kohti ja juttelee, kun tämä on lähellä.
## Kaupankäynti ja muu toiminta hoidetaan main.gd:ssä (E-näppäin lähellä).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

var look := {}
var display_name := ""
var lines: Array = []
var voice := "mummo"
var target: Node3D

var _body: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _talk_t := 0.0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(B.capsule_shape(0.35, 1.8))
	_body = Looks.make(self, look)
	B.label(self, display_name, Vector3(0, 2.1, 0), 40, Color(0.9, 0.95, 1.0), true)
	_bubble = B.label(self, "", Vector3(0, 2.6, 0), 50, Color.WHITE, true)


func _physics_process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""
	if target == null:
		return
	var to_p := target.global_position - global_position
	to_p.y = 0.0
	var d := to_p.length()
	if d < 14.0:
		rotation.y = lerp_angle(rotation.y, B.yaw_to(to_p), 1.0 - exp(-4.0 * delta))
		_talk_t -= delta
		if _talk_t <= 0.0 and d < 9.0:
			say(lines.pick_random())
			_talk_t = randf_range(4.5, 7.0)
	_body.play("Idle_Talking" if _bubble_t > 0.0 else "Idle", 0.3)


func say(text: String) -> void:
	_bubble.text = text
	_bubble_t = 3.0
	Sfx.babble(self, voice, text)


func distance_to_player() -> float:
	if target == null:
		return INF
	var d := target.global_position - global_position
	return Vector2(d.x, d.z).length()
