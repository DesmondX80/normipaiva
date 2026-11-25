extends RefCounted
## Kolmiomittaus (#255): Sytkäri-sovelluksen mätsi ei kerro osoitettaan, vain etäisyyden ("350 m päässä"). Pelaaja ja
## kaksi kaveria mittaavat etäisyyden eri paikoista, Esa piirtää ympyrät paperikarttaan, ja ympyröiden
## leikkauksessa on naisen talo. Sovellus pyöristää etäisyyden (lähempänä tarkemmin), joten yksi kierros antaa vain
## alueen: lisämittaukset lähempää tarkentavat sitä. Väärällä ovella avaa joku muu. Kolme kolmiomittaajaa tuovat
## kukin yhden lahjan (mansikat, kermavaahto, ruusut) kuin itämaan tietäjät; ilman kaikkia kolmea ovi ei aukea.
## Ilta päättyy erikoissääntöiseen Rasvanappiin (rasvanappi_game.gd rules) ja aamu onnelliseen loppuun.
## Kohde: Saloinen (Joni ja Esa, Minttu). Luvun 6 toinen kohde
## "koti" (Kesäheila -96) johtaa pelaajan omalle ovelle, jossa odottaa Päivi.
## Tämä tiedosto on tehtävän tila ja data; main.gd kytkee sen maailmaan (_kolmio_*), Sytkäri on sytkari.gd ja
## ovi- ja aamukohtaukset kolmio_kohtaus.gd.
##
## Koordinaatit: maailman x/z (main.gd world).

## Mittauspisteiden vähimmäisväli: samasta paikasta mitattu ympyrä ei kerro mitään uutta.
const MIN_GAP := 35.0
## Kaverin etämittaus (Esa kirkolta) tulee tekstiviestinä tämän ajan päästä (s).
const REMOTE_DELAY := 40.0
## Oma lahja kaupan tiskiltä (ruusut).
const GIFT_PRICE := 9.0
## Onnellinen loppu tiloihin (day_stats.gd: suurempi on parempi): maine = moraali, stressi helpottaa, mielihyvä = vireys.
const END_MORAALI := 0.25
const END_STRESSI := 0.3
const END_VIREYS := 0.3
## Aamun maito: unohtunut maito kotiin tultaessa (Päivi motkottaa).
const MAITO_STRESSI := -0.25
const MAITO_MORAALI := -0.1

const SITES := {
	"saloinen": {
		"woman": "Minttu", "gen": "Mintun", "talker": "kolmio_saloinen", "friends": ["Joni", "Esa"],
		"gift_me": "ruusut", "gift_part": "ruusuja", "start_place": "kaupan parkkipaikalla",
		"remote": "Esa", "remote_place": "kirkon parkkipaikalta",
		"gifts": [["Esa", "mansikat"], ["Joni", "kermavaahdon"], ["Sinä", "ruusut"]],
		"age": 34, "bio": "Etsi minut, jos osaat ;) Tuo jotain makeaa.", "job": "Kampaaja, Saloinen",
		"ending": "minttu",
	},
	# Luku 6 "Päivi epäilee" (#326): mätsi tulee vasta, kun Päivin huipennus on auki (rikos/paivi.gd huipennus_auki).
	# Profiilikuva on Päivi kesältä -96 Saloisten lavalla (sytkari.gd), ja ympyrät leikkaavat pelaajan oman kodin.
	# Ei lahjoja: ovella Päivi itse pitää kerma- ja mansikkalaatikkoa (kolmio_kohtaus.gd). age 0 = otsikossa paikka.
	"koti": {
		"woman": "Kesäheila -96", "gen": "Kesäheilan", "talker": "kolmio_koti", "friends": ["Joni", "Esa"],
		"gift_me": "", "gift_part": "", "start_place": "kaupan parkkipaikalla",
		"remote": "Esa", "remote_place": "kirkon parkkipaikalta",
		"gifts": [],
		"age": 0, "bio": "Muistatko lavan? Mää muistan. Tuo kermaa ja mansikoita, niin kuin silloin.", "job": "Saloinen",
		"ending": "kulissit",
	},
}

