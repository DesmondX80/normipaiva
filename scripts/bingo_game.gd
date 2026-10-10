extends CanvasLayer
## Bingo Saloisten seuraintalolla (#129): oma 5×5-lappu (B 1–15, I 16–30, N 31–45 vapaa keskiruutu, G 46–60,
## O 61–75). Erkki arpoo pallokoneesta numeron CALL_S sekunnin välein; huudetut numerot merkitään klikkaamalla
## omaan lappuun. Kun rivi (vaaka, pysty tai vino) on täynnä, BINGO-nappi: oikea huuto voittaa. Väärä huuto nolaa
## (mummot mulkoilevat) ja maksaa maineen. Joku mummoista saa bingon RIVAL_AT-huudon paikkeilla: ehdi ensin.
## F / Esc lopettaa. finished(won, false_calls).

signal finished(won: bool, false_calls: int)

const MG := preload("res://scripts/mg_draw.gd")
const CALL_S := 3.0
const COLS := "BINGO"

var drunk := 0.0
var rival_at := 22  # monennellako huudolla mummo huutaa bingon (main.gd arpoo)

var _root: Control
var _info: Label
var _keys: Control
var _tip: Label
var _done := false
var _t := 0.0
var _card: Array = []  # 25 numeroa, 0 = vapaa
var _marked: Array = []  # 25 bool
var _called: Array = []
var _pool: Array = []
var _call_t := 1.5
var _false := 0
var _ball_t := 0.0  # uuden pallon animaatio
var _glare := 0.0
var _sparks: Array = []
var _mouse := Vector2.ZERO


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	_root.gui_input.connect(_gui)
	add_child(_root)
	_info = _label(24, 20.0, false)
	_tip = _label(22, -86.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_card.resize(25)
	_marked.resize(25)
	_marked.fill(false)
	for c in 5:  # sarakkeen numerot omalta väliltään
		var nums: Array = range(c * 15 + 1, c * 15 + 16)
		nums.shuffle()
		for r in 5:
			_card[r * 5 + c] = nums[r]
	_card[12] = 0
	_marked[12] = true
	_pool = range(1, 76)
	_pool.shuffle()
	_tip.text = "Erkki: \"Laput valmiina! Ensimmäinen pallo tulossa...\""


func _label(size: int, y: float, bottom: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.anchor_right = 1.0
	if bottom:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_ball_t = maxf(0.0, _ball_t - delta)
	_glare = maxf(0.0, _glare - delta)
	MG.sparks_step(_sparks, delta)
	_mouse = _root.get_local_mouse_position() + Vector2(sin(_t * 5.0), cos(_t * 4.3)) * drunk * 14.0
	_root.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_end(false)
		return
	_call_t -= delta
	if _call_t <= 0.0 and not _pool.is_empty():
		_call_t = CALL_S
		var n: int = _pool.pop_back()
		_called.append(n)
		_ball_t = 0.8
		Sfx.play("pickup", -10.0, 0.7)
		_tip.text = "Erkki: \"%s %d!\"" % [COLS[(n - 1) / 15], n]
		if _called.size() >= rival_at:
			_tip.text = "Mummo Elvi: \"BIIINGO!\" Erkki tarkistaa... oikein. Kinkku meni."
			Sfx.play("lose", -6.0)
			_done = true
			get_tree().create_timer(2.2).timeout.connect(func() -> void:
				finished.emit(false, _false)
				queue_free())
			return
	_info.text = "Bingo · huudettu %d numeroa · merkitse klikkaamalla, rivi täynnä niin BINGO!" % _called.size()
	_keys.set_text("Hiiri merkitsee   %s lopeta" % Settings.cap("mount"))


func _gui(ev: InputEvent) -> void:
	if _done or not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	if _bingo_rect().has_point(_mouse):
		if _has_line():
			Sfx.play("win", -4.0)
			MG.sparks_burst(_sparks, _bingo_rect().get_center(), Color(1.0, 0.85, 0.2), 40)
			_tip.text = "SINÄ: \"BINGO!\" Erkki tarkistaa... OIKEIN! Mummot mulkoilee."
			_end(true)
		else:
			_false += 1
			_glare = 1.5
			Sfx.play("alert", -8.0)
			_tip.text = ["Erkki: \"Ei oo bingo. Istu alas.\" Mummot mulkoilee.", "Väärä bingo! Hilkka tuhahtaa."].pick_random()
		return
	for i in 25:
		if _cell_rect(i).has_point(_mouse) and not _marked[i]:
			if _card[i] in _called:
				_marked[i] = true
				Sfx.play("pickup", -12.0, 1.4)
			else:
				_tip.text = "%d ei oo vielä tullu!" % _card[i]


## Rivi täynnä merkittyjä (merkitsemättä ei lasketa, vaikka numero olisi huudettu).
func _has_line() -> bool:
	var lines: Array = []
	for r in 5:
		lines.append(range(r * 5, r * 5 + 5))
	for c in 5:
		lines.append([c, c + 5, c + 10, c + 15, c + 20])
	lines.append([0, 6, 12, 18, 24])
	lines.append([4, 8, 12, 16, 20])
	for l in lines:
		if l.all(func(i): return _marked[i]):
			return true
	return false


func _end(won: bool) -> void:
	_done = true
	get_tree().create_timer(1.6 if won else 0.0).timeout.connect(func() -> void:
		finished.emit(won, _false)
		queue_free())


# --- Piirto -------------------------------------------------------------------

func _card_rect() -> Rect2:
	var sz := _root.size
	return Rect2(Vector2(sz.x * 0.5 - 40, sz.y * 0.16), Vector2(400, 470))


func _cell_rect(i: int) -> Rect2:
	var cr := _card_rect()
	return Rect2(cr.position + Vector2(20 + (i % 5) * 72, 90 + (i / 5) * 72), Vector2(66, 66))


func _bingo_rect() -> Rect2:
	var cr := _card_rect()
	return Rect2(Vector2(cr.end.x + 30, cr.position.y + 330), Vector2(200, 90))


func _draw_root() -> void:
	var sz := _root.size
	var font := ThemeDB.fallback_font
	# Sali: paneliseinä, pöytä ja kahvikupit.
	MG.grad_rect(_root, Rect2(Vector2.ZERO, sz), Color(0.82, 0.76, 0.62), Color(0.55, 0.48, 0.36))
	for x in range(0, int(sz.x), 56):
		_root.draw_line(Vector2(x, 0), Vector2(x, sz.y * 0.4), Color(0.7, 0.62, 0.48), 2.0)
	MG.wood(_root, Rect2(Vector2(0, sz.y * 0.4), Vector2(sz.x, sz.y * 0.6)), Color(0.55, 0.4, 0.25), 64.0, 21)
	_root.draw_rect(Rect2(Vector2(0, sz.y * 0.4), Vector2(sz.x, sz.y * 0.6)), Color(0.95, 0.93, 0.85, 0.35))  # pöytäliina
	# Erkki ja pallokone vasemmalla.
	var ek := Vector2(sz.x * 0.17, sz.y * 0.3)
	MG.person(_root, ek, 1.0, {"skin": Color(0.96, 0.75, 0.66), "hair": "parted", "hair_col": Color(0.35, 0.28, 0.22),
		"shirt": Color(0.92, 0.92, 0.88), "tie": true}, Vector2(0.5, 0.3), _ball_t > 0.3)
	var drum := ek + Vector2(110, 40)
	_root.draw_circle(drum, 62.0, Color(0.75, 0.88, 0.98, 0.6))
	_root.draw_arc(drum, 62.0, 0, TAU, 40, Color(0.4, 0.5, 0.6), 4.0)
	for k in 14:
		var a := _t * 2.5 + k * 0.9
		MG.ball(_root, drum + Vector2(cos(a) * 40.0, sin(a * 1.3) * 34.0), 9.0, [Color.RED, Color.YELLOW, Color.WHITE, Color(0.3, 0.6, 1)][k % 4], 0.6)
	_root.draw_line(drum + Vector2(0, 62), drum + Vector2(0, 110), Color(0.3, 0.3, 0.32), 8.0)
	# Viimeisin pallo isona.
	if not _called.is_empty():
		var n: int = _called.back()
		var bp := ek + Vector2(110, 170) + Vector2(0, -60.0 * _ball_t)
		MG.ball(_root, bp, 46.0, Color(0.97, 0.97, 0.95), 0.4)
		_root.draw_circle(bp, 30.0, [Color(0.2, 0.4, 0.85), Color(0.85, 0.2, 0.2), Color(0.95, 0.95, 0.95), Color(0.2, 0.65, 0.3), Color(0.95, 0.65, 0.1)][(n - 1) / 15])
		_root.draw_string(font, bp + Vector2(-30, -2), COLS[(n - 1) / 15], HORIZONTAL_ALIGNMENT_CENTER, 60, 16, Color.WHITE)
		_root.draw_string(font, bp + Vector2(-30, 18), str(n), HORIZONTAL_ALIGNMENT_CENTER, 60, 26, Color.WHITE)
	# Huudetut numerot taululla.
	var hb := Rect2(Vector2(sz.x * 0.05, sz.y * 0.62), Vector2(sz.x * 0.36, 190))
	MG.sign(_root, hb, "", Color(0.08, 0.1, 0.08), Color.WHITE, 18, Color(0.55, 0.4, 0.2))
	_root.draw_string(font, hb.position + Vector2(14, 28), "HUUDETUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.85, 0.3))
	var sorted := _called.duplicate()
	sorted.sort()
	for k in sorted.size():
		var p := hb.position + Vector2(18 + (k % 10) * (hb.size.x - 30) / 10.0, 56 + (k / 10) * 30)
		_root.draw_string(font, p, str(sorted[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.95, 0.9))
	# Oma bingolappu.
	var cr := _card_rect()
	MG.box(_root, cr, Color(0.98, 0.96, 0.88), 10, 10, Color(0.2, 0.35, 0.6), 4)
	for c in 5:
		var hr := Rect2(cr.position + Vector2(20 + c * 72, 22), Vector2(66, 56))
		MG.box(_root, hr, [Color(0.2, 0.4, 0.85), Color(0.85, 0.2, 0.2), Color(0.45, 0.45, 0.5), Color(0.2, 0.65, 0.3), Color(0.95, 0.65, 0.1)][c], 6)
		_root.draw_string(font, hr.position + Vector2(0, 42), COLS[c], HORIZONTAL_ALIGNMENT_CENTER, hr.size.x, 36, Color.WHITE)
	for i in 25:
		var r := _cell_rect(i)
		var hover: bool = r.has_point(_mouse) and not _marked[i]
		MG.box(_root, r, Color(1, 1, 0.85) if hover else Color(1, 1, 1), 6, 0, Color(0.6, 0.6, 0.65), 2)
		if _card[i] == 0:
			_root.draw_string(font, r.position + Vector2(0, 40), "★", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Color(0.9, 0.7, 0.1))
		else:
			_root.draw_string(font, r.position + Vector2(0, 44), str(_card[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Color(0.15, 0.15, 0.2))
		if _marked[i] and _card[i] != 0:  # tussimerkki
			_root.draw_circle(r.get_center(), 26.0, Color(0.85, 0.1, 0.45, 0.45))
			_root.draw_arc(r.get_center(), 26.0, 0, TAU, 24, Color(0.75, 0.05, 0.35, 0.8), 3.0)
	# BINGO-nappi: syttyy, kun rivi on täynnä.
	var br := _bingo_rect()
	var ready := _has_line()
	var pulse := (0.5 + 0.5 * sin(_t * 8.0)) if ready else 0.0
	MG.box(_root, br.grow(pulse * 6.0), Color(0.9, 0.15, 0.1) if ready else Color(0.5, 0.35, 0.3), 16, 8, Color(1.0, 0.85, 0.2), 4)
	_root.draw_string(font, br.position + Vector2(0, 60), "BINGO!", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 44, Color(1, 1, 0.9))
	# Mummot mulkoilevat väärästä huudosta.
	if _glare > 0.0:
		for k in 2:
			var mp := Vector2(sz.x * (0.82 + k * 0.1), sz.y * 0.3)
			MG.person(_root, mp, 0.8, {"skin": Color(0.95, 0.8, 0.74), "hair": "buns", "hair_col": Color(0.9, 0.9, 0.9),
				"shirt": [Color(0.45, 0.4, 0.6), Color(0.55, 0.3, 0.45)][k], "glasses": true}, Vector2(-1, 0.2), true)
			_root.draw_line(mp + Vector2(-20, -20), mp + Vector2(-4, -14), Color(0.2, 0.1, 0.05), 4.0)
			_root.draw_line(mp + Vector2(20, -20), mp + Vector2(4, -14), Color(0.2, 0.1, 0.05), 4.0)
	MG.sparks_draw(_root, _sparks)
