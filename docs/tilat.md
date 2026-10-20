# Päivittäiset tilat


Joka aamu arvotaan kolme tilaa kymmenestä, ja ne näkyvät HUD:n oikeassa yläkulmassa palkkeina (-1…+1, nolla
keskellä: punainen vasemmalle, vihreä oikealle). Kaikissa tiloissa **suurempi on parempi**: stressi, nälkä,
väsymys ja kipu alkavat -1:stä, ja niitä yritetään nostaa; muut alkavat 0:sta. Humalatila (0…1) säilyy yön yli
ja laskee yössä 0,2. Muut nollautuvat joka aamu.

Jokaisella tilalla on oma palkinto ja haitta, jotka ovat päällä heti, kun palkki ylittää rajan (**+0,5** tai
**−0,5**; humalatila 0,3–0,6 tai yli 0,8), ja lakkaavat, kun arvo palaa rajojen väliin. Vain päivän kolme tilaa
vaikuttavat; poikkeuksena humalan ohjaushaitta, joka on aina päällä kuten mopolla. Eilinen päivä ei vaikuta tähän päivään, paitsi humala: jos illalla humala on yli 0,8, tulee
**krapula-aamu** (vireys ja keskittyminen alkavat −0,3:sta). Aamun viesti kertoo tämän päivän tilat.

| Tila | Palkinto (≥ +0,5) | Haitta (≤ −0,5) |
|---|---|---|
| Stressi | mummot suuttuvat hitaammin | Päivi ajaa 10 % nopeammin |
| Nälkä | kävely, juoksu ja pyöräily +10 % | kävely, juoksu ja pyöräily −10 % |
| Väsymys | juoksu ja spurtti kuluttavat kuntoa 30 % hitaammin | kunto palautuu puolet hitaammin |
| Kipu | tappelussa 120 hp (tilanne ennen tappelun iskuja) | juoksu −15 %, hyppy matalampi |
| Stamina | pyörän spurtti rajumpi (1,4 → 1,6) | juoksu ja spurtti eivät toimi |
| Vireys | tutka näkee kauemmas (320 → 450 m) | usva tihenee, näkyvyys puolittuu |
| Moraali | K-Marketin kassa −10 % | K-Marketin kassa +10 % |
| Keskittyminen | repun kauppalistassa näkyy ensimmäisen tuotteen väri | viimeinen tuote unohtuu listasta (???) |
| Kokemus | minipeleissä vakaampi käsi (humalan huojunta −0,15) | minipeleissä huojuntaa +0,15 |
| Humala | 0,3–0,6: tappelussa iskut +20 % | yli 0,8: pyörän ja kävelyn ohjaus heittelee |

Toimintojen vaikutukset tiloihin:

| Toiminto | Vaikutus |
|---|---|
| Aika ulkona | nälkä −, kipu + (hellittää), humala − |
| Liikkuminen | nälkä − (enemmän kuin paikallaan) |
| Sprintti (juoksu, pyörän spurtti) | väsymys −, stamina − |
| Tauko (paikallaan yli 3 s) | väsymys +, stamina + |
| Paikallaan yli 10 s | kokemus − |
| Nuotio laavulla, tuli kodassa, grillikatos (paikallaan) | stressi ++, vireys + |
| Luonnossa paikallaan (metsä, niitty, räme) | vireys + |
| Selvin päin / humala yli 0,5 | vireys + / vireys − |
| Nälkä tai väsymys alle −0,5 | vireys − |
| Nälkä ja väsymys molemmat päivän tiloissa ja alle −0,5 | stamina − |
| Stressi alle −0,5 | keskittyminen − |
| Humala yli 0,7 | kokemus + |
| Jahti (Päivi, juntti, poliisi) | stressi − |
| Kalja (laavu, leikkurin korjaus, Raahe 3, autotallin juhlat 6) | humala +, kipu +, stamina +, nälkä +, moraali −, keskittyminen − |
| Syöminen (paistettu makkara, kettukarkki) | nälkä +, stamina + |
| Kalja T:llä (yksi kannossa olevista) | kuten kalja yllä |
| Syöminen T:llä: korvapuusti / lihapiirakka | nälkä +0,25 ja stressi + / nälkä +0,4 (ja stamina puolet nälän muutoksesta) |
| Syöminen T:llä: suklaa / marjat (1 l) | nälkä +0,2, stressi +, moraali + / nälkä +0,15, vireys + |
| Syöminen T:llä: savukala / savuriista / karrella | nälkä +0,5, stressi +, moraali + / nälkä +0,6, stressi +, moraali + / nälkä +0,25 |
| Tappelu | stressi −, kipu −−, stamina −, moraali −, nälkä − |
| Koiran purema / kettukarkin osuma | kipu −− / kipu − |
| Haavan hoito (Pekka, Päivi) | kipu ++ |
| Kotiinpaluu, laavuloppu | moraali +, stressi + |
| Sivutehtävä (Väinö, nurmikko, kauppalista oikein) | moraali +, stressi +, keskittyminen ++ |
| Kauppalista väärin tai kotiin ilman Päivin ostoksia | stressi −, moraali − |
| Jalkapallo pojille | moraali +0,1…0,5, kokemus +0,4…0,6 ensimmäisellä kerralla, muuten +0,1…0,3 |
| Kalja pojille / pojan kivi osuu | moraali − / kipu − |
| Kodan tarina | stressi + |
| Nuotion tai kodan tulen sytytys | stressi + |
| Lintujen katselu tornista (kerran päivässä) | vireys +, stressi + |
| Sahaus ja halkominen (per pölkky) | stamina −, väsymys −, stressi + |
| Marjojen tai sienten poiminta | väsymys −, stamina −, vireys + |
| Nurmikon leikkuu (leikatessa) | väsymys −, nälkä − |
| Siili leikkurin alle | moraali −−, stressi − |
| Leikkuri hajoaa, teinit vievät pyörän | stressi − |
| Päivi löytää jemman | stressi −−, moraali − |
| Suklaa lepyttää Päivin | stressi + |
| Mummot suuttuvat | moraali − |
| Tappelun voitto | moraali +, kokemus + (tappelun miinusten päälle) |
| Kädenvääntö Raahessa: voitto / häviö | moraali + / moraali − |
| Marjojen tai sienten myynti | moraali + |
| Mökki: savusauna / palju (kerran päivässä) | stressi ++, väsymys ++, kipu +, vireys + / stressi ++, kipu +, stamina + |
| Mökki: kala laiturilta / tikan täysosuma (kerran päivässä) | moraali +, stressi + / moraali +, keskittyminen + |
| Mökki: metsästys saaliin kanssa / hirvi ammuttu | moraali + (0,05 per saalis), stressi + / moraali −−, stressi −− |
| Mökki: savustus valmis | stressi + |
| Mökki: pihapingis | stamina −, nälkä −; kerran päivässä voitto: moraali +, keskittyminen +, stressi + / häviö: stressi +, moraali − |
| Mökin piha (paikallaan) | kuten nuotio: stressi ++, vireys + |
| Mökki: kiukaan tai paljun kamiinan sytytys (kerran päivässä kumpikin) | stressi + |
| Mökki: Santun homma tehty / kaikki hommat tehty | moraali +, stressi + / moraali ++, stressi + |
| Mökki: peukaloon vasaralla / ampiaisen pisto / tikkailta putoaminen | kipu − / kipu − / kipu −−, stressi − |
| Mökki: sanko läikkyi / häkää savusaunassa | stressi −, moraali − / kipu −, vireys −, stressi − |
| Mökki: Santun häätö | moraali −−, stressi −− |
| Mökin sisällä olo | stressi +, vireys + (hitaasti), nälkä − |
| Mökin sisällä (kerran päivässä): suodatinkahvi / takka / TV | vireys ++, stressi + / stressi + / stressi +, kokemus − |
| Mökin sisällä (kerran päivässä): suihku / sisäsauna | vireys +, kipu + / stressi ++, väsymys ++, kipu + |
| Nukkuminen mökillä | väsymys +++ (ennen päivän tulosta), aamulla stressi − (Päivi soittaa) |
| Pekan kyyti mökille (ensimmäinen kerta) | kokemus + |
| Poliisilta pakoon | stressi + |
| WASTED | moraali −−, stressi −− |
| Ensimmäinen kerta (kauppa, laavu, tarinat, sahaus, halkominen, poiminta, Väinö, nurmikko, pontikka, Raahe, tappelut…) | kokemus + |

**Kehittäjille:** kun peliin tulee uusi toiminto, määritä sille vaikutukset tiloihin (`tilat.add(...)`, `_drink()`,
`_eat()`, `_task_done()`, `_task_failed()`, `tilat.first(...)` main.gd:ssä) ja lisää ne tähän taulukkoon. Kirjaa vain
vaikutukset, jotka poikkeavat nollasta. Jos arvoja ei ole annettu, päättele ne toiminnon luonteesta.
