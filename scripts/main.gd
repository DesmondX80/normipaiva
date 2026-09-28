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
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Kota := preload("res://scripts/kota.gd")
const Fight := preload("res://scripts/fight.gd")
const ChopGame := preload("res://scripts/chop_game.gd")
const SawGame := preload("res://scripts/saw_game.gd")
const LaavuGuard := preload("res://scripts/laavu_guard.gd")
const PaperMap := preload("res://scripts/paper_map.gd")
const Villager := preload("res://scripts/villager.gd")
const Looks := preload("res://scripts/looks.gd")
const Tractor := preload("res://scripts/tractor.gd")
const OnFoot := preload("res://scripts/on_foot.gd")
const Ambience := preload("res://scripts/ambience.gd")
const Cutscene := preload("res://scripts/cutscene.gd")
const Menu := preload("res://scripts/menu.gd")
const PICK_TIME := 2.5
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
const ZONE_RADIUS := 6.0
const START_MONEY := 20.0
const BEER_PRICE := 12.90

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
var _arrow: Node3D
var _stats: Label
var _status: Label
var _hint: Label
var _msg: Label
var _msg_time := 0.0
var _sus_box: Control
var _sus_bar: ProgressBar
var _bird_t := 2.0
var _minimap: Control
var _hud: CanvasLayer
var fight: Node3D
var _fight_prev := ""
var _fight_dir := Vector3.ZERO
var _fight_source := "juntti"  # juntti | laavu
var guard: Node3D
var has_sausage := false
var has_matches := false
var fire_lit := false
var sausage_done := false
var _grill_t := -1.0
var bucket := {}  # laji -> litrat
var _pick_t := -1.0
var _pick_spot: Dictionary = {}
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
## Kaljajemma säilyy pelikerrasta toiseen (user://normipaiva.cfg).
var jemma := 0
var laavu_conquered := false
## Jemmat laavun halkovajassa ja Kiilinlammen grillikatoksella (kotijemma = jemma). Teinit voivat pölliä näistä.
var stash_laavu := 0
var stash_grilli := 0
var _jemma_found := 0
var jemma_endings := 0
const JEMMA_WARN := 9
var day := 1
var cutscene: Node3D
var menu: CanvasLayer
var _env: Environment
var _fps_label: Label
var _sun: DirectionalLight3D
static var skip_menu := false  # "Uusi peli" lataa kentän uudelleen ilman alkuvalikkoa
var jemma_best := 0
var jemma_wins := 0


func _ready() -> void:
	randomize()
	_setup_input()
	_setup_environment()
	world = World.new()
	add_child(world)
	home_zone = world.home_zone
	shop_zone = world.shop_zone
	_build_markers()
	_spawn_player()
	world.follow = player
	player.world = world
	_spawn_hazards()
	_spawn_interior()
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
	var jemma_note := ("\nVaroitus: Päivi voi löytää ison kotijemman!") if jemma >= JEMMA_WARN else ""
	_show_message("Päivä %d · Järvikuja 1, Saloinen.\nPitäis käydä kaupassa... Aja K-Marketille!%s%s" % [day, 
		("\nJemmassa %d kaljaa." % jemma) if jemma > 0 else "", jemma_note], 5.0 if jemma_note == "" else 6.0)
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
	_arrow.global_position = ppos + Vector3.UP * 2.6
	var look := Vector3(target.x, _arrow.global_position.y, target.z)
	if _arrow.global_position.distance_to(look) > 0.5:
		_arrow.look_at(look, Vector3.UP)

	_edge_logic()
	_kota_logic()
	_laavu_logic()
	_stash_logic()
	_forage_logic()
	_neighbor_logic()
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


