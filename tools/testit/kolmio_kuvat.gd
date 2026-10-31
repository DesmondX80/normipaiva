extends Node
## Kolmiomittauksen (#255) piirretyt kohtaukset ja Sytkäri kuvina ilman pelimaailmaa: ovi Saloisissa (lahjat
## ojennettu) ja Vaalassa, väärä ovi (mummo keppi ylhäällä, pieni poika), aamu kummassakin, Sytkärin kortti, mätsi ja
## mittaus kummallekin naiselle. Hahmot ovat 3D-hahmoja (Looks.make) kohtausten omissa lavastuksissa. Jokaisen
## kohtauksen hahmoille ja Jonin rinkalle ajetaan läpimenotarkistus (Asento.solids, "LÄPI … -> …" = VIKA).
## tools/testit/aja.sh tscn tools/testit/kolmio_kuvat.tscn
const K := preload("res://scripts/kolmio_kohtaus.gd")
const S := preload("res://scripts/sytkari.gd")
const Kolmio := preload("res://scripts/kolmiomittaus.gd")
const Looks := preload("res://scripts/looks.gd")
const Hall := preload("res://scripts/rasvanappi_hall.gd")
const Asento := preload("res://tools/testit/asento.gd")
const Rasva := preload("res://scripts/rasvanappi_game.gd")
const Pose := preload("res://scripts/pose.gd")
const Gifts := preload("res://scripts/kolmio_lahjat_mallit.gd")

## Otteen rako (käden pinta lahjan pintaan, m): alle -RAKO_SISALLA = käsi lahjan sisällä, lähin yli RAKO_KELLUU = käsi kelluu.
const RAKO_SISALLA := 0.003
const RAKO_KELLUU := 0.015
## Käden keskilinja vartalon pinnasta (pelvis..spine_03): alle KASI_RAJA = käsi vartalon sisällä.
const KASI_RAJA := 0.025
## Jonin rinkan tarkistuksen vartaloluut (selkä, niska ja solisluut hihnoille).
const VARTALO := ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r"]
const KADET := ["upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r"]

var out := "user://kolmio_kuvat"
var root: Node
var vikoja := 0


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + t)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root = self
	_run.call_deferred()

func _shot(node: Node, nm: String, top := false) -> void:
	for i in 12:  # 3D-hahmot ja IK asettuvat
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("kuva_%s.png" % nm))
	if node.get_script() == K:  # Sytkärin kuvastudiot ovat erillisissä maailmoissa samoissa koordinaateissa
		_lapi(node, nm)
	if top and "_cam_base" in node:
		# Ylhäältä: oven aukeamissuunta, hahmojen paikat ja läpimenot (CLAUDE.md: asetelmasta kuva ylhäältä).
		node._cam_base = Transform3D(Basis.looking_at(Vector3(0, -1, -0.01), Vector3.UP), Vector3(0, 7.5, 0.8))
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("kuva_%s_ylhaalta.png" % nm))
	node.queue_free()
	await get_tree().process_frame

## Läpimenotarkistus (CLAUDE.md, Asento.solids): jokainen kohtauksen hahmo lahjoja, ovea, kaidetta, pöytää, lattiaa
## ja toisia hahmoja vasten. Löydökset tulostuvat "LÄPI … -> …" -riveinä, ja aja.sh merkitsee ajon VIAKSI.
func _lapi(node: Node, nm: String) -> void:
	var list := []
	Asento._chars(node, list)
	var bad := 0
	for c: Node3D in list:
		if c.is_visible_in_tree():
			bad += Asento.solids(c, c.get_parent() as Node3D)
	print("KOLMIO läpimenot %s: %d hahmoa, %d läpimenoa" % [nm, list.size(), bad])


