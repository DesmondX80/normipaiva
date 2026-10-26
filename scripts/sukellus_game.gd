extends CanvasLayer
## Vanha herra -sukellus (#250 P11): Raahen sataman pohjalle laskeutuu raskaassa kuparikypäräpuvussa sukeltaja, ja pelaaja pumppaa hänelle ilmaa
## laiturilla keinuvipupumpulla: A työntää vivun alas ja D vetää ylös, vuorotellen (sama näppäin kahdesti ei pumppaa). Nuolet kävelyttävät sukeltajaa
## pohjalla, E tutkii lähimmän esineen. Ilma loppuu (mittari), liian täysi paine nostaa sukeltajan pohjasta. Pohjalta löytyy kadonnut kapteenin taskukello
## muun roinan (saapas, ämpäri, pullo, ankkuri) seasta. Esc lopettaa. Lopussa Väli/E/klikkaus sulkee: finished(found, roina, pumppaukset).
## Grafiikka: satamamaisema (makasiini, vene, lokit), vedenalainen leikkaus (valonsäteet, kalat, rakkolevä, kuplat), laiturin pumppu ja pumppaaja.

signal finished(found: bool, junk: int, pumps: int)

const MG := preload("res://scripts/mg_draw.gd")
const W := 1280.0
const H := 720.0
const INK := Color(0.08, 0.06, 0.05)
const WATER_Y := 190.0  # vedenpinta ja laiturin kansi
const PIER_END := 540.0
const LADDER_X := 506.0
const AIR_START := 55.0
const AIR_DRAIN := 4.0
const AIR_DRAIN_WALK := 7.0
const AIR_DRAIN_DIG := 6.0
const PUMP_GAIN := 5.0
const PUMP_BONUS := 3.5  # tasainen tahti (0,22-0,75 s)
const WALK_SPEED := 150.0
const X_MIN := 585.0
const X_MAX := 1215.0
const DIG_TIME := 0.8
const REACH := 62.0
const WATCH_ID := "kello"
const COPPER := Color(0.78, 0.46, 0.24)
const CANVAS := Color(0.66, 0.55, 0.36)

var _phase := "intro"  # intro | descend | dive | found | fail | over
var _t := 0.0
var _won := false
var _air := AIR_START
var _pumps := 0
var _junk := 0
var _last_key := ""
var _last_pump_t := -9.0
var _beam := 0.0  # vivun kulma (rad), + = pumppaajan puoleinen pää alas
var _beam_goal := 0.0
var _dx := PIER_END + 30.0  # sukeltajan jalkojen paikka
var _dy := WATER_Y
var _face := 1.0
var _walk_t := 0.0
var _dig_t := 0.0
var _dig_item := -1
var _float := 0.0  # kellunta pohjan päällä (px)
var _items: Array = []  # {id, x, done}
var _bubbles: Array = []  # [pos, vel, r, age]
var _sparks: Array = []
var _fish: Array = []
var _weeds: Array = []
var _stones: Array = []
var _bubble_t := 0.0
var _shake := 0.0
var _msg := ""
var _msg_t := 0.0
var _danger_t := 0.0
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for d in [["saapas", 700.0], ["ampari", 830.0], ["pullo", 940.0], ["ankkuri", 1040.0], [WATCH_ID, 1150.0]]:
		_items.append({"id": d[0], "x": d[1], "done": false})
	for i in 26:
		_weeds.append([rng.randf_range(560.0, 1250.0), rng.randf_range(0.0, TAU), rng.randf_range(36.0, 84.0)])
	for i in 30:
		_stones.append([rng.randf_range(20.0, 1260.0), rng.randf_range(8.0, 24.0), rng.randf_range(0.0, 1.0)])
	for i in 8:
		_fish.append({"p": Vector2(rng.randf_range(620.0, 1200.0), rng.randf_range(300.0, 560.0)), "v": rng.randf_range(24.0, 48.0) * (1.0 if i % 2 == 0 else -1.0),
			"s": rng.randf_range(0.8, 1.3), "ph": rng.randf_range(0.0, TAU), "flee": 0.0})
	_say("Pumppaa vuorotellen A ja D: sukeltaja tarvitsee ilmaa!", 3.0)
	Sfx.play("water", -12.0)
	Sfx.play("alert", -10.0, 1.2)


func _input(ev: InputEvent) -> void:
	if _finished:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ESCAPE or ev.keycode == KEY_F:
			_end(false)
		elif ev.keycode == KEY_A or ev.keycode == KEY_D:
			_pump("a" if ev.keycode == KEY_A else "d")
		elif _phase == "over" and _t > 0.6 and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_E):
			_end(_won)
		elif _phase == "dive" and (ev.keycode == KEY_E or ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER):
			_dig()
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _phase == "over" and _t > 0.6:
		_end(_won)


func _end(found: bool) -> void:
	if _finished:
		return
	_finished = true
	finished.emit(found, _junk, _pumps)
	queue_free()


func _say(t: String, d := 2.2) -> void:
	_msg = t
	_msg_t = d


## Pumpun vipu: vuorotellen A (alas) ja D (ylös) antaa ilmaa; sama näppäin kahdesti ei anna.
func _pump(key: String) -> void:
	if _phase == "over" or (_phase == "intro" and _t < 0.2):
		return
	_beam_goal = 1.0 if key == "a" else -1.0
	if key == _last_key:
		Sfx.play("rattle", -16.0, 1.2)
		_say("Vuorotellen! A ja D, ei samaa kahdesti", 1.2)
		return
	_last_key = key
	var gap := _t - _last_pump_t
	_last_pump_t = _t
	_pumps += 1
	var good := gap >= 0.22 and gap <= 0.75
	if _phase == "dive" or _phase == "descend" or _phase == "intro":
		_air = minf(100.0, _air + PUMP_GAIN + (PUMP_BONUS if good else 0.0))
	Sfx.play("whoosh", -17.0, 1.5 if good else 1.1)
	MG.sparks_burst(_sparks, Vector2(334.0 - 8.0 * _beam_goal, WATER_Y - 28.0), Color(0.95, 0.95, 1.0), 2)
	_bubble_burst(1)


