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

# --- Vihko (päiväkirja ja reppu) ---------------------------------------------------------------------------------
## Nahkakantinen kierrevihko: kansi, kaksi viivapaperista sivua punaisine marginaaleineen, kierrerenkaat ja tahrat.
## Sama kirja piirretään päiväkirjassa (journal.gd) ja repussa (inventory.gd), jotta ne näyttävät samalta.
const PAPER := Color(0.97, 0.94, 0.85)
const LINE := Color(0.62, 0.72, 0.85, 0.55)
const MARGIN := Color(0.85, 0.35, 0.35, 0.6)
const NOTE_INK := Color(0.14, 0.17, 0.4)
const LEATHER := Color(0.36, 0.2, 0.12)


static func notebook_rect(size: Vector2) -> Rect2:
	var w := minf(1080.0, size.x - 80.0)
	var h := minf(660.0, size.y - 120.0)
	return Rect2((size - Vector2(w, h)) / 2.0, Vector2(w, h))


static func notebook_page(book: Rect2, right: bool) -> Rect2:
	var half := (book.size.x - 40) / 2.0
	return Rect2(book.position + Vector2(20 + (half if right else 0.0), 18), Vector2(half, book.size.y - 36))


static func notebook(ci: CanvasItem, book: Rect2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, ci.get_viewport_rect().size), Color(0, 0, 0, 0.72))
	box(ci, book.grow(14), LEATHER, 18, 16)
	box(ci, book.grow(6), LEATHER.darkened(0.25), 14)
	ci.draw_arc(book.position + Vector2(book.size.x - 60, book.size.y - 4), 30.0, PI * 1.1, PI * 1.9, 24, Color(0.15, 0.08, 0.04, 0.5), 3.0)
	for side in [false, true]:
		var pg := notebook_page(book, side)
		box(ci, pg, PAPER, 6)
		for y in range(int(pg.position.y) + 70, int(pg.end.y) - 10, 30):
			ci.draw_line(Vector2(pg.position.x + 10, y), Vector2(pg.end.x - 10, y), LINE, 1.0)
		ci.draw_line(Vector2(pg.position.x + 46, pg.position.y + 6), Vector2(pg.position.x + 46, pg.end.y - 6), MARGIN, 1.5)
		page_stains(ci, pg, 7 if side else 3)
	var mid := book.position.x + book.size.x / 2.0
	for y in range(int(book.position.y) + 30, int(book.end.y) - 20, 34):
		ball(ci, Vector2(mid, y), 8.0, Color(0.7, 0.7, 0.74), 0.6)


## Välilehti kirjan oikeassa reunassa (teksti pystyyn).
static func notebook_tab(ci: CanvasItem, r: Rect2, col: Color, text: String, on: bool, hover: bool) -> void:
	box(ci, r.grow(2.0 if on or hover else 0.0), col if on else col.darkened(0.25), 8, 4)
	ci.draw_set_transform(r.get_center(), PI / 2.0)
	ci.draw_string(ThemeDB.fallback_font, Vector2(-40, 6), text.left(9), HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO)


static func notebook_tab_rect(book: Rect2, i: int) -> Rect2:
	return Rect2(Vector2(book.end.x - 6, book.position.y + 40 + i * 92), Vector2(54, 84))


## Otsikkokyltin sijainti kannessa (MG.sign(ci, notebook_title_rect(...), teksti, TITLE_BG, TITLE_FG, 22, TITLE_BORDER)).
const TITLE_BG := Color(0.92, 0.85, 0.65)
const TITLE_FG := Color(0.35, 0.18, 0.08)
const TITLE_BORDER := Color(0.55, 0.4, 0.2)


static func notebook_title_rect(book: Rect2, width := 340.0) -> Rect2:
	return Rect2(Vector2(book.get_center().x - width / 2.0, book.position.y - 34), Vector2(width, 40))


