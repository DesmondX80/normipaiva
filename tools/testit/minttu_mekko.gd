extends Node3D
## Mintun mekko (looks.gd add_gown) kuvina: edestä, sivulta, takaa, kävellen ja istuen. Kuva args[0]/kuva_mekko.png.
## tools/testit/aja.sh tscn tools/testit/minttu_mekko.tscn
const Kuva := preload("res://tools/testit/kuva.gd")
const Looks := preload("res://scripts/looks.gd")
var out := "user://minttu_mekko"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.8, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	# [paikka x, kääntö, animaatio, aika]
	var poses := [[-2.4, PI, "Idle", 0.0], [-1.2, PI / 2.0, "Idle", 0.0], [0.0, 0.0, "Idle", 0.0],
		[1.2, PI * 0.75, "Walk", 0.35], [2.4, PI / 2.0, "Sitting_Idle", 0.0]]
	for p: Array in poses:
		var c := Looks.make(self, Looks.MINTTU)
		c.position = Vector3(p[0], 0.0 if p[2] != "Sitting_Idle" else 0.08, 0)
		c.rotation.y = p[1]
		c.play(p[2], 0.0)
		c.anim.seek(p[3], true)
		c.anim.pause()
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 38
	cam.look_at_from_position(Vector3(0, 1.0, 6.2), Vector3(0, 0.85, 0))
	cam.current = true
	for i in 20:
		await get_tree().process_frame
	await Kuva.piirto()
	Kuva.ruutu(get_viewport()).save_png(out.path_join("kuva_mekko.png"))
	print("MEKKO kuva valmis")
	# Joka puolelta: yksi Minttu keskellä, kamera kiertää kahdeksaan suuntaan (koko vartalo ja lähikuva lantiosta).
	for n in get_children():
		if n is Node3D and n != cam and not n is Light3D:
			n.queue_free()
	await get_tree().process_frame
	var m := Looks.make(self, Looks.MINTTU)
	m.rotation.y = PI  # kasvot +Z
	m.play("Idle", 0.0)
	m.anim.seek(0.0, true)
	m.anim.pause()
	cam.fov = 30
	for k in 8:
		var a := TAU * k / 8.0
		for close in [false, true]:
			var dist := 4.0 if not close else 1.7
			var look_y := 0.9 if not close else 0.85
			cam.look_at_from_position(Vector3(sin(a) * dist, look_y + 0.15, cos(a) * dist), Vector3(0, look_y, 0))
			for i in 3:
				await get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(get_viewport()).save_png(out.path_join("kuva_ymp_%d%s.png" % [k, "_lahi" if close else ""]))
	print("MEKKO ympäri valmis")
	get_tree().quit()
