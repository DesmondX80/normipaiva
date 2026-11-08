extends CanvasLayer
## Korkkiläpsy (#290, pog-tyylinen): kumpikin panee pinoon saman määrän tuplakorkkeja nurin päin, ja vuorotellen pinoon
## lyödään lyöjällä (tinanappi). Tähtäys A/D tai hiiri, voima ajoituksella (välilyönti / klikkaus): oikeinpäin kääntyneet
## korkit saa itselleen. Liian kova lyönti lennättää korkit asfaltille: ei saalista, vuoro vaihtuu. Peli loppuu, kun pino
## on tyhjä. Panoksina vain tuplat (main.gd _start_korkkilapsy). finished(won: Array, quit: bool) = pelaajan saamat korkit.

signal finished(won: Array, quit: bool)

const MG := preload("res://scripts/mg_draw.gd")
const Korkit := preload("res://scripts/korkit.gd")
const W := 1280.0
const H := 720.0
const PILE := Vector2(640, 430)
const SWEET := 0.72  # paras voima
const TOO_HARD := 0.93
const TEEN := {"skin": Color(0.95, 0.77, 0.66), "hair": "spiky", "hair_col": Color(0.85, 0.7, 0.35), "shirt": Color(0.2, 0.55, 0.45),
	"cap": Color(0.85, 0.2, 0.2)}

var stack: Array = []  # [{key, up, off: Vector2, rot}] pinon korkit
var drunk := 0.0
var _root: Control
var _t := 0.0
var _turn := "me"  # me | teini
var _phase := "aim"  # aim | power | slam | fly | done
var _pt := 0.0
var _aim := 0.0  # -1..1 pinon keskeltä
var _power := 0.0
var _pdir := 1.0
var _won_me: Array = []
var _won_teen: Array = []
var _flying: Array = []  # [key, from, to, t, spin, up]
var _sparks: Array = []
var _shake := 0.0
var _say := ""
var _say_t := 0.0
var _specks: Array = []
var _rounds := 0


func _ready() -> void:
	add_to_group("esc_lopettaa")
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	_root.gui_input.connect(_gui)
	add_child(_root)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	for i in 420:
		_specks.append([Vector2(rng.randf() * W, 300 + rng.randf() * (H - 300)), rng.randf_range(0.8, 2.4), rng.randf()])
	for c in stack:
		c.off = Vector2(randf_range(-6, 6), randf_range(-4, 4))
		c.rot = randf() * TAU
	_say = "Panokset pinoon, nurin päin. Sää aloitat."
	_say_t = 3.0


func _gui(e: InputEvent) -> void:
	if _turn != "me":
		return
	if e is InputEventMouseMotion and _phase == "aim":
		_aim = clampf((e.position.x - PILE.x) / 90.0, -1.0, 1.0)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_press()


func _press() -> void:
	if _phase == "aim":
		_phase = "power"
		_power = 0.0
		_pdir = 1.0
	elif _phase == "power":
		_strike(_aim, _power)


func _process(delta: float) -> void:
	_t += delta
	_pt += delta
	_say_t -= delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	MG.sparks_step(_sparks, delta)
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_end(true)
		return
	match _phase:
		"aim", "power":
			if _turn == "me":
				_aim = clampf(_aim + Input.get_axis("left", "right") * delta * 1.6 + sin(_t * 3.0) * drunk * delta, -1.0, 1.0)
				if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact"):
					_press()
				if _phase == "power":
					_power += _pdir * delta * (1.1 + drunk * 0.6)
					if _power >= 1.0 or _power <= 0.0:
						_pdir = -_pdir
						_power = clampf(_power, 0.0, 1.0)
			elif _pt > 1.3:
				# Teinin lyönti: kohtalainen tähtäys ja voima, joskus liian kova.
				_strike(randf_range(-0.45, 0.45), clampf(randfn(SWEET, 0.12), 0.3, 1.0))
		"slam":
			if _pt > 0.18:
				_resolve()
		"fly":
			for f in _flying:
				f[3] = minf(1.0, f[3] + delta * 1.6)
			if _pt > 0.9:
				_flying.clear()
				_next_turn()
	_root.queue_redraw()


