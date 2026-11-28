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
## sahkopyora_eka: sähköpyörän viimeinen liitos autotallissa (main.gd _start_ebike_game) -> ensimmäinen koeajo
##   (sahkopyora_legenda.gd): kuvat nosturiovesta ja naapureista, kaasukahvasta ja kipinästä, keulan noususta,
##   Järvikujan ajosta (Sinikka vilkuttaa), paluusta (Pekka ja Arto osoittavat osiaan) ja otsikosta; pyörän koko ja
##   paikka kuvassa, keula, osoitukset ja teipinpätkä mitataan. Lopuksi pelaaja pyörän selässä tallin edessä,
##   naapurit palaavat ja hetki päiväkirjaan. Pyörä kasataan vain kerran, joten toista kertaa ei ole: Pekka tai Arto
##   muistelee koeajoa jutellessa.
## porron_kyltti_eka: Pörrön muistolaudan maalaus valmis (muistokyltti_game.gd) -> lehdon hetki (porro_legenda.gd):
##   kuvat poikien tulosta, pikkuveljen voikukasta, kivien asettamisesta yksi kerrallaan, "Setä on ihan ok" -hetkestä
##   ja otsikosta; kyltin ja hahmojen paikka kuvassa, kädet kiven laskussa ja kivien paikat mitataan. Lopuksi kivet ja
##   kukka jäävät tolpan juurelle, oikeat pojat palaavat ja hetki päiväkirjaan. Tehtävä tehdään vain kerran: pojat
##   muistelevat ("Mitäs Pörrön kyltille kuuluu?").
## aarnivalkea_eka: Lapinraunion hopeat ensimmäistä kertaa Saloisten Pirttiin (main.gd _aarni_museum) -> Pirtin pihan
##   hetki (aarnivalkea_legenda.gd): kuvat kontista ja pöytäkirjasta, kannen nostosta ja viimeisestä sinisestä liekistä
##   (lehahtaa ja sammuu), hätkähdyksestä, hopeista liinalla ja taalerin välähdyksestä, Hilkasta ja epäilijöistä sekä
##   otsikosta; kontin, liekin, hopeiden ja hahmojen paikka kuvassa mitataan. Lopuksi oikea pelaaja palaa ja hetki
##   päiväkirjaan. Hopeat viedään vain kerran: Hilkka muistelee ("Muistatko, kun aarnivalkea sammui Pirtin pihalla?").
## kertun_rauta_eka: Kertunkankaan kirves Saloisten Pirttiin (ei vielä hetkeä, tehtävä "näytä lehtijuttu") -> lehti
##   kodalle Raimolle ja Veikolle (kertun_legenda.gd): kuvat sisääntulosta ja lehden ojennuksesta, Raimon lukemisesta ja
##   etusivusta ilmassa, Veikon "Perkele" ja kiroilukyltistä, kaljakassista ja kilistyksestä, leikkeestä seinällä ja
##   otsikosta; lehden koko kuvassa, kädet (ojennus, lehti, tölkit, kilistys, osoitus) ja hahmot mitataan. Lopuksi
##   Veikon kaljat, leike jää seinälle, oikeat Raimo ja Veikko palaavat ja hetki päiväkirjaan. Muistelu kodan jutuissa.
## tekojarven_ukko_eka: Tekojärven Ukko ensimmäistä kertaa Saloisten Pirttiin (main.gd _ukko_museum) -> Pirtin pihan
##   hetki (tekojarvi_legenda.gd): kuvat kolmijalasta ja heiluvasta Ukosta, puntarin taulusta (viisari asettuu 18,4:ään),
##   uistimista kyljessä, Taunon tulosta ja kosketuksesta isän lusikkaan, kyyneleestä, lehtikuvasta ja otsikosta; Ukon
##   pituus ja paikka kuvassa, taulun koko, Taunon käsi lusikalla, kyynel ja kädet hauen alla mitataan. Lopuksi
##   oikea pelaaja palaa, hetki päiväkirjaan ja Taunolle uusi kysymys punnituksesta.

const Main := preload("res://scripts/main.gd")
const Kuva := preload("res://tools/testit/kuva.gd")
const TanssiGame := preload("res://scripts/tanssi_game.gd")
const Contact := preload("res://scripts/contact.gd")
const PiirakkaGame := preload("res://scripts/piirakka_game.gd")
const PiirakkaLegenda := preload("res://scripts/piirakka_legenda.gd")
const SahkopyoraLegenda := preload("res://scripts/sahkopyora_legenda.gd")
const EBikeGame := preload("res://scripts/ebike_game.gd")
const PorroLegenda := preload("res://scripts/porro_legenda.gd")
const Terrain := preload("res://scripts/terrain.gd")
const MuistokylttiGame := preload("res://scripts/muistokyltti_game.gd")
const AarnivalkeaLegenda := preload("res://scripts/aarnivalkea_legenda.gd")
const KertunLegenda := preload("res://scripts/kertun_legenda.gd")
const TekojarviLegenda := preload("res://scripts/tekojarvi_legenda.gd")

const KOHTAUKSET := ["mokki_paapeli", "mokki_savusauna_eka", "pentti_eka", "tuppi_eka", "lettu_eka", "loyly_eka", "disko_eka", "karaoke_eka",
	"kesaheila_eka", "lava_eka", "karaoke_baari_eka", "kiihdytys_eka", "tanssit_eka", "piirakka_eka", "sahkopyora_eka", "porron_kyltti_eka",
	"aarnivalkea_eka", "kertun_rauta_eka", "tekojarven_ukko_eka"]

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
		"sahkopyora_eka":
			await _sahkopyora(path)
		"porron_kyltti_eka":
			await _porro(path)
		"aarnivalkea_eka":
			await _aarni(path)
		"kertun_rauta_eka":
			await _kerttu(path)
		"tekojarven_ukko_eka":
			await _ukko(path)
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



