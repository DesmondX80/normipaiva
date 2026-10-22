extends CanvasLayer
## Oma kirppispöytä Saloisten seuraintalolla (#128): pelaaja myy reppunsa tavaraa (marjat, sienet, savukala ja
## -riista) pöytäpaikalta, ostajat tulevat pöydän ääreen yksi kerrallaan ja tinkivät. Ostaja tekee tarjouksen;
## pelaaja hyväksyy, tekee vastatarjouksen (W/S hinta, väli) tai heittää ostajan pois (X). Ostajalla on piilotettu
## enimmäishinta: liian kova vastatarjous ajaa ostajan pois (Pihi kuin Pekka), liian halpa jättää rahat saamatta.
## Kalja ja pontikka myydään tiskin alta nuorelle ostajalle, mutta Anna-Liisa vahtii: kauppa onnistuu vain, kun hän
## katsoo muualle (silmä-merkki vaihtuu vihreäksi). Kiinni jääminen päättää pelin. Esc pakkaa pöydän.
## stock = {tuote: määrä} (main.gd antaa). finished(tulos): {sold, income, caught, quit, rep, title, buyers}.

signal finished(result: Dictionary)

const MG := preload("res://scripts/mg_draw.gd")
const W := 1280.0
const H := 720.0
const MAX_BUYERS := 7
const STEP := 0.5
const WATCH_PERIOD := 8.0
const WATCH_SAFE := Vector2(5.4, 7.6)  # Anna-Liisa katsoo muualle tällä välillä (s)
const TABLE_TOP := 400.0
const PANEL := Rect2(300, 500, 680, 172)
const INK := Color(0.1, 0.08, 0.06)
const GOODS := {
	"puolukka": {"name": "Puolukat", "unit": "l", "fair": 6.0, "one": "litran puolukoita", "many": "%d l puolukoita"},
	"mustikka": {"name": "Mustikat", "unit": "l", "fair": 7.0, "one": "litran mustikoita", "many": "%d l mustikoita"},
	"kantarelli": {"name": "Kantarellit", "unit": "l", "fair": 14.0, "one": "litran kantarelleja", "many": "%d l kantarelleja"},
	"herkkutatti": {"name": "Herkkutatit", "unit": "l", "fair": 11.0, "one": "litran herkkutatteja", "many": "%d l herkkutatteja"},
	"savukala": {"name": "Savukala", "unit": "kpl", "fair": 7.0, "one": "savukalan", "many": "%d savukalaa"},
	"savuriista": {"name": "Savuriista", "unit": "kpl", "fair": 9.0, "one": "savuriistan", "many": "%d savuriistaa"},
	"kalja": {"name": "Kalja", "unit": "kpl", "fair": 15.0, "one": "kaljan", "many": "%d kaljaa", "under": true},
	"pontikka": {"name": "Pontikka", "unit": "pullo", "fair": 20.0, "one": "pullon pontikkaa", "many": "%d pulloa pontikkaa", "under": true},
}
const ORDER := ["puolukka", "mustikka", "kantarelli", "herkkutatti", "savukala", "savuriista"]
## Ostajatyypit: tykkäämät tuotteet, avaustarjous ja enimmäishinta (osuutena reiluista hinnoista), kärsivällisyys
## (epäonnistuneita vastatarjouksia) ja ulkonäkö (MG.person).
const TYPES := {
	"mummo": {"name": "Mummo", "weight": 35, "likes": ["puolukka", "mustikka", "kantarelli", "herkkutatti", "savukala"],
		"open": 0.5, "cap": Vector2(0.9, 1.1), "patience": 3,
		"look": {"hair": "buns", "hair_col": Color(0.88, 0.88, 0.9), "shirt": Color(0.5, 0.42, 0.64), "skin": Color(0.95, 0.8, 0.72)},
		"open_line": "Ottaisin %s. Antaisinko %s €?", "tag": "tinkii pontevasti"},
	"mokki": {"name": "Mökkiläinen", "weight": 25, "likes": ["savukala", "savuriista", "kantarelli", "herkkutatti", "puolukka", "mustikka"],
		"open": 0.75, "cap": Vector2(1.2, 1.5), "patience": 2,
		"look": {"cap": true, "glasses": true, "shirt": Color(0.2, 0.55, 0.65), "hair_col": Color(0.3, 0.22, 0.15), "skin": Color(0.97, 0.8, 0.7)},
		"open_line": "Mökille tarttis %s. %s € kelpaa?", "tag": "kaupungista, rahaa on"},
	"annaliisa": {"name": "Anna-Liisa", "weight": 15, "likes": ["puolukka", "mustikka", "savukala"],
		"open": 0.4, "cap": Vector2(0.8, 0.95), "patience": 4,
		"look": {"hair": "buns", "hair_col": Color(0.55, 0.45, 0.35), "shirt": Color(0.75, 0.55, 0.6), "skin": Color(0.95, 0.8, 0.74)},
		"open_line": "Hmm, %s... %s €, ja se on reilua.", "tag": "naapuri, tietää kaiken"},
	"nuori": {"name": "Nuori mies", "weight": 25, "likes": ["kalja", "pontikka"], "under": true,
		"open": 0.8, "cap": Vector2(1.0, 1.25), "patience": 2,
		"look": {"cap": true, "shirt": Color(0.2, 0.2, 0.25), "hair_col": Color(0.2, 0.15, 0.1), "skin": Color(0.96, 0.78, 0.68)},
		"open_line": "Psst... onko %s tiskin alta? %s €.", "tag": "psst, tiskin alta"},
}
const HILKKA_LOOK := {"hair": "buns", "hair_col": Color(0.85, 0.85, 0.85), "shirt": Color(0.55, 0.3, 0.45), "skin": Color(0.95, 0.8, 0.74)}

var stock := {}  # tuote -> määrä (main.gd)
var maine := 50.0

