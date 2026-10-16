extends Node3D
## Pensasaidan leikkuu minäkuvakulmasta 3D:nä (kodin tuija-aita kadun puolella, hedge.gd). Lisätään aidan lapseksi,
## joten paikallinen kehys on aidan kehys: x aitaa pitkin, piha +z. Sähkötrimmeri on käsissä kuin Doomin moottorisaha,
## Päivi seisoo ajotien aukossa ja patistaa. Hiiri katsoo (terä on aina katseen kohdalla vaakatasossa), vasen nappi
## pohjassa leikkaa, A/D kävelee aitaa pitkin. Terä haukkaa latvasta palan kerrallaan (hedge.gd cut_range), joten
## rehottava aita tasataan ylhäältä alas Päivin narun tasalle; narun alle leikattu kohta jää koloksi. Kylkiversot
## napsitaan myös. Jatkojohto on mutkalla aidan päällä: oikea nappi nostaa sen pois. Terä johtoon katkaisee sen
## (kipinät, moottori sammuu), ja johto teipataan pitämällä E pohjassa. F / Esc lopettaa kesken.

signal finished(result: String)  # "ok" / "kesken"

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const EYE := 1.68
const STAND := 0.85  # silmien etäisyys aidan pihan puoleisesta pinnasta
const BITE := 0.22
const ROOT := 0.25  # terän juuri näin paljon ennen tähtäyspistettä (aidan etupinta)
const BLADE := 0.56
const WALK := 1.5
const SENS := 0.0028
const DONE_SHARE := 0.95
const TAPE_TIME := 1.6
const PAIVI_POS := Vector2(3.9, 0.3)  # x ja z suhteessa aidan keskilinjaan: ajotien aukossa aidan päädyn vieressä
const LINES := {
	"start": ["Narun tasalle. Ei senttiäkään alemmas.", "Mää vedin narun. Suoraan sitä pitkin, ei mitään aaltopeltiä.",
		"Johto on aidan päällä. Nosta se pois ennen ku leikkaat!"],
	"nag": ["Suoraan! Ei se oo mikään aaltopelti.", "Pidä se terä vaakatasossa.", "Kylkiversot kans, ne sojottaa pihalle.",
		"Anna-Liisa kattoo ikkunasta. Tee kunnolla.", "Pala kerrallaan, ei sitä yhellä vedolla."],
	"hole": ["KOLO! Nyt siinä on aukko koko kesän.", "Narun ALLE ei leikata! Anna-Liisa näkee tuon heti.",
		"No voi... Siihen jää ruskea kolo."],
	"cord_near": ["Johto! Varo sitä johtoa!", "Siinä on se johto. Nosta se pois ensin."],
	"cord_cut": ["No niin. Taas. Teippiä on sun takataskussa viime kesältä.", "Johto poikki! Ihan niinku viime kesänä."],
	"taped": ["Teipattu. Ja nyt varovasti.", "Toivottavasti se kestää. Jatka."],
	"cord_off": ["Hyvä. Johto pois alta.", "No niin, nyt ei mee johto poikki."],
	"sides": ["Kylkiversot! Ei se oo valmis, ku sivut sojottaa.", "Vielä ne kyljestä törröttävät oksat."],
	"half": ["No nyt alkaa näyttää aidalta.", "Hyvä. Samaan malliin."],
	"done": ["Suora ku viivottimella. Kiitos, kulta.", "No nyt! Tuo on pensasaita."],
	"done_holes": ["Valmis... mutta ne kolot. Ne näkyy kadulle.", "Ihan hyvä. Paitsi ne kolot."],
}

var hedge: Node3D  # hedge.gd, tämän solmun vanhempi
var start_x := 7.5
var drunk := 0.0
var holes := 0

var _cam: Camera3D
var _prev_cam: Camera3D
var _trim: Node3D
var _teeth: Node3D
var _blade_mat: StandardMaterial3D
var _body: Node3D  # pelaajan hahmo (character.gd), kädet IK:lla kahvoissa
var _paivi: Node3D
var _bubble: Label3D
var _cord: Node3D
var _cord_x := 0.0
var _cord_on := true
var _tape_mi: MeshInstance3D
var _lower := 0.0
var _chips: MultiMeshInstance3D
var _chip_data: Array = []  # [paikka, nopeus, akseli, kulma, pyörimä, maassa, väri, kohti]
var _splats: MultiMeshInstance3D
var _splat_data: Array = []  # [paikka kameran kehyksessä, koko, ikä, kulma, väri]
var _sparks: CPUParticles3D
var _motor: Motor
var _hud: CanvasLayer
var _info: Label
var _keys: Control
var _rng := RandomNumberGenerator.new()
var _done := false
var _phase := "leikkaa"  # leikkaa / johto / valmis
var _t := 0.0
var _x := 7.5
var _yaw := 0.0
var _pitch := -0.15
var _lmb := false
var _walking := 0.0
var _bob := 0.0
var _shake := 0.0
var _strain := 0.0
var _blade_y := 1.5
var _aim := Vector3.ZERO
var _prev_range := Vector2.INF  # edellisen ruudun terän x-väli (pyyhkäisy täyttää välin)
var _say_t := 0.0
var _nag_t := 9.0
var _hole_t := -10.0
var _snap_t := 0.0
var _tape := 0.0
var _end_t := 0.0
var _cord_warned := false
var _half_said := false
var _sides_said := false


