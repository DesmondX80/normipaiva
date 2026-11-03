extends Node
## Sinikan ovilappu, kuistin kori ja piirakka (B, scripts/sinikan_kuisti.gd + main.gd _sinikka_kuisti_logic).
## Ajo: tools/testit/aja.sh scene sinikanlappu. main.gd palauttaa tallennuksen.
## K1 näkyvyys kellon mukaan, K2–K3 tekstit, K4 paperin rako oveen, K5 teksti mahtuu, K6 kehote ja E, K7 kartta ja
## tallennus, K8 korin rako portaaseen, K9–K11 korin tilat ja piirakka, K12 tallennus tiloittain, K13 puhereitti,
## K15 ruutuaika ja kuvat. Viat "TESTI VIKA" -riveinä.

const SinikanKuisti := preload("res://scripts/sinikan_kuisti.gd")
const SinikanKuistiMallit := preload("res://scripts/sinikan_kuisti_mallit.gd")
const Terrain := preload("res://scripts/terrain.gd")

var main: Node3D
var vikoja := 0
var k: Dictionary
var root: Node3D
var cam: Camera3D


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + t)


func _shot_path(suffix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			return a.substr(7).replace(".png", suffix + ".png")
	return "user://sinikanlappu" + suffix + ".png"


## Päivi näkisi pelaajan Sinikan pihalla ja nappaisi (uusi päivä kesken testin): kiinnijäänti pois testin ajaksi.
## Uusi päivä luo uuden auton (_spawn_threats), joten tarkistetaan joka odotuksessa.
func _no_wife() -> void:
	if main.wife == null:
		return
	if main.wife.spotted.is_connected(main._on_wife_spotted):
		main.wife.spotted.disconnect(main._on_wife_spotted)
	if main.wife.caught.is_connected(main._on_wife_caught):
		main.wife.caught.disconnect(main._on_wife_caught)


func _frames(n := 4) -> void:
	_no_wife()
	for i in n:
		await get_tree().process_frame


func _phys(n := 4) -> void:
	_no_wife()
	for i in n:
		await get_tree().physics_frame


func _snap(suffix: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_path(suffix))


func _press() -> void:
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")
	await _frames(3)


## Ankkurin paikallinen piste maailmaan (root: -Z = ulos, y = talon pohja).
func _w(local: Vector3) -> Vector3:
	return root.global_transform * local


## Pelaaja ankkurin paikalliseen kohtaan (x, z), maahan.
func _put(local_xz: Vector2) -> void:
	var p := _w(Vector3(local_xz.x, 0, local_xz.y))
	main.walker_out.global_position = Vector3(p.x, maxf(Terrain.h(p.x, p.z), root.global_position.y) + 0.35, p.z)
	main.walker_out.velocity = Vector3.ZERO
	await _phys(6)
	await _frames(3)


## Solmun MeshInstance3D:iden yhteinen AABB ankkurin paikallisissa koordinaateissa (vain näkyvät).
func _aabb(n: Node3D) -> AABB:
	var inv := root.global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).is_visible_in_tree() or mi.mesh == null:
			continue
		var t: Transform3D = inv * mi.global_transform
		var a: AABB = mi.mesh.get_aabb()
		for i in 8:
			var p: Vector3 = t * a.get_endpoint(i)
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	return out


