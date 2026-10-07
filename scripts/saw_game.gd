extends "res://scripts/kota_minigame.gd"
## Sahaus kodan sahapukilla, FPS-minipeli. Merkkaa tähtäämällä, mistä kohtaa tukki katkaistaan (pölkyn
## mitta), ja sahaa pokasahalla hiiren eteen-taakse-liikkeellä (tai W/S). Kädet ja tuulenpuuskat
## kallistavat sahaa: pidä se suorassa hiiren sivuliikkeellä (tai A/D), muuten saha kiilaa. Liian kiivas
## riuhtominen saa sahan hyppäämään uralta. Raimo ja Veikko kommentoivat mittaa ja sahausta.
## kota.gd:n lapsi sahapukin kohdalla ja kierrossa: tukki on paikallisen Z-akselin suuntainen, pelaaja -X-puolella.

signal sawn

const LOG_Y := 0.88
const R := 0.135
const TUKKI_LEN := 1.6
const END_Z := 1.05  # tukin pää pukin ulkopuolella
const MIN_CUT_Z := 0.5  # pukin jalat z = ±0.4: tätä lähempää ei sahata
const EYE := Vector3(-0.62, 1.6, 0.74)
const STROKE := 0.22  # sahan liike uralla ±
const BIND_TILT := 0.14  # tätä vinommassa saha kiilaa
const RATE := 0.028  # uran syveneminen sahan kulkemaa metriä kohden
const FRANTIC := 2.6  # m/s: tätä kiivaammin saha hyppää uralta

const BARK := Color(0.86, 0.84, 0.79)
const WOOD_A := Color(0.86, 0.74, 0.54)
const WOOD_B := Color(0.77, 0.63, 0.43)
const HEART := Color(0.66, 0.5, 0.32)

const LINES := {
	"start": [["raimo", "Saha on terävä. Viime kesänä teroitettu."],
		["veikko", "Pitkät vedot, ei mitään hätäilyä."],
		["raimo", "Merkkaa ensin mitta. Reilu kolmekymmentä senttiä on hyvä pölkky."]],
	"pukki": [["raimo", "Ei pukin välistä! Pukin ulkopuolelta sahataan."],
		["veikko", "Sahaat kohta pukin poikki. Sitä ei polteta."], ["raimo", "Siinä on pukin jalka. Kauemmas."]],
	"sliver": [["veikko", "Se on lastu, ei pölkky."], ["raimo", "Tuosta ei saa ku tulitikun. Isompi mitta."]],
	"bind": [["raimo", "Saha kiilaa! Suoraan, suoraan."], ["veikko", "Älä väännä, anna sahan tehdä työ."],
		["raimo", "Vinoon menee. Oiota."], ["veikko", "Nyt se jumittaa. Suorista kättä."]],
	"frantic": [["raimo", "Rauhassa! Ei tää oo kilpailu."], ["veikko", "Pitkät ja rauhalliset vedot, sano isäukko."],
		["raimo", "Saha hyppää, ku sää riuhot."], ["veikko", "Ei se nopeammin mene, vaikka kuinka heiluttaa."]],
	"halfway": [["veikko", "Puolivälissä. Samaan malliin."], ["raimo", "Hyvin menee. Vielä puolet."]],
	"perfect_len": [["raimo", "Mittanauhalla ei ois saanu parempaa."], ["veikko", "Täydellinen pölkky. Kerron tästä tarinan."]],
	"good_len": [["raimo", "Hyvä mitta. Mahtuu pesään."], ["veikko", "Juuri sopiva pölkky."],
		["raimo", "Siitä tulee neljä kunnon halkoa."]],
	"short": [["veikko", "Lyhyt tuli. No, palaa lyhytkin."], ["raimo", "Tulitikkuja sahaat?"]],
	"long": [["raimo", "Pitkä pölkky. Ei mahdu pesään ilman halkomista."], ["veikko", "Tuo on jo tukki eikä pölkky."]],
	"crooked": [["raimo", "Vinoon meni. Muista sitte halkoessa kumpi pää alas."],
		["veikko", "Sahasit ku Pekka ampuu. Vähän sinne päin."], ["raimo", "Vino pää. Ei se tulessa haittaa."]],
	"straight": [["veikko", "Suora ku viivotin."], ["raimo", "Suora leikkaus. Ammattimies."]],
	"new_log": [["raimo", "Tukki loppu. Nostetaan uus pinosta."], ["veikko", "Uus tukki pukille. Koivua riittää."]],
	"gust": [["veikko", "Puuska! Pidä saha suorassa."], ["raimo", "Tuulee. Oota että tyyntyy."],
		["veikko", "Tekojärveltä puhaltaa taas."]],
	"idle": [["raimo", "Sahaa, sahaa. Ei se itestään katkea."], ["veikko", "Joko väsyit?"]],
}

