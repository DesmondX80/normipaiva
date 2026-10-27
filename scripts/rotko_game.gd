extends CanvasLayer
## Hiidenportin rotko (#250 P13): kiipeä rotkon seinää otteesta toiseen. Klikkaa ote kättesi ulottuvilla (raja REACH). Jokainen ote ja roikkuminen
## kuluttaa voimia; tasanteella (puinen lepolava) voimat palautuvat. Löystyvä (punertava) ote murtuu hetkessä. Humala (drunk 0..1) lisää
## lipsumista. Putoaminen palauttaa viimeiseen tasanteeseen. Ylin lava = perillä.
## finished(top: bool, falls: int): päästiinkö ylös, putoamiset. Esc lopettaa kesken.

signal finished(top: bool, falls: int)

const MG := preload("res://scripts/mg_draw.gd")
const W := 1280.0
const H := 720.0
const INK := Color(0.1, 0.08, 0.06)
const REACH := 170.0
const STAGE_H := 520.0  # tasanteiden väli (ylöspäin)
const STAGES := 3
const HOLDS_PER := 4

var drunk := 0.0
var _t := 0.0
var _holds: Array = []  # {p: Vector2 (maailma, y ylös negatiivinen), landing: bool, loose: bool, hang: float}
var _cur := 0  # nykyinen ote (indeksi _holds)
var _last_landing := 0
var _stamina := 1.0
var _cam := 0.0
var _falls := 0
var _fall_t := 0.0
var _fall_from := Vector2.ZERO
var _fall_to := Vector2.ZERO
var _msg := ""
var _msg_t := 0.0
var _sparks: Array = []
var _mouse := Vector2(W / 2.0, H / 2.0)
var _top := false
var _finished := false
var _root: Control
var _keys: Control


func _ready() -> void:
	add_to_group("esc_lopettaa")
	CamCtl.free_mouse = true  # muuten kameraohjain lukitsee hiiren takaisin eikä etsin/ote seuraa kursoria
	layer = 6
	_build_holds()
	_cam = _holds[0].p.y
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
	_say("Klikkaa ote ulottuvilta. Punertava murtuu.", 3.5)


## Otteet maailmassa: tasanteet kerroksen välein ja niiden välissä siksak-otteet. Lähes kaikki otteet ovat ulottuvilla edellisestä.
func _build_holds() -> void:
	_holds.append({"p": Vector2(W / 2.0, 0.0), "landing": true, "loose": false, "hang": 0.0})
	for s in STAGES:
		var base := -STAGE_H * s
		for k in HOLDS_PER:
			var x := W / 2.0 + (1.0 if (k + s) % 2 == 0 else -1.0) * (35.0 + (k * 37 + s * 53) % 30)
			var y := base - (k + 1) * (STAGE_H / (HOLDS_PER + 1.0))
			_holds.append({"p": Vector2(x, y), "landing": false, "loose": (k == 2 and s > 0), "hang": 0.0})
		_holds.append({"p": Vector2(W / 2.0, -STAGE_H * (s + 1)), "landing": true, "loose": false, "hang": 0.0})


func _input(ev: InputEvent) -> void:
	if _finished:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ESCAPE or ev.keycode == KEY_F or (_top and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_E)):
			_end()
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		_mouse = _root.get_local_mouse_position()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = _root.get_local_mouse_position()
		if _top:
			_end()
		else:
			_grab(_mouse)


func _exit_tree() -> void:
	CamCtl.free_mouse = false


func _end() -> void:
	if _finished:
		return
	_finished = true
	finished.emit(_top, _falls)
	queue_free()


func _say(t: String, d := 2.0) -> void:
	_msg = t
	_msg_t = d


func _screen(p: Vector2) -> Vector2:
	return Vector2(p.x, p.y - _cam + H * 0.6)


