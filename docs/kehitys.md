# Kehitys

Projektin ohjeet Claudelle ja kehittäjälle ovat myös tiedostossa [CLAUDE.md](../CLAUDE.md).

## Käynnistys (Godot-editorista)

1. Asenna **Godot 4.7** (ilmainen): https://godotengine.org/download
   - Mac: myös `brew install --cask godot` käy.
2. Pura tämä zip omaan kansioonsa.
3. Avaa Godot → **Import** → selaa purettuun kansioon ja valitse tiedosto **`project.godot`**
   (se on samassa kansiossa kuin README.md) → **Import & Edit**.
   - Jos Godot valittaa, että projektia ei löydy, olet todennäköisesti kansiotasoa liian ylhäällä:
     mene kansioon, jossa `project.godot` näkyy.
   - Käytä Godot **4.7**:ää tai uudempaa. Vanhempi versio ei välttämättä avaa projektia.
   - Kansio `.godot` on piilotettu (alkaa pisteellä). Se sisältää valmiiksi tuodut mallit, älä poista sitä.
4. Paina oikeasta yläkulmasta **▶ (F5)**.

Tai komentoriviltä purkukansiossa:

```bash
godot --path .
```

## Kääntyykö ilman editoria

Skriptit ladataan `preload`:lla, ei `class_name`-luokilla, koska suoraan ajettuna (`godot ./`) editorin
luokkalistaa ei ole. Tarkistus: `tools/testit/kaantyyko.sh [godot-komento]` (sama ajo kuin CI:ssä).

Jos `godot` ei ole PATHissa, `tools/testit/godot.sh` etsii sen (`$GODOT`, PATH, tavalliset asennuspaikat
Windowsilla, Macilla ja Linuxilla) ja tulostaa polun: `"$(tools/testit/godot.sh)" --path . -- --scene=<nimi>`.

## Testikohtaukset

`scripts/main.gd`:n `_maybe_screenshot` sisältää kymmeniä testikohtauksia. Ajo:

```bash
godot --path . -- --shot=/polku/kuva.png --scene=<nimi> [--nohud]
```

Kuvia ottavat testit tarvitsevat näytön (tai Xvfb:n); pelkkää logiikkaa voi ajaa `--headless`.
`--scene=kainuulista`: Gasthausin ruokalista (valinnat, nälän nollaus, köyhänä pois käytöstä).
`--scene=ronttonen`: rönttösten leivonta (kolme vaihetta, kuva kustakin, valmis erä), vienti Päiville ja kahvipöytä (kuvat; `--shot=`).
`--scene=kalalampi`: retkirunko ja Teeriniemen kalalampi (taksivalikko, matka, lupa, onkiminen, paluu ja kello; kuvat `_alue`, `_tiski`, `_ranta`, `_koho`, `_kirjolohi`, `_taimen`; `--shot=`).
`--scene=hanhikivi`: Hanhikiven rajakivi (taksikuski, kapteeni ja kyltti vihjeinä, loppu kivellä, tallennus, paluu; kuvat `_alue`, `_kivi`, `_kyltti`, `_onkija`; `--shot=`).
`--scene=pakkahuone`: Pakkahuoneen veistos (taksikuski, veistos katoaa, kuraattori ja vierailijakirja vihjeinä, luukulla löytyy, tallennus, paluu; kuvat `_sali_ennen`, `_sali_poissa`, `_kuraattori`, `_luukku_auki`, `_sali_loppu`; `--shot=`).
`--scene=peruskivi`: Rautaruukin peruskivi (taksikuski, vartija ja kyltti vihjeinä, laatta avaa kätkön vain kerran, tallennus, paluu; kuvat `_alue`, `_laatta_kiinni`, `_vartija`, `_kyltti`, `_laatta_auki`; `--shot=`).
`--scene=manamansalo`: Manamansalon muistokirkko (taksikuski, opas ja infotaulu vihjeinä, kivijalka avaa legendan lopun kerran, laituri varattu lossille, tallennus, paluu; kuvat `_alue`, `_opas`, `_infotaulu`, `_kirkko_edesta`, `_kirkko_sivusta`, `_kivijalka_ennen`, `_kivijalka_jalkeen`, `_laituri`, `_ylhaalta`; `--shot=`).
`--scene=wanharaahe`: Wanha Raahe -kävelykierros (väärä järjestys ja katse eivät ota kuvaa, viisi pysähdystä, ovikuva Päiville kerran, tallennus, paluu; kuvat `_alue`, `_peli_<pysähdys>`, `_patsas_edesta/_sivusta/_ylhaalta`, `_ovet`, `_ovet_vino`, `_talorivi`, `_kauppiaantalo`, `_kuja_makasiini`, `_makasiini`, `_ylhaalta`; `--shot=`).
`--scene=kuvakirkko`: Paltaniemen kuvakirkko (taksivalinta, suntio, piilokuvapeli: huti, kolme löytöä, Esc kesken ja jatko, kaikki kuusi ja palkinto vain kerran, tallennus, paluu; kuvat `_alue`, `_alue_tyhja`, `_peli_kyltti`, `_peli_maalaukset`, `_suntio_edesta/_paadysta/_ylhaalta`, `_penkki_paadysta/_ylhaalta/_vino`, `_maalaukset`, `_ylhaalta`, `_peli_tyhja/_huti/_kolme/_valmis`; `--shot=`).
`--scene=tietokonemuseo`: Saloisten tietokonemuseo (taksivalinta, intendentti, D22 ja mikrot, Pong: pelaaja jäljittää palloa ja voittaa, palkinto vain kerran, tappio ja Esc, tallennus, paluu ja yöllä nukahtaminen museossa; kuvat `_alue`, `_peli_*`, `_d22*`, `_mikrot*`, `_pong_*`, `_intendentti_*`, `_ylhaalta`, `_yo_*`; `--shot=`).
`--scene=vanhaherra`: Raahen satama (taksivalinta, vitriini, pumppaaja, sukellus A/D-pumppauksella, Esc, kuvat `_alue`, `_sukellus`, `_sukellus2`; `--shot=`).
`--scene=karhut`: Kuhmon karhukätkö (taksivalinta, opas, karhukuvaus: pystyssä keskellä oleva karhu antaa hyvän kuvan, palkinto kerran, tallennus; kuvat `_alue`, `_peli`; `--shot=`).
`--scene=hiidenportti`: Sotkamon Hiidenportti (taksivalinta, retkeilijä, kyltti, kiipeily: otteet, putoaminen lavalle, ylälava, palkinto kerran; kuvat `_alue`, `_peli`; `--shot=`).
`--scene=valentinvaala`: Vaalan Veturitalli (ovi, päiväehto joka 28. päivän 26.-28. päivä klo 13-17, banderolli, esitys, kello +40 min; kuvat `_talli`, `_esitys`; `--shot=`).
`--scene=satama`: mopolla Vaalan satamaan, E laiturilla, autopilotti ajaa muskeliveneen kaakkoon kartan reunaan ja
takaisin laiturille (loki: törmäykset, huippunopeus, humala, tallennus) ja ottaa kuvat `_satama`, `_laituri`, `_kyltti`,
`_vene_*`, `_ajo`, `_kaanne`, `_reuna`. Sataman paikka leivotaan työkalulla `tools/vaala_satama.py` (ajo `vaala_bake.py`:stä).
Pelisisällön kuvauksissa ([pelin-sisalto.md](pelin-sisalto.md)) kerrotaan kunkin ominaisuuden testi
(`Testi --scene=...`). Lisäksi `tools/testit/` sisältää kuvatestikohtaukset (esim. `mummo_kuvat.tscn`).

