extends CanvasLayer
## Karhukätkö (#250 P12): hämärä niitty kätkön ikkunasta. Odota, että karhu tulee metsästä, tähtää etsimellä (hiiri) ja ota kuva (klikkaus/Väli).
## Kuvassa karhu keskellä ja isona + pystyssä (katsoo kameraan) = paljon pisteitä. Humala (drunk 0..1) heiluttaa etsintä; filmiä kuusi ruutua.
## finished(best: int, shots: int): paras kuva (0-100), otetut ruudut. Esc lopettaa kesken.

signal finished(best: int, shots: int)

const MG := preload("res://scripts/mg_draw.gd")
const W := 1280.0
const H := 720.0
const INK := Color(0.1, 0.08, 0.06)
const FRAME := Vector2(240, 170)  # etsimen kehys
const FILM := 6
const HORIZON := 360.0

var drunk := 0.0
var _t := 0.0
var _bears: Array = []  # {x, y, vx, size, stand, ttl, seen}
var _next_bear := 2.5
var _shots := 0
var _best := 0
var _last := -1
var _flash := 0.0
var _msg := ""
var _msg_t := 0.0
var _sparks: Array = []
var _snaps: Array = []  # otetut kuvat: [pisteet]
var _aim := Vector2(W / 2.0, H / 2.0)
var _mouse := Vector2(W / 2.0, H / 2.0)
var _finished := false
var _over := false
var _root: Control
var _keys: Control


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
	_say("Odota hiljaa. Karhu tulee kun tulee.", 3.0)


func _input(ev: InputEvent) -> void:
	if _finished:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ESCAPE or ev.keycode == KEY_F:
			_end()
		elif ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_E:
			if _over:
				_end()
			else:
				_shoot()
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		_mouse = _root.get_local_mouse_position()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = _root.get_local_mouse_position()
		if _over:
			_end()
		else:
			_shoot()


func _end() -> void:
	if _finished:
		return
	_finished = true
	finished.emit(_best, _shots)
	queue_free()


func _say(t: String, d := 1.8) -> void:
	_msg = t
	_msg_t = d


func _process(delta: float) -> void:
	if _finished:
		return
	delta = minf(delta, 0.05)
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	_msg_t = maxf(0.0, _msg_t - delta)
	MG.sparks_step(_sparks, delta)
	# Etsin: hiiri + käden tärinä (aina vähän, humalassa paljon).
	var amp := 5.0 + drunk * 46.0
	var sway := Vector2(sin(_t * 2.3) + 0.6 * sin(_t * 5.1 + 1.0), cos(_t * 1.9 + 0.5) + 0.6 * sin(_t * 4.3)) * amp
	_aim = _aim.lerp(_mouse + sway, minf(1.0, delta * 12.0))
	_next_bear -= delta
	if _next_bear <= 0.0 and _bears.size() < 2 and not _over:
		_spawn()
		_next_bear = randf_range(4.0, 8.0)
	for b in _bears:
		b.ttl -= delta
		b.stand = maxf(0.0, b.stand - delta)
		if b.stand <= 0.0 and randf() < delta * 0.25:
			b.stand = 1.6  # nousee takajaloilleen haistelemaan
		var sp := 0.0 if b.stand > 0.0 else 1.0
		b.x += b.vx * delta * sp
		b.y = HORIZON + 30.0 + b.size * 70.0 + sin(_t * 0.7 + b.x * 0.01) * 6.0
	_bears = _bears.filter(func(b: Dictionary) -> bool: return b.ttl > 0.0 and b.x > -200.0 and b.x < W + 200.0)
	if not _over and _shots >= FILM:
		_over = true
		_say("Filmi loppu. Paras kuva %d / 100." % _best, 99.0)
	_keys.set_text("[Väli] tai [Klikkaus] Ota kuva (%d/%d ruutua)   [Esc] Lopeta" % [_shots, FILM] if not _over else "[Väli] Valmis")
	_root.queue_redraw()