func _grab(at: Vector2) -> void:
	if _fall_t > 0.0 or _top:
		return
	var cur: Vector2 = _holds[_cur].p
	var best := -1
	var bd := 40.0  # napsautuksen tarkkuus
	for i in _holds.size():
		if i == _cur:
			continue
		var p: Vector2 = _holds[i].p
		if p.distance_to(cur) > REACH:
			continue
		var d := _screen(p).distance_to(at)
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return
	_cur = best
	_stamina -= 0.1
	Sfx.play("door_close", -14.0, 1.3 + randf() * 0.3)
	MG.sparks_burst(_sparks, _screen(_holds[best].p), Color(0.8, 0.78, 0.7), 5)
	if _holds[best].landing:
		_last_landing = best
		if best == _holds.size() - 1:
			_top = true
			_say("Ylhäällä! Klikkaa tai paina Väli.", 99.0)
			MG.sparks_burst(_sparks, _screen(_holds[best].p) + Vector2(0, -60), Color(1.0, 0.9, 0.4), 28)
			Sfx.play("win_small", -6.0)
		else:
			_say("Lepolava. Voimat palautuvat.", 1.8)
	elif randf() < 0.06 + drunk * 0.35:
		_fall("Käsi lipesi!")


func _fall(why: String) -> void:
	_falls += 1
	_fall_t = 0.9
	_fall_from = _holds[_cur].p
	_fall_to = _holds[_last_landing].p
	_cur = _last_landing
	_stamina = 1.0
	for h in _holds:
		h.hang = 0.0
	_say("%s Putosit lavalle." % why, 2.2)
	Sfx.play("alert", -8.0, 0.5)


func _process(delta: float) -> void:
	if _finished:
		return
	delta = minf(delta, 0.05)
	_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	MG.sparks_step(_sparks, delta)
	var focus: float = _holds[_cur].p.y
	if _fall_t > 0.0:
		_fall_t -= delta
		focus = lerpf(_fall_to.y, _fall_from.y, clampf(_fall_t / 0.9, 0.0, 1.0))
	_cam = lerpf(_cam, focus, minf(1.0, delta * 5.0))
	if _fall_t <= 0.0 and not _top:
		var h: Dictionary = _holds[_cur]
		if h.landing:
			_stamina = minf(1.0, _stamina + delta * 0.5)
		else:
			_stamina -= delta * (0.07 + drunk * 0.06)
			h.hang += delta
			if h.loose and h.hang > 1.1:
				_fall("Ote murtui!")
			elif _stamina <= 0.0:
				_fall("Voimat loppuivat!")
	_keys.set_text("[Klikkaus] Tartu otteeseen   [Esc] Lopeta" if not _top else "[Väli] Valmis")
	_root.queue_redraw()


# --- Piirto -------------------------------------------------------------------------------

func _draw_climber(c: Vector2, fall: float) -> void:
	var s := 1.0
	var shirt := Color(0.75, 0.3, 0.2)
	var tilt := fall * 0.5
	MG.box(_root, Rect2(c + Vector2(-22, -10), Vector2(44, 62)), shirt, 14, 0, INK, 2)  # selkä
	_root.draw_circle(c + Vector2(0, -26), 17.0 * s, Color(0.96, 0.78, 0.68))  # pää
	_root.draw_circle(c + Vector2(0, -32), 17.0 * s, Color(0.35, 0.25, 0.15))  # hiukset (takaa)
	_root.draw_circle(c + Vector2(0, -22), 14.0 * s, Color(0.96, 0.78, 0.68))
	for sx in [-1.0, 1.0]:
		var hand := c + Vector2(sx * (30.0 + 8.0 * sin(_t * 2.0 + sx)), -44.0 + tilt * 30.0)
		_root.draw_line(c + Vector2(sx * 20, -2), hand, shirt.darkened(0.1), 12.0)
		_root.draw_circle(hand, 8.0, Color(0.96, 0.78, 0.68))
		_root.draw_line(c + Vector2(sx * 10, 52), c + Vector2(sx * 22, 92), Color(0.25, 0.28, 0.4), 13.0)  # jalat
		_root.draw_circle(c + Vector2(sx * 22, 96), 8.0, Color(0.12, 0.1, 0.08))


