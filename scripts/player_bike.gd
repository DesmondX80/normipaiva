extends CharacterBody3D
## Pelaajan pyörä: arcade-ohjaus, kallistus kaarteissa ja takaa seuraava kamera.

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")
const DrunkWobble := preload("res://scripts/drunk_wobble.gd")

const MAX_SPEED := 14.0
const REVERSE_SPEED := 3.0
const ACCEL := 7.0
const BRAKE := 22.0
const DRAG := 2.5
const STEER_SPEED := 2.2
const SLOPE_GRAVITY := 6.0  # mäen vaikutus vauhtiin (m/s² per 100 % nousu), pehmennetty
const GRAVITY := 20.0
const SPRINT := 1.4  # spurtin kerroin kiihtyvyyteen ja huippunopeuteen
const FART_CHANCE := 0.18  # miehekäs pieru spurtin alussa
const SPRINT_FOV := 7.0

var speed := 0.0
var controls_enabled := true
var world: Node3D  # alustatiedot (world.gd); ilman tätä kaikki on asfalttia
var surface := "asphalt"
## Jalan kulkeva pelaaja (on_foot.gd): spurtti kuluttaa samaa kuntomittaria kuin juoksu.
var legs: Node
var sprinting := false
## Autopilotti (pyörävaras, main.gd): ohjaa kohti auto_target-pistettä omalla fysiikalla, auto_speed = osuus huippunopeudesta.
var autopilot := false
var auto_target := Vector3.ZERO
var auto_speed := 0.6
## Humala (main.gd asettaa aina, tilasta riippumatta): yli DrunkWobble.LIMIT ohjaus heittelee.
var drunk := 0.0
var _drunk_wobble := DrunkWobble.new()
## Stamina-tilan palkinto (main.gd _stat_effects): spurtin kerroin SPRINT -> sprint_mult.
var sprint_mult := SPRINT
var _thief: Node3D  # varkaan hahmo satulassa (pelaajan kuski piilossa)

## Hiukkasten värit alustan mukaan (sora pöllyää, vesi roiskuu, vilja lentelee).
const DEBRIS := {
	"gravel": Color(0.62, 0.56, 0.45), "lawn": Color(0.35, 0.55, 0.22), "meadow": Color(0.38, 0.52, 0.2),
	"forest": Color(0.3, 0.24, 0.14), "field": Color(0.82, 0.72, 0.4), "bog": Color(0.28, 0.24, 0.14),
	"water": Color(0.75, 0.85, 0.95),
}
## Rahinan sävelkorkeus ja voimakkuus (dB) alustan mukaan.
const ROLL := {
	"asphalt": [1.0, 0.0], "gravel": [1.35, 4.0], "lawn": [0.75, -2.0], "meadow": [0.7, 0.0],
	"forest": [0.8, 2.0], "field": [0.6, 3.0], "bog": [0.45, 2.0], "water": [0.4, 5.0],
}

var _visual: Node3D
var _cam: Camera3D
var _cam_ready := false
var _lean := 0.0
var _wobble := 0.0
var _wheels: Array[Node3D] = []
var _bag: MeshInstance3D
var _crank: Node3D
var _rider: Node3D
var _stun := 0.0
var _push := Vector3.ZERO
var _roll: AudioStreamPlayer
var _chain: AudioStreamPlayer
var _squeal: AudioStreamPlayer
var _squeak_phase := 0.0  # kammen kulma viimeisimmästä vinkaisusta
var _squeak_alt := false
var _terrain := {}
var _bump_t := 0.0
var _shake := 0.0
var _debris: CPUParticles3D
var _debris_mat: StandardMaterial3D
var _fov_kick := 0.0


