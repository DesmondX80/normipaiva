extends CharacterBody3D
## Pelaaja jalan sisätiloissa. Kamera ylhäältä takaviistosta, liike maailman akseleilla; hiiriohjauksella (asetus)
## hiiri kääntää hahmoa ja liike on hahmon suuntaan.

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


## Sisätilan lattia (Rect2:t xz-tasossa, sisätilan kehyksessä): hahmo pysyy niiden sisällä, ettei oviaukoista
## pääse kävelemään tyhjyyteen. Tyhjä = ei rajaa (ulkona).
var bounds: Array = []
const BOUND_MARGIN := 0.35  # hahmon säde


func _keep_in_bounds() -> void:
	if bounds.is_empty():
		return
	var p := Vector2(position.x, position.z)
	var best := p
	var bd := INF
	for r: Rect2 in bounds:
		var g := r.grow(-BOUND_MARGIN)
		var q := Vector2(clampf(p.x, g.position.x, g.end.x), clampf(p.y, g.position.y, g.end.y))
		var d := q.distance_squared_to(p)
		if d < bd:
			bd = d
			best = q
	if bd > 0.0:
		position.x = best.x
		position.z = best.y


func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO
	if controls_enabled:
		v = Input.get_vector("left", "right", "forward", "back")
	var dir := Vector3(v.x, 0, v.y)
	var steer := controls_enabled and CamCtl.steering()
	if steer:
		# Hiiriohjaus (asetus): hiiri kääntää hahmoa, W/S eteen ja taakse katseen suuntaan, A/D sivuttain.
		rotation.y += CamCtl.yaw
		CamCtl.yaw = 0.0
		dir = (global_transform.basis * Vector3(v.x, 0, v.y)).normalized() * minf(v.length(), 1.0)
	velocity = dir * SPEED
	move_and_slide()
	_keep_in_bounds()
	global_position.y = Terrain.h(global_position.x, global_position.z)  # maaston pinnalla (sisätiloissa 0)
	if dir.length() > 0.1:
		if not steer:
			rotation.y = lerp_angle(rotation.y, B.yaw_to(dir), 1.0 - exp(-12.0 * delta))
		_body.play("Jog_Fwd", 0.15, 1.1 if v.y <= 0.0 else -0.8)
	else:
		_body.play("Idle", 0.2)
	_update_camera()


func _update_camera() -> void:
	_cam.global_position = global_position + CAM_OFFSET
	_cam.look_at(global_position + Vector3.UP * 0.8, Vector3.UP)
