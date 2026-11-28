extends CanvasLayer
## Legendaarinen hetki "sahkopyora" (Saloislainen sähköpyörä): kun viimeinen liitos on tehty autotallin työpöydällä
## (main.gd _start_ebike_game), ensimmäinen koeajo lavastetaan kodin autotallin edessä Järvikujalla. Vaiheet:
##   ovi     nosturiovi nousee, pyörä rullaa pimeästä tallista nurmelle; Pekka (akut) ja Arto (johdot) odottavat
##           kädet puuskassa: "Kulukeeko se?"
##   kaasu   lähikuva tangosta: kaasukahva kiertyy, Makitan akun valo vihreälle, moottori vinkuu ja johdoista
##           sinkoaa kipinä (Arto perääntyy)
##   lahto   pyörä nykäisee keulan ilmaan, nurmea lentää, Pekka ja Arto väistävät, ja pyörä kaartaa kadulle
##   ajo     Järvikujaa polkematta jalat levällään, teipinpätkä liehuu tarakalla, Sinikka vilkuttaa kadun toiselta puolelta
##   paluu   jarrutus pihaan, Pekka osoittaa akkua ("Ne on mun Makitan akut!"), Arto johtoja ("Ja mun johdot!")
##   otsikko pyöräilijä nyrkki ylhäällä tallin edessä, naapurit hurraavat, kultainen SALOISLAINEN SÄHKÖPYÖRÄ
## Kehys: D = autotallin nosturioven edusta (world.garage_door), F = ovelta ulos kadulle (world.garage_out), S = F × ylös
## (etelään, Arton suuntaan). Järvikuja kulkee S:n suuntaisesti noin 8 m oven edessä. Pyörän etu on -Z (player_bike.gd,
## takapyörän kosketus (0, 0, 0,55)), hahmojen etu -Z (Looks).

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const Terrain := preload("res://scripts/terrain.gd")

const T := {"ovi": 4.6, "kaasu": 4.0, "lahto": 3.4, "ajo": 4.6, "paluu": 5.2, "otsikko": 5.8}
const ORDER := ["ovi", "kaasu", "lahto", "ajo", "paluu", "otsikko"]
const RATE := 22050.0
const REAR := Vector3(0, 0, 0.55)  # takapyörän kosketus pyörän mallissa
const STREET_F := 8.2  # Järvikujan keskilinja oven edestä
const STOP := Vector2(4.3, -0.2)  # paluun pysähdys (f, s), keula -S (pohjoiseen), kylki kadulle
const GRIP := Vector3(0.21, 1.22, -0.36)  # kaasukahva pyörän kehyksessä (player_bike.gd set_ebike)
const CTRL := Vector3(0, 0.6, -0.17)  # ohjainkotelo
const TAPE_AT := Vector3(0.08, 0.87, 0.74)  # teipinpätkän kiinnityskohta akun takapäädyssä (akku z 0,38..0,72; x renkaan ulkopuolella, roikkuessa ei pinnojen läpi)
const LEAN := 0.7  # kuskin kumara kohtauksessa (rad)
## Naapurien muistot myöhemmin (main.gd _neighbor_line): koeajo jäi kadulle puheeksi.
const MUISTO := {
	"pekka": ["Ne mun Makitan akut vei sut Järvikujan päähän ja takasin. Ei mikään kiinalainen.",
		"Sähköpyörä, perkele! Mää kerron siitä vieläkin kaikille."],
	"arto": ["Mää sanoin, että se savuaa. No, kipinöi se vähän.", "Mun johdot ne siinä kulki. Ei polkimia, ei mitään."],
}

var world: Node3D
var bike: CharacterBody3D  # main.bike (player_bike.gd), tallissa piilossa: tuodaan näkyviin ja ohjataan käsin
var battery := 1.0
var joints := {}  # ebike.joints: liitos -> kiinnitys (teippi liehuu, rautalanka kolisee)
var hide_nodes: Array = []  # oikeat naapurit ja jalan kulkeva pelaaja piiloon kohtauksen ajaksi (kopiot näyttelevät)
var _was_visible := {}

