# Pelin sisältö

> **Juonipaljastuksia.** Tämä opas kertoo pelin kaikki paikat, tehtävät, salasanat ja legendojen ratkaisut. Peli itse ei paljasta mitään etukäteen (päiväkirja näyttää vain sen, mistä on kuultu).

Kaikki, mitä Saloisissa, ja Raahessa voi tehdä. Ohjaus: [ohjaus.md](ohjaus.md),
päivän tilat: [tilat.md](tilat.md), kehitys ja testit: [kehitys.md](kehitys.md).

## Mitä pelissä voi tehdä

- **Tarina "Raaheen pääsee, kunhan…":** ohjaa naapurilta toiselle, mutta kaikki muu pysyy vapaana. Ensin
  kuutonen kotijemmoihin (eteinen, talli ja komposti yhteensä), sitten Pekka huikkaa pihalta ja antaa kolme tehtävää vapaassa järjestyksessä: 3 l sieniä
  Pekalle (Arto tietää paikat), 5 l puolukoita Artolle ja Sinikan takapihan nurmikko niin, ettei Päivi näe
  (jos näkee, Päivi suuttuu ja lähtee jahtiin, mutta leikkuuta voi jatkaa karkuun päästyä). Lopuksi Pekan
  autonavaimet ovat hukassa kodalla: Pekka kävi lintutornilla kaverin kyydillä niin kännissä, että ampui
  luvallisia ja luvattomia lintuja osumatta yhteenkään. Avaimet Pekalle, niin Pekan kyyti Raaheen aukeaa.
  Tehtävät näkyvät repussa (R) sitä mukaa kuin niitä löytyy. Raaheen ei pääse taksilla (taksi ajaa vain retkille ja
  Raahen baariin). Raahe on välietappi: tarina jatkuu myöhemmin.

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
- **Rasvanappi (vain aikuisille; piiloon asetuksella "K-18-sisältö pois", ks. docs/ohjaus.md):** aseman länsipuolella (noin 21 m) on rapistunut tavaramakasiini. Länsipäädyn takaovella palaa punainen
  lamppu häkissä: koputa (E), niin kurkistusluukku aukeaa ja portsari kysyy salasanan. Oikea on "Rasvanappi", ja
  väärästä luukku paukahtaa kiinni. Sisällä pelaajat (Pekka, Arto, Sinikka, Raimo ja Helena) esittäytyvät pyyhkeissään.
  Muista, kuka kiroilee, hyräilee, kikattaa, niiskuttaa tai huokailee, sillä pimeässä muut tunnistaa vain äänestä.
  Valojen sammuttua kontataan (WASD, Shift ripeästi mutta kolisten). Rasvanappi tökkää jotakuta takaapäin peppuun
  (E) ja huutaa nimen. Jos arvaus osuu, tökätty nuolee sormen ja on seuraava nappi. Jos ei, tökkääjä nuolee itse.
  Kun nappi on joku muu, se jahtaa pimeässä. V (kamera) vaihtaa omaan näkymään konttaajan silmistä: W/S konttaa
  eteen ja taakse, A/D kääntyy. Jos asetuksista on valittu hiiri ohjaa kulkusuuntaa (FPS-tyyli), hiiri lukitaan:
  sivuliike kääntää, pystyliike kallistaa katsetta, A/D konttaa sivuttain ja klikkaus tökkää. Valinta muistetaan seuraavaan kierrokseen ja lopussa palataan yleiskuvaan.
  Testit `--scene=rasvanappi` ja `tools/testit/rasvanappi_kuvat.tscn`.
