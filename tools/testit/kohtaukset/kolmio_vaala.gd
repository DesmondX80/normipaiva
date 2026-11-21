extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "kolmio_vaala". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const M := preload("res://scripts/map_data.gd")
const PajatsoGame := preload("res://scripts/pajatso_game.gd")
const HedelmapeliGame := preload("res://scripts/hedelmapeli_game.gd")
const TanssiGame := preload("res://scripts/tanssi_game.gd")

const KOHTAUKSET := ["bangbus", "bangbus_vaala", "parkit", "kolmio_iltakivat", "kolmio_tuppi", "kolmiomittaus_koti", "kolmiomittaus", "kolmiomittaus_vaala", "vaala_ajo", "siitaripelit", "siitarijukeboksi", "kolmio_juttu", "vaalakierros", "siitarihotelli", "paivipartio", "paivihyvitys", "paivihalytys", "paivikoti", "vaala_makasiini", "vaalakoodi", "paivin_puhelu"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"bangbus", "bangbus_vaala":
			# Pentin BangBus (#299, rikos/pentti.gd testi): aikataulu, auto, juttelu, kyyti, herätys ja kantelu; kuvat.
			var saved_bb := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			await main.rikos_osa("pentti").testi("vaala" if scene == "bangbus_vaala" else "")
			if not saved_bb.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_bb)
			else:
				DirAccess.remove_absolute(Main.SAVE_PATH)
			main.get_tree().quit()
			return 2
		"parkit":
			# Pysäköidyt autot eivät ole toistensa sisällä Saloisissa eikä Vaalassa (tools/testit/parkit.gd).
			var saved_pk := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			var pk: Node = load("res://tools/testit/parkit.gd").new()
			pk.main = main
			main.add_child(pk)
			await pk.run()
			if not saved_pk.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_pk)
			else:
				DirAccess.remove_absolute(Main.SAVE_PATH)
			main.get_tree().quit()
			return 2
		"kolmio_iltakivat":
			# Lettukisa, löylykisa, disko ja karaoke pelimaailmassa ovelta aamuun (tools/testit/kolmio_iltakivat.gd).
			var saved_ik := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var ik: Node = load("res://tools/testit/kolmio_iltakivat.gd").new()
			ik.main = main
			main.add_child(ik)
			await ik.run()
			if not saved_ik.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_ik)
		"kolmio_tuppi":
			# Räsytuppi kolmiomittauksen toisena iltana Saloisissa: tekoäly pelaa, ilta loppuun, aamu ja loppu.
			var saved_tp := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var tp: Node = load("res://tools/testit/kolmio_tuppi.gd").new()
			tp.main = main
			main.add_child(tp)
			await tp.run()
			if not saved_tp.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_tp)
		"kolmiomittaus_koti":
			# Luku 6 (#326): kesäheila -96, mittaus kotiin, ovi ja kolme valintaa (tools/testit/kolmiomittaus_koti.gd).
			var saved_kk := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			var kk: Node = load("res://tools/testit/kolmiomittaus_koti.gd").new()
			kk.main = main
			main.add_child(kk)
			await kk.run()
			if not saved_kk.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_kk)
			else:
				DirAccess.remove_absolute(Main.SAVE_PATH)
			main.get_tree().quit()
			return 2
		"kolmiomittaus", "kolmiomittaus_vaala":
			# Kolmiomittaus (#255): Saloinen tai Vaala alusta loppuun kuvineen (tools/testit/kolmiomittaus.gd).
			var saved_km := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			var km: Node = load("res://tools/testit/kolmiomittaus.gd").new()
			km.main = main
			km.site = "vaala" if scene == "kolmiomittaus_vaala" else "saloinen"
			main.add_child(km)
			await km.run()
			if not saved_km.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_km)
			else:
				DirAccess.remove_absolute(Main.SAVE_PATH)  # testi loi tallennuksen: pois, ettei seuraava ajo ala sen tilasta
			main.get_tree().quit()
			return 2
		"vaala_ajo":
			# Vaalan tiet, kohteet ja juna mopolla autopilotilla (tools/testit/vaala_ajo.gd).
			var saved_ajo := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			var ajo: Node = load("res://tools/testit/vaala_ajo.gd").new()
			ajo.main = main
			main.add_child(ajo)
			await ajo.run()
			if not saved_ajo.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_ajo)
			main.get_tree().quit()
			return 2
		"siitaripelit":
			# Pajatso ja hedelmäpeli Siitarissa: _sali (seurue koneella), _vapaa (vuoro saatu), pajatson tilat
			# (_p_veto, _p_kaari, _p_putoaa, _p_kuppi) ja hedelmäpelin tilat (_h_pyorii, _h_voitto, _h_tupla, _h_lukko).
			var _save_bak := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.clock_min = 20.0 * 60.0
			main._start_mopo()
			var mp: CharacterBody3D = main.mopo_trip.mopo
			mp.position = main.mopo_trip.vaala.siitari_park + Vector3(0, 0.5, 0)
			for i in 10:
				await main.get_tree().physics_frame
			main.mopo_trip.stop()
			main._on_mopo_arrived()
			main.money = 30.0
			var snap := func(name: String, frames := 20) -> void:
				for i in frames:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main.siitari_int.walker.position = main.siitari_int.spots.hedelmapeli[0] + Vector3(0.8, 0, 1.4)
			await snap.call("_sali.png", 40)
			main.siitari_int.walker.position = main.siitari_int.spots.hedelmapeli[0]
			main._on_siitari_acted("hedelmapeli")
			await snap.call("_vapaa.png", 30)
			# Pajatso.
			main._on_siitari_acted("pajatso")
			var pg: Node = main.get_children().filter(func(c): return c is PajatsoGame).front()
			pg._insert()
			await snap.call("_p_veto.png", 3)
			pg._launch(0.45)
			await snap.call("_p_lentaa.png", 10)
			# Tehdään sata laukausta eri voimilla ja tulostetaan, mihin ne päätyvät.
			var hits := {}
			for k in 60:
				pg._launch(k / 59.0)
				var guard := 0
				while pg._coin_state != "" and guard < 4000:
					pg._coin_step(1.0 / 240.0)
					guard += 1
				var key := "kuppi%d" % pg._hit_cup if pg._hit_t > 1.19 else "ohi"
				hits[key] = hits.get(key, 0) + 1
				pg._hit_t = 0.0
				pg._hit_cup = -1
			print("PAJATSO laukaukset: %s, potti %d" % [hits, pg.pot])
			pg.pot = 14
			pg._cup(2)
			pg._collect()
			await snap.call("_p_kuppi.png", 25)
			pg._finish()
			print("PAJATSO rahat %s, potti %d" % [main.money, main._pajatso_pot])
			await snap.call("_jalkeen.png", 5)
			# Hedelmäpeli.
			main._on_siitari_acted("hedelmapeli")
			var hg: Node = main.get_children().filter(func(c): return c is HedelmapeliGame).front()
			hg._play()
			await snap.call("_h_pyorii.png", 30)
			while hg._phase == "spin":
				await main.get_tree().process_frame
			print("HEDELMÄ: %s %s %s -> %s, vaihe %s" % [hg._sym(0), hg._sym(1), hg._sym(2), hg._win, hg._phase])
			# Pakotetaan voitto: kolme kelloa.
			hg._phase = "idle"
			var bell: int = hg._strip.find("kello")
			for r in 3:
				hg._pos[r] = float(bell)
			hg._resolve()
			await snap.call("_h_voitto.png", 8)
			hg._double("suuri")
			await snap.call("_h_tupla.png", 50)
			if hg._phase == "win":
				hg._collect()
			await snap.call("_h_kolikot.png", 50)
			hg._phase = "idle"
			hg._lock_ok = true
			hg._locked.assign([true, false, true])
			hg._msg = "LUKITSE?"
			await snap.call("_h_lukko.png", 5)
			# Palautusprosentti: 20 000 kierrosta ilman lukitusta ja tuplausta.
			var spent := 0.0
			var won := 0.0
			for k in 20000:
				for r in 3:
					hg._pos[r] = float(randi() % hg._strip.size())
				hg._locked.fill(false)
				hg._resolve()
				spent += 1.0
				won += hg._win
			hg._win = 0.0
			print("HEDELMÄ palautus %.1f %%" % (won / spent * 100.0))
			hg._finish()
			var _sf := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			_sf.store_buffer(_save_bak)
			_sf.close()
			main.get_tree().quit()
		"siitarijukeboksi":
			# Jukeboksi lauantaina: _valikko, iskelmä -> Raahen jätkien riita (_riita_r) ja tappelu (_tappelu_r),
			# sitten ysäri -> hedelmäpelin miehen riita (_riita_h), tappelu (_tappelu_h) ja häviö (_jalkeen_h).
			var _save_bak := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.day = 6
			main.clock_min = 20.0 * 60.0
			main._start_mopo()
			var mp: CharacterBody3D = main.mopo_trip.mopo
			mp.position = main.mopo_trip.vaala.siitari_park + Vector3(0, 0.5, 0)
			for i in 10:
				await main.get_tree().physics_frame
			main.mopo_trip.stop()
			main._on_mopo_arrived()
			main.money = 30.0
			var snap := func(name: String, frames := 30) -> void:
				for i in frames:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main.siitari_int.walker.position = main.siitari_int.spots.jukeboksi[0]
			for i in 5:
				await main.get_tree().process_frame
			print("JUKE vihje '%s'" % main._hint.text)
			main._on_siitari_acted("jukeboksi")
			print("JUKE valikko %s: %s" % [main._item_menu.is_open(), main._item_menu._items])
			var saa: Array = main._jukebox_songs.keys().filter(func(k: String) -> bool: return k.begins_with("saa_"))
			print("JUKE Saapasjalat %s" % [saa])
			if saa.size() != TanssiGame.Biisit.SONGS.size():
				print("TESTI VIKA jukeboksista puuttuu Saapasjalkojen biisejä: %s" % [saa])
			await snap.call("_valikko.png", 10)
			for round in [["isk_01_Sakkijarven_polkka", "_r", false], ["ysa_02_90s_Racer_Techno", "_h", true]]:
				main._today.erase("siitari_tappelu")
				main._item_menu.visible = false
				main._menu_mode = "jukeboksi"
				main._item_menu.chosen.emit(round[0])
				print("JUKE soi '%s', rahaa %.2f" % [Sfx._music_file, main.money])
				var tq := Time.get_ticks_msec()
				while not main._item_menu.is_open() and Time.get_ticks_msec() - tq < 3000:
					await main.get_tree().process_frame
				print("JUKE riita %s: %s" % [main._item_menu.is_open(), main._item_menu._items])
				await snap.call("_riita%s.png" % round[1], 10)
				main._item_menu.visible = false
				main._item_menu.chosen.emit("tappele")
				print("JUKE tila %s, vastustaja %s, musiikki soi %s" % [main.state, main.fight.foe.get("short", ""), main._jukebox_on])
				await snap.call("_tappelu%s.png" % round[1], 90)
				if round[2]:
					main.fight._p.hp = 0.0
					main.fight._p.state = "ko"
				else:
					main.fight._j.hp = 0.0
					main.fight._j.state = "ko"
				var tw := Time.get_ticks_msec()
				while main.state == "fight" and Time.get_ticks_msec() - tw < 20000:
					await main.get_tree().process_frame
				print("JUKE jälkeen: tila %s, rahaa %.2f, humala %.2f, viesti '%s'" % [main.state, main.money, main.tilat.value("humala"), main._msg.text])
				await snap.call("_jalkeen%s.png" % round[1])
				main.siitari_int.walker.position = main.siitari_int.spots.jukeboksi[0]
			var _sf := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			_sf.store_buffer(_save_bak)
			_sf.close()
			main.get_tree().quit()
		"kolmio_juttu":
			# Teron ja Timon juttelu Vaalan aseman pihalla: jalan kulkija heidän vieressään, vihje ja E (ei kuvia, toimii headlessina).
			main._start_mopo()
			var jv: Node3D = main.mopo_trip.vaala
			for i in 5:
				await main.get_tree().process_frame
			print("JUTTU npcs %d, ovi: %s" % [main._kolmio_vaala_npcs.size(), jv.doors.filter(func(d: Dictionary) -> bool: return d.id == "kolmio_kaverit")])
			main._mopo_dismount()
			for nm in [0, 1]:
				var npc: Node3D = main._kolmio_vaala_npcs[nm]
				for off in [Vector3(0, 0, 1.5), Vector3(1.5, 0, 0), Vector3(0, 0, 3.0), Vector3(0, 0, 4.5)]:
					main.walker_out.global_position = npc.global_position + off + Vector3(0, 0.3, 0)
					main.walker_out.speed = 0.0
					for i in 4:
						await main.get_tree().process_frame
					var near_d := INF
					for d: Dictionary in jv.doors:
						near_d = minf(near_d, (main.mopo_trip.to_local(main.walker_out.global_position) - d.pos).length()) if d.id == "kolmio_kaverit" else near_d
					print("JUTTU %s etäisyys %.1f m, oven etäisyys %.1f m: vihje '%s' tila %s" % [npc.display_name, off.length(), near_d, main.mopo_trip.hint, main.state])
					if not main.mopo_trip.hint.contains("Juttele Teron ja Timon"):
						print("TESTI VIKA %s %.1f m päässä: vihje '%s' (odotettiin juttelua)" % [npc.display_name, off.length(), main.mopo_trip.hint])
			main.get_tree().quit()
		"vaalakierros":
			# Vaalan liikenneympyrä, tori ja Zabuki: paperikartta keskustasta kahdella zoomilla,
			# sitten vapaa kamera ylhäältä ja tien tasolta kulmissa ja liittymässä.
			main._start_mopo()
			main.mopo_trip.mopo.position = main.mopo_trip.vaala.kmarket_door + Vector3(0, 0.6, 0)
			for i in 10:
				await main.get_tree().process_frame
			main._paper.toggle()
			for vw in [["_kartta.png", Vector2(820, -880), 1.6], ["_kartta_lahella.png", Vector2(815, -900), 3.0], ["_kartta_apteekki.png", Vector2(811, -700), 1.0]]:
				main._paper._vcenter = vw[1]
				main._paper._vzoom = vw[2]
				main._paper._view.queue_redraw()
				main._paper.queue_redraw()
				for i in 3:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", vw[0]))
			main._paper.toggle()
			var vcam := Camera3D.new()
			vcam.far = 3000.0
			main.add_child(vcam)
			var vh := func(x: float, z: float, up: float) -> Vector3:
				return main.mopo_trip.vaala.to_global(Vector3(x, main.mopo_trip.vaala.h(x, z) + up, z))
			for vw in [["_ylhaalta", vh.call(815.0, -900.0, 130.0), vh.call(815.0, -902.0, 0.0)],
					["_ymparyra", vh.call(752.0, -846.0, 5.0), vh.call(826.0, -900.0, 1.0)],
					["_tori", vh.call(838.0, -918.0, 9.0), vh.call(786.0, -934.0, 1.0)],
					["_matkakeskus", vh.call(812.0, -936.0, 2.5), vh.call(774.0, -925.6, 2.5)],
					["_matkakeskus_ylos", vh.call(780.0, -920.0, 80.0), vh.call(780.0, -922.0, 0.0)],
					["_zabuki", vh.call(790.0, -884.0, 2.2), vh.call(784.0, -904.8, 1.8)],
					["_zabuki_parkki", vh.call(766.0, -889.0, 4.0), vh.call(786.0, -898.0, 0.5)],
					["_zabuki_parkki_ylos", vh.call(790.0, -895.0, 75.0), vh.call(790.0, -897.0, 0.0)],
					["_torintie_liittyma", vh.call(826.0, -930.0, 5.0), vh.call(798.0, -935.0, 0.5)],
					["_asemalle", vh.call(840.0, -885.0, 6.0), vh.call(880.0, -830.0, 1.0)],
					["_kunnantalo", vh.call(785.0, -878.0, 2.5), vh.call(802.0, -854.0, 3.0)],
					["_kunnantalo_vino", vh.call(765.0, -880.0, 14.0), vh.call(803.0, -854.0, 2.0)],
					["_kunnantalo_ylos", vh.call(800.0, -860.0, 70.0), vh.call(800.0, -862.0, 0.0)],
					["_alikulku", vh.call(722.0, -730.0, 2.5), vh.call(752.0, -695.0, 3.0)],
					["_alikulku_sivu", vh.call(790.0, -740.0, 18.0), vh.call(750.0, -698.0, 0.0)],
					["_alikulku_alla", vh.call(748.0, -700.0, 1.8), vh.call(778.0, -664.0, 2.0)],
					["_alikulku_ylos", vh.call(752.0, -697.0, 70.0), vh.call(752.0, -699.0, 0.0)],
					["_alikulku_tie", vh.call(733.0, -717.0, 3.0), vh.call(762.0, -684.0, 0.0)],
					["_apteekki", vh.call(838.0, -588.0, 3.0), vh.call(806.0, -616.0, 2.0)],
					["_apteekki_ylos", vh.call(811.0, -610.0, 50.0), vh.call(811.0, -612.0, 0.0)],
					["_kauppatie", vh.call(836.0, -897.0, 4.0), vh.call(925.0, -962.0, 3.0)],
					["_kauppa", vh.call(897.0, -965.0, 3.0), vh.call(919.9, -933.8, 2.5)],
					["_kauppa_ylos", vh.call(915.0, -945.0, 90.0), vh.call(915.0, -947.0, 0.0)],
					["_kauppatie_loppu", vh.call(1000.0, -1030.0, 4.0), vh.call(900.0, -958.0, 3.0)],
					["_torintie", vh.call(818.0, -914.0, 4.0), vh.call(745.0, -1074.0, 4.0)],
					["_kirkko", vh.call(792.0, -975.0, 4.5), vh.call(750.5, -988.4, 5.0)],
					["_kirkko_edesta", vh.call(779.0, -1001.0, 2.0), vh.call(764.6, -995.0, 4.5)],
					["_kirkko_sivu", vh.call(752.0, -1018.0, 4.0), vh.call(750.5, -988.4, 5.0)],
					["_kirkko_hautausmaa", vh.call(738.0, -972.0, 5.0), vh.call(755.0, -980.0, 1.5)],
					["_kirkko_ylos", vh.call(755.0, -988.0, 70.0), vh.call(755.0, -990.0, 0.0)]]:
				vcam.look_at_from_position(vw[1], vw[2], Vector3.UP if vw[0] != "_ylhaalta" else Vector3(0, 0, -1))
				vcam.current = true
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", vw[0] + ".png"))
			main.get_tree().quit()
		"siitarihotelli":
			# Hotelli Siitari omana rakennuksenaan ravintolan takana: _ylhaalta, _edesta (tieltä), _takaa (hotellin ovelta).
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			main.mopo_trip.stop()
			var sc := Vector3(vl.siitari.x, vl.h(vl.siitari.x, vl.siitari.y), vl.siitari.y)
			print("HOTELLI siitari %s ovi %s parkki %s hotellin ovi %s" % [sc, vl.siitari_door, vl.siitari_park, vl.hotel_door])
			var cam := Camera3D.new()
			cam.far = 2000.0
			vl.add_child(cam)
			cam.current = true
			var out: Vector3 = (vl.siitari_door - sc) * Vector3(1, 0, 1)
			out = out.normalized()
			var so: Dictionary = vl._siitari_obb()
			var fr := Vector3(so.front.x, 0, so.front.y)
			var hc := sc - fr * 19.6 + Vector3(0, 5, 0)
			var hd: Vector3 = vl.hotel_door
			var hout := (hd - hc) * Vector3(1, 0, 1)
			hout = hout.normalized()
			for v in [["_ylhaalta", sc + Vector3(0, 70, 0) + out * 10.0, sc - out * 8.0], ["_tielta", sc + fr * 38.0 + Vector3(0, 2.5, 0), hc + Vector3(0, 1, 0)],
					["_ovi", hd + hout * 14.0 + Vector3(0, 2.5, 0), hd + Vector3(0, 2, 0)],
					["_parkki", vl.siitari_park + Vector3(0, 1.7, 0) + out * 2.0, hd + Vector3(0, 3, 0)],
					["_kyltti", sc + fr * 4.0 + Vector3(0, 12, 0), hc + Vector3(0, 9, 0)],
					["_ovikyltti", hd + hout * 5.0 + Vector3(0, 1.7, 0), hd + Vector3(0, 2.4, 0)]]:
				cam.position = v[1]
				cam.look_at(vl.to_global(v[2]), Vector3.UP if v[0] != "_ylhaalta" else -out)
				for i in 30:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", v[0] + ".png"))
			main.get_tree().quit()
		"paivipartio":
			# Päivin partio: kohteiden arvonta ilman juoruja ja kun pelaaja on käynyt SEO:lla, sekä ajo kohteesta toiseen
			# nopeutetulla ajalla (määränpäät, perillä pysähtyminen, ajettu matka).
			main.clock_min = 12 * 60.0
			main._wife_rhythm(main.clock_min)
			var names := {}
			for sp in Main.WIFE_SPOTS:
				names[M.w(sp[1])] = sp[0]
			for case in ["ei juoruja", "pelaaja kävi SEO:lla"]:
				main._wife_rumor.clear()
				if case != "ei juoruja":
					main._wife_rumor["seo"] = main.day * 1440.0 + main.clock_min
				var cnt := {}
				for i in 2000:
					var nm: String = names.get(main._wife_dest(), "?")
					cnt[nm] = cnt.get(nm, 0) + 1
				var parts: Array = []
				for k in cnt:
					parts.append("%s %d %%" % [k, roundi(cnt[k] / 20.0)])
				print("PARTIO %s: %s" % [case, ", ".join(parts)])
			main._wife_rumor.clear()
			if main.player != main.walker_out:
				main._toggle_mount()
			main.walker_out.global_position = main.home_zone + Vector3(0, 0.5, 0)
			main.wife.global_position = M.w(M.J_T) + Vector3(0, 0.5, 0)
			main.wife.reset_to(main.world.nearest_node(M.w(M.J_T)))
			main.wife.safe_zones = [[main.walker_out.global_position, 5000.0]]  # testissä ei jahtia
			Engine.time_scale = 8.0
			var last := Vector3.ZERO
			var seen: Array = []
			var odo := 0.0
			var prev_p: Vector3 = main.wife.global_position
			var stops := 0
			var was_still := false
			for f in 60 * 45:
				await main.get_tree().physics_frame
				odo += Vector2(main.wife.global_position.x - prev_p.x, main.wife.global_position.z - prev_p.z).length()
				var still: bool = main.wife._linger > 0.0
				if still and not was_still:
					stops += 1
					seen.append("%s(%.0f m)" % [names.get(main.wife.arrived, "?"), Vector2(main.wife.global_position.x - main.wife.arrived.x, main.wife.global_position.z - main.wife.arrived.z).length()])
				was_still = still
				prev_p = main.wife.global_position
			Engine.time_scale = 1.0
			print("PARTIO ajo: matka %.0f m, pysähdyksiä %d, perillä: %s, nyt matkalla kohteeseen %s" % [odo, stops, ", ".join(seen), names.get(main.wife.dest, "?")])
			main.get_tree().quit()
			return 2
		"paivihyvitys":
			# Kotihommien hyvitys: nurmikko ja kauppalista antavat hyvityksen, kiinnijääminen kuluttaa yhden ja Päivi
			# päästää (jahti loppuu, hetki armoa), ilman hyvitystä peli päättyy. Tallennus palautetaan.
			var saved_h2 := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.paivi_credit.clear()
			main._paivi_credit_add("nurmikko")
			main._paivi_credit_add("kauppalista")
			print("HYVITYS ansaittu %s" % [main.paivi_credit])
			if main.player != main.walker_out:
				main._toggle_mount()
			main.state = "ulkona"
			main.wife.global_position = main.walker_out.global_position + Vector3(2.0, 0, 0)
			main.wife.mode = "chase"
			main.wife.alerted = true
			for i in 10:
				await main.get_tree().physics_frame
			print("HYVITYS 1: tila %s, jahti %s, armoa %.1f s, jäljellä %s, viesti '%s'" % [main.state, main.wife.mode, main.wife.grace, main.paivi_credit,
				main._msg.text.replace("\n", " | ")])
			await main.get_tree().create_timer(1.0).timeout
			print("HYVITYS armon aikana lähellä: tila %s, jahti %s" % [main.state, main.wife.mode])
			main.wife.grace = 0.0
			main.wife.global_position = main.walker_out.global_position + Vector3(2.0, 0, 0)
			for i in 10:
				await main.get_tree().physics_frame
			print("HYVITYS 2: tila %s, jäljellä %s, viesti '%s'" % [main.state, main.paivi_credit, main._msg.text.replace("\n", " | ")])
			main.wife.grace = 0.0
			main.wife.global_position = main.walker_out.global_position + Vector3(2.0, 0, 0)
			for i in 10:
				await main.get_tree().physics_frame
			print("HYVITYS 3 (ei hyvityksiä): tila %s" % main.state)
			if not saved_h2.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_h2)
			main.get_tree().quit()
			return 2
		"paivihalytys":
			# Päivi koko päivän teillä (ei enää töissä), ja Anna-Liisan hälytyksestä hän ajaa heti kaupalle: nopea ja hidas
			# kauppareissu hälytyksen jälkeen, Päivin etäisyys kaupan ovelta ulos tultaessa ja jahti. Tallennus palautetaan.
			var saved_w := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			for hour in [7.0, 9.0, 12.0, 15.0, 21.0, 23.0]:
				main.clock_min = hour * 60.0
				main._wife_rhythm(main.clock_min)
				print("PAIVI klo %d: vaihe %s, näkyy %s, pysäköity %s, kuski näkyy %s" % [int(hour), main._wife_phase, main.wife.visible, main.wife.parked, main.wife._kuski.visible])
			for wait in [1.5, 12.0]:
				main.clock_min = 12 * 60.0
				main._wife_rhythm(main.clock_min)
				main.wife_alerted = false
				main.wife.alerted = false
				main.wife.reset_to(main.wife.farthest_node_from(main.shop_zone))
				var d0 := Vector2(main.wife.global_position.x - main.shop_door.x, main.wife.global_position.z - main.shop_door.z).length()
				if main.player != main.walker_out:
					main._toggle_mount()
				main.walker_out.global_position = main.shop_door + Vector3(0, 0.3, 1.6)
				for i in 5:
					await main.get_tree().process_frame
				main._enter_shop()
				for i in 10:
					await main.get_tree().process_frame
				main._on_busted()
				await main.get_tree().create_timer(wait).timeout
				main._on_shop_exited(false)
				for i in 30:
					await main.get_tree().physics_frame
				var d1 := Vector2(main.wife.global_position.x - main.shop_door.x, main.wife.global_position.z - main.shop_door.z).length()
				print("PAIVI hälytys, kaupassa %.1f s: alussa %.0f m, ulos tullessa %.0f m, tila %s, tietää %s, viesti '%s'" % [wait, d0, d1,
					main.wife.mode, main.wife.alerted, main._msg.text.replace("\n", " | ")])
			if not saved_w.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_w)
			main.get_tree().quit()
			return 2
		"paivikoti":
			# Päivin auto kotipihassa pelin alussa: paikka suhteessa kotiin ja autotalliin, kuvat ylhäältä ja kadulta.
			for i in 30:
				await main.get_tree().process_frame
			var wp: Vector3 = main.wife.global_position
			print("PAIVI vaihe %s, pysäköity %s, auto %s, koti %s, tallin ovi %s, kello %s" % [main._wife_phase, main.wife.parked, wp, main.home_zone,
				main.world.garage_door, main._clock_text()])
			var cam := main.get_viewport().get_camera_3d()
			var gd: Vector3 = main.world.garage_door
			print("PAIVI tallin suunta %s" % main.world.garage_out)
			for v in [["_ylha", wp + Vector3(0, 28, 6), wp], ["_viisto", wp + Vector3(-10, 6, 12), wp], ["_sivu", wp + Vector3(6, 0.8, 5), wp + Vector3(0, 0.6, 0)], ["_talli", gd + Vector3(0, 22, 4), gd]]:
				for i in 10:
					cam.look_at_from_position(v[1], v[2])
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", v[0] + ".png"))
			main.get_tree().quit()
		"vaala_makasiini":
			# Vaalan makasiini aseman vieressä ulkoa (yltä, kadulta, takaovelta), takaoven vihje ja minipeli luukulta.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			if main.player != main.walker_out:
				main._toggle_mount()
			main._msg.text = ""
			main._note.visible = false
			main.mokki.ensure_built()
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var mr: Node3D = vl.makasiini_root
			print("VAALA makasiini %s, ovi %s, asemalta %.0f m" % [mr.global_position if mr != null else null, vl.makasiini_door,
				vl.makasiini_door.distance_to(vl.station_door)])
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.current = true
			var views := [["_ylla", Vector3(14, 34, 22), Vector3(0, 0, 0)], ["_kadulta", Vector3(6, 3.5, 18), Vector3(0, 2, 0)],
				["_takaovi", Vector3(-13, 2.6, 4), Vector3(-6, 1.6, 1.2)], ["_laituri", Vector3(10, 5, -16), Vector3(0, 2, 0)],
				["_asema", Vector3(-40, 14, 30), Vector3(0, 2, 0)]]
			for v in views:
				cam.look_at_from_position(mr.global_transform * (v[1] as Vector3), mr.global_transform * (v[2] as Vector3))
				for i in 15:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", v[0] + ".png"))
			cam.current = false
			cam.queue_free()
			var md: Vector3 = main.mopo_trip.to_global(vl.makasiini_door)
			if main.mopo_trip.on_foot == null:
				main._mopo_dismount()
			main.mopo_trip.on_foot.global_position = md + Vector3(0, 0.5, 0)
			main.mopo_trip.on_foot.activate_camera()
			for i in 15:
				await main.get_tree().process_frame
			print("VAALA makasiinilla vihje '%s'" % main.mopo_trip.hint)
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_ovella.png"))
			main._on_vaala_door("makasiini")
			for i in 200:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_luukku.png"))
			main._rasva_game._done(true)
			for i in 10:
				await main.get_tree().process_frame
			print("VAALA rasvanappi viesti '%s', tila %s, jalan %s" % [main._msg.text, main.state, main.mopo_trip.on_foot != null])
			var f := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f.store_buffer(saved)
			f.close()
			main.get_tree().quit()
		"vaalakoodi":
			# Huijauskoodi: "vaala" kotipihalla vie Vaalaan Gasthausin pihaan seuraavaan aamuun, mopo pihassa.
			var d0 := main.day
			for c in Main.CHEAT_VAALA:
				var ev := InputEventKey.new()
				ev.pressed = true
				ev.keycode = OS.find_keycode_from_string(c.to_upper())
				ev.unicode = c.unicode_at(0)
				Input.parse_input_event(ev)
				await main.get_tree().process_frame
				var up := ev.duplicate()
				up.pressed = false
				Input.parse_input_event(up)
				await main.get_tree().process_frame
			for i in 30:
				await main.get_tree().process_frame
			var vl: Node3D = main.mopo_trip.vaala if main.mopo_trip != null else null
			for i in 60:
				await main.get_tree().physics_frame
			print("KOODI vaala: päivä %d -> %d, Vaalassa %s, mopo Gasthausilta %.1f m, maasta %.2f m, viesti '%s'" % [d0, main.day, main._in_vaala,
				main.mopo_trip.mopo.position.distance_to(vl.door_pos("gasthaus")) if vl != null else -1.0,
				main.mopo_trip.mopo.position.y - vl.h(main.mopo_trip.mopo.position.x, main.mopo_trip.mopo.position.z) if vl != null else -99.0, main._msg.text])
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path)
		"paivin_puhelu":
			# Päivi soittaa aamulla Vaalaan (cutscene.wasted_phone): käden ja puhelimen asento edestä, oikealta ja ylhäältä
			# kesken puhelun; kuvat _edesta, _oikealta, _ylhaalta ja _lahikuva.
			var saved_pu := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			var wake_pu := main.player.global_position
			var face_pu := Vector3(0, 0, -1)
			main.cutscene.wasted_phone(wake_pu, "Testi", "train", wake_pu, face_pu, "Gasthaus", func() -> void: pass)
			var pu_t0 := Time.get_ticks_msec()
			while not main.cutscene._sub.text.begins_with("Päivi puhelimessa") and Time.get_ticks_msec() - pu_t0 < 40000:
				await main.get_tree().process_frame
			await main.get_tree().create_timer(0.8, true, false, true).timeout
			var hh := wake_pu + Vector3(0, 1.55, 0)
			var views_pu := [["_edesta", hh + Vector3(0, 0, -1.5), hh], ["_oikealta", hh + Vector3(1.5, 0, 0), hh],
				["_ylhaalta", hh + Vector3(0.0, 1.5, -0.05), hh], ["_lahikuva", hh + Vector3(0.9, 0.1, -0.7), hh + Vector3(0.1, -0.05, 0)]]
			for vw in views_pu:
				main.cutscene._cam.global_position = vw[1]
				main.cutscene._cam.look_at(vw[2], Vector3.UP if vw[0] != "_ylhaalta" else Vector3(0, 0, -1))
				for i in 3:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", vw[0] + ".png"))
			if not saved_pu.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_pu)
		_:
			return 0
	return 1
