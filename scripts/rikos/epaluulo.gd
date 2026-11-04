extends "res://scripts/rikos/osa.gd"
## S1 Kylän epäluulo (Saloinen): jokainen luukkuosto apteekin takaovelta ja jokainen myynti Saloisten teineille
## kasvattaa kylän epäluuloa (mittari 0–100, pelin oma yksikkö). Yön yli se laskee. Kun mittari täyttyy, Kinnapotin
## Irma (naapuri apteekin kulmalla) soittaa poliisille: Irma puhelin korvalla ja puhekupla, apteekin luukku pysyy
## kiinni loppupäivän (main.gd _hs_door_logic kysyy luukku_kiinni) ja poliisiauto (police_car.gd) partioi Kinnapotissa.
## Partio jahtaa vain, jos taskussa on lääkkeitä (muuten se ei "näe": grace), ja kiinni jäänti on pidätys
## (game._rikos_loppu). Aamulla mittari nollautuu. Hyvä teko: pullakahvit Irmalle laskee mittaria.
## Irman paikka: apteekin paikallisessa kehyksessä (+Z = julkisivu tielle, -Z = takaovi), takakulman vieressä.

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")
const Pose := preload("res://scripts/pose.gd")
const Cutscene := preload("res://scripts/cutscene.gd")
const PoliceCar := preload("res://scripts/police_car.gd")
const ApteekkiSaloinen := preload("res://scripts/apteekki_saloinen.gd")

const MAX := 100.0
const LISA_LUUKKU := 20.0  # luukkuosto apteekin takaovelta
const LISA_MYYNTI := 15.0  # myynti Saloisten teineille (kaukalo, laavu)
const LISA_HYLKASI := 30.0  # yliannos.gd: pelaaja häipyi lyyhistyneen teinin luota
const YO := 30.0  # lasku yön yli
const KAHVIT := 40.0  # pullakahvit Irmalle
const KAHVI_HINTA := 6.0  # €
const AUKI := Vector2(8.0 * 60.0, 21.0 * 60.0)  # Irma pihalla (pelin minuutit)
const PUHE_R := 2.4
const NAKYY_R := 150.0  # tätä kauempana Irma piilossa (ei animointia)
const KUPLA_R := 70.0
const SOITTO := 14.0  # s puhelin korvalla
const PARTIO_R := 120.0  # m apteekilta: partion määränpäät
## Irman paikkaehdokkaat apteekin kehyksessä (x, z): takakulman sivulla, näkee takaoven (DOOR_X, -D/2).
const PAIKAT := [Vector2(9.0, -5.5), Vector2(9.0, -1.0), Vector2(-9.0, -5.5), Vector2(7.5, 6.0)]
## Oikean korvan kohta pääluusta lepoasennossa (cutscene.gd wasted_phone, miehen mitat; skaalataan pituudella).
const EAR := Vector3(0.09, 0.09, -0.01)

## Kinnapotin Irma: eläkeläisrouva, permanentti, pyöreät lasit, roosa neuletakki ja hame (Looks.MUMMOT-mallin mitoin).
const IRMA_LOOK := {"model": "female", "shirt": Color(0.72, 0.42, 0.55), "pants": Color(0.28, 0.27, 0.33),
	"shoes": Color(0.2, 0.13, 0.1), "hair": "", "perm_col": Color(0.82, 0.8, 0.84), "round_glasses": true,
	"skirt": Color(0.28, 0.27, 0.33), "coat_hem": true, "shorts_y": 0.62, "bare_skin": Color(0.66, 0.52, 0.44),
	"hair_color": Color(0.82, 0.8, 0.84), "height": 1.58, "skin": Color(1.0, 0.89, 0.84), "bulk": 0.2, "belly": 0.3,
	"shoulders": -0.4, "muscle": -1.0}

