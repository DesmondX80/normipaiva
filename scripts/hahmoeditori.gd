extends CanvasLayer
## Hahmoeditori pelin alussa (menu.gd open_editor): pelaaja seisoo kotinsa eteisessä peilin edessä ja valitsee tukan,
## hiusten värin, parran, lasit, päähineen, ihon, mahan ja tuulipuvun värin (Looks.HAHMO, Looks.custom).
## Oma 3D-lavastus SubViewportissa (kuten inventory.gd:n muotokuva): hahmo on sama Looks.make-malli kuin pelissä, ja
## jokainen valinta vaihtaa sen ulkonäön paikallaan (Looks.restyle_player). Ruudun päällä vain valintapaneeli ja
## näppäinohje. Peli on pysäytetty (valikko), joten kaikki täällä pyörii PROCESS_MODE_ALWAYS:lla.

const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const HintBar := preload("res://scripts/hint_bar.gd")

signal finished(accepted: bool)

const YELLOW := Color(1.0, 0.8, 0.1)
const PANEL_W := 450.0  # valintapaneelin leveys (px), oikeassa reunassa
const PANEL_GAP := 28.0
const FOV := 30.0
## Kameran rajaukset: [kohteen korkeus (m), osuus ruudun korkeudesta]. Keskikohta: vartalo puolivälistä, pää Head-luusta.
const FRAME := {"vartalo": [2.0, 0.86], "paa": [0.56, 0.6]}
const WALL_Z := -1.6  # takaseinän pinta; hahmo origossa kasvot +Z:aan (peiliin = kameraan)

var can_cancel := true  # Esc palaa päävalikkoon ja palauttaa vanhat valinnat (uuden pelin alussa ei ole, mihin palata)
var _before := {}
var _vp: SubViewport
var _tex: TextureRect
var _cam: Camera3D
var _char: Node3D
var _row := 0
var _rows: Array = []  # [PanelContainer, arvon Label, värinäyte ColorRect]
var _yaw := 0.0
var _yaw_to := 0.0
var _drag := false
var _keys: Control
var _snap := true  # ensimmäinen ruutu: kamera suoraan paikalleen


func _ready() -> void:
	layer = 41  # valikon (40) päällä
	process_mode = Node.PROCESS_MODE_ALWAYS
	_before = Looks.custom.duplicate(true)
	_build_stage()
	_build_ui()
	_select(0)
	_restyle()  # ensimmäinen rivi on tukka: lippis pois heti


# --- Lavastus -------------------------------------------------------------------

func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var root := Node3D.new()
	_vp.add_child(root)
	var env := Environment.new()
	# Taivas vain heijastuksiin (peililasit, kello, rannekoru): huone peittää sen, mutta ilman sitä metalli olisi musta.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.95, 0.88, 0.74)
	sky_mat.sky_horizon_color = Color(1.0, 0.96, 0.88)
	sky_mat.ground_horizon_color = Color(0.75, 0.6, 0.42)
	sky_mat.ground_bottom_color = Color(0.45, 0.32, 0.2)
	sky_mat.sun_angle_max = 0.0
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.93, 0.82)
	env.ambient_light_energy = 0.4
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()  # eteisen kattolamppu ja peilin valo: edestä ylhäältä vasemmalta
	key.rotation_degrees = Vector3(-38, -28, 0)
	key.light_energy = 1.0
	key.light_color = Color(1.0, 0.95, 0.86)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 14.0
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12, 55, 0)
	fill.light_energy = 0.3
	fill.light_color = Color(0.8, 0.88, 1.0)
	root.add_child(fill)
	_room(root)
	_cam = Camera3D.new()
	_cam.fov = FOV
	root.add_child(_cam)
	_cam.current = true
	_char = Looks.make(root, Looks.player())
	Looks.add_cap(_char)
	_char.rotation.y = PI  # mallin kasvot ovat -Z:aan: käännetään kameraan päin
	_char.play("Idle")
	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.mouse_filter = Control.MOUSE_FILTER_STOP
	_tex.gui_input.connect(_stage_input)
	add_child(_tex)


