extends Node
## Huumekaupan riskit (scripts/rikos/, main.gd _rikos_*): ajo tools/testit/aja.sh scene riskit --riski=<nimi> [--arg=...].
## Odotukset välianimaation omilla ajastimilla, joten tahti pysyy. Hitaalla koneella (xvfb, ~1 ruutu/s) ruudun delta
## rajautuu ja WASTED-kierron kamera jää motkotuksen alkuun; --kiintea näyttää oikean kuvan, mutta ei mahdu aikarajaan.
## perus: osa 0:n koukut testiosalla (rikos_koe_osa.gd): puhe, tapahtumat (luukkuosto, myynti, otto), luukun vihje,
##   tallennus edestakaisin, uusi päivä, päiväkirjan data, tappelun loppu sekä PIDÄTETTY (Saloinen) ja ELVYTETTY (Vaala).
## paivakirja: Riskit-sivu 1280×720 ja välilehtien mitat (7 välilehteä mahtuu kirjaan).
## Muut nimet: osan oma testi(arg) (rikos/<nimi>.gd). Viat "TESTI VIKA" -riveinä. main.gd palauttaa tallennuksen.

const KoeOsa := preload("res://tools/testit/rikos_koe_osa.gd")

var main: Node3D
var vikoja := 0


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + t)


func _shot_path(suffix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			return a.substr(7).replace(".png", suffix + ".png")
	return "user://riskit" + suffix + ".png"


## Häiriöt pois heti alussa ja joka odotuksessa (uusi päivä luo uuden Päivin auton): kiinnijäänti ja kello paikallaan.
func _eristys() -> void:
	if main.wife != null:
		if main.wife.spotted.is_connected(main._on_wife_spotted):
			main.wife.spotted.disconnect(main._on_wife_spotted)
		if main.wife.caught.is_connected(main._on_wife_caught):
			main.wife.caught.disconnect(main._on_wife_caught)
	if main.state != "cutscene":
		main.clock_min = 12.0 * 60.0


func _frames(n := 4) -> void:
	for i in n:
		_eristys()
		await get_tree().process_frame


func _snap(suffix: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_path(suffix))
	print("RISKIT kuva " + _shot_path(suffix))


func run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # päiväkirja pysäyttää puun
	_eristys()
	var riski := "perus"
	var arg := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--riski="):
			riski = a.substr(8)
		elif a.begins_with("--arg="):
			arg = a.substr(6)
	await _frames(10)
	print("RISKIT osat: ", main.rikos.map(func(r: Object) -> String: return r.nimi))
	match riski:
		"perus":
			await _perus()
		"paivakirja":
			await _paivakirja()
		_:
			var osa: Object = main.rikos_osa(riski)
			if osa == null:
				_vika("osaa %s ei ole (scripts/rikos/%s.gd)" % [riski, riski])
			else:
				await osa.testi(arg)
	print("RISKIT %s valmis, %d vikaa" % [riski, vikoja])


func _perus() -> void:
	var koe: Object = KoeOsa.new()
	main._rikos_add(koe, "koe")
	if main.rikos_osa("koe") != koe:
		_vika("rikos_osa(koe) ei löydä lisättyä osaa")
	# Puhe: tervehdys, valinnat (oma rivi, ei "Mitä kuuluu?") ja valinnan ohjaus osalle.
	if main._talk_hello("kaukalo_poika") != "KOE terve":
		_vika("_talk_hello ei kysy osalta: %s" % main._talk_hello("kaukalo_poika"))
	var ids: Array = main._talk_options("kaukalo_poika").map(func(o: Dictionary) -> String: return o.id)
	print("RISKIT valinnat ", ids)
	if not "koe_valinta" in ids or "juttu" in ids or not "lopeta" in ids:
		_vika("_talk_options: %s" % [ids])
	if main._talk_options("arto").map(func(o: Dictionary) -> String: return o.id).has("koe_valinta"):
		_vika("osan valinta näkyy väärälle puhujalle")
	main._talk_who = "kaukalo_poika"
	main._talk_choose("koe_valinta")
	if not koe.oli("choose"):
		_vika("_talk_choose ei ohjaa osalle")
	main._talk_who = ""
	# Tapahtumat.
	main.money = 500.0
	main.laake = {"opiaatti": 3}
	main._hs_ostettu()
	main._teini_myy("opiaatti", 0.999)
	main._take_laake("opiaatti")
	for ev in ["luukkuosto", "myynti", "otto"]:
		if not koe.oli(ev):
			_vika("tapahtuma %s ei tullut osalle" % ev)
	for k in koe.kutsut:
		if k[0] in ["myynti", "otto"]:
			print("RISKIT tapahtuma %s %s" % [k[0], k[1]])
			if k[0] == "myynti" and (k[1].get("paikka") != "saloinen" or k[1].get("key") != "opiaatti"):
				_vika("myynti-tapahtuman data %s" % [k[1]])
			if k[0] == "otto" and absf(float(k[1].get("pot", 0.0)) - 1.0) > 0.001:
				_vika("otto-tapahtuman data %s" % [k[1]])
	main._talk_box.close()
	await _frames(4)
	if not koe.oli("tick"):
		_vika("tick ei kutsuttu Saloisissa")
	# Luukun vihje: pelaaja koputuspisteessä, osa pitää luukun kiinni.
	var ap: Dictionary = main.world.apteekki_s
	if ap.is_empty():
		_vika("apteekki_s puuttuu")
	else:
		koe.kiinni = true
		main._place_on_foot(ap.knock + Vector3(0, 0.3, 0))  # jalan (pyörän selästä ei koputeta)
		await _frames(2)
		print("RISKIT koputuspiste %s, pelaaja %s, pyörällä %s" % [ap.knock, main.player.global_position, main.player == main.bike])
		main._hint.text = ""
		main._hs_door_logic(false)
		print("RISKIT luukku kiinni -> vihje '%s'" % main._hint.text)
		if main._hint.text != "KOE luukku kiinni":
			_vika("luukun vihje: '%s'" % main._hint.text)
		koe.kiinni = false
		main._hint.text = ""
		main._hs_door_logic(false)
		print("RISKIT luukku auki -> vihje '%s'" % main._hint.text)
		if not "Koputa" in main._hint.text:
			_vika("luukku ei aukea, kun osa ei pidä sitä kiinni: '%s'" % main._hint.text)
		main._hint.text = ""
	# Tallennus edestakaisin.
	koe.arvo = 42
	main._save_game()
	koe.arvo = 0
	main._load_game()
	print("RISKIT tallennus 42 -> %d" % koe.arvo)
	if koe.arvo != 42:
		_vika("tallennus/lataus: %d" % koe.arvo)
	# Päiväkirjan data.
	var jd: Dictionary = main.journal_data()
	var rs: Array = jd.get("riskit", [])
	if rs.is_empty() or rs[-1].get("otsikko") != "Koe":
		_vika("journal_data riskit: %s" % [rs])
	# Tappelun loppu: osa antaa viestin ja _rikos_fight nollautuu.
	main._rikos_fight = koe
	main._hs_fight_end(true, "")
	if not koe.oli("fight_end") or main._rikos_fight != null:
		_vika("fight_end ei kutsuttu tai _rikos_fight jäi")
	# PIDÄTETTY Saloisissa: menetykset ja otsikko, sitten uusi päivä ja aamu-koukku.
	main.laake = {"opiaatti": 2}
	main.money = 300.0
	main.maine = 50.0
	main._rikos_loppu("pidatys", "Testi: valeostaja oli poliisi.")
	print("RISKIT pidätys: laake %s rahat %.0f maine %.0f tila %s" % [main.laake, main.money, main.maine, main.state])
	if not main.laake.is_empty() or main.money != 150.0 or main.maine != 40.0 or main.state != "cutscene":
		_vika("pidätyksen menetykset")
	await _title_shot("_pidatetty", "PIDÄTETTY")
	await _paivi_shot("_pidatys_paivi")
	await _until_free()
	if not koe.oli("aamu"):
		_vika("aamu ei kutsuttu uutena päivänä")
	# ELVYTETTY Vaalassa: puhelin soi (wasted_phone).
	main._start_mopo()
	await _frames(30)
	main._rikos_loppu("yliannos", "Testi: olo meni liian kovaksi.")
	await _title_shot("_elvytetty_vaala", "ELVYTETTY")
	await _paivi_shot("_elvytetty_puhelin")
	await _until_free()


## Otsikko näkyy: odotetaan cutscenen otsikkoa ja kuvataan.
func _title_shot(suffix: String, want: String) -> void:
	var f := 0
	while main.cutscene._title.text == "" and f < 600:
		f += 1
		await get_tree().process_frame
	var seen: String = main.cutscene._title.text  # otsikko näkyy vain hetken: luetaan ja kuvataan heti
	print("RISKIT otsikko '%s' %d ruutua" % [seen, f])
	if seen != want:
		_vika("otsikko '%s', odotettiin %s" % [seen, want])
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_path(suffix))
	print("RISKIT kuva " + _shot_path(suffix))


