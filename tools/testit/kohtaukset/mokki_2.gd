extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "mokki_2". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const ShopInterior := preload("res://scripts/shop_interior.gd")
const Mokki := preload("res://scripts/mokki.gd")
const PingisGame := preload("res://scripts/pingis_game.gd")
const PaGame := preload("res://scripts/pa_game.gd")
const DartsGame := preload("res://scripts/darts_game.gd")
const Looks := preload("res://scripts/looks.gd")
const Cutscene := preload("res://scripts/cutscene.gd")
const WcGame := preload("res://scripts/wc_game.gd")

const KOHTAUKSET := ["mokkisiitaritappelu", "mokkisiitari", "mokkivaalajalan", "mokkivaalalava", "mokkivaalakartta", "mokkivaalakesk", "mokkiperf", "mokkivaalaperf", "mokkitori", "mokkivaala", "mokkimopo_koko", "mokkireitti", "mokkiratasilta", "mokkisiitariovi", "mokkiratsia", "mokkinuoret", "mokkirakaleima", "mokkitynnyri", "mokkiuinti", "mokkisalminen", "mokkiuinti_mopo", "mokkiranta_vaala", "mokkimopo_jarviseutu", "mokkimopo_paluu", "mokkimopo_silta", "mokkimopo_kanni", "mokkiviina", "mokkivessa", "mokkivaalatiet", "mokkisanttulava", "mokkipohjoinen", "mokkimopo", "mokkiview", "mokkisauna", "mokkiyard", "mokkilake", "mokkipingis", "mokkitikka", "mokkisavustus", "mokkipesuovi", "mokkisisalla", "mokkipa", "mokkipuuhat", "mokkisavusauna"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"mokkisiitaritappelu":
			# Lauantai Siitarissa: Raahen jätkät pajatsolla, riita, Street Fighter -tappelu pihalla ja voittajan kalja.
			var _save_bak := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.day = 6  # lauantai
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
			print("RAAHE %s: jätkät paikalla %s (%d)" % [Main.WEEKDAYS[main._weekday()], main.siitari_int.raahe_on, main.siitari_int._raahe.size()])
			main.siitari_int.walker.position = main.siitari_int.spots.pajatso[0] + Vector3(0, 0, 0.6)
			for i in 5:
				await main.get_tree().process_frame
			print("RAAHE vihje '%s'" % main._hint.text)
			await snap.call("_pajatso.png")
			main._on_siitari_acted("pajatso")
			print("RAAHE valikko auki %s, %s" % [main._item_menu.is_open(), main._item_menu._items])
			await snap.call("_riita.png", 10)
			main._item_menu.visible = false
			main._item_menu.chosen.emit("tappele")
			print("RAAHE tila %s" % main.state)
			await snap.call("_tappelu.png", 90)
			main.fight._j.hp = 0.0
			main.fight._j.state = "ko"
			var tw := Time.get_ticks_msec()
			while main.state == "fight" and Time.get_ticks_msec() - tw < 20000:
				await main.get_tree().process_frame
			print("RAAHE tappelun jälkeen: tila %s, jätkät %s, viesti '%s'" % [main.state, main.siitari_int.raahe_on, main._msg.text])
			await snap.call("_voitto.png")
			var _sf := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			_sf.store_buffer(_save_bak)
			_sf.close()
			main.get_tree().quit()
		"mokkisiitari":
			# Siitari sisältä: _1 yleiskuva, _2 tanssi Sinikan kanssa, _3 karaoke kesken, _4 Päivin puhelu.
			main._start_mopo()
			var mp: CharacterBody3D = main.mopo_trip.mopo
			mp.position = main.mopo_trip.vaala.siitari_park + Vector3(0, 0.5, 0)
			for i in 10:
				await main.get_tree().physics_frame
			main.mopo_trip.stop()
			main._on_mopo_arrived()
			main.money = 30.0
			main.tilat.add("humala", 0.3)
			var snap := func(name: String) -> void:
				for i in 30:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main.siitari_int.walker.position = Vector3(0.5, 0, 1.0)
			await snap.call("_1.png")
			print("SIITARI tila %s hint '%s'" % [main.state, main._hint.text])
			main.siitari_int.walker.position = main.siitari_int.spots.sinikka[0]
			for i in 5:
				await main.get_tree().process_frame
			print("SIITARI Sinikan luona hint '%s'" % main._hint.text)
			main._on_siitari_acted("sinikka")
			print("SIITARI ikkuna auki %s valinnat %s" % [main._talk_box.is_open(), str(main._talk_box._options.map(func(o): return o.text))])
			main._test_talk(["tanssi"])
			await snap.call("_2.png")
			await main.get_tree().create_timer(7.5).timeout
			print("SIITARI tanssi ohi: ohjaus %s, puhelu %.1f s" % [main.siitari_int.walker.controls_enabled, main._paivi_call_t])
			main.siitari_int.walker.position = main.siitari_int.spots.karaoke[0]
			main._on_siitari_acted("karaoke")
			main._karaoke_game()._choose(0)  # oma kappale
			Input.action_press("forward")
			await main.get_tree().create_timer(4.0).timeout
			Input.action_release("forward")
			await snap.call("_3.png")
			await main.get_tree().create_timer(26.0).timeout
			print("SIITARI karaoke ohi, viesti: %s | rahaa %.2f" % [main._msg.text, main.money])
			await main.get_tree().create_timer(4.5).timeout
			await snap.call("_4.png")
			print("SIITARI viesti: %s" % main._msg.text)
			main.siitari_int.walker.position = main.siitari_int.spots.ovi[0]
			for i in 5:
				await main.get_tree().process_frame
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			for i in 30:
				await main.get_tree().physics_frame
			print("SIITARI ulos: tila %s, mopo kohde %s aktiivinen %s" % [main.state, main.mopo_trip.target, main.mopo_trip.active])
			main.get_tree().quit()
		"mokkivaalajalan":
			# Moposta jalan (F) lavan pihassa, kävely ovelle (vihje), rantaan (ei veteen), takaisin mopolle ja selkään.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			var mp: CharacterBody3D = main.mopo_trip.mopo
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
			var press := func(action: String) -> void:
				await main.get_tree().process_frame  # painallus ennen solmujen _processia (just_pressed samassa ruudussa)
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			mp.position = vl.lava_door + vl.lava_out * 12.0 + Vector3(0, 0.6, 0)
			mp.rotation.y = atan2(vl.lava_out.x, vl.lava_out.z)  # selkä ovelle päin
			for i in 20:
				await main.get_tree().physics_frame
			await press.call("mount")
			print("JALAN: kävelijä %s, näkyvissä %s, kuski mopolla %s, status '%s'" % [main.mopo_trip.on_foot != null, main.walker_out.visible,
				mp._rider.visible, main.mopo_trip.status.replace("\n", " | ")])
			var walk_to := func(goal_local: Vector3, secs: float) -> void:
				Input.action_press("forward")
				for i in int(60 * secs):
					await main.get_tree().physics_frame
					var g: Vector3 = main.mopo_trip.to_global(goal_local)
					var want := Vector3(g.x - main.walker_out.global_position.x, 0, g.z - main.walker_out.global_position.z)
					if want.length() < 1.2:
						break
					var err := (-main.walker_out.global_transform.basis.z).signed_angle_to(want, Vector3.UP)
					Input.action_press("left", clampf(err * 3.0, 0.0, 1.0))
					Input.action_press("right", clampf(-err * 3.0, 0.0, 1.0))
				for a in ["forward", "left", "right"]:
					Input.action_release(a)
				for i in 10:
					await main.get_tree().process_frame
			await walk_to.call(vl.lava_door, 12.0)
			print("JALAN ovella: %.1f m, vihje '%s'" % [main.mopo_trip.to_local(main.walker_out.global_position).distance_to(vl.lava_door), main._hint.text])
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_ovi.png"))
			main.money = 50.0
			await press.call("interact")
			print("JALAN lavalle: tila %s, kävelijä näkyvissä %s, viesti %s" % [main.state, main.walker_out.visible, main._msg.text])
			if main._lava_game != null:
				main._lava_game.finished.emit(0.5)
				for i in 5:
					await main.get_tree().process_frame
			print("JALAN lavalta: tila %s, kävelijä näkyvissä %s, ohjaus %s, mopo ohjaus %s" % [main.state, main.walker_out.visible,
				main.walker_out.controls_enabled, mp.controls_enabled])
			# Rantaan: ensimmäinen vesi lavan etelänpuolella, kävelijä 4 m rannasta kohti vettä.
			var shore: Vector3 = vl.lava_center
			while vl.h(shore.x, shore.z) > vl.water_level - 0.3:
				shore.z += 1.0
			main.walker_out.global_position = main.mopo_trip.to_global(shore + Vector3(0, 0, -6))
			main.walker_out.global_position.y = main.mopo_trip.to_global(Vector3(0, vl.h(shore.x, shore.z - 6.0) + 0.4, 0)).y
			await walk_to.call(shore + Vector3(0, 0, 20), 6.0)
			var lp: Vector3 = main.mopo_trip.to_local(main.walker_out.global_position)
			print("JALAN rannassa: maa %.2f, vedenpinta %.2f, vihje '%s'" % [vl.h(lp.x, lp.z), vl.water_level, main._hint.text])
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_ranta.png"))
			main.walker_out.global_position = mp.global_position + Vector3(4, 0.3, 0)
			await walk_to.call(mp.position, 5.0)
			print("JALAN mopolla: %.1f m, vihje '%s'" % [main.walker_out.global_position.distance_to(mp.global_position), main._hint.text])
			await press.call("mount")
			print("SELKÄÄN: kävelijä %s, ohjaus %s, näkyvissä %s, kuski mopolla %s" % [main.mopo_trip.on_foot != null, mp.controls_enabled,
				main.walker_out.visible, mp._rider.visible])
			main.get_tree().quit()
		"mokkivaalalava":
			# Oulujärven lava niemen kärjessä: _yla ylhäältä (joki ja järvi), _tie Vuolijoentieltä, _aita aita rannasta
			# rantaan, _ranta järveltä päin, _ovi ovelta.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			main._msg.text = ""
			var oc := Camera3D.new()
			oc.far = 3000.0
			oc.fov = 62.0
			main.add_child(oc)
			var c: Vector3 = vl.lava_center
			var snap := func(name: String, from: Vector3, to: Vector3) -> void:
				oc.look_at_from_position(main.mopo_trip.to_global(from), main.mopo_trip.to_global(to))
				oc.current = true
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var lv: Dictionary = vl.data.lava
			var rp: Array = lv.road
			var junc := Vector3(rp[0][0], 0, rp[0][1])
			junc.y = vl.h(junc.x, junc.z)
			await snap.call("_yla.png", c + Vector3(-60, 260, 160), c + Vector3(30, 0, -60))
			await snap.call("_tie.png", junc + Vector3(-4, 3, 0), c + Vector3(0, 2, 0))
			await snap.call("_aita.png", c + Vector3(-70, 25, -70), c + Vector3(0, 0, -10))
			await snap.call("_ranta.png", c + Vector3(20, 6, 120), c)
			await snap.call("_ovi.png", vl.lava_door + vl.lava_out * 20.0 + Vector3(0, 3, 12), vl.lava_door + Vector3(0, 1.5, 0))
			var gt := Vector3(lv.gate[0], 0, lv.gate[1])
			gt.y = vl.h(gt.x, gt.z)
			await snap.call("_portti.png", gt + Vector3(-6, 2.5, -22), gt + Vector3(0, 1, 0))
			await snap.call("_pihat.png", c + Vector3(10, 120, 1), c + Vector3(10, 0, 0))
			var fw: Array = lv.fence[2]
			var fe: Array = lv.fence[0]
			await snap.call("_lansi.png", Vector3(fw[0] - 40, vl.water_level + 5, fw[1] - 25), Vector3(fw[0], vl.water_level, fw[1] - 10))
			await snap.call("_ita.png", Vector3(fe[0] + 30, vl.water_level + 4, fe[1] - 35), Vector3(fe[0] - 5, vl.water_level, fe[1]))
			await snap.call("_joki.png", c + Vector3(150, 40, -300), c + Vector3(80, 0, 100))
			# Mopolla Pahalahdentieltä portista lavan ovelle, sitten aitaa päin portin vierestä (aidan pitää pysäyttää).
			var mp: CharacterBody3D = main.mopo_trip.mopo
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
			var drive := func(from: Vector3, goals: Array, secs: float) -> void:
				mp.position = from + Vector3(0, 0.6, 0)
				var d0: Vector3 = (goals[0] - from).normalized()
				mp.rotation.y = atan2(-d0.x, -d0.z)
				mp.speed = 4.0
				mp.activate_camera()
				var gi := 0
				Input.action_press("forward", 0.6)
				for i in int(60 * secs):
					await main.get_tree().physics_frame
					var goal: Vector3 = goals[gi]
					var gd := Vector2(mp.position.x - goal.x, mp.position.z - goal.z).length()
					if gi < goals.size() - 1 and gd < 4.0:
						gi += 1
						goal = goals[gi]
						gd = Vector2(mp.position.x - goal.x, mp.position.z - goal.z).length()
					elif gi == goals.size() - 1 and gd < 4.0:
						break  # perillä: jarrutetaan
					if gi == goals.size() - 1 and gd < 12.0:
						# Loppumatka hiljaa: jarru päälle, jos vauhtia on yli 3 m/s.
						if mp.speed > 3.0:
							Input.action_press("brake")
						else:
							Input.action_release("brake")

					var want := Vector3(goal.x - mp.position.x, 0, goal.z - mp.position.z)
					var err := (-mp.global_transform.basis.z).signed_angle_to(want, Vector3.UP)
					Input.action_press("left", clampf(err * 3.0, 0.0, 1.0))
					Input.action_press("right", clampf(-err * 3.0, 0.0, 1.0))
				for a in ["forward", "left", "right"]:
					Input.action_release(a)
				Input.action_press("brake")
				for i in 40:
					await main.get_tree().physics_frame
				Input.action_release("brake")
			# Pahalahdentie: 30 m ennen porttia, portin läpi, ajotien alkuun ja ovelle.
			var pr: Array = []
			for r in vl.data.side_roads:
				if r.get("name", "") == "Pahalahdentie":
					for q in r.pts:
						pr.append(Vector3(q[0], vl.h(q[0], q[1]), q[1]))
			var gk := 0
			for k in pr.size():
				if pr[k].distance_to(gt) < pr[gk].distance_to(gt):
					gk = k
			var rp0: Vector3 = Vector3(rp[0][0], 0, rp[0][1])
			await drive.call(pr[maxi(gk - 5, 0)], pr.slice(gk - 3) + [rp0, vl.lava_door + vl.lava_out * 2.0], 30.0)
			for i in 30:
				await main.get_tree().physics_frame
			print("LAVA portista: ovelta %.1f m, vihje '%s'" % [mp.position.distance_to(vl.lava_door), main.mopo_trip.hint])
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_mopo.png"))
			# Aitaa päin 8 m portista itään (pohjoisesta etelään).
			var beside := gt + Vector3(8, 0, 0)
			beside.y = vl.h(beside.x, beside.z)
			await drive.call(beside + Vector3(0, 0, -6), [beside + Vector3(0, 0, 20)], 5.0)
			print("LAVA aitaa päin: aidan pohjoispuolella %.1f m (negatiivinen = läpi)" % (beside.z - mp.position.z))
			main.get_tree().quit()
		"mokkivaalakartta":
			# Neittävä–Vaala-kartta (M): ensin mökillä jalan Salmisen uimarannalla (_jalan), sitten mopolla lavan luona:
			# koko alue, keskusta lähempää, lava ja mökin piha.
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.gpos(main.mokki.beach_pos + Vector3(0, 1.0, 3.0))
			for i in 5:
				await main.get_tree().process_frame
			main._paper.toggle()
			for i in 12:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_jalan.png"))
			main._paper.toggle()
			main._start_mopo()
			main.mopo_trip.mopo.position = main.mopo_trip.vaala.lava_door + Vector3(0, 0.6, 0)
			for i in 10:
				await main.get_tree().process_frame
			main._paper.toggle()
			var views := [["_koko.png", Vector2.ZERO, 0.0], ["_keskusta.png", Vector2(800, -900), 1.0],
				["_lava.png", Vector2(660, -270), 2.0], ["_mokki.png", Vector2(0, 0), 2.5], ["_neittava.png", Vector2(-120, -560), 0.7]]
			for vw in views:
				if vw[2] > 0.0:
					main._paper._vcenter = vw[1]
					main._paper._vzoom = vw[2]
				main._paper._view.queue_redraw()
				main._paper.queue_redraw()
				for i in 3:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", vw[0]))
			main._paper.toggle()
		"mokkivaalakesk":
			# Vaalan keskusta Siitarin ympäriltä: _y ylhäältä, _n/_e/_s/_w 45 m päästä viistosti, _tie Vaalantieltä,
			# _ovi Siitarin ovelta ja _kauppa K-Marketin edestä (automaatti).
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			main._msg.text = ""
			var oc := Camera3D.new()
			oc.far = 3000.0
			oc.fov = 62.0
			main.add_child(oc)
			var snap := func(name: String, from: Vector3, to: Vector3) -> void:
				oc.look_at_from_position(main.mopo_trip.to_global(from), main.mopo_trip.to_global(to))
				oc.current = true
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var sc := Vector3(vl.siitari.x, vl.siitari_door.y, vl.siitari.y)
			await snap.call("_y.png", sc + Vector3(0, 140, 60), sc)
			for d in [["_n", Vector3(0, 0, -1)], ["_e", Vector3(1, 0, 0)], ["_s", Vector3(0, 0, 1)], ["_w", Vector3(-1, 0, 0)]]:
				await snap.call(d[0] + ".png", sc + d[1] * 45.0 + Vector3(0, 18, 0), sc + Vector3(0, 2, 0))
			var ni: int = vl.nearest(sc)[0]
			await snap.call("_tie.png", vl.road_pos(ni - 15) + Vector3(0, 1.7, 0), vl.road_pos(ni + 5) + Vector3(0, 1.5, 0))
			await snap.call("_tie2.png", vl.road_pos(ni + 15) + Vector3(0, 1.7, 0), vl.road_pos(ni - 5) + Vector3(0, 1.5, 0))
			var so: Vector3 = Vector3(sin(vl.siitari_yaw), 0, cos(vl.siitari_yaw))
			await snap.call("_ovi.png", vl.siitari_door + so * 14.0 + Vector3(0, 2.5, 0), vl.siitari_door + Vector3(0, 1.5, 0))
			if vl.kmarket_door != Vector3.ZERO:
				await snap.call("_kauppa.png", vl.kmarket_door + vl.kmarket_out * 16.0 + Vector3(0, 4, 0), vl.kmarket_door)
				await snap.call("_otto.png", vl.atm_pos + vl.kmarket_face * 3.0 + Vector3(0, 1.6, 0), vl.atm_pos + Vector3(0, 1.3, 0) - vl.kmarket_face * 1.2)
				await snap.call("_otto_kaukaa.png", (vl.atm_pos + vl.kmarket_door) / 2.0 + vl.kmarket_face * 22.0 + Vector3(0, 4.0, 0), (vl.atm_pos + vl.kmarket_door) / 2.0 + Vector3(0, 1.0, 0))
				await snap.call("_valilla.png", vl.kmarket_door + Vector3(0, 30, 0) + (sc - vl.kmarket_door) * -0.3,
					(sc + vl.kmarket_door) / 2.0)
			print("VAALAKESK siitari %s kauppa %s automaatti %s, väli %.0f m" % [sc, vl.kmarket_door, vl.atm_pos,
				Vector2(sc.x - vl.kmarket_door.x, sc.z - vl.kmarket_door.z).length()])
			main.get_tree().quit()
		"mokkiperf":
			# Suorituskyky mökillä: pelaajan kamera 5 kohdassa (piha, Salmisen ranta, Ranta-Rosvo, laavu, laituri).
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			main._toggle_mount()
			main._msg.text = ""
			main._note.visible = false
			var tot := 0.0
			var spots := [["piha", main.mokki.porch_pos(3.0)], ["ranta", main.mokki.to_global(main.mokki.beach_pos)], ["rosvo", main.mokki.to_global(main.mokki.rosvo_pos)],
				["laavu", main.mokki.to_global(main.mokki.laavu_fire)], ["laituri", main.mokki.to_global(main.mokki.north_dock)]]
			for sp in spots:
				main.walker_out.global_position = sp[1] + Vector3(0, 0.5, 0)
				for f in 40:
					await main.get_tree().process_frame
				var t0 := Time.get_ticks_usec()
				for f in 60:
					await main.get_tree().process_frame
				var fps := 60.0 / ((Time.get_ticks_usec() - t0) / 1e6)
				tot += fps
				print("PERF %s: %.0f fps, piirtoja %d, kolmioita %dk" % [sp[0], fps,
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
			print("PERF keskiarvo %.0f fps" % (tot / spots.size()))
			main.get_tree().quit()
		"mokkivaalaperf":
			# Suorituskyky Vaalan reitillä: kamera mopon takana 8 kohdassa, FPS (ilman vsynciä), piirtokutsut ja kolmiot.
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			var mp: CharacterBody3D = main.mopo_trip.mopo
			main._msg.text = ""
			var tot := 0.0
			var n_rd: int = vl.road.size()
			for k in 8:
				var i: int = clampi(int(float(k) / 7.0 * (n_rd - 20)) + 10, 5, n_rd - 6)
				var d: Vector3 = vl.road_dir(i)
				mp.position = vl.road_pos(i) + Vector3(0, 0.6, 0)
				mp.rotation.y = atan2(-d.x, -d.z)
				mp.speed = 0.0
				for f in 40:
					await main.get_tree().process_frame
				var t0 := Time.get_ticks_usec()
				for f in 60:
					await main.get_tree().process_frame
				var fps := 60.0 / ((Time.get_ticks_usec() - t0) / 1e6)
				tot += fps
				print("PERF %d näyte %d %s: %.0f fps, piirtoja %d, kolmioita %dk" % [k, i, vl.road_names[i], fps,
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%d.png" % k))
			print("PERF keskiarvo %.0f fps" % (tot / 8.0))
			# Erittely: kunkin metsätason ja varjojen osuus kolmioista ja piirroista samassa kohdassa.
			var measure := func(tag: String) -> void:
				for f in 30:
					await main.get_tree().process_frame
				print("PERF %s: piirtoja %d, kolmioita %dk" % [tag,
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
			var i0: int = n_rd / 3
			var d0: Vector3 = vl.road_dir(i0)
			mp.position = vl.road_pos(i0) + Vector3(0, 0.6, 0)
			mp.rotation.y = atan2(-d0.x, -d0.z)
			for f in 120:
				await main.get_tree().process_frame
			var fr: Node3D = null
			for c in vl.get_children():
				if c is Node3D and c.get_script() == load("res://scripts/forest.gd"):
					fr = c
			var lvl := {}
			for k in fr._built:
				var arr: Array = fr._built[k]
				for ii in arr.size():
					lvl[arr[ii]] = "lähi" if ii % 2 == 0 else "keski"
			for c in fr.get_children():
				if c is MultiMeshInstance3D and not lvl.has(c):
					lvl[c] = "kauko"
			await measure.call("kaikki")
			for t in ["lähi", "keski", "kauko"]:
				for c in lvl:
					c.visible = lvl[c] != t
				await measure.call("ilman tasoa " + t)
				for c in lvl:
					c.visible = true
			fr.visible = false
			await measure.call("ilman metsää")
			main._sun.shadow_enabled = false
			await measure.call("ilman metsää ja varjoja")
			fr.visible = true
			await measure.call("metsä ilman varjoja")
		"mokkitori":
			# Vaalan tori (Zabuki, Gasthaus) ylhäältä ja viistosti, sekä ovivihjeet jalan.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			main._msg.text = ""
			var oc := Camera3D.new()
			oc.far = 3000.0
			main.add_child(oc)
			var g := func(v: Vector3) -> Vector3: return main.mopo_trip.to_global(v)
			var snap := func(name: String, from: Vector3, to: Vector3) -> void:
				oc.look_at_from_position(g.call(from), g.call(to), Vector3.FORWARD if from.x == to.x and from.z == to.z else Vector3.UP)
				oc.current = true
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var tc := Vector3(vl._tori_c.x, 0, vl._tori_c.y)
			tc.y = vl.h(tc.x, tc.z)
			var sc := Vector3(vl.siitari.x, 0, vl.siitari.y)
			sc.y = vl.h(sc.x, sc.z)
			await snap.call("_siitari_tori.png", sc + (sc - tc).normalized() * 45.0 + Vector3(0, 28, 0), (sc + tc) / 2.0)
			await snap.call("_tie_tori.png", vl.road_pos(vl.nearest(sc)[0] - 25) + Vector3(0, 1.8, 0), tc + Vector3(0, 1.0, 0))
			await snap.call("_tori_ylh.png", tc + Vector3(0, 90, 0), tc)
			await snap.call("_tori_viisto.png", tc + Vector3(-35, 22, 30), tc)
			for d in vl.doors:
				var dp: Vector3 = d.pos
				var out: Vector3 = d.out
				await snap.call("_ovi_%s.png" % d.id, dp + out * 14.0 + Vector3(0, 5, 0), dp + Vector3(0, 1.5, 0))
				main.mopo_trip.mopo.position = dp + Vector3(0, 0.6, 0)
				main.mopo_trip.mopo.speed = 0.0
				for i in 6:
					await main.get_tree().physics_frame
				print("TORI ovi %s %s vihje: '%s'" % [d.id, dp, main.mopo_trip.hint])
			main.money = 40.0
			var n0: float = main.tilat.value("nalka")
			main._on_vaala_door("zabuki")
			print("TORI zabuki auki %s valinnat %s" % [main._talk_box.is_open(), str(main._talk_box._options.map(func(o): return o.text))])
			main._test_talk(["osta_tupla", "osta_tuoppi"])
			print("TORI zabuki: rahaa %.2f, nälkä %.2f -> %.2f" % [main.money, n0, main.tilat.value("nalka")])
			main._on_vaala_door("kmarket")
			print("TORI kmarket: tila %s, alko %s" % [main.state, main.interior._alko.visible])
			main.interior.walker.position = ShopInterior.ENTRY
			main._on_vaala_shop_exited(false)
			print("TORI kaupasta ulos: tila %s" % main.state)
			var d0 := main.day
			main._on_vaala_door("gasthaus")
			main._test_talk(["yo"])
			for i in 10:
				await main.get_tree().process_frame
			print("TORI gasthaus: päivä %d -> %d, rahaa %.2f, vaalassa %s, kohde %s, mopo %s (ovi %s)" % [d0, main.day, main.money, main._in_vaala,
				main.mopo_trip.target, main.mopo_trip.mopo.position, vl.door_pos("gasthaus")])
			await snap.call("_aamu.png", main.mopo_trip.mopo.position + Vector3(0, 3, 6), main.mopo_trip.mopo.position)
		"mokkivaala":
			# Vaalan kohteet kuviksi (_ali1 alikulku lähestyttäessä, _ali2 sivulta, _ali3 mopo alikulussa, _ris
			# Vuolijoentien risteys, _kesk keskusta ylhäältä, _kirkko, _asema, _talot omakotitaloja läheltä).
			main._start_mopo()
			var mp: CharacterBody3D = main.mopo_trip.mopo
			var vl: Node3D = main.mopo_trip.vaala
			main._msg.text = ""
			var oc := Camera3D.new()
			oc.far = 3000.0
			oc.fov = 62.0
			main.add_child(oc)
			var g := func(v: Vector3) -> Vector3: return main.mopo_trip.to_global(v)
			var snap := func(name: String, from: Vector3, to: Vector3) -> void:
				oc.look_at_from_position(g.call(from), g.call(to))
				oc.current = true
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			for car in main.mopo_trip._cars:  # kuvat ilman liikennettä
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var ui: int = vl.underpass_i
			var up: Vector3 = vl.road_pos(ui)
			var ud: Vector3 = vl.road_dir(ui)
			var ur := ud.cross(Vector3.UP)
			await snap.call("_ali1.png", vl.road_pos(ui - 25) + Vector3(0, 2.2, 0) + ur * 1.6, up + Vector3(0, 2.5, 0))
			await snap.call("_ali5.png", vl.road_pos(ui + 25) + Vector3(0, 2.2, 0) - ur * 1.6, up + Vector3(0, 2.5, 0))
			await snap.call("_ali2.png", up + ur * 40.0 - ud * 25.0 + Vector3(0, 14, 0), up + Vector3(0, 2, 0))
			await snap.call("_ali4.png", up + Vector3(0, 3.0, 0) - ud * 0.5, up + ud * 0.5)
			mp.position = vl.road_pos(ui - 4) + Vector3(0, 0.6, 0) + ur * 1.6
			mp.rotation.y = atan2(-ud.x, -ud.z)
			mp.speed = 8.0
			for i in 40:
				await main.get_tree().physics_frame
			print("VAALA alikulussa: y %.2f tie %.2f, nopeus %.1f, näyte %d (alikulku %d)" % [mp.position.y, vl.h(mp.position.x, mp.position.z),
				mp.speed * 3.6, vl.nearest(mp.position)[0], ui])
			mp.activate_camera()
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_ali3.png"))
			# Oulujoen silta: sivulta, ylhäältä ja ajajan silmin molempiin suuntiin.
			var br: Array = vl.data.bridges[vl.data.bridges.size() - 1]
			var bm: Vector3 = (vl.road_pos(br[0]) + vl.road_pos(br[1])) / 2.0
			var bdir: Vector3 = vl.road_dir((br[0] + br[1]) / 2)
			var bn := bdir.cross(Vector3.UP)
			await snap.call("_silta_sivu.png", bm + bn * 70.0 + Vector3(0, 6, 0), bm)
			await snap.call("_silta_ylha.png", bm + Vector3(0, 90, 1), bm)
			await snap.call("_silta_tulo.png", vl.road_pos(br[0] - 30) + Vector3(0, 1.8, 0) + vl.road_dir(br[0] - 30).cross(Vector3.UP) * 1.6, vl.road_pos(br[0] + 10) + Vector3(0, 1.6, 0))
			await snap.call("_silta_paalla.png", vl.road_pos(br[0] + 4) + Vector3(0, 1.8, 0), vl.road_pos(br[1]) + Vector3(0, 1.5, 0))
			await snap.call("_jarvi.png", bm + Vector3(-60, 40, 60), bm + Vector3(-900, 0, -1200))
			var js: int = vl.data.signs[2].i
			await snap.call("_ris.png", vl.road_pos(js - 30) + Vector3(0, 30, 0), vl.road_pos(js + 5))
			var sc := Vector3(vl.siitari.x, vl.siitari_door.y, vl.siitari.y)
			await snap.call("_kesk.png", sc + Vector3(-160, 120, 160), sc + Vector3(40, 0, -40))
			for bd in vl.data.buildings:
				var nm: String = bd.name
				if nm.contains("kirkko") or bd.type == "train_station":
					var c := Vector2.ZERO
					for q in bd.pts:
						c += Vector2(q[0], q[1])
					c /= bd.pts.size()
					var cy: float = vl.h(c.x, c.y)
					await snap.call("_kirkko.png" if nm.contains("kirkko") else "_asema.png", Vector3(c.x + 35, cy + 14, c.y + 35), Vector3(c.x, cy + 6, c.y))
			var shots_done := {}
			for bd in vl.data.buildings:
				var key: String = bd.kind if bd.kind != "big" else "big%d" % (absi(int(bd.id)) % 3)
				if shots_done.has(key) or key == "shed" or bd.name != "":
					continue
				shots_done[key] = true
				var c := Vector2.ZERO
				for q in bd.pts:
					c += Vector2(q[0], q[1])
				c /= bd.pts.size()
				var cy: float = vl.h(c.x, c.y)
				await snap.call("_lahi_%s.png" % key, Vector3(c.x + 9, cy + 4, c.y + 9), Vector3(c.x, cy + 2.5, c.y))
			var hi: int = vl.nearest(sc)[0] - 60
			await snap.call("_talot.png", vl.road_pos(hi) + Vector3(0, 3, 0), vl.road_pos(hi + 20) + Vector3(0, 2, 0))
			main.get_tree().quit()
		"mokkimopo_koko":
			# Koko reitti mökiltä Siitariin täysillä oikealla kaistalla (ilman liikennettä): pysähdykset ja seinäosumat.
			main.tilat.add("humala", -1.0)
			main._start_mopo()
			var mp: CharacterBody3D = main.mopo_trip.mopo
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var crashes := [0]
			main.mopo_trip.crashed.connect(func(r: String) -> void:
				crashes[0] += 1
				print("KOKO kumoon (%s) näyte %d" % [r, vl.nearest(mp.position)[0]]))
			var si := 12
			var d: Vector3 = vl.road_dir(si)
			mp.position = vl.road_pos(si) + Vector3(0, 0.6, 0) + d.cross(Vector3.UP) * 1.6
			mp.rotation.y = atan2(-d.x, -d.z)
			Input.action_press("forward")
			var last := si
			var slow := 0
			var walls := {}
			var t0 := Time.get_ticks_msec()
			for i in 60 * 400:
				await main.get_tree().physics_frame
				var ni: Array = vl.nearest(mp.position)
				if ni[0] >= 0:
					last = maxi(last, ni[0])
				var lane: Vector3 = vl.road_pos(mini(last + 3, vl.road.size() - 1)) + vl.road_dir(mini(last + 3, vl.road.size() - 1)).cross(Vector3.UP) * 1.6
				var want := Vector3(lane.x - mp.position.x, 0, lane.z - mp.position.z)
				var err := (-mp.global_transform.basis.z).signed_angle_to(want, Vector3.UP)
				Input.action_press("left", clampf(err * 3.0, 0.0, 1.0))
				Input.action_press("right", clampf(-err * 3.0, 0.0, 1.0))
				if mp.is_on_wall():
					walls[last] = true
				slow = slow + 1 if absf(mp.speed) < 0.6 else 0
				if slow == 60:
					print("KOKO pysähtyi näytteellä %d (%s), y %.2f tie %.2f" % [last, vl.road_names[last], mp.position.y, vl.road_pos(last).y])
				if i % 600 == 0 or (slow > 0 and slow % 30 == 0):
					print("KOKO %3d s: näyte %d/%d, %.1f km/h, tiestä %.1f m, ajettava %s, reuna %.2f, paikka %s" % [i / 60, last,
						vl.road.size(), mp.speed * 3.6, ni[1], vl.drivable(mp.position.x, mp.position.z), mp._curb, mp.position])
				if last >= vl.road.size() - 30 or slow > 300:
					break
			Input.action_release("forward")
			Input.action_release("left")
			Input.action_release("right")
			print("KOKO loppu: näyte %d/%d, aika %.0f s, seinäosumat näytteillä %s, kaatumisia %d" % [last, vl.road.size(),
				(Time.get_ticks_msec() - t0) / 1000.0, str(walls.keys()), crashes[0]])
		"mokkireitti":
			# Reitti ajajan silmin 60 näytteen välein (lappu ja liikenne piilossa): _r<näyte>.png ja vastasuuntaan _p<näyte>.png.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			var mp: CharacterBody3D = main.mopo_trip.mopo
			main._msg.text = ""
			main._note.visible = false
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			mp.process_mode = Node.PROCESS_MODE_DISABLED
			var oc := Camera3D.new()
			oc.far = 3000.0
			oc.fov = 70.0
			main.add_child(oc)
			var step: int = 60
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--step="):
					step = int(arg.substr(7))
			for si in range(10, vl.road.size() - 5, step):
				for back in [false, true]:
					var d: Vector3 = vl.road_dir(si) * (-1.0 if back else 1.0)
					var eye: Vector3 = vl.road_pos(si) + d.cross(Vector3.UP) * 1.6 + Vector3(0, 1.9, 0)
					oc.look_at_from_position(main.mopo_trip.to_global(eye), main.mopo_trip.to_global(eye + d * 20.0 - Vector3(0, 1.2, 0)))
					oc.current = true
					for i in 12:
						await main.get_tree().process_frame
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s%03d.png" % ["p" if back else "r", si]))
			main.get_tree().quit()
		"mokkiratasilta":
			# Oulujoen ratasilta (teräsristikko): joen pinnasta, tiesillalta, ylhäältä ja kiskoilta.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			main._msg.text = ""
			main._note.visible = false
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var oc := Camera3D.new()
			oc.far = 3000.0
			oc.fov = 60.0
			main.add_child(oc)
			var snap := func(name: String, from: Vector3, to: Vector3) -> void:
				oc.look_at_from_position(main.mopo_trip.to_global(from), main.mopo_trip.to_global(to))
				oc.current = true
				for i in 15:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var c := Vector3(610, 130.2, -704)
			await snap.call("_joki.png", c + Vector3(-25, -6.5, 55), c + Vector3(0, 2, 0))
			await snap.call("_joki2.png", c + Vector3(30, -6.0, 60), c + Vector3(-5, 2, 0))
			await snap.call("_tiesilta.png", Vector3(560, 133, -738), c + Vector3(0, 2, 0))
			await snap.call("_ylha.png", c + Vector3(0, 70, 30), c)
			await snap.call("_kiskot.png", Vector3(545, 132.5, -686.5), c + Vector3(0, 2.5, 0))
			main.get_tree().quit()
		"mokkisiitariovi":
			# Siitarin ovi: mopolla ja jalan, matkan kohde Siitari ja Paapeli (junalla tai Gasthausista tultaessa).
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
			var near := []
			for d in vl.doors:
				if d.pos.distance_to(vl.siitari_door) < 25.0:
					near.append("%s %.1f m (r %.1f)" % [d.id, d.pos.distance_to(vl.siitari_door), d.get("r", 5.0)])
			print("SIITARI ovi %s, parkki %s, ovet lähellä: %s" % [vl.siitari_door, vl.siitari_park, near])
			for tg in ["siitari", "paapeli"]:
				main.mopo_trip.target = tg
				var mp: CharacterBody3D = main.mopo_trip.mopo
				for at in [["parkki", vl.siitari_park], ["ovi", vl.siitari_door]]:
					mp.position = at[1] + Vector3(0, 0.6, 0)
					mp.speed = 0.0
					for i in 10:
						await main.get_tree().process_frame
					print("SIITARI kohde %s, %s: vihje '%s', tila %s" % [tg, at[0], main.mopo_trip.hint, main.state])
			main.get_tree().quit()
		"mokkiratsia":
			# Moporatsia: selvänä, rattijuopumus (0,7 ‰), ratsian ohitus ja törkeä rattijuopumus (iso sakko).
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(name: String) -> void:
				for i in 10:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main.ratsia_force = true
			main._note.visible = false
			for case in [["selva", 0.0], ["ratti", 0.3], ["ohitus", 0.0], ["torkea", 0.6]]:
				main.money = 300.0
				main.maine = 50.0
				main.tilat.values["humala"] = case[1]
				main._start_mopo()
				var vl: Node3D = main.mopo_trip.vaala
				for car in main.mopo_trip._cars:
					car.process_mode = Node.PROCESS_MODE_DISABLED
					car.visible = false
				var rz: Node3D = main._ratsia
				var sp: Vector3 = rz.stop_pos
				var ni: int = vl.nearest(sp)[0]
				var dir: Vector3 = vl.road_dir(ni)
				var mp: CharacterBody3D = main.mopo_trip.mopo
				mp.position = sp - dir * 40.0 + Vector3(0, 0.6, 0)
				mp.position.y = vl.h(mp.position.x, mp.position.z) + 0.6
				mp.rotation.y = atan2(-dir.x, -dir.z)
				for i in 10:
					await main.get_tree().process_frame
				print("RATSIA %s: vaihe '%s', viesti '%s'" % [case[0], main._ratsia_stage, main._msg.text])
				if case[0] == "selva":
					await snap.call("_lahestyy.png")
				if case[0] == "ohitus":
					mp.position = sp + Vector3(0, 0.6, 0)
					mp.speed = 12.0
					for i in 3:
						await main.get_tree().process_frame
					mp.position = sp + dir * 40.0 + Vector3(0, 0.6, 0)
					mp.position.y = vl.h(mp.position.x, mp.position.z) + 0.6
					for i in 5:
						await main.get_tree().process_frame
					print("RATSIA ohitus: vaihe '%s', rahaa %.0f, maine %.0f, viesti '%s'" % [main._ratsia_stage, main.money, main.maine, main._msg.text])
					continue
				mp.position = sp + Vector3(0, 0.6, 0) - dir * 2.0
				mp.speed = 0.0
				for i in 10:
					await main.get_tree().process_frame
				print("RATSIA %s: pysähtyi, vaihe '%s', valikko %s" % [case[0], main._ratsia_stage, str(main._talk_options().map(func(o): return o.text))])
				if case[0] == "selva":
					await snap.call("_puhallus.png")
				main._talk_choose("puhalla")
				print("RATSIA %s: %.2f ‰ -> '%s' / '%s', rahaa %.0f, maine %.0f" % [case[0], main._promille(), main._talk_box._line, main._talk_box._info, main.money, main.maine])
				if case[0] == "ratti":
					await snap.call("_tulos.png")
				main._talk_choose("jatka")
				for i in 30:
					await main.get_tree().process_frame
				print("RATSIA %s: jatko, tila %s, mopo ohjattavissa %s, päivä %d, viesti '%s'" % [case[0], main.state, main.mopo_trip.mopo.controls_enabled, main.day, main._msg.text.replace("\n", " ")])
			var f := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f.store_buffer(saved)
			f.close()
			main.get_tree().quit()
		"mokkinuoret":
			# Lavan nuorisohommat: porukka aidan takana (huikka, kalja -> pummivinkki), pummireitti järven kautta lavalle.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(name: String) -> void:
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			main._note.visible = false
			main.beers = 2
			main._mopo_dismount()
			print("NUORET bileet %s, pummi ulkona %s sisällä %s, lavan ovi %s" % [vl.party_pos, vl.pummi_out, vl.pummi_in, vl.lava_door])
			var pp: Vector3 = vl.party_pos
			main.walker_out.global_position = main.mopo_trip.to_global(pp + Vector3(0, 0.5, 0) + vl.doors.filter(func(d): return d.id == "bileet")[0].out * -3.5)
			main.walker_out.global_rotation.y = atan2(pp.x - main.mopo_trip.to_local(main.walker_out.global_position).x, pp.z - main.mopo_trip.to_local(main.walker_out.global_position).z) + PI
			for i in 15:
				await main.get_tree().process_frame
			print("NUORET bileissä vihje '%s'" % main.mopo_trip.hint)
			await snap.call("_bileet.png")
			main._on_vaala_door("bileet")
			print("NUORET valikko: %s" % str(main._talk_options().map(func(o): return o.text)))
			main._talk_choose("huikka")
			main._talk_choose("tarjoa")
			print("NUORET huikat %d, humala %.2f, kaljat %d, vinkki %s, vastaus '%s'" % [main._nuoret_huikat, main.tilat.value("humala"), main.beers, main._pummi_tip,
				main._talk_box._line])
			await snap.call("_juttu.png")
			main._talk_box.close()
			for i in 5:
				await main.get_tree().process_frame
			var po: Vector3 = vl.pummi_out
			main.walker_out.global_position = main.mopo_trip.to_global(po + Vector3(0, 0.5, 0))
			for i in 15:
				await main.get_tree().process_frame
			print("NUORET rannassa vihje '%s', kuiva %s" % [main.mopo_trip.hint, not vl.wet(po.x, po.z)])
			await snap.call("_ranta.png")
			# Pummi vie lavan pihalle ilman leimaa (portsari vahtii); tansseihin mennään pihalta lavan ovesta.
			main._pummi_lava()
			print("NUORET pummilla: leima '%s', pihalla %s, viesti '%s'" % [main._lava_pass_now(),
				vl.in_lava_yard(main.mopo_trip.to_local(main.walker_out.global_position)), main._msg.text])
			main._pummi_lava()
			print("NUORET pummi uudestaan: viesti '%s'" % main._msg.text)
			await snap.call("_lava.png")
			print("NUORET lavalla rahat %.2f, tila %s" % [main.money, main.state])
			var f := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f.store_buffer(saved)
			f.close()
			main.get_tree().quit()
		"mokkirakaleima":
			# Räkäleima (rakaleima_game.gd): teinin leiman kopiointi lavan pihalla. Kuvat joka vaiheesta, kaksi lopputulosta:
			# kopio käännettynä oikein päin (kelpaa lipusta) ja peilikuva sellaisenaan (portsarin epäily vähenee vain vähän).
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(name: String) -> void:
				for i in 6:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			main._note.visible = false
			main._mopo_dismount()
			var yard_door: Dictionary = vl.doors.filter(func(d): return d.id == "pihanuoret")[0]
			main.walker_out.global_position = main.mopo_trip.to_global(yard_door.pos + yard_door.out * 2.0 + Vector3(0, 0.5, 0))
			main._lava_pass = "pummi"
			main._lava_pass_day = main.day
			for i in 10:
				await main.get_tree().process_frame
			for round_i in 2:
				main._leima_day = -1
				main._lava_pass = "pummi"
				main._lava_pass_day = main.day
				main._lava_copy = {}
				main._on_vaala_door("pihanuoret")
				print("RAKALEIMA %d valikko: %s" % [round_i, str(main._talk_options().map(func(o): return o.text + (" [ei: %s]" % o.reason if not o.enabled else "")))])
				main._talk_choose("leima")
				for i in 5:
					await main.get_tree().process_frame
				var g: CanvasLayer = main._rakaleima
				print("RAKALEIMA %d peli käynnissä %s, tila %s, hiiri vapaana %s" % [round_i, g != null, main.state, CamCtl.free_mouse])
				g._gaze = "away"
				g._gaze_t = 100.0
				if round_i == 0:
					await snap.call("_a_alku.png")
				g._raw = g._stamp_c() + Vector2(30, 14)
				g.kostuta()
				g._lmb = true
				for i in 40:
					await main.get_tree().process_frame
					g._gaze_t = 100.0
					g._t = 2.0  # muste ei ehdi kuivua hitaassa ohjelmistorenderöinnissä
				await snap.call("_b_paino_%d.png" % round_i)
				g._lmb = false
				g._release()
				print("RAKALEIMA %d kopio q=%.2f vaihe %s peilikuva %s epäily %.2f" % [round_i, g._q, g._phase, g._mirror, g._susp])
				await snap.call("_c_peili_%d.png" % round_i)
				if round_i == 0:
					g._flip_marker = 0.5
					g.flip()
					await snap.call("_d_oikein.png")
				else:
					g.accept()
				print("RAKALEIMA %d lopetus: end_t %.2f valmis %s" % [round_i, g._end_t, g._done])
				var t0 := Time.get_ticks_msec()
				while main._rakaleima != null and Time.get_ticks_msec() - t0 < 40000:
					await main.get_tree().process_frame
				print("RAKALEIMA %d hiiri vapautettu pelin jälkeen: %s" % [round_i, not CamCtl.free_mouse])
				print("RAKALEIMA %d tulos: tila %s, lippu '%s', kopio %s, viesti '%s'" % [round_i, main.state, main._lava_pass_now(), str(main._lava_copy), main._msg.text.replace("\n", " ")])
				main._lava_yard_logic()
				print("RAKALEIMA %d portsari: cover %.2f peilikuva %s" % [round_i, main._portsari.cover if main._portsari != null else -1.0, main._portsari.mirrored if main._portsari != null else false])
			# Jäi kiinni: painaminen teinin katsoessa.
			main._leima_day = -1
			main._lava_copy = {}
			main._lava_pass = "pummi"
			main._lava_pass_day = main.day
			main._on_vaala_door("pihanuoret")
			main._talk_choose("leima")
			for i in 5:
				await main.get_tree().process_frame
			var gc: CanvasLayer = main._rakaleima
			gc._raw = gc._stamp_c()
			gc._lmb = true
			gc._gaze = "look"
			for i in 120:
				await main.get_tree().process_frame
				if not is_instance_valid(gc):
					break
				gc._gaze = "look"
				gc._gaze_t = 100.0
				gc._t = 2.0
				if gc._end_t >= 0.0 and gc._end_t < 1.6:
					await snap.call("_e_kiinni.png")
					break
			var t1 := Time.get_ticks_msec()
			while main._rakaleima != null and Time.get_ticks_msec() - t1 < 40000:
				await main.get_tree().process_frame
			print("RAKALEIMA kiinni: tila %s, maine %.0f, viesti '%s', uusi yritys: %s" % [main.state, main.maine, main._msg.text.replace("\n", " "),
				str(main._talk_options().map(func(o): return o.text + (" [ei: %s]" % o.reason if not o.enabled else "")))])
			var f2 := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f2.store_buffer(saved)
			f2.close()
			main.get_tree().quit()
		"mokkitynnyri", "mokkiuinti":
			# Tynnyrisaunan löylyt (Santtu tuo kaljat) tai Salmisen uinti ja sukeltelu: välianimaatio kuvina.
			main._toggle_mount()
			var spot: Vector3 = main.mokki.barrel_door if scene == "mokkitynnyri" else main.mokki.beach_pos - Vector3(0, 0, 0)
			main.walker_out.global_position = main.mokki.gpos(spot + Vector3(0, 1.0, 0))
			for i in 30:
				await main.get_tree().physics_frame
			if scene == "mokkiuinti":
				var probe: Node3D = Looks.make(main, Cutscene.swim_look(Looks.player()))
				for an in ["Swim_Fwd", "Swim_Idle"]:
					probe.play(an, 0.0)
					probe.anim.advance(0.5)
					print("UINTI %s: pää y %.2f, lantio y %.2f, jalka y %.2f, pää z %.2f" % [an, probe.bone_position("Head").y,
						probe.bone_position("pelvis").y, probe.bone_position("foot_l").y, probe.bone_position("Head").z])
				probe.queue_free()
				main._swim("Salminen", Vector3.ZERO)
			else:
				main._barrel_sauna()
			print("VÄLIKUVA %s alkoi: %s, tila %s" % [scene, main.cutscene.busy, main.state])
			var k := 0
			while main.cutscene.busy and k < 40:
				await main.get_tree().create_timer(1.0).timeout
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%02d.png" % k))
				k += 1
			for i in 90:
				await main.get_tree().process_frame
			print("VÄLIKUVA %s loppui: tila %s, ohjaus %s, viesti '%s', viski %s" % [scene, main.state, main.player.controls_enabled,
				main._msg.text.replace("\n", " | "), Mokki.viina_positions()[-1]])
			main.get_tree().quit()
		"mokkisalminen":
			# Jalan Salmisen rannalla, Ranta-Rosvolla ja Keskimmäisen laavulla: soratiet perille ja minikartta näkyvissä.
			main._toggle_mount()
			for spot in [["_ranta", main.mokki.beach_pos], ["_rosvo", main.mokki.rosvo_pos], ["_laavu", main.mokki.laavu_fire]]:
				var lp: Vector3 = spot[1]
				main.walker_out.global_position = main.mokki.gpos(lp + Vector3(0, 1.0, 0))
				var sp := Vector2(lp.x, lp.z)
				var data: Dictionary = Mokki.map_data()
				var best := INF
				var near := Vector2.ZERO
				for r in data.roads:
					var pts: PackedVector2Array = r.pts
					for k in pts.size() - 1:
						var q := Geometry2D.get_closest_point_to_segment(sp, pts[k], pts[k + 1])
						if q.distance_to(sp) < best:
							best = q.distance_to(sp)
							near = q
				var face := Vector3(near.x - lp.x, 0, near.y - lp.z)
				main.walker_out.global_rotation.y = atan2(face.x, face.z) + main.mokki.global_rotation.y
				main.walker_out.activate_camera()
				for i in 30:
					await main.get_tree().process_frame
				print("SALMINEN %s: tiestä %.1f m, minikartta näkyy %s (mökin kartta %s), tila %s" % [spot[0], best, main._minimap.visible,
					main._minimap._near_mokki(), main.state])
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", spot[0] + ".png"))
			main.get_tree().quit()
		"mokkiuinti_mopo":
			# Mopolla Salmisen rannalle ja kaasu pohjassa kohti järveä, sitten E uimaan mopon selästä: mopon pitää
			# olla uinnin jälkeen näkyvissä kuivalla maalla kävelijän lähellä.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			var mp: CharacterBody3D = main.mopo_trip.mopo
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var bf: Transform3D = vl.beach_tf
			var start: Vector3 = bf * Vector3(0, 0, -12.0)
			mp.position = Vector3(start.x, vl.h(start.x, start.z) + 0.6, start.z)
			var lake: Vector3 = bf.basis * Vector3(0, 0, 1)
			mp.rotation.y = atan2(-lake.x, -lake.z)
			mp.activate_camera()
			Input.action_press("forward", 1.0)
			for i in 240:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			for i in 30:
				await main.get_tree().physics_frame
			var lp: Vector3 = mp.position
			print("UINTI_MOPO rannalla %s: koodi %d, maasto %.2f vs vesi %.2f, vihje '%s'" % [lp, vl.code_at(lp.x, lp.z), vl.h(lp.x, lp.z),
				vl.beach_wl, main.mopo_trip.hint])
			Input.action_press("interact")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("interact")
			var k := 0
			while (main.cutscene.busy or main.state == "cutscene") and k < 60:
				await main.get_tree().create_timer(1.0).timeout
				k += 1
			for i in 60:
				await main.get_tree().physics_frame
			var q: Vector3 = mp.global_position
			print("UINTI_MOPO jälkeen: mopo %s näkyvä %s (vanhemmat näkyvät %s), prosessi %d, koodi %d, maasto %.2f, kävelijästä %.1f m, jalan %s, kamera %s" % [
				mp.position, mp.visible, mp.is_visible_in_tree(), mp.process_mode, vl.code_at(mp.position.x, mp.position.z),
				vl.h(mp.position.x, mp.position.z), q.distance_to(main.walker_out.global_position), main.mopo_trip.on_foot != null,
				main.get_viewport().get_camera_3d().get_parent().name])
			var cam := main.get_viewport().get_camera_3d()
			cam.look_at_from_position(main.walker_out.global_position + Vector3(0, 3, 0) - (bf.basis * Vector3(0, 0, 1)) * 6.0, q)
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path)
			main.get_tree().quit()
		"mokkiranta_vaala":
			# Mopomatkan Salmisen ranta: kyltti, pukukoppi ja penkki kuvina (rannan kehyksessä, +Z järvelle).
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			var bf: Transform3D = vl.beach_tf
			for c in vl._north_rep.get_children():
				if c is Node3D and (c as Node3D).position.distance_to(bf.origin) < 25.0:
					var cp: Vector3 = (c as Node3D).position
					print("RANTA %s %s: maasto %.2f, koodi %d, vesi %.2f" % [c.get_class(), cp, vl.h(cp.x, cp.z), vl.code_at(cp.x, cp.z), vl.beach_wl])
			var rc := Camera3D.new()
			main.add_child(rc)
			rc.current = true
			for v in [["_maalta", Vector3(-6, 4, -22), Vector3(0, 0, -4)], ["_jarvelta", Vector3(4, 3, 14), Vector3(0, 1, -6)]]:
				rc.look_at_from_position(main.mopo_trip.to_global(bf * (v[1] as Vector3) + Vector3(0, bf.origin.y, 0) - Vector3(0, bf.origin.y, 0)),
					main.mopo_trip.to_global(bf * (v[2] as Vector3)), Vector3.UP)
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "%s.png" % v[0]))
			main.get_tree().quit()
		"mokkimopo_jarviseutu":
			# Risteyksestä mopolla: vasemmalle asfalttia Ranta-Rosvolle ja Salmisen rannalle, suoraan soratietä
			# tynnyrisaunan ovelle (vaala.gd _plan_north). Ajo seuraa tietä; perillä kuva mopon takaa.
			main.tilat.add("humala", -1.0)
			main._start_mopo()
			var mp: CharacterBody3D = main.mopo_trip.mopo
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var roads := {}
			for r in vl.north_roads:
				roads[r.name] = r.pts
			var branch := PackedVector2Array()
			for br in vl.data.branches:
				if br.name == "Neittäväntie":
					for q in br.pts:
						branch.append(Vector2(q[0], q[2]))
			var upto := func(line: PackedVector2Array, goal: Vector2) -> PackedVector2Array:
				var bi := 0
				for i in line.size():
					if line[i].distance_to(goal) < line[bi].distance_to(goal):
						bi = i
				return line.slice(0, bi + 1)
			# Jokainen tien näyte ajoalueella ja kuivalla (tiivistetyllä järviseudulla tie kulkee järvien pintaa alempana).
			for rn in roads:
				var pl: PackedVector2Array = roads[rn]
				var bad := Array(pl).filter(func(q: Vector2) -> bool: return not vl.drivable(q.x, q.y) or vl.wet(q.x, q.y, 0.25))
				print("JARVI tie %s: %d / %d näytettä ajokelvottomia" % [rn, bad.size(), pl.size()])
			var asph: PackedVector2Array = roads["Nuojuankoskentie"]
			var rspur: PackedVector2Array = roads["Ranta-Rosvo"]
			var bspur: PackedVector2Array = roads["Salmisen uimaranta"]
			var legs := [
				["rosvo", branch + upto.call(asph, rspur[0]) + rspur, Vector2(vl.rosvo_pos.x, vl.rosvo_pos.z)],
				["ranta", upto.call(asph, bspur[0]).slice(upto.call(asph, rspur[0]).size()) + bspur, Vector2(vl.beach_pos.x, vl.beach_pos.z)],
				["sauna", roads["Keskimmäisentie"] + PackedVector2Array([Vector2(vl.barrel_door.x, vl.barrel_door.z)]),
					Vector2(vl.barrel_door.x, vl.barrel_door.z)],
			]
			for leg in legs:
				var line: PackedVector2Array = leg[1]
				var goal: Vector2 = leg[2]
				if true:
					var d0 := (line[2] - line[0]).normalized()
					mp.position = Vector3(line[0].x, vl.h(line[0].x, line[0].y) + 0.6, line[0].y)
					mp.rotation.y = atan2(-d0.x, -d0.y)
					mp.speed = 0.0
				var at := 0
				var stuck := 0
				var off := 0
				var t0 := Time.get_ticks_msec()
				for i in 60 * 120:
					await main.get_tree().physics_frame
					var p2 := Vector2(mp.position.x, mp.position.z)
					while at < line.size() - 1 and line[at].distance_to(p2) < 6.0:
						at += 1
					var want := Vector3(line[at].x - p2.x, 0, line[at].y - p2.y)
					var err := (-mp.global_transform.basis.z).signed_angle_to(want, Vector3.UP)
					Input.action_press("forward", 0.55 if absf(err) < 0.5 else 0.3)
					Input.action_press("left", clampf(err * 3.0, 0.0, 1.0))
					Input.action_press("right", clampf(-err * 3.0, 0.0, 1.0))
					stuck = stuck + 1 if absf(mp.speed) < 0.5 else 0
					if not vl.drivable(p2.x, p2.y):
						off += 1
					if i % 300 == 0:
						print("JARVI %s %3d s: piste %d/%d, %.0f km/h, %s, pinta %d, maasto %d" % [leg[0], i / 60, at, line.size(), mp.speed * 3.6,
							main.mopo_trip.status.replace("\n", " / "), vl.drive_code(mp.position), off])
					if p2.distance_to(goal) < 3.5 or stuck > 240:
						break
				Input.action_release("forward")
				Input.action_release("left")
				Input.action_release("right")
				for i in 40:
					await main.get_tree().physics_frame
				var p2 := Vector2(mp.position.x, mp.position.z)
				print("JARVI %s: perillä %s (%.1f m kohteesta), aika %.0f s, jumissa %s, ajoalueen ulkona %d ruutua, tie '%s'" % [leg[0],
					p2.distance_to(goal) < 4.5, p2.distance_to(goal), (Time.get_ticks_msec() - t0) / 1000.0, stuck > 240, off,
					main.mopo_trip.status.replace("\n", " / ")])
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % leg[0]))
			# Yleiskuva järviseudusta ylhäältä.
			var oc := Camera3D.new()
			oc.far = 3000.0
			main.add_child(oc)
			oc.global_position = main.mopo_trip.to_global(Vector3(-120, 420, -330))
			oc.look_at(main.mopo_trip.to_global(Vector3(-120, 130, -520)), Vector3.FORWARD)
			oc.current = true
			for i in 30:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_ylhaalta.png"))
			main.get_tree().quit()
		"mokkimopo_paluu":
			# Paluu Siitarista mökille täysillä oikealla kaistalla (ilman liikennettä): pysähdykset ja seinäosumat,
			# erityisesti Oulujoen sillalla.
			main.tilat.add("humala", -1.0)
			main._start_mopo()
			var mp: CharacterBody3D = main.mopo_trip.mopo
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var si: int = vl.road.size() - 12
			var d: Vector3 = -vl.road_dir(si)
			mp.position = vl.road_pos(si) + Vector3(0, 0.6, 0) + d.cross(Vector3.UP) * 1.6
			mp.rotation.y = atan2(-d.x, -d.z)
			Input.action_press("forward")
			var last := si
			var slow := 0
			var walls := {}
			var stuck_at := -1
			var t0 := Time.get_ticks_msec()
			for i in 60 * 400:
				await main.get_tree().physics_frame
				var ni: Array = vl.nearest(mp.position)
				if ni[0] >= 0:
					last = mini(last, ni[0])
				var li := maxi(last - 3, 0)
				var lane: Vector3 = vl.road_pos(li) - vl.road_dir(li).cross(Vector3.UP) * 1.6
				var want := Vector3(lane.x - mp.position.x, 0, lane.z - mp.position.z)
				var err := (-mp.global_transform.basis.z).signed_angle_to(want, Vector3.UP)
				Input.action_press("left", clampf(err * 3.0, 0.0, 1.0))
				Input.action_press("right", clampf(-err * 3.0, 0.0, 1.0))
				if mp.is_on_wall():
					walls[last] = true
				slow = slow + 1 if absf(mp.speed) < 0.6 else 0
				if slow == 60:
					print("PALUU pysähtyi näytteellä %d (%s), y %.2f tie %.2f, paikka %s" % [last, vl.road_names[last], mp.position.y,
						vl.road_pos(last).y, mp.position])
					var fw3 := -mp.global_transform.basis.z
					var prow := ""
					for a: float in [0.0, 0.45, -0.45, 1.1, -1.1, 1.57, -1.57, 3.14]:
						var dd := Vector2(fw3.x, fw3.z).normalized().rotated(a)
						var qq := Vector2(mp.position.x, mp.position.z) + dd * 1.0
						prow += " %+.2f:%s" % [a, "#" if vl.drivable(qq.x, qq.y) else "."]
					var col := mp.get_last_slide_collision()
					print("PALUU jumi: ajettava %s, reuna %.2f, nopeus %.2f, suunta %s, kokeet%s, seinä %s, osuma %s, kaasu %.2f" % [
						vl.drivable(mp.position.x, mp.position.z), mp._curb, mp.speed, fw3, prow, mp.is_on_wall(),
						"" if col == null else "%s %s" % [col.get_collider(), col.get_normal()], Input.get_axis("back", "forward")])
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_jumi.png"))
				if i % 300 == 0:
					print("PALUU %3d s: näyte %d, %.1f km/h, tiestä %.1f m, y %.2f" % [i / 60, last, mp.speed * 3.6, ni[1], mp.position.y])
				if last <= 20 or slow > 300 or (i % 1200 == 0 and i > 0 and last == stuck_at):
					break
				if i % 1200 == 0:
					stuck_at = last  # 20 s samassa kohdassa = jumissa
			Input.action_release("forward")
			Input.action_release("left")
			Input.action_release("right")
			print("PALUU loppu: näyte %d, aika %.0f s, seinäosumat näytteillä %s" % [last, (Time.get_ticks_msec() - t0) / 1000.0,
				str(walls.keys())])
			main.get_tree().quit()
		"mokkimopo_silta", "mokkimopo_kanni":
			# mokkimopo_silta: oikealla kaistalla täysillä Oulujoen sillan yli (ei porrasta sillan päissä), kuva kannelta.
			# mokkimopo_kanni: humala 0,8, kaasu pohjassa ilman ohjausta: kuinka pian mopo on ojassa.
			var kanni := scene == "mokkimopo_kanni"
			main.tilat.add("humala", -1.0)
			if kanni:
				main.tilat.add("humala", 0.8)
			main._start_mopo()
			var mp: CharacterBody3D = main.mopo_trip.mopo
			var vl: Node3D = main.mopo_trip.vaala
			var crashes := [0]
			print("MOPO humala %.2f" % mp.drunk)
			main.mopo_trip.crashed.connect(func(r: String) -> void:
				crashes[0] += 1
				print("MOPO kumoon (%s) näyte %d" % [r, vl.nearest(mp.position)[0]]))
			var b0 := int(vl.data.bridges[0][0])
			var si := b0 - 30 if not kanni else 480
			for car in main.mopo_trip._cars:  # ilman liikennettä: mitataan pelkkää ajamista
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var d: Vector3 = vl.road_dir(si)
			mp.position = vl.road_pos(si) + Vector3(0, 0.6, 0) + d.cross(Vector3.UP) * 1.6
			mp.rotation.y = atan2(-d.x, -d.z)
			mp.speed = 12.0
			Input.action_press("forward")
			for i in 60 * 12:
				await main.get_tree().physics_frame
				if not kanni:
					# Pidä oikea kaista: ohjaa kohti kaistan keskiviivaa.
					var ni: Array = vl.nearest(mp.position)
					var lane: Vector3 = vl.road_pos(ni[0] + 3) + vl.road_dir(ni[0] + 3).cross(Vector3.UP) * 1.6
					var want := Vector3(lane.x - mp.position.x, 0, lane.z - mp.position.z)
					var err := (-mp.global_transform.basis.z).signed_angle_to(want, Vector3.UP)
					Input.action_press("left", clampf(err * 3.0, 0.0, 1.0))
					Input.action_press("right", clampf(-err * 3.0, 0.0, 1.0))
				if i % 60 == 0:
					print("MOPO %2d s: näyte %d, %.1f km/h, y %.2f, tiestä %.1f m, pinta %d, seinä %s, ohjaus %s, kaatunut %s" % [i / 60, vl.nearest(mp.position)[0], mp.speed * 3.6, mp.position.y,
						vl.nearest(mp.position)[1], vl.code_at(mp.position.x, mp.position.z), mp.is_on_wall(), mp.controls_enabled, mp.fallen])
				if not kanni and vl.nearest(mp.position)[0] == b0 + 10:
					Input.action_release("forward")
					await main.get_tree().process_frame
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path)
			Input.action_release("forward")
			print("MOPO loppu: näyte %d (silta %s), kaatumisia %d" % [vl.nearest(mp.position)[0], vl.data.bridges[0], crashes[0]])
			if kanni:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path)
			main.get_tree().quit()
		"mokkiviina":
			# Viinakätköjen etäisyys lähimpään rakennukseen (negatiivinen = sisällä) ja korkeus maasta.
			var data: Dictionary = Mokki.map_data()
			var vp: Array[Vector2] = Mokki.viina_positions()
			for i in vp.size():
				var p: Vector2 = vp[i]
				var best := INF
				for bd in data.buildings:
					var poly: PackedVector2Array = bd.poly
					if poly.size() < 3:
						continue
					var d := INF
					for k in poly.size():
						var c := Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()])
						d = minf(d, p.distance_to(c))
					if Geometry2D.is_point_in_polygon(p, poly):
						d = -d
					best = minf(best, d)
				var e := 1.5
				var sl := rad_to_deg(atan(Vector2(Mokki.h(p.x + e, p.y) - Mokki.h(p.x - e, p.y), Mokki.h(p.x, p.y + e) - Mokki.h(p.x, p.y - e)).length() / (2.0 * e)))
				print("VIINA %d %s: lähin rakennus %.1f m, rinne %.0f°" % [i, p, best, sl])
		"mokkivessa":
			# Mökin pesuhuoneen pönttö (kakkonen, 12 arkkia = tukos) ja pihan huussi (kakkonen, 12 arkkia: ei tukosta).
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
				if g == null:
					print("VESSA minipeli ei auennut")
					return
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
			main.walker_out.global_position = main.mokki.porch_pos(0.9)
			for i in 10:
				await main.get_tree().physics_frame
			main._enter_mokki()
			main.mokki_int.walker.position = main.mokki_int.SPOTS.wc[0]
			for i in 10:  # vihje päivittyy _processissa: prosessiruutuja, ei fysiikkaruutuja
				await main.get_tree().process_frame
			print("VESSA mökki: '%s'" % main.mokki_int.hint)
			await press.call("interact")
			await play.call(2, 12)
			main._on_mokki_exited()
			main.walker_out.global_position = main.mokki.to_global(Mokki.HUUSSI_LOCAL + Vector3(0, 0.3, 1.3))
			for i in 10:
				await main.get_tree().physics_frame
			print("VESSA huussi: '%s'" % main._hint.text)
			await press.call("interact")
			await play.call(2, 12)
		"mokkivaalatiet":
			# Kaikki Vaalan tiet ajettaviksi: mopon kapseli (r 0,4, 1,8 m) 0,3 m maan yläpuolella 1,5 m välein reittiä,
			# risteysten haaroja ja OSM-teitä pitkin. Osuma = este (rakennus, aita, kaide, puomi) tai liian jyrkkä maa.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			var mp: CharacterBody3D = main.mopo_trip.mopo
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			for i in 5:
				await main.get_tree().physics_frame
			var space := main.get_world_3d().direct_space_state
			var cap := CapsuleShape3D.new()
			cap.radius = 0.4
			cap.height = 1.8
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = cap
			q.collision_mask = mp.collision_mask
			q.exclude = [mp.get_rid()]
			var lines: Array = []  # [nimi, pisteet (paikallinen Vector3, y = tien taso tai NAN)]
			var main_pts: Array = []
			for i in range(6, vl.road.size()):  # alku on mökin pihassa (mopo lähtee parkista)
				main_pts.append(vl.road_pos(i) + vl.road_dir(i).cross(Vector3.UP) * 1.6)  # oikea kaista
			lines.append(["reitti", main_pts])
			for b in vl.data.branches:
				var bp: Array = []
				for k in b.pts.size() - 3:  # umpitien puomi lopussa
					bp.append(Vector3(b.pts[k][0], NAN, b.pts[k][2]))
				lines.append(["haara " + b.name, bp])
			for r in vl.data.side_roads:
				if r.kind != "road" or r.hw in ["footway", "cycleway", "path", "pedestrian", "steps"]:
					continue
				var sp: Array = []
				for k in r.pts.size():
					sp.append(Vector3(r.pts[k][0], NAN, r.pts[k][1]))
				lines.append(["%s (%s)" % [r.name if r.name != "" else "nimetön", r.hw], sp])
			var bad := {}
			var total_m := 0.0
			for ln in lines:
				var pts: Array = ln[1]
				for k in pts.size() - 1:
					var a: Vector3 = pts[k]
					var b2: Vector3 = pts[k + 1]
					var seg := Vector2(b2.x - a.x, b2.z - a.z).length()
					total_m += seg
					var steps := maxi(int(seg / 1.5), 1)
					for t in steps:
						var f := float(t) / steps
						var x := lerpf(a.x, b2.x, f)
						var z := lerpf(a.z, b2.z, f)
						var gy: float = vl.h(x, z) if is_nan(a.y) else lerpf(a.y, b2.y, f)
						# Maa törmäysmuodoista (silta, alikulku): säde ylhäältä.
						var top := vl.to_global(Vector3(x, gy + 2.5, z))
						var ray := PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 8, 0), mp.collision_mask, [mp.get_rid()])
						var hit := space.intersect_ray(ray)
						var y := gy
						if not hit.is_empty():
							y = vl.to_local(hit.position).y
						q.transform = Transform3D(Basis(), vl.to_global(Vector3(x, y + 0.9 + 0.3, z)))
						var res := space.intersect_shape(q, 4)
						var why := ""
						if not hit.is_empty() and (hit.normal as Vector3).y < 0.7:
							why = "jyrkkä/seinä (normaali %.2f)" % (hit.normal as Vector3).y
						for rr in res:
							var col: Object = rr.collider
							why = "este %s/%s" % [col.name, (col.get_parent().name if col.get_parent() != null else "")]
							break
						if why != "":
							var key := "%s @ %d,%d" % [ln[0], int(x / 10.0) * 10, int(z / 10.0) * 10]
							if not bad.has(key):
								bad[key] = why
			print("TIET tarkistettu %d viivaa, %.1f km, ongelmia %d" % [lines.size(), total_m / 1000.0, bad.size()])
			for key in bad:
				print("TIET  ", key, ": ", bad[key])
		"mokkisanttulava":
			# Hommat tehty -> Santtu ehdottaa lavaa, suostutaan, mopolle (Santtu taakse), lavalle (Santtu tanssii).
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.porch_pos(0.9)
			main._hommat_arrive()
			main.hommat.start_day()
			for t in main.hommat.tasks:
				if not t in main.hommat.done:
					main.hommat.done.append(t)
			main.hommat.active = true
			print("SANTTU tarjoaa: %s, tervehdys '%s'" % [main._santtu_offers_lava(), main._talk_hello("santtu")])
			main._talk_who = "santtu"
			var r := main._on_santtu_menu("lava")
			print("SANTTU vastaa: '%s'" % r[0])
			main.walker_out.global_position = main.mokki.gpos(Mokki.MOPO_LOCAL + Vector3(1.0, 0.5, 0.0))
			main._start_mopo()
			for i in 30:
				await main.get_tree().process_frame
			print("SANTTU kyydissä %s, pihalla näkyy %s, viesti '%s'" % [main._santtu_riding, main.mokki.santtu.visible, main._msg.text])
			var mp: CharacterBody3D = main.mopo_trip.mopo
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.look_at_from_position(mp.to_global(Vector3(2.2, 1.3, 0.4)), mp.to_global(Vector3(0, 1.0, 0.3)))
			cam.current = true
			main._msg.text = ""
			main._note.visible = false
			for i in 10:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_mopo.png"))
			main.money = 40.0
			mp.position = main.mopo_trip.vaala.lava_door + Vector3(0, 0.6, 0)
			main._enter_lava(true)  # lippu ostettu
			for i in 30:
				await main.get_tree().process_frame
			main._lava_game._cam.look_at_from_position(main._lava_game.to_global(Vector3(-2.5, 2.2, 6.5)), main._lava_game.to_global(Vector3(-2.5, 1.2, 2.4)))
			main._lava_game.set_process(false)
			for i in 5:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_lava.png"))
			main._lava_game.set_process(true)
			main._lava_game.finished.emit(0.6)
			for i in 5:
				await main.get_tree().process_frame
			main.mopo_trip.finished.emit("paapeli")
			for i in 5:
				await main.get_tree().process_frame
			print("SANTTU kotona: kyydissä %s, pihalla näkyy %s" % [main._santtu_riding, main.mokki.santtu.visible])
			main.get_tree().quit()
		"mokkipohjoinen":
			# Mökin pohjoiset kohteet: Salmisen uimaranta, Ranta-Rosvo, Keskimmäisen laavu, tynnyrisauna, laituri ja vene.
			main._toggle_mount()
			var cam := Camera3D.new()
			cam.far = 2000.0
			main.add_child(cam)
			var shot := func(name: String, at: Vector3, from: Vector3) -> void:
				cam.look_at_from_position(main.mokki.to_global(at + from), main.mokki.to_global(at + Vector3(0, 1.0, 0)))
				cam.current = true
				for i in 20:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main._msg.text = ""
			main._note.visible = false
			print("POHJOINEN laavu %s sauna %s laituri %s vene %s rosvo %s ranta %s" % [main.mokki.laavu_fire, main.mokki.barrel_door,
				main.mokki.north_dock, main.mokki.north_boat.position if main.mokki.north_boat else null, main.mokki.rosvo_pos, main.mokki.beach_pos])
			var dd := Vector3(main.mokki.north_dock_dir.x, 0, main.mokki.north_dock_dir.y)
			await shot.call("_laavu.png", main.mokki.laavu_fire, dd * 3.0 - dd.cross(Vector3.UP) * 4.0 + Vector3(0, 1.5, 0))
			await shot.call("_sauna.png", main.mokki.barrel_door, dd * 4.5 + dd.cross(Vector3.UP) * 3.5 + Vector3(0, 0.8, 0))
			await shot.call("_laituri.png", main.mokki.north_dock, dd * 12.0 + dd.cross(Vector3.UP) * 8.0 + Vector3(0, 4, 0))
			await shot.call("_rosvo.png", main.mokki.rosvo_pos, Vector3(2.5, 1.2, 4.5))
			await shot.call("_ranta.png", main.mokki.beach_pos, Vector3(14, 6, 10))
			var ref := Vector3(120, 0, -250)
			ref.y = Mokki.h(ref.x, ref.z)
			await shot.call("_vertailu.png", ref, Vector3(14, 6, 10))
			# Kävely: pelaaja laiturille, kalastus ja uinti.
			for spot in [["ranta", main.mokki.beach_pos], ["rosvo", main.mokki.rosvo_pos], ["laavu", main.mokki.laavu_fire], ["sauna", main.mokki.barrel_door], ["laituri", main.mokki.north_dock]]:
				main.walker_out.global_position = main.mokki.to_global(spot[1] + Vector3(0, 0.6, 0))
				main.walker_out.velocity = Vector3.ZERO
				for i in 20:
					await main.get_tree().physics_frame
				main._hint.text = ""
				for i in 3:
					await main.get_tree().process_frame
				print("POHJOINEN %s: alueella %s, vihje '%s', y %.2f" % [spot[0], Mokki.in_area(spot[1].x, spot[1].z), main._hint.text, main.mokki.to_local(main.walker_out.global_position).y])
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kavely.png"))
			main._paper.toggle()
			main._paper._vcenter = Vector2(20, -900)
			main._paper._vzoom = 0.3
			main._paper._view.queue_redraw()
			main._paper.queue_redraw()
			for i in 3:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kartta.png"))
			main._paper.toggle()
			main.get_tree().quit()
		"mokkimopo":
			# Mopomatka: lähtö Paapelista, ajo alusta, kuvat reitin varrelta (_1 lähtö, _2 Neittäväntie, _3 silta,
			# _4 Siitari) ja saapuminen baariin.
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.gpos(Mokki.MOPO_LOCAL + Vector3(1.0, 0.5, 0.0))
			for i in 10:
				await main.get_tree().physics_frame
			var tb := Time.get_ticks_msec()
			main._start_mopo()
			print("MOPO käynnistys %d ms" % (Time.get_ticks_msec() - tb))
			var mp: CharacterBody3D = main.mopo_trip.mopo
			var vl: Node3D = main.mopo_trip.vaala
			var snap := func(name: String) -> void:
				for i in 30:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			Input.action_press("forward")
			for i in 240:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			print("MOPO 4 s: %.1f km/h, y %.2f tie %.2f, %s" % [mp.speed * 3.6, mp.position.y, vl.h(mp.position.x, mp.position.z), main.mopo_trip.status])
			await snap.call("_1.png")
			for spot in [["_2.png", 0.3], ["_3.png", -1.0], ["_4.png", -2.0]]:
				var si: int
				if spot[1] == -1.0:
					si = int(vl.data.bridges[0][0]) - 25
				elif spot[1] == -2.0:
					si = vl.nearest(vl.siitari_park)[0] - 30
				else:
					si = int(vl.road.size() * spot[1])
				var d: Vector3 = vl.road_dir(si)
				mp.position = vl.road_pos(si) + Vector3(0, 0.6, 0) + d.cross(Vector3.UP) * 1.8
				mp.rotation.y = atan2(-d.x, -d.z)
				mp.speed = 8.0
				mp.activate_camera()
				await snap.call(spot[0])
				print("MOPO %s: %s | hint '%s'" % [spot[0], main.mopo_trip.status, main._hint.text.replace("\n", " / ")])
			# Yleiskuvat: Oulujoen silta sivulta ja Siitari Vaalantieltä (_5, _6).
			main._msg.text = ""
			var oc := Camera3D.new()
			oc.far = 2000.0
			main.add_child(oc)
			var bm: Vector3 = main.mopo_trip.to_global(vl.road_pos(int((vl.data.bridges[0][0] + vl.data.bridges[0][1]) / 2)))
			var bdir: Vector3 = vl.road_dir(int(vl.data.bridges[0][0]))
			oc.look_at_from_position(bm + bdir.cross(Vector3.UP) * 70.0 + Vector3(0, 12, 0), bm)
			oc.current = true
			await snap.call("_5.png")
			var sd: Vector3 = main.mopo_trip.to_global(vl.siitari_door)
			var sc3 := Vector3(vl.siitari.x, sd.y - Main.VAALA_POS.y, vl.siitari.y)
			var ni3: Array = vl.nearest(sc3)
			var rp3: Vector3 = main.mopo_trip.to_global(vl.road_pos(ni3[0]))
			var sgc: Vector3 = main.mopo_trip.to_global(sc3)
			oc.look_at_from_position(rp3 + (rp3 - sgc).normalized() * 12.0 + Vector3(0, 6, 0), sgc + Vector3(0, 3, 0))
			await snap.call("_6.png")
			mp.activate_camera()
			mp.position = vl.siitari_park + Vector3(0, 0.5, 0)
			mp.speed = 0.0
			for i in 20:
				await main.get_tree().physics_frame
			print("MOPO Siitarilla: hint '%s', ovi %s parkki %s" % [main._hint.text, vl.siitari_door, vl.siitari_park])
			Input.action_press("interact")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			print("MOPO baari: tila %s, valikko auki %s, viesti: %s" % [main.state, main._item_menu.is_open(), main._msg.text])
			main._item_menu.hide()
			main._on_siitari("lahde")
			print("MOPO paluu: kohde %s, aktiivinen %s, %s" % [main.mopo_trip.target, main.mopo_trip.active, main.mopo_trip.status.replace("\n", " / ")])
			mp.position = vl.road_pos(30) + Vector3(0, 0.6, 0)
			for i in 20:
				await main.get_tree().physics_frame
			print("MOPO Paapelin tiellä: matka jatkuu %s, hint '%s'" % [main.mopo_trip.active, main._hint.text])
			# Pihaan ajettaessa kartta vaihtuu mökille itsestään (ei E:tä).
			mp.position = vl.mokki_mopo + (vl.road_pos(3) - vl.mokki_mopo).normalized() * 6.0 + Vector3(0, 0.6, 0)
			for i in 20:
				await main.get_tree().physics_frame
			var wl2: Vector3 = main.mokki.to_local(main.walker_out.global_position)
			print("MOPO kotona: tila %s, kävelijä mökillä %.1f %.1f, mopo pihassa %s" % [main.state, wl2.x, wl2.z, main.mokki.mopo_parked.visible])
			# Toinen kerta: kalja Siitarissa -> Santtu hakee.
			main._start_mopo()
			mp.position = vl.siitari_park + Vector3(0, 0.5, 0)
			for i in 10:
				await main.get_tree().physics_frame
			main.mopo_trip.stop()
			main._on_mopo_arrived()
			var m0 := main.money
			main._item_menu.hide()
			main._on_siitari("karhu")
			await main.get_tree().process_frame
			main._item_menu.hide()
			main._on_siitari("lahde")
			print("MOPO kalja: rahaa %.2f -> %.2f, humala %.2f, tila %s, viesti: %s" % [m0, main.money, main.tilat.value("humala"), main.state, main._msg.text])
			# Vaalan pankkiautomaatti ja auton alle jääminen: auto takaa täydellä vauhdilla, mopo seisoo kaistalla.
			main._start_mopo()
			mp.position = vl.atm_pos + Vector3(0, 0.5, 0)
			mp.speed = 0.0
			for i in 10:
				await main.get_tree().physics_frame
			var m1 := main.money
			print("MOPO otto: hint '%s'" % main._hint.text)
			Input.action_press("interact")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("interact")
			print("MOPO otto: rahaa %.2f -> %.2f, viesti: %s" % [m1, main.money, main._msg.text])
			var si2 := 300
			var d2: Vector3 = vl.road_dir(si2)
			mp.position = vl.road_pos(si2) + d2.cross(Vector3.UP) * 1.6 + Vector3(0, 0.5, 0)
			mp.rotation.y = atan2(-d2.x, -d2.z)
			mp.speed = 0.0
			var car0: Node3D = main.mopo_trip._cars[0]
			car0.set_line_t(float(si2 - 5), 1)
			for i in 90:
				await main.get_tree().physics_frame
				if main.state == "cutscene":
					break
			await snap.call("_kuolema.png")
			print("MOPO kolari: tila %s, alaotsikko: %s" % [main.state, main.cutscene._sub.text])
			for i in 900:
				await main.get_tree().process_frame
				if main.state != "cutscene":
					break
			print("MOPO kolarin jälkeen: tila %s, kotona %s, päivä %d" % [main.state, main.player.global_position.distance_to(main.home_zone) < 12.0, main.day])
		"mokkiviina":
			# Viinakätköt: paikat, HUD:n suunta ja matka kätkön vieressä (kuva _hud), kävely kätkölle ja avaus E:llä.
			main.viina_found = []
			main._toggle_mount()
			var vp: Array[Vector2] = Mokki.viina_positions()
			print("VIINA paikat ", vp, " mökistä ", vp.map(func(q: Vector2) -> int: return roundi(q.distance_to(Mokki.COTTAGE_LOCAL))))
			var q0: Vector2 = vp[0]
			var toward := (Mokki.COTTAGE_LOCAL - q0).normalized()
			main.walker_out.global_position = main.mokki.gpos(Vector3(q0.x + toward.x * 7.0, 0.6, q0.y + toward.y * 7.0))
			main.walker_out.look_at(main.mokki.gpos(Vector3(q0.x, 0.6, q0.y)))
			for i in 60:
				await main.get_tree().physics_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_hud.png"))
			print("VIINA HUD ", main._stats.text.replace("\n", " | "))
			var vc := Camera3D.new()
			main.add_child(vc)
			vc.look_at_from_position(main.mokki.gpos(Vector3(q0.x + 1.6, 1.1, q0.y + 1.2)), main.mokki.gpos(Vector3(q0.x, 0.1, q0.y)))
			vc.current = true
			main._hud.visible = false
			for i in 4:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_katko.png"))
			main._hud.visible = true
			vc.queue_free()
			main.walker_out.activate_camera()
			Input.action_press("forward")
			for i in 300:
				await main.get_tree().physics_frame
				if main._viina_nearest()[2] < 1.2:
					break
			Input.action_release("forward")
			print("VIINA matka %.2f vihje '%s'" % [main._viina_nearest()[2], main._hint.text])
			Input.action_press("interact")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("interact")
			print("VIINA löydetyt ", main.viina_found, " pullot ", main.viina_pullot, " viesti: ", main._msg.text)
		"mokkiview", "mokkisauna", "mokkiyard", "mokkilake":
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.to_global(Vector3(-2, 0.4, -14))
			for i in 40:
				await main.get_tree().process_frame
			var cam4 := Camera3D.new()
			main.add_child(cam4)
			cam4.fov = 60
			if scene == "mokkiview":
				cam4.look_at_from_position(main.mokki.to_global(Vector3(-16, 9, -22)), main.mokki.to_global(Vector3(2, 1.5, -1)), Vector3.UP)
			elif scene == "mokkisauna":
				cam4.look_at_from_position(main.mokki.to_global(Vector3(0, 3.5, 12)), main.mokki.to_global(Vector3(9, 1.2, 6.5)), Vector3.UP)
				main.mokki.set_sauna_fire(true)
				main.mokki.set_tub_fire(true)
			elif scene == "mokkiyard":
				cam4.look_at_from_position(main.mokki.to_global(Vector3(9, 5, -6)), main.mokki.to_global(Vector3(2, 1.0, -6)), Vector3.UP)
			else:
				cam4.look_at_from_position(main.mokki.to_global(Vector3(-4, 4, 20)), main.mokki.to_global(Vector3(7, 1.2, 24)), Vector3.UP)
			cam4.current = true
		"mokkipingis":
			# Pingis Santun kanssa: pelaaja lyö automaattisesti, kun pallo on ulottuvilla. Tulostaa pisteet.
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.to_global(Vector3(Mokki.PINGIS_LOCAL.x, Mokki.h(Mokki.PINGIS_LOCAL.x, Mokki.PINGIS_LOCAL.z) + 0.4, Mokki.PINGIS_LOCAL.z + 1.6))
			for i in 10:
				await main.get_tree().physics_frame
			print("PINGIS hint: ", main._hint.text)
			main._start_pingis()
			var pg: Node3D = main.get_children().filter(func(c): return c is PingisGame)[0]
			var shot_taken := false
			for i in 60 * 40:
				await main.get_tree().process_frame
				if not is_instance_valid(pg) or pg._phase == "done":
					break
				if pg._phase == "serve" and pg._server == 0:
					pg._serve(0)
				elif pg._phase == "rally" and pg._last == 1 and pg._pl[0].swing_t < 0.0:
					pg._pl[0].x = move_toward(pg._pl[0].x, clampf(pg._land_x(PingisGame.HIT_Y) - 0.45, -PingisGame.X_MAX, -PingisGame.X_MIN), 0.06)
					if pg._ball.distance_to(pg._paddle(0)) < 0.6 and randf() < 0.93:
						pg._swing(0, "smash" if pg._ball.y > 1.8 else "normal", 0.0)
				if not shot_taken and pg._rally >= 3:
					shot_taken = true
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_rally.png"))
				if i % 300 == 0:
					print("PINGIS t=%d phase=%s rounds=%s rally=%d" % [i / 60, pg._phase, pg._rounds, pg._rally])
			print("PINGIS end state=", main.state, " msg=", main._msg.text)
		"mokkitikka":
			# Tikanheitto: pisteytyksen tarkistus, 9 heittoa (tähtäys triplakahteenkymppiin) ja kuva taulusta.
			for pt in [Vector2.ZERO, Vector2(0, 0.012), Vector2(0, 0.103), Vector2(0, 0.166), Vector2(0.103, 0), Vector2(0, 0.2)]:
				print("TIKKA piste %s -> %s" % [pt, DartsGame.score(pt)])
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.to_global(Vector3(Mokki.DART_LOCAL.x, Mokki.h(Mokki.DART_LOCAL.x, Mokki.DART_LOCAL.z) + 0.4, Mokki.DART_LOCAL.z))
			for i in 10:
				await main.get_tree().physics_frame
			print("TIKKA vihje: ", main._hint.text)
			main._start_darts()
			var dg: Node3D = main.mokki.get_children().filter(func(c): return c is DartsGame)[0]
			for i in 30:
				await main.get_tree().process_frame
			for n in 9:
				dg._aim = Vector2(0, 0.103)
				while dg._phase != "aim":
					await main.get_tree().process_frame
				dg._aim = Vector2(randf_range(-0.03, 0.03), 0.103 + randf_range(-0.03, 0.03))
				dg._throw()
				while dg._phase == "fly":
					await main.get_tree().process_frame
				print("TIKKA heitto %d: %s" % [n + 1, dg._sub.text])
				if n == 2:
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_taulu.png"))
			while is_instance_valid(dg):
				await main.get_tree().process_frame
			print("TIKKA loppu: ennätys=%d msg=%s" % [main.tikka_ennatys, main._msg.text])
			# Mökkitikka: pisteytys renkaittain, 15 heittoa keskustaan, kuva taulusta ja pihalta molemmat taulut.
			for pt in [Vector2.ZERO, Vector2(0.02, 0), Vector2(0, 0.05), Vector2(0.1, 0.1), Vector2(0, 0.205), Vector2(0, 0.22)]:
				print("MTIKKA piste %s -> %s" % [pt, DartsGame.score_mokki(pt)])
			if DartsGame.score_mokki(Vector2.ZERO)[0] != 10 or DartsGame.score_mokki(Vector2(0, 0.205))[0] != 1 or DartsGame.score_mokki(Vector2(0, 0.22))[0] != 0:
				print("TESTI VIKA mökkitikan pisteytys")
			main.walker_out.global_position = main.mokki.to_global(Vector3(Mokki.MTIKKA_LOCAL.x, Mokki.h(Mokki.MTIKKA_LOCAL.x, Mokki.MTIKKA_LOCAL.z) + 0.4, Mokki.MTIKKA_LOCAL.z))
			for i in 10:
				await main.get_tree().physics_frame
			print("MTIKKA vihje: ", main._hint.text)
			if not "mökkitikkaa" in main._hint.text:
				print("TESTI VIKA mökkitikan vihje puuttuu")
			main._start_darts("mokki")
			var mg: Node3D = main.mokki.get_children().filter(func(c): return c is DartsGame)[0]
			for i in 30:
				await main.get_tree().process_frame
			for n in 15:
				while mg._phase != "aim":
					await main.get_tree().process_frame
				mg._aim = Vector2(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04))
				mg._throw()
				while mg._phase == "fly":
					await main.get_tree().process_frame
				if n == 4:
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_mokkitaulu.png"))
			while is_instance_valid(mg):
				await main.get_tree().process_frame
			print("MTIKKA loppu: ennätys=%d msg=%s" % [main.mtikka_ennatys, main._msg.text])
			main._after_darts(200, 10, "darts")
			main._after_darts(140, 10, "mokki")
			var tk: Array = main.journal_data().side.filter(func(q): return q.id == "tikkamestari")
			print("MTIKKA päiväkirja: %s" % [tk.map(func(q): return "%s (%s) tehty %s" % [q.title, q.progress, q.done])])
			if tk.is_empty() or not tk[0].done:
				print("TESTI VIKA Tikkamestari puuttuu päiväkirjasta tai ei valmistu voitoista")
			if main.mtikka_ennatys <= 0:
				print("TESTI VIKA mökkitikan tulos ei tallentunut")
			var pc := Camera3D.new()
			main.mokki.add_child(pc)
			var mid := (Mokki.DART_TREE + Mokki.MTIKKA_TREE) / 2.0
			pc.look_at_from_position(main.mokki.to_global(mid + Vector3(0, Mokki.h(mid.x, mid.z) + 1.7, -5.5)), main.mokki.to_global(mid + Vector3(0, Mokki.h(mid.x, mid.z) + 1.4, 0)))
			pc.current = true
			for i in 5:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_taulut.png"))
		"mokkisavustus":
			# Savustus: saalis savustimeen, halkoja, valmis, eväiksi ja syönti.
			main._toggle_mount()
			main.saalis = [{"type": "kala", "nom": "hauki"}, {"type": "riista", "nom": "jänis"}]
			var kp := Mokki.KITCHEN_LOCAL
			main.walker_out.global_position = main.mokki.to_global(Vector3(kp.x, Mokki.h(kp.x, kp.z) + 0.4, kp.z))
			var press3 := func() -> void:
				Input.action_press("interact")
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
			for i in 10:
				await main.get_tree().physics_frame
			print("SAVU hint: ", main._hint.text)
			await press3.call()
			print("SAVU loaded=", main.smoker_load, " msg=", main._msg.text)
			for k in 3:
				await press3.call()
			var t_end := Time.get_ticks_msec() + 900000  # yläraja: hitaalla koneella savustus kestää pitkään
			var n := 0
			while Time.get_ticks_msec() < t_end:
				n += 1
				await main.get_tree().process_frame
				if main.smoker_temp < 95.0 and main.smoker_fuel < 0.35 and n % 20 == 0:
					await press3.call()
				if n % 600 == 0:
					print("SAVU t=%d temp=%.0f fuel=%.2f progress=%.2f burnt=%.2f hint=%s" % [n / 60, main.smoker_temp, main.smoker_fuel, main.smoker_progress, main.smoker_burnt, main._hint.text])
				if main.smoker_progress >= 1.0:
					break
			var cam5 := Camera3D.new()
			main.add_child(cam5)
			cam5.look_at_from_position(main.mokki.to_global(kp + Vector3(3.0, 2.2, -2.5)), main.mokki.to_global(kp + Vector3(0, 1.0, 1.0)), Vector3.UP)
			cam5.current = true
			for i in 30:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_smoke.png"))
			main.player.activate_camera()
			await main.get_tree().process_frame
			print("SAVU done progress=%.2f hint=%s state=%s" % [main.smoker_progress, main._hint.text, main.state])
			await press3.call()
			print("SAVU out food=", main.food, " msg=", main._msg.text)
			var n0: float = main.tilat.value("nalka")
			main._on_eat("savuriista")
			print("SAVU ate nalka %+.2f food=%s" % [main.tilat.value("nalka") - n0, main.food])
		"mokkipesuovi":
			# Pesuhuoneen ovi: kuistilta sisään pesuhuoneeseen, pesuhuoneen ovesta ulos saman oven eteen, kuva ovesta.
			var press2 := func() -> void:
				Input.action_press("interact")
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.porch2_pos(0.4)
			for i in 10:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("PESUOVI kuistilla hint=", main._hint.text)
			await press2.call()
			print("PESUOVI sisällä state=%s walker=%s" % [main.state, main.mokki_int.walker.position])
			for i in 5:
				await main.get_tree().process_frame
			print("PESUOVI sisävihje=", main.mokki_int.hint)
			await press2.call()
			for i in 5:
				await main.get_tree().physics_frame
			var lp := main.mokki.to_local(main.walker_out.global_position)
			print("PESUOVI ulkona state=%s paikka=%s (ovi %s)" % [main.state, lp, Mokki.DOOR2_LOCAL])
			var oc := Camera3D.new()
			main.add_child(oc)
			oc.look_at_from_position(main.mokki.porch2_pos(4.5) + Vector3(1.5, 0.6, 0), main.mokki.porch2_pos(-0.6) + Vector3(0, 0.3, 0), Vector3.UP)
			oc.current = true
		"mokkisisalla":
			# Mökin sisätila: ovelta sisään, toiminnot, kuva, ulos ja nukkumaan (päivä vaihtuu). Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var press := func(action: String) -> void:
				await main.get_tree().process_frame  # painallus ennen solmujen _processia (just_pressed samassa ruudussa)
				Input.action_press(action)
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.porch_pos(0.4)
			for i in 10:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("SISA ovella hint=", main._hint.text)
			await press.call("interact")
			print("SISA state=", main.state, " hint=", main._hint.text)
			for id in ["kahvi", "jaakaappi", "takka", "tv", "suihku", "wc", "sauna"]:
				main.mokki_int.walker.position = main.mokki_int.SPOTS[id][0]
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				var h: String = main.mokki_int.hint
				await press.call("interact")
				print("SISA %s: hint=%s -> msg=%s" % [id, h, main._msg.text])
			print("SISA tilat: ", main.tilat.summary(), " food=", main.food)
			main.mokki_int.walker.position = Vector3(-1.0, 0, 1.0)
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_tupa.png"))
			await main.get_tree().process_frame
			main.mokki_int.walker.position = Vector3(3.0, 0, -3.8)
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_pesu.png"))
			main.mokki_int.walker.position = main.mokki_int.SPOTS.ovi2[0]
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			print("SISA ovi2 hint=", main.mokki_int.hint)
			main.mokki_int.walker.position = main.mokki_int.SPOTS.ovi[0]
			await main.get_tree().process_frame
			await press.call("interact")
			for i in 5:
				await main.get_tree().physics_frame
			print("SISA ulos state=%s porch_y=%.2f" % [main.state, main.mokki.to_local(main.walker_out.global_position).y])
			main.walker_out.global_position = main.mokki.porch_pos(0.4)
			for i in 5:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			await press.call("interact")
			main.mokki_int.walker.position = main.mokki_int.SPOTS.sanky[0]
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			var d0 := main.day
			await press.call("interact")
			for i in 10:
				await main.get_tree().process_frame
			print("SISA nukuttu day %d -> %d state=%s near_mokki=%.1f msg=%s" % [d0, main.day, main.state,
				main.walker_out.global_position.distance_to(main.mokki.global_position), main._msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"mokkipa":
			# PA-kytkentä: väärä järjestys (pääte ensin = paukku), oikeat johdot, virrat, kierto mikistä, tasot
			# vihreälle ja voitto. Kuvat: _pa_board (kesken), _pa_tupa (soi) ja _pa_ulkona. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(suffix: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", suffix))
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.porch_pos(0.4)
			for i in 10:
				await main.get_tree().physics_frame
			main._enter_mokki()
			main.mokki_int.walker.position = main.mokki_int.SPOTS.pa[0]
			for i in 3:
				await main.get_tree().process_frame
			print("PA hint=", main.mokki_int.hint)
			main._on_mokki_acted("pa")
			var pg: Node = main.get_children().filter(func(c): return c is PaGame)[0]
			print("PA virhe tyyppi: ", pg.connect_ports("puh_out", "mix_ch1"), " -> ", pg._sub.text)
			for pr in [["puh_out", "mix_ch2"], ["mic_out", "mix_ch1"], ["mix_main_l", "amp_in_a"], ["mix_main_r", "amp_in_b"],
					["amp_out_a", "spk_l_in"], ["amp_out_b", "spk_r_in"], ["jj_1", "mix_pow"], ["amp_pow", "jj_2"]]:
				if not pg.connect_ports(pr[0], pr[1]):
					print("PA kytkentä epäonnistui ", pr, " ", pg._sub.text)
			print("PA path_ok=", pg.path_ok(), " task=", pg._task.text)
			pg.amp_sw = true
			for i in 3:
				await main.get_tree().process_frame
			print("PA pääte ensin: strikes=", pg.strikes, " sub=", pg._sub.text)
			pg.amp_sw = false
			await main.get_tree().process_frame
			pg.mix_sw = true
			await main.get_tree().process_frame
			pg.amp_sw = true
			await main.get_tree().process_frame
			print("PA oikea järjestys: strikes=", pg.strikes, " task=", pg._task.text)
			pg.faders.ch1 = 0.8
			pg.faders.master = 0.8
			for i in 60:
				await main.get_tree().process_frame
			print("PA kierto fb=%.2f sub=%s" % [pg._fb, pg._sub.text])
			pg.faders.ch1 = 0.0
			pg.faders.ch2 = 0.8
			for i in 10:
				await main.get_tree().process_frame
			print("PA taso=%.2f soi=%s task=%s" % [pg.out_level, main.mokki_int._pa_players[0].playing, pg._task.text])
			await snap.call("_pa_board.png")
			var t0 := Time.get_ticks_msec()
			while is_instance_valid(pg) and Time.get_ticks_msec() - t0 < 8000:
				await main.get_tree().process_frame
			print("PA valmis: pa_on=%s strikes? msg=%s soi=%s db=%.1f" % [main.mokki_int.pa_on, main._msg.text,
				main.mokki_int._pa_players[0].playing, main.mokki_int._pa_players[0].volume_db])
			main.mokki_int.walker.position = Vector3(-2.0, 0, 0.5)
			for i in 20:
				await main.get_tree().process_frame
			await snap.call("_pa_tupa.png")
			main.mokki_int.walker.position = main.mokki_int.SPOTS.ovi[0]
			await main.get_tree().process_frame
			main._on_mokki_exited()
			for i in 20:
				await main.get_tree().process_frame
			print("PA ulkona: soi=%s" % main.mokki._pa_out.playing)
			await snap.call("_pa_ulkona.png")
			main._enter_mokki()
			main.mokki_int.walker.position = main.mokki_int.SPOTS.pa[0]
			for i in 3:
				await main.get_tree().process_frame
			print("PA hint päällä=", main.mokki_int.hint)
			main._on_mokki_acted("pa")
			print("PA sammutus: pa_on=%s soi=%s ulkona=%s" % [main.mokki_int.pa_on, main.mokki_int._pa_players[0].playing,
				main.mokki._pa_out.playing])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"mokkipuuhat":
			# Santun puuhastelu: jokainen puuhapaikka vuorollaan (kuva _p_<id>.png), sitten vapaa puuhastelu
			# minuutin ajan (Santun tila tulostetaan) ja väistö, kun pelaaja tulee puuhapaikalle.
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.gpos(Vector3(-2.0, 0.4, -14.0))
			for i in 20:
				await main.get_tree().process_frame
			var pu: Node = main.mokki.puuhat
			var pc := Camera3D.new()
			main.add_child(pc)
			for id in pu.spot_ids():
				pu.debug_start(id)
				var at: Vector3 = pu.spot_at(id)
				var sp: Vector3 = main.mokki.santtu.position
				# Odotetaan, että Santtu tekee puuhaa (enintään 2,5 s pelin aikaa; ennen 150 ruutua, hitaalla koneella ~3 min/paikka).
				var pt := 0.0
				while pt < 2.5 and not pu.working():
					await main.get_tree().process_frame
					pt += main.get_process_delta_time()
				for k in 20:
					await main.get_tree().process_frame
				sp = main.mokki.santtu.position
				var away := Vector3(3.2, 2.0, -3.2) if id != "onki" and id != "naputus" else Vector3(-3.0, 1.8, -3.0)
				pc.look_at_from_position(main.mokki.to_global(sp + away), main.mokki.to_global(sp + Vector3(0, 1.0, 0)), Vector3.UP)
				pc.current = true
				for k in 10:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_p_%s.png" % id))
				print("PUUHA %s working=%s anim=%s visible=%s bubble=%s" % [id, pu.working(), main.mokki.santtu.current(),
					main.mokki.santtu.visible, main.mokki._bubble.text])
			pc.current = false
			# Reitit kannolta jokaiselle puuhapaikalle: ei rakennusten, pihan esineiden, puiden eikä veden läpi.
			for id in pu.spot_ids():
				var at: Vector3 = pu.spot_at(id)
				var t0 := Time.get_ticks_usec()
				var route: Array = main.mokki._route(Vector2(Mokki.SANTTU_LOCAL.x, Mokki.SANTTU_LOCAL.z + 0.6), Vector2(at.x, at.z))
				var us := Time.get_ticks_usec() - t0
				var hits := 0
				var from := Vector2(Mokki.SANTTU_LOCAL.x, Mokki.SANTTU_LOCAL.z + 0.6)
				var length := 0.0
				for k in route.size():
					var q: Vector2 = route[k]
					var n := maxi(1, ceili(from.distance_to(q) / 0.2))
					for m in range(1, n):
						var c: Vector2 = from.lerp(q, float(m) / n)
						if not main.mokki._free(main.mokki._cell(c)) and c.distance_to(Vector2(at.x, at.z)) > 1.0 and m > 2:
							hits += 1
					length += from.distance_to(q)
					from = q
				print("REITTI %s: %d pistettä, %.0f m, %.1f ms, esteissä %d" % [id, route.size(), length, us / 1000.0, hits])
			main.walker_out.activate_camera()
			pu._abort()
			main.mokki.santtu_go_home()
			pu._t = 1.0
			var seen := {}
			# 90 s pelin aikaa, ei 5400 ruutua: hitaalla koneella (llvmpipe) ruutulaskuri venyi yli 40 minuuttiin.
			var game_t := 0.0
			while game_t < 90.0:
				await main.get_tree().process_frame
				game_t += main.get_process_delta_time()
				var cid: String = pu.current_id()
				if cid != "" and not seen.has(cid):
					seen[cid] = true
					print("PUUHA vapaa t=%d -> %s (%s)" % [int(game_t), cid, pu._state])
			print("PUUHA vapaa paikat=%s" % [seen.keys()])
			# Väistö: pelaaja tikkataululle, kun Santtu heittää.
			pu.debug_start("tikka")
			await main.get_tree().process_frame
			main.walker_out.global_position = main.mokki.gpos(Mokki.DART_LOCAL + Vector3(0.5, 0.4, 0.3))
			for k in 30:
				await main.get_tree().process_frame
			print("PUUHA väistö state=%s bubble=%s" % [pu._state, main.mokki._bubble.text])
		"mokkisavusauna":
			# Savusauna: ovi ja terassi järvelle yhteisen harjakaton alla, kävely terassilta sisään ja löylyvälianimaatio.
			var sc0 := Mokki.SAUNA_C
			var prof := []
			for z in [17.0, 19.0, 21.0, 22.5, 24.0]:
				prof.append("%.0f:%.2f" % [z, Mokki.h(sc0.x, z) - Mokki.h(sc0.x, sc0.z)])
			print("SAUNA rinne ", " ".join(prof))
			var ec := Camera3D.new()
			main.add_child(ec)
			ec.current = true
			main.walker_out.visible = false
			for v in [["ulko", Vector3(3.5, 2.2, 10.0), Vector3(0, 1.2, 1.5)], ["sivu", Vector3(-8.0, 2.8, 4.0), Vector3(0, 1.2, 1.0)],
					["taka", Vector3(-4.0, 3.5, -8.0), Vector3(0, 1.2, 0.5)]]:
				ec.look_at_from_position(main.mokki.gpos(sc0 + v[1]), main.mokki.gpos(sc0 + v[2]), Vector3.UP)
				for i in 6:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % v[0]))
			ec.queue_free()
			main.walker_out.visible = true
			main._toggle_mount()
			var sb: Vector3 = main.mokki._sauna_body.position
			var walk := func(from: Vector3, to: Vector3, frames: int, what: String) -> void:
				if from != Vector3.INF:
					main.walker_out.global_position = main.mokki.gpos(sc0 + from)
				main.walker_out.look_at(main.mokki.gpos(sc0 + to) + Vector3(0, main.walker_out.global_position.y - main.mokki.gpos(sc0 + to).y, 0))
				for i in 10:
					await main.get_tree().physics_frame
				Input.action_press("forward")
				for i in frames:
					await main.get_tree().physics_frame
					var cur: Vector3 = main.mokki.to_local(main.walker_out.global_position) - sb
					if Vector2(cur.x - to.x, cur.z - to.z).length() < 0.3:
						break
				Input.action_release("forward")
				var wl: Vector3 = main.mokki.to_local(main.walker_out.global_position) - sb
				print("SAUNA %s: x=%.2f y=%.2f z=%.2f" % [what, wl.x, wl.y, wl.z])
			await walk.call(Vector3(-4.6, 0.5, 2.2), Vector3(Mokki.SAUNA_DOOR_X, 0, 2.2), 300, "portaat ylös (kansi y 0.15)")
			await walk.call(Vector3.INF, Vector3(Mokki.SAUNA_DOOR_X, 0, 0.0), 200, "ovesta sisään (lattia y 0.09, z 0)")
			var nc := Camera3D.new()
			main.add_child(nc)
			nc.look_at_from_position(main.mokki.to_global(sb + Vector3(-5.0, 1.4, 4.6)), main.mokki.to_global(sb + Vector3(-1.5, 0.2, 2.2)), Vector3.UP)
			nc.current = true
			for i in 6:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_portaat.png"))
			nc.queue_free()
			main.walker_out.activate_camera()
			main.beers = 1
			main._sauna_cutscene()
			for k in 22:
				await main.get_tree().create_timer(0.9).timeout
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_cs%02d.png" % k))
		_:
			return 0
	return 1
