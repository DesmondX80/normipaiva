extends CanvasLayer
## Tiskaus (Santun homma) mökin keittiössä: astia kerrallaan tiskialtaassa. Hankaa A/D vuorotellen (tai hiirtä
## edestakaisin), kunnes astia on puhdas, ja nosta se kuivauskaappiin (välilyönti tai E). Humalassa märkä astia
## lipsahtaa helposti lattialle. Santtu kommentoi vieressä (mokki_interior.gd say). F / Esc lopettaa kesken.

const MG := preload("res://scripts/mg_draw.gd")

signal finished(washed: int, broken: int)
signal comment(text: String)

const DISHES := [["lautanen", Color(0.95, 0.95, 0.92)], ["muki", Color(0.85, 0.3, 0.2)], ["lautanen", Color(0.95, 0.95, 0.92)],
	["kattila", Color(0.6, 0.62, 0.65)], ["lasi", Color(0.75, 0.88, 0.95)], ["mummon kukkalautanen", Color(0.92, 0.88, 0.95)]]
const SCRUB := 0.09  # yksi veto puhdistaa
const LINES := {
	"start": ["Tiskiaine on altaan reunalla. Kuumaa vettä riittää.", "Mummon astiastoa, varovasti!"],
	"clean": ["Kiiltää!", "Hyvä. Seuraava.", "Tuo on puhdas."],
	"break": ["Se oli mummon astiastosta!", "No voi... lattia on kova.", "Sirpaleet roskiin, ei mitään."],
	"lazy": ["Tuohon jäi vielä kahvinporoja.", "Pohjat kanssa!"],
	"done": ["Tiskit tehty! Kuivauskaappi täynnä."],
}

var dishes_left := DISHES.size()
var drunk := 0.0
var washed := 0
var broken := 0

var _root: Control
var _dirt := 1.0
var _last_dir := 0
var _wobble := 0.0
var _drop_t := -1.0
var _info: Label
var _keys: Control
var _done := false
var _spots: Array = []
var _splash: Array = []  # vesiroiskeet hangatessa (MG.sparks_*)
var _foam: Array = []  # vaahtokuplat astialla: [paikka suhteessa astiaan, säde, ikä]
var _shake := 0.0
var _rack: Array = []  # kuivauskaappiin nostetut astiat (DISHES-rivit)
var _t := 0.0

const WATER := Color(0.55, 0.75, 0.88)
const STEEL := Color(0.74, 0.76, 0.8)
const CHROME := Color(0.86, 0.88, 0.92)


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_root)
	add_child(_root)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 24)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 8)
	_info.anchor_right = 1.0
	_info.offset_top = 40
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_info)
	_keys = preload("res://scripts/hint_bar.gd").new()  # näppäinohjeet hattuina, näppäimet asetuksista
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_new_dish()
	comment.emit(LINES.start.pick_random())


func _new_dish() -> void:
	_dirt = 1.0
	_spots.clear()
	_foam.clear()
	for k in 9:
		_spots.append([Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)), randf_range(0.12, 0.26)])


func _dish() -> Array:
	return DISHES[DISHES.size() - dishes_left]


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseMotion and absf(event.relative.x) > 12.0:
		_scrub(1 if event.relative.x > 0.0 else -1)


func _process(delta: float) -> void:
	if _done:
		return
	_root.queue_redraw()
	_t += delta
	_wobble = maxf(0.0, _wobble - delta * 2.0)
	_shake = maxf(0.0, _shake - delta * 3.0)
	MG.sparks_step(_splash, delta)
	for f in _foam:
		f[2] += delta
	_foam = _foam.filter(func(f): return f[2] < 2.5)
	if _drop_t >= 0.0:
		_drop_t += delta
		if _drop_t > 0.7:
			_drop_t = -1.0
			_next()
		return
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish()
		return
	if Input.is_action_just_pressed("left"):
		_scrub(-1)
	if Input.is_action_just_pressed("right"):
		_scrub(1)
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact"):
		_lift()
	_info.text = "%s · jäljellä %d" % [_dish()[0].capitalize(), dishes_left]
	_keys.set_text("%s hankaa (tai hiiri)   [%s / %s] kuivauskaappiin   %s lopeta" % [Settings.pair("left", "right"),
		Settings.action_key("jump"), Settings.action_key("interact"), Settings.cap("mount")])


