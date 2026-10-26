extends Node3D
## Janttu penkillä (scripts/janttu.gd) erikseen: koottu kuva edestä, päädyistä, ylhäältä ja takaa unessa ja hereillä,
## lähikuvat vatsan päällä lepäävästä kädestä ja kassista, sekä käsien rako vartalon pintaan (RAKO-rivit).
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 tools/testit/janttu_kuvat.tscn -- <kansio>

const Janttu := preload("res://scripts/janttu.gd")
const Asento := preload("res://tools/testit/asento.gd")
const B := preload("res://scripts/build.gd")

var out := "user://janttu"
var cam: Camera3D
var j: Node3D


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
	sun.rotation_degrees = Vector3(-50, 200, 0)  # valo edestä (penkin etupuoli on -Z)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(30, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.36, 0.5, 0.28))
	j = Janttu.new()
	add_child(j)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40.0
	_run.call_deferred()


func _run() -> void:
	for i in 60:
		await get_tree().process_frame
	var centre := Vector3(0, 0.55, 0)
	await Asento.views(cam, out, "uni", centre, 2.1, Vector3(0, 0, -1))
	var torso := ["pelvis", "spine_01", "spine_02", "spine_03"]
	var bad := Asento.report(j.body, self, [["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"]], torso)
	var hand: Vector3 = j.body.global_transform * j.body.bone_position("hand_l")
	await _shot("kasi_lahi", hand + Vector3(0.1, 0.35, -0.6), hand)
	var head: Vector3 = j.body.global_transform * j.body.bone_position("Head")
	await _shot("kassi_lahi", head + Vector3(0.6, 0.35, -0.6), head + Vector3(0.05, -0.1, 0))
	j.wake("Mitä?", 3.0)
	for i in 50:
		await get_tree().process_frame
	await Asento.views(cam, out, "hereilla", centre, 2.1, Vector3(0, 0, -1))
	print("RAKO yhteensä läpimenoja: ", bad)
	get_tree().quit()


func _shot(name: String, from: Vector3, to: Vector3) -> void:
	cam.look_at_from_position(from, to)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("kuva ", name)
