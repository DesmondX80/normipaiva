extends "res://scripts/rikos/osa.gd"
## Pentin pakettiauto (#299, vain aikuisille): keski-ikäinen viiksimies Pentti (Looks.PENTTI, keksitty hahmo) seisoo
## tuunatun pakettiautonsa (Vehicles.pentin_auto, kyljissä PENTIN BANGBUS -banderolli) vieressä perjantai- ja
## lauantai-iltaisin klo 19–23: Saloisissa K-Marketin parkkipaikalla, Vaalassa Zabukin asiakasparkissa. Muina aikoina
## Pentti ajaa autollaan Saloisten liikenteessä (traffic_car.gd pentti; piilotetaan pysäkin ajaksi).
## Juttelu: kaksimieliset repliikit sekoitetusta pakasta (eivät toistu samalla kerralla, kuten ranta_flirtti.gd) ja
## kyyti. Kyyti on välikohtaus (cutscene.gd pentti_ride: auto keinuu, ikkunat huurtuvat, radiosta humppa); mitään ei
## näytetä. Pelaaja herää aamulla oudosta paikasta myöhään: moraali nousee, mutta vireys, kipu ja stressi kärsivät ja
## lompakosta puuttuu rahaa. Jos joku näkee kyytiin nousun, Päivi kuulee siitä aamulla ja maine laskee. Ensimmäinen
## kyyti: päiväkirjan sivutehtävä valmis (quests.gd "pentti") ja legendaarinen hetki "pentin_kyyti" (endings.gd).
## Joka kolmas kyyti (KIERTUE_VALI) on Pentin kiertue: onnellinen loppu "pentin_kiertue" omalla loppukohtauksella
## (cutscene.gd pentti_tour: BangBus maantiellä, Pentti ratissa ja pelaaja etupenkillä), herätys kotipihalta.
## Osa käyttää rikos-osien rajapintaa (osa.gd: puhe, logiikka, aamu, tallennus, testi), vaikka se ei ole huumekauppaa:
## Riskit-sivulle ei tule mitään (riskit() tyhjä).
## Auton kehys kuten Vehicles.hiace: -Z = keula, +X = liukuovi (oikea kylki).

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const M := preload("res://scripts/map_data.gd")
const Looks := preload("res://scripts/looks.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const TrafficCar := preload("res://scripts/traffic_car.gd")
const Endings := preload("res://scripts/endings.gd")

const PAIVAT := [4, 5]  # perjantai ja lauantai (main.gd _weekday: 0 = maanantai)
const AUKI := Vector2(19 * 60, 23 * 60)
## Saloisissa auto kaupan keskipisteen kehyksessä (world.gd _build_shop: parkkirivi z 18–22, ruutuviivat x -6 ja -2),
## keula +Z eli ulos parkista.
const SALOINEN_AUTO := Vector3(-4.0, 0.0, 20.0)
const SALOINEN_YAW := PI
const SEISOO := Vector3(1.6, 0.0, 0.5)  # Pentti auton kehyksessä liukuoven edessä
const PUHE_R := 2.8
const NAKYY_R := 150.0
const HUUTO_R := 15.0
const HUUTO_VALI := 7.0  # s huutojen välillä
const KANTELU_P := 0.6  # todistaja kertoo Päiville näin usein
const TODISTAJA_R := 25.0
const MAINE_NAHTY := 3.0
const RAHAA_POIS := Vector2(5.0, 20.0)
const KIERTUE_VALI := 3  # joka kolmas kyyti on kiertue (onnellinen loppu)
const KIERTUE_RAHAA := Vector2(20.0, 40.0)

const HELLO_EKA := "No terve terve! Pentti. Pentin BangBus, kylien kuuluisin kulkupeli. Lähetkö kyytiin? Penkit on lämpimät ja musiikki kovalla."
const HELLO := [
	"Kas, tuttu naama! Pentin BangBus on taas liikenteessä. Hyppää kyytiin, ovi on auki ja liukuu helposti.",
	"Iltaa! Katoppa näitä verhoja. Samettia. Ei ihan kuka tahansa pääse niiden taakse.",
	"No moro! Mää just lämmittelin moottoria. Ja vähän muutakin.",
]
const HELLO_TAAS := "Sieltähän se tuttu kyytiläinen tulee! Penkki on vielä vähän lämmin viime kerrasta."
## Kiertueen vihje (seuraava kyyti on tavallinen, sitä seuraava kiertue) ja kiertuepäivän tervehdys.
const HELLO_VIHJE := "Kuule, mää suunnittelen kiertuetta. Kajaani, Kuhmo, Suomussalmi. Tänään ajellaan vielä täällä, mutta ens kerralla lähetään, jos uskallat."
const HELLO_KIERTUE := "No niin! Tänään lähetään kiertueelle. Tankki täynnä, kasetti kelattu alkuun ja verhot vedetty. Ootko mukana?"
const KIERTUE_HERAYS := "Pentti jätti sut kotipihaan aamuyöllä. Kiertue kesti yhden yön, mutta tuntui viikolta. Kaulassa on vielä pehmonoppa, ja Päivi seisoo ovella kädet puuskassa."
const KIERTUE_HERAYS_V := "Pentti jätti sut Gasthausin pihaan aamuyöllä. Kiertue kesti yhden yön, mutta tuntui viikolta. Kaulassa on vielä pehmonoppa."
const KIERTUE_MSG_V := "Huomenta Vaalasta! Kiertue on ohi, mopo odottaa Gasthausin pihassa."
## Juttelurepliikit autosta; pakka sekoitetaan, joten sama ei toistu ennen kuin kaikki on kuultu.
const LINES := [
	"Tässä on viis vaihetta eteenpäin ja yks taaksepäin. Mää käytän enimmäkseen eteenpäin.",
	"Iskarit on vaihdettu jäykemmiks. Kyydissä tärisee, mutta ei liikaa. Sopivasti.",
	"Tuulilasi huurtuu helposti. En tiiä mistä se johtuu. Varmaan lämmittimestä.",
	"Verhot on mummon vanhat. Mummo ei tiiä. Älä sääkään kerro.",
	"Radiossa on vaan yks kasetti: humppaa molemmin puolin. Kääntyy itsestään.",
	"Takana on patja. Kuljetan sillä... tavaraa. Pehmeetä tavaraa.",
	"Kilometrejä on neljäsataa tuhatta. Ja jokainen niistä on ajettu rakkaudella.",
	"Pehmonopat peilissä tuo onnea. Kakkonen ja kolmonen, yhteensä vitonen. Mun lempinumero.",
	"Penkit on lammasnahkaa. Aitoa. Lammas oli kans ihan tyytyväinen.",
	"Liukuovi liukuu. Siks sen nimi on liukuovi. Sitä ei voi sanoa kaikista ovista.",
]
## Huudot parkkipaikalla, kun pelaaja on lähellä.
const HUUDOT := ["Hei sää siellä! Lähetkö ajelulle?", "Pentin BangBus, viimenen lähtö tänä iltana!",
	"Penkit on lämpimät ja musiikki kovalla!", "Tilaa on vielä yhelle. Tai kahelle, jos ollaan lähekkäin.",
	"Humppaa ja hyvää seuraa, ilmaseks!"]
const BANGBUS := ["BangBus? No ku moottori paukkuu. Bang! Ihan tekninen nimi. Mitä sää luulit?",
	"Bang niinku pamaus. Pakoputki. Ei mitään muuta. Miksi sää punastut?"]
const EI := "No ei se mitään. Pentti ei pakota. Pentti odottaa. Ensi perjantaina samaan aikaan."
const SEEN := "Joku katsoo pitkään, kun liukuovi sulkeutuu perässäsi. Tästä kuullaan vielä."
const MORNING := "Mulle soitettiin. Sää kuulemma nousit eilen illalla jonku viiksiniekan pakettiautoon. BANGBUS? Mikä se on?"
## Herätys Saloisissa: [teksti, paikka-avain] (paikka _heratys_paikka). Vaalassa Gasthausin pihalta (_gasthaus_morning).
const WAKE_SALOINEN := [
	["Heräsit urheilukentän maalista verkkoon kietoutuneena, nahkaliivi peittona. Pentistä ja autosta ei näy jälkeäkään. Liivi jäi.", "kentta"],
	["Heräsit Oravajärven rannalta. Taskussa on kasetti: \"Pentin parhaat humpat 3\". Kenen viikset ne on sun naamassa? Tussia.", "ranta"],
	["Heräsit aseman laiturin penkiltä. Kaulassa roikkuu pehmonoppa kuin mitali.", "laituri"],
]
const WAKE_VAALA := "Heräsit Gasthausin pihalta mopon vierestä. Kaulassa roikkuu pehmonoppa, ja jostain kuuluu vielä humppa."
const WAKE_VAALA_MSG := "Huomenta Vaalasta! Pentti jätti sut Gasthausin pihaan. Mopo odottaa."

var tavattu := false
var kyydit := 0
var kantelu_day := -1  # päivä, jona joku näki kyytiin nousun (Päivi kuulee seuraavana aamuna)
var todistaja_pakko := -1  # testi: 1 = aina nähty, 0 = ei koskaan, -1 = oikea arvio
var _deck: Array = []
var _last := -1
var _huuto_t := 0.0
var _liikenne_piilossa := false
var _s: Dictionary = {}  # Saloisten auto: {"root", "pentti", "body", "kupla"}
var _v: Dictionary = {}  # Vaalan auto (mopo_trip.vaala:n lapsi) ja vaala-solmu "vl"


func _init() -> void:
	talkers = ["pentti"]


func paikalla() -> bool:
	return game._weekday() in PAIVAT and game._between(game.clock_min, AUKI) and not Settings.get_v("k18_pois")


## Auto ja Pentti parent-solmuun kohtaan pos (parentin kehys), keula yaw:n mukaan. Törmäyslaatikko auton kokoinen.
func _rakenna(parent: Node3D, pos: Vector3, yaw: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "PentinAuto"
	parent.add_child(root)
	root.position = pos
	root.rotation.y = yaw
	var built: Dictionary = Vehicles.pentin_auto(root)
	var body := StaticBody3D.new()
	root.add_child(body)
	body.add_child(B.box_shape(Vector3(1.75, 2.0, 4.7), Vector3(0, 1.0, 0.0)))
	var p := Looks.make(root, Looks.PENTTI)
	p.position = SEISOO
	p.rotation.y = B.yaw_to(Vector3(1, 0, 0.3))  # kasvot ulos liukuoven puolelta
	p.play("Idle", 0.0)
	var kupla := B.bubble(p, Vector3(0, 2.15, 0))
	return {"root": root, "pentti": p, "body": body, "kupla": kupla, "huuru": built.huuru, "layer": body.collision_layer}


func _nayta(d: Dictionary, on: bool) -> void:
	if d.is_empty() or not is_instance_valid(d.root):
		return
	var root: Node3D = d.root
	if root.visible == on:
		return
	root.visible = on
	root.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	(d.body as StaticBody3D).collision_layer = int(d.layer) if on else 0


func tick(_e: bool) -> void:
	var on := paikalla()
	_liikenne(on)
	if game._in_vaala:
		_nayta(_s, false)
		_tick_vaala(on)
	else:
		_nayta(_v, false)
		_tick_saloinen(on)


## Pysäkin ajaksi Pentin liikenneauto piiloon ja pysähdyksiin (sama auto ei voi olla kahdessa paikassa).
func _liikenne(on: bool) -> void:
	if on == _liikenne_piilossa:
		return
	_liikenne_piilossa = on
	for car in game.get_tree().get_nodes_in_group(TrafficCar.GROUP):
		if car.get("pentti"):
			car.visible = not on
			car.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func _tick_saloinen(on: bool) -> void:
	if game.world == null:
		return
	var walk: Node3D = game.player
	var c := M.w(M.SHOP_BUILDING)
	var nakyy := on and Vector2(walk.global_position.x - c.x, walk.global_position.z - c.z).length() < NAKYY_R
	if nakyy and _s.is_empty():
		var p := c + SALOINEN_AUTO
		p.y = T.h(p.x, p.z)
		_s = _rakenna(game.world, p, SALOINEN_YAW)
	_nayta(_s, nakyy)
	if nakyy:
		_puhe(walk, _s, game.player != game.bike)


func _tick_vaala(on: bool) -> void:
	var mt: Node = game.mopo_trip
	if mt == null or not mt.active or mt.vaala == null or not mt.vaala.built:
		_nayta(_v, false)
		return
	var vl: Node3D = mt.vaala
	if vl.pentti_spot == Vector3.INF:
		return
	if not _v.is_empty() and (not is_instance_valid(_v.root) or _v.vl != vl):
		_v = {}
	var walk: Node3D = mt.on_foot if mt.on_foot != null else mt.mopo
	var spot: Vector3 = vl.to_global(vl.pentti_spot)
	var nakyy := on and Vector2(walk.global_position.x - spot.x, walk.global_position.z - spot.z).length() < NAKYY_R
	if nakyy and _v.is_empty():
		_v = _rakenna(vl, vl.pentti_spot, vl.pentti_yaw)
		_v["vl"] = vl
	_nayta(_v, nakyy)
	if nakyy:
		_puhe(walk, _v, mt.on_foot != null)


## Pentti kääntyy tulijaan, huutelee ja tarjoaa juttelua PUHE_R:n päässä.
func _puhe(walk: Node3D, d: Dictionary, on_foot: bool) -> void:
	var p: Node3D = d.pentti
	if game._talk_box.is_open():
		return
	var to := walk.global_position - p.global_position
	to.y = 0.0
	if to.length() < 12.0:
		p.global_rotation.y = lerp_angle(p.global_rotation.y, B.yaw_to(to), 0.08)
	_huuto_t -= game.get_process_delta_time()
	var kupla: Label3D = d.kupla
	if to.length() < HUUTO_R and _huuto_t <= 0.0:
		_huuto_t = HUUTO_VALI
		kupla.text = HUUDOT[randi() % HUUDOT.size()]
	elif _huuto_t < HUUTO_VALI - 3.5 or to.length() >= HUUTO_R:
		kupla.text = ""
	if game._hint.text != "":
		return
	if to.length() < PUHE_R:
		game._talk_hint("pentti", p, on_foot)


func _nykyinen() -> Dictionary:
	return _v if game._in_vaala else _s


# --- Puhe -----------------------------------------------------------------------------------------------------

func hello(who: String) -> String:
	if who != "pentti":
		return ""
	var eka := not tavattu
	tavattu = true
	game.tilat.first("pentti_tavattu", 0.0)  # päiväkirjan sivutehtävä tiedoksi (quests.gd "pentti")
	var d := _nykyinen()
	if not d.is_empty() and is_instance_valid(d.pentti):
		(d.pentti as Node3D).play("Idle_Talking", 0.3)
		(d.kupla as Label3D).text = ""
	if eka:
		return HELLO_EKA
	if kiertue_seuraavaksi():
		return HELLO_KIERTUE
	if kyydit % KIERTUE_VALI == 1:
		return HELLO_VIHJE
	if kyydit > 0 and randf() < 0.5:
		return HELLO_TAAS
	return HELLO[randi() % HELLO.size()]


func options(who: String, o: Array) -> void:
	if who != "pentti":
		return
	if kiertue_seuraavaksi():
		o.append(game._opt("pentti_kyyti", "Lähetään kiertueelle! (Onnellinen loppu, ilta päättyy)", true, "", true))
	else:
		o.append(game._opt("pentti_kyyti", "Lähetään ajelulle. (Kyytiin, ilta päättyy)", true, "", true))
	o.append(game._opt("pentti_juttu", "Kerro siitä autosta."))
	o.append(game._opt("pentti_bangbus", "Mikä ihmeen BangBus?"))
	o.append(game._opt("pentti_ei", "Ei kiitos. Päivi odottaa kotona."))


## Seuraava kyyti on kiertue (joka KIERTUE_VALI:s kyyti).
func kiertue_seuraavaksi() -> bool:
	return (kyydit + 1) % KIERTUE_VALI == 0


## Seuraava repliikki sekoitetusta pakasta: ei toistu ennen kuin pakka on käyty läpi, eikä uuden pakan ensimmäinen
## ole edellisen viimeinen.
func seuraava_repliikki() -> String:
	if _deck.is_empty():
		_deck = range(LINES.size())
		_deck.shuffle()
		if _deck.size() > 1 and _deck[0] == _last:
			_deck.append(_deck.pop_front())
	_last = _deck.pop_front()
	return LINES[_last]


func choose(id: String) -> bool:
	if not id.begins_with("pentti_"):
		return false
	match id:
		"pentti_juttu":
			game._talk_box.reply(seuraava_repliikki(), game._talk_options(), "")
		"pentti_bangbus":
			var info := ""
			if game._once_today("pentti_bangbus"):
				game.tilat.add("moraali", 0.1)
				info = "Tilat: moraali +0,10"
			game._talk_box.reply(BANGBUS[randi() % BANGBUS.size()], game._talk_options(), info)
		"pentti_ei":
			game._talk_box.reply(EI, [game._opt("lopeta", "Lopeta")], "")
		"pentti_kyyti":
			_kyyti()
	return true


## Näkeekö joku: kylän hahmot (CharacterBody3D, jolla display_name) TODISTAJA_R:n päässä, Pentti ei lasketa.
func todistajat() -> int:
	if todistaja_pakko >= 0:
		return todistaja_pakko
	var d := _nykyinen()
	if d.is_empty():
		return 0
	var at: Vector3 = (d.root as Node3D).global_position
	var parent: Node = d.vl if d.has("vl") else game
	var n := 0
	for c in parent.get_children():
		if c is CharacterBody3D and "display_name" in c and c.is_visible_in_tree() \
				and (c as Node3D).global_position.distance_to(at) < TODISTAJA_R:
			n += 1
	return n


func _kyyti() -> void:
	var town := "vaala" if game._in_vaala else "saloinen"
	var nahty := false
	if todistajat() > 0:
		nahty = todistaja_pakko == 1 or randf() < KANTELU_P
	if nahty:
		kantelu_day = game.day
		game.maine = clampf(game.maine - MAINE_NAHTY, 0.0, 100.0)
	kyydit += 1
	var kiertue := kyydit % KIERTUE_VALI == 0
	var vali: Vector2 = KIERTUE_RAHAA if kiertue else RAHAA_POIS
	var raha: float = minf(maxf(game.money, 0.0), roundf(randf_range(vali.x, vali.y)))
	game._talk_box.close()
	game._hud.visible = false
	game._save_game()
	if nahty:
		game._show_message(SEEN, 3.0)
	var nakyi := "Joku näki, kun nousit kyytiin." if nahty else "Kukaan ei nähnyt. Toivottavasti."
	if kiertue:
		var lstats := "Kajaani, Kuhmo, Suomussalmi yhdessä yössä  ·  %s" % game._ending_line("pentin_kiertue")
		game.cutscene.pentti_tour(lstats, func() -> void: _kiertue_aamu(town, raha))
		return
	var stats := "Kyyti nro %d  ·  %s" % [kyydit, nakyi]
	game.cutscene.pentti_ride(stats, func() -> void: _herays(town, raha))


## Aamu kyydin jälkeen: herätys oudosta paikasta myöhään, tilat ja rahat, päiväkirja ja legendaarinen hetki.
func _herays(town: String, raha: float) -> void:
	if town == "vaala":
		game._gasthaus_morning(WAKE_VAALA, WAKE_VAALA_MSG)
	else:
		var w: Array = WAKE_SALOINEN[(kyydit - 1) % WAKE_SALOINEN.size()]
		game._new_day(heratys_paikka(String(w[1])), false, String(w[0]))
	game.clock_min = 10.5 * 60.0  # herätys myöhään
	game.money -= raha
	for k in ["moraali", "vireys", "kipu", "stressi"]:
		game.tilat.ensure(k)
	game.tilat.add("moraali", 0.35)
	game.tilat.add("vireys", -0.4)
	game.tilat.add("kipu", -0.25)  # selkä ja polvet
	game.tilat.add("stressi", -0.15)
	game.tilat.first("pentti_kyyti", 0.5)
	if game.endings.counts.get("pentin_kyyti", 0) == 0:
		game._ending("pentin_kyyti")  # vain ensimmäinen kyyti on legendaarinen hetki
	if raha > 0.0:
		game._queue_message("Lompakosta puuttuu %s €. Tilalla on lappu: \"Bensarahat. T: Pentti\"." % game._eur(raha), 4.0)
	game._save_game()


## Kiertueen jälkeinen aamu: kotipihalla (Saloinen) tai Gasthausin pihalla (Vaala), tilat ja kiertuekulut.
func _kiertue_aamu(town: String, raha: float) -> void:
	if town == "vaala":
		game._gasthaus_morning(KIERTUE_HERAYS_V, KIERTUE_MSG_V)
	else:
		game._new_day(game.home_zone + Vector3(0, 0, 4), false, KIERTUE_HERAYS)
	game.clock_min = 11.0 * 60.0
	game.money -= raha
	for k in ["moraali", "vireys", "kipu", "stressi"]:
		game.tilat.ensure(k)
	game.tilat.add("moraali", 0.5)
	game.tilat.add("vireys", -0.5)
	game.tilat.add("kipu", -0.3)
	game.tilat.add("stressi", -0.25)
	game.tilat.first("pentti_kyyti", 0.5)
	game.tilat.first("pentti_kiertue", 0.5)
	if raha > 0.0:
		game._queue_message("Lompakosta puuttuu %s €. Lappu: \"Kiertuekulut. Bensa, makkarat ja yks motelli. T: Pentti\"." % game._eur(raha), 4.5)
	game._save_game()


## Saloisten herätyspaikka (maailman koordinaatit, maan pinnalla).
func heratys_paikka(key: String) -> Vector3:
	var p := Vector3.ZERO
	match key:
		"kentta":
			p = (game.world.kentta_goal as Transform3D) * Vector3(0.0, 0.0, 1.5)  # maalin edessä kentällä (laavulla teinijengi)
		"ranta":
			p = game.world.uimaranta_pos + Vector3(0.0, 0.0, -6.0)
		_:
			p = game.world.station_arrive
	p.y = T.h(p.x, p.z)
	return p


func aamu(_at_m: bool) -> String:
	if kantelu_day < 0 or kantelu_day != game.day - 1:
		return ""
	game.tilat.add("stressi", -0.2)
	game.tilat.add("moraali", -0.1)
	return MORNING


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("rikos_pentti", "tila", {"tavattu": 1 if tavattu else 0, "kyydit": kyydit, "kantelu_day": kantelu_day})


func load_from(cfg: ConfigFile) -> void:
	var d := _ints(cfg.get_value("rikos_pentti", "tila", {}))
	tavattu = d.get("tavattu", 0) == 1
	kyydit = d.get("kyydit", 0)
	kantelu_day = d.get("kantelu_day", -1)


# --- Testi: --scene=bangbus (Saloinen) ja --scene=bangbus_vaala ------------------------------------------------

var _vikoja := 0


func _vika(t: String) -> void:
	_vikoja += 1
	print("TESTI VIKA pentti: " + t)


## n ruutua; kello pidetään kc:ssä (pysäkkiaika), paitsi välikohtauksen ja herätyksen aikana.
func _tf(n: int, kc := -1.0) -> void:
	for i in n:
		if kc >= 0.0 and game.state != "cutscene" and not game.cutscene.busy:
			game.clock_min = kc
		await game.get_tree().process_frame


func _kuva(suffix: String) -> void:
	var path := "user://bangbus%s.png" % suffix
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7).replace(".png", "%s.png" % suffix)
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
	print("BANGBUS kuva " + path)


## Lähikuva omalla kameralla: from -> at (maailman kehys).
func _lahikuva(suffix: String, from: Vector3, at: Vector3, fov := 45.0) -> void:
	var prev: Camera3D = game.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	game.add_child(cam)
	cam.fov = fov
	cam.look_at_from_position(from, at)
	cam.make_current()
	await _tf(3)
	await _kuva(suffix)
	cam.queue_free()
	if prev != null:
		prev.make_current()


func testi(arg: String) -> void:
	_vikoja = 0
	var vaala := arg == "vaala"
	# Päivä torstai: ei paikalla. Perjantai klo 18: ei vielä. Perjantai klo 20: paikalla.
	while game._weekday() != 3:
		game.day += 1
	game.clock_min = 20 * 60
	print("BANGBUS torstai 20: paikalla %s" % paikalla())
	if paikalla():
		_vika("torstaina paikalla")
	game.day += 1
	game.clock_min = 18 * 60
	if paikalla():
		_vika("perjantaina klo 18 paikalla")
	game.clock_min = 20 * 60
	if not paikalla():
		_vika("perjantaina klo 20 ei paikalla")
	var walk: Node3D
	var d: Dictionary
	if vaala:
		game._start_mopo()
		await _tf(30, 20 * 60)
		var mt: Node3D = game.mopo_trip
		var vl: Node3D = mt.vaala
		if vl.pentti_spot == Vector3.INF:
			_vika("Vaalassa ei Pentin paikkaa (vaala.gd pentti_spot)")
			print("BANGBUS testi valmis, %d vikaa" % _vikoja)
			return
		var mp: CharacterBody3D = mt.mopo
		var fwd := Vector3(-sin(vl.pentti_yaw), 0, -cos(vl.pentti_yaw))
		var sp: Vector3 = vl.pentti_spot + fwd * 5.0 + fwd.cross(Vector3.UP) * -1.0
		mp.position = sp + Vector3(0, 0.6, 0)
		mp.speed = 0.0
		await _tf(5, 20 * 60)
		game._mopo_dismount()
		await _tf(20, 20 * 60)
		walk = mt.on_foot
		d = _v
	else:
		if game.player == game.bike:
			game._toggle_mount()
		var c := M.w(M.SHOP_BUILDING)
		game._place_on_foot(c + Vector3(0.0, 0.3, 30.0))
		await _tf(30, 20 * 60)
		walk = game.walker_out
		d = _s
		# Liikenteen Pentti piilossa pysäkin aikana.
		for car in game.get_tree().get_nodes_in_group(TrafficCar.GROUP):
			if car.get("pentti") and car.visible:
				_vika("liikenteen Pentin auto näkyy pysäkkiaikana")
	if d.is_empty() or not (d.root as Node3D).visible:
		_vika("auto ei näy pysäkillä")
		print("BANGBUS testi valmis, %d vikaa" % _vikoja)
		return
	var root: Node3D = d.root
	var pentti: Node3D = d.pentti
	var rb := root.global_basis
	var rc := root.global_position
	print("BANGBUS auto %s, Pentti %s" % [rc, pentti.global_position])
	# Kuvat: viisto edestä, molemmat kyljet (banderolli), perä (verhot), Pentti lähikuvassa.
	await _lahikuva("_auto_vino", rc - rb.z * 7.5 + rb.x * 4.0 + Vector3(0, 2.2, 0), rc + Vector3(0, 1.0, 0))
	await _lahikuva("_kylki_oikea", rc + rb.x * 7.0 + Vector3(0, 1.4, 0), rc + Vector3(0, 1.2, 0), 50.0)
	await _lahikuva("_kylki_vasen", rc - rb.x * 7.0 + Vector3(0, 1.4, 0), rc + Vector3(0, 1.2, 0), 50.0)
	await _lahikuva("_pera", rc + rb.z * 5.5 + rb.x * 1.0 + Vector3(0, 1.6, 0), rc + rb.z * 2.3 + Vector3(0, 1.3, 0))
	await _lahikuva("_ohjaamo", rc - rb.z * 1.3 + rb.x * 2.6 + Vector3(0, 1.8, 0), rc - rb.z * 1.3 + Vector3(0, 1.45, 0), 50.0)
	var pp := pentti.global_position
	var pf: Vector3 = -pentti.global_basis.z
	await _lahikuva("_pentti", pp + pf * 1.6 + Vector3(0, 1.6, 0), pp + Vector3(0, 1.55, 0), 40.0)
	await _lahikuva("_pentti_kasvot", pp + pf * 0.7 + Vector3(0, 1.7, 0), pp + Vector3(0, 1.66, 0), 35.0)
	# Juttelu: pelaaja Pentin eteen, vihje ja keskustelu.
	var stand: Vector3 = pp + (pf * 1.6)
	stand.y = walk.global_position.y
	walk.global_position = stand
	await _tf(10, 20 * 60)
	await _kuva("_juttelu_vihje")
	game._talk_open("pentti", pentti)
	await _tf(3, 20 * 60)
	var ids: Array = game._talk_options().map(func(o: Dictionary) -> String: return o.id)
	print("BANGBUS valinnat %s" % [ids])
	for want in ["pentti_kyyti", "pentti_juttu", "pentti_bangbus", "pentti_ei", "lopeta"]:
		if not want in ids:
			_vika("valinta puuttuu: " + want)
	if not "pentti_tavattu" in game.tilat.firsts:
		_vika("päiväkirjan tehtävä ei tullut tiedoksi (first:pentti_tavattu)")
	# Repliikit eivät toistu ennen kuin pakka on käyty läpi.
	var kuullut: Array = []
	for i in LINES.size():
		var l := seuraava_repliikki()
		if l in kuullut:
			_vika("repliikki toistui pakan sisällä: " + l)
		kuullut.append(l)
	await _kuva("_juttelu")
	game._talk_choose("pentti_juttu")
	await _tf(3, 20 * 60)
	# Kyyti todistajan kanssa: Päivi kuulee aamulla, maine laskee.
	todistaja_pakko = 1
	var day0: int = game.day
	game.maine = 10.0
	var maine0: float = game.maine
	game.money = 50.0
	var kyydit0 := kyydit
	var loppuja0: int = game.endings.counts.get("pentin_kyyti", 0)
	game._talk_choose("pentti_kyyti")
	await _tf(60)
	game.cutscene.test_hold = true
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5500:
		await _tf(1)
	await _kuva("_kyyti")
	game.cutscene.test_hold = false
	t0 = Time.get_ticks_msec()
	while (game.cutscene.busy or game.day == day0) and Time.get_ticks_msec() - t0 < 60000:
		await _tf(1)
	await _tf(40)
	print("BANGBUS kyydin jälkeen: päivä %d -> %d, kello %.0f, rahaa %.2f, maine %.1f -> %.1f, kyydit %d, loppu %d, tila %s" % [
		day0, game.day, game.clock_min, game.money, maine0, game.maine, kyydit,
		game.endings.counts.get("pentin_kyyti", 0), game.state])
	if game.day != day0 + 1:
		_vika("päivä ei vaihtunut kyydin jälkeen")
	if kyydit != kyydit0 + 1:
		_vika("kyydit ei kasvanut")
	if game.money >= 50.0 - RAHAA_POIS.x + 0.01:
		_vika("rahaa ei kadonnut (%.2f)" % game.money)
	if game.maine > maine0 - MAINE_NAHTY + 0.01:
		_vika("maine ei laskenut, vaikka todistaja näki")
	if game.endings.counts.get("pentin_kyyti", 0) != loppuja0 + 1:
		_vika("legendaarinen hetki pentin_kyyti ei kirjautunut")
	if not "pentti_kyyti" in game.tilat.firsts:
		_vika("päiväkirjan tehtävä ei valmistunut (first:pentti_kyyti)")
	if kantelu_day != day0:
		_vika("kantelu ei kirjautunut")
	if not vaala:
		var spot := heratys_paikka(String(WAKE_SALOINEN[(kyydit - 1) % WAKE_SALOINEN.size()][1]))
		var dist: float = game.walker_out.global_position.distance_to(spot)
		print("BANGBUS herätys %.1f m herätyspaikasta" % dist)
		if dist > 3.0:
			_vika("herätys ei oudossa paikassa (%.1f m)" % dist)
	await _kuva("_aamu")
	# Aamurivi: aamu() palauttaa Päivin rivin edellisen päivän kantelusta (tarkistetaan suoraan, rivi luettiin jo).
	var rivi := ""
	kantelu_day = game.day - 1
	rivi = aamu(false)
	if rivi != MORNING:
		_vika("Päivin aamurivi puuttuu")
	kantelu_day = -1
	if aamu(false) != "":
		_vika("aamurivi ilman kantelua")
	# Toinen kyyti: tavallinen, ei uutta legendaarista hetkeä. Kolmas: kiertue (onnellinen loppu), herätys kotipihalta.
	todistaja_pakko = 0
	for nro in [2, 3]:
		while not (game._weekday() in PAIVAT):
			game.day += 1
		await _tf(20, 20 * 60)
		var dd := _nykyinen()
		var hl := hello("pentti")
		var tekstit: Array = []
		for o: Dictionary in game._talk_options("pentti"):
			tekstit.append(o.text)
		print("BANGBUS kyyti %d: tervehdys '%s', valinnat %s" % [nro, hl, tekstit])
		if nro == 2 and hl != HELLO_VIHJE:
			_vika("toisella kerralla ei kiertuevihjettä")
		if nro == 3 and (hl != HELLO_KIERTUE or not tekstit.any(func(x: String) -> bool: return "kiertueelle" in x)):
			_vika("kolmannella kerralla ei kiertuetta tarjolla")
		var hetket: int = game.endings.counts.get("pentin_kyyti", 0)
		var loput: int = game.endings.counts.get("pentin_kiertue", 0)
		var dpv: int = game.day
		game._talk_open("pentti", dd.pentti if not dd.is_empty() and is_instance_valid(dd.pentti) else null)
		await _tf(3, 20 * 60)
		game._talk_choose("pentti_kyyti")
		if nro == 3:
			game.cutscene.test_hold = true
			var tk := Time.get_ticks_msec()
			while Time.get_ticks_msec() - tk < 6500:
				await _tf(1)
			await _kuva("_kiertue")
			game.cutscene.test_hold = false
		var tw := Time.get_ticks_msec()
		while (game.cutscene.busy or game.day == dpv) and Time.get_ticks_msec() - tw < 60000:
			await _tf(1)
		await _tf(40)
		print("BANGBUS kyyti %d jälkeen: päivä %d, hetket %d, kiertueet %d, tila %s" % [nro, game.day,
			game.endings.counts.get("pentin_kyyti", 0), game.endings.counts.get("pentin_kiertue", 0), game.state])
		if game.day != dpv + 1:
			_vika("kyyti %d: päivä ei vaihtunut" % nro)
		if game.endings.counts.get("pentin_kyyti", 0) != hetket:
			_vika("kyyti %d kirjasi uuden legendaarisen hetken (vain ensimmäinen)" % nro)
		if nro == 2 and game.endings.counts.get("pentin_kiertue", 0) != loput:
			_vika("toinen kyyti kirjasi kiertueen")
		if nro == 3:
			if game.endings.counts.get("pentin_kiertue", 0) != loput + 1 or not Endings.is_loppu("pentin_kiertue"):
				_vika("kiertue ei kirjautunut onnelliseksi lopuksi")
			if not vaala:
				var hd: float = game.walker_out.global_position.distance_to(game.home_zone + Vector3(0, 0, 4))
				print("BANGBUS kiertueen herätys %.1f m kotipihasta" % hd)
				if hd > 3.0:
					_vika("kiertueen jälkeen ei herätty kotipihalta (%.1f m)" % hd)
			await _kuva("_kiertue_aamu")
	todistaja_pakko = -1
	# Tallennus edestakaisin.
	var cfg := ConfigFile.new()
	save_to(cfg)
	var k := kyydit
	kyydit = 0
	load_from(cfg)
	if kyydit != k or not tavattu:
		_vika("tallennus ei palauttanut tilaa")
	print("BANGBUS testi valmis, %d vikaa" % _vikoja)
