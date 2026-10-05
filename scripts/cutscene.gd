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
	"car": ["Miksi sää menit kuolemaan?!", "Auton alle! Ihan keskellä tietä!", "Ja katso nyt tätäkin!",
		"Kotiin siitä, heti!"],
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
	var bubble := B.bubble(_props, paivi.global_position + Vector3(0.3, 2.05, 0), Color.WHITE, 1.0, false)
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
	var bubble := B.bubble(_props, paivi.global_position + Vector3(0, 2.05, 0), Color.WHITE, 1.0, false)
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


# --- Savusaunan löyly ---------------------------------------------------------------

const SAUNA_LINES := ["Löyly hehkuu, hiki virtaa selässä.", "Ihan puhdas olo.", "Ei tätä kaupungissa saa.",
	"Hartiat rentoutuu vihdoinkin."]


## Löylyssä käynti terassilla: höyry nousee saunan ovelta, hartiat rentoutuvat, ja jos kaljaa on mukana,
## otetaan hörppy löylyn päälle. Lyhyt tunnelmapala, ei päivän lopetus (ks. main.gd _sauna_cutscene).
func sauna_relax(at: Vector3, has_beer: bool, done: Callable) -> void:
	_begin()
	await _fade_to(1.0, 0.4)
	_cam.current = true
	for n in hide_nodes:
		if is_instance_valid(n):
			n.visible = false
	var hero := Looks.make(_props, Looks.PLAYER)
	Looks.add_cap(hero)
	hero.global_position = at + Vector3(-3.6, 0.0, 1.0)
	hero.rotation.y = -PI * 0.5  # kasvot saunan ovelle ja nousevalle höyrylle
	hero.play("Sitting_Idle", 0.0)
	# Löyly nousee saunan ovelta terassille.
	var steam := CPUParticles3D.new()
	steam.amount = 22
	steam.lifetime = 2.2
	steam.direction = Vector3.UP
	steam.spread = 14.0
	steam.initial_velocity_min = 0.4
	steam.initial_velocity_max = 0.9
	steam.scale_amount_min = 0.6
	steam.scale_amount_max = 1.6
	steam.global_position = at + Vector3(-1.8, 1.0, 1.5)
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.material = B.unshaded(Color(0.95, 0.95, 0.97, 0.35))
	steam.mesh = sm
	_props.add_child(steam)
	_cam.global_position = at + Vector3(-5.4, 1.6, 3.2)
	_cam.look_at(at + Vector3(-2.4, 1.05, 1.1), Vector3.UP)
	var can: Node3D
	if has_beer:
		can = Node3D.new()
		B.mesh(can, B.cyl(0.033, 0.033, 0.12, 12), Vector3(0, -0.02, 0), Color(0.8, 0.75, 0.2))
		hero.attach("hand_r", can, Vector3(0, -0.02, 0.03))
	_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	_title.add_theme_font_size_override("font_size", 70)
	await _fade_to(0.0, 0.6)
	_title.text = "LÖYLYSSÄ"
	_sub.text = "Höyry nousee, hartiat rentoutuvat."
	await _wait(2.2)
	if has_beer and can != null:
		var tw := _tween()
		tw.tween_property(can, "rotation_degrees:x", -70.0, 0.35)
		tw.tween_property(can, "rotation_degrees:x", 0.0, 0.35)
		_sub.text = "Otat hörpyn kylmää kaljaa löylyn päälle."
		Sfx.play("pickup", -2.0, 0.9)
		await _wait(1.8)
	_sub.text = SAUNA_LINES.pick_random()
	await _wait(2.0)
	await _end(done)
	_title.add_theme_font_size_override("font_size", 150)


# --- Taksireissu Raaheen ----------------------------------------------------------

const TAXI_ROAD := Vector3(0, 0, -3400)
const TAXI_OUT_LINES := ["Raaheen vai? No mennään.", "Kuutonen jää kotiin, baarissa juodaan hanasta.",
	"Siellä on terästehtaan porukka taas liikkeellä..."]
const TAXI_MOKKI_LINES := ["Paapeliin? Vaalaan asti? No, mittari on päällä.", "Kuuskymppiä, mutta tuon takasinki.",
	"Mökille vai? Kantarellejako poimimaan?"]
