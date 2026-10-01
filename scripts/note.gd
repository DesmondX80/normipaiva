extends Control
## Päivin heippalappu: päivän alun ohjeet keltaisena muistilappuna ruudun vasemmalla (vinossa, teippi yläreunassa,
## käsialafontti, allekirjoitus; kauppalistan tuotteet värikynillä). Häipyy itsestään; show_note() korvaa edellisen.

const PAPER := Color(1.0, 0.95, 0.55)
const INK := Color(0.16, 0.18, 0.42)
const WIDTH := 400.0
const TOP := 140.0  # lapun oletusyläreuna
const MARGIN := 24.0  # väli ruudun reunoihin lapun mahduttamisessa
const MIN_SCALE := 0.55  # pienin kutistus: sitä pidempi lappu leikkaantuu mieluummin kuin muuttuu lukukelvottomaksi
const GOOD_SCALE := 0.85  # tätä pienemmäksi kutistuva lappu leveämmäksi: leveällä rivit eivät rivity niin paljon
const WIDTHS := [400.0, 540.0, 680.0]

var _holder: Control  # lappu ja teippi yhdessä (vinossa)
var _paper: PanelContainer
var _box: VBoxContainer
var _tw: Tween
var _tape: ColorRect
var _width := WIDTH
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
	_tape = tape
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
	_fit.call_deferred()


## Mahduttaa lapun ruudulle (pitkät lapussa on monta muistutusta): ensin levennetään, jotta rivit rivittyvät vähemmän,
## sitten nostetaan ylemmäs ja viimeiseksi kutistetaan.
func _fit() -> void:
	var vp := get_viewport_rect().size
	var best := 0.0
	var best_h := 0.0
	for w in WIDTHS:
		_set_width(w)
		await get_tree().process_frame  # rivit asettuvat vasta ruudun yli
		_paper.size = Vector2(w, 0.0)
		var h := _paper.get_combined_minimum_size().y
		var room := vp.y - 2.0 * MARGIN - 14.0
		best = w
		best_h = h
		if h <= room or minf(1.0, room / h) >= GOOD_SCALE or w + 20.0 > vp.x * 0.62:
			break  # mahtuu (lähes) sellaisenaan tai leveämpi ei enää mahdu ruudun leveyteen
	var y := TOP
	var sc := 1.0
	if y + best_h > vp.y - MARGIN:
		y = maxf(MARGIN + 14.0, vp.y - MARGIN - best_h)  # teippi ulottuu 12 px lapun yläpuolelle
	if y + best_h > vp.y - MARGIN:
		sc = clampf((vp.y - 2.0 * MARGIN - 14.0) / best_h, MIN_SCALE, 1.0)
		y = MARGIN + 14.0
	_holder.scale = Vector2(sc, sc)
	_holder.position = Vector2(34.0, y)


func _set_width(w: float) -> void:
	_width = w
	_paper.custom_minimum_size = Vector2(w, 0)
	_tape.position.x = w / 2.0 - 55.0
	for c in _box.get_children():
		if c is Label:
			c.custom_minimum_size = Vector2(w - 50.0, 0)


func is_showing() -> bool:
	return _holder.modulate.a > 0.01


func _line(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(_width - 50.0, 0)
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
