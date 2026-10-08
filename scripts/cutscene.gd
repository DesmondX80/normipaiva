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

const SAUNA_LINES := ["Löyly puree korvia. Ei kiirettä mihinkään.", "Savun ja tervan tuoksu. Ihan puhdas olo.",
	"Ei tätä kaupungissa saa.", "Hartiat rentoutuu vihdoinkin.", "Hiki virtaa selässä. Hiljaista."]
## Rungon kehyksessä (mokki.gd _build_savusauna): ylälaude takaseinällä, kiuas oven vieressä, kiulu alalauteella.
const SAUNA_HERO := Vector3(0.5, 0.6, -0.75)
const SAUNA_STONES := Vector3(0.9, 1.02, 0.5)
const SAUNA_KIULU_W := Vector3(1.15, 0.76, -0.15)
const LADLE_LEN := 0.78
## Saunan asettelu rungon kehyksessä (oletus savusauna). hero = istumapaikka, face = katseen suunta, stones = kivet,
## over = kauhan kaatokohta, kiulu = vesi, rest_cup = kauhan lepopaikka, ember / window = valot, coals = hiillos
## pesässä (null = ei näkyvää pesää), kiulu_prop = kiulu tuodaan mukana, shell = välianimaation seinät ja katto
## (Rect2 x/z, korkeus; null = saunalla omat), shots = kamerakuvat [alku, loppu, katse alku, katse loppu, s] (yleis,
## kiuas, lähi, vetäytyvä). Santtu tuo kaljat: door = ovelta sisään (reitti), stand = ojentaa kaljan, seat = viereen
## lauteelle, santtu_shot = kuva ovelle.
const SAUNA_SAVU := {
	"title": "SAVUSAUNA", "intro": "Hämärä, noen ja tervan tuoksu. Kiuas hehkuu.",
	"hero": SAUNA_HERO, "face": Vector3(0, 0, 1), "stones": SAUNA_STONES, "over": SAUNA_STONES + Vector3(-0.05, 0.28, -0.05),
	"kiulu": SAUNA_KIULU_W, "rest_cup": Vector3(0.82, 0.62, -0.3), "kiulu_prop": false,
	"ember": SAUNA_STONES + Vector3(-0.55, -0.55, 0.0), "ember_shadow": true, "window": Vector3(-1.4, 1.25, -0.3),
	"coals": Vector3(0.82, 0.08, 0.32), "haze": Vector3(0, 1.75, 0), "haze_ext": Vector3(1.4, 0.15, 1.2), "shell": null,
	"shots": [[Vector3(-1.3, 1.25, 1.2), Vector3(-1.15, 1.3, 0.95), Vector3(0.4, 1.0, -0.5), Vector3(0.5, 1.15, -0.55), 4.0],
		[Vector3(-0.75, 1.35, 0.55), Vector3(-0.7, 1.3, 0.5), Vector3(0.85, 0.95, 0.15), Vector3(0.85, 1.0, 0.2), 4.0],
		[Vector3(0.05, 1.5, 0.15), Vector3(0.15, 1.55, -0.05), Vector3(0.5, 1.55, -0.75), Vector3(0.5, 1.6, -0.75), 4.5],
		[Vector3(-1.0, 1.4, 0.9), Vector3(-1.3, 1.45, 1.2), Vector3(0.6, 1.0, -0.2), Vector3(0.5, 1.1, -0.4), 7.0]],
	"door": [Vector3(-0.8, 0.12, 2.1), Vector3(-0.8, 0.09, 0.95)], "stand": Vector3(-0.2, 0.09, 0.42),
	"seat": Vector3(-0.45, 0.6, -0.75),
	"santtu_shot": [Vector3(1.3, 1.55, -0.95), Vector3(1.2, 1.5, -0.85), Vector3(-0.7, 1.0, 1.2), Vector3(-0.2, 1.0, 0.3), 6.0],
}
const SAUNA_SANTTU_IN := ["Mahtuuko tänne? Otin kylmät mukaan.", "Löylyä ilman kaljaa? Ei meidän mökillä.",
	"Kuulin ku kiuas sihahti. Tässä, kylmää."]
const SAUNA_SANTTU_SIT := ["Kippis! Tää on mökin paras hetki.", "Aaah. Tätä varten tää mökki on olemassa.",
	"Heitä vielä yks, ei se meitä tapa."]


## Saunavaatteet: paljas, löylystä punertava iho ja valkoinen pyyhe lanteilla.
static func sauna_look(base: Dictionary) -> Dictionary:
	var look: Dictionary = base.duplicate()
	look.erase("tracksuit")
	look.merge({"stripes": false, "shine": 0.0, "tube_y": 0.01, "shorts_y": 0.72,
		"pants": Color(0.9, 0.88, 0.84), "shoes": Color(0.86, 0.62, 0.52), "bare_skin": Color(0.96, 0.68, 0.58)}, true)
	return look


