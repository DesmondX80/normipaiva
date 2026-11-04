extends "res://scripts/rikos/osa.gd"
## V2 Valeostaja Vaalan torilla (huumekaupan riskit, osa.gd). Vaalan-päivänä, kun repussa on myytävää, torille
## ilmestyy VALEOSTAJA_P:n todennäköisyydellä uusi aikuinen ostaja (kerran päivässä, klo 9–21, ei yöllä). Puolet
## ostajista ovat aitoja, puolet siviilipukuisia poliiseja. Vain poliisilla on vihjeet: korvanappi kierrejohdolla,
## liian uudet valkoiset lenkkarit ja repliikki "Mä otan kaikki, paljonko sulla on?". Myynti poliisille päättyy
## pidätykseen (main.gd _rikos_loppu "pidatys"), kieltäytyminen ei maksa mitään. "Sää oot kyttä": oikein maine +2 ja
## vihjeet päiväkirjan Riskit-sivulle, väärin aito ostaja loukkaantuu ja lähtee. Pelimekaniikkaa: ei aineiden nimiä,
## määriä eikä ohjeita. Hahmo on Vaalan kehyksessä (mopo_trip.vaala), etu = hahmon -Z (Looks/Character).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const VALEOSTAJA_P := 0.2  # ilmestymisen todennäköisyys Vaalan-päivänä, kun repussa on myytävää
const VALE_P := 0.5  # ostaja on poliisi
const AUKI := Vector2(9 * 60, 21 * 60)  # torilla päivällä, yöksi pois
const HINTA_AITO := 1.25  # × _teini_hinta: hyvä hinta
const HINTA_VALE := 1.6  # × _teini_hinta: liian hyvä hinta
const MAINE_TUNNISTUS := 2.0
const PUHE_R := 3.0

## Siviilipoliisi: tumma softshell-takki (kätkee varusteet), siistit farkut, lyhyt tukka ja vastaostetut hohtavan valkoiset
## lenkkarit. Aikuinen ja leveäharteinen, ei tuulipukuinen mopopoika (vaala.gd _build_race_crew).
const VALE_LOOK := {"shirt": Color(0.17, 0.2, 0.19), "pants": Color(0.16, 0.2, 0.32), "jeans": true, "belt_y": 0.99,
	"belt_col": Color(0.06, 0.05, 0.05), "shoes": Color(1.0, 1.0, 1.0), "hair": "Hair_Buzzed", "hair_color": Color(0.24, 0.18, 0.12),
	"height": 1.84, "shoulders": 0.4, "belly": 0.1, "shine": 0.25}
## Aito ostaja: nuhjuinen harmaa huppari, kuluneet farkut ja likaiset tennarit, sänki.
const AITO_LOOK := {"shirt": Color(0.42, 0.42, 0.4), "pants": Color(0.3, 0.33, 0.42), "jeans": true, "shoes": Color(0.42, 0.38, 0.33),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.35, 0.27, 0.18), "beard": true, "height": 1.76, "bulk": -0.3, "grime": 0.25}

const VIHJEET := ["Korvanappi, josta kierrejohto kauluksen alle.", "Liian uudet, hohtavan valkoiset lenkkarit.",
	"\"Mä otan kaikki, paljonko sulla on?\" ja liian hyvä hinta."]
const VALE_HELLO := "Moro. Kaveri sano, et sulta saa. Mä otan kaikki, paljonko sulla on?\n(Korvassa on pieni nappi, josta kiertyy " \
	+ "kierrejohto kauluksen alle. Lenkkarit hohtaa valkoisina kuin suoraan laatikosta.)"
const AITO_HELLO := ["Moi. Onks sulla jotain? Mä maksan hyvin, mut vaan pari.\n(Kuluneet tennarit, nuhjuinen huppari. Vilkuilee Zabukin suuntaan.)",
	"Sää oot se mopomies? Yks tai kaks riittää, ei enempää.\n(Sänkinen naama, kengät kurassa. Rahat rypyssä taskussa.)"]

