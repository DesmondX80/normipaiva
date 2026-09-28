extends Node
## Hahmoesittelykuva (jaettavaksi esim. WhatsAppissa): pääkortti pelaajasta ja 3×3 muuta hahmoa
## omissa kohtauksissaan nimen, roolin ja tunnusrepliikin kanssa.
## Ajo: godot --path . --resolution 540x1070 tools/cast.tscn -- --out=/polku/hahmot.png

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Vehicles := preload("res://scripts/vehicles.gd")

const SIZE := Vector2i(1080, 2210)
const YELLOW := Color(1.0, 0.8, 0.1)
const ORANGE := Color(1.0, 0.42, 0.0)
const CAPTURE := 70

var _out := "user://hahmot.png"
var _frames := 0
var _poster: SubViewport
var _cards := []  # [viewport, rect, rot, name, role, quote, accent]
var _punchers: Array = []
var _gunners: Array = []  # [hahmo, juuri]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_poster = SubViewport.new()
	_poster.size = SIZE
	_poster.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_poster)
	_build_cards()
	_layout()


func _process(_d: float) -> void:
	_frames += 1
	if _frames == CAPTURE - 14:
		for c in _punchers:
			c.play("Punch_Cross", 0.0)
	if _frames == CAPTURE - 2:
		for g in _gunners:
			_place_gun(g[0], g[1])
	if _frames == CAPTURE:
		_poster.get_texture().get_image().save_png(_out)
		print("Hahmokuva tallennettu: ", ProjectSettings.globalize_path(_out))
		get_tree().quit()


## Oma pieni maailma kortille: taivas, nurmi, aurinko ja kamera.
func _stage(size: Vector2i, cam_from: Vector3, cam_to: Vector3, fov: float, ground := Color(0.3, 0.45, 0.2),
		sun_rot := Vector3(-35, 150, 0)) -> Array:
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var sky := Sky.new()
	sky.sky_material = B.shader_mat("res://shaders/sky.gdshader", {"cloud_coverage": 0.45})
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -30, 0)
	fill.light_energy = 0.35
	root.add_child(fill)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	fl.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = ground
	gm.roughness = 1.0
	fl.material_override = gm
	root.add_child(fl)
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.look_at_from_position(cam_from, cam_to, Vector3.UP)
	cam.current = true
	return [vp, root]


func _person(root: Node3D, look: Dictionary, anim: String, rot := 0.0, pos := Vector3.ZERO) -> Node3D:
	var c: Node3D = Looks.make(root, look)
	c.position = pos
	c.rotation.y = PI + rot  # kasvot kameraan (+Z)
	c.play(anim, 0.0)
	return c


func _can(c: Node3D, bone := "hand_l") -> void:
	var can := Node3D.new()
	B.mesh(can, B.cyl(0.033, 0.033, 0.12, 14), Vector3(0, -0.02, 0), Color(0.85, 0.72, 0.2))
	B.mesh(can, B.cyl(0.028, 0.033, 0.012, 14), Vector3(0, 0.045, 0), Color(0.8, 0.8, 0.82))
	c.attach(bone, can, Vector3(0, -0.02, 0))


