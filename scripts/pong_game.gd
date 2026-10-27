extends CanvasLayer
## Tietokonemuseon Pong (#250 P10): museon pelikone, beige CRT-televisio pöydällä. Pelaaja vasemmalla (W/S, nuolet tai hiiri), kone oikealla.
## Ensin viiteen pisteeseen voittaa (WIN_AT). Pallo kiihtyy jokaisesta mailaosumasta ja kimpoaa mailan osumakohdan mukaan.
## Esc lopettaa kesken (finished(false, ...)). Ottelun jälkeen Väli/E/klikkaus sulkee: finished(won, my, ai).
## Grafiikka: museon seinä ja pöytä, beige muovikotelo, kaareva ruutu, pyyhkäisyviivat ja hehku (pingis_game.gd:n sävyt: lämmin, tummat ääriviivat).

signal finished(won: bool, my_score: int, ai_score: int)

const MG := preload("res://scripts/mg_draw.gd")
const W := 1280.0
const H := 720.0
const INK := Color(0.1, 0.08, 0.06)
const PHOSPHOR := Color(0.82, 1.0, 0.88)
const CASE := Color(0.82, 0.74, 0.58)
const SCREEN := Rect2(330, 92, 620, 400)  # pelialue (ruudun sisäpinta)
const PADDLE := Vector2(12, 76)
const BALL := 12.0
const WIN_AT := 5
const PADDLE_SPEED := 470.0
const AI_SPEED := 300.0
const SPEED0 := 360.0
const SPEED_STEP := 24.0
const SPEED_MAX := 760.0
const DIGITS := {  # seitsemän segmentin numerot: a ylä, b oikea ylä, c oikea ala, d ala, e vasen ala, f vasen ylä, g keski
	0: "abcdef", 1: "bc", 2: "abdeg", 3: "abcdg", 4: "bcfg", 5: "acdfg", 6: "acdefg",
}

var _phase := "intro"  # intro | serve | play | point | over
var _t := 0.0
var _score := [0, 0]  # [pelaaja, kone]
var _py := SCREEN.get_center().y  # pelaajan mailan keskikohta
var _ay := SCREEN.get_center().y
var _ball := Vector2.ZERO
var _vel := Vector2.ZERO
var _speed := SPEED0
var _rally := 0
var _trail: Array = []
var _sparks: Array = []
var _shake := 0.0
var _flash := 0.0  # ruudun välähdys pisteestä
var _msg := ""
var _msg_t := 0.0
var _ai_err := 0.0  # koneen tähtäysvirhe (px), arvotaan jokaiselle pallolle
var _serve_dir := 1.0
var _mouse_y := -1.0
var _finished := false
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
	_say("Ensin viiteen pisteeseen voittaa", 2.4)
	Sfx.play("alert", -8.0, 1.4)


func _input(ev: InputEvent) -> void:
	if _finished:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ESCAPE or ev.keycode == KEY_F:
			_end(false)
		elif _phase == "over" and _t > 0.6 and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_E):
			_end(_score[0] > _score[1])
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		_mouse_y = _root.get_local_mouse_position().y
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _phase == "over" and _t > 0.6:
		_end(_score[0] > _score[1])


func _end(won: bool) -> void:
	if _finished:
		return
	_finished = true
	finished.emit(won, _score[0], _score[1])
	queue_free()


func _say(t: String, d := 1.6) -> void:
	_msg = t
	_msg_t = d


# --- Kulku ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _finished:
		return
	delta = minf(delta, 0.05)  # ruudunpäivityksen notkahdus ei saa vieä palloa mailan läpi
	_t += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	_flash = maxf(0.0, _flash - delta * 2.5)
	_msg_t = maxf(0.0, _msg_t - delta)
	MG.sparks_step(_sparks, delta)
	_move_player(delta)
	match _phase:
		"intro":
			if _t > 1.4:
				_serve()
		"serve":
			_move_ai(delta, SCREEN.get_center().y)
			if _t > 0.9:
				_phase = "play"
				_t = 0.0
		"play":
			_step_ball(delta)
		"point":
			_move_ai(delta, SCREEN.get_center().y)
			if _t > 1.2:
				if _score.max() >= WIN_AT:
					_phase = "over"
					_t = 0.0
					Sfx.play("win_small" if _score[0] > _score[1] else "lose", -4.0)
				else:
					_serve()
		"over":
			pass
	if _phase == "over":
		_keys.set_text("[Väli] Valmis")
	else:
		_keys.set_text("[W/S] tai [Hiiri] Liikuta mailaa (ensin %d pisteeseen)   [Esc] Lopeta" % WIN_AT)
	_root.queue_redraw()