static func page_stains(ci: CanvasItem, pg: Rect2, seed_i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var at := func(fx: float, fy: float) -> Vector2:
		return pg.position + Vector2(pg.size.x * fx, pg.size.y * fy)
	# Kahvikupin rengas: epätasainen ruskea kehä, sisältä vaaleampi, yksi valuma.
	for k in 2 if seed_i == 3 else 1:
		var c: Vector2 = at.call(rng.randf_range(0.55, 0.85), rng.randf_range(0.15, 0.75))
		var r := rng.randf_range(38.0, 50.0)
		ci.draw_circle(c, r, Color(0.55, 0.35, 0.15, 0.06))
		for ring in 3:
			var a0 := rng.randf() * TAU
			ci.draw_arc(c, r - ring * 1.8, a0, a0 + TAU * rng.randf_range(0.7, 1.0), 48,
				Color(0.45, 0.27, 0.1, 0.28 - ring * 0.07), 3.0 - ring * 0.6, true)
		var drip := c + Vector2(cos(1.1), sin(1.1)) * r
		ci.draw_line(drip, drip + Vector2(rng.randf_range(-4, 4), rng.randf_range(10, 22)), Color(0.45, 0.27, 0.1, 0.22), 3.0)
	# Oluttahra: kellertävä läikkä tummemmin reunoin ja pieniä roiskeita.
	var bc: Vector2 = at.call(rng.randf_range(0.2, 0.5), rng.randf_range(0.55, 0.85))
	var blob := PackedVector2Array()
	var radii: Array = []
	for k in 18:
		radii.append(rng.randf_range(26.0, 44.0))
	for k in 18:
		var a := k * TAU / 18.0
		blob.append(bc + Vector2(cos(a), sin(a) * 0.75) * radii[k])
	ci.draw_colored_polygon(blob, Color(0.85, 0.62, 0.15, 0.13))
	blob.append(blob[0])
	ci.draw_polyline(blob, Color(0.7, 0.45, 0.1, 0.25), 2.0, true)
	for k in 7:
		var a := rng.randf() * TAU
		ci.draw_circle(bc + Vector2(cos(a), sin(a)) * rng.randf_range(50.0, 85.0), rng.randf_range(2.0, 5.0), Color(0.8, 0.55, 0.12, 0.2))
	# Makkaran rasvatäplä: läpikuultava tumma täplä paperissa.
	if seed_i == 7:
		var gc: Vector2 = at.call(0.3, 0.2)
		ci.draw_circle(gc, 18.0, Color(0.6, 0.5, 0.3, 0.12))
		ci.draw_circle(gc + Vector2(6, 4), 10.0, Color(0.55, 0.45, 0.25, 0.1))
	# Sinappiroiske sivun kulmassa.
	if seed_i == 3:
		var mc: Vector2 = at.call(0.88, 0.9)
		ci.draw_circle(mc, 7.0, Color(0.85, 0.7, 0.1, 0.35))
		ci.draw_line(mc, mc + Vector2(-18, -6), Color(0.85, 0.7, 0.1, 0.3), 3.0)


# --- Sarjakuvahahmo vyötäröstä ylöspäin (kolmiomittauksen kohtaukset ja Sytkäri) ---------------------------------
## Kunnollinen hahmo: kasvonmuoto leukoineen, kaula, hartiat ja vartalo sävytettynä (naisilla rinnat ja tiimalasi),
## kädet sormineen, hiukset tyylin mukaan pään takana ja edessä, silmät, kulmat, nenä ja suu. c = pään keskipiste,
## s = mittakaava (pää n. 60 px korkea, kun s = 1). look: skin, shirt, hair ("short", "parted", "long", "curls",
## "metal", "buns"), hair_col, woman, bust (0..3), curves (0..1), beard, glasses, cap, freckles, eyes (iiriksen väri),
## jacket (nahkatakki), dress (olkaimellinen mekko), stripes (tuulipuku), tie, flannel, pants, shoes. opts: talk, eye
## (katse -1..1), arms ("down", "hold" = kädet edessä rinnan alla, "wave" = oikea käsi ylhäällä), blink, legs (true = koko
## hahmo jalkoineen; muuten kuva rajautuu lantiolle).
static func figure(ci: CanvasItem, c: Vector2, s: float, look: Dictionary, opts := {}) -> void:
	var skin: Color = look.get("skin", Color(0.98, 0.82, 0.72))
	var shirt: Color = look.get("shirt", Color(0.3, 0.4, 0.6))
	var hair: Color = look.get("hair_col", Color(0.35, 0.25, 0.15))
	var style: String = look.get("hair", "short")
	var woman: bool = look.get("woman", false)
	var bust: float = look.get("bust", 0.0)
	var curves: float = look.get("curves", 0.0)
	var arms: String = opts.get("arms", "down")
	var talk: bool = opts.get("talk", false)
	var eye: Vector2 = opts.get("eye", Vector2.ZERO)
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * s
	var line_w := maxf(1.2, 2.0 * s)
	# 1. Pitkät hiukset pään ja hartioiden taakse.
	match style:
		"long", "metal":
			var hl := 118.0 if style == "metal" else 104.0
			var back := PackedVector2Array([P.call(-30, -18), P.call(30, -18), P.call(38, 30), P.call(42, hl - 10), P.call(30, hl),
				P.call(-30, hl), P.call(-42, hl - 10), P.call(-38, 30)])
			ci.draw_colored_polygon(back, hair.darkened(0.25))
			back.append(back[0])
			ci.draw_polyline(back, OUTLINE, line_w, true)
		"curls":
			for i in 34:  # olkapäille valuvat kiharat pään takana, eivät leveämmälle kuin hartiat
				var side := -1.0 if i % 2 == 0 else 1.0
				var fall := fmod(i * 0.381, 1.0)
				var p: Vector2 = P.call(side * (24.0 + 9.0 * fmod(i * 0.618, 1.0)), -6.0 + fall * 56.0)
				_curl(ci, p, 7.0 * s, hair.darkened(0.12 + 0.1 * fmod(i * 0.53, 1.0)))
	# 1b. Jalat (koko hahmo): housut tai mekon helma ja paljaat sääret, kengät.
	if opts.get("legs", false):
		var pants: Color = look.get("pants", Color(0.2, 0.25, 0.4))
		var shoes: Color = look.get("shoes", Color(0.12, 0.1, 0.1))
		var dress: bool = look.get("dress", false)
		for sx in [-1.0, 1.0]:
			var leg := PackedVector2Array([P.call(sx * 3, 136), P.call(sx * 34, 136), P.call(sx * 26, 214), P.call(sx * 22, 268),
				P.call(sx * 8, 268), P.call(sx * 6, 214)])
			ci.draw_colored_polygon(leg, skin if dress else pants)
			if not dress:
				ci.draw_line(P.call(sx * 18, 150), P.call(sx * 15, 262), pants.lightened(0.12), 3.0 * s)
			leg.append(leg[0])
			ci.draw_polyline(leg, OUTLINE, line_w, true)
			var shoe := PackedVector2Array([P.call(sx * 6, 264), P.call(sx * 24, 264), P.call(sx * 30, 276), P.call(sx * 4, 278)])
			ci.draw_colored_polygon(shoe, shoes)
			shoe.append(shoe[0])
			ci.draw_polyline(shoe, OUTLINE, line_w, true)
		if dress:  # helma polviin, laskokset
			var cloth_d: Color = look.get("shirt", Color.WHITE)
			var hem := PackedVector2Array([P.call(-wt_for(woman, curves), 112), P.call(wt_for(woman, curves), 112), P.call(50, 200),
				P.call(-50, 200)])
			ci.draw_colored_polygon(hem, cloth_d.darkened(0.08))
			for k in 5:
				ci.draw_line(P.call(-20 + k * 10, 120), P.call(-36 + k * 18, 198), cloth_d.darkened(0.22), 1.5 * s)
			hem.append(hem[0])
			ci.draw_polyline(hem, OUTLINE, line_w, true)
	# 2. Vartalo: kaulan tyvestä hartioihin, vyötärö (naisilla kapeampi) ja lantio kuvan alareunaan.
	var wt := wt_for(woman, curves)
	var hp := 38.0 + (8.0 * curves if woman else 0.0)
	var sh := 42.0 if not woman else 36.0
	var torso := PackedVector2Array([P.call(-11, 26), P.call(11, 26), P.call(sh - 6, 34), P.call(sh, 46), P.call(sh - 2, 74),
		P.call(wt, 112), P.call(hp, 140), P.call(-hp, 140), P.call(-wt, 112), P.call(-(sh - 2), 74), P.call(-sh, 46), P.call(-(sh - 6), 34)])
	var cloth := shirt
	var cols := PackedColorArray()
	for q in torso:
		var t := clampf(((q - c) / s).y / 140.0, 0.0, 1.0)
		cols.append(cloth.lightened(0.18 * (1.0 - t)).darkened(0.22 * t))
	ci.draw_polygon(torso, cols)
	if look.get("dress", false) or look.get("tube", false):
		# Paljas kaula-aukko ja olkapäät, ohuet olkaimet.
		var neck_skin := PackedVector2Array([P.call(-11, 26), P.call(11, 26), P.call(sh - 6, 34), P.call(sh, 46), P.call(sh - 3, 60),
			P.call(16, 64), P.call(0, 70), P.call(-16, 64), P.call(-(sh - 3), 60), P.call(-sh, 46), P.call(-(sh - 6), 34)])
		ci.draw_colored_polygon(neck_skin, skin)
		for sx in [-1.0, 1.0]:
			ci.draw_line(P.call(sx * 20, 64), P.call(sx * 26, 34), cloth.darkened(0.1), 3.5 * s)
	if woman and bust > 0.0:
		# Rinnat: kaksi pyöreää muotoa, valo ylhäältä, varjokaari alla ja keskellä uurre.
		var br := 9.0 + 4.0 * bust
		for sx in [-1.0, 1.0]:
			var bc: Vector2 = P.call(sx * (6.0 + br * 0.75), 70 + br * 0.35)
			ci.draw_circle(bc, br * s, cloth.lightened(0.05))
			ci.draw_circle(bc + Vector2(-sx * 2.0, -br * 0.35) * s, br * 0.45 * s, cloth.lightened(0.2))
			ci.draw_arc(bc, br * s, PI * 0.15, PI * 0.85, 12, cloth.darkened(0.35), 2.5 * s)
			if look.get("dress", false) or look.get("tube", false):
				ci.draw_arc(bc, br * s, PI * 1.15, PI * 1.85, 12, skin.darkened(0.08), 2.0 * s)
		ci.draw_line(P.call(0, 62 + br * 0.2), P.call(0, 72 + br * 0.5), skin.darkened(0.2), 1.5 * s)
	if look.get("flannel", false):
		for k in 6:
			ci.draw_line(P.call(-sh, 50 + k * 15), P.call(sh, 50 + k * 15), cloth.darkened(0.3), 2.5 * s)
			ci.draw_line(P.call(-30 + k * 12, 34), P.call(-30 + k * 12, 140), cloth.darkened(0.2), 2.0 * s)
	if look.get("stripes", false):
		ci.draw_line(P.call(-sh + 4, 60), P.call(sh - 4, 100), Color(0.08, 0.66, 0.64), 9.0 * s)
		ci.draw_line(P.call(-sh + 4, 72), P.call(sh - 4, 112), Color(0.07, 0.07, 0.09), 5.0 * s)
	if look.get("jacket", false):
		var lining := Color(0.75, 0.72, 0.7)
		ci.draw_colored_polygon(PackedVector2Array([P.call(-11, 28), P.call(11, 28), P.call(7, 140), P.call(-7, 140)]), lining)
		for sx in [-1.0, 1.0]:
			ci.draw_colored_polygon(PackedVector2Array([P.call(sx * 10, 28), P.call(sx * 26, 36), P.call(sx * 12, 82)]), cloth.lightened(0.12))
			ci.draw_line(P.call(sx * 30, 52), P.call(sx * 32, 128), Color(1, 1, 1, 0.22), 3.0 * s)  # nahan kiilto
		ci.draw_line(P.call(7, 80), P.call(7, 140), Color(0.78, 0.78, 0.8), 2.0 * s)  # vetoketju
	if look.get("tie", false):
		ci.draw_colored_polygon(PackedVector2Array([P.call(-4, 28), P.call(4, 28), P.call(6, 86), P.call(0, 94), P.call(-6, 86)]),
			Color(0.65, 0.1, 0.12))
	var tl := torso.duplicate()
	tl.append(tl[0])
	ci.draw_polyline(tl, OUTLINE, line_w, true)
	# 3. Kädet: olkavarsi, kyynärvarsi ja käsi sormineen. Hihat paidan väriset (mekossa ja topissa paljas käsi).
	var bare: bool = look.get("dress", false) or look.get("tube", false)
	for sx in [-1.0, 1.0]:
		var sho: Vector2 = P.call(sx * (sh - 2), 46)
		var elb: Vector2 = P.call(sx * (sh + 8), 92)
		var hand: Vector2 = P.call(sx * (sh + 6), 136)
		if arms == "hold":
			hand = P.call(sx * 12, 112)
		elif arms == "wave" and sx > 0.0:
			elb = P.call(sh + 22, 34)
			hand = P.call(sh + 26, -12)
		var sleeve := skin if bare else cloth.darkened(0.06)
		_limb(ci, sho, elb, 15.0 * s, sleeve, line_w)
		_limb(ci, elb, hand, 13.0 * s, skin if bare or look.get("short_sleeve", false) else sleeve, line_w)
		_hand(ci, hand, (hand - elb).normalized(), 7.5 * s, skin, line_w)
	# 4. Kaula ja pää: kasvonmuoto leuka kapenevana, korvat, varjo leuan alla.
	ci.draw_colored_polygon(PackedVector2Array([P.call(-9, 14), P.call(9, 14), P.call(10, 30), P.call(-10, 30)]), skin.darkened(0.12))
	var face := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var x := sin(a) * 27.0
		var y := -cos(a) * 31.0
		if y > 0.0:  # alapuolella leuka kapenee
			x *= 1.0 - 0.32 * (y / 31.0) * (y / 31.0)
			y *= 1.0 + (0.06 if woman else 0.1)
		face.append(P.call(x, y))
	for sx in [-1.0, 1.0]:
		ci.draw_circle(P.call(sx * 27, 2), 6.0 * s, skin.darkened(0.1))
		ci.draw_arc(P.call(sx * 27, 2), 6.0 * s, PI * 0.5 - sx * PI * 0.5, PI * 1.5 - sx * PI * 0.5, 8, OUTLINE, line_w * 0.8)
	ci.draw_colored_polygon(face, skin)
	ci.draw_colored_polygon(PackedVector2Array([P.call(8, -28), P.call(27, -4), P.call(22, 18), P.call(8, 31), P.call(14, 4)]),
		Color(skin.darkened(0.12), 0.5))  # varjopuoli
	var fl := face.duplicate()
	fl.append(fl[0])
	ci.draw_polyline(fl, OUTLINE, line_w, true)
	# 5. Hiukset pään päällä.
	match style:
		"short":
			_hair_cap(ci, P, s, hair, -12.0, line_w)
		"parted":
			_hair_cap(ci, P, s, hair, -6.0, line_w)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-26, -16), P.call(-4, -32), P.call(14, -30), P.call(-10, -20)]), hair.lightened(0.08))
			ci.draw_line(P.call(-6, -33), P.call(-12, -22), skin.darkened(0.05), 2.0 * s)
		"long", "metal":
			_hair_cap(ci, P, s, hair, -4.0, line_w)
			for sx in [-1.0, 1.0]:  # suorat suortuvat kasvojen sivuilla hartioille
				var strand := PackedVector2Array([P.call(sx * 22, -22), P.call(sx * 31, -10), P.call(sx * 34, 40), P.call(sx * 30, 58),
					P.call(sx * 21, 48), P.call(sx * 22, 4)])
				ci.draw_colored_polygon(strand, hair)
				for k in 3:
					ci.draw_line(P.call(sx * (24 + k * 3), -6), P.call(sx * (25 + k * 3), 46), hair.lightened(0.12), 1.2 * s)
			if style == "long":  # otsatukka sivulle
				ci.draw_colored_polygon(PackedVector2Array([P.call(-26, -10), P.call(-10, -31), P.call(16, -28), P.call(-4, -18)]), hair.lightened(0.05))
		"curls":
			for i in 22:
				var a := PI * 1.0 + PI * 1.0 * i / 21.0
				_curl(ci, c + Vector2(cos(a) * 29.0, sin(a) * 31.0 - 2.0) * s, 9.0 * s, hair.darkened(0.08 * (i % 3)))
			for i in 7:
				_curl(ci, P.call(-18 + i * 6, -24 + absf(i - 3.0) * 1.5), 7.0 * s, hair.lightened(0.05))
		"buns":
			_hair_cap(ci, P, s, hair, -12.0, line_w)
			ci.draw_circle(P.call(0, -36), 12.0 * s, hair)
			ci.draw_arc(P.call(0, -36), 12.0 * s, 0, TAU, 16, OUTLINE, line_w)
	# 6. Kasvot.
	var blink: bool = opts.get("blink", false)
	for sx in [-1.0, 1.0]:
		var e: Vector2 = P.call(sx * 10.5, -3)
		if blink:
			ci.draw_arc(e, 5.0 * s, PI * 0.15, PI * 0.85, 8, OUTLINE, 2.0 * s)
		else:
			var almond := PackedVector2Array()
			for i in 12:
				var a := TAU * i / 12.0
				almond.append(e + Vector2(cos(a) * 6.5, sin(a) * (3.6 if a < PI else 4.4)) * s)
			ci.draw_colored_polygon(almond, Color(0.98, 0.97, 0.95))
			ci.draw_circle(e + eye * 2.0 * s, 3.2 * s, look.get("eyes", Color(0.32, 0.22, 0.14)))
			ci.draw_circle(e + eye * 2.0 * s, 1.6 * s, Color(0.05, 0.04, 0.04))
			ci.draw_circle(e + eye * 2.0 * s + Vector2(-1.0, -1.0) * s, 0.9 * s, Color.WHITE)
			almond.append(almond[0])
			ci.draw_polyline(almond, OUTLINE, 1.2 * s, true)
			if woman:  # ripset ja luomiväri
				ci.draw_arc(e, 6.8 * s, PI * 1.1, PI * 1.9, 8, Color(0.05, 0.04, 0.05), 2.4 * s)
				ci.draw_line(e + Vector2(sx * 6.5, -1.5) * s, e + Vector2(sx * 9.0, -3.5) * s, Color(0.05, 0.04, 0.05), 1.6 * s)
		var brow_col := hair.darkened(0.35) if style != "buns" else Color(0.55, 0.52, 0.5)
		ci.draw_line(e + Vector2(-6.5, -8.0 + (1.0 if sx > 0 else 0.0)) * s, e + Vector2(6.5, -9.0 - (0.0 if sx > 0 else 1.0)) * s,
			brow_col, (2.0 if woman else 3.2) * s)
	ci.draw_line(P.call(0, -2), P.call(-3, 10), skin.darkened(0.3), 1.8 * s)  # nenä
	ci.draw_arc(P.call(-1, 11), 3.0 * s, PI * 0.1, PI * 0.9, 6, skin.darkened(0.3), 1.6 * s)
	if look.get("freckles", false):
		for i in 16:  # pisamat poskilla ja nenänvarressa, satunnaisesti mutta joka kerta samoin
			var sx2 := -1.0 if i % 2 == 0 else 1.0
			ci.draw_circle(P.call(sx2 * (5.0 + fmod(i * 5.3, 13.0)), 3.0 + fmod(i * 3.7, 9.0)), 0.9 * s, Color(0.78, 0.48, 0.32, 0.85))
	if woman:
		for sx in [-1.0, 1.0]:
			ci.draw_circle(P.call(sx * 15, 10), 5.0 * s, Color(1.0, 0.5, 0.5, 0.22))  # posket
	var lip := Color(0.82, 0.12, 0.2) if woman else skin.darkened(0.35)
	if talk:
		ci.draw_colored_polygon(PackedVector2Array([P.call(-7, 18), P.call(7, 18), P.call(5, 24), P.call(0, 26), P.call(-5, 24)]),
			Color(0.35, 0.06, 0.08))
		ci.draw_line(P.call(-5, 19), P.call(5, 19), Color(0.97, 0.95, 0.9), 2.0 * s)  # hampaat
		ci.draw_polyline(PackedVector2Array([P.call(-7, 18), P.call(0, 16.5), P.call(7, 18)]), lip, 2.5 * s, true)
	else:
		ci.draw_arc(P.call(0, 13), 8.0 * s, PI * 0.2, PI * 0.8, 10, lip, (3.0 if woman else 2.2) * s)
	if look.get("beard", false):
		var bd := PackedVector2Array([P.call(-24, 8), P.call(-18, 24), P.call(-8, 34), P.call(0, 36), P.call(8, 34), P.call(18, 24),
			P.call(24, 8), P.call(16, 18), P.call(8, 23), P.call(-8, 23), P.call(-16, 18)])
		ci.draw_colored_polygon(bd, hair.lightened(0.18))
		for k in 7:
			ci.draw_line(P.call(-15 + k * 5, 24), P.call(-15 + k * 5, 31), hair.darkened(0.2), 1.0 * s)
		ci.draw_line(P.call(-8, 15), P.call(8, 15), hair.darkened(0.1), 3.0 * s)  # viikset
	if look.get("glasses", false):
		for sx in [-1.0, 1.0]:
			ci.draw_arc(P.call(sx * 10.5, -3), 8.0 * s, 0, TAU, 16, Color(0.2, 0.2, 0.22), 1.8 * s)
		ci.draw_line(P.call(-2.5, -4), P.call(2.5, -4), Color(0.2, 0.2, 0.22), 1.8 * s)
	if look.get("cap", false):
		var capc: Color = look.get("cap_col", Color(0.06, 0.06, 0.08))
		ci.draw_colored_polygon(PackedVector2Array([P.call(-28, -12), P.call(-24, -28), P.call(0, -36), P.call(24, -28), P.call(28, -12)]), capc)
		ci.draw_colored_polygon(PackedVector2Array([P.call(-6, -14), P.call(40, -14), P.call(42, -9), P.call(-6, -9)]), capc.darkened(0.2))
		ci.draw_line(P.call(-28, -12), P.call(28, -12), Color(1.0, 0.82, 0.1), 1.5 * s)


