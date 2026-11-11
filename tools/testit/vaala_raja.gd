extends Node
## Vaalan reitin vyöhyke (vaala.gd VAALA_RAJA_M = 150 m): rakennusten karsinta, route_dist (oikea vs raaka silmukka),
## suojatut talot, pehmeä seinä (reach_clamp) jalan ja mopolla, ilmoituksen toistuminen (8 s) ja kuvat.
## tools/testit/aja.sh tscn tools/testit/vaala_raja.tscn
var out := "user://vaala_raja"
var main: Node3D
var vl: Node3D
var mt: Node3D
var cam: Camera3D
var _blocked := 0
var _edges: Array = []
const RAJA := 150.05


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


func _shot(tag: String, from: Vector3, to: Vector3, ui := false) -> void:
	for n in main.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = ui
	cam.look_at_from_position(vl.to_global(from), vl.to_global(to), Vector3.UP)
	cam.current = true
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/%s.png" % tag)


func _g(c: Vector2, up := 0.0) -> Vector3:
	return Vector3(c.x, vl.h(c.x, c.y) + up, c.y)


## Raaka etäisyys kaikkiin jänteisiin (vertailu route_dist:lle).
func _brute(p: Vector2) -> float:
	var best := INF
	for k: Vector2i in vl._route_grid:
		var sg: Array = vl._route_grid[k]
		for i in range(0, sg.size(), 2):
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, sg[i], sg[i + 1])))
	return best


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	while main.get("mokki") == null and Time.get_ticks_msec() - t0 < 400000:
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	main.clock_min = 12 * 60
	# Häiriöt pois: päivä seisoo, ei kiinnijääntiä.
	main.set_process_unhandled_input(false)
	var tl := Time.get_ticks_msec()
	main._start_mopo(false)
	for n in 5:
		await get_tree().process_frame
	print("LATAUS Vaala %d ms" % (Time.get_ticks_msec() - tl))
	mt = main.mopo_trip
	vl = mt.vaala
	mt.reach_blocked.connect(func() -> void: _blocked += 1)
	for car in mt._cars:
		car.process_mode = Node.PROCESS_MODE_DISABLED
		car.visible = false
	cam = Camera3D.new()
	cam.far = 3000.0
	cam.fov = 60.0
	vl.add_child(cam)
	_buildings()
	_dist_check()
	await _walk()
	await _mopo()
	await _shots()
	print("TESTI valmis")
	get_tree().quit()


func _buildings() -> void:
	var cs: Dictionary = vl.cull_stats
	print("KARSINTA %s" % cs)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(vl.TIE))
	var named := 0
	var named_left := 0
	var left_ids := {}
	for bd in vl.data.buildings:
		left_ids[int(bd.id)] = true
	for bd in raw.buildings:
		if str(bd.name) != "":
			named += 1
			if left_ids.has(int(bd.id)):
				named_left += 1
	print("NIMETYT talot %d, jäljellä %d" % [named, named_left])
	if left_ids.size() != cs.jalkeen:
		_vika("data.buildings %d != karsinnan jälkeen %d" % [left_ids.size(), cs.jalkeen])
	if not left_ids.has(vl.KATJA_ID):
		_vika("Katjan talo poistui")
	var far := 0
	for bd in vl.data.buildings:
		var pts := PackedVector2Array()
		for q in bd.pts:
			pts.append(Vector2(q[0], q[1]))
		var dmin := INF
		var c := Vector2.ZERO
		for q in pts:
			c += q
			dmin = minf(dmin, vl.route_dist(q))
		dmin = minf(dmin, vl.route_dist(c / maxi(pts.size(), 1)))
		if dmin > RAJA and not vl._cull_protected(bd, int(bd.id), pts):
			far += 1
	print("EI-SUOJATTUJA yli rajan: %d" % far)
	if far > 0:
		_vika("ei-suojattuja taloja yli %.0f m reitistä: %d" % [vl.VAALA_RAJA_M, far])
	print("RAKENNETUT talot (törmäyspohjat): %d" % vl._bld_polys.size())


