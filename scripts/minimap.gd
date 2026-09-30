extends Control
## GTA-tyylinen tutka: pelaaja keskellä, pohjoinen ylös, näyttää ympäristön RANGE metrin säteellä.
## Tiet, metsät, pellot, vesistöt, Päivi, tavoite ja laavu. Kaukana olevat merkit näytetään reunalla.

const M := preload("res://scripts/map_data.gd")
const Mokki := preload("res://scripts/mokki.gd")

const SIZE_PX := 210.0
const RANGE := 320.0  # metriä keskeltä reunaan
const MOKKI_RANGE := 90.0  # mökin tutka on lähempänä tarkka, koska tasku on pieni
const MOKKI_SHOW_DIST := 420.0  # etäisyys mökin keskeltä, jolloin tutka vaihtaa mökin lähikarttaan

var player: Node3D
var wife: Node3D
var world: Node3D
var bike: Node3D  # näytetään kun liikutaan jalan
var mokki: Node3D
var target := Vector3.ZERO
var show_target := true

var _k := (SIZE_PX / 2.0) / RANGE
var _center := Vector2.ONE * SIZE_PX / 2.0
var _origin := Vector2.ZERO  # pelaajan paikka metreinä


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * SIZE_PX
	size = custom_minimum_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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


func _draw() -> void:
	if player != null:
		_origin = Vector2(player.global_position.x, player.global_position.z)
	if mokki != null and player != null and player.global_position.distance_to(mokki.global_position) < MOKKI_SHOW_DIST:
		_draw_mokki()
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.45, 0.28, 0.9))
	for f in M.FIELDS:
		draw_colored_polygon(_pts(f), Color(0.62, 0.6, 0.38, 0.95))
	for f in M.FORESTS:
		draw_colored_polygon(_pts(f), Color(0.2, 0.32, 0.16, 0.95))
	for c in M.CLEARINGS:
		draw_colored_polygon(_pts(c), Color(0.35, 0.45, 0.28, 0.95))
	for b in M.BOGS:
		draw_colored_polygon(_pts(b), Color(0.45, 0.43, 0.3, 0.95))
	for w in M.WATER:
		draw_colored_polygon(_pts(w), Color(0.3, 0.5, 0.75))
	for s in M.STREAMS:
		draw_polyline(_pts(s), Color(0.3, 0.5, 0.75), 1.5)
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
		draw_polyline(_pts(r.pts), col, width)

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
	if show_target:
		var t := _clamp_edge(_w(target))
		draw_arc(t, 8.0, 0, TAU, 20, Color(1, 0.9, 0.1), 2.5)
	if bike != null and bike != player:
		_bike_icon(_clamp_edge(_w(bike.global_position)))
	if wife != null and wife.is_inside_tree():
		draw_circle(_clamp_edge(_w(wife.global_position)), 4.5, Color(0.95, 0.1, 0.1))
	if player != null:
		var fwd3 := -player.global_transform.basis.z
		var f := Vector2(fwd3.x, fwd3.z).normalized()
		var r := f.orthogonal()
		var p := _center
		draw_colored_polygon(PackedVector2Array([p + f * 8.0, p - f * 5.0 + r * 5.0, p - f * 5.0 - r * 5.0]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85), false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 4, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


## Mökin oma lähitutka: sama kehys, mutta sisältö on mökin piha, järvi ja rakennukset kyläkartan sijaan
## (ks. mokki.gd:n julkiset _LOCAL/_CENTER-vakiot, jotka pitävät tämän ja mallinnuksen synkassa).
func _draw_mokki() -> void:
	var k := (SIZE_PX / 2.0) / MOKKI_RANGE
	var lp: Vector3 = mokki.to_local(player.global_position)
	var origin2 := Mokki.to_map2(Vector2(lp.x, lp.z))
	var wl := func(local: Vector2) -> Vector2:
		return (Mokki.to_map2(local) - origin2) * k + _center  # pohjoinen ylös (karttakehys)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.2, 0.12, 0.95))
	# Oikean kartan kohteet (Mokki.map_data: OSM): pellot, piha, vesistöt, tiet ja naapurirakennukset.
	var data: Dictionary = Mokki.map_data()
	var tr := func(poly: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in poly:
			out.append(wl.call(p))
		return out
	for f in data.fields:
		draw_colored_polygon(tr.call(f), Color(0.45, 0.5, 0.26))
	_ellipse(wl, Mokki.YARD_CENTER, Mokki.YARD_R.x, Mokki.YARD_R.y, Color(0.36, 0.3, 0.2, 0.95))
	for w in data.water:
		draw_colored_polygon(tr.call(w), Color(0.3, 0.5, 0.75))
	for r in data.roads:
		draw_polyline(tr.call(r.pts), Color(0.75, 0.7, 0.55), 3.0)
	for bd in data.buildings:
		if not (bd.id in Mokki.OWN_BUILDINGS):
			draw_colored_polygon(tr.call(bd.poly), Color(0.62, 0.6, 0.56))
	var half := Mokki.COTTAGE_SIZE / 2.0
	var c := Mokki.COTTAGE_LOCAL
	draw_colored_polygon(PackedVector2Array([
		wl.call(c + Vector2(-half.x, -half.y)), wl.call(c + Vector2(half.x, -half.y)),
		wl.call(c + Vector2(half.x, half.y)), wl.call(c + Vector2(-half.x, half.y)),
	]), Color(0.24, 0.15, 0.09))
	_marker(wl.call(Vector2(Mokki.SAUNA_LOCAL.x, Mokki.SAUNA_LOCAL.z)), Color(0.55, 0.3, 0.16), "S")
	_marker(wl.call(Vector2(Mokki.TUB_LOCAL.x, Mokki.TUB_LOCAL.z)), Color(0.2, 0.5, 0.55), "A")
	_marker(wl.call(Vector2(Mokki.KITCHEN_LOCAL.x, Mokki.KITCHEN_LOCAL.z)), Color(0.6, 0.72, 0.82), "K")
	_marker(wl.call(Vector2(Mokki.DART_LOCAL.x, Mokki.DART_LOCAL.z)), Color(0.85, 0.15, 0.1), "Ti")
	_marker(wl.call(Vector2(Mokki.DOCK_LOCAL.x, Mokki.DOCK_LOCAL.z)), Color(0.5, 0.38, 0.24), "L")
	_marker(wl.call(Vector2(Mokki.TAXI_LOCAL.x, Mokki.TAXI_LOCAL.z)), Color(0.96, 0.78, 0.08), "Tx")
	_marker(wl.call(Vector2(Mokki.HUNT_LOCAL.x, Mokki.HUNT_LOCAL.z)), Color(0.3, 0.24, 0.15), "R")
	if player != null:
		var fwd3 := -player.global_transform.basis.z
		var f := (Mokki.to_map2(Vector2(fwd3.x, fwd3.z)) - Mokki.to_map2(Vector2.ZERO)).normalized()
		var r := f.orthogonal()
		var p := _center
		draw_colored_polygon(PackedVector2Array([p + f * 8.0, p - f * 5.0 + r * 5.0, p - f * 5.0 - r * 5.0]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85), false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 4, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _ellipse(wl: Callable, local_center: Vector2, rx: float, rz: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24
		pts.append(wl.call(local_center + Vector2(cos(a) * rx, sin(a) * rz)))
	draw_colored_polygon(pts, col)


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


func _marker(p: Vector2, col: Color, txt: String) -> void:
	p = _clamp_edge(p)
	draw_circle(p, 7.0, col)
	draw_string(ThemeDB.fallback_font, p + Vector2(-4, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