func _strike(aim: float, power: float) -> void:
	_aim = aim
	_power = power
	_phase = "slam"
	_pt = 0.0


## Lyönnin tulos: laatu tähtäyksestä ja voimasta; kääntyneet korkit lentävät lyöjän puolelle.
func _resolve() -> void:
	_rounds += 1
	_shake = 0.6 + _power * 0.6
	Sfx.play("rattle_hard" if _power > 0.6 else "rattle", -4.0, randf_range(1.2, 1.5))
	MG.sparks_burst(_sparks, PILE + Vector2(_aim * 40, -20), Color(0.9, 0.9, 0.85), 14)
	var too_hard := _power > TOO_HARD
	var q := clampf((1.0 - absf(_aim) * 0.6) * (1.0 - absf(_power - SWEET) * 2.2), 0.05, 1.0)
	var mine := _turn == "me"
	var side_y := 640.0 if mine else 250.0
	for i in range(stack.size() - 1, -1, -1):
		var c: Dictionary = stack[i]
		var from: Vector2 = PILE + c.off - Vector2(0, i * 5)
		if too_hard and randf() < 0.6:
			var to := Vector2(randf_range(150, 1130), randf_range(330, 660))
			_flying.append([c.key, from, to, 0.0, randf_range(8, 16), randf() < 0.5])
			c.off = Vector2(randf_range(-6, 6), randf_range(-4, 4))
		elif not too_hard and randf() < q * 0.8:
			var won: Array = _won_me if mine else _won_teen
			won.append(c.key)
			var to := Vector2(380 + won.size() * 34 if mine else 900 - won.size() * 34, side_y)
			_flying.append([c.key, from, to, 0.0, randf_range(10, 20), true])
			stack.remove_at(i)
	if too_hard:
		_say = "Liian kova! Korkit asfaltilla, ei kenellekään." if mine else "Teini löi liian kovaa. Korkit takaisin pinoon."
		Sfx.play("hit", -6.0, 0.8)
	else:
		var n := _flying.size()
		_say = ("%d korkkia kääntyi! Sun." % n if n > 0 else "Ei yhtään. Pino pysyi nurin.") if mine else \
			("Teini sai %d." % n if n > 0 else "Teinin lyönti meni ohi. Hah.")
		if n > 0:
			Sfx.play("coin", -6.0, 1.3)
	_say_t = 2.0
	_phase = "fly"
	_pt = 0.0


func _next_turn() -> void:
	if stack.is_empty() or _rounds >= 14:
		_phase = "done"
		_pt = 0.0
		var win := _won_me.size() >= _won_teen.size()
		_say = "Pino on tyhjä. Sää voitit %d korkkia, teini %d." % [_won_me.size(), _won_teen.size()]
		_say_t = 99.0
		Sfx.play("win_small" if win else "hit", -4.0)
		get_tree().create_timer(2.6).timeout.connect(_end.bind(false))
		return
	_turn = "teini" if _turn == "me" else "me"
	_phase = "aim"
	_pt = 0.0


func _end(quit: bool) -> void:
	if is_queued_for_deletion():
		return
	# Keskeytys: pino jaetaan puoliksi takaisin (omat panokset palaavat), saadut pidetään.
	var won := _won_me.duplicate()
	if quit:
		for i in stack.size():
			if i % 2 == 0:
				won.append(stack[i].key)
	finished.emit(won, quit)
	queue_free()


# --- Piirto -------------------------------------------------------------------------------------------------

