extends Node
## Saloisten täytetalot (world.gd _fill_house, K1–K5) pelimaailmassa (osa B): tyyppimäärät pää- ja
## piharakennuksille, poikkeuslistan (FILL_KEEP) talot ennallaan, katoksen, aidan ja piharakennuksen raot tiehen
## ja toisiin pohjiin, rungon päällekkäisyys toisiin täytetaloihin, ruutuaika ja kuvat (kylä, reuna, kaukomaisema,
## yläkuva, lähikuvat K2-katoksesta ja K5-aidasta). Vika = "TESTI VIKA".
## tools/testit/aja.sh tscn tools/testit/saloinen_taytto_b.tscn
const M := preload("res://scripts/map_data.gd")
const W := preload("res://scripts/world.gd")

var out := "user://saloinen_taytto_b"
var main: Node3D
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	load("res://scripts/main.gd").skip_menu = true
	main = load("res://main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _vika(t: String) -> void:
	print("TESTI VIKA " + t)


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	while (main.get("mokki") == null) and Time.get_ticks_msec() - t0 < 400000:
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	main.clock_min = 12 * 60
	var w: Node3D = main.world
	var rows: Array = w.fill_log
	_counts(rows)
	_keep(w, rows)
	_overlaps(w, rows)
	cam = Camera3D.new()
	cam.far = 3000.0
	cam.fov = 60.0
	main.add_child(cam)
	cam.current = true
	if main.get("player") != null:
		main.player.visible = false
	for n in main.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var up := Vector3.UP
	# Kylä: tihein kohta (eniten päätaloja 120 m säteellä).
	var best := Vector2.ZERO
	var bn := 0
	for e: Dictionary in rows:
		var n := 0
		for e2: Dictionary in rows:
			if not e2.piha and (e.c as Vector2).distance_to(e2.c) < 120.0:
				n += 1
		if n > bn:
			bn = n
			best = e.c
	print("SALOINEN tihein kohta %s (%d taloa 120 m sisällä)" % [best, bn])
	var kc := _g(best)
	await _shot("kyla", kc + Vector3(-45, 4.0, 40), kc + up * 2.0)
	await _shot("kyla_2", kc + Vector3(50, 3.0, -30), kc + up * 2.0)
	var env: WorldEnvironment = main.find_children("*", "WorldEnvironment", true, false)[0]
	var fog := env.environment.fog_enabled
	env.environment.fog_enabled = false
	await _shot("ylakuva", kc + up * 160.0 + Vector3(0, 0, 0.1), kc)
	env.environment.fog_enabled = fog
	await _shot("kaukomaisema", kc + Vector3(-260, 45, 200), kc)
	# Reuna: pellon laidan lato (K4) tai muuten kauimpana tihein kohdasta oleva päätalo.
	var edge: Dictionary = {}
	for e: Dictionary in rows:
		if e.t == "K4":
			edge = e
			break
	if edge.is_empty():
		edge = rows[0]
	var ec := _g(edge.c)
	await _shot("reuna", ec + Vector3(30, 5.0, 30), ec + up * 2.0)
	for t in ["K2", "K5", "K1", "K3"]:
		for e: Dictionary in rows:
			if e.t == t and not e.piha and (t != "K2" or e.has("katos")) and (t != "K5" or e.has("aita")):
				var c := _g(e.c)
				var fwd := Vector3(-sin(e.yaw), 0, -cos(e.yaw))  # -Z = julkisivu
				await _shot("lahi_" + t, c + fwd * 16.0 + fwd.cross(up) * 7.0 + up * 3.0, c + up * 2.5)
				break
	get_tree().quit()


func _g(c: Vector2) -> Vector3:
	return Vector3(c.x, W.T.h(c.x, c.y), c.y)


func _counts(rows: Array) -> void:
	var n := {}
	var np := {}
	for e: Dictionary in rows:
		var d: Dictionary = np if e.piha else n
		d[e.t] = d.get(e.t, 0) + 1
		if not e.t in ["K1", "K2", "K3", "K4", "K5"]:
			_vika("täytetalo tyyppiä %s" % e.t)
	var total := 0
	for k in n:
		total += n[k]
	var parts: Array[String] = []
	for t in ["K1", "K2", "K3", "K4", "K5"]:
		parts.append("%s %d (%.1f %%)" % [t, n.get(t, 0), 100.0 * n.get(t, 0) / maxi(total, 1)])
	print("SALOINEN päätalot %d: %s; piharakennukset %s" % [total, ", ".join(parts), np])
	if total < 40:
		_vika("täytetaloja vain %d" % total)


## Poikkeuslistan talot: vanha _house-malli, ei täytetaloa samalla pohjalla.
func _keep(w: Node3D, rows: Array) -> void:
	for q: Vector2 in W.FILL_KEEP:
		var f: Dictionary = w._osm_fit_at(q)
		if f.is_empty():
			print("SALOINEN poikkeus %s: ei OSM-pohjaa" % q)
			continue
		var ax: Vector2 = f.ax
		for e: Dictionary in rows:
			var dv: Vector2 = (e.c as Vector2) - (f.c as Vector2)
			if absf(dv.dot(ax)) < f.l / 2.0 and absf(dv.dot(ax.orthogonal())) < f.d / 2.0:
				_vika("poikkeuslistan talon %s päällä täytetalo %s" % [q, e.t])
	print("SALOINEN poikkeuslista %d pistettä tarkistettu" % W.FILL_KEEP.size())


## Pihan osat (katos, aita, piharakennus) eivät tiellä, vedessä tai toisen talon päällä; rungot eivät toistensa päällä.
func _overlaps(w: Node3D, rows: Array) -> void:
	var on_road := 0
	var on_road_runko := 0
	var cross := 0
	var area_sum := 0.0
	for i in rows.size():
		var e: Dictionary = rows[i]
		var polys: Array = [e.foot]
		for k in ["katos", "aita"]:
			if e.has(k):
				polys.append(e[k])
		for pi in polys.size():
			var poly: PackedVector2Array = polys[pi]
			for q in poly:
				if w._road_clearance(q) < 0.0 or w._in_any(q, w._water):
					if pi > 0 or e.piha:
						on_road += 1
						if on_road <= 5:
							print("SALOINEN pihan osa tiellä/vedessä: %s %s" % [e.t, q])
					else:
						on_road_runko += 1
					break
		for j in range(i + 1, rows.size()):
			var e2: Dictionary = rows[j]
			if (e.c as Vector2).distance_to(e2.c) > 40.0:
				continue
			var p2: Array = [e2.foot]
			for k in ["katos", "aita"]:
				if e2.has(k):
					p2.append(e2[k])
			for ia in polys.size():
				for ib in p2.size():
					for r in Geometry2D.intersect_polygons(polys[ia], p2[ib]):
						var ar := _area(r)
						if ar > 0.05:
							cross += 1
							area_sum += ar
							if cross <= 5:
								print("SALOINEN päällekkäin %s (osa %d, piha %s, %s) ja %s (osa %d, piha %s, %s): %.2f m²" % [
									e.t, ia, e.piha, e.c, e2.t, ib, e2.piha, e2.c, ar])
	# Puut täytetalojen sisällä (rungon pohja): metsän sirottelu ja pihapuut väistävät _add_house-pisteitä.
	var in_tree := 0
	for ti in w._trees.size():
		var t: Array = w._trees[ti]
		var tp: Vector2 = t[0]
		for e: Dictionary in rows:
			if (e.c as Vector2).distance_to(tp) < 12.0 and Geometry2D.is_point_in_polygon(tp, e.foot):
				in_tree += 1
				if in_tree <= 5:
					print("SALOINEN puu %s talon %s sisällä (%s; puu %d/%d, koko %.2f, törmäys %s, piha %s, talo %s)" % [t[1], e.t, tp, ti, w._trees.size(), t[2], t[3], e.piha, e.c])
	print("SALOINEN puita täytetalon sisällä %d" % in_tree)
	if in_tree > 0:
		_vika("%d puuta täytetalon sisällä" % in_tree)
	print("SALOINEN pihan osia tiellä/vedessä %d, runkoja OSM-pohjan mukaan tiellä %d, päällekkäin %d (%.1f m²)" % [on_road, on_road_runko, cross, area_sum])
	print("SALOINEN tien päältä pois jätettyjä pohjia %d" % w.fill_skipped)
	if on_road_runko > 0:
		_vika("%d täytetalon runko tiellä tai vedessä" % on_road_runko)
	if on_road > 0:
		_vika("%d pihan osaa tiellä tai vedessä" % on_road)
	if cross > 0:
		_vika("%d täytetaloa päällekkäin (%.1f m²)" % [cross, area_sum])


func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		s += p[i].cross(p[(i + 1) % p.size()])
	return absf(s) / 2.0


func _shot(nm: String, from: Vector3, to: Vector3) -> void:
	cam.look_at_from_position(from, to)
	for i in 20:
		await get_tree().process_frame
	var ts := Time.get_ticks_usec()
	var frames := 10
	for i in frames:
		await get_tree().process_frame
	var ms := (Time.get_ticks_usec() - ts) / 1000.0 / frames
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("kuva_%s.png" % nm))
	print("kuva %s ruutuaika %.1f ms" % [nm, ms])
