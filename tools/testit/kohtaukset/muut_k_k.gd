extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "muut_k_k". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.

const Main := preload("res://scripts/main.gd")
const B := preload("res://scripts/build.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Mokki := preload("res://scripts/mokki.gd")
const Looks := preload("res://scripts/looks.gd")
const HomeInterior := preload("res://scripts/home_interior.gd")
const KertunRauta := preload("res://scripts/kertun_rauta.gd")
const UkkoLegenda := preload("res://scripts/ukko_legenda.gd")
const KarhutLegenda := preload("res://scripts/karhut_legenda.gd")
const KarhuGame := preload("res://scripts/karhu_game.gd")
const Korkit := preload("res://scripts/korkit.gd")
const KanttoriLegenda := preload("res://scripts/kanttori_legenda.gd")
const ShoreFishGame := preload("res://scripts/shore_fish_game.gd")
const Endings := preload("res://scripts/endings.gd")
const Quests := preload("res://scripts/quests.gd")
const Beast := preload("res://scripts/beast.gd")

const KOHTAUKSET := ["kick", "kello", "korpikalle", "karaokeaito", "karaokesim", "kanttorinyosavel", "karhut", "kalalampi", "kirkko", "koppa", "kieltokyltti", "korkit", "korjaamot", "kertunkangas", "karhukuva", "keskustelu", "keskustelut", "kotisisa", "koillinen", "kotivessa", "kalastus", "koris"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"kick":
			main.player.position = main.juntti.position + Vector3(0, 0.3, 1.2)
		"kello":
			# Vuorokausikello: kulku ulkona, kotona, autotallissa ja mökin tuvassa, tauko pysäyttää, nokoset ja
			# auto-/taksimatka hyppäävät, uusi päivä alkaa klo 8. Kuva HUD:sta.
			if main.player == main.bike:
				main._toggle_mount()
			main.clock_min = 14.0 * 60.0 + 27.0
			var tick := func(label: String) -> void:
				var c0 := main.clock_min
				await main.get_tree().create_timer(2.0).timeout
				print("KELLO %s: %s, +%.2f pelin min / 2 s (tila %s)" % [label, main._clock_text(), main.clock_min - c0, main.state])
			await tick.call("ulkona")
			await RenderingServer.frame_post_draw
			var im := main.get_viewport().get_texture().get_image()
			im.save_png(path.replace(".png", "_hud.png"))
			var crop := im.get_region(Rect2i(0, 0, 380, 130))
			crop.resize(1140, 390, Image.INTERPOLATE_NEAREST)
			crop.save_png(path.replace(".png", "_kello.png"))
			main._enter_home("ovi")
			await tick.call("kotona")
			var c1 := main.clock_min
			main._on_home_acted("sohva")
			print("KELLO nokoset: +%.0f min -> %s" % [main.clock_min - c1, main._clock_text()])
			main._on_home_exited()
			main._enter_garage()
			await tick.call("autotallissa")
			main._on_garage_exited(false)
			var c2 := main.clock_min
			main.get_tree().paused = true
			await main.get_tree().create_timer(2.0, true, false, true).timeout
			main.get_tree().paused = false
			print("KELLO tauolla: +%.2f" % (main.clock_min - c2))
			var c3 := main.clock_min
			main._arrive_by_car(main.mokki.gpos(Mokki.RIDE_LOCAL + Vector3(0, 0.3, 2.2)))
			print("KELLO autolla mökille: +%.0f min -> %s" % [main.clock_min - c3, main._clock_text()])
			await tick.call("mökillä")
			print("KELLO repussa: ", main.inventory_info().lines[0])
			main._new_day(main.home_zone + Vector3(0, 0, 4), false)
			print("KELLO uusi päivä %d: %s" % [main.day, main._clock_text()])
			await main.get_tree().create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_aamu.png"))
		"korpikalle":
			# Korpi-Kalle: osto, kuva pannusta, ratsia karkuun ja kiinni, huikka (lavan rohkeus), myynti lavan pihalla.
			if main.player == main.bike:
				main._toggle_mount()
			main.mokki.ensure_built()
			main.money = 60.0
			main.pontikka = 0
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
			main.walker_out.global_position = main.kalle.to_global(Vector3(0.6, 0.5, -2.2))
			main.walker_out.look_at(main.kalle.global_position + Vector3(0, 0.5, 0), Vector3.UP)
			await frames.call(20)
			print("KALLE pannulla: mökillä %s, hint '%s'" % [main._at_mokki(), main._hint.text])
			await press.call("interact")
			print("KALLE ikkuna: %s" % str(main._talk_box._options.map(func(o): return o.text + ("" if o.enabled else " [" + o.reason + "]"))))
			main._test_talk(["pontikka"])
			print("KALLE osto: pontikka %d rahaa %.2f viesti '%s'" % [main.pontikka, main.money, main._msg.text])
			main._note.visible = false
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.global_position = main.kalle.to_global(Vector3(2.5, 2.0, -4.5))
			cam.look_at(main.kalle.to_global(Vector3(0, 0.8, 0)), Vector3.UP)
			cam.current = true
			for i in 30:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_pannu.png"))
			# Ratsia 1: juostaan karkuun poispäin nimismiehestä.
			main._nimismies_raid()
			await frames.call(10)
			cam.global_position = main._nimismies.global_position + Vector3(3, 2.5, 3)
			cam.look_at(main._nimismies.global_position + Vector3(0, 1.0, 0), Vector3.UP)
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_nimismies.png"))
			cam.current = false
			main.walker_out.activate_camera()
			var away: Vector3 = main.walker_out.global_position - main._nimismies.global_position
			main.walker_out.look_at(main.walker_out.global_position + Vector3(away.x, 0, away.z), Vector3.UP)
			Input.action_press("forward")
			Input.action_press("sprint")
			var w0 := main.walker_out.global_position
			for i in 40:
				await main.get_tree().create_timer(0.5).timeout
				var flee: Vector3 = main.walker_out.global_position - main._nimismies.global_position
				flee.y = 0.0
				if absf(main.walker_out.speed) < 1.0:
					flee = flee.rotated(Vector3.UP, 1.2 if i % 4 < 2 else -1.2)  # puu edessä: sivuun
				main.walker_out.look_at(main.walker_out.global_position + flee, Vector3.UP)
				if i % 2 == 0:
					print("KALLE pako %.1f s: pelaaja liikkunut %.1f m, vauhti %.1f, nimismies %.1f m päässä, alusta %s" % [i * 0.5,
						main.walker_out.global_position.distance_to(w0), main.walker_out.speed, main.walker_out.global_position.distance_to(main._nimismies.global_position),
						main.walker_out.surface])
				if main._nimismies._done:
					break
			Input.action_release("forward")
			Input.action_release("sprint")
			print("KALLE ratsia 1: viesti '%s' pontikka %d rahaa %.2f" % [main._msg.text, main.pontikka, main.money])
			main._nimismies.queue_free()
			main._nimismies = null
			# Ratsia 2: jäädään paikalleen pannulle.
			main.pontikka = 2
			main.walker_out.global_position = main.kalle.to_global(Vector3(0.6, 0.5, -2.2))
			await frames.call(5)
			main._nimismies_raid()
			for i in 20:
				await main.get_tree().create_timer(0.5).timeout
				if main._nimismies._done:
					break
			print("KALLE ratsia 2: viesti '%s' pontikka %d rahaa %.2f" % [main._msg.text, main.pontikka, main.money])
			main._nimismies.queue_free()
			main._nimismies = null
			print("KALLE piilossa %s, myyty tänään %d" % [main.kalle.hiding, main._kalle_sold])
			# Huikka.
			main.pontikka = 1
			main._on_eat("pontikka")
			print("KALLE huikka: pontikka %d rohkeus tänään %s viesti '%s'" % [main.pontikka, main._lava_courage_day == main.day, main._msg.text])
			# Myynti lavan pihalla.
			main.pontikka = 3
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			var mp: CharacterBody3D = main.mopo_trip.mopo
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
			mp.position = vl.lava_door + vl.lava_out * 4.0 + Vector3(0, 0.6, 0)
			for i in 20:
				await main.get_tree().physics_frame
			await press.call("mount")
			await frames.call(10)
			print("KALLE lavan pihalla: hint '%s'" % main._hint.text)
			var m0 := main.money
			for k in 3:
				await press.call("bell")
				print("KALLE myynti %d: pontikka %d rahaa %.2f viesti '%s'" % [k, main.pontikka, main.money, main._msg.text])
		"karaokeaito":
			# Karaoke (Frets on Fire -näppäily) Siitarissa: valikko, lyhennetty aito versio ja oma kappale. Botti näppäilee nuotit:
			# täydellisenä, ja huonona pelaajana (joka toinen ohi, myöhässä). Kuvat joka vaiheesta (ei --headless).
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(name: String) -> void:
				for i in 4:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			main._start_mopo()
			var mp2: CharacterBody3D = main.mopo_trip.mopo
			mp2.position = main.mopo_trip.vaala.siitari_park + Vector3(0, 0.5, 0)
			for i in 10:
				await main.get_tree().physics_frame
			main.mopo_trip.stop()
			main._on_mopo_arrived()
			main._note.visible = false
			main.siitari_int.walker.position = main.siitari_int.spots.karaoke[0]
			var bot := func(kg: CanvasLayer, skill: float, label: String) -> void:
				# Painaa jokaisen nuotin ajallaan (skill 1 = täydellinen; pienempi = osa ohi ja painallukset myöhässä), pitää pitkät.
				var releases := {}
				var shot_done := false
				var n_i := 0
				var st := {}
				while is_instance_valid(kg) and not kg._done:
					await main.get_tree().process_frame
					if not is_instance_valid(kg):
						break
					st = {"hit": kg._hit, "n": kg._notes.size(), "miss": kg._miss, "combo": kg._best_combo, "score": kg._current_score()}
					for n in kg._notes:
						if n.state == "odottaa" and kg._t >= float(n.t) and not n.get("bot", false):
							n["bot"] = true
							n_i += 1
							if skill >= 1.0 or (n_i % 2 == 0 and randf() < skill + 0.3):
								kg.lane_press(n.lane, float(n.t) + (0.0 if skill >= 1.0 else 0.2))
								releases[n.lane] = float(n.t) + maxf(float(n.dur), 0.12)
					for lane in releases.keys():
						if kg._t >= releases[lane]:
							kg.lane_release(lane)
							releases.erase(lane)
					if not shot_done and kg._combo >= 6:
						shot_done = true
						await snap.call("_%s.png" % label)
				print("KARAOKE bot %s: osumia %d / %d, huteja %d, paras putki %d, tulos %.2f" % [label, st.hit, st.n, st.miss, st.combo, st.score])
			main.money = 50.0
			main._on_siitari_acted("karaoke")
			var kg: CanvasLayer = main._karaoke_game()
			print("KARAOKE valikko: %s, rahaa %.2f" % [str(kg.menu_titles.map(func(m): return m[1])), main.money])
			await snap.call("_a_valikko.png")
			kg._menu_i = 1
			kg._choose(1)
			print("KARAOKE aito %s, nuotteja %d, pituus %.1f s, soi %s" % [kg.real, kg._notes.size(), kg._end, kg._track != null and kg._track.playing])
			await bot.call(kg, 1.0, "b_aito_taydellinen")
			await main.get_tree().create_timer(1.0).timeout
			print("KARAOKE aito täydellinen: viesti '%s', tila %s" % [main._msg.text.replace("\n", " "), main.state])
			main.money = 50.0
			main._on_siitari_acted("karaoke")
			kg = main._karaoke_game()
			kg._choose(0)
			print("KARAOKE oma: aito %s, nuotteja %d" % [kg.real, kg._notes.size()])
			await bot.call(kg, 0.4, "c_oma_huono")
			await main.get_tree().create_timer(1.0).timeout
			print("KARAOKE oma huono: viesti '%s', tila %s" % [main._msg.text.replace("\n", " "), main.state])
			var f2 := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f2.store_buffer(saved)
			f2.close()
			main.get_tree().quit()
		"karaokesim":
			# Karaoken vaikeuden kalibrointi: ihmismäinen botti painaa nuotit normaalijakautuneella ajoituksella (sigma s) ja
			# unohtaa osan (huti-%), pitkät irrotetaan hieman etuajassa. Kaksi kappaletta × kolme taitotasoa, nopeutettuna.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main._start_mopo()
			var mp3: CharacterBody3D = main.mopo_trip.mopo
			mp3.position = main.mopo_trip.vaala.siitari_park + Vector3(0, 0.5, 0)
			for i in 10:
				await main.get_tree().physics_frame
			main.mopo_trip.stop()
			main._on_mopo_arrived()
			main._note.visible = false
			var rng := RandomNumberGenerator.new()
			rng.seed = 42
			var levels := [["hyvä", 0.04, 0.02, 0.1], ["keskiverto", 0.08, 0.06, 0.2], ["rento", 0.14, 0.15, 0.3]]
			Engine.time_scale = 4.0
			for song_i in 2:
				for lv in levels:
					main.money = 50.0
					main._on_siitari_acted("karaoke")
					var kg: CanvasLayer = main._karaoke_game()
					kg._choose(song_i)
					if kg._track != null:
						kg._track.stop()  # raita ei seuraa nopeutettua kelloa
					var plan := []
					for n in kg._notes:
						var late: float = rng.randfn(0.0, lv[1])
						plan.append([n, float(n.t) + late, rng.randf() < lv[2], float(n.dur) * rng.randf_range(0.7, 1.0) if lv[3] > 0.0 else float(n.dur)])
					var pressed := []
					var st := {}
					while is_instance_valid(kg) and not kg._done:
						await main.get_tree().physics_frame
						if not is_instance_valid(kg):
							break
						st = {"hit": kg._hit, "n": kg._notes.size(), "miss": kg._miss, "combo": kg._best_combo, "score": kg._current_score()}
						for pl in plan:
							if not pl[2] and not pl[0].get("p", false) and kg._t >= pl[1]:
								pl[0]["p"] = true
								kg.lane_press(pl[0].lane, pl[1])
								pressed.append([pl[0].lane, pl[1] + maxf(pl[3], 0.1)])
						for pr in pressed.duplicate():
							if kg._t >= pr[1]:
								kg.lane_release(pr[0])
								pressed.erase(pr)
					print("KARAOKESIM %-7s %-11s: pisteet %3d %%, osumia %d / %d, huteja %d, paras putki %d" % ["oma" if song_i == 0 else "aito", lv[0], roundi(st.score * 100.0), st.hit, st.n, st.miss, st.combo])
					await main.get_tree().create_timer(0.5).timeout
			Engine.time_scale = 1.0
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"kanttorinyosavel":
			# Kanttorilan yösävel (#144): Hilkka kertoo, teinien kaiutin ja yösävel yöllä, harmooni huutokaupassa, Pirtin arkisto,
			# kuoro- ja Veksi-haara sekä epäilijät. Aja eristetyllä HOME:lla (tallennus).
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			var press_t := func() -> void:
				await main.get_tree().process_frame
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
			var goto_t := func(at: Vector3) -> void:
				main.walker_out.global_position = at + Vector3(0, 0.3, 0)
				for i in 4:
					await main.get_tree().physics_frame
			var kp: Vector3 = main.world.kanttorila_pos
			print("KT Kanttorila: pihan paikka %s (px %s)" % [kp, M.to_px(kp)])
			var wav := KanttoriLegenda.tune("urut")
			print("KT urkuääni: %.1f s, %d tavua; kaiutin %.1f s; kuoro %.1f s" % [wav.data.size() / 2.0 / KanttoriLegenda.RATE, wav.data.size(),
				KanttoriLegenda.tune("kaiutin").data.size() / 2.0 / KanttoriLegenda.RATE, KanttoriLegenda.tune("kuoro").data.size() / 2.0 / KanttoriLegenda.RATE])
			print("KT Hilkka/Sinikka: %s / %s" % [main._talk_options("hilkka").map(func(o): return o.id).has("kanttori_legenda"), main._talk_options("sinikka").map(func(o): return o.id).has("kanttori_legenda")])
			main.kirppis_int.mode = "kirppis"
			main._talk_who = "hilkka"
			main._talk_kirppis("kanttori_legenda")
			print("KT kuultu %s, tehtävät %s" % [main.kanttori.heard, main._kanttori_tasks()])
			main.day = 2
			main.clock_min = 12 * 60
			await goto_t.call(kp)
			for i in 4:
				await main.get_tree().physics_frame
			print("KT päivällä: soi %s, vaihe %d" % [main._kt_player != null and main._kt_player.playing, main._kt_phase])
			main.clock_min = 23 * 60
			await goto_t.call(kp)
			for i in 6:
				await main.get_tree().physics_frame
			print("KT yöllä: teinien kaiutin soi %s (vaihe %d)" % [main._kt_player.playing, main._kt_phase])
			main._kt_player.stop()
			for i in 6:
				await main.get_tree().physics_frame
			print("KT kaiutin loppui: teinit %s, vaihe %d, urut soi %s" % [main.kanttori.teinit, main._kt_phase, main._kt_player.playing])
			main._kt_t = 5.0
			for i in 4:
				await main.get_tree().physics_frame
			print("KT yösävel kuultu %s, tehtävät %s" % [main.kanttori.savel, main._kanttori_tasks()])
			# Huutokauppa: harmooni
			main.clock_min = 12 * 60
			main.day = 4
			main._auction_day = -1
			print("KT huutokauppakohde päivänä 4: %s" % main._auction_lot().get("id", ""))
			main.kanttori.harmooni = true
			print("KT harmooni voitettu, tehtävät %s" % [main._kanttori_tasks()])
			await goto_t.call(main.world.museum_door)
			await press_t.call()
			print("KT Pirtti: arkisto %s, nuotit koossa %s, tehtävät %s" % [main.kanttori.arkisto, main.kanttori.nuotit(), main._kanttori_tasks()])
			print("KT Sinikka: %s, Veksi: %s, veksi auki %s" % [main._talk_options("sinikka").map(func(o): return o.id).has("kanttori_kuoro"), main._talk_options("veksi").map(func(o): return o.id).has("kanttori_myy"), main.kirppis_int.veksi_open])
			# Kuoro
			var m0 := main.maine
			main._talk_who = "sinikka"
			main._talk_kanttori("kanttori_kuoro")
			print("KT kuoro: valinta '%s', maine %.0f -> %.0f, kuoro soi %s, loppu %s" % [main.kanttori.choice, m0, main.maine, main._kt_choir.playing, main.endings.counts.has("kanttorin_virsi")])
			main.clock_min = 23 * 60
			await goto_t.call(kp)
			for i in 6:
				await main.get_tree().physics_frame
			print("KT kuoron jälkeen yöllä: soiko %s (vaihe %d)" % [main._kt_player.playing, main._kt_phase])
			main._talk_who = "pekka"
			var seen := false
			for i in 60:
				if (Main.KANTTORI_PROVEN.pekka as Array).has(main._talk_chat_line()):
					seen = true
					break
			print("KT Pekan todistettu repliikki: %s" % seen)
			# Veksi-haara (uusi tila)
			main.kanttori.choice = ""
			main.money = 10.0
			main._talk_who = "veksi"
			main._talk_kanttori("kanttori_myy")
			print("KT veksi: valinta '%s', rahaa 10 -> %s" % [main.kanttori.choice, main._eur(main.money)])
			main.clock_min = 23 * 60
			await goto_t.call(kp)
			for i in 6:
				await main.get_tree().physics_frame
			print("KT Veksin jälkeen yöllä: soi %s (yösävel jatkuu)" % main._kt_player.playing)
			main.get_tree().quit()
		"karhut":
			# Kuhmon karhut (#250 P12): taksivalinta, opas, kuvaus (karhu keskellä pystyssä), tallennus; kuvat.
			main._note.visible = false
			var kh_shot := func(name: String) -> void:
				for i in 4:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % name))
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.karhut = KarhutLegenda.new()
			print("KH taksivalinta: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "retki_kuhmo").map(func(o): return [o.id, o.enabled, o.text])])
			main._retki_from = main.player.global_position
			main._enter_retki("kuhmo")
			print("KH perillä: state %s, tehtävät %s" % [main.state, main._karhut_tasks()])
			await kh_shot.call("alue")
			main._karhut_acted("opas")
			print("KH opas: puhuttu %s, kupla '%s', tehtävät %s" % [main.karhut.opas, main.retki_int._bubble.text, main._karhut_tasks()])
			main._start_karhut()
			var kh_g: Node = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == KarhuGame)[0]
			print("KH minipeli auki %s, state %s" % [main._minigame_open(), main.state])
			kh_g._spawn()
			kh_g._bears[0].x = 640.0
			kh_g._bears[0].vx = 0.0
			kh_g._bears[0].stand = 30.0
			kh_g._bears[0].size = 0.9
			kh_g._mouse = Vector2(640, 330)
			await main.get_tree().create_timer(1.0).timeout
			await kh_shot.call("peli")
			kh_g._shoot()
			print("KH kuva: paras %d" % kh_g._best)
			kh_g._end()
			await main.get_tree().process_frame
			print("KH valmis: state %s, hyvä %s, paras %d, tehtävät %s, minipeli auki %s" % [main.state, main.karhut.hyva, main.karhut.paras, main._karhut_tasks(), main._minigame_open()])
			main.get_tree().quit()
		"kalalampi":
			# Retkirunko ja Teeriniemen kalalampi (#3): taksivalikko, matka, lupa tiskiltä, onkiminen (kirjolohi, taimen),
			# paluu lähtöpaikkaan ja kello. Kuvat _lampi_*.
			main._note.visible = false
			var kl_shot := func(name: String) -> void:
				for i in 3:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % name))
			var kl_frames := func(n: int) -> void:
				for i in n:
					await main.get_tree().process_frame
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 50.0
			main.kalalupa = false
			main.clock_min = 12 * 60.0
			print("KLP taksivalinnat: %s" % [main._talk_options("taksi").filter(func(o): return o.id.begins_with("retki_")).map(func(o): return [o.id, o.enabled, o.text])])
			var kl_t0 := main.clock_min
			main._retki_from = main.player.global_position
			main._enter_retki("lampi")
			print("KLP perillä: state %s, kello +%.0f min, kohtaus %s" % [main.state, main.clock_min - kl_t0, main.retki_int != null])
			await kl_frames.call(10)
			await kl_shot.call("1_alue")
			main.retki_int.walker.position = main.retki_int.spots.tiski[0]
			await kl_frames.call(4)
			print("KLP tiskillä: spot '%s', vihje '%s'" % [main.retki_int.spot, main._hint.text])
			await kl_shot.call("2_tiski")
			main._on_retki_acted("lampi")
			print("KLP ilman lupaa: state %s (ei peliä: %s)" % [main.state, main.get_children().filter(func(c): return c.get_script() == ShoreFishGame).is_empty()])
			main._on_retki_acted("tiski")
			print("KLP valinnat tiskillä: %s" % [main._talk_options("leirintaalue").map(func(o): return [o.id, o.enabled])])
			main._talk_choose("lupa")
			print("KLP lupa: %s, rahaa %s" % [main.kalalupa, main._eur(main.money)])
			print("KLP lupa uudelleen: %s" % [main._talk_options("leirintaalue").filter(func(o): return o.id == "lupa").map(func(o): return o.enabled)])
			main._talk_box.close()
			await kl_frames.call(4)
			main.retki_int.walker.position = main.retki_int.spots.lampi[0]
			await kl_frames.call(4)
			print("KLP lammella: spot '%s'" % main.retki_int.spot)
			var kl_n := {"kirjolohi": 0, "taimen": 0}
			var kl_g0 := ShoreFishGame.new()
			kl_g0.stocked = true
			for i in 300:
				kl_n[kl_g0._pick_stocked().nom] += 1
			print("KLP lajit 300 arvonnasta: %s" % [kl_n])
			kl_g0.free()
			main._on_retki_acted("lampi")
			var kl_g: Node = main.get_children().filter(func(c): return c.get_script() == ShoreFishGame)[0]
			print("KLP peli: state %s, stocked %s, madot %d" % [main.state, kl_g.stocked, kl_g.worms])
			await kl_frames.call(20)
			await kl_shot.call("3_ranta")
			kl_g._charge = 0.6
			kl_g._cast()
			print("KLP heitto: tila %s, tärppiin %.1f s" % [kl_g._state, kl_g._bite_at - kl_g._t])
			await kl_frames.call(30)
			await kl_shot.call("4_koho")
			for kind in ["kirjolohi", "taimen"]:
				kl_g._state = "idle"
				kl_g._charge = 0.5
				kl_g._cast()
				kl_g._fish = {"nom": kind, "name": kind, "kg": 1.5, "power": 0.5}
				kl_g._hook()
				kl_g._dist = 0.5
				await kl_frames.call(14)
				await kl_shot.call("5_" + kind)
				# Lähikuva kyljestä (sivu +X) ja pinnasta (-Z): kuvion paikka ruumiin pinnalla.
				var kl_cam := Camera3D.new()
				main.add_child(kl_cam)
				for side in [Vector3(0.6, 0, 0), Vector3(0, 0, -0.6)]:
					kl_cam.global_position = kl_g._shown.global_position + Vector3(0, -0.27, 0) + kl_g._shown.global_basis * side
					kl_cam.look_at(kl_g._shown.global_position + Vector3(0, -0.27, 0))
					kl_cam.current = true
					kl_g._shown_t = 5.0
					await kl_shot.call("6_%s_%s" % [kind, "kylki" if side.x > 0.0 else "selka"])
				kl_g._cam.current = true
				kl_cam.queue_free()
			print("KLP saalis: %s, peli-tila %s" % [kl_g.catch, kl_g._state])
			kl_g._state = "end"  # F-lopetus (idle -> end) suoraan: xvfb-ajossa näppäinsyöte ei välity
			kl_g._end_t = 0.5
			await main.get_tree().create_timer(1.0).timeout
			print("KLP jälkeen: state %s, saalis %s, madot (omat) %d" % [main.state, main.saalis, main.madot])
			main._on_retki_exited()
			await main.get_tree().create_timer(14.0).timeout
			print("KLP takaisin: state %s, retki_int %s, etäisyys lähtöpaikasta %.2f m (lähtö %s), kello +%.0f min lähdöstä" % [main.state, main.retki_int, main.player.global_position.distance_to(main._retki_from), main._retki_from, fposmod(main.clock_min - kl_t0, 1440.0)])
			main.get_tree().quit()
		"kirkko":
			# Saloisten kirkko, kellotapuli ja hautausmaa kartan länsilaidalla (#123): kuvat eri suunnista (vain ikkunallisena,
			# headlessinä ohitetaan), hautakivien määrä, kartan länsireuna ja vanhan alueen rajan (x = 0) yli kulkevat tiet.
			main._note.visible = false
			main._hud.visible = false
			var headless := DisplayServer.get_name() == "headless"
			var snap_kk := func(name: String) -> void:
				if headless:
					return
				for i in 8:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			var cam_kk := Camera3D.new()
			cam_kk.far = 1500.0
			main.add_child(cam_kk)
			cam_kk.current = true
			var kk := M.w(M.KIRKKO)
			var tp := M.w(M.KELLOTAPULI)
			print("KIRKKO kirkko %s (px %s), tapuli %s, hautakiviä %d, pääovi %s, tapulin ovi %s" % [kk, M.to_px(kk), tp, main.world.hautausmaa_graves, main.world.kirkko_pos, main.world.tapuli_pos])
			print("KIRKKO pelialue: %s, länsireuna px x %.0f" % [M.PLAY_AREA, M.MAP_MIN.x])
			for v in [["a_etelasta", kk + Vector3(-30, 14, 38), kk + Vector3(0, 5, 0), 55.0], ["b_torni", kk + Vector3(-34, 5.5, 6), kk + Vector3(-16, 7, 0), 45.0],
					["c_tapuli", tp + Vector3(-9, 4.5, -10), tp + Vector3(0, 5, 0), 50.0], ["d_hautausmaa", M.w(Vector2(-175, 470)) + Vector3(0, 95, 55),
					M.w(Vector2(-175, 475)), 55.0], ["e_lansireuna", M.w(Vector2(-195, 470)) + Vector3(6, 3, 0), M.w(Vector2(-260, 470)) + Vector3(0, 4, 0), 70.0],
					["f_maasta", M.w(Vector2(-160, 505)) + Vector3(0, 1.7, 0), M.w(Vector2(-135, 483)) + Vector3(0, 4, 0), 70.0]]:
				cam_kk.fov = v[3]
				cam_kk.look_at_from_position(v[1], v[2])
				await snap_kk.call("_%s.png" % v[0])
			var w_roads := 0
			for r in M.Osm.ROADS:
				var west := false
				var east := false
				for q in r.pts:
					west = west or q.x < -10.0
					east = east or q.x > 10.0
				if west and east:
					w_roads += 1
			print("KIRKKO rajan yli kulkevia teitä: %d" % w_roads)
			main.get_tree().quit()
		"koppa":
			# Karhu-koppa: ensimmäinen kaupasta ostettu kutonen antaa hatun päähän, toinen ei uutta; Päivin reaktio, kodin
			# vaatekaappi (pois ja takaisin) ja koppa joka asussa (edestä, sivulta, takaa, ylhäältä, pää lähikuvina).
			var saved_k := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.has_koppa = false
			Looks.hat = ""
			Looks.outfit = "tuulipuku"
			main.money = 40.0
			main.clock_min = 12.0 * 60.0
			var snap := func(name: String) -> void:
				for f in 8:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			if main.player == main.bike:
				main._toggle_mount()
			for n in 2:
				main._enter_shop()
				main.interior.has_beer = true
				main.interior.has_paid = true
				main.interior.exited.emit(true)
				await main.get_tree().process_frame
				print("KOPPA kutonen %d: koppa %s, hattu '%s', jono %s" % [n + 1, main.has_koppa, Looks.hat,
					str(main._msg_queue).contains("Karhu-koppa päässä")])
				main._msg_queue.clear()
			await snap.call("_pihalla.png")
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			for f in 5:
				await main.get_tree().physics_frame
			main._enter_home("ovi")
			print("KOPPA Päivi: %s" % str(main._msg_queue).contains("Kaljakoppa"))
			main.home_int.walker.position = HomeInterior.SPOTS.vaatekaappi[0]
			for f in 8:
				await main.get_tree().physics_frame
			main._on_home_acted("vaatekaappi")
			print("KOPPA kaappi: %s" % [main._item_menu._items])
			main._item_menu.visible = false
			main._on_wardrobe("koppa")
			print("KOPPA pois: hattu '%s', viesti '%s'" % [Looks.hat, main._msg.text])
			main._on_wardrobe("koppa")
			print("KOPPA takaisin: hattu '%s', viesti '%s'" % [Looks.hat, main._msg.text])
			main._msg.text = ""
			await snap.call("_kotona.png")
			main._on_home_exited()
			var stage := Node3D.new()
			main.add_child(stage)
			stage.global_position = Vector3(5000, 0, 5000)
			var lamp := DirectionalLight3D.new()
			lamp.rotation_degrees = Vector3(-40, 25, 0)
			stage.add_child(lamp)
			var outs := ["tuulipuku", "farkut", "tyovaatteet", "hiihtohaalari"]
			var cs: Array = []
			for i in outs.size():
				var c: Node3D = Looks.make(stage, Looks.player(outs[i]))
				Looks.add_cap(c)
				c.position = Vector3(-1.35 + i * 0.9, 0, 0)
				c.play("Idle", 0.0)
				cs.append(c)
			var cam := Camera3D.new()
			cam.fov = 40.0
			stage.add_child(cam)
			cam.current = true
			main._hud.visible = false
			for k in [["koko", 0.0, Vector3(0, 1.3, 4.6), Vector3(0, 1.1, 0)], ["edesta", 0.0, Vector3(0, 1.8, 1.4), Vector3(0, 1.75, 0)],
					["sivulta", PI * 0.5, Vector3(0, 1.8, 1.4), Vector3(0, 1.75, 0)], ["takaa", PI, Vector3(0, 1.8, 1.4), Vector3(0, 1.75, 0)],
					["vino", PI * 0.25, Vector3(0, 1.95, 1.2), Vector3(0, 1.75, 0)], ["ylhaalta", 0.3, Vector3(0, 3.2, 0.5), Vector3(0, 1.7, 0)]]:
				for c in cs:
					c.rotation.y = PI + k[1]
				cam.look_at_from_position(stage.global_position + k[2], stage.global_position + k[3])
				await snap.call("_%s.png" % k[0])
			# Lähikuvat yhdestä hahmosta: tuulipuku edestä, sivulta, takaa ja ylhäältä aukkoon.
			for k in [["lahi_etu", 0.0, Vector3(0, 1.82, 0.75)], ["lahi_sivu", PI * 0.5, Vector3(0, 1.82, 0.75)],
					["lahi_taka", PI, Vector3(0, 1.85, 0.75)], ["lahi_vino", PI * 0.75, Vector3(0, 1.95, 0.65)],
					["lahi_ylha", 0.2, Vector3(0, 2.45, 0.35)]]:
				cs[0].rotation.y = PI + k[1]
				var hp: Vector3 = cs[0].global_position + Vector3(0, 1.75, 0)
				cam.look_at_from_position(hp + k[2] - Vector3(0, 1.75, 0), hp)
				await snap.call("_%s.png" % k[0])
			Looks.hat = ""
			Looks.outfit = "tuulipuku"
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_k)
			main.get_tree().quit()
		"kieltokyltti":
			# Kodan polun keltainen kieltokyltti: lähikuva edestä ja polulta tulijan silmin.
			print("KYLTTI ", main.world.waste_sign != null, " paikka ", main.world.waste_sign.global_position if main.world.waste_sign else Vector3.ZERO,
				" kodalle %.0f m" % (main.world.waste_sign.global_position.distance_to(main.world.kota.global_position) if main.world.waste_sign else -1.0))
			if main.world.waste_sign == null:
				return 2
			main._note.visible = false
			main._hud.visible = false
			var ws: Node3D = main.world.waste_sign
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.current = true
			cam.fov = 60.0
			for v in [["lahi", Vector3(0.3, 1.4, 3.0), Vector3(0, 1.25, 0)], ["polku", Vector3(-1.5, 1.7, 9.0), Vector3(0, 1.0, 0)]]:
				cam.global_position = ws.to_global(v[1])
				cam.look_at(ws.to_global(v[2]), Vector3.UP)
				for i in 20:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % v[0]))
		"korkit":
			# Pullonkorkit (#290 osa 1): kalja antaa korkin, harvinaisuudet arpoutuvat, tallennus edestakaisin.
			main.korkit = Korkit.new()
			main.tilat.firsts = []
			main._korkki_rng.seed = 290
			main._drink(1)
			print("KORKIT ensimmäinen: %s, korkki-ensikerta %s" % [main.korkit.owned, "korkki" in main.tilat.firsts])
			if main.korkit.owned.size() != 1 or not "korkki" in main.tilat.firsts:
				print("TESTI VIKA kalja ei antanut korkkia")
			var lkm := {"tavallinen": 0, "juhla": 0, "virhe": 0}
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 30000:
				var k := Korkit.roll("kalja", rng)
				lkm[k.split(":")[1]] += 1
				if Korkit.BRANDS[k.split(":")[0]].laji != "kalja":
					print("TESTI VIKA kaljasta limukorkki ", k)
					break
			print("KORKIT tasot 30000: %s" % lkm)
			if absf(lkm.juhla / 30000.0 - Korkit.JUHLA_P) > 0.01 or absf(lkm.virhe / 30000.0 - Korkit.VIRHE_P) > 0.003:
				print("TESTI VIKA harvinaisuudet pielessä")
			main.korkit.add("koffi:virhe")
			main.korkit.add("koffi:virhe")
			var cfg := ConfigFile.new()
			main.korkit.save_to(cfg)
			var k2: RefCounted = Korkit.new()
			k2.load_from(cfg)
			print("KORKIT tallennus: %s, tuplia %d, päiväkirja '%s'" % [k2.owned, k2.tuplat(), main.quest_progress("korkit")])
			if k2.owned != main.korkit.owned or k2.tuplat() != 1:
				print("TESTI VIKA korkkien tallennus")
			# Pullonkeräys ja korkkilaatikko: monta korkkia, myös limuja.
			var ennen: int = main.korkit.owned.values().reduce(func(a, b): return a + b, 0)
			print("KORKIT kasa: %s" % main._korkit_kasa(40))
			var limut: int = main.korkit.owned.keys().filter(func(k): return Korkit.BRANDS[k.split(":")[0]].laji == "limu").size()
			if main.korkit.owned.values().reduce(func(a, b): return a + b, 0) - ennen != 40 or limut == 0:
				print("TESTI VIKA korkkikasa ei antanut 40 korkkia tai limuja")
			# Korkki-Raimo: kaksi tuplaa puuttuvaan, tupla-virhepainos rahaksi; kansion korkkeja ei viedä.
			var d0: int = main.korkit.distinct()
			var t0: int = main.korkit.tuplat()
			main._talk_korkkiraimo("korkki_vaihda")
			print("KORKIT vaihto: erilaisia %d -> %d, tuplia %d -> %d" % [d0, main.korkit.distinct(), t0, main.korkit.tuplat()])
			if main.korkit.distinct() != d0 + 1 or main.korkit.tuplat() > t0 - 2:
				print("TESTI VIKA Raimon vaihto")
			var vk := Korkit.new()
			vk.owned = {"koffi:virhe": 1}
			if vk.take_tuplat(1, "virhe") or vk.owned["koffi:virhe"] != 1:
				print("TESTI VIKA kansion ainoa korkki otettiin")
			# Kultainen MM-korkki: Pekka kertoo paikan, E nostaa kerran, Raimo ostaa.
			main.tilat.first("mmkorkki_legenda")
			main._talk_neighbor("mmkorkki_kysy")
			var mp := main._mmkorkki_pos()
			print("KORKIT mm: paikka %s, Pekka kertoi %s" % [mp, "mmkorkki_pekka" in main.tilat.firsts])
			if mp == Vector3.ZERO:
				print("TESTI VIKA MM-korkin paikkaa ei ole")
			else:
				main._mmkorkki_pick()
				print("KORKIT mm löytyi: %s" % main.korkit.owned.has("mmkorkki"))
				if not main.korkit.owned.has("mmkorkki"):
					print("TESTI VIKA MM-korkki ei löytynyt Pekan päädystä")
			# Korkkiläpsy: panos vain tuplista, peli pyörii (lyönnit), voitetut kansioon; kuvat pelistä.
			for i in 4:
				main.korkit.add("kontio:tavallinen")
			# Juhannuskorkki vain juhannuksena; voittokorkki antaa kaljan; Päivi motkottaa kaljakorkeista.
			var rr := RandomNumberGenerator.new()
			var juhlia := 0
			for i in 3000:
				if Korkit.roll("kalja", rr, false).ends_with(":juhla"):
					juhlia += 1
			print("KORKIT juhannuskorkkeja muulloin: %d" % juhlia)
			if juhlia > 0:
				print("TESTI VIKA juhannuskorkkeja muulloinkin")
			var b0 := main.beers
			main._korkki_rng.seed = 5
			for i in 200:
				main._korkki("kalja")
			print("KORKIT voittokorkit 200 kaljasta: kaljoja +%d" % (main.beers - b0))
			if main.beers - b0 < 1 or main.beers - b0 > 25:
				print("TESTI VIKA voittokorkkien määrä")
			main._msg_queue.clear()
			main._today.erase("paivi_korkit")  # tallennuksesta jäänyt "tänään jo" ei saa estää testiä
			main._paivi_korkit()
			var pv: String = str(main._msg_queue.back()) if not main._msg_queue.is_empty() else ""
			print("KORKIT Päivi: %s" % pv.left(90))
			if not "Montako kaljaa" in pv:
				print("TESTI VIKA Päivi ei motkottanut korkkikansiosta")
			main.korkit.piilossa = true
			main._today.erase("paivi_korkit")
			main._msg_queue.clear()
			main._paivi_korkit()
			if not main._msg_queue.is_empty():
				print("TESTI VIKA Päivi motkotti jemmassa olevasta kansiosta")
			main.korkit.piilossa = false
			# Maastolöydöt: paikat maalla (ei vedessä).
			for lid in main._korkki_loyto_ids():
				var lc := main._korkki_loyto_pos(lid)
				print("KORKIT löytö %s: %s, maasto %.2f" % [lid, lc, Terrain.h(lc.x, lc.z)])
			# Saloisten kaukalo: läpsy kaukalon teinien vieressä (jos iltateinit ovat paikalla).
			if is_instance_valid(main.hs_teens):
				main._lapsy_day = -1
				main._start_korkkilapsy_kaukalo()
				print("KORKIT kaukalo: peli %s, pelaaja piilossa %s" % [main._lapsy_game != null, not main.player.visible])
				if main._lapsy_game != null:
					var lp: Vector3 = main._lapsy_game.global_position
					print("KORKIT kaukalo: pino y %.2f, maasto %.2f" % [lp.y, Terrain.h(lp.x, lp.z)])
					if absf(lp.y - Terrain.h(lp.x, lp.z)) > 0.3:
						print("TESTI VIKA kaukalon läpsy ei ole kaukalon pinnalla")
				if main._lapsy_game == null:
					print("TESTI VIKA kaukalon läpsy ei alkanut")
				else:
					for i in 40:
						await main.get_tree().process_frame
					await RenderingServer.frame_post_draw
					main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_lapsy_kaukalo.png"))
					main._lapsy_game._end(true)
					await main.get_tree().process_frame
					if not main.player.visible:
						print("TESTI VIKA pelaaja jäi piiloon kaukalon läpsyn jälkeen")
			else:
				print("KORKIT kaukalo: iltateinit eivät paikalla, ei tarkistettu")
			main._lapsy_day = -1
			for i in 6:
				main.korkit.add("kontio:tavallinen")
			main._start_mopo()
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			main._mopo_dismount()
			main.clock_min = 19 * 60.0
			for i in 10:
				await main.get_tree().process_frame
			var t_ennen: int = main.korkit.tuplat()
			main._start_korkkilapsy()
			print("KORKIT läpsy: peli %s, pinossa %d, tuplat %d -> %d" % [main._lapsy_game != null,
				main._lapsy_game.stack.size() if main._lapsy_game != null else 0, t_ennen, main.korkit.tuplat()])
			if main._lapsy_game == null or main._lapsy_game.stack.size() != 6 or main.korkit.tuplat() != t_ennen - 3:
				print("TESTI VIKA korkkiläpsy ei alkanut oikein")
			else:
				var lg = main._lapsy_game
				lg._aim = 0.2
				lg._phase = "power"
				lg._power = 0.5
				for i in 40:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_lapsy_tahtays.png"))
				lg._strike(0.05, 0.72)
				await main.get_tree().create_timer(0.45).timeout
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_lapsy_lyonti.png"))
				var n_me: int = lg._won_me.size()
				print("KORKIT läpsy lyönti: sain %d, pinossa %d" % [n_me, lg.stack.size()])
				var d_ennen: int = main.korkit.owned.values().reduce(func(a, b): return a + b, 0)
				lg._end(true)
				await main.get_tree().process_frame
				var d_jalk: int = main.korkit.owned.values().reduce(func(a, b): return a + b, 0)
				print("KORKIT läpsy loppu: korkkeja %d -> %d, peli poissa %s" % [d_ennen, d_jalk, main._lapsy_game == null])
				if main._lapsy_game != null or d_jalk < d_ennen:
					print("TESTI VIKA korkkiläpsyn lopetus")
			# Täysi aukeama palkitaan kerran; kansio päiväkirjan Korkit-välilehdellä (kuva).
			var maine0 := main.maine
			main.korkit.add("koffi:tavallinen")
			main._korkki_rng.seed = 1
			for key in ["koffi:juhla", "kontio:tavallinen", "kontio:juhla", "jaffis:tavallinen", "kolaa:virhe"]:
				main.korkit.add(key)
			print("KORKIT Koffi täysi: palkittu %s, maine %+.0f" % [main.korkit.palkitut, main.maine - maine0])
			if not main.korkit.new_full("koffi") and not "koffi" in main.korkit.palkitut:
				print("TESTI VIKA täyttä aukeamaa ei tunnistettu")
			if main.korkit.new_full("koffi"):
				print("TESTI VIKA aukeama palkittiin kahdesti")
			main._journal.toggle()
			main._journal._set_tab("korkit")
			for i in 4:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_kansio.png"))
			main._journal.toggle()
			# Korkki-Raimo kirppiksellä: kuva salista (seisoo pöytien välissä, ei kenenkään sisällä).
			main._enter_kirppis("kirppis")
			for i in 30:
				await main.get_tree().process_frame
			var rk: Node3D = null
			for n in main.kirppis_int.find_children("*", "Node3D", true, false):
				if n.has_meta("talker") and n.get_meta("talker") == "korkkiraimo":
					rk = n
			var kc := Camera3D.new()
			main.kirppis_int.add_child(kc)
			var rp := main.kirppis_int.to_global(Vector3(-3.0, 0, 0.6))
			kc.look_at_from_position(rp + Vector3(1.6, 1.6, 2.6), rp + Vector3(0, 1.0, 0))
			kc.current = true
			for i in 4:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_raimo.png"))
			main.get_tree().quit()
		"korjaamot":
			# Korjaamot (#142): Volvo rikki ja Korpela korjaa (ilmainen kyyti), Simo korjaa oikosulun ja lataa akun,
			# Heiskasen kaasupullo Sululle (ilmainen kanisteri) ja sammutin, Huhtalan varaosat ja romuauton jemma. Kuvat.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.quests = Quests.new()
			main._volvo_fixed_day = -1
			main._has_kaasu = false
			main._kaasu_given = false
			main._has_sammutin = false
			main._huhtala_day = -1
			main.story.step = "valmis"
			main.day = 10  # 10 % 6 == 4: Volvo rikki
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
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
			main.money = 100.0
			main.beers = 2
			main.clock_min = 10 * 60
			print("KO pekka (rikki): %s" % [opts.call("pekka")])
			var kd: Vector3 = main.world.korpela_door
			var kc := M.w(M.KORPELA)
			var kn := (main.world._osm_fit_at(M.KORPELA).nrm as Vector2)
			await view.call("_korpela.png", kc + Vector3(kn.x, 0, kn.y) * 18.0 + Vector3(5, 5, 0), kc + Vector3(0, 1.5, 0))
			await at.call(kd)
			print("KO korpela: '%s', %s" % [main._hint.text, opts.call("korpela")])
			main._talk_open("korpela", null)
			main._talk_box._pages.clear()
			main._talk_choose("volvo")
			main._talk_box.close()
			print("KO volvo korjattu %s, kello %d, kaljoja %d, pekka: %s" % [main._volvo_fixed_day == main.day, main.clock_min, main.beers, opts.call("pekka")])
			main.ebike.joints = {"moottori": "ruuvi", "akku": "ruuvi", "ohjain": "ruuvi", "kaasu": "ruuvi", "johdot": "teippi"}
			main.ebike.shorted = true
			main.ebike.battery = 0.3
			await frames.call(20)
			await at.call(main.world.simo_pos)
			print("KO simo: '%s', %s" % [main._hint.text, opts.call("simo")])
			await view.call("_simo.png", main.world.simo_pos + Vector3(4, 2.5, 5), main.world.simo_pos + Vector3(-1.5, 1.2, 0))
			main._talk_open("simo", null)
			main._talk_box._pages.clear()
			main._talk_choose("oikosulku")
			main._talk_choose("lataa")
			main._talk_box.close()
			print("KO oikosulku %s, johdot %s, akku %.1f" % [main.ebike.shorted, main.ebike.joints.johdot, main.ebike.battery])
			await frames.call(20)
			await at.call(main.world.heiskanen_door)
			print("KO heiskanen: '%s', %s" % [main._hint.text, opts.call("heiskanen")])
			main._talk_open("heiskanen", null)
			main._talk_box._pages.clear()
			main._talk_choose("osta_kaasu")
			main._talk_choose("sammutin")
			main._talk_box.close()
			print("KO sulo: %s" % [opts.call("sulo")])
			main._talk_open("sulo", main.sulo)
			main._talk_box._pages.clear()
			main._talk_choose("sulo_kaasu")
			main._talk_box.close()
			print("KO kanisteri %s, kaasu annettu %s, rahaa %s" % [main.has_kanister, main._kaasu_given, main._eur(main.money)])
			main.day = 11
			print("KO aamu: '%s'" % main._flowers_morning(false).strip_edges().left(60))
			await frames.call(20)
			var hd: Vector3 = main.world.huhtala_door
			var hc := M.w(M.HUHTALA)
			var hn := (main.world._osm_fit_at(M.HUHTALA).nrm as Vector2)
			var tk: Vector3 = main.world.huhtala_trunk
			await view.call("_huhtala.png", tk + Vector3(10, 7, 10), tk + Vector3(-2, 0.5, 0))
			await at.call(hd)
			print("KO huhtala: '%s', %s" % [main._hint.text, opts.call("huhtala")])
			main._talk_open("huhtala", null)
			main._talk_box._pages.clear()
			main._talk_choose("osa")
			main._talk_box.close()
			await frames.call(20)
			await at.call(main.world.huhtala_trunk)
			print("KO takakontti: '%s'" % main._hint.text)
			main.clock_min = 20 * 60
			await at.call(kd)
			print("KO illalla: '%s'" % main._hint.text)
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"kertunkangas":
			# Kertunkankaan rauta (#122): opastaulu, röykkiön kaivuuyritys, kodan tarina, epäilijät, drooni, suomalmi
			# Aarolle, kuona, kirves isokiven alta, Veksi, Pirtti (loppu) ja Veikon kaljat, sekä Veksin kaupat ja poliisi.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.kertun = KertunRauta.new()
			main.endings = Endings.new()
			main.quests = Quests.new()
			main.tarinat_kuultu = [0]
			main._kertun_sync()
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			var go := func(px: Vector2, off := Vector3(0.8, 0.3, 0)) -> void:
				main.walker_out.global_position = M.w(px) + off
				await frames.call(8)
			var oc := Camera3D.new()
			main.add_child(oc)
			var c0 := M.w(M.KERTUNKANGAS)
			main.clock_min = 13 * 60
			oc.look_at_from_position(c0 + Vector3(-14, 9, 16), c0 + Vector3(-2, 0, -3))
			oc.current = true
			await frames.call(40)
			await snap.call("_roykkiot.png")
			var tp: Vector3 = main.world.kertun_taulu_pos
			oc.look_at_from_position(tp + Vector3(-0.6, 1.4, 0), tp + Vector3(1.6, 1.3, 0))
			await frames.call(10)
			await snap.call("_taulu.png")
			var ik := M.w(KertunRauta.ISOKIVI)
			oc.look_at_from_position(ik + Vector3(8, 4.5, 6), ik + Vector3(5, 0, 7))
			await frames.call(10)
			await snap.call("_kivirivi.png")
			oc.current = false
			main.player.activate_camera()
			main.walker_out.global_position = tp + Vector3(0, 0.3, 0)
			await frames.call(8)
			print("KE taulu: '%s'" % main._hint.text)
			await press.call("interact")
			print("KE taulu luettu (ei legendaa): taulu %s, '%s'" % [main.kertun.taulu, main._msg.text.left(60)])
			await go.call(Vector2(1338, -329))
			print("KE röykkiö: '%s'" % main._hint.text)
			await press.call("interact")
			print("KE kaivu 1: '%s'" % main._msg.text.left(60))
			var kp: Vector3 = main.world.kota.global_position
			main.walker_out.global_position = kp + Vector3(1.0, 0.3, 0)
			main.world.kota.set_fire(true)
			await frames.call(8)
			print("KE kota: '%s'" % main._hint.text)
			main._kertun_heard()
			print("KE kuultu %s, tehtävät %s" % [main.kertun.heard, main._kertun_tasks()])
			var doubt := {}
			for who in ["arto", "annaliisa", "pekka", "reippari"]:
				for i in 15:
					main._talk_who = who
					doubt[main._talk_chat_line()] = true
			print("KE epäilijät: %s" % [Main.KERTUN_DOUBT.keys().filter(func(w): return Main.KERTUN_DOUBT[w].any(func(l): return doubt.has(l)))])
			main.walker_out.global_position = tp + Vector3(0, 0.3, 0)
			await frames.call(8)
			await press.call("interact")
			print("KE taulu: taulu %s, '%s'" % [main.kertun.taulu, main._msg.text.right(80)])
			await go.call(KertunRauta.ISOKIVI, Vector3(2.0, 0.3, 0))
			print("KE isokivi ilman kuvaa: '%s'" % main._hint.text)
			print("KE droonikohde: %s" % [main._drone_pois().any(func(d): return d.id == "kertun_rivi")])
			main._on_drone_photo("kertun_rivi")
			await frames.call(3)
			print("KE kuvattu: %s, isokivi '%s'" % [main.kertun.spotted, main._hint.text])
			await go.call(KertunRauta.MALMI, Vector3(1.0, 0.3, 0))
			print("KE suo: '%s'" % main._hint.text)
			await press.call("interact")
			print("KE malmi %s, tehtävät %s" % [main.kertun.malmi, main._kertun_tasks()])
			print("KE aaro: %s" % [main._talk_options("aaro").map(func(o): return o.id)])
			main._talk_open("aaro", main.aaro)
			main._talk_box._pages.clear()
			main._talk_choose("malmi")
			main._talk_box.close()
			print("KE tunnistettu %s" % main.kertun.malmi_known)
			await go.call(KertunRauta.PAJAKIVI, Vector3(1.2, 0.3, 0.6))
			print("KE pajakivi: '%s'" % main._hint.text)
			await press.call("interact")
			print("KE kuona %s, palat näkyy %s" % [main.kertun.kuona, main.world.kertun_kuona.visible])
			await go.call(KertunRauta.ISOKIVI, Vector3(2.0, 0.3, 0))
			print("KE isokivi: '%s'" % main._hint.text)
			await press.call("interact")
			print("KE kirves %s, '%s', tehtävät %s" % [main.kertun.found, main._msg.text.left(70), main._kertun_tasks()])
			oc.look_at_from_position(ik + Vector3(5, 3, 4), ik)
			oc.current = true
			await frames.call(8)
			await snap.call("_kirves.png")
			oc.current = false
			main.player.activate_camera()
			print("KE veksi auki %s, valinnat %s" % [main.kirppis_int.veksi_open, main._talk_options("veksi").map(func(o): return o.id)])
			main._paper.toggle()
			for i in 4:
				await main.get_tree().process_frame
			main._paper.toggle()
			var md: Vector3 = main.world.museum_door
			main.walker_out.global_position = md + Vector3(0, 0.3, 0)
			await frames.call(8)
			print("KE pirtti: '%s'" % main._hint.text)
			var m0 := main.money
			await press.call("interact")
			print("KE museo: %s, rahaa +%s, loppu %s, loput %d/%d" % [main.kertun.choice, main._eur(main.money - m0), main.endings.counts.has("kertun_rauta"), main.endings.distinct(), Endings.max_count()])
			var proven := {}
			for who in ["arto", "annaliisa", "pekka", "reippari"]:
				for i in 15:
					main._talk_who = who
					proven[main._talk_chat_line()] = true
			print("KE todistettu: %s" % [Main.KERTUN_PROVEN.keys().filter(func(w): return Main.KERTUN_PROVEN[w].any(func(l): return proven.has(l)))])
			main.walker_out.global_position = kp + Vector3(1.0, 0.3, 0)
			await frames.call(8)
			print("KE kota kiitos: '%s'" % main._hint.text)
			var b0 := main.beers
			main._kertun_thanks()
			print("KE kaljat %d -> %d" % [b0, main.beers])
			var d := main.journal_data()
			print("KE päiväkirja: %s" % [d.chapters.back().rows.map(func(r): return str(r[0]).left(30) + ("✔" if r[1] else ""))])
			main.kertun.choice = ""
			main._talk_who = "veksi"
			main._talk_open("veksi", null)
			main._talk_box._pages.clear()
			main._talk_choose("kirves")
			main._talk_box.close()
			print("KE veksi: %s, todistettu %s" % [main.kertun.choice, main.kertun.proven()])
			main.state = "ulkona"
			main._kuutonen_day = main.day
			main._kertun_logic()
			print("KE poliisi: %s, '%s'" % [main.police != null and is_instance_valid(main.police), main._msg.text.left(60)])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"karhukuva":
			# Karhun lähikuvat: kävely sivulta, pystyyn nousu ja karjaisu edestä, laukka sivulta.
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			main._hud.visible = false
			var c0 := main.walker_out.global_position + Vector3(6, 0, 6)
			var b := Beast.new()
			b.kind = "karhu"
			b.target = main.walker_out
			main.add_child(b)
			b.place(c0)
			b.set_physics_process(false)
			b.rotation.y = 0.0
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.current = true
			var shoot := func(name: String, phase: String, speed: float, t: float, secs: float, from: Vector3) -> void:
				b.phase = phase
				b._speed = speed
				b._t = t
				var n := int(secs * 60.0)
				for i in n:
					b._t += 1.0 / 60.0
					b._animate(1.0 / 60.0)
					await main.get_tree().process_frame
				cam.look_at_from_position(b.global_position + from, b.global_position + Vector3(0, 0.9, 0), Vector3.UP)
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % name))
			await shoot.call("kavely", "approach", 2.2, 0.0, 0.6, Vector3(-4.2, 1.2, -0.8))
			b._roar()
			await shoot.call("pysty", "standoff", 0.0, 0.0, 1.4, Vector3(-1.5, 1.5, -4.0))
			b._roar()
			await shoot.call("karjaisu", "standoff", 0.0, 5.0, 0.6, Vector3(-0.8, 1.1, -2.6))
			await shoot.call("laukka", "charge", 9.0, 0.0, 0.37, Vector3(-4.5, 1.0, -0.5))
		"keskustelu":
			# Keskusteluikkuna: Pekka (sienet, haava, kyyti harmaana) ja Arto, kuvat valinnoista ja vastauksesta.
			if main.player == main.bike:
				main._toggle_mount()
			main.bucket = {"kantarelli": 2, "puolukka": 3}
			main.bitten = true
			main.beers = 0
			main.money = 2.0
			main.pekka.set_physics_process(false)
			main.arto.process_mode = Node.PROCESS_MODE_DISABLED
			main._note.visible = false
			var shot := func(name: String) -> void:
				main._msg.text = ""
				main._msg_queue.clear()
				for i in 20:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			main.walker_out.global_position = main.pekka.global_position + Vector3(2.6, 0.5, 1.4)
			main.walker_out.rotation.y = B.yaw_to(main.pekka.global_position - main.walker_out.global_position) + PI
			for i in 10:
				await main.get_tree().physics_frame
			print("KESK vihje '%s'" % main._hint.text)
			await shot.call("_vihje.png")
			main.pekka.say("Perkele, ammuin toissapäivänä neljätoista saatanan kyyhkyä!")
			await shot.call("_vihjekupla.png")
			main.pekka.say("")
			var irow := -1
			for r in Settings.KEY_ROWS.size():
				if "interact" in Settings.KEY_ROWS[r][0]:
					irow = r
			var old_k: int = Settings.keys_of(irow)[0]
			Settings.bind_key(irow, 0, KEY_R)
			await shot.call("_vihje_r.png")
			print("KESK näppäin vaihdettu: '%s'" % main._talk_prompt._key.text)
			Settings.bind_key(irow, 0, old_k)
			for i in 3:
				await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_press("interact")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("interact")
			await shot.call("_pekka.png")
			print("KESK Pekka: %s" % str(main._talk_box._options.map(func(o): return o.text + ("" if o.enabled else " [" + o.reason + "]"))))
			# Numeronäppäin 1 = myy sienet
			var k := InputEventKey.new()
			k.physical_keycode = KEY_1
			k.pressed = true
			Input.parse_input_event(k)
			await main.get_tree().process_frame
			await shot.call("_myyty.png")
			print("KESK myyty: rahaa %.2f, info '%s', auki %s" % [main.money, main._talk_box._info, main._talk_box.is_open()])
			var q := InputEventKey.new()
			q.physical_keycode = KEY_ESCAPE
			q.pressed = true
			Input.parse_input_event(q)
			for i in 3:
				await main.get_tree().process_frame
			print("KESK suljettu: auki %s, ohjaus %s" % [main._talk_box.is_open(), main.walker_out.controls_enabled])
		"keskustelut":
			# Muiden hahmojen keskusteluikkunat: kauppias kassalla ja Korpi-Kalle pannulla.
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			var snap := func(name: String) -> void:
				main._msg.text = ""
				main._msg_queue.clear()
				for i in 20:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			var press := func() -> void:
				await main.get_tree().process_frame
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
			main.money = 9.0
			main._enter_shop()
			for g in main.interior._queue:
				g.queue_free()
			main.interior._queue.clear()
			main.interior.has_beer = true
			main.interior.cart["makkara"] = 3.5
			main.interior.walker.set_carrying(true)
			main.interior.walker.position = main.interior.QUEUE_FRONT
			for i in 10:
				await main.get_tree().physics_frame
			await snap.call("_kassa_vihje.png")
			await press.call()
			await snap.call("_kassa.png")
			print("KESKUSTELUT kauppias: %s" % str(main._talk_box._options.map(func(o): return o.text + ("" if o.enabled else " [" + o.reason + "]"))))
			main._talk_box.close()
			main.mokki.ensure_built()
			main.money = 40.0
			main._kalle_sold = 0
			main.walker_out.global_position = main.kalle.to_global(Vector3(0.6, 0.5, -2.2))
			main.walker_out.look_at(main.kalle.global_position + Vector3(0, 0.5, 0), Vector3.UP)
			main.state = "ulkona"
			main.interior.leave()
			for i in 20:
				await main.get_tree().physics_frame
			await press.call()
			await snap.call("_kalle.png")
			print("KESKUSTELUT Kalle: %s" % str(main._talk_box._options.map(func(o): return o.text)))
		"kotisisa":
			# Kodin sisätila: etuovesta sisään, kuva ylhäältä, jokainen toimintopiste, takaovesta ulos ja sisään,
			# lopuksi nukkumaan parisänkyyn.
			main._toggle_mount()
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			var shot := func(name: String) -> void:
				main._msg.text = ""
				main._note.visible = false
				for i in 20:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			for i in 10:
				await main.get_tree().physics_frame
			print("KOTI ovella: hint '%s'" % main._hint.text)
			await press.call("interact")
			print("KOTI sisällä: tila %s, vihje '%s'" % [main.state, main.home_int.hint])
			await shot.call("_eteinen.png")
			var top := Camera3D.new()
			main.add_child(top)
			top.look_at_from_position(Main.HOME_INT_POS + Vector3(0, 24, 9), Main.HOME_INT_POS + Vector3(0, 0, -0.5))
			top.current = true
			await shot.call("_pohja.png")
			top.queue_free()
			main.home_int.walker.activate()
			var wk: CharacterBody3D = main.home_int.walker
			for id in ["kerrossanky", "suihku", "peili", "sauna", "kahvi", "jaakaappi", "tv", "sohva", "nortti"]:  # WC: vessa-testi
				wk.position = main.home_int.SPOTS[id][0]
				for i in 5:
					await main.get_tree().physics_frame
				var h: String = main.home_int.hint
				await press.call("interact")
				print("KOTI %s: '%s' -> '%s'" % [id, h, main._msg.text.replace("\n", " ")])
				if id == "nortti":
					await shot.call("_nortti.png")
			var count_water := func() -> int:
				var n := 0
				for c in Sfx.get_children():
					if c is AudioStreamPlayer and c.playing and c.stream == Sfx.stream("water"):
						n += 1
				return n
			print("KOTI vesiääniä soi heti: %d" % count_water.call())
			await main.get_tree().create_timer(4.0).timeout  # oikeaa aikaa (testiajo voi pyöriä yli 60 FPS)
			print("KOTI vesiääniä soi 4 s päästä: %d" % count_water.call())
			for c in Sfx.get_children():
				if c is AudioStreamPlayer and c.playing:
					print("KOTI soi: %s db %.1f pitch %.2f pos %.1f/%.1f bus %s" % [c.stream.resource_path, c.volume_db, c.pitch_scale,
						c.get_playback_position(), c.stream.get_length(), c.bus])
			wk.position = main.home_int.SPOTS.takaovi[0]
			for i in 5:
				await main.get_tree().physics_frame
			await press.call("interact")
			var hb2 := main.walker_out.global_position
			print("KOTI takaovesta: tila %s, takaovelta %.1f m, etuovelta %.1f m" % [main.state,
				Vector2(hb2.x - main.home_back_door.x, hb2.z - main.home_back_door.z).length(), Vector2(hb2.x - main.home_door.x, hb2.z - main.home_door.z).length()])
			await shot.call("_takapiha.png")
			var bc := Camera3D.new()
			main.add_child(bc)
			var hf2 := M.HOME_YAW_DIR.normalized()
			bc.look_at_from_position(main.home_back_door - Vector3(hf2.x, 0, hf2.y) * 7.0 + Vector3(0, 2.5, 0), main.home_back_door + Vector3(0, 1.0, 0))
			bc.current = true
			await shot.call("_takaovi_ulkoa.png")
			bc.queue_free()
			main.walker_out.activate_camera()
			main.walker_out.global_position = main.home_back_door + Vector3(0, 0.3, 0)
			for i in 10:
				await main.get_tree().physics_frame
			print("KOTI takaovella: hint '%s'" % main._hint.text)
			await press.call("interact")
			print("KOTI takaovesta sisään: tila %s" % main.state)
			wk.position = main.home_int.SPOTS.sanky[0]
			for i in 5:
				await main.get_tree().physics_frame
			var d0 := main.day
			print("KOTI sängyllä: '%s'" % main.home_int.hint)
			await press.call("interact")
			for i in 30:
				await main.get_tree().process_frame
			print("KOTI nukuttu: päivä %d -> %d, tila %s" % [d0, main.day, main.state])
		"koillinen":
			# Pelialueen koillisnurkka (x > 1000, y < 2500): onko maastoa, puita ja teitä? Kuvat Patotien varrelta.
			var oc := Camera3D.new()
			oc.far = 3000.0
			main.add_child(oc)
			main._msg.text = ""
			main._note.visible = false
			for spot in [["_patotie", Vector2(1470, 2300), Vector2(1470, 2700)], ["_ylhaalta", Vector2(1300, 2200), Vector2(1300, 2201)]]:
				var a3 := M.w(spot[1])
				var b3 := M.w(spot[2])
				if spot[0] == "_ylhaalta":
					oc.look_at_from_position(a3 + Vector3(0, 450, 300), a3)
				else:
					oc.look_at_from_position(a3 + Vector3(0, 3, 0), b3 + Vector3(0, 2, 0))
				oc.current = true
				for i in 40:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", spot[0] + ".png"))
			print("KOILLINEN maaston korkeus %.1f, pinta %s" % [Terrain.h(M.w(Vector2(1300, 2200)).x, M.w(Vector2(1300, 2200)).z),
				main.world.surface_at(M.w(Vector2(1300, 2200)))])
		"kotivessa":
			# Kodin WC: sisään etuovesta, kävely tupakeittiöstä WC:hen pöntön eteen, E -> valikko -> ykkönen -> minipeli.
			main._toggle_mount()
			main.state = "ulkona"
			main._enter_home("ovi")
			for i in 5:
				await main.get_tree().process_frame
			var w: CharacterBody3D = main.home_int.walker
			# Kävellen: etuovelta suoraan eteenpäin tupakeittiöön, vasemmalle WC:n ovelle ja sisään pöntön luo.
			var kylpy := OS.get_cmdline_user_args().has("--kylpy")
			var route: Array = [Vector3(-2.5, 0, 0.5), Vector3(-2.5, 0, 4.0), Vector3(1.2, 0, 4.0), Vector3(1.2, 0, 2.75)] if kylpy \
				else [Vector3(-2.5, 0, 0.5), Vector3(-5.0, 0, 0.5), Vector3(-8.6, 0, 0.5)]
			for tgt in route:
				for i in 240:
					var to: Vector3 = tgt - w.position
					to.y = 0.0
					if to.length() < 0.25:
						break
					w.position += to.normalized() * minf(0.06, to.length())
					w.velocity = Vector3.ZERO
					await main.get_tree().physics_frame
			for i in 3:
				await main.get_tree().process_frame
			print("KOTIVESSA paikka=%s vihje=%s" % [w.position, main.home_int.hint])
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_wc.png"))
			await main.get_tree().process_frame  # kuvakaappauksen jälkeen: painallus ruudun alkuun
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			for i in 3:
				await main.get_tree().process_frame
			print("KOTIVESSA valikko auki=%s tila=%s" % [main._item_menu.is_open(), main._menu_mode])
			if main._item_menu.is_open():
				main._item_menu.visible = false
				main._item_menu.chosen.emit("ykkonen")
				for i in 5:
					await main.get_tree().process_frame
				print("KOTIVESSA minipeli käynnissä=%s" % [is_instance_valid(main._wc_game) and main._wc_game.is_inside_tree()])
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_peli.png"))
		"kalastus":
			# Kalastus rannalta ja Tekojärven Ukko: kalapaikat, onki Oravajärvellä (heitto, nykäisy, saalis), virveli
			# tekojärvellä (Ukko katkaisee siiman), lusikka kirppikseltä, iltahuipennus ja Pirtti. Kuvat _kala_*.
			# Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(suffix: String) -> void:
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", suffix))
			var frames := func(n: int) -> void:
				for i in n:
					await main.get_tree().process_frame
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.ukko = UkkoLegenda.new()
			print("KALA paikat: orava %s, tekojärvi %s" % [main._kala_spot("orava"), main._kala_spot("tekojarvi")])
			var go := func(id: String) -> void:
				var sp: Array = main._kala_spot(id)
				main.walker_out.global_position = sp[0] + Vector3(0, 0.3, 0)
				main.walker_out.velocity = Vector3.ZERO
				for i in 20:
					await main.get_tree().physics_frame
				await main.get_tree().process_frame
			# Ei välineitä: vihje.
			main.has_onki = false
			main.has_virveli = false
			await go.call("orava")
			print("KALA ilman: '%s'" % main._hint.text)
			# Onki Sepolta: pysyvä, matoja mukana.
			main._seppo_choose("osta_onki")
			print("KALA onki %s, madot %d" % [main.has_onki, main.madot])
			await frames.call(3)
			print("KALA vihje: '%s'" % main._hint.text)
			main._start_shore_fishing("orava", "onki")
			var g: Node = main.get_children().filter(func(c): return c.get_script() == ShoreFishGame)[0]
			await frames.call(20)
			await snap.call("_kala_onki_ranta.png")
			g._charge = 0.6
			g._cast()
			await frames.call(30)
			await snap.call("_kala_onki_koho.png")
			g._bite_at = g._t
			await frames.call(3)
			g._fish = {"nom": "ahven", "name": "ahvenen", "kg": 0.45, "power": 0.4}
			g._hook()
			await frames.call(20)
			await snap.call("_kala_onki_vasytys.png")
			g._dist = 0.5
			await frames.call(12)
			await snap.call("_kala_onki_saalis.png")
			print("KALA onki saalis %s, madot %d" % [g.catch, g.worms])
			Input.action_press("mount")
			await frames.call(2)
			Input.action_release("mount")
			await frames.call(150)
			print("KALA jälkeen: state %s, madot %d, saalis %s, msg '%s'" % [main.state, main.madot, main.saalis, main._msg.text])
			# Virveli kirppikseltä, legenda kuultu, tekojärvellä Ukko katkaisee siiman.
			main.has_virveli = true
			main.ukko.heard = true
			print("KALA lusikka piilossa (ei vihjeitä): %s" % main._kirppis_hidden("lusikka"))
			main.clock_min = 14 * 60.0
			await go.call("tekojarvi")
			print("KALA tekojärvi vihje: '%s'" % main._hint.text)
			main._start_shore_fishing("tekojarvi", "virveli")
			g = main.get_children().filter(func(c): return c.get_script() == ShoreFishGame)[0]
			print("KALA snap-tila %s, ready %s" % [g.ukko_snap, g.ukko_ready])
			await frames.call(10)
			g._charge = 1.0
			g._cast()
			await frames.call(10)
			await snap.call("_kala_virveli_heitto.png")
			g._fish = {"nom": "?", "power": 2.0, "snap": true}
			g._strike()
			g._snap_at = g._t + 1.0
			await frames.call(20)
			await snap.call("_kala_ukko_iskee.png")
			for i in 400:
				if g.snaps > 0:
					break
				await main.get_tree().process_frame
			print("KALA snaps %d, msg '%s'" % [g.snaps, g._msg.text])
			g._state = "idle"
			Input.action_press("mount")
			await frames.call(2)
			Input.action_release("mount")
			await frames.call(60)
			main.ukko.siimat += 1
			print("KALA siimat %d, vihjeet %s, lusikka piilossa %s, tehtävät %s" % [main.ukko.siimat, main.ukko.clues(), main._kirppis_hidden("lusikka"), main._ukko_tasks()])
			main.ukko.lusikka = true
			print("KALA tehtävät lusikalla %s" % [main._ukko_tasks()])
			# Huipennus illalla Kaitasaaren kärjestä.
			main.clock_min = 20 * 60.0 + 30.0
			await go.call("tekojarvi")
			main._start_shore_fishing("tekojarvi", "virveli")
			g = main.get_children().filter(func(c): return c.get_script() == ShoreFishGame)[0]
			print("KALA ilta: lure %s, ready %s" % [g.lure, g.ukko_ready])
			await frames.call(10)
			g._charge = 1.0
			g._cast()
			await frames.call(5)
			g._fish = g.UKKO.duplicate()
			g._strike()
			await frames.call(40)
			await snap.call("_kala_ukko_vasytys.png")
			g._dist = 0.5
			await frames.call(25)
			await snap.call("_kala_ukko_kiinni.png")
			for i in 1000:
				if not is_instance_valid(g):
					break
				await main.get_tree().process_frame
			await frames.call(5)
			print("KALA Ukko kiinni %s, päivä %d, tehtävät %s, veksi %s" % [main.ukko.caught, main._ukko_day, main._ukko_tasks(),
				main._talk_options("veksi").map(func(o): return o.id) if main.kirppis_int != null else "?"])
			await frames.call(5)
			print("KALA vapautusvihje: '%s'" % main._hint.text)
			main._inventory.toggle()
			await frames.call(5)
			await snap.call("_kala_reppu.png")
			main._inventory.toggle()
			main._ukko_release()
			print("KALA valinta %s, loppu %s, todistettu %s" % [main.ukko.choice, main.endings.counts.has("ukko_vapaa"), main.ukko.proven()])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"koris":
			# Koripallo kentän laidan korilla: kori pelimaailmassa, sitten pelin vaiheet kuviksi: alku, lataus, lento,
			# kori (verkko heilahtaa), ohi (pojat nauraa), rengas, heittopaikan vaihto, voitto ja kalja. Tallennus palautetaan.
			var saved_k := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var kshot := func(name: String) -> void:
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % name))
			var kframes := func(n: int) -> void:
				for i in n:
					await main.get_tree().process_frame
			if main.player != main.walker_out:
				main._toggle_mount()
			main._hud.visible = false
			var hoop: Node3D = main.world.kentta_hoop
			main.walker_out.global_position = hoop.to_global(Vector3(2.5, 0, 9.0)) + Vector3(0, 0.5, 0)
			main.walker_out.rotation.y = B.yaw_to(hoop.global_position - main.walker_out.global_position)
			main.walker_out.velocity = Vector3.ZERO
			await kframes.call(90)
			await kshot.call("kentta")
			var beers0 := main.beers
			main._boys_field = "saloinen"
			main._start_basket()
			await kframes.call(15)
			var g: Node = main._basket_game
			await kshot.call("alku")
			var throw := func(pw: float, label: String) -> void:
				g._phase = "lataa"
				g._power = pw
				g._lmb = true
				await kframes.call(2)
				g._power = pw
				g._release(pw)
				var shot_done := false
				for f in 400:
					await main.get_tree().process_frame
					if not shot_done and label != "" and (g._scored or g._clang_t > 0.0):
						shot_done = true
						await kframes.call(2)
						await kshot.call(label)
					if g._phase != "lento":
						break
				print("KORIS heitto %.2f: kori %s, putki %d, vaihe %s, poika '%s'" % [pw, g._scored, g.streak, g._phase, g._bubbles[1].text + " / " + g._bubbles[0].text])
				for f in 200:
					if g._phase in ["kasissa", "voitto"]:
						break
					await main.get_tree().process_frame
			g._phase = "lataa"
			g._power = 0.5
			g._lmb = true
			await kframes.call(1)
			g._power = 0.5
			await kshot.call("lataus")
			g._phase = "kasissa"
			await throw.call(0.5, "kori")
			await throw.call(0.0, "")
			await kframes.call(1)
			await kshot.call("ohi")
			await throw.call(0.72, "rengas")
			g.streak = 3
			await throw.call(0.5, "")
			await kframes.call(5)
			await kshot.call("paikka")
			g.streak = 15
			await throw.call(0.5, "")
			await kframes.call(20)
			await kshot.call("voitto")
			await main.get_tree().create_timer(4.5).timeout
			print("KORIS loppu: peli %s, kaljat %d -> %d, ennätys %d, viesti '%s'" % [main._basket_game, beers0, main.beers, main.koris_best, main._msg.text.replace("\n", " | ")])
			await kframes.call(30)
			await kshot.call("loppu")
			if not saved_k.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_k)
		_:
			return 0
	return 1
