extends CanvasLayer
## Siitarin hedelmäpeli (siitari_interior.gd "hedelmapeli"): vanha kolmirullainen peli. Valaistu yläpaneeli,
## voittotaulukko, kolme rullaa ja keskellä voittolinja. Panos 1 €. Kolme samaa linjalla voittaa taulukon mukaan,
## kirsikka ensimmäisellä rullalla antaa panoksen takaisin ja kaksi kirsikkaa 3 €. Häviön jälkeen rullia voi lukita
## (1, 2, 3), mutta ei kahdesti peräkkäin. Voiton voi tuplata: kortti 1–6 PIENI, 8–13 SUURI, seiska vie aina.
## E pelaa, voiton jälkeen E vie voiton talteen, vasen = pieni, oikea = suuri. F / Esc lopettaa (voitto talteen).
## finished(money): rahat pelin jälkeen.

signal finished(money: float)
signal comment(text: String)

const MG := preload("res://scripts/mg_draw.gd")

const BET := 1.0
const SYMBOLS := ["kirsikka", "sitruuna", "appelsiini", "luumu", "rypale", "meloni", "kello", "bar", "seiska"]
const WEIGHTS := [5, 4, 4, 3, 3, 2, 2, 1, 1]
const PAY := {"kirsikka": 10, "sitruuna": 8, "appelsiini": 10, "luumu": 12, "rypale": 15, "meloni": 20, "kello": 30, "bar": 50,
	"seiska": 100}
const NAMES := {"kirsikka": "Kirsikka", "sitruuna": "Sitruuna", "appelsiini": "Appelsiini", "luumu": "Luumu", "rypale": "Viinirypäle",
	"meloni": "Meloni", "kello": "Kello", "bar": "BAR", "seiska": "Seiska"}
const SYM_H := 110.0       # yhden symbolin korkeus rullassa
const STOP_AT := [0.9, 1.35, 1.8]
const TUPLA_MAX := 50.0
const LINES := ["Vanha kunnon hedelmäpeli. Kolme kirsikkaa ja Päivi saa uuden kahvinkeittimen.",
	"Seurue sano, että tänään se on ollu nuuka. Ehkä sulle se on armollinen.",
	"Lukitse kaksi samaa ja toivo kolmatta. Niin ne vanhat konkarit pelaa."]

var money := 10.0
var drunk := 0.0

