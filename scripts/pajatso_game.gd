extends CanvasLayer
## Siitarin mekaaninen pajatso (siitari_interior.gd "pajatso"): lasin takana pystysuora naulalauta. Euro pudotetaan
## oikeasta reunasta laukaisukouruun, ja vipua vedetään (pidä E pohjassa, jousi kiristyy) ja päästetään: kolikko
## nousee kourua ylös ja kiertää lasin yläreunan metallikaarta, kunnes vauhti ei enää riitä painamaan sitä kaarta
## vasten. Siitä se putoaa naulojen läpi (laskettu fysiikka: painovoima, kimpoilu nauloista ja reunoista).
## Messinkikuppeihin osunut kolikko voittaa kupin luvun verran kolikoita, keskimmäinen POTTI-kuppi tyhjentää koko
## potin. Ohi menneet kolikot kertyvät näkyviin pottiin lasin alaosaan, ja voitot maksetaan potista: kun potti on
## tyhjä, kuppikaan ei anna mitään. Liian heikko näppäys valuu takaisin kouruun. Humala tärisyttää vipukättä.
## F / Esc lopettaa. finished(money, pot): rahat ja potti pelin jälkeen (main.gd pitää potin tallessa).

signal finished(money: float, pot: int)
signal comment(text: String)

const MG := preload("res://scripts/mg_draw.gd")

const PRICE := 1.0
const G := 900.0           # painovoima, px/s²
const BW := 560.0          # naulalaudan koko
const BH := 600.0
const ARC_C := Vector2(280, 290)  # yläkaaren keskipiste
const ARC_R := 255.0
const COIN_R := 10.0
const NAIL_R := 4.0
const CHAN_X := 535.0      # laukaisukouru oikeassa reunassa
const CHAN_BOTTOM := 560.0
const WALL_X := 515.0      # kourun ja kentän välinen seinä
const FIELD_L := 25.0
const LOST_Y := 588.0
const V_MIN := 600.0       # vivun laukaisunopeus 0 %..100 % vedolla
const V_MAX := 1160.0
## Kupit: [keskikohta x, suun yläreuna y, suun leveys, voitto (-1 = koko potti)].
const CUPS := [
	[280.0, 300.0, 30.0, -1], [110.0, 410.0, 32.0, 2], [205.0, 400.0, 32.0, 4], [355.0, 400.0, 32.0, 4],
	[450.0, 410.0, 32.0, 2], [160.0, 500.0, 34.0, 3], [400.0, 500.0, 34.0, 3], [280.0, 470.0, 32.0, 6],
]
const LINES := ["Kolikko kouruun, vipu alas ja hellästi. Pajatso ei tykkää raakuudesta.",
	"Vanha kunnon pajatso. Naulat on taivutettu niin, ettei potti tyhjene ikinä.",
	"Kuulemma Raahessa joku tyhjensi potin kolme kertaa samana iltana."]

var money := 10.0
var pot := 12
var drunk := 0.0

