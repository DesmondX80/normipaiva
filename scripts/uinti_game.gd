extends CanvasLayer
## Oulujoen uintikilpailu (#183): Vaalan nuoret pitivät joessa ponkkarit ja uintikilpailuja. Pelaaja hyppää ponkkarilta
## (aika oikeaan kohtaan: Väli / hiiri, kun liukuva merkki on vihreällä) ja uipi sitten kahta kilpailijaa vastaan:
## A ja D (tai vasen ja oikea) vuorotellen vetävät käsiä; sama näppäin kahdesti peräkkäin roiskii eikä vie eteenpäin.
## Veden vastus hidastaa, joten vuoroin painaminen tasaisessa tahdissa on nopeinta. Maali on poiju oikealla.
## finished(sija: int, aika: float). Esc / F lopettaa kesken (sija 0).

signal finished(place: int, time: float)

const MG := preload("res://scripts/mg_draw.gd")
const W := 1280.0
const H := 720.0
const GOAL := 100.0  # matka (m)
const INK := Color(0.08, 0.06, 0.05)
const LANES := [Vector2(0, 470), Vector2(0, 540), Vector2(0, 610)]
const NAMES := ["SÄÄ", "Jere", "Mikko"]
const SKIN := [Color(0.96, 0.78, 0.68), Color(0.95, 0.76, 0.66), Color(0.9, 0.72, 0.6)]
const HAIR := [Color(0.35, 0.25, 0.15), Color(0.75, 0.6, 0.3), Color(0.15, 0.1, 0.08)]
const CAPS := [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(0.95, 0.8, 0.2)]

var drunk := 0.0
var _root: Control
var _keys: Control
var _t := 0.0
var _phase := "intro"  # intro | jump | dive | swim | done
var _pt := 0.0
var _x := [0.0, 0.0, 0.0]  # matka (m)
var _v := [0.0, 0.0, 0.0]
var _stroke := [0.0, 0.0, 0.0]  # käsien vaihe
var _last := ""  # viimeksi painettu puoli
var _rate := [0.0, 0.0]  # AI:n vedot sekunnissa
var _ai_t := [0.0, 0.0]
var _meter := 0.0  # hyppymittarin merkki 0..1
var _jump_q := 0.0  # hypyn laatu 0..1
var _place := 0
var _order: Array = []
var _time := 0.0
var _sparks: Array = []
var _splash := 0.0
var _say := ""
var _say_t := 0.0
var _finished := false


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
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rate = [randf_range(2.3, 2.8), randf_range(2.0, 2.6)]
	_phase = "jump"
	_speak("Ponkkarilta hyppäämään! Osu vihreälle.")


func _speak(t: String) -> void:
	_say = t
	_say_t = 3.0


