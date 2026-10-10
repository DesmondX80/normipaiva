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
const MG := preload("res://scripts/mg_draw.gd")
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
var _sparks: Array = []  # kipinät liitoksen valmistuessa (mg_draw.gd)
var _shake := 0.0


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
	MG.sparks_step(_sparks, delta)
	_shake = maxf(0.0, _shake - delta)
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
	MG.sparks_burst(_sparks, _center(), Color(1.0, 0.85, 0.3), 26)
	_shake = 0.25
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
				_shake = 0.15
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

const BENCH := Color(0.5, 0.36, 0.22)
const FRAME := Color(0.8, 0.1, 0.08)
const DARK := Color(0.13, 0.13, 0.14)
const TEAL := Color(0.0, 0.58, 0.58)
const TAPE := Color(0.68, 0.69, 0.66)
const BLUE_TAPE := Color(0.1, 0.22, 0.75)
const STEEL := Color(0.72, 0.73, 0.76)
const MAT := Color(0.16, 0.36, 0.24)


func _option_rect(n: int) -> Rect2:
	return Rect2(_area.position + Vector2(_area.size.x * 0.42, 118 + n * 82), Vector2(_area.size.x * 0.54, 70))


func _draw_root() -> void:
	var font := ThemeDB.fallback_font
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _shake
	_root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0, 0, 0, 0.6))
	_root.draw_set_transform(sh)
	_draw_workshop()
	_draw_bike(Rect2(_area.position + Vector2(18, 150), Vector2(_area.size.x * 0.36, 250)))
	match _phase:
		"valinta":
			_draw_options(font)
		"ruuvi":
			_draw_mat()
			_draw_part()
			for i in SCREWS:
				var p := _screw_pos(i)
				var turned := 1.0 if i < _screw_i else (_progress if i == _screw_i else 0.0)
				_draw_screw(p, turned, i == _screw_i)
		"teippi", "sahkoteippi":
			_draw_mat()
			_draw_part()
			_draw_tape(_phase == "sahkoteippi")
		"nippu":
			_draw_mat()
			_draw_part()
			_draw_zip()
		"rautalanka":
			_draw_mat()
			_draw_part()
			_draw_wire_twist()
		"valmis":
			_draw_mat()
			MG.sign(_root, Rect2(_center() - Vector2(190, 45), Vector2(380, 90)), "SÄHKÖPYÖRÄ\nKASASSA!", Color(0.12, 0.45, 0.2), Color(1.0, 0.95, 0.6), 30)
	MG.sparks_draw(_root, _sparks)
	_root.draw_set_transform(Vector2.ZERO)


## Työpaja: reikälevyseinä työkaluineen, lamppu ja puinen työpöytä.
func _draw_workshop() -> void:
	var a := _area
	MG.box(_root, a.grow(10), Color(0.1, 0.07, 0.05), 12, 14)
	var wall := Rect2(a.position, Vector2(a.size.x, 96))
	MG.grad_rect(_root, wall, Color(0.62, 0.5, 0.36), Color(0.5, 0.4, 0.28))
	for x in range(int(a.position.x) + 14, int(a.end.x), 22):  # reikälevy
		for y in range(int(a.position.y) + 12, int(a.position.y) + 92, 20):
			_root.draw_circle(Vector2(x, y), 2.2, Color(0.3, 0.22, 0.14))
	# Työkalut seinällä: jakoavain, vasara, ruuvimeisselit, sivuleikkuri.
	var t0 := a.position + Vector2(40, 18)
	_root.draw_line(t0, t0 + Vector2(0, 62), STEEL.darkened(0.1), 8.0)
	_root.draw_circle(t0, 12.0, STEEL.darkened(0.1))
	_root.draw_circle(t0, 6.0, Color(0.62, 0.5, 0.36))
	var h0 := a.position + Vector2(100, 20)
	_root.draw_line(h0 + Vector2(0, 8), h0 + Vector2(0, 70), Color(0.55, 0.35, 0.18), 9.0)
	MG.solid(_root, Rect2(h0 + Vector2(-22, -2), Vector2(44, 16)), Color(0.25, 0.25, 0.27))
	for k in 3:
		var sd := a.position + Vector2(160 + k * 26, 18)
		MG.solid(_root, Rect2(sd, Vector2(12, 30)), [Color(0.85, 0.15, 0.1), Color(0.95, 0.75, 0.1), Color(0.15, 0.4, 0.8)][k], false)
		_root.draw_line(sd + Vector2(6, 30), sd + Vector2(6, 64), STEEL, 4.0)
	var lamp := Vector2(a.position.x + a.size.x * 0.68, a.position.y + 8)
	MG.glow(_root, lamp + Vector2(0, 160), 380.0, Color(1.0, 0.9, 0.6, 0.5))
	_root.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-34, 30), lamp + Vector2(34, 30), lamp + Vector2(18, 0), lamp + Vector2(-18, 0)]),
		Color(0.2, 0.35, 0.25))
	_root.draw_circle(lamp + Vector2(0, 30), 12.0, Color(1.0, 0.97, 0.8))
	MG.sign(_root, Rect2(a.position + Vector2(250, 26), Vector2(200, 42)), "SLN-73 TALLI", Color(0.15, 0.25, 0.55), Color.WHITE, 20)
	MG.wood(_root, Rect2(a.position + Vector2(0, 96), Vector2(a.size.x, a.size.y - 96)), BENCH, 68.0, 7)
	_root.draw_line(a.position + Vector2(0, 96), a.position + Vector2(a.size.x, 96), Color(0.2, 0.13, 0.07), 4.0)


