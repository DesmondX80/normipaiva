extends Node3D
## Hahmojen anatomia (scripts/anatomia.gd): lähikuvat kasvoista, käsistä, jaloista ja vartalosta pelaajalle, Sinikalle,
## Päiville ja Juntille, 4 kulmaa per osa, Idle-asennossa ja samalla kameralla kuin .claude/tyo/hahmot-anatomia/02-nykytila-kuvat.
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 tools/testit/anatomia_kuvat.tscn -- <kansio> [valinnat]
## Valinnat: --osa=a|b|c|d|kaikki (a kädet, b jalat, c kasvot, d vartalo; oletus kaikki),
##   --anat=0|1 (look.anat; 0 = ennen/jälkeen-vertailu, oletus 1), --anim=Idle|Walk|Sitting_Idle|Dance (oletus Idle),
##   --hahmot=pelaaja,sinikka,paivi,juntti, --luokka (jalkaterän luokka 3 magentalla: mittaa sukkavuoto/raja),
##   --paljas=0 (ei shoe=paljas-avainta: vanha shoes-väri), --kengat (näytä kengät: look.shoe lenkkari).
## Tulostaa ANAT-rivit (jalan alin y, kämmenen ja jalan säteet, sormen ja varpaan paksuus) ja kuvat <hahmo>_<osa>_<kulma>.png.

const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const Pose := preload("res://scripts/pose.gd")
const Contact := preload("res://scripts/contact.gd")

var out := "user://anatomia"
var cam: Camera3D
var osa := "kaikki"
var anat := true
var anim := "Idle"
var luokka := false
var paljas := true
var kengat := false
var names := ["pelaaja", "sinikka", "paivi", "juntti"]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and not a[0].begins_with("--"):
		out = a[0]
	for s in a:
		if s.begins_with("--osa="):
			osa = s.substr(6)
		elif s.begins_with("--anat="):
			anat = s.substr(7) != "0"
		elif s.begins_with("--anim="):
			anim = s.substr(7)
		elif s.begins_with("--hahmot="):
			names = s.substr(9).split(",")
		elif s == "--luokka":
			luokka = true
		elif s == "--paljas=0":
			paljas = false
		elif s == "--kengat":
			kengat = true
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	add_child(sun)
	var s2 := DirectionalLight3D.new()
	s2.rotation_degrees = Vector3(-30, 150, 0)
	s2.light_energy = 0.6
	add_child(s2)
	B.mesh(self, B.boxm(Vector3(40, 0.1, 40)), Vector3(0, -0.05, 0), Color(0.6, 0.6, 0.6))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_run.call_deferred()


func _look(n: String) -> Dictionary:
	var l: Dictionary
	match n:
		"pelaaja": l = Looks.player()
		"sinikka": l = Looks.sinikka_bikini()
		"paivi": l = Looks.PAIVI.duplicate()
		_: l = Looks.JUNTTI.duplicate()
	if n != "sinikka":
		if kengat:
			l["shoe"] = "lenkkari"
		elif paljas:
			l["shoe"] = "paljas"
	l["anat"] = anat
	return l


func _run() -> void:
	for n in names:
		var c: Node3D = Looks.make(self, _look(n))
		if luokka:
			# Luokan 3 alue magentalla: väri foot_col-polulla (mode 2) tai, vanhalla koodilla, shoes-värillä (maalattu jalka).
			c.body_mat.set_shader_parameter("shoes", Color(1, 0, 1))
			c.body_mat.set_shader_parameter("foot_col", Color(1, 0, 1))
			if c.body_mat.get_shader_parameter("bare_foot_mode") != null:
				c.body_mat.set_shader_parameter("bare_foot_mode", 2)
		c.restart(anim, 0.0, 1.0)
		for i in 8:
			await get_tree().process_frame
		_measure(n, c)
		await _shots(n, c)
		c.queue_free()
	print("valmis ", out)
	get_tree().quit()


func _g(c: Node3D, b: String) -> Vector3:
	return c.to_global(c.bone_position(b))