## Lahjojen pitely lähikuvina (Vaalassa kaikki kolme kantavat): edestä, sivulta ja ylhäältä kunkin lahjan kohdalta.
## Ennen kuvia otteen rako numeroina (_rako), kädet vartalosta (_kasi_vartaloon) ja läpimenot (Asento.solids).
## Lopuksi lahjat kuistin pöydällä (kaikki ojennettu) edestä, sivulta ja ylhäältä.
func _holders() -> void:
	var ui = _scene("ovi", "vaala", func(u): pass)
	ui._line = 0; ui._given = 0; ui._door = 0.0; ui._door_to = 0.0; ui._line_t = 9.0
	for i in 12:
		await get_tree().process_frame
	for nimi: String in ui._props:
		_rako(ui._people[nimi], ui._props[nimi], nimi)
		_kasi_vartaloon(ui._people[nimi], nimi)
	_lapi(ui, "pitely")
	for nimi: String in ui._props:
		var prop: Node3D = ui._props[nimi]
		var ch: Node3D = ui._people[nimi]
		var c := prop.global_position + Vector3(0, 0.08, 0)
		var fwd := -ch.global_basis.z
		for v in [["edesta", fwd * 0.75 + Vector3(0, 0.12, 0)], ["sivulta", ch.global_basis.x * 0.6 + fwd * 0.2 + Vector3(0, 0.25, 0)],
				["ylhaalta", fwd * 0.2 + Vector3(0, 0.55, 0)]]:
			var eye: Vector3 = c + v[1]
			ui._cam_base = Transform3D(Basis.looking_at(c - eye, Vector3.UP if v[0] != "ylhaalta" else fwd), eye)
			for i in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("kuva_pitely_%s_%s.png" % [nimi.replace(" ", "_"), v[0]]))
	ui._given = 3
	for i in 30:  # lahjat liukuvat pöydälle
		await get_tree().process_frame
	var t: Vector3 = ui._table_top + Vector3(0, 0.08, 0)
	for v in [["edesta", Vector3(0.1, 0.25, 0.85)], ["sivulta", Vector3(0.8, 0.3, 0.1)], ["ylhaalta", Vector3(0, 0.75, 0.12)]]:
		var eye: Vector3 = t + v[1]
		ui._cam_base = Transform3D(Basis.looking_at(t - eye, Vector3.UP), eye)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("kuva_poyta_lahjat_%s.png" % v[0]))
	ui.queue_free()
	await get_tree().process_frame


## Otteen rako: käden ja sormien pinnan pisteet (Pose.limb_points) lahjan kehyksessä, etäisyys lahjan sivupintaan
## (rasian kaltevat seinät, purkin vaippa, kimpun kääre). Kummankin käden pienin rako; negatiivinen = sisällä.
func _rako(ch: Node3D, prop: Node3D, nimi: String) -> void:
	var sk: Skeleton3D = ch.skeleton
	for lr in ["_l", "_r"]:
		var bones := []
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i)
			if bn.ends_with(lr) and (bn.begins_with("hand") or bn.begins_with("thumb") or bn.begins_with("index")
					or bn.begins_with("middle") or bn.begins_with("ring") or bn.begins_with("pinky")):
				bones.append(bn)
		var pts := Pose.limb_points(ch, prop, bones, 1)
		if pts.is_empty():
			print("KOLMIO rako %s %s ei tarkistettu (headless)" % [nimi, lr])
			return
		var mind := INF
		var inside := 0
		var ylo := INF
		var yhi := -INF
		for q in pts:
			ylo = minf(ylo, q.y)
			yhi = maxf(yhi, q.y)
		var bands := [INF, INF, INF]  # rako nyrkin ala-, keski- ja yläosassa (pitkin kättä)
		for q in pts:
			var d := INF
			match String(prop.name):
				"Mansikat":
					var zh := lerpf(Gifts.RASIA_ALA.y, Gifts.RASIA_YLA.y, clampf(q.y / Gifts.RASIA_H, 0.0, 1.0))
					if q.y >= 0.0 and q.y <= Gifts.RASIA_H and absf(q.z) < zh:
						d = absf(q.x) - Gifts.rasia_half(q.y)
				"Kermavaahto":
					if q.y >= 0.0 and q.y <= Gifts.PURKKI_H:
						d = Vector2(q.x, q.z).length() - Gifts.PURKKI_R
				"Ruusut":
					var r := Gifts.kaare_r(q.y)
					if r > 0.0:
						d = Vector2(q.x, q.z).length() - r
			mind = minf(mind, d)
			var bi := clampi(int((q.y - ylo) / maxf(yhi - ylo, 0.001) * 3.0), 0, 2)
			bands[bi] = minf(bands[bi], d)
			if d < -RAKO_SISALLA:
				inside += 1
		print("KOLMIO rako %s %s (%s): lähin käden piste lahjan pinnasta %.4f m, sisällä %d pistettä; nyrkin ala/keski/ylä %s (y %.3f..%.3f)" % [
			nimi, lr, prop.name, mind, inside, bands.map(func(b): return snappedf(b, 0.001)), ylo, yhi])
		if inside > 0:
			_vika("%s %s: käsi %s sisällä (%d pistettä, syvin %.3f m)" % [nimi, lr, prop.name, inside, mind])
		elif mind > RAKO_KELLUU:
			_vika("%s %s: käsi kelluu %s vieressä (lähin %.3f m)" % [nimi, lr, prop.name, mind])