func _gui(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _phase == "jump":
			_jump()
		elif _phase == "swim":
			_pull("L" if _last != "L" else "R")


func _input(ev: InputEvent) -> void:
	if _finished or not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	match ev.keycode:
		KEY_ESCAPE, KEY_F:
			_end(0)
		KEY_SPACE, KEY_ENTER:
			if _phase == "jump":
				_jump()
			elif _phase == "done":
				_end(_place)
		KEY_A, KEY_LEFT:
			_pull("L")
		KEY_D, KEY_RIGHT:
			_pull("R")
	get_viewport().set_input_as_handled()


func _jump() -> void:
	var d := absf(_meter - 0.62)
	_jump_q = clampf(1.0 - d / 0.38, 0.0, 1.0)
	_phase = "dive"
	_pt = 0.0
	Sfx.play("whoosh", -6.0, 0.9 + _jump_q * 0.3)
	_speak("Loistava hyppy!" if _jump_q > 0.75 else ("Ihan ok." if _jump_q > 0.35 else "Mahalasku!"))
	_x[0] = 0.0
	_v[0] = 2.0 + _jump_q * 4.5
	for i in [1, 2]:
		_v[i] = randf_range(2.0, 4.5)


func _pull(side: String) -> void:
	if _phase != "swim":
		return
	if side == _last:
		_splash = 0.4
		_v[0] *= 0.93
		Sfx.play("water", -14.0, 1.4, 0.3)
		return
	_last = side
	_stroke[0] = 1.0
	_v[0] = minf(_v[0] + (1.05 - drunk * 0.2), 5.6)
	Sfx.play("water", -16.0, 1.0 + randf() * 0.4, 0.3)
	MG.sparks_burst(_sparks, Vector2(210.0 + _x[0] * 9.5, LANES[0].y + 30.0), Color(0.85, 0.95, 1.0), 3)


func _end(place: int) -> void:
	if _finished:
		return
	_finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finished.emit(place, _time)
	queue_free()


func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	_pt += delta
	_say_t = maxf(0.0, _say_t - delta)
	_splash = maxf(0.0, _splash - delta)
	MG.sparks_step(_sparks, delta)
	for i in 3:
		_stroke[i] = maxf(0.0, _stroke[i] - delta * 3.0)
	match _phase:
		"jump":
			_meter = 0.5 + 0.5 * sin(_t * 3.4 + drunk * sin(_t * 9.0))
		"dive":
			_x[0] += _v[0] * delta
			for i in [1, 2]:
				_x[i] += _v[i] * delta
			_v[0] *= exp(-0.5 * delta)
			if _pt > 0.9:
				_phase = "swim"
				_time = 0.0
				_speak("Nyt A ja D vuorotellen!")
		"swim":
			_time += delta
			_v[0] *= exp(-0.65 * delta)
			for i in [1, 2]:
				_ai_t[i - 1] -= delta
				if _ai_t[i - 1] <= 0.0:
					_ai_t[i - 1] = 1.0 / _rate[i - 1] * randf_range(0.85, 1.2)
					_v[i] = minf(_v[i] + 1.0 * randf_range(0.8, 1.05), 5.4)
					_stroke[i] = 1.0
				_v[i] *= exp(-0.65 * delta)
			for i in 3:
				_x[i] += _v[i] * delta
				if _x[i] >= GOAL and not _order.has(i):
					_order.append(i)
					if i == 0:
						_place = _order.size()
						_phase = "done"
						_pt = 0.0
						Sfx.play("win" if _place == 1 else "win_small", -6.0)
						_speak(["Voitto!", "Toinen sija, hyvä!", "Kolmas. Treenaa lisää."][_place - 1])
			if _order.size() >= 2 and not _order.has(0) and _phase == "swim":
				_place = 3
				_phase = "done"
				_pt = 0.0
				Sfx.play("lose", -6.0)
				_speak("Kolmas. Treenaa lisää.")
	_update_keys()
	_root.queue_redraw()


func _update_keys() -> void:
	match _phase:
		"jump":
			_keys.set_text("[Väli] Hyppää ponkkarilta   [Esc] Lopeta")
		"swim":
			_keys.set_text("[A] ja [D] vuorotellen vetää   [Esc] Lopeta")
		"done":
			_keys.set_text("[Väli] Valmis")
		_:
			_keys.set_text("[Esc] Lopeta")


func _px(i: int) -> float:
	return 220.0 + minf(_x[i], GOAL + 4.0) * 9.2


func _draw_root() -> void:
	var sz := _root.size
	var s := minf(sz.x / W, sz.y / H)
	var o := (sz - Vector2(W, H) * s) / 2.0
	var ci := _root
	ci.draw_set_transform(o, 0.0, Vector2(s, s))
	_draw_scene(ci)
	for i in [1, 2, 0]:
		_draw_swimmer(ci, i)
	MG.sparks_draw(ci, _sparks)
	_draw_front(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_scene(ci: CanvasItem) -> void:
	# Taivas, kaukaiset rannat ja koivut.
	MG.grad_rect(ci, Rect2(-600, -300, 2480, 600), Color(0.55, 0.78, 0.95), Color(0.9, 0.95, 0.98))
	ci.draw_circle(Vector2(1080, 110), 55.0, Color(1.0, 0.97, 0.75, 0.9))
	MG.glow(ci, Vector2(1080, 110), 140.0, Color(1.0, 0.95, 0.7, 0.3))
	for k in 14:
		var x := -40.0 + k * 100.0
		var h := 90.0 + fmod(k * 37.0, 50.0)
		ci.draw_rect(Rect2(x, 300 - h, 90, h + 20), Color(0.2, 0.38, 0.22))
		ci.draw_circle(Vector2(x + 45, 300 - h), 46.0, Color(0.25, 0.44, 0.26))
	ci.draw_rect(Rect2(-100, 330, 1500, 24), Color(0.4, 0.5, 0.3))  # vastaranta
	# Joki: useita vesikerroksia ja aaltoviivoja.
	MG.grad_rect(ci, Rect2(-600, 350, 2480, 420), Color(0.35, 0.62, 0.78), Color(0.14, 0.3, 0.45))
	for r in 9:
		var y := 372.0 + r * 40.0
		for k in 22:
			var x := fmod(k * 83.0 + r * 31.0 + _t * (14.0 + r * 3.0), 1500.0) - 100.0
			ci.draw_line(Vector2(x, y), Vector2(x + 44, y + sin(_t * 2.0 + k) * 2.0), Color(1, 1, 1, 0.16), 2.0)
	# Kaistaviivat poijuina.
	for li in [505.0, 575.0]:
		for k in 40:
			var bx := 120.0 + k * 31.0
			ci.draw_circle(Vector2(bx, li + sin(_t * 2.0 + k) * 2.0), 4.0, Color(0.96, 0.4, 0.3) if k % 2 == 0 else Color(0.96, 0.96, 0.96))
	# Ponkkari ja laituri vasemmalla, maalipoiju ja lippu oikealla.
	MG.wood(ci, Rect2(-40, 420, 230, 26), Color(0.62, 0.45, 0.28), 26.0, 5, true)
	for px in [10.0, 150.0]:
		ci.draw_rect(Rect2(px, 446, 16, 200), Color(0.42, 0.3, 0.18))
		ci.draw_rect(Rect2(px, 446, 16, 200), INK, false, 2.0)
	MG.solid(ci, Rect2(100, 395, 100, 14), Color(0.3, 0.62, 0.78))  # ponkkarilauta
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-60, 330), Vector2(60, 330), Vector2(120, 396), Vector2(190, 420), Vector2(-60, 440)]), Color(0.42, 0.52, 0.28))  # ranta
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-60, 390), Vector2(70, 380), Vector2(150, 420), Vector2(-60, 440)]), Color(0.72, 0.62, 0.42))
	for bx in [20.0, 60.0, 98.0]:  # pensaita
		ci.draw_circle(Vector2(bx, 372.0), 16.0, Color(0.2, 0.4, 0.2))
	var gx := 220.0 + GOAL * 9.2
	ci.draw_line(Vector2(gx, 380), Vector2(gx, 640), Color(1, 1, 1, 0.5), 3.0)
	ci.draw_polygon(PackedVector2Array([Vector2(gx, 380), Vector2(gx + 54, 395), Vector2(gx, 412)]), PackedColorArray([Color(0.95, 0.2, 0.2), Color(0.95, 0.2, 0.2), Color(0.95, 0.2, 0.2)]))
	ci.draw_string(ThemeDB.fallback_font, Vector2(gx - 24, 372), "MAALI", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color.WHITE)


