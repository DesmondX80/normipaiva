# Ohjaus


| Pyörällä | |
|---|---|
| W / S | polje / jarruta ja peruuta |
| A / D | ohjaa |
| Välilyönti | jarru (pyörällä) / hyppy (jalan) |
| Q | soittokello |
| E | toiminto (kauppaan, osta, maksa, ulos) |
| F | nouse pyörän selästä / takaisin pyörälle (pyörä jää parkkiin ja näkyy kartassa) |
| T | syö ja juo: valikko mukana olevista eväistä (korvapuusti, lihapiirakka, suklaa, marjat ämpäristä) ja kaljoista |
| Shift | juokse (jalan) / spurtti (pyörällä) |
| E (kolmiomittauksen aikana) | Sytkäri: lue etäisyys tästä paikasta (vihje näkyy, kun muuta toimintoa ei ole) |
| M | paperikartta (W/S vierittää, klikkaus asettaa kompassin kohteen; mökillä ja Vaalan matkalla Neittävä–Vaala-kartta: rulla tai Q/E zoomaa, WASD tai vetäminen siirtää) |
| B | matkaopas (kun sen on saanut taksikuskilta): retkikohteet, hinnat, kestot ja leimat; A/D tai nuolet selaavat, Esc / B sulkee |
| I / Tab, O | reppu ja Normipäiväkirja ovat yksi vihko: I avaa sen reppusivulta, O päiväkirjan sivulta. Auki ollessa I / O vaihtaa sivua, saman sivun näppäin ja Esc sulkevat. Välilehti: klikkaus, 1–5 tai ←/→ (reppu on viimeinen) |
| G | kellon kiihdytys päälle / pois (kello kulkee 8-kertaisella nopeudella, rannekellon yläreunassa nuolet; välikuvat ja minipelit sammuttavat) |
| V | FPS-näkymä / kolmas persoona |
| Hiiri | kamera (Esc vapauttaa hiiren valikkoon) |
| Esc | valikko (myös päivän aloitus alusta); minipelissä Esc lopettaa pelin kuten F |

| Muskeliveneessä (Vaalan satama) | |
|---|---|
| W / S | kaasu / peruutus (huippu n. 60 km/h) |
| A / D | ohjaa |
| E | nouse laiturille (aja ensin laiturin viereen ja hidasta) |

| Sahauksessa | |
|---|---|
| Hiiri / E | merkkaa katkaisukohta ja aloita |
| Hiiri eteen-taakse / W-S | sahaa |
| Hiiri sivulle / A-D | pidä saha suorassa |
| Oikea nappi | nosta saha pois |
| F | lopeta sahaus |

| Halonhakkuussa | |
|---|---|
| Hiiri | tähtää |
| Vasen nappi / E | nosta pölkky läjästä, aseta pölkylle, iske |
| Oikea nappi / Q / rulla | käännä pölkky |
| F | lopeta hakkuu |

| Kädenväännössä | |
|---|---|
| E | tartu Teron kättä |
| A / D | vuorotellen tasaiseen, reippaaseen tahtiin |

| Tappelussa | |
|---|---|
| A / D | liiku |
| W | hyppy |
| S | torju |
| J | lyönti |
| K | potku |
| L | kassi-isku (tekee kovaa vahinkoa, rikkoo yhden kaljan) |
| eteen + L | heitä kalja: tölkki lentää kaaressa, osuma kaataa (vie kaljan pysyvästi; hyppy väistää, S torjuu) |
| S + J | pystykoukku (nostaa ilmaan) |
| S + K | jalkapyyhkäisy |
| eteen + K | kiertopotku |
| K ilmassa | lentopotku |

| Pihapingiksessä | |
|---|---|
| A / D | liiku |
| W | hyppy |
| J | lyönti (ja syöttö) |
| K | smash: kova ja matala, onnistuu vain korkeasta pallosta |
| eteen / taakse + lyönti | pitkä / lyhyt pallo |

| Metsästyksessä | |
|---|---|
| Hiiri | tähtää |
| Vasen nappi / E | ammu (kaksi piippua, sitten lataus) |
| Oikea nappi pohjassa | tarkka tähtäys (zoom, rauhallisempi käsi) |
| F | lopeta jahti |

## Puhelin ja tabletti (selainversio)

Kosketusnäytöllä peliin tulevat ruudulle omat ohjaimet (`scripts/touch_controls.gd`, autoload `Touch`).
Napit syöttävät samat näppäinpainallukset kuin näppäimistö, joten kaikki toiminnot toimivat niillä.

| Kosketus | |
|---|---|
| Vasen puoli | tatti ilmestyy sormen kohdalle: polje/kävele ja ohjaa, reunaan asti = spurtti/juoksu |
| Oikea puoli, veto | kamera (metsästyksessä ja droonilla tähtäys) |
| Toiminto / Pyörä / Hyppy-Jarru / Syö | E / F / välilyönti / T |
| Oikea reuna | Valikko (Esc), Kartta, Reppu, Kello, Kamera (V) |
| Minipeleissä | omat napit: tappelu Lyö/Potkaise/Erikois, pingis Lyönti/Smash, drooni Kuva/Alas/Kotiin, metsästys Tähtää |
| Valikot, kartta, sahaus ym. | napautus toimii hiiren klikkauksena |

Työpöydällä ohjaimia voi kokeilla käynnistämällä pelin `godot --path . -- --touch`.

**Valikot:** kaikissa valikoissa (esinevalikko, keskusteluvalinnat, päävalikko ja taukovalikko, kappale- ja toivelistat) rivit on numeroitu, ja numeronäppäin 1-9 (esinevalikossa ja toivelistoissa 0 = kymmenes) valitsee rivin suoraan. W/S ja rulla selaavat, E valitsee.