var _root: Control
var _info: Label
var _keys: Control
var _tip: Label
var _board := Rect2()      # naulalaudan paikka ruudulla
var _nails: Array[Vector2] = []
var _t := 0.0
var _done := false
var _pull := 0.0           # vivun veto 0..1
var _pulling := false
## Kolikon tila: "" (ei kolikkoa), "chan" (nousee kourua), "arc" (kaarella), "free" (putoaa).
var _coin_state := ""
var _cp := Vector2.ZERO
var _cv := Vector2.ZERO
var _v_arc := 0.0          # kaaren alun nopeus (energia)
var _phi := 0.0
var _chan_v := 0.0
var _coin_t := 0.0
var _spin := 0.0
var _hit_cup := -1
var _hit_t := 0.0
var _shake := 0.0
var _sparks: Array = []
var _payout: Array = []    # maksettavat kolikot tarjottimelle: [paikka, nopeus, ikä]
var _tray := 0             # tarjottimen kolikot (näkyvä kasa)
var _pot_drop: Array = []  # pottiin putoavat kolikot [y, x]
var _pop := ""             # iso teksti hetkeksi (POTTI!, +4)
var _pop_t := 0.0
var _won := 0
var _shots := 0
var _clink_t := 0.0


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
	_keys.centered = false  # vasempaan alakulmaan: keskellä alhaalla se peitti potti-ikkunan ja voittotarjottimen
	add_child(_keys)
	_tip = _label(22, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	comment.connect(func(t: String) -> void: _tip.text = t)
	_build_nails()
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


## Naulat lomittaisina riveinä kaaren sisällä; kuppien suiden ja kylkien kohdalta jätetään väli.
func _build_nails() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1987
	var row := 0
	var y := 175.0
	while y < 572.0:
		var x := FIELD_L + 22.0 + (20.0 if row % 2 == 1 else 0.0)
		while x < WALL_X - 14.0:
			var p := Vector2(x + rng.randf_range(-2.0, 2.0), y)
			var ok := p.distance_to(ARC_C) < ARC_R - 34.0 or p.y > ARC_C.y + 10.0
			for c in CUPS:
				var cx: float = c[0]
				var top: float = c[1]
				var hw: float = c[2] / 2.0
				if absf(p.x - cx) < hw + 20.0 and p.y > top - 34.0 and p.y < top + 40.0:
					ok = false
			if ok:
				_nails.append(p)
			x += 40.0
		y += 31.0
		row += 1
	# Kuppien reunatapit: kaksi naulaa suun kulmissa ohjaavat kolikkoa sisään tai ohi.
	for c in CUPS:
		_nails.append(Vector2(c[0] - c[2] / 2.0 - NAIL_R, c[1]))
		_nails.append(Vector2(c[0] + c[2] / 2.0 + NAIL_R, c[1]))


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var sz := _root.size
	_board = Rect2(Vector2(sz.x / 2.0 - BW / 2.0 - 40.0, sz.y / 2.0 - BH / 2.0 - 10.0), Vector2(BW, BH))
	_root.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish()
		return
	_shake = maxf(0.0, _shake - delta * 3.0)
	_hit_t = maxf(0.0, _hit_t - delta)
	_pop_t = maxf(0.0, _pop_t - delta)
	_clink_t -= delta
	MG.sparks_step(_sparks, delta)
	_lever(delta)
	for i in 4:
		_coin_step(delta / 4.0)
	_payout_step(delta)
	_info.text = "PAJATSO · Rahaa %s € · Potissa %d kolikkoa" % [_eur(money), pot]
	if _coin_state == "":
		_keys.set_text("%s pidä pohjassa = vedä vipua, päästä = näppää (1 €)   %s lopeta" % [Settings.cap("interact"), Settings.cap("mount")])
	else:
		_keys.set_text("Kolikko matkalla...   %s lopeta" % Settings.cap("mount"))


func _eur(v: float) -> String:
	return ("%.2f" % v).replace(".", ",").trim_suffix(",00")


## Vipu: E pohjassa kiristää jousta (humalassa käsi tärisee), irrotus laukaisee kolikon kouruun.
func _lever(delta: float) -> void:
	if _coin_state != "":
		_pull = maxf(0.0, _pull - delta * 6.0)
		return
	var held := Input.is_action_pressed("interact")
	if Input.is_action_just_pressed("interact") and not _pulling:  # aloittava E (pohjassa) ei laukaise heti
		if money < PRICE:
			if Input.is_action_just_pressed("interact"):
				comment.emit("Rahat loppu. Pajatso ei anna velaksi.")
			return
		_pulling = true
		money -= PRICE
		_shots += 1
		Sfx.play("coin", -10.0, 1.4)
	if _pulling and held:
		_pull = minf(1.0, _pull + delta * 0.75)
		if drunk > 0.0:
			_pull = clampf(_pull + sin(_t * 11.0) * drunk * delta * 1.6, 0.0, 1.0)
	elif _pulling:
		_pulling = false
		_launch(_pull)


func _launch(p: float) -> void:
	_coin_state = "chan"
	_cp = Vector2(CHAN_X, CHAN_BOTTOM)
	_chan_v = lerpf(V_MIN, V_MAX, p) * randf_range(0.985, 1.015)
	_coin_t = 0.0
	Sfx.play("whoosh", -12.0, 1.6)
	_shake = 0.25


func _coin_step(dt: float) -> void:
	if _coin_state == "":
		return
	_coin_t += dt
	_spin += dt * (_cv.length() + absf(_chan_v)) * 0.05
	match _coin_state:
		"chan":
			# Kourussa ylös: hidastuu painovoimasta. Jos vauhti loppuu ennen kaarta, kolikko valuu takaisin.
			_chan_v -= G * dt
			_cp.y -= _chan_v * dt
			if _cp.y <= ARC_C.y:
				_coin_state = "arc"
				_phi = 0.0
				_v_arc = _chan_v
			elif _chan_v < 0.0 and _cp.y >= CHAN_BOTTOM:
				_coin_state = ""
				_pull = 0.0
				money += PRICE
				_shots -= 1
				Sfx.play("coin", -12.0, 0.8)
				comment.emit("Liian heikko näppäys: kolikko valui takaisin kouruun. Vedä vipua pidempään.")
		"arc":
			# Kaarta vasten: v² = v0² - 2gh. Irtoaa, kun keskihakuvoima ei enää riitä (v² < g R sin φ).
			var rr := ARC_R - COIN_R
			var h := rr * sin(_phi)
			var v2 := _v_arc * _v_arc - 2.0 * G * h
			if v2 < G * rr * sin(_phi) or _phi >= PI:
				var v := sqrt(maxf(v2, 0.0))
				_cv = Vector2(-sin(_phi), -cos(_phi)) * v
				_coin_state = "free"
				Sfx.play("rattle", -20.0, 1.8)
				return
			_phi = minf(PI, _phi + sqrt(v2) / rr * dt)
			_cp = ARC_C + Vector2(cos(_phi), -sin(_phi)) * rr
		"free":
			_cv.y += G * dt
			_cp += _cv * dt
			_collide()
			if _coin_state != "free":
				return
			if _cp.y > LOST_Y or _coin_t > 12.0:
				_lost()


func _collide() -> void:
	for n in _nails:
		var d := _cp - n
		var dist := d.length()
		var md := COIN_R + NAIL_R
		if dist < md and dist > 0.001:
			var nrm := d / dist
			_cp = n + nrm * md
			var vn := _cv.dot(nrm)
			if vn < 0.0:
				var vt := _cv - nrm * vn
				_cv = vt * 0.92 - nrm * vn * 0.42
				_cv += Vector2(randf_range(-14.0, 14.0), 0.0)  # naulat ovat vähän vinossa
				if absf(vn) > 90.0 and _clink_t <= 0.0:
					_clink_t = 0.05
					Sfx.play("glass", -26.0 + minf(absf(vn) / 60.0, 8.0), randf_range(2.6, 3.2))
	# Yläkaari ja sivuseinät.
	if _cp.y < ARC_C.y:
		var d := _cp - ARC_C
		if d.length() > ARC_R - COIN_R:
			var nrm := d.normalized()
			_cp = ARC_C + nrm * (ARC_R - COIN_R)
			var vn := _cv.dot(nrm)
			if vn > 0.0:
				_cv -= nrm * vn * 1.4
	if _cp.x < FIELD_L + COIN_R:
		_cp.x = FIELD_L + COIN_R
		_cv.x = absf(_cv.x) * 0.45
	if _cp.x > WALL_X - COIN_R and _cp.y > ARC_C.y - 4.0:
		_cp.x = WALL_X - COIN_R
		_cv.x = -absf(_cv.x) * 0.45
	# Kuppiin: keskikohta suun sisällä ja liike alaspäin.
	for i in CUPS.size():
		var c: Array = CUPS[i]
		if absf(_cp.x - c[0]) < c[2] / 2.0 - 3.0 and _cp.y > c[1] - 2.0 and _cp.y < c[1] + 16.0 and _cv.y > 0.0:
			_cup(i)
			return


func _cup(i: int) -> void:
	_coin_state = ""
	_pull = 0.0
	_hit_cup = i
	_hit_t = 1.2
	_shake = 0.6
	var c: Array = CUPS[i]
	var at := _board.position + Vector2(c[0], c[1] + 8.0)
	pot += 1  # näpätty kolikko jää koneeseen
	var n: int = pot if c[3] < 0 else mini(c[3], pot)
	pot -= n
	_won += n
	for k in n:
		_payout.append([Vector2(_board.position.x + BW * 0.5 + randf_range(-30, 30), _board.end.y + 70.0),
			Vector2(randf_range(-80, 80), randf_range(-260, -120)), -k * 0.06])
	if c[3] < 0:
		MG.sparks_burst(_sparks, at, Color(1.0, 0.85, 0.2), 50)
		_pop = "POTTI! +%d" % n
		Sfx.play("win", -4.0)
		comment.emit("POTTI! Koko kasa ryöppyää tarjottimelle. Koko baari kääntyy katsomaan.")
	else:
		MG.sparks_burst(_sparks, at, Color(1.0, 0.8, 0.3), 24)
		_pop = "+%d" % n if n > 0 else "Potti tyhjä!"
		Sfx.play("win_small", -6.0)
		if n == 0:
			comment.emit("Kuppiin meni, mutta potti on tyhjä. Ei sieltä mitään tule.")
	_pop_t = 1.6


func _lost() -> void:
	_coin_state = ""
	_pull = 0.0
	pot += 1
	_pot_drop.append([0.0, _cp.x])
	Sfx.play("coin", -16.0, 0.7)
	if randi() % 3 == 0:
		comment.emit(["Ohi. Potti kasvaa, ja se kasvaa sulle.", "Kolikko kilahti naulasta naulaan ja pottiin.",
			"Melkein! Kupin reuna käänsi sen pois."].pick_random())


func _payout_step(delta: float) -> void:
	for p in _payout:
		p[2] += delta
		if p[2] < 0.0:
			continue
		p[1].y += G * delta
		p[0] += p[1] * delta
	for i in range(_payout.size() - 1, -1, -1):
		var p: Array = _payout[i]
		if p[2] > 0.0 and p[0].y > _board.end.y + 92.0:
			_payout.remove_at(i)
			_tray += 1
			money += 1.0
			Sfx.play("coin", -10.0, randf_range(0.9, 1.3))
	for d in _pot_drop:
		d[0] += delta
	_pot_drop = _pot_drop.filter(func(d): return d[0] < 0.5)


func _finish() -> void:
	if not _payout.is_empty():
		money += _payout.size()  # tarjottimelle matkalla olevat kolikot taskuun
		_payout.clear()
	if _coin_state != "":
		pot += 1
	_done = true
	finished.emit(money, pot)
	queue_free()


# --- Piirto -------------------------------------------------------------------

func _draw_root() -> void:
	var sz := _root.size
	var font := ThemeDB.fallback_font
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 6.0
	_draw_bar_wall(sz)
	var o := _board.position + shake
	var cab := Rect2(o - Vector2(60, 200), Vector2(BW + 120, BH + 330))
	# Kaappi: tumma vaneri, kromilistat ja jalusta.
	_root.draw_rect(Rect2(cab.position + Vector2(18, cab.size.y), Vector2(cab.size.x - 36, sz.y)), Color(0.05, 0.04, 0.04, 0.6))
	MG.box(_root, cab, Color(0.4, 0.1, 0.08), 18, 14, MG.OUTLINE, 3)
	MG.wood(_root, cab.grow(-10), Color(0.5, 0.16, 0.1), 60.0, 7, false)
	_root.draw_rect(cab.grow(-10), Color(0.25, 0.05, 0.03, 0.35))
	_draw_header(Rect2(cab.position + Vector2(24, 18), Vector2(cab.size.x - 48, 150)), font)
	# Naulalauta: kermanvalkoinen maalattu levy painokuvioin.
	var field := Rect2(o, Vector2(BW, BH))
	MG.box(_root, field.grow(10), Color(0.75, 0.72, 0.68), 10, 0, MG.OUTLINE, 3)
	MG.grad_rect(_root, field, Color(0.98, 0.94, 0.82), Color(0.9, 0.82, 0.66))
	for k in 9:  # painetut tähdet ja ympyrät
		var p := o + Vector2(50 + (k * 137) % 460, 190 + (k * 89) % 360)
		_star(p, 14.0 + (k % 3) * 5.0, [Color(0.95, 0.4, 0.3, 0.35), Color(0.3, 0.55, 0.9, 0.3), Color(0.95, 0.75, 0.2, 0.4)][k % 3])
	# Kaaren ulkopuoli (ylänurkat) ja vasen reunalista kaapin punaisella.
	_fill_corners(o)
	# Metallikaari ja kourun seinä.
	_root.draw_arc(o + ARC_C, ARC_R + 3.0, PI, TAU, 64, Color(0.35, 0.36, 0.38), 9.0, true)
	_root.draw_arc(o + ARC_C, ARC_R + 1.0, PI, TAU, 64, Color(0.85, 0.86, 0.9), 3.0, true)
	_root.draw_line(o + Vector2(WALL_X + 3, ARC_C.y), o + Vector2(WALL_X + 3, BH), Color(0.35, 0.36, 0.38), 6.0)
	_root.draw_line(o + Vector2(WALL_X + 2, ARC_C.y), o + Vector2(WALL_X + 2, BH), Color(0.85, 0.86, 0.9), 2.0)
	_root.draw_line(o + Vector2(BW - 2, ARC_C.y), o + Vector2(BW - 2, BH), Color(0.35, 0.36, 0.38), 5.0)
	# Kupit (messinkiä) ja voittoluvut.
	for i in CUPS.size():
		_draw_cup(o, i, font)
	# Naulat: pieni varjo, kirkas kanta.
	for n in _nails:
		_root.draw_circle(o + n + Vector2(1.5, 2.5), NAIL_R, Color(0, 0, 0, 0.28))
		_root.draw_circle(o + n, NAIL_R, Color(0.45, 0.45, 0.48))
		_root.draw_circle(o + n - Vector2(1, 1), NAIL_R * 0.55, Color(0.95, 0.95, 0.98))
	# Potti: lasi-ikkuna alhaalla, kolikkopino.
	_draw_pot(o, font)
	# Kolikko.
	if _coin_state != "":
		_draw_coin(o + _cp)
	# Lasi: heijastusviirut.
	for k in 3:
		var x := 60.0 + k * 170.0
		_root.draw_colored_polygon(PackedVector2Array([o + Vector2(x, 0), o + Vector2(x + 40 + k * 10, 0),
			o + Vector2(x - 120 + k * 10, BH), o + Vector2(x - 160, BH)]), Color(1, 1, 1, 0.06))
	_root.draw_rect(field, MG.OUTLINE, false, 3.0)
	_draw_launcher(o, cab, font)
	_draw_tray(o, font)
	for p in _payout:
		if p[2] >= 0.0:
			_draw_coin(p[0])
	MG.sparks_draw(_root, _sparks)
	if _pop_t > 0.0:
		var s := 56 if _pop.begins_with("POTTI") else 44
		var a := clampf(_pop_t / 0.4, 0.0, 1.0)
		var py := o.y + 250.0 - (1.6 - _pop_t) * 40.0
		_root.draw_string_outline(font, Vector2(o.x, py), _pop, HORIZONTAL_ALIGNMENT_CENTER, BW, s, 10, Color(0.15, 0.05, 0.0, a))
		_root.draw_string(font, Vector2(o.x, py), _pop, HORIZONTAL_ALIGNMENT_CENTER, BW, s, Color(1.0, 0.85, 0.2, a))


## Siitarin seinä pajatson takana: tumma puupaneeli, jukeboksin violetti hehku ja kattolampun valokeila.
func _draw_bar_wall(sz: Vector2) -> void:
	MG.wood(_root, Rect2(Vector2.ZERO, sz), Color(0.3, 0.18, 0.1), 90.0, 3, false)
	MG.grad_rect(_root, Rect2(Vector2(0, sz.y * 0.82), Vector2(sz.x, sz.y * 0.18)), Color(0.22, 0.14, 0.09), Color(0.12, 0.08, 0.05))
	_root.draw_line(Vector2(0, sz.y * 0.82), Vector2(sz.x, sz.y * 0.82), Color(0.1, 0.06, 0.03), 4.0)
	MG.glow(_root, Vector2(sz.x * 0.08, sz.y * 0.5), 260.0, Color(0.7, 0.3, 0.9, 0.7))
	MG.glow(_root, Vector2(sz.x * 0.5, -40), 520.0, Color(1.0, 0.85, 0.55, 0.5))
	# Jukeboksin reuna näkyy vasemmalla.
	var jb := Rect2(Vector2(sz.x * 0.02, sz.y * 0.3), Vector2(sz.x * 0.11, sz.y * 0.55))
	MG.box(_root, jb, Color(0.3, 0.12, 0.35), 40, 8, MG.OUTLINE, 3)
	MG.box(_root, jb.grow(-14), Color(0.75, 0.45, 0.85), 30)
	for k in 5:
		_root.draw_line(jb.position + Vector2(18, 30 + k * 26), jb.position + Vector2(jb.size.x - 18, 30 + k * 26), Color(1, 0.9, 0.5, 0.7), 3.0)
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.0, 0.0, 0.05, 0.25))