var _root: Control
var _keys: Control
var _left := {}
var _sold := {}
var _income := 0.0
var _served := 0
var _good := 0
var _greedy := 0
var _caught := false
var _quit := false
var _phase := "arrive"  # arrive / talk / leave / caught / summary
var _pt := 0.0
var _t := 0.0
var _watch_t := 0.0
var _shake := 0.0
var _b := {}  # nykyinen ostaja
var _bx := 1500.0
var _line := ""  # puhekuplan teksti
var _line_me := false
var _counter := 0.0
var _mood := 0  # -1 ärtyisä, 0 neutraali, 1 tyytyväinen
var _sparks: Array = []
var _floats: Array = []  # [teksti, paikka, ikä, väri]
var _coins := 0
var _rep := 0
var _title := ""
var _done := false


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc pakkaa pöydän: taukovalikko ei aukea (menu.gd)
	layer = 6
	_left = stock.duplicate()
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
	_watch_t = randf_range(0.0, 3.0)
	_next()


# --- Ostajat ---------------------------------------------------------------------

func _total_left() -> int:
	var n := 0
	for k in _left:
		n += int(_left[k])
	return n


func _next() -> void:
	if _served >= MAX_BUYERS or _total_left() <= 0:
		_summary()
		return
	var pool: Array = []
	for t in TYPES:
		for k in TYPES[t].likes:
			if int(_left.get(k, 0)) > 0:
				pool.append(t)
				break
	if pool.is_empty():
		_summary()
		return
	var total := 0
	for t in pool:
		total += int(TYPES[t].weight)
	var roll := randi() % total
	var type: String = pool[0]
	for t in pool:
		roll -= int(TYPES[t].weight)
		if roll < 0:
			type = t
			break
	var td: Dictionary = TYPES[type]
	var wants: Array = []
	for k in td.likes:
		if int(_left.get(k, 0)) > 0:
			wants.append(k)
	var item: String = wants.pick_random()
	var qty := mini(int(_left[item]), randi_range(1, 2))
	var fair: float = GOODS[item].fair * qty
	var cap: float = randf_range(td.cap.x, td.cap.y) * (1.0 + maine / 800.0)
	var limit := maxf(STEP * 2.0, snappedf(fair * cap, STEP))
	var offer := clampf(snappedf(fair * td.open * randf_range(0.9, 1.1), STEP), STEP, limit - STEP)
	_b = {"type": type, "item": item, "qty": qty, "fair": fair, "limit": limit, "offer": offer, "patience": td.patience,
		"under": td.get("under", false), "side": 1.0 if randf() < 0.5 else -1.0}
	_counter = maxf(offer + STEP, snappedf(fair * 1.15, STEP))
	_served += 1
	_phase = "arrive"
	_pt = 0.0
	_bx = 640.0 + _b.side * 900.0
	_line = ""
	_mood = 0
	Sfx.play("cloth", -12.0, 1.3)


func _qty_text(item: String, qty: int) -> String:
	return GOODS[item].one if qty == 1 else GOODS[item].many % qty


func _open_line() -> void:
	var td: Dictionary = TYPES[_b.type]
	_say(td.open_line % [_qty_text(_b.item, _b.qty), _eur(_b.offer)], false)


func _say(text: String, me: bool) -> void:
	_line = text
	_line_me = me


static func _eur(v: float) -> String:
	return ("%.1f" % v).replace(".", ",").trim_suffix(",0")


# --- Anna-Liisa vahtii --------------------------------------------------------------

func _watching() -> bool:
	if _phase in ["talk", "arrive", "leave"] and not _b.is_empty() and _b.type == "annaliisa":
		return true
	return _watch_t < WATCH_SAFE.x or _watch_t > WATCH_SAFE.y


# --- Toiminnot ---------------------------------------------------------------------

func _accept(price: float) -> void:
	if _phase != "talk":
		return
	if _b.under and _watching():
		_busted()
		return
	var item: String = _b.item
	var qty: int = _b.qty
	_left[item] = int(_left[item]) - qty
	_sold[item] = int(_sold.get(item, 0)) + qty
	_income += price
	_coins = mini(_coins + roundi(price / 3.0) + 1, 14)
	var ratio: float = price / _b.fair
	if ratio >= 0.85 and ratio <= 1.3:
		_good += 1
	_mood = 1
	_say(["Kauppa! Kiitos.", "Hyvä, tässä rahat.", "Reilu hinta, kiitti.", "Käy, käy. Hyvää päivänjatkoa."].pick_random(), false)
	Sfx.play("coin", -4.0)
	MG.sparks_burst(_sparks, Vector2(640, 440), Color(1.0, 0.85, 0.2), 26)
	_floats.append(["+%s €" % _eur(price), Vector2(760, 360), 0.0, Color(1.0, 0.9, 0.3)])
	_leave()


func _counter_offer() -> void:
	if _phase != "talk":
		return
	var c := _counter
	if c <= _b.offer + 0.001:
		_accept(_b.offer)
		return
	_say("Vastatarjous: %s €." % _eur(c), true)
	if c <= _b.limit + 0.001:
		_accept(c)
		return
	if c <= _b.limit * 1.2 + 0.001 and _b.patience > 1:
		_b.patience -= 1
		var raised := snappedf(_b.offer + (_b.limit - _b.offer) * 0.5, STEP)
		_b.offer = clampf(maxf(raised, _b.offer + STEP), STEP, _b.limit)
		_counter = maxf(_b.offer + STEP, c - 1.0)
		_mood = -1
		_say(["Hmm. %s € on ylin, minkä mää annan." % _eur(_b.offer), "Ei ihan. Entä %s €?" % _eur(_b.offer),
			"Tinkimällä tää menee, %s € ja ei pennin penniä enempää." % _eur(_b.offer)].pick_random(), false)
		Sfx.play("pickup", -10.0, 0.6)
		return
	if c > _b.limit * 1.2:
		_greedy += 1
		_say(["Rosvoamista! Pihi kuin Pekka!", "Mitä?! Hilkan pöydältä saa halvemmalla.", "Tuolla hinnalla ostan kaupasta."].pick_random(), false)
		_floats.append(["Pihi kuin Pekka", Vector2(760, 360), 0.0, Color(1.0, 0.45, 0.35)])
	else:
		_say("Ei tästä tule mitään. Mää meen muualle.", false)
	_mood = -1
	_refuse()


func _refuse() -> void:
	Sfx.play("lose", -10.0, 1.3)
	MG.sparks_burst(_sparks, Vector2(_bx, 250), Color(0.9, 0.3, 0.25), 14)
	_leave()