## Väärät ovet (main.gd valitsee talot): kuka avaa, mitä sanoo ja mitä sen jälkeen tapahtuu.
const WRONG_DOORS := {
	"saloinen": [
		{"who": "Mummo kepin kanssa", "line": "Mansikoita ja ruusuja? Kolme miestä? No tulkaa sisään vaan, mutta kengät pois.",
			"after": "Perääntyt portaita alas ennen kuin keppi nousee."},
		{"who": "Pannu-Sulo", "line": "Täällä ei oo mitään Minttua. Täällä on Sulo, ja Sulo on siskon saunalla. Ostatko kanisterin?",
			"after": "Esa tekstaa: \"Ympyrä meni ohi. Mittaa lähempää.\""},
		{"who": "Pieni poika", "line": "ÄITI! Täällä on taas joku setä ruusujen kanssa!",
			"after": "Ovi pamahtaa kiinni. Jossain sisällä haukkuu koira."},
	],
	"koti": [
		{"who": "Mummo kepin kanssa", "line": "Kesäheilaa etsitte? Kolme miestä ja harppi? Päivihän se asuu tuossa naapurissa!",
			"after": "Perääntyt portaita alas. Mummo jää ovelle katsomaan, mihin suuntaan lähdette."},
		{"who": "Pannu-Sulo", "line": "Täällä ei oo kesäheiloja. Täällä on Sulo, ja Sulon kesäheila oli kanisteri. Ostatko?",
			"after": "Esa tekstaa: \"Ympyrä meni ohi. Mittaa lähempää. Ja kato tarkkaan, kenen pihassa seisot.\""},
		{"who": "Pieni poika", "line": "ÄITI! Täällä on se setä, joka asuu tuolla isossa tiilitalossa!",
			"after": "Ovi pamahtaa kiinni. Joni: \"Se tunsi sut. Huono merkki.\""},
	],
}

## Kaverien jutut (puhekuplat ja Mitä kuuluu?). Joni ja Esa.
const LINES := {
	"saloinen": [
		"Joni: Tää rinkka on testattu Hailuodon golfkentällä. Kolme Sandelsia, yks pallo. Pallo hävis.",
		"Esa: Kolme ympyrää ja yks leikkauspiste. Ihan ku metsoja kuunnellessa, siinä missä soitimet risteää, siinä on kana.",
		"Joni: Tänään meni pari ylikin. Mutta draivi oli kaunis.",
		"Esa: Erämies ei tarvi lautasta. Eikä lusikkaa. Eikä paitaa.",
		"Joni: Kattokaa, Sandelsin kyljessä lukee mitä kenraali sano. Ei se sanonu mitään kolmiomittauksesta, mutta varmaan aatteli.",
		"Esa: Harppi on erämiehen paras kaveri. Kompassi toinen. Kolmas on mansikkapaikka.",
		"Joni: Hcp kakskytkuus, mutta Sytkärissä mää oon kymppi.",
		"Esa: Mää laitan illalla ruokaa. Nuotiolla tai naisen keittiössä, kumpi vaan.",
		"Joni: Rinkka on jesarilla kasassa. Jesari pitää kaiken kasassa, paitsi mun golfkierroksen.",
	],
	"koti": [
		"Esa: Kesäheila -96. Erämies muistaa jokaisen kesän. Tää kesä oli kuiva.",
		"Joni: Saloinen taas? Mää luulin, että täällä on kaikki jo kolmiomitattu.",
		"Esa: Ympyrät vetää tännepäin. Ihan ku metso palais vanhalle soitimelle.",
		"Joni: Toi profiilikuva. Mää oon nähny tuon hatun jossain.",
		"Esa: Harppi ei valehtele. Mutta joskus se näyttää paikan, jota ei haluais nähdä.",
		"Joni: Hcp kakskytkuus, mutta tää tuntuu jo vesiesteeltä.",
	],
}