func _measure(n: String, c: Node3D) -> void:
	for lr in ["l", "r"]:
		var pts := Pose.limb_points(c, self, ["foot_" + lr, "ball_" + lr])
		var lo := INF
		for p in pts:
			lo = minf(lo, p.y)
		print("ANAT %s anat=%s jalka_%s alin y %.4f m (%d pistettä)" % [n, anat, lr, lo if pts.size() > 0 else NAN, pts.size()])
	var prof := Contact.profile(c, Pose.limb_points)
	var hl: Array = prof.caps["hand_l"]
	var hr: Array = prof.caps["hand_r"]
	print("ANAT %s anat=%s kämmen l r %.4f pituus %.4f, r %.4f pituus %.4f, pää r %.4f, jalka %s, mitattu %s" % [n, anat, hl[2], hl[3],
		hr[2], hr[3], (prof.caps["Head"] as Array)[2], str(prof.get("foot", {})), prof.measured])
	# Luokkien lepo-y (UV2.y): jalkaterän (3) ylin ja housujen (2) alin piste, p5/p95 jalan ja nilkan rajan mittaukseen.
	var arr: Array = c.body_mi.mesh.surface_get_arrays(0)
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	var y3: Array = []
	var y2lo := INF
	for v in cols.size():
		var k := roundi(cols[v].r * 4.0)
		if k == 3:
			y3.append(uv2[v].y)
		elif k == 2:
			y2lo = minf(y2lo, uv2[v].y)
	y3.sort()
	if y3.size() > 0:
		print("ANAT %s luokka3 lepo-y min %.4f p50 %.4f p95 %.4f max %.4f (%d pistettä), luokka 2 alin %.4f" % [n, y3[0], y3[y3.size() / 2],
			y3[int(y3.size() * 0.95)], y3[-1], y3.size(), y2lo])
	var nk: Array = prof.caps.get("neck_01", [])
	if nk.size() > 2:
		print("ANAT %s anat=%s kaula r %.4f" % [n, anat, nk[2]])
	print("ANAT %s anat=%s solmut: %s" % [n, anat, ", ".join((c.skeleton.get_children() as Array).map(func(m: Node) -> String:
		return "%s%s" % [m.name, "(%d)" % (m as MeshInstance3D).mesh.get_faces().size() if m is MeshInstance3D and (m as MeshInstance3D).mesh != null else ""]))])


func _shot(n: String, c: Node3D, target: Vector3, dist: float, yaw_deg: float, fov: float, pitch_deg := 0.0) -> void:
	cam.fov = fov
	var fwd := (_g(c, "ball_l") - _g(c, "foot_l"))
	fwd.y = 0
	fwd = fwd.normalized()
	var d := fwd.rotated(Vector3.UP, deg_to_rad(yaw_deg))
	d = d.rotated(d.cross(Vector3.UP).normalized(), deg_to_rad(pitch_deg)) if pitch_deg != 0.0 else d
	cam.global_position = target + d * dist
	cam.look_at(target, Vector3.UP if absf(pitch_deg) < 70 else fwd)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])


func _shots(n: String, c: Node3D) -> void:
	var all := osa == "kaikki"
	if all or osa == "c":  # kasvot: edestä, vinosti, sivulta, takaa
		var head_c := _g(c, "Head") + Vector3(0, 0.08, 0)
		await _shot(n + "_kasvot_etu", c, head_c, 1.0, 0, 20)
		await _shot(n + "_kasvot_vino", c, head_c, 1.0, 45, 20)
		await _shot(n + "_kasvot_sivu", c, head_c, 1.0, 90, 20)
		await _shot(n + "_kasvot_taka", c, head_c, 1.0, 180, 20)
	if all or osa == "a":  # kädet: oikea edestä ja sivulta, vasen edestä, oikea ylhäältä
		var hr := _g(c, "hand_r") + Vector3(0, -0.07, 0)
		var hl := _g(c, "hand_l") + Vector3(0, -0.07, 0)
		await _shot(n + "_kasi_r_etu", c, hr, 0.9, 0, 18)
		await _shot(n + "_kasi_r_sivu", c, hr, 0.9, -90, 18)
		await _shot(n + "_kasi_l_etu", c, hl, 0.9, 0, 18)
		await _shot(n + "_kasi_r_yla", c, _g(c, "hand_r"), 0.8, 0, 18, 70)
	if all or osa == "b":  # jalat: ylhäältä, edestä, sivulta, vinosti
		var ft := (_g(c, "foot_l") + _g(c, "ball_l")) * 0.5
		await _shot(n + "_jalka_yla", c, ft, 0.8, 0, 22, 80)
		await _shot(n + "_jalka_etu", c, ft + Vector3(0, 0.03, 0), 0.8, 0, 22, 10)
		await _shot(n + "_jalka_sivu", c, ft, 0.8, 90, 22)
		await _shot(n + "_jalka_vino", c, ft, 0.8, 45, 22, 25)
	if all or osa == "d":  # vartalo ja kaula: edestä, sivulta, takaa, vinosti; kaula lähikuvana
		var pv := _g(c, "pelvis")
		var mid := Vector3(pv.x, pv.y + 0.1, pv.z)
		await _shot(n + "_vartalo_etu", c, mid, 4.2, 0, 22)
		await _shot(n + "_vartalo_sivu", c, mid, 4.2, 90, 22)
		await _shot(n + "_vartalo_taka", c, mid, 4.2, 180, 22)
		await _shot(n + "_vartalo_vino", c, mid, 4.2, 45, 22)
		var nk := (_g(c, "neck_01") + _g(c, "Head")) * 0.5 + Vector3(0, 0.05, 0)
		await _shot(n + "_kaula_etu", c, nk, 1.5, 0, 20)