const TAXI_HOME_LINES := ["No, oliko reissu rahan arvoinen?", "Kotipihaan asti. Onnea vaan.", "Päivi taitaa olla hereillä..."]


## Menomatka: taksi kaahaa katuvalojen alla kohti Raahen valoja, kuski juttelee ja radiosta soi biisi.
func taxi_to_raahe(done: Callable) -> void:
	taxi_ride("RAAHEEN", "Taksi kaahaa kohti Raahen valoja.", TAXI_OUT_LINES, done)


## Taksimatka (title ja sub ruudulla, kuskin repliikit lines): Raaheen, Paapeliin tai Paapelista kotiin.
func taxi_ride(title: String, sub: String, lines: Array, done: Callable) -> void:
	_begin()
	Sfx.music_play(0.8)
	await _fade_to(1.0, 0.4)
	var road := _build_taxi_road()
	var taxi := Node3D.new()
	road.add_child(taxi)
	Vehicles.taxi(taxi)
	var bubble := B.bubble(_props, Vector3.ZERO, Color.WHITE, 1.0, false)
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
		bubble.text = lines[mini(int(t / 2.6), lines.size() - 1)]
		if not faded:
			faded = true
			_fade_to(0.0, 0.6)
			_title.text = title
			_sub.text = sub
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
	var bubble := B.bubble(_props, paivi.global_position + Vector3(0.3, 2.05, 0), Color.WHITE, 1.0, false)
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


# --- Pekan kyyti mökille ----------------------------------------------------------

const RIDE_ROAD := Vector3(-6000, 0, -3000)
const RIDE_LEN := 420.0
const PEKKA_RIDE_LINES := ["Hyppää kyytiin perkele, mää oon menossa Neittävälle kyyhkyjahtiin!",
	"Turvavyö? Ei tässä autossa oo saatanan turvavöitä.", "Kato, hirvi! ...Ei ollu. Kanto se oli, perkele.",
	"Neittävän pelloilla on kyyhkyä ku vittu taivaan täydeltä!", "Sanoinko jo että ammuin neljätoista kyyhkyä?",
	"Tästä Kaisuantielle. Terveisiä Santulle, perkele!"]
const PEKKA_HOME_LINES := ["Yheksän kyyhkyä tuli, perkele. Kymmenes karkas metsään.",
	"No, tuliko Santun hommat tehtyä vai motkottiko se taas, saatana?", "Päivi soitti mulle. Mää en sanonu mitään, perkele.",
	"Ens kerralla lähetään yhessä jahtiin, vittu.", "Sanoinko jo että ammuin neljätoista kyyhkyä?",
	"Kotipihaan asti, saatana. Tervemenoa Päivin luo."]
const PEKKA_EVICT_LINES := ["Santtu soitti. Kuulemma hommat jäi tekemättä, perkele.", "Yhen tähen arvostelu? Voi vittu.",
	"No, mää en kerro Päiville. Tai no, se kuulee kuitenkin.", "Kyyhkyjahti jäi kesken sun takia, saatana.",
	"Sanoinko jo että ammuin neljätoista kyyhkyä?", "Kotipihaan asti. Mee nyt vaan sisälle, perkele."]


## Pekan vanha vihreä Volvo-farmari: kattoteline, haulikkolaukku ja läpinäkyvät lasit, että kuski ja
## kyytiläinen näkyvät. Palauttaa {"car", "pekka", "hero", "wheels"}.
func _pekka_car(parent: Node3D) -> Dictionary:
	var car := Node3D.new()
	parent.add_child(car)
	var wheels := Vehicles.car(car, Color(0.22, 0.3, 0.18), "PEK-14")
	for c in car.get_children():
		if c is MeshInstance3D and c.material_override == Vehicles.glass():
			c.material_override = Vehicles.cab_glass()
	var rack := Color(0.12, 0.12, 0.12)
	for z in [-0.35, 0.85]:
		B.box(car, Vector3(1.5, 0.05, 0.06), Vector3(0, 1.53, z), rack, false)
	B.box(car, Vector3(0.28, 0.12, 1.6), Vector3(0.35, 1.62, 0.25), Color(0.3, 0.24, 0.12), false)  # haulikkolaukku
	B.box(car, Vector3(0.55, 0.32, 0.9), Vector3(-0.35, 1.72, 0.25), Color(0.75, 0.3, 0.08), false)  # punkka kattotelineellä
	var pekka := Looks.make(car, Looks.PEKKA)
	pekka.position = Vector3(-0.4, 0.05, 0.1)
	pekka.play("Driving", 0.0)
	var hero := Looks.make(car, Looks.PLAYER)
	Looks.add_cap(hero)
	hero.position = Vector3(0.4, 0.05, 0.15)
	hero.play("Sitting_Idle", 0.0)
	var can := Node3D.new()
	B.mesh(can, B.cyl(0.033, 0.033, 0.12, 12), Vector3(0, -0.02, 0), Color(0.8, 0.75, 0.2))
	hero.attach("hand_r", can, Vector3(0, -0.02, 0.03))
	return {"car": car, "pekka": pekka, "hero": hero, "wheels": wheels}


