extends CanvasLayer
## Keskusteluikkuna ruudun alareunassa: puhujan nimi omalla värillään, hahmon repliikki ja numeroitu valintalista.
## Kaikki hahmon kanssa tehtävät asiat (myynti, kaupat, tehtävät, juttelu) näkyvät rinnakkain; juuri nyt mahdoton
## valinta on harmaana ja syy perässä. Valinta: numerot 1–9, W/S tai rulla + E / vasen nappi / klikkaus, Q tai Esc
## lopettaa. Pidemmät puheet (say_lines) etenevät painalluksella rivi kerrallaan, valinnat piilossa sillä aikaa.
## Käyttäjä (main.gd) antaa vaihtoehdot muodossa [{id, text, enabled, reason}] ja kuuntelee chosen- ja closed-signaaleja.

signal chosen(id: String)
signal closed

const W := 760.0
const PAD := 18.0

var speaker := ""
var _color := Color.WHITE
var _line := ""
var _info := ""
var _pages: Array = []
var _options: Array = []
var _sel := 0
var _open_frame := -1
var _root: Control
var _panel: Panel
var _name: Label
var _text: Label
var _info_label: Label
var _list: VBoxContainer
var _help: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -W / 2.0
	_panel.offset_right = W / 2.0
	_panel.offset_bottom = -64.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.92)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(1.0, 0.85, 0.2)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)
	var box := VBoxContainer.new()
	box.position = Vector2(PAD, PAD - 4.0)
	box.size = Vector2(W - PAD * 2.0, 10)
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_name = _mk_label(22, Color.WHITE)
	box.add_child(_name)
	_text = _mk_label(22, Color(0.95, 0.95, 0.92))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(W - PAD * 2.0, 0)
	box.add_child(_text)
	_info_label = _mk_label(18, Color(1.0, 0.85, 0.35))
	box.add_child(_info_label)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	box.add_child(_list)
	_help = _mk_label(14, Color(0.7, 0.7, 0.72))
	box.add_child(_help)
	box.resized.connect(_fit)
	visible = false


func _mk_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _fit() -> void:
	var box := _panel.get_child(0) as Control
	_panel.offset_top = _panel.offset_bottom - box.size.y - PAD * 2.0 + 6.0


func is_open() -> bool:
	return visible


## Avaa keskustelun: puhujan nimi ja väri, aloitusrepliikki ja vaihtoehdot.
func open(who: String, color: Color, line: String, options: Array, info := "") -> void:
	speaker = who
	_color = color
	_line = line
	_info = info
	_pages.clear()
	_options = options
	_sel = _first_enabled()
	_open_frame = Engine.get_process_frames()
	visible = true
	_refresh()


## Hahmon vastaus ja päivitetyt vaihtoehdot (info = pieni keltainen rivi, esim. "+17 €").
func reply(line: String, options: Array, info := "") -> void:
	_line = line
	_info = info
	_options = options
	_sel = clampi(_sel, 0, maxi(0, options.size() - 1))
	if options.size() > 0 and not options[_sel].get("enabled", true):
		_sel = _first_enabled()
	_open_frame = Engine.get_process_frames()
	_refresh()


## Pidempi puhe: rivit painallus kerrallaan, lopuksi vaihtoehdot.
func say_lines(lines: Array, options: Array, info := "") -> void:
	_pages = lines.duplicate()
	_line = _pages.pop_front()
	_info = info
	_options = options
	_sel = _first_enabled()
	_open_frame = Engine.get_process_frames()
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _first_enabled() -> int:
	for i in _options.size():
		if _options[i].get("enabled", true):
			return i
	return 0


func _refresh() -> void:
	_name.text = speaker.to_upper()
	_name.add_theme_color_override("font_color", _color)
	_text.text = "“%s”" % _line if _line != "" else ""
	_info_label.text = _info
	_info_label.visible = _info != ""
	for c in _list.get_children():
		c.queue_free()
	var paging := not _pages.is_empty()
	if paging:
		_help.text = "E / vasen nappi / välilyönti: jatka   ·   Q lopeta"
	else:
		for i in _options.size():
			var o: Dictionary = _options[i]
			var en: bool = o.get("enabled", true)
			var row := Label.new()
			var key := str(i + 1) if i < 9 else " "
			var txt: String = o.text + ("  (%s)" % o.reason if not en and o.get("reason", "") != "" else "")
			row.text = ("▶ " if i == _sel else "   ") + key + "  " + txt
			row.add_theme_font_size_override("font_size", 20)
			var col := Color(1.0, 0.85, 0.2) if i == _sel else Color.WHITE
			row.add_theme_color_override("font_color", col if en else Color(0.5, 0.5, 0.52))
			row.mouse_filter = Control.MOUSE_FILTER_STOP
			row.gui_input.connect(_row_input.bind(i))
			row.mouse_entered.connect(func() -> void:
				if i != _sel:
					_sel = i
					_refresh())
			_list.add_child(row)
		_help.text = "1–%d tai W/S + E valitse   ·   hiiri klikkaa   ·   Q / Esc lopeta" % mini(_options.size(), 9)
	_fit.call_deferred()


func _row_input(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_sel = i
		_choose()


func _choose() -> void:
	if not _pages.is_empty():
		_line = _pages.pop_front()
		_refresh()
		return
	if _options.is_empty():
		close()
		return
	var o: Dictionary = _options[_sel]
	if not o.get("enabled", true):
		_info = o.get("reason", "Ei onnistu nyt.")
		_refresh()
		return
	chosen.emit(o.id)


func _input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _open_frame:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_9 and _pages.is_empty():
			var i := k - KEY_1
			if i < _options.size():
				_sel = i
				get_viewport().set_input_as_handled()
				_choose()
			return
		if k == KEY_ESCAPE or event.is_action("bell"):
			get_viewport().set_input_as_handled()
			close()
		elif event.is_action("forward") and _pages.is_empty():
			_move(-1)
		elif event.is_action("back") and _pages.is_empty():
			_move(1)
		elif event.is_action("interact") or (k == KEY_SPACE and not _pages.is_empty()):
			get_viewport().set_input_as_handled()
			_choose()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and _pages.is_empty():
			_move(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and _pages.is_empty():
			_move(1)
		elif event.button_index == MOUSE_BUTTON_LEFT and not _pages.is_empty():
			_choose()


func _move(d: int) -> void:
	if _options.is_empty():
		return
	_sel = (_sel + d + _options.size()) % _options.size()
	get_viewport().set_input_as_handled()
	_refresh()
