extends Node3D
## Oman mopon potkukäynnistys autotallissa (#155), pelataan tallin oikealla mopolla: pelaajan hahmo seisoo mopon
## vasemmalla puolella vasen käsi tangossa ja oikea satulalla, oikea jalka nousee potkupolkimelle ja potkaisee.
## Kylmä 70-luvun kaksitahtinen: rikastin päälle ([S]), potkun voima ladataan pitämällä [E] pohjassa (mittari heiluu
## ylös ja alas) ja potkaistaan päästämällä irti. Vihreällä potkulla kylmä kone köhäisee rikastimella; kahden
## köhäisyn jälkeen rikastin pois ja vielä yksi hyvä potku, niin mopo lähtee: pakoputki savuaa sinistä, mopo
## tärisee ja ajovalo syttyy. Rikastin päällä liian kauan kastelee tulpan, punaisella potkupoljin potkaisee
## takaisin nilkkaan, ja Päivi tulee talliin kommentoimaan. Humalassa mittari heiluu arvaamattomasti.
## F / Esc lopettaa kesken. Solmu lisätään tallin (garage_interior.gd) lapseksi; mopo = tallin mopon malli.

signal finished(success: bool)
signal comment(text: String)

const MG := preload("res://scripts/mg_draw.gd")
const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const TwoStroke := preload("res://scripts/two_stroke.gd")

const MAX_KICKS := 16
const GREEN := Vector2(0.62, 0.86)
const RED := 0.93
const COUGHS := 2
## Mopon mallin avaruudessa (mopo.gd build_model, keula -Z): potkupoljin vasemmalla kyljellä moottorin takana,
## pakoputken pää, ajovalo, vasen kahva ja satula. Pelaaja seisoo vasemmalla kasvot keulan suuntaan.
const PEDAL_PIVOT := Vector3(-0.17, 0.36, 0.12)
const PEDAL_L := 0.26
const PEDAL_REST := 0.45  # rad, pää ylhäällä
const EXHAUST := Vector3(0.12, 0.3, 0.8)
const LAMP := Vector3(0, 0.95, -0.69)
const GRIP_L := Vector3(-0.3, 1.08, -0.46)
const SEAT_HAND := Vector3(-0.06, 0.9, 0.05)
const STAND := Vector3(-0.5, 0, 0.12)
const PAIVI_LINES := ["Joko se romu lähtee, vai soitanko Pekalle?", "Naapurit luulee, että täällä teurastetaan jotain!",
	"Sää potkit tota kovemmin ku nurmikkoa koskaan leikkaat.", "Jos tuo lähtee käyntiin, mää syön hattuni.",
	"Oisit vaan ostanu bussikortin."]
const FAIL_LINES := ["Pöh.", "Ei mitään. Mopo katsoo sinua pettyneenä.", "Pöhöhö... ei.", "Kone hiljaa kuin Seppo maanantaina."]

var drunk := 0.0
var mopo: Node3D  # tallin mopo (garage_interior.gd _mopo)
var walker: Node3D  # tallin kävelijä: piiloon pelin ajaksi

var _hud: CanvasLayer
var _ui: Control
var _info: Label
var _say: Label
var _keys: Control
var _t := 0.0
var _done := false
var _choke := false
var _coughs := 0
var _kicks := 0
var _charge := 0.0  # 0..1 potkun voima
var _phase := 0.0
var _holding := false
var _kick_anim := 0.0  # 1 -> 0: jalka alas, poljin painuu
var _shake := 0.0
var _word := ""  # PÖH!, AIJAI!, PÖRPÖRPÖR
var _word_t := 0.0
var _paivi_t := 0.0
var _running := false
var _run_t := 0.0
var _engine: TwoStroke  # syntetisoitu kaksitahtipärinä
var _haze: CPUParticles3D  # talliin kertyvä sininen huuru
var _fog: ColorRect  # huurun sävy koko kuvaan
var _paivi_state := ""  # "" / "yskii" / "lahtee" / "poissa"
var _tip_t := 0.0