func _sp_wait(lg: CanvasLayer, phase: String, sec: float) -> bool:
	for i in 6000:
		if not is_instance_valid(lg) or lg.phase == "":
			return false
		if lg.phase == phase and lg._t >= sec:
			return true
		if lg.ORDER.find(lg.phase) > lg.ORDER.find(phase):
			return false
		await _frames(1)
	return false


func _sp_sp(lg: CanvasLayer, p: Vector3) -> Vector2:
	return lg._cam.unproject_position(p) / main.get_viewport().get_visible_rect().size


func _sahkopyora(path: String) -> void:
	main.endings.counts.erase("sahkopyora")
	if main.player == main.bike:
		main._toggle_mount()
	main.day = 3
	main.clock_min = 13 * 60
	var eb = main.ebike
	eb.started = true
	eb.board_taken = true
	for k in eb.PARTS:
		eb.parts[k] = true
	eb.joints = {"moottori": "ruuvi", "akku": "teippi", "ohjain": "nippu", "kaasu": "ruuvi"}
	eb.loose = {}
	eb.shorted = false
	eb.battery = 0.86
	eb.supplies.sahkoteippi = 2
	main.bike.set_ebike({"joints": eb.joints, "loose": eb.loose})
	main.walker_out.global_position = main.world.garage_door + main.world.garage_out * 1.0 + Vector3(0, 0.3, 0)
	await _frames(15)
	main._store_bike(true)
	main._enter_garage()
	await _frames(15)
	var vis_before := [main.pekka.visible, main.arto.visible, main.sinikka.visible]
	main._start_ebike_game(["johdot"])
	await _frames(5)
	var gs: Array = main.get_children().filter(func(c): return c is EBikeGame)
	_check(not gs.is_empty(), "Sähköpyörä: kasaus auki")
	if gs.is_empty():
		return
	var g: CanvasLayer = gs.front()
	g.finished.emit({"johdot": "sahkoteippi"})
	g.queue_free()
	await _frames(3)
	var ls: Array = main.get_children().filter(func(c): return c is SahkopyoraLegenda)
	_check(not ls.is_empty() and main.ebike.built(), "Sähköpyörä: koeajo alkoi viimeisestä liitoksesta")
	if ls.is_empty():
		return
	var lg: CanvasLayer = ls.front()
	_check(int(main.endings.counts.get("sahkopyora", 0)) == 0, "Sähköpyörä: hetki kirjataan vasta lopuksi")
	_check(not main.pekka.visible and not main.arto.visible and not main.walker_out.visible, "Sähköpyörä: oikeat naapurit ja jalan kulkija piilossa")
	var near: Array = []
	for c in main.find_children("*", "Node3D", true, false):
		if c.has_method("bone_position") and c.is_visible_in_tree() and (c as Node3D).global_position.distance_to(main.world.garage_door) < 40.0:
			near.append("%s %.0f m" % [c.get_parent().name + "/" + c.name, (c as Node3D).global_position.distance_to(main.world.garage_door)])
	print("LEGENDA sähköpyörä hahmot lähellä: ", near)
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var bk = main.bike
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var shots := [["ovi", "ovi", 1.0], ["ovi2", "ovi", 3.6], ["kaasu", "kaasu", 1.4], ["kaasu2", "kaasu", 2.45],
		["lahto", "lahto", 0.45], ["lahto2", "lahto", 1.6], ["ajo", "ajo", 1.2], ["ajo2", "ajo", 2.6],
		["paluu", "paluu", 2.5], ["paluu2", "paluu", 4.4], ["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Sähköpyörä: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var top: Vector2 = _sp_sp(lg, bk.to_global(Vector3(0, 1.85, 0)))
		var bot: Vector2 = _sp_sp(lg, bk.to_global(Vector3(0, 0.0, 0)))
		var fw: Vector2 = _sp_sp(lg, bk.to_global(Vector3(0, 0.35, -0.9)))
		var rw: Vector2 = _sp_sp(lg, bk.to_global(Vector3(0, 0.35, 0.9)))
		var size := maxf((top - bot).length() * vs.y, (fw - rw).length() * vs.x)
		var mid := (top + bot) / 2.0
		print("LEGENDA sähköpyörä %s: pyörä kuvassa %s, koko %.0f px, Pekka %s, Arto %s, Sinikka %s" % [st[0], mid, size,
			_sp_sp(lg, head.call(lg.pekka)), _sp_sp(lg, head.call(lg.arto)), _sp_sp(lg, head.call(lg.sinikka))])
		match st[0]:
			"ovi2":
				_check(inside.call(mid) and inside.call(_sp_sp(lg, head.call(lg.pekka))) and inside.call(_sp_sp(lg, head.call(lg.arto))),
					"Sähköpyörä: pyörä ja naapurit ovella kuvassa")
			"kaasu", "kaasu2":
				var gp: Vector2 = _sp_sp(lg, bk.to_global(lg.GRIP))
				var bat: Vector2 = _sp_sp(lg, bk.to_global(Vector3(0, 0.88, 0.5)))
				var ctl: Vector2 = _sp_sp(lg, bk.to_global(lg.CTRL))
				print("LEGENDA sähköpyörä kaasu: kahva %s, akku %s, ohjain %s, kuski %s" % [gp, bat, ctl, _sp_sp(lg, head.call(bk._rider))])
				_check(inside.call(gp) and inside.call(bat) and inside.call(ctl), "Sähköpyörä: kahva, akku ja ohjain lähikuvassa")
				var rr: Node3D = bk._rider
				var palm: Vector3 = (rr.to_global(rr.bone_position("hand_r")) + rr.to_global(rr.bone_position("index_01_r"))) / 2.0
				var gd: float = palm.distance_to(bk._visual.to_global(lg.GRIP))
				print("LEGENDA sähköpyörä kaasukäsi kahvasta %.3f m (käsi %s, sormi %s, kahva %s, korjaus %s, olka %s)" % [gd, rr.bone_position("hand_r"), rr.bone_position("index_01_r"),
					rr.to_local(bk._visual.to_global(lg.GRIP)), lg._grip_off, rr.bone_position("upperarm_r")])
				_check(gd < 0.05, "Sähköpyörä: kaasukäsi kahvassa")
				if st[0] == "kaasu2":
					_check(lg._once.has("spark"), "Sähköpyörä: kipinä")
			"lahto":
				print("LEGENDA sähköpyörä keula %.2f rad" % lg.pitch)
				_check(lg.pitch > 0.25 and inside.call(mid), "Sähköpyörä: keula nousee kuvassa")
			"ajo", "ajo2":
				_check(inside.call(mid) and size > 250.0, "Sähköpyörä: ajossa pyörä isona kuvassa")
				if not lg._tape.is_empty():
					var tz: float = lg._tape[5].position.z - lg._tape[0].position.z
					var ty: float = lg._tape[5].position.y - lg._tape[0].position.y
					print("LEGENDA sähköpyörä teippi: taakse %.2f, alas %.2f" % [tz, ty])
					_check(tz > 0.25 and ty > -0.15, "Sähköpyörä: teipinpätkä liehuu taaksepäin")
				if st[0] == "ajo2":
					_check(inside.call(_sp_sp(lg, head.call(lg.sinikka))) and lg._bub.has(lg.sinikka), "Sähköpyörä: Sinikka vilkuttaa kuvassa")
			"paluu2":
				var ang := func(c: Node3D, at: Vector3) -> float:
					var sh: Vector3 = c.to_global(c.bone_position("upperarm_r"))
					var hd: Vector3 = c.to_global(c.bone_position("hand_r"))
					return rad_to_deg((hd - sh).angle_to(at - sh))
				var pa: float = ang.call(lg.pekka, bk.to_global(Vector3(0, 0.88, 0.5)))
				var aa: float = ang.call(lg.arto, bk.to_global(lg.CTRL))
				var gap := minf(lg.pekka.global_position.distance_to(bk.global_position), lg.arto.global_position.distance_to(bk.global_position))
				print("LEGENDA sähköpyörä osoitus: Pekka %.1f°, Arto %.1f°, lähin naapuri pyörästä %.2f m" % [pa, aa, gap])
				_check(pa < 15.0 and aa < 15.0, "Sähköpyörä: Pekka osoittaa akkua, Arto johtoja")
				_check(gap > 0.7, "Sähköpyörä: naapurit eivät ole pyörän sisällä")
				_check(inside.call(mid) and inside.call(_sp_sp(lg, head.call(lg.pekka))) and inside.call(_sp_sp(lg, head.call(lg.arto))),
					"Sähköpyörä: paluussa kaikki kuvassa")
			"otsikko":
				_check(inside.call(mid) and size > 160.0, "Sähköpyörä: pyöräilijä otsikossa")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA sähköpyörä jälkeen: kerrat %d, viesti '%s', tila %s, pyörällä %s" % [int(main.endings.counts.get("sahkopyora", 0)),
		main._msg.text, main.state, main.player == main.bike])
	_check(int(main.endings.counts.get("sahkopyora", 0)) == 1, "Sähköpyörä: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Sähköpyörä: päiväkirjarivi")
	_check(main.state != "in_garage" and main.player == main.bike and main.bike.visible, "Sähköpyörä: pelaaja pyörän selässä tallin edessä")
	_check([main.pekka.visible, main.arto.visible, main.sinikka.visible] == vis_before and not main.walker_out.visible,
		"Sähköpyörä: naapurit palasivat ennalleen, jalan kulkija piilossa")
	await _frames(20)
	await _shot(path, "jalkeen")
	# Muisto: Pekka tai Arto muistelee jutellessa (30 %), kokeillaan kunnes osuu.
	var said := ""
	var muisto: Array = SahkopyoraLegenda.MUISTO.pekka + SahkopyoraLegenda.MUISTO.arto
	main.story.step = "valmis" if main.story.step == "tehtavat" else main.story.step
	for who in ["pekka", "arto"]:
		main._talk_who = who
		for i in 60:
			var l: String = main._talk_chat_line()
			if l in muisto:
				said = l
				break
		if said != "":
			break
	print("LEGENDA sähköpyörä muisto: '%s'" % said)
	_check(said != "", "Sähköpyörä: naapuri muistelee koeajoa")


