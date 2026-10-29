extends RefCounted
## Kolmiomittaus (#255): Sytkäri-sovelluksen mätsi ei kerro osoitettaan, vain etäisyyden ("350 m päässä"). Pelaaja ja
## kaksi kaveria mittaavat etäisyyden eri paikoista, Esa (tai Timo) piirtää ympyrät paperikarttaan, ja ympyröiden
## leikkauksessa on naisen talo. Sovellus pyöristää etäisyyden (lähempänä tarkemmin), joten yksi kierros antaa vain
## alueen: lisämittaukset lähempää tarkentavat sitä. Väärällä ovella avaa joku muu. Kolme kolmiomittaajaa tuovat
## kukin yhden lahjan (mansikat, kermavaahto, ruusut) kuin itämaan tietäjät; ilman kaikkia kolmea ovi ei aukea.
## Ilta päättyy erikoissääntöiseen Rasvanappiin (rasvanappi_game.gd rules) ja aamu onnelliseen loppuun.
## Kaksi kohdetta: Saloinen (Joni ja Esa, Minttu) ja Vaala (Hevari-Tero ja Siviikki-Timo, Katja).
## Tämä tiedosto on tehtävän tila ja data; main.gd kytkee sen maailmaan (_kolmio_*), Sytkäri on sytkari.gd ja
## ovi- ja aamukohtaukset kolmio_kohtaus.gd.
##
## Koordinaatit: Saloisissa maailman x/z (main.gd world), Vaalassa Vaalan paikallinen x/z (vaala.gd, sama kuin
## paperikartan Neittävä–Vaala-kehys).

## Mittauspisteiden vähimmäisväli: samasta paikasta mitattu ympyrä ei kerro mitään uutta.
const MIN_GAP := 35.0
## Kaverin etämittaus (Esa kirkolta, Timo Veturitallilta) tulee tekstiviestinä tämän ajan päästä (s).
const REMOTE_DELAY := 40.0
## Oma lahja kaupan tiskiltä (Saloisissa ruusut, Vaalassa mansikat).
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
	"vaala": {
		"woman": "Katja", "gen": "Katjan", "talker": "kolmio_vaala", "friends": ["Hevari-Tero", "Siviikki-Timo"],
		"gift_me": "mansikat", "gift_part": "mansikoita", "start_place": "aseman pihassa",
		"remote": "Timo", "remote_place": "Veturitallin pihasta",
		"gifts": [["Timo", "kermavaahdon"], ["Tero", "ruusut"], ["Sinä", "mansikat"]],
		"age": 37, "bio": "Moottoripyörä tallissa, kahvi kuumana. Löydä, jos uskallat. Tuo jotain makeaa.",
		"job": "Rekkakuski, Vaala", "ending": "katja",
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
	"vaala": [
		{"who": "Mummo kepin kanssa", "line": "Kolme miestä ja kermavaahtoa? Minä soitan Roivaiselle!",
			"after": "Perääntyt ennen kuin keppi nousee. Tero: \"Ihan ku verottaja.\""},
		{"who": "Verotoimiston Raimo", "line": "Mansikoita? Ne pitää ilmoittaa luontoisetuna. Ja kuka teistä on Tero?",
			"after": "Tero huutaa pihalta: \"MÄÄ SANOIN! Valtio kolmiomittaa mua!\""},
		{"who": "Unenpöpperöinen yövuorolainen", "line": "Katja asuu jossain tuolla päin. Ja hiljempaa sen Hondan kanssa.",
			"after": "Timo kääntää Siviikin avainta: VTEC kytkeytyy kahvinkeiton tahtiin."},
	],
}

