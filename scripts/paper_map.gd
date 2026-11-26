extends Control
## Paperikarttanäkymä (M): kellertävä paperi taitoksineen, maastokartan värit ja merkit,
## paikannimet, tienimet, kompassiruusu, mittakaava ja selite. Peli on pysäytettynä kun kartta on auki.
## Kartta zoomataan ja siirretään samalla tavalla: rulla zoomaa hiiren kohtaan, kello/toiminto (Q/E) tai
## kahden sormen nipistys zoomaa, W/A/S/D tai vetäminen siirtää, hyppy (välilyönti) keskittää pelaajaan, M tai Esc
## sulkee. Kyläkartalla klikkaus asettaa kompassin kohteen (tarttuu lähimpään merkkiin), klikkaus kohteen päälle tai
## oikea nappi poistaa sen.

const M := preload("res://scripts/map_data.gd")
const Kolmio := preload("res://scripts/kolmiomittaus.gd")

const MAP_W := 600.0
const INK := Color(0.22, 0.16, 0.1)
const PAPER := Color(0.93, 0.88, 0.74)

var world: Node3D
var player: Node3D
var bike: Node3D
var game: Node  # main.gd: stash_markers()

var _view: Control
var _paper_tex: ImageTexture
var _tree_pts: PackedVector2Array = []
## Kompassin kohde maailman x/z-koordinaatteina.
var has_target := false
var target := Vector2.ZERO

const SNAP_PX := 14.0
var _vland: Control  # maanpeite kartan alla (show_behind_parent), oma materiaali
## Näkymä: _vrect = kartan alue (maailman x/z), _vcenter
## keskipiste samassa kehyksessä, _vzoom pikseliä metrille.
var _vrect := Rect2()
var _vzoom := 0.3
const ZOOM_OPEN := 0.6  # kyläkartta avattaessa (px/m), pelaaja keskellä
var _vcenter := Vector2.ZERO


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
	_vland = Control.new()
	_vland.show_behind_parent = true
	_vland.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vland.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.add_child(_vland)
	resized.connect(_layout)
	_layout.call_deferred()


func _layout() -> void:
	var paper := _paper_rect()
	_view.position = Vector2(paper.position.x + 40, paper.position.y + 80)
	_view.size = Vector2(MAP_W, paper.size.y - 130)
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
		if _tree_pts.is_empty() and world != null:
			pass
		var lo := M.w2(M.MAP_MIN)
		_vrect = Rect2(lo, M.w2(M.SIZE) - lo).abs()
		_vzoom = maxf(ZOOM_OPEN, _fit_zoom())
		_center_on_me()  # rajaa myös reunat
		Sfx.play("whoosh", -8.0, 1.6)
	queue_redraw()
	_view.queue_redraw()


## Keskipiste niin, ettei kartan reuna siirry näkymän sisään: kun kartta on näkymää kapeampi (zoom kaukana),
## se on keskellä.
func _clamped(c: Vector2) -> Vector2:
	var half := _view.size / 2.0 / _vzoom
	var out := c
	for ax in 2:
		out[ax] = clampf(c[ax], _vrect.position[ax] + half[ax], _vrect.end[ax] - half[ax])
	return out


## Pienin zoom: koko kartta näkyy.
func _fit_zoom() -> float:
	return minf(_view.size.x / _vrect.size.x, _view.size.y / _vrect.size.y)


## Näkymä pelaajan kohdalle (maailman x/z).
func _center_on_me() -> void:
	if player != null:
		_vcenter = Vector2(player.global_position.x, player.global_position.z)
	_vcenter = _clamped(_vcenter)
	_view.queue_redraw()
	queue_redraw()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("map") or (visible and Input.is_key_pressed(KEY_ESCAPE)):
		if visible or not get_tree().paused:  # ei repun tai valikon päälle
			toggle()
	if not visible:
		return
	var pan := Vector2(Input.get_axis("left", "right"), Input.get_axis("forward", "back"))
	var z := Input.get_action_strength("interact") - Input.get_action_strength("bell")  # E lähemmäs, Q kauemmas
	if pan != Vector2.ZERO or z != 0.0:
		_vcenter = _clamped(_vcenter + pan * 420.0 * delta / _vzoom)
		_vzoom_by(exp(z * 1.6 * delta), _view.size / 2.0)
	if Input.is_action_just_pressed("jump"):
		_center_on_me()

## Hiiren alla olevan nimetyn tien nimi (karttanäkymän koordinaateissa piirretään hiiren viereen).
var _hover_px := Vector2(-1000, -1000)
var _hover_name := ""
## Vetäminen (hiiri tai kosketuksen hiiriemulointi): lyhyt napautus on klikkaus, pidempi veto vierittää.
const DRAG_CLICK := 10.0
var _drag_on := false
var _dragged := 0.0
## Kahden sormen nipistys: sormien paikat indeksin mukaan.
var _touches := {}
var _pinch_d := 0.0


