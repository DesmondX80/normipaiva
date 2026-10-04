extends CharacterBody3D
## Metsän peto: karhu tai susi ilmestyy, kun pelaaja kulkee jalan metsässä (main.gd _beast_tick).
## Karhu: juokseminen tai liian lähelle meneminen laukaisee rynnäkön; paikallaan seisominen tai hidas
## perääntyminen saa sen luopumaan. Susi: hiipii lähemmäs ja hyökkää, jos sille juoksee karkuun tai sen antaa
## tulla liian lähelle; huuto (shout) kasvot sutta kohti säikäyttää sen pois. Hyökkäys (attacked) ja
## selviäminen (gave_up) käsitellään main.gd:ssä.

const B := preload("res://scripts/build.gd")
const DOG := preload("res://assets/animals/ShibaInu.glb")

signal warned
signal attacked(direction: Vector3)
signal gave_up(scared: bool)

const STANDOFF_D := {"karhu": 14.0, "susi": 11.0}
const CHARGE_SPEED := {"karhu": 9.5, "susi": 8.5}
const RUNNING := 3.2  # pelaajan vauhti, jota peto pitää pakenemisena
const CALM_NEEDED := 6.0  # karhu: näin kauan rauhallisena, niin se luopuu

var kind := "karhu"
var target: Node3D
var phase := "approach"  # approach, standoff, charge, leave
var _t := 0.0
var _speed := 0.0
var _calm := 0.0
var _d0 := 0.0
var _roar_t := 0.0
var _scared := false
var _anim: AnimationPlayer
var _legs: Array[Node3D] = []
var _walk := 0.0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 0
	if kind == "karhu":
		_build_bear()
	else:
		_build_wolf()


## Asettaa pedon maahan pisteeseen p (korkeus säteellä).
func place(p: Vector3) -> void:
	global_position = p
	global_position.y = _ground(p, 150.0)


## Huuto: susi säikähtää, jos pelaaja katsoo sitä kohti. Palauttaa true, jos susi pakeni.
func shout() -> bool:
	if kind != "susi" or phase != "standoff":
		return false
	var to_w := global_position - target.global_position
	to_w.y = 0.0
	var fwd := -target.global_transform.basis.z
	if Vector2(fwd.x, fwd.z).normalized().dot(Vector2(to_w.x, to_w.z).normalized()) < 0.5:
		return false
	_scared = true
	_leave(true)
	return true


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_t += delta
	var to_p := target.global_position - global_position
	to_p.y = 0.0
	var d := to_p.length()
	var ps: float = absf(target.get("speed")) if target.get("speed") != null else 0.0
	var want := 0.0
	var face := to_p
	match phase:
		"approach":
			want = 2.2 if kind == "karhu" else 2.8
			if d < STANDOFF_D[kind]:
				phase = "standoff"
				_t = 0.0
				_d0 = d
				_roar()
				warned.emit()
			elif _t > 45.0:
				_leave(false)
		"standoff":
			_roar_t -= delta
			if _roar_t <= 0.0:
				_roar()
			if kind == "karhu":
				if ps > RUNNING or d < 6.0:
					_charge()
				else:
					_calm += delta * (1.6 if d > _d0 + 2.0 else 1.0)  # perääntyminen rauhoittaa nopeammin
					if _calm > CALM_NEEDED or d > 32.0:
						_leave(false)
			else:
				want = 0.8  # hiipii lähemmäs
				if ps > RUNNING or d < 2.8:
					_charge()
				elif _t > 25.0 or d > 30.0:
					_leave(false)
		"charge":
			want = CHARGE_SPEED[kind]
			if d < 1.7:
				attacked.emit(to_p.normalized())
				_leave(false, true)
			elif d > 45.0 or _t > 12.0:
				_leave(false)
		"leave":
			face = -to_p
			want = 7.0 if _scared else 3.5
			if d > 50.0 or _t > 20.0:
				queue_free()
	_speed = move_toward(_speed, want, (14.0 if phase == "charge" else 5.0) * delta)
	if face.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, B.yaw_to(face), 1.0 - exp(-6.0 * delta))
	velocity = -global_transform.basis.z * _speed
	move_and_slide()
	global_position.y = _ground(global_position, 3.0)
	_animate(delta)


func _charge() -> void:
	phase = "charge"
	_t = 0.0
	Sfx.play_on(self, "dog", 6.0, 0.35 if kind == "karhu" else 0.6)