## Kyyti naapurin Pekan kanssa Saloisista Vaalaan: kesäinen maantie peltojen, säilörehupaalien ja männikön
## halki, Pekka puhuu kyyhkyistä. Kolme kuvaa: perästä, edestä tuulilasin läpi (Pekka ratissa, sankari
## kalja kädessä) ja tienvarresta, kun auto kaartaa Neittävän kyltin ohi. done kutsutaan pimeällä.
## kind: "meno" (Vaalaan), "koti" (kotiin Saloisiin) tai "haato" (Santtu soitti Pekan hakemaan).
func pekka_ride(sub: String, done: Callable, kind := "meno") -> void:
	var home := kind != "meno"
	var lines: Array = PEKKA_RIDE_LINES if not home else (PEKKA_EVICT_LINES if kind == "haato" else PEKKA_HOME_LINES)
	_begin()
	Sfx.play("door_close", -3.0)
	Sfx.music_play(0.8)
	await _fade_to(1.0, 0.4)
	var road := _build_ride_road("Raahe 108\nSaloinen 106" if home else "Vaala 12\nNeittävä 4", "SALOINEN" if home else "NEITTÄVÄ")
	var rig := _pekka_car(road)
	var car: Node3D = rig.car
	var wheels: Array = rig.wheels
	var bubble := B.bubble(_props, Vector3.ZERO, Color.WHITE, 1.0, false)
	bubble.no_depth_test = true
	_cam.current = true
	_title.add_theme_color_override("font_color", Color(0.75, 0.95, 0.45))
	_title.add_theme_font_size_override("font_size", 80)
	const SEC := 12.0
	const SPEED := 22.0
	var t0 := Time.get_ticks_msec()
	var faded := false
	var honked := false
	while Time.get_ticks_msec() - t0 < SEC * 1000.0:
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		# Kevyt hölskyntä soratiellä ja pyörät pyörivät.
		car.position = Vector3(sin(t * 0.7) * 0.25, absf(sin(t * 9.0)) * 0.02, -t * SPEED)
		car.rotation.z = sin(t * 5.3) * 0.012
		for w: Node3D in wheels:
			w.rotation.x = -t * SPEED / 0.34
		var tp := car.global_position
		if t < 4.2:
			# 1) Perästä viistosti: tie ja pellot aukeavat eteen.
			var u := t / 4.2
			_cam.global_position = tp + Vector3(lerpf(4.5, 2.6, u), lerpf(2.6, 1.9, u), lerpf(8.5, 6.8, u))
			_cam.look_at(tp + Vector3(0, 0.9, -4.0), Vector3.UP)
		elif t < 8.6:
			# 2) Edestä tuulilasin läpi: Pekka ratissa, sankari kalja kädessä.
			var u := (t - 4.2) / 4.4
			_cam.global_position = car.to_global(Vector3(lerpf(1.6, 0.5, u), 1.45, -5.4 + u * 0.8))
			_cam.look_at(car.to_global(Vector3(0.0, 1.2, 0.2)), Vector3.UP)
		else:
			# 3) Tienvarresta Neittävän kyltin vierestä: auto ohittaa ja töräyttää.
			var post := RIDE_ROAD + Vector3(5.8, 1.1, -SPEED * 10.3)
			_cam.global_position = post
			_cam.look_at(tp + Vector3(0, 0.8, 0), Vector3.UP)
			if not honked:
				honked = true
				Sfx.play("horn", -6.0)
		bubble.global_position = tp + Vector3(-0.4, 2.4 if t < 4.2 or t >= 8.6 else 1.85, 0)
		bubble.text = "Pekka: " + lines[mini(int(t / 2.0), lines.size() - 1)]
		if not faded:
			faded = true
			_fade_to(0.0, 0.6)
			_title.text = {"meno": "PEKAN KYYDILLÄ VAALAAN", "koti": "PEKAN KYYDILLÄ KOTIIN", "haato": "HÄÄTÖ MÖKILTÄ"}[kind]
			_sub.text = sub
		if t > 3.6 and t < 8.6:
			_title.text = ""  # tuulilasikuvassa kasvot näkyviin
			_band.visible = false
		elif t >= 8.6:
			_title.text = "SALOINEN" if home else "NEITTÄVÄ"
		await get_tree().process_frame
	await _end(done)
	_title.add_theme_font_size_override("font_size", 150)