func _dig() -> void:
	if _dig_t > 0.0 or _float > 8.0:
		if _float > 8.0:
			_say("Paine on liian korkea: kellut pohjasta! Anna ilman vähän laskea.", 1.8)
		return
	var best := -1
	var bd := REACH
	for i in _items.size():
		if _items[i].done:
			continue
		var d := absf(_items[i].x - _dx)
		if d < bd:
			bd = d
			best = i
	if best < 0:
		_say("Tässä ei ole mitään. Kävele lähemmäs esinettä.", 1.4)
		return
	_dig_item = best
	_dig_t = DIG_TIME
	Sfx.play("cloth", -8.0, 0.7)


func _bubble_burst(n: int) -> void:
	var hp := _helmet()
	for i in n:
		_bubbles.append([hp + Vector2(_face * 16.0, -22.0 + randf() * 4.0), Vector2(randf_range(-10.0, 10.0), randf_range(-70.0, -110.0)), randf_range(2.5, 6.0), 0.0])


# --- Kulku ----------------------------------------------------------------------------------

func _bed(x: float) -> float:
	return 650.0 + 14.0 * sin(x * 0.012) + 8.0 * sin(x * 0.031 + 1.0) + (maxf(0.0, 560.0 - x) * 0.04)


func _helmet() -> Vector2:
	return Vector2(_dx, _dy - 124.0)


func _process(delta: float) -> void:
	if _finished:
		return
	delta = minf(delta, 0.05)
	_t += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	_msg_t = maxf(0.0, _msg_t - delta)
	_beam = move_toward(_beam, _beam_goal, delta * 5.5)
	_beam_goal = move_toward(_beam_goal, 0.0, delta * 0.9)  # vipu hakeutuu keskelle, jos pumppaus lakkaa
	MG.sparks_step(_sparks, delta)
	_step_bubbles(delta)
	_step_fish(delta)
	match _phase:
		"intro":
			_drain(delta, AIR_DRAIN * 0.5)
			if _t > 1.6:
				_phase = "descend"
				_t = 0.0
				Sfx.play("whoosh", -8.0, 0.6)
		"descend":
			_drain(delta, AIR_DRAIN)
			var k := minf(_t / 2.4, 1.0)
			_dx = lerpf(PIER_END + 30.0, X_MIN, k)
			var to_bed := _bed(_dx)
			_dy = lerpf(WATER_Y + 4.0, to_bed, k * k * (3.0 - 2.0 * k))
			if k >= 1.0:
				_phase = "dive"
				_t = 0.0
				_say("Pohjalla! Kävele nuolilla ja tutki esineet (E). Etsi kapteenin kello.", 3.2)
				Sfx.play("step_hard", -8.0, 0.5)
		"dive":
			_dive_step(delta)
		"found":
			_dy -= 120.0 * delta
			_air = maxf(_air, 40.0)
			if _dy <= WATER_Y + 4.0:
				_phase = "over"
				_won = true
				_t = 0.0
				Sfx.play("win_small", -4.0)
		"fail":
			_dy -= 110.0 * delta
			if _dy <= WATER_Y + 4.0:
				_phase = "over"
				_won = false
				_t = 0.0
				Sfx.play("lose", -4.0)
		"over":
			pass
	if _phase == "over":
		_keys.set_text("[Väli] Valmis")
	else:
		_keys.set_text("[A] alas  [D] ylös: pumppaa vuorotellen   [←] [→] Kävele   [E] Tutki   [Esc] Lopeta")
	_root.queue_redraw()


func _drain(delta: float, rate: float) -> void:
	_air = maxf(0.0, _air - rate * delta)
	if _air <= 0.0 and _phase != "fail" and _phase != "over":
		_phase = "fail"
		_t = 0.0
		_shake = 0.5
		_say("Ilma loppui! Sukeltaja nostetaan ylös.", 2.4)
		Sfx.play("grunt", -6.0, 0.8)


func _dive_step(delta: float) -> void:
	var dir := 0.0
	if Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	if _dig_t > 0.0:
		dir = 0.0
		_dig_t -= delta
		_drain(delta, AIR_DRAIN_DIG)
		if randf() < delta * 14.0:
			MG.sparks_burst(_sparks, Vector2(_items[_dig_item].x + randf_range(-14.0, 14.0), _bed(_items[_dig_item].x) - 6.0), Color(0.86, 0.78, 0.55), 1)
		if _dig_t <= 0.0:
			_finish_dig()
	elif dir != 0.0:
		_face = dir
		_dx = clampf(_dx + dir * WALK_SPEED * delta, X_MIN, X_MAX)
		_walk_t += delta * 7.0
		_drain(delta, AIR_DRAIN_WALK)
		if randf() < delta * 5.0:
			MG.sparks_burst(_sparks, Vector2(_dx - dir * 14.0, _bed(_dx) - 4.0), Color(0.82, 0.74, 0.52), 1)
	else:
		_drain(delta, AIR_DRAIN)
	# Liian täysi paine kelluttaa pohjalta; matala paine tummentaa kuvan.
	var lift := clampf((_air - 85.0) / 15.0, 0.0, 1.0) * 46.0
	_float = move_toward(_float, lift, 90.0 * delta)
	_dy = _bed(_dx) - _float
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble_t = 0.8 if _air > 30.0 else 0.4
		_bubble_burst(1 + int(randf() * 2.0))
	_danger_t = _danger_t + delta if _air < 22.0 else 0.0
	if _air < 22.0 and fmod(_danger_t, 1.0) < delta:
		Sfx.play("alert", -12.0, 1.6)
		_say("Ilma vähissä! Pumppaa!", 1.0)


func _finish_dig() -> void:
	var it: Dictionary = _items[_dig_item]
	it.done = true
	_shake = 0.4
	var at := Vector2(it.x, _bed(it.x) - 20.0)
	if it.id == WATCH_ID:
		MG.sparks_burst(_sparks, at, Color(1.0, 0.85, 0.3), 26)
		Sfx.play("coin", -2.0)
		_say("Arkun alta kimmeltää: KAPTEENIN TASKUKELLO!", 3.0)
		_phase = "found"
		_t = 0.0
	else:
		_junk += 1
		MG.sparks_burst(_sparks, at, Color(0.8, 0.75, 0.6), 10)
		Sfx.play("pickup", -6.0, 0.7)
		_say({"saapas": "Vanha saapas. Ei kellon omistajan.", "ampari": "Ruosteinen ämpäri. Ei se tämä.",
			"pullo": "Tyhjä pullo. Ei viestiä mukana.", "ankkuri": "Pieni ankkuri. Liian painava, jää pohjaan."}.get(it.id, "Roinaa."), 2.2)
	_dig_item = -1


