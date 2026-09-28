extends RefCounted
## Saloisten (Raahe) kartta jäljitettynä karttakuvista. Koordinaatit ovat ensimmäisen kuvan pikseleitä
## (pohjoinen ylös, 300 m ≈ 225 px); w() muuntaa maailmaan, pelissä 1 px = SCALE m (hieman tiivistetty).
## Eteläosa (y > 1580, Antinsuonkangas ja laavu) on sovitettu MML-karttaan kahden kiintopisteen avulla:
## koti (Järvikuja 1) ja Ketunperäntien–Tarpiontien risteys.

const T := preload("res://scripts/terrain.gd")
const SCALE := 1.0
const ORIGIN := Vector2(450, 800)
const SIZE := Vector2(1620, 3960)
## Pelialue: alkuperäinen kylä + Antinsuonkangas (0..897 × 0..2500) ja etelän laajennus kodalle
## Haapajärven tekojärven rannalle (400..1620 × 2500..3960). Reunoilla näkymätön seinä.
const PLAY_AREA := [Vector2(0, 0), Vector2(897, 0), Vector2(897, 2500), Vector2(1620, 2500), Vector2(1620, 3960),
	Vector2(400, 3960), Vector2(400, 2500), Vector2(0, 2500)]

# Risteykset (jaettu teiden kesken, jotta tieverkko kytkeytyy).
const J_W := Vector2(130, 600)    # EV10 / Ketunperäntie / Saloistentie, K-Marketin kulma
const J_K := Vector2(195, 765)    # Ketunperäntie / Tarpiontie
const J_T := Vector2(600, 1125)   # Tarpiontie / Kangastie / pääväylä
const J_A := Vector2(718, 1068)   # asuinalueen katu / pääväylä / kotikatu
const J_E := Vector2(648, 870)    # asuinalueen katu / itään menevä tie
const J_N := Vector2(340, 225)    # Saloistentie / kylän itätie
const J_R2 := Vector2(680, 960)
const J_R3 := Vector2(700, 1020)
const J_H1 := Vector2(795, 1150)
const J_H2 := Vector2(785, 1200)

const J_KL := Vector2(446, 2380)   # Ketunperäntie / laavupolku
const LAAVU := Vector2(833, 2345)  # nuotiopaikka Antinsuonkankaalla
# Haapajärven tekoaltaan kota ja lintutorni (OpenStreetMap), n. 2 km laavulta polkua pitkin.
const KOTA := Vector2(1403, 3742)
const LINTUTORNI := Vector2(1413, 3748)
const J_PATO := Vector2(1304, 3778)  # Ketunperäntie / Patotie

const HOME_ZONE := Vector2(785, 1195)
const HOME_BUILDING := Vector2(808, 1178)
const GARAGE := Vector2(812, 1213)  # kodin autotalli
const COMPOST := Vector2(817, 1186)  # kompostilaatikko talon takana (jemma)
const SHOP_BUILDING := Vector2(75, 570)
const SHOP_ZONE := Vector2(80, 596)