func _input(event: InputEvent) -> void:
	if not visible:
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
			_drag_on = false  # kaksi sormea: zoomaus, ei siirtoa
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
	if event is InputEventMouseMotion:
		if _drag_on and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_dragged += event.relative.length()
			if _dragged >= DRAG_CLICK:
				_vcenter = _clamped(_vcenter - event.relative / _vzoom)
				_view.queue_redraw()
	elif event is InputEventMouseButton:
		var local: Vector2 = event.position - _view.position
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_drag_on = true
					_dragged = 0.0
				else:
					_drag_on = false
			MOUSE_BUTTON_RIGHT:
				pass
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_vzoom_by(1.2, local)
				if event.pressed:
					_vzoom_by(1.0 / 1.2, local)
		_view.queue_redraw()
	elif event is InputEventMagnifyGesture:
		_vzoom_by(event.factor, event.position - _view.position)
	elif event is InputEventPanGesture:
		_vcenter = _clamped(_vcenter + event.delta * 8.0 / _vzoom)
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
	for pl in _public_places():
		out.append(pl[1])
	if game != null:
		for qm in game.quest_marks(true):
			if not qm[3]:
				out.append(qm[1])
	if bike != null and bike != player:
		out.append(Vector2(bike.global_position.x, bike.global_position.z))
	if world != null and world.forage_revealed:
		for f in world.forage:
			if not f.taken:
				out.append(Vector2(f.pos.x, f.pos.z))
	return out


# --- Koordinaatit ------------------------------------------------------------

## Kyläkartan karttapikseli (map_data) näkymän pikseleiksi.
func _px(p: Vector2) -> Vector2:
	return _vpx(M.w2(p))


## Maailman x/z näkymän pikseleiksi (kyläkartta).
func _w2(p: Vector2) -> Vector2:
	return _vpx(p)


## Näkymän pikseli maailman x/z:ksi (kyläkartta).
func _from_view(local: Vector2) -> Vector2:
	return (local - _voff()) / _vzoom


func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(_px(p))
	return out


## Mopomatkan kehyksen (x itään, z etelään, origo mökin osoitepisteessä) piste näkymän pikseleiksi.
## Siirto pyöristetään kokonaisiin pikseleihin: vieritettäessä kaikki viivat ja merkit liikkuvat samassa tahdissa
## (murtopikselisiirrossa ohuet viivat hyppivät pikselistä toiseen eri hetkinä ja kartta näyttää nykivän).
func _vpx(p: Vector2) -> Vector2:
	return p * _vzoom + _voff()


func _voff() -> Vector2:
	return (_view.size / 2.0 - _vcenter * _vzoom).round()


# --- Paperi ja kehys ---------------------------------------------------------

