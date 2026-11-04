extends Node3D
## S2 yliannos (scripts/rikos/yliannos.gd): makaava teini kaukalon laidalla oikealla paikallaan, ensihoitajat, ambulanssi
## ja naloksoni-nenäsuihke. Mittaukset: alin ihopiste maahan (vähintään 0,005 m), selän rako, ensihoitajien rako ihosta
## (vähintään 0,4 m), Asento.solids (läpimenot) ja kuvat edestä/päädyistä/ylhäältä (Asento.views) sekä lähikuvat.
## Ajo: tools/testit/aja.sh tscn tools/testit/yliannos_kuvat.tscn

const Yliannos := preload("res://scripts/rikos/yliannos.gd")
const Teinit := preload("res://scripts/saloinen_teinit.gd")
const Asento := preload("res://tools/testit/asento.gd")
const Terrain := preload("res://scripts/terrain.gd")
const M := preload("res://scripts/map_data.gd")
const B := preload("res://scripts/build.gd")

var out := "user://yliannos_kuvat"
var cam: Camera3D
var ring: Node3D


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
	var kc := M.w2(M.KAUKALO)
	_ground_patch(Vector2(kc.x, kc.y) + Vector2(20.0, 0).rotated(-Teinit.RINK_YAW), 30.0)
	ring = Teinit.new()
	add_child(ring)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 45.0
	_run.call_deferred()


