# Pelin sisältö

> **Juonipaljastuksia.** Tämä opas kertoo pelin kaikki paikat, tehtävät, salasanat ja legendojen ratkaisut. Peli itse ei paljasta mitään etukäteen (päiväkirja näyttää vain sen, mistä on kuultu).

Kaikki, mitä Saloisissa, Paapelin mökillä, Vaalassa ja Raahessa voi tehdä. Ohjaus: [ohjaus.md](ohjaus.md),
päivän tilat: [tilat.md](tilat.md), kehitys ja testit: [kehitys.md](kehitys.md).

## Mitä pelissä voi tehdä

- **Tarina "Paapeliin pääsee, kunhan…":** ohjaa naapurilta toiselle, mutta kaikki muu pysyy vapaana. Ensin
  kuutonen kotijemmoihin (eteinen, talli ja komposti yhteensä), sitten Pekka huikkaa pihalta ja antaa kolme tehtävää vapaassa järjestyksessä: 3 l sieniä
  Pekalle (Arto tietää paikat), 5 l puolukoita Artolle ja Sinikan takapihan nurmikko niin, ettei Päivi näe
  (jos näkee, Päivi suuttuu ja lähtee jahtiin, mutta leikkuuta voi jatkaa karkuun päästyä). Lopuksi Pekan
  autonavaimet ovat hukassa kodalla: Pekka kävi lintutornilla kaverin kyydillä niin kännissä, että ampui
  luvallisia ja luvattomia lintuja osumatta yhteenkään. Avaimet Pekalle, niin Pekan kyyti Paapeliin aukeaa.
  Tehtävät näkyvät repussa (I) sitä mukaa kuin niitä löytyy. Paapeliin ei pääse taksilla (taksi ajaa vain retkille ja
  Raahen baariin). Paapeli on välietappi: tarina jatkuu myöhemmin.

- **Kauppareissu:** kuutonen, grillimakkara ja tulitikut K-Marketista. Kassalla harmaapäät laskevat kolikoita.
  Kauppa on homma muiden joukossa: ei valosädettä eikä pakollista reittiä. Kauppaan mennään oven edestä (E)
  milloin vain, ja sinne voi palata uudestaan, paitsi kalja kädessä: silloin kauppias ovella kieltää Saloisten
  tapaan. Kotiin mennään etu- tai takaovesta (E) tyhjin käsin, kun itse haluaa.
- **Koti sisältä:** etuovelta vasemmalla kaksi makuuhuonetta (kerrossänky ja parisänky), oikealla kylpyhuone
  (suihku, pönttö, peili) ja sauna, suoraan edessä tupakeittiö (kahvit, jääkaappi, telkkari, nokoset sohvalla),
  joka jatkuu vasemmalle nörtin huoneeseen (kolme näyttöä, raidi kesken). Tupakeittiöstä etuovea vastapäätä
  takaovi takapihalle. Päivä päättyy vasta, kun menee nukkumaan parisänkyyn.
  Kylän teillä on liikennettä: henkilöautoja ja pakettiautoja, maanteillä kovempaa kuin asuinkaduilla. Autot
  pysyvät pelaajan ympärillä, ajavat jonossa toistensa (ja Päivin) perässä ja jarruttavat pelaajalle, mutta
  pysähtymismatka on pitkä. Arto asuu heti kodin vasemmalla puolella ja Pekka Lehtikujan päässä.
  Leipähyllystä saa korvapuusteja ja lihapiirakoita evääksi: T syö ne (tai suklaan tai marjat ämpäristä) ja juo kannossa olevan kaljan.
- **Jalkapallopojat:** joka toinen päivä kolme poikaa pelaa vuorotellen Saloisten kentällä tai Honganpalon koulun
  kentällä (aamuviesti kertoo kummalla), ja Jere on potkaissut pallon aidan yli. Pojat kertovat suunnan, ja pallo on
  60–200 m päässä. Palautus: poikien luona E avaa esinevalikon (W/S valitse, E anna,
  Q peruuta). Pallo = 1 € (ja moraali ja kokemus nousevat), kalja = pojat juoksevat nauraen pois, muu esine =
  pojat heittävät sen takaisin ja alkavat heitellä kivillä.
- **Kaupan mummot:** K-Marketin edustan penkillä istuu kaksi permanenttipäistä mummoa, ja vieressä seisoo kolmas
  rollaattorinsa takana keppi kahvassa. Jos kurvaat pyörällä lujaa aivan vierestä tai soitat kelloa (Q), penkin
  mummot suuttuvat ja heittelevät kettukarkkeja: osuma heilauttaa pyörää tai horjauttaa. Maahan jääneet karkit voi
  poimia jalan (kunto +15). Rollaattorimummon eteen ei kannata mennä: hän nostaa kepin olan yli ja huitaisee.
  Ehdit perääntyä, kun keppi nousee. Osuma päähän on kuolema, ja Päivi motkottaa: "Älä kiusaa mummoja! Ne tappaa!"
  Testit `--scene=mummokeppi` ja `tools/testit/mummo_kuvat.tscn`.
- **Rasvanappi (vain aikuisille):** aseman takana on rapistunut tavaramakasiini. Länsipäädyn takaovella palaa punainen
  lamppu häkissä: koputa (E), niin kurkistusluukku aukeaa ja portsari kysyy salasanan. Oikea on "Rasvanappi", ja
  väärästä luukku paukahtaa kiinni. Sisällä pelaajat (Pekka, Arto, Sinikka, Raimo ja Helena) esittäytyvät pyyhkeissään.
  Muista, kuka kiroilee, hyräilee, kikattaa, niiskuttaa tai huokailee, sillä pimeässä muut tunnistaa vain äänestä.
  Valojen sammuttua kontataan (WASD, Shift ripeästi mutta kolisten). Rasvanappi tökkää jotakuta takaapäin peppuun
  (E) ja huutaa nimen. Jos arvaus osuu, tökätty nuolee sormen ja on seuraava nappi. Jos ei, tökkääjä nuolee itse.
  Kun nappi on joku muu, se jahtaa pimeässä. Testit `--scene=rasvanappi` ja `tools/testit/rasvanappi_kuvat.tscn`.