## Jemmat: jalan E piilottaa mukana olevat kaljat, tai ottaa jemmasta mukaan (jalan kantaa enintään 12).
func _stash_logic() -> void:
	if _hint.text != "" or player != walker_out or player.is_stunned():
		return
	var p := player.global_position
	var sites := [
		["koti", home_zone + Vector3(4.0, 0, -2.0), "kotijemmaan", "kotijemmasta"],
		["laavu", M.w(M.LAAVU) + Vector3(4.6, 0, 2.8), "halkovajan jemmaan", "halkovajan jemmasta"],
		["grilli", M.w(M.GRILLIKATOS), "grillikatoksen jemmaan", "grillikatoksen jemmasta"],
	]
	for site in sites:
		var at: Vector3 = site[1]
		if Vector2(p.x - at.x, p.z - at.z).length() > 2.6:
			continue
		if site[0] == "koti" and state == "to_home":
			return  # kotiinpaluu hoitaa saaliin
		if site[0] == "laavu" and not laavu_conquered:
			return
		var have: int = {"koti": jemma, "laavu": stash_laavu, "grilli": stash_grilli}[site[0]]
		var e := Input.is_action_just_pressed("interact")
		if beers > 0:
			_hint.text = "[E] Piilota %d kaljaa %s (siellä %d)" % [beers, site[2], have]
			if e:
				_stash_add(site[0], beers)
				_show_message("Piilotit %d kaljaa %s.%s" % [beers, site[2], _stash_warning(site[0])], 3.0)
				beers = 0
				player.set_carrying(false)
				Sfx.play("pickup", -2.0, 0.8)
		elif have > 0:
			var take := mini(CARRY_FOOT, have)
			_hint.text = "[E] Ota %d kaljaa %s (siellä %d)" % [take, site[3], have]
			if e:
				_stash_add(site[0], -take)
				beers = take
				player.set_carrying(true)
				Sfx.play("pickup")
				_show_message("Otit %d kaljaa %s. Laavulla ne maistuu!%s" % [take, site[3],
					("\nPyörän kyytiin mahtuu vain %d." % CARRY_BIKE) if take > CARRY_BIKE else ""], 3.0)
		else:
			_hint.text = "Tyhjä jemma. Tänne voi piilottaa kaljoja."
		return


func _stash_add(site: String, n: int) -> void:
	match site:
		"koti":
			jemma = maxi(0, jemma + n)
			jemma_best = maxi(jemma_best, jemma)
		"laavu":
			stash_laavu = maxi(0, stash_laavu + n)
		"grilli":
			stash_grilli = maxi(0, stash_grilli + n)
	_save_game()


func _stash_warning(site: String) -> String:
	if site == "koti" and jemma >= JEMMA_WARN:
		return "\nVAROITUS: kotijemma on jo %d kaljaa – Päivi voi löytää sen! Vie kaljoja laavulle." % jemma
	if site != "koti":
		return "\nMuista: teinit voivat pölliä täältä."
	return ""


func _bucket_total() -> int:
	var t := 0
	for k in bucket:
		t += bucket[k]
	return t


## Marja- ja sienipaikat: pysähdy mättään viereen ja poimi E:llä.
func _forage_logic() -> void:
	var p := player.global_position
	if _pick_t >= 0.0:
		_pick_t += get_process_delta_time()
		var sd := Vector2(_pick_spot.pos.x - p.x, _pick_spot.pos.z - p.z).length()
		if sd > 4.5:
			_pick_t = -1.0
			return
		_hint.text = "Poimitaan %s... %d" % [GOODS[_pick_spot.kind].name, ceili(PICK_TIME - _pick_t)]
		if _pick_t >= PICK_TIME:
			var liters: int = mini(world.FORAGE_KINDS[_pick_spot.kind].liters, BUCKET_MAX - _bucket_total())
			bucket[_pick_spot.kind] = bucket.get(_pick_spot.kind, 0) + liters
			_pick_spot.taken = true
			_pick_spot.node.visible = false
			_show_message("+%d l %s ämpäriin" % [liters, GOODS[_pick_spot.kind].name], 2.0)
			Sfx.play("pickup", -4.0, 1.2)
			_pick_t = -1.0
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


## Arto ostaa marjat ja kertoo paikat, Pekka ostaa sienet ja kehuu kyyhkysaaliitaan.
func _neighbor_logic() -> void:
	if _hint.text != "":
		return
	var e := Input.is_action_just_pressed("interact")
	for v in [arto, pekka]:
		if v.distance_to_player() > 4.2:
			continue
		var who := "arto" if v == arto else "pekka"
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
	_pick_t = -1.0
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
	if state == "to_home" and beers <= 0:
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
	var brought := beers
	jemma += beers
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
		var stats := "Jemmassa oli %d olutta – juhlan paikka!  ·  Onnellisia loppuja: %d" % [had, jemma_endings]
		cutscene.garage("KARBURAATTORIA SÄÄTÄMÄSSÄ", stats, func() -> void: _new_day(home_zone + Vector3(0, 0, 4), false))
		return
	Sfx.play("win_small")
	_new_day(home_zone + Vector3(0, 0, 4), false,
		"Kotona! %d kaljaa jemmaan. Kotijemma %d/%d – kun jemmassa on %d, on juhlan aika.\n" % [
		brought, jemma, JEMMA_GOAL, JEMMA_GOAL])


func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	jemma = cfg.get_value("jemma", "kaljat", 0)
	jemma_best = cfg.get_value("jemma", "ennatys", 0)
	jemma_wins = cfg.get_value("jemma", "kotiinpaluut", 0)
	laavu_conquered = cfg.get_value("peli", "laavu_vallattu", false)
	money = cfg.get_value("peli", "rahat", START_MONEY)
	day = cfg.get_value("peli", "paiva", 1)
	stash_laavu = cfg.get_value("jemma", "laavu", 0)
	jemma_endings = cfg.get_value("jemma", "loput", 0)
	stash_grilli = cfg.get_value("jemma", "grilli", 0)
	tarinat_kuultu = cfg.get_value("kota", "tarinat", [])