## Käsi omaan vartaloon: olkavarren alapuolen, kyynärvarren ja käden keskilinjan etäisyys vartalon pintaan
## (pelvis..spine_03, Pose.limb_points). Alle KASI_RAJA = käsi vartalon sisällä.
func _kasi_vartaloon(ch: Node3D, nimi: String) -> void:
	var pts := Pose.limb_points(ch, ch, ["pelvis", "spine_01", "spine_02", "spine_03"], 1)
	if pts.is_empty():
		print("KOLMIO käsi %s ei tarkistettu (headless)" % nimi)
		return
	for lr in ["l", "r"]:
		var chain := ["upperarm_" + lr, "lowerarm_" + lr, "hand_" + lr]
		var low := INF
		for i in 2:
			var a: Vector3 = ch.bone_position(chain[i])
			var b: Vector3 = ch.bone_position(chain[i + 1])
			for st in 5:
				var t := st / 4.0
				if i == 0 and t < 0.5:
					continue  # olkanivelen juuri on vartalossa kiinni
				var p := a.lerp(b, t)
				for q in pts:
					low = minf(low, p.distance_to(q))
		print("KOLMIO käsi %s %s: keskilinja vähintään %.3f m vartalon pinnasta" % [nimi, lr, low])
		if low < KASI_RAJA:
			_vika("%s %s: käsi vartalon sisällä (%.3f m)" % [nimi, lr, low])


func _scene(mode: String, site: String, setup: Callable) -> Node:
	var ui = K.new()
	ui.mode = mode
	ui.site = site
	var info: Dictionary = Kolmio.SITES[site]
	ui.woman = info.woman
	ui.friends = info.friends
	ui.gifts = info.gifts
	setup.call(ui)
	ui.auto = false  # rivi pysyy, lavastus päivittyy (_apply)
	root.add_child(ui)
	return ui