## Löylyssä käynti: hämärä savusauna sisältä, kiuas hehkuu. Hahmo istuu ylälauteella, heittää pitkävartisella
## kauhalla löylyä kiukaalle ja nauttii rauhassa; kalja mukana, niin hörppy löylyn päälle. frame = saunan
## rungon kehys (Mokki.sauna_frame). Lyhyt tunnelmapala, ei päivän lopetus (ks. main.gd _sauna_cutscene).
## lay = saunan asettelu (SAUNA_SAVU:n avaimet korvaavat, esim. mökin sisäsauna), santtu = Santtu tulee löylyihin ja
## tuo kaljat, hide = välianimaation ajaksi piilotettavat solmut (esim. sisätilan kävelijä).
func sauna_relax(frame: Transform3D, has_beer: bool, done: Callable, lay: Dictionary = {}, santtu := false,
		hide: Array = []) -> void:
	var L: Dictionary = SAUNA_SAVU.merged(lay, true)
	_begin()
	await _fade_to(1.0, 0.4)
	_cam.current = true
	_cam.fov = 58.0
	for n in hide_nodes:
		if is_instance_valid(n):
			n.visible = false
	var hidden: Array = []
	for n in hide:
		if is_instance_valid(n) and n.visible:
			n.visible = false
			hidden.append(n)
	var at := func(p: Vector3) -> Vector3: return frame * p
	# Hahmon oma kehys: paikat (kalja, pyyhe) annetaan kuin istuisi kasvot +Z:aan, kääntö katseen suuntaan.
	var hero_rot := Basis(Vector3.UP, B.yaw_to(L.face) - PI)
	var hl := func(v: Vector3) -> Vector3: return frame * (L.hero + hero_rot * v)
	if L.shell != null:
		_sauna_shell(frame, L.shell)
	# Hämärä: aurinko ja taivaan valo pois, valo tulee hiillokselta ja pienestä ikkunasta.
	var saved := [sun.light_energy, env.ambient_light_energy, env.glow_intensity, env.glow_bloom, env.reflected_light_source]
	sun.light_energy = 0.12
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED  # ei sinistä taivasheijastusta tervatuista hirsistä
	env.ambient_light_energy = 0.14
	env.glow_intensity = 0.8
	env.glow_bloom = 0.12
	var ember := OmniLight3D.new()
	ember.light_color = Color(1.0, 0.45, 0.16)
	ember.light_energy = 1.6
	ember.omni_range = 3.6
	ember.omni_attenuation = 1.4
	ember.shadow_enabled = L.ember_shadow
	_props.add_child(ember)
	ember.global_position = at.call(L.ember)
	var window := OmniLight3D.new()
	window.light_color = Color(0.62, 0.74, 1.0)
	window.light_energy = 0.9
	window.omni_range = 3.4
	_props.add_child(window)
	window.global_position = at.call(L.window)
	if L.coals != null:
		for k in 7:  # hiillos pesässä
			B.mesh(_props, B.sphere(0.035 + (k % 3) * 0.012, 6), at.call(L.coals + Vector3((k % 3) * 0.1, 0, k * 0.05)),
				Color.WHITE).material_override = B.unshaded(Color(1.6, 0.45 + (k % 2) * 0.2, 0.08))
	if L.kiulu_prop:
		var ki: Vector3 = L.kiulu - Vector3(0, 0.12, 0)
		B.mesh(_props, B.cyl(0.13, 0.1, 0.24, 10), at.call(ki), Color(0.55, 0.4, 0.25))
		B.mesh(_props, B.cyl(0.12, 0.12, 0.01, 10), at.call(ki + Vector3(0, 0.1, 0)), Color(0.3, 0.38, 0.42))
	# Ylälauteella, kasvot oveen ja kiukaaseen päin (savusaunassa +Z). Kiuas jää vasemmalle kädelle.
	var hero := Looks.make(_props, sauna_look(Looks.PLAYER))
	hero.global_position = at.call(L.hero)
	hero.global_rotation.y = frame.basis.get_euler().y + B.yaw_to(L.face)
	hero.play("Sitting_Idle", 0.0)
	var ladle := Node3D.new()
	B.tube(ladle, Vector3.ZERO, Vector3(0, 0, -LADLE_LEN), 0.014, Color(0.55, 0.42, 0.26))
	B.mesh(ladle, B.cyl(0.06, 0.045, 0.06, 10), Vector3(0, 0.0, -LADLE_LEN), Color(0.5, 0.36, 0.22))
	_props.add_child(ladle)
	var can_rest: Vector3 = hl.call(Vector3(-0.42, 0.5, -0.05))  # oikean reiden vieressä lauteella
	var can: Node3D
	if has_beer and not santtu:
		can = B.mesh(_props, B.cyl(0.033, 0.033, 0.12, 12), can_rest, Color(0.8, 0.75, 0.2))
	# Kädet IK:lla: vasen ohjaa kauhan kuppia (cup), oikea tuo kaljan suulle (sip 0..1).
	var st := {"cup": Vector3.ZERO, "pour": 0.0, "lean": 0.0, "back": 0.0, "sip": 0.0, "t": 0.0, "shot": 0, "can": can}
	var rest_cup: Vector3 = at.call(L.rest_cup)  # kauha kiulun vieressä nojallaan
	st.cup = rest_cup
	var upd := func() -> void:
		if not is_instance_valid(hero):
			return
		st.t += get_process_delta_time()
		ember.light_energy = 1.5 + 0.18 * sin(st.t * 7.0) + 0.1 * sin(st.t * 17.3)
		hero.set_override("spine_01", Vector3.RIGHT, st.lean * 0.35 - st.back * 0.12)
		hero.set_override("neck_01", Vector3.RIGHT, st.back * 0.4 + st.sip * 0.3)
		var sh: Vector3 = hero.to_global(hero.bone_position("upperarm_l"))
		var cup: Vector3 = st.cup
		var hand := cup - (cup - sh).normalized() * LADLE_LEN
		var side: Vector3 = hero.global_basis.x * -0.45
		var cn: Node3D = st.get("can")  # oma tai Santun tuoma kalja
		hero.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", hero.to_local(hand), hero.to_local(sh + side + Vector3(0, -0.4, 0)))
		var grip: Vector3 = hero.to_global(hero.bone_position("hand_l"))
		ladle.global_position = grip
		if grip.distance_to(cup) > 0.05:
			ladle.look_at(cup, Vector3.UP)
			ladle.rotate_object_local(Vector3.FORWARD, st.pour)
		if cn != null and st.sip > 0.0:
			var head: Vector3 = hero.to_global(hero.bone_position("Head"))
			var mouth := head + hero.global_basis.z * -0.12 + Vector3(0, -0.06, 0)
			var shr: Vector3 = hero.to_global(hero.bone_position("upperarm_r"))
			var goal := can_rest.lerp(mouth, st.sip)
			hero.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", hero.to_local(goal),
				hero.to_local(shr + hero.global_basis.x * 0.4 + Vector3(0, -0.4, 0)))
			cn.global_position = hero.to_global(hero.bone_position("hand_r")) + Vector3(0, 0.02, 0)
			cn.global_rotation = Vector3(0, 0, 0)
			cn.rotate_object_local(Vector3.RIGHT, -1.6 * st.sip)
	get_tree().process_frame.connect(upd)
	var glide := func(key: String, to: Variant, sec: float) -> Tween:
		var t := _tween()
		t.tween_method(func(v: Variant) -> void: st[key] = v, st[key], to, sec).set_trans(Tween.TRANS_SINE)
		return t
	# Löylyhöyry: kiukaalta purkautuva pilvi ja hiljalleen leijuva usva katon rajassa.
	# Pehmeät höyrytupsut: kameraan kääntyvä taso, jossa säteittäin häipyvä valkoinen.
	var puff_tex := GradientTexture2D.new()
	puff_tex.fill = GradientTexture2D.FILL_RADIAL
	puff_tex.fill_from = Vector2(0.5, 0.5)
	puff_tex.fill_to = Vector2(1.0, 0.5)
	var pg := Gradient.new()
	pg.set_color(0, Color(1, 1, 1, 0.55))
	pg.set_color(1, Color(1, 1, 1, 0.0))
	pg.add_point(0.45, Color(1, 1, 1, 0.25))
	puff_tex.gradient = pg
	var steam_mat := StandardMaterial3D.new()
	steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_mat.vertex_color_use_as_albedo = true
	steam_mat.albedo_texture = puff_tex
	steam_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	steam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # varjostettuna hiilloksen vastavalo tummentaa
	steam_mat.albedo_color = Color(0.62, 0.55, 0.5)
	steam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var make_steam := func(amount: int, life: float, vel: float, sz: float, burst: bool) -> CPUParticles3D:
		var p := CPUParticles3D.new()
		p.one_shot = burst
		p.emitting = not burst
		p.visible = not burst
		p.amount = amount
		p.lifetime = life
		p.direction = Vector3.UP
		p.spread = 40.0
		p.initial_velocity_min = vel * 0.5
		p.initial_velocity_max = vel
		p.gravity = Vector3(0, 0.15, 0)
		p.damping_min = vel * 0.4
		p.damping_max = vel * 0.7
		p.scale_amount_min = sz * 0.6
		p.scale_amount_max = sz
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.3))
		curve.add_point(Vector2(1, 1.6))
		p.scale_amount_curve = curve
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0.0))
		ramp.set_color(1, Color(1, 1, 1, 0.0))
		ramp.add_point(0.15, Color(1, 1, 1, 0.8))
		p.color_ramp = ramp
		var qm := QuadMesh.new()
		qm.size = Vector2(0.5, 0.5)
		qm.material = steam_mat
		p.mesh = qm
		_props.add_child(p)
		return p
	var haze: CPUParticles3D = make_steam.call(24, 6.0, 0.08, 1.6, false)
	haze.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	haze.emission_box_extents = L.haze_ext
	haze.global_position = at.call(L.haze)
	haze.preprocess = 6.0  # kaikki tupsut elossa heti: syntymättömät piirtyisivät mustina
	var puff: CPUParticles3D = make_steam.call(70, 3.4, 1.3, 1.8, true)
	puff.explosiveness = 1.0
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 0.2
	puff.global_position = at.call(L.stones)
	var drops := CPUParticles3D.new()
	drops.amount = 18
	drops.lifetime = 0.45
	drops.one_shot = true
	drops.emitting = false
	drops.explosiveness = 0.6
	drops.direction = Vector3.DOWN
	drops.spread = 15.0
	drops.initial_velocity_min = 0.3
	drops.initial_velocity_max = 0.8
	drops.gravity = Vector3(0, -9.0, 0)
	var dm := SphereMesh.new()
	dm.radius = 0.012
	dm.height = 0.024
	dm.material = B.unshaded(Color(0.75, 0.85, 1.0, 0.8))
	drops.mesh = dm
	_props.add_child(drops)
	var throw := func(lines: Array) -> void:
		glide.call("lean", 1.0, 0.8)
		await (glide.call("cup", at.call(L.kiulu), 0.8) as Tween).finished
		Sfx.play("water", -10.0, 1.4, 0.4)
		await _wait(0.25)
		var over: Vector3 = at.call(L.over)
		await (glide.call("cup", over, 0.8) as Tween).finished
		glide.call("pour", 2.2, 0.3)
		drops.global_position = over
		drops.restart()
		await _wait(0.22)
		puff.visible = true
		puff.restart()
		get_tree().create_timer(puff.lifetime - 0.05, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(puff):
				puff.visible = false)
		Sfx.play("water", -4.0, 2.4, 0.9)
		Sfx.play("whoosh", -6.0, 0.45)
		_sub.text = lines[0]
		var flare := _tween()
		flare.tween_property(env, "glow_intensity", 1.3, 0.15)
		flare.tween_property(env, "glow_intensity", 0.8, 1.2)
		await _wait(0.5)
		glide.call("pour", 0.0, 0.4)
		glide.call("lean", 0.0, 0.9)
		await (glide.call("cup", rest_cup, 0.9) as Tween).finished
	# Kameraliike sec sekunnissa; uusi kuva (shot-laskuri) katkaisee edellisen liikkeen.
	var cam_move := func(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, sec: float) -> void:
		st.shot += 1
		var my: int = st.shot
		var t0 := Time.get_ticks_msec()
		while my == st.shot:
			var u := clampf((Time.get_ticks_msec() - t0) / (sec * 1000.0), 0.0, 1.0)
			var e := u * u * (3.0 - 2.0 * u)
			_cam.global_position = at.call(from.lerp(to, e))
			_cam.look_at(at.call(look_from.lerp(look_to, e)), Vector3.UP)
			if u >= 1.0 or not busy:
				break
			await get_tree().process_frame
	var shot := func(k: int) -> void:
		var sh: Array = L.shots[k] if k >= 0 else L.santtu_shot
		cam_move.call(sh[0], sh[1], sh[2], sh[3], sh[4])
	_title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.42))
	_title.add_theme_font_size_override("font_size", 70)
	# 1. Yleiskuva oven pielestä: hämärä, hiillos hehkuu, hahmo ylälauteella.
	shot.call(0)
	await _fade_to(0.0, 0.8)
	_title.text = L.title
	_sub.text = L.intro
	await _wait(2.6)
	_title.text = ""
	# 2. Kauhallinen kiukaalle: kuva sivusta kivien ja kauhan tasolta.
	shot.call(1)
	_sub.text = "Kauhallinen vettä kiukaalle..."
	await throw.call(["Tsssshhhh!"])
	# 3. Lähikuva: nojaa taaksepäin, silmät kiinni, löyly laskeutuu hartioille.
	shot.call(2)
	glide.call("back", 1.0, 1.4)
	_sub.text = "Löyly laskeutuu hartioille. Aaahh."
	await _wait(2.4)
	_sub.text = SAUNA_LINES.pick_random()
	await _wait(2.2)
	if santtu:
		# 3b. Santtu tulee ovesta pyyhe lanteilla, ojentaa kylmän kaljan ja istuu viereen.
		glide.call("back", 0.0, 0.6)
		shot.call(-1)
		await _sauna_santtu(frame, L, hero, st)
		has_beer = true
	# 4. Toinen kauhallinen ja hörppy kaljaa, kamera vetäytyy hitaasti.
	glide.call("back", 0.0, 0.6)
	shot.call(3)
	await throw.call(["Toinen kauhallinen. Lämpö nousee korviin."])
	if has_beer:
		_sub.text = "Hörppy kylmää kaljaa löylyn päälle."
		await (glide.call("sip", 1.0, 0.7) as Tween).finished
		Sfx.play("pickup", -4.0, 0.9)
		await _wait(0.6)
		await (glide.call("sip", 0.0, 0.7) as Tween).finished
		await _wait(0.4)
	else:
		glide.call("back", 0.8, 1.2)
		_sub.text = SAUNA_LINES.pick_random()
		await _wait(2.0)
	_sub.text = ""
	await _end(func() -> void:
		get_tree().process_frame.disconnect(upd)
		for n in hidden:
			if is_instance_valid(n):
				n.visible = true
		sun.light_energy = saved[0]
		env.ambient_light_energy = saved[1]
		env.glow_intensity = saved[2]
		env.glow_bloom = saved[3]
		env.reflected_light_source = saved[4]
		_cam.fov = 50.0
		done.call())
	_title.add_theme_font_size_override("font_size", 150)


