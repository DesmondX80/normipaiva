extends Node
## Piirtää Karhu-kutosen pahvikopan painatuksen tekstuuriksi assets/karhu_koppa.png (Looks.add_koppa): koppa
## pujotetaan päähän sivun aukosta, joten kuva on yksi kaistale kopan ympäri (2 px/mm, vasemmalta oikealle ulkoa
## katsottuna): etupaneeli 235 mm, kansi pullonkaulojen rei'illä 135 mm, takapaneeli 235 mm ja pohja 135 mm; korkeus
## 200 mm on kolmen pullon rivi. Etu- ja takapaneelissa tuima kaiverrustyylinen karhunpää kyljellään, karhun
## päälaki kohti kantta. Oma tyylitelty kuva, ei kopio oikeasta pakkauksesta. Ajo: godot --path . tools/karhu_koppa.tscn

const SIZE := Vector2i(1480, 400)
const SEG := [0, 470, 740, 1210, 1480]  # paneelien rajat: etu, kansi, taka, pohja
const AW := 400.0  # karhupaneeli omassa asennossaan: leveys (kopan korkeus)
const AH := 470.0  # ja korkeus (pullon pituus)
const HOLES_V := [66.7, 200.0, 333.3]  # pullonkaulojen reiät kannessa
const HOLES_U := [67.5, 202.5]
const HOLE_R := 26.0
const BG := Color(0.1, 0.075, 0.06)
const BG_LIGHT := Color(0.2, 0.15, 0.11)
const GOLD := Color(0.98, 0.76, 0.32)
const GOLD_DARK := Color(0.72, 0.38, 0.08)
const EMBER := Color(1.0, 0.55, 0.1)

var _vp: SubViewport
var _frames := 0


