extends Node3D
## Normipäivä Saloisissa: rakentaa maailman, pyörittää pelin tilaa ja HUDin.
## Tilat: to_shop -> in_shop -> to_home -> won, tai lost missä vaiheessa tahansa.

const B := preload("res://scripts/build.gd")
const PlayerBike := preload("res://scripts/player_bike.gd")
const WifeCar := preload("res://scripts/wife_car.gd")
const Juntti := preload("res://scripts/juntti.gd")
const ShopInterior := preload("res://scripts/shop_interior.gd")

const World := preload("res://scripts/world.gd")
const Minimap := preload("res://scripts/minimap.gd")
const Compass := preload("res://scripts/compass.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Kota := preload("res://scripts/kota.gd")
const Mokki := preload("res://scripts/mokki.gd")
const Fight := preload("res://scripts/fight.gd")
const ChopGame := preload("res://scripts/chop_game.gd")
const SawGame := preload("res://scripts/saw_game.gd")
const BarGame := preload("res://scripts/bar_game.gd")
const LaavuGuard := preload("res://scripts/laavu_guard.gd")
const PaperMap := preload("res://scripts/paper_map.gd")
const Villager := preload("res://scripts/villager.gd")
const Looks := preload("res://scripts/looks.gd")
const Tractor := preload("res://scripts/tractor.gd")
const OnFoot := preload("res://scripts/on_foot.gd")
const Ambience := preload("res://scripts/ambience.gd")
const Cutscene := preload("res://scripts/cutscene.gd")
const Menu := preload("res://scripts/menu.gd")
const Lawn := preload("res://scripts/lawn.gd")
const PoliceCar := preload("res://scripts/police_car.gd")
const PICK_TIME := 2.5  # sienet: pelkkä odotus
## Marjojen poiminta (puolukka, mustikka): kyykky-ylös-näpyttely.
const BERRIES := ["puolukka", "mustikka"]
const PICK_GAIN := 0.075  # oikea painallus oikeaan tahtiin
const PICK_FUMBLE := 0.06  # väärä nappi tai räpellys: marjoja tippuu
const PICK_TOO_FAST := 0.14  # s: nopeampi näpyttely on räpellystä
const PICK_IDLE := 0.8  # s: tauon jälkeen mittari alkaa valua
const PICK_DECAY := 0.12  # mittarin valuminen tauolla (/s)
const GRUNT_GAP_MS := 450  # ähkäisyjen väli vähintään
const BEND_DRAIN := 27.0  # kyykkiminen kuluttaa kuntoa (/s, kumoaa seisomisen palautumisen ja vähän päälle)
const BUCKET_MAX := 8
## Metsän antimet: hinta €/l, ostaja ja nimi.
const GOODS := {
	"puolukka": {"price": 4.0, "buyer": "arto", "name": "puolukoita"},
	"mustikka": {"price": 5.0, "buyer": "arto", "name": "mustikoita"},
	"kantarelli": {"price": 10.0, "buyer": "pekka", "name": "kantarelleja"},
	"herkkutatti": {"price": 8.0, "buyer": "pekka", "name": "herkkutatteja"},
}
const ARTO_LINES := ["Lähekkö puolukkaan?", "Antinsuonkankaalla on puolukkaa ku mettä!", "Mustikkaa löytyy kuusikosta.",
	"Tuu myymään marjat mulle, maksan hyvin!", "Lähekkö huomenna puolukkaan?"]
const PEKKA_LINES := [
	"Perkele, ammuin toissapäivänä neljätoista saatanan kyyhkyä!",
	"Yks oli vittu ihan kalkkunan kokonen, usko pois perkele.",
	"Haulikko lauloi koko helvetin aamun, saatana!",
	"Kyyhkyt ja kantarellikastike, se on perkeleen herkkua.",
	"Tuoppa niitä vitun sieniä, mää ostan kaikki, saatana!",
	"Sanoinko jo perkele että ammuin neljätoista kyyhkyä?",
	"Talvella mää ammun kolmesataa saatanan jänistä!",
	"Kolmesataa jänistä perkele, joka talvi. Pakkaseen ei enää mahdu vittu.",
	"Jäniksiä on niin helvetisti, että ne tulee jo pihalle, saatana!",
	"Tänä talvena voi mennä jo kolmesataaviiskymmentä, perkele."]
const GRILL_TIME := 5.0
const SAVE_PATH := "user://normipaiva.cfg"

const INTERIOR_POS := Vector3(3000, 0, 0)
const MOKKI_POS := Vector3(6000, 0, 0)  # erillinen tasku, tavoitettavissa vain taksilla kotoa
const ZONE_RADIUS := 6.0
const START_MONEY := 20.0
## Taksi K-Marketin taksitolpalta Raahen baariin ja takaisin.
const TAXI_FARE := 14.0  # meno-paluu
const BAR_ROUND := 6.0  # kädenväännön häviäjä tarjoaa kierroksen
const TAXI_RADIUS := 3.5
const BAR_POS := Vector3(0, 0, -4200)  # baarin minipeli kaukana kartan ulkopuolella
const CHOCO_CHANCE := 0.5  # suklaa lepyttää Päivin
const CHOCO_MONEY := 5.0  # leppynyt Päivi antaa aamulla ylimääräistä
const BEER_PRICE := 12.90
const TAXI_PRICE := 20.0
const SAUNA_TALK_RADIUS := 30.0  # etäisyys, jonka sisällä Santun ympäristöpuheet voivat laueta

var world: Node3D
var home_zone: Vector3
var shop_zone: Vector3
var player: CharacterBody3D
var wife: CharacterBody3D
var juntti: CharacterBody3D
var interior: Node3D
var state := "to_shop"
var money := START_MONEY
var beers := 0
var elapsed := 0.0
var wife_alerted := false

var _hazards: Node3D
var _beacon: MeshInstance3D
var _stats: Label
var _status: Label
var _hint: Label
var _msg: Label
var _msg_time := 0.0
var _sus_box: Control
var _sus_bar: ProgressBar
var _bird_t := 2.0
var _minimap: Control
var _compass: Control
var _hud: CanvasLayer
var fight: Node3D
var _fight_prev := ""
var _fight_dir := Vector3.ZERO
var _fight_source := "juntti"  # juntti | laavu
var guard: Node3D
var has_sausage := false
var has_matches := false
## Suklaalevy taskussa: saattaa lepyttää Päivin (salainen mekaniikka, ei vinkkejä pelissä).
var has_chocolate := false
var _choco_mercy := false  # Päivi leppyi WASTED-motkotuksessa: seuraavana aamuna ylimääräistä rahaa
## Raahen reissujen mittarit 0–100 (tallentuvat): mielihyvä ja maine kovana jätkänä.
var mielihyva := 0.0
var maine := 0.0
var _no_allowance := false  # Raahen reissun jälkeen Päivi ei anna aamulla rahaa kauppaan
var _jemma_choco := ""
var fire_lit := false
var sausage_done := false
var _grill_t := -1.0
var bucket := {}  # laji -> litrat
var _pick_t := -1.0
var _pick_spot: Dictionary = {}
var _pick_meter := 0.0  # marjojen poimintamittari 0–1
var _pick_down := false  # kyykyssä: seuraavaksi odotetaan ylös (D)
var _pick_idle := 0.0  # aika edellisestä painalluksesta
var _pick_locked := false  # poiminta otti ohjauksen pois
var _grunt_next := 0  # ms: seuraava ähkäisy aikaisintaan
var arto: CharacterBody3D
var pekka: CharacterBody3D
var tractor: CharacterBody3D
## player = se jolla nyt liikutaan (pyörä tai jalan); bike ja walker_out ovat molemmat olemassa koko ajan.
var bike: CharacterBody3D
var walker_out: CharacterBody3D
var _paper: Control
var _stamina_box: Control
var _stamina_bar: ProgressBar
var _bike_away_t := 0.0
## Paikat, joihin teinit voivat viedä lukitsemattoman pyörän.
const BIKE_DUMPS := [Vector2(560, 1062), Vector2(300, 600), Vector2(640, 160), Vector2(400, 1480), Vector2(160, 640),
	Vector2(760, 1680)]
## Kaljajemmat: id -> kaljat. Säilyvät pelikerrasta toiseen (user://normipaiva.cfg).
## Kotijemmoja Päivi voi löytää (safe = montako mahtuu huomaamatta, find = löytymisherkkyys),
## ulkojemmoista teinit voivat pölliä (steal = todennäköisyys aamulla). cap = kapasiteetti.
const STASHES := {
	"koti": {"name": "eteisen kaappi", "short": "eteinen", "into": "eteisen kaappiin", "from": "eteisen kaapista",
		"home": true, "cap": 24, "safe": 4, "find": 1.5},
	"autotalli": {"name": "autotallin työkalukaappi", "short": "talli", "into": "autotallin työkalukaappiin",
		"from": "autotallin työkalukaapista", "home": true, "cap": 18, "safe": 8, "find": 0.8},
	"komposti": {"name": "kompostin taus", "short": "komposti", "into": "kompostin taakse", "from": "kompostin takaa",
		"home": true, "cap": 12, "safe": 8, "find": 0.4},
	"laavu": {"name": "laavun halkovaja", "short": "laavu", "into": "halkovajan jemmaan", "from": "halkovajan jemmasta",
		"home": false, "cap": 36, "steal": 0.35},
	"grilli": {"name": "grillikatos", "short": "grilli", "into": "grillikatoksen jemmaan", "from": "grillikatoksen jemmasta",
		"home": false, "cap": 24, "steal": 0.3},
	"torni": {"name": "lintutornin alus", "short": "torni", "into": "lintutornin alle", "from": "lintutornin alta",
		"home": false, "cap": 24, "steal": 0.15},
}
var stash := {}
## Jemmat, joita pelaaja on käyttänyt (näytetään paperikartalla).
var stash_used: Array = []
## Pyörä jää sinne, minne sen jättää (myös yön yli ja pelikerrasta toiseen): tallennettu paikka ja suunta.
var _bike_saved = null  # [Vector3, float] tai null
var _old_stash_lost := 0  # vanhan tallennuksen jemmat, jotka menetettiin päivityksessä
## Kotijemmojen summa (onnellinen loppu, kun JEMMA_GOAL täynnä). Asetus tyhjentää kotijemmat ja
## laittaa arvon eteisen kaappiin (testit ja loppukohtaus).
var jemma: int:
	get:
		var n := 0
		for id in STASHES:
			if STASHES[id].home:
				n += stash.get(id, 0)
		return n
	set(v):
		for id in STASHES:
			if STASHES[id].home:
				stash[id] = 0
		stash["koti"] = v
var laavu_conquered := false
var stash_laavu: int:
	get:
		return stash.get("laavu", 0)
	set(v):
		stash["laavu"] = v
var stash_grilli: int:
	get:
		return stash.get("grilli", 0)
	set(v):
		stash["grilli"] = v
var _jemma_found := 0
var jemma_endings := 0
var day := 1
var cutscene: Node3D
var menu: CanvasLayer
var _env: Environment
var _fps_label: Label
var _sun: DirectionalLight3D
static var skip_menu := false  # "Uusi peli" lataa kentän uudelleen ilman alkuvalikkoa
var jemma_best := 0
var jemma_wins := 0
## Nurmikon leikkuu (lawn.gd): kaksi siiliä -> poliisi, kaksi kiveä -> leikkuri rikki (varaosa Artolta + kalja).
const LAWN_DONE := 0.9  # tämä osuus leikattuna = valmis
const LAWN_PART_PRICE := 8.0
const LAWN_BONUS := 5.0  # leikatusta nurmikosta Päivi antaa aamulla ylimääräistä
const LAWN_NAG_PAIVI := ["Se nurmikko ei leikkaa itseään!", "Takapiha näyttää ihan heinäpellolta.",
	"Leikkaa nyt se nurmikko ennen kuin lähet mihinkään!"]
const LAWN_NAG_ANNALIISA := ["Teillä on siellä kohta ihan heinäpelto!", "Siilit on muuttanu teidän nurmikolle asumaan.",
	"Meillä leikataan nurmikko joka lauantai, niin sitä vaan."]
## Pannu-Sulon pontikkakanisteri metsästä: vastaa kotijemmassa 24 kaljaa. Yksi kanisteri päivässä.
const KANISTER_BEERS := 24
const KANISTER_PRICE := 20.0
const SULO_LINES := ["Ei kuulu kellekään, mitä täällä tehdään.", "Kakskymppiä kanisteri, ja suu suppuun.",
	"Sokeria, hiivaa ja kärsivällisyyttä. Siinä se resepti.", "Ootko sää poliisi? Et näytä poliisilta.",
	"Tää on vanhan ajan tavaraa, ei mitään Alkon litkua.", "Kuka sulle tästä paikasta kerto? Raimo, vai?"]
## Sivutehtävä: Pekan koira Väinö karkaa (dog.gd). Palautus Pekalle: vitonen ja kalja.
const Dog := preload("res://scripts/dog.gd")
const VAINO_CHANCE := 0.2  # osuus päivistä, joina Väinö karkaa
const VAINO_MONEY := 5.0
## Vieras koira metsänreunassa puree (stray_dog.gd). Haava hoidetaan kotikonstein: Pekka (kalja tai
## PEKKA_CARE €) tai Päivi kotona (ilmainen, mutta motkottaa). Hoitamaton haitta kestää päivän loppuun.
const StrayDog := preload("res://scripts/stray_dog.gd")
const Mummot := preload("res://scripts/mummot.gd")
var mummot: Node3D
const PEKKA_CARE := 3.0
const WOUND_PAIVI := ["Taas sää oot ollu vieraitten koirien kans!", "Istu siihen. Ja älä vingu.",
	"Ei ne koirat ite purase, jos niitä ei mene rapsuttelemaan."]
## Päivin kauppalista (muistipeli, #12): Päivi sanoo tuotteet väreineen kerran, lista näyttää vain tuotteet.
## Tuotteet haetaan kaupan Päivin hyllystä (shop_interior.gd) ja tarkistetaan kotona.
const LIST_SIZE := 4
var shopping_list: Array = []  # [[tuote, väri], ...]
var paivi_bag := {}  # kaupasta tuodut: tuote -> väri
var _list_done := false
var _kaljarauha := false  # kaikki oikein: Päivi ei etsi jemmoja seuraavana aamuna
var _msg_queue: Array = []
var stray: CharacterBody3D
var bitten := false
var vaino: CharacterBody3D
var _vaino_at := -1.0  # päivän aika (elapsed), jolloin Väinö karkaa; -1 = ei tänään
var sulo: CharacterBody3D
var has_kanister := false
var _sulo_sold := false  # tämän päivän kanisteri on jo myyty
var lawn: Node3D
var police: CharacterBody3D
var mowing := false
var lawn_siilit := 0  # yliajetut siilit (toinen tuo poliisin)
var lawn_kivet := 0  # kivet terässä (toinen rikkoo leikkurin)
var mower_broken := false
var has_mower_part := false
var _lawn_praise := false  # nurmikko leikattu: aamulla ylimääräistä rahaa
var _lawn_done_today := false
var mokki: Node3D
var _santtu_chat_t := 6.0
var _fish_state := "idle"  # idle | waiting | bite
var _fish_t := 0.0
var _fish_target := 0.0


func _ready() -> void:
	randomize()
	_setup_input()
	_setup_environment()
	world = World.new()
	add_child(world)
	home_zone = world.home_zone
	shop_zone = world.shop_zone
	lawn = Lawn.new()
	lawn.rect = world.lawn_rect
	lawn.mower_park = M.w(M.MOWER_PARK)
	add_child(lawn)
	_build_markers()
	_build_stash_props()
	_spawn_player()
	world.follow = player
	player.world = world
	_spawn_hazards()
	_spawn_interior()
	mokki = Mokki.new()
	mokki.position = MOKKI_POS
	add_child(mokki)
	fight = Fight.new()
	fight.position = Vector3(-3000, 0, 0)
	add_child(fight)
	fight.finished.connect(_on_fight_finished)
	var map_layer := CanvasLayer.new()
	map_layer.layer = 10
	add_child(map_layer)
	var paper := PaperMap.new()
	paper.world = world
	paper.player = player
	paper.game = self
	paper.mokki = mokki
	map_layer.add_child(paper)
	_paper = paper
	var amb := Ambience.new()
	amb.world = world
	amb.player_ref = func() -> Node3D: return player if state in ["to_shop", "to_home"] else null
	add_child(amb)
	paper.bike = bike
	_build_hud()
	cutscene = Cutscene.new()
	cutscene.env = _env
	cutscene.sun = _sun
	cutscene.hide_nodes = [bike, walker_out]
	add_child(cutscene)
	_load_game()
	lawn.spawn_objects()
	_roll_vaino()
	if laavu_conquered:
		guard.vanish()
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	menu = Menu.new()
	menu.game = self
	add_child(menu)
	var debug_shot := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot=") and not arg.ends_with("menu.png"):
			debug_shot = true
	Sfx.music_stop(0.8)  # esim. "Uusi peli" latasi kentän valikosta: musiikki pois, ellei valikko aukea
	if not skip_menu and not debug_shot:
		menu.open_main()
	skip_menu = false
	var bike_note := "" if debug_shot else _apply_saved_bike()  # testikuvat alkavat aina pyörän selästä kotoa
	var jemma_note := ("\nVaroitus: Päivi voi löytää täyden kotijemman!") if not _risky_stashes().is_empty() else ""
	if _old_stash_lost > 0:
		jemma_note += "\nPäivi löysi vanhat jemmat ja kaatoi %d kaljaa viemäriin! Nyt jemmoja on enemmän – jaa kaljat fiksusti." % _old_stash_lost
		_old_stash_lost = 0
		_save_game()
	if Settings.renderer_auto_saved:
		jemma_note += "\nYhteensopiva grafiikka on nyt käytössä myös tavallisella käynnistyksellä (vaihda Asetuksista)."
	jemma_note = bike_note + jemma_note + _lawn_nag()
	_show_message("Päivä %d · Järvikuja 1, Saloinen.\nPitäis käydä kaupassa... Aja K-Marketille!%s%s" % [day, 
		("\nJemmassa %d kaljaa." % jemma) if jemma > 0 else "", jemma_note], 5.0 if jemma_note == "" else 6.0)
	_roll_list()
	_tell_list()
	_maybe_screenshot()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		skip_menu = true
		get_tree().reload_current_scene()
		return

	if state in ["to_shop", "in_shop", "to_home", "fight"]:
		elapsed += delta

	_hint.text = ""
	match state:
		"to_shop", "to_home":
			_outside_logic()
			_mount_logic()
			_bike_theft(delta)
		"in_shop":
			_hint.text = interior.hint
	_update_hud()

	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			_msg.text = ""
	elif not _msg_queue.is_empty() and _hud.visible:
		var m: Array = _msg_queue.pop_front()
		_show_message(m[0], m[1])


## Lukitsematon pyörä: jos se on pitkään kaukana (ei kotipihassa), teinit vievät sen muualle.
func _bike_theft(delta: float) -> void:
	if player != walker_out:
		_bike_away_t = 0.0
		return
	var d := walker_out.global_position.distance_to(bike.global_position)
	var at_home := bike.global_position.distance_to(home_zone) < 25.0
	if d > 150.0 and not at_home:
		_bike_away_t += delta
	else:
		_bike_away_t = maxf(0.0, _bike_away_t - delta)
	if _bike_away_t > 60.0:
		_bike_away_t = 0.0
		if randf() < 0.6:
			var best := Vector3.ZERO
			var bd := -1.0
			for i in 3:
				var cand := M.w(BIKE_DUMPS.pick_random())
				var cd := cand.distance_to(walker_out.global_position)
				if cd > bd:
					bd = cd
					best = cand
			bike.global_position = best + Vector3(0, 0.3, 0)
			bike.rotation.y = randf() * TAU
			_show_message("Teinit veivät lukitsemattoman pyöräsi!\nKatso kartasta (M), minne se jäi.", 4.0)
			Sfx.play("alert", -4.0, 0.7)


func _mount_logic() -> void:
	var e: bool = Input.is_action_just_pressed("mount") and not player.is_stunned()
	if player == walker_out:
		var d: float = walker_out.global_position.distance_to(bike.global_position)
		if d < 2.6:
			if _hint.text == "":
				_hint.text = "[F] Nouse pyörän selkään" if beers <= CARRY_BIKE else \
					"Pyörän kyytiin mahtuu vain %d kaljaa (sinulla %d). Jemmaa tai juo loput." % [CARRY_BIKE, beers]
			if e:
				if beers > CARRY_BIKE:
					_show_message("Liikaa kaljaa pyörän kyytiin! Max %d, sinulla %d." % [CARRY_BIKE, beers], 2.5)
				else:
					_toggle_mount()
		elif e:
			_show_message("Pyörä on %d metrin päässä." % int(d), 1.5)
	elif e:
		_toggle_mount()


func _outside_logic() -> void:
	var target := shop_zone if state == "to_shop" else home_zone
	var ppos := player.global_position
	var dist := Vector2(ppos.x, ppos.z).distance_to(Vector2(target.x, target.z))  # vaakaetäisyys (maasto ei vaikuta)

	_beacon.position = Vector3(target.x, Terrain.h(target.x, target.z) + 20.0, target.z)  # alkaa maan pinnasta
	# Kompassin kohde poistuu, kun sinne päästään.
	if _paper.has_target and Vector2(ppos.x, ppos.z).distance_to(_paper.target) < 10.0:
		_paper.clear_target()
		Sfx.play("pickup", -10.0, 1.3)

	_lawn_logic()
	if player == bike and Input.is_action_just_pressed("bell") and mummot.distance_to_target() < 10.0:
		mummot.anger()  # kellon soitto mummojen vieressä suututtaa varmasti
	_edge_logic()
	_kota_logic()
	_laavu_logic()
	_stash_logic()
	_forage_logic()
	_wound_logic()
	_errand_logic()
	_vaino_logic()
	_neighbor_logic()
	_pontikka_logic()
	_taxi_logic()
	_mokki_taxi_logic()
	_mokki_logic()
	if dist >= ZONE_RADIUS:
		return
	if player == bike:
		_hint.text = "Nouse pyörän selästä (F) ja kävele %s" % ("kauppaan" if state == "to_shop" else "ovelle")
		return
	if state == "to_shop":
		if beers + 6 > CARRY_FOOT:
			_hint.text = "Kädet täynnä kaljaa (%d). Kuutonen ei enää mahdu kantoon – jemmaa ensin." % beers
			return
		_hint.text = "[E] Mene kauppaan"
		if Input.is_action_just_pressed("interact") and not player.is_stunned():
			_enter_shop()
	else:
		_win()


## Jemmat: jalan E piilottaa yhden kaljan (Shift+E kaikki), Q ottaa yhden (Shift+Q niin monta kuin jaksaa kantaa,
## jalan enintään 12).
func _stash_logic() -> void:
	if _hint.text != "" or player != walker_out or player.is_stunned():
		return
	var p := player.global_position
	for id in STASHES:
		var at := _stash_pos(id)
		if Vector2(p.x - at.x, p.z - at.z).length() > 2.6:
			continue
		if id == "koti" and state == "to_home":
			return  # kotiinpaluu hoitaa saaliin
		if id == "laavu" and not laavu_conquered:
			return
		var st: Dictionary = STASHES[id]
		var have: int = stash.get(id, 0)
		var room: int = maxi(0, st.cap - have)
		var can_take := mini(CARRY_FOOT - beers, have)
		var all := Input.is_key_pressed(KEY_SHIFT)
		var opts: Array[String] = []
		if beers > 0 and room > 0:
			opts.append("[E] Piilota 1 · Shift+E %d" % mini(beers, room))
		if can_take > 0:
			opts.append("[Q] Ota 1 · Shift+Q %d" % can_take)
		var head := "%s: %d/%d kaljaa" % [st.name.left(1).to_upper() + st.name.substr(1), have, st.cap]
		if opts.is_empty():
			_hint.text = head + (" – täynnä." if room == 0 and beers > 0 else (" – kädet täynnä." if have > 0 else " – tänne voi piilottaa kaljoja."))
			return
		_hint.text = head + "   " + "   ".join(opts)
		if Input.is_action_just_pressed("interact") and beers > 0 and room > 0:
			var n := mini(beers, room) if all else 1
			_stash_add(id, n)
			beers -= n
			player.set_carrying(beers > 0)
			Sfx.play("pickup", -2.0, 0.8)
			if all or beers == 0:
				_show_message("Piilotit %d kaljaa %s (siellä %d).%s" % [n, st.into, stash[id], _stash_warning(id)], 3.0)
		elif Input.is_action_just_pressed("bell") and can_take > 0:
			var n := can_take if all else 1
			_stash_add(id, -n)
			beers += n
			player.set_carrying(true)
			Sfx.play("pickup")
			if all:
				_show_message("Otit %d kaljaa %s.%s" % [n, st.from,
					("\nPyörän kyytiin mahtuu vain %d." % CARRY_BIKE) if beers > CARRY_BIKE else ""], 3.0)
		return


## Jemman paikka maailmassa.
func _stash_pos(id: String) -> Vector3:
	match id:
		"koti":
			return home_zone + Vector3(4.0, 0, -2.0)
		"autotalli":
			return M.w(M.GARAGE) + Vector3(-3.8, 0, 3.6)
		"komposti":
			return M.w(M.COMPOST)
		"laavu":
			return M.w(M.LAAVU) + Vector3(4.6, 0, 2.8)
		"grilli":
			return M.w(M.GRILLIKATOS)
		"torni":
			return world.kota.to_global(Kota.TOWER_LOCAL) if world.kota != null else M.w(M.KOTA)
	return Vector3.ZERO


func _stash_add(id: String, n: int) -> void:
	stash[id] = maxi(0, stash.get(id, 0) + n)
	if n > 0 and not id in stash_used:
		stash_used.append(id)
	jemma_best = maxi(jemma_best, jemma)
	_save_game()


## Päivin löytämisriski yhdelle kotijemmalle (0, jos jemmassa on vain huomaamaton määrä).
func _find_chance(id: String) -> float:
	var st: Dictionary = STASHES[id]
	var over: int = stash.get(id, 0) - st.safe
	return clampf(over * 0.04 * st.find, 0.0, 0.5) if over > 0 else 0.0


## Kotijemmat, joissa on jo riskialtis määrä kaljaa.
func _risky_stashes() -> Array[String]:
	var out: Array[String] = []
	for id in STASHES:
		if STASHES[id].home and _find_chance(id) > 0.0:
			out.append(id)
	return out


func _stash_warning(id: String) -> String:
	if STASHES[id].home:
		if _find_chance(id) > 0.0:
			return "\nVAROITUS: %s on jo niin täynnä, että Päivi voi löytää sen! Jaa kaljat muihin jemmoihin." % STASHES[id].name
		return ""
	return "\nMuista: teinit voivat pölliä täältä."


## Paperikartan jemmamerkit: [maailman x/z, lyhyt nimi, kaljat, kotijemma].
func stash_markers() -> Array:
	var out := []
	for id in stash_used:
		if STASHES.has(id):
			var at := _stash_pos(id)
			out.append([Vector2(at.x, at.z), STASHES[id].short, stash.get(id, 0), STASHES[id].home])
	return out


## Kompostilaatikko kotipihalle (jemma).
func _build_stash_props() -> void:
	var cp := M.w(M.COMPOST)
	var wood := Color(0.42, 0.3, 0.18)
	var comp := B.box(self, Vector3(1.4, 0.9, 1.4), cp + Vector3(0, 0.45, 0), wood)
	for k in 4:
		B.mesh(comp, B.boxm(Vector3(1.46, 0.06, 1.46)), Vector3(0, -0.35 + k * 0.22, 0), wood.darkened(0.25))
	B.mesh(comp, B.boxm(Vector3(1.3, 0.05, 1.3)), Vector3(0, 0.44, 0), Color(0.25, 0.2, 0.12))


func _bucket_total() -> int:
	var t := 0
	for k in bucket:
		t += bucket[k]
	return t


## Marja- ja sienipaikat: pysähdy mättään viereen ja poimi E:llä.
func _forage_logic() -> void:
	var p := player.global_position
	if _pick_t >= 0.0:
		var dt := get_process_delta_time()
		_pick_t += dt
		var sd := Vector2(_pick_spot.pos.x - p.x, _pick_spot.pos.z - p.z).length()
		if sd > 4.5 or player != walker_out:
			_stop_picking()
			return
		if _pick_spot.kind in BERRIES:
			_pick_berries(dt)
			return
		_hint.text = "Poimitaan %s... %d" % [GOODS[_pick_spot.kind].name, ceili(PICK_TIME - _pick_t)]
		if _pick_t >= PICK_TIME:
			_pick_done()
		return
	if _hint.text != "":
		return
	var near: Array = world.nearest_forage(p)
	if near[0].is_empty() or near[1] > 3.2:
		return
	var f: Dictionary = near[0]
	if player == bike:
		_hint.text = "Täällä on %s! Nouse pyörän selästä poimimaan (F)." % GOODS[f.kind].name
		return
	if _bucket_total() >= BUCKET_MAX:
		_hint.text = "Ämpäri täynnä (%d l). Myy naapureille!" % BUCKET_MAX
	else:
		_hint.text = "[E] Poimi %s" % GOODS[f.kind].name
		if Input.is_action_just_pressed("interact") and not player.is_stunned():
			_pick_t = 0.0
			_pick_spot = f
			player.speed = 0.0
			if f.kind in BERRIES:
				# A/D ovat poimiessa kyykky ja ylös, joten hahmo ei käänny niistä.
				_pick_meter = 0.0
				_pick_down = false
				_pick_idle = PICK_IDLE
				_pick_locked = true
				walker_out.controls_enabled = false
			else:
				_grunt()  # kumartuu sienen luo


## Ähkäisy kumartuessa tai noustessa (chance = todennäköisyys); lyhyt tauko ettei ähinä mene päällekkäin.
func _grunt(chance := 1.0) -> void:
	if Time.get_ticks_msec() < _grunt_next or randf() > chance:
		return
	_grunt_next = Time.get_ticks_msec() + GRUNT_GAP_MS
	Sfx.play("grunt", -6.0, randf_range(0.92, 1.08))


## Marjat: kyykkyyn (A) ja ylös (D) vuorotellen oikeaan tahtiin täyttää poimintamittarin. Väärä nappi tai
## hätäinen räpellys pudottaa marjoja, tauolla mittari valuu. Kyykkiminen kuluttaa kuntoa, ja tyhjällä
## kunnolla selkä pakottaa tauolle. W/S lopettaa.
func _pick_berries(dt: float) -> void:
	if Input.is_action_just_pressed("forward") or Input.is_action_just_pressed("back"):
		_stop_picking()
		return
	var goods: String = GOODS[_pick_spot.kind].name
	_pick_idle += dt
	if walker_out.exhausted:
		walker_out.pose = ""
		_hint.text = "Selkä! Suorista hetki ennen kuin jatkat %s poimintaa. (W/S lopettaa)" % goods
		return
	walker_out.stamina = maxf(0.0, walker_out.stamina - BEND_DRAIN * dt)
	if walker_out.stamina <= 0.0:
		walker_out.exhausted = true
		walker_out.pose = ""
		_show_message("Oho, selkä! Pakko pitää tauko.", 1.5)
		Sfx.play("groan", -2.0)
		return
	var want := "right" if _pick_down else "left"
	var other := "left" if _pick_down else "right"
	if Input.is_action_just_pressed(want):
		if _pick_idle < PICK_TOO_FAST:
			_pick_meter -= PICK_FUMBLE
		else:
			_pick_meter += PICK_GAIN
		_grunt(lerpf(0.25, 0.8, 1.0 - walker_out.stamina / 100.0))  # väsyneenä ähistään tiheämmin
		_pick_down = not _pick_down
		walker_out.pose = "Crouch_Idle" if _pick_down else ""
		_pick_idle = 0.0
	elif Input.is_action_just_pressed(other):
		_pick_meter -= PICK_FUMBLE
		_pick_idle = 0.0
		Sfx.play("rattle", -12.0, 1.4)
	elif _pick_idle > PICK_IDLE:
		_pick_meter -= PICK_DECAY * dt
	_pick_meter = clampf(_pick_meter, 0.0, 1.0)
	var bar := "▮".repeat(roundi(_pick_meter * 10.0)) + "▯".repeat(10 - roundi(_pick_meter * 10.0))
	_hint.text = "Poimitaan %s %s   %s   (W/S lopettaa)" % [goods, bar, "[D] ylös" if _pick_down else "[A] kyykkyyn"]
	if _pick_meter >= 1.0:
		_pick_done()


func _pick_done() -> void:
	var liters: int = mini(world.FORAGE_KINDS[_pick_spot.kind].liters, BUCKET_MAX - _bucket_total())
	bucket[_pick_spot.kind] = bucket.get(_pick_spot.kind, 0) + liters
	_pick_spot.taken = true
	_pick_spot.node.visible = false
	_show_message("+%d l %s ämpäriin" % [liters, GOODS[_pick_spot.kind].name], 2.0)
	Sfx.play("pickup", -4.0, 1.2)
	if not (_pick_spot.kind in BERRIES):
		_grunt()  # nousee ylös sienen kanssa
	_stop_picking()


## Poiminta loppuu. restore = palauta ohjaus (ei, jos tappelu tai uusi päivä hoitaa sen).
func _stop_picking(restore := true) -> void:
	_pick_t = -1.0
	walker_out.pose = ""
	if _pick_locked and restore:
		walker_out.controls_enabled = true
	_pick_locked = false


## Nurmikon leikkuu: leikkurin luona E käynnistää ja E sammuttaa. Siili tai kivi terään on ikävä juttu.
func _lawn_logic() -> void:
	if mowing:
		_mow()
		return
	if _hint.text != "" or player != walker_out or player.is_stunned():
		return
	var p := player.global_position
	var mp: Vector3 = lawn.mower.global_position
	if Vector2(p.x - mp.x, p.z - mp.z).length() > 1.6:
		return
	var e := Input.is_action_just_pressed("interact")
	if mower_broken:
		if not has_mower_part:
			_hint.text = "Leikkuri on rikki. Varaosa Artolta ja kalja, niin korjataan."
		elif beers <= 0:
			_hint.text = "Varaosa on, mutta ilman kaljaa ei korjata. Kalja kaupasta tai jemmasta."
		else:
			_hint.text = "[E] Korjaa leikkuri (kalja samalla)"
			if e:
				mower_broken = false
				has_mower_part = false
				lawn_kivet = 0
				beers -= 1
				player.set_carrying(beers > 0)
				Sfx.play("rattle_hard", -4.0, 1.2)
				_show_message("Uusi terä paikalleen ja kalja naamaan. Leikkuri toimii!", 3.0)
				_save_game()
		return
	var ratio: float = lawn.cut_ratio()
	var cm := roundi(lawn.avg_len() * 100.0)
	if ratio >= LAWN_DONE:
		_hint.text = "Nurmikko on leikattu. Huomenna se on taas pidempi."
		return
	_hint.text = "[E] Leikkaa nurmikko (%d cm, leikattu %d %%)" % [cm, roundi(ratio * 100.0)]
	if e:
		_start_mowing()


func _start_mowing() -> void:
	mowing = true
	walker_out.no_run = true
	walker_out.rotation.y = lawn.mower.rotation.y
	walker_out.global_position = lawn.mower.global_position + lawn.mower.global_transform.basis.z * Lawn.HEAD + Vector3(0, 0.3, 0)
	walker_out.velocity = Vector3.ZERO
	lawn.set_running(true)
	Sfx.play("pedal_creak", -4.0, 0.6)
	_show_message("Leikkuri käy! Katso tarkkaan: pitkässä ruohossa on siilejä ja kiviä.", 3.0)


## Leikkuri sammuu ja jää siihen, missä se on.
func _stop_mowing() -> void:
	if not mowing:
		return
	mowing = false
	walker_out.no_run = false
	lawn.set_running(false)


func _mow() -> void:
	lawn.push_mower(walker_out)
	if not lawn.has_point(walker_out.global_position, 3.0):
		_stop_mowing()
		_show_message("Leikkuri jäi pihan reunalle.", 2.0)
		return
	var head: Vector2 = lawn.head_pos()
	var hit: Dictionary = lawn.hit_test(head)
	if not hit.is_empty():
		_lawn_hit(hit)
		if not mowing:
			return
	lawn.cut(head, Lawn.BLADE_R)
	var ratio: float = lawn.cut_ratio()
	if ratio >= LAWN_DONE and not _lawn_done_today:
		_lawn_done_today = true
		_lawn_praise = true
		_stop_mowing()
		Sfx.play("win_small")
		_show_message("Nurmikko leikattu! Päivi on tyytyväinen.\nHuomenna tulee %s € ylimääräistä kauppaan." % _eur(LAWN_BONUS), 4.0)
		_save_game()
		return
	_hint.text = "Leikataan... %d %%   W/S/A/D ohjaa · [E] sammuta" % roundi(ratio * 100.0)
	if Input.is_action_just_pressed("interact"):
		_stop_mowing()


## Terä osui siiliin tai kiveen. Toinen siili tuo poliisin, toinen kivi rikkoo leikkurin.
func _lawn_hit(o: Dictionary) -> void:
	lawn.remove_object(o)
	if o.kind == "kivi":
		lawn_kivet += 1
		Sfx.play("rattle_hard", 0.0, 0.8)
		if lawn_kivet >= 2:
			mower_broken = true
			_stop_mowing()
			_show_message("KRÄKS! Terä vääntyi ja leikkuri hajosi.\nHae varaosa Artolta ja kaljaa, niin korjataan.", 4.5)
		else:
			lawn.cough()
			_show_message("KOLAHDUS! Kivi terään, leikkuri yskii.", 2.5)
	else:
		lawn_siilit += 1
		Sfx.play("pedal_squeak", 0.0, 1.8)
		if lawn_siilit >= 2:
			lawn_siilit = 0
			_stop_mowing()
			_call_police()
		else:
			_show_message("Voi ei, siili jäi leikkurin alle...\nHuono omatunto. Katso tarkemmin, mihin ajat.", 3.5)
	_save_game()


## Eläinsuojelurikos: poliisiauto lähtee tieverkolta noin 150 metrin päästä, jotta ehtii karkuun.
func _call_police() -> void:
	if police != null and is_instance_valid(police):
		return
	var p := player.global_position
	var start := 0
	var best := INF
	for i in world.graph_nodes.size():
		var d := absf(world.graph_nodes[i].distance_to(p) - 150.0)
		if d < best:
			best = d
			start = i
	police = PoliceCar.new()
	_hazards.add_child(police)
	police.setup(world.graph_nodes, world.graph_adj, start, player)
	police.world = world
	police.caught.connect(func() -> void:
		if state in ["to_shop", "to_home"]:
			_lose("Poliisi pidätti: eläinsuojelurikos!", "police"))
	police.escaped.connect(func() -> void:
		_show_message("Pääsit karkuun! Poliisi luovutti... tällä kertaa.", 3.5))
	police.start_chase()
	Sfx.play("alert", 0.0, 0.8)
	_show_message("TOINEN SIILI! Anna-Liisa soitti poliisit.\nPOLIISI TULEE – KARKUUN!", 4.0)


## Aamun motkotus pitkästä nurmikosta (Päivi, pidemmästä myös naapurin Anna-Liisa).
func _lawn_nag() -> String:
	var avg: float = lawn.avg_len()
	var s := ""
	if avg >= 0.35:
		s += "\nPäivi: \"%s\"" % LAWN_NAG_PAIVI.pick_random()
	if avg >= 0.5:
		s += "\nAnna-Liisa aidan takaa: \"%s\"" % LAWN_NAG_ANNALIISA.pick_random()
	return s


## Uusi kauppalista: neljä eri tuotetta, kullekin väri.
func _roll_list() -> void:
	var prods: Array = ShopInterior.PRODUCTS.keys()
	prods.shuffle()
	shopping_list.clear()
	for i in LIST_SIZE:
		shopping_list.append([prods[i], ShopInterior.COLORS.keys().pick_random()])
	paivi_bag = {}
	_list_done = false


## Päivi luettelee listan kerran (viestijonossa päivän aloitusviestin jälkeen).
func _tell_list() -> void:
	var said: Array[String] = []
	for it in shopping_list:
		said.append("%s %s" % [it[1], it[0]])
	var text := ", ".join(said.slice(0, said.size() - 1)) + " ja " + said[-1]
	_queue_message("Päivi: \"Tuo kaupasta %s.\"\nKauppalistaan hän kirjoitti vain tuotteet. Muista värit!" % text, 7.0)


## Ostosten tarkistus: palauttaa Päivin repliikit. Kaikki oikein -> kaljarauha.
func _check_list() -> Array[String]:
	_list_done = true
	var lines: Array[String] = []
	var big := false
	var wanted := {}
	for it in shopping_list:
		wanted[it[0]] = it[1]
		if not paivi_bag.has(it[0]):
			lines.append("%s puuttuu kokonaan!" % it[0].capitalize())
			big = true
		elif paivi_bag[it[0]] != it[1]:
			lines.append("Mä sanoin %s %s, ei %s!" % [it[1].to_upper(), it[0], paivi_bag[it[0]]])
	for prod in paivi_bag:
		if not wanted.has(prod):
			lines.append("Ei ollu listalla: %s %s! Mitä mää tuolla teen?" % [paivi_bag[prod], prod])
			big = true
	paivi_bag = {}
	if lines.is_empty():
		_kaljarauha = true
		Sfx.play("win_small")
		return ["Päivi: \"Kaikki oikein! No niin, kyllä sää osaat.\"\nKaljarauha: Päivi ei etsi jemmoja huomenna."]
	if big:
		lines.push_front("Eihän tässä oo mitään järkeä!")
	var out: Array[String] = []
	for l in lines:
		out.append("Päivi: \"%s\"" % l)
	return out


## Ostokset Päiville kotiovella (ilman kuutosta; kotiinpaluu kuutosen kanssa tarkistaa ne _win():ssä).
func _errand_logic() -> void:
	if _list_done or paivi_bag.is_empty() or _hint.text != "" or state != "to_shop" or player != walker_out:
		return
	var p := player.global_position
	if Vector2(p.x - home_zone.x, p.z - home_zone.z).length() > ZONE_RADIUS:
		return
	_hint.text = "[E] Anna ostokset Päiville"
	if Input.is_action_just_pressed("interact"):
		for l in _check_list():
			_queue_message(l, 3.0)
		player.set_carrying(beers > 0)


## Vieras koira puri: kaatuu, ja jalka ontuu, kunnes haava hoidetaan.
func _on_bitten(direction: Vector3) -> void:
	if not (state in ["to_shop", "to_home"]):
		return
	_stop_picking()
	_stop_mowing()
	player.stun(direction)
	Sfx.play("groan", 0.0)
	if bitten:
		_show_message("AI! Sama koira puri uudestaan!", 2.5)
		return
	bitten = true
	walker_out.hurt = true
	_show_message("AI PERKELE! Vieras koira puri pohkeeseen!\nHaava pitää hoitaa: Pekka osaa, tai Päivi kotona.", 4.0)


## Haavan hoito kotona: Päivi puhdistaa ja laittaa laastarin, mutta motkottaa (kotiovella, kun ei olla tulossa
## kaupasta; kotiinpaluu kuutosen kanssa aloittaa uuden päivän, joka hoitaa haavan joka tapauksessa).
func _wound_logic() -> void:
	if not bitten or _hint.text != "" or state != "to_shop" or player != walker_out or player.is_stunned():
		return
	var p := player.global_position
	if Vector2(p.x - home_zone.x, p.z - home_zone.z).length() > ZONE_RADIUS:
		return
	_hint.text = "[E] Mene sisälle, Päivi hoitaa haavan"
	if Input.is_action_just_pressed("interact"):
		_heal()
		Sfx.play("door", -3.0)
		_show_message("Päivi: \"%s\"\nPäivi puhdisti haavan ja laittoi laastarin." % WOUND_PAIVI.pick_random(), 4.0)


func _heal() -> void:
	bitten = false
	walker_out.hurt = false


## Arvotaan, karkaako Väinö tänään ja milloin.
func _roll_vaino() -> void:
	_vaino_at = randf_range(40.0, 180.0) if randf() < VAINO_CHANCE else -1.0


## Väinö karkuteillä: Pekan huuto, kiinniotto jalan (nuuhkiessa tai makkaralla houkuteltuna) ja palautus.
func _vaino_logic() -> void:
	if _vaino_at >= 0.0 and elapsed >= _vaino_at:
		_vaino_at = -1.0
		_vaino_escape()
	if not is_instance_valid(vaino):
		return
	vaino.lure = has_sausage and player == walker_out
	if _hint.text != "" or player.is_stunned():
		return
	var e := Input.is_action_just_pressed("interact")
	if vaino.mode == "follow":
		if pekka.distance_to_player() > 4.2:
			return
		if player == bike:
			_hint.text = "Nouse pyörän selästä (F), niin voit palauttaa Väinön Pekalle."
			return
		if vaino.distance_to_target() > 6.0:
			_hint.text = "Väinö jäi jälkeen. Odota, että se ehtii perään."
			return
		_hint.text = "[E] Palauta Väinö Pekalle"
		if e:
			vaino.queue_free()
			vaino = null
			money += VAINO_MONEY
			var beer := beers < CARRY_FOOT
			if beer:
				beers += 1
				player.set_carrying(true)
			pekka.say("Hyvä poika! Siis Väinö. Tässä vitonen%s." % (" ja kalja" if beer else ""))
			Sfx.play("win_small")
			_show_message("Väinö kotona! Pekka antoi %s €%s." % [_eur(VAINO_MONEY), " ja kaljan" if beer else ""], 3.5)
		return
	if vaino.distance_to_target() > 2.4:
		return
	if player == bike:
		_hint.text = "Nouse pyörän selästä (F), niin saat Väinön kiinni."
	elif vaino.is_catchable():
		_hint.text = "[E] Ota Väinö kiinni"
		if e:
			vaino.catch()
			var ate: bool = has_sausage and vaino.lure  # houkuteltu makkaralla
			if ate:
				has_sausage = false
				sausage_done = false
			_show_message("Sait Väinön kiinni!%s Vie se Pekalle." % (" Se söi makkaran." if ate else ""), 3.0)


## Väinö pääsee karkuun Pekan pihalta. Huuto kuuluu Pattijoelle asti.
func _vaino_escape() -> void:
	vaino = Dog.new()
	var start := M.w(M.PEKKA_POS) + Vector3(2.0, 0.0, 2.0)
	vaino.position = start
	vaino.target = player
	vaino.world = world
	vaino.home = start
	_hazards.add_child(vaino)
	var a := randf() * TAU
	vaino.bolt(Vector3(cos(a), 0, sin(a)), randf_range(15.0, 25.0))
	pekka.say("VÄINÖ PERKELE!")
	Sfx.play("dog", 0.0, 0.95)
	Sfx.play("alert", -6.0, 0.6)
	_show_message("Pekka: \"VÄINÖ PERKELE!\" (Kuului Pattijoelle asti.)\nPekan koira Väinö karkasi! Ota se kiinni jalan.", 4.5)


## Pannu-Sulo myy metsässä pontikkakanisterin (vastaa 24 kaljaa). Kanisterin kanssa suunta on kotiin.
func _pontikka_logic() -> void:
	if _hint.text != "" or sulo.distance_to_player() > 4.2:
		return
	if player == bike:
		_hint.text = "Nouse pyörän selästä (F), niin voit jutella Sulon kanssa."
		return
	if has_kanister or _sulo_sold:
		_hint.text = "Sulo: \"Tänään ei oo enempää. Tuu huomenna.\""
		return
	if money < KANISTER_PRICE:
		_hint.text = "Sulo myy pontikkakanisterin %s eurolla. Rahat ei riitä." % _eur(KANISTER_PRICE)
		return
	_hint.text = "[E] Osta Pannu-Sulolta kanisteri (%s €, = %d kaljaa)" % [_eur(KANISTER_PRICE), KANISTER_BEERS]
	if Input.is_action_just_pressed("interact") and not player.is_stunned():
		money -= KANISTER_PRICE
		has_kanister = true
		_sulo_sold = true
		walker_out.set_kanister(true)
		state = "to_home"
		sulo.say("Kakskymppiä ja suu suppuun. Ja kanisteri takasin, kun on tyhjä.")
		Sfx.play("coin", -4.0)
		_show_message("Pontikkakanisteri mukana, vastaa %d kaljaa!\nVie se kotiin jemmaan." % KANISTER_BEERS, 3.5)


## K-Marketin taksitolpan taksi: jalan E vie Raahen baariin, jos rahaa on taksiin.
func _taxi_logic() -> void:
	if _hint.text != "":
		return
	var p := player.global_position
	if Vector2(p.x - world.taxi_pos.x, p.z - world.taxi_pos.z).length() > TAXI_RADIUS:
		return
	if player == bike:
		_hint.text = "Taksi Raahen baariin: nouse pyörän selästä (F)."
	elif money < TAXI_FARE:
		_hint.text = "Taksi Raahen baariin maksaa %s €. Rahat ei riitä." % _eur(TAXI_FARE)
	else:
		_hint.text = "[E] Taksilla Raahen baariin (%s €, meno-paluu)" % _eur(TAXI_FARE)
		if Input.is_action_just_pressed("interact") and not player.is_stunned():
			_taxi_trip()


## Taksireissu: menomatka, kädenvääntö Raahen baarissa, paluu kotipihaan Päivin eteen ja uusi päivä kotoa.
## Pyörä jää kaupan pihaan.
func _taxi_trip() -> void:
	state = "cutscene"
	player.controls_enabled = false
	player.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_hud.visible = false
	money -= TAXI_FARE
	Sfx.play("door_close", -3.0)
	cutscene.taxi_to_raahe(func() -> void:
		var bar := BarGame.new()
		bar.position = BAR_POS
		add_child(bar)
		bar.finished.connect(func(won: bool) -> void:
			bar.queue_free()
			_after_bar(won)))


func _after_bar(won: bool) -> void:
	var paid := 0.0 if won else minf(BAR_ROUND, money)
	money -= paid
	mielihyva = clampf(mielihyva + (35.0 if won else 20.0), 0.0, 100.0)
	maine = clampf(maine + (15.0 if won else -5.0), 0.0, 100.0)
	_no_allowance = true
	var stats := "%s Taksi %s €%s.\nMielihyvä %d · Maine %d" % [
		"Voitit kädenväännön, Tero tarjosi." if won else "Hävisit kädenväännön ja tarjosit kierroksen.",
		_eur(TAXI_FARE), "" if won else ", kierros %s €" % _eur(paid), roundi(mielihyva), roundi(maine)]
	cutscene.taxi_home(home_zone, stats, func() -> void:
		_new_day(home_zone + Vector3(0, 0, 4), false, "Pää on kipeä Raahen reissusta.\n"))


## Arto ostaa marjat ja kertoo paikat, Pekka ostaa sienet ja kehuu kyyhkysaaliitaan.
func _neighbor_logic() -> void:
	if _hint.text != "":
		return
	var e := Input.is_action_just_pressed("interact")
	for v in [arto, pekka]:
		if v.distance_to_player() > 4.2:
			continue
		var who := "arto" if v == arto else "pekka"
		if who == "arto" and mower_broken and not has_mower_part:
			if player == bike:
				_hint.text = "Nouse pyörän selästä (F), niin voit kysyä Artolta leikkurin varaosaa."
			elif money < LAWN_PART_PRICE:
				_hint.text = "Arto myisi leikkurin varaosan %s eurolla, mutta rahat ei riitä." % _eur(LAWN_PART_PRICE)
			else:
				_hint.text = "[E] Osta Artolta leikkurin varaosa (%s €)" % _eur(LAWN_PART_PRICE)
				if e:
					money -= LAWN_PART_PRICE
					has_mower_part = true
					v.say("Vanhasta Husqvarnasta irtos. Kivikkoon ajoit, vai?")
					Sfx.play("register", -4.0)
					_show_message("Varaosa mukana. Vielä kalja, niin leikkuri korjataan.", 3.0)
					_save_game()
			return
		if who == "pekka" and bitten:
			if player == bike:
				_hint.text = "Nouse pyörän selästä (F), niin Pekka voi katsoa haavaa."
			elif beers <= 0 and money < PEKKA_CARE:
				_hint.text = "Pekka hoitaisi haavan kaljalla tai %s eurolla, mutta kumpaakaan ei ole." % _eur(PEKKA_CARE)
			else:
				_hint.text = "[E] Pyydä Pekkaa hoitamaan haava (%s)" % ("kalja" if beers > 0 else _eur(PEKKA_CARE) + " €")
				if e:
					if beers > 0:
						beers -= 1
						player.set_carrying(beers > 0)
					else:
						money -= PEKKA_CARE
					_heal()
					v.say("Ei tää oo mitään, kyyhkyt purree pahemmin.")
					Sfx.play("groan", -4.0, 1.2)
					_show_message("Pekka sitoi haavan ja kaatoi päälle koskenkorvaa. Kirvelee!", 3.5)
			return
		var sale := 0.0
		for k in bucket:
			if GOODS[k].buyer == who:
				sale += bucket[k] * GOODS[k].price
		if who == "arto" and not world.forage_revealed:
			_hint.text = "[E] Juttele Arton kanssa"
			if e:
				world.forage_revealed = true
				v.say("Lähekkö puolukkaan? Merkkaan sulle karttaan parhaat paikat!")
				_show_message("Arto merkitsi marja- ja sienipaikat karttaan (M).", 3.0)
		elif sale > 0.0 and player == bike:
			_hint.text = "Nouse pyörän selästä (F), niin voit myydä %s." % ("marjat" if who == "arto" else "sienet")
		elif sale > 0.0:
			_hint.text = "[E] Myy %s %s €" % ["marjat Artolle" if who == "arto" else "sienet Pekalle", _eur(sale)]
			if e:
				money += sale
				for k in bucket.keys():
					if GOODS[k].buyer == who:
						bucket.erase(k)
				v.say("Kiitti! Tästä tulee hyvää puuroa." if who == "arto" else "No perkele, hyviä sieniä! Näistä tulee saatanan hyvä kastike kyyhkyille.")
				Sfx.play("register", -4.0)
				_show_message("+%s €" % _eur(sale), 2.0)
		else:
			_hint.text = "[E] Juttele %s" % ("Arton kanssa" if who == "arto" else "Pekan kanssa")
			if e:
				v.say((ARTO_LINES if who == "arto" else PEKKA_LINES).pick_random())
		return


## Laavulla: sytytä nuotio (tulitikut), paista makkara, juo kalja -> laavuloppu.
func _laavu_logic() -> void:
	var fire_pos := M.w(M.LAAVU)
	var p := player.global_position
	var d := Vector2(p.x - fire_pos.x, p.z - fire_pos.z).length()
	if _grill_t >= 0.0:
		_grill_t += get_process_delta_time()
		_hint.text = "Makkara paistuu... %d" % ceili(GRILL_TIME - _grill_t)
		if _grill_t >= GRILL_TIME or d > 6.0:
			if _grill_t >= GRILL_TIME:
				sausage_done = true
				_show_message("Makkara valmis! Nam.", 2.5)
				Sfx.play("pickup", -2.0, 0.6)
			_grill_t = -1.0
		return
	if d > 2.8 or _hint.text != "":
		return
	if guard.is_blocking():
		_hint.text = "Laavu on vallattu!"
		return
	if player == bike:
		_hint.text = "Nouse pyörän selästä (F), niin pääset nuotiolle."
		return
	var e: bool = Input.is_action_just_pressed("interact") and not player.is_stunned()
	if not fire_lit and has_matches:
		_hint.text = "[E] Sytytä nuotio"
		if e:
			fire_lit = true
			world.fire.visible = true
			Sfx.play("whoosh", 0.0, 0.5)
			_show_message("Nuotio palaa!", 2.0)
	elif fire_lit and has_sausage and not sausage_done:
		_hint.text = "[E] Paista makkaraa"
		if e:
			_grill_t = 0.0
			Sfx.play("whoosh", -6.0, 0.35)
	elif beers > 0:
		_hint.text = "[E] Avaa kalja laavulla"
		if e:
			beers -= 1
			Sfx.play("pickup")
			_win_laavu()
	elif not fire_lit and not has_matches:
		_hint.text = "Nuotiopaikka. Tulitikut ja makkarat saa K-Marketista."
	else:
		_hint.text = "Laavulla olis hyvä juoda kalja. Kaljat saa K-Marketista."


## Laavuloppu: makkaranpaisto auringonlaskussa, laavusta tulee turvapaikka.
## Pelialueen reunalla hahmo kommentoi (enintään kerran 25 sekunnissa).
func _edge_logic() -> void:
	_edge_cd -= get_process_delta_time()
	var p := player.global_position
	if _edge_cd > 0.0 or world._play_edge_dist(Vector2(p.x, p.z)) > 6.0:
		return
	_edge_cd = 25.0
	var px := M.to_px(p)
	var side := "any"
	if px.x < 25.0:
		side = "west"
	elif px.y < 25.0:
		side = "north"
	elif px.y > M.SIZE.y - 25.0:
		side = "south"
	elif px.x > 870.0:
		side = "east"
	var lines: Array = EDGE_LINES[side] + EDGE_LINES["any"]
	_show_message("\"%s\"" % lines.pick_random(), 3.5)


## Taksipysäkit: kotipihalta mökille 20 €, paluu mökiltä ilmainen (meno-paluu maksettu kerralla,
## ettei rahattomana voi jäädä mökille jumiin). Ks. world.taxi_home_pos ja mokki.gd Mokki.TAXI_LOCAL.
func _mokki_taxi_logic() -> void:
	if _hint.text != "" or player.is_stunned() or cutscene.busy:
		return
	var p := player.global_position
	var home_stand: Vector3 = world.taxi_home_pos
	var mokki_stand: Vector3 = mokki.to_global(Mokki.TAXI_LOCAL)
	var d_home := Vector2(p.x - home_stand.x, p.z - home_stand.z).length()
	var d_mokki := Vector2(p.x - mokki_stand.x, p.z - mokki_stand.z).length()
	if d_home < 3.0:
		if player == bike:
			_hint.text = "Nouse pyörän selästä (F) ja kävele taksille."
			return
		_hint.text = "[E] Tilaa taksi mökille (%s €)" % _eur(TAXI_PRICE)
		if Input.is_action_just_pressed("interact"):
			if money < TAXI_PRICE:
				_show_message("Taksi maksaa %s €. Ei ole tarpeeksi rahaa." % _eur(TAXI_PRICE), 2.5)
			else:
				money -= TAXI_PRICE
				_ride_taxi(mokki_stand + Vector3(0, 0, 2.2), "Matkalla mökille... (%s €)" % _eur(TAXI_PRICE))
	elif d_mokki < 3.0:
		_hint.text = "[E] Tilaa taksi kotiin (paluu jo maksettu)"
		if Input.is_action_just_pressed("interact"):
			_ride_taxi(home_stand + Vector3(0, 0, 2.2), "Matkalla kotiin...")


func _ride_taxi(dest: Vector3, sub: String) -> void:
	walker_out.controls_enabled = false
	walker_out.speed = 0.0
	cutscene.taxi(sub, func() -> void:
		walker_out.global_position = dest
		walker_out.rotation.y = 0.0
		walker_out.activate_camera()
		walker_out.controls_enabled = true)


## Mökillä: jutut Santun kanssa, savusaunan kiuas, puukuumenteinen poreamme, tikanheitto ja laituri.
func _mokki_logic() -> void:
	var p := player.global_position
	var mc := mokki.global_position
	if Vector2(p.x - mc.x, p.z - mc.z).length() > 60.0:
		return
	_santtu_chat_t -= get_process_delta_time()
	if _santtu_chat_t <= 0.0:
		_santtu_chat_t = randf_range(10.0, 18.0)
		var sc: Vector3 = mokki.to_global(Mokki.SANTTU_LOCAL)
		if Vector2(p.x - sc.x, p.z - sc.z).length() < SAUNA_TALK_RADIUS:
			mokki.say(Mokki.SANTTU_AMBIENT.pick_random())
	if _hint.text != "" or player == bike or player.is_stunned():
		return
	var e := Input.is_action_just_pressed("interact")
	var near := func(local: Vector3, r: float) -> bool:
		var g: Vector3 = mokki.to_global(local)
		return Vector2(p.x - g.x, p.z - g.z).length() < r
	if near.call(Mokki.SANTTU_LOCAL, 2.6):
		_hint.text = "[E] Jutskaa Santun kanssa"
		if e:
			mokki.say(Mokki.SANTTU_LINES.pick_random())
		return
	if near.call(Mokki.SAUNA_LOCAL, 2.2):
		if not mokki.sauna_fire_on:
			_hint.text = "[E] Sytytä kiuas"
			if e:
				mokki.set_sauna_fire(true)
				Sfx.play("whoosh", 0.0, 0.6)
				_show_message("Kiuas sytytetty. Lämpiää hetken.", 2.2)
		elif not mokki.sauna_ready():
			_hint.text = "Kiuas lämpiää... %d s" % ceili(Mokki.SAUNA_HEAT - (Mokki.SAUNA_BURN - mokki.sauna_fire_time))
		else:
			_hint.text = "[E] Käy löylyssä"
			if e:
				walker_out.stamina = 100.0
				walker_out.exhausted = false
				Sfx.play("water", -6.0, 0.8)
				_show_message("Löyly virkistää! Kunto palautui.", 2.5)
		return
	if near.call(Mokki.TUB_LOCAL, 1.7):
		if not mokki.tub_fire_on:
			_hint.text = "[E] Sytytä poreammeen tuli"
			if e:
				mokki.set_tub_fire(true)
				Sfx.play("whoosh", 0.0, 0.5)
				_show_message("Tuli palaa ammeen alla. Vesi lämpiää hitaasti.", 2.5)
		elif not mokki.tub_ready():
			_hint.text = "Amme lämpiää... %d s" % ceili(Mokki.TUB_HEAT - (Mokki.TUB_BURN - mokki.tub_fire_time))
		else:
			_hint.text = "[E] Mene kylpyyn"
			if e:
				walker_out.stamina = 100.0
				walker_out.exhausted = false
				Sfx.play("water", -4.0, 0.7)
				_show_message("Kylpy lämmittää. Kunto palautui.", 2.5)
		return
	if near.call(Mokki.DART_LOCAL, 1.8):
		_hint.text = "[E] Heitä tikkaa"
		if e:
			var score: int = [0, 5, 10, 15, 20, 25, 40, 50].pick_random()
			Sfx.play("whoosh", -4.0, 1.2)
			_show_message("TÄYSOSUMA! 50 pistettä!" if score == 50 else ("Ohi meni." if score == 0 else "%d pistettä." % score), 2.0)
		return
	if near.call(Mokki.DOCK_LOCAL, 2.2):
		_fish_logic(e)
		return


## Kalastus laiturilta: heitä onki (E), odota nykäisyä, vedä ylös ajoissa (E). Ks. Mokki.FISH.
func _fish_logic(e: bool) -> void:
	match _fish_state:
		"idle":
			_hint.text = "[E] Heitä onki veteen"
			if e:
				_fish_state = "waiting"
				_fish_t = 0.0
				_fish_target = randf_range(3.0, 8.0)
				Sfx.play("whoosh", -6.0, 0.8)
				_show_message("\"%s\"" % Mokki.LAKE_LINES.pick_random(), 2.5)
		"waiting":
			_fish_t += get_process_delta_time()
			if _fish_t >= _fish_target:
				_fish_state = "bite"
				_fish_t = 0.0
				Sfx.play("alert", -6.0, 1.3)
				_show_message("NYKÄISY!", 1.5)
			else:
				_hint.text = "Odotat nykäisyä..."
		"bite":
			_hint.text = "[E] Vedä ylös!"
			_fish_t += get_process_delta_time()
			if e:
				_land_fish()
				_fish_state = "idle"
			elif _fish_t > 2.2:
				_show_message(Mokki.FISH_MISS_LINES.pick_random(), 2.0)
				_fish_state = "idle"


func _land_fish() -> void:
	if randf() < 0.12:
		Sfx.play("rattle", -4.0, 0.9)
		_show_message("Vedit ylös %s. Ei syötävää." % Mokki.FISH_JUNK.pick_random(), 2.5)
		return
	var fish: Dictionary = Mokki.FISH.pick_random()
	var kg: float = fish.kg * randf_range(0.6, 1.6)
	Sfx.play("win_small", -4.0)
	_show_message("Sait %s! Painoa noin %.1f kg." % [fish.name, kg], 3.0)


## Kota: sahaa tukki pölkyiksi, pilko pölkyt haloiksi, sytytä tuli ja kuuntele tarinoita. Lintutornista lintuja.
func _kota_logic() -> void:
	var k: Node3D = world.kota
	if k == null:
		return
	var p := player.global_position
	var kc := k.global_position
	var dk := Vector2(p.x - kc.x, p.z - kc.z).length()
	if dk > 30.0:
		return
	_kota_chat_t -= get_process_delta_time()
	if _kota_chat_t <= 0.0 and dk < 9.0:
		_kota_chat_t = randf_range(9.0, 15.0)
		if k.fire_on:
			k.say(["raimo", "veikko"].pick_random(), ["Tule istumaan, kerrotaan tarina.", "Hyvin palaa.", "Kato ettei tipu makkara tuleen. Siitä on kyltti."].pick_random())
		else:
			k.say(["raimo", "veikko"].pick_random(), ["Hae puita, niin kerrotaan tarinoita.", "Kylmä kota ilman tulta.",
				"Saha on pukilla ja kirves pölkyssä.", "Kylttiä pitää lukea."].pick_random())
	if _hint.text != "":
		return
	if player == bike:
		if dk < 12.0:
			_hint.text = "Nouse pyörän selästä (F): kodalla touhutaan jalan."
		return
	if player.is_stunned():
		return
	var e := Input.is_action_just_pressed("interact")
	var near := func(local: Vector3, r: float) -> bool:
		var g: Vector3 = k.to_global(local)
		return Vector2(p.x - g.x, p.z - g.z).length() < r
	# Lintutorni: tasanteella.
	var top: Vector3 = k.to_global(Kota.TOWER_LOCAL)
	if Vector2(p.x - top.x, p.z - top.z).length() < 2.4 and p.y > Terrain.h(top.x, top.z) + Kota.TOWER_TOP_Y - 1.0:
		_hint.text = "[E] Katsele lintuja Haapajärven tekojärvellä"
		if e:
			Sfx.play("crow", -8.0, randf_range(1.1, 1.4))
			_show_message("\"%s\"" % Kota.BIRD_LINES.pick_random(), 3.5)
		return
	if near.call(Kota.SAW_LOCAL, 1.7):
		_hint.text = "[E] Tartu pokasahaan ja sahaa tukista pölkkyjä"
		if e:
			_start_saw()
		return
	if near.call(Kota.CHOP_LOCAL, 1.7):
		if kota_polkyt <= 0:
			_hint.text = "Pilkkomispölkky. Sahaa ensin tukki pölkyiksi sahapukilla."
			return
		_hint.text = "[E] Tartu kirveeseen ja halko pölkyt (%d pölkkyä)" % kota_polkyt
		if e:
			_start_chop()
		return
	if dk < 2.7:
		if not k.fire_on:
			if kota_halot >= FIRE_HALOT:
				_hint.text = "[E] Sytytä tuli kotaan (%d halkoa)" % FIRE_HALOT
				if e:
					kota_halot -= FIRE_HALOT
					k.set_fire(true)
					Sfx.play("whoosh", 0.0, 0.5)
					k.say("raimo", "No nyt! Tuli palaa. Istuhan alas.")
			else:
				_hint.text = "Kodan tulisija. Tarvitset %d halkoa (sinulla %d). Puut sahataan ja pilkotaan halkovajan luona." % [FIRE_HALOT, kota_halot]
			return
		if kota_halot > 0 and k.fire_time < 90.0:
			_hint.text = "[E] Lisää halko tuleen (tuli hiipuu)"
			if e:
				kota_halot -= 1
				k.fire_time = minf(k.fire_time + 70.0, 420.0)
				Sfx.play("whoosh", -6.0, 0.5)
			return
		_hint.text = "[E] Kuuntele tarina (kuultu %d/%d)" % [tarinat_kuultu.size(), Kota.STORIES.size()]
		if e:
			_tell_story()


## Sahaus FPS-minipelinä (saw_game.gd): jokainen katkaistu pölkky kasvattaa pölkkyvarastoa.
func _start_saw() -> void:
	var sg := SawGame.new()
	sg.sawn.connect(func() -> void: kota_polkyt += 1)
	_start_kota_game(sg, Kota.SAW_LOCAL, 0.3, func() -> String:
		return "Sahattu %d pölkkyä! Pölkkyjä %d. Halko ne pilkkomispölkyllä kirveellä." % [sg.polkyt_made, kota_polkyt] \
			if sg.polkyt_made > 0 else "")


## Halonhakkuu FPS-minipelinä (chop_game.gd).
func _start_chop() -> void:
	var cg := ChopGame.new()
	cg.polkyt = kota_polkyt
	cg.split.connect(func(n: int) -> void:
		kota_polkyt -= 1
		kota_halot += n)
	_start_kota_game(cg, Kota.CHOP_LOCAL, 0.0, func() -> String:
		return "Halottu %d halkoa! Halkoja %d. Vie ne kodan tulisijaan." % [cg.halot_made, kota_halot] \
			if cg.halot_made > 0 else "")


## Kodan FPS-minipeli (kota_minigame.gd) paikallisessa kohdassa local ja kierrossa rot_y. Pelaaja seisoo
## piilossa minipelin silmien alla; message kertoo lopuksi saaliin.
func _start_kota_game(game: Node3D, local: Vector3, rot_y: float, message: Callable) -> void:
	var k: Node3D = world.kota
	_minigame_prev = state
	state = "minigame"
	player.controls_enabled = false
	player.speed = 0.0
	game.kota = k
	game.position = local
	game.rotation.y = rot_y
	walker_out.global_position = k.to_global(game.transform * (game.eye * Vector3(1, 0, 1))) + Vector3(0, 0.3, 0)
	walker_out.rotation.y = k.global_rotation.y + rot_y + game.yaw_center + PI
	player.visible = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_hud.visible = false
	game.finished.connect(func() -> void:
		state = _minigame_prev
		player.visible = true
		player.activate_camera()
		player.controls_enabled = true
		_hazards.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		_hud.visible = true
		var msg: String = message.call()
		if msg != "":
			_show_message(msg, 3.0))
	k.add_child(game)


## Tarinatuokio kodassa: kamera kertojiin, repliikit puhekuplina ja tekstityksenä. E ohittaa repliikin.
func _tell_story() -> void:
	var k: Node3D = world.kota
	var unheard := []
	for i in Kota.STORIES.size():
		if not tarinat_kuultu.has(i):
			unheard.append(i)
	var idx: int = unheard.pick_random() if not unheard.is_empty() else randi() % Kota.STORIES.size()
	var prev := state
	state = "cutscene"
	player.controls_enabled = false
	player.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	var cam := Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.global_position = k.to_global(Vector3(0.2, 1.55, -2.3))
	cam.look_at(k.to_global(Vector3(0, 0.9, 1.2)), Vector3.UP)
	cam.current = true
	player.visible = false
	k.say("raimo", "")
	k.say("veikko", "")
	for line in Kota.STORIES[idx]:
		var who: String = line[0]
		var dur := clampf(1.5 + line[1].length() * 0.055, 2.5, 7.0)
		(k.raimo if who == "raimo" else k.veikko).play("Sitting_Talking", 0.2)
		_show_message("%s: %s" % ["Raimo" if who == "raimo" else "Veikko", line[1]], dur)
		var t := 0.0
		while t < dur:
			await get_tree().process_frame
			t += get_process_delta_time()
			if t > 0.4 and Input.is_action_just_pressed("interact"):
				break
		(k.raimo if who == "raimo" else k.veikko).play("Sitting_Idle", 0.3)
	cam.queue_free()
	player.visible = true
	player.activate_camera()
	player.controls_enabled = true
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	state = prev
	var fresh := not tarinat_kuultu.has(idx)
	if fresh:
		tarinat_kuultu.append(idx)
		_save_game()
	if tarinat_kuultu.size() >= Kota.STORIES.size() and fresh:
		_show_message("Olet kuullut kaikki kodan tarinat! Raimo: \"No sitten keksitään uusia.\"", 5.0)
	else:
		_show_message(("Uusi tarina kuultu! (%d/%d)" if fresh else "Tuttu tarina, mutta hyvä se on. (%d/%d)") % [
			tarinat_kuultu.size(), Kota.STORIES.size()], 3.0)


func _win_laavu() -> void:
	state = "cutscene"
	player.controls_enabled = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_hud.visible = false
	laavu_conquered = true
	if not Sfx.has_music():
		Sfx.play("win")  # biisi soi loppukohtauksessa, jingle vain ilman sitä
	var title := "LEGENDAARINEN NORMIPÄIVÄ!" if fire_lit and sausage_done else "LAAVULLA KALJOILLA!"
	# Onnellinen loppu juo laavun jemman tyhjäksi (ja mukana olleet kaljat).
	var drunk := beers + 1 + stash_laavu
	var stats := "Nuotio %s  ·  Makkara %s  ·  Kaljoja juotiin %d  ·  Aika %s" % [
		"✔" if fire_lit else "✘", "✔" if sausage_done else "✘", drunk, _time(elapsed)]
	beers = 0
	stash_laavu = 0
	player.set_carrying(false)
	_save_game()
	cutscene.laavu_sunset(M.w(M.LAAVU), world.fire, title, stats, func() -> void: _new_day(_nearest_safe(), false))


# --- Tapahtumat --------------------------------------------------------------

func _enter_shop() -> void:
	state = "in_shop"
	player.controls_enabled = false
	player.speed = 0.0
	_set_outside_visible(false)
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)  # vasta ruudun lopussa: signaali voi tulla kesken vaaran fysiikkapäivityksen
	if wife.mode == "chase" and not wife_alerted:
		wife.reset_to(wife.farthest_node_from(shop_zone))
	interior.money = money
	interior.enter()
	Sfx.play("door", -3.0)


