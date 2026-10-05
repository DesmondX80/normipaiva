extends RefCounted
## Santun hommat: kun mökillä on oltu yksi yö, isäntä Santtu alkaa antaa päivän hommia (mökin aamulappu).
## Joka aamu arvotaan HOMMIA_N hommaa ja Santun hermot (0–100) alkavat kiristyä sitä nopeammin, mitä enemmän
## hommia on tekemättä. Tehty homma rauhoittaa. Täysillä hermoilla tulee lähtö: Pekan kyydillä kotiin ja yhden
## tähden arvostelu. Kaikki tehty: palkinto ja viiden tähden arvostelu. Pelilogiikka main.gd:ssä (_hommat_*).
## Santtu tulee paikalle kommentoimaan jokaista hommaa (mokki.gd santtu_visit, minipeleissä katsojana).

const Mokki := preload("res://scripts/mokki.gd")

## Arvostelun tähdet hommien mukaan: kaikki tehty 5, vähintään puolet 3, muuten 1.
func stars_now() -> int:
	if all_done():
		return 5
	return 3 if done.size() * 2 >= tasks.size() else 1


## Hommat: lappu = rivi Santun aamulapussa, spot = missä homma tehdään (Santtu tulee sinne katsomaan).
const TASKS := {
	"puut": {"lappu": "Saunapuut: sahaa ja halko 8 halkoa (puupaikka kesäkeittiön takana)", "nimi": "Saunapuut",
		"spot": Mokki.PUU_CHOP_LOCAL},
	"nurmi": {"lappu": "Leikkaa päädyn nurmikko (leikkuri mökin päädyssä)", "nimi": "Nurmikko",
		"spot": Mokki.LAWN_MOWER_LOCAL},
	"savusauna": {"lappu": "Lämmitä savusauna: sylit halkopinosta, ja savut pihalle ennen löylyä", "nimi": "Savusauna",
		"spot": Mokki.SAUNA_LOCAL},
	"huussi": {"lappu": "Tyhjennä huussi kompostiin ja käännä komposti", "nimi": "Huussi",
		"spot": Mokki.HUUSSI_LOCAL},
	"laituri": {"lappu": "Vaihda laiturin lahot laudat ja naulaa uudet", "nimi": "Laituri",
		"spot": Mokki.DOCK_FIX_LOCAL},
	"ranni": {"lappu": "Putsaa rännit ja sammaleet katolta (tikkaat takaseinällä)", "nimi": "Rännit",
		"spot": Mokki.LADDER_LOCAL},
	"ampiaiset": {"lappu": "Hävitä ampiaispesä saunan terassin räystäästä", "nimi": "Ampiaispesä",
		"spot": Mokki.WASP_STAND_LOCAL},
	"kahvi": {"lappu": "Keitä mulle kahvit, tuo kuppi pihalle ja tiskaa astiat", "nimi": "Kahvit ja tiskit",
		"spot": Mokki.SANTTU_LOCAL},
	"palju": {"lappu": "Tyhjennä ja pese palju, täytä pumpulla järvestä", "nimi": "Palju",
		"spot": Mokki.TUB_LOCAL},
	"savustus": {"lappu": "Savusta jotain hyvää kesäkeittiön savustimessa", "nimi": "Savustus",
		"spot": Mokki.KITCHEN_LOCAL},
	"metsastys": {"lappu": "Hae riistaa metsästyslavalta (ei hirveä!)", "nimi": "Metsästys",
		"spot": Mokki.HUNT_LOCAL},
	"pa": {"lappu": "PA:n kytkennät on sekaisin, korjaa ne tuvassa", "nimi": "PA-laitteet",
		"spot": Mokki.COTTAGE_DOOR_SPOT},
	"saunakorjaus": {"lappu": "Korjaa savusauna: uudet kiuaskivet rannalta, lauteiden laudat, seinät tervaan, savuluukku ja ovi",
		"nimi": "Savusaunan korjaus", "spot": Mokki.KORJAUS_IN_LOCAL},
}
## Korjattu savusauna ei enää tarvitse korjausta (main.gd asettaa).
var sauna_fixed := false
## Hommia päivässä: toisena mökkipäivänä 3, siitä eteenpäin 4.
const HOMMIA_N := [3, 4]
## Hermot nousevat sekunnissa tekemätöntä hommaa kohden (4 hommaa = noin 12 min pelivaraa).
const HERMO_RATE := 0.035
const HERMO_DONE := 18.0  # tehty homma rauhoittaa
const HERMO_SLEEP := 45.0  # nukkumaan hommat kesken
const HERMO_LEAVE := 20.0  # mopolla Siitariin hommat kesken
const HERMO_BEER := 20.0  # kalja Santulle
const HERMO_MAX := 100.0
## Hermojen rajat (huomautus, kireä, viimeinen varoitus).
const LEVELS := [35.0, 60.0, 85.0]

