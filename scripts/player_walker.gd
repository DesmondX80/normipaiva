extends CharacterBody3D
## Pelaaja jalan kaupan sisällä. Kamera ylhäältä takaviistosta, liike maailman akseleilla.

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")

const SPEED := 4.5
const CAM_OFFSET := Vector3(0, 10, 5.5)

var controls_enabled := false

var _body: Node3D
var _cam: Camera3D
var _bag: MeshInstance3D
var _anim_t := 0.0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(B.capsule_shape(0.3, 1.8))
	_body = Looks.make(self, Looks.PLAYER)
	Looks.add_cap(_body)
	var bag := Node3D.new()
	_bag = B.mesh(bag, B.boxm(Vector3(0.26, 0.34, 0.18)), Vector3(0, -0.2, 0), Color(1.0, 0.45, 0.0))
	_body.attach("hand_r", bag, Vector3(0, -0.05, 0))
	_bag.visible = false
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.top_level = true
	add_child(_cam)


func activate() -> void:
	controls_enabled = true
	_cam.current = true
	_update_camera()


func set_carrying(carrying: bool) -> void:
	_bag.visible = carrying


func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO
	if controls_enabled:
		v = Input.get_vector("left", "right", "forward", "back")
	var dir := Vector3(v.x, 0, v.y)
	velocity = dir * SPEED
	move_and_slide()
	global_position.y = Terrain.h(global_position.x, global_position.z)  # maaston pinnalla (sisätiloissa 0)
	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, B.yaw_to(dir), 1.0 - exp(-12.0 * delta))
		_body.play("Jog_Fwd", 0.15, 1.1)
	else:
		_body.play("Idle", 0.2)
	_update_camera()


func _update_camera() -> void:
	_cam.global_position = global_position + CAM_OFFSET
	_cam.look_at(global_position + Vector3.UP * 0.8, Vector3.UP)
