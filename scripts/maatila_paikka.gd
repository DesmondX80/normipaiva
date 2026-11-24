extends RefCounted
## Maatilan paikka (kaisua.gd): pellot, maasto, pihan rakennukset ja koneiden kotipaikat, isäntä, naapuri, apumies,
## tekstit, sade ja tallennusosio. Kaksi tilaa: Kaisua mökillä (Kaisuantie 38, mökin paikallinen kehys) ja Altaan tila
## Saloisissa kodin itäpuolella (Altaantie, kylän maailmakehys). Kehys on tilan solmun kehys: solmu on mökin tai
## Saloisten maailman lapsi origossa.
##
## Paikat [Vector3, yaw]: yaw = rotation.y, rakennuksen etusivu -Z (konevajan avoin sivu, ladon ovet), kuivurin
## suppilo +X.

const Mokki := preload("res://scripts/mokki.gd")
const Terrain := preload("res://scripts/terrain.gd")
const MapData := preload("res://scripts/map_data.gd")
const MapTila := preload("res://scripts/map_tila.gd")

var id := "kaisua"
var section := "kaisua"  # tallennusosio (kaisua_tila.gd)
## Pellot: [{"id", "name", "kind" ("heina" | "vilja"), "start" (aloitustila, kaisua_tila.gd)}].
var fields: Array = []
## Peltojen monikulmiot kehyksessä samassa järjestyksessä; tyhjä = mökin karttadatasta OSM-tunnisteella.
var field_polys: Array = []
## Maaston pinta (x, z) -> y kehyksessä; sama kolmiointi kuin maastoverkossa (pellon pinta ja kasvusto osuvat maahan).
var height: Callable
var grid_step := 2.0  # maastoverkon kärkipisteväli
var grid_origin := Vector2.ZERO  # kärkipisteet grid_origin + (i, j) * grid_step
var diag_main := true  # kolmion lävistäjä (0,0)-(1,1) (mökki); false = (1,0)-(0,1) (Saloisten terrain.gd)
var yard := Vector3.ZERO  # pihan keskipiste (kivikasat lähimpään pellon kulmaan tästä)
var yard_circles: Array = []  # sora: [[Vector2 keskipiste, säde]]
## Päärakennus: {"poly": PackedVector2Array (4 kulmaa), "ridge": harjakorkeus, "door": Vector3 kuistin kohta}.
var house := {}
var house_door := Vector3.ZERO
var konevaja: Array = []
var lato: Array = []
var kuivuri: Array = []
var diesel: Array = []
var sign: Array = []
var sign_text := "KAISUA"
var sign_sub := "Kaisuantie 38"
var isanta: Array = []
var isanta_name := "Kaisuan isäntä"
var isanta_look := {}
var home := {}  # kone -> [Vector3, yaw]
## Paalikauppa: {"pos": [Vector3, yaw], "drop": Vector3, "look": {}, "name": "Raija"}; tyhjä = ei paalikauppaa.
var naapuri := {}
## Apumies: {"name", "look", "start", "stop", "done", "fuel_out", "none"}; tekstit muodossa "%s" = pellon nimi.
## "away" = mökin Santtu piiloon ajon ajaksi (kaisua.gd helper_changed).
var helper := {}
var texts := {}  # "hello" (ensimmäinen juttelu), "intro" (viesti), "raining" (isännän repliikki sateella), "toinen" (vinkki
## toisesta tilasta, luku 7: isäntä kertoo sen, kunnes toisen tilan isäntä on tavattu)
var toinen := ""  # toisen tilan tallennusosio (luku 7: onko sen isäntä jo tavattu, main.gd)
var legends := {}  # työ -> legendaarinen hetki (endings.gd)
var rain_offset := 0  # sadepäivien siemen: eri tiloilla eri päivät
var rain_radius := 1500.0  # sade näkyy, kun kamera on näin lähellä pihaa
var forest_clear := true  # mökin metsä raivataan pihasta (mokki.gd _kaisua_clear); Saloisissa world.gd


