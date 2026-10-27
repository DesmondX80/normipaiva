extends RefCounted
## Retkirekisteri (erä 3): jokainen valikkomatkan kohde on yksi rivi tässä ja yksi taskukohtaus (retki_*.gd).
## main.gd tekee valikon ja matkan rekisteristä (`_taxi_retki`, `_enter_retki`, `_on_retki_exited`); kohde ei tunne main.gd:tä.
## Kohtauksen rajapinta (kuten raahe_interior.gd): signaalit `exited` ja `acted(kind)`, jäsenet `walker`, `hint`, `busy`,
## `spot`, `_enter_frame` ja funktiot `enter()`, `leave()`, `block_interact()`.
## Kenttä: nimi (kohde), lahto ("taksi" = K-Marketin taksitolppa Saloisissa | "vaala_asema" = Vaalan asema),
## otsikko, sub ja lines (matkakohtaus: tekstit ja kuskin repliikit), perilla (viesti saapuessa), hop_min (matkan kesto, kello siirtyy sen verran sekä menossa että tullessa),
## hinta (meno-paluu, maksetaan lähtiessä), tasku (kohtauksen skripti).
## Matkaopas (matkaopas.gd, valinnaiset): opas (kohdesivun kuvaus, puuttuessa sub) ja kuultu (quests.gd-ehto, jolla kuvaus
## näkyy jo ennen käyntiä, esim. taksikuskin legenda; puuttuessa vain käynti). Kuvaus ei paljasta ratkaisuja.

const RetkiLampi := preload("res://scripts/retki_lampi.gd")
const RetkiHanhikivi := preload("res://scripts/retki_hanhikivi.gd")
const RetkiPakkahuone := preload("res://scripts/retki_pakkahuone.gd")
const RetkiRojuniemi := preload("res://scripts/retki_rojuniemi.gd")
const RetkiManamansalo := preload("res://scripts/retki_manamansalo.gd")
const RetkiWanharaahe := preload("res://scripts/retki_wanharaahe.gd")
const RetkiPaltaniemi := preload("res://scripts/retki_paltaniemi.gd")
const RetkiTietokonemuseo := preload("res://scripts/retki_tietokonemuseo.gd")
const RetkiVanhaherra := preload("res://scripts/retki_vanhaherra.gd")
const RetkiKuhmo := preload("res://scripts/retki_kuhmo.gd")
const RetkiHiidenportti := preload("res://scripts/retki_hiidenportti.gd")
const RetkiPyhakoski := preload("res://scripts/retki_pyhakoski.gd")
const RetkiKajaani := preload("res://scripts/retki_kajaani.gd")
const RetkiKalajoki := preload("res://scripts/retki_kalajoki.gd")
const RetkiRaate := preload("res://scripts/retki_raate.gd")

