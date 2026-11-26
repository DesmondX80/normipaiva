extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "muut_p_s". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Iskelmat := preload("res://scripts/iskelmat.gd")
const Looks := preload("res://scripts/looks.gd")
const TanssiGame := preload("res://scripts/tanssi_game.gd")
const PyhakoskiLegenda := preload("res://scripts/pyhakoski_legenda.gd")
const RaateLegenda := preload("res://scripts/raate_legenda.gd")
const Saappaat := preload("res://scripts/kumisaappaat.gd")

const KOHTAUKSET := ["riskit", "rytmi", "rankkubotti", "saappaat", "puhelin", "rasvanappi", "saloisrata", "rintamus", "raate", "pyhakoski", "reppukaytto", "reppu", "raahepaivi", "purema", "rankkarit_kuvat"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"riskit":
			# Huumekaupan riskit (tools/testit/riskit.gd): --riski=perus|paivakirja|<osa>; tallennus palautetaan lopuksi.
			var saved_rk := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			var rk: Node = load("res://tools/testit/riskit.gd").new()
			rk.main = main
			main.add_child(rk)
			await rk.run()
			if not saved_rk.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_rk)
			else:
				DirAccess.remove_absolute(Main.SAVE_PATH)
			main.get_tree().quit()
			return 2
		"rytmi":
			# Vuorokausirytmi: kuvat Järvikujalta eri kellonaikoina, Päivin vaihe, naapurit ja katuvalot.
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			main.wife_alerted = false
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.global_position = main.home_zone + Vector3(-14, 4.0, 22)
			cam.look_at(main.home_zone + Vector3(10, 2.0, -10), Vector3.UP)
			cam.current = true
			for h in [8.0, 12.0, 17.0, 21.5, 23.0, 1.5]:
				main.clock_min = h * 60.0
				main._rhythm_t = 0.0
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%02d.png" % int(h * 10)))
				print("RYTMI klo %s: aurinko %.0f°, Päivi %s (näkyy %s, pihassa %s), Pekka ulkona %s, katuvalot %s" % [main._clock_text(),
					main._sun_elevation(main.clock_min), main._wife_phase, main.wife.visible, main.wife.parked, main.pekka.visible, main.world.lamps.visible])
			var lp: Vector3 = main.world.lamp_spots[0]
			var best := INF
			for q in main.world.lamp_spots:
				if q.distance_to(main.home_zone) < best:
					best = q.distance_to(main.home_zone)
					lp = q
			lp.y += Terrain.h(lp.x, lp.z)
			cam.global_position = lp + Vector3(9, -3.5, 9)
			cam.look_at(lp, Vector3.UP)
			for i in 5:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_lamppu.png"))
			print("RYTMI lamppuja %d" % main.world.lamp_spots.size())
		"rankkubotti":
			# Botti pelaa rankkarit (5 laukausta ja 5 torjuntaa) loppuun: lukitsee tähtäimen keskelle ja voiman kohtuulliseksi,
			# torjunnassa heittäytyy potkun suuntaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var fr := func(n: int) -> void:
				for i in n:
					await main.get_tree().process_frame
			var press := func(action: String) -> void:
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
			if main.player != main.walker_out:
				main._toggle_mount()
			main.walker_out.global_position = main.world.kentta_spot + Vector3(0, 0.5, 0)
			await fr.call(30)
			main._boys_field = "saloinen"
			var result := [-1, -1]
			main._start_rankku("saloinen")
			var g: Node3D = main._rankku
			g.finished.connect(func(m: int, t: int) -> void:
				result[0] = m
				result[1] = t)
			var steps := 0
			var shots := 0
			var saves := 0
			var last_phase := ""
			while is_instance_valid(g) and g._phase != "done" and steps < 20000:
				await main.get_tree().process_frame
				steps += 1
				if not is_instance_valid(g):
					break
				match g._phase:
					"aim_x":
						if absf(g._aim.x) < 0.22:
							await press.call("jump")
					"aim_y":
						if g._aim.y > 0.45 and g._aim.y < 0.62:
							await press.call("jump")
					"power":
						if g._power > 0.5 and g._power < 0.64:
							shots += 1
							await press.call("jump")
					"dive":
						if g._keeper_dive == 2:
							saves += 1
							var key: String = {-1: "left", 0: "back", 1: "right"}[g._kick_dir]
							if g._kick_dir != 0 and g._kick_high:
								Input.action_press("forward")
							await press.call(key)
							Input.action_release("forward")
				last_phase = g._phase
			print("BOTTI rankkarit: laukauksia %d, torjuntayrityksiä %d, askeleita %d, loppuvaihe %s, tulos %s" % [shots, saves, steps, last_phase, str(result)])
			await main.get_tree().create_timer(3.0).timeout
			print("BOTTI rankkarit jälkeen: tulos %s, tila %s, viesti '%s'" % [str(result), main.state, main._msg.text.replace("\n", " ")])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"saappaat":
			# #274: kumisaappaat kodin eteisestä (E jalkaan ja pois), asun vaihto saappaat jalassa (haalari voittaa), pyörä,
			# mökin saappaat ("jo jalassa"), tallennus. Kuvat: esine edestä, päädystä ja ylhäältä, jalat lähikuvina.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(name: String) -> void:
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var close := func(target: Vector3, from: Vector3, name: String) -> void:
				var prev := main.get_viewport().get_camera_3d()
				var c := Camera3D.new()
				c.fov = 35.0
				main.add_child(c)
				c.global_position = from
				c.look_at(target, Vector3.UP)
				c.make_current()
				await snap.call(name)
				c.queue_free()
				prev.make_current()
			var press := func() -> void:
				await main.get_tree().process_frame
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
			var menu := func(id: String) -> void:  # E-valikosta valinta (kuten näppäin: valikko kiinni ja chosen)
				print("SAAPPAAT valikko %s -> %s" % [main._item_menu._items.map(func(it): return it[0]), id])
				if not main._item_menu.visible or main._item_menu._items.filter(func(it): return it[0] == id).is_empty():
					print("TESTI VIKA saappaat: valikossa ei ole '%s'" % id)
					return
				main._item_menu.visible = false
				main._item_menu.chosen.emit(id)
				for k in 3:  # sisätilan _process päivittää maton näkyvyyden
					await main.get_tree().process_frame
			var types := func() -> Array:
				var t := []
				for n in main.get_tree().root.find_children("*", "Node3D", true, false):
					if n.has_meta("player_body") and not n.shoe_type in t:
						t.append(n.shoe_type)
				return t
			var check := func(what: String, got: Variant, want: Variant) -> void:
				if got != want:
					print("TESTI VIKA saappaat %s: %s, pitäisi olla %s" % [what, got, want])
			var saved_boots := func() -> String:
				var cf := ConfigFile.new()
				cf.load(Main.SAVE_PATH)
				return cf.get_value("pelaaja", "saappaat", "<puuttuu>")
			main._note.visible = false
			Looks.boots = ""
			Saappaat.bag = ""
			main._set_outfit("tuulipuku")
			if main.player != main.walker_out:
				main._toggle_mount()
			main._enter_home("ovi")
			for i in 5:
				await main.get_tree().process_frame
			# Pelikameralta heti sisään tultua: esineen koko ruudulla (löydettävyys, vähintään noin 30 px).
			var px_size := func(node: Node3D) -> Vector2:
				var cam := main.get_viewport().get_camera_3d()
				var m: Vector2 = node.get_meta("matto") / 2.0  # maton puolikkaat (kärkien suunta, sivusuunta)
				var r := Rect2(cam.unproject_position(node.global_position), Vector2.ZERO)
				for corner in [Vector3(-m.y, 0, -m.x), Vector3(m.y, 0, -m.x), Vector3(-m.y, 0, m.x), Vector3(m.y, 0, m.x),
						Vector3(-0.2, 0.375, 0.09), Vector3(0.2, 0.375, 0.09)]:
					r = r.expand(cam.unproject_position(node.global_transform * corner))
				return r.size  # matto ja varsien yläreuna
			await snap.call("_koti_tulo.png")
			print("SAAPPAAT koti pelikamera esine+matto %s px, pelaaja %s px" % [px_size.call(main.home_int._boots),
				main.get_viewport().get_camera_3d().unproject_position(main.home_int.walker.global_position)])
			# 1. Kotona: esine kolmesta suunnasta (-X = seinä, kärjet +X eteiseen), sitten E.
			var bp: Vector3 = main.home_int._boots.global_position
			var hx: Vector3 = main.home_int.global_basis.x
			var hz: Vector3 = main.home_int.global_basis.z
			var mid := bp + Vector3(0, 0.18, 0)
			await close.call(mid, mid + hx * 1.1 + Vector3(0, 0.35, 0), "_esine_edesta.png")
			await close.call(mid, mid + hz * 1.1 + hx * 0.2 + Vector3(0, 0.3, 0), "_esine_paadysta.png")
			await close.call(bp, bp + Vector3(0, 1.4, 0) + hx * 0.05, "_esine_ylhaalta.png")
			main.home_int.walker.position = main.home_int.SPOTS.saappaat[0]
			for i in 5:
				await main.get_tree().process_frame
			print("SAAPPAAT vihje '%s'" % main._hint.text)
			await press.call()
			await snap.call("_koti_valikko.png")
			await menu.call("jalkaan")
			print("SAAPPAAT boots %s, tyyppi %s, esine näkyvissä %s, malleja %d, viesti '%s'" % [Looks.boots, types.call(),
				main.home_int._boots.visible, main.get_tree().root.find_children("*", "Node3D", true, false).filter(
				func(n: Node) -> bool: return n.has_meta("player_body")).size(), main._msg.text])
			check.call("koti E", [Looks.boots, types.call(), main.home_int._boots.visible], ["jalassa", ["kumisaapas"], false])
			check.call("tallennus koti", saved_boots.call(), "jalassa")
			await snap.call("_koti.png")
			var wp: Vector3 = main.home_int.walker.global_position
			await close.call(wp + Vector3(0, 0.3, 0), wp + hz * 1.4 + hx * 0.5 + Vector3(0, 0.5, 0), "_jalat.png")
			await close.call(wp + Vector3(0, 0.3, 0), wp + hx * 1.4 + Vector3(0, 0.5, 0), "_jalat_sivu.png")
			# K3: asun vaihto pitää saappaat, paitsi hiihtohaalarissa.
			for o in ["farkut", "tyovaatteet", "hiihtohaalari", "tuulipuku"]:
				main._set_outfit(o)
				await main.get_tree().process_frame
				print("SAAPPAAT asu %s -> %s" % [o, types.call()])
				check.call("asu " + o, types.call(), ["kuukenka" if o == "hiihtohaalari" else "kumisaapas"])
			# 2. Ulos pyörälle.
			main.home_int.exit_door = "ovi"
			main._on_home_exited()
			if main.player == main.walker_out:
				main._toggle_mount()
			for i in 30:
				await main.get_tree().process_frame
			print("SAAPPAAT pyörä %s" % [types.call()])
			await snap.call("_pyora.png")
			var kp := main.bike.global_position + Vector3(0, 0.45, 0)
			await close.call(kp, kp + main.bike.global_basis.x * 1.6 + Vector3(0, 0.2, 0), "_pyora_jalat.png")
			await close.call(kp, kp - main.bike.global_basis.x * 1.6 + Vector3(0, 0.2, 0), "_pyora_jalat_vasen.png")
			# 3. Mökillä: sama pari, joten mökin matto on tyhjä; E riisuu ne reppuun.
			main._toggle_mount()
			for i in 5:
				await main.get_tree().process_frame
			await snap.call("_mokki_tulo.png")
			for i in 5:
				await main.get_tree().process_frame
			print("SAAPPAAT mökki vihje '%s'" % main._hint.text)
			await press.call()
			await menu.call("reppuun")
			var bag_cf := ConfigFile.new()
			bag_cf.load(Main.SAVE_PATH)
			check.call("tallennus reppu", bag_cf.get_value("pelaaja", "saappaat_repussa", ""), "repussa")
			await snap.call("_mokki.png")
			# Mökin matolle: sama pari näkyy taas kummallakin matolla.
			await press.call()
			await menu.call("tahan")
			await press.call()
			await menu.call("jalkaan")
			# 4. Kotona E: omat kengät takaisin.
			main._enter_home("ovi")
			main.home_int.walker.position = main.home_int.SPOTS.saappaat[0]
			for i in 5:
				await main.get_tree().process_frame
			print("SAAPPAAT koti 2 vihje '%s'" % main._hint.text)
			await press.call()
			check.call("kodin matto tyhjä", main.home_int._boots.visible, false)
			await menu.call("tahan")  # mökiltä otetut saappaat kodin matolle
			print("SAAPPAAT pois: boots '%s', tyyppi %s, esine näkyvissä %s, viesti '%s'" % [Looks.boots, types.call(),
				main.home_int._boots.visible, main._msg.text])
			check.call("koti pois", [Looks.boots, types.call(), main.home_int._boots.visible], ["", ["lenkkari"], true])
			await snap.call("_pois.png")
			# 5. Repusta (I tai T) saappaat jalkaan kotipihalla ja takaisin reppuun.
			await press.call()
			await menu.call("reppuun")
			check.call("kotoa reppuun", [Looks.boots, Saappaat.bag, main.home_int._boots.visible], ["", "repussa", false])
			main.home_int.exit_door = "ovi"
			main._on_home_exited()
			for i in 20:
				await main.get_tree().process_frame
			var items_ids := func() -> Array:
				return main.inventory_items().map(func(it): return it.icon)
			print("SAAPPAAT reppu %s" % [items_ids.call()])
			check.call("repussa", "kumisaappaat" in items_ids.call(), true)
			main._journal.open_at("reppu")
			for i in 4:
				await main.get_tree().process_frame
			await snap.call("_reppu.png")
			main._journal.toggle()
			main.use_item("saappaat")
			for i in 3:
				await main.get_tree().process_frame
			print("SAAPPAAT repusta: boots '%s', reppu '%s', tyyppi %s, viesti '%s'" % [Looks.boots, Saappaat.bag, types.call(), main._msg.text])
			check.call("repusta jalkaan", [Looks.boots, Saappaat.bag, types.call()], ["jalassa", "", ["kumisaapas"]])
			await snap.call("_pihalla.png")
			var pw: Vector3 = main._active_walker().global_position
			await close.call(pw + Vector3(0, 0.3, 0), pw + Vector3(1.0, 0.6, 1.0), "_pihalla_jalat.png")
			main.use_item("saappaat")
			check.call("takaisin reppuun", [Looks.boots, Saappaat.bag, types.call()], ["", "repussa", ["lenkkari"]])
			# Haalarissa repusta: kuukengät pysyvät, saappaat repussa.
			main._set_outfit("hiihtohaalari")
			await main.get_tree().process_frame
			main.use_item("saappaat")
			print("SAAPPAAT haalari: boots '%s', reppu '%s', tyyppi %s, viesti '%s'" % [Looks.boots, Saappaat.bag, types.call(), main._msg.text])
			check.call("haalari repusta", [Looks.boots, Saappaat.bag, types.call()], ["", "repussa", ["kuukenka"]])
			main._set_outfit("tuulipuku")
			# 6. Tallennus.
			print("SAAPPAAT tallennus pelaaja/saappaat '%s'" % saved_boots.call())
			check.call("tallennus lopuksi", saved_boots.call(), "")
			Looks.outfit = "tuulipuku"
			Looks.boots = ""
			Saappaat.bag = ""
			var f := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f.store_buffer(saved)
			f.close()
			main.get_tree().quit()
		"puhelin":
			# Päivin kännykkä (#16): kodin yöpöydältä, P soimaan, N seuraava, U voimakkuus, kuulokkeet tauottavat, P taskuun.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(name: String) -> void:
				for i in 15:
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
			main.phone.found = false
			if main.player != main.walker_out:
				main._toggle_mount()
			main._note.visible = false
			main._enter_home("ovi")
			main.home_int.walker.position = main.home_int.SPOTS.puhelin[0]
			for i in 5:
				await main.get_tree().process_frame
			print("PUHELIN yöpöydällä vihje '%s', malli näkyy %s" % [main._hint.text, main.home_int._phone.visible])
			await snap.call("_koti.png")
			var pc := Camera3D.new()
			main.home_int.add_child(pc)
			pc.fov = 40.0
			pc.look_at_from_position(main.home_int.to_global(main.home_int._phone.position + Vector3(0.35, 0.45, 0.35)), main.home_int.to_global(main.home_int._phone.position))
			pc.current = true
			await snap.call("_lahikuva.png")
			pc.queue_free()
			await press.call("interact")
			print("PUHELIN löydetty %s, malli näkyy %s, viesti '%s'" % [main.phone.found, main.home_int._phone.visible, main._msg.text])
			main.home_int.exit_door = "ovi"
			main._on_home_exited()
			for i in 5:
				await main.get_tree().process_frame
			print("PUHELIN lista %d biisiä: %s" % [Iskelmat.playlist().size(), Iskelmat.playlist().slice(0, 3)])
			for sg: Dictionary in TanssiGame.Biisit.SONGS:
				print("PUHELIN %s: '%s'" % [sg.file in Iskelmat.playlist(), Iskelmat.title(sg.file)])
				if not sg.file in Iskelmat.playlist():
					print("TESTI VIKA puhelimesta puuttuu %s" % sg.title)
			await press.call("phone")
			for i in 30:
				await main.get_tree().process_frame
			print("PUHELIN soi %s '%s', väylä %s -> %s, viesti '%s'" % [main.phone.audible(), main.phone.title, main.phone._player.bus,
				AudioServer.get_bus_send(AudioServer.get_bus_index(main.phone._player.bus)), main._msg.text])
			await snap.call("_soi.png")
			var t1: String = main.phone.title
			await press.call("next_song")
			print("PUHELIN seuraava '%s' -> '%s'" % [t1, main.phone.title])
			await press.call("phone_volume")
			print("PUHELIN voimakkuus %d (%.0f dB), viesti '%s'" % [main.phone.volume, main.phone._player.volume_db, main._msg.text])
			await snap.call("_seuraava.png")
			main.headphones.found = true
			await press.call("headphones")
			for i in 5:
				await main.get_tree().process_frame
			print("PUHELIN kuulokkeet päässä: puhelin kuuluu %s, kuulokkeet soi %s" % [main.phone.audible(), main.headphones._player.playing and not main.headphones._player.stream_paused])
			await press.call("headphones")
			for i in 5:
				await main.get_tree().process_frame
			print("PUHELIN kuulokkeet pois: puhelin kuuluu %s" % main.phone.audible())
			await press.call("phone")
			for i in 30:
				await main.get_tree().process_frame
			print("PUHELIN taskuun: soi %s, viesti '%s'" % [main.phone.audible(), main._msg.text])
			await snap.call("_taskussa.png")
			var f := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f.store_buffer(saved)
			f.close()
			main.get_tree().quit()
		"rasvanappi":
			# Makasiini aseman takana ulkoa ja takaoven vihje, sitten minipeli luukulta (tools/testit/rasvanappi_kuvat.gd
			# kuvaa minipelin vaiheet erikseen).
			if main.player != main.walker_out:
				main._toggle_mount()
			main._msg.text = ""
			main._note.visible = false
			var md: Vector3 = main.world.makasiini_door
			md.y = Terrain.h(md.x, md.z)
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.current = true
			var views := [["_ylla", Vector3(14, 30, 18), Vector3(8, 0, 0)], ["_kadulta", Vector3(14, 4, 14), Vector3(8, 2, 0)],
				["_takaovi", Vector3(-6, 2.2, 3), Vector3(1.5, 1.6, 0)], ["_laituri", Vector3(16, 5, -12), Vector3(8, 2, 0)],
				["_ovi_lahelta", Vector3(-2.2, 1.9, 0.6), Vector3(1.5, 1.6, 0)]]
			for v in views:
				cam.look_at_from_position(md + v[1], md + v[2])
				for i in 15:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", v[0] + ".png"))
			cam.current = false
			main.walker_out.activate_camera()
			main.walker_out.global_position = Vector3(md.x, Terrain.h(md.x, md.z) + 0.4, md.z)
			for i in 10:
				await main.get_tree().process_frame
			print("RASVA ovi %s pelaaja %s" % [md, main.walker_out.global_position])
			print("RASVA ovella vihje '%s'" % main._hint.text)
			main._start_rasvanappi()
			for i in 200:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_luukku.png"))
			main._rasva_game._done(true)
			await main.get_tree().process_frame
			print("RASVA tulos viesti '%s', ohjaus %s" % [main._msg.text, main.player.controls_enabled])
			main.get_tree().quit()
		"saloisrata":
			# Saloisten rata: asema ylhäältä, kaarre pohjoiseen, talojen välit, länsipää ja koillinen; aikataulun juna laiturilla.
			if main.player != main.walker_out:
				main._toggle_mount()
			main._note.visible = false
			var cam := Camera3D.new()
			cam.far = 3000.0
			main.add_child(cam)
			var rp: PackedVector2Array = M.railway()
			var w3 := func(px: Vector2, up: float) -> Vector3:
				var q := M.w2(px)
				return Vector3(q.x, Terrain.h(q.x, q.y) + up, q.y)
			var views := [["_asema", w3.call(Vector2(80, 470), 60.0), w3.call(Vector2(80, 505), 0.0)],
				["_kaarre", w3.call(Vector2(120, 540), 40.0), w3.call(Vector2(180, 420), 0.0)],
				["_pohjoinen", w3.call(Vector2(230, 330), 50.0), w3.call(Vector2(200, 200), 0.0)],
				["_lansi", w3.call(Vector2(20, 520), 5.0), w3.call(Vector2(-200, 504), 2.0)],
				["_koillinen", w3.call(Vector2(170, 60), 8.0), w3.call(Vector2(220, -120), 2.0)]]
			for vw in views:
				cam.look_at_from_position(vw[1], vw[2])
				cam.current = true
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", vw[0] + ".png"))
			# Aikataulun juna: odota asemalla (kello hyppää), juna tulee laiturille ja seisoo; kuva laiturilta.
			Engine.time_scale = 4.0
			var tr: Node3D = main.world.train
			main.walker_out.global_position = main.world.station_pos + Vector3(0, 0.5, 0)
			for i in 5:
				await main.get_tree().process_frame
			print("RATA vihje ennen: '%s'" % main._hint.text)
			main._station_use("saloinen", "raahe")
			var t0 := Time.get_ticks_msec()
			while not tr.at_station() and Time.get_ticks_msec() - t0 < 30000:
				await main.get_tree().process_frame
			Engine.time_scale = 1.0
			print("RATA juna laiturilla %s %.1f s, vihje '%s'" % [tr.at_station(), (Time.get_ticks_msec() - t0) / 1000.0, main._hint.text])
			cam.look_at_from_position(w3.call(Vector2(30, 520), 6.0), w3.call(Vector2(90, 504), 2.0))
			cam.current = true
			for i in 10:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_juna.png"))
			print("RATA %d pistettä, %.0f m" % [rp.size(), rp[0].distance_to(rp[rp.size() - 1])])
			main.get_tree().quit()
		"rintamus":
			# Meteorologin (tai --sinikka: Sinikan) vartalo sivulta: rintamus 0 ja säädetty arvo rinnakkain.
			var NewsScreen := load("res://scripts/news_screen.gd")
			var stage := Node3D.new()
			main.add_child(stage)
			stage.global_position = Vector3(5000, 0, 5000)
			var lamp := DirectionalLight3D.new()
			lamp.rotation_degrees = Vector3(-35, 30, 0)
			stage.add_child(lamp)
			var who := "sinikka" if "--sinikka" in OS.get_cmdline_user_args() else "meteorologi"
			for i in 2:
				var look: Dictionary = (Looks.SINIKKA if who == "sinikka" else NewsScreen.METEOROLOGI).duplicate()
				if i == 0:
					look["bust"] = 0.0
				var c: Node3D = Looks.make(stage, look)
				c.position = Vector3(-0.6 + i * 1.2, 0, 0)
				c.rotation.y = PI * 0.5  # sivuttain kameraan
				c.play("Idle", 0.0)
			var cam := Camera3D.new()
			cam.fov = 35.0
			stage.add_child(cam)
			cam.look_at_from_position(stage.global_position + Vector3(0, 1.3, 3.2), stage.global_position + Vector3(0, 1.2, 0))
			cam.current = true
			main._hud.visible = false
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path)
			# Lähikuvat rintojen muodosta (poimut): kumpikin hahmo sivulta ja vinosti edestä alhaalta.
			var nodes: Array = stage.get_children().filter(func(n): return n.has_method("play"))
			for i in nodes.size():
				var c: Node3D = nodes[i]
				var at: Vector3 = c.global_position + Vector3(0, 1.22, 0)
				for k in [["sivu", Vector3(0, 0.0, 0.75)], ["ala", Vector3(-0.45, -0.25, 0.4)]]:
					cam.fov = 30.0
					c.rotation.y = PI * 0.5 if k[0] == "sivu" else PI
					cam.look_at_from_position(at + k[1], at, Vector3.UP)
					for f in 6:
						await main.get_tree().process_frame
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%d_%s.png" % [i, k[0]]))
		"raate":
			# Raatteen Portti (#250 P20): taksivalinta, kolme kohtaa, palkinto kerran; kuva.
			main._note.visible = false
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.raate = RaateLegenda.new()
			print("RA taksivalinta: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "retki_raate").map(func(o): return [o.id, o.enabled, o.text])])
			main._retki_from = main.player.global_position
			main._enter_retki("raate")
			print("RA perillä: state %s, tehtävät %s" % [main.state, main._raate_tasks()])
			var ra_m0 := main.mielihyva
			main._raate_acted("vierailija")
			main._raate_acted("portti")
			print("RA 2/3: tehtävät %s, kupla '%s'" % [main._raate_tasks(), main.retki_int._bubble.text])
			main._raate_acted("kivi")
			main._raate_acted("kivi")
			print("RA valmis: %s, mielihyvä %.1f -> %.1f, tehtävät %s" % [main.raate.valmis, ra_m0, main.mielihyva, main._raate_tasks()])
			for i in 4:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_alue.png"))
			main.get_tree().quit()
		"pyhakoski":
			# Pyhäkoski (#250 P16): taksivalinta, kolme tarinaa, palkinto kerran; kuva.
			main._note.visible = false
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.pyhakoski = PyhakoskiLegenda.new()
			print("PY taksivalinta: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "retki_pyhakoski").map(func(o): return [o.id, o.enabled, o.text])])
			main._retki_from = main.player.global_position
			main._enter_retki("pyhakoski")
			print("PY perillä: state %s, tehtävät %s" % [main.state, main._pyhakoski_tasks()])
			var py_m0 := main.mielihyva
			main._pyhakoski_acted("vahtimestari")
			main._pyhakoski_acted("kioski")
			print("PY 2/3: tehtävät %s, kupla '%s'" % [main._pyhakoski_tasks(), main.retki_int._bubble.text])
			main._pyhakoski_acted("portaat")
			main._pyhakoski_acted("portaat")
			print("PY valmis: %s, mielihyvä %.1f -> %.1f, tehtävät %s" % [main.pyhakoski.valmis, py_m0, main.mielihyva, main._pyhakoski_tasks()])
			for i in 4:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_alue.png"))
			main.get_tree().quit()
		"reppukaytto":
			# Repusta klikkaus: pulla syödään, kalja juodaan, tooltip kertoo toiminnon. Sisällä kävelijä ei herää.
			main._toggle_mount()
			main.food["pulla"] = 2
			main.beers = 3
			main._inventory.toggle()
			for i in 5:
				await main.get_tree().process_frame
			var click := func(icon: String) -> void:
				for i in main._inventory._slots.size():
					var it = main._inventory._slot_item(i)
					if it != null and it.icon == icon:
						var ev := InputEventMouseMotion.new()
						main._inventory._hover = i
						var cl := InputEventMouseButton.new()
						cl.button_index = MOUSE_BUTTON_LEFT
						cl.pressed = true
						cl.position = main._inventory._slots[i].get_center()
						main._inventory._gui_input(cl)
						return
			await click.call("pulla")
			print("REPPUK pulla: %d, viesti '%s'" % [main.food.get("pulla", 0), main._msg.text])
			await click.call("kalja")
			print("REPPUK kalja: %d, viesti '%s', tauko %s, reppu auki %s" % [main.beers, main._msg.text, main.get_tree().paused, main._inventory.visible])
			for i in main._inventory._slots.size():
				var it = main._inventory._slot_item(i)
				if it != null and it.icon == "pulla":
					main._inventory._hover = i
			main._inventory.queue_redraw()
			for i in 3:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_tooltip.png"))
			main._inventory.toggle()
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			for i in 5:
				await main.get_tree().physics_frame
			main._enter_home("ovi")
			main._inventory.toggle()
			for i in 3:
				await main.get_tree().process_frame
			await click.call("pulla")
			main._inventory.toggle()
			print("REPPUK sisällä: ulkokävelijän ohjaus %s, tila %s" % [main.walker_out.controls_enabled, main.state])
		"reppu":
			# Reppu täynnä tavaraa Saloisissa (kuva _reppu), sitten mökille: HUD ilman pääpelin tehtäviä, pyörän
			# välimatka ja repun mökkinäkymä (kuva _reppu_mokki). Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(suffix: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", suffix))
			main.beers = 9
			main.has_sausage = true
			main.has_matches = true
			main.has_chocolate = true
			main.has_ball = true
			main.has_kanister = true
			main.has_mower_part = true
			main.bucket = {"puolukka": 3, "kantarelli": 2, "herkkutatti": 1, "mustikka": 2}
			main.food = {"pulla": 2, "piirakka": 1, "savukala": 3, "savuriista": 1, "karrella": 1}
			main.saalis = [{"type": "kala", "nom": "hauki"}, {"type": "kala", "nom": "ahven"}, {"type": "kala", "nom": "ahven"},
				{"type": "riista", "nom": "jänis"}, {"type": "riista", "nom": "metso"}, {"type": "riista", "nom": "riekko"},
				{"type": "riista", "nom": "kyyhky"}]
			main.kota_polkyt = 2
			main.kota_halot = 5
			main.paivi_bag = {main.shopping_list[0][0]: "vihreä", main.shopping_list[1][0]: "punainen"}
			await main.get_tree().process_frame
			print("REPPU HUD saloinen: ", main._stats.text.replace("\n", " | "))
			main._inventory.toggle()
			for i in 5:
				await main.get_tree().process_frame
			main._inventory._hover = 0
			main._inventory.queue_redraw()
			await snap.call("_reppu.png")
			main._inventory._hover = main._inventory.SLOTS - 1
			Input.warp_mouse(main._inventory._slots[main._inventory.SLOTS - 1].get_center())
			for i in 3:
				await main.get_tree().process_frame
			main._inventory._hover = main._inventory.SLOTS - 1
			main._inventory.queue_redraw()
			await snap.call("_reppu_pohja.png")
			main._inventory.toggle()
			await main.get_tree().process_frame
			main._toggle_mount()
			for i in 10:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("REPPU HUD mökki: ", main._stats.text.replace("\n", " | "), " status=", main._status.text,
				" hazards=", main._hazards.process_mode)
			Input.action_press("mount")
			await main.get_tree().process_frame
			Input.action_release("mount")
			await main.get_tree().process_frame
			print("REPPU pyörä: ", main._msg.text)
			var e0 := main.clock_min
			for i in 30:
				await main.get_tree().process_frame
			print("REPPU aika mökillä %.2f -> %.2f" % [e0, main.clock_min])
			main._inventory.toggle()
			for i in 5:
				await main.get_tree().process_frame
			await snap.call("_reppu_mokki.png")
			main._inventory.toggle()
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"raahepaivi":
			# Päivi Raahen baarissa: 1) pelaaja jää tiskille -> kiinni ja taksi kotiin; --pako: pelaaja Kellariin,
			# Päivi seuraa portaiden kautta, pelaaja ylös ja ulos ennen kiinnijäämistä.
			main._toggle_mount()
			main.state = "cutscene"
			main._enter_raahe()
			main._raahe.paivi_t = 0.5
			var pako := OS.get_cmdline_user_args().has("--pako")
			main.raahe_int.walker.position = main.raahe_int.spots.tiski[0]
			await main.get_tree().create_timer(1.2).timeout
			print("PAIVI tuli=%s paikalla=%s tila=%s" % [main._raahe.get("paivi_came", false), main.raahe_int.paivi_here, main.raahe_int._paivi_mode])
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kulma.png"))
			if pako:
				main.raahe_int.walker.position = main.raahe_int.spots.ylos[0] + Vector3(-3.0, 0, -2.0)
				await main.get_tree().create_timer(6.0).timeout
				print("PAIVI 6 s: tila=%s kellarissa=%s" % [main.raahe_int._paivi_mode, main.raahe_int._cellar_of(main.raahe_int._paivi.position)])
				print("PAIVI kellarissa: päivi kellarissa=%s näkyy=%s" % [main.raahe_int._cellar_of(main.raahe_int._paivi.position), main.raahe_int._paivi.visible])
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kellari.png"))
				main.raahe_int.walker.position = main.raahe_int.spots.ovi[0]
				for w in 3:
					await main.get_tree().process_frame
				main.raahe_int._on_test_exit()
			for i in 40:
				await main.get_tree().create_timer(0.5).timeout
				if main.state != "in_raahe":
					break
			print("PAIVI loppu: state=%s kiinni=%s tila=%s msg=%s" % [main.state, main._raahe.caught, main.raahe_int._paivi_mode, main._msg.text])
		"purema":
			# Vieras koira: murina, purema, ontuminen, hoito Pekalla ja Päivillä. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main._toggle_mount()
			var sp: Vector3 = main.stray.global_position
			main.walker_out.global_position = sp + Vector3(8.0, 0.5, 0)
			main.walker_out.look_at(Vector3(sp.x, main.walker_out.global_position.y, sp.z))
			for i in 30:
				await main.get_tree().physics_frame
			var sc := Camera3D.new()
			main.add_child(sc)
			sc.global_position = main.stray.global_position + Vector3(2.5, 1.4, 2.5)
			sc.look_at(main.stray.global_position + Vector3(0, 0.4, 0), Vector3.UP)
			sc.current = true
			for i in 3:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_dog.png"))
			sc.queue_free()
			main.walker_out.activate_camera()
			print("PUREMA growl msg=", main._msg.text.replace("\n", " | "))
			Input.action_press("forward")
			for i in 600:
				await main.get_tree().physics_frame
				if main.bitten:
					break
			Input.action_release("forward")
			print("PUREMA bitten=%s hurt=%s status=%s msg=%s" % [main.bitten, main.walker_out.hurt, main._status.text, main._msg.text.replace("\n", " | ")])
			for i in 120:
				await main.get_tree().physics_frame
			main.walker_out.global_position = main.pekka.global_position + Vector3(2.0, 0.5, 0)
			main.beers = 0
			for i in 20:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("PUREMA pekka hint=", main._hint.text)
			var m0 := main.money
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			print("PUREMA pekka healed=%s money %s -> %s msg=%s" % [not main.bitten, main._eur(m0), main._eur(main.money), main._msg.text.replace("\n", " | ")])
			main._on_bitten(Vector3.FORWARD)
			for i in 120:
				await main.get_tree().physics_frame
			main.walker_out.global_position = main.home_zone + Vector3(0, 0.5, 2.0)
			for i in 20:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("PUREMA home hint=", main._hint.text)
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			print("PUREMA paivi healed=%s hurt=%s msg=%s" % [not main.bitten, main.walker_out.hurt, main._msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"rankkarit_kuvat":
			# Rankkarit kentällä: laukauksen tähtäys, voimapalkki, lento, maali verkkoon, yli, torjunnan minäkuva ja
			# heittäytyminen ylä- ja alakulmaan. Kuvat --shot-polun viereen.
			var rshot := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			var rwait := func(sec: float) -> void:
				await main.get_tree().create_timer(sec).timeout
			if main.player != main.walker_out:
				main._toggle_mount()
			main.walker_out.global_position = main.world.kentta_spot + Vector3(0, 0.5, 0)
			await rwait.call(0.5)
			main._boys_field = "saloinen"
			main._start_rankku("saloinen")
			var g: Node = main._rankku
			await rwait.call(2.2)
			print("RK verkkoja löytyi %d" % g._nets.size())
			g._t = 0.4
			await rwait.call(0.3)
			await rshot.call("tahtays")
			g._phase = "aim_y"
			g._t = 1.2
			g._aim.x = 0.7
			await rwait.call(0.4)
			g._phase = "power"
			g._t = 0.55
			await rwait.call(0.1)
			await rshot.call("voima")
			g._aim = Vector2(0.7, 0.4)
			g._power = 0.7
			g._kick()
			g._keeper_dive = -1
			await rwait.call(0.3)
			await rshot.call("vauhti")
			await rwait.call(0.2)
			await rshot.call("lento")
			while g._phase in ["strike", "flight"]:
				await main.get_tree().process_frame
			await rwait.call(0.15)
			print("RK laukaus 1: maali %s, '%s'" % [g._goal, g._tip.text])
			await rshot.call("maali")
			# Toinen laukaus: liian kova yläkulmaan.
			g._round = 2
			g._start_round()
			await rwait.call(0.3)
			g._aim = Vector2(-0.6, 0.85)
			g._power = 0.97
			g._kick()
			while g._phase in ["strike", "flight"]:
				await main.get_tree().process_frame
			print("RK laukaus 2: yli %s, maali %s, '%s'" % [g._over, g._goal, g._tip.text])
			await rwait.call(0.3)
			await rshot.call("yli")
			# Torjunta: minäkuva, potkija juoksee.
			g._round = 1
			g._start_round()
			g._kick_dir = 1
			g._kick_high = true
			await rwait.call(1.4)
			await rshot.call("torjunta")
			while g._phase == "runup":
				await main.get_tree().process_frame
			g._keeper_dive = 1
			g._keeper_high = true
			g._keeper_u = 0.0
			await rwait.call(0.25)
			await rshot.call("heittaytyy_yla")
			while g._phase == "dive":
				await main.get_tree().process_frame
			print("RK torjunta ylä: '%s'" % g._tip.text)
			g._round = 3
			g._start_round()
			g._kick_dir = -1
			g._kick_high = false
			while g._phase == "runup":
				await main.get_tree().process_frame
			g._keeper_dive = -1
			g._keeper_high = true
			g._keeper_u = 0.0
			await rwait.call(0.25)
			await rshot.call("heittaytyy_vaara")
			while g._phase == "dive":
				await main.get_tree().process_frame
			await rwait.call(0.1)
			print("RK torjunta väärä korkeus: '%s'" % g._tip.text)
			await rshot.call("maali_omaan")
			main.get_tree().quit()
			return 2
		_:
			return 0
	return 1