## Mittauksen kommentit (tekstiviesti kaverilta joka mittauksen jälkeen), kierrätetään järjestyksessä.
const MEASURE_LINES := {
	"saloinen": [
		"Esa: Hyvä. Merkkaan harpilla. Erämies ei arvaa, erämies mittaa.",
		"Joni: Tää on niinku golffia: lähestymislyönti ensin, sitten putti.",
		"Esa: Ympyrät risteää. Siellä se kana on.",
		"Joni: Rinkassa on vielä kaks Sandelsia. Mittaa sää, mää vahdin kermavaahtoa.",
		"Esa: Lähempää mitattu ympyrä on terävämpi. Ihan ku jäljet lumessa.",
	],
	"koti": [
		"Esa: Merkkaan harpilla. Ympyrä kulkee kumman läheltä sun kotia.",
		"Joni: Tää on niinku golffia, mutta reikä on sun omalla pihalla.",
		"Esa: Kolme ympyrää ja leikkauspiste. Sää tiedät kyllä jo, missä se on.",
		"Joni: Mää en sano mitään. Mää vaan kannan rinkkaa.",
		"Esa: Jäljet lumessa johtaa aina kotiin. Erämiehen sääntö.",
	],
}

## Päivin puhelu kesken Rasvanapin.
const PAIVI_CALL := [["Päivi", "Missä sää oot?"], ["Sinä", "Kolmiomittaamassa."], ["Päivi", "No tuo maitoa tullessas."]]

## Erikoissääntöinen Rasvanappi naisen pimennetyssä olohuoneessa (rasvanappi_game.gd people ja rules): viisi pelaajaa
## (pelaaja, nainen, kaksi kaveria ja naisen ystävätär), kermavaahto margariinin tilalla, mansikka oikeasta arvauksesta.
## Tunnusäänet: naisen kikatus tai matala nauru, Esan hyräily ja Jonin golfjutut.
const RASVA_PEOPLE := {
	"saloinen": [
		{"id": "minttu", "name": "Minttu", "gen": "Mintun", "desc": "kikattaa", "bulk": 0.9, "col": Color(1.0, 0.5, 0.35),
			"tics": ["Hihii!", "Kuka siellä kermassa?", "Hihihii, löysitte mut!", "Mansikkaa kellekään?"],
			"snd": ["grunt", 1.8], "lick": "Hihii! Makeaa!", "towel": Color(1.0, 0.8, 0.25), "woman": true,
			"look": {"hair": "long", "hair_col": Color(0.72, 0.2, 0.07), "skin": Color(1.0, 0.9, 0.84), "bust": 2.7, "curves": 1.0,
				"curls": true}},
		{"id": "joni", "name": "Joni", "gen": "Jonin", "desc": "kertoo golfjuttuja", "bulk": 1.0, "col": Color(0.6, 0.8, 1.0),
			"tics": ["Tää on niinku pimeä par kolmonen.", "Fore! FORE!", "Hcp ei tässä auta.", "Mun rinkka jäi eteiseen, älkää astuko."],
			"snd": ["grunt", 1.0], "lick": "Birdie.", "towel": Color(0.2, 0.45, 0.8),
			"look": {"hair": "parted", "hair_col": Color(0.07, 0.05, 0.04), "skin": Color(0.98, 0.84, 0.74)}},
		{"id": "esa", "name": "Esa", "gen": "Esan", "desc": "hyräilee", "bulk": 1.1, "col": Color(0.55, 0.9, 0.45),
			"tics": ["Hmm-hmm-hmmm…", "Ei tää oo eka kerta, ku mua tökätään pimeässä metsässä.", "♪ Hmm-hmmm ♪", "Metso soitimella… hmm."],
			"snd": ["grunt", 0.85], "lick": "Hmm. Metsämansikkaa.", "towel": Color(0.3, 0.5, 0.25),
			"look": {"hair": "short", "hair_col": Color(0.42, 0.3, 0.18), "beard": true, "skin": Color(0.95, 0.76, 0.64)}},
		{"id": "pirjo", "name": "Pirjo", "gen": "Pirjon", "desc": "huokailee", "bulk": 0.95, "col": Color(0.95, 0.6, 0.8),
			"tics": ["Huoh…", "Minttu, kuka nää on?", "Ai että.", "Huuuoh."],
			"snd": ["groan", 1.4], "lick": "Ai että, kermaa.", "towel": Color(0.9, 0.45, 0.6), "woman": true,
			"look": {"hair": "long", "hair_col": Color(0.6, 0.45, 0.28), "skin": Color(0.97, 0.8, 0.72), "bust": 2.0, "curves": 0.6}},
	],
}
const RASVA_RULES := {
	"saloinen": {"end_quote": "Esa: \"Rasvanapin jälkeen pitää syödä rasvasta.\"",
		"end_lines": ["Minttu sytyttää kynttilän. Kaikki jähmettyvät.", "Joni: \"Tasan par.\""],
		"style": {"olohuone": true, "floor": Color(0.66, 0.5, 0.32), "wall": Color(0.82, 0.72, 0.58),
			"sofa": Color(0.36, 0.45, 0.3), "rug": Color(0.62, 0.2, 0.18)}},
}