func _ready() -> void:
	collision_mask |= 16  # maasto (Terrain.COLLISION_LAYER)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	_visual = Node3D.new()
	add_child(_visual)
	_build_bike()

	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 900.0
	_cam.top_level = true
	add_child(_cam)
	_cam.current = true

	_build_debris()

	_roll = AudioStreamPlayer.new()
	_roll.stream = Sfx.stream("bike_roll")
	_roll.volume_db = -80.0
	add_child(_roll)
	_roll.play()
	_chain = AudioStreamPlayer.new()
	_chain.stream = Sfx.stream("spokes_loop")  # vapaarattaan naksutus rullatessa polkematta
	_chain.volume_db = -80.0
	add_child(_chain)
	_chain.play()
	_squeal = AudioStreamPlayer.new()
	_squeal.stream = Sfx.stream("bike_roll")  # jarrutus: rullausääni hidastuu (ei synteettistä kirskuntaa)
	_squeal.volume_db = -80.0
	add_child(_squeal)
	_squeal.play()


func set_carrying(carrying: bool) -> void:
	_bag.visible = carrying


## Kuski näkyviin/piiloon (jalan liikuttaessa pyörä jää parkkiin ilman kuskia).
func set_rider_visible(v: bool) -> void:
	_rider.visible = v
	_bag.visible = _bag.visible and v


## Varas satulaan (look) tai pois (tyhjä): pelaajan kuski piiloon, varkaalle samat polkimet ja ote tangosta.
func set_thief(look: Dictionary) -> void:
	if _thief != null:
		_thief.queue_free()
		_thief = null
	if look.is_empty():
		return
	_rider.visible = false
	_bag.visible = false
	_thief = Looks.make(_visual, look)
	_thief.play("Driving", 0.0)
	_thief.anim.advance(0.01)
	var pelvis: Vector3 = _thief.bone_position("pelvis")
	_thief.position = Vector3(0, 0.9, 0.28) + Vector3(0, 0.12, 0.02) - pelvis
	_thief.set_override("spine_01", Vector3.RIGHT, -0.4)


func activate_camera() -> void:
	_cam.current = true
	_cam_ready = false


func is_stunned() -> bool:
	return _stun > 0.0


## Karatepotku: pyörä kaatuu ja lentää hetken potkun suuntaan.
func stun(direction: Vector3) -> void:
	_stun = 1.6
	speed = 0.0
	Sfx.play("bike_fall", -2.0)
	Sfx.play("body_fall", -4.0)
	_push = direction * 8.0


## Kevyt osuma (kettukarkki): pyörä heilahtaa ja vauhti hidastuu, mutta ei kaadu.
func stagger(_direction: Vector3) -> void:
	_wobble = 0.6
	speed *= 0.5


func _physics_process_stunned(delta: float) -> void:
	_stun -= delta
	sprinting = false
	_push = _push.move_toward(Vector3.ZERO, 12.0 * delta)
	velocity = Vector3(_push.x, velocity.y - GRAVITY * delta if not is_on_floor() else 0.0, _push.z)
	move_and_slide()
	speed = 0.0
	_lean = lerpf(_lean, 1.3, 1.0 - exp(-10.0 * delta))
	_visual.rotation.z = _lean
	_update_camera(delta)
	_update_roll_sound()