## Yläpaneeli: maalattu klovni (Bajazzo, pajatson kaima) ja PAJATSO-teksti, reunassa lamppurivi.
func _draw_header(r: Rect2, font: Font) -> void:
	MG.box(_root, r, Color(0.12, 0.1, 0.25), 12, 0, Color(0.95, 0.8, 0.3), 4)
	MG.grad_rect(_root, r.grow(-6), Color(0.2, 0.25, 0.6), Color(0.08, 0.08, 0.25))
	for k in 18:
		var x := r.position.x + 16.0 + k * (r.size.x - 32.0) / 17.0
		var on := int(_t * 4.0 + k) % 3 == 0
		_root.draw_circle(Vector2(x, r.position.y + 10), 5.0, Color(1.0, 0.9, 0.4) if on else Color(0.5, 0.35, 0.15))
		_root.draw_circle(Vector2(x, r.end.y - 10), 5.0, Color(1.0, 0.9, 0.4) if not on else Color(0.5, 0.35, 0.15))
	# Klovni vasemmalla.
	var c := Vector2(r.position.x + 90, r.position.y + r.size.y / 2.0 + 6)
	_root.draw_colored_polygon(PackedVector2Array([c + Vector2(-34, -30), c + Vector2(34, -30), c + Vector2(0, -92)]), Color(0.9, 0.15, 0.2))
	_root.draw_circle(c + Vector2(0, -92), 7.0, Color(1.0, 0.95, 0.4))
	for s in [-1.0, 1.0]:
		_root.draw_circle(c + Vector2(s * 36, -2), 16.0, Color(0.95, 0.45, 0.1))  # hiustupsut
	_root.draw_circle(c, 36.0, Color(0.98, 0.95, 0.92))
	_root.draw_arc(c, 36.0, 0, TAU, 32, MG.OUTLINE, 2.5, true)
	for s in [-1.0, 1.0]:
		_root.draw_line(c + Vector2(s * 13, -18), c + Vector2(s * 13, -2), Color(0.15, 0.2, 0.6), 3.0)
		_root.draw_circle(c + Vector2(s * 13, -8), 4.0, Color(0.08, 0.06, 0.05))
	MG.ball(_root, c + Vector2(0, 4), 9.0, Color(0.95, 0.12, 0.12), 0.6)
	_root.draw_arc(c + Vector2(0, 10), 18.0, 0.3, PI - 0.3, 16, Color(0.85, 0.1, 0.15), 5.0, true)
	_root.draw_colored_polygon(PackedVector2Array([c + Vector2(-26, 34), c + Vector2(26, 34), c + Vector2(14, 46), c + Vector2(-14, 46)]),
		Color(1.0, 0.85, 0.2))
	# Teksti.
	var tp := Vector2(r.position.x + 170, r.position.y + 96)
	_root.draw_string_outline(font, tp, "PAJATSO", HORIZONTAL_ALIGNMENT_LEFT, -1, 74, 14, Color(0.4, 0.05, 0.02))
	_root.draw_string(font, tp, "PAJATSO", HORIZONTAL_ALIGNMENT_LEFT, -1, 74, Color(1.0, 0.82, 0.15))
	_root.draw_string(font, tp + Vector2(4, 36), "1 €   ·   POTTI KESKELLÄ", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.92, 0.85))