## Räsytupin repliikit (tuppi_game.gd, vain aikuisille): rivoja mutta hauskoja. riisuu: id -> [kengät, paita, housut].
const TUPPI_LINES := {
	"saloinen": {
		"alku": ["Räsytuppi. Häviäjät riisuu. Erämies ei häviä.", "Tää on niinku strip-golf, mutta korteilla."],
		"rami": ["Rami! Nyt otetaan tikkiä niinku Joni ottaa mailaa.", "Hihii, rami! Mää haluun nähä Esan karvat."],
		"nolo": ["Nolo. Hiljaa ja varovasti, niinku metsossa.", "Nolo. Kukaan ei ota, kaikki menettää."],
		"tikki": {"joni": ["Birdie!", "Suoraan reikään.", "Hole in one, kulta."], "esa": ["Erämies saalisti.", "Hmm. Mun.",
			"Tää tikki on lihava ku metso."], "minttu": ["Hihii, mun!", "Kato ny, mää otin sen.", "Hihii, tikki kädessä!"]},
		"riisuu": {"joni": ["Golfsukat pois. Hcp nousee.", "Paita pois. Rusketusraja on golfhanskan mallinen.",
			"Housut pois… Älkää kattoko mailakassia."],
			"esa": ["Villasukat pois. Erämies ei tarvi sukkia.", "Paita pois. Erämies ei tarvi paitaakaan.",
			"Housut… Erämies ei tarvi housuja. Hmm."],
			"minttu": ["Sandaalit pois, hihii!", "Hihii, paita pois! Älkää tuijottako, pojat!", "Hihii… nyt on viileä."],
			"pelaaja": ["", "", ""]},
		"kommentti": ["Hihii! Kato ny noita!", "Esa, sulla on enemmän karvaa ku karhulla.", "Tää on parempi ku Rasvanappi.",
			"Fore! Valkoset näkyy!", "Hmm. Kauniit kintut."],
		"voitto": ["Joni ja Esa kalsareissa: pantu tuppeen! Minttu kaataa viimeiset kaljat ja kikattaa koko illan.",
			"Kaverit tupessa! Esa ottaa pyyhkeen ja sanoo, että erämies on aina vähän kalsareissa."],
		"tuppeen": ["Te tupessa! Minttu nauraa kyyneleet silmissä, ja Joni ottaa kuvan kertakäyttökameralla.",
			"Pantu tuppeen kalsareissa. Esa: \"Erämies ei koskaan unohda tätä näkyä.\""],
		"loppu": ["Hihii. No niin, nukkumaan. Kaikki samaan sänkyyn vai?", "Kerma ja mansikat aamulla, pojat."],
	},
}