const HELLO := [
	"Päivää päivää. Kaunis ilma tänään, eikö? Mää tässä vähän katselen, kun ei oo muuta tekemistä.",
	"Ai sää se oot. Sää käyt kovasti siellä apteekin takaovella. Eikö se etuovi kelpaa?",
	"Mää pidän sua silmällä. Kylällä puhutaan, ja mää kuulen kaiken.",
	"Viimeinen varoitus, nuori mies. Mää tiedän numeron, ja sormi on jo napilla.",
]
const HELLO_SOITTI := "Mää soitin jo poliisille. Ihan vaan tiedoksi. Ne ajelee täällä nyt koko päivän."
const PUHELU := ["Haloo, poliisi? Täällä Irma Kinnapotista.", "Taas se sama mies apteekin takaovella!",
	"Ja ne teinit siellä kaukalolla iltaisin...", "Joo, mää ootan. Tulkaa äkkiä."]
const JUTUT := ["Ennen tässä oli rauhallista. Nyt sitä apteekin takaovea koputellaan iltaan asti.",
	"Mun Reino-vainaa sano aina, että kylällä ei salaisuuksia pysy.",
	"Kaukalolla notkuu iltaisin teinejä. Mitä ne siellä myöhään tekee?",
	"Huoltoaseman pullat on kyllä hyviä. Jos joku vaikka tarjois..."]

var epaluulo := 0.0
var halytys := false  # Irma soitti tänään: luukku kiinni ja partio
var kahvit_paiva := -1  # päivä, jona pullakahvit on jo tarjottu
var node: Node3D  # Irma
var auto: CharacterBody3D  # partioiva poliisiauto
var _phone: Node3D
var _kupla: Label3D
var _soitto_t := 0.0
var _rivi := -1
var _partio_ohi := false  # pelaaja pääsi karkuun: auto lähti
var _paikka := Vector3.INF


func _init() -> void:
	talkers = ["irma"]


func taso() -> int:
	return clampi(int(epaluulo / 25.0), 0, 3)


func lisaa(n: float) -> void:
	if halytys or n <= 0.0:
		epaluulo = clampf(epaluulo + n, 0.0, MAX)
		return
	epaluulo = clampf(epaluulo + n, 0.0, MAX)
	if epaluulo >= MAX:
		halyta()


func on_event(ev: String, data: Dictionary) -> void:
	match ev:
		"luukkuosto":
			lisaa(LISA_LUUKKU)
		"myynti":
			if data.get("paikka", "") == "saloinen":
				lisaa(LISA_MYYNTI)
		"hylkasi":
			lisaa(LISA_HYLKASI)
		"epaluulo":
			lisaa(float(data.get("n", 0.0)))


## Mittari täynnä: Irma soittaa (puhelin korvalle ja kupla), luukku kiinni, partio lähtee (tick luo auton).
func halyta() -> void:
	halytys = true
	epaluulo = MAX
	_soitto_t = SOITTO
	_rivi = -1
	_partio_ohi = false
	game.tilat.first("epaluulo_halytys", 0.2)
	Sfx.play("alert", -4.0, 1.3)
	game._show_message("Kinnapotin Irma kaivaa kännykän esiin: \"Haloo, poliisi?\"\n" +
		"Apteekin luukku pysyy tänään kiinni, ja poliisiauto partioi Kinnapotissa.", 4.5)


func luukku_kiinni() -> String:
	if not halytys:
		return ""
	return "Raili raottaa verhoa ja pudistaa päätään: Irma soitti poliisit. Luukku on tänään kiinni."


## Taskussa myytävää: partio pysäyttää ja jahtaa vain silloin.
func kamaa() -> bool:
	for k in game.laake:
		if int(game.laake[k]) > 0:
			return true
	return false


func aamu(at_m: bool) -> String:
	var oli := halytys
	if halytys:
		epaluulo = 0.0
	else:
		epaluulo = maxf(0.0, epaluulo - YO)
	halytys = false
	_soitto_t = 0.0
	_partio_ohi = false
	_poista_auto()
	if oli and not at_m:
		return "Kinnapotin Irma soitti mullekin! Mitä sää oikein teet siellä apteekin takaovella?!"
	return ""


func _poista_auto() -> void:
	if auto != null and is_instance_valid(auto):
		auto.queue_free()
	auto = null


