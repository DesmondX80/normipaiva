extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "legendat": lavastetut legendaariset hetket, jotka eivät kuulu maatilalle
## (maatilan hetket: kaisua.gd *_sato, *_talkoot, *_kylvot). aja() palauttaa 0 = kohtaus ei kuulu ryhmään.
## Kohtaukset ottavat pelaajan tallennuksen talteen alussa ja palauttavat sen lopussa.
##
## mokki_paapeli: Pekan kyyti tarinan jälkeen (story valmis) -> saapuminen mökin pihaan (cutscene.gd paapeli_saapuu):
##   kuvat kyydistä, kaahauksesta, Santusta, autosta noususta ja noususta mökin ylle; hetki kirjataan vasta perillä
##   (päiväkirjarivi, ei vanhaa ilmoitusta) ja toinen kyyti ei toista saapumista, vaan Pekka muistelee.
## pentti_eka: Pentin ensimmäinen kyyti (rikos/pentti.gd _kyyti): keinunta, liukuovi aukeaa, mummo pudottaa kassin,
##   Pentti ovelta ja nousu parkkipaikan ylle; hetki kirjataan aamulla (päiväkirjarivi), toinen kyyti ilman huipennusta.
## mokki_savusauna_eka: korjatun savusaunan ensimmäiset löylyt (sauna_relax first) ja laiturilta Likaseen
##   (savusauna_jarvi): kuvat löylystä, juoksusta, hypystä, uijista ja noususta; toiset löylyt eivät toista kohtausta.

const Main := preload("res://scripts/main.gd")
const Kuva := preload("res://tools/testit/kuva.gd")

const KOHTAUKSET := ["mokki_paapeli", "mokki_savusauna_eka", "pentti_eka"]

var main: Main
var _viat := 0


func aja(scene: String, path: String, _nohud: bool) -> int:
	if not scene in KOHTAUKSET:
		return 0
	var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
	match scene:
		"mokki_paapeli":
			await _paapeli(path)
		"mokki_savusauna_eka":
			await _savusauna(path)
		"pentti_eka":
			await _pentti(path)
	FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
	return 1


func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame


func _shot(path: String, name: String) -> void:
	await Kuva.piirto()
	await Kuva.piirto()
	var p := path.replace(".png", "_%s.png" % name)
	Kuva.ruutu(main.get_viewport()).save_png(p)
	print("LEGENDA kuva ", p)


func _check(ok: bool, what: String) -> void:
	print("LEGENDA %s: %s" % [what, "OK" if ok else "EI"])
	if not ok:
		_viat += 1
		print("TESTI VIKA %s" % what)


## Kuvat ajallisesti (sekuntia alusta) ja odotus, kunnes välianimaatiot ovat ohi.
func _shots_until_done(path: String, shots: Array, max_s := 120.0) -> void:
	# Välianimaation oma kello (cutscene.gd _now_ms): testiajo voi kulkea hitaammin kuin seinäkello.
	var t0: float = main.cutscene._now_ms()
	for st in shots:
		# [nimi, s alusta] tai [nimi, vaihe, s vaiheen alusta] (cutscene.gd phase)
		if st.size() == 3:
			while main.cutscene.phase != st[1] and main.cutscene.busy:
				await _frames(1)
			var tp: float = main.cutscene._now_ms()
			while (main.cutscene._now_ms() - tp) / 1000.0 < float(st[2]) and main.cutscene.busy:
				await _frames(1)
		while st.size() == 2 and (main.cutscene._now_ms() - t0) / 1000.0 < float(st[1]) and main.cutscene.busy:
			await _frames(1)
		if not main.cutscene.busy:
			print("LEGENDA kuva %s jäi ottamatta: kohtaus loppui %.1f s" % [st[0], (main.cutscene._now_ms() - t0) / 1000.0])
			break
		await _shot(path, st[0])
	while main.cutscene.busy and (main.cutscene._now_ms() - t0) / 1000.0 < max_s:
		await _frames(1)
	await _frames(4)  # hidas ajo: päiväkirjarivi (3,5 s) ehtisi kadota pitkässä odotuksessa


