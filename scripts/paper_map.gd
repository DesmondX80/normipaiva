extends Control
## Paperikarttanäkymä (M): kellertävä paperi taitoksineen, maastokartan värit ja merkit,
## paikannimet, tienimet, kompassiruusu, mittakaava ja selite. Peli on pysäytettynä kun kartta on auki.
## W/S tai hiiren rulla vierittää, M tai Esc sulkee. Klikkaus asettaa kompassin kohteen (tarttuu lähimpään
## merkkiin), klikkaus kohteen päälle tai oikea nappi poistaa sen.

const M := preload("res://scripts/map_data.gd")
const Mokki := preload("res://scripts/mokki.gd")

const MAP_W := 600.0
const INK := Color(0.22, 0.16, 0.1)
const PAPER := Color(0.93, 0.88, 0.74)
const MOKKI_RANGE := 110.0  # metriä keskeltä mökin kartan reunaan (alue 200 x 200 m)

var world: Node3D
var player: Node3D
var bike: Node3D
var game: Node  # main.gd: stash_markers()
var mokki: Node3D

var _view: Control
var _k := MAP_W / (M.SIZE.x * M.SCALE)
var _k_m := MAP_W / (MOKKI_RANGE * 2.0)
var _scroll := 0.0
var _paper_tex: ImageTexture
var _tree_pts: PackedVector2Array = []
## Kompassin kohde maailman x/z-koordinaatteina.
var has_target := false
var target := Vector2.ZERO

const SNAP_PX := 14.0
var _in_mokki := false  # avattaessa: ollaanko mökin taskussa -> näytä lähikartta kyläkartan sijaan


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_paper_tex = _make_paper()
	_view = Control.new()
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_view.draw.connect(_draw_map)
	resized.connect(_layout)
	_layout.call_deferred()


func _layout() -> void:
	var paper := _paper_rect()
	_view.position = Vector2(paper.position.x + 40, paper.position.y + 80)
	_view.size = Vector2(MAP_W, paper.size.y - 130)
	_scroll = clampf(_scroll, 0.0, _max_scroll())
	queue_redraw()
	_view.queue_redraw()


func _paper_rect() -> Rect2:
	# Oma koko voi olla vielä 0 tai vanhentunut (piilossa ollessa), joten käytetään viewportin kokoa.
	var s := get_viewport_rect().size
	if s.x <= 0:
		s = size if size.x > 0 else Vector2(1280, 720)
	var w := MAP_W + 80 + 260
	return Rect2(Vector2((s.x - w) / 2.0, 14), Vector2(w, s.y - 28))


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Koko lasketaan aina avattaessa: resized-signaali ei välttämättä tullut oikeaan aikaan.
		size = get_viewport_rect().size
		_layout()
		_in_mokki = mokki != null and player.global_position.distance_to(mokki.global_position) < 420.0
		if _in_mokki:
			_scroll = 0.0
		else:
			if _tree_pts.is_empty() and world != null:
				for i in range(0, world._trees.size(), 7):
					var t: Array = world._trees[i]
					if t[3]:
						_tree_pts.append(t[0])
			# Keskitetään pelaajaan.
			var p := _to_map(player.global_position)
			_scroll = clampf(p.y - _view.size.y / 2.0, 0.0, _max_scroll())
		Sfx.play("whoosh", -8.0, 1.6)
	queue_redraw()
	_view.queue_redraw()


