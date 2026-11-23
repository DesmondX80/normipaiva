extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "muut_k_o". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const B := preload("res://scripts/build.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Mokki := preload("res://scripts/mokki.gd")
const ChopGame := preload("res://scripts/chop_game.gd")
const SawGame := preload("res://scripts/saw_game.gd")
const LavaGame := preload("res://scripts/lava_game.gd")
const HumppaBand := preload("res://scripts/humppa_band.gd")
const PingisGame := preload("res://scripts/pingis_game.gd")
const TiskiGame := preload("res://scripts/tiski_game.gd")
const Headphones := preload("res://scripts/headphones.gd")
const TrafficCar := preload("res://scripts/traffic_car.gd")
const ManamansaloLegenda := preload("res://scripts/manamansalo_legenda.gd")
const KuvakirkkoLegenda := preload("res://scripts/kuvakirkko_legenda.gd")
const KuvakirkkoGame := preload("res://scripts/kuvakirkko_game.gd")
const MuistokylttiGame := preload("res://scripts/muistokyltti_game.gd")
const Quests := preload("res://scripts/quests.gd")
const KeinuGame := preload("res://scripts/keinu_game.gd")
const WcGame := preload("res://scripts/wc_game.gd")
const Story := preload("res://scripts/story.gd")

const KOHTAUKSET := ["matkaopas", "kuutonen", "laavu", "laavufire", "kuulokkeet", "lavatoiveet", "lavatappelu", "lemmikkienkelit", "koulukeskus", "koulu_disko", "kuvakirkko", "manamansalo", "kuninkaantapuli", "olavinmarkkinat", "leikki", "ohjerivi", "lappupekka2", "lappupekka", "lappu", "mummotesti", "marjapaikat", "liikenne", "minimouse", "nappaimet", "naapurit", "naapurit2", "naapurit3", "kupla", "minipelikuvat", "mkey", "mirkku_loppu", "mirkku", "laavut", "mummokeppi", "mummot", "lawnday", "lawn", "police", "lansi_maasto"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"matkaopas":
			# Matkaopas (B): ei opasta, saaminen taksikuskilta, tyhjä, osa kuultu, kaikki käyty (tools/testit/matkaopas.gd).
			var saved_mo := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			var mo: Node = load("res://tools/testit/matkaopas.gd").new()
			mo.main = main
			main.add_child(mo)
			await mo.run()
			if not saved_mo.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_mo)
			main.get_tree().quit()
			return 2
		"kuutonen":
			# Kuutonen kädessä jalan: seisten edestä, sivulta ja takaa, sitten kävellen ja juosten sivulta.
			if main.player != main.walker_out:
				main._toggle_mount()
			main.beers = 6
			main._set_beer_carry()
			main._hud.visible = false
			var kc := Camera3D.new()
			kc.fov = 40.0
			main.add_child(kc)
			var ksnap := func(name: String, local_eye: Vector3, at := Vector3(0, 0.9, 0)) -> void:
				var w := main.walker_out.global_transform
				kc.look_at_from_position(w * local_eye, w * at)
				kc.current = true
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			for i in 30:
				await main.get_tree().process_frame
			await ksnap.call("_edesta.png", Vector3(0, 1.1, -3.2))
			await ksnap.call("_sivu.png", Vector3(-3.2, 1.1, 0))
			await ksnap.call("_takaa.png", Vector3(0.8, 1.3, 3.0))
			var hand := Vector3(main.walker_out._body.bone_position("hand_r").x, 0.65, 0)
			await ksnap.call("_lahi_edesta.png", hand + Vector3(0.3, 0.2, -1.2), hand)
			await ksnap.call("_lahi_takaa.png", hand + Vector3(0.3, 0.3, 1.2), hand)
			await ksnap.call("_lahi_ulko.png", hand + Vector3(1.2 * signf(hand.x), 0.2, 0), hand)
			for act in ["forward", "sprint"]:
				Input.action_press(act)
				for k in 3:
					for i in 9:
						await main.get_tree().process_frame
					await ksnap.call("_%s%d.png" % [act, k], Vector3(2.6 * signf(hand.x), 1.0, 0), Vector3(hand.x, 0.8, 0))
					await ksnap.call("_%s%d_taka.png" % [act, k], Vector3(1.4 * signf(hand.x), 1.2, 2.2), Vector3(hand.x, 0.7, 0))
			Input.action_release("forward")
			Input.action_release("sprint")
			main.get_tree().quit()
		"laavu":
			main.player.position = M.w(M.LAAVU) + Vector3(0, 0.3, -18)
			main.player.rotation.y = PI
		"laavufire":
			main.player.position = M.w(M.LAAVU) + Vector3(-3.0, 0.3, -7.0)
			main.player.rotation.y = PI - 0.4
			main.world.fire.visible = true
			main.guard.mode = "gone"
			main.guard.visible = false
		"kuulokkeet":
			# Valcon kuulokkeet: autotallin laatikosta, H päähän (väylien suotimet päälle, biisi soi), N seuraava, H pois.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(name: String) -> void:
				for i in 15:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var press := func(action: String) -> void:
				await main.get_tree().process_frame  # kuvakaappauksen jälkeen: painallus seuraavan ruudun alkuun
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			main.headphones.found = false
			if main.player != main.walker_out:
				main._toggle_mount()
			main._note.visible = false
			main._enter_garage()
			main.garage_int.walker.position = main.garage_int.SPOTS.laatikko[0]
			for i in 5:
				await main.get_tree().process_frame
			print("KUULOKKEET laatikolla vihje '%s'" % main._hint.text)
			await snap.call("_talli.png")
			await press.call("interact")
			print("KUULOKKEET löydetty %s, laatikko näkyy %s, viesti '%s'" % [main.headphones.found, main.garage_int._box.visible, main._msg.text])
			main._on_garage_exited(false)
			for i in 5:
				await main.get_tree().process_frame
			print("KUULOKKEET lista %s" % [Headphones.playlist()])
			await press.call("headphones")
			var amb := AudioServer.get_bus_index("Ambience")
			var sfx := AudioServer.get_bus_index("SFX")
			print("KUULOKKEET päässä %s, soi %s '%s', ambience-suotimet %s/%s, sfx %s, HUD '%s'" % [main.headphones.on,
				main.headphones._player.playing and not main.headphones._player.stream_paused, main.headphones.title,
				AudioServer.is_bus_effect_enabled(amb, main.headphones._fx.Ambience[0]), AudioServer.is_bus_effect_enabled(amb, main.headphones._fx.Ambience[1]),
				AudioServer.is_bus_effect_enabled(sfx, main.headphones._fx.SFX[0]), main._hp_label.text])
			await snap.call("_paassa.png")
			var t1: String = main.headphones.title
			await press.call("next_song")
			print("KUULOKKEET seuraava '%s' -> '%s'" % [t1, main.headphones.title])
			await press.call("headphones")
			print("KUULOKKEET pois: päässä %s, tauolla %s, suotimet %s, HUD näkyy %s" % [main.headphones.on, main.headphones._player.stream_paused,
				AudioServer.is_bus_effect_enabled(amb, main.headphones._fx.Ambience[0]), main._hp_label.visible])
			var f := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f.store_buffer(saved)
			f.close()
			main.get_tree().quit()
		"lavatoiveet":
			# Oulujärven lava: bändin iskelmätoiveet (äänitteet) ja DJ:n diskotoiveet, bändi vaihtaa biisin itse.
			var _save_bak := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.mokki.ensure_built()  # mopomatka lähtee mökiltä
			main.day = 6
			main.clock_min = 21.5 * 60.0
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			main._note.visible = false
			main.money = 100.0
			var snap := func(name: String) -> void:
				for i in 25:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			main._mopo_dismount()
			main._enter_lava(true)
			var lg: Node3D = main._lava_game
			var band: Node3D = lg._band
			for i in 10:
				await main.get_tree().process_frame
			print("TOIVEET ohjelmisto %d: %s" % [HumppaBand.repertoire().size(), HumppaBand.repertoire().map(func(sg): return sg.title)])
			for t in ["Pihalla tavataan", "Rasvanappi"]:
				if not HumppaBand.repertoire().any(func(sg: Dictionary) -> bool: return sg.title == t):
					print("TESTI VIKA lavan toivelistalta puuttuu %s" % t)
			print("TOIVEET bändi soittaa '%s' (%s), bpm %.0f, musiikki '%s'" % [band.current_song.get("title", ""),
				band.current_song.get("path", "synth"), band.bpm, Sfx._music_file])
			await press.call("forward")
			await press.call("back")
			await press.call("back")
			print("TOIVEET bändin lista auki %s, valinta %d" % [lg._menu >= 0, lg._menu])
			await snap.call("_bandilista.png")
			await press.call("interact")
			for i in 10:
				await main.get_tree().process_frame
			print("TOIVEET toivottu: bändi '%s', bpm %.0f, musiikki '%s', teksti '%s'" % [band.current_song.get("title", ""), band.bpm,
				Sfx._music_file, lg._info.text.get_slice("\n", 0)])
			await snap.call("_bandi.png")
			band._song_left = 0.05
			for i in 10:
				await main.get_tree().process_frame
			print("TOIVEET äänite loppui -> bändi '%s', musiikki '%s'" % [band.current_song.get("title", ""), Sfx._music_file])
			await press.call("back")
			await press.call("back")
			print("TOIVEET DJ:n lista auki %s (%s), valinta %d" % [lg._menu >= 0, lg._menu_kind, lg._menu])
			await snap.call("_djlista.png")
			await press.call("interact")
			for i in 10:
				await main.get_tree().process_frame
			print("TOIVEET DJ: tila %s/%s, musiikki '%s', teksti '%s'" % [lg._mode, lg._phase, Sfx._music_file, lg._info.text.get_slice("\n", 0)])
			await snap.call("_disko.png")
			for k in 3:
				for i in 60:
					await main.get_tree().process_frame
				print("TOIVEET disko kamera %s, minä %s" % [lg.to_local(lg._cam.global_position), lg._me.position])
				await snap.call("_disko%d.png" % (k + 1))
			lg._t = LavaGame.SONG
			for i in 5:
				await main.get_tree().process_frame
			lg._back_to_hall()
			for i in 10:
				await main.get_tree().process_frame
			print("TOIVEET takaisin saliin: bändi '%s', musiikki '%s'" % [band.current_song.get("title", ""), Sfx._music_file])
			lg._leave()
			var _sf := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			_sf.store_buffer(_save_bak)
			_sf.close()
			main.get_tree().quit()
		"lavatappelu":
			# Lavan järkkäri (#183): tappelu Vaalan lavan pihalla, voitto ja tappio, tilan palautuminen. Eristetyllä HOME:lla.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			main._note.visible = false
			main._mopo_dismount()
			var yard_door: Dictionary = vl.doors.filter(func(d): return d.id == "pihanuoret")[0]
			main.walker_out.global_position = main.mopo_trip.to_global(yard_door.pos + yard_door.out * 2.0 + Vector3(0, 0.5, 0))
			for i in 10:
				await main.get_tree().process_frame
			for round_i in 2:
				main.day = 3 + round_i
				main.clock_min = 21 * 60
				main.money = 20.0
				main.maine = 20.0
				main._nuoret_yard = true
				main._talk_who = "nuoret"
				var opt: Dictionary = main._talk_options("nuoret").filter(func(o): return o.id == "jarkkari")[0]
				print("LT %d valinta: %s (%s)" % [round_i, opt.enabled, opt.reason])
				var st0 := main.state
				main._talk_choose("jarkkari")
				for i in 5:
					await main.get_tree().process_frame
				print("LT %d tila %s -> %s, tappelu käynnissä %s, lähde %s" % [round_i, st0, main.state, main.fight != null, main._fight_source])
				if round_i == 0:
					main._on_fight_finished(true, 0, 0)
				else:
					main._on_fight_finished(false, 0, 0)
				for i in 5:
					await main.get_tree().process_frame
				print("LT %d tulos: tila %s, maine 20 -> %.0f, rahaa 20 -> %s, hud %s, uudestaan mahdollinen %s" % [round_i, main.state, main.maine, main._eur(main.money), main._hud.visible,
					main._talk_options("nuoret").filter(func(o): return o.id == "jarkkari").map(func(o): return o.enabled)])
			main.get_tree().quit()
		"lemmikkienkelit":
			# Lemmikki Enkelit (#148): rakennus, lehto, penkki, Pekan hetki, poikien hamsteritehtävä ja muistokyltin minipeli sekä
			# pysyvä rauha poikien kanssa. Aja eristetyllä HOME:lla (tallennus). Kuvat vain ikkunallisena.
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			var headless := DisplayServer.get_name() == "headless"
			var snap_l := func(name: String) -> void:
				if headless:
					return
				for i in 8:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var goto_l := func(at: Vector3) -> void:
				main.walker_out.global_position = at + Vector3(0, 0.3, 0)
				for i in 4:
					await main.get_tree().physics_frame
			var press_l := func() -> void:
				await main.get_tree().process_frame
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
			print("LE lehto %s, penkki %s, portti %s (px %s), rakennus %s" % [main.world.lehto_pos, main.world.lehto_penkki_pos, main.world.lehto_portti_pos, M.to_px(main.world.lehto_pos), M.w(M.LEMMIKKI)])
			var cam_l := Camera3D.new()
			cam_l.far = 1500.0
			main.add_child(cam_l)
			cam_l.current = true
			var f: Dictionary = main.world._osm_fit_at(M.LEMMIKKI)
			var nrm: Vector2 = f.nrm
			var front: Vector2 = f.c + nrm * (f.d / 2.0)
			var views := []
			var sp: Vector2 = front + nrm * 14.0
			views.append(["a_julkisivu", Vector3(sp.x, Terrain.h(sp.x, sp.y) + 3.0, sp.y), Vector3(front.x, Terrain.h(front.x, front.y) + 3.0, front.y), 60.0])
			var up: Vector2 = front + nrm * 20.0
			views.append(["b_lehto", Vector3(up.x, Terrain.h(up.x, up.y) + 9.0, up.y), main.world.lehto_pos + Vector3(0, 0.5, 0), 55.0])
			views.append(["c_penkki", main.world.lehto_pos + Vector3(2.6, 1.6, 4.4), main.world.lehto_penkki_pos + Vector3(0, 0.6, 0), 55.0])
			for v in views:
				cam_l.fov = v[3]
				cam_l.look_at_from_position(v[1], v[2])
				await snap_l.call("_%s.png" % v[0])
			cam_l.current = false
			main.player.activate_camera()
			main.day = 3
			main.clock_min = 12 * 60
			await goto_l.call(main.world.lehto_penkki_pos + Vector3(0, 0, -0.3))
			print("LE penkin vihje: '%s'" % main._hint.text)
			main.beers = 2
			await main.get_tree().physics_frame
			print("LE penkin vihje kaljalla: '%s'" % main._hint.text)
			var st0: float = main.tilat.value("stressi")
			await press_l.call()
			print("LE penkki: stressi %.2f -> %.2f, viesti '%s'" % [st0, main.tilat.value("stressi"), main._msg.text.replace("\n", " ")])
			print("LE lehdon vihje (ei tehtävää): '%s'" % main._hint.text)
			await goto_l.call(main.world.lehto_pos)
			print("LE lehdon vihje: '%s'" % main._hint.text)
			# Pekan hetki
			main.clock_min = 17 * 60
			await goto_l.call(main.world.lehto_portti_pos)
			for i in 6:
				await main.get_tree().physics_frame
			print("LE Pekan hetki: nähty %s" % main.lemmikki.pekka)
			# Poikien tehtävä
			main.day = 4
			main._spawn_boys()
			main._ball_quest = "done"
			main.boys.play_ball()
			print("LE pojat: %s" % [main._talk_options("pojat").map(func(o): return o.id)])
			main._talk_who = "pojat"
			main._talk_lemmikki("lemmikki_kysy")
			print("LE kerrottu: %s, tehtävät %s" % [main.lemmikki.stage, main._lemmikki_tasks()])
			await goto_l.call(main.world.lehto_pos)
			print("LE lehdon vihje: '%s'" % main._hint.text)
			await press_l.call()
			var mg: Node = main.get_children().filter(func(c): return c is MuistokylttiGame).front()
			print("LE minipeli auki: %s" % [mg != null])
			for ch in "PÖRRÖ":
				var before: int = mg._typed
				mg._press(ch)
				var waited := 0.0
				while mg._typed == before and waited < 6.0:
					await main.get_tree().create_timer(0.1).timeout
					waited += 0.1
				print("LE kirjain %s: maalattu %d, vaihe %s" % [ch, mg._typed, mg._stage])
				if not headless and ch == "R":
					await snap_l.call("_d_maalaus.png")
			print("LE kirjaimet maalattu: %d, vaihe %s" % [mg._typed, mg._stage])
			var waited2 := 0.0
			while mg._stage != "nail" and waited2 < 8.0:
				await main.get_tree().create_timer(0.1).timeout
				waited2 += 0.1
			print("LE sydän ja käpälä valmis, vaihe %s" % mg._stage)
			await snap_l.call("_e_naulaus.png")
			for i in 4:
				mg._hammer()
			await main.get_tree().process_frame
			await snap_l.call("_f_valmis.png")
			print("LE vaihe %s" % mg._stage)
			var m0 := main.maine
			mg._end(true)
			await main.get_tree().create_timer(0.5).timeout
			print("LE valmis: stage %s, maine %.0f -> %.0f, loppu %s, Pörrön kyltti näkyy %s, pojat rauhallisia %s, viesti '%s'" % [main.lemmikki.stage, m0, main.maine,
				main.endings.counts.has("porron_kyltti"), main.world.lehto_plate.visible, main.boys.calm, main._msg.text.replace("\n", " ")])
			main.boys.mode = "idle"
			main.boys.stone()
			print("LE kivenheitto estetty: tila %s" % main.boys.mode)
			main.get_tree().quit()
		"koulu_disko":
			# Koulun disko (koulu_disko_game.gd): ovi perjantaina ja muina päivinä, pelin vaiheet (alku, soi toiveineen,
			# miksauspalkki, hidas pareittain, opettajan polkkatoive ja polkka, kesken katkaisu, hiljaisuus, loppu),
			# pisteytys ja tulos, vaikutus peliin (maine, kerran illassa) ja tallennus. Rivit DI OK / TESTI VIKA.
			var saved_di := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			var snap_di := func(name: String) -> void:
				for i in 4:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var crop_di := func(name: String, r: Rect2, zoom: int) -> void:
				await Kuva.piirto()
				var img := Kuva.ruutu(main.get_viewport())
				var k := Vector2(img.get_size())
				var rr := Rect2i(Vector2i(r.position * k), Vector2i(r.size * k))  # r suhteellisena (0..1)
				var part := img.get_region(rr)
				part.resize(rr.size.x * zoom, rr.size.y * zoom, Image.INTERPOLATE_LANCZOS)
				part.save_png(path.replace(".png", name))
			var wait := func(sec: float) -> void:
				await main.get_tree().create_timer(sec).timeout
			var check := func(ok: bool, what: String) -> void:
				print(("DI OK %s" if ok else "TESTI VIKA koulun disko: %s") % what)
			var door: Vector3 = main.world.koulu_ovi_pos
			check.call(door != Vector3.ZERO, "koulun ovi löytyi %s" % door)
			# 1. Ovi: torstaina lappu, perjantaina 18–21 E.
			main.day = 4  # torstai
			main.clock_min = 18 * 60 + 30
			main._disko_day = -1
			main.walker_out.global_position = door + Vector3(0, 0.3, 0)
			await wait.call(0.4)
			check.call(String(main._hint.text).contains("perjantaisin"), "torstaina lappu '%s'" % main._hint.text)
			main.day = 5  # perjantai
			await wait.call(0.3)
			check.call(String(main._hint.text).contains("[E] Koulun disko"), "perjantaina E '%s'" % main._hint.text)
			# Kuva ovelta: pelaaja ja kamera koulun julkisivuun päin (kyltit näkyvissä).
			var school: Vector3 = M.w(M.KOULUKESKUS)
			main.walker_out.global_position = door + (door - school).normalized() * 5.0 + Vector3(0, 0.3, 0)
			main.walker_out.rotation.y = B.yaw_to(school - door)
			await wait.call(1.2)
			await snap_di.call("_ovi.png")
			main.walker_out.global_position = door + Vector3(0, 0.3, 0)
			await wait.call(0.3)
			var m0: float = main.maine
			main._start_koulu_disko()
			await wait.call(1.5)
			var gs: Array = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == Main.KouluDisko)
			check.call(gs.size() == 1, "peli auki")
			var g: Node = gs[0]
			await snap_di.call("_alku.png")
			await crop_di.call("_kasetit_lahi.png", Rect2(0.5, 0.62, 0.5, 0.3), 2)
			# 2. Pisteytys ilman ruutua.
			var idx := func(genre: String) -> int:
				for i in g.KASETIT.size():
					if g.KASETIT[i][1] == genre:
						return i
				return -1
			g._wants = {"tekno": 2, "dance": 1}
			g._history = []
			check.call(g.score_change("tekno", "sujuva") == 4, "toive täyttyi sujuvasti +4 (%d)" % g.score_change("tekno", "sujuva"))
			check.call(g.score_change("dance", "kesken") == 0, "pienempi toive kesken 0 (%d)" % g.score_change("dance", "kesken"))
			check.call(g.score_change("polkka", "sujuva") == -2, "polkka -2 (%d)" % g.score_change("polkka", "sujuva"))
			check.call(g.score_change("hidas", "hiljaisuus") == -3, "ei toivottu hiljaisuuden jälkeen -3 (%d)" % g.score_change("hidas", "hiljaisuus"))
			g._wants = {"dance": 1}
			g._history = ["dance", "dance"]
			check.call(g.score_change("dance", "sujuva") == 3, "kolmas samaa peräkkäin -1 (%d)" % g.score_change("dance", "sujuva"))
			check.call(g.rating(8.5, false, false) == ["Diskon kuningas", 4] and g.rating(5.5, true, true) == ["Kelpo DJ", 3]
				and g.rating(1.0, true, false) == ["Tyhjä lattia", -2], "arvosanat %s %s %s" % [g.rating(8.5, false, false), g.rating(5.5, true, true), g.rating(1.0, true, false)])
			# 3. Ensimmäinen biisi: toivottu tekno.
			g._history = []
			g._wants = {"tekno": 2}
			g._offer = [idx.call("tekno"), idx.call("dance"), idx.call("hidas")]
			g._sel = 0
			var f0: int = g._floor
			g._mix()
			check.call(g._phase == "soi" and g._round == 1 and g._floor == mini(f0 + 3, 12), "ensimmäinen biisi toiveesta: lattia %d -> %d" % [f0, g._floor])
			await wait.call(2.2)
			g._ask_random("hidas")
			await wait.call(0.3)
			await snap_di.call("_soi.png")
			await crop_di.call("_lattia_lahi.png", Rect2(0.22, 0.22, 0.56, 0.5), 2)
			await crop_di.call("_deki_lahi.png", Rect2(0.0, 0.55, 0.36, 0.45), 2)
			# 4. Miksauspalkki: neula ennen ikkunaa ja ikkunassa; sujuva miksaus toivottuun hitaaseen.
			g._t = g.SEG - 2.6
			await wait.call(0.1)
			await snap_di.call("_miksaus.png")
			g._t = g.SEG - 0.5
			g._wants = {"hidas": 2}
			g._offer = [idx.call("hidas"), idx.call("tekno"), idx.call("polkka")]
			g._sel = 0
			var f1: int = g._floor
			var d1: int = g.score_change("hidas", "sujuva")
			g._mix()
			check.call(g._last_mix == "sujuva" and g._floor == clampi(f1 + d1, 0, 12), "sujuva miksaus hitaaseen: lattia %d -> %d (%+d)" % [f1, g._floor, d1])
			await wait.call(2.2)
			await snap_di.call("_hidas.png")
			# 5. Kesken biisin katkaisu.
			g._t = 5.0
			g._offer = [idx.call("dance"), idx.call("tekno"), idx.call("polkka")]
			g._sel = 0
			g._mix()
			check.call(g._last_mix == "kesken", "kesken katkaisu (%s)" % g._last_mix)
			# 6. Opettajan polkkatoive kolmannen biisin aikana ja polkka.
			g._asks_done = 0
			g._t = 3.2
			await wait.call(0.4)
			check.call(g._teacher_asked and int(g._wants.get("polkka", 0)) >= 1, "opettaja toivoi polkkaa")
			await snap_di.call("_opettaja.png")
			g._t = g.SEG - 0.4
			g._offer = [idx.call("polkka"), idx.call("tekno"), idx.call("dance")]
			g._sel = 0
			var f2: int = g._floor
			g._mix()
			check.call(g._teacher_happy and g._floor < f2, "polkka: opettaja tyytyväinen, lattia %d -> %d" % [f2, g._floor])
			await wait.call(1.6)
			await snap_di.call("_polkka.png")
			# 7. Hiljaisuus: kukaan ei miksaa.
			g._t = g.SEG - 0.05
			await wait.call(0.3)
			check.call(g._phase == "tauko", "biisi loppui, hiljaista (%s)" % g._phase)
			await wait.call(g.GAP + 0.4)
			check.call(g._last_mix == "hiljaisuus" and g._phase == "soi", "hiljaisuuden jälkeen uusi biisi (%s)" % g._last_mix)
			# 8. Viimeinen biisi ja tulos.
			g._t = g.SEG - 0.5
			g._mix()  # kuudes biisi alkaa
			g._t = g.SEG - 0.5
			g._mix()  # kuudes loppuu: loppu
			check.call(g._phase == "loppu" and not g._result.is_empty(), "disko loppui (%s)" % g._phase)
			var exp: Array = g.rating(g._result.lattia, true, true)
			check.call(g._result.title == exp[0] and int(g._result.rep) == int(exp[1]), "tulos %s %+d, lattia %.1f" % [g._result.title, g._result.rep, g._result.lattia])
			await wait.call(0.8)
			await snap_di.call("_loppu.png")
			var rep: int = g._result.rep
			g._quit()
			await wait.call(0.6)
			check.call(main.state == "ulkona" and main._disko_day == main.day and is_equal_approx(main.maine, clampf(m0 + rep, 0.0, 100.0)),
				"pelin jälkeen: tila %s, disko tänään %s, maine %.0f -> %.0f" % [main.state, main._disko_day == main.day, m0, main.maine])
			check.call(String(main._msg.text).contains("Koulun disko"), "viesti '%s'" % main._msg.text)
			main.walker_out.global_position = door + Vector3(0, 0.3, 0)
			await wait.call(0.4)
			check.call(String(main._hint.text).contains("soitettu"), "kerran illassa '%s'" % main._hint.text)
			check.call("koulun_disko" in main.tilat.firsts and "koulu_disko_kuultu" in main.tilat.firsts, "sivutehtävä tehty")
			var cfg := ConfigFile.new()
			main._disko_day = 5
			main._save_game()
			cfg.load(Main.SAVE_PATH)
			check.call(int(cfg.get_value("paivarajat", "koulun_disko", -1)) == 5, "tallennus")
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_di)
		"koulukeskus":
			# Koulukeskus, päiväkoti, kentät ja ulkopingis (#143): paikat, vihjeet kellonajan mukaan ja pingis nuoria vastaan
			# (voitto ja tappio). Aja eristetyllä HOME:lla (tallennus). Kuvat vain ikkunallisena.
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			var headless := DisplayServer.get_name() == "headless"
			var snap_k := func(name: String) -> void:
				if headless:
					return
				for i in 8:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var goto_k := func(at: Vector3) -> void:
				main.walker_out.global_position = at + Vector3(0, 0.3, 0)
				for i in 4:
					await main.get_tree().physics_frame
			var pt: Vector3 = main.world.pingis_ulko_pos
			print("KO pöytä %s (px %s), koulu %s, päiväkoti %s" % [pt, M.to_px(pt), M.w(M.KOULUKESKUS), M.w(M.PAIVAKOTI)])
			var cam_k := Camera3D.new()
			cam_k.far = 1500.0
			main.add_child(cam_k)
			cam_k.current = true
			var views := []
			for spec in [["a_koulu", M.KOULUKESKUS, 3.4, 30.0], ["b_paivakoti", M.PAIVAKOTI, 2.7, 16.0]]:
				var f: Dictionary = main.world._osm_fit_at(spec[1])
				if f.is_empty():
					continue
				var nrm: Vector2 = f.nrm
				var base: Vector2 = f.c + nrm * (f.d / 2.0 + spec[3])
				var tgt: Vector2 = f.c + nrm * (f.d / 2.0)
				views.append([spec[0], Vector3(base.x, Terrain.h(base.x, base.y) + 5.0, base.y), Vector3(tgt.x, Terrain.h(tgt.x, tgt.y) + spec[2], tgt.y), 55.0])
			views.append(["c_kentta", M.w(M.KENTAT[0]) + Vector3(-5, 18, 28), M.w(M.KENTAT[0]), 55.0])
			views.append(["d_pingis", pt + Vector3(0.0, 2.0, 5.5), pt + Vector3(0, 1.0, 0), 55.0])
			for v in views:
				cam_k.fov = v[3]
				cam_k.look_at_from_position(v[1], v[2])
				await snap_k.call("_%s.png" % v[0])
			cam_k.current = false
			main.player.activate_camera()
			main.day = 3
			main.clock_min = 10 * 60
			await goto_k.call(pt + Vector3(0, 0, 1.2))
			print("KO aamulla: '%s'" % main._hint.text)
			main.clock_min = 16 * 60
			await goto_k.call(pt + Vector3(0, 0, 1.3))
			print("KO iltapäivällä: '%s'" % main._hint.text)
			# Pingis: voitto (heti kokonaan) ja tappio
			main.money = 10.0
			main.maine = 20.0
			main._start_pingis_nuoret()
			var g: Node3D = main.get_children().filter(func(c): return c is PingisGame)[0]
			print("KO peli: paikka %s, vastustaja %s, taito %.2f" % [g.venue, g.opp_name, g.opp_skill])
			await main.get_tree().create_timer(1.0).timeout
			await snap_k.call("_e_peli.png")
			g._rounds = [2, 0]
			g._end_game()
			await main.get_tree().create_timer(5.0).timeout
			print("KO voitto: maine 20 -> %.0f, rahaa %s, voittoja %d, tila %s, viesti '%s'" % [main.maine, main._eur(main.money), main._pingis_nuoret_voitot, main.state, main._msg.text.replace("\n", " ")])
			main.day = 4
			main.clock_min = 17 * 60
			main._start_pingis_nuoret()
			g = main.get_children().filter(func(c): return c is PingisGame)[0]
			print("KO toinen peli: taito %.2f" % g.opp_skill)
			g._rounds = [0, 2]
			g._end_game()
			await main.get_tree().create_timer(5.0).timeout
			print("KO tappio: rahaa 10 -> %s, tila %s, viesti '%s'" % [main._eur(main.money), main.state, main._msg.text.replace("\n", " ")])
			main.get_tree().quit()
		"kuvakirkko":
			# Paltaniemen kuvakirkko (#250 P9): suntio, maalaukset, piilokuvaetsintä (6 kohdetta, osittainen löytö säilyy, palkinto kerran); tallennus; kuvat.
			main._note.visible = false
			var kk_shot := func(name: String) -> void:
				for i in 4:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.kuvakirkko = KuvakirkkoLegenda.new()
			print("KK taksivalinta: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "retki_paltaniemi").map(func(o): return [o.id, o.enabled, o.text])])
			var kk_t0 := main.clock_min
			main._retki_from = main.player.global_position
			main._enter_retki("paltaniemi")
			print("KK perillä: state %s, kello +%.0f min, tehtävät %s" % [main.state, main.clock_min - kk_t0, main._kuvakirkko_tasks()])
			await kk_shot.call("alue")
			var kk_cam := main.get_viewport().get_camera_3d()
			var kk_close := func(name: String, from: Vector3, to: Vector3, fov := 45.0) -> void:
				var c := Camera3D.new()
				c.fov = fov
				main.retki_int.add_child(c)
				c.look_at_from_position(main.retki_int.global_position + from, main.retki_int.global_position + to)
				c.current = true
				main._hud.visible = false
				await kk_shot.call(name)
				main._hud.visible = true
				kk_cam.make_current()
				c.queue_free()
			# Suntio: ensimmäinen puhe kirjaa tehtävän, repliikit kiertävät.
			main.retki_int.walker.position = main.retki_int.spots.suntio[0]
			for i in 3:
				await main.get_tree().process_frame
			print("KK suntion luona: spot '%s', vihje '%s'" % [main.retki_int.spot, main._hint.text])
			main._kuvakirkko_acted("suntio")
			print("KK suntio: puhuttu %s, kupla '%s', tehtävät %s" % [main.kuvakirkko.suntio, main.retki_int._bubble.text, main._kuvakirkko_tasks()])
			await kk_shot.call("peli_suntio")
			main.retki_int.walker.position = Vector3(3.0, 0, 4.0)  # pois kuvakulmista
			await main.get_tree().create_timer(4.0).timeout  # viesti ja kupla pois
			await kk_shot.call("alue_tyhja")
			main.retki_int.walker.position = Vector3(4.6, 0, 2.6)
			await kk_shot.call("peli_kyltti")
			main.retki_int.walker.position = main.retki_int.spots.maalaukset[0]
			await kk_shot.call("peli_maalaukset")
			await kk_close.call("suntio_edesta", Vector3(-3.6, 1.6, -1.2), Vector3(-3.6, 1.1, -4.4))
			await kk_close.call("suntio_paadysta", Vector3(-1.2, 1.4, -4.4), Vector3(-3.6, 1.1, -4.4))
			await kk_close.call("suntio_ylhaalta", Vector3(-3.6, 5.0, -4.0), Vector3(-3.6, 0.5, -4.4))
			await kk_close.call("penkki_paadysta", Vector3(-8.0, 1.2, 0.2), Vector3(-3.9, 0.6, 0.2), 50.0)
			await kk_close.call("penkki_ylhaalta", Vector3(-3.9, 6.0, 1.2), Vector3(-3.9, 0.3, 0.2), 50.0)
			await kk_close.call("penkki_vino", Vector3(-1.0, 1.6, 4.0), Vector3(-3.9, 0.6, 0.2), 50.0)
			await kk_close.call("maalaukset", Vector3(0.0, 3.0, 2.0), Vector3(0.0, 2.4, -6.0), 60.0)
			await kk_close.call("ylhaalta", Vector3(0.0, 40.0, 1.0), Vector3(0.0, 0.0, 0.0), 40.0)
			# Maalaukset: peli auki, tyhjä tila, huti, löydöt.
			main.retki_int.walker.position = main.retki_int.spots.maalaukset[0]
			for i in 3:
				await main.get_tree().process_frame
			print("KK maalausten luona: spot '%s', vihje '%s'" % [main.retki_int.spot, main._hint.text])
			main._kuvakirkko_acted("maalaukset")
			var kk_g: Node = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == KuvakirkkoGame)[0]
			print("KK peli auki: state %s, minipeli auki %s, löydetty %d" % [main.state, main._minigame_open(), main.kuvakirkko.found.size()])
			await kk_shot.call("peli_tyhja")
			kk_g.click(Vector2(5, 5))
			await kk_shot.call("peli_huti")
			for id in ["tahti", "kala", "kissa"]:
				kk_g.click(kk_g._item_pos(id) + Vector2(4, -3))
			kk_g.click(kk_g._item_pos("tahti"))
			print("KK kolme löytynyt: peli %d, legenda %s, tehtävä %s" % [kk_g.found.size(), main.kuvakirkko.found, main._kuvakirkko_tasks()])
			await kk_shot.call("peli_kolme")
			# Esc kesken: löydöt jäävät.
			kk_g._end(false)
			await main.get_tree().process_frame
			print("KK Esc: state %s, löydetty %d, valmis %s, minipeli auki %s" % [main.state, main.kuvakirkko.found.size(), main.kuvakirkko.valmis, main._minigame_open()])
			# Jatko: aiemmat säilyvät, loput löytyvät, palkinto kerran.
			main.retki_int.block_interact()
			main._kuvakirkko_acted("maalaukset")
			kk_g = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == KuvakirkkoGame)[0]
			print("KK jatko: pelissä %d löydettynä" % kk_g.found.size())
			var kk_m0 := main.maine
			for id in ["lintu", "avain", "etana"]:
				kk_g.click(kk_g._item_pos(id))
			kk_g._glint_id = "kala"
			await kk_shot.call("peli_valmis")
			await main.get_tree().create_timer(1.0).timeout
			await kk_shot.call("peli_valmis_ruutu")
			kk_g._end(true)
			await main.get_tree().process_frame
			print("KK valmis: found %s, valmis %s, maine %.0f -> %.0f, state %s, tehtävät %s" % [main.kuvakirkko.found.size(), main.kuvakirkko.valmis, kk_m0, main.maine, main.state, main._kuvakirkko_tasks()])
			# Toistokäynti ei anna palkintoa uudelleen.
			main.retki_int.block_interact()
			main._kuvakirkko_acted("maalaukset")
			kk_g = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == KuvakirkkoGame)[0]
			var kk_m1 := main.maine
			kk_g._end(true)
			await main.get_tree().process_frame
			print("KK toisto: maine %.0f -> %.0f (ei muutosta)" % [kk_m1, main.maine])
			var kk_cfg := ConfigFile.new()
			main.kuvakirkko.save_to(kk_cfg)
			var kk_l: RefCounted = KuvakirkkoLegenda.new()
			kk_l.load_from(kk_cfg)
			print("KK tallennus: found %d suntio %s valmis %s" % [kk_l.found.size(), kk_l.suntio, kk_l.valmis])
			main._on_retki_exited()
			await main.get_tree().create_timer(14.0).timeout
			print("KK takaisin: state %s, etäisyys lähtöpaikasta %.2f m, kello +%.0f min" % [main.state, main.player.global_position.distance_to(main._retki_from), fposmod(main.clock_min - kk_t0, 1440.0)])
			main.get_tree().quit()
		"manamansalo":
			# Manamansalon muistokirkko (#250 P7): taksikuski kertoo, opas ja infotaulu vihjeinä, kivijalka avaa legendan lopun (kerran); tallennus; kuvat.
			main._note.visible = false
			var mm_shot := func(name: String) -> void:
				for i in 3:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.manamansalo = ManamansaloLegenda.new()
			print("MM taksivalinnat: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "manamansalo_kerro" or o.id == "retki_manamansalo").map(func(o): return [o.id, o.enabled, o.text])])
			print("MM tehtävät ennen: %s" % [main._manamansalo_tasks()])
			main._talk_open("taksi", null, "Kyytiä?")
			main._talk_manamansalo("manamansalo_kerro")
			main._talk_box.close()
			print("MM kuultu %s, tehtävät %s, valinta pois %s" % [main.manamansalo.heard, main._manamansalo_tasks(), main._talk_options("taksi").filter(func(o): return o.id == "manamansalo_kerro").is_empty()])
			print("MM päiväkirja: %s" % [main.quests.hint_for("taksi", main.tilat.firsts, main.quest_flag)])
			var mm_t0 := main.clock_min
			var mm_m0 := main.money
			main._retki_from = main.player.global_position
			main._enter_retki("manamansalo")
			print("MM perillä: state %s, kello +%.0f min" % [main.state, main.clock_min - mm_t0])
			await mm_shot.call("alue")
			main.retki_int.walker.position = main.retki_int.spots.jaanteet[0]
			for i in 3:
				await main.get_tree().process_frame
			print("MM kivijalalla: spot '%s'" % main.retki_int.spot)
			main._on_retki_acted("jaanteet")
			print("MM kivijalka ilman vihjeitä: found %s (false)" % main.manamansalo.found)
			main.retki_int.walker.position = main.retki_int.spots.opas[0]
			for i in 3:
				await main.get_tree().process_frame
			print("MM oppaalla: spot '%s'" % main.retki_int.spot)
			main._on_retki_acted("opas")
			await mm_shot.call("opas")
			print("MM opas %s, tehtävät %s" % [main.manamansalo.opas, main._manamansalo_tasks()])
			main.retki_int.walker.position = main.retki_int.spots.infotaulu[0]
			for i in 3:
				await main.get_tree().process_frame
			print("MM taululla: spot '%s'" % main.retki_int.spot)
			main._on_retki_acted("infotaulu")
			await mm_shot.call("infotaulu")
			print("MM kyltti %s, tehtävät %s" % [main.manamansalo.kyltti, main._manamansalo_tasks()])
			main.retki_int.walker.position = main.retki_int.spots.jaanteet[0]
			for i in 3:
				await main.get_tree().process_frame
			var mm_maine0 := main.maine
			var mm_cam := main.get_viewport().get_camera_3d()
			var mm_close := func(name: String, from: Vector3, to: Vector3) -> void:
				var c := Camera3D.new()
				c.fov = 45.0
				main.retki_int.add_child(c)
				c.look_at_from_position(main.retki_int.global_position + from, main.retki_int.global_position + to)
				c.current = true
				main._hud.visible = false
				await mm_shot.call(name)
				main._hud.visible = true
				mm_cam.make_current()
				c.queue_free()
			await mm_close.call("kirkko_edesta", Vector3(-3.0, 2.2, 7.5), Vector3(-3.0, 2.0, -2.5))
			await mm_close.call("kirkko_sivusta", Vector3(6.0, 3.0, 1.0), Vector3(-3.0, 2.0, -2.5))
			await mm_close.call("kivijalka_ennen", Vector3(9.0, 3.2, 4.2), Vector3(9.0, 0.0, -2.2))
			main._on_retki_acted("jaanteet")
			for i in 3:
				await main.get_tree().process_frame
			await mm_close.call("kivijalka_jalkeen", Vector3(9.0, 3.2, 4.2), Vector3(9.0, 0.0, -2.2))
			await mm_close.call("ylhaalta", Vector3(0.0, 22.0, 3.0), Vector3(0.0, 0.0, 0.0))
			print("MM loppu: found %s, maine %.0f -> %.0f, raha %s -> %s (ei muutu), loppu kirjattu %s, tehtävät %s" % [main.manamansalo.found, mm_maine0, main.maine, main._eur(mm_m0), main._eur(main.money), main.endings.counts.has("manamansalon_kirkko"), main._manamansalo_tasks()])
			var mm_maine1 := main.maine
			main._on_retki_acted("jaanteet")
			print("MM toistokerta: maine %.0f -> %.0f (ei kasva)" % [mm_maine1, main.maine])
			var mm_cfg := ConfigFile.new()
			main.manamansalo.save_to(mm_cfg)
			var mm_l: RefCounted = ManamansaloLegenda.new()
			mm_l.load_from(mm_cfg)
			print("MM tallennus: heard %s opas %s kyltti %s found %s" % [mm_l.heard, mm_l.opas, mm_l.kyltti, mm_l.found])
			main._on_retki_exited()
			await main.get_tree().create_timer(14.0).timeout
			print("MM takaisin: state %s, etäisyys lähtöpaikasta %.2f m, kello +%.0f min" % [main.state, main.player.global_position.distance_to(main._retki_from), fposmod(main.clock_min - mm_t0, 1440.0)])
			main.get_tree().quit()
		"kuninkaantapuli":
			# Kuninkaan tapuli (#126): suntio kertoo, yökello, teinit ja avain, Pirtin G. R., droonikohde, lyijykotelo, museo ja
			# kolo (jemma, poliisin kellovaroitus) sekä epäilijät. Aja eristetyllä HOME:lla (tallennus).
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			var press_k := func() -> void:
				await main.get_tree().process_frame
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
			var goto_k := func(at: Vector3) -> void:
				main.walker_out.global_position = at + Vector3(0, 0.3, 0)
				for i in 4:
					await main.get_tree().physics_frame
			main._pyhimys_nodes()
			var tp: Vector3 = main.world.tapuli_pos
			print("KU tapuli %s, jemman paikka %s" % [tp, main._stash_pos("tapuli")])
			print("KU suntio: %s" % [main._talk_options("suntio").map(func(o): return o.id)])
			main._talk_who = "suntio"
			main._talk_kuningas("kuningas_kerro")
			print("KU kuultu %s, tehtävät %s" % [main.kuningas.heard, main._kuningas_tasks()])
			print("KU avain-valinta ilman pyhimystä: %s" % [main._talk_options("suntio").filter(func(o): return o.id == "kuningas_avain").map(func(o): return o.enabled)])
			main.day = 2
			main.clock_min = 23 * 60
			await goto_k.call(tp + Vector3(0, 0, 60.0))
			main._bell_t = 0.01
			for i in 3:
				await main.get_tree().physics_frame
			print("KU yökello kuultu %s" % main.kuningas.yokello)
			await goto_k.call(tp + Vector3(0, 0, 6.0))
			print("KU teinit pakenivat %s" % main.kuningas.teinit)
			await goto_k.call(tp + Vector3(0, 0, 1.0))
			print("KU avain-vihje '%s'" % main._hint.text)
			await press_k.call()
			print("KU avain %s, tehtävät %s" % [main.kuningas.avain, main._kuningas_tasks()])
			print("KU ennen vihjettä: '%s'" % main._hint.text)
			await goto_k.call(main.world.museum_door)
			main.clock_min = 12 * 60
			await press_k.call()
			print("KU Pirtti: asiakirja %s" % main.kuningas.asiakirja)
			print("KU droonikohde: %s" % [main._drone_pois().any(func(d): return d.id == "kuninkaan_katto")])
			main._on_drone_photo("kuninkaan_katto")
			print("KU drooni %s, tehtävät %s" % [main.kuningas.drooni, main._kuningas_tasks()])
			await goto_k.call(tp + Vector3(0, 0, 1.0))
			print("KU tapulin vihje: '%s'" % main._hint.text)
			await press_k.call()
			print("KU kotelo %s, tehtävät %s" % [main.kuningas.found, main._kuningas_tasks()])
			# Museohaara
			var m0 := main.maine
			var money0 := main.money
			await goto_k.call(main.world.museum_door)
			print("KU museo-vihje: '%s'" % main._hint.text)
			await press_k.call()
			print("KU museo: valinta '%s', maine %.0f -> %.0f, rahaa %s -> %s, loppu %s" % [main.kuningas.choice, m0, main.maine, main._eur(money0), main._eur(main.money), main.endings.counts.has("kuninkaan_tapuli")])
			main._talk_who = "arto"
			var seen := false
			for i in 60:
				if (Main.KUNINGAS_PROVEN.arto as Array).has(main._talk_chat_line()):
					seen = true
					break
			print("KU Arton todistettu repliikki: %s" % seen)
			# Kolohaara (uusi tila): suntion avain pyhimyksen jälkeen, koloon, jemma ja poliisin kellovaroitus
			main.kuningas.choice = ""
			main.kuningas.found = true
			main.kuningas.avain = false
			main.pyhimys.returned = true
			print("KU suntio (pyhimys palautettu): %s" % [main._talk_options("suntio").map(func(o): return "%s:%s" % [o.id, o.enabled])])
			main._talk_kuningas("kuningas_avain")
			print("KU suntion avain %s" % main.kuningas.avain)
			print("KU suntio nyt: %s" % [main._talk_options("suntio").map(func(o): return o.id)])
			main._talk_kuningas("kuningas_kolo")
			print("KU kolo: valinta '%s', maine %.0f" % [main.kuningas.choice, main.maine])
			await goto_k.call(tp + Vector3(0, 0, 1.0))
			print("KU jemma: vihje '%s'" % main._hint.text)
			main._call_police("siili")
			for i in 3:
				await main.get_tree().physics_frame
			print("KU poliisin kellovaroitus: '%s'" % main._msg.text)
			main.get_tree().quit()
		"olavinmarkkinat":
			# Olavinmarkkinoiden hopea (#124): koko ketju (Hilkka, Pirtin kirje, kivi, Olavi-pappa, kalja, lapio, kaivu), lyhdyt
			# yöllä, museo- ja keräilijähaara sekä markkinapäivä. Tallennus palautetaan.
			var saved_ol := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			var press_ol := func() -> void:
				await main.get_tree().process_frame
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
			var goto_ol := func(at: Vector3) -> void:
				main.walker_out.global_position = at + Vector3(0, 0.3, 0)
				for i in 4:
					await main.get_tree().physics_frame
			main._olavi_nodes()
			print("OL paikat: hauta %s, kätkö %s (vedessä %s, px %s), Sulon lyhty %s (vedessä %s)" % [main.world.kauppias_pos, main.world.olavi_katko_pos,
				main.world._in_any(Vector2(main.world.olavi_katko_pos.x, main.world.olavi_katko_pos.z), main.world._water), M.to_px(main.world.olavi_katko_pos),
				main.world.olavi_sulo_pos, main.world._in_any(Vector2(main.world.olavi_sulo_pos.x, main.world.olavi_sulo_pos.z), main.world._water)])
			print("OL Hilkka: %s" % [main._talk_options("hilkka").map(func(o): return o.id).has("olavi_legenda")])
			main.kirppis_int.mode = "kirppis"
			main._talk_who = "hilkka"
			main._talk_kirppis("olavi_legenda")
			print("OL kuultu %s, tehtävät %s" % [main.olavi.heard, main._olavi_tasks()])
			main.day = 3
			main.clock_min = 12 * 60
			await goto_ol.call(main.world.museum_door)
			print("OL Pirtti: vihje '%s'" % main._hint.text)
			await press_ol.call()
			print("OL kirje %s, tehtävät %s" % [main.olavi.kirje, main._olavi_tasks()])
			await goto_ol.call(main.world.kauppias_pos + Vector3(0, 0, 1.0))
			print("OL kiven vihje: '%s'" % main._hint.text)
			await press_ol.call()
			print("OL kivi %s, Olavi-pappa näkyy %s, tehtävät %s" % [main.olavi.kivi, main.olavi_pappa.visible, main._olavi_tasks()])
			print("OL pappa: %s" % [main._talk_options("olavi_pappa").map(func(o): return o.id)])
			main._talk_olavi("olavi_kukat")
			main.beers = 2
			main._talk_olavi("olavi_kalja")
			print("OL lupa %s, kaljoja %d, tehtävät %s" % [main.olavi.lupa, main.beers, main._olavi_tasks()])
			main._on_garage_acted("lapio")
			print("OL lapio %s, tehtävät %s" % [main.olavi.lapio, main._olavi_tasks()])
			main.day = 5
			main.clock_min = 23 * 60
			await goto_ol.call(main.world.olavi_katko_pos + Vector3(0, 0, 30.0))
			print("OL päivä 5 yöllä (Sulon reitti): Sulon lyhty %s, Olavin lyhty %s" % [main._sulo_flame.visible, main._olavi_flame.visible])
			var p0 := main.pontikka
			await goto_ol.call(main.world.olavi_sulo_pos)
			print("OL Sulon vaitiolo: pontikka %d -> %d, sulo %s" % [p0, main.pontikka, main.olavi.sulo])
			main.day = 7
			main.clock_min = 23 * 60
			await goto_ol.call(main.world.olavi_katko_pos + Vector3(4.0, 0, 0))
			print("OL Olavinpäivän yö: Olavin lyhty %s, pappa %s kätkön luona %s, lyhty nähty %s" % [main._olavi_flame.visible, main.olavi_pappa.visible,
				main.olavi_pappa.global_position.distance_to(main.world.olavi_katko_pos) < 4.0, main.olavi.lyhty])
			await goto_ol.call(main.world.olavi_katko_pos + Vector3(0, 0, 1.2))
			print("OL kaivu: vihje '%s'" % main._hint.text)
			await press_ol.call()
			print("OL lipas %s, veksi auki %s, tehtävät %s" % [main.olavi.found, main._talk_options("veksi").map(func(o): return o.id).has("olavi_myy"), main._olavi_tasks()])
			# Museohaara
			main.day = 8
			main.clock_min = 12 * 60
			var m0 := main.maine
			var money0 := main.money
			await goto_ol.call(main.world.museum_door)
			print("OL museo-vihje: '%s'" % main._hint.text)
			await press_ol.call()
			print("OL museo: valinta '%s', maine %.0f -> %.0f, rahaa %s -> %s, loppu %s" % [main.olavi.choice, m0, main.maine, main._eur(money0), main._eur(main.money), main.endings.counts.has("olavinmarkkinat")])
			main.day = 14
			main.clock_min = 12 * 60
			await main.get_tree().physics_frame
			await main.get_tree().physics_frame
			print("OL päivä 14 (Olavinpäivä): markkinat %s, banderolli %s, terva piilossa %s, voi %s, makkara %s" % [main._markkinat_paiva(), main.world.markkina_banner.visible,
				main._kirppis_hidden("terva"), main._kirppis_hidden("voi"), main._kirppis_hidden("makkara")])
			main.day = 13
			await main.get_tree().physics_frame
			await main.get_tree().physics_frame
			print("OL päivä 13: markkinat %s, banderolli %s, terva piilossa %s" % [main._markkinat_paiva(), main.world.markkina_banner.visible, main._kirppis_hidden("terva")])
			main._talk_who = "pekka"
			var seen := false
			for i in 60:
				if (Main.OLAVI_PROVEN.pekka as Array).has(main._talk_chat_line()):
					seen = true
					break
			print("OL Pekan todistettu repliikki: %s" % seen)
			# Keräilijähaara (uusi tila)
			main.olavi.choice = ""
			main.olavi.found = true
			money0 = main.money
			main._talk_who = "veksi"
			main._olavi_sell()
			print("OL keräilijä: valinta '%s', rahaa %s -> %s, maine %.0f" % [main.olavi.choice, main._eur(money0), main._eur(main.money), main.maine])
			await main.get_tree().physics_frame
			await main.get_tree().physics_frame
			print("OL poliisi-lippu: %s" % main.olavi.poliisi)
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_ol)
			main.get_tree().quit()
		"leikki":
			# Leikkipuistot (#146): kuusi puistoa, keinuhyppy (vauhti, hyppy, uusi ennätys), hiekkalaatikko, kalja penkillä
			# äitien edessä ja illalla. Kuvat puistosta ja minipelistä.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.quests = Quests.new()
			main._keinu_record = 3.4
			main._keinu_holder = "Honganpalon Jere"
			main._keinu_best = 0.0
			main._sandbox_day = {}
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
			main.clock_min = 12 * 60
			print("LE puistoja %d: %s" % [main.world.playgrounds.size(), main.world.playgrounds.map(func(p): return p.name)])
			var pg: Dictionary = main.world.playgrounds[0]
			var oc := Camera3D.new()
			main.add_child(oc)
			oc.look_at_from_position(pg.bench + Vector3(-9, 6, -7), pg.bench + Vector3(2, 0, 4))
			oc.current = true
			await frames.call(30)
			await snap.call("_puisto.png")
			var mp: Vector3 = pg.mums.global_position
			var fr: Node3D = pg.frame
			for v in [["_penkki_edesta.png", pg.mums.to_global(Vector3(0.3, 1.4, 3.2)), mp + Vector3(0, 0.7, 0)],
					["_penkki_sivu.png", pg.mums.to_global(Vector3(-3.2, 1.1, 0.4)), mp + Vector3(0, 0.7, 0)],
					["_teline.png", fr.to_global(Vector3(4.5, 1.8, 3.0)), fr.to_global(Vector3(0, 1.2, 0))]]:
				oc.look_at_from_position(v[1], v[2])
				await frames.call(20)
				await snap.call(v[0])
			oc.current = false
			main.player.activate_camera()
			await at.call(pg.swing)
			print("LE keinu: '%s'" % main._hint.text)
			await press.call("interact")
			var g: Node = main._keinu
			print("LE peli keinutelineessä %s, oma keinu piilossa %s, pelaaja piilossa %s" % [g != null and g.get_parent() == pg.frame,
				not pg.frame.get_node("Keinu1").visible, not main.walker_out.visible])
			await main.get_tree().create_timer(1.6).timeout
			g._th = 0.9
			g._w = 0.4
			await main.get_tree().create_timer(0.3).timeout
			await snap.call("_keinu.png")
			g._th = -0.8
			g._w = -0.5
			await main.get_tree().create_timer(0.3).timeout
			await snap.call("_keinu_taakse.png")
			g._th = 0.35
			g._w = 3.4
			await press.call("jump")
			await main.get_tree().create_timer(0.35).timeout
			await snap.call("_lento.png")
			await main.get_tree().create_timer(1.2).timeout
			await snap.call("_alastulo.png")
			var land: Vector3 = g.landing
			await main.get_tree().create_timer(5.5).timeout
			print("LE hyppy: ennätys %s %s, oma %s, '%s'" % [main._keinu_holder, KeinuGame._m(main._keinu_record), KeinuGame._m(main._keinu_best), main._msg.text.left(50)])
			print("LE peli ohi %s, keinu takaisin %s, pelaaja näkyy %s, %.1f m alastulopaikasta" % [main._keinu == null,
				pg.frame.get_node("Keinu1").visible, main.walker_out.visible, Vector2(main.walker_out.global_position.x - land.x, main.walker_out.global_position.z - land.z).length()])
			await at.call(pg.sandbox)
			print("LE hiekkalaatikko: '%s'" % main._hint.text)
			await press.call("interact")
			print("LE kaivettu: '%s'" % main._msg.text.left(70))
			main.beers = 2
			var m0 := main.maine
			await at.call(pg.bench)
			await press.call("interact")
			print("LE kalja äitien edessä: maine %d -> %d, äidit näkyy %s" % [roundi(m0), roundi(main.maine), pg.mums.visible])
			main._today.erase("leikki_kalja")
			main.clock_min = 22 * 60
			await frames.call(5)
			await at.call(pg.bench)
			await press.call("interact")
			print("LE kalja illalla: '%s', äidit näkyy %s" % [main._msg.text.left(40), pg.mums.visible])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"ohjerivi":
			# Näppäinohjerivi seuraa asetuksia: syö T -> R ja takaisin.
			var erow := -1
			for r in Settings.KEY_ROWS.size():
				if "eat" in Settings.KEY_ROWS[r][0]:
					erow = r
			for i in 5:
				await main.get_tree().process_frame
			print("OHJERIVI ennen: '%s'" % main._help_text())
			var old_k: int = Settings.keys_of(erow)[0]
			Settings.bind_key(erow, 0, KEY_R)
			for i in 5:
				await main.get_tree().process_frame
			print("OHJERIVI syö R:ään: '%s'" % main._help_text())
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_r.png"))
			Settings.bind_key(erow, 0, old_k)
		"lappupekka2":
			# Koko ketju pelin funktioilla: kuutonen kotijemmaan -> Pekka kutsuu -> kotiin (uusi päivä) -> aamulappu.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.story = Story.new()
			print("LAPPU2 alku: vaihe %s" % main.story.step)
			for id in Main.STASHES:
				print("LAPPU2 jemma %s: koti %s" % [id, Main.STASHES[id].home])
			main._stash_add("koti", 6)
			print("LAPPU2 jemman jälkeen: vaihe %s" % main.story.step)
			for case in ["kotiin kuutosen kanssa", "nukkumaan", "sammui ulos"]:
				main.state = "ulkona"
				main._kuutonen_day = main.day if case == "kotiin kuutosen kanssa" else -1
				if case == "sammui ulos":
					main._day_end = "ulko"
					main._new_day(main.home_zone + Vector3(0, 0, 4), false)
				else:
					main._win()
				for i in 5:
					await main.get_tree().process_frame
				var txt := " / ".join(main._note.find_children("*", "Label", true, false).map(func(c): return c.text))
				var at := txt.rfind("Pekka")
				print("LAPPU2 %s: vaihe %s, lapussa Pekka: %s" % [case, main.story.step, txt.substr(maxi(0, at - 20), 120) if at >= 0 else "EI"])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"lappupekka":
			# Päivin lappu, kun Pekalla on asiaa (kuutonen piilotettu, Pekan luona ei käyty).
			main.story = Story.new()
			main.story.step = "pekka_kutsuu"
			main._day_note(Main.MORNING_HEAD.koti[0], "")
			for i in 40:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_lappu.png"))
			print("LAPPU Pekka näkyy %s" % main._note.is_showing())
		"lappu":
			# Aamulappu ja samaan aikaan pitkä viesti ja vihje: tekstit lapun oikealla puolella, eivät sen alla.
			main._day_note("Huomenta! Mää lähin jo.", "Se nurmikko ei leikkaa itseään!\nAnna-Liisa sano aidan takaa, että meillä on kohta ihan heinäpelto!")
			for i in 30:
				await main.get_tree().process_frame
			main._show_message("Päivä 5 alkaa kotoa.\nPyörä jäi eilen muualle – katso kartasta (M), minne.\nJossain päin kylää pojat pelaa jalkapalloa.", 6.0)
			for i in 3:
				await main.get_tree().process_frame
			main._hint.text = "Ovi ei aukea kaljat kädessä – Päivi näkee! Piilota kaljat ensin jemmaan (E)."
			print("LAPPU näkyy %s, lapun oikea reuna %.0f, viestin vasen reuna %.0f" % [main._note.is_showing(),
				main._note._paper.get_global_rect().end.x, main._msg.get_global_rect().position.x])
		"mummotesti":
			# Pyörällä lujaa mummojen ohi: suuttuvatko ja heittävätkö kettukarkkeja? Sitten kello.
			var mp0 := main.mummot.global_position
			main.bike.global_position = mp0 + Vector3(-20, 0.4, 3.0)
			main.bike.look_at(main.bike.global_position + Vector3(1, 0, 0), Vector3.UP)
			main.bike.speed = 9.0
			Input.action_press("forward")
			var angry_seen := false
			for i in 180:
				await main.get_tree().physics_frame
				angry_seen = angry_seen or main.mummot.is_angry()
			Input.action_release("forward")
			print("MUMMOT paikka %s, kaupan ovi %s, väli %.1f m, parkkipaikka %.1f m" % [main.mummot.global_position, main.shop_door,
				Vector2(main.mummot.global_position.x - main.shop_door.x, main.mummot.global_position.z - main.shop_door.z).length(),
				Vector2(main.mummot.global_position.x - main.shop_zone.x, main.mummot.global_position.z - main.shop_zone.z).length()])
			var oc := Camera3D.new()
			main.add_child(oc)
			oc.look_at_from_position(main.shop_door + Vector3(-4, 9, 22), (main.shop_door + main.mummot.global_position) / 2.0)
			oc.current = true
			main._msg.text = ""
			main._note.visible = false
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kauppa.png"))
			print("MUMMOT ohi: vaarat %s, in_vaala %s, suuttui %s, lentäviä %d, maassa %d, vauhti %.1f" % [main._hazards.process_mode,
				main._in_vaala, angry_seen, main.mummot._flying.size(), main.mummot._ground.size(), main.bike.speed])
		"marjapaikat":
			# Arton merkinnät karttaan säilyvät tallennuksessa: tallennus ja lataus uudelleen.
			main.world.forage_revealed = true
			main.bucket = {"puolukka": 3, "kantarelli": 1}
			main.kota_polkyt = 2
			main.kota_halot = 5
			main.drone_broken_day = main.day
			main.sinikka_lawn.lengths.fill(0.1)
			main._save_game()
			main.world.forage_revealed = false
			main.bucket = {}
			main.kota_polkyt = 0
			main.kota_halot = 0
			main.drone_broken_day = -1
			main.sinikka_lawn.lengths.fill(0.4)
			main._load_game()
			var f0: Dictionary = main.world.forage[0]
			f0.taken = true
			f0.regrow = main.day + 2
			f0.node.visible = false
			main._save_game()
			f0.taken = false
			main._load_game()
			print("MARJAPAIKAT poimittu tallessa: %s, takaisin päivänä %d (nyt %d)" % [f0.taken, f0.regrow, main.day])
			var d0 := main.day
			main.day = d0 + 1
			main._regrow_forage()
			print("MARJAPAIKAT +1 pv: poimittu %s" % f0.taken)
			main.day = d0 + 2
			main._regrow_forage()
			print("MARJAPAIKAT +2 pv: poimittu %s, näkyy %s" % [f0.taken, f0.node.visible])
			main.day = d0
			print("MARJAPAIKAT latauksen jälkeen: paikat %s, ämpäri %s, pölkyt %d, halot %d, drooni rikki %s, Sinikan nurmi %.2f" % [
				main.world.forage_revealed, main.bucket, main.kota_polkyt, main.kota_halot, main.drone_broken_day == main.day, main.sinikka_lawn.lengths[0]])
		"liikenne":
			# Kylän liikenne: autojen määrä ja liike, K-Marketin automaatti kahdesti ja auton alle jääminen.
			var cars: Array = main._hazards.get_children().filter(func(c): return c is TrafficCar)
			var p0: Array = cars.map(func(c): return c.global_position)
			for i in 180:
				await main.get_tree().physics_frame
			var moved: Array = []
			for i in cars.size():
				moved.append(roundi(cars[i].global_position.distance_to(p0[i])))
			print("LIIKENNE autoja %d, liikkuneet 3 s: %s" % [cars.size(), moved])
			main._toggle_mount()
			main._build_atm()
			main.walker_out.global_position = main._atm_node.global_position + Vector3(0, 0.5, -1.0)
			for i in 10:
				await main.get_tree().physics_frame
			var mm := main.money
			for k in 2:
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
				print("LIIKENNE otto %d: rahaa %.2f -> %.2f, viesti: %s" % [k + 1, mm, main.money, main._msg.text])
			var ac2 := Camera3D.new()
			main.add_child(ac2)
			ac2.look_at_from_position(main._atm_node.global_position + Vector3(2.5, 2.0, -4.5), main._atm_node.global_position + Vector3(0, 1.2, 0))
			ac2.current = true
			for i in 6:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_otto.png"))
			main.walker_out.activate_camera()
			ac2.queue_free()
			# Pelaaja auton eteen.
			var c0: Node3D = cars[0]
			var fw: Vector3 = -c0.global_transform.basis.z
			main.walker_out.global_position = c0.global_position + fw * 3.0 + Vector3(0, 0.3, 0)
			for i in 60:
				await main.get_tree().physics_frame
				if main.state == "cutscene":
					break
			print("LIIKENNE kolari: tila %s" % main.state)
		"minimouse":
			# Oikeat hiiritapahtumat minipeleille: liike kääntää tähtäystä, vasen nappi toimii, sahan veto.
			main._toggle_mount()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			var send := func(ev: InputEvent) -> void:
				Input.parse_input_event(ev)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
			main.kota_polkyt = 1
			main._start_chop()
			await main.get_tree().process_frame
			var cg: Node3D = main.world.kota.get_children().filter(func(c): return c is ChopGame)[0]
			cg._gust_next = 999.0
			var y0: float = cg._yaw
			var mm := InputEventMouseMotion.new()
			mm.relative = Vector2(-120, 0)
			mm.position = main.get_viewport().get_visible_rect().size / 2.0
			await send.call(mm)
			print("MOUSE chop yaw ", y0, " -> ", cg._yaw, " mouse_mode=", Input.mouse_mode)
			var want: Vector2 = cg._aim_to(ChopGame.PILE + Vector3(0, 0.18, 0))
			cg._yaw = want.x
			cg._pitch = want.y
			await main.get_tree().process_frame
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
				await main.get_tree().process_frame
			await send.call(click)
			await send.call(up)
			for i in 60:
				await main.get_tree().process_frame
				if cg._phase == "chop":
					break
			want = cg._aim_to(cg._log_pos + Vector3(0.08, ChopGame.LOG_L, 0))
			cg._yaw = want.x
			cg._pitch = want.y
			await main.get_tree().process_frame
			await send.call(click)
			await send.call(up)
			for i in 400:
				await main.get_tree().process_frame
				if cg._phase == "chop" and cg._swing_t < 0.0:
					break
			print("MOUSE chop stuck hit -> phase=", cg._phase, " swing_t=", cg._swing_t, " cracks=", cg._cracks, " sub=", cg._sub.text)
			cg._quit()
			await main.get_tree().process_frame
			main._start_saw()
			await main.get_tree().process_frame
			var sg: Node3D = main.world.kota.get_children().filter(func(c): return c is SawGame)[0]
			sg._gust_next = 999.0
			var a3: Vector2 = sg._aim_to(Vector3(0, SawGame.LOG_Y + SawGame.R, SawGame.END_Z - 0.36))
			sg._yaw = a3.x
			sg._pitch = a3.y
			await main.get_tree().process_frame
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
			await main.get_tree().process_frame
		"nappaimet":
			# Näppäinasetukset: E -> R toiminnolle, sitten R pyörälle (poistuu toiminnolta), ohjeteksti ja kuva.
			main.menu.open_main()
			main.menu._settings("sub_main")
			for i in 5:
				await main.get_tree().process_frame
			var tabs: TabContainer = main.menu.find_children("*", "TabContainer", true, false)[0]
			tabs.current_tab = tabs.get_tab_count() - 1
			var key := func(code: int) -> void:
				var ev := InputEventKey.new()
				ev.physical_keycode = code as Key
				ev.pressed = true
				Input.parse_input_event(ev)
				await main.get_tree().process_frame
				ev = ev.duplicate()
				ev.pressed = false
				Input.parse_input_event(ev)
				await main.get_tree().process_frame
			var row_of := func(a: String) -> int:
				for r in Settings.KEY_ROWS.size():
					if a in Settings.KEY_ROWS[r][0]:
						return r
				return -1
			var btn := func(row: int, slot: int) -> Button:
				for kb in main.menu._key_buttons:
					if kb[0] == row and kb[1] == slot:
						return kb[2]
				return null
			(btn.call(row_of.call("interact"), 0) as Button).pressed.emit()
			await key.call(KEY_R)
			print("NAPP toiminto=%s E-painallus->interact=%s R->interact=%s" % [Settings.keys_of(row_of.call("interact")),
				InputMap.action_has_event("interact", (func() -> InputEventKey:
					var e := InputEventKey.new(); e.physical_keycode = KEY_E; return e).call()),
				InputMap.action_has_event("interact", (func() -> InputEventKey:
					var e := InputEventKey.new(); e.physical_keycode = KEY_R; return e).call())])
			(btn.call(row_of.call("mount"), 0) as Button).pressed.emit()
			await key.call(KEY_R)
			print("NAPP pyörä=%s toiminto=%s viesti=%s" % [Settings.keys_of(row_of.call("mount")), Settings.keys_of(row_of.call("interact")), main.menu._key_note.text])
			(btn.call(row_of.call("interact"), 0) as Button).pressed.emit()
			await key.call(KEY_G)
			(btn.call(row_of.call("forward"), 1) as Button).pressed.emit()
			await key.call(KEY_ESCAPE)
			print("NAPP esc: eteen=%s viesti=%s valikko auki=%s" % [Settings.keys_of(0), main.menu._key_note.text, main.menu.visible])
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_nappaimet.png"))
			main.menu.close()
			await main.get_tree().process_frame
			print("NAPP vihje: ", Settings.key_hint("[E] Avaa ovi   [F] Pyörälle   [Q] kello   [A] ei vaihdu"))
			for i in 20:
				await main.get_tree().physics_frame
			await Kuva.piirto()
			print("NAPP pelin vihje: ", main._hint.text)
			Settings.reset_keys()
			print("NAPP palautus: toiminto=%s pyörä=%s" % [Settings.keys_of(row_of.call("interact")), Settings.keys_of(row_of.call("mount"))])
		"naapurit", "naapurit2", "naapurit3":  # naapurin talo ja piha kadulta päin (arto / pekka / sinikka)
			var key: String = {"naapurit": "arto", "naapurit2": "pekka", "naapurit3": "sinikka"}[scene]
			main.clock_min = 10.5 * 60.0  # Sinikka pihalla (8-10 uimassa, 12-17 rannalla)
			for i in 10:
				await main.get_tree().process_frame
			var yd: Array = main.world.neighbor_yards[key]
			var door: Vector3 = yd[0]
			var hc := M.w({"arto": M.NEIGHBOR_ARTO, "pekka": M.NEIGHBOR_PEKKA, "sinikka": M.NEIGHBOR_SINIKKA}[key])
			var out := Vector3(door.x - hc.x, 0, door.z - hc.z).normalized()
			var cam := Camera3D.new()
			cam.fov = 65.0
			main.add_child(cam)
			cam.look_at_from_position(door + out * 13.0 + out.rotated(Vector3.UP, 1.2) * 5.0 + Vector3(0, 4.0, 0),
				door + Vector3(0, 1.0, 0), Vector3.UP)
			cam.current = true
			main._msg.text = ""
		"kupla":
			# Puhekupla läheltä ja kaukaa: Pekka sanoo pitkän repliikin, kamera 1,6 m / 4 m / 9 m päästä.
			main.pekka.set_physics_process(false)
			var pp: Vector3 = main.pekka.yard[0]
			main.pekka.global_position = pp
			var fwd := Vector3(0, 0, 1)
			main.pekka.rotation.y = B.yaw_to(fwd)
			main.pekka.say(Main.PEKKA_LINES[3] + " " + Main.PEKKA_LINES[1])
			var kc := Camera3D.new()
			main.add_child(kc)
			kc.current = true
			for dist in [1.6, 4.0, 9.0]:
				kc.look_at_from_position(pp + fwd * dist + Vector3(0, 1.5, 0), pp + Vector3(0, 1.8, 0), Vector3.UP)
				await main.get_tree().create_timer(0.4).timeout
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%d.png" % int(dist * 10)))
				main.pekka.say(Main.PEKKA_LINES[3] + " " + Main.PEKKA_LINES[1])
		"minipelikuvat":
			# Kuvat WC- ja tiskausminipeleistä: ykkönen (lätäköitä), kakkonen (paperivaihe), huussi ja tiskaus.
			main._hud.visible = false
			var shot := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			for cfg in [["ykkonen", true], ["kakkonen", true], ["kakkonen", false]]:
				var g := WcGame.new()
				g.mode = cfg[0]
				g.flush = cfg[1]
				main.add_child(g)
				for i in 30:
					await main.get_tree().process_frame
				if g.mode == "ykkonen":
					g._aim = Vector2(40, -20)
					for k in 6:
						g._puddles.append(Vector2(200 + k * 12, 60 + (k % 3) * 10))
					g._inside = 3.0
					g._total = 4.0
				else:
					g._pushes = 3
					g._phase = "paper"
					g._sheets = 5
				for i in 5:
					await main.get_tree().process_frame
				await shot.call("%s_%s" % [cfg[0], "vesi" if cfg[1] else "huussi"])
				g._done = true
				g.queue_free()
			var tg := TiskiGame.new()
			tg.dishes_left = 1  # mummon kukkalautanen esille
			main.add_child(tg)
			tg.washed = 3
			tg._rack_list = TiskiGame.DISHES.slice(0, 3)
			tg._rebuild_rack()
			for i in 10:
				await main.get_tree().process_frame
			tg._dirt = 0.45
			tg._wobble = 0.6
			tg._last_dir = 1
			for i in 5:
				await main.get_tree().process_frame
			await shot.call("tiski")
			tg._look_up = 1.0  # kuivauskaappi
			for i in 5:
				await main.get_tree().process_frame
			await shot.call("tiski_kaappi")
			tg._finish()
		"mkey":
			for i in 30:
				await main.get_tree().process_frame
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_M
			ev.keycode = KEY_M
			ev.pressed = true
			Input.parse_input_event(ev)
			for i in 3:
				await main.get_tree().process_frame
			ev = ev.duplicate()
			ev.pressed = false
			Input.parse_input_event(ev)
			print("PAPER visible=", main._paper.visible, " paused=", main.get_tree().paused)
			var sc0: Vector2 = main._paper._vcenter
			Input.action_press("back")
			for i in 30:
				await main.get_tree().process_frame
			Input.action_release("back")
			print("PAPER siirto ", sc0, " -> ", main._paper._vcenter)
			ev = ev.duplicate()
			ev.pressed = true
			Input.parse_input_event(ev)
			for i in 3:
				await main.get_tree().process_frame
			ev = ev.duplicate()
			ev.pressed = false
			Input.parse_input_event(ev)
			for i in 3:
				await main.get_tree().process_frame
			print("PAPER after 2nd M visible=", main._paper.visible, " paused=", main.get_tree().paused)
		"mirkku_loppu":
			# Mirkun teltassa: teltta päivällä laavun vieressä, kukkakimppu Mirkulle illalla (vaihtoehto harmaana
			# päivällä) ja loppukohtaus: nuotio, sitten teltan ovi kiinni ja lyhty (hero shot). Kuvat _mloppu_*.
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.fov = 50.0
			var grab := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_mloppu_%s.png" % name))
			var pit := M.w(M.LAAVU)
			var tc: Vector3 = main.mirkku_tent.global_position
			main._hud.visible = false
			main.clock_min = 13 * 60.0
			main.player.global_position = pit + Vector3(0, 0.3, -12)
			for i in 30:
				await main.get_tree().process_frame
			cam.global_position = tc + Vector3(3.5, 1.6, -3.2)
			cam.look_at(tc + Vector3(0, 0.6, 0), Vector3.UP)
			cam.current = true
			for i in 12:
				await main.get_tree().process_frame
			await grab.call("teltta")
			cam.global_position = tc + (pit - tc).normalized() * 3.0 + Vector3(0, 1.0, 0)
			cam.look_at(tc + Vector3(0, 0.5, 0), Vector3.UP)
			for i in 6:
				await main.get_tree().process_frame
			await grab.call("ovi")
			cam.current = false
			main._hud.visible = true
			main.has_flowers = true
			var mk: Node3D = main.mirkku
			main.player.global_position = mk.global_position + Vector3(0, 0.3, 3.0)
			for i in 60:
				await main.get_tree().physics_frame
			print("MLOPPU päivällä: %s" % [main._talk_options("mirkku").filter(func(o): return o.id == "kukat_mirkulle")
				.map(func(o): return [o.enabled, o.get("why", "")])])
			main.clock_min = 19 * 60.0
			main.player.global_position = mk.global_position + Vector3(0, 0.3, 3.0)
			for i in 10:
				await main.get_tree().physics_frame
			main._talk_open("mirkku", mk)
			print("MLOPPU illalla: %s" % [main._talk_options("mirkku").filter(func(o): return o.id == "kukat_mirkulle")
				.map(func(o): return o.enabled)])
			var loppuja: int = main.endings.total("loppu")
			main._talk_choose("kukat_mirkulle")
			var t0 := Time.get_ticks_msec()
			for mark in [["nuotio", 3500], ["teltta_kiinni", 7600], ["hero", 11500]]:
				while Time.get_ticks_msec() - t0 < mark[1]:
					await main.get_tree().process_frame
				await grab.call(mark[0])
			while main.cutscene.busy and Time.get_ticks_msec() - t0 < 30000:
				await main.get_tree().process_frame
			print("MLOPPU loppu kirjattu: %s, kimppu %s, tila %s, päivä %d" % [main.endings.total("loppu") > loppuja, main.has_flowers, main.state, main.day])
		"mirkku":
			# Mirkku laavupolulla päivällä: yleiskuva polulta, lähikuva kukkamättäiden vierestä ja pelaaja vieressä
			# (puhevihje ja keskustelun vaihtoehdot). Kuvat _mirkku_*.
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.fov = 45.0
			main.clock_min = 13 * 60.0
			var mk: Node3D = main.mirkku
			var snap := func(name: String, eye: Vector3, at: Vector3, hud := false) -> void:
				main._hud.visible = hud
				cam.global_position = eye
				cam.look_at(at, Vector3.UP)
				cam.current = true
				for i in 12:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_mirkku_%s.png" % name))
			main.player.global_position = M.w(Vector2(870, 1200))  # kauempana: Mirkku puuhailee polulla
			for i in 400:
				await main.get_tree().physics_frame
			var mp: Vector3 = mk.global_position
			var fw: Vector3 = mk.global_basis.z  # kasvot −Z: kamera eteen
			await snap.call("polku", mp - fw * 7.0 + Vector3(2.0, 2.2, 0), mp + Vector3(0, 0.9, 0))
			await snap.call("lahi", mp - fw * 2.4 + Vector3(0.5, 1.4, 0), mp + Vector3(0, 1.1, 0))
			main.player.global_position = mp + Vector3(0, 0.3, 3.0)
			for i in 90:
				await main.get_tree().physics_frame
			mp = mk.global_position
			await snap.call("vieressa", main.player.global_position + Vector3(2.5, 2.0, 2.5), (mp + main.player.global_position) / 2.0 + Vector3(0, 1.0, 0), true)
			print("MIRKKU paikka %s, etäisyys %.1f, vaihtoehdot %s" % [M.to_px(mp), mk.distance_to_player(),
				main._talk_options("mirkku").map(func(o): return o.id)])
			main._talk_open("mirkku", mk)
			print("MIRKKU juttu: ", main._talk_chat_line() if main._talk_who == "mirkku" else "(ei auennut: %s)" % main._talk_who)
			await snap.call("puhe", main.player.global_position + Vector3(2.5, 2.0, 2.5), (mp + main.player.global_position) / 2.0 + Vector3(0, 1.0, 0), true)
			main._talk_box.close()
		"laavut":
			# Kaikki laavut ja nuotiopaikat iltapäivän valossa, nuotiot palamassa: Antinsuonkangas, Viitajärvi,
			# Kiilinlammen grillikatos, Haapajärven kota, Keskimmäisen laavu (mökki) ja Vaalan laavu. Kuvat _laavu_*.
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.fov = 55.0
			var shot := func(name: String, pit: Vector3, toward: Vector3) -> void:
				var t := Vector3(toward.x, 0, toward.z).normalized()
				for k in 2:
					var side := t.cross(Vector3.UP) * (1.0 if k == 0 else -1.0)
					var eye := pit - t * 6.5 + side * 4.0 + Vector3(0, 3.0, 0)
					cam.global_position = eye
					cam.look_at(pit + t * 1.0 + Vector3(0, 0.8, 0), Vector3.UP)
					cam.current = true
					for i in 12:
						await main.get_tree().process_frame
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_laavu_%s_%d.png" % [name, k]))
			main._hud.visible = false
			main.clock_min = 17 * 60.0
			for i in 5:
				await main.get_tree().process_frame
			main.world.fire.visible = true
			main.world.viita_fire.visible = true
			main._viita_fire_day = main.day  # erämaan logiikka näyttää nuotion vain sytytyspäivänä
			var ap: Vector3 = M.w(M.LAAVU)
			await shot.call("antinsuo", ap, Vector3(0, 0, 1))
			var vt := M.w2(M.VIITAJARVI) - M.w2(M.VIITA_LAAVU)
			await shot.call("viita", main.world.viita_pos, Vector3(-vt.x, 0, -vt.y))
			await shot.call("grillikatos", M.w(M.GRILLIKATOS), Vector3(1, 0, 0))
			await shot.call("kota", main.world.kota.global_position if main.world.kota != null else M.w(M.KOTA), Vector3(0, 0, 1))
			var mk: Node3D = main.mokki
			mk.ensure_built()
			for i in 10:
				await main.get_tree().process_frame
			var lay: Dictionary = Mokki.keskimmainen_layout()
			await shot.call("keskimmainen", mk.to_global(mk.laavu_fire), -(mk.global_basis * Vector3(lay.d.x, 0, lay.d.y)))
			main._start_mopo()
			for i in 60:
				await main.get_tree().process_frame
			var vl: Node3D = main.mopo_trip.vaala
			print("LAAVUT vaala %s" % vl.laavu_fire)
			await shot.call("vaala", vl.to_global(vl.laavu_fire), -(vl.global_basis * Vector3(vl.laavu_lake.x, 0, vl.laavu_lake.y)))
			cam.queue_free()
		"mummokeppi":
			# Jalan rollaattorimummon eteen: keppi nousee, osuu päähän -> WASTED ja Päivin motkotus mummoista.
			main._toggle_mount()
			var st: Node3D = main.mummot._stand
			var front: Vector3 = st.global_transform * Vector3(0.1, 0, 1.25)
			main.walker_out.global_position = front + Vector3(0, 0.3, 0)
			main.walker_out.rotation.y = B.yaw_to(st.global_position - front)
			var sc := Camera3D.new()
			main.add_child(sc)
			sc.look_at_from_position(st.global_transform * Vector3(-3.2, 1.6, 0.8), st.global_transform * Vector3(0, 1.2, 0.7))
			sc.current = true
			var shots := 0
			for i in 400:
				await main.get_tree().process_frame
				if main.mummot._swing_t > 0.72 and shots == 0:
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_isku.png"))
					shots = 1
				if main.state == "cutscene":
					break
			print("MUMMOKEPPI state=%s msg=%s" % [main.state, main._msg.text.replace("\n", " | ")])
			for i in 150:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_wasted.png"))
			for k in 4:
				for i in 100:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_paivi%d.png" % k))
		"mummot":
			# Pyörällä lujaa penkin ohi: mummot suuttuvat ja heittävät kettukarkkeja. Sitten jalan poimimaan.
			var hits := [0]
			main.mummot.hit.connect(func(_d: Vector3) -> void: hits[0] += 1)
			var bp: Vector3 = main.mummot.global_position
			main.bike.global_position = bp + Vector3(-9.0, 0.3, 2.5)
			main.bike.rotation.y = B.yaw_to(Vector3(1, 0, 0))
			for i in 10:
				await main.get_tree().physics_frame
			var sc := Camera3D.new()
			main.add_child(sc)
			sc.global_position = bp + Vector3(3.0, 1.6, 4.5)
			sc.look_at(bp + Vector3(0, 0.8, 0), Vector3.UP)
			sc.current = true
			for i in 3:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_bench.png"))
			sc.queue_free()
			main.bike.activate_camera()
			main.bike.speed = 8.0
			Input.action_press("forward")
			for i in 90:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			print("MUMMOT angry=%s status=%s" % [main.mummot.is_angry(), main._status.text])
			for i in 180:
				await main.get_tree().physics_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_throw.png"))
			for i in 240:
				await main.get_tree().physics_frame
			print("MUMMOT hits=%d ground=%d angry=%s" % [hits[0], main.mummot._ground.size(), main.mummot.is_angry()])
			main._toggle_mount()
			var s0: float = main.walker_out.stamina
			main.walker_out.stamina = 50.0
			if not main.mummot._ground.is_empty():
				main.walker_out.global_position = main.mummot._ground[0].node.global_position + Vector3(0, 0.4, 0)
			for i in 20:
				await main.get_tree().physics_frame
			print("MUMMOT picked stamina 50 -> %.0f ground=%d msg=%s" % [main.walker_out.stamina, main.mummot._ground.size(), main._msg.text])
		"lawnday":
			# Kasvu, kehu ja motkotus aamulla, varaosa Artolta ja korjaus kaljalla. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main._toggle_mount()
			main.lawn.lengths.fill(0.5)
			main._lawn_praise = true
			main._new_day(main.home_zone + Vector3(0, 0, 4), false)
			print("DAY avg=%.2f money=%s objs=%d msg=%s" % [main.lawn.avg_len(), main._eur(main.money), main.lawn.objects.size(), main._msg.text.replace("\n", " | ")])
			main.mower_broken = true
			main.walker_out.global_position = main.arto.global_position + Vector3(1.5, 0.3, 0)
			for i in 10:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("ARTO hint=", main._hint.text)
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			main._test_talk(["varaosa"])  # Arto avaa keskustelun; varaosa ostetaan valinnalla
			print("ARTO part=%s money=%s" % [main.has_mower_part, main._eur(main.money)])
			main.beers = 1
			main.walker_out.global_position = main.lawn.mower.global_position + Vector3(1.0, 0.3, 0)
			for i in 10:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("FIX hint=", main._hint.text)
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			print("FIX broken=%s part=%s beers=%d" % [main.mower_broken, main.has_mower_part, main.beers])
			main._save_game()
			var cfg := ConfigFile.new()
			cfg.load(Main.SAVE_PATH)
			var bytes: PackedByteArray = cfg.get_value("nurmikko", "pituudet", PackedByteArray())
			print("SAVE cells=%d first=%d" % [bytes.size(), bytes[0] if bytes.size() > 0 else -1])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"lawn", "police":
			# Nurmikko: kuva ylhäältä, sitten leikkuu eteenpäin (police: kaksi siiliä terän eteen).
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main._toggle_mount()
			main.walker_out.global_position = main.lawn.mower_park + Vector3(1.2, 0.5, 0.8)
			for i in 20:
				await main.get_tree().physics_frame
			print("LAWN avg=%.2f ratio=%.2f objs=%d hint=%s" % [main.lawn.avg_len(), main.lawn.cut_ratio(), main.lawn.objects.size(), main._hint.text])
			main._msg.text = ""
			var tc := Camera3D.new()
			main.add_child(tc)
			var c := Vector3(main.lawn.pivot.x, 0, main.lawn.pivot.y)
			c.y = Terrain.h(c.x, c.z)
			tc.global_position = c + Vector3(-9.0, 9.0, 12.0)
			tc.look_at(c, Vector3.UP)
			tc.current = true
			for i in 5:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_top.png"))
			tc.queue_free()
			main.walker_out.activate_camera()
			if scene == "police":
				var sp: Vector3 = main.lawn.mower_park + Vector3(0, 0, -2.0)
				for o in main.lawn.objects.duplicate():
					if o.kind == "siili":
						main.lawn.remove_object(o)
				for k in 2:
					var n := Node3D.new()
					main.lawn.add_child(n)
					main.lawn.objects.append({"kind": "siili", "pos": Vector2(sp.x, sp.z - k * 1.5), "r": 0.16, "node": n})
			await main.get_tree().process_frame
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			print("MOW start mowing=", main.mowing, " msg=", main._msg.text.replace("\n", " | "))
			Input.action_press("forward")
			for i in 300:
				await main.get_tree().physics_frame
				if not main.mowing:
					break
			Input.action_release("forward")
			print("MOW after ratio=%.2f mowing=%s siilit=%d kivet=%d broken=%s police=%s msg=%s" % [main.lawn.cut_ratio(), main.mowing,
				main.lawn_siilit, main.lawn_kivet, main.mower_broken, is_instance_valid(main.police), main._msg.text.replace("\n", " | ")])
			main._msg.text = ""
			var tc2 := Camera3D.new()
			main.add_child(tc2)
			tc2.global_position = c + Vector3(-7.0, 10.0, 9.0)
			tc2.look_at(c, Vector3.UP)
			tc2.current = true
			for i in 5:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_cut.png"))
			tc2.queue_free()
			main.player.activate_camera()
			if scene == "police":
				for i in 1800:
					await main.get_tree().physics_frame
					if i % 120 == 0 and is_instance_valid(main.police):
						print("  police t=%d d=%.1f mode=%s alerted=%s" % [i / 60, main.police.global_position.distance_to(main.player.global_position),
							main.police.mode, main.police.alerted])
					if main.state != "ulkona":
						break
				print("POLICE d=%.1f status=%s state=%s" % [main.police.global_position.distance_to(main.player.global_position) if is_instance_valid(main.police) else -1.0,
					main._status.text, main.state])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"lansi_maasto":
			# Länsiosa maaston pinnalla (kirkko, kellotapuli, hautausmaa, Pirtti) ja maaston länsireuna. Lokiin rakennusten
			# pohjan kulmien korkeus suhteessa keskipisteeseen (_lift_node nostaa keskeltä; sokkeli peittää, jos kulma on
			# alle sokkelin korkeuden alempana) ja maaston korkeus länsireunalla. Kuvat _lansi_*.
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.fov = 55.0
			cam.far = 3000.0
			var snap := func(name: String, eye: Vector3, at: Vector3) -> void:
				cam.global_position = eye
				cam.look_at(at, Vector3.UP)
				cam.current = true
				for i in 14:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_lansi_%s.png" % name))
			main._hud.visible = false
			main.clock_min = 12 * 60.0
			var w: Node3D = main.world
			var g3 := func(p: Vector2, up := 0.0) -> Vector3:
				var q := M.w2(p)
				return Vector3(q.x, Terrain.h(q.x, q.y) + up, q.y)
			print("LANSI maasto: origo %s, %d x %d" % [Terrain.origin, Terrain.nx, Terrain.nz])
			for b in [["kirkko", M.KIRKKO, 0.7], ["tapuli", M.KELLOTAPULI, 0.5], ["pirtti", M.PIRTTI, 0.0]]:
				var f: Dictionary = w._osm_fit_at(b[1])
				if f.is_empty():
					print("LANSI %s: ei rakennusta  TESTI VIKA" % b[0])
					continue
				var c: Vector2 = f.c
				var hc := Terrain.h(c.x, c.y)
				var ax := Vector2(cos(f.yaw), -sin(f.yaw))
				var az := Vector2(sin(f.yaw), cos(f.yaw))
				var ds := []
				var low := 0.0
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						var q: Vector2 = c + ax * sx * f.l / 2.0 + az * sz * f.d / 2.0
						var dh := Terrain.h(q.x, q.y) - hc
						low = minf(low, dh)
						ds.append("%.2f" % dh)
				# Kulma alempana kuin sokkeli (+0,3 m Pirtillä, jolla ei ole sokkelia) = rako seinän alla.
				print("LANSI %s: keskellä maa %.2f, kulmat - keskus %s (sokkeli %.1f m)%s" % [b[0], hc, ds, b[2],
					"  TESTI VIKA rako" if -low > b[2] + 0.3 else ""])
			var edge := []
			var zero := false
			for x in [-995.0, -900.0, -800.0, -760.0, -740.0, -700.0]:
				var z := M.w2(M.KIRKKO).y
				var eh := Terrain.h(x, z)
				zero = zero or eh == 0.0
				edge.append("x %.0f: %.2f" % [x, eh])
			print("LANSI reuna kirkon kohdalla: %s%s" % [", ".join(edge), "  TESTI VIKA maasto puuttuu (h = 0)" if zero else ""])
			main.player.global_position = g3.call(M.KIRKKO, 0.3) + Vector3(40, 0, 40)
			for i in 20:
				await main.get_tree().process_frame
			var kd: Vector3 = w.kirkko_pos
			var kc: Vector3 = g3.call(M.KIRKKO)
			var out := Vector3(kd.x - kc.x, 0, kd.z - kc.z).normalized()
			await snap.call("kirkko_ovi", kd + out * 22.0 + Vector3(4, 3.0, 0), kc + Vector3(0, 4.0, 0))
			await snap.call("kirkko_sivu", kc - out.cross(Vector3.UP) * 38.0 + Vector3(0, 4.0, 0), kc + Vector3(0, 3.0, 0))
			var tp: Vector3 = w.tapuli_pos
			var tc: Vector3 = g3.call(M.KELLOTAPULI)
			await snap.call("tapuli", tp + (tp - tc).normalized() * 12.0 + Vector3(0, 2.0, 0), tc + Vector3(0, 2.5, 0))
			var hm: Vector3 = g3.call(Vector2(-170, 455))
			await snap.call("hautausmaa", hm + Vector3(30, 9, 45), hm)
			await snap.call("hautausmaa_ylha", hm + Vector3(0, 110, 20), hm)
			await snap.call("reuna_lanteen", kc + Vector3(60, 18, 0), kc + Vector3(-250, -5, 0))
			await snap.call("reuna_ylha", kc + Vector3(-120, 260, 60), kc + Vector3(-160, 0, 0))
			var md: Vector3 = w.museum_door
			var pc: Vector3 = g3.call(M.PIRTTI)
			await snap.call("pirtti", md + (md - pc).normalized() * 14.0 + Vector3(3, 2.5, 0), pc + Vector3(0, 2.0, 0))
		_:
			return 0
	return 1
