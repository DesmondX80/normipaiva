extends CharacterBody3D
## Paapelin mopo (Vaalan-matka, mopo_trip.gd): 45 km/h, moottorin pörinä kierrosten mukaan, kallistus kaarteissa
## ja takaa seuraava kamera kuten pyörällä. Pinta ja mäet tulevat Vaalan maailmasta (vaala.gd).
## Malli (build_model) on myös mökin pihalla parkissa.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Vaala := preload("res://scripts/vaala.gd")

const MAX_SPEED := 12.5  # 45 km/h
const REVERSE_SPEED := 1.5
const ACCEL := 3.4
const BRAKE := 9.0
const DRAG := 0.9
const STEER_SPEED := 1.9
const GRAVITY := 20.0
const SLOPE := 5.0

var speed := 0.0
var controls_enabled := true
var vaala: Node3D  # vaala.gd (paikallinen kehys = mopo_trip.gd:n kehys)

var _visual: Node3D
var _rider: Node3D
var _cam: Camera3D
var _cam_ready := false
var _lean := 0.0
var _wheels: Array[Node3D] = []
var _engine: AudioStreamPlayer
var _bump_t := 0.0
var _code := Vaala.ROAD


func _ready() -> void:
	collision_mask |= 16
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_visual = Node3D.new()
	add_child(_visual)
	_wheels = build_model(_visual)
	_rider = Looks.make(_visual, Looks.PLAYER)
	Looks.add_cap(_rider)
	CamCtl.mark_own_body(_rider)
	_rider.play("Driving", 0.0)
	_rider.anim.advance(0.01)
	var seat := Vector3(0, 0.82, 0.25)
	_rider.position = seat + Vector3(0, 0.1, 0.0) - _rider.bone_position("pelvis")
	_rider.set_override("spine_01", Vector3.RIGHT, -0.15)
	_cam = Camera3D.new()
	_cam.fov = 72.0
	_cam.far = 1600.0
	_cam.top_level = true
	add_child(_cam)
	_engine = AudioStreamPlayer.new()
	_engine.stream = Sfx.stream("engine")
	_engine.bus = "SFX"
	_engine.volume_db = -12.0
	add_child(_engine)
	_engine.play()


func activate_camera() -> void:
	_cam.current = true
	_cam_ready = false


func set_engine(on: bool) -> void:
	if on and not _engine.playing:
		_engine.play()
	elif not on:
		_engine.stop()