func _send_away() -> void:
	if _phase != "talk":
		return
	_say("Ei kiitos, ei tänään.", true)
	_mood = 0
	_leave()


func _leave() -> void:
	_phase = "leave"
	_pt = 0.0


func _busted() -> void:
	_caught = true
	_phase = "caught"
	_pt = 0.0
	_shake = 0.7
	_say("Kas vaan! Kaljaa Nuorisoseuran talolla! Päivi saa kuulla!", false)
	Sfx.play("lose", -4.0)
	Sfx.play("glass", -8.0, 0.8)


func _summary() -> void:
	_phase = "summary"
	if _good >= 3 and _greedy == 0:
		_rep = 3
		_title = "Rehellinen kauppamies"
	elif _good >= 2 and _greedy <= 1:
		_rep = 1
		_title = "Reilu myyjä"
	elif _greedy >= 2:
		_rep = -3
		_title = "Pihi kuin Pekka"
	elif _greedy == 1 and _good < 2:
		_rep = -1
		_title = "Vähän pihi"
	else:
		_title = "Tavallinen myyjä"
	Sfx.play("win_small" if _income > 0.0 else "cloth", -6.0)


func _end() -> void:
	if _done:
		return
	_done = true
	if _caught:
		_rep = -4
		_title = "Kaljankauppaaja"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finished.emit({"sold": _sold, "income": _income, "caught": _caught, "quit": _quit, "rep": _rep, "title": _title,
		"buyers": _served, "good": _good, "greedy": _greedy})
	queue_free()


# --- Peli ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_watch_t = fmod(_watch_t + delta, WATCH_PERIOD)
	_shake = maxf(0.0, _shake - delta)
	MG.sparks_step(_sparks, delta)
	for f in _floats:
		f[2] += delta
		f[1].y -= 40.0 * delta
	_floats = _floats.filter(func(f: Array) -> bool: return f[2] < 1.4)
	_pt += delta
	match _phase:
		"arrive":
			var k := clampf(_pt / 0.9, 0.0, 1.0)
			_bx = lerpf(640.0 + _b.side * 900.0, 640.0, 1.0 - pow(1.0 - k, 2.0))
			if k >= 1.0:
				_phase = "talk"
				_open_line()
		"leave":
			var k := clampf(_pt / 1.1, 0.0, 1.0)
			_bx = lerpf(640.0, 640.0 + _b.side * 900.0, k * k)
			if _pt >= 1.1:
				_next()
		"caught":
			_bx = lerpf(640.0, 640.0 + _b.side * 900.0, clampf((_pt - 1.2) / 1.0, 0.0, 1.0))
			if _pt >= 2.8:
				_end()
	_update_keys()
	_root.queue_redraw()


func _update_keys() -> void:
	var esc := "%s lopeta" % Settings.cap("mount")
	match _phase:
		"talk":
			_keys.set_text("[W/S] Vastatarjous   [Väli] Tarjoa   [H] Hyväksy   [X] Ei kiitos   [Esc] Pakkaa pöytä")
		"summary":
			_keys.set_text("[Väli] Valmis")
		_:
			_keys.set_text(esc)


func _input(ev: InputEvent) -> void:
	if _done:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var big: bool = ev.shift_pressed
		match ev.keycode:
			KEY_ESCAPE:
				_pack()
			KEY_W, KEY_UP:
				_adjust(STEP * (4.0 if big else 1.0))
			KEY_S, KEY_DOWN:
				_adjust(-STEP * (4.0 if big else 1.0))
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				if _phase == "summary":
					_end()
				else:
					_counter_offer()
			KEY_H, KEY_1:
				_accept(_b.offer if not _b.is_empty() else 0.0)
			KEY_X, KEY_N:
				_send_away()
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed and _phase == "talk":
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust(STEP)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust(-STEP)


func _pack() -> void:
	if _phase == "caught":
		return
	if _phase == "summary":
		_end()
		return
	_quit = true
	_summary()


func _adjust(d: float) -> void:
	if _phase != "talk":
		return
	_counter = maxf(_b.offer + STEP, snappedf(_counter + d, STEP))
	Sfx.play("pickup", -16.0, 1.0 + clampf(_counter / maxf(_b.fair, 1.0), 0.0, 2.0) * 0.2)


# Hiiren napit: ruudun asettelu sama kuin piirrossa (viitekoordinaatit 1280 x 720).
func _view() -> Dictionary:
	var sz := _root.size
	var s := minf(sz.x / W, sz.y / H)
	return {"s": s, "o": (sz - Vector2(W, H) * s) / 2.0}


func _btn_accept() -> Rect2:
	return Rect2(PANEL.position + Vector2(18, 112), Vector2(200, 46))


func _btn_counter() -> Rect2:
	return Rect2(PANEL.position + Vector2(232, 112), Vector2(230, 46))


func _btn_away() -> Rect2:
	return Rect2(PANEL.position + Vector2(476, 112), Vector2(184, 46))


func _btn_minus() -> Rect2:
	return Rect2(PANEL.position + Vector2(420, 52), Vector2(48, 46))


func _btn_plus() -> Rect2:
	return Rect2(PANEL.position + Vector2(604, 52), Vector2(48, 46))


func _gui(ev: InputEvent) -> void:
	if _done or not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	var v := _view()
	var m: Vector2 = (_root.get_local_mouse_position() - v.o) / v.s
	if _phase == "summary":
		_end()
	elif _phase == "talk":
		if _btn_accept().has_point(m):
			_accept(_b.offer)
		elif _btn_counter().has_point(m):
			_counter_offer()
		elif _btn_away().has_point(m):
			_send_away()
		elif _btn_plus().has_point(m):
			_adjust(STEP * 2.0)
		elif _btn_minus().has_point(m):
			_adjust(-STEP * 2.0)


# --- Piirto ---------------------------------------------------------------------------