## Kodin eteinen: lankkulattia, raitatapetti ja puolipaneeli, räsymatto, naulakko takkeineen ja ristipistotaulu.
func _room(root: Node3D) -> void:
	# Lattia: lankut kohti peiliä, kaksi sävyä, raoissa tumma pohja.
	B.mesh(root, B.boxm(Vector3(10.0, 0.04, 8.0)), Vector3(1.0, -0.035, 2.4), Color(0.2, 0.13, 0.08))
	var woods := [Color(0.63, 0.45, 0.27), Color(0.57, 0.4, 0.23), Color(0.66, 0.48, 0.3)]
	for i in 50:
		B.mesh(root, B.boxm(Vector3(0.192, 0.04, 8.0)), Vector3(-4.0 + i * 0.2, -0.02, 2.4), woods[(i * 7) % 3])
	# Takaseinä: tapetti, pystyraidat, valkoinen puolipaneeli urineen, lista ja jalkalista.
	B.mesh(root, B.boxm(Vector3(10.0, 3.4, 0.1)), Vector3(1.0, 1.7, WALL_Z - 0.05), Color(0.62, 0.55, 0.38))
	for i in 34:
		var x := -4.0 + i * 0.3
		B.mesh(root, B.boxm(Vector3(0.07, 2.5, 0.004)), Vector3(x, 2.15, WALL_Z), Color(0.52, 0.43, 0.27))
		B.mesh(root, B.boxm(Vector3(0.012, 2.5, 0.004)), Vector3(x + 0.15, 2.15, WALL_Z), Color(0.48, 0.24, 0.2))
	B.mesh(root, B.boxm(Vector3(10.0, 0.9, 0.03)), Vector3(1.0, 0.45, WALL_Z + 0.015), Color(0.7, 0.68, 0.62))
	for i in 68:
		B.mesh(root, B.boxm(Vector3(0.012, 0.8, 0.004)), Vector3(-4.0 + i * 0.15, 0.48, WALL_Z + 0.03), Color(0.5, 0.48, 0.43))
	B.mesh(root, B.boxm(Vector3(10.0, 0.06, 0.06)), Vector3(1.0, 0.92, WALL_Z + 0.03), Color(0.76, 0.74, 0.68))
	B.mesh(root, B.boxm(Vector3(10.0, 0.11, 0.04)), Vector3(1.0, 0.055, WALL_Z + 0.035), Color(0.76, 0.74, 0.68))
	# Räsymatto hahmon alla: poikkiraidat ja hapsut päissä.
	var rag := [Color(0.72, 0.16, 0.14), Color(0.9, 0.86, 0.74), Color(0.16, 0.3, 0.55), Color(0.9, 0.86, 0.74),
		Color(0.85, 0.66, 0.16), Color(0.9, 0.86, 0.74), Color(0.2, 0.42, 0.28), Color(0.9, 0.86, 0.74)]
	var n := 26
	for i in n:
		var w := 0.09
		B.mesh(root, B.boxm(Vector3(w, 0.012, 0.86)), Vector3((i - (n - 1) * 0.5) * w, 0.006, 0.05), rag[i % rag.size()])
	for side: float in [-1.0, 1.0]:
		for j in 14:
			B.mesh(root, B.boxm(Vector3(0.07, 0.004, 0.012)), Vector3(side * (n * 0.045 + 0.035), 0.003, -0.34 + j * 0.06), Color(0.9, 0.86, 0.74))
	# Naulakko: lauta ja tapit, hattuhylly kannakkeineen, keltainen sadetakki, punainen kaulaliina, karvalakki ja saappaat.
	var nx := -1.35
	var dark := Color(0.36, 0.22, 0.12)
	B.mesh(root, B.boxm(Vector3(1.1, 0.13, 0.03)), Vector3(nx, 1.7, WALL_Z + 0.015), dark)
	B.mesh(root, B.boxm(Vector3(1.1, 0.03, 0.26)), Vector3(nx, 1.9, WALL_Z + 0.13), dark)
	for sx: float in [-0.45, 0.45]:
		B.mesh(root, B.boxm(Vector3(0.03, 0.16, 0.03)), Vector3(nx + sx, 1.82, WALL_Z + 0.04), dark)
		B.tube(root, Vector3(nx + sx, 1.76, WALL_Z + 0.03), Vector3(nx + sx, 1.885, WALL_Z + 0.22), 0.012, dark)
	for k in 4:
		var px := nx - 0.39 + k * 0.26
		B.tube(root, Vector3(px, 1.7, WALL_Z + 0.02), Vector3(px, 1.725, WALL_Z + 0.13), 0.014, Color(0.5, 0.33, 0.18))
		B.mesh(root, B.sphere(0.022, 10), Vector3(px, 1.727, WALL_Z + 0.135), Color(0.5, 0.33, 0.18))
	var coat := Color(0.92, 0.74, 0.12)
	var cx := nx - 0.39
	B.mesh(root, B.capsule(0.2, 0.86), Vector3(cx, 1.24, WALL_Z + 0.12), coat).scale = Vector3(1.0, 1.0, 0.42)
	B.mesh(root, B.sphere(0.13, 12), Vector3(cx, 1.7, WALL_Z + 0.11), coat.darkened(0.08)).scale = Vector3(1.0, 1.15, 0.6)  # huppu
	for sx: float in [-1.0, 1.0]:
		B.mesh(root, B.capsule(0.065, 0.62), Vector3(cx + sx * 0.22, 1.26, WALL_Z + 0.11), coat.darkened(0.05), Vector3(0, 0, sx * 6.0)).scale = Vector3(1.0, 1.0, 0.7)
	for b in 4:
		B.mesh(root, B.sphere(0.014, 8), Vector3(cx, 1.5 - b * 0.16, WALL_Z + 0.207), Color(0.15, 0.15, 0.17))
	var sc := Color(0.7, 0.1, 0.12)
	var sx2 := nx + 0.13
	B.mesh(root, B.capsule(0.045, 0.7), Vector3(sx2 - 0.05, 1.38, WALL_Z + 0.1), sc)
	B.mesh(root, B.capsule(0.045, 0.52), Vector3(sx2 + 0.05, 1.47, WALL_Z + 0.1), sc.darkened(0.12))
	B.mesh(root, B.sphere(0.13, 14), Vector3(nx + 0.2, 1.975, WALL_Z + 0.13), Color(0.3, 0.2, 0.13)).scale = Vector3(1.0, 0.7, 1.0)  # karvalakki
	B.mesh(root, B.sphere(0.07, 10), Vector3(nx + 0.2, 1.93, WALL_Z + 0.24), Color(0.36, 0.25, 0.16)).scale = Vector3(1.6, 0.6, 0.5)
	for sx: float in [-1.0, 1.0]:  # kumisaappaat naulakon alla, kärjet huoneeseen
		var bx := nx + 0.25 + sx * 0.1
		var green := Color(0.13, 0.3, 0.14)
		B.mesh(root, B.cyl(0.055, 0.05, 0.3, 12), Vector3(bx, 0.19, WALL_Z + 0.14), green)
		B.mesh(root, B.capsule(0.05, 0.24), Vector3(bx, 0.05, WALL_Z + 0.2), green, Vector3(90, 0, 0)).scale = Vector3(1.0, 1.0, 0.8)
		B.mesh(root, B.cyl(0.058, 0.058, 0.018, 12), Vector3(bx, 0.335, WALL_Z + 0.14), green.lightened(0.25))
	# Ristipistotaulu seinällä (kyltti: levy ja reunus).
	var taulu := B.sign_plate(root, "KOTI\nKULTA KOTI", Color(0.8, 0.76, 0.64), Color(0.55, 0.1, 0.1), 0.13, 22, Color(0.42, 0.27, 0.14))
	taulu.position = Vector3(0.95, 1.9, WALL_Z + 0.02)