## Vihreä leikkuualusta osan alla ruudukkoineen.
func _draw_mat() -> void:
	var c := _center()
	var r := Rect2(c - Vector2(250, 170), Vector2(500, 340))
	MG.box(_root, r, MAT, 10, 8)
	for k in range(1, 10):
		_root.draw_line(r.position + Vector2(k * 50, 0), r.position + Vector2(k * 50, r.size.y), MAT.lightened(0.12), 1.0)
	for k in range(1, 7):
		_root.draw_line(r.position + Vector2(0, k * 50), r.position + Vector2(r.size.x, k * 50), MAT.lightened(0.12), 1.0)


func _draw_options(font: Font) -> void:
	var opts := fasteners()
	MG.sign(_root, Rect2(_area.position + Vector2(_area.size.x * 0.42, 104 - 52), Vector2(_area.size.x * 0.54, 40)),
		"Kiinnitys: %s" % EBike.JOINT_NAMES[joint()], Color(0.95, 0.92, 0.82), Color(0.15, 0.1, 0.05), 20, Color(0.35, 0.25, 0.15))
	const NOTES := {"ruuvi": "kestää, vie aikaa", "teippi": "nopea, irtoaa kuopissa", "nippu": "siisti, irtoaa joskus",
		"rautalanka": "pitää, mutta kolisee", "sahkoteippi": "eristää, ei oikosulkua"}
	for n in opts.size():
		var k: String = opts[n]
		var r := _option_rect(n)
		var have := _have(k)
		var hover := r.has_point(_mouse) and have > 0
		var card := Color(0.97, 0.94, 0.86) if have > 0 else Color(0.6, 0.58, 0.54)
		MG.box(_root, r.grow(3.0 if hover else 0.0), card, 10, 6 if have > 0 else 0, Color(1.0, 0.75, 0.2) if hover else Color(0.3, 0.22, 0.14), 3 if hover else 2)
		_icon(k, r.position + Vector2(44, r.size.y / 2.0), 26.0, have > 0)
		var ink := Color(0.12, 0.08, 0.05) if have > 0 else Color(0.35, 0.33, 0.3)
		_root.draw_string(font, r.position + Vector2(84, 30), "%d  %s" % [n + 1, _cap(EBike.FASTENERS[k].name)], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
		_root.draw_string(font, r.position + Vector2(84, 54), NOTES[k] if have > 0 else _where(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(0.35, 0.28, 0.2) if have > 0 else Color(0.4, 0.37, 0.33))
		# Määrämerkki oikeassa reunassa.
		var badge := r.position + Vector2(r.size.x - 30, r.size.y / 2.0)
		MG.ball(_root, badge, 18.0, Color(0.2, 0.6, 0.3) if have > 0 else Color(0.5, 0.2, 0.15), 0.3)
		_root.draw_string(font, badge + Vector2(-18, 8), str(have), HORIZONTAL_ALIGNMENT_CENTER, 36, 20, Color.WHITE)


## Tarvikkeen kuvake valintakortissa.
func _icon(kind: String, c: Vector2, r: float, on: bool) -> void:
	var dim := 1.0 if on else 0.55
	match kind:
		"ruuvi":
			for k in 3:
				var p := c + Vector2(-12 + k * 12, -4 + (k % 2) * 10)
				_root.draw_line(p, p + Vector2(4, 18), STEEL.darkened(0.2), 4.0)
				MG.ball(_root, p, 7.0, STEEL * dim, 0.5)
				_root.draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), DARK, 2.0)
		"teippi", "sahkoteippi":
			var col := (TAPE if kind == "teippi" else BLUE_TAPE) * dim
			MG.ball(_root, c, r, col, 0.3)
			_root.draw_circle(c, r * 0.55, Color(0.82, 0.68, 0.45))
			_root.draw_circle(c, r * 0.4, Color(0.97, 0.94, 0.86))
			_root.draw_rect(Rect2(c + Vector2(r * 0.6, 4), Vector2(r * 0.9, 10)), col.darkened(0.1))
		"nippu":
			for k in 4:
				var x := c.x - 15 + k * 10
				_root.draw_line(Vector2(x, c.y - 22), Vector2(x + 4, c.y + 22), Color(0.95, 0.95, 0.92) * dim, 5.0)
				MG.solid(_root, Rect2(Vector2(x - 5, c.y - 26), Vector2(10, 8)), Color(0.9, 0.9, 0.86) * dim, false)
		"rautalanka":
			for k in 4:
				_root.draw_arc(c, r - k * 4.0, 0, TAU, 24, Color(0.55, 0.55, 0.58) * dim, 3.0)