## Kesäinen maantie Vaalaan: kapea asfaltti sorapientareineen, pellot ja säilörehupaalit, ladot, männikkö,
## sähkölinja, Oulujärven sininen kaistale ja lopussa kylän nimikyltti (Neittävä tai kotimatkalla Saloinen).
func _build_ride_road(guide: String, village: String) -> Node3D:
	var r := Node3D.new()
	r.position = RIDE_ROAD
	_props.add_child(r)
	var mid := -RIDE_LEN * 0.5 + 40.0
	B.box(r, Vector3(600, 0.1, RIDE_LEN + 200), Vector3(0, -0.06, mid), Color(0.32, 0.46, 0.2), false)  # pellot
	B.box(r, Vector3(9, 0.03, RIDE_LEN + 200), Vector3(0, -0.005, mid), Color(0.55, 0.5, 0.4), false)  # piennar
	B.box(r, Vector3(6, 0.02, RIDE_LEN + 200), Vector3(0, 0.01, mid), Color(0.26, 0.26, 0.27), false)
	for i in int((RIDE_LEN + 200) / 9.0):
		B.box(r, Vector3(0.12, 0.01, 3.0), Vector3(0, 0.025, 60.0 - i * 9.0), Color(0.92, 0.88, 0.6), false)
	for sx in [-2.85, 2.85]:
		B.box(r, Vector3(0.1, 0.01, RIDE_LEN + 200), Vector3(sx, 0.025, mid), Color(0.9, 0.9, 0.86), false)
	# Ojat ja viljapelto (kultaista) vasemmalla, nurmipelto paaleineen oikealla.
	for sx in [-5.5, 5.5]:
		B.box(r, Vector3(1.2, 0.02, RIDE_LEN + 200), Vector3(sx, -0.02, mid), Color(0.2, 0.3, 0.15), false)
	B.box(r, Vector3(120, 0.04, RIDE_LEN * 0.6), Vector3(-67, 0.0, -90), Color(0.78, 0.68, 0.3), false)
	var white := Color(0.93, 0.94, 0.92)
	for i in 26:
		var p := Vector3(randf_range(14, 70), 0.6, randf_range(-RIDE_LEN + 60, 40))
		var bale := B.mesh(r, B.cyl(0.65, 0.65, 1.2, 16), p, white, Vector3(0, 0, PI / 2.0))
		bale.rotation.y = randf() * TAU
	# Punainen lato ja keltainen omakotitalo peltojen laidalla.
	for spec in [[Vector3(-34, 0, -40), Color(0.6, 0.12, 0.08)], [Vector3(30, 0, -210), Color(0.62, 0.14, 0.1)],
			[Vector3(-26, 0, -300), Color(0.9, 0.78, 0.35)]]:
		var bp: Vector3 = spec[0]
		B.box(r, Vector3(9, 4, 6), bp + Vector3(0, 2, 0), spec[1], false)
		B.mesh(r, B.cyl(0.0, 5.6, 2.4, 4), bp + Vector3(0, 5.2, 0), Color(0.18, 0.18, 0.2), Vector3(0, PI / 4.0, 0))
		for wx in [-2.5, 2.5]:
			B.box(r, Vector3(1.0, 1.0, 0.05), bp + Vector3(wx, 2.4, 3.03), white, false)
	# Männikkö ja kuusikko peltojen takana, välillä tien vieressä.
	for i in 140:
		var side := -1.0 if i % 2 == 0 else 1.0
		var near := i % 7 == 0
		var x := side * (randf_range(9, 16) if near else randf_range(75, 160))
		var z := randf_range(-RIDE_LEN - 40, 60)
		var hgt := randf_range(9, 16)
		if randf() < 0.5:
			B.mesh(r, B.cyl(0.0, hgt * 0.22, hgt * 0.8, 7), Vector3(x, hgt * 0.5, z), Color(0.1, 0.24, 0.12))  # kuusi
		else:
			B.mesh(r, B.cyl(0.18, 0.25, hgt * 0.75, 6), Vector3(x, hgt * 0.37, z), Color(0.55, 0.32, 0.18))  # männyn runko
			B.mesh(r, B.sphere(hgt * 0.2, 7), Vector3(x, hgt * 0.8, z), Color(0.16, 0.32, 0.14))
	# Sähkölinja: puupylväät ja langat oikealla puolella.
	var prev := Vector3.ZERO
	for i in 12:
		var p := Vector3(10.5, 0, 50.0 - i * 45.0)
		B.box(r, Vector3(0.25, 9, 0.25), p + Vector3(0, 4.5, 0), Color(0.35, 0.25, 0.16), false)
		B.box(r, Vector3(2.2, 0.15, 0.15), p + Vector3(0, 8.6, 0), Color(0.35, 0.25, 0.16), false)
		if i > 0:
			for wx in [-0.9, 0.9]:
				B.tube(r, prev + Vector3(wx, 8.7, 0), p + Vector3(wx, 8.7, 0), 0.015, Color(0.1, 0.1, 0.1))
		prev = p
	# Oulujärven sininen selkä horisontissa ja Kaihuanvaaran siluetti.
	B.box(r, Vector3(700, 0.05, 60), Vector3(0, 0.03, -RIDE_LEN - 70), Color(0.25, 0.42, 0.62), false)
	for i in 6:
		B.mesh(r, B.sphere(40.0 + i * 6.0, 10), Vector3(-260 + i * 100, -18, -RIDE_LEN - 190), Color(0.18, 0.3, 0.2))
	# Tienviitat: VAALA 12 alussa ja Neittävän kylännimikyltti lopussa (kolmannen kuvan kamera sen vieressä).
	var s1 := B.sign_pole(r, Vector3(4.6, 0, -30), 2.6)
	var p1 := B.sign_plate(s1, guide, Color(0.1, 0.32, 0.65), Color.WHITE, 0.6, 44, Color.WHITE, "Helvetica Neue")
	p1.position.y = 2.2
	var s2 := B.sign_pole(r, Vector3(4.6, 0, -22.0 * 10.3 + 7.0), 2.6)  # kameran ja tulevan auton välissä
	var p2 := B.sign_plate(s2, village, Color(0.1, 0.32, 0.65), Color.WHITE, 0.32, 44, Color.WHITE, "Helvetica Neue")
	p2.position.y = 2.2
	var sun_l := OmniLight3D.new()
	sun_l.position = Vector3(0, 30, -150)
	sun_l.light_color = Color(1.0, 0.95, 0.8)
	sun_l.light_energy = 0.6
	sun_l.omni_range = 400.0
	r.add_child(sun_l)
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


