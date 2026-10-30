extends Node3D
## Aurinkoa ottava Sinikka (scripts/aurinko_sinikka.gd) erikseen: koottu kuva edestä, päädyistä, ylhäältä ja takaa
## levossa ja huomatessaan pelaajan, lähikuvat päästä, hiuksista ja kämmenistä sekä mittarivit (RAKO, K8, ULOTTUMA,
## VARPAAT, JALAT). Ajo: tools/testit/aja.sh tscn tools/testit/aurinko_sinikka_kuvat.tscn

const Aurinko := preload("res://scripts/aurinko_sinikka.gd")
const Asento := preload("res://tools/testit/asento.gd")
const Pose := preload("res://scripts/pose.gd")
const B := preload("res://scripts/build.gd")

var out := "user://aurinko_sinikka"
var cam: Camera3D
var s: Node3D


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
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 150, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(30, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.88, 0.8, 0.6))  # hiekka
	s = Aurinko.new()
	add_child(s)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40.0
	_run.call_deferred()


func _bp(b: String) -> Vector3:
	return to_local(s.body.to_global(s.body.bone_position(b)))


func _run() -> void:
	for i in 60:
		await get_tree().process_frame
	var bad := _measure()
	print("DBG lasit ", s._shades.global_position if s._shades else Vector3.INF, " pää ", s.body.to_global(s.body.bone_position("Head")), " näkyy ", s._shades.is_visible_in_tree() if s._shades else false)
	if s._shades:
		for c in s._shades.get_children():
			print("DBG lasi osa ", c.global_position, " ", c.visible)
	var centre := Vector3(0, 0.3, 0)
	var front := Vector3(1, 0, 0)  # sivulta katsottuna (pituusakseli Z)
	await Asento.views(cam, out, "lepo", centre, 2.2, front)
	var head := _bp("Head")
	await _shot("paa_lahi", head + Vector3(0.45, 0.4, 0.25), head)
	await _shot("hiukset_lahi", head + Vector3(-0.1, 0.25, 0.6), head)
	await _shot("yla_lahi", head + Vector3(0.0, 1.3, -0.35), head + Vector3(0, 0, -0.3))
	var hl := _bp("hand_l")
	await _shot("kasi_l_lahi", hl + Vector3(-0.5, 0.35, -0.2), hl)
	var hr := _bp("hand_r")
	print("KÄSI_R ranne %s, kämmenen alin %.3f, rullan yläpinta %.3f" % [hr, _lowest(["hand_r"]), Aurinko.TOWEL_TOP + Aurinko.ROLL_R * 1.7])
	await _shot("kasi_r_lahi", hr + Vector3(0.5, 0.35, 0.2), hr)
	cam.look_at_from_position(Vector3(3, 1.6, -1), Vector3(0, 0.3, 0))
	s.notice("Kas, naapuri. Tuu viereen, pyyhe on iso.", 60.0)  # pitkä: testiajossa ruutu voi kestää 0,1 s
	for i in 30:
		await get_tree().process_frame
	print("HUOMAA lift %.2f turn %.2f lasit %s (lepo %s) pm %d t %.2f nt %.2f" % [s._lift, s._turn, s._shades.transform.origin, s._shades_rest.origin, s.process_mode, s._t, s._notice_t])
	await Asento.views(cam, out, "huomaa", centre, 2.2, front)
	head = _bp("Head")
	await _shot("huomaa_paa_lahi", head + Vector3(0.45, 0.4, 0.25), head)
	# Kasvojen puolelta (lasien suunta päästä): lasit otsalla ja katse kameraa (pelaajaa) kohti.
	# Kasvojen suunta poikkileikkauksessa (pituusakseli Z pois): lasit pään keskeltä katsottuna; kamera on +X:ssä.
	var hg: Vector3 = s.body.to_global(s.body.bone_position("Head"))
	var sg: Vector3 = (s._shades as Node3D).global_position
	var face := Vector3(sg.x - hg.x, sg.y - hg.y, 0.0).normalized()
	print("HUOMAA kasvot %s, kameran puolelle (X) %.2f %s" % [face, face.x, "OK" if face.x > 0.2 else "TESTI VIKA pää kääntyy poispäin"])
	await _shot("huomaa_kasvot", head + face * 0.55 + Vector3(0, 0.05, -0.15), head + Vector3(0, 0.05, 0.03))
	await _shot("huomaa_lasit", sg + face * 0.3 + Vector3(0, 0.0, -0.12), sg)
	cam.look_at_from_position(Vector3(3, 1.6, -1), Vector3(0, 0.3, 0))
	s.relax()
	for i in 60:
		await get_tree().process_frame
	await _shot("rauhoittui", Vector3(1.8, 1.2, 1.0), Vector3(0, 0.25, 0))
	print("AURINKO yhteensä vikoja: ", bad)
	get_tree().quit()


## Rakorivit: kädet vartaloon, selkä/pakarat/pohkeet pyyhkeeseen (K8), ulottumat, varpaat ja jalkojen risteys.
func _measure() -> int:
	var ch: Node3D = s.body
	var bad := Asento.report(ch, self, [["upperarm_l", "lowerarm_l", "hand_l"]], ["pelvis", "spine_01", "spine_02", "spine_03"])
	for lr in ["_l", "_r"]:
		var arm: float = _bp("upperarm" + lr).distance_to(_bp("lowerarm" + lr)) + _bp("lowerarm" + lr).distance_to(_bp("hand" + lr))
		print("ULOTTUMA käsi%s %.3f m, olka->ranne %.3f m" % [lr, arm, _bp("upperarm" + lr).distance_to(_bp("hand" + lr))])
	for part in [["lantio", ["pelvis"]], ["spine_02", ["spine_02"]], ["spine_03", ["spine_03"]], ["pohje_l", ["calf_l"]], ["pohje_r", ["calf_r"]]]:
		var pts := Pose.limb_points(ch, self, part[1], 1)
		var low := INF
		for q in pts:
			low = minf(low, q.y)
		var gap: float = low - Aurinko.TOWEL_TOP
		var ok := gap >= -0.01 and gap <= 0.02
		print("K8 %s rako pyyhkeeseen %.3f m %s" % [part[0], gap, "OK" if ok else "TESTI VIKA"])
		bad += 0 if ok else 1
	for lr in ["_l", "_r"]:
		var up: float = (_bp("ball" + lr) - _bp("foot" + lr)).normalized().y
		print("VARPAAT%s ylös %.2f %s" % [lr, up, "OK" if up > 0.5 else "TESTI VIKA"])
		bad += 0 if up > 0.5 else 1
	var cross := (_bp("foot_l") - _bp("foot_r")).x * (_bp("thigh_l") - _bp("thigh_r")).x
	print("JALAT %s, jalkaterät erillään %.2f m" % ["ei ristissä" if cross > 0.0 else "RISTISSÄ", _bp("foot_l").distance_to(_bp("foot_r"))])
	var hd := _bp("Head")
	var ft := (_bp("foot_l") + _bp("foot_r")) / 2.0
	print("SUUNTA pää z=%.2f jalat z=%.2f (pää +Z) %s" % [hd.z, ft.z, "OK" if hd.z > ft.z + 1.0 else "TESTI VIKA"])
	bad += 0 if hd.z > ft.z + 1.0 else 1
	bad += Asento.solids(ch, self)
	return bad


func _lowest(bones: Array) -> float:
	var low := INF
	for q in Pose.limb_points(s.body, self, bones, 1):
		low = minf(low, q.y)
	return low


func _shot(name: String, from: Vector3, to: Vector3) -> void:
	cam.look_at_from_position(from, to)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("kuva ", name)