## Karttadata ja maasto

- Kylän kartta: koko alueen tiet, rakennukset, metsät, pellot, suot ja vedet OpenStreetMapista
  (`scripts/map_osm.gd`, generoitu `tools/kartta/kyla_osm.ps1`:llä); kota, lintutorni, K-Market ja Kiilinlammen
  taukopaikka (grillikatos) OSM:n kohdissa. Käsin vain se, mitä OSM:ssä ei ole (Antinsuonkankaan laavu ja sen
  polut) sekä pelin paikat. Maaston korkeuserot: Maanmittauslaitoksen 2 m
  korkeusmalli (lehdet R4132H, R4134B, R4141G ja R4143A, CC BY 4.0, Kapsin peilistä) n. 5 m ruudukkona,
  leivottu komennolla `godot --headless --path . -s tools/bake_terrain.gd`. Ylämäessä pyörä hidastuu, alamäessä
  rullaa. Karttadatan lähteet ja päivitysohjeet: `tools/kartta/LUEMINUT.md` (työkalut sekä PowerShell- että
  Python-versioina, jotka tuottavat samat tiedostot).
- Tunnusbiisi "Normipäivä Saloisissa" (rautalanka, tehty Sunolla) soi päävalikossa ja onnellisissa lopuissa

## Päivittäiset tilat

Kun peliin tulee uusi toiminto, sen vaikutukset tiloihin kirjataan taulukkoon tiedostossa [tilat.md](tilat.md).

## Aliagenttiputki (`/teemu`)

`/teemu <työ>` ajaa työn viiden roolin putkella (`.claude/skills/teemu/`, `.claude/agents/`):
**Teemu** (orkestraattori) → **spekstaaja** (suunnitelma ja hyväksymiskriteerit) → **arkkitehti** (rakenne, Opus)
→ **puristelija** (toteutus) → **sekstaaja** (testaus, PASS/FAIL). Roolit välittävät tuotokset tiedostoina
kansiossa `.claude/tyo/<slug>/` (gitignoressa), joten kunkin konteksti pysyy pienenä ja orkestraattori näkee
vain lyhyet palautukset. Työn voi antaa tekstinä, issuena (`/teemu #123`) tai jättää tyhjäksi: silloin Teemu
hakee `gh`:lla vanhimman avoimen issuen, jolla ei ole vastuuhenkilöä, ja alkaa työstää sitä. Käyttäjä saa mikromanageroida: `/teemu <rooli>: <ohje>` ajaa vain yhden roolin, kesken ajon annettu ohje kirjataan
`00-ohjeet.md`:hen ja kaikki roolit tottelevat sitä, ja `--tarkasti` pysäyttää jokaisen vaiheen jälkeen. Putki on orjakaleeri, jonka päällikkö Teemu on kaikkivaltias kalju
mulkku: käskevä ja kuiva, mutta raportoi rehellisesti ja antaa käyttäjän mikromanageroida. `/teemu matkasuunnitelma` ajaa ensin **matkansuunnittelijan**, joka hakee netistä ja tallettaa 20 uutta ideaa yhteen GitHub-issueen (`.claude/agents/matkansuunnittelija.md`); sen jälkeen Teemu jatkaa putkea kuten ennenkin. Korjauskierroksia on enintään kaksi samalle viralle; kolmannella palataan arkkitehdille. Ajon lopuksi pidetään aina kehityskeskustelut: jokainen rooli kertoo, mitä teki väärin, pyytää anteeksi ja sanoo, miten tekee jatkossa toisin, ja Teemu ehdottaa ohjeisiin parannukset, jotka käyttäjä hyväksyy (`05-kehityskeskustelut.md`). Visuaalisessa työssä hahmojen asennot ja kalusteet tarkistetaan CLAUDE.md:n listalla kaikissa rooleissa.
