extends CanvasLayer
## Alkuvalikko, taukovalikko (Esc) ja asetukset: grafiikka, ääni, ohjaus. Ohjeet ja tekijät.
## Peli on pysäytetty valikon ollessa auki; alkuvalikon taustalla kamera kiertää Järvikujaa.

const M := preload("res://scripts/map_data.gd")
const SAVE_PATH := "user://normipaiva.cfg"
const YELLOW := Color(1.0, 0.8, 0.1)
const CONTROLS := """Näppäimet voi vaihtaa: Asetukset → Näppäimet (alla oletukset).
PYÖRÄLLÄ
W / S	polje / jarruta ja peruuta
A / D	ohjaa
Välilyönti	jarru
Q	soittokello
Shift	spurtti (kuluttaa kuntoa)
F	nouse pyörän selästä / takaisin pyörälle
JALAN
W / S, A / D	kävele ja käänny
Shift	juokse (kuluttaa kuntoa)
A / D	marjoja poimiessa: kyykkyyn ja ylös vuorotellen
YLEISET
E	toiminto (kauppa, poiminta, nuotio, myynti)
M	paperikartta (W/S tai rulla vierittää)
V	FPS / kolmas persoona
Hiiri	kamera (Esc vapauttaa hiiren valikkoon)
Esc	taukovalikko (myös päivän aloitus alusta)
SAHAUS (kodan sahapukilla)
Hiiri / E	merkkaa katkaisukohta ja aloita
Hiiri eteen-taakse / W-S	sahaa (pitkät, rauhalliset vedot)
Hiiri sivulle / A-D	pidä saha suorassa
Oikea nappi	nosta saha pois (ennen kuin ura on syvä)
HALONHAKKUU (kodan pilkkomispölkyllä)
Hiiri	tähtää (kädet huojuvat, tuuli puuskii)
Vasen nappi / E	nosta pölkky, aseta pölkylle, iske
Oikea nappi / Q / rulla	käännä pölkky (tasainen pää alas)
F	lopeta hakkuu
KÄDENVÄÄNTÖ (Raahen baarissa)
E	tartu kättä
A / D	vuorotellen tasaiseen, reippaaseen tahtiin
TAPPELU
A / D, W, S	liiku, hyppää, torju
J / K	lyönti / potku
S+J, S+K	pystykoukku, jalkapyyhkäisy
eteen+K, ilmassa K	kiertopotku, lentopotku
L	kassi-isku (rikkoo kaljan)"""

var game: Node3D
var _root: Control
var _panel: PanelContainer
var _box: VBoxContainer
var _mode := ""  # main | pause
var _menu_cam: Camera3D
var _cam_t := 0.0
var _capture := {}  # näppäinasetus odottaa painallusta: {row, slot}
var _key_buttons := []  # [row, slot, Button]
var _key_note: Label


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	visible = false


## Näppäimen vaihto: seuraava painallus asetetaan (Esc peruu), eikä se päädy valikolle.
func _input(event: InputEvent) -> void:
	if _capture.is_empty() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	var row: int = _capture.row
	var slot: int = _capture.slot
	_capture = {}
	if code == KEY_ESCAPE:
		_key_note.text = "Peruttu."
	else:
		var moved: String = Settings.bind_key(row, slot, code)
		_key_note.text = "%s: %s" % [Settings.KEY_ROWS[row][1], Settings.key_name(code)] + 			("  (poistettu kohdasta %s)" % moved if moved != "" else "")
	_refresh_keys()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if visible:
			if _mode == "pause":
				close()
			elif _mode == "sub_main":
				open_main()
			elif _mode == "sub_pause":
				open_pause()
			get_viewport().set_input_as_handled()
		elif game != null and game.state in ["to_shop", "to_home", "in_shop", "in_mokki", "in_home", "minigame"] and not game._paper.visible \
				and not game._inventory.visible:
			open_pause()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _menu_cam != null and _menu_cam.current:
		_cam_t += delta
		var c: Vector3 = M.w(M.HOME_BUILDING)
		var a := _cam_t * 0.08
		_menu_cam.global_position = c + Vector3(cos(a) * 28.0, 9.0, sin(a) * 28.0)
		_menu_cam.look_at(c + Vector3(0, 2.0, 0), Vector3.UP)