func _dist_check() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad := 0
	for i in 40:
		var m: Array = vl.road[rng.randi_range(0, vl.road.size() - 1)]
		var p := Vector2(m[0], m[2]) + Vector2(rng.randf_range(-400, 400), rng.randf_range(-400, 400))
		var a: float = vl.route_dist(p)
		var b := _brute(p)
		if absf(a - b) > 0.01:
			bad += 1
	print("ROUTE_DIST vs raaka: eroja %d / 40" % bad)
	if bad > 0:
		_vika("route_dist poikkeaa raa'asta silmukasta %d/40" % bad)
	var dbad := 0
	for d: Dictionary in vl.doors:
		if vl.route_dist(Vector2(d.pos.x, d.pos.z)) > RAJA:
			dbad += 1
			print("  ovi reitin ulkopuolella: %s %s %.1f m" % [d.id, d.pos, vl.route_dist(Vector2(d.pos.x, d.pos.z))])
	print("OVET yli rajan reitistä: %d / %d" % [dbad, vl.doors.size()])
	if dbad > 0:
		_vika("ovia reitin ulkopuolella %d" % dbad)
	var q: Vector2 = vl._mokki_c()
	if vl.route_dist(q) > 1.0:
		_vika("mökki ei reitillä")
	var t := Time.get_ticks_usec()
	for i in 200:
		vl.reach_clamp(Vector3(rng.randf_range(0, 1000), 130, rng.randf_range(-1000, 0)))
	print("reach_clamp %.3f ms/kutsu (satunnainen)" % ((Time.get_ticks_usec() - t) / 200000.0))


func _walk() -> void:
	main._mopo_dismount()
	var w: CharacterBody3D = mt.on_foot
	if w == null:
		_vika("ei jalkaa")
		return
	var starts: Array = []
	var n: int = vl.road.size()
	for k in [0.15, 0.45, 0.8]:
		var m: Array = vl.road[int(n * k)]
		starts.append(Vector2(m[0], m[2]))
	starts.append(vl._mokki_c())
	starts.append(Vector2(vl.data.lava.x, vl.data.lava.z))
	var ang := 0.3
	for s: Vector2 in starts:
		# suunta, jossa 260 m päässä ollaan selvästi vyöhykkeen ulkopuolella (ja kuivalla)
		for k in 24:
			ang = 0.3 + k * TAU / 24.0 + s.x * 0.001
			var far := s + Vector2.from_angle(ang) * 260.0
			if vl.route_dist(far) > 170.0 and not vl.wet(far.x, far.y, 0.3):
				break
		var dir := Vector2.from_angle(ang)
		var pos := s
		var maxd := 0.0
		mt._reach_msg_t = 0.0
		_blocked = 0
		var dt := 0.1
		var steps := 0
		# ulos asti
		while steps < 700:
			pos += dir * 0.7
			w.global_position = mt.to_global(_g(pos))
			mt._process(dt)
			var lp: Vector3 = mt.to_local(w.global_position)
			maxd = maxf(maxd, vl.route_dist(Vector2(lp.x, lp.z)))
			steps += 1
			if _blocked > 0:
				break
		var lp0: Vector3 = mt.to_local(w.global_position)
		var edge := Vector2(lp0.x, lp0.z)
		var blocked_at := steps
		_edges.append([edge, dir])
		# liuku: työnnetään koko ajan ulos + sivulle, 20 s
		var o: Vector2 = (edge - vl.route_nearest(edge)).normalized()
		var tvec := Vector2(-o.y, o.x)
		var moved := 0.0
		var tried := 0.0
		_blocked = 0
		mt._reach_msg_t = 0.0
		for i in 200:
			var before := Vector2(mt.to_local(w.global_position).x, mt.to_local(w.global_position).z)
			var np: Vector2 = before + o * 0.3 + tvec * 0.6
			w.global_position = mt.to_global(_g(np))
			mt._process(dt)
			var lp: Vector3 = mt.to_local(w.global_position)
			var after := Vector2(lp.x, lp.z)
			maxd = maxf(maxd, vl.route_dist(after))
			moved += (after - before).length()
			tried += 0.6
			o = (after - vl.route_nearest(after)).normalized() if after != vl.route_nearest(after) else o
			tvec = Vector2(-o.y, o.x)
		print("JALAN lähtö %s suunta %.0f°: raja saavutettu %d askeleella, suurin etäisyys %.2f, liuku %.0f / %.0f m, ilmoituksia 20 s: %d" % [
			s.round(), rad_to_deg(ang), blocked_at, maxd, moved, tried, _blocked])
		if maxd > RAJA:
			_vika("jalan yli rajan: %.2f" % maxd)
		if moved < 0.5 * tried:
			_vika("liuku jumittaa: %.0f / %.0f" % [moved, tried])
		if _blocked < 2 or _blocked > 3:
			_vika("ilmoituksia 20 s aikana %d (odotus 2-3)" % _blocked)
	print("ILMOITUS main: teksti '%s' aika %.1f" % [main._msg.text, main._msg_time])