func _spawn() -> void:
	var dir := 1.0 if randf() < 0.5 else -1.0
	var size := randf_range(0.5, 1.0)
	_bears.append({"x": -120.0 if dir > 0.0 else W + 120.0, "y": HORIZON + 80.0, "vx": dir * randf_range(35.0, 60.0),
		"size": size, "stand": 0.0, "ttl": 22.0})
	Sfx.play("alert", -14.0, 0.6)


func _shoot() -> void:
	if _shots >= FILM:
		return
	_shots += 1
	_flash = 1.0
	Sfx.play("door_close", -6.0, 1.6)
	var rect := Rect2(_aim - FRAME / 2.0, FRAME)
	var score := 0
	for b in _bears:
		var c := Vector2(b.x, b.y - 55.0 * (0.6 + b.size * 0.8))
		if rect.has_point(c):
			var off: float = (c - _aim).length() / (FRAME.length() * 0.5)
			var s := int(50.0 * (1.0 - off) + 30.0 * b.size + (20.0 if b.stand > 0.0 else 0.0))
			score = maxi(score, clampi(s, 1, 100))
	_last = score
	_best = maxi(_best, score)
	if score == 0:
		_say("Pelkkää niittyä.", 1.5)
	elif score < 60:
		_say("Karhu näkyy, mutta kuva ei ole hyvä (%d)." % score, 1.8)
	else:
		_say("Upea kuva! (%d)" % score, 2.0)
		MG.sparks_burst(_sparks, _aim, Color(1.0, 0.9, 0.4), 22)
		Sfx.play("win_small", -6.0)


# --- Piirto -------------------------------------------------------------------------------

func _draw_bear(b: Dictionary) -> void:
	var s: float = 0.6 + b.size * 0.8
	var c := Vector2(b.x, b.y)
	var dir := signf(b.vx)
	var fur := Color(0.27, 0.2, 0.15)
	var dark := Color(0.16, 0.12, 0.09)
	_root.draw_circle(c + Vector2(0, 4) * s, 62.0 * s, Color(0, 0, 0, 0.22))  # varjo
	if b.stand > 0.0:  # pystyssä: pitkä vartalo ja pää edessä
		_root.draw_circle(c + Vector2(0, -48) * s, 40.0 * s, fur)
		_root.draw_circle(c + Vector2(0, -100) * s, 24.0 * s, fur.lightened(0.05))
		for sx in [-1.0, 1.0]:
			_root.draw_circle(c + Vector2(sx * 17, -118) * s, 8.0 * s, dark)
			_root.draw_line(c + Vector2(sx * 34, -66) * s, c + Vector2(sx * 40, -22) * s, fur, 14.0 * s)
			_root.draw_circle(c + Vector2(sx * 9, -104) * s, 2.8 * s, Color.WHITE)
			_root.draw_circle(c + Vector2(sx * 9, -104) * s, 1.4 * s, INK)
		_root.draw_circle(c + Vector2(0, -92) * s, 8.0 * s, Color(0.55, 0.42, 0.32))
		_root.draw_circle(c + Vector2(0, -95) * s, 3.2 * s, INK)
	else:
		_root.draw_circle(c + Vector2(-8 * dir, -34) * s, 40.0 * s, fur)  # ruumis
		_root.draw_circle(c + Vector2(-22 * dir, -50) * s, 30.0 * s, fur.lightened(0.04))  # lapa
		_root.draw_circle(c + Vector2(34 * dir, -36) * s, 22.0 * s, fur.lightened(0.05))  # pää
		_root.draw_circle(c + Vector2(30 * dir, -56) * s, 7.0 * s, dark)  # korva
		_root.draw_circle(c + Vector2(50 * dir, -30) * s, 9.0 * s, Color(0.55, 0.42, 0.32))  # kuono
		_root.draw_circle(c + Vector2(57 * dir, -32) * s, 3.0 * s, INK)
		_root.draw_circle(c + Vector2(40 * dir, -42) * s, 2.4 * s, INK)
		var step := sin(_t * 4.0 + b.x * 0.05) * 8.0
		for k in 2:
			var lx := (-30.0 + k * 52.0) * dir
			_root.draw_line(c + Vector2(lx, -12) * s, c + Vector2(lx + step * (1.0 - 2.0 * k), 0) * s, dark, 15.0 * s)


