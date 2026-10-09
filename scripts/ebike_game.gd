extends CanvasLayer
## Sähköpyörän kasaus autotallin työpöydällä (ebike.gd, #107). Liitokset yksi kerrallaan: ensin valitaan kiinnitys
## (numeronäppäin tai klikkaus), sitten tehdään se:
## "ruuvi"       – kaksi ruuvia kiinni pyörittämällä hiirtä myötäpäivään ympyrää ruuvin ympäri.
## "teippi"      – jeesusteippiä kierretään osan ympäri: vasen nappi pohjassa, hiiri ylös ja alas osan yli. Liian
##                 kova veto rypistää kierroksen (ei lasketa).
## "sahkoteippi" – sama kuin teippi, mutta kapeampi ja tarkempi.
## "nippu"       – nippuside pujotetaan (klikkaus) ja kiristetään: vasen nappi pohjassa nostaa kireyttä, irrotus
##                 vihreällä lukitsee. Yli punaiselle: side katkeaa ja uusi pitää ottaa.
## "rautalanka"  – rautalankaa kierretään A ja D vuorotellen.
## F / Esc lopettaa (tehdyt liitokset jäävät). finished(results) kertoo tehdyt liitokset: liitos -> kiinnitys.

signal finished(results: Dictionary)
signal comment(text: String)

const EBike := preload("res://scripts/ebike.gd")
const TAPE_WRAPS := 6
const WIRE_WRAPS := 4
const TWISTS := 12
const SCREWS := 2
const LINES := {
	"ruuvi": ["Ruuvit pitää. Kestää kuopat ja metsäpolut.", "Myötäpäivään, niin kiristyy."],
	"teippi": ["Jeesusteippi korjaa kaiken. Melkein.", "Tiukasti ympäri, ei ryppyjä."],
	"sahkoteippi": ["Sähköteippi eristää. Ei oikosulkua ojassa.", "Limittäin, ettei kupari näy."],
	"nippu": ["Nippuside napsuu. Ei liian kireälle!", "Vihreällä irti."],
	"rautalanka": ["Rautalanka pitää, mutta kolisee.", "Vääntö kerrallaan, A ja D."],
	"ryppy": ["Rypistyi! Hitaammin.", "Jeesusteippi liimautui itseensä."],
	"poikki": ["Napsis! Side katkesi.", "Liian kireälle. Uus side."],
}

var todo: Array = []  # liitokset, jotka tehdään (ebike.todo())
var supplies := {}  # kopio tarvikkeista; kulutus näkyy tässä (main.gd päivittää ebike.gd:n tuloksesta)
var drunk := 0.0
var results := {}  # liitos -> kiinnitys
var used := {}  # tarvike -> käytetty määrä