func _on_shop_exited(bought: bool) -> void:
	interior.leave()
	Sfx.play("door_close", -3.0)
	player.rotation.y = PI
	player.controls_enabled = true
	player.activate_camera()
	_set_outside_visible(true)
	_hazards.process_mode = Node.PROCESS_MODE_INHERIT
	if interior.has_paid:
		has_sausage = has_sausage or interior.cart.has("makkara")
		has_matches = has_matches or interior.cart.has("tikut")
		has_chocolate = has_chocolate or interior.cart.has("suklaa")
		for k in interior.bag:
			paivi_bag[k] = interior.bag[k]
		if not interior.bag.is_empty() and not bought:
			_show_message("Päivin ostokset kassissa. Vie ne kotiin.", 2.5)
	if not bought:
		state = "to_shop"
		return
	beers += 6
	state = "to_home"
	player.set_carrying(true)
	if wife_alerted:
		wife.alerted = true
		wife.reset_to(wife.farthest_node_from(shop_zone))
		_show_message("Anna-Liisa soitti Päiville.\nPÄIVI TIETÄÄ MISSÄ OLET!", 3.5)
	else:
		_show_message("Kuutonen kassissa!\nNyt kotiin.", 3.0)


func _on_paid(total: float) -> void:
	money -= total


func _on_busted() -> void:
	wife_alerted = true
	_show_message("Naapurin Anna-Liisa näki sinut!\nKohta Päivi tietää...", 3.0)


