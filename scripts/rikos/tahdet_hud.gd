extends CanvasLayer
## Autovarkauden tähtijahti (rikos/autovarkaus.gd): viisi tähteä ruudun oikeaan yläkulmaan. Täysi tähti on kultainen
## (vaalea yläreuna, tumma alareuna, musta ääriviiva), tyhjä harmaa ääriviiva. Kun jahtaaja näkee pelaajan, tähdet
## vilkkuvat; piilossa ne himmenevät ja pudotusta odotteleva tähti sykkii.

const N := 5
const R := 22.0  # tähden ulkosäde (px)
const STEP := 50.0
const TOP := 140.0  # päivän tilapalkkien (stat_bars.gd: y 36–126) alle

var tahdet := 0
var nakyy := false  # jahtaaja näkee pelaajan juuri nyt
var otsikko := ""  # "PÄIVI" tai "ROIVAINEN"
var game: Node  # main.gd: tähdet vain ulkona (ei sisätiloissa, minipeleissä eikä välianimaatioissa)
var _c: Control


func _ready() -> void:
	layer = 6
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw_stars)
	add_child(_c)


func _process(_d: float) -> void:
	visible = tahdet > 0 and (game == null or game.state == "ulkona")
	if visible:
		_c.queue_redraw()


func _draw_stars() -> void:
	var w := _c.size.x
	var t := Time.get_ticks_msec() / 1000.0
	var blink := nakyy and fmod(t, 0.5) < 0.25
	var right := w - 26.0
	var top := TOP
	# Tausta: tumma pyöristetty levy, jotta tähdet erottuvat taivasta vasten.
	var bw := STEP * N + 16.0
	var bg := Rect2(right - bw, top - 8.0, bw + 8.0, R * 2.0 + 44.0)
	_c.draw_style_box(_panel(), bg)
	for i in N:
		var c := Vector2(right - STEP * (N - 1 - i) - R - 4.0, top + R + 4.0)
		var full := i < tahdet
		var pts := _star(c, R if full else R * 0.92)
		if full:
			var gold := Color(1.0, 0.82, 0.15) if not blink else Color(1.0, 0.95, 0.7)
			if not nakyy:
				gold = gold.darkened(0.25)
			_c.draw_colored_polygon(_star(c + Vector2(2, 3), R), Color(0, 0, 0, 0.45))  # varjo
			_c.draw_colored_polygon(pts, gold.darkened(0.25))
			_c.draw_colored_polygon(_star(c + Vector2(0, -2.0), R * 0.72), gold.lightened(0.25))  # vaalea yläosa
			_c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.15, 0.08, 0.0), 2.5, true)
		else:
			_c.draw_colored_polygon(pts, Color(0.2, 0.2, 0.22, 0.55))
			_c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.75, 0.75, 0.78), 2.0, true)
	if otsikko != "":
		var f := ThemeDB.fallback_font
		var s := 20
		var tw := f.get_string_size(otsikko, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		var at := Vector2(right - tw - 2.0, top + R * 2.0 + 30.0)
		_c.draw_string_outline(f, at, otsikko, HORIZONTAL_ALIGNMENT_LEFT, -1, s, 6, Color(0, 0, 0))
		_c.draw_string(f, at, otsikko, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color(1.0, 0.85, 0.75))


func _panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.55)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(2)
	return sb


## Viisisakarainen tähti, kärki ylöspäin.
static func _star(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + PI * k / 5.0
		var rr := r if k % 2 == 0 else r * 0.45
		out.append(c + Vector2(cos(a), sin(a)) * rr)
	return out