var _root: Control
var _info: Label
var _keys: Control
var _tip: Label
var _done := false
var _t := 0.0
var _mouse := Vector2.ZERO
var _area := Rect2()
var _i := 0  # todo-indeksi
var _phase := "valinta"  # valinta / ruuvi / teippi / sahkoteippi / nippu / rautalanka / valmis
var _kind := ""
var _progress := 0.0  # nykyisen vaiheen eteneminen (kierrokset, vääntö, ruuvin kierrokset)
var _screw_i := 0
var _last_ang := 0.0
var _side := 0  # teippi: kummalla puolella osaa hiiri viimeksi oli (-1 ylä, 1 ala)
var _last_mouse := Vector2.ZERO
var _crinkles := 0
var _tension := 0.0
var _threaded := false
var _last_key := ""
var _tip_t := 0.0


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	_root.gui_input.connect(_gui)
	add_child(_root)
	_info = _label(24, 40.0, false)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_tip = _label(22, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	comment.connect(func(t: String) -> void: _tip.text = t)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup.call_deferred()


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


func _setup() -> void:
	_area = Rect2(_root.size / 2.0 - Vector2(460, 250), Vector2(920, 500))
	if todo.is_empty():
		_finish()
		return
	comment.emit("Työpöydällä pyörä, osat ja tarvikkeet. %s ensin." % _cap(EBike.JOINT_NAMES[todo[0]]))


func joint() -> String:
	return todo[_i] if _i < todo.size() else ""


func _have(kind: String) -> int:
	return int(supplies.get(EBike.FASTENERS[kind].supply, 0))


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_mouse = _root.get_local_mouse_position() + Vector2(sin(_t * 5.0), cos(_t * 4.3)) * drunk * 18.0
	_root.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish()
		return
	match _phase:
		"valinta":
			var opts := fasteners()
			for n in opts.size():
				if Input.is_key_pressed(KEY_1 + n):
					_choose(opts[n])
		"ruuvi":
			_screw_tick()
		"teippi", "sahkoteippi":
			_tape_tick()
		"nippu":
			_zip_tick(delta)
		"rautalanka":
			_wire_tick()
	_tip_t -= delta
	if _tip_t <= 0.0 and _phase in LINES:
		_tip_t = 6.0
		comment.emit(LINES[_phase].pick_random())
	_info.text = _status()
	_keys.set_text("%s lopeta (tehdyt jäävät)" % Settings.cap("mount"))


func fasteners() -> Array:
	return EBike.JOINT_FASTENERS if joint() != "johdot" else EBike.WIRE_FASTENERS


func _status() -> String:
	var head := "Liitos %d / %d: %s" % [mini(_i + 1, todo.size()), todo.size(), EBike.JOINT_NAMES.get(joint(), "")]
	match _phase:
		"valinta":
			return head + " · valitse kiinnitys (numero tai klikkaus)"
		"ruuvi":
			return head + " · ruuvi %d / %d · pyöritä hiirtä myötäpäivään ruuvin ympäri" % [mini(_screw_i + 1, SCREWS), SCREWS]
		"teippi", "sahkoteippi":
			return head + " · kierroksia %d / %d · vasen nappi pohjassa, hiiri ylös ja alas osan yli" % [int(_progress), _wraps()]
		"nippu":
			return head + (" · vasen nappi pohjassa kiristää, irrota vihreällä" if _threaded else " · klikkaa: pujota side")
		"rautalanka":
			return head + " · vääntöjä %d / %d · A ja D vuorotellen" % [int(_progress), TWISTS]
	return head


func _wraps() -> int:
	return WIRE_WRAPS if _phase == "sahkoteippi" else TAPE_WRAPS


func _choose(kind: String) -> void:
	if _have(kind) <= 0:
		comment.emit("Ei %s. %s" % [EBike.FASTENERS[kind].name, _where(kind)])
		return
	_kind = kind
	_phase = kind
	_progress = 0.0
	_screw_i = 0
	_crinkles = 0
	_tension = 0.0
	_threaded = false
	_tip_t = 0.0
	Sfx.play("pickup", -6.0, 1.1)


## Vain ensimmäinen kirjain isoksi (String.capitalize() isontaa jokaisen sanan).
static func _cap(t: String) -> String:
	return t.left(1).to_upper() + t.substr(1)


func _where(kind: String) -> String:
	match kind:
		"ruuvi":
			return "Ruuveja kirppiksen ruuvipurkista tai työkalutaululta."
		"teippi":
			return "Jeesusteippiä K-Marketin rautahyllystä."
		"nippu", "sahkoteippi":
			return "K-Marketin rautahyllystä."
		"rautalanka":
			return "Rautalankaa Tokolan vanhasta varastosta."
	return ""


## Liitos valmis: tarvike kulutetaan ja siirrytään seuraavaan.
func _joint_done() -> void:
	if _kind == "" or joint() == "":
		return
	var sup: String = EBike.FASTENERS[_kind].supply
	supplies[sup] = int(supplies.get(sup, 0)) - 1
	used[sup] = int(used.get(sup, 0)) + 1
	results[joint()] = _kind
	Sfx.play("rattle", -4.0, 1.25)
	comment.emit("%s kiinni (%s)." % [_cap(EBike.JOINT_NAMES[joint()]), EBike.FASTENERS[_kind].name])
	_i += 1
	_phase = "valinta"
	_kind = ""
	if _i >= todo.size():
		_phase = "valmis"
		get_tree().create_timer(1.0).timeout.connect(_finish)


func _center() -> Vector2:
	return _area.position + Vector2(_area.size.x * 0.68, _area.size.y * 0.5)


func _screw_pos(i: int) -> Vector2:
	return _center() + Vector2(-90 + i * 180, 0)


func _screw_tick() -> void:
	var c := _screw_pos(_screw_i)
	var a := (_mouse - c).angle()
	var da := wrapf(a - _last_ang, -PI, PI)
	_last_ang = a
	if da > 0.0 and da < 0.6 and _mouse.distance_to(c) > 25.0 and _mouse.distance_to(c) < 160.0:
		_progress += da / (TAU * 3.0)
		if _progress >= 1.0:
			_progress = 0.0
			_screw_i += 1
			Sfx.play("rattle", -8.0, 1.4)
			if _screw_i >= SCREWS:
				_joint_done()


func _tape_tick() -> void:
	var c := _center()
	var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var dv := _mouse - _last_mouse
	_last_mouse = _mouse
	if not held or absf(_mouse.x - c.x) > 120.0:
		return
	var side := -1 if _mouse.y < c.y - 50.0 else (1 if _mouse.y > c.y + 50.0 else 0)
	if side != 0 and side != _side:
		if _side != 0:
			# Kierros osan yli: liian kova veto rypistää (tarkemmin sähköteipillä).
			var limit := 38.0 if _phase == "sahkoteippi" else 55.0
			if dv.length() > limit:
				_crinkles += 1
				Sfx.play("whoosh", -14.0, 1.8)
				comment.emit(LINES.ryppy.pick_random())
			else:
				_progress += 0.5
				Sfx.play("whoosh", -16.0, 1.3)
				if _progress >= _wraps():
					_joint_done()
					return
		_side = side


func _zip_tick(delta: float) -> void:
	if not _threaded:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_tension += delta * (0.55 + drunk * 0.4)
		if _tension > 1.0:
			_zip_break()
	elif _tension > 0.0:
		if _tension >= 0.68 and _tension <= 0.88:
			_joint_done()
		elif _tension < 0.68:
			comment.emit("Liian löysällä. Kiristä uudestaan.")
			_tension = 0.0
		else:
			_tension = 1.01  # yli vihreän: napsahtaa poikki seuraavalla kiristyksellä
			_zip_break()


## Nippuside katkesi: uusi side pussista, jos on.
func _zip_break() -> void:
	Sfx.play("glass", -12.0, 2.0)
	comment.emit(LINES.poikki.pick_random())
	supplies.nippu = int(supplies.get("nippu", 0)) - 1
	used.nippu = int(used.get("nippu", 0)) + 1
	_tension = 0.0
	_threaded = false
	if supplies.nippu <= 0:
		comment.emit("Nippusiteet loppu! Valitse toinen kiinnitys.")
		_phase = "valinta"


func _wire_tick() -> void:
	for pair in [["left", "A"], ["right", "D"]]:
		if Input.is_action_just_pressed(pair[0]) and pair[1] != _last_key:
			_last_key = pair[1]
			_progress += 1.0
			Sfx.play("rattle", -14.0, randf_range(1.6, 2.0))
			if _progress >= TWISTS:
				_joint_done()
				return


func _gui(ev: InputEvent) -> void:
	if _done or not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	match _phase:
		"valinta":
			var opts := fasteners()
			for n in opts.size():
				if _option_rect(n).has_point(_mouse):
					_choose(opts[n])
		"nippu":
			if not _threaded:
				_threaded = true
				Sfx.play("pickup", -8.0, 1.6)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit(results)
	queue_free()


# --- Piirto -------------------------------------------------------------------

const BENCH := Color(0.42, 0.3, 0.2)
const FRAME := Color(0.78, 0.08, 0.08)
const DARK := Color(0.12, 0.12, 0.13)
const TEAL := Color(0.0, 0.55, 0.55)
const TAPE := Color(0.66, 0.67, 0.64)


func _option_rect(n: int) -> Rect2:
	return Rect2(_area.position + Vector2(_area.size.x * 0.42, 110 + n * 78), Vector2(_area.size.x * 0.52, 64))


func _draw_root() -> void:
	var font := ThemeDB.fallback_font
	_root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0, 0, 0, 0.55))
	_root.draw_rect(_area.grow(6), Color(0.08, 0.06, 0.05))
	_root.draw_rect(_area, BENCH)
	for k in 6:  # työpöydän laudat
		_root.draw_line(_area.position + Vector2(0, 80 * k + 20), _area.position + Vector2(_area.size.x, 80 * k + 20), BENCH.darkened(0.25), 2.0)
	_draw_bike(Rect2(_area.position + Vector2(20, 120), Vector2(_area.size.x * 0.36, 260)))
	match _phase:
		"valinta":
			_draw_options(font)
		"ruuvi":
			_draw_part()
			for i in SCREWS:
				var p := _screw_pos(i)
				var turned := 1.0 if i < _screw_i else (_progress if i == _screw_i else 0.0)
				_root.draw_circle(p, 26.0, Color(0.75, 0.75, 0.78))
				var a := turned * TAU * 3.0
				_root.draw_line(p - Vector2(cos(a), sin(a)) * 18.0, p + Vector2(cos(a), sin(a)) * 18.0, DARK, 4.0)
				if i == _screw_i:
					_root.draw_arc(p, 60.0, -PI / 2.0, -PI / 2.0 + TAU * _progress, 32, Color(0.3, 0.9, 0.4), 6.0)
		"teippi", "sahkoteippi":
			_draw_part()
			var c := _center()
			var col := TAPE if _phase == "teippi" else Color(0.1, 0.2, 0.75)
			for w in int(_progress):
				_root.draw_rect(Rect2(c + Vector2(-60 + w * 20, -48), Vector2(16, 96)), col)
			_root.draw_line(c + Vector2(-140, -50), c + Vector2(140, -50), Color(1, 1, 1, 0.25), 2.0)
			_root.draw_line(c + Vector2(-140, 50), c + Vector2(140, 50), Color(1, 1, 1, 0.25), 2.0)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_root.draw_line(c + Vector2(-60 + int(_progress) * 20, 0), _mouse, col, 10.0)
			_root.draw_circle(_mouse, 22.0, col.darkened(0.2))
			_root.draw_circle(_mouse, 9.0, BENCH)
		"nippu":
			_draw_part()
			var c := _center()
			_root.draw_rect(Rect2(c + Vector2(-8, -70), Vector2(16, 140)), Color(0.95, 0.95, 0.92) if _threaded else Color(0.95, 0.95, 0.92, 0.3))
			var bar := Rect2(c + Vector2(-150, 110), Vector2(300, 22))
			_root.draw_rect(bar, Color(0.1, 0.1, 0.1))
			_root.draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.68, 0), Vector2(bar.size.x * 0.2, bar.size.y)), Color(0.2, 0.7, 0.3))
			_root.draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.88, 0), Vector2(bar.size.x * 0.12, bar.size.y)), Color(0.8, 0.15, 0.1))
			_root.draw_rect(Rect2(bar.position + Vector2(bar.size.x * clampf(_tension, 0.0, 1.0) - 3, -4), Vector2(6, bar.size.y + 8)), Color.WHITE)
		"rautalanka":
			_draw_part()
			var c := _center()
			for w in int(_progress):
				var x := -110 + w * 19
				_root.draw_line(c + Vector2(x, -50), c + Vector2(x + 14, 50), Color(0.6, 0.6, 0.62), 4.0)
		"valmis":
			_root.draw_string(font, _center() + Vector2(-160, 0), "SÄHKÖPYÖRÄ KASASSA!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1.0, 0.85, 0.2))


func _draw_options(font: Font) -> void:
	var opts := fasteners()
	_root.draw_string(font, _area.position + Vector2(_area.size.x * 0.42, 90), "Kiinnitys: %s" % EBike.JOINT_NAMES[joint()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	const NOTES := {"ruuvi": "kestää, vie aikaa", "teippi": "nopea, irtoaa kuopissa", "nippu": "siisti, irtoaa joskus",
		"rautalanka": "pitää, mutta kolisee", "sahkoteippi": "eristää, ei oikosulkua"}
	for n in opts.size():
		var k: String = opts[n]
		var r := _option_rect(n)
		var have := _have(k)
		var hover := r.has_point(_mouse)
		_root.draw_rect(r, Color(0.2, 0.17, 0.14) if have > 0 else Color(0.15, 0.13, 0.12, 0.7))
		if hover and have > 0:
			_root.draw_rect(r, Color(1.0, 0.85, 0.3), false, 3.0)
		var col := Color.WHITE if have > 0 else Color(0.55, 0.55, 0.55)
		_root.draw_string(font, r.position + Vector2(16, 28), "%d  %s (%d)" % [n + 1, _cap(EBike.FASTENERS[k].name), have],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		_root.draw_string(font, r.position + Vector2(48, 52), NOTES[k] if have > 0 else _where(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(0.85, 0.8, 0.7) if have > 0 else Color(0.6, 0.55, 0.5))


## Nykyinen osa isona työpöydällä (moottori, akku, ohjainkotelo, kahva tai johtonippu).
func _draw_part() -> void:
	var c := _center()
	match joint():
		"moottori":
			_root.draw_circle(c, 120.0, DARK)
			_root.draw_circle(c, 70.0, Color(0.25, 0.25, 0.27))
			for k in 12:
				var a := k * TAU / 12.0
				_root.draw_line(c + Vector2(cos(a), sin(a)) * 72.0, c + Vector2(cos(a), sin(a)) * 118.0, Color(0.6, 0.6, 0.62), 2.0)
		"akku":
			_root.draw_rect(Rect2(c - Vector2(150, 70), Vector2(300, 140)), TEAL)
			_root.draw_rect(Rect2(c - Vector2(150, 70), Vector2(80, 140)), DARK)
			_root.draw_string(ThemeDB.fallback_font, c + Vector2(-50, 10), "18V Li-ion ×4", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		"ohjain":
			_root.draw_rect(Rect2(c - Vector2(140, 50), Vector2(280, 100)), DARK)
			_root.draw_string(ThemeDB.fallback_font, c + Vector2(-110, 8), "CONTROLLER 36V", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.8, 0.8))
		"kaasu":
			_root.draw_rect(Rect2(c - Vector2(160, 18), Vector2(320, 36)), Color(0.7, 0.7, 0.72))
			_root.draw_rect(Rect2(c - Vector2(40, 32), Vector2(110, 64)), Color(0.85, 0.75, 0.1))
		"johdot":
			for k in 4:
				var y := -45 + k * 30
				_root.draw_line(c + Vector2(-170, y), c + Vector2(170, y + 8), [Color.RED, Color.BLACK, Color.BLUE, Color.YELLOW][k], 6.0)
			_root.draw_rect(Rect2(c - Vector2(25, 60), Vector2(50, 120)), Color(0.75, 0.55, 0.2))  # kuparit näkyy


## Pyörä sivulta: tehdyt liitokset vihreinä, nykyinen keltaisena.
func _draw_bike(r: Rect2) -> void:
	var o := r.position
	var s := r.size.x / 340.0
	var back := o + Vector2(70, 190) * s
	var front := o + Vector2(270, 190) * s
	for w in [back, front]:
		_root.draw_arc(w, 60.0 * s, 0, TAU, 32, DARK, 5.0)
	var seat := o + Vector2(130, 80) * s
	var head := o + Vector2(240, 80) * s
	var crank := o + Vector2(150, 190) * s
	for seg in [[seat, head], [head, crank], [seat, crank], [crank, back], [seat, back], [head, front]]:
		_root.draw_line(seg[0], seg[1], FRAME, 5.0)
	var spots := {"moottori": back, "akku": o + Vector2(90, 110) * s, "ohjain": o + Vector2(195, 135) * s,
		"kaasu": o + Vector2(250, 55) * s, "johdot": o + Vector2(160, 110) * s}
	for j in spots:
		var col := Color(0.5, 0.5, 0.5, 0.6)
		if results.has(j):
			col = Color(0.3, 0.9, 0.4)
		elif j == joint():
			col = Color(1.0, 0.85, 0.2) if fmod(_t, 0.8) < 0.5 else Color(1.0, 0.6, 0.1)
		elif not (j in todo):
			col = Color(0.3, 0.7, 0.4, 0.7)
		_root.draw_circle(spots[j], 12.0, col)
