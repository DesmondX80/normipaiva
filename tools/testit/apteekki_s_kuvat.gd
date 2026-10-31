extends Node
## Saloisten apteekki (apteekki_saloinen.gd, huumekauppa Saloisiin erä A) pelimaailmassa: paikka ja raot tiehen,
## halleihin ja puihin, hoitajan raot komeroon ja läpimenot (Asento.solids), kuvat edestä, takaa, viistosta,
## ylhäältä, pelikameralta koputuspisteeltä, takaovelta ja luukulta (luukku auki). Rakojen alitus = "TESTI VIKA".
## tools/testit/aja.sh tscn tools/testit/apteekki_s_kuvat.tscn
## Nopea tarkistus ilman pelimaailmaa (vain runko ja hoitaja): ... apteekki_s_kuvat.tscn --vain-hoitaja
const Asento := preload("res://tools/testit/asento.gd")
const Pose := preload("res://scripts/pose.gd")
const Ap := preload("res://scripts/apteekki_saloinen.gd")
const Makasiini := preload("res://scripts/makasiini.gd")

var out := "user://apteekki_s"
var main: Node3D
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	if args.has("--vain-hoitaja"):
		_run_alone.call_deferred()
		return
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
	var a: Dictionary = w.apteekki_s
	if a.is_empty():
		_vika("apteekkia ei rakennettu")
		get_tree().quit()
		return
	var root: Node3D = a.root
	var door: Node3D = a.back
	var nurse: Node3D = a.nurse
	var xf := root.global_transform
	print("APTEEKKI_S juuri %s knock %s out %s stoop_top %s" % [xf.origin, a.knock, a.out, a.stoop_top])
	_gaps(w, xf)
	cam = Camera3D.new()
	cam.far = 3000.0
	cam.fov = 60.0
	main.add_child(cam)
	cam.current = true
	if main.get("player") != null:
		main.player.visible = false
	for n in main.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false  # HUD pois kuvista
	var c := xf.origin
	var fz := xf.basis.z
	var fx := xf.basis.x
	var up := Vector3.UP
	await _shot("edesta", c + fz * 18.0 + up * 3.0, c + up * 2.0)
	await _shot("takaa", c - fz * 16.0 + fx * 2.0 + up * 3.0, c + up * 2.0)
	await _shot("viisto", c + (fz + fx).normalized() * 20.0 + up * 6.0, c + up * 1.5)
	await _shot("viisto_taka", c + (-fz - fx).normalized() * 20.0 + up * 6.0, c + up * 1.5)
	await _shot("ylhaalta", c + up * 70.0 + fz * 0.1, c)
	var kp: Vector3 = a.knock
	var dg := door.global_transform
	await _shot("pelikamera", kp - (a.out as Vector3) * -4.5 + up * 2.6, dg.origin + up * 1.4)
	await _shot("takaovi", dg * Vector3(0.6, 1.6, 2.6), dg * Vector3(0, 1.3, 0))
	await _nurse_views(root, door, nurse, a.fill)
	get_tree().quit()


## Ilman pelimaailmaa: valo, runko ja hoitaja origossa.
func _run_alone() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.7, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(env)
	var root := Node3D.new()
	add_child(root)
	var parts: Dictionary = Ap._build_body(root)
	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.current = true
	await _nurse_views(root, parts.back, parts.nurse, parts.fill)
	get_tree().quit()


## Luukku auki ja valo päällä kuten myynnissä (main.gd _hs_hatch): raot, läpimenot ja kuvat luukulta, ilman ovilehteä
## edestä, ylhäältä ja sivulta.
func _nurse_views(root: Node3D, door: Node3D, nurse: Node3D, fill: Node3D) -> void:
	# Luukku auki ja valo päällä kuten myynnissä (main.gd _hs_hatch).
	door.get_node("Ovi/Luukku").position.x = -0.5 + Makasiini.HATCH_TRAVEL
	fill.visible = true
	for i in 10:
		await get_tree().process_frame
	print("APTEEKKI_S hoitajan animaatio %s @ %.2f s, nopeus %.1f" % [nurse.anim.current_animation, nurse.anim.current_animation_position, nurse.anim.speed_scale])
	_nurse_gaps(nurse, door)
	var bad := Asento.solids(nurse, door, 1.0)
	print("APTEEKKI_S hoitaja läpimenot %d" % bad)
	var dg := door.global_transform
	await _shot("luukku", dg * Vector3(0.05, Makasiini.HATCH_Y + 0.05, 0.55), dg * Vector3(-0.15, Makasiini.HATCH_Y, 0))
	# Hoitaja ilman ovilehteä (asento ja raot komeroon): edestä, sivulta ja ylhäältä.
	door.get_node("Ovi").visible = false
	await _shot("hoitaja_edesta", dg * Vector3(0, 1.0, 2.2), dg * Vector3(0, 0.9, -0.2))
	for n in door.get_children():  # komeron laudat piiloon: hoitaja ylhäältä ja sivulta
		if n is MeshInstance3D and n.name != "Jakkara" and n.name != "Polttimo":
			n.visible = false
	for n in root.get_children():  # katto ja kattoreunus piiloon
		if n is MeshInstance3D and (n as MeshInstance3D).global_position.y > root.global_position.y + Ap.F + Ap.H - 0.1:
			n.visible = false
	await _shot("hoitaja_ylhaalta", dg * Vector3(0, 3.2, -0.2) + Vector3(0.01, 0, 0), dg * Vector3(0, 0, -0.2))
	root.get_child(1).visible = false  # runko piiloon, hoitaja sivulta näkyviin
	await _shot("hoitaja_sivu", dg * Vector3(2.4, 1.2, -0.2), dg * Vector3(0, 0.9, -0.2))


