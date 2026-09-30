extends Control
## Kompassinauha ruudun yläreunassa: ilmansuunnat liikkuvat kameran suunnan mukaan (P ylös kartalla = -Z).
## Paperikartalta valittu kohde näkyy nauhalla omassa suunnassaan, näkökentän ulkopuolella reunalla nuolena.
## Ei etäisyyttä metreinä, vain "lähellä", kun kohde on lähellä.

const SPAN := 180.0  # asteita nauhan reunasta reunaan
const NEAR := 80.0
const NAMES := {0: "P", 45: "KO", 90: "I", 135: "KA", 180: "E", 225: "LO", 270: "L", 315: "LU"}
const TARGET_COL := Color(0.9, 0.15, 0.1)

var player: Node3D
var paper: Control  # paper_map.gd: has_target, target (maailman x/z)
var show_target := true  # mökillä kylän kohteita ei näytetä


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
