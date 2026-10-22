extends CanvasLayer
## Muistokyltti Pörrölle (#148): jalkapallopoikien pikkuveljen hamsterin muistolaudan maalaus Lemmikki Enkelien pihalla.
## Rauhallinen pieni minipeli ilman aikapainetta: laudanpalaan kirjoitetaan hamsterin nimi kirjain kerrallaan oikeaa
## näppäintä painamalla (Ö = Ö, ; tai O), jokainen kirjain maalataan siveltimellä näkyviin. Väärä näppäin vain
## huojauttaa sivellintä. Lopuksi maalataan sydän ja käpälä, ja lauta naulataan tolppaan (poikien silmät kostuvat).
## Pojat katsovat vieressä. Esc / F lopettaa kesken (lopettaa myös tehtävän vain väliaikaisesti). finished(valmis).

signal finished(done: bool)

const MG := preload("res://scripts/mg_draw.gd")
const W := 1280.0
const H := 720.0
const NAME := "PÖRRÖ"
const INK := Color(0.1, 0.08, 0.06)
const PAINTS := [Color(0.96, 0.9, 0.78), Color(0.95, 0.75, 0.3), Color(0.85, 0.5, 0.45), Color(0.55, 0.75, 0.9)]
const BOYS := [
	{"skin": Color(0.96, 0.78, 0.68), "hair_col": Color(0.4, 0.28, 0.15), "shirt": Color(0.3, 0.55, 0.7)},
	{"skin": Color(0.95, 0.76, 0.66), "hair_col": Color(0.2, 0.15, 0.1), "shirt": Color(0.8, 0.35, 0.3)},
	{"skin": Color(0.96, 0.8, 0.7), "hair_col": Color(0.75, 0.6, 0.3), "shirt": Color(0.35, 0.6, 0.4)},
]
const LINES := ["Pörrö tykkäsi auringosta.", "Se söi aina vähän liikaa.", "Pikkuveli piirsi tuon käpälän.", "Kiitti, setä.",
	"Tää on kaunis.", "Pörrö olis tykänny."]

var _root: Control
var _keys: Control
var _t := 0.0
var _typed := 0  # maalattuja kirjaimia
var _stage := "letters"  # letters | heart | nail | done
var _brush := Vector2.ZERO  # sivellin
var _brush_to := Vector2.ZERO
var _stroke_t := 0.0  # nykyisen kirjaimen maalaus 0..1
var _wobble := 0.0
var _strokes: Array = []  # valmiit viivat: [pisteet, väri, paksuus]
var _cur: Array = []  # kirjaimen viivat, joita maalataan
var _sparks: Array = []
var _say := ""
var _say_t := 0.0
var _nail := 0
var _done_t := 0.0
var _finished := false
var _quit := false


func _ready() -> void:
	add_to_group("esc_lopettaa")
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	add_child(_root)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_brush = _plank().get_center() + Vector2(300, 220)
	_brush_to = _brush
	_next_letter()
	_speak("Hiljaa. Maalataan Pörrön nimi.")


func _plank() -> Rect2:
	return Rect2(300, 160, 680, 250)


func _letter_rect(i: int) -> Rect2:
	var pl := _plank()
	var w := 112.0
	var x0 := pl.position.x + (pl.size.x - NAME.length() * w) / 2.0
	return Rect2(x0 + i * w, pl.position.y + 40, w - 8, 170)


## Kirjaimen viivat (pisteitä laatikossa 0..1): yksinkertaistettu käsin maalattu fontti.
static func _glyph(ch: String) -> Array:
	match ch:
		"P":
			return [[Vector2(0.15, 1), Vector2(0.15, 0)], [Vector2(0.15, 0), Vector2(0.7, 0.04), Vector2(0.8, 0.22), Vector2(0.7, 0.42), Vector2(0.15, 0.48)]]
		"Ö":
			return [[Vector2(0.2, 0.2), Vector2(0.2, 1), Vector2(0.8, 1), Vector2(0.8, 0.2), Vector2(0.5, 0.12), Vector2(0.2, 0.2)],
				[Vector2(0.32, 0.0), Vector2(0.34, 0.04)], [Vector2(0.66, 0.0), Vector2(0.68, 0.04)]]
		"R":
			return [[Vector2(0.15, 1), Vector2(0.15, 0)], [Vector2(0.15, 0), Vector2(0.7, 0.04), Vector2(0.8, 0.22), Vector2(0.7, 0.42), Vector2(0.15, 0.48)],
				[Vector2(0.4, 0.48), Vector2(0.82, 1)]]
	return []