## 70-luvun mopo: punainen runko ja tankki, musta satula, kromilokasuojat, pyöreä ajovalo, tavarateline.
## Palauttaa pyörien kääntöpisteet (pyörivät ajettaessa).
static func build_model(parent: Node3D) -> Array[Node3D]:
	var red := Color(0.72, 0.08, 0.06)
	var black := Color(0.05, 0.05, 0.05)
	var chrome := Color(0.8, 0.8, 0.82)
	var wheels: Array[Node3D] = []
	for z in [-0.58, 0.6]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.3, z)
		parent.add_child(pivot)
		var tire := TorusMesh.new()
		tire.inner_radius = 0.2
		tire.outer_radius = 0.3
		tire.rings = 18
		tire.ring_segments = 8
		B.mesh(pivot, tire, Vector3.ZERO, black, Vector3(0, 0, 90))
		B.mesh(pivot, B.cyl(0.19, 0.19, 0.05, 14), Vector3.ZERO, chrome, Vector3(0, 0, 90))
		B.mesh(parent, B.boxm(Vector3(0.12, 0.03, 0.5)), Vector3(0, 0.63, z + (0.05 if z > 0 else -0.05)), chrome)
		wheels.append(pivot)
	# Runko: putki etuhaarukasta satulan alle ja moottori keskellä.
	B.tube(parent, Vector3(0, 1.0, -0.5), Vector3(0, 0.3, -0.58), 0.03, chrome)
	B.tube(parent, Vector3(0, 0.95, -0.46), Vector3(0, 0.45, 0.05), 0.04, red)
	B.tube(parent, Vector3(0, 0.45, 0.05), Vector3(0, 0.3, 0.6), 0.035, red)
	B.mesh(parent, B.boxm(Vector3(0.24, 0.26, 0.36)), Vector3(0, 0.38, 0.05), Color(0.25, 0.25, 0.27))
	B.mesh(parent, B.cyl(0.09, 0.09, 0.24, 10), Vector3(0.0, 0.38, -0.1), Color(0.55, 0.55, 0.57), Vector3(0, 0, 90))
	B.tube(parent, Vector3(0.1, 0.32, 0.1), Vector3(0.12, 0.3, 0.75), 0.035, chrome)  # pakoputki
	B.mesh(parent, B.boxm(Vector3(0.22, 0.2, 0.42)), Vector3(0, 0.78, -0.2), red)  # tankki
	B.mesh(parent, B.boxm(Vector3(0.24, 0.1, 0.5)), Vector3(0, 0.84, 0.25), black)  # satula
	B.mesh(parent, B.boxm(Vector3(0.3, 0.03, 0.34)), Vector3(0, 0.82, 0.62), chrome)  # tavarateline
	B.mesh(parent, B.boxm(Vector3(0.26, 0.24, 0.1)), Vector3(0, 0.72, 0.52), red)
	# Ohjaustanko, peilit ja ajovalo.
	B.tube(parent, Vector3(-0.32, 1.08, -0.46), Vector3(0.32, 1.08, -0.46), 0.018, chrome)
	for gx in [-0.3, 0.3]:
		B.tube(parent, Vector3(gx - 0.05, 1.08, -0.46), Vector3(gx + 0.05, 1.08, -0.46), 0.028, black)
		B.tube(parent, Vector3(gx * 0.8, 1.08, -0.46), Vector3(gx * 0.9, 1.3, -0.5), 0.01, chrome)
		B.mesh(parent, B.cyl(0.05, 0.05, 0.02, 10), Vector3(gx * 0.9, 1.32, -0.5), chrome, Vector3(90, 0, 0))
	B.mesh(parent, B.cyl(0.09, 0.1, 0.12, 14), Vector3(0, 0.95, -0.6), chrome, Vector3(90, 0, 0))
	B.mesh(parent, B.cyl(0.075, 0.075, 0.02, 14), Vector3(0, 0.95, -0.665), Color(1.0, 0.95, 0.75), Vector3(90, 0, 0))
	B.mesh(parent, B.boxm(Vector3(0.08, 0.05, 0.02)), Vector3(0, 0.72, 0.8), Color(0.8, 0.05, 0.05))  # takavalo
	var plate := B.mesh(parent, B.boxm(Vector3(0.16, 0.1, 0.01)), Vector3(0, 0.6, 0.82), Color(0.95, 0.95, 0.95))
	B.label(plate, "V12", Vector3(0, 0, 0.01), 18, Color.BLACK)
	return wheels


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer := 0.0
	var braking := false
	if controls_enabled:
		throttle = Input.get_axis("back", "forward")
		steer = Input.get_axis("right", "left")
		braking = Input.is_action_pressed("brake")
		if Input.is_action_just_pressed("bell"):
			Sfx.play("horn", -8.0, 1.8)  # mopon piippari
	var surf: Dictionary = {"speed": 1.0, "bump": 0.0}
	if vaala != null:
		_code = vaala.code_at(position.x, position.z)
		surf = Vaala.SURF.get(_code, surf)
	# Mäet: nousu hidastaa, lasku kiihdyttää (vaalan korkeus 1 m edessä ja takana).
	var fwd := -global_transform.basis.z
	var grade := 0.0
	if vaala != null:
		grade = (vaala.h(position.x + fwd.x, position.z + fwd.z) - vaala.h(position.x - fwd.x, position.z - fwd.z)) / 2.0
	var max_s: float = MAX_SPEED * surf.speed * clampf(1.0 - grade * 2.5, 0.6, 1.2)
	if throttle > 0.0:
		speed = move_toward(speed, max_s, ACCEL * throttle * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, 0.0 if speed > 0.1 else -REVERSE_SPEED, (BRAKE if speed > 0.1 else ACCEL) * delta)
	else:
		speed = move_toward(speed, 0.0, DRAG * delta)
	if braking:
		speed = move_toward(speed, 0.0, BRAKE * delta)
	speed -= SLOPE * grade * delta
	if speed > max_s:
		speed = move_toward(speed, max_s, 4.0 * delta)
	var steer_factor := clampf(absf(speed) / 3.0, 0.0, 1.0) * lerpf(1.0, 0.6, clampf(absf(speed) / MAX_SPEED, 0.0, 1.0))
	rotation.y += steer * STEER_SPEED * steer_factor * signf(speed) * delta
	fwd = -global_transform.basis.z
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	speed = Vector2(velocity.x, velocity.z).dot(Vector2(fwd.x, fwd.z))
	_lean = lerpf(_lean, steer * steer_factor * 0.4, 1.0 - exp(-5.0 * delta))
	_visual.rotation.z = _lean
	_bump_t += delta * absf(speed)
	var bump: float = surf.bump * clampf(absf(speed) / 5.0, 0.0, 1.0) * sin(_bump_t * 3.3) * sin(_bump_t * 1.9)
	_visual.position.y = lerpf(_visual.position.y, bump, 1.0 - exp(-14.0 * delta))
	for w in _wheels:
		w.rotation.x -= speed * delta / 0.3
	_pose_rider()
	var k := clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
	_engine.pitch_scale = lerpf(1.1, 2.6, k) + (0.25 if throttle > 0.0 else 0.0)
	_engine.volume_db = lerpf(-14.0, -6.0, maxf(k, 0.4 if throttle > 0.0 else 0.0))
	var eye: Vector3 = _rider.to_global(_rider.bone_position("Head")) + Vector3.UP * 0.1
	CamCtl.update_camera(_cam, self, eye, 5.2, 2.4, absf(speed) > 1.0, delta, not _cam_ready, Vector3.ZERO)
	_cam_ready = true


## Kädet tangolle ja jalat jalkatapeille (IK kuten pyörällä).
func _pose_rider() -> void:
	var inv := _rider.transform.affine_inverse()
	for side in [["_l", -1.0], ["_r", 1.0]]:
		var s: float = side[1]
		_rider.set_ik("arm" + side[0], "upperarm" + side[0], "lowerarm" + side[0], "hand" + side[0],
			inv * Vector3(0.3 * s, 1.1, -0.44), inv * Vector3(0.55 * s, 1.2, 0.0))
		_rider.set_ik("leg" + side[0], "thigh" + side[0], "calf" + side[0], "foot" + side[0],
			inv * Vector3(0.2 * s, 0.35, -0.05), inv * Vector3(0.2 * s, 0.9, -0.6))
