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
Testiajot ajetaan `tools/testit/aja.sh`:lla (`kaantyy`, `scene <nimi> [lisäargumentit]`, `tscn <polku>`, valinnat `--headless`,
`--ei-kuvia` ja `--video` (vain tscn: Movie Maker, 30 fps, .avi ajokansioon; esim. `aja.sh --video tscn tools/testit/sinikka_video.tscn`, 27 s Sinikka kävelee, juoksee, hyppää ja istuu rantatuoliin)): se hoitaa eristetyn tallennuksen, jonon, aikarajan, `--shot`:n ja lokin ja tulostaa OK vain, jos ajo päättyi
itse, skriptivirheitä ei ole, testi ei löytänyt vikoja ja kuvia syntyi. Uusi testi tulostaa vikansa riville `TESTI VIKA <selitys>`
(aja.sh tunnistaa myös vanhat merkinnät LÄPI ... ->, RAKO LÄPI, KONTAKTI JÄÄ ja VIRHE). Pelkkä jono:
Useampi samanaikainen ajo (esim. aliagentit) jonotetaan `tools/testit/godot_jono.sh <godot-argumentit>`:llä: ajot
jakavat pelaajan tallennuksen ja user://-kansion, joten vain yksi saa olla käynnissä kerrallaan.

## Testikohtaukset

`scripts/main.gd`:n `_maybe_screenshot` sisältää kymmeniä testikohtauksia. Ajo:

```bash
godot --path . -- --shot=/polku/kuva.png --scene=<nimi> [--nohud]
```