func _step_bubbles(delta: float) -> void:
	for b in _bubbles:
		b[3] += delta
		b[0] += b[1] * delta + Vector2(sin(b[3] * 4.0 + b[2]) * 14.0 * delta, 0.0)
	for i in range(_bubbles.size() - 1, -1, -1):
		if _bubbles[i][0].y < WATER_Y:
			_bubbles.remove_at(i)


func _step_fish(delta: float) -> void:
	var hp := _helmet()
	for f in _fish:
		f.flee = maxf(0.0, f.flee - delta)
		if _phase == "dive" and absf(f.p.x - _dx) < 110.0 and absf(f.p.y - hp.y) < 140.0 and f.flee <= 0.0:
			f.flee = 1.4
			f.v = signf(f.p.x - _dx) * 130.0
		f.p.x += f.v * delta * (3.0 if f.flee > 0.0 else 1.0)
		f.p.y += sin(_t * 1.5 + f.ph) * 8.0 * delta
		if f.p.x < 40.0 or f.p.x > W - 20.0:
			f.v = -f.v if absf(f.v) > 60.0 else -signf(f.p.x - W / 2.0) * 30.0
			f.p.x = clampf(f.p.x, 41.0, W - 21.0)
		if absf(f.v) > 60.0 and f.flee <= 0.0:
			f.v = signf(f.v) * 36.0


# --- Piirto ---------------------------------------------------------------------------------

func _ellipse(c: CanvasItem, ctr: Vector2, rx: float, ry: float, col: Color, n := 22) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, col)


func _draw_root() -> void:
	var c := _root
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _shake
	c.draw_set_transform(sh)
	_draw_sky(c)
	_draw_water(c)
	_draw_bed(c)
	_draw_pilings(c)
	for i in _items.size():
		if not _items[i].done or _items[i].id == WATCH_ID:
			_draw_item(c, _items[i])
	_draw_weeds(c)
	_draw_fish(c)
	_draw_hose(c)
	_draw_diver(c)
	for b in _bubbles:
		var a := clampf(1.0 - b[3] / 4.0, 0.2, 1.0)
		c.draw_circle(b[0], b[2], Color(0.85, 0.95, 1.0, 0.25 * a))
		c.draw_arc(b[0], b[2], 0, TAU, 10, Color(0.95, 1.0, 1.0, 0.8 * a), 1.2, true)
		c.draw_circle(b[0] - Vector2(b[2] * 0.3, b[2] * 0.3), maxf(b[2] * 0.25, 0.8), Color(1, 1, 1, 0.9 * a))
	MG.sparks_draw(c, _sparks)
	_draw_pier(c)
	_draw_surface(c)
	c.draw_set_transform(Vector2.ZERO)
	_draw_hud(c)


func _draw_sky(c: CanvasItem) -> void:
	MG.grad_rect(c, Rect2(0, 0, W, WATER_Y + 4.0), Color(0.62, 0.8, 0.92), Color(0.97, 0.9, 0.78))
	MG.glow(c, Vector2(1080, 70), 120.0, Color(1.0, 0.95, 0.7, 0.9))
	# Pilvet.
	for k in 3:
		var cx := fposmod(220.0 + k * 430.0 + _t * 6.0, W + 200.0) - 100.0
		for j in 4:
			_ellipse(c, Vector2(cx + j * 34.0, 62.0 + k * 22.0 - (j % 2) * 8.0), 40.0, 15.0, Color(1, 1, 1, 0.7))
	# Vastarannan Kruununmakasiini (vaalea kivitalo, aumakatto) ja puna-aitta.
	var by := WATER_Y - 4.0
	MG.solid(c, Rect2(700, by - 74, 210, 74), Color(0.88, 0.82, 0.66))
	c.draw_colored_polygon(PackedVector2Array([Vector2(690, by - 74), Vector2(920, by - 74), Vector2(890, by - 108), Vector2(720, by - 108)]), Color(0.45, 0.22, 0.18))
	c.draw_polyline(PackedVector2Array([Vector2(690, by - 74), Vector2(720, by - 108), Vector2(890, by - 108), Vector2(920, by - 74)]), INK, 2.0)
	for k in 6:
		MG.solid(c, Rect2(716 + k * 31, by - 58, 16, 26), Color(0.3, 0.38, 0.45), true)
	MG.solid(c, Rect2(788, by - 36, 34, 36), Color(0.4, 0.26, 0.15))
	MG.solid(c, Rect2(930, by - 52, 90, 52), Color(0.66, 0.2, 0.16))
	c.draw_colored_polygon(PackedVector2Array([Vector2(922, by - 52), Vector2(1028, by - 52), Vector2(975, by - 82)]), Color(0.32, 0.2, 0.16))
	MG.sign(c, Rect2(740, by - 100, 130, 22), "KRUUNUNMAKASIINI", Color(0.2, 0.14, 0.09), Color(0.97, 0.9, 0.7), 12, Color(0.78, 0.6, 0.2))
	# Vene laiturin ja makasiinin välissä ja lokit.
	var bob := sin(_t * 1.3) * 3.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(1060, WATER_Y - 22 + bob), Vector2(1180, WATER_Y - 22 + bob), Vector2(1156, WATER_Y + 6 + bob), Vector2(1086, WATER_Y + 6 + bob)]), Color(0.72, 0.14, 0.12))
	c.draw_line(Vector2(1060, WATER_Y - 22 + bob), Vector2(1180, WATER_Y - 22 + bob), Color(0.97, 0.95, 0.9), 4.0)
	c.draw_line(Vector2(1110, WATER_Y - 22 + bob), Vector2(1110, WATER_Y - 96 + bob), INK, 3.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(1112, WATER_Y - 92 + bob), Vector2(1112, WATER_Y - 32 + bob), Vector2(1158, WATER_Y - 34 + bob)]), Color(0.97, 0.95, 0.88))
	for k in 3:
		var gx := fposmod(_t * (22.0 + k * 7.0) + k * 300.0, W + 100.0) - 50.0
		var gy := 36.0 + k * 22.0 + sin(_t * 2.0 + k) * 6.0
		var wing := sin(_t * 7.0 + k) * 5.0
		c.draw_polyline(PackedVector2Array([Vector2(gx - 12, gy - 4 + wing), Vector2(gx, gy), Vector2(gx + 12, gy - 4 + wing)]), INK, 2.0, true)


