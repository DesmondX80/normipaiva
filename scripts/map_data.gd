extends RefCounted
## Saloisten (Raahe) kartta. Koordinaatit ovat karttapikseleitä (pohjoinen ylös); w() muuntaa maailmaan, pelissä
## 1 px = SCALE m. Koko kartta on yhdessä todellisessa kehyksessä (1 px ≈ 1,22 m ETRS-TM35FIN:ssä, ks.
## tools/kartta/kehys.ps1), joten kylä on vaakasuunnassa hieman tiivistetty.
##
## Koko kartan tiet, metsät, pellot, suot, vedet, purot ja rakennukset tulevat OpenStreetMapista generoidusta
## tiedostosta map_osm.gd. Tähän tiedostoon on tehty käsin vain se, mitä OSM:ssä ei ole: Antinsuonkankaan laavu ja
## sen polut sekä pelin paikat (koti, naapurit, jemmat, hahmojen paikat).
##
## KARTTADATAN LÄHTEET, jos aluetta laajennetaan tai lisätään (tarkemmin tools/kartta/LUEMINUT.md):
## - Tiet, rakennukset, maankäyttö: OpenStreetMap (ODbL). Ote rajausruudulla (lon/lat):
##     https://api.openstreetmap.org/api/0.6/map?bbox=<länsi>,<etelä>,<itä>,<pohjoinen>
##   (enintään 0,25 astetta² ja 50 000 solmua kerralla). Muunnos: tools/kartta/kyla_osm.ps1 -> map_osm.gd.
## - Korkeudet: Maanmittauslaitoksen korkeusmalli 2 m (CC BY 4.0), 6 x 6 km lehdet Kapsin peilistä:
##     https://kartat.kapsi.fi/files/korkeusmalli/hila_2m/etrs-tm35fin-n2000/<R4>/<R41>/<R4132H>.tif
##   Muunnos: tools/kartta/kyla.ps1 -> assets/terrain/korkeus.json + korkeus_mml.i16, sitten tools/bake_terrain.gd.
## - Osoitteet ja paikannimet: OpenStreetMap / Nominatim (https://nominatim.openstreetmap.org/search?q=...).

const T := preload("res://scripts/terrain.gd")
const Osm := preload("res://scripts/map_osm.gd")
const SCALE := 1.0
const ORIGIN := Vector2(450, 800)
const SIZE := Vector2(1620, 3960)
## Pelialue: koko kartta suorakaiteena (0..1620 × 0..3960): kylä, Antinsuonkangas, koillisen asuinalue ja etelän
## Haapajärven tekojärven ranta kodalle. Reunoilla näkymätön seinä.
const PLAY_AREA := [Vector2(0, 0), Vector2(1620, 0), Vector2(1620, 3960), Vector2(0, 3960)]

# Risteykset ja kiintopisteet (OpenStreetMapin teiltä).
const J_W := Vector2(125, 573)    # Ketunperäntie / Oikotie, K-Marketin kulma
const J_K := Vector2(195, 765)    # Ketunperäntie / Tarpiontie (kehyksen kiintopiste)
const J_T := Vector2(630, 1186)   # Tarpiontie / Kangastie / Honganpalontie
const J_H1 := Vector2(821, 1161)  # Järvikuja / Ristontie
const J_H2 := Vector2(844, 1237)  # Järvikujan eteläpää: laavupolku alkaa

const J_KL := Vector2(492, 2380)   # Ketunperäntie / laavupolku
const LAAVU := Vector2(833, 2345)  # nuotiopaikka Antinsuonkankaalla
# Haapajärven tekoaltaan kota ja lintutorni (OpenStreetMap), n. 2 km laavulta polkua pitkin.
const KOTA := Vector2(1409, 3745)  # OSM: amenity=shelter, tourism=wilderness_hut
const LINTUTORNI := Vector2(1417, 3747)  # OSM: man_made=tower (world.gd kääntää kodan tornin tähän)
const J_PATO := Vector2(1304, 3778)  # Ketunperäntie / Patotie (kehyksen kiintopiste)
## Pannu-Sulon pontikkapannu Antinsuonkankaan kuusikossa, Ketunperäntien ja laavupolun puolivälissä.
## Ei näy kartoilla; kodan tarinoissa mainitaan ohimennen.
const PONTIKKA := Vector2(560, 1850)

