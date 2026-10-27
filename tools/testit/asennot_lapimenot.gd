extends Node
## Läpimenotesti (K13, K16): jokaiselle Seat.registry-paikalle istuvat hahmot tarkistetaan Asento.solids-testillä,
## jalkapohja tukea vasten (alin piste >= -0,005 m) ja pehmeän painuman jäännös (tunkeuma yli painumarajan, K13).
## Kuvat ennen (painumat pois) ja jälkeen koottuina. Ajo: --scene=asennot --asento=lapimenot --nohud
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 -- --scene=asennot --asento=lapimenot --nohud

const Pose := preload("res://scripts/pose.gd")
const Seat := preload("res://scripts/seat.gd")
const Contact := preload("res://scripts/contact.gd")
const Elastic := preload("res://scripts/elastic.gd")
const Asento := preload("res://tools/testit/asento.gd")

const SOLE_MIN := -0.005  # jalkapohjan alin piste tukeen nähden
const RESIDUAL_MAX := 0.001  # sallittu tunkeuma painumarajan yli (m)

var main: Node3D
var node_dbg: Node3D


func run() -> void:
	var out := "user://lapimenot"
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.current = true
	cam.fov = 40.0
	for i in 10:
		await main.get_tree().process_frame
	var spots: Array = Seat.registry.filter(func(n: Variant) -> bool: return is_instance_valid(n) and n.is_inside_tree())
	print("LAPIMENOT istumapaikkoja ", spots.size())
	var bad := 0
	var seated := 0
	for k in spots.size():
		var node: Node3D = spots[k]
		var d := Seat.of(node)
		var seat_w: Vector3 = node.to_global(d.seat)
		var front: Vector3 = node.global_transform.basis * (d.front as Vector3)
		main.player.global_position = seat_w + Vector3(0, 1, 0) + front.normalized() * 6.0
		for i in 20:
			await main.get_tree().process_frame
		var list := []
		Asento._chars(main.get_tree().current_scene, list)
		for ch: Node3D in list:
			if not ch.is_visible_in_tree() or Vector2(ch.global_position.x - seat_w.x, ch.global_position.z - seat_w.z).length() > 0.9 \
					or absf(ch.global_position.y - seat_w.y) > 1.2:
				continue
			seated += 1
			var tag := "%s_%d" % [node.name, k]
			bad += _check(node, ch, tag)
			await _compare(cam, out, tag, node, ch, seat_w, front)
	print("LAPIMENOT yhteensä: %d istujaa, %d vikaa%s" % [seated, bad, "" if seated > 0 else " (EI YHTÄÄN ISTUJAA: testi ei tarkistanut mitään)"])
	print("LAPIMENOT kuvat: ", ProjectSettings.globalize_path(out))


func _check(node: Node3D, ch: Node3D, tag: String) -> int:
	var bad := Asento.solids(ch, main.world)
	var solids := Contact.world_solids(node)
	for lr: String in ["_l", "_r"]:
		var low := INF
		for q in Pose.limb_points(ch, main.world, ["foot" + lr, "ball" + lr]):
			var g: Vector3 = main.world.to_global(q)
			var sup := Contact.support_y(solids, g.x, g.z, g.y + 0.3)
			sup = maxf(sup, Contact.ground_y(node, g.x, g.z, g.y + 0.3))
			if sup > -INF:
				low = minf(low, g.y - sup)
		if low < SOLE_MIN:
			bad += 1
		print("LAPIMENOT %s jalkapohja%s alin %.4f m %s" % [tag, lr, low, "VIRHE" if low < SOLE_MIN else "OK"])
	node_dbg = node
	var worst := _residual(ch)
	if worst > RESIDUAL_MAX:
		bad += 1
		print("KONTAKTI JÄÄ %s: tunkeuma yli painumarajan %.1f mm" % [tag, worst * 1000])
	print("LAPIMENOT %s: painuvia laatikoita %d, jäännös %.1f mm" % [tag, ch.press_boxes.size(), worst * 1000])
	return bad