func _serve() -> void:
	_phase = "serve"
	_t = 0.0
	_ball = SCREEN.get_center()
	_speed = SPEED0
	_rally = 0
	_trail.clear()
	var a := randf_range(-0.45, 0.45)
	_vel = Vector2(cos(a) * _serve_dir, sin(a)) * _speed
	_ai_err = randf_range(-34.0, 34.0)
	_say("%d - %d" % [_score[0], _score[1]], 0.8)


func _move_player(delta: float) -> void:
	var dir := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir += 1.0
	if dir != 0.0:
		_py += dir * PADDLE_SPEED * delta
		_mouse_y = -1.0
	elif _mouse_y >= 0.0:
		_py = move_toward(_py, _mouse_y, PADDLE_SPEED * 1.4 * delta)
	_py = clampf(_py, SCREEN.position.y + PADDLE.y / 2.0, SCREEN.end.y - PADDLE.y / 2.0)


func _move_ai(delta: float, target: float) -> void:
	_ay = move_toward(_ay, target, AI_SPEED * delta)
	_ay = clampf(_ay, SCREEN.position.y + PADDLE.y / 2.0, SCREEN.end.y - PADDLE.y / 2.0)


func _step_ball(delta: float) -> void:
	_ball += _vel * delta
	_trail.append(_ball)
	if _trail.size() > 7:
		_trail.pop_front()
	var top := SCREEN.position.y + BALL / 2.0
	var bot := SCREEN.end.y - BALL / 2.0
	if _ball.y < top or _ball.y > bot:
		_ball.y = clampf(_ball.y, top, bot)
		_vel.y = -_vel.y
		Sfx.play("pickup", -14.0, 0.7)
		MG.sparks_burst(_sparks, _ball, PHOSPHOR, 5)
	# Kone seuraa vain pelaajalta lähtevää palloa; palaa muuten keskelle.
	if _vel.x > 0.0:
		_move_ai(delta, _ball.y + _ai_err)
	else:
		_move_ai(delta * 0.5, SCREEN.get_center().y)
	var px := SCREEN.position.x + 26.0 + PADDLE.x / 2.0
	var ax := SCREEN.end.x - 26.0 - PADDLE.x / 2.0
	if _vel.x < 0.0 and _ball.x - BALL / 2.0 <= px + PADDLE.x / 2.0 and _ball.x > px - PADDLE.x:
		if absf(_ball.y - _py) <= PADDLE.y / 2.0 + BALL / 2.0:
			_hit(0, px + PADDLE.x / 2.0 + BALL / 2.0, _py)
	elif _vel.x > 0.0 and _ball.x + BALL / 2.0 >= ax - PADDLE.x / 2.0 and _ball.x < ax + PADDLE.x:
		if absf(_ball.y - _ay) <= PADDLE.y / 2.0 + BALL / 2.0:
			_hit(1, ax - PADDLE.x / 2.0 - BALL / 2.0, _ay)
	if _ball.x < SCREEN.position.x - 10.0:
		_point(1)
	elif _ball.x > SCREEN.end.x + 10.0:
		_point(0)


## Mailaosuma: kulma osumakohdan mukaan, pallo kiihtyy.
func _hit(who: int, x: float, py: float) -> void:
	var off := clampf((_ball.y - py) / (PADDLE.y / 2.0), -1.0, 1.0)
	_rally += 1
	_speed = minf(SPEED0 + _rally * SPEED_STEP, SPEED_MAX)
	var dir := 1.0 if who == 0 else -1.0
	var a := off * 0.95
	_vel = Vector2(cos(a) * dir, sin(a)) * _speed
	_ball.x = x
	_ai_err = randf_range(-30.0, 30.0) + off * 12.0
	_shake = 0.35
	MG.sparks_burst(_sparks, _ball, PHOSPHOR, 10)
	Sfx.play("pickup", -6.0, 0.8 + minf(_rally, 12) * 0.05)


