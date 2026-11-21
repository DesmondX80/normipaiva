extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "kartta_kota". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const B := preload("res://scripts/build.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Kota := preload("res://scripts/kota.gd")
const ChopGame := preload("res://scripts/chop_game.gd")
const SawGame := preload("res://scripts/saw_game.gd")

const KOHTAUKSET := ["kartta_reuna", "overview", "route", "compass", "maptarget", "map", "signs", "signs2", "signclose", "kotaview", "kotain", "tower", "kotaopaste", "karttaveto", "karttamerkit", "karttanaapurit", "edgetest", "kotapath", "kotagrid", "kotaplay", "kosketus", "placecheck", "hilltest", "sprinttest", "overlap", "walk", "walkmap", "fpsmitta", "fpsosat", "minikartta", "fpsview", "orbit", "fpswalk"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"kartta_reuna":
			# Kartan hahmomerkki pelialueen reunoilla (tools/testit/kartta_reuna.gd).
			var saved_kr := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var kr: Node = load("res://tools/testit/kartta_reuna.gd").new()
			kr.main = main
			main.add_child(kr)
			await kr.run()
			if not saved_kr.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_kr)
			else:
				DirAccess.remove_absolute(Main.SAVE_PATH)
			main.get_tree().quit()
			return 2
		"overview":
			var cam := Camera3D.new()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 1600.0
			cam.far = 3000.0
			main.add_child(cam)
			cam.global_position = M.w((M.MAP_MIN + M.SIZE) / 2.0) + Vector3(0, 1200, 0)
			cam.rotation_degrees = Vector3(-90, 0, 0)
			cam.current = true
			(main.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_enabled = false
		"route":
			main.player.position = M.w(Vector2(440, 850)) + Vector3(0, 0.3, 0)
			main.player.rotation.y = B.yaw_to(M.w(M.J_K) - M.w(Vector2(440, 850)))
		"compass", "maptarget":
			# Kompassin kohde K-Marketille (ja lähelle toinen testi: kartta auki).
			main._paper.target = M.w2(M.SHOP_ZONE)
			main._paper.has_target = true
			if scene == "maptarget":
				main._paper.toggle()
		"map":
			main._note.visible = false
			main._note._holder.modulate.a = 0.0
			main._paper.toggle()  # vain paperikartta (ei reppua päälle)
			var snap := func(name: String) -> void:
				main._paper._view.queue_redraw()
				main._paper.queue_redraw()
				for i in 4:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			await snap.call("_avattu.png")
			print("MAP avattu: zoom %.2f px/m, keskellä %s, pelaaja %s" % [main._paper._vzoom, main._paper._vcenter,
				Vector2(main.player.global_position.x, main.player.global_position.z)])
			main._paper._vzoom_by(0.01, main._paper._view.size / 2.0)
			await snap.call("_koko.png")
			print("MAP koko kartta: zoom %.3f" % main._paper._vzoom)
			if main.world.apteekki_s.has("knock"):
				main._paper._vcenter = Vector2(main.world.apteekki_s.knock.x, main.world.apteekki_s.knock.z)
				main._paper._vzoom_by(100.0, main._paper._view.size / 2.0)
				await snap.call("_apteekki.png")
			main._paper._center_on_me()
			main._paper._vzoom_by(100.0, main._paper._view.size / 2.0)
			await snap.call("_lahella.png")
			print("MAP lähellä: zoom %.2f" % main._paper._vzoom)
			main._paper.toggle()
		"signs":
			main.player.position = M.w(M.J_K) + Vector3(-1, 0.3, 12)
			main.player.rotation.y = -0.5
		"signs2":
			main.player.position = M.w(M.J_H2) + Vector3(-3, 0.3, -10)
			main.player.rotation.y = PI + 0.3
		"signclose":
			var a2 := M.w2(M.J_K)
			var d2 := (M.w2(Vector2(313, 791)) - a2).normalized()
			var at := a2 + d2 * 8.0 + d2.orthogonal() * 6.2
			var cam := Camera3D.new()
			cam.fov = 45.0
			main.add_child(cam)
			var eye := Vector3(at.x, 2.0, at.y) + Vector3(d2.orthogonal().x, 0, d2.orthogonal().y) * 2.6 + Vector3(d2.x, 0, d2.y) * 1.4
			cam.look_at_from_position(eye, Vector3(at.x, 2.35, at.y) + Vector3(d2.x, 0, d2.y) * 0.6, Vector3.UP)
			cam.current = true
		"kotaview", "kotain", "tower":
			main._toggle_mount()
			main.walker_out.global_position = main.world.kota.to_global(Vector3(-2.5, 0.4, -9.0))
			main.walker_out.rotation.y = main.world.kota.global_rotation.y
			for i in 40:
				await main.get_tree().process_frame
			var cam3 := Camera3D.new()
			main.add_child(cam3)
			cam3.fov = 60
			if scene == "kotaview":
				cam3.look_at_from_position(main.world.kota.to_global(Vector3(-8, 4.5, -13)), main.world.kota.to_global(Vector3(-1, 1.2, 1)), Vector3.UP)
			elif scene == "kotain":
				cam3.look_at_from_position(main.world.kota.to_global(Vector3(0.3, 1.5, -2.4)), main.world.kota.to_global(Vector3(0, 0.7, 1.5)), Vector3.UP)
			else:
				cam3.look_at_from_position(main.world.kota.to_global(Vector3(-4, 3.0, -8)), main.world.kota.to_global(Vector3(9, 4, 7)), Vector3.UP)
			cam3.current = true
			if scene == "kotain":
				main.world.kota.set_fire(true)
				main.world.kota.say("raimo", "Tässä kodassa on enemmän kieltokylttejä kuin halkoja.")
		"kotaopaste":
			# Laavun reittiviitta kodalle ja koillisen reunan reittiohje.
			var kpts: PackedVector2Array = main.world._kota_path()
			print("KOTAOPASTE polku %d pistettä, päättyy %.0f m kodasta" % [kpts.size(),
				kpts[-1].distance_to(M.w2(M.KOTA)) if kpts.size() > 0 else -1.0])
			var oc := Camera3D.new()
			main.add_child(oc)
			var k0: Vector2 = kpts[0]
			var kd: Vector2 = (kpts[2] - kpts[0]).normalized()
			var sp := k0 + kd * 4.0
			var sp3 := Vector3(sp.x, Terrain.h(sp.x, sp.y), sp.y)
			oc.look_at_from_position(sp3 + Vector3(kd.y, 0, -kd.x) * 7.0 + Vector3(0, 2.0, 0), sp3 + Vector3(0, 1.5, 0))
			oc.current = true
			main._msg.text = ""
			main._note.visible = false
			for i in 40:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_viitta.png"))
			oc.queue_free()
			main._toggle_mount()
			main.walker_out.global_position = M.w(Vector2(996, 2300)) + Vector3(0, 0.4, 0)
			main._edge_cd = 0.0
			for i in 20:
				await main.get_tree().physics_frame
			print("KOTAOPASTE reunalla: '%s'" % main._msg.text)
		"karttaveto":
			# Paperikartta kosketuksella: veto vierittää (ei aseta kohdetta), napautus asettaa kohteen;
			# mökillä kahden sormen nipistys zoomaa.
			if main.player == main.bike:
				main._toggle_mount()
			main._paper.toggle()
			for i in 3:
				await main.get_tree().process_frame
			var c: Vector2 = main._paper._view.position + main._paper._view.size / 2.0
			var mb := func(pos: Vector2, down: bool) -> void:
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = down
				e.position = pos
				main._paper._gui_input(e)
			var s0: Vector2 = main._paper._vcenter
			mb.call(c, true)
			for k in 12:
				var mm := InputEventMouseMotion.new()
				mm.position = c + Vector2(0, -20.0 * (k + 1))
				mm.relative = Vector2(0, -20)
				mm.button_mask = MOUSE_BUTTON_MASK_LEFT
				main._paper._gui_input(mm)
			mb.call(c + Vector2(0, -240), false)
			print("KARTTAVETO veto ylös: keskipiste %s -> %s, kohde '%s'" % [s0, main._paper._vcenter, str(main._paper.target)])
			# Rullalla zoomaus hiiren kohtaan kyläkartalla.
			var zk0: float = main._paper._vzoom
			for k in 3:
				var wh := InputEventMouseButton.new()
				wh.button_index = MOUSE_BUTTON_WHEEL_UP
				wh.pressed = true
				wh.position = c
				main._paper._gui_input(wh)
			print("KARTTAVETO kylä rulla: zoom %.2f -> %.2f px/m" % [zk0, main._paper._vzoom])
			mb.call(c, true)
			mb.call(c, false)
			print("KARTTAVETO napautus: kohde '%s'" % [str(main._paper.target)])
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kartta.png"))
			main._paper.toggle()
			main.mokki.ensure_built()
			main.walker_out.global_position = Main.MOKKI_POS + Vector3(5, 2, 5)
			for i in 10:
				await main.get_tree().physics_frame
			main._paper.toggle()
			for i in 3:
				await main.get_tree().process_frame
			var z0: float = main._paper._vzoom
			var vc: Vector2 = main._paper._view.global_position + main._paper._view.size / 2.0
			var touch := func(i: int, pos: Vector2, down: bool) -> void:
				var e := InputEventScreenTouch.new()
				e.index = i
				e.position = pos
				e.pressed = down
				main._paper._input(e)
			var drag := func(i: int, pos: Vector2) -> void:
				var e := InputEventScreenDrag.new()
				e.index = i
				e.position = pos
				main._paper._input(e)
			touch.call(0, vc - Vector2(50, 0), true)
			touch.call(1, vc + Vector2(50, 0), true)
			for k in 10:
				drag.call(0, vc - Vector2(50 + 10 * (k + 1), 0))
				drag.call(1, vc + Vector2(50 + 10 * (k + 1), 0))
			touch.call(0, vc, false)
			touch.call(1, vc, false)
			print("KARTTAVETO mökki vaala=%s nipistys: zoom %.3f -> %.3f" % [main._paper._vaala, z0, main._paper._vzoom])
			main._paper.toggle()
		"karttamerkit":
			# Lyijykynämerkinnät: muutama sivutehtävä tiedossa (yksi tehty), kartta kaukaa ja läheltä, päiväkirjan
			# "näytä kartalla" -linkki asettaa kompassin. Tallennus palautetaan.
			var saved_q := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var qshot := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % name))
			main._note.visible = false
			main._msg.text = ""
			for id in ["kauppalista", "nurmikko", "koris", "rankkarit", "piirakka", "oravajarvi", "keinu", "honganpalo", "kukat", "vaino"]:
				main.quests.known[id] = main.day
			main.tilat.first("kauppalista")
			print("KUULTU %s, uudestaan %s" % [main._note_places("Tokolanperällä on crossipoikien rossirata."), main._note_places("rossiradalla")])
			print("MERKIT %d kpl: %s" % [main.quest_marks().size(), main.quest_marks().map(func(q): return "%s %s" % [q[0], q[3]])])
			main._paper.toggle()
			for i in 10:
				await main.get_tree().process_frame
			main._paper._vzoom = 0.22
			main._paper._vcenter = M.w2(Vector2(560, 450))
			main._paper._view.queue_redraw()
			for i in 5:
				await main.get_tree().process_frame
			await qshot.call("kaukaa")
			main._paper._vzoom = 0.6
			main._paper._vcenter = M.w2(M.HONGAN_KENTTA)
			main._paper._view.queue_redraw()
			for i in 5:
				await main.get_tree().process_frame
			await qshot.call("lahelta")
			var hv := InputEventMouseMotion.new()
			hv.position = main._paper._w2(M.w2(M.HONGAN_KOULU)) + main._paper._view.position
			main._paper._gui_input(hv)
			for i in 3:
				await main.get_tree().process_frame
			print("HIIRI paikan päällä: '%s'" % main._paper._hover_name)
			main._paper._vcenter = M.w2(M.HOME_ZONE)
			main._paper._view.queue_redraw()
			hv.position = main._paper._px(M.NEIGHBOR_PEKKA) + main._paper._view.position
			main._paper._gui_input(hv)
			for i in 3:
				await main.get_tree().process_frame
			print("HIIRI naapurin päällä: '%s'" % main._paper._hover_name)
			await qshot.call("naapuri")
			for cn in [["reuna_oikea", Vector2(main._paper._view.size.x - 3, 300)], ["reuna_ylä", Vector2(400, 3)]]:
				hv.position = cn[1] + main._paper._view.position
				main._paper._gui_input(hv)
				main._paper._hover_name = "Oravajärven uimaranta"
				main._paper._view.queue_redraw()
				for i in 3:
					await main.get_tree().process_frame
				await qshot.call(cn[0])
			await qshot.call("hiiri")
			main._paper.toggle()
			for i in 5:
				await main.get_tree().process_frame
			main._journal.toggle()
			main._journal._set_tab("tehtavat")
			for i in 5:
				await main.get_tree().process_frame
			await qshot.call("paivakirja")
			print("LINKIT %s" % [main._journal._links.map(func(l): return l[1])])
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = (main._journal._links[0][0] as Rect2).get_center()
			main._journal._gui_input(ev)
			for i in 10:
				await main.get_tree().process_frame
			print("KOMPASSI kohde %s %s, päiväkirja auki %s, viesti '%s'" % [main._paper.has_target, main._paper.target, main._journal.visible, main._msg.text])
			await qshot.call("kompassi")
			if not saved_q.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_q)
		"karttanaapurit":
			# Paperikartta: naapurien merkit kodin ympärillä.
			main._note.visible = false
			main._msg.text = ""
			main._paper.toggle()
			for i in 10:
				await main.get_tree().process_frame
			# Hiiri Järvikujan päälle: tien nimi näkyy.
			for r in M.ROADS:
				if r.name == "Järvikuja":
					var mp: Vector2 = main._paper._px(r.pts[int(r.pts.size() / 2)])
					var ev := InputEventMouseMotion.new()
					ev.position = mp + main._paper._view.position
					main._paper._gui_input(ev)
					print("KARTTA hiiren alla: '%s'" % main._paper._hover_name)
					break
			for i in 20:
				await main.get_tree().process_frame
		"edgetest":
			for spot in [Vector2(3, 1500), Vector2(450, 3), Vector2(1000, 3957), Vector2(1617, 3000), Vector2(893, 1500)]:
				main._edge_cd = 0.0
				main.player.global_position = M.w(spot) + Vector3(0, 0.5, 0)
				for i in 8:
					await main.get_tree().physics_frame
				print("EDGE ", spot, " -> ", main._msg.text)
		"kotapath":
			# Kodalle vievä polku: se tie tai polku, jonka jokin piste on lähimpänä kotaa.
			var pts: Array = []
			var bestd := INF
			for r in M.ROADS:
				for q: Vector2 in r.pts:
					if r.pts.size() > 7 and q.distance_to(M.KOTA) < bestd:
						bestd = q.distance_to(M.KOTA)
						pts = r.pts
			main.player.global_position = M.w(pts[5]) + Vector3(0, 0.5, 0)
			main.player.rotation.y = B.yaw_to(M.w(pts[6]) - M.w(pts[5]))
		"kotagrid":
			var rows := []
			for zi in range(-8, 9):
				var row := ""
				for xi in range(-8, 13):
					var g: Vector3 = main.world.kota.to_global(Vector3(xi * 2.0, 0, zi * 2.0))
					var sf: String = main.world.surface_at(g)
					row += "~" if sf == "water" else ("o" if xi == 0 and zi == 0 else ("b" if sf == "bog" else "."))
				rows.append(row)
			print("KGRID local x -16..24 (step 2), z -16..16 (top = -z = door side)")
			for r in rows:
				print("KGRID ", r)
		"kotaplay":
			# Koko ketju: sahaa, pilko, sytytä, kuuntele tarina. Tulostaa tilat.
			main._toggle_mount()
			var press := func() -> void:
				Input.action_press("interact")
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
			# Sahaus: merkkaa 36 cm, vedä sahaa suorassa, kunnes pölkky katkeaa. Kaksi pölkkyä.
			main.walker_out.global_position = main.world.kota.to_global(Kota.SAW_LOCAL + Vector3(-0.8, 0, 0.3)) + Vector3(0, 0.4, 0)
			for i in 10:
				await main.get_tree().physics_frame
			print("KOTA hint: ", main._hint.text)
			await press.call()
			var sg: Node3D = main.world.kota.get_children().filter(func(c): return c is SawGame)[0] if main.state == "minigame" else null
			print("SAW state=", main.state, " sg=", sg != null)
			sg._gust_next = 999.0
			for n in 2:
				var a2: Vector2 = sg._aim_to(Vector3(0, SawGame.LOG_Y + SawGame.R, SawGame.END_Z - 0.36))
				sg._yaw = a2.x
				sg._pitch = a2.y
				for i in 5:
					await main.get_tree().process_frame
				if n == 0:
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_mark.png"))
					await main.get_tree().process_frame
				await press.call()
				print("SAW phase=", sg._phase, " cut_z=", sg._cut_z, " task=", sg._task.text)
				var dir := 1.0
				for i in 900:
					if sg._phase != "saw":
						break
					sg._tilt_hand = -(sg._tilt - sg._tilt_hand)  # pidä suorassa
					sg._stroke(dir * 0.02)
					if absf(sg._s) >= SawGame.STROKE - 0.001:
						dir = -dir
					await main.get_tree().process_frame
					if n == 0 and i == 120:
						await Kuva.piirto()
						Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_saw.png"))
				print("SAW cut done phase=", sg._phase, " made=", sg.polkyt_made, " polkyt=", main.kota_polkyt, " sub=", sg._sub.text)
				for i in 30:
					await main.get_tree().process_frame
				if n == 0:
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_cut.png"))
				for i in 600:
					if sg._phase == "mark":
						break
					await main.get_tree().process_frame
			sg._quit()
			await main.get_tree().process_frame
			print("SAW after state=", main.state, " msg=", main._msg.text)
			# Halonhakkuu: väärin päin asetettu pyörähtää pois, oikein päin keskelle ja isku keskelle.
			main.walker_out.global_position = main.world.kota.to_global(Kota.CHOP_LOCAL + Vector3(0.8, 0, 0)) + Vector3(0, 0.4, 0)
			for i in 10:
				await main.get_tree().physics_frame
			print("KOTA hint: ", main._hint.text)
			await press.call()
			var cg: Node3D = main.world.kota.get_children().filter(func(c): return c is ChopGame)[0] if main.state == "minigame" else null
			print("CHOP state=", main.state, " cg=", cg != null)
			cg._gust_next = 999.0
			var aim := func(target: Vector3) -> void:
				var dv: Vector3 = target - ChopGame.EYE
				cg._yaw = atan2(dv.x, dv.z)
				cg._pitch = -atan2(-dv.y, Vector2(dv.x, dv.z).length())
			aim.call(ChopGame.PILE + Vector3(0, 0.18, 0))
			for i in 5:
				await main.get_tree().process_frame
			await press.call()
			print("CHOP phase=", cg._phase, " flat=", cg._flat_down)
			if cg._flat_down:
				cg._alt_action()
			aim.call(Vector3(0, ChopGame.BLOCK_TOP, 0))
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_hold.png"))
			await main.get_tree().process_frame
			await press.call()
			print("CHOP after wrong place phase=", cg._phase, " sub=", cg._sub.text)
			for i in 30:
				await main.get_tree().physics_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_roll.png"))
			for i in 60:
				await main.get_tree().process_frame
			aim.call(ChopGame.PILE + Vector3(0, 0.18, 0))
			await main.get_tree().process_frame
			await press.call()
			if not cg._flat_down:
				cg._alt_action()
			aim.call(Vector3(0, ChopGame.BLOCK_TOP, 0))
			for i in 20:
				await main.get_tree().process_frame
			await press.call()
			print("CHOP after good place phase=", cg._phase, " sub=", cg._sub.text)
			for i in 40:
				await main.get_tree().process_frame
			aim.call(Vector3(cg._log_pos.x, ChopGame.BLOCK_TOP + ChopGame.LOG_L, cg._log_pos.z))
			for i in 5:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_aim.png"))
			await main.get_tree().process_frame
			await press.call()
			for i in 24:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_split.png"))
			for i in 50:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_split2.png"))
			print("CHOP after hit phase=", cg._phase, " sub=", cg._sub.text, " polkyt=", main.kota_polkyt, " halot=", main.kota_halot)
			for i in 90:
				await main.get_tree().process_frame
			cg._quit()
			await main.get_tree().process_frame
			print("KOTA polkyt=", main.kota_polkyt, " halot=", main.kota_halot, " state=", main.state, " msg=", main._msg.text)
			main.walker_out.global_position = main.world.kota.to_global(Vector3(0.9, 0.4, -1.4))
			for i in 10:
				await main.get_tree().physics_frame
			print("KOTA hint: ", main._hint.text)
			await press.call()
			print("KOTA fire=", main.world.kota.fire_on, " halot=", main.kota_halot)
			for i in 5:
				await main.get_tree().physics_frame
			print("KOTA hint: ", main._hint.text)
			await press.call()
			for i in 60:
				await main.get_tree().process_frame
			print("KOTA story state=", main.state, " msg=", main._msg.text)
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_story.png"))
			for i in 9000:  # pisin kodan tarina kestää yli 2400 ruutua
				await main.get_tree().process_frame
				if main.state != "cutscene":
					break
			print("KOTA after state=", main.state, " kuultu=", main.tarinat_kuultu, " msg=", main._msg.text)
			# Torni: portaita ylös kävellen.
			var base: Vector3 = main.world.kota.to_global(Kota.TOWER_LOCAL)
			print("TOWER base ground ", Terrain.h(base.x, base.z))
			var run := Kota.TOWER_TOP_Y / tan(deg_to_rad(33.0))
			var tb := Basis(Vector3.UP, main.world.kota.global_rotation.y - 0.5)
			var foot: Vector3 = base + tb * Vector3(0, 0, -1.75 - run - 1.2)
			main.walker_out.global_position = foot + Vector3(0, 0.5, 0)
			main.walker_out.rotation.y = main.world.kota.global_rotation.y - 0.5 + PI  # kohti tornia (+Z)
			for i in 20:
				await main.get_tree().physics_frame
			Input.action_press("forward")
			var rec := "--rec" in OS.get_cmdline_user_args()  # --rec: ruudut videoksi (_torni_NNNN.png)
			var side_cam: Camera3D = null
			if "--rec-side" in OS.get_cmdline_user_args():  # sivukamera tornin vierestä (pelin oma kamera näkyy ilman tätä)
				side_cam = Camera3D.new()
				main.add_child(side_cam)
				side_cam.global_position = base + tb * Vector3(9.0, 3.0, -4.0)
				side_cam.fov = 60.0
				side_cam.current = true
			for i in 900:
				await main.get_tree().physics_frame
				if side_cam != null:
					side_cam.look_at(main.walker_out.global_position + Vector3(0, 0.9, 0), Vector3.UP)
				if rec and i % 2 == 0 and i < 620:
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_torni_%04d.png" % (i / 2)))
				if i % 120 == 0 or (i > 500 and main._hint.text != "" and i % 30 == 0):
					print("TOWER t=", i, " spd=", main.walker_out.speed, " y=%.2f ground=%.2f hint=%s" % [main.walker_out.global_position.y, Terrain.h(main.walker_out.global_position.x, main.walker_out.global_position.z), main._hint.text])
			Input.action_release("forward")
			var plat_y: float = main.world.kota.global_position.y + Kota.TOWER_TOP_Y + 0.06
			print("TOWER tasanteella %s (jalat %.2f, tasanne %.2f, etäisyys keskeltä %.2f)" % [main.walker_out.global_position.y > plat_y - 0.05,
				main.walker_out.global_position.y, plat_y, Vector2(main.walker_out.global_position.x - base.x, main.walker_out.global_position.z - base.z).length()])
		"kosketus":
			# Kosketusohjaimet (--touch): tatti eteen ajaa pyörällä, Pyörä-nappi nousee selästä, veto kääntää kameraa.
			var touch := func(i: int, p: Vector2, down: bool) -> void:
				var ev := InputEventScreenTouch.new()
				ev.index = i
				ev.position = p
				ev.pressed = down
				Input.parse_input_event(ev)
			var drag := func(i: int, p: Vector2, rel: Vector2) -> void:
				var ev := InputEventScreenDrag.new()
				ev.index = i
				ev.position = p
				ev.relative = rel
				Input.parse_input_event(ev)
			for i in 30:
				await main.get_tree().physics_frame
			var vs := main.get_viewport().get_visible_rect().size
			var p0 := main.player.global_position
			touch.call(0, Vector2(200, vs.y - 200), true)
			drag.call(0, Vector2(200, vs.y - 290), Vector2(0, -90))
			for i in 120:
				await main.get_tree().physics_frame
			print("KOSKETUS tatti: matka %.1f m, forward=%s shift=%s" % [main.player.global_position.distance_to(p0),
				Input.is_action_pressed("forward"), Input.is_key_pressed(KEY_SHIFT)])
			touch.call(0, Vector2(200, vs.y - 290), false)
			for i in 60:
				await main.get_tree().physics_frame
			var yaw0 := CamCtl.yaw
			touch.call(1, Vector2(vs.x * 0.6, vs.y * 0.3), true)
			await main.get_tree().process_frame
			drag.call(1, Vector2(vs.x * 0.6 + 80, vs.y * 0.3), Vector2(80, 0))
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			touch.call(1, Vector2(vs.x * 0.6 + 80, vs.y * 0.3), false)
			print("KOSKETUS veto: yaw %.3f -> %.3f" % [yaw0, CamCtl.yaw])
			var on_bike := main.player == main.bike
			for i in 90:
				await main.get_tree().physics_frame
			print("KOSKETUS ennen nappia: vauhti %.2f vihje '%s'" % [main.bike.velocity.length(), main._hint.text])
			touch.call(2, Vector2(vs.x - 330, vs.y - 250), true)
			for i in 6:
				await main.get_tree().process_frame
			touch.call(2, Vector2(vs.x - 330, vs.y - 250), false)
			for i in 10:
				await main.get_tree().physics_frame
			print("KOSKETUS Pyörä-nappi: pyörällä %s -> %s" % [on_bike, main.player == main.bike])
		"placecheck":
			# Hahmojen, ajoneuvojen ja pelipaikkojen paikat: tien reunan etäisyys (negatiivinen = tiellä) ja
			# osuuko kohta talon, auton tai muun esteen sisään (fysiikkakysely 1 m maan yläpuolella).
			for i in 3:
				await main.get_tree().physics_frame
			var space := main.get_world_3d().direct_space_state
			var checks := [["koti_aloitus", main.home_zone + Vector3(0, 0, 4), null],
				["kauppa_taksi", main.world.taxi_pos, null], ["kauppa_vyohyke", main.shop_zone, null], ["mummot", main.mummot.global_position, main.mummot],
				["arto", main.arto.global_position, main.arto], ["pekka", main.pekka.global_position, main.pekka],
				["sulo", main.sulo.global_position, main.sulo], ["sinikka", main.sinikka.global_position, main.sinikka], ["vaino_alku", main.world.neighbor_yards["pekka"][0], null],
				["paivi_alku", main.world.graph_nodes[main.world.nearest_node(M.w(M.J_T))], null], ["laavu", M.w(M.LAAVU), null],
				["kota_raimo", main.world.kota.raimo.global_position, main.world.kota.raimo],
				["kota_veikko", main.world.kota.veikko.global_position, main.world.kota.veikko],
				["traktori", main.tractor.global_position, main.tractor], ["grilli", M.w(M.GRILLIKATOS), null],
				["kompostijemma", M.w(M.COMPOST), null], ["autotallijemma", M.w(M.GARAGE) + Vector3(-3.8, 0, 3.6), null],
				["leikkuri", M.w(M.MOWER_PARK), null],
				["nurmikko_1", main._lawn_corner(-1, -1), null], ["nurmikko_2", main._lawn_corner(1, -1), null],
				["nurmikko_3", main._lawn_corner(1, 1), null],
				["nurmikko_4", main._lawn_corner(-1, 1), null], ["agility", M.w((M.AGILITY[0] + M.AGILITY[2]) / 2.0), null]]
			for k in M.JUNTTI_SPOTS.size():
				checks.append(["juntti%d" % k, M.w(M.JUNTTI_SPOTS[k]), null])
			for k in M.STRAY_SPOTS.size():
				checks.append(["koira%d" % k, M.w(M.STRAY_SPOTS[k]), null])
			for k in M.BALES.size():
				checks.append(["paali%d" % k, M.w(M.BALES[k]), null])
			for nv in [main.arto, main.pekka, main.sinikka]:  # reitit puuhapisteiden välillä esteiden ohi
				for i in nv.yard.size():
					if nv._inside(Vector2(nv.yard[i].x, nv.yard[i].z)):
						print("REITTI %s piste %d esteen sisällä" % [nv.display_name, i])
					for j in nv.yard.size():
						var a: Vector3 = nv.yard[i]
						var r: Array[Vector3] = nv._plan(a, nv.yard[j])
						var pts: Array[Vector2] = [Vector2(a.x, a.z)]
						for q in r:
							pts.append(Vector2(q.x, q.z))
						pts.append(Vector2(nv.yard[j].x, nv.yard[j].z))
						for k in pts.size() - 1:
							if i != j and nv._blocked(pts[k], pts[k + 1]):
								print("REITTI %s %d->%d menee esteen läpi" % [nv.display_name, i, j])
								break
			for key: String in main.world.neighbor_yards:  # naapurien pihan puuhapisteet
				var yd: Array = main.world.neighbor_yards[key]
				for k in range(1, yd.size()):
					checks.append(["%s_piha%d" % [key, k], yd[k], null])
			for k in Main.BIKE_DUMPS.size():
				checks.append(["pyora%d" % k, M.w(Main.BIKE_DUMPS[k]), null])
			for c in checks:
				var p: Vector3 = c[1]
				var q := PhysicsPointQueryParameters3D.new()
				q.position = Vector3(p.x, Terrain.h(p.x, p.z) + 1.0, p.z)
				q.collision_mask = 0xFFFFFFFF & ~Terrain.COLLISION_LAYER
				var hits := []
				for h in space.intersect_point(q, 8):
					var col: Node = h.collider
					if c[2] != null and (col == c[2] or (c[2] as Node).is_ancestor_of(col)):
						continue
					hits.append("%s@%s" % [col.name, M.to_px((col as Node3D).global_position).round()])
				print("PLACE %s px=%s tie=%.1f talo=%s pinta=%s osumat=%s" % [c[0], M.to_px(p).round(),
					main.world._road_clearance(Vector2(p.x, p.z)), main.world._near_house(Vector2(p.x, p.z), 6.0), main.world.surface_at(p), hits])
			var outside := 0
			for h: Vector2 in main.world._houses:
				if not main.world._in_bounds(h, -1.0):
					outside += 1
			print("PLACE talot yhteensä %d, pelialueen ulkopuolella %d" % [main.world._houses.size(), outside])
			print("PLACE kota %s (OSM %s), torni %s (OSM %s), grillikatos %s, laavu %s" % [
				M.to_px(main.world.kota.global_position).round(), M.KOTA, M.to_px(main.world.kota.to_global(Kota.TOWER_LOCAL)).round(),
				M.LINTUTORNI, M.GRILLIKATOS, M.LAAVU])
		"hilltest":
			# Jyrkin rinne tien varrella: aja ylös ja alas, pysyykö pyörä maan pinnalla.
			var best := Vector3.ZERO
			var slope := 0.0
			for r in M.ROADS:
				for q in r.pts:
					var wq := M.w(q)
					var n := Terrain.normal(wq.x, wq.z)
					if 1.0 - n.y > slope:
						slope = 1.0 - n.y
						best = wq
			var n2 := Terrain.normal(best.x, best.z)
			main.player.global_position = best + Vector3(0, 0.4, 0)
			main.player.rotation.y = atan2(n2.x, n2.z)  # kohti ylämäkeä
			print("HILL at ", best, " slope %.1f %%" % (Vector2(n2.x, n2.z).length() / n2.y * 100.0))
			Input.action_press("forward")
			for i in 360:
				await main.get_tree().physics_frame
				if i % 60 == 0:
					var p := main.player.global_position
					print("HILL t=", i, " y=%.2f ground=%.2f speed=%.1f" % [p.y, Terrain.h(p.x, p.z), main.player.speed])
			Input.action_release("forward")
		"sprinttest":
			# Pisin suora tie: ensin tavallinen poljenta, sitten spurtti (Shift), kunnes kunto loppuu.
			var a := Vector3.ZERO
			var b := Vector3.ZERO
			for r in M.ROADS:
				for j in r.pts.size() - 1:
					var p0 := M.w(r.pts[j])
					var p1 := M.w(r.pts[j + 1])
					if p0.distance_to(p1) > a.distance_to(b):
						a = p0
						b = p1
			if main.player != main.bike:
				main._toggle_mount()
			var d := (b - a).normalized()
			main.bike.global_position = Vector3(a.x, Terrain.h(a.x, a.z) + 0.4, a.z)
			main.bike.rotation.y = atan2(-d.x, -d.z)
			print("SPRINT road %.0f m" % a.distance_to(b))
			var shift := InputEventKey.new()
			shift.keycode = KEY_SHIFT
			Input.action_press("forward")
			for i in 600:
				if i == 180:
					shift.pressed = true
					Input.parse_input_event(shift)
				await main.get_tree().physics_frame
				if i % 60 == 59:
					print("SPRINT t=%d speed=%.1f stamina=%.0f sprinting=%s exhausted=%s fov=%.1f" % [i, main.bike.speed,
						main.walker_out.stamina, main.bike.sprinting, main.walker_out.exhausted, main.bike._cam.fov])
			shift.pressed = false
			Input.parse_input_event(shift)
			Input.action_release("forward")
			# Jalan: juoksu kuluttaa kuntoa, eikä parkissa oleva pyörä saa palauttaa sitä samalla.
			for i in 120:
				await main.get_tree().physics_frame
			main._toggle_mount()
			main.walker_out.stamina = 100.0
			main.walker_out.exhausted = false
			shift.pressed = true
			Input.parse_input_event(shift)
			Input.action_press("forward")
			for i in 120:
				await main.get_tree().physics_frame
			print("SPRINT jalan 2 s juoksua: stamina=%.0f (odotus ~64)" % main.walker_out.stamina)
			shift.pressed = false
			Input.parse_input_event(shift)
			Input.action_release("forward")
		"overlap":
			# Polku ja tie päällekkäin: Järvikujan pää, josta laavupolku lähtee.
			main.player.position = M.w(M.J_H2) + Vector3(-4, 0.3, -9)
			main.player.rotation.y = PI + 0.2
		"walk":
			main._toggle_mount()
			main.walker_out.rotation.y += 0.6
			main.walker_out.stamina = 30.0
			main.walker_out.exhausted = true
		"walkmap":
			main._toggle_mount()
			main.walker_out.global_position += Vector3(40, 0, -60)
			for n in main.find_children("*", "Control", true, false):
				if n.has_method("toggle"):
					n.toggle()
		"fpsmitta":
			# Kuvataajuus eri asetuksilla (kodin edessä, katse Järvikujaa pitkin). Tallennetut asetukset palautetaan.
			var keep := {}
			for k in ["quality", "render_scale", "view_distance"]:
				keep[k] = Settings.get_v(k)
			main._note.hide()
			await main.get_tree().create_timer(2.0).timeout
			var cfgs := [["täysi laatu, 100 %, täysi etäisyys", 3, 1.0, 3], ["erittäin matala, 50 %, täysi etäisyys", 0, 0.5, 3],
				["erittäin matala, 50 %, keski 350 m", 0, 0.5, 1], ["erittäin matala, 50 %, lyhyt 200 m", 0, 0.5, 0],
				["erittäin matala, 100 %, lyhyt 200 m", 0, 1.0, 0], ["täysi laatu, 100 %, lyhyt 200 m", 3, 1.0, 0]]
			for c in cfgs:
				Settings.set_v("quality", c[1])
				Settings.set_v("render_scale", c[2])
				Settings.set_v("view_distance", c[3])
				await main.get_tree().create_timer(1.5).timeout
				var f0 := Engine.get_process_frames()
				var t0 := Time.get_ticks_msec()
				await main.get_tree().create_timer(4.0).timeout
				var fps := float(Engine.get_process_frames() - f0) / ((Time.get_ticks_msec() - t0) / 1000.0)
				var vp: RID = main.get_viewport().get_viewport_rid()
				print("FPS %5.1f  %s | kutsuja %d, kolmioita %d, kohteita %d | prosessi %.1f ms, fysiikka %.1f ms" % [fps, c[0],
					RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
					RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
					RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
			for k in keep:
				Settings.set_v(k, keep[k])
		"fpsosat":
			# Mikä kuluttaa aikaa: laatu 0 / 50 % / 200 m, sitten kutakin pääsolmua vuorotellen pois päältä (prosessi + fysiikka).
			Settings.set_v("quality", 0)
			Settings.set_v("render_scale", 0.5)
			Settings.set_v("view_distance", 0)
			main._note.hide()
			var measure := func(label: String) -> void:
				await main.get_tree().create_timer(0.8).timeout
				var f0 := Engine.get_process_frames()
				var t0 := Time.get_ticks_msec()
				await main.get_tree().create_timer(2.5).timeout
				print("FPS %5.1f  %s" % [float(Engine.get_process_frames() - f0) / ((Time.get_ticks_msec() - t0) / 1000.0), label])
			await measure.call("perus (minikartta näkyvissä)")
			print("marja- ja sienipaikkoja: %d (näkyvät kartalla: %s)" % [main.world.forage.size(), main.world.forage_revealed])
			main._minimap.visible = false
			await measure.call("minikartta piilossa")
			main._minimap.visible = true
			await measure.call("minikartta taas näkyvissä")
			main._minimap.visible = false
			await measure.call("minikartta piilossa (toisto)")
			main._minimap.visible = true

		"minikartta":
			# Minikartan liikkuvat osat: pelaajan nuoli, Päivi, pyörä (kun jalan), tavoite, marja- ja sienipaikat, merkit.
			main._toggle_mount()
			main.world.forage_revealed = true
			var fp: Vector3 = main.world.forage[0].pos
			main.walker_out.global_position = Vector3(fp.x + 6.0, Terrain.h(fp.x + 6.0, fp.z), fp.z)
			main.bike.global_position = main.walker_out.global_position + Vector3(-55, 0, 40)
			main.wife.global_position = main.walker_out.global_position + Vector3(70, 0, -45)
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_a.png"))
			# Liike: kävellään eteenpäin, kartan pitää seurata ja nuolen kääntyä.
			var o0: Vector2 = main._minimap._origin
			Input.action_press("forward")
			for i in 90:
				await main.get_tree().physics_frame
			Input.action_release("forward")
			for i in 3:
				await main.get_tree().process_frame
			print("MINIKARTTA keskipiste siirtyi %.1f m, marjapaikkoja %d, Päivi näkyvissä=%s pyörä=%s" % [
				(main._minimap._origin - o0).length(), main.world.forage.size(), main.wife.is_inside_tree(), main.bike != main.player])
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_b.png"))
		"fpsview":
			CamCtl.fps = true
			CamCtl.pitch = -0.1
		"orbit":
			CamCtl.yaw = 2.3
			CamCtl.pitch = -0.3
			CamCtl._idle = 0.0
		"fpswalk":
			main._toggle_mount()
			CamCtl.fps = true
			CamCtl.pitch = -0.25
			CamCtl.yaw = 0.8
		_:
			return 0
	return 1