## Ruuvi: ristipää, kierteet ja edistymisrengas.
func _draw_screw(p: Vector2, turned: float, active: bool) -> void:
	var a := turned * TAU * 3.0
	if active:
		_root.draw_arc(p, 62.0, 0, TAU, 48, Color(1, 1, 1, 0.15), 10.0)
		_root.draw_arc(p, 62.0, -PI / 2.0, -PI / 2.0 + TAU * turned, 48, Color(0.35, 0.95, 0.45), 10.0)
		var hint := p + Vector2(cos(_t * 4.0), sin(_t * 4.0)) * 62.0  # pyöritä tähän suuntaan
		_root.draw_circle(hint, 6.0, Color(1.0, 0.85, 0.3, 0.8))
	var sink := 1.0 - turned * 0.25
	MG.ball(_root, p, 26.0 * sink, STEEL if turned < 1.0 else STEEL.darkened(0.15), 0.6)
	for k in 2:
		var b := a + k * PI / 2.0
		_root.draw_line(p - Vector2(cos(b), sin(b)) * 15.0, p + Vector2(cos(b), sin(b)) * 15.0, DARK, 5.0)
	if turned >= 1.0:
		_root.draw_string(ThemeDB.fallback_font, p + Vector2(-20, 52), "✔", HORIZONTAL_ALIGNMENT_CENTER, 40, 28, Color(0.35, 0.95, 0.45))


## Teippi: kierrokset osan ympärillä kuitukuviolla, rullasta vedetty pätkä hiiren perässä.
func _draw_tape(electric: bool) -> void:
	var c := _center()
	var col := BLUE_TAPE if electric else TAPE
	var w := 16.0 if electric else 22.0
	for k in int(_progress * 2.0):
		var x := c.x - 70 + k * (w * 0.6)
		var r := Rect2(Vector2(x, c.y - 56), Vector2(w, 112))
		MG.grad_rect(_root, r, col.lightened(0.15), col.darkened(0.15))
		if not electric:
			for f in 6:
				_root.draw_line(r.position + Vector2(2, 10 + f * 17), r.position + Vector2(w - 2, 14 + f * 17), col.darkened(0.12), 1.0)
		_root.draw_rect(r, col.darkened(0.35), false, 1.5)
	for k in _crinkles:  # rypyt
		var p := c + Vector2(-90 + k * 37 % 180, -30 + (k * 53) % 60)
		_root.draw_polyline(PackedVector2Array([p, p + Vector2(8, -6), p + Vector2(16, 4), p + Vector2(24, -4)]), col.darkened(0.4), 2.0)
	for y in [-50.0, 50.0]:
		_root.draw_dashed_line(c + Vector2(-140, y), c + Vector2(140, y), Color(1, 1, 1, 0.35), 3.0, 10.0)
	var roll := _mouse
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_root.draw_line(c + Vector2(-70 + int(_progress * 2.0) * (w * 0.6), 0), roll, col, w * 0.8)
	MG.ball(_root, roll, 30.0, col, 0.25)
	_root.draw_circle(roll, 16.0, Color(0.82, 0.68, 0.45))
	_root.draw_circle(roll, 11.0, MAT)