## Repliikit hommittain: anna (aamulla tai kysyttäessä), tulee (Santtu tulee katsomaan), kesken (kommentit
## homman aikana), valmis (homma tehty), huuto (muistutus kaukaa, kun homma odottaa).
const LINES := {
	"saunakorjaus": {
		"anna": "Savusauna on retuperällä: kiuaskivet rapautunu, lauteet laholla, seinät kaipaa tervaa ja räppänä on jumissa. Kivikasa on rannassa.",
		"tulee": ["Mää tuun kattomaan. Tuo sauna on mun vaarin tekemä.", "Varovasti, se on vanha sauna."],
		"kesken": ["Kiuas ensin, ilman sitä ei oo saunaa.", "Terva tuoksuu! Niin pitääkin.", "Räppänä pitää saada auki, muuten savu jää sisään.",
			"Hyvä, hyvä. Vaari ois ylpeä."],
		"valmis": "Savusauna on ku uus! Lämpiää ja tuulettuu niinku pitää.",
		"huuto": ["Se savusauna ei korjaannu itestään!", "Kiuaskivet on rannan kivikasassa!"],
	},
	"puut": {
		"anna": "Halkopino hupenee. Sahaa ja halko, niin saunassa riittää lämpöä.",
		"tulee": ["No niin, katotaan miten kaupunkilainen sahaa.", "Mää tuun kattomaan, ettei mee varpaat."],
		"kesken": ["Ei sitä noin hakata!", "Reilu kolmekymmentä senttiä on hyvä pölkky.", "Kirves on terävä. Viime kesänä teroitettu.",
			"Kuivaa koivua. Halkeaa ku ajatus."],
		"valmis": "Nyt on saunapuita. Ei tarvi talvella palella.",
		"huuto": ["Se halkopino ei kasva katsomalla!", "Puupaikalla on saha ja kirves valmiina."],
	},
	"nurmi": {
		"anna": "Päädyn nurmikko on ku heinäpelto. Leikkuri on päädyssä, vanha mutta käy.",
		"tulee": ["Vedä naru kunnolla, se on vanha kone.", "Mää kattelen tästä vierestä."],
		"kesken": ["Suoria rivejä! Ei mitään kiemuroita.", "Kivistä varo, terä on ainut.", "Jätit raidan väliin. Tuolta!",
			"Ei se nopeammin leikkaa, vaikka juokset."],
		"valmis": "Nyt näyttää pihalta. Airbnb-kuviin kelpaa.",
		"huuto": ["Nurmikko ei leikkaa itseään!", "Leikkuri odottaa päädyssä!"],
	},
	"savusauna": {
		"anna": "Savusauna pitää lämmittää kunnolla. Pesä täyteen, ja savut pihalle ennen ku mennään.",
		"tulee": ["Lämmität savusaunaa? Mää katon vierestä, ettei pala koko sauna.", "Savusaunassa on tarkkuutta."],
		"kesken": ["Lisää puuta, ettei tuli sammu!", "Ei liikaa kerralla, kiuas halkeaa.", "Savu kertoo, miten lämpiää.",
			"Älä mene sinne vielä, siellä on häkää!"],
		"valmis": "Savut ulkona ja kiuas kuuma. Tuosta tulee hyvät löylyt.",
		"huuto": ["Savusauna ei lämpiä itestään!", "Sylit on halkopinossa kesäkeittiön vieressä."],
	},
	"huussi": {
		"anna": "Huussi on täynnä. Sanko takaluukusta kompostiin, ja komposti talikolla ympäri.",
		"tulee": ["Pidä sanko suorassa, ettei tule kengille.", "Mää pysyn tässä tuulen puolella."],
		"kesken": ["Ei juosta sangon kanssa!", "Kävele rauhassa, ei tää oo kilpailu.", "Komposti kiittää.",
			"Tää on sitä oikeeta mökkielämää."],
		"valmis": "Huussi tyhjä ja komposti käännetty. Mies tekee mitä mies tekee.",
		"huuto": ["Se huussi ei tyhjene katsomalla!", "Sanko on huussin takaluukussa!"],
	},
	"laituri": {
		"anna": "Laiturissa on lahoja lautoja. Uudet laudat ja naulat on laiturilla valmiina.",
		"tulee": ["Naula päähän, ei peukaloon.", "Mää tuun kattomaan. Tuo laituri on mun ylpeys."],
		"kesken": ["Ei sitä noin hakata!", "Pitkät vedot vasaralla, ranne rennoksi.", "Naula meni vinoon. Pois ja uus!",
			"Peukalo ei oo naula."],
		"valmis": "Laituri kantaa taas. Nyt voi vieraat kävellä huoletta.",
		"huuto": ["Laiturissa on vielä lahot laudat!", "Vasara on laiturilla!"],
	},
	"ranni": {
		"anna": "Rännit on täynnä lehtiä ja katolla sammalta. Tikkaat on takaseinällä.",
		"tulee": ["Mää pidän tikkaista kiinni. Tai en pidä, mutta katon.", "Älä kurottele liikaa!"],
		"kesken": ["Varovasti siellä!", "Tikkaat heiluu! Pidä tasapaino!", "Lehdet maahan, ei mun päähän.",
			"Sammal irti harjalla, ei sormilla."],
		"valmis": "Rännit vetää taas. Hyvä ettet tippunu.",
		"huuto": ["Rännit on vielä tukossa!", "Tikkaat odottaa takaseinällä!"],
	},
	"ampiaiset": {
		"anna": "Saunan terassin räystäässä on ampiaispesä. Myrkky on saunan penkillä.",
		"tulee": ["Mää kattelen tästä vähän kauempaa.", "Rauhallisesti. Ne haistaa pelon."],
		"kesken": ["Suihkuta suoraan pesän suuaukkoon!", "Älä huido, ne suuttuu!", "Mää en tuu yhtään lähemmäs.",
			"Ne on vihasia, kato taaksesi!"],
		"valmis": "Pesä alas! Nyt voi saunoa ilman pistoja.",
		"huuto": ["Se ampiaispesä on vieläkin siellä!", "Myrkky on saunan penkillä!"],
	},
	"kahvi": {
		"anna": "Keitä mulle kahvit, musta ei sokeria. Tuo kuppi pihalle. Ja tiskit odottaa tiskipöydällä.",
		"tulee": ["Kahvia! Kävele, älä juokse.", "Kuppi suorassa!"],
		"kesken": ["Tiskit pitää tiskata, ei piilottaa kaappiin.", "Varo mummon astiastoa!", "Kahvit ensin, sitten tiskit."],
		"valmis": "Kahvit juotu ja astiat puhtaana. Tää on hyvä vieras.",
		"huuto": ["Kahvit on vielä keittämättä!", "Tiskit odottaa!"],
	},
	"palju": {
		"anna": "Palju pitää tyhjentää ja pestä, ja täyttää pumpulla järvestä. Pumppu on rannassa laiturin vieressä.",
		"tulee": ["Mää tuun kattomaan, että pestään kunnolla.", "Levät pois reunoilta!"],
		"kesken": ["Harjaa reunat kunnolla!", "Muista sammuttaa pumppu ajoissa!", "Venttiili on kyljessä.",
			"Ei sitä järveä tarvi kokonaan siirtää."],
		"valmis": "Palju puhdas ja täynnä. Kamiina vaan päälle illalla.",
		"huuto": ["Palju on vielä likainen!", "Pumppu on laiturin vieressä rannassa!"],
	},
	"savustus": {
		"anna": "Savusta jotain hyvää. Kalaa laiturilta tai riistaa metsästä, ja savustin kuumaksi.",
		"tulee": ["Mää tuun haistelemaan.", "Lämpö kohdalleen, ei karrelle!"],
		"kesken": ["Kahdeksankymmentä–sataankakskymmentä astetta, muista.", "Ei liikaa halkoja, se käristyy!",
			"Savustin on mun lempilapsi."],
		"valmis": "Kullankeltaista! Tällä pärjää viikon.",
		"huuto": ["Savustin on kylmä!", "Kalaa ja riistaa savustimeen!"],
	},
	"metsastys": {
		"anna": "Metsästyslavalta riistaa, jänis tai metso. Hirveen ei oo lupaa!",
		"tulee": ["Mää tuun mukaan. Hiljaa ollaan.", "Patruunoita on kahdeksan, ei tuhlata."],
		"kesken": ["Rauhassa tähtää.", "Hirveen ei sitte ammuta!"],
		"valmis": "Saalista! Savustimeen vaan.",
		"huuto": ["Metsästyslava odottaa riistapolulla!", "Saalista ei oo vielä tullu!"],
	},
	"pa": {
		"anna": "Joku sotki PA:n johdot. Kytke ne uusiks tuvassa, mikseri ensin ja pääte viimeisenä.",
		"tulee": ["Mää tuun kattomaan, ettei kaiuttimet paukahda.", "Pääte päälle viimeisenä!"],
		"kesken": ["Mikin kanava kiinni, muuten kiljuu!", "Speakonit kaiuttimiin!"],
		"valmis": "Nyt soi! Vanhat keikkakamat toimii vieläkin.",
		"huuto": ["PA on vieläkin sekaisin!", "PA-kamat odottaa tuvassa!"],
	},
}
## Santun hermojen mukaiset huudot kuistilta (hommia tekemättä).
const HERMO_LINES := [
	["Joko ne hommat alkaa? Mää kattelen täältä.", "Superhost en oo ilmaseks.", "Hommat ei tee itteään."],
	["Kahvikin loppu, ku joku vaan makoilee.", "Tää ei oo mikään hotelli. Hommiin!", "Mää alan kohta hermostua."],
	["Viimenen varotus: hommat tehdään tai lähetään!", "Pekka on yhen puhelun päässä!", "Mää soitan kohta Päiville."],
]
## Santun arvostelut (tähdet -> teksti).
const REVIEWS := {
	1: ["Vieras ei tehnyt mitään. Makoili ja söi jääkaapin tyhjäksi. Ei suositella.",
		"Laiskin vieras viiteen vuoteen. Pekka tuli hakemaan.", "Hommat jäi tekemättä. Superhost suosittelee kotiin jäämistä."],
	3: ["Teki osan hommista, loput jäi. Ihan kelpo vieras.", "Hommat puolittain tehty. Kahvit juotiin."],
	5: ["Paras vieras ikinä! Teki kaikki hommat ja vielä pyytämättä kehui savustinta.",
		"Viisi tähteä! Huussi tyhjä, palju puhdas ja laituri kantaa.", "Tervetuloa uudestaan! Mökki on paremmassa kunnossa ku ennen."],
}
## Kalja Santulle: Santtu tekee yhden homman (huonosti) ja leppyy.
const BEER_LINES := [
	"No anna tänne. Mää hoidan tän. Mutta älä kerro kellekään.",
	"Kalja ja homma vaihtaa omistajaa. Tämä jää meidän välille.",
	"No olkoon. Teen ite, ku kerran kaljan toit. Puolittain.",
]
## Mopolla Siitariin hommat kesken: Santtu huutaa perään ja soittaa Päiville.
const LEAVE_LINES := ["Mihinkäs sitä? Hommat kesken!", "Siitariin, ja hommat tekemättä! Mää soitan Päiville!",
	"Ai Vaalaan? No mää soitan kyllä Päiville."]