func _draw_root() -> void:
	# Taivas (hämärä), kaukametsä ja niitty.
	MG.grad_rect(_root, Rect2(0, 0, W, HORIZON), Color(0.95, 0.62, 0.4), Color(0.28, 0.3, 0.5))
	_root.draw_circle(Vector2(950, 250), 38.0, Color(1.0, 0.85, 0.55, 0.9))  # laskeva aurinko
	for i in 22:
		var tx := i * 62.0 - 20.0
		var th := 90.0 + (i * 37 % 60)
		_root.draw_colored_polygon(PackedVector2Array([Vector2(tx, HORIZON + 4), Vector2(tx + 30, HORIZON - th), Vector2(tx + 60, HORIZON + 4)]), Color(0.1, 0.17, 0.15))
	MG.grad_rect(_root, Rect2(0, HORIZON, W, H - HORIZON), Color(0.33, 0.4, 0.22), Color(0.14, 0.2, 0.12))
	_root.draw_rect(Rect2(150, HORIZON + 20, 260, 18), Color(0.35, 0.5, 0.6, 0.7))  # lampi
	for b in _bears:
		_draw_bear(b)
	# Kätkön ikkunan kehys: tumma puu ja rako.
	MG.wood(_root, Rect2(0, 0, W, 70), Color(0.3, 0.2, 0.12), 60.0, 3, true)
	MG.wood(_root, Rect2(0, H - 90, W, 90), Color(0.3, 0.2, 0.12), 60.0, 5, true)
	MG.wood(_root, Rect2(0, 0, 70, H), Color(0.26, 0.17, 0.1), 60.0, 7, false)
	MG.wood(_root, Rect2(W - 70, 0, 70, H), Color(0.26, 0.17, 0.1), 60.0, 9, false)
	# Etsin.
	var r := Rect2(_aim - FRAME / 2.0, FRAME)
	var col := Color(1, 1, 1, 0.9)
	for cx in [r.position.x, r.end.x]:
		for cy in [r.position.y, r.end.y]:
			var dx := 26.0 if cx == r.position.x else -26.0
			var dy := 26.0 if cy == r.position.y else -26.0
			_root.draw_line(Vector2(cx, cy), Vector2(cx + dx, cy), col, 3.0)
			_root.draw_line(Vector2(cx, cy), Vector2(cx, cy + dy), col, 3.0)
	_root.draw_line(_aim + Vector2(-10, 0), _aim + Vector2(10, 0), col, 2.0)
	_root.draw_line(_aim + Vector2(0, -10), _aim + Vector2(0, 10), col, 2.0)
	# Filmiruudut ja tilaviesti.
	for i in FILM:
		var fr := Rect2(100 + i * 34, H - 74, 26, 34)
		MG.box(_root, fr, Color(0.9, 0.85, 0.7) if i >= _shots else Color(0.2, 0.18, 0.16), 3, 0, INK, 2)
	MG.sign(_root, Rect2(W - 330, H - 78, 230, 46), "PARAS %d" % _best, Color(0.14, 0.12, 0.1), Color(1.0, 0.9, 0.5), 28, Color(0.8, 0.7, 0.4))
	if _msg_t > 0.0 or _over:
		MG.sign(_root, Rect2(W / 2.0 - 280, 90, 560, 56), _msg, Color(0.14, 0.12, 0.1, 0.92), Color.WHITE, 26, Color(0.8, 0.7, 0.4))
	MG.sparks_draw(_root, _sparks)
	if _flash > 0.0:
		_root.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, _flash * 0.8))