func _make_paper() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.frequency = 0.012
	n.fractal_octaves = 5
	var fine := FastNoiseLite.new()
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
	draw_string(font, r.position + Vector2(40, 46), "SALOINEN · RAAHE", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
	draw_string(font, r.position + Vector2(40, 68), "Normipäivän maastokartta — Järvikuja 1 ja ympäristö", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK.lightened(0.2))

	var side := Vector2(_view.position.x + MAP_W + 30, _view.position.y)
	_compass(side + Vector2(100, 70))
	var m := 50.0
	for cand in [10.0, 25.0, 50.0, 100.0, 200.0, 250.0, 500.0, 1000.0]:
		if cand * _vzoom <= 100.0:
			m = cand
	_scale_bar(side + Vector2(10, 180), m, _vzoom)
	var end_y := 0.0
	end_y = _legend(side + Vector2(10, 250))
	# Ohjeet heti selitteen alle (ei päällekkäin), näppäimet asetuksista.
	var k := func(a: String) -> String: return Settings.action_key(a)
	var help := ["Rulla / %s %s: zoomaa · %s%s%s%s / vedä: siirrä" % [k.call("bell"), k.call("interact"), k.call("forward"),
		k.call("left"), k.call("back"), k.call("right")],
		"%s: keskitä itseesi · %s sulje" % [k.call("jump"), k.call("map")]]
	var hy := maxf(end_y + 24.0, r.end.y - 12.0 - help.size() * 16.0)
	for line in help:
		draw_string(font, Vector2(side.x + 10, hy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK.lightened(0.3))
		hy += 16.0


func _compass(c: Vector2) -> void:
	var col := INK
	draw_arc(c, 36.0, 0, TAU, 40, col, 1.5)
	draw_string(ThemeDB.fallback_font, c + Vector2(-7, -58), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.75, 0.15, 0.1))


func _scale_bar(p: Vector2, meters: float, k: float) -> void:
	var font := ThemeDB.fallback_font
	for i in 2:
		pass
	draw_string(font, p + Vector2(-2, 26), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)


func _legend(p: Vector2) -> float:
	var font := ThemeDB.fallback_font
	var y := p.y
	return y


# --- Karttasisältö -----------------------------------------------------------

func _draw_map() -> void:
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
		lo = lo.max(Vector2.ZERO)  # vain näkyvä osa (zoomatessa suot ovat isoja)
		hi = hi.min(v.size)
		# Viivoitus kiinni kartassa (rivit maailman ruudukossa), ei ruudussa: ei ui vieritettäessä. Ruudun koko
		# kahden potensseina, joten zoomatessa kuvio vain venyy ja harvenee portaittain.
		var dz := pow(2.0, roundf(log(6.0 / _vzoom) / log(2.0)))
		var org := _voff()
		var step_y := dz * _vzoom
		var row := ceili((lo.y - org.y) / step_y)
		var yy := org.y + row * step_y
		while yy < hi.y:
			var step_x := step_y * 14.0 / 6.0
			var shift := fmod(absf(row * 7.0), 11.0) / 6.0 * step_y
			var xx := org.x + shift + floorf((lo.x - org.x - shift) / step_x) * step_x
			while xx < hi.x:
				if Geometry2D.is_point_in_polygon(Vector2(xx, yy), pts):
					v.draw_line(Vector2(xx, yy), Vector2(xx + step_y, yy), Color(0.3, 0.5, 0.7, 0.8), 1.0)
				xx += step_x
			yy += step_y
			row += 1
	# Puumerkit metsiin.
	var view_r := Rect2(Vector2(-5, -5), v.size + Vector2(10, 10))
	for t in _tree_pts:
		var p := _w2(t)
		if view_r.has_point(p):
			v.draw_circle(p, clampf(1.3 * _vzoom / 0.4, 1.3, 2.6), Color(0.35, 0.5, 0.28, 0.7))
	for w in M.WATER:
		var pts := _pts(w)
		v.draw_colored_polygon(pts, Color(0.55, 0.72, 0.86))
		v.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.2, 0.4, 0.65), 1.5)
	for s in M.STREAMS:
		v.draw_polyline(_pts(s), Color(0.2, 0.45, 0.75), 2.0)

	# Tiet: ensin ääriviivat, sitten täyttö; leveys kasvaa zoomatessa.
	var rw := clampf(_vzoom / 0.4, 1.0, 3.0)
	_rail_on(v, _pts(Array(M.railway())), clampf(3.0 * rw, 2.5, 6.0))  # Saloisten rata asemalta horisonttiin
	# Talot pieninä mustina neliöinä.
	if world != null:
		for h in world._houses:
			var p := _w2(h)
			var hs := clampf(10.0 * _vzoom, 2.0, 20.0)  # talo n. 10 m
			if view_r.has_point(p):
				v.draw_rect(Rect2(p - Vector2(hs, hs) / 2.0, Vector2(hs, hs)), INK)

	var font := ThemeDB.fallback_font
	# Paikannimet eivät mene päällekkäin: tärkeiden kohteiden nimet ja merkit varaavat tilan ensin, paikannimet
	# piirretään listan järjestyksessä vain vapaaseen kohtaan. Kaukaa katsottaessa fontti pienenee.
	var taken: Array[Rect2] = []
	var text_rect := func(text: String, at: Vector2, fs: int) -> Rect2:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		return Rect2(at.x, at.y - fs * 0.85, w, fs * 1.05)
	# Näkyvä kartta-alue: nimet pysyvät sen sisällä (kaukaa kartan ulkopuoli on paperia).
	var map_vis := Rect2(_vpx(_vrect.position), _vrect.size * _vzoom).intersection(Rect2(Vector2.ZERO, v.size))
	# Kohteiden nimet: oikealle merkistä, tai vasemmalle, jos oikealla ei ole tilaa (lb_at: nimen paikka piirtoon).
	var lb_at := {}
	# Saloisten apteekki: paikka haetaan käynnistyksessä (apteekki_saloinen.gd), joten sijainti luetaan maailmasta.
	var apt_s: Vector2 = M.to_px(world.apteekki_s.knock) if world != null and world.apteekki_s.has("knock") else Vector2.INF
	var grilli_txt := "Grillikatos (turvapaikka)" if _vzoom >= 0.4 else "Grillikatos"  # kaukaa lyhyt, mahtuu
	var labels := [["koti", M.HOME_ZONE, "Järvikuja 1"], ["kauppa", M.SHOP_ZONE, "K-Market"], ["laavu", M.LAAVU, "Laavu"],
			["grilli", M.GRILLIKATOS, grilli_txt], ["kota", M.KOTA, "Kota ja lintutorni"]]
	if apt_s != Vector2.INF:
		labels.append(["apteekki", apt_s, "Apteekki"])
	for lb in labels:
		var ip := _px(lb[1])
		var w := font.get_string_size(lb[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var at := ip + Vector2(12, 4)
		if lb[0] in ["koti", "kota"] or at.x + w > map_vis.end.x - 2.0:
			at = ip + Vector2(-12 - w, 4)
		if at.x < map_vis.position.x + 2.0:
			at.x = ip.x + 12.0
		lb_at[lb[0]] = at
		taken.append(Rect2(ip - Vector2(10, 10), Vector2(20, 18)))
		taken.append(text_rect.call(lb[2], at, 13))
	var place_fs := clampi(roundi(12.0 + 8.0 * (_vzoom - 0.15) / 0.45), 12, 20)
	for n in M.PLACE_NAMES:
		var w := font.get_string_size(n[0], HORIZONTAL_ALIGNMENT_LEFT, -1, place_fs).x
		var at := _px(n[1]) - Vector2(w / 2.0, 0)
		at.x = clampf(at.x, map_vis.position.x + 4.0, maxf(map_vis.position.x + 4.0, map_vis.end.x - w - 4.0))  # kokonaan näkyviin
		at.y = clampf(at.y, map_vis.position.y + place_fs + 2.0, maxf(map_vis.position.y + place_fs + 2.0, map_vis.end.y - 4.0))
		var rr: Rect2 = text_rect.call(n[0], at, place_fs)
		if not rr.intersects(Rect2(Vector2.ZERO, v.size)):
			continue
		var free := true
		for t in taken:
			if rr.grow(2.0).intersects(t):
				free = false
				break
		if free:
			taken.append(rr)
			_outlined(v, at, n[0], place_fs, INK)
	# Tienimet eivät tukkeuta karttaa: nimi näkyy vain, kun hiiri on tien päällä (_hover_road).

	# Naapurit (tarina lähettää heidän luokseen): kuulakärkikynän ympyrä, nimi hiiren alla (_place_at).
	for n in NEIGHBORS:
		_place_mark_on(v, _px(n[0]), M.w2(n[0]))
	_house_icon_on(v, _px(M.HOME_ZONE), Color(0.8, 0.15, 0.1))
	_outlined(v, lb_at.koti, "Järvikuja 1", 13, Color(0.7, 0.1, 0.05))
	var sp := _px(M.SHOP_ZONE)
	v.draw_circle(sp, 8.0, Color(1.0, 0.45, 0.0))
	v.draw_string(font, sp + Vector2(-4, 5), "K", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	_outlined(v, lb_at.kauppa, "K-Market", 13, Color(0.7, 0.3, 0.0))
	if apt_s != Vector2.INF:
		_poi_icon_on(v, _px(apt_s), "apteekki")
		_outlined(v, lb_at.apteekki, "Apteekki", 13, Color(0.05, 0.4, 0.18))
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
	_outlined(v, lb_at.laavu, "Laavu", 13, INK)
	_laavu_icon_on(v, _px(M.GRILLIKATOS))
	_outlined(v, lb_at.grilli, grilli_txt, 13, Color(0.1, 0.4, 0.1))
	_laavu_icon_on(v, _px(M.KOTA))
	_outlined(v, lb_at.kota, "Kota ja lintutorni", 13, INK)
	if game != null and game.pontikka_found:  # löytyi droonin ilmakuvasta
		var pp := _px(M.PONTIKKA)
		v.draw_circle(pp, 5.0, Color(0.55, 0.2, 0.1))
		v.draw_arc(pp, 9.0, 0, TAU, 16, Color(0.55, 0.2, 0.1), 1.5)
		v.draw_string(font, pp + Vector2(12, 4), "Pontikkapannu (ilmakuva)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.15, 0.05))
	var kk := _px(M.KERTUNKANGAS)  # muinaisjäännös: kehäröykkiön merkki
	v.draw_arc(kk, 4.5, 0, TAU, 12, Color(0.4, 0.2, 0.08), 1.5)
	v.draw_circle(kk, 1.5, Color(0.4, 0.2, 0.08))
	v.draw_string(font, kk + Vector2(9, 4), "Kertunkankaan kehäröykkiöt", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.35, 0.2, 0.08))
	if game != null and game.ukko != null and game.ukko.spotted and not game.ukko.caught:  # Ukon varjo iltakuvasta
		var us: Array = game._kala_spot("tekojarvi")
		if not us.is_empty():
			var up := _px(M.to_px(us[0] + (us[1] as Vector3) * 16.0))
			v.draw_arc(up, 7.0, 0, TAU, 18, Color(0.1, 0.25, 0.45), 1.5)
			v.draw_arc(up, 3.0, 0, TAU, 12, Color(0.1, 0.25, 0.45), 1.0)
			v.draw_string(font, up + Vector2(11, 4), "Ukon varjo (ilmakuva)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.08, 0.2, 0.4))
	if game != null and game.kertun != null and game.kertun.spotted and not game.kertun.found:  # kivirivi ilmakuvasta
		var ka := _px(game.KertunRauta.RIVI_A)
		var kb := _px(game.KertunRauta.ISOKIVI)
		v.draw_line(ka, kb, Color(0.45, 0.45, 0.45), 2.0)
		v.draw_circle(kb, 4.0, Color(0.45, 0.45, 0.45))
		v.draw_string(font, kb + Vector2(-10, -10), "Kivirivi (ilmakuva)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 0.3, 0.3))
	if game != null and game.pannu != null and game.pannu.spotted and not game.pannu.found:  # kuparin läikkä ilmakuvasta
		var kp := _px(game.SuloPannu.SPOT)
		v.draw_circle(kp, 5.0, Color(0.2, 0.55, 0.4))
		v.draw_arc(kp, 9.0, 0, TAU, 16, Color(0.2, 0.55, 0.4), 1.5)
		v.draw_string(font, kp + Vector2(12, 4), "Kuparin läikkä (ilmakuva)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.1, 0.4, 0.3))
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
		for m in game.cache_markers():
			if m[0] == "saloinen":
				_cache_icon_on(v, _w2(m[1]))
		var sk_p: Vector2 = game.sinikka_map_mark()
		if sk_p != Vector2.INF:
			_sinikka_icon_on(v, _w2(sk_p))
	# Kylän julkiset paikat pienenä kuulakärkikynän ympyränä ("täällä on jotain"), nimi hiiren alla (_place_at).
	for pl in _public_places():
		_place_mark_on(v, _w2(pl[1]), pl[1])
	if game != null:
		for qm in game.quest_marks(true):
			_pencil_ring_on(v, qm)
		_kolmio_rings_on(v, game.kolmio_rings("saloinen"), _w2)
	if has_target:
		_target_icon_on(v, _w2(target))
	if player != null:
		var f := -player.global_transform.basis.z
		_you_icon_on(v, _w2(Vector2(player.global_position.x, player.global_position.z)), atan2(f.z, f.x) + PI / 2.0)
	_mask_outside(v)
	_draw_road_hover(v)  # viimeisenä: kartan reunan paperi ei peitä nimeä


## Kartta-alueen ulkopuoli paperiksi (OSM-aineisto jatkuu pelialueen yli) ja alueen reunaviiva, kun kartta on
## kokonaan näkyvissä tai sen reuna näkyy.
func _mask_outside(v: Control) -> void:
	var a := _vpx(_vrect.position)
	var b := _vpx(_vrect.end)
	var full := Rect2(Vector2.ZERO, v.size)
	var r := _paper_rect()
	var tex_k := Vector2(_paper_tex.get_width(), _paper_tex.get_height()) / r.size
	for out in [Rect2(0, 0, v.size.x, a.y), Rect2(0, b.y, v.size.x, v.size.y - b.y), Rect2(0, a.y, a.x, b.y - a.y),
			Rect2(b.x, a.y, v.size.x - b.x, b.y - a.y)]:
		if out.size.x <= 0.5 or out.size.y <= 0.5:
			continue  # reuna näkymän ulkopuolella
		var o: Rect2 = out.intersection(full)
		if o.size.x <= 0.5 or o.size.y <= 0.5:
			continue
		var src := Rect2((o.position + _view.position - r.position) * tex_k, o.size * tex_k)
		v.draw_texture_rect_region(_paper_tex, o, src)
	var inner := Rect2(a, b - a).intersection(full.grow(2.0))
	if inner.size.x < v.size.x - 1.0 or inner.size.y < v.size.y - 1.0:
		v.draw_rect(Rect2(a, b - a), INK, false, 1.5)


# --- Näkymä --------------------------------------------------------------------------------------


func _vzoom_by(f: float, at: Vector2) -> void:
	var fit := _fit_zoom()
	var before := (at - _view.size / 2.0) / _vzoom + _vcenter
	_vcenter = before - (at - _view.size / 2.0) / _vzoom
	_vcenter = _clamped(_vcenter)
	_view.queue_redraw()
	queue_redraw()  # mittakaava


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
	# Nimi kursorin oikealle yläpuolelle; jos tila loppuu reunassa, vasemmalle tai alapuolelle. Aina kokonaan kartan sisällä.
	var at := _hover_px + Vector2(12, -10)
	if at.x + w + 8 > v.size.x:
		at.x = _hover_px.x - 12 - w
	if at.y - 16 < 0.0:
		at.y = _hover_px.y + 26
	at.x = clampf(at.x, 7.0, maxf(7.0, v.size.x - w - 7.0))
	at.y = clampf(at.y, 16.0, v.size.y - 7.0)
	v.draw_rect(Rect2(at - Vector2(5, 14), Vector2(w + 10, 19)), Color(0.98, 0.95, 0.85, 0.95))
	v.draw_rect(Rect2(at - Vector2(5, 14), Vector2(w + 10, 19)), Color(0.35, 0.18, 0.08), false, 1.0)
	v.draw_string(font, at, _hover_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.35, 0.18, 0.08))


# --- Merkit (piirto joko tähän tai karttanäkymään) ----------------------------

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
			ci.draw_line(p + Vector2(-8, -2), p + Vector2(4, -2), Color(0.5, 0.38, 0.24), 4.0)
			# Soutuvene laiturin kyljessä.
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 3), p + Vector2(6, 3), p + Vector2(4, 7), p + Vector2(-4, 7)]), Color(0.75, 0.2, 0.12))
		"harbor":
			# Ankkuri: varsi, poikkipuu, renkaat ja kaareva pohja.
			ci.draw_line(p + Vector2(0, -7), p + Vector2(0, 6), INK, 2.0)
			ci.draw_line(p + Vector2(-4, -3), p + Vector2(4, -3), INK, 2.0)
			ci.draw_arc(p + Vector2(0, 0), 7.0, deg_to_rad(20), deg_to_rad(160), 12, INK, 2.0)
			ci.draw_arc(p + Vector2(0, -8), 2.0, 0.0, TAU, 10, INK, 1.5)
		"barrel":
			# Tynnyrisauna kyljellään vaunun päällä, piippu.
			ci.draw_rect(Rect2(p + Vector2(-9, -5), Vector2(18, 10)), Color(0.55, 0.36, 0.2))
			for x in [-4.0, 4.0]:
				ci.draw_line(p + Vector2(x, -5), p + Vector2(x, 5), Color(0.3, 0.2, 0.12), 1.5)
			ci.draw_line(p + Vector2(5, -5), p + Vector2(5, -10), INK, 2.0)
			ci.draw_circle(p + Vector2(-5, 7), 2.0, INK)
			ci.draw_circle(p + Vector2(5, 7), 2.0, INK)
		"sauna":
			_house_icon_on(ci, p, Color(0.4, 0.22, 0.12))
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
		"apteekki":
			# Vihreä risti valkoisella pohjalla.
			ci.draw_rect(Rect2(p - Vector2(8, 8), Vector2(16, 16)), Color(0.97, 0.97, 0.94))
			ci.draw_rect(Rect2(p - Vector2(8, 8), Vector2(16, 16)), INK, false, 1.0)
			ci.draw_rect(Rect2(p - Vector2(2, 6), Vector2(4, 12)), Color(0.1, 0.55, 0.25))
			ci.draw_rect(Rect2(p - Vector2(6, 2), Vector2(12, 4)), Color(0.1, 0.55, 0.25))
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
		ci.draw_dashed_line(pts[i], pts[i + 1], Color(0.95, 0.93, 0.85), w - 1.5, clampf(6.0 * _vzoom / 0.4, 3.0, 18.0))  # ratapölkyt venyvät kartan mukana


func _house_icon_on(ci: CanvasItem, p: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(p + Vector2(-6, -2), Vector2(12, 9)), col)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -2), p + Vector2(0, -10), p + Vector2(8, -2)]), col.darkened(0.2))


