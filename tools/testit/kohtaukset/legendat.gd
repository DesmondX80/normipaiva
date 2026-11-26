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
## tuppi_eka: räsytupin ensimmäinen voitto Saloisissa (tuppi_game.gd _leg_*): viimeinen jako pakotetaan kavereiden
##   tappioksi, kuvat ässän iskusta, kalsarikavereista, polaroidista (salama, kehitys) ja otsikosta; aamulla kuva
##   keittiön ikkunassa. Toinen ilta: nainen muistelee polaroidia, voitto ilman huipennusta lasketaan hiljaa.
## lettu_eka: lettukisan ensimmäinen voitto Saloisissa (lettu_game.gd _leg_*): kisa pakotetaan pelaajan voitoksi,
##   kuvat tyhjästä lautasesta, kruunauksesta, vatkaimesta, nuolaisusta ja otsikosta. Toinen ilta: kaveri muistelee,
##   voitto ilman huipennusta lasketaan hiljaa.
## loyly_eka: löylykisan ensimmäinen voitto Saloisissa (loyly_game.gd _leg_*): kaverit pakotetaan pakoon, kuvat
##   viimeisestä kauhasta ja höyrypilvestä, kavereista ovella pyyhkeet kourassa, pyyhkeen putoamisesta (polvista alas),
##   reaktiosta ja otsikosta. Toinen ilta: joku muistelee, voitto ilman huipennusta lasketaan hiljaa.
## disko_eka: Sivikki-diskon ensimmäinen voitto Vaalassa (disko_game.gd _leg_*): kisa pakotetaan pelaajan voitoksi,
##   kuvat bassodropista, Katjan ja pelaajan tanssiotteesta, akun hyytymisestä (Timo ja pimeät ajovalot), laulusta
##   ja otsikosta; tanssiotteen läpimenot mitataan. Toinen ilta: joku muistelee akkua, voitto lasketaan hiljaa.
## karaoke_eka: karaoke-illan ensimmäinen voitto Saloisissa (ilta_karaoke.gd _leg_*): vuorot ohitetaan pelaajan
##   voitoksi, kuvat kertosäkeestä (nainen jakkaralla), naapurin ikkunasta ja patterista, jähmettyneestä porukasta,
##   finaalista, ennätyksestä ja otsikosta; naisen jalat jakkaran kannella mitataan. Toinen ilta: joku muistelee
##   naapuria, voitto lasketaan hiljaa.
## kesaheila_eka: kesäheilan ensimmäinen ovi kotona (kolmio_kohtaus.gd _leg_*): kolme mittausta kotiin, kuvat
##   Sytkärin kartasta (ympyrät ja neula), koputuksesta, Päivistä lavakuvan hatussa, lavakuvasta ja sydämestä,
##   kavereista, kerman ojennuksesta ja otsikosta; nauraa -> hetki kirjataan (päiväkirjarivi). Toinen kerta: tavallinen
##   ovi, Päivi muistelee ja hattu on eteisen naulassa, tunnustaa -> laskettiin hiljaa ilman otsikkoa.

const Main := preload("res://scripts/main.gd")
const Kuva := preload("res://tools/testit/kuva.gd")

const KOHTAUKSET := ["mokki_paapeli", "mokki_savusauna_eka", "pentti_eka", "tuppi_eka", "lettu_eka", "loyly_eka", "disko_eka", "karaoke_eka",
	"kesaheila_eka"]

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
		"tuppi_eka":
			await _tuppi(path)
		"lettu_eka":
			await _lettu(path)
		"loyly_eka":
			await _loyly(path)
		"disko_eka":
			await _disko(path)
		"karaoke_eka":
			await _karaoke(path)
		"kesaheila_eka":
			await _kesaheila(path)
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


