extends RefCounted
## Tarina ja tehtävät (#132): tarinan luvut ja irralliset sivutehtävät yhdessä rekisterissä. Edistyminen luetaan
## pelin omasta tilasta (tilat.firsts-ensikerrat ja main.gd:n liput), joten vanhat tallennukset toimivat sellaisinaan.
## Päiväkirja (journal.gd) ei paljasta mitään etukäteen: luku näkyy vasta, kun siihen päästään, sen vaihe vasta kun
## vihje on kuultu (tai vaihe on tehty), ja sivutehtävä vasta, kun siitä on kuultu (known). Kerran tiedoksi tullut
## pysyy (tallennetaan).
##
## Ehdot merkkijonoina: "always", "first:avain" (tilat.firsts), "firstp:alku" (mikä tahansa ensikerta alkaen),
## "flag:nimi" (main.gd quest_flag), yhdistettynä "&" (ja) tai "|" (tai). Vihje: "auto" = tiedossa heti kun vaihe
## alkaa, "flag:nimi" = kun lippu on tosi, tai "puhuja|repliikki" = puhuja sanoo repliikin keskustelussa (main.gd
## _story_hint), jolloin vaihe merkitään kuulluksi.

const CHAPTERS := [
	{"id": "luku1", "title": "1. Paapeliin pääsee, kunhan…", "story": true, "done": "flag:paapeli"},
	{"id": "luku2", "title": "2. Paapelin isäntä", "steps": [
		{"id": "santtu", "text": "Mökin isäntä Santtu kahvikuppeineen pihalla.", "done": "first:santtu", "hint": "auto"},
		{"id": "hommat", "text": "Santtu antaa pihahommia: tee päivän hommat.", "done": "firstp:homma_",
			"hint": "santtu|Pihalla ois hommia, jos kiinnostaa. Kato lista, mitä tänään pitäis tehdä."},
		{"id": "sauna", "text": "Savusauna on retuperällä: korjaa se Santun neuvoilla.", "done": "flag:sauna_fixed",
			"hint": "santtu|Se savusauna on ihan retuperällä. Kiuas, lauteet, terva ja luukku pitäs laittaa kuntoon."},
		{"id": "loylyt", "text": "Lämmitä korjattu savusauna ja mene löylyihin.", "done": "first:savusauna_loylyt",
			"hint": "santtu|Nyt ku sauna on kunnossa, lämmitä se. Halot pinosta, ja anna savujen tuulettua ennen löylyä."},
	]},
	{"id": "luku3", "title": "3. Mopolla Vaalaan", "steps": [
		{"id": "siitari", "text": "Pihan mopolla Vaalaan, Hotelli-Ravintola Siitariin.", "done": "first:siitari",
			"hint": "santtu|Pihan mopolla pääsee Vaalaan. Siitarissa on karaoke ja tanssilattia, kannattaa käydä."},
		{"id": "lava", "text": "Oulujärven lavalle tansseihin, niemen kärkeen.", "done": "first:lava",
			"hint": "siitari|Oulujärven lavalla on tanssit, niemen kärjessä Pahalahdentien päässä. Siellä se nuoriso on."},
		{"id": "kiihdytys", "text": "Voita Zabukin mopopojat kiihdytyksessä.", "done": "first:mopokisa_voitto",
			"hint": "nuoret|Zabukin pihalla mopopojat haastaa kaikki kiihdytykseen. Pakoputki-Pete on nopein."},
	]},
	{"id": "luku4", "title": "4. Junalla kotiin", "steps": [
		{"id": "asema", "text": "Vaalan rautatieasemalle: juna Saloisiin lähtee sieltä.", "done": "first:asema_vaala",
			"hint": "gasthaus|Juna Saloisiin lähtee asemalta. Zabukin ohi liikenneympyrään ja oikealle."},
		{"id": "juna", "text": "Junalla takaisin Saloisiin, ravintolavaunun kautta.", "done": "first:juna_saloinen", "hint": "auto"},
	]},
	{"id": "luku5", "title": "5. Kylän salaisuudet", "steps": [
		{"id": "kirppis", "text": "Seuranmäen seuraintalolla on kirppis ja huutokauppa.", "done": "first:kirppis",
			"hint": "pekka|Seuranmäellä on kirppis, perkele, siellä on kaikkea. Huutokauppakin. Kävin ostamassa haulikon kotelon."},
		{"id": "varasto", "text": "Tokolan vanha varasto: avain on vanhalla Aarolla.", "done": "first:tokolan_varasto",
			"hint": "tauno|Tokolassa on kaupan vanha varasto. Avain on Aarolla, se tykkää lihapiirakasta."},
		{"id": "aarre", "text": "Tokolan kauppiaan aarre: Aaron mukaan rahat ei koskaan päätyneet pankkiin.", "done": "flag:tokola_done",
			"hint": "flag:tokola_key"},
		{"id": "pannu", "text": "Vanhan Sulon pannu upotettiin Pilkkarinnevalle ratsiayönä.", "done": "flag:pannu_done",
			"hint": "flag:pannu_heard"},
		{"id": "aarni", "text": "Lapinraunion aarnivalkea: Isonvihan hopeat kätkettiin raunion lähelle.", "done": "flag:aarni_done",
			"hint": "flag:aarni_heard"},
		{"id": "kertun", "text": "Kertunkankaan rauta: kodan Raimon mukaan viimeinen seppä kätki kirveensä kankaalle.",
			"done": "flag:kertun_done", "hint": "flag:kertun_heard"},
		{"id": "ukko", "text": "Tekojärven Ukko: Taunon mukaan tekojärven pohjalla, vanhan ladon raunioilla, elää valtava hauki.",
			"done": "flag:ukko_done", "hint": "flag:ukko_heard"},
	]},
]

