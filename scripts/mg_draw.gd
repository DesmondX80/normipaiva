extends RefCounted
## Minipelien piirtoapurit (CanvasItem-piirto): sävytetyt laatikot ja pinnat, puu- ja metallipinnat, kyltit,
## puhekuplat, kipinät ja yksinkertaiset sarjakuvahahmot. Kaikki staattisia: MG.box(ci, ...).
## Tyyli: lämmin, hieman sarjakuvamainen, tummat ääriviivat, vaalea yläreuna ja tumma alareuna.

const OUTLINE := Color(0.08, 0.06, 0.05, 0.9)


## Pyöristetty laatikko varjolla ja valinnaisella reunuksella.
static func box(ci: CanvasItem, r: Rect2, col: Color, radius := 8, shadow := 0, border := Color(0, 0, 0, 0), bw := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(3, 5)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	ci.draw_style_box(sb, r)


## Pystysuunnassa liukuvärjätty suorakaide (ylhäältä top, alhaalta bottom).
static func grad_rect(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))


## Sävytetty "kappale": liukuväri, vaalea yläreuna, tumma alareuna ja ääriviiva.
static func solid(ci: CanvasItem, r: Rect2, col: Color, outline := true) -> void:
	grad_rect(ci, r, col.lightened(0.18), col.darkened(0.22))
	ci.draw_line(r.position + Vector2(2, 2), r.position + Vector2(r.size.x - 2, 2), col.lightened(0.45), 2.0)
	if outline:
		ci.draw_rect(r, OUTLINE, false, 2.0)


## Pyöreä sävytetty kappale (metallinen tai muovinen): tumma reuna, vaalea kiilto vasemmalla ylhäällä.
static func ball(ci: CanvasItem, c: Vector2, rad: float, col: Color, shine := 0.5) -> void:
	ci.draw_circle(c + Vector2(2, 3), rad, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, rad, col.darkened(0.3))
	ci.draw_circle(c - Vector2(rad * 0.08, rad * 0.08), rad * 0.88, col)
	ci.draw_circle(c - Vector2(rad * 0.35, rad * 0.35), rad * 0.3, col.lightened(shine))
	ci.draw_arc(c, rad, 0, TAU, 32, OUTLINE, 2.0, true)


## Puulankkupinta (työpöytä, lattia): lankut, syyt, oksankohdat. seed pitää kuvion paikallaan.
static func wood(ci: CanvasItem, r: Rect2, col: Color, plank := 70.0, seed_i := 1, horizontal := true) -> void:
	ci.draw_rect(r, col)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var n := int((r.size.y if horizontal else r.size.x) / plank) + 1
	for i in n:
		var shade := col.darkened(rng.randf_range(-0.08, 0.12))
		var pr := Rect2(r.position + Vector2(0, i * plank), Vector2(r.size.x, minf(plank, r.size.y - i * plank))) if horizontal \
			else Rect2(r.position + Vector2(i * plank, 0), Vector2(minf(plank, r.size.x - i * plank), r.size.y))
		ci.draw_rect(pr, shade)
		for g in 5:  # syyt
			if horizontal:
				var y := pr.position.y + rng.randf_range(minf(6, pr.size.y / 2.0), maxf(pr.size.y - 6, pr.size.y / 2.0))
				var x0 := pr.position.x + rng.randf_range(0, r.size.x * 0.4)
				var x1 := minf(x0 + rng.randf_range(minf(80, r.size.x * 0.3), r.size.x * 0.6), r.end.x)
				ci.draw_line(Vector2(x0, y), Vector2(x1, clampf(y + rng.randf_range(-3, 3), pr.position.y, pr.end.y)), shade.darkened(0.18), 1.5)
			else:
				var x := pr.position.x + rng.randf_range(minf(6, pr.size.x / 2.0), maxf(pr.size.x - 6, pr.size.x / 2.0))
				var y0 := pr.position.y + rng.randf_range(0, r.size.y * 0.4)
				var y1 := minf(y0 + rng.randf_range(minf(80, r.size.y * 0.3), r.size.y * 0.6), r.end.y)
				ci.draw_line(Vector2(x, y0), Vector2(clampf(x + rng.randf_range(-3, 3), pr.position.x, pr.end.x), y1), shade.darkened(0.18), 1.5)
		if rng.randf() < 0.6 and pr.size.x > 40 and pr.size.y > 20:  # oksankohta
			var k := pr.position + Vector2(rng.randf_range(20, pr.size.x - 20), rng.randf_range(10, pr.size.y - 10))
			ci.draw_circle(k, 6.0, shade.darkened(0.3))
			ci.draw_arc(k, 9.0, 0, TAU, 16, shade.darkened(0.2), 1.5)
		if horizontal:
			ci.draw_line(pr.position, pr.position + Vector2(r.size.x, 0), col.darkened(0.45), 2.0)
		else:
			ci.draw_line(pr.position, pr.position + Vector2(0, r.size.y), col.darkened(0.45), 2.0)


