extends Node
## Piirtää lippiksen etupaneelin merkin (tuima karhunpää + KARHU-teksti) tekstuuriksi assets/cap_logo.png.
## Oma tyylitelty merkki, ei kopio oikeasta logosta. Ajo: godot --path . tools/cap_logo.tscn

const SIZE := Vector2i(512, 384)
const GOLD := Color(0.96, 0.74, 0.22)
const GOLD_DARK := Color(0.62, 0.4, 0.1)
const BROWN := Color(0.22, 0.12, 0.05)
const RED := Color(0.72, 0.07, 0.06)
const WHITE := Color(0.98, 0.96, 0.92)

var _vp: SubViewport
var _frames := 0


class Bear extends Control:
	func _draw() -> void:
		var c := Vector2(256, 132)
		var out := 7.0
		# Korvat
		for sx in [-1.0, 1.0]:
			var e := c + Vector2(sx * 74, -70)
			draw_circle(e, 40 + out, BROWN)
			draw_circle(e, 40, GOLD)
			draw_circle(e + Vector2(sx * -4, 4), 21, GOLD_DARK)
		# Pää: leveähkö, alaspäin kapeneva
		draw_circle(c, 104 + out, BROWN)
		draw_colored_polygon(_ellipse(c + Vector2(0, 8), Vector2(104 + out, 96 + out)), BROWN)
		draw_circle(c, 104, GOLD)
		draw_colored_polygon(_ellipse(c + Vector2(0, 8), Vector2(104, 96)), GOLD)
		# Kulmakarvat ja silmät: vihainen karhu
		for sx in [-1.0, 1.0]:
			var ey := c + Vector2(sx * 40, -14)
			draw_circle(ey, 11, BROWN)
			# Sisäpää alempana = vihainen ilme.
			draw_line(ey + Vector2(sx * -22, -10), ey + Vector2(sx * 24, -30), BROWN, 11.0, true)
		# Kuono
		draw_colored_polygon(_ellipse(c + Vector2(0, 42), Vector2(50, 38)), BROWN)
		draw_colored_polygon(_ellipse(c + Vector2(0, 42), Vector2(43, 31)), Color(0.99, 0.86, 0.5))
		draw_colored_polygon(_ellipse(c + Vector2(0, 28), Vector2(20, 13)), BROWN)  # nenä
		draw_line(c + Vector2(0, 38), c + Vector2(0, 52), BROWN, 5.0, true)
		draw_line(c + Vector2(-20, 58), c + Vector2(20, 58), BROWN, 5.0, true)  # tuima suu

	func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return pts


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var bear := Bear.new()
	bear.size = Vector2(SIZE)
	_vp.add_child(bear)
	var l := Label.new()
	l.text = "KARHU"
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Arial Black", "Impact", "Helvetica Neue"])
	f.font_weight = 900
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 104)
	l.add_theme_color_override("font_color", WHITE)
	l.add_theme_color_override("font_outline_color", RED)
	l.add_theme_constant_override("outline_size", 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 244)
	l.size = Vector2(SIZE.x, 130)
	_vp.add_child(l)


func _process(_d: float) -> void:
	_frames += 1
	if _frames == 6:
		_vp.get_texture().get_image().save_png("res://assets/cap_logo.png")
		print("cap_logo.png tallennettu")
		get_tree().quit()
