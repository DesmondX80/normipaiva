# Karttadata: mistä se tulee ja miten aluetta laajennetaan

Pelin kylä (Saloinen) on tehty oikeasta kartta-aineistosta. Kaikki lähteet
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
  lännestä itään, kussakin ensin etelä, sitten pohjoinen). Esim. kylä = R4132H, R4134B, R4141G, R4143A. Tarkista tulos lehden omasta sijaintitiedosta (GeoTIFF-tagi 33922),
  jonka `Tiff.Info()` tulostaa.

## Ajotavat: PowerShell tai Python

Jokaisesta ajoskriptistä on kaksi samaa tulosta tuottavaa versiota:

- **PowerShell** (Windows PowerShell 5.1, C# käännetään `Add-Type`llä): `kyla_osm.ps1`, `kyla.ps1`.
- **Python 3** (vain standardikirjasto, ei numpyä eikä GDALia): `kyla_osm.py`, `kyla.py`
  (yhteinen kirjasto `kartta.py`). Python-versiot tuottavat samat tiedostot tavu tavulta; LZW-purku puhtaalla
  Pythonilla on hitaampi (kylän korkeusmalli muutamia minuutteja).

## Kylä (scripts/map_data.gd, scripts/map_osm.gd, assets/terrain/)

Kartan pikselit ovat yhdessä todellisessa kehyksessä (`kehys.ps1`, Pythonissa `kartta.py`): kaksi OSM-risteystä
kiinnittää sen, J_K (Ketunperäntie / Tarpiontie) = px (195, 765) ja J_PATO (Ketunperäntie / Patotie) = px (1304, 3778),
mittakaava n. 1,22 m/px. Uusi alue laajennetaan samaan kehykseen, jolloin kaikki kohteet osuvat kohdalleen.

1. **OSM-ote**: hae `map.osm` bbox-kyselyllä niin, että se kattaa uuden alueen (nykyinen: `bbox=24.43,64.595,24.53,64.672`).
   Koko alue ylittää API:n 50 000 solmun rajan, joten se haetaan leveyspiirien kaistoina (64.595–64.62, 64.62–64.645,
   64.645–64.672) ja yhdistetään yhdeksi otteeksi elementtien id:iden mukaan (sama solmu tai tie vain kerran).
   Pohjoisosa (Seuranmäki, Saloisten Reippari, Tokola, Tokolanperän rossirata) on karttapikseleissä negatiivisilla
   y:illä (`map_data.MAP_MIN`), jotta vanhat paikat pysyvät ennallaan.
2. **Tiet, rakennukset, maankäyttö** → `scripts/map_osm.gd` koko kartan alueelta (rajausruutu px skriptissä):
   - `powershell -File tools\kartta\kyla_osm.ps1 -Osm <map.osm>`
   - `python tools/kartta/kyla_osm.py --osm <map.osm> [--out <tiedosto>]`
   - `python tools/kartta/kyla_osm.py --osm <map.osm> --lansi`: läntinen laajennus (px x -260..-60, kirkko, kellotapuli
     ja hautausmaa) liitetään samoin; ote bbox `24.447,64.610,24.457,64.667` haetaan kolmena leveyspiirikaistana
     (64.610–64.630–64.648–64.667) ja yhdistetään id:iden mukaan. Korkeusmalli kattaa px x -550:een asti (maastoruudukon 300 m marginaali `MAP_MIN`:n länsipuolella).
   - `python tools/kartta/kyla_osm.py --osm <map.osm> --pohjoinen`: vain pohjoinen laajennus (px y -960..-60)
     liitetään olemassa olevan `map_osm.gd`:n osioiden loppuun, jolloin vanhan alueen kohteet pysyvät täsmälleen
     ennallaan. Saumassa kohteet leikataan samasta raakageometriasta kuin vanhassa otteessa (`SAUMA`-korjaukset
     skriptissä). Nykyinen `map_osm.gd` on tehty näin.

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

## Työkalut tässä kansiossa

| C# / PowerShell | Python | Tehtävä |
|---|---|---|
| `tm35.cs` | `kartta.py: tm35()` | WGS84/ETRS89 → ETRS-TM35FIN (JHS 197) |
| `tiff.cs` | `kartta.py: Tiff` | GeoTIFF-lukija (LZW, laatat) ilman GDALia |
| `mosaic.cs` | `kartta.py: Mosaic` | lehtien mosaiikki ja näytteistys |
| `osm.cs` | `kartta.py: Osm` | OSM-XML → kylän GDScript-vakiot |
| `kehys.ps1` | `kartta.py: px2tm, tm2px` | kylän kehys (px ↔ TM35) |
| `kyla_osm.ps1`, `kyla.ps1` | `kyla_osm.py`, `kyla.py` | ajoskriptit |
| `tarkista_alueet.gd` | | aluemonikulmioiden kolmioituvuus (Godot) |
