extends Node3D
## K-Marketin penkin mummot erikseen tasaisella maalla: istuma-asennot (edestä, sivulta, lähikuvat) ja
## rollaattorimummon kepinhuitaisu, kun "pelaaja" kävelee liian lähelle.
## godot --path . --resolution 1280x720 tools/testit/mummo_kuvat.tscn -- <kansio>

const Mummot := preload("res://scripts/mummot.gd")
const B := preload("res://scripts/build.gd")

var out := "user://mummot"
var cam: Camera3D
var m: Node3D
var dummy: Node3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var world := self
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.88)
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	B.mesh(world, B.boxm(Vector3(30, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.32, 0.32, 0.34))
	B.mesh(world, B.boxm(Vector3(12, 4, 0.2)), Vector3(0, 2, -1.2), Color(0.85, 0.85, 0.82))
	m = Mummot.new()
	world.add_child(m)
	dummy = Node3D.new()
	dummy.position = Vector3(8, 0, 6)
	world.add_child(dummy)
	B.mesh(dummy, B.cyl(0.2, 0.2, 1.6, 12), Vector3(0, 0.8, 0), Color(0.2, 0.5, 0.2))
	B.mesh(dummy, B.sphere(0.13), Vector3(0, 1.72, 0), Color(0.9, 0.7, 0.6))
	cam = Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	_run.call_deferred()


func _run() -> void:
	for i in 30:
		await get_tree().process_frame
	for g in m._grans:
		var c: Node3D = g
		print("MUMMO %s pelvis %s foot_l %s ball_r %s head %s" % [c.name, c.global_transform * c.bone_position("pelvis"),
			c.global_transform * c.bone_position("foot_l"), c.global_transform * c.bone_position("ball_r"),
			c.global_transform * c.bone_position("Head")])
	await _shot("edesta", Vector3(0.6, 1.3, 5.0), Vector3(0.6, 0.75, 0))
	await _shot("sivulta", Vector3(-4.5, 0.8, 0.3), Vector3(0, 0.6, 0.3))
	await _shot("sivu_oikea", Vector3(5.5, 0.9, 0.4), Vector3(1.5, 0.7, 0.4))
	await _shot("vino", Vector3(3.5, 1.8, 3.5), Vector3(0.5, 0.7, 0))
	for i in m._grans.size():
		var h: Vector3 = m._grans[i].global_position
		await _shot("lahi_%d" % i, h + Vector3(0.6, 1.15, 1.5), h + Vector3(0, 0.95, 0), 35.0)
		var hd: Vector3 = m._grans[i].global_transform * m._grans[i].bone_position("Head") + Vector3(0, 0.08, 0)
		var fw: Vector3 = -m._grans[i].global_basis.z
		await _shot("kasvot_%d" % i, hd + fw * 0.7 + Vector3(0.15, 0.05, 0), hd, 30.0)
		await _shot("lahi_sivu_%d" % i, h + Vector3(-1.8, 0.9, 0.5), h + Vector3(0, 0.7, 0.2), 35.0)
	# Pelaaja kävelee rollaattorimummon eteen ja jää siihen: huitaisu osuu päähän.
	m.target = dummy
	var killed := [0]
	var hits := [0]
	m.killed.connect(func() -> void: killed[0] += 1)
	m.hit.connect(func(_d: Vector3) -> void: hits[0] += 1)
	var s: Node3D = m._stand
	var sp: Vector3 = s.global_position
	dummy.position = sp + Vector3(0.4, 0, 3.5)
	cam.fov = 50.0
	cam.look_at_from_position(sp + Vector3(3.4, 1.5, 1.2), sp + Vector3(0, 1.1, 0.9))
	cam.current = true
	var shots := 0
	var marks := [0.15, 0.35, 0.55, 0.62, 0.68, 0.73, 0.78, 0.84, 0.95, 1.2, 1.5]
	var placed := false
	# Peliaika hitaammin: isku kestää 0,22 s, ja hitaalla (ohjelmisto)renderöinnillä yksi ruutu voisi hypätä sen yli.
	Engine.time_scale = 0.25
	for f in 2400:
		if killed[0] > 0 and shots >= marks.size():
			break
		dummy.position = dummy.position.move_toward(sp + Vector3(0.1, 0, 1.25), 0.03)
		if m._swing_t > 0.0 and not placed:
			placed = true  # kamera sivulle mummon ja tulijan välisestä linjasta
			var mid: Vector3 = (sp + dummy.position) / 2.0
			var side: Vector3 = (dummy.position - sp).cross(Vector3.UP).normalized()
			cam.fov = 45.0
			cam.look_at_from_position(mid + side * 3.6 + Vector3(0, 0.6, 0), mid + Vector3(0, 1.2, 0))
		await get_tree().process_frame
		if shots < marks.size() and m._swing_t >= marks[shots]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("huitaisu_%d.png" % shots))
			shots += 1
	print("HUITAISU jää paikalleen: kuoli=%d kylkeen=%d kuvia=%d" % [killed[0], hits[0], shots])
	Engine.time_scale = 1.0
	# Toinen kerta: pelaaja perääntyy heti, kun keppi nousee: pitää mennä ohi.
	killed[0] = 0
	hits[0] = 0
	dummy.position = sp + Vector3(0.4, 0, 4.0)
	for f in 60:
		await get_tree().process_frame
	m._swing_cd = 0.0
	var fled := false
	for f in 300:
		if m._swing_t > 0.0:
			fled = true
		var goal := sp + Vector3(0.1, 0, 4.0) if fled else sp + Vector3(0.1, 0, 1.25)
		dummy.position = dummy.position.move_toward(goal, 0.06)
		await get_tree().process_frame
	print("HUITAISU perääntyi: kuoli=%d kylkeen=%d" % [killed[0], hits[0]])
	get_tree().quit()


func _shot(name: String, from: Vector3, to: Vector3, fov := 50.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, to)
	cam.current = true
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