## Trimmerin ääni syntetisoituna: terien edestakainen surina (n. 50 Hz kantti ja saha), moottorin vinkuna ja
## leikatessa kohinasta suodatettu rouske. Kuorma (strain) laskee kierroksia hieman.
class Motor extends AudioStreamPlayer:
	const MIX := 11025.0
	var on := false
	var strain := 0.0
	var _pb: AudioStreamGeneratorPlayback
	var _spd := 0.0
	var _ph := 0.0
	var _ph2 := 0.0
	var _lp := 0.0
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = MIX
		gen.buffer_length = 0.1
		stream = gen
		bus = "SFX"
		volume_db = -6.0
		play()
		_pb = get_stream_playback()

	func _process(delta: float) -> void:
		_spd = lerpf(_spd, (1.0 - strain * 0.2) if on else 0.0, 1.0 - exp(-(7.0 if on else 2.5) * delta))
		if _pb == null:
			return
		var dt := 1.0 / MIX
		for f in _pb.get_frames_available():
			var s := 0.0
			if _spd > 0.01:
				_ph = fmod(_ph + 54.0 * _spd * dt, 1.0)
				_ph2 = fmod(_ph2 + 1250.0 * _spd * dt, 1.0)
				var buzz := (0.2 if _ph < 0.5 else -0.2) + (_ph * 2.0 - 1.0) * 0.14
				_lp += (_rng.randf_range(-1.0, 1.0) - _lp) * 0.3
				var crunch := _lp * strain * 0.9 * (0.55 + 0.45 * sin(_ph * TAU * 2.0))
				s = (buzz + sin(_ph2 * TAU) * 0.05 + crunch) * _spd
			_pb.push_frame(Vector2(s, s))


func _ready() -> void:
	process_priority = 10  # oman hahmon animaation ja IK:n jälkeen: sormet taivutetaan kahvan ympäri (_grip)
	_rng.randomize()
	_x = start_x
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.03
	add_child(_cam)
	_cam.current = true
	_build_trimmer()
	_build_paivi()
	_body = Looks.make(self, Looks.PLAYER)
	_body.play("Idle", 0.0)
	_build_cord()
	_build_string()
	_build_particles()
	_motor = Motor.new()
	add_child(_motor)
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_place_camera()
	_say(LINES.start.pick_random(), 4.0)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 24)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 8)
	_info.anchor_right = 1.0
	_info.offset_top = 24
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_info)
	_keys = preload("res://scripts/hint_bar.gd").new()  # näppäinohjeet hattuina, näppäimet asetuksista
	_keys.compact = true
	_keys.centered = true
	_hud.add_child(_keys)


# --- Mallit ---------------------------------------------------------------------------------------------------------

