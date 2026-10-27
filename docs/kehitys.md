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
Useampi samanaikainen ajo (esim. aliagentit) jonotetaan `tools/testit/godot_jono.sh <godot-argumentit>`:llä: ajot
jakavat pelaajan tallennuksen ja user://-kansion, joten vain yksi saa olla käynnissä kerrallaan.

## Testikohtaukset

`scripts/main.gd`:n `_maybe_screenshot` sisältää kymmeniä testikohtauksia. Ajo:

```bash
godot --path . -- --shot=/polku/kuva.png --scene=<nimi> [--nohud]
```

Kuvia ottavat testit tarvitsevat näytön (tai Xvfb:n); pelkkää logiikkaa voi ajaa `--headless`.
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

## Asennot ja kalusteet

Istujat sijoitetaan yhteisillä apufunktioilla `scripts/pose.gd`:ssä: `Pose.seat(ch, front, seat_pt)` (kasvot kalusteen
etusuuntaan, lantio istuimelle), `Pose.feet_to_floor(ch, floor_y, front)` (jalat lattialle lonkkien kohdalle, polvet
eteen) ja `Pose.hands_on_thighs(ch, space)` (kämmenet reisien pinnalle; kutsu vasta, kun jalka-IK on ollut voimassa
yhden ruudun). Tarkistus: `tools/testit/asento.gd` (`seat_report` lantion rako, jalat, polvet, suunta; `bench_report`
kalusteen osien akselit; `report` raajojen rako pintaan). Testikohtaus: `-- --shot=x.png --scene=asennot --asento=<osa>`
ajaa `tools/testit/asennot_<osa>.gd`:n (osa 0 = apujen oma kokeilu tuolilla; kuvat `user://asennot_<osa>/`).

Asentotarkastuksen korjaukset (alkuperäiset istuma-asennot säilytetään, vain viat korjataan): mummojen polvien edestä pois
irrallinen hameen levy (`mummot.gd`), uimarannan tuolit kohti vettä, selkänoja taakse ja rento asento (nilkat ristissä, kädet
sylissä), Honganpalon portaiden istuja ylimmälle askelmalle (`world.gd`) ja kirppiksen rumpalille rumpusetti eteen ja kädet
kapuloille (`kirppis_interior.gd _build_drumkit`).

### Istumapaikat ja kontaktit

Kaluste kuvaa istumapaikan datana (`scripts/seat.gd`): `Seat.spot(node, {seat, front, back, solids, ground, hands})`, kentät
kalusteen paikallisessa avaruudessa; `Seat.collect(node)` kerää B.mesh/B.box-muodot (aja ennen `B.merge_static`). `Pose.sit(hahmo,
kaluste, tyyli, opts)` istuttaa: tyylit `JAYKKA` (mummot), `SUORA` (jakkara, portaat), `RENTO` (selkä selkänojaan, jalat ojossa,
`opts.ristissa`); `opts.hands` = kalusteen käsikohde, muuten kädet reisillä. `scripts/contact.gd` korjaa tunkeumat kapselimallilla:
vartalo pois pöydästä, selkä 0-1 cm selkänojasta, jalkapohja tukipinnalle (korkein tuki kantapään ja päkiän alla), käsivarret pois
jaloista. Tulosteet `KONTAKTI JÄÄ ...` kertovat yli 1 cm tunkeumasta. Kapselimalli mitataan paistetusta verkosta vasta 3 ruutua
hahmon luonnin jälkeen; sitä ennen (ja headlessissa) käytetään vakiotaulukkoa. Kokeilu: `tools/testit/kontakti_a.tscn`
(mittaa jalkapohjan rakoa tukeen). Ei vielä: sääri/reisi kiinteän kappaleen sisällä (askelman reuna) ja toiset hahmot.

**Elastisuus** (`scripts/elastic.gd`): `Elastic.PARTS` on ruumiinosien painumarajat (m): luinen 0 (kallo, sääri, polvi, kyynärpää,
ranne, kämmen, jalkaterä), pehmeä pakara/reisi 15 mm, vatsa 6-16 mm (`belly`), rinta 12-20 mm (`bust`, Sinikka 20), selkä/kylki 4 mm;
`part_limit(osa, shape)` skaalaa ne vartalolla (`belly`, `bulk`, `bust`) ja `sink(osa, shape)` = puolet rajasta (ratkaisijan
suunniteltu upotus). `Character._clothed_mesh` laskee jokaiselle verteksille rajan kerran (`CUSTOM0.w`, levyvälimuistissa).
`ch.set_contacts([[Transform3D, puolikoko], ...])` (laatikon +Y = pinta, enintään 6) siirtää laatikot verkon avaruuteen ja asettaa
uniformit; `character.gdshader` vertex() painaa pehmeät verteksit pinnalle (`min(tunkeuma, raja)` pintaa pitkin, leviäminen sivulle
0,35 x painuma, normaali kohti pintaa); `clear_ik()` / `clear_contacts()` palauttaa lepoverkon. `Elastic.press/displace/depth` ovat
varjostimen peili GDScriptinä (testit, `Pose.limb_points`): pidä kaavat samoina. Ei ruutukohtaista työtä. Kokeilu:
`tools/testit/elastic_a.tscn` (Sinikka rantatuolilla ja pystylevy rinnan edessä, painumat ruumiinosittain).

**Testit (kontaktit ja elastisuus):** `tools/testit/kontakti_a.tscn -- <kansio>` mittaa jalkapohjan rakoa, käsivarren rakoa reiteen ja
vartalon rakoa pöydän reunaan, ja vertaa lopuksi Sinikkaa (`Looks.sinikka_bikini()`), hoikkaa ja kaljamahaa saman pöydän ääressä
(`PAINUMA`, `POYTA`, `K12`, `K14` -rivit: rinta vs vatsa mm, vatsa hoikka vs kaljamaha, painuma nousun jälkeen 0). Läpimenotesti:
`godot_jono.sh --path . -- --shot=x.png --nohud --scene=asennot --asento=lapimenot` (`tools/testit/asennot_lapimenot.gd`) käy läpi
`Seat.registry`-paikat, ajaa jokaiselle istujalle `Asento.solids`, tarkistaa jalkapohjan (alin piste >= -0,005 m) ja pehmeän
painuman jäännöksen (`KONTAKTI JÄÄ`, raja 1 mm yli painumarajan) ja kuvaa istujan ennen (painumat pois) ja jälkeen
(`<tag>_ennen_koottu.png`, `<tag>_jalkeen_koottu.png`). Tulee 0 istujaa = testi ei tarkistanut mitään.

**Kontaktit, jatko:** rento istuja pitää kädet sylissä (`Pose.hands_on_thighs(..., lap)`), hattu ja hiukset otetaan selkänojan mittaukseen
(`Contact.head_extras`), portaiden jalat ojompana (`opts.jalat_ulos`, `Contact.place_foot` liu'uttaa jalan yhdelle askelmalle,
`Contact.clear_legs`), pöydän reunan etupinta on painumakontakti (vatsa/rinta) ja litistyvä kohta pullistuu sivulle
(`Elastic.SPREAD`, `HALO`; varjostin peilaa).