## Koti: Järvikuja 1 (OSM-rakennus kadun länsipuolella, julkisivu itään kadulle; malli hieman taaempana tontilla,
## jotta etupiha mahtuu), autotalli etelässä,
## takapihan nurmikko ja komposti lännessä.
const HOME_BUILDING := Vector2(807.8, 1180.8)
const HOME_YAW_DIR := Vector2(0.967, -0.256)  # julkisivun suunta (kohti Järvikujaa)
const HOME_ZONE := Vector2(829, 1192)  # Järvikujalla kodin edessä (aloitus- ja paluupaikka)
const GARAGE := Vector2(818.1, 1197.6)  # kodin autotalli
const COMPOST := Vector2(803, 1196)  # kompostilaatikko talon takana (jemma)
## Kotipihan nurmikko talon takana talon suuntaisesti (leikkuuminipeli): keskipiste, koko (syvyys talosta poispäin ×
## pituus talon suuntaan) ja paikallisen x-akselin suunta (= julkisivun suunta). Takaseinästä 2 m.
const LAWN_CENTER := Vector2(796.2, 1183.9)
const LAWN_SIZE := Vector2(10, 14)
const LAWN_AXIS := HOME_YAW_DIR
const MOWER_PARK := Vector2(798.4, 1192.1)  # ruohonleikkurin paikka nurmikon eteläreunalla
const SHOP_BUILDING := Vector2(86, 541)
const SHOP_ZONE := Vector2(90, 567)
## Naapuritalot (world.gd _build_neighbors) OSM-rakennusten keskipisteissä; malli tehdään OSM-pohjan mukaan.
## Arto asuu heti vasemmalla (kodin eteläpuolella samalla puolella Järvikujaa, autotallin takana), Pekka Lehtikujan
## päässä (itäpuolen iso talo, julkisivu Lehtikujalle) ja Sinikka Järvikujan vastapuolella.
const NEIGHBOR_ARTO := Vector2(820.6, 1219.9)
const NEIGHBOR_PEKKA := Vector2(868.8, 1108.7)
const NEIGHBOR_SINIKKA := Vector2(855.5, 1204.2)
const MAILBOX := Vector2(814, 1169)
## OSM-rakennukset, joiden tilalle tehdään oma malli (koti, autotalli, naapurit, kauppa).
const OWN_BUILDINGS := [Vector2(812.4, 1177.9), GARAGE, NEIGHBOR_ARTO, NEIGHBOR_PEKKA, NEIGHBOR_SINIKKA,
	Vector2(85.6, 541), Vector2(80.1, 521.8)]

## type: highway | road | street | path. h = katuvalot/kylämäisyys tien varrella (0..1).
## Tiet ja polut: Osm.ROADS (OpenStreetMap). Tässä vain käsin tehdyt laavupolut (laavu ei ole OSM:ssä).
const ROADS_SOUTH := [
	# Metsäpolut Antinsuonkankaan laavulle: Järvikujan päästä etelään ja laavulta länteen Ketunperäntielle.
	{"type": "path", "name": "", "h": 0.0, "pts": [
		J_H2, Vector2(846, 1300), Vector2(860, 1420), Vector2(845, 1560), Vector2(800, 1690), Vector2(805, 1933),
		Vector2(832, 2161), Vector2(836, 2300), LAAVU]},
	{"type": "path", "name": "", "h": 0.0, "pts": [LAAVU, Vector2(790, 2372), Vector2(720, 2395), Vector2(600, 2400), J_KL]},
]
const ROADS := Osm.ROADS + ROADS_SOUTH

const FORESTS := Osm.FORESTS

## Aukeat metsän keskellä (ei puita). OSM:n mukaan Antinsuonkankaan kautta ei kulje voimalinjaa, joten tyhjä.
const CLEARINGS := []

## Hakkuuaukeat (ilmakuvasta Järvikujan kaakkoispuolelta): kantoja, hakkuutähteitä ja muutama siemenpuu.
const CLEARCUTS := [
	[Vector2(868, 1262), Vector2(940, 1250), Vector2(945, 1380), Vector2(895, 1385), Vector2(870, 1330)],
]
## Pellot, suot, vedet ja purot: OpenStreetMap (map_osm.gd).
const FIELDS := Osm.FIELDS
const BOGS := Osm.BOGS
const WATER := Osm.WATER
const STREAMS := Osm.STREAMS