func _physics_process(delta: float) -> void:
	if _stun > 0.0:
		_physics_process_stunned(delta)
		return
	var throttle := 0.0
	var steer := 0.0
	var braking := false
	if autopilot:
		var fwd0 := -global_transform.basis.z
		var to := auto_target - global_position
		to.y = 0.0
		var ang := Vector3(fwd0.x, 0, fwd0.z).signed_angle_to(to, Vector3.UP)
		steer = clampf(ang * 1.6, -1.0, 1.0)
		# Mutkassa hiljennetään (jyrkässä jarrutetaan), suoralla poljetaan auto_speed-osuudella huippunopeudesta.
		var want := MAX_SPEED * auto_speed * clampf(1.2 - absf(ang), 0.25, 1.0)
		throttle = 1.0 if speed < want else 0.0
		braking = speed > want + 2.0
	elif controls_enabled:
		throttle = Input.get_axis("back", "forward")
		steer = clampf(Input.get_axis("right", "left") + CamCtl.vehicle_steer(speed), -1.0, 1.0)
		braking = Input.is_action_pressed("brake")
		if Input.is_action_just_pressed("bell"):
			Sfx.play("bell", -4.0)
	# Shift: spurtti, kun poljetaan eteenpäin ja kuntoa on jäljellä.
	var want_sprint: bool = controls_enabled and Input.is_key_pressed(KEY_SHIFT) and throttle > 0.0 \
		and legs != null and not legs.exhausted and not legs.no_sprint
	if want_sprint and not sprinting:
		_sprint_start()
	sprinting = want_sprint
	if legs != null and controls_enabled:  # vain ajettaessa: parkissa jalat hoitavat kunnon itse
		legs.tire(sprinting, absf(speed) < 0.2, delta)

	_update_surface()
	var t := _terrain
	# Mäet: ylämäessä vauhti hyytyy ja huippunopeus laskee, alamäessä rullaa ja kulkee lujempaa.
	var hfwd := -global_transform.basis.z
	var tn := Terrain.normal(global_position.x, global_position.z)
	var grade := -(tn.x * hfwd.x + tn.z * hfwd.z) / maxf(tn.y, 0.3)  # nousu eteenpäin (0.1 = 10 %)
	var max_s: float = MAX_SPEED * t.speed * clampf(1.0 - grade * 3.0, 0.55, 1.35) * (legs.speed_mult if legs != null else 1.0)
	var accel: float = ACCEL * t.accel
	if legs != null and legs.hurt:
		max_s *= 0.75  # purtu jalka: raskas polkea
		accel *= 0.75
	if sprinting:
		max_s *= sprint_mult
		accel *= sprint_mult
	if throttle > 0.0:
		speed = move_toward(speed, max_s, accel * throttle * delta)
	elif throttle < 0.0:
		if speed > 0.1:
			speed = move_toward(speed, 0.0, BRAKE * delta)
		else:
			speed = move_toward(speed, -REVERSE_SPEED * t.speed, accel * delta)
	else:
		speed = move_toward(speed, 0.0, (DRAG + t.drag) * delta)
	if braking:
		speed = move_toward(speed, 0.0, BRAKE * delta)
	elif absf(grade) > 0.01 and (absf(speed) > 0.3 or throttle != 0.0):
		speed -= SLOPE_GRAVITY * grade * delta
	# Pehmeälle alustalle ajettaessa vauhti hyytyy kohti alustan nopeuskattoa.
	if absf(speed) > max_s:
		speed = move_toward(speed, signf(speed) * max_s, (t.drag + 4.0) * delta)

	# Ohjaus toimii vain liikkeessä, peruuttaessa käänteisesti. Pehmeä maa ja vesi heiluttavat.
	var steer_factor := clampf(absf(speed) / 4.0, 0.0, 1.0)
	if controls_enabled and not autopilot:
		steer += _drunk_wobble.steer(drunk, steer_factor, delta)
	var heading0 := rotation.y
	rotation.y += steer * STEER_SPEED * steer_factor * signf(speed) * t.steer * delta
	if t.sink > 0.05:
		rotation.y += sin(Time.get_ticks_msec() * 0.004) * t.sink * 0.8 * steer_factor * delta
	if controls_enabled and not autopilot:
		CamCtl.turned(rotation.y - heading0)

	var fwd := -global_transform.basis.z
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# Seinään osuminen syö vauhdin.
	speed = Vector2(velocity.x, velocity.z).dot(Vector2(fwd.x, fwd.z))

	_lean = lerpf(_lean, steer * steer_factor * 0.35, 1.0 - exp(-6.0 * delta))
	_wobble = maxf(0.0, _wobble - delta)
	_visual.rotation.z = _lean + sin(_wobble * 30.0) * _wobble * 0.5  # kettukarkki osui: heilahdus
	_apply_bumps(delta)
	for w in _wheels:
		w.rotation.x -= speed * delta / 0.35
	_animate_pedals(delta)

	_update_camera(delta)
	_update_roll_sound()