const PAIVI_SANTTU_CALLS := [
	"\"Santtu soitti. Se sano, että sää lähit baariin ja hommat jäi tekemättä. Hävettää!\"",
	"\"Mökin isäntä soitti mulle. Mitä sää siellä Siitarissa teet, ku pitäs olla hommissa?!\"",
	"\"Santtu kerto kaiken. Huomenna on sitte kotona hommia, usko pois!\"",
]

var tasks: Array = []  # päivän hommat (id:t)
var done: Array = []
var hermo := 0.0
var active := false
## Mökillä vietetyt yöt putkeen (kotiinlähtö nollaa). Hommat alkavat ensimmäisen yön jälkeen.
var nights := 0
var beer_used := false
var snitched := false  # Santtu soitti jo tänään Päiville
## Hommien välivaiheet: id -> arvo (esim. "huussi_sangot", "kahvi_vietu").
var progress := {}
## Santun arvostelut: [{day, stars, text}]. Tallentuu.
var reviews: Array = []
## Häädetty mökiltä tänä päivänä (Pekka ei vie takaisin ennen huomista).
var banned_day := -1
## Eilisistä keskeneräisistä hommista jäi kaunaa: osa hermoista siirtyy seuraavaan päivään.
var carry := 0.0
var _hermo_level := -1


