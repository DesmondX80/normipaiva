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