var _rig: Node3D  # mopon mallin avaruus tallissa
var _mopo_pos := Vector3.ZERO
var _pedal: Node3D
var _player: Node3D
var _paivi: Node3D
var _smoke: CPUParticles3D
var _smoke_mat: StandardMaterial3D
var _lamp: OmniLight3D
var _lamp_glass: MeshInstance3D
var _cam: Camera3D


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	if walker != null:
		walker.visible = false
	_mopo_pos = mopo.position
	_rig = Node3D.new()
	_rig.transform = mopo.transform
	add_child(_rig)
	_build_pedal()
	_build_smoke()
	_lamp_glass = B.mesh(_rig, B.cyl(0.075, 0.075, 0.02, 14), LAMP, Color(0.75, 0.75, 0.66), Vector3(90, 0, 0))
	_lamp_glass.material_override = _lamp_glass.material_override.duplicate()  # oma materiaali: hehkuu käydessä
	_lamp = OmniLight3D.new()
	_lamp.position = LAMP + Vector3(0, 0, -0.15)
	_lamp.light_color = Color(1.0, 0.95, 0.75)
	_lamp.omni_range = 4.0
	_lamp.light_energy = 0.0
	_rig.add_child(_lamp)
	_player = Looks.make(_rig, Looks.player())
	Looks.add_cap(_player)
	_player.position = STAND
	_player.play("Idle", 0.0)
	_paivi = Looks.make(self, Looks.PAIVI)
	_paivi.position = Vector3(0.3, 0, 1.7)  # tullut ovelta mopon eteen, katsoo pelaajaa
	_paivi.rotation.y = -1.0
	_paivi.play("Idle_Talking", 0.0)
	_paivi.visible = false
	_cam = Camera3D.new()
	_cam.fov = 52.0
	add_child(_cam)
	_cam.current = true
	_place_camera()
	_build_hud()
	_engine = TwoStroke.new()
	_engine.volume_db = -2.0
	add_child(_engine)
	_build_haze()
	comment.emit("Kylmä kone. Rikastin päälle (%s), ja potku vihreälle: pidä %s pohjassa ja päästä irti." % [
		Settings.action_key("back"), Settings.action_key("interact")])


func _build_pedal() -> void:
	_pedal = Node3D.new()
	_pedal.position = PEDAL_PIVOT
	_rig.add_child(_pedal)
	var dark := Color(0.18, 0.18, 0.2)
	B.mesh(_pedal, B.cyl(0.03, 0.03, 0.05, 10), Vector3.ZERO, Color(0.6, 0.6, 0.62), Vector3(0, 0, 90))  # akseli
	B.mesh(_pedal, B.boxm(Vector3(0.025, 0.03, PEDAL_L)), Vector3(-0.03, 0, PEDAL_L / 2.0), dark)  # vipu
	B.mesh(_pedal, B.boxm(Vector3(0.11, 0.025, 0.045)), Vector3(-0.08, 0, PEDAL_L), Color(0.1, 0.1, 0.1))  # poljin


func _build_smoke() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.position = EXHAUST
	_smoke.emitting = false
	_smoke.amount = 60
	_smoke.lifetime = 2.2
	_smoke.direction = Vector3(0, 1.0, 0.6)
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 0.4
	_smoke.initial_velocity_max = 1.3
	_smoke.gravity = Vector3(0, 0.45, 0)
	_smoke.damping_min = 0.3
	_smoke.damping_max = 0.6
	_smoke.scale_amount_min = 2.0
	_smoke.scale_amount_max = 6.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.0))
	_smoke.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 8
	sm.rings = 4
	_smoke_mat = StandardMaterial3D.new()
	_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_mat.albedo_color = Color(0.62, 0.7, 0.95, 0.6)
	sm.material = _smoke_mat
	_smoke.mesh = sm
	_rig.add_child(_smoke)