## Valokeila tai lampun hehku: säteittäinen läpikuultava ympyräsarja.
static func glow(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	for k in 8:
		var t := 1.0 - k / 8.0
		ci.draw_circle(c, rad * t, Color(col.r, col.g, col.b, col.a * 0.14))


## Kyltti: levy, reunus, ruuvit kulmissa ja teksti keskellä.
static func sign(ci: CanvasItem, r: Rect2, text: String, bg: Color, fg: Color, size := 24, border := Color.WHITE) -> void:
	box(ci, r.grow(4), border, 6, 4)
	box(ci, r, bg, 4)
	for p in [r.position + Vector2(8, 8), r.position + Vector2(r.size.x - 8, 8), r.end - Vector2(8, 8), r.position + Vector2(8, r.size.y - 8)]:
		ci.draw_circle(p, 3.0, border.darkened(0.3))
	var font := ThemeDB.fallback_font
	var lines := text.split("\n")
	var lh := size * 1.15
	var y0 := r.position.y + r.size.y / 2.0 - lh * lines.size() / 2.0 + size * 0.85
	for i in lines.size():
		ci.draw_string(font, Vector2(r.position.x, y0 + i * lh), lines[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, fg)


## Puhekupla: valkoinen pyöristetty laatikko ja nokka kohti puhujaa.
static func bubble(ci: CanvasItem, r: Rect2, tail: Vector2, text: String, size := 22) -> void:
	var base := Vector2(clampf(tail.x, r.position.x + 20, r.end.x - 20), r.end.y if tail.y > r.end.y else r.position.y)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-12, 0), base + Vector2(12, 0), tail]), Color.WHITE)
	box(ci, r, Color.WHITE, 14, 4, OUTLINE, 2)
	ci.draw_line(base + Vector2(-12, 0), tail, OUTLINE, 2.0)
	ci.draw_line(base + Vector2(12, 0), tail, OUTLINE, 2.0)
	ci.draw_line(base + Vector2(-10, 0), base + Vector2(10, 0), Color.WHITE, 3.0)
	ci.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, r.size.y / 2.0 + size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x, size, Color(0.1, 0.08, 0.06))


## Kipinät tai roiskeet: [[pos, vel, age, col], ...] päivitetään delta-ajalla ja piirretään.
static func sparks_step(list: Array, delta: float) -> void:
	for s in list:
		s[2] += delta
		s[1].y += 500.0 * delta
		s[0] += s[1] * delta
	for i in range(list.size() - 1, -1, -1):
		if list[i][2] > 0.7:
			list.remove_at(i)


static func sparks_burst(list: Array, at: Vector2, col: Color, n := 18) -> void:
	for i in n:
		var a := randf() * TAU
		list.append([at, Vector2(cos(a), sin(a) - 0.8) * randf_range(120, 320), 0.0, col])


static func sparks_draw(ci: CanvasItem, list: Array) -> void:
	for s in list:
		var t: float = 1.0 - s[2] / 0.7
		ci.draw_circle(s[0], 2.0 + 3.0 * t, Color(s[3].r, s[3].g, s[3].b, t))