## Vyötärön puolileveys: naisilla tiimalasi kaventaa.
static func wt_for(woman: bool, curves: float) -> float:
	return 34.0 - (8.0 * curves if woman else 0.0)


## Raaja paksuna viivana ääriviivoineen ja pyöreine niveliin (kyynärpää, olkapää).
static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color, lw: float) -> void:
	ci.draw_line(a, b, OUTLINE, w + lw * 2.0)
	ci.draw_circle(b, (w + lw * 2.0) / 2.0, OUTLINE)
	ci.draw_line(a, b, col, w)
	ci.draw_circle(a, w / 2.0, col)
	ci.draw_circle(b, w / 2.0, col)
	ci.draw_line(a + (b - a).orthogonal().normalized() * w * 0.25, b + (b - a).orthogonal().normalized() * w * 0.25, col.lightened(0.15), w * 0.25)


## Käsi: kämmen, neljä sormea ranteen jatkeena ja peukalo.
static func _hand(ci: CanvasItem, at: Vector2, dir: Vector2, r: float, skin: Color, lw: float) -> void:
	var side := dir.orthogonal()
	ci.draw_circle(at, r + lw, OUTLINE)
	ci.draw_circle(at, r, skin)
	for k in 4:
		var base := at + dir * r * 0.6 + side * (k - 1.5) * r * 0.42
		ci.draw_line(base, base + dir * r * (0.75 + 0.15 * (1.0 - absf(k - 1.5) / 1.5)), OUTLINE, r * 0.42 + lw)
		ci.draw_line(base, base + dir * r * (0.75 + 0.15 * (1.0 - absf(k - 1.5) / 1.5)), skin, r * 0.32)
	ci.draw_line(at + side * r * 0.7, at + side * r * 1.2 + dir * r * 0.3, OUTLINE, r * 0.45 + lw)
	ci.draw_line(at + side * r * 0.7, at + side * r * 1.2 + dir * r * 0.3, skin, r * 0.36)