## Kaverien jutut (puhekuplat ja Mitä kuuluu?). Saloisissa Joni ja Esa, Vaalassa Tero ja Timo.
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
	"vaala": [
		"Tero: Etäisyys pyöristetään ylöspäin. Ihan ku verot. Valtio varmaan kolmiomittaa mua koko ajan.",
		"Timo: Kolme kilsaa? Siviikillä se on kakkosvaihde ja VTEC. Pidä Terosta kiinni.",
		"Tero: Ajoneuvovero tuosta Siviikistä on enemmän ku mun Kela-tuki. Ja silti mää maksan bensat.",
		"Timo: Kuuntele ku se huutaa. Seittemäntuhatta kierrosta ja sitten VTEC. Se on kuin rakkautta.",
		"Tero: Kela halus taas selvityksen. Selvitin, että mää en tykkää Kelasta.",
		"Timo: Matalat jouset ja kakskytkuus vuotta ruostetta. Ei tällasta enää tehä.",
		"Tero: Bensan hinnasta menee puolet valtiolle. Toinen puoli Timon pakoputkeen.",
		"Timo: Pakoputken ääni on sävelletty. Honda tiesi mitä teki.",
		"Tero: Sakot tuli taas. Kuulemma tunneli ei oo moshpit.",
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
	"vaala": [
		"Tero: Taas pyöristys. Ihan ku verottaja olis tehny tän sovelluksen.",
		"Timo: Mää ajoin Siviikillä sinne ja takas. VTEC kytkeytyi kolme kertaa. Tuli mittaus siinä samalla.",
		"Tero: Kela kysyy kohta, miksi mää liikun kolmessa pisteessä.",
		"Timo: Ympyrät piirretty. Siviikin hansikaslokerossa on harppi, tietenkin.",
		"Tero: Lähempää mittaat, tarkempi on. Ainoo asia, mikä tässä maassa toimii.",
	],
}

## Päivin puhelu kesken Rasvanapin.
const PAIVI_CALL := [["Päivi", "Missä sää oot?"], ["Sinä", "Kolmiomittaamassa."], ["Päivi", "No tuo maitoa tullessas."]]

## Erikoissääntöinen Rasvanappi naisen pimennetyssä olohuoneessa (rasvanappi_game.gd people ja rules): viisi pelaajaa
## (pelaaja, nainen, kaksi kaveria ja naisen ystävätär), kermavaahto margariinin tilalla, mansikka oikeasta arvauksesta.
## Tunnusäänet: naisen kikatus tai matala nauru, Esan hyräily, Jonin golfjutut, Teron valitus ja Timon VTEC.
const RASVA_PEOPLE := {
	"saloinen": [
		{"id": "minttu", "name": "Minttu", "gen": "Mintun", "desc": "kikattaa", "bulk": 0.9, "col": Color(1.0, 0.5, 0.35),
			"tics": ["Hihii!", "Kuka siellä kermassa?", "Hihihii, löysitte mut!", "Mansikkaa kellekään?"],
			"snd": ["grunt", 1.8], "lick": "Hihii! Makeaa!", "towel": Color(1.0, 0.8, 0.25), "woman": true,
			"look": {"hair": "long", "hair_col": Color(0.72, 0.2, 0.07), "skin": Color(1.0, 0.9, 0.84)}},
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
			"look": {"hair": "long", "hair_col": Color(0.6, 0.45, 0.28), "skin": Color(0.97, 0.8, 0.72)}},
	],
	"vaala": [
		{"id": "katja", "name": "Katja", "gen": "Katjan", "desc": "nauraa matalalla", "bulk": 0.92, "col": Color(0.85, 0.85, 0.95),
			"tics": ["Heh-heh.", "Ei tarvinnu ees koskee, se valitti jo valtiosta.", "Kuka teistä haisee bensalle? Ai kaikki.", "Heh. Löydän teidät kyllä."],
			"snd": ["groan", 1.25], "lick": "Heh. Makeaa.", "towel": Color(0.7, 0.1, 0.15), "woman": true,
			"look": {"hair": "long", "hair_col": Color(0.03, 0.025, 0.03), "skin": Color(0.98, 0.86, 0.78)}},
		{"id": "tero", "name": "Tero", "gen": "Teron", "desc": "valittaa valtiosta", "bulk": 1.15, "col": Color(1.0, 0.55, 0.3),
			"tics": ["Valtio kolmiomittaa mua nytkin.", "Kela ei korvaa tätä.", "Tästäkin menee vero.", "Perkeleen ajoneuvovero."],
			"snd": ["grunt", 0.75], "lick": "Verotonta. Ainoo.", "towel": Color(0.35, 0.35, 0.38),
			"look": {"hair": "long", "hair_col": Color(0.2, 0.15, 0.12), "beard": true, "skin": Color(0.97, 0.84, 0.76)}},
		{"id": "timo", "name": "Timo", "gen": "Timon", "desc": "ääntelee VTECiä", "bulk": 0.95, "col": Color(1.0, 0.35, 0.35),
			"tics": ["Vrrrrr… VTEC!", "Nyt kytkeytyy!", "Iiiiihhh-VTEC!", "Seittemäntuhatta…"],
			"snd": ["grunt", 1.25], "lick": "Kakkosvaihde.", "towel": Color(0.85, 0.1, 0.12),
			"look": {"hair": "short", "hair_col": Color(0.55, 0.42, 0.25), "skin": Color(0.98, 0.84, 0.74)}},
		{"id": "sari", "name": "Sari", "gen": "Sarin", "desc": "kikattaa", "bulk": 0.9, "col": Color(1.0, 0.8, 0.4),
			"tics": ["Hihii!", "Katja, sää lupasit!", "Hihihii, kuka siellä?", "Ihan kuin piirakkaa…"],
			"snd": ["grunt", 1.7], "lick": "Hihii! Lisää!", "towel": Color(0.95, 0.7, 0.2), "woman": true,
			"look": {"hair": "long", "hair_col": Color(0.95, 0.85, 0.55), "skin": Color(0.98, 0.82, 0.72)}},
	],
}
const RASVA_RULES := {
	"saloinen": {"end_quote": "Esa: \"Rasvanapin jälkeen pitää syödä rasvasta.\"",
		"end_lines": ["Minttu sytyttää kynttilän. Kaikki jähmettyvät.", "Joni: \"Tasan par.\""],
		"style": {"floor": Color(0.66, 0.5, 0.32), "wall": Color(0.82, 0.72, 0.58)}},
	"vaala": {"end_quote": "Tero: \"Tästäkin menee vero.\"",
		"end_lines": ["Katja vetää verhot auki. Kaikki jähmettyvät.", "Timo: \"Siviikki lämpiää jo.\""],
		"style": {"floor": Color(0.45, 0.36, 0.28), "wall": Color(0.27, 0.3, 0.38)}},
}

