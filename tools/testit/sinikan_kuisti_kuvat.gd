extends Node3D
## Sinikan kuistin mallit (sinikan_kuisti_mallit.gd) ilman pelimaailmaa: ovi, sokkeli ja porras samoista mitoista kuin
## world.gd _house (World.door_dims), lappu kaikilla lapputeksteillä (rako lehteen, rajat, tekstin mahtuminen), kori
## tyhjänä ja täynnä (pohjan rako portaaseen, täyte sisämittojen sisällä), piirakka; kuvat edestä, sivulta, ylhäältä
## ja lähikuvat. Rakojen ja rajojen alitus = "TESTI VIKA".
## tools/testit/aja.sh tscn tools/testit/sinikan_kuisti_kuvat.tscn
## Pelimaailmassa (maaston korkeus portaan nurkissa ja kuva pelikameralta): ... sinikan_kuisti_kuvat.tscn --maailma

const B := preload("res://scripts/build.gd")
const World := preload("res://scripts/world.gd")
const Mallit := preload("res://scripts/sinikan_kuisti_mallit.gd")
const SinikanKuisti := preload("res://scripts/sinikan_kuisti.gd")

var out := "user://sinikan_kuisti"
var cam: Camera3D
var vikoja := 0
var m := {}
var k := {}


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA ", t)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	if args.has("--maailma"):
		_run_world.call_deferred()
		return
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.88)
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = 0.4
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-50, 150, 0)  # aurinko ulkopuolelta (-Z), varjot kohti taloa
	sun.shadow_enabled = true
	add_child(sun)
	m = World.door_dims()
	print("MITAT ", m)
	# Talon julkisivu (z = 0, talo +Z:ssa), sokkeli, karmi, lehti ja porras kuten _house:ssa (ovi x = 0).
	var house := Node3D.new()
	add_child(house)
	B.mesh(house, B.boxm(Vector3(30, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.35, 0.42, 0.25))
	B.mesh(house, B.boxm(Vector3(6.2, 0.5, 4.2)), Vector3(0, 0.25, 2.0), Color(0.42, 0.42, 0.42))
	B.mesh(house, B.boxm(Vector3(6, 2.7, 4)), Vector3(0, 0.4 + 1.35, 2.0), Color(0.86, 0.8, 0.66))
	B.mesh(house, B.boxm(Vector3(1.2, 2.3, 0.08)), Vector3(0, 1.55, -0.02), World.WHITE)
	B.mesh(house, B.boxm(World.DOOR_LEAF), Vector3(0, World.DOOR_LEAF_Y, -World.DOOR_LEAF_OUT), World.DOORS[0])
	B.mesh(house, B.boxm(World.DOOR_STEP), Vector3(0, World.DOOR_STEP.y / 2.0, -World.DOOR_STEP.z / 2.0),
		Color(0.5, 0.5, 0.5))
	k = Mallit.build(house, Vector3.ZERO, m)
	_check_lappu()
	_check_kori()
	cam = Camera3D.new()
	cam.near = 0.01
	add_child(cam)
	_run.call_deferred()


## Värin mukaan valittu MeshInstance3D Parts-yhdistyksestä.
func _mesh_by(n: Node, col: Color) -> MeshInstance3D:
	for c in n.get_children():
		if c is MeshInstance3D and (c.material_override as StandardMaterial3D).albedo_color.is_equal_approx(col):
			return c
	return null


## AABB juuren (oven) kehyksessä.
func _aabb_in_root(n: Node, root: Node3D) -> AABB:
	var a := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse()
	for c in ([n] + n.find_children("*", "MeshInstance3D", true, false)):
		if c is MeshInstance3D and (c as Node3D).is_visible_in_tree():
			var b: AABB = (inv * (c as MeshInstance3D).global_transform) * (c as MeshInstance3D).get_aabb()
			a = b if first else a.merge(b)
			first = false
	return a


func _check_lappu() -> void:
	var lappu: Node3D = k.lappu
	lappu.visible = true
	var paper := _aabb_in_root(_mesh_by(lappu, Mallit.PAPER), k.root)
	var gap: float = m.leaf_front - paper.end.z
	print("LAPPU paperi %s  rako lehteen %.4f m (0-0,003)" % [paper, gap])
	if gap < -0.0001 or gap > 0.003:
		_vika("lapun rako lehteen %.4f" % gap)
	var ly: Vector2 = m.leaf_y
	if paper.position.x < -m.leaf_half or paper.end.x > m.leaf_half or paper.position.y < ly.x or paper.end.y > ly.y:
		_vika("lappu ei lehden rajoissa: %s" % paper)
	var tape := _aabb_in_root(_mesh_by(lappu, Mallit.TAPE), k.root)
	print("LAPPU teippi z %.4f..%.4f (paperin etupinta %.4f)" % [tape.position.z, tape.end.z, paper.position.z])
	if tape.end.z > paper.position.z:
		_vika("teippi paperin sisällä")
	var label := lappu.get_node("Teksti") as Label3D
	var lz: float = (k.root.global_transform.affine_inverse() * label.global_position).z
	print("LAPPU teksti z %.4f, paperin etupinta %.4f, Label3D katsoo %s (ulos -Z)" % [lz, paper.position.z,
		(k.root.global_transform.basis.inverse() * label.global_basis.z).snappedf(0.01)])
	if lz >= paper.position.z or (label.global_basis.z).z > -0.99:
		_vika("teksti ei paperin edessä ulospäin")
	var room := Mallit.PAPER_SIZE - Vector2(Mallit.PAPER_MARGIN, Mallit.PAPER_MARGIN) * 2.0
	var texts: Array = SinikanKuisti.LAPPU_AAMU + SinikanKuisti.LAPPU_ILTA
	for t in texts:
		for s in [t, t + "\n– Sinikka"]:
			var ok := Mallit.set_lappu_text(lappu, s)
			var sz := Mallit.text_size(label, label.font_size) * Mallit.LABEL_PX
			print("LAPPU fontti %d teksti %.3f x %.3f m (tila %.3f x %.3f) %d merkkiä" % [label.font_size, sz.x, sz.y,
				room.x, room.y, s.length()])
			if not ok or sz.y > room.y + 0.0005 or sz.x > room.x + 0.0005:
				_vika("teksti ei mahdu paperiin: %s" % s)
			# Tekstin paikka: rivitetyn tekstin suorakaide lapun kehyksessä paperin marginaalien sisällä.
			var px := Mallit.LABEL_PX
			var x0 := label.offset.x * px  # Label3D:n oma x (lapun kehyksessä peilattu, rotation.y = PI)
			var rect := Rect2(Vector2(-(x0 + sz.x), -sz.y / 2.0), sz)
			var inner := Rect2(-room / 2.0, room)
			if not inner.grow(0.001).encloses(rect):
				_vika("teksti paperin ulkopuolella: %s vs %s" % [rect, inner])
	print("LAPPU fontti: %s" % (label.font as SystemFont).get_font_name())


func _check_kori() -> void:
	var root: Node3D = k.root
	var kori: Node3D = k.kori
	var marjat: Node3D = k.marjat
	var sz: Vector2 = m.step_z
	var sh: float = m.step_half
	var a := _aabb_in_root(kori, root)
	var bgap: float = a.position.y - m.step_top
	print("KORI koko %s pohjan rako portaaseen %.4f m" % [a.size.snappedf(0.001), bgap])
	if absf(bgap) > 0.003:
		_vika("korin pohja ei portaalla: %.4f" % bgap)
	if a.position.x < -sh or a.end.x > sh or a.position.z < sz.x or a.end.z > sz.y:
		_vika("kori ei portaalla: %s" % a)
	if a.size.x < 0.30 or a.size.x > 0.40 or a.end.y - a.position.y < 0.3:
		_vika("korin mitat: %s" % a.size)
	marjat.visible = true
	var f := _aabb_in_root(marjat, kori)
	var inner := Mallit.basket_inner()
	var rim := Mallit.basket_rim_top()
	print("MARJAT %s sisämitat ±%.3f ±%.3f, yläpinta %.4f, reuna %.4f (väli %.4f), pohja %.4f" % [f, inner.x, inner.y,
		f.end.y, rim, rim - f.end.y, f.position.y])
	if f.position.x < -inner.x or f.end.x > inner.x or f.position.z < -inner.y or f.end.z > inner.y:
		_vika("täyte seinien läpi: %s" % f)
	if f.end.y > rim - 0.0099 or f.position.y < Mallit.BASKET_FLOOR - 0.0001:
		_vika("täyte yli reunan tai pohjan läpi")
	marjat.visible = false
	var piirakka: Node3D = k.piirakka
	piirakka.visible = true
	var p := _aabb_in_root(piirakka, root)
	var pgap: float = p.position.y - m.step_top
	print("PIIRAKKA %s rako portaaseen %.4f" % [p, pgap])
	if absf(pgap) > 0.003 or p.position.x < -sh or p.end.x > sh or p.position.z < sz.x or p.end.z > sz.y:
		_vika("piirakka ei portaalla: %s" % p)
	if p.intersects(a):
		_vika("piirakka ja kori päällekkäin")
	piirakka.visible = false


func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	var lappu: Node3D = k.lappu
	var lp := Vector3(0, Mallit.PAPER_Y, m.leaf_front)
	Mallit.set_lappu_text(lappu, SinikanKuisti.teksti(true, 0) + "\n– Sinikka")
	await _shot("lappu_aamu", lp + Vector3(0.12, -0.08, -0.75), lp, 35.0)
	Mallit.set_lappu_text(lappu, SinikanKuisti.teksti(false, 1) + "\n– Sinikka")
	await _shot("lappu_ilta", lp + Vector3(-0.1, -0.05, -0.75), lp, 35.0)
	await _shot("lappu_paadysta", lp + Vector3(0.45, -0.02, -0.07), lp + Vector3(0.12, 0, -0.08), 25.0)
	await _shot("lappu_pelaaja", Vector3(0.3, 1.65, -2.2), lp, 50.0)
	lappu.visible = false
	await _shot("tyhja_ovi", Vector3(0.3, 1.65, -2.6), Vector3(0, 1.2, 0), 50.0)
	var kp: Vector3 = (k.kori as Node3D).position + Vector3(0, 0.15, 0)
	await _shot("kori_tyhja", kp + Vector3(0.25, 0.45, -0.75), kp, 40.0)
	await _shot("kori_tyhja_ylhaalta", kp + Vector3(0.0, 0.9, -0.15), kp, 40.0)
	k.marjat.visible = true
	await _shot("kori_taysi", kp + Vector3(0.25, 0.45, -0.75), kp, 40.0)
	await _shot("kori_taysi_ylhaalta", kp + Vector3(0.0, 0.9, -0.15), kp, 40.0)
	await _shot("kori_taysi_sivulta", kp + Vector3(0.8, 0.0, 0.0), kp, 40.0)
	k.marjat.visible = false
	k.piirakka.visible = true
	var pp: Vector3 = (k.piirakka as Node3D).position + Vector3(0, 0.03, 0)
	await _shot("kori_piirakka", pp + Vector3(-0.2, 0.4, -0.6), pp, 40.0)
	await _shot("piirakka_sivulta", pp + Vector3(-0.6, 0.06, 0.0), pp, 35.0)
	lappu.visible = true
	await _shot("kuisti_edesta", Vector3(0, 1.3, -3.6), Vector3(0, 0.9, -0.3), 45.0)
	await _shot("kuisti_sivusta", Vector3(3.2, 0.9, -0.6), Vector3(0, 0.6, -0.4), 45.0)
	await _shot("kuisti_ylhaalta", Vector3(0, 3.2, -0.6), Vector3(0, 0.3, -0.55), 45.0)
	print("kuvat: ", ProjectSettings.globalize_path(out), " vikoja ", vikoja)
	get_tree().quit()


func _shot(name: String, from: Vector3, to: Vector3, fov := 50.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, to)
	cam.current = true
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


## Pelimaailmassa: maaston korkeus portaan nurkissa suhteessa talon pohjaan (talo nostetaan keskeltä), raot ja
## kuva pelikameran etäisyydeltä.
func _run_world() -> void:
	load("res://scripts/main.gd").skip_menu = true
	var main: Node3D = load("res://main.tscn").instantiate()
	add_child(main)
	var t0 := Time.get_ticks_msec()
	while (main.get("mokki") == null) and Time.get_ticks_msec() - t0 < 400000:
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	main.clock_min = 9 * 60
	var w: Node3D = main.world
	k = w.sinikka_kuisti
	m = World.door_dims()
	if k.is_empty():
		_vika("sinikka_kuisti tyhjä")
		get_tree().quit()
		return
	var root: Node3D = k.root
	var xf := root.global_transform
	var sz: Vector2 = m.step_z
	var sh: float = m.step_half
	var worst := -INF
	for c in [Vector3(-sh, 0, sz.x), Vector3(sh, 0, sz.x), Vector3(-sh, 0, sz.y), Vector3(sh, 0, sz.y),
			Vector3(0, 0, sz.x), Vector3.ZERO]:
		var wp: Vector3 = xf * c
		var th := World.T.h(wp.x, wp.z) - xf.origin.y
		worst = maxf(worst, th)
		print("MAASTO portaan kohta %s maasto talon pohjasta %+.3f m" % [c, th])
	print("MAASTO korkein %.3f (porras 0.30, raja 0.28)" % worst)
	if worst > 0.28:
		_vika("porras hautautuu maastoon: %.3f" % worst)
	k.lappu.visible = true
	Mallit.set_lappu_text(k.lappu, SinikanKuisti.teksti(true, 0))
	k.marjat.visible = true
	k.piirakka.visible = true
	_check_kori()
	k.marjat.visible = true
	k.piirakka.visible = true
	cam = Camera3D.new()
	cam.far = 2000.0
	main.add_child(cam)
	if main.get("player") != null:
		main.player.visible = false
	for n in main.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var o := xf.origin
	var out_dir := -xf.basis.z
	await _shot("maailma_edesta", o + out_dir * 4.5 + Vector3.UP * 1.7 + xf.basis.x * 0.6, o + Vector3.UP * 0.9, 50.0)
	await _shot("maailma_kaukaa", o + out_dir * 12.0 + Vector3.UP * 4.0, o + Vector3.UP * 1.0, 50.0)
	print("kuvat: ", ProjectSettings.globalize_path(out), " vikoja ", vikoja)
	get_tree().quit()