var phase := ""
var _t := 0.0
var _cam: Camera3D
var _ui: Control
var _keys: Node
var _story := ""
var _bub := {}  # hahmo -> repliikki
var _once := {}
var _shake := 0.0
var _D := Vector3.ZERO
var _F := Vector3.FORWARD
var _S := Vector3.RIGHT
var _props: Array[Node3D] = []
var pekka: Node3D
var arto: Node3D
var sinikka: Node3D
var _door_panel: MeshInstance3D
var _led: MeshInstance3D
var _led_mat: StandardMaterial3D
var _throttle: Node3D  # kaasukahvan merkkiviiva, kiertyy
var _tape: Array[MeshInstance3D] = []  # teipinpätkä tarakalla
var _sparks: CPUParticles3D
var _clods: CPUParticles3D
var _whine: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _route: Curve3D  # lähtö ja ajo (f, 0, s)
var _back: Curve3D  # paluu
var _u := 0.0  # matka reitillä
var bike_speed := 0.0  # testi lukee
var pitch := 0.0  # keulan nousu (rad), testi lukee
var _legs_up := 0.0  # 0 = jalat polkimilla, 1 = levällään
var _grip_off := Vector3.ZERO  # kaasukäden kohteen korjaus (rider-kehys)


func _ready() -> void:
	layer = 6
	_D = world.garage_door
	_F = world.garage_out.normalized()
	_S = _F.cross(Vector3.UP).normalized()
	_cam = Camera3D.new()
	world.add_child(_cam)
	_cam.make_current()
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_keys.set_text("%s ohita" % Settings.cap("interact"))
	_whine = AudioStreamPlayer.new()
	_whine.stream = Sfx.stream("engine")
	_whine.volume_db = -80.0
	add_child(_whine)
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	for n in hide_nodes:
		if is_instance_valid(n):
			_was_visible[n] = (n as Node3D).visible
			(n as Node3D).visible = false
	# Pyörä näkyviin, oma fysiikka pois (sijainti, pyörät ja kuskin asento tästä).
	bike.visible = true
	bike.process_mode = Node.PROCESS_MODE_INHERIT
	bike.set_physics_process(false)
	bike.speed = 0.0
	bike.set_rider_visible(true)
	bike._visual.position = Vector3.ZERO
	bike._visual.rotation = Vector3.ZERO
	# Kuski kumarampaan, jotta kädet yltävät kahvoihin (ajossa 0,4 rad jättää kädet tangon taakse).
	bike._rider.set_override("spine_01", Vector3.RIGHT, -LEAN)
	_build_route()
	_build_props()
	_begin("ovi")


func _build_route() -> void:
	_route = Curve3D.new()
	_route.bake_interval = 0.1
	_route.add_point(Vector3(1.9, 0, 0), Vector3.ZERO, Vector3(2.2, 0, 0))
	_route.add_point(Vector3(STREET_F, 0, 4.0), Vector3(-0.2, 0, -2.6), Vector3(0.1, 0, 2.0))
	_route.add_point(Vector3(STREET_F, 0, 40.0))
	_back = Curve3D.new()
	_back.bake_interval = 0.1
	_back.add_point(Vector3(STREET_F - 0.6, 0, 24.0), Vector3.ZERO, Vector3(0, 0, -6.0))
	_back.add_point(Vector3(STOP.x + 0.4, 0, STOP.y + 3.0), Vector3(1.6, 0, 2.2), Vector3(-0.3, 0, -0.9))
	_back.add_point(Vector3(STOP.x, 0, STOP.y), Vector3(0, 0, 1.0))


