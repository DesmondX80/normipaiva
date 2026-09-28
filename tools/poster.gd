extends Node
## Pelin juliste: lavastaa kohtaukset oikeilla hahmoilla ja maisemalla, sommittelee GTA-tyyliin
## ja tallentaa PNG:n. Ajo: godot --path . tools/poster.tscn -- --out=/polku/juliste.png

const B := preload("res://scripts/build.gd")
const M := preload("res://scripts/map_data.gd")
const World := preload("res://scripts/world.gd")
const PlayerBike := preload("res://scripts/player_bike.gd")
const ShopInterior := preload("res://scripts/shop_interior.gd")
const Looks := preload("res://scripts/looks.gd")
const Fight := preload("res://scripts/fight.gd")
const Tractor := preload("res://scripts/tractor.gd")
const LaavuGuard := preload("res://scripts/laavu_guard.gd")
const Villager := preload("res://scripts/villager.gd")
const Cutscene := preload("res://scripts/cutscene.gd")
const Vehicles := preload("res://scripts/vehicles.gd")

const SIZE := Vector2i(1200, 1850)
const YELLOW := Color(1.0, 0.8, 0.1)
const ORANGE := Color(1.0, 0.42, 0.0)
const CAPTURE_FRAME := 170

var _out := "user://juliste.png"
var _frames := 0
var _poster: SubViewport
var _w3 := World3D.new()
var _stage: SubViewport
var _world: Node3D
var _fight: Node3D
var _panels := {}
var _talkers: Array = []
var _hide_names: Array = []


func _ready() -> void:
	for act in ["forward", "back", "left", "right", "punch", "kick", "special", "interact", "brake", "bell"]:
		if not InputMap.has_action(act):
			InputMap.add_action(act)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_poster = SubViewport.new()
	_poster.size = SIZE
	_poster.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_poster)
	_stage = _viewport(Vector2i(1140, 500))
	_build_scene()
	_layout()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 5:
		for l in find_children("*", "Label3D", true, false):
			if l.global_position.x > 2000.0:
				l.visible = false  # kaupan nimikyltit pois kassajonokuvasta
		_world.fire.visible = true
		for v in _hide_names:
			for l in v.find_children("*", "Label3D", true, false):
				if l.text.begins_with("Naapurin"):
					l.visible = false
		for t in _talkers:
			if t.size() > 2:
				t[0].call(t[1], t[2])
			else:
				t[0].call(t[1])
	if _frames == 30:
		_fight.start(6, "juntti")
	# Tappelupaneeliin kiertopotku ja osumaefektit juuri ennen kuvaa.
	if _frames == CAPTURE_FRAME - 16:
		_fight._ai_block_t = -1.0
		_fight._ai_t = 10.0
		_fight._j.state = "idle"
		_fight._j.position.x = _fight._p.position.x + 1.3
		_fight._p._start_attack("spin")
	if _frames == CAPTURE_FRAME - 6:
		_fight._j.take_hit(14.0, 1.0, 5.0)
		_fight.on_hit(_fight._p, _fight._j, false, "spin")
		# Osumateksti pienemmäksi ja ylös, ettei peitä taistelijoita.
		for e in _fight._effects:
			var word: Label3D = e[0]
			word.font_size = 52
			word.position.y += 1.1
		_fight._help.visible = false
	if _frames == CAPTURE_FRAME:
		Engine.time_scale = 1.0
		var img := _poster.get_texture().get_image()
		img.save_png(_out)
		print("Juliste tallennettu: ", ProjectSettings.globalize_path(_out))
		get_tree().quit()


func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.world_3d = _w3
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


func _camera(vp: SubViewport, from: Vector3, to: Vector3, fov: float) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 1500.0
	vp.add_child(cam)
	cam.look_at_from_position(from, to, Vector3.UP)
	cam.current = true
	return cam


# --- Lavastus ----------------------------------------------------------------