func _next_letter() -> void:
	if _typed >= NAME.length():
		_stage = "heart"
		_stroke_t = 0.0
		_cur = [_heart(), _paw()]
		_speak("Vielä sydän ja käpälä.")
		return
	var r := _letter_rect(_typed)
	_cur = []
	for line in _glyph(NAME[_typed]):
		var pts := PackedVector2Array()
		for q in line:
			pts.append(r.position + Vector2(q.x * r.size.x, q.y * r.size.y))
		_cur.append(pts)
	_stroke_t = 0.0


func _heart() -> PackedVector2Array:
	var c := Vector2(_plank().end.x - 80, _plank().position.y + 205)
	var pts := PackedVector2Array()
	for i in 29:
		var a := float(i) / 28.0 * TAU
		pts.append(c + Vector2(16.0 * pow(sin(a), 3.0), -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))) * 1.3)
	return pts


func _paw() -> PackedVector2Array:
	var c := Vector2(_plank().position.x + 85, _plank().position.y + 205)
	var pts := PackedVector2Array()
	for i in 17:  # tassu: pääpyyhkäisy ympyränä
		var a := float(i) / 16.0 * TAU
		pts.append(c + Vector2(cos(a), sin(a)) * 16.0)
	return pts


func _speak(t: String) -> void:
	_say = t
	_say_t = 3.4


func _press(ch: String) -> void:
	if _stage != "letters" or _stroke_t < 1.0 and _stroke_t > 0.0:
		return
	if ch == NAME[_typed]:
		_stroke_t = 0.001
		Sfx.play("pickup", -10.0, 0.9 + randf() * 0.2)
	else:
		_wobble = 0.5
		Sfx.play("cloth", -12.0, 0.8)
		if randf() < 0.5:
			_speak(LINES.pick_random())


func _input(ev: InputEvent) -> void:
	if _finished:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ESCAPE or ev.keycode == KEY_F:
			_quit = true
			_end(false)
		elif _stage == "done" and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_E):
			_end(true)
		elif _stage == "letters":
			var ch := ""
			match ev.keycode:
				KEY_P: ch = "P"
				KEY_R: ch = "R"
				KEY_ODIAERESIS, KEY_SEMICOLON, KEY_O: ch = "Ö"
				_: ch = "?"
			_press(ch)
		elif _stage == "nail" and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_E):
			_hammer()
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _stage == "nail":
			_hammer()
		elif _stage == "done":
			_end(true)


func _hammer() -> void:
	_nail += 1
	Sfx.play("rattle_hard", -6.0, 1.4)
	MG.sparks_burst(_sparks, Vector2(_plank().position.x + 40, _plank().get_center().y), Color(0.9, 0.85, 0.6), 8)
	if _nail >= 4:
		_stage = "done"
		_done_t = 0.0
		Sfx.play("win_small", -6.0)
		_speak("Kiitos, setä. Pörrö on nyt kotona.")


func _end(done: bool) -> void:
	if _finished:
		return
	_finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finished.emit(done)
	queue_free()


func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	_wobble = maxf(0.0, _wobble - delta)
	_say_t = maxf(0.0, _say_t - delta)
	MG.sparks_step(_sparks, delta)
	if _stage in ["letters", "heart"] and _stroke_t > 0.0 and _stroke_t < 1.0:
		_stroke_t = minf(1.0, _stroke_t + delta * (0.9 if _stage == "letters" else 0.5))
		var pos := _cur_point(_stroke_t)
		_brush_to = pos
		if randf() < 0.5:
			MG.sparks_burst(_sparks, pos, PAINTS[(_typed + 1) % PAINTS.size()], 1)
		if _stroke_t >= 1.0:
			for line in _cur:
				_strokes.append([line, PAINTS[(_typed + 1) % PAINTS.size()] if _stage == "letters" else PAINTS[2], 11.0 if _stage == "letters" else 6.0])
			if _stage == "letters":
				_typed += 1
				_stroke_t = 0.0
				_next_letter()
				if _typed < NAME.length():
					_speak(LINES.pick_random() if randf() < 0.3 else "")
			else:
				_stage = "nail"
				_cur = []
				_speak("Nyt lauta tolppaan: paina välilyöntiä.")
	elif _stage == "heart" and _stroke_t <= 0.0:
		_stroke_t = 0.001
	_brush = _brush.lerp(_brush_to, 1.0 - exp(-10.0 * delta))
	if _stage == "done":
		_done_t += delta
	_update_keys()
	_root.queue_redraw()


func _cur_point(t: float) -> Vector2:
	if _cur.is_empty():
		return _brush
	var total := 0.0
	for line in _cur:
		total += _len(line)
	var d := t * total
	for line in _cur:
		var l := _len(line)
		if d <= l:
			return _along(line, d)
		d -= l
	return _along(_cur[-1], _len(_cur[-1]))