Kuvia ottavat testit tarvitsevat näytön (tai Xvfb:n); pelkkää logiikkaa voi ajaa `--headless`.
`--scene=kainuulista`: Gasthausin ruokalista (valinnat, nälän nollaus, köyhänä pois käytöstä).
`--scene=ronttonen`: rönttösten leivonta (kolme vaihetta, kuva kustakin, valmis erä), vienti Päiville ja kahvipöytä (kuvat; `--shot=`).
`--scene=kalalampi`: retkirunko ja Teeriniemen kalalampi (taksivalikko, matka, lupa, onkiminen, paluu ja kello; kuvat `_alue`, `_tiski`, `_ranta`, `_koho`, `_kirjolohi`, `_taimen`; `--shot=`).
`--scene=matkaopas`: matkaopas B (`tools/testit/matkaopas.gd`: ei opasta, saaminen taksikuskilta kerran ja tallennus, tyhjä opas, osa kuultu, kaikki käyty: hinnat = taksivalikko ja leimat latauksen jälkeen, uusi rekisteririvi, Esc sekä O ja M oppaan kanssa; kuvat `_ei_opasta`, `_saatu`, `_tyhja_<aukeama>`, `_osa_<aukeama>`, `_kaikki_<aukeama>`, `_vertailu`, `_rajaus_sivu`, `_rajaus_leima`, `_rajaus_sisallys`; `--shot=`).
`--scene=hanhikivi`: Hanhikiven rajakivi (taksikuski, kapteeni ja kyltti vihjeinä, loppu kivellä, tallennus, paluu; kuvat `_alue`, `_kivi`, `_kyltti`, `_onkija`; `--shot=`).
`--scene=pakkahuone`: Pakkahuoneen veistos (taksikuski, veistos katoaa, kuraattori ja vierailijakirja vihjeinä, luukulla löytyy, tallennus, paluu; kuvat `_sali_ennen`, `_sali_poissa`, `_kuraattori`, `_luukku_auki`, `_sali_loppu`; `--shot=`).
`--scene=peruskivi`: Rautaruukin peruskivi (taksikuski, vartija ja kyltti vihjeinä, laatta avaa kätkön vain kerran, tallennus, paluu; kuvat `_alue`, `_laatta_kiinni`, `_vartija`, `_kyltti`, `_laatta_auki`; `--shot=`).
`--scene=manamansalo`: Manamansalon muistokirkko (taksikuski, opas ja infotaulu vihjeinä, kivijalka avaa legendan lopun kerran, tallennus, paluu; kuvat `_alue`, `_opas`, `_infotaulu`, `_kirkko_edesta`, `_kirkko_sivusta`, `_kivijalka_ennen`, `_kivijalka_jalkeen`, `_ylhaalta`; `--shot=`).
`--scene=wanharaahe`: Wanha Raahe -kävelykierros (väärä järjestys ja katse eivät ota kuvaa, viisi pysähdystä, ovikuva Päiville kerran, tallennus, paluu; kuvat `_alue`, `_peli_<pysähdys>`, `_patsas_edesta/_sivusta/_ylhaalta`, `_ovet`, `_ovet_vino`, `_talorivi`, `_kauppiaantalo`, `_kuja_makasiini`, `_makasiini`, `_ylhaalta`; `--shot=`).
`--scene=kuvakirkko`: Paltaniemen kuvakirkko (taksivalinta, suntio, piilokuvapeli: huti, kolme löytöä, Esc kesken ja jatko, kaikki kuusi ja palkinto vain kerran, tallennus, paluu; kuvat `_alue`, `_alue_tyhja`, `_peli_kyltti`, `_peli_maalaukset`, `_suntio_edesta/_paadysta/_ylhaalta`, `_penkki_paadysta/_ylhaalta/_vino`, `_maalaukset`, `_ylhaalta`, `_peli_tyhja/_huti/_kolme/_valmis`; `--shot=`).
`--scene=tietokonemuseo`: Saloisten tietokonemuseo (taksivalinta, intendentti, D22 ja mikrot, Pong: pelaaja jäljittää palloa ja voittaa, palkinto vain kerran, tappio ja Esc, tallennus, paluu ja yöllä nukahtaminen museossa; kuvat `_alue`, `_peli_*`, `_d22*`, `_mikrot*`, `_pong_*`, `_intendentti_*`, `_ylhaalta`, `_yo_*`; `--shot=`).
`--scene=vanhaherra`: Raahen satama (taksivalinta, vitriini, pumppaaja, sukellus A/D-pumppauksella, Esc, kuvat `_alue`, `_sukellus`, `_sukellus2`; `--shot=`).
`--scene=karhut`: Kuhmon karhukätkö (taksivalinta, opas, karhukuvaus: pystyssä keskellä oleva karhu antaa hyvän kuvan, palkinto kerran, tallennus; kuvat `_alue`, `_peli`; `--shot=`).
`--scene=hiidenportti`: Sotkamon Hiidenportti (taksivalinta, retkeilijä, kyltti, kiipeily: otteet, putoaminen lavalle, ylälava, palkinto kerran; kuvat `_alue`, `_peli`; `--shot=`).
`--scene=pyhakoski`: Pyhäkosken voimalaitoskylä (taksivalinta, vahtimestari, kioski, portaat, kolmen tarinan palkinto kerran; kuva `_alue`; `--shot=`).
`--scene=kalajoki`: Kalajoen Hiekkasärkät ja rantapallo (taksivalinta, järjestäjä, peli juhannuksena, turnausvoitto antaa palkkion kerran; kuvat `_alue`, `_peli`, `_loppu`; `--shot=`).
`--scene=raate`: Raatteen Portti (taksivalinta, vierailija, portti, muistokivi, kolmen kohdan palkinto kerran; kuva `_alue`; `--shot=`).
`--scene=kajaani`: Kajaanin linna ja Messenius (taksivalinta, rauniot, tervavene-kohtaus, Messenius, kolmen palkinto kerran; kuva `_alue`; `--shot=`).
`--scene=valentinvaala`: Vaalan Veturitalli (ovi, päiväehto joka 28. päivän 26.-28. päivä klo 13-17, banderolli, esitys, kello +40 min; kuvat `_talli`, `_esitys`; `--shot=`).
`--scene=kmarket_vaala`: Vaalan K-Marketin parkki, mummot ja taksitolppa; taksivalikon hinnat Vaalasta ja Saloisista, retki Manamansaloon ja paluu tolpalle, mummojen suuttuminen mopon ohituksesta (kuvat `_mummot`, `_taksi`, `_retki`, `_karkit`).
`--scene=sahanranta`: siirretty asema ja Satamantien risteys, uusi satama ja Uiton sauna; E saunan ovella ja laiturilla (välianimaatiot), kuvat `_asema`, `_risteys`, `_risteys_ylhaalta`, `_uitto_*`, `_satama`, `_sauna_0..3`, `_uinti_0..4`. Tie- ja maastodata: `venv/bin/python tools/vaala_sahanranta.py` (kerran, `vaala_suorat.py`:n jälkeen; uusi lähtö `git checkout assets/vaala`); `--scene=vaala_ajo --ajo=yhteys` tarkistaa tiet.
`--scene=satama`: mopolla Vaalan satamaan, E laiturilla, autopilotti ajaa muskeliveneen kaakkoon kartan reunaan ja
takaisin laiturille (loki: törmäykset, huippunopeus, humala, tallennus) ja ottaa kuvat `_satama`, `_laituri`, `_kyltti`,
`_vene_*`, `_ajo`, `_kaanne`, `_reuna`. Sataman paikka leivotaan työkalulla `tools/vaala_satama.py` (ajo `vaala_bake.py`:stä).
Uusi Satamantie (kapea asfalttikatu K-Marketilta satamaan ja Uitolle, vanha soratie pois): `venv/bin/python tools/vaala_satamatie.py` (kerran, `vaala_kierros.py`:n jälkeen; uusi lähtö `git checkout assets/vaala`). Kuvat `--scene=sahanranta`, tiet `--scene=vaala_ajo --ajo=yhteys`.

