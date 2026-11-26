extends Node
## Junan erikoiskohtauksen riisunta (Helenan mustat pitsialusvaatteet ja viekoitteleva riisunta): ajaa oikean välianimaation
## (verkkopaita, tarjotut paukut, Saloisista Raaheen), kuvaa pelikameralta riisunnan vaiheet (STRIP_LEN s) ja tulostaa
## RISSUNTA-rivit (Helenan käsien ja pelaajan käden raot, läpimenot).
## aja.sh --kiintea scene asennot --asento=h
const Kuva := preload("res://tools/testit/kuva.gd")

const Pose := preload("res://scripts/pose.gd")
const Looks := preload("res://scripts/looks.gd")
const Asento := preload("res://tools/testit/asento.gd")

const KUVAT := [0.5, 1.6, 2.8, 3.8, 4.8, 5.6, 6.6, 7.0, 7.3, 7.6, 8.0, 8.2, 8.5, 8.9, 9.6]  # s riisunnan alusta
const ASENNOT := [[6.4, "puolivali"], [8.5, "loppu"]]  # s: Helenan asennon kuvat edestä, päädystä ja ylhäältä + rako- ja läpimenotarkistus

var main: Node3D


func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame


## --kohta=pitsi: Helenan pitsialusvaatteet (lace) edestä, sivulta ja takaa sekä lähikuvat ilman välianimaatiota.
func pitsi(out: String) -> void:
	var Cut := load("res://scripts/cutscene.gd")
	var stage := Node3D.new()
	main.add_child(stage)
	stage.global_position = Vector3(5000, 0, 5000)
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-35, 20, 0)
	stage.add_child(lamp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	stage.add_child(env)
	for i in 3:
		var c: Node3D = Looks.make(stage, Cut.helena_bikini())
		c.body_mat.set_shader_parameter("lace", true)
		c.body_mat.set_shader_parameter("lace_col", Cut.HELENA_LACE)
		c.body_mat.set_shader_parameter("nipple_cloth", 0.4)
		c.position = Vector3(-0.9 + i * 0.9, 0, 0)
		c.rotation.y = [PI, PI * 0.5, 0.0][i]
		c.play("Idle", 0.0)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.current = true
	var shots := [["koko", Vector3(0, 1.1, 3.6), Vector3(0, 1.05, 0), 40.0],
		["yla_edesta", Vector3(-0.9, 1.25, 0.75), Vector3(-0.9, 1.25, 0), 30.0],
		["yla_vino", Vector3(-0.5, 1.25, 0.6), Vector3(-0.9, 1.25, 0), 30.0],
		["ala_edesta", Vector3(-0.9, 0.95, 0.75), Vector3(-0.9, 0.95, 0), 30.0],
		["ala_takaa", Vector3(0.9, 0.95, 0.75), Vector3(0.9, 0.95, 0), 30.0],
		["yla_takaa", Vector3(0.9, 1.25, 0.75), Vector3(0.9, 1.25, 0), 30.0],
		["ala_sivulta", Vector3(0.0, 0.95, 0.75), Vector3(0.0, 0.95, 0), 30.0]]
	for k in shots:
		cam.fov = k[3]
		cam.look_at_from_position(stage.global_position + k[1], stage.global_position + k[2])
		for i in 6:
			await main.get_tree().process_frame
		await Kuva.piirto()
		Kuva.ruutu(main.get_viewport()).save_png("%s/pitsi_%s.png" % [out, k[0]])
	print("RISSUNTA pitsikuvat %s" % ProjectSettings.globalize_path(out))


## Helenan asento tässä hetkessä: kuvat edestä, päädystä ja ylhäältä, käsien rako vartaloon ja läpimenot.
func _asento(cs: Node, out: String, tag: String) -> int:
	var hl: Node3D = cs.train_cast.helena
	var car: Node3D = hl.get_parent()
	var cam := Camera3D.new()
	cam.fov = 40.0
	car.add_child(cam)
	cam.current = true
	var front: Vector3 = -hl.global_basis.z
	print("RISSUNTA asento %s undress %.2f" % [tag, float(hl.body_mat.get_shader_parameter("undress"))])
	await Asento.views(cam, out, "helena_" + tag, hl.global_position + Vector3(0, 0.7, 0), 1.2, front)
	# Pari: pelaajan ja Helenan väli (jalkaterät, reidet) edestä, päädystä ja ylhäältä.
	var hero: Node3D = cs.train_cast["minä"]
	var mid: Vector3 = (hl.global_position + hero.global_position) * 0.5 + Vector3(0, 0.3, 0)
	await Asento.views(cam, out, "pari_" + tag, mid, 0.9, front)
	var bad: int = Asento.report(hl, car, [["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"]],
		["pelvis", "spine_01", "spine_02", "spine_03", "thigh_l", "thigh_r"])
	bad += Asento.solids(hl, car)
	cam.current = false
	cam.queue_free()
	cs._cam.current = true
	return bad


func run() -> void:
	var out := "user://asennot_h"
	DirAccess.make_dir_recursive_absolute(out)
	for arg in OS.get_cmdline_user_args():
		if arg == "--kohta=pitsi":
			await pitsi(out)
			return
	var cs: Node = main.cutscene
	cs.test_hold = true
	Looks.outfit = "farkut"
	cs.train_ride(true, func() -> void: pass)
	var waited := 0
	while not str(cs._sub.text).contains("Täällähän on kuuma") and waited < 6000:
		await _frames(1)
		waited += 1
	print("RISSUNTA riisunta alkaa ruudulla %d" % waited)
	var t0: float = cs._now_ms()
	var i := 0
	var j := 0
	var bad := 0
	while i < KUVAT.size():
		await _frames(1)
		var tt: float = (cs._now_ms() - t0) / 1000.0
		if j < ASENNOT.size() and tt >= ASENNOT[j][0]:
			bad += await _asento(cs, out, ASENNOT[j][1])
			j += 1
			await _frames(4)
			continue
		if tt >= KUVAT[i]:
			var f := "%s/riisunta_%02d_%.1fs.png" % [out, i, tt]
			Kuva.ruutu(main.get_viewport()).save_png(f)
			var hl: Node3D = cs.train_cast.helena
			print("RISSUNTA %.1fs undress %.2f teksti %s" % [tt, float(hl.body_mat.get_shader_parameter("undress")), str(cs._sub.text)])
			i += 1
	print("RISSUNTA kuvat %s" % ProjectSettings.globalize_path(out))
	print("RISSUNTA asentovirheitä %d" % bad)
	await _frames(5)
	cs.test_hold = false