func _run() -> void:
	await get_tree().process_frame
	var ui = _scene("ovi", "saloinen", func(u): pass)
	ui._line = 3; ui._given = 2; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
	await _shot(ui, "ovi_saloinen", true)
	ui = _scene("ovi", "vaala", func(u): pass)
	ui._line = 1; ui._given = 0; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
	await _shot(ui, "ovi_vaala")
	await _holders()
	ui = _scene("vaara", "saloinen", func(u): u.resident = Kolmio.WRONG_DOORS.saloinen[0])
	ui._line = 2; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
	await _shot(ui, "vaara_mummo")
	ui = _scene("vaara", "saloinen", func(u): u.resident = Kolmio.WRONG_DOORS.saloinen[0])
	ui._line = 0; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
	await _shot(ui, "vaara_mummo_keppi_alas")
	ui = _scene("vaara", "saloinen", func(u): u.resident = Kolmio.WRONG_DOORS.saloinen[2])
	ui._line = 1; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
	await _shot(ui, "vaara_poika")
	ui = _scene("aamu", "saloinen", func(u): u.stats = "Kolme ympyrää ✔")
	ui._line = 1; ui._line_t = 9.0
	await _shot(ui, "aamu_saloinen")
	ui = _scene("aamu", "vaala", func(u): pass)
	ui._line = 2; ui._line_t = 9.0
	await _shot(ui, "aamu_vaala")
	for site in ["saloinen", "vaala"]:
		var info: Dictionary = Kolmio.SITES[site]
		for m in ["match", "matka"]:
			var sy = S.new()
			sy.mode = m
			sy.who = info.woman; sy.age = info.age; sy.job = info.job; sy.bio = info.bio; sy.dist = "250 m"
			sy.note_from = "Esa"; sy.note = "Hyvä. Merkkaan harpilla."
			root.add_child(sy)
			sy._t = 1.2 if m == "match" else 2.0
			sy._rise = 1.0
			sy.set_process(false)
			sy._view.queue_redraw()
			await _shot(sy, "syt_%s_%s" % [m, site])
			if m == "match":
				sy = S.new()
				sy.mode = m
				sy.who = info.woman; sy.age = info.age; sy.job = info.job; sy.bio = info.bio; sy.dist = "250 m"
				root.add_child(sy)
				sy._t = 4.0; sy._swiped = 1.0; sy._rise = 1.0
				sy.set_process(false)
				sy._view.queue_redraw()
				await _shot(sy, "syt_matsi_%s" % site)
	await _rinkka()
	for site in ["saloinen", "vaala"]:
		await _olohuone(site)
	print("KOLMIO kuvat valmis, vikoja %d" % vikoja)
	get_tree().quit()


