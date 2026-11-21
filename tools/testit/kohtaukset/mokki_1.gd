extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "mokki_1". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.

const Main := preload("res://scripts/main.gd")
const B := preload("res://scripts/build.gd")
const ShopInterior := preload("res://scripts/shop_interior.gd")
const Mokki := preload("res://scripts/mokki.gd")
const LavaGame := preload("res://scripts/lava_game.gd")
const Hommat := preload("res://scripts/santun_hommat.gd")
const LaituriGame := preload("res://scripts/laituri_game.gd")
const TiskiGame := preload("res://scripts/tiski_game.gd")
const Atm := preload("res://scripts/atm.gd")
const HuntGame := preload("res://scripts/hunt_game.gd")
const FishGame := preload("res://scripts/fish_game.gd")

const KOHTAUKSET := ["mokkilava", "mokkikauppa", "mokkialikulku", "mokkijuna", "mokkikaatuminen", "mokkiasema", "mokkilavaportti", "mokkikauppaauto", "mokkilama", "mokkihotelli", "mokkikahlaus", "mokkijuhannus", "mokkiaukiolot", "mokkikiihdytys", "mokkibotti", "mokkiajoalue", "mokkijarvi_e", "mokkilahto", "mokkijuoksu", "mokkieat", "mokkifish", "mokkielukat", "mokkielukat2", "mokkijahti", "mokkidrooni", "mokkihommat", "mokkikartta", "mokkiilma", "mokkikaide", "mokkilaituri", "mokkikanto", "kuisti"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"mokkilava":
			# Oulujärven lava: mopo ovelle (vihje), ulkokuva, lavatanssit (kuva), lopetus ja takaisin mopolle.
			main._start_mopo()
			var vl2: Node3D = main.mopo_trip.vaala
			var mpl: CharacterBody3D = main.mopo_trip.mopo
			mpl.position = vl2.lava_door + Vector3(0, 0.6, 0)
			mpl.speed = 0.0
			main.money = 40.0
			for i in 30:
				await main.get_tree().process_frame
			print("LAVA ovi ", vl2.lava_door, " keskus ", vl2.lava_center, " vihje: ", main.mopo_trip.hint)
			var lc := Camera3D.new()
			lc.far = 3000.0
			main.add_child(lc)
			lc.look_at_from_position(main.mopo_trip.to_global(vl2.lava_door + vl2.lava_out * 30.0 + Vector3(-25, 18, 30)),
				main.mopo_trip.to_global(vl2.lava_center))
			lc.current = true
			for i in 30:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_ulko.png"))
			main._lava_gate()  # lippu portilta (leima), sitten ovesta sisään
			main._enter_lava()
			for i in 20:
				await main.get_tree().process_frame
			# Baari, sitten yleiskuvat tanssipuolelta (bändi ja baari) ja diskosta.
			var mb := main.money
			main._lava_game._order()
			print("LAVA baari: rahaa %.2f -> %.2f, teksti '%s'" % [mb, main.money, main._lava_game._info.text.get_slice("\n", 0)])
			var lg: Node3D = main._lava_game
			for v in [["_bandi.png", Vector3(8, 4.5, 4), Vector3(0, 2, -19)], ["_baari.png", Vector3(-lg.door_side * 9.5, 2.0, 0.5), Vector3(-lg.door_side * 16, 1.3, -4.5)],
					["_disko.png", Vector3(10, 3.5, 9.5), Vector3(-2, 1.0, 18)]]:
				lg._cam.look_at_from_position(lg.to_global(v[1]), lg.to_global(v[2]))
				lg.set_process(false)
				for i in 10:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", v[0]))
				lg.set_process(true)
			main._lava_game._start_dance("disco")
			for i in 40:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_diskotanssi.png"))
			main._lava_game._hits = 20
			for i in 60:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_tanssi.png"))
			main._lava_game._t = LavaGame.SONG
			for i in 5:
				await main.get_tree().process_frame
			var m0 := main.mielihyva
			main._lava_game.finished.emit(main._lava_game._score())
			for i in 10:
				await main.get_tree().process_frame
			print("LAVA ohi: tila %s, rahaa %.2f, mielihyvä %.1f -> %.1f, mopo aktiivinen %s" % [main.state, main.money, m0, main.mielihyva, main.mopo_trip.active])
			main.get_tree().quit()
		"mokkikauppa":
			# K-Market Tervaportti Vaalassa: mopo oven eteen (vihje), kauppaan, Alkon hylly, ulos ja takaisin mopolle.
			main._start_mopo()
			var vk: Node3D = main.mopo_trip.vaala
			var mpk: CharacterBody3D = main.mopo_trip.mopo
			mpk.position = vk.kmarket_door + Vector3(0, 0.6, 0)
			mpk.speed = 0.0
			for i in 30:
				await main.get_tree().process_frame
			print("VAALAKAUPPA ovi ", vk.kmarket_door, " automaatti ", vk.atm_pos, " vihje: ", main.mopo_trip.hint)
			var occ := Camera3D.new()
			main.add_child(occ)
			occ.look_at_from_position(main.mopo_trip.to_global(vk.kmarket_door + vk.kmarket_out * 14.0 + Vector3(0, 5, 0)),
				main.mopo_trip.to_global(vk.kmarket_door))
			occ.current = true
			for i in 20:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_ulko.png"))
			main._enter_vaala_shop()
			main.interior.walker.position = ShopInterior.ALKO_SPOT
			main.interior.walker.rotation.y = PI / 2.0
			for i in 40:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_alko.png"))
			print("VAALAKAUPPA alkon vihje: ", main.interior.hint)
			main.interior.cart["viina0"] = ShopInterior.ALKO[1]
			main.interior.has_beer = true
			main.interior.has_paid = true
			var pullot0 := main.viina_pullot
			main.interior.exited.emit(true)
			for i in 10:
				await main.get_tree().process_frame
			print("VAALAKAUPPA ulos: tila %s, pulloja %d -> %d, kaljoja %d, mopo aktiivinen %s" % [main.state, pullot0, main.viina_pullot,
				main.beers, main.mopo_trip.active])
			# Juoksukaljat: rahat loppu, kuutonen ja pullo ovesta maksamatta.
			main.money = 1.0
			main._enter_vaala_shop()
			main.interior.has_beer = true
			main.interior.cart["viina0"] = ShopInterior.ALKO[1]
			main.interior.cart["makkara"] = 3.0
			main.interior.walker.position = ShopInterior.DOOR
			Input.action_press("interact")
			for i in 3:
				await main.get_tree().process_frame
			Input.action_release("interact")
			for i in 10:
				await main.get_tree().process_frame
			print("VAALAKAUPPA juoksukaljat: tila %s, raha %.2f, pulloja %d, kaljoja %d, makkara %s, viesti '%s'" % [main.state, main.money,
				main.viina_pullot, main.beers, main.has_sausage, main._msg.text.replace("\n", " | ")])
		"mokkialikulku":
			# Radan alikulku: metsä piiloon, ylhäältä, sivulta ja ajajan silmin, sekä maan korkeus tien poikki.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			main._msg.text = ""
			main._note.visible = false
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			for c in vl.get_children():
				if c is Node3D and c.get_script() == load("res://scripts/forest.gd"):
					c.visible = false
			var oc := Camera3D.new()
			oc.far = 3000.0
			main.add_child(oc)
			var g := func(v: Vector3) -> Vector3: return main.mopo_trip.to_global(v)
			var snap := func(name: String, from: Vector3, to: Vector3) -> void:
				oc.look_at_from_position(g.call(from), g.call(to), Vector3.FORWARD if from.x == to.x and from.z == to.z else Vector3.UP)
				oc.current = true
				for i in 20:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			var ui: int = vl.underpass_i
			var up: Vector3 = vl.road_pos(ui)
			var ud: Vector3 = vl.road_dir(ui)
			var ur := ud.cross(Vector3.UP)
			for x in [-12.0, -8.0, -5.0, -3.0, 0.0, 3.0, 5.0, 8.0, 12.0]:
				var q: Vector3 = up + ur * x
				print("ALI poikki %+.0f m: maa %.2f (tie %.2f)" % [x, vl.h(q.x, q.z), up.y])
			await snap.call("_ylha.png", up + Vector3(0, 45, 0), up)
			await snap.call("_sivu.png", up + ur * 30.0 + Vector3(0, 8, 0), up + Vector3(0, 2, 0))
			await snap.call("_tulo.png", vl.road_pos(ui - 20) + Vector3(0, 1.8, 0), up + Vector3(0, 2.0, 0))
			await snap.call("_lahto.png", vl.road_pos(ui + 20) + Vector3(0, 1.8, 0), up + Vector3(0, 2.0, 0))
			await snap.call("_ali.png", vl.road_pos(ui - 3) + Vector3(0, 1.5, 0), vl.road_pos(ui + 6) + Vector3(0, 1.5, 0))
		"mokkijuna":
			# Juna Oulujoen ratasillalla ja radan alikulun yli: kamera paikallaan, juna liikkeelle heti, kuvat 1 s välein.
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
			var tr: Node3D = vl.train
			print("JUNA reitti %d pistettä, pituus %.0f m" % [tr.path.size(), tr._length])
			var ui: int = vl.underpass_i
			var ue: Vector3 = vl.road_pos(ui - 28) + Vector3(0, 1.8, 0)
			for view in [["_silta", Vector3(612, 125.5, -670), Vector3(608, 131, -704), 0], ["_alikulku", ue, vl.road_pos(ui) + Vector3(0, 4.5, 0), 1]]:
				oc.look_at_from_position(main.mopo_trip.to_global(view[1]), main.mopo_trip.to_global(view[2]))
				oc.current = true
				tr.spawn_now(view[3] == 0, view[3])
				var shots := 0
				for i in 60 * 70:
					await main.get_tree().process_frame
					var loco: Node3D = tr._units[0][0] if not tr._units.is_empty() else null
					if loco == null:
						break
					if loco.visible and (loco.position as Vector3).distance_to(view[2]) < 45.0 and i % 50 == 0 and shots < 4:
						await RenderingServer.frame_post_draw
						main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "%s%d.png" % [view[0], shots]))
						shots += 1
					if shots >= 4:
						break
				print("JUNA %s: kuvia %d, keula %.0f m" % [view[0], shots, tr._s])
			main.get_tree().quit()
		"mokkikaatuminen":
			# Mopo kumoon aseman ajotiellä (kaukana päätiestä): nousee ajetulle tielle, ei Paapelin päähän.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			var mp: CharacterBody3D = main.mopo_trip.mopo
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var acc: Array = []
			for r in vl.data.side_roads:
				if r.get("name", "") == "Aseman piha":
					acc = r.pts
			var a := Vector3(acc[0][0], 0, acc[0][1])
			var b := Vector3(acc[1][0], 0, acc[1][1])
			var dir := (b - a).normalized()
			mp.position = a + dir * 8.0 + Vector3(0, vl.h(a.x, a.z) + 0.6, 0)
			mp.rotation.y = atan2(-dir.x, -dir.z)
			Input.action_press("forward", 0.6)
			for i in 150:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			var at := mp.position
			main.mopo_trip._on_crash("ditch")
			for i in 60 * 4:
				await main.get_tree().process_frame
			var sd: Vector3 = vl.station_door
			print("KAATUMINEN kumoon %s, ylös %s (siirtymä %.1f m), asemalle %.0f m, Paapelin päähän %.0f m, pystyssä %s, ohjaus %s" % [at, mp.position,
				Vector2(mp.position.x - at.x, mp.position.z - at.z).length(), Vector2(mp.position.x - sd.x, mp.position.z - sd.z).length(),
				mp.position.distance_to(vl.road_pos(3)), not mp.fallen, mp.controls_enabled])
			main.get_tree().quit()
		"mokkiasema":
			# Vaalan asema ja liikenneympyrä: kuvat ympyrästä, asemasta ja laiturilta sekä mopolla ympyrästä asemalle.
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			var ast: Dictionary = vl.data.keskusta.asema
			var rc := Vector3(ast.roundabout.c[0], 0, ast.roundabout.c[1])
			rc.y = vl.h(rc.x, rc.z)
			var sd: Vector3 = vl.station_door
			await snap.call("_ympyra.png", rc + Vector3(0, 45, 20), rc)
			await snap.call("_ylha.png", sd + Vector3(30, 70, 10), sd + Vector3(30, 0, 0))
			await snap.call("_ovi.png", sd + Vector3(ast.out[0], 0, ast.out[1]) * 18.0 + Vector3(0, 3, 4), sd + Vector3(0, 2, 0))
			var pc := Vector3.ZERO
			for q in ast.platform:
				pc += Vector3(q[0], 0, q[1])
			pc /= float(ast.platform.size())
			pc.y = vl.h(pc.x, pc.z)
			await snap.call("_laituri.png", pc + Vector3(ast.along[0], 0, ast.along[1]) * 30.0 + Vector3(0, 2.5, 0), pc + Vector3(0, 2, 0))
			var tg: Vector3 = vl.station_door
			var mp: CharacterBody3D = main.mopo_trip.mopo
			var si: int = vl.road.size() - 40
			var d: Vector3 = vl.road_dir(si)
			mp.position = vl.road_pos(si) + Vector3(0, 0.6, 0) + d.cross(Vector3.UP) * 1.6
			mp.rotation.y = atan2(-d.x, -d.z)
			mp.activate_camera()
			# Reitti: ympyrän länsilaita ja aseman ajotie (Aseman piha) ympyrästä ovelle.
			var goals: Array = [rc + (vl.road_pos(si) - rc).normalized() * 9.0]
			var chain: Array = []
			var at2 := Vector2(rc.x, rc.z)
			var used := {}
			for step in 10:
				var best_r = null
				var best_d := 25.0
				var rev := false
				for r in vl.data.side_roads:
					if not (r.get("name", "") in ["Ratatie", "Asematie"]) or used.has(r):
						continue
					var a2 := Vector2(r.pts[0][0], r.pts[0][1])
					var b2 := Vector2(r.pts[-1][0], r.pts[-1][1])
					for e in 2:
						var d2 := (a2 if e == 0 else b2).distance_to(at2)
						if d2 < best_d:
							best_d = d2
							best_r = r
							rev = e == 1
				if best_r == null:
					break
				used[best_r] = true
				var rp: Array = best_r.pts.duplicate()
				if rev:
					rp.reverse()
				chain.append_array(rp)
				at2 = Vector2(rp[-1][0], rp[-1][1])
			var acc_start := Vector2.ZERO
			for r in vl.data.side_roads:
				if r.get("name", "") == "Aseman piha":
					acc_start = Vector2(r.pts[0][0], r.pts[0][1])
					var kmin := 0
					for k in chain.size():
						if Vector2(chain[k][0], chain[k][1]).distance_to(acc_start) < Vector2(chain[kmin][0], chain[kmin][1]).distance_to(acc_start):
							kmin = k
					for k in range(0, kmin + 1, 2) if not chain.is_empty() else []:  # Ratatie poistui suorien teiden myötä
						goals.append(Vector3(chain[k][0], 0, chain[k][1]))
					for q in r.pts:
						goals.append(Vector3(q[0], 0, q[1]))
			print("ASEMA reitillä %d tavoitetta, Ratatietä %d pistettä" % [goals.size(), chain.size()])
			var gi := 0
			# --nopeus: täysi kaasu (jarru vain jyrkissä mutkissa), huippunopeus ja pinnat Ratatiellä ja ajotiellä.
			var fast := OS.get_cmdline_user_args().has("--nopeus")
			var top := 0.0
			var codes := {}
			Input.action_press("forward", 1.0 if fast else 0.5)
			for i in 60 * 90:
				await main.get_tree().physics_frame
				if gi >= 2:
					top = maxf(top, mp.speed * 3.6)
					var cd: int = vl.drive_code(mp.position)
					codes[cd] = codes.get(cd, 0) + 1
				var goal: Vector3 = goals[gi]
				var gd := Vector2(mp.position.x - goal.x, mp.position.z - goal.z).length()
				if gd < 4.0:
					if gi == goals.size() - 1:
						break
					gi += 1
				var want := Vector3(goal.x - mp.position.x, 0, goal.z - mp.position.z)
				var err := (-mp.global_transform.basis.z).signed_angle_to(want, Vector3.UP)
				Input.action_press("left", clampf(err * 3.0, 0.0, 1.0))
				Input.action_press("right", clampf(-err * 3.0, 0.0, 1.0))
				if mp.speed > (7.0 if not fast else (6.0 if absf(err) > 0.6 else 99.0)):
					Input.action_press("brake")
				else:
					Input.action_release("brake")
			for a in ["forward", "left", "right", "brake"]:
				Input.action_release(a)
			print("ASEMA huippunopeus %.0f km/h, pinnat (koodi: ruutuja) %s" % [top, codes])
			mp.speed = 0.0
			for i in 20:
				await main.get_tree().physics_frame
			print("ASEMA mopolla ovelta %.1f m, vihje '%s'" % [Vector2(mp.position.x - tg.x, mp.position.z - tg.z).length(), main.mopo_trip.hint])
			var rd := INF
			for q in chain:
				rd = minf(rd, Vector2(q[0] - mp.position.x, q[1] - mp.position.z).length())
			print("ASEMA mopo %s, Ratatiestä %.1f m, ajettava %s, reuna %.2f, tavoite %d/%d %s, seinä %s" % [mp.position, rd,
				vl.drivable(mp.position.x, mp.position.z), mp._curb, gi, goals.size(), goals[gi], mp.is_on_wall()])
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_mopo.png"))
			main.get_tree().quit()
		"mokkilavaportti":
			# Lavan portti: ilman rahaa käännytys, lipulla leima ja portti auki; pummilla järven kautta pihalle ja
			# portsari heittää ulos, kun näkee.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(name: String) -> void:
				for i in 15:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			main._note.visible = false
			main._mopo_dismount()
			var go: Vector3 = vl.gate_out
			main.walker_out.global_position = main.mopo_trip.to_global(go + Vector3(0, 0.5, 0))
			for i in 15:
				await main.get_tree().process_frame
			print("LAVA portilla vihje '%s', portsarin reitti %d pistettä, teinit %s" % [main.mopo_trip.hint, vl.portsari_path.size(), vl.yard_teens_pos])
			main.money = 5.0
			main._on_vaala_door("portti")
			print("LAVA ilman rahaa: leima '%s', viesti '%s'" % [main._lava_pass_now(), main._msg.text])
			await snap.call("_portti.png")
			main.money = 30.0
			main._on_vaala_door("portti")
			for i in 5:
				await main.get_tree().process_frame
			print("LAVA lipulla: leima '%s', rahaa %.2f, portin ovi piilossa %s, lavan vihje '%s'" % [main._lava_pass_now(), main.money,
				main.mopo_trip.door_hidden.call("portti"), main.mopo_trip.lava_hint])
			# Pummireitti: leima pois, rahat loppu, järven kautta pihalle.
			main._lava_pass = ""
			main.money = 0.0
			main.walker_out.global_position = main.mopo_trip.to_global(vl.pummi_out + Vector3(0, 0.5, 0))
			for i in 10:
				await main.get_tree().process_frame
			print("LAVA rannassa vihje '%s'" % main.mopo_trip.hint)
			main._on_vaala_door("pummi")
			for i in 10:
				await main.get_tree().process_frame
			var wl: Vector3 = main.mopo_trip.to_local(main.walker_out.global_position)
			print("LAVA pummilla: pihalla %s, leima '%s', portsari vahtii %s, viesti '%s'" % [vl.in_lava_yard(wl), main._lava_pass_now(), main._portsari.watch, main._msg.text])
			var ps: Vector3 = main._portsari.position
			var fwd: Vector3 = -main._portsari.global_transform.basis.z
			main.walker_out.global_position = main.mopo_trip.to_global(vl.yard_teens_pos + Vector3(2.5, 0.5, 2.5))
			await snap.call("_piha.png")
			var wps: Array[Vector3] = [ps]
			main._portsari.waypoints = wps
			main._portsari.rotation.y = 0.0
			var front: Vector3 = ps + Vector3(0, 0, -4.0)
			main.walker_out.global_position = main.mopo_trip.to_global(front + Vector3(0, 0.5, 0))
			var t0 := Time.get_ticks_msec()
			while main._lava_pass_now() == "pummi" and Time.get_ticks_msec() - t0 < 8000:
				main.walker_out.global_position = main.mopo_trip.to_global(Vector3(front.x, vl.h(front.x, front.z) + 0.5, front.z))
				await main.get_tree().process_frame
			wl = main.mopo_trip.to_local(main.walker_out.global_position)
			print("LAVA portsari: leima '%s', pihalla %s, portilta %.1f m, maine %.0f, viesti '%s'" % [main._lava_pass_now(), vl.in_lava_yard(wl),
				wl.distance_to(vl.gate_out), main.maine, main._msg.text])
			await snap.call("_ulos.png")
			var f := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f.store_buffer(saved)
			f.close()
			main.get_tree().quit()
		"mokkikauppaauto":
			# Kauppa-auto mökillä: tulee Kaisuantietä pihatien päähän, tööttää, luukulla ostokset, lähtee pois.
			var _save_bak := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			main._toggle_mount()
			main._note.visible = false
			main.money = 40.0
			main.beers = 0
			var w0 := main.mokki.to_global(Mokki.RIDE_LOCAL + Vector3(6.0, 0, 3.0))
			main.walker_out.global_position = Vector3(w0.x, main.mokki.global_position.y + Mokki.h(Mokki.RIDE_LOCAL.x + 6.0, Mokki.RIDE_LOCAL.z + 3.0) + 0.5, w0.z)
			main._kauppa_auto_t = Main.KAUPPA_AUTO_DELAY
			var ka: Node3D = main.kauppa_auto
			var t0 := Time.get_ticks_msec()
			var tuli_kuva := false
			Engine.time_scale = 4.0  # ajo nopeammin: hitaalla (ohjelmallisella) renderöinnillä auto ei muuten ehdi 90 s:ssa
			while ka.state != "parked" and Time.get_ticks_msec() - t0 < 90000:
				await main.get_tree().process_frame
				if not tuli_kuva and ka.state == "coming" and ka._i == ka._path.size() - 1 and ka.position.distance_to(ka._path[-1]) < 14.0:
					# Ajossa lähikuva vinosti edestä: Eila ratissa (Vehicles.kuski "hiace"), luukku kiinni.
					tuli_kuva = true
					ka.set_process(false)  # auto paikalleen kuvan ajaksi (hidas renderöinti: muuten se ajaa kameran ohi)
					var tc := Camera3D.new()
					main.add_child(tc)
					var kb: Basis = ka.global_basis
					tc.look_at_from_position(ka.global_position - kb.z * 4.6 - kb.x * 0.8 + Vector3(0, 1.9, 0), ka.global_position + Vector3(0, 1.4, 0) - kb.z * 1.3)
					tc.current = true
					await RenderingServer.frame_post_draw
					main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_tulee.png"))
					tc.queue_free()
					ka.set_process(true)
			Engine.time_scale = 1.0
			print("KAUPPA-AUTO fps %.0f" % Engine.get_frames_per_second())
			print("KAUPPA-AUTO tila '%s' %.0f s, paikka %s, luukku %s, viesti '%s'" % [ka.state, (Time.get_ticks_msec() - t0) / 1000.0,
				ka.position, ka.hatch_pos(), main._msg.text])
			var hp: Vector3 = main.mokki.to_global(ka.hatch_pos())
			main.walker_out.global_position = hp + Vector3(0, 0.5, 0)
			main.walker_out.rotation.y = B.yaw_to(main.mokki.to_global(ka.position) - hp)
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.look_at_from_position(hp + (hp - main.mokki.to_global(ka.position)).normalized() * 7.0 + Vector3(0, 2.5, 0), main.mokki.to_global(ka.position) + Vector3(0, 1.2, 0))
			cam.current = true
			for i in 20:
				await main.get_tree().process_frame
			print("KAUPPA-AUTO vihje '%s'" % main._hint.text)
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_luukku.png"))
			# Lähikuva kyljestä: luukku auki katoksena, Eila luukulla, ratti tyhjä.
			var kx: Vector3 = ka.global_basis.x
			var kc: Vector3 = ka.global_position + ka.global_basis.z * 0.5
			cam.look_at_from_position(kc + kx * 6.0 - ka.global_basis.z * 2.5 + Vector3(0, 1.9, 0), kc + kx * 0.8 + Vector3(0, 1.4, 0))
			for i in 4:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_luukku_lahi.png"))
			main._talk_open("kauppa_auto", ka.seller)
			print("KAUPPA-AUTO valikko: %s" % str(main._talk_options().map(func(o): return o.text + ("" if o.enabled else " [" + o.reason + "]"))))
			for k in ["auto_kalja", "auto_sokeri", "auto_lehti", "auto_turbohiiva", "auto_makkara"]:
				main._talk_choose(k)
				print("KAUPPA-AUTO %s: rahaa %.2f, kaljat %d, sokeri %s, turbo %s, makkara %s, info '%s'" % [k, main.money, main.beers, main.has_sugar, main.has_turbo,
					main.has_sausage, main._talk_box._info if "_info" in main._talk_box else ""])
			main._talk_box.close()
			main.walker_out.global_position = w0 + Vector3(0, 30, 0)  # pois luukulta: odotus kuluu
			ka.wait_t = 0.5
			Engine.time_scale = 4.0
			t0 = Time.get_ticks_msec()
			while ka.state != "away" and Time.get_ticks_msec() - t0 < 90000:
				await main.get_tree().process_frame
				if ka.state == "leaving" and Time.get_ticks_msec() - t0 > 2500 and Time.get_ticks_msec() - t0 < 2550:
					await RenderingServer.frame_post_draw
					main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_lahtee.png"))
			Engine.time_scale = 1.0
			print("KAUPPA-AUTO lähti: tila '%s' %.0f s, päivän käynti %d / päivä %d" % [ka.state, (Time.get_ticks_msec() - t0) / 1000.0,
				main._kauppa_auto_day, main.day])
			var _sf := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			_sf.store_buffer(_save_bak)
			_sf.close()
			main.get_tree().quit()
		"mokkilama":
			# Lama Vaalassa: työvoimatoimiston jono ja laput, jonotus, automaatin oikut.
			var _save_bak := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			main._note.visible = false
			main._mopo_dismount()
			var td: Dictionary = vl.doors.filter(func(d): return d.id == "tyokkari")[0]
			main.walker_out.global_position = main.mopo_trip.to_global(td.pos + Vector3(0, 0.5, 0))
			for i in 15:
				await main.get_tree().process_frame
			print("LAMA työkkäri ovi %s, vihje '%s'" % [vl.tyokkari_door, main.mopo_trip.hint])
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.look_at_from_position(main.mopo_trip.to_global(td.pos + td.out * 12.0 + Vector3(0, 4, 0)), main.mopo_trip.to_global(vl.tyokkari_door + Vector3(0, 1.5, 0)))
			cam.current = true
			for i in 20:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_jono.png"))
			cam.look_at_from_position(main.mopo_trip.to_global(vl.tyokkari_door + td.out * 9.0 + Vector3(0, 2.2, 0)), main.mopo_trip.to_global(vl.tyokkari_door + Vector3(0, 2.4, 0)))
			for i in 10:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_julkisivu.png"))
			var shop := Vector3(926, 0, -926)
			var ni: int = vl.nearest(shop)[0]
			var rp: Vector3 = vl.road_pos(ni)
			cam.look_at_from_position(main.mopo_trip.to_global(rp + (rp - shop).normalized() * 6.0 + Vector3(0, 4, 0)), main.mopo_trip.to_global(Vector3(shop.x, rp.y + 2, shop.z)))
			for i in 10:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_lappu.png"))
			cam.current = false
			main._on_vaala_door("tyokkari")
			var c0 := main.clock_min
			print("LAMA valikko: %s" % str(main._talk_options().map(func(o): return o.text)))
			main._talk_choose("jonota")
			print("LAMA jonotus: kello %+.0f min, vastaus '%s', uudestaan %s" % [main.clock_min - c0, main._talk_box._line,
				str(main._talk_options().map(func(o): return o.text + ("" if o.enabled else " [" + o.reason + "]")))])
			main._talk_box.close()
			var got := {}
			for n in 40:
				main.atm_day = -1
				main._atm_lama_day = -1
				var m0 := main.money
				main._atm_use()
				var k := "hylätty" if main.money == m0 else ("raja" if main.money - m0 < Atm.DAILY else "ok")
				got[k] = got.get(k, 0) + 1
				if k == "hylätty":
					var m1 := main.money
					main._atm_use()
					got["uusi yritys " + str(main.money - m1)] = got.get("uusi yritys " + str(main.money - m1), 0) + 1
			print("LAMA automaatti 40 päivää: %s" % got)
			var _sf := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			_sf.store_buffer(_save_bak)
			_sf.close()
			main.get_tree().quit()
		"mokkihotelli":
			# Hotelli Siitari: hotellin ovi ravintolan takana, vastaanotto, huone 12 (Dingo), ulos; keskusta ylhäältä.
			var _save_bak := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			var oc := Camera3D.new()
			oc.far = 2000.0
			main.add_child(oc)
			oc.look_at_from_position(main.mopo_trip.to_global(Vector3(700, 260, -760)), main.mopo_trip.to_global(Vector3(820, 130, -930)))
			oc.current = true
			await snap.call("_keskusta.png")
			oc.current = false
			var mp: CharacterBody3D = main.mopo_trip.mopo
			mp.position = vl.hotel_door + Vector3(0, 0.6, 0)
			mp.speed = 0.0
			for i in 20:
				await main.get_tree().process_frame
			print("HOTELLI ovi %s, Siitarin ovi %s (%.1f m), vihje '%s'" % [vl.hotel_door, vl.siitari_door,
				vl.hotel_door.distance_to(vl.siitari_door), main.mopo_trip.hint])
			main._on_vaala_door("hotelli")
			for i in 10:
				await main.get_tree().process_frame
			print("HOTELLI sisällä: tila %s, hotellissa %s, vihje '%s'" % [main.state, main.siitari_int.in_hotel(), main._hint.text])
			await snap.call("_vastaanotto.png")
			main.siitari_int.walker.position = main.siitari_int.spots.dingo[0]
			for i in 10:
				await main.get_tree().process_frame
			print("HOTELLI huone 12 vihje '%s', spot %s" % [main._hint.text, main.siitari_int.spot])
			await snap.call("_huone12.png")
			main._talk_open("dingo", null)
			print("HOTELLI dingo valikko: %s" % str(main._talk_options().map(func(o): return o.text)))
			for k in ["nimmari", "huikka", "telkkari"]:
				main._talk_choose(k)
				print("HOTELLI %s: '%s' / '%s', rahaa %.0f, maine %.0f" % [k, main._talk_box._line, main._talk_box._info, main.money, main.maine])
			main._talk_box.close()
			await snap.call("_telkkari.png")
			main._talk_open("vastaanotto", null)
			main._talk_choose("huone")
			print("HOTELLI vastaanotto: '%s'" % main._talk_box._line)
			main._talk_box.close()
			for i in 5:
				await main.get_tree().process_frame
			main.siitari_int.walker.position = main.siitari_int.spots.hotelli_ovi[0]
			for i in 5:
				await main.get_tree().process_frame
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			for i in 5:
				await main.get_tree().process_frame
			print("HOTELLI ulos: tila %s, mopomatka %s, vihje '%s'" % [main.state, main.mopo_trip.active, main.mopo_trip.hint])
			var _sf := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			_sf.store_buffer(_save_bak)
			_sf.close()
			main.get_tree().quit()
		"mokkikahlaus":
			# Pummilla kävellen: rannasta aidan vesipään ympäri lavan pihalle (kahlausalue, ei teleporttia).
			var _save_bak := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			main._note.visible = false
			main._mopo_dismount()
			var po: Vector3 = vl.pummi_out
			var pn: Vector3 = vl.pummi_in
			var tip := Vector3(vl._wade_c.x, 0, vl._wade_c.y)
			var mid := (po + pn) / 2.0
			var away := Vector3(tip.x - mid.x, 0, tip.z - mid.z).normalized()
			var nrm := Vector3(po.x - pn.x, 0, po.z - pn.z).normalized()
			var way: Array[Vector3] = [po, tip + nrm * 2.0 + away * 1.0, tip + away * 2.0, tip - nrm * 2.0 + away * 1.0, pn]
			main.walker_out.global_position = main.mopo_trip.to_global(po + Vector3(0, 0.5, 0))
			for i in 5:
				await main.get_tree().physics_frame
			var blocked := 0
			var deepest := 0.0
			for k in way.size() - 1:
				var a2: Vector3 = way[k]
				var b2: Vector3 = way[k + 1]
				var n := int(a2.distance_to(b2) / 0.4) + 1
				for j in n:
					var q := a2.lerp(b2, float(j + 1) / n)
					var want := main.mopo_trip.to_global(Vector3(q.x, vl.h(q.x, q.z) + 0.5, q.z))
					if main.walker_out.test_move(main.walker_out.global_transform, want - main.walker_out.global_position):
						blocked += 1
					main.walker_out.global_position = want
					await main.get_tree().physics_frame
					await main.get_tree().process_frame
					deepest = maxf(deepest, vl.water_level - vl.h(q.x, q.z))
					var gp := main.walker_out.global_position
					if Vector2(gp.x - want.x, gp.z - want.z).length() > 0.3:
						print("KAHLAUS palautettiin kuivalle kohdassa %s (syvyys %.2f m), vihje '%s'" % [q, vl.water_level - vl.h(q.x, q.z), main._hint.text])
						blocked += 100
						break
				if blocked >= 100:
					break
				if k == 1:
					print("KAHLAUS kärjessä: vihje '%s'" % main._hint.text)
			print("KAHLAUS: syvin %.2f m, törmäyksiä %d, leima '%s', pihalla %s, viesti '%s'" % [deepest, blocked, main._lava_pass_now(),
				vl.in_lava_yard(main.mopo_trip.to_local(main.walker_out.global_position)), main._msg.text])
			var _sf := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			_sf.store_buffer(_save_bak)
			_sf.close()
			main.get_tree().quit()
		"mokkijuhannus":
			# Juhannusaatto: kokko rannalla, juhannustanssit isommalla bändillä, TV kuvaa, Päivi näkee lähetyksen.
			var _save_bak := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			main.day = 5 + 7 * 0  # perjantai
			print("JUHANNUS viikonpäivä %s, juhannus %s" % [Main.WEEKDAYS[main._weekday()], main._juhannus()])
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			main._mopo_dismount()
			var kd: Array = vl.doors.filter(func(d): return d.id == "kokko")
			print("JUHANNUS kokko %s, ovi %s" % [vl.kokko_pos, kd.size()])
			if kd.size() > 0:
				main.walker_out.global_position = main.mopo_trip.to_global(kd[0].pos + Vector3(0, 0.5, 0))
				for i in 10:
					await main.get_tree().process_frame
				print("JUHANNUS kokolla vihje '%s'" % main.mopo_trip.hint)
				var kc := Camera3D.new()
				main.add_child(kc)
				kc.look_at_from_position(main.mopo_trip.to_global(vl.kokko_pos + kd[0].out * 11.0 + Vector3(0, 3.5, 0)), main.mopo_trip.to_global(vl.kokko_pos + Vector3(0, 2, 0)))
				kc.current = true
				await snap.call("_kokko.png")
				kc.current = false
				main._on_vaala_door("kokko")
				print("JUHANNUS kokko: '%s'" % main._msg.text)
			main._enter_lava(true)
			var lg: Node3D = main._lava_game
			print("JUHANNUS lava: juhannus %s, tv %s, bändi '%s'" % [lg.juhannus, lg.tv, lg.band])
			await snap.call("_lava.png")
			lg._start_dance("humppa")
			lg._t = LavaGame.SONG * 0.55
			for i in 20:
				await main.get_tree().process_frame
			print("JUHANNUS TV-kuva otettu: %s" % (main._tv_shot != null))
			if main._tv_shot != null:
				main._tv_shot.get_image().save_png(path.replace(".png", "_tvkuva.png"))
			lg._hits = 30
			lg._misses = 0
			lg._t = LavaGame.SONG
			for i in 5:
				await main.get_tree().process_frame
			print("JUHANNUS tanssi: vaihe %s, paras %.2f, lähetykseen %s" % [lg._phase, lg._best, main._tv_pending != null])
			lg._back_to_hall()
			for i in 5:
				await main.get_tree().process_frame
			print("JUHANNUS takaisin saliin: vaihe %s, teksti '%s'" % [lg._phase, lg._info.text.get_slice("\n", 0)])
			lg._order()
			print("JUHANNUS baari: rahaa %.2f" % main.money)
			lg._leave()
			for i in 300:
				await main.get_tree().process_frame
				if i == 200:
					await RenderingServer.frame_post_draw
					main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_paivi1.png"))
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_paivi2.png"))
			var tc := Time.get_ticks_msec()
			var shot3 := false
			while main.cutscene.busy:
				await main.get_tree().process_frame
				if not shot3 and Time.get_ticks_msec() - tc > 6500:
					shot3 = true
					await RenderingServer.frame_post_draw
					main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_paivi3.png"))
			print("JUHANNUS lähetyksen jälkeen: tila %s, maine %.0f, Päivi vihainen %s, viesti '%s'" % [main.state, main.maine, main._paivi_mad, main._msg.text])
			var _sf := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			_sf.store_buffer(_save_bak)
			_sf.close()
			main.get_tree().quit()
		"mokkiaukiolot":
			# Aukioloajat: tekstit, Saloisten kaupan ovi, taksi Raaheen, Vaalan ovet ja valomerkki Siitarissa.
			var _save_bak := FileAccess.get_file_as_bytes(Main.SAVE_PATH)  # testi ei saa muuttaa pelaajan tallennusta
			for t in [6.5, 8.0, 12.0, 19.0, 21.5, 1.5]:
				main.clock_min = t * 60.0
				print("AUKI klo %.1f: kauppa %s alko %s siitari %s raahe %s lava %s | '%s'" % [t, main.is_open("kauppa"), main.is_open("alko"),
					main.is_open("siitari"), main.is_open("raahe"), main.is_open("lava"), main.closed_text("kauppa")])
			main.clock_min = 22.0 * 60.0
			if main.player != main.walker_out:
				main._toggle_mount()
			main.walker_out.global_position = main.shop_door + Vector3(0, 0.5, 0)
			for i in 10:
				await main.get_tree().process_frame
			print("AUKI kaupan ovi klo 22: '%s'" % main._hint.text)
			main.clock_min = 12.0 * 60.0
			print("AUKI taksi klo 12: %s" % str(main._talk_options("taksi").filter(func(o): return o.id == "raahe").map(func(o): return [o.enabled, o.reason])))
			main.clock_min = 15.0 * 60.0
			print("AUKI taksi klo 15: %s" % str(main._talk_options("taksi").filter(func(o): return o.id == "raahe").map(func(o): return [o.enabled, o.reason])))
			main.clock_min = 9.5 * 60.0
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var mp: CharacterBody3D = main.mopo_trip.mopo
			mp.position = vl.siitari_park + Vector3(0, 0.6, 0)
			mp.speed = 0.0
			for i in 10:
				await main.get_tree().process_frame
			print("AUKI Siitari klo 9.30: '%s'" % main.mopo_trip.hint)
			mp.position = vl.lava_door + Vector3(0, 0.6, 0)
			for i in 10:
				await main.get_tree().process_frame
			print("AUKI lava klo 9.30: '%s'" % main.mopo_trip.hint)
			main.clock_min = 12.0 * 60.0
			mp.position = vl.kmarket_door + Vector3(0, 0.6, 0)
			for i in 10:
				await main.get_tree().process_frame
			print("AUKI Tervaportti klo 12: '%s'" % main.mopo_trip.hint)
			mp.position = vl.siitari_park + Vector3(0, 0.6, 0)
			for i in 10:
				await main.get_tree().process_frame
			print("AUKI Siitari klo 12: '%s'" % main.mopo_trip.hint)
			main._on_mopo_arrived()
			main.clock_min = 1.95 * 60.0
			for i in 60:
				await main.get_tree().process_frame
			main.clock_min = 2.05 * 60.0
			for i in 5:
				await main.get_tree().process_frame
			print("AUKI Siitari klo 2.03: tila %s, viesti '%s'" % [main.state, main._msg.text])
			main.clock_min = 2.4 * 60.0
			for i in 5:
				await main.get_tree().process_frame
			print("AUKI Siitari klo 2.24: tila %s, viesti '%s'" % [main.state, main._msg.text])
			var _sf := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			_sf.store_buffer(_save_bak)
			_sf.close()
			main.get_tree().quit()
		"mokkikiihdytys":
			# Mopojen kiihdytys: Zabukin pihan mopopojat, kisa (botti lähtee vihreällä ja vaihtaa vihreällä alueella).
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(name: String) -> void:
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			main._note.visible = false
			main.money = 30.0
			main._mopo_dismount()
			main.walker_out.global_position = main.mopo_trip.to_global(vl.race_spot + Vector3(0, 0.5, 0) + vl.doors.filter(func(d): return d.id == "kiihdytys")[0].out * 3.0)
			for i in 15:
				await main.get_tree().process_frame
			print("KISA pihassa vihje '%s'" % main.mopo_trip.hint)
			await snap.call("_piha.png")
			var tr: Array = vl.race_track()
			print("KISA rata %d pistettä, %.0f m suoraan" % [tr.size(), Vector2(tr[0].x, tr[0].z).distance_to(Vector2(tr[-1].x, tr[-1].z)) if tr.size() > 1 else 0.0])
			main._on_vaala_door("kiihdytys")
			print("KISA valikko: %s" % str(main._talk_options().map(func(o): return o.text)))
			main._talk_choose("kisa")
			for i in 30:
				await main.get_tree().process_frame
			await snap.call("_valot.png")
			var rc: Node3D = main._race
			Input.action_press("forward")  # kaasu pohjassa jo punaisilla: ei vilppilähtöä, lähtö vihreällä
			for i in 40:
				await main.get_tree().process_frame
			print("KISA punaisilla kaasu pohjassa: vaihe %s, kierrokset %.2f, matka %.1f m" % [rc._phase, rc._idle_rpm, rc._me.s])
			while rc._green_at == 0.0:
				await main.get_tree().process_frame
			for i in 3:
				await main.get_tree().process_frame
			print("KISA lähtö: %s" % rc._note)
			var shot := 0
			var t0 := Time.get_ticks_msec()
			while is_instance_valid(rc) and rc._phase == "race" and Time.get_ticks_msec() - t0 < 300000:  # yläraja: hitaalla (ohjelmisto)renderöinnillä kisa kestää minuutteja
				var r: float = rc._rpm(rc._me)
				if r > 0.86 and rc._me.gear < 3 and rc._me.shift <= 0.0:
					Input.action_press("jump")
					await main.get_tree().process_frame
					Input.action_release("jump")
					print("KISA vaihto %d: %s" % [rc._me.gear, rc._note])
				await main.get_tree().process_frame
				if Time.get_ticks_msec() - t0 > 3000 * (shot + 1) and shot < 3:
					await snap.call("_ajo%d.png" % shot)
					shot += 1
			Input.action_release("forward")
			await snap.call("_maali.png")
			print("KISA tulos: oma %.2f, vastustaja %.2f, '%s'" % [rc._me.time, rc._opp.time, rc._big.text])
			t0 = Time.get_ticks_msec()
			while main.state == "mopokisa" and Time.get_ticks_msec() - t0 < 60000:
				await main.get_tree().process_frame
			print("KISA jälkeen: tila %s, rahaa %.2f, viesti '%s', voitot %d" % [main.state, main.money, main._msg.text, main._race_wins])
			var f := FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE)
			f.store_buffer(saved)
			f.close()
			main.get_tree().quit()
		"mokkibotti":
			# Botti pelaa mökin minipelit (ränni, ampiaiset) loppuun: --peli=ranni|ampiais (oletus molemmat). Tulokset tulostetaan,
			# tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var which := "kaikki"
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("--peli="):
					which = a2.substr(7)
			var fr := func(n: int) -> void:
				for i in n:
					await main.get_tree().process_frame
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.porch_pos(0.9)
			await fr.call(20)
			if which in ["ranni", "kaikki"]:
				main._start_ranni()
				await fr.call(10)
				var g: Node3D = main.mokki.get_children().filter(func(c): return c.get_script() != null and c.get_script().resource_path.ends_with("ranni_game.gd"))[0]
				var steps := 0
				var falls := 0
				var cleaned := 0
				var last_click := -10.0
				while is_instance_valid(g) and not g.all_done and not g.fell_off and steps < 400000:
					await main.get_tree().process_frame
					steps += 1
					if g._move_t >= 0.0 or g._fall_t >= 0.0:
						continue
					Input.action_release("left")
					Input.action_release("right")
					if g._bal + g._bal_v * 0.4 > 0.05:
						Input.action_press("left")
					elif g._bal + g._bal_v * 0.4 < -0.05:
						Input.action_press("right")
					var tgt: Variant = null
					for t in g.state[g._sec]:
						if t.hp > 0:
							tgt = t
							break
					if tgt == null:
						g._alt_action()
						continue
					var aim: Vector2 = g._aim_to(tgt.pos)
					g._yaw = aim.x
					g._pitch = aim.y
					await main.get_tree().process_frame
					# Kuin ihminen: klikataan vasta, kun tikkaat ovat vakaat ja edellisestä on kulunut aikaa (peliaika g._t).
					if g._t - last_click < 0.7 or absf(g._bal) > 0.3 or absf(g._bal_v) > 0.5:
						continue
					if not g._pick().is_empty():
						last_click = g._t
						var before: int = tgt.hp
						g._action()
						cleaned += before - tgt.hp
				Input.action_release("left")
				Input.action_release("right")
				print("BOTTI ränni: valmis %s, kaatui %s, askeleita %d, siivottu %d, tila %s" % [g.all_done if is_instance_valid(g) else "?", g.fell_off if is_instance_valid(g) else "?", steps, cleaned, main.state])
				if is_instance_valid(g):
					await fr.call(5)
					g._quit()
				await fr.call(10)
				print("BOTTI ränni jälkeen: tila %s, viesti '%s'" % [main.state, main._msg.text.replace("\n", " ")])
			if which in ["ampiais", "kaikki"]:
				main._start_ampiaiset()
				await fr.call(20)
				var g2: Node3D = main.mokki.get_children().filter(func(c): return c.get_script() != null and c.get_script().resource_path.ends_with("ampiais_game.gd"))[0]
				print("BOTTI ampiaiset: hiiri lukittu %s" % [Input.mouse_mode == Input.MOUSE_MODE_CAPTURED])
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = true
				Input.parse_input_event(ev)
				var st2 := 0
				while is_instance_valid(g2) and g2.result == "" and st2 < 3000:
					await main.get_tree().process_frame
					st2 += 1
					var am: Vector2 = g2._aim_to(g2.nest_local + Vector3(0, -0.27, 0))
					g2._yaw = am.x
					g2._pitch = am.y
				ev.pressed = false
				Input.parse_input_event(ev)
				if is_instance_valid(g2):
					print("BOTTI ampiaiset: tulos '%s', pistoja %d, annos %.2f, myrkkyä jäljellä %.1f, askeleita %d" % [g2.result, g2.stings, g2._dose, g2._can, st2])
					var t3 := Time.get_ticks_msec()
					while is_instance_valid(g2) and Time.get_ticks_msec() - t3 < 40000:
						await main.get_tree().process_frame
				print("BOTTI ampiaiset jälkeen: tila %s, viesti '%s', peli elossa %s%s" % [main.state, main._msg.text.replace("\n", " "), is_instance_valid(g2),
					(", end_t %.2f, done %s, result %s, can_quit %s" % [g2._end_t, g2._done, g2.result, g2._can_quit()]) if is_instance_valid(g2) else ""])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"mokkiajoalue":
			# Mopon ajoalue (vaala.gd drivable) kuvaksi ja kokeet: tieltä suoraan ja viistosti metsään, sekä
			# pysäköintipaikoilta liikkeelle.
			main.tilat.add("humala", -1.0)
			main._start_mopo()
			var mp: CharacterBody3D = main.mopo_trip.mopo
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var img := Image.create(vl._dnx, vl._dnz, false, Image.FORMAT_L8)
			for j in vl._dnz:
				for i in vl._dnx:
					img.set_pixel(i, j, Color.WHITE if vl._drive[j * vl._dnx + i] != 0 else Color.BLACK)
			img.save_png(path.replace(".png", "_maski.png"))
			print("AJO maski %d x %d, x0 %.1f z0 %.1f" % [vl._dnx, vl._dnz, vl._x0, vl._z0])
			for t in [[200, 90.0], [400, 60.0], [560, -90.0], [700, 35.0], [300, -20.0]]:
				var si: int = t[0]
				var d: Vector3 = vl.road_dir(si).rotated(Vector3.UP, deg_to_rad(t[1]))
				mp.position = vl.road_pos(si) + Vector3(0, 0.6, 0)
				mp.rotation.y = atan2(-d.x, -d.z)
				mp.speed = 10.0
				Input.action_press("forward")
				for i in 60 * 4:
					await main.get_tree().physics_frame
				Input.action_release("forward")
				var ni: Array = vl.nearest(mp.position)
				print("AJO näyte %d kulma %+.0f: tiestä %.1f m, ajettava %s, pinta %d, nopeus %.1f km/h" % [si, t[1], ni[1],
					vl.drivable(mp.position.x, mp.position.z), vl.code_at(mp.position.x, mp.position.z), mp.speed * 3.6])
			var stops := {"siitari": vl.siitari_park, "lava": vl.lava_door, "kmarket": vl.kmarket_door, "mokki": vl.mokki_mopo}
			for d in vl.doors:
				stops[d.id] = d.pos
			for id in stops:
				var sp: Vector3 = stops[id]
				print("AJO pysäkki %s %s ajettava %s" % [id, sp, vl.drivable(sp.x, sp.z)])
			main.get_tree().quit()
		"mokkijarvi_e":
			# Mopomatkalla järviseudun E-kohteet: viskikätkö, tynnyrisauna, makkaranpaisto, uinti ja kalastus.
			# Tallennus palautetaan lopuksi (kätkön avaus tallentaa).
			var saved_cfg := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.tilat.add("humala", -1.0)
			main._start_mopo()
			var mp: CharacterBody3D = main.mopo_trip.mopo
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			main.viina_found.erase("viski")
			main.has_sausage = true
			var state0 := main.state
			for id in ["viski", "tynnyrisauna", "laavu", "salminen", "kalastus"]:
				var dpos := Vector3.INF
				for d in vl.doors:
					if d.id == id:
						dpos = d.pos
				if dpos == Vector3.INF:
					print("JARVI_E %s: ei ovea" % id)
					continue
				var back := Vector3(1.5, 0, 0)
				if id == "salminen":
					# Mopolla järveen ja sieltä uimaan: mopo ei saa jäädä veteen.
					if main.mopo_trip.on_foot != null:
						main._mopo_remount()
					mp.position = vl.beach_tf.origin + vl.beach_tf.basis * Vector3(0, 0, 3.0) + Vector3(0, 0.3, 0)
					mp.speed = 0.0
					mp.velocity = Vector3.ZERO
					print("JARVI_E mopo järvessä: koodi %d, ajettava %s" % [vl.code_at(mp.position.x, mp.position.z), vl.drivable(mp.position.x, mp.position.z)])
					back = Vector3.INF
				if back == Vector3.INF:
					pass
				elif main.mopo_trip.on_foot != null:
					main.walker_out.global_position = main.mopo_trip.to_global(dpos + back + Vector3(0, 0.6, 0))
					main.walker_out.velocity = Vector3.ZERO
				else:
					mp.position = dpos + back + Vector3(0, 0.8, 0)
					mp.speed = 0.0
					mp.velocity = Vector3.ZERO
				for i in 20:
					await main.get_tree().process_frame
				var hint0: String = main.mopo_trip.hint
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
				var started := main.state
				var k := 0
				while (main.cutscene.busy or main.state != state0) and k < 60:
					await main.get_tree().create_timer(1.0).timeout
					if k == 3 or (k == 8 and id != "kalastus"):
						await RenderingServer.frame_post_draw
						main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s%d.png" % [id, k]))
					if id == "kalastus" and k == 4:
						for c in vl.get_children():
							for g in c.get_children():
								if g is FishGame:
									g.finished.emit([])
					k += 1
				for i in 10:
					await main.get_tree().process_frame
				print("JARVI_E %s: vihje '%s', tila %s -> %s, %d s, matka käynnissä %s, viesti '%s'" % [id, hint0, started, main.state, k,
					main.mopo_trip.active, main._msg.text.replace("\n", " | ")])
				if id == "salminen":
					print("JARVI_E mopo uinnin jälkeen %s: koodi %d (vesi %d), ajettava %s, jalan %s" % [mp.position, vl.code_at(mp.position.x, mp.position.z),
						vl.WATER, vl.drivable(mp.position.x, mp.position.z), main.mopo_trip.on_foot != null])
			print("JARVI_E viski löydetty %s, vihje nyt '%s', jalan %s" % ["viski" in main.viina_found, main.mopo_trip.hint, main.mopo_trip.on_foot != null])
			var vt: Node3D = vl.train
			print("JARVI_E juna: laituri %.0f m, reitti alkaa x %.0f" % [vl.station_t, vt.path[0].x])
			if not saved_cfg.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_cfg)
			main.get_tree().quit()
		"mokkilahto":
			# Mopomatkan lähtö: _1 mökin mopopaikalta (pelaaja jalan, mopo parkissa), _2 heti kartan vaihduttua
			# mopon kameralla, _3 ylhäältä Vaalan lähtöpaikasta, _4 mökin piha ylhäältä vertailuun.
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.gpos(Mokki.MOPO_LOCAL + Vector3(1.0, 0.5, 0.0))
			main.walker_out.rotation.y = main.mokki.rotation.y + PI * 0.9
			var shot := func(name: String) -> void:
				for i in 40:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			main._msg.text = ""
			main._note.visible = false
			await shot.call("_1.png")
			var top := Camera3D.new()
			top.far = 2000.0
			main.add_child(top)
			top.look_at_from_position(main.mokki.gpos(Mokki.MOPO_LOCAL) + Vector3(0, 45, 35), main.mokki.gpos(Mokki.MOPO_LOCAL))
			top.current = true
			await shot.call("_4.png")
			main._start_mopo()
			main._msg.text = ""
			main._note.visible = false
			await shot.call("_2.png")
			var mp: CharacterBody3D = main.mopo_trip.mopo
			top.look_at_from_position(mp.global_position + Vector3(0, 45, 35), mp.global_position)
			top.current = true
			await shot.call("_3.png")
			print("LAHTO mopo vaalassa ", main.mopo_trip.to_local(mp.global_position), " näyte ", main.mopo_trip._sample, " ", main.mopo_trip.status.replace("\n", " | "))
		"mokkijuoksu":
			# Juoksukaljat Vaalan Tervaportissa: ei taksia, kauppias saa mopon kiinni, tappio vie kaljat ja Koskenkorvat.
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.gpos(Mokki.MOPO_LOCAL + Vector3(1.0, 0.5, 0.0))
			for i in 10:
				await main.get_tree().physics_frame
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			var mp: CharacterBody3D = main.mopo_trip.mopo
			mp.position = vl.kmarket_door + Vector3(0, 0.6, 0)
			for i in 10:
				await main.get_tree().physics_frame
			main._enter_vaala_shop()
			main.interior.has_beer = true
			main.interior.has_paid = true
			main.interior.stolen = true
			var pv0 := main.viina_pullot
			main._on_shop_exited(true)
			await main.get_tree().process_frame
			print("VJUOKSU alku: kaljat %d, kauppias %s, viesti '%s'" % [main.beers, main._chasing(), main._msg.text.replace("\n", " ")])
			for i in 600:
				await main.get_tree().physics_frame
				if main.state == "fight":
					break
			print("VJUOKSU kiinni: tila %s, kauppias korkeus %.1f, mopo %.1f" % [main.state, main._shop_chaser.global_position.y if is_instance_valid(main._shop_chaser) else -1.0, mp.global_position.y])
			while main.fight._phase != "fight":
				await main.get_tree().process_frame
			for i in 40:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_tappelu.png"))
			main.fight._p.take_hit(999.0, 1.0, 5.0)
			while main.state == "fight":
				await main.get_tree().process_frame
			print("VJUOKSU tappio: tila %s, kaljat %d, pullot %d -> %d, vaala %s, viesti '%s'" % [main.state, main.beers, pv0, main.viina_pullot,
				main._in_vaala, main._msg.text.replace("\n", " ")])
		"mokkieat":
			# Vaalan matkalla T: pulla mopon selässä, vauhdissa ei, viina jalan.
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.gpos(Mokki.MOPO_LOCAL + Vector3(1.0, 0.5, 0.0))
			for i in 10:
				await main.get_tree().physics_frame
			main._start_mopo()
			main.food["pulla"] = 1
			main.viina_pullot = 1
			var mp: CharacterBody3D = main.mopo_trip.mopo
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			for i in 30:
				await main.get_tree().physics_frame
			await press.call("eat")
			print("MOPOEAT open=", main._item_menu.is_open(), " mopo_ctrl=", mp.controls_enabled, " door_block=", main.mopo_trip.menu_open)
			await press.call("interact")
			print("MOPOEAT pulla=", main.food.get("pulla", 0), " open=", main._item_menu.is_open(), " mopo_ctrl=", mp.controls_enabled, " state=", main.state)
			Input.action_press("forward")
			for i in 120:
				await main.get_tree().physics_frame
			await press.call("eat")
			Input.action_release("forward")
			print("MOPOEAT fast speed=%.1f open=" % mp.speed, main._item_menu.is_open(), " msg=", main._msg.text)
			Input.action_press("brake")
			for i in 180:
				await main.get_tree().physics_frame
				if absf(mp.speed) < 0.5:
					break
			Input.action_release("brake")
			await press.call("mount")
			for i in 10:
				await main.get_tree().physics_frame
			await press.call("eat")
			print("MOPOEAT foot=", main.mopo_trip.on_foot != null, " open=", main._item_menu.is_open(), " walker_ctrl=", main.walker_out.controls_enabled)
			await press.call("interact")
			print("MOPOEAT viina=", main.viina_pullot, " walker_ctrl=", main.walker_out.controls_enabled, " state=", main.state)
		"mokkifish":
			# Soutuvenekalastus: laiturilla E, soutu järvelle (_1), heitto parven kohdalle, tärppi ja väsytys (_2),
			# lopetus F:llä. Tulostaa tilat ja saaliin.
			main._toggle_mount()
			var press2 := func() -> void:
				Input.action_press("interact")
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
			var shot2 := func(name: String) -> void:
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			main.walker_out.global_position = main.mokki.to_global(Vector3(Mokki.DOCK_LOCAL.x, Mokki.h(Mokki.DOCK_LOCAL.x, Mokki.DOCK_LOCAL.z - 11.6) + 0.7, Mokki.DOCK_LOCAL.z))
			for i in 10:
				await main.get_tree().physics_frame
			await shot2.call("_0.png")
			print("FISH hint: ", main._hint.text)
			main._start_fishing()
			await main.get_tree().process_frame
			var fg: Node = null
			for c in main.mokki.get_children():
				if c is FishGame:
					fg = c
			print("FISH peli käynnissä: %s, tila %s" % [fg != null, main.state])
			Input.action_press("forward")
			await main.get_tree().create_timer(3.0).timeout
			Input.action_release("forward")
			await main.get_tree().create_timer(2.5).timeout
			await shot2.call("_1.png")
			print("FISH soudettu: paikka %s nopeus %.2f, parvia %d" % [fg._pos, fg._speed, fg._shoals.size()])
			# Vene parven viereen ja heitto sitä kohti.
			var sh: Vector3 = fg._shoals[0]
			var dir: Vector3 = (sh - fg._pos).normalized()
			fg._pos = sh - dir * 8.0
			fg._yaw = atan2(-dir.x, -dir.z)
			fg._speed = 0.0
			Input.action_press("interact")
			await main.get_tree().create_timer(0.5).timeout
			Input.action_release("interact")
			for i in 4:
				await main.get_tree().process_frame
			print("FISH heitto: tila %s, koho %s, kala %s" % [fg._state, fg._bob, fg._fish])
			fg._bite_at = fg._t
			for i in 4:
				await main.get_tree().process_frame
			print("FISH koho sukelsi: tila %s" % fg._state)
			await press2.call()
			print("FISH tärppi: tila %s" % fg._state)
			# Väsytys: pidä E, kun kireys on alle 0,6, muuten päästä.
			var guard := 0
			while fg._state == "reel" and guard < 60 * 40:
				guard += 1
				if fg._tension < 0.6:
					Input.action_press("interact")
				else:
					Input.action_release("interact")
				if guard == 60:
					await shot2.call("_2.png")
				await main.get_tree().process_frame
			Input.action_release("interact")
			print("FISH väsytys ohi: tila %s, saalis %s, viesti %s" % [fg._state, fg.catch, fg._msg.text])
			Input.action_press("ui_accept")
			var fk := InputEventKey.new()
			fk.keycode = KEY_F
			fk.pressed = true
			Input.parse_input_event(fk)
			await main.get_tree().create_timer(2.0).timeout
			fk.pressed = false
			Input.parse_input_event(fk)
			Input.action_release("ui_accept")
			await main.get_tree().process_frame
			print("FISH lopussa: tila %s, saalis %s, viesti %s" % [main.state, main.saalis, main._msg.text])
			main.get_tree().quit()
		"mokkielukat", "mokkielukat2":
			# Metsästyksen eläinmallit rivissä aukealla metsästyslavan edessä.
			main._toggle_mount()
			var gl: Vector2 = Mokki.HUNT_GLADE
			var kinds := ["hirvi", "metso", "riekko", "kyyhky", "janis"]
			for i in kinds.size():
				var hgm := HuntGame.new()
				var node: Node3D = hgm._model(kinds[i])
				hgm.free()
				node.scale = Vector3.ONE * HuntGame.SIZE
				var px := gl.x + 2.0
				var pz := gl.y - 6.0 + i * 3.0
				node.position = Vector3(px, Mokki.h(px, pz), pz)
				node.rotation.y = PI / 2.0
				main.mokki.add_child(node)
			var ec := Camera3D.new()
			main.add_child(ec)
			ec.look_at_from_position(main.mokki.to_global(Vector3(gl.x + 9.0, Mokki.h(gl.x + 9.0, gl.y) + 1.6, gl.y)),
				main.mokki.to_global(Vector3(gl.x + 2.0, Mokki.h(gl.x + 2.0, gl.y) + 0.8, gl.y)))
			if scene == "mokkielukat2":  # hirvi läheltä
				var hz := gl.y - 6.0
				ec.look_at_from_position(main.mokki.to_global(Vector3(gl.x + 6.5, Mokki.h(gl.x + 6.5, hz + 2.0) + 3.0, hz + 2.5)),
					main.mokki.to_global(Vector3(gl.x + 2.0, Mokki.h(gl.x + 2.0, hz) + 2.4, hz)))
			ec.current = true
			main.walker_out.visible = false
		"mokkijahti":
			# Metsästys: nousee lavalle, odottaa eläimen, tähtää ja ampuu. Tulostaa saaliin.
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.to_global(Vector3(Mokki.HUNT_LOCAL.x + 1.5, Mokki.h(Mokki.HUNT_LOCAL.x + 1.5, Mokki.HUNT_LOCAL.z) + 0.4, Mokki.HUNT_LOCAL.z))
			for i in 10:
				await main.get_tree().physics_frame
			print("JAHTI hint: ", main._hint.text)
			main._start_hunt()
			var hg: Node3D = main.mokki.get_children().filter(func(c): return c is HuntGame)[0]
			hg._spawn_t = 0.0
			for i in 60 * 3:
				await main.get_tree().process_frame
			var shots := 0
			for i in 60 * 20:
				await main.get_tree().process_frame
				var alive: Array = hg._animals.filter(func(a): return a.state in ["walk", "pause"] and a.kind != "hirvi")
				if alive.is_empty() or hg._reload_t > 0.0:
					continue
				var a: Dictionary = alive[0]
				var c: Vector3 = a.pos + Vector3(0, HuntGame.SPECIES[a.kind].cy * HuntGame.SIZE, 0) - hg._eye
				hg._yaw = atan2(c.x, c.z)
				hg._pitch = atan2(c.y, Vector2(c.x, c.z).length())
				await main.get_tree().process_frame
				if shots == 0:
					await RenderingServer.frame_post_draw
					main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_aim.png"))
				hg._shoot()
				shots += 1
				print("JAHTI shot %d at %s d=%.1f bag=%s" % [shots, a.kind, c.length(), hg.bag])
				if shots >= 3:
					break
			hg._finish("testi")
			while is_instance_valid(hg):
				await main.get_tree().process_frame
			await main.get_tree().process_frame
			print("JAHTI end state=", main.state, " saalis=", main.saalis, " msg=", main._msg.text)
		"mokkidrooni":
			# Drooni mökillä: alustan vihje, nousu, kuva mökistä ja järvestä, laskeutuminen (H) ja järveen putoaminen.
			# Kuvat _pad, _fpv, _chase. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(suffix: String) -> void:
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", suffix))
			main.drone_photos.clear()
			main.drone_battery = 1.0
			main._toggle_mount()
			var pad := main._drone_pad(true)
			main.walker_out.global_position = pad + Vector3(1.2, 0.3, 0.6)
			for i in 20:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("MDROONI at_mokki=%s pad=%s parked=%s hint=%s" % [main._at_mokki(), pad, main._drone_parked.position, main._hint.text])
			print("MDROONI kohteet: ", main._mokki_drone_names().values())
			await snap.call("_pad.png")
			await main.get_tree().process_frame  # kuvakaappauksen jälkeen: painallus seuraavan ruudun alkuun
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			var dg: Node3D = main._drone
			print("MDROONI state=%s drone=%s total=%d" % [main.state, dg != null, dg.photo_total])
			Input.action_press("jump")
			for i in 200:
				await main.get_tree().physics_frame
			Input.action_release("jump")
			print("MDROONI nousu: kork %.1f m" % (dg.body.global_position.y - dg._home_ground))
			var mc: Vector3 = main.mokki.gpos(Vector3(0, 1, -1))
			var to: Vector3 = mc - dg.body.global_position
			dg._yaw = atan2(-to.x, -to.z)
			dg._gimbal = -atan2(-to.y, Vector2(to.x, to.z).length())
			for i in 5:
				await main.get_tree().physics_frame
			await dg.take_photo()
			print("MDROONI kuva: ", main.drone_photos, " ", dg._warn.text)
			# Järven yläpuolelle ja kuva alas.
			for id in main._mokki_lakes:
				var lk: Vector3 = main.mokki.to_global(main._mokki_lakes[id])
				dg.body.global_position = lk + Vector3(0, 50, 25)
				dg._yaw = 0.0
				dg._gimbal = -atan2(50.0, 25.0)
				for i in 10:
					await main.get_tree().physics_frame
				await dg.take_photo()
				print("MDROONI järvi %s: %s" % [id, dg._warn.text])
				break
			await snap.call("_fpv.png")
			CamCtl.fps = false
			dg.body.global_position = pad + Vector3(30, 25, 20)
			for i in 40:
				await main.get_tree().physics_frame
			await snap.call("_chase.png")
			Input.action_press("forward")  # alueen raja: kaukana mökistä käännytään takaisin
			dg.body.global_position = Main.MOKKI_POS + Vector3(Main.MOKKI_DRONE_R + 5.0, 0, 0)
			dg.body.global_position.y = dg.ground.call(dg.body.global_position.x, dg.body.global_position.z) + 60.0
			for i in 5:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			print("MDROONI raja: vel=%s msg=%s" % [dg._vel, dg._warn.text])
			dg.body.global_position = pad + Vector3(10, 20, 10)
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_H
			ev.pressed = true
			Input.parse_input_event(ev)
			for i in 60 * 20:
				await main.get_tree().physics_frame
				if main._drone == null:
					break
			print("MDROONI loppu: state=%s drone=%s msg=%s" % [main.state, main._drone != null, main._msg.text])
			# Järveen pudotus: uusi lento ja lasku veden päälle.
			await main.get_tree().process_frame
			main._start_drone()
			await main.get_tree().process_frame
			dg = main._drone
			var lake: Vector3 = main.mokki.gpos(Mokki.DOCK_LOCAL + Vector3(0, 0, 15))
			dg._landed = false
			dg.body.global_position = lake + Vector3(0, 1.05, 0)  # h() on järven pohja, pinta metrin ylempänä
			print("MDROONI vesi=%s" % dg.is_water.call(lake.x, lake.z))
			for i in 60 * 5:
				await main.get_tree().physics_frame
				if main._drone == null:
					break
			print("MDROONI järveen: broken=%s msg=%s" % [main.drone_broken_day == main.day, main._msg.text])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"mokkihommat":
			# Santun hommat: yö mökillä, aamulappu, kaikki 12 hommaa pihalla, Santun kävely, minipelit (laituri,
			# ränni, ampiaiset, sahaus, halkominen, tiskit), huussin sangot, savusauna, palju, kalja Santulle,
			# hermot ja häätö. Kuvat _h_*.png. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap := func(suffix: String) -> void:
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_h_%s.png" % suffix))
			var wait := func(n: int) -> void:
				for i in n:
					await main.get_tree().process_frame
			var cam := Camera3D.new()
			main.add_child(cam)
			var look := func(from: Vector3, at: Vector3) -> void:
				cam.look_at_from_position(main.mokki.to_global(Vector3(from.x, Mokki.h(from.x, from.z) + from.y, from.z)),
					main.mokki.to_global(Vector3(at.x, Mokki.h(at.x, at.z) + at.y, at.z)), Vector3.UP)
				cam.current = true
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.porch_pos(0.9)
			main._hommat_arrive()
			print("HOMMAT saapuminen active=%s nights=%d" % [main.hommat.active, main.hommat.nights])
			main.hommat.nights = 1
			var rows: Array = main._hommat_morning()
			print("HOMMAT aamu active=%s tasks=%s rows=%d" % [main.hommat.active, main.hommat.tasks, rows.size()])
			main.hommat.tasks = Hommat.TASKS.keys()
			main._hommat_prepare()
			main._note.show_note(["Huomenta mökille!"] + rows, "– Santtu", 5.0)
			await wait.call(30)
			await snap.call("lappu")
			main._note.visible = false
			await look.call(Vector3(-11, 3.5, 6), Vector3(-16, 0.8, 15))
			await wait.call(10)
			await snap.call("puupaikka")
			await look.call(Vector3(-8, 3.0, 4), Vector3(-15, 0.8, 1.5))
			await wait.call(10)
			await snap.call("huussi")
			await look.call(Vector3(14, 4.0, -9), Vector3(6, 1.5, 0))
			await wait.call(10)
			await snap.call("nurmi_tikkaat")
			await look.call(Vector3(9.7, 9.0, -8.0), Vector3(9.7, 0.0, 1.0))
			await wait.call(10)
			await snap.call("nurmi_ylhaalta")
			await look.call(Vector3(-1.5, 2.0, 15.5), Vector3(2.7, 2.0, 18.5))
			main.mokki.wasp_nest.visible = true
			await wait.call(10)
			await snap.call("ampiaispesa")
			var dz: float = main.mokki.dock_body.position.z + main._dock_fix_z()
			await look.call(Vector3(6.5, 2.5, dz - 2.5), Vector3(8.9, 0.0, dz + 0.6))
			await wait.call(10)
			await snap.call("laituri")
			# Huussi: kolme sankoa kompostiin (kävellen) ja yksi läikkyy juostessa, sitten talikko.
			var near := func(local: Vector3, r: float) -> bool:
				var g: Vector3 = main.mokki.to_global(local)
				var pp := main.player.global_position
				return Vector2(pp.x - g.x, pp.z - g.z).length() < r
			var go := func(local: Vector3) -> void:
				main.walker_out.global_position = main.mokki.gpos(local + Vector3(0, 0.4, 0))
				main.walker_out.velocity = Vector3.ZERO
				for i in 4:
					await main.get_tree().physics_frame
			for trip in 3:
				await go.call(Mokki.HUUSSI_HATCH_LOCAL)
				main._hommat_logic(true, near)
				await go.call(Mokki.KOMPOSTI_LOCAL + Vector3(1.2, 0, 0))
				main._hommat_logic(true, near)
			print("HUUSSI sangot=%s carry=%s" % [main.hommat.progress.get("sangot"), main._carry])
			cam.current = false
			main.walker_out.activate_camera()
			for i in 12:
				main._hommat_logic(true, near)
			print("HUUSSI tehty=%s msg=%s" % ["huussi" in main.hommat.done, main._msg.text.replace("\n", " | ")])
			await go.call(Mokki.HUUSSI_HATCH_LOCAL)
			main._set_carry("sanko")
			main.walker_out.speed = 5.0
			main._hommat_tick(2.0)
			print("LAIKKYI carry=%s msg=%s" % [main._carry, main._msg.text.replace("\n", " | ")])
			# Santtu kävelee katsomaan (palju) ja palaa kannolle.
			await go.call(Mokki.TUB_LOCAL + Vector3(1.4, 0, 0))
			for i in 60 * 8:
				main._santtu_watch(main.get_process_delta_time())
				await main.get_tree().process_frame
				if main.mokki.santtu_arrived():
					break
			print("SANTTU paljulla arrived=%s pos=%s bubble=%s" % [main.mokki.santtu_arrived(), main.mokki.santtu.position, main.mokki._bubble.text])
			await snap.call("santtu_palju")
			# Palju: tyhjennys, pesu ja täyttö pumpulla.
			main._palju_logic(true)
			for i in 60 * 9:
				main._hommat_tick(main.get_process_delta_time())
				await main.get_tree().process_frame
				if not main._palju_draining:
					break
			main.mokki.palju_dirt = 0.01
			Input.action_press("interact")
			for i in 10:
				main._palju_logic(false)
				await main.get_tree().process_frame
			Input.action_release("interact")
			print("PALJU taso=%.2f lika=%.2f letku=%s" % [main.mokki.palju_level, main.mokki.palju_dirt, main.mokki._hose.visible])
			await go.call(Mokki.pump_local() + Vector3(0.8, 0, 0))
			main._hommat_logic(true, near)
			main.mokki.palju_level = 0.97
			await wait.call(5)
			main._hommat_logic(true, near)
			print("PALJU tehty=%s pumppu=%s" % ["palju" in main.hommat.done, main.mokki.pump_on])
			# Savusauna: syli pesään, kiuas kuumaksi ja savut tuulettumaan (ajat lyhennetään).
			await go.call(Mokki.HALKO_LOCAL)
			main._hommat_logic(true, near)
			print("HALOT carry=%s" % main._carry)
			await go.call(Mokki.SAUNA_LOCAL + Vector3(-1.5, 0, 0))
			main._sauna_logic(true)
			await look.call(Vector3(-1, 3.0, 14), Vector3(5, 1.5, 19))
			await wait.call(90)
			await snap.call("savusauna")
			main.mokki.sauna_heat = 0.99
			for i in 60 * 8:
				await main.get_tree().process_frame
				if not main.mokki.sauna_fire_on:
					break
			main.mokki.sauna_smoke = 0.02
			await wait.call(60)
			print("SAUNA heated=%s ready=%s tehty=%s" % [main.mokki.sauna_heated, main.mokki.sauna_ready(), "savusauna" in main.hommat.done])
			cam.current = false
			# Minipelit: käynnistys, kuva Santtu katsojana ja lopetus.
			var mg := func(starter: Callable, name: String, frames: int) -> void:
				starter.call()
				await wait.call(frames)
				await snap.call(name)
				var g: Node = null
				for c in main.mokki.get_children():
					if c.has_method("_quit"):
						g = c
				if g != null:
					g._quit()
				await wait.call(5)
				print("PELI %s state=%s msg=%s" % [name, main.state, main._msg.text.replace("\n", " | ")])
			await mg.call(main._start_laituri, "peli_laituri", 40)
			await mg.call(main._start_ranni, "peli_ranni", 40)
			await mg.call(main._start_ampiaiset, "peli_ampiaiset", 40)
			await mg.call(main._start_mokki_saw, "peli_saha", 40)
			main._mokki_polkyt = 2
			await mg.call(main._start_mokki_chop, "peli_halko", 40)
			# Laituri ratkaistuna: kaikki naulat kantaan.
			var lg := LaituriGame.new()
			print("LAITURI valmis ennen=%s" % LaituriGame.is_done(main._dock_state))
			lg.free()
			# Leikkuri: nurmikko leikataan suoraan.
			main._ensure_mokki_lawn()
			main._start_mowing(main.mokki_lawn)
			main.mokki_lawn.lengths.fill(0.04)
			main._mow()
			print("NURMI tehty=%s mowing=%s" % ["nurmi" in main.hommat.done, main.mowing])
			# Kahvit sisällä, vienti Santulle ja tiskit.
			main._enter_mokki()
			await wait.call(5)
			main._on_mokki_acted("kahvi")
			main._start_tiskit()
			await wait.call(20)
			await snap.call("tiskit")
			var tg: Node = main.mokki_int.get_children().filter(func(c): return c is TiskiGame)[0]
			for k in 3000:
				if not is_instance_valid(tg) or tg._done:
					break
				tg._scrub(1 if k % 2 == 0 else -1)
				if tg._dirt <= 0.0 and tg._busy_t < 0.0:
					tg.drunk = 0.0
					tg._lift()
				await main.get_tree().process_frame
			await wait.call(5)
			print("TISKIT dishes=%d" % main.mokki_int.dishes)
			main._on_mokki_exited()
			print("KAHVI carry=%s" % main._carry)
			await go.call(main.mokki.santtu.position + Vector3(1.2, 0, 0))
			main._on_santtu_menu("kahvi")
			print("KAHVI tehty=%s" % ("kahvi" in main.hommat.done))
			# Kalja Santulle: yksi homma pois.
			main.beers = 1
			main._on_santtu_menu("kalja")
			print("KALJA beer_used=%s done=%s" % [main.hommat.beer_used, main.hommat.done])
			print("HUD: ", main._stats.text.replace("\n", " | "))
			print("REPPU: ", main.inventory_info())
			# Hermot: täysi mittari = häätö ja yhden tähden arvostelu.
			main.hommat.done = main.hommat.done.slice(0, 2)
			main.hommat.hermo = 99.9
			main.state = "ulkona"
			print("HAATO ennen: busy=%s menu=%s (%s) note=%s" % [main.cutscene.busy, main._item_menu.is_open(), main._item_menu._title.text, main._note.visible])
			main._item_menu.visible = false
			main.player.controls_enabled = true
			main._hommat_tick(1.0)
			await wait.call(10)
			print("HAATO active=%s banned=%s reviews=%s" % [main.hommat.active, main.hommat.banned_day == main.day, main.hommat.reviews])
			await wait.call(200)
			print("HAATO state=%s at_mokki=%s" % [main.state, main._at_mokki()])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"mokkikartta":
			# Paperikartta (M) ja tutka mökillä: oikean kartan järvet, tiet ja rakennukset.
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.porch_pos(1.5)
			for i in 10:
				await main.get_tree().physics_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_tutka.png"))
			await main.get_tree().process_frame
			Input.action_press("map")
			await main.get_tree().process_frame
			Input.action_release("map")
		"mokkiilma":
			# Mökin 200 m alue ilmasta (vertaa drone-kuvaan ja karttaan) ja rakennusaika.
			var t0 := Time.get_ticks_msec()
			var test := Mokki.new()
			test.position = Vector3(0, 0, 20000)
			main.add_child(test)
			print("MOKKIILMA rakennus %d ms, lapsia %d, vesi_y %.2f, mökki->ranta h(8.9,44)=%.2f" % [Time.get_ticks_msec() - t0,
				test.get_child_count(), Mokki.water_y(), Mokki.h(8.9, 44.0)])
			test.queue_free()
			var ac := Camera3D.new()
			main.add_child(ac)
			ac.far = 2000.0
			ac.look_at_from_position(main.mokki.gpos(Vector3(-5, 90, -60)), main.mokki.gpos(Vector3(0, 0, 25)))
			ac.current = true
			for i in 10:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_piha.png"))
			# Mökki järven puolelta: rinteen sokkeli ja kuistin portaat.
			ac.look_at_from_position(main.mokki.gpos(Vector3(9, 2.0, 12)), main.mokki.gpos(Vector3(1, 0.5, 0)))
			for i in 4:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_ranta.png"))
			ac.look_at_from_position(main.mokki.gpos(Vector3(0, 170, 30)), main.mokki.gpos(Vector3(0, 0, 0)))
		"mokkikaide":
			# Kuistin kaide järven puolelta läheltä vinosti.
			var kc := Camera3D.new()
			main.add_child(kc)
			kc.look_at_from_position(main.mokki.gpos(Vector3(6.5, 1.6, 8.5)), main.mokki.gpos(Vector3(0.5, 0.9, 1.5)), Vector3.UP)
			kc.current = true
			main.walker_out.visible = false
		"mokkilaituri":
			# Laituri: rantaprofiili, kävely rannalta laiturin päähän ja kuva sivusta.
			var dl: Vector3 = Mokki.DOCK_LOCAL
			var prof := []
			for k in 11:
				var z: float = dl.z - 16.0 + k * 2.0
				prof.append("%.0f:%.2f%s" % [z, Mokki.h(dl.x, z), "~" if Mokki.water_at(dl.x, z) >= 0 else ""])
			print("LAITURI profiili ", " ".join(prof), " vesi_y %.2f" % Mokki.water_y())
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.gpos(Vector3(dl.x, 0.5, dl.z - 16.0))
			main.walker_out.look_at(main.mokki.gpos(Vector3(dl.x, 0.5, dl.z + 5.0)))
			for i in 10:
				await main.get_tree().physics_frame
			Input.action_press("forward")
			for i in 420:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			var wl: Vector3 = main.mokki.to_local(main.walker_out.global_position)
			print("LAITURI kävelijä x=%.2f y=%.2f z=%.2f (pää z %.1f)" % [wl.x, wl.y, wl.z, dl.z])
			var dc := Camera3D.new()
			main.add_child(dc)
			var sy: float = Mokki.h(dl.x, dl.z - 12.0)
			dc.look_at_from_position(main.mokki.to_global(dl + Vector3(4.5, sy + 1.2, -15.5)), main.mokki.to_global(dl + Vector3(0, sy, -10.5)))
			dc.current = true
			main.walker_out.visible = false
		"mokkikanto":
			# Santtu kannolla: alussa ja puuhista palattua, istuu pölkyn päällä (ei ilmassa eikä pölkyn sisällä).
			main._toggle_mount()
			main.walker_out.global_position = main.mokki.gpos(Vector3(8, 0.5, 14))
			var kc := Camera3D.new()
			main.add_child(kc)
			kc.current = true
			var sl := Mokki.SANTTU_LOCAL
			var snap := func(tag: String) -> void:
				var top := -99.0
				for c in main.mokki.get_children():
					if c is MeshInstance3D and c.mesh is CylinderMesh and Vector2(c.position.x - sl.x, c.position.z - sl.z).length() < 0.05:
						top = c.position.y + c.mesh.height * 0.5
				var s: Node3D = main.mokki.santtu
				var pel: Vector3 = main.mokki.to_local(s.to_global(s.bone_position("pelvis")))
				var th: Vector3 = main.mokki.to_local(s.to_global(s.bone_position("thigh_l")))
				print("KANTO %s: juuri %s, lantio %s, reisi %s, kanto keski %s ylä %.2f, maa %.2f" % [tag, s.position, pel, th,
					Vector2(sl.x, sl.z), top, Mokki.h(sl.x, sl.z)])
				for v in [["sivu", Vector3(2.2, 0.9, 0.0)], ["edes", Vector3(0.0, 1.0, -2.2)], ["taka", Vector3(-0.6, 1.2, 2.2)]]:
					var eye: Vector3 = main.mokki.gpos(sl + v[1])
					eye.y = main.mokki.to_global(Vector3(0, Mokki.h(sl.x, sl.z), 0)).y + v[1].y
					kc.look_at_from_position(eye, main.mokki.to_global(sl + Vector3(0, Mokki.h(sl.x, sl.z) + 0.5, 0)), Vector3.UP)
					for i in 4:
						await main.get_tree().process_frame
					await RenderingServer.frame_post_draw
					main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s_%s.png" % [tag, v[0]]))
			for i in 10:
				await main.get_tree().process_frame
			await snap.call("alku")
			main.mokki.santtu_visit(sl + Vector3(3, 0, 3))
			while not main.mokki.santtu_arrived():
				await main.get_tree().process_frame
			main.mokki.santtu_go_home()
			while main.mokki.santtu_out():
				await main.get_tree().process_frame
			for i in 30:
				await main.get_tree().process_frame
			await snap.call("paluu")
			for k in 12:
				await main.get_tree().create_timer(0.25).timeout
				var s: Node3D = main.mokki.santtu
				print("KANTO t%d lantio %s anim %s" % [k, main.mokki.to_local(s.to_global(s.bone_position("pelvis"))), s.current()])
		"kuisti":
			# Mökin kuisti: luiskaa ylös kannelle (korkeus ~0,6 m), eikä kannen reunasta pääse sisään maata pitkin.
			main._toggle_mount()
			var start: Vector3 = main.mokki.gpos(Vector3(6.6, 0.5, 2.2))
			main.walker_out.global_position = start
			main.walker_out.look_at(main.mokki.gpos(Vector3(0, 0.5, 2.2)))
			for i in 10:
				await main.get_tree().physics_frame
			Input.action_press("forward")
			for i in 150:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			var lp: Vector3 = main.mokki.to_local(main.walker_out.global_position)
			print("KUISTI portaat: x=%.2f y=%.2f z=%.2f (kansi y %.2f, x -4.7..4.7)" % [lp.x, lp.y, lp.z, Mokki.h(0, -1) + 0.62])
			main.walker_out.global_position = main.mokki.gpos(Vector3(0, 0.5, 7.5))
			main.walker_out.look_at(main.mokki.gpos(Vector3(0, 0.5, 0)))
			for i in 10:
				await main.get_tree().physics_frame
			Input.action_press("forward")
			for i in 120:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			lp = main.mokki.to_local(main.walker_out.global_position)
			print("KUISTI edestä: z=%.2f y=%.2f (kannen reuna z 3.9: pitäisi pysähtyä)" % [lp.z, lp.y])
			# Yleiskuva pihasta rannan suunnasta: kuisti, savusauna, palju ja kesäkeittiö kuten kuvissa.
			var kc := Camera3D.new()
			main.add_child(kc)
			kc.look_at_from_position(main.mokki.gpos(Vector3(4, 9, 36)), main.mokki.gpos(Vector3(2, 1, 8)))
			kc.current = true
		_:
			return 0
	return 1
