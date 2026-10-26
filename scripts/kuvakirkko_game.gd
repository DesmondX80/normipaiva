extends CanvasLayer
## Paltaniemen kuvakirkko, piilokuvaetsintä (#250 P9): kirkon seinän kolmessa maalauksessa on kuusi pientä piilokuvaa. Hiirellä (suurennuslasi)
## klikataan löydetty kohde; alareunan lokerikko näyttää etsittävät (siluetti -> väri löytyessä) ja laskuri n/6 kertoo tilan.
## Hutiklikkaus vain värähdyttää; 20 s ilman löytöä kimaltaa lähin löytämätön. Löydöt säilyvät käyntien välillä (`found`, item_found).
## Esc lopettaa kesken (finished(false), löydöt jäävät). finished(true) kun kaikki kuusi on löydetty. Maalaukset ovat tyyliteltyjä
## (taivas ja maa, arkki, puutarha), eivät kopioita kirkon maalauksista.

signal finished(done: bool)
signal item_found(id: String)

const MG := preload("res://scripts/mg_draw.gd")
const W := 1280.0
const H := 720.0
const INK := Color(0.1, 0.08, 0.06)
const GOLD := Color(0.82, 0.64, 0.22)
const HIT_R := 24.0
const TEX_PAD := 24.0  # maalaustekstuurin reunus
const IDLE_HINT := 20.0

## Maalaukset (taulun suorakaide) ja piilokuvat: id, nimi, taulu, paikka taulun sisällä (px).
const FRAMES := {
	"taivas": Rect2(50, 110, 340, 390),
	"arkki": Rect2(430, 110, 420, 390),
	"puutarha": Rect2(890, 110, 340, 390),
}
const ITEMS := {
	"tahti": {"nimi": "tähti", "frame": "taivas", "at": Vector2(238, 78)},
	"kala": {"nimi": "kala", "frame": "arkki", "at": Vector2(96, 318)},
	"kissa": {"nimi": "kissa", "frame": "arkki", "at": Vector2(205, 124)},
	"lintu": {"nimi": "lintu", "frame": "puutarha", "at": Vector2(232, 118)},
	"avain": {"nimi": "avain", "frame": "puutarha", "at": Vector2(84, 340)},
	"etana": {"nimi": "etana", "frame": "puutarha", "at": Vector2(150, 330)},
}

var found: Array = []  # löydetyt id:t (main.gd antaa aiemmat)
var texture_only := false  # vain yksi maalaus tekstuuriksi (painting_viewport): ei hiirtä, hintbaria eikä Esc-ryhmää
var _tex_id := ""
var _root: Control
var _keys: Control
var _t := 0.0
var _idle := 0.0
var _glint_id := ""
var _glint_t := 0.0
var _misses: Array = []  # [pos, ikä]
var _wobble := 0.0
var _sparks: Array = []
var _say := ""
var _say_t := 0.0
var _all_t := -1.0
var _finished := false
var _mouse := Vector2(640, 360)


func _ready() -> void:
	if texture_only:
		_root = Control.new()
		_root.size = FRAMES[_tex_id].size + Vector2(TEX_PAD, TEX_PAD) * 2.0
		_root.draw.connect(func() -> void:
			_root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.3, 0.2, 0.1))
			_draw_painting(_tex_id, Rect2(Vector2(TEX_PAD, TEX_PAD), FRAMES[_tex_id].size)))
		add_child(_root)
		set_process(false)
		set_process_input(false)
		return
	add_to_group("esc_lopettaa")
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	add_child(_root)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if found.size() >= ITEMS.size():
		_all_t = 0.0
	_speak("Kirkon seinillä on kuusi piilokuvaa. Etsi ne." if found.is_empty() else "Jatketaan: %d/%d löydetty." % [found.size(), ITEMS.size()])