## Maastopala Terrain.h:n mukaan (verkko + törmäys maaston kerroksessa, jota Asento._ground lukee).
func _ground_patch(c: Vector2, half: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(half * 2.0)
	var faces := PackedVector3Array()
	for i in n:
		for j in n:
			var x0 := c.x - half + i
			var z0 := c.y - half + j
			var q := [Vector3(x0, 0, z0), Vector3(x0 + 1, 0, z0), Vector3(x0, 0, z0 + 1), Vector3(x0 + 1, 0, z0 + 1)]
			for k in 4:
				q[k].y = Terrain.h(q[k].x, q[k].z)
			for v in [q[0], q[1], q[2], q[1], q[3], q[2]]:
				st.add_vertex(v)
				faces.append(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = B.mat(Color(0.42, 0.55, 0.3))
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = Terrain.COLLISION_LAYER
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _run() -> void:
	for i in 20:
		await get_tree().process_frame
	var bad := 0
	# Teini samaan paikkaan kuin pelissä (yliannos.gd aloita).
	var c: Vector3 = ring.center()
	var wp: Vector3 = c + Yliannos.PAIKKA.rotated(Vector3.UP, ring.rotation.y)
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = Vector3(wp.x, Terrain.h(wp.x, wp.z), wp.z)
	holder.rotation.y = ring.rotation.y + 0.9
	var teen := Yliannos.build_teen(holder)
	for i in 6:
		await get_tree().process_frame
	var mit := Yliannos.lay_down(holder, teen)
	print("YLIANNOS teini: %s (alin ihopiste maahan, selän alin maahan)" % [mit])
	if float(mit.get("alin", -1.0)) < 0.004:
		bad += 1
		print("TESTI VIKA teini maan sisällä: alin %s" % mit.get("alin"))
	print("YLIANNOS ringin keskeltä %.2f m (puhealueet erillään: > %.1f)" % [Vector2(wp.x - c.x, wp.z - c.z).length(), 3.2 + Yliannos.PUHE_R])
	# Raajojen korkeus maasta pitkin raajaa (luut).
	for chain in [["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"], ["thigh_l", "calf_l", "foot_l"],
			["thigh_r", "calf_r", "foot_r"], ["pelvis", "spine_02", "Head"]]:
		var row := []
		for bn in chain:
			var g: Vector3 = teen.global_transform * teen.bone_position(bn)
			row.append("%s %.3f" % [bn, g.y - Terrain.h(g.x, g.z)])
		print("YLIANNOS luu maasta: ", ", ".join(row))
	var n := Asento.solids(teen, self, 2.0)
	print("YLIANNOS teini läpimenoja ", n)
	bad += n
	var front: Vector3 = Vector3(1, 0, 0).rotated(Vector3.UP, holder.rotation.y)  # teinin oikea kylki (kasvot ylös, pää +Z)
	var mid: Vector3 = holder.global_position + Vector3(0, 0.15, 0)
	await Asento.views(cam, out, "teini", mid, 1.9, front, false)
	await _shot("teini_lahi", mid + front * 1.4 + Vector3(0, 1.1, 0) + holder.global_basis.z * 0.9, mid + holder.global_basis.z * 0.5)
	await _shot("teini_pelikamera", mid + (front * 0.6 - holder.global_basis.z).normalized() * 5.5 + Vector3(0, 3.2, 0), mid)
	# Ensihoitajat ja ambulanssi.
	var md := Yliannos.place_medics(holder, teen)
	print("YLIANNOS ensihoitajien rako ihosta: %s m (vähintään 0,4)" % [md.rako])
	for r in md.rako:
		if float(r) < 0.4:
			bad += 1
			print("TESTI VIKA ensihoitaja liian lähellä: %s" % r)
	for i in 4:
		await get_tree().process_frame
	for ch in holder.get_children():
		if ch != teen and ch.has_method("play"):
			var nm := Asento.solids(ch, self, 2.0)
			print("YLIANNOS ensihoitaja läpimenoja ", nm)
			bad += nm
	await Asento.views(cam, out, "ensihoitajat", mid, 2.6, front, false)
	var ambu := Node3D.new()
	add_child(ambu)
	var ap: Vector3 = holder.global_position + front * 9.0
	ambu.global_position = Vector3(ap.x, Terrain.h(ap.x, ap.z), ap.z)
	ambu.rotation.y = B.yaw_to(-(holder.global_position - ambu.global_position))
	Yliannos.tilt_to_ground(ambu)
	var valot := Yliannos.build_ambulance(ambu)
	print("YLIANNOS ambulanssin valoja %d" % valot.size())
	for i in 4:
		await get_tree().process_frame
	await _shot("kohtaus", mid + (-front * 0.4 + holder.global_basis.z).normalized() * 9.0 + front * 4.0 + Vector3(0, 4.0, 0), mid + front * 4.0)
	var ab := ambu.global_basis
	var ac := ambu.global_position + Vector3(0, 1.3, 0)
	await _shot("ambulanssi_taka", ac + ab.z * 7.5 + ab.x * 3.5 + Vector3(0, 0.8, 0), ac)
	await _shot("ambulanssi_sivu", ac + ab.x * 7.0 - ab.z * 1.0 + Vector3(0, 0.4, 0), ac)
	await _shot("ambulanssi_toinen_sivu", ac - ab.x * 7.0 - ab.z * 2.5 + Vector3(0, 0.6, 0), ac)
	ambu.visible = false
	# Nenäsuihke: pystyssä ja kyljellään nurmella, lähikuva (oikea koko n. 4,5 cm).
	var sp := Node3D.new()
	add_child(sp)
	var spp := c + Vector3(-3.0, 0, -3.0)
	sp.global_position = Vector3(spp.x, Yliannos.ground_y(sp, spp.x, spp.z) + 0.001, spp.z)
	Yliannos.build_spray(sp)
	var lying := Yliannos.build_spray(sp)
	var lg := sp.global_position + Vector3(0.07, 0, 0.02)
	lying.global_position = Vector3(lg.x, Yliannos.ground_y(sp, lg.x, lg.z) + Yliannos.SUIHKE_R, lg.z)
	lying.rotation = Vector3(PI / 2.0, 0.6, 0)
	cam.fov = 20.0
	await _shot("suihke", sp.global_position + Vector3(0.12, 0.09, 0.22), sp.global_position + Vector3(0.03, 0.02, 0.0))
	await _shot("suihke_ylhaalta", sp.global_position + Vector3(0.03, 0.3, 0.001), sp.global_position + Vector3(0.03, 0.0, 0.0))
	print("YLIANNOS kuvat valmiit, %d vikaa" % bad)
	get_tree().quit()


func _shot(name: String, from: Vector3, to: Vector3) -> void:
	cam.look_at_from_position(from, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.FORWARD)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("kuva ", name)
