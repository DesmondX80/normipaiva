extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "muut_a_k". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const B := preload("res://scripts/build.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const StationInterior := preload("res://scripts/station_interior.gd")
const Looks := preload("res://scripts/looks.gd")
const HomeInterior := preload("res://scripts/home_interior.gd")
const EBike := preload("res://scripts/ebike.gd")
const OmaMopo := preload("res://scripts/oma_mopo.gd")
const Aarnivalkea := preload("res://scripts/aarnivalkea.gd")
const HanhikiviLegenda := preload("res://scripts/hanhikivi_legenda.gd")
const HiidenporttiLegenda := preload("res://scripts/hiidenportti_legenda.gd")
const MesseniusLegenda := preload("res://scripts/messenius_legenda.gd")
const KalajokiLegenda := preload("res://scripts/kalajoki_legenda.gd")
const RantapalloGame := preload("res://scripts/rantapallo_game.gd")
const RotkoGame := preload("res://scripts/rotko_game.gd")
const Endings := preload("res://scripts/endings.gd")
const Quests := preload("res://scripts/quests.gd")

const KOHTAUKSET := ["hahmoeditori", "asennot", "juntti", "fight", "fight_ohjeet", "field", "bog", "asut", "asema", "bikini", "hupihommat", "kainuulista", "hanhikivi", "kajaani", "kalajoki", "hiidenportti", "drakkar", "haalari", "bikini_video", "eramaa", "junttikierto", "jemmat", "honganpalo", "honganpalo_maasto", "ideat", "hiirisisalla", "juhlat", "chocotest", "fightfx", "infoboard", "guardleave", "hedgeclose", "homeview", "homeview2", "garage", "grilli", "aloitusruutu", "found", "aidat", "hiirinapit", "hiiriohjaus", "humala_ohjaus", "heitto", "jemma_ovi"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"hahmoeditori":
			# Hahmoeditori pelin alussa: tools/testit/hahmoeditori.gd (rajaus, jokainen vaihtoehto, peruminen, tallennus).
			var he_node: Node = load("res://tools/testit/hahmoeditori.gd").new()
			he_node.main = main
			main.add_child(he_node)
			await he_node.run(path)
		"asennot":
			# Asentojen ja kalusteiden tarkistus: --asento=<osa> ajaa tools/testit/asennot_<osa>.gd:n run():n.
			var osa := "0"
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--asento="):
					osa = arg.substr(9)
			var saved_as := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			var as_node: Node = load("res://tools/testit/asennot_%s.gd" % osa).new()
			as_node.main = main
			main.add_child(as_node)
			await as_node.run()
			if not saved_as.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_as)
			main.get_tree().quit()
			return 2
		"juntti":
			main.player.position = main.juntti.position + Vector3(0, 0.3, 10)
		"fight":
			main.beers = 6
			main._on_kicked(Vector3.RIGHT)
			for i in 130:
				await main.get_tree().process_frame
		"fight_ohjeet":
			# Tappelun alun ohjetauko: paneeli näkyy, tappelu ei ala itsestään, lyöntinappi aloittaa (ROUND 1, FIGHT!).
			main.fight.get_script().ohjeet_testissa = true
			main.beers = 6
			main._on_kicked(Vector3.RIGHT)
			for i in 90:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_ohjeet.png"))
			print("FIGHT ohjeet: vaihe '%s' 1,5 s jälkeen, aika %.1f" % [main.fight._phase, main.fight._time])
			# Asetuksissa liikkuminen nuolinäppäimiin: paneeli näyttää valitut näppäimet (nuolina), sitten takaisin.
			var keys0: Dictionary = (Settings.values.keys as Dictionary).duplicate(true)
			for ak in [["forward", KEY_UP], ["back", KEY_DOWN], ["left", KEY_LEFT], ["right", KEY_RIGHT]]:
				Settings.values.keys[ak[0]] = [ak[1], 0, 0]
			var teksti: String = main.fight._ohje_teksti()
			print("FIGHT ohjeet nuolilla: %s" % teksti.replace("\n", " / "))
			if not "↑" in teksti:
				print("TESTI VIKA ohjepaneeli ei käytä asetusten näppäimiä")
			main.fight._ohje.set_text(teksti)
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_ohjeet_nuolet.png"))
			Settings.values.keys = keys0
			main.fight._ohje.set_text(main.fight._ohje_teksti())
			if main.fight._phase != "ohjeet":
				print("TESTI VIKA tappelu alkoi ilman lyöntinappia (vaihe %s)" % main.fight._phase)
			var ev := InputEventAction.new()
			ev.action = "punch"
			ev.pressed = true
			Input.parse_input_event(ev)
			for i in 3:
				await main.get_tree().process_frame
			var up := InputEventAction.new()
			up.action = "punch"
			Input.parse_input_event(up)
			print("FIGHT lyöntinapin jälkeen: vaihe '%s'" % main.fight._phase)
			if main.fight._phase != "intro":
				print("TESTI VIKA lyöntinappi ei aloittanut tappelua (vaihe %s)" % main.fight._phase)
			var t0 := Time.get_ticks_msec()
			while main.fight._phase != "fight" and Time.get_ticks_msec() - t0 < 5000:
				await main.get_tree().process_frame
			print("FIGHT alkoi: vaihe '%s'" % main.fight._phase)
			if main.fight._phase != "fight":
				print("TESTI VIKA tappelu ei alkanut ROUND 1:n jälkeen")
			main.fight.get_script().ohjeet_testissa = false
		"field", "bog":
			var M2 := preload("res://scripts/map_data.gd")
			main.player.position = M2.w(Vector2(450, 730) if scene == "field" else Vector2(400, 1110)) + Vector3(0, 0.3, 0)
			main.player.speed = 9.0
		"asut":
			# Pelaajan asut rinnakkain kodin pihalla: edestä, takaa ja päät lähikuvina (--asu-kohta=etu|taka|paa).
			main._note.visible = false
			main._hud.visible = false
			var stage := Node3D.new()
			main.add_child(stage)
			var base := main.home_zone + Vector3(6, 0, 10)
			base.y = Terrain.h(base.x, base.z)
			stage.position = base
			var cs: Array = []
			var ids := ["tuulipuku", "farkut", "tyovaatteet", "hiihtohaalari"]
			for k in ids.size():
				var ch: Node3D = Looks.make(stage, Looks.player(ids[k]))
				Looks.add_cap(ch)
				ch.position = Vector3((k - 1.5) * 1.1, 0, 0)
				ch.play("Idle", 0.0)
				cs.append(ch)
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.current = true
			main.player.visible = false
			var shoot := func(name: String, from: Vector3, to: Vector3, fov: float) -> void:
				cam.fov = fov
				cam.look_at_from_position(stage.to_global(from), stage.to_global(to))
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			await shoot.call("_etu.png", Vector3(0, 1.2, -5.0), Vector3(0, 1.0, 0), 45.0)
			await shoot.call("_taka.png", Vector3(0, 1.3, 5.0), Vector3(0, 1.0, 0), 45.0)
			for k in ids.size():
				var hx := (k - 1.5) * 1.1
				await shoot.call("_paa%d.png" % k, Vector3(hx + 0.25, 1.72, -0.75), Vector3(hx, 1.62, 0), 30.0)
				await shoot.call("_paataka%d.png" % k, Vector3(hx - 0.35, 1.75, 0.8), Vector3(hx, 1.55, 0), 30.0)
			# Asun vaihto paikallaan: tuulipukuhahmo farkkuihin.
			Looks.outfit = "farkut"
			Looks.restyle_player(cs[0])
			await shoot.call("_vaihto.png", Vector3(-1.65, 1.2, -2.6), Vector3(-1.65, 1.0, 0), 45.0)
			Looks.outfit = "tuulipuku"
			main.get_tree().quit()
		"asema":
			# Asemat: Saloisten asema ulkoa (katu ja laituri), odotussali, hörppy juopolle -> kätkö kartalle, kätkön
			# tyhjennys, laiturille ja junan vihje; sama Vaalassa. Tallennus palautetaan lopuksi.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var view := [null, null]  # kameran paikka ja kohde (null = pelin oma kamera)
			var snap := func(name: String) -> void:
				for i in 12:
					if view[0] != null:
						main.get_viewport().get_camera_3d().look_at_from_position(view[0], view[1])
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
				view[0] = null
			if main.player != main.walker_out:
				main._toggle_mount()
			main._msg.text = ""
			main._note.visible = false
			main.asema_katkot = {}
			main.beers = 2
			main.viina_pullot = 1
			main.money = 20.0
			var sp: Vector3 = main.world.station_pos
			var look := func(from: Vector3, to: Vector3) -> void:
				view[0] = from
				view[1] = to
			main.walker_out.global_position = Vector3(sp.x, Terrain.h(sp.x, sp.z) + 0.4, sp.z + 1.0)
			look.call(sp + Vector3(-9, 4.5, 15), sp + Vector3(1, 2.5, -4))
			await snap.call("_katu.png")
			look.call(sp + Vector3(16, 9, 10), sp + Vector3(1, 3, -4))
			await snap.call("_katto.png")
			var pd: Vector3 = main.world.station_plat_door
			look.call(pd + Vector3(12, 3.5, -10), pd + Vector3(-2, 2, 2))
			await snap.call("_laituri.png")
			main.walker_out.activate_camera()
			for i in 10:
				await main.get_tree().process_frame
			print("ASEMA ovella vihje '%s'" % main._hint.text)
			main._enter_asema("saloinen")
			await snap.call("_sali.png")
			main.asema_int.walker.position = StationInterior.PEOPLE[0].at + Vector3(0.8, 0, 1.0)
			for i in 5:
				await main.get_tree().process_frame
			print("ASEMA salissa vihje '%s', tila %s" % [main._hint.text, main.state])
			main._on_asema_acted("hlo0")
			print("ASEMA valikko auki %s" % main._item_menu.is_open())
			await snap.call("_valikko.png")
			main._item_menu.visible = false
			main._item_menu.chosen.emit("kalja")
			await snap.call("_kerto.png")
			print("ASEMA kätkö %s, kaljat %d, viesti '%s', merkit %s, kätkö %s, asemalta %.0f m" % [main.asema_katkot, main.beers, main._msg.text,
				main.cache_markers(), main.world.cache_pos, Vector2(main.world.cache_pos.x - sp.x, main.world.cache_pos.z - sp.z).length()])
			main._paper.toggle()
			await snap.call("_kartta.png")
			main._paper.toggle()
			main._on_asema_exited("laituri")
			for i in 10:
				await main.get_tree().process_frame
			print("ASEMA laiturilla vihje '%s', paikka %s, tila %s" % [main._hint.text, main.player.global_position, main.state])
			var cp: Vector3 = main.world.cache_pos
			main.walker_out.global_position = cp + Vector3(0, 0.5, 1.9)
			main.walker_out.rotation.y = 0.0
			for i in 10:
				await main.get_tree().process_frame
			print("ASEMA kätköllä vihje '%s', maa %.2f, kätkö y %.2f" % [main._hint.text, Terrain.h(cp.x, cp.z), cp.y])
			look.call(cp + Vector3(5, 3, 5), cp)
			await snap.call("_katko.png")
			main._take_cache("saloinen")
			print("ASEMA kätkö tyhjennetty: rahaa %.2f, tila %s" % [main.money, main.asema_katkot])
			# Vaala: asema ulkoa, odotussali, hörppy, kätkö ja laituri.
			main.mokki.ensure_built()
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var sd: Vector3 = main.mopo_trip.to_global(vl.station_door)
			var sb: Vector3 = main.mopo_trip.to_global(vl.station_back)
			var outv := (sd - sb).normalized()
			look.call(sd + outv * 16.0 + outv.cross(Vector3.UP) * 8.0 + Vector3(0, 5, 0), sd - outv * 4.0 + Vector3(0, 2, 0))
			await snap.call("_vaala_katu.png")
			look.call(sb - outv * 14.0 + outv.cross(Vector3.UP) * 10.0 + Vector3(0, 4, 0), sb + Vector3(0, 2, 0))
			await snap.call("_vaala_laituri.png")
			main._on_vaala_door("asema")
			await snap.call("_vaala_sali.png")
			main._on_asema_acted("hlo2")
			main._item_menu.visible = false
			main._item_menu.chosen.emit("viina")
			print("VAALA kätkö %s, viesti '%s', merkit %s" % [main.asema_katkot, main._msg.text, main.cache_markers()])
			main._on_asema_exited("laituri")
			for i in 15:
				await main.get_tree().process_frame
			print("VAALA laiturilla vihje '%s' (%s), jalan %s, laiturilta %.1f m" % [main.mopo_trip.hint, main._hint.text, main.mopo_trip.on_foot != null,
				main.player.global_position.distance_to(main.mopo_trip.to_global(vl.station_board))])
			await snap.call("_vaala_laituri_jalan.png")
			var vc: Vector3 = main._cache_pos("vaala")
			main.walker_out.global_position = vc + Vector3(1.0, 0.5, 0)
			for i in 15:
				await main.get_tree().process_frame
			print("VAALA kätköllä vihje '%s', asemalta %.0f m" % [main.mopo_trip.hint, vc.distance_to(sb)])
			look.call(vc + Vector3(5, 3, 5), vc)
			await snap.call("_vaala_katko.png")
			main._paper.toggle()
			await snap.call("_vaala_kartta.png")
			main._paper.toggle()
			main._on_vaala_door("katko")
			print("VAALA kätkö tyhjennetty: rahaa %.2f, tila %s" % [main.money, main.asema_katkot])
			var f := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f.store_buffer(saved)
			f.close()
			main.get_tree().quit()
		"bikini":
			# Sinikan lappubikinit edestä, sivulta ja takaa.
			var stage := Node3D.new()
			main.add_child(stage)
			stage.global_position = Vector3(5000, 0, 5000)
			var lamp := DirectionalLight3D.new()
			lamp.rotation_degrees = Vector3(-35, 20, 0)
			stage.add_child(lamp)
			for i in 3:
				var blook := Looks.sinikka_bikini()
				for kv in OS.get_cmdline_user_args():
					if kv.begins_with("--bust="):
						blook["bust"] = float(kv.substr(7))
				var c: Node3D = Looks.make(stage, blook)
				c.position = Vector3(-0.9 + i * 0.9, 0, 0)
				c.rotation.y = [PI, PI * 0.5, 0.0][i]  # edestä, sivulta, takaa
				var anim := "Idle"
				for kv in OS.get_cmdline_user_args():
					if kv.begins_with("--anim="):
						anim = kv.substr(7)
				if "--lepo" in OS.get_cmdline_user_args():  # lepoasento ilman animaatiota (muotoilu ilman luuston liikettä)
					c.skeleton.reset_bone_poses()
				else:
					c.play(anim, 0.0)
				if i == 0 and "--karki" in OS.get_cmdline_user_args():  # rinnan kärki: muotoillun verkon uloin piste (z)
					var bm: MeshInstance3D = null
					for mi in c.skeleton.get_children():
						if mi is MeshInstance3D and (bm == null or mi.mesh.surface_get_array_len(0) > bm.mesh.surface_get_array_len(0)):
							bm = mi
					var arrs: Array = bm.mesh.surface_get_arrays(0)
					var sv: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
					var ru: PackedVector2Array = arrs[Mesh.ARRAY_TEX_UV2]
					for side in [-1.0, 1.0]:
						var best := -1
						for k in sv.size():
							if sv[k].x * side > 0.02 and sv[k].y > 1.15 and sv[k].y < 1.5 and (best < 0 or sv[k].z > sv[best].z):
								best = k
						print("KARKI puoli %d: muotoiltu %s lepo %s" % [side, sv[best], ru[best]])
				if i == 0 and "--mittaa" in OS.get_cmdline_user_args():
					var body: MeshInstance3D = null
					for mi in c.skeleton.get_children():
						if mi is MeshInstance3D and (body == null or mi.mesh.surface_get_array_len(0) > body.mesh.surface_get_array_len(0)):
							body = mi
					var verts: PackedVector3Array = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					for y in [0.85, 0.9, 0.95, 1.1, 1.3]:
						var lo := 9.0
						var hi := -9.0
						var bz := 9.0
						var bx := 0.0
						for v in verts:
							if absf(v.y - y) < 0.006 and absf(v.x) < 0.25:
								lo = minf(lo, v.x)
								hi = maxf(hi, v.x)
								if v.z < bz and absf(v.x) < 0.05:
									bz = v.z
									bx = v.x
						print("KESKI y %.2f: x %.4f..%.4f keski %.4f, takimmainen piste x %.4f" % [y, lo, hi, (lo + hi) / 2.0, bx])
			var cam := Camera3D.new()
			cam.fov = 40.0
			stage.add_child(cam)
			cam.look_at_from_position(stage.global_position + Vector3(0, 1.1, 3.6), stage.global_position + Vector3(0, 1.05, 0))
			cam.current = true
			main._hud.visible = false
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_bikini.png"))
			# Lähikuvat alaosasta: edestä, sivulta ja takaa.
			for k in [["ala_edesta", Vector3(-0.9, 0.95, 1.1), Vector3(-0.9, 0.92, 0)], ["ala_sivulta", Vector3(0.0, 0.95, 1.1), Vector3(0.0, 0.92, 0)],
					["ala_takaa", Vector3(0.9, 0.95, 1.1), Vector3(0.9, 0.92, 0)], ["vako", Vector3(0.9, 0.9, 0.6), Vector3(0.9, 0.88, 0)],
					["haara", Vector3(-0.9, 0.93, 0.6), Vector3(-0.9, 0.9, 0)], ["yla_edesta", Vector3(-0.9, 1.2, 0.75), Vector3(-0.9, 1.17, 0)],
					["yla_vino", Vector3(-0.45, 1.22, 0.6), Vector3(-0.9, 1.17, 0)], ["yla_sivulta", Vector3(-0.35, 1.2, 0.0), Vector3(0.0, 1.17, 0)]]:
				cam.fov = 30.0
				cam.look_at_from_position(stage.global_position + k[1], stage.global_position + k[2])
				for i in 5:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % k[0]))
		"hupihommat":
			# Vaalan nuorison hupihommat (#183): mopon viritys autotallissa, pullonkeräys lavan pihalta ja kioskilla hengailu.
			# Aja eristetyllä HOME:lla (tallennus).
			main.money = 100.0
			main.oma_mopo.owned = true
			main.oma_mopo.running = false
			print("HU viritysvihje ei käynnissä: '%s'" % main._mopo_virit_hint())
			main.oma_mopo.running = true
			main.oma_mopo.rajoitin = false
			var b0: float = main.oma_mopo.max_speed()
			print("HU huippu ilman viritystä: %.1f, vihje '%s'" % [b0, main._mopo_virit_hint()])
			for id in ["sylinteri", "pakoputki", "rattaat"]:
				main._on_virit_menu(id)
				print("HU %s: rahaa %s, huippu %.1f, osia %d" % [id, main._eur(main.money), main.oma_mopo.max_speed(), main.oma_mopo.virit.size()])
			print("HU viritetty täysin, vihje '%s'" % main._mopo_virit_hint())
			print("HU rajoittimella huippu: %.1f" % [OmaMopo.MAX_LIMITED + main.oma_mopo.virit_bonus()])
			# Pullonkeräys
			main.day = 3
			main.clock_min = 8 * 60
			main._nuoret_yard = true
			var m1 := main.money
			print("HU nuoret aamulla: %s" % [main._talk_options("nuoret").map(func(o): return "%s:%s" % [o.id, o.enabled])])
			main._talk_who = "nuoret"
			main._pullonkeraus()
			print("HU pullot: rahaa %s -> %s, kello %d, uudestaan mahdollinen %s" % [main._eur(m1), main._eur(main.money), int(main.clock_min), main._talk_options("nuoret").filter(func(o): return o.id == "pullot").map(func(o): return o.enabled)])
			main.clock_min = 15 * 60
			print("HU nuoret iltapäivällä: pullot-valinta %s" % [main._talk_options("nuoret").any(func(o): return o.id == "pullot")])
			# Kioskilla hengailu
			main.clock_min = 13 * 60
			print("HU zabuki päivällä: %s" % [main._talk_options("zabuki").filter(func(o): return o.id == "hengaile").map(func(o): return "%s (%s)" % [o.enabled, o.reason])])
			main.clock_min = 20 * 60
			var mo0: float = main.mielihyva
			print("HU zabuki illalla: %s" % [main._talk_options("zabuki").filter(func(o): return o.id == "hengaile").map(func(o): return o.enabled)])
			main._talk_who = "zabuki"
			main._hengaile_kioskilla()
			print("HU hengailu: mielihyvä %.0f -> %.0f, kello %d, toistamiseen mahdollinen %s" % [mo0, main.mielihyva, int(main.clock_min), main._talk_options("zabuki").filter(func(o): return o.id == "hengaile").map(func(o): return o.enabled)])
			# Purukumit, kasetti, mopoletka ja kesäduuni
			main._talk_who = "nuoret"
			main.day = 5
			main.clock_min = 19 * 60
			main.money = 50.0
			print("HU nuoret illalla: %s" % [main._talk_options("nuoret").map(func(o): return "%s:%s" % [o.id, o.enabled])])
			var pm: float = main.maine
			main._nuoret_hupi("purkka")
			print("HU purkka: rahaa 50 -> %s, maine %.0f -> %.0f, uudestaan %s" % [main._eur(main.money), pm, main.maine, main._talk_options("nuoret").filter(func(o): return o.id == "purkka").map(func(o): return o.enabled)])
			main._nuoret_hupi("kasetti_aanita")
			print("HU kasetti äänitetty %s, rahaa %s, soita-valinta %s" % [main._kasetti, main._eur(main.money), main._talk_options("nuoret").any(func(o): return o.id == "kasetti_soita")])
			main._nuoret_hupi("kasetti_soita")
			print("HU kasetti soitettu päivä %d, toistamiseen mahdollinen %s" % [main._kasetti_day, main._talk_options("nuoret").filter(func(o): return o.id == "kasetti_soita").map(func(o): return o.enabled)])
			main.clock_min = 23 * 60 + 30
			main.oma_mopo.running = true
			main.oma_mopo.fuel = 0.8
			print("HU letka-valinta yöllä: %s" % [main._talk_options("nuoret").filter(func(o): return o.id == "letka").map(func(o): return o.enabled)])
			var f0: float = main.oma_mopo.fuel
			main._nuoret_hupi("letka")
			print("HU letka: bensa %.2f -> %.2f, päivä %d" % [f0, main.oma_mopo.fuel, main._letka_day])
			main.day = 6
			main.clock_min = 9 * 60
			main._talk_who = "tyokkari"
			main.money = 10.0
			print("HU tyokkari: %s" % [main._talk_options("tyokkari").filter(func(o): return o.id == "kesaduuni").map(func(o): return o.enabled)])
			main._kesaduuni()
			print("HU kesäduuni: rahaa 10 -> %s, kello %d, uudestaan %s" % [main._eur(main.money), int(main.clock_min), main._talk_options("tyokkari").filter(func(o): return o.id == "kesaduuni").map(func(o): return o.enabled)])
			main.get_tree().quit()
		"kainuulista":
			# Gasthausin ruokalista (#16): valinnat, nälän nollaus, hinta ja ruokalistakyltti (kuva _lista).
			var ks := main._talk_options("gasthaus")
			print("KL valinnat: %s" % [ks.map(func(o): return o.id)])
			var k0: float = main.tilat.value("nalka")
			main.tilat.add("nalka", -0.7)
			main.money = 50.0
			main._talk_who = "gasthaus"
			for kid in Main.GASTHAUS_MENU:
				main.tilat.add("nalka", -0.5)
				var kn0: float = main.tilat.value("nalka")
				main._talk_choose("ruoka_" + kid)
				print("KL %s: nälkä %.2f -> %.2f, rahaa %s" % [kid, kn0, main.tilat.value("nalka"), main._eur(main.money)])
			main.money = 1.0
			print("KL köyhänä: %s" % [main._talk_options("gasthaus").filter(func(o): return o.id.begins_with("ruoka_")).map(func(o): return o.enabled)])
			print("KL alkunälkä %.2f" % k0)
			main.get_tree().quit()
		"hanhikivi":
			# Hanhikiven rajakivi (#250 P4): taksikuski kertoo, kapteeni ja kyltti vihjeinä, kivellä loppu; tallennus; kuvat Koskipuistosta.
			main._note.visible = false
			var hk_shot := func(name: String) -> void:
				for i in 3:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.hanhikivi = HanhikiviLegenda.new()
			print("HK taksivalinnat: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "hanhikivi_kerro" or o.id == "retki_hanhikivi").map(func(o): return [o.id, o.enabled, o.text])])
			print("HK tehtävät ennen: %s" % [main._hanhikivi_tasks()])
			main._talk_open("taksi", null, "Kyytiä?")
			main._talk_hanhikivi("hanhikivi_kerro")
			main._talk_box.close()
			print("HK kuultu %s, tehtävät %s, valinta pois %s" % [main.hanhikivi.heard, main._hanhikivi_tasks(), main._talk_options("taksi").filter(func(o): return o.id == "hanhikivi_kerro").is_empty()])
			print("HK päiväkirja: %s" % [main.quests.hint_for("taksi", main.tilat.firsts, main.quest_flag)])
			main._ensure_raahe()
			main.raahe_int.kapteeni_vihje = true
			main._on_raahe_acted("kapteeni")
			print("HK kapteeni %s, kapteenin vihje pois %s, tehtävät %s" % [main.hanhikivi.kapteeni, not main.raahe_int.kapteeni_vihje, main._hanhikivi_tasks()])
			var hk_t0 := main.clock_min
			main._retki_from = main.player.global_position
			main._enter_retki("hanhikivi")
			print("HK perillä: state %s, kello +%.0f min, rahaa %s" % [main.state, main.clock_min - hk_t0, main._eur(main.money)])
			await hk_shot.call("alue")
			main.retki_int.walker.position = main.retki_int.spots.kivi[0]
			main.retki_int.walker.rotation.y = B.yaw_to(Vector3(0, 0, -1))
			for i in 3:
				await main.get_tree().process_frame
			print("HK kivellä: spot '%s', vihje '%s'" % [main.retki_int.spot, main._hint.text])
			await hk_shot.call("kivi")
			main._on_retki_acted("kivi")
			print("HK kivi ilman kylttiä: found %s (pitää olla false)" % main.hanhikivi.found)
			main.retki_int.walker.position = main.retki_int.spots.kyltti[0]
			for i in 3:
				await main.get_tree().process_frame
			print("HK kyltillä: spot '%s'" % main.retki_int.spot)
			await hk_shot.call("kyltti")
			main._on_retki_acted("kyltti")
			print("HK kyltti %s, tehtävät %s" % [main.hanhikivi.kyltti, main._hanhikivi_tasks()])
			var hk_m0 := main.maine
			main._on_retki_acted("kivi")
			print("HK loppu: found %s, maine %.0f -> %.0f, loppu kirjattu %s, tehtävät %s" % [main.hanhikivi.found, hk_m0, main.maine, main.endings.counts.has("hanhikiven_rajakivi"), main._hanhikivi_tasks()])
			main._on_retki_acted("kivi")
			print("HK toistokerta: maine %.0f (ei kasva)" % main.maine)
			var hk_cfg := ConfigFile.new()
			main.hanhikivi.save_to(hk_cfg)
			var hk_l: RefCounted = HanhikiviLegenda.new()
			hk_l.load_from(hk_cfg)
			print("HK tallennus: heard %s kapteeni %s kyltti %s found %s" % [hk_l.heard, hk_l.kapteeni, hk_l.kyltti, hk_l.found])
			main.retki_int.walker.position = main.retki_int.spots.onkija[0]
			for i in 3:
				await main.get_tree().process_frame
			main.retki_int.say("Sanotaan, että joku siirsi sen.", 20.0)
			main.retki_int.walker.position = main.retki_int.spots.ovi[0] + Vector3(3, 0, -6)
			for i in 3:
				await main.get_tree().process_frame
			await hk_shot.call("onkija")
			main._on_retki_exited()
			await main.get_tree().create_timer(14.0).timeout
			print("HK takaisin: state %s, etäisyys lähtöpaikasta %.2f m, kello +%.0f min" % [main.state, main.player.global_position.distance_to(main._retki_from), fposmod(main.clock_min - hk_t0, 1440.0)])
			main.get_tree().quit()
		"kajaani":
			# Kajaanin linna ja Messenius (#250 P17-P18): taksivalinta, rauniot, tervavene, Messenius, palkinto kerran; kuva.
			main._note.visible = false
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.messenius = MesseniusLegenda.new()
			print("KA taksivalinta: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "retki_kajaani").map(func(o): return [o.id, o.enabled, o.text])])
			main._retki_from = main.player.global_position
			main._enter_retki("kajaani")
			print("KA perillä: state %s, tehtävät %s" % [main.state, main._messenius_tasks()])
			var ka_m0 := main.mielihyva
			main._messenius_acted("rauniot")
			main._messenius_acted("tervavene")
			print("KA 2/3: tehtävät %s, kupla '%s'" % [main._messenius_tasks(), main.retki_int._bubble.text])
			for i in 90:
				await main.get_tree().process_frame
			main._messenius_acted("messenius")
			main._messenius_acted("messenius")
			print("KA valmis: %s, mielihyvä %.1f -> %.1f, tehtävät %s" % [main.messenius.valmis, ka_m0, main.mielihyva, main._messenius_tasks()])
			for i in 4:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_alue.png"))
			main.get_tree().quit()
		"kalajoki":
			# Kalajoki (#250 P19): taksivalinta, järjestäjä, kyltti, rantapallo (juhannus perjantaina), palkinto kerran; kuvat.
			main._note.visible = false
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.day = 5  # perjantai = juhannusaatto
			main.clock_min = 12 * 60.0
			main.kalajoki = KalajokiLegenda.new()
			print("KJ taksivalinta: %s, juhannus %s" % [main._talk_options("taksi").filter(func(o): return o.id == "retki_kalajoki").map(func(o): return [o.id, o.enabled, o.text]), main._juhannus()])
			main._retki_from = main.player.global_position
			main._enter_retki("kalajoki")
			print("KJ perillä: state %s, tehtävät %s" % [main.state, main._kalajoki_tasks()])
			main._kalajoki_acted("kyltti")
			main._kalajoki_acted("jarjestaja")
			print("KJ järjestäjä: tehtävät %s, kupla '%s'" % [main._kalajoki_tasks(), main.retki_int._bubble.text])
			for i in 4:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_alue.png"))
			var kj_m0 := main.mielihyva
			main._kalajoki_acted("kentta")
			var kj_g: Node = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == RantapalloGame)[0]
			print("KJ peli auki: state %s" % main.state)
			for i in 100:
				await main.get_tree().process_frame
			for i in 140:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_peli.png"))
			print("KJ pelitila: %s, pallo %s, tulos %s" % [kj_g._phase, kj_g._ball, kj_g._score])
			kj_g._score = [3, 1]
			kj_g._phase = "over"
			kj_g._t = 1.0
			await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_loppu.png"))
			kj_g._end(true)
			await main.get_tree().process_frame
			print("KJ valmis: %s, voitot %d, mielihyvä %.1f -> %.1f, state %s, tehtävät %s" % [main.kalajoki.valmis, main.kalajoki.voitot, kj_m0, main.mielihyva, main.state, main._kalajoki_tasks()])
			main.get_tree().quit()
		"hiidenportti":
			# Hiidenportti (#250 P13): taksivalinta, retkeilijä, kyltti, kiipeily (otteet, putoaminen, ylälava), tallennus; kuvat.
			main._note.visible = false
			var hp_shot := func(name: String) -> void:
				for i in 4:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			if main.player == main.bike:
				main.bike.speed = 0.0
				main._toggle_mount()
			main.money = 80.0
			main.clock_min = 12 * 60.0
			main.hiidenportti = HiidenporttiLegenda.new()
			print("HP taksivalinta: %s" % [main._talk_options("taksi").filter(func(o): return o.id == "retki_hiidenportti").map(func(o): return [o.id, o.enabled, o.text])])
			main._retki_from = main.player.global_position
			main._enter_retki("hiidenportti")
			print("HP perillä: state %s, tehtävät %s" % [main.state, main._hiidenportti_tasks()])
			await hp_shot.call("alue")
			main._hiidenportti_acted("kyltti")
			main._hiidenportti_acted("opas")
			print("HP kyltti: luettu %s, kupla '%s', tehtävät %s" % [main.hiidenportti.kyltti, main.retki_int._bubble.text, main._hiidenportti_tasks()])
			main._start_hiidenportti()
			var hp_g: Node = main.get_children().filter(func(c: Node) -> bool: return c.get_script() == RotkoGame)[0]
			print("HP minipeli auki %s, state %s" % [main._minigame_open(), main.state])
			hp_g._grab(hp_g._screen(hp_g._holds[1].p))
			hp_g._grab(hp_g._screen(hp_g._holds[2].p))
			await main.get_tree().create_timer(0.6).timeout
			await hp_shot.call("peli")
			hp_g._fall("Testi.")
			print("HP putosi: ote %d (lava), putoamisia %d" % [hp_g._cur, hp_g._falls])
			for i in range(1, hp_g._holds.size()):
				hp_g._cur = i - 1
				hp_g._grab(hp_g._screen(hp_g._holds[i].p))
				if hp_g._fall_t > 0.0:
					hp_g._fall_t = 0.0
					hp_g._cur = i - 1
					hp_g._grab(hp_g._screen(hp_g._holds[i].p))
			print("HP ylhäällä %s" % hp_g._top)
			hp_g._end()
			await main.get_tree().process_frame
			print("HP valmis: state %s, ylhäällä %s, nousuja %d, putoamisia %d, tehtävät %s, minipeli auki %s" % [main.state, main.hiidenportti.ylhaalla, main.hiidenportti.nousuja, main.hiidenportti.putoamisia, main._hiidenportti_tasks(), main._minigame_open()])
			main.get_tree().quit()
		"drakkar":
			# Drakkar Noir: pullo Railin pöydällä, osto, legendaarinen hetki, suihkaus, Sinikan ja Päivin reaktiot ja
			# tanssibonus. Tallennus palautetaan lopuksi.
			var saved_dk := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.drakkar_found = false
			main.drakkar = 0
			main.drakkar_day = -1
			main.endings.counts.erase("drakkar")
			main.money = 30.0
			main.clock_min = 12.0 * 60.0
			main._enter_kirppis("kirppis")
			for f in 10:
				await main.get_tree().process_frame
			var tcam := Camera3D.new()
			tcam.fov = 30.0
			main.kirppis_int.add_child(tcam)
			var bp: Vector3 = main.kirppis_int.drakkar.global_position
			tcam.look_at_from_position(bp + Vector3(0.12, 0.22, 0.45), bp + Vector3(0, 0.07, 0))
			tcam.current = true
			main._hud.visible = false
			for f in 8:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_poyta.png"))
			tcam.look_at_from_position(bp + Vector3(1.2, 1.3, 2.0), bp + Vector3(0, 0.2, -0.5))
			for f in 4:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_poyta_laaja.png"))
			tcam.queue_free()
			main._hud.visible = true
			main._talk_who = "raili"
			print("DRAKKAR Railin valinnat: %s" % str(main._talk_options()).left(400))
			main._talk_kirppis("osta_drakkar")
			print("DRAKKAR ostettu: suihkauksia %d, löydetty %s, rahaa %.1f, hetki %s" % [main.drakkar, main.drakkar_found, main.money, main.endings.counts.has("drakkar")])
			print("DRAKKAR piilossa nyt: %s" % main._kirppis_hidden("drakkar"))
			main._on_eat("drakkar")
			print("DRAKKAR suihkaus 1: päivä %s, jäljellä %d, viesti '%s'" % [main.drakkar_day == main.day, main.drakkar, main._msg.text])
			main._on_eat("drakkar")
			print("DRAKKAR suihkaus 2: '%s'" % main._msg.text)
			print("DRAKKAR Sinikka: '%s'" % main._talk_hello("sinikka"))
			print("DRAKKAR tanssi 0.6 -> %.2f" % main._drakkar_dance(0.6))
			main.drakkar = 1
			main._on_eat("drakkar")
			print("DRAKKAR tyhjä: jäljellä %d, myynnissä taas %s" % [main.drakkar, not main._kirppis_hidden("drakkar")])
			var cnt: int = main.endings.counts.get("drakkar", 0)
			main._talk_kirppis("osta_drakkar")
			print("DRAKKAR uusi pullo: suihkauksia %d, hetkiä %d (ennen %d)" % [main.drakkar, main.endings.counts.get("drakkar", 0), cnt])
			main._talk_box.close()
			main._on_kirppis_exited()
			# Päivi kotona: tuoksu huomataan ovella.
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			for f in 5:
				await main.get_tree().physics_frame
			main._enter_home("ovi")
			print("DRAKKAR Päivi: %s" % str(main._msg_queue).contains("Drakkar Noir? Kenelle"))
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_dk)
		"haalari":
			# Hiihtohaalari: Railin vaatetanko kirppiksellä, osto, Anna-Liisan reaktio, kodin vaatekaappi, Päivin reaktio ja
			# pelaajan malli haalarissa (edestä, takaa, sivulta, pää ja panta lähikuvina, juoksu). Tallennus palautetaan.
			var saved_h := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.has_haalari = false
			Looks.outfit = "tuulipuku"
			Looks.hat = ""
			main.money = 30.0
			main.clock_min = 12.0 * 60.0
			var snap := func(name: String) -> void:
				for f in 8:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main._enter_kirppis("kirppis")
			for f in 10:
				await main.get_tree().process_frame
			await snap.call("_sali.png")
			var tcam := Camera3D.new()
			tcam.fov = 40.0
			main.kirppis_int.add_child(tcam)
			var rp: Vector3 = main.kirppis_int.haalari.global_position
			tcam.look_at_from_position(rp + Vector3(0.3, -0.6, 2.2), rp + Vector3(0, -0.75, 0))
			tcam.current = true
			main._hud.visible = false
			await snap.call("_tanko.png")
			tcam.look_at_from_position(rp + Vector3(0.05, -0.3, 0.75), rp + Vector3(0, -0.35, 0))
			await snap.call("_tanko_lahi.png")
			tcam.queue_free()
			main._hud.visible = true
			main._talk_who = "raili"
			print("HAALARI Railin valinnat: %s" % [main._talk_options().map(func(o): return o.id)])
			main._talk_kirppis("osta_haalari")
			print("HAALARI ostettu: %s, rahaa %.1f, piilossa %s, tangossa näkyy %s" % [main.has_haalari, main.money,
				main._kirppis_hidden("haalari"), main.kirppis_int.haalari.visible])
			main._talk_box.close()
			for f in 4:
				await main.get_tree().process_frame
			await snap.call("_ostettu.png")
			main._on_kirppis_exited()
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			for f in 5:
				await main.get_tree().physics_frame
			main._enter_home("ovi")
			main.home_int.walker.position = HomeInterior.SPOTS.vaatekaappi[0]
			for f in 8:
				await main.get_tree().physics_frame
			main._on_home_acted("vaatekaappi")
			print("HAALARI kaappi: %s" % [main._item_menu._items])
			main._item_menu.visible = false
			main._on_wardrobe("hiihtohaalari")
			print("HAALARI päällä: %s, viesti '%s'" % [Looks.outfit, main._msg.text])
			main._msg.text = ""
			await snap.call("_kotona.png")
			main._on_home_exited()
			main._today.erase("haalari_paivi")
			main._enter_home("ovi")
			print("HAALARI Päivi: %s" % str(main._msg_queue).contains("pinkki karkki"))
			main._on_home_exited()
			main._today.erase("haalari_seura")
			main._enter_kirppis("kirppis")
			for f in 3:
				await main.get_tree().process_frame
			print("HAALARI Anna-Liisa: '%s'" % main.kirppis_int._bubbles[main.kirppis_int._people[main.kirppis_int.person_index("annaliisa")]].text)
			await snap.call("_kirppis_paalla.png")
			main._on_kirppis_exited()
			# Malli lavalla: kokonaan joka suunnasta ja pää lähikuvina.
			var stage := Node3D.new()
			main.add_child(stage)
			stage.global_position = Vector3(5000, 0, 5000)
			var lamp := DirectionalLight3D.new()
			lamp.rotation_degrees = Vector3(-40, 25, 0)
			stage.add_child(lamp)
			var c: Node3D = Looks.make(stage, Looks.player("hiihtohaalari"))
			Looks.add_cap(c)
			c.play("Idle", 0.0)
			var cam := Camera3D.new()
			cam.fov = 40.0
			stage.add_child(cam)
			cam.current = true
			main._hud.visible = false
			for k in [["koko", 0.0, Vector3(0, 1.0, 3.4), Vector3(0, 0.9, 0)], ["takaa", PI, Vector3(0, 1.0, 3.4), Vector3(0, 0.9, 0)],
					["sivu", PI * 0.5, Vector3(0, 1.0, 3.4), Vector3(0, 0.9, 0)], ["rinta", 0.0, Vector3(0, 1.3, 1.5), Vector3(0, 1.25, 0)],
					["jalat", 0.25, Vector3(0, 0.4, 1.6), Vector3(0, 0.35, 0)], ["paa", 0.3, Vector3(0, 1.75, 0.9), Vector3(0, 1.68, 0)],
					["paa_taka", PI - 0.4, Vector3(0, 1.8, 0.9), Vector3(0, 1.68, 0)], ["paa_sivu", PI * 0.5, Vector3(0, 1.72, 0.9), Vector3(0, 1.68, 0)]]:
				c.rotation.y = PI + k[1]
				cam.look_at_from_position(stage.global_position + k[2], stage.global_position + k[3])
				await snap.call("_%s.png" % k[0])
			c.play("Jog_Fwd", 0.0)
			c.rotation.y = PI + 0.6
			cam.look_at_from_position(stage.global_position + Vector3(0, 1.0, 3.4), stage.global_position + Vector3(0, 0.9, 0))
			for f in 20:
				c.anim.advance(0.03)
				await main.get_tree().process_frame
			await snap.call("_juoksu.png")
			Looks.outfit = "tuulipuku"
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_h)
			main.get_tree().quit()
		"bikini_video":
			# Video Sinikasta lappubikineissä eri animaatioissa (Movie Maker: --write-movie, --fixed-fps 30): kamera
			# kiertää hahmoa, välillä lähikuva ylävartalosta. Lopuksi peli sulkeutuu.
			var stage := Node3D.new()
			main.add_child(stage)
			stage.global_position = Vector3(5000, 0, 5000)
			var lamp := DirectionalLight3D.new()
			lamp.rotation_degrees = Vector3(-40, 25, 0)
			lamp.shadow_enabled = true
			stage.add_child(lamp)
			var floor_m := B.mesh(stage, B.cyl(2.5, 2.5, 0.04, 48), Vector3(0, -0.02, 0), Color(0.42, 0.36, 0.26))  # hiekka (tumma: valo polttaa)
			floor_m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var c: Node3D = Looks.make(stage, Looks.sinikka_bikini())
			var cam := Camera3D.new()
			cam.fov = 38.0
			stage.add_child(cam)
			cam.current = true
			main._hud.visible = false
			main._note.visible = false
			var caption := Label.new()
			caption.add_theme_font_size_override("font_size", 30)
			caption.add_theme_color_override("font_outline_color", Color.BLACK)
			caption.add_theme_constant_override("outline_size", 8)
			caption.position = Vector2(40, 30)
			var layer := CanvasLayer.new()
			layer.layer = 20
			main.add_child(layer)
			layer.add_child(caption)
			var shots := [["Idle", "Seisoo", false], ["Walk", "Kävely", false], ["Dance", "Tanssi", false], ["Dance", "Tanssi, lähikuva", true],
				["Jump", "Hyppy", false], ["Punch_Cross", "Lyönti", false], ["Idle", "Seisoo, lähikuva", true]]
			var t_all := 0.0
			for sh in shots:
				c.play(sh[0], 0.2)
				caption.text = "Sinikka · " + sh[1]
				var t := 0.0
				while t < 4.0:
					var dt := main.get_process_delta_time()
					t += dt
					t_all += dt
					var a := t_all * 0.6
					var close: bool = sh[2]
					var r := 1.2 if close else 3.4
					var h := 1.25 if close else 1.1
					var look_y := 1.15 if close else 0.95
					cam.look_at_from_position(stage.global_position + Vector3(sin(a) * r, h, cos(a) * r), stage.global_position + Vector3(0, look_y, 0))
					await main.get_tree().process_frame
			main.get_tree().quit()
		"eramaa":
			# Etelän erämaa (#147) ja rauniot (#145): laavun nuotio, makkara ja kalja (loppu), Viitajärven uinti,
			# Kaitasaaren ilta, metso aamulla, suojelualueen kyltti, Puntarimäki; rauniot: teinit, kalja, valokuva,
			# Pirtti ja jemma. Kuvat.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.quests = Quests.new()
			main.endings = Endings.new()
			main._valokuva = 0
			main._viita_fire_day = -1
			main._viita_kalja_day = -1
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
			main.clock_min = 8 * 60 + 30
			await frames.call(3)
			var mp: Vector3 = main.world.metso.global_position
			await view.call("_metso.png", mp + Vector3(2.2, 1.0, -1.5), mp + Vector3(0, 0.5, 0))
			await at.call(mp + Vector3(4, 0, 0))
			print("ER metso: '%s' (näkyy %s, kello %d, etäisyys %.1f, stun %s, bike %s)" % [main._hint.text, main.world.metso.visible, main.clock_min, main.walker_out.global_position.distance_to(mp), main.player.is_stunned(), main.player == main.bike])
			await press.call("interact")
			print("ER soidin %s" % ("metso" in main.tilat.firsts))
			main.clock_min = 20 * 60 + 30
			main.has_matches = true
			main.has_sausage = true
			main.sausage_done = false
			main.beers = 3
			var vp: Vector3 = main.world.viita_pos
			await at.call(vp + Vector3(1.6, 0, 0))
			print("ER laavu: '%s'" % main._hint.text)
			await press.call("interact")
			await frames.call(3)
			print("ER makkara: '%s'" % main._hint.text)
			await press.call("interact")
			await frames.call(3)
			print("ER kalja: '%s'" % main._hint.text)
			await press.call("interact")
			print("ER loppu %s (onnellinen %s), loput %d/%d, tila %s" % [main.endings.counts.has("eramaan_laavu"), Endings.is_loppu("eramaan_laavu"),
				main.endings.distinct("loppu"), Endings.max_count("loppu"), main.state])
			for i in 240:  # loppukohtaus: kuva auringonlaskusta
				await main.get_tree().process_frame
			await snap.call("_eramaa_loppu.png")
			for i in 1200:
				if main.state != "cutscene":
					break
				await main.get_tree().process_frame
			print("ER uusi päivä %d, tila %s" % [main.day, main.state])
			main._viita_find_shore()
			print("ER ranta %s, suunta %s" % [main._viita_shore, main._viita_dir])
			await at.call(main._viita_shore)
			print("ER uinti: '%s'" % main._hint.text)
			main.clock_min = 12 * 60
			main._swim("Viitajärvi", Vector3.ZERO)
			await main.get_tree().create_timer(5.5).timeout
			await snap.call("_viitauinti.png")
			for i in 80:
				if main.state != "cutscene":
					break
				await main.get_tree().create_timer(0.5).timeout
			print("ER uitu: %s, '%s'" % [main.state, main._msg.text.left(40)])
			main.clock_min = 20 * 60
			await at.call(main.world.kaitasaari_pos + Vector3(1.0, 0, 0))
			print("ER kaitasaari: '%s'" % main._hint.text)
			await press.call("interact")
			print("ER ilta: '%s'" % main._msg.text.left(40))
			await at.call(main.world.suojelu_pos[1] + Vector3(1, 0, 0))
			print("ER suojelu: '%s'" % main._hint.text)
			await at.call(main.world.puntari_pos + Vector3(2, 0, 0))
			print("ER puntari: '%s'" % main._hint.text)
			# Rauniot.
			var ry: Vector3 = main.world.rauniot_youth_pos
			main.clock_min = 12 * 60
			await view.call("_rauniot.png", ry + Vector3(-14, 8, 10), M.w(Vector2(160, 45)))
			main.clock_min = 21 * 60
			await at.call(ry + Vector3(3, 0, 0))
			print("ER teinit: '%s', näkyy %s" % [main._hint.text, main.world.rauniot_youth.visible])
			await view.call("_nuotio.png", ry + Vector3(4, 2, 4), ry + Vector3(0, 0.6, 0))
			main.beers = 2
			print("ER valinnat: %s (kaljoja %d)" % [main._talk_options("rauniot_nuoret").map(func(o): return o.id), main.beers])
			main._talk_open("rauniot_nuoret", null)
			main._talk_box._pages.clear()
			main._talk_choose("tarjoa")
			main._talk_box.close()
			await frames.call(20)
			await at.call(main.world.rauniot_uuni + Vector3(0.8, 0, 0.8))
			print("ER uuni: '%s'" % main._hint.text)
			await press.call("interact")
			print("ER valokuva %d" % main._valokuva)
			main.clock_min = 12 * 60
			await at.call(main.world.museum_door)
			print("ER pirtti: '%s'" % main._hint.text)
			await press.call("interact")
			print("ER lahjoitettu %d" % main._valokuva)
			await at.call(main.world.rauniot_stash)
			print("ER jemma: '%s'" % main._hint.text)
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"junttikierto":
			# Juntti kiertää paikkojaan: pelaaja menee eri paikkojen lähelle (selin paikkaan), ja Juntti on siellä; kun
			# paikka näkyy kamerassa, Juntti ei siirry.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			if main.player == main.bike:
				main._toggle_mount()
			# _juntti_roam ajetaan _processissa: odotetaan prosessiruutuja (hitaalla koneella yhteen prosessiruutuun
			# mahtuu monta fysiikkaruutua).
			var frames := func(n: int) -> void:
				for i in n:
					await main.get_tree().process_frame
			for k in [5, 6, 0, 2]:
				var at := M.w(M.JUNTTI_SPOTS[k])
				main.walker_out.global_position = at + Vector3(60, 0.3, 0)
				var cam := main.get_viewport().get_camera_3d()
				cam.look_at_from_position(main.walker_out.global_position + Vector3(-3, 2, 0), main.walker_out.global_position + Vector3(10, 1, 0))
				main._juntti_hop_t = 0.0
				await frames.call(10)
				var seen := cam.is_position_in_frustum(at + Vector3(0, 1, 0))
				var jd := Vector2(main.juntti.global_position.x - at.x, main.juntti.global_position.z - at.z).length()
				print("JU paikka %d %s: Juntti %.1f m paikasta (paikka kamerassa %s), tila %s" % [k, M.JUNTTI_SPOTS[k], jd, seen, main.juntti.mode])
			# Katse kohti paikkaa: Juntti ei saa ilmestyä silmien eteen.
			var at2 := M.w(M.JUNTTI_SPOTS[4])
			main.walker_out.global_position = at2 + Vector3(60, 0.3, 0)
			var cam2 := main.get_viewport().get_camera_3d()
			cam2.look_at_from_position(main.walker_out.global_position + Vector3(3, 2, 0), at2 + Vector3(0, 1, 0))
			main._juntti_hop_t = 0.0
			await frames.call(10)
			print("JU katse paikkaan 4: kamerassa %s, Juntti %.1f m paikasta" % [cam2.is_position_in_frustum(at2 + Vector3(0, 1, 0)),
				Vector2(main.juntti.global_position.x - at2.x, main.juntti.global_position.z - at2.z).length()])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"jemmat":
			# Päiväkirjan Jemmat-välilehti: löydetyt jemmat, kaljat / tila, riskit ja yhteensä. Kuva välilehdestä.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.stash = {"koti": 3, "autotalli": 12, "komposti": 0, "grilli": 7, "uimaranta": 2}
			main.stash_used = ["koti", "autotalli", "komposti", "grilli", "uimaranta"]
			main.beers = 4
			var d: Dictionary = main._stash_journal()
			print("JE yhteensä koti %d/%d, ulko %d, löydetty %d/%d" % [d.home, d.goal, d.out, d.found, d.all])
			for r in d.rows:
				print("JE %s %d/%d %s%s" % [r.name, r.n, r.cap, r.note, " ⚠" if r.warn else ""])
			print("JE muut %s" % [d.extra])
			print("JE reppu %s" % [main.inventory_info().stashes])
			var snap := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main._journal.toggle()
			main._journal._set_tab("jemmat")
			for i in 4:
				await main.get_tree().process_frame
			await snap.call("_jemmat.png")
			main._journal.toggle()
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"honganpalo_maasto":
			# Honganpalon koulu ja kenttä maaston pinnalla: kenttä matalalta sivusta (rako maahan näkyy), päädystä ja
			# ylhäältä, koulu edestä ja takaa (sokkeli rinteessä), piha (vahtimestari, iltaporukka). Lokiin kentän rako
			# maahan yhdeksästä pisteestä (TESTI VIKA, jos yli 0,15 m). Kuvat _hongan_*.
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.fov = 55.0
			var snap := func(name: String, eye: Vector3, at: Vector3) -> void:
				cam.global_position = eye
				cam.look_at(at, Vector3.UP)
				cam.current = true
				for i in 14:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_hongan_%s.png" % name))
			main._hud.visible = false
			main.clock_min = 19 * 60.0
			var w: Node3D = main.world
			var kc := M.w2(M.HONGAN_KENTTA)
			var kp := Vector3(kc.x, Terrain.h(kc.x, kc.y), kc.y)
			main.player.global_position = kp + Vector3(0, 0.3, 45)
			for i in 20:
				await main.get_tree().process_frame
			var field: Node3D = w.hongan_kids[0].get_parent()  # pojat ovat kentän lapsia
			var worst := 0.0
			var rako := []
			for dz in [-17.0, 0.0, 17.0]:
				for dx in [-11.0, 0.0, 11.0]:
					var q: Vector3 = field.to_global(Vector3(dx, 0, dz))
					var g := q.y - Terrain.h(q.x, q.z)
					worst = maxf(worst, absf(g))
					rako.append("%.2f" % g)
			print("HONGAN kentän pinta - maa: %s (pahin %.2f m)%s" % [rako, worst, "  TESTI VIKA" if worst > 0.15 else ""])
			var hp: Vector3 = w.hongan_hoop.global_position
			print("HONGAN kori - maa %.2f" % (hp.y - Terrain.h(hp.x, hp.z)))
			await snap.call("kentta_sivu", kp + Vector3(24, 1.2, 4), kp + Vector3(0, 0.3, 0))
			await snap.call("kentta_paaty", kp + Vector3(3, 1.6, 26), kp + Vector3(0, 0.5, 0))
			await snap.call("kentta_ylha", kp + Vector3(0, 38, 8), kp)
			var dp: Vector3 = w.hongan_door
			var sc := M.w2(M.HONGAN_KOULU)
			var sp := Vector3(sc.x, Terrain.h(sc.x, sc.y), sc.y)
			var out := Vector3(dp.x - sp.x, 0, dp.z - sp.z).normalized()
			await snap.call("koulu_edesta", dp + out * 18.0 + Vector3(0, 3.0, 0), dp + Vector3(0, 1.5, 0))
			await snap.call("koulu_takaa", sp - out * 30.0 + Vector3(6, 4.0, 0), sp + Vector3(0, 1.0, 0))
			await snap.call("piha", w.hongan_janitor_pos + Vector3(4, 2.0, 4), w.hongan_youth_pos + Vector3(0, 0.8, 0))
			return 1
		"honganpalo":
			# Honganpalon koulu (#138) ja Lapinraunion aarnivalkea (#139): vahtimestarin keikka, luokkakuva, jäätelöauto,
			# iltaporukan juoru, rankkaripiste; Hilkan legenda, Pannu-Sulo yöllä, Pirtin pöytäkirja, oikea liekki,
			# droonikohde, hopeat, Pirtti (loppu) ja Veksi. Kuvat koulusta, raunioista ja yöliekistä.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.aarni = Aarnivalkea.new()
			main.quests = Quests.new()
			main.endings = Endings.new()
			main._hongan_day = -1
			main._hongan_keikka = false
			main._rankku_day = -1
			main.day = 4  # torstai
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
			main.money = 50.0
			main.clock_min = 10 * 60
			var hd: Vector3 = main.world.hongan_door
			var hc := M.w(M.HONGAN_KOULU)
			var hdir := ((hd - hc) * Vector3(1, 0, 1)).normalized()
			await view.call("_koulu.png", hd + hdir * 16.0 + hdir.cross(Vector3.UP) * 12.0 + Vector3(0, 5, 0), hc + Vector3(0, 2, 0))
			await at.call(main.world.hongan_janitor_pos + Vector3(1.2, 0, 0))
			print("HO reijo: '%s' näkyy %s" % [main._hint.text, main.world.hongan_janitor.visible])
			print("HO reijo valinnat: %s" % [main._talk_options("vahtimestari").map(func(o): return o.id)])
			main._talk_open("vahtimestari", main.world.hongan_janitor)
			main._talk_box._pages.clear()
			main._talk_choose("keikka")
			main._talk_box.close()
			await frames.call(20)
			var m0 := main.money
			for t in main.world.hongan_trash:
				await at.call(t.global_position)
				await press.call("interact")
			print("HO keikka: roskia jäljellä %d, rahaa +%s, '%s'" % [main._hongan_trash_left(), main._eur(main.money - m0), main._msg.text.left(40)])
			await at.call(main.world.hongan_window)
			print("HO ikkuna: '%s'" % main._hint.text)
			await press.call("interact")
			print("HO luokkakuva: '%s'" % main._msg.text.left(50))
			await at.call(main.world.hongan_spot)
			print("HO kenttä: '%s'" % main._hint.text)
			main.clock_min = 18 * 60
			await at.call(main.world.hongan_truck_pos + Vector3(2.0, 0, 0))
			print("HO jäätelöauto näkyy %s: '%s'" % [main.world.hongan_truck.visible, main._hint.text])
			await press.call("interact")
			print("HO jäätelö %d" % main.food.get("jaatelo", 0))
			await view.call("_jaatelo.png", main.world.hongan_truck_pos + hdir * 9.0 + Vector3(0, 3, 0), main.world.hongan_truck_pos + Vector3(0, 1, 0))
			main.clock_min = 20 * 60
			await at.call(main.world.hongan_youth_pos + hdir * 2.0)
			print("HO porukka: '%s'" % main._hint.text)
			for i in 15:
				main._talk_who = "hongan_nuoret"
				main._talk_chat_line()
			print("HO juoru aarnivalkea %s" % ("juoru_aarnivalkea" in main.tilat.firsts))
			# Legenda.
			main._talk_who = "hilkka"
			main._talk_kirppis("aarnivalkea")
			main._talk_box.close()
			print("HO kuultu %s, tehtävät %s" % [main.aarni.heard, main._aarni_tasks()])
			var rp: Vector3 = main.world.raunio_pos
			main.clock_min = 12 * 60
			await view.call("_raunio.png", rp + Vector3(-9, 5, 10), rp + Vector3(-4, 0, -4))
			main.clock_min = 23 * 60
			await at.call(rp + Vector3(14, 0, 0))
			await frames.call(5)
			await view.call("_sulo.png", rp + Vector3(12, 2.5, 6), rp + Vector3(5, 0.8, 1))
			await at.call(rp + Vector3(8, 0, 1))
			print("HO sulo: %s, '%s'" % [main.aarni.sulo, main._msg.text.left(60)])
			await at.call(rp + Vector3(5, 0, 0))
			print("HO raunio: '%s'" % main._hint.text)
			main.clock_min = 12 * 60
			await at.call(main.world.museum_door)
			print("HO pirtti: '%s'" % main._hint.text)
			await press.call("interact")
			print("HO pöytäkirja %s" % main.aarni.poytakirja)
			main.clock_min = 23 * 60
			print("HO droonikohde %s" % [main._drone_pois().any(func(d): return d.id == "aarni_hehku")])
			var ap := M.w(M.AARNI_SPOT)
			await at.call(ap + Vector3(10, 0, 0))
			print("HO liekki %s, '%s'" % [main.aarni.liekki, main._msg.text.left(50)])
			await view.call("_aarnivalkea.png", ap + Vector3(4, 1.8, 3), ap + Vector3(0, 0.4, 0))
			await at.call(ap + Vector3(1.2, 0, 0))
			print("HO kivikasa: '%s'" % main._hint.text)
			await press.call("interact")
			print("HO hopeat %s, tehtävät %s, veksi %s" % [main.aarni.found, main._aarni_tasks(), main.kirppis_int.veksi_open])
			main.clock_min = 12 * 60
			await at.call(main.world.museum_door)
			print("HO pirtti 2: '%s'" % main._hint.text)
			await press.call("interact")
			# Ensimmäisellä kerralla Pirtin pihan hetki lavastetaan (aarnivalkea_legenda.gd, oma testi legendat aarnivalkea_eka): ohitetaan.
			for lg in main.get_children().filter(func(c): return c.get_script() == preload("res://scripts/aarnivalkea_legenda.gd")):
				lg._finish()
			await frames.call(3)
			print("HO museo: %s, loppu %s, loput %d/%d" % [main.aarni.choice, main.endings.counts.has("aarnivalkea"), main.endings.distinct(), Endings.max_count()])
			var pr := {}
			for who in ["arto", "annaliisa", "pekka"]:
				for i in 15:
					main._talk_who = who
					pr[main._talk_chat_line()] = true
			print("HO todistettu: %s" % [Main.AARNI_PROVEN.keys().filter(func(w): return Main.AARNI_PROVEN[w].any(func(l): return pr.has(l)))])
			main.aarni.choice = ""
			print("HO veksi: %s" % [main._talk_options("veksi").map(func(o): return o.id)])
			main._talk_who = "veksi"
			main._aarni_sell()
			main._talk_box.close()
			print("HO myyty: %s" % main.aarni.choice)
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"ideat":
			# Tehtävien ideat: uusi sivutehtävä tiedoksi ajatuksena, sähköpyörän osien paikat kyläläisiltä ja nälkäajatus.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.quests = Quests.new()
			main.ebike = EBike.new()
			if main.player == main.bike:
				main._toggle_mount()
			var idle := func(n: int) -> void:
				for i in n:
					await main.get_tree().process_frame
			var snap := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			await idle.call(40)
			print("ID alku: hiljaa tiedossa %d, viesti '%s'" % [main.quests.known.size(), main._msg.text])
			main._msg_queue.clear()
			main._show_message("", 0.0)
			print("ID kirppis: %s" % main._kirppis_give("ruuvipurkki"))
			await idle.call(40)
			print("ID idea: '%s'" % main._msg.text)
			await snap.call("_idea.png")
			print("ID osalista ennen: %s" % [main.ebike.tasks()])
			main._msg_queue.clear()
			main._show_message("", 0.0)
			print("ID seppo: '%s'" % main._ebike_tip("seppo"))
			print("ID seppo 2: '%s'" % main._ebike_tip("seppo"))
			print("ID arto: '%s'" % main._ebike_tip("arto"))
			await idle.call(5)
			print("ID vinkkiviesti: '%s'" % main._msg.text)
			print("ID osalista jälkeen: %s" % [main.ebike.tasks()])
			main._msg_queue.clear()
			main._show_message("", 0.0)
			if not "nalka" in main.tilat.chosen:
				main.tilat.chosen.append("nalka")
			main.tilat.add("nalka", -3.0)
			main.clock_min = 12 * 60
			await idle.call(40)
			print("ID nälkä (%.2f): '%s'" % [main.tilat.value("nalka"), main._msg.text])
			await snap.call("_nalka.png")
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"hiirisisalla":
			# Hiiren napit sisätiloissa vapaalla kursorilla: vasen nappi = toiminto kylmiöllä (kuutonen koriin).
			Settings.values["mouse_steer_indoor"] = false
			main._enter_shop()
			main.interior.walker.position = main.interior.COOLER_SPOT
			for i in 10:
				await main.get_tree().process_frame
			var mid := main.get_viewport().get_visible_rect().size / 2.0
			print("HIIRI tila %s, hiiri %s, hint '%s', leijuu %s" % [main.state, Input.mouse_mode, main.interior.hint,
				main.get_viewport().gui_get_hovered_control()])
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.position = mid
			ev.global_position = mid
			ev.pressed = true
			Input.parse_input_event(ev)
			for i in 2:
				await main.get_tree().process_frame
			var up := ev.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
			for i in 3:
				await main.get_tree().process_frame
			print("HIIRI vasen nappi: kuutonen %s" % main.interior.has_beer)
		"juhlat":
			# Onnellinen loppu kotipiilolta: 24 kaljaa kotipiiloissa, nukkuminen ei aloita juhlia, kotipiilolla E aloittaa.
			main._toggle_mount()
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			main.stash["koti"] = 12
			main.stash["autotalli"] = 8
			main.stash["komposti"] = 4
			main.beers = 0
			main._kaljarauha = true  # Päivi ei etsi jemmoja yöllä (muuten jemma paljastuu ja välikohtaus alkaa)
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			for i in 10:
				await main.get_tree().physics_frame
			await press.call("interact")
			main.home_int.walker.position = main.home_int.SPOTS.sanky[0]
			for i in 5:
				await main.get_tree().physics_frame
			var e0 := main.jemma_endings
			await press.call("interact")
			for i in 30:
				await main.get_tree().process_frame
			print("JUHLAT nukuttu: jemma %d, loppuja %d -> %d, tila %s" % [main.jemma, e0, main.jemma_endings, main.state])
			await main._test_goto_stash("autotalli")
			print("JUHLAT kotipiilolla: hint '%s'" % main._hint.text)
			await press.call("interact")
			for i in 10:
				await main.get_tree().process_frame
			print("JUHLAT E: jemma %d, loppuja %d -> %d, tila %s" % [main.jemma, e0, main.jemma_endings, main.state])
		"chocotest":
			# Suklaa karkkitelineestä, maksu, ulos ja WASTED: lepyttääkö Päivin? Tallennus palautetaan lopuksi.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var ok := 0
			for i in 1000:
				main.has_chocolate = true
				ok += int(main._offer_chocolate() == "ok")
			print("CHOCO ok-osuus %.2f" % (ok / 1000.0))
			main._enter_shop()
			for i in 10:
				await main.get_tree().physics_frame
			main.interior.walker.position = main.interior.CANDY_SPOT
			for i in 5:
				await main.get_tree().physics_frame
			print("CHOCO hint=", main.interior.hint)
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			print("CHOCO cart=", main.interior.cart, " total=", main.interior._total())
			main.interior.has_paid = true
			main._on_shop_exited(false)
			print("CHOCO has_chocolate=", main.has_chocolate, " money=", main.money)
			main._lose("Testi", "wife")
			print("CHOCO mercy=", main._choco_mercy, " has_chocolate=", main.has_chocolate)
			for i in 60:
				await main.get_tree().create_timer(0.5, true, false, true).timeout
				if main.state != "cutscene":
					break
			print("CHOCO after state=", main.state, " money=", main.money, " msg=", main._msg.text.replace("\n", " | "))
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"fightfx":
			main.beers = 6
			main._on_kicked(Vector3.RIGHT)
			for i in 130:
				await main.get_tree().process_frame
			main.fight._j.position.x = main.fight._p.position.x + 1.2
			main.fight._p._start_attack("spin")
			for i in 14:
				await main.get_tree().process_frame
			main.fight._j.take_hit(12.0, 1.0, 3.2)
			main.fight.on_hit(main.fight._p, main.fight._j, false, "kick")
			main.fight.on_hit(main.fight._p, main.fight._j, false, "punch")
			for i in 4:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path)
			main.get_tree().quit()
			return 2
		"infoboard":
			var cam := Camera3D.new()
			cam.fov = 40.0
			main.add_child(cam)
			var ib := M.w(M.LAAVU) + Vector3(3.6, 0, -3.2)
			var nrm := Vector3(-sin(0.45), 0, -cos(0.45))
			cam.look_at_from_position(ib + Vector3(0, 1.5, 0) - nrm * -2.6, ib + Vector3(0, 1.4, 0), Vector3.UP)
			cam.current = true
			main.guard.visible = false
		"guardleave":
			main.player.position = M.w(M.LAAVU) + Vector3(0, 0.3, -20)
			main.guard.defeat()
			for i in 520:
				await main.get_tree().process_frame
		"hedgeclose":
			var cam := Camera3D.new()
			cam.fov = 50.0
			main.add_child(cam)
			var hb2 := M.w(M.HOME_BUILDING)
			cam.look_at_from_position(hb2 + Vector3(-19, 1.6, 6), hb2 + Vector3(-14, 0.8, -2), Vector3.UP)
			cam.current = true
			main._msg.text = ""
		"homeview", "homeview2":
			var cam := Camera3D.new()
			cam.fov = 55.0
			main.add_child(cam)
			var hb := M.w(M.HOME_BUILDING)
			var eye := M.w(Vector2(826, 1186)) + Vector3(0, 1.7, 0) if scene == "homeview" else M.w(Vector2(822, 1150)) + Vector3(0, 1.7, 0)
			cam.look_at_from_position(eye, hb + Vector3(0, 1.8, 0), Vector3.UP)
			cam.current = true
			main._msg.text = ""
		"garage":
			main.beers = 0
			main.jemma = 26
			main._win(true)
			print("GARAGE jemma=", main.jemma)
			for i in 200:
				await main.get_tree().process_frame
		"grilli":
			main.player.position = M.w(M.GRILLIKATOS) + Vector3(-3, 0.3, 8)
			main.player.rotation.y = 0.3
		"aloitusruutu":
			# Aloitusruutu kuten käynnistyksessä (päävalikko ja kiertävä kamera kodin yllä): taustalla ei saa näkyä
			# pelin HUD-laatikoita (esim. autovarkauden tähtilaatikko rikos/tahdet_hud.gd ilman tähtiä).
			main.menu.open_main()
			for i in 120:
				await main.get_tree().process_frame
			for n in main.find_children("*", "CanvasLayer", true, false):
				var cl := n as CanvasLayer
				if cl != main.menu and cl.visible and cl.layer < main.menu.layer and n.get_script() != null \
						and String(n.get_script().resource_path).ends_with("tahdet_hud.gd"):
					print("TESTI VIKA aloitusruudussa näkyy tähtilaatikko %s" % n.get_path())
			print("ALOITUS valikko auki %s" % main.menu.visible)
		"found":
			main._hud.visible = false
			main.cutscene.jemma_found(main.home_zone, 8, 12, func() -> void: pass)
			for i in 330:
				await main.get_tree().process_frame
		"aidat":
			# Pensasaidat tien kohdalta katkaistuina: kuvat kolmesta leikkauskohdasta (_aita_N.png).
			print("AIDAT leikattu %.1f m, kohtia %d" % [main.world.hedges_cut * 0.25, main.world.hedge_cut_at.size()])
			var ac := Camera3D.new()
			main.add_child(ac)
			for i in mini(3, main.world.hedge_cut_at.size()):
				var c: Vector2 = main.world.hedge_cut_at[i]
				var gy := Terrain.h(c.x, c.y)
				ac.look_at_from_position(Vector3(c.x + 7.0, gy + 6.0, c.y + 7.0), Vector3(c.x, gy + 0.5, c.y), Vector3.UP)
				ac.current = true
				for k in 30:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_aita_%d.png" % i))
		"hiirisisalla":
			# Hiiriohjaus sisätiloissa (oma asetus): pelkkä ulkoasetus ei ohjaa sisällä (kursori vapaana); sisäasetus
			# päälle -> hiiren liike kääntää hahmoa ja W vie katseen suuntaan; pois -> W liikkuu ruudulla ylös.
			var old_out: bool = Settings.get_v("mouse_steer")
			var old_in: bool = Settings.get_v("mouse_steer_indoor")
			Settings.set_v("mouse_steer", true)
			Settings.set_v("mouse_steer_indoor", false)
			if main.player == main.bike:
				main._toggle_mount()
			main._enter_home("ovi")
			var w: CharacterBody3D = main.home_int.walker
			w.position = Vector3(1.0, 0, -2.0)
			for i in 10:
				await main.get_tree().physics_frame
			print("HSISALLA ulkoasetus: sisällä %s, hiiri %d, ohjaa %s" % [CamCtl.indoors, Input.mouse_mode, CamCtl.steering()])
			Settings.set_v("mouse_steer_indoor", true)
			for i in 10:
				await main.get_tree().physics_frame
			print("HSISALLA hiiri %d ohjaa %s" % [Input.mouse_mode, CamCtl.steering()])
			var r0 := w.rotation.y
			for i in 20:
				var mm := InputEventMouseMotion.new()
				mm.relative = Vector2(-10, 0)
				Input.parse_input_event(mm)
				await main.get_tree().physics_frame
			var turned := wrapf(w.rotation.y - r0, -PI, PI)
			var fwd := -w.global_transform.basis.z
			var p0 := w.position
			Input.action_press("forward")
			for i in 20:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			var mv := w.position - p0
			print("HSISALLA käännös %.2f rad, W liike katseen suuntaan %.2f m, sivulle %.2f m" % [turned, mv.dot(fwd),
				mv.dot(w.global_transform.basis.x)])
			Settings.set_v("mouse_steer_indoor", false)
			var p1 := w.position
			Input.action_press("forward")
			for i in 20:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			print("HSISALLA ilman asetusta W liikkuu ruudulla ylös (−Z): %.2f m" % -(w.position - p1).z)
			Settings.set_v("mouse_steer", old_out)
			Settings.set_v("mouse_steer_indoor", old_in)
		"hiirinapit":
			# Hiiren napit: oletukset, vasen = toiminto lukitulla hiirellä (kotiovelle sisään), minipelin aikana ei,
			# rulla selaa esinevalikkoa, valikossa hiiren napin asetus ja oikea klikkaus tyhjentää.
			Settings.reset_keys()
			if main.player == main.bike:
				main._toggle_mount()
			var names := []
			for r in Settings.KEY_ROWS.size():
				var ks: Array = Settings.keys_of(r)
				if ks[2] != 0:
					names.append("%s=%s" % [Settings.KEY_ROWS[r][1], Settings.key_name(ks[2])])
			print("HNAPIT oletukset: ", ", ".join(names))
			var click := func(btn: int) -> void:
				for down in [true, false]:
					var ev := InputEventMouseButton.new()
					ev.button_index = btn
					ev.pressed = down
					Input.parse_input_event(ev)
					await main.get_tree().process_frame
					await main.get_tree().process_frame
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			for i in 10:
				await main.get_tree().physics_frame
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			await main.get_tree().process_frame
			await click.call(MOUSE_BUTTON_LEFT)
			print("HNAPIT vasen kotiovella: tila %s" % main.state)
			main._on_home_exited()
			for i in 5:
				await main.get_tree().physics_frame
			CamCtl.need_mouse = true
			var st0 := main.state
			await click.call(MOUSE_BUTTON_LEFT)
			print("HNAPIT minipelin aikana vasen: tila %s (ei muutosta: %s)" % [main.state, main.state == st0])
			CamCtl.need_mouse = false
			main._item_menu.open([["a", "Eka"], ["b", "Toka"], ["c", "Kolmas"]], "Testi")
			await main.get_tree().process_frame
			await click.call(MOUSE_BUTTON_WHEEL_DOWN)
			await click.call(MOUSE_BUTTON_WHEEL_DOWN)
			print("HNAPIT rulla esinevalikossa: valinta %d (odotus 2), pelaaja paikallaan %s" % [main._item_menu._sel, absf(main.walker_out.speed) < 0.1])
			main._item_menu.visible = false
			main.menu.open_main()
			main.menu._settings("sub_main")
			for i in 5:
				await main.get_tree().process_frame
			var row := 9  # soittokello
			for kb in main.menu._key_buttons:
				if kb[0] == row and kb[1] == 2:
					(kb[2] as Button).pressed.emit()
			await click.call(MOUSE_BUTTON_WHEEL_UP)
			print("HNAPIT asetus: kello = %s, viesti '%s'" % [Settings.key_name(Settings.keys_of(row)[2]), main.menu._key_note.text])
			var tabs: TabContainer = main.menu.find_children("*", "TabContainer", true, false)[0]
			tabs.current_tab = tabs.get_tab_count() - 1
			for i in 5:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_nappaimet.png"))
			Settings.reset_keys()
			main.menu.close()
		"hiiriohjaus":
			# Hiiriohjaus (FPS-tyyli): jalan hiiren käännös kääntää hahmon suoraan ja A sivuttain; pyörä ohjautuu
			# kameran suuntaan ja kamera pysyy maailmassa paikallaan.
			Settings.set_v("mouse_steer", true)
			if main.player == main.bike:
				main._toggle_mount()
			for i in 10:
				await main.get_tree().physics_frame
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			await main.get_tree().process_frame
			var h0 := main.walker_out.rotation.y
			CamCtl.yaw = 0.6
			for i in 3:
				await main.get_tree().physics_frame
			print("HIIRI ohjaa=%s jalan käännös %.2f (odotus 0.60) yaw jäljellä %.2f" % [CamCtl.steering(), wrapf(main.walker_out.rotation.y - h0, -PI, PI), CamCtl.yaw])
			var p0 := main.walker_out.global_position
			var side0 := main.walker_out.global_transform.basis.x
			Input.action_press("left")
			for i in 60:
				await main.get_tree().physics_frame
			Input.action_release("left")
			var mv := main.walker_out.global_position - p0
			print("HIIRI A-sivuaskel: sivulle %.2f m, eteen %.2f m" % [mv.dot(side0), mv.dot(-main.walker_out.global_transform.basis.z)])
			var far := main.walker_out.global_position + Vector3(300, 0, 250)
			var np: Vector3 = main.world.ride.get_point_position(main.world.ride.get_closest_point(Vector3(far.x, 0, far.z)))
			main.bike.global_position = Vector3(np.x, Terrain.h(np.x, np.z) + 0.4, np.z)
			main._toggle_mount()
			for i in 10:
				await main.get_tree().physics_frame
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			Input.action_press("forward")
			for i in 60:
				await main.get_tree().physics_frame
			var target := main.bike.rotation.y + 0.8
			CamCtl.yaw = 0.8
			for k in 4:
				for i in 30:
					await main.get_tree().physics_frame
				print("HIIRI pyörä %.1f s: keula-ero kohteeseen %.2f, kameran ero kohteeseen %.2f, vauhti %.1f" % [
					(k + 1) * 0.5, wrapf(target - main.bike.rotation.y, -PI, PI), wrapf(target - main.bike.rotation.y - CamCtl.yaw, -PI, PI), main.bike.speed])
			Input.action_release("forward")
			Settings.set_v("mouse_steer", false)
		"humala_ohjaus":
			# Humalan ohjaushaitta: kävellään ja ajetaan 6 s suoraan ilman ohjausta, selvänä ja humalassa 0,9. Suunnan
			# muutos. Humala ei ole päivän tiloissa: heittely on silti päällä (kuten mopolla).
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.tilat.chosen = ["stressi", "moraali", "kipu"]
			for mounted in [false, true]:
				if (main.player == main.bike) != mounted:
					main._toggle_mount()
				for h in [0.0, 0.9]:
					main.tilat.values["humala"] = h
					main.player.global_position = M.w(M.GRILLIKATOS) + Vector3(1.0, 0.5, 1.0)
					main.player.rotation.y = 0.0
					Input.action_press("forward")
					var max_dev := 0.0
					for i in 360:
						await main.get_tree().physics_frame
						max_dev = maxf(max_dev, absf(wrapf(main.player.rotation.y, -PI, PI)))
					Input.action_release("forward")
					print("HUMALA %s humala=%.1f drunk=%.2f max suunnanmuutos %.0f°" % ["pyörä" if mounted else "jalan", h,
						main.player.drunk, rad_to_deg(max_dev)])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"heitto":
			# Tappelussa kolme kaljanheittoa (eteen + L), sitten K.O. ja kaljamäärän tarkistus.
			main.beers = 6
			main.state = "ulkona"
			main._kuutonen_day = main.day
			main._start_fight("juntti", "juntti", Vector3.RIGHT)
			# Ottelun alkuun asti (ei kiinteää ruutumäärää: hitaalla koneella Juntti ehti tyrmätä ennen heittoja), ja
			# pelaajalle reilusti energiaa, ettei Juntin isku katkaise heittosarjaa.
			for i in 600:
				await main.get_tree().process_frame
				if main.fight._phase == "fight":
					break
			main.fight._p.hp = 1000.0
			for k in 3:
				for w in 300:  # edellinen heitto tai Juntin isku kesken: heitto onnistuu vain vapaasta asennosta
					if main.fight._p.state in ["idle", "walk", "block"] and main.fight._p.on_ground():
						break
					await main.get_tree().process_frame
				var hp0: float = main.fight._j.hp
				Input.action_press("right")
				await main.get_tree().process_frame
				Input.action_press("special")
				await main.get_tree().process_frame
				Input.action_release("special")
				Input.action_release("right")
				for i in 12:
					await main.get_tree().process_frame
				if k == 0:
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_fly.png"))
				for i in 50:
					await main.get_tree().process_frame
				print("HEITTO %d thrown=%d foe hp %.0f -> %.0f foe_state=%s cans=%d" % [k, main.fight._thrown, hp0, main.fight._j.hp,
					main.fight._j.state, main.fight._cans.size()])
			print("HEITTO help=", main.fight._help._text.replace("\n", " | ").right(60))
			main.fight._j.hp = 0.0
			main.fight._j.state = "ko"
			for i in 300:
				await main.get_tree().process_frame
				if main.state != "fight":
					break
			print("HEITTO after fight beers=%d state=%s msg=%s" % [main.beers, main.state, main._msg.text.replace("\n", " | ")])
		"jemma_ovi":
			# Kotiinpaluu: kaljat kädessä ovi ei aukea, eteisen kaappiin piilotus E:llä, tyhjin käsin ovelle -> koti.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			if main.player == main.bike:
				main._toggle_mount()
			main.state = "ulkona"
			main._kuutonen_day = main.day
			main.jemma = 0
			main.beers = 3
			main.walker_out.global_position = main.home_zone + Vector3(0, 0.5, 0)
			for i in 3:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("OVI kaljat kädessä: state=%s hint=%s" % [main.state, main._hint.text])
			await main._test_goto_stash("koti")
			print("OVI jemman luona: hint=%s" % main._hint.text)
			for i in 3:
				await press.call("interact")
			print("OVI piilotettu: beers=%d jemma=%d state=%s hint=%s" % [main.beers, main.jemma, main.state, main._hint.text])
			main._on_home_exited()
			main.walker_out.global_position = main.home_zone + Vector3(3.0, 0.5, 2.0)
			await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("OVI pihalla tyhjin käsin: hint=%s" % main._hint.text)
			main.walker_out.global_position = main.home_zone + Vector3(0, 0.5, 0)
			for i in 3:
				await main.get_tree().physics_frame
				await main.get_tree().process_frame
			print("OVI ovella: state=%s jemma=%d" % [main.state, main.jemma])
			for i in 30:
				await main.get_tree().process_frame
			print("OVI aamu: day=%d msg=%s" % [main.day, main._msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		_:
			return 0
	return 1
