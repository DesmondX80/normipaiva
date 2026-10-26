extends Node
## Asentojen tarkistus, osa B (koti ja välianimaatiot): ajaa oikean välianimaation, jäädyttää ajan ja kuvaa kaikki
## istujat (kuvat edestä, päädyistä, ylhäältä, takaa) sekä tulostaa ASENTO-rivit.
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 -- --nohud --scene=asennot --asento=b --kohta=<nimi>
## kohta: tarpio, viita, mirkku, makkara, sauna_savu, sauna_tynnyri, taksi_koti, pekka, juna, tv, uutiset, nortti, ankkuri

const Pose := preload("res://scripts/pose.gd")
const Asento := preload("res://tools/testit/asento.gd")
const B := preload("res://scripts/build.gd")
const M := preload("res://scripts/map_data.gd")
const Mokki := preload("res://scripts/mokki.gd")
const Looks := preload("res://scripts/looks.gd")
const NewsScreen := preload("res://scripts/news_screen.gd")
const HomeInterior := preload("res://scripts/home_interior.gd")

var main: Node3D
var kohta := "tarpio"


func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame


## Kaikki istuvat/ajavat hahmot solmun alla.
func _chars(node: Node, out: Array) -> void:
	for c in node.get_children():
		if is_instance_valid(c) and c.has_method("bone_position") and str(c.get("_current")).begins_with("Sitting") or c.get("_current") == "Driving":
			out.append(c)
		_chars(c, out)


func _shoot(cam: Camera3D, out: String, root: Node3D, size := 1.8, tag := "") -> void:
	var list := []
	_chars(root, list)
	print("ASENTO %s: %d hahmoa" % [kohta, list.size()])
	var bad := 0
	var i := 0
	for ch: Node3D in list:
		var front: Vector3 = -ch.global_basis.z
		front.y = 0
		front = front.normalized()
		var name := "%s%s_%d" % [kohta, tag, i]
		print("ASENTO ", name, " lantio ", ch.to_global(ch.bone_position("pelvis")), " jalka_l ", ch.to_global(ch.bone_position("foot_l")),
			" jalka_r ", ch.to_global(ch.bone_position("foot_r")), " anim ", ch.get("_current"))
		await Asento.views(cam, out, name, ch.global_position + Vector3(0, 0.6, 0), size, front)
		bad += Asento.report(ch, root, [["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"]],
			["pelvis", "spine_01", "spine_02", "spine_03", "thigh_l", "thigh_r"])
		var lr_cross: float = (ch.to_global(ch.bone_position("foot_l")) - ch.to_global(ch.bone_position("foot_r"))).dot(ch.global_basis.x)
		print("ASENTO %s jalat %s (jalka_l - jalka_r sivuakselilla %.3f)" % [name, "ei ristissä" if lr_cross < 0.0 else "RISTISSÄ", lr_cross])
		var pel: Vector3 = ch.to_global(ch.bone_position("pelvis"))
		for lr in ["_l", "_r"]:
			var d: float = (ch.to_global(ch.bone_position("calf" + lr)) - ch.to_global(ch.bone_position("thigh" + lr))).dot(front)
			print("ASENTO %s polvi%s edessä %.3f %s" % [name, lr, d, "OK" if d > 0.0 else "VIRHE"])
		i += 1
	print("ASENTO %s virheitä %d kuvat %s" % [kohta, bad, ProjectSettings.globalize_path(out)])


