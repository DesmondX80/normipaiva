extends Node3D
## Rintojen mitat paistetusta vartaloverkosta (vaakaleikkeet kolmioista, kädet pois), cm kuten rintaliivikoossa:
## rinnanympärys rinnan korkeimmalta kohdalta ja alaympärys rinnan alta (mittanauha = vaakaleikkeen kupera verho),
## ero (DD ≈ 20–22 cm) ja ulkonema rintakehästä (rinnan kärki - etupinta rinnan alla). Sinikka (bikinit) ja vertailuna
## Mirkku (bust 1.4), molemmat Idle-asennossa. Kuvat edestä, sivulta ja vinosti rinnan korkeudelta.
## aja.sh tscn tools/testit/sinikka_mitat.tscn

const Pose := preload("res://scripts/pose.gd")
const Looks := preload("res://scripts/looks.gd")

var out := "user://sinikka_mitat"
var cam: Camera3D


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
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 30.0
	var sk := Looks.make(self, Looks.sinikka_bikini())
	var mir := Looks.make(self, Looks.MIRKKU)
	mir.position = Vector3(3, 0, 0)
	var piha := Looks.make(self, Looks.SINIKKA)  # regressio: pihan glam-Sinikan aurinkolasit kasvoilla (add_glam)
	piha.position = Vector3(-8, 0, 0)
	# Lisäargumentti "--bust=2.2,2.6": samat mitat Sinikalle näillä bust-arvoilla (piilossa, ei kuviin).
	var extra := []
	for a in args:
		if a.begins_with("--bust="):
			for v in a.trim_prefix("--bust=").split(","):
				var lk: Dictionary = Looks.sinikka_bikini()
				lk.bust = float(v)
				var c := Looks.make(self, lk)
				c.position = Vector3(-3 * (extra.size() + 1), 0, 0)
				extra.append(c)
	for c in [sk, mir, piha] + extra:
		c.play("Idle", 0.0)
		c.anim.speed_scale = 0.0  # sama asento joka ajossa (mittaus toistuu)
	for i in 6:
		await get_tree().process_frame
	for c in [sk, mir, piha] + extra:
		c.anim.seek(0.0, true)
	await get_tree().process_frame
	_measure(sk, "Sinikka")
	_measure(mir, "Mirkku")
	for c in extra:
		_measure(c, "Sinikka_bust%.2f" % c.body_shape.bust)
		c.visible = false
	mir.visible = false
	piha.visible = false
	var y := 1.25
	var b := Vector3(0, 1.15, -0.05)  # rinnan korkeus (mitattu kärki y ≈ 1,14–1,15)
	for v in [["edesta", Vector3(0, y + 0.05, -1.6), Vector3(0, y - 0.05, 0)], ["sivulta", Vector3(1.6, y + 0.05, 0), Vector3(0, y - 0.05, 0)],
			["vino", Vector3(1.0, y + 0.15, -1.2), Vector3(0, y - 0.05, 0)], ["lahi_edesta", b + Vector3(0, 0.05, -0.75), b],
			["lahi_sivulta", b + Vector3(0.75, 0.05, 0), b], ["lahi_vino", b + Vector3(0.5, 0.15, -0.55), b]]:
		cam.look_at_from_position(v[1], v[2])
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("rinnat_%s.png" % v[0]))
	# Pihan Sinikan kasvot lähikuvina edestä ja vinosti: lasit silmillä, sangat korville (ei takaraivolla).
	sk.visible = false
	piha.visible = true
	var hd: Vector3 = piha.to_global(piha.bone_position("Head")) + Vector3(0, 0.08, 0)
	# Edestä ja vinosti lierin alta (silmien korkeudelta lieri peittää kasvot).
	for v in [["piha_kasvot_edesta", hd + Vector3(0, -0.2, -0.55)], ["piha_kasvot_vino", hd + Vector3(0.35, -0.18, -0.45)],
			["piha_kasvot_sivulta", hd + Vector3(0.6, 0.03, 0)], ["piha_kasvot_lahi", hd + Vector3(0, 0.0, -0.32)]]:
		cam.look_at_from_position(v[1], hd)
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % v[0]))
	var sh := piha.find_child("Aurinkolasit", true, false) as Node3D
	var face := (piha.global_transform.basis * Vector3.FORWARD).normalized()  # hahmon etu -Z
	var ahead: float = (sh.global_position - piha.to_global(piha.bone_position("Head"))).dot(face) if sh != null else -INF
	print("PIHA lasit pään edessä %.3f m %s" % [ahead, "OK" if ahead > 0.03 else "TESTI VIKA lasit eivät ole kasvoilla"])
	print("kuvat: ", out)
	get_tree().quit()