## Santtu löylyihin: ovelta sisään (L.door), ojentaa kaljan hahmolle (st.can, IK:n kalja) ja istuu viereen (L.seat)
## oma kalja kädessä.
func _sauna_santtu(frame: Transform3D, L: Dictionary, hero: Node3D, st: Dictionary) -> void:
	var at := func(p: Vector3) -> Vector3: return frame * p
	var s: Node3D = Looks.make(_props, sauna_look(load("res://scripts/mokki.gd").SANTTU_LOOK))
	var path: Array = L.door + [L.stand]
	s.global_position = at.call(path[0])
	s.play("Walk", 0.0)
	var own := Node3D.new()
	B.mesh(own, B.cyl(0.033, 0.033, 0.12, 12), Vector3.ZERO, Color(0.8, 0.75, 0.2))
	s.attach("hand_r", own, Vector3(0, -0.02, 0.05))
	var gift := Node3D.new()
	B.mesh(gift, B.cyl(0.033, 0.033, 0.12, 12), Vector3.ZERO, Color(0.8, 0.75, 0.2))
	var gift_bone: Node3D = s.attach("hand_l", gift, Vector3(0, -0.02, 0.05))
	Sfx.play("door", -6.0, 0.9)
	_sub.text = "Ovi narahtaa..."
	for i in range(1, path.size()):
		var a: Vector3 = at.call(path[i - 1])
		var b: Vector3 = at.call(path[i])
		s.global_rotation.y = B.yaw_to(b - a)
		var tw := _tween()
		tw.tween_property(s, "global_position", b, a.distance_to(b) / 1.3)
		await tw.finished
	var hp := hero.global_position
	s.global_rotation.y = B.yaw_to(Vector3(hp.x, 0, hp.z) - Vector3(s.global_position.x, 0, s.global_position.z))
	s.play("Interact", 0.25)
	_sub.text = "Santtu: \"%s\"" % SAUNA_SANTTU_IN.pick_random()
	await _wait(0.9)
	# Kalja Santun kädestä hahmon viereen lauteelle; IK nostaa sen myöhemmin suulle.
	var from: Vector3 = gift.global_position
	gift_bone.queue_free()
	var can := B.mesh(_props, B.cyl(0.033, 0.033, 0.12, 12), from, Color(0.8, 0.75, 0.2))
	var rest: Vector3 = frame * (L.hero + Basis(Vector3.UP, B.yaw_to(L.face) - PI) * Vector3(-0.42, 0.5, -0.05))
	var tw2 := _tween()
	tw2.tween_property(can, "global_position", rest, 0.7).set_trans(Tween.TRANS_SINE)
	Sfx.play("pickup", -6.0, 1.1)
	await tw2.finished
	st.can = can
	await _wait(1.0)
	# Viereen lauteelle.
	s.play("Walk", 0.2)
	var seat: Vector3 = at.call(L.seat)
	s.global_rotation.y = B.yaw_to(seat - s.global_position)
	var tw3 := _tween()
	tw3.tween_property(s, "global_position", seat, 0.9).set_trans(Tween.TRANS_SINE)
	await tw3.finished
	s.global_rotation.y = frame.basis.get_euler().y + B.yaw_to(L.face)
	s.play("Sitting_Idle", 0.3)
	Sfx.play("pickup", -4.0, 0.8)
	_sub.text = "Santtu: \"%s\"" % SAUNA_SANTTU_SIT.pick_random()
	await _wait(2.4)


