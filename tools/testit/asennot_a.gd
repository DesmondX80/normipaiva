extends Node
## Asentojen tarkistus, osa A (kauppa ja kylä): K-Marketin penkin mummot erillisessä huoneessa; kuvat ja ASENTO-rivit.
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 -- --shot=x.png --nohud --scene=asennot --asento=a

const Pose := preload("res://scripts/pose.gd")
const Asento := preload("res://tools/testit/asento.gd")
const B := preload("res://scripts/build.gd")
const Mummot := preload("res://scripts/mummot.gd")

var main: Node3D


func _room() -> Node3D:
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
	B.mesh(room, B.boxm(Vector3(14, 0.1, 14)), Vector3(0, -0.05, 0), Color(0.5, 0.45, 0.4))
	return room


func run() -> void:
	var out := "user://asennot_a"
	DirAccess.make_dir_recursive_absolute(out)
	var room := _room()
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.current = true
	cam.fov = 40.0
	await _mummot(room, cam, out)
	cam.reparent(main)
	await _aurinko(cam, out)
	await _kylä(cam, out)
	print("ASENTO osa A kuvat: ", ProjectSettings.globalize_path(out))


## K-Marketin penkki: kaksi mummoa istuu, penkin etu on +Z. Tarkistetaan sekä Idle- että Talking-asento.
func _mummot(room: Node3D, cam: Camera3D, out: String) -> void:
	var m: Node3D = Mummot.new()
	room.add_child(m)
	var front := Vector3(0, 0, 1)
	for i in 8:
		await main.get_tree().process_frame
	var parts := []
	for c in m.get_children():
		if c is MeshInstance3D and absf((c as Node3D).rotation_degrees.x) > 1.0:
			parts.append(c)
	var bad := Asento.bench_report(parts)
	for i in 2:
		print("ASENTO mummo %d" % i)
		bad += Asento.seat_report(m._grans[i], room, Mummot.SEAT_TOP, 0.0, front)
		bad += Asento.report(m._grans[i], room, [["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"]],
			["pelvis", "spine_01", "spine_02", "spine_03", "thigh_l", "thigh_r"])
	await Asento.views(cam, out, "mummot", room.global_position + Vector3(0, 0.7, 0), 2.4, front)
	for i in 2:
		if m.has_method("_lap_hands"):
			m._lap_hands(i, false)
		m._grans[i].play("Sitting_Talking", 0.0)
	for i in 6:
		await main.get_tree().process_frame
	await Asento.views(cam, out, "mummot_puhe", room.global_position + Vector3(0, 0.7, 0), 2.4, front)
	for i in 2:
		bad += Asento.report(m._grans[i], room, [["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"]],
			["pelvis", "spine_01", "spine_02", "spine_03", "thigh_l", "thigh_r"])
	for i in 2:
		if m.has_method("_lap_hands"):
			m._lap_hands(i, true)
	for i in 6:
		await main.get_tree().process_frame
	await Asento.views(cam, out, "mummo_lahi", room.global_position + Vector3(-0.5, 0.6, 0), 1.0, front)
	print("ASENTO mummot virheitä: ", bad)


## Kuvaa maailman istujan: kamera hahmon ympärille. Asennetaan pelaaja paikalle, jotta maasto ja kohteet latautuvat.
func _world_view(cam: Camera3D, out: String, name: String, ch: Node3D, size := 2.0) -> int:
	var front: Vector3 = -ch.global_basis.z
	front.y = 0
	front = front.normalized()
	var at := ch.global_position
	print("ASENTO näkymä ", name, " paikallinen sijainti ", ch.position, " lantio ", ch.position + ch.basis * ch.bone_position("pelvis"), " jalka ", ch.position + ch.basis * ch.bone_position("foot_l"))
	main.player.global_position = at + Vector3(0, 1, 0) + front * 6.0
	for i in 20:
		await main.get_tree().process_frame
	await Asento.views(cam, out, name, at + Vector3(0, 0.6, 0), size, front)
	var pts := Pose.limb_points(ch, main.world, ["pelvis", "thigh_l", "thigh_r"])
	var pel: Vector3 = main.world.to_local(ch.to_global(ch.bone_position("pelvis")))
	var low := INF
	for q in pts:
		if Vector2(q.x - pel.x, q.z - pel.z).length() < 0.15:
			low = minf(low, q.y)
	print("ASENTO %s: lantion pohja y=%.3f (pinta %d pistettä), kasvot vs etu %.3f" % [name, low, pts.size(), (-ch.global_basis.z).dot(front)])
	return Asento.report(ch, main.world, [["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"]],
		["pelvis", "spine_01", "spine_02", "spine_03", "thigh_l", "thigh_r"])


## Kaikki hahmot (animaatio anim) pisteen lähellä, rekursiivisesti.
func _chars_near(node: Node, p: Vector3, r: float, anim: String, out: Array) -> void:
	for c in node.get_children():
		if c.has_method("bone_position") and c.get("_current") == anim and Vector2((c as Node3D).global_position.x - p.x, (c as Node3D).global_position.z - p.z).length() < r:
			out.append(c)
		_chars_near(c, p, r, anim, out)