var _root: Control
var _info: Label
var _keys: Control
var _tip: Label
var _strip: Array[String] = []   # rullanauha (sama kaikilla rullilla, eri aloituskohta)
var _pos: Array[float] = [0.0, 0.0, 0.0]   # rullan asento symboleina (desimaali = välissä)
var _target: Array[int] = [0, 0, 0]
var _spin_from: Array[float] = [0.0, 0.0, 0.0]
var _stopped: Array[bool] = [true, true, true]
var _locked: Array[bool] = [false, false, false]
var _lock_ok := false            # lukitus sallittu (edellinen kierros hävisi eikä ollut lukittu)
var _was_locked := false
## Vaihe: "idle" (odottaa panosta), "spin", "win" (voitto odottaa: talteen tai tuplaus), "tupla" (kortti kääntyy).
var _phase := "idle"
var _spin_t := 0.0
var _win := 0.0
var _card := 0
var _card_t := 0.0
var _guess := ""
var _t := 0.0
var _done := false
var _flash := 0.0
var _shake := 0.0
var _sparks: Array = []
var _coins: Array = []           # tarjottimelle putoavat kolikot [paikka, nopeus, viive]
var _tray := 0
var _msg := ""
var _btn_flash := ""


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_root)
	add_child(_root)
	_info = _label(24, 30.0, false)
	_keys = preload("res://scripts/hint_bar.gd").new()  # näppäinohjeet hattuina, näppäimet asetuksista
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_tip = _label(22, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	comment.connect(func(t: String) -> void: _tip.text = t)
	for i in SYMBOLS.size():
		for k in WEIGHTS[i]:
			_strip.append(SYMBOLS[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(_strip.size() - 1, 0, -1):  # sekoitettu, mutta aina sama nauha
		var j := rng.randi_range(0, i)
		var tmp := _strip[i]
		_strip[i] = _strip[j]
		_strip[j] = tmp
	for r in 3:
		_pos[r] = float(randi() % _strip.size())
	_msg = "PANOS 1 €"
	comment.emit(LINES.pick_random())


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


func _sym(r: int, off := 0) -> String:
	var n := _strip.size()
	return _strip[(int(roundf(_pos[r])) + off + n * 4) % n]


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_root.queue_redraw()
	_flash = maxf(0.0, _flash - delta)
	_shake = maxf(0.0, _shake - delta * 3.0)
	MG.sparks_step(_sparks, delta)
	_coin_step(delta)
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		if _phase == "spin" or _phase == "tupla":
			return
		_finish()
		return
	match _phase:
		"idle":
			if _lock_ok:
				for r in 3:
					if Input.is_key_pressed(KEY_1 + r) and not _key_held(r):
						_locked[r] = not _locked[r]
						_btn_flash = "lukko%d" % r
						Sfx.play("pickup", -12.0, 1.4)
				_held = [Input.is_key_pressed(KEY_1), Input.is_key_pressed(KEY_2), Input.is_key_pressed(KEY_3)]
			if Input.is_action_just_pressed("interact"):
				_play()
		"spin":
			_spin_step(delta)
		"win":
			if Input.is_action_just_pressed("interact"):
				_collect()
			elif Input.is_action_just_pressed("left"):
				_double("pieni")
			elif Input.is_action_just_pressed("right"):
				_double("suuri")
		"tupla":
			_card_t += delta
			if _card_t > 1.1:
				_double_result()
	_info.text = "HEDELMÄPELI · Rahaa %s €%s" % [_eur(money), "  ·  Voitto %s €" % _eur(_win) if _win > 0.0 else ""]
	match _phase:
		"idle":
			_keys.set_text("%s pelaa (1 €)%s   %s lopeta" % [Settings.cap("interact"),
				"   [1] [2] [3] lukitse rulla" if _lock_ok else "", Settings.cap("mount")])
		"win":
			_keys.set_text("%s voitot talteen   %s tuplaa PIENI (1–6)   %s tuplaa SUURI (8–13)" % [Settings.cap("interact"),
				Settings.cap("left"), Settings.cap("right")])
		_:
			_keys.set_text("")


var _held := [false, false, false]


func _key_held(r: int) -> bool:
	return _held[r]


func _eur(v: float) -> String:
	return ("%.2f" % v).replace(".", ",").trim_suffix(",00")


func _play() -> void:
	if money < BET:
		comment.emit("Rahat loppu. Kone vilkuttaa valojaan, mutta velaksi se ei pelaa.")
		return
	money -= BET
	_was_locked = _locked.has(true)
	Sfx.play("coin", -10.0, 1.3)
	Sfx.play("rattle", -14.0, 1.2)
	_phase = "spin"
	_card = 0
	_spin_t = 0.0
	_msg = ""
	var n := _strip.size()
	for r in 3:
		_stopped[r] = _locked[r]
		_spin_from[r] = _pos[r]
		# Pysähdyskohta arvotaan, ja rulla pyörii sinne vähintään kolme kierrosta.
		_target[r] = int(roundf(_pos[r])) if _locked[r] else int(_pos[r]) + n * (3 + r) + randi() % n


func _spin_step(delta: float) -> void:
	_spin_t += delta
	var n := _strip.size()
	for r in 3:
		if _stopped[r]:
			continue
		var t := clampf(_spin_t / STOP_AT[r], 0.0, 1.0)
		# Nopea pyöritys, joka hidastuu pysähdyskohtaan, ja lopussa pieni nytkähdys (mekaaninen pysäytin).
		var e := 1.0 - pow(1.0 - t, 3.0)
		_pos[r] = lerpf(_spin_from[r], float(_target[r]), e) + (sin(t * PI * 3.0) * 0.06 if t > 0.85 else 0.0)
		if t >= 1.0:
			_stopped[r] = true
			_pos[r] = float(_target[r] % n)
			_shake = 0.25
			Sfx.play("pickup", -8.0, 0.8 + r * 0.1)
	if not _stopped.has(false):
		_resolve()


func _resolve() -> void:
	var a := _sym(0)
	var b := _sym(1)
	var c := _sym(2)
	_win = 0.0
	if a == b and b == c:
		_win = PAY[a]
	elif a == "kirsikka" and b == "kirsikka":
		_win = 3.0
	elif a == "kirsikka":
		_win = 1.0
	_locked = [false, false, false]
	if _win > 0.0:
		_phase = "win"
		_lock_ok = false
		_flash = 1.5
		_msg = "VOITTO %s €" % _eur(_win)
		if _win >= 10.0:
			Sfx.play("win", -4.0)
			MG.sparks_burst(_sparks, _reel_rect(1).get_center(), Color(1.0, 0.85, 0.2), 50)
			comment.emit("Kolme %s! Koneen valot vilkkuu ja koko Siitari kuulee kellon." % NAMES[a].to_lower() if a != "bar" else
				"Kolme BARia! Nyt kelpaa.")
		else:
			Sfx.play("win_small", -6.0)
			MG.sparks_burst(_sparks, _reel_rect(0).get_center(), Color(1.0, 0.4, 0.4), 16)
	else:
		_phase = "idle"
		_lock_ok = not _was_locked
		_msg = "LUKITSE?" if _lock_ok else "PANOS 1 €"
		if _lock_ok and (a == b or b == c or a == c):
			comment.emit("Kaksi samaa! Lukitse ne (1 2 3) ja yritä kolmatta.")


func _collect() -> void:
	_pay(_win)
	_win = 0.0
	_card = 0
	_phase = "idle"
	_msg = "PANOS 1 €"


func _pay(amount: float) -> void:
	var n := int(amount)
	for k in n:
		_coins.append([_tray_rect().get_center() + Vector2(randf_range(-40, 40), -150.0), Vector2(randf_range(-60, 60), randf_range(-120, 0)),
			-k * 0.07])
	money += amount - n  # sentit suoraan


func _double(guess: String) -> void:
	_guess = guess
	_card = randi_range(1, 13)
	_card_t = 0.0
	_phase = "tupla"
	_btn_flash = guess
	Sfx.play("cloth", -10.0, 1.4)


func _double_result() -> void:
	var ok := (_guess == "pieni" and _card <= 6) or (_guess == "suuri" and _card >= 8)
	if ok:
		_win *= 2.0
		_flash = 1.0
		Sfx.play("win_small", -6.0, 1.1)
		_msg = "TUPLAUS %s €" % _eur(_win)
		if _win >= TUPLA_MAX:
			comment.emit("Tuplausraja täynnä. Kone maksaa voiton ulos.")
			_collect()
			return
		_phase = "win"
	else:
		Sfx.play("lose", -6.0)
		comment.emit("Seiska! Seiska vie aina." if _card == 7 else ["Väärin arvattu. Voitto meni.", "Ahneella on paskanen loppu."].pick_random())
		_win = 0.0
		_msg = "PANOS 1 €"
		_phase = "idle"
		_lock_ok = false


func _coin_step(delta: float) -> void:
	for c in _coins:
		c[2] += delta
		if c[2] < 0.0:
			continue
		c[1].y += 900.0 * delta
		c[0] += c[1] * delta
	for i in range(_coins.size() - 1, -1, -1):
		var c: Array = _coins[i]
		if c[2] > 0.0 and c[0].y > _tray_rect().end.y - 12.0:
			_coins.remove_at(i)
			_tray += 1
			money += 1.0
			Sfx.play("coin", -12.0, randf_range(0.9, 1.3))


func _finish() -> void:
	if _win > 0.0:
		money += _win
	money += _coins.size()
	_coins.clear()
	_done = true
	finished.emit(money)
	queue_free()


# --- Piirto -------------------------------------------------------------------

## Kaappi piirretään 600 x 800 -kehykseen, joka skaalataan ruudun korkeuteen (ylhäällä otsikko, alhaalla vinkki ja napit).
var _k := 1.0


func _cab() -> Rect2:
	var vs := _root.size / _k
	return Rect2(Vector2(vs.x / 2.0 - 300, 62.0 / _k), Vector2(600, 800))


func _reel_rect(r: int) -> Rect2:
	var c := _cab()
	return Rect2(c.position + Vector2(66 + r * 166, 330), Vector2(136, 230))


func _tray_rect() -> Rect2:
	var c := _cab()
	return Rect2(c.position + Vector2(140, c.size.y - 70), Vector2(320, 46))


func _draw_root() -> void:
	var sz := _root.size
	var font := ThemeDB.fallback_font
	_draw_bar_wall(sz)
	_k = minf(1.0, (sz.y - 170.0) / 800.0)
	var cab := _cab()
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 4.0
	_root.draw_set_transform_matrix(Transform2D(0.0, Vector2(_k, _k), 0.0, sh))
	_root.draw_rect(Rect2(cab.position + Vector2(20, cab.size.y - 10), Vector2(cab.size.x - 40, sz.y)), Color(0.04, 0.03, 0.03, 0.7))
	# Kaappi: musta lakkapinta, kromireunat ja punaiset sivupaneelit.
	MG.box(_root, cab, Color(0.08, 0.08, 0.1), 22, 16, MG.OUTLINE, 3)
	MG.grad_rect(_root, Rect2(cab.position + Vector2(10, 10), Vector2(30, cab.size.y - 20)), Color(0.85, 0.15, 0.15), Color(0.45, 0.05, 0.05))
	MG.grad_rect(_root, Rect2(Vector2(cab.end.x - 40, cab.position.y + 10), Vector2(30, cab.size.y - 20)), Color(0.85, 0.15, 0.15),
		Color(0.45, 0.05, 0.05))
	_draw_marquee(Rect2(cab.position + Vector2(50, 20), Vector2(cab.size.x - 100, 120)), font)
	_draw_paytable(Rect2(cab.position + Vector2(50, 150), Vector2(cab.size.x - 100, 160)), font)
	# Rullaikkuna.
	var win_r := Rect2(cab.position + Vector2(50, 318), Vector2(cab.size.x - 100, 254))
	MG.box(_root, win_r.grow(6), Color(0.75, 0.76, 0.8), 14, 0, MG.OUTLINE, 3)
	MG.box(_root, win_r, Color(0.05, 0.05, 0.06), 10)
	for r in 3:
		_draw_reel(r, font)
	# Voittolinja.
	var ly := _reel_rect(0).get_center().y
	var lc := Color(1.0, 0.85, 0.2) if _flash > 0.0 and int(_flash * 8.0) % 2 == 0 else Color(0.95, 0.15, 0.1)
	_root.draw_line(Vector2(win_r.position.x - 4, ly), Vector2(win_r.end.x + 4, ly), lc, 4.0)
	for x in [win_r.position.x - 14, win_r.end.x + 14]:
		_root.draw_colored_polygon(PackedVector2Array([Vector2(x, ly - 10), Vector2(x, ly + 10),
			Vector2(x + (12 if x < win_r.position.x else -12), ly)]), lc)
	# Lasin kiilto.
	_root.draw_colored_polygon(PackedVector2Array([win_r.position + Vector2(20, 0), win_r.position + Vector2(90, 0),
		win_r.position + Vector2(30, win_r.size.y), win_r.position + Vector2(-10, win_r.size.y)]), Color(1, 1, 1, 0.06))
	_draw_panel(Rect2(cab.position + Vector2(50, 586), Vector2(cab.size.x - 100, 132)), font)
	_draw_tray(font)
	for c in _coins:
		if c[2] >= 0.0:
			MG.ball(_root, c[0], 10.0, Color(0.92, 0.78, 0.35), 0.6)
	MG.sparks_draw(_root, _sparks)
	if _phase == "tupla" or (_phase == "win" and _card > 0 and _card_t > 0.0):
		_draw_card(Vector2(cab.end.x + 30, cab.position.y + 380), font)
	_root.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_bar_wall(sz: Vector2) -> void:
	MG.wood(_root, Rect2(Vector2.ZERO, sz), Color(0.3, 0.18, 0.1), 90.0, 5, false)
	MG.grad_rect(_root, Rect2(Vector2(0, sz.y * 0.84), Vector2(sz.x, sz.y * 0.16)), Color(0.22, 0.14, 0.09), Color(0.12, 0.08, 0.05))
	_root.draw_line(Vector2(0, sz.y * 0.84), Vector2(sz.x, sz.y * 0.84), Color(0.1, 0.06, 0.03), 4.0)
	MG.glow(_root, Vector2(sz.x * 0.5, sz.y * 0.4), 520.0, Color(1.0, 0.4, 0.5, 0.35 + 0.15 * sin(_t * 3.0)))
	# Siitari-kyltti seinällä ja pajatson punainen kylki oikealla.
	MG.sign(_root, Rect2(Vector2(sz.x * 0.05, sz.y * 0.12), Vector2(220, 70)), "SIITARI", Color(0.55, 0.05, 0.06), Color(1.0, 0.92, 0.6), 40,
		Color(0.3, 0.02, 0.03))
	var pj := Rect2(Vector2(sz.x * 0.86, sz.y * 0.2), Vector2(sz.x * 0.2, sz.y * 0.66))
	MG.box(_root, pj, Color(0.6, 0.1, 0.1), 14, 8, MG.OUTLINE, 3)
	MG.box(_root, Rect2(pj.position + Vector2(20, 40), Vector2(pj.size.x - 40, pj.size.y * 0.5)), Color(0.95, 0.88, 0.6), 8)
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.0, 0.0, 0.05, 0.3))


## Valaistu yläpaneeli: HEDELMÄPELI-teksti ja maalatut hedelmät, reunoilla juoksevat lamput.
func _draw_marquee(r: Rect2, font: Font) -> void:
	MG.box(_root, r, Color(0.15, 0.05, 0.3), 12, 0, Color(0.95, 0.8, 0.3), 4)
	MG.grad_rect(_root, r.grow(-8), Color(0.95, 0.35, 0.15), Color(0.6, 0.08, 0.2))
	MG.glow(_root, r.get_center(), r.size.x * 0.45, Color(1.0, 0.95, 0.6, 0.5))
	for k in 20:
		var x := r.position.x + 14.0 + k * (r.size.x - 28.0) / 19.0
		var on := int(_t * 6.0 + k) % 4 < 2 or _flash > 0.0
		_root.draw_circle(Vector2(x, r.position.y + 8), 5.0, Color(1.0, 0.95, 0.5) if on else Color(0.45, 0.3, 0.1))
		_root.draw_circle(Vector2(x, r.end.y - 8), 5.0, Color(1.0, 0.95, 0.5) if not on else Color(0.45, 0.3, 0.1))
	_draw_symbol("kirsikka", Vector2(r.position.x + 52, r.get_center().y), 0.6)
	_draw_symbol("seiska", Vector2(r.end.x - 52, r.get_center().y), 0.6)
	var tp := Vector2(r.position.x, r.get_center().y + 22)
	_root.draw_string_outline(font, tp, "HEDELMÄPELI", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 54, 12, Color(0.3, 0.02, 0.05))
	_root.draw_string(font, tp, "HEDELMÄPELI", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 54, Color(1.0, 0.92, 0.3))


## Voittotaulukko: kolme samaa = voitto euroina, kirsikat erikseen.
func _draw_paytable(r: Rect2, font: Font) -> void:
	MG.box(_root, r, Color(0.06, 0.08, 0.2), 8, 0, Color(0.7, 0.7, 0.75), 2)
	var order := ["seiska", "bar", "kello", "meloni", "rypale", "luumu", "appelsiini", "sitruuna", "kirsikka"]
	for i in order.size():
		var col := i % 3
		var row := i / 3
		var p := r.position + Vector2(18 + col * 168, 18 + row * 46)
		var lit: bool = _phase == "win" and _sym(0) == order[i] and _sym(1) == order[i] and _sym(2) == order[i] and int(_flash * 8.0) % 2 == 0
		if lit:
			MG.box(_root, Rect2(p - Vector2(6, 4), Vector2(160, 40)), Color(1.0, 0.85, 0.2, 0.5), 6)
		for k in 3:
			_draw_symbol(order[i], p + Vector2(14 + k * 26, 16), 0.2)
		_root.draw_string(font, p + Vector2(88, 24), "%d €" % PAY[order[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.9, 0.4))
	_root.draw_string(font, r.position + Vector2(0, r.size.y - 8), "Kirsikka 1. rullalla 1 €  ·  kaksi kirsikkaa 3 €",
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Color(0.9, 0.9, 0.95))


## Rulla: valkoinen kaareva nauha (tumma ylä- ja alareuna = lieriö), kolme symbolia näkyvissä.
func _draw_reel(r: int, _font: Font) -> void:
	var rr := _reel_rect(r)
	_root.draw_rect(rr, Color(0.97, 0.96, 0.92))
	var n := _strip.size()
	var base := floorf(_pos[r])
	var frac := _pos[r] - base
	var blur: bool = not _stopped[r] and _spin_t > 0.1 and _spin_t < STOP_AT[r] - 0.25
	for k in range(-2, 3):
		var y := rr.get_center().y - (k - frac) * SYM_H
		if absf(y - rr.get_center().y) > rr.size.y * 0.5 - 20.0:  # ei rullan reunan yli
			continue
		var sym: String = _strip[(int(base) + k + n * 8) % n]
		var squash := 1.0 - absf(y - rr.get_center().y) / (rr.size.y * 0.9)
		if blur:
			_draw_symbol(sym, Vector2(rr.get_center().x, y), 0.5 * squash, 0.35)
			_draw_symbol(sym, Vector2(rr.get_center().x, y + 18), 0.5 * squash, 0.25)
		else:
			_draw_symbol(sym, Vector2(rr.get_center().x, y), 0.5 * maxf(squash, 0.3))
	# Lieriön varjostus ylhäältä ja alhaalta.
	MG.grad_rect(_root, Rect2(rr.position, Vector2(rr.size.x, 70)), Color(0.05, 0.05, 0.06, 0.95), Color(0.05, 0.05, 0.06, 0.0))
	MG.grad_rect(_root, Rect2(rr.position + Vector2(0, rr.size.y - 70), Vector2(rr.size.x, 70)), Color(0.05, 0.05, 0.06, 0.0),
		Color(0.05, 0.05, 0.06, 0.95))
	_root.draw_rect(Rect2(rr.position + Vector2(rr.size.x - 14, 0), Vector2(14, rr.size.y)), Color(0, 0, 0, 0.18))
	_root.draw_rect(rr, MG.OUTLINE, false, 2.0)
	# Lukituslamppu rullan alla.
	var lp := Vector2(rr.get_center().x, rr.end.y + 4)
	if _locked[r]:
		MG.glow(_root, lp, 40.0, Color(1.0, 0.3, 0.2, 0.9))
		MG.sign(_root, Rect2(lp + Vector2(-46, -22), Vector2(92, 24)), "LUKITTU", Color(0.75, 0.08, 0.06), Color(1, 0.95, 0.8), 15,
			Color(0.95, 0.8, 0.3))


## Ohjauspaneeli: rahanäyttö (LED), viestinäyttö ja isot valaistut napit.
func _draw_panel(r: Rect2, font: Font) -> void:
	MG.solid(_root, r, Color(0.2, 0.2, 0.22))
	var led := Rect2(r.position + Vector2(14, 12), Vector2(150, 44))
	MG.box(_root, led, Color(0.08, 0.02, 0.02), 4, 0, Color(0.4, 0.4, 0.42), 2)
	_root.draw_string(font, led.position + Vector2(0, -2), "RAHAA", HORIZONTAL_ALIGNMENT_CENTER, led.size.x, 12, Color(0.8, 0.8, 0.8))
	_root.draw_string(font, led.position + Vector2(0, 34), "%s €" % _eur(money), HORIZONTAL_ALIGNMENT_CENTER, led.size.x, 28, Color(1.0, 0.25, 0.15))
	var msg := Rect2(r.position + Vector2(180, 12), Vector2(r.size.x - 194, 44))
	MG.box(_root, msg, Color(0.02, 0.06, 0.02), 4, 0, Color(0.4, 0.4, 0.42), 2)
	var mtxt := _msg
	if _phase == "win" and int(_t * 3.0) % 2 == 0:
		mtxt = "TUPLAA?"
	_root.draw_string(font, msg.position + Vector2(0, 32), mtxt, HORIZONTAL_ALIGNMENT_CENTER, msg.size.x, 26, Color(0.4, 1.0, 0.35))
	# Napit: lukot, PIENI, SUURI, PELAA / TALTEEN.
	var y := r.position.y + 92
	for k in 3:
		_button(Vector2(r.position.x + 44 + k * 58, y), 22.0, "%d" % (k + 1), Color(0.95, 0.95, 0.9),
			_locked[k] or (_lock_ok and _phase == "idle" and int(_t * 2.0) % 2 == 0), font)
	_button(Vector2(r.position.x + 256, y), 26.0, "PIENI", Color(0.95, 0.8, 0.2), _phase == "win", font)
	_button(Vector2(r.position.x + 330, y), 26.0, "SUURI", Color(0.95, 0.8, 0.2), _phase == "win", font)
	_button(Vector2(r.end.x - 60, y), 32.0, "TALTEEN" if _phase == "win" else "PELAA",
		Color(0.9, 0.2, 0.15) if _phase == "win" else Color(0.25, 0.8, 0.3), _phase in ["idle", "win"], font)


func _button(c: Vector2, rad: float, text: String, col: Color, lit: bool, font: Font) -> void:
	if lit:
		MG.glow(_root, c, rad * 2.0, Color(col.r, col.g, col.b, 0.6))
	_root.draw_circle(c + Vector2(0, 5), rad, col.darkened(0.6))
	MG.ball(_root, c, rad, col if lit else col.darkened(0.45), 0.5)
	var fs := 13 if text.length() > 2 else 18
	_root.draw_string(font, c + Vector2(-rad * 1.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, rad * 3.0, fs, Color(0.1, 0.06, 0.04))


func _draw_tray(font: Font) -> void:
	var r := _tray_rect()
	MG.box(_root, r.grow(5), Color(0.25, 0.25, 0.28), 10, 0, MG.OUTLINE, 2)
	MG.grad_rect(_root, r, Color(0.7, 0.72, 0.76), Color(0.4, 0.42, 0.46))
	_root.draw_rect(Rect2(r.position + Vector2(r.size.x / 2.0 - 40, -14), Vector2(80, 14)), Color(0.05, 0.05, 0.05))
	for k in mini(_tray, 40):
		var p := r.position + Vector2(r.size.x / 2.0 + ((k * 37) % 120 - 60) * 2.0, r.size.y - 9 - (k / 8) * 4)
		var pts := PackedVector2Array()
		for j in 14:
			pts.append(p + Vector2(cos(TAU * j / 14.0) * 10.0, sin(TAU * j / 14.0) * 3.5))
		_root.draw_colored_polygon(pts, Color(0.88, 0.74, 0.32))
	if _tray > 0:
		_root.draw_string(font, r.position + Vector2(0, r.size.y + 24), "Tarjottimella %d €" % _tray, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18,
			Color(1, 0.92, 0.6))


## Tuplauskortti: selkä kääntyy (kaventuu ja levenee), sitten kortin arvo.
func _draw_card(c: Vector2, font: Font) -> void:
	var t := clampf(_card_t / 0.6, 0.0, 1.0)
	var w := 120.0 * absf(cos(t * PI))
	var r := Rect2(c - Vector2(w / 2.0, 85), Vector2(maxf(w, 2.0), 170))
	MG.box(_root, r, Color.WHITE if t > 0.5 else Color(0.7, 0.1, 0.12), 10, 6, MG.OUTLINE, 2)
	if t <= 0.5:
		for k in 6:
			_root.draw_line(r.position + Vector2(6, 14 + k * 26), r.end - Vector2(6, 156 - k * 26), Color(1, 0.8, 0.8, 0.5), 2.0)
	elif w > 60.0:
		var names := {1: "A", 11: "J", 12: "Q", 13: "K"}
		var v: String = names.get(_card, str(_card))
		var col := Color(0.8, 0.1, 0.1) if _card % 2 == 0 else Color(0.08, 0.08, 0.1)
		_root.draw_string(font, r.position + Vector2(8, 28), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
		_root.draw_string(font, r.position + Vector2(0, 108), v, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 64, col)
	_root.draw_string(font, c + Vector2(-80, 120), "Arvaus: %s" % _guess.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color.WHITE)


## Symbolit piirretään käsin: sävytys, ääriviivat ja kiilto. s = mittakaava (1 = 100 px), a = läpinäkyvyys.
func _draw_symbol(sym: String, c: Vector2, s: float, a := 1.0) -> void:
	var o := Color(MG.OUTLINE.r, MG.OUTLINE.g, MG.OUTLINE.b, a)
	var ac := func(col: Color) -> Color: return Color(col.r, col.g, col.b, col.a * a)
	match sym:
		"kirsikka":
			_root.draw_line(c + Vector2(-20, 10) * s, c + Vector2(4, -36) * s, ac.call(Color(0.25, 0.5, 0.15)), 5.0 * s)
			_root.draw_line(c + Vector2(20, 14) * s, c + Vector2(4, -36) * s, ac.call(Color(0.25, 0.5, 0.15)), 5.0 * s)
			_leaf(c + Vector2(14, -38) * s, s, ac.call(Color(0.3, 0.65, 0.2)), o)
			for p in [Vector2(-20, 24), Vector2(20, 28)]:
				_root.draw_circle(c + p * s, 21.0 * s, ac.call(Color(0.55, 0.02, 0.06)))
				_root.draw_circle(c + (p - Vector2(2, 2)) * s, 18.0 * s, ac.call(Color(0.88, 0.08, 0.12)))
				_root.draw_circle(c + (p - Vector2(8, 8)) * s, 6.0 * s, ac.call(Color(1, 0.7, 0.7)))
				_root.draw_arc(c + p * s, 21.0 * s, 0, TAU, 24, o, 2.0, true)
		"sitruuna":
			_ellipse(c, Vector2(44, 32) * s, ac.call(Color(0.85, 0.7, 0.05)), o)
			_ellipse(c - Vector2(2, 3) * s, Vector2(40, 27) * s, ac.call(Color(1.0, 0.9, 0.2)), Color.TRANSPARENT)
			for side in [-1.0, 1.0]:
				_root.draw_circle(c + Vector2(side * 44, 0) * s, 6.0 * s, ac.call(Color(0.9, 0.78, 0.1)))
			_root.draw_circle(c + Vector2(-14, -12) * s, 7.0 * s, ac.call(Color(1, 1, 0.75)))
		"appelsiini":
			_root.draw_circle(c, 38.0 * s, ac.call(Color(0.8, 0.35, 0.02)))
			_root.draw_circle(c - Vector2(3, 3) * s, 34.0 * s, ac.call(Color(1.0, 0.55, 0.08)))
			for k in 8:
				var p := c + Vector2(cos(k * 2.3), sin(k * 1.7)) * 20.0 * s
				_root.draw_circle(p, 1.8 * s, ac.call(Color(0.85, 0.4, 0.02)))
			_root.draw_circle(c + Vector2(-12, -14) * s, 8.0 * s, ac.call(Color(1, 0.85, 0.55)))
			_leaf(c + Vector2(8, -38) * s, s, ac.call(Color(0.3, 0.65, 0.2)), o)
			_root.draw_arc(c, 38.0 * s, 0, TAU, 28, o, 2.0, true)
		"luumu":
			_ellipse(c, Vector2(32, 38) * s, ac.call(Color(0.3, 0.08, 0.35)), o)
			_ellipse(c - Vector2(3, 3) * s, Vector2(28, 34) * s, ac.call(Color(0.5, 0.15, 0.55)), Color.TRANSPARENT)
			_root.draw_arc(c + Vector2(6, 0) * s, 26.0 * s, -1.4, 1.2, 12, ac.call(Color(0.32, 0.08, 0.36)), 3.0 * s)
			_root.draw_circle(c + Vector2(-12, -16) * s, 6.0 * s, ac.call(Color(0.85, 0.65, 0.9)))
			_root.draw_line(c + Vector2(0, -36) * s, c + Vector2(4, -46) * s, ac.call(Color(0.35, 0.25, 0.1)), 4.0 * s)
		"rypale":
			_root.draw_line(c + Vector2(0, -34) * s, c + Vector2(4, -48) * s, ac.call(Color(0.35, 0.25, 0.1)), 4.0 * s)
			_leaf(c + Vector2(-14, -40) * s, s, ac.call(Color(0.3, 0.65, 0.2)), o)
			for row in 4:
				for k in 4 - row:
					var p := c + Vector2((k - (3 - row) / 2.0) * 20.0, -22.0 + row * 17.0) * s
					_root.draw_circle(p, 11.0 * s, ac.call(Color(0.22, 0.08, 0.3)))
					_root.draw_circle(p - Vector2(1, 1) * s, 9.5 * s, ac.call(Color(0.45, 0.2, 0.6)))
					_root.draw_circle(p - Vector2(4, 4) * s, 3.0 * s, ac.call(Color(0.85, 0.75, 0.95)))
		"meloni":
			# Vesimelonin viipale: vihreä kuori, vaalea raja, punainen malto ja siemenet.
			_wedge(c + Vector2(0, -16) * s, 46.0 * s, ac.call(Color(0.15, 0.5, 0.15)))
			_wedge(c + Vector2(0, -16) * s, 40.0 * s, ac.call(Color(0.9, 0.95, 0.75)))
			_wedge(c + Vector2(0, -16) * s, 35.0 * s, ac.call(Color(0.92, 0.18, 0.22)))
			for k in 5:
				var a2 := 0.4 + k * 0.58
				_ellipse(c + Vector2(0, -16) * s + Vector2(cos(a2), sin(a2)) * 20.0 * s, Vector2(2.5, 4.0) * s, ac.call(Color(0.1, 0.05, 0.05)),
					Color.TRANSPARENT)
			_root.draw_line(c + Vector2(-46, -16) * s, c + Vector2(46, -16) * s, o, 2.0)
		"kello":
			var pts := PackedVector2Array()
			for k in 13:
				var t := k / 12.0
				var y := lerpf(-34.0, 26.0, t)
				var w := 10.0 + 26.0 * pow(t, 1.4)
				pts.append(c + Vector2(-w, y) * s)
			for k in range(12, -1, -1):
				var t := k / 12.0
				pts.append(c + Vector2(10.0 + 26.0 * pow(t, 1.4), lerpf(-34.0, 26.0, t)) * s)
			_root.draw_colored_polygon(pts, ac.call(Color(0.95, 0.75, 0.15)))
			_root.draw_rect(Rect2(c + Vector2(-40, 22) * s, Vector2(80, 9) * s), ac.call(Color(0.8, 0.55, 0.1)))
			_root.draw_circle(c + Vector2(0, 36) * s, 7.0 * s, ac.call(Color(0.7, 0.5, 0.1)))
			_root.draw_circle(c + Vector2(0, -38) * s, 6.0 * s, ac.call(Color(0.8, 0.55, 0.1)))
			_root.draw_line(c + Vector2(-8, -24) * s, c + Vector2(-20, 16) * s, ac.call(Color(1, 0.95, 0.7)), 5.0 * s)
			pts.append(pts[0])
			_root.draw_polyline(pts, o, 2.0, true)
		"bar":
			var r := Rect2(c - Vector2(44, 20) * s, Vector2(88, 40) * s)
			MG.box(_root, r.grow(3.0 * s), ac.call(Color(0.95, 0.85, 0.3)), int(8 * s))
			MG.box(_root, r, ac.call(Color(0.08, 0.08, 0.1)), int(6 * s))
			_root.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, r.size.y * 0.78), "BAR", HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
				int(34 * s), ac.call(Color(1, 1, 1)))
		"seiska":
			var font := ThemeDB.fallback_font
			var p := c + Vector2(-50, 34) * s
			_root.draw_string_outline(font, p, "7", HORIZONTAL_ALIGNMENT_CENTER, 100.0 * s, int(96 * s), int(10 * s), ac.call(Color(0.3, 0.02, 0.02)))
			_root.draw_string(font, p, "7", HORIZONTAL_ALIGNMENT_CENTER, 100.0 * s, int(96 * s), ac.call(Color(0.95, 0.1, 0.1)))
			_root.draw_string(font, p + Vector2(-3, -3) * s, "7", HORIZONTAL_ALIGNMENT_CENTER, 100.0 * s, int(96 * s), ac.call(Color(1, 0.4, 0.35, 0.5)))


func _leaf(c: Vector2, s: float, col: Color, o: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-10, 0) * s, c + Vector2(0, -8) * s, c + Vector2(14, -4) * s, c + Vector2(4, 6) * s])
	_root.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	_root.draw_polyline(pts, o, 1.5, true)


func _ellipse(c: Vector2, r: Vector2, col: Color, o: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_root.draw_colored_polygon(pts, col)
	if o.a > 0.0:
		pts.append(pts[0])
		_root.draw_polyline(pts, o, 2.0, true)


## Puoliympyrä alaspäin (melonin viipale).
func _wedge(c: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 17:
		var a := PI * k / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	_root.draw_colored_polygon(pts, col)
