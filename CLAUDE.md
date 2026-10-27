# Normipäivä: ohjeet Claudelle

## Dokumentaatio

README on lyhyt esittely. Pelin sisältö (kaikki paikat, tehtävät ja legendat) on tiedostossa `docs/pelin-sisalto.md`,
päivän tilat `docs/tilat.md`, ohjaus `docs/ohjaus.md`, kehitys ja testikohtaukset `docs/kehitys.md` ja lisenssit
`docs/tekijanoikeudet.md`. Uusi ominaisuus kuvataan `docs/`-tiedostoon; README:hen korkeintaan rivi.

## Skriptien lataus

Ei `class_name`-luokkia: skriptit ladataan `preload`:lla (`const MeshBundle := preload("res://scripts/mesh_bundle.gd")`).
`class_name` vaatii editorin luokkalistan (`.godot/`, ei gitissä), joten suoraan ajettuna (`godot ./`) peli ei käänny.

## Minipelien grafiikka

Minipeleihin (CanvasLayer-piirretyt kuten `carb_game.gd`, `saunakorjaus_game.gd`, `ebike_game.gd`,
`auction_game.gd`) tehdään kunnolliset grafiikat, ei pelkkiä värilaatikoita ja ympyröitä:

- Esineet piirretään tunnistettaviksi: muodot, sävytys (vaalea yläreuna, tumma alareuna), ääriviivat, varjot ja
  yksityiskohdat (ruuvin ura, teipin kuitu, puun syyt, metallin kiilto).
- Tausta on oikea paikka (työpöytä, lava, sali), ei yksivärinen laatikko.
- Hahmot ovat hahmoja (pää, hiukset, vartalo, kädet), eivät ympyröitä suorakaiteiden päällä.
- Toiminnalle on palaute: animaatio, hiukkaset tai roiskeet, tärähdys ja ääni.
- Tyyli on yhtenäinen pelin muiden minipelien kanssa: lämmin, hieman sarjakuvamainen, selkeät värit.
- Ota kuva testikohtauksesta ja katso se ennen kuin työ on valmis.

## Kyltit

Seinillä, ovissa, lavoilla ja rakennuksissa olevat tekstit ovat kylttejä: taustalevy ja reunus (`B.sign_plate`) tai
banderolli kankaana, ei irrallisia Label3D-tekstejä seinän pinnassa tai ilmassa. Irrallinen Label3D sopii vain
puhekupliin, nimiin ja pelin ohjeteksteihin (esim. "ULOS"-merkki lattiassa).

## 3D-esineet ja visuaalinen työ

- **Hae oikea esikuva ennen mallinnusta.** Kysy kuva tai kuvaus, jos et tiedä varmasti, miltä esine näyttää
  (esim. lihapiirakka: uppopaistettu, halkaistu kuin simpukka, puoliskot kiinni takareunasta). Vertaa malliin.
- **Esine, joka syödään, rikotaan tai leikataan, rakennetaan umpinaisista paloista**, joista jokaisella on oma
  päätypinta (kuten nakki lieriöistä). Älä leikkaa onttoa kuorta varjostimella: leikkauksesta näkyy ontto sisus,
  ja sen paikkaaminen on hankalaa.
- **Kuvaa kaikki tilat, älä vain yhtä.** Kun esine muuttuu (haukut, vauhti, rikkoutuminen), ota kuva jokaisesta
  vaiheesta ja kokoa ne yhdeksi vertailukuvaksi. Rajaa ja suurenna pieniä esineitä: virheet eivät näy kokonaisesta
  ruudusta.
- **Tunnista ennen kuin korjaat.** Jos kuvassa on jotain outoa, värjää epäillyt osat hetkeksi selvillä väreillä
  (magenta, syaani, vihreä) ja katso, mikä osa se on.
