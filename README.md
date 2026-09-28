# Normipäivä Saloisissa

GTA-tyylinen 3D-peli: aja pyörällä Järvikuja 1:stä K-Marketille, osta kuutonen ja aja kotiin.
Matkalla vaanii vaimo Päivin punainen Hyundai, kassalla harmaapäät laskevat kolikoita, naapurin Anna-Liisa
voi käräyttää ja paikallinen juntti (Raahen karateklubin perustaja) haastaa Street Fighter -tappeluun.

## Mitä pelissä voi tehdä

- **Kauppareissu:** kuutonen, grillimakkara ja tulitikut K-Marketista. Kassalla harmaapäät laskevat kolikoita.
- **Laavu Antinsuonkankaalla:** sytytä nuotio, paista makkara ja avaa kalja, jos pääset laavun
  valtaajien (vittumainen akka tai teinijengi) ohi. Tästä tulee "LEGENDAARINEN NORMIPÄIVÄ".
- **Metsän antimet:** poimi puolukoita, mustikoita, kantarelleja ja herkkutatteja. Naapurin Arto
  (lähekkö puolukkaan?) merkitsee paikat karttaan ja ostaa marjat, ja Pekka (14 kyyhkyä!) ostaa sienet.
  Marjoja poimitaan kyykkyyn (A) ja ylös (D) vuorotellen tasaiseen tahtiin: räpellys ja väärä nappi pudottavat
  marjoja, ja pitkä kyykkiminen käy selkään (kunto): ähinä tihenee, ja lopulta pitää pitää tauko. W/S lopettaa poiminnan.
- **Kaljajemma:** onnistuneen kotiinpaluun saalis piilotetaan jemmaan, joka säilyy pelikerrasta toiseen.
  Jos jemma kasvaa isoksi, Päivi saattaa löytää sen...
- **Vaarat:** Päivin Hyundai, juntti, laavun valtaajat ja jyväjemmari traktorilla, jos ajat viljapellolle.
  Kiinni jäädessä ratkaistaan Street Fighter -tappelussa.

## Jalan vai pyörällä?

- **Vain jalan:** kauppaan meno, marjojen ja sienten poiminta, laavun toiminnot, kaupat naapureiden kanssa
  ja kotiin meno. Nouse pyörän selästä F:llä.
- **Pyörä** on asfaltilla nopea, mutta metsässä ja pellolla pääset jalan nopeammin.
- **Lukitsematon pyörä:** jos jätät sen pitkäksi aikaa kauas (ei kotipihaan), teinit voivat viedä sen.
  Katso kartasta, minne se jäi.
- **Kunto:** juoksu ja pyörän spurtti (Shift) kuluttavat kuntoa. Tyhjänä pitää kävellä tai polkea rauhassa,
  kunnes kunto palautuu. Spurtin alussa saattaa päästä miehekäs pieru.

## Päivät, turvapaikat ja välianimaatiot

- Peli jatkuu päivästä toiseen. Kun jäät kiinni, tulee **WASTED** ja Päivin motkotus, ja uusi päivä alkaa
  lähimmästä turvapaikasta: kotoa tai laavulta (kun olet vallannut sen).
- Onnellinen loppu kotona: karburaattorin säätöä autotallissa kalja kädessä. Laavulla: makkaranpaistoa
  auringonlaskussa.
- **Jemmat:** vie kaljat kotiin, laavun halkovajaan tai Kiilinlammen grillikatokselle (jalan, E). Kun kotijemmassa on
  **24 olutta**, tulee onnellinen loppu autotallissa. Yli 9 kaljan kotijemma on vaarassa: Päivi voi löytää sen
  (JEMMA PALJASTUI!). Laavun ja grillikatoksen jemmoista teinit voivat pölliä. Jemmasta voi ottaa kaljat mukaan
  ja juoda ne laavulla. Onnellinen loppu juo kyseisen jemman tyhjäksi (autotalli kotijemman, laavu laavun jemman).
- **Kantoraja:** jalan jaksaa kantaa 12 kaljaa, pyörän kyytiin mahtuu 6. Liian täysin käsin ei pääse pyörän
  selkään eikä kauppaan (kuutonen ei mahdu).
- **Kiilinlammen grillikatos** on turvapaikka: sinne Päivi ei tule Hyundailla perään.
- Esc avaa valikon: asetukset (grafiikan laatu, koko näyttö, V-Sync, renderöintiskaala, FOV, FPS-näyttö,
  äänenvoimakkuudet, hiiren herkkyys, käänteinen Y, kameran automaattikeskitys), ohjaimet ja tekijät.

## Lataa valmis peli