## Nippuside: hammastettu nauha, lukkopää ja kireysmittari.
func _draw_zip() -> void:
	var c := _center()
	var white := Color(0.96, 0.96, 0.93)
	if _threaded:
		var tight := clampf(_tension, 0.0, 1.0)
		var loop := Rect2(c + Vector2(-60 + tight * 30, -80 + tight * 20), Vector2(120 - tight * 60, 160 - tight * 40))
		MG.box(_root, loop, Color(0, 0, 0, 0), int(40 - tight * 20), 0, white, 7)
		MG.solid(_root, Rect2(loop.position + Vector2(loop.size.x / 2.0 - 12, -12), Vector2(24, 18)), white)
		for k in 8:
			_root.draw_line(loop.position + Vector2(loop.size.x / 2.0 + 14 + k * 9, -4), loop.position + Vector2(loop.size.x / 2.0 + 18 + k * 9, 4), Color(0.8, 0.8, 0.78), 2.0)
		_root.draw_line(loop.position + Vector2(loop.size.x / 2.0 + 12, 0), loop.position + Vector2(loop.size.x / 2.0 + 90 + tight * 40, 0), white, 7.0)
	else:
		var y := c.y + sin(_t * 3.0) * 6.0
		_root.draw_line(Vector2(c.x - 120, y - 110), Vector2(c.x + 120, y - 110), white, 7.0)
		MG.solid(_root, Rect2(Vector2(c.x - 132, y - 120), Vector2(22, 18)), white)
		_root.draw_string(ThemeDB.fallback_font, Vector2(c.x - 150, y - 130), "klikkaa: pujota side", HORIZONTAL_ALIGNMENT_CENTER, 300, 18, Color(1, 1, 1, 0.8))
	var bar := Rect2(c + Vector2(-160, 120), Vector2(320, 26))
	MG.box(_root, bar.grow(4), Color(0.08, 0.08, 0.08), 8)
	MG.grad_rect(_root, Rect2(bar.position, Vector2(bar.size.x * 0.68, bar.size.y)), Color(0.6, 0.6, 0.6), Color(0.4, 0.4, 0.4))
	MG.grad_rect(_root, Rect2(bar.position + Vector2(bar.size.x * 0.68, 0), Vector2(bar.size.x * 0.2, bar.size.y)), Color(0.35, 0.9, 0.45), Color(0.15, 0.6, 0.25))
	MG.grad_rect(_root, Rect2(bar.position + Vector2(bar.size.x * 0.88, 0), Vector2(bar.size.x * 0.12, bar.size.y)), Color(0.95, 0.3, 0.2), Color(0.6, 0.1, 0.08))
	var nx := bar.position.x + bar.size.x * clampf(_tension, 0.0, 1.0)
	_root.draw_colored_polygon(PackedVector2Array([Vector2(nx, bar.position.y - 2), Vector2(nx - 9, bar.position.y - 16), Vector2(nx + 9, bar.position.y - 16)]), Color.WHITE)
	_root.draw_line(Vector2(nx, bar.position.y), Vector2(nx, bar.end.y), Color.WHITE, 3.0)
	_root.draw_string(ThemeDB.fallback_font, bar.position + Vector2(0, 50), "KIREYS", HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 18, Color(1, 1, 1, 0.8))


## Rautalanka: kierteet osan yli väännöittäin, langan päät sojottavat.
func _draw_wire_twist() -> void:
	var c := _center()
	var wire := Color(0.6, 0.6, 0.63)
	for k in int(_progress):
		var x := c.x - 120 + k * 20
		_root.draw_line(Vector2(x, c.y - 60), Vector2(x + 16, c.y + 60), wire.darkened(0.3), 6.0)
		_root.draw_line(Vector2(x, c.y - 60), Vector2(x + 16, c.y + 60), wire, 3.0)
	var tip := c + Vector2(-120 + int(_progress) * 20, 70)
	_root.draw_line(tip, tip + Vector2(30, 40 + sin(_t * 10.0) * 8.0), wire, 3.0)
	for i in 2:
		var key: String = ["A", "D"][i]
		var kr := Rect2(c + Vector2(-110 + i * 160, 120), Vector2(60, 50))
		var lit := key != _last_key
		MG.box(_root, kr, Color(0.95, 0.92, 0.85) if lit else Color(0.5, 0.48, 0.45), 8, 4, Color(0.2, 0.15, 0.1), 2)
		_root.draw_string(ThemeDB.fallback_font, kr.position + Vector2(0, 36), key, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, 28, Color(0.15, 0.1, 0.05))