func _mopo() -> void:
	main._mopo_remount()
	var m: CharacterBody3D = mt.mopo
	var base: Array = vl.road[vl.road.size() / 2]
	var p := Vector2(base[0], base[2])
	var bad := 0
	var tried := 0
	for a in [0.4, 1.9, 3.3, 5.0]:
		var q := p + Vector2.from_angle(a) * 420.0
		while vl.route_dist(q) < 170.0 and tried < 400:
			q = p + Vector2.from_angle(a + tried * 0.37) * (250.0 + tried * 5.0)
			tried += 1
		m.position = _g(q, 0.5)
		m.speed = 8.0
		mt._process(0.1)
		var d: float = vl.route_dist(Vector2(m.position.x, m.position.z))
		if d > RAJA:
			bad += 1
		print("MOPO spawn ulos -> etäisyys %.2f, nopeus %.1f" % [d, m.speed])
	if bad > 0:
		_vika("mopo jäi rajan ulkopuolelle %d" % bad)


func _fog(on: bool) -> void:
	var we := main.get_node_or_null("WorldEnvironment")
	if we != null:
		we.environment.fog_enabled = on


func _shots() -> void:
	if _edges.is_empty():
		_vika("ei reunapistettä kuviin")
		return
	var edge: Vector2 = _edges[0][0]
	var o: Vector2 = _edges[0][1]
	print("REUNAPISTE %s suunta %s" % [edge, o])
	var e := edge - o * 1.0
	var s := Vector2(vl.siitari.x, vl.siitari.y)
	_fog(false)
	await _shot("a_yla", _g(e - o * 150.0, 450.0), _g(e + o * 60.0))
	await _shot("d_reuna_yla", _g(e - o * 300.0, 140.0), _g(e + o * 100.0, 0.0))
	_fog(true)
	await _shot("b_reuna_ulos", _g(e, 1.7), _g(e + o * 100.0, 4.0))
	await _shot("c_reuna_sisaan", _g(e, 1.7), _g(e - o * 100.0, 4.0))
	# horisontti reunalta, korkeammalta (ei tyhjää näkyvissä?)
	await _shot("f_horisontti", _g(e, 30.0), _g(e + o * 400.0, 10.0))
	# ilmoitus ruudulla pelikameralla: jalan reunalla, viimeinen työntö ilmoituksen jälkeen
	main._mopo_remount()
	main._mopo_dismount()
	var w: CharacterBody3D = mt.on_foot
	mt._reach_msg_t = 0.0
	main._msg_time = 0.0
	main._msg.text = ""
	w.global_position = mt.to_global(_g(e + o * 6.0))
	mt._process(0.1)
	for n in main.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = true
	cam.current = false
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/e_ilmoitus.png")
	print("ILMOITUS ruudulla: '%s' %.1f s" % [main._msg.text, main._msg_time])
	if main._msg.text == "":
		_vika("ilmoitusta ei näy ruudulla")