func _on_wife_spotted() -> void:
	if state in ["to_shop", "to_home"] and not wife.alerted:
		_show_message("PÄIVI NÄKI SINUT!\nPakoon!", 2.0)


func _on_wife_caught() -> void:
	if state in ["to_shop", "to_home"]:
		_lose("Päivi nappasi kiinni!", "wife")


## Juntti sai kiinni -> Street Fighter -kaksintaistelu.
func _on_kicked(direction: Vector3) -> void:
	_start_fight("juntti", "juntti", direction)


## Laavun akka tai teinijengi haastaa.
func _on_laavu_challenge(kind: String, direction: Vector3) -> void:
	_start_fight(kind, "laavu", direction)


func _start_fight(foe_key: String, source: String, direction: Vector3) -> void:
	if not (state in ["to_shop", "to_home"]):
		return
	_fight_source = source
	_grill_t = -1.0
	_stop_picking(false)
	_stop_mowing()
	_fight_prev = state
	_fight_dir = direction
	state = "fight"
	player.controls_enabled = false
	player.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)  # vasta ruudun lopussa: signaali voi tulla kesken vaaran fysiikkapäivityksen
	_hud.visible = false
	fight.start(beers, foe_key)


func _on_fight_finished(won: bool, bags_used: int) -> void:
	state = _fight_prev
	_hud.visible = true
	player.activate_camera()
	player.controls_enabled = true
	_hazards.process_mode = Node.PROCESS_MODE_INHERIT
	beers = maxi(0, beers - bags_used)
	var note := "\nKassi-iskut rikkoi %d kaljaa." % bags_used if bags_used > 0 else ""
	var loser_node: Node3D = {"juntti": juntti, "laavu": guard, "tractor": tractor}[_fight_source]
	if won:
		loser_node.defeat()
		var who := "Juntti lähti itkien kotiin."
		if _fight_source == "tractor":
			who = "Jyväjemmari ajoi murjottamaan. Pelto on nyt vapaata riistaa!"
		elif _fight_source == "laavu":
			laavu_conquered = true
			_save_game()
			who = "Akka lähti nostamaan meteliä muualle. Laavu on vapaa!" if guard.kind == "akka" else "Teinit pakenivat. Laavu on vapaa!"
		_show_message("K.O.! %s%s" % [who, note], 3.0)
	else:
		loser_node.gloat()
		player.stun(_fight_dir)
		var foe := "Juntti"
		if _fight_source == "tractor":
			foe = "Jyväjemmari"
		elif _fight_source == "laavu":
			foe = "Akka" if guard.kind == "akka" else "Teinit"
		if beers > 0:
			beers = maxi(0, beers - 2)
			Sfx.play("glass", -3.0)
			_show_message("Hävisit! %s potkaisi kassia, 2 kaljaa rikki.%s" % [foe, note], 3.0)
		else:
			money -= 5.0
			_show_message("Hävisit! %s vei vitosen \"lainaksi\"." % foe, 3.0)
			if state == "to_shop" and money < BEER_PRICE:
				_lose("%s vei rahat. Kuutoseen ei enää riitä." % foe, _fight_source if _fight_source == "juntti" else "default")
				return
	player.set_carrying(beers > 0)
	if state == "to_home" and beers <= 0 and not has_kanister:
		_lose("Kaikki kaljat rikki. Kotiin ei kannata mennä tyhjin käsin.", "juntti")