func _laavu_icon_on(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 6), p + Vector2(3, -8), p + Vector2(9, 6)]), Color(0.45, 0.28, 0.12))
	ci.draw_line(p + Vector2(-9, 6), p + Vector2(9, 6), INK, 2.0)
	ci.draw_circle(p + Vector2(-2, 3), 2.5, Color(0.95, 0.45, 0.1))


## Kylän julkiset paikat, joissa on jotain tekemistä: [nimi, paikka, käyty]. Kartalla vain yhteinen pieni kynäympyrä
## (ei kerrota, mitä paikassa on), nimi hiiren alla (_place_at). Käyty = paikan ensikäynti (tilat.first) kirjattu.
## Paikat, jotka kuka tahansa saloislainen tietää; Sepon varasto ja rossirata vasta kun niistä kuulee (main.gd
## HEARD_PLACES). Salaiset ja syrjäiset löytyvät kuulemalla tehtävinä (lyijykynämerkinnät, _pencil_ring_on).
## Naapurit kartalla: [paikka (karttapikseli), nimi, tapaamisen merkintä (main.gd _talk_open)].
const NEIGHBORS := [[M.NEIGHBOR_PEKKA, "Pekka", "pekka"], [M.NEIGHBOR_SINIKKA, "Sinikka", "sinikka"], [M.NEIGHBOR_ARTO, "Arto", "arto"]]


