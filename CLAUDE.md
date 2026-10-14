# Normipäivä: ohjeet Claudelle

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