## type: highway | road | street | path. h = talotiheys tien varrella (0..1).
const ROADS := [
	{"type": "highway", "name": "Valtatie 8", "h": 0.0, "pts": [
		Vector2(300, 0), Vector2(240, 110), Vector2(170, 230), Vector2(90, 380), Vector2(40, 470), Vector2(0, 590)]},
	{"type": "road", "name": "EV10", "h": 0.0, "pts": [Vector2(0, 625), Vector2(60, 612), J_W]},
	{"type": "road", "name": "", "h": 0.3, "pts": [Vector2(0, 445), Vector2(60, 490), Vector2(105, 535), J_W]},
	{"type": "road", "name": "Saloistentie", "h": 0.55, "pts": [
		J_W, Vector2(185, 540), Vector2(245, 470), Vector2(290, 380), J_N, Vector2(385, 120), Vector2(420, 40), Vector2(430, 0)]},
	{"type": "road", "name": "Ketunperäntie", "h": 0.15, "pts": [
		J_W, Vector2(165, 680), J_K, Vector2(190, 880), Vector2(175, 1000), Vector2(185, 1100),
		Vector2(215, 1300), Vector2(225, 1500), Vector2(239, 1884), Vector2(368, 2178), J_KL, Vector2(492, 2500),
		Vector2(515, 2554), Vector2(528, 2577), Vector2(665, 2755), Vector2(889, 2921), Vector2(1021, 3031),
		Vector2(1038, 3052), Vector2(1060, 3103), Vector2(1196, 3454), Vector2(1290, 3710), J_PATO, Vector2(1335, 4026)]},
	{"type": "road", "name": "Tarpiontie", "h": 0.2, "pts": [
		J_K, Vector2(320, 790), Vector2(440, 850), Vector2(505, 955), Vector2(560, 1040), J_T]},
	{"type": "road", "name": "Kangastie", "h": 0.5, "pts": [
		J_T, Vector2(560, 1220), Vector2(530, 1300), Vector2(545, 1420), Vector2(555, 1580)]},
	{"type": "road", "name": "", "h": 0.2, "pts": [
		Vector2(380, 1350), Vector2(440, 1330), Vector2(520, 1250), J_T, J_A, Vector2(800, 1012), Vector2(897, 960)]},
	{"type": "road", "name": "", "h": 0.3, "pts": [
		J_N, Vector2(460, 245), Vector2(560, 200), Vector2(640, 160), Vector2(700, 120), Vector2(800, 150), Vector2(897, 140)]},
	{"type": "street", "name": "", "h": 0.8, "pts": [Vector2(385, 120), Vector2(470, 100), Vector2(560, 60), Vector2(620, 20)]},
	{"type": "street", "name": "", "h": 0.7, "pts": [Vector2(290, 380), Vector2(220, 330), Vector2(200, 270)]},
	# Asuinalue pääväylän pohjoispuolella (reitti kulkee tästä).
	{"type": "street", "name": "", "h": 0.8, "pts": [Vector2(655, 800), J_E, J_R2, J_R3, J_A]},
	{"type": "road", "name": "", "h": 0.3, "pts": [Vector2(600, 885), J_E, Vector2(760, 850), Vector2(897, 828)]},
	{"type": "street", "name": "", "h": 0.9, "pts": [Vector2(560, 930), Vector2(610, 900), Vector2(600, 885)]},
	{"type": "street", "name": "", "h": 0.9, "pts": [Vector2(550, 1000), Vector2(640, 965), J_R2]},
	{"type": "street", "name": "", "h": 0.9, "pts": [Vector2(575, 1062), Vector2(640, 1040), J_R3]},
	# Järvikuja (koti: Järvikuja 1) ja sivukadut.
	{"type": "street", "name": "Järvikuja", "h": 0.8, "pts": [J_A, Vector2(770, 1056), Vector2(800, 1092), J_H1, J_H2]},
	{"type": "street", "name": "", "h": 0.9, "pts": [Vector2(640, 1160), Vector2(720, 1135), J_H1]},
	{"type": "street", "name": "", "h": 0.9, "pts": [Vector2(650, 1235), Vector2(740, 1218), J_H2]},
	# Tarpio.
	{"type": "street", "name": "Lampitie", "h": 0.9, "pts": [
		Vector2(270, 1500), Vector2(340, 1490), Vector2(420, 1500), Vector2(545, 1420)]},
	{"type": "street", "name": "", "h": 0.9, "pts": [Vector2(300, 1400), Vector2(400, 1420), Vector2(420, 1500)]},
	{"type": "street", "name": "", "h": 0.9, "pts": [Vector2(545, 1420), Vector2(620, 1440), Vector2(720, 1450)]},
	{"type": "street", "name": "", "h": 0.9, "pts": [Vector2(530, 1300), Vector2(610, 1370), Vector2(680, 1380)]},
	# Pyöräreitti pellon laitaa ja kentän ohi kaupalle (autolla ei pääse).
	{"type": "path", "name": "", "h": 0.0, "pts": [
		Vector2(655, 800), Vector2(630, 800), Vector2(545, 655), Vector2(300, 620), Vector2(290, 590),
		Vector2(250, 530), Vector2(225, 510), Vector2(185, 530), Vector2(160, 570), J_W]},
	{"type": "path", "name": "", "h": 0.0, "pts": [
		Vector2(560, 655), Vector2(620, 700), Vector2(700, 690), Vector2(760, 700), Vector2(820, 760), Vector2(897, 770)]},
	{"type": "path", "name": "", "h": 0.0, "pts": [Vector2(700, 690), Vector2(690, 600), Vector2(740, 520), Vector2(830, 470)]},
	# Metsäpolut Antinsuonkankaan laavulle: kotoa etelään ja laavulta länteen Ketunperäntielle.
	{"type": "path", "name": "", "h": 0.0, "pts": [
		J_H2, Vector2(770, 1290), Vector2(765, 1390), Vector2(781, 1670), Vector2(805, 1933), Vector2(832, 2161),
		Vector2(836, 2300), LAAVU]},
	{"type": "path", "name": "", "h": 0.0, "pts": [LAAVU, Vector2(790, 2372), Vector2(720, 2395), Vector2(600, 2400), J_KL]},
	# Kotapolku laavulta Haapajärven tekoaltaan kodalle (metsäautotie ja polku, OpenStreetMap).
	{"type": "path", "name": "Kotapolku", "h": 0.0, "pts": [
		LAAVU, Vector2(831, 2368), Vector2(812, 2393), Vector2(808, 2410), Vector2(834, 2495), Vector2(950, 2806), Vector2(958, 2809), Vector2(966, 2806), Vector2(975, 2801), Vector2(988, 2785), Vector2(994, 2791), Vector2(1054, 2953), Vector2(1066, 2978), Vector2(1072, 3000), Vector2(1079, 3011), Vector2(1088, 3015), Vector2(1112, 2995), Vector2(1138, 2955), Vector2(1159, 2931), Vector2(1234, 3157), Vector2(1253, 3223), Vector2(1282, 3299), Vector2(1306, 3373), Vector2(1335, 3448), Vector2(1386, 3617), Vector2(1387, 3634), Vector2(1367, 3686), Vector2(1360, 3712), Vector2(1357, 3736), Vector2(1364, 3744), Vector2(1383, 3753), Vector2(1393, 3753)]},
	{"type": "path", "name": "Patotie", "h": 0.0, "pts": [Vector2(1372, 3568), Vector2(1352, 3668), Vector2(1327, 3726), Vector2(1314, 3769), J_PATO]},
]

