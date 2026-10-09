extends Control
## GTA-tyylinen tutka: pelaaja keskellä, pohjoinen ylös, näyttää ympäristön RANGE metrin säteellä.
## Tiet, metsät, pellot, vesistöt, Päivi, tavoite ja laavu. Kaukana olevat merkit näytetään reunalla.

const M := preload("res://scripts/map_data.gd")
const Mokki := preload("res://scripts/mokki.gd")

const SIZE_PX := 210.0
const RANGE := 320.0  # metriä keskeltä reunaan
const FAR_RANGE := 450.0  # vireys-tilan palkinto (main.gd _stat_effects): tutka näkee kauemmas
const MOKKI_RANGE := 90.0  # mökin tutka on lähempänä tarkka, koska tasku on pieni
const MOKKI_SHOW_DIST := 650.0  # etäisyys mökin keskeltä, jolloin tutka vaihtaa mökin lähikarttaan

var player: Node3D
var wife: Node3D
var world: Node3D
var bike: Node3D  # näytetään kun liikutaan jalan
var mokki: Node3D
var game: Node  # main.gd: cache_markers()
var target := Vector3.ZERO
var show_target := true
## Vaalan mopomatka (main.gd asettaa): vaala.gd, mopo ja onko pelaaja Vaalan maailmassa.
var vaala: Node3D
var vaala_mopo: Node3D
var vaala_on := false
const VAALA_RANGE := 220.0
const VAALA_TEX_SCALE := 0.5
var _vaala_tex: Texture2D
var _vaala_origin := Vector2.ZERO
var _vaala_building := false

## Staattinen kartta (pellot, metsät, vedet, tiet, rakennukset) piirretään kerran tekstuuriksi (SubViewport) ja
## joka ruudulla näytetään vain pelaajan ympärille leikattu pala. Ennen kartta piirrettiin kokonaan uudelleen joka
## ruudulla (satoja monikulmioita ja polyviivoja, pisteet muunnettuna GDScriptillä), mikä vei heikolla koneella
## yli puolet ruudun ajasta. TEX_SCALE = tekstuuripikseliä metriä kohti.
const TEX_SCALE := 0.5
const MOKKI_TEX_SCALE := 1.0

class _Painter extends Control:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


var _village_tex: Texture2D
var _village_origin := Vector2.ZERO  # tekstuurin vasen yläkulma maailman metreinä
var mokki_forage: Array = []  # Santun kertomat marja- ja sienipaikat (main.gd), tyhjä = ei näytetä
var _mokki_tex: Texture2D
var _mokki_origin := Vector2.ZERO  # tekstuurin vasen yläkulma mökin karttametreinä (Mokki.to_map2)
var _mokki_building := false
## Tutkan säde (RANGE tai FAR_RANGE).
var range_m := RANGE:
	set(v):
		range_m = v
		_k = (SIZE_PX / 2.0) / v
var _k := (SIZE_PX / 2.0) / RANGE
var _center := Vector2.ONE * SIZE_PX / 2.0
var _origin := Vector2.ZERO  # pelaajan paikka metreinä


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * SIZE_PX
	size = custom_minimum_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bake_village()


func _process(_delta: float) -> void:
	queue_redraw()


func _w(v: Vector3) -> Vector2:
	return (Vector2(v.x, v.z) - _origin) * _k + _center


func _px(p: Vector2) -> Vector2:
	return (M.w2(p) - _origin) * _k + _center


func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(_px(p))
	return out


