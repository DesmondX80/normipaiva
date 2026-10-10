extends CanvasLayer
## Reipparin lihapiirakkahaaste (#115): montako lihapiirakkaa kaikilla mausteilla ehdit syödä TIME sekunnissa?
## Välilyönti haukkaa, A ja D vuorotellen pureskelevat (CHEWS kertaa haukun jälkeen), sitten voi haukata taas.
## Jokainen haukku täyttää vatsaa; vatsa sulattaa hitaasti, ja limu (W) laskee vatsaa mutta vie hetken. Täysi vatsa:
## "Ei mahdu!" ja haaste päättyy. Ennätystaulu kioskin seinällä (record). F / Esc luovuttaa. finished(pies).

signal finished(pies: int)

const MG := preload("res://scripts/mg_draw.gd")
const TIME := 40.0
const BITES := 5  # haukkua piirakkaa kohti
const CHEWS := 2  # pureskeluja haukun jälkeen (A/D vuorotellen)
const BITE_FILL := 0.028
const DIGEST := 0.009  # vatsa sulattaa sekunnissa
const SODA := 0.15
const SODA_T := 1.1
const LINES := ["Raija: \"Kaikilla mausteilla, niinku Juntti tilas!\"", "Raija: \"Älä tukehdu, mää en osaa ensiapua.\"",
	"Raija: \"Juntti söi seittemän ja oksensi parkkipaikalle.\"", "Raija: \"Pureskele, poika, pureskele!\""]

var record := 7
var record_holder := "Juntti"
var drunk := 0.0

