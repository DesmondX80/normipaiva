extends Node3D
## Välianimaatiot: WASTED + Päivin motkotus (häviö), makkaranpaisto auringonlaskussa (laavu) ja
## karburaattorin korjaus autotallissa kalja kädessä (kotiinpaluu). play() kutsuu done-kutsua lopuksi.
## Ajastukset reaaliajassa (Engine.time_scale hidastaa vain WASTED-hetken).

const B := preload("res://scripts/build.gd")
const M := preload("res://scripts/map_data.gd")
const Looks := preload("res://scripts/looks.gd")
const Vehicles := preload("res://scripts/vehicles.gd")

const GARAGE_POS := Vector3(0, 0, -3000)
const PAIVI_LINES := {
	"wife": ["No niin. Mihinkäs sitä oltiin menossa?", "Kaljareissulla taas, vai?", "Kuinka monta kertaa pitää sanoa!",
		"Ja kotiin siitä, heti!"],
	"juntti": ["Taas sää oot tapellu jonku kanssa!", "Kaljat maassa ja rahat menny!", "Voi sinua, voi sinua...",
		"Ja kotiin siitä, heti!"],
	"default": ["Missä sää oikein olit?!", "Taas jotain kaljareissuja!", "Pyöräkin on ihan kuramuas!",
		"Nyt riitti, kotiin siitä!"],
	"police": ["Poliisi soitti. POLIISI!", "Siilin yli? Ruohonleikkurilla?!", "Koko kylä puhuu tästä huomenna.",
		"Ja kotiin siitä, heti!"],
	"raahe": ["Missä sää oot ollu koko yön?!", "Raahessa?! Taksilla?!", "Kaljanhaju tuntuu tänne asti!",
		"Huomenna ei tule rahaa kauppaan!"],
}
## Suklaa Päiville motkotuksen aluksi: leppyy (lyhyt ja lempeä) tai ei (motkotus + lisärepliikki).
const CHOCO_OK_LINES := ["...Onks toi mulle?", "No. Tän kerran annetaan anteeks."]
const CHOCO_FAIL_LINE := "Ja luuletko että mut ostetaan suklaalla?"

var env: Environment
var sun: DirectionalLight3D
var busy := false

var _cam: Camera3D
var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _fade: ColorRect
var _band: ColorRect
var _title: Label
var _sub: Label
var _props: Node3D
var _prev_cam: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 1500.0
	add_child(_cam)
	_layer = CanvasLayer.new()
	_layer.layer = 15
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_top = _rect(root, Color.BLACK)
	_bottom = _rect(root, Color.BLACK)
	_band = _rect(root, Color(0, 0, 0, 0.55))
	_fade = _rect(root, Color(0, 0, 0, 0))
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title = _text(root, 150)
	_sub = _text(root, 34)
	_layer.visible = false