## Saloisten agilitykenttä (OpenStreetMap) reitin varrella.
const AGILITY := [Vector2(333, 516), Vector2(383, 516), Vector2(383, 554), Vector2(333, 554)]

const PLACE_NAMES := [
	["Saloinen", Vector2(500, 40)],
	["Tarpio", Vector2(430, 1580)],
	["Kuusiluoto", Vector2(230, 1080)],
	["Pilkkarinneva", Vector2(380, 1050)],
	["Honganpalo", Vector2(900, 900)],
	["Kiilinlampi", Vector2(808, 700)],
	["Hamppulampi", Vector2(628, 1330)],
	["Antinsuonkangas", Vector2(640, 2250)],
	# Etelä
	["Haapajärven tekojärvi", Vector2(1540, 3560)],
]

## Jyväjemmarin traktorin parkkipaikka keskipellon länsilaidalla ja paalimuovit.
const TRACTOR_POS := Vector2(270, 745)
const BALES := [Vector2(215, 710), Vector2(222, 725), Vector2(230, 740), Vector2(218, 755), Vector2(290, 745), Vector2(300, 722)]

## Kiilinlammen grillikatos (turvapaikka Päiviltä) lammen etelärannalla OSM:n taukopaikan
## (tourism=picnic_site, (806, 825)) kohdalla, rannan ja rantapolun välissä.
const GRILLIKATOS := Vector2(806, 812)

## Vieraan koiran mahdolliset paikat metsänreunassa teiden ja polkujen varrella (yksi arvotaan päivässä).
const STRAY_SPOTS := [Vector2(870, 1260), Vector2(700, 700), Vector2(215, 860), Vector2(160, 1260), Vector2(620, 1690),
	Vector2(760, 1480)]

## Juntin mahdolliset olinpaikat reitin varrella.
const JUNTTI_SPOTS := [Vector2(160, 690), Vector2(311, 776), Vector2(452, 841), Vector2(235, 500), Vector2(688, 1118)]


## Saloisten rata karttapikseleinä (1 px = 1 m): asemaraide K-Marketin takana (world.gd _build_station), josta
## rata jatkuu länteen Valtatien yli kartan reunan taakse ja idässä Ketunperäntien jälkeen kaartaa etelään
## (R 140 m, 60°) ja jatkuu suorana kaakkoon kartan reunan taakse. Linja on haettu kylän rakennusten välistä
## (lähin seinä n. 5 m), tiet ylitetään tasoristeyksinä.
const RAIL_ARC_X := 110.0
const RAIL_ARC_R := 140.0
const RAIL_ARC_TURN := PI / 3.0
static var _railway := PackedVector2Array()


static func railway() -> PackedVector2Array:
	if not _railway.is_empty():
		return _railway
	var y := SHOP_BUILDING.y - 37.0
	var x := -1500.0
	while x < RAIL_ARC_X:
		_railway.append(Vector2(x, y))
		x += 8.0
	var steps := int(RAIL_ARC_R * RAIL_ARC_TURN / 4.0)
	for k in steps + 1:
		var th := RAIL_ARC_TURN * k / steps
		_railway.append(Vector2(RAIL_ARC_X + RAIL_ARC_R * sin(th), y + RAIL_ARC_R - RAIL_ARC_R * cos(th)))
	var p := _railway[_railway.size() - 1]
	var d := Vector2(cos(RAIL_ARC_TURN), sin(RAIL_ARC_TURN))
	while p.x < SIZE.x + 1200.0 and p.y < SIZE.y + 1200.0:
		p += d * 8.0
		_railway.append(p)
	return _railway


## Karttapikseli maailmaan maaston pinnalle (y = maaston korkeus).
static func w(p: Vector2) -> Vector3:
	var x := (p.x - ORIGIN.x) * SCALE
	var z := (p.y - ORIGIN.y) * SCALE
	return Vector3(x, T.h(x, z), z)


static func w2(p: Vector2) -> Vector2:
	return (p - ORIGIN) * SCALE


static func to_px(world: Vector3) -> Vector2:
	return Vector2(world.x, world.z) / SCALE + ORIGIN