## Sivutehtävät: id, otsikko, kuvaus (kun tiedossa), tiedossa-ehto, valmis-ehto ja valinnainen edistymisavain
## (main.gd quest_progress). Idea: pelaajan ajatus tai huomio, joka näytetään, kun tehtävä tulee tiedoksi, jotta tehtävä
## ei ilmesty päiväkirjaan tyhjästä (main.gd _quest_ideas).
const SIDE := [
	{"id": "kauppalista", "title": "Päivin kauppalista", "text": "Heippalapussa kauppalista värikynillä. Oikeat tuotteet oikean värisinä.",
		"known": "always", "done": "first:kauppalista"},
	{"id": "nurmikko", "title": "Takapihan nurmikko", "text": "Nurmikko kasvaa joka päivä. Leikattu nurmikko tuo Päiviltä ylimääräistä.",
		"known": "always", "done": "first:nurmikko"},
	{"id": "pensasaita", "title": "Kadun puolen pensasaita", "text": "Tuija-aita Päivin narun tasalle trimmerillä. Ei koloja, niin Päivi antaa ylimääräistä.",
		"known": "flag:pensas_nag|first:pensasaita", "done": "first:pensasaita",
		"idea": "Tuija-aita rehottaa kadulle. Trimmeri on aidan päässä, ja Päivi vahtii narun kanssa."},
	{"id": "koris", "title": "Kuusitoista koria putkeen", "text": "Kentän laidan korilla pojat lyö vetoa: 16 koria putkeen, palkkiona Jeren isän kalja.",
		"known": "first:koris_haaste|first:koris16", "done": "first:koris16",
		"idea": "Pojat lyö vetoa, ettei setä saa 16 koria putkeen. Panoksena Jeren isän kalja."},
	{"id": "laavu", "title": "Laavu Antinsuonkankaalla", "text": "Nuotio, makkara ja kalja laavulla, jos valtaajat väistyy.",
		"known": "always", "done": "flag:ending_legendaarinen"},
	{"id": "vaino", "title": "Väinö karkuteillä", "text": "Pekan koira karkasi. Hiivi viereen jalan, makkara houkuttaa.",
		"known": "first:vaino_karkasi|first:vaino", "done": "first:vaino",
		"idea": "Väinö karkas taas! Pyörällä se säikähtää. Jalan perään, ja makkara houkuttaa."},
	{"id": "pojat", "title": "Jalkapallopoikien pallo", "text": "Pojilla on pallo hukassa. Pojat kertoivat suunnan.",
		"known": "first:pojat", "done": "first:jalkapallo",
		"idea": "Pojilta jäi pallo hukkaan. Ne näytti suuntaa, kattelen sitä, ku kuljen sinne päin."},
	{"id": "pontikka", "title": "Pontikkaa kuusikossa", "text": "Joku keittää kuusikossa pontikkaa. Kodan tarinat ja ilmakuvat auttaa.",
		"known": "flag:pontikka_found|first:pontikka|first:juoru_pontikka", "done": "first:pontikka",
		"idea": "Kuusikosta tuoksahti tuttu haju. Joku keittää siellä! Ilmasta näkis savun."},
	{"id": "drooni", "title": "Saloinen ilmasta", "text": "Kuvauskopterilla ilmakuvat kylän kohteista.",
		"known": "first:drooni", "done": "flag:drone_all", "progress": "drooni",
		"idea": "Kopteri lentää! Tällä sais koko Saloisten ilmasta. Kuvat talteen."},
	{"id": "kotiviini", "title": "Kotiviini", "text": "Marjat, sokeri ja hiiva autotallin saaviin. Kypsä viini, ja juhlat.",
		"known": "first:kotiviini", "done": "flag:ending_viinibileet",
		"idea": "Viini käy. Ku se on kypsää, pidetään kunnon juhlat."},
	{"id": "sahkopyora", "title": "Saloislainen sähköpyörä", "text": "Osat sieltä täältä ja kasaus autotallin työpöydällä.",
		"known": "flag:ebike_started", "done": "flag:ebike_built", "progress": "sahkopyora",
		"idea": "Hetkinen… mähän oon meinannu kasata sähköpyörän! Pekalla on vanhoja akkuja, ja Seppo tietää romut."},
	{"id": "huutokauppa", "title": "Huutokaupan voittaja", "text": "Seuraintalon lavalla huutokauppa. Huuto menee läpi vain, kun Erkki katsoo.",
		"known": "first:kirppis", "done": "first:huutokauppa",
		"idea": "Lavalla Erkki huutaa kauppaa. Huuto menee läpi vaan, ku Erkki kattoo sun suuntaan."},
	{"id": "seurailta", "title": "Tanssit ja bingo", "text": "Ilmoitustaulu: tanssit lauantaisin klo 21, bingo tiistaisin klo 18.",
		"known": "first:kirppis", "done": "first:tanssit&first:bingo",
		"idea": "Seuraintalon ilmoitustaululla: tanssit lauantaisin yheksältä, bingo tiistaisin kuudelta."},
	{"id": "raahe", "title": "Kapteenin Kulman Tero", "text": "Raahen baarissa terästehtaan Tero haastaa kädenvääntöön.",
		"known": "first:raahe", "done": "first:tero_voitto",
		"idea": "Tiskin takana Tero kääntää hihat. Kädenvääntöön ois haastajaa."},
	{"id": "santtu5", "title": "Viisi tähteä Santulta", "text": "Santtu arvostelee päivän hommat. Täydet tähdet tarvitaan.",
		"known": "first:santtu", "done": "flag:santtu_5",
		"idea": "Santtu kattoo päivän hommat tarkkaan ja antaa tähtiä. Viis tähteä, se ois jotain."},
	{"id": "viinakatkot", "title": "Mökin viinakätköt", "text": "Mökin metsissä on vanhoja viinakätköjä.",
		"known": "first:viinakatko", "done": "flag:viina_all", "progress": "viinakatkot",
		"idea": "Lokikirjassa on muitakin nimiä. Mökin metsissä on näitä kätköjä enemmänkin."},
	{"id": "asemakatkot", "title": "Aseman rahakätköt", "text": "Odotussalin juopot ja narkkarit tietää kätköjen paikat hörppyä vastaan.",
		"known": "first:asema_horppy|first:asema_katko", "done": "flag:asema_all", "progress": "asemakatkot",
		"idea": "Odotussalin porukka tietää kätköjen paikat. Hörppy auttaa muistamaan."},
	{"id": "era", "title": "Eräjorma", "text": "Kalaa järvestä ja riistaa metsästä mökin savustimeen.",
		"known": "first:kalastus|first:metsastys", "done": "first:savustin",
		"idea": "Saalis! Mökin savustimessa kalasta ja riistasta tulis herkkua."},
	{"id": "pingis", "title": "Pihapingismestari", "text": "Santtu on pihapingismestari. Voita hänet.",
		"known": "first:pingis", "done": "first:pingis_voitto",
		"idea": "Santtu pelaa pingistä ku vanha mestari. Kerran se on voitettava."},
	{"id": "volvo", "title": "Pekan Volvo ei lähde", "text": "Välillä Pekan Volvo ei käynnisty. Korpelan korjaamo laittaa sen kuntoon, ja kyyti Paapeliin on sinä päivänä ilmainen.",
		"known": "first:volvo_rikki|first:volvo_korjattu", "done": "first:volvo_korjattu",
		"idea": "Pekan Volvo ei aina lähe. Korpela sen korjais, ja Pekka heittäis ilmaseks Paapeliin."},
	{"id": "kaasu", "title": "Kaasua Pannu-Sululle", "text": "Pannu-Sulon kaasupullo on tyhjä. Heiskaselta saa uuden.",
		"known": "first:korjaamo", "done": "first:sulo_kaasu",
		"idea": "Heiskasella kaasupulloja. Pannu-Sulon pullo on kuulemma tyhjä."},
	{"id": "eramaa", "title": "Erämaan laavu", "text": "Kartan lounaiskulmassa Viitajärven laavu: nuotio, makkara ja kalja, eikä kukaan tiedä, missä oot.",
		"known": "first:viitajarvi", "done": "flag:ending_eramaan_laavu",
		"idea": "Viitajärvi. Ei ketään missään. Laavulle nuotio, makkara ja kalja, eikä kukaan tiedä."},
	{"id": "metso", "title": "Metson soidin", "text": "Luonnonsuojelualueella soitimella metso aamuisin (8–10). Hiljaa lähelle.",
		"known": "first:suojelualue", "done": "first:metso",
		"idea": "Kyltissä lukee: aamusin täällä soitimella metso, kaheksasta kymmeneen. Hiljaa lähelle."},
	{"id": "rauniot", "title": "Raunioiden valokuva", "text": "Länsilaidan raunioilla iltaisin teinien nuotio. Uunin raunioissa jotain, kenen talo?",
		"known": "first:rauniot", "done": "first:rauniot_valokuva",
		"idea": "Raunioilla teinien nuotio. Vanhan uunin raunioissa jotain… kenen talo tää oli?"},
	{"id": "keinu", "title": "Keinuhyppyennätys", "text": "Leikkipuistojen keinuhyppyennätys on Honganpalon Jerellä. Aikuinen mies voi parempaan.",
		"known": "first:leikkipuisto", "done": "first:keinu_ennatys",
		"idea": "Keinutelineeseen raapustettu Jeren ennätys. Aikuinen mies hyppää kyllä pidemmälle."},
	{"id": "kukat", "title": "Kukat Päiville", "text": "Säästöpihasta kukkakimppu, ja kotiin ennen iltaa. Syntymäpäivänä erityisen tärkeää.",
		"known": "first:saastopiha", "done": "first:kukat_paiville",
		"idea": "Säästöpihalla kukkia. Päivi ilahtuis kimpusta, ku sen vie kotiin ennen iltaa."},
	{"id": "taimet", "title": "Sinikan tomaatintaimet", "text": "Sinikka ei ehdi säästöpihaan. Taimet sieltä Sinikalle.",
		"known": "first:saastopiha&flag:taimet_pyydetty|first:sinikka_taimet", "done": "first:sinikka_taimet",
		"idea": "Säästöpihan tomaatintaimet… Sinikka puhu, ettei se ehdi tänne itte."},
	{"id": "seppo", "title": "Sepon varastomyynti", "text": "K-Marketin vieressä Sepon varasto: tarvikkeita sähköpyörään, yllätyslaatikko ja Sepon päivän hinnat.",
		"known": "first:seppo", "done": "first:seppo_kauppa",
		"idea": "Sepon varastossa tarvikkeita ja yllätyslaatikko. Hinnat riippuu Sepon päivästä."},
	{"id": "honganpalo", "title": "Honganpalon koulu", "text": "Vahtimestari Reijo maksaa, jos kerää iltaporukan roskat pihalta.",
		"known": "first:honganpalo", "done": "first:vahtimestari_keikka",
		"idea": "Koulun pihalla roskia iltaporukan jäljiltä. Vahtimestari Reijo maksais, jos joku keräis."},
	{"id": "rankkarit", "title": "Rankkarit Saloisten kentällä", "text": "Pojat pelaa kentällä päivisin. Voita heidät rankkareissa.",
		"known": "first:kentta", "done": "first:rankkarit_voitto",
		"idea": "Kentällä pojat potkii rankkareita. Ne haastaa kaikki, aikuisetkin."},
	{"id": "oravajarvi", "title": "Oravajärven uimaranta", "text": "Kylän oma uimaranta kotoa pohjoiseen. Uimaan, ja pohjasta voi löytyä kaikenlaista.",
		"known": "first:oravajarvi", "done": "first:uinti_oravajärvi",
		"idea": "Oravajärven uimaranta. Pulahdus virkistää, ja pohjasta voi löytyä kaikenlaista."},
	{"id": "sormus", "title": "Sormus järven pohjasta", "text": "Oravajärven pohjasta löytyi kultasormus. Kuka siellä käy aamuisin uimassa?",
		"known": "flag:orava_sormus|first:sormus_sinikalle", "done": "first:sormus_sinikalle",
		"idea": "Kultasormus järven pohjasta! Joku aamu-uimari on sen hukannu."},
	{"id": "huoltis", "title": "SEO Saloinen 24/7", "text": "Huoltis on aina auki. Rekkakuskit ajaa Raaheen, jos kehtaa kysyä kyytiä.",
		"known": "first:seo", "done": "first:rekkakyyti",
		"idea": "Rekkakuskit ajaa SEO:lta Raaheen. Kehtaiskohan kysyä kyytiä?"},
	{"id": "katsastus", "title": "Sähköpyörän katsastus", "text": "Kinnapotin katsastusmies katsoo kasatun sähköpyörän. Teipillä ei pääse läpi.",
		"known": "first:kinnapotti", "done": "first:katsastus_ok",
		"idea": "Katsastusasema. Kasatun sähköpyörän vois tuua tänne. Teipillä ei kuulemma pääse läpi."},
	{"id": "rossi", "title": "Tokolanperän rossirata", "text": "Crossipoikien kierrosennätys pyörällä. Hyppyreistä ilmaan.",
		"known": "first:rossirata", "done": "first:rossi_voitto",
		"idea": "Crossipoikien rata. Taululla kierrosennätys, ja hyppyreistä pääsee ilmaan."},
	{"id": "piirakka", "title": "Reipparin lihapiirakkahaaste", "text": "Kioskin seinällä ennätystaulu: Juntti söi seitsemän lihapiirakkaa kaikilla. Pystytkö parempaan?",
		"known": "first:reippari", "done": "first:piirakkaennatys",
		"idea": "Reipparin ennätystaulu: Juntti söi seittemän lihapiirakkaa kaikilla. Pystyiskö parempaan?"},
	{"id": "miisu", "title": "Kadonnut Miisu", "text": "Reipparin ilmoitustaulu: Tokolan Aaron kissa Miisu on kadonnut. Aaro tietää, missä se tykkää käydä.",
		"known": "first:miisu_ilmoitus", "done": "first:miisu_palautettu",
		"idea": "Ilmoitustaululla lappu: Aaron Miisu-kissa kadonnu. Aaro tietää, missä se tykkää käydä."},
	{"id": "pummi", "title": "Pummilla lavalle", "text": "Porukka aidan takana tietää reitin lavalle ilman lippua.",
		"known": "first:nuoret_kalja|first:pummi_lava", "done": "first:pummi_lava",
		"idea": "Porukka aidan takana kuiskaa: lavalle pääsee ilman lippua, ku tietää reitin."},
]