## Uusi päivä mökillä: hommat arvotaan, jos on oltu jo yö.
func start_day() -> void:
	tasks.clear()
	done.clear()
	progress.clear()
	hermo = carry
	carry = 0.0
	beer_used = false
	snitched = false
	_hermo_level = -1
	active = nights >= 1
	if not active:
		return
	var ids: Array = TASKS.keys()
	if sauna_fixed:
		ids.erase("saunakorjaus")
	ids.shuffle()
	tasks = ids.slice(0, HOMMIA_N[mini(nights - 1, HOMMIA_N.size() - 1)])


func stop() -> void:
	carry = 0.0
	active = false
	tasks.clear()
	done.clear()
	progress.clear()
	hermo = 0.0


## Onko homma tänään tehtävänä ja vielä tekemättä.
func pending(id: String) -> bool:
	return active and id in tasks and not id in done


func undone() -> Array:
	return tasks.filter(func(t): return not t in done)


func all_done() -> bool:
	return active and undone().is_empty()


## Homma tehty: palauttaa true, jos se oli tekemättä.
func complete(id: String) -> bool:
	if not pending(id):
		return false
	done.append(id)
	hermo = maxf(0.0, hermo - HERMO_DONE)
	return true


func add_hermo(v: float) -> void:
	hermo = clampf(hermo + v, 0.0, HERMO_MAX)


