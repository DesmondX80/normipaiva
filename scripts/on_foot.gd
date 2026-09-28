extends CharacterBody3D
## Pelaaja jalan ulkona: W/S eteen/taakse, A/D kääntyy, Shift juoksee. Kamera takaa kuten pyörällä.
## Sama rajapinta kuin pyörällä (speed, controls_enabled, surface, stun, set_carrying, activate_camera),
## jotta vaarat, kartat ja pelilogiikka toimivat kummalla tahansa.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const WALK := 1.9
const RUN := 5.4
const TURN := 2.6
const GRAVITY := 20.0

var controls_enabled := true
var world: Node3D
var surface := "asphalt"
var speed := 0.0
## Kestävyys: juoksu kuluttaa, kävely ja seisominen palauttavat. Tyhjänä ei voi juosta ennen kuin palautuu.
var stamina := 100.0
var exhausted := false
## Asento paikallaan seistessä (esim. marjojen poiminnan kyykky); tyhjä = tavallinen seisominen.
var pose := ""
var _breath_t := 0.0

var _body: Node3D
var _cam: Camera3D
var _cam_ready := false
var _stun := 0.0
var _push := Vector3.ZERO
var _bag: MeshInstance3D
var _step_t := 0.0


func _ready() -> void:
	collision_mask |= 16  # maasto (Terrain.COLLISION_LAYER)
	add_child(B.capsule_shape(0.3, 1.8))
	_body = Looks.make(self, Looks.PLAYER)
	Looks.add_cap(_body)
	CamCtl.mark_own_body(_body)
	var bag := Node3D.new()
	_bag = B.mesh(bag, B.boxm(Vector3(0.26, 0.34, 0.18)), Vector3(0, -0.2, 0), Color(1.0, 0.45, 0.0))
	_body.attach("hand_r", bag, Vector3(0, -0.05, 0))
	_bag.visible = false
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 900.0
	_cam.top_level = true
	add_child(_cam)


func activate_camera() -> void:
	_cam.current = true
	_cam_ready = false


func set_carrying(carrying: bool) -> void:
	_bag.visible = carrying


func is_stunned() -> bool:
	return _stun > 0.0


## Potku tai tönäisy: kaatuu maahan ja nousee hetken päästä.
func stun(direction: Vector3) -> void:
	_stun = 1.6
	speed = 0.0
	_push = direction * 5.0
	_body.play("Death01", 0.05, 2.0)
	Sfx.play("body_fall", -2.0)


func _physics_process(delta: float) -> void:
	if world != null:
		surface = world.surface_at(global_position)
	if _stun > 0.0:
		_stun -= delta
		_push = _push.move_toward(Vector3.ZERO, 10.0 * delta)
		velocity = Vector3(_push.x, velocity.y - GRAVITY * delta if not is_on_floor() else 0.0, _push.z)
		move_and_slide()
		if _stun <= 0.0:
			_body.play("Idle", 0.3)
		_update_camera(delta)
		return

	var throttle := 0.0
	var steer := 0.0
	var running := false
	if controls_enabled:
		throttle = Input.get_axis("back", "forward")
		steer = Input.get_axis("right", "left")
		running = Input.is_key_pressed(KEY_SHIFT) and throttle > 0.0 and not exhausted
	if running:
		stamina = maxf(0.0, stamina - 18.0 * delta)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(100.0, stamina + (22.0 if absf(speed) < 0.2 else 12.0) * delta)
		if exhausted and stamina >= 35.0:
			exhausted = false
	# Hengästyneenä kuuluu puuskutus.
	if exhausted:
		_breath_t -= delta
		if _breath_t <= 0.0:
			_breath_t = 0.75
			Sfx.play("whoosh", -10.0, 0.5)
	var ground: float = world.speed_factor(global_position, "runner") if world != null else 1.0
	var want := throttle * (RUN if running else WALK) * ground
	if throttle < 0.0:
		want *= 0.6  # peruutuskävely
	speed = move_toward(speed, want, 12.0 * delta)
	rotation.y += steer * TURN * delta

	var fwd := -global_transform.basis.z
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	speed = Vector2(velocity.x, velocity.z).dot(Vector2(fwd.x, fwd.z))

	var s := absf(speed)
	if s < 0.2:
		_body.play(pose if pose != "" else "Idle", 0.12 if pose != "" else 0.25)
	elif s < 2.8:
		_body.play("Walk", 0.2, signf(speed) * s / 1.4)
	else:
		_body.play("Sprint", 0.2, s / 6.0)
	# Askeleet: pehmeä töminä, soralla ja metsässä vähän kovempi.
	_step_t += s * delta
	var stride := 0.75 if s < 2.8 else 1.4
	if _step_t > stride:
		_step_t = 0.0
		var step := "step_hard" if surface in ["asphalt", "gravel"] else "step_grass"
		if surface in ["bog", "water"]:
			Sfx.play("water", -10.0, randf_range(1.4, 1.8))
		Sfx.play(step, -8.0 + (3.0 if s > 2.8 else 0.0), randf_range(0.9, 1.1))
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	var eye: Vector3 = _body.to_global(_body.bone_position("Head")) + Vector3.UP * 0.08
	CamCtl.update_camera(_cam, self, eye, 4.2, 2.6, absf(speed) > 0.5, delta, not _cam_ready)
	_cam_ready = true