## Kaisuan tila mökillä (mökin paikallinen kehys).
static func kaisua() -> RefCounted:
	var s: RefCounted = (load("res://scripts/maatila_paikka.gd") as GDScript).new()
	s.id = "kaisua"
	s.section = "kaisua"
	s.fields = [
		{"id": "1074444652", "name": "Kotipelto", "kind": "heina", "start": 3},
		{"id": "1074444653", "name": "Tienvarsipelto", "kind": "vilja", "start": 15},
		{"id": "1074444678", "name": "Isopelto", "kind": "vilja", "start": 10},
		{"id": "1074444679", "name": "Ojanvarsi", "kind": "heina", "start": 2},
	]
	s.height = Callable(Mokki, "mesh_h")
	s.grid_step = 2.0
	s.grid_origin = Vector2.ZERO
	s.diag_main = true
	s.yard = Vector3(-213.0, 0, 121.0)
	for y in Mokki.KAISUA_YARD:
		s.yard_circles.append([y[0], y[1]])
	s.house_door = Vector3(-207.5, 0, 110.2)  # pirtin ovi pihan puolella (OSM-talo 1074444651); kuisti tähän
	for bd in Mokki.map_data().buildings:
		if bd.id == Mokki.KAISUA_HOUSE:
			var ridge := 7.6
			if FileAccess.file_exists(Mokki.HEIGHTS_PATH):
				var hj: Variant = JSON.parse_string(FileAccess.get_file_as_string(Mokki.HEIGHTS_PATH))
				if hj is Dictionary:
					ridge = float((hj as Dictionary).get("height", {}).get(Mokki.KAISUA_HOUSE, ridge))
			s.house = {"poly": bd.poly, "ridge": ridge}
	s.konevaja = [Vector3(-192.5, 0, 126.0), PI / 2.0]  # avoin sivu länteen
	s.lato = [Vector3(-214.0, 0, 141.8), 0.0]  # ovet pohjoiseen pihalle
	s.kuivuri = [Vector3(-237.0, 0, 125.0), 0.0]  # suppilo itään pihalle
	s.diesel = [Vector3(-199.0, 0, 113.0), 0.0]  # polttoainesäiliö konevajan pohjoispäässä
	s.sign = [Vector3(-233.5, 0, 98.5), PI * 0.1]
	s.isanta = [Vector3(-207.0, 0, 117.5), PI / 2.0]
	s.isanta_look = {
		"shirt": Color(0.22, 0.32, 0.24), "flannel": true, "pants": Color(0.2, 0.24, 0.32), "workwear": true,
		"suspenders": true, "shoes": Color(0.1, 0.1, 0.09), "shoe": "kumisaapas", "hair": "Hair_Buzzed",
		"hair_color": Color(0.62, 0.6, 0.56), "beard": true, "height": 1.84, "skin": Color(0.95, 0.78, 0.68),
		"belly": 0.8, "bulk": 0.35, "shoulders": 0.3,
	}
	s.home = {
		"traktori": [Vector3(-207.0, 0, 125.0), PI / 2.0],
		"puimuri": [Vector3(-226.0, 0, 108.0), PI * 0.15],
		"niittokone": [Vector3(-197.5, 0, 131.8), PI / 2.0],
		"karhotin": [Vector3(-197.5, 0, 125.5), PI / 2.0],
		"aes": [Vector3(-197.5, 0, 120.0), PI / 2.0],
		"aura": [Vector3(-204.0, 0, 142.5), PI / 2.0],
		"kylvokone": [Vector3(-203.5, 0, 136.5), PI / 2.0],
		"paalain": [Vector3(-226.0, 0, 134.0), PI / 2.0],
		"perakarry": [Vector3(-229.0, 0, 116.5), PI / 2.0],
	}
	# Paalikauppa: naapurin talo tien pohjoispuolella (OSM 1074444650), paalipaikka vajan länsipuolen niityllä.
	s.naapuri = {"pos": [Vector3(-181.0, 0, 9.0), PI * 0.6], "drop": Vector3(-184.0, 0, 13.0), "name": "Raija",
		"look": {"shirt": Color(0.62, 0.25, 0.3), "pants": Color(0.22, 0.24, 0.3), "shoes": Color(0.1, 0.1, 0.09),
			"shoe": "kumisaapas", "hair": "Hair_Long", "hair_color": Color(0.55, 0.42, 0.3), "height": 1.62,
			"skin": Color(0.96, 0.8, 0.7), "model": "female"}}
	s.helper = {"name": "Santtu", "look": Mokki.SANTTU_LOOK, "away": true,
		"start": "Santtu polkaisi mökiltä (%d €): – Mää ajan %s, sää voit vaikka kerätä kiviä.",
		"stop": "Santtu: – No jätetään kesken. Mää meen mökille.",
		"done": "Santtu soitti: – %s ajettu! Mää lähin mökille.",
		"fuel_out": "Santtu soitti: – Diesel loppu kesken, traktori jäi pellolle (%s).",
		"none": "Santtu: – Ei tässä oo mitään ajettavaa."}
	s.texts = {
		"hello": "No terve! Santun mökiltä? Traktori on konevajan edessä ja koneet vajassa. Kotipelto on niittokunnossa ja Tienvarsipelto puintikypsä. Maksan joka hommasta, ja emäntä laittaa talkooruoat.",
		"intro": "Kaisuan hommat: traktorilla (%s) niittokone, karhotin, paalain, äes, kylvökone ja viljakärry konevajan suulta (%s kytkee peruuttamalla). Puimuri on talon vieressä.",
		"toinen": "Saloisissa on Altaan tila, Altaantien varressa. Isäntä on vanha tuttu, soitti ja kyseli renkiä: ohraa on viis hehtaaria ja poika ajaa yksin. Käy kattomassa, jos kotona oot.",
	}
	s.toinen = "altaantie"
	s.legends = {"latoon": "kaisuan_heinatalkoot", "kuivuri": "kaisuan_sato", "kylvo": "kaisuan_kylvot"}
	s.rain_offset = 0
	s.rain_radius = 1500.0
	return s