var polkyt_made := 0

var _phase := "mark"  # mark | saw | slide
var _back_z := END_Z - TUKKI_LEN
var _end_z := END_Z
var _tukki: Node3D
var _mark: MeshInstance3D
var _kerf: MeshInstance3D
var _saw: Node3D
var _dust: CPUParticles3D
var _cut_z := 0.0
var _depth := 0.0
var _s := 0.0  # sahan paikka uralla
var _s_dir := 0.0
var _s_travel := 0.0  # nykyisen vedon pituus
var _tilt_hand := 0.0
var _tilt := 0.0
var _crook := 0.0
var _travel := 0.0
var _said_half := false
var _bind_cd := 0.0
var _frantic_cd := 0.0
var _hop := 0.0
var _frame_move := 0.0  # tämän ruudun sahausliike (kiivauden mittaus)
var _idle_t := 0.0
var _slide_from := 0.0
var _slide_t := 0.0
var _depth_bar: ProgressBar
var _level: Control
var _level_dot: ColorRect


func _init() -> void:
	eye = EYE
	yaw_center = PI / 2.0  # katse +X:ään, tukin yli kohti kotaa
	_yaw = yaw_center
	_pitch = -0.8
	lines = LINES
	watcher_spots = {"raimo": Vector3(1.6, 0, -0.55), "veikko": Vector3(1.75, 0, 1.35)}
	watch_at = Vector3(0, 0, 0.7)
	help_text = "%s aloita sahaus merkistä   %s sahaa (tai hiiri eteen-taakse)   %s pidä saha suorassa (tai hiiri sivulle)\n%s nosta saha   %s lopeta" % [
		Settings.cap("interact", "Hiiri vasen"), Settings.pair("forward", "back"), Settings.pair("left", "right"),
		Settings.cap("bell", "Hiiri oikea"), Settings.cap("mount")]


func _start() -> void:
	for n in ["Saw", "SawLog"]:
		var node: Node3D = kota.find_child(n, true, false)
		if node != null:
			node.visible = false
	_tukki = Node3D.new()
	add_child(_tukki)
	_rebuild_tukki()
	_mark = B.mesh(self, B.boxm(Vector3(2.0 * R + 0.02, 0.006, 0.006)), Vector3.ZERO, Color(0.95, 0.95, 0.9))
	_mark.material_override = B.unshaded(Color(0.95, 0.95, 0.9))
	_kerf = B.mesh(self, B.boxm(Vector3(1, 1, 1)), Vector3.ZERO, Color(0.12, 0.08, 0.05))
	_kerf.visible = false
	_build_saw()
	_build_dust()
	_build_meters()
	_say_kind("start")
	_update_task()


# --- Rakennus --------------------------------------------------------------------------

