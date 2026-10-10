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
		{"id": "asema", "text": "Vaalan rautatieasemalle: juna Saloisiin lähtee sieltä.", "done": "first:asema",
			"hint": "gasthaus|Juna Saloisiin lähtee asemalta. Zabukin ohi liikenneympyrään ja oikealle."},
		{"id": "juna", "text": "Junalla takaisin Saloisiin, ravintolavaunun kautta.", "done": "first:juna", "hint": "auto"},
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
	]},
]
const STORY_MORE := "Tarina jatkuu…"

## Sivutehtävät: id, otsikko, kuvaus (kun tiedossa), tiedossa-ehto, valmis-ehto ja valinnainen edistymisavain
## (main.gd quest_progress).
const SIDE := [
	{"id": "kauppalista", "title": "Päivin kauppalista", "text": "Heippalapussa kauppalista värikynillä. Oikeat tuotteet oikean värisinä.",
		"known": "always", "done": "first:kauppalista"},
	{"id": "nurmikko", "title": "Takapihan nurmikko", "text": "Nurmikko kasvaa joka päivä. Leikattu nurmikko tuo Päiviltä ylimääräistä.",
		"known": "always", "done": "first:nurmikko"},
	{"id": "laavu", "title": "Laavu Antinsuonkankaalla", "text": "Nuotio, makkara ja kalja laavulla, jos valtaajat väistyy.",
		"known": "always", "done": "flag:ending_legendaarinen"},
	{"id": "vaino", "title": "Väinö karkuteillä", "text": "Pekan koira karkasi. Hiivi viereen jalan, makkara houkuttaa.",
		"known": "first:vaino_karkasi|first:vaino", "done": "first:vaino"},
	{"id": "pojat", "title": "Jalkapallopoikien pallo", "text": "Pojilla on pallo hukassa. Pojat kertoivat suunnan.",
		"known": "first:pojat", "done": "first:jalkapallo"},
	{"id": "pontikka", "title": "Pontikkaa kuusikossa", "text": "Joku keittää kuusikossa pontikkaa. Kodan tarinat ja ilmakuvat auttaa.",
		"known": "flag:pontikka_found|first:pontikka|first:juoru_pontikka", "done": "first:pontikka"},
	{"id": "drooni", "title": "Saloinen ilmasta", "text": "Kuvauskopterilla ilmakuvat kylän kohteista.",
		"known": "first:drooni", "done": "flag:drone_all", "progress": "drooni"},
	{"id": "kotiviini", "title": "Kotiviini", "text": "Marjat, sokeri ja hiiva autotallin saaviin. Kypsä viini, ja juhlat.",
		"known": "first:kotiviini", "done": "flag:ending_viinibileet"},
	{"id": "sahkopyora", "title": "Saloislainen sähköpyörä", "text": "Osat sieltä täältä ja kasaus autotallin työpöydällä.",
		"known": "flag:ebike_started", "done": "flag:ebike_built", "progress": "sahkopyora"},
	{"id": "huutokauppa", "title": "Huutokaupan voittaja", "text": "Seuraintalon lavalla huutokauppa. Huuto menee läpi vain, kun Erkki katsoo.",
		"known": "first:kirppis", "done": "first:huutokauppa"},
	{"id": "seurailta", "title": "Tanssit ja bingo", "text": "Ilmoitustaulu: tanssit lauantaisin klo 21, bingo tiistaisin klo 18.",
		"known": "first:kirppis", "done": "first:tanssit&first:bingo"},
	{"id": "raahe", "title": "Kapteenin Kulman Tero", "text": "Raahen baarissa terästehtaan Tero haastaa kädenvääntöön.",
		"known": "first:raahe", "done": "first:tero_voitto"},
	{"id": "santtu5", "title": "Viisi tähteä Santulta", "text": "Santtu arvostelee päivän hommat. Täydet tähdet tarvitaan.",
		"known": "first:santtu", "done": "flag:santtu_5"},
	{"id": "viinakatkot", "title": "Mökin viinakätköt", "text": "Mökin metsissä on vanhoja viinakätköjä.",
		"known": "first:viinakatko", "done": "flag:viina_all", "progress": "viinakatkot"},
	{"id": "asemakatkot", "title": "Aseman rahakätköt", "text": "Odotussalin juopot ja narkkarit tietää kätköjen paikat hörppyä vastaan.",
		"known": "first:asema_horppy|first:asema_katko", "done": "flag:asema_all", "progress": "asemakatkot"},
	{"id": "era", "title": "Eräjorma", "text": "Kalaa järvestä ja riistaa metsästä mökin savustimeen.",
		"known": "first:kalastus|first:metsastys", "done": "first:savustin"},
	{"id": "pingis", "title": "Pihapingismestari", "text": "Santtu on pihapingismestari. Voita hänet.",
		"known": "first:pingis", "done": "first:pingis_voitto"},
	{"id": "honganpalo", "title": "Honganpalon koulu", "text": "Vahtimestari Reijo maksaa, jos kerää iltaporukan roskat pihalta.",
		"known": "first:honganpalo", "done": "first:vahtimestari_keikka"},
	{"id": "rankkarit", "title": "Rankkarit Saloisten kentällä", "text": "Pojat pelaa kentällä päivisin. Voita heidät rankkareissa.",
		"known": "first:kentta", "done": "first:rankkarit_voitto"},
	{"id": "oravajarvi", "title": "Oravajärven uimaranta", "text": "Kylän oma uimaranta kotoa pohjoiseen. Uimaan, ja pohjasta voi löytyä kaikenlaista.",
		"known": "first:oravajarvi", "done": "first:uinti_oravajärvi"},
	{"id": "sormus", "title": "Sormus järven pohjasta", "text": "Oravajärven pohjasta löytyi kultasormus. Kuka siellä käy aamuisin uimassa?",
		"known": "first:uinti_oravajärvi", "done": "first:sormus_sinikalle"},
	{"id": "huoltis", "title": "SEO Saloinen 24/7", "text": "Huoltis on aina auki. Rekkakuskit ajaa Raaheen, jos kehtaa kysyä kyytiä.",
		"known": "first:seo", "done": "first:rekkakyyti"},
	{"id": "katsastus", "title": "Sähköpyörän katsastus", "text": "Kinnapotin katsastusmies katsoo kasatun sähköpyörän. Teipillä ei pääse läpi.",
		"known": "first:kinnapotti", "done": "first:katsastus_ok"},
	{"id": "rossi", "title": "Tokolanperän rossirata", "text": "Crossipoikien kierrosennätys pyörällä. Hyppyreistä ilmaan.",
		"known": "first:rossirata", "done": "first:rossi_voitto"},
	{"id": "piirakka", "title": "Reipparin lihapiirakkahaaste", "text": "Kioskin seinällä ennätystaulu: Juntti söi seitsemän lihapiirakkaa kaikilla. Pystytkö parempaan?",
		"known": "first:reippari", "done": "first:piirakkaennatys"},
	{"id": "miisu", "title": "Kadonnut Miisu", "text": "Reipparin ilmoitustaulu: Tokolan Aaron kissa Miisu on kadonnut. Aaro tietää, missä se tykkää käydä.",
		"known": "first:miisu_ilmoitus", "done": "first:miisu_palautettu"},
	{"id": "pummi", "title": "Pummilla lavalle", "text": "Porukka aidan takana tietää reitin lavalle ilman lippua.",
		"known": "first:nuoret_kalja|first:pummi_lava", "done": "first:pummi_lava"},
]

var known := {}  # sivutehtävä -> päivä, jolloin tuli tiedoksi
var heard := {}  # tarinan vaihe -> true (vihje kuultu)
var done_day := {}  # tehtävä tai vaihe -> päivä, jolloin valmistui (päiväkirjaan)


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
				if open and not d and (h == "auto" or (h.begins_with("flag:") and check(h, firsts, flag))):
					heard[st.id] = true
				if d or (open and heard.has(st.id)):
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
		side.append({"title": q.title, "text": q.text, "done": d, "progress": p, "day": known[q.id]})
	return {"chapters": chapters, "more": more, "side": side}


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("tehtavat", "tiedossa", known)
	cfg.set_value("tehtavat", "kuultu", heard)
	cfg.set_value("tehtavat", "valmis", done_day)


func load_from(cfg: ConfigFile) -> void:
	known = cfg.get_value("tehtavat", "tiedossa", {})
	heard = cfg.get_value("tehtavat", "kuultu", {})
	done_day = cfg.get_value("tehtavat", "valmis", {})
