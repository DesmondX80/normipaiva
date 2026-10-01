extends Control
## Päivin heippalappu: päivän alun ohjeet keltaisena muistilappuna ruudun vasemmalla (vinossa, teippi yläreunassa,
## käsialafontti, allekirjoitus). Lapun alla Päivin ääneen sanoma repliikki (esim. kauppalistan värit, joita hän ei
## kirjoittanut lappuun). Häipyy itsestään; show_note() korvaa edellisen.

const PAPER := Color(1.0, 0.95, 0.55)
const INK := Color(0.16, 0.18, 0.42)
const WIDTH := 400.0

var _holder: Control  # lappu ja teippi yhdessä (vinossa)
var _paper: PanelContainer
var _box: VBoxContainer
var _speech: Label
var _tw: Tween
var _speech_tw: Tween
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
	_speech = Label.new()
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.custom_minimum_size = Vector2(WIDTH + 260, 0)
	_speech.position = Vector2(30, 0)
	_speech.add_theme_font_size_override("font_size", 21)
	_speech.add_theme_color_override("font_color", Color(1, 1, 1))
	_speech.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_speech.add_theme_constant_override("outline_size", 7)
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_speech)
	_holder.modulate.a = 0.0
	_speech.modulate.a = 0.0


## Uusi lappu: rivit (tyhjät ohitetaan; "• " alkavat listana), allekirjoitus ja näkymisaika sekunteina.
func show_note(lines: Array, sign := "– Päivi", seconds := 12.0) -> void:
	for c in _box.get_children():
		c.queue_free()
	var first := true
	for raw in lines:
		var t := String(raw).strip_edges()
		if t == "":
			continue
		var l := _line(t, 28 if first else 22)
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
	_place_speech.call_deferred()


## Päivin repliikki lapun alla (lainausmerkeissä), näkyy seconds sekuntia.
func say(text: String, seconds := 9.0) -> void:
	_speech.text = text
	if _speech_tw != null:
		_speech_tw.kill()
	_speech_tw = create_tween()
	_speech_tw.tween_property(_speech, "modulate:a", 1.0, 0.3)
	_speech_tw.tween_interval(seconds)
	_speech_tw.tween_property(_speech, "modulate:a", 0.0, 0.8)
	_place_speech.call_deferred()


func is_showing() -> bool:
	return _holder.modulate.a > 0.01


func _place_speech() -> void:
	var bottom := _holder.position.y + _paper.size.y + 16.0 if _holder.modulate.a > 0.01 or _tw != null else 150.0
	_speech.position = Vector2(30, bottom)


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