var paiva := -1  # päivä, jolta ostaja on arvottu (kerran päivässä)
var on := false  # tänään torilla ostaja
var vale := false  # ostaja on poliisi
var poissa := false  # ostaja lähti (paljastettu, loukkaantui tai pidätti)
var vihjeet: Array = []  # tunnistetut vihjeet (VIHJEET), päiväkirjaan
var tunnistettu := 0  # kytät, jotka pelaaja tunnisti
var pidatyksia := 0
var tavattu := false  # tänään juteltu (päiväkirjan rivi)

var node: Node3D  # ostajan hahmo Vaalan kehyksessä
var _node_vale := false


func _init() -> void:
	talkers = ["valeostaja"]


func _myytavaa() -> Array:
	var o: Array = []
	game._teini_myynti_valinnat(o)
	return o


## Torin paikka: torin sisällä, irti tiestä, kojuista, Zabukista ja mopopojista (fysiikkakysely kojujen törmäyksille).
func _spot(vl: Node3D) -> Vector3:
	var tori: PackedVector2Array = vl._tori
	if tori.size() < 3:
		return Vector3.INF
	var c: Vector2 = vl._tori_c
	var space: PhysicsDirectSpaceState3D = vl.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 2.0  # vähintään 2 m vapaata kojuista ja kalusteista (pallo 0,3–4,3 m maasta, maata ei osu)
	q.shape = sh
	for ring in 12:
		for k in 16:
			var p: Vector2 = c + Vector2(ring * 2.0, 0).rotated(TAU * k / 16.0 + ring * 0.4)
			if not Geometry2D.is_point_in_polygon(p, tori):
				continue
			var p3 := Vector3(p.x, vl.h(p.x, p.y), p.y)
			var ni: Array = vl.nearest(p3)
			if ni[0] >= 0 and ni[1] < float(vl.road[ni[0]][4]) + 2.5:
				continue
			if vl._zabuki != Vector3.INF and p.distance_to(Vector2(vl._zabuki.x, vl._zabuki.z)) < 8.0:
				continue
			if vl.race_spot != Vector3.ZERO and p.distance_to(Vector2(vl.race_spot.x, vl.race_spot.z)) < 8.0:
				continue
			q.transform = Transform3D(Basis.IDENTITY, vl.to_global(p3 + Vector3(0, 2.3, 0)))
			if not space.intersect_shape(q, 1).is_empty():
				continue
			return p3
	return Vector3.INF


## Hahmo: Looks + siviilipoliisilla korvanappi ja kierrejohto (add_earpiece). Testikuvat käyttävät samaa (valeostaja_kuvat.gd).
static func build_model(parent: Node3D, is_vale: bool) -> Node3D:
	var ch := Looks.make(parent, VALE_LOOK if is_vale else AITO_LOOK)
	if is_vale:
		add_earpiece(ch)
	return ch


## Korvanappi oikeaan korvaan (+X) ja läpikuultava kierrejohto korvan takaa alas kauluksen alle. Mitat hahmon avaruudessa
## pääluun lepopaikasta (kasvot -Z, korvakorujen paikka add_glam: ±0,072, 0,015, 0,005).
static func add_earpiece(c: Node3D) -> void:
	var g := Node3D.new()
	g.name = "Korvanappi"
	var tube_col := Color(0.86, 0.9, 0.92)
	B.mesh(g, B.sphere(0.5, 10), Vector3(0.077, 0.07, 0.004), Color(0.12, 0.12, 0.13)).scale = Vector3(0.012, 0.016, 0.016)
	# Johto: lyhyt suora pätkä napista korvan taakse, sitten kierre alas kaulan sivua kaulukseen.
	var a := Vector3(0.081, 0.064, 0.01)
	var b := Vector3(0.08, 0.025, 0.03)
	var e := Vector3(0.066, -0.13, 0.05)
	var pts: Array[Vector3] = [a, b]
	var ax := (e - b).normalized()
	var u := ax.cross(Vector3.RIGHT).normalized()
	var v := ax.cross(u).normalized()
	var turns := 13.0
	var n := 130
	for i in range(1, n + 1):
		var t := float(i) / n
		var ang := TAU * turns * t
		pts.append(b.lerp(e, t) + (u * cos(ang) + v * sin(ang)) * 0.0055)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Looks._tube_strip(st, pts, 0.0019, tube_col)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	g.add_child(mi)
	c.attach("Head", g, Vector3.ZERO)


