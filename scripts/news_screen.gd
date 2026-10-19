extends Node2D
## Kymmenen uutiset videonauhalta (cutscene.gd news_tape): piirretään SubViewportiin ja näytetään telkkarin ruudulla.
## Vaiheet (seg): "play" (sininen VHS-ruutu ja ▶ PLAY), "tunnus" (uutisten alkutunnus), "studio" (uutistenlukija
## pöydän takana, alakolmanneksessa otsikko) ja "saa" (meteorologi ja Suomen kartta). Päällä aina VHS-viivat,
## nauhan aikakoodi ja välillä seurantahäiriö.

const MG := preload("res://scripts/mg_draw.gd")

const SIZE := Vector2(512, 320)
const ANCHOR := {"skin": Color(0.95, 0.78, 0.66), "hair": "parted", "hair_col": Color(0.3, 0.22, 0.14),
	"shirt": Color(0.16, 0.2, 0.32), "tie": true}
const WEATHER := {"skin": Color(0.93, 0.76, 0.64), "hair": "long", "hair_col": Color(0.75, 0.55, 0.25),
	"shirt": Color(0.75, 0.2, 0.25), "glasses": true}
## Suomen ääriviiva (0..1, y alas): lounaisrannikolta myötäpäivään Lapin käsivarren kautta takaisin.
const FINLAND := [Vector2(0.18, 0.92), Vector2(0.30, 0.97), Vector2(0.50, 0.94), Vector2(0.70, 0.90), Vector2(0.82, 0.84),
	Vector2(0.86, 0.72), Vector2(0.92, 0.60), Vector2(0.88, 0.48), Vector2(0.86, 0.36), Vector2(0.80, 0.25), Vector2(0.86, 0.13),
	Vector2(0.76, 0.02), Vector2(0.64, 0.07), Vector2(0.52, 0.13), Vector2(0.24, 0.02), Vector2(0.20, 0.06), Vector2(0.36, 0.17),
	Vector2(0.48, 0.25), Vector2(0.47, 0.36), Vector2(0.52, 0.43), Vector2(0.46, 0.50), Vector2(0.36, 0.56), Vector2(0.22, 0.62),
	Vector2(0.16, 0.70), Vector2(0.18, 0.80)]

var seg := "play"
var headline := ""
var talk := false
var _t := 0.0
var _seg_t := 0.0
var _last_seg := ""


func _process(delta: float) -> void:
	_t += delta
	_seg_t = 0.0 if seg != _last_seg else _seg_t + delta
	_last_seg = seg
	queue_redraw()


func _draw() -> void:
	match seg:
		"play":
			_draw_play()
		"tunnus":
			_draw_intro()
		"studio":
			_draw_studio()
		"saa":
			_draw_weather()
	_draw_vhs()


func _text(pos: Vector2, s: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, pos, s, align, width, size, 4, Color(0, 0, 0, 0.6))
	draw_string(f, pos, s, align, width, size, col)


## Videon oma sininen ruutu ennen kuvaa: PLAY ja nauhan laskuri.
func _draw_play() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.1, 0.2, 0.75))
	_text(Vector2(30, 60), "▶ PLAY", 40, Color.WHITE)
	_text(Vector2(30, 290), "SP", 26, Color.WHITE)
	_text(Vector2(0, 290), "0:00:0%d" % int(_seg_t), 26, Color.WHITE, SIZE.x - 30, HORIZONTAL_ALIGNMENT_RIGHT)


## Alkutunnus: tummansininen tausta, pyörivä maapallo ja otsikko.
func _draw_intro() -> void:
	MG.grad_rect(self, Rect2(Vector2.ZERO, SIZE), Color(0.05, 0.1, 0.3), Color(0.0, 0.02, 0.1))
	var c := Vector2(SIZE.x / 2.0, 135)
	for k in 6:
		draw_arc(c, 60 + k * 26 + fmod(_seg_t * 30.0, 26.0), 0, TAU, 48, Color(0.3, 0.55, 1.0, 0.18 - k * 0.025), 3.0)
	MG.ball(self, c, 58, Color(0.15, 0.45, 0.85), 0.4)
	for k in 5:  # pituuspiirit pyörivät
		var w := 58.0 * absf(cos(_seg_t * 1.2 + k * PI / 5.0))
		_ellipse(c, Vector2(w, 58), Color(0.7, 0.85, 1.0, 0.5))
	draw_line(c - Vector2(58, 0), c + Vector2(58, 0), Color(0.7, 0.85, 1.0, 0.5), 2.0)
	var a := clampf(_seg_t / 0.8, 0.0, 1.0)
	MG.box(self, Rect2(40, 210, SIZE.x - 80, 58), Color(0.85, 0.1, 0.12, a), 6, 4)
	_text(Vector2(40, 252), "KYMMENEN UUTISET", 38, Color(1, 1, 1, a), SIZE.x - 80, HORIZONTAL_ALIGNMENT_CENTER)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, 2.0, true)


