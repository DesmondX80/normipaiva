extends CharacterBody3D
## Kaisuan tilan ajettava kone (kaisua.gd): vanha traktori tai leikkuupuimuri. Ohjaus kuten mopolla (eteen/taakse,
## ohjaus, jarru), pyöräpohjainen kääntyminen akselivälin mukaan (puimuri kääntää takapyörillä), kamera takaa ja
## runko maaston kallistuksen mukaan. Samat kutsut kuin mopolla (main.gd:n player-rajapinta: speed, controls_enabled,
## is_stunned, set_carrying, activate_camera).
##
## Traktori: kolmipistenostimen työkone kulkee rungon mukana (nostettuna kuljetukseen, laskettuna töissä) ja
## vetoaisan kone perävaununa (akseli seuraa vetokoukkua). Työn aikana kone tekee työtään pellolle (work_fn) joka
## fysiikkaruudulla. Etukuormaimen paalipiikki kantaa yhtä paalia. Puimuri: leikkuupöytä puimaa edessä, säiliö
## täyttyy ja purkuputki kääntyy ulos purettaessa.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Koneet := preload("res://scripts/kaisua_koneet.gd")
const Mokki := preload("res://scripts/mokki.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Contact := preload("res://scripts/contact.gd")

const GRAVITY := 20.0
const TANK_MAX := 2200.0  # kg, puimurin viljasäiliö

var kind := "traktori"  # "traktori" tai "puimuri"
var speed := 0.0
var controls_enabled := false
var surface := "field"
var driven := false  # pelaaja ratissa
## Testien autopilotti: x = kaasu (-1…1), y = ohjaus (+ = vasen) näppäinten sijaan.
var autopilot := Vector2.INF
var working := false  # työkone laskettu / leikkuupöytä alhaalla
## Työn kohdistus pellolle: work_fn(op, keskipiste (Vector2, paikallinen), suunta (Vector2), puolileveys,
## puolipituus) -> Dictionary (kaisua.gd _apply_work).
var work_fn: Callable
var to_local_fn: Callable  # maailma -> mökin paikallinen (Vector3)

var implement: Node3D = null  # kytketty työkone (traktori)
var implement_id := ""
var implement_parts := {}
var bale: Node3D = null  # piikissä oleva paali
var unloading := false  # puimuri: purkuputki ulkona ja vilja valuu
var tank := 0.0  # puimuri: kg
## Diesel (0–1): kuluu moottorin käydessä, työssä enemmän (täysi tankki noin 20 min töitä). Tyhjänä moottori sammuu.
var fuel := 1.0
const FUEL_IDLE := 0.00025
const FUEL_LOAD := 0.0006

var _visual: Node3D
var _model := {}
var _driver: Node3D
var _cam: Camera3D
var _cam_ready := false
var _steer := 0.0
var _engine: AudioStreamPlayer3D
var _smoke: CPUParticles3D
var _dust: CPUParticles3D
var _chaff: CPUParticles3D
var _stream: CPUParticles3D
var _lift := 1.0  # 1 = työkone ylhäällä
var _loader := 0.0  # kuormaimen nosto 0…1
var _spin := 0.0
var _load := 0.0  # moottorin kuorma 0…1 (ääni ja savu)
## Työkoneen ääni (moottorin päälle): kone -> silmukka. Voimanoton koneet soivat seisoessakin, maata muokkaavat vain
## liikkeessä (sävel nousee vauhdin mukana).
const WORK_SOUND := {"niittokone": "kone_niitto", "karhotin": "kone_karho", "paalain": "kone_paalain", "aura": "kone_maa",
	"aes": "kone_maa", "kylvokone": "kone_kylvo"}
const WORK_PTO := ["niittokone", "karhotin", "paalain"]
var _work_snd: AudioStreamPlayer3D
## Apumies (Santtu, kaisua.gd _start_helper) ajaa valmiin reitin: [[Vector2 paikka (Kaisuan kehys), bool työssä], ...]
## 0,4 m välein. Kone liikkuu reittiä pitkin ilman törmäyksiä (pellon päiden käännökset voivat mennä pientareelle).
var helper_path: Array = []
## Maaston pinta tilan kehyksessä (maatila_paikka.gd height; kaisua.gd asettaa).
var height_fn: Callable = Callable(Mokki, "mesh_h")
var helper_s := 0.0  # matka reitillä (m)
var helper_rate := 1.0  # aikakerroin (kaisua.gd kiirehtii, kun pelaaja on kaukana; testit kiirehtivät)
var helper_done := false
var _helper: Node3D  # apumiehen hahmo ratissa
var _work_key := ""
var _work_amt := 0.0
var _pitch := 0.0
var _roll := 0.0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(40.0)
	floor_snap_length = 0.6
	collision_mask = 1 | Terrain.COLLISION_LAYER
	_visual = Node3D.new()
	add_child(_visual)
	# Törmäys pitkittäisellä kapselilla: laatikon reuna takertui maaston korkeuskartan kolmioiden reunoihin.
	var cap := CapsuleShape3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = cap
	cs.rotation.x = PI / 2.0
	if kind == "puimuri":
		cap.radius = 1.1
		cap.height = 6.2
		cs.position = Vector3(0, 1.25, 1.4)
		_model = Koneet.puimuri(_visual)
	else:
		cap.radius = 0.62
		cap.height = 3.4
		cs.position = Vector3(0, 0.8, -0.8)
		_model = Koneet.traktori(_visual)
	add_child(cs)
	_driver = _make_driver(Looks.player())
	_driver.visible = false
	_cam = Camera3D.new()
	_cam.fov = 72.0
	_cam.far = 1600.0
	_cam.top_level = true
	add_child(_cam)
	_engine = Sfx.loop_on(self, "tractor_engine", -6.0)
	_engine.pitch_scale = 0.7 if kind == "puimuri" else 0.85
	_engine.stream_paused = true
	_smoke = _particles(Vector3(0.6, 3.8, 2.9) if kind == "puimuri" else Vector3(0.17, 2.32, -1.5), Color(0.2, 0.2, 0.2, 0.5), 0.35, Vector3.UP, 1.2)
	# Pakokaasu laajenee ja vaalenee noustessaan (pöllähdys), tuuli vie sitä hieman taakse.
	var grow := Curve.new()
	grow.max_value = 3.0  # ennen pisteitä: pisteet rajataan arvoalueeseen
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 3.0))
	_smoke.scale_amount_curve = grow
	# Hiukkasbillboard: tavallinen billboard ohittaa hiukkasen koon (kasvukäyrä ei näkyisi).
	(_smoke.mesh.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Väri ja peittävyys tulevat liukumasta; materiaalin oma väri (0,2 harmaa, alfa 0,5) kertoisi ne melkein näkymättömiksi.
	(_smoke.mesh.material as StandardMaterial3D).albedo_color = Color.WHITE
	_smoke.scale_amount_min = 0.9  # 0,4 m:n neliö: pöllähdys alkaa noin 0,2 m:stä ja kasvaa yli metriin
	_smoke.scale_amount_max = 1.5
	_smoke.amount = 32
	_smoke.lifetime = 1.6
	_smoke.damping_min = 0.4
	_smoke.damping_max = 0.8
	var sg := Gradient.new()
	sg.set_color(0, Color(0.14, 0.14, 0.14, 0.85))
	sg.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	sg.add_point(0.35, Color(0.32, 0.32, 0.32, 0.6))
	_smoke.color_ramp = sg
	_dust = _particles(Vector3(0, 0.3, 2.0), Color(0.45, 0.36, 0.25, 0.45), 0.9, Vector3(0, 0.4, 1), 2.2)
	if kind == "puimuri":
		_chaff = _particles(Vector3(0, 1.4, 4.5), Color(0.85, 0.75, 0.45, 0.8), 0.25, Vector3(0, -0.2, 1), 1.6)
		_stream = _particles(Vector3.ZERO, Color(0.86, 0.74, 0.42, 1.0), 0.12, Vector3.DOWN, 0.9, _model.spout_tip)


func _particles(pos: Vector3, col: Color, size: float, dir: Vector3, life: float, parent: Node3D = null) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 24
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.direction = dir
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.3, 0) if dir.y >= 0.0 else Vector3(0, -9.0, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.4
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _soft_dot()
	m.vertex_color_use_as_albedo = true
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	(parent if parent != null else _visual).add_child(p)
	return p


static var _dot: Texture2D


## Pehmeä pyöreä täplä (pöly, savu ja jyvät): reunat läpinäkyviksi, ettei partikkeli näy neliönä.
static func _soft_dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 32
		t.height = 32
		_dot = t
	return _dot


# --- main.gd:n pelaajarajapinta ------------------------------------------------------------------------------------

func is_stunned() -> bool:
	return false


func set_carrying(_on: bool) -> void:
	pass


func stun(_t := 0.0) -> void:
	pass


func stagger(_v := Vector3.ZERO) -> void:
	pass


func activate_camera() -> void:
	_cam.current = true
	_cam_ready = false


## Kuski ratissa (pelaaja tai apumies): Driving-animaatio, lantio istuimelle, jalat ja kädet IK:lla.
func _make_driver(look: Dictionary, cap := true) -> Node3D:
	var drv := Looks.make(_visual, look)
	if cap:
		Looks.add_cap(drv)  # pelaajan lippis; apumiehellä oma ulkonäkö ilman
	drv.play("Driving", 0.0)
	drv.anim.advance(0.01)
	var seat: Vector3 = Koneet.C_SEAT if kind == "puimuri" else Koneet.T_SEAT
	drv.position = seat + Vector3(0, 0.08, 0.04) - drv.bone_position("pelvis")
	# Jalat IK:lla: traktorissa astinlaudoille vaihteistokotelon sivuille (kotelo on istuimen edessä keskellä),
	# puimurissa tasanteelle ohjausakselin molemmin puolin. Polvet eteen ja hieman ulos, jalkapohja Drivingin asennossa.
	var inv := drv.transform.affine_inverse()
	for side in ["_l", "_r"]:
		var sx := signf(drv.bone_position("thigh" + side).x)
		# Jalkapohjat astinlaudan urien päällä (nilkka 14 cm laudan yllä, pohja n. 1 cm urien yllä; traktorissa varpaat kuormaimen tornien
		# sisäpuolella), puimurissa tasanteella.
		var foot := Vector3(sx * 0.36, Koneet.T_PLATE_Y + 0.14, -0.13) if kind == "traktori" else Vector3(sx * 0.2, 2.44, -0.98)
		var knee := foot + Vector3(sx * 0.25, 0.6, -0.5)
		var fb := Contact.foot_basis(drv, side, false)
		drv.set_ik("leg" + side, "thigh" + side, "calf" + side, "foot" + side, inv * foot, inv * knee)
		drv.set_ik_orient("leg" + side, fb, 1.0)
		# Kädet ratille "kymmentä vaille kaksi": otteet kehällä ratin tasossa (traktori ja puimuri eri korkeudella),
		# kyynärpäät alas ja sivulle. Driving-animaation kädet ovat traktorin ratin kohdalla, puimurin ratti on alempana.
		var ax := signf(drv.bone_position("upperarm" + side).x)
		var wc: Vector3 = Koneet.T_WHEEL if kind == "traktori" else Koneet.C_WHEEL
		var tilt: float = Koneet.T_WHEEL_TILT if kind == "traktori" else Koneet.C_WHEEL_TILT
		var grip := wc + Basis(Vector3.RIGHT, tilt) * Vector3(ax * 0.165, 0.0, -0.09)
		var elbow := grip + Vector3(ax * 0.3, -0.35, 0.3)
		drv.set_ik("arm" + side, "upperarm" + side, "lowerarm" + side, "hand" + side, inv * grip, inv * elbow)
	drv.visible = false
	return drv


## Kuski ratissa (pelaaja kyydissä) vai kone parkissa.
func set_driven(on: bool) -> void:
	driven = on
	controls_enabled = on
	_driver.visible = on
	_engine.stream_paused = not on
	_smoke.emitting = on
	if not on:
		speed = 0.0
		set_working(false)
		_dust.emitting = false


func set_working(on: bool) -> void:
	working = on
	if kind == "puimuri":
		_chaff.emitting = false
	_dust.emitting = false
	if on:
		Sfx.play_on(self, "rattle", -6.0, 0.8)


# --- Ajo -----------------------------------------------------------------------------------------------------------

func _max_speed() -> float:
	if kind == "puimuri":
		return 3.4 if working else 5.5
	if working and implement != null:
		return float(Koneet.IMPLEMENTS[implement_id].speed)
	return 7.0  # 25 km/h


func _physics_process(delta: float) -> void:
	if not helper_path.is_empty():
		_helper_drive(delta)
		return
	var throttle := 0.0
	var steer := 0.0
	var braking := false
	if controls_enabled:
		throttle = Input.get_axis("back", "forward")
		steer = clampf(Input.get_axis("right", "left") + CamCtl.vehicle_steer(speed), -1.0, 1.0)
		braking = Input.is_action_pressed("brake")
		if Input.is_action_just_pressed("bell") and implement == null and kind == "puimuri":
			Sfx.play_on(self, "horn", -6.0, 0.6)
	if autopilot != Vector2.INF:
		throttle = autopilot.x
		steer = autopilot.y
		braking = false
	if driven:
		fuel = maxf(0.0, fuel - delta * (FUEL_IDLE + FUEL_LOAD * _load))
		if fuel <= 0.0:
			throttle = 0.0  # moottori sammui: rullaa hiljaa seis
			if working:
				set_working(false)
	_engine.stream_paused = not driven or fuel <= 0.0
	_smoke.emitting = driven and fuel > 0.0
	var max_s := _max_speed()
	if throttle > 0.0:
		speed = move_toward(speed, max_s * throttle, 2.2 * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, 0.0 if speed > 0.2 else -2.5 * -throttle, (6.0 if speed > 0.2 else 2.0) * delta)
	else:
		speed = move_toward(speed, 0.0, 1.6 * delta)
	if braking:
		speed = move_toward(speed, 0.0, 7.0 * delta)
	if speed > max_s:
		speed = move_toward(speed, max_s, 3.0 * delta)
	_steer = move_toward(_steer, steer, 2.4 * delta)
	var wb := Koneet.C_WHEELBASE if kind == "puimuri" else Koneet.T_WHEELBASE
	var max_angle := 0.62 if kind == "puimuri" else 0.6
	var yaw_rate := speed / wb * tan(_steer * max_angle)
	var heading0 := rotation.y
	rotation.y += yaw_rate * delta
	if controls_enabled:
		CamCtl.turned(rotation.y - heading0)
	var fwd := -global_transform.basis.z
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	velocity.y = -1.0 if is_on_floor() else velocity.y - GRAVITY * delta
	var was := speed
	move_and_slide()
	speed = Vector2(velocity.x, velocity.z).dot(Vector2(fwd.x, fwd.z))
	if absf(was) > 2.0 and absf(speed) < absf(was) * 0.4 and is_on_wall():
		Sfx.play_on(self, "punch_heavy", -6.0, 0.6)
	_ground_follow(delta)
	_animate(delta, throttle)
	_work_sound(delta)
	_update_implement(delta)
	if working and speed > 0.25:
		_do_work()
	if driven:
		var eye := global_position + Vector3.UP * (3.6 if kind == "puimuri" else 2.2)
		CamCtl.update_camera(_cam, self, eye, 11.0 if kind == "puimuri" else 7.5, 4.2 if kind == "puimuri" else 3.0,
			absf(speed) > 0.6, delta, not _cam_ready, Vector3.ZERO)
		_cam_ready = true


## Runko maaston mukaan: kallistus neljän pyörän kohdan korkeuksista (mökin paikallinen maasto).
func _ground_follow(delta: float) -> void:
	if not to_local_fn.is_valid():
		return
	var wb := Koneet.C_WHEELBASE if kind == "puimuri" else Koneet.T_WHEELBASE
	var zf := -wb if kind == "traktori" else 0.0
	var zr := 0.0 if kind == "traktori" else wb
	var b := global_transform.basis
	var pts := []
	for q in [Vector3(-0.8, 0, zf), Vector3(0.8, 0, zf), Vector3(-0.8, 0, zr), Vector3(0.8, 0, zr)]:
		var l: Vector3 = to_local_fn.call(global_position + b * q)
		pts.append(float(height_fn.call(l.x, l.z)))
	var front := (float(pts[0]) + float(pts[1])) / 2.0
	var rear := (float(pts[2]) + float(pts[3])) / 2.0
	var left := (float(pts[0]) + float(pts[2])) / 2.0
	var right := (float(pts[1]) + float(pts[3])) / 2.0
	# +X-kierto nostaa keulaa (-Z) ja +Z-kierto oikeaa kylkeä (+X): etuakseli on molemmissa -Z:n puolella.
	var pitch := atan2(front - rear, absf(zf - zr))
	var roll := atan2(right - left, 1.6)
	_pitch = lerpf(_pitch, pitch, 1.0 - exp(-8.0 * delta))
	_roll = lerpf(_roll, roll, 1.0 - exp(-8.0 * delta))
	_visual.rotation = Vector3(_pitch, 0, _roll)
	var lp: Vector3 = to_local_fn.call(global_position)
	var gy := float(height_fn.call(lp.x, lp.z))
	_visual.position.y = lerpf(_visual.position.y, clampf(gy - lp.y, -0.4, 0.4), 1.0 - exp(-10.0 * delta))


func _animate(delta: float, throttle: float) -> void:
	var dist := speed * delta
	if kind == "puimuri":
		for w in _model.front:
			w.rotation.x -= dist / 0.72
		for i in 2:
			_model.rear[i].rotation.y = -_steer * 0.62
			_model.rear_spin[i].rotation.x -= dist / 0.42
		if working:
			_model.reel.rotation.x -= delta * 2.2
			_model.auger.rotation.x -= delta * 7.0
		(_model.grain as MeshInstance3D).scale.y = maxf(0.01, tank / TANK_MAX * 0.75)
		(_model.grain as MeshInstance3D).position.y = 2.96 + (_model.grain as MeshInstance3D).scale.y * 0.5
		var spout_t := -1.45 if unloading else 0.0
		_model.spout.rotation.y = move_toward(_model.spout.rotation.y, spout_t, 1.2 * delta)
		_stream.emitting = unloading and absf(_model.spout.rotation.y - spout_t) < 0.05 and tank > 0.0
		_chaff.emitting = working and speed > 0.3
	else:
		for w in _model.rear:
			w.rotation.x -= dist / Koneet.T_REAR_R
		for i in 2:
			_model.front[i].rotation.y = _steer * 0.6
			_model.front_spin[i].rotation.x -= dist / Koneet.T_FRONT_R
		var lt := 0.5 if bale != null else 0.0
		_loader = move_toward(_loader, lt, 0.6 * delta)
		_model.loader.rotation.x = _loader * 0.75
		_model.spear.rotation.x = -_loader * 0.75
	_load = lerpf(_load, clampf(absf(throttle) * 0.6 + (0.5 if working else 0.0), 0.0, 1.0), 1.0 - exp(-3.0 * delta))
	if driven:
		var base := 0.7 if kind == "puimuri" else 0.85
		_engine.pitch_scale = base + absf(speed) * 0.06 + _load * 0.25
		_engine.volume_db = -9.0 + _load * 5.0
		# Ei amount-asetusta joka ruutu: CPUParticles3D.amount käynnistää hiukkaset alusta (savu jäi paikalleen
		# yhdeksi pisteeksi). Kuorma näkyy nopeutena ja tummuutena.
		_smoke.initial_velocity_max = 1.0 + _load * 2.0
		_smoke.color_ramp.set_color(0, Color(0.14, 0.14, 0.14, 0.7 + _load * 0.25))


## Työkoneen ääni: soitin vaihtuu koneen mukana, voimakkuus häivytetään (laskettu kone hiljenee 0,4 s:ssa).
func _work_sound(delta: float) -> void:
	var key := ""
	var pto := true
	if kind == "puimuri":
		key = "kone_puinti"
	elif implement != null:
		key = WORK_SOUND.get(implement_id, "")
		pto = implement_id in WORK_PTO
	var on := working and key != "" and (pto or absf(speed) > 0.3)
	_work_amt = move_toward(_work_amt, 1.0 if on else 0.0, delta * (1.5 if on else 2.5))
	if key != _work_key:
		if _work_snd != null:
			_work_snd.queue_free()
			_work_snd = null
		_work_key = key
		if key != "":
			_work_snd = Sfx.loop_on(self, key, -60.0)
			_work_snd.stream_paused = true
	if _work_snd == null:
		return
	_work_snd.stream_paused = _work_amt <= 0.001
	_work_snd.volume_db = linear_to_db(maxf(_work_amt, 0.001)) + (-2.0 if kind == "puimuri" else -4.0)
	_work_snd.pitch_scale = 1.0 if pto else 0.85 + clampf(absf(speed) / 3.0, 0.0, 1.0) * 0.3


# --- Apumies -------------------------------------------------------------------------------------------------------

const HELPER_STEP := 0.4  # reitin pisteväli (m)
const HELPER_TURN_SPEED := 2.2


## Apumies rattiin ja reitti ajoon (look = hahmon ulkonäkö).
func start_helper(path: Array, look: Dictionary) -> void:
	if _helper == null:
		_helper = _make_driver(look, false)
	_helper.visible = true
	_driver.visible = false
	helper_path = path
	helper_s = 0.0
	helper_done = false
	velocity = Vector3.ZERO
	speed = 0.0
	_engine.stream_paused = false
	_smoke.emitting = true


func stop_helper() -> void:
	helper_path = []
	speed = 0.0
	set_working(false)
	if _helper != null:
		_helper.visible = false
	if not driven:
		_engine.stream_paused = true
		_smoke.emitting = false


func helper_active() -> bool:
	return not helper_path.is_empty()


## Ajettu osuus reitistä (0…1).
func helper_progress() -> float:
	return 0.0 if helper_path.size() < 2 else clampf(helper_s / ((helper_path.size() - 1) * HELPER_STEP), 0.0, 1.0)


## Koneen keulan suunta reitin pisteessä i: saman suunnan (ajo tai peruutus) naapuripisteistä, ettei suunta hyppää
## peruutuksen ja ajon vaihtokohdassa; peruuttaessa keula osoittaa kulkusuuntaa vastaan.
func _helper_dir(i: int) -> Vector2:
	var n := helper_path.size()
	var rev: bool = helper_path[i][2]
	var a := i
	var b := i
	for k in 3:
		if a > 0 and helper_path[a - 1][2] == rev:
			a -= 1
		if b < n - 1 and helper_path[b + 1][2] == rev:
			b += 1
	var d := (helper_path[b][0] as Vector2) - (helper_path[a][0] as Vector2)
	if d.length() < 0.01:
		return Vector2(-sin(rotation.y), -cos(rotation.y))
	return -d.normalized() if rev else d.normalized()


func _helper_point(s: float) -> Vector2:
	var f := s / HELPER_STEP
	var i := clampi(int(f), 0, helper_path.size() - 2)
	return (helper_path[i][0] as Vector2).lerp(helper_path[i + 1][0], clampf(f - i, 0.0, 1.0))


## Reittiä eteenpäin: työkaistalla koneen työnopeus, käännöksissä hitaammin. Askel enintään reitin pisteväli, jotta
## työ (kaisua.gd _apply_work) kattaa kaistan aukoitta myös aikakertoimella.
func _helper_drive(delta: float) -> void:
	var n := helper_path.size()
	var total := (n - 1) * HELPER_STEP
	var i := clampi(int(helper_s / HELPER_STEP), 0, n - 1)
	var on_work: bool = helper_path[i][1]
	var v: float = HELPER_TURN_SPEED
	if on_work and implement != null:
		v = float(Koneet.IMPLEMENTS[implement_id].speed)
	elif on_work and kind == "puimuri":
		v = 3.0
	fuel = maxf(0.0, fuel - delta * helper_rate * (FUEL_IDLE + FUEL_LOAD * _load))
	if fuel <= 0.0:
		helper_done = true  # kaisua.gd kertoo ja lopettaa
		speed = 0.0
		return
	if on_work != working:
		set_working(on_work)
	var rev: bool = helper_path[i][2]
	if rev:
		v = 1.6
	var dist := v * delta * helper_rate
	var steps := maxi(1, ceili(dist / HELPER_STEP))
	var prev_yaw := rotation.y
	for k in steps:
		helper_s = minf(helper_s + dist / steps, total)
		var p := _helper_point(helper_s)
		var f := _helper_dir(clampi(int(helper_s / HELPER_STEP), 0, n - 1))
		position = Vector3(p.x, float(height_fn.call(p.x, p.y)), p.y)
		rotation.y = atan2(-f.x, -f.y)
		_update_implement(delta * helper_rate / steps)  # nosto ja lasku samassa aikakertoimessa kuin ajo
		if working:
			_do_work()
	speed = -v if rev else v
	var turn := wrapf(rotation.y - prev_yaw, -PI, PI) / maxf(dist, 0.01)  # kaarevuus 1/m
	var wb := Koneet.C_WHEELBASE if kind == "puimuri" else Koneet.T_WHEELBASE
	_steer = clampf(atan(turn * wb) / 0.6, -1.0, 1.0)
	_ground_follow(delta)
	_animate(delta, 0.6)
	_work_sound(delta)
	_engine.stream_paused = false
	if helper_s >= total:
		helper_done = true
		speed = 0.0
		set_working(false)


# --- Työkone -------------------------------------------------------------------------------------------------------

## Kytkee työkoneen (kaisua.gd tarkistaa etäisyyden): nostimen kone rungon lapseksi, aisan kone perävaunuksi.
func hitch(id: String, node: Node3D, parts: Dictionary) -> void:
	implement = node
	implement_id = id
	implement_parts = parts
	_lift = 1.0
	if Koneet.IMPLEMENTS[id].mount == "nostin":
		var keep := node.global_transform
		node.get_parent().remove_child(node)
		_visual.add_child(node)
		node.global_transform = keep
	Sfx.play_on(self, "rattle_hard", -4.0, 0.9)


## Irrottaa työkoneen paikalleen maahan; palauttaa koneen solmun (kaisua.gd liittää sen takaisin pihaan).
func unhitch(parent: Node3D) -> Node3D:
	var node := implement
	if node == null:
		return null
	set_working(false)
	if Koneet.IMPLEMENTS[implement_id].mount == "nostin":
		var keep := node.global_transform
		_visual.remove_child(node)
		parent.add_child(node)
		node.global_transform = keep
		var y := node.global_transform.basis.get_euler().y
		node.global_rotation = Vector3(0, y, 0)
	_settle(node)
	implement = null
	implement_id = ""
	implement_parts = {}
	Sfx.play_on(self, "rattle_hard", -4.0, 0.8)
	return node


## Koneen solmu maahan (paikallinen maasto).
func _settle(node: Node3D) -> void:
	node.global_position = _ground_at(node.global_position)


## Maailman piste maan pinnalle (mökin maastoverkko).
func _ground_at(p: Vector3) -> Vector3:
	if not to_local_fn.is_valid():
		return p
	var lp: Vector3 = to_local_fn.call(p)
	return Vector3(p.x, p.y + float(height_fn.call(lp.x, lp.z)) - lp.y, p.z)


func link_point() -> Vector3:
	return _visual.to_global(Koneet.T_LINK)


func hitch_point() -> Vector3:
	return _visual.to_global(Koneet.T_HITCH)


func _update_implement(delta: float) -> void:
	if implement == null:
		return
	var info: Dictionary = Koneet.IMPLEMENTS[implement_id]
	_lift = move_toward(_lift, 0.0 if working else 1.0, 1.5 * delta)
	if info.mount == "nostin":
		# Aura painuu töissä vannasten syvyydelle (18 cm), muut koneet maan pintaan.
		var sink := 0.18 if implement_id == "aura" else 0.0
		implement.position = Vector3(0, _lift * 0.35 + 0.02 - sink * (1.0 - _lift), Koneet.T_LINK.z)
		implement.rotation = Vector3.ZERO
		for w in implement_parts.get("wheels", []):
			(w as Node3D).rotation.x -= speed * delta / 0.33 * (1.0 - _lift)
		if implement_parts.has("bar"):
			(implement_parts.bar as Node3D).rotation.z = _lift * 1.35
	else:
		# Perävaunu: aisan silmä koukussa, akseli seuraa (aisa osoittaa akselilta koukulle), kone maan tasolla.
		var hp := hitch_point()
		var axle_d: float = info.axle
		var axle := implement.global_position + implement.global_transform.basis.z * axle_d
		var dir := hp - axle
		dir.y = 0.0
		if dir.length() > 0.01:
			dir = dir.normalized()
			implement.global_rotation = Vector3(0, atan2(-dir.x, -dir.z), 0)
			if speed < 0.0 and not helper_path.is_empty():
				# Santun lyhyet peruutukset päisteessä: vaunu oikenee traktorin linjaan (ei linkkaa).
				implement.global_rotation.y = lerp_angle(implement.global_rotation.y, global_rotation.y, clampf(delta * 3.0, 0.0, 1.0))
		implement.global_position = _ground_at(hp)
		for w in implement_parts.get("wheels", []):
			(w as Node3D).rotation.x -= speed * delta / 0.4
	var spin_rate := 6.0 if working else 0.0
	_spin += spin_rate * delta
	for s in implement_parts.get("spin", []):
		var n := s as Node3D
		if implement_id == "karhotin":
			n.rotation.y = _spin * (1.0 if n.position.x > 0.0 else -1.0) * 0.5
		elif implement_id == "niittokone":
			n.rotation.y = _spin * 4.0
		else:
			n.rotation.x = -_spin
	_dust.emitting = working and speed > 0.5 and implement_id in ["aes", "kylvokone", "aura"]


## Työalue pellolle (koneen kehyksestä mökin paikalliseen) ja work_fn.
func _do_work() -> void:
	if not work_fn.is_valid() or not to_local_fn.is_valid():
		return
	var op := ""
	var c := Vector3.ZERO
	var hw := 0.0
	var hl := 0.0
	var frame: Node3D = self
	if kind == "puimuri":
		op = "puinti"
		c = Vector3(0, 0, -2.55)
		hw = 2.1
		hl = 0.35
		frame = _visual
	elif implement != null and _lift < 0.15:
		var info: Dictionary = Koneet.IMPLEMENTS[implement_id]
		op = info.work
		c = info.c
		hw = info.hw
		hl = info.hl
		frame = implement
	if op == "":
		return
	var gc := frame.to_global(c)
	var gf := frame.to_global(c + Vector3.FORWARD) - gc
	var lc: Vector3 = to_local_fn.call(gc)
	var lf: Vector3 = to_local_fn.call(gc + gf) - lc
	var f2 := Vector2(lf.x, lf.z).normalized()
	work_fn.call(op, Vector2(lc.x, lc.z), f2, hw, hl)


## Paalipiikin kärjen kohta (maailmassa), paali kiinni ja irti.
func spear_point() -> Vector3:
	return _model.spear.to_global(Vector3(0, 0, -0.65))


func take_bale(b: Node3D) -> void:
	bale = b
	var keep := b.global_transform
	b.get_parent().remove_child(b)
	_model.spear.add_child(b)
	b.global_transform = keep
	var tw := create_tween()
	tw.tween_property(b, "position", Vector3(0, -0.62, -0.68), 0.35)
	tw.parallel().tween_property(b, "rotation", Vector3(0, PI / 2.0, 0), 0.35)
	Sfx.play_on(self, "pickup", -4.0, 0.7)


func drop_bale(parent: Node3D) -> Node3D:
	var b := bale
	if b == null:
		return null
	bale = null
	var keep := b.global_transform
	_model.spear.remove_child(b)
	parent.add_child(b)
	b.global_transform = keep
	var y := b.global_transform.basis.get_euler().y
	b.global_rotation = Vector3(0, y, 0)
	_settle(b)
	return b