const JEMMA_GOAL := 24

# Kota: sahaus ja pilkkominen, tuli ja tarinat.
const HALOT_PER_POLKKY := 4
const FIRE_HALOT := 4
var kota_polkyt := 0
var kota_halot := 0
var _minigame_prev := "to_shop"
var tarinat_kuultu: Array = []  # kuultujen tarinoiden indeksit (tallentuu)
var _kota_chat_t := 6.0
var _story_skip := false
var _edge_cd := 0.0

## Kartan reunalla: hahmon kommentit (alue, repliikit).
const EDGE_LINES := {
	"west": ["Valtatie 8 vie Ouluun. Ei tänään, kalja lämpenee.", "Tuolla on Pattijoki. Sinne ei kukaan mene vapaaehtoisesti.",
		"Länteen on vain meri ja Hailuoto. Pyörä ei kellu."],
	"north": ["Tuolla on Raahen keskusta ja Alko... ei, pysytään suunnitelmassa.", "Pohjoisessa on vain teollisuusalue ja anoppi Pirjo. Takaisin!",
		"Tästä eteenpäin navigaattori sanoisi: käänny ympäri."],
	"east": ["Idässä on pelkkää suota ja Pekan jäniksiä.", "Tuonne ei ole tietä. Eikä kauppaa. Eikä järkeä.",
		"Mettää ja mettää. Ei täällä ole kaljaa."],
	"south": ["Tekojärven takana on Pyhäjoki. Ei sinne pyörällä.", "Tästä alkaa Siikajoen kunta. Siellä on omat juntit.",
		"Etelään on liian pitkä matka kuutosen kanssa."],
	"any": ["Kartta loppuu tähän. Päivi sanoi, ettei pidemmälle.", "Maailman reuna. Saloisten raja. Sama asia.",
		"Ei jakseta. Kauppa on toiseen suuntaan.", "Tuolla ei ole mitään. Tai jos on, niin se ei kuulu mulle."],
}
const CARRY_FOOT := 12  # jalan jaksaa kantaa kaksi kuutosta
const CARRY_BIKE := 6  # pyörän tarakalle mahtuu kuutonen

## Kotiinpaluu: saalis jemmaan. Kun kotijemmassa on 24 olutta, tulee onnellinen loppu:
## karburaattorin säätöä autotallissa kalja kädessä (kotijemma juodaan tyhjäksi).
func _win() -> void:
	state = "cutscene"
	player.controls_enabled = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	if not _list_done and not paivi_bag.is_empty():
		# Päivin palaute ostoksista uuden päivän aloitusviestin jälkeen (ennen uutta listaa).
		for l in _check_list():
			_msg_queue.append([l, 3.0])
	var kanister := KANISTER_BEERS if has_kanister else 0
	var brought := beers + kanister
	var where := _deposit_home(brought)
	if kanister > 0:
		where += " (pontikkakanisteri = %d kaljaa)" % kanister
		has_kanister = false
		walker_out.set_kanister(false)
	jemma_wins += 1
	jemma_best = maxi(jemma_best, jemma)
	beers = 0
	_save_game()
	if jemma >= JEMMA_GOAL:
		_hud.visible = false
		if not Sfx.has_music():
			Sfx.play("win")  # biisi soi loppukohtauksessa, jingle vain ilman sitä
		var had := jemma
		jemma = 0  # onnellinen loppu juo kotijemman tyhjäksi
		jemma_endings += 1
		_save_game()
		var stats := "Jemmassa oli %d olutta%s – juhlan paikka!  ·  Onnellisia loppuja: %d" % [had,
			" (pontikka mukaan luettuna)" if kanister > 0 else "", jemma_endings]
		cutscene.garage("KARBURAATTORIA SÄÄTÄMÄSSÄ", stats, func() -> void: _new_day(home_zone + Vector3(0, 0, 4), false))
		return
	Sfx.play("win_small")
	_new_day(home_zone + Vector3(0, 0, 4), false,
		"Kotona! %d kaljaa %s. Kotijemmat %d/%d – kun niissä on %d, on juhlan aika.\n" % [
		brought, where, jemma, JEMMA_GOAL, JEMMA_GOAL])


