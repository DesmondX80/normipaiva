extends CanvasLayer
## Rantajalkapallo (#250 P19): Kalajoen Hiekkasärkät, sivukuva. Pelaaja vasemmalla (A/D tai nuolet liikkuu, W/ylös hyppy, Väli potkaisee),
## kone oikealla. Ensin kolmeen maaliin voittaa (WIN_AT). Pallo pomppii hiekasta, maalien rimoista ja seinistä; maali on rimaa alempana.
## Esc lopettaa kesken (finished(false, ...)). Ottelun jälkeen Väli/E/klikkaus sulkee: finished(won, my, ai).
## juhannus = true: koivut ja siimalippu kentän laidalle (turnaus). Grafiikka: ranta, meri, dyynit, sateenvarjot, verkolliset maalit.

signal finished(won: bool, my_score: int, ai_score: int)

const MG := preload("res://scripts/mg_draw.gd")
const W := 1280.0
const H := 720.0
const GROUND := 600.0  # hiekan yläpinta (jalkojen y)
const GOAL_W := 130.0  # maalin leveys reunasta
const CROSSBAR := 430.0  # rimaan y; maali on sen alla
const BALL_R := 21.0
const PL_W := 24.0  # pelaajan puolileveys
const PL_H := 124.0
const GRAV := 1500.0
const WIN_AT := 3
const INK := Color(0.1, 0.08, 0.06)

var juhannus := false

var _phase := "intro"  # intro | play | goal | over
var _t := 0.0
var _score := [0, 0]  # [pelaaja, kone]
var _pl := {"x": 330.0, "y": GROUND, "vx": 0.0, "vy": 0.0, "face": 1.0, "kick": 0.0, "kicked": false}
var _ai := {"x": 950.0, "y": GROUND, "vx": 0.0, "vy": 0.0, "face": -1.0, "kick": 0.0, "kicked": false}
var _ball := Vector2(640, 250)
var _bv := Vector2.ZERO
var _spin := 0.0
var _sparks: Array = []
var _shake := 0.0
var _msg := ""
var _msg_t := 0.0
var _ai_err := 0.0
var _ai_react := 0.0
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
	_say("Ensin kolmeen maaliin voittaa", 2.4)
	_reset_play()
	Sfx.play("alert", -8.0, 1.2)


func _input(ev: InputEvent) -> void:
	if _finished:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ESCAPE or ev.keycode == KEY_F:
			_end(false)
		elif _phase == "over" and _t > 0.6 and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_E):
			_end(_score[0] > _score[1])
		elif ev.keycode == KEY_SPACE and _phase == "play" and _pl.kick <= 0.0:
			_pl.kick = 0.24
			_pl.kicked = false
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _phase == "over" and _t > 0.6:
			_end(_score[0] > _score[1])
		elif _phase == "play" and _pl.kick <= 0.0:
			_pl.kick = 0.24
			_pl.kicked = false


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

func _reset_play() -> void:
	_pl.x = 330.0
	_ai.x = 950.0
	for p in [_pl, _ai]:
		p.y = GROUND
		p.vx = 0.0
		p.vy = 0.0
		p.kick = 0.0
	_ball = Vector2(640, 260)
	_bv = Vector2(randf_range(-60, 60), 0)
	_ai_err = randf_range(-40.0, 40.0)


func _process(delta: float) -> void:
	if _finished:
		return
	delta = minf(delta, 0.04)
	_t += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	_msg_t = maxf(0.0, _msg_t - delta)
	MG.sparks_step(_sparks, delta)
	match _phase:
		"intro":
			if _t > 1.6:
				_phase = "play"
				_t = 0.0
		"play":
			_step(delta)
		"goal":
			if _t > 1.5:
				if _score.max() >= WIN_AT:
					_phase = "over"
					_t = 0.0
					Sfx.play("win_small" if _score[0] > _score[1] else "lose", -4.0)
				else:
					_reset_play()
					_phase = "play"
					_t = 0.0
	if _phase == "over":
		_keys.set_text("[Väli] Valmis")
	else:
		_keys.set_text("[A/D] Liiku   [W] Hyppää   [Väli] Potkaise   (ensin %d maaliin)   [Esc] Lopeta" % WIN_AT)
	_root.queue_redraw()