## Kaaren ulkopuoliset ylänurkat täytetään kaapin punaisella, jotta lauta näyttää holvikaarelta.
func _fill_corners(o: Vector2) -> void:
	var red := Color(0.42, 0.1, 0.07)
	var lp := PackedVector2Array([o, o + Vector2(0, ARC_C.y)])
	var rp := PackedVector2Array()
	for k in 17:
		lp.append(o + ARC_C + Vector2(cos(PI - PI / 2.0 * k / 16.0), -sin(PI - PI / 2.0 * k / 16.0)) * ARC_R)
		rp.append(o + ARC_C + Vector2(cos(PI / 2.0 * k / 16.0), -sin(PI / 2.0 * k / 16.0)) * ARC_R)
	lp.append(o + Vector2(ARC_C.x, 0))
	rp.append_array([o + Vector2(ARC_C.x, 0), o + Vector2(BW, 0), o + Vector2(BW, ARC_C.y)])
	_root.draw_colored_polygon(lp, red)
	_root.draw_colored_polygon(rp, red)
	_root.draw_rect(Rect2(o + Vector2(0, ARC_C.y), Vector2(FIELD_L, BH - ARC_C.y)), red)


func _draw_cup(o: Vector2, i: int, font: Font) -> void:
	var c: Array = CUPS[i]
	var hw: float = c[2] / 2.0 + 2.0
	var top := o + Vector2(c[0], c[1])
	var lit := i == _hit_cup and _hit_t > 0.0 and int(_hit_t * 10.0) % 2 == 0
	var brass := Color(1.0, 0.9, 0.4) if lit else Color(0.82, 0.62, 0.22)
	var pts := PackedVector2Array()
	pts.append(top + Vector2(-hw, 0))
	for k in 9:
		var a := PI * k / 8.0
		pts.append(top + Vector2(-cos(a) * hw, 6.0 + sin(a) * 18.0))
	pts.append(top + Vector2(hw, 0))
	_root.draw_colored_polygon(pts, brass.darkened(0.25))
	_root.draw_colored_polygon(PackedVector2Array([top + Vector2(-hw + 3, 2), top + Vector2(hw - 3, 2), top + Vector2(hw - 6, 8),
		top + Vector2(-hw + 6, 8)]), Color(0.15, 0.1, 0.05))  # suu
	_root.draw_line(top + Vector2(-hw + 5, 12), top + Vector2(-hw + 9, 20), brass.lightened(0.5), 2.5)
	pts.append(pts[0])
	_root.draw_polyline(pts, MG.OUTLINE, 2.0, true)
	var label := "POTTI" if c[3] < 0 else str(c[3])
	var lr := Rect2(top + Vector2(-26 if c[3] < 0 else -14, 28), Vector2(52 if c[3] < 0 else 28, 20))
	MG.box(_root, lr, Color(0.75, 0.1, 0.1) if c[3] < 0 else Color(0.15, 0.3, 0.65), 5, 0, MG.OUTLINE, 1)
	_root.draw_string(font, lr.position + Vector2(0, 16), label, HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 15, Color(1, 0.95, 0.8))
	if lit:
		MG.glow(_root, top + Vector2(0, 10), 50.0, Color(1.0, 0.9, 0.3, 0.8))