func _kylä(cam: Camera3D, out: String) -> void:
	var world: Node3D = main.world
	cam.current = true
	var bad := 0
	# Rannan tuolit (mummo näkyy aamulla, perheet päivällä)
	for h: Node3D in world.uimaranta_people:
		main.clock_min = 9 * 60 if h.get_meta("mummo") else 13 * 60
		for i in 3:
			await main.get_tree().process_frame
		for c in h.get_children():
			if c.has_method("bone_position") and c.get("_current") == "Sitting_Idle":
				bad += await _world_view(cam, out, "ranta_%d" % world.uimaranta_people.find(h), c, 1.8)
	print("ASENTO kylä virheitä: ", bad)
	# Muut kohteet: sijainti ja kellonaika
	var spots := []
	main.clock_min = 13 * 60
	var M := preload("res://scripts/map_data.gd")
	for i in 1:
		var c: Vector2 = M.w2(M.PLAYGROUNDS[i][1])
		var bp := Vector3(c.x, 0, c.y) + Basis(Vector3.UP, i * 0.9 + 0.3) * Vector3(0, 0, -5.0)
		spots.append(["leikkipuisto_%d" % i, bp, "Sitting_Idle", 13 * 60])
	spots.append(["rauniot", world.rauniot_youth.global_position, "Sitting_Idle", 22 * 60])
	spots.append(["hongan", world.hongan_youth.global_position, "Sitting_Idle", 20 * 60])
	spots.append(["taksi", world.taxi_pos, "Driving", 13 * 60])
	for s in spots:
		main.clock_min = s[3]
		var found := []
		_chars_near(world, s[1], 3.0, s[2], found)
		print("ASENTO %s: %d hahmoa" % [s[0], found.size()])
		for k in found.size():
			bad += await _world_view(cam, out, "%s_%d" % [s[0], k], found[k], 1.0 if s[0] == "hongan" else 1.8)
			if s[0] == "taksi":  # leikkauskuva: auton kori piiloon, jalat ja lantio näkyviin
				for c in found[k].get_parent().get_children():
					if c is MeshInstance3D:
						c.visible = false
				bad += await _world_view(cam, out, "taksi_ilman_%d" % k, found[k], 1.8)
	print("ASENTO kylä yhteensä virheitä: ", bad)


## Oravajärven rannalla aurinkoa ottava Sinikka klo 13 (aurinko_sinikka.gd): kuvat, läpimenot (K9) ja etäisyydet
## rannan kalusteisiin ja perheisiin (K14: pyyhkeen ja hatun reunasta vähintään 1 m).
func _aurinko(cam: Camera3D, out: String) -> void:
	var world: Node3D = main.world
	var a: Node3D = world.uimaranta_aurinko
	if a == null:
		print("TESTI VIKA aurinko-Sinikkaa ei ole (world.uimaranta_aurinko)")
		return
	main.clock_min = 13 * 60
	a.visible = true  # näkyvyys on main.gd:ssä (osa B); varmistetaan tässä
	cam.current = true
	main.player.global_position = a.global_position + Vector3(4, 1, 4)
	for i in 30:
		await main.get_tree().process_frame
	print("ASENTO aurinko: asetettu ", a.placed)
	var p: Vector3 = a.global_position
	var Tr := preload("res://scripts/terrain.gd")
	print("ASENTO aurinko: maaston korkeus T.h %.3f, asetelman nosto %.3f (pyyhkeen pinta +0,08, hiekka +0,065), sijainti %s" % [Tr.h(p.x, p.z), a.position.y - Tr.h(p.x, p.z), p])
	var bad: int = Asento.solids(a.body, main.world, 1.0)
	print("ASENTO aurinko: läpimenotarkistus tehty")
	var front: Vector3 = a.global_basis.x
	await Asento.views(cam, out, "aurinko", p + Vector3(0, 0.3, 0), 2.6, front, false)
	await Asento.views(cam, out, "aurinko_ymparisto", p + Vector3(0, 0.5, 0), 12.0, front, false)
	var M := preload("res://scripts/map_data.gd")
	var bp: Vector2 = M.w2(M.UIMARANTA)
	var dir: Vector2 = M.UIMARANTA_DIR
	var side := dir.orthogonal()
	var hut: Vector2 = bp - dir * 15.0 - side * 9.0
	var dock: Vector2 = bp + side * 6.0
	var things := [["penkki", world.uimaranta_bench, 1.0], ["grilli", world.grilli_ranta_pos, 1.0],
		["laituri", Vector3(dock.x, 0, dock.y), 1.0], ["huussi", Vector3(hut.x, 0, hut.y), 1.0]]
	for h: Node3D in world.uimaranta_people:
		things.append(["perhe_%d" % world.uimaranta_people.find(h), h.global_position, 1.0])
	for t in things:
		var c: Vector3 = t[1]
		var d := Vector2(c.x - p.x, c.z - p.z).length() - 1.3 - (t[2] as float)  # 1,3 = pyyhkeen puolipituus ja hattu, t[2] = kohteen säde
		print("ASENTO aurinko etäisyys %s %.2f m %s" % [t[0], d, "OK" if d >= 1.0 else "TESTI VIKA liian lähellä"])
	print("ASENTO aurinko läpimenoja: ", bad)
	a.visible = false
