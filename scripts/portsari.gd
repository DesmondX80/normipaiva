extends CharacterBody3D
## Oulujärven lavan portsari (kuten Saloisten K-Marketin naapuri Anna-Liisa, neighbor.gd): kiertää lavan pihaa
## portilta ovelle ja takaisin, näkökenttä maassa. Pummilla pihalle tullut (main.gd asettaa watch) kerää
## epäilyä, kun portsari näkee hänet: liian pitkä katse = "Leimaa ei näy!" ja busted (main.gd heittää portista ulos).
## Leimallisista ei välitetä. Solmu Vaalan kehyksessä, maan korkeus ground-kutsulla (vaala.gd h).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const SPEED := 1.6
const VIEW_RANGE := 11.0
const VIEW_HALF_ANGLE := 0.7854  # 45°
const SUSPICION_RATE := 60.0
const SUSPICION_DECAY := 12.0
const LOOK := {"shirt": Color(0.06, 0.06, 0.07), "pants": Color(0.08, 0.08, 0.1), "shoes": Color(0.05, 0.05, 0.05),
	"hair": "Hair_Buzzed", "hair_color": Color(0.2, 0.15, 0.1), "height": 1.92, "bulk": 0.6, "shoulders": 0.6,
	"muscle": 0.4, "belly": 0.4}
const IDLE_LINES := ["Leimat näkyviin, kiitos.", "Ei pulloja sisälle.", "Rauhallisesti nyt, pojat.",
	"Kuka siellä aidan takana metelöi?", "Liput portilta, ei muualta."]

signal busted

var target: Node3D
var waypoints: Array[Vector3] = []
var pauses := {}
var ground := Callable()
var watch := false  # pummilla pihalla: epäily kertyy näköyhteydestä
var tip := false  # porukka kertoi portsarin tavat: epäily kertyy hitaammin
var suspicion := 0.0
var sees_player := false

var _wp := 0
var _wait := 0.0
var _fan_mat: StandardMaterial3D
var _mark: Label3D
var _bubble: Label3D
var _bubble_t := 0.0
var _chat_t := 8.0
var _body: Node3D
var _cooldown := 0.0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(B.capsule_shape(0.35, 1.8))
	_body = Looks.make(self, LOOK)
	B.guide(self, "Portsari", Vector3(0, 2.2, 0), 40, Color(0.8, 0.9, 1.0), true)
	_mark = B.label(self, "", Vector3(0, 2.65, 0), 90, Color(1, 0.85, 0.1), true)
	_bubble = B.bubble(self, Vector3(0, 3.1, 0), Color.WHITE)
	var fan := MeshInstance3D.new()
	fan.mesh = B.vision_fan(VIEW_RANGE, VIEW_HALF_ANGLE)
	_fan_mat = B.unshaded(Color(1, 0.9, 0.2, 0.22))
	fan.material_override = _fan_mat
	fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fan.position.y = 0.08
	add_child(fan)


func _physics_process(delta: float) -> void:
	_walk(delta)
	_look(delta)
	_cooldown = maxf(_cooldown - delta, 0.0)
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(12.0, 20.0)
		if _bubble_t <= 0.0:
			say(IDLE_LINES.pick_random())


func _walk(delta: float) -> void:
	if waypoints.is_empty():
		return
	if _wait > 0.0:
		_wait -= delta
		_body.play("Idle_Talking" if _bubble_t > 0.0 else "Idle", 0.3)
		# Pysähdyksissä portsari vilkuilee ympärilleen.
		rotation.y += sin(Time.get_ticks_msec() / 900.0) * delta * 0.5
		return
	var goal := waypoints[_wp]
	var to_g := goal - position
	to_g.y = 0.0
	if to_g.length() < 0.4:
		_wait = pauses.get(_wp, 0.0)
		_wp = (_wp + 1) % waypoints.size()
		return
	rotation.y = lerp_angle(rotation.y, B.yaw_to(to_g), 1.0 - exp(-5.0 * delta))
	velocity = to_g.normalized() * SPEED
	move_and_slide()
	if ground.is_valid():
		position.y = ground.call(position.x, position.z)
	_body.play("Walk", 0.25, SPEED / 1.4)


func _look(delta: float) -> void:
	var saw_before := sees_player
	sees_player = false
	if target != null and watch and _cooldown <= 0.0:
		var to_p := target.global_position - global_position
		to_p.y = 0.0
		var d := to_p.length()
		var fwd := -global_transform.basis.z
		if d < VIEW_RANGE and fwd.angle_to(to_p) < VIEW_HALF_ANGLE:
			sees_player = B.line_of_sight(self, global_position + Vector3.UP * 1.6,
				target.global_position + Vector3.UP * 1.2, [get_rid(), (target as CollisionObject3D).get_rid()])
		if sees_player and not saw_before and _bubble_t <= 0.0:
			say("Hetkinen... näytäpä kättä?")
		if sees_player:
			suspicion += SUSPICION_RATE * (0.6 if tip else 1.0) * (1.3 - d / VIEW_RANGE) * delta
		else:
			suspicion = maxf(0.0, suspicion - SUSPICION_DECAY * delta)
		if suspicion >= 100.0:
			suspicion = 0.0
			_cooldown = 6.0
			Sfx.play("alert")
			say("Leimaa ei näy! Ulos, ja heti!")
			busted.emit()
	else:
		suspicion = maxf(0.0, suspicion - SUSPICION_DECAY * delta)
	if sees_player:
		_mark.text = "?"
		_mark.modulate = Color(1, 0.85, 0.1)
		_fan_mat.albedo_color = Color(1, 0.4, 0.1, 0.35)
	else:
		_mark.text = "?" if suspicion > 5.0 else ""
		_fan_mat.albedo_color = Color(1, 0.9, 0.2, 0.22)


func say(text: String) -> void:
	_bubble.text = "Portsari: " + text if text != "" else ""
	_bubble_t = 3.0