func _point(who: int) -> void:
	_score[who] += 1
	_phase = "point"
	_t = 0.0
	_flash = 1.0
	_shake = 0.7
	_serve_dir = 1.0 if who == 1 else -1.0  # pisteen hävinnyt saa syötön
	MG.sparks_burst(_sparks, _ball, Color(1.0, 0.8, 0.4), 22)
	Sfx.play("coin" if who == 0 else "rattle_hard", -6.0)
	if _score.max() >= WIN_AT:
		_say("PELI!" if who == 0 else "KONE VOITTI", 1.2)
	else:
		_say("%d - %d" % [_score[0], _score[1]], 1.0)


# --- Piirto ---------------------------------------------------------------------------------

func _draw_root() -> void:
	var c := _root
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 5.0 * _shake
	# Museon seinä: tapetti, alaosassa puupanelointi, lattia pöydän alla.
	MG.grad_rect(c, Rect2(0, 0, W, 520), Color(0.78, 0.7, 0.56), Color(0.62, 0.54, 0.42))
	for x in range(0, 1280, 64):
		c.draw_line(Vector2(x, 0), Vector2(x, 520), Color(0.5, 0.42, 0.3, 0.18), 2.0)
	MG.wood(c, Rect2(0, 520, W, 200), Color(0.46, 0.31, 0.18), 70.0, 3, true)
	MG.grad_rect(c, Rect2(0, 500, W, 30), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.35))
	MG.sign(c, Rect2(360, 18, 560, 48), "TIETOKONEMUSEO, SALOINEN", Color(0.2, 0.14, 0.09), Color(0.97, 0.9, 0.7), 28, Color(0.78, 0.6, 0.2))
	# Kotelo: beige muovirunko, pyöristetty, tumma ääriviiva, ruudun kehys sisällä.
	var case_r := Rect2(250, 70, 820, 490)
	MG.box(c, Rect2(case_r.position + Vector2(0, 14), case_r.size), Color(0, 0, 0, 0.3), 40)
	MG.box(c, case_r, CASE.darkened(0.15), 36, 14, INK, 3)
	MG.box(c, case_r.grow(-8), CASE, 32)
	MG.grad_rect(c, Rect2(case_r.position + Vector2(40, 8), Vector2(case_r.size.x - 80, 20)), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0))
	MG.box(c, SCREEN.grow(26), Color(0.2, 0.18, 0.16), 30, 0, INK, 3)
	# Ruutu.
	var scr := SCREEN
	scr.position += sh
	MG.box(c, scr, Color(0.03, 0.06, 0.05), 20)
	MG.glow(c, scr.get_center(), 340.0, Color(0.5, 1.0, 0.7, 0.12 + 0.3 * _flash))
	_draw_field(sh)
	# Pyyhkäisyviivat ja reunojen tummennus (kaareva lasi).
	for y in range(int(scr.position.y) + 2, int(scr.end.y), 4):
		c.draw_line(Vector2(scr.position.x, y), Vector2(scr.end.x, y), Color(0, 0, 0, 0.16), 1.0)
	var roll := fposmod(_t * 60.0, scr.size.y)
	MG.grad_rect(c, Rect2(scr.position.x, scr.position.y + roll - 20, scr.size.x, 20), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.05))
	MG.grad_rect(c, Rect2(scr.position, Vector2(scr.size.x, 36)), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))
	MG.grad_rect(c, Rect2(scr.position + Vector2(0, scr.size.y - 36), Vector2(scr.size.x, 36)), Color(0, 0, 0, 0), Color(0, 0, 0, 0.45))
	c.draw_arc(scr.position + Vector2(80, 60), 40.0, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.12), 6.0, true)  # lasin heijastus
	MG.box(c, scr.grow(3), Color(0, 0, 0, 0), 20, 0, INK, 3)
	# Muovikotelon osat: säätönuppi, tyyppikilpi ja ilmanvaihtoraot.
	for k in 2:
		var kp := Vector2(1026, 210 + k * 110)
		MG.ball(c, kp, 30.0, Color(0.2, 0.17, 0.14), 0.4)
		c.draw_line(kp, kp + Vector2(0, -22).rotated(0.5 + k * 1.3 + sin(_t * 0.6) * 0.05), CASE, 4.0)
	MG.sign(c, Rect2(560, 526, 160, 28), "PONG", Color(0.2, 0.14, 0.09), Color(0.97, 0.9, 0.7), 22, Color(0.78, 0.6, 0.2))
	for k in 5:
		c.draw_line(Vector2(1002, 400 + k * 12), Vector2(1050, 400 + k * 12), CASE.darkened(0.4), 3.0)
	# Pöytä ja ohjainnupit pelaajalle.
	MG.wood(c, Rect2(0, 560, W, 160), Color(0.36, 0.23, 0.12), 80.0, 7, true)
	c.draw_rect(Rect2(0, 556, W, 8), Color(0.62, 0.44, 0.24))
	for k in 2:
		var kp := Vector2(560 + k * 160, 636)
		MG.ball(c, kp, 36.0, Color(0.78, 0.2, 0.16) if k == 0 else Color(0.2, 0.3, 0.6), 0.5)
		c.draw_circle(kp, 22.0, Color(0, 0, 0, 0.15))
	MG.sparks_draw(c, _sparks)
	# Tilaviesti ja loppuruutu.
	if _msg_t > 0.0 and _phase != "over":
		MG.sign(c, Rect2(430, 600, 420, 64), _msg, Color(0.97, 0.93, 0.8), INK, 34, Color(0.78, 0.6, 0.2))
	if _phase == "over":
		var a := minf(_t / 0.5, 1.0)
		c.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5 * a))
		var won: bool = _score[0] > _score[1]
		MG.sign(c, Rect2(340, 230, 600, 220), ("VOITIT!" if won else "KONE VOITTI") + "\n%d - %d\n[Väli] Jatka" % [_score[0], _score[1]],
			Color(0.2, 0.14, 0.09), Color(1, 0.93, 0.6), 52, Color(0.78, 0.6, 0.2))