func _build_cards() -> void:
	var cam_std := [Vector3(0.0, 1.25, 3.6), Vector3(0.0, 0.95, 0.0), 30.0]
	# Pääkortti: SÄÄ kalja kädessä, pyörä vieressä.
	var h := _stage(Vector2i(1040, 560), Vector3(0.0, 1.25, 2.9), Vector3(0.0, 1.05, 0.0), 30.0)
	var hero := _person(h[1], Looks.PLAYER, "Idle", -0.3)
	Looks.add_cap(hero)
	_can(hero)
	_cards.append([h[0], Rect2(20, 190, 1040, 560), -0.5, "SÄÄ", "Päähenkilö. Tuulipuku, Karhu-lippis, kaljamaha.",
		"\"Pitäis käydä kaupassa...\"", YELLOW])

	var defs := [
		["Päivi", Looks.PAIVI, "Idle_Talking", "Vaimo. Ajaa punaista Hyundaita.", "\"Kaljareissulla taas, vai?!\"",
			Color(0.9, 0.2, 0.3), "car"],
		["Juntti", Looks.JUNTTI, "Idle", "Raahen karateklubin perustaja.", "\"HAI-JAAH!\"", Color(0.95, 0.95, 0.95), "punch"],
		["Anna-Liisa", Looks.ANNA_LIISA, "Idle_Talking", "Naapuri. Näkee kaiken.", "\"Kyllä mää Päiville kerron...\"",
			Color(0.2, 0.75, 0.7), ""],
		["Arto", Looks.ARTO, "Idle_Talking", "Naapuri. Ostaa marjat.", "\"Lähekkö puolukkaan?\"",
			Color(0.9, 0.25, 0.15), "bucket"],
		["Pekka", Looks.PEKKA, "Pistol_Aim_Up", "Naapuri. Metsämies.", "\"14 kyyhkyä, perkele!\"",
			Color(0.55, 0.65, 0.3), "gun"],
		["Jyväjemmari", Looks.JEMMARI, "Idle", "Viljelijä. Pellolla ei ajeta.", "\"POIS MUN VILJOISTA!\"",
			Color(0.3, 0.45, 0.8), "tractor"],
		["Harmaapää", Looks.GRANDPAS[0], "Idle", "Kassajonon kuningas.", "\"Ainiin, oli se pakettiki...\"",
			Color(0.75, 0.75, 0.75), "hunch"],
		["Laavun akka", Looks.AKKA, "Idle_Talking", "Laavun valtaaja.", "\"Tää on MEIDÄN laavu!\"",
			Color(0.8, 0.15, 0.15), ""],
		["Teinit", Looks.TEENS[1], "Idle", "Laavun valtaajat. Pöllivät jemmat.", "\"Ok boomer.\"",
			Color(0.3, 0.8, 0.4), "teens"],
	]
	for i in defs.size():
		var d: Array = defs[i]
		var col := i % 3
		var row := i / 3
		var rect := Rect2(20 + col * 350, 790 + row * 440, 340, 420)
		var st := _stage(Vector2i(340, 420), cam_std[0], cam_std[1], cam_std[2],
			Color(0.62, 0.52, 0.3) if d[6] == "tractor" else Color(0.3, 0.45, 0.2))
		var root: Node3D = st[1]
		var c := _person(root, d[1], d[2], [0.0, -0.25, 0.2][col])
		match d[6]:
			"car":
				var car := Node3D.new()
				car.position = Vector3(-1.4, 0, -3.2)
				car.rotation.y = 0.9
				root.add_child(car)
				Vehicles.car(car, Color(0.78, 0.05, 0.05), "PÄI-V1")
			"punch":
				c.rotation.y = PI - 0.9
				_punchers.append(c)
			"bucket":
				var b := Node3D.new()
				B.mesh(b, B.cyl(0.13, 0.1, 0.22, 16), Vector3(0, 0.11, 0), Color(0.85, 0.85, 0.8))
				B.mesh(b, B.cyl(0.12, 0.12, 0.02, 16), Vector3(0, 0.21, 0), Color(0.75, 0.12, 0.15))
				b.position = Vector3(0.45, 0, 0.3)
				root.add_child(b)
			"gun":
				c.rotation.y = PI - 0.5
				_gunners.append([c, root])
			"tractor":
				var t := Node3D.new()
				t.position = Vector3(1.3, 0, -3.8)
				t.rotation.y = -0.6
				root.add_child(t)
				Vehicles.tractor(t, Color(0.72, 0.08, 0.06), "modern")
			"hunch":
				Looks.hunch(c, 0.35)
			"teens":
				c.position.x = 0.35
				var t2 := _person(root, Looks.TEENS[0], "Idle", -0.3, Vector3(-0.45, 0, -0.5))
				t2.play("Idle", 0.0)
				var t3 := _person(root, Looks.TEENS[2], "Idle_Talking", 0.3, Vector3(0.9, 0, -0.9))
				t3.play("Idle_Talking", 0.0)
		_cards.append([st[0], rect, [0.7, -0.6, 0.5][(i + row) % 3], d[0].to_upper(), d[3], d[4], d[5]])