func _draw_pot(o: Vector2, font: Font) -> void:
	var r := Rect2(o + Vector2(BW / 2.0 - 70, BH + 16), Vector2(140, 74))
	MG.box(_root, r.grow(6), Color(0.3, 0.3, 0.32), 8, 0, MG.OUTLINE, 2)
	MG.grad_rect(_root, r, Color(0.12, 0.12, 0.16), Color(0.05, 0.05, 0.07))
	# Kolikkopino: kasa limittäisiä kolikoita, korkeus potin mukaan.
	var n := mini(pot, 60)
	for k in n:
		var col := k % 6
		var row := k / 6
		var p := r.position + Vector2(18 + col * 21 + (row % 2) * 9, r.size.y - 10 - row * 5)
		_coin_flat(p)
	for d in _pot_drop:
		_draw_coin(r.position + Vector2(clampf(d[1] - BW / 2.0 + 70.0, 10.0, 130.0), -10.0 + d[0] * 120.0))
	_root.draw_rect(r, Color(1, 1, 1, 0.07))
	_root.draw_line(r.position + Vector2(10, 6), r.position + Vector2(40, 6), Color(1, 1, 1, 0.3), 2.0)
	MG.sign(_root, Rect2(r.position + Vector2(-110, 20), Vector2(90, 34)), "POTTI %d" % pot, Color(0.75, 0.1, 0.1), Color(1, 0.95, 0.8), 16,
		Color(0.95, 0.8, 0.3))