## Altaan tila Saloisissa kodin itäpuolella (Altaantie): pellot peltoseurannan lohkoista (map_tila.gd), piha
## Altaantien koillispuolella OSM-ulkorakennuksen paikalla, päärakennus tien toisella puolella OSM-talon paikalla.
## Kehys = Saloisten maailma (map_data.gd w2: px - ORIGIN).
static func altaantie() -> RefCounted:
	var s: RefCounted = (load("res://scripts/maatila_paikka.gd") as GDScript).new()
	var W := func(x: float, y: float) -> Vector3:
		var q := MapData.w2(Vector2(x, y))
		return Vector3(q.x, 0, q.y)
	var face := func(from: Vector3, to: Vector3) -> float:  # yaw, jolla -Z osoittaa kohti to
		var d := to - from
		return atan2(-d.x, -d.z)
	s.id = "altaantie"
	s.section = "altaantie"
	var names := {"597884": ["Isoaho", "vilja", 15], "597885": ["Altaanpelto", "vilja", 10], "598366": ["Vainio", "vilja", 15],
		"597887": ["Kotiniitty", "heina", 3], "597886": ["Tienvarsiniitty", "heina", 2]}
	for f in MapTila.FIELDS:
		var n: Array = names.get(f.id, [])
		if n.is_empty():
			continue
		s.fields.append({"id": f.id, "name": n[0], "kind": n[1], "start": n[2]})
		var poly := PackedVector2Array()
		for p: Vector2 in f.pts:
			poly.append(MapData.w2(p))
		s.field_polys.append(poly)
	Terrain.ensure()
	s.height = Callable(Terrain, "h")
	s.grid_step = Terrain.CELL
	s.grid_origin = Terrain.origin
	s.diag_main = false
	s.forest_clear = false
	var y: Vector3 = W.call(1290.0, 1565.0)
	s.yard = y
	for c in MapData.ALTAAN_PIHA:
		s.yard_circles.append([MapData.w2(c[0]), c[1]])
	# Päärakennus OSM-talon (px 1155,1; 1611,1; kulma -0,15; 13,6 × 8,2) paikalle, kuisti pohjoiseen tielle päin.
	var hc := MapData.w2(MapData.ALTAAN_TALO)
	var ax := Vector2(cos(-0.15), sin(-0.15))
	var az := ax.orthogonal()
	s.house = {"poly": PackedVector2Array([hc - ax * 6.8 - az * 4.1, hc + ax * 6.8 - az * 4.1, hc + ax * 6.8 + az * 4.1,
		hc - ax * 6.8 + az * 4.1]), "ridge": 7.0}
	s.house_door = W.call(1160.0, 1601.0)
	var kv: Vector3 = W.call(1308.0, 1538.0)
	s.konevaja = [kv, face.call(kv, y)]
	var lt: Vector3 = W.call(1268.0, 1531.0)
	s.lato = [lt, face.call(lt, y)]
	var kd: Vector3 = W.call(1326.0, 1584.0)
	var kdir := y - kd
	s.kuivuri = [kd, atan2(kdir.z, kdir.x) * -1.0]  # +X (suppilo) kohti pihaa
	s.diesel = [W.call(1301.0, 1581.0), 0.4]
	var sg: Vector3 = W.call(1243.0, 1607.0)
	s.sign = [sg, face.call(sg, W.call(1225.0, 1625.0)) + PI]  # kyltti tielle päin
	s.sign_text = "ALTAAN TILA"
	s.sign_sub = "Altaantie"
	s.isanta = [W.call(1280.0, 1575.0), face.call(W.call(1280.0, 1575.0), W.call(1255.0, 1600.0))]
	s.isanta_name = "Altaan isäntä"
	s.isanta_look = {
		"shirt": Color(0.55, 0.16, 0.12), "flannel": true, "pants": Color(0.18, 0.2, 0.24), "workwear": true,
		"shoes": Color(0.12, 0.1, 0.08), "shoe": "kumisaapas", "hair": "Hair_SimpleParted",
		"hair_color": Color(0.35, 0.3, 0.26), "beard": true, "height": 1.8, "skin": Color(0.93, 0.76, 0.66),
		"belly": 0.8, "bulk": 0.35, "shoulders": 0.3,
	}
	# Koneet: ajoneuvot pihalla, työkoneet konevajan suulla perä vajaan päin (traktori peruuttaa kytkemään).
	var kf: Vector3 = (y - kv)
	kf.y = 0.0
	kf = kf.normalized()
	var ka := Vector3(-kf.z, 0, kf.x)
	var out := atan2(-kf.x, -kf.z)  # keula pois vajasta
	s.home = {
		"traktori": [y + Vector3(-6.0, 0, 9.0), face.call(y, W.call(1255.0, 1610.0))],
		"puimuri": [W.call(1277.0, 1579.0), face.call(W.call(1277.0, 1579.0), W.call(1252.0, 1612.0))],
		"niittokone": [kv + kf * 6.0 + ka * 5.0, out],
		"karhotin": [kv + kf * 6.0, out],
		"aes": [kv + kf * 6.0 - ka * 5.0, out],
		"aura": [kv + kf * 13.0 + ka * 4.0, out],
		"kylvokone": [kv + kf * 13.0 - ka * 4.0, out],
		"paalain": [W.call(1289.0, 1553.0), out],
		"perakarry": [W.call(1300.0, 1570.0), out],
	}
	s.naapuri = {}
	s.helper = {"name": "Eetu", "away": false,
		"look": {"shirt": Color(0.2, 0.36, 0.55), "pants": Color(0.25, 0.25, 0.28), "shoes": Color(0.1, 0.1, 0.1),
			"shoe": "kumisaapas", "hair": "Hair_Buzzed", "hair_color": Color(0.45, 0.35, 0.25), "height": 1.8,
			"belly": 0.8, "bulk": 0.35, "shoulders": 0.3},  # sama vartalo kuin isännällä: verkko välimuistista
		"start": "Isännän poika Eetu tuli talosta (%d €): – Mää ajan %s, isä maksaa sulle kuitenki.",
		"stop": "Eetu: – No jätetään kesken. Mää meen sisälle.",
		"done": "Eetu huusi pihalta: – %s ajettu!",
		"fuel_out": "Eetu: – Diesel loppu kesken, traktori jäi pellolle (%s).",
		"none": "Eetu: – Ei tässä oo mitään ajettavaa."}
	s.texts = {
		"hello": "Päivää! Altaan tilalle töihin? Traktori on pihalla ja koneet konevajan suulla. Isoaho ja Vainio on puintikypsiä, Kotiniitty niittokunnossa ja Altaanpellon sänki kynnettävä. Isoahon pelto on tuolla pohjoisessa metsän takana, sinne pääsee pellon välistä polkua. Maksan joka hommasta, ja emäntä laittaa ruuat.",
		"intro": "Altaan tilan hommat: traktorilla (%s) niittokone, karhotin, paalain, aura, äes, kylvökone ja viljakärry konevajan suulta (%s kytkee peruuttamalla). Puimuri on pihalla. Isoahoon ajetaan peltojen välistä polkua pohjoiseen.",
		"toinen": "Vaalan Neittävällä on Kaisuan tila, Kaisuantien varressa. Sikäläinen isäntä kaipais talkoomiestä heinille ja ohrille. Jos sinne päin meet, käy sanomassa päivää.",
	}
	s.toinen = "kaisua"
	s.legends = {"latoon": "altaan_heinatalkoot", "kuivuri": "altaan_sato", "kylvo": "altaan_kylvot"}
	s.rain_offset = 7
	s.rain_radius = 700.0
	return s
