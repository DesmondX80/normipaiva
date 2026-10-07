extends Control
## Paperikarttanäkymä (M): kellertävä paperi taitoksineen, maastokartan värit ja merkit,
## paikannimet, tienimet, kompassiruusu, mittakaava ja selite. Peli on pysäytettynä kun kartta on auki.
## W/S, hiiren rulla tai vetäminen (myös sormella) vierittää, M tai Esc sulkee. Klikkaus asettaa kompassin kohteen (tarttuu lähimpään
## merkkiin), klikkaus kohteen päälle tai oikea nappi poistaa sen.
## Mökillä ja Vaalan mopomatkalla kartta on yksi iso Neittävä–Vaala-kartta mopomatkan kehyksessä (vaala.gd:
## origo mökin osoitepisteessä, x itään, z etelään): mökin piha, tie Vaalaan ja Vaalan keskusta kohteineen.
## Rulla, Q/E tai kahden sormen nipistys zoomaa, W/A/S/D tai vetäminen siirtää.

const M := preload("res://scripts/map_data.gd")
const Mokki := preload("res://scripts/mokki.gd")

const MAP_W := 600.0
const INK := Color(0.22, 0.16, 0.1)
const PAPER := Color(0.93, 0.88, 0.74)
const VAALA_MAASTO := "res://assets/vaala/maasto.bin"
const VAALA_TIE := "res://assets/vaala/tie.json"
const GASTHAUS_ID := 534430535  # vaala.gd
## Mökin oma kartta-aineisto (mokki.gd) piirretään tähän asti osoitepisteestä: sen jälkeen mopomatkan tie on
## tiivistetty (Neittäväntie ja Vuolijoentie), eikä 1:1-aineisto enää osu kohdalleen.
const MOKKI_DETAIL_R := 480.0
const VZOOM_MAX := 4.0  # px/m
## Mopomatkan tilat (main.gd state), joissa näytetään Neittävä–Vaala-kartta.

var world: Node3D
var player: Node3D
var bike: Node3D
var game: Node  # main.gd: stash_markers()
var mokki: Node3D
var mopo_trip: Node3D  # main.gd asettaa ensimmäisellä mopomatkalla

var _view: Control
var _k := MAP_W / (M.SIZE.x * M.SCALE)
var _scroll := 0.0
var _paper_tex: ImageTexture
var _tree_pts: PackedVector2Array = []
## Kompassin kohde maailman x/z-koordinaatteina.
var has_target := false
var target := Vector2.ZERO

