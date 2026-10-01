extends Control
## Päivin heippalappu: päivän alun ohjeet keltaisena muistilappuna ruudun vasemmalla (vinossa, teippi yläreunassa,
## käsialafontti, allekirjoitus; kauppalistan tuotteet värikynillä). Häipyy itsestään; show_note() korvaa edellisen.

const PAPER := Color(1.0, 0.95, 0.55)
const INK := Color(0.16, 0.18, 0.42)
const WIDTH := 400.0

var _holder: Control  # lappu ja teippi yhdessä (vinossa)
var _paper: PanelContainer
var _box: VBoxContainer
var _tw: Tween
var _font: SystemFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Bradley Hand", "Segoe Print", "Comic Sans MS", "Chalkboard SE", "Marker Felt",
		"Noteworthy", "sans-serif"])
	_paper = PanelContainer.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(5, 7)
	sb.content_margin_left = 26
	sb.content_margin_right = 24
	sb.content_margin_top = 30
	sb.content_margin_bottom = 20
	sb.corner_radius_bottom_right = 18  # käpristynyt kulma
	_paper.add_theme_stylebox_override("panel", sb)
	_paper.custom_minimum_size = Vector2(WIDTH, 0)
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.position = Vector2(34, 140)
	_holder.rotation = deg_to_rad(-2.2)
	add_child(_holder)
	_holder.add_child(_paper)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_paper.add_child(_box)
	# Teippi yläreunassa.
	var tape := ColorRect.new()
	tape.color = Color(0.95, 0.95, 0.9, 0.7)
	tape.size = Vector2(110, 26)
	tape.position = Vector2(WIDTH / 2.0 - 55, -12)
	tape.rotation = deg_to_rad(3.0)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(tape)  # ei PanelContainerin lapsena (se venyttäisi teipin koko lapun päälle)
	_holder.modulate.a = 0.0


## Uusi lappu: rivit (tyhjät ohitetaan; "• " alkavat listana), allekirjoitus ja näkymisaika sekunteina.
## Rivi voi olla myös [teksti, väri]: kirjoitettu värikynällä (ohut tumma reunus, jotta keltainenkin erottuu).
func show_note(lines: Array, sign := "– Päivi", seconds := 12.0) -> void:
	for c in _box.get_children():
		c.queue_free()
	var first := true
	for raw in lines:
		var ink := INK
		var pen := false
		if raw is Array:
			ink = raw[1]
			pen = true
			raw = raw[0]
		var t := String(raw).strip_edges()
		if t == "":
			continue
		var l := _line(t, 28 if first else 22)
		if pen:
			l.add_theme_color_override("font_color", ink)
			l.add_theme_color_override("font_outline_color", INK.darkened(0.3))
			l.add_theme_constant_override("outline_size", 4)
		first = false
		_box.add_child(l)
	if sign != "":
		var s := _line(sign, 26)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_box.add_child(s)
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_holder, "modulate:a", 1.0, 0.35)
	_tw.tween_interval(seconds)
	_tw.tween_property(_holder, "modulate:a", 0.0, 0.8)


func is_showing() -> bool:
	return _holder.modulate.a > 0.01


func _line(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH - 50, 0)
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