func _porro(path: String) -> void:
	main.endings.counts.erase("porron_kyltti")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 4
	main.clock_min = 18 * 60 + 30
	main._spawn_boys()
	main._ball_quest = "done"
	main.lemmikki.stage = "kerrottu"
	main.walker_out.global_position = main.world.lehto_pos + Vector3(0, 0.3, 0)
	await _frames(15)
	var post: Node3D = main.world.lehto_plate
	var G: Node3D = post.get_parent()
	var hs := []
	for q in [Vector3(3.6, 0, -0.6), Vector3(3.6, 0, -2.0), Vector3(2.0, 0, -2.7), Vector3(0, 0, -3.2), Vector3(-3.6, 0, -0.6), Vector3(0, 0, 3.0)]:
		var w: Vector3 = G.to_global(q)
		hs.append("%.2f" % (Terrain.h(w.x, w.z) - post.global_position.y))
	print("LEGENDA Pörrö: tolppa y %.2f, maasto - tolppa: %s" % [post.global_position.y, hs])
	main._start_muistokyltti()
	await _frames(5)
	var gs: Array = main.get_children().filter(func(c): return c is MuistokylttiGame)
	_check(not gs.is_empty(), "Pörrö: minipeli auki")
	if gs.is_empty():
		return
	gs.front()._end(true)
	for i in 60:
		if not main.get_children().filter(func(c): return c is PorroLegenda).is_empty():
			break
		await _frames(1)
	var ls: Array = main.get_children().filter(func(c): return c is PorroLegenda)
	_check(not ls.is_empty(), "Pörrö: lehdon hetki alkoi laudan valmistuttua")
	if ls.is_empty():
		return
	var lg: CanvasLayer = ls.front()
	_check(int(main.endings.counts.get("porron_kyltti", 0)) == 0, "Pörrö: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible and (not is_instance_valid(main.boys) or not main.boys.visible), "Pörrö: oikeat pojat ja jalan kulkija piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var plate_at := func() -> Vector3: return post.to_global(Vector3(0, 0.92, 0))
	var shots := [["lehto", "lehto", 1.2], ["lehto2", "lehto", 4.2], ["kukka", "kukka", 1.6], ["kukka2", "kukka", 3.6],
		["kivet", "kivet", 1.6], ["kivet2", "kivet", 3.65], ["kivet3", "kivet", 5.7], ["seta", "seta", 1.6], ["seta2", "seta", 4.0],
		["otsikko", "otsikko", 3.2]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Pörrö: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var pl: Vector2 = _sp_sp(lg, plate_at.call())
		var pl2: Vector2 = _sp_sp(lg, post.to_global(Vector3(0.15, 0.92, 0)))
		var heads := [lg.me, lg.veli, lg.pojat[0], lg.pojat[1], lg.pojat[2]].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Pörrö %s: kyltti %s (leveys %.0f px), päät minä/veli/p0/p1/p2 %s" % [st[0], pl, (pl2 - pl).length() * vs.x * 2.0, heads])
		_check(inside.call(pl), "Pörrö: kyltti kuvassa (%s)" % st[0])
		match st[0]:
			"lehto2":
				_check(heads.all(func(h): return inside.call(h)), "Pörrö: pojat, pikkuveli ja pelaaja kuvassa")
			"kukka", "kukka2":
				_check(inside.call(heads[1]), "Pörrö: pikkuveljen kasvot kuvassa")
				_check(inside.call(_sp_sp(lg, lg.flower.global_position)), "Pörrö: voikukka kuvassa")
				if st[0] == "kukka":
					var d: float = lg._hand(lg.veli).distance_to(lg.flower.global_position)
					print("LEGENDA Pörrö kukka kädessä %.3f m" % d)
				else:
					var fl: Vector3 = post.to_global(Vector3(lg.FLOWER.x, 0, lg.FLOWER.y))
					_check(lg.flower.global_position.distance_to(fl) < 0.05, "Pörrö: voikukka kyltin juurella")
			"kivet", "kivet2", "kivet3":
				var who: int = ["kivet", "kivet2", "kivet3"].find(st[0])
				_check(inside.call(heads[2 + who]), "Pörrö: kivenlaskija %d kuvassa" % who)
			"seta":
				_check(inside.call(heads[0]) and inside.call(heads[2]), "Pörrö: pelaaja ja isoveli kuvassa")
				_check(lg._bub.has(lg.pojat[0]), "Pörrö: Setä on ihan ok")
			"seta2":
				_check(inside.call(heads[1]) and lg._bub.has(lg.veli), "Pörrö: pikkuveli kiittää kuvassa")
	# Kivet laskettiin kädestä ja ne ovat juurella.
	for i in 3:
		var d: float = lg.placed.get(lg.stones[i], 9.0)
		var at: Vector3 = post.to_global(Vector3(lg.STONES[i].x, 0, lg.STONES[i].y))
		print("LEGENDA Pörrö kivi %d: käsi laskiessa %.3f m, paikasta %.3f m" % [i, d, lg.stones[i].global_position.distance_to(at)])
		_check(d < 0.12, "Pörrö: kivi %d laskettiin kädestä" % i)
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	var muisto: Array = post.get_children().filter(func(c): return c.has_meta("porro_muisto") and c.visible)
	print("LEGENDA Pörrö jälkeen: kerrat %d, viesti '%s', kivet+kukka %d, pojat näkyvät %s, rauhallisia %s" % [int(main.endings.counts.get("porron_kyltti", 0)),
		main._msg.text, muisto.size(), is_instance_valid(main.boys) and main.boys.visible, main.boys.calm if is_instance_valid(main.boys) else false])
	_check(int(main.endings.counts.get("porron_kyltti", 0)) == 1, "Pörrö: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Pörrö: päiväkirjarivi")
	_check(muisto.size() == 4 and post.visible, "Pörrö: kivet ja voikukka jäivät tolpan juurelle")
	_check(main.walker_out.visible and main.player.controls_enabled, "Pörrö: pelaaja ohjaa taas")
	# Pysyvä juuri kuvaan.
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.current = true
	cam.fov = 40.0
	cam.look_at_from_position(post.to_global(Vector3(0.6, 0.9, -1.8)), post.to_global(Vector3(0, 0.45, -0.1)))
	await _frames(10)
	await _shot(path, "jalkeen")
	cam.look_at_from_position(post.to_global(Vector3(1.6, 0.15, -0.3)), post.to_global(Vector3(0, 0.1, -0.2)))
	await _frames(5)
	await _shot(path, "juuri_sivu")
	cam.queue_free()
	main.walker_out.activate_camera()
	# Muisto: pojat kertovat kyltistä.
	var o: Array = main._talk_options("pojat").map(func(x): return x.id)
	_check("lemmikki_porro" in o, "Pörrö: pojille uusi kysymys kyltistä")
	main._talk_who = "pojat"
	main._talk_lemmikki("lemmikki_porro")
	await _frames(3)
	print("LEGENDA Pörrö muisto: vaihtoehdot %s" % [o])


func _aarni(path: String) -> void:
	main.endings.counts.erase("aarnivalkea")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 5
	main.clock_min = 12 * 60
	var a = main.aarni
	a.heard = true
	a.sulo = true
	a.poytakirja = true
	a.liekki = true
	a.found = true
	a.choice = ""
	var m0: float = main.money
	main.walker_out.global_position = main.world.museum_door + Vector3(0, 0.3, 0)
	await _frames(15)
	print("LEGENDA Aarni: vihje '%s'" % main._hint.text)
	await main.get_tree().process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is AarnivalkeaLegenda)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Aarni: Pirtin pihan hetki alkoi hopeiden luovutuksesta")
	if lg == null:
		return
	_check(a.choice == "museo" and main.money > m0, "Aarni: hopeat museoon ja löytöpalkkio")
	_check(int(main.endings.counts.get("aarnivalkea", 0)) == 0, "Aarni: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible, "Aarni: oikea pelaaja piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["kontti", "kontti", 1.4], ["kontti2", "kontti", 4.0], ["kansi", "kansi", 1.3], ["liekki", "kansi", 1.8],
		["liekki2", "kansi", 3.0], ["sammui", "kansi", 4.6], ["hopeat", "hopeat", 1.6], ["valahdys", "hopeat", 2.85],
		["hopeat2", "hopeat", 4.2], ["hilkka", "hilkka", 1.6], ["hilkka2", "hilkka", 3.6], ["arto", "hilkka", 5.0], ["hilkka3", "hilkka", 6.0],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.2]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Aarni: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var kp: Vector2 = _sp_sp(lg, lg.kontti.global_position + Vector3(0, 0.13, 0))
		var kw: Vector2 = _sp_sp(lg, lg.kontti.to_global(Vector3(0.17, 0.13, 0)))
		var heads := [lg.me, lg.opas, lg.hilkka, lg.arto, lg.annaliisa, lg.pekka].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Aarni %s: kontti %s (puolileveys %.0f px), päät minä/opas/hilkka/arto/al/pekka %s, liekki %.2f" % [st[0], kp,
			(kw - kp).length() * vs.x, heads, lg.flame.scale.y if lg.flame.visible else 0.0])
		if not st[0] in ["hopeat", "valahdys", "hopeat2"]:  # liinan lähikuvassa ja taalerin puolilähikuvassa kontti saa jäädä pois
			_check(inside.call(kp), "Aarni: kontti kuvassa (%s)" % st[0])
		match st[0]:
			"kontti2":
				_check(inside.call(heads[0]) and inside.call(heads[1]), "Aarni: opas ja pelaaja kuvassa")
				_check(lg._bub.has(lg.opas), "Aarni: opas lukee pöytäkirjaa")
			"kansi":
				var lp: Vector3 = lg._top(lg.KONTTI_AT.x, lg.KONTTI_AT.y + 0.1, 0.27)
				var hd: float = lg._hand(lg.opas).distance_to(lp)
				print("LEGENDA Aarni kansi: käsi kannesta %.3f m" % hd)
				_check(hd < 0.12, "Aarni: oppaan käsi kannella")
			"liekki":
				_check(lg.flame.visible and lg.flame.scale.y > 0.6, "Aarni: liekki lehahti kontista")
				_check(inside.call(_sp_sp(lg, lg.flame.global_position + Vector3(0, 0.35, 0))), "Aarni: liekki kuvassa")
				_check(inside.call(heads[1]), "Aarni: oppaan kasvot kuvassa")
			"sammui":
				_check(not lg.flame.visible or lg.flame.scale.y < 0.05, "Aarni: liekki sammui")
			"valahdys":
				_check(lg.held_coin.visible and inside.call(_sp_sp(lg, lg.held_coin.global_position)), "Aarni: taaleri valoa vasten kuvassa")
			"hopeat":
				var cp: Vector2 = _sp_sp(lg, lg.coins[0].global_position)
				var cp2: Vector2 = _sp_sp(lg, lg.coins[0].global_position + lg._G.global_basis.x * 0.04)
				print("LEGENDA Aarni taaleri leveys %.0f px" % ((cp2 - cp).length() * vs.x))
				_check(inside.call(cp) and (cp2 - cp).length() * vs.x > 40.0, "Aarni: hopeat näkyvät isona")
			"hopeat2":
				_check(lg._bub.get(lg.opas, "") == "Juuri nämä!" and inside.call(heads[1]), "Aarni: Juuri nämä! (oppaan kasvot kuvassa)")
			"hilkka2":
				_check(inside.call(heads[0]) and inside.call(heads[1]) and inside.call(heads[2]), "Aarni: Hilkka, opas ja pelaaja kuvassa")
				_check(lg._bub.has(lg.hilkka), "Aarni: Hilkka: Mitäs minä sanoin")
			"hilkka3", "otsikko2":
				_check(heads.all(func(h): return inside.call(h)), "Aarni: kaikki hahmot kuvassa (%s)" % st[0])
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Aarni jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("aarnivalkea", 0)), main._msg.text])
	_check(int(main.endings.counts.get("aarnivalkea", 0)) == 1, "Aarni: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Aarni: päiväkirjarivi")
	_check(main.walker_out.visible and main.player.controls_enabled, "Aarni: pelaaja ohjaa taas")
	# Muisto: Hilkka kertoo (kirppiksellä).
	main.kirppis_int.mode = "kirppis"
	var o: Array = main._talk_options("hilkka").map(func(x): return x.id)
	_check("aarni_muisto" in o, "Aarni: Hilkalle kysymys Pirtin pihasta")
	main._talk_who = "hilkka"
	main._talk_kirppis("aarni_muisto")
	await _frames(3)
	print("LEGENDA Aarni muisto: vaihtoehdot %s" % [o])


