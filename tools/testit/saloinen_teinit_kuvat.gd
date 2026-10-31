extends Node3D
## Saloisten kaukalon iltateinit (scripts/saloinen_teinit.gd) ja laavun teinien rauhantila (laavu_guard.gd peaceful)
## erikseen: maastopala ja kaukalon itälaita oikealla paikallaan, kuvat edestä/päädyistä/ylhäältä (Asento.views),
## pelikameralta ja lähikuvat; läpimenotarkistus (Asento.solids) teineille, kellonaika ja rauhantilan mittarit.
## Ajo: tools/testit/aja.sh tscn tools/testit/saloinen_teinit_kuvat.tscn

const Teinit := preload("res://scripts/saloinen_teinit.gd")
const LaavuGuard := preload("res://scripts/laavu_guard.gd")
const Asento := preload("res://tools/testit/asento.gd")
const Terrain := preload("res://scripts/terrain.gd")
const M := preload("res://scripts/map_data.gd")
const B := preload("res://scripts/build.gd")

var out := "user://saloinen_teinit"
var cam: Camera3D
var t: Node3D
var player: Node3D


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
	_ground_patch(Vector2(kc.x, kc.y) + Vector2(15.5, 0).rotated(-Teinit.RINK_YAW), 24.0)
	_rink_side(kc)
	var lc := M.w(M.LAAVU)
	_ground_patch(Vector2(lc.x, lc.z), 20.0)
	player = Node3D.new()
	add_child(player)
	t = Teinit.new()
	add_child(t)
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


## Kaukalon itälaita ja valotolpat kuten world.gd (vain yhteyskuvaa varten).
func _rink_side(kc: Vector2) -> void:
	var rink := Node3D.new()
	rink.position = Vector3(kc.x, Terrain.h(kc.x, kc.y), kc.y)
	rink.rotation.y = Teinit.RINK_YAW
	add_child(rink)
	B.mesh(rink, B.boxm(Vector3(0.12, 1.1, 42.0)), Vector3(12.0, 0.55, 0), Color(0.92, 0.9, 0.82))
	B.mesh(rink, B.boxm(Vector3(0.16, 0.1, 42.0)), Vector3(12.0, 1.12, 0), Color(0.8, 0.2, 0.12))
	B.mesh(rink, B.boxm(Vector3(12.0, 0.03, 50.0)), Vector3(6.0, 0.03, 0), Color(0.62, 0.6, 0.55))
	for z in [-16.7, 16.7]:
		B.mesh(rink, B.cyl(0.1, 0.14, 9.0, 8), Vector3(13.5, 4.5, z), Color(0.55, 0.56, 0.58))


