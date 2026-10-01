extends SceneTree
## Kuvat mökiltä tarkan mallinnuksen (laserpuut, rakennusten korkeudet) tarkistukseen:
## godot --path . -s tools/testit/tarkka_kuvat.gd -- <kansio>
## Vaalan mopomatkan kuvat: godot --path . -- --shot=<kansio>/v.png --scene=mokkivaala

var main: Node3D
var out := "user://tarkka"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	load("res://scripts/main.gd").skip_menu = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	root.size = Vector2i(1600, 900)
	_run.call_deferred()


func _run() -> void:
	for i in 10:
		await process_frame
	var cam := Camera3D.new()
	cam.far = 4000.0
	cam.fov = 65.0
	main.add_child(cam)
	if true:
		var m: Node3D = main.mokki
		m.ensure_built()
		# [nimi, paikka (paikallinen, korkeus maasta), katsepiste]
		for s in [["mokki_piha", Vector3(-6, 1.7, -12), Vector3(5, 1.5, 30)],
				["mokki_laiturilta", Vector3(8.9, 1.6, 54), Vector3(0, 2, 0)],
				["mokki_metsa", Vector3(-60, 1.7, -40), Vector3(-90, 3, -80)],
				["mokki_ilmasta", Vector3(-150, 140, 250), Vector3(0, 0, 0)],
				["mokki_tie", Vector3(-30, 1.7, -60), Vector3(-60, 1.5, -200)]]:
			var a: Vector3 = s[1]
			var b: Vector3 = s[2]
			await _shot(cam, m.gpos(a), m.gpos(b), s[0])
	quit()


func _shot(cam: Camera3D, from: Vector3, to: Vector3, name: String) -> void:
	cam.look_at_from_position(from, to)
	cam.current = true
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("kuva %s (%d FPS)" % [name, Engine.get_frames_per_second()])