# --- Viinibileet ja hatarat muistikuvat ------------------------------------------------

## Takaumat illasta: [kuvateksti, kameran paikka, katseen kohde (tallin koordinaateissa)]. Asetelmat _wine_pose.
const WINE_FLASHBACKS := [
	["...Pekka seisoi saavin päällä ja piti juhlapuheen kotiviinin kunniaksi...", Vector3(-0.6, 0.5, 1.6), Vector3(-2.6, 1.6, -0.4)],
	["...Sinikka ja sinä tanssitte tangoa radion tahtiin. Vai oliko se humppa?", Vector3(1.6, 1.2, 4.4), Vector3(0.0, 1.0, 2.6)],
	["...Arto halasi karburaattoria ja itki, että SLN-73 on hänen paras ystävänsä...", Vector3(2.2, 1.1, 3.6), Vector3(0.6, 0.6, 1.8)],
	["...joku lupasi, ettei viiniä tehdä enää IKINÄ.", Vector3(-1.2, 1.4, 1.2), Vector3(-2.6, 0.6, -0.4)],
]
var _party := {}


## Viinibileet autotallissa: kotiviini valmis, Pekka, Arto ja Sinikka kylässä. Juhlakuva ja sen jälkeen
## haaleat, vinot muistikuvat illasta (kuvatekstit), lopulta pimeys. done herättää naapurista (main.gd).
func wine_party(stats: String, done: Callable) -> void:
	_begin()
	Sfx.music_play(0.8, Sfx.MUSIC_CHORUS)
	await _fade_to(1.0, 0.5)
	_build_garage(true)
	var g := GARAGE_POS
	_cam.current = true
	_title.add_theme_color_override("font_color", Color(0.85, 0.3, 0.55))
	_title.add_theme_font_size_override("font_size", 90)
	await _fade_to(0.0, 0.8)
	_title.text = "VIINIBILEET!"
	_sub.text = stats
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6500:
		var u := (Time.get_ticks_msec() - t0) / 6500.0
		_cam.global_position = g + Vector3(lerpf(3.4, 2.0, u), lerpf(2.0, 1.6, u), lerpf(5.6, 4.8, u))
		_cam.look_at(g + Vector3(-0.8, 1.0, 1.6), Vector3.UP)
		await get_tree().process_frame
	_title.text = ""
	_sub.text = ""
	await _fade_to(1.0, 0.8)
	# Hatarat muistikuvat: haalea, vino ja huojuva kuva, välissä pimeää.
	env.adjustment_saturation = 0.25
	for i in WINE_FLASHBACKS.size():
		var fb: Array = WINE_FLASHBACKS[i]
		_wine_pose(i)
		await _fade_to(0.15, 0.35)
		_sub.text = fb[0]
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 2600:
			var w := (Time.get_ticks_msec() - t1) / 1000.0
			_cam.global_position = g + (fb[1] as Vector3) + Vector3(sin(w * 1.3) * 0.15, sin(w * 0.9) * 0.08, 0)
			_cam.look_at(g + (fb[2] as Vector3), Vector3.UP)
			_cam.rotate_object_local(Vector3.FORWARD, 0.18 * sin(w * 0.7 + i))
			_fade.color.a = 0.15 + 0.25 * absf(sin(w * 2.1 + i))  # silmät lupsuvat
			await get_tree().process_frame
		await _fade_to(1.0, 0.4)
	_sub.text = "...ja sitten kaikki pimeni."
	await _wait(1.6)
	_sub.text = ""
	await _end(done)
	_title.add_theme_font_size_override("font_size", 150)


