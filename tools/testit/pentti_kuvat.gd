extends Node3D
## Pentti (#299, Looks.PENTTI): avonainen nahkaliivi paljaan karvaisen rinnan päällä, viikset, pilottilasit ja ketju.
## Kuvat edestä, viistosti, sivulta ja takaa sekä rinnan ja liivin reunan lähikuvat; vertailukuva _vertailu.png.
## Ajo: tools/testit/aja.sh tscn tools/testit/pentti_kuvat.tscn

const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

var out := "user://pentti"
var cam: Camera3D
var shots: Array[String] = []


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
	env.environment.ambient_light_energy = 0.8
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 160, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(10, 0.1, 10)), Vector3(0, -0.05, 0), Color(0.4, 0.41, 0.43))
	var p := Looks.make(self, Looks.PENTTI)
	p.rotation.y = PI  # kasvot +Z:aan (hahmon etu -Z)
	p.play("Idle", 0.0)
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
	shots.append(name)
	print("PENTTI_KUVAT kuva " + out + "/" + name + ".png")


func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	await _shot("edesta", Vector3(0, 1.1, 3.4), Vector3(0, 1.0, 0))
	await _shot("vino", Vector3(2.2, 1.3, 2.6), Vector3(0, 1.05, 0))
	await _shot("sivu", Vector3(3.4, 1.1, 0), Vector3(0, 1.0, 0))
	await _shot("takaa", Vector3(0, 1.2, -3.4), Vector3(0, 1.0, 0))
	await _shot("rinta", Vector3(0, 1.3, 1.1), Vector3(0, 1.22, 0), 35.0)
	await _shot("rinta_vino", Vector3(0.7, 1.35, 0.9), Vector3(0, 1.25, 0), 30.0)
	await _shot("reuna", Vector3(-0.35, 1.2, 0.6), Vector3(-0.06, 1.15, 0.1), 30.0)  # liivin reuna ja napit
	await _shot("kasvot", Vector3(0, 1.66, 0.6), Vector3(0, 1.62, 0), 30.0)
	get_tree().quit()