# --- Näkymät -------------------------------------------------------------------

func open_main() -> void:
	_mode = "main"
	_show()
	if _menu_cam == null:
		_menu_cam = Camera3D.new()
		_menu_cam.fov = 55.0
		_menu_cam.far = 1500.0
		game.add_child(_menu_cam)
	_menu_cam.current = true
	game._hud.visible = false
	Sfx.music_play()
	var has_save := FileAccess.file_exists(SAVE_PATH)
	_title("NORMIPÄIVÄ", "S A L O I S I S S A")
	_button("Jatka peliä" if has_save else "Aloita peli", close)
	if has_save:
		_button("Uusi peli", _confirm_new)
	_button("Asetukset", func() -> void: _settings("sub_main"))
	_button("Ohjaimet", func() -> void: _controls("sub_main"))
	_button("Tekijät", func() -> void: _credits("sub_main"))
	_button("Lopeta", func() -> void:
		game._save_game()
		get_tree().quit())


func open_pause() -> void:
	_mode = "pause"
	_show()
	_title("TAUKO", "Päivä %d · jemmassa %d kaljaa" % [game.day, game.jemma])
	_button("Jatka", close)
	_button("Asetukset", func() -> void: _settings("sub_pause"))
	_button("Ohjaimet", func() -> void: _controls("sub_pause"))
	_button("Aloita päivä alusta", func() -> void:
		get_tree().paused = false
		game.get_script().skip_menu = true
		get_tree().reload_current_scene())
	_button("Päävalikkoon", func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	_button("Lopeta peli", func() -> void:
		game._save_game()
		get_tree().quit())


func close() -> void:
	visible = false
	get_tree().paused = false
	if _mode == "main" or _mode == "sub_main":
		Sfx.music_stop()
		game._hud.visible = true
		game.player.activate_camera()
	_mode = ""


func _back(from: String) -> void:
	if from == "sub_main":
		open_main()
	else:
		open_pause()


func _confirm_new() -> void:
	_mode = "sub_main"
	_clear()
	_title("UUSI PELI?", "Jemma, rahat, päivät ja laavun valtaus nollataan.")
	_button("Kyllä, aloita alusta", func() -> void:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		get_tree().paused = false
		game.get_script().skip_menu = true
		get_tree().reload_current_scene())
	_button("Takaisin", open_main)


func _controls(from: String) -> void:
	_mode = from
	_clear()
	_title("OHJAIMET", "")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	for line in CONTROLS.split("\n"):
		var parts := line.split("\t")
		var k := _label(parts[0], 17, YELLOW if parts.size() == 1 else Color(0.9, 0.9, 0.85))
		grid.add_child(k)
		grid.add_child(_label(parts[1] if parts.size() > 1 else "", 17, Color.WHITE))
	_box.add_child(grid)
	_button("Takaisin", func() -> void: _back(from))


func _credits(from: String) -> void:
	_mode = from
	_clear()
	_title("TEKIJÄT", "")
	for t in ["Normipäivä Saloisissa – tehty Godot 4 -pelimoottorilla", "Kartta: Saloinen, Raahe",
			"Hahmot ja animaatiot: Quaternius (CC0)", "Äänet: OpenGameArt ja Kenney (CC0)",
			"Tunnusbiisi: Normipäivä Saloisissa (rautalanka, tehty Sunolla)",
			"Kiitos Päiville, Pirjolle, Artolle ja Pekalle"]:
		_box.add_child(_label(t, 18, Color.WHITE))
	_button("Takaisin", func() -> void: _back(from))


func _settings(from: String) -> void:
	_mode = from
	_clear()
	_title("ASETUKSET", "")
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(560, 380)
	_box.add_child(tabs)
	var g := _tab(tabs, "Grafiikka")
	var weak := Button.new()
	weak.text = "Heikko kone: valitse kevyimmät asetukset"
	weak.tooltip_text = "Erittäin matala laatu, renderöintiskaala 70 % ja lyhyt näkyvyysetäisyys."
	weak.custom_minimum_size = Vector2(0, 40)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.18, 0.16, 0.2), "hover": Color(0.85, 0.35, 0.05), "pressed": Color(1.0, 0.45, 0.1),
			"focus": Color(0.18, 0.16, 0.2)}[st]
		sb.border_color = YELLOW if st == "focus" else Color(0.4, 0.35, 0.3)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		weak.add_theme_stylebox_override(st, sb)
	weak.pressed.connect(func() -> void:
		Settings.set_v("quality", 0)
		Settings.set_v("render_scale", 0.7)
		Settings.set_v("view_distance", 0)
		_settings(from))
	g.add_child(weak)
	_option(g, "Laatu", Settings.QUALITY, Settings.get_v("quality"), func(i: int) -> void: Settings.set_v("quality", i))
	_check(g, "Koko näyttö", "fullscreen")
	_check(g, "Pystytahdistus (V-Sync)", "vsync")
	_slider(g, "Renderöintiskaala", "render_scale", 0.5, 1.0, 0.05, "%d %%", 100.0)
	_option(g, "Näkyvyysetäisyys (lyhyt keventää)", Settings.VIEW_NAMES, Settings.get_v("view_distance"),
		func(i: int) -> void: Settings.set_v("view_distance", i))
	_slider(g, "Näkökenttä (FOV)", "fov", 55.0, 95.0, 1.0, "%d°", 1.0)
	_check(g, "Näytä FPS", "show_fps")
	_check(g, "Näytä opasteet (paikkojen ja hahmojen nimet)", "show_guides")
	var note := _label("", 14, Color(0.8, 0.8, 0.8))
	var note_text := func() -> String:
		return "Käytössä nyt: %s. Vaihtuu, kun peli käynnistetään uudelleen." % Settings.RENDERERS[Settings.renderer_current()]
	_option(g, "Grafiikkamoottori", Settings.RENDERERS, Settings.renderer_saved(), func(i: int) -> void:
		Settings.set_renderer(i)
		note.text = note_text.call() if i != Settings.renderer_current() else "")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.add_child(note)
	var a := _tab(tabs, "Ääni")
	_slider(a, "Kokonaisvoimakkuus", "vol_master", 0.0, 1.0, 0.05, "%d %%", 100.0)
	_slider(a, "Tehosteet", "vol_sfx", 0.0, 1.0, 0.05, "%d %%", 100.0)
	_slider(a, "Ympäristö", "vol_ambience", 0.0, 1.0, 0.05, "%d %%", 100.0)
	_slider(a, "Musiikki", "vol_music", 0.0, 1.0, 0.05, "%d %%", 100.0)
	var c := _tab(tabs, "Ohjaus")
	_slider(c, "Hiiren herkkyys", "mouse_sens", 0.3, 3.0, 0.1, "%.1f", 1.0)
	_check(c, "Käänteinen pystyakseli", "invert_y")
	_check(c, "Hiiri kääntää kameraa", "mouse_look")
	_check(c, "Hiiri ohjaa kulkusuuntaa (FPS-tyyli)", "mouse_steer")
	_check(c, "Kamera palaa itsestään taakse", "auto_recenter")
	_keys_tab(tabs)
	_button("Takaisin", func() -> void: _back(from))