## Nykyinen osa isona alustalla: napamoottori, Makitan akut, ohjainkotelo, kaasukahva tai johtonippu.
func _draw_part() -> void:
	var c := _center()
	var font := ThemeDB.fallback_font
	match joint():
		"moottori":
			MG.ball(_root, c, 120.0, Color(0.2, 0.2, 0.22), 0.25)
			_root.draw_arc(c, 104.0, 0, TAU, 48, Color(0.32, 0.32, 0.34), 6.0)
			for k in 18:  # pinnareiät laipassa
				var a := k * TAU / 18.0
				_root.draw_circle(c + Vector2(cos(a), sin(a)) * 92.0, 4.0, Color(0.06, 0.06, 0.07))
			MG.ball(_root, c, 48.0, STEEL.darkened(0.2), 0.6)
			MG.ball(_root, c, 16.0, STEEL, 0.7)
			_root.draw_line(c + Vector2(80, 70), c + Vector2(150, 140), DARK, 10.0)  # kaapeli
			_root.draw_string(font, c + Vector2(-60, -60), "36V 350W", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(0.85, 0.85, 0.85))
		"akku":
			for k in 4:
				var r := Rect2(c + Vector2(-150 + (k % 2) * 152, -70 + (k / 2) * 72), Vector2(146, 66))
				MG.solid(_root, r, TEAL)
				MG.solid(_root, Rect2(r.position, Vector2(40, r.size.y)), DARK)
				_root.draw_string(font, r.position + Vector2(46, 28), "makita", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
				_root.draw_string(font, r.position + Vector2(46, 52), "18V 3.0Ah", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 1, 1))
				_root.draw_circle(r.position + Vector2(20, 20), 4.0, Color(0.3, 1.0, 0.4) if fmod(_t + k * 0.3, 1.2) < 0.6 else Color(0.1, 0.3, 0.12))
		"ohjain":
			var r := Rect2(c - Vector2(150, 55), Vector2(300, 110))
			MG.solid(_root, r, Color(0.55, 0.56, 0.6))
			for k in 9:  # jäähdytysrivat
				_root.draw_line(r.position + Vector2(20 + k * 30, 8), r.position + Vector2(20 + k * 30, 30), Color(0.4, 0.41, 0.45), 4.0)
			MG.sign(_root, Rect2(r.position + Vector2(60, 50), Vector2(180, 40)), "CONTROLLER 36V", Color(0.1, 0.1, 0.12), Color(0.9, 0.9, 0.9), 16, Color(0.3, 0.3, 0.32))
			for k in 4:
				_root.draw_line(r.position + Vector2(r.size.x, 30 + k * 18), r.position + Vector2(r.size.x + 60, 20 + k * 26),
					[Color.RED, Color.BLACK, Color.BLUE, Color.YELLOW][k], 5.0)
		"kaasu":
			MG.solid(_root, Rect2(c - Vector2(200, 16), Vector2(400, 32)), STEEL)
			MG.solid(_root, Rect2(c + Vector2(60, -30), Vector2(130, 60)), Color(0.12, 0.12, 0.12))
			MG.solid(_root, Rect2(c + Vector2(-20, -36), Vector2(80, 72)), Color(0.95, 0.78, 0.1))
			for k in 6:
				_root.draw_line(c + Vector2(-12 + k * 12, -34), c + Vector2(-12 + k * 12, 34), Color(0.75, 0.6, 0.05), 3.0)
			_root.draw_line(c + Vector2(20, 36), c + Vector2(40, 140), DARK, 6.0)
		"johdot":
			for k in 4:
				var y := -48.0 + k * 32.0
				var col: Color = [Color(0.85, 0.1, 0.1), Color(0.1, 0.1, 0.1), Color(0.1, 0.3, 0.85), Color(0.95, 0.8, 0.1)][k]
				_root.draw_polyline(PackedVector2Array([c + Vector2(-200, y), c + Vector2(-90, y + 6), c + Vector2(-30, y + 2)]), col.darkened(0.3), 11.0)
				_root.draw_polyline(PackedVector2Array([c + Vector2(-200, y), c + Vector2(-90, y + 6), c + Vector2(-30, y + 2)]), col, 7.0)
				_root.draw_polyline(PackedVector2Array([c + Vector2(30, y + 2), c + Vector2(110, y - 4), c + Vector2(200, y + 4)]), col.darkened(0.3), 11.0)
				_root.draw_polyline(PackedVector2Array([c + Vector2(30, y + 2), c + Vector2(110, y - 4), c + Vector2(200, y + 4)]), col, 7.0)
				_root.draw_line(c + Vector2(-30, y + 2), c + Vector2(30, y + 2), Color(0.85, 0.55, 0.25), 4.0)  # kuparit näkyy