## Laukaisukouru oikealla: kolikkoaukko, jousivipu kromikuulalla (painuu alas vedettäessä) ja vedon voimamittari.
func _draw_launcher(o: Vector2, cab: Rect2, font: Font) -> void:
	var slot := o + Vector2(BW + 30, -60)
	MG.box(_root, Rect2(slot - Vector2(18, 40), Vector2(36, 80)), Color(0.75, 0.76, 0.8), 6, 3, MG.OUTLINE, 2)
	_root.draw_rect(Rect2(slot - Vector2(3, 26), Vector2(6, 40)), Color(0.05, 0.05, 0.05))
	_root.draw_string(font, slot + Vector2(-30, 58), "1 €", HORIZONTAL_ALIGNMENT_CENTER, 60, 18, Color(1, 0.95, 0.8))
	# Kolikko odottaa kourun pohjalla.
	if _coin_state == "" and (_pulling or money >= PRICE):
		_draw_coin(o + Vector2(CHAN_X, CHAN_BOTTOM - _pull * 22.0))
	# Vipu kaapin oikeassa kyljessä.
	var piv := Vector2(cab.end.x - 6, o.y + BH - 60)
	var a := -0.35 + _pull * 0.9
	var tip := piv + Vector2(cos(a), sin(a)) * 110.0
	_root.draw_circle(piv, 16.0, Color(0.4, 0.4, 0.44))
	_root.draw_line(piv, tip, MG.OUTLINE, 14.0)
	_root.draw_line(piv, tip, Color(0.82, 0.84, 0.88), 9.0)
	_root.draw_line(piv + Vector2(0, -3), tip + Vector2(0, -3), Color(1, 1, 1, 0.7), 2.5)
	MG.ball(_root, tip, 18.0, Color(0.85, 0.12, 0.1), 0.6)
	MG.ball(_root, piv, 10.0, Color(0.75, 0.76, 0.8), 0.6)
	# Jousen veto.
	var bar := Rect2(Vector2(cab.end.x + 40, o.y + BH - 260), Vector2(22, 220))
	MG.box(_root, bar.grow(4), Color(0.05, 0.05, 0.05, 0.8), 6)
	var h := bar.size.y * _pull
	MG.grad_rect(_root, Rect2(Vector2(bar.position.x, bar.end.y - h), Vector2(bar.size.x, h)), Color(1.0, 0.3, 0.2), Color(0.3, 0.8, 0.3))
	_root.draw_string(font, bar.position + Vector2(-30, -12), "VETO", HORIZONTAL_ALIGNMENT_CENTER, 82, 18, Color.WHITE)