static func _len(line: PackedVector2Array) -> float:
	var l := 0.0
	for i in line.size() - 1:
		l += line[i].distance_to(line[i + 1])
	return l


static func _along(line: PackedVector2Array, d: float) -> Vector2:
	for i in line.size() - 1:
		var seg := line[i].distance_to(line[i + 1])
		if d <= seg:
			return line[i].lerp(line[i + 1], d / maxf(seg, 0.001))
		d -= seg
	return line[-1]


func _update_keys() -> void:
	match _stage:
		"letters":
			_keys.set_text("Paina kirjainta: [%s]   [Esc] Lopeta" % NAME[mini(_typed, NAME.length() - 1)].replace("Ö", "Ö / ;"))
		"nail":
			_keys.set_text("[Väli] Naulaa lauta tolppaan   [Esc] Lopeta")
		"done":
			_keys.set_text("[Väli] Valmis")
		_:
			_keys.set_text("[Esc] Lopeta")


func _draw_root() -> void:
	var sz := _root.size
	var s := minf(sz.x / W, sz.y / H)
	var o := (sz - Vector2(W, H) * s) / 2.0
	var ci := _root
	ci.draw_set_transform(o, 0.0, Vector2(s, s))
	_draw_yard(ci)
	_draw_boys(ci)
	_draw_post_and_plank(ci)
	MG.sparks_draw(ci, _sparks)
	_draw_brush(ci)
	if _say != "" and _say_t > 0.0:
		MG.bubble(ci, Rect2(400, 40, 480, 70), Vector2(560, 215), _say, 22)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_yard(ci: CanvasItem) -> void:
	# Illan lämmin taivas, tuhkaamon seinä ja valkoinen aita, nurmi ja kynttilälyhdyt.
	MG.grad_rect(ci, Rect2(-600, -300, 2480, 760), Color(0.98, 0.84, 0.66), Color(0.99, 0.93, 0.8))
	ci.draw_circle(Vector2(1010, 160), 90.0, Color(1.0, 0.93, 0.7, 0.35))
	MG.glow(ci, Vector2(1010, 160), 160.0, Color(1.0, 0.9, 0.6, 0.35))
	MG.box(ci, Rect2(-100, 130, 520, 270), Color(0.93, 0.9, 0.84), 2, 4, MG.OUTLINE, 2)  # rakennus vasemmalla
	for wx in [60, 220]:
		MG.box(ci, Rect2(wx, 200, 90, 110), Color(0.55, 0.7, 0.8), 4, 2, MG.OUTLINE, 2)
		ci.draw_line(Vector2(wx + 45, 200), Vector2(wx + 45, 310), Color(0.95, 0.95, 0.9), 4.0)
	MG.sign(ci, Rect2(60, 140, 300, 44), "LEMMIKKI ENKELIT", Color(0.95, 0.85, 0.85), Color(0.35, 0.18, 0.25), 24, Color(0.35, 0.18, 0.25))
	ci.draw_rect(Rect2(380, 60, 38, 120), Color(0.9, 0.88, 0.84))  # piippu
	ci.draw_rect(Rect2(380, 60, 38, 8), MG.OUTLINE)
	MG.grad_rect(ci, Rect2(-600, 400, 2480, 400), Color(0.42, 0.6, 0.3), Color(0.3, 0.46, 0.22))
	for i in 28:  # nurmen kuviot
		var x := fmod(float(i) * 97.0, 1400.0) - 60.0
		var y := 430.0 + fmod(float(i) * 53.0, 230.0)
		ci.draw_line(Vector2(x, y), Vector2(x + 6, y - 12), Color(0.5, 0.7, 0.35), 2.0)
	for k in 8:  # aita
		var fx := 440.0 + k * 100.0
		ci.draw_rect(Rect2(fx, 360, 14, 70), Color(0.95, 0.94, 0.9))
		ci.draw_rect(Rect2(fx, 360, 14, 70), MG.OUTLINE, false, 1.5)
	ci.draw_rect(Rect2(430, 380, 800, 10), Color(0.95, 0.94, 0.9))
	ci.draw_rect(Rect2(430, 406, 800, 10), Color(0.95, 0.94, 0.9))
	for lx in [200.0, 330.0, 1130.0, 1220.0]:  # kynttilälyhdyt
		ci.draw_rect(Rect2(lx - 14, 520, 28, 36), Color(0.2, 0.15, 0.12))
		ci.draw_rect(Rect2(lx - 10, 524, 20, 28), Color(1.0, 0.82, 0.4, 0.75 + sin(_t * 5.0 + lx) * 0.1))
		MG.glow(ci, Vector2(lx, 538), 50.0, Color(1.0, 0.8, 0.4, 0.35))


