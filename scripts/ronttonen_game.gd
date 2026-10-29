extends CanvasLayer
## Rönttösten leivonta mökin keittiössä (Kainuun rönttönen), hiirellä pelattavat vaiheet piirrettyinä kuvina:
## "kaulinta" – ruistaikina ohueksi: vedä kaulinta hiiri pohjassa pystyyn ja vaakaan, soikio kasvaa.
## "tayte"   – ota lusikalla perunamuusia kulhosta ja kasaa 4 kekoa taikinan keskelle, sitten 3 lusikallista puolukkaa päälle.
## "nypyt"   – reunan poimutus: klikkaa taikinan reunan renkaita yksitellen (kaikki 18), reuna nousee poimuille.
## Valmis rönttönen on avoin soikea: täyte näkyy ja reuna on poimuinen. F / Esc keskeyttää (vaiheen saa tehdä uudestaan).
## finished(ok) kertoo, valmistuiko rönttönen. Humalassa kursori huojuu.

const MG := preload("res://scripts/mg_draw.gd")
const B := preload("res://scripts/build.gd")

signal finished(ok: bool)
signal comment(text: String)

const DOUGH_MIN := Vector2(55, 40)  # taikinapallon koko kaulinnan alussa
const DOUGH_MAX := Vector2(250, 150)  # ohueksi kaulittu soikio (puoliakselit, px)
const FILL := Vector2(150, 75)  # täytealue (puoliakselit), pysyy poimutetun reunan sisällä
const MUUSI_N := 4
const BERRY_N := 3
const PLEATS := 18
const PLEAT_ELL := Vector2(212, 120)  # poimujen renkaat taikinan reunalla
const PLEAT_R := 30.0
const DOUGH := Color(0.62, 0.46, 0.28)  # ruistaikina
const BAKED := Color(0.8, 0.54, 0.26)
const LINES := {
	"kaulinta": ["Ruisjauhoa pöytään, ettei tartu.", "Ohueksi, ohueksi. Mummon ohje: läpi pitää näkyä pöytä."],
	"tayte": ["Muusi ensin, puolukka päälle.", "Perunamuusia keskelle, ei reunoille."],
	"nypyt": ["Reuna ylös ja nyppy nyppyyn.", "Sormella poimua jokaiseen kohtaan."],
	"ohi": ["Keskelle, ei pöydälle!", "Taikinan päälle se täyte kuuluu."],
	"jarjestys": ["Muusi ensin. Puolukka tulee päälle.", "Ei puolukkaa ennen muusia."],
	"valmis": ["Tulipa komeita. Uuniin vaan.", "Kainuulainen rönttönen, ei muuta."],
}

var mode := "kaulinta"  # aloitusvaihe; kaikki kolme tehdään peräkkäin
var drunk := 0.0