func _update_roll_sound() -> void:
	var k := clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
	# Jarrut kirskuvat vauhdissa.
	var braking := controls_enabled and (Input.is_action_pressed("brake") or (Input.is_action_pressed("back") and speed > 1.0))
	var want := -80.0
	_squeal.volume_db = lerpf(_squeal.volume_db, want, 0.3)
	_squeal.pitch_scale = 0.9 + k * 0.25
	var r: Array = ROLL.get(surface, ROLL.asphalt)
	_roll.volume_db = linear_to_db(k * 0.6 + 0.0001) + r[1] - 2.0
	_roll.pitch_scale = (0.75 + k * 0.5) * r[0]
	# Vapaaratas naksuu vain, kun rullataan polkematta.
	var coasting := controls_enabled and absf(speed) > 1.0 and not Input.is_action_pressed("forward")
	_chain.volume_db = lerpf(_chain.volume_db, (linear_to_db(k * 0.7 + 0.0001) - 6.0) if coasting else -80.0, 0.25)
	_chain.pitch_scale = 0.6 + k * 0.8


func _update_surface() -> void:
	var kind: String = world.surface_at(global_position) if world != null else "asphalt"
	if kind != surface:
		if kind == "water":
			Sfx.play("whoosh", 2.0, 0.45)
			Sfx.play("water", -6.0, 1.3)
		surface = kind
	_terrain = world.TERRAIN[kind] if world != null else {"speed": 1.0, "accel": 1.0, "drag": 0.0, "bump": 0.0, "steer": 1.0, "sink": 0.0}


## Töyssyt, kivet ja juuret, uppoaminen rämeeseen/veteen, roiskeet.
func _apply_bumps(delta: float) -> void:
	var t := _terrain
	var k := clampf(absf(speed) / 5.0, 0.0, 1.0)
	_bump_t += delta * absf(speed)
	var bump: float = t.bump * k * (sin(_bump_t * 3.1) * sin(_bump_t * 1.7 + 0.5) + 0.3 * sin(_bump_t * 9.3))
	if t.bump >= 0.08 and randf() < 0.03 * k:
		# Juurakko metsässä: tärähdys ja vauhti hidastuu.
		bump += 0.12
		Sfx.play("rattle_hard", -2.0, randf_range(0.9, 1.1))
		speed *= 0.85
		_shake = 0.25
	_visual.position.y = lerpf(_visual.position.y, -t.sink + bump, 1.0 - exp(-14.0 * delta))
	_visual.rotation.x = lerpf(_visual.rotation.x, bump * 1.5, 1.0 - exp(-14.0 * delta))
	_shake = maxf(_shake - delta, t.bump * k * 0.6)
	if t.bump > 0.0 and randf() < t.bump * k * 0.25:
		Sfx.play("rattle", -14.0 + t.bump * 60.0, randf_range(0.85, 1.15))  # lokasuoja kolisee
	_debris.emitting = DEBRIS.has(surface) and absf(speed) > 2.0
	if _debris.emitting:
		_debris_mat.albedo_color = DEBRIS[surface]
		var up := 4.5 if surface == "water" else 3.0
		_debris.initial_velocity_max = up * clampf(absf(speed) / 6.0, 0.5, 1.3)