## Hermot kiristyvät tekemättömien hommien mukaan. Palauttaa uuden hermotason, jos raja ylittyi (muuten -1).
func tick(delta: float) -> int:
	if not active:
		return -1
	hermo = minf(HERMO_MAX, hermo + HERMO_RATE * undone().size() * delta)
	var lv := level()
	if lv > _hermo_level:
		_hermo_level = lv
		return lv
	_hermo_level = mini(_hermo_level, lv)
	return -1


## Hermotaso: -1 = rauhallinen, 0 = huomauttelee, 1 = kireä, 2 = viimeinen varoitus.
func level() -> int:
	var lv := -1
	for i in LEVELS.size():
		if hermo >= LEVELS[i]:
			lv = i
	return lv


func furious() -> bool:
	return active and hermo >= HERMO_MAX


func mood() -> String:
	return ["rauhallinen", "huomauttelee", "kireä", "räjähtämäisillään"][level() + 1]


## Hermot HUD:iin prosentteina.
func bar() -> String:
	return "%d %%" % roundi(hermo)


## Kalja Santulle: Santtu tekee helpoimman tekemättömän homman. Palauttaa tehdyn homman id:n tai "".
func beer_help() -> String:
	if beer_used or not active:
		return ""
	var left := undone()
	if left.is_empty():
		return ""
	beer_used = true
	var id: String = left.pick_random()
	done.append(id)
	hermo = maxf(0.0, hermo - HERMO_BEER)
	return id