func _draw_field(sh: Vector2) -> void:
	var c := _root
	var r := SCREEN
	r.position += sh
	# Keskiviiva, ylä- ja alareunan viivat.
	for y in range(int(r.position.y) + 6, int(r.end.y) - 6, 26):
		c.draw_rect(Rect2(r.get_center().x - 3, y, 6, 14), PHOSPHOR * Color(1, 1, 1, 0.7))
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5), PHOSPHOR * Color(1, 1, 1, 0.8))
	c.draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), PHOSPHOR * Color(1, 1, 1, 0.8))
	_draw_digit(_score[0], Vector2(r.get_center().x - 100, r.position.y + 28))
	_draw_digit(_score[1], Vector2(r.get_center().x + 60, r.position.y + 28))
	# Mailat ja pallo hehkulla.
	var px := r.position.x + 26.0
	var ax := r.end.x - 26.0 - PADDLE.x
	for p in [Rect2(px, _py - PADDLE.y / 2.0 + sh.y, PADDLE.x, PADDLE.y), Rect2(ax, _ay - PADDLE.y / 2.0 + sh.y, PADDLE.x, PADDLE.y)]:
		c.draw_rect(p.grow(5), Color(0.5, 1.0, 0.7, 0.14))
		c.draw_rect(p, PHOSPHOR)
	for i in _trail.size():
		var tp: Vector2 = _trail[i] + sh
		c.draw_rect(Rect2(tp - Vector2(BALL, BALL) / 2.0, Vector2(BALL, BALL)), Color(0.5, 1.0, 0.7, 0.05 + 0.04 * i))
	if _phase == "play" or _phase == "serve":
		var bp := _ball + sh
		c.draw_rect(Rect2(bp - Vector2(BALL, BALL) / 2.0 - Vector2(5, 5), Vector2(BALL, BALL) + Vector2(10, 10)), Color(0.5, 1.0, 0.7, 0.18))
		c.draw_rect(Rect2(bp - Vector2(BALL, BALL) / 2.0, Vector2(BALL, BALL)), Color(1, 1, 1))


## Iso seitsemän segmentin numero (kuten oikeassa Pongissa).
func _draw_digit(n: int, at: Vector2) -> void:
	var segs: String = DIGITS.get(clampi(n, 0, 6), "abcdef")
	var w := 40.0
	var h := 36.0
	var t := 8.0
	var rects := {
		"a": Rect2(at.x, at.y, w, t), "b": Rect2(at.x + w - t, at.y, t, h), "c": Rect2(at.x + w - t, at.y + h, t, h),
		"d": Rect2(at.x, at.y + 2.0 * h - t, w, t), "e": Rect2(at.x, at.y + h, t, h), "f": Rect2(at.x, at.y, t, h),
		"g": Rect2(at.x, at.y + h - t / 2.0, w, t),
	}
	for s in segs:
		_root.draw_rect(rects[s], PHOSPHOR)
