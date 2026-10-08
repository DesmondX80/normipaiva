# Karttadata: mistä se tulee ja miten aluetta laajennetaan

Pelin kylä (Saloinen, Raahe) ja mökki (Kaisuantie 62, Vaala) on tehty oikeasta kartta-aineistosta. Kaikki lähteet
ovat avoimia; tällä sivulla kerrotaan, mistä data haetaan ja millä työkaluilla se muunnetaan peliin, jos aluetta
laajennetaan tai uusia alueita lisätään.

## Lähteet

| Mitä | Lähde | Lisenssi | Haku |
|------|-------|----------|------|
| Tiet, polut, rakennukset, metsät, pellot, suot, vedet, purot | OpenStreetMap | ODbL (© OpenStreetMap-tekijät) | `https://api.openstreetmap.org/api/0.6/map?bbox=<länsi>,<etelä>,<itä>,<pohjoinen>` (asteina, enintään 0,25 astetta² ja 50 000 solmua kerralla; isompi alue useana palana tai Overpass-rajapinnasta) |
| Maanpinnan korkeudet | Maanmittauslaitoksen korkeusmalli 2 m | CC BY 4.0 (© Maanmittauslaitos) | Kapsin peili `https://kartat.kapsi.fi/files/korkeusmalli/hila_2m/etrs-tm35fin-n2000/<R4>/<R41>/<R4132H>.tif` (6 × 6 km lehti, GeoTIFF, LZW-pakattu float32, n. 20–25 Mt) |
| Osoitteet ja paikat | OpenStreetMap / Nominatim | ODbL | `https://nominatim.openstreetmap.org/search?q=<osoite>&format=json` (Google Maps antaa tarkemman osoitepisteen, jos OSM:ssä on vain katu) |

Huomioita:
- Maanmittauslaitoksen omat rajapinnat vaativat API-avaimen; Kapsin peilistä saa samat lehdet ilman sitä.
- Muut korkeuslähteet ovat karkeampia: EU-DEM 25 m (OpenTopoData) ja Copernicus 90 m (Open-Meteo). SRTM ei kata
  tätä leveyttä.
- Lehden nimi ETRS-TM35FIN-koordinaateista (E, N): 1:200 000 -lehti = rivikirjain (K = N 6 570 000, 96 km välein:
  K L M N P Q R S T U V W X) ja sarake (4 = E 308 000–500 000, 192 km leveä). Jako neljään (numerot 1–4: 1 lounas,
  2 luode, 3 kaakko, 4 koillinen) kolmesti, lopuksi kahdeksaan 6 × 6 km lehteen (kirjaimet A–H sarakkeittain
  lännestä itään, kussakin ensin etelä, sitten pohjoinen). Esim. mökki E 484 018 N 7 153 382 = R4333D,
  kylä = R4132H, R4134B, R4141G, R4143A. Tarkista tulos lehden omasta sijaintitiedosta (GeoTIFF-tagi 33922),
  jonka `Tiff.Info()` tulostaa.

## Ajotavat: PowerShell tai Python

Jokaisesta ajoskriptistä on kaksi samaa tulosta tuottavaa versiota:

- **PowerShell** (Windows PowerShell 5.1, C# käännetään `Add-Type`llä): `kyla_osm.ps1`, `kyla.ps1`, `mokki.ps1`.
- **Python 3** (vain standardikirjasto, ei numpyä eikä GDALia): `kyla_osm.py`, `kyla.py`, `mokki.py`
  (yhteinen kirjasto `kartta.py`). Python-versiot tuottavat samat tiedostot tavu tavulta; LZW-purku puhtaalla
  Pythonilla on hitaampi (kylän korkeusmalli muutamia minuutteja).

## Kylä (scripts/map_data.gd, scripts/map_osm.gd, assets/terrain/)

Kartan pikselit ovat yhdessä todellisessa kehyksessä (`kehys.ps1`, Pythonissa `kartta.py`): kaksi OSM-risteystä
kiinnittää sen, J_K (Ketunperäntie / Tarpiontie) = px (195, 765) ja J_PATO (Ketunperäntie / Patotie) = px (1304, 3778),
mittakaava n. 1,22 m/px. Uusi alue laajennetaan samaan kehykseen, jolloin kaikki kohteet osuvat kohdalleen.

1. **OSM-ote**: hae `map.osm` bbox-kyselyllä niin, että se kattaa uuden alueen (nykyinen: `bbox=24.43,64.595,24.53,64.66`).
2. **Tiet, rakennukset, maankäyttö** → `scripts/map_osm.gd` koko kartan alueelta (rajausruutu px skriptissä):
   - `powershell -File tools\kartta\kyla_osm.ps1 -Osm <map.osm>`
   - `python tools/kartta/kyla_osm.py --osm <map.osm> [--out <tiedosto>]`

   Luokittelu (`osm.cs` / `kartta.py`): highway → highway/road/street/path, landuse/natural → metsä/pelto/suo/vesi,
   waterway → purot, building → talot (suunnattu pohjapiirros). Käsin tehdyt kohteet (vain se, mitä OSM:ssä ei ole,
   esim. Antinsuonkankaan laavu) ja pelipaikat ovat `map_data.gd`:ssä; päivitä `PLAY_AREA` ja pelipaikat, jos rajat
   muuttuvat. Tarkista paikat lopuksi testinäkymällä `--scene=placecheck` ja alueet
   `godot --headless --path . -s tools/kartta/tarkista_alueet.gd`.
3. **Korkeudet** → `assets/terrain/korkeus.json` (metatiedot) ja `korkeus_mml.i16` (int16 cm, täsmälleen pelin 5 m
   maastoruudukon pisteissä, ilman keskiarvoa). Lataa tarvittavat 2 m -lehdet ja aja
   - `powershell -File tools\kartta\kyla.ps1 -Lehdet <kansio> [-Sheets R4132H,...]`
   - `python tools/kartta/kyla.py --lehdet <kansio> [--sheets R4132H ...] [--out-dir <kansio>]`

   Mosaiikin ja ruudukon rajat ovat skriptissä; laajenna niitä uuden alueen mukaan.
4. **Maasto peliin**: `godot --headless --path . -s tools/bake_terrain.gd` leipoo `korkeus.bin`in ja `pinnat.png`:n.
   Järvien pinta on korkeusmallin tasoitettu vedenpinta järven sisältä (`map_data.WATER`), rannat mallin mukaisina.

## Mökki (scripts/mokki.gd, assets/mokki/kartta.json)

Mökin ympäristö (kävelyalue `AREA_MIN..AREA_MAX` mokki.gd:ssä: 400 m mökin ympäri ja pohjoiseen Salmisille ja
Keskimmäiselle, n. 1 × 2,15 km; näkyvä alue 550 m laajempi) on osoitepisteen kehyksessä (x itään, z etelään, metreinä;
origo 64.5054523 N, 26.6672225 E; lon × 111 320 × cos(lat), lat × 111 320). `kartta.json` tehdään kokonaan samoilla
työkaluilla kuin kylä: OSM-kohteet (myös metsät) samalla muuntimella, pihan tarkka ruudukko "dem" (300 × 300 m, 2 m)
ja kaukoalue "dem_far" (2 × 2 km, 8 m = mökin kaukomaaston ruutu) MML:n 2 m mallista (lehti R4333D kattaa koko
alueen) ja vesistöjen pinnat ("level") mallin tasoitetusta vedenpinnasta.

1. **OSM-ote**: `https://api.openstreetmap.org/api/0.6/map?bbox=26.6440,64.4955,26.6950,64.5280` (kaukoalue `FAR`
   mokki.py:ssä; PowerShell-versiot tekevät vielä vanhan 2 × 2 km alueen)
2. **Kartta**:
   - `powershell -File tools\kartta\mokki.ps1 -Lehdet <kansio> [-Osm <map.osm>]`
   - `python tools/kartta/mokki.py --lehdet <kansio> [--osm <map.osm>] [--out <tiedosto>]`

   Ilman OSM-otetta nykyiset kohteet säilyvät ja vain korkeudet ja pinnat lasketaan uudelleen.

Mökin ympäristössä OSM:n metsäkartoitus on vajaa (kävelyalue lähes kartoittamatta), joten `mokki.gd` pitää maaston
metsänä kaikkialla, missä ei ole peltoa, vettä, suota, tietä tai pihaa; metsäalueet ovat datassa tallessa.
Vanha `tools/mokki_kartta.py` (Overpass ja EU-DEM 25 m) on vielä repossa, mutta nämä työkalut korvaavat sen.

## Työkalut tässä kansiossa

| C# / PowerShell | Python | Tehtävä |
|---|---|---|
| `tm35.cs` | `kartta.py: tm35()` | WGS84/ETRS89 → ETRS-TM35FIN (JHS 197) |
| `tiff.cs` | `kartta.py: Tiff` | GeoTIFF-lukija (LZW, laatat) ilman GDALia |
| `mosaic.cs` | `kartta.py: Mosaic` | lehtien mosaiikki ja näytteistys |
| `osm.cs` | `kartta.py: Osm` | OSM-XML → kylän GDScript-vakiot tai mökin kartta.json-kohteet |
| `mokki_dem.cs` | `kartta.py: MokkiDem` | mökin korkeusruudukot ja vesistöjen pinnat |
| `kehys.ps1` | `kartta.py: px2tm, tm2px` | kylän kehys (px ↔ TM35) |
| `kyla_osm.ps1`, `kyla.ps1`, `mokki.ps1` | `kyla_osm.py`, `kyla.py`, `mokki.py` | ajoskriptit |
| `tarkista_alueet.gd` | | aluemonikulmioiden kolmioituvuus (Godot) |

## Tarkka mallinnus: mökin metsä ja Vaalan mopomatka (tarkka.py)

Mökin ympäristö ja Vaalan mopomatka käyttävät samaa aineistoa kuin Oulujärven norpat:

| Mitä | Lähde |
|------|-------|
| Puut: paikka, pituus, latvuksen säde | MML:n laserkeilaus 2011 (Funet, `mml/laserkeilaus/2008_latest/2011/`): latvusmallin paikalliset maksimit; latvuston aukot täydennetään vain laserin näkemään latvustoon |
| Puulajit | Luken monilähteinen VMI 2023 (16 m), HTTP-aluepyynnöillä vain tarvittavat laatat |
| Rakennusten korkeudet | laserpisteet pohjapiirroksen sisältä (pienissä harja, isoissa katon taso) |
| Vaalan korkeudet | MML:n 2 m korkeusmalli (tie, sivut, keskusta ja kaukomaasto; ennen EU-DEM 25 m) |
| Vaalan pellot, suot, vedet ja rakennukset | maastotietokanta; keskustan rakennuksille OSM:n nimet, tyypit ja tunnisteet |

Python-riippuvuudet: `python3 -m venv venv && venv/bin/pip install -r tools/kartta/requirements.txt`.

- **Mökki**: `venv/bin/python tools/kartta/mokki_puut.py --cache <välimuisti>` → `assets/mokki/puut.bin`
  (puut mökin paikallisessa kehyksessä, maanpinta kuten `mokki.gd`:n `h()`) ja `assets/mokki/rakennukset.json`
  (naapurirakennusten harjakorkeudet OSM-tunnisteittain).
- **Vaala**: `venv/bin/python tools/vaala_bake.py --cache <välimuisti>` (tarkka aineisto `tools/kartta/vaala_tarkka.py`)
  → `assets/vaala/tie.json`, `maasto.bin` ja `puut.bin`. Puut siirretään tien suhteen pelin kehykseen kuten muutkin
  kohteet, tiivistetyllä välillä harvennettuna tiivistyksen suhteessa (metsän tiheys säilyy). Kaukomaaston metsä
  (650 m tiestä) on laserin valtapuita. Soratie mökiltä Neittäväntielle on tiivistetty `GRAVEL_K`-kertaisesti.
  Alikululta keskustaan Oulujoen ylitys (`TOWN_K`) ja itärannan pätkä keskustan portille (`EAST_K`, `TOWN_GATE`, ei
  taloja) on lineaarinen kaista: joki kapenee ja keskusta alkaa heti sillan jälkeen; lavan niemi (`vaala_lava.AREA_REAL`)
  ja keskusta ovat kumpikin 1:1 omalla siirrollaan (`lava_off`, `town_off`). Oulujärven lounainen lahti mökin
  puolella on maata (`lake_cut`, `LAKE_CUT_X`, `LAKE_CUT_Z`), järven selkä jatkuu niemeltä kaakkoon.
  Radan alikulku on leveä (`UNDER_OPEN` 13 m ajoradan reunasta) ja penger nousee aukon reunasta luiskana
  (`UNDER_SLOPE`) kannen alle; kansi pilareilla ja maatuet luiskien päällä (vaala.gd). Liian isot rakennukset
  pienennetään `BUILDING_SCALE`-taulukolla. Sivuteiden päälle jääneet talot
  ja sillan päihin liittyvät sivutiet karsitaan, tiivistetyllä välillä reitin poikki menevät metsätiet harvennetaan
  (`THIN_CROSS`) ja rakennuksettomat pihamaat muutetaan metsäksi.
  Eteenpäin-kuvaus (`vaala_warp.Forward`: todellinen piste -> lähin pelin ruutu, jonka käänteiskuvaus osuu siihen)
  jatkaa risteysten haarat OSM-linjaansa pitkin tarkan alueen reunaan ja kuvaa mökin kävelyalueen mopomatkan
  kehykseen (tie.json "mokki_warp", paperikartta). Tiivistyksessä mökin pohjoiset järvet puristuisivat 22-kertaisesti
  sadan metrin läikäksi, joten Neittävän järviseutu (`NORTH_LAKES`: Salmiset, Pyöriäinen, Keskimmäinen mökin
  kartta.json:sta) piirretään Neittäväntien luoteeseen loivalla kuvauksella `NL_C + (p - NL_REF) * NL_S`; alueen
  muut pikkujärvet muuttuvat suoksi. Paperikartta käyttää samaa kuvausta mökin kohteille ("mokki_map").
  Ajettavuus: `godot --path . --disable-vsync -- --shot=<kansio>/t.png --scene=mokkivaalatiet` (mopon kapseli
  kaikkia teitä pitkin), `--scene=mokkimopo_koko` ja `--scene=mokkimopo_paluu` (koko reitti ajaen kumpaankin suuntaan),
  `--scene=mokkiajoalue` (mopon ajoalue kuvaksi, tieltä metsään ajo) ja `--scene=mokkireitti` (reitti ajajan silmin
  60 näytteen välein, `--step=N`). `--disable-vsync` nopeuttaa kuvien ottoa, kun ikkuna on taustalla.
  Lopuksi `tools/vaala_lava.py` tekee Oulujärven lavan niemen 1:1-maastoksi:
  Pahalahdentien risteys on 1:1-alueella, mutta niemen kaukomaasto tuli tiivistetyn tien suhteen (muualta), joten
  niemellä ei ollut vettä. Skripti tekee alueelle tarkan maaston korkeusmallista (vesi = korkeusmallin tasoitettu
  vedenpinta, Oulujoki ja Oulujärvi samassa 122,74 m:ssä), painaa järven kaukomaastoon (vaala.gd piirtää vedet),
  sijoittaa lavan rantaan (`SHORE_GAP` m vedestä, lähin paikka todellisesta), asfaltoi Pahalahdentien lavalle (ajotie
  kiertää lavan kulman oven eteen), tekee aidan rannasta rantaan ja siistii puut. Korkeusmalli on tallessa
  reitti.json:ssa ("lava_dem", `--cache` hakee sen kerran); muuten ajo ei tarvitse välimuistia ja on toistettavissa.
  Tarkistuskuvat: `godot --path . -- --shot=<kansio>/v.png --scene=mokkivaalalava` (myös mopolla portista ovelle)
  ja `--scene=mokkivaalajalan` (moposta jalan, ovelle, rantaan ja takaisin selkään).
  Sen jälkeen `tools/vaala_silta_jarvi.py` suoristaa Oulujoen sillan (tiivistyskaistan sauma taittoi sen keskeltä)
  ja tasaa sen korkeuden penkereineen sekä täyttää Oulujärven kaukomaaston luoteiskulmaan, ja
  `tools/vaala_keskusta.py` siirtää K-Marketin ja Gasthausin Siitarin ympärille ja torin tien päähän Siitarin
  pihalenkin kohdalle (`TORI_U`, `TORI_V`), Zabuki torin itäpäätyyn.
  Molemmat ovat toistettavia ilman välimuistia (alkuarvot tie.json:ssa). Tarkistuskuvat:
  `--scene=mokkitori` (tori, Zabuki, Gasthaus) ja `--scene=mokkivaala` (silta `_silta*`, alikulku, keskusta).
- **Puut pois teiltä**: molemmat leivonnat ajavat lopuksi `tools/kartta/puut_teilta.py`:n, joka poistaa valmiista
  `puut.bin`:stä puut piirretyiltä teiltä, kaduilta, poluilta, radoilta ja parkkipaikoilta (rungon etäisyys tien reunasta
  vähintään 0,8 m). Ajettavissa myös erikseen ilman välimuistia: `venv/bin/python tools/kartta/puut_teilta.py`.

Lähdeaineisto ladataan välimuistiin (n. 600 Mt: 9 laserlehteä, korkeusmallilehdet, maastotietokanta R4333L, R4333R,
R4334R). Korkeusmallin lehtijako alkaa idässä 308 000:sta (lehdet 2000 mod 6000), pohjoisessa 6 570 000:sta.
Puut piirtää `scripts/forest.gd` (kolme tarkkuustasoa, paikat varjostimessa datatekstuurista, rungot törmäävät
kameran lähellä). Tarkistuskuvat: `godot --path . -s tools/testit/tarkka_kuvat.gd -- <kansio>` (mökki) ja
`godot --path . -- --shot=<kansio>/v.png --scene=mokkivaala` (Vaala).