func _draw_root() -> void:
	# Rotkon seinä: harmaa kallio, halkeamia, sammalta, kapea taivas ylhäällä.
	MG.grad_rect(_root, Rect2(0, 0, W, H), Color(0.42, 0.42, 0.44), Color(0.26, 0.27, 0.3))
	var off := fmod(-_cam, 160.0)
	for i in 9:
		var y := off + (i - 1) * 160.0
		_root.draw_line(Vector2(80 + (i * 97) % 300, y), Vector2(320 + (i * 61) % 400, y + 90), Color(0.2, 0.2, 0.22), 3.0)
		_root.draw_line(Vector2(W - 120 - (i * 71) % 260, y + 40), Vector2(W - 380 - (i * 43) % 200, y + 130), Color(0.2, 0.2, 0.22), 3.0)
		_root.draw_circle(Vector2(140 + (i * 211) % 1000, y + 70), 34.0, Color(0.28, 0.4, 0.22, 0.45))  # sammal
	MG.wood(_root, Rect2(0, 0, 90, H), Color(0.18, 0.18, 0.2), 60.0, 3, false)  # rotkon reunat varjossa
	MG.wood(_root, Rect2(W - 90, 0, 90, H), Color(0.18, 0.18, 0.2), 60.0, 4, false)
	var cur: Vector2 = _holds[_cur].p
	for i in _holds.size():
		var p := _screen(_holds[i].p)
		if p.y < -80.0 or p.y > H + 80.0:
			continue
		if _holds[i].landing:
			MG.wood(_root, Rect2(p.x - 150, p.y + 8, 300, 22), Color(0.5, 0.36, 0.22), 60.0, 5 + i, true)
			_root.draw_line(Vector2(p.x - 150, p.y + 8), Vector2(p.x - 150, p.y - 70), INK, 5.0)
			_root.draw_line(Vector2(p.x + 150, p.y + 8), Vector2(p.x + 150, p.y - 70), INK, 5.0)
			_root.draw_line(Vector2(p.x - 150, p.y - 56), Vector2(p.x + 150, p.y - 56), Color(0.4, 0.28, 0.17), 6.0)
		else:
			var col := Color(0.62, 0.45, 0.4) if _holds[i].loose else Color(0.72, 0.7, 0.64)
			var near: bool = _holds[i].p.distance_to(cur) <= REACH and i != _cur
			MG.ball(_root, p, 17.0, col, 0.6)
			if near and not _top:
				_root.draw_arc(p, 24.0, 0.0, TAU, 24, Color(1, 1, 0.6, 0.55 + 0.25 * sin(_t * 5.0)), 2.0)
	# Hahmo roikkuu otteessa tai putoaa.
	var cp := _screen(cur)
	if _fall_t > 0.0:
		var f := clampf(_fall_t / 0.9, 0.0, 1.0)
		cp = _screen(_fall_to).lerp(_screen(_fall_from), f * f)
	_draw_climber(cp + Vector2(0, 16 if _holds[_cur].landing else 50), 1.0 if _fall_t > 0.0 else 0.0)
	# Taivasraita ja kyltti ylhäällä: matka-asteikko vasemmalla.
	var prog := clampf(-_holds[_cur].p.y / (STAGE_H * STAGES), 0.0, 1.0)
	MG.box(_root, Rect2(30, 120, 24, 480), Color(0.14, 0.12, 0.1), 6, 0, Color.WHITE, 2)
	MG.ball(_root, Vector2(42, 600.0 - 480.0 * prog), 14.0, Color(1.0, 0.8, 0.3), 0.6)
	# Voimamittari.
	MG.sign(_root, Rect2(W - 330, 40, 280, 40), "VOIMAT", Color(0.14, 0.12, 0.1), Color(1.0, 0.9, 0.5), 22, Color(0.8, 0.7, 0.4))
	MG.box(_root, Rect2(W - 330, 88, 280, 26), Color(0.14, 0.12, 0.1), 8, 0, Color.WHITE, 2)
	MG.box(_root, Rect2(W - 326, 92, 272.0 * clampf(_stamina, 0.0, 1.0), 18), Color(0.4, 0.8, 0.35) if _stamina > 0.3 else Color(0.9, 0.35, 0.25), 6)
	if _falls > 0:
		MG.sign(_root, Rect2(100, 40, 240, 40), "PUTOAMISIA %d" % _falls, Color(0.14, 0.12, 0.1), Color.WHITE, 20, Color(0.8, 0.7, 0.4))
	if _msg_t > 0.0:
		MG.sign(_root, Rect2(W / 2.0 - 300, 100, 600, 56), _msg, Color(0.14, 0.12, 0.1, 0.92), Color.WHITE, 24, Color(0.8, 0.7, 0.4))
	MG.sparks_draw(_root, _sparks)
