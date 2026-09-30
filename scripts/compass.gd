extends Control
## Kompassinauha ruudun yläreunassa: ilmansuunnat liikkuvat kameran suunnan mukaan (P ylös kartalla = -Z).
## Paperikartalta valittu kohde näkyy nauhalla omassa suunnassaan, näkökentän ulkopuolella reunalla nuolena.
## Ei etäisyyttä metreinä, vain "lähellä", kun kohde on lähellä. Mökillä lähin viinakätkö näkyy geokätkön
## tapaan keltaisena merkkinä, jonka alla matka metreinä (main.gd _viina_logic).

const SPAN := 180.0  # asteita nauhan reunasta reunaan
const NEAR := 80.0
const NAMES := {0: "P", 45: "KO", 90: "I", 135: "KA", 180: "E", 225: "LO", 270: "L", 315: "LU"}
const TARGET_COL := Color(0.9, 0.15, 0.1)
const CACHE_COL := Color(1.0, 0.75, 0.1)

var player: Node3D
var paper: Control  # paper_map.gd: has_target, target (maailman x/z)
var show_target := true  # mökillä kylän kohteita ei näytetä
var has_cache := false
var cache := Vector2.ZERO  # viinakätkö (maailman x/z)
var cache_text := ""  # merkin alla; tyhjä = matka metreinä (mopomatkalla kohteen nimi ja todellinen matka)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	offset_top = 10
	offset_bottom = 54


func _process(_delta: float) -> void:
	var w := minf(440.0, get_viewport_rect().size.x * 0.36)
	offset_left = -w / 2.0
	offset_right = w / 2.0
	queue_redraw()


## Kameran suunta asteina: 0 = pohjoinen, 90 = itä.
func _heading() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var f := -cam.global_transform.basis.z
	return fposmod(rad_to_deg(atan2(f.x, -f.z)), 360.0)


func _x_for(deg: float, heading: float) -> float:
	return size.x / 2.0 + wrapf(deg - heading, -180.0, 180.0) / SPAN * size.x


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	draw_line(Vector2(0, h - 1), Vector2(w, h - 1), Color(1, 1, 1, 0.3), 1.0)
	var heading := _heading()
	for d in range(0, 360, 15):
		var x := _x_for(d, heading)
		if x < 4.0 or x > w - 4.0:
			continue
		if NAMES.has(d):
			var txt: String = NAMES[d]
			var main := d % 90 == 0
			var fs := 20 if main else 14
			var col := Color(1, 0.35, 0.3) if d == 0 else (Color.WHITE if main else Color(0.85, 0.85, 0.85))
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string_outline(font, Vector2(x - tw / 2.0, 24), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
			draw_string(font, Vector2(x - tw / 2.0, 24), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		else:
			draw_line(Vector2(x, h - 12), Vector2(x, h - 4), Color(1, 1, 1, 0.6), 1.5)
	# Keskikohta.
	var c := w / 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(c - 6, h), Vector2(c + 6, h), Vector2(c, h - 8)]), Color(1, 1, 1, 0.9))
	_draw_target(heading)
	_draw_cache(heading)


## Ilmansuunta tekstinä (P, KO, I, ...) asteista: 0 = pohjoinen, 90 = itä.
static func dir_name(deg: float) -> String:
	return NAMES[int(roundf(fposmod(deg, 360.0) / 45.0)) % 8 * 45]


## Suunta asteina pisteestä a pisteeseen b (maailman x/z; pohjoinen = -Z).
static func bearing_deg(a: Vector2, b: Vector2) -> float:
	var d := b - a
	return fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)


func _draw_cache(heading: float) -> void:
	if not has_cache or player == null:
		return
	var p := Vector2(player.global_position.x, player.global_position.z)
	var rel := wrapf(bearing_deg(p, cache) - heading, -180.0, 180.0)
	var h := size.y
	if absf(rel) > SPAN / 2.0 - 4.0:
		var s := signf(rel)
		var ex := size.x / 2.0 + s * (size.x / 2.0 - 4.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(ex, h / 2.0), Vector2(ex - s * 12, h / 2.0 - 9), Vector2(ex - s * 12, h / 2.0 + 9)]), CACHE_COL)
		return
	var x := size.x / 2.0 + rel / SPAN * size.x
	var m := Vector2(x, h - 8)
	draw_colored_polygon(PackedVector2Array([m + Vector2(0, -8), m + Vector2(7, 0), m + Vector2(0, 8), m + Vector2(-7, 0)]), Color.BLACK)
	draw_colored_polygon(PackedVector2Array([m + Vector2(0, -6), m + Vector2(5, 0), m + Vector2(0, 6), m + Vector2(-5, 0)]), CACHE_COL)
	var font := ThemeDB.fallback_font
	var txt := cache_text if cache_text != "" else "%d m" % roundi(p.distance_to(cache))
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(font, Vector2(x - tw / 2.0, h + 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
	draw_string(font, Vector2(x - tw / 2.0, h + 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CACHE_COL)


func _draw_target(heading: float) -> void:
	if paper == null or player == null or not paper.has_target or not show_target:
		return
	var p := Vector2(player.global_position.x, player.global_position.z)
	var d: Vector2 = paper.target - p
	var bearing := rad_to_deg(atan2(d.x, -d.y))
	var rel := wrapf(bearing - heading, -180.0, 180.0)
	var h := size.y
	if absf(rel) > SPAN / 2.0 - 4.0:
		# Näkökentän ulkopuolella: nuoli reunaan.
		var s := signf(rel)
		var x := size.x / 2.0 + s * (size.x / 2.0 - 4.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, h / 2.0), Vector2(x - s * 12, h / 2.0 - 9), Vector2(x - s * 12, h / 2.0 + 9)]), TARGET_COL)
		return
	var x := size.x / 2.0 + rel / SPAN * size.x
	var m := Vector2(x, h - 8)
	draw_circle(m, 6.0, Color.BLACK)
	draw_circle(m, 4.5, TARGET_COL)
	if d.length() < NEAR:
		var font := ThemeDB.fallback_font
		var tw := font.get_string_size("lähellä", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string_outline(font, Vector2(x - tw / 2.0, h + 14), "lähellä", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		draw_string(font, Vector2(x - tw / 2.0, h + 14), "lähellä", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TARGET_COL.lightened(0.3))