func _ensure_node(vl: Node3D) -> bool:
	if node != null and is_instance_valid(node) and _node_vale == vale:
		return true
	if node != null and is_instance_valid(node):
		node.queue_free()
	var p := _spot(vl)
	if p == Vector3.INF:
		poissa = true  # torilla ei tilaa: ostaja ei tule tänään (ei haeta joka ruutu uudelleen)
		return false
	node = build_model(vl, vale)
	_node_vale = vale
	node.position = p
	# Katse Zabukin suuntaan (torin keskellä ovat kojut); kääntyy tulijaan tickissä.
	var z: Vector3 = vl._zabuki if vl._zabuki != Vector3.INF else Vector3(vl._tori_c.x, 0, vl._tori_c.y + 10.0)
	node.rotation.y = B.yaw_to(Vector3(z.x - p.x, 0, z.z - p.z))
	node.play("Idle", 0.0)
	return true


func _paikalla() -> bool:
	return on and not poissa and paiva == game.day and game._between(game.clock_min, AUKI)


func tick(_e: bool) -> void:
	var mt: Node = game.mopo_trip
	if not game._in_vaala or mt == null or not mt.active:
		if node != null and is_instance_valid(node):
			node.visible = false
		return
	if paiva != game.day and game._between(game.clock_min, AUKI) and not _myytavaa().is_empty():
		paiva = game.day
		on = randf() < VALEOSTAJA_P
		vale = randf() < VALE_P
		poissa = false
		tavattu = false
	var walk: Node3D = mt.on_foot if mt.on_foot != null else mt.mopo
	var nakyy := _paikalla()
	if nakyy and (node == null or not is_instance_valid(node) or _node_vale != vale):
		# Paikka haetaan vasta torin lähellä: kojujen törmäysmuodot ovat silloin varmasti fysiikassa.
		var tc: Vector2 = mt.vaala._tori_c
		var wl: Vector3 = mt.vaala.to_local(walk.global_position)
		if Vector2(wl.x, wl.z).distance_to(tc) > 80.0 or not _ensure_node(mt.vaala):
			nakyy = false
	if node == null or not is_instance_valid(node):
		return
	if game._talk_box.is_open() and game._talk_who == "valeostaja":
		return  # kesken keskustelun ei kadota (lähtö näkyy, kun ikkuna sulkeutuu)
	node.visible = nakyy
	if not nakyy or game._talk_box.is_open() or game._hint.text != "":
		return
	var d: Vector3 = walk.global_position - node.global_position
	d.y = 0.0
	if d.length() < 9.0:  # kääntyy katsomaan tulijaa
		node.rotation.y = lerp_angle(node.rotation.y, B.yaw_to(d), 0.08)
	if d.length() < PUHE_R:
		game._talk_hint("valeostaja", node, mt.on_foot != null)


func hello(who: String) -> String:
	if who != "valeostaja":
		return ""
	tavattu = true
	if node != null and is_instance_valid(node):
		node.play("Idle_Talking", 0.3)
	return VALE_HELLO if vale else AITO_HELLO[game.day % AITO_HELLO.size()]


func _hinta(key: String) -> float:
	return roundf(game._teini_hinta(key) * (HINTA_VALE if vale else HINTA_AITO))


