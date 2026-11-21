extends Node3D
## Ihon sävy: kasvo/kaula/rinta/käsi RGB-keskiarvot (kuvasta, tasainen valo) ja kuvat edestä, takaa, kasvot, hartia.
## godot --path . --resolution 1280x720 tools/testit/savy_mitta.tscn -- <kansio> [--anat=0] [--hahmot=a,b]
## Rasvanapin hahmot (pekka, arto, raimo, helena_r, sinikka_r) tehdään kuten crawler3d.setup (shirt/pants = iho, paljas).
const Kuva := preload("res://tools/testit/kuva.gd")

const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const Game := preload("res://scripts/rasvanappi_game.gd")

var out := "user://savy"
var anat := true
var face := 1.0  # --face=0: ennen-vertailu (face_match pois)
var names := ["pelaaja", "paivi", "juntti", "sinikka", "sinikka_bikini", "helena", "pekka_r", "arto_r", "raimo_r", "helena_r", "sinikka_r"]
var cam: Camera3D


func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--anat="):
			anat = s.ends_with("1")
		elif s.begins_with("--face="):
			face = float(s.substr(7))
		elif s.begins_with("--hahmot="):
			names = s.substr(9).split(",")
		elif not s.begins_with("--"):
			out = s
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, 180, 0)  # edestä (-Z = hahmon etu)
	add_child(sun)
	var s2 := DirectionalLight3D.new()
	s2.rotation_degrees = Vector3(-25, 0, 0)
	s2.light_energy = 0.8
	add_child(s2)
	B.mesh(self, B.boxm(Vector3(40, 0.1, 40)), Vector3(0, -0.05, 0), Color(0.6, 0.6, 0.6))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 30.0
	_run.call_deferred()


func _look(n: String) -> Dictionary:
	var l: Dictionary
	match n:
		"pelaaja": l = Looks.player()
		"paivi": l = Looks.PAIVI.duplicate()
		"juntti": l = Looks.JUNTTI.duplicate()
		"sinikka": l = Looks.SINIKKA.duplicate()
		"sinikka_bikini": l = Looks.sinikka_bikini()
		"helena": l = load("res://scripts/cutscene.gd").HELENA.duplicate()
		_:
			var id := n.trim_suffix("_r")
			var lk := Game.towel_look(Game.real_look(id))
			var skin: Color = lk.get("skin", Color(1.0, 0.9, 0.85))
			lk["shirt"] = skin
			lk["pants"] = skin
			lk["shoes"] = skin.darkened(0.25)
			lk["shoe"] = "paljas"
			lk["face_match"] = face
			lk["tube_y"] = 0.01
			lk["sleeve_x"] = 0.0
			lk["shorts_y"] = 1.4
			l = lk
	l["anat"] = anat
	return l


func _px(img: Image, p: Vector2, r := 4) -> Color:
	var s := Color(0, 0, 0)
	var k := 0
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var x := clampi(int(p.x) + dx, 0, img.get_width() - 1)
			var y := clampi(int(p.y) + dy, 0, img.get_height() - 1)
			s += img.get_pixel(x, y)
			k += 1
	return s / float(k)


func _fmt(c: Color) -> String:
	return "%d,%d,%d" % [roundi(c.r * 255), roundi(c.g * 255), roundi(c.b * 255)]


func _run() -> void:
	for n in names:
		var c: Node3D = Looks.make(self, _look(n))
		c.restart("Idle", 0.0, 1.0)
		for i in 8:
			await get_tree().process_frame
		var h := float(_look(n).get("height", 1.75))
		var head: Vector3 = c.to_global(c.bone_position("Head"))
		var ch: Vector3 = c.to_global(c.bone_position("spine_03"))
		# etukuva: kamera +Z:ssä katsoo hahmoa; pää ja rinta
		cam.global_position = Vector3(0, h * 0.78, -3.6)
		cam.look_at(Vector3(0, h * 0.78, 0))
		await get_tree().process_frame
		await Kuva.piirto()
		var img := Kuva.ruutu(get_viewport())
		var up := func(v: Vector3) -> Vector2: return cam.unproject_position(v)
		var cheek: Color = (_px(img, up.call(head + Vector3(-0.045, 0.06, -0.1)), 3) + _px(img, up.call(head + Vector3(0.045, 0.06, -0.1)), 3)) * 0.5
		var neck: Color = (_px(img, up.call(head + Vector3(-0.05, -0.1, -0.03)), 3) + _px(img, up.call(head + Vector3(0.05, -0.1, -0.03)), 3)) * 0.5
		var chest: Color = _px(img, up.call(ch + Vector3(0.0, 0.0, -0.12)), 4)
		var hand: Color = _px(img, up.call(c.to_global(c.bone_position("lowerarm_l")) * 0.5 + c.to_global(c.bone_position("hand_l")) * 0.5), 3)
		if not Kuva.piirretaan():
			print("SAVY %s ei tarkistettu: headless, ei piirrettyä kuvaa mitattavaksi" % n)
		else:
			print("SAVY %s anat=%s kasvo %s kaula %s rinta %s kasi %s" % [n, anat, _fmt(cheek), _fmt(neck), _fmt(chest), _fmt(hand)])
		img.save_png(out.path_join(n + "_etu.png"))
		var px := up.call(head) as Vector2
		for v in ["taka", "kasvot", "hartia"]:
			match v:
				"taka":
					cam.global_position = Vector3(0, h * 0.78, 3.6)
					cam.look_at(Vector3(0, h * 0.78, 0))
				"kasvot":
					cam.global_position = head + Vector3(0.0, 0.1, -1.0)
					cam.look_at(head + Vector3(0, 0.0, 0))
				"hartia":
					cam.global_position = ch + Vector3(0.0, 0.25, -1.1)
					cam.look_at(ch + Vector3(0.0, 0.2, 0))
			await get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(get_viewport()).save_png(out.path_join("%s_%s.png" % [n, v]))
		c.queue_free()
	print("valmis ", out)
	get_tree().quit()