func _build_props() -> void:
	# Nosturiovi: pimeä aukko ja nouseva ovilevy oven pinnan eteen (tallin oma ovi on osa seinää).
	var face := _D - _F * 0.8
	var holder := Node3D.new()
	world.add_child(holder)
	_props.append(holder)
	holder.global_position = Vector3(face.x, _ground(face), face.z)
	holder.rotation.y = B.yaw_to(-_F)  # paikallinen +Z = ulos
	B.mesh(holder, B.boxm(Vector3(2.66, 2.14, 0.02)), Vector3(0, 1.08, 0.04), Color(0.07, 0.06, 0.05))
	# Sisällä hehkuu työpöydän lamppu ja näkyy työkalutaulun ääriviiva.
	var bulb := B.mesh(holder, B.sphere(0.07, 8), Vector3(0.7, 1.6, 0.06), Color(1.0, 0.85, 0.5))
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.85, 0.5)
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.8, 0.45)
	bm.emission_energy_multiplier = 2.5
	bulb.material_override = bm
	B.mesh(holder, B.boxm(Vector3(1.1, 0.06, 0.01)), Vector3(0.6, 0.9, 0.055), Color(0.22, 0.16, 0.1))
	B.mesh(holder, B.boxm(Vector3(0.8, 0.5, 0.01)), Vector3(0.6, 1.3, 0.052), Color(0.14, 0.12, 0.1))
	_door_panel = B.mesh(holder, B.boxm(Vector3(2.78, 1.0, 0.05)), Vector3(0, 1.1, 0.08), Color(0.4, 0.25, 0.15))
	for k in 6:
		B.mesh(_door_panel, B.boxm(Vector3(2.7, 0.03, 0.02)), Vector3(0, -0.5 + k * 0.2, 0.035), Color(0.32, 0.2, 0.12))
	# Akun merkkivalo (punainen -> vihreä), kaasukahvan merkkiviiva ja teipinpätkä.
	_led = B.mesh(bike._visual, B.boxm(Vector3(0.03, 0.012, 0.03)), Vector3(0.04, 0.887, 0.46), Color(0.6, 0.05, 0.05))
	_led_mat = StandardMaterial3D.new()
	_led_mat.albedo_color = Color(0.5, 0.04, 0.04)
	_led_mat.emission_enabled = true
	_led_mat.emission = Color(0.9, 0.1, 0.05)
	_led_mat.emission_energy_multiplier = 1.5
	_led.material_override = _led_mat
	_props.append(_led)
	_throttle = Node3D.new()
	_throttle.position = GRIP
	bike._visual.add_child(_throttle)
	_props.append(_throttle)
	B.mesh(_throttle, B.boxm(Vector3(0.072, 0.008, 0.012)), Vector3(0, 0.026, 0), Color(0.08, 0.08, 0.08))
	if joints.values().has("teippi"):
		var at := TAPE_AT
		for i in 6:
			var seg := B.mesh(bike._visual, B.boxm(Vector3(0.004, 0.048, 0.072)), at, Color(0.7, 0.71, 0.68))  # kaistale pystyssä: näkyy sivulta
			_tape.append(seg)
			_props.append(seg)
	_sparks = _particles(bike._visual, CTRL, Color(1.0, 0.9, 0.45), 26, 0.45, 0.012, true)
	_sparks.direction = Vector3(0.4, 1, 0.2)
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 1.2
	_sparks.initial_velocity_max = 2.6
	_clods = _particles(world, Vector3.ZERO, Color(0.28, 0.42, 0.14), 34, 0.8, 0.05, false)
	_clods.direction = Vector3(0, 1, 0)
	_clods.spread = 30.0
	_clods.initial_velocity_min = 2.0
	_clods.initial_velocity_max = 3.6
	# Naapurit: Pekka toi akut, Arto johdot; Sinikka kadun toisella puolella pensasaidan luona.
	pekka = _person(Looks.PEKKA, 3.3, -2.4)
	arto = _person(Looks.ARTO, 3.1, 2.3)
	sinikka = _person(Looks.SINIKKA, 10.9, 14.0)
	for c in [pekka, arto]:
		_face(c, _P(1.0, 0.0))
	_face(sinikka, _P(STREET_F, 8.0))


