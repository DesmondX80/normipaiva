extends Control
## Vuorokausikello HUD:n vasemmassa yläkulmassa (Päivin lappu saa mennä päälle): 90-luvun digitaalinen rannekello (musta muovikehys, vihertävä
## LCD, 7-segmenttinumerot, sammuneet segmentit haaleina, kaksoispiste vilkkuu sekunnin tahdissa). Vasemmalla
## päivän numero ja aurinko tai kuu vuorokaudenajan mukaan. main.gd asettaa minutes (0–1439) ja day.

const SIZE := Vector2(212, 70)
const CASE := Color(0.1, 0.1, 0.11)
const BEZEL := Color(0.22, 0.22, 0.24)
const LCD := Color(0.66, 0.72, 0.58)
const INK := Color(0.1, 0.12, 0.1)
const GHOST := Color(0.1, 0.12, 0.1, 0.06)
## Segmentit a–g kullekin numerolle.
const DIGITS := ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"]

var minutes := 480.0
var day := 1


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Kehys: musta muovi, ylä- ja alareunassa rannekkeen tyvet, kirkas reuna.
	_round(Rect2(Vector2(14, -4), Vector2(SIZE.x - 28, 8)), CASE.lightened(0.05), 3)
	_round(Rect2(Vector2(14, SIZE.y - 4), Vector2(SIZE.x - 28, 8)), CASE.lightened(0.05), 3)
	_round(Rect2(Vector2.ZERO, SIZE), CASE, 14)
	_round(Rect2(Vector2(3, 3), SIZE - Vector2(6, 6)), BEZEL, 12)
	draw_string(font, Vector2(14, 15), "NORMI", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.7, 0.35))
	draw_string(font, Vector2(SIZE.x - 92, 15), "ALARM · LIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.7, 0.72))
	var lcd := Rect2(Vector2(10, 20), Vector2(SIZE.x - 20, SIZE.y - 28))
	_round(lcd, LCD, 5)
	draw_rect(Rect2(lcd.position, Vector2(lcd.size.x, 3)), Color(0, 0, 0, 0.12))  # lasin varjo
	# Vasen sarake: päivä ja aurinko/kuu.
	var h := int(minutes) / 60
	var m := int(minutes) % 60
	draw_string(font, lcd.position + Vector2(6, 15), "PV", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	draw_string(font, lcd.position + Vector2(6, 35), str(day), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	var icon := lcd.position + Vector2(46, 21)
	if h >= 5 and h < 22:
		draw_circle(icon, 5.0, INK)
		for k in 8:
			var a := k * TAU / 8.0
			draw_line(icon + Vector2(cos(a), sin(a)) * 7.0, icon + Vector2(cos(a), sin(a)) * 10.0, INK, 1.5)
	else:
		draw_circle(icon, 7.0, INK)
		draw_circle(icon + Vector2(3.5, -2.5), 6.0, LCD)
	# Kellonaika 7-segmenttinumeroina.
	var x0 := lcd.position.x + 66.0
	var y0 := lcd.position.y + 5.0
	var dw := 17.0
	var dh := 32.0
	var gap := 11.0
	_digit(h / 10 if h >= 10 else -1, Vector2(x0, y0), dw, dh)
	_digit(h % 10, Vector2(x0 + dw + gap, y0), dw, dh)
	var cx := x0 + 2.0 * dw + gap + 5.0
	var blink := Time.get_ticks_msec() % 1000 < 600
	for cy in [y0 + dh * 0.3, y0 + dh * 0.7]:
		draw_rect(Rect2(Vector2(cx, cy - 2), Vector2(4, 4)), INK if blink else GHOST)
	_digit(m / 10, Vector2(cx + 11.0, y0), dw, dh)
	_digit(m % 10, Vector2(cx + 11.0 + dw + gap, y0), dw, dh)


## Yksi 7-segmenttinumero (n = -1: kaikki segmentit sammuksissa, esim. johtava nolla).
func _digit(n: int, p: Vector2, w: float, h: float) -> void:
	var t := 3.4
	var on: String = DIGITS[n] if n >= 0 else ""
	var hh := h / 2.0
	var segs := {
		"a": [p + Vector2(t * 0.6, 0), p + Vector2(w - t * 0.6, 0), true],
		"d": [p + Vector2(t * 0.6, h), p + Vector2(w - t * 0.6, h), true],
		"g": [p + Vector2(t * 0.6, hh), p + Vector2(w - t * 0.6, hh), true],
		"f": [p + Vector2(0, t * 0.6), p + Vector2(0, hh - t * 0.6), false],
		"b": [p + Vector2(w, t * 0.6), p + Vector2(w, hh - t * 0.6), false],
		"e": [p + Vector2(0, hh + t * 0.6), p + Vector2(0, h - t * 0.6), false],
		"c": [p + Vector2(w, hh + t * 0.6), p + Vector2(w, h - t * 0.6), false],
	}
	for k in segs:
		var a: Vector2 = segs[k][0]
		var b: Vector2 = segs[k][1]
		var hor: bool = segs[k][2]
		var n2 := Vector2(0, t / 2.0) if hor else Vector2(t / 2.0, 0)
		var dir := (b - a).normalized() * (t / 2.0)
		var poly := PackedVector2Array([a, a + dir + n2, b - dir + n2, b, b - dir - n2, a + dir - n2])
		draw_colored_polygon(poly, INK if k in on else GHOST)


func _round(r: Rect2, col: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	draw_style_box(sb, r)
