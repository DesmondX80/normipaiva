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

## Kylä (scripts/map_data.gd, scripts/map_osm.gd, assets/terrain/)

Kartan pikselit ovat yhdessä todellisessa kehyksessä (`kehys.ps1`): kaksi OSM-risteystä kiinnittää sen,
J_K (Ketunperäntie / Tarpiontie) = px (195, 765) ja J_PATO (Ketunperäntie / Patotie) = px (1304, 3778),
mittakaava n. 1,22 m/px. Uusi alue laajennetaan samaan kehykseen, jolloin kaikki kohteet osuvat kohdalleen.

1. **OSM-ote**: hae `map.osm` bbox-kyselyllä niin, että se kattaa uuden alueen (nykyinen: `bbox=24.43,64.595,24.53,64.66`).
2. **Tiet, rakennukset, maankäyttö**: `powershell -File tools\kartta\kyla_osm.ps1 -Osm <map.osm>` kirjoittaa
   `scripts/map_osm.gd`:n koko kartan alueelta. Rajausruutu (px) on skriptissä.
   Luokittelu (`osm.cs`): highway → highway/road/street/path, landuse/natural → metsä/pelto/suo/vesi,
   waterway → purot, building → talot (suunnattu pohjapiirros). Käsin tehdyt kohteet (vain se, mitä OSM:ssä
   ei ole, esim. Antinsuonkankaan laavu) ja pelipaikat ovat `map_data.gd`:ssä; päivitä `PLAY_AREA` ja
   pelipaikat, jos rajat muuttuvat. Tarkista paikat lopuksi testinäkymällä `--scene=placecheck`.
3. **Korkeudet**: lataa tarvittavat 2 m -lehdet ja aja
   `powershell -File tools\kartta\kyla.ps1 -Lehdet <kansio> [-Sheets R4132H,...]`. Se kirjoittaa
   `assets/terrain/korkeus.json` (metatiedot) ja `korkeus_mml.i16` (int16 cm, täsmälleen pelin 5 m maastoruudukon pisteissä, ilman keskiarvoa). Mosaiikin
   ja ruudukon rajat ovat skriptissä; laajenna niitä uuden alueen mukaan.
4. **Maasto peliin**: `godot --headless --path . -s tools/bake_terrain.gd` leipoo `korkeus.bin`in ja
   `pinnat.png`:n (järvet tasoitetaan `map_data.WATER`:n mukaan).

## Mökki (scripts/mokki.gd, assets/mokki/kartta.json)

Mökin alue (200 × 200 m) on osoitepisteen kehyksessä (x itään, z etelään, metreinä; origo 64.5054523 N,
26.6672225 E). `kartta.json` sisältää OSM-kohteet ja 2 m korkeusmallin (lehti R4333D, 2 m välein) samassa
kehyksessä. Uusi alue tehdään samoin: OSM-ote → metreiksi osoitepisteestä (lon × 111 320 × cos(lat), lat × 111 320)
ja korkeudet `Tiff`- ja `Tm35`-apureilla (ks. `kyla.ps1`).

## Työkalut tässä kansiossa

- `tm35.cs`: WGS84/ETRS89 → ETRS-TM35FIN (JHS 197).
- `tiff.cs`: GeoTIFF-lukija (LZW, laatat) ilman GDALia; `Tiff.Info(polku)` ja `Tiff.Window(x, y, w, h)`.
- `mosaic.cs`: lehtien mosaiikki ja näytteistys kartan pikseliruudukkoon.
- `osm.cs`: OSM-XML → kartan tiet, alueet ja rakennukset GDScript-vakioina.
- `kehys.ps1`: kylän kehys (px ↔ TM35), `kyla.ps1`: korkeudet, `kyla_osm.ps1`: OSM-aineisto.

Skriptit on tehty Windows PowerShell 5.1:lle (C# käännetään `Add-Type`llä, Pythonia tai GDALia ei tarvita).