Vaalan asematie (Vaalantie torille, Aseman piha suoraan asemalle, Satamantie soraksi, tori laajennettu): `python3 tools/vaala_asematie.py` (kerran, `vaala_risteys.py`:n jälkeen; uusi lähtö `git checkout assets/vaala`). `--scene=vaala_ajo --ajo=yhteys`: kaikki Vaalan tiet tavoitettavissa mökiltä (ajoalueen tulvatäyttö; irralliset saarekkeet listataan). `--ajo=venelava`: veneen reitti lavan laituriin. `--ajo=portti`: mopo ei pääse lavan portista eikä aidan läpi (parkki aidan ulkopuolella). Tieverkon siistii ja suoristaa `python3 tools/vaala_suorat.py` (bake-ketjun viimeinen vaihe, ajetaan kerran; sivutiet, jalkakäytävät ja umpikujahaarat pois, jäljelle suorat tiet kohteisiin).
Vaalan Ratatie (asfalttikierros aseman edestä Zabukin taakse Aseman pihaan, 3 pientä rakennusta pois): `python3 tools/vaala_kierros.py` (kerran, `vaala_asematie.py`:n jälkeen; uusi lähtö `git checkout assets/vaala`). `--scene=vaalakierros`: paperikartta keskustasta kahdella zoomilla sekä vapaan kameran kuvat `_ylhaalta`, `_ymparyra`, `_tori`, `_zabuki`, `_asemalle`.
Vaalan tori ja Zabuki kauemmaksi Siitarista, liikenneympyrä kauimmaiseen risteykseen (oikealle Aseman piha asemalle, vasemmalle Torintie torille; Ratatien kierros pois): `venv/bin/python tools/vaala_torisiirto.py` (kerran, `vaala_satamatie.py`:n jälkeen; uusi lähtö `git checkout assets/vaala`). Kuvat `--scene=vaalakierros`.
Kunnantalo Siitarin puolelle tietä (OSM:n Kunnanvirasto korvataan omalla mallilla): `venv/bin/python tools/vaala_kunnantalo.py` (kerran, `vaala_torisiirto.py`:n jälkeen; uusi lähtö `git checkout assets/vaala`).
Pelisisällön kuvauksissa ([pelin-sisalto.md](pelin-sisalto.md)) kerrotaan kunkin ominaisuuden testi
(`Testi --scene=...`). Lisäksi `tools/testit/` sisältää kuvatestikohtaukset (esim. `mummo_kuvat.tscn`).