## Välianimaation saunahuone (sisätiloissa ilman kattoa ja matalin seinin): tummat paneeliseinät, oviaukko ja katto.
## shell = [Rect2(x, z, leveys, syvyys), korkeus, oviaukko Vector2(x alku, x loppu) seinässä z = rect.position.y].
func _sauna_shell(frame: Transform3D, shell: Array) -> void:
	var r: Rect2 = shell[0]
	var h: float = shell[1]
	var door: Vector2 = shell[2]
	var col := Color(0.24, 0.17, 0.11)
	var t := 0.06
	var x0 := r.position.x - t / 2.0
	var x1 := r.end.x + t / 2.0
	var z0 := r.position.y - t / 2.0
	var z1 := r.end.y + t / 2.0
	var part := func(size: Vector3, c: Vector3) -> void:
		var m := B.mesh(_props, B.boxm(size), frame * c, col)
		m.global_basis = frame.basis
	part.call(Vector3(x1 - x0, h, t), Vector3((x0 + x1) / 2.0, h / 2.0, z1))
	part.call(Vector3(t, h, z1 - z0), Vector3(x0, h / 2.0, (z0 + z1) / 2.0))
	part.call(Vector3(t, h, z1 - z0), Vector3(x1, h / 2.0, (z0 + z1) / 2.0))
	part.call(Vector3(door.x - x0, h, t), Vector3((x0 + door.x) / 2.0, h / 2.0, z0))
	part.call(Vector3(x1 - door.y, h, t), Vector3((door.y + x1) / 2.0, h / 2.0, z0))
	part.call(Vector3(door.y - door.x, h - 2.0, t), Vector3((door.x + door.y) / 2.0, (h + 2.0) / 2.0, z0))
	part.call(Vector3(x1 - x0, t, z1 - z0), Vector3((x0 + x1) / 2.0, h, (z0 + z1) / 2.0))


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


# --- Junamatka ravintolavaunussa ----------------------------------------------------

const TRAIN_POS := Vector3(-12000, 0, -9000)  # oma tasku (ennen sama kuin autotallin sisätila: talli näkyi kuvissa)
const Train := preload("res://scripts/train.gd")
const MARJA := {
	"model": "female", "shirt": Color(0.2, 0.42, 0.68), "pants": Color(0.16, 0.16, 0.2), "shoes": Color(0.12, 0.1, 0.1),
	"hair": "Hair_Long", "hair_color": Color(0.42, 0.26, 0.14), "height": 1.68,
}
const LIISA := {
	"model": "female", "shirt": Color(0.9, 0.56, 0.18), "pants": Color(0.3, 0.26, 0.22), "shoes": Color(0.3, 0.2, 0.15),
	"hair": "Hair_Buns", "hair_color": Color(0.9, 0.8, 0.52), "height": 1.64,
}
const HELENA := {
	"model": "female", "shirt": Color(0.55, 0.15, 0.35), "pants": Color(0.12, 0.12, 0.15), "shoes": Color(0.1, 0.1, 0.1),
	"hair": "Hair_Long", "hair_color": Color(0.1, 0.08, 0.07), "height": 1.7,
}
const WAITER := {
	"shirt": Color(0.95, 0.95, 0.95), "pants": Color(0.1, 0.1, 0.12), "shoes": Color(0.05, 0.05, 0.05),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.3, 0.25, 0.2), "height": 1.8,
}
## Ravintolavaunun jutustelu: [puhuja, repliikki]; puhuja "minä", "marja", "liisa", "helena" tai "tarjoilija".
## Pelaaja juo olutta ja tarjoaa naisille Koskenkorvat; kolmas kenttä "treat" = repliikki, joka vaihtuu
## TRAIN_NO_TREAT:iin, jos rahat eivät riitä tarjoamiseen (naiset ostavat paukkunsa itse); "hand" = paukun
## jälkeen vieressä istuva Helena laskee kätensä pelaajan reidelle (IK) ja pitää sen siinä loppumatkan.
const TRAIN_TALK_VAALA := [
	["marja", "Onko tässä vapaata? Ravintolavaunusta näkee parhaiten."], ["minä", "Istukaa toki! Tuoppi on just kaadettu."],
	["liisa", "Oletko menossa Vaalaan asti?"], ["minä", "Oulujärven rantaan, Paapeliin. Mökillä odottaa sauna."],
	["tarjoilija", "Saako naisille olla jotain? Olutta, Koskenkorvaa?"],
	["minä", "Kolme Koskenkorvaa naisille, minun piikkiin!", "treat"], ["helena", "No voi kiitos! Kippis!"],
	["helena", "Sinä olet kyllä mukava mies.", "hand"], ["minä", "Tuota... Juna on kyllä mukava kulkuväline."],
	["marja", "Kippis! Oulujärven auringonlasku on maailman kaunein."], ["liisa", "Sinä olet kyllä mukavaa seuraa."],
	["minä", "Ja te kauniimpia kuin Salmisen ranta."], ["marja", "Hyvää matkaa, ja terveisiä Siitarin karaokeen!"],
]
const TRAIN_TALK_SALOINEN := [
	["helena", "Hei! Saanko istua? Tässä on niin kiva valo."], ["minä", "Tottahan toki. Mulla on tuoppi, otatteko jotain?"],
	["tarjoilija", "Olutta vai jotain vahvempaa?"], ["minä", "Kolme Koskenkorvaa naisille, minä tarjoan!", "treat"],
	["marja", "Kippis! Menetkö kotiin Saloisiin?"], ["helena", "Älä vielä mene. Matkaa on jäljellä.", "hand"], ["minä", "Kotiin. Kuusi kaljaa ja nurmikko odottaa."],
	["liisa", "Sinulla on hauska tapa kertoa asioista."], ["minä", "Ja teidän kanssanne matka meni hetkessä."],
	["helena", "Hyvää kotimatkaa! Oli ilo jutella."],
]
const TRAIN_NO_TREAT := "Tarjoaisin teille paukut, mutta lompakko on laiha. Ottakaa omat, kippis silti!"