func _build_scene() -> void:
	var s := _stage
	var sky := Sky.new()
	sky.sky_material = B.shader_mat("res://shaders/sky.gdshader", {"cloud_coverage": 0.55})
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.85, 0.78, 0.7)
	env.fog_depth_begin = 60.0
	env.fog_depth_end = 500.0
	env.fog_sky_affect = 0.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.1
	_w3.environment = env
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, 205, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	s.add_child(sun)

	_world = World.new()
	s.add_child(_world)
	var set3d := Node3D.new()
	s.add_child(set3d)

	# Pääkuva: pyöräilijä lähtee Järvikuja 1:n punatiilitalon edestä, Päivin Hyundai perässä.
	var bike_pos := M.w(Vector2(791, 1162))
	var bike := PlayerBike.new()
	bike.position = bike_pos + Vector3(0, 0.3, 0)
	bike.rotation.y = 0.15
	s.add_child(bike)
	bike.controls_enabled = false
	bike.set_carrying(true)
	bike.speed = 2.0
	_world.follow = bike
	var car := Node3D.new()
	car.position = bike_pos + Vector3(-1.0, 0, 16.0)
	s.add_child(car)
	B.car(car, Color(0.78, 0.05, 0.05))
	car.rotation.y = 0.05
	var main_cam := _camera(s, bike_pos + Vector3(0.6, 1.15, -10.5), bike_pos + Vector3(4.2, 1.5, 8.0), 42.0)
	main_cam.cull_mask = 0xFFFFF & ~4  # loppukohtauksen hahmot (kerros 3) eivät näy pääkuvassa

	# Tappelu omaan näkymäänsä (oma 2D-kerros: energiapalkit näkyvät vain tässä paneelissa).
	var vf := _viewport(Vector2i(740, 280))
	_fight = Fight.new()
	_fight.position = Vector3(-3000, 0, 0)
	vf.add_child(_fight)
	_panels["fight"] = vf

	# Laavu: nuotio palaa, akka vahtii.
	var pit := M.w(M.LAAVU)
	var guard := LaavuGuard.new()
	guard.kind = "akka"
	guard.center = pit
	s.add_child(guard)
	_talkers.append([guard, "_say"])
	var vl := _viewport(Vector2i(270, 280))
	_camera(vl, pit + Vector3(-3.8, 1.6, -8.0), pit + Vector3(0.6, 1.0, -0.8), 50.0)
	_panels["laavu"] = vl

	# Jyväjemmari traktorilla pellolla.
	var tp := M.w(Vector2(450, 725))
	var tractor := Tractor.new()
	tractor.position = tp
	tractor.rotation.y = B.yaw_to(Vector3(-7.5, 0, 3.5)) + 0.45  # kohti kameraa, kolmen neljäsosan kulmassa
	set3d.add_child(tractor)
	_talkers.append([tractor, "_say"])
	var vt := _viewport(Vector2i(270, 280))
	_camera(vt, tp + Vector3(-7.5, 1.1, 3.5), tp + Vector3(0, 1.6, 0), 45.0)
	_panels["tractor"] = vt

	# Harmaapäät kassajonossa.
	var shop := ShopInterior.new()
	shop.position = Vector3(3000, 0, 0)
	s.add_child(shop)
	shop._queue_started = true
	var vg := _viewport(Vector2i(360, 280))
	var q := Vector3(3000, 0, 0) + ShopInterior.QUEUE_FRONT
	_camera(vg, q + Vector3(-2.6, 1.7, 1.6), q + Vector3(0.3, 1.1, -1.4), 48.0)
	_panels["queue"] = vg

	# Naapurit pihalla: Arto, Pekka ja Anna-Liisa.
	var np := M.w(Vector2(797, 1128))
	var names := [["Naapurin Arto", Looks.ARTO, "Lähekkö puolukkaan?", "arto"],
		["Naapurin Pekka", Looks.PEKKA, "Ammuin 14 kyyhkyä!", "pekka"],
		["Naapurin Anna-Liisa", Looks.ANNA_LIISA, "Kyllä mää kerron...", "pirjo"]]
	for i in names.size():
		var v := Villager.new()
		v.display_name = names[i][0]
		v.look = names[i][1]
		v.lines = [names[i][2]]
		v.voice = names[i][3]
		v.position = np + Vector3(-1.5 + i * 1.5, 0, 0)
		v.rotation.y = PI + [0.3, 0.0, -0.3][i]
		set3d.add_child(v)
		_talkers.append([v, "say", names[i][2]] if i == 0 else [v, "get_class"])
		_hide_names.append(v)
	var vn := _viewport(Vector2i(270, 280))
	_camera(vn, np + Vector3(0, 1.5, 5.4), np + Vector3(0, 1.15, 0), 48.0)
	_panels["neighbors"] = vn

	# Grillikatos Kiilinlammella: turvapaikka, Päivin Hyundai ei pääse perille.
	var gp := M.w(M.GRILLIKATOS)
	var chill := Looks.make(set3d, Looks.PLAYER)
	Looks.add_cap(chill)
	chill.position = gp + Vector3(0.6, 0, 0.8)
	chill.rotation.y = -0.4
	chill.play("Idle", 0.0)
	var vk := _viewport(Vector2i(270, 280))
	_camera(vk, gp + Vector3(3.2, 1.7, 6.4), gp + Vector3(0.2, 1.1, 0.6), 50.0)
	_panels["grilli"] = vk

	# Loppu 1: WASTED – Päivi motkottaa kotipihalla (harmaaksi haalistettuna).
	var home: Vector3 = _world.home_zone
	var hero := Looks.make(set3d, Looks.PLAYER)
	Looks.add_cap(hero)
	hero.position = home + Vector3(0, 0, 1.0)
	hero.rotation.y = PI * 0.5
	hero.play("Idle", 0.0)
	hero.set_override("neck_01", Vector3.RIGHT, 0.5)
	var paivi := Looks.make(set3d, Looks.PAIVI)
	paivi.position = home + Vector3(-1.4, 0, 1.0)
	paivi.rotation.y = -PI * 0.5
	paivi.play("Idle_Talking", 0.0)
	var bubble := B.label(set3d, "Kaljareissulla taas, vai?!", paivi.position + Vector3(0.5, 2.1, 0), 30, Color.WHITE, true)
	bubble.outline_size = 10
	for n in [hero, paivi, bubble]:
		for vi in n.find_children("*", "VisualInstance3D", true, false):
			(vi as VisualInstance3D).layers = 4
		if n is VisualInstance3D:
			n.layers = 4
	var vw := _viewport(Vector2i(555, 250))
	bubble.position.y = 2.15
	_camera(vw, home + Vector3(-0.7, 1.5, 5.6), home + Vector3(-0.7, 1.45, 1.0), 44.0)
	var grey: Environment = _w3.environment.duplicate()
	grey.adjustment_saturation = 0.12
	grey.adjustment_contrast = 1.2
	(vw.get_child(-1) as Camera3D).environment = grey
	_panels["wasted"] = vw

	# Loppu 2: kotijemmassa 24 – karburaattoria säätämässä autotallissa.
	var cs := Cutscene.new()
	cs._props = Node3D.new()
	s.add_child(cs._props)
	cs._build_garage()
	var gg := Cutscene.GARAGE_POS
	var vr := _viewport(Vector2i(555, 250))
	_camera(vr, gg + Vector3(2.6, 1.7, 4.8), gg + Vector3(0.3, 0.9, 1.0), 50.0)
	_panels["garage"] = vr


