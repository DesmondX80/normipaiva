extends Node3D
## Valeostaja (scripts/rikos/valeostaja.gd) lähikuvina: aito ostaja, siviilipoliisi ja vertailuksi Vaalan mopopoika
## (vaala.gd _build_race_crew) rinnakkain edestä, sivulta ja ylhäältä sekä korvanappi ja kengät suurennettuina.
## Ajo: tools/testit/aja.sh tscn tools/testit/valeostaja_kuvat.tscn

const Valeostaja := preload("res://scripts/rikos/valeostaja.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const MOPOPOIKA := {"shirt": Color(0.1, 0.35, 0.6), "pants": Color(0.25, 0.32, 0.5), "shoes": Color(0.9, 0.9, 0.9), "hair": "Hair_Buzzed",
	"hair_color": Color(0.7, 0.55, 0.3), "height": 1.76, "bulk": -0.6, "shoulders": -0.5, "tracksuit": {"a": Color(0.9, 0.2, 0.3), "b": Color(0.1, 0.35, 0.6)}}

var out := "user://valeostaja"
var cam: Camera3D
var vale: Node3D


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
	B.mesh(self, B.boxm(Vector3(14, 0.1, 10)), Vector3(0, -0.05, 0), Color(0.4, 0.41, 0.43))  # torin asfaltti
	var aito := Valeostaja.build_model(self, false)
	aito.position = Vector3(-1.4, 0, 0)
	vale = Valeostaja.build_model(self, true)
	var poika := Looks.make(self, MOPOPOIKA)
	poika.position = Vector3(1.4, 0, 0)
	for c in [aito, vale, poika]:
		c.play("Idle", 0.0)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40.0
	_run.call_deferred()


func _shot(name: String, from: Vector3, to: Vector3) -> void:
	cam.look_at_from_position(from, to)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("VALEOSTAJA_KUVAT kuva " + out + "/" + name + ".png")


func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	await _shot("edesta", Vector3(0, 1.2, -6.5), Vector3(0, 0.95, 0))  # kasvot -Z
	await _shot("sivulta", Vector3(6.5, 1.2, -0.5), Vector3(0, 0.95, 0))
	await _shot("ylhaalta", Vector3(0, 7.0, -0.3), Vector3(0, 0, 0))
	var head := Vector3(0, 1.72, 0)
	await _shot("korvanappi", head + Vector3(0.45, 0.05, 0.12), head + Vector3(0, -0.04, 0))
	await _shot("korvanappi_takaa", head + Vector3(0.25, 0.0, 0.4), head + Vector3(0.04, -0.06, 0))
	await _shot("kengat", Vector3(0, 0.5, -2.2), Vector3(0, 0.1, 0))
	var ep := vale.find_child("Korvanappi", true, false)
	print("VALEOSTAJA_KUVAT korvanappi ", ep != null)
	if ep == null:
		print("TESTI VIKA korvanappi puuttuu")
	get_tree().quit()