func _scrub(dir: int) -> void:
	if dir == _last_dir or _drop_t >= 0.0:
		return
	_last_dir = dir
	_dirt = maxf(0.0, _dirt - SCRUB * randf_range(0.7, 1.2))
	_wobble = 1.0
	# Vaahtoa harjan kohdalle ja roiskeita altaaseen.
	for k in 3:
		_foam.append([Vector2(dir * randf_range(0.0, 0.35), randf_range(-0.15, 0.3)), randf_range(8.0, 18.0), 0.0])
	MG.sparks_burst(_splash, _center() + Vector2(dir * 60.0, 20.0), Color(0.8, 0.92, 1.0), 6)
	Sfx.play("water", -14.0, randf_range(1.3, 1.7))
	if _dirt <= 0.0 and randf() < 0.5:
		comment.emit(LINES.clean.pick_random())


func _lift() -> void:
	if _dirt > 0.15:
		comment.emit(LINES.lazy.pick_random())
		Sfx.play("alert", -12.0, 1.6)
		return
	# Märkä astia lipsahtaa humalassa (ja mummon kukkalautanen aina vähän helpommin).
	var slip := drunk * 0.45 + (0.08 if _dish()[0].begins_with("mummon") else 0.02)
	if randf() < slip:
		broken += 1
		_drop_t = 0.0
		_shake = 1.0
		Sfx.play("glass", 0.0, 0.7)
		comment.emit(LINES["break"].pick_random())
		return
	washed += 1
	_rack.append(_dish())
	Sfx.play("pickup", -8.0, 1.2)
	_next()


func _next() -> void:
	dishes_left -= 1
	if dishes_left <= 0:
		comment.emit(LINES.done[0])
		_finish()
		return
	_new_dish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit(washed, broken)
	queue_free()


## Astian keskipiste altaassa.
func _center() -> Vector2:
	return _root.size / 2.0 + Vector2(-60, 40)


func _draw_root() -> void:
	var sz := _root.size
	var c := _center()
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.55))
	_root.draw_set_transform(Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _shake)
	_draw_kitchen(c)
	_draw_sink(c)
	_draw_rack(c)
	if _drop_t >= 0.0:
		_draw_shards(c)
	else:
		var off := Vector2(sin(_t * 25.0) * 10.0 * _wobble, 0)
		_draw_dish(c + off)
		_draw_brush(c + off)
	MG.sparks_draw(_root, _splash)
	_draw_meter(c)
	_root.draw_set_transform(Vector2.ZERO)


## Keittiö: laatoitettu välitila, ikkuna ja puinen työtaso laminaattireunalla.
func _draw_kitchen(c: Vector2) -> void:
	var area := Rect2(c - Vector2(410, 280), Vector2(960, 560))
	MG.box(_root, area.grow(8), Color(0.1, 0.07, 0.05), 12, 14)
	var wall := Rect2(area.position, Vector2(area.size.x, 120))
	_root.draw_rect(wall, Color(0.93, 0.92, 0.86))
	for x in range(0, int(wall.size.x), 40):  # laatat ja saumat
		for y in range(0, int(wall.size.y), 40):
			var tr := Rect2(wall.position + Vector2(x + 2, y + 2), Vector2(36, 36))
			MG.grad_rect(_root, tr, Color(0.96, 0.95, 0.9), Color(0.86, 0.85, 0.8))
			if (x / 40 + y / 40) % 7 == 3:  # kuviolaatta
				_root.draw_circle(tr.get_center(), 9.0, Color(0.35, 0.55, 0.7, 0.6))
	var win := Rect2(area.position + Vector2(60, 10), Vector2(170, 100))  # ikkuna järvelle
	MG.box(_root, win.grow(6), Color(0.95, 0.95, 0.95), 4, 4, MG.OUTLINE, 2)
	MG.grad_rect(_root, win, Color(0.55, 0.78, 0.95), Color(0.75, 0.88, 0.95))
	_root.draw_rect(Rect2(win.position + Vector2(0, 62), Vector2(win.size.x, 38)), Color(0.25, 0.45, 0.6))
	for k in 6:  # rannan kuuset
		var tp := win.position + Vector2(10 + k * 30, 62)
		_root.draw_colored_polygon(PackedVector2Array([tp + Vector2(-12, 4), tp + Vector2(12, 4), tp + Vector2(0, -30 - (k % 3) * 8)]), Color(0.15, 0.35, 0.2))
	_root.draw_line(win.position + Vector2(win.size.x / 2.0, 0), win.position + Vector2(win.size.x / 2.0, win.size.y), Color(0.95, 0.95, 0.95), 5.0)
	MG.wood(_root, Rect2(area.position + Vector2(0, 120), Vector2(area.size.x, area.size.y - 120)), Color(0.66, 0.5, 0.32), 64.0, 5)
	_root.draw_rect(Rect2(area.position + Vector2(0, 116), Vector2(area.size.x, 8)), Color(0.4, 0.28, 0.16))