const FORESTS := [
	[Vector2(545, 460), Vector2(600, 440), Vector2(700, 445), Vector2(800, 430), Vector2(897, 425),
		Vector2(897, 815), Vector2(760, 842), Vector2(690, 830), Vector2(670, 760), Vector2(620, 720), Vector2(560, 645)],
	[Vector2(210, 790), Vector2(330, 800), Vector2(360, 850), Vector2(300, 890), Vector2(205, 880)],
	[Vector2(150, 920), Vector2(280, 930), Vector2(330, 1000), Vector2(320, 1030), Vector2(250, 1160),
		Vector2(160, 1150), Vector2(140, 1030)],
	[Vector2(0, 1150), Vector2(120, 1180), Vector2(200, 1250), Vector2(205, 1400), Vector2(120, 1450), Vector2(0, 1420)],
	[Vector2(240, 1200), Vector2(380, 1190), Vector2(470, 1260), Vector2(430, 1320), Vector2(300, 1335), Vector2(240, 1280)],
	[Vector2(720, 1270), Vector2(897, 1230), Vector2(897, 1500), Vector2(760, 1480), Vector2(720, 1390)],
	[Vector2(0, 100), Vector2(120, 90), Vector2(170, 200), Vector2(120, 330), Vector2(50, 380), Vector2(0, 370)],
	[Vector2(820, 180), Vector2(897, 170), Vector2(897, 320), Vector2(830, 300)],
	[Vector2(0, 700), Vector2(110, 710), Vector2(150, 850), Vector2(120, 1000), Vector2(0, 1050)],
	[Vector2(380, 420), Vector2(520, 430), Vector2(540, 520), Vector2(470, 560), Vector2(390, 530)],
	# Antinsuonkangas ja Puntarinmäen suunta: metsää lähes koko eteläosa.
	[Vector2(0, 1470), Vector2(200, 1460), Vector2(265, 1560), Vector2(560, 1600), Vector2(700, 1500),
		Vector2(897, 1505), Vector2(897, 2500), Vector2(0, 2500)],
	# Etelän metsä kodalle asti (vesi ja suot jätetään puista pois).
	[Vector2(400, 2500), Vector2(1620, 2500), Vector2(1620, 3960), Vector2(400, 3960)],
]

