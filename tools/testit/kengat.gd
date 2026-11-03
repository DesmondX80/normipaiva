extends Node3D
## Kengät (scripts/shoes.gd): rivi hahmoja (tyypit x male/female + paljas vertailuksi) lattialla y = 0. Mitataan:
## KENKA <tyyppi><malli><lr> alin (kenkäverkon ja vartalon alin piste foot+ball, Pose.limb_points; K9 ±5 mm seistessä),
## KENKA iho_ulkona (jalkaterän ihon pahin ulkonema kuoren läpi lepoasennossa, pitää olla < 0) ja RUUTU 24 kengällisellä
## hahmolla (ka ja p95 < 16,7 ms; vertailuksi samat paljain jaloin). Kuvat: edestä, sivulta, ylhäältä, takaa, kävelyn kolme
## vaihetta ja varpaillaan seisonta, rajattuna jalkoihin ja koottuna vertailukuviksi (vertailu_*.png). Viat: "TESTI VIKA ...".
## aja.sh tscn tools/testit/kengat.tscn

const Pose := preload("res://scripts/pose.gd")
const Looks := preload("res://scripts/looks.gd")
const Shoes := preload("res://scripts/shoes.gd")
const B := preload("res://scripts/build.gd")
const RUUTU := 1000.0 / 60.0

var out := "user://kengat"
var cam: Camera3D
var row: Array = []  # [nimi, hahmo]


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
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(40, 0.1, 40)), Vector3(0, -0.05, 0), Color(0.55, 0.52, 0.48))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 30.0
	_run.call_deferred()


func _look(kind: String, shoes: Color) -> Dictionary:
	return {"model": kind, "shirt": Color(0.3, 0.45, 0.6), "pants": Color(0.2, 0.22, 0.3), "shoes": shoes}


func _run() -> void:
	var looks := [["lenkkari_m", _look("male", Color(0.92, 0.92, 0.9))], ["lenkkari_f", _look("female", Color(0.92, 0.92, 0.9))],
		["punainen_f", _look("female", Color(0.85, 0.12, 0.1))], ["paljas_m", _look("male", Color(0.12, 0.1, 0.08))],
		["pelaaja", Looks.player("")]]
	for i in looks.size():
		var ch: Node3D = Looks.make(self, looks[i][1])
		ch.position = Vector3(i * 1.2, 0, 0)
		ch.play("Idle", 0.0, 0.0)
		ch.anim.seek(0.5, true)
		row.append([looks[i][0], ch])
	for i in 6:
		await get_tree().process_frame
	_measure()
	for r in row:
		await _views(r[0], r[1])
	await _walk(row[0][1], "lenkkari_m")
	await _walk(row[1][1], "lenkkari_f")
	await _tiptoe(row[0][1], "lenkkari_m")
	_sheet("vertailu_kuvakulmat", ["lenkkari_m_edesta", "lenkkari_m_sivu", "lenkkari_m_ylhaalta", "lenkkari_m_takaa",
		"lenkkari_f_edesta", "lenkkari_f_sivu", "lenkkari_f_ylhaalta", "punainen_f_sivu"])
	_sheet("vertailu_kavely", ["lenkkari_m_kavely_0", "lenkkari_m_kavely_1", "lenkkari_m_kavely_2", "lenkkari_m_varpaat",
		"lenkkari_f_kavely_0", "lenkkari_f_kavely_1", "lenkkari_f_kavely_2", "lenkkari_m_varpaat_edesta"])
	await _ruutu()
	print("KENKA valmis ", ProjectSettings.globalize_path(out))
	get_tree().quit()