func _draw_swimmer(ci: CanvasItem, i: int) -> void:
	var lane: float = LANES[i].y
	var x := _px(i)
	var diving := _phase == "dive" and i == 0
	var y := lane + sin(_t * 3.0 + i) * 2.0
	if _phase == "jump" and i == 0:
		# Ponkkarin päässä odottaa.
		x = 150.0
		y = 395.0
		MG.person(ci, Vector2(x, y - 52.0), 0.5, {"skin": SKIN[0], "hair_col": HAIR[0], "shirt": CAPS[0]}, Vector2(1, 0), false)
		return
	if diving:
		y = lerpf(395.0, lane, clampf(_pt / 0.5, 0.0, 1.0)) - sin(clampf(_pt / 0.9, 0.0, 1.0) * PI) * 50.0
		x = lerpf(150.0, x, clampf(_pt / 0.9, 0.0, 1.0))
	var sub := y > 420.0
	var stroke: float = _stroke[i]
	# Vartalo veden alla (varjo) ja pää/hartiat pinnalla.
	ci.draw_circle(Vector2(x, lane + 26.0), 22.0, Color(0, 0.1, 0.2, 0.25))
	ci.draw_circle(Vector2(x, y + 6.0), 17.0, CAPS[i].darkened(0.2))  # uimapuku/selkä
	var head := Vector2(x + 18.0, y - 4.0)
	ci.draw_circle(head, 12.0, SKIN[i])
	ci.draw_arc(head, 12.0, PI * 1.05, PI * 1.95, 12, HAIR[i], 7.0)
	ci.draw_circle(head + Vector2(5, -2), 2.0, INK)
	ci.draw_arc(head, 12.0, 0, TAU, 20, INK, 1.5)
	# Käsi: vuorotellen eteen ja taakse.
	var ph := _t * 7.0 * (0.4 + stroke) + i
	var hand := Vector2(x + 18.0 + cos(ph) * 26.0, y - 16.0 + sin(ph) * 18.0)
	ci.draw_line(Vector2(x + 6.0, y - 2.0), hand, SKIN[i], 6.0)
	ci.draw_circle(hand, 5.0, SKIN[i])
	if sub or stroke > 0.2:
		for k in 3:
			ci.draw_circle(Vector2(x - 20.0 - k * 10.0, y + 10.0 + sin(_t * 8.0 + k) * 3.0), 3.0 - k * 0.6, Color(1, 1, 1, 0.5 - k * 0.12))
	# Nimi.
	ci.draw_string(ThemeDB.fallback_font, Vector2(x - 12.0, lane + 52.0), NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE if i == 0 else Color(0.9, 0.95, 1.0, 0.8))


