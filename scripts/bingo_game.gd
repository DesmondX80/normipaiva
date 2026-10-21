extends Node3D
## Bingo Saloisten seuraintalolla (#129), pelataan salin bingopöydässä: pelaaja istuu pöydän päässä mummojen ja
## Taunon rivissä, ja lavalla salin oma Erkki pyörittää pallokonetta ja huutaa numerot puhekuplassa. Oma 5×5-lappu
## (B 1–15, I 16–30, N 31–45 vapaa keskiruutu, G 46–60, O 61–75) on ruudun oikeassa reunassa kuin paperi kädessä;
## huudetut numerot merkitään klikkaamalla. Kun rivi (vaaka, pysty tai vino) on täynnä, BINGO-nappi: oikea huuto
## voittaa. Väärä huuto nolaa: pöydän mummot kääntyvät mulkoilemaan, ja maine kärsii. Mummo Elvi saa bingon
## RIVAL_AT-huudon paikkeilla: ehdi ensin. F / Esc lopettaa. Solmu lisätään salin (kirppis_interior.gd) lapseksi.
## finished(won, false_calls).

signal finished(won: bool, false_calls: int)

const MG := preload("res://scripts/mg_draw.gd")
const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const CALL_S := 3.0
const COLS := "BINGO"
const SEAT := Vector3(2.0, 0, 0.9)  # pöydän pää, kasvot lavalle
const DRUM := Vector3(-1.5, 1.75, -4.4)  # salin pallokone lavalla
const BALL_COLS := [Color(0.2, 0.4, 0.85), Color(0.85, 0.2, 0.2), Color(0.95, 0.95, 0.95), Color(0.2, 0.65, 0.3), Color(0.95, 0.65, 0.1)]

var drunk := 0.0
var quit := false  # lopetettiin kesken (ei kuittaa bingoa)
var rival_at := 22  # monennellako huudolla mummo huutaa bingon (main.gd arpoo)
var interior  # kirppis_interior.gd: Erkki, pöydän mummot ja puhekuplat

var _hud: CanvasLayer
var _root: Control
var _info: Label
var _keys: Control
var _tip: Label
var _done := false
var _t := 0.0
var _card: Array = []  # 25 numeroa, 0 = vapaa
var _marked: Array = []  # 25 bool
var _called: Array = []
var _pool: Array = []
var _call_t := 1.5
var _false := 0
var _ball_t := 0.0  # uuden pallon animaatio
var _glare := 0.0
var _sparks: Array = []
var _mouse := Vector2.ZERO

var _me: Node3D
var _cam: Camera3D
var _drum_balls: Array[Node3D] = []
var _pop: MeshInstance3D  # uusi pallo pomppaa koneesta
var _erkki: Node3D
var _mummos: Array[Node3D] = []  # pöydän istujat (mulkoilevat väärästä bingosta)
var _elvi: Node3D


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	_build()
	_cam = Camera3D.new()
	_cam.fov = 52.0
	add_child(_cam)
	_cam.current = true
	_cam.look_at_from_position(to_global(SEAT + Vector3(0.7, 1.75, 1.5)), to_global(Vector3(-0.6, 1.2, -4.0)))
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_card.resize(25)
	_marked.resize(25)
	_marked.fill(false)
	for c in 5:  # sarakkeen numerot omalta väliltään
		var nums: Array = range(c * 15 + 1, c * 15 + 16)
		nums.shuffle()
		for r in 5:
			_card[r * 5 + c] = nums[r]
	_card[12] = 0
	_marked[12] = true
	_pool = range(1, 76)
	_pool.shuffle()
	_tip.text = "Erkki: \"Laput valmiina! Ensimmäinen pallo tulossa...\""
	_erkki_say("Laput valmiina!", 1.5)


# --- Rakennus ------------------------------------------------------------------

