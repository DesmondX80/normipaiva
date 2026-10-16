extends Node3D
## Konttaava hahmo (crawler3d.gd) sivulta, edestä ja ylhäältä askeleen eri vaiheissa.
## godot --path . --resolution 1280x720 tools/testit/konttaus_kuvat.tscn -- <kansio>

const Crawler := preload("res://scripts/crawler3d.gd")
const B := preload("res://scripts/build.gd")

var out := "user://konttaus"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.6, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.box(self, Vector3(10, 0.2, 10), Vector3(0, -0.1, 0), Color(0.45, 0.35, 0.25), false)
	var c := Crawler.new()
	add_child(c)
	c.setup({"shirt": Color(0.95, 0.75, 0.62), "pants": Color(0.25, 0.45, 0.25), "skin": Color(0.95, 0.75, 0.62),
		"hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.2, 0.12), "beard": true, "belly": 0.6, "bulk": 0.3})
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	_run.call_deferred(c, cam)


func _run(c: Node3D, cam: Camera3D) -> void:
	var views := [["sivu", Vector3(2.6, 0.7, 0), Vector3(0, 0.4, 0)], ["edesta", Vector3(0.6, 0.9, -2.4), Vector3(0, 0.4, -0.2)],
		["ylha", Vector3(0.01, 4.0, 0), Vector3(0, 0, 0)], ["takaa", Vector3(-1.2, 1.4, 2.2), Vector3(0, 0.4, 0)]]
	for ph in [0.0, PI / 2.0, PI]:
		for f in 4:
			c.pose(ph, 1.0)
			await get_tree().process_frame
		for v in views:
			cam.look_at_from_position(v[1], v[2])
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("%s_%d.png" % [v[0], int(ph * 10)]))
	get_tree().quit()