func _draw_water(c: CanvasItem) -> void:
	MG.grad_rect(c, Rect2(0, WATER_Y, W, H - WATER_Y), Color(0.24, 0.66, 0.72), Color(0.04, 0.16, 0.26))
	# Valonsäteet pinnalta.
	for k in 6:
		var x0 := 120.0 + k * 220.0 + sin(_t * 0.4 + k) * 30.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x0, WATER_Y), Vector2(x0 + 70, WATER_Y), Vector2(x0 + 210, H), Vector2(x0 + 90, H)]), Color(1, 1, 0.8, 0.05))
	# Lietehiukkaset.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 40:
		var px := rng.randf_range(0.0, W)
		var py := fposmod(rng.randf_range(WATER_Y, H) - _t * rng.randf_range(2.0, 9.0), H - WATER_Y) + WATER_Y
		c.draw_circle(Vector2(px + sin(_t + k) * 6.0, py), rng.randf_range(0.8, 1.8), Color(1, 1, 1, 0.22))


func _draw_bed(c: CanvasItem) -> void:
	var pts := PackedVector2Array()
	for x in range(0, int(W) + 20, 20):
		pts.append(Vector2(x, _bed(float(x))))
	var poly := PackedVector2Array(pts)
	poly.append(Vector2(W, H))
	poly.append(Vector2(0, H))
	c.draw_colored_polygon(poly, Color(0.62, 0.55, 0.38))
	c.draw_polyline(pts, Color(0.86, 0.78, 0.55), 5.0, true)
	for k in 6:  # hiekan aallot
		var p2 := PackedVector2Array()
		for x in range(0, int(W) + 20, 20):
			p2.append(Vector2(x, _bed(float(x)) + 18.0 + k * 10.0 + sin(x * 0.03 + k) * 3.0))
		c.draw_polyline(p2, Color(0.5, 0.44, 0.3, 0.5), 2.0, true)
	for s in _stones:
		var sx: float = s[0]
		_ellipse(c, Vector2(sx, _bed(sx) + 4.0), s[1], s[1] * 0.55, Color(0.34, 0.33, 0.34).lightened(s[2] * 0.2))
		c.draw_arc(Vector2(sx, _bed(sx) + 2.0), s[1] * 0.8, PI * 1.1, PI * 1.6, 8, Color(0.65, 0.65, 0.66, 0.6), 2.0)
	# Matalan syvyyden tummennus.
	MG.grad_rect(c, Rect2(0, 420, W, H - 420), Color(0, 0.05, 0.12, 0.0), Color(0, 0.05, 0.12, 0.35))


func _draw_pilings(c: CanvasItem) -> void:
	for px in [90.0, 250.0, 400.0, LADDER_X + 24.0]:
		var bot := _bed(px) + 14.0
		MG.grad_rect(c, Rect2(px - 14, WATER_Y, 28, bot - WATER_Y), Color(0.34, 0.26, 0.17), Color(0.12, 0.1, 0.08))
		c.draw_rect(Rect2(px - 14, WATER_Y, 28, bot - WATER_Y), INK, false, 2.0)
		for k in 10:  # merenkuoriaiset ja levä
			c.draw_circle(Vector2(px - 8.0 + (k % 3) * 8.0, WATER_Y + 30.0 + k * 38.0), 3.0, Color(0.75, 0.75, 0.7, 0.8))
		c.draw_line(Vector2(px - 14, WATER_Y + 80), Vector2(px - 18, WATER_Y + 150), Color(0.25, 0.5, 0.25), 4.0)
	for k in 2:  # poikkipalkit
		c.draw_rect(Rect2(76, WATER_Y + 80.0 + k * 150.0, LADDER_X - 52.0, 10), Color(0.28, 0.2, 0.13))
	# Tikkaat.
	for sx in [LADDER_X - 10.0, LADDER_X + 10.0]:
		c.draw_line(Vector2(sx, WATER_Y - 20), Vector2(sx, WATER_Y + 190), Color(0.45, 0.45, 0.48), 4.0)
	for k in 6:
		c.draw_line(Vector2(LADDER_X - 10.0, WATER_Y + 4.0 + k * 34.0), Vector2(LADDER_X + 10.0, WATER_Y + 4.0 + k * 34.0), Color(0.55, 0.55, 0.58), 4.0)


func _draw_weeds(c: CanvasItem) -> void:
	for w in _weeds:
		var wx: float = w[0]
		var base := Vector2(wx, _bed(wx) + 4.0)
		var pts := PackedVector2Array()
		for k in 6:
			var t := k / 5.0
			pts.append(base + Vector2(sin(_t * 1.2 + w[1] + t * 2.0) * 10.0 * t, -w[2] * t))
		c.draw_polyline(pts, Color(0.12, 0.34, 0.2), 6.0, true)
		c.draw_polyline(pts, Color(0.28, 0.56, 0.3), 3.0, true)


func _draw_fish(c: CanvasItem) -> void:
	for f in _fish:
		var d := signf(f.v) if f.v != 0.0 else 1.0
		var s: float = f.s
		var p: Vector2 = f.p
		var body := Color(0.42, 0.5, 0.2)  # ahven: vihertävä selkä, tummat raidat, punaiset evät
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-d * 16, 0) * s, p + Vector2(-d * 30, -9 + sin(_t * 9.0 + f.ph) * 3.0) * s, p + Vector2(-d * 30, 9 + sin(_t * 9.0 + f.ph) * 3.0) * s]), Color(0.8, 0.3, 0.2))
		_ellipse(c, p, 19.0 * s, 9.0 * s, body)
		_ellipse(c, p + Vector2(0, 3) * s, 17.0 * s, 5.0 * s, Color(0.9, 0.85, 0.55))
		for k in 3:
			c.draw_line(p + Vector2(d * (6 - k * 7), -8) * s, p + Vector2(d * (6 - k * 7), 4) * s, Color(0.15, 0.2, 0.08), 2.5 * s)
		c.draw_circle(p + Vector2(d * 12, -2) * s, 2.5 * s, Color.WHITE)
		c.draw_circle(p + Vector2(d * 12.5, -2) * s, 1.2 * s, INK)