func _public_places() -> Array:
	var firsts: Array = game.tilat.firsts if game != null and game.tilat != null else []
	var out: Array = []
	for p in [["Honganpalon koulu", M.HONGAN_KOULU, "honganpalo"], ["Saloisten kenttä", M.KENTTA, "kentta"],
			["Seuraintalo", M.SEURAINTALO, "kirppis"], ["Reippari", M.REIPPARI, "reippari"], ["SEO Saloinen", M.SEO, "seo"],
			["Oravajärven uimaranta", M.UIMARANTA, "oravajarvi"], ["Katsastus", M.KATSASTUS, "kinnapotti"],
			["Korpelan korjaamo", M.KORPELA, "korjaamo"], ["Säästöpiha", M.SAASTOPIHA, "saastopiha"],
			# Muut paikat, joihin ajetaan tai kävellään (kuka tahansa tietää): kirkko, tapuli, Pirtti, koulut, kentät, korjaamot, rauniot ja erämaa.
			["Saloisten kirkko", M.KIRKKO, "kirkko"], ["Kellotapuli", M.KELLOTAPULI, "tapuli"], ["Saloisten Pirtti (museo)", M.PIRTTI, "pirtti"],
			["Koulukeskus", M.KOULUKESKUS, "koulukeskus"], ["Päiväkoti", M.PAIVAKOTI, "paivakoti"], ["Kaukalo", M.KAUKALO, "kaukalo"],
			["Ulkopingispöytä", M.ULKOPINGIS, "pingis"], ["Lemmikki Enkelit (muistolehto)", M.LEMMIKKI, "lemmikki"],
			["Kanttorila", M.KANTTORILA, "kanttorila"], ["Honganpalon kenttä", M.HONGAN_KENTTA, "hongankentta"],
			["Arttim Metal Works", M.ARTTIM, "arttim"], ["Rudus", M.RUDUS, "rudus"], ["Heiskasen huolto", M.HEISKANEN, "heiskanen"],
			["Huhtalan auto ja varaosat", M.HUHTALA, "huhtala"], ["Lapinraunio", M.LAPINRAUNIO, "lapinraunio"],
			["Raunio", M.RAUNIOT[0], "raunio"], ["Kertunkankaan röykkiöt", M.KERTUNKANGAS, "kertunkangas"],
			["Heinimäki", M.HEINIMAKI, "heinimaki"], ["Kiilinlammen grillikatos", M.GRILLIKATOS, "grillikatos"],
			["Antinsuon laavu", M.LAAVU, "laavu"], ["Kota ja lintutorni", M.KOTA, "kota"], ["Viitajärven laavu", M.VIITA_LAAVU, "viitalaavu"],
			["Puntarimäki", M.PUNTARIMAKI, "puntarimaki"], ["Kaitasaari", M.KAITASAARI, "kaitasaari"]]:
		out.append([p[0], M.w2(p[1]), p[2] in firsts])
	# Kuulemalla kartalle (main.gd HEARD_PLACES), tai kun paikassa on käyty.
	if "kuultu_seppo" in firsts or "seppo" in firsts:
		out.append(["Sepon varasto", M.w2(M.SEPPO), "seppo" in firsts])
	if "kuultu_rossirata" in firsts or "rossirata" in firsts:
		out.append(["Rossirata", M.w2(M.ROSSI[0]), "rossirata" in firsts])
	if world != null:
		if world.station_pos != Vector3.ZERO:
			out.append(["Asema", Vector2(world.station_pos.x, world.station_pos.z), "asema" in firsts])
		for pg in world.playgrounds:
			out.append(["Leikkipuisto", Vector2(pg.swing.x, pg.swing.z), "leikkipuisto" in firsts])
	return out