## Maalaus (sama piirto kuin minipelissä, kehys ja piilokuvat mukana) 3D-seinää varten: SubViewport, jonka tekstuuri laitetaan kvadille.
## Viewport kantaa piirtäjää lapsenaan; koko px = FRAMES-koko + 2 * TEX_PAD.
static func painting_viewport(id: String) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(FRAMES[id].size + Vector2(TEX_PAD, TEX_PAD) * 2.0)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var g: CanvasLayer = new()
	g.texture_only = true
	g._tex_id = id
	vp.add_child(g)
	return vp


func _item_pos(id: String) -> Vector2:
	return FRAMES[ITEMS[id].frame].position + ITEMS[id].at


func _speak(t: String) -> void:
	_say = t
	_say_t = 3.6


func _input(ev: InputEvent) -> void:
	if _finished:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ESCAPE or ev.keycode == KEY_F:
			_end(false)
		elif _all_t >= 0.0 and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_E):
			_end(true)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		_mouse = _root.get_local_mouse_position()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = _root.get_local_mouse_position()
		if _all_t >= 0.0:
			if _all_t > 0.8:
				_end(true)
		else:
			click(_mouse)


## Klikkaus kuvapisteeseen p (testit kutsuvat suoraan): osuma löytää kohteen, huti värähdyttää.
func click(p: Vector2) -> void:
	for id in ITEMS:
		if not found.has(id) and p.distance_to(_item_pos(id)) <= HIT_R:
			found.append(id)
			_idle = 0.0
			_glint_id = ""
			MG.sparks_burst(_sparks, _item_pos(id), GOLD.lightened(0.3), 22)
			Sfx.play("pickup", -4.0, 1.0 + 0.1 * found.size())
			item_found.emit(id)
			if found.size() >= ITEMS.size():
				_all_t = 0.0
				Sfx.play("win_small", -4.0)
				_speak("Kaikki kuusi löytyi! Hieno silmä.")
			else:
				_speak("Löytyi: %s (%d/%d)" % [ITEMS[id].nimi, found.size(), ITEMS.size()])
			return
	_misses.append([p, 0.0])
	_wobble = 0.3
	Sfx.play("rattle_hard", -14.0, 0.7)


func _end(done: bool) -> void:
	if _finished:
		return
	_finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finished.emit(done)
	queue_free()


## Lähin löytämätön kuva annetusta pisteestä.
func _nearest_unfound(p: Vector2) -> String:
	var best := ""
	var bd := 1e9
	for id in ITEMS:
		if not found.has(id) and p.distance_to(_item_pos(id)) < bd:
			bd = p.distance_to(_item_pos(id))
			best = id
	return best


func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	_wobble = maxf(0.0, _wobble - delta)
	_say_t = maxf(0.0, _say_t - delta)
	_glint_t = maxf(0.0, _glint_t - delta)
	MG.sparks_step(_sparks, delta)
	for m in _misses:
		m[1] += delta
	_misses = _misses.filter(func(m: Array) -> bool: return m[1] < 0.6)
	if _all_t >= 0.0:
		_all_t += delta
		_keys.set_text("[Väli] Valmis")
	else:
		_idle += delta
		if _idle > IDLE_HINT:
			_idle = 0.0
			_glint_id = _nearest_unfound(_mouse)
			_glint_t = 2.5
		_keys.set_text("[Hiiri] Etsi piilokuvat (%d/%d)   [Esc] Lopeta" % [found.size(), ITEMS.size()])
	_mouse = _root.get_local_mouse_position()
	_root.queue_redraw()


# --- Piirto ---------------------------------------------------------------------------------