## Teräsallas: harjattu sisäpinta, pohjaventtiili, kromihana ja vesi vaahtoineen; tiskiainepullo ja sieni.
func _draw_sink(c: Vector2) -> void:
	var rim := Rect2(c - Vector2(330, 220), Vector2(660, 440))
	MG.box(_root, rim, STEEL.darkened(0.1), 26, 10, MG.OUTLINE, 2)
	MG.box(_root, Rect2(rim.position + Vector2(6, 4), Vector2(rim.size.x - 12, 18)), STEEL.lightened(0.25), 14)
	var basin := rim.grow(-26.0)
	MG.box(_root, basin, STEEL.darkened(0.42), 22, 0, MG.OUTLINE, 2)
	MG.box(_root, basin.grow(-6.0), STEEL.darkened(0.28), 18)
	for k in 30:
		var y := basin.position.y + 8 + k * 13
		_root.draw_line(Vector2(basin.position.x + 16, y), Vector2(basin.end.x - 16, y), Color(1, 1, 1, 0.05), 1.0)
	_root.draw_circle(c + Vector2(220, 130), 20.0, STEEL.darkened(0.5))  # pohjaventtiili
	_root.draw_circle(c + Vector2(220, 130), 14.0, STEEL)
	for k in 4:
		_root.draw_line(c + Vector2(220, 130) + Vector2(-9, 0).rotated(k * PI / 4.0), c + Vector2(220, 130) + Vector2(9, 0).rotated(k * PI / 4.0), STEEL.darkened(0.5), 2.0)
	# Vesi: läpikuultava pinta, aallot ja vaahtokuplat.
	MG.box(_root, basin.grow(-10.0), Color(WATER, 0.55), 18)
	for k in 5:
		var y := basin.position.y + 50 + k * 70 + sin(_t + k) * 4.0
		_root.draw_arc(Vector2(basin.position.x + 120 + (k % 2) * 200, y), 60.0, PI * 1.15, PI * 1.85, 12, Color(1, 1, 1, 0.18), 3.0)
	for k in 30:
		var a := k * 2.4 + _t * 0.15
		var p := c + Vector2(cos(a) * (120 + (k % 7) * 28), sin(a * 1.3) * (95 + (k % 5) * 22))
		var r := 10.0 + (k % 4) * 6.0
		if basin.grow(-r - 6).has_point(p):
			_bubble(p, r)
	# Hana takareunassa ylhäältä: jalka, nokka altaan päälle, suutin ja kahvat; tippa putoaa välillä.
	var tap := c + Vector2(0, -236)
	MG.box(_root, Rect2(tap + Vector2(-30, -16), Vector2(60, 30)), CHROME.darkened(0.15), 12, 4, MG.OUTLINE, 2)
	_root.draw_line(tap, tap + Vector2(0, 62), MG.OUTLINE, 20.0)
	_root.draw_line(tap, tap + Vector2(0, 62), CHROME.darkened(0.08), 16.0)
	_root.draw_line(tap + Vector2(-4, 0), tap + Vector2(-4, 60), Color(1, 1, 1, 0.8), 3.0)
	MG.ball(_root, tap + Vector2(0, 66), 11.0, CHROME, 0.5)
	_root.draw_circle(tap + Vector2(0, 68), 5.0, Color(0.25, 0.27, 0.3))
	var drip := fposmod(_t, 2.2) / 2.2
	if drip > 0.6:
		var dp := tap + Vector2(0, 74 + (drip - 0.6) * 220.0)
		_root.draw_circle(dp, 4.0, Color(WATER.lightened(0.3), 0.9))
	for side in [-1.0, 1.0]:
		var h := tap + Vector2(side * 52, -2)
		MG.ball(_root, h, 13.0, CHROME, 0.6)
		_root.draw_circle(h, 5.0, Color(0.85, 0.15, 0.15) if side > 0 else Color(0.2, 0.4, 0.9))
	# Tiskiainepullo etiketteineen ja sieni reunalla.
	var bottle := c + Vector2(290, -196)
	MG.box(_root, Rect2(bottle + Vector2(-22, -44), Vector2(44, 88)), Color(0.15, 0.62, 0.3), 14, 5, MG.OUTLINE, 2)
	_root.draw_rect(Rect2(bottle + Vector2(-14, -38), Vector2(6, 74)), Color(1, 1, 1, 0.35))
	MG.box(_root, Rect2(bottle + Vector2(-8, -62), Vector2(16, 20)), Color(0.95, 0.95, 0.95), 4, 0, MG.OUTLINE, 2)
	MG.box(_root, Rect2(bottle + Vector2(-18, -10), Vector2(36, 32)), Color(0.98, 0.97, 0.9), 4)
	_root.draw_circle(bottle + Vector2(0, 0), 7.0, Color(0.95, 0.75, 0.1))
	_root.draw_string(ThemeDB.fallback_font, bottle + Vector2(-18, 18), "ASTIA", HORIZONTAL_ALIGNMENT_CENTER, 36, 10, Color(0.1, 0.35, 0.15))
	var sp := Rect2(c + Vector2(-318, -214), Vector2(64, 34))
	MG.box(_root, sp, Color(0.98, 0.85, 0.25), 6, 3, MG.OUTLINE, 2)
	MG.box(_root, Rect2(sp.position, Vector2(sp.size.x, 12)), Color(0.2, 0.55, 0.3), 4)
	for k in 6:
		_root.draw_circle(sp.position + Vector2(8 + k * 10, 24 + (k % 2) * 3), 2.0, Color(0.85, 0.7, 0.15))