## Sarjakuvahahmo edestä: pää (iho, hiukset tyylin mukaan, silmät katseen suuntaan, suu), vartalo paidassa ja kädet.
## look: {skin, hair, hair_col, shirt, pants, cap, beard, glasses, tie}. eye_dir = katseen suunta (-1..1), talk = suu auki.
## arm_up: oikea käsi ylhäällä (huuto), paddle = huutolappu kädessä.
static func person(ci: CanvasItem, c: Vector2, s: float, look: Dictionary, eye_dir := Vector2.ZERO, talk := false,
		arm_up := 0.0, paddle := "") -> void:
	var skin: Color = look.get("skin", Color(0.96, 0.78, 0.68))
	var shirt: Color = look.get("shirt", Color(0.3, 0.4, 0.6))
	var hair: Color = look.get("hair_col", Color(0.35, 0.25, 0.15))
	# Vartalo ja olkapäät.
	var body := Rect2(c + Vector2(-34, 34) * s, Vector2(68, 70) * s)
	box(ci, body, shirt, int(22 * s), 0, OUTLINE, 2)
	ci.draw_rect(Rect2(body.position + Vector2(6, 6) * s, Vector2(56, 10) * s), shirt.lightened(0.15))
	if look.get("stripes", false):  # tuulipuvun raidat
		ci.draw_line(body.position + Vector2(10, 20) * s, body.position + Vector2(58, 50) * s, Color(0.0, 0.7, 0.7), 8.0 * s)
		ci.draw_line(body.position + Vector2(10, 32) * s, body.position + Vector2(58, 62) * s, Color(0.05, 0.05, 0.05), 5.0 * s)
	if look.get("tie", false):
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 36) * s, c + Vector2(5, 36) * s, c + Vector2(7, 70) * s,
			c + Vector2(0, 78) * s, c + Vector2(-7, 70) * s]), Color(0.65, 0.1, 0.12))
	# Vasen käsi alhaalla, oikea nousee huudettaessa.
	ci.draw_line(c + Vector2(-32, 44) * s, c + Vector2(-44, 92) * s, shirt.darkened(0.1), 14.0 * s)
	ci.draw_circle(c + Vector2(-44, 96) * s, 7.0 * s, skin)
	var hand := c + Vector2(32, 44) * s + Vector2(16, lerpf(48, -62, arm_up)) * s
	ci.draw_line(c + Vector2(32, 44) * s, hand, shirt.darkened(0.1), 14.0 * s)
	ci.draw_circle(hand, 7.0 * s, skin)
	if paddle != "" and arm_up > 0.3:
		var pr := Rect2(hand + Vector2(-20, -52) * s, Vector2(40, 34) * s)
		box(ci, pr, Color(0.97, 0.95, 0.88), 4, 2, OUTLINE, 2)
		ci.draw_string(ThemeDB.fallback_font, pr.position + Vector2(0, 25 * s), paddle, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, int(22 * s), Color(0.1, 0.1, 0.1))
		ci.draw_line(hand, hand + Vector2(0, -18) * s, Color(0.45, 0.3, 0.15), 4.0 * s)
	# Kaula ja pää.
	ci.draw_rect(Rect2(c + Vector2(-8, 22) * s, Vector2(16, 14) * s), skin.darkened(0.1))
	ci.draw_circle(c + Vector2(2, 3) * s, 31.0 * s, Color(0, 0, 0, 0.25))
	ci.draw_circle(c, 30.0 * s, skin)
	ci.draw_circle(c + Vector2(-29, 2) * s, 6.0 * s, skin.darkened(0.08))  # korvat
	ci.draw_circle(c + Vector2(29, 2) * s, 6.0 * s, skin.darkened(0.08))
	match look.get("hair", "short"):
		"buns":  # mummon nuttura
			ci.draw_circle(c + Vector2(0, -36) * s, 13.0 * s, hair)
			ci.draw_arc(c, 30.0 * s, PI * 1.05, PI * 1.95, 16, hair, 12.0 * s)
		"long":
			ci.draw_arc(c, 31.0 * s, PI * 0.9, PI * 2.1, 20, hair, 14.0 * s)
			ci.draw_rect(Rect2(c + Vector2(-36, 0) * s, Vector2(10, 34) * s), hair)
			ci.draw_rect(Rect2(c + Vector2(26, 0) * s, Vector2(10, 34) * s), hair)
		"parted":
			ci.draw_arc(c, 30.0 * s, PI * 1.0, PI * 2.0, 16, hair, 12.0 * s)
			ci.draw_line(c + Vector2(-8, -30) * s, c + Vector2(-12, -18) * s, skin, 3.0 * s)
		_:
			ci.draw_arc(c, 30.0 * s, PI * 1.08, PI * 1.92, 16, hair, 9.0 * s)
	if look.get("cap", false):
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-30, -10) * s, c + Vector2(30, -10) * s, c + Vector2(26, -30) * s,
			c + Vector2(0, -36) * s, c + Vector2(-26, -30) * s]), Color(0.08, 0.08, 0.1))
		ci.draw_rect(Rect2(c + Vector2(-4, -14) * s, Vector2(44, 6) * s), Color(0.08, 0.08, 0.1))
	# Silmät katseen suuntaan, kulmat, nenä ja suu.
	for ex in [-11.0, 11.0]:
		var e := c + Vector2(ex, -4) * s
		ci.draw_circle(e, 6.0 * s, Color.WHITE)
		ci.draw_circle(e + eye_dir * 3.0 * s, 3.0 * s, Color(0.1, 0.08, 0.06))
		ci.draw_line(e + Vector2(-6, -9) * s, e + Vector2(6, -10) * s, hair.darkened(0.3), 2.5 * s)
	if look.get("glasses", false):
		for ex in [-11.0, 11.0]:
			ci.draw_arc(c + Vector2(ex, -4) * s, 8.5 * s, 0, TAU, 16, Color(0.2, 0.2, 0.2), 2.0 * s)
		ci.draw_line(c + Vector2(-3, -4) * s, c + Vector2(3, -4) * s, Color(0.2, 0.2, 0.2), 2.0 * s)
	ci.draw_line(c + Vector2(0, 0) * s, c + Vector2(-3, 8) * s, skin.darkened(0.25), 2.0 * s)
	if look.get("beard", false):
		ci.draw_arc(c + Vector2(0, 6) * s, 24.0 * s, PI * 0.1, PI * 0.9, 16, hair.lightened(0.1), 12.0 * s)
	if talk:
		ci.draw_circle(c + Vector2(0, 15) * s, 6.0 * s, Color(0.35, 0.08, 0.08))
	else:
		ci.draw_line(c + Vector2(-7, 15) * s, c + Vector2(7, 15) * s, Color(0.4, 0.15, 0.12), 2.5 * s)
