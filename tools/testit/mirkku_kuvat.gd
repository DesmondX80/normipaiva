extends Node3D
## Mirkku (Looks.MIRKKU) erikseen: palmikko oikean olan yli, edestä, vinosti, sivulta ja takaa sekä lähikuvat;
## asennot Idle, Idle_Talking ja kukan poiminta (PickUp_Table).
## godot --path . --resolution 1280x720 tools/testit/mirkku_kuvat.tscn -- <kansio>

const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

var out := "user://mirkku"
var cam: Camera3D
var m: Node3D


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
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 200, 0)  # valo edestä (Mirkku katsoo −Z)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(30, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.36, 0.5, 0.28))
	m = Looks.make(self, Looks.MIRKKU)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_run.call_deferred()


func _run() -> void:
	for st in [["idle", "Idle"], ["puhuu", "Idle_Talking"], ["poimii", "PickUp_Table"]]:
		m.play(st[1], 0.0)
		for i in 40:
			await get_tree().process_frame
		var hd: Vector3 = m.global_transform * m.bone_position("Head")
		await _shot(st[0] + "_edesta", Vector3(0, 1.1, -3.2), Vector3(0, 0.9, 0), 40.0)
		await _shot(st[0] + "_lahi", hd + Vector3(0.25, -0.15, -1.3), hd + Vector3(0, -0.25, 0), 35.0)
		if st[0] == "idle":
			await _shot("idle_vino", Vector3(2.2, 1.4, -2.2), Vector3(0, 1.1, 0), 35.0)
			await _shot("idle_sivu", Vector3(2.8, 1.4, 0), Vector3(0, 1.2, 0), 30.0)
			await _shot("idle_takaa", Vector3(0.6, 1.5, 2.6), Vector3(0, 1.2, 0), 35.0)
			await _shot("idle_kasvot", hd + Vector3(0, 0.03, -0.75), hd, 30.0)
	get_tree().quit()


func _shot(name: String, from: Vector3, to: Vector3, fov := 50.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, to)
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("kuva ", name)