func _draw_root() -> void:
	var c := _root
	# Kirkon seinä: tumma puupanelointi, katon maalattu kaista, lattia ja penkkien selkänojat alhaalla.
	MG.wood(c, Rect2(0, 0, W, 610), Color(0.5, 0.36, 0.22), 90.0, 4, false)
	c.draw_rect(Rect2(0, 0, W, 610), Color(0.18, 0.1, 0.05, 0.35))
	_draw_ceiling(Rect2(0, 0, W, 86))
	MG.wood(c, Rect2(0, 610, W, 110), Color(0.28, 0.18, 0.1), 80.0, 9, true)
	MG.grad_rect(c, Rect2(0, 600, W, 20), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.5))
	# Ikkunan valokeila vinosti seinälle.
	c.draw_colored_polygon(PackedVector2Array([Vector2(520, 86), Vector2(700, 86), Vector2(900, 610), Vector2(640, 610)]), Color(1, 0.95, 0.7, 0.07))
	for id in FRAMES:
		_draw_painting(id, FRAMES[id])
	for id in found:
		_draw_found_ring(id)
	# Nimikyltti kuvien alla.
	MG.sign(c, Rect2(430, 520, 420, 56), "PALTANIEMEN KUVAKIRKKO\nsanotaan: seinät on maalattu 1700-luvulla", Color(0.2, 0.14, 0.09), Color(0.97, 0.9, 0.7), 20, GOLD)
	_draw_tray()
	for m in _misses:
		var k: float = 1.0 - m[1] / 0.6
		c.draw_line(m[0] + Vector2(-9, -9), m[0] + Vector2(9, 9), Color(0.85, 0.2, 0.15, k), 4.0)
		c.draw_line(m[0] + Vector2(9, -9), m[0] + Vector2(-9, 9), Color(0.85, 0.2, 0.15, k), 4.0)
	if _glint_t > 0.0 and _glint_id != "":
		var gp := _item_pos(_glint_id)
		var pulse := 0.5 + 0.5 * sin(_t * 9.0)
		c.draw_arc(gp, 30.0 + 6.0 * pulse, 0, TAU, 32, Color(1, 0.95, 0.5, 0.85), 3.0, true)
		MG.glow(c, gp, 36.0, Color(1, 0.95, 0.5, 0.5))
	MG.sparks_draw(c, _sparks)
	if _say_t > 0.0:
		MG.sign(c, Rect2(390, 624, 500, 44), _say, Color(0.97, 0.93, 0.8), INK, 24, GOLD)
	if _all_t >= 0.0:
		var a := minf(_all_t / 0.6, 1.0)
		c.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45 * a))
		MG.sign(c, Rect2(340, 250, 600, 190), "KAIKKI LÖYTYI!\n%d/%d piilokuvaa\n[Väli] Jatka" % [ITEMS.size(), ITEMS.size()], Color(0.2, 0.14, 0.09), Color(1, 0.93, 0.6), 46, GOLD)
	_draw_lens(_mouse)