func _draw_item(c: CanvasItem, it: Dictionary) -> void:
	var x: float = it.x
	var y := _bed(x) + 2.0
	var near := absf(_dx - x) < REACH and _phase == "dive"
	match it.id:
		"saapas":
			MG.solid(c, Rect2(x - 12, y - 40, 22, 38), Color(0.32, 0.22, 0.14))
			MG.solid(c, Rect2(x - 14, y - 14, 46, 14), Color(0.28, 0.19, 0.12))
			c.draw_line(Vector2(x - 12, y - 28), Vector2(x + 10, y - 28), Color(0.5, 0.4, 0.28), 2.0)
			c.draw_rect(Rect2(x - 14, y - 3, 46, 3), Color(0.12, 0.1, 0.08))
		"ampari":
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 20, y - 36), Vector2(x + 20, y - 36), Vector2(x + 15, y), Vector2(x - 15, y)]), Color(0.52, 0.34, 0.2))
			c.draw_polyline(PackedVector2Array([Vector2(x - 20, y - 36), Vector2(x - 15, y), Vector2(x + 15, y), Vector2(x + 20, y - 36)]), INK, 2.0)
			_ellipse(c, Vector2(x, y - 36), 20.0, 5.0, Color(0.22, 0.14, 0.1))
			c.draw_arc(Vector2(x, y - 38), 18.0, PI, TAU, 10, Color(0.4, 0.4, 0.4), 2.5)
			c.draw_line(Vector2(x - 14, y - 20), Vector2(x - 10, y - 8), Color(0.8, 0.45, 0.15), 3.0)  # ruostetta
		"pullo":
			c.draw_line(Vector2(x - 20, y - 8), Vector2(x + 14, y - 14), Color(0.35, 0.65, 0.4, 0.9), 14.0)
			c.draw_line(Vector2(x + 14, y - 14), Vector2(x + 28, y - 16), Color(0.35, 0.65, 0.4, 0.9), 6.0)
			c.draw_line(Vector2(x - 18, y - 12), Vector2(x + 6, y - 16), Color(1, 1, 1, 0.5), 2.0)
		"ankkuri":
			c.draw_line(Vector2(x, y - 62), Vector2(x, y - 6), Color(0.3, 0.3, 0.32), 7.0)
			c.draw_arc(Vector2(x, y - 20), 28.0, 0.15, PI - 0.15, 12, Color(0.3, 0.3, 0.32), 7.0)
			c.draw_line(Vector2(x - 14, y - 52), Vector2(x + 14, y - 52), Color(0.3, 0.3, 0.32), 6.0)
			c.draw_arc(Vector2(x, y - 68), 6.0, 0, TAU, 10, Color(0.4, 0.4, 0.42), 3.0)
			c.draw_line(Vector2(x - 24, y - 26), Vector2(x - 20, y - 8), Color(0.65, 0.4, 0.15), 3.0)
		WATCH_ID:
			# Uponnut puuarkku: kansi raollaan, kulta kimaltaa raosta.
			MG.solid(c, Rect2(x - 34, y - 34, 68, 36), Color(0.42, 0.28, 0.16))
			for k in 3:
				c.draw_line(Vector2(x - 34, y - 24 + k * 10), Vector2(x + 34, y - 24 + k * 10), Color(0.25, 0.16, 0.1), 2.0)
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 36, y - 34), Vector2(x + 36, y - 34), Vector2(x + 30, y - 48), Vector2(x - 24, y - 52)]), Color(0.36, 0.24, 0.14))
			c.draw_polyline(PackedVector2Array([Vector2(x - 36, y - 34), Vector2(x - 24, y - 52), Vector2(x + 30, y - 48), Vector2(x + 36, y - 34)]), INK, 2.0)
			c.draw_rect(Rect2(x - 28, y - 37, 56, 4), Color(0.02, 0.02, 0.03))
			var shown: bool = it.done or absf(_dx - x) < 260.0 or sin(_t * 2.0) > 0.7
			if it.done:
				MG.ball(c, Vector2(x, y - 62.0), 13.0, Color(0.96, 0.78, 0.22), 0.7)
				c.draw_arc(Vector2(x, y - 62), 8.0, 0, TAU, 12, Color(0.55, 0.4, 0.08), 1.5)
				c.draw_line(Vector2(x, y - 62), Vector2(x, y - 70), Color(0.55, 0.4, 0.08), 2.0)
			elif shown:
				var g := 0.5 + 0.5 * sin(_t * 5.0)
				MG.glow(c, Vector2(x, y - 34), 26.0 + 10.0 * g, Color(1.0, 0.9, 0.4, 0.8))
				c.draw_line(Vector2(x - 9 - 4 * g, y - 34), Vector2(x + 9 + 4 * g, y - 34), Color(1, 1, 0.8, 0.9), 2.0)
				c.draw_line(Vector2(x, y - 43 - 4 * g), Vector2(x, y - 25 + 4 * g), Color(1, 1, 0.8, 0.9), 2.0)
	if near and not it.done:
		MG.sign(c, Rect2(x - 28, y - 112 + sin(_t * 4.0) * 3.0, 56, 28), "E", Color(0.2, 0.14, 0.09), Color(1.0, 0.93, 0.6), 22, Color(0.78, 0.6, 0.2))


## Letku pumpun ulostulosta laiturin reunan yli veteen ja sukeltajan kypärän takaosaan; kierteiset renkaat ja kiilto.
func _hose_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	var p0 := Vector2(412.0, WATER_Y - 8.0)
	var p1 := Vector2(PIER_END - 6.0, WATER_Y - 10.0)
	var h := _helmet() + Vector2(-_face * 22.0, 6.0)
	out.append(p0)
	out.append(p1)
	var ctrl := Vector2((p1.x + h.x) / 2.0 + 20.0, maxf(p1.y, h.y) + 70.0 + absf(h.x - p1.x) * 0.15)
	for k in range(1, 21):
		var t := k / 20.0
		out.append(p1.lerp(ctrl, t).lerp(ctrl.lerp(h, t), t))
	return out


func _draw_hose(c: CanvasItem) -> void:
	var pts := _hose_points()
	c.draw_polyline(pts, Color(0.06, 0.07, 0.07, 0.9), 9.0, true)
	c.draw_polyline(pts, Color(0.22, 0.26, 0.2), 6.0, true)
	for i in range(1, pts.size() - 1, 2):  # kierteen renkaat
		var d := (pts[i + 1] - pts[i - 1]).normalized().orthogonal()
		c.draw_line(pts[i] - d * 4.0, pts[i] + d * 4.0, Color(0.1, 0.12, 0.1), 1.5)
	c.draw_polyline(pts, Color(0.5, 0.58, 0.45, 0.35), 1.5, true)