var known := {}  # sivutehtävä -> päivä, jolloin tuli tiedoksi
var heard := {}  # tarinan vaihe -> true (vihje kuultu)
var done_day := {}  # tehtävä tai vaihe -> päivä, jolloin valmistui (päiväkirjaan)
var primed := false  # alkutilanne kirjattu hiljaa: idea näytetään vain sen jälkeen tiedoksi tulleille


## Ehto: firsts = tilat.firsts, flag = Callable(nimi) -> bool.
static func check(cond: String, firsts: Array, flag: Callable) -> bool:
	if cond == "always":
		return true
	if "|" in cond:
		for c in cond.split("|"):
			if check(c, firsts, flag):
				return true
		return false
	if "&" in cond:
		for c in cond.split("&"):
			if not check(c, firsts, flag):
				return false
		return true
	var kind := cond.get_slice(":", 0)
	var arg := cond.get_slice(":", 1)
	match kind:
		"first":
			return arg in firsts
		"firstp":
			for f in firsts:
				if String(f).begins_with(arg):
					return true
			return false
		"flag":
			return flag.call(arg)
	return false


## Tarinan nykyinen avoin vaihe: [luku, vaihe] tai [] (luku 1 kulkee story.gd:n kautta).
func active_step(firsts: Array, flag: Callable) -> Array:
	for ch in CHAPTERS:
		if check(ch.get("done", ""), firsts, flag) and ch.get("story", false):
			continue
		if ch.get("story", false):
			return []
		for st in ch.steps:
			if not check(st.done, firsts, flag):
				return [ch, st]
	return []