func _leave(scared: bool, after_attack := false) -> void:
	phase = "leave"
	_t = 0.0
	if not after_attack:
		gave_up.emit(scared)


func _roar() -> void:
	_roar_t = randf_range(1.6, 2.6)
	if kind == "karhu":
		Sfx.play_on(self, "dog", 2.0, randf_range(0.28, 0.34))  # matala murina
	else:
		Sfx.play_on(self, "dog", 0.0, randf_range(0.55, 0.62))


func _ground(p: Vector3, up: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * up, p + Vector3.DOWN * 8.0)
	q.collision_mask = 1
	if target is CollisionObject3D:
		q.exclude = [(target as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else p.y


func _animate(delta: float) -> void:
	if _anim != null:
		var a := "Idle"
		if _speed > 5.0:
			a = "Gallop"
		elif _speed > 0.3:
			a = "Walk"
		elif phase == "standoff":
			a = "Idle_2_HeadLow"
		if _anim.current_animation != a:
			_anim.play(a, 0.2)
		return
	# Karhu: jalat keinuvat askeleen tahtiin, seisoessa paikallaan.
	_walk += delta * _speed * 2.2
	var amp := clampf(_speed / 3.0, 0.0, 1.0) * 0.6
	for i in _legs.size():
		var ph := _walk + (PI if i in [1, 2] else 0.0)
		_legs[i].rotation.x = sin(ph) * amp


## Karhu palikoista: pyöreä ruho, kyttyrä, iso pää kuonoineen, pyöreät korvat ja neljä paksua jalkaa.
func _build_bear() -> void:
	var fur := Color(0.26, 0.17, 0.1)
	var dark := fur.darkened(0.35)
	var body := B.mesh(self, B.sphere(0.6), Vector3(0, 0.95, 0.1), fur)
	body.scale = Vector3(1.0, 0.9, 1.6)
	B.mesh(self, B.sphere(0.4), Vector3(0, 1.3, -0.35), fur).scale = Vector3(1.1, 0.8, 1.0)  # kyttyrä
	var head := B.mesh(self, B.sphere(0.34), Vector3(0, 1.15, -0.95), fur)
	head.scale = Vector3(1.0, 0.9, 1.05)
	B.mesh(self, B.sphere(0.17), Vector3(0, 1.05, -1.25), fur.lightened(0.15)).scale = Vector3(1.0, 0.85, 1.3)  # kuono
	B.mesh(self, B.sphere(0.06), Vector3(0, 1.1, -1.45), Color(0.05, 0.04, 0.04))  # nenä
	for sx in [-1.0, 1.0]:
		B.mesh(self, B.sphere(0.1), Vector3(0.22 * sx, 1.43, -0.9), fur)  # korvat
		B.mesh(self, B.sphere(0.04), Vector3(0.14 * sx, 1.22, -1.24), Color(0.03, 0.03, 0.03))  # silmät
	for p in [Vector3(-0.32, 0.75, -0.5), Vector3(0.32, 0.75, -0.5), Vector3(-0.32, 0.75, 0.7), Vector3(0.32, 0.75, 0.7)]:
		var leg := Node3D.new()
		leg.position = p
		add_child(leg)
		B.mesh(leg, B.cyl(0.17, 0.15, 0.75, 10), Vector3(0, -0.38, 0), fur)
		B.mesh(leg, B.boxm(Vector3(0.3, 0.12, 0.38)), Vector3(0, -0.72, -0.06), dark)  # tassu
		_legs.append(leg)


## Susi koiramallista: isompi, harmaa turkki.
func _build_wolf() -> void:
	var m: Node3D = DOG.instantiate()
	m.scale = Vector3.ONE * 0.4
	m.rotation.y = PI
	add_child(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(i) as StandardMaterial3D
			if mat == null:
				continue
			var grey := mat.duplicate() as StandardMaterial3D
			grey.albedo_color = {"Main": Color(0.36, 0.35, 0.33), "Main_Light": Color(0.62, 0.6, 0.56)}.get(
				mat.resource_name, mat.albedo_color)
			mesh.set_surface_override_material(i, grey)
	_anim = m.find_child("AnimationPlayer", true, false)
	for n in ["Idle", "Walk", "Gallop", "Idle_2_HeadLow"]:
		_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")