## Paapelin mökkibileet pihalla (center = maailman piste kuistin edessä, yaw = kuistilta pihalle): Santtu,
## Sinikka ja Korpi-Kalle, kokko ja viinisangot. Juhlakuva ja hatarat muistikuvat kuten viinibileissä.
const MOKKI_FLASHBACKS := [
	["...Santtu nosti PA-kaiuttimet kuistille ja soitti Eräitä Jormia koko Neittävälle...", Vector3(-3.0, 1.2, 3.5), Vector3(0, 1.2, -1.5)],
	["...Korpi-Kalle ja Sinikka tanssivat humppaa kokon ympäri...", Vector3(3.5, 1.4, 3.0), Vector3(0.8, 1.0, 1.5)],
	["...joku hyppäsi järveen vaatteet päällä. Taisit olla sinä.", Vector3(0, 2.2, 5.0), Vector3(0, 0.5, 14.0)],
	["...Santtu lupasi, ettei Paapelilla tehdä enää viiniä. Ikinä. Ehkä.", Vector3(-1.0, 1.5, 2.0), Vector3(-1.4, 1.3, -0.4)],
]


func mokki_party(center: Vector3, yaw: float, stats: String, done: Callable) -> void:
	_begin()
	Sfx.music_play(0.8, Sfx.MUSIC_CHORUS)
	await _fade_to(1.0, 0.5)
	var g := Node3D.new()
	_props.add_child(g)
	g.global_position = center
	g.rotation.y = yaw
	var Mokki := load("res://scripts/mokki.gd")
	var Kalle := load("res://scripts/korpikeittaja.gd")
	# Kokko, pöytä ja sangot.
	for k in 8:
		var a := TAU * k / 8.0
		B.mesh(g, B.sphere(0.16, 8), Vector3(0.8 + cos(a) * 0.55, 0.1, 1.5 + sin(a) * 0.55), Color(0.45, 0.44, 0.42))
	var glow := B.unshaded(Color(1.0, 0.5, 0.1))
	for k in 3:
		var f := MeshInstance3D.new()
		f.mesh = B.boxm(Vector3(0.4, 0.5, 0.06))
		f.material_override = glow
		f.position = Vector3(0.8, 0.3, 1.5)
		f.rotation.y = k * PI / 3.0
		g.add_child(f)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.position = Vector3(0.8, 0.8, 1.5)
	g.add_child(light)
	B.mesh(g, B.boxm(Vector3(1.4, 0.06, 0.7)), Vector3(-2.0, 0.75, 0.6), Color(0.55, 0.4, 0.25))
	for k in 5:
		B.mesh(g, B.cyl(0.035, 0.04, 0.26, 8), Vector3(-2.5 + k * 0.22, 0.91, 0.6), Color(0.2, 0.4, 0.22))
	for k in 2:
		B.mesh(g, B.cyl(0.26, 0.22, 0.5, 14), Vector3(-2.9 + k * 0.6, 0.25, 1.4), Color(0.95, 0.95, 0.93))
	_party.clear()
	var cast := [["hero", Looks.PLAYER, Vector3(-0.4, 0, 2.2), "Dance"], ["santtu", Mokki.SANTTU_LOOK, Vector3(-1.4, 0, -0.4), "Dance"],
		["sinikka", Looks.SINIKKA, Vector3(1.8, 0, 2.4), "Dance"], ["kalle", Kalle.KALLE, Vector3(2.2, 0, 1.2), "Dance"]]
	for c in cast:
		var ch := Looks.make(g, c[1])
		if c[0] == "hero":
			Looks.add_cap(ch)
		ch.position = c[2]
		ch.play(c[3], 0.0)
		ch.attach("hand_r", _wine_glass(), Vector3(0, -0.03, 0.04))
		_party[c[0]] = ch
	_face(_party.hero, Vector3(0.8, 0, 1.5))
	_face(_party.santtu, Vector3(0.8, 0, 1.5))
	_face(_party.sinikka, _party.kalle.position)
	_face(_party.kalle, _party.sinikka.position)
	var tg := func(local: Vector3) -> Vector3: return g.to_global(local)
	_cam.current = true
	_title.add_theme_color_override("font_color", Color(0.85, 0.3, 0.55))
	_title.add_theme_font_size_override("font_size", 90)
	await _fade_to(0.0, 0.8)
	_title.text = "MÖKKIBILEET!"
	_sub.text = stats
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6500:
		var u := (Time.get_ticks_msec() - t0) / 6500.0
		_cam.global_position = tg.call(Vector3(lerpf(4.5, 2.5, u), lerpf(2.6, 1.9, u), lerpf(6.5, 5.2, u)))
		_cam.look_at(tg.call(Vector3(0.2, 1.0, 1.2)), Vector3.UP)
		await get_tree().process_frame
	_title.text = ""
	_sub.text = ""
	await _fade_to(1.0, 0.8)
	env.adjustment_saturation = 0.25
	for i in MOKKI_FLASHBACKS.size():
		var fb: Array = MOKKI_FLASHBACKS[i]
		match i:
			0:
				_party.santtu.play("Dance", 0.0)
			1:
				_party.sinikka.position = Vector3(0.0, 0, 2.4)
				_party.kalle.position = Vector3(0.6, 0, 2.6)
				_face(_party.sinikka, _party.kalle.position)
				_face(_party.kalle, _party.sinikka.position)
			2:
				for k in ["hero", "santtu", "sinikka", "kalle"]:
					_party[k].visible = false
			3:
				_party.santtu.visible = true
				_party.santtu.play("Idle_Talking", 0.0)
				_face(_party.santtu, Vector3(-1.0, 0, 2.0))
		await _fade_to(0.15, 0.35)
		_sub.text = fb[0]
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 2600:
			var w := (Time.get_ticks_msec() - t1) / 1000.0
			_cam.global_position = tg.call((fb[1] as Vector3) + Vector3(sin(w * 1.3) * 0.15, sin(w * 0.9) * 0.08, 0))
			_cam.look_at(tg.call(fb[2]), Vector3.UP)
			_cam.rotate_object_local(Vector3.FORWARD, 0.18 * sin(w * 0.7 + i))
			_fade.color.a = 0.15 + 0.25 * absf(sin(w * 2.1 + i))
			await get_tree().process_frame
		await _fade_to(1.0, 0.4)
	_sub.text = "...ja sitten kaikki pimeni."
	await _wait(1.6)
	_sub.text = ""
	await _end(done)
	_title.add_theme_font_size_override("font_size", 150)