## Vihjeen kuuleminen keskustelussa: palauttaa repliikin, jos puhujalla on avoimen vaiheen vihje.
func hint_for(who: String, firsts: Array, flag: Callable) -> String:
	var a := active_step(firsts, flag)
	if a.is_empty():
		return ""
	var h: String = a[1].get("hint", "")
	if h.get_slice("|", 0) != who or not "|" in h:
		return ""
	heard[a[1].id] = true
	return h.get_slice("|", 1)


## Uudet tiedoksi tulleet sivutehtävät (niiden idea näytetään). Ensimmäinen kutsu uuden pelin tai latauksen jälkeen
## kirjaa jo täyttyneet hiljaa.
func newly_known(firsts: Array, flag: Callable, day: int) -> Array:
	var out: Array = []
	for q in SIDE:
		if known.has(q.id) or not check(q.known, firsts, flag):
			continue
		known[q.id] = day
		if primed:
			out.append(q)
	primed = true
	return out


## Päiväkirjan sisältö. story_rows = story.list() (luku 1), progress = Callable(avain) -> String, day = nykyinen päivä.
func build(firsts: Array, flag: Callable, story_rows: Array, progress: Callable, day: int) -> Dictionary:
	var chapters: Array = []
	var prev_done := true
	for ch in CHAPTERS:
		if not prev_done:
			break
		var rows: Array = []
		var ch_done := false
		if ch.get("story", false):
			rows = story_rows
			ch_done = check(ch.done, firsts, flag)
		else:
			ch_done = true
			var open := true
			for st in ch.steps:
				var d := check(st.done, firsts, flag)
				ch_done = ch_done and d
				if d and not done_day.has(st.id):
					done_day[st.id] = day
				var h: String = st.get("hint", "")
				# Lipulla vihjattu vaihe (luvun 5 legendat) näkyy heti kuultuna, vaikka aiempi vaihe olisi kesken.
				var by_flag := h.begins_with("flag:")
				if not d and ((open and h == "auto") or (by_flag and check(h, firsts, flag))):
					heard[st.id] = true
				if d or ((open or by_flag) and heard.has(st.id)):
					rows.append([st.text, d])
				if not d:
					open = false
		chapters.append({"title": ch.title, "rows": rows, "done": ch_done})
		prev_done = ch_done
	var more := prev_done  # kaikki luvut tehty: tarina jatkuu myöhemmin
	var side: Array = []
	for q in SIDE:
		if not known.has(q.id) and check(q.known, firsts, flag):
			known[q.id] = day
		if not known.has(q.id):
			continue
		var d := check(q.done, firsts, flag)
		if d and not done_day.has(q.id):
			done_day[q.id] = day
		var p: String = progress.call(q.progress) if q.has("progress") else ""
		side.append({"id": q.id, "title": q.title, "text": q.text, "done": d, "progress": p, "day": known[q.id]})
	return {"chapters": chapters, "more": more, "side": side}


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("tehtavat", "tiedossa", known)
	cfg.set_value("tehtavat", "kuultu", heard)
	cfg.set_value("tehtavat", "valmis", done_day)


func load_from(cfg: ConfigFile) -> void:
	known = cfg.get_value("tehtavat", "tiedossa", {})
	heard = cfg.get_value("tehtavat", "kuultu", {})
	done_day = cfg.get_value("tehtavat", "valmis", {})
	primed = false