## Aukeat metsän keskellä (voimalinjan johtoaukea): ei puita.
const CLEARINGS := [
	[Vector2(724, 1600), Vector2(754, 1600), Vector2(876, 2500), Vector2(846, 2500)],
]

## Hakkuuaukeat (ilmakuvasta Järvikujan kaakkoispuolelta): kantoja, hakkuutähteitä ja muutama siemenpuu.
const CLEARCUTS := [
	[Vector2(812, 1212), Vector2(897, 1196), Vector2(897, 1335), Vector2(838, 1330), Vector2(815, 1280)],
]

## Viljelty pelto keskellä (ei puita).
const FIELDS := [
	[Vector2(320, 640), Vector2(540, 665), Vector2(620, 790), Vector2(430, 830), Vector2(340, 790)],
	[Vector2(430, 290), Vector2(620, 280), Vector2(700, 380), Vector2(560, 420), Vector2(440, 400)],
	[Vector2(600, 2050), Vector2(652, 2045), Vector2(657, 2170), Vector2(605, 2172)],
	[Vector2(812, 2236), Vector2(862, 2232), Vector2(866, 2282), Vector2(818, 2290)],
]

const BOGS := [
	[Vector2(330, 1050), Vector2(440, 1040), Vector2(470, 1180), Vector2(345, 1190)],
	[Vector2(690, 2255), Vector2(752, 2248), Vector2(765, 2335), Vector2(700, 2350)],
	# Etelä: suot ja ruovikot tekojärven ympärillä (OpenStreetMap).
	[Vector2(1394, 3882), Vector2(1399, 3896), Vector2(1392, 3903), Vector2(1377, 3908), Vector2(1373, 3907), Vector2(1362, 3891), Vector2(1364, 3884), Vector2(1386, 3880)],
	[Vector2(1600, 2634), Vector2(1605, 2638), Vector2(1617, 2657), Vector2(1615, 2664), Vector2(1607, 2665), Vector2(1599, 2656), Vector2(1595, 2634)],
	[Vector2(1467, 3610), Vector2(1472, 3645), Vector2(1481, 3668), Vector2(1504, 3707), Vector2(1515, 3755), Vector2(1496, 3811), Vector2(1503, 3852), Vector2(1503, 3876), Vector2(1497, 3903), Vector2(1479, 3933), Vector2(1453, 3960), Vector2(1379, 3960), Vector2(1374, 3957), Vector2(1367, 3951), Vector2(1366, 3944), Vector2(1369, 3938), Vector2(1379, 3933), Vector2(1407, 3923), Vector2(1422, 3909), Vector2(1424, 3896), Vector2(1417, 3890), Vector2(1413, 3874), Vector2(1413, 3834), Vector2(1419, 3810), Vector2(1433, 3778), Vector2(1428, 3766), Vector2(1432, 3760), Vector2(1457, 3749), Vector2(1461, 3734), Vector2(1457, 3726), Vector2(1434, 3728), Vector2(1420, 3713), Vector2(1429, 3675), Vector2(1437, 3652), Vector2(1445, 3613), Vector2(1456, 3606)],
	[Vector2(1620, 3716), Vector2(1614, 3726), Vector2(1600, 3731), Vector2(1594, 3739), Vector2(1593, 3750), Vector2(1564, 3751), Vector2(1537, 3761), Vector2(1529, 3760), Vector2(1529, 3752), Vector2(1516, 3744), Vector2(1536, 3746), Vector2(1548, 3743), Vector2(1552, 3739), Vector2(1551, 3725), Vector2(1557, 3711), Vector2(1566, 3699), Vector2(1583, 3686), Vector2(1599, 3678), Vector2(1616, 3677), Vector2(1620, 3674)],
	[Vector2(1604, 3255), Vector2(1604, 3277), Vector2(1602, 3283), Vector2(1597, 3282), Vector2(1598, 3289), Vector2(1594, 3293), Vector2(1583, 3290), Vector2(1575, 3280), Vector2(1571, 3269), Vector2(1575, 3257), Vector2(1583, 3251), Vector2(1613, 3249)],
	[Vector2(1068, 2835), Vector2(1070, 2844), Vector2(1067, 2862), Vector2(1061, 2871), Vector2(1035, 2891), Vector2(1011, 2831), Vector2(1023, 2833), Vector2(1062, 2831)],
	[Vector2(1030, 2901), Vector2(1012, 2903), Vector2(993, 2914), Vector2(1001, 2873), Vector2(996, 2858), Vector2(990, 2854), Vector2(975, 2854), Vector2(959, 2866), Vector2(937, 2867), Vector2(922, 2872), Vector2(904, 2885), Vector2(901, 2894), Vector2(903, 2906), Vector2(893, 2898), Vector2(892, 2882), Vector2(900, 2869), Vector2(911, 2859), Vector2(956, 2837), Vector2(1006, 2827)],
	[Vector2(948, 2981), Vector2(944, 2987), Vector2(923, 2998), Vector2(903, 3018), Vector2(895, 3019), Vector2(893, 3013), Vector2(907, 2998), Vector2(912, 2988), Vector2(907, 2964), Vector2(894, 2937), Vector2(897, 2934)],
	[Vector2(824, 2683), Vector2(819, 2712), Vector2(820, 2725), Vector2(827, 2734), Vector2(840, 2736), Vector2(842, 2739), Vector2(835, 2760), Vector2(824, 2775), Vector2(791, 2809), Vector2(784, 2816), Vector2(778, 2813), Vector2(771, 2765), Vector2(800, 2723), Vector2(800, 2696), Vector2(806, 2684), Vector2(816, 2679)],
	[Vector2(1281, 3749), Vector2(1282, 3763), Vector2(1275, 3774), Vector2(1258, 3780), Vector2(1245, 3779), Vector2(1234, 3766), Vector2(1235, 3757), Vector2(1240, 3752), Vector2(1270, 3745)],
	[Vector2(1000, 3275), Vector2(1001, 3316), Vector2(993, 3402), Vector2(988, 3418), Vector2(975, 3430), Vector2(932, 3449), Vector2(926, 3445), Vector2(922, 3423), Vector2(931, 3369), Vector2(970, 3275), Vector2(980, 3266), Vector2(990, 3265)],
	[Vector2(1009, 3221), Vector2(1005, 3271), Vector2(1004, 3336), Vector2(998, 3372), Vector2(998, 3421), Vector2(994, 3435), Vector2(981, 3444), Vector2(920, 3469), Vector2(895, 3485), Vector2(880, 3513), Vector2(857, 3575), Vector2(836, 3611), Vector2(829, 3614), Vector2(826, 3610), Vector2(830, 3603), Vector2(843, 3586), Vector2(859, 3536), Vector2(885, 3472), Vector2(902, 3454), Vector2(922, 3423), Vector2(926, 3445), Vector2(932, 3449), Vector2(975, 3430), Vector2(988, 3418), Vector2(993, 3402), Vector2(994, 3378), Vector2(999, 3348), Vector2(1000, 3275), Vector2(990, 3265), Vector2(980, 3266), Vector2(970, 3275), Vector2(988, 3228), Vector2(995, 3218), Vector2(1001, 3216)],
]