## Raot: pohjan ja pihan kulmat tien reunaan, esteiden (hallien) reunoihin ja lähimpään puuhun.
func _gaps(w: Node3D, xf: Transform3D) -> void:
	var fp := Ap.FOOTPRINT
	var road := INF
	for i in 9:
		for j in 6:
			var q := xf * Vector3(fp.position.x + fp.size.x * i / 8.0, 0, fp.position.y + fp.size.y * j / 5.0)
			road = minf(road, w._road_clearance(Vector2(q.x, q.z)))
	var hall := INF
	var c2 := Vector2(xf.origin.x, xf.origin.z)
	for o in w.blockers:
		if (o[0] as Vector2).distance_to(c2) < 0.5 or (o[0] as Vector2).distance_to(c2) > 120.0:
			continue
		hall = minf(hall, _rect_dist(o, xf))
	var tree := INF
	for t in w._trees:
		var p: Vector2 = t[0]
		var l := xf.affine_inverse() * Vector3(p.x, xf.origin.y, p.y)
		var dx := maxf(absf(l.x) - Ap.L / 2.0, 0.0)
		var dz := maxf(absf(l.z) - Ap.D / 2.0, 0.0)
		if l.z < -Ap.D / 2.0:
			dz = maxf(-l.z - Ap.D / 2.0 - Ap.STOOP.z, 0.0) if absf(l.x - Ap.DOOR_X) < Ap.STOOP.x / 2.0 else dz
		tree = minf(tree, Vector2(dx, dz).length())
	print("APTEEKKI_S raot: tie %.1f m (≥ 12), halli %.1f m (≥ 8), puu %.1f m (≥ 3)" % [road, hall, tree])
	if road < 12.0:
		_vika("apteekki liian lähellä tietä %.1f m" % road)
	if hall < 8.0:
		_vika("apteekki liian lähellä hallia %.1f m" % hall)
	if tree < 3.0:
		_vika("puu liian lähellä apteekkia %.1f m" % tree)


## Esteen (blocker [c, puolikoko, yaw]) lyhin etäisyys apteekin pohjaan (näytepisteet pohjan reunalta).
func _rect_dist(o: Array, xf: Transform3D) -> float:
	var best := INF
	for i in 21:
		for side in 4:
			var s := i / 20.0
			var lp: Vector3
			match side:
				0: lp = Vector3(-Ap.L / 2.0 + s * Ap.L, 0, -Ap.D / 2.0)
				1: lp = Vector3(-Ap.L / 2.0 + s * Ap.L, 0, Ap.D / 2.0)
				2: lp = Vector3(-Ap.L / 2.0, 0, -Ap.D / 2.0 + s * Ap.D)
				_: lp = Vector3(Ap.L / 2.0, 0, -Ap.D / 2.0 + s * Ap.D)
			var g := xf * lp
			var q := (Vector2(g.x, g.z) - (o[0] as Vector2)).rotated(o[2])
			var hs: Vector2 = o[1]
			best = minf(best, Vector2(maxf(absf(q.x) - hs.x, 0.0), maxf(absf(q.y) - hs.y, 0.0)).length())
	return best


## Hoitajan pinnan raot komeroon oven kehyksessä (+Z ulos): selkä takaseinän sisäpintaan, nenä ovilehden
## sisäpintaan, olkapäät sivuseiniin, jalat lattiaan (tai jakkaraan). Silmien korkeus luukkuun.
func _nurse_gaps(nurse: Node3D, door: Node3D) -> void:
	var pts := Pose.limb_points(nurse, door, ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
		"clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"])
	var feet := Pose.limb_points(nurse, door, ["foot_l", "foot_r", "ball_l", "ball_r"])
	if pts.is_empty():
		print("APTEEKKI_S hoitajan raot: ei pintaa, ei tarkistettu")
		return
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var flo := INF
	for p in feet:
		flo = minf(flo, p.y)
	var back_wall := -Makasiini.GAP + 0.022  # komeron takaseinän sisäpinta
	var leaf := 0.03 - 0.025  # ovilehden sisäpinta (saranasolmu z 0.03, lehti 0.05)
	var stool := door.get_node_or_null("Jakkara") as MeshInstance3D
	var floor_y := 0.016
	if stool != null:
		floor_y = stool.position.y + (stool.mesh as BoxMesh).size.y / 2.0
	var eye := nurse.to_global(nurse.bone_position("Head"))
	var eye_d := door.to_local(eye).y + 0.075
	print("APTEEKKI_S hoitajan raot: selkä %.3f m, nenä %.3f m, sivut %.3f / %.3f m, jalkapohja lattiaan %.3f m, pää+0.075 %.3f vs luukku %.3f" % [
		lo.z - back_wall, leaf - hi.z, lo.x + 0.58, 0.58 - hi.x, flo - floor_y, eye_d, Makasiini.HATCH_Y])
	if lo.z - back_wall < 0.01 or leaf - hi.z < 0.01 or lo.x + 0.58 < 0.01 or 0.58 - hi.x < 0.01:
		_vika("hoitaja koskee komeron seinään tai oveen")
	if flo - floor_y < -0.01 or flo - floor_y > 0.03:
		_vika("hoitajan jalat eivät ole lattialla (%.3f m)" % (flo - floor_y))


func _shot(nm: String, from: Vector3, to: Vector3) -> void:
	cam.look_at_from_position(from, to)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("kuva_%s.png" % nm))
	print("kuva %s (%.1f ms)" % [nm, 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)])
