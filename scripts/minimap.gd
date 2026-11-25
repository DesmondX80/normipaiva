extends Control
## GTA-tyylinen tutka: pelaaja keskellä, pohjoinen ylös, näyttää ympäristön RANGE metrin säteellä.
## Tiet, metsät, pellot, vesistöt, Päivi, tavoite ja laavu. Kaukana olevat merkit näytetään reunalla.

const M := preload("res://scripts/map_data.gd")

const SIZE_PX := 210.0
const RANGE := 320.0  # metriä keskeltä reunaan
const FAR_RANGE := 450.0  # vireys-tilan palkinto (main.gd _stat_effects): tutka näkee kauemmas

var player: Node3D
var nimismies: Node3D  # jalan jahtaava nimismies: sama pylpyrä
var wife: Node3D
var police: Node3D  # jahtaava poliisiauto: sininen pylpyrä, kun Päivi on punainen
var world: Node3D
var bike: Node3D  # näytetään kun liikutaan jalan
var game: Node  # main.gd: cache_markers()
var target := Vector3.ZERO
var show_target := true

## Staattinen kartta (pellot, metsät, vedet, tiet, rakennukset) piirretään kerran tekstuuriksi (SubViewport) ja
## joka ruudulla näytetään vain pelaajan ympärille leikattu pala. Ennen kartta piirrettiin kokonaan uudelleen joka
## ruudulla (satoja monikulmioita ja polyviivoja, pisteet muunnettuna GDScriptillä), mikä vei heikolla koneella
## yli puolet ruudun ajasta. TEX_SCALE = tekstuuripikseliä metriä kohti.
const TEX_SCALE := 0.5

class _Painter extends Control:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


var _village_tex: Texture2D
var _village_origin := Vector2.ZERO  # tekstuurin vasen yläkulma maailman metreinä
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


## Tekstuurin alue ruudulle. Kartan reunalla lähdealue ylittää tekstuurin: vain tekstuurin sisälle jäävä osa piirretään
## samassa mittakaavassa ja loppu täytetään taustavärillä (muuten reunapikselit venyisivät raidoiksi ja kartta liukuisi
## pelaajan merkin alta).
func _draw_tex_region(tex: Texture2D, src: Rect2, bg: Color) -> void:
	var full := Rect2(Vector2.ZERO, size)
	var clipped := src.intersection(Rect2(Vector2.ZERO, tex.get_size()))
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		draw_rect(full, bg)
		return
	if clipped.size.is_equal_approx(src.size):
		draw_texture_rect_region(tex, full, src)
		return
	draw_rect(full, bg)
	var k := size / src.size
	draw_texture_rect_region(tex, Rect2((clipped.position - src.position) * k, clipped.size * k), clipped)


func _draw() -> void:
	if player != null:
		_origin = Vector2(player.global_position.x, player.global_position.z)
	if _village_tex != null:
		var src := Rect2((_origin - _village_origin) * TEX_SCALE - Vector2.ONE * range_m * TEX_SCALE, Vector2.ONE * 2.0 * range_m * TEX_SCALE)
		_draw_tex_region(_village_tex, src, Color(0.35, 0.45, 0.28, 0.9))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.45, 0.28, 0.9))
	_marker(_px(M.HOME_ZONE), Color(0.3, 1.0, 0.4), "K")
	_marker(_px(M.SHOP_ZONE), Color(1.0, 0.5, 0.0), "M")
	_marker(_px(M.LAAVU), Color(0.75, 0.5, 0.25), "L")
	_marker(_px(M.GRILLIKATOS), Color(0.35, 0.8, 0.35), "G")
	_marker(_px(M.KOTA), Color(0.85, 0.6, 0.3), "Ko")
	if world != null and world.apteekki_s.has("knock"):
		_marker(_px(M.to_px(world.apteekki_s.knock)), Color(0.1, 0.55, 0.25), "A")
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
	if police != null and is_instance_valid(police) and police.is_inside_tree():
		_police_icon(_clamp_edge(_w(police.global_position)))
	if _nimismies_ok():
		_police_icon(_clamp_edge(_w(nimismies.global_position)))
	if player != null:
		var fwd3 := -player.global_transform.basis.z
		var f := Vector2(fwd3.x, fwd3.z).normalized()
		var r := f.orthogonal()
		var p := _center
		draw_colored_polygon(PackedVector2Array([p + f * 8.0, p - f * 5.0 + r * 5.0, p - f * 5.0 - r * 5.0]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85), false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 4, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)












## Tutkan ulkopuolella oleva merkki pysyy reunalla oikeassa suunnassa.
func _clamp_edge(p: Vector2) -> Vector2:
	var m := 9.0
	return Vector2(clampf(p.x, m, size.x - m), clampf(p.y, m, size.y - m))


func _nimismies_ok() -> bool:
	return nimismies != null and is_instance_valid(nimismies) and nimismies.is_inside_tree()


## Jahtaava poliisi: sininen vilkkuva pylpyrä valkoisella reunalla.
func _police_icon(p: Vector2) -> void:
	var flash := int(Time.get_ticks_msec() / 250) % 2 == 0
	var rad := 6.5 if flash else 5.0
	draw_circle(p, rad, Color(0.15, 0.35, 1.0))
	draw_arc(p, rad, 0, TAU, 16, Color.WHITE, 1.5)


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