## Puheäänet

Päivin repliikit puhuu Satu (nalkutus: nopea tahti, korotettu sävelkorko) ja kaikki muut hahmot Eddy (rauhallinen
tenori). Äänet ovat valmiita mp3-tiedostoja `assets/aanet/<paivi|muu>/<tiiviste>.mp3`, joissa tiiviste on repliikin
tekstin SHA-1:n 12 ensimmäistä merkkiä (`Sfx.voice_key`); `assets/aanet/hakemisto.json` kertoo, mikä tiiviste on mikä
repliikki. Soitto: `Sfx.speak(ryhmä, teksti)` (`audio.gd`); puhekuplat (`bubble.gd`, `voice`-ominaisuus tai
"Päivi: "-etuliite) ja dialogiruutu (`dialogue_box.gd`, puhujan nimi) kutsuvat sitä itse, joten uusi repliikki saa äänen
ilman koodimuutosta. Puuttuva ääni on hiljaisuutta. Äänten teko (vain macOS): aja testikohtaus lipulla
`--aanisynteesi` (esim. `tools/testit/aja.sh --headless scene asema --aanisynteesi`), jolloin jokainen vastaan tuleva
repliikki syntetisoidaan (`tools/aanet/syntetisoi.sh`), ja sen jälkeen `godot --headless --import`. Uusi tai muuttunut
repliikki tarvitsee oman ajonsa: vanha tiedosto jää käyttämättömäksi.

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
(mittaa jalkapohjan rakoa tukeen). Ei vielä: sääri/reisi kiinteän kappaleen sisällä (askelman reuna); toiset hahmot: "Hahmo hahmoa vastaan" alla.

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

**Kontaktit, pohje ja maa:** `Contact.clear_seat_edge` siirtää rento-istujan eteen, kun pohje on istuinlaatikon jalanjäljessä yli
`Elastic.sink("pohje")` pinnan alla (liuku `slide` annetaan `fit_back`ille, joten selkä kallistuu lisää eikä lantio vedy nojaan takaisin).
Polvitaipeen pehmeä raja koskee vain etupintaa. `Contact.ground_y` (fysiikkasäde, `Terrain.COLLISION_LAYER`) on jalkojen tuki kalusteen
kappaleiden rinnalla; `Asento.solids` ohittaa `draped`-maaston laatat ja tarkistaa maan säteellä (`LÄPI ... -> maa (jalkaterä|muu)`).
Läpimenotestin jäännös lasketaan ilman `deep_fade`a (`_raw_pen`), ja `Asento.views(..., check := false)` ohittaa toistotarkistuksen.

