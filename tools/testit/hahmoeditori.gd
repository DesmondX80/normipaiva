extends Node
## --scene=hahmoeditori: hahmoeditori pelin alussa (scripts/hahmoeditori.gd). Avaa editorin päävalikon kautta, tarkistaa
## kameran rajauksen projisoimalla (pää ja koko hahmo paneelin vasemmalle jäävän alueen keskellä), kuvaa jokaisen rivin
## jokaisen vaihtoehdon (_<rivi>_<vaihtoehto>), valinnat muissa asuissa ja päähineissä (_asu_<nimi>), perumisen (Esc
## palauttaa valinnat ja päävalikon), hyväksynnän (pelaajan mallit vaihtuvat, peli jatkuu, tallennus) ja latauksen.
## Rivit "HE OK ..." tai "TESTI VIKA ...".

const Kuva := preload("res://tools/testit/kuva.gd")
const Looks := preload("res://scripts/looks.gd")
const Main := preload("res://scripts/main.gd")

var main: Main


func _tarkista(ok: bool, mita: String) -> void:
	print(("HE OK " if ok else "TESTI VIKA ") + mita)


func _odota(n: int) -> void:
	for f in n:
		await main.get_tree().process_frame


func _kuva(p: String) -> void:
	await _odota(3)  # uusi malli ja SubViewport ehtivät piirtyä
	await Kuva.piirto()
	await Kuva.piirto()
	Kuva.ruutu(main.get_viewport()).save_png(p)


## Odottaa, että kamera on asettunut rivin rajaukseen (pelin aika ei kulje valikossa: ruutuja, ei sekunteja).
func _kamera(ed: Node) -> void:
	for f in 400:
		if ed._cam.position.distance_to(ed.cam_goal(String(Looks.HAHMO[ed._row].cam))) < 0.002:
			return
		await main.get_tree().process_frame
	_tarkista(false, "kamera ei asettunut")