func _draw_root() -> void:
	var v := _view()
	var ci := _root
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 14.0
	ci.draw_set_transform(v.o + sh, 0.0, Vector2(v.s, v.s))
	_draw_hall(ci)
	_draw_side_stalls(ci)
	_draw_watcher(ci)
	_draw_buyer(ci)
	_draw_table(ci)
	MG.sparks_draw(ci, _sparks)
	for f in _floats:
		var a := clampf(1.4 - f[2], 0.0, 1.0)
		var col: Color = f[3]
		ci.draw_string(ThemeDB.fallback_font, f[1] + Vector2(2, 2), f[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0, 0, 0, a * 0.6))
		ci.draw_string(ThemeDB.fallback_font, f[1], f[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(col.r, col.g, col.b, a))
	if _phase == "summary":
		_draw_summary(ci)
	else:
		_draw_panel(ci)
	_draw_bubble(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hall(ci: CanvasItem) -> void:
	# Seinä paneeleineen, ikkuna, viirinauha, ilmoitustaulu ja lankkulattia.
	MG.grad_rect(ci, Rect2(-600, -300, 2480, 700), Color(0.94, 0.86, 0.68), Color(0.84, 0.72, 0.52))
	ci.draw_rect(Rect2(-600, 290, 2480, 120), Color(0.62, 0.45, 0.3))
	for x in range(-600, 1900, 90):
		ci.draw_rect(Rect2(x + 6, 298, 78, 104), Color(0.7, 0.52, 0.35))
		ci.draw_rect(Rect2(x + 6, 298, 78, 5), Color(0.8, 0.62, 0.43))
	ci.draw_rect(Rect2(-600, 286, 2480, 8), Color(0.42, 0.28, 0.17))
	MG.wood(ci, Rect2(-600, 408, 2480, 520), Color(0.6, 0.43, 0.27), 70.0, 3, true)
	ci.draw_rect(Rect2(-600, 404, 2480, 6), Color(0.3, 0.2, 0.12))
	# Ikkuna
	var win := Rect2(70, 70, 190, 190)
	MG.glow(ci, win.get_center() + Vector2(120, 260), 260.0, Color(1.0, 0.95, 0.7, 0.25))
	MG.box(ci, win.grow(10), Color(0.95, 0.92, 0.85), 4, 6)
	MG.grad_rect(ci, win, Color(0.55, 0.78, 0.95), Color(0.85, 0.93, 0.98))
	ci.draw_circle(win.position + Vector2(130, 60), 22.0, Color(1.0, 0.97, 0.7, 0.9))
	ci.draw_colored_polygon(PackedVector2Array([win.position + Vector2(0, 190), win.position + Vector2(60, 130), win.position + Vector2(120, 165),
		win.position + Vector2(190, 120), win.position + Vector2(190, 190)]), Color(0.28, 0.5, 0.3))
	ci.draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color(0.95, 0.92, 0.85), 6.0)
	ci.draw_line(Vector2(win.position.x, win.get_center().y), Vector2(win.end.x, win.get_center().y), Color(0.95, 0.92, 0.85), 6.0)
	# Viirinauha
	var flags := [Color(0.85, 0.25, 0.2), Color(0.95, 0.8, 0.25), Color(0.25, 0.55, 0.8), Color(0.35, 0.7, 0.35)]
	var prev := Vector2(-60, 28)
	for i in 17:
		var x := -60.0 + i * 85.0
		var p := Vector2(x, 28.0 + 26.0 * sin(float(i) / 16.0 * PI))
		ci.draw_line(prev, p, Color(0.3, 0.22, 0.15), 2.0)
		if i > 0:
			var mid := (prev + p) / 2.0
			ci.draw_colored_polygon(PackedVector2Array([mid + Vector2(-16, 0), mid + Vector2(16, 0), mid + Vector2(0, 34)]), flags[i % 4])
		prev = p
	# Ilmoitustaulu
	var board := Rect2(960, 70, 250, 170)
	MG.box(ci, board.grow(8), Color(0.45, 0.3, 0.18), 4, 6)
	MG.box(ci, board, Color(0.78, 0.6, 0.38), 3)
	MG.sign(ci, Rect2(board.position + Vector2(22, 16), Vector2(206, 56)), "KIRPPIS\npöytäpaikka 2 €", Color(0.15, 0.4, 0.3), Color(1, 0.97, 0.85), 18)
	for note in [[Rect2(board.position + Vector2(24, 94), Vector2(60, 56)), Color(1, 0.95, 0.6)],
			[Rect2(board.position + Vector2(98, 90), Vector2(54, 62)), Color(0.95, 0.75, 0.8)],
			[Rect2(board.position + Vector2(166, 98), Vector2(60, 50)), Color(0.8, 0.92, 1.0)]]:
		MG.box(ci, note[0], note[1], 2, 2, MG.OUTLINE, 1)
		for ln in 3:
			ci.draw_line(note[0].position + Vector2(8, 14 + ln * 12), note[0].position + Vector2(note[0].size.x - 8, 14 + ln * 12), Color(0.3, 0.3, 0.35, 0.6), 1.5)
		ci.draw_circle(note[0].position + Vector2(note[0].size.x / 2.0, 4), 3.5, Color(0.8, 0.15, 0.15))


func _draw_side_stalls(ci: CanvasItem) -> void:
	# Hilkan liinapöytä vasemmalla ja Taunon työkalupöytä oikealla, kauempana. Hilkka istuu liinojensa takana.
	MG.person(ci, Vector2(120, 285), 0.8, HILKKA_LOOK, Vector2(1, 0.2), false)
	for t in [Vector2(10, 360), Vector2(1030, 360)]:
		var top := Rect2(t, Vector2(260, 24))
		MG.solid(ci, top, Color(0.58, 0.4, 0.24))
		MG.box(ci, Rect2(t + Vector2(8, 24), Vector2(244, 46)), Color(0.92, 0.9, 0.82), 3, 0, MG.OUTLINE, 1)
	for i in 4:  # liinat
		var x := 40.0 + i * 52.0
		MG.box(ci, Rect2(Vector2(x, 340), Vector2(44, 20)), [Color(0.95, 0.95, 0.9), Color(0.9, 0.6, 0.7), Color(0.6, 0.75, 0.9), Color(0.95, 0.85, 0.5)][i], 3, 0, MG.OUTLINE, 1)
	for i in 3:  # työkalut
		var x := 1060.0 + i * 70.0
		ci.draw_rect(Rect2(x, 346, 12, 14), Color(0.6, 0.6, 0.65))
		ci.draw_rect(Rect2(x + 3, 330, 6, 18), Color(0.55, 0.35, 0.18))
	MG.sign(ci, Rect2(60, 392, 140, 22), "HILKKA", Color(0.55, 0.3, 0.45), Color(1, 1, 1), 14)


func _draw_watcher(ci: CanvasItem) -> void:
	if _b.get("type", "") == "annaliisa" and _phase != "summary":
		return  # hän on itse pöydän ääressä
	var look := (TYPES.annaliisa.look as Dictionary).duplicate()
	var c := Vector2(1130, 300)
	var looking := _watching()
	var gaze := Vector2(-1.0, 0.4) if looking else Vector2(0.9, -0.3)
	MG.person(ci, c, 0.85, look, gaze, _phase == "caught")
	# Penkki ja silmämerkki: punainen = katsoo pöytään, vihreä = katsoo muualle.
	MG.box(ci, Rect2(c + Vector2(-48, 70), Vector2(96, 14)), Color(0.5, 0.33, 0.2), 3, 0, MG.OUTLINE, 1)
	var ec := c + Vector2(0, -62)
	var warn := not looking and _watch_t > WATCH_SAFE.y - 0.7
	var col := Color(0.85, 0.2, 0.18) if looking else Color(0.3, 0.75, 0.35)
	if warn:
		col = Color(0.95, 0.65, 0.15)
	MG.box(ci, Rect2(ec + Vector2(-26, -16), Vector2(52, 32)), Color(1, 1, 1, 0.92), 14, 3, col, 3)
	ci.draw_circle(ec, 9.0, col)
	ci.draw_circle(ec + (Vector2(-3, 0) if looking else Vector2(4, -2)), 4.0, Color(0.05, 0.05, 0.05))
	if not looking:
		ci.draw_line(ec + Vector2(-22, 14), ec + Vector2(22, -14), Color(0.3, 0.75, 0.35), 3.0)
	if warn:
		ci.draw_string(ThemeDB.fallback_font, ec + Vector2(-60, -28), "kääntyy!", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(0.95, 0.65, 0.15))


func _draw_buyer(ci: CanvasItem) -> void:
	if _b.is_empty() or _phase == "summary":
		return
	var td: Dictionary = TYPES[_b.type]
	var look: Dictionary = td.look
	var walking := _phase in ["arrive", "leave"] or (_phase == "caught" and _pt > 1.2)
	var bob := absf(sin(_t * 9.0)) * 8.0 if walking else sin(_t * 1.6) * 2.0
	var c := Vector2(_bx, 232.0 - bob)
	var eye := Vector2(0, 0.2)
	if _phase == "leave" and _mood < 0:
		eye = Vector2(_b.side, 0)
	var talking := _phase == "talk" and _line != "" and not _line_me and fmod(_t, 0.4) < 0.2
	MG.person(ci, c, 1.9, look, eye, talking)
	# Pienet ärtymysmerkit tai tyytyväisyys pään yläpuolelle.
	if _mood < 0 and _phase in ["talk", "leave"]:
		for a in 3:
			ci.draw_line(c + Vector2(-60 + a * 12, -68), c + Vector2(-48 + a * 12, -82), Color(0.9, 0.25, 0.2), 4.0)
	elif _mood > 0:
		ci.draw_string(ThemeDB.fallback_font, c + Vector2(50, -60), "♥" if _b.type != "nuori" else "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.9, 0.3, 0.4))


func _draw_table(ci: CanvasItem) -> void:
	# Pöytälevy, ruudullinen pöytäliina, tavarat hintalappuineen ja kassarasia.
	var top := Rect2(230, TABLE_TOP, 820, 96)
	MG.solid(ci, top, Color(0.68, 0.5, 0.3))
	ci.draw_rect(Rect2(230, TABLE_TOP + 90, 820, 10), Color(0.4, 0.27, 0.15))
	for i in 7:
		ci.draw_line(Vector2(240, TABLE_TOP + 12 + i * 12), Vector2(1040, TABLE_TOP + 12 + i * 12), Color(0.45, 0.3, 0.17, 0.35), 1.5)
	# Liina etupuolella.
	var cloth := Rect2(246, TABLE_TOP + 98, 788, 300)
	ci.draw_rect(cloth, Color(0.96, 0.94, 0.9))
	for gx in range(0, 788, 40):
		ci.draw_rect(Rect2(cloth.position.x + gx, cloth.position.y, 20, cloth.size.y), Color(0.82, 0.2, 0.2, 0.55))
	for gy in range(0, 300, 40):
		ci.draw_rect(Rect2(cloth.position.x, cloth.position.y + gy, cloth.size.x, 20), Color(0.82, 0.2, 0.2, 0.55))
	for fx in range(0, 788, 98):  # laskokset
		ci.draw_line(cloth.position + Vector2(fx + 20, 4), cloth.position + Vector2(fx + 14, 296), Color(0, 0, 0, 0.12), 6.0)
	ci.draw_rect(Rect2(cloth.position.x - 4, cloth.position.y - 2, cloth.size.x + 8, 8), Color(0.72, 0.15, 0.15))
	ci.draw_rect(cloth, MG.OUTLINE, false, 2.0)
	# Tavarat.
	var shown: Array = []
	for k in ORDER:
		if int(_left.get(k, 0)) > 0:
			shown.append(k)
	var span := 640.0 / maxf(shown.size(), 1.0)
	for i in shown.size():
		var k: String = shown[i]
		var x := 300.0 + span * (i + 0.5)
		var base := Vector2(x, TABLE_TOP + 62)
		_icon(ci, k, base, 1.0)
		var n: int = _left[k]
		var tag := Rect2(base + Vector2(-38, 12), Vector2(76, 24))
		MG.sign(ci, tag, "%s €" % _eur(GOODS[k].fair), Color(1, 0.96, 0.7), INK, 15, Color(0.4, 0.3, 0.2))
		ci.draw_circle(base + Vector2(30, -40), 13.0, Color(0.15, 0.4, 0.3))
		ci.draw_string(ThemeDB.fallback_font, base + Vector2(17, -34), "%d" % n, HORIZONTAL_ALIGNMENT_CENTER, 26, 17, Color.WHITE)
	if shown.is_empty():
		MG.sign(ci, Rect2(520, TABLE_TOP + 20, 240, 50), "Pöytä tyhjä", Color(0.9, 0.85, 0.7), INK, 22, Color(0.4, 0.3, 0.2))
	# Kassarasia oikealla.
	var box := Rect2(940, TABLE_TOP + 44, 82, 40)
	MG.solid(ci, box, Color(0.45, 0.5, 0.55))
	ci.draw_rect(Rect2(box.position + Vector2(4, 4), Vector2(74, 14)), Color(0.12, 0.12, 0.14))
	for i in _coins:
		ci.draw_circle(box.position + Vector2(10 + (i % 7) * 10, 14 - (i / 7) * 4), 5.0, Color(0.95, 0.8, 0.25))
		ci.draw_arc(box.position + Vector2(10 + (i % 7) * 10, 14 - (i / 7) * 4), 5.0, 0, TAU, 10, Color(0.5, 0.35, 0.05), 1.0)
	# Tiskin alla: kauppakassi, josta pullon kaulat pistävät esiin.
	var under := int(_left.get("kalja", 0)) + int(_left.get("pontikka", 0))
	if under > 0:
		var bag := Rect2(160, TABLE_TOP + 150, 110, 120)
		MG.grad_rect(ci, bag, Color(0.93, 0.9, 0.82), Color(0.78, 0.74, 0.62))
		ci.draw_rect(bag, MG.OUTLINE, false, 2.0)
		ci.draw_line(bag.position + Vector2(24, 0), bag.position + Vector2(40, -22), Color(0.6, 0.55, 0.45), 4.0)
		ci.draw_line(bag.position + Vector2(86, 0), bag.position + Vector2(70, -22), Color(0.6, 0.55, 0.45), 4.0)
		for b in mini(under, 3):
			var bx := bag.position.x + 22 + b * 32
			ci.draw_rect(Rect2(bx, bag.position.y - 30, 12, 34), Color(0.2, 0.5, 0.25))
			ci.draw_rect(Rect2(bx - 1, bag.position.y - 34, 14, 6), Color(0.85, 0.7, 0.2))
		ci.draw_string(ThemeDB.fallback_font, bag.position + Vector2(0, 66), "tiskin alta", HORIZONTAL_ALIGNMENT_CENTER, 110, 17, Color(0.3, 0.22, 0.15))
		ci.draw_string(ThemeDB.fallback_font, bag.position + Vector2(0, 90), "×%d" % under, HORIZONTAL_ALIGNMENT_CENTER, 110, 20, Color(0.3, 0.22, 0.15))


## Tuotteen kuvake: base = keskipiste pöydän pinnalla.
func _icon(ci: CanvasItem, id: String, base: Vector2, sc: float) -> void:
	var sh := PackedVector2Array()
	for a in 16:
		sh.append(base + Vector2(cos(a / 16.0 * TAU) * 32.0, 5.0 + sin(a / 16.0 * TAU) * 7.0) * sc)
	ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.2))
	match id:
		"puolukka", "mustikka":
			var berry: Color = Color(0.82, 0.12, 0.18) if id == "puolukka" else Color(0.22, 0.22, 0.55)
			var tub := Rect2(base + Vector2(-26, -26) * sc, Vector2(52, 34) * sc)
			for i in 12:  # marjakasa
				ci.draw_circle(base + Vector2(-22 + (i % 6) * 8.5, -30 - (i / 6) * 6 + sin(i * 2.3) * 3) * sc, 5.5 * sc, berry.darkened(0.15))
				ci.draw_circle(base + Vector2(-23 + (i % 6) * 8.5, -31 - (i / 6) * 6 + sin(i * 2.3) * 3) * sc, 4.5 * sc, berry)
				ci.draw_circle(base + Vector2(-25 + (i % 6) * 8.5, -33 - (i / 6) * 6 + sin(i * 2.3) * 3) * sc, 1.5 * sc, berry.lightened(0.5))
			MG.solid(ci, tub, Color(0.62, 0.42, 0.22))
			ci.draw_line(tub.position + Vector2(0, 14) * sc, tub.end - Vector2(0, 20) * sc, Color(0.4, 0.26, 0.12), 1.5)
			ci.draw_line(tub.position + Vector2(0, 24) * sc, tub.end - Vector2(0, 10) * sc, Color(0.4, 0.26, 0.12), 1.5)
		"kantarelli":
			for p in [Vector2(-16, 0), Vector2(2, -4), Vector2(18, 2)]:
				var o: Vector2 = base + p * sc
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-4, 6) * sc, o + Vector2(4, 6) * sc, o + Vector2(7, -20) * sc, o + Vector2(-7, -20) * sc]), Color(0.95, 0.72, 0.18))
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-16, -22) * sc, o + Vector2(-8, -30) * sc, o + Vector2(8, -30) * sc,
					o + Vector2(16, -22) * sc, o + Vector2(10, -16) * sc, o + Vector2(0, -20) * sc, o + Vector2(-10, -16) * sc]), Color(1.0, 0.8, 0.25))
				ci.draw_line(o + Vector2(-12, -23) * sc, o + Vector2(12, -23) * sc, Color(1.0, 0.92, 0.55), 2.0)
				ci.draw_line(o + Vector2(-4, -17) * sc, o + Vector2(-2, 4) * sc, Color(0.8, 0.55, 0.1), 1.5)
		"herkkutatti":
			for p in [Vector2(-14, 4), Vector2(14, 0)]:
				var o: Vector2 = base + p * sc
				MG.solid(ci, Rect2(o + Vector2(-7, -22) * sc, Vector2(14, 28) * sc), Color(0.93, 0.87, 0.7), false)
				ci.draw_circle(o + Vector2(0, -24) * sc, 17.0 * sc, Color(0.45, 0.28, 0.14))
				ci.draw_circle(o + Vector2(-2, -27) * sc, 15.0 * sc, Color(0.62, 0.4, 0.2))
				ci.draw_circle(o + Vector2(-7, -33) * sc, 5.0 * sc, Color(0.8, 0.6, 0.38))
				ci.draw_rect(Rect2(o + Vector2(-15, -22) * sc, Vector2(30, 5) * sc), Color(0.9, 0.82, 0.55))
		"savukala":
			var o := base + Vector2(0, -16) * sc
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(34, 0) * sc, o + Vector2(50, -14) * sc, o + Vector2(50, 14) * sc]), Color(0.55, 0.32, 0.1))
			var body := PackedVector2Array()
			for a in 20:
				var th := a / 20.0 * TAU
				body.append(o + Vector2(cos(th) * 36.0, sin(th) * 15.0) * sc)
			ci.draw_colored_polygon(body, Color(0.7, 0.45, 0.15))
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-30, -3) * sc, o + Vector2(0, -12) * sc, o + Vector2(30, -3) * sc,
				o + Vector2(0, 0) * sc]), Color(0.88, 0.65, 0.25))
			ci.draw_arc(o + Vector2(-17, 0) * sc, 11.0 * sc, -1.2, 1.2, 8, Color(0.4, 0.22, 0.06), 2.0)
			ci.draw_circle(o + Vector2(-26, -3) * sc, 3.0 * sc, Color.BLACK)
			ci.draw_polyline(body + PackedVector2Array([body[0]]), MG.OUTLINE, 2.0)
			for sx in 4:
				ci.draw_line(o + Vector2(-4 + sx * 9, -8) * sc, o + Vector2(-1 + sx * 9, 8) * sc, Color(0.5, 0.3, 0.08, 0.5), 1.5)
		"savuriista":
			var o := base + Vector2(0, -18) * sc
			ci.draw_line(o + Vector2(14, 8) * sc, o + Vector2(40, 22) * sc, Color(0.95, 0.9, 0.78), 7.0 * sc)
			ci.draw_circle(o + Vector2(42, 24) * sc, 6.0 * sc, Color(0.95, 0.9, 0.78))
			MG.ball(ci, o + Vector2(-4, 0) * sc, 24.0 * sc, Color(0.55, 0.3, 0.14), 0.35)
			ci.draw_circle(o + Vector2(-12, -9) * sc, 7.0 * sc, Color(0.8, 0.55, 0.28, 0.7))
			ci.draw_line(o + Vector2(-16, 6) * sc, o + Vector2(8, 10) * sc, Color(0.35, 0.18, 0.07), 2.0)
		"kalja":
			var o := base + Vector2(0, 6) * sc
			MG.solid(ci, Rect2(o + Vector2(-12, -42) * sc, Vector2(24, 44) * sc), Color(0.2, 0.5, 0.25), false)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-12, -42) * sc, o + Vector2(12, -42) * sc, o + Vector2(5, -58) * sc, o + Vector2(-5, -58) * sc]), Color(0.18, 0.45, 0.22))
			ci.draw_rect(Rect2(o + Vector2(-6, -66) * sc, Vector2(12, 10) * sc), Color(0.2, 0.5, 0.25))
			ci.draw_rect(Rect2(o + Vector2(-7, -69) * sc, Vector2(14, 5) * sc), Color(0.85, 0.7, 0.2))
			MG.box(ci, Rect2(o + Vector2(-12, -34) * sc, Vector2(24, 20) * sc), Color(0.95, 0.88, 0.5), 1, 0, MG.OUTLINE, 1)
			ci.draw_string(ThemeDB.fallback_font, o + Vector2(-12, -19) * sc, "KALJA", HORIZONTAL_ALIGNMENT_CENTER, 24 * sc, int(8 * sc), INK)
			ci.draw_line(o + Vector2(-8, -40) * sc, o + Vector2(-8, -4) * sc, Color(1, 1, 1, 0.4), 2.0)
		"pontikka":
			var o := base + Vector2(0, 6) * sc
			var glass := Color(0.75, 0.88, 0.92, 0.9)
			MG.solid(ci, Rect2(o + Vector2(-14, -40) * sc, Vector2(28, 42) * sc), glass, false)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-14, -40) * sc, o + Vector2(14, -40) * sc, o + Vector2(5, -56) * sc, o + Vector2(-5, -56) * sc]), glass.darkened(0.08))
			ci.draw_rect(Rect2(o + Vector2(-5, -66) * sc, Vector2(10, 12) * sc), glass)
			ci.draw_rect(Rect2(o + Vector2(-6, -70) * sc, Vector2(12, 6) * sc), Color(0.7, 0.5, 0.3))
			ci.draw_rect(Rect2(o + Vector2(-13, -18) * sc, Vector2(26, 18) * sc), Color(1, 1, 1, 0.25))
			ci.draw_rect(Rect2(o + Vector2(-13, -34) * sc, Vector2(26, 13) * sc), Color(0.96, 0.93, 0.8))
			ci.draw_string(ThemeDB.fallback_font, o + Vector2(-13, -24) * sc, "PK", HORIZONTAL_ALIGNMENT_CENTER, 26 * sc, int(10 * sc), Color(0.15, 0.15, 0.45))
			ci.draw_line(o + Vector2(-10, -38) * sc, o + Vector2(-10, -2) * sc, Color(1, 1, 1, 0.5), 2.0)
			ci.draw_rect(Rect2(o + Vector2(-14, -40) * sc, Vector2(28, 42) * sc), MG.OUTLINE, false, 1.5)