const WATER := [
	[Vector2(725, 720), Vector2(760, 712), Vector2(778, 745), Vector2(758, 792), Vector2(730, 782)],
	[Vector2(580, 1295), Vector2(620, 1285), Vector2(632, 1320), Vector2(600, 1347), Vector2(574, 1326)],
	# Etelä: Haapajärven tekojärvi (leikattu pelialueeseen) ja lammet (OpenStreetMap).
	[Vector2(1920, 2823), Vector2(1920, 4227), Vector2(1899, 4232), Vector2(1868, 4248), Vector2(1865, 4259), Vector2(1863, 4260), Vector2(1412, 4260), Vector2(1413, 4259), Vector2(1408, 4257), Vector2(1416, 4254), Vector2(1416, 4247), Vector2(1421, 4241), Vector2(1421, 4206), Vector2(1427, 4175), Vector2(1442, 4139), Vector2(1444, 4118), Vector2(1459, 4089), Vector2(1466, 4087), Vector2(1471, 4082), Vector2(1471, 4071), Vector2(1483, 4058), Vector2(1486, 4050), Vector2(1488, 4032), Vector2(1525, 3999), Vector2(1541, 3977), Vector2(1539, 3948), Vector2(1553, 3933), Vector2(1554, 3926), Vector2(1569, 3916), Vector2(1563, 3886), Vector2(1570, 3866), Vector2(1589, 3847), Vector2(1598, 3850), Vector2(1601, 3847), Vector2(1599, 3842), Vector2(1605, 3833), Vector2(1604, 3796), Vector2(1607, 3788), Vector2(1603, 3768), Vector2(1593, 3750), Vector2(1594, 3739), Vector2(1600, 3731), Vector2(1614, 3726), Vector2(1638, 3687), Vector2(1669, 3665), Vector2(1675, 3656), Vector2(1691, 3653), Vector2(1710, 3641), Vector2(1721, 3627), Vector2(1728, 3614), Vector2(1730, 3597), Vector2(1747, 3582), Vector2(1749, 3576), Vector2(1758, 3508), Vector2(1768, 3492), Vector2(1788, 3471), Vector2(1786, 3456), Vector2(1795, 3432), Vector2(1804, 3423), Vector2(1813, 3406), Vector2(1822, 3375), Vector2(1848, 3358), Vector2(1846, 3346), Vector2(1827, 3338), Vector2(1808, 3343), Vector2(1803, 3341), Vector2(1798, 3330), Vector2(1792, 3327), Vector2(1780, 3329), Vector2(1774, 3333), Vector2(1771, 3343), Vector2(1758, 3345), Vector2(1749, 3352), Vector2(1746, 3361), Vector2(1737, 3368), Vector2(1734, 3376), Vector2(1724, 3378), Vector2(1717, 3387), Vector2(1705, 3394), Vector2(1688, 3419), Vector2(1673, 3460), Vector2(1671, 3480), Vector2(1655, 3509), Vector2(1626, 3538), Vector2(1620, 3537), Vector2(1612, 3546), Vector2(1593, 3553), Vector2(1588, 3561), Vector2(1580, 3563), Vector2(1575, 3558), Vector2(1565, 3560), Vector2(1558, 3552), Vector2(1549, 3559), Vector2(1523, 3566), Vector2(1493, 3566), Vector2(1486, 3561), Vector2(1483, 3546), Vector2(1474, 3547), Vector2(1467, 3528), Vector2(1460, 3530), Vector2(1453, 3543), Vector2(1451, 3556), Vector2(1444, 3558), Vector2(1439, 3573), Vector2(1433, 3580), Vector2(1425, 3607), Vector2(1433, 3607), Vector2(1435, 3611), Vector2(1429, 3614), Vector2(1426, 3623), Vector2(1419, 3627), Vector2(1414, 3638), Vector2(1413, 3653), Vector2(1404, 3668), Vector2(1394, 3701), Vector2(1394, 3709), Vector2(1400, 3722), Vector2(1407, 3724), Vector2(1419, 3735), Vector2(1423, 3748), Vector2(1418, 3796), Vector2(1405, 3807), Vector2(1405, 3819), Vector2(1408, 3835), Vector2(1404, 3866), Vector2(1406, 3879), Vector2(1417, 3903), Vector2(1405, 3909), Vector2(1368, 3913), Vector2(1359, 3905), Vector2(1359, 3897), Vector2(1351, 3880), Vector2(1352, 3865), Vector2(1345, 3844), Vector2(1343, 3821), Vector2(1349, 3802), Vector2(1386, 3773), Vector2(1402, 3771), Vector2(1405, 3767), Vector2(1405, 3758), Vector2(1414, 3753), Vector2(1415, 3736), Vector2(1410, 3730), Vector2(1368, 3732), Vector2(1365, 3727), Vector2(1364, 3719), Vector2(1373, 3689), Vector2(1383, 3674), Vector2(1395, 3645), Vector2(1416, 3573), Vector2(1438, 3530), Vector2(1440, 3518), Vector2(1455, 3501), Vector2(1464, 3493), Vector2(1470, 3482), Vector2(1486, 3471), Vector2(1494, 3472), Vector2(1501, 3475), Vector2(1502, 3492), Vector2(1512, 3522), Vector2(1528, 3531), Vector2(1539, 3531), Vector2(1547, 3527), Vector2(1564, 3500), Vector2(1568, 3487), Vector2(1565, 3462), Vector2(1571, 3435), Vector2(1582, 3413), Vector2(1581, 3389), Vector2(1583, 3385), Vector2(1598, 3383), Vector2(1612, 3364), Vector2(1607, 3321), Vector2(1595, 3306), Vector2(1593, 3297), Vector2(1598, 3289), Vector2(1597, 3282), Vector2(1602, 3283), Vector2(1604, 3277), Vector2(1604, 3255), Vector2(1613, 3249), Vector2(1633, 3245), Vector2(1645, 3239), Vector2(1652, 3222), Vector2(1650, 3213), Vector2(1665, 3176), Vector2(1671, 3171), Vector2(1675, 3171), Vector2(1682, 3182), Vector2(1688, 3182), Vector2(1719, 3143), Vector2(1718, 3138), Vector2(1711, 3134), Vector2(1692, 3137), Vector2(1683, 3126), Vector2(1683, 3119), Vector2(1693, 3104), Vector2(1702, 3061), Vector2(1702, 3050), Vector2(1685, 3024), Vector2(1675, 3020), Vector2(1673, 3012), Vector2(1675, 3002), Vector2(1679, 2997), Vector2(1696, 2993), Vector2(1697, 2985), Vector2(1680, 2972), Vector2(1648, 2957), Vector2(1642, 2946), Vector2(1640, 2936), Vector2(1644, 2907), Vector2(1646, 2854), Vector2(1631, 2822)],
	[Vector2(1492, 2533), Vector2(1494, 2540), Vector2(1501, 2546), Vector2(1506, 2569), Vector2(1514, 2580), Vector2(1514, 2591), Vector2(1516, 2599), Vector2(1509, 2608), Vector2(1504, 2606), Vector2(1502, 2600), Vector2(1504, 2598), Vector2(1509, 2598), Vector2(1510, 2589), Vector2(1507, 2581), Vector2(1500, 2580), Vector2(1499, 2582), Vector2(1502, 2593), Vector2(1500, 2594), Vector2(1498, 2591), Vector2(1489, 2560), Vector2(1474, 2530), Vector2(1476, 2529), Vector2(1482, 2532), Vector2(1488, 2528)],
	[Vector2(1524, 2629), Vector2(1531, 2632), Vector2(1529, 2637), Vector2(1524, 2633), Vector2(1514, 2635), Vector2(1514, 2630), Vector2(1517, 2630), Vector2(1518, 2628), Vector2(1515, 2619), Vector2(1518, 2618)],
	[Vector2(1529, 3752), Vector2(1531, 3756), Vector2(1529, 3760), Vector2(1514, 3768), Vector2(1508, 3783), Vector2(1507, 3795), Vector2(1502, 3801), Vector2(1501, 3808), Vector2(1503, 3821), Vector2(1508, 3830), Vector2(1511, 3842), Vector2(1518, 3849), Vector2(1518, 3856), Vector2(1509, 3866), Vector2(1510, 3874), Vector2(1502, 3902), Vector2(1494, 3918), Vector2(1480, 3938), Vector2(1460, 3960), Vector2(1453, 3960), Vector2(1479, 3933), Vector2(1490, 3919), Vector2(1497, 3903), Vector2(1502, 3888), Vector2(1503, 3876), Vector2(1503, 3852), Vector2(1496, 3811), Vector2(1503, 3795), Vector2(1506, 3779), Vector2(1515, 3755), Vector2(1513, 3744)],
	[Vector2(976, 2873), Vector2(983, 2874), Vector2(985, 2878), Vector2(985, 2893), Vector2(978, 2895), Vector2(974, 2898), Vector2(971, 2892), Vector2(968, 2891), Vector2(961, 2900), Vector2(956, 2902), Vector2(956, 2904), Vector2(960, 2905), Vector2(960, 2910), Vector2(965, 2913), Vector2(967, 2905), Vector2(974, 2903), Vector2(974, 2926), Vector2(969, 2919), Vector2(958, 2913), Vector2(953, 2916), Vector2(953, 2921), Vector2(944, 2929), Vector2(939, 2929), Vector2(926, 2921), Vector2(913, 2899), Vector2(914, 2893), Vector2(920, 2884), Vector2(937, 2874), Vector2(954, 2876), Vector2(965, 2873), Vector2(973, 2868)],
	[Vector2(1513, 2851), Vector2(1512, 2854), Vector2(1519, 2853), Vector2(1520, 2855), Vector2(1519, 2862), Vector2(1515, 2864), Vector2(1510, 2859), Vector2(1502, 2862), Vector2(1501, 2856), Vector2(1503, 2852), Vector2(1499, 2853), Vector2(1498, 2858), Vector2(1490, 2864), Vector2(1483, 2865), Vector2(1483, 2851), Vector2(1487, 2849), Vector2(1492, 2841), Vector2(1495, 2849), Vector2(1499, 2848), Vector2(1504, 2841)],
]

