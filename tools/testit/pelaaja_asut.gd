extends Node3D
## Pelaajan asut rinnakkain (looks.gd OUTFITS): kuva args[0]/kuva_asut.png, ja samat asut eri päähineillä
## (oma, Stetson, Karhu-koppa): kuva_hatut.png.
## tools/testit/aja.sh tscn tools/testit/pelaaja_asut.tscn
const Kuva := preload("res://tools/testit/kuva.gd")
const Looks := preload("res://scripts/looks.gd")


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://asut"
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
	var ids: Array = Looks.OUTFITS.keys()
	for i in ids.size():
		var c := Looks.make(self, Looks.player(ids[i]))
		c.position = Vector3((i - (ids.size() - 1) / 2.0) * 1.0, 0, 0)
		c.rotation.y = PI
		c.play("Idle", 0.0)
		print("ASU %s" % ids[i])
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.look_at_from_position(Vector3(0, 1.1, 6.5), Vector3(0, 0.95, 0))
	cam.current = true
	for i in 20:
		await get_tree().process_frame
	await Kuva.piirto()
	Kuva.ruutu(get_viewport()).save_png(out.path_join("kuva_asut.png"))
	# Päähineet: asut rinnakkain, kullakin eri päähine (oma, Stetson, Karhu-koppa vuorotellen).
	for n in get_children():
		if n.has_meta("player_body"):
			n.free()
	var hats := ["", "stetson", "koppa"]
	var hats_for := {"tuulipuku": "", "farkut": "stetson", "hiihtohaalari": "koppa", "nahkaliivi": "stetson"}
	for i in ids.size():
		Looks.hat = hats_for.get(ids[i], hats[i % hats.size()])
		var c := Looks.make(self, Looks.player(ids[i]))
		Looks.add_cap(c)  # peli lisää päähineen erikseen (Looks.hat valitsee oman, Stetsonin tai kopan)
		c.position = Vector3((i - (ids.size() - 1) / 2.0) * 0.9, 0, 0)
		c.rotation.y = PI
		c.play("Idle", 0.0)
	Looks.hat = ""
	cam.fov = 30
	cam.look_at_from_position(Vector3(0, 1.3, 5.2), Vector3(0, 1.0, 0))
	for i in 20:
		await get_tree().process_frame
	await Kuva.piirto()
	Kuva.ruutu(get_viewport()).save_png(out.path_join("kuva_hatut.png"))
	get_tree().quit()