## Kylän staattinen kartta tekstuuriksi (kerran käynnistyksessä): kattaa koko pelialueen ja reunalle FAR_RANGE + 10 m
## marginaalin, jotta leike ei koskaan ulotu tekstuurin ulkopuolelle.
func _bake_village() -> void:
	var pad := FAR_RANGE + 10.0
	var lo := M.w2(M.MAP_MIN) - Vector2(pad, pad)
	var hi := M.w2(M.SIZE) + Vector2(pad, pad)
	_village_origin = lo
	var tex_size := Vector2i(((hi - lo) * TEX_SCALE).ceil())
	var tp := func(p: Vector2) -> Vector2:
		return (M.w2(p) - lo) * TEX_SCALE
	var wscale := TEX_SCALE / _k  # viivanleveys: lopullinen leveys pysyy samana, kun tekstuuri pienennetään
	var paint := func(c: Control) -> void:
		var pts := func(arr: Array) -> PackedVector2Array:
			var out := PackedVector2Array()
			for q in arr:
				out.append(tp.call(q))
			return out
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(tex_size)), Color(0.35, 0.45, 0.28, 0.9))
		for f in M.FIELDS:
			c.draw_colored_polygon(pts.call(f), Color(0.62, 0.6, 0.38, 0.95))
		for f in M.FORESTS:
			c.draw_colored_polygon(pts.call(f), Color(0.2, 0.32, 0.16, 0.95))
		for cl in M.CLEARINGS:
			c.draw_colored_polygon(pts.call(cl), Color(0.35, 0.45, 0.28, 0.95))
		for b in M.BOGS:
			c.draw_colored_polygon(pts.call(b), Color(0.45, 0.43, 0.3, 0.95))
		for w in M.WATER:
			c.draw_colored_polygon(pts.call(w), Color(0.3, 0.5, 0.75))
		for st in M.STREAMS:
			c.draw_polyline(pts.call(st), Color(0.3, 0.5, 0.75), 1.5 * wscale)
		for r in M.ROADS:
			var col := Color(0.88, 0.88, 0.85)
			var width := 2.0
			match r.type:
				"highway":
					col = Color(0.95, 0.8, 0.2)
					width = 4.0
				"road":
					width = 3.0
				"path":
					col = Color(0.85, 0.7, 0.5)
					width = 1.5
			c.draw_polyline(pts.call(r.pts), col, width * wscale)
		c.draw_polyline(pts.call(Array(M.railway())), Color(0.15, 0.13, 0.12), 2.5 * wscale)  # rata
	_village_tex = await _render(tex_size, paint)


## Piirtää paint-kutsun SubViewportissa kerran ja palauttaa valmiin tekstuurin.
func _render(tex_size: Vector2i, paint: Callable) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = tex_size
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := _Painter.new()
	painter.fn = paint
	painter.size = Vector2(tex_size)
	vp.add_child(painter)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return vp.get_texture()