func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kohta="):
			kohta = arg.substr(8)
	var out := "user://asennot_b"
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera3D.new()
	cam.fov = 40.0
	main.add_child(cam)
	var cs: Node = main.cutscene
	var at := Vector3.ZERO
	var root: Node3D = null
	match kohta:
		"tarpio", "viita", "mirkku", "makkara":
			var pit: Vector3 = M.w(M.LAAVU)
			if kohta == "viita":
				pit = main.world.viita_pos
			if kohta == "makkara":
				var lay: Dictionary = Mokki.keskimmainen_layout()
				main.mokki.ensure_built()
				pit = main.mokki.to_global(main.mokki.laavu_fire)
			main.player.global_position = pit + Vector3(0, 1, 6)
			await _frames(30)
			match kohta:
				"tarpio":
					cs.laavu_sunset(pit, main.world.fire, "T", "S", func() -> void: pass)
				"viita":
					main._viita_find_shore()
					cs.laavu_sunset(pit, main.world.viita_fire, "T", "S", func() -> void: pass, main._viita_dir)
				"mirkku":
					cs.mirkku_teltta(pit, main.world.fire, main.mirkku_tent, "T", "S", func() -> void: pass)
				"makkara":
					var lay2: Dictionary = Mokki.keskimmainen_layout()
					cs.makkara(pit, main.mokki.global_basis * Vector3(lay2.d.x, 0, lay2.d.y), func() -> void: pass)
			await _frames(12)
			root = cs._props
		"sauna_savu", "sauna_tynnyri":
			main.mokki.ensure_built()
			var frame: Transform3D = main.mokki.sauna_frame() if kohta == "sauna_savu" else main.mokki.barrel_frame()
			main.player.global_position = frame.origin + Vector3(0, 1, 6)
			await _frames(30)
			var lay3: Dictionary = {} if kohta == "sauna_savu" else Cutscene_SAUNA_TYNNYRI()
			cs.sauna_relax(frame, false, func() -> void: pass, lay3, false)
			await _frames(12)
			root = cs._props
		"taksi_koti":
			cs.taxi_home(Vector3.ZERO, "", func() -> void: pass)
			await _frames(12)
			root = cs._props
		"pekka":
			cs.pekka_ride("test", func() -> void: pass, "meno")
			await _frames(12)
			root = cs._props
		"juna":
			cs.train_ride(true, func() -> void: pass)
			await _frames(40)
			root = cs._props
		"tv":
			cs.paivi_tv(null, func() -> void: pass)
			await _frames(12)
			root = cs._props
		"uutiset":
			cs.news_tape("", func() -> void: pass)
			await _frames(12)
			root = cs._props
		"sohva", "pekka_auto", "juna_vaunu":
			# Välianimaation osat erikseen (ei aikajanaa): rakennetaan kohtaus ja kuvataan se ulkopuolisella kameralla.
			cs._begin()
			cs._layer.visible = false
			var o := Vector3(0, 500, 0)
			var sun2 := DirectionalLight3D.new()
			sun2.rotation_degrees = Vector3(-50, 200, 0)
			main.add_child(sun2)
			var size2 := 1.8
			if kohta == "sohva":
				o = cs.TV_ROOM
				cs._tv_room(o)
				for p in [[Looks.player(), Vector3.ZERO], [Looks.PAIVI, Vector3(-0.9, 0, 0)]]:
					var ch: Node3D = Looks.make(cs._props, p[0])
					cs._sit_on_sofa(ch, o + p[1])
					ch.play("Sitting_Idle", 0.0)
					cs._sit_on_sofa(ch, o + p[1])
			elif kohta == "pekka_auto":
				var car := Node3D.new()
				car.position = o
				cs._props.add_child(car)
				cs._pekka_car(car)
			else:
				var car := Node3D.new()
				car.position = o
				cs._props.add_child(car)
				cs._build_dining_car(car)
				size2 = 0.9
			main.player.global_position = o + Vector3(0, 1, 6)
			await _frames(10)
			cam.current = true
			await _shoot(cam, out, cs._props, size2)
			if kohta == "pekka_auto":
				for c in cs._props.get_children()[0].get_children():
					if c is MeshInstance3D:
						c.visible = false
				await _shoot(cam, out, cs._props, size2, "_ilman_koria")
			return
		"nortti":
			var room := Node3D.new()
			room.position = Vector3(0, 400, 0)
			main.add_child(room)
			var hi: Node3D = HomeInterior.new()
			room.add_child(hi)
			await _frames(10)
			var sun := DirectionalLight3D.new()
			sun.rotation_degrees = Vector3(-50, 200, 0)
			main.add_child(sun)
			main.player.global_position = room.global_position + Vector3(0, 1, 0)
			root = hi
		"ankkuri":
			var ns: SubViewport = NewsScreen.new()
			main.add_child(ns)
			await _frames(10)
			cam.reparent(ns)
			cam.current = true
			root = ns.get_child(0) as Node3D if ns.get_child_count() > 0 else null
			var all := []
			_chars(ns, all)
			var ch: Node3D = all[0]
			ns.size = Vector2i(1280, 720)
			ns.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var front: Vector3 = Vector3(0, 0, 1)
			print("ASENTO ankkuri lantio ", ch.to_global(ch.bone_position("pelvis")), " jalka_l ", ch.to_global(ch.bone_position("foot_l")))
			await Asento.views(cam, out, "ankkuri", ch.global_position + Vector3(0, 0.6, 0), 1.8, front)
			print("ASENTO ankkuri kuvat ", ProjectSettings.globalize_path(out))
			return
	Engine.time_scale = 0.01  # jäädytä välianimaatio
	for k in 3:  # välianimaation oma kamera (suljetuissa tiloissa ulkopuolinen kamera ei näe sisään)
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png(out.path_join("%s_oma_%d.png" % [kohta, k]))
		await _frames(50)
	cam.current = true
	await _frames(5)
	await _shoot(cam, out, root)
	Engine.time_scale = 1.0


func Cutscene_SAUNA_TYNNYRI() -> Dictionary:
	return load("res://scripts/cutscene.gd").SAUNA_TYNNYRI