## Pyörä sivulta: renkaat pinnoineen, punainen runko kiiltoineen, satula ja tanko. Liitoskohdat merkkeinä:
## tehdyt vihreänä, nykyinen sykkien keltaisena, tekemättömät harmaana.
func _draw_bike(r: Rect2) -> void:
	var o := r.position
	var s := r.size.x / 340.0
	MG.box(_root, Rect2(o - Vector2(6, 46), r.size + Vector2(12, 60)), Color(0.95, 0.92, 0.84, 0.92), 12, 6, Color(0.35, 0.25, 0.15), 2)
	MG.sign(_root, Rect2(o + Vector2(r.size.x / 2.0 - 90, -38), Vector2(180, 30)), "TYÖJÄRJESTYS", Color(0.15, 0.25, 0.55), Color.WHITE, 16)
	var back := o + Vector2(70, 190) * s
	var front := o + Vector2(270, 190) * s
	for w in [back, front]:
		_root.draw_circle(w, 62.0 * s, Color(0.08, 0.08, 0.08))
		_root.draw_circle(w, 52.0 * s, Color(0.95, 0.92, 0.84))
		_root.draw_arc(w, 50.0 * s, 0, TAU, 32, STEEL, 3.0)
		for k in 12:
			var a := k * TAU / 12.0 + _t * 0.5
			_root.draw_line(w, w + Vector2(cos(a), sin(a)) * 50.0 * s, STEEL.darkened(0.2), 1.0)
		_root.draw_circle(w, 6.0 * s, STEEL)
	var seat := o + Vector2(130, 80) * s
	var head := o + Vector2(240, 80) * s
	var crank := o + Vector2(150, 190) * s
	for seg in [[seat, head], [head, crank], [seat, crank], [crank, back], [seat, back], [head, front]]:
		_root.draw_line(seg[0], seg[1], FRAME.darkened(0.35), 9.0 * s)
		_root.draw_line(seg[0], seg[1], FRAME, 6.0 * s)
		_root.draw_line(seg[0] + Vector2(0, -2), seg[1] + Vector2(0, -2), FRAME.lightened(0.4), 1.5)
	MG.solid(_root, Rect2(seat + Vector2(-24, -16) * s, Vector2(48, 12) * s), DARK)
	_root.draw_line(head, head + Vector2(10, -30) * s, STEEL, 5.0 * s)
	_root.draw_line(head + Vector2(-10, -32) * s, head + Vector2(34, -32) * s, DARK, 6.0 * s)
	_root.draw_circle(crank, 14.0 * s, STEEL.darkened(0.2))
	var spots := {"moottori": back, "akku": o + Vector2(90, 110) * s, "ohjain": o + Vector2(195, 135) * s,
		"kaasu": o + Vector2(250, 50) * s, "johdot": o + Vector2(160, 110) * s}
	for j in spots:
		var col := Color(0.55, 0.55, 0.55)
		var pulse := 0.0
		if results.has(j):
			col = Color(0.3, 0.9, 0.4)
		elif j == joint():
			col = Color(1.0, 0.8, 0.2)
			pulse = 0.5 + 0.5 * sin(_t * 6.0)
		elif not (j in todo):
			col = Color(0.3, 0.75, 0.45)
		if pulse > 0.0:
			_root.draw_arc(spots[j], 16.0 + pulse * 8.0, 0, TAU, 24, Color(col.r, col.g, col.b, 1.0 - pulse * 0.6), 3.0)
		MG.ball(_root, spots[j], 11.0, col, 0.5)