## Katon maalattu kaista: syvänsininen, kultatähtiä ja köynnös.
func _draw_ceiling(r: Rect2) -> void:
	var c := _root
	MG.grad_rect(c, r, Color(0.12, 0.2, 0.42), Color(0.2, 0.3, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 34:
		var p := Vector2(rng.randf_range(12, W - 12), rng.randf_range(10, r.size.y - 14))
		var s := rng.randf_range(3.0, 6.5)
		_star(p, s, GOLD.lightened(0.15), 0.0)
	for k in 8:
		var x0 := k * 170.0
		var pts := PackedVector2Array()
		for j in 18:
			pts.append(Vector2(x0 + j * 10.0, 70.0 + sin(j * 0.6 + k) * 6.0))
		c.draw_polyline(pts, Color(0.3, 0.6, 0.3), 3.0, true)
		for j in range(2, 18, 4):
			c.draw_circle(pts[j] + Vector2(0, -6), 4.0, Color(0.85, 0.35, 0.3))
	c.draw_rect(Rect2(0, r.size.y - 5, W, 8), GOLD.darkened(0.25))
	c.draw_line(Vector2(0, r.size.y - 5), Vector2(W, r.size.y - 5), GOLD.lightened(0.3), 2.0)


func _star(c: Vector2, rad: float, col: Color, rot: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := rot - PI / 2.0 + i * PI / 5.0
		var rr := rad if i % 2 == 0 else rad * 0.42
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	_root.draw_colored_polygon(pts, col)


## Täytetty ellipsi; clip rajaa pisteet maalauksen sisään (kukkulat eivät valu kehyksen yli).
func _ellipse(c: Vector2, rx: float, ry: float, col: Color, rot := 0.0, clip := Rect2()) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		var v := c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
		if clip.has_area():
			v = Vector2(clampf(v.x, clip.position.x, clip.end.x), clampf(v.y, clip.position.y, clip.end.y))
		pts.append(v)
	_root.draw_colored_polygon(pts, col)


func _draw_painting(id: String, r: Rect2) -> void:
	var c := _root
	var sh := 3.0 * sin(_t * 40.0) * _wobble  # hutiklikkauksen värähdys
	var rr := Rect2(r.position + Vector2(sh, 0), r.size)
	MG.box(c, rr.grow(14), GOLD.darkened(0.15), 6, 10, INK, 3)
	c.draw_rect(rr.grow(8), GOLD.lightened(0.15), false, 4.0)
	match id:
		"taivas":
			_paint_taivas(rr)
		"arkki":
			_paint_arkki(rr)
		"puutarha":
			_paint_puutarha(rr)
	# Maalauksen vanha lakkapinta: reunoille tummennus ja halkeamaviiva.
	MG.grad_rect(c, Rect2(rr.position, Vector2(rr.size.x, 26)), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0))
	MG.grad_rect(c, Rect2(rr.position + Vector2(0, rr.size.y - 26), Vector2(rr.size.x, 26)), Color(0, 0, 0, 0), Color(0, 0, 0, 0.3))
	c.draw_rect(rr, INK, false, 2.0)
	for k in ITEMS:
		if ITEMS[k].frame == id:
			_draw_item(k, rr.position + ITEMS[k].at, 1.0, true)


func _paint_taivas(r: Rect2) -> void:
	var c := _root
	MG.grad_rect(c, r, Color(0.45, 0.68, 0.88), Color(0.85, 0.9, 0.92))
	var sun := r.position + Vector2(90, 90)
	for k in 14:
		var a := k * TAU / 14.0
		c.draw_line(sun + Vector2(cos(a), sin(a)) * 42, sun + Vector2(cos(a), sin(a)) * 74, Color(0.98, 0.8, 0.25), 4.0)
	MG.ball(c, sun, 38.0, Color(0.98, 0.82, 0.3), 0.4)
	for p in [Vector2(210, 60), Vector2(70, 190), Vector2(260, 150)]:
		var q: Vector2 = r.position + p
		for o in [Vector2(-22, 6), Vector2(0, -6), Vector2(22, 6), Vector2(0, 8)]:
			_ellipse(q + o, 26, 16, Color(0.96, 0.95, 0.9))
	# Kukkulat ja talo.
	for h in [[Vector2(70, 340), 150.0, 80.0, Color(0.35, 0.58, 0.3)], [Vector2(250, 360), 170.0, 90.0, Color(0.28, 0.5, 0.26)]]:
		_ellipse(r.position + h[0], h[1], h[2], h[3], 0.0, r)
	MG.solid(c, Rect2(r.position + Vector2(150, 262), Vector2(54, 40)), Color(0.75, 0.3, 0.25))
	c.draw_colored_polygon(PackedVector2Array([r.position + Vector2(144, 264), r.position + Vector2(177, 232), r.position + Vector2(210, 264)]), Color(0.4, 0.24, 0.16))
	c.draw_rect(Rect2(r.position + Vector2(168, 280), Vector2(14, 22)), Color(0.3, 0.2, 0.12))
	MG.grad_rect(c, Rect2(r.position + Vector2(0, 340), Vector2(r.size.x, 50)), Color(0.25, 0.45, 0.22), Color(0.18, 0.34, 0.16))
	# Pieniä lintuviivoja taivaalla.
	for p in [Vector2(150, 40), Vector2(290, 110), Vector2(40, 130)]:
		var q: Vector2 = r.position + p
		c.draw_polyline(PackedVector2Array([q + Vector2(-8, -2), q + Vector2(-3, -6), q, q + Vector2(3, -6), q + Vector2(8, -2)]), INK, 1.5, true)


func _paint_arkki(r: Rect2) -> void:
	var c := _root
	MG.grad_rect(c, r, Color(0.6, 0.62, 0.7), Color(0.42, 0.5, 0.6))
	# Sateenkaari.
	var rc := r.position + Vector2(r.size.x / 2.0, 300)
	var cols := [Color(0.85, 0.3, 0.28), Color(0.95, 0.65, 0.25), Color(0.95, 0.9, 0.4), Color(0.45, 0.7, 0.35), Color(0.35, 0.55, 0.8)]
	for i in cols.size():
		c.draw_arc(rc, 170.0 - i * 11.0, PI, TAU, 40, cols[i], 11.0, true)
	# Meri.
	MG.grad_rect(c, Rect2(r.position + Vector2(0, 250), Vector2(r.size.x, 140)), Color(0.18, 0.38, 0.5), Color(0.1, 0.22, 0.34))
	for row in 6:
		var y := 262.0 + row * 24.0
		for k in 11:
			var x := float(k * 40 + (row % 2) * 20)
			if x < 16.0 or x > r.size.x - 16.0:
				continue
			c.draw_arc(r.position + Vector2(x, y), 14.0, PI * 1.1, PI * 1.9, 10, Color(0.6, 0.78, 0.86, 0.7), 2.0, true)
	# Arkki: runko, ohjaamo, ikkunat, mastoviiri.
	var hull := PackedVector2Array([r.position + Vector2(100, 220), r.position + Vector2(330, 220), r.position + Vector2(300, 280), r.position + Vector2(130, 280)])
	c.draw_colored_polygon(hull, Color(0.5, 0.3, 0.17))
	c.draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[3], hull[0]]), INK, 2.5, true)
	for k in 5:
		c.draw_line(r.position + Vector2(112 + k * 45, 226), r.position + Vector2(125 + k * 40, 276), Color(0.35, 0.2, 0.1), 1.5)
	MG.solid(c, Rect2(r.position + Vector2(170, 160), Vector2(150, 64)), Color(0.72, 0.5, 0.3))
	c.draw_colored_polygon(PackedVector2Array([r.position + Vector2(160, 162), r.position + Vector2(245, 118), r.position + Vector2(330, 162)]), Color(0.55, 0.28, 0.2))
	for k in 3:
		c.draw_rect(Rect2(r.position + Vector2(188 + k * 42, 182), Vector2(22, 24)), Color(0.2, 0.25, 0.32))
	c.draw_line(r.position + Vector2(245, 118), r.position + Vector2(245, 86), INK, 2.5)
	c.draw_colored_polygon(PackedVector2Array([r.position + Vector2(245, 88), r.position + Vector2(280, 98), r.position + Vector2(245, 108)]), Color(0.85, 0.25, 0.2))
	# Aallot rungon edessä.
	for k in 9:
		c.draw_arc(r.position + Vector2(100 + k * 28, 280), 16.0, PI * 1.05, PI * 1.95, 10, Color(0.7, 0.85, 0.9), 3.0, true)