func _save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("jemma", "kaljat", jemma)
	cfg.set_value("jemma", "ennatys", jemma_best)
	cfg.set_value("jemma", "kotiinpaluut", jemma_wins)
	cfg.set_value("peli", "laavu_vallattu", laavu_conquered)
	cfg.set_value("peli", "rahat", money)
	cfg.set_value("peli", "paiva", day)
	cfg.set_value("jemma", "laavu", stash_laavu)
	cfg.set_value("jemma", "loput", jemma_endings)
	cfg.set_value("jemma", "grilli", stash_grilli)
	cfg.set_value("kota", "tarinat", tarinat_kuultu)
	cfg.save(SAVE_PATH)


## Isoon kotijemmaan kohdistuu riski: Päivi saattaa löytää sen ja kaataa puolet viemäriin.
## Laavun ja grillikatoksen jemmoista teinit voivat pölliä. Tarkistetaan joka aamu.
func _jemma_check(allow_found := true) -> String:
	var note := ""
	if allow_found and jemma >= JEMMA_WARN + 1 and randf() < clampf((jemma - JEMMA_WARN) * 0.05, 0.1, 0.45):
		var lost := jemma / 2
		jemma -= lost
		_jemma_found = lost
		note += "\nPäivi löysi kotijemman ja kaatoi %d kaljaa viemäriin!" % lost
	for site in [["laavu", 0.35, "laavun halkovajasta"], ["grilli", 0.3, "grillikatokselta"]]:
		var n: int = stash_laavu if site[0] == "laavu" else stash_grilli
		if n > 0 and randf() < site[1]:
			var stolen := clampi(randi_range(n / 2, n), 1, n)
			if site[0] == "laavu":
				stash_laavu -= stolen
			else:
				stash_grilli -= stolen
			note += "\nTeinit pöllivät %s %d kaljaa!" % [site[2], stolen]
	if jemma >= JEMMA_WARN:
		note += "\nVaroitus: kotijemmassa on jo %d kaljaa – Päivi voi löytää sen!" % jemma
	_save_game()
	return note


## Häviö: WASTED-välianimaatio ja Päivin motkotus, sitten uusi päivä lähimmästä turvapaikasta.
func _lose(reason: String, cause := "default") -> void:
	if state == "cutscene":
		return
	state = "cutscene"
	player.controls_enabled = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)  # vasta ruudun lopussa: signaali voi tulla kesken vaaran fysiikkapäivityksen
	_hud.visible = false
	var spawn := _nearest_safe()
	cutscene.wasted(player.global_position, reason, cause, home_zone, func() -> void: _new_day(spawn, true))


## Grafiikan laatu (Settings): varjot, SSAO/SSIL, hehku, ruohon tiheys, lähipuiden etäisyys, FPS-näyttö.
func _apply_settings() -> void:
	var q: int = Settings.get_v("quality")
	_env.ssao_enabled = q >= 1
	_env.ssil_enabled = q >= 2
	_env.glow_enabled = q >= 1
	_sun.directional_shadow_max_distance = [70.0, 120.0, 180.0][q]
	_sun.shadow_blur = [0.5, 1.0, 1.5][q]
	world.set_quality(q)
	_fps_label.visible = Settings.get_v("show_fps")


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
	if walker_out.visible:
		walker_out.visible = false
		walker_out.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		bike.set_rider_visible(true)
	bike.global_position = spawn + Vector3(0, 0.3, 0)
	bike.rotation.y = 0.0
	bike.speed = 0.0
	bike.controls_enabled = true
	_set_avatar(bike)
	beers = 0
	bike.set_carrying(false)
	has_sausage = false
	has_matches = false
	fire_lit = false
	sausage_done = false
	_grill_t = -1.0
	_pick_t = -1.0
	world.fire.visible = false
	if world.kota != null:
		world.kota.set_fire(false)
	var bonus := ""
	if money < START_MONEY:
		bonus = "\nPäivi antoi %s € kauppaan." % _eur(START_MONEY - money) if not lost else "\nTakin taskusta löytyi vähän rahaa."
		money = START_MONEY
	wife_alerted = false
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
	var jnote := _jemma_check()
	if _jemma_found > 0:
		# Päivi löysi jemman: välianimaatio ennen päivän alkua.
		state = "cutscene"
		_hud.visible = false
		bike.controls_enabled = false
		_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		var lost_n := _jemma_found
		var msg := "%sPäivä %d alkaa.%s\nPitäis käydä kaupassa..." % [intro, day, jnote]
		cutscene.jemma_found(home_zone, lost_n, jemma, func() -> void:
			state = "to_shop"
			_hud.visible = true
			bike.controls_enabled = true
			bike.activate_camera()
			_hazards.process_mode = Node.PROCESS_MODE_INHERIT
			_show_message(msg, 6.0))
		return
	_show_message("%sPäivä %d alkaa%s.%s%s\nPitäis käydä kaupassa..." % [intro, day, " laavulta" if spawn.distance_to(home_zone) > 50.0 else " kotoa",
		bonus, jnote], 4.0 if jnote == "" and intro == "" else 6.0)