func _step(delta: float) -> void:
	var dir := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	if dir != 0.0:
		_pl.face = dir
	_pl.vx = dir * 340.0
	if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) and _pl.y >= GROUND:
		_pl.vy = -640.0
	_move_ai(delta)
	for p in [_pl, _ai]:
		_move_body(p, delta)
	for sub in 2:  # kaksi alaskelta, ettei nopea pallo mene pelaajan läpi
		_move_ball(delta * 0.5)
		_hit_body(_pl)
		_hit_body(_ai)


func _move_body(p: Dictionary, delta: float) -> void:
	p.x = clampf(p.x + p.vx * delta, PL_W + 8.0, W - PL_W - 8.0)
	p.vy += GRAV * delta
	p.y += p.vy * delta
	if p.y >= GROUND:
		p.y = GROUND
		p.vy = 0.0
	p.kick = maxf(0.0, p.kick - delta)


func _move_ai(delta: float) -> void:
	_ai_react -= delta
	if _ai_react <= 0.0:
		_ai_react = 0.25
		_ai_err = randf_range(-34.0, 34.0)
	# Pysyy pallon oikealla puolella (oma maali oikealla) ja potkaisee kohti pelaajan maalia.
	var target: float = _ball.x + 58.0 + _ai_err * 0.4
	if _ball.x > _ai.x + 10.0:
		target = _ball.x + 70.0  # pallo takana: kierrä sen taakse
	if _ball.x > W - 200.0 and _ai.x < _ball.x:
		target = W - 220.0  # ei seisota oman maalin sisällä
	var dx: float = target - _ai.x
	_ai.vx = clampf(dx * 4.0, -250.0, 250.0)
	_ai.face = -1.0
	var near: float = _ai.x - _ball.x
	if _ai.kick <= 0.0 and near > -10.0 and near < 84.0 and _ball.y > GROUND - 120.0 and _ai.y >= GROUND - 6.0:
		_ai.kick = 0.24
		_ai.kicked = false
	if _ai.y >= GROUND and _ball.y < GROUND - 170.0 and absf(_ball.x - _ai.x) < 120.0 and _bv.y > 0.0 and randf() < 0.05:
		_ai.vy = -600.0  # puskupallo


func _move_ball(delta: float) -> void:
	var prev := _ball
	_bv.y += GRAV * delta
	_bv *= 1.0 - 0.1 * delta
	_ball += _bv * delta
	_spin += _bv.x * delta * 0.02
	if _ball.y > GROUND - BALL_R:
		_ball.y = GROUND - BALL_R
		if _bv.y > 120.0:
			Sfx.play("pickup", -16.0, 0.5)
			MG.sparks_burst(_sparks, Vector2(_ball.x, GROUND), Color(0.93, 0.82, 0.55), 4)
		_bv.y = -_bv.y * 0.6 if _bv.y > 120.0 else 0.0
		_bv.x *= 1.0 - 1.8 * delta  # hiekka jarruttaa
	# Rima: pomppaa ylhäältä ja alhaalta.
	for side in [0, 1]:
		var in_goal: bool = _ball.x < GOAL_W + BALL_R if side == 0 else _ball.x > W - GOAL_W - BALL_R
		if in_goal and absf(_ball.y - CROSSBAR) < BALL_R + 5.0:
			if prev.y <= CROSSBAR:
				_ball.y = CROSSBAR - BALL_R - 5.0
				_bv.y = -absf(_bv.y) * 0.55
			else:
				_ball.y = CROSSBAR + BALL_R + 5.0
				_bv.y = absf(_bv.y) * 0.55
			Sfx.play("pickup", -10.0, 0.6)
	if _ball.y > CROSSBAR + 5.0:
		if _ball.x < 70.0:
			_goal(1)
			return
		if _ball.x > W - 70.0:
			_goal(0)
			return
	if _ball.x < BALL_R:
		_ball.x = BALL_R
		_bv.x = absf(_bv.x) * 0.6
	elif _ball.x > W - BALL_R:
		_ball.x = W - BALL_R
		_bv.x = -absf(_bv.x) * 0.6