## Junamatka Saloisten ja Vaalan asemien välillä kolmessa osassa: lähtö (Saloisista Raahen terästehtaan ohi,
## Vaalasta Oulujoen ristikkosillan yli), ravintolavaunussa jutellaan mukavia naismatkustajien kanssa (kahvia ja
## pullaa, maisema vilistää ikkunoissa) ja saapuminen (Vaalaan sillan yli, Saloisiin terästehtaan ohi).
## Taustalla soi lirkuttelubiisi. done kutsutaan pimeällä.
func train_ride(to_vaala: bool, done: Callable, treat := true) -> void:
	_begin()
	Sfx.play("door_close", -4.0)
	Sfx.music_play(0.8, 0.0, Sfx.SONG_LIRKUTTELU)
	await _fade_to(1.0, 0.4)
	var rumble := AudioStreamPlayer.new()
	rumble.stream = Sfx.stream("tractor_engine")
	rumble.pitch_scale = 0.42
	rumble.volume_db = -6.0
	rumble.bus = "SFX"
	_props.add_child(rumble)
	rumble.play()
	_cam.current = true
	_title.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_title.add_theme_font_size_override("font_size", 80)
	# 1) Lähtö.
	await _train_outside("steel" if to_vaala else "bridge", "JUNALLA VAALAAN" if to_vaala else "JUNALLA SALOISIIN",
		"Raahen terästehdas savuaa radan varressa." if to_vaala else "Oulujoen rautatiesilta. Vaala jää taakse.")
	# 2) Ravintolavaunu sisältä.
	var car := Node3D.new()
	car.position = TRAIN_POS + Vector3(0, 40, 0)
	_props.add_child(car)
	var cast := _build_dining_car(car)
	var scenery: Node3D = cast.scenery
	await _fade_to(0.0, 0.5)
	var lines: Array = TRAIN_TALK_VAALA if to_vaala else TRAIN_TALK_SALOINEN
	const LINE := 2.3
	const SPEED := 24.0
	var hand_from := lines.size()
	for i in lines.size():
		if lines[i].size() > 2 and lines[i][2] == "hand":
			hand_from = i
	var hand := {"w": 0.0, "rest": Vector3.ZERO}
	var t0 := Time.get_ticks_msec()
	var last := -1
	while Time.get_ticks_msec() - t0 < lines.size() * LINE * 1000.0:
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		scenery.position.z = fposmod(t * SPEED, 120.0)  # maisema vilistää ikkunoissa
		car.position.y = TRAIN_POS.y + 40.0 + sin(t * 11.0) * 0.008  # kiskojen tasainen tärinä
		var k := mini(int(t / LINE), lines.size() - 1)
		var who: String = lines[k][0]
		var ch: Node3D = cast[who]
		if k != last:
			last = k
			for nm in ["marja", "liisa", "helena", "minä"]:
				(cast[nm] as Node3D).play("Sitting_Talking" if nm == who else "Sitting_Idle", 0.3)
		var names := {"minä": "Sinä", "marja": "Marja", "liisa": "Liisa", "helena": "Helena", "tarjoilija": "Tarjoilija"}
		var line: String = TRAIN_NO_TREAT if lines[k].size() > 2 and lines[k][2] == "treat" and not treat else lines[k][1]
		_sub.text = "%s: %s" % [names[who], line]  # tekstitys alareunassa (kupla leikkautui lähikuvissa)
		# Kamerat: leveä sivukuva käytävältä pöydän poikki (selkänojat eivät peitä), muuten puhujaa vastapäätä
		# istuvien olan yli kevyesti liukuen.
		var u := fmod(t, LINE) / LINE
		if k >= hand_from:
			# Helenan oikea käsi pelaajan vasemmalle reidelle: lepoasennosta liukuen polven ja lantion väliin.
			var hl: Node3D = cast.helena
			var hero: Node3D = cast["minä"]
			if hand.w == 0.0:
				hand.rest = hl.to_global(hl.bone_position("hand_r"))
			hand.w = minf(1.0, hand.w + get_process_delta_time() * 1.4)
			var hip: Vector3 = hero.to_global(hero.bone_position("thigh_l"))
			var knee: Vector3 = hero.to_global(hero.bone_position("calf_l"))
			var side: Vector3 = hl.global_position - hero.global_position
			side.y = 0.0
			var on_thigh: Vector3 = hip.lerp(knee, 0.55) + Vector3(0, 0.2, 0) + side.normalized() * 0.04  # ranne reiden pinnan yllä (reisi on paksu, kämmen ei saa upota)
			var goal: Vector3 = (hand.rest as Vector3).lerp(on_thigh, smoothstep(0.0, 1.0, hand.w))
			var sh: Vector3 = hl.to_global(hl.bone_position("upperarm_r"))
			hl.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", hl.to_local(goal),
				hl.to_local(sh + Vector3(0, -0.4, 0) + hl.global_basis.z * 0.25))
		if k == hand_from or k == hand_from + 1:
			# Käsi reidellä: kurkistus pöydän alta vastapäätä (pöytälevy peittää sylin ylhäältä).
			_cam.global_position = car.to_global(Vector3(lerpf(-0.3, -0.38, u), 0.58, lerpf(-0.42, -0.5, u)))
			_cam.look_at(car.to_global(Vector3(-0.85, 0.6, 0.75)), Vector3.UP)
		elif who == "tarjoilija" or k % 3 == 2:
			_cam.global_position = car.to_global(Vector3(1.15, 1.35, lerpf(0.35, -0.35, u)))
			_cam.look_at(car.to_global(Vector3(-0.85, 1.0, 0.0)), Vector3.UP)
		elif who in ["marja", "liisa"]:
			_cam.global_position = car.to_global(Vector3(lerpf(0.15, 0.05, u), 1.45, 1.6))
			_cam.look_at(ch.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		else:
			_cam.global_position = car.to_global(Vector3(lerpf(0.1, 0.0, u), 1.45, -1.6))
			_cam.look_at(ch.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		await get_tree().process_frame
	await _fade_to(1.0, 0.4)
	_sub.text = ""
	car.queue_free()
	# 3) Saapuminen.
	await _train_outside("bridge" if to_vaala else "steel", "", "Oulujoen silta. Kohta Vaalan asemalla." if to_vaala
		else "Raahen terästehtaan ohi. Kohta Saloisten asemalla.")
	rumble.stop()
	await _end(done)
	_title.add_theme_font_size_override("font_size", 150)


## Juna (Sr1 ja neljä sinistä vaunua, keula -Z) välikuviin.
func _cut_train(parent: Node3D) -> Node3D:
	var train := Node3D.new()
	parent.add_child(train)
	var off := 0.0
	for spec in [["loco", 18.96], ["coach", 26.4], ["coach", 26.4], ["dining", 26.4], ["coach", 26.4]]:
		var u := Node3D.new()
		train.add_child(u)
		if spec[0] == "loco":
			Train.build_loco(u, spec[1])
		else:
			Train.build_coach(u, spec[1], spec[0] == "dining")
		u.position.z = off + float(spec[1]) / 2.0
		off += float(spec[1]) + 0.8
	return train


## Ulkokuva junasta: "steel" = Raahen terästehdas (savuavat piiput, masuuni, ruostuneet hallit, saastunut maa ja
## ruskea savusumu) tai "bridge" = Oulujoen teräsristikkosilta Vaalassa (kamera joen rannalta). Pimeästä pimeään.
func _train_outside(kind: String, title: String, sub: String) -> void:
	var root := Node3D.new()
	root.position = TRAIN_POS + (Vector3(0, 0, 0) if kind == "steel" else Vector3(2000, 0, 0))
	_props.add_child(root)
	var puffs: Array = []
	var fog_saved := [env.fog_enabled, env.fog_light_color, env.fog_density, env.adjustment_saturation, env.fog_depth_begin,
		env.fog_depth_end]
	if kind == "steel":
		puffs = _build_steel_land(root)
		# Ruskea savusumu tehtaan yllä.
		env.fog_enabled = true
		env.fog_light_color = Color(0.5, 0.42, 0.33)
		env.fog_density = 0.02
		env.fog_depth_begin = 15.0
		env.fog_depth_end = 260.0
		env.adjustment_saturation = 0.6
	else:
		_build_bridge_land(root)
	var train := _cut_train(root)
	const SPEED := 24.0
	var t0 := Time.get_ticks_msec()
	var faded := false
	var honked := false
	while Time.get_ticks_msec() - t0 < 6500:
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		train.position.z = 80.0 - t * SPEED
		if kind == "steel":
			# Radan vierestä: veturi tulee kohti tehtaan edessä, vaunut lipuvat ohi savun alla.
			_cam.global_position = root.to_global(Vector3(14.0, 2.2, -45.0))
			var look_z := clampf(train.position.z + 15.0 + t * 5.0, -45.0, 90.0)
			_cam.look_at(root.to_global(Vector3(-8.0, 4.0 + t * 0.6, look_z)), Vector3.UP)
		else:
			# Joen rannalta matalalta: juna ylittää ristikkosillan.
			_cam.global_position = root.to_global(Vector3(42.0, -2.4, -6.0))
			_cam.look_at(root.to_global(Vector3(0.0, 2.5, clampf(train.position.z + 20.0, -40.0, 30.0))), Vector3.UP)
		for pf in puffs:
			var m: MeshInstance3D = pf[0]
			var base: Vector3 = pf[1]
			var ph: float = fmod(t * 0.25 + pf[2], 1.0)
			m.position = base + Vector3(ph * 9.0, ph * 30.0, ph * 4.0)
			m.scale = Vector3.ONE * (1.0 + ph * 3.5)
		if not faded:
			faded = true
			_fade_to(0.0, 0.6)
			_title.text = title
			_sub.text = sub
		if t > 3.0:
			_title.text = ""
		if t > 1.2 and not honked:
			honked = true
			Sfx.play("horn", -2.0, 0.48, 2.5)
		await get_tree().process_frame
	await _fade_to(1.0, 0.4)
	_title.text = ""
	_sub.text = ""
	env.fog_enabled = fog_saved[0]
	env.fog_light_color = fog_saved[1]
	env.fog_density = fog_saved[2]
	env.adjustment_saturation = fog_saved[3]
	env.fog_depth_begin = fog_saved[4]
	env.fog_depth_end = fog_saved[5]
	root.queue_free()


func _rails_along(r: Node3D, z0: float, z1: float, y: float) -> void:
	B.box(r, Vector3(4.2, 0.4, z1 - z0), Vector3(0, y, (z0 + z1) / 2.0), Color(0.4, 0.37, 0.33), false)
	var n := int((z1 - z0) / 0.8)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = B.boxm(Vector3(2.5, 0.12, 0.25))
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, y + 0.24, z0 + i * 0.8)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = B.mat(Color(0.38, 0.33, 0.28))
	r.add_child(mmi)
	for sx: float in [-0.72, 0.72]:
		B.box(r, Vector3(0.08, 0.14, z1 - z0), Vector3(sx, y + 0.36, (z0 + z1) / 2.0), Color(0.5, 0.45, 0.4), false)


## Raahen terästehdas radan varressa: harmaanruskea saastunut maa, oranssit lätäköt ja kuolleet puut, masuuni
## kehikkoineen, korkeat puna-valkoiset piiput ja savupilvet, ruostuneet hallit, kuljettimet, putkisillat, säiliöt
## sekä malmi- ja koksikasat. Palauttaa savupilvet [mesh, lähtöpaikka, vaihe] animointia varten.
func _build_steel_land(r: Node3D) -> Array:
	B.box(r, Vector3(600, 0.1, 600), Vector3(0, -0.06, -60), Color(0.3, 0.27, 0.24), false)
	_rails_along(r, -300, 220, 0.0)
	var rust := Color(0.45, 0.27, 0.18)
	var steel := Color(0.36, 0.36, 0.37)
	for i in 10:  # lätäköt
		var p := Vector3(randf_range(-60, 60), -0.0, randf_range(-250, 150))
		if absf(p.x) < 5.0:
			continue
		B.mesh(r, B.cyl(randf_range(2, 5), randf_range(2, 5), 0.05, 12), p, Color(0.7, 0.4, 0.12))
	for i in 25:  # kuolleet puut
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * randf_range(8, 30), 0, randf_range(-250, 180))
		var hgt := randf_range(5, 9)
		B.mesh(r, B.cyl(0.1, 0.18, hgt, 6), p + Vector3(0, hgt / 2.0, 0), Color(0.3, 0.28, 0.26))
		var br := B.mesh(r, B.cyl(0.03, 0.06, hgt * 0.4, 5), p + Vector3(0.6, hgt * 0.7, 0), Color(0.3, 0.28, 0.26))
		br.rotation.z = -0.8
	# Hallit radan länsipuolella.
	for i in 6:
		var z := 120.0 - i * 60.0
		var w := randf_range(30, 45)
		var hgt := randf_range(18, 30)
		B.box(r, Vector3(w, hgt, 50), Vector3(-45 - w / 2.0, hgt / 2.0, z), rust if i % 2 == 0 else steel, false)
		B.box(r, Vector3(w + 1, 1.2, 51), Vector3(-45 - w / 2.0, hgt, z), steel.darkened(0.3), false)
		for k in 4:
			B.box(r, Vector3(0.2, 3.0, 5.0), Vector3(-44.9, hgt * 0.6, z - 18.0 + k * 12.0), Color(0.15, 0.13, 0.12), false)
	# Masuuni: tumma torni kehikkoineen ja kuumailmakuupat.
	var bf := Vector3(-70, 0, -60)
	B.mesh(r, B.cyl(7.0, 9.0, 45.0, 16), bf + Vector3(0, 22.5, 0), Color(0.22, 0.2, 0.19))
	B.mesh(r, B.cyl(4.0, 7.0, 10.0, 16), bf + Vector3(0, 50.0, 0), Color(0.3, 0.26, 0.22))
	for k in 4:
		var a := TAU * k / 4.0
		B.mesh(r, B.cyl(0.5, 0.5, 60.0, 6), bf + Vector3(cos(a) * 11.0, 30.0, sin(a) * 11.0), steel)
		B.mesh(r, B.cyl(5.0, 5.0, 38.0, 14), bf + Vector3(-25.0, 19.0, -18.0 + k * 12.0), Color(0.48, 0.44, 0.4))  # kuupat
	# Piiput puna-valkoisin raidoin ja savu.
	var puffs: Array = []
	for cp in [Vector3(-70, 0, 60), Vector3(-110, 0, 20), Vector3(-95, 0, -110), Vector3(-130, 0, -40), Vector3(60, 0, -150)]:
		var hgt := 55.0 if cp.z > 40.0 else 85.0
		for band in 8:
			B.mesh(r, B.cyl(3.2 - band * 0.12, 3.3 - band * 0.12, hgt / 8.0, 14), cp + Vector3(0, hgt / 16.0 + band * hgt / 8.0, 0),
				Color(0.75, 0.12, 0.08) if band % 2 == 1 else Color(0.9, 0.9, 0.88))
		for k in 10:
			var pm := B.mesh(r, B.sphere(4.5, 10), cp + Vector3(0, hgt, 0), Color(0.42, 0.38, 0.35))
			var mat := B.mat(Color(0.4, 0.35, 0.3, 0.6)).duplicate() as StandardMaterial3D
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pm.material_override = mat
			puffs.append([pm, cp + Vector3(0, hgt + 2.0, 0), k / 10.0])
	# Kasat, kuljettimet ja säiliöt radan itäpuolella.
	for i in 5:
		var p := Vector3(randf_range(25, 70), 0, -220.0 + i * 70.0)
		var hgt := randf_range(8, 16)
		B.mesh(r, B.cyl(0.0, hgt * 1.4, hgt, 14), p + Vector3(0, hgt / 2.0, 0), Color(0.18, 0.16, 0.15) if i % 2 == 0 else Color(0.45, 0.25, 0.15))
	for i in 3:
		var cv := B.mesh(r, B.boxm(Vector3(3.0, 2.0, 80.0)), Vector3(-30 + i * 45, 14.0, -90 + i * 30), steel.darkened(0.2))
		cv.rotation.x = 0.18
		cv.rotation.y = 0.6 + i * 0.3
	for i in 3:
		B.mesh(r, B.cyl(9.0, 9.0, 14.0, 18), Vector3(30 + i * 22, 7.0, 120), Color(0.55, 0.52, 0.48))
	B.box(r, Vector3(160, 1.5, 2.0), Vector3(-10, 11.0, -170), rust, false)  # putkisilta radan yli
	for sx: float in [-40.0, 30.0]:
		B.box(r, Vector3(1.2, 11.0, 1.2), Vector3(sx, 5.5, -170), rust, false)
	var sun_l := OmniLight3D.new()
	sun_l.position = Vector3(0, 40, -60)
	sun_l.light_color = Color(1.0, 0.8, 0.6)
	sun_l.light_energy = 0.5
	sun_l.omni_range = 300.0
	r.add_child(sun_l)
	return puffs