func _build_debris() -> void:
	_debris = CPUParticles3D.new()
	_debris.amount = 40
	_debris.lifetime = 0.6
	_debris.emitting = false
	_debris.position = Vector3(0, 0.1, 0.6)
	_debris.direction = Vector3(0, 1, 0.7)
	_debris.spread = 35.0
	_debris.initial_velocity_min = 1.5
	_debris.initial_velocity_max = 3.5
	_debris.gravity = Vector3(0, -9.8, 0)
	_debris.scale_amount_min = 0.5
	_debris.scale_amount_max = 1.2
	var m := BoxMesh.new()
	m.size = Vector3(0.05, 0.05, 0.05)
	_debris_mat = StandardMaterial3D.new()
	_debris_mat.roughness = 1.0
	m.material = _debris_mat
	_debris.mesh = m
	add_child(_debris)


func _update_camera(delta: float) -> void:
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.15
	var eye: Vector3 = _rider.to_global(_rider.bone_position("Head")) + Vector3.UP * 0.08
	CamCtl.update_camera(_cam, self, eye, 5.5, 2.6, absf(speed) > 1.0, delta, not _cam_ready, shake)
	_cam_ready = true
	# Spurtissa näkökenttä levenee hieman (vauhdin tunne).
	_fov_kick = lerpf(_fov_kick, SPRINT_FOV if sprinting and speed > 2.0 else 0.0, 1.0 - exp(-4.0 * delta))
	_cam.fov += _fov_kick


func _sprint_start() -> void:
	_shake = maxf(_shake, 0.2)
	if randf() < FART_CHANCE:
		Sfx.play("fart", -3.0, randf_range(0.9, 1.1))


func _build_bike() -> void:
	var frame_col := Color(0.78, 0.08, 0.08)
	var black := Color(0.06, 0.06, 0.06)
	var steel := Color(0.72, 0.72, 0.75)

	for z in [-0.55, 0.55]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.35, z)
		_visual.add_child(pivot)
		var tire := TorusMesh.new()
		tire.inner_radius = 0.3
		tire.outer_radius = 0.36
		tire.rings = 20
		tire.ring_segments = 6
		B.mesh(pivot, tire, Vector3.ZERO, black, Vector3(0, 0, 90))
		B.mesh(pivot, B.cyl(0.04, 0.04, 0.1, 8), Vector3.ZERO, steel, Vector3(0, 0, 90))
		for k in 8:
			var spoke := B.mesh(pivot, B.boxm(Vector3(0.01, 0.6, 0.01)), Vector3.ZERO, steel)
			spoke.rotation.x = PI * k / 8.0
		_wheels.append(pivot)

	var seat := Vector3(0, 0.9, 0.28)
	var crank := Vector3(0, 0.36, 0.05)
	var head := Vector3(0, 0.88, -0.42)
	B.tube(_visual, seat, head, 0.025, frame_col)
	B.tube(_visual, head + Vector3(0, -0.1, 0), crank, 0.028, frame_col)
	B.tube(_visual, seat + Vector3(0, 0.05, 0), crank, 0.025, frame_col)
	B.tube(_visual, crank, Vector3(0, 0.35, 0.55), 0.018, frame_col)
	B.tube(_visual, seat, Vector3(0, 0.35, 0.55), 0.018, frame_col)
	B.tube(_visual, head + Vector3(0, 0.12, 0), Vector3(0, 0.35, -0.55), 0.02, steel)
	B.tube(_visual, Vector3(-0.3, 1.22, -0.36), Vector3(0.3, 1.22, -0.36), 0.018, black)
	for gx in [-0.27, 0.27]:
		B.tube(_visual, Vector3(gx - 0.04, 1.22, -0.36), Vector3(gx + 0.04, 1.22, -0.36), 0.03, Color(0.15, 0.1, 0.08))
	B.tube(_visual, head, Vector3(0, 1.22, -0.36), 0.02, steel)
	B.mesh(_visual, B.boxm(Vector3(0.16, 0.06, 0.28)), seat + Vector3(0, 0.05, 0.02), black)
	B.mesh(_visual, B.cyl(0.1, 0.1, 0.02, 16), crank + Vector3(0.05, 0, 0), steel, Vector3(0, 0, 90))
	# Lokasuoja ja tavarateline.
	B.mesh(_visual, B.boxm(Vector3(0.1, 0.02, 0.5)), Vector3(0, 0.74, 0.6), frame_col)
	B.tube(_visual, Vector3(0, 0.74, 0.4), Vector3(0, 0.55, 0.62), 0.012, steel)

	_crank = Node3D.new()
	_crank.position = crank
	_visual.add_child(_crank)
	for side in [-1.0, 1.0]:
		var arm := B.mesh(_crank, B.boxm(Vector3(0.02, 0.17, 0.03)), Vector3(0.08 * side, -0.085 * side, 0), steel)
		arm.name = "Arm%d" % int(side)
		B.mesh(_crank, B.boxm(Vector3(0.1, 0.02, 0.06)), Vector3(0.12 * side, -0.17 * side, 0), black)

	# Kuski tuulipuvussa: istuva ajoasento, jalat polkevat luiden ohituksilla.
	_rider = Looks.make(_visual, Looks.PLAYER)
	Looks.add_cap(_rider)
	CamCtl.mark_own_body(_rider)
	_rider.play("Driving", 0.0)
	_rider.anim.advance(0.01)
	var pelvis: Vector3 = _rider.bone_position("pelvis")
	_rider.position = seat + Vector3(0, 0.12, 0.02) - pelvis
	_rider.set_override("spine_01", Vector3.RIGHT, -0.4)  # kumarassa tankoa kohti

	# K-Marketin muovikassi tangossa, näkyy kun kaljat on ostettu.
	_bag = B.mesh(_visual, B.boxm(Vector3(0.28, 0.34, 0.2)), Vector3(0.3, 0.8, -0.45), Color(1.0, 0.45, 0.0))
	B.label(_bag, "K", Vector3(0, 0, 0.11), 24, Color.WHITE)
	_bag.visible = false