func _paapeli(path: String) -> void:
	if main.player != main.walker_out:
		main._toggle_mount()
	main.money = 30.0
	main.story.step = "valmis"
	main.endings.counts.erase("paapeli")
	main.pekka.process_mode = Node.PROCESS_MODE_DISABLED
	main._note.visible = false
	main._pekka_ride()
	await _frames(2)
	_check(not main.endings.counts.has("paapeli"), "Paapeli: hetkeä ei kirjattu kyydin alussa")
	# Kyyti 12 s + häivytykset, sitten saapuminen: kaahaus 4,6 s, pölypilvi 3,6 s, autosta nousu 4,2 s, nousu 7,5 s.
	await _shots_until_done(path, [["kyyti", 3.0], ["kaahaus", 17.0], ["perilla", 19.6], ["santtu", 22.4], ["santtu2", 25.5], ["nousu", 32.5]], 240.0)
	var lp: Vector3 = main.mokki.to_local(main.walker_out.global_position)
	print("LEGENDA Paapeli jälkeen: kerrat %d, viesti '%s', paikka (%.1f, %.1f), ohjaus %s" % [int(main.endings.counts.get("paapeli", 0)),
		main._msg.text, lp.x, lp.z, main.walker_out.controls_enabled])
	_check(int(main.endings.counts.get("paapeli", 0)) == 1, "Paapeli: hetki kirjattiin perillä")
	_check(main._msg.text.contains("uusi tarina"), "Paapeli: päiväkirjarivi")
	_check(main.walker_out.controls_enabled and main.mokki.parked_volvo[0].visible, "Paapeli: ohjaus ja pysäköity Volvo takaisin")
	await _shot(path, "jalkeen")
	# Toinen kyyti: ei saapumiskohtausta, Pekka muistelee, kerta lasketaan hiljaa.
	main._pekka_ride()
	await _frames(2)
	_check(int(main.endings.counts.get("paapeli", 0)) == 2, "Paapeli: toinen kyyti laskettiin")
	await _shots_until_done(path, [["toinen_kyyti", 1.5]], 120.0)
	_check(not main._msg.text.contains("LEGENDAARINEN"), "Paapeli: toisella kyydillä ei ilmoitusta")


func _savusauna(path: String) -> void:
	var mk: Node3D = main.mokki
	mk.ensure_built()
	# Pelaaja jalan mökin pihalle saunan eteen (kuten pelissä: savusauna on mökillä).
	if main.player != main.walker_out:
		main._toggle_mount()
	main.walker_out.global_position = mk.gpos(Vector3(4.0, 0.3, 16.0))
	main.walker_out.activate_camera()
	await _frames(20)
	main.endings.counts.erase("savusauna")
	mk.sauna_fixed = true
	print("LEGENDA laituri %s -> %s, vesi %.2f" % [mk.dock_start(), mk.dock_end(), mk.dock_water_y()])
	main._sauna_cutscene()
	await _frames(2)
	_check(not main.endings.counts.has("savusauna"), "Savusauna: hetkeä ei kirjattu löylyjen alussa")
	await _shots_until_done(path, [["otsikko", 2.0], ["loyly", 6.2], ["santtu", 15.0], ["juoksu", "juoksu", 0.8],
		["hyppy", "hyppy", 0.5], ["roiske", "hyppy", 1.4], ["uijat", "uijat", 1.6], ["uijat2", "uijat", 3.6], ["nousu", "nousu", 4.5]], 180.0)
	print("LEGENDA savusauna jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("savusauna", 0)), main._msg.text])
	_check(int(main.endings.counts.get("savusauna", 0)) == 1, "Savusauna: hetki kirjattiin järven jälkeen")
	_check(main._msg.text.contains("uusi tarina"), "Savusauna: päiväkirjarivi")
	# Toiset löylyt: tavallinen kohtaus, Santtu muistelee, kerta lasketaan hiljaa.
	main._sauna_cutscene()
	await _frames(2)
	_check(int(main.endings.counts.get("savusauna", 0)) == 2, "Savusauna: toiset löylyt laskettiin")
	await _shots_until_done(path, [["toiset", 2.0]], 120.0)
	_check(not main._msg.text.contains("LEGENDAARINEN"), "Savusauna: toisilla löylyillä ei ilmoitusta")



func _pentti(path: String) -> void:
	if main.player != main.walker_out:
		main._toggle_mount()
	main._note.visible = false
	main.endings.counts.erase("pentin_kyyti")
	var pt: RefCounted = main.rikos_osa("pentti")
	pt.kyydit = 0
	pt.todistaja_pakko = 0
	var day0: int = main.day
	pt._kyyti()
	await _frames(2)
	_check(not main.endings.counts.has("pentin_kyyti"), "Pentti: ei kirjattu kyydin alussa")
	await _shots_until_done(path, [["keinunta", 4.0], ["hiljaisuus", "hiljaisuus", 1.2], ["ovi", "ovi", 1.0], ["kassi", "ovi", 2.8],
		["pentti", "pentti", 1.6], ["nousu", "nousu", 4.0]], 120.0)
	for i in 200:
		if main.day != day0:
			break
		await _frames(1)
	await _frames(4)
	print("LEGENDA Pentti aamu: päivä %d -> %d, kerrat %d, viesti '%s'" % [day0, main.day, int(main.endings.counts.get("pentin_kyyti", 0)), main._msg.text])
	_check(int(main.endings.counts.get("pentin_kyyti", 0)) == 1, "Pentti: hetki kirjattiin")
	_check(not main._msg.text.contains("LEGENDAARINEN"), "Pentti: ei vanhaa ilmoitusta")
	await _shot(path, "aamu")
	# Toinen kyyti: ei huipennusta.
	pt._kyyti()
	await _frames(2)
	var seen_phase := false
	while main.cutscene.busy:
		if main.cutscene.phase != "":
			seen_phase = true
		await _frames(1)
	_check(not seen_phase, "Pentti: toisella kyydillä ei huipennusta")
	await _frames(60)
	_check(int(main.endings.counts.get("pentin_kyyti", 0)) == 2, "Pentti: toinen kyyti laskettiin hiljaa")