func _set_outside_visible(v: bool) -> void:
	_arrow.visible = v
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

	_arrow = Node3D.new()
	add_child(_arrow)
	var cone := MeshInstance3D.new()
	cone.mesh = B.cyl(0.0, 0.3, 0.9)
	cone.material_override = B.unshaded(Color(1.0, 0.85, 0.1))
	cone.rotation_degrees.x = -90
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.add_child(cone)


# --- Hahmot ------------------------------------------------------------------

func _spawn_player() -> void:
	player = PlayerBike.new()
	player.position = home_zone + Vector3(0, 0.3, 4)
	add_child(player)
	bike = player
	walker_out = OnFoot.new()
	walker_out.world = world
	add_child(walker_out)
	walker_out.visible = false
	walker_out.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)


## Vaihtaa ohjattavan hahmon (pyörä / jalan) ja päivittää kaikki, jotka seuraavat pelaajaa.
func _set_avatar(a: CharacterBody3D) -> void:
	player = a
	world.follow = a
	for h in [wife, juntti, guard, tractor, arto, pekka]:
		if h != null:
			h.target = a
	_minimap.player = a
	_paper.player = a
	a.activate_camera()


## F: nouse pyörän selästä tai takaisin pyörälle (pyörän vieressä).
func _toggle_mount() -> void:
	if player == bike:
		if absf(bike.speed) > 3.0:
			_show_message("Hidasta ensin!", 1.2)
			return
		bike.speed = 0.0
		bike.controls_enabled = false
		bike.set_rider_visible(false)
		walker_out.global_position = bike.global_position + bike.global_transform.basis.x * 1.1
		walker_out.rotation.y = bike.rotation.y
		walker_out.visible = true
		walker_out.process_mode = Node.PROCESS_MODE_INHERIT
		walker_out.controls_enabled = true
		walker_out.set_carrying(beers > 0)
		_set_avatar(walker_out)
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
	_status = _centered_label(layer, 30, 0.0, 14, 90)
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
	layer.add_child(_minimap)


func _update_hud() -> void:
	var jem := "koti %d/%d" % [jemma, JEMMA_GOAL]
	if stash_laavu > 0:
		jem += " · laavu %d" % stash_laavu
	if stash_grilli > 0:
		jem += " · grilli %d" % stash_grilli
	var lines := "Rahaa: %s €\nKaljat: %d   (jemmat: %s%s)\nAika: %s" % [_eur(money), beers, jem,
		" ⚠" if jemma >= JEMMA_WARN else "", _time(elapsed)]
	if state in ["to_shop", "to_home"]:
		var target := shop_zone if state == "to_shop" else home_zone
		var p := player.global_position
		lines += "\nTavoite: %s  %d m\nAlusta: %s" % [
			"K-Market" if state == "to_shop" else "Koti",
			int(Vector2(p.x, p.z).distance_to(Vector2(target.x, target.z))), world.TERRAIN[player.surface].name]
	_stamina_box.visible = player == walker_out and state in ["to_shop", "to_home"]
	if _stamina_box.visible:
		_stamina_bar.value = walker_out.stamina
		(_stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.9, 0.3, 0.2) if walker_out.exhausted else Color(0.3, 0.8, 0.4)
	var inv: Array[String] = []
	if has_sausage:
		inv.append("makkara (paistettu)" if sausage_done else "makkara")
	if has_matches:
		inv.append("tulitikut")
	if kota_polkyt > 0:
		inv.append("pölkkyjä %d" % kota_polkyt)
	if kota_halot > 0:
		inv.append("halkoja %d" % kota_halot)
	if not inv.is_empty():
		lines += "\nMukana: " + ", ".join(inv)
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
		"carry":
			laavu_conquered = true
			guard.vanish()
			_toggle_mount()
			walker_out.global_position = M.w(M.LAAVU) + Vector3(3.8, 0.3, 1.4)
			bike.global_position = walker_out.global_position + Vector3(1.0, 0, 0)
			stash_laavu = 15
			for i in 20:
				await get_tree().process_frame
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
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
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