## Sähkötrimmeri (paikallinen -z = terän suunta, juuri origossa): keltainen runko, musta alaosa ja tuuletusraot,
## savunharmaa käsisuoja, teräslevy hampaineen (hampaat liikkuvat käydessä), etukahvan kaari, takakahva ja liipaisin,
## johto roikkuu takaa. Hanskat ja hihat seuraavat kahvoja.
func _build_trimmer() -> void:
	_trim = Node3D.new()
	add_child(_trim)
	var yellow := Color(0.96, 0.7, 0.1)
	var dark := Color(0.12, 0.12, 0.13)
	var steel := Color(0.72, 0.74, 0.78)
	B.mesh(_trim, B.boxm(Vector3(0.11, 0.075, 0.3)), Vector3(0, 0.01, 0.17), yellow)
	B.mesh(_trim, B.cyl(0.055, 0.055, 0.11, 14), Vector3(0, 0.01, 0.32), yellow, Vector3(0, 0, PI / 2.0))
	B.mesh(_trim, B.boxm(Vector3(0.1, 0.045, 0.32)), Vector3(0, -0.045, 0.17), dark)
	for k in 5:  # tuuletusraot molemmin puolin
		for sx in [-1.0, 1.0]:
			B.mesh(_trim, B.boxm(Vector3(0.004, 0.04, 0.008)), Vector3(sx * 0.056, 0.015, 0.08 + k * 0.025), Color(0.1, 0.08, 0.04), Vector3(0.4, 0, 0))
	B.mesh(_trim, B.boxm(Vector3(0.06, 0.012, 0.004)), Vector3(0.056, 0.03, 0.24), dark, Vector3(0, PI / 2.0, 0))  # tarra
	var guard := B.mesh(_trim, B.boxm(Vector3(0.17, 0.14, 0.005)), Vector3(0, 0.0, 0.0), Color(0.25, 0.28, 0.32))
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22, 0.25, 0.3, 0.6)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.2
	guard.material_override = gm
	_blade_mat = StandardMaterial3D.new()
	_blade_mat.albedo_color = steel
	_blade_mat.metallic = 0.8
	_blade_mat.roughness = 0.3
	var blade := B.mesh(_trim, B.boxm(Vector3(0.05, 0.005, BLADE)), Vector3(0, -0.01, -BLADE / 2.0 - 0.01), steel)
	blade.material_override = _blade_mat
	B.mesh(_trim, B.boxm(Vector3(0.016, 0.014, BLADE)), Vector3(0, -0.002, -BLADE / 2.0 - 0.01), dark)  # selkäkisko
	B.mesh(_trim, B.boxm(Vector3(0.024, 0.02, 0.03)), Vector3(0, -0.006, -BLADE - 0.015), dark)  # kärkisuoja
	_teeth = Node3D.new()
	_trim.add_child(_teeth)
	var n := int(BLADE / 0.034)
	for k in n:
		for sx in [-1.0, 1.0]:
			var tooth := B.mesh(_teeth, B.boxm(Vector3(0.024, 0.004, 0.012)), Vector3(sx * 0.034, -0.01, -0.03 - k * 0.034), steel.darkened(0.15))
			tooth.material_override = _blade_mat
	var bow := [Vector3(-0.075, -0.02, 0.06), Vector3(-0.07, 0.09, 0.06), Vector3(-0.03, 0.13, 0.06), Vector3(0.03, 0.13, 0.06),
		Vector3(0.07, 0.09, 0.06), Vector3(0.075, -0.02, 0.06)]
	for k in bow.size() - 1:  # etukahvan kaari rungon yli
		B.tube(_trim, bow[k], bow[k + 1], 0.014, dark)
	var rear := [Vector3(0, 0.04, 0.34), Vector3(0, 0.11, 0.38), Vector3(0, 0.11, 0.5), Vector3(0, 0.02, 0.52), Vector3(0, -0.04, 0.44)]
	for k in rear.size() - 1:
		B.tube(_trim, rear[k], rear[k + 1], 0.017, dark)
	B.mesh(_trim, B.boxm(Vector3(0.016, 0.03, 0.03)), Vector3(0, 0.08, 0.44), Color(0.85, 0.15, 0.1))  # liipaisin
	var cord := [Vector3(0, -0.03, 0.5), Vector3(0.03, -0.25, 0.56), Vector3(0.08, -0.6, 0.5), Vector3(0.1, -1.2, 0.4)]
	for k in cord.size() - 1:
		B.tube(_trim, cord[k], cord[k + 1], 0.008, Color(0.98, 0.5, 0.08))



func _build_paivi() -> void:
	_paivi = Looks.make(self, Looks.PAIVI)
	_paivi.position = Vector3(PAIVI_POS.x, 0, hedge.zc + PAIVI_POS.y)
	_paivi.play("Idle", 0.0)
	_bubble = B.bubble(_paivi, Vector3(0, 2.05, 0))
	_bubble.text = ""


## Oranssi jatkojohto mutkalla aidan yli: pihalta ylös etupintaa, latvan yli ja alas takapintaa.
func _build_cord() -> void:
	_cord_x = start_x
	for tries in 30:
		var x := _rng.randf_range(-9.0, 9.0)
		if hedge.col_at(x) >= 0 and absf(x - start_x) > 2.0 and absf(x - PAIVI_POS.x) > 1.0:
			_cord_x = x
			break
	_cord = Node3D.new()
	add_child(_cord)
	_cord_path(false)