## Hiiren alla olevan julkisen paikan nimi (alle 10 px merkistä), muuten "".
func _place_at(local: Vector2) -> String:
	if not Rect2(Vector2.ZERO, _view.size).has_point(local):
		return ""
	for pl in _public_places():
		if _w2(pl[1]).distance_to(local) < 10.0:
			return pl[0]
	for n in NEIGHBORS:
		if _px(n[0]).distance_to(local) < 8.0:
			return n[1]
	return ""


## "Täällä on jotain": pieni kuulakärkikynällä sutaistu ympyrä (vähän yli kierroksen, ei aivan pyöreä).
func _place_mark_on(ci: CanvasItem, p: Vector2, key: Vector2) -> void:
	var pts := PackedVector2Array()
	var h := absi(int(key.x * 7.0 + key.y * 13.0))  # muoto paikan (maailman x/z) mukaan: ei elä vieritettäessä
	var a0 := (h % 628) / 100.0
	for s in 17:
		var a := a0 + s * TAU * 1.15 / 16.0
		var r := 4.2 + 0.7 * sin(a * 2.0 + h % 5) + s * 0.04
		pts.append(p + Vector2(cos(a), sin(a) * 0.85) * r)
	ci.draw_polyline(pts, Color(0.12, 0.18, 0.55, 0.9), 1.3, true)


