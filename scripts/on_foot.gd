extends CharacterBody3D
## Pelaaja jalan ulkona: W/S eteen/taakse, A/D kääntyy, Shift juoksee. Kamera takaa kuten pyörällä.
## Sama rajapinta kuin pyörällä (speed, controls_enabled, surface, stun, set_carrying, activate_camera),
## jotta vaarat, kartat ja pelilogiikka toimivat kummalla tahansa.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const DrunkWobble := preload("res://scripts/drunk_wobble.gd")

const WALK := 2.3
const RUN := 5.4
## Juoksu kuluttaa kuntoa hitaammin kuin pyörän spurtti: täydellä kunnolla jaksaa juosta noin 20 s.
const RUN_DRAIN := 5.0
const TURN := 2.6
const GRAVITY := 20.0
const JUMP_SPEED := 6.5

var controls_enabled := true
var world: Node3D
var surface := "asphalt"
var speed := 0.0
var _strafe := 0.0  # sivuttaisvauhti (hiiriohjauksen A/D)
## Kestävyys: juoksu kuluttaa, kävely ja seisominen palauttavat. Tyhjänä ei voi juosta ennen kuin palautuu.
var stamina := 100.0
var exhausted := false
## Asento paikallaan seistessä (esim. marjojen poiminnan kyykky); tyhjä = tavallinen seisominen.
var pose := ""
## Juoksu estetty (esim. ruohonleikkurin työntäminen).
var no_run := false
## Vieraan koiran purema (main.gd): ontuu, ja kunto palautuu hitaammin. Pyörä lukee saman (raskaampi polkea).
var hurt := false
const HURT_SPEED := 0.6
const HURT_RECOVER := 0.5
## Humala (main.gd asettaa aina, tilasta riippumatta): yli DrunkWobble.LIMIT kävely heittelee.
var drunk := 0.0
var _drunk_wobble := DrunkWobble.new()
## Päivän tilojen palkinnot ja haitat (main.gd _stat_effects). Pyörä lukee näistä nopeuden, kulutuksen ja spurtin.
var speed_mult := 1.0  # nälkä: kävely ja juoksu
var run_mult := 1.0  # kipu: juoksu
var jump_mult := 1.0  # kipu: hyppy
var drain_mult := 1.0  # väsymys: juoksun ja spurtin kulutus
var recover_mult := 1.0  # väsymys: palautuminen
var no_sprint := false  # stamina: juoksu ja spurtti eivät toimi
var _breath_t := 0.0

var _body: Node3D
var _cam: Camera3D
var _cam_ready := false
var _stun := 0.0
var _push := Vector3.ZERO
var _bag: MeshInstance3D
var _kanister: Node3D
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
	# Pontikkakanisteri vasemmassa kädessä.
	var can := Node3D.new()
	# Roikkuu vasemmalla kyljellä käden alla (hahmon juuressa, ei käden luussa: pysyy pystyssä).
	B.mesh(can, B.boxm(Vector3(0.12, 0.32, 0.26)), Vector3.ZERO, Color(0.92, 0.92, 0.88))
	B.mesh(can, B.boxm(Vector3(0.04, 0.05, 0.12)), Vector3(0, 0.18, -0.04), Color(0.85, 0.15, 0.1))
	can.position = Vector3(-0.34, 0.6, 0.0)
	add_child(can)
	_kanister = can
	can.visible = false
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


## Kädessä kannettava esine (huussin sanko, halkosyli, kahvikuppi); null = tyhjät kädet.
var _held: Node3D


func set_held(node: Node3D) -> void:
	if _held != null:
		_held.queue_free()
		_held = null
	if node != null:
		_held = _body.attach("hand_r", node, Vector3(0, -0.05, 0))


func set_kanister(on: bool) -> void:
	_kanister.visible = on


func is_stunned() -> bool:
	return _stun > 0.0


## Potku tai tönäisy: kaatuu maahan ja nousee hetken päästä.
func stun(direction: Vector3) -> void:
	_stun = 1.6
	speed = 0.0
	_push = direction * 5.0
	_body.play("Death01", 0.05, 2.0)
	Sfx.play("body_fall", -2.0)


## Kevyt osuma (kettukarkki): horjahtaa hetken taaksepäin kaatumatta.
func stagger(direction: Vector3) -> void:
	_stun = 0.35
	speed = 0.0
	_push = direction * 2.5


## Kunnon kulutus ja palautuminen. Pyörän spurtti käyttää samaa mittaria (jalat ovat samat).
func tire(exerting: bool, resting: bool, delta: float, drain := 18.0) -> void:
	if exerting:
		stamina = maxf(0.0, stamina - drain * drain_mult * delta)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(100.0, stamina + (22.0 if resting else 12.0) * (HURT_RECOVER if hurt else 1.0) * recover_mult * delta)
		if exhausted and stamina >= 35.0:
			exhausted = false
	# Hengästyneenä kuuluu puuskutus.
	if exhausted:
		_breath_t -= delta
		if _breath_t <= 0.0:
			_breath_t = 0.75
			Sfx.play("whoosh", -10.0, 0.5)


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
	var strafe := 0.0
	var running := false
	var jump_pressed := false
	if controls_enabled:
		throttle = Input.get_axis("back", "forward")
		steer = Input.get_axis("right", "left")
		running = Input.is_action_pressed("sprint") and throttle > 0.0 and not exhausted and not no_run and not no_sprint
		jump_pressed = Input.is_action_just_pressed("jump") and pose == ""
		if CamCtl.steering():
			# FPS-tyyli: hiiri kääntää hahmoa, A/D sivuttain.
			rotation.y += CamCtl.yaw
			CamCtl.yaw = 0.0
			strafe = steer
			steer = 0.0
	tire(running, absf(speed) < 0.2, delta, RUN_DRAIN)
	var ground: float = world.speed_factor(global_position, "runner") if world != null else 1.0
	var want := throttle * (RUN * run_mult if running else WALK) * ground * speed_mult
	if throttle < 0.0:
		want *= 0.6  # peruutuskävely
	if hurt:
		want *= HURT_SPEED  # ontuu
	speed = move_toward(speed, want, 12.0 * delta)
	if controls_enabled:
		steer += _drunk_wobble.steer(drunk, clampf(absf(speed) / WALK, 0.0, 1.0), delta) * 0.6
	rotation.y += steer * TURN * delta
	_strafe = move_toward(_strafe, strafe * WALK * 0.8 * ground * speed_mult, 12.0 * delta)

	var fwd := -global_transform.basis.z
	var side := global_transform.basis.x
	velocity.x = fwd.x * speed + side.x * _strafe
	velocity.z = fwd.z * speed + side.z * _strafe
	if is_on_floor():
		velocity.y = JUMP_SPEED * jump_mult if jump_pressed else 0.0
		if jump_pressed:
			Sfx.play("whoosh", -8.0, 1.4)
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	speed = Vector2(velocity.x, velocity.z).dot(Vector2(fwd.x, fwd.z))

	var s := maxf(absf(speed), absf(_strafe))
	if not is_on_floor():
		_body.play("Jump", 0.1)
	elif s < 0.2:
		_body.play(pose if pose != "" else "Idle", 0.12 if pose != "" else 0.25)
	elif s < 2.8:
		_body.play("Walk", 0.2, signf(speed) * s / 1.6)
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