## Pelaajan (suorakaide) ja pallon törmäys: lähin piste suorakaiteelta; potku antaa lisävauhtia kohti vastustajan maalia.
func _hit_body(p: Dictionary) -> void:
	var r := Rect2(p.x - PL_W, p.y - PL_H, PL_W * 2.0, PL_H)
	var cp := Vector2(clampf(_ball.x, r.position.x, r.end.x), clampf(_ball.y, r.position.y, r.end.y))
	var d := _ball - cp
	var dist := d.length()
	if dist >= BALL_R:
		return
	var n := d / dist if dist > 0.01 else Vector2(p.face, -0.5).normalized()
	_ball = cp + n * BALL_R
	var rel := _bv - Vector2(p.vx, p.vy)
	var vn := rel.dot(n)
	if vn < 0.0:
		_bv -= 1.7 * vn * n
	if p.kick > 0.0 and not p.kicked and cp.y > p.y - 78.0:
		p.kicked = true
		_bv = Vector2(p.face * 760.0, -420.0) + Vector2(p.vx * 0.3, 0)
		_shake = 0.25
		MG.sparks_burst(_sparks, _ball, Color(0.93, 0.82, 0.55), 12)
		Sfx.play("pickup", -5.0, 0.9)
	else:
		Sfx.play("pickup", -14.0, 1.1)
	if _bv.length() > 1100.0:
		_bv = _bv.normalized() * 1100.0


func _goal(who: int) -> void:
	_score[who] += 1
	_phase = "goal"
	_t = 0.0
	_shake = 0.8
	MG.sparks_burst(_sparks, _ball, Color(1.0, 0.85, 0.4), 26)
	Sfx.play("coin" if who == 0 else "rattle_hard", -6.0)
	if _score.max() >= WIN_AT:
		_say("PELI!" if who == 0 else "KONE VOITTI", 1.4)
	else:
		_say("MAALI!  %d - %d" % [_score[0], _score[1]], 1.4)


# --- Piirto ---------------------------------------------------------------------------------