func _draw_diver(c: CanvasItem) -> void:
	var f := _face
	var o := Vector2(_dx, _dy)
	var step := sin(_walk_t) * 9.0 if _dig_t <= 0.0 else 0.0
	var moving := _phase == "dive" and _dig_t <= 0.0 and (Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT))
	if not moving:
		step = 0.0
	var crouch := 10.0 if _dig_t > 0.0 else 0.0
	var bob := sin(_t * 2.0) * 2.0 if _phase != "dive" or _float > 2.0 else 0.0
	o.y += bob
	# Varjo pohjalla.
	if _phase == "dive":
		_ellipse(c, Vector2(_dx, _bed(_dx) + 3.0), 34.0 - _float * 0.3, 7.0, Color(0, 0, 0, 0.3))
	# Jalat: lyijykengät ja kangashousut.
	for leg in [-1.0, 1.0]:
		var lx: float = o.x + f * leg * 6.0 + step * leg * f
		var lift: float = maxf(0.0, step * leg * f) * 0.5
		c.draw_line(Vector2(o.x + f * leg * 4.0, o.y - 56.0 + crouch), Vector2(lx, o.y - 16.0 - lift + crouch * 0.3), CANVAS.darkened(0.15 if leg > 0.0 else 0.28), 17.0)
		var boot := Rect2(lx - 12.0 + f * 5.0 - (0.0 if f > 0.0 else 0.0), o.y - 16.0 - lift, 28.0, 16.0)
		if f < 0.0:
			boot.position.x = lx - 16.0
		MG.solid(c, boot, Color(0.36, 0.37, 0.4).darkened(0.1 if leg > 0.0 else 0.25))
		c.draw_line(boot.position + Vector2(2, 6), boot.position + Vector2(boot.size.x - 2, 6), COPPER.darkened(0.2), 2.5)
	# Vartalo: kangaspuku, rintalevy, vyö ja lyijypainot.
	var tor := Rect2(o.x - 19.0, o.y - 108.0 + crouch, 38.0, 56.0)
	MG.box(c, tor, CANVAS, 12, 0, INK, 2)
	MG.grad_rect(c, Rect2(tor.position + Vector2(3, 3), Vector2(tor.size.x - 6, 12)), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.0))
	c.draw_line(tor.position + Vector2(2, 36), tor.position + Vector2(tor.size.x - 2, 36), Color(0.3, 0.2, 0.12), 5.0)
	for wx in [-12.0, 12.0]:
		MG.solid(c, Rect2(o.x + wx - 5.0, o.y - 80.0 + crouch, 10.0, 14.0), Color(0.5, 0.52, 0.55))
	_ellipse(c, Vector2(o.x, o.y - 106.0 + crouch), 25.0, 10.0, COPPER.darkened(0.1))  # rintalevy
	c.draw_arc(Vector2(o.x, o.y - 106.0 + crouch), 25.0, 0.1, PI - 0.1, 14, COPPER.lightened(0.25), 2.0)
	for k in 6:  # niitit
		c.draw_circle(Vector2(o.x - 20.0 + k * 8.0, o.y - 105.0 + crouch + (absf(k - 2.5) - 2.5) * -1.6), 1.8, COPPER.lightened(0.5))
	# Kädet: eteen ja alas, kaivettaessa maahan.
	var hand_t := Vector2(o.x + f * 34.0, o.y - 64.0 + crouch + (24.0 if _dig_t > 0.0 else 0.0) + sin(_walk_t) * 6.0 * (1.0 if moving else 0.0))
	var sho := Vector2(o.x + f * 2.0, o.y - 98.0 + crouch)
	c.draw_line(sho, hand_t, CANVAS.darkened(0.18), 14.0)
	c.draw_line(sho, hand_t, CANVAS.darkened(0.08), 10.0)
	c.draw_circle(hand_t, 8.0, Color(0.3, 0.22, 0.16))
	c.draw_arc(hand_t, 8.0, 0, TAU, 10, INK, 1.5)
	# Kypärä: kuparipallo, kolme lasia (edessä, sivu, ylä), kaulus ja ilmaletkun liitin.
	var hc := Vector2(o.x, o.y - 128.0 + crouch)
	c.draw_circle(hc + Vector2(2, 3), 27.0, Color(0, 0, 0, 0.25))
	c.draw_circle(hc, 26.0, COPPER.darkened(0.35))
	c.draw_circle(hc - Vector2(1.5, 2.0), 24.0, COPPER)
	c.draw_circle(hc - Vector2(8.0, 10.0), 9.0, COPPER.lightened(0.35))
	c.draw_arc(hc, 26.0, 0, TAU, 28, INK, 2.0, true)
	var win := hc + Vector2(f * 12.0, -2.0)  # etulasi
	c.draw_circle(win, 11.0, COPPER.darkened(0.4))
	c.draw_circle(win, 8.5, Color(0.1, 0.22, 0.28))
	c.draw_arc(win, 11.0, 0, TAU, 14, COPPER.lightened(0.3), 1.5, true)
	c.draw_circle(win - Vector2(2.5, 3.0), 3.0, Color(0.8, 0.95, 1.0, 0.85))
	var win2 := hc + Vector2(-f * 2.0, -2.0)  # sivulasi
	c.draw_circle(win2, 6.0, COPPER.darkened(0.4))
	c.draw_circle(win2, 4.2, Color(0.1, 0.22, 0.28))
	c.draw_circle(hc + Vector2(f * 2.0, -20.0), 4.5, Color(0.1, 0.22, 0.28))  # yläcasi
	c.draw_arc(hc + Vector2(f * 2.0, -20.0), 5.5, 0, TAU, 10, COPPER.lightened(0.2), 1.2)
	MG.ball(c, hc + Vector2(-f * 25.0, 6.0), 6.0, COPPER.darkened(0.15), 0.4)  # letkun liitin takana
	MG.ball(c, hc + Vector2(f * 17.0, 17.0), 4.5, COPPER.lightened(0.1), 0.4)  # poistoventtiili