## Näppäimet-välilehti: jokaisella toiminnolla kaksi paikkaa; napsautus odottaa uutta näppäintä.
func _keys_tab(tabs: TabContainer) -> void:
	var k := _tab(tabs, "Näppäimet")
	_capture = {}
	_key_buttons.clear()
	_key_note = _label("Napsauta näppäintä ja paina uutta. Esc peruu. Sama näppäin voi olla vain yhdessä kohdassa.", 15,
		Color(0.85, 0.85, 0.85))
	_key_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_key_note.custom_minimum_size = Vector2(520, 0)
	k.add_child(_key_note)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	k.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for r in Settings.KEY_ROWS.size():
		var h := _row(list, Settings.KEY_ROWS[r][1])
		(h.get_child(0) as Label).custom_minimum_size = Vector2(230, 0)
		for slot in 2:
			var b := Button.new()
			b.custom_minimum_size = Vector2(130, 30)
			b.focus_mode = Control.FOCUS_NONE
			_key_style(b)
			b.pressed.connect(func() -> void:
				_capture = {"row": r, "slot": slot}
				_key_note.text = "Paina uutta näppäintä kohtaan %s… (Esc peruu)" % Settings.KEY_ROWS[r][1]
				_refresh_keys())
			h.add_child(b)
			_key_buttons.append([r, slot, b])
		var clr := Button.new()
		clr.text = "×"
		clr.tooltip_text = "Tyhjennä toinen näppäin"
		clr.focus_mode = Control.FOCUS_NONE
		_key_style(clr)
		clr.pressed.connect(func() -> void:
			Settings.bind_key(r, 1, 0)
			_refresh_keys())
		h.add_child(clr)
	var reset := Button.new()
	reset.text = "Palauta oletusnäppäimet"
	reset.focus_mode = Control.FOCUS_NONE
	reset.custom_minimum_size = Vector2(0, 34)
	_key_style(reset)
	reset.pressed.connect(func() -> void:
		Settings.reset_keys()
		_capture = {}
		_key_note.text = "Oletusnäppäimet palautettu."
		_refresh_keys())
	k.add_child(reset)
	_refresh_keys()