## Koivutukki Z-akselin suuntaisena: kuori ja päädyissä vuosirenkaat. Origo tukin keskellä.
static func tukki_mesh(parent: Node3D, length: float) -> void:
	B.mesh(parent, B.cyl(R, R, length, 16), Vector3.ZERO, BARK, Vector3(90, 0, 0))
	for sz in [-1.0, 1.0]:
		var rings := [[0.97, WOOD_A], [0.62, WOOD_B], [0.3, HEART]]
		for i in rings.size():
			var d := B.mesh(parent, B.cyl(R * rings[i][0], R * rings[i][0], 0.004, 16),
				Vector3(0, 0, sz * (length / 2.0 + 0.001 + i * 0.001)), rings[i][1], Vector3(90, 0, 0))
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _rebuild_tukki() -> void:
	for ch in _tukki.get_children():
		ch.queue_free()
	var len := _end_z - _back_z
	_tukki.position = Vector3(0, LOG_Y, (_back_z + _end_z) / 2.0)
	tukki_mesh(_tukki, len)


## Pokasaha: terä X-akselin suuntainen, terän alareuna origossa. Kahva pelaajan puolella (-X).
func _build_saw() -> void:
	_saw = Node3D.new()
	add_child(_saw)
	var orange := Color(0.95, 0.45, 0.05)
	B.mesh(_saw, B.boxm(Vector3(0.78, 0.035, 0.004)), Vector3(0, 0.0175, 0), Color(0.78, 0.8, 0.83))
	for x in [-0.39, 0.39]:
		B.mesh(_saw, B.cyl(0.017, 0.017, 0.32, 8), Vector3(x, 0.16, 0), orange)
	B.mesh(_saw, B.cyl(0.02, 0.02, 0.8, 8), Vector3(0, 0.32, 0), orange, Vector3(0, 0, 90))
	B.mesh(_saw, B.cyl(0.024, 0.024, 0.16, 10), Vector3(-0.45, 0.08, 0), Color(0.2, 0.2, 0.22), Vector3(0, 0, 90))
	B.mesh(_saw, B.sphere(0.045, 10), Vector3(-0.47, 0.1, 0), Color(0.35, 0.22, 0.12))
	for mi in _saw.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_saw.visible = false


func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.amount = 60
	_dust.lifetime = 0.9
	_dust.emitting = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(R, 0.01, 0.01)
	_dust.direction = Vector3.DOWN
	_dust.spread = 30.0
	_dust.initial_velocity_min = 0.2
	_dust.initial_velocity_max = 0.6
	_dust.gravity = Vector3(0, -4.0, 0)
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.84, 0.66)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	_dust.mesh = q
	add_child(_dust)


## Sahauksen mittarit: uran syvyys ja sahan suoruus (merkki keskellä = suora, reunoilla kiilaa).
func _build_meters() -> void:
	_depth_bar = ProgressBar.new()
	_depth_bar.max_value = 100.0
	_depth_bar.show_percentage = false
	_depth_bar.anchor_left = 0.5
	_depth_bar.anchor_right = 0.5
	_depth_bar.anchor_top = 1.0
	_depth_bar.anchor_bottom = 1.0
	_depth_bar.offset_left = -160
	_depth_bar.offset_right = 160
	_depth_bar.offset_top = -228
	_depth_bar.offset_bottom = -210
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.7, 0.35)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_depth_bar.add_theme_stylebox_override("fill", fill)
	_depth_bar.add_theme_stylebox_override("background", bg)
	_layer.add_child(_depth_bar)
	_level = Control.new()
	_level.anchor_left = 0.5
	_level.anchor_right = 0.5
	_level.anchor_top = 1.0
	_level.anchor_bottom = 1.0
	_level.offset_left = -160
	_level.offset_right = 160
	_level.offset_top = -202
	_level.offset_bottom = -186
	_layer.add_child(_level)
	for spec in [[0.0, 320.0, Color(0.8, 0.15, 0.1, 0.6)], [70.0, 180.0, Color(0.9, 0.75, 0.1, 0.6)],
			[120.0, 80.0, Color(0.2, 0.75, 0.25, 0.7)], [159.0, 2.0, Color(1, 1, 1, 0.9)]]:
		var r := ColorRect.new()
		r.position = Vector2(spec[0], 0)
		r.size = Vector2(spec[1], 16)
		r.color = spec[2]
		_level.add_child(r)
	_level_dot = ColorRect.new()
	_level_dot.size = Vector2(8, 22)
	_level_dot.position = Vector2(156, -3)
	_level_dot.color = Color.WHITE
	_level.add_child(_level_dot)
	var cap := Label.new()
	cap.text = "Suoruus"
	cap.add_theme_font_size_override("font_size", 16)
	cap.add_theme_color_override("font_outline_color", Color.BLACK)
	cap.add_theme_constant_override("outline_size", 6)
	cap.position = Vector2(-80, -2)
	_level.add_child(cap)
	_depth_bar.visible = false
	_level.visible = false