func _draw_boys(ci: CanvasItem) -> void:
	for i in 3:
		var c := Vector2(150 + i * 120, 520)
		var look: Dictionary = (BOYS[i] as Dictionary).duplicate()
		MG.person(ci, c, 0.9, look, Vector2(0.9, 0.3), false)


func _draw_post_and_plank(ci: CanvasItem) -> void:
	var pl := _plank()
	# Tolppa ja varjo.
	ci.draw_rect(Rect2(pl.get_center().x - 26, pl.end.y, 52, 200), Color(0.45, 0.3, 0.17))
	ci.draw_rect(Rect2(pl.get_center().x - 26, pl.end.y, 52, 200), MG.OUTLINE, false, 2.0)
	MG.box(ci, Rect2(pl.position + Vector2(8, 10), pl.size), Color(0, 0, 0, 0.25), 8)
	MG.wood(ci, pl, Color(0.8, 0.62, 0.42), 62.0, 11, true)
	ci.draw_rect(pl, MG.OUTLINE, false, 3.0)
	# Vaaleanpunainen pohjamaali nimen alle (esimaalaus).
	ci.draw_rect(Rect2(pl.position + Vector2(14, 14), pl.size - Vector2(28, 28)), Color(0.92, 0.85, 0.74, 0.55))
	if _stage == "nail" or _stage == "done":
		for k in range(_nail):
			var nx := pl.position.x + 24 + (0 if k % 2 == 0 else pl.size.x - 48)
			var ny := pl.position.y + 24 + (0 if k < 2 else pl.size.y - 48)
			ci.draw_circle(Vector2(nx, ny), 7.0, Color(0.55, 0.55, 0.58))
			ci.draw_arc(Vector2(nx, ny), 7.0, 0, TAU, 10, MG.OUTLINE, 1.5)
	# Ohjaussiluetti: seuraavan kirjaimen haamu.
	if _stage == "letters" and _typed < NAME.length() and _stroke_t <= 0.0:
		for line in _glyph(NAME[_typed]):
			var pts := PackedVector2Array()
			var r := _letter_rect(_typed)
			for q in line:
				pts.append(r.position + Vector2(q.x * r.size.x, q.y * r.size.y))
			ci.draw_polyline(pts, Color(1, 1, 1, 0.45 + sin(_t * 4.0) * 0.15), 5.0, true)
	# Maalatut viivat (tummennettu reuna ja vaalea kiilto).
	for st in _strokes:
		ci.draw_polyline(st[0], (st[1] as Color).darkened(0.45), st[2] + 3.0, true)
		ci.draw_polyline(st[0], st[1], st[2], true)
	# Kesken oleva viiva.
	if _stroke_t > 0.0 and _stroke_t < 1.0:
		var col: Color = PAINTS[(_typed + 1) % PAINTS.size()] if _stage == "letters" else PAINTS[2]
		var wid := 11.0 if _stage == "letters" else 6.0
		var total := 0.0
		for line in _cur:
			total += _len(line)
		var d := _stroke_t * total
		for line in _cur:
			var l := _len(line)
			var part := PackedVector2Array([line[0]])
			var acc := 0.0
			for i in line.size() - 1:
				var seg := line[i].distance_to(line[i + 1])
				if d - acc >= seg:
					part.append(line[i + 1])
					acc += seg
				else:
					part.append(line[i].lerp(line[i + 1], clampf((d - acc) / maxf(seg, 0.001), 0.0, 1.0)))
					break
			if d > 0.0 and part.size() > 1:
				ci.draw_polyline(part, col.darkened(0.45), wid + 3.0, true)
				ci.draw_polyline(part, col, wid, true)
			d = maxf(0.0, d - l)
	if _stage == "done":
		var a := clampf(_done_t * 1.5, 0.0, 1.0)
		MG.glow(ci, pl.get_center(), 240.0, Color(1.0, 0.95, 0.7, 0.3 * a))


func _draw_brush(ci: CanvasItem) -> void:
	if _stage == "done":
		return
	var b := _brush + Vector2(sin(_t * 40.0) * _wobble * 14.0, 0)
	ci.draw_line(b, b + Vector2(120, -90), Color(0.65, 0.45, 0.25), 9.0)  # varsi
	ci.draw_line(b, b + Vector2(120, -90), MG.OUTLINE, 2.0)
	ci.draw_line(b, b + Vector2(16, -12), Color(0.8, 0.8, 0.85), 11.0)  # metallinen holkki
	ci.draw_circle(b, 8.0, PAINTS[(_typed + 1) % PAINTS.size()])
	ci.draw_arc(b, 8.0, 0, TAU, 12, MG.OUTLINE, 1.5)