func _view(from_l: Vector3, at_l: Vector3, fov := 50.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(_w(from_l), _w(at_l), Vector3.UP)
	cam.current = true


func _label(n: Node) -> Label3D:
	var ls := n.find_children("*", "Label3D", true, false)
	return ls[0] if not ls.is_empty() else null


func run() -> void:
	_no_wife()
	for i in 600:
		if main.state == "ulkona":
			break
		await get_tree().process_frame
	if main.player == main.bike:
		main._toggle_mount()
	await _frames(5)
	k = main.world.sinikka_kuisti
	if k.is_empty():
		_vika("world.sinikka_kuisti puuttuu (osa A)")
		return
	root = k.root
	main.sk = SinikanKuisti.new()
	main.sinikka_task = 0
	main.bucket.erase("mustikka")
	main._today.clear()
	main.day = 1
	cam = Camera3D.new()
	main.add_child(cam)
	var lappu: Node3D = k.lappu
	var kori: Node3D = k.kori
	var marjat: Node3D = k.marjat
	var piirakka: Node3D = k.piirakka
	await _put(Vector2(6.0, -8.0))  # sivussa, ei kuvissa

	# K1: lappu näkyy vain, kun Sinikka on poissa (8–10 ja 12–17).
	for c in [7.0, 8.0, 9.5, 11.0, 12.0, 16.5, 17.5]:
		main.clock_min = c * 60.0 + 1.0
		await _frames(3)
		var want: bool = (c >= 8.0 and c < 10.0) or (c >= 12.0 and c < 17.0)
		print("SL K1 klo %.1f: lappu %s, away %s (tila %s, päivä %d, viesti '%s')" % [c, lappu.visible, main._sinikka_away(),
			main.state, main.day, main._msg.text.left(60)])
		if lappu.visible != want or lappu.visible != main._sinikka_away():
			_vika("K1 klo %.1f lappu näkyy %s, pitäisi %s" % [c, lappu.visible, want])

	# K2–K3: tekstit aamulla ja iltapäivällä, vaihtoehdot päivän mukaan, paikka ja kori mainittu.
	for aamu in [true, false]:
		var seen := {}
		for d in 6:
			var t := SinikanKuisti.teksti(aamu, d)
			seen[t] = true
			if t.length() > 140:
				_vika("K2 teksti yli 140 merkkiä: %s" % t)
			if not ("Oravaj" in t or "rann" in t.to_lower()):
				_vika("K2 paikka puuttuu: %s" % t)
			if not ("kori" in t.to_lower()):
				_vika("K2 kori puuttuu: %s" % t)
		print("SL K3 %s: %d vaihtoehtoa (tila %s, päivä %d, viesti '%s')" % ["aamu" if aamu else "ilta", seen.size(),
			main.state, main.day, main._msg.text.left(60)])
		if seen.size() < 2:
			_vika("K3 vaihtoehtoja %d" % seen.size())
	for d in [1, 2]:
		if SinikanKuisti.teksti(true, d) == SinikanKuisti.teksti(false, d):
			_vika("K2 aamu = ilta päivänä %d" % d)
	for c in [[8.5, 1], [13.0, 1], [8.5, 2]]:
		main.day = c[1]
		main.clock_min = c[0] * 60.0
		await _frames(3)
		for i in 600:  # kellon siirto voi käynnistää päivän välikohtauksen (tila cutscene): odotetaan ulos
			if main.state == "ulkona":
				break
			await get_tree().process_frame
		await _frames(2)
		var lb := _label(lappu)
		var want := SinikanKuisti.teksti(c[0] < 10.0, c[1])
		print("SL K2 klo %.1f päivä %d: '%s' (day %d, avain %s, tila %s)" % [c[0], c[1], lb.text if lb != null else "<ei Label3D>",
			main.day, main._sk_lappu_key, main.state])
		if lb == null or lb.text != want:
			_vika("K2 lapun teksti ei vaihtunut (klo %.1f päivä %d)" % [c[0], c[1]])
	main.day = 1

	# K4: paperin takapinta oven lehden pinnassa (rako 0–3 mm) ja lehden rajoissa.
	main.clock_min = 8.5 * 60.0
	await _frames(3)
	var leaf_front := -(0.03 + 0.1 / 2.0)  # world.gd: oven lehti 0,1 m paksu, keskellä z - 0,03
	var la := _aabb(lappu)
	var gap := leaf_front - la.end.z
	print("SL K4 lappu x %.3f..%.3f y %.3f..%.3f z %.4f..%.4f, rako oveen %.1f mm" % [la.position.x, la.end.x,
		la.position.y, la.end.y, la.position.z, la.end.z, gap * 1000.0])
	if gap < -0.0001 or gap > 0.003:
		_vika("K4 lapun rako oveen %.1f mm" % (gap * 1000.0))
	if la.position.x < -0.475 or la.end.x > 0.475 or la.position.y < 0.40 or la.end.y > 2.50:
		_vika("K4 lappu yli oven lehden")

	# K5: pisin teksti mahtuu paperiin (set_lappu_text palauttaa false, jos ei mahdu).
	for t in SinikanKuisti.LAPPU_AAMU + SinikanKuisti.LAPPU_ILTA:
		if not SinikanKuistiMallit.set_lappu_text(lappu, t):
			_vika("K5 ei mahdu: %s" % t)
	main._sk_lappu_key = ""
	await _frames(2)

	# K15 lapun kuvat: aamu ja ilta lähikuvana pelaajan silmän korkeudelta, tyhjä ovi klo 11.
	var lc := la.get_center()
	_view(lc + Vector3(0.15, 0.15, -0.85), lc, 45.0)
	await _snap("_aamu")
	main.clock_min = 13.0 * 60.0
	await _frames(3)
	await _snap("_ilta")
	main.clock_min = 11.0 * 60.0
	await _frames(3)
	_view(Vector3(0.4, 1.6, -3.2), Vector3(0, 1.2, -0.3), 50.0)
	await _snap("_tyhja_ovi")
	cam.current = false
	main.player.activate_camera()

	# K6: kehote 2,4 m:ssä, ei 2,6 m:ssä eikä klo 11; E avaa lapun.
	var lp: Node3D = main.walker_out
	var lxz := Vector2(lc.x, lc.z)
	var hints := {}
	for c in [[8.5, 2.4], [8.5, 2.6], [11.0, 2.4]]:
		main.clock_min = c[0] * 60.0
		await _put(lxz + Vector2(0, -c[1]))
		var d := Vector2(lp.global_position.x - main.world.sinikka_kuisti.lappu.global_position.x,
			lp.global_position.z - main.world.sinikka_kuisti.lappu.global_position.z).length()
		hints["%.1f/%.1f" % [c[0], c[1]]] = main._hint.text
		print("SL K6 klo %.1f %.2f m (mitattu %.2f): vihje '%s' (tila %s, pyörä %s, päivä %d)" % [c[0], c[1], d, main._hint.text, main.state, main.player == main.bike, main.day])
	if not "lappu" in hints["8.5/2.4"]:
		_vika("K6 ei kehotetta 2,4 m:ssä")
	if "lappu" in hints["8.5/2.6"] or "lappu" in hints["11.0/2.4"]:
		_vika("K6 kehote liian kaukaa tai lapun ollessa poissa")
	main.clock_min = 8.5 * 60.0
	await _put(lxz + Vector2(0, -1.8))
	await _press()
	print("SL K6 E: luettu %s, lappu ruudulla %s, viesti '%s'" % [main.sk.lappu_luettu, main._note.visible, main._msg.text])
	if not main.sk.lappu_luettu or not main._note.visible:
		_vika("K6 E ei avannut lappua")

	# K7: kartan merkki, kerran, tallennus ja lataus.
	var mark: Vector2 = main.sinikka_map_mark()
	print("SL K7 merkki %s" % mark)
	if mark == Vector2.INF:
		_vika("K7 ei karttamerkkiä")
	main._msg.text = ""
	await _press()
	if main._msg.text != "" and "kartalle" in main._msg.text:
		_vika("K7 merkkiviesti toistui")
	main._save_game()
	var cfg := ConfigFile.new()
	cfg.load(main.SAVE_PATH)
	var sk2 := SinikanKuisti.new()
	sk2.load_from(cfg)
	if not sk2.lappu_luettu:
		_vika("K7 luettu ei tallentunut")
	main._note.visible = false
	main._paper.toggle()
	await _frames(3)
	main._paper._vcenter = mark + Vector2(30, -20)
	main._paper._vzoom = 1.2
	main._paper.queue_redraw()
	for c in main._paper.find_children("*", "Control", true, false):
		c.queue_redraw()
	await _snap("_kartta")
	main._paper.toggle()
	await _frames(3)

	# K8: korin pohja portaan päällä (rako 0–3 mm), mitat ja rajat; maasto portaan nurkissa.
	var ka := _aabb(kori)
	var kgap := ka.position.y - 0.30
	print("SL K8 kori %.3f x %.3f x %.3f m, x %.3f..%.3f z %.3f..%.3f, rako portaaseen %.1f mm" % [ka.size.x, ka.size.z,
		ka.size.y, ka.position.x, ka.end.x, ka.position.z, ka.end.z, kgap * 1000.0])
	if kgap < -0.0001 or kgap > 0.003:
		_vika("K8 korin rako portaaseen %.1f mm" % (kgap * 1000.0))
	if ka.position.x < -0.9 or ka.end.x > 0.9 or ka.position.z < -1.0 or ka.end.z > -0.1:
		_vika("K8 kori yli portaan")
	if maxf(ka.size.x, ka.size.z) < 0.28 or maxf(ka.size.x, ka.size.z) > 0.42:
		_vika("K8 korin leveys %.2f m" % maxf(ka.size.x, ka.size.z))
	var hs := []
	for c in [Vector3(-0.9, 0, -1.0), Vector3(0.9, 0, -1.0), Vector3(-0.9, 0, -0.1), Vector3(0.9, 0, -0.1)]:
		var p := _w(c)
		hs.append(Terrain.h(p.x, p.z) - root.global_position.y)
	print("SL K8 maasto portaan nurkissa talon pohjasta: %s (porras 0,30)" % [hs.map(func(v): return "%.2f" % v)])
	if hs.max() > 0.28:
		_vika("K8 porras hautautuu maastoon (%.2f m)" % hs.max())

	# K9: korin kehotteet ja jättö (klo 9: Sinikka uimassa, lappu ja kori molemmat lähellä).
	var kc := ka.get_center()
	main.clock_min = 9.0 * 60.0
	await _put(Vector2(kc.x, kc.z - 1.0))
	print("SL K9 ei tehtävää: '%s'" % main._hint.text)
	if not "Kysy" in main._hint.text:
		_vika("K9 kehote ilman tehtävää: '%s'" % main._hint.text)
	main.sinikka_task = 1
	main.bucket["mustikka"] = 1
	await _frames(3)
	print("SL K9 1 l: '%s'" % main._hint.text)
	if not "ämpärissä 1 l" in main._hint.text:
		_vika("K9 puutekehote: '%s'" % main._hint.text)
	await _put(Vector2(0, -1.5))  # oven edessä: kori lähempänä, mutta lappu oven linjassa
	print("SL K9 oven edessä: '%s'" % main._hint.text)
	if not "lappu" in main._hint.text:
		_vika("K9 oven edessä kohde ei ole lappu: '%s'" % main._hint.text)
	await _put(Vector2(kc.x, kc.z - 1.0))
	main.bucket["mustikka"] = 3
	await _frames(3)
	print("SL K9 3 l: '%s'" % main._hint.text)
	await _press()
	print("SL K9 jätetty: kori '%s', tehtävä %d, ämpäri %s" % [main.sk.kori, main.sinikka_task, main.bucket.get("mustikka", 0)])
	if main.sk.kori != "marjat" or main.sinikka_task != 0 or int(main.bucket.get("mustikka", 0)) != 1:
		_vika("K9 jättö")

	# K10: täyte näkyy korin sisällä, ei läpi.
	await _frames(2)
	var ma := _aabb(marjat)
	print("SL K10 marjat näkyy %s, x %.3f..%.3f z %.3f..%.3f y %.3f..%.3f; kori y %.3f..%.3f" % [marjat.visible,
		ma.position.x, ma.end.x, ma.position.z, ma.end.z, ma.position.y, ma.end.y, ka.position.y, ka.end.y])
	if not marjat.visible or piirakka.visible:
		_vika("K10 näkyvyys marjat %s piirakka %s" % [marjat.visible, piirakka.visible])
	if ma.position.x < ka.position.x or ma.end.x > ka.end.x or ma.position.z < ka.position.z or ma.end.z > ka.end.z \
			or ma.position.y < ka.position.y:
		_vika("K10 marjat korin ulkopuolella")
	_view(Vector3(kc.x + 0.4, 1.3, kc.z - 1.1), Vector3(kc.x, 0.45, kc.z), 40.0)
	await _snap("_kori_marjat")
	cam.current = false
	main.player.activate_camera()

	# K11: piirakka ei synny Sinikan ollessa poissa eikä pelaajan lähellä; syntyy 25 m:n päässä kotona ollessa.
	await _put(Vector2(kc.x, kc.z - 25.0))
	print("SL K11 klo 9 25 m: '%s'" % main.sk.kori)
	main.clock_min = 11.0 * 60.0
	await _put(Vector2(kc.x, kc.z - 1.2))
	print("SL K11 klo 11 lähellä: '%s'" % main.sk.kori)
	if main.sk.kori != "marjat":
		_vika("K11 piirakka syntyi liian aikaisin")
	await _put(Vector2(kc.x, kc.z - 25.0))
	print("SL K11 klo 11 25 m: '%s'" % main.sk.kori)
	if main.sk.kori != "piirakka":
		_vika("K11 piirakka ei syntynyt")
	await _frames(2)
	var pa := _aabb(piirakka)
	print("SL K11 vati x %.3f..%.3f z %.3f..%.3f y %.3f..%.3f, rako portaaseen %.1f mm" % [pa.position.x, pa.end.x,
		pa.position.z, pa.end.z, pa.position.y, pa.end.y, (pa.position.y - 0.30) * 1000.0])
	if absf(pa.position.y - 0.30) > 0.003:
		_vika("K11 vadin rako portaaseen %.1f mm" % ((pa.position.y - 0.30) * 1000.0))
	if not piirakka.visible or marjat.visible:
		_vika("K11 näkyvyys")
	_view(Vector3(0.0, 1.5, -2.2), Vector3(0, 0.3, -0.5), 45.0)
	await _snap("_kori_piirakka")
	cam.current = false
	main.player.activate_camera()
	# K12 tallennus tiloittain.
	for st in ["", "marjat", "piirakka"]:
		var keep: String = main.sk.kori
		main.sk.kori = st
		main._save_game()
		cfg = ConfigFile.new()
		cfg.load(main.SAVE_PATH)
		sk2 = SinikanKuisti.new()
		sk2.load_from(cfg)
		print("SL K12 '%s' -> '%s'" % [st, sk2.kori])
		if sk2.kori != st:
			_vika("K12 tila '%s' ei säilynyt" % st)
		main.sk.kori = keep
	# K13 a: korissa piirakka → ei apu- eikä mustikat-valintaa.
	var ids: Array = main._talk_options("sinikka").map(func(o): return o.id)
	print("SL K13 piirakka odottaa, valinnat %s" % [ids])
	if "apu" in ids or "mustikat" in ids:
		_vika("K13 uusi tehtävä piirakan odottaessa")
	# K11 nouto.
	var pc := pa.get_center()
	var food0: int = main.food.get("mustikkapiirakka", 0)
	await _put(Vector2(pc.x, pc.z - 1.0))
	print("SL K11 vati: '%s'" % main._hint.text)
	await _press()
	print("SL K11 noudettu: kori '%s', piirakoita %d -> %d, tänään %s" % [main.sk.kori, food0,
		main.food.get("mustikkapiirakka", 0), "sinikka_piirakka" in main._today])
	if main.sk.kori != "" or main.food.get("mustikkapiirakka", 0) != food0 + 1 or not "sinikka_piirakka" in main._today:
		_vika("K11 nouto")
	await _press()
	if main.food.get("mustikkapiirakka", 0) != food0 + 1:
		_vika("K11 piirakka tuli kahdesti")
	ids = main._talk_options("sinikka").map(func(o): return o.id)
	if "apu" in ids:
		_vika("K13 apu samana päivänä noudon jälkeen")
	main._today.clear()
	ids = main._talk_options("sinikka").map(func(o): return o.id)
	print("SL K13 seuraava päivä: %s" % [ids])
	if not "apu" in ids:
		_vika("K13 apu ei palannut")

	# K13 b: puheluovutus ennallaan, ja sen jälkeen kori ei ota marjoja.
	main.sinikka_task = 1
	main.bucket["mustikka"] = 2
	food0 = main.food.get("mustikkapiirakka", 0)
	main._talk_open("sinikka", main.sinikka)
	await _frames(2)
	main._talk_choose("mustikat")
	print("SL K13 puhe: tehtävä %d, ämpäri %s, piirakoita %d -> %d" % [main.sinikka_task, main.bucket.get("mustikka", 0),
		food0, main.food.get("mustikkapiirakka", 0)])
	if main.sinikka_task != 0 or main.food.get("mustikkapiirakka", 0) != food0 + 1 or main.bucket.has("mustikka"):
		_vika("K13 puheluovutus")
	main._talk_box.close()
	await _frames(6)
	main.bucket["mustikka"] = 3
	main.clock_min = 9.0 * 60.0
	await _put(Vector2(kc.x, kc.z - 1.0))
	print("SL K13 kori puheen jälkeen: '%s'" % main._hint.text)
	await _press()
	if main.sk.kori != "":
		_vika("K13 kori otti marjat ilman tehtävää")
	# K13 c: kori ensin, sitten puhe: ei mustikat-valintaa eikä apua.
	main._today.clear()
	main.sinikka_task = 1
	await _frames(3)
	await _press()
	ids = main._talk_options("sinikka").map(func(o): return o.id)
	print("SL K13 korin jälkeen valinnat %s (kori '%s')" % [ids, main.sk.kori])
	if main.sk.kori != "marjat" or "mustikat" in ids or "apu" in ids:
		_vika("K13 korin jälkeen puheessa tehtävä")

	# K15: kuvat tyhjästä korista ja kuistista kolmesta suunnasta, klo 9 (lappu ovessa, marjat korissa).
	await _put(Vector2(6.0, -8.0))
	main.sk.kori = ""
	await _frames(3)
	_view(Vector3(kc.x + 0.4, 1.3, kc.z - 1.1), Vector3(kc.x, 0.45, kc.z), 40.0)
	await _snap("_kori_tyhja")
	main.sk.kori = "marjat"
	main.clock_min = 9.0 * 60.0
	await _frames(3)
	_view(Vector3(0.3, 1.6, -4.0), Vector3(0, 0.9, -0.4), 50.0)
	await _snap("_kuisti_edesta")
	_view(Vector3(3.2, 1.4, -1.6), Vector3(0, 0.7, -0.5), 50.0)
	await _snap("_kuisti_sivusta")
	_view(Vector3(0.0, 4.0, -1.2), Vector3(0, 0.3, -0.55), 45.0)
	await _snap("_kuisti_ylhaalta")
	# Ruutuaika kuistin edessä mallien kanssa ja ilman (testipiirto: suhteellinen vertailu).
	_view(Vector3(0.3, 1.6, -4.0), Vector3(0, 0.9, -0.4), 50.0)
	var ms := []
	for vis in [true, false]:
		root.visible = vis
		await _frames(6)
		var t0 := Time.get_ticks_usec()
		for i in 12:
			await get_tree().process_frame
		ms.append((Time.get_ticks_usec() - t0) / 12000.0)
	root.visible = true
	print("SL K15 ruutu kuistilla %.1f ms (ilman kuistin malleja %.1f ms)" % [ms[0], ms[1]])
	if ms[0] > ms[1] * 1.1 + 1.0:
		_vika("K15 kuistin mallit hidastavat yli 10 %%: %.1f / %.1f ms" % [ms[0], ms[1]])
	cam.current = false
	main.player.activate_camera()
	cam.queue_free()
	if not main.wife.spotted.is_connected(main._on_wife_spotted):
		main.wife.spotted.connect(main._on_wife_spotted)
	if not main.wife.caught.is_connected(main._on_wife_caught):
		main.wife.caught.connect(main._on_wife_caught)
	print("SL valmis, vikoja %d" % vikoja)