func _draw_bubble(ci: CanvasItem) -> void:
	if _line == "" or _phase in ["summary", "arrive"]:
		return
	var font := ThemeDB.fallback_font
	var w := 440.0
	var size := 22
	var lines := _wrap(_line, font, size, w - 28.0)
	var h := 20.0 + lines.size() * 28.0
	var r: Rect2
	var tail: Vector2
	if _line_me:
		r = Rect2(Vector2(70, 130), Vector2(w, h))
		tail = Vector2(180, 130 + h + 50)
	elif _phase == "caught":  # Anna-Liisa huutaa penkiltään
		r = Rect2(Vector2(640, 40), Vector2(w, h))
		tail = Vector2(1120, 250)
	else:
		r = Rect2(Vector2(clampf(_bx - 40, 40, 500), 66), Vector2(w, h))
		tail = Vector2(_bx + 10, 160)
	MG.box(ci, r, Color.WHITE if not _line_me else Color(1, 0.96, 0.75), 14, 5, MG.OUTLINE, 2)
	var base := Vector2(clampf(tail.x, r.position.x + 24, r.end.x - 24), r.end.y if tail.y > r.end.y else r.position.y)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-12, -2), base + Vector2(12, -2), tail]), Color.WHITE if not _line_me else Color(1, 0.96, 0.75))
	for i in lines.size():
		ci.draw_string(font, r.position + Vector2(14, 34 + i * 28), lines[i], HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, size, INK)