Valmiit Windows- ja Mac-versiot uusimmasta mainista:
[Releases → Normipäivä (uusin main)](https://github.com/DesmondX80/normipaiva/releases/tag/latest).
GitHub Actions buildaa ne automaattisesti jokaisesta mainin pushista (`.github/workflows/release.yml`).
Peliä ei ole allekirjoitettu: Windowsissa valitse SmartScreen-varoituksesta *Lisätietoja → Suorita silti*,
Macissa *Järjestelmäasetukset → Tietosuoja ja suojaus → Avaa silti*.
Jos Windows-versio näyttää hetken mustaa ja sulkeutuu, käynnistä se tiedostolla `Normipaiva (yhteensopiva).bat`
(kevyempi OpenGL-grafiikka). Peli muistaa valinnan, joten sen jälkeen myös `Normipaiva.exe` toimii.
Grafiikkamoottorin voi vaihtaa myös kohdasta Asetukset → Grafiikka (vaihtuu uudelleenkäynnistyksessä).
Loki: `%APPDATA%\Godot\app_userdata\Normipäivä\logs\godot.log`.

## Käynnistys (Godot-editorista)

1. Asenna **Godot 4.7** (ilmainen): https://godotengine.org/download
   - Mac: myös `brew install --cask godot` käy.
2. Pura tämä zip omaan kansioonsa.
3. Avaa Godot → **Import** → selaa purettuun kansioon ja valitse tiedosto **`project.godot`**
   (se on samassa kansiossa kuin tämä README) → **Import & Edit**.
   - Jos Godot valittaa, että projektia ei löydy, olet todennäköisesti kansiotasoa liian ylhäällä:
     mene kansioon, jossa `project.godot` näkyy.
   - Käytä Godot **4.7**:ää tai uudempaa. Vanhempi versio ei välttämättä avaa projektia.
   - Kansio `.godot` on piilotettu (alkaa pisteellä). Se sisältää valmiiksi tuodut mallit, älä poista sitä.
4. Paina oikeasta yläkulmasta **▶ (F5)**.

Tai komentoriviltä purkukansiossa:

```bash
godot --path .
```

## Ohjaus

| Pyörällä | |
|---|---|
| W / S | polje / jarruta ja peruuta |
| A / D | ohjaa |
| Välilyönti | jarru |
| Q | soittokello |
| E | toiminto (kauppaan, osta, maksa, ulos) |
| F | nouse pyörän selästä / takaisin pyörälle (pyörä jää parkkiin ja näkyy kartassa) |
| Shift | juokse (jalan) / spurtti (pyörällä) |
| M | paperikartta (W/S vierittää, klikkaus asettaa kompassin kohteen) |
| V | FPS-näkymä / kolmas persoona |
| Hiiri | kamera (Esc vapauttaa hiiren valikkoon) |
| Esc | valikko |
| R | aloita alusta |

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

| Tappelussa | |
|---|---|
| A / D | liiku |
| W | hyppy |
| S | torju |
| J | lyönti |
| K | potku |
| L | kassi-isku (tekee kovaa vahinkoa, rikkoo yhden kaljan) |
| S + J | pystykoukku (nostaa ilmaan) |
| S + K | jalkapyyhkäisy |
| eteen + K | kiertopotku |
| K ilmassa | lentopotku |

## Tekijänoikeudet

- Koodi, kartta ja maisema: tehty tätä peliä varten.
- Äänet: CC0-äänitteitä OpenGameArtista ja Kenneyltä (lähteet: `assets/sounds/LICENSE.md`).
- **Haapajärven tekoaltaan kota** (sijainti OpenStreetMapista) on n. 2 km laavulta etelään Kotapolkua pitkin.
  Sahaa tukki pölkyiksi pokasahalla ja halko pölkyt kirveellä (jalan, E), sytytä tuli kotaan ja kuuntele
  vakiovieraiden Raimon ja Veikon tarinoita (10 kpl, kuullut tallentuvat). Kota on täynnä kieltokylttejä.
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
- Maaston korkeuserot: todellinen korkeusmalli (Copernicus DEM ~90 m, `assets/terrain/korkeus.json`), leivottu
  5 m ruudukoksi komennolla `godot --headless --path . -s tools/bake_terrain.gd`. Ylämäessä pyörä hidastuu,
  alamäessä rullaa. Kartta on Saloisissa loivaa: suurin nousu reitillä on noin 15 %.
- Tunnusbiisi "Normipäivä Saloisissa" (rautalanka, tehty Sunolla) soi päävalikossa ja onnellisissa lopuissa
  (`assets/music/normipaiva.mp3`; voimakkuus Asetukset → Ääni → Musiikki).
- Hahmot ja animaatiot: [Quaternius](https://quaternius.com) — Universal Base Characters ja
  Universal Animation Library, **CC0** (lisenssit kansiossa `assets/characters/`).