## Lyijykynämerkintä tiedossa olevasta tehtävästä (main.gd quest_marks): kaksi vähän eri kokoista, käsin vedetyn
## näköistä rengasta ja otsikko renkaan yläpuolella. Tehty vedetään yli ja haalistuu.
func _pencil_ring_on(ci: CanvasItem, qm: Array) -> void:
	var c := _w2(qm[1])
	var r := maxf(9.0, float(qm[2]) * _vzoom)
	var done: bool = qm[3]
	var col := Color(0.32, 0.32, 0.36, 0.45 if done else 0.85)
	var h := absi(hash(qm[4]))
	for k in 2:
		var pts := PackedVector2Array()
		var a0 := (h % 628) / 100.0 + k * 0.7
		for s in 33:
			var a := a0 + s * TAU / 30.0  # yli kierroksen: kynä jatkaa vähän alkukohdan ohi
			var rr := r * (1.0 + 0.06 * sin(a * 3.0 + h % 7 + k) + k * 0.05)
			pts.append(c + Vector2(cos(a), sin(a) * 0.92) * rr)
		ci.draw_polyline(pts, col, 1.4 if k == 0 else 1.0, true)
	var font := ThemeDB.fallback_font
	var txt: String = qm[0]
	var fs := 12
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := c + Vector2(-w / 2.0, -r - 4.0)
	if done:
		ci.draw_line(c + Vector2(-r, r) * 0.6, c + Vector2(r, -r) * 0.6, col, 1.4)
	if _vzoom < 0.45:
		return  # kaukaa pelkkä rengas, otsikko vasta lähempää
	for pl in _public_places():
		if (pl[1] as Vector2).distance_to(qm[1]) < 90.0:
			return  # julkisen paikan symboli ja hiirivihje kertovat jo; ei päällekkäistä tekstiä
	ci.draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if done:
		ci.draw_line(at + Vector2(0, -4), at + Vector2(w, -4), col, 1.2)