func _bubble(p: Vector2, r: float, alpha := 1.0) -> void:
	_root.draw_circle(p, r, Color(1, 1, 1, 0.3 * alpha))
	_root.draw_arc(p, r, 0, TAU, 16, Color(1, 1, 1, 0.55 * alpha), 1.5)
	_root.draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.75 * alpha))


## Astiankuivauskaappi oikealla: puukehys, avoin ovi, ritilät; tiskatut astiat pystyssä oikean muotoisina.
func _draw_rack(c: Vector2) -> void:
	var rack := Rect2(c + Vector2(350, -230), Vector2(170, 420))
	MG.box(_root, rack.grow(8), Color(0.88, 0.85, 0.78), 6, 10, MG.OUTLINE, 2)
	MG.box(_root, rack, Color(0.72, 0.7, 0.66), 4)
	var lower := rack.position.y + rack.size.y * 0.55
	for y in [rack.position.y + rack.size.y * 0.5, rack.end.y - 14]:  # ritilät
		_root.draw_line(Vector2(rack.position.x + 6, y), Vector2(rack.end.x - 6, y), STEEL.darkened(0.2), 4.0)
		_root.draw_line(Vector2(rack.position.x + 6, y - 2), Vector2(rack.end.x - 6, y - 2), STEEL.lightened(0.3), 1.5)
	for k in 9:
		var x := rack.position.x + 12 + k * 18.0
		_root.draw_line(Vector2(x, rack.position.y + 20), Vector2(x, rack.position.y + rack.size.y * 0.5), STEEL.darkened(0.1), 2.0)
	# Pesty: lautaset pystyyn yläritilään, muut alas.
	var top_i := 0
	var low_x := rack.position.x + 18
	for d: Array in _rack:
		var col: Color = d[1]
		match d[0]:
			"lautanen", "mummon kukkalautanen":
				var px := rack.position.x + 34 + top_i * 26
				top_i += 1
				var pr := Rect2(Vector2(px - 7, rack.position.y + 34), Vector2(14, rack.size.y * 0.5 - 38))
				MG.box(_root, pr, col.darkened(0.1), 7, 2, MG.OUTLINE, 2)
				_root.draw_line(pr.position + Vector2(4, 8), pr.position + Vector2(4, pr.size.y - 8), col.lightened(0.5), 2.0)
				if d[0].begins_with("mummon"):
					_root.draw_line(pr.position + Vector2(10, 8), pr.position + Vector2(10, pr.size.y - 8), Color(0.85, 0.7, 0.3), 2.0)
			"muki":
				var mp := Vector2(low_x + 16, lower + 40)
				MG.box(_root, Rect2(mp - Vector2(16, 20), Vector2(32, 40)), col, 6, 2, MG.OUTLINE, 2)
				_root.draw_arc(mp + Vector2(16, 0), 9.0, -PI / 2.0, PI / 2.0, 10, MG.OUTLINE, 6.0)
				_root.draw_arc(mp + Vector2(16, 0), 9.0, -PI / 2.0, PI / 2.0, 10, col, 3.5)
				low_x += 46
			"lasi":
				var gp := Vector2(low_x + 14, lower + 40)
				_root.draw_colored_polygon(PackedVector2Array([gp + Vector2(-14, 22), gp + Vector2(14, 22), gp + Vector2(10, -22), gp + Vector2(-10, -22)]),
					Color(col, 0.55))
				_root.draw_polyline(PackedVector2Array([gp + Vector2(-14, 22), gp + Vector2(14, 22), gp + Vector2(10, -22), gp + Vector2(-10, -22), gp + Vector2(-14, 22)]),
					MG.OUTLINE, 2.0)
				_root.draw_line(gp + Vector2(-6, -16), gp + Vector2(-8, 14), Color(1, 1, 1, 0.7), 2.0)
				low_x += 38
			"kattila":
				var kp := Vector2(low_x + 34, lower + 112)
				MG.box(_root, Rect2(kp - Vector2(34, 26), Vector2(68, 52)), col, 8, 3, MG.OUTLINE, 2)
				MG.box(_root, Rect2(kp - Vector2(34, 26), Vector2(68, 12)), col.lightened(0.25), 6)
				_root.draw_line(kp + Vector2(34, -16), kp + Vector2(58, -20), Color(0.14, 0.14, 0.15), 7.0)
	var title := "Kuivauskaappi %d" % washed
	_root.draw_string(ThemeDB.fallback_font, rack.position + Vector2(1, -16), title, HORIZONTAL_ALIGNMENT_CENTER, rack.size.x, 18, Color(0, 0, 0, 0.75))
	_root.draw_string(ThemeDB.fallback_font, rack.position + Vector2(0, -17), title, HORIZONTAL_ALIGNMENT_CENTER, rack.size.x, 18, Color(0.2, 0.15, 0.1))


