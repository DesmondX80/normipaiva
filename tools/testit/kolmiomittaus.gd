extends Node
## Kolmiomittaus (#255, scripts/kolmiomittaus.gd): logiikka, hahmot, Sytkäri, paperikartan ympyrät, ovet, erikoissääntöinen
## Rasvanappi, aamu ja maito. main.gd palauttaa tallennuksen.
## Ajo: tools/testit/aja.sh scene kolmiomittaus   (Saloinen: Joni, Esa ja Minttu)
##      tools/testit/aja.sh scene kolmiomittaus_vaala   (Vaala: Hevari-Tero, Siviikki-Timo, Siviikki ja Katja)
## Kuvat: _kaverit, _hahmo_<nimi>_edesta/_sivulta/_takaa, _rinkka_* (rajattu), _sytkari_mätsi, _sytkari_matka,
## _kartta, _vaara_ovi, _ovi_ilman_lahjaa, _ovi_lahjat, _rasva_esittely, _rasva_pimea, _rasva_puhelu, _rasva_loppu, _aamu.

const Kolmio := preload("res://scripts/kolmiomittaus.gd")
const Looks := preload("res://scripts/looks.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")

var main: Node3D
var site := "saloinen"
var vikoja := 0


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + t)


func _shot_path(suffix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			return a.substr(7).replace(".png", suffix + ".png")
	return "user://kolmio_%s%s.png" % [site, suffix]


func _frames(n := 4) -> void:
	for i in n:
		await get_tree().process_frame


func _snap(suffix: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(_shot_path(suffix))


func _press(action := "interact") -> void:
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func run() -> void:
	main.kolmio = Kolmio.new()  # puhdas lähtö: aiemman ajon tallennus ei saa jättää mittausta kesken
	_logic()
	if site == "vaala":
		await _run_vaala()
	else:
		await _run_saloinen()
	print("KOLMIO %s valmis, %d vikaa" % [site, vikoja])


## Pyöristys ja ympyrät: oikea etäisyys on aina vyöhykkeellä, ja kohde on kaikkien ympyröiden leikkauksessa.
func _logic() -> void:
	for d in [5.0, 37.0, 119.0, 121.0, 260.0, 499.0, 501.0, 1260.0]:
		var m := Kolmio.shown(d)
		print("KOLMIO pyöristys %.0f m -> %s (porras %.0f)" % [d, Kolmio.dist_text(m), Kolmio.step_for(d)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 255
	var target := Vector2(10, 20)
	var k := Kolmio.new()
	k.start("saloinen", Vector2(-200, 50), target, "Joni")
	for i in 300:
		var at := target + Vector2(rng.randf_range(-900, 900), rng.randf_range(-900, 900))
		var r := Kolmio.ring(at, target, "x")
		var d := at.distance_to(target)
		if d < float(r.lo) - 0.001 or d > float(r.hi) + 0.001:
			_vika("pyöristys: %.1f m ei ole vyöhykkeellä %.1f..%.1f" % [d, r.lo, r.hi])
			break
		if i < 4:
			k.measure("saloinen", at, target, "x")
	if not k.inside("saloinen", target):
		_vika("kohde ei ole ympyröiden leikkauksessa")
	if k.can_measure("saloinen", Vector2(-200, 60)):
		_vika("mittaus sallittu %d m:n päästä edellisestä" % 10)
	# Tallennus ja lataus säilyttävät ympyrät ja vaiheen.
	var cfg := ConfigFile.new()
	k.maito_day = 7
	k.save_to(cfg)
	var k2 := Kolmio.new()
	k2.load_from(cfg)
	if k2.stage("saloinen") != "mittaus" or (k2.st("saloinen").rings as Array).size() != (k.st("saloinen").rings as Array).size() \
			or k2.maito_day != 7:
		_vika("tallennus ei säilynyt: %s" % k2.st("saloinen"))


func _cam_at(pos: Vector3, look: Vector3) -> Camera3D:
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.current = true
	cam.look_at_from_position(pos, look)
	return cam


## Hahmo kolmesta suunnasta (edestä, sivulta, takaa) ja rajattuna pään tai rinkan korkeudelta.
func _model_shots(node: Node3D, nimi: String, focus_y := 1.5, dist := 1.6) -> void:
	var c := node.global_position
	var fwd := -node.global_transform.basis.z
	var side := node.global_transform.basis.x
	for v in [["_edesta", fwd], ["_sivulta", side], ["_takaa", -fwd]]:
		var cam := _cam_at(c + (v[1] as Vector3) * dist + Vector3(0, focus_y, 0), c + Vector3(0, focus_y - 0.1, 0))
		await _snap("_hahmo_%s%s" % [nimi, v[0]])
		cam.queue_free()


## Sytkäri kiinni E:llä: odota, että sen voi sulkea (match 2,8 s, matka 0,8 s pelin ajassa), ja paina, kunnes se sulkeutuu.
func _close_phone() -> void:
	for i in 600:
		var ui = main._kolmio_ui
		if ui == null:
			return
		if "_t" in ui and ui._t > (3.0 if ui.mode == "match" else 1.0):
			await _press()
		else:
			await get_tree().process_frame
	_vika("Sytkäri ei sulkeutunut E:llä")


func _wait_ui(max_frames := 120) -> void:
	for i in max_frames:
		if main._kolmio_ui == null:
			return
		await get_tree().process_frame


## Kohtausta eteenpäin E:llä, kunnes se sulkeutuu (tai raja tulee vastaan).
func _advance_ui(shot_at := -1, suffix := "") -> void:
	for i in 14:
		if main._kolmio_ui == null:
			return
		if "_line" in main._kolmio_ui:
			print("KOLMIO kohtaus %s rivi %d/%d, tila %s" % [main._kolmio_ui.mode, main._kolmio_ui._line, main._kolmio_ui.lines.size(), main.state])
		await _frames(30)
		if i == shot_at:
			await _snap(suffix)
		await _press()


func _run_saloinen() -> void:
	var w: Node3D = main.walker_out
	if main.player != w:
		main._toggle_mount()
	main._msg.text = ""
	main._note.visible = false
	var joni: Node3D = main._kolmio_joni
	if joni == null:
		_vika("Jonia ei luotu")
		return
	var doors: Array = main._kolmio_door_list("saloinen")
	print("KOLMIO ovet %s" % [doors])
	if doors.size() != 4:
		_vika("Saloisissa %d ovea (pitäisi 4: Minttu ja kolme väärää)" % doors.size())
	var t: Vector2 = main._kolmio_target("saloinen")
	var jp := Vector2(joni.global_position.x, joni.global_position.z)
	print("KOLMIO Mintun ovi %s, kaupalta %.0f m, kirkolta %.0f m" % [t, jp.distance_to(t), M.w2(M.KIRKKO).distance_to(t)])
	# Kaverit kaupan pihassa, hahmot ja rinkka.
	var cam := _cam_at(joni.global_position + Vector3(4.5, 2.2, 5.5), joni.global_position + Vector3(0.8, 1.0, 0))
	await _snap("_kaverit")
	cam.queue_free()
	main._kolmio_esa.visible = false  # toinen kaveri ei saa peittää kuvattavaa
	await _model_shots(joni, "joni")
	main._kolmio_esa.visible = true
	joni.visible = false
	await _model_shots(main._kolmio_esa, "esa")
	joni.visible = true
	var back: Vector3 = joni.global_transform.basis.z
	cam = _cam_at(joni.global_position + back * 0.8 + Vector3(0, 1.35, 0), joni.global_position + Vector3(0, 1.25, 0))
	await _snap("_rinkka_takaa")
	cam.queue_free()
	cam = _cam_at(joni.global_position + joni.global_transform.basis.x * 0.8 + back * 0.25 + Vector3(0, 1.35, 0),
		joni.global_position + back * 0.2 + Vector3(0, 1.25, 0))
	await _snap("_rinkka_sivulta")
	cam.queue_free()
	await _women_shots()
	main.walker_out.activate_camera()
	# Mätsi Jonilta ja Esalta: puhelin, ensimmäinen ympyrä ja Esan etämittaus.
	w.global_position = joni.global_position + joni.global_transform.basis.z * -1.5 + Vector3(0, 0.3, 0)
	await _frames(10)
	print("KOLMIO kaverien vihje '%s', tila %s, puhe %s, valikko %s, Jonille %.1f m" % [main._hint.text, main.state,
		main._talk_box.is_open(), main._item_menu.is_open(), joni.distance_to_player()])
	main._talk_open("kolmio_saloinen", joni)
	await _frames(5)
	main._talk_choose("kolmio_aloita")
	await _frames(150)
	await _snap("_sytkari_matsi")
	if main.kolmio.stage("saloinen") != "mittaus":
		_vika("mittaus ei alkanut")
	await _close_phone()
	print("KOLMIO mätsin jälkeen: tila %s, ui %s, vaihe %s, remote_t %.2f, Esa näkyy %s" % [main.state, main._kolmio_ui,
		main.kolmio.stage("saloinen"), main.kolmio.st("saloinen").remote_t, main._kolmio_esa.visible])
	main.kolmio.st("saloinen").remote_t = 0.05
	await _frames(20)
	print("KOLMIO 20 ruudun jälkeen: tila %s, remote_t %.2f, Esa näkyy %s, kuva %d" % [main.state, main.kolmio.st("saloinen").remote_t,
		main._kolmio_esa.visible, Engine.get_process_frames()])
	var rings: Array = main.kolmio.st("saloinen").rings
	print("KOLMIO ympyrät Esan jälkeen %d: %s" % [rings.size(), rings])
	if rings.size() != 2:
		_vika("Esan etämittaus ei tullut (%d ympyrää)" % rings.size())
	# Kolmas mittaus pelaajalta itäpuolelta.
	var me := t + Vector2(180, -60)
	w.global_position = Vector3(me.x, Terrain.h(me.x, me.y) + 0.4, me.y)
	await _frames(10)
	print("KOLMIO mittausvihje '%s'" % main._hint.text)
	main._kolmio_measure("saloinen", me)
	await _frames(70)
	await _snap("_sytkari_matka")
	await _close_phone()
	if not main.kolmio.inside("saloinen", t):
		_vika("Mintun ovi ei ole leikkauksessa")
	var wrong_in := 0
	for dd: Array in doors:
		if dd[1] >= 0 and main.kolmio.inside("saloinen", dd[0]):
			wrong_in += 1
	print("KOLMIO kolmen ympyrän jälkeen leikkauksessa myös %d väärää ovea" % wrong_in)
	# Paperikartta: ympyrät ja leikkausalue.
	main._paper.toggle()
	await _frames(10)
	main._paper._vcenter = t
	main._paper._vzoom = 0.9
	await _snap("_kartta")
	main._paper._vzoom = 0.35
	await _snap("_kartta_kaukaa")
	main._paper.toggle()
	await _frames(5)
	await _doors_and_evening("saloinen")


## Naiset ja kaverit valaistulla lavalla korkealla maiseman yllä (Looks.make): edestä, sivulta ja takaa.
func _women_shots() -> void:
	var stage := Node3D.new()
	main.add_child(stage)
	stage.global_position = main.walker_out.global_position + Vector3(0, 120, 0)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	stage.add_child(light)
	var looks := {"minttu": Looks.MINTTU, "katja": Looks.KATJA, "tero": Looks.HEVARI_TERO, "timo": Looks.SIVIIKKI_TIMO}
	for nimi in looks:
		var c: Node3D = Looks.make(stage, looks[nimi])
		c.play("Idle")
		await _frames(6)
		await _model_shots(c, nimi, 1.45, 2.0)
		var head: Vector3 = c.global_position + Vector3(0, 1.6, 0)
		var cam := _cam_at(head + (-c.global_transform.basis.z) * 0.55 + Vector3(0, 0.05, 0), head)
		await _snap("_hahmo_%s_kasvot" % nimi)
		cam.queue_free()
		cam = _cam_at(head + c.global_transform.basis.z * 0.6, head - Vector3(0, 0.1, 0))
		await _snap("_hahmo_%s_hiukset_takaa" % nimi)
		cam.queue_free()
		c.queue_free()
	stage.queue_free()


## Väärä ovi, oikea ovi ilman lahjaa, lahja tiskiltä, oikea ovi lahjoineen, Rasvanappi, aamu ja maito.
func _doors_and_evening(s: String) -> void:
	var doors: Array = main._kolmio_door_list(s)
	main._kolmio_knock(s, 0)
	await _frames(40)
	await _press()
	await _frames(40)
	await _snap("_vaara_ovi")
	await _advance_ui()
	await _wait_ui()
	if main._kolmio_ui != null:
		_vika("väärän oven kohtaus ei sulkeutunut")
	main._kolmio_knock(s, -1)
	await _advance_ui(3, "_ovi_ilman_lahjaa")
	await _wait_ui()
	if main._rasva_game != null:
		_vika("ovi aukesi ilman pelaajan lahjaa")
	print("KOLMIO lahjatta viesti '%s'" % main._msg.text)
	# Lahja kaupan tiskiltä: valinta näkyy kauppiaalla ja maksaa.
	var o: Array = []
	main._kolmio_gift_option(o)
	print("KOLMIO kauppiaan valinta %s" % [o])
	if o.is_empty():
		_vika("kauppias ei tarjoa lahjaa")
	main._talk_who = "kauppias"
	main.money = maxf(main.money, 20.0)
	main.interior.money = main.money
	var money0: float = main.money
	main._kolmio_choose("kolmio_lahja")
	main._talk_who = ""
	if not main.kolmio.st(s).gift or absf(money0 - main.money - Kolmio.GIFT_PRICE) > 0.01:
		_vika("lahjan osto ei toiminut (rahaa %.2f -> %.2f)" % [money0, main.money])
	var day0: int = main.day
	main._kolmio_knock(s, -1)
	await _advance_ui(4, "_ovi_lahjat")
	for i in 60:
		if main._rasva_game != null:
			break
		await get_tree().process_frame
	var g: Node = main._rasva_game
	if g == null:
		_vika("Rasvanappi ei alkanut oikealla ovella")
		return
	await _frames(40)
	await _snap("_rasva_esittely")
	g._lights_out()
	await _frames(120)
	await _snap("_rasva_pimea")
	g._game_t = 46.0
	await _frames(20)
	print("KOLMIO puhelun tila '%s'" % g._mode)
	if g._mode != "puhelu":
		_vika("Päivin puhelu ei tullut")
	await _frames(60)
	await _snap("_rasva_puhelu")
	for i in 4:
		await _press()
		await _frames(10)
	g._end()
	await _frames(60)
	await _snap("_rasva_loppu")
	g._done(true)
	await _frames(60)
	await _snap("_aamu")
	await _advance_ui()
	await _frames(30)
	print("KOLMIO aamun jälkeen päivä %d -> %d, vaihe %s, maito %d, loppu %s" % [day0, main.day, main.kolmio.stage(s),
		main.kolmio.maito_day, main.endings.counts])
	if main.day != day0 + 1:
		_vika("päivä ei vaihtunut aamuun")
	if main.kolmio.stage(s) != "valmis" or main.kolmio.maito_day != main.day:
		_vika("loppu ei kirjautunut (vaihe %s, maito %d)" % [main.kolmio.stage(s), main.kolmio.maito_day])
	if not main.endings.counts.has(Kolmio.SITES[s].ending):
		_vika("onnellinen loppu puuttuu")
	# Maito: kotiin ilman maitoa = motkotus.
	main.paivi_bag.erase("maito")
	main._kolmio_maito_home()
	await _frames(5)
	print("KOLMIO maidoton kotiinpaluu: '%s'" % main._msg.text)


func _run_vaala() -> void:
	if main.player != main.walker_out:
		main._toggle_mount()
	main._msg.text = ""
	main._note.visible = false
	main.mokki.ensure_built()
	main._start_mopo()
	var mt: Node3D = main.mopo_trip
	for car in mt._cars:
		car.process_mode = Node.PROCESS_MODE_DISABLED
		car.visible = false
	main._kolmio_vaala_setup()
	var vl: Node3D = mt.vaala
	var doors: Array = main._kolmio_door_list("vaala")
	print("KOLMIO Vaala talot %d, ovet %s, kaverit %d" % [vl.house_doors.size(), doors, main._kolmio_vaala_npcs.size()])
	if doors.size() < 3 or main._kolmio_vaala_npcs.size() != 2:
		_vika("Vaalan ovet tai kaverit puuttuvat")
		return
	var t: Vector2 = main._kolmio_target("vaala")
	var st: Vector2 = main._kolmio_vaala_spots.start
	print("KOLMIO Katjan ovi %s, asemalta %.0f m, Veturitallilta %.0f m" % [t, st.distance_to(t),
		(main._kolmio_vaala_spots.remote as Vector2).distance_to(t)])
	var tero: Node3D = main._kolmio_vaala_npcs[0]
	var cam := _cam_at(tero.global_position + Vector3(6, 2.5, 7), tero.global_position + Vector3(1.5, 0.9, 0))
	await _snap("_kaverit")
	cam.queue_free()
	var timo: Node3D = main._kolmio_vaala_npcs[1]
	timo.visible = false
	await _model_shots(tero, "tero")
	timo.visible = true
	tero.visible = false
	await _model_shots(timo, "timo")
	tero.visible = true
	# Kaverit ja Civic ylhäältä: kukaan ei seiso auton sisällä.
	cam = _cam_at(tero.global_position + Vector3(0.5, 9.0, 0.6), tero.global_position + Vector3(1.0, 0, 0))
	await _snap("_kaverit_ylhaalta")
	cam.queue_free()
	# Juttelu ovella (vaala.gd doors) ja mätsi.
	if mt.on_foot == null:
		main._mopo_dismount()
	var kd: Dictionary = vl.doors.filter(func(d: Dictionary) -> bool: return d.id == "kolmio_kaverit")[0]
	mt.on_foot.global_position = mt.to_global(kd.pos) + Vector3(0, 0.5, 0)
	mt.on_foot.activate_camera()
	await _frames(15)
	print("KOLMIO Vaalan kaverien vihje '%s'" % mt.hint)
	main._on_vaala_door("kolmio_kaverit")
	await _frames(5)
	main._talk_choose("kolmio_aloita")
	await _frames(150)
	await _snap("_sytkari_matsi")
	await _close_phone()
	main.kolmio.st("vaala").remote_t = 0.05
	await _frames(20)
	var me := t + Vector2(-150, 90)
	main._kolmio_measure("vaala", me)
	await _frames(70)
	await _snap("_sytkari_matka")
	await _close_phone()
	print("KOLMIO Vaalan ympyrät %s" % [main.kolmio.st("vaala").rings])
	if not main.kolmio.inside("vaala", t):
		_vika("Katjan ovi ei ole leikkauksessa")
	main._paper.toggle()
	await _frames(10)
	main._paper._vcenter = t
	main._paper._vzoom = 1.5
	await _snap("_kartta")
	main._paper.toggle()
	await _frames(5)
	await _doors_and_evening("vaala")
