extends CanvasLayer
## Sytkäri (#255): parodiadeittisovellus pelaajan puhelimessa (liekkilogo, pyyhkäisy vasemmalle tai oikealle).
## Ei Tinderin nimeä eikä logoa. Kolme näkymää:
##   "match"  profiilikortti, pyyhkäisy oikealle, MÄTSI! ja etäisyys (osoitetta ei kerrota)
##   "matka"  profiili ja etäisyys tästä paikasta, alla kaverin tekstiviesti (kolmiomittaus.gd MEASURE_LINES)
## Puhelin nousee ruudun alalaidasta, E tai Esc sulkee (closed). Kuvat ovat piirrettyjä profiilikuvia
## Profiilikuvat ovat 3D-hahmoista otettuja kuvia (_photo: oma pieni studio SubViewportissa, Looks.make-hahmo):
## Minttu kesäpihalla, Katja iltakadulla ja pelaaja harmaata taustaa vasten.

signal closed

const MG := preload("res://scripts/mg_draw.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

const FLAME_A := Color(1.0, 0.36, 0.2)
const FLAME_B := Color(1.0, 0.7, 0.18)
const INK := Color(0.12, 0.1, 0.12)

var mode := "match"
var who := "Minttu"
var age := 34
var job := ""
var bio := ""
var dist := ""  # "350 m"
var note := ""  # kaverin viesti
var note_from := ""

var _view: Control
var _t := 0.0
var _rise := 0.0
var _swiped := 0.0  # 0..1 kortti lentää oikealle (match)
var _hearts: Array = []  # [paikka, nopeus, ikä]
var _done := false
var _photos := {}  # nimi -> SubViewport (profiilikuva)


func _ready() -> void:
	add_to_group("esc_lopettaa")
	layer = 7
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_all)
	add_child(_view)
	match who:
		"Minttu":
			_photos[who] = _photo(Looks.MINTTU, Color(0.62, 0.82, 0.98), Color(0.35, 0.6, 0.28), "kesa")
		"Katja":
			_photos[who] = _photo(Looks.KATJA, Color(0.16, 0.18, 0.26), Color(0.2, 0.2, 0.22), "ilta")
	_photos["me"] = _photo(Looks.player(), Color(0.62, 0.66, 0.72), Color(0.5, 0.5, 0.52), "")
	Sfx.play("bell", -12.0, 2.4)
	Sfx.play("bell", -14.0, 3.0)


func _process(delta: float) -> void:
	_t += delta
	_rise = minf(1.0, _rise + delta * 3.0)
	if mode == "match":
		if _t > 1.6 and _swiped == 0.0:
			_swiped = 0.001
			Sfx.play("whoosh", -6.0, 1.3)
		if _swiped > 0.0 and _swiped < 1.0:
			_swiped = minf(1.0, _swiped + delta * 2.2)
			if _swiped >= 1.0:
				Sfx.play("win_small", -4.0, 1.2)
				for i in 26:
					var a := randf() * TAU
					_hearts.append([Vector2.ZERO, Vector2(cos(a), sin(a) - 0.6) * randf_range(80, 260), 0.0])
	for h in _hearts:
		h[2] += delta
		h[1].y += 160.0 * delta
		h[0] += h[1] * delta
	_hearts = _hearts.filter(func(h: Array) -> bool: return h[2] < 1.6)
	var can_close := _t > (2.8 if mode == "match" else 0.8)
	if can_close and not _done and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")
			or Input.is_key_pressed(KEY_ESCAPE)):
		_done = true
		closed.emit()
		queue_free()
	_view.queue_redraw()