func _particles(parent: Node3D, at: Vector3, col: Color, n: int, life: float, size: float, glow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	p.position = at
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	if glow:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 4.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	parent.add_child(p)
	_props.append(p)
	return p


func _person(look: Dictionary, f: float, s: float) -> Node3D:
	var c: Node3D = Looks.make(world, look)
	_props.append(c)
	c.global_position = _P(f, s)
	c.play("Idle", 0.0)
	return c


func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	for c in [pekka, arto, sinikka]:
		c.clear_ik()
		c.clear_overrides()
	match p:
		"ovi":
			_story = "Pekka toi akut, Arto johdot. Nyt nähdään, kulkeeko."
			Sfx.play("rattle", -6.0, 0.6)
			_place_bike(_P(-1.6, 0.0), _F, 0.0)
		"kaasu":
			_story = "Kaasukahva. Porakoneen akku. Jeesusteippi. Kolme, kaks, yks..."
			_place_bike(_P(1.9, 0.0), _F, 0.0)
			_set_door(1.0)
			_stand(pekka, 3.3, -2.4)
			_stand(arto, 3.1, 2.3)
		"lahto":
			_story = "SE LÄHTI!"
			_u = 0.0
			bike_speed = 0.0
			_clods.global_position = _P(1.9, 0.0) + _F * 0.5
			_clods.restart()
			Sfx.play("whoosh", -3.0, 0.8)
			_shake = 0.5
		"ajo":
			_story = "Ei tarvi polkea! Järvikujaa kolmeakymppiä ilman ainuttakaan poljinkierrosta."
			_u = _route.get_closest_offset(Vector3(STREET_F, 0, 1.8))
			bike_speed = 6.5
			_stand(pekka, 5.0, -1.2)
			_stand(arto, 5.4, 1.2)
		"paluu":
			_story = "Takaisin pihaan. Jarrut toimii. Melkein."
			_u = 0.0
			_stand(pekka, 3.1, -2.6)
			_stand(arto, 3.0, 1.9)
			_face(pekka, _P(STREET_F, 6.0))
			_face(arto, _P(STREET_F, 6.0))
		"otsikko":
			_story = ""
			_u = _back.get_baked_length()
			_place_on(_back, _u, 0.0)
			_legs_up = 0.0
			_stand(pekka, 3.1, -2.6)
			_stand(arto, 3.0, 1.9)
			_whine.stop()
			Sfx.play("win", -4.0)
			_set_door(1.0)


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 2.2)
	if Input.is_action_just_pressed("interact"):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"ovi":
			_step_ovi(delta)
		"kaasu":
			_step_kaasu(delta)
		"lahto":
			_step_lahto(delta)
		"ajo":
			_step_ajo(delta)
		"paluu":
			_step_paluu(delta)
		"otsikko":
			_step_otsikko(delta)
	_pose_rider()
	_update_tape()
	_ui.queue_redraw()
	if phase != "" and _t >= T[phase]:
		var i := ORDER.find(phase)
		if i == ORDER.size() - 1:
			_finish()
		else:
			_begin(ORDER[i + 1])


func _finish() -> void:
	if phase == "":
		return
	phase = ""
	_whine.stop()
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	for n in _was_visible:
		if is_instance_valid(n):
			(n as Node3D).visible = _was_visible[n]
	bike._visual.position = Vector3.ZERO
	bike._visual.rotation = Vector3.ZERO
	bike._rider.set_override("spine_01", Vector3.RIGHT, -0.4)  # player_bike.gd:n oma kumara
	bike.set_physics_process(true)
	bike.speed = 0.0
	finished.emit()
	_cam.queue_free()
	queue_free()


# --- Vaiheet ------------------------------------------------------------------------