# --- Käyttöliittymä ---------------------------------------------------------------

func _build_ui() -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.09, 0.9)
	sb.border_color = YELLOW
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL_W - PANEL_GAP
	panel.offset_right = -PANEL_GAP
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := _label("KUKA SINÄ OLET?", 40, YELLOW)
	title.add_theme_font_override("font", B.sys_font(PackedStringArray(["Impact", "Arial Black", "Helvetica Neue"]), 900))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	box.add_child(_label("Vilkaisu eteisen peiliin ennen normipäivää.", 17, Color(0.85, 0.85, 0.85)))
	box.add_child(_spacer(6))
	for i in Looks.HAHMO.size():
		box.add_child(_row_ui(i))
	box.add_child(_spacer(8))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	box.add_child(btns)
	btns.add_child(_button("Arvo", _randomize, Color(0.18, 0.16, 0.2)))
	btns.add_child(_button("Valmis", func() -> void: _finish(true), Color(0.55, 0.24, 0.04)))
	_keys = HintBar.new()
	_keys.compact = true
	add_child(_keys)


func _row_ui(i: int) -> Control:
	var row: Dictionary = Looks.HAHMO[i]
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_PASS  # rivi valitaan nuolipainikkeesta, ei hiiren ohituksesta (malli vaihtuisi turhaan)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	pc.add_child(h)
	var name := _label(row.name, 19, Color.WHITE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.custom_minimum_size = Vector2(128, 0)
	h.add_child(name)
	h.add_child(_arrow("‹", func() -> void:
		_select(i)
		_step(-1)))
	var sw := ColorRect.new()
	sw.custom_minimum_size = Vector2(18, 18)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.visible = false
	h.add_child(sw)
	var val := _label("", 19, YELLOW)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.clip_text = true
	h.add_child(val)
	h.add_child(_arrow("›", func() -> void:
		_select(i)
		_step(1)))
	_rows.append([pc, val, sw])
	_refresh_row(i)
	return pc


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _style(b: Button, base: Color) -> void:
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": base, "hover": Color(0.85, 0.35, 0.05), "pressed": Color(1.0, 0.45, 0.1)}[st]
		sb.border_color = Color(0.4, 0.35, 0.3)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override(st, sb)
	b.focus_mode = Control.FOCUS_NONE  # näppäimet luetaan itse (_input): painike ei saa napata Enteriä tai nuolia


func _arrow(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(38, 34)
	b.add_theme_font_size_override("font_size", 24)
	_style(b, Color(0.18, 0.16, 0.2))
	b.pressed.connect(cb)
	return b


func _button(text: String, cb: Callable, base: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	_style(b, base)
	b.pressed.connect(cb)
	return b


func _refresh_row(i: int) -> void:
	var row: Dictionary = Looks.HAHMO[i]
	var opt := Looks.custom_opt(row.id)
	var text: String = opt[1]
	if row.id == "lippis" and Looks.custom_opt("tukka")[0] in Looks.NO_CAP_HAIR:
		text = "Ei mahdu tukan päälle"
	(_rows[i][1] as Label).text = text
	var sw: ColorRect = _rows[i][2]
	var v: Variant = opt[2]
	if v is Array and (v as Array)[0] is Color:
		v = (v as Array)[0]
	sw.visible = v is Color
	if v is Color:
		sw.color = v


func _select(i: int) -> void:
	var bare := _bare()
	_row = clampi(i, 0, _rows.size() - 1)
	if _char != null and bare != _bare():
		_restyle()
	for k in _rows.size():
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.8, 0.1, 0.16) if k == _row else Color(0, 0, 0, 0)
		sb.border_color = YELLOW if k == _row else Color(0, 0, 0, 0)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		(_rows[k][0] as PanelContainer).add_theme_stylebox_override("panel", sb)


# --- Valinnat --------------------------------------------------------------------

func _index(row: Dictionary) -> int:
	var id: String = Looks.custom_opt(row.id)[0]
	for k in (row.opts as Array).size():
		if row.opts[k][0] == id:
			return k
	return 0


func _step(dir: int) -> void:
	var row: Dictionary = Looks.HAHMO[_row]
	var n: int = (row.opts as Array).size()
	Looks.custom[row.id] = row.opts[posmod(_index(row) + dir, n)][0]
	for i in _rows.size():
		_refresh_row(i)  # tukka vaikuttaa myös päähineen riviin
	_restyle()
	Sfx.play("cloth", -8.0, 1.25)


func _randomize() -> void:
	for i in Looks.HAHMO.size():
		var row: Dictionary = Looks.HAHMO[i]
		Looks.custom[row.id] = (row.opts as Array).pick_random()[0]
		_refresh_row(i)
	_restyle()
	Sfx.play("cloth", -5.0, 0.9)


## Tukan ja hiusten värin riveillä lippis on hetken kädessä: muuten se peittäisi juuri sen, mitä valitaan.
func _bare() -> bool:
	return Looks.HAHMO[_row].id in ["tukka", "hiusvari"]


func _restyle() -> void:
	var lippis: Variant = Looks.custom.get("lippis")
	if _bare():
		Looks.custom["lippis"] = "ei"
	Looks.restyle_player(_char)
	if lippis == null:
		Looks.custom.erase("lippis")
	else:
		Looks.custom["lippis"] = lippis
	_char.play("Idle", 0.0)


func _finish(accepted: bool) -> void:
	if not accepted:
		Looks.custom = _before
	finished.emit(accepted)


# --- Ohjaus ja kamera -------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if can_cancel:
			_finish(false)
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return  # hiiri: painikkeet ja hahmon kääntö (_stage_input)
	if event.is_echo():
		return
	var handled := true
	if event.is_action_pressed("forward"):
		_select(posmod(_row - 1, _rows.size()))
	elif event.is_action_pressed("back"):
		_select(posmod(_row + 1, _rows.size()))
	elif event.is_action_pressed("left"):
		_step(-1)
	elif event.is_action_pressed("right"):
		_step(1)
	elif event.is_action_pressed("bell"):
		_randomize()
	elif event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]):
		_finish(true)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Hahmoa käännetään vetämällä hiirellä (tai sormella) lavastuksen päällä.