func _draw_all() -> void:
	var s := _view.size if _view.size.x > 10.0 else Vector2(1280, 720)
	var k := s.y / 720.0
	_view.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.45 * _rise))
	var e := 1.0 - pow(1.0 - _rise, 3.0)
	var pw := 330.0 * k
	var ph := 640.0 * k
	var pr := Rect2(Vector2((s.x - pw) / 2.0, s.y - ph * e - 20 * k * e + (1.0 - e) * 60.0), Vector2(pw, ph))
	# Puhelin: musta kuori, kiiltävä reuna, kaiutinrako ja näyttö.
	MG.box(_view, pr, Color(0.07, 0.07, 0.08), int(44 * k), int(10 * k), Color(0.35, 0.35, 0.38), int(3 * k))
	_view.draw_line(pr.position + Vector2(40, 8) * k, pr.position + Vector2(pw - 40 * k, 8 * k), Color(1, 1, 1, 0.15), 2.0)
	MG.box(_view, Rect2(pr.position + Vector2(pw / 2.0 - 34 * k, 18 * k), Vector2(68, 8) * k), Color(0.2, 0.2, 0.22), int(4 * k))
	var sr := Rect2(pr.position + Vector2(14, 38) * k, Vector2(pw - 28 * k, ph - 70 * k))
	MG.grad_rect(_view, sr, Color(0.99, 0.97, 0.96), Color(0.95, 0.92, 0.92))
	_status_bar(sr, k)
	_app_header(sr, k)
	var card := Rect2(sr.position + Vector2(14, 88) * k, Vector2(sr.size.x - 28 * k, sr.size.y * 0.62))
	if mode == "match":
		_draw_match(sr, card, k)
	else:
		_draw_matka(sr, card, k)
	for h in _hearts:
		var a: float = 1.0 - h[2] / 1.6
		_heart(card.get_center() + h[0], 9.0 * k * (0.6 + a * 0.6), Color(1.0, 0.35, 0.45, a))
	MG.box(_view, Rect2(pr.position + Vector2(pw / 2.0 - 50 * k, ph - 22 * k), Vector2(100, 6) * k), Color(0.5, 0.5, 0.52), int(3 * k))
	if (mode == "match" and _t > 2.8) or (mode != "match" and _t > 0.8):
		var hint := "[%s] puhelin taskuun" % Settings.action_key("interact")
		_view.draw_string_outline(ThemeDB.fallback_font, Vector2(0, pr.position.y - 14 * k), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x,
			int(20 * k), 6, Color.BLACK)
		_view.draw_string(ThemeDB.fallback_font, Vector2(0, pr.position.y - 14 * k), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x,
			int(20 * k), Color(1.0, 0.92, 0.75))


func _status_bar(sr: Rect2, k: float) -> void:
	var f := ThemeDB.fallback_font
	_view.draw_string(f, sr.position + Vector2(12, 18) * k, "DNA 4G", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k), INK)
	_view.draw_string(f, sr.position + Vector2(0, 18 * k), "21:37", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(12 * k), INK)
	var b := Rect2(sr.end.x - 40 * k, sr.position.y + 7 * k, 24 * k, 12 * k)
	_view.draw_rect(b, INK, false, 1.5)
	_view.draw_rect(Rect2(b.position + Vector2(2, 2), Vector2(b.size.x * 0.4, b.size.y - 4)), Color(0.85, 0.2, 0.15))
	_view.draw_rect(Rect2(b.end.x, b.position.y + 3 * k, 3 * k, 6 * k), INK)


## Sovelluksen otsake: liekkilogo ja nimi.
func _app_header(sr: Rect2, k: float) -> void:
	var c := Vector2(sr.position.x + sr.size.x / 2.0 - 52 * k, sr.position.y + 54 * k)
	flame(_view, c, 20.0 * k, _t)
	var f := ThemeDB.fallback_font
	_view.draw_string(f, c + Vector2(22, 10) * k, "sytkäri", HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * k), FLAME_A.darkened(0.1))
	_view.draw_line(Vector2(sr.position.x + 10 * k, sr.position.y + 78 * k), Vector2(sr.end.x - 10 * k, sr.position.y + 78 * k),
		Color(0.85, 0.82, 0.82), 1.5)


## Liekkilogo: kaksi päällekkäistä pisaraa (oranssi ulkona, keltainen sisällä), kärki lepattaa.
static func flame(ci: CanvasItem, c: Vector2, r: float, t := 0.0) -> void:
	var wob := sin(t * 7.0) * 0.12
	for ly in 2:
		var rr := r * (1.0 if ly == 0 else 0.55)
		var base := c + Vector2(0, r * 0.35 if ly == 0 else r * 0.55)
		var pts := PackedVector2Array()
		for i in 25:
			var a := PI * 0.5 + TAU * i / 24.0
			var q := Vector2(cos(a), sin(a)) * rr
			if q.y < 0.0:  # yläpuoli venyy kärjeksi
				var up := -q.y / rr
				q.y *= 1.0 + 1.3 * up
				q.x *= 1.0 - 0.75 * up * up
				q.x += wob * rr * up * up
			pts.append(base + q)
		ci.draw_colored_polygon(pts, FLAME_A if ly == 0 else FLAME_B)
		if ly == 0:
			pts.append(pts[0])
			ci.draw_polyline(pts, FLAME_A.darkened(0.35), 1.5, true)