- **Pentin BangBus (vain aikuisille, #299):** Pentti (keksitty keski-ikäinen viiksimies: avonainen nahkaliivi karvaisen rinnan päällä, pilottilasit,
  kultaketju) seisoo tuunatun pakettiautonsa vieressä perjantai- ja lauantai-iltaisin klo 19–23: Saloisissa K-Marketin
  parkkipaikalla, Raahessa Zabukin asiakasparkissa. Muina aikoina Pentti ajaa autollaan Saloisten liikenteessä.
  Auto on viininpunainen Hiace: kyljissä käsinmaalattu PENTIN BANGBUS -banderolli, keulassa liekit, katolla
  lisävalot, takaikkunassa ja ohjaamon takana punaiset samettiverhot ja peilissä pehmonopat. Pentti huutelee
  lähelle tulevalle. Juttelussa kaksimieliset repliikit autosta (eivät toistu samalla kerralla), "Mikä ihmeen
  BangBus?" (moraali kerran päivässä), kieltäytyminen tai kyyti. Kyyti on välikohtaus: auto keinuu parkkipaikalla,
  ikkunat huurtuvat ja radiosta soi humppa; mitään ei näytetä. Pelaaja herää aamulla klo 10.30 oudosta paikasta
  (Saloisissa urheilukentän maalista, Oravajärven rannalta tai aseman laiturilta, Raahessa Gasthausin pihalta):
  moraali nousee, mutta vireys, kipu ja stressi kärsivät, ja lompakosta puuttuu 5–20 € ("Bensarahat. T: Pentti").
  Jos joku kylän hahmo on lähellä (25 m), hän näkee kyytiin nousun 60 %:n todennäköisyydellä: maine −3 ja Päivi
  kuulee asiasta aamulla. Päiväkirjaan sivutehtävä "Pentin kyydissä".
  Ensimmäinen kyyti on legendaarinen hetki (`cutscene.gd _pentti_legend`): keinunta ja humppa loppuvat, liukuovi
  aukeaa punaisen hehkun keskeltä, ja pelaaja astuu ulos. Kaupasta tuleva mummo pudottaa ostoskassinsa ("Tää
  kerrotaan koko kylälle!"), maitopurkki vierii pois, ja Pentti huikkaa keulan vierestä. Lopuksi kamera nousee
  parkkipaikan ylle ja hetken nimi tulee näkyviin. Aamulla tulee rivi "Päiväkirjaan uusi tarina". Myöhemmät kyydit
  lasketaan hiljaa, ja Pentti muistelee ensimmäistä kertaa tervehtiessään (`rikos/pentti.gd HELLO_MUISTO`). Testi
  `--scene=pentti_eka`.
  Toisella kerralla Pentti suunnittelee kiertuetta, ja joka kolmas kyyti on **Pentin kiertue** (onnellinen loppu):
  loppukohtauksessa BangBus ajaa yön maantietä Kajaanin, Kuhmon ja Suomussalmen kautta, Pentti ratissa ja pelaaja
  etupenkillä. Herätys kotipihalta (Raahessa Gasthausin pihalta) klo 11, kiertuekulut 20–40 €.
  Testit `--scene=bangbus` ja `--scene=bangbus_vaala`. Mainosjuliste: [kuvat/pentin_bangbus_juliste.png](kuvat/pentin_bangbus_juliste.png).
- **Kolmiomittaus (Sytkäri-mätsi, vain aikuisille):** Saloisten kaupan pihassa seisovat Joni (tummatukkainen golfari,
  selässä Sandels-oluen 24-pakkauksesta jesarilla tehty päkkirinkka termoksineen, golfpalloineen ja tölkkeineen) ja Esa
  (erämies, harppi taskussa), Raahen aseman pihassa Hevari-Tero (valittaa valtiosta) ja Sivikki-Timo (punainen Honda
  Civic, VTEC). Juttele (E), niin puhelimeen tulee Sytkäri-mätsi (parodiadeittisovellus, liekkilogo): Minttu (punaiset
  kiharat, pisamat, kesämekko) Saloisissa tai Katja (pitkät mustat suorat hiukset, nahkatakki, motoristi) Raahessa;
  kumpikin vähintään yhtä hemaiseva kuin Sinikka. Ovi-, väärän oven ja aamukohtaukset ovat
  3D-lavastuksia omissa maailmoissaan (`kolmio_kohtaus.gd`), ja Sytkärin profiilikuvat on otettu 3D-hahmoista.
  Osoitetta ei kerrota, vain etäisyys. Kaveri mittaa lähtöpaikalta, ja toinen mittaa kauempaa: Saloisissa Esa
  tekstaa kirkolta, Raahessa Teron ja Timon kanssa jutellessa valitaan "Hypätään Sivikkiin", ja Timo ajaa porukan
  aseman pihasta katuja pitkin Raahentielle (maaston kautta vain, jos tietä ei ole) ja tietä pitkin mittauspisteeseen (VTEC kytkeytyy, matkalla Timon ja Teron
  jutut, E hyppää perille) ja takaisin asemalle. Mittauksen ajan kaverit kulkevat jalan pelaajan perässä (Esa
  liittyy mukaan tekstattuaan, Tero ja Timo Sivikki-ajon jälkeen) ja seisovat takana ovella; pyörän tai mopon
  selässä he jäävät odottamaan ja tulevat perään, kun pelaaja jatkaa jalan. Sen jälkeen pelaaja mittaa lisää missä vain (E "Avaa Sytkäri", vähintään 35 m edellisistä mittauksista).
  Sovellus pyöristää etäisyyden (alle 120 m 10 m:iin, alle 500 m 50 m:iin, muuten 100 m:iin), joten paperikartalla (M)
  jokainen mittaus on harpilla piirretty ympyrä ja haalea vyöhyke; vyöhykkeet tummuvat päällekkäin, ja leikkauksessa
  on naisen talo. Lähempää mitattu ympyrä on tarkempi. Väärällä ovella avaa joku muu (mummo kepin kanssa, Pannu-Sulo,
  verotoimiston Raimo...). Kolmiomittaajat tuovat kukin yhden lahjan kuin itämaan tietäjät (Saloisissa Esa mansikat,
  Joni kermavaahdon ja pelaaja ruusut, Raahessa Timo kermavaahdon, Tero ruusut ja pelaaja mansikat); oma lahja ostetaan
  kaupan tiskiltä kauppiaalta (9 €), ja ilman sitä ovi ei aukea ("Missäs ne ruusut on?"). Oikealla ovella pelataan
  erikoissääntöinen Rasvanappi naisen pimennetyssä olohuoneessa (TV-taso, piano, kirjahylly, takka, ruokapöytä,
  sohva, arkku, jalkalamppu, viherkasvi ja rahi samoilla paikoilla kuin makasiinin esteet; ikkunasta kuunvalo,
  eteisen ovesta valojuova): viisi pelaajaa (pelaaja, nainen, kaverit ja naisen
  ystävätär), kermavaahto margariinin tilalla, mansikka palkinnoksi oikeasta arvauksesta ja kaverien omat äänet
  (golfjutut, hyräily, valitus, VTEC). Kesken pelin Päivi soittaa: "Missä sää oot?" "Kolmiomittaamassa." "No tuo maitoa
  tullessas." Aamulla kahvit ja mansikkaletut (onnellinen loppu **Kolmiomittaus Saloisissa** tai **Raahessa**), ja
  seuraavana päivänä maito on vietävä kotiin, tai Päivi motkottaa. Yksi kolmiomittaus päivässä. Päiväkirjan Tehtävät-sivulle
  tulee "Kolmiomittaus Saloisissa" tai "Raahessa", kun kavereiden kanssa juttelee ensimmäisen kerran (ajatusviesti), ja se
  leimataan tehdyksi aamulla; Saloisten tehtävällä on karttamerkintä kavereiden luo. Testit
  `--scene=kolmiomittaus` ja `--scene=kolmiomittaus_vaala` (`tools/testit/kolmiomittaus.gd`).
- **Iltakivat (kolmiomittauksen toinen ilta ja siitä eteenpäin, vain aikuisille, vähän rivoja):** kohteen ensimmäinen
  ilta on aina Rasvanappi, sen jälkeen illat kiertävät (`kolmiomittaus.gd KIVAT`; Saloisissa räsytuppi, lettukisa,
  karaoke ja löylykisa; Raahessa räsytuppi, Sivikki-disko, löylykisa, lettukisa ja karaoke). Jokaisen voitto on
  legendaarinen hetki, ja aamun tilastorivi ja kaverien aamurepliikit kertovat illan kivasta (`kolmio_kohtaus.gd KIVA_AAMU`).
  Sivutehtävä **Kolmiomittauksen iltakivat** (päiväkirja, tulee tiedoksi ensimmäisen kolmiomittauksen jälkeen): koe kaikki
  kuusi (Rasvanappi, räsytuppi, lettukisa, löylykisa, Sivikki-disko ja karaoke; voittoa ei vaadita, luovutus ei kelpaa).
  Edistyminen "koettu n / 6" ja puuttuvat kivat; disko vaatii Raahen.
  - **Räsytuppi** (`tuppi.gd`, `tuppi_game.gd`): tuppia pareittain naisen olohuoneen korttipöydässä (pelaaja ja nainen
    vastaan kaverit; rami tai nolo, maapakko, ässä korkein). Jaon hävinnyt pari riisuu: kengät, paita (naisella
    rintaliivit jäävät) ja housut; kalsareissa hävinnyt pari on pantu tuppeen. Legendaarinen hetki **Räsytuppi**.
  - **Lettukisa** (`lettu_game.gd`): minuutissa eniten kermalettuja. Haukku (E) täyttää suuta ja suu tyhjenee
    pureskellessa; liian iso suullinen = kerma nenästä ja yskintä. Letut ovat kolmesta palasta, haarukka nousee suulle,
    ja nainen tuo lisää lettuja pannulta. Legendaarinen hetki **Lettukunkku**.
  - **Löylykisa** (`loyly_game.gd`): oma sauna (lauteet, kiuas kivineen, höyry), pyyhkeet lanteilla. Nainen heittää
    löylyä tasaisin välein; hengitä ulos (E), kun rengas on vihreällä, niin tuska laskee. Paennut nousee lauteilta, ja
    pyyhe jää lauteille. Viimeinen lauteilla voittaa: **Löylykunkku**.
  - **Sivikki-disko** (vain Raahe, `disko_game.gd`): Katjan pihalla Timon Civic ajovaloineen ja pohjavaloineen, stereoista
    oikea 90-luvun tanssibiisi (tempo mitattu). Liikkeet tulevat tahdissa neljälle kaistalle: lantio (A/D), kädet ylös (W)
    ja pyllistys (S, hahmo pyllistää kameraan). Katja valitsee parhaan tanssijan hitaille: **Sivikki-disko**.
  - **Karaoke** (`ilta_karaoke.gd`): mikrofoniteline olohuoneessa ja putkitelkkari sanoineen; jokainen laulaa oman rivon
    säkeistön pelin karaokella (`karaoke_game.gd`, nuottikaistat), kaverien vuoroilla tekoäly näppäilee. Paras laulaja
    voittaa: **Karaokekunkku**.
- **Luku 6: Päivi epäilee (#326, aikuisille):** salaiset hommat jättävät jälkiä, ja Päivin **epäluulo 0–100**
  (`scripts/rikos/paivi.gd`) nousee niistä. Jäljet: kolmiomittaus +20, Rasvanappi, Pentin BangBus ja huumekaupan myynti
  +15, korkkikansio, rakaleiman kopio, Drakkar Noir ja Irman hälytys +10. Jälki syntyy kerran, kun ensikerta tehdään, ja
  Päivi ottaa sen puheeksi seuraavana aamuna kotipihalla (ennen klo 11, alle 50 m kodista, yksi jälki aamussa;
  `rikos/paivi_puhe.gd`). Päivi seisoo pihalla pelaajan vieressä, ja valinnat ovat kolme selitystä, tunnustus ja
  vastahyökkäys. Selitys menee läpi vain, jos pelaaja on oikeasti tehnyt sen (esim. jutellut Pekan kanssa samana päivänä
  tai käynyt kirppiksellä): tosi −5, valhe +10, ja väärä Pekka-selitys paljastuu, kun Pekka tervehtii seuraavan kerran
  (+10). Tunnustus −15 ja moraali −0,05, ja Päivi muistaa sen. Vastahyökkäys ("Missä sää oikeen käyt iltaisin
  jumpassa?") +5 ja avaa huipennuksen. **Hyvitykset** (`rikos/paivi_hyvitys.gd`) laskevat epäluuloa vain jäljen jälkeen:
  kukat, Wanhan Raahen ovikuva ja Sinikan tomaatintaimet −10, kauppalista, nurmikko ja pensasaita −5; sama hyvitys ei toimi
  samana eikä seuraavana päivänä. **Päivi tutkii** (yli 60, `rikos/paivi_tutkii.gd`): iltaisin klo 19–21 Hyundai ajaa
  "jumppaan" seuraintalon pihaan eikä jahtaa. Alle 25 m seuraaminen paljastuu (+10 kerran päivässä), 25–50 m päästä
  näkee, mihin Päivi menee. Pekka, Sinikka, Hilkka ja Pentti vastaavat Päiville pelaajan tekojen mukaan, ja Päivi löytää
  liian täyden kotijemman ja korkkikansion. **Huipennus: Kesäheila -96** (`main.gd _kesaheila_*`): kun epäluulo on ollut yli
  60 tai vastahyökkäystä on käytetty, Sytkäri piippaa uudesta mätsistä "Kesäheila -96, Saloinen" (profiilikuva: Päivi
  olkihatussa Saloisten lavalla, seepia). Joni ja Esa mittaavat sen kaupan parkkipaikalta kuten Mintun, ympyrät
  leikkaavat oman kodin, ja etuovella koputetaan: Päivi seisoo kynnyksellä kerma ja mansikat käsissään, Sinikka nauraa
  eteisessä. Valinnat: **Nauraa yhdessä** (epäluulo 0, onnellinen loppu **Kulissit kunnossa**, aamu omassa keittiössä),
  **Tunnustaa kaikki** (pelaajan synnit oikeista teoista ja Päivin omat, mm. Zabukin tanssit; loppu **Avoin pelikortti**)
  tai **Suuttua** (Päivi äidilleen 7 päiväksi: ei lappua, rahaa eikä listaa, jääkaappi tyhjä; kukat ovella tuovat hänet
  aiemmin, ja valinta tehdään uudelleen). Legendaarinen hetki **Kesäheila -96** tulee kummassakin onnellisessa lopussa.
  **K-18 pois:** vain korkkikansion ja Drakkarin jäljet, puheeksiotto ja hyvitykset toimivat; Päivi ei tutki, eikä
  huipennusta tule. Päiväkirjan Tarina-sivulla luku 6 näkyy vaiheineen ja Päivin piirretyllä ilmeellä (rauhallinen,
  kulmat koholla, kädet puuskassa, laukku pakattu). Vihjeitä: Pekka ("Päivi kyseli musta eilen..."), Sinikka ja Pentti.
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
  (herätys kotona). Uusi kohde = yksi rivi rekisteriin ja yksi tiedosto; Raahen aseman matkavalikko (`lahto: "vaala_asema"`)
  generoidaan samasta rekisteristä, kun ensimmäinen Raahen kohde tulee.
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
    11, savukala 7, savuriista 9, kalja 15, pontikka 20. Pelin aikaa kuluu tunti per neljä asiakasta. Testi `--scene=kirppismyynti`.
  - **Pekan vintin romut** (`pekan_laatikko.gd`): kun oma pöytä on kerran pidetty, Pekka tarjoaa laatikollisen
    vanhaa tavaraa ("Vie kirppikselle, puolet mulle"): kolme iskelmä-LP:tä (5 €), pilkkipokaali -87 (10), karvalakki
    (12), vieherasia (15), Itkevä poika -taulu (18) ja kampikahvimylly (12). Ne myydään omalla pöydällä kuten marjat;
    ostajat huudahtavat tavarasta ("Voi, Itkevä poika!"), Anna-Liisa tunnistaa Pekan tavarat, ja romujen ollessa
    pöydällä tulee myös keräilijä, joka maksaa vanhasta hyvin. Puolet romujen tuloista on Pekan (yhteenvedossa ja
    viestissä). Tilitys Pekalle samana päivänä: maine +2 ja seuraava kyyti mökille ilmainen ("Pekan piikkiin").
    Jos osuus jää yön yli, Pekka tervehtii vihaisena eikä anna kyytiä, ennen kuin rahat tulevat (ei palkkiota).
    Myymättömät jäävät laatikkoon (reppu: Pekan romulaatikko). Sivutehtävä "Pekan vintin romut". Testi
    `--scene=pekanlaatikko`.
  - **Hiihtohaalari:** Railin vaatetangossa keskipöydän vieressä (vakosamettitakin ja flanellipaidan välissä)
    roikkuu neonpinkki kasarin toppahaalari, 6 € (tinkiä voi). Valkoinen olkakaarroke sahalaitaisin vuorenhuipuin,
    keltainen ja turkoosi raita, tikkauskanavat, vetoketju, mustat resorit, valkoiset kuukengät ja raidallinen frotee-otsapanta
    (mitoitetaan pään ja tukan mukaan). Ostettuna moraali nousee hieman, Anna-Liisa nauraa, ja haalari tulee kodin
    vaatekaappiin. Haalarissa Anna-Liisa nauraa seuraintalolla ja Päivi motkottaa kotiovella kerran päivässä.
  - **Släbärit ja villasukat:** samalla tangolla lattialla 90-luvun släbärit (tummansininen muotoiltu pohja, leveä remmi
    kolmella valkoisella raidalla), 3 € (tinkiä voi). Jalassa ne ovat yksi kenkä: harmaa villasukka (resorivarsi puoleen sääreen lahkeen päällä, valkoinen kanta ja
    kärki) ja släbäri päällä. Ostettuna Raili muistelee Kalajoen hiekkoja, ja Päivi kaivaa kotona
    niihin harmaat villasukat (valkoinen kanta ja kärki). Kodin vaatekaapista "Släbärit ja villasukat jalkaan" ja takaisin
    "Asun omat kengät jalkaan" millä tahansa asulla paitsi hiihtohaalarilla (kuukengät). Kumisaappaat menevät edelle:
    jos ne ovat jalassa, ne riisutaan ensin eteisen matolle. Pelkkä ulkonäkö. Testi `--scene=slabarit`.
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
- **Saloisten kartta, kaikki kiinnostavat paikat:** paperikartalla (M) jokaisessa kylän julkisessa paikassa on pieni kynäympyrä, nimi näkyy hiiren
  alla ja klikkaus asettaa kompassin kohteen (`paper_map.gd _public_places`). Mukana ovat koulu, kenttä, seuraintalo, Reippari, SEO, uimaranta, katsastus,
  korjaamot ja säästöpiha sekä kirkko, kellotapuli, Pirtti (museo), koulukeskus, päiväkoti, kaukalo, ulkopingis, Lemmikki Enkelit, Kanttorila, Honganpalon kenttä,
  Arttim, Rudus, Heiskasen huolto, Huhtalan romuautot, Lapinraunio, raunio, Kertunkankaan röykkiöt, Heinimäki, Kiilinlammen grillikatos, Antinsuon laavu,
  kota ja lintutorni, Viitajärven laavu, Puntarimäki ja Kaitasaari. Salaiset (Sepon varasto, rossirata, tehtävien paikat) paljastuvat edelleen vasta kuulemalla.
- **Reppu:** 4 × 4 taskua (`inventory.gd`, 16); tavarat, eväät, lääkkeet, huumeet (myös jatketut annokset), klaffipöytä ja lääkelaukku ovat samassa ruudukossa. Klikkaus ottaa annoksen, T-valikko toimii ennallaan.
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
- **Legenda: Manamansalon muistokirkko (#250 P7, tarkistettava):** Oulujärven suurin saari Raahessa; sen sanotaan olleen metsästäjien hautausmaasaari ja
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
- **Saloisten koulukeskus, päiväkoti, kentät ja ulkopingis (#143):** keskustan koulukeskus ja päiväkoti (OSM-rakennukset)
  nimikylttineen, kaksi jalkapallokenttää rajaviivoineen ja maaleineen sekä koulun pihan ulkopingispöytä ("PIHAPINGIS").
  Pöydällä iltapäivisin ja iltaisin (14–21) E: haaste kylän nuorille samalla pingis_game.gd-minipelillä kuin Santun kanssa
  mökillä, mutta koulun pihalla ja heikommalla vastustajalla (taito 0,72 ja +0,06 jokaisesta voitosta, enintään 0,96).
  Voitto: nuoret tarjoavat limut, kerran päivässä maine +3, moraali ja stressi paranevat ("Setä on ihan ok"). Tappio: tarjoat
  limut (3 €), jos rahaa ei ole, maine −2 kerran päivässä. Päiväkodin toinen paikka px (585, 12) osuu leikkipaikkaan eikä
  omaan rakennukseen, joten kyltti on vain päiväkodilla px (725, 123). Ei vielä: Päivin työpaikka päiväkodissa eikä juniorien
  treenit. Testi `--scene=koulukeskus` (logiikka headlessinä, kuvat ikkunallisena).
- **Koulun disko** (`koulu_disko_game.gd`): perjantaisin 18–21 koulukeskuksen ovelta (kyltti "KOULUDISKO PE 18–21",
  muina aikoina ovessa lappu), kerran illassa. DJ on hukassa, ja pelaaja pyörittää kasetteja liikuntasalissa
  (parketti pelikenttäviivoineen, puolapuut, kori, patjat, serpentiinit, ilmapallot, KOULUDISKO-banderolli,
  peilipallo valotäplineen ja värivalot; DJ-pöydällä tuplakasettideki VU-mittareineen). 12 lasta tanssii tai
  seisoskelee seinustalla, opettaja valvoo. Lapset huutavat toiveita (tekno, dance, hidas), ja pelaaja valitsee
  kolmesta kasetista seuraavan (vasen/oikea) ja miksaa biisin saumassa (E, kun miksauspalkin neula on vihreällä).
  Tanssilattia: eniten toivottu +3, muu toivottu +1, toivomaton −1, polkka −3, kolmas samaa peräkkäin −1; sujuva
  miksaus +1, kesken biisin −1 (levyn raapaisu), hiljaisuus −2. Hitaalla lapset tanssivat pareittain. Opettaja
  toivoo kolmannessa biisissä kerran polkkaa: lapset voihkivat, mutta soitettu polkka antaa maineen +1 (soittamatta
  −1). Kuusi biisiä (20 s kukin); tulos keskimääräisestä täyttöasteesta: Diskon kuningas (8+, maine +4), Kelpo DJ
  (5+, +2), Kuin mummojen tanssit (2+, 0) tai Tyhjä lattia (−1). Kesken lähtö: maine −1. Sivutehtävä "Koulun DJ".
  Testi `--scene=koulu_disko`.
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
  päivän kyyti Raaheen on ilmainen. Simo korjaa sähköpyörän oikosulun ja lataa akun pakusta, Heiskaselta kaasupullo
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
  nähden, Päivi kuulee siitä aamulla. Iltapäivisin (12–17) Sinikka ottaa samalla rannalla aurinkoa selällään
  pyyhkeellä (aurinkolasit silmillä; lähestyessä lasit nousevat otsalle ja hän kääntää päänsä). Juttelu avaa
  kaksimielisiä repliikkejä (`ranta_flirtti.gd`, eivät toistu samalla kerralla) ja kolme vastausta: rasvan levitys
  (flirtti), vitsi tai torjunta. Vastaus nostaa moraalia, vireyttä tai stressiä kerran päivässä. Jos flirttaat perheiden
  nähden (15 m), perhe kertoo siitä Päiville noin joka toisella kerralla (arpa kerran päivässä), ja Päivi ottaa asian
  puheeksi aamulla. Pihalla Sinikkaa ei iltapäivällä näy. Testi `--scene=sinikkaranta`.
  Kun Sinikka on poissa, hänen ulko-ovessaan on teipattu käsinkirjoitettu lappu (aamulla uinti, iltapäivällä
  aurinko, kaksimielisesti ja päivän mukaan vaihtuen). E lukee lapun; ensimmäinen luku merkitsee Sinikan sydämen
  paperikartalle Oravajärven rannalle (M). Kuistin portaalla on pajukori: kun mustikkatehtävä on auki, E koriin jättää
  ämpäristä 2 l mustikoita (tehtävä sulkeutuu). Kun Sinikka on käynyt kotona ja olet ollut poissa kuistilta (yli 20 m),
  korin vieressä odottaa vadilla mustikkapiirakka; E ottaa sen (sama palkka kuin puheluovutuksessa, kerran
  päivässä). Kun korissa on marjoja tai piirakka odottaa, Sinikalta ei voi pyytää uutta tehtävää (`sinikan_kuisti.gd`).
  Testi `--scene=sinikanlappu`.
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
- **Muuta Raahessa ja kylällä:**
  - **Karaoke (Frets on Fire -näppäily):** Siitarin ja Kapteenin Kellarin karaokessa kappale valitaan ennen laulua (W/S ja E,
    tai hiirellä). Pelitapa on kuin Frets on Firessa: neljä nuottiraitaa (A S K L tai nuolinäppäimet) laskeutuvat perspektiivikaistaa
    osumalinjalle, ja nuotti painetaan tahtiin (täydellinen ±0,08 s, hyvä ±0,15 s, ok ±0,25 s). Pitkät nuotit pidetään pohjassa
    loppuun asti (bonus). Putki kasvattaa kerrointa (×1–×4), huti, väärä näppäys tai liian aikainen irrotus katkaisee sen, ja
    vasemmalla näkyy yleisömittari. Sanat ovat alhaalla, laulettava sana tai tavu hakasulkeissa. Kännissä nuotit nykivät ja
    painallukset viivästyvät. Tulos = osumien laatu ja pitojen bonus / täydet pisteet. Kappaleet: paikan oma ("Mopolla Raaheen",
    "Ruukin valot": sävelkorkeus määrää raidan, melodia syntetisoidaan ja osuma laulaa nuotin) tai **Normipäivä Saloisissa
    (lyhennetty aito versio)**: tunnari oikealla soittoraidalla (`assets/music/normipaiva_lyhyt.mp3`, laulu erotettu, n. 56 s:
    ensimmäinen verso ja kertosäe sekä loppukertosäe, ristiinhäivytetty) ja ajoitetuilla sanoilla
    (`assets/music/normipaiva_sanat_lyhyt.json`, 58 sanaa; raita arvotaan sanasta). Esc lopettaa. Testi `--scene=karaokeaito`
    (botti pelaa molemmat kappaleet, kuvat; ei `--headless`).
  - **Aukioloajat:** K-Marketit 7–21, Alkon hylly 9–18, Siitarin baari 11–02 (hotellin vastaanotto aina auki),
    Kapteenin Kulma 14–02 ja lavatanssit 20–01, pankkiautomaatti aina. Suljetulla ovella kerrotaan, milloin paikka
    aukeaa, ja taksi Raaheen ei lähde, jos baari on perillä kiinni. Sulkemisaikaan sisällä tulee valomerkki: kaupassa
    kauppias hoputtaa, ja baareista ja lavalta ohjataan ulos vartin päästä (`--scene=mokkiaukiolot`).
  - **Rönttönen (Kainuun rönttönen, `ronttonen_game.gd`):** mökin keittiössä piste "Leivo rönttösiä" (E). Kolme vaihetta hiirellä:
    kaulinta (vedä kaulinta hiiri pohjassa pystyyn ja vaakaan, taikinasoikio kasvaa), täyte (4 keko perunamuusia, sitten 3 lusikallista
    puolukkaa; muusi ensin) ja reunan nyppiminen (18 poimua klikkaamalla). Valmis rönttönen on avoin soikea: täyte näkyy ja reuna on
    poimuinen. Erä on 3 rönttöstä (reppuun enintään 6). Kun ne viedään kotiin, Päivi kattaa kahvipöydän (3D: liina, kahvipannu, kupit ja
    rönttöset lautasella) sille päivälle: mielihyvä +10 ja stressi alas (palkkio kerran päivässä, loput rönttöset säilyvät).
    Humalassa kursori huojuu. Testi `--scene=ronttonen`.
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
  repeämät, vyö, nokiset tahrat iholla ja tuprukka vaalea tukka, viitteenä Uuno kyntämässä; `character.gdshader` net_shirt, grime), Raahen makuuhuoneen kaapista työhousuihin, flanelliin ja Karjala-lippikseen. Kodin
  kaapista saa myös Stetson-cowboyhatun lippiksen tilalle (ruskea huopa, keskiura, kaareva lieri, nauha ja hopeinen
  koristelaatta); se pysyy päässä asusta riippumatta, kunnes lippis vaihdetaan takaisin. Kirppikseltä ostettu
  hiihtohaalari tulee kodin kaappiin neljänneksi asuksi. Pentin kiertueen jälkeen aamulla kassissa on Pentin nahkaliivi
  lapun kanssa ("Pidä tää. Sää oot nyt kiertuemiehiä."), ja se tulee kodin kaappiin asuksi **Nahkaliivi ja farkut**:
  avonainen ruskea nahkaliivi paljaan karvaisen rinnan päällä, farkut mustalla vyöllä ja cowboybootsit, kuten Pentillä
  mutta ilman viiksiä ja ketjua (`looks.gd OUTFITS`, main.gd has_liivi). Kaikki asut rinnakkain:
  `tools/testit/aja.sh tscn tools/testit/pelaaja_asut.tscn`. Ensimmäisestä kaupasta ostetusta kutosesta (K-Market,
  Raahen K-Market tai kauppa-auto, ei juoksukaljoista) jää Karhu-kutosen pahvikoppa, ja pää pujotetaan heti sen sivun
  aukosta: koppa seisoo pystyssä päässä, edessä kansi pullonkaulojen rei'illä, sivuilla tuima karhu kyljellään
  päälaki eteenpäin ja takana pohja. Alareuna sovitetaan pään muotoon (ylimäärä pullistuu eteen ja taakse). Painatus on oma
  piirros (`tools/karhu_koppa.gd` -> `assets/karhu_koppa.png`). Koppa vaihdetaan kodin kaapilla, ja Päivi
  ihmettelee sitä kotiovella. Asu ja hattu vaihtuvat
  kaikkiin pelaajan malleihin paikallaan (pyörä, kävely, mopo, sisätilat) ja säilyvät tallennuksessa. Vaatteet
  piirretään varjostimessa pikseleinä (`shaders/character.gdshader`), asusteet ovat muutama pieni mesh luissa
  (`looks.gd`, testit `--scene=asut`, `--scene=vaatekaappi`, `--scene=stetson`, `--scene=haalari` ja `--scene=koppa`).
  Aikuisilla hahmoilla on nännit: nännipiha ja oikeasti pinnasta kohoava nuppi (tiheä pintapala vartalon verkon päällä,
  `character.gd _nipple_patch`). Naisella ne ovat rinnan etupinnan keskellä, miehellä rintalihaksen alareunassa, ja
  nännipiha pysyy pyöreänä rinnan muotoilusta huolimatta. Näkyvät paljaalla rinnalla (sauna, bikinit ilman yläosaa,
  verkkopaidan silmukat, avoin liivi), ja kohouma erottuu myös ohuen ja tiukan kankaan läpi (bikinit, tuubitoppi;
  `nipple_cloth`). Lapsilla ja nuorilla niitä ei ole (pituus alle 1,5 m tai lookin `nipples: false`).
- **Kengät (#272, #274):** jokaisella hahmolla on oma kenkätyyppi (`look.shoe`; `Shoes.type_for` käyttää `shoes`-väriä vain varalla).
  Pelaajalla tuulipuvussa lenkkarit, farkuissa ja työvaatteissa työkengät ja hiihtohaalarissa kuukengät; saunassa ja uidessa
  paljain jaloin. Kirppikseltä ostetut släbärit ja villasukat korvaavat asun kengät vaatekaapista (ks. kirppis). **Kumisaappaat (#274):** kodin eteisessä (makuuhuoneen oven ja etuseinän välissä) ja mökin päätyseinällä punaisen uunin vieressä on
  vihreä saapaspari vaalealla kuramatolla. Ne ovat periaatteessa yhdet saappaat: kun ne ottaa kummasta tahansa paikasta,
  ne katoavat molemmilta matoilta, ja ne voi palauttaa kummalle tahansa. E avaa valikon: matolta jalkaan tai reppuun,
  jalasta matolle tai reppuun ja repusta jalkaan tai matolle. Repussa kulkevat saappaat vaihtuvat jalkaan missä tahansa
  repusta (I) tai T-valikosta, ja riisutut menevät takaisin reppuun, joten omat kengät saa aina takaisin. Ne pysyvät jalassa
  paikasta toiseen ja tallentuvat (`pelaaja/saappaat`, `pelaaja/saappaat_repussa`), eikä paikka vaihda kenkiä itsestään.
  Hiihtohaalari pitää aina kuukengät. **Tanssijat:** Hilkka ja Anna-Liisa kävelykengät, seuraintalon Sinikka punaiset
  sandaalit. **Sivuhahmot:** kenkä sopii henkilöön (mummot kävelykenkä, työmiehet työkenkä, nuoret lenkkari, virkailijat ja
  tarjoilijat nauhakenkä, naisilla osalla sandaali, kodassa ja metsäretkillä kumisaapas). Satunnaisissa joukoissa (lavan yleisö,
  tanssiparit) kenkä arvotaan iän ja sukupuolen mukaan (`Shoes.random_type`: vanhat kävelykenkä, naisista 40 % sandaali muut lenkkari,
  aikuisista miehistä 40 % työkenkä muut lenkkari, nuoret lenkkari), deterministisesti samasta siemenestä. Santulla ja
  Hanhikiven kalastajalla kumisaappaat (#273). (`scripts/shoes.gd`, `scripts/kumisaappaat.gd`, ks. `docs/kehitys.md` Kengät.)
  Testit `--scene=saappaat` ja `tools/testit/kengat.tscn`.
- **Päivin vanha kännykkä (P soimaan / taskuun, N seuraava, U voimakkuus):** kodin makuuhuoneen yöpöydällä
  parisängyn vieressä. Soittaa vanhoja iskelmiä 78 kierroksen levyiltä (`assets/music/iskelma/`, sama lista kuin
  lavabändillä) pienestä kaiuttimesta: oma ääniväylä kaistanpäästöllä ja säröllä, joten ääni on ohut kuin taskusta.
  Soidessa puhelin näkyy minikartan vieressä: näytöllä juokseva biisin nimi, esittäjä, aika, taajuuspalkit ja
  voimakkuus, ja kaiuttimesta nousee nuotteja. Soittolistalla ovat myös Saloisten Saapasjalkojen biisit (Pihalla
  tavataan, Rasvanappi ja Normipäivä). Kuulokkeet ja pelin oma musiikki tauottavat puhelimen. Kansioon
  lisätyt biisit (esim. Eräät Jormat Suno-soittolistalta, ks. LUEMINUT.txt) soivat myös. Löytö ja voimakkuus
  säilyvät (testi `--scene=puhelin`).
- **Vaarat:** Päivin Hyundai, juntti, laavun valtaajat ja jyväjemmari traktorilla, jos ajat viljapellolle.
  Päivin Hyundai on punainen Pony 2 -viistoperä (5-ovinen, Giugiaro), oma malli `vehicles.gd pony()` (viistetyt korin reunat, pyöreät pyöränkaaret, läpinäkyvät lasit ja sisusta: selkänojat niskatukineen, kojelauta ja ratti); muut autot ovat `car()`.
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

## Maiseman täyttö: talot (K1–K8)

Saloisten ja Raahen nimettömät OSM-rakennukset saavat oman mallin (`scripts/rakennukset.gd`), jonka tyypin, värit ja mitat
valitsee `scripts/taytto.gd` pohjasta. Täyttö on vain Saloisissa (`world.gd _build_houses`) ja Raahessa (`vaala.gd`), ei Raahessa:
Wanha Raahe -retken talot ovat ennallaan. Keltainen Raahen puutalo (K5) esiintyy silti pienenä osuutena kummassakin kylässä.

- **K1** rintamamiestalo (1½ krs, avoräystäät) | **K2** matala omakotitalo (70-80-luku, osa tasakattoisia, peiterima- tai tiilenvärinen)
  | **K3** aitta, myös rantamökki (suurennettu) | **K4** lato | **K5** Raahen vanha puutalo (aita, kun tietä on)
  | **K6** rivitalo (asuntomoduuli toistuu, oma ovi ja katos asuntoa kohden) | **K7** kerrostalo (2-3 krs, parvekkeet, liikevariantti)
  | **K8** halli: kone, teollisuus, liike tai suoja (neljä varianttia).
- **Tyypitys** (`Taytto.classify`, ensimmäinen osuva sääntö): OSM-tyyppi (`t`), pohjan pinta-ala, kerrosluku (`lv`), pellon ja tien
  läheisyys. Pieni pohja (alle 45 m²) on K3, pellolla K4; ladot ja varastot K4 tai K8 koon mukaan; apartments ja usean kerroksen
  isot pohjat K7; terrace/semidetached tai pitkä kapea iso pohja K6; iso teollisuus- ja liikepohja K8; muut isot asuinpohjat jaetaan.
- **Jako:** pohja, joka on 260 m² tai isompi eikä sovi K6-K8:aan, jaetaan enintään 3 taloon pitkää akselia pitkin (väli vähintään
  5 m, talo vähintään 9 m). Jaetuissa taloissa on pieni heitto kulmassa ja paikassa, ja vierekkäisillä eri tyyppi tai väri.
- **Pysyy vanhana mallina:** koulu, päiväkoti, kirjasto, hotelli, sairaala, julkiset rakennukset ja kirkko (`Taytto.keep_old`),
  yli 3 kerroksiset, L- ja U-muotoiset pohjat (pohjan ala alle 0,75 suunnatusta laatikosta ja ala vähintään 260 m²), nimetyt
  kohteet ja omat mallit (`OWN_BUILDINGS`), Saloisten `FILL_KEEP`-lista sekä Raahessa Katjan talo (`KATJA_ID`) ja muut tunnetut
  kohteet. Katjan oven `house_doors`-pituus pysyy 25,4 m:ssä, joten Katja pysyy pisimmän ovipituuden kohteena.
- **Sokkeli:** rinteessä K8:n rungon alla korkeusero saa olla enintään 1,5 m (`FILL_DROP_MAX`): halli lyhennetään, ja jos ei vielä
  riitä, ylärinteen puoli uppoaa maahan.

## Pullonkorkit (#290)

- Jokaisesta juodusta kaljasta jää korkki (`korkit.gd`, `main.gd _korkki`). Merkit ovat parodioita: Kontio, Lapin Kuuma ja
  Koffi (kalja) sekä Jaffis, Kolaa ja Pantteri-limu (limu). Tasot: tavallinen, kesäkorkki (n. 1/15) ja virhepainos
  (n. 1/150). Ensimmäinen korkki aloittaa kansion, ja uusi harvinainen kerrotaan. Päiväkirjan tehtävä "Korkkikansio"
  (kansiossa X / 18, tuplia). Tallennus `[korkit]`. Testi `scene korkit` (kuva kansiosta).
- **Korkkikansio:** päiväkirjan Korkit-välilehti (5): vasemmalla kaljat, oikealla limut, merkin rivillä tavallinen,
  kesäkorkki (aurinkorengas) ja virhepainos (logo ylösalaisin, väärä väri). Puuttuva: katkoviiva ja vihje. Täysi
  merkki palkitaan kerran (moraali, maine +2, tähti).
- **Limukorkit ja muut lähteet:** pullonkeräyksestä (Raahe) jää talteen 1–3 korkkia, kaljoja ja limuja. Kirppiksellä
  Veksin korkkilaatikosta saa satunnaisen korkin 0,10 €:lla (kun kansio on aloitettu). Pelissä ei juoda limua, joten
  limukorkit tulevat näistä.
- **Korkki-Raimo** (kirppiksen salissa, keltainen paita): vaihtaa kaksi tuplaa puuttuvaan korkkiin (ei virhepainoksia),
  ostaa tupla-virhepainoksen 15 €:lla (kansion korkkeja ei koskaan viedä) ja kertoo kultaisen MM-korkin legendan
  (`mmkorkki_legenda`). Testi `scene korkit` (vaihto, kuva Raimosta).
- **Legenda: kultainen MM-korkki (1995):** Korkki-Raimo kertoo juhlaerästä. Pekalta kysytään ("Joitko sää
  kultakorkkisen kaljan?"): hän heitti korkin saunan jälkeen talonsa päädyn kivikkoon (`neighbor_yards.pekka[3]`).
  Siellä [E] nostaa korkin kerran: maine +3, kansion kansilehteen kultainen korkki. Raimo ostaa sen 200 €:lla, jos
  haluaa. Päiväkirjassa "Kultainen MM-korkki" (karttalinkki Pekan pihaan, kun Pekka on kertonut).
- **Korkkiläpsy** (`korkki_game.gd`): pelataan pelimaailmassa 3D:nä Raahen lavan pihalla teinien vieressä illalla
  18–23 kerran päivässä (kansio aloitettu, 3 tuplaa). Pino oikeita 3D-korkkeja (rihlattu kylki, kannessa kansion logo
  tekstuurina, nurjalla puolella tiiviste), vastassa teini Jere kyykyssä ja pelaajan oma hahmo pinon vieressä
  (Looks-hahmot), tinanappi-lyöjä. Kamera rajataan laskemalla (pino alakolmannekseen, Jeren pää yläosaan). Tähtäys A/D
  tai hiiri, voima ajoituksella; kääntyneet korkit lentävät pyörien lyöjän eteen, liian kova lyönti lennättää ne
  maahan. Ruudun päällä voimamittari, tilanne ja näppäinhatut asetusten näppäimistä. Testi `scene korkit` (Raahe ladataan,
  kuvat tähtäyksestä ja lyönnistä).
- **Juhannuskorkit** (ennen kesäkorkki) arpoutuvat vain juhannuksena (`_juhannus()`); muulloin arpa antaa tavallisen.
- **Voittokorkki:** joka 25. kaljakorkin alla lukee "VOITIT PULLON", ja kassalla se vaihdetaan: kalja +1.
- **Korkkiläpsy myös Saloisten kaukalolla** iltateinien vieressä (kaukalon teinien valinta, sama kerran päivässä).
- **Kiiltävät korkit maastosta:** uimarannan penkin vierestä, Antinsuon laavulta ja Viitajärven laavulta "[E] Jokin
  kiiltää maassa", kerran päivässä paikkaa kohden.
- **Tuplat omalta kirppispöydältä:** kun pöytä on vuokrattu, Hilkan valinnoissa "Myy tuplakorkit" (0,10 €/kpl).
- **Korkki-Raimo** on kirppiksellä vain lauantaisin. **Kansio kotijemmaan:** Korkit-välilehden linkki piilottaa kansion,
  jolloin Päivi ei näe sitä. **MM-korkin lappu:** kun legenda on kuultu, korkkilaatikon pohjalta löytyy Raimon lappu
  ("KYSY PEKALTA"). Ensimmäinen kampanjakorkki voi olla "UUSI YRITYS".
- **Päivi ja kansio:** kotiin tullessa kerran päivässä, jos kansiossa on kuusi tai enemmän kaljakorkkia, Päivi laskee ne
  ääneen ("Montako kaljaa tässä kansiossa on, häh?"); moraali laskee kaljakorkkien suhteessa limukorkkeihin.
  kultainen MM-korkki.

## Normipäiväkirja: tarina, tehtävät, onnelliset loput ja legendaariset hetket (O)

- **Tarina** etenee luvuittain: 1. Raaheen pääsee, kunhan… (naapurien hommat ja Pekan kyyti mökille), 2. Raahen
  isäntä (Santun hommat ja savusaunan korjaus), 3. Mopolla Raaheen (Siitari, Oulujärven lava, kiihdytys), 4. Junalla
  kotiin ja 5. Kylän salaisuudet (Seuranmäen kirppis, Tokolan varasto ja aarre, Vanhan Sulon pannu, Lapinraunion aarnivalkea, Kertunkankaan rauta, Tekojärven Ukko) sekä rinnakkainen 6. Päivi epäilee (aikuisille, ks. yllä). Seuraavaan
  vaiheeseen vihjataan puheissa: Santtu, Siitarin baarimikko, aidan takana porukka, Gasthausin emäntä, Pekka
  ja Tauno kertovat, mitä seuraavaksi.
- **Sivutehtävät**: kauppalista, nurmikko, laavu, Väinö, jalkapallopojat, pontikka, ilmakuvat, kotiviini,
  sähköpyörä, huutokauppa, tanssit ja bingo, Teron kädenvääntö, Santun viisi tähteä, viina- ja rahakätköt,
  eräjorma, pihapingis ja pummilla lavalle. Retkien legendat (tietokonemuseon Pong, Wanhan Raahen kierros, kuvakirkon
  piilokuvat, kapteenin taskukello, Kuhmon karhukuva, Hiidenportti, Pyhäkosken tarinat, Kajaanin linna ja Raatteen
  Portti, Kalajoen rantafutis) tulevat tiedoksi perillä ensimmäisestä kohdasta, edistyminen otsikon perässä (esim. tarinat 1 / 3).
  Lisäksi Teeriniemen kalalampi (saalis), Kapteenin Kulman pubivisa (kaikki oikein), ponkkarin uimakisa (voitto),
  Valentin Raahen elokuvapäivät (Veturitallin ovelta) ja Hanttihommat (keikkatyö, kesäduuni, työkkäri, pullonkeräys ja
  kioskihengailu, kokeiltu X / 5) ja Kylän tekemisiä (juoksulenkki, lintutorni, rönttöset, hedelmäpeli, pajatso,
  muskelivene ja juhannuskokko, kokeiltu X / 7). Salaiset (Rasvanappi, rakaleiman kopio, Nyrkit puhuu: tappelun voitto) tulevat
  päiväkirjaan vasta, kun ne on kerran tehty.
- **→ näytä kartalla** tehtävän alla asettaa kompassin (lyijykynärengas kartalla). Toisten paikkakuntien tehtävät
  (Raahe, Hanhikivi, Pakkahuone, Peruskivi, Manamansalo ja retkien legendat) osoittavat K-Marketin taksitolpalle,
  eikä niille piirretä omaa rengasta. Linkitöntä tehtävää ei voi näyttää: kohde liikkuu (Väinö, pallo, Pentti) tai se
  on mökillä tai Raahessa, joka ei ole Saloisten kartalla.
- **Jemmat**-välilehti: kaikki löydetyt jemmapaikat täyttöpalkkeineen (kaljat / tila), kotijemma tavoitteeseen
  nähden tölkkiriveinä, ulkojemmat ja yhteensä sekä riskit: Päivi voi löytää liian täyden
  kotijemman, ja teinit voivat pölliä ulkojemmasta. Reppu (I) näyttää myös tyhjät löydetyt jemmat. Testi `--scene=jemmat`.
- **Päiväkirja (O)** ei paljasta mitään etukäteen: luku näkyy, kun siihen päästään, vaihe, kun siitä on kuultu, ja
  sivutehtävä, kun siitä on kerrottu. Uusista vihjeistä tulee ilmoitus "Päiväkirjaan tuli uutta".
- **Onnelliset loput** (päivä päättyy loppukohtaukseen): juhlat autotallissa, viinibileet, laavulla kaljoilla,
  legendaarinen normipäivä, mökkibileet, erämaan laavu (Viitajärven laavu auringonlaskussa), Kymppiuutiset nauhalta
  (video ajastetaan olohuoneessa ennen klo 22, ja klo 22.25 jälkeen sohvalle eteisen kaapin kaljan kanssa), Mirkun
  teltassa sekä kolmiomittaus Saloisissa ja Raahessa. Ilmoitus "ONNELLINEN LOPPU".
- **Legendaariset hetket** (saavutukset, peli jatkuu): Raaheen Pekan kyydillä, savusaunan löylyt, Pentin ensimmäinen kyyti, lavatanssit,
  karaokekuningas, kiihdytyksen voittaja, sähköpyörä, seuraintalon tanssit, bingon jättipotti, lihapiirakkakuningas,
  Drakkar Noir ja legendat (Tokolan aarre, Vanhan Sulon pannu, viimeisen sepän kirves, Isonvihan hopeat, Tekojärven
  Ukko, Ukko vapaaksi). Ilmoitus "LEGENDAARINEN HETKI".
- **Lavastetut hetket** (`endings.gd STAGED`) koetaan kohtauksina, ja niihin päädytään tarinan kautta. Niistä ei tule
  ilmoitusta, vaan kohtauksen jälkeen rivi "Päiväkirjaan uusi tarina". Kohtaus nähdään vain ensimmäisellä kerralla.
  Toistot lasketaan päiväkirjaan, ja hahmo muistelee ensimmäistä kertaa. Hetki on Pentin ensimmäinen kyyti
  (`rikos/pentti.gd`, `cutscene.gd pentti_ride`; testi `--scene=pentti_eka`).
- Päiväkirjan Loput-välilehdellä onnelliset loput vasemmalla (X / 10, kerrat yhteensä; matalat kortit tiiviinä riveinä) ja legendaariset hetket oikealla
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
  Hyundailla perään. Testi `--scene=turvapaikat`. Lisäksi kotitöiden ajan: oman nurmikon leikkuu (40 m leikkurista)
  ja pensasaidan leikkuu (40 m aidan luota, Päivi vahtii itse narun vieressä; leikkuun jälkeen 15 s aikaa lähteä,
  testi `--scene=pensasaita`). Häviö tai uusi päivä kesken leikkuun lopettaa minipelin (`main.gd _abort_hedge`).
  Trimmeri haukkaa latvasta enintään 22 cm kerrallaan: liian syvä veto pitkään kasvuun ei leikkaa, vaan kone pykii
  ja nykii, ja ruudulle tulee vinkki leikata ylempää pala kerrallaan (`hedge_game.gd _deep_tick`).
- Esc avaa valikon: asetukset (grafiikan laatu, koko näyttö, V-Sync, renderöintiskaala, FOV, FPS-näyttö,
  leijuvat opasteet eli paikkojen ja hahmojen nimet (oletuksena pois), äänenvoimakkuudet, hiiren herkkyys, käänteinen Y, kameran automaattikeskitys), ohjaimet ja tekijät.