## K9: alin piste kummankin jalan foot+ball-luiden pinnasta (kengällä kenkäverkko, paljaalla iho) lattiaan y = 0.
func _measure() -> void:
	for r in row:
		var ch: Node3D = r[1]
		for lr in ["_l", "_r"]:
			var pts := Pose.limb_points(ch, self, ["foot" + lr, "ball" + lr])
			if pts.is_empty():
				print("KENKA %s%s ei pisteitä: ei tarkistettu" % [r[0], lr])
				continue
			var lo := INF
			for q in pts:
				lo = minf(lo, q.y)
			print("KENKA %s%s alin %.1f mm (tyyppi %s, pohja %.1f mm)" % [r[0], lr, lo * 1000.0, ch.shoe_type, ch.shoe_sole * 1000.0])
			if ch.shoe_type != "paljas" and absf(lo) > 0.005:
				print("TESTI VIKA %s%s kengän alin %.1f mm lattiasta (raja ±5 mm)" % [r[0], lr, lo * 1000.0])
		if ch.shoe_mi != null:
			var o := Shoes.skin_outside(ch.shoe_mi.mesh, ch.body_mi.mesh.surface_get_arrays(0))
			print("KENKA %s iho_ulkona %.1f mm (lepoasento; varjostin painaa ihoa vielä 6 mm sisään)" % [r[0], o * 1000.0])
			if o > 0.0:
				print("TESTI VIKA %s jalkaterän iho %.1f mm kengän ulkopuolella" % [r[0], o * 1000.0])


func _feet(ch: Node3D) -> Vector3:
	return (ch.to_global(ch.bone_position("foot_l")) + ch.to_global(ch.bone_position("foot_r"))) / 2.0 + Vector3(0, -0.03, 0)