## Lipinkarinoja.
const STREAMS := [
	[Vector2(0, 950), Vector2(180, 945), Vector2(300, 925), Vector2(420, 905), Vector2(470, 850), Vector2(500, 790)],
	# Antinsuonoja laavun länsipuolella.
	[Vector2(897, 2090), Vector2(820, 2200), Vector2(760, 2300), Vector2(725, 2395), Vector2(640, 2500)],
]

## Agilitykenttä reitin varrella.
const AGILITY := [Vector2(300, 552), Vector2(352, 552), Vector2(352, 592), Vector2(300, 592)]

const PLACE_NAMES := [
	["Saloinen", Vector2(480, 70)],
	["Tarpio", Vector2(380, 1500)],
	["Kuusiluoto", Vector2(225, 1045)],
	["Pilkkarinneva", Vector2(385, 1120)],
	["Antinsuonkangas", Vector2(640, 2250)],
	["Kiilinlampi", Vector2(752, 700)],
	# Etelä
	["Haapajärven tekojärvi", Vector2(1540, 3560)],
]

## Jyväjemmarin traktorin parkkipaikka keskipellon länsilaidalla ja paalimuovit.
const TRACTOR_POS := Vector2(318, 755)
const BALES := [Vector2(333, 690), Vector2(336, 704), Vector2(331, 718), Vector2(338, 732), Vector2(345, 668), Vector2(560, 680)]

## Kiilinlammen grillikatos (turvapaikka Päiviltä) lammen kaakkoisrannalla.
const GRILLIKATOS := Vector2(789, 768)

## Naapurit Järvikujan varrella: Arto (puolukat) ja Pekka (kyyhkyt).
const ARTO_POS := Vector2(786, 1128)
const PEKKA_POS := Vector2(752, 1073)

## Juntin mahdolliset olinpaikat reitin varrella.
const JUNTTI_SPOTS := [Vector2(320, 610), Vector2(590, 720), Vector2(625, 880), Vector2(235, 500), Vector2(700, 1085)]


## Karttapikseli maailmaan maaston pinnalle (y = maaston korkeus).
static func w(p: Vector2) -> Vector3:
	var x := (p.x - ORIGIN.x) * SCALE
	var z := (p.y - ORIGIN.y) * SCALE
	return Vector3(x, T.h(x, z), z)


static func w2(p: Vector2) -> Vector2:
	return (p - ORIGIN) * SCALE


static func to_px(world: Vector3) -> Vector2:
	return Vector2(world.x, world.z) / SCALE + ORIGIN