# --- Irma ja partio --------------------------------------------------------------------------------------------

func tick(_e: bool) -> void:
	_partio()
	var ap: Dictionary = game.world.apteekki_s if game.world != null else {}
	if ap.is_empty() or game._in_vaala:
		if node != null and is_instance_valid(node):
			node.visible = false
		return
	var walk: Node3D = game.player
	var paikalla: bool = game._between(game.clock_min, AUKI) or halytys and _soitto_t > 0.0
	var d := INF
	if _paikka != Vector3.INF:
		d = Vector2(walk.global_position.x - _paikka.x, walk.global_position.z - _paikka.z).length()
	elif Vector2(walk.global_position.x - ap.knock.x, walk.global_position.z - ap.knock.z).length() < 90.0:
		_paikka = _valitse_paikka(ap)  # fysiikka on silloin varmasti rakennettu
	if node == null and _paikka != Vector3.INF:
		_rakenna(ap)
	if node == null:
		return
	var nakyy: bool = paikalla and d < NAKYY_R
	_soitto(nakyy and d < KUPLA_R)
	if game._talk_box.is_open() and game._talk_who == "irma":
		return
	node.visible = nakyy
	node.process_mode = Node.PROCESS_MODE_INHERIT if nakyy else Node.PROCESS_MODE_DISABLED
	if not nakyy or game._talk_box.is_open() or game._hint.text != "":
		return
	var to := walk.global_position - node.global_position
	to.y = 0.0
	if to.length() < 10.0:  # kääntyy katsomaan tulijaa
		node.rotation.y = lerp_angle(node.rotation.y, B.yaw_to(to), 0.06)
	elif _soitto_t <= 0.0:  # muuten tuijottaa apteekin takaovea
		var k: Vector3 = ap.knock - node.global_position
		node.rotation.y = lerp_angle(node.rotation.y, B.yaw_to(Vector3(k.x, 0, k.z)), 0.03)
	if to.length() < PUHE_R:
		game._talk_hint("irma", node, game.player != game.bike)


## Paikka apteekin kehyksestä: ensimmäinen ehdokas, jonka kohdalla ei ole törmäysmuotoja (puut, aidat, hallit).
func _valitse_paikka(ap: Dictionary) -> Vector3:
	var root: Node3D = ap.root
	var yaw := root.rotation.y
	var c := root.global_position
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.6
	q.shape = sh
	var first := Vector3.INF
	for pk in PAIKAT:
		var l := Basis(Vector3.UP, yaw) * Vector3(pk.x, 0, pk.y)
		var p := Vector3(c.x + l.x, 0, c.z + l.z)
		p.y = T.h(p.x, p.z)
		if first == Vector3.INF:
			first = p
		q.transform = Transform3D(Basis(), p + Vector3(0, 1.0, 0))
		var osumat := space.intersect_shape(q, 4).filter(func(r: Dictionary) -> bool:
			return r.collider is StaticBody3D)
		if osumat.is_empty():
			print("EPALUULO Irman paikka %s (apteekin kehyksessä %s)" % [p.snapped(Vector3.ONE * 0.1), pk])
			return p
	print("EPALUULO Irman paikka: kaikki ehdokkaat esteessä, käytetään ensimmäistä %s" % first)
	return first


func _rakenna(ap: Dictionary) -> void:
	node = Looks.make(game.world, IRMA_LOOK)
	node.global_position = _paikka
	var k: Vector3 = ap.knock - _paikka
	node.rotation.y = B.yaw_to(Vector3(k.x, 0, k.z))
	node.play("Idle", 0.0)
	_phone = Cutscene._phone()
	node.add_child(_phone)
	_phone.visible = false
	_kupla = B.bubble(node, Vector3(0, 1.95, 0), Color(1.0, 0.88, 0.95), 1.0, false)