func _draw_pier(c: CanvasItem) -> void:
	# Kansi: lankut ja reunapalkki.
	MG.wood(c, Rect2(0, WATER_Y - 6.0, PIER_END, 26.0), Color(0.56, 0.4, 0.24), 26.0, 4, false)
	c.draw_rect(Rect2(0, WATER_Y - 6.0, PIER_END, 5.0), Color(0.78, 0.6, 0.38))
	c.draw_rect(Rect2(0, WATER_Y + 14.0, PIER_END, 6.0), Color(0.2, 0.14, 0.09))
	# Pollari reunalla.
	MG.solid(c, Rect2(PIER_END - 30.0, WATER_Y - 28.0, 18.0, 24.0), Color(0.25, 0.27, 0.3))
	_draw_pump(c)
	_draw_pumper(c)
	# Näppäinhatut A ja D (seuraava vuoro hehkuu).
	for k in 2:
		var key := "a" if k == 0 else "d"
		var next := _last_key != key and _phase != "over"
		var r := Rect2(46.0 + k * 62.0, 78.0, 48.0, 44.0)
		if next:
			MG.glow(c, r.get_center(), 46.0 + sin(_t * 8.0) * 5.0, Color(1.0, 0.9, 0.4, 0.8))
		MG.box(c, r, Color(0.95, 0.93, 0.86) if next else Color(0.7, 0.68, 0.62), 8, 3, INK, 2)
		c.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 32), key.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, INK)
		c.draw_string(ThemeDB.fallback_font, r.position + Vector2(-14, 62), "alas" if k == 0 else "ylös", HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 28.0, 18, Color(0.15, 0.1, 0.06))


## Keinuvipupumppu (sivuprofiili): puurunko, kaksi messinkisylinteriä, kaksoisvipu ja painemittari. Vivun vasen pää on pumppaajan puolella.
func _pump_beam_end(side: float) -> Vector2:
	return Vector2(334.0, WATER_Y - 74.0) + Vector2(cos(_beam * 0.30), sin(_beam * 0.30)) * 84.0 * side


func _draw_pump(c: CanvasItem) -> void:
	var base := Rect2(286.0, WATER_Y - 40.0, 126.0, 34.0)
	MG.solid(c, base, Color(0.5, 0.34, 0.2))
	MG.solid(c, Rect2(304.0, WATER_Y - 74.0, 60.0, 36.0), Color(0.46, 0.3, 0.18))
	# Sylinterit ja männänvarret vivun päiden alla.
	for side in [-1.0, 1.0]:
		var e := _pump_beam_end(side)
		var cx: float = 334.0 + 50.0 * side
		MG.grad_rect(c, Rect2(cx - 11.0, WATER_Y - 62.0, 22.0, 40.0), Color(0.95, 0.78, 0.3), Color(0.6, 0.42, 0.12))
		c.draw_rect(Rect2(cx - 11.0, WATER_Y - 62.0, 22.0, 40.0), INK, false, 2.0)
		c.draw_line(Vector2(cx, e.y + 6.0), Vector2(cx, WATER_Y - 62.0), Color(0.78, 0.8, 0.82), 4.0)
		c.draw_line(Vector2(cx - 3.0, WATER_Y - 54.0), Vector2(cx - 3.0, WATER_Y - 30.0), Color(1, 1, 0.8, 0.5), 2.0)
		c.draw_circle(Vector2(cx, e.y + 6.0), 4.0, Color(0.5, 0.52, 0.55))
	# Pylväs ja vipu.
	c.draw_line(Vector2(334.0, WATER_Y - 40.0), Vector2(334.0, WATER_Y - 74.0), Color(0.3, 0.2, 0.12), 10.0)
	var a := _pump_beam_end(-1.0)
	var b := _pump_beam_end(1.0)
	c.draw_line(a, b, INK, 12.0)
	c.draw_line(a, b, Color(0.55, 0.38, 0.22), 8.0)
	c.draw_line(a + Vector2(0, -2), b + Vector2(0, -2), Color(0.78, 0.6, 0.38), 2.0)
	MG.ball(c, Vector2(334.0, WATER_Y - 74.0), 8.0, COPPER, 0.5)
	# Kahvat (poikkipuut) vivun päissä; vasen on pumppaajan käsissä.
	c.draw_line(a + Vector2(0, -12), a + Vector2(0, 12), Color(0.3, 0.2, 0.12), 6.0)
	c.draw_line(b + Vector2(0, -12), b + Vector2(0, 12), Color(0.3, 0.2, 0.12), 6.0)
	# Painemittari pumpun päällä ja ulostulo.
	MG.ball(c, Vector2(384.0, WATER_Y - 54.0), 15.0, Color(0.95, 0.9, 0.78), 0.3)
	c.draw_line(Vector2(384.0, WATER_Y - 54.0), Vector2(384.0, WATER_Y - 54.0) + Vector2(0, -11).rotated(lerpf(-2.2, 2.2, _air / 100.0)), Color(0.7, 0.1, 0.08), 2.0)
	c.draw_rect(Rect2(404.0, WATER_Y - 16.0, 12.0, 10.0), COPPER)
	c.draw_arc(Vector2(334.0, WATER_Y - 20.0), 5.0, 0, TAU, 8, COPPER, 2.0)