func _build() -> void:
	if interior != null:
		if interior.walker != null:
			interior.walker.visible = false
		for i in interior.PEOPLE.size():
			var p: Dictionary = interior.PEOPLE[i]
			if not ("bingo" in p.modes):
				continue
			if p.id == "huutaja":
				_erkki = interior._people[i]
			elif p.pose == "Sitting_Idle":
				_mummos.append(interior._people[i])
				if p.name == "Mummo Elvi":
					_elvi = interior._people[i]
	# Oma tuoli pöydän päässä, lappu ja kynä pöydällä.
	var wood := Color(0.45, 0.28, 0.16)
	B.mesh(self, B.boxm(Vector3(0.45, 0.05, 0.42)), SEAT + Vector3(0, 0.45, 0), wood)
	B.mesh(self, B.boxm(Vector3(0.45, 0.45, 0.04)), SEAT + Vector3(0, 0.7, 0.2), wood)
	for lx in [-0.19, 0.19]:
		for lz in [-0.17, 0.17]:
			B.mesh(self, B.boxm(Vector3(0.04, 0.45, 0.04)), SEAT + Vector3(lx, 0.22, lz), wood.darkened(0.2))
	B.mesh(self, B.boxm(Vector3(0.3, 0.01, 0.3)), Vector3(1.32, 0.76, 0.25), Color(0.98, 0.97, 0.9))
	_me = Looks.make(self, Looks.player())
	Looks.add_cap(_me)
	_me.play("Sitting_Idle", 0.0)
	_me.anim.advance(0.01)
	var pelvis: Vector3 = _me.bone_position("pelvis")
	_me.position = SEAT + Vector3(-pelvis.x, 0.05, 0.06 - pelvis.z)
	_me.rotation.y = 0.3  # kääntyy hieman lappua kohti
	# Pallokoneen pyörivät pallot ja uusi pallo.
	for k in 8:
		var bl := B.mesh(self, B.sphere(0.055, 8), DRUM, [Color.RED, Color.YELLOW, Color.WHITE, Color(0.3, 0.6, 1)][k % 4])
		_drum_balls.append(bl)
	_pop = B.mesh(self, B.sphere(0.09, 12), DRUM, Color.WHITE)
	_pop.material_override = _pop.material_override.duplicate()
	_pop.visible = false


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	_root.gui_input.connect(_gui)
	_hud.add_child(_root)
	_info = _label(24, 20.0, false)
	_tip = _label(22, -86.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	_hud.add_child(_keys)


func _label(fs: int, y: float, bottom: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.anchor_right = 1.0
	if bottom:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(l)
	return l


func _erkki_say(text: String, t := 2.5) -> void:
	if interior != null and _erkki != null:
		interior.say(_erkki, text, t)


# --- Peli ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_animate(delta)
	if _done:
		return
	_t += delta
	_ball_t = maxf(0.0, _ball_t - delta)
	_glare = maxf(0.0, _glare - delta)
	MG.sparks_step(_sparks, delta)
	_mouse = _root.get_local_mouse_position() + Vector2(sin(_t * 5.0), cos(_t * 4.3)) * drunk * 14.0
	_root.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		quit = true
		_end(false)
		return
	_call_t -= delta
	if _call_t <= 0.0 and not _pool.is_empty():
		_call_t = CALL_S
		var n: int = _pool.pop_back()
		_called.append(n)
		_ball_t = 0.8
		Sfx.play("pickup", -10.0, 0.7)
		var call := "%s %d!" % [COLS[int((n - 1) / 15.0)], n]
		_tip.text = "Erkki: \"%s\"" % call
		_erkki_say(call, 2.6)
		if _erkki != null:
			_erkki.restart("Interact", 0.1)
		(_pop.material_override as StandardMaterial3D).albedo_color = BALL_COLS[int((n - 1) / 15.0)]
		if _called.size() >= rival_at:
			_tip.text = "Mummo Elvi: \"BIIINGO!\" Erkki tarkistaa... oikein. Illan palkinto meni."
			if _elvi != null and interior != null:
				interior.say(_elvi, "BIIINGO!", 2.5)
			Sfx.play("lose", -6.0)
			_done = true
			get_tree().create_timer(2.2).timeout.connect(func() -> void:
				_restore()
				finished.emit(false, _false)
				queue_free())
			return
	_info.text = "Bingo · huudettu %d numeroa · merkitse klikkaamalla, rivi täynnä niin BINGO!" % _called.size()
	_keys.set_text("Hiiri merkitsee   %s lopeta" % Settings.cap("mount"))


func _gui(ev: InputEvent) -> void:
	if _done or not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	if _bingo_rect().has_point(_mouse):
		if _has_line():
			Sfx.play("win", -4.0)
			MG.sparks_burst(_sparks, _bingo_rect().get_center(), Color(1.0, 0.85, 0.2), 40)
			_tip.text = "SINÄ: \"BINGO!\" Erkki tarkistaa... OIKEIN! Mummot mulkoilee."
			_erkki_say("Tarkistetaan... OIKEIN! Bingo pöydän päähän!", 2.5)
			_glare = 2.0
			_end(true)
		else:
			_false += 1
			_glare = 1.8
			Sfx.play("alert", -8.0)
			var line: String = ["Ei oo bingo. Istu alas.", "Väärä bingo! Hilkka tuhahtaa."].pick_random()
			_tip.text = "Erkki: \"%s\" Mummot mulkoilee." % line if line.begins_with("Ei") else line
			_erkki_say("Ei oo bingo!", 2.0)
			if interior != null:
				interior.say_id("hilkka", "Hmph!", 1.8)
		return
	for i in 25:
		if _cell_rect(i).has_point(_mouse) and not _marked[i]:
			if _card[i] in _called:
				_marked[i] = true
				Sfx.play("pickup", -12.0, 1.4)
			else:
				_tip.text = "%d ei oo vielä tullu!" % _card[i]


## Rivi täynnä merkittyjä (merkitsemättä ei lasketa, vaikka numero olisi huudettu).
func _has_line() -> bool:
	var lines: Array = []
	for r in 5:
		lines.append(range(r * 5, r * 5 + 5))
	for c in 5:
		lines.append([c, c + 5, c + 10, c + 15, c + 20])
	lines.append([0, 6, 12, 18, 24])
	lines.append([4, 8, 12, 16, 20])
	for l in lines:
		if l.all(func(i): return _marked[i]):
			return true
	return false


func _end(won: bool) -> void:
	_done = true
	get_tree().create_timer(1.6 if won else 0.0).timeout.connect(func() -> void:
		_restore()
		finished.emit(won, _false)
		queue_free())


## Mummojen päät suoriksi ja kävelijä näkyviin.
func _restore() -> void:
	for m in _mummos:
		m.set_override("Head", Vector3.UP, 0.0)
	if interior != null and interior.walker != null:
		interior.walker.visible = true


# --- Animaatio -----------------------------------------------------------------

## Pallokone pyörii (nopeammin arvonnassa), uusi pallo pomppaa ylös, ja väärästä bingosta mummot kääntävät päänsä.
func _animate(_delta: float) -> void:
	var spin := _t * (6.0 if _ball_t > 0.0 else 2.0)
	for k in _drum_balls.size():
		var a := spin + k * 0.8
		_drum_balls[k].position = DRUM + Vector3(cos(a) * 0.2, sin(a * 1.3) * 0.18, sin(a) * 0.2)
	_pop.visible = _ball_t > 0.0
	if _pop.visible:
		var u := 1.0 - _ball_t / 0.8
		_pop.position = DRUM + Vector3(0.25 * u, 0.15 + sin(u * PI) * 0.45, 0.3 * u)
	for m in _mummos:
		var to := _me.position - m.position
		var look := clampf(wrapf(atan2(-to.x, -to.z) - m.rotation.y, -PI, PI), -1.3, 1.3) if _glare > 0.0 else 0.0
		m.set_override("Head", Vector3.UP, look)


# --- HUD: lappu, BINGO-nappi ja huudetut ---------------------------------------

func _card_rect() -> Rect2:
	var sz := _root.size
	var s := clampf(sz.y / 1080.0 * 1.25, 0.7, 1.2)
	return Rect2(Vector2(sz.x - 400 * s - 30, sz.y * 0.5 - 235 * s), Vector2(400, 470) * s)


func _scale() -> float:
	return _card_rect().size.x / 400.0


func _cell_rect(i: int) -> Rect2:
	var cr := _card_rect()
	var s := _scale()
	return Rect2(cr.position + Vector2(20 + (i % 5) * 72, 90 + int(i / 5.0) * 72) * s, Vector2(66, 66) * s)


func _bingo_rect() -> Rect2:
	var cr := _card_rect()
	var s := _scale()
	return Rect2(Vector2(cr.position.x - 230 * s, cr.end.y - 100 * s), Vector2(200, 90) * s)


func _draw_root() -> void:
	var font := ThemeDB.fallback_font
	var s := _scale()
	# Viimeisin pallo ja huudetut numerot vasemmassa yläkulmassa.
	var hb := Rect2(Vector2(30, 70), Vector2(360, 150) * s)
	MG.sign(_root, hb, "", Color(0.08, 0.1, 0.08), Color.WHITE, 18, Color(0.55, 0.4, 0.2))
	_root.draw_string(font, hb.position + Vector2(14, 26), "HUUDETUT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * s), Color(1.0, 0.85, 0.3))
	var sorted := _called.duplicate()
	sorted.sort()
	for k in sorted.size():
		var p := hb.position + Vector2(14 + (k % 10) * (hb.size.x - 24) / 10.0, 50 + int(k / 10.0) * 24 * s)
		_root.draw_string(font, p, str(sorted[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * s), Color(0.9, 0.95, 0.9))
	if not _called.is_empty():
		var n: int = _called.back()
		var bp := hb.position + Vector2(hb.size.x + 60 * s, 60 * s) + Vector2(0, -30.0 * _ball_t)
		MG.ball(_root, bp, 46.0 * s, Color(0.97, 0.97, 0.95), 0.4)
		_root.draw_circle(bp, 30.0 * s, BALL_COLS[int((n - 1) / 15.0)])
		_root.draw_string(font, bp + Vector2(-30, -2) * s, COLS[int((n - 1) / 15.0)], HORIZONTAL_ALIGNMENT_CENTER, 60 * s, int(16 * s), Color.WHITE)
		_root.draw_string(font, bp + Vector2(-30, 18) * s, str(n), HORIZONTAL_ALIGNMENT_CENTER, 60 * s, int(26 * s), Color.WHITE)
	# Oma bingolappu.
	var cr := _card_rect()
	MG.box(_root, cr, Color(0.98, 0.96, 0.88), 10, 10, Color(0.2, 0.35, 0.6), 4)
	for c in 5:
		var hr := Rect2(cr.position + Vector2(20 + c * 72, 22) * s, Vector2(66, 56) * s)
		MG.box(_root, hr, BALL_COLS[c] if c != 2 else Color(0.45, 0.45, 0.5), 6)
		_root.draw_string(font, hr.position + Vector2(0, 42 * s), COLS[c], HORIZONTAL_ALIGNMENT_CENTER, hr.size.x, int(36 * s), Color.WHITE)
	for i in 25:
		var r := _cell_rect(i)
		var hover: bool = r.has_point(_mouse) and not _marked[i]
		MG.box(_root, r, Color(1, 1, 0.85) if hover else Color(1, 1, 1), 6, 0, Color(0.6, 0.6, 0.65), 2)
		if _card[i] == 0:
			_root.draw_string(font, r.position + Vector2(0, 40 * s), "★", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(30 * s), Color(0.9, 0.7, 0.1))
		else:
			_root.draw_string(font, r.position + Vector2(0, 44 * s), str(_card[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(30 * s), Color(0.15, 0.15, 0.2))
		if _marked[i] and _card[i] != 0:  # tussimerkki
			_root.draw_circle(r.get_center(), 26.0 * s, Color(0.85, 0.1, 0.45, 0.45))
			_root.draw_arc(r.get_center(), 26.0 * s, 0, TAU, 24, Color(0.75, 0.05, 0.35, 0.8), 3.0)
	# BINGO-nappi: syttyy, kun rivi on täynnä.
	var br := _bingo_rect()
	var ready := _has_line()
	var pulse := (0.5 + 0.5 * sin(_t * 8.0)) if ready else 0.0
	MG.box(_root, br.grow(pulse * 6.0), Color(0.9, 0.15, 0.1) if ready else Color(0.5, 0.35, 0.3), 16, 8, Color(1.0, 0.85, 0.2), 4)
	_root.draw_string(font, br.position + Vector2(0, 60 * s), "BINGO!", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, int(44 * s), Color(1, 1, 0.9))
	MG.sparks_draw(_root, _sparks)