func _cord_path(on_ground: bool, gap := false) -> void:
	for c in _cord.get_children():
		c.queue_free()
	var f: float = hedge.front()
	var bk: float = hedge.back()
	var t: float = hedge.top_at(_cord_x)
	var pts: Array = []
	if on_ground:
		pts = [Vector3(_cord_x - 0.8, 0.02, f + 1.6), Vector3(_cord_x - 0.2, 0.02, f + 0.9), Vector3(_cord_x + 0.4, 0.02, f + 0.5),
			Vector3(_cord_x + 1.2, 0.02, f + 0.6)]
	else:
		pts = [Vector3(_cord_x - 0.7, 0.02, f + 1.5), Vector3(_cord_x - 0.1, 0.02, f + 0.12), Vector3(_cord_x, 0.6, f + 0.04),
			Vector3(_cord_x, t + 0.025, f - 0.05), Vector3(_cord_x + 0.03, t + 0.03, hedge.zc), Vector3(_cord_x + 0.05, t + 0.02, bk + 0.05),
			Vector3(_cord_x + 0.06, 0.4, bk - 0.04), Vector3(_cord_x + 0.3, 0.02, bk - 0.6)]
	for k in pts.size() - 1:
		if gap and k == 3:
			continue  # poikki latvan kohdalta
		B.tube(_cord, pts[k], pts[k + 1], 0.012, Color(0.98, 0.5, 0.08))
	if gap:
		for e in [pts[3], pts[4]]:  # kuparilangat törröttävät katkenneista päistä
			B.tube(_cord, e, e + Vector3(0, 0.015, 0.02), 0.002, Color(0.85, 0.5, 0.25))


## Silpun lehti: litteä suippo lehti (pitkä akseli a, leveys b, normaali n), keskisuoni hieman koholla.
func _leaf_mesh(a: Vector3, b: Vector3, n: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [-a, b * 0.9 - a * 0.1, a, -b * 0.9 - a * 0.1]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for k in tri:
			st.set_normal(n)
			st.add_vertex(pts[k])
	return st.commit()


## Päivin naru: tolpat aidan päissä ja oranssi naru etupinnan edessä narun korkeudella.
func _build_string() -> void:
	var z: float = hedge.front() + 0.07
	var wood := Color(0.6, 0.45, 0.26)
	for sg in hedge.segs:
		for x in [sg[0] - 0.04, sg[1] + 0.04]:
			B.mesh(self, B.boxm(Vector3(0.04, hedge.TARGET + 0.25, 0.04)), Vector3(x, (hedge.TARGET + 0.25) / 2.0 - 0.05, z), wood)
			B.mesh(self, B.cyl(0.0, 0.03, 0.06, 4), Vector3(x, hedge.TARGET + 0.23, z), wood.lightened(0.15))
		B.tube(self, Vector3(sg[0] - 0.04, hedge.TARGET, z), Vector3(sg[1] + 0.04, hedge.TARGET, z), 0.004, Color(1.0, 0.45, 0.05))


func _build_particles() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _leaf_mesh(Vector3(0.022, 0, 0), Vector3(0, 0, 0.009), Vector3.UP)
	mm.instance_count = 700
	mm.visible_instance_count = 0
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_chips = MultiMeshInstance3D.new()
	_chips.multimesh = mm
	_chips.material_override = mat
	_chips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_chips)
	# Linssiin lätsähtäneet silput kameran edessä.
	var sm := MultiMesh.new()
	sm.transform_format = MultiMesh.TRANSFORM_3D
	sm.use_colors = true
	sm.mesh = _leaf_mesh(Vector3(0.5, 0, 0), Vector3(0, 0.2, 0), Vector3.BACK)
	sm.instance_count = 40
	sm.visible_instance_count = 0
	var smat := StandardMaterial3D.new()
	smat.vertex_color_use_as_albedo = true
	smat.vertex_color_is_srgb = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.no_depth_test = true
	smat.render_priority = 10
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_splats = MultiMeshInstance3D.new()
	_splats.multimesh = sm
	_splats.material_override = smat
	_splats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cam.add_child(_splats)
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 60
	_sparks.lifetime = 0.6
	_sparks.explosiveness = 0.95
	_sparks.direction = Vector3(0, 1, 0.4)
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 1.5
	_sparks.initial_velocity_max = 4.0
	_sparks.gravity = Vector3(0, -9.0, 0)
	_sparks.scale_amount_min = 0.5
	var sp := SphereMesh.new()
	sp.radius = 0.008
	sp.height = 0.016
	var spm := StandardMaterial3D.new()
	spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spm.albedo_color = Color(1.0, 0.85, 0.35)
	spm.emission_enabled = true
	spm.emission = Color(1.0, 0.7, 0.2)
	spm.emission_energy_multiplier = 4.0
	sp.material = spm
	_sparks.mesh = sp
	add_child(_sparks)