func _paint_puutarha(r: Rect2) -> void:
	var c := _root
	MG.grad_rect(c, r, Color(0.7, 0.85, 0.7), Color(0.4, 0.62, 0.32))
	MG.grad_rect(c, Rect2(r.position + Vector2(0, 250), Vector2(r.size.x, 140)), Color(0.34, 0.56, 0.26), Color(0.2, 0.4, 0.18))
	# Iso puu: runko ja lehvästö.
	var tx := r.position + Vector2(220, 250)
	c.draw_colored_polygon(PackedVector2Array([tx + Vector2(-18, 0), tx + Vector2(-9, -130), tx + Vector2(9, -130), tx + Vector2(20, 0)]), Color(0.42, 0.28, 0.16))
	for o in [Vector2(-60, -150), Vector2(0, -190), Vector2(55, -150), Vector2(-25, -120), Vector2(30, -110), Vector2(0, -150)]:
		_ellipse(tx + o, 52, 40, Color(0.22, 0.45, 0.2))
	for o in [Vector2(-60, -155), Vector2(5, -195), Vector2(50, -152), Vector2(-20, -122), Vector2(28, -108)]:
		_ellipse(tx + o + Vector2(-6, -6), 38, 28, Color(0.3, 0.55, 0.24))
	for p in [Vector2(-40, -140), Vector2(30, -180), Vector2(60, -130), Vector2(-10, -105)]:
		c.draw_circle(tx + p, 6.0, Color(0.85, 0.3, 0.25))  # omenat
	# Nurmi, kukat ja aita.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 90:
		var p := r.position + Vector2(rng.randf_range(6, r.size.x - 6), rng.randf_range(262, 384))
		c.draw_line(p, p + Vector2(rng.randf_range(-3, 3), -rng.randf_range(8, 15)), Color(0.18, 0.4, 0.15), 2.0)
	for p in [Vector2(40, 300), Vector2(110, 360), Vector2(280, 330), Vector2(300, 370), Vector2(176, 302)]:
		var q: Vector2 = r.position + p
		c.draw_line(q, q + Vector2(0, 26), Color(0.2, 0.42, 0.16), 3.0)
		for k in 5:
			var a := k * TAU / 5.0
			c.draw_circle(q + Vector2(cos(a), sin(a)) * 7.0, 5.0, Color(0.95, 0.75, 0.82))
		c.draw_circle(q, 4.0, Color(0.95, 0.8, 0.3))


