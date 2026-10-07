extends CanvasLayer
## Tiskaus (Santun homma) mökin keittiössä: astia kerrallaan tiskialtaassa. Hankaa A/D vuorotellen (tai hiirtä
## edestakaisin), kunnes astia on puhdas, ja nosta se kuivauskaappiin (välilyönti tai E). Humalassa märkä astia
## lipsahtaa helposti lattialle. Santtu kommentoi vieressä (mokki_interior.gd say). F / Esc lopettaa kesken.

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


func _ready() -> void:
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
	_wobble = maxf(0.0, _wobble - delta * 2.0)
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
		Sfx.play("glass", 0.0, 0.7)
		comment.emit(LINES["break"].pick_random())
		return
	washed += 1
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


func _draw_root() -> void:
	var sz := _root.size
	var c := sz / 2.0 + Vector2(-60, 40)
	var t := Time.get_ticks_msec() / 1000.0
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.5))
	# Työtaso ja välitila (laatat) altaan takana.
	var counter := Rect2(c - Vector2(400, 260), Vector2(940, 540))
	_box(counter, Color(0.62, 0.48, 0.33), 14, Color(0, 0, 0, 0.45), 18)
	for k in 9:
		_root.draw_line(counter.position + Vector2(0, 30 + k * 60), Vector2(counter.end.x, counter.position.y + 34 + k * 60),
			Color(0.5, 0.37, 0.24, 0.35), 2.0)
	# Teräsallas: reuna, sisäpinta harjattuna, pohjaventtiili.
	var rim := Rect2(c - Vector2(330, 220), Vector2(660, 440))
	_box(rim, Color(0.72, 0.74, 0.77), 26, Color(0, 0, 0, 0.35), 10)
	var basin := rim.grow(-26.0)
	_box(basin, Color(0.48, 0.5, 0.54), 22)
	for k in 30:
		var y := basin.position.y + 8 + k * 13
		_root.draw_line(Vector2(basin.position.x + 16, y), Vector2(basin.end.x - 16, y), Color(1, 1, 1, 0.05), 1.0)
	# Hana takareunassa.
	var tap := c + Vector2(0, -235)
	_box(Rect2(tap + Vector2(-26, -18), Vector2(52, 36)), Color(0.8, 0.82, 0.86), 10, Color(0, 0, 0, 0.3), 6)
	_box(Rect2(tap + Vector2(-9, 0), Vector2(18, 70)), Color(0.85, 0.87, 0.9), 8)
	_root.draw_circle(tap + Vector2(48, 0), 14.0, Color(0.85, 0.15, 0.15))
	_root.draw_circle(tap + Vector2(-48, 0), 14.0, Color(0.2, 0.35, 0.85))
	# Vesi ja vaahto: läpikuultava vesi, kuplat kiiltopisteineen, hidas liike.
	_box(basin.grow(-8.0), Color(0.5, 0.68, 0.78, 0.55), 18)
	for k in 26:
		var a := k * 2.4 + t * 0.15
		var p := c + Vector2(cos(a) * (110 + (k % 7) * 28), sin(a * 1.3) * (90 + (k % 5) * 22))
		var r := 12.0 + (k % 4) * 6.0
		if basin.grow(-r).has_point(p):
			_root.draw_circle(p, r, Color(1, 1, 1, 0.32))
			_root.draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.6))
	# Tiskiainepullo altaan reunalla.
	var bottle := c + Vector2(290, -200)
	_box(Rect2(bottle + Vector2(-20, -40), Vector2(40, 80)), Color(0.2, 0.7, 0.35), 12, Color(0, 0, 0, 0.3), 6)
	_box(Rect2(bottle + Vector2(-7, -56), Vector2(14, 18)), Color(0.95, 0.95, 0.95), 4)
	_box(Rect2(bottle + Vector2(-14, -8), Vector2(28, 26)), Color(1, 1, 1, 0.8), 4)
	# Kuivauskaappi oikealla: tiskatut astiat pinossa.
	var rack := Rect2(c + Vector2(350, -200), Vector2(160, 400))
	_box(rack, Color(0.9, 0.9, 0.88), 10, Color(0, 0, 0, 0.35), 10)
	for k in 9:
		_root.draw_line(rack.position + Vector2(14 + k * 16.5, 14), rack.position + Vector2(14 + k * 16.5, rack.size.y - 14), Color(0.65, 0.67, 0.7), 3.0)
	for k in washed:
		var d: Array = DISHES[k]
		_box(Rect2(rack.position + Vector2(20, rack.size.y - 40 - k * 46), Vector2(rack.size.x - 40, 30)), d[1], 14, Color(0, 0, 0, 0.25), 4)
	_root.draw_string(ThemeDB.fallback_font, rack.position + Vector2(0, -12), "Kuivauskaappi %d" % washed, HORIZONTAL_ALIGNMENT_CENTER, rack.size.x, 18, Color.WHITE)
	if _drop_t >= 0.0:
		# Sirpaleet lentävät ja KRÄSH.
		var ft := _drop_t / 0.7
		var d0: Array = _dish()
		for k in 9:
			var a := k * TAU / 9.0 + 0.4
			var p := c + Vector2(cos(a), sin(a)) * (30.0 + 220.0 * ft) + Vector2(0, 160.0 * ft * ft)
			var sh := PackedVector2Array([p, p + Vector2(18, 6).rotated(a + ft * 6), p + Vector2(6, 20).rotated(a - ft * 4)])
			_root.draw_colored_polygon(sh, Color(d0[1], 1.0 - ft * 0.6))
		_root.draw_string(ThemeDB.fallback_font, c + Vector2(-110, -20 + ft * 40), "KRÄSH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 64,
			Color(1, 0.3, 0.2, 1.0 - ft))
		return
	var d: Array = _dish()
	var off := Vector2(sin(Time.get_ticks_msec() / 40.0) * 10.0 * _wobble, 0)
	var dc := c + off
	var col: Color = d[1]
	var kind: String = d[0]
	var r := 150.0
	match kind:
		"muki":
			r = 95.0
			_root.draw_circle(dc + Vector2(8, 10), r + 4, Color(0, 0, 0, 0.25))
			_box(Rect2(dc + Vector2(r - 12, -22), Vector2(70, 44)), col.darkened(0.1), 22)
			_box(Rect2(dc + Vector2(r + 8, -10), Vector2(32, 20)), Color(0.5, 0.68, 0.78), 10)
			_root.draw_circle(dc, r, col)
			_root.draw_circle(dc, r * 0.82, col.darkened(0.25))
			_root.draw_circle(dc, r * 0.7, Color(0.35, 0.22, 0.12).lerp(col.darkened(0.3), 1.0 - _dirt))  # kahvinpohja
		"lasi":
			r = 90.0
			_root.draw_circle(dc + Vector2(8, 10), r + 4, Color(0, 0, 0, 0.15))
			_root.draw_circle(dc, r, Color(col, 0.55))
			_root.draw_circle(dc, r * 0.85, Color(col.lightened(0.2), 0.35))
			_ring(dc, Vector2(r, r) * 0.95, -2.4, -1.2, Color(1, 1, 1, 0.8), 4.0)
		"kattila":
			r = 140.0
			_root.draw_circle(dc + Vector2(10, 12), r + 6, Color(0, 0, 0, 0.25))
			_box(Rect2(dc + Vector2(r - 6, -14), Vector2(140, 28)), Color(0.14, 0.14, 0.15), 12)
			_root.draw_circle(dc, r, col.lightened(0.15))
			_root.draw_circle(dc, r * 0.9, col)
			_root.draw_circle(dc, r * 0.82, col.darkened(0.12))
			_ring(dc, Vector2(r, r) * 0.86, -2.6, -1.0, Color(1, 1, 1, 0.5), 5.0)
		_:
			_root.draw_circle(dc + Vector2(8, 12), r + 4, Color(0, 0, 0, 0.25))
			_root.draw_circle(dc, r, col)
			_root.draw_circle(dc, r * 0.66, col.darkened(0.05))
			_ring(dc, Vector2(r, r) * 0.66, 0.0, TAU, col.darkened(0.12), 3.0)
			if kind == "mummon kukkalautanen":
				for k in 10:
					var a := k * TAU / 10.0
					var fp := dc + Vector2(cos(a), sin(a)) * r * 0.83
					for pk in 5:
						var pa := pk * TAU / 5.0 + a
						_root.draw_circle(fp + Vector2(cos(pa), sin(pa)) * 7.0, 6.0, Color(0.6, 0.35, 0.75))
					_root.draw_circle(fp, 4.0, Color(0.95, 0.8, 0.3))
				_ring(dc, Vector2(r, r) * 0.97, 0.0, TAU, Color(0.85, 0.7, 0.3), 3.0)  # kultareuna
			_ring(dc, Vector2(r, r) * 0.9, -2.5, -1.1, Color(1, 1, 1, 0.7), 4.0)
	# Lika: epäsäännölliset läikät, haalistuvat hangatessa.
	for s in _spots:
		var sp: Vector2 = dc + s[0] * r * 0.8
		var sr: float = s[1] * r * 0.6
		var a: float = _dirt * 0.85
		_root.draw_circle(sp, sr, Color(0.42, 0.3, 0.15, a))
		_root.draw_circle(sp + Vector2(sr * 0.5, -sr * 0.3), sr * 0.6, Color(0.36, 0.25, 0.12, a))
		_root.draw_circle(sp + Vector2(-sr * 0.4, sr * 0.45), sr * 0.45, Color(0.5, 0.38, 0.2, a * 0.8))
	# Tiskiharja hankaa: liikkuu viimeisimmän vedon suuntaan.
	var bx := dc + Vector2(_last_dir * 40.0 * _wobble, 20 + sin(t * 3.0) * 6.0)
	_box(Rect2(bx + Vector2(-10, -150), Vector2(20, 120)), Color(0.85, 0.2, 0.2), 8, Color(0, 0, 0, 0.3), 5)
	_box(Rect2(bx + Vector2(-26, -40), Vector2(52, 44)), Color(0.95, 0.85, 0.3), 10)
	for k in 6:
		_root.draw_line(bx + Vector2(-22 + k * 9, 4), bx + Vector2(-22 + k * 9, 14), Color(0.85, 0.75, 0.25), 3.0)
	# Puhtausmittari.
	var bar := Rect2(c + Vector2(-160, 210), Vector2(320, 20))
	_box(bar.grow(4.0), Color(0.08, 0.08, 0.09, 0.9), 10)
	if _dirt < 0.99:
		_box(Rect2(bar.position, Vector2(bar.size.x * (1.0 - _dirt), bar.size.y)), Color(0.35, 0.82, 0.5), 8)
	_root.draw_string(ThemeDB.fallback_font, bar.position + Vector2(0, -8), "Puhtaus %d %%" % roundi((1.0 - _dirt) * 100.0),
		HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 18, Color.WHITE)


## Ellipsin kaari (a0..a1 radiaaneina) viivana.
func _ring(c: Vector2, r: Vector2, a0: float, a1: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := lerpf(a0, a1, i / 32.0)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_root.draw_polyline(pts, col, w, true)


## Pyöristetty laatikko (valinnainen varjo).
func _box(r: Rect2, col: Color, radius: int, shadow := Color(0, 0, 0, 0), shadow_size := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.shadow_color = shadow
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(4, 6)
	sb.anti_aliasing = true
	_root.draw_style_box(sb, r)
