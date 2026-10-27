extends Node3D
## Elastiset hiukset (osa A2): Sinikka (bikini, pitkät hiukset, olkihattu) rantatuolilla, pää nojassa (Pose.sit RENTO). Mitataan
## selkänojan jalanjäljen kohdalta pinnan normaalia pitkin: kallo (gs >= 0), painunut tukka (jäännös/rako pintaan) ja hattu
## (gx >= 0), ja otetaan kuvat sivusta, päästä ja takaa. Virheet: "TESTI VIKA ...".
## aja.sh tscn tools/testit/hiukset.tscn

const Pose := preload("res://scripts/pose.gd")
const Seat := preload("res://scripts/seat.gd")
const Contact := preload("res://scripts/contact.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

var out := "user://hiukset"
var cam: Camera3D
var chair: Node3D
var ch: Node3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.88)
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(30, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.86, 0.78, 0.55))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 30.0
	_run.call_deferred()


func _build_chair() -> void:
	chair = Node3D.new()
	add_child(chair)
	B.mesh(chair, B.boxm(Vector3(0.9, 0.02, 1.8)), Vector3(0, 0.07, 0), Color(0.9, 0.2, 0.2))
	var cc := Color(0.95, 0.85, 0.2)
	B.mesh(chair, B.boxm(Vector3(0.5, 0.04, 0.45)), Vector3(0, 0.42, -0.05), cc)
	var tilt := 0.5
	var lean := Vector3(0, cos(tilt), sin(tilt))
	var pivot := Vector3(0, 0.42, 0.2)
	B.mesh(chair, B.boxm(Vector3(0.5, 0.7, 0.04)), pivot + lean * 0.35, cc).rotation.x = tilt
	var n := Vector3(0, sin(tilt), -cos(tilt))
	Seat.spot(chair, {"seat": Vector3(0, 0.44, -0.04), "front": Vector3(0, 0, -1),
		"back": {"p": pivot + lean * 0.35 + n * 0.02, "n": n}})


func _shot(tag: String, pos: Vector3, look: Vector3) -> void:
	cam.look_at_from_position(pos, look)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	cam.get_viewport().get_texture().get_image().save_png(out.path_join(tag + ".png"))


func _run() -> void:
	_build_chair()
	ch = Looks.make(chair, Looks.sinikka_bikini())
	ch.play("Sitting_Idle", 0.0)
	for i in 4:
		await get_tree().process_frame
	Pose.sit(ch, chair, Pose.RENTO, {"ristissa": true})
	for i in 10:
		await get_tree().process_frame
	_measure()
	var hp: Vector3 = ch.to_global(ch.bone_position("Head")) + Vector3(0, 0.05, 0)
	await _shot("1_sivu", hp + Vector3(3.0, -0.1, 0.0), hp + Vector3(0, -0.35, 0))
	await _shot("2_paa_sivu", hp + Vector3(1.0, 0.0, -0.05), hp)
	await _shot("3_paa_etu", hp + Vector3(0.7, 0.2, -0.9), hp)
	await _shot("4_paa_ylhaalta", hp + Vector3(0.3, 1.0, 0.5), hp)
	ch.clear_contacts()
	ch.refresh_pose()
	await _shot("5_ilman_painumaa", hp + Vector3(1.0, 0.0, -0.05), hp)
	print("HIUKSET valmis ", ProjectSettings.globalize_path(out))
	get_tree().quit()


func _measure() -> void:
	var d := Seat.of(chair)
	var bp: Vector3 = chair.to_global(d.back.p)
	var bn: Vector3 = (chair.global_transform.basis * (d.back.n as Vector3)).normalized()
	var bb := Contact._back_box(chair)
	var gs := Contact._foot_min(Contact.world_points(ch, Pose.limb_points, ["Head", "neck_01"], 1), bp, bn, bb)
	var gh_rest := Contact._foot_min(Contact.world_points(ch, Pose.limb_points, ["Head"], 2), bp, bn, bb)
	var gx := Contact._foot_min(Contact.head_extras(ch), bp, bn, bb)
	print("HIUKSET kallo %s, hiukset %s, hattu %s (m, + = rako nojaan, painumalaatikoita %d)" % [gs, gh_rest, gx, ch.press_boxes.size()])
	if gs == INF:
		print("HIUKSET pää ei ole nojalaatikon jalanjäljellä: ei tarkistettu (ei mitattavaa)")
		return
	if gs < -0.001:
		print("TESTI VIKA kallo nojan sisällä %.4f m" % gs)
	if gh_rest != INF:
		if gh_rest < -0.001:
			print("TESTI VIKA hiusten jäännös nojan läpi %.4f m (raja 1 mm)" % gh_rest)
		if gh_rest > 0.003:
			print("TESTI VIKA hiusten rako nojaan %.4f m (raja 3 mm)" % gh_rest)
	else:
		print("HIUKSET ei hiuksia nojan kohdalla: ei tarkistettu")
	if gx != INF and gx < -0.001:
		print("TESTI VIKA hattu nojan sisällä %.4f m" % gx)
