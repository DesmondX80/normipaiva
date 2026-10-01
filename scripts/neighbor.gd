extends CharacterBody3D
## Naapurin Anna-Liisa: kiertää kaupan käytäviä, näkökenttä lattialla. Liian pitkä katse = käräytys.

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")

const SPEED := 1.8
const VIEW_RANGE := 9.0
const VIEW_HALF_ANGLE := 0.7854  # 45°
const SUSPICION_RATE := 55.0
const SUSPICION_DECAY := 10.0

signal busted

var target: Node3D
var waypoints: Array[Vector3] = []  # paikalliset koordinaatit kaupan sisällä
var pauses := {}  # waypoint-indeksi -> sekunnit
var suspicion := 0.0
var has_busted := false
var sees_player := false

var _wp := 0
var _wait := 0.0
var _fan_mat: StandardMaterial3D
var _mark: Label3D
var _bubble: Label3D
var _bubble_t := 0.0
var _anim_t := 0.0
var _body: Node3D


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(B.capsule_shape(0.3, 1.7))
	_body = Looks.make(self, Looks.ANNA_LIISA)
	B.guide(self, "Naapurin Anna-Liisa", Vector3(0, 2.1, 0), 40, Color(0.8, 1, 0.95), true)
	_mark = B.label(self, "", Vector3(0, 2.55, 0), 90, Color(1, 0.85, 0.1), true)
	_bubble = B.bubble(self, Vector3(0, 3.1, 0), Color.WHITE)

	var fan := MeshInstance3D.new()
	fan.mesh = B.vision_fan(VIEW_RANGE, VIEW_HALF_ANGLE)
	_fan_mat = B.unshaded(Color(1, 0.9, 0.2, 0.22))
	fan.material_override = _fan_mat
	fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fan.position.y = 0.05
	add_child(fan)
	_say("Kas, täällähän on väkeä...")


func _physics_process(delta: float) -> void:
	_walk(delta)
	_look(delta)
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""


func _walk(delta: float) -> void:
	if waypoints.is_empty():
		return
	if _wait > 0.0:
		_wait -= delta
		velocity = Vector3.ZERO
		_body.play("Idle_Talking" if _bubble_t > 0.0 else "Idle", 0.3)
		return
	var goal := waypoints[_wp]
	var to_g := goal - position
	to_g.y = 0.0
	if to_g.length() < 0.3:
		_wait = pauses.get(_wp, 0.0)
		_wp = (_wp + 1) % waypoints.size()
		return
	rotation.y = lerp_angle(rotation.y, B.yaw_to(to_g), 1.0 - exp(-6.0 * delta))
	velocity = to_g.normalized() * SPEED
	move_and_slide()
	global_position.y = Terrain.h(global_position.x, global_position.z)  # maaston pinnalla (sisätiloissa 0)
	_body.play("Walk", 0.25, SPEED / 1.4)


func _look(delta: float) -> void:
	var saw_before := sees_player
	sees_player = false
	if target != null and not has_busted:
		var to_p := target.global_position - global_position
		to_p.y = 0.0
		var d := to_p.length()
		var fwd := -global_transform.basis.z
		if d < VIEW_RANGE and fwd.angle_to(to_p) < VIEW_HALF_ANGLE:
			sees_player = B.line_of_sight(self, global_position + Vector3.UP * 1.5,
				target.global_position + Vector3.UP * 1.2,
				[get_rid(), (target as CollisionObject3D).get_rid()])
		if sees_player and not saw_before and _bubble_t <= 0.0:
			_say("Hmm? Onkos tuo...")
		if sees_player:
			suspicion += SUSPICION_RATE * (1.3 - d / VIEW_RANGE) * delta
		else:
			suspicion = maxf(0.0, suspicion - SUSPICION_DECAY * delta)
		if suspicion >= 100.0:
			suspicion = 100.0
			has_busted = true
			Sfx.play("alert")
			_say("Kyllä mää tästä Päiville kerron!")
			busted.emit()

	if has_busted:
		_mark.text = "!"
		_mark.modulate = Color(1, 0.15, 0.1)
		_fan_mat.albedo_color = Color(1, 0.2, 0.1, 0.12)
	elif sees_player:
		_mark.text = "?"
		_mark.modulate = Color(1, 0.85, 0.1)
		_fan_mat.albedo_color = Color(1, 0.4, 0.1, 0.35)
	else:
		_mark.text = "?" if suspicion > 5.0 else ""
		_fan_mat.albedo_color = Color(1, 0.9, 0.2, 0.22)


func _say(text: String) -> void:
	_bubble.text = "Anna-Liisa: " + text if text != "" else ""
	_bubble_t = 3.0
	Sfx.babble(self, "pirjo", text)