## Talliin kertyvä huuru: isoja läpikuultavia pilviä koko tallin tilavuuteen, pitkä elinikä, joten huuru sakenee
## koko käynnin ajan. Pilvet syttyvät ja hiipuvat pehmeästi (värirampin alfa).
func _build_haze() -> void:
	_haze = CPUParticles3D.new()
	_haze.position = Vector3(0.6, 1.0, 0.5)
	_haze.emitting = false
	_haze.amount = 110
	_haze.lifetime = 12.0
	_haze.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_haze.emission_box_extents = Vector3(3.4, 0.9, 4.0)
	_haze.direction = Vector3(0, 1, 0)
	_haze.spread = 180.0
	_haze.initial_velocity_min = 0.02
	_haze.initial_velocity_max = 0.12
	_haze.gravity = Vector3(0, 0.02, 0)
	_haze.scale_amount_min = 1.6
	_haze.scale_amount_max = 3.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0.7))
	ramp.add_point(0.25, Color(1, 1, 1, 1))
	_haze.color_ramp = ramp
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 5
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.6, 0.68, 0.92, 0.09)
	sm.material = m
	_haze.mesh = sm
	add_child(_haze)


## Pöllähdys pakoputkesta: köhäisy (sininen), kastunut tulppa (musta) tai käynti (jatkuva).
func _puff(black: bool, n: int) -> void:
	_smoke_mat.albedo_color = Color(0.08, 0.08, 0.08, 0.8) if black else Color(0.62, 0.7, 0.95, 0.6)
	_smoke.amount = maxi(n, 8)
	_smoke.explosiveness = 0.85
	_smoke.one_shot = true
	_smoke.restart()


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	_fog = ColorRect.new()  # savun sävy koko kuvaan: sakenee käynnin aikana (mittarit pysyvät sen päällä)
	_fog.anchor_right = 1.0
	_fog.anchor_bottom = 1.0
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.color = Color(0.58, 0.66, 0.9, 0.0)
	_hud.add_child(_fog)
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	_hud.add_child(_ui)
	_info = _label(24, 40.0, false, Color.WHITE)
	_say = _label(26, 84.0, false, Color(1.0, 0.82, 0.86))
	var tip := _label(22, -90.0, true, Color(1.0, 0.9, 0.55))
	comment.connect(func(t: String) -> void: tip.text = t)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	_hud.add_child(_keys)