## Oulujoki Vaalassa: rannat koivikkoineen, leveä joki, teräsristikkosilta (train.gd build_truss) penkereineen ja
## Vaalan talot ja kirkontorni joen takana.
func _build_bridge_land(r: Node3D) -> void:
	const RIVER := Vector2(-45.0, 25.0)  # joen z-väli
	const WATER_Y := -4.5
	B.box(r, Vector3(500, 6.0, 300), Vector3(0, -3.0, RIVER.y + 150.0), Color(0.33, 0.47, 0.22), false)
	B.box(r, Vector3(500, 6.0, 300), Vector3(0, -3.0, RIVER.x - 150.0), Color(0.33, 0.47, 0.22), false)
	B.box(r, Vector3(500, 0.05, RIVER.y - RIVER.x + 20.0), Vector3(0, WATER_Y, (RIVER.x + RIVER.y) / 2.0), Color(0.2, 0.36, 0.55), false)
	B.box(r, Vector3(500, 0.1, RIVER.y - RIVER.x + 20.0), Vector3(0, WATER_Y - 3.0, (RIVER.x + RIVER.y) / 2.0), Color(0.3, 0.28, 0.22), false)
	for zz: float in [RIVER.x, RIVER.y]:  # rantaluiskat
		var bank := B.mesh(r, B.boxm(Vector3(500, 0.2, 9.0)), Vector3(0, -2.2, zz + (3.5 if zz == RIVER.x else -3.5)), Color(0.42, 0.42, 0.3))
		bank.rotation.x = 0.55 if zz == RIVER.x else -0.55
	_rails_along(r, -300, RIVER.x - 2.0, 0.0)
	_rails_along(r, RIVER.y + 2.0, 220, 0.0)
	Train.build_truss(r, Vector3(0, 0.0, RIVER.y + 4.0), Vector3(0, 0.0, RIVER.x - 4.0), WATER_Y)
	for i in 120:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * randf_range(9, 150)
		var z := randf_range(-250, 200)
		if z > RIVER.x - 6.0 and z < RIVER.y + 6.0:
			continue
		var hgt := randf_range(8, 15)
		if randf() < 0.5:
			B.mesh(r, B.cyl(0.0, hgt * 0.22, hgt * 0.8, 7), Vector3(x, hgt * 0.4, z), Color(0.1, 0.24, 0.12))
		else:
			B.mesh(r, B.cyl(0.12, 0.16, hgt * 0.7, 6), Vector3(x, hgt * 0.35, z), Color(0.92, 0.92, 0.88))
			B.mesh(r, B.sphere(hgt * 0.18, 7), Vector3(x, hgt * 0.75, z), Color(0.35, 0.55, 0.22))
	# Vaala joen takana: talot ja kirkontorni.
	for i in 8:
		var p := Vector3(-120 + i * 30, 0, -110 - (i % 3) * 18)
		B.box(r, Vector3(10, 6, 8), p + Vector3(0, 3, 0), [Color(0.85, 0.75, 0.4), Color(0.6, 0.15, 0.1), Color(0.9, 0.9, 0.86)][i % 3], false)
		B.mesh(r, B.cyl(0.0, 7.0, 3.0, 4), p + Vector3(0, 7.5, 0), Color(0.2, 0.2, 0.22), Vector3(0, 45, 0))
	B.box(r, Vector3(6, 24, 6), Vector3(70, 12, -140), Color(0.92, 0.9, 0.84), false)
	B.mesh(r, B.cyl(0.0, 4.5, 9.0, 4), Vector3(70, 28.5, -140), Color(0.25, 0.25, 0.27), Vector3(0, 45, 0))