## Lettukisan repliikit (lettu_game.gd, vain aikuisille). "%s" havio-rivissä = voittajan nimi.
const LETTU_LINES := {
	"saloinen": {
		"alku": ["Lettukisa! Kuka syö eniten, saa kermaa niin paljon ku jaksaa. Ja vähän muutakin, hihii.",
			"Minuutti aikaa, pojat. Kerma suuhun ja nielkää. Ei mussuteta!"],
		"kerma": ["Lisää kermaa! Mää ruiskutan, älkää pyristelkö.", "Kenellä on vielä suu auki? Hihii.",
			"Nielkää, pojat! Mää en jaksa odottaa koko yötä.", "Kuumia lettuja! Varokaa, ne on rasvasia."],
		"tukehtuu": {"joni": ["Hhkk! Kerma meni väärään reikään!", "Fore! Kerma tulee nenästä!"],
			"esa": ["Hhkk… erämies ei niele kaikkea kerralla.", "Kerma nenästä! Ihan ku hirvellä kiima-aikaan."]},
		"tukehtuu_sina": ["Hihii, liian iso suullinen! Kerma tuli nenästä.", "Hitaasti, kulta. Ei kaikkea kerralla."],
		"kommentti": {"joni": ["Tää on ku mailan varsi: liukas ja pitkä.", "Mää oon nielly isompiaki. Golfpalloja siis."],
			"esa": ["Hirvi syö kakskymmentä kiloa päivässä. Mää oon hirvi.", "Kerma suupielessä on erämiehen meikki."]},
		"voitto": ["Sää nielit kaikki. Mää tykkään miehistä, jotka ei jätä mitään lautaselle.",
			"Voittaja nuolee vatkaimen. Tuu tänne, kulta."],
		"havio": ["%s voitti! Voittaja nuolee vatkaimen, ja häviäjät tiskaa kalsareissa.", "%s voitti. Hihii, sulla on kermaa poskessa."],
	},
}

## Löylykisan repliikit (loyly_game.gd, vain aikuisille). "%s" havio-rivissä = voittajan nimi.
const LOYLY_LINES := {
	"saloinen": {
		"alku": ["Löylykisa! Viimeinen lauteilla saa nukkua keskellä. Pyyhkeet tiukalle, pojat, hihii.",
			"Mää heitän, te kestätte. Kuka lähtee ekana, nuolee kiukaan. Ei oikeesti. Ehkä."],
		"heitto": ["Lisää löylyä! Katotaan, kenen pyyhe kestää.", "Hihii, nyt sihisee! Pitäkää kiinni pyyhkeistä.",
			"Toinen kauhallinen. Esa, sun karvat kihartuu.", "Kuumaa? Mää en ees aloittanu."],
		"pakenee": {"joni": ["Mää lähen! Mailat sulaa!", "Fore! Pyyhe jäi, älkää kattoko!"],
			"esa": ["Erämies… lähtee hakemaan… vettä.", "Hmm. Pyyhe jäi. Erämies ei tarvi pyyhettä."]},
		"pakenee_sina": ["Hihii! Pyyhe jäi lauteille, ja kaikki näki. Kaikki.", "Sää lähdit ekana! Ja ilman pyyhettä."],
		"kommentti": {"joni": ["Tää on kuumempi ku Floridan kenttä.", "Mun pallot kiehuu."],
			"esa": ["Erämies saunoo savusaunassa sata kertaa kuumemmassa.", "Hmm. Vasta lämmintä."]},
		"voitto": ["Sää kestit! Tuu alalauteelle, mää heitän sulle henkilökohtasen löylyn.", "Viimeinen lauteilla. Mää tykkään sisukkaista."],
		"havio": ["%s voitti! Ja sun pyyhe makaa vieläkin lauteilla.", "%s kesti pisimpään. Hihii, sun pakarat oli punasemmat ku kiuas."],
	},
}


