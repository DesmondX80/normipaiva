extends RefCounted
## Sinikka ottaa aurinkoa Oravajärven rannalla (12–17): kaksimieliset repliikit ja kolme vastausta (main.gd
## _sinikka_sun, _ranta_choose). Mittarit vain kerran päivässä; flirtti perheiden nähden voi kantautua Päiville.

## Juttelurepliikit; pakka (deck) sekoitetaan, joten sama ei toistu peräkkäin samalla juttelukerralla.
const LINES := [
	"Ai sää. Ootko tullu kattomaan maisemia? Järvi on tuolla päin, kulta.",
	"Viittisitkö levittää vähän rasvaa selkään? Mää en ylety itte... ja sulla on niin lämpimät kädet, näyttää.",
	"Tuu viereen vaan, pyyhe on iso. Mää en pure. Ainakaan kovaa.",
	"Aurinko polttaa, mutta sää polttaat enemmän. Älä kerro Päiville, että mää sanoin noin.",
	"Mää otan aina aurinkoa ilman olkaimia. Ettei jää raitoja. Ihan käytännön syistä tietysti.",
	"Kävin aamulla uimassa, nyt mää kuivattelen. Pitkään. Joka paikasta.",
	"Tiedätkö mikä tässä helteessä on parasta? No arvaa. Väärin. Tai no... ehkä vähän oikein.",
	"Pullossa on kerroin kolkyt. Mutta jos sää jäät siihen seisomaan, tarvitaan isompi kerroin.",
	"Mää tykkään kun mies osaa käyttää käsiään. Puutarhassa siis. Mitä sää ajattelit?",
	"Hikoilettaa vai? Mennään yhessä pulahtamaan. Mää uin aina ensin, sää saat kattoa perästä.",
]

## Vastaukset rannalla: id -> [valinnan teksti, Sinikan vastaus, {tila: muutos}]. Tilat ovat day_stats.gd:n avaimia.
const CHOICES := {
	"ranta_flirtti": ["Levitän rasvan, jos sää lupaat ettet kerro Päiville.",
		"Voi kulta, mää en kerro kenellekään. Kädet lämpimiks ensin... noin. Ihan ammattimiehen ote.",
		{"moraali": 0.25, "vireys": 0.2, "stressi": 0.15}],
	"ranta_vitsi": ["Mää oon kuullu, että kerroin kolkyt riittää vaikka Saharaan.",
		"Hah! Sää oot hauska. Saharassa ei oo tällasia maisemia, eihän?",
		{"moraali": 0.1, "stressi": 0.2}],
	"ranta_torju": ["Mää oon naimisissa, Sinikka. Ota sää aurinkoa ihan rauhassa.",
		"Tylsimys. No, Päivi on onnekas nainen. Mutta jos muutat mieltä, pyyhe on täällä huomennakin.",
		{"moraali": 0.15, "stressi": -0.05}],
}

## Kun perheet näkivät flirtin ja kertovat siitä Päiville (heti tuleva viesti ja aamurivi).
const SEEN := "Rantaperheen äiti kattoo sua pitkään ja kaivaa puhelimen esiin. Tästä kuullaan vielä."
const MORNING := "Mulle soitettiin Oravajärveltä. Sää kuulemma levittelit iltapäivällä aurinkorasvaa Sinikan selkään. Sinikan. Selkään."
## Kerran päivässä saatava vaikutus on jo käytetty: vastaus tulee, mittarit eivät liiku.
const SPENT := "Sinikka nauraa, mutta tänään se ei enää tunnu missään."


## Sekoitettu indeksilista LINES-taulukkoon. Kun pakka loppuu, uuden pakan ensimmäinen ei ole edellinen viimeinen.
static func deck(last := -1) -> Array:
	var d := range(LINES.size())
	d.shuffle()
	if d.size() > 1 and d[0] == last:
		d.append(d.pop_front())
	return d