var _root: Control
var _info: Label
var _keys: Control
var _tip: Label
var _done := false
var _t := 0.0
var _mouse := Vector2.ZERO
var _raw := Vector2.ZERO
var _lmb := false
var _area := Rect2()
var _center := Vector2.ZERO
var _sparks: Array = []  # jauhopöly ja roiskeet (MG.sparks_*)
var _shake := 0.0
var _fin_t := 0.0  # valmis-näytön aika
# kaulinta
var _px := 0.0  # vaakasuuntainen kaulinta 0..1
var _py := 0.0
var _pin_h := true  # kaulin vaakana (pystyvedot)
# täyte
var _held := ""  # "", "muusi", "puolukka"
var _muusi: Array = []  # keon paikka (suhteessa keskukseen)
var _berries: Array = []  # {p, c}
# nyppy
var _pleats: Array = []  # bool per renkaan paikka


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	_root.gui_input.connect(_gui)
	add_child(_root)
	_info = _label(24, 40.0, false)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_tip = _label(22, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	comment.connect(func(t: String) -> void: _tip.text = t)
	_pleats.resize(PLEATS)
	_pleats.fill(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_raw = _root.get_local_mouse_position()
	_setup.call_deferred()


func _label(size: int, y: float, bottom: bool) -> Label:
	return B.hud_label(self, size, y, bottom)


func _setup() -> void:
	_area = Rect2(_root.size / 2.0 - Vector2(440, 250), Vector2(880, 500))
	_center = _area.position + Vector2(440, 310)
	comment.emit((LINES[mode] as Array).pick_random())


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_shake = maxf(_shake - delta * 4.0, 0.0)
	_mouse = _raw + Vector2(sin(_t * 5.0), cos(_t * 4.3)) * drunk * 18.0
	MG.sparks_step(_sparks, delta)
	_root.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish(false)
		return
	if mode == "valmis":
		_fin_t += delta
		if _fin_t > 2.2:
			_finish(true)
		return
	_info.text = _status()
	_keys.set_text("%s lopeta" % Settings.cap("mount"))


func _status() -> String:
	match mode:
		"kaulinta":
			return "Taikinan kaulinta: %d %% · pidä vasen nappi pohjassa ja vedä pystyyn ja vaakaan" % roundi((_px + _py) * 50.0)
		"tayte":
			return "Täyte: muusia %d / %d, puolukkaa %d / %d · klikkaa kulho, sitten taikinaa" % [_muusi.size(), MUUSI_N,
				int(_berries.size() / 5.0), BERRY_N]
		"nypyt":
			return "Reunan nyppiminen: %d / %d · klikkaa renkaita" % [_pleats.count(true), PLEATS]
	return ""


func _gui(ev: InputEvent) -> void:
	if ev is InputEventMouse:
		_raw = ev.position
		_mouse = _raw
		_lmb = (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if _done or mode == "valmis":
		return
	if ev is InputEventMouseMotion and mode == "kaulinta" and _lmb:
		_roll(ev.relative)
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		match mode:
			"tayte":
				_click_tayte()
			"nypyt":
				_click_nyppy()


func _finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(ok)
	queue_free()


func _next(m: String) -> void:
	mode = m
	Sfx.play("win_small", -8.0, 1.2)
	comment.emit((LINES[m] as Array).pick_random())


# --- Kaulinta -----------------------------------------------------------------

func _dough_size() -> Vector2:
	var p := (_px + _py) / 2.0
	return Vector2(lerpf(DOUGH_MIN.x, DOUGH_MAX.x, clampf(_px * 0.6 + p * 0.4, 0.0, 1.0)),
		lerpf(DOUGH_MIN.y, DOUGH_MAX.y, clampf(_py * 0.6 + p * 0.4, 0.0, 1.0)))


func _roll(rel: Vector2) -> void:
	var d := _dough_size()
	var off := (_mouse - _center) / (d + Vector2(40, 40))
	if off.length() > 1.0:
		return  # kaulin pitää olla taikinan päällä
	_pin_h = absf(rel.y) > absf(rel.x)
	_px = minf(_px + absf(rel.x) * 0.0016, 1.0)
	_py = minf(_py + absf(rel.y) * 0.0024, 1.0)
	if randf() < 0.25 and rel.length() > 2.0:
		MG.sparks_burst(_sparks, _mouse, Color(0.97, 0.95, 0.88), 2)
	if randf() < 0.06:
		Sfx.play("cloth", -14.0, randf_range(0.7, 0.9))
	if _px >= 1.0 and _py >= 1.0:
		MG.sparks_burst(_sparks, _center, Color(0.97, 0.95, 0.88), 24)
		_next("tayte")


# --- Täyte --------------------------------------------------------------------

func _bowl(i: int) -> Vector2:
	return _area.position + Vector2(105 if i == 0 else 775, 390)


func _in_fill(p: Vector2) -> bool:
	var q := (p - _center) / FILL
	return q.length() <= 1.0


func _click_tayte() -> void:
	for i in 2:
		if _mouse.distance_to(_bowl(i)) < 75.0:
			var kind := "muusi" if i == 0 else "puolukka"
			if kind == "puolukka" and _muusi.size() < MUUSI_N:
				comment.emit((LINES["jarjestys"] as Array).pick_random())
				return
			if (kind == "muusi" and _muusi.size() >= MUUSI_N) or (kind == "puolukka" and _berries.size() >= BERRY_N * 5):
				return
			_held = kind
			Sfx.play("pickup", -8.0, 1.2 if i == 0 else 1.5)
			return
	if _held == "":
		return
	if not _in_fill(_mouse):
		comment.emit((LINES["ohi"] as Array).pick_random())
		Sfx.play("rattle", -10.0, 1.4)
		return
	var rel := _mouse - _center
	if _held == "muusi":
		for m in _muusi:
			if rel.distance_to(m) < 38.0:
				comment.emit("Vähän sivummalle, ei kasaan.")
				return
		_muusi.append(rel)
		MG.sparks_burst(_sparks, _mouse, Color(0.95, 0.88, 0.6), 8)
	else:
		for k in 5:
			var a := randf() * TAU
			_berries.append({"p": rel + Vector2(cos(a), sin(a)) * randf_range(0.0, 24.0), "c": randf()})
		MG.sparks_burst(_sparks, _mouse, Color(0.75, 0.1, 0.15), 8)
	_held = ""
	_shake = 0.4
	Sfx.play("pickup", -6.0, 0.7)
	if _muusi.size() >= MUUSI_N and _berries.size() >= BERRY_N * 5:
		_next("nypyt")


# --- Nyppy --------------------------------------------------------------------

func _pleat_pos(i: int) -> Vector2:
	var a := TAU * i / PLEATS
	return _center + Vector2(cos(a), sin(a)) * PLEAT_ELL


func _click_nyppy() -> void:
	for i in PLEATS:
		if not _pleats[i] and _mouse.distance_to(_pleat_pos(i)) < PLEAT_R:
			_pleats[i] = true
			_shake = 0.5
			Sfx.play("rattle", -8.0, randf_range(1.3, 1.7))
			MG.sparks_burst(_sparks, _pleat_pos(i), Color(0.97, 0.95, 0.88), 6)
			if _pleats.count(true) >= PLEATS:
				MG.sparks_burst(_sparks, _center, Color(1.0, 0.9, 0.5), 30)
				mode = "valmis"
				Sfx.play("win", -4.0)
				comment.emit((LINES["valmis"] as Array).pick_random())
				_info.text = "Valmis rönttönen!"
			return
	Sfx.play("cloth", -12.0, 1.2)


# --- Piirto -------------------------------------------------------------------

func _ell(c: Vector2, r: Vector2, n := 56) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw_root() -> void:
	_root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0, 0, 0, 0.55))
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 4.0
	_root.draw_set_transform(off)
	_draw_kitchen()
	match mode:
		"kaulinta":
			_draw_kaulinta()
		"tayte":
			_draw_tayte()
		_:
			_draw_nypyt()
	MG.sparks_draw(_root, _sparks)
	_root.draw_set_transform(Vector2.ZERO)


## Keittiö: laattaseinä, hylly (kahvipannu, kuppi, puolukkapurkki) ja jauhotettu puutaso.
func _draw_kitchen() -> void:
	var a := _area
	MG.box(_root, a.grow(14.0), Color(0.12, 0.09, 0.07), 22, 18)
	var wall := Rect2(a.position, Vector2(a.size.x, 130))
	MG.grad_rect(_root, wall, Color(0.93, 0.9, 0.8), Color(0.82, 0.78, 0.66))
	for ix in 22:
		for iy in 4:
			_root.draw_rect(Rect2(a.position + Vector2(ix * 40, iy * 32.5), Vector2(40, 32.5)), Color(0.55, 0.5, 0.4, 0.28), false, 1.0)
	MG.wood(_root, Rect2(a.position + Vector2(0, 130), Vector2(a.size.x, a.size.y - 130)), Color(0.66, 0.47, 0.27), 90.0, 5, false)
	_root.draw_rect(Rect2(a.position + Vector2(0, 126), Vector2(a.size.x, 8)), Color(0.4, 0.27, 0.15))
	# Hylly vasemmalla: kahvipannu ja kuppi; oikealla puolukkapurkki.
	MG.solid(_root, Rect2(a.position + Vector2(40, 96), Vector2(200, 12)), Color(0.5, 0.34, 0.18))
	MG.solid(_root, Rect2(a.position + Vector2(70, 48), Vector2(34, 48)), Color(0.2, 0.2, 0.22))
	_root.draw_rect(Rect2(a.position + Vector2(66, 44), Vector2(42, 8)), Color(0.12, 0.12, 0.14))
	_root.draw_arc(a.position + Vector2(104, 70), 14, -PI / 2, PI / 2, 10, Color(0.1, 0.1, 0.12), 4.0)
	MG.solid(_root, Rect2(a.position + Vector2(140, 70), Vector2(28, 26)), Color(0.95, 0.93, 0.88))
	_root.draw_arc(a.position + Vector2(168, 82), 8, -PI / 2, PI / 2, 10, Color(0.85, 0.83, 0.78), 3.0)
	MG.solid(_root, Rect2(a.position + Vector2(640, 96), Vector2(160, 12)), Color(0.5, 0.34, 0.18))
	MG.solid(_root, Rect2(a.position + Vector2(690, 58), Vector2(44, 38)), Color(0.7, 0.1, 0.15))
	_root.draw_rect(Rect2(a.position + Vector2(688, 52), Vector2(48, 9)), Color(0.9, 0.85, 0.7))
	_root.draw_rect(Rect2(a.position + Vector2(698, 66), Vector2(28, 14)), Color(0.95, 0.9, 0.78))
	# Jauholäikkiä tasolla.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for k in 26:
		MG.ball(_root, a.position + Vector2(rng.randf_range(30, 850), rng.randf_range(150, 480)), rng.randf_range(2, 5),
			Color(0.97, 0.95, 0.88, 0.5), 0.1)


func _dough_poly(c: Vector2, r: Vector2, col: Color) -> void:
	_root.draw_colored_polygon(_ell(c + Vector2(7, 11), r), Color(0, 0, 0, 0.28))
	_root.draw_colored_polygon(_ell(c, r), col.darkened(0.28))
	_root.draw_colored_polygon(_ell(c - Vector2(0, r.y * 0.035), r * Vector2(0.97, 0.93)), col)
	_root.draw_colored_polygon(_ell(c - Vector2(r.x * 0.1, r.y * 0.25), r * Vector2(0.55, 0.3)), col.lightened(0.12))
	var pts := _ell(c, r)
	pts.append(pts[0])
	_root.draw_polyline(pts, MG.OUTLINE, 2.5, true)
	var rng := RandomNumberGenerator.new()  # ruisjauhon pilkut
	rng.seed = 9
	for k in int(r.x * r.y / 900.0):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.9
		_root.draw_circle(c + Vector2(cos(a), sin(a)) * r * d, rng.randf_range(0.8, 1.6), col.darkened(0.35))


func _draw_pin(c: Vector2) -> void:
	var horizontal := _pin_h
	var half := Vector2(110, 0) if horizontal else Vector2(0, 110)
	var thick := 26.0
	var skin := Color(0.96, 0.78, 0.68)
	var sleeve := Color(0.85, 0.45, 0.4)
	var ends := [c - half, c + half]
	for e in ends:  # hihat ja kädet kaulimen päissä
		var dir: Vector2 = (e - c).normalized()
		_root.draw_line(e + dir * 10, e + dir * 70, sleeve, 30.0)
		_root.draw_line(e + dir * 70, e + dir * 90, sleeve.darkened(0.2), 4.0)
	MG.box(_root, Rect2(c - half - Vector2(0, 0) - (Vector2(0, thick / 2) if horizontal else Vector2(thick / 2, 0)),
		(Vector2(220, thick) if horizontal else Vector2(thick, 220))), Color(0.85, 0.66, 0.38), 12, 6, MG.OUTLINE, 2)
	var s := Rect2(c - Vector2(100, 5), Vector2(200, 5)) if horizontal else Rect2(c - Vector2(5, 100), Vector2(5, 200))
	_root.draw_rect(s, Color(1, 1, 1, 0.3))
	for e in ends:
		var dir: Vector2 = (e - c).normalized()
		_root.draw_circle(e + dir * 6, 14.0, skin)
		_root.draw_arc(e + dir * 6, 14.0, 0, TAU, 20, MG.OUTLINE, 2.0)


func _draw_kaulinta() -> void:
	var d := _dough_size()
	_dough_poly(_center, d, DOUGH)
	_draw_pin(_mouse if _lmb else _center + Vector2(0, -d.y - 40))


func _draw_filling(c: Vector2) -> void:
	for m in _muusi:  # perunamuusikeot
		var p: Vector2 = c + m
		_root.draw_circle(p + Vector2(3, 5), 31, Color(0, 0, 0, 0.2))
		_root.draw_circle(p, 31, Color(0.88, 0.8, 0.5))
		_root.draw_circle(p - Vector2(0, 3), 27, Color(0.97, 0.92, 0.66))
		_root.draw_circle(p - Vector2(9, 11), 9, Color(1.0, 0.98, 0.82))
		_root.draw_arc(p, 31, 0, TAU, 24, Color(0.55, 0.45, 0.2, 0.7), 1.5)
	for b in _berries:
		var p: Vector2 = c + b.p
		MG.ball(_root, p, 6.5, Color(0.72, 0.08, 0.16) if b.c > 0.35 else Color(0.85, 0.15, 0.2), 0.45)


func _draw_bowls() -> void:
	for i in 2:
		var bp := _bowl(i)
		var muusi := i == 0
		_root.draw_colored_polygon(_ell(bp + Vector2(5, 10), Vector2(74, 40)), Color(0, 0, 0, 0.3))
		_root.draw_colored_polygon(_ell(bp, Vector2(72, 42)), Color(0.35, 0.5, 0.65).darkened(0.2))
		_root.draw_colored_polygon(_ell(bp - Vector2(0, 8), Vector2(72, 36)), Color(0.4, 0.58, 0.75))
		_root.draw_colored_polygon(_ell(bp - Vector2(0, 8), Vector2(60, 28)), Color(0.95, 0.9, 0.65) if muusi else Color(0.7, 0.1, 0.15))
		_root.draw_colored_polygon(_ell(bp - Vector2(14, 14), Vector2(26, 8)),
			Color(1.0, 0.97, 0.82) if muusi else Color(0.85, 0.2, 0.25))
		var rim := _ell(bp - Vector2(0, 8), Vector2(72, 36))
		rim.append(rim[0])
		_root.draw_polyline(rim, MG.OUTLINE, 2.0, true)
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		if _held == "" and ((muusi and _muusi.size() < MUUSI_N) or (not muusi and _muusi.size() >= MUUSI_N)):
			var ring := _ell(bp - Vector2(0, 8), Vector2(80 + pulse * 4.0, 44 + pulse * 3.0))
			ring.append(ring[0])
			_root.draw_polyline(ring, Color(1, 0.9, 0.4, 0.8), 3.0, true)


func _draw_spoon() -> void:
	if _held == "":
		return
	var p := _mouse
	_root.draw_line(p + Vector2(0, 8), p + Vector2(70, -50), Color(0.55, 0.36, 0.16), 9.0)
	_root.draw_colored_polygon(_ell(p, Vector2(24, 17)), Color(0.72, 0.5, 0.24))
	_root.draw_colored_polygon(_ell(p - Vector2(0, 3), Vector2(19, 12)),
		Color(0.97, 0.92, 0.66) if _held == "muusi" else Color(0.75, 0.1, 0.16))
	_root.draw_arc(p, 24, 0, TAU, 20, MG.OUTLINE, 2.0)


func _draw_tayte() -> void:
	_dough_poly(_center, DOUGH_MAX, DOUGH)
	var pts := _ell(_center, FILL)  # täytealueen ohjausviiva
	pts.append(pts[0])
	_root.draw_polyline(pts, Color(1, 1, 1, 0.35), 2.0)
	_draw_filling(_center)
	_draw_bowls()
	_draw_spoon()


func _draw_nypyt() -> void:
	var done := mode == "valmis"
	var col := DOUGH.lerp(BAKED, clampf(_fin_t / 1.2, 0.0, 1.0)) if done else DOUGH
	_dough_poly(_center, DOUGH_MAX, col)
	# Poimutetut reunat: päällekkäiset nyppylohkot renkaan paikoissa ja poimu sisäänpäin.
	for i in PLEATS:
		var p := _pleat_pos(i)
		if _pleats[i]:
			var inward := (_center - p).normalized()
			_root.draw_circle(p + Vector2(2, 4), PLEAT_R, Color(0, 0, 0, 0.25))
			_root.draw_circle(p, PLEAT_R, col.darkened(0.3))
			_root.draw_circle(p - Vector2(0, 2), PLEAT_R - 3, col.lightened(0.04))
			_root.draw_circle(p - Vector2(7, 9), 9, col.lightened(0.18))
			_root.draw_line(p + inward * 4, p + inward * 26, col.darkened(0.4), 2.5)
			_root.draw_arc(p, PLEAT_R, 0, TAU, 20, MG.OUTLINE, 1.5)
		else:
			var pulse := 0.5 + 0.5 * sin(_t * 5.0 + i)
			_root.draw_arc(p, 11 + pulse * 3.0, 0, TAU, 16, Color(1, 0.9, 0.4, 0.85), 2.5)
			_root.draw_circle(p, 3.0, Color(1, 0.95, 0.6, 0.8))
	# Avoin täytealue: sisäsoikio (täyte näkyy), sisäreuna varjona.
	var inner := Vector2(172, 78)
	_root.draw_colored_polygon(_ell(_center, inner + Vector2(6, 6)), col.darkened(0.35))
	_root.draw_colored_polygon(_ell(_center, inner), Color(0.85, 0.78, 0.5))
	_draw_filling(_center)
	var ip := _ell(_center, inner)
	ip.append(ip[0])
	_root.draw_polyline(ip, MG.OUTLINE, 2.0, true)
	if done:
		for k in 3:  # höyry
			var sx := _center.x - 80 + k * 80
			for j in 6:
				var yy := _center.y - 150 - j * 18 - fmod(_fin_t * 40.0, 18.0)
				_root.draw_circle(Vector2(sx + sin(_t * 2.0 + j + k) * 8.0, yy), 6.0 + j, Color(1, 1, 1, 0.2 - j * 0.03))
		# "Valmis rönttönen!" näkyy ylhäällä _info-tekstinä: kyltti alareunassa osui alareunan kommentin päälle.