func _rect(root: Control, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


func _text(root: Control, size: int) -> Label:
	var l := Label.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Impact", "Arial Black", "Helvetica Neue"]) if size > 60 else PackedStringArray(["Helvetica Neue", "Arial"])
	f.font_weight = 900 if size > 60 else 600
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 18 if size > 60 else 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_right = 1.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func _layout_bars(amount: float) -> void:
	var sz := get_viewport().get_visible_rect().size
	var h := sz.y * 0.11 * amount
	_top.position = Vector2.ZERO
	_top.size = Vector2(sz.x, h)
	_bottom.position = Vector2(0, sz.y - h)
	_bottom.size = Vector2(sz.x, h)
	_band.position = Vector2(0, sz.y * 0.36)
	_band.size = Vector2(sz.x, sz.y * 0.2)
	_title.position = Vector2(0, sz.y * 0.36)
	_title.size = Vector2(sz.x, sz.y * 0.2)
	_sub.position = Vector2(0, sz.y * 0.74)
	_sub.size = Vector2(sz.x, sz.y * 0.12)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


var hide_nodes: Array = []  # pelaajan hahmot piiloon välianimaation ajaksi


func _begin() -> void:
	busy = true
	for n in hide_nodes:
		if is_instance_valid(n):
			n.set_meta("was_visible", n.visible)
	_prev_cam = get_viewport().get_camera_3d()
	_layer.visible = true
	_title.text = ""
	_sub.text = ""
	_band.visible = false
	_fade.color.a = 0.0
	_layout_bars(0.0)
	var tw := _tween()
	tw.tween_method(_layout_bars, 0.0, 1.0, 0.6)
	_props = Node3D.new()
	add_child(_props)


func _end(done: Callable) -> void:
	Sfx.music_stop(1.2)
	var tw := _tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	await tw.finished
	_props.queue_free()
	for n in hide_nodes:
		if is_instance_valid(n):
			n.visible = n.get_meta("was_visible", true)
	Engine.time_scale = 1.0
	env.adjustment_saturation = 1.12
	_layer.visible = false
	busy = false
	done.call()
	var tw2 := _tween()
	_layer.visible = true
	tw2.tween_property(_fade, "color:a", 0.0, 0.8)
	tw2.parallel().tween_method(_layout_bars, 1.0, 0.0, 0.8)
	await tw2.finished
	_layer.visible = false


func _fade_to(a: float, t: float) -> void:
	var tw := _tween()
	tw.tween_property(_fade, "color:a", a, t)
	await tw.finished


## Kamera kiertää pistettä sec sekuntia (reaaliajassa).
func _orbit(center: Vector3, radius: float, height: float, from_a: float, to_a: float, sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while true:
		var u := clampf((Time.get_ticks_msec() - t0) / (sec * 1000.0), 0.0, 1.0)
		var a := lerpf(from_a, to_a, u)
		_cam.global_position = center + Vector3(cos(a) * radius, height, sin(a) * radius)
		_cam.look_at(center + Vector3.UP * 1.0, Vector3.UP)
		if u >= 1.0:
			break
		await get_tree().process_frame


# --- WASTED + motkotus ------------------------------------------------------------

func wasted(at: Vector3, reason: String, cause: String, home: Vector3, done: Callable, choco := "") -> void:
	_begin()
	_cam.current = true
	Sfx.play("lose", 0.0)
	Engine.time_scale = 0.3
	var tw := _tween()
	tw.tween_property(env, "adjustment_saturation", 0.0, 1.2)
	_orbit(at, 5.0, 3.5, 0.3, 1.2, 3.4)
	await _wait(0.9)
	_band.visible = true
	_title.add_theme_color_override("font_color", Color(0.85, 0.08, 0.08))
	_title.text = "WASTED"
	_title.scale = Vector2.ONE * 1.4
	_title.pivot_offset = _title.size / 2.0
	var tt := _tween()
	tt.tween_property(_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	_sub.text = reason.replace("\n", " ")
	await _wait(2.6)
	await _fade_to(1.0, 0.6)
	Engine.time_scale = 1.0
	env.adjustment_saturation = 1.12
	_band.visible = false
	_title.text = ""
	# Päivin motkotus kotipihalla (oikea pelaajahahmo piiloon).
	for n in hide_nodes:
		if is_instance_valid(n):
			n.visible = false
	var hero := Looks.make(_props, Looks.PLAYER)
	Looks.add_cap(hero)
	hero.global_position = home + Vector3(0, 0, 1.0)
	hero.rotation.y = PI * 0.5
	hero.play("Idle", 0.0)
	hero.set_override("neck_01", Vector3.RIGHT, 0.5)  # pää painuksissa
	var paivi := Looks.make(_props, Looks.PAIVI)
	paivi.global_position = home + Vector3(-1.4, 0, 1.0)
	paivi.rotation.y = -PI * 0.5
	paivi.play("Idle_Talking", 0.0)
	var bubble := B.label(_props, "", paivi.global_position + Vector3(0.3, 2.05, 0), 26, Color.WHITE, true)
	bubble.outline_size = 8
	bubble.no_depth_test = true
	_cam.global_position = home + Vector3(-0.7, 1.7, 4.6)
	_cam.look_at(home + Vector3(-0.7, 1.35, 1.0), Vector3.UP)
	if choco != "":
		_give_chocolate(hero)
	_sub.text = "Päivi ei ollut tyytyväinen." if choco != "ok" else "Päivi ei ollut ihan niin tyytymätön."
	await _fade_to(0.0, 0.6)
	var lines: Array = PAIVI_LINES.get(cause, PAIVI_LINES.default)
	if choco == "ok":
		lines = CHOCO_OK_LINES
	elif choco == "fail":
		lines = [CHOCO_FAIL_LINE] + lines
	for line in lines:
		bubble.text = "Päivi: " + line
		await _wait(1.7)
	await _end(done)


# --- Päivi löytää kotijemman ------------------------------------------------------

const FOUND_LINES := ["Mitäs NÄMÄ sitten on?!", "Autotallin hyllyn takana, vai?", "Nämä menee nyt viemäriin!",
	"Ja jos vielä kerran löydän..."]


## Sankari ojentaa suklaalevyn Päiville.
func _give_chocolate(hero: Node3D) -> void:
	var bar := Node3D.new()
	B.mesh(bar, B.boxm(Vector3(0.16, 0.02, 0.08)), Vector3.ZERO, Color(0.1, 0.25, 0.7))
	hero.attach("hand_r", bar, Vector3(0, -0.03, 0.04))


func jemma_found(home: Vector3, lost: int, left: int, done: Callable, choco := "") -> void:
	_begin()
	await _fade_to(1.0, 0.4)
	for n in hide_nodes:
		if is_instance_valid(n):
			n.visible = false
	_cam.current = true
	# Päivi kotipihalla kaljakasa jaloissa, sankari vieressä nolona.
	var paivi := Looks.make(_props, Looks.PAIVI)
	paivi.global_position = home + Vector3(-0.8, 0, 1.2)
	paivi.rotation.y = PI + 0.7  # kohti sankaria ja kameraa
	paivi.play("Idle_Talking", 0.0)
	var can := Node3D.new()
	B.mesh(can, B.cyl(0.033, 0.033, 0.12, 12), Vector3.ZERO, Color(0.8, 0.75, 0.2))
	paivi.attach("hand_r", can, Vector3(0, -0.02, 0))
	var hero := Looks.make(_props, Looks.PLAYER)
	Looks.add_cap(hero)
	hero.global_position = home + Vector3(0.9, 0, 1.2)
	hero.rotation.y = PI - 0.7
	hero.play("Idle", 0.0)
	hero.set_override("neck_01", Vector3.RIGHT, 0.55)
	for i in mini(lost, 24):
		var c := B.mesh(_props, B.cyl(0.033, 0.033, 0.12, 10), home + Vector3(-0.2 + (i % 6) * 0.09, 0.06 + (i / 6) * 0.125, 2.0 + randf() * 0.05),
			Color(0.8, 0.75, 0.2))
		c.rotation.y = randf() * TAU
	B.box(_props, Vector3(0.7, 0.3, 0.45), home + Vector3(-1.9, 0.15, 1.6), Color(0.3, 0.2, 0.1), false)  # kaljakori
	var bubble := B.label(_props, "", paivi.global_position + Vector3(0, 2.05, 0), 26, Color.WHITE, true)
	bubble.outline_size = 8
	_cam.global_position = home + Vector3(0.1, 1.55, 4.3)
	_cam.look_at(home + Vector3(0.0, 1.15, 1.3), Vector3.UP)
	env.adjustment_saturation = 1.12
	await _fade_to(0.0, 0.5)
	if choco != "":
		_give_chocolate(hero)
	for line in FOUND_LINES.slice(0, 2):
		bubble.text = "Päivi: " + line
		await _wait(1.6)
	if choco == "ok":
		bubble.text = "Päivi: ...No. Kaadan vaan osan."
		await _wait(1.6)
	elif choco == "fail":
		bubble.text = "Päivi: " + CHOCO_FAIL_LINE
		await _wait(1.6)
	# WASTED-tyyli: harmaaksi ja iso punainen teksti.
	Sfx.play("glass", 0.0)
	Sfx.play("lose", -2.0)
	var tw := _tween()
	tw.tween_property(env, "adjustment_saturation", 0.0, 0.8)
	_band.visible = true
	_title.add_theme_color_override("font_color", Color(0.85, 0.08, 0.08))
	_title.add_theme_font_size_override("font_size", 110)
	_title.text = "JEMMA PALJASTUI"
	_title.pivot_offset = _title.size / 2.0
	_title.scale = Vector2.ONE * 1.4
	_tween().tween_property(_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	_sub.text = "Päivi kaatoi %d kaljaa viemäriin. Jemmaan jäi %d." % [lost, left]
	bubble.text = "Päivi: " + FOUND_LINES[2]
	await _wait(2.2)
	bubble.text = "Päivi: " + FOUND_LINES[3]
	await _wait(1.8)
	_title.add_theme_font_size_override("font_size", 150)
	await _end(done)


# --- Makkaranpaisto auringonlaskussa ----------------------------------------------

func laavu_sunset(pit: Vector3, fire: Node3D, title: String, stats: String, done: Callable) -> void:
	_begin()
	Sfx.music_play(0.8, Sfx.MUSIC_CHORUS)
	await _fade_to(1.0, 0.5)
	_cam.current = true
	fire.visible = true
	for n in hide_nodes:
		if is_instance_valid(n):
			n.visible = false
	var old_rot := sun.rotation_degrees
	var old_col := sun.light_color
	var old_en := sun.light_energy
	var hero := Looks.make(_props, Looks.PLAYER)
	Looks.add_cap(hero)
	hero.global_position = pit + Vector3(-2.1, 0.12, 0)
	hero.rotation.y = -PI * 0.5
	hero.play("Sitting_Idle", 0.0)
	# Makkaratikku kädessä kohti tulta.
	var stick := Node3D.new()
	B.tube(stick, Vector3.ZERO, Vector3(0, 0, -1.3), 0.012, Color(0.5, 0.35, 0.2))
	B.mesh(stick, B.capsule(0.03, 0.16), Vector3(0, 0, -1.25), Color(0.6, 0.2, 0.12), Vector3(90, 0, 0))
	hero.attach("hand_r", stick, Vector3(0, 0, 0))
	stick.rotation_degrees = Vector3(-25, -70, 0)
	var can := B.mesh(_props, B.cyl(0.033, 0.033, 0.12, 12), pit + Vector3(-2.0, 0.55, 0.35), Color(0.8, 0.75, 0.2))
	can.rotation_degrees.x = 0
	_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	var tw := _tween()
	tw.tween_property(sun, "rotation_degrees", Vector3(-4, 255, 0), 7.0)
	tw.parallel().tween_property(sun, "light_color", Color(1.0, 0.45, 0.2), 7.0)
	tw.parallel().tween_property(sun, "light_energy", 0.9, 7.0)
	_fade_to(0.0, 0.8)
	_orbit(pit + Vector3(-1.0, 0, 0), 5.8, 1.5, PI * 1.22, PI * 1.62, 8.0)
	await _wait(1.2)
	_title.text = title
	_title.add_theme_font_size_override("font_size", 90)
	_sub.text = stats
	await _wait(6.8)
	await _end(done)
	sun.rotation_degrees = old_rot
	sun.light_color = old_col
	sun.light_energy = old_en
	_title.add_theme_font_size_override("font_size", 150)


# --- Taksireissu Raaheen ----------------------------------------------------------

const TAXI_ROAD := Vector3(0, 0, -3400)
const TAXI_OUT_LINES := ["Raaheen vai? No mennään.", "Kuutonen jää kotiin, baarissa juodaan hanasta.",
	"Siellä on terästehtaan porukka taas liikkeellä..."]
const TAXI_HOME_LINES := ["No, oliko reissu rahan arvoinen?", "Kotipihaan asti. Onnea vaan.", "Päivi taitaa olla hereillä..."]


## Menomatka: taksi kaahaa katuvalojen alla kohti Raahen valoja, kuski juttelee ja radiosta soi biisi.
func taxi_to_raahe(done: Callable) -> void:
	_begin()
	Sfx.music_play(0.8)
	await _fade_to(1.0, 0.4)
	var road := _build_taxi_road()
	var taxi := Node3D.new()
	road.add_child(taxi)
	Vehicles.taxi(taxi)
	var bubble := B.label(_props, "", Vector3.ZERO, 26, Color.WHITE, true)
	bubble.outline_size = 8
	_cam.current = true
	_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_title.add_theme_font_size_override("font_size", 90)
	var t0 := Time.get_ticks_msec()
	var faded := false
	while Time.get_ticks_msec() - t0 < 8000:
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		taxi.position.z = -t * 16.0
		var tp := taxi.global_position
		_cam.global_position = tp + Vector3(lerpf(4.0, 2.2, t / 8.0), 1.7, 6.5)
		_cam.look_at(tp + Vector3(0, 0.8, -3.0), Vector3.UP)
		bubble.global_position = tp + Vector3(-0.4, 2.3, 0)
		bubble.text = TAXI_OUT_LINES[mini(int(t / 2.6), TAXI_OUT_LINES.size() - 1)]
		if not faded:
			faded = true
			_fade_to(0.0, 0.6)
			_title.text = "RAAHEEN"
			_sub.text = "Taksi kaahaa kohti Raahen valoja."
		await get_tree().process_frame
	await _end(done)
	_title.add_theme_font_size_override("font_size", 150)


## Paluumatka Raahesta, sitten kotipihalla odottaa Päivi. stats näytetään matkalla.
func taxi_home(home: Vector3, stats: String, done: Callable) -> void:
	_begin()
	Sfx.music_play(0.8, Sfx.MUSIC_CHORUS)
	await _fade_to(1.0, 0.4)
	var road := _build_taxi_road()
	var taxi := Node3D.new()
	taxi.position.z = -150.0
	taxi.rotation.y = PI  # takaisin päin
	road.add_child(taxi)
	Vehicles.taxi(taxi)
	var driver := Looks.make(taxi, Looks.TAXI_DRIVER)
	driver.position = Vector3(-0.4, 0.05, 0.1)
	driver.play("Driving", 0.0)
	_cam.current = true
	_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_title.add_theme_font_size_override("font_size", 80)
	var t0 := Time.get_ticks_msec()
	var faded := false
	while Time.get_ticks_msec() - t0 < 6500:
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		taxi.position.z = -150.0 + t * 16.0
		# Edestä viistosti: kuski ratissa ja Raahen valot taustalla.
		_cam.global_position = taxi.to_global(Vector3(lerpf(2.8, 1.8, t / 6.5), 1.5, -7.5))
		_cam.look_at(taxi.to_global(Vector3(0.0, 0.9, 0.0)), Vector3.UP)
		if not faded:
			faded = true
			_fade_to(0.0, 0.6)
			_title.text = "TAKAISIN SALOISIIN"
			_sub.text = stats
		_sub.text = stats if t < 4.0 else TAXI_HOME_LINES[mini(int((t - 4.0) / 1.2), TAXI_HOME_LINES.size() - 1)]
		await get_tree().process_frame
	await _fade_to(1.0, 0.5)
	_title.text = ""
	road.queue_free()
	# Kotipiha: taksi kaartaa pois, Päivi odottaa.
	for n in hide_nodes:
		if is_instance_valid(n):
			n.visible = false
	var hero := Looks.make(_props, Looks.PLAYER)
	Looks.add_cap(hero)
	hero.global_position = home + Vector3(0, 0, 1.0)
	hero.rotation.y = PI * 0.5
	hero.play("Idle", 0.0)
	hero.set_override("neck_01", Vector3.RIGHT, 0.5)
	var paivi := Looks.make(_props, Looks.PAIVI)
	paivi.global_position = home + Vector3(-1.4, 0, 1.0)
	paivi.rotation.y = -PI * 0.5
	paivi.play("Idle_Talking", 0.0)
	var cab := Node3D.new()
	_props.add_child(cab)
	cab.global_position = home + Vector3(2.5, 0, -5.0)
	cab.rotation.y = -PI * 0.5  # keula +X: ajaa pois kuvan oikealle
	Vehicles.taxi(cab)
	var bubble := B.label(_props, "", paivi.global_position + Vector3(0.3, 2.05, 0), 26, Color.WHITE, true)
	bubble.outline_size = 8
	bubble.no_depth_test = true
	_cam.global_position = home + Vector3(-0.7, 1.7, 4.6)
	_cam.look_at(home + Vector3(-0.7, 1.35, 1.0), Vector3.UP)
	_sub.text = "Päivi oli odottanut."
	Sfx.music_stop(1.0)
	await _fade_to(0.0, 0.6)
	var ct := create_tween().set_ignore_time_scale(true)
	ct.tween_interval(3.5)  # taksi lähtee takaisin kaupan taksitolpalle motkotuksen aikana
	ct.tween_property(cab, "global_position", cab.global_position + Vector3(40, 0, 0), 5.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for line in PAIVI_LINES.raahe:
		bubble.text = line
		await _wait(1.8)
	await _end(done)
	_title.add_theme_font_size_override("font_size", 150)


## Ilta-tie Raaheen: asfalttia, katuvaloja, metsänreunaa ja lopussa Raahen valot ja terästehtaan piiput.
func _build_taxi_road() -> Node3D:
	var r := Node3D.new()
	r.position = TAXI_ROAD
	_props.add_child(r)
	B.box(r, Vector3(400, 0.1, 400), Vector3(0, -0.06, -150), Color(0.2, 0.3, 0.16), false)
	B.box(r, Vector3(7, 0.02, 400), Vector3(0, 0.0, -150), Color(0.18, 0.18, 0.19), false)
	for i in 60:
		B.box(r, Vector3(0.15, 0.01, 3.0), Vector3(0, 0.02, 40.0 - i * 6.5), Color(0.9, 0.9, 0.85), false)
	for i in 18:
		var z := 40.0 - i * 20.0
		for sx in [-5.5, 5.5]:
			B.box(r, Vector3(0.12, 6.0, 0.12), Vector3(sx, 3.0, z), Color(0.5, 0.5, 0.52), false)
			B.mesh(r, B.boxm(Vector3(0.9, 0.12, 0.3)), Vector3(sx * 0.85, 6.0, z), Color(1.0, 0.9, 0.6))
		for sx in [-14.0, 14.0]:
			B.mesh(r, B.cyl(0.0, 2.2, 8.0, 7), Vector3(sx + randf_range(-3, 3), 4.0, z + randf_range(-6, 6)), Color(0.1, 0.22, 0.12))
	# Raahen valot ja terästehtaan piiput horisontissa.
	for i in 12:
		B.box(r, Vector3(8, randf_range(6, 16), 8), Vector3(-50 + i * 9, 5, -380), Color(0.25, 0.25, 0.3), false)
	for x in [-20.0, -8.0, 15.0]:
		B.mesh(r, B.cyl(1.4, 2.0, 60.0, 10), Vector3(x, 30.0, -420), Color(0.45, 0.42, 0.4))
	for p in [Vector3(0, 5.5, 0), Vector3(0, 5.5, -80), Vector3(0, 5.5, -160)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color(1.0, 0.85, 0.55)
		l.light_energy = 1.2
		l.omni_range = 30.0
		r.add_child(l)
	return r


# --- Autotalli ja karburaattori ---------------------------------------------------

func garage(title: String, stats: String, done: Callable) -> void:
	_begin()
	Sfx.music_play(0.8, Sfx.MUSIC_CHORUS)
	await _fade_to(1.0, 0.5)
	_build_garage()
	_cam.current = true
	_cam.global_position = GARAGE_POS + Vector3(3.2, 1.9, 5.4)
	_cam.look_at(GARAGE_POS + Vector3(0.6, 0.9, 1.4), Vector3.UP)
	_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_title.add_theme_font_size_override("font_size", 90)
	await _fade_to(0.0, 0.8)
	_title.text = title
	_sub.text = stats
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 7500:
		var u := (Time.get_ticks_msec() - t0) / 7500.0
		_cam.global_position = GARAGE_POS + Vector3(lerpf(3.2, 2.2, u), lerpf(1.9, 1.5, u), lerpf(5.4, 4.3, u))
		_cam.look_at(GARAGE_POS + Vector3(0.6, 0.9, 1.4), Vector3.UP)
		await get_tree().process_frame
	await _end(done)
	_title.add_theme_font_size_override("font_size", 150)


func _build_garage() -> void:
	var g := Node3D.new()
	g.position = GARAGE_POS
	_props.add_child(g)
	var conc := Color(0.55, 0.55, 0.53)
	B.box(g, Vector3(7, 0.1, 8), Vector3(0, -0.05, 0), conc, false)
	for x in [-3.5, 3.5]:
		B.box(g, Vector3(0.2, 3, 8), Vector3(x, 1.5, 0), Color(0.82, 0.72, 0.52), false)
	B.box(g, Vector3(7, 3, 0.2), Vector3(0, 1.5, -4), Color(0.82, 0.72, 0.52), false)
	B.box(g, Vector3(7.2, 0.15, 8.2), Vector3(0, 3.05, 0), Color(0.3, 0.3, 0.3), false)
	# Työpöytä, työkalutaulu, rasvatahra.
	B.box(g, Vector3(2.4, 0.9, 0.7), Vector3(-2.1, 0.45, -3.4), Color(0.45, 0.3, 0.18), false)
	B.box(g, Vector3(2.2, 1.2, 0.05), Vector3(-2.1, 1.8, -3.88), Color(0.7, 0.6, 0.45), false)
	for i in 7:
		B.box(g, Vector3(0.05, 0.35, 0.03), Vector3(-3.0 + i * 0.3, 1.9, -3.84), Color(0.3, 0.3, 0.32), false)
	B.box(g, Vector3(0.5, 0.25, 0.3), Vector3(-1.6, 1.02, -3.4), Color(0.75, 0.1, 0.08), false)
	B.mesh(g, B.cyl(0.9, 0.9, 0.01, 18), Vector3(0.3, 0.005, -1.8), Color(0.12, 0.11, 0.1))
	# Vanha auto konepelti auki.
	var car := Node3D.new()
	car.position = Vector3(0.6, 0, -0.6)
	car.rotation.y = PI  # keula ovelle päin
	g.add_child(car)
	Vehicles.car(car, Color(0.55, 0.12, 0.1), "SLN-73")
	var hood := Vehicles.slab(car, Vector3(0, 0.95, -0.95), Vector3(0, 1.9, -1.4), 1.7, 0.06, Vehicles.paint(Color(0.55, 0.12, 0.1)))
	hood.name = "Hood"
	B.box(car, Vector3(0.9, 0.3, 0.8), Vector3(0, 0.95, -1.5), Color(0.2, 0.2, 0.22), false)  # moottori
	B.mesh(car, B.cyl(0.14, 0.14, 0.18, 12), Vector3(0, 1.15, -1.5), Color(0.6, 0.6, 0.62))  # karburaattori
	# Sankari kumarassa moottorin kimpussa, kalja kädessä.
	var hero := Looks.make(g, Looks.PLAYER)
	Looks.add_cap(hero)
	hero.position = Vector3(0.9, 0, 2.2)
	hero.play("Fixing_Kneeling", 0.0)
	hero.set_override("spine_01", Vector3.RIGHT, -0.35)
	var can := Node3D.new()
	B.mesh(can, B.cyl(0.033, 0.033, 0.12, 12), Vector3(0, -0.02, 0), Color(0.8, 0.75, 0.2))
	hero.attach("hand_l", can, Vector3(0, -0.02, 0))
	# Kuutonen työpöydällä ja lamppu katossa.
	for i in 5:
		B.mesh(g, B.cyl(0.033, 0.033, 0.12, 10), Vector3(-2.8 + i * 0.09, 0.96, -3.3), Color(0.8, 0.75, 0.2))
	var bulb := OmniLight3D.new()
	bulb.position = Vector3(0, 2.8, -0.5)
	bulb.light_color = Color(1.0, 0.85, 0.6)
	bulb.light_energy = 2.2
	bulb.omni_range = 9.0
	bulb.shadow_enabled = true
	g.add_child(bulb)
	B.mesh(g, B.sphere(0.08, 8), Vector3(0, 2.8, -0.5), Color(1, 0.95, 0.8))
	B.guide(g, "Radio: Iskelmä", Vector3(-2.8, 1.25, -3.3), 30, Color(1, 1, 0.8), true)
