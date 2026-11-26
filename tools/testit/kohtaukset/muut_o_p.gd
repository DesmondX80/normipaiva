extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "muut_o_p". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const B := preload("res://scripts/build.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const EBike := preload("res://scripts/ebike.gd")
const SuloPannu := preload("res://scripts/sulo_pannu.gd")
const PakkahuoneLegenda := preload("res://scripts/pakkahuone_legenda.gd")
const PeruskiviLegenda := preload("res://scripts/peruskivi_legenda.gd")
const Endings := preload("res://scripts/endings.gd")
const Quests := preload("res://scripts/quests.gd")
const Story := preload("res://scripts/story.gd")

const KOHTAUKSET := ["pohjoinen", "picktest", "pakkahuone", "peruskivi", "palonpyhimys", "paivakirja", "pannu", "pohjoiset", "pedot", "pitkalappu", "omatjuomat", "pojat", "pontikka", "pensasaita"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"pohjoinen":
			# Pohjoinen laajennus (map_data.MAP_MIN): Seuranmäki, Reippari, Tokola, rossirata, rata ja pohjoisreuna.
			main._note.visible = false
			var oc := Camera3D.new()
			oc.far = 3000.0
			oc.fov = 60.0
			main.add_child(oc)
			var snap := func(name: String, from: Vector2, h: float, to: Vector2) -> void:
				oc.look_at_from_position(M.w(from) + Vector3(0, h, 0), M.w(to) + Vector3(0, 1.5, 0))
				oc.current = true
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			await snap.call("_ilma.png", Vector2(330, 150), 520.0, Vector2(380, -450))
			await snap.call("_seuranmaki.png", Vector2(470, -200), 25.0, Vector2(410, -280))
			await snap.call("_reippari.png", Vector2(450, -250), 2.0, Vector2(434, -281))
			await snap.call("_tokola.png", Vector2(420, -440), 6.0, Vector2(350, -540))
			await snap.call("_rossirata.png", Vector2(200, -700), 60.0, Vector2(100, -796))
			await snap.call("_rata.png", Vector2(240, -330), 4.0, Vector2(300, -620))
			await snap.call("_reuna.png", Vector2(500, -700), 6.0, Vector2(500, -950))
			await snap.call("_sauma.png", Vector2(300, 80), 30.0, Vector2(300, -120))
			main.get_tree().quit()
		"picktest":
			# Puolukan poiminta: rauhallinen A/D-tahti, sitten räpellys ja pelkkä A. Tallennus palautetaan lopuksi.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			if main.player != main.walker_out:
				main._toggle_mount()
			var tries := [["tahti 0,25 s", 15], ["räpellys joka ruutu", 1], ["vain A", 15]]
			for tr in tries:
				var berry: Dictionary = {}
				for f in main.world.forage:
					if not f.taken and f.kind in Main.BERRIES:
						berry = f
						break
				main.walker_out.global_position = berry.pos + Vector3(0.8, 0.5, 0)
				main.walker_out.stamina = 100.0
				main.walker_out.exhausted = false
				for i in 20:
					await main.get_tree().physics_frame
				Input.action_press("interact")
				for w in 2:
					await main.get_tree().process_frame
				Input.action_release("interact")
				var t0 := Time.get_ticks_msec()
				var key := "left"
				for n in 400:
					if main._pick_t < 0.0:
						break
					Input.action_press(key)
					for w in 2:
						await main.get_tree().process_frame
					Input.action_release(key)
					if tr[0] != "vain A":
						key = "right" if key == "left" else "left"
					for w in tr[1]:
						await main.get_tree().process_frame
					if n == 6 and tr == tries[0]:  # ohjeen näppäinhatut kuvaan kesken poiminnan
						await Kuva.piirto()
						Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_ohje.png"))
				print("PICK %s: valmis=%s aika=%.1f s mittari=%.2f kunto=%.0f ämpäri=%s ohjaus=%s" % [tr[0], main._pick_t < 0.0,
					(Time.get_ticks_msec() - t0) / 1000.0, main._pick_meter, main.walker_out.stamina, main.bucket, main.walker_out.controls_enabled])
				main._stop_picking()
			# Sieni: pelkkä odotus, ähkäisy kumartuessa ja noustessa.
			for f in main.world.forage:
				if not f.taken and not (f.kind in Main.BERRIES):
					main.walker_out.global_position = f.pos + Vector3(0.8, 0.5, 0)
					break
			for i in 20:
				await main.get_tree().physics_frame
			Input.action_press("interact")
			for w in 2:
				await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().create_timer(Main.PICK_TIME + 0.5).timeout
			print("PICK sieni: valmis=%s ämpäri=%s" % [main._pick_t < 0.0, main.bucket])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"pakkahuone":
			# Pakkahuoneen veistos (#250 P5): taksikuski kertoo, veistos katoaa, kuraattori ja vierailijakirja vihjeinä, luukulla löytyy; tallennus; kuvat.
			main._note.visible = false
			var ph_shot := func(name: String) -> void:
				for i in 3:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.pakkahuone = PakkahuoneLegenda.new()
			print("PH taksivalinnat: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "pakkahuone_kerro" or o.id == "retki_pakkahuone").map(func(o): return [o.id, o.enabled, o.text])])
			print("PH tehtävät ennen: %s" % [main._pakkahuone_tasks()])
			var ph_t0 := main.clock_min
			main._retki_from = main.player.global_position
			main._enter_retki("pakkahuone")
			print("PH perillä: state %s, kello +%.0f min, veistos esillä %s" % [main.state, main.clock_min - ph_t0, main.retki_int._special.visible])
			main.retki_int.walker.position = main.retki_int.spots.veistos[0]
			main.retki_int.walker.rotation.y = B.yaw_to(Vector3(0, 0, -1))
			await ph_shot.call("sali_ennen")
			main._on_retki_acted("luukku")
			main._talk_open("taksi", null, "Kyytiä?")
			main._talk_pakkahuone("pakkahuone_kerro")
			main._talk_box.close()
			for i in 3:
				await main.get_tree().process_frame
			print("PH kuultu %s, tehtävät %s, veistos esillä %s, valinta pois %s" % [main.pakkahuone.heard, main._pakkahuone_tasks(), main.retki_int._special.visible, main._talk_options("taksi").filter(func(o): return o.id == "pakkahuone_kerro").is_empty()])
			await ph_shot.call("sali_poissa")
			main._on_retki_acted("luukku")
			print("PH luukku ilman vihjeitä: found %s (false)" % main.pakkahuone.found)
			main.retki_int.walker.position = main.retki_int.spots.kuraattori[0]
			for i in 3:
				await main.get_tree().process_frame
			print("PH kuraattorilla: spot '%s', vihje '%s'" % [main.retki_int.spot, main._hint.text])
			main._on_retki_acted("kuraattori")
			await ph_shot.call("kuraattori")
			print("PH kuraattori %s, tehtävät %s" % [main.pakkahuone.kuraattori, main._pakkahuone_tasks()])
			main.retki_int.walker.position = main.retki_int.spots.kirja[0]
			for i in 3:
				await main.get_tree().process_frame
			print("PH kirjalla: spot '%s'" % main.retki_int.spot)
			main._on_retki_acted("kirja")
			print("PH kirja %s, tehtävät %s" % [main.pakkahuone.kirja, main._pakkahuone_tasks()])
			main.retki_int.walker.position = main.retki_int.spots.luukku[0]
			for i in 3:
				await main.get_tree().process_frame
			print("PH luukulla: spot '%s'" % main.retki_int.spot)
			var ph_m0 := main.maine
			main._on_retki_acted("luukku")
			for i in 3:
				await main.get_tree().process_frame
			print("PH loppu: found %s, esillä %s, maine %.0f -> %.0f, loppu kirjattu %s, tehtävät %s" % [main.pakkahuone.found, main.retki_int._special.visible, ph_m0, main.maine, main.endings.counts.has("pakkahuoneen_veistos"), main._pakkahuone_tasks()])
			await ph_shot.call("luukku_auki")
			main.retki_int.walker.position = main.retki_int.spots.veistos[0]
			for i in 3:
				await main.get_tree().process_frame
			await ph_shot.call("sali_loppu")
			main._on_retki_acted("luukku")
			print("PH toistokerta: maine %.0f (ei kasva)" % main.maine)
			var ph_cfg := ConfigFile.new()
			main.pakkahuone.save_to(ph_cfg)
			var ph_l: RefCounted = PakkahuoneLegenda.new()
			ph_l.load_from(ph_cfg)
			print("PH tallennus: heard %s kuraattori %s kirja %s found %s" % [ph_l.heard, ph_l.kuraattori, ph_l.kirja, ph_l.found])
			main._on_retki_exited()
			await main.get_tree().create_timer(14.0).timeout
			print("PH takaisin: state %s, etäisyys lähtöpaikasta %.2f m, kello +%.0f min" % [main.state, main.player.global_position.distance_to(main._retki_from), fposmod(main.clock_min - ph_t0, 1440.0)])
			main.get_tree().quit()
		"peruskivi":
			# Rautaruukin peruskivi (#250 P6): taksikuski kertoo, vartija ja kyltti vihjeinä, laatta kiven edessä avaa kätkön (kerran); tallennus; kuvat.
			main._note.visible = false
			var pk_shot := func(name: String) -> void:
				for i in 3:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.peruskivi = PeruskiviLegenda.new()
			print("PK taksivalinnat: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "peruskivi_kerro" or o.id == "retki_rojuniemi").map(func(o): return [o.id, o.enabled, o.text])])
			print("PK tehtävät ennen: %s" % [main._peruskivi_tasks()])
			main._talk_open("taksi", null, "Kyytiä?")
			main._talk_peruskivi("peruskivi_kerro")
			main._talk_box.close()
			print("PK kuultu %s, tehtävät %s, valinta pois %s" % [main.peruskivi.heard, main._peruskivi_tasks(), main._talk_options("taksi").filter(func(o): return o.id == "peruskivi_kerro").is_empty()])
			print("PK päiväkirja: %s" % [main.quests.hint_for("taksi", main.tilat.firsts, main.quest_flag)])
			var pk_t0 := main.clock_min
			var pk_m0 := main.money
			main._retki_from = main.player.global_position
			main._enter_retki("rojuniemi")
			print("PK perillä: state %s, kello +%.0f min" % [main.state, main.clock_min - pk_t0])
			await pk_shot.call("alue")
			main.retki_int.walker.position = main.retki_int.spots.laatta[0]
			main.retki_int.walker.rotation.y = B.yaw_to(Vector3(0, 0, -1))
			for i in 3:
				await main.get_tree().process_frame
			print("PK laatalla: spot '%s', vihje '%s'" % [main.retki_int.spot, main._hint.text])
			main._on_retki_acted("laatta")
			print("PK laatta ilman vihjeitä: found %s (false)" % main.peruskivi.found)
			await pk_shot.call("laatta_kiinni")
			main.retki_int.walker.position = main.retki_int.spots.vartija[0]
			for i in 3:
				await main.get_tree().process_frame
			print("PK vartijalla: spot '%s'" % main.retki_int.spot)
			main._on_retki_acted("vartija")
			await pk_shot.call("vartija")
			print("PK vartija %s, tehtävät %s" % [main.peruskivi.vartija, main._peruskivi_tasks()])
			main.retki_int.walker.position = main.retki_int.spots.kyltti[0]
			for i in 3:
				await main.get_tree().process_frame
			print("PK kyltillä: spot '%s'" % main.retki_int.spot)
			main._on_retki_acted("kyltti")
			await pk_shot.call("kyltti")
			print("PK kyltti %s, tehtävät %s" % [main.peruskivi.kyltti, main._peruskivi_tasks()])
			main.retki_int.walker.position = main.retki_int.spots.kivi[0]
			for i in 3:
				await main.get_tree().process_frame
			print("PK kivellä: spot '%s'" % main.retki_int.spot)
			main.retki_int.walker.position = main.retki_int.spots.laatta[0]
			for i in 3:
				await main.get_tree().process_frame
			var pk_maine0 := main.maine
			var pk_cam := main.get_viewport().get_camera_3d()
			var pk_close := func(name: String, from: Vector3, to: Vector3) -> void:
				var c := Camera3D.new()
				c.fov = 45.0
				main.retki_int.add_child(c)
				c.look_at_from_position(main.retki_int.global_position + from, main.retki_int.global_position + to)
				c.current = true
				main._hud.visible = false
				await pk_shot.call(name)
				main._hud.visible = true
				pk_cam.make_current()
				c.queue_free()
			await pk_close.call("kivi_kiinni", Vector3(5.5, 2.4, 3.2), Vector3(5.8, 0.6, -2.2))
			await pk_close.call("kivi_ylhaalta", Vector3(5.5, 7.0, 0.5), Vector3(5.5, 0.0, -2.0))
			main._on_retki_acted("laatta")
			for i in 3:
				await main.get_tree().process_frame
			await pk_close.call("kivi_auki", Vector3(5.5, 2.4, 3.2), Vector3(5.8, 0.6, -2.2))
			await pk_close.call("tehdas", Vector3(-2.0, 2.0, 8.0), Vector3(-2.0, 4.0, -10.0))
			print("PK loppu: found %s, maine %.0f -> %.0f, raha %s -> %s, loppu kirjattu %s, tehtävät %s" % [main.peruskivi.found, pk_maine0, main.maine, main._eur(pk_m0), main._eur(main.money), main.endings.counts.has("peruskiven_kapseli"), main._peruskivi_tasks()])
			await pk_shot.call("laatta_auki")
			var pk_m1 := main.money
			main._on_retki_acted("laatta")
			print("PK toistokerta: maine %.0f, raha %s -> %s (ei kasva)" % [main.maine, main._eur(pk_m1), main._eur(main.money)])
			var pk_cfg := ConfigFile.new()
			main.peruskivi.save_to(pk_cfg)
			var pk_l: RefCounted = PeruskiviLegenda.new()
			pk_l.load_from(pk_cfg)
			print("PK tallennus: heard %s vartija %s kyltti %s found %s" % [pk_l.heard, pk_l.vartija, pk_l.kyltti, pk_l.found])
			main._on_retki_exited()
			await main.get_tree().create_timer(14.0).timeout
			print("PK takaisin: state %s, etäisyys lähtöpaikasta %.2f m, kello +%.0f min" % [main.state, main.player.global_position.distance_to(main._retki_from), fposmod(main.clock_min - pk_t0, 1440.0)])
			main.get_tree().quit()
		"palonpyhimys":
			# Palon yön pyhimys (#125): koko ketju logiikkana (hoitaja, luettelo, vuosipäivän kynttilä ja nainen, lupaus, Aaro,
			# Tokolan orsi, palautus suntiolle) sekä epäilijöiden repliikit. Tallennus palautetaan.
			var saved_py := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main._note.visible = false
			main.tokola.key = true
			main._pyhimys_nodes()
			main.day = 5
			main.clock_min = 20 * 60
			print("PY vuosipäivä päivä 5: %s, päivä 6: %s" % [main.pyhimys.vuosipaiva(5), main.pyhimys.vuosipaiva(6)])
			print("PY hoitaja: %s" % [main._talk_options("hoitaja").map(func(o): return o.id)])
			main._talk_who = "hoitaja"
			main._talk_pyhimys("pyhimys_kerro")
			print("PY kuultu %s, tehtävät %s" % [main.pyhimys.heard, main._pyhimys_tasks()])
			print("PY suntio: %s" % [main._talk_options("suntio").map(func(o): return o.id)])
			main._talk_pyhimys("pyhimys_luettelo")
			print("PY luettelo %s, tehtävät %s" % [main.pyhimys.luettelo, main._pyhimys_tasks()])
			main._pyhimys_logic()
			print("PY päivä 5 illalla: kynttilä %s, nainen %s" % [main._kynttila_flame.visible, main.kynttilanainen.visible])
			main.day = 6
			main.clock_min = 12 * 60
			main._pyhimys_logic()
			print("PY päivä 6 päivällä: kynttilä %s, nainen %s" % [main._kynttila_flame.visible, main.kynttilanainen.visible])
			main.clock_min = 20 * 60
			main._pyhimys_logic()
			print("PY päivä 6 illalla: kynttilä %s, nainen %s, naisen paikka %s, haudalla %s" % [main._kynttila_flame.visible, main.kynttilanainen.visible, main.kynttilanainen.global_position, main.world.kynttila_pos])
			print("PY nainen: %s" % [main._talk_options("kynttilanainen").map(func(o): return o.id)])
			print("PY Aaro ennen lupausta: %s" % [main._talk_options("aaro").map(func(o): return o.id).has("pyhimys_aitta")])
			main._talk_pyhimys("pyhimys_lupaa")
			print("PY lupaus %s, Aaro nyt: %s, tehtävät %s" % [main.pyhimys.lupaus, main._talk_options("aaro").map(func(o): return o.id).has("pyhimys_aitta"), main._pyhimys_tasks()])
			main._talk_pyhimys("pyhimys_aitta")
			main._varasto_hints()
			print("PY varaston orsi: vihje '%s', tehtävät %s" % [main.varasto_int.hints.orsi, main._pyhimys_tasks()])
			main._on_varasto_acted("orsi")
			print("PY löydetty %s, suntio: %s" % [main.pyhimys.found, main._talk_options("suntio").map(func(o): return o.id)])
			var m0 := main.maine
			main._talk_pyhimys("pyhimys_anna")
			print("PY palautettu %s, maine %.0f -> %.0f, loppu %s, tehtävät %s" % [main.pyhimys.returned, m0, main.maine, main.endings.counts.has("palon_pyhimys"), main._pyhimys_tasks()])
			main.clock_min = 12 * 60
			main._pyhimys_logic()
			print("PY palautuksen jälkeen päivällä: kynttilä %s, nainen kirkolla %s (%s)" % [main._kynttila_flame.visible, main.kynttilanainen.visible, main.kynttilanainen.global_position.distance_to(main.world.kirkko_pos) < 4.0])
			main.clock_min = 20 * 60
			main._pyhimys_logic()
			print("PY palautuksen jälkeen illalla: kynttilä %s, nainen %s" % [main._kynttila_flame.visible, main.kynttilanainen.visible])
			for who in ["suntio", "pekka", "sinikka"]:
				main._talk_who = who
				var seen := false
				for i in 40:
					if (Main.PYHIMYS_PROVEN[who] as Array).has(main._talk_chat_line()):
						seen = true
						break
				print("PY %s todistettu repliikki: %s" % [who, seen])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_py)
			main.get_tree().quit()
		"paivakirja":
			# Normipäiväkirja (#132): alussa vain luku 1 ja itsestäänselvät tehtävät, Raahen loppu avaa luvun 2,
			# Santun vihje tervehdyksessä, sivutehtävät ilmestyvät, loppujen kirjaus (erilaiset ja yhteensä) ja kuvat
			# kolmesta välilehdestä. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.quests = Quests.new()
			main.endings = Endings.new()
			main.story = Story.new()
			main.ebike = EBike.new()
			main.tilat.firsts = []
			var snap := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var summary := func() -> String:
				var d := main.journal_data()
				return "luvut %s, tehtävät %s, loput %d/%d yht %d, hetket %d/%d" % [d.chapters.map(func(c): return "%s(%d rivi%s)" % [c.title.left(2), c.rows.size(), ",valmis" if c.done else ""]),
					d.side.map(func(q): return q.title), d.loput.distinct, d.loput.max, d.loput.total, d.hetket.distinct, d.hetket.max]
			print("PK alku: ", summary.call())
			main.story.step = "valmis"
			main._ending("paapeli")
			main.tilat.first("mokki")
			print("PK paapeli: ", summary.call())
			main.tilat.first("santtu")
			print("PK santtu tervehtii: '%s'" % main._talk_hello("santtu"))
			print("PK santun jälkeen: ", summary.call())
			for k in ["drooni", "kirppis", "pojat", "raahe", "kotiviini"]:
				main.tilat.first(k)
			main.ebike.started = true
			main._ending("juhlat")
			main._ending("juhlat")
			main._ending("legendaarinen")
			print("PK lisää: ", summary.call())
			print("PK viesti: '%s'" % [main._msg_queue.back() if not main._msg_queue.is_empty() else main._msg.text])
			# Retkien legendat ja karttalinkit: tiedoksi ensimmäisestä kohdasta, edistyminen ja "näytä kartalla"
			# (Saloisten paikat ja taksitolppa).
			for k in ["pyhakoski_voimala", "kuvakirkko_suntio", "wanharaahe_patsas", "karhut_opas", "olavi_legenda",
					"kuningas_legenda", "kanttori_legenda", "pingis_ulkopoyta", "hanhikivi_legenda", "kalajoki_sarkat", "kalalupa",
					"pubivisa", "uintikilpailu", "keikkatyo", "tyokkari", "rasvanappi", "rakaleima", "tappelu_juntti",
					"lintutorni", "pajatso", "ronttonen"]:
				main.tilat.first(k)
			main.pyhakoski.voimala = true
			main.wanharaahe.kuvat = ["patsas"]
			var dl := main.journal_data()
			var by := {}
			for q in dl.side:
				by[q.id] = q
			for id in ["pyhakoski", "kuvakirkko", "wanharaahe", "karhut", "olavinmarkkinat", "kuninkaan_tapuli",
					"kanttorin_yosavel", "pihapingis", "hanhikiven_rajakivi", "kalajoki", "kalalampi", "pubivisa"]:
				if not by.has(id):
					print("TESTI VIKA päiväkirjasta puuttuu tehtävä ", id)
				elif not by[id].spot:
					print("TESTI VIKA tehtävällä %s ei ole näytä kartalla -linkkiä" % id)
				else:
					print("PK %s: %s (%s)" % [id, by[id].title, by[id].progress])
			for id in ["tekemiset", "hanttihommat", "rasvanappi", "rakaleima", "tappelut"]:
				if not by.has(id):
					print("TESTI VIKA päiväkirjasta puuttuu tehtävä ", id)
				else:
					print("PK %s: %s (%s)%s" % [id, by[id].title, by[id].progress, " tehty" if by[id].done else ""])
			if by.has("hanttihommat") and by.hanttihommat.progress != "kokeiltu 2 / 5":
				print("TESTI VIKA hanttihommien edistyminen '%s'" % by.hanttihommat.progress)
			if by.has("tekemiset") and by.tekemiset.progress != "kokeiltu 3 / 6":
				print("TESTI VIKA kylän tekemisten edistyminen '%s'" % by.tekemiset.progress)
			if by.has("rasvanappi") and not by.rasvanappi.done:
				print("TESTI VIKA rasvanappi ei ole tehty, vaikka pelattu")
			if by.has("pyhakoski") and by.pyhakoski.progress != "tarinat 1 / 3":
				print("TESTI VIKA Pyhäkosken edistyminen '%s'" % by.pyhakoski.progress)
			main.show_quest_on_map("pyhakoski")
			var taksi := Vector2(main.world.taxi_pos.x, main.world.taxi_pos.z)
			print("PK pyhäkoski kartalla: kohde %s, taksi %s" % [main._paper.target, taksi])
			if main._paper.target.distance_to(taksi) > 1.0:
				print("TESTI VIKA retken näytä kartalla ei osoita taksitolpalle")
			if main.quest_marks(true).any(func(m): return m[4] in Main.TAXI_QUESTS):
				print("TESTI VIKA retkille piirretään renkaita kartalle")
			main._journal.toggle()
			for t in ["tarina", "tehtavat", "loput"]:
				main._journal._set_tab(t)
				for i in 4:
					await main.get_tree().process_frame
				await snap.call("_%s.png" % t)
			main._journal._set_tab("tehtavat")  # listan loppu: retkien legendat ja niiden linkit
			main._journal._scroll = 1700.0
			main._journal.queue_redraw()
			for i in 4:
				await main.get_tree().process_frame
			await snap.call("_tehtavat_loppu.png")
			# Esc sulkee päiväkirjan eikä avaa taukovalikkoa (ennen valikko jäi auki ja peli pyöri taustalla).
			var esc := InputEventKey.new()
			esc.physical_keycode = KEY_ESCAPE
			esc.keycode = KEY_ESCAPE
			esc.pressed = true
			Input.parse_input_event(esc)
			for i in 3:
				await main.get_tree().process_frame
			esc = esc.duplicate()
			esc.pressed = false
			Input.parse_input_event(esc)
			await main.get_tree().process_frame
			print("PK esc: päiväkirja auki %s, valikko auki %s, tauko %s" % [main._journal.visible, main.menu.visible, main.get_tree().paused])
			if main._journal.visible:
				main._journal.toggle()
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"pannu":
			# Legenda: Sulon isän kadonnut pannu (#130): Aaron kertomus, epäilijät, droonikuva, kaivaminen rämeestä ja
			# kolme valintaa (Sulo, Pirtti, romu) seurauksineen. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.pannu = SuloPannu.new()
			main.tokola.key = true
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
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
			print("PA aaro: %s" % [main._talk_options("aaro").map(func(o): return o.id)])
			main._talk_open("aaro", main.aaro)
			main._talk_box._pages.clear()
			main._talk_choose("vanhasulo")
			main._talk_box.close()
			print("PA kuultu %s, läikkä näkyy %s, tehtävät %s" % [main.pannu.heard, main._pannu_node.visible, main._pannu_tasks()])
			var doubt := {}
			for i in 20:
				main._talk_who = "sulo"
				doubt[main._talk_chat_line()] = true
			print("PA sulo epäilee: %s" % [Main.PANNU_DOUBT.sulo.any(func(l): return doubt.has(l))])
			var spot := M.w(SuloPannu.SPOT)
			main.walker_out.global_position = spot + Vector3(1.0, 0.3, 0)
			await frames.call(10)
			print("PA rämeellä ilman kuvaa: '%s'" % main._hint.text)
			print("PA droonikohde: %s" % [main._drone_pois().any(func(d): return d.id == "kuparipannu")])
			var oc := Camera3D.new()
			main.add_child(oc)
			oc.look_at_from_position(spot + Vector3(6, 9, 6), spot)
			oc.current = true
			await frames.call(20)
			await snap.call("_rame.png")
			oc.current = false
			main.player.activate_camera()
			main._on_drone_photo("kuparipannu")
			await frames.call(5)
			print("PA kuvattu: %s, tehtävät %s" % [main.pannu.spotted, main._pannu_tasks()])
			await press.call("interact")
			print("PA kaivettu: %s, viesti '%s'" % [main.pannu.found, main._msg.text.left(90)])
			print("PA sulo: %s, tauno: %s" % [main._talk_options("sulo").map(func(o): return o.id), main._talk_options("tauno").map(func(o): return o.id)])
			# Valinta 1: Pirtti.
			var md: Vector3 = main.world.museum_door
			main.walker_out.global_position = md + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("PA pirtti: '%s'" % main._hint.text)
			oc.look_at_from_position(md + (md - M.w(M.PIRTTI)).normalized() * 9.0 + Vector3(0, 3, 0), M.w(M.PIRTTI) + Vector3(0, 1.5, 0))
			oc.current = true
			await frames.call(20)
			await snap.call("_pirtti.png")
			oc.current = false
			main.player.activate_camera()
			await press.call("interact")
			print("PA museo: valinta %s, maine %d, kanisteri %s € / %d kaljaa" % [main.pannu.choice, roundi(main.maine), main._eur(main._kanister_price()), main._kanister_beers()])
			# Valinta 2: Sulo.
			main.pannu.choice = ""
			main._talk_open("sulo", main.sulo)
			main._talk_box._pages.clear()
			main._talk_choose("pannu")
			main._talk_box.close()
			var proven := {}
			for i in 20:
				main._talk_who = "sulo"
				proven[main._talk_chat_line()] = true
			print("PA sulo: valinta %s, kanisteri %s € / %d kaljaa, myöntää %s" % [main.pannu.choice, main._eur(main._kanister_price()), main._kanister_beers(),
				Main.PANNU_PROVEN.sulo.any(func(l): return proven.has(l))])
			# Valinta 3: romu.
			main.pannu.choice = ""
			var m0 := main.money
			main._talk_who = "tauno"
			main._talk_kirppis("romu")
			main._talk_box.close()
			main._talk_who = "aaro"
			print("PA romu: valinta %s, rahaa %s -> %s, kanisteri %s €, Aaro: '%s'" % [main.pannu.choice, main._eur(m0), main._eur(main.money), main._eur(main._kanister_price()), main._talk_chat_line()])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"pohjoiset":
			# Kylän pohjoisosan paikat: kenttä (rankkarit, lenkki), Oravajärven uimaranta (uinti, löydöt, grilli,
			# kalja, jemma, sormus Sinikalle), SEO ja A+ (kahvi, munkki, lounas, rekka), Kinnapotti (katsastus hylätty ja
			# hyväksytty, hitsari, keikkatyö) ja rossirata (kierros ja palkinto). Kuvat paikoista ja minipelistä.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.quests = Quests.new()
			main._rankku_day = -1
			main._orava_finds = []
			main._orava_find_day = -1
			main._sormus_given = false
			main.katsastus = ""
			main._keikka_day = -1
			main._rossi_best = 0.0
			main._rossi_won = false
			main.day = 3  # keskiviikko
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
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
			var at := func(pos: Vector3) -> void:
				main.walker_out.global_position = pos + Vector3(0, 0.3, 0)
				await frames.call(8)
			var oc := Camera3D.new()
			main.add_child(oc)
			var view := func(name: String, from: Vector3, to: Vector3) -> void:
				oc.look_at_from_position(from, to)
				oc.current = true
				await frames.call(30)
				await snap.call(name)
				oc.current = false
				main.player.activate_camera()
			main.money = 100.0
			main.clock_min = 12 * 60
			# Kenttä.
			var kc := M.w(M.KENTTA)
			await view.call("_kentta.png", kc + Vector3(-30, 14, 34), kc + Vector3(10, 0, -8))
			await at.call(main.world.kentta_spot)
			print("PO kenttä: '%s', pojat näkyy %s" % [main._hint.text, main.world.kentta_kids[0].visible])
			await press.call("interact")
			var g: Node = main._rankku
			print("PO maalin kehys pilkulta %.1f m (pitää olla 0: maan tasolla ja oikeassa kohdassa)" % (g.global_transform * Vector3(0, 0, 7)).distance_to(main.world.kentta_spot))
			print("PO rankkarit kentällä %s, kentän pojat piilossa %s, pelaaja piilossa %s" % [g != null and g.get_parent() == main.world,
				not main.world.kentta_kids[0].visible, not main.walker_out.visible])
			await main.get_tree().create_timer(2.0).timeout
			g._phase = "aim_y"
			g._t = 0.0
			g._aim = Vector2(0.75, 0.5)
			await main.get_tree().create_timer(0.2).timeout
			await snap.call("_rankku.png")
			g._aim = Vector2(0.75, 0.65)
			g._kick()
			g._keeper_dive = -1
			await main.get_tree().create_timer(0.25).timeout
			await snap.call("_laukaus.png")
			await main.get_tree().create_timer(0.5).timeout
			await snap.call("_maali.png")
			print("PO laukaus: %d – %d, '%s'" % [g._mine, g._theirs, g._tip.text])
			g._round = 1
			g._start_round()
			await main.get_tree().create_timer(1.5).timeout
			await snap.call("_torjunta.png")
			while g._phase == "runup":
				await main.get_tree().process_frame
			g._keeper_dive = g._kick_dir
			g._keeper_u = 0.0
			await main.get_tree().create_timer(0.3).timeout
			await snap.call("_heittaytyy.png")
			await main.get_tree().create_timer(0.6).timeout
			print("PO torjunta: %d – %d, '%s'" % [g._mine, g._theirs, g._tip.text])
			g._mine = 4
			g._theirs = 1
			g._finish("testi")
			await main.get_tree().create_timer(2.6).timeout
			print("PO rankkarit: '%s', päivä %d, peli ohi %s, pelaaja näkyy %s, pojat näkyy %s" % [main._msg.text.left(50), main._rankku_day, main._rankku == null, main.walker_out.visible, main.world.kentta_kids[0].visible])
			await at.call(main.world.kentta_laps[0])
			await press.call("interact")
			for i in [1, 2, 3, 0]:
				await at.call(main.world.kentta_laps[i])
			print("PO lenkki: kierroksia %d, '%s'" % [main._lenkki.laps, main._msg.text.left(40)])
			main._lenkki.on = false
			await at.call(main.world.kentta_spot + Vector3(0, 0, 200))
			# Uimaranta.
			var up: Vector3 = main.world.uimaranta_pos
			var dir3 := Vector3(M.UIMARANTA_DIR.x, 0, M.UIMARANTA_DIR.y)
			await view.call("_uimaranta.png", up - dir3 * 22.0 + Vector3(-8, 7, 0), up + dir3 * 2.0)
			await at.call(up)
			await frames.call(3)
			print("PO ranta: '%s'" % main._hint.text)
			main._swim("Oravajärvi", Vector3.ZERO)
			await main.get_tree().create_timer(4.0).timeout
			await snap.call("_uinti.png")
			for i in 80:
				if main.state != "cutscene":
					break
				await main.get_tree().create_timer(0.5).timeout
			print("PO uinti: tila %s, löydöt %s, '%s'" % [main.state, main._orava_finds, main._msg.text.right(60)])
			main.has_sausage = true
			main.sausage_done = false
			await at.call(main.world.grilli_ranta_pos + Vector3(1.2, 0, 0))
			print("PO grilli: '%s'" % main._hint.text)
			await press.call("interact")
			print("PO makkara paistettu %s" % main.sausage_done)
			main.beers = 2
			var m0 := main.maine
			await at.call(main.world.uimaranta_bench + Vector3(0.6, 0, 0))
			await press.call("interact")
			print("PO kalja perheiden edessä: maine %d -> %d" % [roundi(m0), roundi(main.maine)])
			await at.call(main.world.pukukoppi_pos)
			print("PO pukukoppi: '%s'" % main._hint.text)
			main._orava_finds = ["aurinkolasit", "nokia", "sormus"]
			print("PO sinikka: %s" % [main._talk_options("sinikka").map(func(o): return o.id)])
			main._talk_open("sinikka", main.sinikka)
			main._talk_box._pages.clear()
			main._talk_choose("sormus")
			main._talk_box.close()
			print("PO sormus annettu %s" % main._sormus_given)
			await frames.call(20)
			# SEO ja A+.
			var sd: Vector3 = main.world.seo_door
			var sdir := (sd - M.w(M.SEO)) * Vector3(1, 0, 1)
			await view.call("_seo.png", sd + sdir.normalized() * 16.0 + sdir.normalized().cross(Vector3.UP) * 10.0 + Vector3(0, 5, 0), M.w(M.SEO) + Vector3(0, 2, 0))
			main.clock_min = 3 * 60
			await at.call(sd)
			print("PO seo yöllä: '%s'" % main._hint.text)
			print("PO seo: %s" % [main._talk_options("seo").map(func(o): return "%s%s" % [o.id, "" if o.enabled else "(x)"])])
			main._talk_open("seo", null)
			main._talk_box._pages.clear()
			main._talk_choose("kahvi")
			main._talk_choose("munkki")
			main._talk_box.close()
			print("PO ostettu: munkki %d, rahaa %s" % [main.food.get("munkki", 0), main._eur(main.money)])
			main.clock_min = 12 * 60
			await at.call(main.world.aplus_door)
			print("PO A+: '%s', %s" % [main._hint.text, main._talk_options("aplus").map(func(o): return o.id)])
			main._talk_open("aplus", null)
			main._talk_box._pages.clear()
			main._talk_choose("lounas")
			main._talk_box.close()
			print("PO lounas päivä %d" % main._lunch_day)
			await frames.call(20)
			# Kinnapotti.
			var kd: Vector3 = main.world.katsastus_door
			var kdir := (kd - M.w(M.KATSASTUS)) * Vector3(1, 0, 1)
			var cKATSASTUS := M.w(M.KATSASTUS)
			var nKATSASTUS := (main.world._osm_fit_at(M.KATSASTUS).nrm as Vector2)
			await view.call("_kinnapotti.png", cKATSASTUS + Vector3(nKATSASTUS.x, 0, nKATSASTUS.y) * 26.0 + Vector3(0, 7, 0), cKATSASTUS + Vector3(0, 2, 0))
			var ad: Vector3 = main.world.arttim_door
			var cARTTIM := M.w(M.ARTTIM)
			var nARTTIM := (main.world._osm_fit_at(M.ARTTIM).nrm as Vector2)
			await view.call("_arttim.png", cARTTIM + Vector3(nARTTIM.x, 0, nARTTIM.y) * 26.0 + Vector3(0, 7, 0), cARTTIM + Vector3(0, 2, 0))
			for j in EBike.JOINTS:
				main.ebike.joints[j] = "teippi" if j == "akku" else ("sahkoteippi" if j == "johdot" else "ruuvi")
			main.ebike.loose = {}
			main.ebike.shorted = false
			main.ebike.battery = 1.0
			main.bike.global_position = kd + Vector3(3, 0.5, 3)
			await at.call(kd)
			print("PO katsastus: '%s', %s" % [main._hint.text, main._talk_options("katsastaja").map(func(o): return "%s%s" % [o.id, "" if o.enabled else "(x)"])])
			main._talk_open("katsastaja", null)
			main._talk_box._pages.clear()
			main._talk_choose("katsasta")
			main._talk_box.close()
			print("PO katsastus 1: %s" % main.katsastus)
			print("PO hitsari: %s" % [main._talk_options("hitsari").map(func(o): return o.id)])
			main._talk_open("hitsari", null)
			main._talk_box._pages.clear()
			main._talk_choose("teline")
			main._talk_choose("ruuvit")
			main._talk_box.close()
			print("PO akku %s, ruuvit %d" % [main.ebike.joints.akku, main.ebike.supplies.ruuvit])
			main._talk_open("katsastaja", null)
			main._talk_box._pages.clear()
			main._talk_choose("katsasta")
			main._talk_box.close()
			print("PO katsastus 2: %s, maine %d" % [main.katsastus, roundi(main.maine)])
			main.clock_min = 9 * 60
			var mk := main.money
			await at.call(main.world.rudus_gate)
			print("PO rudus: '%s'" % main._hint.text)
			await press.call("interact")
			print("PO keikka: rahaa +%s, kello %d:%02d" % [main._eur(main.money - mk), int(main.clock_min) / 60, int(main.clock_min) % 60])
			# Rossirata.
			var rg: Vector3 = main.world.rossi_gate
			await view.call("_rossi.png", rg + Vector3(-18, 12, 10), M.w(Vector2(100, -815)))
			main.walker_out.global_position = rg + Vector3(0, 0.3, 0)
			main.bike.global_position = rg + Vector3(0.5, 0.5, 0)
			await frames.call(5)
			main._toggle_mount()
			await frames.call(8)
			print("PO rossi: '%s'" % main._hint.text)
			await press.call("interact")
			for i in range(1, M.ROSSI.size()):
				main.bike.global_position = M.w(M.ROSSI[i]) + Vector3(0, 0.5, 0)
				await frames.call(6)
			main._rossi.t = 37.5
			main.bike.global_position = rg + Vector3(0, 0.5, 0)
			await frames.call(6)
			print("PO rossi maali: paras %s, voitto %s, '%s'" % [main._laptime(main._rossi_best), main._rossi_won, main._msg.text.left(60)])
			var j0: Array = main.world.rossi_jumps[0]
			print("PO hyppyrit %d, hop %s" % [main.world.rossi_jumps.size(), main.bike.has_method("hop")])
			var d := main.journal_data()
			print("PO tehtävät: %s" % [d.side.map(func(q): return "%s%s" % [q.title, "✔" if q.done else ""])])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"pedot":
			# Metsän pedot: karhu ja paikallaan seisominen (luopuu), karhu ja juoksu (raatelee, iso haava, eväät),
			# susi ja huuto kasvokkain (pakenee), Santun hoito, mökin metsän tunnistus. Kuva karhusta.
			if main.player == main.bike:
				main._toggle_mount()
			var spot := Vector3.INF
			var p0 := main.walker_out.global_position
			for r in range(40, 900, 20):
				for k in 24:
					var q := p0 + Vector3(cos(k * TAU / 24.0), 0, sin(k * TAU / 24.0)) * r
					var metsassa := true
					for d: Vector3 in [Vector3.ZERO, Vector3(30, 0, 0), Vector3(-30, 0, 0), Vector3(0, 0, 30), Vector3(0, 0, -30)]:
						if main.world.surface_at(q + d) != "forest":
							metsassa = false
							break
					if metsassa:
						spot = q
						break
				if spot != Vector3.INF:
					break
			print("PEDOT metsäpiste ", spot, " alusta ", main.world.surface_at(spot))
			main.walker_out.global_position = Vector3(spot.x, Terrain.h(spot.x, spot.z) + 0.3, spot.z)
			for i in 10:
				await main.get_tree().physics_frame
			var wait_phase := func(ph: String, limit: float) -> void:
				var t0 := Time.get_ticks_msec()
				while is_instance_valid(main._beast) and main._beast.phase != ph and Time.get_ticks_msec() - t0 < limit * 1000.0:
					await main.get_tree().physics_frame
			# 1) Karhu, seisotaan paikallaan.
			main._spawn_beast("karhu")
			await wait_phase.call("standoff", 20.0)
			print("PEDOT karhu kohtaus: etäisyys %.1f m viesti '%s'" % [main._beast.global_position.distance_to(main.walker_out.global_position), main._msg.text.replace("\n", " | ")])
			var oc := Camera3D.new()
			main.add_child(oc)
			oc.look_at_from_position(main.walker_out.global_position + Vector3(0, 2.2, 0) + (main.walker_out.global_position - main._beast.global_position).normalized() * 3.0,
				main._beast.global_position + Vector3(0, 1.0, 0), Vector3.UP)
			oc.current = true
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_karhu.png"))
			oc.queue_free()
			main.walker_out.activate_camera()
			await wait_phase.call("leave", 15.0)
			print("PEDOT karhu paikallaan: vaihe %s viesti '%s' haava %s" % [main._beast.phase if is_instance_valid(main._beast) else "-", main._msg.text, main.bitten])
			if is_instance_valid(main._beast):
				main._beast.queue_free()
			main._beast = null
			# 2) Karhu, juostaan karkuun.
			main.food["pulla"] = 2
			main.food["savukala"] = 1
			main.has_sausage = true
			main.bucket["mustikka"] = 3
			var k0: float = main.tilat.value("kipu")
			main._spawn_beast("karhu")
			await wait_phase.call("standoff", 20.0)
			Input.action_press("forward")
			Input.action_press("sprint")
			await wait_phase.call("leave", 10.0)
			Input.action_release("forward")
			Input.action_release("sprint")
			print("PEDOT karhu juoksu: haava %s iso %s kipu %.2f -> %.2f ontuu %.2f ruoat %s makkara %s ämpäri %s" % [main.bitten, main.wound_big,
				k0, main.tilat.value("kipu"), main.walker_out.hurt_speed, main.food, main.has_sausage, main.bucket])
			print("PEDOT viesti: ", main._msg.text.replace("\n", " | "))
			if is_instance_valid(main._beast):
				main._beast.queue_free()
			main._beast = null
			main._heal()
			for i in 120:
				await main.get_tree().physics_frame
			# 3) Susi, käännytään kohti ja huudetaan.
			main.food["savukala"] = 1
			main._spawn_beast("susi")
			await wait_phase.call("standoff", 20.0)
			print("PEDOT susi kohtaus: viesti '%s' hint '%s'" % [main._msg.text.replace("\n", " | "), main._hint.text])
			var wp: Vector3 = main._beast.global_position
			main.walker_out.look_at(Vector3(wp.x, main.walker_out.global_position.y, wp.z), Vector3.UP)
			await main.get_tree().process_frame
			Input.action_press("interact")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			print("PEDOT susi huuto: vaihe %s viesti '%s' haava %s" % [main._beast.phase if is_instance_valid(main._beast) else "-", main._msg.text, main.bitten])
			# 4) Santun hoito karhun haavaan.
			main.bitten = true
			main.wound_big = true
			main.walker_out.hurt = true
			main.walker_out.hurt_speed = Main.BEAR_HURT_SPEED
			print("PEDOT Santtu: haava %s iso %s ontuu %.2f viesti '%s'" % [main.bitten, main.wound_big, main.walker_out.hurt_speed, main._msg.text])
			# 5) Mökin metsä: osuus metsää mökin ympärillä.
			var n_forest := 0
			for k in 40:
					n_forest += 1
		"pitkalappu":
			# Pitkä lappu: kaikki päivän muistutukset kerralla; lapun pitää mahtua kokonaan ruudulle.
			var many := ["Laitoin 12,00 € kauppaa varten.", "Eilen ei tullu kaupasta mitään, vaikka oli lista!",
				Main.PAIVI_MORNING_SINIKKA[0], "Löysin sun kaljat eteisen kaapista ja kaadoin 6 viemäriin!",
				Main.LAWN_NAG_PAIVI[2], Main.LAWN_NAG_ANNALIISA[0], "Pyörä ei oo pihassa. Mihin sää sen taas jätit?",
				Main.HANGOVER_NOTE.paivi, Main.STAT_TIPS.paivi.vireys[0],
				Main.STAT_TIPS.paivi.stressi[1], Main.STAT_TIPS.paivi.keskittyminen[0]]
			main._day_note(Main.MORNING_HEAD.mokilta[0], "
".join(many))
			await main.get_tree().create_timer(1.2).timeout
			var rect: Rect2 = main._note._paper.get_global_rect()
			print("PITKALAPPU ruutu=%s lappu=%s asteikko=%s" % [main.get_viewport().get_visible_rect().size, rect, main._note._holder.scale])
		"omatjuomat":
			# Omat juomat Raahen baarissa: T-valikosta kaljaa, kunnes baarimikko varoittaa ja heittää ulos.
			main._toggle_mount()
			main.state = "cutscene"
			main._enter_raahe()
			main._raahe.paivi_t = -1.0
			main.raahe_int.walker.position = main.raahe_int.spots.tiski[0]
			main.beers = 12
			await main.get_tree().create_timer(0.8).timeout
			for k in 12:
				if main.state != "in_raahe" or not main.raahe_int.walker.controls_enabled:
					break
				await main.get_tree().process_frame
				Input.action_press("eat")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("eat")
				var open: bool = main._item_menu.is_open()
				main._item_menu.visible = false
				main._item_menu.chosen.emit("kalja")
				await main.get_tree().process_frame
				print("OMAT %d: valikko=%s kaljaa=%d varoitettu=%s viesti='%s'" % [k, open, main.beers, main._own_drink_warned, main._msg.text])
			await main.get_tree().create_timer(3.0).timeout
			print("OMAT loppu: tila=%s potkittu=%s" % [main.state, main._raahe.get("kicked", false)])
		"pojat":
			# Jalkapallopojat: tehtävä, pallon haku, palautus valikosta; sitten kalja ja väärä esine. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var press := func(action: String) -> void:
				await main.get_tree().process_frame  # painallus ennen solmujen _processia (just_pressed samassa ruudussa)
				Input.action_press(action)
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			main._toggle_mount()
			for round in ["pallo", "kalja", "makkara"]:
				if is_instance_valid(main.boys):
					main.boys.queue_free()
				main.day = 2
				main._spawn_boys()
				main.walker_out.global_position = main.boys.global_position + Vector3(2.5, 0.5, 0)
				for i in 10:
					await main.get_tree().physics_frame
				await main.get_tree().process_frame
				print("POJAT [%s] hint=%s" % [round, main._hint.text])
				await press.call("interact")
				main._test_talk(["pallo_kysy"])
				var bd: float = main.ball.global_position.distance_to(main.boys.global_position) if is_instance_valid(main.ball) else -1.0
				print("POJAT quest=%s ball_dist=%.0f msg=%s" % [main._ball_quest, bd, main._msg.text.replace("\n", " | ")])
				if round == "pallo":
					main.walker_out.global_position = main.ball.global_position + Vector3(0.8, 0.4, 0)
					for i in 10:
						await main.get_tree().physics_frame
					await main.get_tree().process_frame
					await press.call("interact")
					print("POJAT has_ball=%s hud_inv=%s" % [main.has_ball, "jalkapallo" in main._stats.text])
				elif round == "kalja":
					main.beers = 2
				else:
					main.has_sausage = true
					main.beers = 0
				main.walker_out.global_position = main.boys.global_position + Vector3(2.5, 0.5, 0)
				for i in 10:
					await main.get_tree().physics_frame
				await main.get_tree().process_frame
				var m0 := main.money
				var mor: float = main.tilat.value("moraali")
				var xp: float = main.tilat.value("kokemus")
				await press.call("interact")
				print("POJAT ikkuna=%s valinnat=%s" % [main._talk_box.is_open(), str(main._talk_box._options.map(func(o): return o.id))])
				if round == "pallo":
					for i in 5:
						await main.get_tree().process_frame
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_menu.png"))
					await main.get_tree().process_frame
				main._test_talk(["anna_" + round])  # ensimmäinen valinta voi olla Pörrö-tehtävä (lemmikki_kysy)
				for i in 30:
					await main.get_tree().process_frame
				print("POJAT gave -> mode=%s money %s -> %s moraali %+.2f kokemus %+.2f beers=%d msg=%s" % [
					main.boys.mode if is_instance_valid(main.boys) else "gone", main._eur(m0), main._eur(main.money), main.tilat.value("moraali") - mor,
					main.tilat.value("kokemus") - xp, main.beers, main._msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"pontikka":
			# Pannu-Sulo: kuva paikasta, kanisterin osto ja kotiinpaluu. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main._toggle_mount()
			var sp := main.sulo.global_position
			main.walker_out.global_position = sp + Vector3(2.0, 0.5, 2.5)
			main.walker_out.look_at(Vector3(sp.x, main.walker_out.global_position.y, sp.z))
			for i in 30:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("PONTIKKA hint=", main._hint.text, " money=", main._eur(main.money))
			var tc := Camera3D.new()
			main.add_child(tc)
			var still := M.w(M.PONTIKKA)
			tc.global_position = still + Vector3(4.5, 2.6, 5.0)
			tc.look_at(still + Vector3(-0.6, 0.6, 0), Vector3.UP)
			tc.current = true
			main._msg.text = ""
			for i in 5:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_still.png"))
			tc.queue_free()
			main.walker_out.activate_camera()
			await main.get_tree().process_frame
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			print("SULO ikkuna: %s" % str(main._talk_box._options.map(func(o): return o.text)))
			main._test_talk(["kanisteri"])
			print("BUY kanister=%s state=%s money=%s hint=%s" % [main.has_kanister, main.state, main._eur(main.money), main._hint.text])
			for i in 60:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_carry.png"))
			var cc := Camera3D.new()
			main.add_child(cc)
			var wp := main.walker_out.global_position
			cc.global_position = wp + main.walker_out.global_transform.basis * Vector3(-1.6, 0.9, -1.2)
			cc.look_at(wp + Vector3(0, 0.7, 0), Vector3.UP)
			cc.current = true
			main._msg.text = ""
			for i in 5:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_hand.png"))
			cc.queue_free()
			main.jemma = 3
			# Kanisteri piilotetaan itse eteisen kaappiin, sitten tyhjin käsin ovelle.
			await main._test_goto_stash("koti")
			print("STASH hint=", main._hint.text)
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			print("STASH kanister=%s jemma=%d msg=%s" % [main.has_kanister, main.jemma, main._msg.text.replace("\n", " | ")])
			main._on_home_exited()
			main.walker_out.global_position = main.home_zone + Vector3(0, 0.5, 0)
			for i in 3:
				await main.get_tree().physics_frame
				await main.get_tree().process_frame
			print("WIN kanister=%s jemma=%d endings=%d state=%s" % [main.has_kanister, main.jemma, main.jemma_endings, main.state])
			for i in 60:
				await main.get_tree().process_frame
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"pensasaita":
			# Pensasaidan leikkuu (3D, minäkuvakulma): rehottava aita ja trimmeri pihalla, sitten pelin vaiheet kuviksi:
			# alku johto aidan päällä, leikkuu silppuineen, kolo ja Päivi, johto poikki, teippaus, kyljet, valmis ja aita
			# leikattuna pelimaailmassa. Tallennus palautetaan.
			var saved_h := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var hshot := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			var hframes := func(n: int) -> void:
				for i in n:
					await main.get_tree().process_frame
			if main.player != main.walker_out:
				main._toggle_mount()
			main._hud.visible = false
			var hh: Node3D = main.world.home_hedge
			hh.grow(0.1)
			main._hedge_done_today = false
			var fwd := Vector3(-sin(main.world.hedge_yaw), 0, -cos(main.world.hedge_yaw))
			main.walker_out.global_position = main.world.hedge_spot - fwd * 3.0 + Vector3(0, 0.3, 0)
			main.walker_out.rotation.y = main.world.hedge_yaw
			main.walker_out.velocity = Vector3.ZERO
			await hframes.call(60)
			await hshot.call("piha")
			main._hud.visible = true
			main.walker_out.global_position = main.world.hedge_spot + Vector3(0, 0.3, 0)
			await hframes.call(5)
			print("PENSAS vihje '%s', rehotus %.2f" % [main._hint.text, hh.overgrowth()])
			Input.action_press("interact")
			await hframes.call(2)
			Input.action_release("interact")
			await hframes.call(10)
			var g: Node = main._hedge_game
			print("PENSAS peli auki %s" % [g != null])
			if g == null:
				main.get_tree().quit()
				return 2
			# Päivi vahtii itse leikkuuta: Hyundai ei saa pelaajaa kiinni aidan luota, vaikka jahti olisi päällä.
			var wf: Node3D = main.wife
			var w_save := [wf.global_position, wf.parked, wf.visible, wf.process_mode, wf.alerted, wf.mode]
			wf.reset_to(main.world.nearest_node(main.world.hedge_spot))
			wf.parked = false
			wf.visible = true
			wf.process_mode = Node.PROCESS_MODE_INHERIT
			wf.alerted = true
			wf.mode = "chase"
			for i in 180:
				await main.get_tree().physics_frame
			var w_d: float = Vector2(wf.global_position.x - main.player.global_position.x, wf.global_position.z - main.player.global_position.z).length()
			print("PENSAS Päivin auto %.1f m, turvassa %s, tila %s" % [w_d, wf.is_target_safe(), main.state])
			if not wf.is_target_safe() or main.state != "ulkona":
				print("TESTI VIKA Päivi otti kiinni pensasaidan leikkuussa")
			wf.global_position = w_save[0]
			wf.parked = w_save[1]
			wf.visible = w_save[2]
			wf.process_mode = w_save[3]
			wf.alerted = w_save[4]
			wf.mode = w_save[5]
			var aim := func(y: float) -> float:  # katseen kulma, jolla terä on korkeudella y
				return atan((y - g.EYE) / g.STAND)
			g._pitch = aim.call(1.75)
			await hframes.call(10)
			await hshot.call("alku")
			# Johto aidan päällä: oikea nappi nostaa sen pois.
			g._x = g._cord_x + 0.3
			g._pitch = aim.call(hh.top_at(g._cord_x) + 0.1)
			await hframes.call(6)
			await hshot.call("johto")
			g._x = g._cord_x
			g._pitch = aim.call(hh.top_at(g._cord_x))
			await hframes.call(3)
			g._lift_cord()
			await hframes.call(3)
			print("PENSAS johto nostettu pois: %s, Päivi '%s'" % [not g._cord_on, g._bubble.text])
			await hshot.call("johto_pois")
			# Kaksi vetoa: ensin pala latvasta, sitten narun tasalle; kävellään ja heilutetaan terää sivulta sivulle.
			for pass_y in [1.74, 1.62, 1.52]:
				g._lmb = true
				for f in 110:
					g._x = 8.6 - f * 0.03
					g._yaw = sin(f * 0.25) * 0.5
					g._pitch = aim.call(pass_y)
					await main.get_tree().process_frame
					if pass_y > 1.7 and f == 60:
						print("PENSAS silppua %d, lätsähdyksiä %d, fps %d" % [g._chip_data.size(), g._splat_data.size(), Engine.get_frames_per_second()])
						await hshot.call("leikkuu")
			g._lmb = false
			g._yaw = 0.0
			g._x = 6.2
			g._pitch = aim.call(1.6)
			await hframes.call(10)
			print("PENSAS tasalla %.2f, fps %d" % [hh.level_share(), Engine.get_frames_per_second()])
			await hshot.call("leikattu")
			# Kolo: terä narun alle, ja Päivi ajotien aukossa osoittaa.
			g._lmb = true
			g._x = 6.4
			for f in 14:
				g._pitch = aim.call(1.38)
				await main.get_tree().process_frame
			g._lmb = false
			g._yaw = 0.75
			g._pitch = aim.call(1.3)
			await hframes.call(8)
			print("PENSAS koloja %d, Päivi '%s'" % [g.holes, g._bubble.text])
			await hshot.call("kolo")
			# Johto takaisin aidan päälle ja terä siihen.
			g._cord_on = true
			g._cord_path(false)
			g._yaw = 0.0
			g._x = g._cord_x - 0.04
			g._lmb = true
			for f in 30:
				g._pitch = aim.call(hh.top_at(g._cord_x) - 0.03)
				await main.get_tree().process_frame
				if g._phase == "johto":
					break
			g._lmb = false
			await hframes.call(5)
			print("PENSAS vaihe %s, Päivi '%s'" % [g._phase, g._bubble.text])
			await hshot.call("johto_poikki")
			Input.action_press("interact")
			await main.get_tree().create_timer(0.9).timeout
			await hshot.call("teippaus")
			await main.get_tree().create_timer(1.0).timeout
			Input.action_release("interact")
			await hframes.call(3)
			print("PENSAS teipattu: vaihe %s, johto aidalla %s" % [g._phase, g._cord_on])
			# Latva valmiiksi koko aidalta, kylkiversot jäljellä.
			for i in hh.tops.size():
				if hh.tops[i] > 1.52:
					hh.tops[i] = 1.51
					hh.state[i] = 1
			for sh in hh.shoots:
				sh[1] = minf(sh[1], 1.51)
			hh.grow(0.0)
			var side: Array = hh.sides[0]
			g._x = side[0] + 0.5
			g._yaw = 0.3
			g._pitch = aim.call(side[1]) - 0.15
			await hframes.call(6)
			print("PENSAS kyljet %d" % hh.sides_left())
			await hshot.call("kyljet")
			g._yaw = 0.0
			g._lmb = true
			for sd in hh.sides:
				g._x = sd[0] - 0.04
				for f in 3:
					g._pitch = aim.call(sd[1])
					await main.get_tree().process_frame
			g._lmb = true
			g._pitch = aim.call(1.51)
			await hframes.call(3)
			g._lmb = false
			await hframes.call(20)
			# Valmis aita voi lopettaa minipelin jo ennen tätä (hitaalla koneella ruudut ovat pitkiä): peli on silloin vapautettu.
			print("PENSAS vaihe %s, kyljet %d, latva ok %s, tasalla %.2f, koloja %s, Päivi '%s'" % [g._phase if is_instance_valid(g) else "ohi",
				hh.sides_left(), hh.shoots_ok(), hh.level_share(), str(g.holes) if is_instance_valid(g) else "-",
				g._bubble.text if is_instance_valid(g) else ""])
			await hshot.call("valmis")
			await main.get_tree().create_timer(3.6).timeout
			print("PENSAS Päivin armonaika leikkuun jälkeen %.1f s" % main.wife.grace)
			if main._hedge_game == null and main.wife.grace <= 0.0:
				print("TESTI VIKA Päivin auto jahtaa heti leikkuun jälkeen")
			print("PENSAS loppu: peli %s, rehotus %.2f, kehu %s, viesti '%s'" % [main._hedge_game, hh.overgrowth(), main._hedge_praise, main._msg.text.replace("\n", " | ")])
			main._hud.visible = false
			main.walker_out.global_position = main.world.hedge_spot - fwd * 3.0 + Vector3(0, 0.3, 0)
			await hframes.call(30)
			await hshot.call("loppu")
			# Häviö kesken leikkuun (esim. Päivi nappaa ennen turvapaikkaa): minipeli ja sen päätön pelaajahahmo pois.
			hh.grow(0.1)
			main._hedge_done_today = false
			main.walker_out.global_position = main.world.hedge_spot + Vector3(0, 0.3, 0)
			main._start_hedge()
			await hframes.call(10)
			var g2: Node = main._hedge_game
			main._lose("Päivi nappasi kiinni!", "wife")
			await hframes.call(5)
			var left_games := 0
			for ch in hh.get_children():
				if ch.get_script() == main.HedgeGame:
					left_games += 1
			print("PENSAS häviö kesken: peli %s, vanha poistettu %s, aidalla minipelejä %d" % [main._hedge_game, not is_instance_valid(g2) or g2.is_queued_for_deletion(), left_games])
			if main._hedge_game != null or (is_instance_valid(g2) and not g2.is_queued_for_deletion()):
				print("TESTI VIKA pensasaidan minipeli jäi päälle häviön jälkeen")
			for i in 600:  # välianimaatio ja uusi päivä läpi
				await main.get_tree().process_frame
				if main.state == "ulkona":
					break
			await hframes.call(30)
			print("PENSAS uusi päivä: tila %s, pelaaja näkyy %s" % [main.state, main.walker_out.visible])
			main._hud.visible = false
			await hshot.call("havion_jalkeen")
			if not saved_h.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_h)
		_:
			return 0
	return 1