# --- Ohjaus ---------------------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw = clampf(_yaw - event.relative.x * SENS, -0.9, 0.9)
		_pitch = clampf(_pitch - event.relative.y * SENS, -1.0, 0.55)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_lmb = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_lift_cord()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish("kesken")
		return
	_say_t -= delta
	if _say_t <= 0.0:
		_bubble.text = ""
		_paivi.play("Idle")
	_shake = maxf(0.0, _shake - delta * 3.0)
	match _phase:
		"leikkaa":
			var ax := Input.get_axis("left", "right")
			_x = clampf(_x + ax * WALK * delta * (0.6 if _lmb else 1.0), -9.8, 9.8)
			_walking = lerpf(_walking, absf(ax), 1.0 - exp(-8.0 * delta))
			_bob += delta * 9.0 * _walking
			_place_camera()
			_trim_tick(delta)
		"johto":
			_motor.on = false
			# Katse kääntyy katkenneeseen kohtaan, ja teippi kiertyy sen ympärille.
			var cut := Vector3(_cord_x, hedge.top_at(_cord_x) + 0.03, hedge.front() - 0.05)
			var to := cut - _cam.position
			_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), 1.0 - exp(-5.0 * delta))
			_pitch = lerpf(_pitch, atan2(to.y, Vector2(to.x, to.z).length()), 1.0 - exp(-5.0 * delta))
			_place_camera()
			if _tape > 0.0:
				if _tape_mi == null:
					_tape_mi = B.mesh(self, B.cyl(0.016, 0.016, 1.0, 10), cut, Color(0.06, 0.06, 0.07), Vector3(PI / 2.0, 0, 0))
				_tape_mi.scale = Vector3(1, minf(_tape / TAPE_TIME, 1.0) * 0.08 + 0.005, 1)
			if Input.is_action_pressed("interact"):
				_tape += delta
				if fmod(_tape, 0.4) < delta:
					Sfx.play("cloth", -8.0, 1.3 + _rng.randf() * 0.3)
				if _tape >= TAPE_TIME:
					_tape = 0.0
					_cord_on = false
					_cord_path(true)
					B.mesh(_cord, B.cyl(0.013, 0.013, 0.05, 10), Vector3(_cord_x - 0.2, 0.025, hedge.front() + 0.9), Color(0.06, 0.06, 0.06),
						Vector3(0, 0, PI / 2.0))  # teippi
					_phase = "leikkaa"
					if _tape_mi != null:
						_tape_mi.queue_free()
						_tape_mi = null
					_say(LINES.taped.pick_random(), 2.5)
		"valmis":
			_motor.on = false
			_end_t += delta
			_pitch = lerpf(_pitch, -0.35, 1.0 - exp(-2.0 * delta))
			_place_camera()
			if _end_t > 3.2:
				_finish("ok")
				return
	_paivi_face()
	var down: Vector3 = _body.transform.basis.inverse() * -_trim.basis.y
	_grip("l", down)
	_grip("r", down)
	_step_particles(delta)
	_info.text = _status()
	if _phase == "johto":
		_keys.set_text("%s pidä pohjassa: teippaa johto   %s lopeta" % [Settings.cap("interact"), Settings.cap("mount")])
	else:
		_keys.set_text("Hiiri katsoo ja tähtää · vasen nappi leikkaa · oikea nostaa johdon   %s kävele   %s lopeta" % [
			Settings.pair("left", "right"), Settings.cap("mount")])


## Kamera silmien korkeudelle aidan eteen; humala huojuttaa, kävely keinuttaa, leikkuu tärisyttää. Trimmeri ja kädet
## seuraavat: terä vaakatasossa katseen ja aidan etupinnan leikkauskohdan korkeudella.
func _place_camera() -> void:
	var sway := Vector2(sin(_t * 1.7) * 0.6 + sin(_t * 4.3) * 0.4, cos(_t * 1.3) * 0.7 + sin(_t * 3.1) * 0.3) * drunk * 0.05
	var shk := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake * 0.006
	var bob := Vector3(sin(_bob) * 0.02, absf(cos(_bob)) * 0.025, 0) * _walking
	var eye := Vector3(_x, EYE, hedge.front() + STAND) + bob + shk
	_cam.position = eye
	_cam.rotation = Vector3(_pitch + sway.y, _yaw + sway.x, 0)
	var dir := -_cam.transform.basis.z
	var f: float = hedge.front()
	var hit := eye + dir * 3.0
	if dir.z < -0.05:
		hit = eye + dir * minf((f - eye.z) / dir.z, 6.0)
	_aim = hit
	_blade_y = clampf(hit.y, 0.35, 2.25)
	_aim.y = _blade_y
	var flat := Vector3(dir.x, 0, dir.z).normalized() if absf(dir.x) + absf(dir.z) > 0.01 else Vector3.FORWARD
	var right := _cam.transform.basis.x
	# Trimmeri lähtee rinnan edestä (takakahva) kohti tähtäyspistettä: terä nousee vinosti aitaan kuin Doomin saha.
	var grip := eye + Vector3(0, -0.55, 0) + right * 0.28 + flat * 0.15
	var bd := (_aim - grip).normalized()
	_trim.basis = Basis.looking_at(bd, Vector3.UP)
	_trim.position = _aim - bd * ROOT
	if _motor.on:
		_trim.position += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 0.003 * (1.0 + _strain * 2.0)
		_teeth.position.z = 0.006 if int(_t * 50.0) % 2 == 0 else -0.006
	# Teipatessa ja lopuksi trimmeri lasketaan alas, ettei se peitä näkymää.
	_lower = lerpf(_lower, 0.0 if _phase == "leikkaa" else 1.0, 1.0 - exp(-4.0 * get_process_delta_time()))
	_trim.position += Vector3(0, -0.55, 0.15) * _lower
	# Oma hahmo seisoo kameran kohdalla (pää piilossa): sen omat kädet kahvoihin IK:lla. Vasen käsi etukahvan
	# kaaren päälle, oikea takakahvaan; kyynärpäät alas ja sivuille.
	_body.position = Vector3(eye.x, 0, eye.z) - flat * 0.12 - bob - shk
	_body.rotation.y = atan2(-flat.x, -flat.z)
	var inv := _body.transform.affine_inverse()
	var up := _trim.basis.y
	var lh: Vector3 = _trim.transform * Vector3(-0.01, 0.13, 0.06) - bd * 0.05 + up * 0.03
	var rh: Vector3 = _trim.transform * Vector3(0, 0.11, 0.45) - bd * 0.06 + up * 0.02
	_body.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", inv * lh, inv * (lh - right * 0.45 + Vector3(0, -0.45, 0.1)))
	_body.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * rh, inv * (rh + right * 0.45 + Vector3(0, -0.45, 0.1)))
	var hi: int = _body.skeleton.find_bone("Head")
	if hi >= 0:
		_body.skeleton.set_bone_pose_scale(hi, Vector3.ONE * 0.01)  # pää ei peitä kameraa


