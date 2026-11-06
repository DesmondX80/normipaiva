extends Node3D
## Kaikki henkilöautomallit rivissä (vehicles.gd saab, saab poliisi, lada, civic ja Päivin pony): kuva vinosti
## edestä, sivulta ja takaa. Ajo: tools/testit/aja.sh tscn tools/testit/autot_kuvat.tscn

const Vehicles := preload("res://scripts/vehicles.gd")
const B := preload("res://scripts/build.gd")

var out := "user://autot"
var cam: Camera3D


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
	sun.rotation_degrees = Vector3(-50, 150, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(40, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.4, 0.41, 0.43))  # asfaltti
	# Rivissä 2,4 m välein, keulat -Z:hen.
	var row := [
		func(n: Node3D): Vehicles.saab(n, Color(0.15, 0.25, 0.5), "SAA-900"),
		func(n: Node3D): Vehicles.saab(n, Color.WHITE, "SJX-141", true),
		func(n: Node3D): Vehicles.lada(n, Color(0.82, 0.78, 0.66), "LLJ-606"),
		func(n: Node3D): Vehicles.civic(n, Color(0.72, 0.04, 0.07), "VTC-916"),
		func(n: Node3D): Vehicles.pony(n, Color(0.78, 0.05, 0.05), "PÄI-V1"),
	]
	for k in row.size():
		var n := Node3D.new()
		n.position = Vector3((k - (row.size() - 1) / 2.0) * 2.4, 0, 0)
		add_child(n)
		row[k].call(n)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_run.call_deferred()


func _shot(name: String, from: Vector3, to: Vector3, fov := 40.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, to)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("AUTOT_KUVAT kuva " + out + "/" + name + ".png")


func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	await _shot("vino_edesta", Vector3(-7.5, 3.2, -9.5), Vector3(0, 0.6, 0), 42.0)
	await _shot("edesta", Vector3(0, 1.6, -14.0), Vector3(0, 0.7, 0), 45.0)
	await _shot("vino_takaa", Vector3(7.5, 3.2, 9.5), Vector3(0, 0.6, 0), 42.0)
	get_tree().quit()