func _draw_root() -> void:
	var c := _root
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 5.0 * _shake
	# Taivas, aurinko ja pilvet.
	MG.grad_rect(c, Rect2(0, 0, W, 330), Color(0.42, 0.7, 0.92), Color(0.82, 0.92, 0.96))
	MG.glow(c, Vector2(1020, 120), 130.0, Color(1.0, 0.95, 0.6, 0.9))
	c.draw_circle(Vector2(1020, 120), 38.0, Color(1.0, 0.97, 0.75))
	for k in 3:
		var cx := fposmod(160.0 + k * 420.0 + _t * 6.0, W + 200.0) - 100.0
		c.draw_circle(Vector2(cx, 90 + k * 28), 34.0, Color(1, 1, 1, 0.85))
		c.draw_circle(Vector2(cx + 36, 98 + k * 28), 28.0, Color(1, 1, 1, 0.85))
		c.draw_circle(Vector2(cx - 34, 100 + k * 28), 24.0, Color(1, 1, 1, 0.85))
	# Meri vaahtoineen ja kaukainen metsänreuna.
	c.draw_rect(Rect2(0, 300, W, 40), Color(0.18, 0.36, 0.3))
	MG.grad_rect(c, Rect2(0, 330, W, 120), Color(0.2, 0.5, 0.68), Color(0.32, 0.64, 0.78))
	for i in 14:
		var wx := fposmod(i * 100.0 + _t * 16.0 * (1 if i % 2 == 0 else -1), W + 80.0) - 40.0
		c.draw_line(Vector2(wx, 350 + (i % 4) * 22), Vector2(wx + 44, 350 + (i % 4) * 22), Color(1, 1, 1, 0.45), 3.0)
	c.draw_rect(Rect2(0, 440, W, 8), Color(0.92, 0.96, 0.96))
	# Hiekkadyynit ja ruoho, sateenvarjot taustalla.
	for k in 4:
		var dx := 140.0 + k * 360.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(dx - 240, 460), Vector2(dx - 90, 420), Vector2(dx + 40, 410), Vector2(dx + 200, 460)]),
			Color(0.88, 0.78, 0.55))
		for g in 6:
			c.draw_line(Vector2(dx - 60 + g * 14, 424 + absf(g - 2) * 3), Vector2(dx - 66 + g * 14, 404 + absf(g - 2) * 3), Color(0.42, 0.55, 0.28), 2.0)
	for u in [[240.0, Color(0.9, 0.3, 0.25)], [660.0, Color(0.95, 0.8, 0.25)], [1010.0, Color(0.25, 0.55, 0.85)]]:
		var ux: float = u[0]
		c.draw_line(Vector2(ux, 520), Vector2(ux + 6, 440), Color(0.45, 0.35, 0.25), 4.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(ux - 56, 458), Vector2(ux + 6, 414), Vector2(ux + 68, 458)]), u[1])
		c.draw_colored_polygon(PackedVector2Array([Vector2(ux - 18, 458), Vector2(ux + 6, 414), Vector2(ux + 24, 458)]), Color(1, 1, 1, 0.75))
	# Hiekkakenttä.
	MG.grad_rect(c, Rect2(0, 448, W, GROUND - 448), Color(0.95, 0.86, 0.62), Color(0.9, 0.79, 0.54))
	MG.grad_rect(c, Rect2(0, GROUND, W, H - GROUND), Color(0.84, 0.72, 0.48), Color(0.62, 0.5, 0.32))
	c.draw_line(Vector2(0, GROUND), Vector2(W, GROUND), Color(0.96, 0.9, 0.7), 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:  # hiekkarakeet ja jalanjäljet
		var px := rng.randf_range(0, W)
		var py := rng.randf_range(GROUND + 6, H - 8)
		c.draw_circle(Vector2(px, py), rng.randf_range(1.5, 3.0), Color(0.55, 0.43, 0.28, 0.5))
	c.draw_line(Vector2(W / 2.0, GROUND - 6), Vector2(W / 2.0, GROUND + 22), Color(1, 1, 1, 0.7), 3.0)  # keskimerkki
	if juhannus:
		_draw_juhannus()
	_draw_goal(0)
	_draw_goal(1)
	# Varjot.
	for p in [_pl, _ai]:
		MG.box(c, Rect2(p.x - 26, GROUND + 1, 52, 8), Color(0, 0, 0, 0.25), 4)
	var bsh := clampf((GROUND - _ball.y) / 300.0, 0.0, 1.0)
	MG.box(c, Rect2(_ball.x - 18 + bsh * 6, GROUND + 1, 36 - bsh * 12, 7), Color(0, 0, 0, 0.3 - bsh * 0.15), 4)
	_draw_player(_ai, {"shirt": Color(0.9, 0.78, 0.2), "shorts": Color(0.2, 0.3, 0.6), "hair": Color(0.25, 0.18, 0.12), "skin": Color(0.95, 0.77, 0.62)})
	_draw_player(_pl, {"shirt": Color(0.78, 0.2, 0.18), "shorts": Color(0.95, 0.95, 0.92), "hair": Color(0.4, 0.3, 0.18), "skin": Color(0.96, 0.78, 0.66)})
	_draw_ball()
	MG.sparks_draw(c, _sparks)
	# Tulostaulu ja viestit.
	MG.sign(c, Rect2(530, 14, 220, 70), "%d  -  %d" % [_score[0], _score[1]], Color(0.12, 0.3, 0.45), Color(0.99, 0.95, 0.8), 44, Color(0.9, 0.75, 0.35))
	MG.sign(c, Rect2(20, 20, 300, 44), "HIEKKASÄRKÄT, KALAJOKI", Color(0.12, 0.3, 0.45), Color(0.99, 0.95, 0.8), 22, Color(0.9, 0.75, 0.35))
	c.draw_string(ThemeDB.fallback_font, Vector2(150, GROUND + 70), "SINÄ", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 0.1, 0.08))
	c.draw_string(ThemeDB.fallback_font, Vector2(1090, GROUND + 70), "KONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.35, 0.28, 0.05))
	if _msg_t > 0.0 and _phase != "over":
		MG.sign(c, Rect2(400, 260, 480, 70), _msg, Color(0.97, 0.93, 0.8), INK, 36, Color(0.9, 0.75, 0.35))
	if _phase == "over":
		var a := minf(_t / 0.5, 1.0)
		c.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5 * a))
		var won: bool = _score[0] > _score[1]
		MG.sign(c, Rect2(340, 230, 600, 220), ("VOITIT!" if won else "KONE VOITTI") + "\n%d - %d\n[Väli] Jatka" % [_score[0], _score[1]],
			Color(0.12, 0.3, 0.45), Color(1, 0.93, 0.6), 52, Color(0.9, 0.75, 0.35))