## Studio: siniset taustapaneelit, kello, uutistenlukija pöydän takana ja otsikko alakolmanneksessa.
func _draw_studio() -> void:
	MG.grad_rect(self, Rect2(Vector2.ZERO, SIZE), Color(0.2, 0.32, 0.6), Color(0.06, 0.1, 0.25))
	for i in 5:  # taustan valopaneelit
		var r := Rect2(20 + i * 100, 30, 80, 150)
		MG.grad_rect(self, r, Color(0.35, 0.5, 0.85, 0.5), Color(0.15, 0.25, 0.55, 0.3))
		draw_rect(r, Color(0.6, 0.75, 1.0, 0.35), false, 2.0)
	# Taustan maapallo ja kello.
	MG.glow(self, Vector2(400, 95), 70, Color(0.5, 0.7, 1.0, 0.8))
	draw_circle(Vector2(400, 95), 44, Color(0.15, 0.35, 0.75))
	draw_arc(Vector2(400, 95), 44, 0, TAU, 40, Color(0.75, 0.9, 1.0, 0.7), 2.0)
	_ellipse(Vector2(400, 95), Vector2(18, 44), Color(0.75, 0.9, 1.0, 0.5))
	draw_line(Vector2(356, 95), Vector2(444, 95), Color(0.75, 0.9, 1.0, 0.5), 2.0)
	MG.box(self, Rect2(30, 40, 92, 34), Color(0.05, 0.08, 0.15, 0.85), 4)
	_text(Vector2(30, 66), "22.0%d" % mini(9, 2 + int(_seg_t / 8.0)), 24, Color(1.0, 0.85, 0.3), 92, HORIZONTAL_ALIGNMENT_CENTER)
	# Uutistenlukija: pää nyökkää puhuessa.
	var bob := sin(_t * 3.0) * 1.5 if talk else 0.0
	MG.person(self, Vector2(SIZE.x / 2.0, 118 + bob), 1.05, ANCHOR, Vector2(0, 0.2), talk and fmod(_t, 0.4) < 0.22)
	# Pöytä: kiiltävä pinta ja etulevy.
	var desk := Rect2(70, 196, SIZE.x - 140, 60)
	MG.solid(self, desk, Color(0.22, 0.28, 0.45))
	draw_rect(Rect2(desk.position, Vector2(desk.size.x, 6)), Color(0.75, 0.82, 0.95))
	draw_rect(Rect2(desk.position.x + 30, desk.position.y + 22, desk.size.x - 60, 4), Color(0.85, 0.1, 0.12))
	for k in 3:  # paperit pöydällä
		draw_rect(Rect2(SIZE.x / 2.0 - 40 + k * 4, 190 - k, 46, 8), Color(0.96, 0.96, 0.92).darkened(k * 0.05))
	# Alakolmannes: punainen palkki ja otsikko.
	if headline != "":
		var a := clampf(_seg_t / 0.5, 0.0, 1.0)
		var r := Rect2(lerpf(-SIZE.x, 0.0, a) + 16, 252, SIZE.x - 32, 44)
		MG.box(self, r, Color(0.95, 0.95, 0.97), 4, 3)
		MG.box(self, Rect2(r.position, Vector2(110, r.size.y)), Color(0.85, 0.1, 0.12), 4)
		_text(r.position + Vector2(0, 30), "UUTISET", 20, Color.WHITE, 110, HORIZONTAL_ALIGNMENT_CENTER)
		var f := ThemeDB.fallback_font
		draw_string(f, r.position + Vector2(122, 29), headline, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130, 19, Color(0.08, 0.1, 0.2))