func _draw_front(ci: CanvasItem) -> void:
	# Etäisyys- ja aikamittari ylhäällä, hyppymittari ja puhekupla.
	var font := ThemeDB.fallback_font
	MG.box(ci, Rect2(40, 20, 400, 62), Color(0.05, 0.1, 0.18, 0.8), 10, 6, Color(0.5, 0.8, 1.0), 2)
	ci.draw_string(font, Vector2(56, 48), "Oulujoen uintikilpailu · %d m" % int(GOAL), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.85, 0.95, 1.0))
	ci.draw_string(font, Vector2(56, 72), "Matka %d m · aika %.1f s" % [int(minf(_x[0], GOAL)), _time], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.95, 0.7))
	if _phase == "jump":
		var bar := Rect2(440, 160, 400, 36)
		MG.box(ci, bar.grow(6), Color(0.05, 0.1, 0.18, 0.85), 10, 6, Color.WHITE, 2)
		ci.draw_rect(bar, Color(0.25, 0.25, 0.3))
		ci.draw_rect(Rect2(bar.position.x + bar.size.x * 0.48, bar.position.y, bar.size.x * 0.28, bar.size.y), Color(0.3, 0.75, 0.35))
		var mx := bar.position.x + _meter * bar.size.x
		ci.draw_rect(Rect2(mx - 5, bar.position.y - 8, 10, bar.size.y + 16), Color(1.0, 0.9, 0.3))
		ci.draw_string(font, Vector2(bar.position.x, bar.position.y - 14), "HYPPY OIKEASSA KOHTAA", HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 20, Color.WHITE)
	if _phase == "swim":
		var a: float = _stroke[0]
		ci.draw_string(font, Vector2(540, 150), "A  ◀  ▶  D", HORIZONTAL_ALIGNMENT_CENTER, 200, 34, Color(1, 1, 1, 0.55 + a * 0.4))
		if _splash > 0.0:
			ci.draw_string(font, Vector2(540, 190), "ROISKE!", HORIZONTAL_ALIGNMENT_CENTER, 200, 22, Color(1.0, 0.6, 0.5))
	if _say != "" and _say_t > 0.0:
		MG.bubble(ci, Rect2(40, 106, 500, 56), Vector2(150, 200), _say, 22)
	if _phase == "done":
		var r := Rect2(380, 220, 520, 200)
		MG.box(ci, r, Color(0.99, 0.96, 0.85), 14, 10, Color(0.15, 0.3, 0.5), 4)
		var title: String = ["VOITTO!", "TOINEN SIJA", "KOLMAS SIJA"][clampi(_place - 1, 0, 2)]
		MG.sign(ci, Rect2(r.position + Vector2(110, 18), Vector2(300, 52)), title, Color(0.15, 0.4, 0.6), Color.WHITE, 28)
		ci.draw_string(font, r.position + Vector2(0, 118), "Aikasi %.1f s" % _time, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, INK)
		ci.draw_string(font, r.position + Vector2(0, 160), "Nuoret hurraavat rannalla.", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(0.4, 0.35, 0.3))