## Haulikko käsien suuntaan (tähtäysasennossa kädet ovat yhdessä ylhäällä).
func _place_gun(c: Node3D, root: Node3D) -> void:
	var hr: Vector3 = c.bone_position("hand_r")
	var hl: Vector3 = c.bone_position("hand_l")
	var chest: Vector3 = c.bone_position("spine_03")
	var hands := (hr + hl) * 0.5
	var dir := (hands - chest).normalized()
	var gun := Node3D.new()
	root.add_child(gun)
	gun.global_position = hands - dir * 0.28
	gun.look_at(gun.global_position + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
	var wood := Color(0.42, 0.24, 0.12)
	var steel := Color(0.12, 0.12, 0.13)
	B.mesh(gun, B.boxm(Vector3(0.05, 0.09, 0.34)), Vector3(0, -0.02, 0.12), wood)  # tukki
	B.mesh(gun, B.boxm(Vector3(0.045, 0.05, 0.3)), Vector3(0, 0, -0.14), wood)  # etutukki
	for sx in [-0.013, 0.013]:
		B.mesh(gun, B.cyl(0.011, 0.011, 0.72, 10), Vector3(sx, 0.025, -0.4), steel, Vector3(PI * 0.5, 0, 0))  # piiput


func _layout() -> void:
	var root := Control.new()
	root.size = Vector2(SIZE)
	_poster.add_child(root)
	var bg := ColorRect.new()
	bg.size = Vector2(SIZE)
	bg.color = Color(0.08, 0.07, 0.09)
	root.add_child(bg)
	for i in 12:
		var stripe := ColorRect.new()
		stripe.size = Vector2(2600, 70)
		stripe.position = Vector2(-800, 120 + i * 200)
		stripe.rotation = -0.35
		stripe.color = Color(ORANGE, 0.07 + 0.02 * (i % 2))
		root.add_child(stripe)
	var title := _text(root, "NORMIPÄIVÄ", 132, YELLOW, 20)
	title.position = Vector2(0, 8)
	title.size = Vector2(SIZE.x, 140)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _text(root, "S A L O I S I S S A   ·   H A H M O T", 36, Color.WHITE, 10)
	sub.position = Vector2(0, 138)
	sub.size = Vector2(SIZE.x, 50)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for c in _cards:
		var r: Rect2 = c[1]
		var holder := _frame(root, c[0], r, c[2], c[6])
		var hero := r.size.x > 500
		# Nimi keltaisella tarralla yläkulmaan.
		var tag := ColorRect.new()
		tag.color = c[6]
		tag.position = Vector2(-10, -14)
		tag.rotation = -0.04
		holder.add_child(tag)
		var name_l := _text(root, c[3], 54 if hero else 34, Color(0.08, 0.06, 0.05), 0)
		name_l.remove_theme_constant_override("shadow_offset_x")
		name_l.remove_theme_constant_override("shadow_offset_y")
		name_l.reparent(tag)
		name_l.position = Vector2(14, 0)
		tag.size = Vector2(name_l.get_minimum_size().x + 28, 70 if hero else 48)
		name_l.size = Vector2(tag.size.x - 28, tag.size.y)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Rooli ja repliikki kortin alareunaan tummalle nauhalle.
		var band := ColorRect.new()
		band.color = Color(0, 0, 0, 0.55)
		var bh := 110.0 if hero else 108.0
		band.position = Vector2(0, r.size.y - bh)
		band.size = Vector2(r.size.x, bh)
		holder.add_child(band)
		var quote := _text(root, c[5], 40 if hero else 25, YELLOW, 8)
		quote.reparent(band)
		quote.position = Vector2(10, 4)
		quote.size = Vector2(r.size.x - 20, 54 if hero else 50)
		quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quote.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var role := _text(root, c[4], 26 if hero else 19, Color(0.92, 0.9, 0.86), 5)
		role.reparent(band)
		role.position = Vector2(10, (58 if hero else 54))
		role.size = Vector2(r.size.x - 20, 48)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var foot := _text(root, "Aja K-Marketille, osta kuutonen, pääse kotiin ennen Päiviä.", 32, Color.WHITE, 8)
	foot.position = Vector2(0, SIZE.y - 80)
	foot.size = Vector2(SIZE.x, 50)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _frame(root: Control, vp: SubViewport, r: Rect2, deg: float, accent: Color) -> Control:
	var holder := Control.new()
	holder.position = r.position
	holder.size = r.size
	holder.pivot_offset = r.size / 2.0
	holder.rotation_degrees = deg
	root.add_child(holder)
	var border := ColorRect.new()
	border.color = Color.BLACK
	border.position = Vector2(-9, -9)
	border.size = r.size + Vector2(18, 18)
	holder.add_child(border)
	var edge := ColorRect.new()
	edge.color = Color(0.95, 0.93, 0.88)
	edge.position = Vector2(-5, -5)
	edge.size = r.size + Vector2(10, 10)
	holder.add_child(edge)
	var tex := TextureRect.new()
	tex.texture = vp.get_texture()
	tex.size = r.size
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	holder.add_child(tex)
	return holder


func _text(root: Control, text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Impact", "Arial Black", "Helvetica Neue"])
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)
	root.add_child(l)
	return l