## Jonin Sandels-päkkirinkka, Mintun kiharat ja väärän oven mummon kampaus 3D:nä: takaa, sivulta, ylhäältä ja rajattuna lähikuvana (logo, muotokuva, jesarit).
func _rinkka() -> void:
	var w := Node3D.new()
	add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 150, 0)
	w.add_child(sun)
	var joni: Node3D = Looks.make(w, Looks.JONI)
	joni.play("Idle", 0.0)
	var minttu: Node3D = Looks.make(w, Looks.MINTTU)  # kiharat: kuvat kolmesta suunnasta ja kasvot
	minttu.position = Vector3(4, 0, 0)
	minttu.play("Idle", 0.0)
	var mummo: Node3D = Looks.make(w, K.RESIDENTS["Mummo kepin kanssa"])  # väärän oven mummo: permanentti ja lasit
	mummo.position = Vector3(-4, 0, 0)
	mummo.play("Idle", 0.0)
	for i in 8:
		await get_tree().process_frame
	# Rinkka ja hihnat Jonin vartaloa vasten: Asento.solids ohittaa hahmon omat lapset, joten pakkaus siirretään
	# hetkeksi maailmaan samaan paikkaan.
	var pack: Node3D = null
	for n in joni.find_children("*", "Node3D", true, false):
		if n.get_child_count() > 20 and not n.has_method("bone_position") and not n is Skeleton3D:
			pack = n
			break
	if pack == null:
		print("TESTI VIKA rinkkaa ei löytynyt Jonista")
	else:
		var xf := pack.global_transform
		var par := pack.get_parent()
		par.remove_child(pack)
		w.add_child(pack)
		pack.global_transform = xf
		print("KOLMIO läpimenot rinkka: %d" % Asento.solids(joni, w, 1.0))
		w.remove_child(pack)
		par.add_child(pack)
		pack.global_transform = xf
		# Rako numeroina seisten ja kävelyn kahdeksassa vaiheessa (Asento.solids katsoo vain yhden asennon).
		_reppu(joni, pack, "seisoo")
		_kasi_vartaloon(joni, "Joni seisoo")
		joni.play("Walk", 0.0)
		for i in 8:
			for f in 4:
				await get_tree().process_frame
			_reppu(joni, pack, "kävely %d" % i)
			_kasi_vartaloon(joni, "Joni kävely %d" % i)
		joni.play("Idle", 0.0)
		for i in 10:
			await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 40.0
	w.add_child(cam)
	cam.current = true
	for v in [["rinkka_takaa", Vector3(0.3, 1.5, 1.8), Vector3(0, 1.2, 0)], ["rinkka_sivulta", Vector3(1.6, 1.4, 0.4), Vector3(0, 1.25, 0.1)],
			["rinkka_ylhaalta", Vector3(0.0, 3.0, 0.35), Vector3(0, 1.2, 0.15)], ["rinkka_lahelta", Vector3(0.05, 1.3, 0.75), Vector3(0, 1.22, 0.2)],
			["minttu_edesta", Vector3(4.1, 1.55, -1.1), Vector3(4, 1.45, 0)], ["minttu_kasvot", Vector3(4.05, 1.58, -0.6), Vector3(4, 1.53, 0)],
			["minttu_sivulta", Vector3(5.1, 1.55, 0.0), Vector3(4, 1.45, 0)], ["minttu_takaa", Vector3(4.1, 1.6, 1.1), Vector3(4, 1.45, 0)],
			["mummo_kasvot", Vector3(-3.95, 1.4, -0.6), Vector3(-4, 1.36, 0)], ["mummo_sivulta", Vector3(-3.0, 1.35, 0.0), Vector3(-4, 1.3, 0)],
			["mummo_takaa", Vector3(-3.9, 1.45, 0.9), Vector3(-4, 1.3, 0)]]:
		cam.look_at_from_position(v[1], v[2])
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("kuva_%s.png" % v[0]))
	w.queue_free()


## Jonin rinkka (looks.gd add_sandels_rinkka) vartaloa ja käsiä vasten pakkauksen kehyksessä (selkä -Z): pakkaus
## ja kylkitavarat AABB:nä (olkahihnat pois), vartalon ja käsien lähin piste siihen; olkahihnat (B.tube, säde 0,012)
## janoina, vartalon ja käsien rako hihnan pintaan.
func _reppu(ch: Node3D, pack: Node3D, mika: String) -> void:
	var vartalo := Pose.limb_points(ch, pack, VARTALO, 1)
	var kadet := Pose.limb_points(ch, pack, KADET, 1)
	if vartalo.is_empty():
		print("KOLMIO rinkka %s ei tarkistettu (headless)" % mika)
		return
	var aabb := AABB()
	var first := true
	var straps := []  # [a, b, säde] pakkauksen kehyksessä
	for mi: MeshInstance3D in pack.find_children("*", "MeshInstance3D", true, false):
		var xf := pack.global_transform.affine_inverse() * mi.global_transform
		var cm := mi.mesh as CylinderMesh
		if cm != null and is_equal_approx(cm.top_radius, 0.012) and is_equal_approx(cm.bottom_radius, 0.012) and cm.height > 0.05:  # ei Olvin merkkiä
			straps.append([xf * Vector3(0, cm.height / 2.0, 0), xf * Vector3(0, -cm.height / 2.0, 0), cm.top_radius])
			continue
		var bb: AABB = xf * mi.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	var res := {}
	for g in [["selkä", vartalo], ["käsi", kadet]]:
		var lahin := INF
		var sisalla := 0
		var h_lahin := INF
		var h_sisalla := 0
		for q: Vector3 in g[1]:
			var d := _aabb_dist(aabb, q)
			lahin = minf(lahin, d)
			if d <= 0.0:
				sisalla += 1
			for sp: Array in straps:
				var dh := q.distance_to(Geometry3D.get_closest_point_to_segment(q, sp[0], sp[1])) - float(sp[2])
				h_lahin = minf(h_lahin, dh)
				if dh < 0.0:
					h_sisalla += 1
		res[g[0]] = [lahin, sisalla, h_lahin, h_sisalla]
	print("KOLMIO rinkka %s: selän rako %.3f m (sisällä %d), käsi lähin %.3f m (sisällä %d), hihna-vartalo %.3f m (sisällä %d), hihna-käsi %.3f m (sisällä %d), %d hihnaa" % [
		mika, res["selkä"][0], res["selkä"][1], res["käsi"][0], res["käsi"][1], res["selkä"][2], res["selkä"][3], res["käsi"][2], res["käsi"][3], straps.size()])
	if res["selkä"][1] > 0:
		_vika("rinkka selän sisällä (%s, %d pistettä)" % [mika, res["selkä"][1]])
	if res["käsi"][1] > 0:
		_vika("käsi rinkan sisällä (%s, %d pistettä)" % [mika, res["käsi"][1]])
	if res["selkä"][3] > 0:
		_vika("olkahihna vartalon sisällä (%s, %d pistettä)" % [mika, res["selkä"][3]])
	if res["käsi"][3] > 0:
		print("KOLMIO rinkka %s: käsi hihnan kohdalla (kainalo), %d pistettä" % [mika, res["käsi"][3]])