func _measure(ch: Node3D, nm: String) -> void:
	var mi: MeshInstance3D = ch.body_mi
	var src: Dictionary = Pose._src_arrays(mi)
	var baked := mi.bake_mesh_from_current_skeleton_pose()
	if src.is_empty() or baked == null:
		print("MITAT ", nm, ": ei verkkoa, ei tarkistettu")
		return
	var a: Array = baked.surface_get_arrays(0)
	var bv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var xf := ch.global_transform.affine_inverse() * mi.global_transform  # hahmon avaruus: etu -Z, metreinä
	# Kädet pois (ne roikkuvat rinnan korkeudella vartalon vieressä): kärkipisteen vahvin luu.
	var skin: Skin = mi.skin
	var arm := {}
	for b in skin.get_bind_count():
		var bn := str(skin.get_bind_name(b))
		if bn == "":
			bn = ch.skeleton.get_bone_name(skin.get_bind_bone(b))
		for w in ["arm", "hand", "thumb", "index", "middle", "ring", "pinky"]:
			if bn.contains(w):
				arm[b] = true
	var per: int = src.per
	var bi: PackedInt32Array = src.bi
	var bw: PackedFloat32Array = src.bw
	var vs := PackedVector3Array()
	var ok := PackedByteArray()
	vs.resize(bv.size())
	ok.resize(bv.size())
	for v in bv.size():
		vs[v] = xf * bv[v]
		var best := 0
		for k in per:
			if bw[v * per + k] > bw[v * per + best]:
				best = k
		ok[v] = 0 if arm.has(bi[v * per + best]) else 1
	# Profiili: kupera ympärys ja etupinta (-z max) vaakaleikkeistä 0,5 cm välein.
	var prof := []
	for i in 121:
		var y := 0.9 + 0.005 * i
		var sl := PackedVector2Array()
		var front := -INF
		for t in range(0, idx.size(), 3):
			if ok[idx[t]] == 0 or ok[idx[t + 1]] == 0 or ok[idx[t + 2]] == 0:
				continue
			for e in 3:
				var p0: Vector3 = vs[idx[t + e]]
				var p1: Vector3 = vs[idx[t + (e + 1) % 3]]
				if (p0.y - y) * (p1.y - y) < 0.0:
					var q := p0.lerp(p1, (y - p0.y) / (p1.y - p0.y))
					sl.append(Vector2(q.x, q.z))
					if absf(q.x) < 0.2:
						front = maxf(front, -q.z)
		prof.append([y, _hull_len(sl), front])
	var tall := -INF
	for p in vs:
		tall = maxf(tall, p.y)
	# Kaula = kapein leike 0,75–0,9 pituudesta; rinnan kärki = etummaisin leike 12–35 cm kaulan alla.
	var neck := 0
	for i in prof.size():
		var y: float = prof[i][0]
		if y > 0.75 * tall and y < 0.9 * tall and (neck == 0 or prof[i][1] < prof[neck][1]):
			neck = i
	var top := -1
	for i in prof.size():
		var y: float = prof[i][0]
		if y > prof[neck][0] - 0.35 and y < prof[neck][0] - 0.12 and (top < 0 or prof[i][2] > prof[top][2]):
			top = i
	# Rinnan alaraja (poimu): alaspäin kärjestä jyrkimmän vetäytymisen ohi, kunnes etupinta lakkaa vetäytymästä
	# (alle 1 mm / 5 mm).
	var steep := top
	for i in range(top, maxi(top - 30, 1), -1):
		if prof[i][2] - prof[i - 1][2] > prof[steep][2] - prof[steep - 1][2]:
			steep = i
	var under := steep - 1
	while under > 1 and prof[under - 1][2] < prof[under][2] - 0.001:
		under -= 1
	print("MITAT %s pituus %.3f m, kaula y %.3f" % [nm, tall, prof[neck][0]])
	var s := ""
	for i in range(maxi(under - 6, 0), mini(top + 8, prof.size())):
		s += " %.3f:%.1f/%.1f" % [prof[i][0], prof[i][1] * 100.0, prof[i][2] * 100.0]
	print("MITAT ", nm, " profiili y:ympärys/etu cm", s)
	var bust: float = prof[top][1] * 100.0
	var ub: float = prof[under][1] * 100.0
	print("MITAT %s rinnanympärys %.1f cm (y %.3f), alaympärys %.1f cm (y %.3f), ero %.1f cm, ulkonema %.1f cm" % [
		nm, bust, prof[top][0], ub, prof[under][0], bust - ub, (prof[top][2] - prof[under][2]) * 100.0])


## Kuperan verhon piiri (mittanauha kulkee rintojen välin yli).
static func _hull_len(p: PackedVector2Array) -> float:
	if p.size() < 3:
		return 0.0
	var h := Geometry2D.convex_hull(p)
	var l := 0.0
	for i in h.size() - 1:
		l += h[i].distance_to(h[i + 1])
	return l