var state := {}  # kohde -> {stage, rings, remote_t, gift, wrong, done_day}
var maito_day := -1  # päivä, jona Päivi odottaa maitoa (aamu kolmiomittauksen jälkeen)
var _measure_i := {}


func _init() -> void:
	for s in SITES:
		state[s] = _fresh()


func _fresh() -> Dictionary:
	return {"stage": "", "rings": [], "remote_t": -1.0, "gift": false, "wrong": [], "done_day": -1}


func st(site: String) -> Dictionary:
	return state[site]


func stage(site: String) -> String:
	return st(site).stage


func site_info(site: String) -> Dictionary:
	return SITES[site]


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
	s.remote_t = REMOTE_DELAY
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
		cfg.set_value("kolmio", site, {"stage": s.stage, "rings": rings, "gift": s.gift, "wrong": s.wrong, "done_day": s.done_day})
	cfg.set_value("kolmio", "maito", maito_day)


func load_from(cfg: ConfigFile) -> void:
	for site in SITES:
		var s := _fresh()
		var d: Dictionary = cfg.get_value("kolmio", site, {})
		s.stage = d.get("stage", "")
		s.gift = d.get("gift", false)
		s.wrong = d.get("wrong", [])
		s.done_day = d.get("done_day", -1)
		for q: Array in d.get("rings", []):
			s.rings.append({"c": Vector2(q[0], q[1]), "m": float(q[2]), "lo": float(q[3]), "hi": float(q[4]), "who": String(q[5])})
		if s.stage == "mittaus":
			s.remote_t = REMOTE_DELAY if (s.rings as Array).size() < 2 else -1.0
		state[site] = s
	maito_day = cfg.get_value("kolmio", "maito", -1)