## Puhelin korvalla SOITTO sekuntia: oikea käsi IK:lla korvalle (kuten cutscene.gd wasted_phone), kupla vaihtaa
## repliikkiä. kupla = pelaaja tarpeeksi lähellä nähdäkseen kuplan.
func _soitto(kupla: bool) -> void:
	if _soitto_t <= 0.0:
		if _phone.visible:
			_phone.visible = false
			node.clear_ik()
			_kupla.text = ""
		return
	_soitto_t -= game.get_process_delta_time()
	var r := mini(PUHELU.size() - 1, int((SOITTO - _soitto_t) / (SOITTO / PUHELU.size())))
	if r != _rivi:
		_rivi = r
		if kupla:
			Sfx.speak("muu", PUHELU[r])
	_kupla.text = "Irma: " + PUHELU[r] if kupla else ""
	_phone.visible = true
	_korvalle()


func _korvalle() -> void:
	var s := float(IRMA_LOOK.height) / 1.8
	var fingers := Vector3(0.0, 1.0, -0.35).normalized()
	var ear: Vector3 = node.bone_position("Head") + node.bone_delta("Head") * (EAR * s)
	var hold := ear + Vector3(0.04 * s, 0, 0)
	_phone.position = hold
	_phone.basis = Basis(Vector3.RIGHT, -0.25) * Basis(Vector3.UP, -PI / 2.0)  # ruutu päätä kohti, yläpää eteen
	var wrist := hold + Vector3(0.035 * s, 0.0, 0.0) - fingers * 0.07 * s
	node.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", wrist, wrist + Vector3(0.15, -0.6, 0.25))
	node.set_ik_orient("arm_r", Pose.palm_on(fingers, Vector3.LEFT, false), 1.0)


## Partio hälytyspäivänä: auto tieverkolle ~150 m pelaajasta, määränpäät apteekin ympäriltä. Näkee pelaajan vain,
## kun taskussa on lääkkeitä ja pelaaja on ulkona Saloisissa (muuten grace pitää sen sokeana).
func _partio() -> void:
	if not halytys or _partio_ohi or game._in_vaala:
		if auto != null and is_instance_valid(auto):
			auto.grace = 1.0e6
		return
	var ap: Dictionary = game.world.apteekki_s
	if ap.is_empty():
		return
	if auto == null or not is_instance_valid(auto):
		_luo_auto(ap)
	auto.target = game.player
	var valvoo: bool = game.state == "ulkona" and not game.cutscene.busy and kamaa()
	if not valvoo:
		auto.grace = 1.0e6
	elif auto.grace > 0.0:
		auto.grace = 0.0


func _luo_auto(ap: Dictionary) -> void:
	var p: Vector3 = game.player.global_position
	var nodes: Array[Vector3] = game.world.graph_nodes
	var start := 0
	var best := INF
	for i in nodes.size():
		var d := absf(nodes[i].distance_to(p) - 150.0)
		if d < best:
			best = d
			start = i
	auto = PoliceCar.new()
	game._hazards.add_child(auto)
	auto.setup(nodes, game.world.graph_adj, start, game.player)
	auto.world = game.world
	auto.grace = 1.0e6
	var c: Vector3 = ap.knock
	auto.pick_dest = func() -> Vector3:
		return c + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)) * PARTIO_R
	auto.spotted.connect(func() -> void:
		Sfx.play("alert", 0.0, 0.8)
		game._show_message("POLIISI KINNAPOTISSA! Taskut täynnä lääkkeitä – KARKUUN!", 3.5))
	auto.caught.connect(func() -> void:
		if game.state == "ulkona" and kamaa():
			game._rikos_loppu("pidatys", "Poliisi ratsasi Kinnapotissa, ja taskusta löytyi lääkkeitä."))
	auto.escaped.connect(func() -> void:
		_partio_ohi = true
		game.tilat.add("stressi", 0.2)
		game._show_message("Pääsit karkuun! Poliisiauto kaartaa pois Kinnapotista.", 3.5))


# --- Puhe -----------------------------------------------------------------------------------------------------

func hello(who: String) -> String:
	if who != "irma":
		return ""
	if node != null and is_instance_valid(node) and _soitto_t <= 0.0:
		node.play("Idle_Talking", 0.3)
	if _soitto_t > 0.0:
		return "Hetkinen, mää puhun puhelimessa! ...Joo, se on täällä nyt. Seisoo ihan mun vieressä."
	if halytys:
		return HELLO_SOITTI
	return HELLO[taso()]