func _max_scroll() -> float:
	if _in_mokki:
		return 0.0
	return maxf(0.0, M.SIZE.y * M.SCALE * _k - _view.size.y)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("map") or (visible and Input.is_key_pressed(KEY_ESCAPE)):
		toggle()
	if not visible:
		return
	var v := Input.get_axis("forward", "back")
	if v != 0.0:
		_scroll = clampf(_scroll + v * 600.0 * delta, 0.0, _max_scroll())
		_view.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click(event.position - _view.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			clear_target()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = clampf(_scroll - 60.0, 0.0, _max_scroll())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = clampf(_scroll + 60.0, 0.0, _max_scroll())
		_view.queue_redraw()


func clear_target() -> void:
	has_target = false
	_view.queue_redraw()


func _click(local: Vector2) -> void:
	if not Rect2(Vector2.ZERO, _view.size).has_point(local):
		return
	if has_target and _w2(target).distance_to(local) < SNAP_PX:
		clear_target()
		return
	var best := _from_view(local)
	var bd := SNAP_PX
	for w in _snap_points():
		var d := _w2(w).distance_to(local)
		if d < bd:
			bd = d
			best = w
	target = best
	has_target = true
	Sfx.play("whoosh", -14.0, 2.4)
	_view.queue_redraw()


## Kartan merkit, joihin klikkaus tarttuu (maailman x/z).
func _snap_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in [M.HOME_ZONE, M.SHOP_ZONE, M.LAAVU, M.GRILLIKATOS, M.KOTA]:
		out.append(M.w2(p))
	for n in M.PLACE_NAMES:
		out.append(M.w2(n[1]))
	if bike != null and bike != player:
		out.append(Vector2(bike.global_position.x, bike.global_position.z))
	if world != null and world.forage_revealed:
		for f in world.forage:
			if not f.taken:
				out.append(Vector2(f.pos.x, f.pos.z))
	return out


# --- Koordinaatit ------------------------------------------------------------

func _to_map(v: Vector3) -> Vector2:
	var lo := M.w2(Vector2.ZERO)
	return (Vector2(v.x, v.z) - lo) * _k


func _px(p: Vector2) -> Vector2:
	return (M.w2(p) - M.w2(Vector2.ZERO)) * _k - Vector2(0, _scroll)


func _w2(p: Vector2) -> Vector2:
	return (p - M.w2(Vector2.ZERO)) * _k - Vector2(0, _scroll)


func _from_view(local: Vector2) -> Vector2:
	return (local + Vector2(0, _scroll)) / _k + M.w2(Vector2.ZERO)


func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(_px(p))
	return out


## Mökin paikallinen koordinaatti (metrit mökin origosta) näkymän pikseleiksi, 200 m alueen keskipiste keskellä.
func _pxl(local: Vector2) -> Vector2:
	return Mokki.to_map2(local) * _k_m + _view.size / 2.0  # pohjoinen ylös (karttakehys)


func _ellipse_on(ci: CanvasItem, local_center: Vector2, rx: float, rz: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32
		pts.append(_pxl(local_center + Vector2(cos(a) * rx, sin(a) * rz)))
	ci.draw_colored_polygon(pts, col)


# --- Paperi ja kehys ---------------------------------------------------------

func _make_paper() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.frequency = 0.012
	n.fractal_octaves = 5
	var fine := FastNoiseLite.new()
	fine.frequency = 0.25
	var img := Image.create(512, 512, false, Image.FORMAT_RGB8)
	for y in 512:
		for x in 512:
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var f := fine.get_noise_2d(x, y) * 0.5 + 0.5
			var c := PAPER.darkened(0.18 * (1.0 - v) + 0.05 * f)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var r := _paper_rect()
	draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.35))
	draw_texture_rect(_paper_tex, r, false)
	# Taitokset: vaaleat ja tummat viivat ristiin.
	for i in range(1, 3):
		var x := r.position.x + r.size.x * i / 3.0
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(1, 1, 1, 0.25), 3.0)
		draw_line(Vector2(x + 2, r.position.y), Vector2(x + 2, r.end.y), Color(0, 0, 0, 0.08), 2.0)
	var y := r.position.y + r.size.y / 2.0
	draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.25), 3.0)
	draw_line(Vector2(r.position.x, y + 2), Vector2(r.end.x, y + 2), Color(0, 0, 0, 0.08), 2.0)
	# Kahvitahra.
	draw_arc(r.position + Vector2(r.size.x - 90, r.size.y - 150), 34.0, 0.3, TAU - 0.4, 40, Color(0.45, 0.28, 0.1, 0.18), 5.0)
	# Karttakehys.
	var mv := Rect2(_view.position - Vector2(4, 4), _view.size + Vector2(8, 8))
	draw_rect(mv, INK, false, 2.0)
	draw_rect(mv.grow(5), INK, false, 1.0)

	var font := ThemeDB.fallback_font
	if _in_mokki:
		draw_string(font, r.position + Vector2(40, 46), "NEITTÄVÄ · MÖKKI PAAPELI", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
		draw_string(font, r.position + Vector2(40, 68), "Kaisuantie 62, Vaala · 200 × 200 m (OpenStreetMap, MML)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK.lightened(0.2))
	else:
		draw_string(font, r.position + Vector2(40, 46), "SALOINEN · RAAHE", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
		draw_string(font, r.position + Vector2(40, 68), "Normipäivän maastokartta — Järvikuja 1 ja ympäristö", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK.lightened(0.2))

	var side := Vector2(_view.position.x + MAP_W + 30, _view.position.y)
	_compass(side + Vector2(100, 70))
	if _in_mokki:
		_scale_bar(side + Vector2(10, 180), 50.0, _k_m)
		_legend_mokki(side + Vector2(10, 250))
		draw_string(font, Vector2(side.x + 10, r.end.y - 22), "M sulje", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK.lightened(0.3))
	else:
		_scale_bar(side + Vector2(10, 180), 100.0, _k)
		_legend(side + Vector2(10, 250))
		draw_string(font, Vector2(side.x + 10, r.end.y - 40), "Klikkaa: kompassin kohde", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK.lightened(0.3))
		draw_string(font, Vector2(side.x + 10, r.end.y - 22), "M sulje · W/S vieritä", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK.lightened(0.3))


func _compass(c: Vector2) -> void:
	var col := INK
	for k in 8:
		var a := TAU * k / 8.0 - PI / 2.0
		var len := 52.0 if k % 2 == 0 else 30.0
		var tip := c + Vector2(cos(a), sin(a)) * len
		var l := c + Vector2(cos(a - 0.35), sin(a - 0.35)) * 10.0
		var rr := c + Vector2(cos(a + 0.35), sin(a + 0.35)) * 10.0
		draw_colored_polygon(PackedVector2Array([c, l, tip]), col if k % 2 == 0 else col.lightened(0.4))
		draw_colored_polygon(PackedVector2Array([c, tip, rr]), Color(0.75, 0.15, 0.1) if k == 0 else col.lightened(0.55))
	draw_arc(c, 36.0, 0, TAU, 40, col, 1.5)
	draw_string(ThemeDB.fallback_font, c + Vector2(-7, -58), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.75, 0.15, 0.1))


func _scale_bar(p: Vector2, meters: float, k: float) -> void:
	var font := ThemeDB.fallback_font
	var seg := meters * k
	for i in 2:
		draw_rect(Rect2(p + Vector2(i * seg, 0), Vector2(seg, 8)), INK if i == 0 else PAPER.darkened(0.05))
	draw_rect(Rect2(p, Vector2(seg * 2, 8)), INK, false, 1.0)
	draw_string(font, p + Vector2(-2, 26), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	draw_string(font, p + Vector2(seg - 14, 26), "%d" % int(meters), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	draw_string(font, p + Vector2(seg * 2 - 20, 26), "%d m" % int(meters * 2.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)


func _legend(p: Vector2) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, p, "SELITE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	var items := [
		["road", "Maantie"], ["street", "Katu"], ["path", "Polku"], ["forest", "Metsä"], ["field", "Pelto"],
		["bog", "Suo, räme"], ["water", "Vesi"], ["home", "Koti"], ["shop", "K-Market"], ["laavu", "Laavu"], ["berry", "Marjapaikka"], ["mushroom", "Sienipaikka"], ["stash", "Kaljajemma"], ["target", "Kompassin kohde"], ["you", "Olet tässä"],
	]
	for i in items.size():
		var y := p.y + 20 + i * 20
		var sym := Vector2(p.x + 14, y)
		match items[i][0]:
			"road":
				draw_line(sym - Vector2(12, 0), sym + Vector2(12, 0), Color(0.45, 0.25, 0.1), 6.0)
				draw_line(sym - Vector2(12, 0), sym + Vector2(12, 0), Color(0.98, 0.86, 0.4), 3.0)
			"street":
				draw_line(sym - Vector2(12, 0), sym + Vector2(12, 0), INK, 2.0)
			"path":
				draw_dashed_line(sym - Vector2(12, 0), sym + Vector2(12, 0), INK, 1.5, 4.0)
			"forest":
				draw_rect(Rect2(sym - Vector2(12, 7), Vector2(24, 14)), Color(0.66, 0.76, 0.52))
				draw_circle(sym, 2.0, Color(0.3, 0.45, 0.25))
			"field":
				draw_rect(Rect2(sym - Vector2(12, 7), Vector2(24, 14)), Color(0.93, 0.82, 0.5))
			"bog":
				draw_rect(Rect2(sym - Vector2(12, 7), Vector2(24, 14)), Color(0.78, 0.84, 0.82))
				draw_line(sym - Vector2(8, 0), sym + Vector2(8, 0), Color(0.3, 0.5, 0.7), 1.0)
			"water":
				draw_rect(Rect2(sym - Vector2(12, 7), Vector2(24, 14)), Color(0.55, 0.72, 0.86))
			"home":
				_house_icon(sym, Color(0.8, 0.15, 0.1))
			"shop":
				draw_circle(sym, 7.0, Color(1.0, 0.45, 0.0))
				draw_string(font, sym + Vector2(-4, 5), "K", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
			"laavu":
				_laavu_icon(sym)
			"berry":
				for o in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -4)]:
					draw_circle(sym + o, 2.6, Color(0.8, 0.08, 0.1))
			"mushroom":
				draw_rect(Rect2(sym + Vector2(-1, -1), Vector2(2, 5)), Color(0.9, 0.86, 0.75))
				draw_colored_polygon(PackedVector2Array([sym + Vector2(-5, -1), sym + Vector2(0, -6), sym + Vector2(5, -1)]), Color(0.95, 0.65, 0.1))
			"stash":
				_stash_icon_on(self, sym)
			"target":
				_target_icon_on(self, sym)
			"you":
				_you_icon(sym, 0.0)
		draw_string(font, Vector2(p.x + 36, y + 5), items[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)


func _legend_mokki(p: Vector2) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, p, "SELITE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	var items := [
		["cottage", "Mökki"], ["sauna", "Savusauna"], ["kitchen", "Kesäkeittiö"], ["tub", "Poreamme"],
		["dart", "Tikkataulu"], ["dock", "Laituri"], ["taxi", "Taksipysäkki"], ["water", "Järvi"],
		["road", "Tie"], ["field", "Pelto"], ["house", "Naapuri"], ["you", "Olet tässä"],
	]
	for i in items.size():
		var y := p.y + 22 + i * 24
		var sym := Vector2(p.x + 14, y)
		match items[i][0]:
			"cottage":
				draw_rect(Rect2(sym - Vector2(12, 7), Vector2(24, 14)), Color(0.85, 0.83, 0.74))
				draw_rect(Rect2(sym - Vector2(12, 7), Vector2(24, 14)), INK, false, 1.0)
			"sauna":
				_house_icon(sym, Color(0.4, 0.22, 0.12))
			"tub":
				draw_circle(sym, 6.0, Color(0.2, 0.5, 0.55))
			"dart":
				draw_circle(sym, 5.0, Color(0.16, 0.28, 0.14))
				draw_circle(sym, 2.0, Color(0.85, 0.15, 0.1))
			"dock":
				draw_line(sym - Vector2(12, 0), sym + Vector2(12, 0), Color(0.5, 0.38, 0.24), 5.0)
			"taxi":
				draw_circle(sym, 7.0, Color(0.96, 0.78, 0.08))
				draw_string(font, sym + Vector2(-4, 5), "T", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.05, 0.05))
			"water":
				draw_rect(Rect2(sym - Vector2(12, 7), Vector2(24, 14)), Color(0.55, 0.72, 0.86))
			"kitchen":
				_house_icon(sym, Color(0.45, 0.6, 0.75))
			"road":
				draw_line(sym - Vector2(12, 0), sym + Vector2(12, 0), Color(0.62, 0.52, 0.36), 3.0)
			"field":
				draw_rect(Rect2(sym - Vector2(12, 7), Vector2(24, 14)), Color(0.86, 0.84, 0.6))
			"house":
				draw_rect(Rect2(sym - Vector2(7, 6), Vector2(14, 12)), Color(0.6, 0.55, 0.5))
			"you":
				_you_icon(sym, 0.0)
		draw_string(font, Vector2(p.x + 36, y + 5), items[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)


# --- Karttasisältö -----------------------------------------------------------

## Pelialueen ulkopuoli (koillinen ja lounas): vinoviivoitus ja merkintä, ettei tyhjä kulma näytä virheeltä.
## Piirretään karttakohteiden päälle, koska OSM-aineisto jatkuu pelialueen ulkopuolelle.
func _draw_unmapped(v: CanvasItem) -> void:
	var rects := [[Vector2(M.PLAY_AREA[1].x, 0), Vector2(M.SIZE.x, M.PLAY_AREA[2].y), true],
		[Vector2(0, M.PLAY_AREA[2].y), Vector2(M.PLAY_AREA[5].x, M.SIZE.y), false]]
	for rr in rects:
		var out_lo := _px(rr[0])
		var out_hi := _px(rr[1])
		var out_r := Rect2(out_lo, out_hi - out_lo)
		v.draw_rect(out_r, Color(0.8, 0.76, 0.64, 1.0))
		var hy := -out_r.size.x
		while hy < out_r.size.y:
			var a0 := out_r.position + Vector2(0, hy)
			var a1 := out_r.position + Vector2(out_r.size.x, hy + out_r.size.x)
			if a0.y < out_r.position.y:
				a0 = a0 + Vector2(out_r.position.y - a0.y, out_r.position.y - a0.y)
			if a1.y > out_r.end.y:
				a1 = a1 - Vector2(a1.y - out_r.end.y, a1.y - out_r.end.y)
			v.draw_line(a0, a1, Color(0.55, 0.48, 0.36, 0.5), 1.0)
			hy += 14.0
		v.draw_rect(out_r, INK, false, 1.5)
		if not rr[2]:
			continue
		var oc := out_r.get_center()
		for i in 2:
			var txt: String = ["KARTOITTAMATON", "(suota ja Pekan jäniksiä)"][i]
			var fs := 18 if i == 0 else 13
			var w := ThemeDB.fallback_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			v.draw_string(ThemeDB.fallback_font, oc + Vector2(-w / 2.0, i * 22.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


func _draw_map() -> void:
	if _in_mokki:
		_draw_mokki_map()
		return
	var v := _view
	v.draw_rect(Rect2(Vector2.ZERO, v.size), Color(0.95, 0.92, 0.82, 0.55))
	for f in M.FORESTS:
		v.draw_colored_polygon(_pts(f), Color(0.66, 0.76, 0.52, 0.9))
	for c in M.CLEARINGS:
		v.draw_colored_polygon(_pts(c), Color(0.9, 0.88, 0.74, 0.9))
	for f in M.FIELDS:
		var pts := _pts(f)
		v.draw_colored_polygon(pts, Color(0.93, 0.82, 0.5))
		v.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.7, 0.55, 0.25), 1.0)
	for b in M.BOGS:
		var pts := _pts(b)
		v.draw_colored_polygon(pts, Color(0.78, 0.84, 0.82))
		var lo := pts[0]
		var hi := pts[0]
		for p in pts:
			lo = lo.min(p)
			hi = hi.max(p)
		var yy := lo.y + 5.0
		while yy < hi.y:
			var xx := lo.x + fmod(yy * 7.0, 11.0)
			while xx < hi.x:
				if Geometry2D.is_point_in_polygon(Vector2(xx, yy), pts):
					v.draw_line(Vector2(xx, yy), Vector2(xx + 6, yy), Color(0.3, 0.5, 0.7, 0.8), 1.0)
				xx += 14.0
			yy += 6.0
	# Puumerkit metsiin.
	for t in _tree_pts:
		var p := _w2(t)
		if p.y > -5 and p.y < v.size.y + 5:
			v.draw_circle(p, 1.3, Color(0.35, 0.5, 0.28, 0.7))
	for w in M.WATER:
		var pts := _pts(w)
		v.draw_colored_polygon(pts, Color(0.55, 0.72, 0.86))
		v.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.2, 0.4, 0.65), 1.5)
	for s in M.STREAMS:
		v.draw_polyline(_pts(s), Color(0.2, 0.45, 0.75), 2.0)

	# Tiet: ensin ääriviivat, sitten täyttö.
	for pass_i in 2:
		for r in M.ROADS:
			var pts := _pts(r.pts)
			match r.type:
				"highway":
					v.draw_polyline(pts, Color(0.45, 0.2, 0.08) if pass_i == 0 else Color(0.95, 0.55, 0.2), 8.0 if pass_i == 0 else 5.0)
				"road":
					v.draw_polyline(pts, Color(0.45, 0.25, 0.1) if pass_i == 0 else Color(0.98, 0.86, 0.4), 6.0 if pass_i == 0 else 3.5)
				"street":
					if pass_i == 1:
						v.draw_polyline(pts, INK.lightened(0.15), 2.0)
				"path":
					if pass_i == 1:
						for i in pts.size() - 1:
							v.draw_dashed_line(pts[i], pts[i + 1], INK, 1.5, 5.0)
	# Talot pieninä mustina neliöinä.
	if world != null:
		for h in world._houses:
			var p := _w2(h)
			v.draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), INK)

	var font := ThemeDB.fallback_font
	for n in M.PLACE_NAMES:
		var p := _px(n[1])
		v.draw_string(font, p - Vector2(n[0].length() * 5.5, 0), n[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	# Tienimet tien suuntaisesti.
	for r in M.ROADS:
		if r.name == "":
			continue
		var pts: Array = r.pts
		var i := int(pts.size() / 2) - 1 if pts.size() > 2 else 0
		var a := _px(pts[i])
		var b := _px(pts[i + 1])
		var ang := (b - a).angle()
		if ang > PI / 2.0 or ang < -PI / 2.0:
			ang += PI
		v.draw_set_transform((a + b) / 2.0 + Vector2(0, -6).rotated(ang), ang)
		v.draw_string(font, Vector2(-r.name.length() * 3.2, 0), r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.35, 0.18, 0.08))
		v.draw_set_transform(Vector2.ZERO)
	_draw_unmapped(v)

	_house_icon_on(v, _px(M.HOME_ZONE), Color(0.8, 0.15, 0.1))
	v.draw_string(font, _px(M.HOME_ZONE) + Vector2(10, 4), "Järvikuja 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.1, 0.05))
	var sp := _px(M.SHOP_ZONE)
	v.draw_circle(sp, 8.0, Color(1.0, 0.45, 0.0))
	v.draw_string(font, sp + Vector2(-4, 5), "K", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	v.draw_string(font, sp + Vector2(12, 4), "K-Market", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.3, 0.0))
	# Arton merkitsemät marja- ja sienipaikat, käsin piirretyn näköisinä.
	if world != null and world.forage_revealed:
		for f in world.forage:
			var fp := _w2(Vector2(f.pos.x, f.pos.z))
			var col: Color = world.FORAGE_KINDS[f.kind].color
			if f.taken:
				v.draw_line(fp - Vector2(4, 4), fp + Vector2(4, 4), INK.lightened(0.4), 1.5)
				v.draw_line(fp + Vector2(-4, 4), fp + Vector2(4, -4), INK.lightened(0.4), 1.5)
			elif f.kind in ["puolukka", "mustikka"]:
				for o in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -4)]:
					v.draw_circle(fp + o, 2.6, col)
				v.draw_arc(fp + Vector2(0, -1), 8.0, 0, TAU, 16, Color(0.6, 0.1, 0.05, 0.7), 1.2)
			else:
				v.draw_rect(Rect2(fp + Vector2(-1, -1), Vector2(2, 5)), Color(0.9, 0.86, 0.75))
				v.draw_colored_polygon(PackedVector2Array([fp + Vector2(-5, -1), fp + Vector2(0, -6), fp + Vector2(5, -1)]), col)
				v.draw_arc(fp + Vector2(0, -1), 8.0, 0, TAU, 16, Color(0.6, 0.1, 0.05, 0.7), 1.2)
	_laavu_icon_on(v, _px(M.LAAVU))
	v.draw_string(font, _px(M.LAAVU) + Vector2(12, 4), "Laavu", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	_laavu_icon_on(v, _px(M.GRILLIKATOS))
	v.draw_string(font, _px(M.GRILLIKATOS) + Vector2(12, 4), "Grillikatos (turvapaikka)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.1, 0.4, 0.1))
	_laavu_icon_on(v, _px(M.KOTA))
	v.draw_string(font, _px(M.KOTA) + Vector2(-150, 4), "Kota ja lintutorni", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	if bike != null and bike != player:
		var bp := _w2(Vector2(bike.global_position.x, bike.global_position.z))
		for o in [-5.0, 5.0]:
			v.draw_arc(bp + Vector2(o, 2), 3.8, 0, TAU, 12, Color(0.1, 0.35, 0.7), 1.8)
		v.draw_line(bp + Vector2(-5, 2), bp + Vector2(0, -4), Color(0.1, 0.35, 0.7), 1.8)
		v.draw_line(bp + Vector2(0, -4), bp + Vector2(5, 2), Color(0.1, 0.35, 0.7), 1.8)
		v.draw_string(ThemeDB.fallback_font, bp + Vector2(10, 4), "Pyörä", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.1, 0.3, 0.6))
	# Käytetyt kaljajemmat: kotijemmat yhtenä merkkinä (ne ovat kartalla päällekkäin).
	if game != null:
		var home_n := 0
		var home_p := Vector2.ZERO
		var home_seen := false
		for m in game.stash_markers():
			if m[3]:
				home_n += m[2]
				home_p = m[0]
				home_seen = true
				continue
			var sp2 := _w2(m[0])
			_stash_icon_on(v, sp2)
			v.draw_string(font, sp2 + Vector2(8, 12), "%s %d" % [m[1], m[2]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.25, 0.05))
		if home_seen:
			var hp := _px(M.HOME_ZONE) + Vector2(10, 10)
			_stash_icon_on(v, hp)
			v.draw_string(font, hp + Vector2(8, 12), "jemmat %d" % home_n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.25, 0.05))
	if has_target:
		_target_icon_on(v, _w2(target))
	if player != null:
		var f := -player.global_transform.basis.z
		_you_icon_on(v, _w2(Vector2(player.global_position.x, player.global_position.z)), atan2(f.z, f.x) + PI / 2.0)


## Mökin oma lähikartta: piha, järvi ja rakennukset (ks. mokki.gd:n julkiset _LOCAL/_CENTER-vakiot).
func _draw_mokki_map() -> void:
	var v := _view
	var font := ThemeDB.fallback_font
	v.draw_rect(Rect2(Vector2.ZERO, v.size), Color(0.86, 0.88, 0.78, 0.55))
	# Oikean kartan kohteet (Mokki.map_data: OSM, 200 x 200 m): metsäalue, pellot, vesistöt nimineen, tiet ja rakennukset.
	var data: Dictionary = Mokki.map_data()
	var tr := func(poly: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in poly:
			out.append(_pxl(p))
		return out
	v.draw_colored_polygon(tr.call(data.area), Color(0.66, 0.76, 0.52, 0.9))
	for f in data.fields:
		v.draw_colored_polygon(tr.call(f), Color(0.86, 0.84, 0.6, 0.9))
	_ellipse_on(v, Mokki.YARD_CENTER, Mokki.YARD_R.x, Mokki.YARD_R.y, Color(0.9, 0.88, 0.74, 0.9))
	for i in data.water.size():
		var wp: PackedVector2Array = tr.call(data.water[i])
		v.draw_colored_polygon(wp, Color(0.55, 0.72, 0.86))
		var cen := Vector2.ZERO
		for p in wp:
			cen += p
		cen /= maxf(1.0, wp.size())
		if data.water_names[i] != "" and Rect2(Vector2.ZERO, v.size).has_point(cen):
			v.draw_string(font, cen + Vector2(-30, 0), data.water_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.15, 0.3, 0.5))
	for r in data.roads:
		var rp: PackedVector2Array = tr.call(r.pts)
		v.draw_polyline(rp, Color(0.62, 0.52, 0.36), 3.0 if r.type == "unclassified" else 2.0)
		if r.name != "" and rp.size() > 2:
			v.draw_string(font, rp[rp.size() / 2] + Vector2(4, -4), r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	for bd in data.buildings:
		if not (bd.id in Mokki.OWN_BUILDINGS):
			v.draw_colored_polygon(tr.call(bd.poly), Color(0.6, 0.55, 0.5))
	v.draw_polyline(tr.call(data.area) + PackedVector2Array([_pxl(data.area[0])]), INK, 1.5)

	var half := Mokki.COTTAGE_SIZE / 2.0
	var c := Mokki.COTTAGE_LOCAL
	var cottage := PackedVector2Array([
		_pxl(c + Vector2(-half.x, -half.y)), _pxl(c + Vector2(half.x, -half.y)),
		_pxl(c + Vector2(half.x, half.y)), _pxl(c + Vector2(-half.x, half.y)),
	])
	v.draw_colored_polygon(cottage, Color(0.85, 0.83, 0.74))
	v.draw_polyline(cottage + PackedVector2Array([cottage[0]]), INK, 1.5)
	v.draw_string(font, _pxl(c) + Vector2(-24, -18), "Mökki Paapeli", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)

	var sauna_p := _pxl(Vector2(Mokki.SAUNA_LOCAL.x, Mokki.SAUNA_LOCAL.z))
	_house_icon_on(v, sauna_p, Color(0.4, 0.22, 0.12))

	var tub_p := _pxl(Vector2(Mokki.TUB_LOCAL.x, Mokki.TUB_LOCAL.z))
	v.draw_circle(tub_p, 6.0, Color(0.2, 0.5, 0.55))

	var kitchen_p := _pxl(Vector2(Mokki.KITCHEN_LOCAL.x, Mokki.KITCHEN_LOCAL.z))
	_house_icon_on(v, kitchen_p, Color(0.45, 0.6, 0.75))

	var dart_p := _pxl(Vector2(Mokki.DART_LOCAL.x, Mokki.DART_LOCAL.z))
	v.draw_circle(dart_p, 5.0, Color(0.16, 0.28, 0.14))
	v.draw_circle(dart_p, 2.0, Color(0.85, 0.15, 0.1))

	var dock_a := _pxl(Vector2(Mokki.DOCK_LOCAL.x, Mokki.DOCK_LOCAL.z - 12.0))
	var dock_b := _pxl(Vector2(Mokki.DOCK_LOCAL.x, Mokki.DOCK_LOCAL.z))
	v.draw_line(dock_a, dock_b, Color(0.5, 0.38, 0.24), 5.0)
	v.draw_string(font, dock_b + Vector2(10, 4), "Laituri", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)

	var taxi_p := _pxl(Vector2(Mokki.TAXI_LOCAL.x, Mokki.TAXI_LOCAL.z))
	v.draw_circle(taxi_p, 7.0, Color(0.96, 0.78, 0.08))
	v.draw_string(font, taxi_p + Vector2(-4, 5), "T", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.05, 0.05))
	v.draw_string(font, taxi_p + Vector2(12, 4), "Taksipysäkki", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)

	var santtu_p := _pxl(Vector2(Mokki.SANTTU_LOCAL.x, Mokki.SANTTU_LOCAL.z))
	v.draw_circle(santtu_p, 4.0, Color(0.75, 0.55, 0.12))

	if player != null and mokki != null:
		var lp: Vector3 = mokki.to_local(player.global_position)
		var f := -player.global_transform.basis.z
		var fm := Mokki.to_map2(Vector2(f.x, f.z)) - Mokki.to_map2(Vector2.ZERO)  # suunta karttakehykseen
		_you_icon_on(v, _pxl(Vector2(lp.x, lp.z)), atan2(fm.y, fm.x) + PI / 2.0)


# --- Merkit (piirto joko tähän tai karttanäkymään) ----------------------------

func _house_icon(p: Vector2, col: Color) -> void:
	_house_icon_on(self, p, col)


func _house_icon_on(ci: CanvasItem, p: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(p + Vector2(-6, -2), Vector2(12, 9)), col)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -2), p + Vector2(0, -10), p + Vector2(8, -2)]), col.darkened(0.2))