func _step_ovi(delta: float) -> void:
	var open := clampf(_t / 1.8, 0.0, 1.0)
	_set_door(open)
	# Pyörä rullaa hitaasti ulos (jalat lattiaa vasten), kun ovi on puoliksi auki.
	var k := clampf((_t - 1.4) / 2.6, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var f := lerpf(-1.6, 1.9, k)
	_place_bike(_P(f, 0.0), _F, 0.0)
	_spin(1.35 * (1.0 if k > 0.0 and k < 1.0 else 0.0), delta)
	for c in [pekka, arto]:
		_arms_crossed(c)
		_face(c, bike.global_position)
	if _t > 1.6:
		_bub[pekka] = "Pekka: No? Kulukeeko se?"
	if _t > 3.1:
		_bub[arto] = "Arto: Mää sanon, että se savuaa."
	# Kamera nurmelta suoraan ovelle: ovi ja pyörä keskellä, Pekka ja Arto reunoilla (leveys 7,4 m lasketaan).
	var look := _P(1.2, 0.0, 1.1)
	var eye := _P(9.0, 0.5, 1.5)
	_cam_at(eye, look, _fov_w(9.0 - 3.2, 7.0))  # naapurit f = 3,2, s = ±2,4


func _step_kaasu(delta: float) -> void:
	var twist := clampf((_t - 0.5) / 0.9, 0.0, 1.0)
	_throttle.rotation.x = -1.1 * twist
	var on := _t > 1.1
	_led_mat.emission = Color(0.1, 1.0, 0.25) if on else Color(0.9, 0.1, 0.05)
	_led_mat.albedo_color = Color(0.1, 0.6, 0.15) if on else Color(0.5, 0.04, 0.04)
	if on:
		var k := clampf((_t - 1.1) / 1.6, 0.0, 1.0)
		_whine.pitch_scale = 1.6 + 2.2 * k
		_whine.volume_db = -14.0 + 6.0 * k
		if not _whine.playing:
			_whine.play()
		_spin(6.0 * k, delta)  # takapyörä alkaa pyöriä paikallaan, nurmi pitää vielä
	if _t > 2.3 and not _once.has("spark"):
		_once["spark"] = true
		_sparks.restart()
		_play(_crackle_wav(), -4.0)
		_shake = 0.35
		_story = "Kipinä! Johdoista. Arto ottaa askeleen taaksepäin."
	if _t > 2.3:
		arto.global_position = arto.global_position.lerp(_P(3.6, 3.2), minf(1.0, delta * 4.0))
		_hands_up(arto, 0.8)
	_arms_crossed(pekka)
	# Lähikuva: tanko, kaasukahva, ohjainkotelo ja kuskin kasvot pyörän oikealta etuviistosta.
	var look := bike.to_global(Vector3(0.05, 1.0, -0.1))
	var eye := bike.to_global(Vector3(1.05, 1.5, -1.35))
	_cam_at(eye, look, 40.0)


func _step_lahto(delta: float) -> void:
	# Keula nousee nykäyksestä, laskeutuu kahdessa sekunnissa; vauhti kasvaa kadulle.
	var a := clampf(_t / 0.25, 0.0, 1.0)
	var down := clampf((_t - 0.9) / 0.9, 0.0, 1.0)
	pitch = 0.38 * a * (1.0 - down * down) + 0.04 * sin(_t * 14.0) * (1.0 - down)
	bike_speed = minf(6.5, 1.0 + _t * 3.2)
	_u = minf(_u + bike_speed * delta, _route.get_baked_length())
	_place_on(_route, _u, pitch)
	_spin(bike_speed, delta)
	_legs_up = clampf(_t / 0.3, 0.0, 1.0)
	_whine.pitch_scale = 3.8 + 0.4 * sin(_t * 3.0)
	_whine.volume_db = -7.0
	# Pekka ja Arto väistävät sivuun ja nostavat kädet.
	var k := clampf(_t / 0.5, 0.0, 1.0)
	pekka.global_position = _P(3.3, -2.4).lerp(_P(3.6, -3.4), k)
	arto.global_position = _P(3.6, 3.2).lerp(_P(3.9, 3.9), k)
	_hands_up(pekka, 1.0)
	_hands_up(arto, 1.0)
	_face(pekka, bike.global_position)
	_face(arto, bike.global_position)
	if _t > 0.4:
		_bub[pekka] = "Pekka: PERKELE!"
	# Kuva kadun toiselta puolelta: piha, tallin ovi ja naapurit; kamera kääntyy pyörän mukana sen kaartaessa kadulle.
	var eye := _P(14.5, 2.6, 1.6)
	var look := _P(4.0, 0.3, 0.95).lerp(bike.global_position + Vector3(0, 0.9, 0), 0.55)
	_cam_at(eye, look, _fov_w(eye.distance_to(_P(4.0, 0.3)), 9.0))


func _step_ajo(delta: float) -> void:
	_u = minf(_u + bike_speed * delta, _route.get_baked_length())
	_place_on(_route, _u, 0.0)
	_spin(bike_speed, delta)
	_legs_up = 1.0
	_whine.pitch_scale = 3.9 + 0.15 * sin(_t * 9.0)
	_whine.volume_db = -8.0
	if joints.values().has("rautalanka") and fmod(_t, 0.55) < delta:
		Sfx.play("rattle", -12.0, randf_range(0.9, 1.15))
	var bs := (bike.global_position - _D).dot(_S)
	_face(sinikka, bike.global_position)
	if bs > 3.0:
		_wave(sinikka, _t)
		_bub[sinikka] = "Sinikka: No nyt se kulkee! Kypärä päähän!"
	for c in [pekka, arto]:
		_face(c, bike.global_position)
	# Kamera kadulla pyörän edellä etuviistossa (peruuttaa samaa vauhtia): pyörä isona keskellä, Sinikka kadun
	# itäreunalla kuvan oikealla, kun pyörä ohittaa hänet.
	var bp := bike.global_position
	var eye := _P(STREET_F + 1.5, bs + 4.6, 1.05)
	var look := bp + Vector3(0, 0.85, 0) + _F * 0.5
	_cam_at(eye, look, _fov_for(eye.distance_to(look), 2.0, 0.5))


func _step_paluu(delta: float) -> void:
	var L := _back.get_baked_length()
	var dur := 3.0
	var k := clampf(_t / dur, 0.0, 1.0)
	var e := 1.0 - (1.0 - k) * (1.0 - k)
	var prev := _u
	_u = L * e
	bike_speed = (_u - prev) / maxf(delta, 0.001)
	_place_on(_back, _u, -0.06 * clampf((k - 0.8) / 0.2, 0.0, 1.0) * (1.0 - clampf((_t - dur) / 0.3, 0.0, 1.0)))
	_spin(bike_speed, delta)
	_legs_up = 1.0 - clampf((k - 0.7) / 0.3, 0.0, 1.0)
	_whine.volume_db = lerpf(-8.0, -40.0, k)
	if k >= 1.0:
		_whine.stop()
	if k > 0.82 and not _once.has("brake"):
		_once["brake"] = true
		Sfx.play("pedal_squeak", -2.0, 0.7)
	if _t > dur:
		if not _once.has("point"):
			_once["point"] = true
			pekka.clear_ik()
			arto.clear_ik()
		var bat := bike.to_global(Vector3(0, 0.88, 0.5))
		var wire := bike.to_global(CTRL)
		_point(pekka, bat)
		_point(arto, wire)
		_face(pekka, bat)
		_face(arto, wire)
		_bub[pekka] = "Pekka: Ne on mun Makitan akut!"
		if _t > dur + 1.0:
			_bub[arto] = "Arto: Ja mun johdot!"
	else:
		_face(pekka, bike.global_position)
		_face(arto, bike.global_position)
		_cheer(pekka, _t)
		_cheer(arto, _t + 0.3)
	# Kadulta tallille päin: pyörä kyljittäin keskellä, Pekka ja Arto sen molemmin puolin, ovi taustalla.
	var look := _P(STOP.x - 0.6, STOP.y + 0.1, 1.0)
	var eye := _P(STOP.x + 6.4, STOP.y + 0.6, 1.55)
	_cam_at(eye, look, _fov_for(eye.distance_to(look), 2.9, 0.78))


func _step_otsikko(delta: float) -> void:
	_cheer(pekka, _t)
	_cheer(arto, _t + 0.4)
	_face(pekka, bike.global_position)
	_face(arto, bike.global_position)
	var look := _P(STOP.x - 0.8, STOP.y + 0.1, 1.25)
	var eye := _P(STOP.x + 7.4, STOP.y + 1.0, 2.1)
	_cam_at(eye, look, _fov_for(eye.distance_to(look), 3.6, 0.6))


# --- Pyörä ja kuski -----------------------------------------------------------------

## Pyörä kohtaan pos, keula suuntaan h; keulan nosto kiertää mallia takapyörän kosketuksen ympäri.
func _place_bike(pos: Vector3, h: Vector3, p: float) -> void:
	h.y = 0.0
	h = h.normalized()
	var yb := Basis(Vector3.UP, atan2(-h.x, -h.z))
	var full := yb * Basis(Vector3.RIGHT, p)
	var ground := Vector3(pos.x, _ground(pos), pos.z)
	var contact := ground + yb * REAR
	bike.global_transform = Transform3D(full, contact - full * REAR)


func _place_on(c: Curve3D, u: float, p: float) -> void:
	var L := c.get_baked_length()
	var a := c.sample_baked(clampf(u, 0.0, L))
	var b := c.sample_baked(clampf(u + 0.3, 0.0, L))
	if u + 0.3 > L:
		b = a + (a - c.sample_baked(clampf(u - 0.3, 0.0, L)))
	var pa := _P(a.x, a.z)
	var pb := _P(b.x, b.z)
	_place_bike(pa, pb - pa, p)


func _spin(v: float, delta: float) -> void:
	for w in bike._wheels:
		w.rotation.x -= v * delta / 0.35


## Kädet tangolle ja jalat polkimille (player_bike.gd), ajossa jalat levällään sivuille (ei tarvi polkea).
func _pose_rider() -> void:
	bike._animate_pedals(0.0)
	if phase == "kaasu":
		_hand_on_throttle()
	elif phase == "otsikko":
		_fist_up(clampf(_t / 0.4, 0.0, 1.0))
	var r: Node3D = bike._rider
	var inv := r.transform.affine_inverse()
	if _legs_up > 0.0:
		for side in [["_l", -1.0], ["_r", 1.0]]:
			var s: float = side[1]
			var pedal := Vector3(0.12 * s, 0.27, 0.05)
			var out := Vector3(0.42 * s, 0.5, -0.32 + 0.04 * sin(_t * 7.0 + s))
			var foot := pedal.lerp(out, _legs_up)
			r.set_ik("leg" + side[0], "thigh" + side[0], "calf" + side[0], "foot" + side[0], inv * foot,
				inv * Vector3(0.45 * s, 1.0, -0.4))


## Kaasukäsi keltaiselle kahvalle (kaasu-vaihe): ranteen kohde korjataan joka ruutu niin, että ranteen ja etusormen
## tyven väli osuu kahvaan (player_bike.gd:n oma kahvakohta on kahvan ulkopuolella).
func _hand_on_throttle() -> void:
	var r: Node3D = bike._rider
	var sh: Vector3 = r.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var grip_l: Vector3 = r.to_local(bike._visual.to_global(GRIP))
	var palm: Vector3 = (r.bone_position("hand_r") + r.bone_position("index_01_r")) / 2.0
	_grip_off += (grip_l - palm) * 0.5
	_grip_off = _grip_off.limit_length(0.2)
	r.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", grip_l + _grip_off, sh + Vector3(s * 0.35, -0.35, 0.1))


## Pyöräilijän oikea nyrkki ilmaan (otsikossa kameran puoli, pyörä seisoo), vasen pysyy tangossa.
func _fist_up(w: float) -> void:
	var r: Node3D = bike._rider
	var sh: Vector3 = r.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest: Vector3 = r.bone_position("hand_r")
	var up := sh + Vector3(s * 0.12, 0.56, -0.06)
	r.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", rest.lerp(up, w), sh + Vector3(s * 0.45, 0.05, 0.25))


func _update_tape() -> void:
	if _tape.is_empty():
		return
	# Pätkä roikkuu paikallaan ja liehuu vauhdissa: kulma taittuu pala palalta (aalto kulkee taaksepäin ja kasvaa
	# vapaata päätä kohti), joten kaistale kiemurtelee eikä ole suora keppi.
	var flow := clampf(absf(bike_speed) / 6.0, 0.0, 1.0)
	var p := TAPE_AT
	var n := _tape.size()
	var base := lerpf(-1.25, -0.12, flow)  # kulma vaakatasosta taaksepäin: roikkuu -> liehuu
	for i in n:
		var wave := sin(_t * (6.0 + 16.0 * flow) - i * 1.2) * (0.25 + 0.45 * flow) * float(i + 1) / n
		var a := base + wave
		var d := Vector3(0.0, sin(a), cos(a))
		var seg := _tape[i]
		var z := d
		var x := Vector3.RIGHT
		var y := z.cross(x).normalized()
		seg.transform = Transform3D(Basis(x, y, z), p + d * 0.035)
		p += d * 0.068

# --- Naapurit -----------------------------------------------------------------------

func _stand(c: Node3D, f: float, s: float) -> void:
	c.global_position = _P(f, s)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.global_position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


func _arms_crossed(c: Node3D) -> void:
	for side in [["_l", -1.0], ["_r", 1.0]]:
		var lr: String = side[0]
		var sh: Vector3 = c.bone_position("upperarm" + lr)
		var s := signf(sh.x) if sh.x != 0.0 else float(side[1])
		var chest := Vector3(-s * 0.1, sh.y - 0.3, sh.z - 0.24)
		c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, chest, sh + Vector3(s * 0.4, -0.3, -0.1))