func options(who: String, o: Array) -> void:
	if who != "irma":
		return
	var syy := ""
	if kahvit_paiva == game.day:
		syy = "tänään jo tarjottu"
	elif game.money < KAHVI_HINTA:
		syy = "rahat ei riitä (%s €)" % game._eur(KAHVI_HINTA)
	o.append(game._opt("epaluulo_kahvit", "Tarjoa Irmalle pullakahvit (%s €)" % game._eur(KAHVI_HINTA), syy == "", syy,
		epaluulo >= 50.0 and syy == ""))
	o.append(game._opt("epaluulo_juttu", "Mitä kylälle kuuluu?"))


func choose(id: String) -> bool:
	if id == "epaluulo_juttu":
		game._talk_box.reply(JUTUT[(game.day + int(epaluulo)) % JUTUT.size()], game._talk_options())
		return true
	if id != "epaluulo_kahvit":
		return false
	if kahvit_paiva == game.day or game.money < KAHVI_HINTA:
		game._talk_box.reply("Kiitos vaan, mutta ei tänään enää.", game._talk_options())
		return true
	kahvit_paiva = game.day
	game.money -= KAHVI_HINTA
	var ennen := epaluulo
	epaluulo = maxf(0.0, epaluulo - KAHVIT)
	game.maine = clampf(game.maine + 1.0, 0.0, 100.0)
	Sfx.play("coin", -4.0)
	game._save_game()
	var t := "No voi että, pullakahvit! Ehkä mää oon sua väärin luullu. Sää oot ihan kohtelias nuori mies."
	if halytys:
		t = "No voi että, pullakahvit! ...Mutta soitettu mikä soitettu. Ne poliisit ajelee täällä silti tänään."
	game._talk_box.reply(t, game._talk_options(), "−%s €. Kylän epäluulo %d → %d (Riskit-sivu, 7)." % [
		game._eur(KAHVI_HINTA), roundi(ennen), roundi(epaluulo)])
	return true


func riskit() -> Dictionary:
	if epaluulo <= 0.0 and not halytys:
		return {}
	var rivit: Array = []
	if halytys:
		rivit.append("Irma soitti poliisit! Luukku kiinni tänään, poliisiauto partioi Kinnapotissa.")
		rivit.append("Partio pysäyttää, jos taskussa on lääkkeitä. Huomenna kylä rauhoittuu.")
	else:
		rivit.append(["Kinnapotin Irma katselee vielä hymyillen.", "Irma ihmettelee apteekin takaovea.",
			"Irma pitää sua silmällä.", "Irman sormi on jo puhelimen napilla!"][taso()])
		rivit.append("Luukkuosto +%d, myynti Saloisissa +%d, yön yli −%d." % [LISA_LUUKKU, LISA_MYYNTI, YO])
		rivit.append("Täynnä: Irma soittaa poliisit, luukku kiinni päivän.")
	rivit.append("Pullakahvit Irmalle: −%d (kerran päivässä)." % KAHVIT)
	return {"otsikko": "Kylän epäluulo (Saloinen)", "mittari": epaluulo / MAX, "rivit": rivit}


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("rikos_epaluulo", "tila", {"epaluulo": roundi(epaluulo), "halytys": 1 if halytys else 0,
		"kahvit_paiva": kahvit_paiva})


func load_from(cfg: ConfigFile) -> void:
	var d := _ints(cfg.get_value("rikos_epaluulo", "tila", {}))
	epaluulo = float(d.get("epaluulo", 0))
	halytys = d.get("halytys", 0) == 1
	kahvit_paiva = d.get("kahvit_paiva", -1)
	_soitto_t = 0.0
	_partio_ohi = false
	if not halytys:
		_poista_auto()


# --- Testi: aja.sh scene riskit --riski=epaluulo ----------------------------------------------------------------

var _vikoja := 0


