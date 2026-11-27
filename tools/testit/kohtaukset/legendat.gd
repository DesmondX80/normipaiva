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
## lava_eka: Oulujärven lavan ensimmäinen hyvä humppa (lava_game.gd _leg_*): kappale pakotetaan hyväksi, kuvat
##   laulajasta mikillä, olan yli lattialle, piiriin kävelystä ja taputuksesta, rinta rinnan potkusta (kolmas potku),
##   ukon ja mummon repliikeistä ja otsikosta; kädet ja jalat mitataan (taputus, potku). Lavalta ulos -> päiväkirjarivi.
##   Toinen käynti: pari muistelee, hyvä humppa ilman huipennusta lasketaan hiljaa.
## karaoke_baari_eka: baarin karaoken ensimmäinen raikuva veto Siitarissa (karaoke_legenda.gd): kuvat viimeisestä
##   sävelestä, hiljaisuudesta, salin aplodeista ja kumarruksesta, kellosta, tuopin liu'usta ja kiinniotosta, taulusta
##   ja otsikosta; kädet mitataan (mikki, taputus, tuoppi). Taulu jää seinälle, hetki päiväkirjaan. Toinen käynti:
##   baarimikko muistelee, raikuva veto lasketaan hiljaa. Lopuksi sama kohtaus Kapteenin Kellarissa (kuvat).
## kiihdytys_eka: mopojen kiihdytyksen ensimmäinen voitto Vaalantiellä (kiihdytys_legenda.gd): kisan tulos pakotetaan
##   voitoksi, kuvat hidastetusta maalista (lähestyminen, salama viivalla, vastustaja perässä), vastustajan ilmeestä,
##   keulinnasta ja hurraavista mopopojista, työnnöstä Zabukille ja otsikosta; keulinta, lippu ja työntäjän kädet
##   mitataan. Hetki päiväkirjaan. Toinen käynti: pojat muistelevat, voitto ilman huipennusta lasketaan hiljaa.
## tanssit_eka: seuraintalon tanssien ensimmäinen hyvä tanssi Sinikan kanssa (tanssi_game.gd _leg_*): tanssi pakotetaan
##   hyväksi, kuvat viimeisestä valssista (valot himmenevät), taivutuksesta, valojen syttymisestä (Anna-Liisa lupaa
##   kertoa kylälle) ja otsikosta; parin koko kuvassa, taivutuksen kädet, jalat ja läpimenot mitataan. Hetki
##   päiväkirjaan ja sali palautuu. Toinen käynti: Anna-Liisa muistelee, hyvä tanssi ilman huipennusta lasketaan hiljaa.
## piirakka_eka: Reipparin lihapiirakkahaasteen ensimmäinen ennätys (piirakka_legenda.gd): haaste pakotetaan kahdeksaan
##   piirakkaan, kuvat viimeisestä palasta ja laskusta, Juntin paperilaskennasta, rullamitasta, Raijan tussiviivasta ja
##   lapusta, röyhtäyksestä ja otsikosta; kädet (paperi, mitta, nenä), kohteiden koko kuvassa ja asennot mitataan.
##   Hetki päiväkirjaan, taulussa uusi nimi. Toinen haaste: Juntti tai Raija muistelee, ennätys lasketaan hiljaa.

const Main := preload("res://scripts/main.gd")
const Kuva := preload("res://tools/testit/kuva.gd")
const TanssiGame := preload("res://scripts/tanssi_game.gd")
const Contact := preload("res://scripts/contact.gd")
const PiirakkaGame := preload("res://scripts/piirakka_game.gd")
const PiirakkaLegenda := preload("res://scripts/piirakka_legenda.gd")

const KOHTAUKSET := ["mokki_paapeli", "mokki_savusauna_eka", "pentti_eka", "tuppi_eka", "lettu_eka", "loyly_eka", "disko_eka", "karaoke_eka",
	"kesaheila_eka", "lava_eka", "karaoke_baari_eka", "kiihdytys_eka", "tanssit_eka", "piirakka_eka"]

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
		"lava_eka":
			await _lava(path)
		"karaoke_baari_eka":
			await _baari(path)
		"kiihdytys_eka":
			await _kiihdytys(path)
		"tanssit_eka":
			await _tanssit(path)
		"piirakka_eka":
			await _piirakka(path)
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


## Lava: hyvä humppa pakotetaan (osumat), kappale loppuun (lava_game.gd _dance, _t >= SONG).
func _lava_dance(lg: Node3D) -> void:
	lg._start_dance("humppa")
	await _frames(10)
	lg._hits = 200
	lg._misses = 0
	lg._t = lg.SONG


func _lava_wait(lg: Node3D, phase: String, sec: float) -> bool:
	for i in 6000:
		if not is_instance_valid(lg):
			return false
		if lg._phase == phase and lg._leg_t >= sec:
			return true
		if lg._phase == "result" or (phase in lg.LEG and lg.LEG.find(lg._phase) > lg.LEG.find(phase)):
			return false
		await _frames(1)
	return false