## Piilokuva: piirretään maalaukseen (scale 1, hidden) tai lokerikkoon (suurempana). Löytymätön maalauksessa vain pienenä ja maalauksen sävyisenä.
func _draw_item(id: String, p: Vector2, s: float, in_painting: bool, tint := Color.WHITE) -> void:
	var c := _root
	var ink := INK if in_painting else Color(0.12, 0.09, 0.06)
	match id:
		"tahti":
			_star(p, 11.0 * s, Color(1.0, 0.93, 0.55) * tint, 0.0)
			c.draw_arc(p, 11.0 * s, 0, TAU, 5, ink, 1.0)
		"kala":
			_ellipse(p, 17.0 * s, 8.0 * s, Color(0.42, 0.7, 0.72) * tint)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(14, 0) * s, p + Vector2(28, -9) * s, p + Vector2(28, 9) * s]), Color(0.36, 0.62, 0.66) * tint)
			c.draw_circle(p + Vector2(-9, -2) * s, 2.2 * s, ink)
			c.draw_line(p + Vector2(-2, -6) * s, p + Vector2(4, 6) * s, Color(0.3, 0.55, 0.6) * tint, 1.5)
		"kissa":
			_ellipse(p + Vector2(0, 7) * s, 11.0 * s, 9.0 * s, Color(0.9, 0.55, 0.2) * tint)
			c.draw_circle(p + Vector2(0, -5) * s, 7.5 * s, Color(0.92, 0.58, 0.24) * tint)
			for sx in [-1.0, 1.0]:
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(sx * 3, -10) * s, p + Vector2(sx * 8, -17) * s, p + Vector2(sx * 8.5, -7) * s]), Color(0.9, 0.52, 0.2) * tint)
				c.draw_circle(p + Vector2(sx * 3, -6) * s, 1.4 * s, ink)
			c.draw_polyline(PackedVector2Array([p + Vector2(10, 10) * s, p + Vector2(18, 8) * s, p + Vector2(20, -2) * s]), Color(0.88, 0.5, 0.2) * tint, 3.0 * s, true)
		"lintu":
			_ellipse(p, 13.0 * s, 8.0 * s, Color(0.25, 0.55, 0.62) * tint, -0.2)
			c.draw_circle(p + Vector2(-11, -5) * s, 6.0 * s, Color(0.28, 0.58, 0.64) * tint)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -6) * s, p + Vector2(-23, -4) * s, p + Vector2(-16, -2) * s]), Color(0.95, 0.5, 0.2) * tint)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(10, 0) * s, p + Vector2(24, 6) * s, p + Vector2(11, 5) * s]), Color(0.2, 0.45, 0.52) * tint)
			c.draw_circle(p + Vector2(-12, -6) * s, 1.4 * s, ink)
		"avain":
			var key := Color(0.85, 0.7, 0.25) * tint
			c.draw_arc(p + Vector2(-12, 0) * s, 6.0 * s, 0, TAU, 14, key, 3.0 * s, true)
			c.draw_line(p + Vector2(-6, 0) * s, p + Vector2(18, 0) * s, key, 3.0 * s)
			c.draw_line(p + Vector2(13, 0) * s, p + Vector2(13, 6) * s, key, 3.0 * s)
			c.draw_line(p + Vector2(18, 0) * s, p + Vector2(18, 5) * s, key, 3.0 * s)
		"etana":
			c.draw_line(p + Vector2(-14, 8) * s, p + Vector2(12, 8) * s, Color(0.7, 0.62, 0.5) * tint, 5.0 * s)
			c.draw_line(p + Vector2(-14, 6) * s, p + Vector2(-17, -2) * s, Color(0.7, 0.62, 0.5) * tint, 1.5)
			c.draw_circle(p + Vector2(3, 0) * s, 9.0 * s, Color(0.62, 0.42, 0.25) * tint)
			c.draw_arc(p + Vector2(3, 0) * s, 5.0 * s, 0, TAU * 0.8, 12, Color(0.4, 0.25, 0.14) * tint, 1.8)