func _run() -> void:
	for i in 30:
		await get_tree().process_frame
	var c: Vector3 = t.center()
	var front: Vector3 = Vector3(1, 0, 0).rotated(Vector3.UP, Teinit.RINK_YAW)  # kaukalosta poispäin
	print("TEINIT paikka ", c.snapped(Vector3.ONE * 0.01), " maa ", snappedf(Terrain.h(c.x, c.z), 0.01))
	# Kellonaika: 20–01 paikalla, muuten ei.
	var ok_t := true
	for pair in [[19 * 60 + 59, false], [20 * 60, true], [23 * 60, true], [30, true], [60, false], [12 * 60, false]]:
		if Teinit.on_time(pair[0]) != pair[1]:
			ok_t = false
			print("TESTI VIKA kellonaika %d -> %s" % [pair[0], Teinit.on_time(pair[0])])
	print("TEINIT kellonaika ", "OK" if ok_t else "VIKA")
	# Repliikeissä ei Vaalaa/Siitaria.
	var bad_w := 0
	for k in ["KAUKALO_HELLO", "KAUKALO_CHAT", "KAUKALO_EI_KAMAA", "KAUKALO_HYVA", "KAUKALO_MIETO", "KAUKALO_EI_OSTA",
			"LAAVU_HELLO", "LAAVU_CHAT", "LAAVU_HYVA", "LAAVU_MIETO", "LAAVU_EI_OSTA", "PEACE",
			"KAUKALO_KIINNI", "KAUKALO_PAKO", "LAAVU_KIINNI", "LAAVU_PAKO"]:
		var v: Variant = (t.get_script() as GDScript).get_script_constant_map()[k]
		for line in (v if v is Array else [v]):
			if (line as String).to_lower().contains("vaala") or (line as String).to_lower().contains("siitari"):
				bad_w += 1
				print("TESTI VIKA repliikki ", k, ": ", line)
	print("TEINIT repliikit Vaala/Siitari: ", bad_w)
	# Läpimenot ja jalkojen rako maahan.
	var bad := 0
	for ch: Node3D in t.teens:
		bad += Asento.solids(ch, self, 2.0)
	print("TEINIT läpimenoja ", bad)
	await Asento.views(cam, out, "kaukalo", c + Vector3(0, 0.9, 0), 3.0, front, false)
	await _shot("kaukalo_yhteys", c + front * 11.0 + front.cross(Vector3.UP) * 6.0 + Vector3(0, 5.0, 0), c + Vector3(0, 0.8, 0))
	await _shot("kaukalo_lahi", c + front * 3.2 + Vector3(0, 1.6, 0), c + Vector3(0, 1.1, 0))
	await _shot("kaukalo_maa", c + front * 1.6 + front.cross(Vector3.UP) * 1.0 + Vector3(0, 0.8, 0), c + Vector3(-0.2, 0.05, 0.1).rotated(Vector3.UP, Teinit.RINK_YAW))
	# Pelaaja lähestyy: teinit kääntyvät häneen.
	player.global_position = c + front * 4.0
	for i in 60:
		await get_tree().process_frame
	var faced := 0
	for ch: Node3D in t.teens:
		var fwd := -ch.global_transform.basis.z
		var to_p := player.global_position - ch.global_position
		to_p.y = 0
		if fwd.normalized().dot(to_p.normalized()) > 0.8:
			faced += 1
	print("TEINIT kääntyvät pelaajaan: %d/3 %s" % [faced, "OK" if faced == 3 else "(target ei asetettu)"])
	t.target = player
	for i in 90:
		await get_tree().process_frame
	faced = 0
	for ch: Node3D in t.teens:
		var fwd := -ch.global_transform.basis.z
		var to_p := player.global_position - ch.global_position
		to_p.y = 0
		if fwd.normalized().dot(to_p.normalized()) > 0.8:
			faced += 1
	print("TEINIT kääntyvät pelaajaan: %d/3 %s" % [faced, "OK" if faced == 3 else "TESTI VIKA"])
	bad = 0
	for ch: Node3D in t.teens:
		bad += Asento.solids(ch, self, 2.0)
	print("TEINIT läpimenoja pelaajaan kääntyneenä ", bad)
	await _shot("kaukalo_pelaaja", player.global_position + Vector3(0, 1.7, 0) + front * 2.5, c + Vector3(0, 1.2, 0))
	t.set_on(false)
	await get_tree().process_frame
	print("TEINIT set_on(false): näkyy ", t.visible)
	t.set_on(true)
	await _laavu()
	get_tree().quit()


func _laavu() -> void:
	var lc := M.w(M.LAAVU)
	lc.y = Terrain.h(lc.x, lc.z)
	var tgt := Node3D.new()
	add_child(tgt)
	tgt.global_position = lc + Vector3(10, 0, 0)
	tgt.global_position.y = Terrain.h(tgt.global_position.x, tgt.global_position.z)
	var g := LaavuGuard.new()
	g.kind = "teens"
	g.center = lc
	g.target = tgt
	g.peaceful = true
	var hits := [0]
	g.challenge.connect(func(_k: String, _d: Vector3) -> void: hits[0] += 1)
	add_child(g)
	for i in 240:
		await get_tree().physics_frame
	var d := g.boss_pos() - tgt.global_position
	d.y = 0
	print("LAAVU peaceful: etäisyys pelaajaan %.2f m (tavoite %.1f), haasteita %d, kupla '%s' %s" % [d.length(), LaavuGuard.PEACE_STOP,
		hits[0], g._bubble.text, "OK" if hits[0] == 0 and absf(d.length() - LaavuGuard.PEACE_STOP) < 0.4 else "TESTI VIKA"])
	await _shot("laavu_peaceful", tgt.global_position + Vector3(0, 1.7, 0) + Vector3(2.5, 0.5, 2.5), g.boss_pos() + Vector3(0, 1.0, 0))
	# Rauha päättyy: pomo haastaa kuten ennen.
	g.peaceful = false
	for i in 240:
		await get_tree().physics_frame
	print("LAAVU ei peaceful: haasteita %d %s" % [hits[0], "OK" if hits[0] >= 1 else "TESTI VIKA"])


func _shot(name: String, from: Vector3, to: Vector3) -> void:
	cam.look_at_from_position(from, to)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("kuva ", name)
