extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "muut_s_u". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const B := preload("res://scripts/build.gd")
const ShopInterior := preload("res://scripts/shop_interior.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Retket := preload("res://scripts/retket.gd")
const Looks := preload("res://scripts/looks.gd")
const HomeInterior := preload("res://scripts/home_interior.gd")
const GarageInterior := preload("res://scripts/garage_interior.gd")
const EBike := preload("res://scripts/ebike.gd")
const TanssiGame := preload("res://scripts/tanssi_game.gd")
const BingoGame := preload("res://scripts/bingo_game.gd")
const Tokola := preload("res://scripts/tokola.gd")
const TietokonemuseoLegenda := preload("res://scripts/tietokonemuseo_legenda.gd")
const PongGame := preload("res://scripts/pong_game.gd")
const Quests := preload("res://scripts/quests.gd")
const Story := preload("res://scripts/story.gd")
const DayStats := preload("res://scripts/day_stats.gd")

const KOHTAUKSET := ["sinikanlappu", "uittorinne", "uutiset", "uintikisa", "tietokonemuseo", "stetson", "tokola", "sinikkaranta", "turvapaikat", "seppo", "seurailta", "sisarajat", "tarina", "sisasyonti", "settingsmenu", "trailsign", "sinikkatehtava", "sinikka", "sunset", "stash", "tallennuspaikat", "startcheck", "tallennus", "stashtour", "tarpio", "tallijuoma2", "tallijuoma", "syo", "tilat", "tilat_vaikutukset", "tappioko"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"sinikanlappu":
			# Sinikan ovilappu, kori ja piirakka (tools/testit/sinikanlappu.gd); tallennus palautetaan lopuksi.
			var saved_sl := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			var sl: Node = load("res://tools/testit/sinikanlappu.gd").new()
			sl.main = main
			main.add_child(sl)
			await sl.run()
			if not saved_sl.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_sl)
			else:
				DirAccess.remove_absolute(Main.SAVE_PATH)
			main.get_tree().quit()
			return 2
		"uittorinne":
			# Uiton saunan rinne: törmäyssäteen osumakorkeus vs. h() pitkin linjaa saunan ovelta rantaan (TESTI VIKA, jos ero > 5 cm).
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for i in 10:
				await main.get_tree().physics_frame
			var ud: Vector3 = vl.uitto_door
			var dd := Vector3(vl.uitto_dir.x, 0, vl.uitto_dir.y)
			var sdv := dd.cross(Vector3.UP)
			var space := main.get_viewport().world_3d.direct_space_state
			var worst := 0.0
			for sv in [-3.0, 0.0, 3.0]:
				var row := []
				for t in range(-4, 16):
					var lp: Vector3 = ud + dd * float(t) + sdv * sv
					var gp: Vector3 = vl.to_global(Vector3(lp.x, vl.h(lp.x, lp.z), lp.z))
					var q := PhysicsRayQueryParameters3D.create(gp + Vector3(0, 50, 0), gp - Vector3(0, 50, 0), 0xFFFFFFFF)
					var r := space.intersect_ray(q)
					if r.is_empty():
						row.append("%d:-" % t)
						continue
					var gh: float = vl.to_local(r.position).y
					var diff: float = gh - vl.h(lp.x, lp.z)
					worst = maxf(worst, absf(diff))
					row.append("%d:%+.2f" % [t, diff])
				print("UITTORINNE sivu %.0f törmäys-h: %s" % [sv, " ".join(row)])
			print("UITTORINNE suurin ero %.2f m" % worst)
			if main.mopo_trip.on_foot == null:
				main._mopo_dismount()
			var uc := Camera3D.new()
			main.add_child(uc)
			uc.current = true
			for t in [1.0, 4.0, 7.0, 10.0]:
				var wp: Vector3 = ud + dd * t
				main.walker_out.global_position = vl.to_global(Vector3(wp.x, vl.h(wp.x, wp.z) + 0.6, wp.z))
				for i in 30:
					await main.get_tree().physics_frame
				var wl: Vector3 = vl.to_local(main.walker_out.global_position)
				print("UITTORINNE hahmo t=%.0f: jalan y - h = %+.3f, rinne %.0f°" % [t, wl.y - vl.h(wl.x, wl.z),
					rad_to_deg(atan2(vl.h(wl.x + dd.x, wl.z + dd.z) - vl.h(wl.x - dd.x, wl.z - dd.z), 2.0))])
				uc.look_at_from_position(main.walker_out.global_position + sdv * 3.0 + Vector3(0, 0.5, 0), main.walker_out.global_position + Vector3(0, 0.6, 0))
				for i in 4:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_t%d.png" % int(t)))
			main.get_tree().quit()
		"uutiset":
			# Kymppiuutiset nauhalta: video ajastetaan klo 21, klo 22.40 sohvalle eteisen kaapin kaljan kanssa, loppukohtaus
			# kuvina vaiheittain ja uusi päivä.
			if main.player == main.bike:
				main._toggle_mount()
			main._tape_day = -1
			main.stash["koti"] = 2
			main.clock_min = 21.0 * 60.0
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
			var snap := func(name: String) -> void:
				await frames.call(10)
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			await frames.call(3)
			main._enter_home("ovi")
			var wk: CharacterBody3D = main.home_int.walker
			wk.position = HomeInterior.SPOTS.video[0]
			await frames.call(5)
			print("UUTISET video ennen: '%s'" % main._hint.text)
			await press.call("interact")
			print("UUTISET ajastus: nauha %d päivä %d viesti '%s'" % [main._tape_day, main.day, main._msg.text])
			await frames.call(3)
			print("UUTISET video jälkeen: '%s'" % main._hint.text)
			var close := Camera3D.new()
			main.add_child(close)
			var vcr: Vector3 = main.home_int.to_global(Vector3(0.22, 0.25, -5.45))
			close.look_at_from_position(vcr + Vector3(0.15, 0.25, 0.7), vcr + Vector3(0, 0.15, 0))
			close.current = true
			await snap.call("_video.png")
			close.queue_free()
			wk.activate()
			main.clock_min = 22.0 * 60.0 + 40.0
			wk.position = HomeInterior.SPOTS.sohva[0]
			await frames.call(5)
			print("UUTISET sohva: '%s'" % main._hint.text)
			await snap.call("_sohva.png")
			await press.call("interact")
			print("UUTISET loppu: tila %s jemma %d" % [main.state, main.stash.get("koti", 0)])
			var t0 := Time.get_ticks_msec()
			for k in [["play", 2.0], ["tunnus", 5.3], ["studio", 7.0], ["zoom", 9.6], ["saa", 12.4], ["kommentti", 15.0], ["otsikko", 18.2]]:
				while Time.get_ticks_msec() - t0 < k[1] * 1000.0:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % k[0]))
				if main.cutscene.news_view != null:
					Kuva.ruutu(main.cutscene.news_view).save_png(path.replace(".png", "_ruutu_%s.png" % k[0]))
				if k[0] == "play":  # tunnus täysin näkyvissä: odotetaan vaihetta ja 1,6 s
					while main.cutscene.news_view.seg != "tunnus":
						await main.get_tree().process_frame
					await main.get_tree().create_timer(1.6, true, false, true).timeout
					await Kuva.piirto()
					Kuva.ruutu(main.cutscene.news_view).save_png(path.replace(".png", "_ruutu_tunnus_valmis.png"))
			for i in 40:
				await main.get_tree().create_timer(0.5, true, false, true).timeout
				if not main.cutscene.busy:
					break
			await main.get_tree().create_timer(1.5, true, false, true).timeout
			print("UUTISET herätys: tila %s päivä %d nauha %d loppuja %d viesti '%s'" % [main.state, main.day, main._tape_day,
				main.endings.counts.get("uutiset", 0), main._msg.text.replace("\n", " | ")])
		"uintikisa":
			# Oulujoen uintikilpailu (#183): kuva ponkkarilta ja kisan aikana (vain ikkunallisena), voitto ja tappio sekä tilan palautuminen.
			main._start_mopo()
			var vl2: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			main._note.visible = false
			main._mopo_dismount()
			var yd: Dictionary = vl2.doors.filter(func(d): return d.id == "pihanuoret")[0]
			main.walker_out.global_position = main.mopo_trip.to_global(yd.pos + yd.out * 2.0 + Vector3(0, 0.5, 0))
			for i in 10:
				await main.get_tree().process_frame
			var headless := DisplayServer.get_name() == "headless"
			var snap_u := func(name: String) -> void:
				if headless:
					return
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main.day = 3
			main.clock_min = 14 * 60
			main._nuoret_yard = true
			main._talk_who = "nuoret"
			print("UI valinta: %s" % [main._talk_options("nuoret").filter(func(o): return o.id == "uinti").map(func(o): return o.enabled)])
			main._talk_choose("uinti")
			await main.get_tree().create_timer(0.6).timeout
			var ug: Node = main._uinti_game
			print("UI peli auki %s, tila %s" % [ug != null, main.state])
			await snap_u.call("_a_ponkkari.png")
			ug._meter = 0.62
			ug._jump()
			await main.get_tree().create_timer(1.3).timeout
			await snap_u.call("_b_uinti.png")
			print("UI hypyn laatu %.2f, vaihe %s" % [ug._jump_q, ug._phase])
			var side := "L"
			var guard_t := 0.0
			while ug._phase == "swim" and guard_t < 60.0:
				ug._pull(side)
				side = "R" if side == "L" else "L"
				await main.get_tree().create_timer(0.17).timeout
				guard_t += 0.17
			await snap_u.call("_c_maali.png")
			print("UI tulos: sija %d, aika %.1f, vaihe %s" % [ug._place, ug._time, ug._phase])
			var m0 := main.maine
			ug._end(ug._place)
			await main.get_tree().create_timer(0.5).timeout
			print("UI jälkeen: tila %s, maine %.0f -> %.0f, uudestaan mahdollinen %s, viesti '%s'" % [main.state, m0, main.maine,
				main._talk_options("nuoret").filter(func(o): return o.id == "uinti").map(func(o): return o.enabled), main._msg.text.replace("\n", " ")])
			main.get_tree().quit()
		"tietokonemuseo":
			# Saloisten tietokonemuseo (#250 P10): intendentti, D22 ja mikrot, Pong (voitto, tappio, palkinto kerran); tallennus; paluu; yöllä nukahtaminen museossa; kuvat.
			main._note.visible = false
			var tm_shot := func(name: String) -> void:
				for i in 4:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.tietokonemuseo = TietokonemuseoLegenda.new()
			main.mielihyva = 50.0
			print("TM taksivalinta: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "retki_tietokonemuseo").map(func(o): return [o.id, o.enabled, o.text])])
			var tm_t0 := main.clock_min
			main._retki_from = main.player.global_position
			main._enter_retki("tietokonemuseo")
			print("TM perillä: state %s, kello +%.0f min, tehtävät %s" % [main.state, main.clock_min - tm_t0, main._tietokonemuseo_tasks()])
			await tm_shot.call("alue")
			var tm_cam := main.get_viewport().get_camera_3d()
			var tm_close := func(name: String, from: Vector3, to: Vector3, fov := 45.0) -> void:
				var c := Camera3D.new()
				c.fov = fov
				main.retki_int.add_child(c)
				c.look_at_from_position(main.retki_int.global_position + from, main.retki_int.global_position + to)
				c.current = true
				main._hud.visible = false
				await tm_shot.call(name)
				main._hud.visible = true
				tm_cam.make_current()
				c.queue_free()
			main.retki_int.walker.position = main.retki_int.spots.intendentti[0]
			for i in 3:
				await main.get_tree().process_frame
			print("TM intendentin luona: spot '%s', vihje '%s'" % [main.retki_int.spot, main._hint.text])
			main._tietokonemuseo_acted("intendentti")
			print("TM intendentti: puhuttu %s, kupla '%s', tehtävät %s" % [main.tietokonemuseo.intendentti, main.retki_int._bubble.text, main._tietokonemuseo_tasks()])
			await tm_shot.call("peli_intendentti")
			main.retki_int.walker.position = main.retki_int.spots.d22[0]
			for i in 3:
				await main.get_tree().process_frame
			print("TM d22: spot '%s', vihje '%s'" % [main.retki_int.spot, main._hint.text])
			main._tietokonemuseo_acted("d22")
			await tm_shot.call("peli_d22")
			main.retki_int.walker.position = main.retki_int.spots.mikrot[0]
			for i in 3:
				await main.get_tree().process_frame
			print("TM mikrot: spot '%s', vihje '%s'" % [main.retki_int.spot, main._hint.text])
			main.retki_int.walker.position = Vector3(4.6, 0, 2.6)
			await main.get_tree().create_timer(5.5).timeout
			await tm_shot.call("peli_kyltti")
			main.retki_int.walker.position = main.retki_int.spots.pong[0]
			for i in 3:
				await main.get_tree().process_frame
			print("TM pongilla: spot '%s', vihje '%s'" % [main.retki_int.spot, main._hint.text])
			await tm_shot.call("peli_pong")
			main.retki_int.walker.position = Vector3(1.0, 0, 3.5)  # pois kuvakulmista
			await main.get_tree().process_frame
			await tm_close.call("d22", Vector3(-4.6, 2.2, 1.0), Vector3(-4.6, 1.2, -5.2), 55.0)
			await tm_close.call("d22_nauha", Vector3(-6.5, 1.6, -2.6), Vector3(-6.5, 1.3, -5.2), 40.0)
			await tm_close.call("d22_paneeli", Vector3(-5.3, 1.7, -2.6), Vector3(-5.3, 1.5, -5.2), 40.0)
			await tm_close.call("d22_kortti", Vector3(-4.1, 1.5, -2.6), Vector3(-4.1, 1.2, -5.2), 40.0)
			await tm_close.call("d22_sivu", Vector3(-1.2, 1.8, -1.5), Vector3(-5.0, 1.0, -5.0), 55.0)
			await tm_close.call("mikrot", Vector3(4.0, 2.2, -1.0), Vector3(4.0, 0.9, -4.8), 55.0)
			await tm_close.call("mikrot_c64", Vector3(2.4, 1.6, -3.4), Vector3(2.4, 0.95, -4.8), 40.0)
			await tm_close.call("mikrot_zx", Vector3(4.0, 1.6, -3.4), Vector3(4.0, 0.95, -4.8), 40.0)
			await tm_close.call("mikrot_pc", Vector3(5.6, 1.6, -3.4), Vector3(5.6, 0.95, -4.8), 40.0)
			await tm_close.call("pong_edesta", Vector3(5.4, 1.7, 2.6), Vector3(5.4, 1.2, -0.2), 45.0)
			await tm_close.call("pong_paadysta", Vector3(8.0, 1.4, -0.2), Vector3(5.4, 1.2, -0.2), 45.0)
			await tm_close.call("pong_ylhaalta", Vector3(5.4, 6.0, 0.6), Vector3(5.4, 0.8, -0.2), 40.0)
			await tm_close.call("intendentti_edesta", Vector3(-0.4, 1.6, -1.6), Vector3(-0.4, 1.1, -4.0))
			await tm_close.call("intendentti_paadysta", Vector3(2.0, 1.4, -4.0), Vector3(-0.4, 1.1, -4.0))
			await tm_close.call("intendentti_ylhaalta", Vector3(-0.4, 5.0, -3.6), Vector3(-0.4, 0.5, -4.0))
			await tm_close.call("ylhaalta", Vector3(0.0, 40.0, 1.0), Vector3(0.0, 0.0, 0.0), 40.0)
			# Pong: peli auki, pelaaja jäljittää palloa (voitto), palkinto kerran.
			main.retki_int.walker.position = main.retki_int.spots.pong[0]
			for i in 3:
				await main.get_tree().process_frame
			main._tietokonemuseo_acted("pong")
			var tm_g: Node = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == PongGame)[0]
			print("TM pong auki: state %s, minipeli auki %s, voitot %d" % [main.state, main._minigame_open(), main.tietokonemuseo.voitot])
			await tm_shot.call("pong_alku")
			var tm_w := 0.0
			while tm_g._phase != "play" and tm_w < 5.0:
				await main.get_tree().process_frame
				tm_w += main.get_process_delta_time()
			await main.get_tree().create_timer(0.7).timeout
			tm_g._py = tm_g._ball.y
			await tm_shot.call("pong_peli")
			var tm_p := 0.0
			var tm_shots := 0
			while tm_g._phase != "over" and tm_p < 120.0:
				await main.get_tree().process_frame
				tm_p += main.get_process_delta_time()
				tm_g._py = tm_g._ball.y if tm_g._phase == "play" else tm_g._py
				if tm_g._phase == "point" and tm_shots == 0:
					tm_shots = 1
					await tm_shot.call("pong_piste")
			print("TM pong: vaihe %s, tulos %s, kesti %.1f s" % [tm_g._phase, tm_g._score, tm_p])
			await tm_shot.call("pong_loppu")
			tm_g._end(tm_g._score[0] > tm_g._score[1])
			await main.get_tree().process_frame
			print("TM pong valmis: state %s, voitot %d, parhaat %d, mielihyvä %.1f, tehtävät %s, minipeli auki %s" % [main.state, main.tietokonemuseo.voitot, main.tietokonemuseo.parhaat, main.mielihyva, main._tietokonemuseo_tasks(), main._minigame_open()])
			# Toinen voitto ei anna palkintoa uudelleen; tappio ei lisää voittoja; Esc kesken ei muuta.
			main.retki_int.block_interact()
			main._tietokonemuseo_acted("pong")
			tm_g = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == PongGame)[0]
			var tm_m := main.mielihyva
			tm_g._score = [5, 3]
			tm_g._end(true)
			await main.get_tree().process_frame
			print("TM toinen voitto: voitot %d, mielihyvä %.1f -> %.1f (ei muutosta)" % [main.tietokonemuseo.voitot, tm_m, main.mielihyva])
			main.retki_int.block_interact()
			main._tietokonemuseo_acted("pong")
			tm_g = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == PongGame)[0]
			tm_g._score = [2, 5]
			tm_g._phase = "over"
			tm_g._t = 1.0
			await tm_shot.call("pong_tappio")
			tm_g._end(false)
			await main.get_tree().process_frame
			print("TM tappio: voitot %d, state %s" % [main.tietokonemuseo.voitot, main.state])
			main.retki_int.block_interact()
			main._tietokonemuseo_acted("pong")
			tm_g = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == PongGame)[0]
			tm_g._end(false)
			await main.get_tree().process_frame
			print("TM Esc: state %s, voitot %d, minipeli auki %s" % [main.state, main.tietokonemuseo.voitot, main._minigame_open()])
			var tm_cfg := ConfigFile.new()
			main.tietokonemuseo.save_to(tm_cfg)
			var tm_l: RefCounted = TietokonemuseoLegenda.new()
			tm_l.load_from(tm_cfg)
			print("TM tallennus: intendentti %s voitot %d parhaat %d" % [tm_l.intendentti, tm_l.voitot, tm_l.parhaat])
			main._on_retki_exited()
			await main.get_tree().create_timer(14.0).timeout
			print("TM takaisin: state %s, etäisyys lähtöpaikasta %.2f m, kello +%.0f min" % [main.state, main.player.global_position.distance_to(main._retki_from), fposmod(main.clock_min - tm_t0, 1440.0)])
			# Yö: nukahtaminen museossa vie kotiin ja herätysteksti kertoo paikan.
			main._retki_from = main.player.global_position
			main.state = "cutscene"
			main._enter_retki("tietokonemuseo")
			await main.get_tree().create_timer(4.0).timeout  # saapumisviesti ehtii pois
			main._note.visible = true
			print("TM yö ennen: state %s, retki_int %s, retki_id '%s'" % [main.state, main.retki_int != null, main._retki_id])
			main._pass_out()
			print("TM yö: state %s, retki_int %s, hahmo %s, intro '%s'" % [main.state, main.retki_int != null, main.player.global_position.distance_to(main.home_zone + Vector3(0, 0, 4)) < 12.0, "Sammuit " + str(Retket.LISTA[main._retki_id].sammuit)])
			await main.get_tree().create_timer(1.0).timeout
			await tm_shot.call("yo_herays")
			await main.get_tree().create_timer(3.0).timeout
			await tm_shot.call("yo_aamu")
			print("TM yö jälkeen: state %s, päivä %d, hazards %s, retki_int %s" % [main.state, main.day, main._hazards.process_mode, main.retki_int != null])
			main.get_tree().quit()
		"stetson":
			# Stetson pelaajan päässä kaikissa asuissa: edestä, sivulta, takaa ja lähikuva.
			var stage := Node3D.new()
			main.add_child(stage)
			stage.global_position = Vector3(5000, 0, 5000)
			var lamp := DirectionalLight3D.new()
			lamp.rotation_degrees = Vector3(-40, 25, 0)
			stage.add_child(lamp)
			Looks.hat = "stetson"
			var outs := ["tuulipuku", "farkut", "tyovaatteet"]
			var heads: Array = []
			for i in 3:
				var c: Node3D = Looks.make(stage, Looks.player(outs[i]))
				Looks.add_cap(c)
				c.position = Vector3(-0.9 + i * 0.9, 0, 0)
				c.play("Idle", 0.0)
				heads.append(c)
			var cam := Camera3D.new()
			cam.fov = 40.0
			stage.add_child(cam)
			cam.current = true
			main._hud.visible = false
			# Vaatekaappi pelissä: kodin kaapilla valikko ja Stetson-valinta pelaajan malliin.
			Looks.hat = ""
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			for f in 5:
				await main.get_tree().physics_frame
			main._enter_home("ovi")
			main.home_int.walker.position = HomeInterior.SPOTS.vaatekaappi[0]
			for f in 8:
				await main.get_tree().physics_frame
			main._on_home_acted("vaatekaappi")
			print("STETSON valikko auki %s" % main._item_menu.is_open())
			main._on_wardrobe("hattu")
			var hats := 0
			for n in main.get_tree().root.find_children("*", "Node3D", true, false):
				if n.has_meta("player_body"):
					hats += 1
			print("STETSON hattu '%s', pelaajan malleja %d, viesti '%s'" % [Looks.hat, hats, main._msg.text])
			main._msg.text = ""
			for f in 30:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kotona.png"))
			main._on_home_exited()
			for k in [["koko", 0.0, Vector3(0, 1.1, 3.6), Vector3(0, 1.0, 0)], ["edesta", 0.0, Vector3(0, 1.75, 1.6), Vector3(0, 1.72, 0)],
					["sivulta", PI * 0.5, Vector3(0, 1.75, 1.6), Vector3(0, 1.72, 0)], ["takaa", PI, Vector3(0, 1.75, 1.6), Vector3(0, 1.72, 0)],
					["vino", PI * 0.25, Vector3(0, 1.85, 1.2), Vector3(0, 1.72, 0)]]:
				for c in heads:
					c.rotation.y = PI + k[1]
				cam.look_at_from_position(stage.global_position + k[2], stage.global_position + k[3])
				for f in 8:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % k[0]))
		"tokola":
			# Tokola (#120): ulkokuvat varastosta ja Heinimäen kuusesta, lukittu ovi, Aaron avain lihapiirakasta,
			# varaston löydöt (ohjain, rautalanka, tilikirja, lankku), kaivaminen Heinimäellä, markat Railille ja
			# legendan todistus Aarolle; epäilijän repliikki. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.ebike = EBike.new()
			main.tokola = Tokola.new()
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
			var oc := Camera3D.new()
			oc.far = 2000.0
			main.add_child(oc)
			var vd: Vector3 = main.world.varasto_door
			var vc := M.w(M.TOKOLA_VARASTO)
			var out := (vd - vc).normalized()
			oc.look_at_from_position(vd + out * 12.0 + Vector3(0, 4.0, 0) + out.cross(Vector3.UP) * 5.0, vc + Vector3(0, 1.5, 0))
			oc.current = true
			await frames.call(30)
			await snap.call("_varasto_ulko.png")
			var hp: Vector3 = main.world.heinimaki_pos
			oc.look_at_from_position(hp + Vector3(9, 4, 9), hp + Vector3(0, 3, 0))
			await frames.call(20)
			await snap.call("_heinimaki.png")
			oc.current = false
			main.player.activate_camera()
			print("TK paikat: ovi px %s, aaro px %s, kuusi px %s" % [M.to_px(vd), M.to_px(main.world.aaro_pos), M.to_px(hp)])
			main.walker_out.global_position = vd + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("TK ovi lukossa: '%s'" % main._hint.text)
			main.food["piirakka"] = 1
			print("TK aaro: %s" % [main._talk_options("aaro").map(func(o): return o.id)])
			main._talk_open("aaro", main.aaro)
			main._talk_box._pages.clear()
			main._talk_choose("piirakka")
			main._talk_box.close()
			await frames.call(5)
			print("TK avain: %s, piirakat %d" % [main.tokola.key, main.food.get("piirakka", 0)])
			main.walker_out.global_position = vd + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("TK ovi: '%s'" % main._hint.text)
			await press.call("interact")
			print("TK sisällä: %s" % main.state)
			await frames.call(20)
			await snap.call("_varasto_sisa.png")
			for sp in ["laatikko", "kelat", "lankku", "hylly", "lankku"]:
				main.varasto_int.walker.position = main.varasto_int.spots[sp][0]
				await frames.call(5)
				var h: String = main._hint.text
				await press.call("interact")
				print("TK %s: vihje '%s', viesti '%s'" % [sp, h, main._msg.text.left(80)])
			print("TK tila: ohjain %s, rautalanka %d, tilikirja %s, lankku %s, tehtävät %s" % [main.ebike.parts.has("ohjain"), main.ebike.supplies.rautalanka, main.tokola.tilikirja, main.tokola.lankku, main._tokola_tasks()])
			main.varasto_int.walker.position = main.varasto_int.spots.ovi[0]
			await frames.call(5)
			await press.call("interact")
			main.walker_out.global_position = hp + Vector3(2.0, 0.3, 0)
			await frames.call(10)
			print("TK kuusi: '%s'" % main._hint.text)
			await press.call("interact")
			print("TK lipas: %s, markat %s" % [main.tokola.lipas, main.tokola.markat])
			print("TK sulo: %s" % [main._talk_options("sulo").map(func(o): return o.id)])
			main._talk_open("aaro", main.aaro)
			main._talk_box._pages.clear()
			main._talk_choose("lipas")
			main._talk_box.close()
			for lg in main.get_children().filter(func(c): return c.get_script() == Main.TokolaLegenda):
				lg._finish()  # Aaron pihan hetki on oma testinsä (legendat.gd tokolan_aarre_eka)
			print("TK legenda: %s, maine %d, hetki %d" % [main.tokola.legend, roundi(main.maine), int(main.endings.counts.get("tokolan_aarre", 0))])
			var m0 := main.money
			main._talk_who = "raili"
			main._talk_kirppis("markat")
			main._talk_box.close()
			print("TK markat: rahaa %s -> %s" % [main._eur(m0), main._eur(main.money)])
			var lines := {}
			for i in 30:
				main._talk_who = "pekka"
				lines[main._talk_chat_line()] = true
			print("TK pekka todistettu repliikki: %s" % [Main.TOKOLA_PROVEN.pekka.any(func(l): return lines.has(l))])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"sinikkaranta":
			# Jalkapallopojat kentillä vuorotellen (kentän omat pojat piilossa) ja Sinikan aamu-uinti Oravajärvellä:
			# pihalta poissa, bonus kerran, mummojen kantelu tuijottaessa, jutteleminen ja sormus, Päivin aamukysymys.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			if main.player == main.bike:
				main._toggle_mount()
			var frames := func(n: int) -> void:
				for i in n:
					await main.get_tree().physics_frame
			# Pelin aikaan sidotut odotukset ruutuina: hitaassa testipiirrossa (0,5-3,5 s/ruutu) prosessiaskel on enintään
			# 8 fysiikka-askelta (0,13 s), joten create_timer(1.5) venyi 30-40 sekuntiin ja ajo aikarajaan (600 s).
			var ticks := func(n: int) -> void:
				for i in n:
					await main.get_tree().process_frame
			var snap := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main.clock_min = 12 * 60
			for d in [2, 4, 3]:
				main.day = d
				if is_instance_valid(main.boys):
					main.boys.queue_free()
				var ok := main._spawn_boys()
				await ticks.call(3)
				print("SR päivä %d: pojat %s kentällä '%s', Saloisten pojat näkyy %s, Honganpalon %s" % [d, ok, main._boys_field,
					main.world.kentta_kids[0].visible, main.world.hongan_kids[0].visible])
			main.day = 2
			if is_instance_valid(main.boys):
				main.boys.queue_free()
			main._spawn_boys()
			main._give_ball_quest()
			print("SR pallo %.0f m kentältä, viesti '%s'" % [main.ball.global_position.distance_to(main.boys.global_position), main._give_ball_quest().left(40) if false else "ok"])
			main.clock_min = 8 * 60 + 30
			main._sinikka_seen_day = -1
			main._sinikka_tattle_day = -1
			await ticks.call(3)
			print("SR pihan Sinikka näkyy %s, rannan Sinikka näkyy %s" % [main.sinikka.visible, main.world.uimaranta_sinikka.visible])
			var sp: Vector3 = main.world.uimaranta_sinikka_pos
			var m0: float = main.tilat.values.get("moraali", 0.0)
			main.walker_out.global_position = sp + Vector3(1.5, 0.3, 0)
			await frames.call(5)
			await ticks.call(3)
			print("SR bonus: moraali %.2f -> %.2f, '%s', vihje '%s'" % [m0, main.tilat.values.get("moraali", 0.0), main._msg.text.left(50), main._hint.text])
			var dir3 := Vector3(M.UIMARANTA_DIR.x, 0, M.UIMARANTA_DIR.y)
			var oc := Camera3D.new()
			main.add_child(oc)
			oc.look_at_from_position(sp + dir3 * 3.5 + Vector3(0, 1.5, 0), sp + Vector3(0, 1.0, 0))
			oc.current = true
			await frames.call(20)
			await snap.call("_sinikka.png")
			oc.current = false
			main.player.activate_camera()
			# Tuijotus kertyy pelin ajassa (yli 8 s): testi aloittaa 7,5 s:sta ja odottaa korkeintaan 30 ruutua.
			main._sinikka_stare_t = 7.5
			for i in 30:
				await main.get_tree().process_frame
				if main._sinikka_tattle_day == main.day:
					break
			print("SR kantelu päivä %d" % main._sinikka_tattle_day)
			main._orava_finds = ["aurinkolasit", "nokia", "sormus"]
			main._sormus_given = false
			print("SR valinnat rannalla: %s" % [main._talk_options("sinikka").map(func(o): return o.id)])
			main.day += 1
			print("SR aamu: '%s'" % main._flowers_morning(false).strip_edges().left(70))
			main.clock_min = 11 * 60
			await ticks.call(3)
			print("SR klo 11: pihan Sinikka %s, rannan %s" % [main.sinikka.visible, main.world.uimaranta_sinikka.visible])
			await main._sinikka_sun_test(frames, snap)
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"turvapaikat":
			# Turvapaikat: Päivi ei tule grillikatokselle, Viitajärven laavulle eikä raunioille; Viitajärven laavu on
			# päivän aloituspaikka erämaan laavun lopun jälkeen.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			if main.player == main.bike:
				main._toggle_mount()
			print("TU vyöhykkeitä %d" % main.wife.safe_zones.size())
			for spot in [["grillikatos", M.w(M.GRILLIKATOS)], ["viitajärvi", main.world.viita_pos], ["rauniot", main.world.rauniot_youth_pos], ["koti", main.home_zone]]:
				main.walker_out.global_position = spot[1] + Vector3(1.0, 0.3, 0)
				await main.get_tree().physics_frame
				print("TU %s: turvassa %s" % [spot[0], main.wife.is_target_safe()])
			main.walker_out.global_position = main.world.viita_pos + Vector3(30, 0.3, 0)
			main.endings.counts.erase("eramaan_laavu")
			print("TU aloitus ennen loppua: %.0f m kodista" % main._nearest_safe().distance_to(main.home_zone))
			main.endings.counts["eramaan_laavu"] = 1
			print("TU aloitus lopun jälkeen: %.0f m Viitajärven laavulta" % main._nearest_safe().distance_to(main.world.viita_pos))
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"seppo":
			# Sepon varastomyynti (#140) ja säästöpiha (#141): aukiolo, päivän tuotteet ja hinnat, kehu, yllätyslaatikko
			# (Kekkonen Veksille), marjojen ja Nokian myynti; kukat, multa, Sinikan taimet ja aamun kukkaviestit
			# (tavallinen, syntymäpäivä muistettu ja unohdettu). Kuvat paikoista.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.quests = Quests.new()
			main._seppo_day = {}
			main._kekkonen = 0
			main._nokia_sold = false
			main.has_flowers = false
			main._has_taimet = false
			main.sinikka_taimet = 0
			main.day = 2  # tiistai
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
				await frames.call(10)
			var oc := Camera3D.new()
			main.add_child(oc)
			var view := func(name: String, from: Vector3, to: Vector3) -> void:
				oc.look_at_from_position(from, to)
				oc.current = true
				await frames.call(30)
				await snap.call(name)
				oc.current = false
				main.player.activate_camera()
			var opts := func(who: String) -> Array:
				return main._talk_options(who).map(func(o): return "%s%s" % [o.id, "" if o.enabled else "(x)"])
			main.money = 80.0
			main.clock_min = 12 * 60
			var sd: Vector3 = main.world.seppo_door
			var sc := M.w(M.SEPPO)
			var sn := (main.world._osm_fit_at(M.SEPPO).nrm as Vector2)
			await view.call("_seppo.png", sc + Vector3(sn.x, 0, sn.y) * 18.0 + Vector3(6, 5, 0), sc + Vector3(0, 1.5, 0))
			await at.call(main.world.seppo_npc.global_position + Vector3(1.0, 0, 0))
			print("SE seppo: '%s'" % main._hint.text)
			print("SE päivän tuotteet %s, hinnat %s" % [main._seppo_today(), main._seppo_today().map(func(k): return main._eur(main._seppo_price(k)))])
			print("SE valinnat: %s" % [opts.call("seppo")])
			main._talk_open("seppo", main.world.seppo_npc)
			main._talk_box._pages.clear()
			print("SE mitä kuuluu: '%s'" % main._talk_chat_line())
			var k0: String = main._seppo_today()[0]
			var sup0: int = main.ebike.supplies.get(Main.SEPPO_STOCK[k0][2], 0) if Main.SEPPO_STOCK[k0][2] != "" else 0
			main._talk_choose("osta_" + k0)
			main._talk_choose("kehu")
			print("SE ostettu %s (tarvike %d -> %d), kehu: %.2f" % [k0, sup0, main.ebike.supplies.get(Main.SEPPO_STOCK[k0][2], 0) if Main.SEPPO_STOCK[k0][2] != "" else 0, main._seppo_kehu])
			for i in 30:
				main._seppo_day.erase("laatikko")
				main.money += Main.SEPPO_LAATIKKO
				main._talk_choose("laatikko")
				if main._kekkonen == 1:
					break
			print("SE laatikko: kekkonen %d" % main._kekkonen)
			main.bucket["puolukka"] = 3
			main._orava_finds = ["aurinkolasit", "nokia"]
			var m0 := main.money
			main._talk_choose("marjat")
			main._talk_choose("nokia")
			main._talk_box.close()
			print("SE myynti +%s, marjat jäljellä %d" % [main._eur(main.money - m0), main.bucket.get("puolukka", 0)])
			print("SE veksi auki %s: %s" % [main.kirppis_int.veksi_open, opts.call("veksi")])
			main._talk_who = "veksi"
			main._talk_choose("kekkonen")
			main._talk_box.close()
			print("SE kekkonen myyty %d" % main._kekkonen)
			main.day = 8  # maanantai: kiinni
			await frames.call(3)
			await at.call(sd)
			print("SE maanantaina: '%s'" % main._hint.text)
			main.day = 2
			# Säästöpiha.
			var pd: Vector3 = main.world.saasto_door
			var pc := M.w(M.SAASTOPIHA)
			var pn := (main.world._osm_fit_at(M.SAASTOPIHA).nrm as Vector2)
			await view.call("_saastopiha.png", pc + Vector3(pn.x, 0, pn.y) * 15.0 + Vector3(-5, 5, 0), pc + Vector3(3, 1.5, 0))
			await at.call(pd)
			print("SE säästöpiha: '%s'" % main._hint.text)
			for i in 20:
				main._talk_who = "sinikka"
				main._talk_chat_line()
			print("SE sinikka pyytää taimia %d" % main.sinikka_taimet)
			print("SE valinnat: %s" % [opts.call("saasto")])
			main._talk_open("saasto", null)
			main._talk_box._pages.clear()
			main._talk_choose("kukat")
			main._talk_choose("taimet")
			main._talk_choose("multa")
			main._talk_box.close()
			print("SE kukat %s, taimet %s, multa %d" % [main.has_flowers, main._has_taimet, main._multa_day])
			print("SE sinikka: %s" % [opts.call("sinikka")])
			main._talk_open("sinikka", main.sinikka)
			main._talk_box._pages.clear()
			main._talk_choose("taimet")
			main._talk_box.close()
			print("SE taimet viety %d, pullat %d" % [main.sinikka_taimet, main.food.get("pulla", 0)])
			main.has_flowers = false  # viety kotiin
			main._flowers_day = 2
			main.day = 3
			var mm := main.money
			print("SE aamu (kukat, multa): '%s' rahaa +%s" % [main._flowers_morning(false).strip_edges().replace("\n", " | "), main._eur(main.money - mm)])
			main._flowers_day = 7
			main.day = 8
			mm = main.money
			print("SE aamu (syntymäpäivä muistettu): '%s' +%s" % [main._flowers_morning(false).strip_edges().left(60), main._eur(main.money - mm)])
			main.day = 22
			main._flowers_day = -1
			print("SE aamu (syntymäpäivä unohdettu): '%s', ei kauppa-rahaa %s" % [main._flowers_morning(false).strip_edges().left(60), main._bday_forgotten(false)])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"seurailta":
			# Seuraintalon tanssit ja bingo (#129): ovi kiinni keskiviikkoiltana, tanssit lauantaina (lippu, sali, tanssi
			# Sinikan kanssa, ukot takakontilla, sulkeminen), bingo tiistaina (sali, lappu, pakotettu bingo ja palkinto).
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
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
			var door: Vector3 = main.world.kirppis_door
			main.money = 40.0
			main.day = 3
			main.clock_min = 19 * 60
			main.walker_out.global_position = door + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("SE ke ilta (%s): '%s'" % [Main.WEEKDAYS[main._weekday()], main._hint.text])
			main.day = 6
			main.clock_min = 21 * 60 + 30
			await frames.call(5)
			print("SE la ilta (%s): '%s'" % [Main.WEEKDAYS[main._weekday()], main._hint.text])
			await press.call("interact")
			print("SE tansseihin: tila %s, tila sisällä %s, rahaa %s" % [main.state, main.kirppis_int.mode, main._eur(main.money)])
			await frames.call(30)
			await snap.call("_tanssit_sali.png")
			# Taustaparit (kirppis_interior.gd _build_dancers) kasvokkain: kummankin katse (-Z) kohti paria ja rintakehien
			# väli. Lähikuvat yhdestä parista sivulta ja ylhäältä.
			for d: Node3D in main.kirppis_int._dancers:
				var cs := d.get_children()
				for k in 2:
					var me3: Node3D = cs[k]
					var other: Node3D = cs[1 - k]
					var to := other.global_position - me3.global_position
					to.y = 0.0
					var face := -me3.global_basis.z
					var dot := face.normalized().dot(to.normalized())
					var chest := me3.to_global(me3.bone_position("spine_03")).distance_to(other.to_global(other.bone_position("spine_03")))
					print("SE taustapari %s/%d: katse kohti paria %.2f, rintakehien väli %.2f m" % [d.name, k, dot, chest])
					if dot < 0.7:
						print("TESTI VIKA taustapari %s/%d ei ole kasvokkain (%.2f)" % [d.name, k, dot])
			# Läpimenot koko kierrokselta: taustaparin kumpikin tanssija (keskipiste ± 0,3 m kierron mukaan) vähintään 0,6 m
			# (kaksi kapselia) salin näkyvistä ihmisistä (bändi lavalla, muut lattialla).
			var lap := TAU / 0.35
			var near := [9.0, ""]
			for step in 400:
				var tt := lap * step / 400.0
				for k in main.kirppis_int._dancers.size():
					var dp: Array = main.kirppis_int.dancer_pose(k, main.kirppis_int._dancers.size(), tt)
					var off := Vector3(sin(dp[1]), 0, cos(dp[1])) * 0.3
					for i in main.kirppis_int.PEOPLE.size():
						if not main.kirppis_int._shown(i) or main.kirppis_int.PEOPLE[i].has("instrument"):
							continue
						var q: Vector3 = main.kirppis_int.person_at(i)
						for dpos: Vector3 in [dp[0] - off, dp[0] + off]:
							var dd := Vector2(dpos.x - q.x, dpos.z - q.z).length()
							if dd < near[0]:
								near = [dd, main.kirppis_int.PEOPLE[i].name]
			print("SE taustaparit lähimmillään %.2f m (%s)" % near)
			if near[0] < 0.6:
				print("TESTI VIKA taustapari menee läpi: %.2f m %s" % near)
			var pc := Camera3D.new()
			main.kirppis_int.add_child(pc)
			var pd: Node3D = main.kirppis_int._dancers[0]
			var mid3: Vector3 = (pd.get_child(0).global_position + pd.get_child(1).global_position) * 0.5 + Vector3(0, 1.0, 0)
			var side: Vector3 = pd.global_basis.x.normalized()
			var cur := main.get_viewport().get_camera_3d()
			var al: Vector3 = main.kirppis_int.to_global(main.kirppis_int.person_at(main.kirppis_int.person_index("annaliisa")) + Vector3(0, 1.0, 0))
			for v in [["_taustapari_sivu.png", mid3 + side * 2.4 + Vector3(0, 0.2, 0), mid3], ["_taustapari_ylha.png", mid3 + Vector3(0.01, 2.6, 0), mid3],
					["_annaliisa_tanssit.png", al + Vector3(-2.5, 1.2, -3.0), al]]:
				pc.look_at_from_position(v[1], v[2])
				pc.current = true
				await snap.call(v[0])
			pc.queue_free()
			if cur != null:
				cur.current = true
			print("SE sinikka: %s" % [main._talk_options("sinikka_seura").map(func(o): return o.id)])
			print("SE raili: %s" % [main._talk_options("raili").map(func(o): return o.id)])
			main._talk_open("sinikka_seura", null)
			main._talk_box._pages.clear()
			main._talk_choose("tanssi")
			var tg: Node = main.kirppis_int.get_children().filter(func(c): return c is TanssiGame).front()
			print("SE tanssi auki salissa: %s, salin Sinikka piilossa %s, kävelijä piilossa %s" % [tg != null, not main.kirppis_int._holders[main.kirppis_int.person_index("sinikka_seura")].visible, not main.kirppis_int.walker.visible])
			await main.get_tree().create_timer(5.5).timeout
			await snap.call("_tanssi.png")
			print("SE tanssibiisi '%s': musiikki soi %s, kohta %.2f s, musiikin kohta %.2f s, kompastukset %d" % [tg._song.title, Sfx.music_pos() >= 0.0, tg._t, Sfx.music_pos(), tg._misses])
			# Biisien nuottiradat (tanssibiisit.gd): askeleet vuorotellen, aikajärjestyksessä, huuto kertosäkeen lopussa
			# ja äänite olemassa.
			for sg: Dictionary in TanssiGame.Biisit.SONGS:
				var ch: Array = TanssiGame.Biisit.chart(sg)
				var kinds := {}
				var order_ok := true
				for i in ch.size():
					kinds[ch[i][1]] = kinds.get(ch[i][1], 0) + 1
					if i > 0 and ch[i][0] <= ch[i - 1][0]:
						order_ok = false
				print("SE nuottirata '%s': %s, järjestys %s, viimeinen %.1f s / loppu %.1f s" % [sg.title, kinds, order_ok, ch[-1][0], sg.end])
				if not order_ok or kinds.get("HEI", 0) < 1 or absi(int(kinds.get("A", 0)) - int(kinds.get("D", 0))) > 1 \
						or not ResourceLoader.exists(sg.file) or float(sg.beats[-1]) < float(sg.end):
					print("TESTI VIKA tanssin nuottirata '%s': %s" % [sg.title, kinds])
			var hei: Array = tg._beats.filter(func(b: Array) -> bool: return b[1] == "HEI").front()
			tg.seek(tg._song.beats[36])  # tahti 9: säkeistö
			await frames.call(4)
			await snap.call("_tanssi_sakeisto.png")
			tg.seek(hei[0] - 1.0)
			await frames.call(4)
			await snap.call("_tanssi_hei_tulossa.png")
			tg.seek(hei[0])
			tg._press("HEI", tg.WINDOW)
			print("SE HEI! osui %s, kompastukset %d" % [hei[2] == 1, tg._misses])
			if hei[2] != 1:
				print("TESTI VIKA HEI! ei osunut")
			await frames.call(6)
			await snap.call("_tanssi_hei.png")
			tg._miss()
			tg._say("Auts, varpaat!", 2.0)
			await main.get_tree().create_timer(0.15).timeout
			await snap.call("_tanssi_kompastus.png")
			tg._hits = 30
			tg._misses = 3
			tg._finish()
			await frames.call(5)
			print("SE tanssi ohi: viesti '%s', soitto %.1f, Sinikka takaisin %s, kävelijä näkyy %s" % [main._msg.text, main._paivi_call_t, main.kirppis_int._holders[main.kirppis_int.person_index("sinikka_seura")].visible, main.kirppis_int.walker.visible])
			main._on_kirppis_acted("takaovi")
			print("SE ukot: '%s'" % main._msg.text)
			main.clock_min = 60 + 5
			await frames.call(5)
			print("SE tanssit loppu: tila %s, viesti '%s'" % [main.state, main._msg.text])
			main.day = 2
			main.clock_min = 18 * 60 + 15
			main.walker_out.global_position = door + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("SE ti ilta (%s): '%s'" % [Main.WEEKDAYS[main._weekday()], main._hint.text])
			await press.call("interact")
			print("SE bingoon: tila %s, %s" % [main.state, main.kirppis_int.mode])
			await frames.call(30)
			await snap.call("_bingo_sali.png")
			print("SE erkki: %s" % [main._talk_options("huutaja").map(func(o): return o.id)])
			main._talk_open("huutaja", null)
			main._talk_box._pages.clear()
			main._talk_choose("bingo")
			var bg: Node = main.kirppis_int.get_children().filter(func(c): return c is BingoGame).front()
			print("SE bingo auki: %s" % [bg != null])
			bg.rival_at = 99
			await main.get_tree().create_timer(7.0).timeout
			var click := InputEventMouseButton.new()  # väärä bingo: mummot mulkoilevat
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			bg._mouse = bg._bingo_rect().get_center()
			bg._gui(click)
			await main.get_tree().create_timer(0.4).timeout
			await snap.call("_bingo_vaara.png")
			print("SE väärä bingo: %d, '%s'" % [bg._false, bg._tip.text])
			for i in 5:  # ylärivi merkityksi kuin huudettuna
				if not (bg._card[i] in bg._called):
					bg._called.append(bg._card[i])
				bg._marked[i] = true
			await main.get_tree().create_timer(0.3).timeout
			await snap.call("_bingo.png")
			print("SE bingo rivi: %s" % [bg._has_line()])
			bg._end(true)
			await main.get_tree().create_timer(2.0).timeout
			print("SE bingo voitto: viesti '%s'" % main._msg.text)
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"sisarajat":
			# Joka sisätilassa ovelta neljään suuntaan 1,5 s: hahmo ei saa päätyä lattian ulkopuolelle.
			if main.player == main.bike:
				main._toggle_mount()
			main.mokki.ensure_built()
			# Sisätila haetaan vasta sisään mentäessä: Raahen baari rakennetaan joka käynnillä uudestaan.
			var cases := [["koti", func() -> Node3D: return main.home_int, func() -> void: main._enter_home("ovi")],
				["mökki", func() -> Node3D: return main.mokki_int, func() -> void: main._enter_mokki("ovi")],
				["talli", func() -> Node3D: return main.garage_int, func() -> void: main._enter_garage()],
				["kauppa", func() -> Node3D: return main.interior, func() -> void: main._enter_shop()],
				["raahe", func() -> Node3D: return main.raahe_int, func() -> void: main._enter_raahe()],
				["siitari", func() -> Node3D: return main.siitari_int, func() -> void:
					main.state = "in_siitari"
					main.siitari_int.enter()]]
			for c in cases:
				c[2].call()
				var it: Node3D = c[1].call()
				for i in 5:
					await main.get_tree().physics_frame
				var w: CharacterBody3D = it.walker
				var start: Vector3 = w.position
				var worst := 0.0
				for d in [["right", Vector2(1, 0)], ["left", Vector2(-1, 0)], ["forward", Vector2(0, -1)], ["back", Vector2(0, 1)]]:
					w.position = start
					w.controls_enabled = true
					Input.action_press(d[0])
					for i in 90:
						await main.get_tree().physics_frame
					Input.action_release(d[0])
					var p := Vector2(w.position.x, w.position.z)
					var out := INF
					for r: Rect2 in w.bounds:
						var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
						out = minf(out, q.distance_to(p))
					worst = maxf(worst, out)
				print("SISARAJAT %s: ovi %s, pahin yli lattian %.2f m, rajat %s" % [c[0], start, worst, w.bounds])
				# Toisin päin: rajaus ei saa estää pääsyä yhteenkään toimintopisteeseen.
				var pts := {}
				var sp = it.get("spots")
				if sp == null and "SPOTS" in it:
					sp = it.SPOTS
				if sp is Dictionary:
					for id in sp:
						pts[id] = sp[id][0]
				if it == main.interior:
					for id in ["DOOR", "ENTRY", "COOLER_SPOT", "GRILL_SPOT", "CANDY_SPOT", "BAKERY_SPOT", "BREW_SPOT", "ALKO_SPOT",
							"QUEUE_FRONT"]:
						pts[id] = main.interior.get_script().get_script_constant_map()[id]
					for k in ShopInterior.PRODUCTS.size():
						pts["hylly%d" % k] = Vector3(10.4, 0, ShopInterior.SHELF_Z0 + k + 0.5)
				var blocked: Array = []
				for id in pts:
					var at: Vector3 = pts[id]
					w.position = at
					w._keep_in_bounds()
					if Vector2(w.position.x - at.x, w.position.z - at.z).length() > 0.01:
						blocked.append("%s (%.2f m)" % [id, Vector2(w.position.x - at.x, w.position.z - at.z).length()])
				print("SISARAJAT %s: toimintopisteitä %d, rajaus estää: %s" % [c[0], pts.size(), blocked if not blocked.is_empty() else "ei mitään"])
				w.position = start
				main.state = "ulkona"
		"tarina":
			# Koko tarina läpi: kaljat jemmaan, Pekan tehtävät, sienet, puolukat, Sinikan nurmikko, avaimet kodalta.
			main.story = Story.new()
			main._toggle_mount()
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			var goto := func(pos: Vector3) -> void:
				main.walker_out.global_position = pos + Vector3(0, 0.4, 0)
				main.walker_out.velocity = Vector3.ZERO
				for i in 8:
					await main.get_tree().physics_frame
			var shot := func(name: String) -> void:
				main._msg.text = ""
				main._msg_queue.clear()
				main._note.visible = false
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			print("TARINA alku: %s, Pekan kyyti auki %s" % [main.story.step, main.story.ride_unlocked()])
			main.beers = 6
			main.walker_out.set_carrying(true)
			await main._test_goto_stash("koti")
			var shift := InputEventKey.new()
			shift.keycode = KEY_SHIFT
			shift.physical_keycode = KEY_SHIFT
			shift.pressed = true
			Input.parse_input_event(shift)
			await press.call("interact")
			shift = shift.duplicate()
			shift.pressed = false
			Input.parse_input_event(shift)
			print("TARINA jemma: kaljat %d, vaihe %s, viesti '%s'" % [main.beers, main.story.step, str(main._msg_queue)])
			main._on_home_exited()
			await goto.call(main.pekka.global_position + Vector3(1.5, 0, 0))
			print("TARINA Pekka: '%s'" % main._hint.text)
			await press.call("interact")
			print("TARINA ikkuna: %s" % str(main._talk_box._options.map(func(o): return o.text)))
			main._test_talk(["tarina"])
			print("TARINA tehtävät: %s, lista %s" % [main.story.step, str(main.story.list())])
			main.bucket = {"kantarelli": 2, "herkkutatti": 2, "puolukka": 6}
			await goto.call(main.pekka.global_position + Vector3(1.5, 0, 0))
			print("TARINA Pekka sienet: '%s'" % main._hint.text)
			var m0 := main.money
			await press.call("interact")
			main._test_talk(["myy"])
			print("TARINA sienet: %s, ämpäri %s, rahaa %.2f -> %.2f" % [main.story.done.sienet, main.bucket, m0, main.money])
			await goto.call(main.arto.global_position + Vector3(1.5, 0, 0))
			print("TARINA Arto: '%s'" % main._hint.text)
			await press.call("interact")
			main._test_talk(["myy"])
			print("TARINA puolukat: %s, ämpäri %s" % [main.story.done.puolukat, main.bucket])
			await goto.call(main.sinikka_lawn.mower.global_position + Vector3(0.8, 0, 0))
			print("TARINA leikkuri: '%s'" % main._hint.text)
			await shot.call("_nurmikko.png")
			await press.call("interact")
			print("TARINA leikkuu käy %s" % main.mowing)
			main.sinikka_lawn.lengths.fill(0.0)
			for i in 10:
				await main.get_tree().process_frame
			print("TARINA nurmikko: %s, vaihe %s" % [main.story.done.nurmikko, main.story.step])
			main._inventory.toggle()
			for i in 5:
				await main.get_tree().process_frame
			await shot.call("_reppu.png")
			main._inventory.toggle()
			await goto.call(main.pekka.global_position + Vector3(1.5, 0, 0))
			print("TARINA Pekka avaimet: '%s'" % main._hint.text)
			await press.call("interact")
			main._test_talk(["tarina"])
			print("TARINA avaimet: vaihe %s, avaimet kodalla %s" % [main.story.step, is_instance_valid(main._keys_node)])
			await goto.call(main._keys_node.global_position + Vector3(1.0, 0, 0))
			print("TARINA kodalla: '%s'" % main._hint.text)
			var kc := Camera3D.new()
			main.add_child(kc)
			kc.look_at_from_position(main._keys_node.global_position + Vector3(1.2, 1.2, 1.2), main._keys_node.global_position)
			kc.current = true
			await shot.call("_avaimet.png")
			kc.queue_free()
			main.walker_out.activate_camera()
			await press.call("interact")
			print("TARINA avaimet mukana: %s" % main.story.step)
			await goto.call(main.pekka.global_position + Vector3(1.5, 0, 0))
			await press.call("interact")
			main._test_talk(["tarina"])
			print("TARINA valmis: %s, kyyti auki %s" % [main.story.step, main.story.ride_unlocked()])
			for i in 3:
				await main.get_tree().process_frame
			print("TARINA Pekka nyt: '%s'" % main._hint.text)
			await press.call("interact")
			print("TARINA Pekka nyt valinnat: %s" % str(main._talk_box._options.map(func(o): return o.text + ("" if o.enabled else " [" + o.reason + "]"))))
			main._talk_box.close()
		"sisasyonti":
			# T sisätiloissa: kotona valikko aukeaa, kävelijä pysähtyy, pulla syödään ja ohjaus palaa.
			if main.player == main.bike:
				main._toggle_mount()
			main.food["pulla"] = 2
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			for i in 5:
				await main.get_tree().physics_frame
			main._enter_home("ovi")
			for i in 30:
				await main.get_tree().physics_frame
			var n0: float = main.tilat.get_v("nalka") if main.tilat.has_method("get_v") else 0.0
			await main.get_tree().process_frame
			Input.action_press("eat")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("eat")
			print("SISASYO tila=%s valikko=%s kotikävelijän ohjaus=%s ulkokävelijän=%s" % [main.state, main._item_menu.is_open(),
				main.home_int.walker.controls_enabled, main.walker_out.controls_enabled])
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_sisasyonti.png"))
			main._item_menu.visible = false
			main._item_menu.chosen.emit("pulla")
			await main.get_tree().process_frame
			print("SISASYO jälkeen: pullia %d, viesti '%s', kotikävelijän ohjaus=%s ulkokävelijän=%s" % [main.food.get("pulla", 0), main._msg.text,
				main.home_int.walker.controls_enabled, main.walker_out.controls_enabled])
		"settingsmenu":
			main.menu.open_main()
			main.menu._settings("sub_main")
			for i in 10:
				await main.get_tree().process_frame
			var wk: Button = null
			for b in main.menu.find_children("*", "Button", true, false):
				if (b as Button).text.begins_with("Heikko kone"):
					wk = b
			print("ASETUKSET ennen: laatu=%d skaala=%.1f etäisyys=%d" % [Settings.get_v("quality"), Settings.get_v("render_scale"), Settings.get_v("view_distance")])
			if wk != null:
				wk.pressed.emit()
			for i in 10:
				await main.get_tree().process_frame
			print("ASETUKSET jälkeen: laatu=%d skaala=%.1f etäisyys=%d usva_loppu=%.0f kaukoraja=%.0f" % [Settings.get_v("quality"),
				Settings.get_v("render_scale"), Settings.get_v("view_distance"), main._env.fog_depth_end, Settings.view_far()])
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_asetukset.png"))
		"trailsign":
			var a3 := M.w2(M.J_H2)
			var d3 := (M.w2(Vector2(846, 1300)) - a3).normalized()
			var at3 := a3 + d3 * 5.0 + d3.orthogonal() * 3.0
			var cam := Camera3D.new()
			cam.fov = 40.0
			main.add_child(cam)
			var n3 := Vector3(-d3.y, 0, d3.x)
			var sp := Vector3(at3.x, 1.55, at3.y) + Vector3(d3.x, 0, d3.y) * 0.8
			cam.look_at_from_position(sp + n3 * 2.4 + Vector3(0, 0.2, 0), sp, Vector3.UP)
			cam.current = true
		"sinikkatehtava":
			# Sinikan mustikkatehtävä: pyyntö, odotus ilman marjoja, luovutus 2 l:lla ja piirakka reppuun.
			main._toggle_mount()
			var press := func() -> void:
				Input.action_press("interact")
				await main.get_tree().process_frame
				Input.action_release("interact")
				for i in 5:
					await main.get_tree().process_frame
			main.clock_min = 11 * 60  # aamulla (8–10) Sinikka on uimassa ja iltapäivällä (12–17) rannalla, ei pihalla
			for i in 5:
				await main.get_tree().process_frame
			main.sinikka.set_physics_process(false)
			var sp2: Vector3 = main.sinikka.yard[0]
			main.sinikka.global_position = sp2
			main.walker_out.global_position = sp2 + Vector3(1.5, 0.4, 0)
			for i in 20:
				await main.get_tree().physics_frame
			print("SINIKKA vihje: ", main._hint.text)
			await press.call()
			print("SINIKKA valinnat: %s" % str(main._talk_box._options.map(func(o): return o.id)))
			main._talk_choose("apu")
			print("SINIKKA pyyntö: tehtävä=%d info=%s" % [main.sinikka_task, main._talk_box._info])
			main._talk_choose("juttu")
			print("SINIKKA odotus: info=%s valinnat=%s" % [main._talk_box._info, str(main._talk_box._options.map(func(o): return o.text + ("" if o.enabled else " [" + o.reason + "]")))])
			main._talk_box.close()
			main.bucket["mustikka"] = 3
			for i in 3:
				await main.get_tree().process_frame
			print("SINIKKA vihje marjoilla: ", main._hint.text)
			await press.call()
			main._talk_choose("mustikat")
			print("SINIKKA luovutus: tehtävä=%d ämpäri=%s piirakka=%d info=%s" % [main.sinikka_task, main.bucket, main.food.get("mustikkapiirakka", 0), main._talk_box._info])
			print("SINIKKA sama päivä uudestaan: valinnat=%s" % str(main._talk_box._options.map(func(o): return o.id)))
			main._talk_box.close()
			for i in 3:
				await main.get_tree().process_frame
			var n0: float = main.tilat.value("nalka")
			main._open_eat_menu()
			print("SINIKKA syömävalikko: ", main._item_menu._items)
			main._item_menu.visible = false
			main._item_menu.chosen.emit("mustikkapiirakka")
			print("SINIKKA söi piirakan: nälkä %+.2f, piirakoita %d, msg=%s" % [main.tilat.value("nalka") - n0, main.food.get("mustikkapiirakka", 0), main._msg.text])
		"sinikka":
			# Sinikka läheltä edestä vinosti (ulkonäkö ja asusteet). Klo 10.30: aamulla hän on uimassa, iltapäivällä rannalla.
			main.clock_min = 10.5 * 60.0
			for i in 30:
				await main.get_tree().process_frame
			main.sinikka.set_physics_process(false)
			var sp: Vector3 = main.sinikka.yard[0]
			var hc := M.w(M.NEIGHBOR_SINIKKA)
			var fwd := Vector3(sp.x - hc.x, 0, sp.z - hc.z).normalized()
			main.sinikka.global_position = sp
			main.sinikka.rotation.y = B.yaw_to(fwd)
			var sc := Camera3D.new()
			sc.fov = 40.0
			main.add_child(sc)
			sc.look_at_from_position(sp + fwd * 3.2 + fwd.cross(Vector3.UP) * 1.2 + Vector3(0, 1.4, 0), sp + Vector3(0, 1.05, 0), Vector3.UP)
			sc.current = true
			main._msg.text = ""
		"sunset":
			main.beers = 5
			main.fire_lit = true
			main.sausage_done = true
			main.stash_laavu = 7
			main._win_laavu()
			print("SUNSET laavu=", main.stash_laavu, " jemma=", main.jemma, " beers=", main.beers)
			for i in 300:
				await main.get_tree().process_frame
		"stash":
			main.laavu_conquered = true
			main.guard.vanish()
			main._toggle_mount()
			main.walker_out.global_position = M.w(M.LAAVU) + Vector3(3.8, 0.3, 1.4)
			main.walker_out.rotation.y = -0.6
			main.beers = 6
			main.jemma = 10
			for i in 20:
				await main.get_tree().process_frame
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			print("STASH laavu=", main.stash_laavu, " beers=", main.beers)
		"tallennuspaikat":
			# Viisi omaa tallennuspaikkaa (menu.gd _slots): tallennus paikkaan 2, kuvaus, valikot ja lataus (kopio
			# automaattitallennukseksi; uudelleenlatausta ei tehdä testissä). Testin HOME on eristetty (aja.sh).
			for i in range(1, main.menu.SLOTS_N + 1):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(main.menu.slot_path(i)))
			main.day = 7
			main.money = 12.5
			main.menu.open_pause()
			main.menu._save_slot(2)
			var info: String = main.menu._slot_info(2)
			print("PAIKAT paikka 2: %s, paikka 3: %s" % [info, main.menu._slot_info(3)])
			if not info.begins_with("2: Päivä 7"):
				print("TESTI VIKA paikan 2 kuvaus väärin: %s" % info)
			main.menu._slots("save", "sub_pause")
			await main.get_tree().process_frame
			var n_save: int = main.menu._box.get_children().filter(func(c: Node) -> bool: return c is Button).size()
			main.menu._slots("load", "sub_pause")
			await main.get_tree().process_frame
			var n_load: int = main.menu._box.get_children().filter(func(c: Node) -> bool: return c is Button).size()
			print("PAIKAT painikkeita tallennus %d (odotus 7), lataus %d (odotus 2)" % [n_save, n_load])
			if n_save != 7 or n_load != 2:
				print("TESTI VIKA tallennus/latausvalikon painikkeet")
			await Kuva.piirto()
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--shot="):
					main.menu._slots("save", "sub_pause")
					for i in 4:
						await main.get_tree().process_frame
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(arg.substr(7).replace(".png", "_tallenna.png"))
			main.money = 99.0
			main._save_game()
			var cfg := ConfigFile.new()
			cfg.load(main.menu.slot_path(2))
			print("PAIKAT paikan rahat %s (odotus 12.5)" % cfg.get_value("peli", "rahat"))
			if absf(float(cfg.get_value("peli", "rahat", 0.0)) - 12.5) > 0.01:
				print("TESTI VIKA paikan sisältö muuttui automaattitallennuksessa")
			main.menu.close()
		"startcheck":
			# Oikea käynnistys (kuvan nimi *menu.png ohittaa testitilan): tallennettu pyörä, valikosta jatkoon, kävely.
			main.menu.close()
			await main.get_tree().process_frame
			var p0 := main.player.global_position
			var c0 := main.get_viewport().get_camera_3d().global_position
			Input.action_press("forward")
			for i in 60:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			print("STARTCHECK on_foot=", main.player == main.walker_out, " mode=", main.walker_out.process_mode,
				" moved=%.1f cam_moved=%.1f" % [main.player.global_position.distance_to(p0),
				main.get_viewport().get_camera_3d().global_position.distance_to(c0)])
		"tallennus":
			# Tallennus ja jatko tallennetusta paikasta: jalan ulkona, pyörän selässä ja kaupassa (viimeisin
			# ulkopaikka). Jokainen: tallennus, pelaaja kotiin, luku tiedostosta ja _apply_saved_bike.
			var saved_cfg := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var check := func(label: String, want: Vector3, want_bike: bool) -> void:
				main._save_game()
				var cfg := ConfigFile.new()
				cfg.load(Main.SAVE_PATH)
				main._place_on_foot(main.home_zone + Vector3(0, 0.3, 4))  # pelaaja muualle, kuin uusi käynnistys
				main._resume_saved = cfg.get_value("peli", "paikka", [])
				main._bike_saved = [cfg.get_value("peli", "pyora"), cfg.get_value("peli", "pyora_kulma", 0.0)]
				if want_bike:
					main.walker_out.visible = false
					main.walker_out.process_mode = Node.PROCESS_MODE_DISABLED
					main._set_avatar(main.bike)  # käynnistyksessä pelaaja on pyörän selässä ennen _apply_saved_bikea
				main._apply_saved_bike()
				for i in 5:
					await main.get_tree().physics_frame
				print("TALLENNUS %s: paikka %s ero %.2f m, pyörällä %s (odotus %s), jalan näkyvissä %s" % [label,
					str(main.player.global_position.snapped(Vector3.ONE * 0.1)), main.player.global_position.distance_to(want),
					main.player == main.bike, want_bike, main.walker_out.visible])
			# 1) Jalan kaupan pihalla.
			if main.player != main.walker_out:
				main._toggle_mount()
			var spot := main.shop_zone + Vector3(8, 0, 10)
			spot.y = Terrain.h(spot.x, spot.z) + 0.3
			main.walker_out.global_position = spot
			for i in 40:
				await main.get_tree().physics_frame
				await main.get_tree().process_frame
			var foot_at := main.walker_out.global_position
			await check.call("jalan", foot_at, false)
			# 2) Pyörän selässä tien varressa.
			main.bike.global_position = spot + Vector3(4, 0, 0)
			main._toggle_mount()
			for i in 40:
				await main.get_tree().physics_frame
				await main.get_tree().process_frame
			await check.call("pyörällä", main.bike.global_position, true)
			# 3) Kaupassa: tallennus jatkaa viimeisimmästä ulkopaikasta.
			if main.player != main.walker_out:
				main._toggle_mount()
			for i in 20:
				await main.get_tree().physics_frame
				await main.get_tree().process_frame
			var outside := main.walker_out.global_position
			main._enter_shop()
			for i in 10:
				await main.get_tree().process_frame
			print("TALLENNUS kaupassa: state=%s" % main.state)
			await check.call("kaupasta", outside, false)
			# Taukovalikko tallennuksen jälkeen.
			main.menu.open_pause(true)
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path)
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_cfg)
			main.get_tree().quit()
		"stashtour":
			# Jokainen jemma: E piilottaa yhden, Q ottaa yhden, kuva paikasta.
			main.laavu_conquered = true
			main.guard.vanish()
			main._toggle_mount()
			main._hud.visible = true
			for id in Main.STASHES:
				var at := main._stash_pos(id)
				main.walker_out.global_position = at + Vector3(1.6, 0.6, 1.6)
				main.walker_out.look_at(Vector3(at.x, main.walker_out.global_position.y, at.z))
				main.walker_out.velocity = Vector3.ZERO
				main.beers = 3
				main.walker_out.set_carrying(true)
				for i in 40:
					await main.get_tree().process_frame
				print("STASH ", id, " at ", at, " hint=", main._hint.text)
				var before: int = main.stash.get(id, 0)
				Input.action_press("interact")
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
				print("  E: ", before, " -> ", main.stash.get(id, 0), " beers=", main.beers)
				Input.action_press("bell")
				await main.get_tree().process_frame
				Input.action_release("bell")
				await main.get_tree().process_frame
				print("  Q: -> ", main.stash.get(id, 0), " beers=", main.beers)
				main._msg.text = ""
				var tc := Camera3D.new()
				main.add_child(tc)
				tc.global_position = at + Vector3(5.0, 3.5, 5.0)
				tc.look_at(at, Vector3.UP)
				tc.current = true
				for i in 3:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_" + id + ".png"))
				tc.queue_free()
				main.walker_out.activate_camera()
		"tarpio":
			# Tarpion laavu valokuvan suunnasta (edestä vasemmalta penkin takaa), laavusta ulos ja nuotio palamassa.
			# Kuvat _tarpio_*.
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.fov = 60.0
			var pit := M.w(M.LAAVU)
			var snap := func(name: String, eye: Vector3, at: Vector3) -> void:
				cam.global_position = pit + eye
				cam.look_at(pit + at, Vector3.UP)
				cam.current = true
				for i in 14:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_tarpio_%s.png" % name))
			main._hud.visible = false
			main.clock_min = 12 * 60.0
			main.player.global_position = pit + Vector3(0, 0.3, -30)
			for i in 20:
				await main.get_tree().process_frame
			await snap.call("edesta", Vector3(-0.6, 1.7, -6.4), Vector3(0.9, 1.0, 2.2))
			await snap.call("ulos", Vector3(0.4, 1.4, 2.6), Vector3(0.0, 0.8, -6.0))
			await snap.call("vaja", Vector3(2.5, 1.6, -2.5), Vector3(4.6, 1.0, 2.8))
			main.world.fire.visible = true
			main.clock_min = 21 * 60.0
			await snap.call("nuotio", Vector3(-1.5, 1.5, -3.8), Vector3(0.0, 0.5, 0.5))
		"tallijuoma2":
			# Käyttäjän polku: hiiriohjaus päällä, viini käymään saavilla, T-valikko, välissä taukovalikko, viina hiiren
			# vasemmalla.
			Settings.set_v("mouse_steer", true)
			if main.player == main.bike:
				main._toggle_mount()
			main.viina_pullot = 2
			main.bucket = {"mustikka": 3}
			main.has_yeast = true
			main.has_sugar = true
			main.wine_start = -1
			main.wine_locked = false
			main._enter_garage()
			var w: CharacterBody3D = main.garage_int.walker
			w.position = GarageInterior.SPOTS.saavi[0]
			for i in 5:
				await main.get_tree().physics_frame
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			var press := func(a: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(a)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(a)
				await main.get_tree().process_frame
			var click := func(btn: int) -> void:
				for down in [true, false]:
					var ev := InputEventMouseButton.new()
					ev.button_index = btn
					ev.pressed = down
					Input.parse_input_event(ev)
					await main.get_tree().process_frame
					await main.get_tree().process_frame
			await main._test_fill_vat(true)
			print("TALLIJ2 viini käymään: alku %d" % main.wine_start)
			await press.call("eat")
			print("TALLIJ2 valikko auki %s" % main._item_menu.is_open())
			main.menu.open_pause()
			for i in 5:
				await main.get_tree().process_frame
			main.menu.close()
			for i in 5:
				await main.get_tree().process_frame
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			main._item_menu._sel = main._item_menu._items.map(func(x): return x[0]).find("viina")
			await click.call(MOUSE_BUTTON_LEFT)
			for i in 10:
				await main.get_tree().physics_frame
			var p0 := w.position
			Input.action_press("forward")
			for i in 30:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			print("TALLIJ2 viinan jälkeen: valikko %s, ohjaus %s, tila %s, busy %s, liikkui %.2f m, viinaa %d, viesti '%s'" % [
				main._item_menu.is_open(), w.controls_enabled, main.state, main.garage_int.busy, w.position.distance_to(p0), main.viina_pullot, main._msg.text])
			Settings.set_v("mouse_steer", false)
		"tallijuoma":
			# Tallissa juominen: T-valikosta viina ja kalja sekä repusta, ohjauksen pitää palata.
			if main.player == main.bike:
				main._toggle_mount()
			main.viina_pullot = 3
			main.beers = 2
			main.pontikka = 1
			main._enter_garage()
			for i in 5:
				await main.get_tree().physics_frame
			var w: CharacterBody3D = main.garage_int.walker
			var press := func(a: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(a)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(a)
				await main.get_tree().process_frame
			for id in ["viina", "kalja", "pontikka"]:
				await press.call("eat")
				var open: bool = main._item_menu.is_open()
				var items: Array = main._item_menu._items.map(func(x): return x[0])
				main._item_menu._sel = items.find(id)
				await press.call("interact")
				for i in 10:
					await main.get_tree().process_frame
				print("TALLIJ %s: valikko auki %s, valikossa %s, ohjaus %s, tila %s, busy %s, viesti '%s'" % [id, open, items,
					w.controls_enabled, main.state, main.garage_int.busy, main._msg.text])
			await press.call("eat")
			await press.call("bell")
			for i in 5:
				await main.get_tree().process_frame
			print("TALLIJ peruutus: ohjaus %s, tila %s" % [w.controls_enabled, main.state])
			w.position = GarageInterior.SPOTS.ovi[0]
			for i in 5:
				await main.get_tree().physics_frame
			await press.call("eat")
			main._item_menu._sel = 0
			await press.call("interact")
			for i in 5:
				await main.get_tree().process_frame
			print("TALLIJ ovella kalja: ohjaus %s, tila %s" % [w.controls_enabled, main.state])
		"syo":
			# Leipähyllystä korvapuusti ja piirakka, sitten T-valikosta syöminen. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var press := func(action: String) -> void:
				await main.get_tree().process_frame  # painallus ennen solmujen _processia (just_pressed samassa ruudussa)
				Input.action_press(action)
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			main._enter_shop()
			main.interior.walker.position = ShopInterior.BAKERY_SPOT
			await main.get_tree().process_frame
			print("SYO shop hint=", main.interior.hint)
			await press.call("interact")
			await press.call("interact")
			print("SYO cart=", main.interior.cart, " hint=", main.interior.hint)
			main.interior.has_paid = true
			main.interior.exited.emit(false)
			await main.get_tree().process_frame
			print("SYO food=", main.food, " inv=", main._stats.text.contains("korvapuusti"))
			main.bucket["puolukka"] = 2
			main.has_chocolate = true
			main.beers = 0  # kalja tarkistetaan erikseen lopussa
			main._toggle_mount()
			for i in 5:
				await main.get_tree().physics_frame
			var n0: float = main.tilat.value("nalka")
			await press.call("eat")
			print("SYO menu=", main._item_menu.is_open(), " items=", main._item_menu._items)
			await press.call("interact")
			print("SYO ate first: nalka %+.2f food=%s msg=%s" % [main.tilat.value("nalka") - n0, main.food, main._msg.text])
			await press.call("eat")
			await press.call("back")
			await press.call("back")
			await press.call("interact")
			print("SYO ate third: nalka total %+.2f bucket=%s choco=%s" % [main.tilat.value("nalka") - n0, main.bucket, main.has_chocolate])
			main.food.clear()
			main.bucket.clear()
			main.has_chocolate = false
			main.beers = 2
			var h0: float = main.tilat.value("humala")
			await press.call("eat")
			print("SYO kalja menu=", main._item_menu._items)
			await press.call("interact")
			print("SYO joi kaljan: humala %+.2f beers=%d msg=%s" % [main.tilat.value("humala") - h0, main.beers, main._msg.text])
			main.beers = 0
			await press.call("eat")
			print("SYO empty menu=%s msg=%s" % [main._item_menu.is_open(), main._msg.text])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"tilat":
			# Päivän tilat: lepo grillikatoksella, kalja, tehtävä, uusi päivä ja hankaluus. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.tilat.chosen = ["stressi", "moraali", "humala"]
			print("TILAT alku ", main.tilat.summary())
			main._toggle_mount()
			main.walker_out.global_position = M.w(M.GRILLIKATOS) + Vector3(1.0, 0.5, 1.0)
			for i in 300:
				await main.get_tree().physics_frame
			print("TILAT lepo grillikatoksella 5 s: ", main.tilat.summary())
			main._drink(2)
			main._task_done(true)
			print("TILAT 2 kaljaa + sivutehtävä: ", main.tilat.summary())
			for i in 5:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_hud.png"))
			var sp0: float = main.wife.speed_mult
			main._new_day(main.home_zone + Vector3(0, 0, 4), false)
			print("TILAT uusi päivä wife %.2f -> %.2f mummot=%.1f koira=%.1f humala=%.2f chosen=%s" % [sp0, main.wife.speed_mult,
				main.mummot.anger_speed, main.stray.bite_dist, main.tilat.value("humala"), main.tilat.chosen])
			print("TILAT viesti: ", main._msg.text.replace("\n", " | "))
			# Krapula: illan humala yli rajan -> aamulla vireys ja keskittyminen -0,3.
			main.tilat.values["humala"] = 0.95
			main._new_day(main.home_zone + Vector3(0, 0, 4), false)
			print("TILAT krapula humala=%.2f vireys=%.2f keskittyminen=%.2f viesti: %s" % [main.tilat.value("humala"),
				main.tilat.value("vireys"), main.tilat.value("keskittyminen"), main._msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"tilat_vaikutukset":
			# Jokaisen tilan palkinto (+0,8) ja haitta (-0,8): mitä _stat_effects ja kulutuskohdat asettavat.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			for k in DayStats.STATS:
				for v in ([0.5, 0.9] if k == "humala" else [0.8, -0.8]):
					main.tilat.chosen = [k, "stressi" if k != "stressi" else "nalka", "moraali" if k != "moraali" else "nalka"]
					for o in DayStats.STATS:
						main.tilat.values[o] = 0.0
					main.tilat.values[k] = v
					main._stat_effects()
					main.interior.price_mult = 1.0 - 0.1 * main.tilat.effect("moraali")
					var inv: Dictionary = main.inventory_info()
					print("VAIKUTUS %s %+.1f eff=%d | mummot %.1f wife %.2f nopeus %.2f kulutus %.1f palautus %.1f juoksu %.2f hyppy %.2f spurtti %.1f eispurttia %s tutka %.0f usva %.0f hinta %.2f käsi %.2f lista %s" % [
						k, v, main.tilat.effect(k), main.mummot.anger_speed, main.wife.speed_mult, main.walker_out.speed_mult, main.walker_out.drain_mult,
						main.walker_out.recover_mult, main.walker_out.run_mult, main.walker_out.jump_mult, main.bike.sprint_mult, main.walker_out.no_sprint,
						main._minimap.range_m, main._env.fog_depth_end, main.interior.price_mult, main._hand_shake(), inv.list])
			# Muut kuin päivän kolme tilaa eivät vaikuta.
			main.tilat.chosen = ["stressi", "moraali", "kipu"]
			main.tilat.values["nalka"] = -0.9
			print("VAIKUTUS nälkä ei päivän tila: eff=%d" % main.tilat.effect("nalka"))
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"tappioko":
			# Tappelun häviö ilman kaljoja ja rahaa: päivä ei pääty, tyrmäys vie tunnin, rahaa ei mene miinukselle.
			for case in [[-1, 0, 3.0], [main.day, 2, 20.0]]:
				main.state = "ulkona"
				main._kuutonen_day = case[0]
				main.beers = case[1]
				main.money = case[2]
				var d0 := main.day
				var c0 := main.clock_min
				var m0: float = main.maine
				main._start_fight("juntti", "juntti", Vector3.RIGHT)
				for i in 150:
					await main.get_tree().process_frame
				main.fight._p.hp = 0.0
				main.fight._p.state = "ko"
				for i in 400:
					await main.get_tree().process_frame
					if main.state != "fight":
						break
				for i in 30:
					await main.get_tree().process_frame
				print("TAPPIO %s: tila %s, päivä %d -> %d, kello +%.0f min, rahaa %.2f, kaljoja %d, maine %.0f -> %.0f, viesti '%s'" % [
					case[0], main.state, d0, main.day, fmod(main.clock_min - c0 + 1440.0, 1440.0), main.money, main.beers, m0, main.maine,
					main._msg.text.replace("\n", " | ")])
				main.juntti.global_position += Vector3(200, 0, 200)
		_:
			return 0
	return 1