func _heart(c: Vector2, r: float, col: Color) -> void:
	_view.draw_circle(c + Vector2(-r * 0.5, 0), r * 0.6, col)
	_view.draw_circle(c + Vector2(r * 0.5, 0), r * 0.6, col)
	_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.08, r * 0.15), c + Vector2(r * 1.08, r * 0.15),
		c + Vector2(0, r * 1.3)]), col)


func _draw_match(sr: Rect2, card: Rect2, k: float) -> void:
	var f := ThemeDB.fallback_font
	var e := _swiped * _swiped
	if _swiped < 1.0:
		# Kortti lentää oikealle ja kallistuu; alla seuraava (tyhjä) kortti.
		MG.box(_view, card.grow(-6 * k), Color(0.88, 0.86, 0.86), int(16 * k))
		var off := Vector2(e * sr.size.x * 1.2, -e * 40.0 * k)
		_view.draw_set_transform(card.get_center() + off, e * 0.5, Vector2.ONE)
		var local := Rect2(-card.size / 2.0, card.size)
		_profile_card(local, k)
		if _t > 1.0:
			var a := clampf((_t - 1.0) * 3.0, 0.0, 1.0)
			var lr := Rect2(local.position + Vector2(16, 20) * k, Vector2(130, 46) * k)
			_view.draw_rect(lr, Color(0.2, 0.8, 0.4, a), false, 4.0 * k)
			_view.draw_string(f, lr.position + Vector2(0, 34 * k), "TYKKÄÄ", HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, int(28 * k),
				Color(0.2, 0.8, 0.4, a))
		_view.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		_buttons(sr, k, _t > 1.2)
		return
	# MÄTSI! Kaksi pyöreää profiilikuvaa vierekkäin, liekki välissä, etäisyys mutta ei osoitetta.
	var pop := clampf((_t - 1.6 - 1.0 / 2.2) * 4.0, 0.0, 1.0)
	var big := 1.0 + 0.15 * sin(clampf(pop, 0.0, 1.0) * PI)
	_view.draw_string_outline(f, Vector2(sr.position.x, card.position.y + 50 * k), "MÄTSI!", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x,
		int(52 * k * big), 8, Color.WHITE)
	_view.draw_string(f, Vector2(sr.position.x, card.position.y + 50 * k), "MÄTSI!", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x,
		int(52 * k * big), FLAME_A)
	var cy := card.position.y + 140 * k
	var me_c := Vector2(sr.get_center().x - 70 * k, cy)
	var her_c := Vector2(sr.get_center().x + 70 * k, cy)
	_round_photo(her_c, 58 * k, k, false)
	_round_photo(me_c, 58 * k, k, true)
	flame(_view, Vector2(sr.get_center().x, cy + 8 * k), 18 * k, _t)
	var y := cy + 92 * k
	_view.draw_string(f, Vector2(sr.position.x, y), "%s, %d" % [who, age], HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(26 * k), INK)
	_view.draw_string(f, Vector2(sr.position.x, y + 28 * k), "%s päässä" % dist, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(20 * k),
		FLAME_A.darkened(0.15))
	_bubble_text(Rect2(sr.position.x + 18 * k, y + 46 * k, sr.size.x - 36 * k, 64 * k), "\"%s\"" % bio, k, Color(1.0, 0.93, 0.9))
	_view.draw_string(f, Vector2(sr.position.x, y + 132 * k), "Osoite: ei kerrottu", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(15 * k),
		Color(0.45, 0.4, 0.42))