## Räsytuppi kesken illan: kaverit kalsareissa ja viimeinen jako päättyy heidän tappioonsa (tuppi_game.gd "jako").
func _tuppi_win(g: CanvasLayer) -> void:
	g.game.rasy[1] = 3
	g._result = {"haviaja": 1, "voittaja": 0, "tuppeen": true, "ryosto": false, "pisteet": 2}
	g.auto = true
	g._phase = "jako"
	g._t = 0.0


func _tuppi_wait(g: CanvasLayer, phase: String, sec: float) -> bool:
	for i in 20000:
		if not is_instance_valid(g):
			return false
		if g._phase == phase and g._t >= sec:
			return true
		await _frames(1)
	return false


func _tuppi(path: String) -> void:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("rasytuppi")
	DirAccess.remove_absolute(main.TUPPI_KUVA % "saloinen")
	await _frames(10)
	var s: Dictionary = main.kolmio.st("saloinen")
	s.done_day = maxi(0, main.day - 1)
	s.illat = 1
	main._kolmio_kiva("saloinen", "tuppi")
	await _frames(20)
	var g: CanvasLayer = main._rasva_game
	_check(g != null and g.legend and not g.recall, "Tuppi: ensimmäinen ilta, legenda odottaa")
	_tuppi_win(g)
	var shots := [["isku", "isku", 0.3], ["lyonti", "isku", 0.75], ["nousu", "nousu", 1.4], ["nousu2", "nousu", 3.4],
		["kuva", "kuva", 1.2]]
	for st: Array in shots:
		if await _tuppi_wait(g, st[1], st[2]):
			await _shot(path, st[0])
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
	for i in 2000:
		if not is_instance_valid(g) or g._photo != null:
			break
		await _frames(1)
	_check(is_instance_valid(g) and g._photo != null, "Tuppi: polaroid otettiin")
	if is_instance_valid(g):
		var t0: float = g._t
		while is_instance_valid(g) and g._phase == "kuva" and g._t < t0 + 0.25:
			await _frames(1)
		await _shot(path, "salama")
		while is_instance_valid(g) and g._phase == "kuva" and g._t < t0 + 3.4:
			await _frames(1)
		await _shot(path, "kehitys")
		if await _tuppi_wait(g, "otsikko", 2.6):
			await _shot(path, "otsikko")
	for i in 3000:
		if main._kolmio_ui != null:
			break
		await _frames(1)
	await _frames(30)
	var ui: CanvasLayer = main._kolmio_ui
	print("LEGENDA tuppi aamu: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("rasytuppi", 0)), main._msg.text])
	_check(int(main.endings.counts.get("rasytuppi", 0)) == 1, "Tuppi: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Tuppi: päiväkirjarivi")
	_check(ui != null and ui.photo != null, "Tuppi: polaroid aamussa")
	if ui != null:
		ui.auto = false
		ui._line = 1
		ui._view.queue_redraw()
		await _frames(10)
		await _shot(path, "aamu")
		ui._finish()
	await _frames(60)
	# Toinen ilta: muisto, voitto ilman huipennusta.
	main.kolmio.st("saloinen").done_day = maxi(0, main.day - 1)
	main._kolmio_kiva("saloinen", "tuppi")
	await _frames(20)
	g = main._rasva_game
	_check(g != null and not g.legend and g.recall, "Tuppi: toinen ilta ilman legendaa")
	_check(g != null and (String(g._bubbles[2]).contains("polaroid") or String(g._bubbles[2]).contains("kuva")), "Tuppi: nainen muistelee polaroidia")
	await _shot(path, "muisto")
	_tuppi_win(g)
	var seen := false
	while is_instance_valid(g) and main._rasva_game == g:
		if g._phase in ["isku", "nousu", "kuva", "otsikko"]:
			seen = true
		await _frames(1)
	await _frames(30)
	_check(not seen, "Tuppi: toisella voitolla ei huipennusta")
	_check(main._kolmio_ui != null and main._kolmio_ui.photo != null and not main._kolmio_ui.photo_new, "Tuppi: polaroid yhä ikkunassa toisena aamuna")
	_check(int(main.endings.counts.get("rasytuppi", 0)) == 2, "Tuppi: toinen voitto laskettiin hiljaa")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(30)
	Settings.set_v("k18_pois", k18)


## Lettukisa loppusekunneilla pelaajan johdossa (lettu_game.gd "kisa").
func _lettu_win(g: CanvasLayer) -> void:
	g._phase = "kisa"
	g._t = 0.0
	g._story = ""
	g._eaters[0].bites = 34
	g._eaters[1].bites = 22
	g._eaters[2].bites = 19
	g._left = 0.05
	g.auto = true


func _lettu(path: String) -> void:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("lettukunkku")
	await _frames(10)
	var s: Dictionary = main.kolmio.st("saloinen")
	s.done_day = maxi(0, main.day - 1)
	s.illat = 2
	main._kolmio_kiva("saloinen", "lettu")
	await _frames(20)
	var g: CanvasLayer = main._rasva_game
	_check(g != null and g.legend and not g.recall, "Lettu: ensimmäinen ilta, legenda odottaa")
	_lettu_win(g)
	var shots := [["lasku", "lasku", 0.4], ["lautanen", "lasku", 2.3], ["kruunu", "kruunu", 1.0], ["kruunattu", "kruunu", 2.6],
		["vatkain", "vatkain", 1.0], ["nuolaisu", "vatkain", 3.15], ["viikset", "vatkain", 4.0], ["kommentti", "vatkain", 5.4],
		["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if await _tuppi_wait(g, st[1], st[2]):
			await _shot(path, st[0])
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
	for i in 3000:
		if main._kolmio_ui != null:
			break
		await _frames(1)
	await _frames(30)
	print("LEGENDA lettu aamu: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("lettukunkku", 0)), main._msg.text])
	_check(int(main.endings.counts.get("lettukunkku", 0)) == 1, "Lettu: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Lettu: päiväkirjarivi")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(60)
	# Toinen ilta: kaveri muistelee, voitto ilman huipennusta.
	main.kolmio.st("saloinen").done_day = maxi(0, main.day - 1)
	main._kolmio_kiva("saloinen", "lettu")
	await _frames(20)
	g = main._rasva_game
	_check(g != null and not g.legend and g.recall, "Lettu: toinen ilta ilman legendaa")
	var muisto := false
	if g != null:
		for b: String in g._bubbles:
			if b.contains("vatkai") or b.contains("kunkku"):
				muisto = true
	_check(muisto, "Lettu: kaveri muistelee vatkainta")
	await _shot(path, "muisto")
	_lettu_win(g)
	var seen := false
	while is_instance_valid(g) and main._rasva_game == g:
		if g._phase in g.LEG:
			seen = true
		await _frames(1)
	await _frames(30)
	_check(not seen, "Lettu: toisella voitolla ei huipennusta")
	_check(int(main.endings.counts.get("lettukunkku", 0)) == 2, "Lettu: toinen voitto laskettiin hiljaa")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(30)
	Settings.set_v("k18_pois", k18)


## Löylykisa: kaverit pakenevat heti, pelaaja jää viimeiseksi (loyly_game.gd _race -> _end).
func _loyly_win(g: CanvasLayer) -> void:
	g._phase = "kisa"
	g._t = 0.0
	g._story = ""
	g._heat = 6
	g.auto = true
	g._flee(1)
	g._flee(2)


func _loyly(path: String) -> void:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("loylykunkku")
	await _frames(10)
	var s: Dictionary = main.kolmio.st("saloinen")
	s.done_day = maxi(0, main.day - 1)
	s.illat = 2
	main._kolmio_kiva("saloinen", "loyly")
	await _frames(20)
	var g: CanvasLayer = main._rasva_game
	_check(g != null and g.legend and not g.recall, "Löyly: ensimmäinen ilta, legenda odottaa")
	_loyly_win(g)
	var shots := [["kauha", "kauha", 0.6], ["pilvi", "kauha", 2.7], ["kunkku", "kauha", 4.2], ["ovi", "ovi", 1.3],
		["ovi2", "ovi", 3.4], ["nousu", "pyyhe", 1.4], ["putoaa", "pyyhe", 2.72], ["kasa", "pyyhe", 3.4],
		["reaktio", "pyyhe", 4.6], ["ego", "pyyhe", 6.6], ["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if await _tuppi_wait(g, st[1], st[2]):
			await _shot(path, st[0])
			if st[0] == "ego":  # siveä rajaus: kunkun lantio kuvan alareunan alapuolella
				var c: Node3D = g._chars[0]
				var q: Vector2 = g._cam.unproject_position(c.to_global(c.bone_position("pelvis")) + Vector3(0, 0.12, 0))
				var vs: Vector2 = main.get_viewport().get_visible_rect().size
				print("LEGENDA löyly lantio ruudulla y %.0f / %.0f" % [q.y, vs.y])
				_check(q.y > vs.y, "Löyly: lantio rajattu pois kaksoiskuvasta")
			if st[0] == "kasa":
				var c2: Node3D = g._chars[0]
				var k: Vector2 = g._cam.unproject_position(c2.to_global(c2.bone_position("pelvis")))
				print("LEGENDA löyly jalkakuva lantio y %.0f" % k.y)
				_check(k.y < 0.0, "Löyly: jalkakuvassa lantio kuvan yläpuolella")
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
	for i in 3000:
		if main._kolmio_ui != null:
			break
		await _frames(1)
	await _frames(30)
	print("LEGENDA löyly aamu: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("loylykunkku", 0)), main._msg.text])
	_check(int(main.endings.counts.get("loylykunkku", 0)) == 1, "Löyly: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Löyly: päiväkirjarivi")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(60)
	# Toinen ilta: joku muistelee, voitto ilman huipennusta.
	main.kolmio.st("saloinen").done_day = maxi(0, main.day - 1)
	main._kolmio_kiva("saloinen", "loyly")
	await _frames(20)
	g = main._rasva_game
	_check(g != null and not g.legend and g.recall, "Löyly: toinen ilta ilman legendaa")
	var muisto := false
	if g != null:
		for b: String in g._bubbles:
			if b.contains("pyyhe") or b.contains("kunkku"):
				muisto = true
	_check(muisto, "Löyly: joku muistelee pyyhettä")
	await _shot(path, "muisto")
	_loyly_win(g)
	var seen := false
	while is_instance_valid(g) and main._rasva_game == g:
		if g._phase in g.LEG:
			seen = true
		await _frames(1)
	await _frames(30)
	_check(not seen, "Löyly: toisella voitolla ei huipennusta")
	_check(int(main.endings.counts.get("loylykunkku", 0)) == 2, "Löyly: toinen voitto laskettiin hiljaa")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(30)
	Settings.set_v("k18_pois", k18)


## Sivikki-disko: kaikki liikkeet osutuiksi ja pelaajalle ylivoimaiset pisteet (disko_game.gd _dance -> _end).
func _disko_win(g: CanvasLayer) -> void:
	g._phase = "kisa"
	g._t = 0.0
	g._story = ""
	g.auto = true
	for n: Dictionary in g._notes:
		n.hit = true
	g._score = [9600, 3100, 3400]


func _disko(path: String) -> void:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	const Contact := preload("res://scripts/contact.gd")
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("sivikkidisko")
	if main.player != main.walker_out:
		main._toggle_mount()
	main.mokki.ensure_built()
	main._start_mopo()
	await _frames(30)
	var s: Dictionary = main.kolmio.st("vaala")
	s.done_day = maxi(0, main.day - 1)
	s.illat = 2
	main._kolmio_kiva("vaala", "disko")
	await _frames(20)
	var g: CanvasLayer = main._rasva_game
	_check(g != null and g.legend and not g.recall, "Disko: ensimmäinen ilta, legenda odottaa")
	if g == null:
		Settings.set_v("k18_pois", k18)
		return
	await _frames(30)
	_disko_win(g)
	var shots := [["droppi", "droppi", 0.6], ["drop", "droppi", 2.4], ["pari", "pari", 1.6], ["ote", "pari", 4.0],
		["himmenee", "sammuu", 0.9], ["timo", "sammuu", 4.4], ["laulu", "laulu", 1.2], ["kuoro", "laulu", 5.6],
		["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if await _tuppi_wait(g, st[1], st[2]):
			await _shot(path, st[0])
			if st[0] == "ote" and not g._prof.is_empty():  # tanssiote: vartalot eivät mene toistensa sisään
				var deep := 0.0
				var what := ""
				for o: Array in Contact.overlap_pairs(g._chars[0], g._prof[0], g._chars[3], g._prof[3], 0.0):
					if float(o[2]) > deep:
						deep = float(o[2])
						what = "%s-%s" % [o[0], o[1]]
				print("LEGENDA disko ote syvin päällekkäisyys %.3f m (%s)" % [deep, what])
				_check(deep < 0.025, "Disko: tanssiotteessa ei läpimenoa")
				var hl: Vector3 = g._chars[0].to_global(g._chars[0].bone_position("hand_l"))
				var kw: Vector3 = g._chars[3].to_global(g._chars[3].bone_position("spine_01"))
				print("LEGENDA disko pelaajan käsi Katjan vyötäröltä %.2f m" % hl.distance_to(kw))
				_check(hl.distance_to(kw) < 0.3, "Disko: pelaajan käsi Katjan vyötäröllä")
			if st[0] == "timo":
				_check(not g._music.playing and g._lit == 0.0, "Disko: akku loppui, musiikki ja valot pois")
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
			_check(false, "Disko: vaihe %s/%s" % [st[1], st[0]])
	for i in 3000:
		if main._kolmio_ui != null:
			break
		await _frames(1)
	await _frames(30)
	print("LEGENDA disko aamu: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("sivikkidisko", 0)), main._msg.text])
	_check(int(main.endings.counts.get("sivikkidisko", 0)) == 1, "Disko: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Disko: päiväkirjarivi")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(60)
	# Toinen ilta: joku muistelee akkua, voitto ilman huipennusta.
	main.kolmio.st("vaala").done_day = maxi(0, main.day - 1)
	main._kolmio_kiva("vaala", "disko")
	await _frames(20)
	g = main._rasva_game
	_check(g != null and not g.legend and g.recall, "Disko: toinen ilta ilman legendaa")
	var muisto := false
	if g != null:
		for b: String in g._bubbles:
			if b.contains("akku"):
				muisto = true
	_check(muisto, "Disko: joku muistelee akkua")
	await _shot(path, "muisto")
	if g != null:
		_disko_win(g)
		var seen := false
		while is_instance_valid(g) and main._rasva_game == g:
			if g._phase in g.LEG:
				seen = true
			await _frames(1)
		await _frames(30)
		_check(not seen, "Disko: toisella voitolla ei huipennusta")
	_check(int(main.endings.counts.get("sivikkidisko", 0)) == 2, "Disko: toinen voitto laskettiin hiljaa")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(30)
	Settings.set_v("k18_pois", k18)


## Karaoke: laulamatta suoraan loppuun pelaajan voittona (ilta_karaoke.gd _end).
func _karaoke_win(g: CanvasLayer) -> void:
	if g._kg != null:
		g._kg.queue_free()
		g._kg = null
	g.auto = true
	g._scores = [0.94, 0.61, 0.72]
	g._turn = g._turns.size()
	g._end()


func _karaoke(path: String) -> void:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("karaokekunkku")
	await _frames(10)
	var s: Dictionary = main.kolmio.st("saloinen")
	s.done_day = maxi(0, main.day - 1)
	s.illat = 3
	main._kolmio_kiva("saloinen", "karaoke")
	await _frames(20)
	var g: CanvasLayer = main._rasva_game
	_check(g != null and g.legend and not g.recall, "Karaoke: ensimmäinen ilta, legenda odottaa")
	_karaoke_win(g)
	_check(g._phase == "kerto", "Karaoke: voitto aloitti kertosäkeen")
	var shots := [["kerto", "kerto", 1.4], ["kerto2", "kerto", 3.6], ["ikkuna", "naapuri", 0.9], ["kop", "naapuri", 1.5],
		["huuto", "naapuri", 3.0], ["jahmo", "naapuri", 5.6], ["finaali", "finaali", 1.2], ["pito", "finaali", 3.9],
		["laskuri", "ennatys", 1.2], ["ennatys", "ennatys", 2.2], ["porukka", "ennatys", 3.4], ["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if await _tuppi_wait(g, st[1], st[2]):
			await _shot(path, st[0])
			if st[0] == "kerto":  # nainen seisoo jakkaralla: jalkapohjat kannen tasolla ja kannen sisällä
				var w: Node3D = g._leg_chars[3]
				var stool: Vector3 = g.CENTER + g.AUDIENCE[1]
				for b in ["foot_l", "foot_r"]:
					var fp: Vector3 = g._hall.to_local(w.to_global(w.bone_position(b)))
					var d := Vector2(fp.x - stool.x, fp.z - stool.z).length()
					print("LEGENDA karaoke nainen %s: korkeus %.3f (kansi %.3f), etäisyys keskeltä %.3f" % [b, fp.y, g.STOOL_H, d])
					_check(fp.y > g.STOOL_H - 0.01 and d < 0.19, "Karaoke: %s jakkaran kannella" % b)
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
	for i in 3000:
		if main._kolmio_ui != null:
			break
		await _frames(1)
	await _frames(30)
	print("LEGENDA karaoke aamu: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("karaokekunkku", 0)), main._msg.text])
	_check(int(main.endings.counts.get("karaokekunkku", 0)) == 1, "Karaoke: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Karaoke: päiväkirjarivi")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(60)
	# Toinen ilta: joku muistelee naapuria, voitto ilman huipennusta.
	main.kolmio.st("saloinen").done_day = maxi(0, main.day - 1)
	main._kolmio_kiva("saloinen", "karaoke")
	await _frames(20)
	g = main._rasva_game
	_check(g != null and not g.legend and g.recall, "Karaoke: toinen ilta ilman legendaa")
	var muisto := false
	if g != null:
		for b: String in g._bubbles:
			if b.contains("naapuri") or b.contains("Raimo"):
				muisto = true
	_check(muisto, "Karaoke: joku muistelee naapuria")
	await _shot(path, "muisto")
	_karaoke_win(g)
	var seen := false
	while is_instance_valid(g) and main._rasva_game == g:
		if g._phase in g.LEG:
			seen = true
		await _frames(1)
	await _frames(30)
	_check(not seen, "Karaoke: toisella voitolla ei huipennusta")
	_check(int(main.endings.counts.get("karaokekunkku", 0)) == 2, "Karaoke: toinen voitto laskettiin hiljaa")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(30)
	Settings.set_v("k18_pois", k18)


## Kesäheilan ovi: kolme mittausta kotiin ja koputus (_kolmio_knock), kuten kolmiomittaus_koti mutta suoraan.
func _kesa_ovi() -> CanvasLayer:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	main.kolmio = Kolmio.new()
	var t: Vector2 = main._kolmio_target("koti")
	main.kolmio.start("koti", main._kolmio_start_point("koti"), t, "Joni")
	main.kolmio.measure("koti", t + Vector2(260, -140), t, "Esa")
	main.kolmio.measure("koti", t + Vector2(-70, 55), t, "Sinä")
	main._kolmio_knock("koti", -1)
	await _frames(10)
	return main._kolmio_ui


func _kesa_wait(ui: CanvasLayer, line: int, sec: float) -> bool:
	for i in 20000:
		if not is_instance_valid(ui):
			return false
		if (line < 0 and ui._title_t >= sec) or (line >= 0 and ui._title_t < 0.0 and ui._line == line and ui._line_t >= sec):
			return true
		await _frames(1)
	return false


func _kesaheila(path: String) -> void:
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	for e in ["kesaheila", "kulissit", "avoin_pelikortti"]:
		main.endings.counts.erase(e)
	var p: Object = main.rikos_osa("paivi")
	if p != null:
		p.liput.clear()
		p.poissa_asti = -1
		p.epaluulo = 65.0
	await _frames(10)
	var ui := await _kesa_ovi()
	_check(ui != null and ui.site == "koti" and ui.legend and not ui.recall, "Kesäheila: ensimmäinen ovi lavastetaan")
	if ui == null:
		return
	print("LEGENDA kesäheila ympyrät %s" % [ui.rings.map(func(r: Dictionary) -> String: return "%s %.0f m" % [r.who, r.m])])
	var shots := [["kartta", 0, 2.4], ["neula", 1, 2.2], ["kop", 2, 0.5], ["ovi", 3, 2.4], ["sinikka", 4, 2.0], ["muisto", 5, 3.0],
		["kaverit", 6, 1.6], ["kerma", 8, 1.6], ["otsikko", -1, 3.0]]
	for st: Array in shots:
		if await _kesa_wait(ui, st[1], st[2]):
			await _shot(path, st[0])
			if st[0] == "ovi":
				_check(ui._hat != null and is_instance_valid(ui._hat), "Kesäheila: Päivillä lavakuvan hattu")
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
	for i in 2000:
		if not is_instance_valid(ui):
			break
		await _frames(1)
	await _frames(10)
	var ids: Array = main._talk_options().map(func(x: Dictionary) -> String: return x.id)
	print("LEGENDA kesäheila valinnat %s, kerrat %d" % [ids, int(main.endings.counts.get("kesaheila", 0))])
	_check("paivi_kesa_nauraa" in ids and int(main.endings.counts.get("kesaheila", 0)) == 0, "Kesäheila: otsikon jälkeen valinta, ei vielä kirjattu")
	main._talk_choose("paivi_kesa_nauraa")
	await _frames(10)
	main._talk_choose("paivi_kesa_jatka")
	await _frames(20)
	print("LEGENDA kesäheila nauraa: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("kesaheila", 0)), main._msg.text])
	_check(int(main.endings.counts.get("kesaheila", 0)) == 1, "Kesäheila: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Kesäheila: päiväkirjarivi")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(60)
	# Toinen kerta: tavallinen ovi, Päivi muistelee ja hattu naulassa; tunnustaa lasketaan hiljaa.
	if p != null:
		p.liput.clear()
		p.poissa_asti = -1
	ui = await _kesa_ovi()
	_check(ui != null and not ui.legend and ui.recall, "Kesäheila: toinen kerta ilman legendaa")
	if ui == null:
		return
	ui.auto = false
	var muisto := false
	for l: Array in ui.lines:
		if String(l[1]).contains("naulassa"):
			muisto = true
	_check(muisto, "Kesäheila: Päivi muistelee hattua")
	ui._line = 2
	ui._door = 1.0
	ui._door_to = 1.0
	ui._line_t = 3.0
	await _frames(30)
	await _shot(path, "toinen")
	ui._finish()
	await _frames(10)
	main._talk_choose("paivi_kesa_tunnustaa")
	await _frames(20)
	_check(int(main.endings.counts.get("kesaheila", 0)) == 2, "Kesäheila: toinen kerta laskettiin hiljaa")
	main._talk_box.close()
	await _frames(10)
	Settings.set_v("k18_pois", k18)