## Karaoke-illan repliikit ja säkeistöt (ilta_karaoke.gd, vain aikuisille): "sakeet" laulajan id -> neljä riviä
## (omat sanat, laulettavat karaoke_game.gd:n nuottikaistoilla), "nimet_<id>" kappaleen nimi. "%s" = laulajan nimi.
const KARAOKE_LINES := {
	"saloinen": {
		"alku": ["Karaoke! Paras laulaja saa valita, kenen viereen nukkuu. Hihii.", "Mikki on lämmin, pojat. Älkää nuolko sitä."],
		"sakeet": {
			"joni": ["Mää puttasin sun pihalla koko yön", "pallot oli märät ja maila oli kova",
				"Minttu huusi fore ja mää tähtäsin reikään", "Päivi luulee että mää oon kalassa"],
			"pelaaja": ["Päivi soitti yöllä ja kysy missä mää oon", "mittaamassa kulta ihan oikeesti mittaamassa",
				"harppi oli pitkä ja kynä oli terävä", "ympyrät leikkas just sängyn kohdalla"],
			"esa": ["Erämies tuli metsästä harpin kanssa", "kolme ympyrää ja yksi iso keppi",
				"kermaa ja mansikkaa en tarvi lusikkaa", "hirvi kiimassa ei kysy lupaa"]},
		"nimet_joni": ["Hole in one"], "nimet_pelaaja": ["Kolmiomittauksen blues"], "nimet_esa": ["Erämiehen kiima"],
		"kehu": ["Hihii, %s lauloi niin, että mun pikkuhousut lähti kiertoon!", "Kultakurkku! Nyt mää vähän punastun."],
		"pilkka": ["Hihii, %s kuulosti hirveltä, jolla on pallit puristuksissa.", "Naapurit hakkaa seinää. Ei se mitään."],
		"kommentti": {"joni": ["Tää on mun ainoo hole in one tänä vuonna."], "esa": ["Erämies laulaa harvoin. Ja kovaa."]},
		"voitto": ["Sää lauloit parhaiten. Mää valitsen sut, ja Esa nukkuu saunassa.", "Kultakurkku. Tuu tänne, mää kuiskaan sulle jotain."],
		"havio": ["%s voitti! Se nukkuu mun vieressä, ja sää sohvalla mikki kainalossa.", "%s lauloi parhaiten. Hihii, sori."],
	},
}

var state := {}  # kohde -> {stage, rings, remote_t, gift, wrong, done_day}
var maito_day := -1  # päivä, jona Päivi odottaa maitoa (aamu kolmiomittauksen jälkeen)
var _measure_i := {}


func _init() -> void:
	for s in SITES:
		state[s] = _fresh()


func _fresh() -> Dictionary:
	return {"stage": "", "rings": [], "remote_t": -1.0, "gift": false, "wrong": [], "done_day": -1, "illat": 0}


## Iltakivat Rasvanapin jälkeen kiertävässä järjestyksessä (kohde -> lista).
const KIVAT := {"saloinen": ["tuppi", "lettu", "karaoke", "loyly"]}


## Seuraavan illan iltakiva: ensimmäinen ilta on aina Rasvanappi, sen jälkeen KIVAT kiertäen.
func next_kiva(site: String) -> String:
	var s := st(site)
	if s.done_day < 0:
		return "rasvanappi"
	var list: Array = KIVAT.get(site, ["tuppi"])
	return list[maxi(0, int(s.get("illat", 1)) - 1) % list.size()]


func st(site: String) -> Dictionary:
	return state[site]


func stage(site: String) -> String:
	return st(site).stage


## Sovelluksen pyöristys: lähellä 10 m, keskimatkalla 50 m, kaukana 100 m portain.
static func step_for(d: float) -> float:
	if d < 120.0:
		return 10.0
	if d < 500.0:
		return 50.0
	return 100.0


## Näytettävä etäisyys (m): oikea etäisyys pyöristettynä, vähintään yksi porras.
static func shown(d: float) -> float:
	var s := step_for(d)
	return maxf(s, roundf(d / s) * s)


static func dist_text(m: float) -> String:
	if m <= 10.0:
		return "alle 10 m"
	if m >= 1000.0:
		return ("%.1f km" % (m / 1000.0)).replace(".", ",")
	return "%d m" % roundi(m)


## Ympyrä mittauksesta: keskipiste, näytetty etäisyys ja vyöhyke, jolla oikea etäisyys on (pyöristyksen tarkkuus).
static func ring(at: Vector2, target: Vector2, who: String) -> Dictionary:
	var d := at.distance_to(target)
	var m := shown(d)
	var s := step_for(d)
	var lo := maxf(0.0, m - s / 2.0)
	if m <= s:
		lo = 0.0  # lähin porras: "alle" tarkoittaa mitä tahansa nollasta asti
	return {"c": at, "m": m, "lo": lo, "hi": m + s / 2.0, "who": who}