# --- Kulku -----------------------------------------------------------------------------

func _update_task() -> void:
	match _phase:
		"mark":
			_task.text = "Tähtää tukkiin ja merkkaa, mistä katkaistaan (pölkyn mitta)"
		"saw":
			_task.text = "Sahaa pitkin vedoin ja pidä saha suorassa"
		_:
			_task.text = ""
	_set_crosshair(_phase == "mark")
	mouse_aims = _phase == "mark"
	_depth_bar.visible = _phase == "saw"
	_level.visible = _phase == "saw"
	_saw.visible = _phase == "saw"


func _action() -> void:
	if _phase != "mark":
		return
	var p := _ray_plane(LOG_Y + R)
	if absf(p.x) > R * 1.5 or p.z < _back_z or p.z > _end_z:
		return
	if p.z < MIN_CUT_Z:
		_say_kind("pukki")
		return
	if _end_z - p.z < 0.1:
		_say_kind("sliver")
		return
	_cut_z = p.z
	_depth = 0.0
	_s = 0.0
	_s_dir = 0.0
	_s_travel = 0.0
	_tilt_hand = 0.0
	_crook = 0.0
	_travel = 0.0
	_said_half = false
	_idle_t = 0.0
	_mark.visible = false
	_phase = "saw"
	Sfx.play("pickup", -8.0, 0.6)
	_update_task()


## Oikea nappi: sahan voi nostaa pois ja merkata uuden kohdan, jos ura on vasta aloitettu.
func _alt_action() -> void:
	if _phase == "saw" and _depth < 0.02:
		_phase = "mark"
		_kerf.visible = false
		_update_task()


func _mouse_moved(rel: Vector2) -> void:
	if _phase != "saw":
		return
	_stroke(-rel.y * 0.9)
	_tilt_hand += rel.x * 0.5


func _gust_comment_ok() -> bool:
	return _phase == "saw"


func _cleanup() -> void:
	for n in ["Saw", "SawLog"]:
		var node: Node3D = kota.find_child(n, true, false)
		if node != null:
			node.visible = true


func _tick(delta: float) -> void:
	_bind_cd -= delta
	_frantic_cd -= delta
	_count.text = "Sahattu %d pölkkyä" % polkyt_made
	match _phase:
		"mark":
			_update_mark()
		"saw":
			# Näppäimet: W/S vetää sahaa tasaiseen tahtiin, A/D oikaisee.
			var k := Input.get_axis("back", "forward")
			if k != 0.0:
				_stroke(k * 1.3 * delta)
			_tilt_hand += Input.get_axis("left", "right") * 0.4 * delta
			_update_saw(delta)
		"slide":
			_slide_t += delta / 0.6
			var f := ease(minf(_slide_t, 1.0), -2.0)
			var shift := (END_Z - _slide_from) * f
			_tukki.position.z = (_back_z + _slide_from) / 2.0 + shift
			if _slide_t >= 1.0:
				_back_z += END_Z - _slide_from
				_end_z = END_Z
				if _end_z - _back_z < 0.75:
					_back_z = END_Z - TUKKI_LEN
					Sfx.play("rattle_hard", -6.0, 0.7)
					_say_kind("new_log")
				_rebuild_tukki()
				_phase = "mark"
				_update_task()
	# Kamera katsoo sahatessa uraa, merkatessa hiiri tähtää vapaasti.
	if _phase == "saw":
		var want := _aim_to(Vector3(0.05, LOG_Y + R, _cut_z))
		_yaw = lerp_angle(_yaw, want.x, 1.0 - exp(-6.0 * delta))
		_pitch = lerpf(_pitch, want.y, 1.0 - exp(-6.0 * delta))