## Astia altaassa: sävytys, ääriviiva, kiilto, lika ja vaahto.
func _draw_dish(dc: Vector2) -> void:
	var d: Array = _dish()
	var col: Color = d[1]
	var kind: String = d[0]
	var r := 150.0
	match kind:
		"muki":
			r = 95.0
			_root.draw_circle(dc + Vector2(8, 10), r + 4, Color(0, 0, 0, 0.25))
			MG.box(_root, Rect2(dc + Vector2(r - 14, -26), Vector2(74, 52)), col.darkened(0.15), 24, 0, MG.OUTLINE, 2)
			MG.box(_root, Rect2(dc + Vector2(r + 8, -11), Vector2(34, 22)), Color(WATER, 0.9), 10)
			_root.draw_circle(dc, r, col.darkened(0.2))
			_root.draw_circle(dc - Vector2(4, 4), r - 4, col)
			_root.draw_arc(dc, r, 0, TAU, 48, MG.OUTLINE, 2.5, true)
			_root.draw_circle(dc, r * 0.82, col.darkened(0.3))
			_root.draw_circle(dc, r * 0.7, Color(0.35, 0.22, 0.12).lerp(col.darkened(0.35), 1.0 - _dirt))  # kahvinpohja
			_ring(dc, Vector2(r, r) * 0.93, -2.6, -1.2, Color(1, 1, 1, 0.6), 4.0)
		"lasi":
			r = 90.0
			_root.draw_circle(dc + Vector2(8, 10), r + 4, Color(0, 0, 0, 0.15))
			_root.draw_circle(dc, r, Color(col, 0.55))
			_root.draw_circle(dc, r * 0.85, Color(col.lightened(0.2), 0.35))
			_root.draw_arc(dc, r, 0, TAU, 48, Color(0.3, 0.45, 0.55, 0.9), 2.5, true)
			_root.draw_arc(dc, r * 0.85, 0, TAU, 48, Color(1, 1, 1, 0.5), 1.5, true)
			_ring(dc, Vector2(r, r) * 0.95, -2.4, -1.2, Color(1, 1, 1, 0.85), 4.0)
			_ring(dc, Vector2(r, r) * 0.6, 0.6, 1.2, Color(1, 1, 1, 0.5), 3.0)
		"kattila":
			r = 140.0
			_root.draw_circle(dc + Vector2(10, 12), r + 6, Color(0, 0, 0, 0.25))
			MG.box(_root, Rect2(dc + Vector2(r - 8, -16), Vector2(150, 32)), Color(0.14, 0.14, 0.15), 14, 0, MG.OUTLINE, 2)
			_root.draw_circle(dc + Vector2(r + 124, 0), 7.0, Color(0.3, 0.3, 0.3))  # ripustusreikä
			_root.draw_circle(dc, r, col.lightened(0.15))
			_root.draw_arc(dc, r, 0, TAU, 64, MG.OUTLINE, 2.5, true)
			_root.draw_circle(dc, r * 0.9, col)
			_root.draw_circle(dc, r * 0.82, col.darkened(0.12))
			for k in 6:  # pohjan sorvausrenkaat
				_root.draw_arc(dc, r * (0.15 + k * 0.11), 0, TAU, 40, col.darkened(0.18), 1.0, true)
			_ring(dc, Vector2(r, r) * 0.86, -2.6, -1.0, Color(1, 1, 1, 0.55), 5.0)
		_:
			_root.draw_circle(dc + Vector2(8, 12), r + 4, Color(0, 0, 0, 0.25))
			_root.draw_circle(dc, r, col.darkened(0.12))
			_root.draw_circle(dc - Vector2(3, 3), r - 4, col)
			_root.draw_arc(dc, r, 0, TAU, 64, MG.OUTLINE, 2.5, true)
			_root.draw_circle(dc, r * 0.66, col.darkened(0.06))
			_ring(dc, Vector2(r, r) * 0.66, 0.0, TAU, col.darkened(0.16), 3.0)
			if kind == "mummon kukkalautanen":
				for k in 10:
					var a := k * TAU / 10.0
					var fp := dc + Vector2(cos(a), sin(a)) * r * 0.83
					_root.draw_line(fp, fp + Vector2(cos(a + 1.2), sin(a + 1.2)) * 14.0, Color(0.3, 0.55, 0.3), 2.5)  # lehti
					for pk in 5:
						var pa := pk * TAU / 5.0 + a
						_root.draw_circle(fp + Vector2(cos(pa), sin(pa)) * 7.0, 6.0, Color(0.6, 0.35, 0.75))
					_root.draw_circle(fp, 4.0, Color(0.95, 0.8, 0.3))
				_ring(dc, Vector2(r, r) * 0.97, 0.0, TAU, Color(0.85, 0.7, 0.3), 3.0)  # kultareuna
			_ring(dc, Vector2(r, r) * 0.9, -2.5, -1.1, Color(1, 1, 1, 0.7), 4.0)
	# Lika: epäsäännölliset läikät ja ruoantähteet, haalistuvat hangatessa.
	for s in _spots:
		var sp: Vector2 = dc + s[0] * r * 0.8
		var sr: float = s[1] * r * 0.6
		var a: float = _dirt * 0.85
		_root.draw_circle(sp, sr, Color(0.42, 0.3, 0.15, a))
		_root.draw_circle(sp + Vector2(sr * 0.5, -sr * 0.3), sr * 0.6, Color(0.36, 0.25, 0.12, a))
		_root.draw_circle(sp + Vector2(-sr * 0.4, sr * 0.45), sr * 0.45, Color(0.5, 0.38, 0.2, a * 0.8))
		_root.draw_circle(sp + Vector2(sr * 0.2, sr * 0.1), sr * 0.18, Color(0.75, 0.55, 0.2, a))  # puuron jämä
	for f in _foam:
		var fa: float = 1.0 - f[2] / 2.5
		_bubble(dc + (f[0] as Vector2) * r, f[1] * (0.8 + f[2] * 0.15), fa)
	if _dirt <= 0.0:  # puhdas: kiilto välkkyy
		var gp := dc + Vector2(-r * 0.4, -r * 0.45)
		var gs := 10.0 + sin(_t * 6.0) * 4.0
		_root.draw_line(gp - Vector2(gs, 0), gp + Vector2(gs, 0), Color.WHITE, 3.0)
		_root.draw_line(gp - Vector2(0, gs), gp + Vector2(0, gs), Color.WHITE, 3.0)


