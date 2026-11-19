extends Node
## Rasvanapin hahmojen anatomia FPS-kameralta: halli valot päällä, hahmot konttaamassa ja seisomassa, lähikuvat
## (kädet, jalat, selkä, hartiat, kasvot) kaikista viidestä pelaajasta ja pelaajasta itsestään.
## godot --path . --resolution 1280x720 tools/testit/rasvanappi_anat.tscn -- <kansio> [--anat=0|1]

const Game := preload("res://scripts/rasvanappi_game.gd")
const Hall := preload("res://scripts/rasvanappi_hall.gd")

var out := "user://rasvanappi_anat"
var hall: Node3D


func _ready() -> void:
	var anat := true
	var no_shadow := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--anat="):
			anat = a.ends_with("1")
		elif a == "--ei-varjoa":
			no_shadow = true  # selvitys: onko jyrkkä reuna hallin varjokartan (omni) varjo
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	var looks: Array = []
	for p: Dictionary in Game.PEOPLE:
		var real := Game.real_look(String(p.id))
		var lk := Game.towel_look(real)
		if not lk.has("skin"):
			lk["skin"] = p.look.skin
		if not anat:
			lk["anat"] = false
		looks.append({"towel": p.towel, "woman": String(lk.get("model", "male")) == "female", "look": lk})
	var me := Game.towel_look(Game.Looks.player())
	if not anat:
		me["anat"] = false
	looks.append({"towel": Color(0.95, 0.95, 0.92), "woman": false, "look": me})
	hall = Hall.new()
	hall.room = Game.ROOM
	hall.door_y = Game.DOOR_Y
	add_child(hall)
	hall.build(Game.OBST, looks, {}, null)
	hall.set_lit(1.0)
	if no_shadow:
		for l in hall.find_children("*", "OmniLight3D", true, false):
			(l as OmniLight3D).shadow_enabled = false
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("KUVA ", name)


## Kamera kohtaan eye katsomaan kohtaan at.
func _cam(eye: Vector3, at: Vector3, fov := 60.0) -> void:
	var c: Camera3D = hall.fps_cam
	c.fov = fov
	c.current = true
	c.transform = Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye)


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var n: int = hall.crawlers.size()
	# Konttaajat riviin eri paikkoihin, kaikki +X-suuntaan (ang 0).
	hall.crawl_start()
	for i in n:
		hall.place(i, Vector2(3.0, 0.9 + i * 1.0), 0.0, 0.0, false)
	await get_tree().process_frame
	for i in n - 1:
		var pz: float = 0.9 + i * 1.0
		var nm: String = Game.PEOPLE[i].id
		# FPS-etäisyys: takaa 0,7 m päästä silmäkorkeudelta (pelaajan oma näkymä), takaviisto, sivu, edestä.
		_cam(Vector3(2.2, 0.62, pz), Vector3(3.0, 0.45, pz), 72.0)
		await _shot("%s_fps_taka" % nm)
		_cam(Vector3(3.4, 0.9, pz + 1.2), Vector3(3.2, 0.5, pz), 50.0)
		await _shot("%s_sivu" % nm)
		_cam(Vector3(4.3, 0.7, pz + 0.3), Vector3(3.5, 0.5, pz), 55.0)
		await _shot("%s_etu" % nm)
	# Seisova esittely (pyyhe päällä): rivi ja lähikuva.
	hall.lineup()
	await get_tree().process_frame
	await get_tree().process_frame
	hall.line_cam.current = true
	await _shot("rivi")
	for i in n - 1:
		var x: float = 2.9 + i * 1.55
		_cam(Vector3(x, 1.35, hall.LINE_Z + 1.6), Vector3(x, 1.25, hall.LINE_Z), 50.0)
		await _shot("%s_ylavartalo" % Game.PEOPLE[i].id)
		_cam(Vector3(x, 0.45, hall.LINE_Z + 1.8), Vector3(x, 0.45, hall.LINE_Z), 50.0)
		await _shot("%s_jalat" % Game.PEOPLE[i].id)
		_cam(Vector3(x, 1.65, hall.LINE_Z + 0.7), Vector3(x, 1.62, hall.LINE_Z), 50.0)
		await _shot("%s_kasvot" % Game.PEOPLE[i].id)
	get_tree().quit()
