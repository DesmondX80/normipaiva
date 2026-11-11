extends Node
## Vaalan täytetalot (vaala.gd _fill_house, K1–K8): tyyppijakauma, paikkojen tyypit (koulu, kerrostalot, mökit),
## Katjan talo (house_doors len), kuvat (keskusta, Vaalantie, Sahanranta, sekstaajan paikat) ja ruutuaika.
## tools/testit/aja.sh tscn tools/testit/vaala_taytto_g.tscn
var out := "user://vaala_taytto_g"
var main: Node3D
var vl: Node3D
var cam: Camera3D
const VAA := [472392144, 534430539, 508285475, 508285476, 827456164, 827456090, 827456093, -100567, 1555230365]


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


func _shot(tag: String, from: Vector3, to: Vector3) -> void:
	cam.look_at_from_position(vl.to_global(from), vl.to_global(to), Vector3.UP)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/%s.png" % tag)
	var ts := Time.get_ticks_usec()
	for i in 20:
		await get_tree().process_frame
	print("kuva %s ruutuaika %.1f ms" % [tag, (Time.get_ticks_usec() - ts) / 1000.0 / 20.0])


func _g(c: Vector2) -> Vector3:
	return Vector3(c.x, vl.h(c.x, c.y), c.y)


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	while (main.get("mokki") == null) and Time.get_ticks_msec() - t0 < 400000:
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	main.clock_min = 12 * 60
	var tl := Time.get_ticks_msec()
	main._start_mopo()
	for n in 5:
		await get_tree().process_frame
	print("LATAUS Vaala %d ms" % (Time.get_ticks_msec() - tl))
	vl = main.mopo_trip.vaala
	for car in main.mopo_trip._cars:
		car.process_mode = Node.PROCESS_MODE_DISABLED
		car.visible = false
	main.mopo_trip.mopo.visible = false
	cam = Camera3D.new()
	cam.far = 3000.0
	cam.fov = 60.0
	vl.add_child(cam)
	cam.current = true
	for n in main.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var rows: Array = vl.fill_log
	var cnt := {}
	var main_n := 0
	for e: Dictionary in rows:
		cnt[e.t] = cnt.get(e.t, 0) + 1
	print("VAALA täytetaloja %d: %s" % [rows.size(), cnt])
	for t: String in ["K1", "K2", "K3", "K4", "K5", "K6", "K7", "K8"]:
		print("  %s %d (%.1f %%)" % [t, cnt.get(t, 0), 100.0 * cnt.get(t, 0) / maxi(rows.size(), 1)])
	for id in VAA:
		var s := ""
		for e: Dictionary in rows:
			if e.id == id:
				s += " %s%s %.0fx%.0f" % [e.t, "/" + str(e.get("v", "")) if e.get("v", "") != "" else "", e.l, e.d]
		print("PAIKKA %d: %s" % [id, s if s != "" else "VANHA (ei täytetaloa)"])
	var katja: Dictionary = {}
	for hd: Dictionary in vl.house_doors:
		if hd.id == vl.KATJA_ID:
			katja = hd
	print("KATJA ovi %s len %s; house_doors %d" % [katja.get("pos", "?"), katja.get("len", "?"), vl.house_doors.size()])
	var best_len := 0.0
	var best: Dictionary = {}
	for hd: Dictionary in vl.house_doors:
		var dd := Vector2(hd.pos.x - vl.station_door.x, hd.pos.z - vl.station_door.z).length()
		if dd >= 80.0 and dd <= 350.0 and float(hd.len) > best_len:
			best_len = float(hd.len)
			best = hd
	print("KATJAN VALINTA (main.gd 80-350 m, pisin len): id %s len %.1f" % [best.get("id", "?"), best_len])
	if best.get("id", 0) != vl.KATJA_ID:
		_vika("Katjan talo ei ole pisin len (valinta id %s)" % best.get("id", "?"))
	# Sivusuuntainen läpimenotarkistus: täytetalojen rungot eivät risteä keskenään.
	var ov := 0
	for i in rows.size():
		for j in range(i + 1, rows.size()):
			if rows[i].id == rows[j].id:
				continue
			var a: PackedVector2Array = rows[i].foot
			var b: PackedVector2Array = rows[j].foot
			if not Geometry2D.intersect_polygons(a, b).is_empty():
				ov += 1
	print("PÄÄLLEKKÄIN %d" % ov)
	if ov > 0:
		_vika("täytetalojen rungot päällekkäin %d" % ov)
	var up := Vector3.UP
	var ctr := Vector2(vl.station_door.x, vl.station_door.z)
	var kc := _g(ctr)
	await _shot("keskusta_viisto", kc + Vector3(-60, 22, 70), kc)
	await _shot("keskusta_ylha", kc + up * 160.0 + Vector3(0, 0, 0.1), kc)
	var vt := Vector2.ZERO
	var bn := 0
	for e: Dictionary in rows:
		var n := 0
		for e2: Dictionary in rows:
			if (e.c as Vector2).distance_to(e2.c) < 100.0:
				n += 1
		if n > bn and (e.c as Vector2).distance_to(ctr) > 150.0:
			bn = n
			vt = e.c
	var vg := _g(vt)
	print("VAALANTIE tihein kohta %s (%d taloa)" % [vt, bn])
	await _shot("vaalantie_viisto", vg + Vector3(-50, 20, 55), vg)
	await _shot("vaalantie_ylha", vg + up * 150.0 + Vector3(0, 0, 0.1), vg)
	var sr := Vector2.ZERO
	var sn := 0
	for e: Dictionary in rows:
		if int(e.id) <= -3000001:
			sr += e.c
			sn += 1
	if sn > 0:
		var sg := _g(sr / sn)
		print("SAHANRANTA %d taloa, keskus %s" % [sn, sr / sn])
		await _shot("sahanranta_viisto", sg + Vector3(-45, 20, 50), sg)
		await _shot("sahanranta_ylha", sg + up * 130.0 + Vector3(0, 0, 0.1), sg)
	for id in VAA:
		for bd: Dictionary in vl.data.buildings:
			if int(bd.id) == id:
				var cen := Vector2.ZERO
				for q in bd.pts:
					cen += Vector2(q[0], q[1])
				cen /= bd.pts.size()
				var p := _g(cen)
				await _shot("vaa_%d_ylha" % id, p + up * 110.0 + Vector3(0, 0, 0.1), p)
				await _shot("vaa_%d_viisto" % id, p + Vector3(-40, 22, 45), p + up * 2.0)
	get_tree().quit()
