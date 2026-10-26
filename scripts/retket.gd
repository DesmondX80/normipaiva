extends RefCounted
## Retkirekisteri (erä 3): jokainen valikkomatkan kohde on yksi rivi tässä ja yksi taskukohtaus (retki_*.gd).
## main.gd tekee valikon ja matkan rekisteristä (`_taxi_retki`, `_enter_retki`, `_on_retki_exited`); kohde ei tunne main.gd:tä.
## Kohtauksen rajapinta (kuten raahe_interior.gd): signaalit `exited` ja `acted(kind)`, jäsenet `walker`, `hint`, `busy`,
## `spot`, `_enter_frame` ja funktiot `enter()`, `leave()`, `block_interact()`.
## Kenttä: nimi (kohde), lahto ("taksi" = K-Marketin taksitolppa Saloisissa | "vaala_asema" = Vaalan asema),
## otsikko, sub ja lines (matkakohtaus: tekstit ja kuskin repliikit), perilla (viesti saapuessa), hop_min (matkan kesto, kello siirtyy sen verran sekä menossa että tullessa),
## hinta (meno-paluu, maksetaan lähtiessä), tasku (kohtauksen skripti).

const RetkiLampi := preload("res://scripts/retki_lampi.gd")
const RetkiHanhikivi := preload("res://scripts/retki_hanhikivi.gd")
const RetkiPakkahuone := preload("res://scripts/retki_pakkahuone.gd")
const RetkiRojuniemi := preload("res://scripts/retki_rojuniemi.gd")
const RetkiManamansalo := preload("res://scripts/retki_manamansalo.gd")
const RetkiWanharaahe := preload("res://scripts/retki_wanharaahe.gd")
const RetkiPaltaniemi := preload("res://scripts/retki_paltaniemi.gd")
const RetkiTietokonemuseo := preload("res://scripts/retki_tietokonemuseo.gd")
const RetkiVanhaherra := preload("res://scripts/retki_vanhaherra.gd")