var _root: Control
var _info: Label
var _keys: Control
var _tip: Label
var _done := false
var _t := -2.0  # alkulaskenta
var _pies := 0
var _bite := 0  # haukkuja nykyisestä piirakasta
var _chew := 0  # pureskelut jäljellä
var _last := ""
var _belly := 0.0
var _soda_t := 0.0
var _crumbs: Array = []
var _jaw := 0.0
var _tip_t := 3.0


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	add_child(_root)
	_info = _label(24, 20.0, false)
	_tip = _label(22, -86.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_tip.text = "Raija: \"Ennätys on %s, %d piirakkaa. Kello käy kun sanon nyt...\"" % [record_holder, record]


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


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_jaw = maxf(0.0, _jaw - delta * 4.0)
	_soda_t = maxf(0.0, _soda_t - delta)
	MG.sparks_step(_crumbs, delta)
	_root.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish("Luovutit. Raija: \"Heikko sukupolvi.\"")
		return
	if _t < 0.0:
		_info.text = "Lihapiirakkahaaste alkaa: %d" % ceili(-_t)
		return
	_belly = maxf(0.0, _belly - DIGEST * delta)
	if _soda_t <= 0.0:
		if Input.is_action_just_pressed("jump") and _chew == 0:
			_bite += 1
			_chew = CHEWS
			_belly += BITE_FILL * (1.0 + drunk * 0.3)
			_jaw = 1.0
			MG.sparks_burst(_crumbs, _mouth(), Color(0.85, 0.6, 0.3), 8)
			Sfx.play("pickup", -14.0, 0.6)
			if _bite >= BITES:
				_bite = 0
				_pies += 1
				Sfx.play("win_small", -10.0, 1.3)
				if _pies == record + 1:
					_tip.text = "UUSI ENNÄTYS! Raija hakee tussin."
		for k in [["left", "A"], ["right", "D"]]:
			if Input.is_action_just_pressed(k[0]) and _chew > 0 and k[1] != _last:
				_last = k[1]
				_chew -= 1
				_jaw = 0.6
		if Input.is_action_just_pressed("forward"):
			_soda_t = SODA_T
			_belly = maxf(0.0, _belly - SODA)
			Sfx.play("glass", -10.0, 1.5)
	if _belly >= 1.0:
		_finish("EI MAHDU! Vatsa täynnä. %d piirakkaa." % _pies)
		return
	if _t >= TIME:
		_finish("Aika loppu! %d piirakkaa." % _pies)
		return
	_tip_t -= delta
	if _tip_t <= 0.0 and _pies <= record:
		_tip_t = 6.0
		_tip.text = LINES.pick_random()
	_info.text = "Piirakoita %d · aikaa %d s · ennätys %s %d" % [_pies, ceili(TIME - _t), record_holder, record]
	_keys.set_text("%s haukkaa · %s / %s pureskele · %s limua · %s luovuta" % [Settings.cap("jump"), Settings.cap("left"),
		Settings.cap("right"), Settings.cap("forward"), Settings.cap("mount")])


func _finish(text: String) -> void:
	_done = true
	_tip.text = text
	get_tree().create_timer(1.8).timeout.connect(func() -> void:
		finished.emit(_pies)
		queue_free())


# --- Piirto -------------------------------------------------------------------

func _mouth() -> Vector2:
	return Vector2(_root.size.x * 0.32, _root.size.y * 0.5)


func _draw_root() -> void:
	var sz := _root.size
	var font := ThemeDB.fallback_font
	# Iltataivas ja kioskin seinä luukkuineen.
	MG.grad_rect(_root, Rect2(Vector2.ZERO, sz), Color(0.95, 0.6, 0.35), Color(0.45, 0.3, 0.45))
	var wall := Rect2(Vector2(sz.x * 0.45, sz.y * 0.13), Vector2(sz.x * 0.5, sz.y * 0.57))
	MG.solid(_root, wall, Color(0.95, 0.94, 0.9))
	_root.draw_rect(Rect2(wall.position + Vector2(0, wall.size.y - 40), Vector2(wall.size.x, 22)), Color(0.95, 0.45, 0.1))
	MG.sign(_root, Rect2(wall.position + Vector2(30, -18), Vector2(wall.size.x - 60, 46)), "SALOISTEN REIPPARI",
		Color(0.8, 0.1, 0.08), Color(1.0, 0.88, 0.2), 26)
	var win := Rect2(wall.position + Vector2(40, 60), Vector2(wall.size.x * 0.5, wall.size.y * 0.55))
	MG.box(_root, win, Color(0.15, 0.12, 0.1), 4)
	for k in 8:  # markiisi raidoin
		_root.draw_rect(Rect2(win.position + Vector2(-20 + k * (win.size.x + 40) / 8.0, -26), Vector2((win.size.x + 40) / 8.0, 26)),
			Color(0.95, 0.45, 0.1) if k % 2 == 0 else Color.WHITE)
	MG.person(_root, win.position + Vector2(win.size.x * 0.5, win.size.y * 0.45), 0.9, {"skin": Color(0.95, 0.78, 0.68),
		"hair": "long", "hair_col": Color(0.7, 0.3, 0.15), "shirt": Color(0.95, 0.45, 0.1)}, Vector2(-0.8, 0.3), _tip_t > 4.5)
	# Ennätystaulu ja hintataulu.
	var rec := Rect2(Vector2(win.end.x + 24, win.position.y), Vector2(wall.end.x - win.end.x - 50, 110))
	var beat := _pies > record
	MG.sign(_root, rec, "ENNÄTYS\n%s %d" % ["SINÄ" if beat else record_holder, _pies if beat else record], Color(0.1, 0.1, 0.12), Color(1, 1, 0.85), 22,
		Color(0.85, 0.85, 0.82))
	MG.sign(_root, Rect2(rec.position + Vector2(0, 130), Vector2(rec.size.x, 120)), "LIHAPIIRAKKA\nKAIKILLA\n4,90",
		Color(0.97, 0.95, 0.85), Color(0.6, 0.1, 0.05), 20, Color(0.6, 0.1, 0.05))
	# Tiski ja lautanen piirakkoineen.
	MG.wood(_root, Rect2(Vector2(0, sz.y * 0.7), Vector2(sz.x, sz.y * 0.3)), Color(0.55, 0.36, 0.2), 50.0, 31)
	var plate := Vector2(sz.x * 0.58, sz.y * 0.8)
	_root.draw_circle(plate + Vector2(4, 8), 120.0, Color(0, 0, 0, 0.25))
	_root.draw_circle(plate, 118.0, Color(0.97, 0.97, 0.95))
	_root.draw_arc(plate, 100.0, 0, TAU, 40, Color(0.85, 0.85, 0.85), 3.0)
	if not _done or _bite > 0:
		_draw_pie(plate, 1.0 - float(_bite) / BITES)
	for k in mini(_pies, 12):  # syödyt: paperit pinossa
		_root.draw_rect(Rect2(Vector2(sz.x * 0.82 + (k % 3) * 8, sz.y * 0.82 - k * 6), Vector2(70, 8)), Color(0.95, 0.93, 0.85))
	# Pelaaja: pää isona, posket pullollaan pureskellessa.
	var face := Vector2(sz.x * 0.25, sz.y * 0.42)
	MG.person(_root, face, 2.2, {"skin": Color(0.95, 0.76, 0.66), "hair": "short", "hair_col": Color(0.2, 0.15, 0.1),
		"shirt": Color(0.42, 0.2, 0.62), "cap": true, "stripes": true}, Vector2(0.6, 0.3), _jaw > 0.3)
	if _chew > 0:
		for sx in [-1.0, 1.0]:
			_root.draw_circle(face + Vector2(sx * 52.0, 26.0 + sin(_t * 30.0) * 3.0), 20.0, Color(0.95, 0.72, 0.6))
	if _belly > 0.75:
		_root.draw_string(font, face + Vector2(-60, -110), "*hik*" if fmod(_t, 1.0) < 0.5 else "", HORIZONTAL_ALIGNMENT_CENTER, 120, 26, Color.WHITE)
	# Vatsamittari ja limupullo.
	var bar := Rect2(Vector2(40, sz.y * 0.12), Vector2(36, sz.y * 0.5))
	MG.box(_root, bar.grow(4), Color(0.08, 0.08, 0.08), 8)
	var fill := clampf(_belly, 0.0, 1.0)
	MG.grad_rect(_root, Rect2(Vector2(bar.position.x, bar.end.y - bar.size.y * fill), Vector2(bar.size.x, bar.size.y * fill)),
		Color(0.95, 0.3, 0.2).lerp(Color(0.95, 0.85, 0.2), 1.0 - fill), Color(0.6, 0.2, 0.1))
	_root.draw_string(font, bar.position + Vector2(-20, bar.size.y + 32), "VATSA", HORIZONTAL_ALIGNMENT_CENTER, 76, 18, Color.WHITE)
	var bottle := Vector2(110, sz.y * 0.55)
	MG.solid(_root, Rect2(bottle + Vector2(-16, -10), Vector2(32, 90)), Color(0.2, 0.6, 0.25).lerp(Color(0.6, 0.85, 0.6), _soda_t))
	MG.solid(_root, Rect2(bottle + Vector2(-7, -40), Vector2(14, 30)), Color(0.2, 0.6, 0.25))
	_root.draw_string(font, bottle + Vector2(-40, 104), "LIMU (%s)" % Settings.action_key("forward"), HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Color.WHITE)
	# Pureskeluohje: A ja D vuorotellen.
	if _chew > 0:
		for i in 2:
			var key: String = ["A", "D"][i]
			var kr := Rect2(face + Vector2(-90 + i * 110, 150), Vector2(70, 56))
			var lit := key != _last
			MG.box(_root, kr, Color(0.98, 0.95, 0.85) if lit else Color(0.5, 0.48, 0.45), 8, 4, Color(0.2, 0.15, 0.1), 2)
			_root.draw_string(font, kr.position + Vector2(0, 40), key, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, 30, Color(0.15, 0.1, 0.05))
	MG.sparks_draw(_root, _crumbs)
	if _t < 0.0:
		_root.draw_string(font, Vector2(0, sz.y * 0.4), str(ceili(-_t)), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 90, Color(1.0, 0.95, 0.4))


## Lihapiirakka kaikilla: kuori, kaksi nakkia, ketsuppi, sinappi, kurkkusalaatti ja sipuli. left = jäljellä 0..1.
func _draw_pie(c: Vector2, left: float) -> void:
	var w := 170.0 * maxf(left, 0.15)
	var r := Rect2(c + Vector2(-85, -38), Vector2(w, 76))
	MG.box(_root, r, Color(0.85, 0.55, 0.25), 30, 0, Color(0.55, 0.3, 0.1), 3)
	_root.draw_line(r.position + Vector2(10, 38), r.position + Vector2(w - 10, 38), Color(0.45, 0.2, 0.12), 14.0)  # nakit
	_root.draw_line(r.position + Vector2(10, 52), r.position + Vector2(w - 10, 52), Color(0.5, 0.25, 0.14), 12.0)
	for k in int(w / 14.0):
		var x := r.position.x + 8 + k * 14
		_root.draw_line(Vector2(x, r.position.y + 20), Vector2(x + 8, r.position.y + 30), Color(0.85, 0.1, 0.08), 4.0)  # ketsuppi
		_root.draw_line(Vector2(x + 4, r.position.y + 30), Vector2(x + 12, r.position.y + 22), Color(0.95, 0.8, 0.1), 3.0)  # sinappi
		_root.draw_circle(Vector2(x + 6, r.position.y + 14), 3.0, Color(0.35, 0.65, 0.25))  # kurkkusalaatti
		_root.draw_circle(Vector2(x + 2, r.position.y + 62), 2.5, Color(0.98, 0.95, 0.9))  # sipuli