## Takauman asetelma: hahmot ja asennot (i = WINE_FLASHBACKS-indeksi).
func _wine_pose(i: int) -> void:
	var pekka: Node3D = _party.get("pekka")
	var arto: Node3D = _party.get("arto")
	var sinikka: Node3D = _party.get("sinikka")
	var hero: Node3D = _party.get("hero")
	match i:
		0:
			pekka.position = Vector3(-2.6, 0.72, -0.4)
			_face(pekka, Vector3(0, 0, 2.0))
			pekka.play("Idle_Talking", 0.0)
		1:
			hero.position = Vector3(-0.25, 0, 2.6)
			sinikka.position = Vector3(0.3, 0, 2.6)
			_face(hero, sinikka.position)
			_face(sinikka, hero.position)
			hero.play("Dance", 0.0)
			sinikka.play("Dance", 0.0)
		2:
			arto.position = Vector3(0.6, 0, 1.9)
			_face(arto, Vector3(0.6, 0, 0.5))
			arto.play("Fixing_Kneeling", 0.0)
		3:
			for ch in [pekka, arto, sinikka, hero]:
				ch.visible = false


## Hahmo katsomaan kohti pistettä (tallin koordinaateissa).
func _face(ch: Node3D, at: Vector3) -> void:
	var d := at - ch.position
	ch.rotation.y = atan2(-d.x, -d.z)  # malli katsoo -Z:aan