## Juhannus: koivut kentän laidoilla ja siimalippu.
func _draw_juhannus() -> void:
	var c := _root
	for bx in [190.0, 1090.0, 420.0, 860.0]:
		c.draw_line(Vector2(bx, GROUND), Vector2(bx, 360), Color(0.92, 0.92, 0.88), 8.0)
		for k in 5:
			c.draw_circle(Vector2(bx + sin(k * 2.1) * 26.0, 380 - k * 14), 26.0 - k * 2.0, Color(0.35 + k * 0.03, 0.62, 0.26))
	for i in 2:
		var x0 := 190.0 + i * 670.0
		var x1 := 420.0 + i * 670.0
		var pts := PackedVector2Array()
		for s in 13:
			var tt := s / 12.0
			pts.append(Vector2(lerpf(x0, x1, tt), 372.0 + sin(tt * PI) * 26.0))
		c.draw_polyline(pts, Color(0.4, 0.3, 0.2), 2.0)
		for s in range(1, 12):
			var cp: Vector2 = pts[s]
			c.draw_colored_polygon(PackedVector2Array([cp, cp + Vector2(14, 0), cp + Vector2(7, 20)]), Color(0.2, 0.42, 0.82) if s % 2 == 0 else Color(0.97, 0.97, 0.92))


func _draw_goal(side: int) -> void:
	var c := _root
	var x0 := 0.0 if side == 0 else W - GOAL_W
	var fx := GOAL_W if side == 0 else W - GOAL_W  # etutolpan x
	# Verkko (ruudukko) ja katto.
	var net := Rect2(x0, CROSSBAR, GOAL_W, GROUND - CROSSBAR)
	c.draw_rect(net, Color(1, 1, 1, 0.1))
	for gx in range(0, int(GOAL_W) + 1, 16):
		c.draw_line(Vector2(x0 + gx, CROSSBAR), Vector2(x0 + gx, GROUND), Color(1, 1, 1, 0.38), 1.5)
	for gy in range(int(CROSSBAR), int(GROUND) + 1, 16):
		c.draw_line(Vector2(x0, gy), Vector2(x0 + GOAL_W, gy), Color(1, 1, 1, 0.38), 1.5)
	# Tolpat ja rima.
	c.draw_line(Vector2(fx, CROSSBAR), Vector2(fx, GROUND), Color(0.97, 0.97, 0.94), 9.0)
	c.draw_line(Vector2(x0, CROSSBAR), Vector2(x0 + GOAL_W, CROSSBAR), Color(0.97, 0.97, 0.94), 9.0)
	c.draw_line(Vector2(fx + 4.5 * (1 if side == 0 else -1), CROSSBAR), Vector2(fx + 4.5 * (1 if side == 0 else -1), GROUND), Color(0.7, 0.7, 0.66), 2.0)
	c.draw_circle(Vector2(fx, CROSSBAR), 6.0, Color(0.97, 0.97, 0.94))


