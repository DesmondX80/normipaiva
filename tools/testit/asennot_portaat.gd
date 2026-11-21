extends Node
## Honganpalon portaiden istuja erillisessä huoneessa (nopea kierros osa a:n hongan_0:lle ja läpimenotestin Portaat-paikalle):
## samat askelmat, sama Seat.spot ja sama hahmo kuin world.gd:ssä. Pose.sit SUORA, kuvat ja ASENTO/jalkapohja-rivit.
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 -- --shot=x.png --nohud --scene=asennot --asento=portaat

const Pose := preload("res://scripts/pose.gd")
const Asento := preload("res://tools/testit/asento.gd")
const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Seat := preload("res://scripts/seat.gd")
const Contact := preload("res://scripts/contact.gd")

var main: Node3D


func run() -> void:
	var out := "user://asennot_portaat"
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
	B.mesh(room, B.boxm(Vector3(14, 0.1, 14)), Vector3(0, -0.05, 0), Color(0.5, 0.45, 0.4))
	var stairs := Node3D.new()
	stairs.name = "Portaat"
	room.add_child(stairs)
	var fz := 0.0
	for k in 3:  # sama kuin world.gd (Honganpalon koulu)
		B.box(stairs, Vector3(4.0, 0.15, 0.4), Vector3(0, 0.07 + k * 0.15, fz - 1.4 + k * 0.4), Color(0.6, 0.6, 0.58))
	Seat.spot(stairs, {"seat": Vector3(1.0, 0.445, fz - 0.62), "front": Vector3(0, 0, -1)})
	var holder := Node3D.new()
	room.add_child(holder)
	var t: Node3D = Looks.make(holder, {"model": "female", "shirt": Color(0.85, 0.3, 0.6), "hair": "Hair_Long",
		"hair_color": Color(0.9, 0.8, 0.5), "height": 1.62, "pants": Color(0.15, 0.18, 0.3), "shoes": Color(0.9, 0.9, 0.9),
		"skin": Color(0.95, 0.8, 0.7)})
	t.play("Sitting_Idle", 0.0)
	for i in 6:
		await main.get_tree().process_frame
	Pose.sit(t, stairs, Pose.SUORA, {"jalat_ulos": 1.8})
	for i in 6:
		await main.get_tree().process_frame
	var bp := func(b: String) -> Vector3: return stairs.to_local(t.to_global(t.bone_position(b)))
	for b in ["pelvis", "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r", "upperarm_l", "lowerarm_l", "hand_l"]:
		print("PORTAAT luu %s %s" % [b, bp.call(b)])
	var bad := Asento.report(t, room, [["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"]],
		["pelvis", "spine_01", "spine_02", "spine_03", "thigh_l", "thigh_r"])
	var solids := Contact.world_solids(stairs)
	for lr: String in ["_l", "_r"]:
		var low := INF
		for bn in ["foot" + lr, "ball" + lr]:
			var lb := INF
			var at := Vector3.ZERO
			for q in Pose.limb_points(t, main.world, [bn]):
				var g: Vector3 = main.world.to_global(q)
				var sup := Contact.support_y(solids, g.x, g.z, g.y + 0.3)
				if sup > -INF and g.y - sup < lb:
					lb = g.y - sup
					at = stairs.to_local(g)
			print("PORTAAT %s alin %.4f kohdassa %s" % [bn, lb, at])
			low = minf(low, lb)
		print("PORTAAT jalkapohja%s alin %.4f m %s" % [lr, low, "VIRHE" if low < -0.005 else "OK"])
		if low < -0.005:
			bad += 1
	var c: Vector3 = stairs.to_global(Vector3(1.0, 0.5, fz - 0.9))
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.current = true
	cam.fov = 40.0
	await Asento.views(cam, out, "portaat", c, 1.6, stairs.global_basis * Vector3(0, 0, -1))
	print("ASENTO yhteensä virheitä: ", bad, " kuvat: ", ProjectSettings.globalize_path(out))
