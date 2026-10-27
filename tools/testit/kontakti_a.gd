extends Node3D
## Kontaktijärjestelmän (Seat, Contact, Pose.sit) kokeilu: tyttö portaiden ylimmällä askelmalla (SUORA), rantatuolin
## rento istuja (RENTO, nilkat ristissä) ja jakkaralla pöydän ääressä (JAYKKA). Mittaa jalkapohjan (paistettu verkko)
## raon tukipintaan, vartalon raon pöydän reunaan ja käsivarren raon reiteen sekä ottaa kuvat. Lopuksi Sinikka (bikinit), hoikka ja
## kaljamaha istuvat saman pöydän ääressä: painumat luuttain numeroina (K10-K12, K15) ja nousu (K14).
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 tools/testit/kontakti_a.tscn -- <kansio>

const Pose := preload("res://scripts/pose.gd")
const Seat := preload("res://scripts/seat.gd")
const Contact := preload("res://scripts/contact.gd")
const Asento := preload("res://tools/testit/asento.gd")
const Looks := preload("res://scripts/looks.gd")
const Elastic := preload("res://scripts/elastic.gd")
const B := preload("res://scripts/build.gd")

var out := "user://kontakti_a"
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
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(30, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.36, 0.5, 0.28))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40.0
	_run.call_deferred()


func _person(parent: Node3D, shirt: Color, height: float, belly := 0.0) -> Node3D:
	# Verkon paistaminen vaatii, että hahmo on ollut puussa muutaman ruudun
	var p := Looks.make(parent, {"model": "female" if height < 1.7 else "male", "shirt": shirt, "pants": Color(0.2, 0.3, 0.6),
		"hair": "Hair_Long", "height": height, "belly": belly, "skin": Color(0.95, 0.8, 0.7)})
	p.play("Sitting_Idle", 0.0)
	for i in 4:
		await get_tree().process_frame
	return p


func _stairs() -> Array:
	var root := Node3D.new()
	root.position = Vector3(-3, 0, 0)
	add_child(root)
	for k in 3:  # k = 2 ylin; etu +Z
		B.box(root, Vector3(4.0, 0.15, 0.4), Vector3(0, 0.07 + k * 0.15, (2 - k) * 0.4), Color(0.6, 0.6, 0.58))
	Seat.spot(root, {"seat": Vector3(0, 0.445, 0), "front": Vector3(0, 0, 1)})
	var ch := await _person(root, Color(0.85, 0.3, 0.6), 1.62)
	Pose.sit(ch, root, Pose.SUORA, {"jalat_ulos": 1.8})
	return [root, ch]


func _chair(x: float, tilt: float, belly: float) -> Array:
	var root := Node3D.new()
	root.position = Vector3(x, 0, 0)
	add_child(root)
	B.mesh(root, B.boxm(Vector3(0.9, 0.02, 1.8)), Vector3(0, 0.07, 0), Color(0.9, 0.2, 0.2))
	var cc := Color(0.2, 0.5, 0.9)
	B.mesh(root, B.boxm(Vector3(0.5, 0.04, 0.45)), Vector3(0, 0.42, -0.05), cc)
	var lean := Vector3(0, cos(tilt), sin(tilt))
	var pivot := Vector3(0, 0.42, 0.2)
	B.mesh(root, B.boxm(Vector3(0.5, 0.7, 0.04)), pivot + lean * 0.35, cc).rotation.x = tilt
	var n := Vector3(0, sin(tilt), -cos(tilt))
	Seat.spot(root, {"seat": Vector3(0, 0.44, -0.04), "front": Vector3(0, 0, -1),
		"back": {"p": pivot + lean * 0.35 + n * 0.02, "n": n}})
	var ch := await _person(root, Color(0.95, 0.8, 0.2), 1.8, belly)
	Pose.sit(ch, root, Pose.RENTO, {"ristissa": true})
	return [root, ch]