static func _wrap(text: String, font: Font, size: int, width: float) -> Array:
	var out: Array = []
	var cur := ""
	for word in text.split(" "):
		var trial := word if cur == "" else cur + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = trial
	if cur != "":
		out.append(cur)
	return out


func _draw_panel(ci: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	MG.box(ci, PANEL, Color(0.1, 0.08, 0.07, 0.9), 14, 8, Color(0.95, 0.8, 0.3), 3)
	var p := PANEL.position
	if _phase != "talk":
		ci.draw_string(font, p + Vector2(0, 96), "Myyty %d €  ·  asiakkaita %d/%d" % [roundi(_income), _served, MAX_BUYERS],
			HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, 24, Color(1, 0.95, 0.7))
		return
	var td: Dictionary = TYPES[_b.type]
	ci.draw_string(font, p + Vector2(18, 30), "%s (%s) ostaa %s" % [td.name, td.tag, _qty_text(_b.item, _b.qty)], HORIZONTAL_ALIGNMENT_LEFT, 640, 20, Color(0.85, 0.85, 0.9))
	ci.draw_string(font, p + Vector2(18, 56), "Tarjous", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.7, 0.7, 0.75))
	ci.draw_string(font, p + Vector2(18, 94), "%s €" % _eur(_b.offer), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 0.9, 0.4))
	ci.draw_string(font, p + Vector2(180, 56), "Reilu hinta %s €" % _eur(_b.fair), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.7, 0.7, 0.75))
	ci.draw_string(font, p + Vector2(180, 90), "Kärsivällisyys:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.7, 0.75))
	for i in int(td.patience):  # sydämet = jäljellä olevat yritykset
		var on: bool = i < int(_b.patience)
		ci.draw_circle(p + Vector2(300 + i * 18, 85), 6.0, Color(0.9, 0.35, 0.4) if on else Color(0.3, 0.25, 0.25))
	# Vastatarjous
	ci.draw_string(font, p + Vector2(420, 44), "Vastatarjous", HORIZONTAL_ALIGNMENT_LEFT, 232, 16, Color(0.7, 0.7, 0.75))
	_button(ci, _btn_minus(), "−", Color(0.35, 0.3, 0.3))
	_button(ci, _btn_plus(), "+", Color(0.35, 0.3, 0.3))
	var cr := Rect2(_btn_minus().end.x + 4, _btn_minus().position.y, _btn_plus().position.x - _btn_minus().end.x - 8, 46)
	ci.draw_string(font, Vector2(cr.position.x, cr.position.y + 34), "%s €" % _eur(_counter), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 28, Color.WHITE)
	var risky: bool = _b.under
	var safe := not _watching()
	var acol := Color(0.2, 0.55, 0.3)
	var atxt := "Hyväksy [H]"
	if risky:
		acol = Color(0.2, 0.55, 0.3) if safe else Color(0.7, 0.2, 0.18)
		atxt = "Tiskin alta [H]" if safe else "Anna-Liisa kyttää!"
	_button(ci, _btn_accept(), atxt, acol)
	_button(ci, _btn_counter(), "Tarjoa %s € [Väli]" % _eur(_counter), Color(0.72, 0.55, 0.12))
	_button(ci, _btn_away(), "Ei kiitos [X]", Color(0.5, 0.25, 0.22))


func _button(ci: CanvasItem, r: Rect2, text: String, col: Color) -> void:
	var v := _view()
	var m: Vector2 = (_root.get_local_mouse_position() - v.o) / v.s
	var hot := r.has_point(m)
	MG.solid(ci, r, col.lightened(0.12) if hot else col)
	ci.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + r.size.y * 0.66), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 19, Color.WHITE)