func _hands_up(c: Node3D, w: float) -> void:
	for lr in ["_l", "_r"]:
		var sh: Vector3 = c.bone_position("upperarm" + lr)
		var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
		var tgt := sh + Vector3(s * 0.3, 0.3 * w, -0.32)
		c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, tgt, sh + Vector3(s * 0.45, -0.2, 0.2))


func _cheer(c: Node3D, t: float) -> void:
	var bob := absf(sin(t * 6.0))
	for lr in ["_l", "_r"]:
		var sh: Vector3 = c.bone_position("upperarm" + lr)
		var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
		c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, sh + Vector3(s * 0.2, 0.46 + 0.08 * bob, -0.08),
			sh + Vector3(s * 0.45, 0.0, 0.25))


func _wave(c: Node3D, t: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", sh + Vector3(s * (0.2 + 0.14 * sin(t * 8.0)), 0.5, -0.1),
		sh + Vector3(s * 0.45, 0.0, 0.25))


func _point(c: Node3D, at_global: Vector3) -> void:
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var dir := (c.to_local(at_global) - sh).normalized()
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", sh + dir * 0.56, sh + Vector3(s * 0.4, -0.35, 0.1))


# --- Ovi, kamera ja ääni ------------------------------------------------------------

## Ovilevy nousee: 0 = kiinni (peittää aukon), 1 = rullalla ylhäällä.
func _set_door(open: float) -> void:
	var h := lerpf(2.14, 0.22, open)
	_door_panel.scale.y = h
	_door_panel.position.y = 2.15 - h / 2.0