## Pumppaaja sivusta (katsoo oikealle, kohti pumppua): lippalakki, parta, sininen työpaita; kädet vivun vasemmassa päässä.
func _draw_pumper(c: CanvasItem) -> void:
	var grip := _pump_beam_end(-1.0)
	var lean := _beam * 7.0  # kumartuu työntäessä
	var feet := Vector2(206.0, WATER_Y - 6.0)
	var hip := feet + Vector2(0, -52)
	var sh := hip + Vector2(lean * 0.6, -62.0 + absf(lean) * 0.2)
	var head := sh + Vector2(lean * 0.5 + 6.0, -34.0)
	# Jalat.
	for leg in [-1.0, 1.0]:
		var foot := feet + Vector2(leg * 14.0, 0)
		c.draw_line(hip, foot + Vector2(0, -12), Color(0.28, 0.27, 0.32).darkened(0.12 if leg > 0.0 else 0.0), 18.0)
		MG.solid(c, Rect2(foot.x - 10.0, foot.y - 12.0, 30.0, 12.0), Color(0.15, 0.1, 0.08))
	# Vartalo.
	var tp := PackedVector2Array([hip + Vector2(-17, 0), hip + Vector2(17, 0), sh + Vector2(15, 4), sh + Vector2(-17, 4)])
	c.draw_colored_polygon(tp, Color(0.28, 0.42, 0.62))
	c.draw_polyline(PackedVector2Array([tp[0], tp[3], tp[2], tp[1]]), INK, 2.0)
	c.draw_line(hip + Vector2(-17, -4), hip + Vector2(17, -4), Color(0.25, 0.16, 0.1), 5.0)  # vyö
	# Kädet: takakäsi tummempi.
	for arm in [0, 1]:
		var s := sh + Vector2(2.0 + arm * 4.0, 8.0)
		var g := grip + Vector2(arm * 7.0 - 3.0, 2.0)
		var elbow := (s + g) / 2.0 + Vector2(-8.0, 22.0)
		var col := Color(0.2, 0.32, 0.5) if arm == 0 else Color(0.28, 0.42, 0.62)
		c.draw_polyline(PackedVector2Array([s, elbow, g]), INK, 15.0, true)
		c.draw_polyline(PackedVector2Array([s, elbow, g]), col, 11.0, true)
		c.draw_circle(g, 7.0, Color(0.93, 0.74, 0.62))
		c.draw_arc(g, 7.0, 0, TAU, 10, INK, 1.5)
	# Pää: kaula, kasvot, parta, lippalakki.
	c.draw_circle(head + Vector2(1, 3), 22.0, Color(0, 0, 0, 0.22))
	c.draw_circle(head, 21.0, Color(0.93, 0.74, 0.62))
	c.draw_arc(head + Vector2(8, 6), 17.0, 0.2, PI * 0.8, 10, Color(0.8, 0.8, 0.78), 9.0)  # harmaa parta
	c.draw_circle(head + Vector2(10, -3), 3.0, Color.WHITE)
	c.draw_circle(head + Vector2(11, -3), 1.5, INK)
	c.draw_line(head + Vector2(4, -9), head + Vector2(15, -8), Color(0.5, 0.5, 0.5), 2.5)
	c.draw_line(head + Vector2(18, 1), head + Vector2(22, 4), Color(0.8, 0.6, 0.5), 3.0)
	c.draw_colored_polygon(PackedVector2Array([head + Vector2(-22, -6), head + Vector2(20, -6), head + Vector2(16, -22), head + Vector2(-4, -26), head + Vector2(-20, -20)]), Color(0.18, 0.2, 0.26))
	c.draw_rect(Rect2(head + Vector2(10, -10), Vector2(26, 5)), Color(0.12, 0.14, 0.18))
	c.draw_circle(head + Vector2(-2, -16), 2.5, Color(0.85, 0.8, 0.4))
	# Hiki ja rasitus: pumppaajan pää punertuu, kun ilma on vähissä.


func _draw_surface(c: CanvasItem) -> void:
	# Pinta aaltoilee ja peittää laiturin alaosan sekä sukeltajan yläpuolen läpikuultavasti.
	var pts := PackedVector2Array()
	for x in range(0, int(W) + 10, 10):
		pts.append(Vector2(x, WATER_Y + sin(x * 0.04 + _t * 2.0) * 2.5))
	c.draw_polyline(pts, Color(0.9, 1.0, 1.0, 0.8), 3.0, true)
	var poly := PackedVector2Array(pts)
	poly.append(Vector2(W, WATER_Y + 26.0))
	poly.append(Vector2(0, WATER_Y + 26.0))
	c.draw_colored_polygon(poly, Color(0.4, 0.8, 0.85, 0.2))


func _draw_hud(c: CanvasItem) -> void:
	# Painemittari: messinkikehys, vihreä alue (30-80), punainen alue (alle 20) ja viisari.
	var gc := Vector2(1170.0, 86.0)
	MG.box(c, Rect2(gc + Vector2(-82, -66), Vector2(164, 168)), Color(0.34, 0.23, 0.14), 14, 6, INK, 2)
	MG.ball(c, gc, 60.0, COPPER.lightened(0.15), 0.3)
	c.draw_circle(gc, 52.0, Color(0.96, 0.93, 0.82))
	var a0 := deg_to_rad(-220.0)
	var span := deg_to_rad(260.0)
	var arc_at := func(v: float) -> float: return a0 + span * v / 100.0
	c.draw_arc(gc, 42.0, arc_at.call(0.0), arc_at.call(20.0), 8, Color(0.8, 0.15, 0.1), 7.0)
	c.draw_arc(gc, 42.0, arc_at.call(30.0), arc_at.call(80.0), 14, Color(0.2, 0.65, 0.25), 7.0)
	c.draw_arc(gc, 42.0, arc_at.call(88.0), arc_at.call(100.0), 8, Color(0.8, 0.5, 0.1), 7.0)
	for k in 11:
		var an: float = arc_at.call(k * 10.0)
		c.draw_line(gc + Vector2.from_angle(an) * 46.0, gc + Vector2.from_angle(an) * 52.0, INK, 2.0)
	var wob := sin(_t * 30.0) * 0.015 if _air < 22.0 else 0.0
	var na: float = arc_at.call(_air) + wob
	c.draw_line(gc, gc + Vector2.from_angle(na) * 44.0, Color(0.7, 0.08, 0.06), 4.0)
	c.draw_circle(gc, 6.0, INK)
	c.draw_string(ThemeDB.fallback_font, gc + Vector2(-50, 30), "ILMA", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 18, Color(0.3, 0.2, 0.12))
	c.draw_string(ThemeDB.fallback_font, gc + Vector2(-80, 96), "Roina %d/4" % _junk, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 22, Color(1.0, 0.93, 0.7))
	if _air < 22.0 and _phase != "over":  # pimeä reunoilta, kun ilma on vähissä
		var k := (0.5 + 0.5 * sin(_t * 8.0)) * 0.22
		c.draw_rect(Rect2(0, 0, W, H), Color(0.6, 0.05, 0.05, k))
	if _msg_t > 0.0 and _phase != "over":
		MG.sign(c, Rect2(260, 20, 760, 56), _msg, Color(0.97, 0.93, 0.8), INK, 28, Color(0.78, 0.6, 0.2))
	if _phase == "over":
		var al := minf(_t / 0.5, 1.0)
		c.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5 * al))
		var txt := "LÖYTYI!\nKapteenin taskukello\n[Väli] Jatka" if _won else "ILMA LOPPUI\nPumppaa vuorotellen A ja D\n[Väli] Jatka"
		MG.sign(c, Rect2(340, 230, 600, 220), txt, Color(0.2, 0.14, 0.09), Color(1, 0.93, 0.6), 46, Color(0.78, 0.6, 0.2))