func _draw_root() -> void:
	var ci := _root
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 8.0
	ci.draw_set_transform(sh, 0.0, Vector2.ONE)
	# Tausta: lavan pihan asfaltti iltavalossa, reunakivi ja aita, maalattu viiva ja halkeamat.
	MG.grad_rect(ci, Rect2(0, 0, W, 300), Color(0.95, 0.62, 0.38), Color(0.55, 0.42, 0.5))
	for i in 26:
		var x := i * 52.0
		ci.draw_rect(Rect2(x, 170, 10, 130), Color(0.42, 0.3, 0.22))
		ci.draw_rect(Rect2(x, 170, 3, 130), Color(0.55, 0.42, 0.3))
	ci.draw_rect(Rect2(0, 200, W, 9), Color(0.38, 0.27, 0.2))
	ci.draw_rect(Rect2(0, 250, W, 9), Color(0.38, 0.27, 0.2))
	MG.grad_rect(ci, Rect2(0, 300, W, H - 300), Color(0.36, 0.36, 0.38), Color(0.24, 0.24, 0.26))
	ci.draw_rect(Rect2(0, 292, W, 14), Color(0.62, 0.6, 0.56))
	ci.draw_rect(Rect2(0, 304, W, 4), Color(0.4, 0.38, 0.36))
	for s in _specks:
		ci.draw_circle(s[0], s[1], Color(0.5, 0.5, 0.52, 0.35) if s[2] > 0.5 else Color(0.15, 0.15, 0.17, 0.4))
	ci.draw_rect(Rect2(120, 560, 1040, 8), Color(0.9, 0.85, 0.55, 0.7))
	ci.draw_polyline(PackedVector2Array([Vector2(200, 330), Vector2(260, 380), Vector2(250, 440), Vector2(320, 500)]), Color(0.12, 0.12, 0.13), 2.0)
	ci.draw_polyline(PackedVector2Array([Vector2(1000, 600), Vector2(1060, 560), Vector2(1140, 580)]), Color(0.12, 0.12, 0.13), 2.0)
	# Teini vastapäätä kyykyssä: lyöjä kädessä omalla vuorollaan.
	MG.person(ci, Vector2(900, 150), 1.0, TEEN, Vector2((PILE.x - 900) / 400.0, 0.6), _say_t > 0 and _turn == "teini",
		0.6 if _turn == "teini" and _phase != "fly" else 0.0)
	_label(ci, Vector2(900, 70), "Jere, 14 v.", 18)
	# Voitetut korkit kummankin puolella.
	for i in _won_teen.size():
		_cap(ci, Vector2(900 - (i + 1) * 34, 250), 15.0, _won_teen[i], true, 0.3 * i)
	for i in _won_me.size():
		_cap(ci, Vector2(380 + (i + 1) * 34, 640), 15.0, _won_me[i], true, 0.3 * i)
	# Pino: korkit nurin päin päällekkäin, varjo alla.
	ci.draw_circle(PILE + Vector2(6, 10), 46.0, Color(0, 0, 0, 0.3))
	for i in stack.size():
		var c: Dictionary = stack[i]
		_cap(ci, PILE + c.off - Vector2(0, i * 5), 40.0, c.key, c.up, c.rot)
	for f in _flying:
		var k: float = f[3]
		var p: Vector2 = (f[1] as Vector2).lerp(f[2], k) - Vector2(0, sin(k * PI) * 120.0)
		var sc := absf(cos(k * f[4]))
		ci.draw_set_transform(sh + p, 0.0, Vector2(1.0, maxf(0.15, sc)))
		_cap(ci, Vector2.ZERO, 30.0 if k < 1.0 else 15.0, f[0], f[5] if sc > 0.5 or k >= 1.0 else not f[5], 0.0)
		ci.draw_set_transform(sh, 0.0, Vector2.ONE)
	MG.sparks_draw(ci, _sparks)
	# Lyöjä: vanha tinanappi, vuorolla tähtäyksen kohdalla pinon yllä; iskussa alas.
	if _phase in ["aim", "power", "slam"]:
		var lift := 120.0 if _phase != "slam" else 120.0 * (1.0 - _pt / 0.18)
		var sp := PILE + Vector2(_aim * 60.0, -stack.size() * 5 - lift)
		ci.draw_circle(PILE + Vector2(_aim * 60.0 + 4, 8), 34.0 * (1.0 - lift / 300.0), Color(0, 0, 0, 0.25))
		ci.draw_circle(sp, 36.0, Color(0.42, 0.44, 0.46))
		ci.draw_circle(sp, 32.0, Color(0.62, 0.64, 0.66))
		ci.draw_arc(sp, 28.0, PI * 1.1, PI * 1.9, 14, Color(0.9, 0.92, 0.95), 4.0)
		ci.draw_arc(sp, 30.0, PI * 0.1, PI * 0.9, 14, Color(0.35, 0.36, 0.38), 3.0)
		ci.draw_circle(sp, 10.0, Color(0.5, 0.52, 0.54))
		ci.draw_circle(sp + Vector2(-12, -12), 5.0, Color(1, 1, 1, 0.5))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Voimamittari ja tekstit.
	if _turn == "me" and _phase in ["aim", "power"]:
		var r := Rect2(1080, 380, 40, 240)
		MG.box(ci, r.grow(6), Color(0.1, 0.1, 0.1, 0.7), 6)
		ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * (1.0 - TOO_HARD)), Color(0.85, 0.2, 0.15))  # liian kova
		ci.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * (SWEET + 0.08), r.size.x, r.size.y * 0.16), Color(0.3, 0.8, 0.35))
		ci.draw_rect(Rect2(r.position.x - 6, r.end.y - r.size.y * _power - 3, r.size.x + 12, 6), Color(1, 1, 1))
		_label(ci, Vector2(1100, 650), "VOIMA", 16)
	MG.box(ci, Rect2(20, 14, 600, 44), Color(0.08, 0.07, 0.06, 0.8), 8)
	_label(ci, Vector2(320, 44), "KORKKILÄPSY · %s · sää %d, teini %d · pinossa %d" % ["sun vuoro" if _turn == "me" else "teinin vuoro",
		_won_me.size(), _won_teen.size(), stack.size()], 18)
	if _say_t > 0:
		MG.bubble(ci, Rect2(380, 70, 420, 70), Vector2(820, 120), _say, 20)
	var keys := "[A/D tai hiiri] tähtää   [Väli/klikkaus] lyöntivoima, toinen painallus lyö   [F/Esc] lopeta"
	MG.box(ci, Rect2(140, 680, 1000, 32), Color(0.08, 0.07, 0.06, 0.75), 8)
	_label(ci, Vector2(640, 703), keys, 16)