func _P(f: float, s: float, y := 0.0) -> Vector3:
	var p := _D + _F * f + _S * s
	return Vector3(p.x, _ground(p) + y, p.z)


func _ground(p: Vector3) -> float:
	return Terrain.h(p.x, p.z)


func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.06 * _shake
	_cam.fov = fov
	_cam.look_at_from_position(eye + sh, look)


## Kuvakulma (pystysuora), jolla leveys w etäisyydellä d mahtuu kuvaan vaakasuunnassa.
func _fov_w(d: float, w: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return rad_to_deg(2.0 * atan(w / (2.0 * d) / (vs.x / vs.y)))


## Kuvakulma, jolla korkeus h etäisyydellä d täyttää osuuden frac kuvan korkeudesta.
func _fov_for(d: float, h: float, frac: float) -> float:
	return rad_to_deg(2.0 * atan(h / (2.0 * d * frac)))


func _play(wav: AudioStreamWAV, db: float) -> void:
	_sfx.stream = wav
	_sfx.volume_db = db
	_sfx.play()


## Oikosulun rätinä: tiheitä napsahduksia ja suhinaa.
func _crackle_wav() -> AudioStreamWAV:
	var dur := 0.7
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var pop := 0.0
	for i in s.size():
		var t := i / RATE
		if rng.randf() < 0.004:
			pop = rng.randf_range(0.6, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		pop *= 0.93
		var hiss := rng.randf_range(-1.0, 1.0) * 0.25 * exp(-t * 5.0)
		var env := minf(t / 0.005, 1.0) * clampf((dur - t) / 0.2, 0.0, 1.0)
		s[i] = env * (pop + hiss)
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = bytes
	return w


# --- Piirto -------------------------------------------------------------------------

func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 440, 24, 880, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for c: Node3D in _bub:
		if is_instance_valid(c) and c.visible:
			Room.bubble(_ui, _cam, c, _bub[c], 90.0, 120.0)
	if phase == "otsikko":
		var a := clampf((_t - 0.7) / 0.8, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.05, 0.25 * a))
		var y := vs.y * 0.17
		_draw_bolt(Vector2(vs.x / 2.0, y - 92.0), a)
		var title := "SALOISLAINEN SÄHKÖPYÖRÄ"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 66, 12, Color(0.12, 0.04, 0.02, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 66, Color(1.0, 0.82, 0.35, a))
		var sr := Rect2(vs.x / 2.0 - 400, vs.y - 158.0, 800, 84)
		_ui.draw_rect(sr, Color(0.05, 0.04, 0.03, 0.75 * a))
		var tt := "Akku %d %%  ·  Pekan akut, Arton johdot" % roundi(battery * 100.0)
		_ui.draw_string(font, sr.position + Vector2(0, 30), tt, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(1.0, 0.85, 0.3, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Ruuveilla, teipillä ja toivolla kasattu sähköpyörä kulkee.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Salama otsikon yllä: keltainen siksak tummalla ääriviivalla.
func _draw_bolt(c: Vector2, a: float) -> void:
	var pts := PackedVector2Array([c + Vector2(8, -34), c + Vector2(-16, 4), c + Vector2(-1, 4), c + Vector2(-10, 36),
		c + Vector2(18, -6), c + Vector2(3, -6), c + Vector2(14, -34)])
	_ui.draw_colored_polygon(pts, Color(1.0, 0.84, 0.2, a))
	var loop := pts.duplicate()
	loop.append(pts[0])
	_ui.draw_polyline(loop, Color(0.25, 0.12, 0.02, a), 3.0)