## Pelaaja sivusta: pää ja hiukset, paita, shortsit, jalat (juoksuliike, potkussa jalka eteen), kädet heiluvat vastaan.
func _draw_player(p: Dictionary, look: Dictionary) -> void:
	var c := _root
	var f: float = p.face
	var x: float = p.x
	var y: float = p.y
	var air: bool = y < GROUND - 2.0
	var run: float = sin(_t * 14.0) * clampf(absf(p.vx) / 300.0, 0.0, 1.0)
	var hip := Vector2(x, y - 58)
	var skin: Color = look.skin
	var kick: float = p.kick
	# Jalat: kaukainen ensin (tummempi), lähin päälle. Potkuliike: lähin jalka heilahtaa eteen.
	var far_foot := hip + Vector2(-run * 22.0 * f, 56.0 - (14.0 if air else 0.0))
	var near_foot := hip + Vector2(run * 22.0 * f, 56.0 - (22.0 if air else 0.0))
	if kick > 0.0:
		var k := sin((1.0 - kick / 0.24) * PI)
		near_foot = hip + Vector2(f * (14.0 + 52.0 * k), 50.0 - 26.0 * k)
	for leg in [[far_foot, skin.darkened(0.15), look.shorts.darkened(0.15)], [near_foot, skin, look.shorts]]:
		var ft: Vector2 = leg[0]
		var knee: Vector2 = hip.lerp(ft, 0.5) + Vector2(f * 6.0, 0)
		c.draw_line(hip, knee, leg[1], 13.0)
		c.draw_line(knee, ft, leg[1], 11.0)
		c.draw_line(hip, hip.lerp(knee, 0.35), leg[2], 15.0)
		c.draw_circle(ft + Vector2(f * 6.0, -2.0), 7.0, leg[1])  # jalkaterä
	# Vartalo: paita, shortsit.
	var tor := Rect2(x - 17, y - 112, 34, 60)
	MG.box(c, tor, look.shirt, 12, 0, MG.OUTLINE, 2)
	c.draw_rect(Rect2(tor.position + Vector2(5, 5), Vector2(24, 8)), look.shirt.lightened(0.18))
	MG.box(c, Rect2(x - 18, y - 66, 36, 18), look.shorts, 6, 0, MG.OUTLINE, 2)
	# Kädet.
	var sw := -run * 18.0 * f
	for arm in [[-1.0, 0.8], [1.0, 1.0]]:
		var sh_pt := Vector2(x, y - 104)
		var hand := sh_pt + Vector2(sw * arm[0] + f * (6.0 if air else 0.0), 40.0 - (28.0 if air else 0.0))
		c.draw_line(sh_pt, hand, skin.darkened(0.12 if arm[0] < 0 else 0.0), 10.0)
		c.draw_circle(hand, 5.5, skin)
	# Pää: iho, hiukset, silmä ja suu katseen suuntaan.
	var head := Vector2(x + f * 2.0, y - 128 + (2.0 if air else 0.0))
	c.draw_circle(head, 19.0, skin)
	c.draw_arc(head, 19.0, 0, TAU, 24, MG.OUTLINE, 2.0, true)
	c.draw_arc(head, 20.0, PI * 0.95, PI * 2.05, 16, look.hair, 9.0, true)  # hiukset päälaella
	c.draw_circle(head + Vector2(-f * 14.0, -2.0), 8.0, look.hair)
	c.draw_circle(head + Vector2(f * 9.0, -3.0), 3.0, Color(1, 1, 1))
	c.draw_circle(head + Vector2(f * 10.5, -3.0), 1.6, INK)
	c.draw_line(head + Vector2(f * 6.0, 8.0), head + Vector2(f * 13.0, 7.0), Color(0.5, 0.2, 0.15), 2.0)


## Pallo: valkoinen, mustat laikat pyörivät vauhdin mukana, kiilto ja ääriviiva.
func _draw_ball() -> void:
	var c := _root
	var bp := _ball
	c.draw_circle(bp, BALL_R, Color(0.97, 0.97, 0.95))
	for k in 5:
		var a := _spin + k * TAU / 5.0
		var pp := bp + Vector2(cos(a), sin(a)) * BALL_R * 0.55
		c.draw_circle(pp, BALL_R * 0.2, Color(0.12, 0.12, 0.14))
	c.draw_circle(bp, BALL_R * 0.18, Color(0.12, 0.12, 0.14))
	c.draw_circle(bp - Vector2(BALL_R * 0.4, BALL_R * 0.4), BALL_R * 0.2, Color(1, 1, 1, 0.8))
	c.draw_arc(bp, BALL_R, 0, TAU, 28, MG.OUTLINE, 2.0, true)