func _trim_tick(delta: float) -> void:
	_motor.on = _lmb
	var flat := -_trim.basis.z
	var root := _trim.position
	var f: float = hedge.front()
	var bk: float = hedge.back()
	# Johdon varoitus, kun terä lähestyy aidan päällä olevaa johtoa.
	if _cord_on and absf(_aim.x - _cord_x) < 0.8 and absf(_blade_y - hedge.top_at(_cord_x)) < 0.4:
		if not _cord_warned:
			_cord_warned = true
			_say(LINES.cord_near.pick_random(), 2.5, true)
	elif _cord_on and absf(_aim.x - _cord_x) > 2.0:
		_cord_warned = false
	if not _lmb:
		_strain = lerpf(_strain, 0.0, 1.0 - exp(-6.0 * delta))
		_motor.strain = _strain
		_prev_range = Vector2.INF
		return
	# Terän pisteet aidan sisällä: niiden x-väli (ja edellisen ruudun väli, pyyhkäisy) leikataan.
	var xa := INF
	var xb := -INF
	var side_hits: Array = []
	for k in 12:
		var p := root + flat * (0.02 + (BLADE - 0.02) * k / 11.0)
		if p.z <= f + 0.03 and p.z >= bk:
			xa = minf(xa, p.x - 0.02)
			xb = maxf(xb, p.x + 0.02)
		var sh: Array = hedge.cut_side(p)
		if not sh.is_empty():
			side_hits.append(sh)
	var removed := 0.0
	if xa <= xb:
		var ra := xa
		var rb := xb
		if _prev_range != Vector2.INF:
			ra = minf(ra, _prev_range.x)
			rb = maxf(rb, _prev_range.y)
		_prev_range = Vector2(xa, xb)
		var ct: float = hedge.top_at(_cord_x)
		if _cord_on and _cord_x >= ra - 0.06 and _cord_x <= rb + 0.06 and _blade_y <= ct + 0.04 and ct - _blade_y <= BITE:
			_cut_cord(Vector3(_cord_x, ct + 0.03, f - 0.1))
			return
		var res: Dictionary = hedge.cut_range(ra, rb, _blade_y, BITE, _cord_x if _cord_on else INF)
		removed += res.removed
		var at: Array = res.at
		for x in at:
			if _rng.randf() < 0.45:
				_spawn_chip(Vector3(x, _blade_y + 0.01, _rng.randf_range(f - 0.4, f)), _rng.randf() < 0.3)
		if not at.is_empty() and _snap_t <= 0.0 and res.removed > 0.02:
			_snap_t = 0.15
			Sfx.play("rattle", -22.0, 2.2 + _rng.randf() * 0.4)
		if res.holes > 0 and _t - _hole_t > 1.5:  # yksi kolo per vetäisy, ei per ruutu
			_hole_t = _t
			holes += 1
			_shake = 1.0
			Sfx.play("rattle_hard", -10.0, 0.9)
			_say(LINES.hole.pick_random(), 3.0, true)
	else:
		_prev_range = Vector2.INF
	for sh in side_hits:
		removed += 0.1
		Sfx.play("rattle", -12.0, 1.8)
		for k in 16:
			_spawn_chip(Vector3(sh[0] + _rng.randf_range(-0.05, 0.05), sh[1] + _rng.randf_range(-0.04, 0.04), f + _rng.randf_range(0.0, sh[2])), true)
	_snap_t -= delta
	_strain = lerpf(_strain, clampf(removed * 14.0, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	_motor.strain = _strain
	_shake = maxf(_shake, _strain * 0.8)
	# Päivi: puolivälissä kehu, valmiin latvan jälkeen kylkiversot, välillä yleistä patistusta.
	var share: float = hedge.level_share()
	if share > 0.5 and not _half_said:
		_half_said = true
		_say(LINES.half.pick_random(), 2.5)
	_nag_t -= delta
	if _nag_t <= 0.0 and _say_t < -1.0:
		_nag_t = _rng.randf_range(9.0, 14.0)
		_say(LINES.nag.pick_random(), 2.8)
	if share >= DONE_SHARE and hedge.sides_left() > 0 and not _sides_said:
		_sides_said = true
		_say(LINES.sides.pick_random(), 3.0)
	if share >= DONE_SHARE and hedge.sides_left() == 0 and hedge.shoots_ok():
		_phase = "valmis"
		_lmb = false
		Sfx.play("win_small", -4.0)
		_say((LINES.done_holes if holes > 0 else LINES.done).pick_random(), 3.2)


func _status() -> String:
	match _phase:
		"johto":
			return "JOHTO POIKKI! Teippaa: %d %%" % roundi(_tape / TAPE_TIME * 100.0)
		"valmis":
			return "Pensasaita leikattu!" + (" (koloja %d)" % holes if holes > 0 else "")
	return "Narun tasalla %d %% · kylkiversoja %d · koloja %d%s" % [roundi(hedge.level_share() * 100.0), hedge.sides_left(), holes,
		" · johto aidan päällä!" if _cord_on else ""]


func _lift_cord() -> void:
	if not _cord_on or _phase != "leikkaa":
		return
	if Vector2(_aim.x - _cord_x, _aim.y - hedge.top_at(_cord_x)).length() > 0.45:
		return
	_cord_on = false
	_cord_path(true)
	Sfx.play("cloth", -6.0, 0.9)
	_say(LINES.cord_off.pick_random(), 2.0)


func _cut_cord(at: Vector3) -> void:
	_phase = "johto"
	_lmb = false
	_tape = 0.0
	_motor.on = false
	_shake = 2.0
	_cord_path(false, true)
	Sfx.play("shotgun", -12.0, 2.6)
	Sfx.play("alert", -10.0, 1.2)
	_sparks.position = at
	_sparks.restart()
	_sparks.emitting = true
	_say(LINES.cord_cut.pick_random(), 3.5, true)


## Ote kahvasta: kämmen kohti kahvaa (trimmerin alas-suunta, down hahmon avaruudessa), sormet kyynärvarren jatkona,
## ja jokainen sormen nivel taipuu kämmenen puolelle kahvan ympäri; peukalo vastakkain. Ajetaan IK:n jälkeen.
func _grip(side: String, down: Vector3) -> void:
	var sk: Skeleton3D = _body.skeleton
	var to_char: Basis = (_body.model.transform * sk.transform).basis
	var to_skel := to_char.inverse()
	var hi := sk.find_bone("hand_" + side)
	var mid := sk.find_bone("middle_01_" + side)
	if hi < 0 or mid < 0:
		return
	var rest := sk.get_bone_global_rest(hi)
	var f_rest := (sk.get_bone_global_rest(mid).origin - rest.origin).normalized()
	var p_rest := Vector3.DOWN  # T-asennossa kämmen alaspäin
	var palm := (to_skel * down).normalized()
	var fore := (sk.get_bone_global_pose(hi).origin - sk.get_bone_global_pose(sk.find_bone("lowerarm_" + side)).origin).normalized()
	var fingers := (fore - palm * fore.dot(palm)).normalized()
	var from := Basis(f_rest, p_rest, f_rest.cross(p_rest).normalized())
	var to := Basis(fingers, palm, fingers.cross(palm).normalized())
	_body._set_global_rot(hi, (to * from.inverse()) * rest.basis)
	for f in ["index", "middle", "ring", "pinky"]:
		for k in [1, 2, 3]:
			var i := sk.find_bone("%s_0%d_%s" % [f, k, side])
			var nxt := sk.find_bone(("%s_0%d_%s" % [f, k + 1, side]) if k < 3 else ("%s_04_leaf_%s" % [f, side]))
			if i < 0 or nxt < 0:
				continue
			sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion())
			var seg := (sk.get_bone_global_pose(nxt).origin - sk.get_bone_global_pose(i).origin).normalized()
			_body._set_global_rot(i, Basis(seg.cross(palm).normalized(), [1.2, 1.3, 0.9][k - 1]) * sk.get_bone_global_pose(i).basis)
	for k in ["02", "03"]:
		var i := sk.find_bone("thumb_%s_%s" % [k, side])
		var tip_b := sk.find_bone(("thumb_03_" + side) if k == "02" else ("thumb_04_leaf_" + side))
		if i < 0 or tip_b < 0:
			continue
		sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion())
		var t_dir := (sk.get_bone_global_pose(tip_b).origin - sk.get_bone_global_pose(i).origin).normalized()
		_body._set_global_rot(i, Basis(t_dir.cross(palm).normalized(), 0.7) * sk.get_bone_global_pose(i).basis)


