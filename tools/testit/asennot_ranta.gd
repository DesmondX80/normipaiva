extends Node
## Rannan rantatuolin istujat erillisessä huoneessa (nopea kierros, osa a:n ranta_0/ranta_1 samalla tuolilla ja
## samoilla hahmoilla kuin world.gd): Pose.sit RENTO, kuvat edestä, päädyistä, ylhäältä ja takaa sekä ASENTO-rivit.
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 -- --shot=x.png --nohud --scene=asennot --asento=ranta

const Pose := preload("res://scripts/pose.gd")
const Asento := preload("res://tools/testit/asento.gd")
const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Seat := preload("res://scripts/seat.gd")

var main: Node3D


func run() -> void:
	var out := "user://asennot_ranta"
	DirAccess.make_dir_recursive_absolute(out)
	if main._talk_box.is_open():
		main._talk_box.close()
	var room := Node3D.new()
	room.position = Vector3(0, 300, 0)
	main.add_child(room)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.88)
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	room.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 200, 0)
	room.add_child(sun)
	B.mesh(room, B.boxm(Vector3(14, 0.1, 14)), Vector3(0, -0.05, 0), Color(0.86, 0.8, 0.62))
	var looks := [
		{"model": "male", "shirt": Color(0.95, 0.75, 0.68), "pants": Color(0.2, 0.4, 0.75), "hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.22, 0.15), "height": 1.8, "skin": Color(0.95, 0.75, 0.68), "belly": 0.6},
		{"model": "female", "shirt": Color(0.95, 0.4, 0.5), "pants": Color(0.95, 0.4, 0.5), "hair": "Hair_Long", "hair_color": Color(0.5, 0.35, 0.2), "height": 1.65, "skin": Color(0.95, 0.78, 0.68)},
	]
	var people := []
	var holders := []
	for i in looks.size():
		var holder := Node3D.new()
		holder.position = Vector3(i * 2.5, 0, 0)
		room.add_child(holder)
		var person: Node3D = Looks.make(holder, looks[i])
		person.play("Sitting_Idle", 0.0)
		var cc := Color(0.2, 0.5, 0.9)
		B.mesh(holder, B.boxm(Vector3(0.5, 0.04, 0.45)), Vector3(0, 0.42, -0.05), cc)
		var tilt := 0.5  # sama kuin world.gd:n rantatuoli
		var lean := Vector3(0, cos(tilt), sin(tilt))
		var pivot := Vector3(0, 0.42, 0.2)
		B.mesh(holder, B.boxm(Vector3(0.5, 0.7, 0.04)), pivot + lean * 0.35, cc).rotation.x = tilt
		for lx in [-0.23, 0.23]:
			for lz in [-0.25, 0.15]:
				B.mesh(holder, B.cyl(0.015, 0.015, 0.44, 5), Vector3(lx, 0.21, lz), Color(0.7, 0.7, 0.72))
		var nn := Vector3(0, sin(tilt), -cos(tilt))
		Seat.spot(holder, {"seat": Vector3(0, 0.44, -0.04), "front": Vector3(0, 0, -1), "back": {"p": pivot + lean * 0.35 + nn * 0.02, "n": nn}})
		people.append(person)
		holders.append(holder)
	for i in 6:
		await main.get_tree().process_frame
	for i in people.size():
		Pose.sit(people[i], holders[i], Pose.RENTO, {"ristissa": true})
	for i in 6:
		await main.get_tree().process_frame
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.current = true
	cam.fov = 40.0
	var bad := 0
	for i in people.size():
		print("ASENTO ranta %d" % i)
		bad += Asento.report(people[i], room, [["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"]],
			["pelvis", "spine_01", "spine_02", "spine_03", "thigh_l", "thigh_r"])
		await Asento.views(cam, out, "ranta_%d" % i, holders[i].global_position + Vector3(0, 0.6, 0), 1.8, Vector3(0, 0, -1))
	print("ASENTO yhteensä virheitä: ", bad, " kuvat: ", ProjectSettings.globalize_path(out))
