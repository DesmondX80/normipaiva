extends Node3D
## Elastisuuden kokeilu: Sinikka (bikinit) rantatuolilla (RENTO). Istuin ja selkänoja annetaan hahmolle kontaktilaatikoina
## (ch.set_contacts), ja painumat mitataan ruumiinosittain paistetusta verkosta (Elastic.displace, varjostimen peili).
## Kuvat ennen/jälkeen sivusta, edestä, takaa ja lähikuvat. Luiset osat (polvi, kyynärpää, sääri) 0 painumaa.
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 tools/testit/elastic_a.tscn -- <kansio>

const Pose := preload("res://scripts/pose.gd")
const Seat := preload("res://scripts/seat.gd")
const Elastic := preload("res://scripts/elastic.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

var out := "user://elastic_a"
var cam: Camera3D
var root: Node3D
var ch: Node3D
const TILT := 0.5


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.88)
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(30, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.36, 0.5, 0.28))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 35.0
	_run.call_deferred()


func _boxes() -> Array:
	var seat := Transform3D(root.global_transform.basis, root.to_global(Vector3(0, 0.42, -0.05)))
	var lean := Vector3(0, cos(TILT), sin(TILT))
	var n := Vector3(0, sin(TILT), -cos(TILT))
	var xb := root.global_transform.basis.x
	var yb: Vector3 = root.global_transform.basis * n
	var back := Transform3D(Basis(xb, yb, xb.cross(yb)), root.to_global(Vector3(0, 0.42, 0.2) + lean * 0.35))
	return [[seat, Vector3(0.25, 0.02, 0.225)], [back, Vector3(0.25, 0.02, 0.35)]]


func _run() -> void:
	root = Node3D.new()
	add_child(root)
	var cc := Color(0.2, 0.5, 0.9)
	B.mesh(root, B.boxm(Vector3(0.9, 0.02, 1.8)), Vector3(0, 0.07, 0), Color(0.9, 0.2, 0.2))
	B.mesh(root, B.boxm(Vector3(0.5, 0.04, 0.45)), Vector3(0, 0.42, -0.05), cc)
	var lean := Vector3(0, cos(TILT), sin(TILT))
	var pivot := Vector3(0, 0.42, 0.2)
	B.mesh(root, B.boxm(Vector3(0.5, 0.7, 0.04)), pivot + lean * 0.35, cc).rotation.x = TILT
	var nn := Vector3(0, sin(TILT), -cos(TILT))
	Seat.spot(root, {"seat": Vector3(0, 0.44, -0.04), "front": Vector3(0, 0, -1),
		"back": {"p": pivot + lean * 0.35 + nn * 0.02, "n": nn}})
	ch = Looks.make(root, Looks.sinikka_bikini())
	ch.play("Sitting_Idle", 0.0)
	for i in 4:
		await get_tree().process_frame
	Pose.sit(ch, root, Pose.RENTO, {"ristissa": true})
	for i in 30:
		await get_tree().process_frame
	await _shots("ennen")
	ch.set_contacts(_boxes())
	for i in 3:
		await get_tree().process_frame
	_measure()
	await _shots("jalkeen")
	# Kakkonen: pystylevy edessä (pöydän reuna), jonka pinta on 15 mm rinnan etureunan taakse: rinta, vatsa ja kädet painuvat.
	ch.clear_contacts()
	var zf := INF
	var mi: MeshInstance3D = ch.body_mi
	for q in mi.bake_mesh_from_current_skeleton_pose().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var w: Vector3 = mi.global_transform * q
		if w.y > 1.0 and w.y < 1.5:
			zf = minf(zf, w.z)
	var plate := Transform3D(Basis(Vector3.RIGHT, Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, 1.1, zf + 0.015 - 0.01))
	B.mesh(self, B.boxm(Vector3(1.0, 1.2, 0.02)), Vector3(0, 1.1, zf + 0.015 - 0.01), Color(0.6, 0.4, 0.25))
	print("POYTA pinta z ", snappedf(zf + 0.015, 0.001), " (rinnan etureuna ", snappedf(zf, 0.001), ")")
	ch.set_contacts([[plate, Vector3(0.5, 0.01, 0.6)]])
	for i in 3:
		await get_tree().process_frame
	_measure()
	await _shots("poyta")
	ch.clear_ik()
	print("PAINUMA nousun jalkeen: laatikoita ", ch.press_boxes.size(), " press_n ", ch.body_mat.get_shader_parameter("press_n"))
	print("ELASTIC_A valmis ", ProjectSettings.globalize_path(out))
	get_tree().quit()


func _shots(tag: String) -> void:
	var c: Vector3 = root.to_global(Vector3(0, 0.75, 0))
	var views := [["sivu", Vector3(2.6, 0.9, 0.0), c], ["edesta", Vector3(0.0, 1.0, -2.6), c],
		["takaa", Vector3(0.0, 1.0, 2.6), c],
		["pakara", Vector3(1.0, 0.65, 0.4), root.to_global(Vector3(0, 0.5, 0.0))],
		["rinta", Vector3(0.6, 1.5, -0.9), root.to_global(Vector3(0, 1.0, 0.0))],
		["polvi", Vector3(0.5, 0.5, -1.2), root.to_global(Vector3(0, 0.45, -0.45))]]
	for v in views:
		cam.look_at_from_position(v[1], v[2])
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		cam.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [tag, v[0]]))


func _measure() -> void:
	var mi: MeshInstance3D = ch.body_mi
	var baked := mi.bake_mesh_from_current_skeleton_pose()
	var src: Array = mi.mesh.surface_get_arrays(0)
	var arr: Array = baked.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var bi: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var bw: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var c0: PackedFloat32Array = src[Mesh.ARRAY_CUSTOM0]
	var per := bi.size() / vs.size()
	var sk: Skin = mi.skin
	var groups := {}
	for v in vs.size():
		var best := 0
		for k in per:
			if bw[v * per + k] > bw[v * per + best]:
				best = k
		var nm := str(sk.get_bind_name(bi[v * per + best]))
		var side := "taka" if ns[v].z < -0.3 else ("etu" if ns[v].z > 0.3 else "sivu")
		var key := nm + " " + side
		var lim := c0[v * 4 + 3]
		var raw := Elastic.depth(vs[v], lim, ch.press_boxes)
		var disp := Elastic.press(vs[v], ns[v], lim, ch.press_boxes).distance_to(vs[v])
		var g: Array = groups.get(key, [0, 0.0, 0.0, 0.0, 0.0])
		if raw > 0.0:
			g[0] += 1
		g[1] = maxf(g[1], raw)
		g[2] = maxf(g[2], disp)
		g[3] = maxf(g[3], lim)
		if raw > lim:
			g[4] = maxf(g[4], raw - lim)  # jäännöstunkeuma painuman jälkeen (K13)
		groups[key] = g
	var keys := groups.keys()
	keys.sort()
	for k in keys:
		var g: Array = groups[k]
		if g[0] > 0 or str(k).begins_with("calf") or str(k).begins_with("lowerarm") or str(k).begins_with("upperarm") or str(k).begins_with("spine"):
			print("PAINUMA %-18s kosketus-verteksejä %4d  tunkeuma max %.1f mm  painuma max %.1f mm  raja %.1f mm  yli rajan %.1f mm" % [
				k, g[0], g[1] * 1000, g[2] * 1000, g[3] * 1000, g[4] * 1000])