const LISTA := {
	"lampi": {
		"nimi": "Teeriniemen leirintäalueen kalalampeen", "lahto": "taksi", "otsikko": "TEERINIEMEEN",
		"sub": "Taksi kaartaa soratielle. Leirintäalueen kyltti vilahtaa männikössä.",
		"lines": ["Kalalammelle vai? Istutettua kalaa, ei siinä paljon taitoa tarvita.", "Lupa pitää ostaa tiskiltä. Kyllä ne valvoo.",
			"Mulla on veli, joka sai siellä viisikiloisen. Tai niin se kertoo."],
		"perilla": "Teeriniemen leirintäalue. Kalalampi, lupa tiskiltä.",
		"hop_min": 25.0, "hinta": 16.0, "tasku": RetkiLampi, "sammuit": "leirintäalueen nuotiopaikan penkille",
	},
	"hanhikivi": {
		"nimi": "Pyhäjoen Koskipuistoon (Hanhikivi)", "lahto": "taksi", "otsikko": "PYHÄJOELLE",
		"sub": "Taksi ajaa Pyhäjoen yli. Joen kohina kuuluu jo auton ikkunasta.",
		"lines": ["Koskipuistoon vai? Hanhikivi on siellä, sanotaan.", "Hourunkoski vetää. Siellä on hyvä kävellä, ei tarvii kiirehtiä.",
			"Siitä kivestä on monta juttua. Kukaan ei oikein tiedä."],
		"perilla": "Pyhäjoen Koskipuisto. Hourunkoski kohisee, kivi on rannalla.",
		"hop_min": 35.0, "hinta": 20.0, "tasku": RetkiHanhikivi, "sammuit": "Koskipuiston rantapenkille Hourunkosken kohinaan",
	},
	"pakkahuone": {
		"nimi": "Raahen Pakkahuoneen museoon", "lahto": "taksi", "otsikko": "RAAHEEN",
		"sub": "Taksi ajaa Raahen satamaan. Punainen Pakkahuone kohoaa rantaan.",
		"lines": ["Museoon vai? Pakkahuone on Raahen vanhimpia taloja, sanotaan.", "Siellä on veistoksia 1600-luvulta. En oo koskaan käynyt.",
			"Kuulemma sieltä on yksi ihan kadonnut. Tai en tiedä."],
		"perilla": "Raahen Pakkahuone. Museo on auki, kuraattori on pöytänsä takana.",
		"hop_min": 20.0, "hinta": 12.0, "tasku": RetkiPakkahuone, "sammuit": "Pakkahuoneen museon penkille veistosten keskelle",
	},
	"rojuniemi": {
		"nimi": "Rautaruukin Rojuniemeen (peruskivi)", "lahto": "taksi", "otsikko": "ROJUNIEMEEN",
		"sub": "Taksi ajaa Raahen teollisuusalueelle. Piippu nousee tehtaan yllä.",
		"lines": ["Ruukille vai? Peruskivi on portin vieressä, sanotaan.", "Kekkonen sen paljasti, kuulemma. Mä en ollut vielä syntynyt.",
			"Vartija tietää kivestä enemmän. Se tietää kaikesta."],
		"perilla": "Rautaruukin Rojuniemi. Peruskivi on aidan vieressä, vartija kopissaan.",
		"hop_min": 20.0, "hinta": 14.0, "tasku": RetkiRojuniemi, "sammuit": "Rojuniemen rantakivelle",
	},
	"manamansalo": {
		"nimi": "Manamansalon muistokirkolle", "lahto": "taksi", "otsikko": "MANAMANSALOON",
		"sub": "Taksi ajaa Vaalan taakse, tie 8823:lle. Oulujärvi välkkyy puiden välistä.",
		"lines": ["Manamansaloon vai? Pitkä keikka, noin viisikymmentä kilometriä, sanotaan.", "Siellä on se vanha kirkko ja hautausmaa. Saarta sanotaan kuolemansaareksi.",
			"En tiedä miksi. Opas tietää enemmän, tai sanoo tietävänsä."],
		"perilla": "Manamansalo. Muistokirkko, hautausmaa ja laituri järven rannalla.",
		"hop_min": 60.0, "hinta": 30.0, "tasku": RetkiManamansalo, "sammuit": "Manamansalon muistokirkon portaille",
	},
	"wanharaahe": {
		"nimi": "Raahen Wanhaan kaupunkiin (kävelykierros)", "lahto": "taksi", "otsikko": "WANHAAN RAAHEEN",
		"sub": "Taksi ajaa Pekkatorille. Puutalot seisovat rivissä kuin postikortissa.",
		"lines": ["Wanhaan Raaheen vai? Pekkatorilla on se Brahen patsas, sanotaan.", "Ota kamera mukaan. Ne vanhat ovet on kuulemma kuvauksen arvoisia.",
			"Kävele rauhassa, ei siellä ole kiire. Tori on kivetty."],
		"perilla": "Wanha Raahe. Brahen patsas Pekkatorilla ja puutalot rivissä.",
		"hop_min": 20.0, "hinta": 12.0, "tasku": RetkiWanharaahe, "sammuit": "Pekkatorin penkille Brahen patsaan juurelle",
	},
	"paltaniemi": {
		"nimi": "Paltaniemen kuvakirkkoon (Kajaani)", "lahto": "taksi", "otsikko": "PALTANIEMEEN",
		"sub": "Taksi ajaa Kajaanin suuntaan. Oulujärven rannalla seisoo vanha puukirkko.",
		"lines": ["Kuvakirkkoon vai? Se on Paltaniemessä, matkaa on kai viisikymmentä kilometriä, sanotaan.", "Seinät on maalattu täyteen. Kuulemma 1700-luvulla.",
			"Siellä on suntio. Se osaa kertoa, jos jaksaa kuunnella."],
		"perilla": "Paltaniemen kuvakirkko. Seinät ovat maalauksia täynnä, suntio on alttarin luona.",
		"hop_min": 55.0, "hinta": 28.0, "tasku": RetkiPaltaniemi, "sammuit": "Paltaniemen kirkon penkille maalausten alle",
	},
	"vanhaherra": {
		"nimi": "Raahen satamaan (Vanha herra, sukellus)", "lahto": "taksi", "otsikko": "RAAHEN SATAMAAN",
		"sub": "Taksi ajaa Raahen satamaan. Kruununmakasiini kohoaa laiturin takana ja vesi välkkyy.",
		"lines": ["Satamaan vai? Kruununmakasiinissa on se vanha sukelluspuku, sanotaan maailman vanhin.", "Laiturilla pumpataan joskus ilmaa sukeltajalle. Hirveä homma.",
			"Kapteeni kuulemma pudotti sinne kellonsa. Pohjassa on kaikenlaista."],
		"perilla": "Raahen satama. Kruununmakasiini, vitriini ja laiturin ilmapumppu.",
		"hop_min": 20.0, "hinta": 12.0, "tasku": RetkiVanhaherra, "sammuit": "Raahen laiturin pollarille pumpun viereen",
	},
	"tietokonemuseo": {
		"nimi": "Saloisten tietokonemuseoon", "lahto": "taksi", "otsikko": "SALOISTEN MUSEOLLE",
		"sub": "Taksi ajaa lyhyen matkan Saloisissa. Museon kyltti vilahtaa tien varressa.",
		"lines": ["Tietokonemuseoon vai? Siellä on se iso Datasaab, sanotaan vuodelta 1971.", "Mun poika pelasi siellä Pongia. Ei se voittanut.",
			"Heinäkuussa se on kuulemma auki, sanotaan. Kokeile onneasi."],
		"perilla": "Saloisten tietokonemuseo. Datasaabin kaapit seisovat rivissä, Pong-kone odottaa nurkassa.",
		"hop_min": 12.0, "hinta": 6.0, "tasku": RetkiTietokonemuseo, "sammuit": "museon konsolipöydän ääreen Datasaabin humistessa",
	},
}


## Kohteiden id:t annetusta lähtöpaikasta rekisterin järjestyksessä.
static func lahdosta(lahto: String) -> Array:
	var out: Array = []
	for id in LISTA:
		if LISTA[id].lahto == lahto:
			out.append(id)
	return out