func options(who: String, o: Array) -> void:
	if who != "valeostaja":
		return
	for r in _myytavaa():
		var k: String = String(r.id).trim_prefix("myy_")
		o.append(game._opt("valeostaja_myy_" + k, "Myy %s (%s €)" % [game._laake_label(k), game._eur(_hinta(k))]))
	o.append(game._opt("valeostaja_kytta", "Sää oot kyttä."))
	o.append(game._opt("valeostaja_ei", "Ei oo mitään myytävää."))


func choose(id: String) -> bool:
	if not id.begins_with("valeostaja_"):
		return false
	if id.begins_with("valeostaja_myy_"):
		_myy(id.trim_prefix("valeostaja_myy_"))
	elif id == "valeostaja_kytta":
		_kytta()
	else:
		game._talk_box.reply("No, ei sitten. Mä oon tässä vielä hetken.", game._talk_options(), "Ei maksanut mitään.")
	return true


func _myy(key: String) -> void:
	if game.laake.get(key, 0) <= 0:
		return
	if vale:
		# Poliisi: virkamerkki esiin, pidätys (menetykset _rikos_loppu: lääkkeet, puolet rahoista, maine).
		poissa = true
		pidatyksia += 1
		_opi()
		game._talk_box.close()
		game._show_message("Ostaja kaivaa virkamerkin takin alta: \"Poliisi. Olet pidätetty.\"", 3.0)
		Sfx.play("door_close", -2.0)
		game.get_tree().create_timer(1.8).timeout.connect(func() -> void:
			game._rikos_loppu("pidatys", "Myit siviilipukuiselle poliisille Vaalan torilla."))
		return
	game.hs.myyty(key)
	game.laake[key] -= 1
	if game.laake[key] <= 0:
		game.laake.erase(key)
	var price := _hinta(key)
	game.money += price
	Sfx.play("coin", -4.0)
	game._rikos_event("myynti", {"key": key, "paikka": "vaala"})
	game._talk_box.reply("Kiitti. Ei nähty.", game._talk_options(), "+%s €. Rahaa %s €." % [game._eur(price), game._eur(game.money)])


func _kytta() -> void:
	poissa = true
	if vale:
		tunnistettu += 1
		_opi()
		game.maine = clampf(game.maine + MAINE_TUNNISTUS, 0.0, 100.0)
		game._talk_box.reply("...Mää en tiä mistä sää puhut. (Hän painaa korvanappia ja lähtee kävelemään Zabukin taakse.)",
			[game._opt("lopeta", "Lopeta")], "Tunnistit siviilipoliisin. Maine +%d. Vihjeet päiväkirjaan (Riskit)." % int(MAINE_TUNNISTUS))
	else:
		game._talk_box.reply("Kyttä? MÄ? Ihan sama, mä meen muualle. (Hän tuhahtaa ja lähtee.)", [game._opt("lopeta", "Lopeta")],
			"Ostaja loukkaantui. Kauppa jäi tekemättä.")


func _opi() -> void:
	for v in VIHJEET:
		if not v in vihjeet:
			vihjeet.append(v)


func riskit() -> Dictionary:
	var rivit: Array = []
	for v in vihjeet:
		rivit.append("Siviilipoliisi: " + v)
	if tavattu and on and paiva == game.day and not poissa:
		rivit.append("Tänään Vaalan torilla uusi ostaja. Katso tarkkaan.")
	if tunnistettu > 0 or pidatyksia > 0:
		rivit.append("Kyttiä tunnistettu %d, pidätyksiä %d." % [tunnistettu, pidatyksia])
	if rivit.is_empty():
		return {}
	return {"otsikko": "Kyttävihjeet", "rivit": rivit}


## --- Testi: aja.sh scene riskit --riski=valeostaja --------------------------------------------------------------------
var _vikoja := 0


func _tv(t: String) -> void:
	_vikoja += 1
	print("TESTI VIKA valeostaja: " + t)


func _tf(n: int) -> void:
	for i in n:
		if game.state != "cutscene":
			game.clock_min = 12.0 * 60.0
		await game.get_tree().process_frame


