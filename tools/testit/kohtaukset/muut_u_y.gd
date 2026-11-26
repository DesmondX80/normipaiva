extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "muut_u_y". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const B := preload("res://scripts/build.gd")
const ShopInterior := preload("res://scripts/shop_interior.gd")
const BarGame := preload("res://scripts/bar_game.gd")
const Looks := preload("res://scripts/looks.gd")
const HomeInterior := preload("res://scripts/home_interior.gd")
const GarageInterior := preload("res://scripts/garage_interior.gd")
const WanharaaheLegenda := preload("res://scripts/wanharaahe_legenda.gd")
const VanhaherraLegenda := preload("res://scripts/vanhaherra_legenda.gd")
const SukellusGame := preload("res://scripts/sukellus_game.gd")
const WcGame := preload("res://scripts/wc_game.gd")

const KOHTAUKSET := ["wife", "vaanto", "yo", "vaatekaappi", "viini", "uutiset_kuva", "vanhaherra", "wanharaahe", "uutiset_sohva", "vihjeet", "vessa", "valiajat", "wasted", "vaino"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"wife":
			main.player.position = main.wife.position + Vector3(0, 0.3, 14)
			main.player.rotation.y = PI
		"vaanto":
			# Kädenvääntö suoraan (ilman taksimatkaa): pelin kamera kolmessa kulmassa, sivukuva, takaa ja kourat.
			main._hud.visible = false
			var vb := BarGame.new()
			vb.position = Main.BAR_POS
			main.add_child(vb)
			vb._phase = "test"
			var vsnap := func(name: String) -> void:
				for i in 12:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			for ang in [0.0, 0.7, -0.7]:
				vb._angle = ang
				await vsnap.call("_%s.png" % str(ang))
			var sc := Camera3D.new()
			sc.fov = 45.0
			vb.add_child(sc)
			sc.look_at_from_position(vb.to_global(Vector3(1.7, 1.25, 0.1)), vb.to_global(Vector3(0, 0.95, 0.1)))
			sc.current = true
			vb._angle = 0.0
			await vsnap.call("_sivu.png")
			sc.look_at_from_position(vb.to_global(Vector3(-0.9, 1.5, 1.6)), vb.to_global(Vector3(0, 0.95, 0.1)))
			await vsnap.call("_taka.png")
			# Kourat läheltä: pelaajan kämmenselän puolelta (+x), Teron kämmenselän puolelta (-x) ja ylhäältä.
			# Lisäksi pelin kameran suunnasta suurennettuna.
			var grip_c := vb.to_global(Vector3(0, vb.TABLE_Y + 0.36, 0))
			sc.near = 0.02
			sc.look_at_from_position(grip_c + (vb._cam.global_position - grip_c).normalized() * 0.35, grip_c)
			await vsnap.call("_kourat_peli.png")
			for v in [["_kourat.png", Vector3(0.28, 0.04, 0.05)], ["_kourat2.png", Vector3(-0.28, 0.04, -0.05)],
					["_kourat3.png", Vector3(0.05, 0.3, 0.02)]]:
				sc.look_at_from_position(grip_c + v[1], grip_c, Vector3.FORWARD if v[0] == "_kourat3.png" else Vector3.UP)
				await vsnap.call(v[0])
			main.get_tree().quit()
		"yo":
			# Yön raja: ilta-ilmoitus klo 22, raja klo 2, kahvi ja viina siirtävät (enintään klo 4), sammuminen ulkona,
			# kotona ja mökillä.
			if main.player == main.bike:
				main._toggle_mount()
			var run := func(label: String, start: float, coffee: int, humala: float, home := false) -> void:
				main._new_day(main.home_zone + Vector3(0, 0, 4), false)
				await main.get_tree().process_frame
				if home:
					main._enter_home("ovi")
				main._msg_queue.clear()
				main.clock_min = start
				main._night_coffee = coffee
				if humala > 0.0:
					main.tilat.ensure("humala")
					main.tilat.add("humala", humala)
				for i in 3:
					await main.get_tree().process_frame
				var lim := main._pass_out_text()
				var d0 := main.day
				var last := main.clock_min
				var t0 := Time.get_ticks_msec()
				while main.day == d0 and Time.get_ticks_msec() - t0 < 60000:
					last = main.clock_min
					main.clock_min = fmod(main.clock_min + 1.0, 1440.0)  # kelataan minuutti ruudussa
					await main.get_tree().process_frame
				print("YO %s: raja klo %s, sammui klo %d.%02d, herätys klo %s, kotipihalla %s, viesti '%s'" % [label, lim,
					int(last) / 60, int(last) % 60, main._clock_text(), main.walker_out.global_position.distance_to(main.home_zone) < 10.0,
					str(main._msg_queue.map(func(m): return m[0])).left(200)])
			main.clock_min = 21.0 * 60.0 + 59.0
			main._night_warned = 0
			for i in 5:
				await main.get_tree().process_frame
			main.clock_min = 22.0 * 60.0 + 1.0
			for i in 5:
				await main.get_tree().process_frame
			print("YO ilta: varoitettu %d, jono %s" % [main._night_warned, str(main._msg_queue).left(140)])
			await run.call("ulkona selvänä", 1.0 * 60.0 + 50.0, 0, 0.0)
			await run.call("kaksi kahvia", 2.0 * 60.0 + 30.0, 2, 0.0)
			await run.call("kahvit ja viina", 3.0 * 60.0 + 40.0, 3, 0.8)
			await run.call("kotona", 1.0 * 60.0 + 55.0, 0, 0.0, true)
		"vaatekaappi":
			# Vaatekaappi kotona (farkut) ja asun vaihto kaikkiin pelaajan malleihin; kuva pyörällä pihalla.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(name: String) -> void:
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main._note.visible = false
			if main.player != main.walker_out:
				main._toggle_mount()
			main._enter_home("ovi")
			main.home_int.walker.position = main.home_int.SPOTS.vaatekaappi[0]
			for i in 5:
				await main.get_tree().process_frame
			print("KAAPPI vihje '%s'" % main._hint.text)
			await main.get_tree().process_frame
			Input.action_press("interact")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			print("KAAPPI valikko auki %s, tila %s, valinnat %s" % [main._item_menu.is_open(), main._menu_mode, main._item_menu._items])
			await snap.call("_valikko.png")
			main._item_menu.chosen.emit("farkut")
			var bodies := main.get_tree().root.find_children("*", "Node3D", true, false).filter(func(n): return n.has_meta("player_body"))
			print("KAAPPI asu %s, pelaajan malleja %d, viesti '%s'" % [Looks.outfit, bodies.size(), main._msg.text])
			await snap.call("_koti.png")
			main.home_int.exit_door = "ovi"
			main._on_home_exited()
			if main.player == main.walker_out:
				main._toggle_mount()
			for i in 30:
				await main.get_tree().process_frame
			await snap.call("_pyora.png")
			# Raahen vaatekaappi: työvaatteet ja Karjala-lippis.
			for i in 5:
				await main.get_tree().process_frame
			print("KAAPPI Raahe vihje '%s'" % main._hint.text)
			Input.action_press("interact")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			print("KAAPPI Raahe valinnat %s" % [main._item_menu._items])
			main._item_menu.visible = false
			main._item_menu.chosen.emit("tyovaatteet")
			print("KAAPPI Raahe asu %s, viesti '%s'" % [Looks.outfit, main._msg.text])
			await snap.call("_paapeli.png")
			Looks.outfit = "tuulipuku"
			var f := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f.store_buffer(saved)
			f.close()
			main.get_tree().quit()
		"viini":
			# Kotiviini: kaupan hylly, hiiva jääkaapista, sokeri keittiön kaapista, saaviin, 21 päivää, viinibileet,
			# takaumat ja herätys naapurista krapulassa, lukitus.
			if main.player == main.bike:
				main._toggle_mount()
			main.wine_locked = false
			main.wine_start = -1
			main.has_yeast = false
			main.has_turbo = false
			main.has_sugar = false
			main.bucket = {"mustikka": 2, "puolukka": 2}
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
				for i in 3:
					await main.get_tree().process_frame
			main._enter_shop()
			main.interior.walker.position = ShopInterior.BREW_SPOT
			await frames.call(5)
			print("VIINI kauppa: hint '%s'" % main._hint.text)
			await press.call("interact")
			await press.call("interact")
			print("VIINI kauppa kori: %s" % [main.interior.cart])
			main.interior.cart.clear()
			main._on_shop_exited(false)
			await frames.call(5)
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			await frames.call(3)
			main._enter_home("ovi")
			main.home_int.walker.position = HomeInterior.SPOTS.jaakaappi[0]
			await frames.call(5)
			await press.call("interact")
			main.home_int.walker.position = HomeInterior.SPOTS.sokeri[0]
			await frames.call(5)
			print("VIINI keittiön kaappi: hint '%s'" % main._hint.text)
			await press.call("interact")
			print("VIINI kotoa: hiiva %s sokeri %s viesti '%s'" % [main.has_yeast, main.has_sugar, main._msg.text])
			main._on_home_exited()
			await frames.call(3)
			main.walker_out.global_position = main.world.garage_door + Vector3(0, 0.3, 0)
			await frames.call(3)
			main._enter_garage()
			main.garage_int.walker.position = GarageInterior.SPOTS.saavi[0]
			await frames.call(5)
			print("VIINI saavilla: hint '%s'" % main._hint.text)
			await main._test_fill_vat()
			print("VIINI käymään: alku %d päiviä %d marjat %s hiiva %s sokeri %s" % [main.wine_start, main.wine_days, main.bucket, main.has_yeast, main.has_sugar])
			await frames.call(30)
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_saavi.png"))
			main.day += 21
			main.garage_int.set_wine(main._wine_stage())
			await frames.call(3)
			print("VIINI 21 pv: hint '%s'" % main._hint.text)
			await press.call("interact")
			print("VIINI bileet: tila %s lukossa %s" % [main.state, main.wine_locked])
			for t in [5.0, 6.0, 7.0]:
				await main.get_tree().create_timer(t, true, false, true).timeout
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_bileet%d.png" % int(t)))
			for i in 40:
				await main.get_tree().create_timer(0.5, true, false, true).timeout
				if not main.cutscene.busy:
					break
			await main.get_tree().create_timer(1.5, true, false, true).timeout
			var near := ""
			for k in Main.WINE_WAKE:
				if main.walker_out.global_position.distance_to(main.world.neighbor_yards[k][0]) < 3.0:
					near = k
			print("VIINI herätys: tila %s naapuri '%s' vireys %.2f keskittyminen %.2f viesti '%s'" % [main.state, near,
				main.tilat.value("vireys"), main.tilat.value("keskittyminen"), main._msg.text.replace("\n", " | ")])
			print("VIINI jono: ", str(main._msg_queue).left(300))
			main.walker_out.global_position = main.world.garage_door + Vector3(0, 0.3, 0)
			await frames.call(3)
			main._enter_garage()
			main.garage_int.walker.position = GarageInterior.SPOTS.saavi[0]
			await frames.call(5)
			print("VIINI lukossa: hint '%s'" % main._hint.text)
			main._on_garage_exited(false)
			var promised := main.wine_lock_day
			for i in Main.WINE_LOCK_DAYS:
				main._new_day(main.home_door, false)
				print("VIINI päivä %d lupauksesta: lukossa %s" % [main.day - promised, main.wine_locked])
			print("VIINI unohtui: aamuviesti %s" % (str(main._msg_queue) + main._msg.text).contains("viinilupaus"))
		"uutiset_kuva":
			# Jaettava kuva Kymppiuutisten lopusta: sankari sohvalla, tölkki käsinojalla ja studio telkkarissa.
			main.cutscene.news_tape("", func() -> void: pass)
			while main.cutscene.news_view == null or main.cutscene.news_view.seg != "studio":
				await main.get_tree().process_frame
			await main.get_tree().create_timer(1.2, true, false, true).timeout
			main.cutscene._layer.visible = false
			var shot_cam := Camera3D.new()
			shot_cam.fov = 42.0
			main.cutscene.add_child(shot_cam)
			var r: Vector3 = main.cutscene.TV_ROOM
			shot_cam.fov = 44.0
			shot_cam.look_at_from_position(r + Vector3(2.3, 1.45, 3.05), r + Vector3(0.15, 0.85, -0.9), Vector3.UP)
			shot_cam.current = true
			var news: SubViewport = main.cutscene.news_view
			news.seg = "studio"
			news.headline = "Kaljan hinta nousee taas"
			news.talk = true
			# Iltatunnelma: ympäristövalo himmeäksi ilman taivasta, huonetta valaisevat telkkarin hehku ja jalkalamppu.
			var e: Environment = main.cutscene.env
			e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			e.ambient_light_color = Color(0.35, 0.4, 0.6)
			e.ambient_light_energy = 0.35
			e.fog_enabled = false
			main._sun.visible = false
			main._hud.visible = false
			main._note.visible = false
			main._msg.text = ""
			for i in 20:
				news.seg = "studio"  # kohtaus etenee taustalla: ruutu pidetään studiossa
				main.cutscene._layer.visible = false
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kuva.png"))
			# Sama kuva loppukohtauksen otsikkopalkilla ja onnellisen lopun tekstillä (ilman elokuvapalkkeja).
			main.cutscene._layer.visible = true
			main.cutscene._layout_bars(0.0)
			main.cutscene._fade.color.a = 0.0
			main.cutscene._band.visible = true
			main.cutscene._title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			main.cutscene._title.add_theme_font_size_override("font_size", 64)
			var vs := main.get_viewport().get_visible_rect().size  # palkki alakolmannekseen, ettei peitä telkkaria
			main.cutscene._band.position = Vector2(0, vs.y * 0.74)
			main.cutscene._band.size = Vector2(vs.x, vs.y * 0.2)
			main.cutscene._title.position = Vector2(0, vs.y * 0.73)
			main.cutscene._title.size = Vector2(vs.x, vs.y * 0.13)
			main.cutscene._sub.position = Vector2(vs.x * 0.05, vs.y * 0.84)
			main.cutscene._sub.size = Vector2(vs.x * 0.9, vs.y * 0.09)
			main.cutscene._title.text = "KYMPPIUUTISET NAUHALTA"
			for i in 10:
				news.seg = "studio"
				main.cutscene._title.text = "KYMPPIUUTISET NAUHALTA"
				main.cutscene._sub.text = "ONNELLINEN LOPPU  ·  Video ajastettu, kalja eteisen kaapista ja sohvalle. Päivi nukkuu jo."
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kuva_teksti.png"))
		"vanhaherra":
			# Vanha herra (#250 P11): taksivalinta, vitriini, pumppaaja, sukellus (A/D-pumppaus, kaivaus), tallennus; kuvat.
			main._note.visible = false
			var vh_shot := func(name: String) -> void:
				for i in 4:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.vanhaherra = VanhaherraLegenda.new()
			main.mielihyva = 50.0
			print("VH taksivalinta: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "retki_vanhaherra").map(func(o): return [o.id, o.enabled, o.text])])
			main._retki_from = main.player.global_position
			main._enter_retki("vanhaherra")
			print("VH perillä: state %s, tehtävät %s" % [main.state, main._vanhaherra_tasks()])
			await vh_shot.call("alue")
			main._vanhaherra_acted("vitriini")
			main._vanhaherra_acted("pumppaaja")
			print("VH puhuttu %s, tehtävät %s" % [main.vanhaherra.puhuttu, main._vanhaherra_tasks()])
			main._start_sukellus()
			var vh_g: Node = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == SukellusGame)[0]
			print("VH minipeli auki %s, state %s" % [main._minigame_open(), main.state])
			var vh_keys := ["a", "d"]
			for i in 40:
				vh_g._pump(vh_keys[i % 2])
				await main.get_tree().create_timer(0.4).timeout
				if i == 12:
					await vh_shot.call("sukellus")
			await vh_shot.call("sukellus2")
			vh_g._end(false)
			await main.get_tree().process_frame
			print("VH Esc: state %s, sukelluksia %d, minipeli auki %s" % [main.state, main.vanhaherra.sukelluksia, main._minigame_open()])
			main.get_tree().quit()
		"wanharaahe":
			# Wanha Raahe (#250 P8): viisi pysähdystä järjestyksessä, kuvan tarkistus katseen mukaan, ovikuva Päiville (kerran); tallennus; kuvat.
			main._note.visible = false
			var wr_shot := func(name: String) -> void:
				for i in 3:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.wanharaahe = WanharaaheLegenda.new()
			main.mielihyva = 50.0
			print("WR taksivalinta: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "retki_wanharaahe").map(func(o): return [o.id, o.enabled, o.text])])
			var wr_t0 := main.clock_min
			main._retki_from = main.player.global_position
			main._enter_retki("wanharaahe")
			print("WR perillä: state %s, kello +%.0f min, pysähdyksiä %d" % [main.state, main.clock_min - wr_t0, main.retki_int.STOPS.size()])
			await wr_shot.call("alue")
			var wr_cam := main.get_viewport().get_camera_3d()
			var wr_close := func(name: String, from: Vector3, to: Vector3, fov := 45.0) -> void:
				var c := Camera3D.new()
				c.fov = fov
				main.retki_int.add_child(c)
				c.look_at_from_position(main.retki_int.global_position + from, main.retki_int.global_position + to)
				c.current = true
				main._hud.visible = false
				await wr_shot.call(name)
				main._hud.visible = true
				wr_cam.make_current()
				c.queue_free()
			# Väärä järjestys ja väärä katse eivät ota kuvaa.
			main.retki_int.walker.position = main.retki_int.spots.ovet[0]
			main.retki_int.press("ovet")
			print("WR väärä järjestys: kuvia %d, viesti '%s'" % [main.wanharaahe.kuvat.size(), main.retki_int.note])
			main.retki_int.walker.position = main.retki_int.spots.patsas[0]
			main.retki_int.walker.rotation.y = B.yaw_to(Vector3(1, 0, 0))
			main.retki_int.press("patsas")
			print("WR väärä katse: kuvia %d, osuu %s, viesti '%s'" % [main.wanharaahe.kuvat.size(), main.retki_int.photo_hits("patsas"), main.retki_int.note])
			for id in ["patsas", "ovet", "kauppiaantalo", "kuja", "makasiini"]:
				main.retki_int.walker.position = main.retki_int.spots[id][0]
				var wr_dir: Vector3 = main.retki_int.STOPS[id].target - main.retki_int.spots[id][0]
				main.retki_int.walker.rotation.y = B.yaw_to(Vector3(wr_dir.x, 0, wr_dir.z))
				for i in 3:
					await main.get_tree().process_frame
				print("WR %s: spot '%s', vihje '%s', osuu %s" % [id, main.retki_int.spot, main._hint.text, main.retki_int.photo_hits(id)])
				await wr_shot.call("peli_" + id)
				if id == "makasiini":
					var wr_m0 := main.maine
					main.retki_int.press(id)
					print("WR makasiini (viimeinen): maine %.0f -> %.0f" % [wr_m0, main.maine])
				else:
					main.retki_int.press(id)
				if id == "ovet":
					print("WR ovikuva taskussa %s, tehtävät %s" % [main.wanharaahe.ovikuva, main._wanharaahe_tasks()])
			print("WR kierros: kuvat %s, valmis %s, päiväkirja %s" % [main.wanharaahe.kuvat, main.wanharaahe.valmis, main._wanharaahe_tasks()])
			main.retki_int.press("patsas")
			print("WR uusinta: kuvia %d, viesti '%s'" % [main.wanharaahe.kuvat.size(), main.retki_int.note])
			await wr_close.call("patsas_edesta", Vector3(-9.0, 3.2, 3.2), Vector3(-9.0, 2.4, -1.8))
			await wr_close.call("patsas_sivusta", Vector3(-5.2, 3.0, -0.8), Vector3(-9.0, 2.7, -1.8))
			await wr_close.call("patsas_ylhaalta", Vector3(-9.0, 9.0, 1.0), Vector3(-9.0, 1.0, -1.8))
			await wr_close.call("ovet", Vector3(1.0, 1.9, -0.6), Vector3(1.0, 1.4, -4.6))
			await wr_close.call("ovet_vino", Vector3(3.8, 2.2, -1.5), Vector3(1.0, 1.3, -4.6))
			await wr_close.call("talorivi", Vector3(8.0, 3.0, 9.0), Vector3(8.0, 2.2, -4.6), 60.0)
			await wr_close.call("kauppiaantalo", Vector3(13.9, 3.0, 4.5), Vector3(13.9, 2.8, -4.6))
			await wr_close.call("kuja_makasiini", Vector3(20.0, 2.6, 3.5), Vector3(20.5, 1.8, -5.0))
			await wr_close.call("makasiini", Vector3(22.2, 2.0, 3.5), Vector3(22.2, 1.8, -4.6))
			await wr_close.call("ylhaalta", Vector3(3.0, 40.0, 4.0), Vector3(3.0, 0.0, 0.0), 60.0)
			var wr_m1 := main.mielihyva
			main._give_ovikuva()
			print("WR Päivi: mielihyvä %.0f -> %.0f, ovikuva %s, annettu %s" % [wr_m1, main.mielihyva, main.wanharaahe.ovikuva, main.wanharaahe.annettu])
			var wr_cfg := ConfigFile.new()
			main.wanharaahe.save_to(wr_cfg)
			var wr_l: RefCounted = WanharaaheLegenda.new()
			wr_l.load_from(wr_cfg)
			print("WR tallennus: kuvat %s ovikuva %s annettu %s valmis %s" % [wr_l.kuvat, wr_l.ovikuva, wr_l.annettu, wr_l.valmis])
			main._on_retki_exited()
			await main.get_tree().create_timer(14.0).timeout
			print("WR takaisin: state %s, etäisyys lähtöpaikasta %.2f m, kello +%.0f min" % [main.state, main.player.global_position.distance_to(main._retki_from), fposmod(main.clock_min - wr_t0, 1440.0)])
			main.get_tree().quit()
		"uutiset_sohva":
			# Kymppiuutisten loppukohtaus: sankari sohvalla lähikuvina edestä, sivulta, takaa ja ylhäältä.
			main.cutscene.news_tape("testi", func() -> void: pass)
			while main.cutscene.news_hero == null:
				await main.get_tree().process_frame
			await main.get_tree().create_timer(1.2, true, false, true).timeout
			var cam := Camera3D.new()
			cam.fov = 40.0
			main.cutscene.add_child(cam)
			var o: Vector3 = main.cutscene.TV_ROOM + main.cutscene.SOFA_SIT + Vector3(0, 0.55, 0)
			var hero: Node3D = main.cutscene.news_hero
			var sk: Skeleton3D = hero.skeleton
			for bi in sk.get_bone_count():
				var bn := sk.get_bone_name(bi)
				if bn in ["pelvis", "spine_03", "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "hand_r", "middle_01_r"]:
					print("SOHVA luu %s %s" % [bn, hero.to_global(hero.bone_position(bn)) - main.cutscene.TV_ROOM])
			main.cutscene._layer.visible = false  # tekstit ja palkit pois lähikuvista
			for k in [["alku", Vector3(0, 0.4, -2.6)], ["kasi_sivu", Vector3(1.4, 0.15, -0.1)], ["kasi_edesta", Vector3(0.15, 0.35, -1.5)],
					["kasi_ylhaalta", Vector3(0.1, 1.4, -0.5)], ["edesta", Vector3(0, 0.4, -2.6)], ["sivulta", Vector3(-1.0, 0.1, -0.3)],
					["vino", Vector3(1.8, 0.6, -1.8)], ["ylhaalta", Vector3(0.01, 2.4, -0.3)], ["tyhja", Vector3(1.2, 0.5, -1.4)]]:
				if not is_instance_valid(hero) or not is_instance_valid(cam):
					print("SOHVA välikuva loppui ennen kuvaa %s (hidas kone)" % k[0])
					break
				hero.visible = k[0] != "tyhja"  # tyhjässä kuvassa sohvan painumat ilman istujaa
				cam.fov = 40.0
				cam.look_at_from_position(o + k[1], o, Vector3.UP)
				if k[0].begins_with("kasi"):  # lähikuva oikeasta kädestä ja käsinojan tölkistä
					var hp: Vector3 = (hero.to_global(hero.bone_position("hand_r")) + main.cutscene.TV_ROOM + main.cutscene.SOFA_CAN) / 2.0
					cam.fov = 25.0
					cam.look_at_from_position(hp + k[1], hp, Vector3.UP)
				cam.current = true
				main._note.visible = false
				main._msg.text = ""
				for i in 12:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % k[0]))
		"vihjeet":
			# Vihjepalkki (hint_bar.gd): kaupan grilli, ovi maksamatta, jono ja kotijemma.
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			main._note._holder.modulate.a = 0.0  # lappu kiinni: palkki keskelle
			var snap := func(name: String) -> void:
				main._msg.text = ""
				main._msg_queue.clear()
				for i in 15:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
				print("VIHJEET %s: '%s'" % [name, main._hint.text.replace("
", " | ")])
			main._toggle_mount()
			main.bike.global_position = main.shop_door + (main.shop_zone - main.shop_door).normalized() * 1.0 + Vector3(0, 0.5, 0)
			main.bike.velocity = Vector3.ZERO
			for i in 10:
				await main.get_tree().physics_frame
			await snap.call("_pyora.png")
			main._toggle_mount()
			main.money = 9.0
			main._enter_shop()
			main.interior.cart["makkara"] = 3.5
			main.interior.walker.set_carrying(true)
			main.interior.walker.position = main.interior.GRILL_SPOT
			await snap.call("_grilli.png")
			main.interior.walker.position = main.interior.DOOR
			await snap.call("_ovi.png")
			main.interior.walker.position = main.interior.QUEUE_FRONT + main.interior.QUEUE_STEP * 3
			await snap.call("_jono.png")
			main.interior.cart.clear()
			main.interior.has_paid = true
			main.interior.exited.emit(false)
			await main.get_tree().process_frame
			if main.player == main.bike:
				main._toggle_mount()
			main.beers = 6
			main.walker_out.set_carrying(true)
			await main._test_goto_stash("koti")
			await snap.call("_jemma.png")
		"vessa":
			# Kodin WC: ykkönen ja kakkonen (ponnistus vihreällä, 5 arkkia).
			main._toggle_mount()
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			# Pöntöllä: valikko auki, valinta (ykkönen = 1. rivi, kakkonen = 2.), minipeli pelataan läpi.
			var play := func(choice: int, sheets: int) -> void:
				print("VESSA valikko auki %s, kysymys '%s'" % [main._item_menu.is_open(), main._item_menu._title.text])
				if choice == 2:
					await press.call("back")
				await press.call("interact")
				var g: CanvasLayer = main._wc_game
				if g.mode == "ykkonen":
					var guard := 0
					while is_instance_valid(g) and guard < 3000:
						guard += 1
						var aim: Vector2 = g._aim
						Input.action_release("left")
						Input.action_release("right")
						Input.action_release("forward")
						Input.action_release("back")
						if aim.x > 8.0:
							Input.action_press("left", clampf(aim.x / 60.0, 0.2, 1.0))
						elif aim.x < -8.0:
							Input.action_press("right", clampf(-aim.x / 60.0, 0.2, 1.0))
						if aim.y > 8.0:
							Input.action_press("forward", clampf(aim.y / 60.0, 0.2, 1.0))
						elif aim.y < -8.0:
							Input.action_press("back", clampf(-aim.y / 60.0, 0.2, 1.0))
						await main.get_tree().process_frame
					for a2 in ["left", "right", "forward", "back"]:
						Input.action_release(a2)
				else:
					# Testi tarkistaa kulun (ponnistukset, arkit, tukos), ei ajoitusta: neula pysäytetään vihreälle ennen
					# painallusta. Neulaa odottamalla hidas kone (iso delta) hyppäsi vihreän yli ja ajo jumittui aikarajaan.
					var guard := 0
					while is_instance_valid(g) and g._phase == "push" and guard < 50:
						guard += 1
						g._needle = (WcGame.GREEN.x + WcGame.GREEN.y) / 2.0
						g._needle_speed = 0.0
						await press.call("interact")
					for k in sheets:
						await press.call("interact")
					await press.call("brake")
				for i in 5:
					await main.get_tree().process_frame
				print("VESSA tulos: '%s'" % main._msg.text.replace("\n", " | "))
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			for i in 10:
				await main.get_tree().physics_frame
			await press.call("interact")
			main.home_int.walker.position = main.home_int.SPOTS.wc[0]
			for i in 5:
				await main.get_tree().physics_frame
			print("VESSA koti: '%s'" % main.home_int.hint)
			await press.call("interact")
			await play.call(1, 0)
			await press.call("interact")
			await play.call(2, 5)
			print("VESSA kävelijä liikkuu %s, kiireinen %s" % [main.home_int.walker.controls_enabled, main.home_int.busy])
		"valiajat":
			# Välianimaatioiden repliikkikohdat: kunkin kesto tulostetaan (VALIAJAT <nimi> <s>), ja repliikkien äänien
			# pituus + 0,6 s on mahduttava siihen (cutscene.gd _say_wait). Vain Päivin repliikkejä sisältävät välianimaatiot.
			var cs_flag := [false]
			var done_cb := func() -> void: cs_flag[0] = true
			var runs := {
				"telkkari": func() -> void: main.cutscene.paivi_tv(ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGB8)), done_cb),
			}
			for nm: String in runs:
				cs_flag[0] = false
				var tv0 := Time.get_ticks_msec()
				runs[nm].call()
				while not cs_flag[0] and Time.get_ticks_msec() - tv0 < 120000:
					await main.get_tree().process_frame
				print("VALIAJAT %s %.1f s" % [nm, (Time.get_ticks_msec() - tv0) / 1000.0])
		"wasted":
			for i in 20:
				await main.get_tree().process_frame
			main._lose("Päivi nappasi kiinni!", "wife")
			for i in 60:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_1.png"))
			for i in 210:
				await main.get_tree().process_frame
		"vaino":
			# Väinö karkaa, pelaaja hiipii nuuhkivan koiran viereen, ottaa kiinni ja palauttaa Pekalle.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main._toggle_mount()
			main._vaino_at = main.clock_min
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			var mi: MeshInstance3D = main.vaino.find_children("*", "MeshInstance3D", true, false)[0]
			var ab := mi.global_transform * mi.get_aabb()
			print("VAINO escaped mode=%s aabb size=%s msg=%s" % [main.vaino.mode, ab.size, main._msg.text.replace("\n", " | ")])
			for i in 1800:
				await main.get_tree().physics_frame
				if main.vaino.mode == "sniff":
					break
			print("VAINO after bolt mode=%s d_home=%.1f" % [main.vaino.mode, main.vaino.global_position.distance_to(main.vaino.home)])
			main.walker_out.global_position = main.vaino.global_position + main.vaino.global_transform.basis.x * 1.8 + Vector3(0, 0.5, 0)
			main.walker_out.look_at(Vector3(main.vaino.global_position.x, main.walker_out.global_position.y, main.vaino.global_position.z))
			for i in 5:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			var vc := Camera3D.new()
			main.add_child(vc)
			vc.global_position = main.vaino.global_position + Vector3(2.2, 1.2, 2.2)
			vc.look_at(main.vaino.global_position + Vector3(0, 0.35, 0), Vector3.UP)
			vc.current = true
			main._msg.text = ""
			for i in 3:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_dog.png"))
			vc.queue_free()
			main.walker_out.activate_camera()
			await main.get_tree().process_frame
			print("VAINO near hint=%s mode=%s" % [main._hint.text, main.vaino.mode])
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			print("VAINO caught mode=%s msg=%s" % [main.vaino.mode, main._msg.text.replace("\n", " | ")])
			main.walker_out.global_position = main.pekka.global_position + Vector3(2.0, 0.5, 0)
			main.vaino.global_position = main.walker_out.global_position + Vector3(0, -0.5, 2.0)
			for i in 60:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("VAINO at pekka hint=%s dog_d=%.1f status=%s" % [main._hint.text, main.vaino.distance_to_target(), main._status.text])
			var m0 := main.money
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			print("VAINO Pekan valinnat: %s" % str(main._talk_box._options.map(func(o): return o.id)))
			main._test_talk(["vaino"])
			print("VAINO returned valid=%s money %s -> %s beers=%d msg=%s" % [is_instance_valid(main.vaino), main._eur(m0), main._eur(main.money), main.beers,
				main._msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		_:
			return 0
	return 1