func _kerttu(path: String) -> void:
	main.endings.counts.erase("kertun_rauta")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 6
	main.clock_min = 17 * 60
	var k = main.kertun
	k.heard = true
	k.taulu = true
	k.spotted = true
	k.malmi = true
	k.malmi_known = true
	k.kuona = true
	k.found = true
	k.choice = ""
	k.kiitetty = false
	main._kertun_sync()
	var kota: Node3D = main.world.kota
	_check(kota.clipping == null or not kota.clipping.visible, "Kerttu: ei leikettä seinällä ennen hetkeä")
	# Pirtti: kirves museoon, hetki ei vielä.
	var m0: float = main.money
	main.walker_out.global_position = main.world.museum_door + Vector3(0, 0.3, 0)
	await _frames(15)
	print("LEGENDA Kerttu: Pirtti '%s'" % main._hint.text)
	await main.get_tree().process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(3)
	_check(k.choice == "museo" and main.money > m0, "Kerttu: kirves museoon ja löytöpalkkio")
	_check(int(main.endings.counts.get("kertun_rauta", 0)) == 0, "Kerttu: hetki ei vielä Pirtissä")
	var tasks: Array = main._kertun_tasks()
	print("LEGENDA Kerttu: viesti '%s', tehtävät %s" % [main._msg.text.right(60), tasks])
	_check(not tasks.is_empty() and str(tasks[0][0]).contains("lehtijuttu"), "Kerttu: tehtävä näyttää lehti kodalla")
	# Kota: tuli ei pala, lehti silti näytettävissä.
	kota.set_fire(false)
	var b0: int = main.beers
	main.walker_out.global_position = kota.global_position + kota.global_basis * Vector3(0.0, 0.3, -1.6)
	await _frames(15)
	print("LEGENDA Kerttu: kota '%s'" % main._hint.text)
	_check(main._hint.text.contains("lehtijuttu"), "Kerttu: kodalla vihje lehtijutusta")
	await main.get_tree().process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is KertunLegenda)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Kerttu: kodan hetki alkoi lehdestä")
	if lg == null:
		return
	_check(not main.walker_out.visible and not kota.raimo.visible and not kota.veikko.visible, "Kerttu: oikeat hahmot piilossa")
	_check(kota.fire_on, "Kerttu: tuli palaa hetken ajan")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.03 and v.x < 0.97 and v.y > 0.06 and v.y < 0.97
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["sisaan", "lehti", 1.6], ["ojennus", "lehti", 4.05], ["otti", "lehti", 5.0], ["lukee", "raimo", 1.6], ["nousee", "raimo", 2.8],
		["etusivu", "raimo", 4.6], ["veikko", "veikko", 1.8], ["perkele", "veikko", 3.6], ["kyltti", "veikko", 5.8], ["kassi", "kaljat", 1.5],
		["kilistys0", "kaljat", 3.4], ["kilistys", "kaljat", 4.5], ["leike", "leike", 0.9], ["leike2", "leike", 3.2], ["leike3", "leike", 5.0],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.4]]
	var paper_px := func() -> float:
		var c0: Vector2 = _sp_sp(lg, lg.paper.to_global(Vector3(-0.18, 0, 0)))
		var c1: Vector2 = _sp_sp(lg, lg.paper.to_global(Vector3(0.18, 0, 0)))
		return (c1 - c0).length() * vs.x
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Kerttu: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var heads := [lg.me, lg.raimo, lg.veikko].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Kerttu %s: päät minä/raimo/veikko %s, lehti %.0f px %s" % [st[0], heads, paper_px.call(), _sp_sp(lg, lg.paper.global_position)])
		match st[0]:
			"sisaan":
				_check(inside.call(heads[1]) and inside.call(heads[2]), "Kerttu: Raimo ja Veikko kuvassa")
				_check(inside.call(_sp_sp(lg, kota.to_global(Vector3(0, 0.9, 0)))), "Kerttu: tuli kuvassa")
			"ojennus":
				var ho: Vector3 = lg._K(lerpf(lg.P_GIVE.x, lg.S_R.x, 0.5), 1.02, lerpf(lg.P_GIVE.y, lg.S_R.y, 0.5))
				var gap: float = lg._hand(lg.me, lg._near_side(lg.me, ho)).distance_to(lg._hand(lg.raimo, lg._near_side(lg.raimo, ho)))
				print("LEGENDA Kerttu ojennus: kädet %.3f m" % gap)
				_check(gap < 0.2, "Kerttu: lehti kädestä käteen")
			"lukee":
				_check(inside.call(heads[1]), "Kerttu: Raimon kasvot kuvassa")
				_check(inside.call(_sp_sp(lg, lg.paper.global_position)), "Kerttu: lehti kuvassa")
			"etusivu":
				var px: float = paper_px.call()
				var e0: Vector3 = lg.paper.to_global(Vector3(0.18, 0, 0))
				var e1: Vector3 = lg.paper.to_global(Vector3(-0.18, 0, 0))
				var hr: Vector3 = lg._hand(lg.raimo, "r")
				var hl: Vector3 = lg._hand(lg.raimo, "l")
				var dr: float = minf(hr.distance_to(e0), hr.distance_to(e1))
				var dl: float = minf(hl.distance_to(e0), hl.distance_to(e1))
				print("LEGENDA Kerttu etusivu: %.0f px, kädet reunoista %.3f / %.3f m" % [px, dr, dl])
				_check(px > 220.0 and inside.call(_sp_sp(lg, lg.paper.global_position)), "Kerttu: etusivu isona kuvassa")
				_check(minf(dr, dl) < 0.09 and maxf(dr, dl) < 0.12, "Kerttu: Raimo pitää lehteä reunoista")
				var toward: float = (lg._cam.global_position - lg.paper.global_position).dot(lg.paper.global_basis.z)
				_check(toward > 0.0, "Kerttu: etusivu kameraan päin")
				_check(inside.call(heads[1]), "Kerttu: Raimon kasvot kuvassa (etusivu)")
			"perkele":
				_check(lg._bub.get(lg.veikko, "").contains("Perkele") and inside.call(heads[2]), "Kerttu: Veikko: Perkele")
			"kyltti":
				var sg: Vector3 = kota.to_global(lg.KIROILU)
				var sh: Vector3 = lg.raimo.to_global(lg.raimo.bone_position("upperarm_l"))
				var hd: Vector3 = lg._hand(lg.raimo, "l")
				var cosang: float = (hd - sh).normalized().dot((sg - sh).normalized())
				print("LEGENDA Kerttu osoitus: kulma %.0f°" % rad_to_deg(acos(clampf(cosang, -1.0, 1.0))))
				_check(cosang > 0.85, "Kerttu: Raimo osoittaa kylttiä")
				_check(inside.call(_sp_sp(lg, sg)) and inside.call(heads[1]), "Kerttu: kyltti ja Raimo kuvassa")
			"kassi":
				_check(lg.cans[lg.veikko].visible and inside.call(heads[2]), "Kerttu: Veikko nostaa tölkin kassista")
			"kilistys":
				var cs: Array = [lg.raimo, lg.veikko, lg.me].map(func(c): return lg.cans[c].global_position)
				var far := 0.0
				for i in 3:
					far = maxf(far, (cs[i] as Vector3).distance_to(cs[(i + 1) % 3]))
				print("LEGENDA Kerttu kilistys: tölkit %.3f m toisistaan" % far)
				_check(far < 0.16, "Kerttu: kolme tölkkiä yhdessä")
				_check(heads.all(func(h): return inside.call(h)), "Kerttu: kaikki kolme kuvassa (kilistys)")
				_check(cs.all(func(c): return inside.call(_sp_sp(lg, c))), "Kerttu: tölkit kuvassa")
			"leike2":
				_check(lg.paper_on_wall and lg.paper.transform.is_equal_approx(kota.clip_transform()), "Kerttu: lehti seinällä")
				_check(paper_px.call() > 110.0 and inside.call(_sp_sp(lg, lg.paper.global_position)), "Kerttu: leike isona kuvassa")
				_check(inside.call(_sp_sp(lg, kota.to_global(lg.LIIOITTELU))), "Kerttu: liioittelukyltti kuvassa")
				_check(inside.call(heads[1]), "Kerttu: Raimo kuvassa (leike)")
			"otsikko2":
				_check(heads.all(func(h): return inside.call(h)), "Kerttu: kaikki kolme kuvassa (otsikko)")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Kerttu jälkeen: kerrat %d, kaljat %d -> %d, viesti '%s'" % [int(main.endings.counts.get("kertun_rauta", 0)), b0, main.beers, main._msg.text])
	_check(int(main.endings.counts.get("kertun_rauta", 0)) == 1, "Kerttu: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Kerttu: päiväkirjarivi")
	_check(k.kiitetty and main.beers == b0 + 3, "Kerttu: Veikon kolme kaljaa")
	_check(kota.clipping != null and kota.clipping.visible, "Kerttu: leike jäi kodan seinälle")
	_check(kota.raimo.visible and kota.veikko.visible and not kota.fire_on, "Kerttu: oikeat hahmot takaisin ja tuli kuten ennen")
	_check(main.walker_out.visible and main.player.controls_enabled, "Kerttu: pelaaja ohjaa taas")
	_check(main._kertun_tasks().is_empty(), "Kerttu: tehtävä valmis")
	# Leike seinällä pelissä.
	var cam := Camera3D.new()
	kota.add_child(cam)
	var cg: Vector3 = kota.to_global(kota.clip_transform().origin)
	cam.look_at_from_position(kota.to_global(Vector3(0.5, 1.5, -0.3)), cg)
	cam.fov = 45.0
	cam.make_current()
	await _frames(8)
	await _shot(path, "jalkeen")
	cam.queue_free()
	main.player.activate_camera()
	# Muisto kodan jutuissa.
	var lines := {}
	for i in 80:
		lines[str(main._kota_chat_line()[1])] = true
	_check(KertunLegenda.MUISTO.any(func(m): return lines.has(m[1])), "Kerttu: Raimo ja Veikko muistelevat")
	main._hint.text = ""
	await _frames(5)
	print("LEGENDA Kerttu kota jälkeen: '%s'" % main._hint.text)


