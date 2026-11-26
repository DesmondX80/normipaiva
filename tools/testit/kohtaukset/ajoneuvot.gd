extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "ajoneuvot". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const B := preload("res://scripts/build.gd")
const Pose := preload("res://scripts/pose.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const BarGame := preload("res://scripts/bar_game.gd")
const TrafficCar := preload("res://scripts/traffic_car.gd")
const Looks := preload("res://scripts/looks.gd")
const OnFoot := preload("res://scripts/on_foot.gd")
const HomeInterior := preload("res://scripts/home_interior.gd")
const GarageInterior := preload("res://scripts/garage_interior.gd")
const CarbGame := preload("res://scripts/carb_game.gd")
const EBike := preload("res://scripts/ebike.gd")
const EBikeGame := preload("res://scripts/ebike_game.gd")
const OmaMopo := preload("res://scripts/oma_mopo.gd")
const MopoKickGame := preload("res://scripts/mopo_kick_game.gd")
const Quests := preload("res://scripts/quests.gd")

const KOHTAUKSET := ["taxistand", "taxitest", "bikeside", "tractor", "autovarkaus_kahdesti", "sahkopyora", "autotalli", "juoksutaksi", "juoksutappelu", "junan_alle", "tractortest", "cars", "tractorside", "tractorfront", "tractortop", "tractorclose", "carbump", "bikestay", "bikeload", "carry", "drooni", "pyoravaras", "junavaunu", "junavaunu_saloinen"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"taxistand":
			if main.player != main.walker_out:
				main._toggle_mount()
			var shop_c := M.w(M.SHOP_BUILDING)
			print("STAND kauppa=", shop_c, " kauppavyöhyke=", main.shop_zone - shop_c, " taksi=", main.world.taxi_pos - shop_c)
			main.walker_out.global_position = main.world.taxi_pos + Vector3(8.0, 0.5, -6.0)
			main.walker_out.rotation.y = B.yaw_to(main.world.taxi_pos - main.walker_out.global_position)
		"taxitest":
			# Taksi Raaheen: vihje, menomatka, kädenvääntö (A/D-tahti), paluu ja uusi päivä. Kuvat --shot-kansioon,
			# tallennus palautetaan lopuksi.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var shot := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.get_base_dir().path_join("taxi_%s.png" % name))
			if main.player != main.walker_out:
				main._toggle_mount()
			main.money = 30.0
			main.clock_min = 17 * 60  # baari auki 14–02: aamulla taksi ei vie suljettuun baariin
			main.walker_out.global_position = main.world.taxi_pos + Vector3(2.2, 0.5, 1.0)
			main.walker_out.rotation.y = -PI * 0.5
			for i in 30:
				await main.get_tree().physics_frame
			await shot.call("parkki")
			print("TAXI hint=", main._hint.text)
			await main.get_tree().process_frame  # kuvakaappauksen jälkeen: painallus seuraavan ruudun alkuun
			Input.action_press("interact")
			for w in 2:
				await main.get_tree().process_frame
			Input.action_release("interact")
			print("TAXI ikkuna: %s" % str(main._talk_box._options.map(func(o): return o.text)))
			main._test_talk(["raahe"])
			print("TAXI state=", main.state, " money=", main.money)
			await main.get_tree().create_timer(5.0, true, false, true).timeout
			await shot.call("meno")
			for i in 60:
				await main.get_tree().create_timer(0.5, true, false, true).timeout
				if main.state == "in_raahe":
					break
			print("TAXI perillä state=%s msg=%s" % [main.state, main._msg.text])
			var press := func() -> void:
				await main.get_tree().process_frame
				Input.action_press("interact")
				for w in 2:
					await main.get_tree().process_frame
				Input.action_release("interact")
				for w in 3:
					await main.get_tree().process_frame
			main.raahe_int.walker.position = Vector3(0.0, 0, 1.5)
			await main.get_tree().create_timer(1.0, true, false, true).timeout
			await shot.call("kulma")
			# Visa: kolme kysymystä, vastataan aina ensimmäiseen vaihtoehtoon.
			main.raahe_int.walker.position = main.raahe_int.spots.visa[0]
			for w in 3:
				await main.get_tree().process_frame
			print("TAXI visa hint=", main.raahe_int.hint)
			await press.call()
			print("TAXI visa ikkuna=%s '%s'" % [main._talk_box.is_open(), main._talk_box._line.replace("\n", " | ")])
			for qn in 3:
				print("TAXI visa kysymys: ", main._quiz[main._quiz_i][0], " ", main._quiz[main._quiz_i][1])
				main._talk_choose("visa_0")
				print("TAXI visa vastaus: '%s' info '%s'" % [main._talk_box._line.replace("\n", " | "), main._talk_box._info])
				for w in 3:
					await main.get_tree().process_frame
			print("TAXI visa tulos=%d valinnat=%s" % [main._raahe.quiz, str(main._talk_box._options.map(func(o): return o.id))])
			main._talk_box.close()
			main.raahe_int.walker.position = main.raahe_int.spots.tiski[0] if main.raahe_int.spots.has("tiski") else main.raahe_int.walker.position
			main._on_raahe_acted("tiski")
			print("TAXI tiski: ikkuna %s valinnat %s" % [main._talk_box.is_open(), str(main._talk_box._options.map(func(o): return o.text))])
			main._test_talk(["juo_tuoppi"])
			print("TAXI tuoppi: rahaa %.2f ohjaus %s" % [main.money, main.raahe_int.walker.controls_enabled])
			# Kädenvääntö Teron kanssa.
			main.raahe_int.walker.position = main.raahe_int.spots.tero[0]
			for w in 3:
				await main.get_tree().process_frame
			print("TAXI tero hint=", main.raahe_int.hint)
			await press.call()
			var bar: Node = null
			for c in main.get_children():
				if c is BarGame:
					bar = c
			if bar == null:
				print("TAXI baaria ei löytynyt")
				main.get_tree().quit()
				return 2
			await main.get_tree().create_timer(1.5, true, false, true).timeout
			await shot.call("baari")
			await main.get_tree().process_frame
			Input.action_press("interact")
			for w in 2:
				await main.get_tree().process_frame
			Input.action_release("interact")
			# Laskenta ennen vääntöä: odotetaan vaihetta eikä kiinteää aikaa (hitaalla koneella 3,3 s ei riitä).
			for w in 3000:
				if bar._phase not in ["", "intro", "count"]:
					break
				await main.get_tree().process_frame
			var key := "left"
			var n := 0
			var pace := 0.07  # s painallusten välissä (lisäksi 3 ruutua); --pace=0.3 kokeilee hidasta tahtia
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--pace="):
					pace = float(arg.substr(7))
			while bar._phase == "wrestle":
				await main.get_tree().process_frame  # painallus ruudun alkuun, ei ajastimen jälkeen
				Input.action_press(key)
				for w in 2:
					await main.get_tree().process_frame
				Input.action_release(key)
				key = "right" if key == "left" else "left"
				await main.get_tree().create_timer(pace, true, false, true).timeout
				n += 1
				if n == 12:
					await shot.call("vaanto")
					await main.get_tree().process_frame
			print("TAXI vääntö: kulma=%.2f painalluksia=%d" % [bar._angle, n])
			await main.get_tree().create_timer(4.0, true, false, true).timeout
			print("TAXI väännön jälkeen: won=%s msg=%s" % [main._raahe.won, main._msg.text])
			# Kellariin portaita ja kuva karaokesta.
			main.raahe_int.walker.position = main.raahe_int.spots.alas[0]
			for w in 3:
				await main.get_tree().process_frame
			await press.call()
			print("TAXI kellarissa: %s" % main.raahe_int.in_cellar())
			main.raahe_int.walker.position = main.raahe_int.spots.karaoke[0] + Vector3(1.5, 0, -0.5)
			await main.get_tree().create_timer(1.0, true, false, true).timeout
			await shot.call("kellari")
			# Ylös ja ulos.
			main.raahe_int.walker.position = main.raahe_int.spots.ylos[0]
			for w in 3:
				await main.get_tree().process_frame
			await press.call()
			main.raahe_int.walker.position = main.raahe_int.spots.ovi[0]
			for w in 3:
				await main.get_tree().process_frame
			print("TAXI ovi hint=", main.raahe_int.hint)
			await press.call()
			await main.get_tree().create_timer(4.5, true, false, true).timeout
			await main.get_tree().create_timer(4.0, true, false, true).timeout
			await shot.call("paluu")
			for i in 80:
				await main.get_tree().create_timer(0.5, true, false, true).timeout
				if i == 6:
					await shot.call("koti")
				if main.state != "cutscene":
					break
			print("TAXI after state=%s money=%.2f mielihyva=%d maine=%d msg=%s" % [main.state, main.money, main.mielihyva, main.maine,
				main._msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"bikeside":
			var cam := Camera3D.new()
			cam.fov = 35.0
			main.player.add_child(cam)
			cam.position = Vector3(3.2, 1.1, 0.1)
			cam.look_at_from_position(main.player.global_position + Vector3(3.2, 1.1, 0.1), main.player.global_position + Vector3(0, 0.9, 0), Vector3.UP)
			cam.current = true
			main.player.speed = 3.0
		"tractor":
			main.player.position = M.w(Vector2(304, 735)) + Vector3(0, 0.3, 0)
			main.player.rotation.y = PI / 2.0
		"autovarkaus_kahdesti":
			# Auton kaappaus useasti peräkkäin oikealla ajolla (headless); rikos/autovarkaus.gd testi_kahdesti.
			await main.rikos_osa("autovarkaus").testi_kahdesti(3)
			main.get_tree().quit()
		"sahkopyora":
			# Sähköpyörä (#107): tarvikkeet kaupasta, idea ja kasaus työpöydällä (kuvat vaiheista), ajo avustuksella
			# ja ilman, akku irtoaa juurakoissa, tienvarsikorjaus teipillä ja oikosulku vedessä. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.ebike = EBike.new()
			if main.player == main.bike:
				main._toggle_mount()
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			var frames := func(n: int) -> void:
				for i in n:
					await main.get_tree().physics_frame
			var snap := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main._ebike_cart({"teippi": 4.9, "nippu": 2.5, "sahkoteippi": 2.2})
			print("SP kauppa: tarvikkeet %s, aloitettu %s" % [main.ebike.supplies, main.ebike.started])
			main.bucket["kantarelli"] = 2
			main.beers = 1
			var po: Array = main._talk_options("pekka").map(func(o): return o.id)
			var ao: Array = main._talk_options("arto").map(func(o): return o.id)
			print("SP naapurit: pekka akku %s, arto johdot %s" % ["akku" in po, "johdot" in ao])
			main.ebike.started = false
			# Pyörä talliin.
			main.bike.global_position = main.world.garage_door + main.world.garage_out * 2.5 + Vector3(0, 0.4, 0)
			main.walker_out.global_position = main.bike.global_position + Vector3(1.0, 0, 0)
			main.beers = 0
			await frames.call(5)
			main._toggle_mount()
			main.bike.global_position = main.world.garage_door + main.world.garage_out * 0.5 + Vector3(0, 0.4, 0)
			# Aloituksen päivälappu ja avoin puhe (Päivi) syövät muuten E:n (SP talliin: tallissa false, kasaus kaatui).
			main._note.visible = false
			if main._talk_box.is_open():
				main._talk_box.close()
			await frames.call(10)
			await press.call("interact")
			print("SP talliin: tila %s, tallissa %s" % [main.state, main.bike_in_garage])
			main.garage_int.walker.position = GarageInterior.SPOTS.tyopoyta[0]
			await frames.call(5)
			await press.call("interact")
			print("SP idea + huolto: aloitettu %s, tune %.2f, tarvikkeet %s, viesti '%s'" % [main.ebike.started, main.bike.tune, main.ebike.supplies, main._msg.text])
			await press.call("interact")
			print("SP osat puuttuu: viesti '%s'" % main._msg.text)
			for k in EBike.PARTS:
				main.ebike.parts[k] = true
			main.ebike.supplies.rautalanka = 1
			await press.call("interact")
			var g: Node = main.get_children().filter(func(c): return c is EBikeGame).front()
			print("SP kasaus auki: %s, liitokset %s" % [g != null, g.todo if g != null else []])
			await main.get_tree().create_timer(0.5).timeout
			await snap.call("_valinta.png")
			var plan := {"moottori": "ruuvi", "akku": "teippi", "ohjain": "nippu", "kaasu": "rautalanka", "johdot": "teippi"}
			for j in main.ebike.JOINTS:
				g._choose(plan[j])
				if j in ["moottori", "akku", "ohjain"]:
					g._progress = 0.4
					g._threaded = true
					g._tension = 0.75
					await main.get_tree().create_timer(0.3).timeout
					await snap.call("_%s.png" % plan[j])
				g._joint_done()
				await frames.call(2)
			await main.get_tree().create_timer(1.5).timeout
			print("SP kasattu: valmis %s, liitokset %s, tarvikkeet %s, viesti '%s'" % [main.ebike.built(), main.ebike.joints, main.ebike.supplies, main._msg.text])
			main.garage_int.walker.position = GarageInterior.SPOTS.pyora[0]
			await frames.call(5)
			await press.call("interact")
			print("SP ulos pyörällä: selässä %s" % [main.player == main.bike])
			await frames.call(20)
			var sc := Camera3D.new()
			main.add_child(sc)
			var bp := main.bike.global_position
			var side := main.bike.global_transform.basis.x
			sc.look_at_from_position(bp + side * 2.4 + Vector3(0, 1.1, 0.3), bp + Vector3(0, 0.7, 0))
			sc.current = true
			main._hud.visible = false
			await frames.call(10)
			await snap.call("_sivu.png")
			sc.queue_free()
			main._hud.visible = true
			main.bike.activate_camera()
			# Ajo suoralla asfaltilla: avustuksella ja ilman.
			var road := M.w(Vector2(829, 1240))
			# Mittauksen ajaksi ruuvikiinnitykset: teipattu akku voi irrota jo parin sekunnin ajossa, jolloin
			# "avustettu" mittaus mittaisikin raskasta pyörää. Oikeat kiinnitykset palautetaan mittauksen jälkeen.
			var joints0: Dictionary = main.ebike.joints.duplicate()
			for j in main.ebike.joints:
				main.ebike.joints[j] = "ruuvi"
			var top := func(battery: float) -> float:
				main.ebike.battery = battery
				main.ebike.loose.clear()
				main.bike.global_position = road + Vector3(0, 0.4, 0)
				main.bike.rotation.y = B.yaw_to(M.w(Vector2(844, 1300)) - road)
				main.bike.speed = 0.0
				Input.action_press("forward")
				await frames.call(240)
				Input.action_release("forward")
				var v: float = main.bike.speed
				main.bike.speed = 0.0
				return v
			var v_on: float = await top.call(1.0)
			var akku_after: float = main.ebike.battery
			var v_off: float = await top.call(0.0)
			print("SP huippu: avustus %.1f km/h (akku %.3f), tyhjä akku %.1f km/h, raskas %s" % [v_on * 3.6, akku_after, v_off * 3.6, main.bike.heavy])
			main.ebike.joints = joints0
			main.ebike.loose.clear()
			main.ebike.battery = 1.0
			# Juurakot irrottavat teipatun akun.
			main.bike.speed = 8.0
			# Yksi juurakko per prosessiruutu: ebike.gd lukee osumat kerran ruudussa, ja hitaalla koneella monta fysiikkaruutua
			# osui samaan ruutuun (60 osumaa = muutama arvonta, akku jäi kiinni).
			for i in 60:
				main.bike.root_hits += 1
				await main.get_tree().process_frame
				if not main.ebike.loose.is_empty():
					break
			print("SP irtoaminen: irti %s, avustus %.1f, viesti '%s'" % [main.ebike.loose.keys(), main.bike.assist, main._msg.text])
			if main.ebike.loose.is_empty():
				print("TESTI VIKA sahkopyora: 60 juurakkoa ei irrottanut teipattua osaa")
			main.bike.speed = 0.0
			await frames.call(20)
			main.bike.global_position = road + Vector3(0, 0.4, 0)
			main.bike.rotation.y = PI * 0.6
			await frames.call(30)
			await snap.call("_irti.png")
			main._toggle_mount()
			main.walker_out.global_position = main.bike.global_position + Vector3(1.2, 0.3, 0)
			await frames.call(5)
			print("SP korjausvihje: '%s'" % main._hint.text)
			await press.call("interact")
			print("SP teipattu: irti %s, teippiä %d, toimii %s" % [main.ebike.loose.keys(), main.ebike.supplies.teippi, main.ebike.working()])
			main._toggle_mount()
			# Oikosulku vedessä (johdot jeesusteipillä).
			main.bike.surface = "water"
			main.bike.speed = 3.0
			var m: String = main.ebike.ride_tick(main.bike, 0.016)
			main.bike.speed = 0.0
			print("SP oikosulku: %s, viesti '%s', todo %s" % [main.ebike.shorted, m, main.ebike.todo()])
			await frames.call(30)
			await snap.call("_hud.png")
			print("SP tehtävät: %s" % [main.ebike.tasks()])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"autotalli":
			# Autotalli: sisään kaljat kädessä, työkalukaappiin, radio, arkku, karburaattori (kuva + pakotettu
			# onnistuminen), ulos; pyörä talliin, huolto ja ulos pyörällä; eteisen kaappi kodin sisällä.
			if main.player == main.bike:
				main._toggle_mount()
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			var frames := func(n: int) -> void:
				for i in n:
					await main.get_tree().physics_frame
			var gstash: int = main.stash.get("autotalli", 0)
			main.beers = 3
			main.walker_out.global_position = main.world.garage_door + main.world.garage_out * 0.4 + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("TALLI ovella: hint '%s'" % main._hint.text)
			await press.call("interact")
			print("TALLI sisään: tila %s" % main.state)
			main.garage_int.walker.position = GarageInterior.SPOTS.kaappi[0]
			await frames.call(5)
			print("TALLI kaappi: hint '%s'" % main._hint.text)
			await press.call("interact")
			await press.call("interact")
			print("TALLI kaappiin: jemma %d -> %d, kaljat %d" % [gstash, main.stash.get("autotalli", 0), main.beers])
			main.garage_int.walker.position = GarageInterior.SPOTS.radio[0]
			await frames.call(5)
			await press.call("interact")
			print("TALLI radio: päällä %s, viesti '%s'" % [main.garage_int.radio_on, main._msg.text])
			main.garage_int.walker.position = GarageInterior.SPOTS.arkku[0]
			await frames.call(5)
			await press.call("interact")
			main.garage_int.walker.position = Vector3(0.6, 0, 3.0)
			await frames.call(10)
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_talli.png"))
			main.garage_int.walker.position = GarageInterior.SPOTS.auto[0]
			await frames.call(5)
			await press.call("interact")
			var cg: Node = main.get_children().filter(func(c): return c is CarbGame).front()
			print("TALLI karburaattori auki: %s" % [cg != null])
			await main.get_tree().create_timer(1.5).timeout
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_karbu.png"))
			if cg != null:
				cg._mix_ok = cg._mix
				cg._idle_ok = cg._idle
				await main.get_tree().create_timer(4.0).timeout
			print("TALLI karburaattori: peli ohi %s, viesti '%s'" % [not is_instance_valid(cg), main._msg.text])
			main.garage_int.walker.position = GarageInterior.SPOTS.ovi[0]
			await frames.call(5)
			await press.call("interact")
			print("TALLI ulos: tila %s, etäisyys ovesta %.1f m" % [main.state, main.walker_out.global_position.distance_to(main.world.garage_door)])
			# Pyörä talliin ja ulos.
			main.bike.global_position = main.world.garage_door + main.world.garage_out * 2.5 + Vector3(0, 0.4, 0)
			main.walker_out.global_position = main.bike.global_position + Vector3(1.0, 0, 0)
			main.beers = 0
			await frames.call(5)
			main._toggle_mount()
			main.bike.global_position = main.world.garage_door + main.world.garage_out * 0.5 + Vector3(0, 0.4, 0)
			await frames.call(10)
			print("TALLI pyörällä ovella: hint '%s'" % main._hint.text)
			await press.call("interact")
			print("TALLI pyörä talliin: tila %s, tallissa %s, näkyy %s" % [main.state, main.bike_in_garage, main.bike.visible])
			main.garage_int.walker.position = GarageInterior.SPOTS.tyopoyta[0]
			await frames.call(5)
			await press.call("interact")
			print("TALLI huolto: tune %.2f viesti '%s'" % [main.bike.tune, main._msg.text])
			main.garage_int.walker.position = GarageInterior.SPOTS.pyora[0]
			await frames.call(5)
			print("TALLI pyörän luona: hint '%s'" % main._hint.text)
			await press.call("interact")
			print("TALLI ulos pyörällä: tila %s, pyörän selässä %s, tallissa %s" % [main.state, main.player == main.bike, main.bike_in_garage])
			# Eteisen kaappi sisällä.
			main._toggle_mount()
			main.beers = 2
			var hstash: int = main.stash.get("koti", 0)
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("ETEINEN ovella: hint '%s'" % main._hint.text)
			await press.call("interact")
			print("ETEINEN sisään: tila %s, kantaa %s" % [main.state, main.home_int.carrying])
			main.home_int.walker.position = Vector3(1.5, 0, -2.5)
			await frames.call(5)
			print("ETEINEN keittiöön kaljoineen: paikka %s hint '%s'" % [main.home_int.walker.position, main._hint.text])
			main.home_int.walker.position = HomeInterior.SPOTS.kaappi[0]
			await frames.call(5)
			print("ETEINEN kaapilla: hint '%s'" % main._hint.text)
			await press.call("interact")
			await press.call("interact")
			main.home_int.walker.position = Vector3(1.5, 0, -2.5)
			await frames.call(5)
			print("ETEINEN kaappiin: jemma %d -> %d, kaljat %d, keittiöön pääsi %s" % [hstash, main.stash.get("koti", 0), main.beers,
				main.home_int.walker.position.distance_to(Vector3(1.5, 0, -2.5)) < 0.5])
		"juoksutaksi", "juoksutappelu":
			# Juoksukaljat Saloisissa: kauppias perään. Taksi: juokse suoraan taksille (5,4 m/s). Tappelu: jää
			# paikalleen, kung fu -torjunta ja vastaisku, tölkki tehoaa, ja voitto ja tappio.
			main._toggle_mount()
			main.walker_out.global_position = main.shop_door + Vector3(0, 0.3, 0.5)
			for i in 5:
				await main.get_tree().physics_frame
			main._enter_shop()
			main.interior.has_beer = true
			main.interior.has_paid = true
			main.interior.stolen = true
			main._on_shop_exited(true)
			await main.get_tree().process_frame
			print("JUOKSU alku: kaljat %d, kauppias %s, etumatka %.1f s, viesti '%s'" % [main.beers, main._chasing(),
				main._shop_chaser.delay, main._msg.text.replace("\n", " ")])
			if scene == "juoksutaksi":
				var t0 := Time.get_ticks_msec()
				main.walker_out.controls_enabled = false
				while main._chasing():
					var tp: Vector3 = main.world.taxi_pos
					var to := Vector3(tp.x - main.walker_out.global_position.x, 0, tp.z - main.walker_out.global_position.z)
					if to.length() < Main.TAXI_RADIUS - 0.5:
						break
					main.walker_out.global_position += to.normalized() * OnFoot.RUN / 60.0
					await main.get_tree().physics_frame
				main.walker_out.controls_enabled = true
				var cd: float = main.walker_out.global_position.distance_to(main._shop_chaser.global_position) if main._chasing() else -1.0
				print("JUOKSU taksilla: kauppias jahtaa %s, välimatka %.1f m, hint '%s'" % [main._chasing(), cd, main._hint.text])
				for i in 2:
					await main.get_tree().process_frame
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
				print("JUOKSU taksiin: tila %s, rahat %.2f" % [main.state, main.money])
			else:
				for i in 400:
					await main.get_tree().physics_frame
					if main.state == "fight":
						break
				print("JUOKSU kiinni: tila %s, vastustaja %s" % [main.state, main.fight.foe.get("short", "")])
				while main.fight._phase != "fight":
					await main.get_tree().process_frame
				var j: Node3D = main.fight._j
				var hp0: float = j.hp
				var bl: bool = j.take_hit(12.0, -1.0, 2.0)
				await main.get_tree().process_frame
				print("JUOKSU lyönti: torjuttu %s, hp %.0f -> %.0f, asento %s, torjunta %.2f s, vastaisku tulossa %s" % [bl,
					hp0, j.hp, j.state, j.parry_t, j.counter_pending])
				var seen := ""
				for i in 90:
					await main.get_tree().process_frame
					if j.state == "attack" and seen == "":
						seen = j._attack
				print("JUOKSU vastaisku: %s, huuto '%s'" % [seen, main.fight._bubble_j.text])
				bl = j.take_hit(26.0, -1.0, 5.5, 6.0, 0.9, true)
				print("JUOKSU tölkki: torjuttu %s, hp -> %.0f" % [bl, j.hp])
				j.take_hit(999.0, -1.0, 5.5, 6.0, 0.9, true)
				while main.state == "fight":
					await main.get_tree().process_frame
				print("JUOKSU voitto: tila %s, kaljat %d, viesti '%s'" % [main.state, main.beers, main._msg.text.replace("\n", " ")])
		"junan_alle":
			# Häviö junan alle Saloisten radalla: pelaaja seisoo kiskoilla, juna ajaa päälle (oikea hits-osuma),
			# sitten WASTED ja Päivin motkotus. Kuvat _0..._N 0,4 s välein ajosta osumaan asti, _wasted ja _paivi.
			var saved_ja := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			if main.player != main.walker_out:
				main._toggle_mount()
			main._note.visible = false
			var tr_ja: Node3D = main.world.train
			tr_ja.spawn_now(false, 1)
			var t_ja: float = main.world.station_t - 130.0  # kiskoilla ennen laituria, jossa maa on olemassa (radan alkupää on kartan ulkopuolella)
			tr_ja._s = t_ja - 140.0  # veturin keula 140 m hahmon takana
			var spot: Vector3 = tr_ja.to_global(tr_ja.point_t(t_ja))  # point_t/dir_t ovat junan paikallisia
			var rd: Vector3 = tr_ja.global_transform.basis * tr_ja.dir_t(t_ja)
			main.walker_out.global_position = spot + Vector3(0, 0.6, 0)
			main.walker_out.rotation.y = atan2(rd.x, rd.z)  # -Z = etu: katse junaa (tulee radan alkupäästä) kohti
			for i in 20:
				await main.get_tree().physics_frame
			var n_ja := 0
			while main.state != "cutscene" and n_ja < 40:
				await main.get_tree().create_timer(0.4, true, false, true).timeout
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%d.png" % n_ja))
				n_ja += 1
			print("JUNAN_ALLE osuma state=", main.state, " kuvia ", n_ja)
			await main.get_tree().create_timer(2.5, true, false, true).timeout
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_wasted.png"))
			await main.get_tree().create_timer(4.5, true, false, true).timeout
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_paivi.png"))
			for i in 60:
				await main.get_tree().create_timer(0.5, true, false, true).timeout
				if main.state != "cutscene":
					break
			if not saved_ja.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_ja)
		"tractortest":
			# Onnistunut kotiinpaluu ja sen jälkeen pellolle: jemmarin pitää hyökätä.
			main.state = "ulkona"
			main._kuutonen_day = main.day
			main.beers = 0
			main.jemma = 6
			main._win()
			for i in 5:
				await main.get_tree().physics_frame
			print("AFTER WIN hazards process_mode=", main._hazards.process_mode, " state=", main.state)
			main.player.position = M.w(Vector2(304, 735)) + Vector3(0, 0.3, 0)
			var hit := -1
			for i in 600:
				await main.get_tree().physics_frame
				if main.state == "fight":
					hit = i
					break
			print("TRACTOR after win: fight at frame ", hit, " mode=", main.tractor.mode)
		"cars":
			var cam := Camera3D.new()
			cam.fov = 45.0
			main.add_child(cam)
			var hb3 := M.w(M.HOME_BUILDING)
			cam.look_at_from_position(hb3 + Vector3(-20, 1.6, -7), hb3 + Vector3(-14, 0.8, 0), Vector3.UP)
			cam.current = true
			main._msg.text = ""
		"tractorside", "tractorfront", "tractortop":
			main.player.position = M.w(Vector2(304, 735)) + Vector3(0, 0.3, 0)
			var cam3 := Camera3D.new()
			cam3.fov = 40.0
			main.add_child(cam3)
			main.tractor.set_physics_process(false)
			var tb := main.tractor.global_transform.basis
			var tp3 := main.tractor.global_position + tb * Vector3(0, 1.9, 0.75)
			var off: Vector3 = {"tractorside": tb * Vector3(6.0, 0.2, 0), "tractorfront": tb * Vector3(0, 0.4, -6.5),
				"tractortop": tb * Vector3(0.01, 6.0, 0.3)}[scene]
			cam3.look_at_from_position(tp3 + off, tp3, Vector3.UP if scene != "tractortop" else -tb.z)
			cam3.current = true
			main._msg.text = ""
		"tractorclose":
			main.player.position = M.w(Vector2(304, 735)) + Vector3(0, 0.3, 0)
			main.player.rotation.y = PI / 2.0
			var cam2 := Camera3D.new()
			cam2.fov = 45.0
			main.add_child(cam2)
			var tp2 := main.tractor.global_position
			cam2.look_at_from_position(tp2 + Vector3(-5.5, 2.0, -4.0), tp2 + Vector3(0, 1.3, 0), Vector3.UP)
			cam2.current = true
			main.tractor.set_physics_process(false)
			main._msg.text = ""
		"carbump":
			# Hiljaa tuleva auto tönäisee (ei hit-signaalia), lujaa tuleva tappaa (hit-signaali).
			main._toggle_mount()
			for i in 10:
				await main.get_tree().physics_frame
			for c in [[5.0, 3.5], [16.0, 4.0]]:
				var hits := [0]
				var stunned := false
				var car := TrafficCar.new()
				car.cruise = c[0]
				car.lane = 0.0
				car.target_fn = func() -> Node3D: return main.walker_out
				car.hit.connect(func() -> void: hits[0] += 1)
				main.add_child(car)
				var wp := main.walker_out.global_position
				var pts := []
				for k in 41:
					var x := wp.x - 40.0 + k * 2.0
					pts.append(Vector3(x, Terrain.h(x, wp.z), wp.z))
				car.setup_line(pts, (40.0 - c[1]) / 2.0, 1)
				for i in 90:
					await main.get_tree().physics_frame
					stunned = stunned or main.walker_out.is_stunned()
				print("CARBUMP cruise=", c[0], " hits=", hits[0], " stunned=", stunned)
				car.queue_free()
				for i in 120:
					await main.get_tree().physics_frame
				main.walker_out.global_position = wp
		"bikestay":
			# Pyörä kaupalle, uusi päivä kotoa: pyörän pitää jäädä, pelaaja jalan. Sitten tallennus.
			var left := main.shop_zone + Vector3(6, 0.3, 6)
			main.bike.global_position = left
			main._new_day(main.home_zone + Vector3(0, 0, 4), false)
			for i in 30:
				await main.get_tree().physics_frame
			print("BIKESTAY on_foot=", main.player == main.walker_out, " bike_moved=%.2f" % main.bike.global_position.distance_to(left),
				" walker_home=%.1f" % main.walker_out.global_position.distance_to(main.home_zone), " msg=", main._msg.text.replace("\n", " | "))
			main._save_game()
		"bikeload":
			print("BIKELOAD saved=", main._bike_saved, " note=", main._apply_saved_bike().strip_edges(), " on_foot=", main.player == main.walker_out,
				" bike_at_shop=%.1f" % main.bike.global_position.distance_to(main.shop_zone))
		"carry":
			main.laavu_conquered = true
			main.guard.vanish()
			main._toggle_mount()
			main.walker_out.global_position = M.w(M.LAAVU) + Vector3(3.8, 0.3, 1.4)
			main.bike.global_position = main.walker_out.global_position + Vector3(1.0, 0, 0)
			main.stash_laavu = 15
			for i in 20:
				await main.get_tree().process_frame
			Input.action_press("bell")
			await main.get_tree().process_frame
			Input.action_release("bell")
			await main.get_tree().process_frame
			print("CARRY took beers=", main.beers, " laavu=", main.stash_laavu)
			Input.action_press("mount")
			await main.get_tree().process_frame
			Input.action_release("mount")
			await main.get_tree().process_frame
			print("CARRY on_bike=", main.player == main.bike, " hint=", main._hint.text, " msg=", main._msg.text)
		"drooni":
			# Drooni: alustan vihje, nousu, lento, kuvat kotitalosta ja K-Marketista, paluu kotiin (H) ja laskeutuminen.
			# Kuvat _pad, _fpv, _chase. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(suffix: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", suffix))
			var key := func(k: Key) -> void:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				ev.pressed = true
				Input.parse_input_event(ev)
				await main.get_tree().process_frame
				ev = ev.duplicate()
				ev.pressed = false
				Input.parse_input_event(ev)
				await main.get_tree().process_frame
			main.drone_photos.clear()
			main._toggle_mount()
			var pad: Vector3 = main.world.drone_pad_pos
			print("DROONI pad->home_zone %.1f m" % Vector2(pad.x - main.home_zone.x, pad.z - main.home_zone.z).length())
			main.walker_out.global_position = pad + Vector3(1.2, Terrain.h(pad.x, pad.z) + 0.3, 0.6)
			main.walker_out.rotation.y = B.yaw_to(pad - main.walker_out.global_position)
			for i in 20:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("DROONI hint=", main._hint.text)
			await snap.call("_pad.png")
			var top := Camera3D.new()
			main.add_child(top)
			top.global_position = pad + Vector3(0, 28, 0.01)
			top.look_at(pad, Vector3.UP)
			top.current = true
			for i in 3:
				await main.get_tree().process_frame
			await snap.call("_padtop.png")
			top.queue_free()
			main.walker_out.activate_camera()
			await main.get_tree().process_frame  # kuvakaappauksen jälkeen: painallus seuraavan ruudun alkuun
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			print("DROONI state=", main.state, " drone=", main._drone != null)
			var dg: Node3D = main._drone
			Input.action_press("jump")
			for i in 150:
				await main.get_tree().physics_frame
			Input.action_release("jump")
			print("DROONI nousu: kork %.1f m landed=%s" % [dg.body.global_position.y - dg._home_ground, dg._landed])
			Input.action_press("forward")
			for i in 180:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			print("DROONI eteen: kotiin %.1f m nopeus %.1f" % [dg._home_dist(), dg._vel.length()])
			await snap.call("_fpv.png")
			# Kuva kotitalosta: käännytään taloa kohti ja kamera alas.
			var hb := M.w(M.HOME_BUILDING)
			var to: Vector3 = hb - dg.body.global_position
			dg._yaw = atan2(-to.x, -to.z)
			dg._gimbal = -atan2(dg.body.global_position.y - hb.y, Vector2(to.x, to.z).length())
			for i in 5:
				await main.get_tree().physics_frame
			await dg.take_photo()
			print("DROONI kuva koti: photos=", main.drone_photos, " msg=", dg._warn.text)
			# Pontikkapannun yläpuolelle (siirretään suoraan) ja kuva alas.
			var pk := M.w(M.PONTIKKA)
			dg.body.global_position = pk + Vector3(0, 60, 30)
			dg._yaw = 0.0
			dg._gimbal = -atan2(60.0, 30.0)
			for i in 30:
				await main.get_tree().physics_frame
			await dg.take_photo()
			print("DROONI kuva pontikka: photos=", main.drone_photos, " found=", main.pontikka_found)
			await snap.call("_pontikka.png")
			CamCtl.fps = false
			dg.body.global_position = main.world.drone_pad_pos + Vector3(40, 30, 20)
			for i in 40:
				await main.get_tree().physics_frame
			await snap.call("_chase.png")
			await key.call(KEY_H)
			print("DROONI H mode=", dg._mode)
			for i in 60 * 25:
				await main.get_tree().physics_frame
				if main._drone == null:
					break
			print("DROONI loppu: state=%s drone=%s akku=%.2f msg=%s" % [main.state, main._drone != null, main.drone_battery, main._msg.text])
			# Törmäys: uusi lento ja isku seinään.
			main.drone_battery = 1.0
			main.walker_out.global_position = pad + Vector3(1.2, Terrain.h(pad.x, pad.z) + 0.3, 0.6)
			for i in 5:
				await main.get_tree().physics_frame
			main._start_drone()
			await main.get_tree().process_frame
			dg = main._drone
			dg._landed = false
			dg.body.global_position = hb + Vector3(-20, 3, 0)
			dg._vel = Vector3(18, 0, 0)
			dg._yaw = -PI / 2.0
			Input.action_press("forward")
			for i in 60 * 5:
				await main.get_tree().physics_frame
				if main._drone == null:
					break
			Input.action_release("forward")
			print("DROONI törmäys: broken=%s msg=%s" % [main.drone_broken_day == main.day, main._msg.text])
			await main.get_tree().process_frame
			print("DROONI hint rikki=", main._hint.text)
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"pyoravaras":
			# Pyörävaras: pyörä 400 m päähän, varkaus käyntiin; seurataan teinin lähestymistä ja ajelua 100 m:n
			# sisällä, kuva, sitten pelaaja kävelee pyörän luo (kiinni). --hylkaa: lyhyt ajelu ja hylkäys.
			main._toggle_mount()
			var far := main.walker_out.global_position + Vector3(300, 0, 250)
			var nid: int = main.world.ride.get_closest_point(Vector3(far.x, 0, far.z))
			var np: Vector3 = main.world.ride.get_point_position(nid)
			main.bike.global_position = Vector3(np.x, Terrain.h(np.x, np.z) + 0.4, np.z)
			for i in 10:
				await main.get_tree().physics_frame
			main._thief_start()
			if OS.get_cmdline_user_args().has("--hylkaa"):
				main._thief.roam = 6.0
			var maxd := 0.0
			for k in 110:
				await main.get_tree().create_timer(1.0).timeout
				if main._thief.is_empty():
					break
				var dd := Vector2(main.bike.global_position.x - main.walker_out.global_position.x, main.bike.global_position.z - main.walker_out.global_position.z).length()
				if main._thief.phase == "roam":
					maxd = maxf(maxd, dd)
				if k % 6 == 0:
					print("VARAS %2d s: vaihe=%s etäisyys=%.0f m nopeus=%.1f reitti=%d kuuluvuus=%.2f rullaus=%.0f dB" % [k, main._thief.phase, dd, main.bike.speed,
						(main._thief.route as PackedVector3Array).size(), main.bike._hear(), main.bike._roll.volume_db])
			print("VARAS ajelun suurin etäisyys %.0f m, käynnissä=%s msg=%s" % [maxd, not main._thief.is_empty(), main._msg.text])
			if not main._thief.is_empty():
				var oc := Camera3D.new()
				main.add_child(oc)
				oc.look_at_from_position(main.bike.global_position + Vector3(5, 3, 5), main.bike.global_position + Vector3(0, 1, 0), Vector3.UP)
				oc.current = true
				await main.get_tree().create_timer(0.3).timeout
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_varas.png"))
				oc.queue_free()
				main.walker_out.global_position = main.bike.global_position + Vector3(2.0, 0.5, 0)
				await main.get_tree().create_timer(0.5).timeout
				print("VARAS kiinni? käynnissä=%s msg=%s" % [not main._thief.is_empty(), main._msg.text])
		"junavaunu", "junavaunu_saloinen":
			# Ravintolavaunun välianimaatio: kuva jokaisesta repliikistä (Helenan lähentely, pelaajan hiki).
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--asu="):
					Looks.outfit = arg.substr(6)  # esim. farkut: verkkopaidassa Helena painautuu kiinni
			var done := [false]
			main.cutscene.train_ride(func() -> void: done[0] = true, not OS.get_cmdline_user_args().has("--eitarjoa"))  # --eitarjoa: normaali sketsi ilman kossuja
			var seen := ""
			var due := -1
			var n := 0
			var close_n := 0
			var close_due := 0
			var seat_checked := false
			var phase_due: Array = []
			var cast_hand := func(tc: Dictionary) -> Vector3:
				return tc.helena.to_global(tc.helena.bone_position("hand_r")) if tc.has("helena") else Vector3.ZERO
			var t0 := Time.get_ticks_msec()
			while not done[0] and Time.get_ticks_msec() - t0 < 90000:
				await main.get_tree().process_frame
				var sub: String = main.cutscene._sub.text
				if sub != seen and sub.contains(": "):
					seen = sub
					due = Time.get_ticks_msec() + 1500
					if sub.ends_with("Mmm..."):
						# Vihjaileva ilme (verkkopaita): vaiheet koko repliikin ajalta.
						for ms in [150, 450, 750, 1050, 1350, 1650, 1950, 2200]:
							phase_due.append(Time.get_ticks_msec() + ms)
				if not phase_due.is_empty() and Time.get_ticks_msec() >= phase_due[0]:
					phase_due.pop_front()
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_ilme%d.png" % (8 - phase_due.size())))
				# Penkit: hahmon pinnan pisteet vs. istuin- ja selkänojalaatikot (vaunun avaruudessa), kerran.
				if not seat_checked and not main.cutscene.train_cast.is_empty() and main.cutscene.train_cast.has("tyynyt") and (main.cutscene.train_cast.minä as Node3D).position.y > 0.005:
					seat_checked = true
					var sc0: Dictionary = main.cutscene.train_cast
					var carn: Node3D = sc0.scenery.get_parent()
					for nm in ["minä", "helena", "marja", "liisa"]:
						var boxes := []  # [nimi, min, max]: oma tyyny, selkänojat ja pöytä
						var cu: Node3D = sc0.tyynyt[nm]
						var cx: float = cu.position.x
						var cz: float = cu.position.z
						boxes.append(["tyyny", Vector3(cx - 0.225, 0.0, cz - 0.275), Vector3(cx + 0.225, cu.scale.y, cz + 0.275)])
						for sz in [-1.0, 1.0]:
							boxes.append(["selkä%+.0f" % sz, Vector3(-1.3, 0.445, 1.15 * sz - 0.06), Vector3(-0.4, 1.25, 1.15 * sz + 0.06)])
						boxes.append(["pöytä", Vector3(-1.3, 0.725, -0.375), Vector3(-0.4, 0.775, 0.375)])
						var chn: Node3D = sc0[nm]
						var bn := []
						for bi in chn.skeleton.get_bone_count():
							bn.append(chn.skeleton.get_bone_name(bi))
						var pts := Pose.limb_points(chn, carn, bn, 1)
						var worst := {}
						for q in pts:
							var lq: Vector3 = q
							for b in boxes:
								var bmin: Vector3 = b[1]
								var bmax: Vector3 = b[2]
								if lq.x > bmin.x and lq.x < bmax.x and lq.y > bmin.y and lq.y < bmax.y and lq.z > bmin.z and lq.z < bmax.z:
									var dep := minf(minf(lq.x - bmin.x, bmax.x - lq.x), minf(minf(lq.y - bmin.y, bmax.y - lq.y), minf(lq.z - bmin.z, bmax.z - lq.z)))
									worst[b[0]] = maxf(float(worst.get(b[0], 0.0)), dep)
						var min_y := INF
						var butt_y := INF
						var back_z := 0.0
						var zdir := 1.0 if nm in ["minä", "helena"] else -1.0
						for q in pts:
							min_y = minf(min_y, q.y)
							if q.y > 0.3 and q.y < 0.75 and q.x > -1.3 and q.x < -0.4 and absf(q.z - zdir * 0.85) < 0.3:
								butt_y = minf(butt_y, q.y)
								back_z = maxf(back_z, (q.z * zdir))
						var sk := Camera3D.new()
						main.add_child(sk)
						sk.look_at_from_position(carn.to_global(Vector3(1.25, 0.55, zdir * 0.85)), carn.to_global(Vector3(-0.85, 0.55, zdir * 0.85)), Vector3.UP)
						sk.current = true
						await Kuva.piirto()
						await Kuva.piirto()
						Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_penkki_%s.png" % nm))
						sk.queue_free()
						if is_instance_valid(main.cutscene._cam):
							main.cutscene._cam.current = true
						print("PENKKI %s paikka %s pisteitä %d, uppoaa: %s | alin y %.3f, takamus alin y %.3f (istuin 0.445), selkä z %.3f (selkänoja 1.09)" % [nm, chn.position, pts.size(), str(worst), min_y, butt_y, back_z])
				# Käsi reidellä: suurennos pelaajan vasemmasta reidestä pöydän yli ja sivusta (0.7 s välein).
				var tc: Dictionary = main.cutscene.train_cast
				if not tc.is_empty() and is_instance_valid(tc.helena) and tc.helena._ik.has("arm_r") and close_n < 24 \
						and Time.get_ticks_msec() >= close_due and (cast_hand.call(tc) != Vector3.ZERO):
					close_due = Time.get_ticks_msec() + 900
					var hero: Node3D = tc["minä"]
					var th: Vector3 = hero.to_global(hero.bone_position("thigh_l").lerp(hero.bone_position("calf_l"), 0.55))
					var cc := Camera3D.new()
					cc.fov = 38.0
					main.add_child(cc)
					for view in [["e", Vector3(0.12, 0.12, -0.55)], ["s", Vector3(-0.55, 0.25, -0.15)], ["v", Vector3(-0.35, 0.5, -0.35)]]:
						if not is_instance_valid(hero):
							break  # välianimaatio loppui kesken kuvien (hidas kone): hahmot on jo vapautettu
						cc.look_at_from_position(th + hero.global_basis * view[1], th, Vector3.UP)
						cc.current = true
						await Kuva.piirto()
						Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kasi%02d%s.png" % [close_n, view[0]]))
					# Ylävartalo edestä ja ylhäältä takaa (verkkopaidassa vasen käsi Helenan ympärillä).
					var chest: Vector3 = hero.to_global(hero.bone_position("Head")) + Vector3(0, -0.3, 0) if is_instance_valid(hero) else Vector3.ZERO
					for view in [["f", Vector3(-0.35, 0.15, -1.3)], ["t", Vector3(-0.2, 0.9, 0.6)]]:
						if not is_instance_valid(hero):
							break
						cc.look_at_from_position(chest + hero.global_basis * view[1], chest, Vector3.UP)
						cc.current = true
						await Kuva.piirto()
						Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kasi%02d%s.png" % [close_n, view[0]]))
					cc.queue_free()
					if is_instance_valid(main.cutscene._cam):
						main.cutscene._cam.current = true
					close_n += 1
				if due > 0 and Time.get_ticks_msec() >= due:
					due = -1
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%02d.png" % n))
					print("JUNAVAUNU %02d %s" % [n, seen])
					n += 1
		_:
			return 0
	return 1