## Päivin puhe: kupla pään yllä ja puheanimaatio (kiukkuisena nopeampi).
func _say(text: String, t: float, angry := false) -> void:
	_bubble.text = text
	_say_t = t
	_paivi.play("Idle_Talking", 0.2, 1.5 if angry else 1.0)


func _paivi_face() -> void:
	var to := _cam.position - _paivi.position
	_paivi.rotation.y = lerp_angle(_paivi.rotation.y, B.yaw_to(Vector3(to.x, 0, to.z)), 0.1)


func _finish(result: String) -> void:
	if _done:
		return
	_done = true
	_motor.on = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	finished.emit(result)
	queue_free()


# --- Silppu ---------------------------------------------------------------------------------------------------------

## Silppu: osa lentää kohti kameraa (ja lätsähtää linssiin), osa putoaa maahan ja jää aidan juurelle.
func _spawn_chip(at: Vector3, big: bool) -> void:
	if _chip_data.size() >= _chips.multimesh.instance_count:
		var oldest := _chip_data.find_custom(func(c: Array) -> bool: return c[5])
		if oldest < 0:
			return
		_chip_data.remove_at(oldest)
	var toward := _rng.randf() < (0.22 if big else 0.1)
	var v := Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(0.6, 2.2), _rng.randf_range(0.2, 1.4))
	if toward:
		v = (_cam.position - at).normalized() * _rng.randf_range(2.5, 4.0) + Vector3(_rng.randf_range(-0.3, 0.3), 0.6, 0)
	var col := Color(0.24, 0.46, 0.16).lerp(Color(0.55, 0.62, 0.24), _rng.randf() * 0.7)
	if _rng.randf() < 0.18:
		col = Color(0.5, 0.36, 0.2)  # oksanpätkä
	var axis := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
	_chip_data.append([at, v, axis, _rng.randf() * TAU, _rng.randf_range(-14, 14), false, col, toward])