func _draw_found_ring(id: String) -> void:
	var p := _item_pos(id)
	_root.draw_arc(p, 25.0, 0, TAU, 28, Color(1, 0.9, 0.35, 0.9), 3.0, true)
	_root.draw_arc(p, 28.0, 0, TAU, 28, INK, 1.5, true)


## Löydettävien lokerikko: siluetti ennen löytöä, väri ja kultakehys löydön jälkeen.
func _draw_tray() -> void:
	var c := _root
	MG.box(c, Rect2(32, 626, 330, 70), Color(0.2, 0.13, 0.08), 8, 6, GOLD.darkened(0.2), 2)
	var ids: Array = ITEMS.keys()
	for i in ids.size():
		var r := Rect2(42 + i * 52, 634, 46, 46)
		var got: bool = found.has(ids[i])
		MG.box(c, r, Color(0.95, 0.9, 0.75) if got else Color(0.1, 0.07, 0.05), 6, 0, GOLD if got else GOLD.darkened(0.5), 2)
		_draw_item(ids[i], r.get_center() - Vector2(0, 0), 1.0 if ids[i] != "kala" else 0.9, false, Color.WHITE if got else Color(0.06, 0.06, 0.06))
	c.draw_string(ThemeDB.fallback_font, Vector2(900, 672), "%d / %d" % [found.size(), ITEMS.size()], HORIZONTAL_ALIGNMENT_CENTER, 340, 56, Color(1, 0.93, 0.6))
	c.draw_string(ThemeDB.fallback_font, Vector2(900, 696), "piilokuvaa löydetty", HORIZONTAL_ALIGNMENT_CENTER, 340, 20, Color(0.9, 0.85, 0.7))


## Suurennuslasi hiiren kohdalla: linssin ympärillä vanha messinkirengas, kahva alaoikealle, vaalea heijastus.
func _draw_lens(p: Vector2) -> void:
	var c := _root
	c.draw_line(p + Vector2(18, 18), p + Vector2(50, 50), Color(0.35, 0.22, 0.12), 9.0)
	c.draw_line(p + Vector2(18, 18), p + Vector2(50, 50), Color(0.55, 0.38, 0.2), 4.0)
	c.draw_circle(p, 22.0, Color(0.85, 0.95, 1.0, 0.12))
	c.draw_arc(p, 22.0, 0, TAU, 32, Color(0.75, 0.58, 0.22), 5.0, true)
	c.draw_arc(p, 25.0, 0, TAU, 32, INK, 1.5, true)
	c.draw_arc(p, 14.0, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, 0.7), 3.0, true)