func _label(size: int, y: float, bottom: bool, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.anchor_right = 1.0
	if bottom:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(l)
	return l


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_ui.queue_redraw()
	_word_t = maxf(0.0, _word_t - delta)
	_paivi_t = maxf(0.0, _paivi_t - delta)
	_kick_anim = maxf(0.0, _kick_anim - delta * 3.0)
	_shake = maxf(0.0, _shake - delta * 2.5)
	_paivi.visible = (_paivi_t > 0.0 or _running) and _paivi_state != "poissa"
	_say.visible = _paivi_t > 0.0
	_pose(delta)
	if _running:
		_run_tick(delta)
		return
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish(false)
		return
	if Input.is_action_just_pressed("back"):
		_choke = not _choke
		Sfx.play("rattle", -10.0, 1.6)
		_word = "RIKASTIN %s" % ("PÄÄLLE" if _choke else "POIS")
		_word_t = 0.9
	# Potkun lataus: mittari heiluu ylös-alas (humalassa epätasaisesti), irti päästäessä potkaistaan.
	var hold := Input.is_action_pressed("interact") and (_holding or Input.is_action_just_pressed("interact"))  # aloittava E ei potkaise
	if hold:
		_holding = true
		var sp := 1.15 + drunk * (0.9 + sin(_t * 5.3) * 0.8)
		_phase += delta * sp
		_charge = 0.5 - 0.5 * cos(_phase * PI)
	elif _holding:
		_holding = false
		_kick(_charge)
		_charge = 0.0
		_phase = 0.0
	_tip_t -= delta
	if _tip_t <= 0.0 and _kicks > 0:
		_tip_t = 6.0
		if _coughs >= COUGHS and _choke:
			comment.emit("Köhii jo! Rikastin pois (%s) ja vielä yksi hyvä potku." % Settings.action_key("back"))
		elif not _choke and _coughs < COUGHS:
			comment.emit("Kylmä kone ei syty ilman rikastinta (%s)." % Settings.action_key("back"))
	_info.text = "Potkukäynnistys · potkuja %d / %d" % [_kicks, MAX_KICKS]
	_keys.set_text("%s potku (pidä ja päästä)   %s rikastin   %s lopeta" % [Settings.cap("interact"), Settings.cap("back"),
		Settings.cap("mount")])


func _kick(power: float) -> void:
	_kicks += 1
	_kick_anim = 1.0
	_shake = 0.35
	Sfx.play("rattle_hard", -6.0, randf_range(0.8, 1.0))
	if power >= RED:
		# Takaisinpotku nilkkaan.
		_word = "AIJAI!"
		_word_t = 1.2
		_shake = 1.0
		Sfx.play("grunt", -2.0, 0.9)
		comment.emit(["Potkupoljin potkaisi takaisin! Nilkka sanoo sanasen.", "AU! Liian kova potku, poljin palasi kuin bumerangi."].pick_random())
	elif power >= GREEN.x and power <= GREEN.y:
		if _coughs >= COUGHS and not _choke:
			_start()
			return
		if _coughs >= COUGHS and _choke:
			_coughs = 1
			_word = "PLÖRTS"
			_word_t = 1.0
			_puff(true, 30)
			_engine.pop(1)
			comment.emit("Rikastin päällä liian kauan: tulppa kastui! Rikastin pois ja yritä uudestaan.")
		elif _choke:
			_coughs += 1
			_word = ["PÖH!", "PÖH-PÖH!"][mini(_coughs - 1, 1)]
			_word_t = 1.0
			Sfx.play("shotgun", -20.0, 2.6)
			_puff(false, 16)
			_engine.pop(2 + _coughs)
			comment.emit("Köhäisi! %s" % ("Vielä kerran." if _coughs < COUGHS else "Nyt rikastin pois (%s)." % Settings.action_key("back")))
		else:
			_word = FAIL_LINES[0]
			_word_t = 0.8
			comment.emit("Ei syty. Kylmä kone haluaa rikastimen.")
	elif power < 0.35:
		_word = "pöh"
		_word_t = 0.8
		comment.emit("Liian laimea potku. Mopo ei edes huomannut.")
	else:
		_word = FAIL_LINES.pick_random() if randf() < 0.5 else "Pöh."
		_word_t = 0.8
		comment.emit("Melkein. Potku vihreälle.")
	if _kicks in [4, 8, 12]:
		_paivi_say(PAIVI_LINES[(int(_kicks / 4.0) - 1 + randi() % 2) % PAIVI_LINES.size()], 3.5)
	if _kicks >= MAX_KICKS:
		comment.emit("Jalka ei enää nouse. Huomenna uudestaan.")
		_finish(false)


func _paivi_say(line: String, t: float) -> void:
	_say.text = "Päivi: \"%s\"" % line
	_paivi_t = t
	_paivi.restart("Idle_Talking", 0.2)


func _start() -> void:
	_running = true
	_word = "PÖRPÖRPÖR!"
	_word_t = 3.0
	_engine.running = true
	_engine.target_rpm = 6000.0
	_engine.throttle = 1.0
	_haze.emitting = true
	Sfx.play("win_small", -4.0)
	_smoke_mat.albedo_color = Color(0.62, 0.7, 0.95, 0.6)
	_smoke.one_shot = false
	_smoke.explosiveness = 0.0
	_smoke.amount = 140  # käydessä tuprutetaan kunnolla
	_smoke.lifetime = 3.5
	_smoke.emitting = true
	_lamp.light_energy = 1.4
	(_lamp_glass.material_override as StandardMaterial3D).emission_enabled = true
	(_lamp_glass.material_override as StandardMaterial3D).emission = Color(1.0, 0.95, 0.7)
	_paivi_say("...No voi hyvä tavaton. Se lähti.", 3.0)
	comment.emit("KÄY! Kaksitahtinen pärisee ja talli täyttyy sinisestä savusta.")


## Käy! Kaasu ryntäilee (pöröröRÖÖÖ), mopo tärisee ja talli täyttyy sinisestä savusta. Kun huurua on tarpeeksi,
## Päivi alkaa yskiä ja lähtee ulos nosturiovesta. Lopuksi valmis.
const RUN_TIME := 8.0
const PAIVI_COUGH_AT := 2.8
const PAIVI_LEAVE_AT := 4.2
const DOOR := Vector3(0.4, 0, 5.2)


func _run_tick(delta: float) -> void:
	_run_t += delta
	# Kaasun ryntäykset: alussa riehutaan, sitten tasainen tyhjäkäynti ja välillä ylpeä ryntäys.
	var blip := fmod(_run_t, 1.1) < 0.4 if _run_t < 3.0 else fmod(_run_t, 2.3) < 0.35
	_engine.target_rpm = 6800.0 if blip else TwoStroke.IDLE
	_engine.throttle = 1.0 if blip else 0.15
	var shake := 0.012 if blip else 0.006
	mopo.position = _mopo_pos + Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)) * shake
	_rig.position = mopo.position
	_fog.color.a = clampf(_run_t / 6.0, 0.0, 1.0) * 0.42
	if _run_t > PAIVI_COUGH_AT and _paivi_state == "":
		_paivi_state = "yskii"
		_paivi_say("KÖH! Köh... Mää en... KÖH... kestä tätä! Koko talo haisee!", 3.0)
		_paivi.restart("Hit_Chest", 0.15)
		for i in 4:
			get_tree().create_timer(i * 0.45).timeout.connect(func() -> void:
				if is_inside_tree():
					Sfx.play("grunt", -6.0, randf_range(1.45, 1.7)))
		comment.emit("Talli on sininen. Päivi yskii.")
	if _run_t > PAIVI_LEAVE_AT and _paivi_state == "yskii":
		_paivi_state = "lahtee"
		_paivi.play("Walk", 0.2)
	if _paivi_state == "lahtee":
		var to := DOOR - _paivi.position
		to.y = 0.0
		if to.length() < 0.2:
			_paivi_state = "poissa"
			Sfx.play("door_close", -6.0, 0.9)
			comment.emit("Päivi lähti yskien sisälle. Mopo pärisee.")
		else:
			_paivi.position += to.normalized() * minf(1.4 * delta, to.length())
			_paivi.rotation.y = lerp_angle(_paivi.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))
	if _run_t > RUN_TIME:
		_finish(true)