## Kotiinpaluun saalis: eteisen kaappiin, ylimenevät autotalliin ja kompostin taakse. Palauttaa kuvauksen.
func _deposit_home(n: int) -> String:
	var parts: Array[String] = []
	for id in ["koti", "autotalli", "komposti"]:
		var put := mini(n, maxi(0, STASHES[id].cap - stash.get(id, 0)))
		if put > 0:
			stash[id] = stash.get(id, 0) + put
			n -= put
			parts.append("%d %s" % [put, STASHES[id].into])
	if n > 0:
		stash["koti"] = stash.get("koti", 0) + n  # kaikki täynnä: ahdetaan eteiseen
		parts.append("%d lisää %s" % [n, STASHES["koti"].into])
	return ", ".join(parts) if not parts.is_empty() else "jemmaan"


func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for id in STASHES:
		stash[id] = cfg.get_value("jemmat", id, 0)
	stash_used = cfg.get_value("jemmat", "kaytetyt", [])
	# Vanhan version jemmat (kaljat/laavu/grilli) eivät siirry: Päivi löysi ne.
	for k in ["kaljat", "laavu", "grilli"]:
		_old_stash_lost += int(cfg.get_value("jemma", k, 0))
	jemma_best = cfg.get_value("jemma", "ennatys", 0)
	jemma_wins = cfg.get_value("jemma", "kotiinpaluut", 0)
	laavu_conquered = cfg.get_value("peli", "laavu_vallattu", false)
	money = cfg.get_value("peli", "rahat", START_MONEY)
	day = cfg.get_value("peli", "paiva", 1)
	has_chocolate = cfg.get_value("peli", "suklaa", false)
	mielihyva = cfg.get_value("peli", "mielihyva", 0.0)
	maine = cfg.get_value("peli", "maine", 0.0)
	jemma_endings = cfg.get_value("jemma", "loput", 0)
	tarinat_kuultu = cfg.get_value("kota", "tarinat", [])
	lawn.load_state(cfg.get_value("nurmikko", "pituudet", PackedByteArray()))
	lawn_siilit = cfg.get_value("nurmikko", "siilit", 0)
	lawn_kivet = cfg.get_value("nurmikko", "kivet", 0)
	mower_broken = cfg.get_value("nurmikko", "rikki", false)
	has_mower_part = cfg.get_value("nurmikko", "varaosa", false)
	_lawn_praise = cfg.get_value("nurmikko", "kehu", false)
	if cfg.has_section_key("peli", "pyora"):
		_bike_saved = [cfg.get_value("peli", "pyora"), cfg.get_value("peli", "pyora_kulma", 0.0)]


func _save_game() -> void:
	var cfg := ConfigFile.new()
	for id in STASHES:
		cfg.set_value("jemmat", id, stash.get(id, 0))
	cfg.set_value("jemmat", "kaytetyt", stash_used)
	cfg.set_value("jemma", "ennatys", jemma_best)
	cfg.set_value("jemma", "kotiinpaluut", jemma_wins)
	cfg.set_value("peli", "laavu_vallattu", laavu_conquered)
	cfg.set_value("peli", "rahat", money)
	cfg.set_value("peli", "paiva", day)
	cfg.set_value("peli", "suklaa", has_chocolate)
	cfg.set_value("peli", "mielihyva", mielihyva)
	cfg.set_value("peli", "maine", maine)
	cfg.set_value("jemma", "loput", jemma_endings)
	cfg.set_value("kota", "tarinat", tarinat_kuultu)
	if lawn != null:
		cfg.set_value("nurmikko", "pituudet", lawn.save_state())
	cfg.set_value("nurmikko", "siilit", lawn_siilit)
	cfg.set_value("nurmikko", "kivet", lawn_kivet)
	cfg.set_value("nurmikko", "rikki", mower_broken)
	cfg.set_value("nurmikko", "varaosa", has_mower_part)
	cfg.set_value("nurmikko", "kehu", _lawn_praise)
	if bike != null:
		cfg.set_value("peli", "pyora", bike.global_position)
		cfg.set_value("peli", "pyora_kulma", bike.rotation.y)
	cfg.save(SAVE_PATH)


## Kotijemmoihin kohdistuu riski jemmakohtaisesti: Päivi saattaa löytää täyden jemman ja kaataa puolet
## viemäriin (enintään yksi löytö aamussa). Ulkojemmoista teinit voivat pölliä. Tarkistetaan joka aamu.
func _jemma_check(allow_found := true) -> String:
	var note := ""
	if allow_found:
		var ids := _risky_stashes()
		ids.shuffle()
		for id in ids:
			if randf() < _find_chance(id):
				var lost: int = stash[id] / 2
				_jemma_choco = _offer_chocolate()
				if _jemma_choco == "ok":
					lost /= 2  # leppynyt Päivi kaataa viemäriin vain osan
				stash[id] -= lost
				_jemma_found = lost
				note += "\nPäivi löysi %s ja kaatoi %d kaljaa viemäriin!" % [STASHES[id].name, lost]
				break
	for id in STASHES:
		var st: Dictionary = STASHES[id]
		var n: int = stash.get(id, 0)
		if not st.home and n > 0 and randf() < st.steal:
			var stolen := clampi(randi_range(n / 2, n), 1, n)
			stash[id] = n - stolen
			note += "\nTeinit pöllivät %s %d kaljaa!" % [st.from, stolen]
	var risky := _risky_stashes()
	if not risky.is_empty():
		var names: Array[String] = []
		for id in risky:
			names.append(STASHES[id].name)
		note += "\nVaroitus: Päivi voi löytää jemman (%s)!" % ", ".join(names)
	_save_game()
	return note


## Häviö: WASTED-välianimaatio ja Päivin motkotus, sitten uusi päivä lähimmästä turvapaikasta.
func _lose(reason: String, cause := "default") -> void:
	if state == "cutscene":
		return
	state = "cutscene"
	_stop_mowing()
	player.controls_enabled = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)  # vasta ruudun lopussa: signaali voi tulla kesken vaaran fysiikkapäivityksen
	_hud.visible = false
	var spawn := _nearest_safe()
	var choco := _offer_chocolate()
	_choco_mercy = choco == "ok"
	cutscene.wasted(player.global_position, reason, cause, home_zone, func() -> void: _new_day(spawn, true), choco)


## Suklaa annetaan Päiville automaattisesti motkotuksen hetkellä. Palauttaa "" (ei suklaata), "ok" tai "fail".
func _offer_chocolate() -> String:
	if not has_chocolate:
		return ""
	has_chocolate = false
	return "ok" if randf() < CHOCO_CHANCE else "fail"


## Grafiikan laatu (Settings): varjot, SSAO/SSIL, hehku, ruohon tiheys, lähipuiden etäisyys, FPS-näyttö.
## Erittäin matalalla ei ole auringon varjoja: ne piirtäisivät lähimaailman neljästi lisää joka ruudulla.
func _apply_settings() -> void:
	var q: int = Settings.get_v("quality")
	_env.ssao_enabled = q >= 2
	_env.ssil_enabled = q >= 3
	_env.glow_enabled = q >= 2
	_sun.shadow_enabled = q >= 1
	_sun.directional_shadow_max_distance = [70.0, 70.0, 120.0, 180.0][q]
	_sun.shadow_blur = [0.5, 0.5, 1.0, 1.5][q]
	world.set_quality(q)
	_fps_label.visible = Settings.get_v("show_fps")
	get_tree().call_group(B.GUIDES, "set_visible", Settings.get_v("show_guides"))


## Lähin turvapaikka: koti tai laavu (kun se on vallattu).
func _nearest_safe() -> Vector3:
	var p := player.global_position
	var laavu := M.w(M.LAAVU) + Vector3(-3.0, 0, -6.0)
	if laavu_conquered and p.distance_to(laavu) < p.distance_to(home_zone):
		return laavu
	return home_zone + Vector3(0, 0, 4)


## Uusi päivä turvapaikasta: vaarat ja kauppa nollautuvat, jemma, rahat ja laavun valtaus säilyvät.
func _new_day(spawn: Vector3, lost: bool, intro := "") -> void:
	day += 1
	# Pyörä jää sinne, minne se jäi; päivä alkaa jalan turvapaikasta.
	beers = 0
	has_kanister = false
	_sulo_sold = false
	walker_out.set_kanister(false)
	bike.set_carrying(false)
	_place_on_foot(spawn + Vector3(0, 0.3, 0))
	walker_out.rotation.y = 0.0
	var bike_note := _bike_note(spawn)
	has_sausage = false
	has_matches = false
	fire_lit = false
	sausage_done = false
	_grill_t = -1.0
	_stop_picking(false)
	world.fire.visible = false
	if world.kota != null:
		world.kota.set_fire(false)
	if mokki != null:
		mokki.set_sauna_fire(false)
		mokki.set_tub_fire(false)
	_fish_state = "idle"
	var bonus := ""
	if _no_allowance:
		_no_allowance = false
		bonus = "\nPäivi ei antanut rahaa kauppaan Raahen reissun jälkeen."
	elif money < START_MONEY:
		bonus = "\nPäivi antoi %s € kauppaan." % _eur(START_MONEY - money) if not lost else "\nTakin taskusta löytyi vähän rahaa."
		money = START_MONEY
	if _choco_mercy:
		_choco_mercy = false
		money += CHOCO_MONEY
		bonus += "\nPäivi leppyi ja antoi %s € ylimääräistä." % _eur(CHOCO_MONEY)
	if bitten:
		_heal()
		bonus += "\nPuremahaava parani yön aikana. Päivi: \"%s\"" % WOUND_PAIVI.pick_random()
	if not _list_done and not shopping_list.is_empty():
		bonus += "\nPäivi: \"Eilen ei tullu kaupasta mitään, vaikka oli lista!\""
	var rauha := _kaljarauha
	_kaljarauha = false
	_roll_list()
	# Nurmikko kasvaa yön aikana; siilit ja kivet uusiin paikkoihin, leikkuri takaisin paikalleen.
	_stop_mowing()
	if _lawn_praise:
		_lawn_praise = false
		money += LAWN_BONUS
		bonus += "\nPäivi kehui nurmikkoa ja antoi %s € ylimääräistä." % _eur(LAWN_BONUS)
	_lawn_done_today = false
	lawn.grow()
	lawn.park_mower()
	lawn.spawn_objects()
	bonus += _lawn_nag()
	wife_alerted = false
	police = null
	vaino = null  # karkuri palaa yöksi itse kotiin
	_roll_vaino()
	for c in _hazards.get_children():
		c.queue_free()
	_spawn_threats()
	if laavu_conquered:
		guard.vanish()
	_minimap.wife = wife
	interior.queue_free()
	_spawn_interior()
	# Viiveellä: kotiinpaluu pysäyttää vaarat set_deferredillä samalla ruudulla, ja suora asetus
	# jäisi sen alle (vaarat jäätyisivät koko päiväksi). Viivästetyt kutsut suoritetaan järjestyksessä.
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	state = "to_shop"
	elapsed = 0.0
	_hud.visible = true
	_set_outside_visible(true)
	_save_game()
	_jemma_found = 0
	_jemma_choco = ""
	var jnote := _jemma_check(not rauha)
	if rauha:
		jnote += "\nKaljarauha: Päivi ei etsinyt jemmoja."
	if _jemma_found > 0:
		# Päivi löysi jemman: välianimaatio ennen päivän alkua.
		state = "cutscene"
		_hud.visible = false
		player.controls_enabled = false
		_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		var lost_n := _jemma_found
		var msg := "%sPäivä %d alkaa.%s%s%s\nPitäis käydä kaupassa..." % [intro, day, bonus, bike_note, jnote]
		cutscene.jemma_found(home_zone, lost_n, jemma, func() -> void:
			state = "to_shop"
			_hud.visible = true
			player.controls_enabled = true
			player.activate_camera()
			_hazards.process_mode = Node.PROCESS_MODE_INHERIT
			_show_message(msg, 6.0)
			_tell_list(), _jemma_choco)
		return
	_show_message("%sPäivä %d alkaa%s.%s%s%s\nPitäis käydä kaupassa..." % [intro, day, " laavulta" if spawn.distance_to(home_zone) > 50.0 else " kotoa",
		bonus, bike_note, jnote], 4.0 if jnote == "" and intro == "" and bike_note == "" else 6.0)
	_tell_list()


## Tallennettu pyörä paikalleen ja pelaaja jalan kotiin. Palauttaa aamumuistutuksen.
func _apply_saved_bike() -> String:
	if _bike_saved == null:
		return ""
	bike.global_position = _bike_saved[0]
	bike.rotation.y = _bike_saved[1]
	_place_on_foot(home_zone + Vector3(0, 0.3, 4))
	return _bike_note(home_zone)


## Muistutus aamulla, jos pyörä jäi kauas.
func _bike_note(spawn: Vector3) -> String:
	if bike.global_position.distance_to(spawn) < 30.0:
		return ""
	return "\nPyörä jäi eilen muualle – katso kartasta (M), minne."


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and bike != null:
		_save_game()  # pyörän paikka talteen, vaikka ikkuna suljettaisiin kesken päivän


func _set_outside_visible(v: bool) -> void:
	_beacon.visible = v


# --- Syöte & ympäristö -------------------------------------------------------

func _setup_input() -> void:
	_add_action("forward", [KEY_W, KEY_UP])
	_add_action("back", [KEY_S, KEY_DOWN])
	_add_action("left", [KEY_A, KEY_LEFT])
	_add_action("right", [KEY_D, KEY_RIGHT])
	_add_action("brake", [KEY_SPACE])
	_add_action("interact", [KEY_E])
	_add_action("restart", [KEY_R])
	_add_action("bell", [KEY_Q])
	_add_action("punch", [KEY_J])
	_add_action("kick", [KEY_K])
	_add_action("special", [KEY_L])
	_add_action("map", [KEY_M])
	_add_action("mount", [KEY_F])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _setup_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = B.shader_mat("res://shaders/sky.gdshader")
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	# Syvyysvarjostus kulmiin ja epäsuora valo.
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.8
	env.ssil_enabled = true
	env.ssil_intensity = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	# Kaukaisuuden usva taivaan sävyssä, aurinko kajastaa.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.74, 0.8, 0.88)
	env.fog_sun_scatter = 0.25
	env.fog_depth_begin = 90.0
	env.fog_depth_end = 700.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	# Kesäiltapäivän matala, lämmin aurinko pitkine varjoineen.
	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-34, 145, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)


# --- Merkit ------------------------------------------------------------------

func _build_markers() -> void:
	_beacon = MeshInstance3D.new()
	_beacon.mesh = B.cyl(1.5, 1.5, 40)
	_beacon.material_override = B.unshaded(Color(1.0, 0.85, 0.1, 0.3))
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beacon)


# --- Hahmot ------------------------------------------------------------------

func _spawn_player() -> void:
	player = PlayerBike.new()
	player.position = home_zone + Vector3(0, 0.3, 4)
	add_child(player)
	bike = player
	walker_out = OnFoot.new()
	walker_out.world = world
	add_child(walker_out)
	bike.legs = walker_out
	walker_out.visible = false
	walker_out.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)


## Vaihtaa ohjattavan hahmon (pyörä / jalan) ja päivittää kaikki, jotka seuraavat pelaajaa.
func _set_avatar(a: CharacterBody3D) -> void:
	player = a
	world.follow = a
	for h in [wife, juntti, guard, tractor, arto, pekka, sulo, police, vaino, stray, mummot]:
		if is_instance_valid(h):
			h.target = a
	_minimap.player = a
	_compass.player = a
	_paper.player = a
	a.activate_camera()


## F: nouse pyörän selästä tai takaisin pyörälle (pyörän vieressä).
## Pelaaja jalan kohtaan pos; pyörä jää paikalleen ilman kuskia.
func _place_on_foot(pos: Vector3) -> void:
	bike.speed = 0.0
	bike.controls_enabled = false
	bike.set_rider_visible(false)
	walker_out.global_position = pos
	walker_out.velocity = Vector3.ZERO
	walker_out.visible = true
	walker_out.process_mode = Node.PROCESS_MODE_INHERIT
	walker_out.controls_enabled = true
	walker_out.set_carrying(beers > 0)
	_set_avatar(walker_out)


func _toggle_mount() -> void:
	_stop_mowing()
	if player == bike:
		if absf(bike.speed) > 3.0:
			_show_message("Hidasta ensin!", 1.2)
			return
		_place_on_foot(bike.global_position + bike.global_transform.basis.x * 1.1)
		walker_out.rotation.y = bike.rotation.y
		_save_game()  # pyörän paikka talteen
	else:
		walker_out.visible = false
		walker_out.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		bike.set_rider_visible(true)
		bike.controls_enabled = true
		bike.set_carrying(beers > 0)
		_set_avatar(bike)


func _spawn_hazards() -> void:
	_hazards = Node3D.new()
	add_child(_hazards)
	_spawn_threats()
	arto = _villager("Naapurin Arto", Looks.ARTO, ARTO_LINES, "arto", M.ARTO_POS)
	pekka = _villager("Naapurin Pekka", Looks.PEKKA, PEKKA_LINES, "pekka", M.PEKKA_POS)
	sulo = _villager("Pannu-Sulo", Looks.SULO, SULO_LINES, "sulo", M.PONTIKKA + Vector2(-2.2, -1.2))


## Päivi, juntti, laavun valtaajat ja jyväjemmari (luodaan uudelleen joka päivä).
func _spawn_threats() -> void:
	wife = WifeCar.new()
	_hazards.add_child(wife)
	wife.setup(world.graph_nodes, world.graph_adj, world.nearest_node(M.w(M.J_T)), player)
	wife.world = world
	wife.spotted.connect(_on_wife_spotted)
	wife.caught.connect(_on_wife_caught)

	juntti = Juntti.new()
	juntti.position = M.w(M.JUNTTI_SPOTS.pick_random())
	juntti.target = player
	juntti.world = world
	juntti.kicked.connect(_on_kicked)
	_hazards.add_child(juntti)

	guard = LaavuGuard.new()
	guard.kind = ["akka", "teens"].pick_random()
	guard.center = M.w(M.LAAVU)
	guard.target = player
	guard.world = world
	guard.challenge.connect(_on_laavu_challenge)
	_hazards.add_child(guard)

	tractor = Tractor.new()
	tractor.position = M.w(M.TRACTOR_POS)
	tractor.rotation.y = -PI / 2.0
	tractor.target = player
	tractor.world = world
	tractor.challenge.connect(func(k: String, d: Vector3) -> void: _start_fight(k, "tractor", d))
	_hazards.add_child(tractor)

	# Kaupan penkin mummot (#14): kettukarkit, jos kurvaa läheltä lujaa tai soittaa kelloa.
	mummot = Mummot.new()
	mummot.position = M.w(M.SHOP_BUILDING) + Vector3(-6.0, 0, 10.2)
	mummot.target = player
	mummot.hit.connect(func(dir: Vector3) -> void:
		if state in ["to_shop", "to_home"] and not player.is_stunned():
			player.stagger(dir)
			_show_message("Kettukarkki osui! Mummoilla on hyvä käsi.", 2.0))
	mummot.candy_picked.connect(func() -> void:
		walker_out.stamina = minf(100.0, walker_out.stamina + 15.0)
		_show_message("Kettukarkki maasta. Kunto +15", 1.5))
	_hazards.add_child(mummot)

	stray = StrayDog.new()
	stray.spot = M.w(M.STRAY_SPOTS.pick_random())
	stray.position = stray.spot
	stray.target = player
	stray.world = world
	stray.growled.connect(func() -> void:
		if state in ["to_shop", "to_home"] and not bitten:
			_show_message("Vieras koira murisee. Tuohon ei kannata mennä rapsuttelemaan.", 2.5))
	stray.bit.connect(_on_bitten)
	_hazards.add_child(stray)
	wife.safe_zones = [[M.w(M.GRILLIKATOS), 7.5]]


func _villager(nimi: String, look: Dictionary, lines: Array, voice: String, px: Vector2) -> CharacterBody3D:
	var v := Villager.new()
	v.display_name = nimi
	v.look = look
	v.lines = lines
	v.voice = voice
	v.target = player
	v.position = M.w(px)
	add_child(v)
	return v