func _table() -> Array:
	var root := Node3D.new()
	root.position = Vector3(3, 0, 0)
	add_child(root)
	B.box(root, Vector3(0.4, 0.45, 0.4), Vector3(0, 0.225, 0), Color(0.7, 0.5, 0.3))
	B.box(root, Vector3(1.2, 0.05, 0.9), Vector3(0, 0.725, 0.62), Color(0.5, 0.35, 0.2))  # reuna z = 0,17
	Seat.spot(root, {"seat": Vector3(0, 0.45, 0), "front": Vector3(0, 0, 1), "ground": 0.0})
	var ch := await _person(root, Color(0.3, 0.6, 0.3), 1.8, 0.7)
	Pose.sit(ch, root, Pose.JAYKKA)
	return [root, ch]


func _run() -> void:
	var sets := [await _stairs(), await _chair(0, 0.5, 0.0), await _chair(1.5, 0.5, 0.6), await _table()]
	for i in 30:
		await get_tree().process_frame
	for s in sets:
		var root: Node3D = s[0]
		var ch: Node3D = s[1]
		_measure(root, ch)
		var d := Seat.of(root)
		var c: Vector3 = root.to_global(d.seat) + Vector3(0, 0.45, 0)
		await Asento.views(cam, out, root.name + str(sets.find(s)), c, 1.9, root.global_transform.basis * d.front)
	var s0: Array = sets[0]
	var d0 := Seat.of(s0[0])
	await Asento.views(cam, out, "portaat_lahi", (s0[0] as Node3D).to_global(d0.seat) + Vector3(0, 0.45, 0.1), 0.7, (s0[0] as Node3D).global_transform.basis * d0.front, false)
	await _vertailu()
	print("KONTAKTI_A valmis ", ProjectSettings.globalize_path(out))
	get_tree().quit()


func _measure(root: Node3D, ch: Node3D) -> void:
	var nm := root.name + str(get_children().find(root))
	var solids := Contact.world_solids(root)
	var prof := Contact.profile(ch, Pose.limb_points)
	print("PROFIILI ", ch.profile_key, " ", prof.foot, " r:", prof.caps.keys().map(func(k: String) -> String: return "%s=%.3f" % [k, prof.caps[k][2]]))
	for lr: String in ["_l", "_r"]:
		var pts := Pose.limb_points(ch, self, ["foot" + lr, "ball" + lr])
		var gap := INF
		var low := Vector3.ZERO
		for q in pts:
			var sup := Contact.support_y(solids, q.x, q.z, q.y + 0.3)
			if sup == -INF:
				sup = 0.0
			if q.y - sup < gap:
				gap = q.y - sup
				low = q
		print("JALKA ", nm, lr, " alin piste ", low, " rako tukeen ", snappedf(gap, 0.0001), " m (paistettu verkko)")
	var torso := Pose.limb_points(ch, self, ["pelvis", "spine_01", "spine_02", "spine_03"])
	var thigh := Pose.limb_points(ch, self, ["thigh_l", "thigh_r", "calf_l", "calf_r"])
	for lr: String in ["_l", "_r"]:
		var cl := Pose.clearance(ch, self, ["upperarm" + lr, "lowerarm" + lr, "hand" + lr], thigh, 4)
		var mn := INF
		for c in cl:
			mn = minf(mn, c[2])
		print("KASI ", nm, lr, " pienin rako jalkaan (luun keskilinja, + paksuus) ", snappedf(mn, 0.001) if mn < INF else "ei pintaa")
	var front: Vector3 = root.global_transform.basis * (Seat.of(root).front as Vector3)
	var tb := -INF
	for q in torso:
		if q.y > 0.9:
			tb = maxf(tb, (q - root.global_position).dot(front))
	print("VARTALO ", nm, " etuin piste ", snappedf(tb, 0.001), " (pöydän reuna 0,17 jos pöytä)")