func _finish(success: bool) -> void:
	_done = true
	_engine.running = false
	mopo.position = _mopo_pos
	if walker != null:
		walker.visible = true
	finished.emit(success)
	queue_free()


# --- Asento ja kamera ----------------------------------------------------------

## Poljin nousee latauksessa (jalka nostaa polven ylös) ja painuu potkussa; kädet tangossa ja satulalla.
func _pose(_delta: float) -> void:
	var lift := _charge if _holding else 0.0
	var a := PEDAL_REST - _kick_anim * 0.75
	_pedal.rotation.x = a
	var tip := PEDAL_PIVOT + Vector3(-0.08, 0, 0) + Vector3(0, sin(a), cos(a)) * PEDAL_L
	var foot := tip + Vector3(0, 0.06 + lift * 0.28, 0.02)
	var takaisin := _word == "AIJAI!" and _word_t > 0.6
	if takaisin:
		foot += Vector3(-0.15, 0.25, 0.1)  # nilkka sinkoaa ylös
	_player.rotation.x = 0.0
	_player.set_override("spine_01", Vector3.RIGHT, -0.25 - lift * 0.15)
	var inv := _player.transform.affine_inverse()
	_player.set_ik("leg_r", "thigh_r", "calf_r", "foot_r", inv * foot, inv * (foot + Vector3(-0.2, 0.6, -0.8)))
	_player.set_ik("leg_l", "thigh_l", "calf_l", "foot_l", inv * (STAND + Vector3(-0.12, 0.08, 0.05)),
		inv * (STAND + Vector3(-0.2, 0.6, -0.8)))
	_player.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", inv * GRIP_L, inv * (GRIP_L + Vector3(-0.5, 0.2, 0.3)))
	_player.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * SEAT_HAND, inv * (SEAT_HAND + Vector3(0.1, 0.3, 0.4)))
	_place_camera()


## Kamera tallin oikealta etuviistosta: pelaaja ja potkupoljin edessä, Päivi ovella näkyy sivusilmällä.
func _place_camera() -> void:
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.02
	_cam.position = _mopo_pos + Vector3(1.0, 1.9, 2.9) + sh
	_cam.look_at(to_global(_mopo_pos + Vector3(0.1, 0.7, 0.0)), Vector3.UP)