func _spawn_interior() -> void:
	interior = ShopInterior.new()
	interior.position = INTERIOR_POS
	add_child(interior)
	interior.paid.connect(_on_paid)
	interior.busted.connect(_on_busted)
	interior.exited.connect(_on_shop_exited)


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	_hud = layer
	add_child(layer)
	_stats = _label(layer, 24)
	_stats.position = Vector2(20, 16)
	var help := _label(layer, 16)
	help.text = "W/S polje · A/D ohjaa · E toiminto · F jalan/pyörälle · M kartta · V FPS · hiiri kamera · Esc valikko"
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 20
	help.offset_top = -36
	_status = _centered_label(layer, 30, 0.0, 66, 142)  # kompassin alle
	_status.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	_hint = _centered_label(layer, 30, 1.0, -130, -80)
	_msg = _centered_label(layer, 44, 0.3, -80, 120)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # pitkät viestit (tarinat) rivittyvät
	_msg.offset_left = 60
	_msg.offset_right = -60

	_sus_box = VBoxContainer.new()
	_sus_box.anchor_left = 1.0
	_sus_box.anchor_right = 1.0
	_sus_box.offset_left = -340
	_sus_box.offset_right = -20
	_sus_box.offset_top = 16
	layer.add_child(_sus_box)
	var sl := Label.new()
	sl.text = "Naapurin epäily"
	sl.add_theme_font_size_override("font_size", 20)
	sl.add_theme_color_override("font_outline_color", Color.BLACK)
	sl.add_theme_constant_override("outline_size", 6)
	_sus_box.add_child(sl)
	_sus_bar = ProgressBar.new()
	_sus_bar.max_value = 100.0
	_sus_bar.show_percentage = false
	_sus_bar.custom_minimum_size = Vector2(320, 22)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.2, 0.1)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_sus_bar.add_theme_stylebox_override("fill", fill)
	_sus_bar.add_theme_stylebox_override("background", bg)
	_sus_box.add_child(_sus_bar)
	_sus_box.visible = false
	_fps_label = _label(layer, 16)
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.offset_left = -120
	_fps_label.offset_top = 8

	_stamina_box = VBoxContainer.new()
	_stamina_box.anchor_left = 1.0
	_stamina_box.anchor_right = 1.0
	_stamina_box.anchor_top = 1.0
	_stamina_box.anchor_bottom = 1.0
	_stamina_box.offset_left = -226
	_stamina_box.offset_right = -16
	_stamina_box.offset_top = -16 - 210 - 44
	_stamina_box.offset_bottom = -16 - 214
	layer.add_child(_stamina_box)
	var st_l := Label.new()
	st_l.text = "Kunto"
	st_l.add_theme_font_size_override("font_size", 16)
	st_l.add_theme_color_override("font_outline_color", Color.BLACK)
	st_l.add_theme_constant_override("outline_size", 6)
	_stamina_box.add_child(st_l)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.max_value = 100.0
	_stamina_bar.show_percentage = false
	_stamina_bar.custom_minimum_size = Vector2(210, 12)
	var sfill := StyleBoxFlat.new()
	sfill.bg_color = Color(0.3, 0.8, 0.4)
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0, 0, 0, 0.5)
	_stamina_bar.add_theme_stylebox_override("fill", sfill)
	_stamina_bar.add_theme_stylebox_override("background", sbg)
	_stamina_box.add_child(_stamina_bar)
	_stamina_box.visible = false

	_minimap = Minimap.new()
	_minimap.anchor_left = 1.0
	_minimap.anchor_right = 1.0
	_minimap.anchor_top = 1.0
	_minimap.anchor_bottom = 1.0
	_minimap.offset_left = -16 - 210
	_minimap.offset_top = -16 - 210
	_minimap.player = player
	_minimap.wife = wife
	_minimap.world = world
	_minimap.bike = bike
	_minimap.mokki = mokki
	layer.add_child(_minimap)

	_compass = Compass.new()
	_compass.player = player
	_compass.paper = _paper
	layer.add_child(_compass)


func _update_hud() -> void:
	var jem := "koti %d/%d" % [jemma, JEMMA_GOAL]
	for id in STASHES:
		if not STASHES[id].home and stash.get(id, 0) > 0:
			jem += " · %s %d" % [STASHES[id].short, stash[id]]
	var lines := "Rahaa: %s €\nKaljat: %d   (jemmat: %s%s)\nAika: %s" % [_eur(money), beers, jem,
		" ⚠" if not _risky_stashes().is_empty() else "", _time(elapsed)]
	if state in ["to_shop", "to_home"]:
		var target := shop_zone if state == "to_shop" else home_zone
		var p := player.global_position
		lines += "\nTavoite: %s  %d m\nAlusta: %s" % [
			"K-Market" if state == "to_shop" else "Koti",
			int(Vector2(p.x, p.z).distance_to(Vector2(target.x, target.z))), world.TERRAIN[player.surface].name]
	_stamina_box.visible = state in ["to_shop", "to_home"]  # juoksu ja pyörän spurtti kuluttavat samaa kuntoa
	if _stamina_box.visible:
		_stamina_bar.value = walker_out.stamina
		(_stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.9, 0.3, 0.2) if walker_out.exhausted else Color(0.3, 0.8, 0.4)
	var inv: Array[String] = []
	if has_sausage:
		inv.append("makkara (paistettu)" if sausage_done else "makkara")
	if has_matches:
		inv.append("tulitikut")
	if has_chocolate:
		inv.append("suklaalevy")
	if has_mower_part:
		inv.append("leikkurin varaosa")
	if has_kanister:
		inv.append("pontikkakanisteri (= %d kaljaa)" % KANISTER_BEERS)
	if kota_polkyt > 0:
		inv.append("pölkkyjä %d" % kota_polkyt)
	if kota_halot > 0:
		inv.append("halkoja %d" % kota_halot)
	if not inv.is_empty():
		lines += "\nMukana: " + ", ".join(inv)
	if not _list_done and not shopping_list.is_empty():
		# Kauppalista: vain tuotteet, värit pitää muistaa. ✔ = kassissa (väristä riippumatta).
		var items: Array[String] = []
		for it in shopping_list:
			items.append(it[0] + (" ✔" if paivi_bag.has(it[0]) or interior.bag.has(it[0]) else ""))
		lines += "\nKauppalista: " + ", ".join(items)
	if mielihyva > 0.0 or maine > 0.0:
		lines += "\nMielihyvä %d · Maine %d" % [roundi(mielihyva), roundi(maine)]
	if not bucket.is_empty():
		var bl: Array[String] = []
		for k in bucket:
			bl.append("%s %d l" % [k, bucket[k]])
		lines += "\nÄmpäri: " + ", ".join(bl)
	_stats.text = lines
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_minimap.visible = state != "in_shop"
	_minimap.target = shop_zone if state == "to_shop" else home_zone
	_minimap.show_target = state in ["to_shop", "to_home"]
	_compass.visible = state in ["to_shop", "to_home"]

	var status: Array[String] = []
	if state in ["to_shop", "to_home"]:
		if wife.is_target_safe():
			status.append("TURVASSA – KIILINLAMMEN GRILLIKATOS")
		elif wife.alerted:
			status.append("PÄIVI TIETÄÄ MISSÄ OLET!")
		elif wife.mode == "chase":
			status.append("PÄIVI JAHTAA!")
		if juntti.mode == "chase":
			status.append("JUNTTI JAHTAA!")
		if tractor.mode == "chase":
			status.append("JYVÄJEMMARI JAHTAA!")
		if is_instance_valid(police) and not police.is_leaving():
			status.append("POLIISI JAHTAA!")
		if bitten:
			status.append("PURTU – HAAVA PITÄÄ HOITAA")
		if mummot.is_angry():
			status.append("MUMMOT HEITTELEE KETTUKARKKEJA!")
		if is_instance_valid(vaino):
			if vaino.mode == "follow":
				status.append("VÄINÖ MUKANA – VIE PEKALLE")
			else:
				var vd := roundi(vaino.distance_to_target() / 10.0) * 10
				status.append("VÄINÖ KARKUSSA" + (" (n. %d m)" % vd if vd >= 10 else ""))
	_status.text = "\n".join(status)

	var nb: CharacterBody3D = interior.neighbor
	_sus_box.visible = state == "in_shop" and nb != null
	if _sus_box.visible:
		_sus_bar.value = nb.suspicion