func _laavu_icon(p: Vector2) -> void:
	_laavu_icon_on(self, p)


func _laavu_icon_on(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 6), p + Vector2(3, -8), p + Vector2(9, 6)]), Color(0.45, 0.28, 0.12))
	ci.draw_line(p + Vector2(-9, 6), p + Vector2(9, 6), INK, 2.0)
	ci.draw_circle(p + Vector2(-2, 3), 2.5, Color(0.95, 0.45, 0.1))


## Kaljapullo: ruskea runko ja kaula.
func _stash_icon_on(ci: CanvasItem, p: Vector2) -> void:
	var col := Color(0.45, 0.25, 0.05)
	ci.draw_rect(Rect2(p + Vector2(-3, -2), Vector2(6, 9)), col)
	ci.draw_rect(Rect2(p + Vector2(-1.2, -7), Vector2(2.4, 5)), col)
	ci.draw_rect(Rect2(p + Vector2(-3, 1), Vector2(6, 3)), Color(0.95, 0.85, 0.5))


func _target_icon_on(ci: CanvasItem, p: Vector2) -> void:
	var col := Color(0.85, 0.1, 0.1)
	ci.draw_arc(p, 9.0, 0, TAU, 24, col, 2.5)
	ci.draw_line(p - Vector2(5, 5), p + Vector2(5, 5), col, 2.0)
	ci.draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), col, 2.0)


func _you_icon(p: Vector2, ang: float) -> void:
	_you_icon_on(self, p, ang)


func _you_icon_on(ci: CanvasItem, p: Vector2, ang: float) -> void:
	var f := Vector2(0, -1).rotated(ang)
	var r := f.orthogonal()
	ci.draw_circle(p, 11.0, Color(0.85, 0.1, 0.1, 0.25))
	ci.draw_colored_polygon(PackedVector2Array([p + f * 10.0, p - f * 6.0 + r * 6.0, p - f * 2.0, p - f * 6.0 - r * 6.0]), Color(0.85, 0.1, 0.1))