func _wine_glass() -> Node3D:
	var gl := Node3D.new()
	B.mesh(gl, B.cyl(0.035, 0.02, 0.07, 10), Vector3(0, 0.05, 0), Color(0.5, 0.05, 0.2))
	B.mesh(gl, B.cyl(0.004, 0.004, 0.07, 6), Vector3(0, -0.02, 0), Color(0.9, 0.9, 0.95))
	return gl


func _build_garage(party := false) -> void:
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
	if party:
		_build_wine_party(g)
	else:
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


## Viinibileiden väki: sankari ja Sinikka tanssivat, Pekka ja Arto maistelevat saavin vieressä, viinilasit käsissä.
func _build_wine_party(g: Node3D) -> void:
	var wood := Color(0.52, 0.34, 0.18)
	B.mesh(g, B.cyl(0.36, 0.31, 0.65, 18), Vector3(-2.6, 0.33, -0.4), wood)  # viinisaavi
	B.mesh(g, B.cyl(0.33, 0.33, 0.02, 18), Vector3(-2.6, 0.62, -0.4), Color(0.45, 0.05, 0.2))
	for k in 6:  # tyhjiä pulloja lattialla
		var bt := B.mesh(g, B.cyl(0.035, 0.04, 0.26, 8), Vector3(-1.9 + k * 0.18, 0.04, -1.6 + (k % 2) * 0.2), Color(0.2, 0.4, 0.22))
		bt.rotation.z = PI / 2.0
	var cast := [["hero", Looks.PLAYER, Vector3(-0.3, 0, 2.6), "Dance"], ["sinikka", Looks.SINIKKA, Vector3(0.5, 0, 2.9), "Dance"],
		["pekka", Looks.PEKKA, Vector3(-1.9, 0, 0.9), "Idle_Talking"], ["arto", Looks.ARTO, Vector3(-1.3, 0, 1.7), "Idle_Talking"]]
	_party.clear()
	for c in cast:
		var ch := Looks.make(g, c[1])
		if c[0] == "hero":
			Looks.add_cap(ch)
		ch.position = c[2]
		ch.play(c[3], 0.0)
		ch.attach("hand_r", _wine_glass(), Vector3(0, -0.03, 0.04))
		_party[c[0]] = ch
	_face(_party.hero, _party.sinikka.position)
	_face(_party.sinikka, _party.hero.position)
	_face(_party.pekka, _party.arto.position)
	_face(_party.arto, _party.pekka.position)