func _draw() -> void:
	if player != null:
		_origin = Vector2(player.global_position.x, player.global_position.z)
	if vaala_on and vaala != null and player != null:
		_draw_vaala()
		return
	if mokki != null and player != null and _near_mokki():
		_draw_mokki()
		return
	if _village_tex != null:
		var src := Rect2((_origin - _village_origin) * TEX_SCALE - Vector2.ONE * range_m * TEX_SCALE, Vector2.ONE * 2.0 * range_m * TEX_SCALE)
		draw_texture_rect_region(_village_tex, Rect2(Vector2.ZERO, size), src)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.45, 0.28, 0.9))
	_marker(_px(M.HOME_ZONE), Color(0.3, 1.0, 0.4), "K")
	_marker(_px(M.SHOP_ZONE), Color(1.0, 0.5, 0.0), "M")
	_marker(_px(M.LAAVU), Color(0.75, 0.5, 0.25), "L")
	_marker(_px(M.GRILLIKATOS), Color(0.35, 0.8, 0.35), "G")
	_marker(_px(M.KOTA), Color(0.85, 0.6, 0.3), "Ko")
	if world != null and world.forage_revealed:
		for f in world.forage:
			if not f.taken:
				var fp := _w(f.pos)
				if Rect2(Vector2.ZERO, size).has_point(fp):
					draw_circle(fp, 3.0, world.FORAGE_KINDS[f.kind].color)
	if game != null:
		for m in game.cache_markers():
			if m[0] == "saloinen":
				_cache_icon(_clamp_edge(_w(Vector3(m[1].x, 0, m[1].y))))
	if show_target:
		var t := _clamp_edge(_w(target))
		draw_arc(t, 8.0, 0, TAU, 20, Color(1, 0.9, 0.1), 2.5)
	if bike != null and bike != player:
		_bike_icon(_clamp_edge(_w(bike.global_position)))
	if wife != null and wife.is_inside_tree() and wife.visible:  # töissä auto on piilossa origon alla
		draw_circle(_clamp_edge(_w(wife.global_position)), 4.5, Color(0.95, 0.1, 0.1))
	if player != null:
		var fwd3 := -player.global_transform.basis.z
		var f := Vector2(fwd3.x, fwd3.z).normalized()
		var r := f.orthogonal()
		var p := _center
		draw_colored_polygon(PackedVector2Array([p + f * 8.0, p - f * 5.0 + r * 5.0, p - f * 5.0 - r * 5.0]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85), false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 4, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


## Vaalan matkan tutka (mopolla tai jalan): Vaalan maailman kartta pelaajan ympäriltä, pohjoinen ylös.
func _draw_vaala() -> void:
	var k := (SIZE_PX / 2.0) / VAALA_RANGE
	var lp: Vector3 = vaala.to_local(player.global_position)
	var o := Vector2(lp.x, lp.z)
	var vl := func(p: Vector2) -> Vector2: return (p - o) * k + _center
	if _vaala_tex == null:
		if not _vaala_building:
			_vaala_building = true
			_bake_vaala()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.3, 0.16, 0.95))
	else:
		var src := Rect2((o - _vaala_origin) * VAALA_TEX_SCALE - Vector2.ONE * VAALA_RANGE * VAALA_TEX_SCALE,
			Vector2.ONE * 2.0 * VAALA_RANGE * VAALA_TEX_SCALE)
		draw_texture_rect_region(_vaala_tex, Rect2(Vector2.ZERO, size), src)
	var marks := [[vaala.siitari, Color(0.7, 0.1, 0.08), "S"]]
	if vaala.kmarket_door != Vector3.ZERO:
		marks.append([Vector2(vaala.kmarket_door.x, vaala.kmarket_door.z), Color(1.0, 0.5, 0.0), "K"])
	if vaala.station_door != Vector3.ZERO:
		marks.append([Vector2(vaala.station_door.x, vaala.station_door.z), Color(0.2, 0.4, 0.8), "J"])
	if vaala.lava_door != Vector3.ZERO:
		marks.append([Vector2(vaala.lava_door.x, vaala.lava_door.z), Color(0.6, 0.15, 0.1), "L"])
	if vaala._zabuki != Vector3.INF:
		marks.append([Vector2(vaala._zabuki.x, vaala._zabuki.z), Color(0.95, 0.7, 0.15), "Z"])
	marks.append([Vector2(vaala.mokki_mopo.x, vaala.mokki_mopo.z), Color(0.8, 0.15, 0.1), "P"])
	for m in marks:
		_marker(_clamp_edge(vl.call(m[0])), m[1], m[2])
	if game != null:
		for m in game.cache_markers():
			if m[0] == "vaala":
				_cache_icon(_clamp_edge(vl.call(m[1])))
	if vaala_mopo != null and vaala_mopo != player:
		var mp: Vector3 = vaala.to_local(vaala_mopo.global_position)
		_bike_icon(_clamp_edge(vl.call(Vector2(mp.x, mp.z))))
	var fwd3 := vaala.global_transform.basis.inverse() * (-player.global_transform.basis.z)
	var f := Vector2(fwd3.x, fwd3.z).normalized()
	var r := f.orthogonal()
	var p := _center
	draw_colored_polygon(PackedVector2Array([p + f * 8.0, p - f * 5.0 + r * 5.0, p - f * 5.0 - r * 5.0]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85), false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 4, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


## Vaalan maailman staattinen tutkakartta tekstuuriksi (kerran): maankäyttö vaala.gd:n ruudukosta, mopotie, sivutiet,
## rata ja rakennukset.
func _bake_vaala() -> void:
	var nx: int = vaala._nx
	var nz: int = vaala._nz
	var cell: float = vaala._cell
	var lo := Vector2(vaala._x0, vaala._z0) - Vector2.ONE * cell / 2.0
	_vaala_origin = lo
	var tex_size := Vector2i((Vector2(nx, nz) * cell * VAALA_TEX_SCALE).ceil())
	var pal := [Color(0.2, 0.32, 0.16), Color(0.62, 0.6, 0.38), Color(0.45, 0.43, 0.3), Color(0.3, 0.5, 0.75),
		Color(0.4, 0.48, 0.32), Color(0.5, 0.5, 0.42), Color(0.5, 0.5, 0.42), Color(0.45, 0.42, 0.38)]
	var px := PackedByteArray()
	px.resize(nx * nz * 3)
	var codes: PackedByteArray = vaala._codes
	for q in nx * nz:
		var col: Color = pal[mini(codes[q], 7)]
		px[q * 3] = int(col.r * 255.0)
		px[q * 3 + 1] = int(col.g * 255.0)
		px[q * 3 + 2] = int(col.b * 255.0)
	var land := ImageTexture.create_from_image(Image.create_from_data(nx, nz, false, Image.FORMAT_RGB8, px))
	var kk := (SIZE_PX / 2.0) / VAALA_RANGE
	var wscale := VAALA_TEX_SCALE / kk
	var tp := func(p: Vector2) -> Vector2: return (p - lo) * VAALA_TEX_SCALE
	var data: Dictionary = vaala.data
	var paint := func(c: Control) -> void:
		c.draw_texture_rect(land, Rect2(Vector2.ZERO, Vector2(tex_size)), false)
		for bd in data.buildings:
			var bp := PackedVector2Array()
			for q in bd.pts:
				bp.append(tp.call(Vector2(q[0], q[1])))
			if bp.size() >= 3 and not Geometry2D.triangulate_polygon(bp).is_empty():
				c.draw_colored_polygon(bp, Color(0.62, 0.6, 0.56))
		for r in data.side_roads:
			var rp := PackedVector2Array()
			for q in r.pts:
				rp.append(tp.call(Vector2(q[0], q[1])))
			if rp.size() < 2:
				continue
			if r.kind == "rail":
				c.draw_polyline(rp, Color(0.25, 0.22, 0.2), 2.0 * wscale)
			elif r.hw in ["footway", "cycleway", "path", "pedestrian", "track"]:
				c.draw_polyline(rp, Color(0.8, 0.7, 0.55), 1.2 * wscale)
			else:
				c.draw_polyline(rp, Color(0.88, 0.88, 0.85), 2.5 * wscale)
		var line := PackedVector2Array()
		for q in data.road:
			line.append(tp.call(Vector2(q[0], q[2])))
		c.draw_polyline(line, Color(0.95, 0.8, 0.2), 4.0 * wscale)
	_vaala_tex = await _render(tex_size, paint)


## Mökin kävelyalueella (myös Salmiset ja Keskimmäinen, n. 1,7 km mökistä) tai lähellä sitä: mökin lähikartta.
## Ennen raja oli 650 m mökistä, ja kauempana tutka yritti näyttää kyläkarttaa mökin kehyksessä (tyhjä ruutu).
func _near_mokki() -> bool:
	if player.global_position.distance_to(mokki.global_position) < MOKKI_SHOW_DIST:
		return true
	var l: Vector3 = mokki.to_local(player.global_position)
	return Mokki.in_area(l.x, l.z, -150.0)


## Mökin oma lähitutka: sama kehys, mutta sisältö on mökin piha, järvi ja rakennukset kyläkartan sijaan
## (ks. mokki.gd:n julkiset _LOCAL/_CENTER-vakiot, jotka pitävät tämän ja mallinnuksen synkassa).
func _draw_mokki() -> void:
	var k := (SIZE_PX / 2.0) / MOKKI_RANGE
	var lp: Vector3 = mokki.to_local(player.global_position)
	var origin2 := Mokki.to_map2(Vector2(lp.x, lp.z))
	var wl := func(local: Vector2) -> Vector2:
		return (Mokki.to_map2(local) - origin2) * k + _center  # pohjoinen ylös (karttakehys)
	if _mokki_tex == null:
		if not _mokki_building:
			_mokki_building = true
			_bake_mokki()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.2, 0.12, 0.95))
	else:
		var src := Rect2((origin2 - _mokki_origin) * MOKKI_TEX_SCALE - Vector2.ONE * MOKKI_RANGE * MOKKI_TEX_SCALE,
			Vector2.ONE * 2.0 * MOKKI_RANGE * MOKKI_TEX_SCALE)
		draw_texture_rect_region(_mokki_tex, Rect2(Vector2.ZERO, size), src)
	_marker(wl.call(Vector2(Mokki.SAUNA_LOCAL.x, Mokki.SAUNA_LOCAL.z)), Color(0.55, 0.3, 0.16), "S")
	_marker(wl.call(Vector2(Mokki.TUB_LOCAL.x, Mokki.TUB_LOCAL.z)), Color(0.2, 0.5, 0.55), "A")
	_marker(wl.call(Vector2(Mokki.KITCHEN_LOCAL.x, Mokki.KITCHEN_LOCAL.z)), Color(0.6, 0.72, 0.82), "K")
	_marker(wl.call(Vector2(Mokki.DART_LOCAL.x, Mokki.DART_LOCAL.z)), Color(0.85, 0.15, 0.1), "Ti")
	_marker(wl.call(Vector2(Mokki.DOCK_LOCAL.x, Mokki.DOCK_LOCAL.z)), Color(0.5, 0.38, 0.24), "L")
	_marker(wl.call(Vector2(Mokki.RIDE_LOCAL.x, Mokki.RIDE_LOCAL.z)), Color(0.3, 0.42, 0.24), "Pk")
	_marker(wl.call(Vector2(Mokki.HUNT_LOCAL.x, Mokki.HUNT_LOCAL.z)), Color(0.3, 0.24, 0.15), "R")
	for f in mokki_forage:
		if not f.taken:
			var fp: Vector2 = wl.call(f.local)
			if Rect2(Vector2.ZERO, size).has_point(fp):
				draw_circle(fp, 3.0, Mokki.FORAGE_COLORS[f.kind])
	if player != null:
		var fwd3 := -player.global_transform.basis.z
		var f := (Mokki.to_map2(Vector2(fwd3.x, fwd3.z)) - Mokki.to_map2(Vector2.ZERO)).normalized()
		var r := f.orthogonal()
		var p := _center
		draw_colored_polygon(PackedVector2Array([p + f * 8.0, p - f * 5.0 + r * 5.0, p - f * 5.0 - r * 5.0]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85), false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 4, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


## Mökin lähikartan staattinen osa tekstuuriksi (kerran, kun pelaaja ensimmäisen kerran tulee mökin lähelle).
## Kattaa koko mökkialueen ja reunalla MOKKI_RANGE + 10 m marginaalin.
func _bake_mokki() -> void:
	var data: Dictionary = Mokki.map_data()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for a in data.area:
		var m: Vector2 = Mokki.to_map2(a)
		lo = lo.min(m)
		hi = hi.max(m)
	var pad := MOKKI_RANGE + 10.0
	lo -= Vector2(pad, pad)
	hi += Vector2(pad, pad)
	_mokki_origin = lo
	var tex_size := Vector2i(((hi - lo) * MOKKI_TEX_SCALE).ceil())
	var kk := (SIZE_PX / 2.0) / MOKKI_RANGE
	var wscale := MOKKI_TEX_SCALE / kk
	var wl := func(local: Vector2) -> Vector2:
		return (Mokki.to_map2(local) - lo) * MOKKI_TEX_SCALE
	var paint := func(c: Control) -> void:
		var tr := func(poly: PackedVector2Array) -> PackedVector2Array:
			var out := PackedVector2Array()
			for q in poly:
				out.append(wl.call(q))
			return out
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(tex_size)), Color(0.16, 0.2, 0.12, 0.95))
		# Oikean kartan kohteet (Mokki.map_data: OSM): pellot, piha, vesistöt, tiet ja naapurirakennukset.
		for f in data.fields:
			c.draw_colored_polygon(tr.call(f), Color(0.45, 0.5, 0.26))
		for b in data.bogs:
			c.draw_colored_polygon(tr.call(b), Color(0.4, 0.38, 0.24))
		var ep := PackedVector2Array()
		for i in 24:
			var an := TAU * i / 24
			ep.append(wl.call(Mokki.YARD_CENTER + Vector2(cos(an) * Mokki.YARD_R.x, sin(an) * Mokki.YARD_R.y)))
		c.draw_colored_polygon(ep, Color(0.36, 0.3, 0.2, 0.95))
		for w in data.water:
			c.draw_colored_polygon(tr.call(w), Color(0.3, 0.5, 0.75))
		for r in data.roads:
			c.draw_polyline(tr.call(r.pts), Color(0.75, 0.7, 0.55), 3.0 * wscale)
		for bd in data.buildings:
			if not (bd.id in Mokki.OWN_BUILDINGS):
				c.draw_colored_polygon(tr.call(bd.poly), Color(0.62, 0.6, 0.56))
		var half := Mokki.COTTAGE_SIZE / 2.0
		var ct := Mokki.COTTAGE_LOCAL
		c.draw_colored_polygon(PackedVector2Array([
			wl.call(ct + Vector2(-half.x, -half.y)), wl.call(ct + Vector2(half.x, -half.y)),
			wl.call(ct + Vector2(half.x, half.y)), wl.call(ct + Vector2(-half.x, half.y)),
		]), Color(0.24, 0.15, 0.09))
	_mokki_tex = await _render(tex_size, paint)