## Hiuskalotti pään yläosaan: otsaraja y = hairline (pään keskipisteestä), ääriviiva ja kiilto.
static func _hair_cap(ci: CanvasItem, P: Callable, s: float, hair: Color, hairline: float, lw: float) -> void:
	var cap := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		cap.append(P.call(cos(a) * 29.0, sin(a) * 34.0))
	cap.append(P.call(27, hairline + 6))
	cap.append(P.call(14, hairline))
	cap.append(P.call(-14, hairline))
	cap.append(P.call(-27, hairline + 6))
	ci.draw_colored_polygon(cap, hair)
	cap.append(cap[0])
	ci.draw_polyline(cap, OUTLINE, lw, true)
	ci.draw_arc(P.call(-6, -14), 16.0 * s, PI * 1.2, PI * 1.6, 8, hair.lightened(0.25), 2.5 * s)


## Kihara: pyöreä rengas, tumma spiraali sisällä ja vaalea kiilto.
static func _curl(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(p, r + 1.0, OUTLINE.lerp(col, 0.4))
	ci.draw_circle(p, r, col)
	ci.draw_arc(p, r * 0.55, 0.0, PI * 1.5, 8, col.darkened(0.3), maxf(1.0, r * 0.22))
	ci.draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.22, col.lightened(0.3))