## Säätiedotus: meri, Suomen kartta, sääsymbolit ja meteorologi osoittaa Pohjois-Pohjanmaata.
func _draw_weather() -> void:
	MG.grad_rect(self, Rect2(Vector2.ZERO, SIZE), Color(0.25, 0.5, 0.8), Color(0.12, 0.3, 0.6))
	for i in 9:  # meren aallot
		var y := 30.0 + i * 34.0
		draw_line(Vector2(0, y), Vector2(SIZE.x, y + 6), Color(0.4, 0.65, 0.95, 0.25), 2.0)
	var box := Rect2(250, 14, 190, 292)
	var pts := PackedVector2Array()
	for p in FINLAND:
		pts.append(box.position + p * box.size)
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(5, 6))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.25))
	draw_colored_polygon(pts, Color(0.45, 0.72, 0.35))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.95, 0.95, 0.85), 3.0, true)
	draw_polyline(pts, Color(0.12, 0.25, 0.1, 0.7), 1.0, true)
	# Sääsymbolit: Helsinki aurinko, Saloinen sadepilvi, Lappi pilvinen.
	_sun(box.position + Vector2(0.5, 0.86) * box.size, 18.0)
	_cloud(box.position + Vector2(0.46, 0.48) * box.size, 1.0, true)
	_cloud(box.position + Vector2(0.62, 0.16) * box.size, 0.8, false)
	_temp(box.position + Vector2(0.62, 0.84) * box.size, "+17")
	_temp(box.position + Vector2(0.62, 0.48) * box.size, "+12")
	_temp(box.position + Vector2(0.78, 0.14) * box.size, "+8")
	var salo := box.position + Vector2(0.43, 0.52) * box.size
	draw_circle(salo, 4.0, Color(0.95, 0.2, 0.2))
	_text(salo + Vector2(-92, 18), "Saloinen", 16, Color.WHITE)
	# Meteorologi vasemmalla, käsi kohti Saloisia.
	MG.person(self, Vector2(130, 150), 1.1, WEATHER, Vector2(0.8, 0), talk and fmod(_t, 0.4) < 0.22, 0.35)
	MG.box(self, Rect2(16, 262, 200, 40), Color(0.05, 0.1, 0.25, 0.85), 4)
	_text(Vector2(16, 290), "SÄÄ  ·  HUOMENNA", 20, Color(1.0, 0.85, 0.3), 200, HORIZONTAL_ALIGNMENT_CENTER)


func _sun(c: Vector2, r: float) -> void:
	for k in 8:
		var a := TAU * k / 8.0 + _t * 0.5
		draw_line(c + Vector2(cos(a), sin(a)) * (r + 4), c + Vector2(cos(a), sin(a)) * (r + 12), Color(1.0, 0.8, 0.1), 4.0)
	MG.ball(self, c, r, Color(1.0, 0.82, 0.15), 0.4)


func _cloud(c: Vector2, s: float, rain: bool) -> void:
	if rain:
		for k in 4:
			var x := c.x - 18 * s + k * 12 * s
			var y := c.y + 14 * s + fmod(_t * 40.0 + k * 9.0, 18.0) * s
			draw_line(Vector2(x, y), Vector2(x - 3 * s, y + 8 * s), Color(0.25, 0.45, 1.0), 3.0)
	for b in [[Vector2(-14, 2), 13.0], [Vector2(0, -6), 17.0], [Vector2(15, 2), 12.0]]:
		draw_circle(c + b[0] * s + Vector2(2, 3), b[1] * s, Color(0, 0, 0, 0.2))
	for b in [[Vector2(-14, 2), 13.0], [Vector2(0, -6), 17.0], [Vector2(15, 2), 12.0]]:
		draw_circle(c + b[0] * s, b[1] * s, Color(0.72, 0.75, 0.8) if rain else Color(0.92, 0.93, 0.95))
	draw_rect(Rect2(c + Vector2(-26, 2) * s, Vector2(52, 12) * s), Color(0.72, 0.75, 0.8) if rain else Color(0.92, 0.93, 0.95))


func _temp(p: Vector2, s: String) -> void:
	MG.box(self, Rect2(p + Vector2(-2, -20), Vector2(44, 26)), Color(0.05, 0.1, 0.25, 0.8), 5)
	_text(p + Vector2(-2, 0), s, 20, Color.WHITE, 44, HORIZONTAL_ALIGNMENT_CENTER)


## VHS: vaakaviivat, värin vuoto reunoilla, aikakoodi ja välillä alareunan seurantahäiriö.
func _draw_vhs() -> void:
	for y in range(0, int(SIZE.y), 3):
		draw_line(Vector2(0, y), Vector2(SIZE.x, y), Color(0, 0, 0, 0.12), 1.0)
	if seg != "play":
		_text(Vector2(14, 30), "▶", 22, Color(1, 1, 1, 0.75))
	var band := fmod(_t * 0.35, 1.6)
	if band < 1.0:  # seurantahäiriö rullaa alhaalta ylös
		var y := SIZE.y * (1.0 - band)
		for i in 26:
			var x := fmod(i * 97.3 + _t * 700.0, SIZE.x)
			draw_line(Vector2(x, y + fmod(i * 7.0, 10.0)), Vector2(x + 18 + fmod(i * 13.0, 30.0), y + fmod(i * 7.0, 10.0)),
				Color(1, 1, 1, 0.35), 1.5)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0.5), false, 6.0)