func run(path: String) -> void:
	var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
	Looks.custom = {}
	main.menu.open_main()
	await _odota(3)
	main.menu.open_editor(true)
	var ed: Node = main.menu.editor
	_tarkista(ed != null and main.get_tree().paused and not main._hud.visible, "editori auki, peli pysäytetty, HUD piilossa")
	await _odota(8)
	# Rajaus: kohteen keskikohta paneelin vasemmalle jäävän alueen keskellä ja korkeus FRAME:n osuus ruudusta.
	var vs: Vector2 = Vector2(ed._vp.size)
	var ui: Vector2 = ed._tex.size
	var fx: float = (ui.x - ed.PANEL_W - ed.PANEL_GAP) * 0.5 / ui.x
	for rivi in [0, 6]:
		ed._select(rivi)
		await _kamera(ed)
		var mode: String = Looks.HAHMO[rivi].cam
		var cy: float = ed.cam_goal(mode).y
		var span: float = ed.FRAME[mode][0]
		var c: Vector2 = ed._cam.unproject_position(Vector3(0, cy, 0))
		var a: Vector2 = ed._cam.unproject_position(Vector3(0, cy + span * 0.5, 0))
		var b: Vector2 = ed._cam.unproject_position(Vector3(0, cy - span * 0.5, 0))
		var osuus := (b.y - a.y) / vs.y
		_tarkista(absf(c.x / vs.x - fx) < 0.01 and absf(c.y / vs.y - 0.5) < 0.01 and absf(osuus - float(ed.FRAME[mode][1])) < 0.01,
			"rajaus %s: keskikohta %.3f, %.3f (tavoite %.3f, 0.500), korkeus %.3f ruudusta (tavoite %.2f)" % [mode, c.x / vs.x,
			c.y / vs.y, fx, osuus, float(ed.FRAME[mode][1])])
		if mode == "vartalo":
			# Hahmo mahtuu ruutuun: päälaki (lippis) ja jalkapohjat ruudun sisällä, eikä hahmo jää paneelin alle.
			var top: Vector2 = ed._cam.unproject_position(Vector3(0, 1.95, 0))
			var bot: Vector2 = ed._cam.unproject_position(Vector3(0, 0, 0))
			var oik: Vector2 = ed._cam.unproject_position(Vector3(0.55, 1.0, 0))
			_tarkista(top.y > 0 and bot.y < vs.y and oik.x / vs.x < (ui.x - ed.PANEL_W - ed.PANEL_GAP) / ui.x,
				"koko hahmo ruudussa: ylä %.0f, ala %.0f / %.0f px, oikea reuna %.3f < paneeli %.3f" % [top.y, bot.y, vs.y,
				oik.x / vs.x, (ui.x - ed.PANEL_W - ed.PANEL_GAP) / ui.x])
	# Jokainen vaihtoehto: rivi valitaan, askel oikealle, kuva. Kierros palaa oletukseen.
	for i in Looks.HAHMO.size():
		var row: Dictionary = Looks.HAHMO[i]
		ed._select(i)
		await _kamera(ed)
		for k in (row.opts as Array).size():
			var id: String = Looks.custom_opt(row.id)[0]
			_tarkista((ed._rows[i][1] as Label).text == Looks.custom_opt(row.id)[1], "rivi %s näyttää %s" % [row.id, id])
			if row.id == "tukka":
				_tarkista((ed._rows[4][1] as Label).text == ("Ei mahdu tukan päälle" if id in Looks.NO_CAP_HAIR else "Lippis")
					and String(Looks.player().cap) == ("" if id in Looks.NO_CAP_HAIR else "karhu"),
					"tukka %s: päähineen rivi ja lippis" % id)
			await _kuva(path.replace(".png", "_%s_%s.png" % [row.id, id]))
			ed._step(1)
		_tarkista(Looks.custom_opt(row.id)[0] == row.opts[0][0], "rivi %s palasi oletukseen" % row.id)
	# Käännetty hahmo (hiiren veto): selkä ja sivu.
	ed._select(6)
	Looks.custom = {"tukka": "pitka", "lippis": "ei", "puku": "lila"}
	ed._restyle()
	for kulma: float in [1.2, PI]:
		ed._yaw_to = kulma
		await _odota(40)
		await _kuva(path.replace(".png", "_kaanto_%d.png" % roundi(rad_to_deg(kulma))))
	ed._yaw_to = 0.0
	await _odota(40)
	# Valinnat muissa asuissa ja päähineissä (pää läheltä ja koko hahmo).
	var asut := [["farkut", "", {"tukka": "pitka", "hiusvari": "musta", "parta": "taysi"}],
		["tyovaatteet", "", {"tukka": "pitka", "hiusvari": "punainen", "parta": "viikset", "maha": "hoikka"}],
		["hiihtohaalari", "", {"tukka": "letti", "hiusvari": "ruskea", "iho": "paivettynyt", "maha": "jatti"}],
		["nahkaliivi", "", {"tukka": "kalju", "parta": "taysi", "hiusvari": "harmaa", "iho": "ruskea", "maha": "pieni"}],
		["tuulipuku", "stetson", {"tukka": "pitka", "hiusvari": "musta", "puku": "viini"}],
		["tuulipuku", "koppa", {"tukka": "letti", "puku": "vihrea", "lasit": "valkoiset"}],
		["tyovaatteet", "", {"tukka": "siili", "parta": "silea", "iho": "tumma"}]]
	for a: Array in asut:
		Looks.outfit = a[0]
		Looks.hat = a[1]
		Looks.custom = a[2]
		ed._restyle()
		for rivi in [0, 6]:
			ed._select(rivi)
			await _kamera(ed)
			await _kuva(path.replace(".png", "_asu_%s%s_%s_%s.png" % [a[0], a[1], a[2].tukka, Looks.HAHMO[rivi].cam]))
	Looks.outfit = "tuulipuku"
	Looks.hat = ""
	# Arvonta: jokaisella rivillä on kelvollinen valinta.
	ed._randomize()
	var kelpaa := true
	for row: Dictionary in Looks.HAHMO:
		kelpaa = kelpaa and Looks.custom.has(row.id) and Looks.custom_opt(row.id)[0] == Looks.custom[row.id]
	_tarkista(kelpaa, "arvonta: %s" % [Looks.custom])
	# Peruminen: valinnat palaavat ja päävalikko aukeaa.
	ed._finish(false)
	await _odota(3)
	_tarkista(main.menu.editor == null and main.menu._mode == "main" and Looks.custom == asut[-1][2],
		"peruminen: päävalikko, valinnat ennallaan (%s)" % [Looks.custom])
	# Hyväksyntä: mallit vaihtuvat, peli jatkuu ja valinnat tallentuvat.
	Looks.custom = {}
	main.menu.open_editor(false)
	ed = main.menu.editor
	await _odota(4)
	var valinta := {"tukka": "siili", "hiusvari": "punainen", "parta": "taysi", "lasit": "ei", "lippis": "ei", "iho": "paivettynyt",
		"maha": "jatti", "puku": "viini"}
	for i in Looks.HAHMO.size():
		ed._select(i)
		for k in 8:
			if Looks.custom_opt(Looks.HAHMO[i].id)[0] == valinta[Looks.HAHMO[i].id]:
				break
			ed._step(1)
	await _kuva(path.replace(".png", "_valmis.png"))
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	ed._input(esc)
	_tarkista(main.menu.editor != null, "uuden pelin alussa Esc ei sulje editoria")
	ed._finish(true)
	await _odota(4)
	var mallit := main.get_tree().root.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n.has_meta("player_body"))
	var oikein := 0
	for n in mallit:
		if is_equal_approx(float(n.body_shape.belly), 1.0) and (n.body_mat.get_shader_parameter("shirt") as Color).is_equal_approx(Color(0.5, 0.07, 0.14)):
			oikein += 1
	_tarkista(main.menu.editor == null and not main.get_tree().paused and main._hud.visible, "hyväksyntä: peli käynnissä, HUD näkyy")
	_tarkista(Looks.custom == valinta and oikein == mallit.size() and oikein > 0, "pelaajan mallit vaihtuivat: %d / %d" % [oikein, mallit.size()])
	var cfg := ConfigFile.new()
	cfg.load(Main.SAVE_PATH)
	_tarkista(cfg.get_value("pelaaja", "hahmo", {}) == valinta, "tallennus: %s" % [cfg.get_value("pelaaja", "hahmo", {})])
	await _odota(20)
	await _kuva(path.replace(".png", "_peli.png"))
	# Lataus: vanha tallennus ilman hahmoa palauttaa oletuksen, uusi tuo valinnat.
	main._set_look({})
	_tarkista(Looks.custom.is_empty() and Looks.player().hair == "Hair_SimpleParted" and is_equal_approx(Looks.player().belly, 0.75),
		"oletus = sama ulkonäkö kuin ennen editoria")
	main._load_game()
	_tarkista(Looks.custom == valinta, "lataus toi valinnat")
	main._set_look({})
	if saved.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.SAVE_PATH))
	else:
		FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