const SNAP_PX := 14.0
var _vaala := false  # avattaessa: mökki tai Vaalan matka -> Neittävä–Vaala-kartta kyläkartan sijaan
var _vd := {}  # tie.json
var _vtex: ImageTexture  # tarkan maaston maankäyttö ja rinnevarjostus
var _vrect := Rect2()   # tarkan maaston alue (kehyksen x/z)
var _vbld_pts := PackedVector2Array()  # rakennusten kolmiot (kehyksen x/z), yksi piirtokutsu
var _vbld_idx := PackedInt32Array()
var _vbld_cols := PackedColorArray()
var _vpois: Array = []  # [nimi, paikka, laji, aina näkyvä]
var _vzoom := 0.3
var _vcenter := Vector2.ZERO
var _vdrag := false
var _vdragged := 0.0


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
		_vaala = _vaala_mode()
		if _vaala:
			_scroll = 0.0
			_vaala_load()
			_vfit()
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
	if _vaala:
		return 0.0
	return maxf(0.0, M.SIZE.y * M.SCALE * _k - _view.size.y)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("map") or (visible and Input.is_key_pressed(KEY_ESCAPE)):
		if visible or not get_tree().paused:  # ei repun tai valikon päälle
			toggle()
	if not visible:
		return
	if _vaala:
		var pan := Vector2(Input.get_axis("left", "right"), Input.get_axis("forward", "back"))
		var z := (1.0 if Input.is_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
		if pan != Vector2.ZERO or z != 0.0:
			_vcenter += pan * 420.0 * delta / _vzoom
			_vzoom_by(exp(z * 1.6 * delta), _view.size / 2.0)
		return
	var v := Input.get_axis("forward", "back")
	if v != 0.0:
		_scroll = clampf(_scroll + v * 600.0 * delta, 0.0, _max_scroll())
		_view.queue_redraw()


## Hiiren alla olevan nimetyn tien nimi (karttanäkymän koordinaateissa piirretään hiiren viereen).
var _hover_px := Vector2(-1000, -1000)
var _hover_name := ""
## Vetäminen (hiiri tai kosketuksen hiiriemulointi): lyhyt napautus on klikkaus, pidempi veto vierittää.
const DRAG_CLICK := 10.0
var _drag_on := false
var _dragged := 0.0
## Kahden sormen nipistys (Vaalan kartta): sormien paikat indeksin mukaan.
var _touches := {}
var _pinch_d := 0.0


func _input(event: InputEvent) -> void:
	if not visible or not _vaala:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_d = _pinch_dist()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_vdrag = false  # kaksi sormea: zoomaus, ei siirtoa
			var d := _pinch_dist()
			if _pinch_d > 1.0 and d > 1.0:
				var ps: Array = _touches.values()
				var mid: Vector2 = (ps[0] + ps[1]) / 2.0 - _view.global_position
				_vzoom_by(d / _pinch_d, mid)
			_pinch_d = d
			get_viewport().set_input_as_handled()


func _pinch_dist() -> float:
	if _touches.size() < 2:
		return 0.0
	var ps: Array = _touches.values()
	return (ps[0] as Vector2).distance_to(ps[1])


func _gui_input(event: InputEvent) -> void:
	if _vaala:
		_vaala_input(event)
		return
	if event is InputEventMouseMotion:
		if _drag_on and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_dragged += event.relative.length()
			if _dragged >= DRAG_CLICK:
				_scroll = clampf(_scroll - event.relative.y, 0.0, _max_scroll())
				_view.queue_redraw()
		_hover_px = event.position - _view.position
		var nm := _road_at(_hover_px)
		if nm != _hover_name or nm != "":
			_hover_name = nm
			_view.queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _drag_on and _dragged < DRAG_CLICK:
			_click(event.position - _view.position)  # napautus: kompassin kohde
		_drag_on = false
		_view.queue_redraw()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_drag_on = true
			_dragged = 0.0
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			clear_target()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = clampf(_scroll - 60.0, 0.0, _max_scroll())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = clampf(_scroll + 60.0, 0.0, _max_scroll())
		_hover_name = _road_at(_hover_px)
		_view.queue_redraw()


## Lähimmän nimetyn tien nimi, jos hiiri on alle 7 px päässä siitä (karttanäkymän px).
func _road_at(local: Vector2) -> String:
	if not Rect2(Vector2.ZERO, _view.size).has_point(local):
		return ""
	var best := 7.0
	var name := ""
	for r in M.ROADS:
		if r.name == "":
			continue
		var pts: Array = r.pts
		for i in pts.size() - 1:
			var d := local.distance_to(Geometry2D.get_closest_point_to_segment(local, _px(pts[i]), _px(pts[i + 1])))
			if d < best:
				best = d
				name = r.name
	return name


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


## Mökin paikallinen koordinaatti (metrit mökin origosta) Neittävä–Vaala-kartan pikseleiksi (pohjoinen ylös).
func _pxl(local: Vector2) -> Vector2:
	return _vpx(Mokki.to_map2(local))


## Mopomatkan kehyksen (x itään, z etelään, origo mökin osoitepisteessä) piste näkymän pikseleiksi.
func _vpx(p: Vector2) -> Vector2:
	return (p - _vcenter) * _vzoom + _view.size / 2.0


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
	if _vaala:
		draw_string(font, r.position + Vector2(40, 46), "NEITTÄVÄ – VAALA", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
		draw_string(font, r.position + Vector2(40, 68), "Mökki Paapeli (Kaisuantie 62) ja mopotie Vaalan keskustaan · OpenStreetMap, MML", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK.lightened(0.2))
	else:
		draw_string(font, r.position + Vector2(40, 46), "SALOINEN · RAAHE", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
		draw_string(font, r.position + Vector2(40, 68), "Normipäivän maastokartta — Järvikuja 1 ja ympäristö", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK.lightened(0.2))

	var side := Vector2(_view.position.x + MAP_W + 30, _view.position.y)
	_compass(side + Vector2(100, 70))
	if _vaala:
		var m := 50.0
		for cand in [50.0, 100.0, 200.0, 250.0, 500.0, 1000.0]:
			if cand * _vzoom <= 100.0:
				m = cand
		_scale_bar(side + Vector2(10, 180), m, _vzoom)
		_legend_vaala(side + Vector2(10, 250))
		draw_string(font, Vector2(side.x + 10, r.end.y - 58), "Rulla / Q E / nipistä: zoomaa", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK.lightened(0.3))
		draw_string(font, Vector2(side.x + 10, r.end.y - 40), "WASD / vedä: siirrä", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK.lightened(0.3))
		draw_string(font, Vector2(side.x + 10, r.end.y - 22), "M sulje", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK.lightened(0.3))
	else:
		_scale_bar(side + Vector2(10, 180), 100.0, _k)
		_legend(side + Vector2(10, 250))
		draw_string(font, Vector2(side.x + 10, r.end.y - 58), "Klikkaa: kompassin kohde", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK.lightened(0.3))
		draw_string(font, Vector2(side.x + 10, r.end.y - 40), "Vedä / W S / rulla: vieritä", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK.lightened(0.3))
		draw_string(font, Vector2(side.x + 10, r.end.y - 22), "M sulje", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK.lightened(0.3))


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


func _legend_vaala(p: Vector2) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, p, "SELITE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	var items := [
		["home", "Mökki Paapeli"], ["siitari", "Hotelli-Ravintola Siitari"], ["shop", "K-Market Tervaportti"],
		["smarket", "S-Market"], ["zabuki", "Zabuki (olut, burgerit)"], ["gasthaus", "Gasthaus (yö 10 €)"],
		["atm", "Pankkiautomaatti"], ["lava", "Oulujärven lava"], ["church", "Kirkko"], ["station", "Rautatieasema"],
		["road", "Maantie"], ["gravel", "Soratie"], ["rail", "Rautatie"], ["field", "Pelto"], ["bog", "Suo"],
		["water", "Vesi"], ["building", "Rakennus"], ["you", "Olet tässä"],
	]
	for i in items.size():
		var y := p.y + 17 + i * 15.0
		var sym := Vector2(p.x + 14, y)
		match items[i][0]:
			"road":
				draw_line(sym - Vector2(12, 0), sym + Vector2(12, 0), Color(0.45, 0.25, 0.1), 6.0)
				draw_line(sym - Vector2(12, 0), sym + Vector2(12, 0), Color(0.98, 0.86, 0.4), 3.0)
			"gravel":
				draw_line(sym - Vector2(12, 0), sym + Vector2(12, 0), Color(0.62, 0.52, 0.36), 3.0)
			"rail":
				_rail_on(self, PackedVector2Array([sym - Vector2(12, 0), sym + Vector2(12, 0)]), 3.0)
			"field":
				draw_rect(Rect2(sym - Vector2(12, 6), Vector2(24, 12)), Color(0.93, 0.82, 0.5))
			"bog":
				draw_rect(Rect2(sym - Vector2(12, 6), Vector2(24, 12)), Color(0.78, 0.84, 0.82))
				draw_line(sym - Vector2(8, 0), sym + Vector2(8, 0), Color(0.3, 0.5, 0.7), 1.0)
			"water":
				draw_rect(Rect2(sym - Vector2(12, 6), Vector2(24, 12)), Color(0.55, 0.72, 0.86))
			"building":
				draw_rect(Rect2(sym - Vector2(6, 5), Vector2(12, 10)), Color(0.42, 0.38, 0.34))
			"you":
				_you_icon(sym, 0.0)
			_:
				_poi_icon_on(self, sym, items[i][0])
		draw_string(font, Vector2(p.x + 36, y + 5), items[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)


# --- Karttasisältö -----------------------------------------------------------

func _draw_map() -> void:
	if _vaala:
		_draw_vaala_map()
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
	# Tienimet eivät tukkeuta karttaa: nimi näkyy vain, kun hiiri on tien päällä (_hover_road).

	# Naapurit (tarina lähettää heidän luokseen): pieni talomerkki ja nimi, nimet eri puolille ettei mene päällekkäin.
	for n in [[M.NEIGHBOR_PEKKA, "Pekka", Vector2(8, -2)], [M.NEIGHBOR_SINIKKA, "Sinikka", Vector2(8, 10)],
			[M.NEIGHBOR_ARTO, "Arto", Vector2(-10, 20)]]:
		var np := _px(n[0])
		_neighbor_icon_on(v, np)
		v.draw_string(font, np + n[2], n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.35, 0.22, 0.1))
	_house_icon_on(v, _px(M.HOME_ZONE), Color(0.8, 0.15, 0.1))
	v.draw_string(font, _px(M.HOME_ZONE) + Vector2(-78, 4), "Järvikuja 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.1, 0.05))
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
	if game != null and game.pontikka_found:  # löytyi droonin ilmakuvasta
		var pp := _px(M.PONTIKKA)
		v.draw_circle(pp, 5.0, Color(0.55, 0.2, 0.1))
		v.draw_arc(pp, 9.0, 0, TAU, 16, Color(0.55, 0.2, 0.1), 1.5)
		v.draw_string(font, pp + Vector2(12, 4), "Pontikkapannu (ilmakuva)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.15, 0.05))
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
	_draw_road_hover(v)


# --- Neittävä–Vaala-kartta --------------------------------------------------------------------------------------

## Mökillä tai Vaalan mopomatkalla (myös Siitarissa, Tervaportissa ja lavalla).
func _vaala_mode() -> bool:
	if game == null:
		return false
	if game._in_vaala:
		return true
	return game._at_mokki()


func _vaala_trip() -> bool:
	return mopo_trip != null and mopo_trip.mopo != null and \
		(game._in_vaala)


## Pelaajan paikka ja suunta kartan kehyksessä: mopolla (tai sen luona sisällä) mopon paikka, mökillä mökin
## paikallisesta kehyksestä osoitepisteen kehykseen.
func _vaala_me() -> Array:
	if _vaala_trip():
		var m: Node3D = mopo_trip.mopo
		var f := -m.global_transform.basis.z
		return [Vector2(m.position.x, m.position.z), atan2(f.z, f.x) + PI / 2.0]
	if mokki != null and player != null:
		var lp: Vector3 = mokki.to_local(player.global_position)
		var f := -player.global_transform.basis.z
		var fm := Mokki.to_map2(Vector2(f.x, f.z)) - Mokki.to_map2(Vector2.ZERO)
		return [Mokki.to_map2(Vector2(lp.x, lp.z)), atan2(fm.y, fm.x) + PI / 2.0]
	return []


## Koko alue näkyviin (mökki, tie ja Vaalan keskusta).
func _vfit() -> void:
	_vzoom = minf(_view.size.x / _vrect.size.x, _view.size.y / _vrect.size.y)
	_vcenter = _vrect.get_center()


func _vzoom_by(f: float, at: Vector2) -> void:
	var fit := minf(_view.size.x / _vrect.size.x, _view.size.y / _vrect.size.y)
	var before := (at - _view.size / 2.0) / _vzoom + _vcenter
	_vzoom = clampf(_vzoom * f, fit, VZOOM_MAX)
	_vcenter = before - (at - _view.size / 2.0) / _vzoom
	_vcenter = _vcenter.clamp(_vrect.position, _vrect.end)
	_view.queue_redraw()
	queue_redraw()  # mittakaava


func _vaala_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var local: Vector2 = event.position - _view.position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_vzoom_by(1.2, local)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_vzoom_by(1.0 / 1.2, local)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_vdrag = event.pressed
	elif event is InputEventMouseMotion and _vdrag:
		_vcenter = (_vcenter - event.relative / _vzoom).clamp(_vrect.position, _vrect.end)
		_view.queue_redraw()
	elif event is InputEventMagnifyGesture:
		_vzoom_by(event.factor, event.position - _view.position)
	elif event is InputEventPanGesture:
		_vcenter = (_vcenter + event.delta * 8.0 / _vzoom).clamp(_vrect.position, _vrect.end)
		_view.queue_redraw()


## Kerran: tie.json (mopomatkan oma, jos se on jo ladattu), maankäyttö ja rinnevarjostus maasto.bin:stä
## kuvaksi, rakennukset kolmioiksi ja kohteet.
func _vaala_load() -> void:
	if _vtex != null:
		return
	if mopo_trip != null:
		_vd = mopo_trip.vaala.data
	else:
		_vd = JSON.parse_string(FileAccess.get_file_as_string(VAALA_TIE))
	var f := FileAccess.open(VAALA_MAASTO, FileAccess.READ)
	var nx := f.get_32()
	var nz := f.get_32()
	var x0 := f.get_float()
	var z0 := f.get_float()
	var cell := f.get_float()
	var hts := f.get_buffer(nx * nz * 4).to_float32_array()
	var codes := f.get_buffer(nx * nz)
	_vrect = Rect2(x0 - cell / 2.0, z0 - cell / 2.0, nx * cell, nz * cell)
	# Koodit kuten vaala.gd: metsä, pelto, suo, vesi, piha, piennar, tie, rata. Tiivistys on leivottu saumattomaksi
	# (tools/kartta/vaala_warp.py), joten kartta piirretään sellaisenaan ilman merkintöjä.
	var pal := [Color(0.66, 0.76, 0.52), Color(0.93, 0.82, 0.5), Color(0.78, 0.84, 0.82), Color(0.55, 0.72, 0.86),
		Color(0.86, 0.85, 0.7), Color(0.84, 0.8, 0.68), Color(0.84, 0.8, 0.68), Color(0.7, 0.66, 0.6)]
	var px := PackedByteArray()
	px.resize(nx * nz * 3)
	for j in nz:
		for i in nx:
			var q := j * nx + i
			var c: int = codes[q]
			var col: Color = pal[c] if c < pal.size() else pal[0]
			if c != 3:
				# Rinnevarjostus luoteesta: kaakkoon nouseva rinne vaalea, luoteeseen nouseva tumma.
				var dx := hts[mini(q + 1, j * nx + nx - 1)] - hts[maxi(q - 1, j * nx)]
				var dz := hts[mini(q + nx, nx * nz - 1)] - hts[maxi(q - nx, 0)]
				col = col * clampf(1.0 + (dx + dz) * 0.07, 0.72, 1.18)
			px[q * 3] = clampi(int(col.r * 255.0), 0, 255)
			px[q * 3 + 1] = clampi(int(col.g * 255.0), 0, 255)
			px[q * 3 + 2] = clampi(int(col.b * 255.0), 0, 255)
	_vtex = ImageTexture.create_from_image(Image.create_from_data(nx, nz, false, Image.FORMAT_RGB8, px))
	# Rakennukset: kolmiot kerralla, nimetyt julkiset ja kaupat tummemman punaisina.
	for bd in _vd.buildings:
		var pts := PackedVector2Array()
		for q in bd.pts:
			pts.append(Vector2(q[0], q[1]))
		if pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.01:
			pts.remove_at(pts.size() - 1)
		var tris := Geometry2D.triangulate_polygon(pts)
		if tris.is_empty():
			continue
		var col := Color(0.42, 0.38, 0.34)
		if bd.name != "" or bd.type in ["church", "train_station", "civic", "school", "library", "hotel", "retail", "commercial"]:
			col = Color(0.55, 0.22, 0.16)
		var base := _vbld_pts.size()
		_vbld_pts.append_array(pts)
		for t in tris:
			_vbld_idx.append(base + t)
		for k in pts.size():
			_vbld_cols.append(col)
	if _vd.has("lava"):
		var lc := Vector2(_vd.lava.x, _vd.lava.z)
		var lh := Vector2(_vd.lava.w, _vd.lava.l) / 2.0
		var base := _vbld_pts.size()
		_vbld_pts.append_array(PackedVector2Array([lc - lh, lc + Vector2(lh.x, -lh.y), lc + lh, lc + Vector2(-lh.x, lh.y)]))
		_vbld_idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		for k in 4:
			_vbld_cols.append(Color(0.55, 0.16, 0.11))
	# Kohteet: [nimi, paikka, laji, aina nimellä].
	_vpois = [["Mökki Paapeli", Mokki.to_map2(Mokki.COTTAGE_LOCAL), "home", true],
		["Siitari", Vector2(_vd.siitari[0], _vd.siitari[1]), "siitari", true]]
	if _vd.has("lava"):
		_vpois.append(["Oulujärven lava", Vector2(_vd.lava.x, _vd.lava.z), "lava", true])
	for bd in _vd.buildings:
		var nm: String = bd.name
		if nm == "" and bd.type != "train_station" and int(bd.id) != GASTHAUS_ID:
			continue
		var cen := Vector2.ZERO
		for q in bd.pts:
			cen += Vector2(q[0], q[1])
		cen /= float(bd.pts.size())
		if nm.contains("K-Market"):
			_vpois.append(["K-Market Tervaportti", cen, "shop", true])
		elif nm.contains("S-market"):
			_vpois.append(["S-Market", cen, "smarket", false])
		elif int(bd.id) == GASTHAUS_ID:
			_vpois.append(["Gasthaus", cen, "gasthaus", false])
		elif bd.type == "train_station":
			_vpois.append([nm if nm != "" else "Rautatieasema", cen, "station", false])
		elif bd.type == "church" or nm.ends_with("kirkko"):
			_vpois.append([nm, cen, "church", nm.ends_with("kirkko")])
		else:
			_vpois.append([nm, cen, "named", false])
	var tori := _vaala_tori()
	if tori[0] != Vector2.INF:
		_vpois.append(["Tori", tori[0], "label", false])
		_vpois.append(["Zabuki", tori[1], "zabuki", false])
	if _vd.get("underpass") != null:
		var u: Dictionary = _vd.underpass
		_vpois.append(["Radan alikulku", Vector2(u.at[0], u.at[1]), "label", false])
	if _vd.bridges.size() > 1:
		var br: Array = _vd.bridges[_vd.bridges.size() - 1]
		var a: Array = _vd.road[br[0]]
		var b: Array = _vd.road[br[1]]
		_vpois.append(["Oulujoen silta", Vector2((a[0] + b[0]) / 2.0, (a[2] + b[2]) / 2.0), "label", false])


## Vaalan tori ja Zabuki kuten vaala.gd _tori_prep: [torin keskipiste, Zabukin paikka] (INF, jos toria ei ole).
func _vaala_tori() -> Array:
	var pts := PackedVector2Array()
	for r in _vd.side_roads:
		if r.name == "Vaalan tori":
			for q in r.pts:
				pts.append(Vector2(q[0], q[1]))
	if pts.size() < 3:
		return [Vector2.INF, Vector2.INF]
	var c := Vector2.ZERO
	for q in pts:
		c += q
	c /= pts.size()
	if mopo_trip != null and mopo_trip.vaala.door_pos("zabuki") != Vector3.ZERO:
		var zp: Vector3 = mopo_trip.vaala.door_pos("zabuki")
		return [c, Vector2(zp.x, zp.z)]
	var at := Vector2.INF
	for bd in _vd.buildings:
		if bd.kind != "shed":
			continue
		var b := Vector2.ZERO
		for q in bd.pts:
			b += Vector2(q[0], q[1])
		b /= bd.pts.size()
		if b.distance_to(c) < 30.0 and b.distance_to(c) < at.distance_to(c):
			at = b
	return [c, at if at != Vector2.INF else c + Vector2(0, -12.0)]


func _draw_vaala_map() -> void:
	var v := _view
	var font := ThemeDB.fallback_font
	var forest := Color(0.66, 0.76, 0.52)
	v.draw_rect(Rect2(Vector2.ZERO, v.size), forest.darkened(0.04))
	if _vtex == null:
		return
	v.draw_texture_rect(_vtex, Rect2(_vpx(_vrect.position), _vrect.size * _vzoom), false)
	if _vaala_trip():
		_draw_mokki_overlay(v)
	var wz := func(half: float, lo: float, hi: float) -> float: return clampf(half * 2.0 * _vzoom, lo, hi)

	# Sivutiet ja rata.
	for r in _vd.side_roads:
		var pts := PackedVector2Array()
		for q in r.pts:
			pts.append(_vpx(Vector2(q[0], q[1])))
		if r.kind == "rail":
			_rail_on(v, pts, wz.call(1.6, 2.5, 5.0))
		elif r.hw in ["footway", "cycleway", "path", "pedestrian", "track"]:
			if _vzoom > 0.6:
				for i in pts.size() - 1:
					v.draw_dashed_line(pts[i], pts[i + 1], INK.lightened(0.2), 1.2, 4.0)
		elif r.hw in ["secondary", "tertiary", "residential"] or r.surface in ["asphalt", "paved"]:
			v.draw_polyline(pts, INK.lightened(0.15), wz.call(3.0, 1.6, 7.0))
			v.draw_polyline(pts, Color(0.97, 0.95, 0.88), wz.call(3.0, 1.6, 7.0) - 1.4)
		else:
			v.draw_polyline(pts, Color(0.62, 0.52, 0.36), wz.call(2.2, 1.4, 5.0))
	for br in _vd.branches:
		var pts := PackedVector2Array()
		for q in br.pts:
			pts.append(_vpx(Vector2(q[0], q[2])))
		v.draw_polyline(pts, Color(0.62, 0.52, 0.36) if br.gravel else INK.lightened(0.15), wz.call(br.hw, 1.6, 6.0))
	if _vd.has("lava") and _vd.lava.road.size() >= 2:
		# Asfaltoitu ajotie Pahalahdentieltä ja aita joelta Pahalahteen (portti tiellä).
		var lr: Array = _vd.lava.road
		var la := _vpx(Vector2(lr[0][0], lr[0][1]))
		var lb := _vpx(Vector2(lr[1][0], lr[1][1]))
		v.draw_line(la, lb, INK.lightened(0.15), wz.call(2.2, 1.6, 6.0))
		v.draw_line(la, lb, Color(0.97, 0.95, 0.88), wz.call(2.2, 1.6, 6.0) - 1.4)
		if _vd.lava.has("fence") and _vzoom > 0.6:
			var fp := PackedVector2Array()
			for q in _vd.lava.fence:
				fp.append(_vpx(Vector2(q[0], q[1])))
			v.draw_polyline(fp, Color(0.6, 0.08, 0.05), 1.5)

	# Mopotie: sora (Uutelanperäntie) ruskeana, asfaltti maantien värein, sillat tummalla reunalla.
	var road: Array = _vd.road
	var line := PackedVector2Array()
	for q in road:
		line.append(_vpx(Vector2(q[0], q[2])))
	var w: float = wz.call(3.6, 4.0, 11.0)
	v.draw_polyline(line, Color(0.45, 0.2, 0.08), w + 2.5)
	var run_start := 0
	for i in range(1, road.size() + 1):
		if i == road.size() or road[i][5] != road[run_start][5]:
			var seg := line.slice(run_start, mini(i + 1, road.size()))
			v.draw_polyline(seg, Color(0.84, 0.72, 0.5) if road[run_start][5] == 1 else Color(0.98, 0.86, 0.4), w)
			run_start = i
	for br in _vd.bridges:
		var seg := line.slice(br[0], br[1] + 1)
		v.draw_polyline(seg, INK, w + 5.0)
		v.draw_polyline(seg, Color(0.98, 0.86, 0.4), w)

	# Rakennukset kerralla.
	if not _vbld_idx.is_empty():
		var bp := PackedVector2Array()
		bp.resize(_vbld_pts.size())
		for i in _vbld_pts.size():
			bp[i] = _vpx(_vbld_pts[i])
		RenderingServer.canvas_item_add_triangle_array(v.get_canvas_item(), _vbld_idx, bp, _vbld_cols)

	# Tienimet kylteistä (tien suuntaisesti).
	for sg in _vd.signs:
		if sg.kind != "street":
			continue
		var i: int = clampi(sg.i + 8, 1, road.size() - 2)
		_road_label(v, line[i - 1], line[i + 1], sg.text, Color(0.35, 0.18, 0.08), 12, -8.0 - w / 2.0)
	for r in _vd.side_roads:
		if r.name == "" or r.pts.size() < 3 or (_vzoom < 0.9 and r.name != "Pahalahdentie"):
			continue
		var k: int = r.pts.size() / 2
		_road_label(v, _vpx(Vector2(r.pts[k - 1][0], r.pts[k - 1][1])), _vpx(Vector2(r.pts[k][0], r.pts[k][1])), r.name,
			Color(0.35, 0.18, 0.08), 11, -6.0)

	# Paikannimet.
	var sx: float = _vd.siitari[0]
	var sz: float = _vd.siitari[1]
	_place(v, "VAALA", _vpx(Vector2(sx + 150.0, sz - 260.0)), 26)
	_place(v, "NEITTÄVÄ", _vpx(Vector2(-120.0, 120.0)), 20)
	for sg in _vd.signs:
		if sg.kind == "river":
			var q: Array = road[sg.i]
			_place(v, "Oulujoki", _vpx(Vector2(q[0] - 140.0, q[2] + 40.0)), 15, Color(0.15, 0.3, 0.55))

	# Kohteet: tärkeät aina nimellä, muut zoomatessa.
	for poi in _vpois:
		var p := _vpx(poi[1])
		if not Rect2(Vector2(-60, -20), v.size + Vector2(120, 40)).has_point(p):
			continue
		var kind: String = poi[2]
		if kind == "home" and _vzoom >= 1.2:
			continue  # mökin pihan omat merkit näkyvät
		if kind == "named":
			if _vzoom < 0.9:
				continue
			v.draw_circle(p, 2.5, Color(0.55, 0.22, 0.16))
			var tw := font.get_string_size(poi[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			v.draw_string(font, p + (Vector2(-6 - tw, 4) if p.x + 6 + tw > v.size.x - 4 else Vector2(6, 4)), poi[0],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK.lightened(0.1))
			continue
		if kind == "label":
			if _vzoom >= 0.7:
				v.draw_string(font, p + Vector2(10, 14), poi[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK.lightened(0.1))
			continue
		_poi_icon_on(v, p, kind)
		if poi[3] or _vzoom >= 0.9:
			var col := Color(0.7, 0.3, 0.0) if kind == "shop" else (Color(0.6, 0.08, 0.05) if kind in ["siitari", "lava", "home", "zabuki", "gasthaus"]
				else (Color(0.1, 0.45, 0.2) if kind == "smarket" else INK))
			var tw := font.get_string_size(poi[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			_outlined(v, p + (Vector2(-12 - tw, 5) if p.x + 12 + tw > v.size.x - 4 else Vector2(12, 5)), poi[0], 13, col)
	if mopo_trip != null and mopo_trip.vaala.atm_pos != Vector3.ZERO:
		var ap: Vector3 = mopo_trip.vaala.atm_pos
		_poi_icon_on(v, _vpx(Vector2(ap.x, ap.z)) + Vector2(0, 14), "atm")

	# Mökillä mökin koko kävelyalue omasta aineistostaan kaiken päälle (mopomatkan tiivistetty kartta jää alle).
	if not _vaala_trip():
		_draw_mokki_overlay(v)
	# Mopo: mökin pihassa tai Vaalassa parkissa; pelaaja.
	var me := _vaala_me()
	if mokki != null and not _vaala_trip() and mokki.mopo_parked != null and mokki.mopo_parked.visible:
		var lp: Vector3 = mokki.to_local(mokki.mopo_parked.global_position)
		_mopo_icon_on(v, _pxl(Vector2(lp.x, lp.z)))
	if not me.is_empty():
		_you_icon_on(v, _vpx(me[0]), me[1])


## Mökin oma kartta-aineisto (mokki.gd, 1:1) osoitepisteen ympäriltä: järvet nimineen, pellot, suot, tiet ja
## naapurit; zoomatessa mökin piha merkkeineen.
func _draw_mokki_overlay(v: Control) -> void:
	var font := ThemeDB.fallback_font
	var data: Dictionary = Mokki.map_data()
	# Mökillä koko kävelyalue (pohjoiseen Salmisille ja Keskimmäiselle) mökin omasta 1:1-aineistosta mopomatkan
	# tiivistetyn kartan päälle; matkalla vain mökin lähiympäristö.
	var whole := not _vaala_trip()
	var area: PackedVector2Array = data.area
	if whole:
		var ap := PackedVector2Array()
		for q in area:
			ap.append(_pxl(q))
		v.draw_colored_polygon(ap, Color(0.66, 0.76, 0.52))
		v.draw_polyline(ap + PackedVector2Array([ap[0]]), INK.lightened(0.4), 1.0)
	var inside := func(p: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(p, area) if whole else Mokki.to_map2(p).length() < MOKKI_DETAIL_R
	var near := func(poly: PackedVector2Array) -> bool:
		var cen := Vector2.ZERO
		for p in poly:
			cen += p
		cen /= maxf(1.0, poly.size())
		return inside.call(cen)
	var tr := func(poly: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in poly:
			out.append(_pxl(p))
		return out
	for fl in data.fields:
		if near.call(fl):
			v.draw_colored_polygon(tr.call(fl), Color(0.93, 0.82, 0.5))
	for b in data.bogs:
		if near.call(b):
			v.draw_colored_polygon(tr.call(b), Color(0.78, 0.84, 0.82))
	for i in data.water.size():
		if not near.call(data.water[i]):
			continue
		var wp: PackedVector2Array = tr.call(data.water[i])
		v.draw_colored_polygon(wp, Color(0.55, 0.72, 0.86))
		v.draw_polyline(wp + PackedVector2Array([wp[0]]), Color(0.2, 0.4, 0.65), 1.0)
		var cen := Vector2.ZERO
		for p in wp:
			cen += p
		cen /= maxf(1.0, wp.size())
		if data.water_names[i] != "" and (_vzoom >= 0.5 or wp.size() > 40):
			_place(v, data.water_names[i], cen, 12, Color(0.15, 0.3, 0.55))
	for r in data.roads:
		var seg := PackedVector2Array()
		for p in r.pts:
			if inside.call(p):
				seg.append(_pxl(p))
			elif seg.size() > 1:
				v.draw_polyline(seg, Color(0.55, 0.42, 0.26), 2.5)
				seg = PackedVector2Array()
			else:
				seg = PackedVector2Array()
		if seg.size() > 1:
			v.draw_polyline(seg, Color(0.62, 0.52, 0.36), 2.0)
	for bd in data.buildings:
		if not (bd.id in Mokki.OWN_BUILDINGS) and near.call(bd.poly):
			v.draw_colored_polygon(tr.call(bd.poly), Color(0.42, 0.38, 0.34))
	if whole and mokki != null and mokki.built:
		var sites := [["Salmisen uimaranta", mokki.beach_pos, "beach"], ["Ranta-Rosvo", mokki.rosvo_pos, "statue"],
			["Laavu ja tynnyrisauna", mokki.laavu_fire, "laavu"], ["Laituri ja soutuvene", mokki.north_dock, "dock"]]
		for st in sites:
			var p3: Vector3 = st[1]
			if p3 == Vector3.ZERO:
				continue
			var sp := _pxl(Vector2(p3.x, p3.z))
			_poi_icon_on(v, sp, st[2])
			if _vzoom >= 0.5 and st[2] != "dock" or _vzoom >= 1.2:
				_outlined(v, sp + Vector2(10, 5), st[0], 12, Color(0.12, 0.25, 0.5))
	if _vzoom < 1.2:
		return
	# Piha lähempää: mökki, savusauna, palju, kesäkeittiö, tikkataulu, laituri, Pekan auto, Santtu ja riistapolku.
	var labels := _vzoom >= 2.0
	_ellipse_on(v, Mokki.YARD_CENTER, Mokki.YARD_R.x, Mokki.YARD_R.y, Color(0.9, 0.88, 0.74, 0.9))
	var half := Mokki.COTTAGE_SIZE / 2.0
	var c := Mokki.COTTAGE_LOCAL
	var cottage := PackedVector2Array([
		_pxl(c + Vector2(-half.x, -half.y)), _pxl(c + Vector2(half.x, -half.y)),
		_pxl(c + Vector2(half.x, half.y)), _pxl(c + Vector2(-half.x, half.y)),
	])
	v.draw_colored_polygon(cottage, Color(0.24, 0.15, 0.09))
	v.draw_polyline(cottage + PackedVector2Array([cottage[0]]), INK, 1.5)
	_outlined(v, _pxl(c) + Vector2(-24, -18), "Mökki Paapeli", 13, Color(0.6, 0.08, 0.05))
	var at := func(p3: Vector3) -> Vector2: return _pxl(Vector2(p3.x, p3.z))
	_house_icon_on(v, at.call(Mokki.SAUNA_LOCAL), Color(0.4, 0.22, 0.12))
	v.draw_circle(at.call(Mokki.TUB_LOCAL), 5.0, Color(0.2, 0.5, 0.55))
	_house_icon_on(v, at.call(Mokki.KITCHEN_LOCAL), Color(0.45, 0.6, 0.75))
	var dart_p: Vector2 = at.call(Mokki.DART_LOCAL)
	v.draw_circle(dart_p, 4.0, Color(0.16, 0.28, 0.14))
	v.draw_circle(dart_p, 1.6, Color(0.85, 0.15, 0.1))
	var dock_a := _pxl(Vector2(Mokki.DOCK_LOCAL.x, Mokki.DOCK_LOCAL.z - 12.0))
	var dock_b: Vector2 = at.call(Mokki.DOCK_LOCAL)
	v.draw_line(dock_a, dock_b, Color(0.5, 0.38, 0.24), 4.0)
	var ride_p: Vector2 = at.call(Mokki.RIDE_LOCAL)
	v.draw_circle(ride_p, 6.0, Color(0.3, 0.42, 0.24))
	v.draw_string(font, ride_p + Vector2(-4, 5), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.95, 0.9))
	v.draw_circle(at.call(Mokki.SANTTU_LOCAL), 3.5, Color(0.75, 0.55, 0.12))
	var hunt_p: Vector2 = at.call(Mokki.HUNT_LOCAL)
	v.draw_circle(hunt_p, 4.5, Color(0.3, 0.24, 0.15))
	# Santun kertomat marja- ja sienipaikat.
	if game != null and game.mokki_forage_revealed:
		for f in game.mokki_forage:
			var fp := _pxl(f.local)
			var col: Color = Mokki.FORAGE_COLORS[f.kind]
			if f.taken:
				v.draw_line(fp - Vector2(3, 3), fp + Vector2(3, 3), INK.lightened(0.4), 1.2)
				v.draw_line(fp + Vector2(-3, 3), fp + Vector2(3, -3), INK.lightened(0.4), 1.2)
			else:
				v.draw_circle(fp, 3.2, col)
				v.draw_arc(fp, 6.0, 0, TAU, 14, Color(0.6, 0.1, 0.05, 0.7), 1.0)
	if labels:
		v.draw_string(font, at.call(Mokki.SAUNA_LOCAL) + Vector2(10, 4), "Savusauna", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
		v.draw_string(font, dock_b + Vector2(8, 4), "Laituri", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
		v.draw_string(font, ride_p + Vector2(10, 4), "Pekan auto", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
		v.draw_string(font, hunt_p + Vector2(8, 4), "Riistapolku", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)


## Teksti tien suuntaisesti (luettavaan suuntaan), keskellä pisteiden a ja b välissä, siirrettynä sivulle.
func _road_label(v: CanvasItem, a: Vector2, b: Vector2, text: String, col: Color, fs: int, side: float) -> void:
	var font := ThemeDB.fallback_font
	var ang := (b - a).angle()
	if ang > PI / 2.0 or ang < -PI / 2.0:
		ang += PI
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	v.draw_set_transform((a + b) / 2.0 + Vector2(0, side).rotated(ang), ang)
	v.draw_string_outline(font, Vector2(-tw / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(PAPER, 0.8))
	v.draw_string(font, Vector2(-tw / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	v.draw_set_transform(Vector2.ZERO)


func _place(v: CanvasItem, text: String, p: Vector2, fs: int, col := INK) -> void:
	var tw := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_outlined(v, p - Vector2(tw / 2.0, 0), text, fs, col)


func _outlined(v: CanvasItem, p: Vector2, text: String, fs: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	v.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(PAPER, 0.85))
	v.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Hiiren alla olevan tien nimi pienessä lapussa hiiren vieressä (kutsutaan _draw_mapin lopusta).
func _draw_road_hover(v: Control) -> void:
	if _hover_name == "":
		return
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(_hover_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var at := _hover_px + Vector2(12, -10)
	at.x = minf(at.x, v.size.x - w - 12)
	v.draw_rect(Rect2(at - Vector2(5, 14), Vector2(w + 10, 19)), Color(0.98, 0.95, 0.85, 0.95))
	v.draw_rect(Rect2(at - Vector2(5, 14), Vector2(w + 10, 19)), Color(0.35, 0.18, 0.08), false, 1.0)
	v.draw_string(font, at, _hover_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.35, 0.18, 0.08))


# --- Merkit (piirto joko tähän tai karttanäkymään) ----------------------------

## Neittävä–Vaala-kartan kohteiden merkit.
func _poi_icon_on(ci: CanvasItem, p: Vector2, kind: String) -> void:
	var font := ThemeDB.fallback_font
	match kind:
		"home":
			_house_icon_on(ci, p, Color(0.8, 0.15, 0.1))
		"siitari":
			ci.draw_rect(Rect2(p - Vector2(8, 7), Vector2(16, 14)), Color(0.55, 0.05, 0.06))
			ci.draw_string(font, p + Vector2(-4, 5), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.92, 0.6))
		"shop":
			ci.draw_circle(p, 8.0, Color(1.0, 0.45, 0.0))
			ci.draw_string(font, p + Vector2(-4, 5), "K", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		"beach":
			# Aurinkovarjo hiekalla.
			ci.draw_rect(Rect2(p + Vector2(-8, 3), Vector2(16, 4)), Color(0.9, 0.8, 0.5))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -3), p + Vector2(0, -9), p + Vector2(8, -3)]), Color(0.9, 0.2, 0.2))
			ci.draw_line(p + Vector2(0, -3), p + Vector2(0, 4), INK, 1.5)
		"statue":
			ci.draw_rect(Rect2(p + Vector2(-5, 2), Vector2(10, 5)), Color(0.45, 0.43, 0.42))
			ci.draw_circle(p + Vector2(0, -7), 2.5, Color(0.42, 0.3, 0.16))
			ci.draw_line(p + Vector2(0, -5), p + Vector2(0, 2), Color(0.42, 0.3, 0.16), 3.0)
		"laavu":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 6), p + Vector2(-2, -7), p + Vector2(8, 6)]), Color(0.45, 0.33, 0.2))
			ci.draw_circle(p + Vector2(5, 8), 2.5, Color(0.95, 0.5, 0.1))
		"dock":
			ci.draw_line(p + Vector2(-6, 0), p + Vector2(6, 0), Color(0.5, 0.38, 0.24), 4.0)
		"smarket":
			ci.draw_circle(p, 8.0, Color(0.1, 0.5, 0.25))
			ci.draw_string(font, p + Vector2(-4, 5), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		"zabuki":
			# Oluttuoppi: keltainen lasi, vaahto ja kahva.
			ci.draw_rect(Rect2(p + Vector2(-5, -6), Vector2(9, 13)), Color(0.95, 0.7, 0.15))
			ci.draw_rect(Rect2(p + Vector2(-5, -8), Vector2(9, 3)), Color(1.0, 0.98, 0.9))
			ci.draw_arc(p + Vector2(5, 0), 3.5, -PI / 2, PI / 2, 8, INK, 2.0)
			ci.draw_rect(Rect2(p + Vector2(-5, -8), Vector2(9, 15)), INK, false, 1.0)
		"gasthaus":
			# Sänky: runko, tyyny ja peitto.
			ci.draw_rect(Rect2(p + Vector2(-9, -6), Vector2(18, 12)), Color(0.2, 0.25, 0.45))
			ci.draw_rect(Rect2(p + Vector2(-7, -1), Vector2(14, 5)), Color(0.95, 0.93, 0.85))
			ci.draw_rect(Rect2(p + Vector2(-7, -4), Vector2(5, 3)), Color(1, 1, 1))
		"atm":
			ci.draw_rect(Rect2(p - Vector2(6, 5), Vector2(12, 10)), Color(0.1, 0.45, 0.25))
			ci.draw_string(font, p + Vector2(-4, 4), "€", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		"lava":
			# Punamullattu tanssilava: pitkä runko ja matala harjakatto.
			ci.draw_rect(Rect2(p + Vector2(-9, -3), Vector2(18, 9)), Color(0.55, 0.16, 0.11))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-11, -3), p + Vector2(0, -9), p + Vector2(11, -3)]), Color(0.36, 0.12, 0.1))
			for x in [-5.0, 0.0, 5.0]:
				ci.draw_rect(Rect2(p + Vector2(x - 1.5, -1), Vector2(3, 3)), Color(0.98, 0.85, 0.5))
		"church":
			ci.draw_line(p + Vector2(0, -9), p + Vector2(0, 7), INK, 2.5)
			ci.draw_line(p + Vector2(-5, -4), p + Vector2(5, -4), INK, 2.5)
		"station":
			ci.draw_rect(Rect2(p - Vector2(9, 4), Vector2(18, 8)), INK)
			for x in [-6.0, 0.0]:
				ci.draw_rect(Rect2(p + Vector2(x, -2), Vector2(4, 4)), PAPER)


## Rautatie: musta viiva valkoisin välein.
func _rail_on(ci: CanvasItem, pts: PackedVector2Array, w: float) -> void:
	ci.draw_polyline(pts, INK, w)
	for i in pts.size() - 1:
		ci.draw_dashed_line(pts[i], pts[i + 1], Color(0.95, 0.93, 0.85), w - 1.5, 6.0)


## Mopo sivulta: kaksi rengasta ja runko.
func _mopo_icon_on(ci: CanvasItem, p: Vector2) -> void:
	var col := Color(0.15, 0.3, 0.6)
	for o in [-5.0, 5.0]:
		ci.draw_circle(p + Vector2(o, 2), 3.2, col)
	ci.draw_rect(Rect2(p + Vector2(-5, -4), Vector2(10, 4)), col)


func _house_icon(p: Vector2, col: Color) -> void:
	_house_icon_on(self, p, col)


func _house_icon_on(ci: CanvasItem, p: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(p + Vector2(-6, -2), Vector2(12, 9)), col)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -2), p + Vector2(0, -10), p + Vector2(8, -2)]), col.darkened(0.2))


## Naapurin talo: pieni ruskea talomerkki.
func _neighbor_icon_on(ci: CanvasItem, p: Vector2) -> void:
	var col := Color(0.55, 0.35, 0.15)
	ci.draw_rect(Rect2(p + Vector2(-4, -1), Vector2(8, 6)), col)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-5.5, -1), p + Vector2(0, -6), p + Vector2(5.5, -1)]), col.darkened(0.2))


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