## Suurin tunkeuma painumarajan yli (K13): paistetusta verkosta, Elastic.depth vs CUSTOM0.w.
func _residual(ch: Node3D) -> float:
	var mi: MeshInstance3D = ch.body_mi
	if mi == null or ch.press_boxes.is_empty() or DisplayServer.get_name() == "headless":
		return 0.0
	var vs: PackedVector3Array = mi.bake_mesh_from_current_skeleton_pose().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var c0: PackedFloat32Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]
	var wv := -1
	var worst := 0.0
	for v in vs.size():
		var ov := _raw_pen(vs[v], ch.press_boxes) - c0[v * 4 + 3]
		if ov > worst:
			worst = ov
			wv = v
	if wv >= 0:
		var bi: PackedInt32Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES]
		print("JAANNOS pahin verteksi ", wv, " luu ", mi.skin.get_bind_name(bi[wv * (bi.size() / vs.size())]), " lim ", c0[wv * 4 + 3], " paikka ", vs[wv])
		var arr0: Array = mi.mesh.surface_get_arrays(0)
		var st: int = bi.size() / vs.size()
		var bw: PackedFloat32Array = arr0[Mesh.ARRAY_WEIGHTS]
		var info := ""
		for k in st:
			info += "%s=%.2f " % [mi.skin.get_bind_name(bi[wv * st + k]), bw[wv * st + k]]
		print("JAANNOS painot ", info, " lepo ", (arr0[Mesh.ARRAY_VERTEX] as PackedVector3Array)[wv], " normaali ", (arr0[Mesh.ARRAY_NORMAL] as PackedVector3Array)[wv])
		var pl: Vector3 = ch.to_local(mi.to_global(vs[wv]))  # hahmon avaruus (verkon avaruus on käännetty)
		for nm in ["thigh_r", "calf_r", "thigh_l", "calf_l", "pelvis"]:
			var dmin := INF
			for q in Pose.limb_points(ch, ch, [nm]):
				dmin = minf(dmin, q.distance_to(pl))
			print("JAANNOS luu ", nm, " ", ch.bone_position(nm), " etaisyys vertekseen ", dmin)
		var wp: Vector3 = mi.to_global(vs[wv])
		print("JAANNOS vertex maailma ", wp, " tuki ", Contact.support_y(Contact.world_solids(node_dbg), wp.x, wp.z, wp.y + 0.1))
		for b in ch.press_boxes:
			var bq: Vector3 = (b[0] as Transform3D) * vs[wv]
			print("JAANNOS laatikko q ", bq, " h ", b[1], " etaisyys reunaan x %.3f z %.3f" % [(b[1] as Vector3).x - absf(bq.x), (b[1] as Vector3).z - absf(bq.z)])
	return worst


func _compare(cam: Camera3D, out: String, tag: String, node: Node3D, ch: Node3D, seat_w: Vector3, front: Vector3) -> void:
	var c := seat_w + Vector3(0, 0.45, 0)
	await Asento.views(cam, out, tag + "_jalkeen", c, 1.9, front, false)
	await Asento.views(cam, out, tag + "_lahi", ch.to_global(ch.bone_position("calf_r")) + front * 0.1, 0.8, front, false)
	var saved: Array = ch.press_boxes.duplicate(true)
	ch.clear_contacts()
	for i in 3:
		await main.get_tree().process_frame
	await Asento.views(cam, out, tag + "_ennen", c, 1.9, front, false)
	ch.press_boxes = saved
	ch._upload_contacts()


## Syvin tunkeuma laatikoiden jalanjäljessä ilman deep_fadea (rehellinen mittari: reunaa vasten oleva syvä verteksi ei häviä).
func _raw_pen(p: Vector3, boxes: Array) -> float:
	var best := 0.0
	for b in boxes:
		var q: Vector3 = (b[0] as Transform3D) * p
		var h: Vector3 = b[1]
		if absf(q.x) < h.x and absf(q.z) < h.z and q.y >= -h.y:
			best = maxf(best, h.y - q.y)
	return best