func _ukko(path: String) -> void:
	main.endings.counts.erase("tekojarven_ukko")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 4
	main.clock_min = 20 * 60 + 40
	var u = main.ukko
	u.heard = true
	u.siimat = 2
	u.lusikka = true
	u.caught = true
	u.choice = ""
	var m0: float = main.money
	main.walker_out.global_position = main.world.museum_door + Vector3(0, 0.3, 0)
	await _frames(15)
	print("LEGENDA Ukko: vihje '%s'" % main._hint.text)
	await main.get_tree().process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is TekojarviLegenda)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Ukko: Pirtin pihan hetki alkoi Ukon luovutuksesta")
	if lg == null:
		return
	_check(u.choice == "museo" and main.money > m0, "Ukko: Ukko museoon ja palkkio")
	_check(int(main.endings.counts.get("tekojarven_ukko", 0)) == 0, "Ukko: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible, "Ukko: oikea pelaaja piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.03 and v.x < 0.97 and v.y > 0.06 and v.y < 0.97
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["punnitus", "punnitus", 0.5], ["punnitus2", "punnitus", 2.2], ["taulu", "punnitus", 3.6], ["taulu2", "punnitus", 5.6],
		["uistimet", "uistimet", 1.4], ["uistimet2", "uistimet", 4.4], ["tauno", "tauno", 2.0], ["lusikka", "tauno", 4.2],
		["kyynel", "tauno", 6.4], ["kyynel2", "tauno", 8.0], ["kuva", "kuva", 1.6], ["kuva2", "kuva", 4.0], ["kuva3", "kuva", 5.8],
		["salama", "kuva", 6.5], ["otsikko", "otsikko", 0.6], ["otsikko2", "otsikko", 3.2]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Ukko: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var snout: Vector2 = _sp_sp(lg, lg._pike_pt(1.0))
		var tail: Vector2 = _sp_sp(lg, lg._pike_pt(0.0))
		var heads := [lg.me, lg.opas, lg.tauno, lg.pekka, lg.arto, lg.annaliisa].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Ukko %s: kuono %s pyrstö %s (pituus %.0f px), päät minä/opas/tauno/pekka/arto/al %s, viisari %.1f" % [st[0],
			snout, tail, ((snout - tail) * vs).length(), heads, lg.needle_kg])
		match st[0]:
			"punnitus2":
				_check(inside.call(snout) and inside.call(tail), "Ukko: koko Ukko kuvassa")
				_check(((snout - tail) * vs).y < -vs.y * 0.35, "Ukko: Ukko roikkuu pystyssä ja isona")
				_check(inside.call(heads[0]) and inside.call(heads[1]), "Ukko: opas ja pelaaja kuvassa")
			"taulu", "taulu2":
				var dc: Vector2 = _sp_sp(lg, lg.scale_dial.global_position)
				var de: Vector2 = _sp_sp(lg, lg.scale_dial.to_global(Vector3(0.074, 0, 0)))
				var r := ((de - dc) * vs).length()
				print("LEGENDA Ukko taulun säde %.0f px" % r)
				_check(inside.call(dc) and r > 80.0, "Ukko: puntarin taulu isona keskellä (%s)" % st[0])
				if st[0] == "taulu2":
					_check(absf(lg.needle_kg - lg.KG) < 0.3, "Ukko: viisari asettui 18,4:ään")
					_check(lg._story.contains("pilkku neljä"), "Ukko: lukema kerrotaan")
			"uistimet2":
				for l: Node3D in lg.lures:
					_check(inside.call(_sp_sp(lg, l.global_position)), "Ukko: uistin kuvassa")
				var l0: Vector2 = _sp_sp(lg, lg.lure_isa.global_position)
				var l1: Vector2 = _sp_sp(lg, lg.lure_isa.global_position + lg._G.global_basis.y * 0.06)
				print("LEGENDA Ukko lusikka %.0f px" % ((l1 - l0) * vs).length())
				_check(((l1 - l0) * vs).length() > 40.0, "Ukko: isän lusikka näkyy isona")
			"tauno":
				_check(inside.call(heads[2]), "Ukko: Tauno kävelee pihalle (kuvassa)")
			"lusikka":
				var hd: float = lg._hand(lg.tauno).distance_to(lg.lure_isa.global_position)
				print("LEGENDA Ukko Taunon käsi lusikasta %.3f m" % hd)
				_check(hd < 0.1, "Ukko: Taunon käsi isän lusikalla")
				_check(inside.call(heads[2]) and inside.call(_sp_sp(lg, lg.lure_isa.global_position)), "Ukko: Tauno ja lusikka kuvassa")
			"kyynel":
				_check(inside.call(heads[2]), "Ukko: Taunon kasvot kuvassa")
				var hw: float = lg._hand(lg.tauno).distance_to(head.call(lg.tauno))
				print("LEGENDA Ukko pyyhintä: käsi päästä %.3f m" % hw)
				_check(hw < 0.2, "Ukko: Tauno pyyhkii silmää")
			"kyynel2":
				var tp: Vector2 = _sp_sp(lg, lg.tear.global_position)
				var tp2: Vector2 = _sp_sp(lg, lg.tear.global_position + Vector3(0, 0.02, 0))
				print("LEGENDA Ukko kyynel %s, korkeus %.0f px" % [tp, ((tp2 - tp) * vs).length()])
				_check(lg.tear.visible and inside.call(tp), "Ukko: kyynel Taunon poskella kuvassa")
				_check(((tp2 - tp) * vs).length() > 12.0, "Ukko: kyynel erottuu")
			"kuva3", "salama", "otsikko2":
				_check(inside.call(snout) and inside.call(tail), "Ukko: Ukko vaakatasossa kuvassa (%s)" % st[0])
				var hs: Array = heads.slice(0, 5) if st[0] == "otsikko2" else heads  # otsikossa kamera on Anna-Liisan puhelin
				_check(hs.all(func(h): return inside.call(h)), "Ukko: kaikki hahmot kuvassa (%s)" % st[0])
				var gaps: Array = []
				for pr in [[lg.tauno, lg.HOLD_U[0]], [lg.tauno, lg.HOLD_U[1]], [lg.me, lg.HOLD_U[2]], [lg.me, lg.HOLD_U[3]]]:
					var pt: Vector3 = lg._pike_pt(pr[1], -1.0)
					var c: Node3D = pr[0]
					gaps.append(minf(lg._hand(c).distance_to(pt), lg._hand_l(c).distance_to(pt)))
				print("LEGENDA Ukko kädet hauen alla %s" % [gaps])
				_check(gaps.all(func(g): return g < 0.09), "Ukko: kädet hauen alla (%s)" % st[0])
			"salama":
				_check(lg.flashed and lg.phone.visible, "Ukko: Anna-Liisa kuvaa (salama)")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Ukko jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("tekojarven_ukko", 0)), main._msg.text])
	_check(int(main.endings.counts.get("tekojarven_ukko", 0)) == 1, "Ukko: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Ukko: päiväkirjarivi")
	_check(main.walker_out.visible and main.player.controls_enabled, "Ukko: pelaaja ohjaa taas")
	main.kirppis_int.mode = "kirppis"
	var o: Array = main._talk_options("tauno").map(func(x): return x.id)
	_check("ukko_muisto" in o, "Ukko: Taunolle kysymys punnituksesta")
	main._talk_who = "tauno"
	main._talk_kirppis("ukko_muisto")
	await _frames(3)
	print("LEGENDA Ukko muisto: vaihtoehdot %s" % [o])