func _step_particles(delta: float) -> void:
	var mm := _chips.multimesh
	for i in range(_chip_data.size() - 1, -1, -1):
		var c: Array = _chip_data[i]
		if c[5]:
			continue
		c[1].y -= 9.0 * delta
		c[1] *= 1.0 - 1.2 * delta  # ilmanvastus: lehti leijailee
		c[0] += c[1] * delta
		c[3] += c[4] * delta
		if c[7] and (c[0] as Vector3).distance_to(_cam.position) < 0.35:
			_splat(c[6])
			_chip_data.remove_at(i)
			continue
		if c[0].y <= 0.015:
			c[0].y = 0.01 + _rng.randf() * 0.01
			c[5] = true
			c[3] = _rng.randf() * TAU
	mm.visible_instance_count = _chip_data.size()
	for i in _chip_data.size():
		var c: Array = _chip_data[i]
		var b := Basis(Vector3.UP, c[3]) if c[5] else Basis(c[2], c[3])
		mm.set_instance_transform(i, Transform3D(b, c[0]))
		mm.set_instance_color(i, c[6])
	# Linssin lätsähdykset valuvat alas ja haihtuvat.
	var sm := _splats.multimesh
	for i in range(_splat_data.size() - 1, -1, -1):
		var s: Array = _splat_data[i]
		s[2] += delta
		s[0].y -= 0.004 * delta
		if s[2] > 3.0:
			_splat_data.remove_at(i)
	sm.visible_instance_count = _splat_data.size()
	for i in _splat_data.size():
		var s: Array = _splat_data[i]
		var col: Color = s[4]
		col.a = clampf(3.0 - s[2], 0.0, 1.0) * 0.95
		sm.set_instance_transform(i, Transform3D(Basis(Vector3.BACK, s[3]).scaled(Vector3.ONE * s[1]), s[0]))
		sm.set_instance_color(i, col)


func _splat(col: Color) -> void:
	if _splat_data.size() >= _splats.multimesh.instance_count:
		_splat_data.remove_at(0)
	var p := Vector3(_rng.randf_range(-0.07, 0.07), _rng.randf_range(-0.03, 0.045), -0.1)
	_splat_data.append([p, _rng.randf_range(0.008, 0.016), 0.0, _rng.randf() * TAU, col.darkened(0.1)])