func _stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		_yaw_to = wrapf(_yaw_to + event.relative.x * 0.012, -PI, PI)


## Kameran paikka rajaukselle: kohde (korkeus m) täyttää osuuden ruudun korkeudesta ja on vaakasuunnassa paneelin
## vasemmalle jäävän alueen keskellä. Kamera katsoo suoraan -Z:aan, joten paikka seuraa suoraan näkökentästä.
func cam_goal(mode: String) -> Vector3:
	var vs := _tex.size
	if vs.y < 1.0:
		vs = Vector2(1280, 720)
	var fx := clampf((vs.x - PANEL_W - PANEL_GAP) * 0.5 / vs.x, 0.2, 0.5)
	var t := tan(deg_to_rad(FOV * 0.5))
	var fr: Array = FRAME[mode]
	var d: float = float(fr[0]) * 0.5 / (t * float(fr[1]))
	var cy := 0.94
	if mode == "paa":
		cy = _char.bone_position("Head").y + 0.07
	return Vector3(-(2.0 * fx - 1.0) * d * t * vs.x / vs.y, cy, d)


func _process(delta: float) -> void:
	var px := Vector2i(get_window().size)
	if px.x > 0 and px.y > 0 and _vp.size != px:
		_vp.size = px
	var goal := cam_goal(String(Looks.HAHMO[_row].cam))
	_cam.position = goal if _snap else _cam.position.lerp(goal, 1.0 - exp(-7.0 * delta))
	_snap = false
	_yaw = lerp_angle(_yaw, _yaw_to, 1.0 - exp(-12.0 * delta))
	_char.rotation.y = PI + _yaw
	_keys.set_text("%s Rivi   %s Vaihda   %s Arvo   [Hiiri] Käännä   %s Valmis%s" % [Settings.pair("forward", "back"),
		Settings.pair("left", "right"), Settings.cap("bell"), Settings.cap("interact"), "   [Esc] Takaisin" if can_cancel else ""])