## Ravintolavaunu sisältä: valkoiset pöytäliinat, punaiset istuimet, puupaneloidut seinät, ikkunarivit molemmin
## puolin (maisema liikkuu ulkona), tiski kahvinkeittimineen ja tarjoilija. Pelaaja istuu ikkunapöydässä Marjaa
## ja Liisaa vastapäätä, Helena pelaajan vieressä ikkunan puolella, tarjoilija käytävällä. Palauttaa hahmot ja
## maisemasolmun.
func _build_dining_car(car: Node3D) -> Dictionary:
	const W := 2.8
	const LEN := 16.0
	var wood := Color(0.55, 0.36, 0.2)
	var cream := Color(0.93, 0.9, 0.82)
	B.box(car, Vector3(W, 0.1, LEN), Vector3(0, -0.05, 0), Color(0.3, 0.12, 0.1), false)  # lattiamatto
	B.box(car, Vector3(W, 0.1, LEN), Vector3(0, 2.45, 0), cream, false)  # katto
	for zz: float in [-LEN / 2.0, LEN / 2.0]:
		B.box(car, Vector3(W, 2.5, 0.1), Vector3(0, 1.2, zz), wood, false)
	# Seinät ikkunoineen: alaosa paneelia, ikkunoiden välissä pilarit, ylhäällä kaistale.
	for sx: float in [-1.0, 1.0]:
		var x := sx * W / 2.0
		B.box(car, Vector3(0.08, 0.85, LEN), Vector3(x, 0.42, 0), wood, false)
		B.box(car, Vector3(0.08, 0.55, LEN), Vector3(x, 2.15, 0), cream, false)
		for k in 9:
			B.box(car, Vector3(0.1, 1.05, 0.35), Vector3(x, 1.38, -LEN / 2.0 + k * 2.0), cream, false)
	# Lamput.
	for k in 4:
		var lamp := B.mesh(car, B.boxm(Vector3(0.6, 0.05, 0.6)), Vector3(0, 2.38, -6.0 + k * 4.0), Color(1.0, 0.95, 0.8))
		lamp.material_override = B.unshaded(Color(1.0, 0.95, 0.82))
		var l := OmniLight3D.new()
		l.position = Vector3(0, 2.2, -6.0 + k * 4.0)
		l.light_color = Color(1.0, 0.9, 0.75)
		l.light_energy = 0.8
		l.omni_range = 5.0
		car.add_child(l)
	# Pöydät ja istuimet ikkunan vieressä (vasen rivi, x < 0), käytävä oikealla.
	var red := Color(0.65, 0.1, 0.1)
	for tz: float in [-4.0, 0.0, 4.0]:
		B.box(car, Vector3(0.9, 0.05, 0.75), Vector3(-0.85, 0.75, tz), Color(0.97, 0.97, 0.96), false)  # liina
		B.box(car, Vector3(0.08, 0.75, 0.08), Vector3(-0.85, 0.37, tz), Color(0.3, 0.3, 0.3), false)
		for sz: float in [-1.0, 1.0]:
			B.box(car, Vector3(0.9, 0.45, 0.55), Vector3(-0.85, 0.22, tz + sz * 0.85), red, false)
			B.box(car, Vector3(0.9, 0.8, 0.12), Vector3(-0.85, 0.85, tz + sz * 1.15), red, false)
		if tz == 0.0:
			continue  # oma pöytä: olut ja paukut alla
		for cx: float in [-1.05, -0.65]:
			B.mesh(car, B.cyl(0.045, 0.04, 0.09, 12), Vector3(cx, 0.82, tz - 0.15), Color(0.95, 0.95, 0.95))  # kahvikupit
			B.mesh(car, B.cyl(0.045, 0.04, 0.09, 12), Vector3(cx, 0.82, tz + 0.15), Color(0.95, 0.95, 0.95))
		B.mesh(car, B.sphere(0.07, 8), Vector3(-0.85, 0.82, tz), Color(0.78, 0.55, 0.25))  # korvapuusti
	# Oma pöytä: pelaajalla tuoppi olutta vaahtoineen, naisilla Koskenkorvapaukut ja pöydän keskellä pullo.
	B.mesh(car, B.cyl(0.042, 0.036, 0.16, 14), Vector3(-0.62, 0.855, 0.2), Color(0.86, 0.56, 0.12))
	B.mesh(car, B.cyl(0.043, 0.043, 0.03, 14), Vector3(-0.62, 0.95, 0.2), Color(0.97, 0.95, 0.88))
	for sp: Vector3 in [Vector3(-1.07, 0.0, 0.2), Vector3(-1.05, 0.0, -0.2), Vector3(-0.6, 0.0, -0.2)]:
		B.mesh(car, B.cyl(0.02, 0.016, 0.055, 10), sp + Vector3(0, 0.805, 0), Color(0.8, 0.88, 0.92))
		B.mesh(car, B.cyl(0.017, 0.015, 0.03, 10), sp + Vector3(0, 0.796, 0), Color(0.97, 0.97, 0.95))
	B.mesh(car, B.cyl(0.035, 0.035, 0.2, 12), Vector3(-0.85, 0.88, 0.0), Color(0.85, 0.9, 0.93))  # Koskenkorva-pullo
	B.mesh(car, B.cyl(0.036, 0.036, 0.06, 12), Vector3(-0.85, 0.86, 0.0), Color(0.15, 0.3, 0.65))  # etiketti
	B.mesh(car, B.cyl(0.013, 0.013, 0.07, 8), Vector3(-0.85, 1.015, 0.0), Color(0.85, 0.9, 0.93))
	# Tiski kahvinkeittimineen vaunun päässä.
	B.box(car, Vector3(W - 0.4, 1.0, 0.6), Vector3(0, 0.5, -LEN / 2.0 + 0.5), wood, false)
	B.box(car, Vector3(0.35, 0.45, 0.3), Vector3(0.7, 1.22, -LEN / 2.0 + 0.5), Color(0.2, 0.2, 0.22), false)
	# Maisema ikkunoiden takana: pellot, kuuset ja koivut liikkuvat (scenery.position.z).
	var scenery := Node3D.new()
	car.add_child(scenery)
	B.box(scenery, Vector3(160, 0.05, 360), Vector3(0, -1.2, -60), Color(0.36, 0.5, 0.24), false)
	for i in 120:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * randf_range(6, 60)
		var z := randf_range(-240, 120)
		var hgt := randf_range(6, 14)
		if randf() < 0.6:
			B.mesh(scenery, B.cyl(0.0, hgt * 0.22, hgt * 0.8, 7), Vector3(x, hgt * 0.4 - 1.2, z), Color(0.1, 0.24, 0.12))
		else:
			B.mesh(scenery, B.cyl(0.12, 0.16, hgt * 0.7, 6), Vector3(x, hgt * 0.35 - 1.2, z), Color(0.92, 0.92, 0.88))
			B.mesh(scenery, B.sphere(hgt * 0.18, 7), Vector3(x, hgt * 0.75 - 1.2, z), Color(0.3, 0.5, 0.2))
	# Hahmot: pelaaja ja Helena käytävän puolella eri pöydissä, Marja ja Liisa pelaajaa vastapäätä.
	var cast := {"scenery": scenery}
	var seat := func(look: Dictionary, at: Vector3, face: Vector3) -> Node3D:
		var c := Looks.make(car, look)
		c.position = at
		c.rotation.y = B.yaw_to(face)
		c.play("Sitting_Idle", 0.0)
		return c
	var hero: Node3D = seat.call(Looks.PLAYER, Vector3(-0.58, 0.0, 0.85), Vector3(0, 0, -1))
	Looks.add_cap(hero)
	cast["minä"] = hero
	cast["marja"] = seat.call(MARJA, Vector3(-1.05, 0.0, -0.85), Vector3(0, 0, 1))
	cast["liisa"] = seat.call(LIISA, Vector3(-0.55, 0.0, -0.85), Vector3(0, 0, 1))
	cast["helena"] = seat.call(HELENA, Vector3(-1.1, 0.0, 0.85), Vector3(0, 0, -1))
	var waiter := Looks.make(car, WAITER)
	waiter.position = Vector3(0.35, 0.0, -1.55)
	waiter.rotation.y = B.yaw_to(Vector3(-0.8, 0, 1.0))
	waiter.play("Idle_Talking", 0.0)
	cast["tarjoilija"] = waiter
	return cast


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