func add_review(day: int, stars: int) -> String:
	var text: String = REVIEWS[stars].pick_random()
	reviews.append({"day": day, "stars": stars, "text": text})
	return text


func review_avg() -> float:
	if reviews.is_empty():
		return 0.0
	var s := 0.0
	for r in reviews:
		s += r.stars
	return s / reviews.size()


static func stars(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(5 - n)


## Rivit Santun aamulappuun ja reppuun.
func lappu_rows(check := false) -> Array:
	var out: Array = []
	for id in tasks:
		out.append(("  • " if not check else "") + TASKS[id].lappu + ("  ✔" if check and id in done else ""))
	return out


func line(id: String, kind: String) -> String:
	var v = LINES[id][kind]
	return v.pick_random() if v is Array else v


# --- Santun kommentit puupaikan minipeleihin (saw_game.gd, chop_game.gd: Raimon ja Veikon tilalla) ----------

const SAW_LINES := {
	"start": [["santtu", "Saha on terävä. Mää teroitin sen ite."], ["santtu", "Merkkaa ensin mitta. Reilu kolmekymmentä senttiä."],
		["santtu", "Pitkät vedot, ei mitään hätäilyä."]],
	"pukki": [["santtu", "Ei pukin välistä! Ulkopuolelta sahataan."], ["santtu", "Sahaat kohta mun pukin poikki."]],
	"sliver": [["santtu", "Se on lastu, ei pölkky."], ["santtu", "Tuosta ei saa ku tikun."]],
	"bind": [["santtu", "Saha kiilaa! Suoraan, suoraan."], ["santtu", "Ei sitä noin väännetä!"], ["santtu", "Vinoon menee. Oiota."]],
	"frantic": [["santtu", "Rauhassa! Ei tää oo kilpailu."], ["santtu", "Ei sitä noin hakata! Pitkät vedot."], ["santtu", "Saha hyppää, ku sää riuhot."]],
	"halfway": [["santtu", "Puolivälissä. Samaan malliin."], ["santtu", "Hyvin menee."]],
	"perfect_len": [["santtu", "Mittanauhalla ei ois saanu parempaa."], ["santtu", "Juuri savusaunan pesään."]],
	"good_len": [["santtu", "Hyvä mitta. Mahtuu pesään."], ["santtu", "Siitä tulee neljä kunnon halkoa."]],
	"short": [["santtu", "Lyhyt tuli. No, palaa lyhytkin."], ["santtu", "Tulitikkuja sahaat?"]],
	"long": [["santtu", "Pitkä pölkky. Ei mahdu pesään."], ["santtu", "Tuo on puolikas tukki."]],
	"crooked": [["santtu", "Vinoon meni. Muista halkoessa kumpi pää alas."], ["santtu", "Vino pää. Ei se pesässä haittaa."]],
	"straight": [["santtu", "Suora ku viivotin."], ["santtu", "Suora leikkaus. Airbnb-kuviin kelpais."]],
	"new_log": [["santtu", "Tukki loppu. Uus pinosta."], ["santtu", "Seuraava tukki."]],
	"gust": [["santtu", "Puuska! Pidä saha suorassa."], ["santtu", "Likaselta puhaltaa taas."]],
	"idle": [["santtu", "Sahaa, sahaa. Ei se itestään katkea."], ["santtu", "Joko kahvitauko? Ei vielä."]],
}
const CHOP_LINES := {
	"start": [["santtu", "Tasainen pää alas, vino ylös."], ["santtu", "Kirves on terävä. Varpaat kauemmas."],
		["santtu", "Mää tuun kattomaan, ettei mee varpaat."]],
	"placed": [["santtu", "Hyvin asetettu."], ["santtu", "Suoraan keskelle. Oppii se."]],
	"wrong_end": [["santtu", "Väärin päin! Vino pää ylös."], ["santtu", "Ei se noin päin pysy."]],
	"edge": [["santtu", "Keskelle, keskelle! Ei reunalle."], ["santtu", "Reunalla ei pysy mikään."]],
	"no_pile": [["santtu", "Ei oo pölkkyjä. Sahaa ensin pukilla."], ["santtu", "Pölkyt loppu. Saha on pukilla."]],
	"clean": [["santtu", "Kunnon isku!"], ["santtu", "Kuivaa koivua. Halkeaa ku ajatus."], ["santtu", "Siinä on miestä."]],
	"perfect": [["santtu", "Ristiin halki yhellä iskulla! Tuota en oo nähny sitte Oulun yliopiston."],
		["santtu", "Täydellinen. Tästä kirjotan arvosteluun."]],
	"stuck": [["santtu", "Jäi kiinni. Nykäise irti ja uusiks."], ["santtu", "Ei sitä noin hakata! Keskemmälle."]],
	"stuck_split": [["santtu", "Sitkeä oli, mutta periksi antoi."], ["santtu", "Kahella iskulla. Hyväksytään."]],
	"knock": [["santtu", "Syrjään meni ja pölkky lensi. Nosta takasin."], ["santtu", "Varo mun ikkunoita!"]],
	"block": [["santtu", "Pölkkyyn löit. Se on halkaisupölli, ei vihollinen."], ["santtu", "Ohi. Tähtää pölkkyyn."]],
	"ground": [["santtu", "Maahan meni! Varpaat tallella?"], ["santtu", "Ei sitä noin hakata! Kirves tylsyy."]],
	"gust": [["santtu", "Puuska! Odota hetki."], ["santtu", "Tuulee järveltä."]],
	"idle": [["santtu", "Ei ne halot itestään halkea."], ["santtu", "Saunapuut ei tee itteään."]],
	"done": [["santtu", "Pölkyt halottu. Hyvä saunapuu."]],
}


# --- Kannettavat esineet (on_foot.gd set_held) ------------------------------------------

const B := preload("res://scripts/build.gd")


## Huussin sanko, halkosyli tai kahvikuppi käteen.
static func held_model(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"sanko":
			B.mesh(n, B.cyl(0.14, 0.11, 0.26, 12), Vector3(0, -0.2, 0), Color(0.55, 0.56, 0.58))
			B.mesh(n, B.cyl(0.13, 0.13, 0.01, 12), Vector3(0, -0.08, 0), Color(0.3, 0.22, 0.1))
			B.tube(n, Vector3(-0.13, -0.08, 0), Vector3(0, 0.02, 0), 0.006, Color(0.4, 0.4, 0.42))
			B.tube(n, Vector3(0, 0.02, 0), Vector3(0.13, -0.08, 0), 0.006, Color(0.4, 0.4, 0.42))
		"halot":
			for k in 5:
				var h := B.mesh(n, B.cyl(0.06, 0.06, 0.4, 5), Vector3(-0.1 + (k % 3) * 0.1, -0.05 + (k / 3) * 0.1, -0.12),
					Color(0.72, 0.58, 0.38) if k % 2 else Color(0.62, 0.48, 0.3))
				h.rotation.z = PI / 2.0
		"kahvi":
			B.mesh(n, B.cyl(0.04, 0.035, 0.09, 10), Vector3(0, -0.04, -0.04), Color(0.95, 0.95, 0.92))
			B.mesh(n, B.cyl(0.036, 0.036, 0.005, 10), Vector3(0, 0.0, -0.04), Color(0.15, 0.08, 0.03))
	return n
