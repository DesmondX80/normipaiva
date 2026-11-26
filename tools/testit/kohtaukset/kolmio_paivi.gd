extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "kolmio_paivi". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const M := preload("res://scripts/map_data.gd")
const TanssiGame := preload("res://scripts/tanssi_game.gd")

const KOHTAUKSET := ["parkit", "kolmio_iltakivat", "kolmio_tuppi", "kolmiomittaus_koti", "kolmio_juttu", "paivipartio", "paivihyvitys", "paivihalytys", "paivikoti", "paivin_puhelu"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"parkit":
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
		"kolmio_juttu":
			for i in 5:
				await main.get_tree().process_frame
			for nm in [0, 1]:
				for off in [Vector3(0, 0, 1.5), Vector3(1.5, 0, 0), Vector3(0, 0, 3.0), Vector3(0, 0, 4.5)]:
					main.walker_out.speed = 0.0
					for i in 4:
						await main.get_tree().process_frame
					var near_d := INF
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
		"paivin_puhelu":
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