## Sama pöytä kolmelle hahmolle (x-siirrolla): Sinikka, hoikka ja kaljamaha. look = Looks-sanakirja.
func _table_for(x: float, look: Dictionary) -> Array:
	var root := Node3D.new()
	root.position = Vector3(x, 0, 6)
	add_child(root)
	B.box(root, Vector3(0.4, 0.45, 0.4), Vector3(0, 0.225, 0), Color(0.7, 0.5, 0.3))
	B.box(root, Vector3(1.2, 0.05, 0.9), Vector3(0, 0.725, 0.62), Color(0.5, 0.35, 0.2))  # reuna z = 0,17
	Seat.spot(root, {"seat": Vector3(0, 0.45, 0), "front": Vector3(0, 0, 1), "ground": 0.0})
	var ch := Looks.make(root, look)
	ch.play("Sitting_Idle", 0.0)
	for i in 4:
		await get_tree().process_frame
	Pose.sit(ch, root, Pose.JAYKKA)
	return [root, ch]


func _vertailu() -> void:
	var slim := {"model": "male", "shirt": Color(0.3, 0.6, 0.3), "pants": Color(0.2, 0.3, 0.6), "hair": "Hair_Long", "height": 1.8,
		"belly": 0.0, "skin": Color(0.95, 0.8, 0.7)}
	var fat: Dictionary = slim.duplicate()
	fat["belly"] = 0.9
	var sets := {"sinikka": await _table_for(-3, Looks.sinikka_bikini()), "hoikka": await _table_for(0, slim),
		"kaljamaha": await _table_for(3, fat)}
	for i in 30:
		await get_tree().process_frame
	var res := {}
	for nm: String in sets:
		var root: Node3D = sets[nm][0]
		var ch: Node3D = sets[nm][1]
		print("VERTAILU ", nm, " painuvia laatikoita ", ch.press_boxes.size())
		res[nm] = _painumat(nm, root, ch)
		var d := Seat.of(root)
		await Asento.views(cam, out, "poyta_" + nm, root.to_global(d.seat) + Vector3(0, 0.45, 0), 1.9, root.global_transform.basis * d.front)
	# K12: rinta (spine_03 etu) vs vatsa (spine_01 etu), mm
	var r_s: float = res["sinikka"].get("spine_03 etu", 0.0)
	var v_s: float = res["sinikka"].get("spine_01 etu", 0.0)
	var v_h: float = res["hoikka"].get("spine_01 etu", 0.0)
	var v_k: float = res["kaljamaha"].get("spine_01 etu", 0.0)
	print("K12 Sinikan rinta %.1f mm vs Sinikan vatsa %.1f mm: %s" % [r_s * 1000, v_s * 1000, "OK" if r_s > v_s else "EI"])
	print("K12 vatsa hoikka %.1f mm vs kaljamaha %.1f mm: %s" % [v_h * 1000, v_k * 1000, "OK" if v_k >= v_h else "EI"])
	# K14: nousu -> painuma pois
	for nm: String in sets:
		var ch: Node3D = sets[nm][1]
		ch.clear_ik()
		print("K14 ", nm, " nousun jälkeen laatikoita ", ch.press_boxes.size(), " press_n ", ch.body_mat.get_shader_parameter("press_n"))