func _update_mark() -> void:
	var p := _ray_plane(LOG_Y + R)
	var on_log := absf(p.x) < R * 1.5 and p.z > _back_z and p.z < _end_z
	_mark.visible = on_log
	if not on_log:
		_task.text = "Tähtää tukkiin ja merkkaa, mistä katkaistaan (pölkyn mitta)"
		return
	_mark.position = Vector3(0, LOG_Y + R + 0.004, p.z)
	var ok := p.z >= MIN_CUT_Z and _end_z - p.z >= 0.1
	(_mark.material_override as StandardMaterial3D).albedo_color = Color(0.95, 0.95, 0.9) if ok else Color(1, 0.3, 0.2)
	_task.text = "Pölkyn pituus %d cm  ·  %s tai hiiri: aloita sahaus" % [roundi((_end_z - p.z) * 100.0), Settings.action_key("interact")] if ok \
		else "Pukin välistä ei sahata" if p.z < MIN_CUT_Z else "Liian lyhyt"


## Sahan liike uralla: syventää uraa, jos saha on suorassa eikä liike ole liian kiivas.
func _stroke(ds: float) -> void:
	if _phase != "saw" or _hop > 0.0:
		return
	var binding := absf(_tilt) > BIND_TILT
	if binding:
		ds *= 0.25  # kiilaava saha liikkuu jäykästi
	var ns := clampf(_s + ds, -STROKE, STROKE)
	var moved := absf(ns - _s)
	if moved < 0.0001:
		return
	var dir := signf(ns - _s)
	if dir != _s_dir:
		if _s_travel > 0.08:
			Sfx.play("saw", -4.0 if not binding else -10.0, randf_range(0.9, 1.1) * (0.8 if binding else 1.0))
		_s_dir = dir
		_s_travel = 0.0
	_s_travel += moved
	_s = ns
	_idle_t = 0.0
	_frame_move += moved
	if binding:
		if randf() < 0.1:
			Sfx.play("pedal_squeak", -14.0, randf_range(0.6, 0.8))
		if _bind_cd <= 0.0:
			_bind_cd = 6.0
			_say_kind("bind")
		return
	var straight := 1.0 - pow(absf(_tilt) / BIND_TILT, 2.0) * 0.6
	_depth += moved * RATE * straight
	_crook += absf(_tilt) * moved
	_travel += moved
	_dust.emitting = true
	_dust.set_meta("t", 0.15)