**Hahmo hahmoa vastaan:** toinen hahmo on este samoilla luukapseleilla kuin kalusteet (`scripts/contact.gd`, kapselit myös kämmenelle
ja päälle). Kutsuja ajaa joka ruutu `Contact.pair_fit(a, pa, b, pb, move_b)` (vartalot erilleen siirtämällä b:tä vaakasuunnassa, IK-ketjujen
loppupää liukuu pinnalle ja alkupää kiertää polea) -> `pair_contacts` (painumalaatikot kosketuskohtiin, enintään 6) -> `set_contacts`;
`overlap_pairs` mittaa kapseliparien päällekkäisyyden ja `surface_point` antaa IK-kohteen kapselin pinnalta. Mittari:
`tools/testit/aja.sh tscn tools/testit/hahmot_kontakti.tscn` (halaus Sinikan kanssa, iskut Juntin vatsaan, painiote) tulostaa vaiheen pahimman
kapseliparin (`PARI <vaihe> <a>:<kapseli> <b>:<kapseli> <mm> (t)`, kuusi syvintä `PARIT`), kohteen raon pintaan (`KOHDE`: kämmenkapseli
`Contact._pt_depth`illa ja kuvahetkellä kämmenen verkko toisen verkkoon, joka ratkaisee, koska hartialla kapseli on 2-6 cm verkon alla), ranteen kulman
(`RANNE`, raja 70 astetta), jalkojen ja rinnan suunnan (`SUUNTA`), painuman luuttain ilman leviämistä (`PAINUMA`, luiset 0, muut enintään
5 cm) sekä kapselimallin ja verkon eron hartioilla ja vatsassa (`MALLI`, tiedoksi). Raja 1 cm: yli -> `TESTI VIKA`. Vaihe `vanha` (halaus
kiinteillä kohteilla) ajetaan aina ja todistaa mittarin (`MITTARI`; ellei se ylitä rajaa, `TESTI VIKA mittari ei havaitse`); argumentti
`vanha` ajaa halauksen vanhalla tavalla mittarin alla, jolloin VIKA-rivi on odotettu. Yksinäinen hahmo (toinen 30 m päässä) ei saa muuttua
(`YKSIN`, raja 0,1 mm). Kuvat `<vaihe>_<hetki>_koottu.png` (iskut: ennen, osuma, palautuu). Halauksessa kädet ovat eri korkeuksilla,
ettei käsivarsia tarvitse ristiin: Sinikan kädet päähahmon vyötärölle, päähahmon kädet Sinikan hartioiden yli (kyynärpäät ylhäällä). Painiote
(Juntti leveäharteinen, joten hartiaote ei mahdu): päähahmon kämmenet Juntin kyljille (`spine_01`), Juntti tarttuu päältä päähahmon
kyynärvarsista kyynärpään läheltä. Argumentti `paini` ajaa vain painivaiheen (nopea kokeilu).

**Tanssin suljettu ote:** `scripts/pari_ote.gd` (`PariOte.valssi`) asettaa tanssin `_hold`issa viejän selkäkäden (lyhyellä parilla
vyötärölle), seuraajan olkakäden ja vapaat kädet kämmen kämmentä vasten; kämmenkohde on pinta + `PariOte.palm_r` (kämmenpuolen säde
muototaulusta). Raajojen ja kämmenen kapseleilla on muototaulu (`Contact._bin_table`: säde suunnan mukaan luun kehyksessä), joten
kapselimalli seuraa ohutta kyynärvartta ja litteää kämmentä. Painumalla on yhteinen raja (`Elastic.press` ja `press.gdshaderinc`
pitävät käytetyn painuman summaa, enintään `Elastic.MAX_LIMIT` 5 cm), joten päällekkäiset laatikot eivät painu yli rajan. Mittari:
`tools/testit/aja.sh tscn tools/testit/tanssi_kontakti.tscn [sinikka_seura|hilkka|annaliisa] [pois]` ajaa kolme paria vaiheissa alku,
rata, horja (kompastus) ja loppu (kaikki tahdit osutuiksi) ja tulostaa `PARI`, `KOHDE` (selkä- ja olkakäsi, verkko ±1 cm), `KÄSI KÄDESSÄ`
(kapselirako ja verkko ≤ 1 cm, kämmenet vastakkain ≤ −0,7), `RANNE` (≤ 70°), `SUUNTA` (jalat, rinnat vastakkain hartialinjoista),
`PAINUMA` (≤ 5 cm), `RUUTU` (ka < 16,7 ms) ja `JÄÄNTEET` (0 lopetuksen jälkeen). Kuvat `<pari>_<vaihe>_koottu.png`, `_jalat`, `_kadet`
(vapaat kädet suurennettuna) ja Sinikalla `_rinta`. `pois` ajaa ilman kontakteja (vertailu).

