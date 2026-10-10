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
## Kartan kulmat: MAP_MIN (luoteiskulma) ja SIZE (kaakkoiskulma). Kartta jatkuu pohjoiseen negatiivisiin
## y-pikseleihin (Seuranmäki, Saloisten Reippari, Tokola ja Tokolanperän rossirata), jotta vanhat paikat pysyvät
## ennallaan.
const MAP_MIN := Vector2(0, -900)
const SIZE := Vector2(1620, 3960)
## Pelialue: koko kartta suorakaiteena (0..1620 × -900..3960): Seuranmäki ja Tokola pohjoisessa, kylä,
## Antinsuonkangas, koillisen asuinalue ja etelän Haapajärven tekojärven ranta kodalle. Reunoilla näkymätön seinä.
const PLAY_AREA := [MAP_MIN, Vector2(SIZE.x, MAP_MIN.y), SIZE, Vector2(MAP_MIN.x, SIZE.y)]

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
## Saloisten seuraintalo Seuranmäellä (OSM-rakennus): kirpputori ja huutokauppa sisällä (kirppis_interior.gd).
const SEURAINTALO := Vector2(394.3, -272.8)
## Saloisten Reippari, grillikioski seuraintalon vieressä (OSM retail-rakennus, amenity=fast_food) (#115).
const REIPPARI := Vector2(432.8, -282.4)
## Aaron kissan Miisun mahdolliset piilopaikat Tokolan ympäristössä (ilmoitustaulun sivutehtävä).
const MIISU_SPOTS := [Vector2(405, -668), Vector2(318, -650), Vector2(290, -790), Vector2(372, -470)]
## Tokola (#120): kauppias Tokolan vanha varasto Tokolantien varressa (keksitty paikka oikean historian pohjalta),
## vanhan Aaron talo (OSM, Tokolantie) ja Heinimäen laki (OSM natural=peak), jossa latvaton kuusi.
const TOKOLA_VARASTO := Vector2(350, -520)
const AARO_HOUSE := Vector2(362, -571)
const HEINIMAKI := Vector2(412, -684)
## Saloisten Pirtti, kotiseutumuseo (OSM tourism=museum, rakennus): Sulon pannun lahjoitus (#130).
const PIRTTI := Vector2(269.7, 439.9)
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
	Vector2(85.6, 541), Vector2(80.1, 521.8), SEURAINTALO, REIPPARI]

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
	["Seuranmäki", Vector2(470, -330)],
	["Tokola", Vector2(330, -600)],
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
## rata jatkuu länteen Valtatien yli kartan reunan taakse. Idässä rata kaartaa heti aseman jälkeen pohjoiseen
## (R ≥ 45 m) ja pujottelee talojen välistä (lähin seinä n. 7 m) suoraan pohjoiseen Tokolantien yli, kaartaa
## y = -200:ssa loivasti (R = 200 m) 13° koilliseen ja jatkuu suorana Seuranmäen länsipuolelta (lähin talo n. 17 m)
## kartan pohjoisreunan yli horisonttiin: ei kulje kylän läpi. RAIL_NE:n eteläpää on haettu tilahilahaulla
## rakennusten etäisyyskentästä ja pehmennetty; tiet ylitetään tasoristeyksinä.
const RAIL_NE := [
	Vector2(101.5, 503.9), Vector2(107.2, 503.7), Vector2(112.7, 503.2), Vector2(118.2, 502.4), Vector2(123.7, 501.1),
	Vector2(129.0, 499.1), Vector2(134.2, 496.5), Vector2(139.0, 493.3), Vector2(143.4, 489.5), Vector2(147.3, 485.2),
	Vector2(150.7, 480.4), Vector2(153.7, 475.3), Vector2(156.4, 470.0), Vector2(158.9, 464.5), Vector2(161.2, 459.0),
	Vector2(163.6, 453.5), Vector2(165.9, 448.0), Vector2(168.2, 442.4), Vector2(170.5, 436.9), Vector2(172.7, 431.3),
	Vector2(175.0, 425.8), Vector2(177.3, 420.3), Vector2(179.6, 414.7), Vector2(181.9, 409.2), Vector2(184.2, 403.6),
	Vector2(186.5, 398.1), Vector2(188.8, 392.5), Vector2(191.1, 387.0), Vector2(193.3, 381.4), Vector2(195.5, 375.8),
	Vector2(197.5, 370.2), Vector2(199.3, 364.5), Vector2(200.8, 358.7), Vector2(202.1, 352.9), Vector2(203.2, 347.0),
	Vector2(204.1, 341.1), Vector2(205.0, 335.1), Vector2(205.8, 329.2), Vector2(206.6, 323.3), Vector2(207.4, 317.3),
	Vector2(208.3, 311.4), Vector2(209.3, 305.5), Vector2(210.4, 299.6), Vector2(211.5, 293.7), Vector2(212.5, 287.9),
	Vector2(213.2, 282.0), Vector2(213.4, 276.1), Vector2(213.0, 270.2), Vector2(212.0, 264.4), Vector2(210.6, 258.7),
	Vector2(208.8, 253.0), Vector2(206.8, 247.4), Vector2(205.0, 241.7), Vector2(203.3, 236.0), Vector2(202.0, 230.2),
	Vector2(201.0, 224.3), Vector2(200.3, 218.4), Vector2(199.8, 212.4), Vector2(199.5, 206.4), Vector2(199.4, 200.4),
	Vector2(199.3, 194.4), Vector2(199.3, 188.4), Vector2(199.3, 182.4), Vector2(199.3, 176.4), Vector2(199.3, 170.4),
	Vector2(199.3, 164.4), Vector2(199.3, 158.4), Vector2(199.3, 152.4), Vector2(199.3, 146.4), Vector2(199.3, 140.4),
	Vector2(199.3, 134.4), Vector2(199.3, 128.4), Vector2(199.3, 122.4), Vector2(199.3, 116.4), Vector2(199.3, 110.4),
	Vector2(199.3, 104.4), Vector2(199.3, 98.4), Vector2(199.3, 92.4), Vector2(199.3, 86.4), Vector2(199.3, 80.4),
	Vector2(199.3, 74.4), Vector2(199.3, 68.4), Vector2(199.3, 62.4), Vector2(199.3, 56.4), Vector2(199.3, 50.4),
	Vector2(199.3, 44.4), Vector2(199.3, 38.4), Vector2(199.3, 32.4), Vector2(199.3, 26.4), Vector2(199.3, 20.4),
	Vector2(199.3, 14.4), Vector2(199.3, 8.4), Vector2(199.3, 2.4), Vector2(199.3, -3.6), Vector2(199.3, -9.6),
	Vector2(199.3, -15.6), Vector2(199.3, -21.6), Vector2(199.3, -27.6), Vector2(199.3, -33.6), Vector2(199.3, -39.6),
	Vector2(199.3, -45.6), Vector2(199.3, -51.6), Vector2(199.3, -57.6), Vector2(199.3, -63.6), Vector2(199.3, -69.6),
	Vector2(199.3, -75.6), Vector2(199.3, -81.6), Vector2(199.3, -87.6), Vector2(199.3, -93.6), Vector2(199.3, -99.6),
	Vector2(199.3, -105.6), Vector2(199.3, -111.6), Vector2(199.3, -117.6), Vector2(199.3, -123.6), Vector2(199.3, -129.6),
	Vector2(199.3, -135.6), Vector2(199.3, -141.6), Vector2(199.3, -147.6), Vector2(199.3, -153.6), Vector2(199.3, -159.6),
	Vector2(199.3, -165.6), Vector2(199.3, -171.6), Vector2(199.3, -177.6), Vector2(199.3, -183.6), Vector2(199.3, -189.6),
	Vector2(199.3, -195.6), Vector2(199.3, -200.0), Vector2(199.4, -206.7), Vector2(199.7, -213.4), Vector2(200.3, -220.0),
	Vector2(201.1, -226.7), Vector2(202.1, -233.3), Vector2(203.3, -239.9), Vector2(204.8, -246.4), Vector2(206.2, -252.2),
	Vector2(207.5, -258.1), Vector2(208.9, -263.9), Vector2(210.3, -269.8), Vector2(211.7, -275.6), Vector2(213.1, -281.4),
	Vector2(214.5, -287.3), Vector2(215.9, -293.1), Vector2(217.3, -298.9), Vector2(218.7, -304.8), Vector2(220.1, -310.6),
	Vector2(221.5, -316.4), Vector2(222.9, -322.3), Vector2(224.3, -328.1), Vector2(225.6, -334.0), Vector2(227.0, -339.8),
	Vector2(228.4, -345.6), Vector2(229.8, -351.5), Vector2(231.2, -357.3), Vector2(232.6, -363.1), Vector2(234.0, -369.0),
	Vector2(235.4, -374.8), Vector2(236.8, -380.6), Vector2(238.2, -386.5), Vector2(239.6, -392.3), Vector2(241.0, -398.2),
	Vector2(242.4, -404.0), Vector2(243.7, -409.8), Vector2(245.1, -415.7), Vector2(246.5, -421.5), Vector2(247.9, -427.3),
	Vector2(249.3, -433.2), Vector2(250.7, -439.0), Vector2(252.1, -444.8), Vector2(253.5, -450.7), Vector2(254.9, -456.5),
	Vector2(256.3, -462.4), Vector2(257.7, -468.2), Vector2(259.1, -474.0), Vector2(260.5, -479.9), Vector2(261.8, -485.7),
	Vector2(263.2, -491.5), Vector2(264.6, -497.4), Vector2(266.0, -503.2), Vector2(267.4, -509.0), Vector2(268.8, -514.9),
	Vector2(270.2, -520.7), Vector2(271.6, -526.5), Vector2(273.0, -532.4), Vector2(274.4, -538.2), Vector2(275.8, -544.1),
	Vector2(277.2, -549.9), Vector2(278.6, -555.7), Vector2(279.9, -561.6), Vector2(281.3, -567.4), Vector2(282.7, -573.2),
	Vector2(284.1, -579.1), Vector2(285.5, -584.9), Vector2(286.9, -590.7), Vector2(288.3, -596.6), Vector2(289.7, -602.4),
	Vector2(291.1, -608.3), Vector2(292.5, -614.1), Vector2(293.9, -619.9), Vector2(295.3, -625.8), Vector2(296.7, -631.6),
	Vector2(298.0, -637.4), Vector2(299.4, -643.3), Vector2(300.8, -649.1), Vector2(302.2, -654.9), Vector2(303.6, -660.8),
	Vector2(305.0, -666.6), Vector2(306.4, -672.5), Vector2(307.8, -678.3), Vector2(309.2, -684.1), Vector2(310.6, -690.0),
	Vector2(312.0, -695.8), Vector2(313.4, -701.6), Vector2(314.8, -707.5), Vector2(316.1, -713.3), Vector2(317.5, -719.1),
	Vector2(318.9, -725.0), Vector2(320.3, -730.8), Vector2(321.7, -736.7), Vector2(323.1, -742.5), Vector2(324.5, -748.3),
	Vector2(325.9, -754.2), Vector2(327.3, -760.0), Vector2(328.7, -765.8), Vector2(330.1, -771.7), Vector2(331.5, -777.5),
	Vector2(332.9, -783.3), Vector2(334.2, -789.2), Vector2(335.6, -795.0), Vector2(337.0, -800.9), Vector2(338.4, -806.7),
	Vector2(339.8, -812.5), Vector2(341.2, -818.4), Vector2(342.6, -824.2), Vector2(344.0, -830.0), Vector2(345.4, -835.9),
	Vector2(346.8, -841.7), Vector2(348.2, -847.5), Vector2(349.6, -853.4), Vector2(351.0, -859.2), Vector2(352.3, -865.0),
	Vector2(353.7, -870.9), Vector2(355.1, -876.7), Vector2(356.5, -882.6), Vector2(357.9, -888.4), Vector2(359.3, -894.2),
	Vector2(360.7, -900.1), Vector2(362.1, -905.9), Vector2(363.5, -911.7), Vector2(364.9, -917.6), Vector2(366.3, -923.4),
	Vector2(367.7, -929.2), Vector2(369.1, -935.1), Vector2(370.4, -940.9), Vector2(371.8, -946.8), Vector2(373.2, -952.6),
	Vector2(374.6, -958.4), Vector2(376.0, -964.3)
]
static var _railway := PackedVector2Array()


static func railway() -> PackedVector2Array:
	if not _railway.is_empty():
		return _railway
	var y := SHOP_BUILDING.y - 37.0
	var x := -1500.0
	while x < 100.0:
		_railway.append(Vector2(x, y))
		x += 8.0
	for q: Vector2 in RAIL_NE:
		_railway.append(q)
	var p := _railway[_railway.size() - 1]
	var d := (p - _railway[_railway.size() - 2]).normalized()
	while p.y > -1200.0:
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