## Mittaus aloittaa tehtävän: ensimmäinen ympyrä lähtöpaikalta (kaveri mittasi), etämittaus tulossa.
func start(site: String, at: Vector2, target: Vector2, who: String) -> Dictionary:
	var s := st(site)
	s.stage = "mittaus"
	s.rings = []
	s.wrong = []
	s.gift = false  # oma lahja ostetaan joka kerta uudestaan
	s.remote_t = -1.0 if SITES[site].get("drive", false) else REMOTE_DELAY
	var r := ring(at, target, who)
	(s.rings as Array).append(r)
	return r


func measure(site: String, at: Vector2, target: Vector2, who: String) -> Dictionary:
	var r := ring(at, target, who)
	(st(site).rings as Array).append(r)
	return r


## Onko tästä mittaaminen järkevää (tehtävä käynnissä ja kaukana edellisistä pisteistä).
func can_measure(site: String, at: Vector2) -> bool:
	var s := st(site)
	if s.stage != "mittaus":
		return false
	for r: Dictionary in s.rings:
		if (r.c as Vector2).distance_to(at) < MIN_GAP:
			return false
	return true


## Onko piste kaikkien ympyröiden vyöhykkeillä (paperikartan leikkausalue).
func inside(site: String, p: Vector2) -> bool:
	var rings: Array = st(site).rings
	if rings.is_empty():
		return false
	for r: Dictionary in rings:
		var d := (r.c as Vector2).distance_to(p)
		if d < r.lo or d > r.hi:
			return false
	return true


func next_measure_line(site: String) -> String:
	var lines: Array = MEASURE_LINES[site]
	var i: int = _measure_i.get(site, 0)
	_measure_i[site] = i + 1
	return lines[i % lines.size()]


## Kaverin etämittauksen ajastin: palauttaa true sillä ruudulla, kun mittaus tulee.
func remote_step(site: String, delta: float) -> bool:
	var s := st(site)
	if s.stage != "mittaus" or s.remote_t < 0.0:
		return false
	s.remote_t -= delta
	if s.remote_t > 0.0:
		return false
	s.remote_t = -1.0
	return true


## Onko kaveri (remote) jo mitannut.
func remote_done(site: String) -> bool:
	for r: Dictionary in st(site).rings:
		if r.who == SITES[site].remote:
			return true
	return false


func wrong_door(site: String, i: int) -> Dictionary:
	var s := st(site)
	if not i in s.wrong:
		(s.wrong as Array).append(i)
	var list: Array = WRONG_DOORS[site]
	return list[i % list.size()]


func finish(site: String, day: int) -> void:
	var s := st(site)
	s.stage = "valmis"
	s.done_day = day
	s.illat = int(s.get("illat", 0)) + 1
	s.remote_t = -1.0


## Saman päivän ilta on jo käytetty: toisessa kohteessa ei aloiteta samana päivänä.
func busy_today(day: int) -> bool:
	for site in SITES:
		if st(site).done_day == day:
			return true
	return false


func save_to(cfg: ConfigFile) -> void:
	for site in SITES:
		var s := st(site)
		var rings: Array = []
		for r: Dictionary in s.rings:
			rings.append([r.c.x, r.c.y, r.m, r.lo, r.hi, r.who])
		cfg.set_value("kolmio", site, {"stage": s.stage, "rings": rings, "gift": s.gift, "wrong": s.wrong, "done_day": s.done_day,
			"illat": s.illat})
	cfg.set_value("kolmio", "maito", maito_day)


func load_from(cfg: ConfigFile) -> void:
	for site in SITES:
		var s := _fresh()
		var d: Dictionary = cfg.get_value("kolmio", site, {})
		s.stage = d.get("stage", "")
		s.gift = d.get("gift", false)
		s.wrong = d.get("wrong", [])
		s.done_day = d.get("done_day", -1)
		s.illat = d.get("illat", 1 if s.done_day >= 0 else 0)
		for q: Array in d.get("rings", []):
			s.rings.append({"c": Vector2(q[0], q[1]), "m": float(q[2]), "lo": float(q[3]), "hi": float(q[4]), "who": String(q[5])})
		if s.stage == "mittaus":
			s.remote_t = REMOTE_DELAY if (s.rings as Array).size() < 2 and not SITES[site].get("drive", false) else -1.0
		state[site] = s
	maito_day = cfg.get_value("kolmio", "maito", -1)