# --- Sommittelu --------------------------------------------------------------

func _layout() -> void:
	var root := Control.new()
	root.size = Vector2(SIZE)
	_poster.add_child(root)

	var bg := ColorRect.new()
	bg.size = Vector2(SIZE)
	bg.color = Color(0.08, 0.07, 0.09)
	root.add_child(bg)
	for i in 9:
		var stripe := ColorRect.new()
		stripe.size = Vector2(2800, 70)
		stripe.position = Vector2(-800, 160 + i * 220)
		stripe.rotation = -0.35
		stripe.color = Color(ORANGE, 0.08 + 0.02 * (i % 2))
		root.add_child(stripe)

	_frame(root, _stage, Rect2(30, 290, 1140, 500), -0.6)
	# Päivä tarinana: numeroidut vaiheet, lopuksi kaksi loppua.
	var cells := [
		["queue", Rect2(30, 830, 360, 280), 0.8, "1 · KAUPPA", "\"Ainiin, oli se pakettiki vielä\""],
		["fight", Rect2(430, 830, 740, 280), -0.5, "2 · MATKALLA", "STREET FIGHTER SALOISISSA"],
		["laavu", Rect2(30, 1140, 270, 280), -1.0, "3 · LAAVU", "\"Tää on MEIDÄN laavu!\""],
		["grilli", Rect2(320, 1140, 270, 280), 0.9, "4 · JEMMA", "Grillikatos = turvapaikka"],
		["neighbors", Rect2(610, 1140, 270, 280), -0.7, "NAAPURIT", "300 jänistä talvessa!"],
		["tractor", Rect2(900, 1140, 270, 280), 1.0, "VAARA", "POIS MUN VILJOISTA!"],
		["wasted", Rect2(30, 1455, 555, 250), -0.6, "LOPPU A", "Päivi nappasi kiinni"],
		["garage", Rect2(615, 1455, 555, 250), 0.6, "LOPPU B", "Jemmassa 24 – karburaattorin säätöön"],
	]
	for c in cells:
		var r: Rect2 = c[1]
		_frame(root, _panels[c[0]], r, c[2])
		var cap := _text(root, c[4], 24 if r.size.x < 300 else 28, Color.WHITE, 8)
		cap.position = r.position + Vector2(6, r.size.y - 64)
		cap.size = Vector2(r.size.x - 12, 58)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Vaihenumero keltaisella tarralla vasempaan yläkulmaan.
		var step := ColorRect.new()
		step.color = YELLOW if c[3].begins_with("LOPPU") == false else (Color(0.85, 0.1, 0.08) if c[0] == "wasted" else Color(0.2, 0.75, 0.25))
		step.position = r.position + Vector2(-8, -12)
		step.rotation = -0.05
		root.add_child(step)
		var st := _text(root, c[3], 26, Color(0.1, 0.08, 0.05) if c[0] != "wasted" else Color.WHITE, 0)
		st.remove_theme_constant_override("shadow_offset_x")
		st.remove_theme_constant_override("shadow_offset_y")
		st.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		st.reparent(step)
		st.position = Vector2(12, 0)
		step.size = Vector2(st.get_minimum_size().x + 24, 40)
		st.size = Vector2(step.size.x - 24, 40)
		st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# WASTED päälle kuten pelissä.
	var wr: Rect2 = cells[6][1]
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.55)
	band.position = wr.position + Vector2(0, 118)
	band.size = Vector2(wr.size.x, 72)
	band.pivot_offset = band.size / 2.0
	band.rotation_degrees = -0.6
	root.add_child(band)
	var wt := _text(root, "WASTED", 66, Color(0.85, 0.08, 0.08), 12)
	wt.reparent(band)
	wt.position = Vector2.ZERO
	wt.size = band.size
	wt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# "TAI" loppujen väliin.
	var tai := _text(root, "TAI", 40, YELLOW, 10)
	tai.position = Vector2(560, 1545)
	tai.size = Vector2(80, 60)
	tai.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Uutuustähti pääkuvan kulmaan.
	var star := ColorRect.new()
	star.color = ORANGE
	star.position = Vector2(58, 318)
	star.size = Vector2(300, 92)
	star.rotation = -0.09
	root.add_child(star)
	var st2 := _text(root, "KÄVELE · JEMMAA · FPS\n3 JEMMAA · 2 LOPPUA", 24, Color.WHITE, 6)
	st2.reparent(star)
	st2.position = Vector2.ZERO
	st2.size = star.size
	st2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var title := _text(root, "NORMIPÄIVÄ", 190, YELLOW, 26)
	title.position = Vector2(0, 14)
	title.size = Vector2(SIZE.x, 200)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _text(root, "S A L O I S I S S A", 64, Color.WHITE, 14)
	sub.position = Vector2(0, 196)
	sub.size = Vector2(SIZE.x, 80)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bb := ColorRect.new()
	bb.color = YELLOW
	bb.position = Vector2(640, 722)
	bb.size = Vector2(510, 58)
	bb.rotation = -0.04
	root.add_child(bb)
	var badge := _text(root, "JÄRVIKUJA 1 → K-MARKET → LAAVU → KOTI", 26, Color(0.1, 0.08, 0.05), 0)
	badge.reparent(bb)
	badge.position = Vector2.ZERO
	badge.size = bb.size
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var tag := _text(root, "Osta kuutonen. Jemmaa 24. Pääse kotiin ennen Päiviä.", 40, Color.WHITE, 10)
	tag.position = Vector2(0, 1728)
	tag.size = Vector2(SIZE.x, 70)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var credit := _text(root, "Saloinen · Raahe  ·  Tehty Godotilla  ·  Hahmot: Quaternius (CC0)", 22, Color(0.75, 0.72, 0.68), 4)
	credit.position = Vector2(0, 1798)
	credit.size = Vector2(SIZE.x, 40)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Kuvapaneeli mustalla kehyksellä, hieman vinossa.
func _frame(root: Control, vp: SubViewport, r: Rect2, deg: float) -> void:
	var holder := Control.new()
	holder.position = r.position
	holder.size = r.size
	holder.pivot_offset = r.size / 2.0
	holder.rotation_degrees = deg
	root.add_child(holder)
	var border := ColorRect.new()
	border.color = Color.BLACK
	border.position = Vector2(-10, -10)
	border.size = r.size + Vector2(20, 20)
	holder.add_child(border)
	var white := ColorRect.new()
	white.color = Color(0.95, 0.93, 0.88)
	white.position = Vector2(-5, -5)
	white.size = r.size + Vector2(10, 10)
	holder.add_child(white)
	var tex := TextureRect.new()
	tex.texture = vp.get_texture()
	tex.size = r.size
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	holder.add_child(tex)


func _text(root: Control, text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Impact", "Arial Black", "Helvetica Neue"])
	font.font_weight = 900
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 5)
	l.add_theme_constant_override("shadow_offset_y", 6)
	root.add_child(l)
	return l