**Hiukset ja pää (elastiset):** hiukset ovat skinnattuja verkkoja oma varjostin `shaders/hair.gdshader` (painumasilmukka jaettu
`shaders/press.gdshaderinc`-tiedostossa vartalon kanssa); painumaraja on 0,9 x etäisyys kallon pintaan (`CUSTOM0.w`), leviäminen suuntautuu
pois pään keskuksesta (`press_origin`), ja latvat heilahtavat jousella (`hair_sway`, `CUSTOM0.x` paino). `Pose.limb_points(..., meshes)`:
0 = vartalo ja hiukset, 1 = vain vartalo, 2 = vain hiukset (painuneina). `Contact.fit_back` mittaa selkänojalaatikon jalanjäljen kohdalta
erikseen kallon (`Head`), niskan juuren (`neck_01`, raja 0), painumattomat hiukset ja hatun (`head_extras`): tavoite on litistynyt tukka
(10 % paksuudesta + 1 mm) juuri nojassa. Hattu kallistuu ensin (`_tilt_hat`, enintään 0,5 rad etureunan ympäri), sitten kaula; nojan
ylä- tai sivureunan yli menevä pää ei taivu nojan äärettömään tasoon (sen takia mitataan vain jalanjäljeltä). Janttu: kassin yläpinta
lasketaan pään alimmasta jäykästä pisteestä ja kassi on painumakontakti (`janttu.gd _add_bag`). Pimeässä `crawler3d.disguise` värittää hiukset
`hair_col`-uniformilla. Kokeilu: `tools/testit/hiukset.tscn` (Sinikka rantatuolilla pää nojassa: kallo, hiusten jäännös ja rako, hattu;
`TESTI VIKA` -rivit). `Pose.sit`: korkea polvi (> 10 cm lonkan yläpuolella) yritetään saada alas siirtämällä jalkaterää (`_knees_down`);
jos jalka menisi kappaleeseen (matala askelma), asento jää, ja kädet menevät polvien päälle (`hands_on_thighs`: kohde reidellä tai polvella
niin, että olkapää yltää, sormet vaakaan).

**Hyllyntä liikkeessä (rinnat, vatsa, pakarat):** jokaisella osalla on oma vaimennettu jousi (`Elastic.JIGGLE`: luu, piste, taajuus,
vaimennus, vaakakiihtyvyyden osuus, suurin siirto): rinnat 3,5 Hz / ζ 0,12 (spine_03), vatsa 5 Hz / ζ 0,2 (spine_01), pakarat ja reiden yläosa
12 Hz / ζ 0,25 (pelvis). `Character._update_jiggle` ajaa jouset luun pisteen kiihtyvyydestä vain lähellä (LOD-väli 1, piilossa nollaan) ja
syöttää siirrot uniformeina `jiggle_rinta/vatsa/pakara` (pehmeä raja tanh). Voimakkuus vartalosta (`Elastic.jiggle_gain`: bust, belly, bulk,
curves); verteksipainot `CUSTOM1` (`Elastic.jiggle_weights`, vain paikasta). Siirto lisätään ennen painumaa, joten kontaktilaatikko pitää
pinnan ulkona. `jiggle_debug = true` värittää painot (magenta rinta, syaani vatsa, vihreä pakara). Kokeilu: `aja.sh --video tscn
tools/testit/sinikka_video.tscn` (HYLLYNTA-rivit lokissa, `_lahi.png`-vertailut samasta asennosta ilman hyllyntää, Juntti vatsana).

**Rintamus (`bust`, naismalli):** `Character._bust` pullistaa rinnat ellipsoideiksi; arvo 1,4 asti (Mirkku) koko kasvaa
tasaisesti, sen yli (Sinikka 2.7, DD hoikalla) kasvaa vain ulkonema eteen, ei leveys kylkien yli. Yli 1,4:llä
`_subdivide_bust` tihentää pohjaverkon rinnan alueella kahdesti ennen muotoilua (muuten iso muoto on särmikäs ja
lappubikinien reuna porrastuu). Mittaus: `aja.sh tscn tools/testit/sinikka_mitat.tscn [--bust=2.4,3.0]` (rinnan- ja
alaympärys, ulkonema rintakehästä cm, MITAT-rivit lokissa; kuvat edestä, sivulta ja lähikuvat).