## Motkotus: odotetaan, kunnes otsikko on pois (pihakohtaus), ja kuvataan puhekupla.
func _paivi_shot(suffix: String) -> void:
	var f := 0
	while main.cutscene._title.text != "" and f < 900:
		f += 1
		await get_tree().process_frame
	for n in 3:  # repliikit: välianimaation omin ajastimin (cutscene.gd _wait), joten --kiintea pitää tahdin
		await get_tree().create_timer(2.5 if n == 0 else 2.6, true, false, true).timeout
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot_path(suffix + str(n)))
		var vc := get_viewport().get_camera_3d()
		print("RISKIT kuva %s kamera %s %s (välianimaation: %s), koti %s" % [_shot_path(suffix + str(n)), vc.name if vc else "-",
			vc.global_position if vc else Vector3.ZERO, vc == main.cutscene._cam, main.home_zone])


func _until_free() -> void:
	var f := 0
	while main.state == "cutscene" and f < 4000:
		f += 1
		await get_tree().process_frame
	await _frames(10)
	print("RISKIT cutscene ohi, tila %s, päivä %d" % [main.state, main.day])


func _paivakirja() -> void:
	var koe: Object = KoeOsa.new()
	main._rikos_add(koe, "koe")
	main._journal.open_at("riskit")
	await _frames(10)
	var j: Control = main._journal
	var book: Rect2 = j._book
	print("RISKIT kirja %s, välilehtiä %d" % [book, j.TABS.size()])
	for i in j.TABS.size():
		var r: Rect2 = j._tab_rect(i)
		var tw: float = ThemeDB.fallback_font.get_string_size(str(j.TABS[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		print("RISKIT välilehti %d %s y %.1f–%.1f korkeus %.1f teksti %.1f px" % [i, j.TABS[i][1], r.position.y, r.end.y, r.size.y, tw])
		if r.end.y > book.end.y:
			_vika("välilehti %s yli kirjan (%.1f > %.1f)" % [j.TABS[i][1], r.end.y, book.end.y])
		if tw > r.size.y - 4.0:
			_vika("välilehden %s teksti %.1f px ei mahdu %.1f px:iin" % [j.TABS[i][1], tw, r.size.y])
	await _snap("_riskit")
	main.rikos.erase(koe)
	j._data = main.journal_data()
	j.queue_redraw()
	await _snap("_riskit_tyhja")
	main._journal.toggle()
	await _frames(4)