func _draw_matka(sr: Rect2, card: Rect2, k: float) -> void:
	var f := ThemeDB.fallback_font
	var top := Rect2(card.position, Vector2(card.size.x, 150 * k))
	MG.box(_view, top, Color.WHITE, int(16 * k), int(4 * k), Color(0.85, 0.8, 0.8), 1)
	_round_photo(top.position + Vector2(70, 75) * k, 52 * k, k, false)
	_view.draw_string(f, top.position + Vector2(134, 52) * k, "%s, %d" % [who, age], HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * k), INK)
	_view.draw_string(f, top.position + Vector2(134, 76) * k, job, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), Color(0.45, 0.4, 0.42))
	# Sijaintinasta ja etäisyys isolla: osoitetta ei näy, vain pyöristetty matka.
	var pin := top.position + Vector2(132, 106) * k
	_view.draw_circle(pin, 8 * k, FLAME_A)
	_view.draw_colored_polygon(PackedVector2Array([pin + Vector2(-7, 3) * k, pin + Vector2(7, 3) * k, pin + Vector2(0, 16) * k]), FLAME_A)
	_view.draw_circle(pin, 3 * k, Color.WHITE)
	var pulse := 1.0 + 0.06 * sin(_t * 6.0)
	_view.draw_string(f, top.position + Vector2(144, 116) * k, "%s päässä" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * k * pulse),
		FLAME_A.darkened(0.15))
	# Tutkarenkaat: sovellus pyöristää, joten paikka on rengas eikä piste.
	var rc := Vector2(sr.get_center().x, top.end.y + 92 * k)
	for i in 3:
		var rr := fmod(_t * 40.0 + i * 30.0, 90.0) * k
		_view.draw_arc(rc, rr, 0, TAU, 40, Color(FLAME_A.r, FLAME_A.g, FLAME_A.b, 0.6 * (1.0 - rr / (90.0 * k))), 2.5 * k)
	_view.draw_circle(rc, 5 * k, INK)
	_view.draw_string(f, Vector2(sr.position.x, rc.y + 74 * k), "sinä", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(13 * k),
		Color(0.45, 0.4, 0.42))
	if note != "":
		var nr := Rect2(sr.position.x + 14 * k, sr.end.y - 130 * k, sr.size.x - 28 * k, 112 * k)
		MG.box(_view, nr, Color(0.86, 0.93, 1.0), int(14 * k), int(3 * k), Color(0.6, 0.72, 0.88), 1)
		_view.draw_string(f, nr.position + Vector2(12, 22) * k, "Viesti: %s" % note_from, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k),
			Color(0.2, 0.35, 0.6))
		_wrap(nr.position + Vector2(12, 46) * k, note, nr.size.x - 24 * k, int(16 * k), INK)


func _profile_card(r: Rect2, k: float) -> void:
	MG.box(_view, r, Color.WHITE, int(16 * k), int(6 * k), Color(0.8, 0.76, 0.76), 1)
	var ph := Rect2(r.position + Vector2(8, 8) * k, Vector2(r.size.x - 16 * k, r.size.y * 0.74))
	_portrait(_view, ph, who)
	# Nimen tausta: tumma liukuväri kuvan alareunassa.
	MG.grad_rect(_view, Rect2(ph.position.x, ph.end.y - 70 * k, ph.size.x, 70 * k), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.65))
	var f := ThemeDB.fallback_font
	_view.draw_string(f, Vector2(ph.position.x + 14 * k, ph.end.y - 30 * k), "%s, %d" % [who, age], HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(28 * k), Color.WHITE)
	_view.draw_string(f, Vector2(ph.position.x + 14 * k, ph.end.y - 10 * k), job, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k),
		Color(1, 1, 1, 0.85))
	_wrap(Vector2(r.position.x + 14 * k, ph.end.y + 26 * k), bio, r.size.x - 28 * k, int(15 * k), INK)


func _buttons(sr: Rect2, k: float, like: bool) -> void:
	var y := sr.end.y - 52 * k
	var no := Vector2(sr.get_center().x - 60 * k, y)
	var yes := Vector2(sr.get_center().x + 60 * k, y)
	MG.ball(_view, no, 26 * k, Color.WHITE, 0.2)
	_view.draw_line(no + Vector2(-9, -9) * k, no + Vector2(9, 9) * k, Color(0.9, 0.3, 0.35), 4 * k)
	_view.draw_line(no + Vector2(9, -9) * k, no + Vector2(-9, 9) * k, Color(0.9, 0.3, 0.35), 4 * k)
	MG.ball(_view, yes, 26 * k * (1.15 if like else 1.0), Color(0.75, 1.0, 0.82) if like else Color.WHITE, 0.2)
	_heart(yes + Vector2(0, -3 * k), 10 * k, Color(0.2, 0.75, 0.4))


func _round_photo(c: Vector2, r: float, k: float, me: bool) -> void:
	_view.draw_circle(c + Vector2(2, 4) * k, r + 4 * k, Color(0, 0, 0, 0.25))
	_view.draw_circle(c, r + 4 * k, Color.WHITE)
	var box := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	if me:
		_portrait(_view, box, "me", true)
	else:
		_portrait(_view, box, who, true)
	_view.draw_arc(c, r + 2 * k, 0, TAU, 48, FLAME_A, 3.0 * k)