func _tshot(suffix: String) -> void:
	await _tf(3)
	await RenderingServer.frame_post_draw
	var path := "user://riskit_valeostaja" + suffix + ".png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7).replace(".png", "_valeostaja" + suffix + ".png")
	game.get_viewport().get_texture().get_image().save_png(path)
	print("VALEOSTAJA kuva " + path)


func _tcam(from: Vector3, to: Vector3) -> Camera3D:
	var cam := Camera3D.new()
	game.add_child(cam)
	cam.fov = 50.0
	cam.look_at_from_position(from, to)
	cam.current = true
	return cam


func _tilanne(t: String) -> void:
	print("VALEOSTAJA %s: paiva %d on %s vale %s poissa %s näkyy %s, laake %s, rahat %.0f, maine %.0f, vihjeitä %d" % [t, paiva, on, vale,
		poissa, node != null and is_instance_valid(node) and node.visible, game.laake, game.money, game.maine, vihjeet.size()])


func _avaa() -> void:
	game._talk_open("valeostaja", node)
	await _tf(3)


func testi(_arg: String) -> void:
	if game.player != game.walker_out:
		game._toggle_mount()
	game._start_mopo()
	var mt: Node = game.mopo_trip
	for car in mt._cars:
		car.process_mode = Node.PROCESS_MODE_DISABLED
		car.visible = false
	await _tf(20)
	var vl: Node3D = mt.vaala
	# V2.1 arvonta: ei myytävää = ei arvota; myytävää = arvotaan kerran päivässä.
	game.laake = {}
	paiva = -1
	await _tf(3)
	if paiva != -1:
		_tv("arvottiin ilman myytävää")
	game.laake = {"opiaatti": 3}
	await _tf(3)
	_tilanne("arvonta")
	if paiva != game.day:
		_tv("ei arvottu, vaikka repussa on myytävää")
	var n_on := 0
	for i in 2000:
		n_on += int(randf() < VALEOSTAJA_P)
	print("VALEOSTAJA arvonta 2000 päivää: ostaja %d kertaa (odotus %d)" % [n_on, int(2000 * VALEOSTAJA_P)])
	var was_on := on
	await _tf(3)
	if on != was_on:
		_tv("arvottiin uudelleen samana päivänä")
	# Aito ostaja torilla: pelaaja jalan torin laidalle (paikka haetaan vasta torin lähellä).
	if node != null:
		_tv("ostajan paikka haettiin kaukana torista")
	if mt.on_foot == null:
		game._mopo_dismount()
	var tc: Vector2 = vl._tori_c
	mt.on_foot.global_position = vl.to_global(Vector3(tc.x, vl.h(tc.x, tc.y) + 0.5, tc.y + 25.0))
	mt.on_foot.activate_camera()
	await _tf(10)
	on = true
	vale = false
	poissa = false
	await _tf(5)
	_tilanne("aito")
	if node == null or not node.visible:
		_tv("aito ostaja ei näy torilla")
		return
	var p := Vector2(node.position.x, node.position.z)
	var ni: Array = vl.nearest(node.position)
	print("VALEOSTAJA paikka %s, torin keskeltä %.1f m, tiestä %.1f m (puolileveys %.1f), torilla %s, korvanappi %s" % [node.position,
		p.distance_to(vl._tori_c), ni[1], float(vl.road[ni[0]][4]) if ni[0] >= 0 else -1.0, Geometry2D.is_point_in_polygon(p, vl._tori),
		node.find_child("Korvanappi", true, false) != null])
	if not Geometry2D.is_point_in_polygon(p, vl._tori):
		_tv("ostaja ei ole torilla")
	if node.find_child("Korvanappi", true, false) != null:
		_tv("aidolla ostajalla on korvanappi")
	# Pelaaja jalan ostajan eteen: puhevihje ja pelikameran kuva.
	var fwd := -node.global_transform.basis.z
	fwd.y = 0.0
	mt.on_foot.global_position = node.global_position + fwd.normalized() * 2.2 + Vector3(0, 0.5, 0)
	mt.on_foot.activate_camera()
	await _tf(20)
	var tp: Control = game._talk_prompt
	print("VALEOSTAJA puhevihje: näkyy %s, vihjerivi '%s', pelaajasta %.1f m" % [tp.visible, game._hint.text,
		mt.on_foot.global_position.distance_to(node.global_position)])
	if not tp.visible:
		_tv("puhevihje ei näy ostajan edessä")
	await _tshot("_pelikamera")
	await _avaa()
	var h: String = hello("valeostaja")
	var ids: Array = game._talk_options("valeostaja").map(func(o: Dictionary) -> String: return o.id)
	print("VALEOSTAJA valinnat ", ids, " tervehdys '", h, "'")
	if not "valeostaja_myy_opiaatti" in ids or not "valeostaja_kytta" in ids or not "valeostaja_ei" in ids or "juttu" in ids or "myy_opiaatti" in ids:
		_tv("valinnat %s" % [ids])
	await _tshot("_aito_keskustelu")
	var m0: float = game.money
	game._talk_choose("valeostaja_myy_opiaatti")
	_tilanne("aito myynti")
	if game.laake.get("opiaatti", 0) != 2 or absf(game.money - m0 - _hinta("opiaatti")) > 0.01:
		_tv("aito myynti: laake %s, rahaa +%.0f (hinta %.0f)" % [game.laake, game.money - m0, _hinta("opiaatti")])
	var before := [game.money, game.maine, game.laake.duplicate()]
	game._talk_choose("valeostaja_ei")
	if [game.money, game.maine, game.laake] != before or not node.visible:
		_tv("kieltäytyminen maksoi tai ostaja lähti")
	game._talk_choose("valeostaja_kytta")
	_tilanne("aito: sää oot kyttä")
	if game.maine != before[1] or not poissa or not vihjeet.is_empty():
		_tv("väärä syytös muutti mainetta tai vihjeitä")
	game._talk_box.close()
	await _tf(5)
	if node.visible:
		_tv("loukkaantunut ostaja ei lähtenyt")
	# Valeostaja: vihjeet näkyvissä (korvanappi, valkoiset kengät, repliikki).
	vale = true
	poissa = false
	await _tf(5)
	_tilanne("vale")
	if node.find_child("Korvanappi", true, false) == null:
		_tv("valeostajalla ei korvanappia")
	if not "Mä otan kaikki" in hello("valeostaja"):
		_tv("valeostajan tervehdyksessä ei vihjettä")
	var head: Vector3 = node.global_position + Vector3(0, 1.72, 0)
	var side := node.global_transform.basis.x
	var cam := _tcam(head + side * 0.45 + Vector3(0, 0.05, -0.15), head + Vector3(0, -0.02, 0))
	await _tshot("_korvanappi")
	cam.look_at_from_position(node.global_position + fwd * 1.3 + Vector3(0, 0.5, 0), node.global_position + Vector3(0, 0.1, 0))
	await _tshot("_kengat")
	cam.look_at_from_position(node.global_position + fwd * 5.0 + side * 2.0 + Vector3(0, 2.0, 0), node.global_position + Vector3(0, 1.0, 0))
	await _tshot("_vale_kokonaan")
	var rp: Vector3 = vl.to_global(vl.race_spot)
	cam.look_at_from_position(node.global_position + (node.global_position - rp).normalized() * 9.0 + Vector3(0, 4.0, 0),
		(node.global_position + rp) / 2.0 + Vector3(0, 1.0, 0))
	print("VALEOSTAJA mopopojat %.1f m päässä" % node.global_position.distance_to(rp))
	await _tshot("_tori_ja_mopopojat")
	cam.queue_free()
	mt.on_foot.activate_camera()
	await _avaa()
	game._talk_choose("valeostaja_kytta")
	_tilanne("vale: sää oot kyttä")
	if vihjeet.size() != VIHJEET.size() or tunnistettu != 1 or absf(game.maine - float(before[1]) - MAINE_TUNNISTUS) > 0.01:
		_tv("tunnistus: vihjeet %d, tunnistettu %d, maine %.0f" % [vihjeet.size(), tunnistettu, game.maine])
	var rs: Dictionary = riskit()
	print("VALEOSTAJA riskit ", rs)
	if rs.get("otsikko") != "Kyttävihjeet" or rs.get("rivit", []).size() < 3:
		_tv("päiväkirjan rivit %s" % [rs])
	game._talk_box.close()
	await _tf(3)
	# Yö: ostaja poissa.
	poissa = false
	game.clock_min = 22.5 * 60.0
	tick(false)
	if node.visible:
		_tv("ostaja torilla yöllä")
	await _tf(3)
	# Tallennus edestakaisin (oma osio).
	var cfg := ConfigFile.new()
	save_to(cfg)
	var v0 := [paiva, on, vale, poissa, tunnistettu, pidatyksia, vihjeet.duplicate()]
	paiva = -5
	tunnistettu = 0
	vihjeet = []
	load_from(cfg)
	print("VALEOSTAJA tallennus ", v0, " -> ", [paiva, on, vale, poissa, tunnistettu, pidatyksia, vihjeet])
	if [paiva, on, vale, poissa, tunnistettu, pidatyksia, vihjeet] != v0:
		_tv("tallennus/lataus")
	load_from(ConfigFile.new())
	if paiva != -1 or not vihjeet.is_empty():
		_tv("vanha tallennus: oletusarvot")
	load_from(cfg)
	# Myynti valeostajalle: PIDÄTETTY ja menetykset.
	vale = true
	poissa = false
	game.laake = {"opiaatti": 2}
	game.money = 300.0
	game.maine = 50.0
	await _tf(5)
	await _avaa()
	game._talk_choose("valeostaja_myy_opiaatti")
	var f := 0
	while game.cutscene._title.text == "" and f < 900:
		f += 1
		await game.get_tree().process_frame
	var title: String = game.cutscene._title.text
	await RenderingServer.frame_post_draw
	await _tshot("_pidatetty")
	_tilanne("pidätys (otsikko '%s' %d ruutua)" % [title, f])
	if title != "PIDÄTETTY" or not game.laake.is_empty() or game.money != 150.0 or game.maine != 40.0 or pidatyksia != 1:
		_tv("pidätys: otsikko '%s', laake %s, rahat %.0f, maine %.0f" % [title, game.laake, game.money, game.maine])
	f = 0
	while game.state == "cutscene" and f < 4000:
		f += 1
		await game.get_tree().process_frame
	await _tf(10)
	print("VALEOSTAJA cutscene ohi, tila %s, päivä %d" % [game.state, game.day])
	print("VALEOSTAJA testi valmis, %d vikaa" % _vikoja)


func save_to(cfg: ConfigFile) -> void:
	var s := "rikos_" + nimi
	cfg.set_value(s, "luvut", {"paiva": paiva, "on": int(on), "vale": int(vale), "poissa": int(poissa), "tavattu": int(tavattu),
		"tunnistettu": tunnistettu, "pidatyksia": pidatyksia})
	cfg.set_value(s, "vihjeet", vihjeet.duplicate())


func load_from(cfg: ConfigFile) -> void:
	var s := "rikos_" + nimi
	var l := _ints(cfg.get_value(s, "luvut", {}))
	paiva = l.get("paiva", -1)
	on = l.get("on", 0) == 1
	vale = l.get("vale", 0) == 1
	poissa = l.get("poissa", 0) == 1
	tavattu = l.get("tavattu", 0) == 1
	tunnistettu = l.get("tunnistettu", 0)
	pidatyksia = l.get("pidatyksia", 0)
	vihjeet = []
	for v in cfg.get_value(s, "vihjeet", []):
		if String(v) in VIHJEET:
			vihjeet.append(String(v))