func _label(ci: CanvasItem, c: Vector2, text: String, size: int) -> void:
	var f := ThemeDB.fallback_font
	ci.draw_string(f, c + Vector2(-500, 1), text, HORIZONTAL_ALIGNMENT_CENTER, 1000, size, Color(0, 0, 0, 0.7))
	ci.draw_string(f, c + Vector2(-500, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 1000, size, Color(1, 0.97, 0.9))


## Kruunukorkki ylhäältä: logopuoli (väri, rihla, sävytys, kiilto, logo) tai nurja puoli (pelti ja korkkitiiviste).
func _cap(ci: CanvasItem, c: Vector2, r: float, key: String, up: bool, rot: float) -> void:
	var p := key.split(":")
	var br: Dictionary = Korkit.BRANDS.get(p[0], {"nimi": "MM", "vari": Color(0.95, 0.75, 0.2)})
	var col: Color = br.vari if up else Color(0.72, 0.72, 0.7)
	var pts := PackedVector2Array()
	for i in 42:
		var a := i * TAU / 42.0 + rot
		pts.append(c + Vector2(cos(a), sin(a)) * (r + (r * 0.1 if i % 2 == 0 else 0.0)))
	ci.draw_colored_polygon(pts, col.darkened(0.35))
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), col.darkened(0.6), 1.2, true)
	ci.draw_circle(c, r * 0.94, col)
	ci.draw_arc(c, r * 0.86, PI * 1.1, PI * 1.9, 16, col.lightened(0.45), r * 0.1, true)
	ci.draw_arc(c, r * 0.86, PI * 0.1, PI * 0.9, 16, col.darkened(0.3), r * 0.1, true)
	if not up:
		ci.draw_circle(c, r * 0.7, Color(0.78, 0.66, 0.48))  # korkkitiiviste
		ci.draw_arc(c, r * 0.7, 0, TAU, 24, Color(0.6, 0.5, 0.35), 1.5)
		return
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.18, Color(1, 1, 1, 0.35))
	if p.size() > 1 and p[1] == "juhla":
		for i in 12:
			var a := i * TAU / 12.0
			ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.74, c + Vector2(cos(a), sin(a)) * r * 0.9, Color(1, 0.85, 0.2), 2.0)
	if r >= 20.0:
		var t := String(br.nimi).left(6).to_upper()
		ci.draw_string(ThemeDB.fallback_font, c + Vector2(-r, r * 0.17), t, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 0.38),
			Color(1, 0.95, 0.85))