# --- HUD -----------------------------------------------------------------------

func _draw_ui() -> void:
	var sz := _ui.size
	var font := ThemeDB.fallback_font
	if _word_t > 0.0:
		var al := clampf(_word_t * 2.0, 0.0, 1.0)
		var big := _word in ["PÖRPÖRPÖR!", "AIJAI!", "PLÖRTS"]
		var wp := Vector2(sz.x * 0.02, sz.y * 0.36 - (1.0 - al) * 20.0)
		var fs := 60 if big else 42
		_ui.draw_string_outline(font, wp, _word, HORIZONTAL_ALIGNMENT_CENTER, sz.x * 0.4, fs, 10, Color(0, 0, 0, al))
		_ui.draw_string(font, wp, _word, HORIZONTAL_ALIGNMENT_CENTER, sz.x * 0.4, fs,
			Color(1, 0.85, 0.3, al) if _word != "AIJAI!" else Color(1, 0.35, 0.25, al))
	# Potkumittari oikeassa reunassa: vihreä alue, punainen yläpää ja nykyinen voima.
	var g := Rect2(Vector2(sz.x - 90, sz.y * 0.5 - 100), Vector2(44, 200))
	MG.box(_ui, g.grow(6), Color(0.08, 0.08, 0.09, 0.9), 10, 4)
	var to_y := func(v: float) -> float: return g.end.y - g.size.y * v
	_ui.draw_rect(Rect2(Vector2(g.position.x, to_y.call(GREEN.y)), Vector2(g.size.x, g.size.y * (GREEN.y - GREEN.x))), Color(0.3, 0.8, 0.4, 0.85))
	_ui.draw_rect(Rect2(g.position, Vector2(g.size.x, g.size.y * (1.0 - RED))), Color(0.9, 0.2, 0.15, 0.9))
	var cy: float = to_y.call(_charge)
	_ui.draw_rect(Rect2(Vector2(g.position.x, cy), Vector2(g.size.x, g.end.y - cy)), Color(1, 0.85, 0.3, 0.55))
	_ui.draw_line(Vector2(g.position.x - 8, cy), Vector2(g.end.x + 8, cy), Color.WHITE, 4.0)
	_ui.draw_string(font, g.position + Vector2(-40, -14), "POTKU", HORIZONTAL_ALIGNMENT_CENTER, 124, 18, Color.WHITE)
	# Mittaripaneeli: rikastinvipu ja köhäisyt.
	var dash := Rect2(Vector2(sz.x - 330, sz.y * 0.5 - 96), Vector2(210, 192))
	MG.box(_ui, dash, Color(0.12, 0.12, 0.13, 0.9), 12, 4, Color(0.45, 0.45, 0.48), 2)
	MG.sign(_ui, Rect2(dash.position + Vector2(25, 14), Vector2(160, 36)), "RIKASTIN", Color(0.2, 0.22, 0.25), Color.WHITE, 20)
	var lever := dash.position + Vector2(105, 84)
	MG.box(_ui, Rect2(lever + Vector2(-46, -8), Vector2(92, 16)), Color(0.3, 0.3, 0.32), 8)
	MG.ball(_ui, lever + Vector2(34 if _choke else -34, 0), 14.0, Color(0.85, 0.15, 0.1) if _choke else Color(0.55, 0.55, 0.58))
	_ui.draw_string(font, lever + Vector2(-90, 34), "POIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE if not _choke else Color(0.6, 0.6, 0.6))
	_ui.draw_string(font, lever + Vector2(30, 34), "PÄÄLLÄ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE if _choke else Color(0.6, 0.6, 0.6))
	var kr := dash.position + Vector2(18, 166)
	_ui.draw_string(font, kr, "Köhäisyt", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	for i in COUGHS:
		MG.ball(_ui, kr + Vector2(120 + i * 30, -6), 10.0, Color(0.95, 0.8, 0.2) if i < _coughs else Color(0.3, 0.3, 0.3), 0.6)