## Painuma (Elastic.press) ja jäännös luuttain sekä rako pöydän reunaan (K15). Palauttaa {luu + puoli: suurin painuma m}.
func _painumat(nm: String, root: Node3D, ch: Node3D) -> Dictionary:
	var out_d := {}
	var mi: MeshInstance3D = ch.body_mi
	if mi == null or DisplayServer.get_name() == "headless":
		print("PAINUMA ", nm, ": ei verkkoa (headless)")
		return out_d
	var src: Array = mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = mi.bake_mesh_from_current_skeleton_pose().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var bi: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var bw: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var c0: PackedFloat32Array = src[Mesh.ARRAY_CUSTOM0]
	var per := bi.size() / vs.size()
	var sk: Skin = mi.skin
	var over := 0.0
	var worst_v := -1
	var limb_over := 0.0
	var worst_key := ""
	for v in vs.size():
		var best := 0
		for k in per:
			if bw[v * per + k] > bw[v * per + best]:
				best = k
		var key := str(sk.get_bind_name(bi[v * per + best])) + (" etu" if ns[v].z > 0.3 else " muu")
		var lim := c0[v * 4 + 3]
		var disp := Elastic.press(vs[v], ns[v], lim, ch.press_boxes).distance_to(vs[v])
		out_d[key] = maxf(out_d.get(key, 0.0), disp)
		var rp := _raw_pen(vs[v], ch.press_boxes) - lim if lim > 0.0005 else 0.0  # raja 0 = ei painu (sormet, jalkaterä): LÄPI-testi mittaa
		if not (key.begins_with("spine_") or key.begins_with("pelvis")):
			# Kädet ja jalat lepäävät pinnalla suunnitellusti (esim. kyynärvarsi pöydän päällä on laatikon sisällä pinnan tasolla): LÄPI-testi mittaa
			limb_over = maxf(limb_over, rp)
		elif rp > over:
			over = rp
			worst_v = v
			worst_key = key
	for key: String in ["spine_01 etu", "spine_02 etu", "spine_03 etu"]:
		print("PAINUMA %s %s painuma max %.1f mm" % [nm, key, out_d.get(key, 0.0) * 1000])
	if limb_over > 0.001:
		print("PAINUMA %s raajat: raakasyvyys laatikossa %.1f mm (tiedoksi, ei vika)" % [nm, limb_over * 1000])
	if over > 0.001:
		print("KONTAKTI JÄÄ ", nm, " tunkeuma yli painumarajan ", snappedf(over * 1000, 0.1), " mm")
		# Diagnostiikka: pahin verteksi, sen laatikko (0 = istuin/noja/pöytä järjestyksessä contacts()-listalta) ja reunaetäisyys
		var wp: Vector3 = vs[worst_v]
		var bi_i := 0
		for b in ch.press_boxes:
			var bq: Vector3 = (b[0] as Transform3D) * wp
			var bh: Vector3 = b[1]
			if absf(bq.x) < bh.x and absf(bq.z) < bh.z and bq.y >= -bh.y:
				print("  JAANNOS %s luu %s laatikko %d (yläpinnan normaali y %.2f, h %s) syvyys %.1f mm, reunaan x %.1f z %.1f mm, raja %.1f mm" % [
					nm, worst_key, bi_i, (b[0] as Transform3D).basis.y.y, bh, (bh.y - bq.y) * 1000, (bh.x - absf(bq.x)) * 1000,
					(bh.z - absf(bq.z)) * 1000, c0[worst_v * 4 + 3] * 1000])
			bi_i += 1
	# K15: etuin vartalon piste pöydän reunaan (0,17 solmun etusuunnassa)
	var front: Vector3 = root.global_transform.basis * (Seat.of(root).front as Vector3)
	for b: String in ["spine_01", "spine_03"]:
		var tb := -INF
		for q in Pose.limb_points(ch, self, [b]):
			tb = maxf(tb, (q - root.global_position).dot(front))
		print("POYTA %s %s etuin piste %.3f, rako reunaan %.1f mm" % [nm, b, tb, (0.17 - tb) * 1000])
	return out_d


## Syvin tunkeuma laatikoiden jalanjäljessä ilman deep_fadea (rehellinen mittari: reunaa vasten oleva syvä verteksi ei häviä).
func _raw_pen(p: Vector3, boxes: Array) -> float:
	var best := 0.0
	for b in boxes:
		var q: Vector3 = (b[0] as Transform3D) * p
		var h: Vector3 = b[1]
		if absf(q.x) < h.x and absf(q.z) < h.z and q.y >= -h.y:
			best = maxf(best, h.y - q.y)
	return best
