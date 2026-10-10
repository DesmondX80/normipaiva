extends CanvasLayer
## Aikuisen keinuhyppykisa leikkipuistossa (#146): keinu vauhtiin oikeaan tahtiin ja hyppy hiekalle. W eteenpäin
## heilahtaessa ja S taaksepäin heilahtaessa lisää vauhtia, väärä tahti hidastaa. Liian kova vauhti löysää ketjut.
## Välilyönti hyppää: eteenpäin heilahduksen nousussa pitkä lento, taaksepäin heilahtaessa selälleen hiekkaan.
## Pituus mitataan keinutelineen alta. F / Esc luovuttaa. finished(metrit, kaatui).

signal finished(dist: float, crashed: bool)

const MG := preload("res://scripts/mg_draw.gd")
const L := 1.9  # ketjun pituus (m)
const PIVOT_H := 2.4
const G := 9.81
const PPM := 110.0  # pikseliä metrille
const PUMP := 0.32
const TIME := 30.0
const MUM_LINES := ["Äiti penkillä: \"Joko se setä lopettaa?\"", "Äiti penkillä: \"Eetu, tuu pois sieltä keinun läheltä.\"",
	"Pikkupoika: \"Äiti, miks tuo setä keinuu?\"", "Äiti penkillä kaivaa puhelimen esiin..."]

var record := 3.4
var record_holder := "Honganpalon Jere"
var best := 0.0
var drunk := 0.0