## Näppäinnappi näyttää näppäimeltä: tumma laatikko reunuksella, hover oranssi.
func _key_style(b: Button) -> void:
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.16, 0.15, 0.18), "hover": Color(0.85, 0.35, 0.05), "pressed": Color(1.0, 0.45, 0.1)}[st]
		sb.border_color = Color(0.5, 0.45, 0.4)
		sb.set_border_width_all(2)
		sb.border_width_bottom = 4
		sb.set_corner_radius_all(5)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		b.add_theme_stylebox_override(st, sb)


func _refresh_keys() -> void:
	for kb in _key_buttons:
		var b: Button = kb[2]
		var waiting: bool = not _capture.is_empty() and _capture.row == kb[0] and _capture.slot == kb[1]
		b.text = "…" if waiting else Settings.key_name(Settings.keys_of(kb[0])[kb[1]])
		b.modulate = YELLOW if waiting else Color.WHITE


# --- Rakennuspalikat ------------------------------------------------------------

func _show() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear()


func _clear() -> void:
	_capture = {}
	for ch in _root.get_children():
		ch.queue_free()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.35 if _mode.begins_with("main") or _mode == "sub_main" else 0.55)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.09, 0.88)
	sb.border_color = YELLOW
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(_box)


func _title(text: String, sub: String) -> void:
	var t := _label(text, 64, YELLOW)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Impact", "Arial Black", "Helvetica Neue"])
	f.font_weight = 900
	t.add_theme_font_override("font", f)
	t.add_theme_constant_override("outline_size", 12)
	_box.add_child(t)
	if sub != "":
		_box.add_child(_label(sub, 20, Color.WHITE))


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 46)
	b.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.18, 0.16, 0.2), "hover": Color(0.85, 0.35, 0.05), "pressed": Color(1.0, 0.45, 0.1),
			"focus": Color(0.18, 0.16, 0.2)}[st]
		sb.border_color = YELLOW if st == "focus" else Color(0.4, 0.35, 0.3)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	_box.add_child(b)
	if _box.get_child_count() <= 3:
		b.call_deferred("grab_focus")


func _tab(tabs: TabContainer, name: String) -> VBoxContainer:
	var m := MarginContainer.new()
	m.name = name
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	tabs.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	return v


func _row(parent: Control, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var l := _label(text, 18, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(250, 0)
	h.add_child(l)
	parent.add_child(h)
	return h


func _check(parent: Control, text: String, key: String) -> void:
	var h := _row(parent, text)
	var c := CheckButton.new()
	c.button_pressed = Settings.get_v(key)
	c.toggled.connect(func(on: bool) -> void: Settings.set_v(key, on))
	h.add_child(c)


func _option(parent: Control, text: String, items: Array, sel: int, cb: Callable) -> void:
	var h := _row(parent, text)
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = sel
	o.item_selected.connect(cb)
	o.custom_minimum_size = Vector2(200, 0)
	h.add_child(o)


func _slider(parent: Control, text: String, key: String, lo: float, hi: float, step: float, fmt: String, mul: float) -> void:
	var h := _row(parent, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = Settings.get_v(key)
	s.custom_minimum_size = Vector2(200, 24)
	h.add_child(s)
	var v := _label(fmt % (s.value * mul), 18, YELLOW)
	v.custom_minimum_size = Vector2(70, 0)
	h.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = fmt % (x * mul)
		Settings.set_v(key, x))