## Kolmiomittauksen (#255) harppiympyrät: pyöristyksen vyöhyke haaleana punakynävarjostuksena (päällekkäin tummuu,
## joten leikkausalue erottuu), harpin viiva näytetyllä etäisyydellä, harpin kärjen jälki ja mittaajan nimi.
## to_view: kartan koordinaatit (maailman x/z) näkymän pikseleiksi.
func _kolmio_rings_on(ci: CanvasItem, rings: Array, to_view: Callable) -> void:
	var col := Color(0.6, 0.1, 0.12)
	for r: Dictionary in rings:
		var c: Vector2 = to_view.call(r.c)
		var lo: float = float(r.lo) * _vzoom
		var hi: float = float(r.hi) * _vzoom
		ci.draw_arc(c, (lo + hi) / 2.0, 0, TAU, 96, Color(col.r, col.g, col.b, 0.14), maxf(1.0, hi - lo))
		ci.draw_arc(c, float(r.m) * _vzoom, 0, TAU, 96, Color(col.r, col.g, col.b, 0.8), 1.4, true)
		ci.draw_circle(c, 2.2, col)
		ci.draw_arc(c, 5.0, 0, TAU, 12, col, 1.2, true)
		_outlined(ci, c + Vector2(7, -6), "%s %s" % [r.who, Kolmio.dist_text(r.m)], 12, col)


## Kaljapullo: ruskea runko ja kaula.
func _stash_icon_on(ci: CanvasItem, p: Vector2) -> void:
	var col := Color(0.45, 0.25, 0.05)
	ci.draw_rect(Rect2(p + Vector2(-3, -2), Vector2(6, 9)), col)
	ci.draw_rect(Rect2(p + Vector2(-1.2, -7), Vector2(2.4, 5)), col)
	ci.draw_rect(Rect2(p + Vector2(-3, 1), Vector2(6, 3)), Color(0.95, 0.85, 0.5))


## Juopon kertoma rahakätkö: käsin piirretty rasti ympyrässä ja €.
func _cache_icon_on(ci: CanvasItem, p: Vector2) -> void:
	var col := Color(0.75, 0.5, 0.0)
	ci.draw_arc(p, 10.0, 0, TAU, 20, col, 2.0)
	ci.draw_line(p - Vector2(5, 5), p + Vector2(5, 5), Color(0.6, 0.1, 0.05), 2.2)
	ci.draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), Color(0.6, 0.1, 0.05), 2.2)
	_outlined(ci, p + Vector2(13, 5), "Kätkö 100 €", 13, col)


## Sinikan ovilappu luettu (main.gd sinikka_map_mark): punakynällä sutaistu sydän ja nimi Oravajärven rannalla.
## Siirretty oikealle ylös, ettei peitä uimarannan julkisen paikan kynäympyrää (_place_mark_on, r ≈ 5 px).
func _sinikka_icon_on(ci: CanvasItem, p: Vector2) -> void:
	var col := Color(0.8, 0.1, 0.25)
	var c := p + Vector2(14, -12)
	var pts := PackedVector2Array()
	for s in 24:
		var t := s * TAU / 24.0
		pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * 0.45)
	ci.draw_colored_polygon(pts, Color(col, 0.25))
	pts.append(pts[0])
	ci.draw_polyline(pts, col, 1.8, true)
	_outlined(ci, c + Vector2(10, 5), "Sinikka", 13, col)


func _target_icon_on(ci: CanvasItem, p: Vector2) -> void:
	var col := Color(0.85, 0.1, 0.1)
	ci.draw_arc(p, 9.0, 0, TAU, 24, col, 2.5)
	ci.draw_line(p - Vector2(5, 5), p + Vector2(5, 5), col, 2.0)
	ci.draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), col, 2.0)


const YOU_R := 12.0  # oman merkin säde (kehä 11 px)


func _you_icon_on(ci: CanvasItem, p: Vector2, ang: float) -> void:
	# Kartan reunalla merkki pidetään kokonaan näkyvissä (muuten kehys leikkaa nuolen ja kehän).
	if ci is Control:
		var s: Vector2 = (ci as Control).size
		if s.x > 40.0 and s.y > 40.0:
			p = p.clamp(Vector2(YOU_R, YOU_R), s - Vector2(YOU_R, YOU_R))
	var f := Vector2(0, -1).rotated(ang)
	var r := f.orthogonal()
	ci.draw_circle(p, 11.0, Color(0.85, 0.1, 0.1, 0.25))
	ci.draw_colored_polygon(PackedVector2Array([p + f * 10.0, p - f * 6.0 + r * 6.0, p - f * 2.0, p - f * 6.0 - r * 6.0]), Color(0.85, 0.1, 0.1))