func _lava(path: String) -> void:
	main.endings.counts.erase("lavatanssit")
	if main.player != main.walker_out:
		main._toggle_mount()
	main._start_mopo()
	await _frames(30)
	main._enter_lava(true)
	await _frames(40)
	var lg: Node3D = main._lava_game
	_check(lg != null and lg.legend and not lg.recall, "Lava: ensimmäinen käynti, legenda odottaa")
	if lg == null:
		return
	await _lava_dance(lg)
	var shots := [["laulaja", "kutsu", 1.6], ["olka", "kutsu", 4.2], ["kavely", "piiri", 1.0], ["piiri", "piiri", 4.4],
		["potku1", "potku", 0.9], ["potku3", "potku", 2.95], ["ukko", "potku", 4.4], ["mummo", "potku", 6.8], ["otsikko", "otsikko", 3.0],
		["otsikko2", "otsikko", 5.6]]
	for st: Array in shots:
		if await _lava_wait(lg, st[1], st[2]):
			await _shot(path, st[0])
			if st[0] == "olka":
				var vs: Vector2 = main.get_viewport().get_visible_rect().size
				var top: Vector2 = lg._cam.unproject_position(lg._me.to_global(lg._me.bone_position("Head")) + Vector3(0, 0.15, 0))
				var bot: Vector2 = lg._cam.unproject_position(lg._me.global_position)
				var sx := -1.0
				if lg._leg_singer != null:
					sx = lg._cam.unproject_position(lg._leg_singer.to_global(lg._leg_singer.bone_position("Head"))).x
				print("LEGENDA lava olka: pari %.0f px korkea, laulajan pää x %.0f / %.0f" % [bot.y - top.y, sx, vs.x])
				_check(bot.y - top.y >= 150.0 and sx > 0.0 and sx < vs.x * 0.3, "Lava: olan yli -kuvassa laulaja reunassa ja pari iso")
			if st[0] == "piiri":
				var n := 0
				for c: Node3D in lg._leg_ring:
					var hl: Vector3 = c.to_global(c.bone_position("hand_l"))
					var hr: Vector3 = c.to_global(c.bone_position("hand_r"))
					if hl.distance_to(hr) < 0.32:
						n += 1
				print("LEGENDA lava piirissä %d, kädet yhdessä %d" % [lg._leg_ring.size(), n])
				_check(lg._leg_walk.is_empty() and lg._leg_ring.size() >= 16 and n >= lg._leg_ring.size() - 2, "Lava: piiri taputtaa")
			if st[0] == "potku3":
				for c: Node3D in [lg._me, lg._partner]:
					var hip: Vector3 = c.to_global(c.bone_position("thigh_r"))
					var foot: Vector3 = c.to_global(c.bone_position("foot_r"))
					var stand: Vector3 = c.to_global(c.bone_position("foot_l"))
					print("LEGENDA lava potku: lonkka %.2f, jalka %.2f, tukijalka %.2f (lattia %.2f)" % [hip.y, foot.y, stand.y, lg.global_position.y])
					_check(foot.y > hip.y - 0.55 and stand.y - lg.global_position.y < 0.2, "Lava: jalka nousee, tukijalka lattialla")
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
			_check(false, "Lava: vaihe %s/%s" % [st[1], st[0]])
	for i in 600:
		if lg._phase == "result":
			break
		await _frames(1)
	_check(lg._phase == "result", "Lava: legendan jälkeen tulos")
	lg._leave()
	await _frames(20)
	print("LEGENDA lava ulos: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("lavatanssit", 0)), main._msg.text])
	_check(int(main.endings.counts.get("lavatanssit", 0)) == 1, "Lava: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Lava: päiväkirjarivi")
	await _frames(60)
	# Toinen käynti: pari muistelee, hyvä humppa ilman huipennusta.
	main._enter_lava(true)
	await _frames(40)
	lg = main._lava_game
	_check(lg != null and not lg.legend and lg.recall, "Lava: toinen käynti ilman legendaa")
	if lg == null:
		return
	var muisto := false
	for c: Node3D in lg._leg_bub:
		if String(lg._leg_bub[c]).contains("jalka") or String(lg._leg_bub[c]).contains("piirin"):
			muisto = true
	_check(muisto, "Lava: pari muistelee")
	await _shot(path, "muisto")
	await _lava_dance(lg)
	var seen := false
	for i in 120:
		if lg._phase in lg.LEG:
			seen = true
		await _frames(1)
	_check(not seen and lg._phase == "result", "Lava: toisella hyvällä humpalla ei huipennusta")
	lg._leave()
	await _frames(20)
	_check(int(main.endings.counts.get("lavatanssit", 0)) == 2, "Lava: toinen kerta laskettiin hiljaa")


func _baari_sing(score: float, raahe: bool) -> void:
	main.money = 50.0
	if raahe:
		main._on_raahe_acted("karaoke")
	else:
		main._on_siitari_acted("karaoke")
	await _frames(5)
	var kg: CanvasLayer = main._karaoke_game()
	if kg == null:
		_check(false, "Baari: karaoke aukesi")
		return
	kg.finished.emit(score)
	await _frames(3)


func _baari_wait(phase: String, sec: float) -> bool:
	var g: CanvasLayer = main._karaoke_leg
	for i in 2000:
		if not is_instance_valid(g):
			return false
		if g.phase == phase and g._t >= sec:
			return true
		await _frames(1)
	return false


func _baari_scene(path: String, prefix: String, measure: bool) -> void:
	var g: CanvasLayer = main._karaoke_leg
	_check(g != null, "Baari %s: legenda alkoi" % prefix)
	if g == null:
		return
	var shots := [["savel", "savel", 1.0], ["savel2", "savel", 3.0], ["hiljaisuus", "hiljaisuus", 1.4], ["aplodit", "aplodit", 1.6],
		["aplodit2", "aplodit", 3.4], ["kello", "kello", 0.75], ["liuku", "tuoppi", 1.0], ["kiinni", "tuoppi", 2.3],
		["nosto", "tuoppi", 3.25], ["otsikko", "otsikko", 2.2], ["otsikko2", "otsikko", 5.0]]
	for st: Array in shots:
		if not await _baari_wait(st[1], st[2]):
			_check(false, "Baari %s: vaihe %s" % [prefix, st[0]])
			continue
		await _shot(path, prefix + st[0])
		if not measure:
			continue
		match st[0]:
			"savel2":
				var hd: Vector3 = g._player.to_global(g._player.bone_position("Head"))
				print("LEGENDA baari sävel: walker %s, pää %s -> ruudulla %s, kamera %s" % [g._walker.position, g.interior.to_local(hd),
					g._cam.unproject_position(hd), g.interior.to_local(g._cam.global_position)])
				var h: Vector3 = g._player.to_global(g._player.bone_position("hand_r"))
				var mic: Vector3 = g.interior.to_global(g.cast.mic)
				print("LEGENDA baari mikki: käsi %.3f m telineestä" % h.distance_to(mic))
				_check(h.distance_to(mic) < 0.12, "Baari: käsi mikkitelineessä")
			"aplodit":
				var n := 0
				for a: Array in g._aud:
					var c: Node3D = a[0]
					if c.to_global(c.bone_position("hand_l")).distance_to(c.to_global(c.bone_position("hand_r"))) < 0.32:
						n += 1
				print("LEGENDA baari aplodit: %d / %d taputtaa" % [n, g._aud.size()])
				_check(n == g._aud.size(), "Baari: koko sali taputtaa")
			"kello":
				var bt: Node3D = g.cast.bartender
				var bh: Vector3 = bt.to_global(bt.bone_position("hand_r"))
				var cord: Vector3 = g._bell.to_global(Vector3(0, 0.19, 0))
				print("LEGENDA baari kello: käsi %s, naru %s, ero %.3f" % [g.interior.to_local(bh), g.interior.to_local(cord), bh.distance_to(cord)])
				_check(bh.distance_to(cord) < 0.1, "Baari: baarimikon käsi kellon narussa")
			"aplodit2":
				var hd: Vector3 = g._player.to_global(g._player.bone_position("Head"))
				var pv: Vector3 = g._player.to_global(g._player.bone_position("pelvis"))
				var fw: Vector3 = g.interior.global_basis * (g.cast.face as Vector3)
				print("LEGENDA baari kumarrus: pää %.2f m lantion edessä" % (hd - pv).dot(fw))
				_check((hd - pv).dot(fw) > 0.15, "Baari: pelaaja kumartaa")
			"kiinni":
				var h: Vector3 = g._player.to_global(g._player.bone_position("hand_r"))
				var hw: Vector3 = g._pint.to_global(g._pint.get_meta("handle"))
				print("LEGENDA baari tuoppi: käsi %.3f m korvasta" % h.distance_to(hw))
				_check(h.distance_to(hw) < 0.12, "Baari: käsi tuopin korvassa")
	for i in 900:
		if not is_instance_valid(g):
			break
		await _frames(1)
	await _frames(5)


func _baari_enter_siitari() -> void:
	main._start_mopo()
	var mp: CharacterBody3D = main.mopo_trip.mopo
	mp.position = main.mopo_trip.vaala.siitari_park + Vector3(0, 0.5, 0)
	for i in 10:
		await main.get_tree().physics_frame
	main.mopo_trip.stop()
	main._on_mopo_arrived()
	main._note.visible = false
	await _frames(10)
	main.siitari_int.walker.position = main.siitari_int.spots.karaoke[0]


func _baari(path: String) -> void:
	main.endings.counts.erase("karaoke")
	for k in ["karaoke_taulu_siitari", "karaoke_taulu_raahe"]:
		main.tilat.firsts.erase(k)
	# Kapteenin Kellari ensin (Saloisista taksilla): sama kohtaus Raahessa.
	main._enter_raahe()
	await _frames(20)
	main.raahe_int.walker.position = main.raahe_int.spots.karaoke[0]
	await _frames(5)
	await _baari_sing(0.96, true)
	await _baari_scene(path, "raahe_", true)
	var rb: Node3D = main.raahe_int._board
	_check(rb != null and rb.visible and "karaoke_taulu_raahe" in main.tilat.firsts, "Baari: Kellarin taulu seinällä")
	_check(main.raahe_int._singer.current().begins_with("Sitting"), "Baari: vakiolaulaja istuu taas")
	main.raahe_int.leave()
	main.state = "ulkona"
	await _frames(10)
	# Siitari.
	main.endings.counts.erase("karaoke")
	await _baari_enter_siitari()
	_check(main.state == "in_siitari", "Baari: Siitarissa")
	await _baari_sing(0.96, false)
	await _baari_scene(path, "", true)
	print("LEGENDA baari: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("karaoke", 0)), main._msg.text])
	_check(int(main.endings.counts.get("karaoke", 0)) == 1, "Baari: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Baari: päiväkirjarivi")
	_check("karaoke_taulu_siitari" in main.tilat.firsts, "Baari: taulu muistetaan")
	var b: Node3D = main.siitari_int._board
	_check(b != null and b.visible, "Baari: taulu seinällä")
	var seated := true
	for c: Node3D in main.siitari_int._seurue + main.siitari_int._cardplayers:
		if not c.current().begins_with("Sitting"):
			seated = false
	_check(seated and main.siitari_int.walker.controls_enabled, "Baari: sali istuu taas, pelaaja liikkuu")
	await _shot(path, "jalkeen")
	# Toinen käynti: baarimikko muistelee, raikuva veto ilman kohtausta.
	main._on_siitari("lahde")
	await _frames(20)
	await _baari_enter_siitari()
	var bt_text: String = main.siitari_int._bubbles[main.siitari_int._bartender].text
	print("LEGENDA baari muisto: '%s'" % bt_text)
	_check(bt_text.to_lower().contains("taulu") or bt_text.to_lower().contains("kuningas"), "Baari: baarimikko muistelee")
	main.siitari_int.walker.position = Vector3(-5.2, 0, -1.6)
	main.siitari_int.walker.rotation.y = B_yaw(Vector3(-1, 0, -1.1))
	await _frames(20)
	await _shot(path, "muisto")
	await _baari_sing(0.96, false)
	_check(main._karaoke_leg == null, "Baari: toisella kerralla ei kohtausta")
	await _frames(10)
	_check(int(main.endings.counts.get("karaoke", 0)) == 2, "Baari: toinen kerta laskettiin hiljaa")


## Kiihdytys alkaa Zabukin pihassa: mopopoikien valikosta pieni kisa (Tunturi-Jani).
func _kiih_start() -> Node3D:
	var vl: Node3D = main.mopo_trip.vaala
	main.money = 60.0
	main.walker_out.global_position = main.mopo_trip.to_global(vl.race_spot + Vector3(0, 0.5, 0)
		+ vl.doors.filter(func(d): return d.id == "kiihdytys")[0].out * 3.0)
	await _frames(15)
	main._on_vaala_door("kiihdytys")
	await _frames(5)
	main._talk_choose("kisa")
	await _frames(30)
	return main._race


## Kisan tulos pakotetaan pelaajan voitoksi: molemmat maalissa, pelaaja ensin (mopo_race.gd _process "race").
func _kiih_win(rc: Node3D) -> void:
	rc._green_at = maxf(rc._t - 9.84, 0.001)
	rc._me.go = true
	rc._opp.go = true
	rc._me.s = rc.DIST + 1.0
	rc._opp.s = rc.DIST + 0.4
	rc._me.time = 9.84
	rc._opp.time = 10.06
	rc._phase = "race"


func _kiih_legend(rc: Node3D) -> CanvasLayer:
	for i in 300:
		if not is_instance_valid(rc):
			return null
		for c in rc.get_children():
			if c is CanvasLayer and "phase" in c and "race" in c:
				return c
		await _frames(1)
	return null


func _kiih_wait(lg: CanvasLayer, phase: String, sec: float) -> bool:
	for i in 6000:
		if not is_instance_valid(lg) or lg.phase == "":
			return false
		if lg.phase == phase and lg._t >= sec:
			return true
		if lg.ORDER.find(lg.phase) > lg.ORDER.find(phase):
			return false
		await _frames(1)
	return false


func _kiihdytys(path: String) -> void:
	main.endings.counts.erase("kiihdytys")
	main.tilat.firsts.erase("kiihdytys_muisto")
	if main.player != main.walker_out:
		main._toggle_mount()
	main._start_mopo()
	await _frames(30)
	main._mopo_dismount()
	await _frames(10)
	var rc: Node3D = await _kiih_start()
	_check(rc != null and rc.legend, "Kiihdytys: ensimmäinen kisa, legenda odottaa")
	if rc == null:
		return
	_kiih_win(rc)
	var lg: CanvasLayer = await _kiih_legend(rc)
	_check(lg != null, "Kiihdytys: voitosta alkoi lavastettu kohtaus")
	if lg == null:
		return
	var shots := [["lahestyy", "maali", 0.9], ["viiva", "maali", -1.0], ["perassa", "maali", 3.3], ["ilme", "ilme", 1.0],
		["ilme2", "ilme", 2.9], ["keulinta", "keulinta", 1.2], ["hurraus", "keulinta", 2.8], ["tyonto", "tyonto", 1.4],
		["tyonto2", "tyonto", 3.4], ["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		var ok := false
		if st[0] == "viiva":
			for i in 3000:
				if not is_instance_valid(lg) or lg.phase != "maali":
					break
				if lg._cross_t >= 0.0 and lg._t >= lg._cross_t + 0.25:
					ok = true
					break
				await _frames(1)
		else:
			ok = await _kiih_wait(lg, st[1], st[2])
		if not ok:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
			_check(false, "Kiihdytys: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		if st[0] == "viiva":
			var me: Node3D = rc._my_model
			var opp: Node3D = rc._opp_model
			var lead: float = lg._s_me - lg._s_opp
			print("LEGENDA kiihdytys viivalla: pelaaja %.2f m, vastustaja %.2f m (viiva %.0f), ero %.2f m" % [lg._s_me, lg._s_opp, rc.DIST, lead])
			_check(lead > 0.5 and me.visible and opp.visible, "Kiihdytys: pelaaja viivalla ensin")
			var hand: Vector3 = lg._bone_l(lg._flagger, "hand_r")
			print("LEGENDA kiihdytys lippu: tanko %.3f m kädestä" % hand.distance_to(lg._flag.position))
			_check(hand.distance_to(lg._flag.position) < 0.1, "Kiihdytys: lippu lipputytön kädessä")
		if st[0] == "ilme":
			var r: Node3D = lg._opp_rider
			var m: Node3D = rc._opp_model
			var worst := 0.0
			for lr in ["_l", "_r"]:
				var h: Vector3 = r.to_global(r.bone_position("hand" + lr))
				var side := signf(m.to_local(h).x)
				worst = maxf(worst, h.distance_to(m.to_global(Vector3(0.3 * side, 1.08, -0.46))))
			print("LEGENDA kiihdytys ilme: ajajan kädet kahvoista enintään %.3f m" % worst)
			_check(worst < 0.1, "Kiihdytys: ajajan kädet tangossa")
		if st[0] == "keulinta" or st[0] == "hurraus":
			var m: Node3D = rc._my_model
			var rear: Vector3 = m.position + m.transform.basis * lg.REAR
			var front: Vector3 = m.position + m.transform.basis * Vector3(0, 0.3, -0.58)
			var s: float = rc.DIST + 13.0 - lg.KEUL_V * lg._t
			var ground: float = lg._P(s, 0.3).y
			print("LEGENDA kiihdytys keulinta: takapyörä %.2f, etupyörän napa %.2f (tie %.2f)" % [rear.y, front.y, ground])
			_check(absf(rear.y - ground) < 0.08 and front.y - ground > 0.55, "Kiihdytys: keula pystyssä, takapyörä tiessä")
			var r: Node3D = lg._me_rider
			var hl: Vector3 = r.to_global(r.bone_position("hand_l"))
			var hd: Vector3 = r.to_global(r.bone_position("Head"))
			_check(hl.y > hd.y + 0.05, "Kiihdytys: nyrkki ilmassa")
			var cam: Camera3D = lg._cam
			var top: Vector2 = cam.unproject_position(hl + Vector3(0, 0.08, 0))
			var bot: Vector2 = cam.unproject_position(rc.to_global(rear))  # rear ja front kisan kehyksessä
			var fr: Vector2 = cam.unproject_position(rc.to_global(front))
			var vs: Vector2 = main.get_viewport().get_visible_rect().size
			print("LEGENDA kiihdytys keulinta kuvassa: korkeus %.0f px, keskikohta x %.0f / %.0f" % [bot.y - top.y, (fr.x + bot.x) / 2.0, vs.x])
			_check(bot.y - top.y >= 300.0 and absf((fr.x + bot.x) / 2.0 - vs.x / 2.0) < vs.x * 0.2, "Kiihdytys: keulinta iso ja keskellä")
		if st[0] == "tyonto":
			var p: Node3D = lg._pusher
			var m: Node3D = rc._opp_model
			var gl: Vector3 = m.to_global(lg.push_grips["_l"])
			var gr: Vector3 = m.to_global(lg.push_grips["_r"])
			var dl: float = p.to_global(p.bone_position("hand_l")).distance_to(gl)
			var dr: float = p.to_global(p.bone_position("hand_r")).distance_to(gr)
			print("LEGENDA kiihdytys työntö: kädet tangosta %.3f / %.3f m" % [dl, dr])
			_check(dl < 0.1 and dr < 0.1, "Kiihdytys: työntäjän kädet tangossa")
	for i in 3000:
		if main.state != "mopokisa":
			break
		await _frames(1)
	await _frames(5)
	print("LEGENDA kiihdytys jälkeen: tila %s, kerrat %d, viesti '%s'" % [main.state, int(main.endings.counts.get("kiihdytys", 0)), main._msg.text])
	_check(int(main.endings.counts.get("kiihdytys", 0)) == 1, "Kiihdytys: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Kiihdytys: päiväkirjarivi")
	await _frames(60)
	# Toinen kisa: pojat muistelevat, voitto ilman huipennusta.
	var vl: Node3D = main.mopo_trip.vaala
	main.walker_out.global_position = main.mopo_trip.to_global(vl.race_spot + Vector3(0, 0.5, 0)
		+ vl.doors.filter(func(d): return d.id == "kiihdytys")[0].out * 3.0)
	await _frames(15)
	main._on_vaala_door("kiihdytys")
	await _frames(10)
	var hello: String = main._talk_box._line
	print("LEGENDA kiihdytys toinen käynti: '%s'" % hello)
	_check(hello in main.MopoRace.LEG_MUISTO, "Kiihdytys: mopopojat muistelevat")
	await _shot(path, "muisto")
	main._talk_choose("kisa")
	await _frames(30)
	rc = main._race
	_check(rc != null and not rc.legend, "Kiihdytys: toinen kisa ilman legendaa")
	if rc == null:
		return
	_kiih_win(rc)
	var seen := false
	for i in 600:
		if main.state != "mopokisa":
			break
		if is_instance_valid(rc):
			for c in rc.get_children():
				if c is CanvasLayer and "race" in c:
					seen = true
		await _frames(1)
	_check(not seen, "Kiihdytys: toisella voitolla ei huipennusta")
	_check(int(main.endings.counts.get("kiihdytys", 0)) == 2, "Kiihdytys: toinen voitto laskettiin hiljaa")


func B_yaw(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


## Tanssit: tanssi Sinikan kanssa seuraintalon salissa, osumat pakotetaan ja biisi loppuun (tanssi_game.gd _leg_good).
func _tanssi_start() -> Node3D:
	main._start_tanssi("sinikka_seura")
	await _frames(20)
	var tgs: Array = main.kirppis_int.get_children().filter(func(c): return c is TanssiGame)
	if tgs.is_empty():
		return null
	var tg: Node3D = tgs.front()
	tg.frame_clock = true
	await _frames(30)  # kontaktiprofiilit (tanssiote) valmiiksi
	tg._hits = 200
	tg._misses = 0
	tg.seek(float(tg._song.end) - 0.1)
	return tg


func _tanssi_wait(tg: Node3D, phase: String, sec: float) -> bool:
	for i in 6000:
		if not is_instance_valid(tg) or tg._done:
			return false
		if tg._phase == phase and tg._leg_t >= sec:
			return true
		if tg._phase in tg.LEG and tg.LEG.find(tg._phase) > tg.LEG.find(phase):
			return false
		await _frames(1)
	return false


## Pisteen paikka kuvassa (0..1) tanssin kamerasta.
func _tanssi_sp(tg: Node3D, p: Vector3) -> Vector2:
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	return tg._cam.unproject_position(p) / vs


func _tanssit(path: String) -> void:
	main.endings.counts.erase("tanssit")
	if main.player == main.bike:
		main._toggle_mount()
	main.day = 6
	main.clock_min = 21 * 60 + 30
	main._enter_kirppis("tanssit")
	await _frames(30)
	var ki: Node3D = main.kirppis_int
	var tg := await _tanssi_start()
	_check(tg != null and tg.legend, "Tanssit: ensimmäinen tanssi, legenda odottaa")
	if tg == null:
		return
	var e0: float = (ki._lamps[0][0] as OmniLight3D).light_energy
	var head0 := 9.0  # parin pää seisten (valssissa)
	var shots := [["valssi", "valssi", 1.4], ["valssi2", "valssi", 4.0], ["taivutus", "taivutus", 0.6], ["taivutus2", "taivutus", 2.6],
		["valot", "valot", 1.4], ["valot2", "valot", 4.2], ["otsikko", "otsikko", 3.2]]
	for st: Array in shots:
		if not await _tanssi_wait(tg, st[1], st[2]):
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
			_check(false, "Tanssit: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var me: Node3D = tg._me
		var her: Node3D = tg._her
		if st[0] == "valssi2":
			var top := _tanssi_sp(tg, me.to_global(me.bone_position("Head")) + Vector3(0, 0.15, 0))
			var bot := _tanssi_sp(tg, me.global_position)
			var e: float = (ki._lamps[0][0] as OmniLight3D).light_energy
			head0 = her.to_global(her.bone_position("Head")).y - tg.global_position.y
			print("LEGENDA tanssit valssi: pari %.0f %% kuvan korkeudesta, lamppu %.2f / %.2f, kohdevalo %.1f" % [(bot.y - top.y) * 100.0, e, e0, tg._spot.light_energy])
			_check(bot.y - top.y > 0.5 and e < e0 * 0.3 and tg._spot.light_energy > 5.0, "Tanssit: valssissa pari iso ja valot himmeinä")
			_check(ki.hold_dancers, "Tanssit: taustaparit pysähtyivät")
		if st[0] == "taivutus2":
			var head: Vector3 = her.to_global(her.bone_position("Head"))
			var hand: Vector3 = me.to_global(me.bone_position("hand_r"))
			var blade: Vector3 = tg.dip_target()
			var hl: Vector3 = tg.dip_grip()
			var hr: Vector3 = her.to_global(her.bone_position("hand_r"))
			var floor_y: float = tg.global_position.y
			var feet := 9.0
			for c: Node3D in [me, her]:
				for f in ["foot_l", "foot_r", "ball_l", "ball_r"]:
					feet = minf(feet, c.to_global(c.bone_position(f)).y - floor_y)
			var deep := 0.0
			var worst := ""
			if not tg.prof.is_empty():
				for o: Array in Contact.overlap_pairs(me, tg.prof[me], her, tg.prof[her], 0.0):
					if float(o[2]) > deep:
						deep = float(o[2])
						worst = "%s/%s" % [o[0], o[1]]
			var axg: Vector3 = tg.global_basis * tg._dip_ax
			var sho: Vector3 = me.to_global(me.bone_position("upperarm_r"))
			var reach: float = sho.distance_to(me.to_global(me.bone_position("lowerarm_r"))) + me.to_global(me.bone_position("lowerarm_r")).distance_to(hand)
			print("LEGENDA tanssit taivutus: olka selästä %.2f m, käden ulottuma %.2f m" % [sho.distance_to(blade), reach])
			var sm := _tanssi_sp(tg, me.to_global(me.bone_position("Head")))
			var sh := _tanssi_sp(tg, head)
			print("LEGENDA tanssit taivutus: parin pää %.2f m, käsi selästä %.2f m, parin käsi olalta %.2f m, matalin jalka %.3f m, syvin päällekkäisyys %.3f m (%s), päät kuvassa %s %s" % [head.y - floor_y, hand.distance_to(blade), hl.distance_to(hr), feet, deep, worst, sm, sh])
			print("LEGENDA tanssit taivutus: parin pää seisten %.2f m" % head0)
			var arch: float = (head - her.to_global(her.bone_position("pelvis"))).dot(axg)
			print("LEGENDA tanssit taivutus: parin pää lantion takana %.2f m" % arch)
			_check(head.y - floor_y < head0 - 0.1 and arch > 0.2, "Tanssit: pari taipuu taakse")
			_check(hand.distance_to(blade) < 0.12, "Tanssit: pelaajan käsi parin vyötäröllä")
			_check(hl.distance_to(hr) < 0.12, "Tanssit: parin käsi pelaajan olalla")
			_check(feet > -0.02, "Tanssit: jalat eivät mene lattian läpi")
			_check(deep < 0.03 or tg.prof.is_empty(), "Tanssit: taivutuksessa ei läpimenoa")
			_check(sm.x > 0.05 and sm.x < 0.95 and sh.x > 0.05 and sh.x < 0.95 and sm.y > 0.12 and sh.y > 0.12, "Tanssit: kumpikin näkyy taivutuksessa")
		if st[0] == "valot2":
			var on := 0
			for l: Array in ki._lamps:
				if (l[0] as OmniLight3D).light_energy > e0 * 0.9:
					on += 1
			var j: Node3D = tg._juoru
			var js := _tanssi_sp(tg, j.to_global(j.bone_position("Head"))) if j != null else Vector2(-1, -1)
			print("LEGENDA tanssit valot: lamppuja päällä %d / %d, juoruaja %s kuvassa %s, repliikki '%s'" % [on, ki._lamps.size(), j.name if j != null else "-", js, tg._leg_bub.get(j, "")])
			_check(on == ki._lamps.size(), "Tanssit: kattolamput syttyivät")
			_check(j != null and js.x > 0.05 and js.x < 0.95 and js.y > 0.12 and js.y < 0.95 and String(tg._leg_bub.get(j, "")).contains("Anna-Liisa"), "Tanssit: Anna-Liisa näkyy ja puhuu")
	for i in 900:
		if not is_instance_valid(tg) or tg._done:
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA tanssit jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("tanssit", 0)), main._msg.text])
	_check(int(main.endings.counts.get("tanssit", 0)) == 1, "Tanssit: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Tanssit: päiväkirjarivi")
	_check(not ki.hold_dancers and absf((ki._lamps[0][0] as OmniLight3D).light_energy - e0) < 0.01, "Tanssit: sali palautui (parit ja valot)")
	await _frames(30)
	# Toinen käynti: Anna-Liisa muistelee, hyvä tanssi ilman huipennusta.
	main._on_kirppis_exited()
	await _frames(20)
	main._enter_kirppis("tanssit")
	await _frames(20)
	var al: int = ki.person_index("annaliisa")
	var said: String = (ki._bubbles[ki._people[al]] as Label3D).text
	print("LEGENDA tanssit toinen käynti: Anna-Liisa '%s'" % said)
	_check(said in TanssiGame.LEG_MUISTO, "Tanssit: Anna-Liisa muistelee")
	await _shot(path, "muisto")
	tg = await _tanssi_start()
	_check(tg != null and not tg.legend, "Tanssit: toinen tanssi ilman legendaa")
	if tg == null:
		return
	var seen := false
	for i in 300:
		if not is_instance_valid(tg) or tg._done:
			break
		if tg._phase in tg.LEG:
			seen = true
		await _frames(1)
	await _frames(10)
	_check(not seen, "Tanssit: toisella hyvällä tanssilla ei huipennusta")
	_check(int(main.endings.counts.get("tanssit", 0)) == 2, "Tanssit: toinen kerta laskettiin hiljaa")


## Haaste käyntiin Reipparin pihapöydässä; palauttaa piirakka_game.gd-solmun, kun alkulaskenta on ohi.
func _piir_start() -> Node3D:
	main._talk_who = "reippari"
	main._start_piirakka()
	await _frames(5)
	var gs: Array = main.world.get_children().filter(func(c): return c is PiirakkaGame)
	if gs.is_empty():
		return null
	var g: Node3D = gs.front()
	for i in 600:
		if g._t >= 0.2:
			break
		await _frames(1)
	return g


func _piir_legend(g: Node3D) -> CanvasLayer:
	for i in 400:
		if not is_instance_valid(g):
			return null
		for c in g.get_children():
			if c is PiirakkaLegenda:
				return c
		await _frames(1)
	return null


func _piir_wait(lg: CanvasLayer, phase: String, sec: float) -> bool:
	for i in 6000:
		if not is_instance_valid(lg) or lg.phase == "":
			return false
		if lg.phase == phase and lg._t >= sec:
			return true
		if lg.ORDER.find(lg.phase) > lg.ORDER.find(phase):
			return false
		await _frames(1)
	return false


## Kehyksen piste kuvan osuutena (0..1) legendan kamerasta.
func _piir_sp(lg: CanvasLayer, p_local: Vector3) -> Vector2:
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	return lg._cam.unproject_position(lg.game.to_global(p_local)) / vs


func _piir_in(v: Vector2) -> bool:
	return v.x > 0.04 and v.x < 0.96 and v.y > 0.1 and v.y < 0.96


func _piirakka(path: String) -> void:
	main.endings.counts.erase("piirakkakuningas")
	main._piirakka_record = 7
	main._piirakka_holder = "Juntti"
	if main.player == main.bike:
		main._toggle_mount()
	main.day = 3
	main.clock_min = 12 * 60
	main.money = 40.0
	main.walker_out.global_position = main.world.reippari_window + Vector3(0, 0.3, 0)
	await _frames(15)
	var g := await _piir_start()
	_check(g != null and g.legend and not g.recall, "Piirakka: ensimmäinen haaste, legenda odottaa")
	if g == null:
		return
	g._pies = 8
	g._finish("Aika loppu! 8 piirakkaa.")
	var lg := await _piir_legend(g)
	_check(lg != null, "Piirakka: legenda alkoi ennätyksestä")
	if lg == null:
		return
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["lasku", "lasku", 0.7], ["lasku2", "lasku", 2.8], ["paperit", "paperit", 0.5 + 2 * 0.42 + 0.21],
		["paperit2", "paperit", 0.5 + 8 * 0.42 + 0.9], ["mitta", "mitta", 2.2], ["mitta2", "mitta", 3.6], ["taulu", "taulu", 1.1],
		["taulu2", "taulu", 4.8], ["royhtays", "royhtays", 0.8], ["royhtays2", "royhtays", 2.4], ["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if not await _piir_wait(lg, st[1], st[2]):
			_check(false, "Piirakka: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var me: Node3D = lg._me
		var j: Node3D = lg.people.juntti
		var hand := func(c: Node3D, lr: String) -> Vector3: return lg.game.to_local(c.to_global(c.bone_position("hand" + lr)))
		var head := func(c: Node3D) -> Vector3: return lg.game.to_local(c.to_global(c.bone_position("Head")))
		match st[0]:
			"lasku2":
				var feet := 9.0
				for f in ["foot_l", "foot_r", "ball_l", "ball_r"]:
					feet = minf(feet, me.to_global(me.bone_position(f)).y - lg.game.global_position.y)
				var knee := maxf(lg.game.to_local(me.to_global(me.bone_position("calf_l"))).y, lg.game.to_local(me.to_global(me.bone_position("calf_r"))).y)
				var hb: Vector3 = hand.call(me, "_l")
				var belly: Vector3 = lg.game.to_local(me.to_global(me.bone_position("spine_01")))
				print("LEGENDA piirakka lasku: matalin jalka %.3f, polvi %.2f (pöytä %.2f), vasen käsi vatsasta %.2f m, kuningas kuvassa %s" % [feet, knee, lg.TABLE_Y, hb.distance_to(belly), _piir_sp(lg, head.call(me))])
				_check(feet > -0.02 and knee < lg.TABLE_Y - 0.06, "Piirakka: istuva kuningas ei mene lattian eikä pöydän läpi")
				_check(_piir_in(_piir_sp(lg, head.call(me))), "Piirakka: kuningas näkyy laskussa")
			"paperit":
				var i := 2
				var hr: Vector3 = hand.call(j, "_r")
				var span := (_piir_sp(lg, lg._paper_at(0)) - _piir_sp(lg, lg._paper_at(7))).length() * vs.x
				var shp: Vector3 = lg.game.to_local(j.to_global(j.bone_position("upperarm_r")))
				var elp: Vector3 = lg.game.to_local(j.to_global(j.bone_position("lowerarm_r")))
				print("LEGENDA piirakka paperit: olka %s, kyynärpää %s, käsi %s, kohde %s, käsivarsi %.2f+%.2f" % [shp, elp, hr, lg._paper_at(i) + Vector3(0, 0.035, 0), shp.distance_to(elp), elp.distance_to(hr)])
				print("LEGENDA piirakka paperit: käsi paperista %d %.2f m, paperirivistö %.0f px, Juntti kuvassa %s" % [i, hr.distance_to(lg._paper_at(i) + Vector3(0, 0.035, 0)), span, _piir_sp(lg, head.call(j))])
				var shw: Vector3 = lg.game.to_local(j.to_global(j.bone_position("upperarm_r")))
				var ang := rad_to_deg((hr - shw).angle_to(lg._paper_at(i) + Vector3(0, 0.03, 0) - shw))
				print("LEGENDA piirakka paperit: osoitus %.1f° paperista %d" % [ang, i])
				_check(ang < 10.0, "Piirakka: Juntti osoittaa laskettavaa paperia")
				_check(span > 180.0, "Piirakka: paperit isona keskellä")
				var jy: float = _piir_sp(lg, head.call(j)).y
				_check(_piir_in(_piir_sp(lg, head.call(j))) and jy > 0.25, "Piirakka: Juntti näkyy laskiessaan (kasvot kuplan alla)")
			"mitta", "mitta2":
				if st[0] == "mitta2":
					var js := _piir_sp(lg, head.call(j))
					var rs := _piir_sp(lg, head.call(lg.people.raija))
					print("LEGENDA piirakka mitta kahden kuva: Juntti %s, Raija %s" % [js, rs])
					_check(_piir_in(js) and _piir_in(rs), "Piirakka: Juntti ja Raija näkyvät mittauksessa")
					continue
				var pa: Vector2 = _piir_sp(lg, lg.PIE_AT + Vector3(0, 0.03, -0.114))
				var pb: Vector2 = _piir_sp(lg, lg.PIE_AT + Vector3(0, 0.03, 0.114))
				var pw := (pa - pb).length() * vs.x
				var cr: float = (hand.call(j, "_r") as Vector3).distance_to(lg._tape_case.position + Vector3(0, 0.035, 0))
				var hk: float = (hand.call(j, "_l") as Vector3).distance_to(lg._hook.position + Vector3(0, 0.04, 0))
				print("LEGENDA piirakka mitta: piirakka %.0f px, kotelo kädestä %.2f m, koukku sormesta %.2f m, Juntti %s, Raija %s" % [pw, cr, hk, _piir_sp(lg, head.call(j)), _piir_sp(lg, head.call(lg.people.raija))])
				_check(pw > 200.0 and _piir_in(pa) and _piir_in(pb), "Piirakka: vertailupiirakka isona kuvassa")
				_check(cr < 0.1 and hk < 0.1, "Piirakka: kädet mitassa")
			"taulu2":
				var bw := (_piir_sp(lg, lg.BOARD + Vector3(-0.53, 0, -0.03)) - _piir_sp(lg, lg.BOARD + Vector3(0.53, 0, -0.03))).length() * vs.x
				var tip: float = (hand.call(lg.people.raija, "_r") as Vector3).distance_to(lg._note.position)
				print("LEGENDA piirakka taulu: taulu %.0f px, lappu '%s', Raijan käsi lapusta %.2f m, Juntti %s" % [bw, lg._note_lab.text, tip, _piir_sp(lg, head.call(j))])
				_check(bw > 330.0 and _piir_in(_piir_sp(lg, lg.BOARD)), "Piirakka: ennätystaulu isona")
				_check(lg._note.visible and lg._note_lab.text.length() > 6 and tip < 0.45, "Piirakka: Raija kirjoittaa lappuun")
			"royhtays2":
				var d: float = (head.call(me) as Vector3).distance_to(head.call(j))
				var nose: float = (hand.call(j, "_l") as Vector3).distance_to(head.call(j))
				var chest: float = lg.game.to_local(me.to_global(me.bone_position("spine_03"))).distance_to(lg.game.to_local(j.to_global(j.bone_position("spine_03"))))
				print("LEGENDA piirakka röyhtäys: päät %.2f m, rinnat %.2f m, Juntin käsi päästä %.2f m, pilvi %d, kuvassa %s %s" % [d, chest, nose, lg._cloud.size(), _piir_sp(lg, head.call(me)), _piir_sp(lg, head.call(j))])
				_check(chest > 0.4 and lg._cloud.size() > 5, "Piirakka: röyhtäys ilman läpimenoa")
				_check(nose < 0.2, "Piirakka: Juntti peittää nenänsä")
				_check(_piir_in(_piir_sp(lg, head.call(me))) and _piir_in(_piir_sp(lg, head.call(j))), "Piirakka: kumpikin näkyy röyhtäyksessä")
			"otsikko":
				print("LEGENDA piirakka otsikko: kuningas %s, Juntti %s, taulu %s" % [_piir_sp(lg, head.call(me)), _piir_sp(lg, head.call(j)), _piir_sp(lg, lg.BOARD)])
				_check(_piir_in(_piir_sp(lg, head.call(me))) and _piir_in(_piir_sp(lg, lg.BOARD)), "Piirakka: kuningas ja taulu otsikossa")
	for i in 900:
		if not is_instance_valid(g):
			break
		await _frames(1)
	await _frames(10)
	var board: String = (main.world.reippari_record.find_children("*", "Label3D", true, false)[0] as Label3D).text
	print("LEGENDA piirakka jälkeen: kerrat %d, viesti '%s', taulu '%s'" % [int(main.endings.counts.get("piirakkakuningas", 0)), main._msg.text, board.replace("\n", " / ")])
	_check(int(main.endings.counts.get("piirakkakuningas", 0)) == 1, "Piirakka: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Piirakka: päiväkirjarivi")
	_check(board.contains("Järvikuja 1 8"), "Piirakka: taulussa uusi nimi")
	await _frames(30)
	# Toinen haaste: muisto alussa, ennätys ilman huipennusta.
	g = await _piir_start()
	_check(g != null and not g.legend and g.recall, "Piirakka: toinen haaste ilman legendaa")
	if g == null:
		return
	var said := ""
	for k in g._bubbles:
		said += (g._bubbles[k][0] as Label3D).text
	var muisto := PiirakkaLegenda.MUISTO.map(func(m): return m[1])
	print("LEGENDA piirakka toinen haaste: muisto '%s'" % said)
	_check(said in muisto, "Piirakka: Juntti tai Raija muistelee")
	await _shot(path, "muisto")
	g._pies = 9
	g._finish("Aika loppu! 9 piirakkaa.")
	var seen := false
	for i in 400:
		if not is_instance_valid(g):
			break
		for c in g.get_children():
			if c is PiirakkaLegenda:
				seen = true
		await _frames(1)
	await _frames(10)
	print("LEGENDA piirakka toinen ennätys: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("piirakkakuningas", 0)), main._msg.text])
	_check(not seen, "Piirakka: toisella ennätyksellä ei huipennusta")
	_check(int(main.endings.counts.get("piirakkakuningas", 0)) == 2 and main._msg.text.contains("UUSI ENNÄTYS"), "Piirakka: toinen ennätys laskettiin hiljaa")
	main._piirakka_record = 7
	main._piirakka_holder = "Juntti"
	main._reippari_update()