func _label(layer: CanvasLayer, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	layer.add_child(l)
	return l


func _centered_label(layer: CanvasLayer, size: int, anchor_y: float, top: float, bottom: float) -> Label:
	var l := _label(layer, size)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_top = top
	l.offset_bottom = bottom
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Viesti jonoon: näytetään, kun edellinen on ehtinyt näkyä loppuun.
func _queue_message(text: String, seconds: float) -> void:
	if _msg_time <= 0.0 and _hud.visible:
		_show_message(text, seconds)
	else:
		_msg_queue.append([text, seconds])


func _show_message(text: String, seconds: float) -> void:
	_msg.text = text
	_msg_time = seconds


func _eur(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")


func _time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


# --- Debug -------------------------------------------------------------------
# `godot --path . -- --shot=/polku/kuva.png [--scene=shop|juntti|wife]`
# ottaa kuvakaappauksen n. 1,5 s jälkeen ja sulkee pelin.

func _maybe_screenshot() -> void:
	var path := ""
	var scene := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			path = arg.substr(7)
		elif arg.begins_with("--scene="):
			scene = arg.substr(8)
	if path.is_empty():
		return
	await get_tree().process_frame
	match scene:
		"shop":
			_enter_shop()
			interior.has_beer = true
			interior.walker.set_carrying(true)
			interior.walker.position = interior.QUEUE_FRONT + interior.QUEUE_STEP * 3
			interior._neighbor_t = 0.01
		"juntti":
			player.position = juntti.position + Vector3(0, 0.3, 10)
		"kick":
			player.position = juntti.position + Vector3(0, 0.3, 1.2)
		"wife":
			player.position = wife.position + Vector3(0, 0.3, 14)
			player.rotation.y = PI
		"taxistand":
			if player != walker_out:
				_toggle_mount()
			var shop_c := M.w(M.SHOP_BUILDING)
			print("STAND kauppa=", shop_c, " kauppavyöhyke=", shop_zone - shop_c, " taksi=", world.taxi_pos - shop_c)
			walker_out.global_position = world.taxi_pos + Vector3(8.0, 0.5, -6.0)
			walker_out.rotation.y = B.yaw_to(world.taxi_pos - walker_out.global_position)
		"taxitest":
			# Taksi Raaheen: vihje, menomatka, kädenvääntö (A/D-tahti), paluu ja uusi päivä. Kuvat --shot-kansioon,
			# tallennus palautetaan lopuksi.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var shot := func(name: String) -> void:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.get_base_dir().path_join("taxi_%s.png" % name))
			if player != walker_out:
				_toggle_mount()
			money = 30.0
			walker_out.global_position = world.taxi_pos + Vector3(2.2, 0.5, 1.0)
			walker_out.rotation.y = -PI * 0.5
			for i in 30:
				await get_tree().physics_frame
			await shot.call("parkki")
			print("TAXI hint=", _hint.text)
			await get_tree().process_frame  # kuvakaappauksen jälkeen: painallus seuraavan ruudun alkuun
			Input.action_press("interact")
			for w in 2:
				await get_tree().process_frame
			Input.action_release("interact")
			print("TAXI state=", state, " money=", money)
			await get_tree().create_timer(5.0, true, false, true).timeout
			await shot.call("meno")
			var bar: Node = null
			for i in 60:
				await get_tree().create_timer(0.5, true, false, true).timeout
				for c in get_children():
					if c is BarGame:
						bar = c
				if bar != null:
					break
			if bar == null:
				print("TAXI baaria ei löytynyt")
				get_tree().quit()
				return
			await get_tree().create_timer(1.5, true, false, true).timeout
			await shot.call("baari")
			await get_tree().process_frame
			Input.action_press("interact")
			for w in 2:
				await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().create_timer(3.3, true, false, true).timeout
			var key := "left"
			var n := 0
			var pace := 0.07  # s painallusten välissä (lisäksi 3 ruutua); --pace=0.3 kokeilee hidasta tahtia
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--pace="):
					pace = float(arg.substr(7))
			while bar._phase == "wrestle":
				await get_tree().process_frame  # painallus ruudun alkuun, ei ajastimen jälkeen
				Input.action_press(key)
				for w in 2:
					await get_tree().process_frame
				Input.action_release(key)
				key = "right" if key == "left" else "left"
				await get_tree().create_timer(pace, true, false, true).timeout
				n += 1
				if n == 12:
					await shot.call("vaanto")
					await get_tree().process_frame
			print("TAXI vääntö: kulma=%.2f painalluksia=%d" % [bar._angle, n])
			await get_tree().create_timer(4.5, true, false, true).timeout
			await get_tree().create_timer(4.0, true, false, true).timeout
			await shot.call("paluu")
			for i in 80:
				await get_tree().create_timer(0.5, true, false, true).timeout
				if i == 6:
					await shot.call("koti")
				if state != "cutscene":
					break
			print("TAXI after state=%s money=%.2f mielihyva=%d maine=%d msg=%s" % [state, money, mielihyva, maine,
				_msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"overview":
			var cam := Camera3D.new()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 1600.0
			cam.far = 3000.0
			add_child(cam)
			cam.global_position = M.w(M.SIZE / 2.0) + Vector3(0, 1200, 0)
			cam.rotation_degrees = Vector3(-90, 0, 0)
			cam.current = true
			$WorldEnvironment.environment.fog_enabled = false
		"route":
			player.position = M.w(Vector2(545, 660)) + Vector3(0, 0.3, 0)
			player.rotation.y = B.yaw_to(M.w(Vector2(300, 620)) - M.w(Vector2(545, 660)))
		"fight":
			beers = 6
			_on_kicked(Vector3.RIGHT)
			for i in 130:
				await get_tree().process_frame
		"field", "bog":
			var M2 := preload("res://scripts/map_data.gd")
			player.position = M2.w(Vector2(450, 730) if scene == "field" else Vector2(400, 1110)) + Vector3(0, 0.3, 0)
			player.speed = 9.0
		"laavu":
			player.position = M.w(M.LAAVU) + Vector3(0, 0.3, -18)
			player.rotation.y = PI
		"laavufire":
			player.position = M.w(M.LAAVU) + Vector3(-3.0, 0.3, -7.0)
			player.rotation.y = PI - 0.4
			world.fire.visible = true
			guard.mode = "gone"
			guard.visible = false
		"compass", "maptarget":
			# Kompassin kohde K-Marketille (ja lähelle toinen testi: kartta auki).
			_paper.target = M.w2(M.SHOP_ZONE)
			_paper.has_target = true
			if scene == "maptarget":
				_paper.toggle()
		"map":
			for n in find_children("*", "Control", true, false):
				if n.has_method("toggle"):
					n.toggle()
		"bikeside":
			var cam := Camera3D.new()
			cam.fov = 35.0
			player.add_child(cam)
			cam.position = Vector3(3.2, 1.1, 0.1)
			cam.look_at_from_position(player.global_position + Vector3(3.2, 1.1, 0.1), player.global_position + Vector3(0, 0.9, 0), Vector3.UP)
			cam.current = true
			player.speed = 3.0
		"signs":
			player.position = M.w(M.J_K) + Vector3(-1, 0.3, 12)
			player.rotation.y = -0.5
		"signs2":
			player.position = M.w(M.J_H2) + Vector3(-3, 0.3, -10)
			player.rotation.y = PI + 0.3
		"signclose":
			var a2 := M.w2(M.J_K)
			var d2 := (M.w2(Vector2(320, 790)) - a2).normalized()
			var at := a2 + d2 * 8.0 + d2.orthogonal() * 6.2
			var cam := Camera3D.new()
			cam.fov = 45.0
			add_child(cam)
			var eye := Vector3(at.x, 2.0, at.y) + Vector3(d2.orthogonal().x, 0, d2.orthogonal().y) * 2.6 + Vector3(d2.x, 0, d2.y) * 1.4
			cam.look_at_from_position(eye, Vector3(at.x, 2.35, at.y) + Vector3(d2.x, 0, d2.y) * 0.6, Vector3.UP)
			cam.current = true
		"tractor":
			player.position = M.w(Vector2(352, 745)) + Vector3(0, 0.3, 0)
			player.rotation.y = PI / 2.0
		"picktest":
			# Puolukan poiminta: rauhallinen A/D-tahti, sitten räpellys ja pelkkä A. Tallennus palautetaan lopuksi.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			if player != walker_out:
				_toggle_mount()
			var tries := [["tahti 0,25 s", 15], ["räpellys joka ruutu", 1], ["vain A", 15]]
			for tr in tries:
				var berry: Dictionary = {}
				for f in world.forage:
					if not f.taken and f.kind in BERRIES:
						berry = f
						break
				walker_out.global_position = berry.pos + Vector3(0.8, 0.5, 0)
				walker_out.stamina = 100.0
				walker_out.exhausted = false
				for i in 20:
					await get_tree().physics_frame
				Input.action_press("interact")
				for w in 2:
					await get_tree().process_frame
				Input.action_release("interact")
				var t0 := Time.get_ticks_msec()
				var key := "left"
				for n in 400:
					if _pick_t < 0.0:
						break
					Input.action_press(key)
					for w in 2:
						await get_tree().process_frame
					Input.action_release(key)
					if tr[0] != "vain A":
						key = "right" if key == "left" else "left"
					for w in tr[1]:
						await get_tree().process_frame
				print("PICK %s: valmis=%s aika=%.1f s mittari=%.2f kunto=%.0f ämpäri=%s ohjaus=%s" % [tr[0], _pick_t < 0.0,
					(Time.get_ticks_msec() - t0) / 1000.0, _pick_meter, walker_out.stamina, bucket, walker_out.controls_enabled])
				_stop_picking()
			# Sieni: pelkkä odotus, ähkäisy kumartuessa ja noustessa.
			for f in world.forage:
				if not f.taken and not (f.kind in BERRIES):
					walker_out.global_position = f.pos + Vector3(0.8, 0.5, 0)
					break
			for i in 20:
				await get_tree().physics_frame
			Input.action_press("interact")
			for w in 2:
				await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().create_timer(PICK_TIME + 0.5).timeout
			print("PICK sieni: valmis=%s ämpäri=%s" % [_pick_t < 0.0, bucket])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"shoptest":
			_toggle_mount()
			walker_out.global_position = shop_zone + Vector3(1.5, 0.5, 0)
			for i in 30:
				await get_tree().physics_frame
			print("SHOP hint=", _hint.text)
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("SHOP state=", state)
		"kotaview", "kotain", "tower":
			_toggle_mount()
			walker_out.global_position = world.kota.to_global(Vector3(-2.5, 0.4, -9.0))
			walker_out.rotation.y = world.kota.global_rotation.y
			for i in 40:
				await get_tree().process_frame
			var cam3 := Camera3D.new()
			add_child(cam3)
			cam3.fov = 60
			if scene == "kotaview":
				cam3.look_at_from_position(world.kota.to_global(Vector3(-8, 4.5, -13)), world.kota.to_global(Vector3(-1, 1.2, 1)), Vector3.UP)
			elif scene == "kotain":
				cam3.look_at_from_position(world.kota.to_global(Vector3(0.3, 1.5, -2.4)), world.kota.to_global(Vector3(0, 0.7, 1.5)), Vector3.UP)
			else:
				cam3.look_at_from_position(world.kota.to_global(Vector3(-4, 3.0, -8)), world.kota.to_global(Vector3(9, 4, 7)), Vector3.UP)
			cam3.current = true
			if scene == "kotain":
				world.kota.set_fire(true)
				world.kota.say("raimo", "Tässä kodassa on enemmän kieltokylttejä kuin halkoja.")
		"mokkiview", "mokkisauna", "mokkiyard", "mokkilake":
			_toggle_mount()
			walker_out.global_position = mokki.to_global(Vector3(-2, 0.4, -14))
			for i in 40:
				await get_tree().process_frame
			var cam4 := Camera3D.new()
			add_child(cam4)
			cam4.fov = 60
			if scene == "mokkiview":
				cam4.look_at_from_position(mokki.to_global(Vector3(-16, 9, -22)), mokki.to_global(Vector3(2, 1.5, -1)), Vector3.UP)
			elif scene == "mokkisauna":
				cam4.look_at_from_position(mokki.to_global(Vector3(0, 3.5, 12)), mokki.to_global(Vector3(9, 1.2, 6.5)), Vector3.UP)
				mokki.set_sauna_fire(true)
				mokki.set_tub_fire(true)
			elif scene == "mokkiyard":
				cam4.look_at_from_position(mokki.to_global(Vector3(9, 5, -6)), mokki.to_global(Vector3(2, 1.0, -6)), Vector3.UP)
			else:
				cam4.look_at_from_position(mokki.to_global(Vector3(-4, 4, 20)), mokki.to_global(Vector3(7, 1.2, 24)), Vector3.UP)
			cam4.current = true
		"mokkifish":
			# Koko kalastusketju: heitä onki, nykäisy, vedä ylös. Tulostaa tilat.
			_toggle_mount()
			var press2 := func() -> void:
				Input.action_press("interact")
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
				await get_tree().process_frame
			walker_out.global_position = mokki.to_global(Mokki.DOCK_LOCAL) + Vector3(0, 0.4, 0)
			for i in 10:
				await get_tree().physics_frame
			print("FISH hint: ", _hint.text, " state=", _fish_state)
			await press2.call()
			print("FISH after cast: state=", _fish_state, " msg=", _msg.text)
			_fish_t = _fish_target + 1.0
			for i in 3:
				await get_tree().physics_frame
			print("FISH after wait: state=", _fish_state, " hint=", _hint.text, " msg=", _msg.text)
			await press2.call()
			print("FISH after reel: state=", _fish_state, " msg=", _msg.text)
		"edgetest":
			for spot in [Vector2(3, 1500), Vector2(450, 3), Vector2(1000, 3957), Vector2(1617, 3000), Vector2(893, 1500)]:
				_edge_cd = 0.0
				player.global_position = M.w(spot) + Vector3(0, 0.5, 0)
				for i in 8:
					await get_tree().physics_frame
				print("EDGE ", spot, " -> ", _msg.text)
		"kotapath":
			var pts: Array = M.ROADS.filter(func(r): return r.name == "Kotapolku")[0].pts
			player.global_position = M.w(pts[5]) + Vector3(0, 0.5, 0)
			player.rotation.y = B.yaw_to(M.w(pts[6]) - M.w(pts[5]))
		"kotagrid":
			var rows := []
			for zi in range(-8, 9):
				var row := ""
				for xi in range(-8, 13):
					var g: Vector3 = world.kota.to_global(Vector3(xi * 2.0, 0, zi * 2.0))
					var sf: String = world.surface_at(g)
					row += "~" if sf == "water" else ("o" if xi == 0 and zi == 0 else ("b" if sf == "bog" else "."))
				rows.append(row)
			print("KGRID local x -16..24 (step 2), z -16..16 (top = -z = door side)")
			for r in rows:
				print("KGRID ", r)
		"minimouse":
			# Oikeat hiiritapahtumat minipeleille: liike kääntää tähtäystä, vasen nappi toimii, sahan veto.
			_toggle_mount()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			var send := func(ev: InputEvent) -> void:
				Input.parse_input_event(ev)
				await get_tree().process_frame
				await get_tree().process_frame
			kota_polkyt = 1
			_start_chop()
			await get_tree().process_frame
			var cg: Node3D = world.kota.get_children().filter(func(c): return c is ChopGame)[0]
			cg._gust_next = 999.0
			var y0: float = cg._yaw
			var mm := InputEventMouseMotion.new()
			mm.relative = Vector2(-120, 0)
			mm.position = get_viewport().get_visible_rect().size / 2.0
			await send.call(mm)
			print("MOUSE chop yaw ", y0, " -> ", cg._yaw, " mouse_mode=", Input.mouse_mode)
			var want: Vector2 = cg._aim_to(ChopGame.PILE + Vector3(0, 0.18, 0))
			cg._yaw = want.x
			cg._pitch = want.y
			await get_tree().process_frame
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = mm.position
			await send.call(click)
			var up := click.duplicate()
			up.pressed = false
			await send.call(up)
			print("MOUSE chop after click phase=", cg._phase)
			# Aseta oikein päin keskelle ja iske vähän sivuun: kirves jää kiinni, peli ei saa jumittua.
			if not cg._flat_down:
				cg._alt_action()
			want = cg._aim_to(Vector3(0, ChopGame.BLOCK_TOP, 0))
			cg._yaw = want.x
			cg._pitch = want.y
			for i in 3:
				await get_tree().process_frame
			await send.call(click)
			await send.call(up)
			for i in 60:
				await get_tree().process_frame
				if cg._phase == "chop":
					break
			want = cg._aim_to(cg._log_pos + Vector3(0.08, ChopGame.LOG_L, 0))
			cg._yaw = want.x
			cg._pitch = want.y
			await get_tree().process_frame
			await send.call(click)
			await send.call(up)
			for i in 400:
				await get_tree().process_frame
				if cg._phase == "chop" and cg._swing_t < 0.0:
					break
			print("MOUSE chop stuck hit -> phase=", cg._phase, " swing_t=", cg._swing_t, " cracks=", cg._cracks, " sub=", cg._sub.text)
			cg._quit()
			await get_tree().process_frame
			_start_saw()
			await get_tree().process_frame
			var sg: Node3D = world.kota.get_children().filter(func(c): return c is SawGame)[0]
			sg._gust_next = 999.0
			var a3: Vector2 = sg._aim_to(Vector3(0, SawGame.LOG_Y + SawGame.R, SawGame.END_Z - 0.36))
			sg._yaw = a3.x
			sg._pitch = a3.y
			await get_tree().process_frame
			await send.call(click)
			await send.call(up)
			print("MOUSE saw after click phase=", sg._phase)
			var s0: float = sg._s
			var mv := InputEventMouseMotion.new()
			mv.relative = Vector2(0, -40)
			mv.position = mm.position
			await send.call(mv)
			print("MOUSE saw stroke s ", s0, " -> ", sg._s, " depth=", sg._depth)
			sg._quit()
			await get_tree().process_frame
		"settingsmenu":
			menu.open_main()
			menu._settings("sub_main")
			for i in 10:
				await get_tree().process_frame
		"kotaplay":
			# Koko ketju: sahaa, pilko, sytytä, kuuntele tarina. Tulostaa tilat.
			_toggle_mount()
			var press := func() -> void:
				Input.action_press("interact")
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
				await get_tree().process_frame
			# Sahaus: merkkaa 36 cm, vedä sahaa suorassa, kunnes pölkky katkeaa. Kaksi pölkkyä.
			walker_out.global_position = world.kota.to_global(Kota.SAW_LOCAL + Vector3(-0.8, 0, 0.3)) + Vector3(0, 0.4, 0)
			for i in 10:
				await get_tree().physics_frame
			print("KOTA hint: ", _hint.text)
			await press.call()
			var sg: Node3D = world.kota.get_children().filter(func(c): return c is SawGame)[0] if state == "minigame" else null
			print("SAW state=", state, " sg=", sg != null)
			sg._gust_next = 999.0
			for n in 2:
				var a2: Vector2 = sg._aim_to(Vector3(0, SawGame.LOG_Y + SawGame.R, SawGame.END_Z - 0.36))
				sg._yaw = a2.x
				sg._pitch = a2.y
				for i in 5:
					await get_tree().process_frame
				if n == 0:
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(path.replace(".png", "_mark.png"))
					await get_tree().process_frame
				await press.call()
				print("SAW phase=", sg._phase, " cut_z=", sg._cut_z, " task=", sg._task.text)
				var dir := 1.0
				for i in 900:
					if sg._phase != "saw":
						break
					sg._tilt_hand = -(sg._tilt - sg._tilt_hand)  # pidä suorassa
					sg._stroke(dir * 0.02)
					if absf(sg._s) >= SawGame.STROKE - 0.001:
						dir = -dir
					await get_tree().process_frame
					if n == 0 and i == 120:
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png(path.replace(".png", "_saw.png"))
				print("SAW cut done phase=", sg._phase, " made=", sg.polkyt_made, " polkyt=", kota_polkyt, " sub=", sg._sub.text)
				for i in 30:
					await get_tree().process_frame
				if n == 0:
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(path.replace(".png", "_cut.png"))
				for i in 600:
					if sg._phase == "mark":
						break
					await get_tree().process_frame
			sg._quit()
			await get_tree().process_frame
			print("SAW after state=", state, " msg=", _msg.text)
			# Halonhakkuu: väärin päin asetettu pyörähtää pois, oikein päin keskelle ja isku keskelle.
			walker_out.global_position = world.kota.to_global(Kota.CHOP_LOCAL + Vector3(0.8, 0, 0)) + Vector3(0, 0.4, 0)
			for i in 10:
				await get_tree().physics_frame
			print("KOTA hint: ", _hint.text)
			await press.call()
			var cg: Node3D = world.kota.get_children().filter(func(c): return c is ChopGame)[0] if state == "minigame" else null
			print("CHOP state=", state, " cg=", cg != null)
			cg._gust_next = 999.0
			var aim := func(target: Vector3) -> void:
				var dv: Vector3 = target - ChopGame.EYE
				cg._yaw = atan2(dv.x, dv.z)
				cg._pitch = -atan2(-dv.y, Vector2(dv.x, dv.z).length())
			aim.call(ChopGame.PILE + Vector3(0, 0.18, 0))
			for i in 5:
				await get_tree().process_frame
			await press.call()
			print("CHOP phase=", cg._phase, " flat=", cg._flat_down)
			if cg._flat_down:
				cg._alt_action()
			aim.call(Vector3(0, ChopGame.BLOCK_TOP, 0))
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_hold.png"))
			await get_tree().process_frame
			await press.call()
			print("CHOP after wrong place phase=", cg._phase, " sub=", cg._sub.text)
			for i in 30:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_roll.png"))
			for i in 60:
				await get_tree().process_frame
			aim.call(ChopGame.PILE + Vector3(0, 0.18, 0))
			await get_tree().process_frame
			await press.call()
			if not cg._flat_down:
				cg._alt_action()
			aim.call(Vector3(0, ChopGame.BLOCK_TOP, 0))
			for i in 20:
				await get_tree().process_frame
			await press.call()
			print("CHOP after good place phase=", cg._phase, " sub=", cg._sub.text)
			for i in 40:
				await get_tree().process_frame
			aim.call(Vector3(cg._log_pos.x, ChopGame.BLOCK_TOP + ChopGame.LOG_L, cg._log_pos.z))
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_aim.png"))
			await get_tree().process_frame
			await press.call()
			for i in 24:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_split.png"))
			for i in 50:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_split2.png"))
			print("CHOP after hit phase=", cg._phase, " sub=", cg._sub.text, " polkyt=", kota_polkyt, " halot=", kota_halot)
			for i in 90:
				await get_tree().process_frame
			cg._quit()
			await get_tree().process_frame
			print("KOTA polkyt=", kota_polkyt, " halot=", kota_halot, " state=", state, " msg=", _msg.text)
			walker_out.global_position = world.kota.to_global(Vector3(0.9, 0.4, -1.4))
			for i in 10:
				await get_tree().physics_frame
			print("KOTA hint: ", _hint.text)
			await press.call()
			print("KOTA fire=", world.kota.fire_on, " halot=", kota_halot)
			for i in 5:
				await get_tree().physics_frame
			print("KOTA hint: ", _hint.text)
			await press.call()
			for i in 60:
				await get_tree().process_frame
			print("KOTA story state=", state, " msg=", _msg.text)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_story.png"))
			for i in 2400:
				await get_tree().process_frame
				if state != "cutscene":
					break
			print("KOTA after state=", state, " kuultu=", tarinat_kuultu, " msg=", _msg.text)
			# Torni: portaita ylös kävellen.
			var base: Vector3 = world.kota.to_global(Kota.TOWER_LOCAL)
			print("TOWER base ground ", Terrain.h(base.x, base.z))
			var run := Kota.TOWER_TOP_Y / tan(deg_to_rad(33.0))
			var tb := Basis(Vector3.UP, world.kota.global_rotation.y - 0.5)
			var foot: Vector3 = base + tb * Vector3(0, 0, -1.75 - run - 1.2)
			walker_out.global_position = foot + Vector3(0, 0.5, 0)
			walker_out.rotation.y = world.kota.global_rotation.y - 0.5 + PI  # kohti tornia (+Z)
			for i in 20:
				await get_tree().physics_frame
			Input.action_press("forward")
			for i in 900:
				await get_tree().physics_frame
				if i % 120 == 0 or (i > 500 and _hint.text != "" and i % 30 == 0):
					print("TOWER t=", i, " spd=", walker_out.speed, " y=%.2f ground=%.2f hint=%s" % [walker_out.global_position.y, Terrain.h(walker_out.global_position.x, walker_out.global_position.z), _hint.text])
			Input.action_release("forward")
		"chocotest":
			# Suklaa karkkitelineestä, maksu, ulos ja WASTED: lepyttääkö Päivin? Tallennus palautetaan lopuksi.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var ok := 0
			for i in 1000:
				has_chocolate = true
				ok += int(_offer_chocolate() == "ok")
			print("CHOCO ok-osuus %.2f" % (ok / 1000.0))
			_enter_shop()
			for i in 10:
				await get_tree().physics_frame
			interior.walker.position = interior.CANDY_SPOT
			for i in 5:
				await get_tree().physics_frame
			print("CHOCO hint=", interior.hint)
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("CHOCO cart=", interior.cart, " total=", interior._total())
			interior.has_paid = true
			_on_shop_exited(false)
			print("CHOCO has_chocolate=", has_chocolate, " money=", money)
			_lose("Testi", "wife")
			print("CHOCO mercy=", _choco_mercy, " has_chocolate=", has_chocolate)
			for i in 60:
				await get_tree().create_timer(0.5, true, false, true).timeout
				if state != "cutscene":
					break
			print("CHOCO after state=", state, " money=", money, " msg=", _msg.text.replace("\n", " | "))
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"hilltest":
			# Jyrkin rinne tien varrella: aja ylös ja alas, pysyykö pyörä maan pinnalla.
			var best := Vector3.ZERO
			var slope := 0.0
			for r in M.ROADS:
				for q in r.pts:
					var wq := M.w(q)
					var n := Terrain.normal(wq.x, wq.z)
					if 1.0 - n.y > slope:
						slope = 1.0 - n.y
						best = wq
			var n2 := Terrain.normal(best.x, best.z)
			player.global_position = best + Vector3(0, 0.4, 0)
			player.rotation.y = atan2(n2.x, n2.z)  # kohti ylämäkeä
			print("HILL at ", best, " slope %.1f %%" % (Vector2(n2.x, n2.z).length() / n2.y * 100.0))
			Input.action_press("forward")
			for i in 360:
				await get_tree().physics_frame
				if i % 60 == 0:
					var p := player.global_position
					print("HILL t=", i, " y=%.2f ground=%.2f speed=%.1f" % [p.y, Terrain.h(p.x, p.z), player.speed])
			Input.action_release("forward")
		"sprinttest":
			# Pisin suora tie: ensin tavallinen poljenta, sitten spurtti (Shift), kunnes kunto loppuu.
			var a := Vector3.ZERO
			var b := Vector3.ZERO
			for r in M.ROADS:
				for j in r.pts.size() - 1:
					var p0 := M.w(r.pts[j])
					var p1 := M.w(r.pts[j + 1])
					if p0.distance_to(p1) > a.distance_to(b):
						a = p0
						b = p1
			if player != bike:
				_toggle_mount()
			var d := (b - a).normalized()
			bike.global_position = Vector3(a.x, Terrain.h(a.x, a.z) + 0.4, a.z)
			bike.rotation.y = atan2(-d.x, -d.z)
			print("SPRINT road %.0f m" % a.distance_to(b))
			var shift := InputEventKey.new()
			shift.keycode = KEY_SHIFT
			Input.action_press("forward")
			for i in 600:
				if i == 180:
					shift.pressed = true
					Input.parse_input_event(shift)
				await get_tree().physics_frame
				if i % 60 == 59:
					print("SPRINT t=%d speed=%.1f stamina=%.0f sprinting=%s exhausted=%s fov=%.1f" % [i, bike.speed,
						walker_out.stamina, bike.sprinting, walker_out.exhausted, bike._cam.fov])
			shift.pressed = false
			Input.parse_input_event(shift)
			Input.action_release("forward")
			# Jalan: juoksu kuluttaa kuntoa, eikä parkissa oleva pyörä saa palauttaa sitä samalla.
			for i in 120:
				await get_tree().physics_frame
			_toggle_mount()
			walker_out.stamina = 100.0
			walker_out.exhausted = false
			shift.pressed = true
			Input.parse_input_event(shift)
			Input.action_press("forward")
			for i in 120:
				await get_tree().physics_frame
			print("SPRINT jalan 2 s juoksua: stamina=%.0f (odotus ~64)" % walker_out.stamina)
			shift.pressed = false
			Input.parse_input_event(shift)
			Input.action_release("forward")
		"tractortest":
			# Onnistunut kotiinpaluu ja sen jälkeen pellolle: jemmarin pitää hyökätä.
			state = "to_home"
			beers = 6
			jemma = 0
			_win()
			for i in 5:
				await get_tree().physics_frame
			print("AFTER WIN hazards process_mode=", _hazards.process_mode, " state=", state)
			player.position = M.w(Vector2(352, 745)) + Vector3(0, 0.3, 0)
			var hit := -1
			for i in 600:
				await get_tree().physics_frame
				if state == "fight":
					hit = i
					break
			print("TRACTOR after win: fight at frame ", hit, " mode=", tractor.mode)
		"fightfx":
			beers = 6
			_on_kicked(Vector3.RIGHT)
			for i in 130:
				await get_tree().process_frame
			fight._j.position.x = fight._p.position.x + 1.2
			fight._p._start_attack("spin")
			for i in 14:
				await get_tree().process_frame
			fight._j.take_hit(12.0, 1.0, 3.2)
			fight.on_hit(fight._p, fight._j, false, "kick")
			fight.on_hit(fight._p, fight._j, false, "punch")
			for i in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()
			return
		"trailsign":
			var a3 := M.w2(M.J_H2)
			var d3 := (M.w2(Vector2(770, 1290)) - a3).normalized()
			var at3 := a3 + d3 * 5.0 + d3.orthogonal() * 3.0
			var cam := Camera3D.new()
			cam.fov = 40.0
			add_child(cam)
			var n3 := Vector3(-d3.y, 0, d3.x)
			var sp := Vector3(at3.x, 1.55, at3.y) + Vector3(d3.x, 0, d3.y) * 0.8
			cam.look_at_from_position(sp + n3 * 2.4 + Vector3(0, 0.2, 0), sp, Vector3.UP)
			cam.current = true
		"infoboard":
			var cam := Camera3D.new()
			cam.fov = 40.0
			add_child(cam)
			var ib := M.w(M.LAAVU) + Vector3(3.6, 0, -3.2)
			var nrm := Vector3(-sin(0.45), 0, -cos(0.45))
			cam.look_at_from_position(ib + Vector3(0, 1.5, 0) - nrm * -2.6, ib + Vector3(0, 1.4, 0), Vector3.UP)
			cam.current = true
			guard.visible = false
		"guardleave":
			player.position = M.w(M.LAAVU) + Vector3(0, 0.3, -20)
			guard.defeat()
			for i in 520:
				await get_tree().process_frame
		"overlap":
			# Polku ja tie päällekkäin: Järvikujan pää, josta laavupolku lähtee.
			player.position = M.w(M.J_H2) + Vector3(-4, 0.3, -9)
			player.rotation.y = PI + 0.2
		"walk":
			_toggle_mount()
			walker_out.rotation.y += 0.6
			walker_out.stamina = 30.0
			walker_out.exhausted = true
		"walkmap":
			_toggle_mount()
			walker_out.global_position += Vector3(40, 0, -60)
			for n in find_children("*", "Control", true, false):
				if n.has_method("toggle"):
					n.toggle()
		"hedgeclose":
			var cam := Camera3D.new()
			cam.fov = 50.0
			add_child(cam)
			var hb2 := M.w(M.HOME_BUILDING)
			cam.look_at_from_position(hb2 + Vector3(-19, 1.6, 6), hb2 + Vector3(-14, 0.8, -2), Vector3.UP)
			cam.current = true
			_msg.text = ""
		"cars":
			var cam := Camera3D.new()
			cam.fov = 45.0
			add_child(cam)
			var hb3 := M.w(M.HOME_BUILDING)
			cam.look_at_from_position(hb3 + Vector3(-20, 1.6, -7), hb3 + Vector3(-14, 0.8, 0), Vector3.UP)
			cam.current = true
			_msg.text = ""
		"tractorside", "tractorfront", "tractortop":
			player.position = M.w(Vector2(352, 745)) + Vector3(0, 0.3, 0)
			var cam3 := Camera3D.new()
			cam3.fov = 40.0
			add_child(cam3)
			tractor.set_physics_process(false)
			var tb := tractor.global_transform.basis
			var tp3 := tractor.global_position + tb * Vector3(0, 1.9, 0.75)
			var off: Vector3 = {"tractorside": tb * Vector3(6.0, 0.2, 0), "tractorfront": tb * Vector3(0, 0.4, -6.5),
				"tractortop": tb * Vector3(0.01, 6.0, 0.3)}[scene]
			cam3.look_at_from_position(tp3 + off, tp3, Vector3.UP if scene != "tractortop" else -tb.z)
			cam3.current = true
			_msg.text = ""
		"tractorclose":
			player.position = M.w(Vector2(352, 745)) + Vector3(0, 0.3, 0)
			player.rotation.y = PI / 2.0
			var cam2 := Camera3D.new()
			cam2.fov = 45.0
			add_child(cam2)
			var tp2 := tractor.global_position
			cam2.look_at_from_position(tp2 + Vector3(-5.5, 2.0, -4.0), tp2 + Vector3(0, 1.3, 0), Vector3.UP)
			cam2.current = true
			tractor.set_physics_process(false)
			_msg.text = ""
		"homeview", "homeview2":
			var cam := Camera3D.new()
			cam.fov = 55.0
			add_child(cam)
			var hb := M.w(M.HOME_BUILDING)
			var eye := M.w(Vector2(784, 1196)) + Vector3(0, 1.7, 0) if scene == "homeview" else M.w(Vector2(790, 1150)) + Vector3(0, 1.7, 0)
			cam.look_at_from_position(eye, hb + Vector3(-4, 1.8, 0), Vector3.UP)
			cam.current = true
			_msg.text = ""
		"mkey":
			for i in 30:
				await get_tree().process_frame
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_M
			ev.keycode = KEY_M
			ev.pressed = true
			Input.parse_input_event(ev)
			for i in 3:
				await get_tree().process_frame
			ev = ev.duplicate()
			ev.pressed = false
			Input.parse_input_event(ev)
			print("PAPER visible=", _paper.visible, " paused=", get_tree().paused)
			var sc0: float = _paper._scroll
			Input.action_press("back")
			for i in 30:
				await get_tree().process_frame
			Input.action_release("back")
			print("PAPER scroll ", sc0, " -> ", _paper._scroll, " max ", _paper._max_scroll())
			ev = ev.duplicate()
			ev.pressed = true
			Input.parse_input_event(ev)
			for i in 3:
				await get_tree().process_frame
			ev = ev.duplicate()
			ev.pressed = false
			Input.parse_input_event(ev)
			for i in 3:
				await get_tree().process_frame
			print("PAPER after 2nd M visible=", _paper.visible, " paused=", get_tree().paused)
		"fpsview":
			CamCtl.fps = true
			CamCtl.pitch = -0.1
		"orbit":
			CamCtl.yaw = 2.3
			CamCtl.pitch = -0.3
			CamCtl._idle = 0.0
		"fpswalk":
			_toggle_mount()
			CamCtl.fps = true
			CamCtl.pitch = -0.25
			CamCtl.yaw = 0.8
		"wasted":
			for i in 20:
				await get_tree().process_frame
			_lose("Päivi nappasi kiinni!", "wife")
			for i in 60:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_1.png"))
			for i in 210:
				await get_tree().process_frame
		"garage":
			beers = 6
			jemma = 20
			_win()
			print("GARAGE jemma=", jemma)
			for i in 200:
				await get_tree().process_frame
		"sunset":
			beers = 5
			fire_lit = true
			sausage_done = true
			stash_laavu = 7
			_win_laavu()
			print("SUNSET laavu=", stash_laavu, " jemma=", jemma, " beers=", beers)
			for i in 300:
				await get_tree().process_frame
		"grilli":
			player.position = M.w(M.GRILLIKATOS) + Vector3(-3, 0.3, 8)
			player.rotation.y = 0.3
		"stash":
			laavu_conquered = true
			guard.vanish()
			_toggle_mount()
			walker_out.global_position = M.w(M.LAAVU) + Vector3(3.8, 0.3, 1.4)
			walker_out.rotation.y = -0.6
			beers = 6
			jemma = 10
			for i in 20:
				await get_tree().process_frame
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("STASH laavu=", stash_laavu, " beers=", beers)
		"bikestay":
			# Pyörä kaupalle, uusi päivä kotoa: pyörän pitää jäädä, pelaaja jalan. Sitten tallennus.
			var left := shop_zone + Vector3(6, 0.3, 6)
			bike.global_position = left
			_new_day(home_zone + Vector3(0, 0, 4), false)
			for i in 30:
				await get_tree().physics_frame
			print("BIKESTAY on_foot=", player == walker_out, " bike_moved=%.2f" % bike.global_position.distance_to(left),
				" walker_home=%.1f" % walker_out.global_position.distance_to(home_zone), " msg=", _msg.text.replace("\n", " | "))
			_save_game()
		"bikeload":
			print("BIKELOAD saved=", _bike_saved, " note=", _apply_saved_bike().strip_edges(), " on_foot=", player == walker_out,
				" bike_at_shop=%.1f" % bike.global_position.distance_to(shop_zone))
		"stashtour":
			# Jokainen jemma: E piilottaa yhden, Q ottaa yhden, kuva paikasta.
			laavu_conquered = true
			guard.vanish()
			_toggle_mount()
			_hud.visible = true
			for id in STASHES:
				var at := _stash_pos(id)
				walker_out.global_position = at + Vector3(1.6, 0.6, 1.6)
				walker_out.look_at(Vector3(at.x, walker_out.global_position.y, at.z))
				walker_out.velocity = Vector3.ZERO
				beers = 3
				walker_out.set_carrying(true)
				for i in 40:
					await get_tree().process_frame
				print("STASH ", id, " at ", at, " hint=", _hint.text)
				var before: int = stash.get(id, 0)
				Input.action_press("interact")
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
				print("  E: ", before, " -> ", stash.get(id, 0), " beers=", beers)
				Input.action_press("bell")
				await get_tree().process_frame
				Input.action_release("bell")
				await get_tree().process_frame
				print("  Q: -> ", stash.get(id, 0), " beers=", beers)
				_msg.text = ""
				var tc := Camera3D.new()
				add_child(tc)
				tc.global_position = at + Vector3(5.0, 3.5, 5.0)
				tc.look_at(at, Vector3.UP)
				tc.current = true
				for i in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_" + id + ".png"))
				tc.queue_free()
				walker_out.activate_camera()
		"carry":
			laavu_conquered = true
			guard.vanish()
			_toggle_mount()
			walker_out.global_position = M.w(M.LAAVU) + Vector3(3.8, 0.3, 1.4)
			bike.global_position = walker_out.global_position + Vector3(1.0, 0, 0)
			stash_laavu = 15
			for i in 20:
				await get_tree().process_frame
			Input.action_press("bell")
			await get_tree().process_frame
			Input.action_release("bell")
			await get_tree().process_frame
			print("CARRY took beers=", beers, " laavu=", stash_laavu)
			Input.action_press("mount")
			await get_tree().process_frame
			Input.action_release("mount")
			await get_tree().process_frame
			print("CARRY on_bike=", player == bike, " hint=", _hint.text, " msg=", _msg.text)
		"found":
			_hud.visible = false
			cutscene.jemma_found(home_zone, 8, 12, func() -> void: pass)
			for i in 330:
				await get_tree().process_frame
		"shopfront":
			player.position = shop_zone + Vector3(0, 0.3, 14)
		"shopsigns":
			# Kaupan kyltit (KASSA, OLUET, GRILLI, ULOS) yleiskuvana ilman leijuvia opasteita.
			_enter_shop()
			var sc := Camera3D.new()
			add_child(sc)
			sc.global_position = INTERIOR_POS + Vector3(2.0, 9.0, 14.0)
			sc.look_at(INTERIOR_POS + Vector3(0, 1.0, 0), Vector3.UP)
			sc.current = true
		"mummot":
			# Pyörällä lujaa penkin ohi: mummot suuttuvat ja heittävät kettukarkkeja. Sitten jalan poimimaan.
			var hits := [0]
			mummot.hit.connect(func(_d: Vector3) -> void: hits[0] += 1)
			var bp: Vector3 = mummot.global_position
			bike.global_position = bp + Vector3(-9.0, 0.3, 2.5)
			bike.rotation.y = B.yaw_to(Vector3(1, 0, 0))
			for i in 10:
				await get_tree().physics_frame
			var sc := Camera3D.new()
			add_child(sc)
			sc.global_position = bp + Vector3(3.0, 1.6, 4.5)
			sc.look_at(bp + Vector3(0, 0.8, 0), Vector3.UP)
			sc.current = true
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_bench.png"))
			sc.queue_free()
			bike.activate_camera()
			bike.speed = 8.0
			Input.action_press("forward")
			for i in 90:
				await get_tree().physics_frame
			Input.action_release("forward")
			print("MUMMOT angry=%s status=%s" % [mummot.is_angry(), _status.text])
			for i in 180:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_throw.png"))
			for i in 240:
				await get_tree().physics_frame
			print("MUMMOT hits=%d ground=%d angry=%s" % [hits[0], mummot._ground.size(), mummot.is_angry()])
			_toggle_mount()
			var s0: float = walker_out.stamina
			walker_out.stamina = 50.0
			if not mummot._ground.is_empty():
				walker_out.global_position = mummot._ground[0].node.global_position + Vector3(0, 0.4, 0)
			for i in 20:
				await get_tree().physics_frame
			print("MUMMOT picked stamina 50 -> %.0f ground=%d msg=%s" % [walker_out.stamina, mummot._ground.size(), _msg.text])
		"kauppalista":
			# Päivin lista: 3 oikein, 1 väärä väri ja 1 ylimääräinen; kotona palaute. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			shopping_list = [["tamponi", "vihreä"], ["maito", "punainen"], ["ristikkolehti", "sininen"], ["voi", "keltainen"]]
			print("LISTA hud=", _stats.text.split("\n")[-1])
			_enter_shop()
			var iw: CharacterBody3D = interior.walker
			var picks := [["tamponi", "vihreä"], ["maito", "punainen"], ["ristikkolehti", "sininen"], ["voi", "sininen"], ["kahvi", "punainen"]]
			for pk in picks:
				var idx: int = ShopInterior.PRODUCTS.keys().find(pk[0])
				iw.position = Vector3(10.4, 0, ShopInterior.SHELF_Z0 + idx + 0.5)
				await get_tree().process_frame
				var ci: int = ShopInterior.COLORS.keys().find(pk[1])
				for k in ci:
					Input.action_press("bell")
					await get_tree().process_frame
					Input.action_release("bell")
					await get_tree().process_frame
				print("  at %s hint=%s" % [pk[0], interior.hint])
				Input.action_press("interact")
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
			print("LISTA bag=", interior.bag, " hud=", _stats.text.split("\n")[-1])
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_shelf.png"))
			interior.has_paid = true
			interior.exited.emit(false)
			await get_tree().process_frame
			_toggle_mount()
			walker_out.global_position = home_zone + Vector3(0, 0.5, 2.0)
			for i in 20:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("LISTA home hint=", _hint.text, " bag=", paivi_bag)
			_msg_time = 0.0
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("LISTA feedback=", " || ".join(_msg_queue.map(func(m: Array) -> String: return m[0])), " shown=", _msg.text)
			_new_day(home_zone + Vector3(0, 0, 4), false)
			print("LISTA newday list=", shopping_list, " queue=", _msg_queue.size())
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"purema":
			# Vieras koira: murina, purema, ontuminen, hoito Pekalla ja Päivillä. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			_toggle_mount()
			var sp: Vector3 = stray.global_position
			walker_out.global_position = sp + Vector3(8.0, 0.5, 0)
			walker_out.look_at(Vector3(sp.x, walker_out.global_position.y, sp.z))
			for i in 30:
				await get_tree().physics_frame
			var sc := Camera3D.new()
			add_child(sc)
			sc.global_position = stray.global_position + Vector3(2.5, 1.4, 2.5)
			sc.look_at(stray.global_position + Vector3(0, 0.4, 0), Vector3.UP)
			sc.current = true
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_dog.png"))
			sc.queue_free()
			walker_out.activate_camera()
			print("PUREMA growl msg=", _msg.text.replace("\n", " | "))
			Input.action_press("forward")
			for i in 600:
				await get_tree().physics_frame
				if bitten:
					break
			Input.action_release("forward")
			print("PUREMA bitten=%s hurt=%s status=%s msg=%s" % [bitten, walker_out.hurt, _status.text, _msg.text.replace("\n", " | ")])
			for i in 120:
				await get_tree().physics_frame
			walker_out.global_position = pekka.global_position + Vector3(2.0, 0.5, 0)
			beers = 0
			for i in 20:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("PUREMA pekka hint=", _hint.text)
			var m0 := money
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("PUREMA pekka healed=%s money %s -> %s msg=%s" % [not bitten, _eur(m0), _eur(money), _msg.text.replace("\n", " | ")])
			_on_bitten(Vector3.FORWARD)
			for i in 120:
				await get_tree().physics_frame
			walker_out.global_position = home_zone + Vector3(0, 0.5, 2.0)
			for i in 20:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("PUREMA home hint=", _hint.text)
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("PUREMA paivi healed=%s hurt=%s msg=%s" % [not bitten, walker_out.hurt, _msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"vaino":
			# Väinö karkaa, pelaaja hiipii nuuhkivan koiran viereen, ottaa kiinni ja palauttaa Pekalle.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			_toggle_mount()
			_vaino_at = elapsed
			await get_tree().process_frame
			await get_tree().process_frame
			var mi: MeshInstance3D = vaino.find_children("*", "MeshInstance3D", true, false)[0]
			var ab := mi.global_transform * mi.get_aabb()
			print("VAINO escaped mode=%s aabb size=%s msg=%s" % [vaino.mode, ab.size, _msg.text.replace("\n", " | ")])
			for i in 1800:
				await get_tree().physics_frame
				if vaino.mode == "sniff":
					break
			print("VAINO after bolt mode=%s d_home=%.1f" % [vaino.mode, vaino.global_position.distance_to(vaino.home)])
			walker_out.global_position = vaino.global_position + vaino.global_transform.basis.x * 1.8 + Vector3(0, 0.5, 0)
			walker_out.look_at(Vector3(vaino.global_position.x, walker_out.global_position.y, vaino.global_position.z))
			for i in 5:
				await get_tree().physics_frame
			await get_tree().process_frame
			var vc := Camera3D.new()
			add_child(vc)
			vc.global_position = vaino.global_position + Vector3(2.2, 1.2, 2.2)
			vc.look_at(vaino.global_position + Vector3(0, 0.35, 0), Vector3.UP)
			vc.current = true
			_msg.text = ""
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_dog.png"))
			vc.queue_free()
			walker_out.activate_camera()
			await get_tree().process_frame
			print("VAINO near hint=%s mode=%s" % [_hint.text, vaino.mode])
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("VAINO caught mode=%s msg=%s" % [vaino.mode, _msg.text.replace("\n", " | ")])
			walker_out.global_position = pekka.global_position + Vector3(2.0, 0.5, 0)
			vaino.global_position = walker_out.global_position + Vector3(0, -0.5, 2.0)
			for i in 60:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("VAINO at pekka hint=%s dog_d=%.1f status=%s" % [_hint.text, vaino.distance_to_target(), _status.text])
			var m0 := money
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("VAINO returned valid=%s money %s -> %s beers=%d msg=%s" % [is_instance_valid(vaino), _eur(m0), _eur(money), beers,
				_msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"pontikka":
			# Pannu-Sulo: kuva paikasta, kanisterin osto ja kotiinpaluu. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			_toggle_mount()
			var sp := sulo.global_position
			walker_out.global_position = sp + Vector3(2.0, 0.5, 2.5)
			walker_out.look_at(Vector3(sp.x, walker_out.global_position.y, sp.z))
			for i in 30:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("PONTIKKA hint=", _hint.text, " money=", _eur(money))
			var tc := Camera3D.new()
			add_child(tc)
			var still := M.w(M.PONTIKKA)
			tc.global_position = still + Vector3(4.5, 2.6, 5.0)
			tc.look_at(still + Vector3(-0.6, 0.6, 0), Vector3.UP)
			tc.current = true
			_msg.text = ""
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_still.png"))
			tc.queue_free()
			walker_out.activate_camera()
			await get_tree().process_frame
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("BUY kanister=%s state=%s money=%s hint=%s" % [has_kanister, state, _eur(money), _hint.text])
			for i in 60:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_carry.png"))
			var cc := Camera3D.new()
			add_child(cc)
			var wp := walker_out.global_position
			cc.global_position = wp + walker_out.global_transform.basis * Vector3(-1.6, 0.9, -1.2)
			cc.look_at(wp + Vector3(0, 0.7, 0), Vector3.UP)
			cc.current = true
			_msg.text = ""
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_hand.png"))
			cc.queue_free()
			jemma = 3
			_win()
			print("WIN kanister=%s jemma=%d endings=%d state=%s" % [has_kanister, jemma, jemma_endings, state])
			for i in 60:
				await get_tree().process_frame
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"lawnday":
			# Kasvu, kehu ja motkotus aamulla, varaosa Artolta ja korjaus kaljalla. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			_toggle_mount()
			lawn.lengths.fill(0.5)
			_lawn_praise = true
			_new_day(home_zone + Vector3(0, 0, 4), false)
			print("DAY avg=%.2f money=%s objs=%d msg=%s" % [lawn.avg_len(), _eur(money), lawn.objects.size(), _msg.text.replace("\n", " | ")])
			mower_broken = true
			walker_out.global_position = arto.global_position + Vector3(1.5, 0.3, 0)
			for i in 10:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("ARTO hint=", _hint.text)
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("ARTO part=%s money=%s" % [has_mower_part, _eur(money)])
			beers = 1
			walker_out.global_position = lawn.mower.global_position + Vector3(1.0, 0.3, 0)
			for i in 10:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("FIX hint=", _hint.text)
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("FIX broken=%s part=%s beers=%d" % [mower_broken, has_mower_part, beers])
			_save_game()
			var cfg := ConfigFile.new()
			cfg.load(SAVE_PATH)
			var bytes: PackedByteArray = cfg.get_value("nurmikko", "pituudet", PackedByteArray())
			print("SAVE cells=%d first=%d" % [bytes.size(), bytes[0] if bytes.size() > 0 else -1])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"lawn", "police":
			# Nurmikko: kuva ylhäältä, sitten leikkuu eteenpäin (police: kaksi siiliä terän eteen).
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			_toggle_mount()
			walker_out.global_position = lawn.mower_park + Vector3(1.2, 0.5, 0.8)
			for i in 20:
				await get_tree().physics_frame
			print("LAWN avg=%.2f ratio=%.2f objs=%d hint=%s" % [lawn.avg_len(), lawn.cut_ratio(), lawn.objects.size(), _hint.text])
			_msg.text = ""
			var tc := Camera3D.new()
			add_child(tc)
			var c := Vector3(lawn.rect.get_center().x, 0, lawn.rect.get_center().y)
			c.y = Terrain.h(c.x, c.z)
			tc.global_position = c + Vector3(-9.0, 9.0, 12.0)
			tc.look_at(c, Vector3.UP)
			tc.current = true
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_top.png"))
			tc.queue_free()
			walker_out.activate_camera()
			if scene == "police":
				var sp: Vector3 = lawn.mower_park + Vector3(0, 0, -2.0)
				for o in lawn.objects.duplicate():
					if o.kind == "siili":
						lawn.remove_object(o)
				for k in 2:
					var n := Node3D.new()
					lawn.add_child(n)
					lawn.objects.append({"kind": "siili", "pos": Vector2(sp.x, sp.z - k * 1.5), "r": 0.16, "node": n})
			await get_tree().process_frame
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("MOW start mowing=", mowing, " msg=", _msg.text.replace("\n", " | "))
			Input.action_press("forward")
			for i in 300:
				await get_tree().physics_frame
				if not mowing:
					break
			Input.action_release("forward")
			print("MOW after ratio=%.2f mowing=%s siilit=%d kivet=%d broken=%s police=%s msg=%s" % [lawn.cut_ratio(), mowing,
				lawn_siilit, lawn_kivet, mower_broken, is_instance_valid(police), _msg.text.replace("\n", " | ")])
			_msg.text = ""
			var tc2 := Camera3D.new()
			add_child(tc2)
			tc2.global_position = c + Vector3(-7.0, 10.0, 9.0)
			tc2.look_at(c, Vector3.UP)
			tc2.current = true
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_cut.png"))
			tc2.queue_free()
			player.activate_camera()
			if scene == "police":
				for i in 1800:
					await get_tree().physics_frame
					if i % 120 == 0 and is_instance_valid(police):
						print("  police t=%d d=%.1f mode=%s alerted=%s" % [i / 60, police.global_position.distance_to(player.global_position),
							police.mode, police.alerted])
					if state != "to_shop":
						break
				print("POLICE d=%.1f status=%s state=%s" % [police.global_position.distance_to(player.global_position) if is_instance_valid(police) else -1.0,
					_status.text, state])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