func _vika(t: String) -> void:
	_vikoja += 1
	print("TESTI VIKA epaluulo: " + t)


func _frames(n: int) -> void:
	for i in n:
		if game.state != "cutscene":
			game.clock_min = 12.0 * 60.0
		await game.get_tree().process_frame


func _kuva(suffix: String) -> void:
	var path := "user://riskit_epaluulo%s.png" % suffix
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7).replace(".png", "_epaluulo%s.png" % suffix)
	await _frames(4)
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
	print("EPALUULO kuva " + path)


## Irman lähikuva omalla kameralla: suunta hahmon kehyksessä (-Z = kasvot), etäisyys m.
func _lahikuva(suffix: String, dir: Vector3, dist: float) -> void:
	var prev: Camera3D = game.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	game.add_child(cam)
	var head: Vector3 = node.global_transform * Vector3(0, 1.4, 0)
	var at: Vector3 = head + node.global_basis * dir.normalized() * dist
	cam.global_position = at
	cam.look_at(head, Vector3.FORWARD if absf(dir.normalized().y) > 0.9 else Vector3.UP)
	cam.fov = 40.0
	cam.make_current()
	await _kuva(suffix)
	cam.queue_free()
	if prev != null:
		prev.make_current()


func testi(_arg: String) -> void:
	epaluulo = 0.0
	halytys = false
	kahvit_paiva = -1
	_poista_auto()
	game.laake = {}
	game.money = 100.0
	game.maine = 50.0
	# S1.1 kasvu tapahtumista ja lasku yön yli.
	game._hs_ostettu()
	print("EPALUULO luukkuosto -> %.0f" % epaluulo)
	game._rikos_event("myynti", {"key": "opiaatti", "paikka": "saloinen"})
	print("EPALUULO myynti Saloisissa -> %.0f" % epaluulo)
	game._rikos_event("myynti", {"key": "opiaatti", "paikka": "vaala"})
	print("EPALUULO myynti Vaalassa -> %.0f" % epaluulo)
	if epaluulo != LISA_LUUKKU + LISA_MYYNTI:
		_vika("kasvu: %.0f (odotettiin %.0f)" % [epaluulo, LISA_LUUKKU + LISA_MYYNTI])
	var rs: Array = game.journal_data().get("riskit", [])
	print("EPALUULO riskit %s" % [rs])
	if rs.filter(func(d: Dictionary) -> bool: return str(d.otsikko).begins_with("Kylän epäluulo")).is_empty():
		_vika("epäluulo ei näy Riskit-sivulla")
	var at := aamu(false)
	print("EPALUULO yön yli -> %.0f, aamu '%s'" % [epaluulo, at])
	if epaluulo != LISA_LUUKKU + LISA_MYYNTI - YO or at != "":
		_vika("yön yli: %.0f '%s'" % [epaluulo, at])
	# S1.4 pullakahvit.
	epaluulo = 60.0
	game._talk_who = "irma"
	var ids: Array = game._talk_options("irma").map(func(o: Dictionary) -> String: return o.id)
	print("EPALUULO Irman valinnat %s, tervehdys '%s'" % [ids, game._talk_hello("irma")])
	if not "epaluulo_kahvit" in ids or "juttu" in ids:
		_vika("Irman valinnat %s" % [ids])
	game._talk_choose("epaluulo_kahvit")
	print("EPALUULO kahvit -> %.0f, rahat %s, maine %.0f" % [epaluulo, game.money, game.maine])
	if epaluulo != 60.0 - KAHVIT or game.money != 100.0 - KAHVI_HINTA:
		_vika("kahvit: %.0f rahat %s" % [epaluulo, game.money])
	var o: Array = game._talk_options("irma").filter(func(x: Dictionary) -> bool: return x.id == "epaluulo_kahvit")
	print("EPALUULO toiset kahvit: enabled %s syy '%s'" % [o[0].enabled, o[0].reason])
	if o[0].enabled:
		_vika("kahvit kahdesti päivässä")
	game._talk_box.close()
	game._talk_who = ""
	# S1.2 hälytys: pelaaja apteekin takaovella, mittari yli.
	var ap: Dictionary = game.world.apteekki_s
	game._place_on_foot(ap.knock + Vector3(0, 0.3, 0))
	await _frames(20)
	epaluulo = 90.0
	game._rikos_event("luukkuosto", {})
	await _frames(10)
	print("EPALUULO hälytys %s mittari %.0f, Irma %s, puhelin %s, kupla '%s', auto %s" % [halytys, epaluulo,
		node != null, _phone != null and _phone.visible, _kupla.text if _kupla != null else "", auto != null])
	if not halytys or node == null or not _phone.visible or _kupla.text == "" or auto == null:
		_vika("hälytys: Irma puhelimessa ja partio")
	if node != null:
		var hand: Vector3 = node.global_transform * node.bone_position("hand_r")
		var head: Vector3 = node.global_transform * node.bone_position("Head")
		print("EPALUULO puhelin–käsi %.3f m, puhelin–pää %.3f m, Irma–koputus %.1f m" % [
			_phone.global_position.distance_to(hand), _phone.global_position.distance_to(head),
			node.global_position.distance_to(ap.knock)])
		await _kuva("_soitto_peli")
		await _lahikuva("_irma_edesta", Vector3(0, 0.05, -1), 1.6)
		await _lahikuva("_irma_sivu", Vector3(1, 0.05, 0), 1.2)
		await _lahikuva("_irma_ylha", Vector3(0.05, 1, -0.1), 1.3)
	# S1.3 luukku kiinni.
	game._hint.text = ""
	game._hs_door_logic(false)
	print("EPALUULO luukku -> '%s'" % game._hint.text)
	if not "kiinni" in game._hint.text:
		_vika("luukku ei ole kiinni: '%s'" % game._hint.text)
	game._hint.text = ""
	# Partio ilman lääkkeitä ei pysäytä.
	game.laake = {}
	auto.global_position = game.player.global_position + Vector3(2.5, 0.2, 0)
	await _frames(20)
	print("EPALUULO partio ilman kamaa: tila %s, auto %s" % [game.state, auto.mode if is_instance_valid(auto) else "?"])
	if game.state != "ulkona":
		_vika("partio pysäytti ilman lääkkeitä (tila %s)" % game.state)
	# Riskit-sivu.
	game._journal.open_at("riskit")
	await _frames(10)
	await _kuva("_riskit")
	game._journal.toggle()
	await _frames(4)
	# Tallennus edestakaisin.
	var tallessa := [roundi(epaluulo), halytys, kahvit_paiva]
	game._save_game()
	epaluulo = 0.0
	halytys = false
	kahvit_paiva = -1
	game._load_game()
	print("EPALUULO tallennus %s -> %s" % [tallessa, [roundi(epaluulo), halytys, kahvit_paiva]])
	if [roundi(epaluulo), halytys, kahvit_paiva] != tallessa:
		_vika("tallennus/lataus")
	# Aamu: nollaus, luukku auki, partio pois, Päivin lappu.
	at = aamu(false)
	print("EPALUULO aamu: %.0f, luukku '%s', auto %s, lappu '%s'" % [epaluulo, luukku_kiinni(), auto, at])
	if epaluulo != 0.0 or luukku_kiinni() != "" or auto != null or at == "":
		_vika("aamun nollaus")
	await _frames(4)
	# Partio ja lääkkeet taskussa: pidätys.
	lisaa(MAX)
	await _frames(4)
	game.laake = {"opiaatti": 1}
	game.money = 100.0
	for i in 30:
		if game.state != "ulkona":
			break
		if is_instance_valid(auto):
			auto.global_position = game.player.global_position + Vector3(2.5, 0.2, 0)
		await _frames(1)
	print("EPALUULO partio lääkkeiden kanssa: tila %s, laake %s, rahat %s" % [game.state, game.laake, game.money])
	if game.state != "cutscene" or not game.laake.is_empty() or game.money != 50.0:
		_vika("partio ei pidättänyt")
	print("EPALUULO testi valmis, %d vikaa" % _vikoja)