## Voittotarjotin kaapin alla: kromikouru ja kasa kolikoita.
func _draw_tray(o: Vector2, font: Font) -> void:
	var r := Rect2(Vector2(o.x + 60, o.y + BH + 100), Vector2(BW - 120, 46))
	MG.box(_root, r.grow(5), Color(0.25, 0.25, 0.28), 10, 6, MG.OUTLINE, 2)
	MG.grad_rect(_root, r, Color(0.7, 0.72, 0.76), Color(0.4, 0.42, 0.46))
	for k in mini(_tray, 40):
		_coin_flat(r.position + Vector2(r.size.x / 2.0 + ((k * 37) % 120 - 60) * 1.4, r.size.y - 8 - (k / 8) * 4))
	if _tray > 0:
		_root.draw_string(font, r.position + Vector2(0, -8), "Voitot tarjottimella: %d €" % _tray, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18,
			Color(1, 0.92, 0.6))


## Euron kolikko edestä: kultainen reuna, hopeinen keskus, kohokuvio ja pyörivä kiilto.
func _draw_coin(p: Vector2) -> void:
	_root.draw_circle(p + Vector2(2, 3), COIN_R, Color(0, 0, 0, 0.35))
	_root.draw_circle(p, COIN_R, Color(0.72, 0.58, 0.22))
	_root.draw_circle(p, COIN_R - 1.5, Color(0.92, 0.78, 0.35))
	_root.draw_circle(p, COIN_R * 0.62, Color(0.78, 0.8, 0.84))
	_root.draw_circle(p, COIN_R * 0.62, Color(0.5, 0.5, 0.55), false, 1.0)
	_root.draw_string(ThemeDB.fallback_font, p + Vector2(-4, 4), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.35, 0.35, 0.4))
	var a := _spin
	_root.draw_line(p + Vector2(cos(a), sin(a)) * 3.0, p + Vector2(cos(a), sin(a)) * 8.0, Color(1, 1, 1, 0.8), 2.0)
	_root.draw_arc(p, COIN_R, 0, TAU, 20, MG.OUTLINE, 1.5, true)


## Kolikko kyljellään pinossa: litteä ellipsi.
func _coin_flat(p: Vector2) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		pts.append(p + Vector2(cos(a) * 10.0, sin(a) * 3.5))
	_root.draw_colored_polygon(pts, Color(0.88, 0.74, 0.32))
	pts.append(pts[0])
	_root.draw_polyline(pts, Color(0.45, 0.35, 0.1), 1.0)
	_root.draw_line(p + Vector2(-6, -1), p + Vector2(2, -2), Color(1, 0.95, 0.7), 1.5)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + TAU * k / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	_root.draw_colored_polygon(pts, col)