const LISTA := {
	"lampi": {
		"nimi": "Teeriniemen leirintäalueen kalalampeen", "lahto": "taksi", "otsikko": "TEERINIEMEEN",
		"sub": "Taksi kaartaa soratielle. Leirintäalueen kyltti vilahtaa männikössä.",
		"lines": ["Kalalammelle vai? Istutettua kalaa, ei siinä paljon taitoa tarvita.", "Lupa pitää ostaa tiskiltä. Kyllä ne valvoo.",
			"Mulla on veli, joka sai siellä viisikiloisen. Tai niin se kertoo."],
		"perilla": "Teeriniemen leirintäalue. Kalalampi, lupa tiskiltä.",
		"hop_min": 25.0, "hinta": 16.0, "tasku": RetkiLampi, "sammuit": "leirintäalueen nuotiopaikan penkille",
		"opas": "Teeriniemen leirintäalueella on istutettu kalalampi. Lupa ostetaan tukkimökin tiskiltä, ja vuokraonki kuuluu hintaan, sanotaan. Saaliista kerrotaan isompia juttuja kuin niistä on.",
	},
	"hanhikivi": {
		"nimi": "Pyhäjoen Koskipuistoon (Hanhikivi)", "lahto": "taksi", "otsikko": "PYHÄJOELLE",
		"sub": "Taksi ajaa Pyhäjoen yli. Joen kohina kuuluu jo auton ikkunasta.",
		"lines": ["Koskipuistoon vai? Hanhikivi on siellä, sanotaan.", "Hourunkoski vetää. Siellä on hyvä kävellä, ei tarvii kiirehtiä.",
			"Siitä kivestä on monta juttua. Kukaan ei oikein tiedä."],
		"perilla": "Pyhäjoen Koskipuisto. Hourunkoski kohisee, kivi on rannalla.",
		"hop_min": 35.0, "hinta": 20.0, "tasku": RetkiHanhikivi, "sammuit": "Koskipuiston rantapenkille Hourunkosken kohinaan",
		"opas": "Pyhäjoen Koskipuistossa kohisee Hourunkoski, ja rannalla on Hanhikivi. Kivestä kerrotaan monta juttua, sanotaan, eikä kukaan tiedä, mikä niistä on totta. Puistossa on hyvä kävellä.", "kuultu": "first:hanhikivi_legenda",
	},
	"pakkahuone": {
		"nimi": "Raahen Pakkahuoneen museoon", "lahto": "taksi", "otsikko": "RAAHEEN",
		"sub": "Taksi ajaa Raahen satamaan. Punainen Pakkahuone kohoaa rantaan.",
		"lines": ["Museoon vai? Pakkahuone on Raahen vanhimpia taloja, sanotaan.", "Siellä on veistoksia 1600-luvulta. En oo koskaan käynyt.",
			"Kuulemma sieltä on yksi ihan kadonnut. Tai en tiedä."],
		"perilla": "Raahen Pakkahuone. Museo on auki, kuraattori on pöytänsä takana.",
		"hop_min": 20.0, "hinta": 12.0, "tasku": RetkiPakkahuone, "sammuit": "Pakkahuoneen museon penkille veistosten keskelle",
		"opas": "Punainen Pakkahuone Raahen rannassa on museo, sanotaan Suomen vanhimpia paikallismuseoita. Kokoelmassa on 1600-luvun veistoksia, ja kuraattori kertoo niistä mielellään.", "kuultu": "first:pakkahuone_legenda",
	},
	"rojuniemi": {
		"nimi": "Rautaruukin Rojuniemeen (peruskivi)", "lahto": "taksi", "otsikko": "ROJUNIEMEEN",
		"sub": "Taksi ajaa Raahen teollisuusalueelle. Piippu nousee tehtaan yllä.",
		"lines": ["Ruukille vai? Peruskivi on portin vieressä, sanotaan.", "Kekkonen sen paljasti, kuulemma. Mä en ollut vielä syntynyt.",
			"Vartija tietää kivestä enemmän. Se tietää kaikesta."],
		"perilla": "Rautaruukin Rojuniemi. Peruskivi on aidan vieressä, vartija kopissaan.",
		"hop_min": 20.0, "hinta": 14.0, "tasku": RetkiRojuniemi, "sammuit": "Rojuniemen rantakivelle",
		"opas": "Rautaruukin Raahen terästehtaan peruskiven sanotaan paljastetun 1962. Kivi seisoo aidan vieressä, ja portin vartija tuntee paikan historian.", "kuultu": "first:peruskivi_legenda",
	},
	"manamansalo": {
		"nimi": "Manamansalon muistokirkolle", "lahto": "taksi", "otsikko": "MANAMANSALOON",
		"sub": "Taksi ajaa Vaalan taakse, tie 8823:lle. Oulujärvi välkkyy puiden välistä.",
		"lines": ["Manamansaloon vai? Pitkä keikka, noin viisikymmentä kilometriä, sanotaan.", "Siellä on se vanha kirkko ja hautausmaa. Saarta sanotaan kuolemansaareksi.",
			"En tiedä miksi. Opas tietää enemmän, tai sanoo tietävänsä."],
		"perilla": "Manamansalo. Muistokirkko, hautausmaa ja laituri järven rannalla.",
		"hop_min": 60.0, "hinta": 30.0, "tasku": RetkiManamansalo, "sammuit": "Manamansalon muistokirkon portaille",
		"opas": "Oulujärven suurin saari. Kainuun ensimmäisen kirkon sanotaan rakennetun sinne 1559, ja saarta kutsutaan kuolemansaareksi. Muistokirkolla on opas, ja laiturilta kulkee lossi.", "kuultu": "first:manamansalo_legenda",
	},
	"wanharaahe": {
		"nimi": "Raahen Wanhaan kaupunkiin (kävelykierros)", "lahto": "taksi", "otsikko": "WANHAAN RAAHEEN",
		"sub": "Taksi ajaa Pekkatorille. Puutalot seisovat rivissä kuin postikortissa.",
		"lines": ["Wanhaan Raaheen vai? Pekkatorilla on se Brahen patsas, sanotaan.", "Ota kamera mukaan. Ne vanhat ovet on kuulemma kuvauksen arvoisia.",
			"Kävele rauhassa, ei siellä ole kiire. Tori on kivetty."],
		"perilla": "Wanha Raahe. Brahen patsas Pekkatorilla ja puutalot rivissä.",
		"hop_min": 20.0, "hinta": 12.0, "tasku": RetkiWanharaahe, "sammuit": "Pekkatorin penkille Brahen patsaan juurelle",
		"opas": "Raahen vanha puutalokaupunki Pekkatorin ympärillä: Brahen patsas, vanhat ovet ja kapeat kujat. Kameralle riittää kuvattavaa, sanotaan.",
	},
	"paltaniemi": {
		"nimi": "Paltaniemen kuvakirkkoon (Kajaani)", "lahto": "taksi", "otsikko": "PALTANIEMEEN",
		"sub": "Taksi ajaa Kajaanin suuntaan. Oulujärven rannalla seisoo vanha puukirkko.",
		"lines": ["Kuvakirkkoon vai? Se on Paltaniemessä, matkaa on kai viisikymmentä kilometriä, sanotaan.", "Seinät on maalattu täyteen. Kuulemma 1700-luvulla.",
			"Siellä on suntio. Se osaa kertoa, jos jaksaa kuunnella."],
		"perilla": "Paltaniemen kuvakirkko. Seinät ovat maalauksia täynnä, suntio on alttarin luona.",
		"hop_min": 55.0, "hinta": 28.0, "tasku": RetkiPaltaniemi, "sammuit": "Paltaniemen kirkon penkille maalausten alle",
		"opas": "Oulujärven rannan puukirkko, jonka seinät sanotaan maalatun täyteen 1700-luvulla. Maalauksissa riittää katsottavaa, ja suntio kertoo kirkosta.",
	},
	"vanhaherra": {
		"nimi": "Raahen satamaan (Vanha herra, sukellus)", "lahto": "taksi", "otsikko": "RAAHEN SATAMAAN",
		"sub": "Taksi ajaa Raahen satamaan. Kruununmakasiini kohoaa laiturin takana ja vesi välkkyy.",
		"lines": ["Satamaan vai? Kruununmakasiinissa on se vanha sukelluspuku, sanotaan maailman vanhin.", "Laiturilla pumpataan joskus ilmaa sukeltajalle. Hirveä homma.",
			"Kapteeni kuulemma pudotti sinne kellonsa. Pohjassa on kaikenlaista."],
		"perilla": "Raahen satama. Kruununmakasiini, vitriini ja laiturin ilmapumppu.",
		"hop_min": 20.0, "hinta": 12.0, "tasku": RetkiVanhaherra, "sammuit": "Raahen laiturin pollarille pumpun viereen",
		"opas": "Kruununmakasiinin vitriinissä on Vanha herra, sanotaan maailman vanhin säilynyt sukelluspuku. Laiturilla pumpataan joskus ilmaa sukeltajalle.",
	},
	"tietokonemuseo": {
		"nimi": "Saloisten tietokonemuseoon", "lahto": "taksi", "otsikko": "SALOISTEN MUSEOLLE",
		"sub": "Taksi ajaa lyhyen matkan Saloisissa. Museon kyltti vilahtaa tien varressa.",
		"lines": ["Tietokonemuseoon vai? Siellä on se iso Datasaab, sanotaan vuodelta 1971.", "Mun poika pelasi siellä Pongia. Ei se voittanut.",
			"Heinäkuussa se on kuulemma auki, sanotaan. Kokeile onneasi."],
		"perilla": "Saloisten tietokonemuseo. Datasaabin kaapit seisovat rivissä, Pong-kone odottaa nurkassa.",
		"hop_min": 12.0, "hinta": 6.0, "tasku": RetkiTietokonemuseo, "sammuit": "museon konsolipöydän ääreen Datasaabin humistessa",
		"opas": "Pieni museo Saloisissa: Datasaab D22, sanotaan vuodelta 1971, ja huoneellinen vanhoja mikroja. Nurkan pelikoneella saa haastaa koneen.",
	},
	"kuhmo": {
		"nimi": "Kuhmon karhukätköön", "lahto": "taksi", "otsikko": "KUHMOON",
		"sub": "Taksi ajaa itään, Kuhmon korpeen. Mänty seisoo tien molemmin puolin.",
		"lines": ["Karhukätköön vai? Kuhmossa niitä on, sanotaan, ja kyllä ne tulevat illalla.", "Pitkä matka, sataviisikymmentä kilometriä. Otan sen hinnalla.",
			"Älä ota evästä mukaan, karhu haistaa. Tai en tiedä."],
		"perilla": "Kuhmon karhukätkö. Niitty on hiljainen, opas odottaa kätkön vieressä.",
		"hop_min": 90.0, "hinta": 45.0, "tasku": RetkiKuhmo, "sammuit": "karhukätkön penkille niityn ääreen",
		"opas": "Puinen karhukätkö Kuhmon korvessa niityn laidalla. Karhujen sanotaan tulevan illalla, kun on hiljaista. Kamera mukaan, eväät kotiin.",
	},
	"hiidenportti": {
		"nimi": "Sotkamon Hiidenporttiin (rotkolaakso)", "lahto": "taksi", "otsikko": "HIIDENPORTILLE",
		"sub": "Taksi ajaa Sotkamon suuntaan. Metsä tiivistyy ja kalliot nousevat tien reunaan.",
		"lines": ["Hiidenportille vai? Se on se rotko Sotkamossa, sanotaan, ja kyllä se on jyrkkä.", "Matkaa on sata kilometriä, kai. Otan sen hinnalla.",
			"Kenkien kanssa kannattaa olla tarkkana. Itse en kiipeä, jalka ei kestä."],
		"perilla": "Hiidenportin rotko. Kalliot kohoavat, retkeilijä seisoo polun alussa.",
		"hop_min": 70.0, "hinta": 38.0, "tasku": RetkiHiidenportti, "sammuit": "rotkon lepolavalle kallioseinän juurelle",
		"opas": "Sotkamon Hiidenportti on jyrkkäseinäinen kalliorotko, jonka pohjalla virtaa puro, sanotaan. Polun alussa on infokyltti. Hyvät kengät jalkaan.",
	},
		"pyhakoski": {
			"nimi": "Pyhäkosken voimalaitoskylään", "lahto": "taksi", "otsikko": "PYHÄKOSKELLE",
			"sub": "Taksi ajaa Oulujoen vartta. Voimalaitoksen harmaa pato ilmestyy puiden taakse.",
			"lines": ["Pyhäkoskelle vai? Se on se voimalaitoskylä Oulujoella, sanotaan.", "Siellä oli ennen kioski ja tanssit. Nyt on hiljaisempaa.",
				"Vahtimestari tietää kylästä kaiken. Jos jaksaa kuunnella."],
			"perilla": "Pyhäkosken kylä. Voimalaitos jyrisee joen rannalla, kioski on tien varressa.",
			"hop_min": 45.0, "hinta": 24.0, "tasku": RetkiPyhakoski, "sammuit": "tanssipaikan portaille voimalaitoksen jylinään",
			"opas": "Oulujoen voimalaitoskylä: harmaa pato, punainen kioski ja vanha tanssipaikka. Kylästä kerrotaan tarinoita, sanotaan, ja vahtimestari tietää ne.",
		},
	"kajaani": {
		"nimi": "Kajaanin linnan raunioille", "lahto": "taksi", "otsikko": "KAJAANIIN",
		"sub": "Taksi ajaa Kajaaniin. Joen kohina kuuluu jo, ja saaren rauniot erottuvat puiden takaa.",
		"lines": ["Linnalle vai? Siitä on jäljellä vain rauniot, sanotaan.", "Siellä oli vankina se Messenius. Kirjoitti kuulemma vankilassa vaikka mitä.",
			"Joella kulki ennen tervaveneitä. Nyt on hiljaista."],
		"perilla": "Kajaanin linnan rauniot. Joki kohisee, tervavene odottaa laiturissa.",
		"hop_min": 60.0, "hinta": 30.0, "tasku": RetkiKajaani, "sammuit": "linnan raunioiden kivelle joen rannalle",
		"opas": "Kajaanin linnasta on jäljellä rauniot joen saarella. Linnassa sanotaan istuneen vankina historioitsija Messeniuksen. Joella kulkee yhä tervavene.",
	},
	"kalajoki": {
		"nimi": "Kalajoen Hiekkasärkille (rantajalkapallo)", "lahto": "taksi", "otsikko": "KALAJOELLE",
		"sub": "Taksi ajaa pitkän matkan rannikolle. Dyynit nousevat tien viereen ja meri välkkyy.",
		"lines": ["Hiekkasärkille vai? Kalajoella, matkaa on kai sata kilometriä, sanotaan.", "Juhannuksena siellä pelataan rantajalkapalloa. Kuulemma tuhansia katsojia.",
			"Hiekassa juokseminen on kamalaa. Hyvä että sinä juokset, en minä."],
		"perilla": "Kalajoen Hiekkasärkät. Meri lyö rantaa, kentällä pallo odottaa.",
		"hop_min": 80.0, "hinta": 42.0, "tasku": RetkiKalajoki, "sammuit": "rantahiekalle sateenvarjon varjoon",
		"opas": "Kalajoen Hiekkasärkät: dyynit, meri ja hiekkakenttä maaleineen. Juhannuksena pelataan rantajalkapallon turnaus, sanotaan. Muulloin saa harjoitella.",
	},
	"raate": {
		"nimi": "Raatteen Portille (Suomussalmi)", "lahto": "taksi", "otsikko": "RAATTEENTIELLE",
		"sub": "Taksi ajaa itään, kauas. Metsä on tiheää ja tie hiljenee.",
		"lines": ["Raatteen Portille vai? Suomussalmella, sanotaan.", "Talvisodan paikka. Siellä ei puhuta paljon.",
			"Odotan täällä."],
		"perilla": "Raatteen Portti. Tie jatkuu metsään, vanha vierailija seisoo hiljaa.",
		"hop_min": 100.0, "hinta": 30.0, "tasku": RetkiRaate, "sammuit": "!Väsymys vei voiton Raatteentien varrella, ja lepäsit hetken ennen kotimatkaa",
		"opas": "Talvisodan muistopaikka Suomussalmella. Raatteentien portilla ja muistokivellä kuljetaan hiljaa, sanotaan.",
	},
}


## Kohteiden id:t annetusta lähtöpaikasta rekisterin järjestyksessä.
static func lahdosta(lahto: String) -> Array:
	var out: Array = []
	for id in LISTA:
		if LISTA[id].lahto == lahto:
			out.append(id)
	return out