- **Kolmas korjaus samaan ongelmaan = vaihda lähestymistapaa.** Jos paikkaus tuo aina uuden virheen, yksinkertaista
  (esim. suora leikkaus kaarevan sijaan) tai rakenna toisin. Älä kasaa korjauksia korjausten päälle.
- **Sisällöt sovitetaan säiliöön laskemalla**, ei kiinteillä koordinaateilla (esim. täytteiden korkeus kannen
  alapinnan alle sen kulman mukaan), muuten ne pistävät läpi, kun säiliötä säädetään.
- **Älä sano "toimii", ennen kuin olet katsonut suurennettua kuvaa.** Kerro rehellisesti, mikä on vielä huonosti.
- Tekniset sudenkuopat: SurfaceTool-pistevärit tarvitsevat `vertex_color_is_srgb = true`, ja peilatussa
  geometriassa kolmioiden kiertosuunta kääntyy (valitse se normaalin mukaan).

## Hahmojen asennot ja kalusteet

Toistuvia virheitä: jalat solmussa, sormet ja ranteet väännetty, raajat kulkevat kappaleiden läpi, hahmo istuu 180°
väärään suuntaan ja kalusteen osat (penkin tolpat ja rimat) osoittavat eri suuntiin.

- **Vasen ja oikea ovat peilikuvia.** Kämmenen tai jalkaterän asento lasketaan yhteisellä apufunktiolla
  (`pose.gd palm_down`/`palm_on`, parametri `left`: vasen kierretään sormiakselin ympäri 180°), ei omalla kannalla.
  Sormet osoittavat kyynärvarren jatkeena, eivät kyynärpäätä kohti.
- **Raaja, joka nojaa johonkin (vatsa, reisi, penkki), sovitetaan pintaan laskemalla** paistetusta verkosta
  (`pose.gd limb_points`, `top_y`): nivelet olkavarren ja kyynärvarren mitan päähän ja hihan paksuuden verran
  pinnan yläpuolelle (esim. `janttu.gd _place_props`). IK:n pole on vain vihje, ei takuu siitä, ettei raaja mene läpi.
  Tarkista rako numeroina pitkin raajaa (luun korkeus vs. pinta), ennen kuin otat kuvia.
- **Kallistukset ja suunnat johdetaan yhdestä vektorista.** Kalusteen kaikki kallistuvat osat lasketaan samasta
  kallistuksesta (`janttu.gd _build_bench`: tolpat ja rimat), ei erikseen arvatuilla etumerkeillä. Hahmon suunta
  otetaan istuimen tai sängyn etusuunnasta; kirjaa koodiin, mikä akseli on etu (esim. "-Z = penkin etupuoli").
- **Asetelmasta kuvat edestä, päädystä ja ylhäältä.** Päätykuva paljastaa kallistusten etumerkit ja ylhäältä näkyvät
  jalkojen risteys ja istumissuunta. Läpimeno, väännetty ranne tai väärä suunta on aina FAIL.
- **Kiinteät esineet eivät mene toistensa sisään**: vartalo ei pöytään, jalkaterä ei portaaseen, lattiaan tai maahan,
  sääri ei tukkiin, käsi ei vartaloon eikä hahmo toiseen hahmoon. Ennen kuin asetelma on valmis, aja automaattinen
  läpimenotarkistus (`tools/testit/asento.gd Asento.solids`, osana `--scene=asennot`); yksikin läpimeno on vika.
  Poikkeus: tarkoituksellinen sisäkkäisyys on sallittu (pää painuu pehmeään kassiin tai tyynyyn): merkitse pehmeä osa
  `set_meta("pehmea", true)` ja kirjaa koodiin, miksi.
- **Mittaa pinnasta, ei luista.** Jalkapohjan, käden ja vartalon etäisyys pintaan mitataan paistetun verkon pisteistä
  (`pose.gd limb_points`): nilkkaluu voi olla pinnan yllä, vaikka jalkaterän etuosa on pinnan sisällä.
