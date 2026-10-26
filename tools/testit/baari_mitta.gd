extends Node3D
## Baarin kädenväännön mittaus ja kuvat: godot --path . --resolution 1280x720 tools/testit/baari_mitta.tscn -- <kansio>
## Kolme vääntökulmaa x kaksi hahmoa: vatsan rako pöydän reunaan, reisien rako pöydän alapintaan, polvien väli,
## kyynärpään korkeus, pään sijainti ja läpimenotarkistus (Asento.solids).
const BarGame := preload("res://scripts/bar_game.gd")
const Pose := preload("res://scripts/pose.gd")
const Asento := preload("res://tools/testit/asento.gd")
var out := "user://baari"
var cam: Camera3D
var g: Node3D

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	cam = Camera3D.new()
	add_child(cam)
	g = BarGame.new()
	add_child(g)
	cam.current = true
	_run.call_deferred()

func _p(ch: Node3D, b: String) -> Vector3:
	return g.to_local(ch.to_global(ch.bone_position(b)))

func _run() -> void:
	for i in 24:
		await get_tree().process_frame
	g._layer.visible = false
	g._cam.queue_free()
	await get_tree().process_frame
	cam.current = true
	g._bubble.visible = false
	var top: float = g.TABLE_Y + 0.03
	var edge: float = g.EDGE
	for ang in [-1.0, 0.0, 1.0]:
		g._angle = ang
		for i in 15:
			await get_tree().process_frame
		var tag := "a%d" % int(ang + 1)
		var knees := {}
		for ch in [g._me, g._tero]:
			var sgn := 1.0 if ch == g._me else -1.0
			var nm := "pelaaja" if ch == g._me else "tero"
			var pts := Pose.limb_points(ch, g, ["pelvis", "spine_01", "spine_02", "spine_03"])
			var front := INF
			for q in pts:
				if q.y > top - 0.07 and q.y < top + 0.01 and absf(q.x) < 0.5:
					front = minf(front, q.z * sgn)
			var th := Pose.limb_points(ch, g, ["thigh_l", "thigh_r"])
			var tmax := -INF
			for q in th:
				if q.z * sgn < edge and absf(q.x) < 0.5:
					tmax = maxf(tmax, q.y)
			var kn := Pose.limb_points(ch, g, ["calf_l", "calf_r", "thigh_l", "thigh_r"])
			var kp := PackedVector3Array()
			for q in kn:
				if q.z * sgn < 0.30 and q.y > 0.2:
					kp.append(q)
			knees[nm] = kp
			var el := _p(ch, "lowerarm_r")
			var sh := _p(ch, "upperarm_r")
			var hd := _p(ch, "Head")
			var hand := _p(ch, "hand_r")
			print(tag, " ", nm, " RAKO_vatsa ", snappedf(front - edge, 0.001), " reisi_rako_alapintaan ", snappedf((top - 0.06) - tmax, 0.001),
				" kyynarpaa_y_pinnasta ", snappedf(el.y - top, 0.001), " (tavoite ", g.ELBOW_R, ") kyynarpaa_reunasta ", snappedf(edge - el.z * sgn, 0.001),
				" olka_z_reunasta ", snappedf(sh.z * sgn - edge, 0.001), " paa_z ", snappedf(hd.z * sgn, 0.001), " ote ", hand,
				" lam ", snappedf(ch.get_meta("lam"), 0.001), " lantio_y ", snappedf(_p(ch, "pelvis").y, 0.001))
			print(tag, " ", nm, " solids ", Asento.solids(ch, g))
		var best := INF
		for a in knees["pelaaja"]:
			for b in knees["tero"]:
				best = minf(best, a.distance_to(b))
		print(tag, " polvien_valinen_pinta ", snappedf(best, 0.001))
		var c := Vector3(0, g.TABLE_Y + 0.3, 0)
		await _shot("sivu" + tag, c + Vector3(2.0, 0.1, 0), c)
		await _shot("edesta" + tag, c + Vector3(0.3, 0.3, 2.0), c)
		await _shot("ylhaalta" + tag, c + Vector3(0, 1.7, 0.01), c)
		await _shot("sivu_lahi" + tag, c + Vector3(1.2, 0.0, 0), c - Vector3(0, 0.1, 0))
	get_tree().quit()

func _shot(name: String, from: Vector3, to: Vector3) -> void:
	cam.fov = 55.0
	cam.look_at_from_position(g.to_global(from), g.to_global(to))
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
