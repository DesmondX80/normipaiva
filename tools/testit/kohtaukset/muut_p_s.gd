extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "muut_p_s". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.

const Main := preload("res://scripts/main.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Mokki := preload("res://scripts/mokki.gd")
const Iskelmat := preload("res://scripts/iskelmat.gd")
const Muskelivene := preload("res://scripts/muskelivene.gd")
const Looks := preload("res://scripts/looks.gd")
const MokkiInterior := preload("res://scripts/mokki_interior.gd")
const SaunaKorjaus := preload("res://scripts/saunakorjaus_game.gd")
const RonttonenGame := preload("res://scripts/ronttonen_game.gd")
const TanssiGame := preload("res://scripts/tanssi_game.gd")
const PyhakoskiLegenda := preload("res://scripts/pyhakoski_legenda.gd")
const RaateLegenda := preload("res://scripts/raate_legenda.gd")
const Saappaat := preload("res://scripts/kumisaappaat.gd")

const KOHTAUKSET := ["riskit", "saunakorjaus_pelaa", "saunakorjaus", "rytmi", "rankkubotti", "saappaat", "puhelin", "rasvanappi", "saloisrata", "satamatie", "sahanranta", "satama", "rintamus", "raate", "pyhakoski", "ronttonen", "reppukaytto", "reppu", "raahepaivi", "purema", "rankkarit_kuvat"]

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
		"saunakorjaus_pelaa":
			# Savusaunan korjaus oikeasti pelaten: kävely paikoille törmäyksineen, E ja minipelit hiiren klikkauksilla ja
			# näppäimillä (ei _finish-oikotietä). Kiukaalla otetaan ensin pieni kivi (ennen jumittui) ja vaihdetaan isoon.
			if main.player == main.bike:
				main._toggle_mount()
			main.mokki.ensure_built()
			main.mokki.set_sauna_fixed(false)
			main.hommat.sauna_fixed = false
			main.hommat.active = true
			main.hommat.tasks = ["saunakorjaus"]
			main.hommat.done.clear()
			main.hommat.progress.clear()
			main._note.visible = false
			var frames := func(n: int) -> void:
				for i in n:
					await main.get_tree().process_frame
			var key := func(action: String) -> void:
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			var move := func(pos: Vector2, mask := 0) -> void:
				var ev := InputEventMouseMotion.new()
				ev.position = pos
				ev.global_position = pos
				ev.button_mask = mask
				Input.parse_input_event(ev)
				await main.get_tree().process_frame
			var click := func(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
				await move.call(pos)
				for pressed in [true, false]:
					var ev := InputEventMouseButton.new()
					ev.position = pos
					ev.global_position = pos
					ev.button_index = button
					ev.pressed = pressed
					Input.parse_input_event(ev)
					await main.get_tree().process_frame
			# Kävely oikeilla ohjaimilla: hahmo käännetään kohti reittipistettä ja "eteen" pohjassa (rinteet, seinät ja
			# lauteet kuten pelaajalla). Jumiin jäädessä (ei edistystä 1,5 s) kuva ja seuraava piste.
			var walk := func(points: Array, tag: String) -> float:
				Input.action_press("forward")
				for wp in points:
					var goal: Vector3 = main.mokki.gpos(wp)
					var best := INF
					var still := 0
					for i in 1800:
						var d: Vector3 = goal - main.walker_out.global_position
						d.y = 0.0
						if d.length() < (0.35 if wp == points[-1] else 0.5):
							break
						main.walker_out.rotation.y = atan2(-d.x, -d.z)
						if d.length() < best - 0.02:
							best = d.length()
							still = 0
						else:
							still += 1
							if still > 90:
								print("KORJAUS %s: jumissa paikassa %s (kohde %s, matkaa %.1f m)" % [tag,
									main.mokki.to_local(main.walker_out.global_position), wp, d.length()])
								Input.action_release("forward")
								var jc := Camera3D.new()
								main.add_child(jc)
								jc.look_at_from_position(main.walker_out.global_position + Vector3(0, 7, 6), main.walker_out.global_position)
								jc.current = true
								await RenderingServer.frame_post_draw
								await RenderingServer.frame_post_draw
								main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_jumi_%s.png" % tag))
								jc.queue_free()
								main.walker_out.activate_camera()
								Input.action_press("forward")
								break
						await main.get_tree().physics_frame
				Input.action_release("forward")
				for i in 10:
					await main.get_tree().physics_frame
				var last: Vector3 = main.mokki.gpos(points[-1])
				return Vector2(main.walker_out.global_position.x - last.x, main.walker_out.global_position.z - last.z).length()
			# Reitinhaku 0,4 m:n ruudukossa: ruutu on vapaa, jos pelaajan kapseli mahtuu (seinät, puut, lauteet), se ei
			# ole vedessä eikä nousu naapuriin ole jyrkkä. Maan korkeus säteellä ylhäältä (lattiat mukaan).
			var space := main.walker_out.get_world_3d().direct_space_state
			var CELL := 0.4
			var x0 := -14.0
			var z0 := 6.0
			var nx := 95
			var nz := 110
			var ground := {}
			var cell_y := func(ix: int, iz: int) -> float:
				var gk := ix * 1000 + iz
				if ground.has(gk):
					return ground[gk]
				var lx := x0 + ix * CELL
				var lz := z0 + iz * CELL
				var y := INF
				if not Mokki.in_water(lx, lz):
					var top: Vector3 = main.mokki.gpos(Vector3(lx, 1.6, lz))
					var rq := PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -4.0, 0))
					rq.exclude = [main.walker_out.get_rid()]
					var hit := space.intersect_ray(rq)
					var gy: float = hit.position.y if not hit.is_empty() else main.mokki.gpos(Vector3(lx, 0, lz)).y
					var sh := CapsuleShape3D.new()
					sh.radius = 0.28
					sh.height = 1.1
					var q := PhysicsShapeQueryParameters3D.new()
					q.shape = sh
					q.transform = Transform3D(Basis(), Vector3(top.x, gy + 0.32 + 0.55, top.z))
					q.exclude = [main.walker_out.get_rid()]
					if space.intersect_shape(q, 1).is_empty():
						y = gy
				ground[gk] = y
				return y
			var find_path := func(from: Vector3, to: Vector3) -> Array:
				var a := Vector2i(roundi((from.x - x0) / CELL), roundi((from.z - z0) / CELL))
				var b := Vector2i(roundi((to.x - x0) / CELL), roundi((to.z - z0) / CELL))
				var prev := {a: a}
				var queue: Array[Vector2i] = [a]
				var head := 0
				while head < queue.size():
					var c: Vector2i = queue[head]
					head += 1
					if c.distance_to(b) < 2.0:
						var pts: Array = []
						var k := c
						while k != a:
							pts.push_front(Vector3(x0 + k.x * CELL, 0, z0 + k.y * CELL))
							k = prev[k]
						pts.append(to)
						return pts
					var cy: float = cell_y.call(c.x, c.y)
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1),
							Vector2i(1, -1), Vector2i(-1, -1)]:
						var n: Vector2i = c + d
						if prev.has(n) or n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz:
							continue
						var ny: float = cell_y.call(n.x, n.y)
						if ny == INF or (cy != INF and absf(ny - cy) > 0.3):
							continue
						prev[n] = c
						queue.append(n)
				return []
			var start: Vector3 = Mokki.KORJAUS_OVI_LOCAL + Vector3(-4.0, 0, 0)
			main.walker_out.global_position = main.mokki.gpos(start) + Vector3(0, 0.5, 0)
			await frames.call(10)
			var game := func() -> Node:
				var gs := main.get_children().filter(func(c): return c is SaunaKorjaus)
				return null if gs.is_empty() else gs[0]
			var open_game := func(step: String) -> Node:
				print("KORJAUS %s: vihje '%s'" % [step, main._hint.text])
				await key.call("interact")
				await frames.call(3)
				return game.call()
			var shot := func(step: String) -> void:
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % step))
			var routes := {"kivet": [start, Mokki.KIVI_LOCAL],
				"kiuas": [start, Mokki.KORJAUS_OVI_LOCAL, Mokki.KORJAUS_IN_LOCAL],
				"lauteet": [Mokki.KORJAUS_IN_LOCAL],
				"terva": [Mokki.KORJAUS_OVI_LOCAL, start, Mokki.KORJAUS_TERVA_LOCAL],
				"luukku": [start, Mokki.KORJAUS_OVI_LOCAL]}
			for step in ["kivet", "kiuas", "lauteet", "terva", "luukku"]:
				var here: Vector3 = main.mokki.to_local(main.walker_out.global_position)
				var route: Array = find_path.call(here, routes[step][-1])
				print("KORJAUS %s: reitti %d pistettä" % [step, route.size()] if not route.is_empty() else "KORJAUS %s: EI REITTIÄ %s -> %s" % [step, here, routes[step][-1]])
				var miss: float = await walk.call(route if not route.is_empty() else routes[step], step)
				print("KORJAUS %s: kävely perillä %.2f m päässä, paikka %s" % [step, miss, main.mokki.to_local(main.walker_out.global_position)])
				if miss > 0.6:
					main.walker_out.global_position = main.mokki.gpos(routes[step][-1]) + Vector3(0, 0.3, 0)  # jatketaan, vika kirjattu
					await frames.call(5)
				for i in 20:
					await main.get_tree().process_frame
				await shot.call("paikka_" + step)  # pelikamerasta: saunan sisällä katon pitää olla poissa
				var g: Node = await open_game.call(step)
				if g == null:
					print("KORJAUS %s: peli ei auennut" % step)
					continue
				var ok := [false]
				g.finished.connect(func(r: bool) -> void: ok[0] = r)
				await frames.call(3)
				var probe: Vector2 = g._area.get_center()
				await move.call(probe)
				var hov := main.get_viewport().gui_get_hovered_control()
				print("KORJAUS hiiri: lähetetty %s, pelissä %s, hiiren alla %s (%s)" % [probe, g._root.get_local_mouse_position(),
					hov, hov.get_path() if hov != null else ""])
				var gui_n := [0]
				g._root.gui_input.connect(func(ev: InputEvent) -> void:
					if ev is InputEventMouseButton:
						gui_n[0] += 1)
				match step:
					"kivet":
						for st in g._stones.duplicate():
							if st.good and is_instance_valid(g) and not g._done:
								await click.call(st.p)
								print("KORJAUS kivi %s: pelin hiiri %s, kerätty %d, humala %.2f" % [st.p, g._mouse, g._got, g.drunk])
					"kiuas":
						for sl in g._slots:
							await click.call((sl.rect as Rect2).get_center())
							await click.call((sl.rect as Rect2).get_center())
						await shot.call("kiuas_tyhja")
						# Ensin pieni kivi käteen (ennen tästä ei päässyt eteenpäin), sitten vaihto isoon.
						await click.call(g._bag_rect(g._bag.find("pieni")).get_center())
						print("KORJAUS kiuas: kädessä '%s'" % g._held)
						for sl in g._slots:
							if not is_instance_valid(g) or g._done:
								break
							var want := "iso" if sl.row == 0 else "pieni"
							if g._held != want:
								await click.call(g._bag_rect(g._bag.find(want)).get_center())
							await click.call((sl.rect as Rect2).get_center())
					"lauteet":
						for i in 3:
							for k in 4:
								await click.call(g._plank_rect(i).get_center() + Vector2(0, -12))
							for k in 2:
								for h in 3:
									if is_instance_valid(g) and not g._done:
										await click.call(g._nail_pos(i, k) + Vector2(8, -6))  # vähän ohi kannan keskeltä
							if i == 0:
								await shot.call("lauteet")
					"terva":
						var w: Rect2 = g._wall()
						var lh: float = w.size.y / g.TH
						for row in g.TH:
							var y: float = w.position.y + (row + 0.5) * lh
							var x: float = w.position.x + 2.0
							while x < w.end.x - 2.0 and is_instance_valid(g) and not g._done:
								Input.parse_input_event(main._mb(Vector2(x, y), true)) if x == w.position.x + 2.0 else null
								await move.call(Vector2(x, y), MOUSE_BUTTON_MASK_LEFT)
								x += 300.0 * main.get_process_delta_time()  # rauhallinen veto, ~300 px/s
							Input.parse_input_event(main._mb(Vector2(x, y), false))
							await frames.call(2)
							for dr in g._drips.duplicate():
								await click.call(dr.p + Vector2(0, 6), MOUSE_BUTTON_RIGHT)
							if row == 2:
								await shot.call("terva")
						for dr in g._drips.duplicate() if is_instance_valid(g) else []:
							await click.call(dr.p + Vector2(0, 6), MOUSE_BUTTON_RIGHT)
						await main.get_tree().create_timer(1.3).timeout
						if is_instance_valid(g) and not g._done:
							print("KORJAUS terva: kattavuus %.2f valumia %d" % [g._coverage(), g._drips.size()])
					"luukku":
						for i in 16:
							await key.call("left" if i % 2 == 0 else "right")
						print("KORJAUS luukku: vaihe %s" % g._phase)
						Input.action_press("forward")
						for i in 300:
							await main.get_tree().process_frame
							if g._lift > 0.68:
								break
						await key.call("interact")
						Input.action_release("forward")
						await frames.call(3)
						print("KORJAUS luukku: vaihe %s, nosto %.2f, pelejä auki %d" % [g._phase, g._lift,
							main.get_children().filter(func(c): return c is SaunaKorjaus).size()])
						var c: Vector2 = g._area.position + Vector2(g._area.size.x / 2.0, 260)
						var a := -PI / 2.0
						for i in 400:
							if not is_instance_valid(g) or g._done:
								break
							a += 0.25
							await move.call(c + Vector2(cos(a), sin(a)) * 90.0)
						await shot.call("luukku")
				await main.get_tree().create_timer(1.3).timeout  # vaihe kuitataan 0,8 s viiveellä
				print("KORJAUS %s: nappitapahtumia pelissä %d" % [step, gui_n[0]])
				print("KORJAUS %s: valmis %s, edistyminen %s, viesti '%s'" % [step, ok[0], main.hommat.progress.get("korjaus", {}).keys()
					if step != "kivet" else main.hommat.progress.get("kivet", false), main._msg.text.replace("\n", " | ")])
			print("KORJAUS lopuksi: homma tehty %s, sauna korjattu %s" % ["saunakorjaus" in main.hommat.done, main.mokki.sauna_fixed])
		"saunakorjaus":
			# Savusaunan korjaus: Santun homma, kivikasa, neljä vaihetta (kuvat minipeleistä, vaiheet kuitataan), lopuksi
			# korjattu sauna (tervatut seinät, suora ovi) ja lämpenemisen vertailu.
			if main.player == main.bike:
				main._toggle_mount()
			main.mokki.ensure_built()
			main.mokki.set_sauna_fixed(false)
			main.hommat.sauna_fixed = false
			main.hommat.active = true
			main.hommat.tasks = ["saunakorjaus"]
			main.hommat.done.clear()
			main.hommat.progress.clear()
			main._note.visible = false
			var press := func() -> void:
				await main.get_tree().process_frame
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
			var go := func(local: Vector3) -> void:
				main.walker_out.global_position = main.mokki.gpos(local) + Vector3(0, 0.3, 0)
				main.walker_out.velocity = Vector3.ZERO
				for i in 8:
					await main.get_tree().physics_frame
				for i in 3:
					await main.get_tree().process_frame
			print("SAUNA kivikasa vedessä %s" % Mokki.in_water(Mokki.KIVI_LOCAL.x, Mokki.KIVI_LOCAL.z))
			# Lämpeneminen rikkinäisenä.
			main.mokki.sauna_heat = 0.0
			main.mokki.sauna_fire_on = true
			main.mokki.sauna_fuel = 30.0
			for i in 60:
				await main.get_tree().physics_frame
			var broken_heat: float = main.mokki.sauna_heat
			main.mokki.sauna_fire_on = false
			main.mokki.sauna_heat = 0.0
			for step in ["kivet", "kiuas", "lauteet", "terva", "luukku"]:
				var at: Vector3 = {"kivet": Mokki.KIVI_LOCAL, "kiuas": Mokki.KORJAUS_IN_LOCAL, "lauteet": Mokki.KORJAUS_IN_LOCAL,
					"terva": Mokki.KORJAUS_TERVA_LOCAL, "luukku": Mokki.KORJAUS_OVI_LOCAL}[step]
				await go.call(at)
				print("SAUNA %s: hint '%s'" % [step, main._hint.text])
				await press.call()
				var g: Node = main.get_children().filter(func(c): return c is SaunaKorjaus).front()
				if g == null:
					print("SAUNA %s: peli ei auennut" % step)
					continue
				for i in 20:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % step))
				g._finish(true)
				await main.get_tree().process_frame
				print("SAUNA %s valmis: viesti '%s'" % [step, main._msg.text.replace("\n", " | ")])
			print("SAUNA lopuksi: homma tehty %s, korjattu %s" % ["saunakorjaus" in main.hommat.done, main.mokki.sauna_fixed])
			main.mokki.sauna_fire_on = true
			main.mokki.sauna_fuel = 30.0
			for i in 60:
				await main.get_tree().physics_frame
			print("SAUNA lämpö 1 s: rikki %.3f, korjattu %.3f" % [broken_heat, main.mokki.sauna_heat])
			main.mokki.sauna_fire_on = false
			await go.call(Mokki.KORJAUS_OVI_LOCAL + Vector3(-4.0, 0, 0))
			var cam := Camera3D.new()
			main.add_child(cam)
			cam.global_position = main.mokki.gpos(Mokki.SAUNA_LOCAL + Vector3(-6.0, 2.5, 4.0))
			cam.look_at(main.mokki.gpos(Mokki.SAUNA_LOCAL + Vector3(0, 1.0, 1.0)), Vector3.UP)
			cam.current = true
			for i in 10:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_korjattu.png"))
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%02d.png" % int(h * 10)))
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
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_lamppu.png"))
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
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
			main.mokki.ensure_built()
			main._enter_mokki("ovi")
			for i in 5:
				await main.get_tree().process_frame
			await snap.call("_mokki_tulo.png")
			print("SAAPPAAT mökki pelikamera esine %s px" % px_size.call(main.mokki_int._boots))
			var mp: Vector3 = main.mokki_int._boots.global_position
			var mx: Vector3 = main.mokki_int.global_basis.x
			var mz: Vector3 = main.mokki_int.global_basis.z
			var mm := mp + Vector3(0, 0.18, 0)
			await close.call(mm, mm + mx * 1.1 + Vector3(0, 0.35, 0), "_mokki_esine_edesta.png")  # kärjet tupaan (+X)
			await close.call(mm, mm + mz * 1.1 + mx * 0.2 + Vector3(0, 0.3, 0), "_mokki_esine_paadysta.png")  # ikkunan puolelta (-Z:ssä uuni)
			main.mokki_int.walker.position = main.mokki_int.SPOTS.saappaat[0]
			for i in 5:
				await main.get_tree().process_frame
			print("SAAPPAAT mökki vihje '%s'" % main._hint.text)
			await press.call()
			check.call("mökin matto tyhjä", main.mokki_int._boots.visible, false)
			await menu.call("reppuun")
			print("SAAPPAAT mökki boots %s, reppu %s, esine näkyvissä %s, viesti '%s'" % [Looks.boots, Saappaat.bag,
				main.mokki_int._boots.visible, main._msg.text])
			check.call("mökki reppuun", [Looks.boots, Saappaat.bag, main.mokki_int._boots.visible, types.call()],
				["", "repussa", false, ["lenkkari"]])
			var bag_cf := ConfigFile.new()
			bag_cf.load(Main.SAVE_PATH)
			check.call("tallennus reppu", bag_cf.get_value("pelaaja", "saappaat_repussa", ""), "repussa")
			await snap.call("_mokki.png")
			# Mökin matolle: sama pari näkyy taas kummallakin matolla.
			await press.call()
			await menu.call("tahan")
			check.call("mökin matolle", [Looks.boots, Saappaat.bag, main.mokki_int._boots.visible], ["", "", true])
			await press.call()
			await menu.call("jalkaan")
			check.call("mökiltä jalkaan", [Looks.boots, Saappaat.bag, main.mokki_int._boots.visible], ["jalassa", "", false])
			# 4. Kotona E: omat kengät takaisin.
			main.mokki_int.exit_door = "ovi"
			main._on_mokki_exited()
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", v[0] + ".png"))
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
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_luukku.png"))
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", vw[0] + ".png"))
			# Aikataulun juna: odota asemalla (kello hyppää), juna tulee laiturille ja seisoo; kuva laiturilta.
			Engine.time_scale = 4.0
			var tr: Node3D = main.world.train
			main.walker_out.global_position = main.world.station_pos + Vector3(0, 0.5, 0)
			for i in 5:
				await main.get_tree().process_frame
			print("RATA vihje ennen: '%s'" % main._hint.text)
			main._station_use("saloinen", "vaala")
			var t0 := Time.get_ticks_msec()
			while not tr.at_station() and Time.get_ticks_msec() - t0 < 30000:
				await main.get_tree().process_frame
			Engine.time_scale = 1.0
			print("RATA juna laiturilla %s %.1f s, vihje '%s'" % [tr.at_station(), (Time.get_ticks_msec() - t0) / 1000.0, main._hint.text])
			cam.look_at_from_position(w3.call(Vector2(30, 520), 6.0), w3.call(Vector2(90, 504), 2.0))
			cam.current = true
			for i in 10:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_juna.png"))
			print("RATA %d pistettä, %.0f m" % [rp.size(), rp[0].distance_to(rp[rp.size() - 1])])
			main.get_tree().quit()
		"satamatie":
			# Uusi Satamantie (kapea asfalttikatu K-Marketilta radan yli satamaan): kuvat _alku, _rata, _ylhaalta, _liittyma, _satama.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var look := func(from: Vector3, to: Vector3, tag: String) -> void:
				var rc := Camera3D.new()
				main.add_child(rc)
				rc.current = true
				rc.look_at_from_position(vl.to_global(from), vl.to_global(to), Vector3.UP)
				for i in 8:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % tag))
				rc.queue_free()
			var sat: Dictionary = {}
			for r in vl.data.side_roads:
				if r.get("name", "") == "Satamantie":
					sat = r
			var p0 := Vector2(sat.pts[0][0], sat.pts[0][1])
			var p1 := Vector2(sat.pts[sat.pts.size() / 3][0], sat.pts[sat.pts.size() / 3][1])
			var pm := (p0 + p1) / 2.0
			print("SATAMATIE pisteitä %d, katu %s" % [sat.pts.size(), sat.get("street", 0)])
			await look.call(Vector3(p0.x - 14, vl.h(p0.x, p0.y) + 6.0, p0.y - 10), Vector3(p0.x + 14, vl.h(p0.x, p0.y), p0.y + 24), "alku")
			await look.call(Vector3(p0.x - 30, vl.h(p0.x, p0.y) + 40.0, p0.y - 20), Vector3(p1.x, vl.h(p1.x, p1.y), p1.y), "ylhaalta")
			await look.call(Vector3(pm.x - 22, vl.h(pm.x, pm.y) + 4.0, pm.y - 22), Vector3(pm.x + 10, vl.h(pm.x, pm.y), pm.y + 10), "rata")
			var pj := Vector2(sat.pts[sat.pts.size() / 2][0], sat.pts[sat.pts.size() / 2][1])
			await look.call(Vector3(pj.x - 30, vl.h(pj.x, pj.y) + 30.0, pj.y - 30), Vector3(pj.x, vl.h(pj.x, pj.y), pj.y), "liittyma")
			main.get_tree().quit()
		"sahanranta":
			# Siirretty asema ja risteys, uusi satama ja Uiton sauna (vaala.gd _build_uitto): kuvat _asema, _risteys, _satama,
			# _uitto_*; E saunan ovella ja laiturilla (välianimaatiot, kuvat _sauna_*, _uinti_*). Lokiin ovet ja vihjeet.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var shot := func(tag: String) -> void:
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % tag))
			var look := func(from: Vector3, to: Vector3, tag: String) -> void:
				var rc := Camera3D.new()
				main.add_child(rc)
				rc.current = true
				rc.look_at_from_position(vl.to_global(from), vl.to_global(to), Vector3.UP)
				for i in 8:
					await main.get_tree().process_frame
				await shot.call(tag)
				rc.queue_free()
			var doors: Dictionary = {}
			for d in vl.doors:
				doors[d.id] = d
			print("SAHANRANTA ovet: asema %s, uittosauna %s, uittouinti %s, satama %s, katko %s" % [
				doors.get("asema", {}).get("pos"), doors.get("uittosauna", {}).get("pos"), doors.get("uittouinti", {}).get("pos"),
				doors.get("satama", {}).get("pos"), vl.cache_pos])
			main.helena_vaalassa = OS.get_cmdline_user_args().has("--helena")  # Uiton sauna Helenan kanssa Santun sijaan
			var sd: Vector3 = doors.asema.pos
			await look.call(sd + Vector3(-30, 25, -45), sd + Vector3(0, 0, 0), "asema")
			await look.call(sd + Vector3(-95, 70, -40), sd + Vector3(-75, 0, 10), "risteys")
			await look.call(sd + Vector3(-60, 120, 20), sd + Vector3(-60, 0, 40), "risteys_ylhaalta")
			var sp: Vector3 = vl.siitari_park
			await look.call(sp + Vector3(-25, 40, -25), sp, "siitari_ylha")
			await look.call(sp + Vector3(-18, 5, 18), sp + Vector3(-8, 1, 0), "siitari_eteen")
			var rcn: Dictionary = vl.data.keskusta.asema.roundabout
			var rcp := Vector3(rcn.c[0], vl.h(rcn.c[0], rcn.c[1]), rcn.c[1])
			await look.call(rcp + Vector3(0, 40, 22), rcp, "risteys_zabuki")
			var ud: Vector3 = doors.uittosauna.pos
			var dd := Vector3(vl.uitto_dir.x, 0, vl.uitto_dir.y)
			var sdv := dd.cross(Vector3.UP)
			await look.call(ud + Vector3(0, 60, 0) - dd * 20.0, ud, "uitto_yla")
			await look.call(ud + dd * 9.0 + sdv * 6.0 + Vector3(0, 2.5, 0), ud - dd * 5.0 + Vector3(0, 1.4, 0), "uitto_sauna")
			await look.call(ud + dd * 14.0 - sdv * 12.0 + Vector3(0, 3.5, 0), ud - dd * 4.0 - sdv * 9.0 + Vector3(0, 1.2, 0), "uitto_makasiini")
			var pd: Vector3 = doors.uittouinti.pos
			await look.call(pd + dd * 9.0 + sdv * 5.0 + Vector3(0, 2.5, 0), pd - dd * 1.0 + Vector3(0, 0.5, 0), "uitto_laituri")
			await look.call(pd + dd * 3.5 + sdv * 3.0 + Vector3(0, 1.8, 0), pd + Vector3(0, 0.4, 0), "uitto_tikkaat")
			await look.call(doors.satama.pos + Vector3(0, 45, 0) - Vector3(vl.satama_dir.x, 0, vl.satama_dir.y) * 30.0, doors.satama.pos, "satama")
			# E saunan ovella.
			if main.mopo_trip.on_foot == null:
				main._mopo_dismount()
			main.walker_out.global_position = vl.to_global(ud + Vector3(0, 0.6, 0))
			for i in 20:
				await main.get_tree().process_frame
			print("SAHANRANTA sauna vihje '%s'" % main.mopo_trip.hint)
			Input.action_press("interact")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("interact")
			var k := 0
			while not (main.cutscene.busy or main.state == "cutscene") and k < 30:
				await main.get_tree().create_timer(0.2).timeout
				k += 1
			for t in 8:
				await main.get_tree().create_timer(3.0).timeout
				await shot.call("sauna_%d" % t)
			k = 0
			while (main.cutscene.busy or main.state == "cutscene") and k < 90:
				await main.get_tree().create_timer(1.0).timeout
				k += 1
			print("SAHANRANTA sauna valmis (%d s), tila %s, stressi %.2f" % [k, main.state, main.tilat.value("stressi")])
			main.walker_out.global_position = vl.to_global(pd + Vector3(0, 0.6, 0))
			for i in 20:
				await main.get_tree().process_frame
			print("SAHANRANTA uinti vihje '%s'" % main.mopo_trip.hint)
			Input.action_press("interact")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("interact")
			k = 0
			while not (main.cutscene.busy or main.state == "cutscene") and k < 30:
				await main.get_tree().create_timer(0.2).timeout
				k += 1
			for t in 5:
				await main.get_tree().create_timer(3.0).timeout
				await shot.call("uinti_%d" % t)
			k = 0
			while (main.cutscene.busy or main.state == "cutscene") and k < 90:
				await main.get_tree().create_timer(1.0).timeout
				k += 1
			print("SAHANRANTA uinti valmis (%d s), tila %s" % [k, main.state])
			main.get_tree().quit()
		"satama":
			# Mopolla satamaan, E laiturilla, autopilotti ajaa veneen kaakkoon kartan reunaan ja takaisin laiturille.
			# Lokiin törmäykset, huippunopeus, humala ja kello; kuvat _satama, _laituri, _kyltti, _vene_*, _ajo, _kaanne, _reuna, _kartta.
			var saved_sat := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.tilat.add("humala", -1.0)
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var sdoor := Vector3.INF
			for d in vl.doors:
				if d.id == "satama":
					sdoor = d.pos
			if sdoor == Vector3.INF:
				print("SATAMA: ei ovea")
				main.get_tree().quit()
				return 2
			var shot := func(tag: String) -> void:
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % tag))
			var look := func(from: Vector3, to: Vector3, tag: String) -> void:
				var rc := Camera3D.new()
				main.add_child(rc)
				rc.current = true
				rc.look_at_from_position(vl.to_global(from), vl.to_global(to), Vector3.UP)
				for i in 8:
					await main.get_tree().process_frame
				await shot.call(tag)
				rc.queue_free()
			var tf: Transform3D = vl.satama_boat_tf
			var bp: Vector3 = tf.origin
			var up := Vector3(0, 1, 0)
			await look.call(vl.satama_park + Vector3(0, 40, 0) + vl.satama_dir.x * Vector3(1, 0, 0) * -30.0, bp, "satama")
			await look.call(vl.satama_door + Vector3(vl.satama_dir.x, 0, vl.satama_dir.y) * -6.0 + Vector3(0, 3.5, 0), vl.satama_dock, "laituri")
			await look.call(vl.satama_park + up * 2.0 + Vector3(vl.satama_dir.x, 0, vl.satama_dir.y) * -8.0, vl.satama_park + up * 2.4, "kyltti")
			for v in [["sivu", Vector3(5.5, 1.8, 0)], ["pera", Vector3(0, 2.2, 6.5)], ["keula", Vector3(0, 2.0, -7.0)], ["yla", Vector3(0.1, 8.0, 0.1)]]:
				await look.call(bp + tf.basis * (v[1] as Vector3), bp + up * 0.8, "vene_" + v[0])
			var hum0: float = main.tilat.value("humala")
			# Mopo laiturin juureen ja E.
			if main.mopo_trip.on_foot != null:
				main.walker_out.global_position = main.mopo_trip.to_global(sdoor + Vector3(1.5, 0.6, 0))
			else:
				main.mopo_trip.mopo.position = sdoor + Vector3(1.5, 0.8, 0)
			if main.mopo_trip.on_foot == null:
				main._mopo_dismount()
			for i in 20:
				await main.get_tree().process_frame
			print("SATAMA vihje '%s'" % main.mopo_trip.hint)
			Input.action_press("interact")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().create_timer(0.8).timeout
			var game: Node = null
			for c in vl.get_children():
				if c is Muskelivene:
					game = c
			if game == null:
				print("SATAMA: ajoa ei käynnistynyt, tila %s" % main.state)
				main.get_tree().quit()
				return 2
			print("SATAMA ajossa: tila %s, hud %s, mopo parkissa" % [main.state, main._hud.visible])
			# Kohde: kaakkoon kauimpana oleva ruutu, jonne näkölinja on vapaa; valitaan uudelleen joka sekunti.
			var best_far := 0.0
			var bumps := 0
			var peak := 0.0
			var edge_hit := false
			var stuck := 0.0
			var last_p: Vector3 = game._pos
			var phase := "ulos"
			var trail: Array[Vector2] = []  # menoreitti: takaisin ajetaan samaa reittiä (ranta voi olla suoran välissä)
			var t_all := 0.0
			var back_until := 0.0
			var shots_done := {}
			while t_all < 240.0:
				var gp: Vector3 = game._pos
				var los := func(a: Vector2, b: Vector2) -> bool:
					var n := int(a.distance_to(b) / 8.0) + 1
					for i in range(1, n + 1):
						var q := a.lerp(b, float(i) / n)
						if not vl.boat_free(q.x, q.y):
							return false
					return true
				var goal := Vector2.ZERO
				if phase == "ulos" and t_all > 90.0:  # testin aikaraja: käännytään takaisin, jotta paluu ehtii
					phase = "takaisin"
				if phase == "ulos":
					var sc := -INF
					for a in 48:
						var ang := TAU * a / 48.0
						for dist in [60.0, 150.0, 300.0, 600.0, 1200.0]:
							var q: Vector2 = Vector2(gp.x, gp.z) + Vector2(cos(ang), sin(ang)) * dist
							if los.call(Vector2(gp.x, gp.z), q):
								var s: float = (q - Vector2(bp.x, bp.z)).dot(Vector2(1, 1).normalized())
								if s > sc:
									sc = s
									goal = q
					best_far = maxf(best_far, Vector2(gp.x - bp.x, gp.z - bp.z).length())
					if trail.is_empty() or Vector2(gp.x, gp.z).distance_to(trail[-1]) > 30.0:
						trail.append(Vector2(gp.x, gp.z))
					if goal == Vector2.ZERO or (goal - Vector2(gp.x, gp.z)).length() < 40.0:
						edge_hit = true
						await shot.call("reuna")
						phase = "takaisin"
				if phase == "takaisin":
					while not trail.is_empty() and Vector2(gp.x, gp.z).distance_to(trail[-1]) < 25.0:
						trail.pop_back()
					goal = trail[-1] if not trail.is_empty() else Vector2(game.start.origin.x, game.start.origin.z)
					if trail.is_empty() and Vector2(gp.x, gp.z).distance_to(Vector2(game.start.origin.x, game.start.origin.z)) < 4.5 and absf(game._speed) < 1.5:
						Input.action_release("forward")
						Input.action_release("left")
						Input.action_release("right")
						print("DBGS ennen E: tila %s speed %.2f near %s t %.1f" % [game._state, game._speed, game._near_dock(), game._t])
						Input.action_press("interact")
						await main.get_tree().create_timer(0.2).timeout  # kestää yli fysiikkatikin (is_just_pressed)
						Input.action_release("interact")
						break
				var to := goal - Vector2(gp.x, gp.z)
				var want := atan2(-to.x, -to.y)
				var err := wrapf(want - game._yaw, -PI, PI)
				Input.action_release("left")
				Input.action_release("right")
				if err > 0.08:
					Input.action_press("left")
				elif err < -0.08:
					Input.action_press("right")
				var dist_goal := to.length()
				if t_all < back_until:  # reunasta peruutetaan ensin irti
					Input.action_release("forward")
					Input.action_press("back")
					Input.action_press("left")
					await main.get_tree().create_timer(0.25).timeout
					t_all += 0.25
					continue
				if phase == "takaisin" and trail.is_empty() and dist_goal < 40.0 and absf(game._speed) > 3.0:
					Input.action_release("forward")
					Input.action_press("back")
				elif absf(err) < 1.2 or absf(game._speed) < 3.0:  # paikallaan ei käännytä: kaasu ensin
					Input.action_release("back")
					Input.action_press("forward")
				else:
					Input.action_release("forward")
				peak = maxf(peak, absf(game._speed))
				if game._bump_cd > 0.55:
					bumps += 1
				stuck = stuck + 0.25 if (gp - last_p).length() < 0.3 else 0.0
				last_p = gp
				if stuck > 8.0 and phase == "ulos" and best_far > 300.0:
					edge_hit = true  # kartan reuna: vene ei pääse pidemmälle, käännytään takaisin
					await shot.call("reuna")
					phase = "takaisin"
					stuck = 0.0
					back_until = t_all + 4.0
				if stuck > 8.0:
					print("SATAMA: jumissa kohdassa %s" % gp)
					break
				if peak > 12.0 and not shots_done.has("ajo") and absf(game._speed) > 12.0:
					shots_done["ajo"] = true
					await shot.call("ajo")
				if absf(game._roll) > 0.12 and not shots_done.has("kaanne"):
					shots_done["kaanne"] = true
					await shot.call("kaanne")
				if phase == "ulos" and not shots_done.has("kartta") and t_all > 6.0:
					shots_done["kartta"] = true
					await shot.call("minikartta")
				await main.get_tree().create_timer(0.25).timeout
				t_all += 0.25
			for a in ["forward", "back", "left", "right"]:
				Input.action_release(a)
			await main.get_tree().create_timer(6.0 if phase == "takaisin" else 1.5).timeout  # laituriin liukuminen kestää
			print("SATAMA ajo: %.0f s, huippu %.0f km/h, törmäyksiä %d, kauimmas %.0f m, reunakosketus %s, vaihe %s" % [t_all, peak * 3.6, bumps, best_far, edge_hit, phase])
			print("SATAMA lopussa: tila %s, ajo vielä %s, humala %.2f -> %.2f, mopo %s, jalan %s" % [main.state, is_instance_valid(game) and game.is_inside_tree(), hum0, main.tilat.value("humala"), main.mopo_trip.mopo.position, main.mopo_trip.on_foot != null])
			main._save_game()
			print("SATAMA tallennus ok, tila %s" % main.state)
			await shot.call("loppu")
			if not saved_sat.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_sat)
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
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path)
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
					await RenderingServer.frame_post_draw
					main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%d_%s.png" % [i, k[0]]))
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
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_alue.png"))
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
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_alue.png"))
			main.get_tree().quit()
		"ronttonen":
			# Rönttösten leivonta (#15): kolme vaihetta (kuva kustakin), erä talteen, vienti Päiville ja kahvipöytä (kuva).
			main._note.visible = false
			print("RO spot: %s" % [MokkiInterior.SPOTS.has("ronttonen")])
			var ro_shot := func(name: String) -> void:
				for i in 3:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % name))
			var ro_ev := func(g: Node, pos: Vector2, rel := Vector2.ZERO, pressed := true, motion := false) -> void:
				var ev: InputEvent
				if motion:
					var m := InputEventMouseMotion.new()
					m.position = pos
					m.relative = rel
					m.button_mask = MOUSE_BUTTON_MASK_LEFT
					ev = m
				else:
					var b := InputEventMouseButton.new()
					b.position = pos
					b.button_index = MOUSE_BUTTON_LEFT
					b.pressed = pressed
					b.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
					ev = b
				g._gui(ev)
				g._mouse = pos
				await main.get_tree().process_frame
			var g := RonttonenGame.new()
			var ro_ok := [false]
			g.finished.connect(func(ok: bool) -> void: ro_ok[0] = ok)
			main.add_child(g)
			for i in 4:
				await main.get_tree().process_frame
			var ro_c: Vector2 = g._center
			await ro_ev.call(g, ro_c, Vector2.ZERO, true)
			for i in 90:
				await ro_ev.call(g, ro_c + Vector2(sin(i * 0.7) * 60.0, cos(i * 0.5) * 30.0), Vector2(14, 0) if i % 2 == 0 else Vector2(0, 14), true, true)
				if i == 30:
					await ro_shot.call("1_kaulinta")
				if g.mode != "kaulinta":
					break
			print("RO kaulinta: vaihe %s px %.2f py %.2f" % [g.mode, g._px, g._py])
			await ro_ev.call(g, ro_c, Vector2.ZERO, false)
			await ro_shot.call("2_kaulittu")
			await ro_ev.call(g, g._bowl(1), Vector2.ZERO)
			print("RO puolukka ennen muusia: kädessä '%s'" % g._held)
			for i in 4:
				await ro_ev.call(g, g._bowl(0))
				await ro_ev.call(g, ro_c + Vector2(-100 + i * 66, (i % 2) * 20 - 10))
				if i == 1:
					await ro_ev.call(g, g._bowl(0))
					await ro_ev.call(g, ro_c + Vector2(0, 150))
					print("RO ohi: muusia %d" % g._muusi.size())
			await ro_shot.call("3_muusi")
			for i in 3:
				await ro_ev.call(g, g._bowl(1))
				await ro_ev.call(g, ro_c + Vector2(-70 + i * 70, (i % 2) * 24 - 12))
			await ro_ev.call(g, g._bowl(0))
			await ro_shot.call("4_puolukka")
			print("RO täyte: vaihe %s muusi %d marjoja %d" % [g.mode, g._muusi.size(), g._berries.size()])
			for i in 9:
				await ro_ev.call(g, g._pleat_pos(i))
			await ro_shot.call("5_nyppy_kesken")
			for i in range(9, 18):
				await ro_ev.call(g, g._pleat_pos(i))
			print("RO nyppy: vaihe %s" % g.mode)
			await main.get_tree().create_timer(1.0).timeout
			await ro_shot.call("6_valmis")
			for i in 160:
				await main.get_tree().process_frame
				if ro_ok[0]:
					break
			print("RO valmis: ok %s" % ro_ok[0])
			# Erä talteen ja vienti Päiville.
			main.ronttoset = 3
			var rm0 := main.mielihyva
			main.day = 5
			main._kahvipoyta_day = -1
			main._give_ronttoset()
			print("RO annettu: rönttösiä %d, kahvipöytä %s, mielihyvä %.0f -> %.0f" % [main.ronttoset, main._kahvipoyta_day == main.day, rm0, main.mielihyva])
			main._give_ronttoset()
			print("RO toinen kerta samana päivänä: rönttösiä %d" % main.ronttoset)
			var cam := Camera3D.new()
			main.home_int.add_child(cam)
			cam.position = Vector3(3.6, 1.7, 0.3)
			cam.look_at(main.home_int.to_global(Vector3(3.6, 0.8, -0.8)))
			cam.current = true
			await ro_shot.call("7_kahvipoyta")
			cam.position = Vector3(3.6, 1.1, -0.1)
			cam.look_at(main.home_int.to_global(Vector3(3.6, 0.8, -0.85)))
			await ro_shot.call("8_kahvipoyta_lahelta")
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
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_tooltip.png"))
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", suffix))
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
			main.mokki.ensure_built()  # pelissä mökki rakentuu kyydin aikana; testi menee sinne suoraan
			main.walker_out.global_position = main.mokki.porch_pos(3.0)
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
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_kulma.png"))
			if pako:
				main.raahe_int.walker.position = main.raahe_int.spots.ylos[0] + Vector3(-3.0, 0, -2.0)
				await main.get_tree().create_timer(6.0).timeout
				print("PAIVI 6 s: tila=%s kellarissa=%s" % [main.raahe_int._paivi_mode, main.raahe_int._cellar_of(main.raahe_int._paivi.position)])
				print("PAIVI kellarissa: päivi kellarissa=%s näkyy=%s" % [main.raahe_int._cellar_of(main.raahe_int._paivi.position), main.raahe_int._paivi.visible])
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_kellari.png"))
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
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_dog.png"))
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
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % name))
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