## Tutkan ulkopuolella oleva merkki pysyy reunalla oikeassa suunnassa.
func _clamp_edge(p: Vector2) -> Vector2:
	var m := 9.0
	return Vector2(clampf(p.x, m, size.x - m), clampf(p.y, m, size.y - m))


func _bike_icon(p: Vector2) -> void:
	draw_circle(p, 8.0, Color(0.1, 0.55, 0.9))
	for o in [-3.5, 3.5]:
		draw_arc(p + Vector2(o, 1.5), 2.6, 0, TAU, 10, Color.WHITE, 1.3)
	draw_line(p + Vector2(-3.5, 1.5), p + Vector2(0, -2.5), Color.WHITE, 1.3)
	draw_line(p + Vector2(0, -2.5), p + Vector2(3.5, 1.5), Color.WHITE, 1.3)


## Rahakätkö: kultainen €-merkki.
func _cache_icon(p: Vector2) -> void:
	draw_circle(p, 7.5, Color(0.1, 0.1, 0.1))
	draw_circle(p, 6.0, Color(1.0, 0.82, 0.15))
	draw_string(ThemeDB.fallback_font, p + Vector2(-4, 5), "€", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)


func _marker(p: Vector2, col: Color, txt: String) -> void:
	p = _clamp_edge(p)
	draw_circle(p, 7.0, col)
	draw_string(ThemeDB.fallback_font, p + Vector2(-4, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