## Profiilikuva laatikkoon: 3D-hahmon kuva (_photo), kuvasuhde säilyy (rajataan keskeltä). circle = pyöreä
## pienoiskuva (kulmat peitetään valkoisella).
func _portrait(ci: CanvasItem, r: Rect2, pname: String, circle := false) -> void:
	var vp: SubViewport = _photos.get(pname)
	if vp == null:
		ci.draw_rect(r, Color(0.6, 0.6, 0.62))
	else:
		var src := Vector2(vp.size)
		var sc := maxf(r.size.x / src.x, r.size.y / src.y)
		var crop := r.size / sc
		ci.draw_texture_rect_region(vp.get_texture(), r, Rect2((src - crop) / 2.0, crop))
	if circle:
		var rr := minf(r.size.x, r.size.y) / 2.0
		var c := r.get_center()
		ci.draw_arc(c, rr + rr * 0.25, 0, TAU, 48, Color.WHITE, rr * 0.5)
		ci.draw_rect(Rect2(r.position.x - 2, r.end.y - 2, r.size.x + 4, rr * 0.4), Color.WHITE)
	else:
		ci.draw_rect(r, MG.OUTLINE, false, 2.0)


## Profiilikuvan studio: hahmo kasvot kameraan, tausta ja valot omassa 3D-maailmassaan (ei pelin aurinkoa eikä maastoa).
func _photo(look: Dictionary, bg: Color, ground: Color, props: String) -> SubViewport:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(360, 480)
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var st := Node3D.new()
	vp.add_child(st)
	var ch: Node3D = Looks.make(st, look)
	ch.rotation.y = PI  # kasvot +Z:aan, kameraan
	ch.play("Idle", 0.0)
	B.mesh(st, B.boxm(Vector3(6, 4, 0.1)), Vector3(0, 1.8, -1.6), bg)
	B.mesh(st, B.boxm(Vector3(6, 0.1, 4)), Vector3(0, -0.05, 0), ground)
	match props:
		"kesa":  # pihan kukkapenkki ja pensas taustalla
			for i in 14:
				var p := Vector3(-1.4 + i * 0.22, 0.25 + 0.15 * (i % 3), -1.45)
				B.mesh(st, B.sphere(0.06, 8), p, Color(1.0, 0.95, 0.4) if i % 2 == 0 else Color(1.0, 1.0, 1.0))
			B.mesh(st, B.sphere(0.6, 14), Vector3(-1.2, 0.5, -1.3), Color(0.25, 0.5, 0.22))
			B.mesh(st, B.sphere(0.5, 14), Vector3(1.3, 0.45, -1.35), Color(0.3, 0.55, 0.25))
		"ilta":  # katulamppu ja moottoripyörän punainen tankki
			var bulb := B.mesh(st, B.sphere(0.12, 12), Vector3(-0.9, 2.3, -1.4), Color(1.0, 0.85, 0.5))
			var bm := bulb.material_override as StandardMaterial3D
			bm.emission_enabled = true
			bm.emission = Color(1.0, 0.8, 0.45)
			bm.emission_energy_multiplier = 4.0
			B.mesh(st, B.capsule(0.18, 0.7), Vector3(0.75, 0.9, -0.6), Color(0.65, 0.06, 0.08), Vector3(0, 0, 90))
			B.tube(st, Vector3(0.35, 1.05, -0.6), Vector3(0.45, 1.15, -0.95), 0.015, Color(0.75, 0.75, 0.78))
	var key := DirectionalLight3D.new()
	key.light_energy = 1.2
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-30, 25, 0)
	st.add_child(key)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.environment = env
	st.add_child(cam)
	var h := float(look.get("height", 1.75))
	var eye := Vector3(0.12, h * 0.9, 1.25)  # pää ja hartiat: profiilikuvan rajaus
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, h * 0.84, 0) - eye, Vector3.UP), eye)
	cam.current = true
	return vp


func _bubble_text(r: Rect2, text: String, k: float, col: Color) -> void:
	MG.box(_view, r, col, int(12 * k), 0, Color(0.85, 0.75, 0.72), 1)
	_wrap(r.position + Vector2(10, 22) * k, text, r.size.x - 20 * k, int(15 * k), INK)


func _wrap(at: Vector2, text: String, w: float, size: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var line := ""
	var y := 0.0
	for word in text.split(" "):
		var t := word if line == "" else line + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w and line != "":
			_view.draw_string(font, at + Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += size * 1.3
			line = word
		else:
			line = t
	_view.draw_string(font, at + Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