static func _aabb_dist(b: AABB, p: Vector3) -> float:
	var q := p.clamp(b.position, b.end)
	if q == p:
		var e := (p - b.position).min(b.end - p)
		return -minf(e.x, minf(e.y, e.z))
	return q.distance_to(p)


## Naisen olohuone (rasvanappi_hall.gd _build_living) valot päällä: pelikamera, esittelykamera ja ylhäältä.
func _olohuone(site: String) -> void:
	var h = Hall.new()
	h.room = Rasva.ROOM
	h.door_y = Rasva.DOOR_Y
	h.style = Kolmio.RASVA_RULES[site].style
	add_child(h)
	h.build(Rasva.OBST, [], {}, null)
	h.set_lit(1.0)
	h.set_sight(Vector2(1.5, Rasva.DOOR_Y), 2.0)
	var top := Camera3D.new()
	top.fov = 50.0
	top.cull_mask = Hall.LAYER
	top.environment = h.cam.environment
	h.add_child(top)
	var eye := Vector3(6.0, 11.0, 3.6)
	top.transform = Transform3D(Basis.looking_at(Vector3(0, -1, -0.001), Vector3.UP), eye)
	var near := Camera3D.new()  # lähikuva: televisio, piano ja ikkuna
	near.fov = 50.0
	near.cull_mask = Hall.LAYER
	near.environment = h.cam.environment
	h.add_child(near)
	near.transform = Transform3D(Basis.looking_at(Vector3(4.0, 0.8, 0.2) - Vector3(2.6, 1.7, 3.0), Vector3.UP), Vector3(2.6, 1.7, 3.0))
	var near2 := Camera3D.new()  # lähikuva: ruokapöytä, takka ja kirjahylly
	near2.fov = 50.0
	near2.cull_mask = Hall.LAYER
	near2.environment = h.cam.environment
	h.add_child(near2)
	near2.transform = Transform3D(Basis.looking_at(Vector3(10.0, 0.7, 2.5) - Vector3(6.0, 2.2, 6.5), Vector3.UP), Vector3(6.0, 2.2, 6.5))
	for v in [[h.cam, "peli"], [h.line_cam, "edesta"], [top, "ylhaalta"], [near, "tv"], [near2, "takka"]]:
		(v[0] as Camera3D).current = true
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("kuva_olohuone_%s_%s.png" % [site, v[1]]))
	h.queue_free()
	await get_tree().process_frame
