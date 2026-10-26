extends Node
## Pose-istumisapujen kokeilu (Osa 0): hahmo tuolilla, jalat lattialla, kädet reisillä; kuvat ja ASENTO-rivit.
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 -- --shot=x.png --scene=asennot --asento=0

const Pose := preload("res://scripts/pose.gd")
const Asento := preload("res://tools/testit/asento.gd")
const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const SEAT_Y := 0.45

var main: Node3D


func run() -> void:
	var out := "user://asennot_0"
	DirAccess.make_dir_recursive_absolute(out)
	var room := Node3D.new()
	room.position = Vector3(0, 300, 0)  # kauas kartasta
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
	B.mesh(room, B.boxm(Vector3(10, 0.1, 10)), Vector3(0, -0.05, 0), Color(0.5, 0.45, 0.4))
	# Tuoli: etu = -Z
	var wood := Color(0.45, 0.28, 0.16)
	B.mesh(room, B.boxm(Vector3(0.45, 0.05, 0.42)), Vector3(0, SEAT_Y - 0.025, 0), wood)
	B.mesh(room, B.boxm(Vector3(0.45, 0.45, 0.04)), Vector3(0, SEAT_Y + 0.25, 0.2), wood)
	for lx in [-0.19, 0.19]:
		for lz in [-0.17, 0.17]:
			B.mesh(room, B.boxm(Vector3(0.04, SEAT_Y - 0.05, 0.04)), Vector3(lx, (SEAT_Y - 0.05) / 2.0, lz), wood.darkened(0.2))
	var ch: Node3D = Looks.make(room, Looks.player())
	ch.play("Sitting_Idle", 0.0)
	var front := Vector3(0, 0, -1)
	Pose.seat(ch, front, Vector3(0, SEAT_Y, 0))
	Pose.feet_to_floor(ch, 0.0, front)
	for i in 3:
		await main.get_tree().process_frame
	Pose.hands_on_thighs(ch, room)
	for i in 3:
		await main.get_tree().process_frame
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.current = true
	cam.fov = 40.0
	await Asento.views(cam, out, "tuoli", room.global_position + Vector3(0, 0.6, 0), 1.6, front)
	var bad := Asento.seat_report(ch, room, SEAT_Y, 0.0, front)
	bad += Asento.report(ch, room, [["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"]],
		["pelvis", "spine_01", "spine_02", "spine_03", "thigh_l", "thigh_r"])
	print("ASENTO yhteensä virheitä: ", bad, " kuvat: ", ProjectSettings.globalize_path(out))