var _root: Control
var _info: Label
var _tip: Label
var _keys: Control
var _phase := "swing"  # swing / fly / landed / done
var _t := -1.5
var _th := 0.15  # kulma (rad), + = eteenpäin
var _w := 0.0  # kulmanopeus
var _last := ""
var _pos := Vector2.ZERO  # lento (m): x eteenpäin telineen alta, y maasta
var _vel := Vector2.ZERO
var _crash := false
var _dist := 0.0
var _shake := 0.0
var _sparks: Array = []
var _trail: Array = []
var _tip_t := 5.0
var _slack := 0.0


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	add_child(_root)
	_info = _label(26, 18.0, false)
	_tip = _label(24, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_tip.text = "Keinuhyppy! Ennätys %s %s m. Vauhtia oikeaan tahtiin." % [record_holder, _m(record)]


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


static func _m(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")


func _seat() -> Vector2:
	return Vector2(sin(_th) * L, PIVOT_H - cos(_th) * L)


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	_slack = maxf(0.0, _slack - delta)
	MG.sparks_step(_sparks, delta)
	_root.queue_redraw()
	if _phase == "done":
		return
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish("Luovutit. Pikkupoika pääsee vihdoin keinuun.")
		return
	match _phase:
		"swing":
			_swing(delta)
		"fly":
			_fly(delta)
		"landed":
			if _t > 2.0:
				var txt := ""
				if _crash:
					txt = "Selälleen hiekkaan! %s m. Äidit pudistelee päätään." % _m(_dist)
				elif _dist > record:
					txt = "%s METRIÄ! UUSI ENNÄTYS! %s jää historiaan." % [_m(_dist), record_holder]
				else:
					txt = "%s metriä. Ennätys %s %s m pitää." % [_m(_dist), record_holder, _m(record)]
				_finish(txt)
	_info.text = "Keinuhyppy · ennätys %s %s m%s" % [record_holder, _m(record), (" · oma %s m" % _m(best)) if best > 0.0 else ""]
	_keys.set_text("%s eteen heilahtaessa · %s taakse heilahtaessa · %s hyppää · %s luovuta" % [Settings.cap("forward"),
		Settings.cap("back"), Settings.cap("jump"), Settings.cap("mount")])


func _swing(delta: float) -> void:
	if _t < 0.0:
		return
	# Heiluri: painovoima, pieni vaimennus ja ketjujen löystyminen liian korkealla.
	_w += (-G / L * sin(_th) - 0.12 * _w) * delta
	_th += _w * delta
	if absf(_th) > 1.45:
		_th = signf(_th) * 1.45
		_w *= -0.3
		_slack = 0.6
		_shake = 0.6
		Sfx.play("rattle_hard", -6.0, 1.3)
		_tip.text = "KLONK! Ketjut löystyi. Äidit kirkaisee."
	for k in [["forward", 1.0], ["back", -1.0]]:
		if Input.is_action_just_pressed(k[0]):
			var right: bool = signf(_w) == k[1] and absf(_th) < 0.9
			if right and k[0] != _last:
				_w += k[1] * PUMP * (1.0 - drunk * 0.4)
				Sfx.play("pedal_creak", -12.0, 1.2)
			else:
				_w *= 0.85
				_tip.text = "Väärä tahti! Keinu hidastuu."
			_last = k[0]
	if Input.is_action_just_pressed("jump"):
		var s := _seat()
		_pos = s + Vector2(0, 0.45)
		var v := _w * L
		_vel = Vector2(cos(_th), sin(_th)) * v
		_crash = _w < 0.0 or absf(v) < 0.6
		_phase = "fly"
		_t = 0.0
		Sfx.play("whoosh", -4.0, 1.0)
		return
	if _t > TIME:
		_tip.text = "Äiti: \"Nyt riittää!\" Hyppää tai luovuta."
	_tip_t -= delta
	if _tip_t <= 0.0:
		_tip_t = 6.0
		_tip.text = MUM_LINES.pick_random()


func _fly(delta: float) -> void:
	_vel.y -= G * delta
	_pos += _vel * delta
	_trail.append(_pos)
	if _pos.y <= 0.0:
		_pos.y = 0.0
		_dist = maxf(0.0, _pos.x)
		_phase = "landed"
		_t = 0.0
		_shake = 1.0 if _crash else 0.6
		MG.sparks_burst(_sparks, _to_screen(_pos), Color(0.9, 0.8, 0.55), 30)
		Sfx.play("body_fall" if _crash else "step_grass", -2.0, 0.8)


func _finish(text: String) -> void:
	_phase = "done"
	_tip.text = text
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		finished.emit(_dist, _crash)
		queue_free())


# --- Piirto -------------------------------------------------------------------

func _origin() -> Vector2:
	return Vector2(_root.size.x * 0.28, _root.size.y * 0.8)  # keinutelineen jalan kohta maassa


func _to_screen(m: Vector2) -> Vector2:
	return _origin() + Vector2(m.x, -m.y) * PPM


func _draw_root() -> void:
	var sz := _root.size
	var font := ThemeDB.fallback_font
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 8.0
	_root.draw_set_transform(sh, 0.0, Vector2.ONE)
	MG.grad_rect(_root, Rect2(Vector2.ZERO, sz), Color(0.5, 0.72, 0.95), Color(0.9, 0.93, 0.95))
	for k in 14:  # metsänreuna
		var x := k * sz.x / 13.0
		var th := 120.0 + float((k * 41) % 70)
		_root.draw_colored_polygon(PackedVector2Array([Vector2(x - 50, sz.y * 0.62), Vector2(x, sz.y * 0.62 - th), Vector2(x + 50, sz.y * 0.62)]),
			Color(0.15, 0.36, 0.18).darkened((k % 3) * 0.08))
	_root.draw_rect(Rect2(Vector2(0, sz.y * 0.62), Vector2(sz.x, sz.y * 0.38)), Color(0.34, 0.6, 0.26))
	var o := _origin()
	# Hiekka ja pituusmerkit.
	MG.box(_root, Rect2(Vector2(o.x - 140, o.y - 6), Vector2(sz.x - o.x + 160, 40)), Color(0.88, 0.8, 0.58), 14)
	for m in range(1, 8):
		var mx := o.x + m * PPM
		_root.draw_line(Vector2(mx, o.y), Vector2(mx, o.y + 18), Color(0.55, 0.45, 0.3), 2.0)
		_root.draw_string(font, Vector2(mx - 10, o.y + 34), "%d m" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.3, 0.2))
	var rx := o.x + record * PPM  # ennätyslippu
	_root.draw_line(Vector2(rx, o.y), Vector2(rx, o.y - 70), Color(0.3, 0.3, 0.3), 3.0)
	_root.draw_colored_polygon(PackedVector2Array([Vector2(rx, o.y - 70), Vector2(rx + 40, o.y - 60), Vector2(rx, o.y - 50)]), Color(0.9, 0.15, 0.15))
	_root.draw_string(font, Vector2(rx - 30, o.y - 76), record_holder.get_slice(" ", record_holder.get_slice_count(" ") - 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.1, 0.1))
	if best > 0.0:
		var bx := o.x + best * PPM
		_root.draw_line(Vector2(bx, o.y), Vector2(bx, o.y - 50), Color(0.3, 0.3, 0.3), 3.0)
		_root.draw_colored_polygon(PackedVector2Array([Vector2(bx, o.y - 50), Vector2(bx + 30, o.y - 42), Vector2(bx, o.y - 34)]), Color(0.2, 0.5, 0.9))
	# Penkki ja äidit taustalla.
	var bp := Vector2(sz.x * 0.82, sz.y * 0.6)
	MG.wood(_root, Rect2(bp + Vector2(-90, 30), Vector2(180, 16)), Color(0.55, 0.4, 0.25), 60.0, 7)
	MG.person(_root, bp + Vector2(-40, -30), 0.55, {"skin": Color(0.95, 0.8, 0.7), "hair": "long", "hair_col": Color(0.45, 0.3, 0.2),
		"shirt": Color(0.6, 0.75, 0.9)}, Vector2(-0.8, 0), _tip_t > 4.5)
	MG.person(_root, bp + Vector2(40, -30), 0.55, {"skin": Color(0.95, 0.8, 0.7), "hair": "long", "hair_col": Color(0.85, 0.7, 0.4),
		"shirt": Color(0.9, 0.6, 0.5)}, Vector2(-0.8, 0))
	# Keinuteline: A-kehikko ja orsi.
	var pv := _to_screen(Vector2(0, PIVOT_H))
	var frame_col := Color(0.15, 0.45, 0.85)
	for e in [-1.0, 1.0]:
		_root.draw_line(pv, o + Vector2(e * 90, 0), frame_col, 10.0)
	_root.draw_circle(pv, 9.0, frame_col.darkened(0.3))
	# Ketjut ja istuin tai lentävä keinuja.
	var seat := _to_screen(_seat())
	var chain_col := Color(0.6, 0.6, 0.62)
	if _phase == "swing":
		var sag := Vector2(0, 14) * _slack
		for k in 10:
			var a := pv.lerp(seat, k / 10.0) + sag * sin(k / 10.0 * PI)
			var b := pv.lerp(seat, (k + 1) / 10.0) + sag * sin((k + 1) / 10.0 * PI)
			_root.draw_line(a, b, chain_col, 3.0)
		_root.draw_rect(Rect2(seat + Vector2(-26, -4), Vector2(52, 8)), Color(0.1, 0.1, 0.1))
		var leg := 1.0 if _w > 0.0 else -1.0
		_draw_rider(seat + Vector2(0, -50), _th, leg)
	else:
		for k in 10:
			_root.draw_line(pv.lerp(seat, k / 10.0), pv.lerp(seat, (k + 1) / 10.0), chain_col, 3.0)
		_root.draw_rect(Rect2(seat + Vector2(-26, -4), Vector2(52, 8)), Color(0.1, 0.1, 0.1))
		for i in range(1, _trail.size(), 3):
			_root.draw_circle(_to_screen(_trail[i]), 3.0, Color(1, 1, 1, 0.5))
		var spin := 0.0 if not _crash else _t * -6.0
		if _phase == "landed":
			spin = PI / 2.0 if _crash else 0.0
		_draw_rider(_to_screen(_pos) + Vector2(0, -50), spin, 1.0)
		if _phase == "landed":
			var lx := _to_screen(Vector2(_dist, 0))
			MG.bubble(_root, Rect2(lx + Vector2(-60, -170), Vector2(130, 46)), lx + Vector2(0, -120), "%s m" % _m(_dist), 26)
	MG.sparks_draw(_root, _sparks)
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Vauhtimittari: kulma.
	var g := Rect2(Vector2(40, 80), Vector2(240, 120))
	MG.box(_root, g, Color(0.08, 0.08, 0.1, 0.85), 10)
	var gc := g.position + Vector2(g.size.x / 2.0, g.size.y - 14)
	_root.draw_arc(gc, 90.0, PI, TAU, 30, Color(0.4, 0.4, 0.45), 8.0)
	_root.draw_arc(gc, 90.0, PI + PI * 0.06, PI + PI * 0.94, 30, Color(0.95, 0.3, 0.2, 0.0), 1.0)
	var amp := clampf(absf(_th) / 1.45, 0.0, 1.0)
	_root.draw_arc(gc, 90.0, PI, PI + PI * amp, 30, Color(0.3, 0.9, 0.3).lerp(Color(0.95, 0.3, 0.2), maxf(0.0, amp - 0.75) * 4.0), 8.0)
	_root.draw_string(font, gc + Vector2(-60, -20), "VAUHTI", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, Color.WHITE)


## Keinuja: aikuinen tuulipuvussa, jalat heilahtavat vauhdin suuntaan.
func _draw_rider(c: Vector2, tilt: float, leg: float) -> void:
	_root.draw_set_transform(c, tilt * 0.6, Vector2.ONE)
	_root.draw_line(Vector2(-6, 40), Vector2(-6 + leg * 34, 70), Color(0.42, 0.2, 0.62), 12.0)
	_root.draw_line(Vector2(6, 40), Vector2(6 + leg * 34, 72), Color(0.42, 0.2, 0.62), 12.0)
	MG.person(_root, Vector2(0, -10), 0.6, {"skin": Color(0.95, 0.76, 0.66), "hair": "short", "hair_col": Color(0.2, 0.15, 0.1),
		"shirt": Color(0.42, 0.2, 0.62), "cap": true, "stripes": true}, Vector2(leg * 0.6, 0), _phase == "fly", 1.0)
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