func _draw_summary(ci: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	var r := Rect2(330, 120, 620, 520)
	MG.box(ci, Rect2(r.position + Vector2(0, 0), r.size), Color(0.99, 0.96, 0.85), 14, 10, Color(0.4, 0.28, 0.15), 4)
	MG.sign(ci, Rect2(r.position + Vector2(130, 20), Vector2(360, 54)), "PÖYTÄ PAKATTU", Color(0.15, 0.4, 0.3), Color(1, 0.97, 0.85), 28)
	var y := r.position.y + 112.0
	var any := false
	for k in ORDER + ["kalja", "pontikka"]:
		if int(_sold.get(k, 0)) <= 0:
			continue
		any = true
		_icon(ci, k, Vector2(r.position.x + 60, y + 18), 0.6)
		ci.draw_string(font, Vector2(r.position.x + 110, y + 8), "%s × %d" % [GOODS[k].name, _sold[k]], HORIZONTAL_ALIGNMENT_LEFT, 300, 24, INK)
		y += 46.0
	if not any:
		ci.draw_string(font, Vector2(r.position.x, y + 20), "Mitään ei mennyt kaupaksi.", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, INK)
	ci.draw_line(Vector2(r.position.x + 40, r.end.y - 150), Vector2(r.end.x - 40, r.end.y - 150), Color(0.4, 0.28, 0.15), 2.0)
	ci.draw_string(font, Vector2(r.position.x, r.end.y - 100), "Tulot %s €" % _eur(_income), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, Color(0.15, 0.4, 0.2))
	var tcol := Color(0.15, 0.4, 0.2) if _rep > 0 else (Color(0.7, 0.2, 0.15) if _rep < 0 else Color(0.35, 0.3, 0.25))
	ci.draw_string(font, Vector2(r.position.x, r.end.y - 56), "\"%s\"" % _title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, tcol)
	ci.draw_string(font, Vector2(r.position.x, r.end.y - 22), "Asiakkaita %d · reiluja kauppoja %d · tylysti kotiin %d" % [_served, _good, _greedy],
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Color(0.45, 0.4, 0.35))