class Art extends Control:
	var serif: SystemFont

	func _draw() -> void:
		# Tausta: tumma, hieman lämpimämpi keskeltä.
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(SIZE.x, 0), Vector2(SIZE.x, SIZE.y), Vector2(0, SIZE.y)]),
			PackedColorArray([BG, BG, BG, BG]))
		_bear_panel(Transform2D(Vector2(0, 1), Vector2(-1, 0), Vector2(SEG[0] + AH, 0)))  # karhun päälaki oikealle
		_bear_panel(Transform2D(Vector2(0, -1), Vector2(1, 0), Vector2(SEG[2], AW)))  # takana päälaki vasemmalle
		draw_set_transform_matrix(Transform2D())
		_lid(SEG[1])
		_bottom(SEG[3])
		for x in SEG:  # taitokset
			draw_line(Vector2(x, 0), Vector2(x, SIZE.y), Color(0.04, 0.03, 0.02), 4.0)

	## Karhupaneeli omassa asennossaan (0..AW, 0..AH): teksti ylhäällä, karhunpää, TOSI VAHVA ja viivakoodi alhaalla.
	func _bear_panel(t: Transform2D) -> void:
		draw_set_transform_matrix(t)
		for k in 6:  # lämmin hehku karhun takana
			draw_circle(Vector2(200, 245), 200.0 - k * 12.0, Color(BG_LIGHT, 0.25))
		_text("TÄYTTÄ OLUTTA", Vector2(200, 50), 34, GOLD)
		_bear(Vector2(200, 250))
		_text("TOSI VAHVA", Vector2(165, 436), 38, GOLD)
		# Viivakoodi keltaisella tarralla oikeassa alakulmassa.
		draw_rect(Rect2(318, 404, 64, 44), Color(0.98, 0.84, 0.15))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var x := 323.0
		while x < 376.0:
			var w := float(rng.randi_range(1, 3))
			draw_rect(Rect2(x, 408, w, 32), Color(0.08, 0.06, 0.04))
			x += w + float(rng.randi_range(1, 3))

	func _text(s: String, center: Vector2, size: int, col: Color) -> void:
		var w := serif.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p := center + Vector2(-w / 2.0, size * 0.35)
		draw_string_outline(serif, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.05, 0.03, 0.02))
		draw_string(serif, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

	## Pään säde kulmassa a (0 = oikealle, -PI/2 = ylös): leveä pää, korvat ylhäällä viistosti, kapeneva leuka.
	func _head_r(a: float) -> float:
		var r := 128.0 + 10.0 * cos(2.0 * a)
		for e in [-PI * 0.5 - 0.95, -PI * 0.5 + 0.95]:  # korvat
			var d := wrapf(a - e, -PI, PI)
			r += 40.0 * exp(-d * d / 0.05)
		var down := wrapf(a - PI * 0.5, -PI, PI)  # leuka hieman pitkä
		r += 12.0 * exp(-down * down / 0.3)
		return r

	func _bear(c: Vector2) -> void:
		var outline := PackedVector2Array()
		for i in 120:
			var a := TAU * i / 120.0
			outline.append(c + Vector2(cos(a), sin(a)) * (_head_r(a) + 6.0))
		draw_colored_polygon(outline, Color(0.05, 0.03, 0.02))
		var fill := PackedVector2Array()
		for i in 120:
			var a := TAU * i / 120.0
			fill.append(c + Vector2(cos(a), sin(a)) * _head_r(a))
		draw_colored_polygon(fill, Color(0.2, 0.11, 0.04))
		# Turkki kaiverrusviivoina: karva lähtee kuonosta ylös ja ulos, reunoilla pidempi ja tummempi. Vedot hilasta,
		# suunta kuonosta poispäin (ei säteittäin keskeltä, ettei pää näytä räjähdykseltä).
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var root := c + Vector2(0, 70)
		var y := c.y - 175.0
		while y < c.y + 175.0:
			var x := c.x - 175.0 + fmod(y, 2.0) * 4.0
			while x < c.x + 175.0:
				var p := Vector2(x, y) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
				var off := p - c
				var R := _head_r(off.angle())
				var f := off.length() / R
				if f < 0.97:
					var d := (p - root).normalized()
					var len := lerpf(9.0, 22.0, f)
					var q := p + d * len
					if (q - c).length() > _head_r((q - c).angle()) - 3.0:
						q = p + d * maxf(2.0, len * 0.4)
					draw_line(p, q, GOLD.lerp(GOLD_DARK, clampf(f * f * 1.1, 0.0, 1.0)), lerpf(2.6, 1.8, f), true)
				x += 11.0
			y += 9.0
		# Reunan karvatupsut ääriviivassa.
		for i in 90:
			var a := TAU * i / 90.0
			var R := _head_r(a)
			draw_line(c + Vector2(cos(a), sin(a)) * (R - 10.0), c + Vector2(cos(a + 0.03), sin(a + 0.03)) * (R + 5.0),
				GOLD_DARK, 2.4, true)
		# Korvien sisus tummana.
		for e in [-PI * 0.5 - 0.95, -PI * 0.5 + 0.95]:
			var ec := c + Vector2(cos(e), sin(e)) * 142.0
			_ellipse(ec, Vector2(20, 17), Color(0.12, 0.06, 0.03))
			draw_arc(ec, 19.0, PI, TAU, 16, GOLD, 3.0, true)
		# Kuono: vaaleampi, hienot vaakaviivat.
		var mz := c + Vector2(0, 58)
		_ellipse(mz, Vector2(64, 50), Color(0.08, 0.05, 0.03))
		for k in 13:
			var my := -44.0 + k * 7.4
			var hw := 60.0 * sqrt(maxf(0.0, 1.0 - pow(my / 48.0, 2.0)))
			draw_line(mz + Vector2(-hw, my), mz + Vector2(hw, my), GOLD.lerp(GOLD_DARK, absf(my) / 60.0), 2.6, true)
		# Nenä: tumma pyöristetty kolmio, kiilto päällä.
		var nose := PackedVector2Array([mz + Vector2(-30, -26), mz + Vector2(30, -26), mz + Vector2(22, -6), mz + Vector2(0, 8),
			mz + Vector2(-22, -6)])
		draw_colored_polygon(nose, Color(0.06, 0.04, 0.03))
		_ellipse(mz + Vector2(-8, -20), Vector2(9, 4), Color(0.5, 0.35, 0.2))
		# Avoin suu karjaisussa: punainen, tummat reunat, valkoiset kulmahampaat.
		var mouth := mz + Vector2(0, 32)
		_ellipse(mouth, Vector2(30, 17), Color(0.05, 0.03, 0.02))
		_ellipse(mouth + Vector2(0, 2), Vector2(24, 12), Color(0.78, 0.14, 0.1))
		for s in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([mouth + Vector2(s * 16, -10), mouth + Vector2(s * 9, -10),
				mouth + Vector2(s * 12, 0)]), Color(0.96, 0.92, 0.82))
		# Silmät: hehkuvat, vihaiset kulmat.
		for s in [-1.0, 1.0]:
			var ey := c + Vector2(s * 52, -18)
			draw_circle(ey, 24.0, Color(0.05, 0.03, 0.02))
			draw_circle(ey, 15.0, Color(EMBER, 0.5))
			_ellipse(ey, Vector2(13, 7), Color(1.0, 0.82, 0.3))
			_ellipse(ey, Vector2(4, 6), Color(0.15, 0.05, 0.02))
			draw_line(ey + Vector2(s * -24, -6), ey + Vector2(s * 26, -26), Color(0.05, 0.03, 0.02), 9.0, true)

	func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)

	## Kansi: kultainen kehys ja painettu rengas jokaisen pullonkaulan reiän ympärillä (reiät tehdään läpinäkyviksi).
	func _lid(x0: float) -> void:
		var w: float = SEG[2] - SEG[1]
		draw_rect(Rect2(x0 + 10, 10, w - 20, SIZE.y - 20), GOLD_DARK, false, 3.0)
		for v in HOLES_V:
			for u in HOLES_U:
				draw_arc(Vector2(x0 + u, v), HOLE_R + 8.0, 0.0, TAU, 32, GOLD, 4.0, true)
		_text("KARHU", Vector2(x0 + w / 2.0, 133), 30, GOLD)
		_text("KARHU", Vector2(x0 + w / 2.0, 267), 30, GOLD)

	## Pohja: lukitusläpät ja pieni teksti.
	func _bottom(x0: float) -> void:
		var w: float = SEG[4] - SEG[3]
		for v in [100.0, 300.0]:
			draw_rect(Rect2(x0 + w / 2.0 - 40, v - 12, 80, 24), Color(0.04, 0.03, 0.02))
			draw_rect(Rect2(x0 + w / 2.0 - 40, v - 12, 80, 24), BG_LIGHT, false, 2.0)
		_text("6 × 0,33 l", Vector2(x0 + w / 2.0, 200), 26, GOLD_DARK)


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var art := Art.new()
	art.size = Vector2(SIZE)
	art.serif = SystemFont.new()
	art.serif.font_names = PackedStringArray(["DejaVu Serif", "Georgia", "Times New Roman"])
	art.serif.font_weight = 800
	_vp.add_child(art)


func _process(_d: float) -> void:
	_frames += 1
	if _frames != 6:
		return
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	for v in HOLES_V:  # pullonkaulojen reiät läpi
		for u in HOLES_U:
			var c := Vector2(SEG[1] + u, v)
			for y in range(int(v - HOLE_R) - 1, int(v + HOLE_R) + 2):
				for x in range(int(c.x - HOLE_R) - 1, int(c.x + HOLE_R) + 2):
					if Vector2(x + 0.5, y + 0.5).distance_to(c) < HOLE_R:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
	img.save_png("res://assets/karhu_koppa.png")
	print("karhu_koppa.png tallennettu")
	get_tree().quit()