## Tiskiharja: kahva ripustusreikineen ja harjaspää harjaksineen.
func _draw_brush(dc: Vector2) -> void:
	var bx := dc + Vector2(_last_dir * 40.0 * _wobble, 20 + sin(_t * 3.0) * 6.0)
	var tilt := -0.35 + _last_dir * 0.15 * _wobble
	var dir := Vector2(sin(-tilt), -cos(-tilt))  # kahvan suunta harjaspäästä ylös
	var top := bx + dir * 170.0
	# Harjaspää ja harjakset.
	var head := Rect2(bx + Vector2(-30, -42), Vector2(60, 46))
	for k in 9:
		var bxk := bx + Vector2(-26 + k * 6.5, 2)
		_root.draw_line(bxk, bxk + Vector2(_last_dir * 3.0 * _wobble, 14), Color(0.9, 0.78, 0.25), 3.0)
	MG.box(_root, head, Color(0.95, 0.85, 0.3), 12, 4, MG.OUTLINE, 2)
	MG.box(_root, Rect2(head.position + Vector2(5, 4), Vector2(50, 12)), Color(1.0, 0.95, 0.6), 8)
	# Kahva.
	_root.draw_line(bx + dir * 30.0, top, MG.OUTLINE, 24.0)
	_root.draw_line(bx + dir * 30.0, top, Color(0.85, 0.2, 0.2), 20.0)
	_root.draw_line(bx + dir * 30.0 + Vector2(-5, 0), top + Vector2(-5, 0), Color(1.0, 0.5, 0.45), 4.0)
	_root.draw_circle(top - dir * 14.0, 5.0, Color(0.3, 0.06, 0.06))  # ripustusreikä