## Kameraa lähempi jalkaterä (suunta dir kamerasta katsottuna kohti hahmoa käännettynä): kuvan keskelle.
func _foot_near(ch: Node3D, dir: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := -INF
	for lr in ["_l", "_r"]:
		var f: Vector3 = (ch.to_global(ch.bone_position("foot" + lr)) + ch.to_global(ch.bone_position("ball" + lr))) / 2.0
		if f.dot(dir) > bd:
			bd = f.dot(dir)
			best = f
	return best + Vector3(0, -0.02, 0)


## Hahmon avaruudessa etu on -Z.
func _views(nm: String, ch: Node3D) -> void:
	var f := _feet(ch)
	var fw: Vector3 = -ch.global_basis.z
	var rt: Vector3 = ch.global_basis.x
	await _shot(nm + "_edesta", f + fw * 1.1 + Vector3(0, 0.3, 0), f)
	var g := _foot_near(ch, rt)
	await _shot(nm + "_sivu", g + rt * 0.75 + Vector3(0, 0.1, 0), g)
	g = _foot_near(ch, rt)
	await _shot(nm + "_ylhaalta", g + Vector3(0, 0.75, 0) + fw * 0.4, g)
	await _shot(nm + "_takaa", f - fw * 1.1 + Vector3(0, 0.35, 0), f)
	g = _foot_near(ch, fw + rt)
	await _shot(nm + "_kolmeneljannes", g + (fw + rt).normalized() * 0.75 + Vector3(0, 0.35, 0), g)


func _walk(ch: Node3D, nm: String) -> void:
	ch.play("Walk", 0.0, 0.0)
	var ln: float = ch.anim_length("Walk")
	for i in 3:
		ch.anim.seek(ln * (0.12 + i * 0.3), true)
		for k in 3:
			await get_tree().process_frame
		var f := _feet(ch)
		await _shot("%s_kavely_%d" % [nm, i], f + ch.global_basis.x * 1.2 + Vector3(0, 0.15, 0), f)
		_lowest(ch, "%s kävely %d" % [nm, i])
	ch.play("Idle", 0.0, 0.0)


## Varpaillaan: kantapää ylös (nilkka), päkiä taipuu takaisin vaakaan.
func _tiptoe(ch: Node3D, nm: String) -> void:
	ch.set_override("foot_l", Vector3.RIGHT, 0.6)
	ch.set_override("foot_r", Vector3.RIGHT, 0.6)
	ch.set_override("ball_l", Vector3.RIGHT, -0.6)
	ch.set_override("ball_r", Vector3.RIGHT, -0.6)
	for k in 3:
		await get_tree().process_frame
	var f := _foot_near(ch, ch.global_basis.x)
	await _shot(nm + "_varpaat", f + ch.global_basis.x * 0.75 + Vector3(0, 0.1, 0), f)
	f = _feet(ch)
	await _shot(nm + "_varpaat_edesta", f - ch.global_basis.z * 1.1 + Vector3(0, 0.3, 0), f)
	_lowest(ch, nm + " varpaat")
	ch.clear_overrides()


func _lowest(ch: Node3D, tag: String) -> void:
	var lo := INF
	for q in Pose.limb_points(ch, self, ["foot_l", "ball_l", "foot_r", "ball_r"]):
		lo = minf(lo, q.y)
	print("KENKA %s alin %.1f mm" % [tag, lo * 1000.0])


func _shot(tag: String, pos: Vector3, look: Vector3) -> void:
	cam.look_at_from_position(pos, look)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	cam.get_viewport().get_texture().get_image().save_png(out.path_join(tag + ".png"))


## Vertailukuva: kuvat pienennettyinä 4 x 2 ruudukkoon.
func _sheet(nm: String, tags: Array) -> void:
	var cw := 640
	var chh := 360
	var img := Image.create(cw * 4, chh * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.1, 0.1))
	for i in tags.size():
		var src := Image.load_from_file(out.path_join(tags[i] + ".png"))
		if src == null:
			continue
		src.convert(Image.FORMAT_RGBA8)
		src.resize(cw, chh, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(src, Rect2i(0, 0, cw, chh), Vector2i((i % 4) * cw, (i / 4) * chh))
	img.save_png(out.path_join(nm + ".png"))


## K14: 24 kengällistä hahmoa kävelemässä kameran edessä; vertailuksi samat paljain jaloin.
func _ruutu() -> void:
	for r in row:
		r[1].visible = false
	var res := {}
	for shod in [true, false]:
		var crowd: Array = []
		for i in 24:
			var lk := _look("male" if i % 2 == 0 else "female", Color(0.92, 0.92, 0.9) if shod else Color(0.12, 0.1, 0.08))
			var ch: Node3D = Looks.make(self, lk)
			ch.position = Vector3((i % 8) * 0.9 - 3.2, 0, -2.0 - (i / 8) * 1.5)
			ch.play("Walk")
			crowd.append(ch)
		cam.look_at_from_position(Vector3(0, 1.7, 5.0), Vector3(0, 0.8, -3.0))
		for i in 20:
			await get_tree().process_frame
		var ms: Array[float] = []
		var t0 := Time.get_ticks_usec()
		for i in 60:
			await get_tree().process_frame
			var t := Time.get_ticks_usec()
			ms.append((t - t0) / 1000.0)
			t0 = t
		var sum := 0.0
		for m in ms:
			sum += m
		ms.sort()
		res[shod] = [sum / 60.0, ms[56]]
		print("RUUTU %s ka %.2f ms p95 %.2f ms max %.2f ms (24 hahmoa)" % ["kengat" if shod else "paljain", sum / 60.0, ms[56], ms[59]])
		await RenderingServer.frame_post_draw
		cam.get_viewport().get_texture().get_image().save_png(out.path_join("ruutu_%s.png" % ("kengat" if shod else "paljain")))
		for ch in crowd:
			ch.queue_free()
		await get_tree().process_frame
	if res[true][0] >= RUUTU or res[true][1] >= RUUTU:
		if res[false][0] >= RUUTU or res[false][1] >= RUUTU:
			print("RUUTU raja ylittyy myös paljain jaloin (kone hidas): kenkien lisäkustannus %.2f ms, raja: ei tarkistettu" % (res[true][0] - res[false][0]))
		else:
			print("TESTI VIKA ruutu kengillä ka %.2f ms p95 %.2f ms (raja %.1f)" % [res[true][0], res[true][1], RUUTU])