## Polkimet pyörivät vauhdin mukaan; IK vie jalkaterät polkimille ja kädet tankoon.
func _animate_pedals(delta: float) -> void:
	_crank.rotation.x -= speed * delta / 0.9
	# Ruosteiset polkimet: vinkaisu ja narahdus vuorotellen puolen kierroksen välein.
	_squeak_phase += absf(speed * delta / 0.9)
	if _squeak_phase >= PI:
		_squeak_phase -= PI
		var loud := clampf(absf(speed) / 6.0, 0.25, 1.0)
		# Ruosteiset polkimet: vinkaisu ja narahdus vuorotellen, välillä väliin jääden.
		if randf() < 0.7:
			Sfx.play("pedal_creak" if _squeak_alt else "pedal_squeak", linear_to_db(loud) - 10.0,
				randf_range(0.9, 1.1) * (1.0 + clampf(absf(speed) / 14.0, 0.0, 1.0) * 0.15))
		_squeak_alt = not _squeak_alt
	var who: Node3D = _thief if _thief != null else _rider
	var inv := who.transform.affine_inverse()
	var crank_basis := Basis(Vector3.RIGHT, _crank.rotation.x)
	for side in [["_l", -1.0], ["_r", 1.0]]:
		var s: float = side[1]
		var pedal: Vector3 = _crank.position + crank_basis * Vector3(0.12 * s, -0.17 * s, 0)
		var hip := Vector3(0.1 * s, 1.0, 0.25)
		who.set_ik("leg" + side[0], "thigh" + side[0], "calf" + side[0], "foot" + side[0],
			inv * (pedal + Vector3(0, 0.08, 0.04)), inv * (hip + Vector3(0.05 * s, 0.1, -0.7)))
		var grip := Vector3(0.27 * s, 1.24, -0.34)
		var shoulder := Vector3(0.2 * s, 1.5, 0.05)
		who.set_ik("arm" + side[0], "upperarm" + side[0], "lowerarm" + side[0], "hand" + side[0],
			inv * grip, inv * (shoulder + Vector3(0.35 * s, -0.35, 0.1)))