func _update_saw(delta: float) -> void:
	# Kädet huojuvat ja puuska kallistaa sahaa; pelaaja oikaisee.
	var drift := 0.05 * sin(_t * 0.63) + 0.035 * sin(_t * 1.7 + 1.1) + 0.012 * sin(_t * 4.3)
	_tilt_hand = clampf(_tilt_hand, -0.5, 0.5)
	_tilt = _tilt_hand + drift + _gust_offset().x * 3.0
	_hop = maxf(0.0, _hop - delta)
	if _frame_move / maxf(delta, 0.001) > FRANTIC and _depth > 0.01 and _hop <= 0.0:
		# Riuhtominen: saha hyppää uralta hetkeksi, ja ura mataloituu vähän.
		_hop = 0.5
		_shake = 0.7
		_depth = maxf(0.0, _depth - 0.004)
		Sfx.play("whoosh", -6.0, 1.4)
		if _frantic_cd <= 0.0:
			_frantic_cd = 6.0
			_say_kind("frantic")
	_frame_move = 0.0
	var dt: float = _dust.get_meta("t", 0.0) - delta
	_dust.set_meta("t", dt)
	if dt <= 0.0:
		_dust.emitting = false
	_dust.position = Vector3(0, LOG_Y - R, _cut_z)
	# Terä: alareuna uran pohjassa, kallistus X-akselin ympäri. Hypätessä terä nousee uralta.
	var hop_y := 0.04 * sin(PI * _hop / 0.5) if _hop > 0.0 else 0.0
	_saw.position = Vector3(_s, LOG_Y + R - _depth + hop_y, _cut_z)
	_saw.rotation = Vector3(_tilt, 0, 0)
	_kerf.visible = _depth > 0.002
	var dc := minf(_depth, R)
	_kerf.scale = Vector3(2.0 * sqrt(dc * (2.0 * R - dc)) + 0.004, _depth, 0.005)  # uran leveys = jänne syvyydellä
	_kerf.position = Vector3(0, LOG_Y + R - _depth / 2.0, _cut_z)
	_depth_bar.value = _depth / (2.0 * R) * 100.0
	var dot := clampf(_tilt / (BIND_TILT * 2.0), -1.0, 1.0)
	_level_dot.position.x = 156.0 + dot * 156.0
	_level_dot.color = Color.WHITE if absf(_tilt) < BIND_TILT * 0.5 else (Color(1, 0.85, 0.2) if absf(_tilt) < BIND_TILT else Color(1, 0.3, 0.2))
	_idle_t += delta
	if _idle_t > 12.0:
		_idle_t = 0.0
		_say_kind("idle")
	if not _said_half and _depth > R:
		_said_half = true
		if randf() < 0.4:
			_say_kind("halfway")
	if _depth >= 2.0 * R * 0.97:
		_cut_through()


## Pölkky katkeaa ja putoaa maahan, tukki työnnetään pukilla eteenpäin.
func _cut_through() -> void:
	var len := _end_z - _cut_z
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 16  # vain maasto: pukin törmäyslaatikko on tukin ympärillä
	body.mass = 6.0
	body.continuous_cd = true
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = R
	shape.height = len
	cs.shape = shape
	cs.rotation.x = PI / 2.0
	body.add_child(cs)
	var vis := Node3D.new()
	body.add_child(vis)
	tukki_mesh(vis, len)
	body.position = Vector3(0, LOG_Y, _cut_z + len / 2.0)
	add_child(body)
	body.linear_velocity = Vector3(randf_range(-0.2, 0.2), -0.3, 0.4)
	body.angular_velocity = Vector3(randf_range(1.5, 3.0), 0, randf_range(-1.0, 1.0))
	_add_debris(body, 6.0)
	Sfx.play("rattle_hard", -3.0, 0.8)
	_kerf.visible = false
	_dust.emitting = false
	polkyt_made += 1
	sawn.emit()
	var crooked := _crook / maxf(_travel, 0.001) > 0.06
	if crooked:
		_say_kind("crooked")
	elif len >= 0.33 and len <= 0.39:
		_say_kind("perfect_len")
	elif len < 0.25:
		_say_kind("short")
	elif len > 0.5:
		_say_kind("long")
	elif randf() < 0.3:
		_say_kind("straight")
	else:
		_say_kind("good_len")
	# Tukki lyhenee katkaisukohtaan ja liukuu pukilla eteen.
	_end_z = _cut_z
	_rebuild_tukki()
	_slide_from = _end_z
	_slide_t = 0.0
	_phase = "slide"
	_update_task()