## Pudonnut astia: sirpaleet lentävät ja KRÄSH.
func _draw_shards(c: Vector2) -> void:
	var ft := _drop_t / 0.7
	var d0: Array = _dish()
	for k in 11:
		var a := k * TAU / 11.0 + 0.4
		var p := c + Vector2(cos(a), sin(a)) * (30.0 + 230.0 * ft) + Vector2(0, 170.0 * ft * ft)
		var sz := 1.0 + (k % 3) * 0.5
		var sh := PackedVector2Array([p, p + Vector2(30, 8).rotated(a + ft * 6) * sz, p + Vector2(10, 32).rotated(a - ft * 4) * sz])
		_root.draw_colored_polygon(sh, Color(d0[1], 1.0 - ft * 0.6))
		_root.draw_polyline(sh + PackedVector2Array([sh[0]]), Color(MG.OUTLINE, 1.0 - ft * 0.6), 2.0)
	var font := ThemeDB.fallback_font
	_root.draw_string(font, c + Vector2(-106, -16 + ft * 40), "KRÄSH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(0, 0, 0, 0.6 * (1.0 - ft)))
	_root.draw_string(font, c + Vector2(-110, -20 + ft * 40), "KRÄSH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(1, 0.3, 0.2, 1.0 - ft))


## Puhtausmittari altaan alla.
func _draw_meter(c: Vector2) -> void:
	var bar := Rect2(c + Vector2(-160, 214), Vector2(320, 20))
	MG.box(_root, bar.grow(4.0), Color(0.08, 0.08, 0.09, 0.92), 10, 3)
	if _dirt < 0.99:
		MG.box(_root, Rect2(bar.position, Vector2(bar.size.x * (1.0 - _dirt), bar.size.y)), Color(0.35, 0.82, 0.5), 8)
	_root.draw_string(ThemeDB.fallback_font, bar.position + Vector2(1, -7), "Puhtaus %d %%" % roundi((1.0 - _dirt) * 100.0),
		HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 18, Color(0, 0, 0, 0.7))
	_root.draw_string(ThemeDB.fallback_font, bar.position + Vector2(0, -8), "Puhtaus %d %%" % roundi((1.0 - _dirt) * 100.0),
		HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 18, Color.WHITE)


## Ellipsin kaari (a0..a1 radiaaneina) viivana.
func _ring(c: Vector2, r: Vector2, a0: float, a1: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := lerpf(a0, a1, i / 32.0)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_root.draw_polyline(pts, col, w, true)