- **Päivin kauppalista:** aamulla ruudun laidassa on Päivin heippalappu (kauppalista ja Päivin omin sanoin
  kirjoittamat muistutukset; mökillä lapun kirjoittaa Santtu). Pelin tiedot, kuten jemmojen tilanne ja varoitukset,
  tulevat ruudun viesteinä. Kauppalistan neljä tuotetta on kirjoitettu kukin omanvärisellä kynällä ("vihreä tamponi,
  punainen maito..."), mutta lappu näkyy vain hetken, ja repun kauppalistassa on pelkät tuotteet. Kaupan oikealla seinällä on Päivin hylly, jossa jokaisesta tuotteesta
  on viisi väriä: Q vaihtaa väriä, E ottaa, vaihtaa tai palauttaa. Päivin ostokset maksetaan Päivin rahoilla.
  Kotona Päivi tarkistaa ostokset: kaikki oikein = kaljarauha (Päivi ei etsi jemmoja seuraavana aamuna), muuten
  motkotus jokaisesta virheestä.
- **Laavu Antinsuonkankaalla:** sytytä nuotio, paista makkara ja avaa kalja, jos pääset laavun
  valtaajien (vittumainen akka tai teinijengi) ohi. Tästä tulee "LEGENDAARINEN NORMIPÄIVÄ". Laavu oikean
  Tarpion laavun valokuvien mukaan: haalistuneet hirret nurkkasalvoksineen, "TARPION LAAVU" -kyltti etupalkissa,
  teräksinen tulirengas ja kääntyvä grilliritilä, halkopenkit sivuilla ja lautapenkki edessä, pölkyt ja hirsinen
  puuvaja lankkuovineen. Testi `--scene=tarpio`.
- **Mirkku luontopolulla:** laavupolulla Järvikujan päästä etelään kävelee kesäpäivisin Mirkku (punertavan vaalea
  palmikko oikean olan yli, valkoinen paita) ja poimii päivänkakkaraa, keltasauniota ja maitohorsmaa polun varresta.
  Jalan E juttelemaan. Mirkun teltta on pystyssä Tarpion laavun vieressä. Onnellinen loppu **Mirkun teltassa**:
  vie illalla (17–23) säästöpihan kukkakimppu (se, joka piti viedä Päiville) Mirkulle -> nuotio laavulla
  auringonlaskussa, teltan ovi kiinni ja lyhty palaa; aamulla Päivi kysyy, missä olit yön. Testit `--scene=mirkku`,
  `--scene=mirkku_loppu` ja `tools/testit/mirkku_kuvat.tscn`.
- **Metsän antimet:** poimi puolukoita, mustikoita, kantarelleja ja herkkutatteja. Naapurin Arto
  (lähekkö puolukkaan?) merkitsee paikat karttaan ja ostaa marjat, ja Pekka (14 kyyhkyä!) ostaa sienet.
  Marjoja poimitaan kyykkyyn (A) ja ylös (D) vuorotellen tasaiseen tahtiin: räpellys ja väärä nappi pudottavat
  marjoja, ja pitkä kyykkiminen käy selkään (kunto): ähinä tihenee, ja lopulta pitää pitää tauko. W/S lopettaa poiminnan.
- **Kaljajemma:** kotiinpaluun saalis piilotetaan itse jemmaan (jalan E), joka säilyy pelikerrasta toiseen.
  Kotiovi ei aukea kaljat tai kanisteri kädessä. Jos jemma kasvaa isoksi, Päivi saattaa löytää sen...
- **Taksi Raahen baariin:** K-Marketin taksitolpalla odottaa taksi (4 € meno-paluu, 10 min suuntaansa, jalan E) Kapteenin Kulmaan
  ja Kellariin (Kirkkokatu 32, Kirkkokadun ja kävelykadun kulma). Ylhäällä Kulmassa merihenkinen pubi
  (ruori, pelastusrengas, laivataulu Raahen purjelaivojen ajoilta, kuva Pekkatorin Brahen patsaasta) ja
  kesäterassi kävelykadulla: tiskiltä tuoppi, kossu tai kaffet, ikkunapöydässä vanha kapteeni muistelee
  retarien aikoja, ja terästehtaan porukka yövuoron jälkeen: Tero haastaa kädenvääntöön (häviäjä tarjoaa
  kierroksen). Illan pubivisassa kolme kysymystä Raahesta (kaikki oikein: visajuoma talon piikkiin).
  Portaat alas Kellariin (ent. Kajuutta): karaoke "Ruukin valot". Puhe on raahelaista (räknätä, skooli, kööki,
  retari, seeli). Ulko-ovelta taksi kotiin: Päivi odottaa, eikä seuraavana aamuna tule rahaa kauppaan.
  Pyörä jää kaupan pihaan.
- **Retket (retkirunko):** taksikuski vie Raahen lisäksi muihinkin kohteisiin (taksivalikko generoidaan rekisteristä
  `scripts/retket.gd`: nimi, lähtöpaikka, matkan kesto, meno-paluu-hinta ja kohtaus). Kohde on oma taskukohtaus (`retki_*.gd`), jossa
  kävellään kuten Raahen baarissa. Ovelta (taksille) E vie takaisin **lähtöpaikkaan** samaan paikkaan, josta lähdettiin: päivä ei vaihdu,
  paluumatka on jo maksettu ja kello siirtyy matkan keston verran sekä menossa että tullessa. Yöllä sammutaan kuten muuallakin
  (herätys kotona). Uusi kohde = yksi rivi rekisteriin ja yksi tiedosto; Vaalan aseman matkavalikko (`lahto: "vaala_asema"`)
  generoidaan samasta rekisteristä, kun ensimmäinen Vaalan kohde tulee.
- **Matkaopas (B):** taksikuskilta saa kerran pehmeäkantisen taskuoppaan (taksivalikon valinta "Onko sulla mitään esitettä näistä
  retkipaikoista?"; tallentuu ensikertana `matkaopas`, näkyy repussa). Opas on aukeama (`scripts/matkaopas.gd`): kansilehti ja
  sisällys (käydyt rastitettu, klikkaus vie sivulle), sitten sivu jokaisesta rekisterin kohteesta. Nimi, lähtöpaikka, kesto ja
  meno-paluuhinta näkyvät heti, samat luvut kuin taksivalikossa. Kuvaus (rekisterin `opas`, puuttuessa `sub`) näkyy vasta, kun
  kohteessa on käyty (`retki_<id>`) tai siitä on kuultu (rekisterin `kuultu`-ehto: taksikuskin legendat Hanhikivi, Pakkahuone,
  peruskivi ja Manamansalo); muuten "???". Käydyllä sivulla on KÄYTY-kumileima. Kuvaukset eivät paljasta legendojen ratkaisuja.
  "→ taksitolppa kartalle" asettaa kompassin taksitolpalle. Selaus A/D, nuolet, rulla ja sivunkulmat; peli on tauolla, Esc tai B sulkee.
- **Teeriniemen kalalampi (retki):** taksilla 16 € (meno-paluu, 25 min suuntaansa) Teeriniemen leirintäalueelle: tukkimökin tiskiltä
  ostetaan kalalupa (8 €, kerran, tallentuu; hintaan kuuluu vuokraonki ja 8 matoa, jotka eivät kuluta omia matoja). Ilman lupaa lammella
  ei onkea. Istutetussa lammessa (kalat kiertävät näkyvissä) onkiminen on pelin onkimekaniikka (`shore_fish_game.gd`, tila `stocked`):
  istutettu kala syö nopeasti (tärppi 1-3 s), ei roskaa eikä parvirenkaita (toisin kuin soutuveneessä). Saalis on kirjolohi
  (vaaleanharmaa, punertava kylkiraita, mustat pilkut) tai harvinaisempi ja väkevämpi taimen (ruskea, punaiset pilkut vaaleissa
  renkaissa), ja se menee reppuun kuten muukin saalis. Testi `--scene=kalalampi`.
- **Nurmikon leikkuu:** takapihan nurmikko kasvaa joka päivä. Leikkurin luona E käynnistää (ja sammuttaa), ja
  leikkuria työnnetään kuten kävellessä (ei juosta). Pitkässä ruohossa piilee siilejä ja kiviä: toinen siili leikkurin
  alle tuo poliisin (pakene näkyvistä, kiinni jääminen = WASTED), ja toinen kivi rikkoo leikkurin (varaosa Artolta
  8 € ja kalja, niin korjataan). Leikattu nurmikko tuo aamulla Päiviltä 5 € ylimääräistä. Leikkaamattomasta Päivi
  motkottaa ja Anna-Liisa kommentoi, ja siilejä ja kiviä tulee lisää.
- **Väinö karkuteillä:** joskus Pekan koira Väinö karkaa ("VÄINÖ PERKELE!"). Se nuuhkii ja pakenee: juoksijan
  ja pyöräilijän se kuulee kaukaa, joten nuuhkivan Väinön viereen hiivitään kävellen ja se otetaan kiinni E:llä.
  Grillimakkara houkuttelee sen luo. Palautuksesta Pekka antaa vitosen ja kaljan.
- **Vieras koira:** metsänreunassa kuljeskelee tumma vieras koira, joka murisee ja puree liian lähelle tulevaa.
  Purtu jalka ontuu, pyöräily on raskasta ja kunto palautuu hitaasti. Haava hoidetaan kotikonstein: Pekka sitoo
  sen ja kaataa päälle koskenkorvaa (kalja tai 3 €), tai Päivi kotona laittaa laastarin ja motkottaa. Hoitamaton
  haava paranee yön aikana.
- **Pontikka:** jossain metsässä Pannu-Sulo keittää pontikkaa. Paikka ei näy kartalla, mutta kodan tarinoista
  saattaa kuulla vihjeen. Sulo myy päivässä yhden kanisterin (20 €), joka vastaa kotijemmassa 24 kaljaa.
- **Saloislainen sähköpyörä:** autotallin työpöydällä syntyy idea: tavallinen pyörä sähköpyöräksi osilla sieltä
  täältä. Napamoottori huudetaan Seuranmäen kirppiksen huutokaupasta, Makitan akut saa Pekalta litrasta sieniä,
  ohjain ja kaasukahva löytyvät Tokolan vanhasta varastosta ja johdot Artolta kaljaa vastaan. Kiinnitystarvikkeet
  K-Marketin rautahyllystä (jeesusteippi, nippusiteet, sähköteippi), kirppikseltä (ruuvipurkki, rautalanka) ja
  työkalutaululta. Kasaus on työpöydän minipeli: jokaiseen liitokseen (moottori, akku, ohjain, kaasukahva, johdot)
  valitaan kiinnitys. Ruuvit väännetään hiirtä pyörittämällä ja pysyvät, jeesusteippi kierretään (liian kova veto
  rypistää) ja irtoaa kuopissa ja juurakoissa, nippuside kiristetään vihreälle (yli punaisen katkeaa) ja irtoaa
  harvemmin, rautalanka väännetään A/D ja pitää mutta kolisee (teinit kiinnostuvat pyörästä). Johdot ilman
  sähköteippiä oikosulkevat vedessä ja rämeessä. Ajossa avustus nostaa kiihtyvyyttä ja huippunopeutta, eikä
  avustettu spurtti väsytä; akku (palkki kunnon alla) tyhjenee ja latautuu tallissa ja kotona yön yli (Päivi
  huomaa sähkölaskun). Tyhjä tai irronnut akku tekee pyörästä raskaan. Irronnut osa teipataan tien varressa
  jalan E:llä, oikosulku korjataan tallissa. Testi `--scene=sahkopyora`.
- **Oma mopo (#155):** Sepon pressun alla ollut Hopeanuoli. Seppo myy sen vasta tutulle: ostokset, marjat, Nokia ja
  yllätyslaatikot kasvattavat luottamusta, ja Kekkosen rintamerkin palauttaminen ("isävainaan merkki!") avaa kaupan
  heti puoleen hintaan. Hinta riippuu Sepon mielialasta. Mopo tulee talliin romuna: ketju ja ratas Huhtalan
  romuista (Datsunin alta), sytytys Autosähkö-Simolta, satula Sepolta (muistoesine, maksaa erikseen) ja ajovalo
  Tokolan Aarolta (pojan sähkömopo vuodelta -82). Tallissa kokoaminen, kaasarin säätö (sama minipeli kuin SLN-73:lla),
  bensa SEO:n kanisterista ja potkukäynnistys tallin oikealla mopolla (hahmo potkii polkimesta): rikastin päälle, potku vihreälle kahdesti, rikastin pois ja vielä
  kerran. Liian kova potku potkaisee nilkkaan, ja Päivi tulee talliin kommentoimaan. Käynnistyessä pakoputki
  tupruttaa, talli täyttyy sinisestä huurusta, ja Päivi lähtee yskien ulos. Pärinä on syntetisoitu kaksitahtiääni
  (two_stroke.gd: sytytyspamaukset kierrosten tahdissa, epätasainen käynti ja ohilyönnit), sama ajossa. Mopolla ajetaan pyörän tapaan (F ja
  talliovi), mutta kaasulla ilman kuntoa: Sepon vuonna 1979 irrottama rajoitin pois 21 m/s, rajoittimella 15 m/s.
  Bensa kuluu (palkki kunnon alla), tyhjällä tankilla mopoa taluttaa, ja SEO:lla tankataan. Katsastus hylkää ilman
  ajovaloa ja rajoitinta. Rossiradalla mopolla on oma kierrosaika, ja Päivi motkottaa romusta aamuisin. Testi
  `--scene=mopo`.
- **Seuranmäen seuraintalo:** kartan pohjoisosassa punainen seuraintalo, sisällä kirpputori (auki klo 10–18):
  mummo Hilkan virkkuuliinat, Railin rihkama (VHS-kasetit, posliinikoirat), Taunon työkalut ja lavalla huutaja
  Erkki. Naapurin Anna-Liisa tinkii vieressä ja kommentoi. Tinkiminen keskustellen: myyjä hyväksyy tarjouksen,
  tekee vastatarjouksen tai suuttuu loppupäiväksi; maine auttaa, eikä alle 40 %:n mennä. Huutokauppa kerran
  päivässä salin lavan edessä: pelaaja istuu tuolirivissä mummo Elvin ja ukko Veikkosen välissä, Erkki kääntyy
  vilkuilemaan yleisöä ja valokeila osoittaa katsottavaa, ja huuto menee läpi vain, kun hän katsoo sinua (käsi ja
  numerolappu ylös); "ensimmäisen, toisen… kolmannen kerran!" Erkin puhekuplassa ja nuija kopahtaa.
  Testi `--scene=kirppis`.
  - **Oma kirppispöytä (#128):** salin etuosassa vuokrattava pöytä ("OMA PÖYTÄ"): Hilkalta paikka 2 €/päivä (puheesta
    tai pöydän luota E), jonka jälkeen pöydän taakse pääsee koko päiväksi. Pöydälle viedään repusta kaikki myytävä:
    marjat ja sienet (litroittain ämpäristä), savukala ja savuriista sekä tiskin alta kalja ja pontikka. Ostajat
    (mummo, mökkiläinen, Anna-Liisa, nuori mies) tulevat pöydän ääreen yksi kerrallaan ja tekevät tarjouksen; pelaaja
    hyväksyy (H), tekee vastatarjouksen (W/S hinta, väli) tai heittää ostajan pois (X). Ostajalla on piilotettu
    enimmäishinta: mummo ja Anna-Liisa tinkivät, mökkiläinen maksaa enemmän, mutta yli 20 % enimmäishinnan ylittävä
    vastatarjous ajaa ostajan pois ("Pihi kuin Pekka") ja liian moni epäonnistunut yritys (sydämet) tyhjentää
    kärsivällisyyden. Liian halpa myynti jättää rahat saamatta. Kalja ja pontikka myydään vain nuorelle ostajalle, ja
    kauppa onnistuu vain, kun Anna-Liisa katsoo muualle (silmämerkki vihreä, varoitus ennen kuin hän kääntyy takaisin):
    kiinni jäädessä peli päättyy, maine −4, Päivi kuulee, ja Hilkka antaa 55 %:n todennäköisyydellä myyntikiellon
    huomiseen. Pöytäkerran jälkeen maine: reiluja kauppoja ("Rehellinen kauppamies" +3 tai "Reilu myyjä" +1) tai
    liikaa tyly tinkiminen ("Pihi kuin Pekka" −3). Reilu hinta: puolukka 6 €/l, mustikka 7, kantarelli 14, herkkutatti
    11, savukala 7, savuriista 9, kalja 15, pontikka 20. Pelin aikaa kuluu tunti per neljä asiakasta. Pekan vanhoja
    tavaroita ei vielä myydä. Testi `--scene=kirppismyynti`.
  - **Hiihtohaalari:** Railin vaatetangossa keskipöydän vieressä (vakosamettitakin ja flanellipaidan välissä)
    roikkuu neonpinkki kasarin toppahaalari, 6 € (tinkiä voi). Valkoinen olkakaarroke sahalaitaisin vuorenhuipuin,
    keltainen ja turkoosi raita, tikkauskanavat, vetoketju, mustat resorit, kuukengät ja raidallinen frotee-otsapanta
    (mitoitetaan pään ja tukan mukaan). Ostettuna moraali nousee hieman, Anna-Liisa nauraa, ja haalari tulee kodin
    vaatekaappiin. Haalarissa Anna-Liisa nauraa seuraintalolla ja Päivi motkottaa kotiovella kerran päivässä.
    Testi `--scene=haalari`.
  - **Drakkar Noir (legendaarinen hetki):** Railin pöydällä puolillaan oleva musta pullo (12 €). Kun pullo loppuu,
    Railin pöydälle tulee uusi (legendaarinen hetki vain ensimmäisestä).
    Pullossa 10 suihkausta, suihkaus T-valikosta. Tuoksu kestää päivän: moraali ja mielihyvä nousevat, Sinikka
    huomaa sen ("Tuu vähän lähemmäs, komistus"), Päivi haistaa sen kotiovella, ja seuraintalon tansseissa ja
    lavalla tulos paranee. Toinen suihkaus samana päivänä on jo liikaa. Testi `--scene=drakkar`.
- **Saloisten kirkko, kellotapuli ja hautausmaa (#123):** kartan länsilaidalla (kartta ulottuu nyt px x −250:een).
  Valkoinen puukirkko jyrkkine kattoineen ja kuparinvihreine tornin huippuineen (nimikyltti tien puolella, nykyinen
  kirkko 1932), punainen puinen kellotapuli (1783) kelloineen ja OSM:n rajaama hautausmaa matalan aidan sekä
  hautakivirivien kera (osassa puuristi). Paikat ovat vielä koristeita: tulevat legendat (#125 Palon yön pyhimys,
  Olavinmarkkinat, kellotapuli) rakentuvat niiden varaan. Testi `--scene=kirkko` (headlessinä vain luvut, kuvat vaativat
  ikkunan).
- **Legenda: Palon yön pyhimys (#125):** oikea tausta Wikipedian mukaan: Saloisten vanha puukirkko paloi loppiaisaamun
  jumalanpalveluksen aikana 1930 (issuen "1908" ei löydy lähteestä), nykyinen kirkko valmistui 1932, ja palosta pelastettiin
  mm. Pyhän Olavin ja Neitsyt Marian veistokset ja alttarikaapit. Legenda on keksitty ja pelissä totta: yksi pieni puinen
  pyhimys katosi palon yönä, kun talollinen vei sen kotiinsa eikä uskaltanut palauttaa. Ketju: hautausmaan hoitaja kertoo ->
  suntio näyttää luettelon yliviivatun rivin ("pieni pyhimyskuva, puuta") -> palon vuosipäivän iltana (pelissä joka 6. päivä,
  klo 18–23) talollisen haudalla palaa kynttilä ja siellä on iäkäs nainen, joka kertoo suvun asuneen Tokolassa, kun lupaat
  pitää nimen salassa -> Aaro muistaa mummon aitan pyhän nuken -> pyhimys Tokolan vanhan varaston orsilta -> suntiolle
  kirkkoon. Palautus: loppu "Palon yön pyhimys", maine +10, kynttilä sammuu, nainen käy vuosipäivinä kirkon edessä, ja
  suntion, Pekan ja Sinikan epäilyt vaihtuvat. Testi `--scene=palonpyhimys` (toimii headlessinä).
- **Legenda: Olavinmarkkinoiden hopea (#124):** oikea tausta (Visit Raahe): Saloinen sai 1616 vapaat markkinat
  Olavinpäivästä kahdeksi viikoksi, kauppiaita tuli monesta kaupungista ja talonpojat myivät mm. tervaa ja voita; Raahen
  perustamisen jälkeen markkinat siirtyivät Rantatorille. Legenda on keksitty ja pelissä totta: kauppias Olof Skyttä
  (hautakiven nimi ja vuodet keksittyjä) kätki markkinarahansa. Ketju: kirppiksen Hilkka kertoo -> Saloisten Pirtti antaa
  kauppiaan kirjeen ("kirkon rannan luoto", pelin tulkinta Kirkkoluodontiestä) -> hautausmaan sammaloitunut kivi ja tuoreet
  kukat -> Olavi-pappa (päivisin hautausmaalla) kertoo ja pyytää kaljaa -> lupa kaivaa -> lapio autotallin vasemmalta
  seinältä -> lipas Kirkkoluodontien länsipuolelta sammaloituneen kiven vierestä. Olavinpäivä on pelissä joka 7. päivä:
  sen yönä (22–4) Olavi-pappa seisoo lyhdyn kanssa kätköllä; muina öinä lyhty on Pannu-Sulon toimitusreitillä (Sulo antaa
  pullon pontikkaa vaitiolosta). Valinta: Pirtti/museo (palkkio 60 €, maine +12, lehtijuttu, loppu "Olavinmarkkinat
  palasivat") tai Veksi (240 €, maine −8, poliisi hakee kylällä). Museovalinnan jälkeen joka Olavinpäivä 10–18
  seuraintalolla on Olavinmarkkinat: banderolli, ja kirppiksellä tervatuoppi, voita ja markkinamakkaraa. Epäilijät
  (Pekka, Arto, Anna-Liisa) vaihtavat repliikkinsä. Testi `--scene=olavinmarkkinat` (toimii headlessinä).
- **Legenda: Kuninkaan tapuli (#126):** oikea tausta (Visit Raahe): kellotapuli on vuodelta 1783 ja "sanotaan" Kustaa III:n
  suunnittelemaksi (varmistamaton; OSM antaa 1786). Legenda keksitty ja pelissä totta: kuninkaan sinetöity piirustus
  muurattiin rakenteisiin, minkä vuoksi tapuli säästyi kirkon palossa. Kello kumahtaa yöllä, koska kylän teinit pitävät
  tapulissa bileitä. Ketju: suntio kertoo -> yöllä kello kumahtaa (22–4, ei ennen kuin legenda on kuultu) -> tapulin juurella
  teinit pakenevat ja pudottavat avaimen kopion (tai suntio antaa avaimen, kun kirkon palon legenda #125 on selvitetty) ->
  Pirtin rakennusasiakirja "G. R." tai droonin ilmakuva räystään kruunusta -> lyijykotelo ylimmän palkin kolosta.
  Valinta: Pirtin oppaalle (70 €, maine +12, loppu "Kuninkaan tapuli", Arton ja Pekan repliikit vaihtuvat) tai takaisin
  koloon suntion luona (maine +4, avain pysyvästi): tapuli on silloin jemma (24 kaljaa) ja kello varoittaa, kun poliisi
  on liikkeellä. Teinien bileiden jatkuminen tai loppuminen ei ole mukana. Testi `--scene=kuninkaantapuli` (headless).
- **Vaalan nuorison hupihommat (#183):** (1) *Mopon viritys*: Saloisen autotallin virittämöstä (työkalulaatikko mopon vieressä,
  E) ajokuntoiseen mopoon isompi sylinteri (14 €, +1,4 m/s), urheilupakoputki (9 €, +1,0) ja pienemmät rattaat (7 €, +0,8);
  kukin vie 30 min ja nostaa huippunopeutta (rajoittimella 15 → 18,2 m/s, ilman 21 → 24,2 m/s), ja ajossa mitataan huippunopeuden
  ennätys. Lavan pihan teinien keskusteluvalinnat (Vaala, `nuoret`): (2) *Pullonkeräys* aamulla 6–11 (9–16 kpl, pantti 0,15 €/kpl,
  40 min). (3) *Liian nuoret portailla* illalla 18–23: uutta purukumia lapsille (1,50 €, maine +1), ettei tarvitse pestä vanhoja.
  (4) *Kasetin äänitys*: tyhjä kasetti 1 € ja 20 min radiosta; sen jälkeen oma kasetti teinien soittimeen kerran päivässä (65 %
  tykkää: maine +2, mielihyvä; muuten maine −1). (5) *Mopoletka* yöllä 23–03 toimivalla mopolla (bensaa −12 %, moraali ja
  mielihyvä, 18 % todennäköisyydellä poliisi). (6) *Järkkäri*: Street Fighter -tappelu lavan pihalla illalla 20–24 kerran päivässä
  (fight.gd "jarkkari"; voitto maine +3, tappio −5 € ja maine −3). (7) *Uimakilpailu* iltapäivällä 12–18 kerran päivässä
  (`uinti_game.gd`): ponkkarihyppy (aika vihreälle) ja 100 m vuorotellen A ja D kahta nuorta vastaan; voitosta maine +4 ja
  ennätysaika. Kioskilla Zabukin luona illalla 18–23 *hengailu* (tunti, moraali, stressi, mielihyvä). Voimayhtiön *kesäduuni*:
  Vaalan työkkärissä aamulla 8–12 rantojen siivous 4 h, 28 €. Testit `--scene=hupihommat`, `--scene=lavatappelu` ja
  `--scene=uintikisa`.
- **Pieneläintuhkaamo Lemmikki Enkelit (#148):** kylän länsiosassa (OSM office=company) lämminhenkinen, rauhallinen paikka
  (pastellikyltti enkelinsiipineen, piippu, valkoinen aita). Rakennuksen edessä muistolehto: sorapolku, penkki, kynttilälyhdyt
  ja lemmikkien nimikyltit (Misu, Rekku, Nalle). Penkillä E: stressi laskee kerran päivässä (20 min), kaljaa ei avata. Iltaisin
  (16–19) portilla käy Pekka "vaan katsomassa": ensin kömpelö vitsi piipusta (luuli yleiseksi saunaksi), sitten lämmin hetki
  vanhan Väinön pelosta. Sivutehtävä (jalkapallopojat, vain jos pojat ovat kentällä): pojat kertovat pikkuveljen hamsteri Pörrön
  kuolleen, ja pelaaja maalaa lehtoon muistokyltin pienellä minipelillä (muistokyltti_game.gd: kirjaimet P, Ö, R, R, Ö
  näppäimillä, sydän, käpälä ja lauta tolppaan; ei aikapainetta). Valmistuttua Pörrön kyltti näkyy lehdossa, pojat eivät heitä
  enää koskaan kiviä ("Setä on ihan ok") ja maine +5. Sävy on kunnioittava: ei vitsejä kuolleista lemmikeistä. Testi
  `--scene=lemmikkienkelit`.
- **Legenda: Kanttorilan yösävel (#144):** Kanttorila on OSM-talo kylän länsiosassa (nimikyltti seinässä). Sen historiaa ei
  löytynyt (Saloisten seurakunta perustettiin 1912, nykyinen kirkko valmistui 1932), joten kaikki talosta kerrottu on
  keksittyä ja Pirtiltä tai museolta tarkistamatta. Legenda (pelissä totta): kanttorin virren nuotit katosivat, ja talosta
  kuuluu öisin urkuja. Ketju: Hilkka tai Sinikka kertoo -> yöllä (22–4) Kanttorilan pihalla ensin teinien kaiutin (kimeä
  neliöaalto), jonka jälkeen oikea urkusävel (syntetisoitu koodissa) -> seuraintalon huutokaupassa harmooni, jonka
  palkeesta nuottiarkin ensimmäinen puolikas -> Pirtin arkistosta toinen puolikas -> Sinikalle (kuoro laulaa virren,
  maine +12, loppu "Kanttorin virsi", yösävel vaikenee) tai Veksille (150 €, maine −5, yösävel jatkuu). Epäilijät (Pekka,
  Arto, Anna-Liisa) vaihtavat repliikkinsä. Testi `--scene=kanttorinyosavel` (headless).
- **Legenda: Hanhikiven rajakivi (#250 P4, tarkistettava):** Pyhäjoen Hanhikivi, Koskipuisto ja Hourunkosken kosket ovat
  oikeita paikkoja; rajakiviteoria ("kivi oli ennen rajamerkki ja joku siirsi sen") on epävarma ja esitetään vain huhuna
  ("sanotaan", "kuulemma"), kukaan ei tiedä kuka. Ketju: taksikuski kertoo (valinta "Mikä se Hanhikivi oikein on?") ->
  vihje 1: Kapteenin Kulman kapteeni Raahessa -> vihje 2: Koskipuiston opaskyltti Pyhäjoella (retki taksilla 20 €, 35 min,
  `retki_hanhikivi.gd`: puisto, kosket, kivi ja laatta, kalastaja, penkki) -> kiveä tutkimalla, kun molemmat vihjeet on kuultu,
  loppu "Hanhikiven rajakivi" (maine +3, ei rahaa, kerran). Näkyy päiväkirjassa. Tila `hanhikivi_legenda.gd`. Testi `--scene=hanhikivi`.
- **Legenda: Pakkahuoneen veistos (#250 P5, tarkistettava):** Raahen Pakkahuone on museona, sanotaan Suomen vanhin paikallismuseo,
  ja siellä on 1600-luvun uskonnollisia veistoksia (esitetään "sanotaan"-muodossa). Kadonnut veistos on keksitty. Ketju: taksikuski kertoo
  (valinta "Mikä se Pakkahuone oikein on?") -> veistos katoaa jalustaltaan museossa (retki taksilla 12 €, 20 min, `retki_pakkahuone.gd`) ->
  kuraattori ja vierailijakirja vihjeinä -> kellarin luukku, kun molemmat on kuultu: veistos löytyy ja palaa jalustalle, loppu
  "Pakkahuoneen veistos" (maine +3, ei rahaa, kerran). Näkyy päiväkirjassa. Tila `pakkahuone_legenda.gd`. Testi `--scene=pakkahuone`.
- **Legenda: Rautaruukin peruskivi (#250 P6, tarkistettava):** Rautaruukin Raahen terästehtaan Rojuniemen peruskiveä sanotaan paljastetun
  25.8.1962 (Kekkonen) ja ensimmäinen lähetys sanotaan 5.9.1964 (päivämäärät tarkistettava, esitetään "sanotaan"-muodossa). Kätkö (kuparikapseli
  laatan alla) on keksitty, kuten Tokolan aarre. Ketju: taksikuski kertoo (valinta "Mikä se Rautaruukin peruskivi oikein on?") -> vihje 1: vartija
  Rojuniemessä (retki taksilla 4 €, 10 min, `retki_rojuniemi.gd`: tehdas, aita, vartijakoppi, peruskivi, laatta) -> vihje 2: opaskyltti ->
  laatta kiven edessä, kun molemmat on kuultu: kätkö aukeaa, löytäjäispalkkio 30 € ja maine +3, loppu "Peruskiven kapseli". Palkkio vain kerran
  (`found`-lippu). Näkyy päiväkirjassa. Tila `peruskivi_legenda.gd`. Testi `--scene=peruskivi`.
- **Legenda: Manamansalon muistokirkko (#250 P7, tarkistettava):** Oulujärven suurin saari Vaalassa; sen sanotaan olleen metsästäjien hautausmaasaari ja
  Kainuun ensimmäisen kirkon sanotaan rakennetun sinne 1559. Nimen "kuolemansaari" tulkinta on epävarma, ja peli esittää sen vain taksikuskin ja oppaan
  tulkintana. Ketju: taksikuski kertoo (valinta "Mikä se Manamansalon kuolemansaari oikein on?") -> vihje 1: opas kirkon edessä (retki taksilla 30 €, 60 min,
  `retki_manamansalo.gd`: muistokirkko, hautausmaa, laituri) -> vihje 2: hautausmaan infotaulu -> kirkon kivijalka mäellä: legendan loppu, kynttilä
  syttyy, maine +3 (ei rahaa). Näkyy päiväkirjassa. Tila `manamansalo_legenda.gd`. Testi `--scene=manamansalo`.
- **Retki: Wanha Raahe, kävelykierros (#250 P8, tarkistettava):** taksilla Raahen vanhaan puutalokaupunkiin (valinta "Raahen Wanhaan kaupunkiin", 12 €, 20 min,
  `retki_wanharaahe.gd`). Viisi pysähdystä järjestyksessä: Brahen patsas Pekkatorilla (sanotaan 1888, Raahen perustaja 1649), vanhat ovet, kauppiaan kaksikerroksinen talo,
  rantakuja ja katulyhty sekä punamullattu makasiini. Pysähdyspaikalla E ottaa valokuvan, jos hahmo katsoo kohdetta kohti (sama kulma- ja etäisyystarkistus kuin
  dronen kuvissa, `PHOTO_RANGE`/`PHOTO_CONE`); väärä järjestys tai suunta ei ota kuvaa. Ovien kuva tulee reppuun ja viedään kotiin Päiville (kerran, mielihyvä +8);
  kaikki viisi kuvaa: maine +2. Näkyy päiväkirjassa. Patsas ja talot ovat tyylitelty, ei tarkka kopio esikuvasta. Tila `wanharaahe_legenda.gd`. Testi `--scene=wanharaahe`.
- **Retki: Paltaniemen kuvakirkko, piilokuvaetsintä (#250 P9, tarkistettava):** taksilla Kajaanin Paltaniemen kuvakirkkoon (valinta "Paltaniemen kuvakirkkoon", 28 €, 55 min,
  `retki_paltaniemi.gd`). Kirkon sisällä on penkkirivit, alttari, saarnastuoli ja takaseinällä kolme maalausta; suntio kertoo kirkosta (sanotaan: seinät maalattu 1700-luvulla).
  Maalauksille E avaa minipelin `kuvakirkko_game.gd`: taivas ja maa, arkki ja puutarha -maalauksissa on kuusi piilokuvaa (tähti, kala, kissa, lintu, avain, etana). Hiirellä
  (suurennuslasi) klikataan löydetty, alareunan lokerikko ja laskuri n/6 näyttävät tilan, huti värähdyttää ja 20 s ilman löytöä kimaltaa lähin. Löydöt säilyvät käyntien välillä
  (Esc kesken); kaikki kuusi: maine +2 (kerran). Näkyy päiväkirjassa. Kirkon 3D-seinämaalaukset piirretään samalla koodilla kuin minipeli (SubViewport-tekstuuri, `painting_viewport`); suntion kupla on maailmassa vasemmalla (ei maalauksen päällä). Maalaukset ovat tyyliteltyjä, eivät kopioita kirkon maalauksista. Tila `kuvakirkko_legenda.gd`. Testi `--scene=kuvakirkko`.
- **Retki: Saloisten tietokonemuseo ja Pong (#250 P10, tarkistettava):** taksilla Saloisten tietokonemuseoon (valinta "Saloisten tietokonemuseoon", 6 €, 12 min,
  `retki_tietokonemuseo.gd`). Sisällä on Datasaab D22 -koneen neljä kaappia (pyörivät nauharullat, vilkkuva merkkivalopaneeli, korttilukija) konsolipöytineen, mikrotietokonehuone
  (kolme tyyliteltyä 1980-luvun konetta) ja Pong-pelikone; intendentti kertoo kokoelmasta (puhekupla maailmassa). Faktat "sanotaan"-muodossa ja tarkistettavia: D22 vuodelta 1971 ja
  heinäkuun aukioloaika (pelissä museo on aina auki). E D22:lla ja mikroilla näyttää tietoviestin. E Pong-koneella avaa minipelin `pong_game.gd`:
  beige CRT-televisio museon pöydällä, pelaaja vasemmalla (W/S, nuolet tai hiiri), kone oikealla, ensin viiteen pisteeseen; pallo kiihtyy jokaisesta mailaosumasta ja kimpoaa osumakohdan
  mukaan, hehku, pyyhkäisyviivat, kipinät, tärähdys ja äänet. Ensimmäinen voitto: mielihyvä +6 (kerran); voitot ja paras tulos tallentuvat (`tietokonemuseo_legenda.gd`). Näkyy päiväkirjassa
  intendentin puheen jälkeen, kunnes Pong on voitettu. Yöllä museoon nukahtaa (herätysteksti retket.gd:n kentästä "sammuit"). Testi `--scene=tietokonemuseo`.
- **Retki: Raahen satama, Vanha herra ja sukellus (#250 P11, tarkistettava):** taksilla Raahen satamaan (valinta "Raahen satamaan", 12 €, 20 min, `retki_vanhaherra.gd`).
  Kruununmakasiinin vitriinissä on "Vanha herra" (kuparikypärä, kangaspuku, lyijykengät; sanotaan maailman vanhimmaksi säilyneeksi sukelluspuvuksi, tarkistettava museon kuvasta).
  Laiturilla pumppaaja (kädet pumpun vivussa) ja sukeltaja kuparikypärässä puhekuplineen. Pumpusta alkaa minipeli `sukellus_game.gd`: A ja D vuorotellen pumppaavat ilmaa
  (tahdissa bonus, sama näppäin kahdesti ei anna), ilmamittari tyhjenee pohjalla; E/Väli kaivaa. Pohjalla on saapas, ämpäri, pullo ja ankkuri, ja kapteenin taskukello puuarkun alla.
  Löytyessä mielihyvä +6 ja maine +1 (kerran, `vanhaherra_legenda.gd`); Esc keskeyttää, uusi yritys käy aina. Näkyy päiväkirjassa pumppaajan kanssa puhumisen jälkeen. Testi `--scene=vanhaherra`.
- **Retki: Kuhmon karhukätkö (#250 P12, tarkistettava):** taksilla Kuhmoon (valinta "Kuhmon karhukätköön", 45 €, 90 min, `retki_kuhmo.gd`). Puinen kätkö, penkki, infokyltti ja opas puhekuplineen
  (paikka ja aikataulut "sanotaan"). Ikkunasta alkaa minipeli `karhu_game.gd`: hämärä niitty, odotus, karhu kävelee tai nousee pystyyn; etsin hiirellä, kuva klikkauksella/Välilyönnillä,
  kuusi ruutua. Karhu keskellä, iso ja pystyssä = paras kuva. Humala (`tilat` humala) heiluttaa etsintä. Hyvä kuva (60+/100): mielihyvä +6 ja maine +1 kerran (`karhut_legenda.gd`),
  paras tulos tallentuu. Näkyy päiväkirjassa oppaan puheen jälkeen. Testi `--scene=karhut`.
- **Retki: Sotkamon Hiidenportti (#250 P13, tarkistettava):** taksilla Sotkamoon (valinta "Sotkamon Hiidenporttiin", 38 €, 70 min, `retki_hiidenportti.gd`). Kalliorotko (kerroksittain porrastetut, vaaleahuuliset kalliot halkeamineen ja sammalineen, puro pohjalla, havupuita reunalla; esikuva Porttijoen rotko), lepolavat, infokyltti ja
  retkeilijä puhekuplineen (tiedot "sanotaan"). Seinältä alkaa minipeli `rotko_game.gd`: klikkaa ote käden ulottuvilta, ote ja roikkuminen kuluttavat voimia, lepolavalla ne palautuvat;
  punertava ote murtuu, humala lisää lipsumista. Putoaminen palauttaa viimeiselle lavalle. Ylälavalle päästyä mielihyvä +6 ja maine +1 kerran (`hiidenportti_legenda.gd`).
  Näkyy päiväkirjassa kyltin lukemisen jälkeen. Testi `--scene=hiidenportti`.
- **Retki: Pyhäkosken voimalaitoskylä (#250 P16, tarkistettava):** taksilla Oulujoen varteen (valinta "Pyhäkosken voimalaitoskylään", 24 €, 45 min, `retki_pyhakoski.gd`). Voimalaitos,
  punainen kioski, tanssipaikan portaat, rivitalot ja vahtimestari puhekuplineen (kyltit fontti 60-72). Kolme tarinaa: vahtimestari (voimalaitos), kioski ja portaat; kaikki "sanotaan"-muodossa,
  hiljainen sävy, ei minipeliä. Kun kaikki kolme on kuultu: mielihyvä +4 ja maine +1 kerran (`pyhakoski_legenda.gd`). Näkyy päiväkirjassa ensimmäisen tarinan jälkeen. Testi `--scene=pyhakoski`.
- **Retki: Kajaanin linna ja Messenius (#250 P17-P18, tarkistettava):** taksilla Kajaaniin (valinta "Kajaanin linnan raunioille", 30 €, 60 min, `retki_kajaani.gd`). Joen saaren harmaakiviset rauniot, tervavene laiturissa ja Messeniuksen muistotaulu
  (kyltit fontti 60-72), tervamies puhekuplineen. Kolme asiaa: rauniot, tervavene (kohtaus: vene lipuu joen poikki ja tervamies kertoo) ja Messeniuksen vankeus (1616-1636, sanotaan); kaikki "sanotaan"-muodossa, ei minipeliä.
  Kun kaikki kolme on koettu: mielihyvä +5 ja maine +1 kerran (`messenius_legenda.gd`). Näkyy päiväkirjassa ensimmäisen jälkeen. Testi `--scene=kajaani`.
- **Retki: Kalajoen Hiekkasärkät, rantajalkapallo (#250 P19, tarkistettava):** taksilla Kalajoelle (valinta "Kalajoen Hiekkasärkille", 42 €, 80 min, `retki_kalajoki.gd`). Ranta, meri, dyynit, kenttä maaleineen, Hiekkasärkät-kyltti ja turnauksen järjestäjä puhekuplineen (kyltit fontti 60-72).
  Kentällä E käynnistää minipelin `rantapallo_game.gd`: sivukuvan rantajalkapallo (A/D liike, W hyppy, Väli potku), kone vastustajana, ensin kolmeen maaliin; pallo pomppii hiekasta ja rimasta, maalit verkolla.
  Juhannusaattona (perjantai, `_juhannus()`) voitto on turnausvoitto: mielihyvä +6 ja maine +1 kerran (`kalajoki_legenda.gd`), ja kentälle ilmestyvät koivut ja siimalippu. Muina päivinä saa harjoitella ilman palkkiota. Turnauksen koko ja tiedot "sanotaan"-muodossa, tarkistettava. Testi `--scene=kalajoki`.
- **Retki: Raatteen Portti, Suomussalmi (#250 P20, tarkistettava):** taksilla itään (valinta "Raatteen Portille", 30 €, 100 min, `retki_raate.gd`). Kunnioittava tarinaetappi talvisodan muistopaikalle: ei minipeliä eikä vitsejä. Kivipylväsportti Raatteentien päällä, muistokivi soihtuineen ja vanha vierailija puhekuplineen (kyltit fontti 60-72).
  Kolme kohtaa (vierailija/tie, portti, muistokivi), kaikki "sanotaan"-muodossa; aukioloa tai museota ei esitetä varmana. Kun kaikki on käyty: mielihyvä +3 ja maine +1 kerran (`raate_legenda.gd`). Näkyy päiväkirjassa ensimmäisen kohdan jälkeen. Testi `--scene=raate`.
- **Valentin Vaala -elokuvapäivät (#250 P14, ohjelma ja päivät tarkistettava):** Vaalan Veturitalli (punatiilinen vaja aseman päädyssä, kyltti "VAALAN VETURITALLI") on auki esityksiin kolmena viimeisenä päivänä 28 päivän jaksossa (päivät 26-28) klo 13-17; muulloin ovella kerrotaan syy. Ovella banderolli. E ovella: mykkäelokuvan tyylinen sepiaesitys (ohjelma yleinen, ei väitettyjä elokuvanimiä) ja 78-levyn iskelmä (`iskelmat.gd`); kello +40 min, stressi -0,1, mielihyvä +4. Esc poistuu kesken. Tiedostot `vaala.gd _build_veturitalli`, `vaala_esitys.gd`. Testi `--scene=valentinvaala`.
- **Saloisten koulukeskus, päiväkoti, kentät ja ulkopingis (#143):** keskustan koulukeskus ja päiväkoti (OSM-rakennukset)
  nimikylttineen, kaksi jalkapallokenttää rajaviivoineen ja maaleineen sekä koulun pihan ulkopingispöytä ("PIHAPINGIS").
  Pöydällä iltapäivisin ja iltaisin (14–21) E: haaste kylän nuorille samalla pingis_game.gd-minipelillä kuin Santun kanssa
  mökillä, mutta koulun pihalla ja heikommalla vastustajalla (taito 0,72 ja +0,06 jokaisesta voitosta, enintään 0,96).
  Voitto: nuoret tarjoavat limut, kerran päivässä maine +3, moraali ja stressi paranevat ("Setä on ihan ok"). Tappio: tarjoat
  limut (3 €), jos rahaa ei ole, maine −2 kerran päivässä. Päiväkodin toinen paikka px (585, 12) osuu leikkipaikkaan eikä
  omaan rakennukseen, joten kyltti on vain päiväkodilla px (725, 123). Ei vielä: koulun disko, Päivin työpaikka päiväkodissa
  eikä juniorien treenit. Testi `--scene=koulukeskus` (logiikka headlessinä, kuvat ikkunallisena).
 grillikioski seuraintalon vieressä (auki 11–23). Luukulta Raijalta makkaraperunat,
  lihapiirakka kaikilla, hampurilainen ja kahvi (ruoat reppuun, T syö). Illalla 18–23 kioskin edessä notkuu porukka
  mopoineen, ja juoruista kuulee mm. Pannu-Sulon kuusikosta ja Tokolan varastosta. Ilmoitustaululta alkaa
  sivutehtävä "Kadonnut Miisu": Tokolan Aaron kissa löytyy Aaron vihjeellä ja viedään takaisin (10 €).
  Lihapiirakkahaaste (4,90 €) syödään FPS-näkymässä pihapöydän penkillä: kädessä haastekokoinen lihapiirakka
  kaikilla (uppopaistettu kiiltävä kuori auki kuin simpukka, kolme nakkia, kurkkusalaatti, ketsuppi, sinappi ja
  sipuli), lautasella keko lisää, ja Raija, grillin omistaja Reiska, Juntti, rekkamies ja mummo kerääntyvät pöydän
  ympärille kommentoimaan, kannustamaan ja epäilemään puhekuplissa. Välilyönti haukkaa (pala lähtee), A ja D
  vuorotellen pureskelevat (kamera nyökkää) ja W juo limua (pullo huulille), ennen kuin vatsa täyttyy (kuva huojuu
  ja reunat vihertävät). Juntin seitsemän piirakan ennätyksen rikkominen on oma onnellinen loppunsa "Lihapiirakkakuningas", ja
  Päivi haistaa sipulin aamulla. Testi `--scene=reippari`.
- **Korjaamot:** P. Korpelan moottoriajoneuvohuolto (Volvo nostimella), Simo Niemelän liikkuva autosähkö
  (pakettiauto Pirtin lähellä), Heiskasen kaasu- ja sammutinhuolto sekä Huhtalan auto ja varaosat romuautoineen
  (auki 8–17). Pekan Volvo ei lähde joka kuudes päivä: Korpela korjaa sen kahdella kaljalla tai 25 €:lla, ja sen
  päivän kyyti Paapeliin on ilmainen. Simo korjaa sähköpyörän oikosulun ja lataa akun pakusta, Heiskaselta kaasupullo
  Pannu-Sululle (ilmainen kanisteri) ja sammutin kotiin (Päivi ilahtuu), Huhtalan romuista varaosia, ja romuauton
  takakontti on uusi jemma. Testi `--scene=korjaamot`.
- **Etelän erämaa:** Viitajärven laavu kartan lounaiskulmassa: tulitikuilla nuotio, makkara ja kalja tuovat
  onnellisen lopun "Erämaan laavu" (18 loppua), ja Viitajärvessä voi uida. Kaitasaaren kärjestä auringonlasku
  tekojärvellä (19–23), luonnonsuojelualueen kyltit (maastopyöräily paheksutaan) ja metson soidin aamuisin (8–10),
  Puntarimäeltä maisema.
- **Rauniot:** länsilaidan metsässä sammaloituneet kivijalat ja sortunut kiviaita (OSM:n nimetön raunio). Kivijalan
  kolo on uusi kaljajemma, iltaisin (20–01) teinit istuvat nuotiolla, ja kaljaa vastaan he vinkkaavat uunin
  raunioista: vanha valokuva, joka pääsee Saloisten Pirtin seinälle (maine). Testi `--scene=eramaa`.
- **Leikkipuistot:** Käpykadunpuisto, Herukkapolunpuisto ja neljä koulujen ja päiväkotien leikkipaikkaa: keinut,
  liukumäki, hiekkalaatikko, jousikeinu, penkki ja aita, päivisin (9–19) äidit penkillä. Keinuhyppy pelataan
  oikealla keinulla: pelaajan hahmo istuu keinussa kädet ketjuissa, kamera kuvaa sivulta ja penkin äidit katsovat
  taustalla. Vauhtia oikeaan tahtiin (W eteen, S taakse heilahtaessa, jalat pumppaavat; liian kova vauhti löysää
  ketjut), välilyönnillä hyppy hiekalle (onnistunut alastulo tai selälleen), ja pelaaja jää alastulopaikalleen.
  Hiekassa metrimerkit, ennätyslippu ja oma paras; Honganpalon Jeren 3,40 m ennätyksen rikkominen tuo maineen kerran (oman ennätyksen parantaminen ei). Hiekkalaatikosta voi kaivaa kolikoita tai
  leluja kerran päivässä, ja kalja penkillä äitien edessä maksaa mainetta (illalla rauhassa). Testi `--scene=leikki`.
- **Sepon varastomyyntipiste:** K-Marketin vieressä Sepon ruskea varasto rojuineen (telkkaripino, renkaat,
  sukset, pressun alla vanha mopo, joka "ei oo myytävänä, vielä"). Auki ti–su 10–18, ellei Seppo ole kalassa. Päivän
  kolme tuotetta (teippiä, nippusiteitä, ruuveja, rautalankaa, sähköteippiä tai kummallisuuksia) ja hinnat Sepon
  mielialan mukaan; kehuminen laskee tai nostaa hintoja, kaljan voi vaihtaa halpaan tavaraan. Yllätyslaatikko
  (5 €): roskaa, tarvikkeita, kakskymppinen tai Kekkosen rintamerkki, jonka Veksi ostaa 30 €:lla. Seppo ostaa marjat
  ja vanhan Nokian.
- **Saloisten säästöpiha:** punainen puutarhamyymälä, kasvihuone ja taimipöydät (ma–pe 9–18, la 9–15). Kukkakimppu
  Päiville: vie se kotiin sisälle (maljakkoon), niin aamulla kymppi ylimääräistä, ja kotiin viemätön kimppu lakastuu repussa; joka 14. päivä on Päivin syntymäpäivä (vihje
  edellisenä aamuna), jolloin kukat tuovat kakskymppiä ja unohdus vie seuraavan aamun kauppa-rahat. Sinikka pyytää tomaatintaimia
  (palkkiona pullaa), ja multasäkistä Päivi saa kukkapenkin. Testi `--scene=seppo`.
- **Honganpalon koulu:** 270 m kodista tiilinen koulu kylttineen, lipputanko, pyörätelineet ja kenttä maaleineen.
  Vahtimestari Reijo (8–16) maksaa 15 €, kun keräät iltaporukan roskat pihalta; ikkunasta näkyy Päivin luokkakuva
  vuodelta 1989. Illalla (19–23) portailla istuu porukka mopoineen ja juoruaa, torstaisin (17–19) pihalla on
  jäätelöauto, ja päivisin pojat lyövät rankkareita. **Legenda: Lapinraunion aarnivalkea** (keksitty, pelissä
  totta): Mummo Hilkka kertoo Isonvihan hopeista ja sinisestä liekistä raunion luona. Arto, Anna-Liisa ja Pekka
  epäilevät. Yöllä (22–4) raunion luona liekin takana on ensin Pannu-Sulo kaasupolttimineen, Saloisten Pirtin
  käräjäpöytäkirja kertoo "kivien alle, sammalen sekaan", ja sitten oikea aarnivalkea palaa sammaloituneen kivikasan
  päällä (tai näkyy droonin yökuvassa). Hopeat Pirttiin (loppu "Isonvihan hopeat") tai Veksille (rahaa, poliisi).
  Testi `--scene=honganpalo`.
- **Saloisten kenttä ja kaukalo:** Seuranmäellä jalkapallokenttä viivoineen, maalit verkkoineen, katsomo ja
  valomastot, vieressä jääkiekkokaukalo laitoineen. Pojat pelaavat päivisin (10–20): rankkarit pelataan oikealla
  kentällä oikeaa maalia kohti (myös Honganpalon koulun kentällä), viisi laukausta pelaajan takaa (tähtäin heiluu
  maalin suulla, välilyönti lukitsee suunnan ja korkeuden, hahmo potkaisee ja poikien maalivahti heittäytyy; kulmaan
  vaikea torjua, liian laaja menee ohi) ja viisi torjuntaa maalin suulta (potkija juoksee pilkulle ja lantio
  paljastaa suunnan, A / S / D heittäytyy). Muut pojat katsovat rangaistusalueen reunalla. Kummankin kentän pojat pelaavat kerran päivässä, ja kesken luovutettu (F/Esc) ei ole voitto. Juoksulenkki
  kentän kulmasta kulmaan. Testi `--scene=pohjoiset`.
- **Oravajärven uimaranta:** hiekkaranta, laituri, pukukoppi (uusi kaljajemma penkin alla), rantagrilli, penkki,
  huussi ja rantakyltti. Uinti kuten Salmisessa, ja joka päivä pohjasta voi löytyä jotain (aurinkolasit, vanha
  Nokia, kultasormus Sinikalle 20 €:lla). Aamuisin mummot, iltapäivisin perheet: kalja penkillä perheiden edessä
  maksaa mainetta. Aamuisin (8–10) Sinikka käy uimassa pienissä punaisissa lappubikineissä: hänen näkemisensä piristää kerran
  päivässä (moraali, vireys, stressi), rannalla voi jutella ja antaa sormuksen, mutta jos jäät tuijottamaan mummojen
  nähden, Päivi kuulee siitä aamulla. Testi `--scene=sinikkaranta`.
- **SEO Saloinen ja ravintola A+:** tankkauskatos mittareineen, SEO-pylväs hintoineen ja rekka pihassa. Myymälä
  auki 24/7: kahvi (vireys), munkki reppuun ja rekkakuskin ilmainen kyyti Raaheen (6–23, kun Kapteenin Kulma on perillä auki). A+: lounas ma–pe
  10.30–14 ja tuoppi illalla 16–22; pöydissä rekkamiesten ja vuoromiesten juttuja.
- **Kinnapotin teollisuusalue:** Saloisten katsastus, Arttim metal works ja Rudus siiloineen peltihalleina.
  Katsastusmies tutkii sähköpyörän (teippi, rautalanka, irronneet osat, oikosulku ja tyhjä akku hylkäävät;
  hyväksytty saa leiman ja maineen kerran). Mopon katsastus samoin kerran. Hitsari myy ruuveja ja hitsaa akkutelineen (akku ei enää irtoa). Ruduksen
  portilla keikkatyötä aamuisin: kolme tuntia lapiota, 30 €.
- **Tokolanperän rossirata:** OSM-uran kierros mutkien rengasmerkkeineen, lähtöportti ajanottokylttineen ja kolme
  hyppyriä, joista pyörä lähtee ilmaan. Kierrosaika pyörällä crossipoikien ennätystä (0:22) vastaan; voitto antaa
  nippusiteitä, ruuveja ja mainetta. Crossipojat paikalla viikonloppuisin.
- **Kertunkankaan kehäröykkiöt:** Palonkyläntien pohjoispuolella metsässä Muinaispolun päässä oikea muinaisjäännös:
  kolme keskuskuopallista kehäröykkiötä, röykkiö, kivikkoon kaivetut kuopat, 140 metrin kivivalli ja opastaulu
  "Rautakaudelta Rautaruukille" (tiedot Visit Raahen ja Raahen Seudun mukaan). Röykkiöihin ei kosketa: toinen
  kaivuuyritys tuo poliisin. Penkillä saa juoda kaljan yksin metsässä. **Legenda: Kertunkankaan rauta**
  (keksitty, pelissä totta): kodan Raimo kertoo, että kankaan väki teki rautaa suomalmista ennen Raahea ja viimeinen
  seppä kätki kirveensä. Arto, Anna-Liisa, Pekka ja Reipparin Raija epäilevät. Opastaulun pohjakartan
  merkitsemätön kivi, droonin ilmakuva suorasta kivirivistä, suon ruosteveden suomalmi Tokolan Aarolle ja kuona
  pajakiven juurelta johtavat kirveeseen isokiven alla. Saloisten Pirttiin: museo vahvistaa, lehtijuttu, maine ja
  uusi loppu "Viimeisen sepän kirves", Veikko tarjoaa kaljat ja epäilijät perääntyvät. Kirppiksen takahuoneen
  Veksille: 150 €, mutta legenda jää todistamatta, Raimo naurunalaiseksi ja poliisi perään. Testi
  `--scene=kertunkangas`.
- **Seuraintalon tanssit ja bingo:** päivillä on viikonpäivät (päivä 1 = maanantai, näkyy repun tiedoissa).
  Lauantaisin klo 21–01 tanssit (lippu 8 €): lavalla Saloisten Saapasjalat, viirit ja värivalot, lattialla pareja.
  Tanssiin voi hakea Sinikan (Päivi soittaa hetken päästä perään, ja aamulla on motkotusta), Hilkan tai Anna-Liisan: tanssitaan salin
  lattialla salin omien ihmisten kanssa muiden parien kiertäessä ympärillä ja kameran kiertäessä paria. Saapasjalat
  soittaa oikean biisin ("Pihalla tavataan", "Rasvanappi" tai pelin tunnari "Normipäivä", `scripts/tanssibiisit.gd`), ja nuotit tulevat biisin
  mitatuille iskuille: A ja D vuorotellen (alkusoitossa joka toisella iskulla, säkeistössä joka iskulla, kertosäkeessä
  tuplasteppejä), ja kertosäkeen huutoon (HEI!, HEP! tai NORMIPÄIVÄ!) painetaan välilyöntiä (kipinät ja tärähdys). Tanssi
  kestää alkusoitosta ensimmäisen kertosäkeen loppuun, ja kompastuessa tulee horjahdus ja pari sanoo sanansa; pari tanssii suljetussa otteessa (viejän käsi parin selällä, parin käsi viejän olalla, vapaat kädet kämmen kämmentä vasten, vartalot saavat painautua toisiaan vasten), ja hyvä tanssi nostaa moraalia ja mainetta (kömpelö tanssi Anna-Liisan kanssa leviää
  kylälle). Kahviossa Raili myy kahvia ja munkkia, takaovesta pihalle ukkojen luo takakontille (huikka kossua,
  Anna-Liisa voi nähdä). Tiistaisin klo 18–20 bingo: lappu 2 €, pelaaja istuu bingopöydän päässä mummojen rivissä, ja Erkki
  pyörittää lavalla pallokonetta ja huutaa numerot puhekuplassa. Huudetut numerot
  merkitään omaan lappuun, ja täysi rivi BINGO-napilla voittaa (kahvipaketti, virkkuuliina, lahjakortti tai
  harvoin joulukinkku), jos ehtii ennen mummoja (tarkka merkitsijä noin joka neljäs ilta). Kesken lopetettu bingo tai tanssi ei kuittaa seurailtaa. Väärä bingohuuto nolaa (pöydän väki kääntyy mulkoilemaan) ja vie mainetta. Testi `--scene=seurailta`.
- **Tokola ja kauppiaan aarre:** Tokolantien varressa Tokolan kaupan vanha varasto (kauppa lopetti 1950–60-luvulla;
  varasto on pelin keksintö). Avain on vanhalla Aarolla, joka antaa sen lihapiirakkaa vastaan ja kertoo
  legendan: kauppias ei vienyt rahojaan pankkiin. Varastosta ohjain, rautalankaa ja kauppiaan tilikirja, jonka
  piirros vie narisevan lattialankun alle ja lappu Heinimäen latvattoman kuusen juurelle. Rahalipas näytetään
  Aarolle (legenda todistettu, maine nousee ja epäilijät joutuvat myöntämään) tai tilikirja annetaan Pannu-Sululle
  pulloja vastaan (sen isän nimikirjaimet ovat "sokerin" ostajissa). Markat myydään kirppiksen Railille.
  Heinimäeltä näkyy terästehtaan savut. Testi `--scene=tokola`.
- **Legenda: Sulon isän kadonnut pannu:** Tokolan Aaro tietää, kuka on "S. S." kauppiaan kirjoissa: Pannu-Sulon isä,
  pitäjän paras keittäjä, upotti kuparipannunsa Pilkkarinnevan rämeeseen ratsiayönä 1966. Sulo, Pekka ja Arto
  kiistävät koko jutun. Droonin ilmakuva paljastaa rämeellä kuparin vihreän läikän (merkki karttaan), ja pannu
  kahlataan ja kaivetaan esiin. Valinta: pannu Sululle (keittää isän reseptillä, kanisteri vastaa 32 kaljaa),
  Saloisten Pirtin kotiseutumuseoon (maine, lehtijuttu, mutta Sulo nostaa kanisterin hintaa) tai Taunolle romuksi
  (20 €, Sulo ja Aaro suuttuvat). Löydön jälkeen Sulo myöntää: "No... isä keitti. Ja hyvää keitti."
  Testi `--scene=pannu`.
- **Mökki:** mökille pääsee naapurin Pekan kyydillä (taksia ei ole: se oli aiemmin oikotie, ja nyt Volvo pitää tarvittaessa korjauttaa Korpelalla): Pekka on menossa Neittävälle kyyhkyjahtiin ja ottaa
  kyytiin kaljalla tai 10 eurolla (jalan E Pekan luona). Pekan auto odottaa mökin pihatien päässä, ja sillä
  pääsee kotipihaan ilmaiseksi (bensat maksettiin menomatkalla). Välikuvassa Pekan vihreä Volvo kaahaa kesäistä maantietä peltojen, säilörehupaalien ja männikön
  halki, Pekka puhuu kyyhkyistä ratissa ja auto töräyttää Neittävän (kotimatkalla Saloisten) kyltin ohi. Mökki on Vaalan Neittävän kylällä,
  noin 106 km linnuntietä itään Järvikujalta, ja välimatkat (esim. pyörään) näytetään sen mukaan. Mökillä
  pääpelin tehtävät eivät etene eivätkä näy HUD:ssa: aika seisoo, Päivi ja muut vaarat jäävät Saloisiin, eikä
  pyörää varasteta sillä aikaa. Mökki on mallinnettu oikean paikan mukaan (Kaisuantie 62, Neittävä, Vaala): 1,9 × 1,9 km
  maisema OpenStreetMapista (Likanen, Syväjärvi, Ahveroinen, Tervalampi, Kiiskeroinen, Penikka ja muut lammet
  omilla pinnoillaan, Kaisuantie, Uutelanperäntie, Neittäväntie ja muut tiet, pellot, suo, purot ja noin sata
  naapurirakennusta) ja korkeudet koko alueelta Maanmittauslaitoksen 2 m korkeusmallista (kauempana 8 m ruudukkona,
  `tools/kartta/mokki.ps1`; mökki on harjanteella ja piha viettää n. 7 m rantaan). Kävelyalue on 800 × 800 m, ja
  maisema jatkuu horisonttiin. Data päivitetään komennolla `tools/kartta/mokki.ps1` tai `tools/kartta/mokki.py` (ks. `tools/kartta/LUEMINUT.md`). Metsä on oikea: noin 128 000 puuta
  Maanmittauslaitoksen laserkeilauksesta (paikka, pituus ja latvuksen leveys) ja Luken VMI:n puulajeista, ja
  naapuritalojen korkeudet on mitattu laserista (`tools/kartta/mokki_puut.py`). Mökki on tummanruskeine
  pystylautaseinineen metsän keskellä. Piha Airbnb-kuvien ja drone-kuvan mukaan: kuisti järvelle, rannan puolella
  savusauna, puulämmitteinen palju ja kesäkeittiö (avoin katos offset-savustimineen), tikanheittotaulu, laituri
  portaineen ja soutuveneineen sekä isäntä Santtu kahvikuppeineen.
  - **Kalastus soutuveneellä:** laiturilla E vie veneeseen. W/S soutaa ja A/D kääntää. Kalaparvet näkyvät renkaina
    pinnalla. Pidä E heittääksesi virvelin (pidempi painallus heittää kauemmas), ja kun koho sukeltaa, paina E heti.
    Väsytyksessä E kelaa: pidä siiman kireys vihreällä, koska punaisella siima katkeaa ja löysällä kala karkaa.
    Parvien luona ja kauempana rannasta tulee isompia kaloja (hauki rimpuilee rajuimmin). Humala tärisyttää kättä.
    F soutaa takaisin laiturille. Saalis viedään savustimeen.
  - **Pajatso ja hedelmäpeli Siitarissa:** pajatso RAY:n 50 pennin pajatson (1966) mukaan: tiikkikehyksinen kaappi,
    RAY:n apilakyltti, lasin takana tummanpunainen lauta, harmaa rakonauha, suppilo, porttien kolikkoputket (näkyvä
    varanto), tähtipyörät, voittokouru kahvoineen ja TILT-valo; kyljen laukaisin ja maksuvipu työntyvät reunan yli.
    Pelataan euron kolikoilla: taskussa on yleensä yksi, oikean kehyksen vaihtokone (D) vaihtaa kahden euron kolikon
    kahdeksi euroksi kahvaa vääntämällä (kolikot kuppiin), ja voittokourun kolikot käyvät suoraan peliin. Euro syötetään
    (E) yläkehyksen kiinnikkeen rakoon, josta se putoaa oikean reunan kanavaa alas laukaisupesään pystyyn rakonauhan
    tasolle. Laukaisin ei ole jousiase: sitä ei viritetä, vaan sormi napsauttaa liipaisimen suoraan sisään ja jousi vain
    palauttaa sen. Liipaisin on kyljen lenkki, jota painetaan sisään kohti konetta. E pohjassa kerää sormeen voimaa (mitä pidempään, sitä kovempi isku), irrotus napsauttaa.
    Lyöntitekniikat: pintalyönti (kevyt neppaus; liian heikko putoaa viereiseen R-rakoon ja antaa uusinnan),
    peukalotuki (välilyönti: peukalo kehyksen reunaan, ei tärinää, voima kertyy hitaammin), voimalyönti (kova isku
    laidan portteihin) ja snaiffaus (S: saatto jarruttaa iskua). Lennon aikana
    K tönäisee konetta: jousi vaimenee hetkeksi, mutta tilt vie kolikon, ja kolmannesta tiltistä isäntä heittää ulos.
    Kolikko lähtee aina vasemmalle ja hieman ylös ja putoaa rakojen yli yhdeksälle raolle: R (panos takaisin), 2, 3, 3,
    14, 3, 3, 2, R euroa (oikean koneen 1:00, 1:50 ja 7:00). Raon portissa on kaksi jousitappia, joiden säädettävä
    jäykkyys vaihtelee portittain (seiskassa jäykin, vasemmassa laidassa löysät): hiljainen ja vino osuma kuoleutuu
    jouseen ja kolikko putoaa porttiin, kova kimpoaa; kiinteät ohjaustapit estävät suorat reitit keskelle. Jokaisella
    portilla on oma kolikkoputki: rakoon mennyt kolikko pinoutuu siihen ja vapauttaa putken lukituksen, ja maksuvipu
    (W) liikuttaa luistilevyä, joka pyyhkäisee voiton juuri siitä putkesta kouruun; tyhjästä putkesta kone maksaa
    tyhjää. Ohi mennyt kolikko valuu suppilon jakotapilta vajaimpaan putkeen (täysi valuu kassaan). Siimahuijaus (Q)
    kerran päivässä, jos repussa on virveli tai onki: rakoon mennyt siimakolikko nykäistään uudestaan läpi, kunnes
    siimaleikkuri katkaisee siiman tai isäntä näkee ja heittää ulos (maine −6). Kone skaalautuu pienempään ikkunaan.
    Palautus (simuloitu): satunnainen lyönti noin 60 %, tähtäys ilman tukea noin 80–90 %, peukalotuella noin 95 %,
    voimalyönti vähemmän (`--scene=pajatso`).
    Hedelmäpelillä pelaa kaksi seurueen jäsentä; vuoron saa kysymällä. Kolme rullaa, voittotaulukko, lukitus
    häviön jälkeen (1 2 3) ja tuplaus pieni/suuri (`--scene=siitaripelit`).
  - **Lauantai Siitarissa:** pajatsolla pelaa kaksi Raahen jätkää, jotka eivät anna pelivuoroa ja haastavat riitaa.
    Valikosta pihalle tai antaa olla; pihalla Street Fighter -tappelu hotelli-ravintolan edessä mopojen ja
    katsojien keskellä. Voittajalle baarimikko tarjoaa kaljan ja jätkät häipyvät, häviäjältä ne vievät vitosen
    (`--scene=mokkisiitaritappelu`). Rannekellossa näkyy viikonpäivä (MA–SU), perjantaisin juhannuskokon merkki.
  - **Jukeboksi Siitarissa:** biisi 50 senttiä: iskelmät (vanhat 78-levyt), Saloisten Saapasjalat (Pihalla tavataan,
    Rasvanappi ja Normipäivä) ja ysärit (kuulokkeiden soittolista).
    Lauantaina iskelmä suututtaa Raahen jätkät, ja ysäri suututtaa aina hedelmäpelin miehen: riita pihalle Street
    Fighter -tappeluna (kerran päivässä) tai biisi pois. Häviäjä maksaa vitosen, voittajalle talo tarjoaa kaljan
    (`--scene=siitarijukeboksi`).
  - **Mopolla Vaalaan:** mökin pihan mopolla (huippunopeus 60 km/h) ajetaan Hotelli-Ravintola Siitariin
    (Uutelanperäntien sora Neittäväntielle, Vuolijoentie radan ali, Oulujoen silta, Vaalan keskusta 1:1: kirkko,
    rautatieasema, kaupat ja kunnantalo). Mopo pysyy teillä: metsään, pellolle ja pihoille ei köröttele, vaan tien
    reunassa mopo liukuu kuin reunakiveä vasten (sivutiet, parkit, tori ja ovien edustat ovat ajettavia; lavan aidan sisäpuoli on kävelyaluetta).
    Radan alikulku on ohikulkuvideon mukainen betonisilta pilaripareineen, ja penger laskee luiskana sillan alle.
    Rata ylittää Oulujoen tiesillan tasossa teräksisellä ristikkosillalla, ja radalla kulkee silloin tällöin juna
    (punavalkoinen Sr1-veturi ja neljä sinistä VR:n vaunua, yksi niistä ravintolavaunu), joka vihellyttää ohittaessaan.
    Radalla ei kannata seisoa: liikkuva juna tappaa (Vaalassa ja Saloisissa), ja Päivi motkottaa: "Minun piti parsia
    sinut kokoon palasista!" Seisovan junan läpi ei kävellä eikä ajeta.
    Vaalassa kuollessa herätään lähemmästä paikasta, Gasthausista tai Paapelista, ja aamulla Päivi soittaa: Santtu
    vastaa kännykkään pää painuksissa ("Kyllä kulta..."). Saloisissa kuollessa herätään aina kotona, ja Päivi motkottaa
    pihalla (`--scene=vaala_ajo --ajo=kuolema --kohta=gasthaus|mokki` ja `--ajo=kuolema_saloinen`).
    Testi `--scene=vaala_ajo` (ilman ikkunaa `--headless`): autopilotti ajaa mopolla 60 km/h jokaisen Vaalan tien
    (n. 190 tietä, 21 km) ja jokaiseen kohteeseen ja kirjaa jumit ja törmäykset (`--ajo=tiet|kohteet|juna|lava`).
  - **Junalla Saloisten ja Vaalan välillä (10 € suuntaansa):** Vaalassa Vaalantien päästä torin kulmasta
    suoraa asfalttia (Aseman piha) Siitarin ja Zabukin pohjoispuolelta rautatieasemalle (pelissä tuotu radan varteen
    noin 100 m Siitarista, laituri radan vieressä; todellisuudessa n. 300 m kauempana; junat eivät aja Oulujoen
    ratasillalle, vaan Vaalan pään reitti alkaa sillan itäpuolelta); Saloisissa
    asema on K-Marketin takana, ja rata jatkuu asemalta länteen Valtatien yli ja idässä kaartaa heti pohjoiseen
    talojen välistä ja koilliseen horisonttiin, ei kylän läpi (tiet tasoristeyksinä). Molemmat asemat ovat samaa
    vanhaa VR:n puuasematyyppiä (`station_build.gd`): keltainen pystylautaverhous valkoisin listoin, ristikkoikkunat,
    punainen saumattu peltikatto kolmella tiilipiipulla ja kattolyhdyillä, kadun puolella sisäänkäyntikatos
    portaineen ja laiturin puolella pitkä katos, kello ja penkki. Kadun puoleisesta ovesta (E) mennään
    **odotussaliin** (`station_interior.gd`): ruutulattia, puupenkit, suljettu lippuluukku, lähtevien junien taulu,
    kaakeliuuni, kahviautomaatti ja välkkyvä loisteputki. Penkeillä ja nurkissa notkuvat juopot Rane ja Make sekä
    narkkarit Nisse ja Jonna, jotka pyytävät viinahörppyä (kalja, Koskenkorva tai pontikka esinevalikosta).
    Ensimmäisestä hörpystä kerrotaan narkkarin rahakätkön paikka: merkki ("Kätkö 100 €") paperikarttaan ja
    minikarttaan, ja radan varressa n. 150 m asemalta vanhojen ratapölkkyjen pinon alla on muovikassissa satanen
    (E jalan; kummallakin asemalla oma kätkö, kerran pelissä). **Junaan noustaan laiturilta**, ei aseman ovelta:
    odotussalin laiturin puoleisesta ovesta tai aseman ympäri laiturille. Juna tulee kummallekin
    asemalle satunnaisesti n. tunnin välein pelin kellossa ja seisoo laiturilla puoli minuuttia: vain silloin
    pääsee kyytiin (E laiturilla). Muuten E = odota junaa, kello hyppää ja juna saapuu (testi `--scene=asema`). Matkalla juna ohittaa Saloisten
    päässä savuavan Raahen terästehtaan ja ylittää Vaalan päässä Oulujoen ristikkosillan. Välikuvassa istutaan
    ravintolavaunussa tuopin kanssa, naisille tarjotaan Koskenkorvat (16 €, jos rahat riittävät) ja paukun
    jälkeen vieressä istuva Helena laskee kätensä polven päälle ja liu'uttaa sen reittä pitkin sisäreidelle; taustalla soi hidas soul-lirkuttelu
    (`tools/lirkuttelu.py` syntetisoi biisin `assets/music/lirkuttelu.wav`). Junasta noustaan laiturille; Vaalaan tultaessa mopo odottaa
    aseman edessä, ja Vaalasta
    lähdettäessä se palaa mökin pihaan kuten muillakin paluureiteillä.
  - **Minikartta** näkyy myös Vaalan matkalla (mopolla ja jalan) ja mökillä koko kävelyalueella Salmisille asti.
    Salmisen uimarannalle, Ranta-Rosvolle ja Keskimmäisen laavulle (tynnyrisauna) vie soratie. Tynnyrisaunan löylyt
    ovat välianimaatio: kaarevat paneelit ja pieni kiuas, ja Santtu tulee kylmien kaljojen kanssa viereen lauteelle
    (testi `--scene=mokkitynnyri`). Salmisessa uidaan ja sukellellaan välianimaationa: kahlaus hiekkarannalta,
    rintauintia, sukellus hiekkapohjalle ahvenparven ja kaislojen sekaan ja pinnalle polskimaan (`--scene=mokkiuinti`).
    Laavun nuotiolla paistetaan makkara välianimaationa (makkara mukana), ja laiturilta lähdetään kalaan. Samat
    toimivat mopomatkalla Vaalan maailman järviseudulla E:llä (tynnyrisauna, laavu, laituri, Salmisen ranta ja
    viskikätkö; mopon selästä aloitettaessa hahmo nousee mopolta ja jatkaa jalan, testi `--scene=mokkijarvi_e`).
    Ranta-Rosvon jalustan takana on viskikätkö (viinakätköjen seitsemäs, avataan kuten muutkin). Mopomaailmassa
    järviseutu on tiivistetty puoleen Neittäväntien haaran pään ympäri (`tools/vaala_jarviseutu.py 0.5`, ilman
    lähdeaineiston välimuistia; leivonnan NL_C ja NL_S vastaavat sitä), joten Rosvolle, Salmiselle ja laavulle on
    lyhyt ajomatka. Järviin ja rannan matalikolle ei ajeta mopolla, ja uimaan lähtiessä mopo jää kuivalle
    (`--scene=mokkiuinti_mopo`). Vaalan asfalttisivukaduilla ajetaan täyttä 60 km/h, soratiellä pientareen vauhtia. Mopo kaatuu kännissä myös sivuteillä
    (asema, järviseutu): se nostetaan ajetulle tielle muutama metri taaemmas (`--scene=mokkikaatuminen`). Ranta-Rosvo ja
    Salmisen uimaranta (Taka-Salmisen länsiranta) ovat asfaltoidun Nuojuankoskentien varrella. Mopolla: risteyksessä,
    jossa Siitariin käännytään oikealle, vasemmalle kääntyvä asfaltti vie Rosvolle ja rannalle, ja samasta
    risteyksestä asfaltin yli suoraan lähtevä soratie Keskimmäisen laavun ja tynnyrisaunan pihaan (testi
    `--scene=mokkimopo_jarviseutu`). Maasto on Maanmittauslaitoksen 2 m korkeusmallista, pellot, suot, vedet
    ja rakennusten pohjat maastotietokannasta, rakennusten korkeudet ja tienvarren metsä (noin 200 000 puuta)
    laserkeilauksesta ja puulajit Luken VMI:stä (`tools/vaala_bake.py`). Keskustassa on K-Market Tervaportti:
    sama kauppa kuin kylässä, ja vasemmalla seinällä Alkon hylly (Koskenkorva kätköviinaksi, T ottaa huikan).
    Pelissä kauppa on Siitarin vieressä Vaalantien varressa (todellisuudessa n. 400 m kauempana), ja
    pankkiautomaatti on kaupan seinällä. Jos rahat eivät riitä, kaljat ja Alkon pullot voi viedä ovesta
    juoksukaljoina maksamatta (kylän K-Marketissa samoin). Mopotie päättyy torille Siitarin viereen: torin päädyssä
    on Zabuki (olut ja hampurilaiset) ja Siitaria vastapäätä Gasthaus. Gasthausin emännältä saa myös Kainuun ruokaa (kalakeitto 9,50 €, kukkoleipä 7 €, talkkuna 4 €, rieska 3,50 €; ruokalistakyltti HUONEET-kyltin alla), ja annos nollaa nälän. Zabukin pohjoispuolelta Vaalantie kääntyy asemalle. `tools/vaala_keskusta.py` siirtää kaupan ja poistaa
    laserpuut rakennusten, parkkien ja teiden päältä (latvusmallissa katotkin näkyivät puina). Niemellä, jossa Oulujoki alkaa Oulujärvestä (Vuolijoentieltä oikealle
    asfaltoitua Pahalahdentietä juuri ennen radan alikulkua; `tools/vaala_lava.py` tekee niemen, leveän joen ja
    järven 1:1 korkeusmallista), on Oulujärven lava 90-luvun asussaan (punamullatut seinät, luukut auki, bändi
    lavalla) aivan rannassa niemen kärjessä lautatarha-aidan sisällä, jonka päät ulottuvat jokeen ja Pahalahteen:
    lippu (12 €) ostetaan aidan portilta, jossa portsari leimaa käden ja portti aukeaa koko päiväksi; lavatansseihin (klo 20–01), joissa A ja D vuorotellen tahdissa vievät parin tanssiin. Kappaleen jälkeen palataan saliin:
    voi tanssia uudestaan, mennä diskopuolelle tai baaritiskille tuopille, ja Q vie lavalta ulos. Lavalla soittaa
    Humppaveikot (`humppa_band.gd`): laulaja, harmonikka palkeineen, kitara, basso ja rummut, kädet soittimilla
    tahdin mukaan. Bändi soittaa vanhoja iskelmiä ja lavamusiikkia 78 kierroksen levyiltä (`iskelmat.gd`, sama
    lista kuin Päivin kännykässä) sekä Saloisten Saapasjalkojen "Pihalla tavataan" ja "Rasvanappi", ja W:llä bändiltä voi toivoa kappaleen ("Säkkijärven polkka", "Orpopojan
    valssi"...). Tanssin tahti seuraa kappaleen tempoa, ja kappaleen loputtua bändi soittaa seuraavan. Jos
    äänitteitä ei ole, kappaleet syntetisoidaan (`humppa_synth.gd`). S:llä DJ:ltä voi toivoa diskobiisin pelin
    90-luvun biiseistä: se alkaa heti, ja diskopuolelta haetaan pari (testi `--scene=lavatoiveet`). Tanssien
    aikaan humppa kuuluu pihalle, salissa tanssitaan ja seinien penkeillä istutaan, ja pihalla on grillikioski
    jonoineen ja tupakkapaikka. Lavan ympärillä kasvaa koivikkoa ja katajaa paljaan niityn sijaan. Pelissä lava on
    todellista (1 500 m²) vähän pienempi. Oulujärvi jatkuu niemeltä kaakkoon kartan reunaan asti. Oulujoen suun itärannalla on Vaalan satama (todellinen Venesatama, Sahanranta): pitkä pääsiltalaituri T-päällä ja sormilaituri,
    rantakivetys, sorapihan parkki (Sahanrannantie-sorapätkä) ja kyltti "VAALAN SATAMA". Laiturilla on punavalkoinen muskelivene ja
    kaksi soutuvenettä. Pelin ranta poikkeaa todellisesta, joten satama on haettu pelin rantaviivasta lähimpään sopivaan
    kohtaan lähemmäs asemaa: asemalta se on pelissä etelässä n. 470 m (oikeasti n. 700 m; `tools/vaala_satama.py`,
    hakukeskus `vaala_sahanranta.py`:ssä). Asema on siirretty 80 m radan suuntaan itään (todellisuudessa se on lännempänä), jotta Satamantie
    lähtee Aseman pihan taitteesta suoraan etelään tasoristeyksen yli aseman editse eikä kierrä aseman takaa; Veturitalli, Veturitallintie,
    Kätkötie ja narkkarin kätkö (`asema.katko`) siirtyivät mukana, ja aseman lähitalot lähimpään vapaaseen paikkaan.
    **Sahanrannan täyte:** Satamantien, Sahanrannantien ja Uitontien varrella on pientaloja, aittoja ja rantamökkejä oikean Sahanrannan
    mitoin sekä puita ja lehtoja pihoilla ja rannoilla (`tools/vaala_sahanranta.py`, ajetaan kerran `vaala_suorat.py`:n jälkeen).
    **Taksihinnat (kaikki retket ja Raahen baari):** meno-paluun hinta ja kesto lasketaan lähtöpaikasta kaikkialla samalla tavalla: matka km x 1,05 min
    (pyöristys 5 min, vähintään 10 min) ja 0,40 €/min (`retket.gd tarjous`, `raahe_tarjous`; Saloisten ja Vaalan väli 150 min / 60 € on mittapuu).
    Saloisten tolpalta esim. Raahen kohteet 4 € / 10 min, Teeriniemi 6 €, Hanhikivi 14 €, Kalajoki 28 €, Pyhäkoski 42 €, Kajaani 84 €, Hiidenportti
    102 €, Kuhmo 118 €, Raate 126 € (295-315 min suuntaansa, yöllä sammuu perillä); Vaalasta ks. alla. Matkaopas näyttää molemmat lähtöpaikat.
    **Vaalan K-Markettiin** (`vaala.gd _build_kmarket_yard`) on tehty merkitty parkkipaikka autoineen, kaupan penkin mummot ja rollaattorimummo
    kuten Saloisissa (suuttuvat mopon ohituksesta yli 5 m/s, kettukarkit horjauttavat mopoa, jalan karkit voi poimia, keppi päähän on kuolema;
    kuolinviesti "Rollaattorimummo huitaisi kepillä päähän Vaalan K-Marketin pihalla") sekä taksitolppa (E): samat valinnat kuin Saloisissa
    (kaikki retket, taksikuskin legendat, matkaopas; ei Raahen baaria eikä kyytiä Saloisiin, ja Saloisten tolpalta ei kyytiä Paapeliin), mutta **hinta ja kesto lähtöpaikan mukaan**: Vaalasta Raahen seudulle
    150 min ja 60 € (kuten kotimatka Saloisiin), Manamansaloon 10 €, Pyhäkoskelle 18 €, Kajaaniin 32 €, Kalajoelle 88 € (matka km Vaalasta
    x 1,05 min ja 0,40 €/min; `retket.gd tarjous`). Retkeltä palataan samaan tolpalle jalan. Testi `--scene=kmarket_vaala`.
    Vaalantie kääntyy siistillä ympyränkaarella (säde 18 m) Siitarin ja Zabukin pohjoispuolelta suoraan asemalle (Aseman piha); reitin U-mutka
    Zabukin pihan läpi ja liittymä torille on poistettu (`tools/vaala_asematie.py`, ajetaan kerran `vaala_risteys.py`:n jälkeen). Tori on
    laajennettu Aseman pihan pohjoispuolelle Zabukin eteen (kojut vähintään 4,5 m reunasta, tori 9 m tien keskiviivasta). Siitarin eteen, terassin ja Vaalantien väliin,
    on tehty parkkipaikka ruutuviivoin, P-kyltein ja asiakkaiden autoin (`vaala.gd _siitari_lot`).
    **Tienpinta kaikkialla kuten Saloisissa** (`vaala.gd _ribbon`, `_conform`): asfaltti on kaksikaistainen 8 m tie (kuten Saloisten maantie) maastoon sovitettuna nauhana
    (mutkissa kiekot, kolmiot leikattu maastoruudukon viivoilla, ei kiiloja eikä maata läpi) harmaine pientareineen (1,2 m) ja valkoisine
    katkoviivoineen (3 m / 6 m); päätiellä (leveys 7,2 m) sillat jäävät kannen korkeudelle. **Sora** on kaikkialla Keskimmäisentien ja Paapelin
    soratien mallia (2,6 m, hiekan värit): Satamantie, Sahanrannantie, Pahalahdentie (lavan tie), Salmisentie, mökin päätie ja järviseudun tiet.
    Parkit samoin. Sivutiet, järviseudun tiet ja parkit käyttävät samaa (`_side_style`, `_surf_mat`); mopon ajoalue lasketaan samasta tyylistä. Siitarin ja K-Marketin pihoilla on vain muutama auto (`LOT_MAX_CARS`). Salmisten (Etu- ja Taka-Salminen, Pyöriäinen) rannoille
    kasvaa lisää koivuja, mäntyjä, kuusia ja pensaita teiden ulkopuolelle (`vaala.gd _build_salminen_trees`).
    **Salmisentie:** laavun ja tynnyrisaunan pihan takaa Taka-Salmisen pohjoisrantaa (11-14 m rannasta, tasaista metsää) Nuojuankoskentien
    päähän uimarannan kohdalle, yhdessä Keskimmäisentien kanssa kierros Salmisen ympäri. Soratie kuten Keskimmäisentie (soralla mopo ajaa
    pelin säännöin 85 %:n huippuvauhtia); testi `--scene=vaala_ajo --ajo=tiet --kohdat=-250,-445` (245 m, ei törmäyksiä).
    **Lavan parkki:** Pahalahdentie (sora) päättyy soralle parkkipaikalle lavan aidan ulkopuolella portin edessä (muutama auto, P-kyltti;
    `vaala.gd _build_lava_lot`, data `lava.lot`). Autoja ja mopoja ei päästetä portista: aidan sisäpuoli (piha ja lavan ovi) on
    kävelyaluetta eikä kuulu mopon ajoalueeseen; mopo jää parkkiin (`lava_park`) ja pelaaja kävelee portille lippua ostamaan. Testi
    `--scene=vaala_ajo --ajo=portti` ajaa mopolla täysillä porttia, aitaa ja viistoon kohti: mopon pitää pysähtyä aidan ulkopuolelle.
    **Uiton sauna (Sahanranta, Uitontie):** Satamantien varrella haarautuu Uitontie rantaan, jossa on Oulujoen uiton jäljiltä hirsisauna
    (lämpimänä, savu piipusta), makasiini (nykyään kanoottitalli, kajakkeja telineessä), tukkipino, nuotiopaikka ja laituri
    uimatikkaineen, pelastusrenkaineen ja soutuveneineen (`vaala.gd _build_uitto`). E saunan ovella: löylyt välianimaationa, ja Santtu tulee
    kylmien kaljojen kanssa kuten savusaunassa (stressi, väsymys ja kipu kerran päivässä, moraali). E laiturilla: uinti Oulujärveen
    Salmisen uintianimaatiolla (kahlaus, uinti, sukellus; saunan jälkeen vilvoittelu antaa lisää). Todellinen paikka: Oulujärven
    Melontakeskus Sahanrannassa Uitontien päässä (1930-luvun uiton maja, sauna ja makasiinit, entisestä uiton venevajasta tehty kanoottitalli;
    tarkemmat rakennuskuvat puuttuvat, joten mallit ovat tulkintoja). Testi `--scene=sahanranta`.
    Satama näkyy paperikartalla ankkurina ja minikartalla V-merkkinä. Satamaan vie Satamantie (soratie kuten Paapelin soratiet, haarautuu Aseman pihasta 840, -818 ja menee tasoristeyksellä radan yli) ja Sahanrannantie (sora). Vaalan tiet ovat suoria ja vievät kohteisiin: pääreitti, Neittäväntie (järviseudulle), Vaalantie ja Aseman piha, Veturitallintie, Satamantie, Sahanrannantie ja Pahalahdentie (lavalle). Muut OSM-tiet, jalkakäytävät, pyörätiet ja umpikujat on poistettu (`tools/vaala_suorat.py`; testi `--scene=vaala_ajo --ajo=yhteys` tarkistaa, että kaikki tiet ovat ajettavissa mökiltä).
    **Muskelivene:** E laiturin juuressa ("Muskeliveneellä Oulujärvelle") ajaa veneen vesille: W/S kaasu (huippu n. 60 km/h,
    selvästi soutuvenettä nopeampi), A/D ohjaus, moottoriääni, keulan nousu, vanavesi, roiskeet ja kallistus käännöksessä.
    Vene pysyy vedessä (ei läpi rannasta, laitureista tai lavan aidasta) ja pysähtyy kartan reunalle kaakossa. Mopo jää
    parkkiin, tilat ja kello kulkevat kuten muuten, humala heiluttaa ohjausta. E laiturin vieressä hiljaa palaa laiturin
    kärkeen (ensimmäisellä kerralla kokemus, kerran päivässä stressi -0,1). Testi `--scene=satama`. **Lavalle veneellä:** myös Oulujärven lavan pihan järvenpuoleisella rannalla on laituri ja muskelivene (ovi "lavalaituri", E). Ajon voi päättää kumpaan tahansa laituriin (E laiturin vieressä); lavan laituriin noustaessa ei ole leimaa, joten tulija on pummilla ja portsari vahtii (`--scene=vaala_ajo --ajo=venelava` tarkistaa veneen reitin).
  - **Juhannus ja Kesäillan valssi:** juhannusaattona (perjantai) lavan niemen rannassa aidan ulkopuolella palaa
    juhannuskokko klo 21–03 juhlaväen keskellä (E: moraali ja mielihyvä). Lavalla soittaa isompi Vaalan Tähtiorkesteri
    (valkoiset takit, trumpetti ja taustalaulajat), koivunoksat koristavat lavaa, ja tanssilattia on tupaten täynnä.
    TV-ryhmä kuvaa Kesäillan valssia tanssilattian laidalla (kamera jalustalla, äänimies ja valot). Jos humppa onnistuu
    (vähintään 50 %), se menee suorana lähetykseen, ja lavalta lähtiessä välikuvassa Päivi katsoo Kesäillan valssia
    kotona sohvalla: ruudulla on TV-kameran kuva pelaajan tanssista, ja Päivi tunnistaa miehensä ja kiroilee
    ("Mitä PERKELETTÄ?! Mun mies! Telkkarissa!"). Maine nousee, ja aamulla lapussa on motkotusta (`--scene=mokkijuhannus`).
  - **90-luvun nuorison hupihommat:** rahaton pääsee lavan pihalle **pummilla** kahlaamalla aidan järvenpuoleisen
    pään ympäri (mopo jää rantaan). Ympäri voi myös kävellä itse: aidan vesipään ympärillä saa kahlata vyötäröä
    myöten (`--scene=mokkikahlaus`). Leimaa ei silloin ole, ja **portsari** kiertää pihaa portilta lavan ovelle
    näkökenttä maassa kuten Saloisten K-Marketin Anna-Liisa: liian pitkä katse ja portsari taluttaa niskasta portista
    ulos (maine laskee). Lavan sisällä portsari ei näe, ja pihalta pois kävellyt pummi voi ostaa lipun tai kahlata uudestaan. Lavan pihalla parkkipaikan laidalla **teinit** ryyppäävät mopojensa vieressä (huikat ja
    jutut kuten aidan takana). **Aidan takana metsässä** porukka ryyppää nuotiolla kuusikossa, mopot puiden välissä ja kasettisoitin soimassa:
    huikka kiertävästä kossu-vissypullosta (kolme päivässä), kalja porukalle (maine nousee ja saa vinkin
    pummireitistä ja portsarin tavoista, jolloin portsari huomaa hitaammin) ja jutut lamasta, EU:sta, Dingosta ja mopojen virityksistä
    (`--scene=mokkinuoret`). **Mopojen kiihdytys:** Zabukin pihan mopopojat haastavat 150 metrin kiihdytykseen
    Vaalantien suoralla (Tunturi-Jani 5 € tai viritetyllä mopolla ajava Pakoputki-Pete 20 €): kolme punaista ja
    vihreä, W kaasu (ennen vihreää = vilppilähtö), välilyönti vaihtaa ylös kierrosmittarin vihreällä alueella
    (aikaisin moottori tukehtuu, rajoittimella aika valuu, kännissä vihreä alue heiluu). Voitto tuplaa panoksen
    ja nostaa mainetta (`--scene=mokkikiihdytys`).
  - **Karaoke (Frets on Fire -näppäily):** Siitarin ja Kapteenin Kellarin karaokessa kappale valitaan ennen laulua (W/S ja E,
    tai hiirellä). Pelitapa on kuin Frets on Firessa: neljä nuottiraitaa (A S K L tai nuolinäppäimet) laskeutuvat perspektiivikaistaa
    osumalinjalle, ja nuotti painetaan tahtiin (täydellinen ±0,08 s, hyvä ±0,15 s, ok ±0,25 s). Pitkät nuotit pidetään pohjassa
    loppuun asti (bonus). Putki kasvattaa kerrointa (×1–×4), huti, väärä näppäys tai liian aikainen irrotus katkaisee sen, ja
    vasemmalla näkyy yleisömittari. Sanat ovat alhaalla, laulettava sana tai tavu hakasulkeissa. Kännissä nuotit nykivät ja
    painallukset viivästyvät. Tulos = osumien laatu ja pitojen bonus / täydet pisteet. Kappaleet: paikan oma ("Mopolla Vaalaan",
    "Ruukin valot": sävelkorkeus määrää raidan, melodia syntetisoidaan ja osuma laulaa nuotin) tai **Normipäivä Saloisissa
    (lyhennetty aito versio)**: tunnari oikealla soittoraidalla (`assets/music/normipaiva_lyhyt.mp3`, laulu erotettu, n. 56 s:
    ensimmäinen verso ja kertosäe sekä loppukertosäe, ristiinhäivytetty) ja trailerin karaokeen ajoitetuilla sanoilla
    (`assets/music/normipaiva_sanat_lyhyt.json`, 58 sanaa; raita arvotaan sanasta). Esc lopettaa. Testi `--scene=karaokeaito`
    (botti pelaa molemmat kappaleet, kuvat; ei `--headless`).
  - **Räkäleima (pummin leima teinin kädestä):** lavan pihalla juovilta teineiltä (E, "Kopioi tuore leima teinin kädestä", kerran
    päivässä) voi kopioida portsarin tuoreen leiman omaan käteensä (`rakaleima_game.gd`, hiirellä). Käsi viedään leiman
    päälle ja vasen nappi painaa: muste kuivuu 16 sekunnissa ja tarttuu sitä paremmin, mitä tuoreempaa se on, ja R kostuttaa
    kämmenen ("räkä"), jolloin muste irtoaa paremmin. Teini vilkaisee välillä (kysymysmerkki varoittaa ennen vilkaisua):
    painaminen hänen katsoessaan nostaa epäilyä, ja täyteen mittariin yltänyt jää kiinni (maine −1, ei toista yritystä
    päivässä). Leimassa on vain päivän nelinumeroinen koodi (esim. 1226), joka muuttuu päivittäin: ei kehystä eikä muuta tekstiä. **Kopio tulee peilikuvana**, koska kasvot vastakkain painettu kuva kääntyy: tulosruudussa alkuperäinen ja
    kopio rinnakkain. Välilyönti painaa käden toiseen käteen kun ajoitusmerkki on vihreällä: kuva kääntyy oikein päin mutta
    haalistuu. Oikein päin oleva tarpeeksi tumma kopio kelpaa aidosta leimasta (portti aukeaa kuin lipulla). Muuten kädessä
    on peilikuva- tai haaleakopio, joka vähentää portsarin epäilyn kertymistä vain vähän (portsari sanoo huomanneensa
    väärinpäin olevan leiman). Testi `--scene=mokkirakaleima` (kuvat joka vaiheesta, ei kuvia `--headless`-ajossa).
  - **Poliisin moporatsia:** mopomatkalla poliisi pitää välillä ratsiaa tien varressa (iltaisin useammin):
    vilkkuva poliisiauto, viittova Ratsupoliisi Roivainen ja toinen konstaapeli tarkastamassa mopopojan porattua
    Tunturia ("Omalla kylällä saa ajaa kännissä, mutta varo Ratsupoliisi Roivaista"). Pelaajakin viitotaan sivuun: pysähdy auton eteen, niin edessä on puhalluskoe ja mopon tarkastus. Alle 0,5 ‰ = matka
    jatkuu (joskus rikesakko mopon viasta), 0,5–1,2 ‰ = rattijuopumus (sakko 120 €, avaimet tunniksi pois),
    yli 1,2 ‰ = törkeä rattijuopumus (sakko 250 €). Ratsian
    ohittaminen pysähtymättä = sakko postissa ja maine laskee (`--scene=mokkiratsia`). Taustat: Oulujärven lava (Yle, Kaleva, Wikipedia) ja Oulujoen
    voimalaitoskylien muistelmat (ponkkarit, kioskit, tanssipaikkojen portailla odottelevat nuoret).
  - **Vaalan poliisiasema ja Janttu:** Oulujoen sillan Vaalan puoleisessa päässä, Vaalasta lähtiessä tien oikealla
    puolella, on 70-luvun tiilinen poliisiasema (POLIISI-kyltti katoksessa, nimikyltti, lipputanko ja poliisiauto
    pihassa). Konstaapeli Roivainen on asemalla aina, kun ei ole ratsiassa. 20 % matkoista hänellä on tutka tien
    reunassa: yli 47 km/h (40 + toleranssi) pysäyttää, ja sakoista jutellaan (rikesakko 50 €, yli 20 km/h ylinopeudesta
    100 €; selittely joskus varoitus, muuten +20 €; ohi ajaminen 120 € postissa). Vastapäätä puistonpenkin päällä
    makaa kilipäissään Janttu (pipo, Alkon kassi tyynynä, kossupullo ja tölkit penkin alla, Zzz). Vain jalan (ei ajaessa) voi tarjota kaljaa, pontikkaa tai
    Koskenkorvaa (hereillä ollessaan hän ei ota uutta): Janttu herää ja kertoo, missä Roivainen ratsaa tänään tai mittaako hän tutkalla. Testi `--scene=poliisi`.
  - **Lama Vaalassa:** Siitarin lounaispuolella on työvoimatoimisto, jonka ovella jonottaa kuusi ihmistä ("Sahalta
    lähti viiskymmentä miestä kerralla") ja ilmoitustaululla lukee "AVOIMET TYÖPAIKAT –". Jonoon pääsee kerran
    päivässä (puoli tuntia), ja virkailija antaa lomakkeen tai kurssiesitteen. Muiden liiketilojen ikkunoissa on lappuja
    "LIIKE LOPETTAA", "LOPPUUNMYYNTI" ja "TILA VUOKRATTAVANA". Pankkiautomaatti (Vaalassa ja Saloisissa) voi hylätä
    kortin, jolloin uusi yritys onnistuu, tai pankki on laskenut nostorajaa ja koneesta tulee vain 10 €. Päivin aamulapussa
    on välillä motkotusta rahasta (`--scene=mokkilama`). Keskustassa laserpuita on harvennettu, jotta taajama erottuu.
  - **Aukioloajat:** K-Marketit 7–21, Alkon hylly 9–18, Siitarin baari 11–02 (hotellin vastaanotto aina auki),
    Kapteenin Kulma 14–02 ja lavatanssit 20–01, pankkiautomaatti aina. Suljetulla ovella kerrotaan, milloin paikka
    aukeaa, ja taksi Raaheen ei lähde, jos baari on perillä kiinni. Sulkemisaikaan sisällä tulee valomerkki: kaupassa
    kauppias hoputtaa, ja baareista ja lavalta ohjataan ulos vartin päästä (`--scene=mokkiaukiolot`).
  - **Hotelli Siitari:** oma kaksikerroksinen rakennus (0,75 ravintolan pituudesta, 10,5 m syvä) ravintolan takana (HOTELLI SIITARI -valomainos harjalla,
    polku parkkipaikalta ovelle, `--scene=siitarihotelli`; ravintola ja hotelli on siirretty 6 m pois tiestä, jotta terassi ja seinä eivät ole tiellä). Ovesta pääsee vastaanottoon, jossa
    Marjatta kertoo, että huoneet ovat täynnä. Käytävän perällä huoneessa 12 riehuu Dingo kiertueellaan: sänky on nurin,
    patja seinää vasten, ikkuna rikki, tuoli lentää seinään ja joku hyppii. Bändiltä voi pyytää nimmarin, ottaa huikan
    Koskenkorvasta tai auttaa heittämään telkkarin ikkunasta (moraali ja maine nousevat, mutta jos Marjatta näkee,
    vahingot maksetaan, 40 €) (`--scene=mokkihotelli`).
    Moposta voi nousta jalan F:llä kuten pyörältä (hiljaa ajaen; mopo jää parkkiin tyhjänä) ja kävellä; **ovet, pankkiautomaatti, lava ja Siitari toimivat vain jalan**: mopon selässä
    vihje kehottaa nousemaan mopolta (F). F mopon vieressä nostaa takaisin selkään. Veteen ei kahlata.
    Paperikartta (M) on mökillä ja Vaalan matkalla yksi iso Neittävä–Vaala-kartta: mökin piha, mopotie ja Vaalan
    keskusta (Siitari, K-Market Tervaportti, pankkiautomaatti, Oulujärven lava, kirkko, rautatieasema ja muut
    nimetyt talot). Kartta on piirretty samaan tyyliin kuin Saloisten kartta (`shaders/vaala_kartta.gdshader`): litteät värit ja
    pehmeät rajat, pellolla ruskea ja vedellä sininen ääriviiva, suolla vinoviivat, metsässä puumerkit, maantiet keltaisina ruskealla
    reunuksella, sorateet ohuina mustina viivoina ja talot mustina. Siitariin ei ole keltaista ohjeviivaa, kompassi riittää. Mökin pohjoiset järvet (Salmiset, Pyöriäinen ja Keskimmäinen)
    ovat kartalla ja mopomatkan maisemassa Neittävällä Neittäväntien luoteispuolella loivasti tiivistettyinä, ja
    Salmisen uimaranta, Ranta-Rosvo, Keskimmäisen laavu ja tynnyrisauna niiden rannoilla; mökillä jalan kulkiessa
    "Olet tässä" näkyy samassa kartassa. Rulla tai Q/E zoomaa ja WASD tai vetäminen siirtää.
    Kännissä tanko vaeltaa, kuva huojuu ja ojaan on lyhyt matka. Siitarin baarissa on tiski, karaoke
    (näppäily, ks. Karaoke), tanssilattia, pajatso, pöytäseurue ja naapurin Sinikka. Jos Sinikan
    kanssa tanssii tai tarjoaa hänelle drinkin, Päivi kuulee siitä pian puhelimessa ja on seuraavana päivänä
    vauhdissa.
  - **Kauppa-auto:** Neittävän kyläkauppa lopetti laman alla, joten kerran päivässä noin minuutti mökille tulon
    jälkeen Kaisuantietä tulee kauppa-auto. Pihalta katsottuna se tulee vasemmalta, pysähtyy pihatien päähän Pekan
    auton viereen ja tööttää. Myyjä Eila myy luukulta kuutosen, grillimakkaraa, tulitikkuja, korvapuusteja,
    lihapiirakoita, kotiviinin sokeria ja turbohiivaa sekä Iltalehteä lama-lööppeineen. Myynti on vain käteisellä.
    Kun kukaan ei asioi, auto jatkaa parin minuutin päästä oikealle naapuriin (`--scene=mokkikauppaauto`).
  - **Pihapingis Santtua vastaan:** mailat ovat kannolla Santun vieressä (E). Street Fighter -tyyliin sivulta:
    isoilla puumailoilla lyödään palloa ilmassa puolelta toiselle ilman pöytää, ja se, jonka puolelle pallo
    putoaa maahan, häviää erän. Kaksi erävoittoa voittaa, ja pallo kiihtyy rallin pidetessä.
  - **Metsästys:** metsän riistapolulla on metsästyslava (E), josta ammutaan haulikolla (FPS) aukealle tulevaa
    riistaa: jänis, riekko, metso ja ohi lentävä kyyhky. Kaksi piippua ja 8 patruunaa, laukaus säikäyttää
    lähistön eläimet. Hirveen ei ole lupaa!
  - **Offset-savustin:** laiturin kalat ja jahdin riista laitetaan savustimeen (E, enintään 4 kerralla), ja halkoja
    lisätään tulipesään (E). Lämpö seuraa tulta viiveellä: 80–120 °C savustaa täysillä, viileämmässä hitaasti ja yli
    135 °C käristää saaliin karrelle. Valmiit savukalat ja savuriista otetaan eväiksi ja syödään nälkään T:llä.
    Makkaran voi yhä paistaa savustimessa kerralla.
  - **Santun PA-laitteet:** tuvassa on vanhat keikkakamat (kaiuttimet jalustoilla, mikseri pöydän päässä ja pääte
    lattialla). E avaa kytkennän, jossa johdot vedetään hiirellä liittimestä toiseen: Santun kännykkään Bluetoothilla yhdistetty mokkula mikserin linjakanavaan,
    MAIN L/R päätteen tuloihin ja Speakonit kaiuttimiin, virrat jatkojohdosta. Virrat päälle oikeassa
    järjestyksessä (mikseri ensin, pääte viimeisenä, muuten kaiuttimet paukahtavat), mikin kanava kiinni (kierto
    kiljuu) ja CH2 ja MASTER niin, että taso pysyy vihreällä. Kolme mokaa ja Santtu pakkaa kamat. Onnistuneen
    kytkennän jälkeen pelin tunnusmusiikki soi tuvassa ja vaimeana pihalle, kunnes PA sammutetaan (E laitteilla).
  - **Savusauna lämmitetään:** syli halkoja halkopinosta kesäkeittiön vierestä (E) ja pesään (E saunalla).
    Pesä pitää pitää täynnä, kunnes kiuas on kuuma, ja sitten pesä palaa loppuun ja savut tuulettuvat ovesta ja
    räppänästä. Vasta sitten pääsee löylyihin: liian aikaisin sisään mennessä häkä kirvelee. Ovi ja katettu
    terassi ovat järven puolella saman harjakaton alla (portaat pihan puolelta). Löylyssä istutaan hämärässä
    ylälauteella, heitetään pitkävartisella kauhalla löylyä kiukaalle ja otetaan hörppy kaljaa, jos on mukana.
  - **Santun hommat:** kun mökillä on oltu yksi yö, Santtu kirjoittaa aamulappuun päivän hommat (toisena päivänä
    3, sitten 4). Valikoimassa on 12 hommaa:
    saunapuut (sahaus ja halkominen puupaikalla, Santtu kommentoi Raimon ja Veikon tilalla, 8 halkoa),
    päädyn nurmikko Santun vanhalla leikkurilla (kiviä nurmikossa), savusaunan lämmitys, huussin tyhjennys
    (kolme sankoa takaluukusta kompostiin ja komposti talikolla ympäri), laiturin korjaus (lahot laudat irti
    sorkkaraudalla, uudet laudat ja naulat vasaralla, ohi lyönti osuu peukaloon), rännien ja katon putsaus tikkailta
    (tasapaino A/D:llä, liikaa kallellaan ja tikkaat kaatuvat), ampiaispesän hävitys saunan terassilta
    (suihkuta suuaukkoon, kolmas pisto ja juoksu järveen), kahvit Santulle pihalle ja tiskit tuvassa (minäkuvana
    altaan ääreltä, puhdas astia nostetaan altaan yläpuolella olevaan kuivauskaappiin, märkä astia lipsahtaa humalassa), paljun tyhjennys, pesu ja täyttö bensapumpulla rannasta (muista sammuttaa
    ajoissa), savustus, metsästys (ei hirveä!) ja PA:n johtojen korjaus. Sangon ja kahvikupin kanssa ei
    juosta: kova vauhti läikyttää. Santtu tulee paikalle katsomaan ja kommentoimaan jokaista hommaa
    ("Ei sitä noin hakata!") ja huutelee kuistilta, kun hommat odottavat.
    Tekemättömät hommat kiristävät Santun **hermoja** (HUD ja reppu). Täysillä hermoilla tulee lähtö: Santtu
    soittaa Pekan hakemaan, antaa yhden tähden arvostelun, eikä mökille pääse ennen huomista. Nukkumaan meno hommat
    kesken kiristää hermoja lisää, mopolla Siitariin lähtö hommat kesken saa Santun soittamaan Päiville (puhelu
    baarissa ja kotona motkotusta). Kalja tai kätköviina Santulle kerran päivässä: Santtu tekee yhden homman
    itse (puolittain). Kaikki hommat tehty: Santtu antaa 10 € palkkioksi, savukalaa ja pullon
    pontikkaa. Jokainen mökkipäivä päättyy Santun arvosteluun (1, 3 tai 5 tähteä), myös taksilla tai junalla lähtiessä (junalla tekstiviestinä), ja arvostelut näkyvät repussa.
  - **Rönttönen (Kainuun rönttönen, `ronttonen_game.gd`):** mökin keittiössä piste "Leivo rönttösiä" (E). Kolme vaihetta hiirellä:
    kaulinta (vedä kaulinta hiiri pohjassa pystyyn ja vaakaan, taikinasoikio kasvaa), täyte (4 keko perunamuusia, sitten 3 lusikallista
    puolukkaa; muusi ensin) ja reunan nyppiminen (18 poimua klikkaamalla). Valmis rönttönen on avoin soikea: täyte näkyy ja reuna on
    poimuinen. Erä on 3 rönttöstä (reppuun enintään 6). Kun ne viedään kotiin, Päivi kattaa kahvipöydän (3D: liina, kahvipannu, kupit ja
    rönttöset lautasella) sille päivälle: mielihyvä +10 ja stressi alas (palkkio kerran päivässä, loput rönttöset säilyvät).
    Humalassa kursori huojuu. Testi `--scene=ronttonen`.
  - **Santtu puuhastelee:** kannolla kahvikupin kanssa istumisen välillä Santtu kävelee pihan puuhapaikoille:
    halkoo ja sahaa puupaikalla, kantaa sylillisen halkoja saunan seinälle, heittää löylyvettä kiukaalle, koettaa
    paljun vettä, hoitaa savustinta, heittää tikkaa, onkii laiturin päässä (joskus nousee ahven), naputtelee
    laiturin lautoja, pompottelee pingispalloa, käy huussissa, kääntää kompostia, kitkee nurmikkoa, katsoo
    ränniä, rassaa mopon karburaattoria, tarkistaa pumpun ja kiikaroi metsästyslavalla. Santtu väistää, jos
    pelaaja tulee paikalle, eikä tee itse sinä päivänä annettuja hommia. Hommien katsominen menee puuhien edelle.
    Santtu kiertää rakennukset, pihan esineet, puut ja veden (reitinhaku esteruudukossa, laiturilla kansi).
  Saunassa käynti (E) on lyhyt välianimaatio terassilla: löyly höyryää saunan ovelta, ja jos kaljaa on mukana,
  otetaan hörppy. Kuistin ovelta (E) pääsee **sisälle**: tupa keittiöineen (suodatinkahvi,
  jääkaappi), pitkä pöytä, TV ja takka, makuuhuone violetteine kerrossänkyineen, kylpyhuone ja sisäsauna.
  Kerrossängyssä voi **nukkua yön**: päivä vaihtuu ja uusi alkaa mökiltä (Päivi soittaa aamulla).
- **Drooni:** kotipihan asfaltilla on droonin laskeutumisalusta (jalan E). Kuvauskopterilla tutkitaan Saloisia
  ilmasta: W/S/A/D liikkuu, hiiri tai Q/E kääntää, Space nousee, C laskee, Shift = sport-tila ja hiiren pystyliike
  kallistaa kameraa. V vaihtaa FPV- ja seurantakameran. Vasen nappi ottaa ilmakuvan: tunnistettavia kohteita on 14
  (koti, K-Market, laavu, grillikatos, Päivin Hyundai, juntti, jyväjemmari, mummot, Arto, Pekka, Sinikka, Väinö,
  jalkapallopojat ja... Pannu-Sulon pontikkapannu, joka merkitään kuvan jälkeen karttaan). Akku kestää 5 min ja
  latautuu alustalla, korkeusraja on 120 m ja kantama noin 2,7 km (akku ei riitä aivan kantaman reunalle ja takaisin): heikolla akulla tai signaalilla drooni palaa
  itse kotiin (H palaa, F laskeutuu). Kova törmäys rikkoo droonin päiväksi. Päivin jahti on tauolla lennon ajan.
  Drooni kulkee mukana myös **mökille**: alusta on pysäköintipaikan vieressä mökin takana. Mökillä kuvattavia on
  mökki, savusauna, palju, kesäkeittiö, laituri, metsästyslava, Santtu, Korpi-Kallen pannu ja lähijärvet (Likanen, Tervalampi,
  Kiiskeroinen); lentoalue ulottuu noin 600 m:n päähän, ja järveen tipahtanut drooni on mennyttä. Moottoreista
  kuuluu vain pieni surina.
- **Reppu (I tai Tab):** sama nahkakantinen kierrevihko kuin Normipäiväkirja (`mg_draw.gd notebook`: kansi, viivapaperi,
  marginaali, kierrerenkaat, tahrat, otsikkokyltti, välilehti ja käsiala). Oikealla sivulla on **9 taskua** 3 x 3 -ruudukossa:
  tavarat, kaljat, ostokset, sienet, kalat, saaliit ja eväät (T, klikkaus syö tai juo) pikselikuvakkeina ja pinoina. Täyden repun
  viimeisessä taskussa näkyy "+N"-lappu, ja sen selitys kertoo, mitä repun pohjalla on; hiiren alla olevan tavaran nimi ja kuvaus
  kirjoitetaan ruudukon alle. Vasemmalla sivulla ovat rahat, päivän tilanne, kauppalista, jemmat ja tehtävät käsin kirjoitettuina
  sekä polaroid pelaajan omasta 3D-hahmosta, joka kääntyy katsomaan hiirtä. Päänäkymän HUD:ssa näkyvät enää aika ja alusta (sekä varoitus, jos kotijemma on
  vaarassa).
- **Valcon kuulokkeet (H päähän / pois, N seuraava biisi):** pölyisessä pahvilaatikossa autotallin työkalukaapin
  päällä. Päässä ollessaan linnut, varikset ja muu ympäristö vaimenevat selvästi, mutta myös Päivin auto, poliisi
  ja muut äänet kuuluvat heikommin ja tunkkaisemmin (alipäästö). Samalla soi soittolista kansiosta
  `assets/music/kuulokkeet/` (Suno-biisit ogg/mp3/wav, ks. LUEMINUT.txt; tyhjällä kansiolla pelin omat biisit),
  ja vasemmassa alakulmassa näkyy soiva biisi. Mukana on seitsemän 90-luvun tyylistä eurodance-, techno- ja
  rave-biisiä (CC BY, tekijät alla), jotka soivat myös lavan diskopuolella ja teinien kasettisoittimista.
  Löytö säilyy (testi `--scene=kuulokkeet`).
- **Vaatekaapit ja asut:** pelaaja on vaaleahiuksinen ja pukinpartainen, ja hänellä on kello, rannekoru ja tatuointi
  vasemmassa olkavarressa. Oletuksena tuulipuku, Karhu-lippis ja peililasiset pilottilasit. Kodin makuuhuoneen
  vaatekaapista vaihdetaan repaleiseen verkkopaitaan, ruskeisiin henkseleihin ja tummiin työhousuihin (rispaantuneet
  repeämät, vyö, nokiset tahrat iholla ja tuprukka vaalea tukka, viitteenä Uuno kyntämässä; `character.gdshader` net_shirt, grime), Paapelin makuuhuoneen kaapista työhousuihin, flanelliin ja Karjala-lippikseen. Kodin
  kaapista saa myös Stetson-cowboyhatun lippiksen tilalle (ruskea huopa, keskiura, kaareva lieri, nauha ja hopeinen
  koristelaatta); se pysyy päässä asusta riippumatta, kunnes lippis vaihdetaan takaisin. Kirppikseltä ostettu
  hiihtohaalari tulee kodin kaappiin neljänneksi asuksi. Ensimmäisestä kaupasta ostetusta kutosesta (K-Market,
  Vaalan K-Market tai kauppa-auto, ei juoksukaljoista) jää Karhu-kutosen pahvikoppa, ja pää pujotetaan heti sen sivun
  aukosta: koppa seisoo pystyssä päässä, edessä kansi pullonkaulojen rei'illä, sivuilla tuima karhu kyljellään
  päälaki eteenpäin ja takana pohja. Alareuna sovitetaan pään muotoon (ylimäärä pullistuu eteen ja taakse). Painatus on oma
  piirros (`tools/karhu_koppa.gd` -> `assets/karhu_koppa.png`). Koppa vaihdetaan kodin kaapilla, ja Päivi
  ihmettelee sitä kotiovella. Asu ja hattu vaihtuvat
  kaikkiin pelaajan malleihin paikallaan (pyörä, kävely, mopo, sisätilat) ja säilyvät tallennuksessa. Vaatteet
  piirretään varjostimessa pikseleinä (`shaders/character.gdshader`), asusteet ovat muutama pieni mesh luissa
  (`looks.gd`, testit `--scene=asut`, `--scene=vaatekaappi`, `--scene=stetson`, `--scene=haalari` ja `--scene=koppa`).
- **Päivin vanha kännykkä (P soimaan / taskuun, N seuraava, U voimakkuus):** kodin makuuhuoneen yöpöydällä
  parisängyn vieressä. Soittaa vanhoja iskelmiä 78 kierroksen levyiltä (`assets/music/iskelma/`, sama lista kuin
  lavabändillä) pienestä kaiuttimesta: oma ääniväylä kaistanpäästöllä ja säröllä, joten ääni on ohut kuin taskusta.
  Soidessa puhelin näkyy minikartan vieressä: näytöllä juokseva biisin nimi, esittäjä, aika, taajuuspalkit ja
  voimakkuus, ja kaiuttimesta nousee nuotteja. Soittolistalla ovat myös Saloisten Saapasjalkojen biisit (Pihalla
  tavataan, Rasvanappi ja Normipäivä). Kuulokkeet ja pelin oma musiikki tauottavat puhelimen. Kansioon
  lisätyt biisit (esim. Eräät Jormat Suno-soittolistalta, ks. LUEMINUT.txt) soivat myös. Löytö ja voimakkuus
  säilyvät (testi `--scene=puhelin`).
- **Vaarat:** Päivin Hyundai, juntti, laavun valtaajat ja jyväjemmari traktorilla, jos ajat viljapellolle.
  Kiinni jäädessä ratkaistaan Street Fighter -tappelussa.
  Juntilla on seitsemän paikkaa reittien varrella ja Seuranmäellä (Reipparin edusta ja kentän laita), ja hän ehtii
  sinne, minne olet menossa: kun lähestyt jotakin paikkaa ja Juntti on kaukana poissa näkyvistä, hän on jo siellä.
  Juntti ei siirry kenenkään nähden (kumpikaan paikka ei saa näkyä kamerassa) eikä kesken jahdin. Testi
  `--scene=junttikierto`.


### Kota, sahaus ja halonhakkuu

- **Haapajärven tekoaltaan kota** (sijainti OpenStreetMapista) on n. 2 km laavulta etelään Kotapolkua pitkin.
  Sahaa tukki pölkyiksi pokasahalla ja halko pölkyt kirveellä (jalan, E), sytytä tuli kotaan ja kuuntele
  vakiovieraiden Raimon ja Veikon tarinoita (12 kpl, kuullut tallentuvat). Kota on täynnä kieltokylttejä.
  Vieressä lintutorni: kävele portaat ylös ja katsele lintuja tekojärvellä.
- **Sahaus** on FPS-minipeli: tähtää tukkiin ja merkkaa katkaisukohta (pölkyn mitta näkyy, pukin välistä ei
  sahata), sitten sahaa hiiren eteen-taakse-liikkeellä. Kädet ja tuulenpuuskat kallistavat sahaa: pidä se suorassa
  hiiren sivuliikkeellä, muuten saha kiilaa. Liian kiivas riuhtominen saa sahan hyppäämään uralta. Raimo ja
  Veikko arvioivat mitan ja suoruuden.
- **Halonhakkuu** on FPS-minipeli: nosta pölkky läjästä, käännä se oikein päin ja aseta keskelle halkaisupölliä.
  Pölkky pysyy pystyssä vain tasainen pää alaspäin (toinen pää on vino ja runko pyöreä): väärin päin tai
  reunalle asetettu pölkky pyörähtää pois. Sitten tähtää kirveellä hiirellä ja iske. Kädet huojuvat ja
  tuulenpuuskat heittävät tähtäystä. Keskelle osunut isku halkaisee pölkyn neljäksi haloksi, vähän sivuun
  osunut jää kiinni ja reunaan osunut lennättää pölkyn pölliltä. Raimo ja Veikko tulevat ulos kommentoimaan.
- Kartan reunalla hahmo kommentoi, miksi pidemmälle ei kannata lähteä.

### Mökin esikuva

- **Mökki** on mallinnettu oikean Airbnb-vuokramökin ("The warmth of a smoke sauna and cottage life",
  Neittävä) valokuvien mukaan. Se on erillinen alue, jonne pääsee naapurin Pekan kyydillä tai kaupan taksilla.

## Normipäiväkirja: tarina, tehtävät, onnelliset loput ja legendaariset hetket (O)

- **Tarina** etenee luvuittain: 1. Paapeliin pääsee, kunhan… (naapurien hommat ja Pekan kyyti mökille), 2. Paapelin
  isäntä (Santun hommat ja savusaunan korjaus), 3. Mopolla Vaalaan (Siitari, Oulujärven lava, kiihdytys), 4. Junalla
  kotiin ja 5. Kylän salaisuudet (Seuranmäen kirppis, Tokolan varasto ja aarre, Vanhan Sulon pannu, Lapinraunion aarnivalkea, Kertunkankaan rauta, Tekojärven Ukko). Seuraavaan
  vaiheeseen vihjataan puheissa: Santtu, Siitarin baarimikko, aidan takana porukka, Gasthausin emäntä, Pekka
  ja Tauno kertovat, mitä seuraavaksi.
- **Sivutehtävät**: kauppalista, nurmikko, laavu, Väinö, jalkapallopojat, pontikka, ilmakuvat, kotiviini,
  sähköpyörä, huutokauppa, tanssit ja bingo, Teron kädenvääntö, Santun viisi tähteä, viina- ja rahakätköt,
  eräjorma, pihapingis ja pummilla lavalle.
- **Jemmat**-välilehti: kaikki löydetyt jemmapaikat täyttöpalkkeineen (kaljat / tila), kotijemma tavoitteeseen
  nähden tölkkiriveinä, ulkojemmat ja yhteensä sekä riskit: Päivi voi löytää liian täyden
  kotijemman, ja teinit voivat pölliä ulkojemmasta. Reppu (I) näyttää myös tyhjät löydetyt jemmat. Testi `--scene=jemmat`.
- **Päiväkirja (O)** ei paljasta mitään etukäteen: luku näkyy, kun siihen päästään, vaihe, kun siitä on kuultu, ja
  sivutehtävä, kun siitä on kerrottu. Uusista vihjeistä tulee ilmoitus "Päiväkirjaan tuli uutta".
- **Onnelliset loput** (päivä päättyy loppukohtaukseen): juhlat autotallissa, viinibileet, laavulla kaljoilla,
  legendaarinen normipäivä, mökkibileet, erämaan laavu (Viitajärven laavu auringonlaskussa) ja Kymppiuutiset nauhalta
  (video ajastetaan olohuoneessa ennen klo 22, ja klo 22.25 jälkeen sohvalle eteisen kaapin kaljan kanssa). Ilmoitus
  "ONNELLINEN LOPPU".
- **Legendaariset hetket** (saavutukset, peli jatkuu): Paapeliin Pekan kyydillä, savusaunan löylyt, lavatanssit,
  karaokekuningas, kiihdytyksen voittaja, sähköpyörä, seuraintalon tanssit, bingon jättipotti, lihapiirakkakuningas,
  Drakkar Noir ja legendat (Tokolan aarre, Vanhan Sulon pannu, viimeisen sepän kirves, Isonvihan hopeat, Tekojärven
  Ukko, Ukko vapaaksi). Ilmoitus "LEGENDAARINEN HETKI".
- Päiväkirjan Loput-välilehdellä onnelliset loput vasemmalla (X / 7, kerrat yhteensä) ja legendaariset hetket oikealla
  (X / 16, tähtirivi), löytämättömät ???. Testi `--scene=paivakirja`.

## Jalan vai pyörällä?

- **Vain jalan:** kauppaan meno, marjojen ja sienten poiminta, laavun toiminnot, kaupat naapureiden kanssa
  ja kotiin meno. Nouse pyörän selästä F:llä.
- **Pyörä** on asfaltilla nopea, mutta metsässä ja pellolla pääset jalan nopeammin.
- **Lukitsematon pyörä:** jos jätät sen pitkäksi aikaa kauas (ei kotipihaan), teini voi pölliä sen. Varas ajaa
  pyörällä oikeasti teitä ja polkuja pitkin: ensin kohti sinua ja 100 m:n päästä sinne tänne enintään 100 m:n
  päässä, kunnes hylkää pyörän (sieltä sen voi taas pölliä). Kartta (M) näyttää pyörän koko ajan; kun ehdit
  pyörän viereen, teini hyppää selästä ja juoksee karkuun.
- **Kunto:** juoksu ja pyörän spurtti (Shift) kuluttavat kuntoa. Tyhjänä pitää kävellä tai polkea rauhassa,
  kunnes kunto palautuu. Spurtin alussa saattaa päästä miehekäs pieru.

## Päivät, turvapaikat ja välianimaatiot

- Peli jatkuu päivästä toiseen. Kun jäät kiinni, tulee **WASTED** ja Päivin motkotus, ja uusi päivä alkaa
  lähimmästä turvapaikasta: kotoa, laavulta (kun olet vallannut sen) tai Viitajärven laavulta (kun olet saanut
  erämaan laavun lopun).
- Onnellinen loppu kotona: karburaattorin säätöä autotallissa kalja kädessä. Laavulla: makkaranpaistoa
  auringonlaskussa.
- **Jemmat:** piilota kaljat itse kotijemmoihin (eteisen kaappi, autotalli, komposti), laavun halkovajaan tai
  Kiilinlammen grillikatokselle (jalan, E; pontikkakanisteri E:llä kotijemmaan = 24 kaljaa). Kotiovesta pääsee
  sisään vasta tyhjin käsin. Kun kotipiiloissa (eteinen, autotalli
  ja komposti yhteensä) on **24 olutta**, juhlat aloitetaan tyhjin käsin kotipiilon luona (E): onnellinen loppu
  autotallissa. Nukkumaan mentäessä juhlat eivät ala itsestään. Yli 9 kaljan kotijemma on vaarassa: Päivi voi löytää sen
  (JEMMA PALJASTUI!). Laavun ja grillikatoksen jemmoista teinit voivat pölliä. Jemmasta voi ottaa kaljat mukaan
  ja juoda ne laavulla. Onnellinen loppu juo kyseisen jemman tyhjäksi (autotalli kotijemman, laavu laavun jemman).
- **Kantoraja:** jalan jaksaa kantaa 12 kaljaa, pyörän kyytiin mahtuu 6. Liian täysin käsin ei pääse pyörän
  selkään, ja kalja kädessä ei pääse kauppaan (kauppias kieltää).
- **Turvapaikat Päiviltä:** Kiilinlammen grillikatos, Viitajärven laavu ja länsilaidan rauniot. Niihin Päivi ei tule
  Hyundailla perään. Testi `--scene=turvapaikat`.
- Esc avaa valikon: asetukset (grafiikan laatu, koko näyttö, V-Sync, renderöintiskaala, FOV, FPS-näyttö,
  leijuvat opasteet eli paikkojen ja hahmojen nimet (oletuksena pois), äänenvoimakkuudet, hiiren herkkyys, käänteinen Y, kameran automaattikeskitys), ohjaimet ja tekijät.
