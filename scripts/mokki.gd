extends Node3D
## Mökki: Santtu-isännän vuokramökki Kaisuantie 62, Uutelanperä, Vaala, mallinnettu Airbnb-ilmoituksen kuvien ja
## drone-kuvan mukaan. Erillinen tasku maailman ulkopuolella, tavoitettavissa vain taksilla kotoa. Ympäristö
## 1,9 x 1,9 km oikean kartan mukaan (assets/mokki/kartta.json, tools/mokki_kartta.py: OpenStreetMap, MML:n 2 m
## korkeusmalli koko alueella, kauempana 8 m ruudukkona, tools/kartta/mokki.ps1): Likanen, Syväjärvi,
## Ahveroinen, Tervalampi, Kiiskeroinen,
## Penikka ja muut lammet omilla pinnoillaan, tiet nimineen, pellot, suo, purot, naapurirakennukset ja metsä.
## Kävelyalue on 800 x 800 m; sen ulkopuolinen maisema näkyy horisonttiin asti. Pelilogiikka main.gd:ssä.
##
## Koordinaatit: paikallinen kehys on mökin kehys (mökin pitkä sivu X-akselilla, kuisti +Z eli järvelle päin).
## Karttadata on osoitepisteen kehyksessä (x itään, z etelään); mökki on kiertynyt siihen nähden YARD_ROT_DEG.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Terrain := preload("res://scripts/terrain.gd")
const DroneGame := preload("res://scripts/drone_game.gd")
const DartsGame := preload("res://scripts/darts_game.gd")
const Mopo := preload("res://scripts/mopo.gd")

const DATA_PATH := "res://assets/mokki/kartta.json"
const HEIGHTS_PATH := "res://assets/mokki/rakennukset.json"
const TREES_PATH := "res://assets/mokki/puut.bin"
const Forest := preload("res://scripts/forest.gd")
## Mökin kehys karttakehyksessä: paikallisen origon paikka (m osoitepisteestä) ja kierto (OSM:n mökin mukaan).
const YARD_C := Vector2(1.0, 2.35)
const YARD_ROT_DEG := 17.6
const AREA_HALF := 400.0  # kävelyalue 800 x 800 m osoitepisteen ympärillä (näkymättömät seinät)
const VIEW_HALF := 950.0  # maasto, metsä ja kohteet näkyvät tähän asti (paikallisessa kehyksessä)
const INNER_HALF := 144.0  # tarkka 2 m maastoverkko pihan ympärillä (2 m korkeusmallin alue)
const FAR_GRID := 8.0  # kauempana maastoverkon ruutu
const MASK_STEP := 4.0  # teiden ja pihojen hakuruudukko (ks. _mask)

# Pihan asettelu: mökki OSM:n rakennuksen kohdalla, sauna, palju ja laituri drone-kuvasta.
# Rannan puolella kuistilta katsottuna vasemmalta oikealle (+X -> -X): savusauna, palju ja kesäkeittiö.
const TAXI_LOCAL := Vector3(-7.0, 0, -29.0)    # Kaisuantien varressa mökin takana
const SAUNA_LOCAL := Vector3(5.9, 0, 18.1)     # kiuas savusaunan sisällä
const TUB_LOCAL := Vector3(-0.7, 0, 14.8)      # puulämmitteinen palju
const DART_LOCAL := Vector3(4.2, 0, 8.0)       # heittopiste tikkataulun edessä (taulu männyssä)
const DART_TREE := DART_LOCAL + Vector3(0, 0, 3.0)  # tikkataulun mänty
const DART_BOARD_UP := 1.5  # taulun keskusta maasta
const DOCK_LOCAL := Vector3(8.9, 0, 55.4)      # laiturin pää Likasella
## Pihalta rantaan laiturille johtava kulkukäytävä: metsä ei kasva tälle kaistaleelle (ks. _build_forest).
const DOCK_PATH_A := Vector2(DOCK_LOCAL.x, 27.0)
const DOCK_PATH_B := Vector2(DOCK_LOCAL.x, DOCK_LOCAL.z + 1.5)
const KITCHEN_LOCAL := Vector3(-12.6, 0, 16.2) # kesäkeittiön savustimen edessä (katoksen alla)
const SANTTU_LOCAL := Vector3(-1.5, 0, 6.5)    # pihatuolilla kuistin edessä
const HUNT_LOCAL := Vector3(-30.0, 0, 5.0)     # metsästyslava syvemmällä metsässä, tien ja polun ulkopuolella
## Metsästyslavan edessä (lännessä) oleva aukea, jolle riista tulee (hunt_game.gd): metsä ei kasva sille.
const HUNT_GLADE := Vector2(HUNT_LOCAL.x - 14.0, HUNT_LOCAL.z)
const HUNT_GLADE_R := 10.0
const PINGIS_LOCAL := Vector3(-7.5, 0, 9.0)    # pihapingiksen mailat kannolla Santun vasemmalla puolella
const DRONE_LOCAL := Vector3(-4.5, 0, -7.5)    # droonin laskeutumisalusta pysäköintipaikan vieressä mökin takana
const MOPO_LOCAL := Vector3(-1.2, 0, -8.0)     # Paapelin mopo parkissa mökin takana: E ajaa Vaalaan Siitariin
## Santun hommat (santun_hommat.gd, main.gd _hommat_*): puupaikka, halkopino, huussi, komposti, päädyn nurmikko,
## tikkaat räystääseen, ampiaispesä saunan terassilla, laiturin korjauskohta ja paljun pumppu rannassa.
const PUU_SAW_LOCAL := Vector3(-18.0, 0, 14.5)   # sahapukki kesäkeittiön takana
const PUU_CHOP_LOCAL := Vector3(-15.2, 0, 13.4)  # pilkkomispölkky
const HALKO_LOCAL := Vector3(-15.3, 0, 18.6)     # halkopinon edessä: syli halkoja savusaunaan
const HUUSSI_LOCAL := Vector3(-12.5, 0, -2.0)    # huussi pihan laidalla, ovi pihalle (+Z)
const HUUSSI_HATCH_LOCAL := Vector3(-12.5, 0, -3.3)  # takaluukku, josta sanko otetaan
const KOMPOSTI_LOCAL := Vector3(-18.5, 0, 5.5)
## Päädyn nurmikko (paikallinen x/z) ja Santun vanha leikkuri sen kulmassa.
const LAWN_RECT := Rect2(7.8, -3.5, 3.8, 9.0)
const LAWN_MOWER_LOCAL := Vector3(8.4, 0, -3.0)
const LADDER_LOCAL := Vector3(0.4, 0, -4.6)      # tikkaat takaseinän räystääseen (räystäs z = -3.75)
const GUTTER_Z := -3.85                           # ränni takaräystään alla
const GUTTER_UP := 2.78                           # rännin korkeus mökin lattiatason maasta
const WASP_STAND_LOCAL := Vector3(2.2, 0, 16.9)  # ampiaispesän edessä saunan terassin kulmalla
const DOCK_FIX_LOCAL := Vector3(8.9, 0, 49.0)    # laiturin lahot laudat
## Viinakätköt mökin ympäröivässä metsässä geokätköjen tapaan: kompassi ja HUD näyttävät lähimmän löytämättömän
## kätkön suunnan ja matkan (main.gd _viina_logic). Paikat arvotaan kiinteällä siemenellä (viina_positions).
const VIINA := [
	{"id": "kossu", "desc": "Koskenkorva 0,5 l", "spot": "kivikasan alla"},
	{"id": "jallu", "desc": "Jaloviina 0,5 l", "spot": "kaatuneen kuusen juurakossa"},
	{"id": "minttu", "desc": "Minttu 0,35 l", "spot": "sammalmättään alla"},
	{"id": "salmari", "desc": "Salmiakkikossu 0,5 l", "spot": "kannon kolossa"},
	{"id": "lakka", "desc": "Lakkalikööri 0,5 l", "spot": "kiven kupeessa"},
	{"id": "pontikka", "desc": "Pontikkapullo 0,7 l", "spot": "risukasan alla"},
]
const VIINA_R := Vector2(45.0, 220.0)  # etäisyys mökistä (min, max)
const VIINA_GAP := 45.0                # kätköjen väli vähintään

# Karttageometria (ks. minimap.gd ja paper_map.gd: mökin oma kartta korvaa kyläkartan täällä).
const YARD_CENTER := Vector2(-2.0, 10.0)
const YARD_R := Vector2(21.0, 19.0)
const GRID_STEP := 2.0   # maastoverkon ja törmäyksen ruutu (korkeusmallin tarkkuus)
const COTTAGE_LOCAL := Vector2(0.0, -1.0)
## OSM-rakennukset, jotka mallinnetaan käsin (mökki) tai jätetään tyhjäksi tontiksi (käyttämätön vaja purettu).
const OWN_BUILDINGS := ["1074462394", "1555232405"]
const COTTAGE_SIZE := Vector2(9.4, 5.0)

const SAUNA_HEAT := 20.0    # (vanha) s ennen kuin kiuas on kuuma
const SAUNA_BURN := 260.0   # s sytytyksestä sammumiseen
## Savusaunan lämmitys: syli palaa SAUNA_FUEL_LOAD s, pesään mahtuu SAUNA_FUEL_MAX s, ja täyteen lämpöön menee
## noin 1 / SAUNA_HEAT_RATE s tulta. Savut tuulettuvat SAUNA_CLEAR s:ssa, ja lämmin kiuas jäähtyy hitaasti.
const SAUNA_FUEL_LOAD := 30.0
const SAUNA_FUEL_MAX := 60.0
const SAUNA_HEAT_RATE := 1.0 / 75.0
const SAUNA_CLEAR := 22.0
const SAUNA_COOL := 1.0 / 500.0
const TUB_HEAT := 30.0
const TUB_BURN := 320.0

## Santun jutut: poimittu suoraan hänen omasta Airbnb-ilmoituksestaan (Neittävä, Pohjois-Pohjanmaa).
const SANTTU_LINES := [
	"Oon täällä Superhost, viides vuosi menossa!",
	"Ilmoitus on ihan uus – ei oo vielä yhtään arvostelua.",
	"Muilla mökeillä on jo 106 arvostelua, keskiarvo 4.86. Kyllä tää vielä nousee.",
	"Parkkipaikka on ilmainen, harvinaista täällä päin.",
	"Suodatinkahvia on aina tarjolla. Se on listan kohokohtia, usko tai älä.",
	"Savusauna ja puulämmitteinen palju – kokeile molempia, ennen ku lähet.",
	"Pihalla on ulkokeittiö ja savustin. Kokkaa jotain, jos on aikaa.",
	"Lähin kauppa on Vaalassa, viistoista kilsaa. Täällä on rauhallista.",
	"Synnyin 80-luvulla, opiskelin Oulun yliopistossa. Sitä ei tästä äkkiä arvais.",
	"Vastausprosentti sata, vastaan yleensä tunnissa. Paitsi kun oon saunassa.",
]
const SANTTU_AMBIENT := [
	"Löylyä riittää, älä säästele.", "Palju lämpiää hitaasti, mutta kunnolla.",
	"Kahvia on keittiössä, ota rohkeasti.", "Tikkaa saa heittää, puuta ei tarvi säästellä.",
	"Ilta on kaunis järvellä.", "Rauhallista täällä, ei naapureita lähelläkään.",
]
const LAKE_LINES := [
	"Järvi on tyyni, ei tuulenvirettäkään.", "Jossain kaukana kuikka huutaa.",
	"Kala pomppaa pinnalla, laineet leviävät hitaasti.", "Usva nousee veden pinnalta illan viilettyä.",
	"Ranta on ruovikkoa täynnä, mutta laituri kantaa hyvin.", "Ei täällä naapureita näy eikä kuulu.",
]
## Saaliit: nimi partitiivissa (sopii lauseeseen "Sait ...") ja tyypillinen paino kiloina.
const FISH := [
	{"name": "särjen", "nom": "särki", "kg": 0.25}, {"name": "ahvenen", "nom": "ahven", "kg": 0.35},
	{"name": "lahnan", "nom": "lahna", "kg": 0.9}, {"name": "hauen", "nom": "hauki", "kg": 1.6},
	{"name": "mateen", "nom": "made", "kg": 0.8},
]
const FISH_JUNK := ["vanhan kumisaappaan", "ruosteisen peltitölkin", "jonkun kadonneen lippiksen", "pelkän oksankappaleen"]
const FISH_MISS_LINES := ["Kala vei syötin.", "Onki jäi tyhjäksi.", "Siima venähti tyhjää.", "Ei tällä kertaa."]

var boat_parked: Node3D
var sauna_fire_on := false
var sauna_fire_time := 0.0
var tub_fire_on := false
var tub_fire_time := 0.0

var santtu: Node3D
var _bubble: Label3D
var _name_label: Label3D
var _bubble_t := 0.0
var _t := 0.0
var _sauna_fire: Node3D
var _tub_fire: Node3D
## Offset-savustimen tulipesä ja piipun savu (main.gd säätää lämmön mukaan, set_smoker()).
var _smoker_fire: Node3D
var _smoker_smoke: CPUParticles3D


## Rakennettu? Mökkialue (500 m maasto, metsä, rakennukset) rakennetaan vasta tarvittaessa (ensure_built),
## ettei pelin käynnistys hidastu noin 2 sekunnilla. Kartat ja sijaintilaskut (map_data, h, gpos) toimivat ilman.
var built := false
var _pa_out: AudioStreamPlayer3D

## Savusauna: lämpö (0–1), polttopuuta pesässä (s), savua saunassa (0–1). Täysi lämpö polttaa pesän loppuun,
## ja ennen löylyä savujen pitää tuulettua (häkä). Ks. main.gd _sauna_logic.
var sauna_heat := 0.0
var sauna_fuel := 0.0
var sauna_smoke := 0.0
var sauna_heated := false
signal sauna_event(kind: String)  # "sammui", "kuuma", "valmis"
var _sauna_smoke_fx: CPUParticles3D
## Palju: vettä (0–1), likaa (0–1) ja pumppu järvestä.
var palju_level := 1.0
var palju_dirt := 0.0
var pump_on := false
var _palju_water: MeshInstance3D
var _palju_dirt: MeshInstance3D
var _pump_sound: AudioStreamPlayer3D
var _hose: Node3D
## Hommien esineet: huussin kärpäset, kompostin pinta, ampiaispesä, laiturin paikkalaudat, tikkaat.
var huussi_flies: CPUParticles3D
var komposti_soil: MeshInstance3D
var wasp_nest: Node3D
var dock_body: Node3D
var dock_patch: Node3D
var ladder: Node3D
var cottage_base := 0.0  # mökin lattiatason maan korkeus (rännipelin kehys)
var sauna_base := 0.0  # savusaunan ja terassin lattiataso (ampiaispelin kehys)


func ensure_built() -> void:
	if built:
		return
	built = true
	_build_ground()
	_build_lake_and_dock()
	_build_neighbors()
	_build_forest()
	_build_cottage()
	_build_summer_kitchen()
	_build_savusauna()
	_build_hottub()
	_build_yard_extras()
	_build_hunt_spot()
	_build_viina_caches()
	_build_mopo()
	_build_pingis_spot()
	_build_trees()
	_build_santtu()
	_build_chore_spots()
	# Kaikki pihan rakennukset ja esineet maanpinnalle (maasto ja vesi ovat jo oikealla korkeudella).
	for c in get_children():
		if c is Node3D and not c.has_meta("ground"):
			c.position.y += h(c.position.x, c.position.z)
	cottage_base = h(0.0, -1.0)
	sauna_base = h(SAUNA_LOCAL.x, SAUNA_LOCAL.z + 1.0)
	_build_hose()


## Tikkataulun etupinnan keskipiste mökin koordinaateissa (tikanheiton minipeli).
static func dart_board_center() -> Vector3:
	return DART_TREE + Vector3(0, h(DART_TREE.x, DART_TREE.z) + DART_BOARD_UP, -0.36)


## Löylyihin: kiuas lämmitetty täyteen, pesä palanut loppuun ja savut tuulettuneet.
func sauna_ready() -> bool:
	return sauna_heated and not sauna_fire_on and sauna_smoke <= 0.05 and sauna_heat >= 0.6


func tub_ready() -> bool:
	return tub_fire_on and tub_fire_time <= TUB_BURN - TUB_HEAT


func set_sauna_fire(on: bool) -> void:
	sauna_fire_on = on
	if on:
		sauna_fire_time = SAUNA_BURN
		sauna_fuel = maxf(sauna_fuel, SAUNA_FUEL_LOAD)
	else:
		sauna_fuel = 0.0
		if _sauna_fire != null:
			_sauna_fire.visible = false


## Uusi päivä: savusauna kylmänä.
func reset_sauna() -> void:
	set_sauna_fire(false)
	sauna_heat = 0.0
	sauna_smoke = 0.0
	sauna_heated = false


## Syli halkoja pesään (sytyttää, jos tuli on sammunut). Palauttaa false, jos pesä on jo täynnä.
func sauna_add_wood() -> bool:
	if sauna_fire_on and sauna_fuel > SAUNA_FUEL_MAX - SAUNA_FUEL_LOAD * 0.5:
		return false
	if not sauna_fire_on:
		sauna_fire_on = true
		sauna_fire_time = SAUNA_BURN
	sauna_fuel = minf(sauna_fuel + SAUNA_FUEL_LOAD, SAUNA_FUEL_MAX)
	return true


func set_tub_fire(on: bool) -> void:
	tub_fire_on = on
	if on:
		tub_fire_time = TUB_BURN
	elif _tub_fire != null:
		_tub_fire.visible = false


## Savustimen tulipesä ja savu lämpötilan (°C) mukaan: kylmänä ei mitään, kuumana paksu savu.
func set_smoker(temp: float) -> void:
	if not built:
		return
	_smoker_fire.visible = temp > 45.0
	_smoker_smoke.emitting = temp > 40.0
	# Kuumempi tulipesä = paksumpi savu (CPUParticles3D:llä ei ole amount_ratiota, joten koko kasvaa).
	var thick := clampf((temp - 40.0) / 120.0, 0.2, 1.0)
	_smoker_smoke.scale_amount_min = 0.5 + thick * 0.6
	_smoker_smoke.scale_amount_max = 1.0 + thick * 1.8


## Mökin PA:n tunnusmusiikki kuuluu pihalle seinien läpi vaimeana (sisällä soi mokki_interior.gd:n kaiuttimista).
func set_pa_level(v: float) -> void:
	if _pa_out == null:
		if v <= 0.01:
			return
		_pa_out = AudioStreamPlayer3D.new()
		_pa_out.bus = "Music"
		_pa_out.stream = Sfx.music_stream()
		_pa_out.position = Vector3(COTTAGE_LOCAL.x, h(COTTAGE_LOCAL.x, COTTAGE_LOCAL.y) + 1.8, COTTAGE_LOCAL.y)
		_pa_out.unit_size = 9.0
		_pa_out.max_distance = 90.0
		_pa_out.attenuation_filter_cutoff_hz = 900.0  # seinät vaimentavat diskantin
		_pa_out.attenuation_filter_db = -30.0
		add_child(_pa_out)
	if v <= 0.01:
		_pa_out.stop()
		return
	_pa_out.volume_db = -8.0 + linear_to_db(v)
	if not _pa_out.playing and _pa_out.stream != null:
		_pa_out.play()


func say(text: String, seconds := 3.2) -> void:
	if not built:
		return
	_bubble.text = text
	_bubble_t = seconds


func _process(delta: float) -> void:
	if not built:
		return
	_t += delta
	_sauna_tick(delta)
	_palju_tick(delta)
	_santtu_tick(delta)
	if tub_fire_on:
		tub_fire_time -= delta
		if tub_fire_time <= 0.0:
			set_tub_fire(false)
		else:
			_tub_fire.visible = true
	for f in [_sauna_fire, _tub_fire, _smoker_fire]:
		if f.visible:
			for k in 4:
				var fl: Node3D = f.get_node("Flame%d" % k)
				fl.scale = Vector3(1.0, 0.8 + 0.35 * absf(sin(_t * (5.0 + k) + k)), 1.0)
			(f.get_node("Glow") as OmniLight3D).light_energy = 2.0 + 0.6 * sin(_t * 13.0) * sin(_t * 7.1)
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.text = ""


# --- Kartta, maasto ja vesistöt ----------------------------------------------------

static var _map := {}


## Karttakehys (osoitepisteestä, x itään, z etelään) -> mökin paikallinen kehys.
static func to_local2(p: Vector2) -> Vector2:
	var b := deg_to_rad(YARD_ROT_DEG)
	var d := p - YARD_C
	return Vector2(d.x * cos(b) + d.y * sin(b), -d.x * sin(b) + d.y * cos(b))


## Mökin paikallinen kehys -> karttakehys.
static func to_map2(p: Vector2) -> Vector2:
	var b := deg_to_rad(YARD_ROT_DEG)
	return Vector2(p.x * cos(b) - p.y * sin(b), p.x * sin(b) + p.y * cos(b)) + YARD_C


## Karttadata paikallisessa kehyksessä: water/fields (monikulmiot), roads ({type, name, pts}), buildings
## ({id, type, poly}), streams, dem ja alueen kulmat (area). Ladataan kerran.
static func map_data() -> Dictionary:
	if not _map.is_empty():
		return _map
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var out := {"water": [], "water_names": [], "water_levels": [], "water_bbox": [], "fields": [], "field_bbox": [],
		"bogs": [], "sands": [], "forests": [], "roads": [], "buildings": [], "streams": [], "dem": d.dem,
		"dem_far": d.get("dem_far", {})}
	var keep := Rect2(-Vector2.ONE * (VIEW_HALF + 400.0), Vector2.ONE * (VIEW_HALF + 400.0) * 2.0)
	for f in d.features:
		var pts := PackedVector2Array()
		var fb := Rect2(Vector2(f.pts[0][0], f.pts[0][1]), Vector2.ZERO)
		for p in f.pts:
			fb = fb.expand(Vector2(p[0], p[1]))
			pts.append(to_local2(Vector2(p[0], p[1])))
		if not keep.intersects(fb, true):
			continue  # alueen ulkopuolinen kohde (karttakehyksessä)
		if f.kind != "road" and f.kind != "stream" and pts.size() > 3 and pts[0].distance_to(pts[-1]) < 0.01:
			pts.remove_at(pts.size() - 1)  # OSM:n suljettu viiva toistaa alkupisteen
		var lb := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			lb = lb.expand(p)
		match f.kind:
			"water":
				out.water.append(pts)
				out.water_names.append(f.name)
				out.water_levels.append(float(f.get("level", d.dem.water)))
				out.water_bbox.append(lb)
			"field":
				out.fields.append(pts)
				out.field_bbox.append(lb)
			"bog":
				out.bogs.append(pts)
			"forest":
				out.forests.append(pts)  # OSM:n metsät (vajaa kartoitus mökin ympärillä: maasto on metsää oletuksena)
			"sand":
				out.sands.append(pts)
			"road":
				var bb := Rect2(pts[0], Vector2.ZERO)
				for p in pts:
					bb = bb.expand(p)
				out.roads.append({"type": f.type, "name": f.name, "pts": pts, "bbox": bb.grow(6.0)})
			"building":
				out.buildings.append({"id": f.id, "type": f.type, "poly": pts})
			"stream":
				out.streams.append(pts)
	var area := PackedVector2Array()
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		area.append(to_local2(c * AREA_HALF))
	out.area = area
	_map = out
	return _map


## Onko paikallinen piste järvessä (tai lammessa).
static func in_water(x: float, z: float) -> bool:
	return water_at(x, z) >= 0


## Vesistön indeksi (map_data().water) pisteessä, -1 = kuivaa maata.
static func water_at(x: float, z: float) -> int:
	var data := map_data()
	var p := Vector2(x, z)
	for i in data.water.size():
		if data.water_bbox[i].has_point(p) and Geometry2D.is_point_in_polygon(p, data.water[i]):
			return i
	return -1


## Onko piste pellolla.
static func in_field(p: Vector2) -> bool:
	var data := map_data()
	for i in data.fields.size():
		if data.field_bbox[i].has_point(p) and Geometry2D.is_point_in_polygon(p, data.fields[i]):
			return true
	return false


static var _mask_data := PackedByteArray()
static var _mask_n := 0


## Hakuruudukko (MASK_STEP m): bitti 1 = tie lähellä (puut eivät kasva), bitti 2 = rakennuksen piha.
static func _mask(p: Vector2) -> int:
	if _mask_data.is_empty():
		_build_mask()
	var i := int((p.x + VIEW_HALF) / MASK_STEP)
	var j := int((p.y + VIEW_HALF) / MASK_STEP)
	if i < 0 or j < 0 or i >= _mask_n or j >= _mask_n:
		return 0
	return _mask_data[j * _mask_n + i]


static func _build_mask() -> void:
	_mask_n = int(VIEW_HALF * 2.0 / MASK_STEP) + 1
	_mask_data.resize(_mask_n * _mask_n)
	var mark := func(p: Vector2, r: float, bit: int) -> void:
		var cr := int(ceil(r / MASK_STEP))
		var ci := int((p.x + VIEW_HALF) / MASK_STEP)
		var cj := int((p.y + VIEW_HALF) / MASK_STEP)
		for dj in range(-cr, cr + 1):
			for di in range(-cr, cr + 1):
				var i := ci + di
				var j := cj + dj
				if i < 0 or j < 0 or i >= _mask_n or j >= _mask_n or Vector2(di, dj).length() * MASK_STEP > r + MASK_STEP * 0.5:
					continue
				_mask_data[j * _mask_n + i] |= bit
	var data := map_data()
	for r in data.roads:
		var pts: PackedVector2Array = r.pts
		for k in pts.size() - 1:
			var segs := maxi(1, int(pts[k].distance_to(pts[k + 1]) / 2.0))
			for s in segs + 1:
				mark.call(pts[k].lerp(pts[k + 1], float(s) / segs), 4.0, 1)
	for bd in data.buildings:
		var poly: PackedVector2Array = bd.poly
		if poly.size() > 0:
			var c := Vector2.ZERO
			for q in poly:
				c += q
			mark.call(c / poly.size(), 14.0, 2)


static var _viina_pos: Array[Vector2] = []


## Viinakätköjen paikat (paikallinen x/z, VIINA-järjestyksessä): metsää, ei vettä, peltoa, suota, teitä eikä pihoja.
static func viina_positions() -> Array[Vector2]:
	if not _viina_pos.is_empty():
		return _viina_pos
	var data := map_data()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4062
	var avoid := [Vector2(HUNT_LOCAL.x, HUNT_LOCAL.z), HUNT_GLADE, Vector2(DOCK_LOCAL.x, DOCK_LOCAL.z),
		Vector2(TAXI_LOCAL.x, TAXI_LOCAL.z)]
	var tries := 0
	while _viina_pos.size() < VIINA.size() and tries < 5000:
		tries += 1
		var a := rng.randf() * TAU
		var p := COTTAGE_LOCAL + Vector2(cos(a), sin(a)) * rng.randf_range(VIINA_R.x, VIINA_R.y)
		if _mask(p) != 0 or in_water(p.x, p.y) or in_field(p) or not in_area(p.x, p.y, 30.0):
			continue
		if pow((p.x - YARD_CENTER.x) / YARD_R.x, 2.0) + pow((p.y - YARD_CENTER.y) / YARD_R.y, 2.0) < 2.0:
			continue
		var ok := true
		for b in data.bogs:
			if Geometry2D.is_point_in_polygon(p, b):
				ok = false
		for q in avoid + _viina_pos:
			if p.distance_to(q) < VIINA_GAP:
				ok = false
		if ok:
			_viina_pos.append(p)
	return _viina_pos


## Onko paikallinen piste 200 x 200 m alueella (reunan sisäpuolella margin m).
static func in_area(x: float, z: float, margin := 0.0) -> bool:
	var m := to_map2(Vector2(x, z))
	return absf(m.x) < AREA_HALF - margin and absf(m.y) < AREA_HALF - margin


## Korkeusmallin arvo (m merenpinnasta) paikallisessa pisteessä: pihan ympärillä MML:n 2 m malli 2 m ruudukkona,
## kauempana sama malli 8 m ruudukkona ("dem_far"), välissä pehmeä liuku.
static func _dem(x: float, z: float) -> float:
	var data := map_data()
	var m := to_map2(Vector2(x, z))
	var inner: Dictionary = data.dem
	var lim := -float(inner.x0) - 2.0
	var edge := maxf(absf(m.x), absf(m.y))
	if edge < lim - 16.0 or data.dem_far.is_empty():
		return _grid(inner, m)
	var far := _grid(data.dem_far, m)
	if edge >= lim:
		return far
	return lerpf(_grid(inner, m), far, (edge - (lim - 16.0)) / 16.0)


static func _grid(dem: Dictionary, m: Vector2) -> float:
	var n: int = dem.n
	var fx := clampf((m.x - dem.x0) / dem.step, 0.0, n - 1.001)
	var fz := clampf((m.y - dem.z0) / dem.step, 0.0, n - 1.001)
	var i := int(fx)
	var j := int(fz)
	var vals: Array = dem["values"]
	var a: float = lerpf(vals[j * n + i], vals[j * n + i + 1], fx - i)
	var b: float = lerpf(vals[(j + 1) * n + i], vals[(j + 1) * n + i + 1], fx - i)
	return lerpf(a, b, fz - j)


## Mökin paikallinen maanpinnan korkeus (mökki = 0). Vesistöissä pohja on pinnan alla, rannalla maa pysyy
## hieman pinnan yläpuolella.
static func h(x: float, z: float) -> float:
	var wi := water_at(x, z)
	if wi >= 0:
		return water_level(wi) - 1.0
	return maxf(_dem(x, z) - _base(), water_y() + 0.12)


## Vesistön pinnan korkeus mökin tasoon nähden (jokaisella järvellä oma pinta, Likanen alimpana).
static func water_level(i: int) -> float:
	return float(map_data().water_levels[i]) - _base()


static var _base_cache := NAN


static func _base() -> float:
	if is_nan(_base_cache):
		_base_cache = _grid(map_data().dem, to_map2(COTTAGE_LOCAL))
	return _base_cache


## Järvien pinnan korkeus mökin tasoon nähden (Likanen 125,3 m N2000).
static func water_y() -> float:
	return float(map_data().dem.water) - _base()


## Paikallinen piste maanpinnalle (y = h + local.y) maailmakoordinaatteina.
func gpos(local: Vector3) -> Vector3:
	return to_global(Vector3(local.x, h(local.x, local.z) + local.y, local.z))


## Kuistin kansi pesuhuoneen oven edessä (maailmassa).
func porch2_pos(out := 0.9) -> Vector3:
	var p := DOOR2_LOCAL + PORCH_DIR * out
	return to_global(Vector3(p.x, h(COTTAGE_LOCAL.x, COTTAGE_LOCAL.y) + 0.62 + 0.3, p.z))


## Kuistin kansi oven edessä (maailmassa): uloskäynnin ja aamun heräämisen paikka.
func porch_pos(out := 0.9) -> Vector3:
	var p := DOOR_LOCAL + PORCH_DIR * out
	return to_global(Vector3(p.x, h(COTTAGE_LOCAL.x, COTTAGE_LOCAL.y) + 0.62 + 0.3, p.z))


func _ground_mat(a: Color, b: Color, scale := 0.04, fine := 0.8) -> Material:
	return B.shader_mat("res://shaders/ground.gdshader", {
		"color_a": a, "color_b": b, "scale": scale, "fine_scale": fine, "bump": 0.7, "roughness_v": 0.95, "stripes": 0.0,
	})


## Onko piste jonkin rakennuksen pihalla (naapurit ja oma piha).
func _is_yard(p: Vector2) -> bool:
	if pow((p.x - YARD_CENTER.x) / YARD_R.x, 2.0) + pow((p.y - YARD_CENTER.y) / YARD_R.y, 2.0) < 1.0:
		return true
	return _mask(p) & 2 != 0


## Maasto korkeusmallin mukaan: pihan ympärillä 2 m verkko, kauempana 8 m verkko horisonttiin asti. Metsä,
## pihat, pellot, suo, hiekka ja järvien pohjat omilla materiaaleillaan, törmäys samoista ruudukoista
## (HeightMapShape3D kuten world.gd:ssä). Karkean verkon sisäosa painetaan tarkan verkon alle.
func _build_ground() -> void:
	var mats := {
		"forest": _ground_mat(Color(0.28, 0.32, 0.17), Color(0.5, 0.48, 0.32), 0.03, 0.6),
		"yard": _ground_mat(Color(0.36, 0.3, 0.2), Color(0.55, 0.47, 0.32), 0.04, 0.9),
		"field": _ground_mat(Color(0.45, 0.5, 0.25), Color(0.6, 0.62, 0.32), 0.02, 0.4),
		"shore": _ground_mat(Color(0.3, 0.3, 0.22), Color(0.42, 0.4, 0.3), 0.05, 0.8),
		"bog": _ground_mat(Color(0.4, 0.38, 0.22), Color(0.55, 0.45, 0.3), 0.03, 0.5),
		"sand": _ground_mat(Color(0.72, 0.64, 0.46), Color(0.82, 0.75, 0.56), 0.06, 1.2),
	}
	var sts := {}
	for k in mats:
		sts[k] = SurfaceTool.new()
		sts[k].begin(Mesh.PRIMITIVE_TRIANGLES)
	_ground_grid(sts, INNER_HALF, GRID_STEP, false)
	_ground_grid(sts, VIEW_HALF - fmod(VIEW_HALF - INNER_HALF, FAR_GRID), FAR_GRID, true)
	for k in sts:
		var st: SurfaceTool = sts[k]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mats[k]
		mi.set_meta("ground", true)
		add_child(mi)
	# Horisontti: laaja metsänvärinen taso maaston alla, ettei reunan takana näy tyhjää.
	var far_vals: Array = map_data().dem_far.get("values", [0.0])
	var lowest := INF
	for v in far_vals:
		lowest = minf(lowest, v)
	var plane := B.mesh(self, B.boxm(Vector3(9000, 1, 9000)), Vector3(0, lowest - _base() - 3.0, 0), Color(0.2, 0.25, 0.14))
	plane.set_meta("ground", true)
	# Kävelyalueen reunat: näkymättömät seinät.
	var area: PackedVector2Array = map_data().area
	for k in 4:
		var a := area[k]
		var b := area[(k + 1) % 4]
		var wall := StaticBody3D.new()
		var mid := (a + b) / 2.0
		wall.position = Vector3(mid.x, 0, mid.y)
		wall.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		wall.add_child(B.box_shape(Vector3(a.distance_to(b), 80.0, 1.0), Vector3(0, 5.0, 0)))
		wall.set_meta("ground", true)
		add_child(wall)


## Yksi maastoverkko (-half..half, ruutu step) materiaaleittain ja törmäyksenä. hole = tarkan verkon alue
## ohitetaan (sen korkeudet painetaan syvälle, jotta karkea törmäys ei nouse tarkan maaston päälle).
func _ground_grid(sts: Dictionary, half: float, step: float, hole: bool) -> void:
	var data := map_data()
	var lo := Vector2(-half, -half)
	var n := int(roundf(half * 2.0 / step)) + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var inside := func(q: Vector2) -> bool:
		return hole and absf(q.x) < INNER_HALF - 0.01 and absf(q.y) < INNER_HALF - 0.01
	for j in n:
		for i in n:
			var p := lo + Vector2(i, j) * step
			hs[j * n + i] = -60.0 if inside.call(p) else h(p.x, p.y)
	for j in n - 1:
		for i in n - 1:
			var c := lo + (Vector2(i, j) + Vector2(0.5, 0.5)) * step
			if inside.call(c):
				continue
			var kind := "forest"
			if in_water(c.x, c.y):
				kind = "shore"
			elif in_field(c):
				kind = "field"
			elif _is_yard(c):
				kind = "yard"
			else:
				for b in data.bogs:
					if Geometry2D.is_point_in_polygon(c, b):
						kind = "bog"
				for sd in data.sands:
					if Geometry2D.is_point_in_polygon(c, sd):
						kind = "sand"
			var st: SurfaceTool = sts[kind]
			var v := func(di: int, dj: int) -> Vector3:
				var q := lo + Vector2(i + di, j + dj) * step
				return Vector3(q.x, hs[(j + dj) * n + i + di], q.y)
			for corner in [v.call(0, 0), v.call(1, 0), v.call(1, 1), v.call(0, 0), v.call(1, 1), v.call(0, 1)]:
				st.add_vertex(corner)
	var ground_body := StaticBody3D.new()
	ground_body.collision_layer = Terrain.COLLISION_LAYER
	ground_body.collision_mask = 0
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	hm.map_data = hs
	var cs := CollisionShape3D.new()
	cs.shape = hm
	cs.scale = Vector3(step, 1.0, step)
	ground_body.position = Vector3(lo.x + (n - 1) * step * 0.5, 0.0, lo.y + (n - 1) * step * 0.5)
	ground_body.add_child(cs)
	ground_body.set_meta("ground", true)
	add_child(ground_body)


## Maaston myötäinen nauha (tie, puro) murtoviivaa pitkin.
func _strip(pts: PackedVector2Array, half_w: float, lift: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var segs := maxi(1, int(a.distance_to(b) / 3.0))
		var nrm := (b - a).normalized().orthogonal() * half_w
		for s in segs:
			var p0 := a.lerp(b, float(s) / segs)
			var p1 := a.lerp(b, float(s + 1) / segs)
			for v in [p0 + nrm, p1 + nrm, p1 - nrm, p0 + nrm, p1 - nrm, p0 - nrm]:
				st.add_vertex(Vector3(v.x, h(v.x, v.y) + lift, v.y))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.set_meta("ground", true)
	add_child(mi)


## Järvet ja lammet (OSM-monikulmiot) pinnan korkeudelle, puro ja tiet maaston myötäisinä, ruovikko rannoille.
func _build_waters_and_roads() -> void:
	var data := map_data()
	var water_mat := B.shader_mat("res://shaders/water.gdshader")
	for wi in data.water.size():
		var poly: PackedVector2Array = data.water[wi]
		var wy := water_level(wi)
		var idx := Geometry2D.triangulate_polygon(poly)
		if idx.is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for i in idx:
			st.add_vertex(Vector3(poly[i].x, wy, poly[i].y))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = water_mat
		mi.set_meta("ground", true)
		add_child(mi)
		# Ruovikko rantaviivalle (harvemmin kauempana mökistä).
		for k in poly.size() - 1:
			var a := poly[k]
			var b := poly[k + 1]
			if a.length() > 160.0:
				continue
			var cnt := int(a.distance_to(b) / 3.0)
			for c in cnt:
				var p := a.lerp(b, randf()) + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
				if absf(p.x - DOCK_LOCAL.x) < 2.5 and absf(p.y - DOCK_LOCAL.z) < 16.0:
					continue
				var reed := B.mesh(self, B.cyl(0.0, 0.02, 0.9 + randf() * 0.5, 5), Vector3(p.x, wy, p.y),
					Color(0.42, 0.5, 0.22).lightened(randf() * 0.15))
				reed.rotation.x = (randf() - 0.5) * 0.15
				reed.set_meta("ground", true)
	for s in data.streams:
		_strip(s, 0.8, 0.02, water_mat)
	var gravel := _ground_mat(Color(0.53, 0.47, 0.37), Color(0.64, 0.57, 0.45), 0.08, 1.1)
	var asphalt := _ground_mat(Color(0.2, 0.2, 0.21), Color(0.3, 0.3, 0.31), 0.1, 1.5)
	for r in data.roads:
		match r.type:
			"tertiary", "secondary":
				_strip(r.pts, 3.2, 0.06, asphalt)  # Neittäväntie ja Nuojuankoskentie päällystettyjä
			"path", "footway":
				_strip(r.pts, 0.6, 0.04, gravel)
			_:
				_strip(r.pts, 2.6 if r.type == "unclassified" else (1.4 if r.type == "service" else 1.8), 0.05, gravel)
	Sfx.loop_on(self, "water", -14.0).position = Vector3(DOCK_LOCAL.x, water_y(), DOCK_LOCAL.z - 4.0)


## Naapurit OSM-rakennuksina: seinät, harjakatto ja törmäys (oma mökki ja vaja mallinnetaan erikseen).
func _build_neighbors() -> void:
	# Harjan korkeudet laserkeilauksesta (tools/kartta/mokki_puut.py -> assets/mokki/rakennukset.json).
	var heights := {}
	if FileAccess.file_exists(HEIGHTS_PATH):
		heights = JSON.parse_string(FileAccess.get_file_as_string(HEIGHTS_PATH)).get("height", {})
	var walls := [Color(0.6, 0.15, 0.11), Color(0.9, 0.8, 0.45), Color(0.86, 0.8, 0.66), Color(0.92, 0.91, 0.87),
		Color(0.45, 0.3, 0.2), Color(0.58, 0.7, 0.78)]
	for bd in map_data().buildings:
		if bd.id in OWN_BUILDINGS:
			continue
		var poly: PackedVector2Array = bd.poly
		if poly.size() < 4:
			continue
		# Suorakaide kahdesta ensimmäisestä sivusta; epäsäännöllisille rajaava laatikko samassa suunnassa.
		var e1 := poly[1] - poly[0]
		var ang := atan2(e1.y, e1.x)
		var ax := e1.normalized()
		var az := ax.orthogonal()
		var mn := Vector2(INF, INF)
		var mx := -mn
		for p in poly:
			var q := Vector2((p - poly[0]).dot(ax), (p - poly[0]).dot(az))
			mn = mn.min(q)
			mx = mx.max(q)
		var size := mx - mn
		var cen := poly[0] + ax * ((mn.x + mx.x) / 2.0) + az * ((mn.y + mx.y) / 2.0)
		var small: bool = bd.type in ["shed", "cabin", "yes"] and size.x * size.y < 60.0
		var wall_h := 2.3 if small else 3.0
		var rise := 1.0 if small else 1.6
		var ridge: float = heights.get(str(bd.id), 0.0)
		if ridge > 0.0:
			# Laserin harjakorkeus: katon nousu lyhyemmän sivun mukaan, seinät loput.
			rise = clampf(minf(size.x, size.y) * 0.3, 0.8, 3.0)
			wall_h = clampf(ridge - rise, 2.1, 6.0)
			rise = maxf(ridge - wall_h, 0.6)
		var body := StaticBody3D.new()
		body.position = Vector3(cen.x, h(cen.x, cen.y), cen.y)
		body.rotation.y = -ang
		body.set_meta("ground", true)
		add_child(body)
		var col: Color = walls[hash(bd.id) % walls.size()]
		B.mesh(body, B.boxm(Vector3(size.x, wall_h, size.y)), Vector3(0, wall_h / 2.0 - 0.2, 0), col)
		var roof := PrismMesh.new()
		roof.size = Vector3(size.y + 0.8, rise, size.x + 0.6)
		B.mesh(body, roof, Vector3(0, wall_h - 0.2 + roof.size.y / 2.0, 0), Color(0.22, 0.22, 0.24), Vector3(0, 90, 0))
		body.add_child(B.box_shape(Vector3(size.x, wall_h, size.y), Vector3(0, wall_h / 2.0, 0)))


## Metsä oikeista puista: MML:n laserkeilaus (paikka, pituus, latvus) ja Luken VMI (laji), forest.gd. Puut on
## jo leivottu pois vesistä, pelloilta, teiltä, rakennuksilta ja pelin aukoista (tools/kartta/mokki_puut.py).
func _build_forest() -> void:
	var f := Forest.new()
	add_child(f)
	f.load_data(TREES_PATH)


func _build_lake_and_dock() -> void:
	_build_waters_and_roads()
	# Laituri: pukit ja lankut rannasta Likaselle (+Z). Rantapää maastoverkon kuivan maan pisteeseen: verkko
	# viettää rantaviivan ruudussa suoraan järven pohjaan, joten sen keskeltä alkava laituri leijuisi ilmassa.
	# Laituri nostetaan rantaan (ensure_built lisää y:hyn h:n); pukit ulottuvat järven pohjaan asti.
	var start_z := floorf((DOCK_LOCAL.z - 11.6) / GRID_STEP) * GRID_STEP
	while in_water(DOCK_LOCAL.x, start_z) and start_z > DOCK_LOCAL.z - 30.0:
		start_z -= GRID_STEP
	var dl := DOCK_LOCAL.z - start_z  # kannen pituus rannasta päähän
	var dock := StaticBody3D.new()
	dock.position = Vector3(DOCK_LOCAL.x, 0, start_z)
	add_child(dock)
	dock_body = dock
	# Paikkalaudat (laiturin korjaus, laituri_game.gd): lahot ja uudet laudat piirretään tämän alle.
	dock_patch = Node3D.new()
	dock_patch.name = "DockPatch"
	dock.add_child(dock_patch)
	var wi := water_at(DOCK_LOCAL.x, DOCK_LOCAL.z)
	var bed := (water_level(wi) if wi >= 0 else water_y()) - 1.0 - h(DOCK_LOCAL.x, start_z)  # pohja laiturin kehyksessä
	var wood := Color(0.5, 0.38, 0.24)
	var post_len := 0.22 - bed + 0.1
	for i in int(dl / 1.05) + 1:
		var z := i * 1.05
		for sx in [-0.65, 0.65]:
			B.mesh(dock, B.cyl(0.05, 0.06, post_len, 8), Vector3(sx, 0.22 - post_len / 2.0, z), Color(0.35, 0.26, 0.16))
	B.mesh(dock, B.boxm(Vector3(1.5, 0.06, dl + 1.2)), Vector3(0, 0.22, (dl + 0.4) / 2.0), wood)
	for i in int((dl + 0.8) / 0.55) + 1:
		B.mesh(dock, B.boxm(Vector3(1.46, 0.02, 0.42)), Vector3(0, 0.26, i * 0.55), wood.lightened(0.05 * (i % 2)))
	dock.add_child(B.box_shape(Vector3(1.5, 0.3, dl + 1.4), Vector3(0, 0.2, (dl + 0.4) / 2.0)))
	# Portaat rantapäähän: kansi on hieman maanpintaa korkeammalla, joten muutama askelma vie kannelta
	# rantaan (muuten CharacterBody ei nouse edes pienestä pystyreunasta).
	var shore_y := h(dock.position.x, dock.position.z - 2.2) - h(dock.position.x, dock.position.z)
	var deck_y := 0.25
	var stair_rise := deck_y - shore_y
	if stair_rise > 0.04:
		var stair_steps := maxi(2, ceili(stair_rise / 0.13))
		var stair_h := stair_rise / stair_steps
		for i in stair_steps:
			var sy := deck_y - (i + 0.5) * stair_h
			var sz := -0.5 - 0.16 - i * 0.32
			B.mesh(dock, B.boxm(Vector3(1.3, stair_h, 0.34)), Vector3(0, sy, sz), wood.darkened(0.06 * (i % 2)))
	# Askelmien päällä näkymätön luiska (CharacterBody ei nouse askelmia, ks. kuisti): alkaa maan alta ilman
	# reunaa ja päättyy kannen törmäyslaatikon yläpintaan.
	var top := 0.35
	var rise := top - shore_y + 0.4
	var run := maxf(1.2, rise * 1.6)
	var ramp := B.box_shape(Vector3(1.3, 0.1, Vector2(run, rise).length()), Vector3.ZERO)
	ramp.transform = Transform3D(Basis(Vector3.RIGHT, -atan2(rise, run)), Vector3(0, top - rise / 2.0 - 0.05, -0.5 - run / 2.0))
	dock.add_child(ramp)
	# Onkivapa nojaa laiturin päässä (ks. Mokki.DOCK_LOCAL, kalastus main.gd:ssä).
	var rod := Node3D.new()
	rod.position = Vector3(0.55, 0.3, dl)
	rod.rotation = Vector3(0, 0.3, -0.35)
	dock.add_child(rod)
	B.mesh(rod, B.cyl(0.012, 0.02, 2.4, 6), Vector3(0, 1.2, 0), Color(0.15, 0.15, 0.16))
	B.mesh(rod, B.sphere(0.03, 6), Vector3(0, 2.35, 0.05), Color(0.85, 0.15, 0.1))
	B.mesh(dock, B.boxm(Vector3(0.3, 0.16, 0.2)), Vector3(-0.5, 0.32, dl - 0.2), Color(0.32, 0.28, 0.24))  # varustelaatikko
	# Soutuvene laiturin kyljessä köysissä (kalastus: fish_game.gd). Vedessä h() on pohja = pinta - 1.
	boat_parked = Node3D.new()
	boat_parked.position = Vector3(DOCK_LOCAL.x + 1.75, 1.12, DOCK_LOCAL.z - 1.6)
	boat_parked.rotation.y = PI
	add_child(boat_parked)
	load("res://scripts/fish_game.gd").build_boat(boat_parked, true)


# --- Päärakennus ---------------------------------------------------------------

func _build_cottage() -> void:
	var l := 9.4
	var d := 5.0
	var found_h := 0.62
	var wall_h := 2.3
	var rise := 1.0
	var porch_d := 2.4
	var wall_col := Color(0.24, 0.15, 0.09)
	var dark_wood := Color(0.22, 0.18, 0.14)
	var conc := Color(0.62, 0.62, 0.6)
	var white := Color(0.94, 0.94, 0.9)
	var roof_col := Color(0.5, 0.51, 0.53)
	var deck_z := -d / 2.0 - porch_d / 2.0
	var body := StaticBody3D.new()
	body.position = Vector3(0, 0, -1.0)
	body.rotation.y = PI  # kuisti (rungon -Z) järvelle päin (+Z), kuten kuvissa
	add_child(body)
	# Pohja on suorakaide, jonka kuistin puoleisesta länsinurkasta puuttuu lovi: ulko-ovi on loven sisänurkassa
	# (sisätilassa tuvan vasen nurkka, mokki_interior.gd). Tien puoleinen takaseinä on suora.
	var notch := Vector2(1.1, 1.3)
	var notch_x := -l / 2.0 + notch.x
	# Sokkeli: tummat pystylaudat ja vaaleat betoniharkot vuorotellen (ei loven kohdalla).
	for i in 10:
		var x := -l / 2.0 + 0.5 + i * (l - 1.0) / 9.0
		if x < notch_x:
			continue
		B.mesh(body, B.boxm(Vector3((l - 1.0) / 9.0 - 0.03, found_h, 0.5)), Vector3(x, found_h / 2.0, -d / 2.0 - 0.05),
			conc if i % 3 == 1 else dark_wood)
	var full_h := wall_h + rise + found_h
	for part in [[Vector3(notch.x / 2.0, 0, 0), Vector3(l - notch.x, 0, d)],
			[Vector3(-l / 2.0 + notch.x / 2.0, 0, notch.y / 2.0), Vector3(notch.x, 0, d - notch.y)]]:
		var pc: Vector3 = part[0]
		var ps: Vector3 = part[1]
		body.add_child(B.box_shape(Vector3(ps.x, full_h, ps.z), Vector3(pc.x, full_h / 2.0 - found_h, pc.z)))
		# Tummanruskeat pystypaneeliseinät.
		B.mesh(body, B.boxm(Vector3(ps.x, wall_h, ps.z)), Vector3(pc.x, found_h + wall_h / 2.0, pc.z), wall_col)
	for i in 9:
		var x := -l / 2.0 + 0.2 + i * l / 8.0
		if x < notch_x + 0.05:
			continue
		B.mesh(body, B.boxm(Vector3(0.03, wall_h, 0.01)), Vector3(x, found_h + wall_h / 2.0, -d / 2.0 - 0.01), wall_col.lightened(0.14))
	# Harjakatto (pelti) talon ylle, symmetrinen harja keskellä.
	var ang := atan(rise / (d / 2.0))
	var half := (d / 2.0 + 0.5) / cos(ang)
	for sz in [-1.0, 1.0]:
		B.mesh(body, B.boxm(Vector3(l + 1.0, 0.08, half)), Vector3(0, found_h + wall_h + rise / 2.0, sz * d / 4.0),
			roof_col, Vector3(sz * rad_to_deg(ang), 0, 0))
	for sxg in [-1.0, 1.0]:
		var gable := PrismMesh.new()
		gable.size = Vector3(d, rise, 0.06)
		B.mesh(body, gable, Vector3(sxg * (l / 2.0 + 0.02), found_h + wall_h + rise / 2.0, 0), white, Vector3(0, 90, 0))
	# Kuistin tasainen lippakatto tolppien varassa.
	B.mesh(body, B.boxm(Vector3(l + 0.4, 0.08, porch_d + 0.4)), Vector3(0, found_h + wall_h + 0.04, deck_z), roof_col)
	# Rännit molempien räystäiden alla (takaräystään ränni putsataan tikkailta, ranni_game.gd).
	for sz in [-1.0, 1.0]:
		var gz: float = sz * (d / 2.0 + 0.35)
		B.mesh(body, B.boxm(Vector3(l + 0.9, 0.1, 0.13)), Vector3(0, GUTTER_UP - 0.04, gz), Color(0.42, 0.43, 0.45))
	B.mesh(body, B.cyl(0.045, 0.045, GUTTER_UP, 8), Vector3(-l / 2.0 - 0.3, GUTTER_UP / 2.0 - 0.1, d / 2.0 + 0.35), Color(0.42, 0.43, 0.45))  # syöksytorvi
	# Savupiippu (musta, korkilla).
	B.mesh(body, B.boxm(Vector3(0.5, 1.1, 0.5)), Vector3(l / 2.0 - 2.2, found_h + wall_h + rise + 0.35, 0.4), Color(0.08, 0.08, 0.09))
	B.mesh(body, B.boxm(Vector3(0.64, 0.08, 0.64)), Vector3(l / 2.0 - 2.2, found_h + wall_h + rise + 0.94, 0.4), Color(0.15, 0.15, 0.16))
	# Ikkunat ja ovi julkisivussa (-Z, kuistin puolella).
	var glass := Color(0.1, 0.14, 0.2)
	for wx in [-3.4, -0.6, 3.7]:
		B.mesh(body, B.boxm(Vector3(1.0, 1.15, 0.05)), Vector3(wx, found_h + 1.35, -d / 2.0 - 0.02), white)
		B.mesh(body, B.boxm(Vector3(0.85, 0.98, 0.06)), Vector3(wx, found_h + 1.35, -d / 2.0 - 0.03), glass)
	# Pesuhuoneen puinen ovi ikkunoineen kuistille ja pieni pesuhuoneen ikkuna (sisätilassa pesuhuoneen vasen seinä).
	var wash_x := -DOOR2_LOCAL.x
	B.mesh(body, B.boxm(Vector3(0.9, 2.0, 0.05)), Vector3(wash_x, found_h + 1.0, -d / 2.0 - 0.02), Color(0.66, 0.46, 0.27))
	B.mesh(body, B.boxm(Vector3(0.5, 0.55, 0.06)), Vector3(wash_x, found_h + 1.5, -d / 2.0 - 0.03), glass)
	B.mesh(body, B.boxm(Vector3(0.06, 0.08, 0.08)), Vector3(wash_x - 0.32, found_h + 0.95, -d / 2.0 - 0.06), Color(0.75, 0.72, 0.6))
	B.mesh(body, B.boxm(Vector3(0.55, 0.45, 0.05)), Vector3(wash_x + 0.95, found_h + 1.6, -d / 2.0 - 0.02), white)
	B.mesh(body, B.boxm(Vector3(0.45, 0.35, 0.06)), Vector3(wash_x + 0.95, found_h + 1.6, -d / 2.0 - 0.03), glass)
	# Ulko-ovi loven sisänurkassa kuistin puolella: lasiovi, edessä kuistin kansi, joka jatkuu loveen.
	var sx := -l / 2.0 + notch.x / 2.0
	var door := Node3D.new()
	door.position = Vector3(sx, found_h, -d / 2.0 + notch.y - 0.02)
	body.add_child(door)
	B.mesh(door, B.boxm(Vector3(0.95, 2.05, 0.06)), Vector3(0, 1.02, 0), white)
	B.mesh(door, B.boxm(Vector3(0.75, 1.8, 0.07)), Vector3(0, 1.05, 0), glass)
	B.mesh(door, B.boxm(Vector3(0.1, 0.1, 0.08)), Vector3(0.36, 1.0, -0.03), Color(0.75, 0.72, 0.6))
	# Tien puoleisessa takaseinässä vain makuuhuoneen ikkuna (sisätilassa makuuhuone oikealla tien puolella).
	B.mesh(body, B.boxm(Vector3(1.0, 1.15, 0.05)), Vector3(2.7, found_h + 1.35, d / 2.0 + 0.02), white)
	B.mesh(body, B.boxm(Vector3(0.85, 0.98, 0.06)), Vector3(2.7, found_h + 1.35, d / 2.0 + 0.03), glass)
	# Maan korkeus rungon koordinaateissa mökin lattiatasoon nähden (rinne).
	var g := func(bx: float, bz: float) -> float:
		return h(-bx, -bz - 1.0) - h(0.0, -1.0)
	# Rinteessä (korkeusmalli: maa laskee järvelle päin) sokkeli ja kuistin alusta jatkuvat maahan asti.
	var low := 0.0
	for bx in [-l / 2.0 - 0.3, 0.0, l / 2.0 + 0.3]:
		for bz in [d / 2.0, 0.0, -d / 2.0, deck_z, -d / 2.0 - porch_d]:
			low = minf(low, g.call(bx, bz))
	low -= 0.15
	if low < -0.2:
		B.mesh(body, B.boxm(Vector3(l - 0.04, -low, d - 0.04)), Vector3(0, low / 2.0, 0), dark_wood)
		B.mesh(body, B.boxm(Vector3(l - 0.1, found_h - 0.07 - low, porch_d - 0.1)), Vector3(0, (found_h - 0.07 + low) / 2.0, deck_z), dark_wood)
		body.add_child(B.box_shape(Vector3(l, -low, d), Vector3(0, low / 2.0, 0)))
		body.add_child(B.box_shape(Vector3(l, found_h - low, porch_d), Vector3(0, (found_h + low) / 2.0, deck_z)))
	# Kuisti: kansi, valkoinen kaide, tolpat ja portaat länsipäässä.
	B.mesh(body, B.boxm(Vector3(l, 0.1, porch_d)), Vector3(0, found_h - 0.02, deck_z), Color(0.62, 0.5, 0.36))
	for x in [-l / 2.0 + 0.3, -l / 2.0 + 1.9, -l / 2.0 + 3.5, -l / 2.0 + 5.1, -l / 2.0 + 6.7, l / 2.0 - 0.3]:
		B.mesh(body, B.boxm(Vector3(0.14, wall_h, 0.14)), Vector3(x, found_h + wall_h / 2.0, deck_z - porch_d / 2.0), white)
	# Kaide kannen ulkoreunassa tolppien linjassa: yläpuu ja pystyrimat kannesta yläpuuhun.
	var rail_z := deck_z - porch_d / 2.0 + 0.07
	B.mesh(body, B.boxm(Vector3(l - 0.2, 0.06, 0.08)), Vector3(0, found_h + 0.86, rail_z), white)
	for i in 26:
		B.mesh(body, B.boxm(Vector3(0.03, 0.83, 0.03)), Vector3(-l / 2.0 + 0.3 + i * (l - 0.6) / 25.0, found_h + 0.445, rail_z), white)
	# Portaat lännessä maahan (rinteessä askelmia on niin monta kuin maan tasoon tarvitaan).
	var foot := minf(g.call(-l / 2.0 - 1.0, deck_z + 0.5), 0.0)
	var stx := -l / 2.0 - 0.15
	var steps := maxi(3, ceili((found_h - foot) / 0.21))
	var step_h := (found_h - foot) / steps
	for i in steps:
		var sy := found_h - (i + 0.5) * step_h
		B.mesh(body, B.boxm(Vector3(0.32, step_h, 1.1)), Vector3(stx - i * 0.3, sy, deck_z + 0.5), Color(0.5, 0.4, 0.28))
	# Kuistin lattia kiinteäksi (muuten kävellään maata pitkin ja kansi leikkaa polvista) ja portaiden kohdalle
	# loiva luiska: CharacterBody ei nouse porrasaskelmia, mutta kävelee alle 45° rinnettä ylös.
	body.add_child(B.box_shape(Vector3(l, found_h + 0.03, porch_d), Vector3(0, (found_h + 0.03) / 2.0, deck_z)))
	# Kansi jatkuu loveen oven eteen, alla umpinainen alusta maahan asti.
	var nz := -d / 2.0 + notch.y / 2.0
	var nlow := minf(minf(g.call(sx, -d / 2.0), g.call(sx, -d / 2.0 + notch.y)), 0.0) - 0.1
	B.mesh(body, B.boxm(Vector3(notch.x, 0.1, notch.y)), Vector3(sx, found_h - 0.02, nz), Color(0.62, 0.5, 0.36))
	B.mesh(body, B.boxm(Vector3(notch.x - 0.05, found_h - 0.07 - nlow, notch.y - 0.05)), Vector3(sx, (found_h - 0.07 + nlow) / 2.0, nz), dark_wood)
	body.add_child(B.box_shape(Vector3(notch.x, found_h + 0.03 - nlow, notch.y), Vector3(sx, (found_h + 0.03 + nlow) / 2.0, nz)))
	# Luiska alkaa maan tason alta (-0,4), jotta rinteessä sen alapää ei jää askelmaksi.
	var ramp_rise := found_h - foot + 0.4
	var run := maxf(2.0, ramp_rise * 1.6)
	var ramp := B.box_shape(Vector3(Vector2(run, ramp_rise).length(), 0.1, 1.1), Vector3.ZERO)
	ramp.transform = Transform3D(Basis(Vector3.BACK, atan2(ramp_rise, run)),
		Vector3(-l / 2.0 - run / 2.0, found_h - ramp_rise / 2.0 - 0.05, deck_z + 0.5))
	body.add_child(ramp)
	# Kuistin sohva, tuolit ja pöytä (kuten kuvissa).
	body.add_child(B.box_shape(Vector3(1.7, 0.6, 0.9), Vector3(-1.5, found_h + 0.3, deck_z + 0.5)))
	body.add_child(B.box_shape(Vector3(0.6, 0.45, 0.6), Vector3(3.6, found_h + 0.22, deck_z + 0.6)))
	B.mesh(body, B.boxm(Vector3(1.7, 0.55, 0.75)), Vector3(-1.5, found_h + 0.3, deck_z + 0.55), Color(0.32, 0.26, 0.22))
	B.mesh(body, B.boxm(Vector3(1.7, 0.5, 0.16)), Vector3(-1.5, found_h + 0.62, deck_z + 0.2), Color(0.36, 0.3, 0.26))
	B.mesh(body, B.cyl(0.28, 0.3, 0.05, 16), Vector3(3.6, found_h + 0.42, deck_z + 0.6), Color(0.55, 0.42, 0.28))
	# Nimikyltti kuistilla.
	var plate := B.sign_plate(body, "MÖKKI PAAPELI", Color(0.36, 0.2, 0.1), Color(0.98, 0.95, 0.86), 0.2, 34,
		Color(0.3, 0.18, 0.1), "Helvetica Neue")
	plate.position = Vector3(0, found_h + wall_h - 0.15, -d / 2.0 - 0.06)
	plate.rotation.y = PI


# --- Kesäkeittiö: avoin katos offset-savustimineen -------------------------------------

## Kuvien mukaan rannan puolella paljun oikealla (kuistilta katsottuna): avoin puukatos, jonka alla
## offset-savustin ja pöytä. Halkopino katoksen vieressä. (Vieressä ollut käyttämätön lautavaja purettu.)
func _build_summer_kitchen() -> void:
	var dark_roof := Color(0.24, 0.22, 0.2)
	var post := Color(0.4, 0.3, 0.2)
	# Avoin katos: tolpat, loiva katto, savustin, pöytä ja penkki.
	var katos := Node3D.new()
	katos.position = KITCHEN_LOCAL + Vector3(-0.2, 0, 2.0)
	add_child(katos)
	for px in [-1.6, 1.4]:
		for pz in [-1.4, 1.4]:
			B.mesh(katos, B.cyl(0.07, 0.08, 2.2, 8), Vector3(px, 1.1, pz), post)
	var kroof := B.mesh(katos, B.boxm(Vector3(3.6, 0.06, 3.4)), Vector3(-0.1, 2.25, 0), dark_roof)
	kroof.rotation.z = 0.12
	var smoker := Node3D.new()
	smoker.position = Vector3(0.2, 0, -0.9)
	katos.add_child(smoker)
	B.mesh(smoker, B.cyl(0.35, 0.4, 1.0, 14), Vector3(0, 0.55, 0), Color(0.15, 0.15, 0.16), Vector3(0, 0, 90))
	B.mesh(smoker, B.cyl(0.22, 0.24, 0.55, 12), Vector3(-0.55, 0.4, 0), Color(0.15, 0.15, 0.16), Vector3(0, 0, 90))
	B.mesh(smoker, B.cyl(0.04, 0.04, 0.6, 8), Vector3(-0.55, 0.85, 0), Color(0.15, 0.15, 0.16))
	for legx in [-0.4, 0.4]:
		for legz in [-0.28, 0.28]:
			B.mesh(smoker, B.cyl(0.03, 0.03, 0.5, 6), Vector3(legx, 0.25, legz), Color(0.1, 0.1, 0.1))
	# Tulipesä (offset-laatikko) hehkuu ja piipusta nousee savu, kun savustin on käytössä.
	_smoker_fire = _make_fire(smoker, Vector3(-0.55, 0.2, 0), 0.4)
	_smoker_smoke = CPUParticles3D.new()
	_smoker_smoke.position = Vector3(-0.55, 1.15, 0)
	_smoker_smoke.emitting = false
	_smoker_smoke.amount = 40
	_smoker_smoke.lifetime = 3.5
	_smoker_smoke.direction = Vector3(0.15, 1, 0)
	_smoker_smoke.spread = 12.0
	_smoker_smoke.gravity = Vector3(0.25, 0.35, 0)
	_smoker_smoke.initial_velocity_min = 0.4
	_smoker_smoke.initial_velocity_max = 0.8
	_smoker_smoke.scale_amount_min = 0.8
	_smoker_smoke.scale_amount_max = 2.2
	var puff := SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	puff.material = B.unshaded(Color(0.78, 0.78, 0.8, 0.28))
	_smoker_smoke.mesh = puff
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	_smoker_smoke.scale_amount_curve = grow
	smoker.add_child(_smoker_smoke)
	var kbody := StaticBody3D.new()
	katos.add_child(kbody)
	kbody.add_child(B.box_shape(Vector3(1.4, 1.0, 0.8), Vector3(0.2, 0.5, -0.9)))
	kbody.add_child(B.box_shape(Vector3(1.6, 0.9, 0.7), Vector3(-0.3, 0.45, 0.8)))
	B.mesh(katos, B.boxm(Vector3(1.6, 0.9, 0.6)), Vector3(-0.3, 0.45, 0.8), Color(0.32, 0.3, 0.28))  # keittiötaso
	B.mesh(katos, B.boxm(Vector3(1.6, 0.05, 0.62)), Vector3(-0.3, 0.92, 0.8), Color(0.5, 0.5, 0.5))
	# Halkopino katoksen vieressä, kuten kuvassa.
	for row in 5:
		for col in 8:
			var log_mi := B.mesh(self, B.cyl(0.07, 0.07, 0.4, 5), Vector3(-16.4 + col * 0.32, 0.12 + row * 0.2, 19.6),
				Color(0.72, 0.58, 0.38) if (row + col) % 3 else Color(0.62, 0.48, 0.3))
			log_mi.rotation.x = PI / 2.0


# --- Savusauna ------------------------------------------------------------------

func _build_savusauna() -> void:
	var w := 3.4
	var d := 2.9
	var wall_h := 2.0
	var rise := 0.7
	var log_col := Color(0.42, 0.32, 0.2)
	var sauna := StaticBody3D.new()
	sauna.position = SAUNA_LOCAL + Vector3(0, 0, 1.0)  # akselinsuuntainen: ei kiertoa, ovi ja terassi -X:ssä paljulle päin
	add_child(sauna)
	var offs := [d / 2.0, w / 2.0, -d / 2.0, -w / 2.0]  # side 0..3: +Z, +X, -Z, -X (ovi)
	# Pyöröhirsiseinät (kaksi pitkää, kaksi lyhyttä, ovi -X:ssä).
	for side in 4:
		var horiz := side % 2 == 0
		var len := w if horiz else d
		var off: float = offs[side]
		var y := 0.14
		while y < wall_h:
			var col := log_col if int(y * 10) % 2 else log_col.darkened(0.12)
			if horiz:
				B.mesh(sauna, B.cyl(0.09, 0.09, len + 0.18, 8), Vector3(0, y, off), col, Vector3(0, 0, 90))
			elif side == 3 and y < 1.7:
				for sz in [-1.0, 1.0]:
					B.mesh(sauna, B.cyl(0.09, 0.09, (len - 0.8) / 2.0, 8), Vector3(off, y, sz * (len + 0.8) / 4.0), col, Vector3(90, 0, 0))
			else:
				B.mesh(sauna, B.cyl(0.09, 0.09, len + 0.18, 8), Vector3(off, y, 0), col, Vector3(90, 0, 0))
			y += 0.17
	# Törmäys kolmelle umpiseinälle; oviseinä jätetään avoimeksi (kulkuaukko).
	for side in range(3):
		var horiz2 := side % 2 == 0
		var off2: float = offs[side]
		if horiz2:
			sauna.add_child(B.box_shape(Vector3(w + 0.2, wall_h, 0.2), Vector3(0, wall_h / 2.0, off2)))
		else:
			sauna.add_child(B.box_shape(Vector3(0.2, wall_h, d + 0.2), Vector3(off2, wall_h / 2.0, 0)))
	# Harjakatto (harja Z-suunnassa, lappeet ovelle päin) ja piippu.
	var roof := PrismMesh.new()
	roof.size = Vector3(w + 0.9, rise, d + 0.9)
	B.mesh(sauna, roof, Vector3(0, wall_h + rise / 2.0, 0), Color(0.24, 0.22, 0.2))
	B.mesh(sauna, B.cyl(0.1, 0.12, 0.9, 10), Vector3(0.6, wall_h + rise + 0.4, 0), Color(0.4, 0.16, 0.1))
	# Ovi ja pieni ikkuna.
	var door := Node3D.new()
	door.position = Vector3(-w / 2.0 - 0.03, 0.05, 0.55)
	sauna.add_child(door)
	B.mesh(door, B.boxm(Vector3(0.06, 1.7, 0.75)), Vector3(0, 0.85, 0), Color(0.35, 0.24, 0.14))
	B.mesh(sauna, B.boxm(Vector3(0.05, 0.5, 0.5)), Vector3(-w / 2.0 - 0.02, 1.1, -0.7), Color(0.94, 0.94, 0.9))
	# Katettu terassi ovella: pukit, penkki, jakkarat ja saavit (kuten kuvassa).
	for pz in [-0.9, 0.9]:
		B.mesh(sauna, B.cyl(0.08, 0.08, wall_h + rise, 8), Vector3(-w / 2.0 - 2.1, (wall_h + rise) / 2.0, pz), log_col)
	var proof := PrismMesh.new()
	proof.size = Vector3(2.4, 0.5, d + 0.4)
	B.mesh(sauna, proof, Vector3(-w / 2.0 - 2.1, wall_h + rise * 0.5, 0), Color(0.24, 0.22, 0.2))
	B.mesh(sauna, B.boxm(Vector3(1.5, 0.5, 0.7)), Vector3(-w / 2.0 - 2.5, 0.3, -0.6), Color(0.3, 0.26, 0.22))
	B.mesh(sauna, B.cyl(0.28, 0.3, 0.4, 16), Vector3(-w / 2.0 - 2.0, 0.22, 0.9), Color(0.34, 0.24, 0.15))
	B.mesh(sauna, B.cyl(0.2, 0.22, 0.35, 12), Vector3(-w / 2.0 - 1.4, 0.19, 1.0), Color(0.3, 0.22, 0.14))
	# Sisätila: penkit, kiuas ja tynnyri.
	for pz in [-0.9, 0.0, 0.9]:
		B.mesh(sauna, B.boxm(Vector3(w - 0.5, 0.06, 0.5)), Vector3(0.6, 0.55, pz), Color(0.62, 0.5, 0.34))
	B.mesh(sauna, B.boxm(Vector3(w - 0.5, 0.06, 0.9)), Vector3(0.6, 0.95, 0), Color(0.62, 0.5, 0.34))
	var kiuas_local: Vector3 = SAUNA_LOCAL - sauna.position
	B.mesh(sauna, B.cyl(0.18, 0.22, 0.6, 10), Vector3(kiuas_local.x, 0.3, kiuas_local.z), Color(0.3, 0.3, 0.32))
	_sauna_fire = _make_fire(sauna, Vector3(kiuas_local.x, 0.62, kiuas_local.z), 0.55)
	B.mesh(sauna, B.cyl(0.1, 0.13, 0.55, 10), Vector3(kiuas_local.x + 0.45, 0.28, kiuas_local.z), Color(0.55, 0.4, 0.25))  # tuohinen kiulu
	B.mesh(sauna, B.cyl(0.15, 0.1, 0.5, 10), Vector3(0.6, wall_h - 0.05, -1.1), Color(0.22, 0.22, 0.24))  # savuhormi kattoon
	# Savusaunan savu: lämmittäessä paksua savua ovesta ja räppänästä, tuulettuessa ohenee.
	_sauna_smoke_fx = _smoke_fx(Vector3(-w / 2.0 - 0.2, 1.7, 0.4))
	sauna.add_child(_sauna_smoke_fx)
	# Ampiaispesä terassin katon alla etukulmassa (Santun homma: ampiais_game.gd). Näkyy vain homman päivänä.
	wasp_nest = Node3D.new()
	wasp_nest.position = Vector3(-w / 2.0 - 1.5, 1.95, -0.6)
	wasp_nest.visible = false
	sauna.add_child(wasp_nest)
	var paper := Color(0.62, 0.58, 0.5)
	for k in 5:
		var ring := B.mesh(wasp_nest, B.sphere(0.13 - absf(k - 2) * 0.025, 12), Vector3(0, -k * 0.055, 0), paper.darkened(0.06 * (k % 2)))
		ring.scale = Vector3(1.0, 0.6, 1.0)
	B.mesh(wasp_nest, B.sphere(0.03, 8), Vector3(0, -0.27, 0), Color(0.08, 0.07, 0.06))  # suuaukko
	B.mesh(wasp_nest, B.cyl(0.015, 0.02, 0.12, 6), Vector3(0, 0.08, 0), paper.darkened(0.2))


func _make_fire(parent: Node3D, pos: Vector3, sz: float) -> Node3D:
	var fire := Node3D.new()
	fire.position = pos
	fire.visible = false
	parent.add_child(fire)
	for k in 4:
		var fl := MeshInstance3D.new()
		fl.mesh = B.cyl(0.0, (0.12 - k * 0.02) * sz, (0.4 + k * 0.06) * sz, 6)
		fl.material_override = B.unshaded(Color(1.6, 0.6 + k * 0.1, 0.1))
		fl.position = Vector3(cos(k * 1.6) * 0.08 * sz, 0.15 * sz + k * 0.02, sin(k * 1.6) * 0.08 * sz)
		fl.name = "Flame%d" % k
		fire.add_child(fl)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.2)
	glow.light_energy = 2.0
	glow.omni_range = 5.0
	glow.name = "Glow"
	fire.add_child(glow)
	return fire


# --- Puulämmitteinen palju -----------------------------------------------------

func _build_hottub() -> void:
	var tub := StaticBody3D.new()
	tub.position = TUB_LOCAL
	add_child(tub)
	tub.add_child(B.capsule_shape(0.95, 0.9))
	# Puinen palju: tummat laudat ulkona, musta sisäkuori ja vanteet.
	B.mesh(tub, B.cyl(0.95, 0.98, 0.85, 20), Vector3(0, 0.42, 0), Color(0.36, 0.25, 0.16))
	B.mesh(tub, B.cyl(0.88, 0.88, 0.8, 20), Vector3(0, 0.46, 0), Color(0.07, 0.07, 0.08))
	_palju_water = B.mesh(tub, B.cyl(0.86, 0.86, 0.05, 20), Vector3(0, 0.86, 0), Color(0.15, 0.35, 0.42, 0.85))
	# Levät ja lehdet pohjalla (näkyy, kun palju on tyhjä ja likainen).
	_palju_dirt = B.mesh(tub, B.cyl(0.85, 0.85, 0.02, 20), Vector3(0, 0.08, 0), Color(0.22, 0.3, 0.12))
	_palju_dirt.visible = false
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.22, 0.3, 0.12)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.roughness = 1.0
	_palju_dirt.material_override = dm
	for k in 3:
		B.mesh(tub, B.cyl(0.99, 0.99, 0.04, 20), Vector3(0, 0.2 + k * 0.28, 0), Color(0.18, 0.18, 0.2))
	# Tyhjennysventtiili kyljessä.
	B.mesh(tub, B.cyl(0.04, 0.04, 0.2, 8), Vector3(-0.98, 0.1, 0.0), Color(0.6, 0.6, 0.62), Vector3(0, 0, 90))
	B.mesh(tub, B.cyl(0.14, 0.16, 0.45, 10), Vector3(0.7, 0.0, 0.7), Color(0.3, 0.3, 0.32))  # tulipesän piippu
	_tub_fire = _make_fire(tub, Vector3(0.7, 0.05, 0.7), 0.55)
	var steps := Node3D.new()
	steps.position = Vector3(-1.1, 0, 0)
	tub.add_child(steps)
	for i in 2:
		B.mesh(steps, B.boxm(Vector3(0.6, 0.18, 0.4)), Vector3(0, 0.1 + i * 0.2, -i * 0.35), Color(0.5, 0.38, 0.25))


# --- Piha: tikkataulu, savustin, taksipysäkki -------------------------------------

func _build_yard_extras() -> void:
	# Tikkataulu männyn rungossa, kääntyneenä heittopistettä (etelää) kohti.
	var tree := StaticBody3D.new()
	tree.position = DART_TREE
	add_child(tree)
	B.mesh(tree, B.cyl(0.22, 0.3, 6.0, 10), Vector3(0, 3.0, 0), Color(0.4, 0.26, 0.16))
	for k in 3:
		B.mesh(tree, B.cyl(0.02, 1.3 - k * 0.3, 1.8, 8), Vector3(0, 4.6 + k * 1.1, 0), Color(0.16, 0.28, 0.14))
	var board := DartsGame.make_board(tree)  # oikea tikkataulu, etupinta heittopisteelle (-Z)
	board.position = Vector3(0, DART_BOARD_UP, -0.36)
	tree.add_child(B.capsule_shape(0.3, 6.0))
	# Penkit ja nuotiopaikka paljun edessä (kuten kuistilta otetussa kuvassa).
	for bp in [TUB_LOCAL + Vector3(-2.2, 0, -2.4), TUB_LOCAL + Vector3(2.4, 0, -2.4), TUB_LOCAL + Vector3(-2.6, 0, 1.0)]:
		B.mesh(self, B.boxm(Vector3(1.6, 0.08, 0.35)), bp + Vector3(0, 0.42, 0), Color(0.45, 0.34, 0.22))
		for lx in [-0.65, 0.65]:
			B.mesh(self, B.boxm(Vector3(0.1, 0.4, 0.3)), bp + Vector3(lx, 0.2, 0), Color(0.38, 0.28, 0.18))
	for k in 8:
		var a := TAU * k / 8.0
		B.mesh(self, B.sphere(0.12, 6), TUB_LOCAL + Vector3(0.2 + cos(a) * 0.45, 0.06, -3.8 + sin(a) * 0.45), Color(0.45, 0.44, 0.42))
	# Taksipysäkki: kyltti ja pysäköity taksi pihatien päässä.
	var taxi_sign := B.sign_pole(self, TAXI_LOCAL + Vector3(1.4, 0, 0), 2.4)
	var tplate := B.sign_plate(taxi_sign, "TAKSI", Color(0.96, 0.78, 0.08), Color(0.05, 0.05, 0.05), 0.26, 40,
		Color(0.05, 0.05, 0.05), "Helvetica Neue")
	tplate.position.y = 2.1
	B.parked_car(self, TAXI_LOCAL + Vector3(-2.6, 0, 1.0), 12.0, Color(0.96, 0.78, 0.08))
	B.mesh(self, B.boxm(Vector3(0.5, 0.16, 0.3)), TAXI_LOCAL + Vector3(-2.6, 1.68, 1.0), Color(0.9, 0.85, 0.2))
	# Droonin alusta: sama drooni kulkee mukana taksissa kotoa.
	DroneGame.make_pad(self, DRONE_LOCAL, 0.0)
	# Pihatie taksipysäkiltä pihaan (sora).
	var road_mat := B.shader_mat("res://shaders/ground.gdshader", {
		"color_a": Color(0.53, 0.47, 0.37), "color_b": Color(0.64, 0.57, 0.45), "scale": 0.08,
		"fine_scale": 1.1, "bump": 0.6, "roughness_v": 1.0, "stripes": 0.0,
	})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var a := Vector2(TAXI_LOCAL.x, TAXI_LOCAL.z)
	var b := Vector2(1.0, -4.5)  # mökin takaseinälle (pysäköinti mökin takana, kuten drone-kuvassa)
	var n := (b - a).normalized().orthogonal() * 1.6
	var segs := 10
	for s in segs:
		var p0 := a.lerp(b, float(s) / segs)
		var p1 := a.lerp(b, float(s + 1) / segs)
		for v in [p0 + n, p1 + n, p1 - n, p0 + n, p1 - n, p0 - n]:
			st.add_vertex(Vector3(v.x, h(v.x, v.y) + 0.04, v.y))  # maaston myötäinen sora
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = road_mat
	mi.set_meta("ground", true)
	add_child(mi)


## Riistapolku: matala metsästyslava puuta vasten ja pieni kyltti, josta löytää paikan syvemmältä metsästä.
func _build_hunt_spot() -> void:
	var wood := Color(0.4, 0.3, 0.2)
	var tree := StaticBody3D.new()
	tree.position = HUNT_LOCAL + Vector3(0.6, 0, -0.4)
	add_child(tree)
	B.mesh(tree, B.cyl(0.2, 0.28, 6.5, 9), Vector3(0, 3.25, 0), Color(0.38, 0.27, 0.17))
	for k in 3:
		B.mesh(tree, B.cyl(0.02, 1.2 - k * 0.25, 1.7, 8), Vector3(0, 5.0 + k * 1.05, 0), Color(0.15, 0.27, 0.14))
	tree.add_child(B.capsule_shape(0.3, 6.5))
	var stand := Node3D.new()
	stand.position = HUNT_LOCAL
	add_child(stand)
	for lx in [-0.5, 0.5]:
		for lz in [-0.4, 0.4]:
			B.mesh(stand, B.cyl(0.04, 0.05, 1.1, 6), Vector3(lx, 0.55, lz), wood)
	B.mesh(stand, B.boxm(Vector3(1.1, 0.08, 0.9)), Vector3(0, 1.1, 0), wood.lightened(0.08))
	var sign := B.sign_pole(self, HUNT_LOCAL + Vector3(1.4, 0, 1.0), 1.5)
	var plate := B.sign_plate(sign, "RIISTAPOLKU", Color(0.32, 0.24, 0.14), Color(0.92, 0.88, 0.78), 0.18, 26,
		Color(0.3, 0.18, 0.1), "Helvetica Neue")
	plate.position.y = 1.3


## Paapelin mopo parkissa (sama malli kuin ajettava, mopo.gd); main.gd piilottaa sen matkan ajaksi.
var mopo_parked: Node3D


func _build_mopo() -> void:
	mopo_parked = Node3D.new()
	mopo_parked.position = MOPO_LOCAL
	mopo_parked.rotation.y = PI * 0.9
	add_child(mopo_parked)
	Mopo.build_model(mopo_parked)
	mopo_parked.rotation.z = 0.08  # seisontatuella


## Viinakätköt: ruosteinen ammuslaatikko puoliksi kivien ja sammalen alla (kuten geokätkö), vieressä kuivunut
## oksa merkkinä. Laatikko jää paikalleen, kun viina on otettu.
func _build_viina_caches() -> void:
	var rust := Color(0.36, 0.3, 0.18)
	var stone := Color(0.46, 0.46, 0.44)
	var moss := Color(0.2, 0.24, 0.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for p in viina_positions():
		var c := Node3D.new()
		c.position = Vector3(p.x, 0, p.y)
		c.rotation.y = rng.randf() * TAU
		add_child(c)
		B.mesh(c, B.sphere(0.55, 10), Vector3(0, -0.3, 0), moss)
		B.mesh(c, B.boxm(Vector3(0.36, 0.2, 0.2)), Vector3(0, 0.12, 0), rust)
		B.mesh(c, B.boxm(Vector3(0.38, 0.04, 0.22)), Vector3(0, 0.23, 0), rust.darkened(0.25))
		B.mesh(c, B.boxm(Vector3(0.1, 0.03, 0.04)), Vector3(0, 0.26, 0), rust.darkened(0.45))
		for k in 4:
			var ang := k * TAU / 4.0 + rng.randf_range(-0.3, 0.3)
			var r := rng.randf_range(0.14, 0.24)
			B.mesh(c, B.sphere(r, 8), Vector3(cos(ang) * 0.38, r * 0.4, sin(ang) * 0.3), stone.darkened(rng.randf_range(0.0, 0.25)))
		B.tube(c, Vector3(0.45, 0.0, 0.25), Vector3(0.55, 0.9, 0.35), 0.025, Color(0.5, 0.42, 0.32))


## Pihapingiksen paikka: kaksi isoa puumailaa ja pallo kannon päällä, keskirajana köysi nurmella
## (E: pingistä Santtua vastaan, pingis_game.gd).
func _build_pingis_spot() -> void:
	var t := Node3D.new()
	t.position = PINGIS_LOCAL
	add_child(t)
	B.mesh(t, B.cyl(0.25, 0.28, 0.5, 12), Vector3(0, 0.25, 0), Color(0.42, 0.3, 0.18))
	B.mesh(t, B.cyl(0.23, 0.23, 0.01, 12), Vector3(0, 0.505, 0), Color(0.78, 0.66, 0.46))
	for m in [[Vector3(-0.08, 0.52, 0.02), 25.0, Color(0.85, 0.72, 0.5)], [Vector3(0.1, 0.535, -0.04), -40.0, Color(0.2, 0.45, 0.75)]]:
		B.mesh(t, B.cyl(0.2, 0.2, 0.015, 18), m[0], m[2], Vector3(0, m[1], 0))
		B.mesh(t, B.boxm(Vector3(0.035, 0.03, 0.16)), m[0] + Vector3(0, 0, 0.27).rotated(Vector3.UP, deg_to_rad(m[1])),
			Color(0.5, 0.34, 0.18), Vector3(0, m[1], 0))
	B.mesh(t, B.sphere(0.03, 8), Vector3(0.0, 0.58, 0.12), Color(1.0, 0.6, 0.15))
	B.mesh(t, B.boxm(Vector3(0.04, 0.02, 3.0)), Vector3(2.0, 0.01, 0), Color(0.95, 0.95, 0.9))  # keskiraja


# --- Männyt ympärillä --------------------------------------------------------------

## Isoja mäntyjä pihan reunoilla (ei rakennusten, kulkuväylien eikä laiturin polun päälle): mökki on
## metsän keskellä, joten piha rajautuu tiiviisti puihin joka suunnalta (harva metsä muualla _build_forest()).
func _build_trees() -> void:
	for tp in [Vector2(-10.0, 3.0), Vector2(12.0, 2.0), Vector2(-17.0, 10.0), Vector2(14.0, 12.0), Vector2(15.0, 26.0),
			Vector2(-4.0, 28.0), Vector2(-16.0, -6.0), Vector2(17.0, -8.0), Vector2(-19.0, 24.0), Vector2(18.0, 24.0),
			Vector2(2.0, 32.0), Vector2(-13.0, -18.0), Vector2(-6.0, -9.0), Vector2(9.0, -10.0)]:
		_pine(Vector3(tp.x, 0, tp.y), randf_range(0.9, 1.3))


func _pine(pos: Vector3, s: float) -> void:
	var t := StaticBody3D.new()
	t.position = pos
	add_child(t)
	var h := 7.0 * s
	B.mesh(t, B.cyl(0.12 * s, 0.22 * s, h * 0.5, 7), Vector3(0, h * 0.25, 0), Color(0.35, 0.25, 0.16))
	for k in 4:
		var fh := 1.6 * s * (1.0 - k * 0.12)
		B.mesh(t, B.cyl(0.03, fh * 0.62, fh, 7), Vector3(0, h * 0.4 + k * h * 0.16, 0),
			Color(0.15, 0.26, 0.14).lightened(0.04 * k))
	t.add_child(B.capsule_shape(0.25 * s, h * 0.8))


# --- Santtu, isäntä ------------------------------------------------------------

## Santun ulkonäkö (myös mökin sisällä, mokki_interior.gd).
const SANTTU_LOOK := {
	"shirt": Color(0.75, 0.55, 0.12), "pants": Color(0.25, 0.24, 0.26), "shoes": Color(0.3, 0.22, 0.15),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.4, 0.3, 0.18), "beard": true, "height": 1.78,
	"belly": 0.35, "bulk": -0.1,
}
## Mökin ulko-ovi länsinurkan lovessa kuistin puolella (paikallinen, oven edessä kannella): E vie sisään
## (main.gd _mokki_logic). PORCH_DIR = ovelta ulospäin kuistille.
const DOOR_LOCAL := Vector3(4.15, 0, 0.7)
const PORCH_DIR := Vector3(0, 0, 1)
## Pesuhuoneen ovi kuistille julkisivussa (paikallinen, oven edessä kannella): sisään pesuhuoneeseen.
const DOOR2_LOCAL := Vector3(-1.3, 0, 2.0)
const COTTAGE_DOOR_SPOT := DOOR_LOCAL  # PA-homma: Santtu tulee ovelle


func _build_santtu() -> void:
	var look := SANTTU_LOOK
	B.mesh(self, B.cyl(0.22, 0.26, 0.42, 12), SANTTU_LOCAL + Vector3(0, 0.21, 0), Color(0.4, 0.28, 0.17))  # pihatuoli (kanto)
	santtu = Looks.make(self, look)
	santtu.position = SANTTU_LOCAL + Vector3(0, 0.2, 0)
	santtu.rotation.y = B.yaw_to(Vector3(0, 0, -1))  # kasvot kohti mökkiä (kuisti järven puolella)
	santtu.play("Sitting_Idle", 0.0)
	var mug := Node3D.new()
	B.mesh(mug, B.cyl(0.035, 0.035, 0.08, 10), Vector3(0, -0.02, 0), Color(0.95, 0.95, 0.92))
	santtu.attach("hand_r", mug, Vector3(0, -0.02, 0.03))
	_bubble = B.label(self, "", SANTTU_LOCAL + Vector3(0, 1.6, 0), 16, Color.WHITE, true)
	_bubble.outline_size = 6
	_bubble.width = 700.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label = B.label(self, "Santtu, isäntä", SANTTU_LOCAL + Vector3(0, 1.3, 0), 12, Color(1, 0.9, 0.6), true)
	_name_label.no_depth_test = false


# --- Santun hommat: puupaikka, huussi, komposti, tikkaat, pumppu ja letku ---------------------

## Puupaikka (sahapukki ja pilkkomispölkky kuten kodalla, solmujen nimet samat: saw_game.gd ja chop_game.gd
## piilottavat ne pelin ajaksi), huussi, komposti ja tikkaat takaseinällä.
func _build_chore_spots() -> void:
	var dark := Color(0.3, 0.22, 0.14)
	var saw := Node3D.new()
	saw.position = PUU_SAW_LOCAL
	add_child(saw)
	for z in [-0.4, 0.4]:
		for sgn in [-1.0, 1.0]:
			var leg := B.mesh(saw, B.boxm(Vector3(0.07, 1.0, 0.07)), Vector3(0, 0.45, z), dark)
			leg.rotation.z = sgn * 0.5
	B.mesh(saw, B.boxm(Vector3(0.08, 0.08, 1.0)), Vector3(0, 0.45, 0), dark)
	var sawlog := B.mesh(saw, B.cyl(0.13, 0.14, 1.6, 10), Vector3(0, 0.88, 0), Color(0.85, 0.83, 0.78))
	sawlog.rotation.x = PI / 2.0
	sawlog.name = "SawLog"
	var bow := Node3D.new()
	bow.position = Vector3(0.05, 1.18, 0.35)
	bow.name = "Saw"
	saw.add_child(bow)
	B.mesh(bow, B.cyl(0.02, 0.02, 0.8, 8), Vector3(0, 0.25, 0), Color(0.95, 0.45, 0.05), Vector3(0, 0, PI / 2.0))
	B.mesh(bow, B.boxm(Vector3(0.78, 0.035, 0.005)), Vector3(0, -0.05, 0), Color(0.75, 0.76, 0.78))
	for sx in [-0.39, 0.39]:
		B.mesh(bow, B.cyl(0.018, 0.018, 0.32, 8), Vector3(sx, 0.1, 0), Color(0.95, 0.45, 0.05))
	var sb := StaticBody3D.new()
	sb.position = PUU_SAW_LOCAL + Vector3(0, 0.5, 0)
	sb.add_child(B.box_shape(Vector3(0.6, 1.0, 1.4)))
	add_child(sb)
	# Tukkipino sahapukin takana (sahaaja seisoo pukin -X-puolella).
	for i in 5:
		var l := B.mesh(self, B.cyl(0.14, 0.16, 3.0, 10), PUU_SAW_LOCAL + Vector3(-2.3 - (i % 3) * 0.3, 0.16 + (i / 3) * 0.26, 1.0),
			Color(0.85, 0.83, 0.78))
		l.rotation.x = PI / 2.0
	var chop := Node3D.new()
	chop.position = PUU_CHOP_LOCAL
	add_child(chop)
	B.mesh(chop, B.cyl(0.3, 0.34, 0.5, 12), Vector3(0, 0.25, 0), Color(0.5, 0.36, 0.22))
	B.mesh(chop, B.cyl(0.29, 0.29, 0.02, 12), Vector3(0, 0.51, 0), Color(0.8, 0.68, 0.48))
	var axe := Node3D.new()
	axe.position = Vector3(0.05, 0.52, 0)
	axe.rotation.z = -0.45
	axe.name = "Axe"
	chop.add_child(axe)
	B.mesh(axe, B.cyl(0.02, 0.025, 0.7, 8), Vector3(0, 0.35, 0), Color(0.75, 0.6, 0.35))
	B.mesh(axe, B.boxm(Vector3(0.16, 0.1, 0.03)), Vector3(0.05, 0.02, 0), Color(0.3, 0.3, 0.32))
	var cb := StaticBody3D.new()
	cb.position = PUU_CHOP_LOCAL + Vector3(0, 0.25, 0)
	cb.add_child(B.box_shape(Vector3(0.6, 0.5, 0.6)))
	add_child(cb)
	_build_huussi()
	_build_komposti()
	_build_ladder()
	_build_pump()


## Punainen lautahuussi sydänikkunoineen: ovi pihalle (+Z), takana luukku, josta sanko otetaan.
func _build_huussi() -> void:
	var red := Color(0.55, 0.18, 0.12)
	var white := Color(0.92, 0.9, 0.84)
	var hu := StaticBody3D.new()
	hu.position = HUUSSI_LOCAL
	add_child(hu)
	B.mesh(hu, B.boxm(Vector3(1.3, 2.1, 1.3)), Vector3(0, 1.05, 0), red)
	for k in 6:
		B.mesh(hu, B.boxm(Vector3(0.02, 2.1, 0.01)), Vector3(-0.55 + k * 0.22, 1.05, 0.655), red.darkened(0.2))
	var roof := PrismMesh.new()
	roof.size = Vector3(1.6, 0.45, 1.6)
	B.mesh(hu, roof, Vector3(0, 2.32, 0), Color(0.2, 0.2, 0.22))
	B.mesh(hu, B.boxm(Vector3(0.8, 1.85, 0.04)), Vector3(0, 0.95, 0.67), red.lightened(0.08))  # ovi
	for side in [-1.0, 1.0]:  # sydän: kaksi palloa ja kärki
		B.mesh(hu, B.sphere(0.055, 8), Vector3(side * 0.045, 1.62, 0.69), Color(0.05, 0.04, 0.04))
	var tip := B.mesh(hu, B.boxm(Vector3(0.08, 0.08, 0.02)), Vector3(0, 1.56, 0.69), Color(0.05, 0.04, 0.04))
	tip.rotation.z = PI / 4.0
	B.mesh(hu, B.boxm(Vector3(0.08, 0.04, 0.05)), Vector3(0.3, 0.95, 0.7), white)  # hakanen
	B.mesh(hu, B.boxm(Vector3(0.7, 0.45, 0.04)), Vector3(0, 0.3, -0.67), red.darkened(0.15))  # takaluukku
	B.mesh(hu, B.boxm(Vector3(0.12, 0.04, 0.05)), Vector3(0, 0.45, -0.7), white)
	hu.add_child(B.box_shape(Vector3(1.3, 2.1, 1.3), Vector3(0, 1.05, 0)))
	var sign := B.label(hu, "♥", Vector3(0, 2.0, 0.7), 20, Color(0.95, 0.85, 0.7), false)
	sign.no_depth_test = false
	huussi_flies = CPUParticles3D.new()
	huussi_flies.position = Vector3(0, 0.6, -0.9)
	huussi_flies.amount = 14
	huussi_flies.lifetime = 2.0
	huussi_flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	huussi_flies.emission_sphere_radius = 0.5
	huussi_flies.gravity = Vector3.ZERO
	huussi_flies.initial_velocity_min = 0.3
	huussi_flies.initial_velocity_max = 0.8
	huussi_flies.spread = 180.0
	var fly := SphereMesh.new()
	fly.radius = 0.012
	fly.height = 0.024
	fly.material = B.unshaded(Color(0.05, 0.05, 0.05))
	huussi_flies.mesh = fly
	huussi_flies.emitting = false
	hu.add_child(huussi_flies)


## Lautakehikkoinen komposti ja talikko kyljessä.
func _build_komposti() -> void:
	var wood := Color(0.48, 0.36, 0.22)
	var ko := StaticBody3D.new()
	ko.position = KOMPOSTI_LOCAL
	add_child(ko)
	for row in 4:
		for side in 4:
			var horiz := side % 2 == 0
			var off := 0.7 * (1.0 if side < 2 else -1.0)
			var plank := B.boxm(Vector3(1.45, 0.16, 0.04) if horiz else Vector3(0.04, 0.16, 1.45))
			B.mesh(ko, plank, Vector3(0 if horiz else off, 0.1 + row * 0.2, off if horiz else 0), wood.darkened(0.05 * (row % 2)))
	komposti_soil = B.mesh(ko, B.boxm(Vector3(1.36, 0.6, 1.36)), Vector3(0, 0.3, 0), Color(0.18, 0.14, 0.09))
	var fork := Node3D.new()
	fork.position = Vector3(0.85, 0, 0.5)
	fork.rotation.z = 0.25
	ko.add_child(fork)
	B.mesh(fork, B.cyl(0.018, 0.02, 1.4, 6), Vector3(0, 0.75, 0), Color(0.7, 0.55, 0.32))
	for k in 4:
		B.mesh(fork, B.cyl(0.006, 0.006, 0.25, 4), Vector3(-0.06 + k * 0.04, 0.08, 0), Color(0.35, 0.35, 0.37))
	ko.add_child(B.box_shape(Vector3(1.45, 0.8, 1.45), Vector3(0, 0.4, 0)))


## Alumiinitikkaat takaseinää vasten räystääseen (ranni_game.gd piirtää omansa pelin ajaksi).
func _build_ladder() -> void:
	ladder = Node3D.new()
	ladder.name = "Ladder"
	ladder.position = LADDER_LOCAL
	add_child(ladder)
	make_ladder(ladder, 3.1)


## Tikkaat juuresta ylös nojaten +Z:aan (kaltevuus noin 15°).
static func make_ladder(parent: Node3D, length: float) -> void:
	var alu := Color(0.72, 0.74, 0.76)
	var lean := 0.26
	var leg := Node3D.new()
	leg.rotation.x = lean
	parent.add_child(leg)
	for sx in [-0.22, 0.22]:
		B.mesh(leg, B.boxm(Vector3(0.04, length, 0.06)), Vector3(sx, length / 2.0, 0), alu)
	for k in int(length / 0.3):
		B.mesh(leg, B.cyl(0.015, 0.015, 0.44, 6), Vector3(0, 0.25 + k * 0.3, 0), alu.darkened(0.1), Vector3(0, 0, 90))


## Paljun täyttöpumppu rannassa laiturin vieressä (bensamoottori ja imuletku järveen).
static func pump_local() -> Vector3:
	var x := DOCK_LOCAL.x - 1.7
	var z := DOCK_LOCAL.z - 8.0
	while in_water(x, z) and z > 20.0:
		z -= 1.0
	return Vector3(x, 0, z - 1.4)


func _build_pump() -> void:
	var pump := Node3D.new()
	pump.position = pump_local()
	add_child(pump)
	B.mesh(pump, B.boxm(Vector3(0.5, 0.35, 0.38)), Vector3(0, 0.2, 0), Color(0.8, 0.12, 0.08))
	B.mesh(pump, B.cyl(0.11, 0.11, 0.28, 12), Vector3(0.05, 0.47, 0), Color(0.15, 0.15, 0.16))
	B.mesh(pump, B.cyl(0.03, 0.03, 0.08, 6), Vector3(-0.2, 0.42, 0.12), Color(0.9, 0.75, 0.1))
	B.tube(pump, Vector3(0.0, 0.15, 0.2), Vector3(0.1, -0.3, 1.8), 0.035, Color(0.12, 0.3, 0.12))  # imuletku järveen
	_pump_sound = Sfx.loop_on(pump, "tractor_engine", -12.0)
	if _pump_sound != null:
		_pump_sound.stop()
		_pump_sound.pitch_scale = 1.9


## Täyttöletku pumpulta paljulle maaston myötäisesti (näkyy, kun palju täytetään).
func _build_hose() -> void:
	_hose = Node3D.new()
	_hose.visible = false
	add_child(_hose)
	var pts := [pump_local() + Vector3(0, 0, -0.2), Vector3(DOCK_LOCAL.x - 1.8, 0, 28.0), Vector3(1.6, 0, 23.5),
		Vector3(0.6, 0, 16.0), TUB_LOCAL + Vector3(0.4, 0, 0.8)]
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var segs := maxi(1, int(a.distance_to(b) / 1.5))
		for s in segs:
			var p0 := a.lerp(b, float(s) / segs)
			var p1 := a.lerp(b, float(s + 1) / segs)
			B.tube(_hose, Vector3(p0.x, h(p0.x, p0.z) + 0.04, p0.z), Vector3(p1.x, h(p1.x, p1.z) + 0.04, p1.z), 0.03, Color(0.12, 0.3, 0.12))
	var top := TUB_LOCAL + Vector3(0.4, 0, 0.8)
	var ty := h(top.x, top.z)
	B.tube(_hose, Vector3(top.x, ty + 0.04, top.z), Vector3(top.x - 0.1, h(TUB_LOCAL.x, TUB_LOCAL.z) + 0.95, top.z - 0.3), 0.03, Color(0.12, 0.3, 0.12))


func _smoke_fx(pos: Vector3) -> CPUParticles3D:
	var fx := CPUParticles3D.new()
	fx.position = pos
	fx.emitting = false
	fx.amount = 36
	fx.lifetime = 4.0
	fx.direction = Vector3(-0.3, 1, 0)
	fx.spread = 18.0
	fx.gravity = Vector3(0.2, 0.4, 0)
	fx.initial_velocity_min = 0.3
	fx.initial_velocity_max = 0.7
	fx.scale_amount_min = 1.0
	fx.scale_amount_max = 2.6
	var puff := SphereMesh.new()
	puff.radius = 0.26
	puff.height = 0.52
	puff.material = B.unshaded(Color(0.55, 0.55, 0.57, 0.3))
	fx.mesh = puff
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.8))
	fx.scale_amount_curve = grow
	return fx


# --- Savusaunan lämmitys ja palju ------------------------------------------------------

func _sauna_tick(delta: float) -> void:
	if sauna_fire_on:
		sauna_fuel -= delta
		sauna_heat = minf(1.0, sauna_heat + SAUNA_HEAT_RATE * delta)
		sauna_smoke = 1.0
		_sauna_fire.visible = true
		if sauna_heat >= 1.0 and not sauna_heated:
			sauna_heated = true
			sauna_fuel = minf(sauna_fuel, 4.0)  # pesä palaa loppuun
			sauna_event.emit("kuuma")
		if sauna_fuel <= 0.0:
			sauna_fire_on = false
			sauna_fuel = 0.0
			_sauna_fire.visible = false
			if not sauna_heated:
				sauna_event.emit("sammui")
	else:
		sauna_heat = maxf(0.0, sauna_heat - SAUNA_COOL * delta)
		if sauna_smoke > 0.0:
			sauna_smoke = maxf(0.0, sauna_smoke - delta / SAUNA_CLEAR)
			if sauna_smoke <= 0.0 and sauna_heated:
				sauna_event.emit("valmis")
	_sauna_smoke_fx.emitting = sauna_smoke > 0.08
	# Tuulettuessa savu ohenee (CPUParticles3D:llä ei ole amount_ratiota, joten koko pienenee).
	_sauna_smoke_fx.scale_amount_max = 1.0 + 1.6 * clampf(sauna_smoke, 0.0, 1.0)


## Paljun vesi ja lika näkyviin, pumppu täyttää.
func _palju_tick(delta: float) -> void:
	if pump_on:
		palju_level = minf(palju_level + delta / PALJU_FILL, 1.25)  # yli 1 = tulvii yli
	_palju_water.visible = palju_level > 0.03
	_palju_water.position.y = 0.1 + 0.76 * minf(palju_level, 1.0)
	_palju_dirt.visible = palju_dirt > 0.02 and palju_level < 0.5
	(_palju_dirt.material_override as StandardMaterial3D).albedo_color.a = clampf(palju_dirt * 1.2, 0.0, 1.0)


const PALJU_FILL := 30.0  # s tyhjästä täyteen pumpulla
const PALJU_DRAIN := 8.0  # s täydestä tyhjäksi


func set_pump(on: bool) -> void:
	pump_on = on
	_hose.visible = on or (palju_level < 0.95 and palju_dirt <= 0.02)
	if _pump_sound != null:
		if on:
			_pump_sound.play()
		else:
			_pump_sound.stop()


func set_hose(v: bool) -> void:
	_hose.visible = v


# --- Santtu tulee katsomaan ---------------------------------------------------------

## Santun kävely: kohde ja reitti (kulmapisteet mökin ja saunan ohi), katse ja kotiinpaluu kannolle.
var _santtu_path: Array = []
var _santtu_look := Vector3.ZERO
var _santtu_away := false
var _santtu_walking := false
const SANTTU_WALK := 1.6
## Esteet, joiden läpi Santtu ei kävele (paikallinen x/z): mökki kuisteineen, savusauna, palju, kesäkeittiö, huussi.
const SANTTU_BLOCKS := [Rect2(-5.6, -4.4, 12.6, 8.6), Rect2(1.7, 17.2, 6.2, 3.9), Rect2(-1.8, 13.7, 2.2, 2.2),
	Rect2(-14.8, 16.4, 4.0, 3.6), Rect2(-13.3, -2.8, 1.6, 1.6)]


## Santtu nousee kannolta ja kävelee paikan spot viereen (noin 1,8 m päähän) katsomaan kohti look.
func santtu_visit(spot: Vector3, look := Vector3.INF) -> void:
	if not built:
		return
	var from := Vector2(santtu.position.x, santtu.position.z)
	var to2 := Vector2(spot.x, spot.z)
	var d := to2 - from
	if d.length() > 1.8:
		to2 -= d.normalized() * 1.8
	_santtu_look = look if look != Vector3.INF else spot
	_santtu_path = _route(from, to2)
	_santtu_away = true
	_start_walk()


## Santtu suoraan paikalle (esim. metsästyslavan viereen, kun peli on omassa näkymässään).
func santtu_teleport(spot: Vector3, look: Vector3) -> void:
	if not built:
		return
	santtu.position = Vector3(spot.x, h(spot.x, spot.z), spot.z)
	santtu.rotation.y = B.yaw_to(look - spot)
	santtu.play("Idle", 0.2)
	_santtu_path.clear()
	_santtu_away = true
	_santtu_walking = false


func santtu_go_home() -> void:
	if not built or not _santtu_away:
		return
	_santtu_away = false
	_santtu_look = Vector3.INF
	_santtu_path = _route(Vector2(santtu.position.x, santtu.position.z), Vector2(SANTTU_LOCAL.x, SANTTU_LOCAL.z + 0.6))
	_santtu_path.append(Vector2(SANTTU_LOCAL.x, SANTTU_LOCAL.z))
	_start_walk()


## Onko Santtu poissa kannolta (kävelee tai katsoo jotain hommaa).
func santtu_out() -> bool:
	return _santtu_away or _santtu_walking


## Onko Santtu perillä katsomassa (ei kävele).
func santtu_arrived() -> bool:
	return _santtu_away and not _santtu_walking


func _start_walk() -> void:
	if _santtu_path.is_empty():
		return
	if not _santtu_walking:
		santtu.position.y = h(santtu.position.x, santtu.position.z)
		santtu.play("Walk", 0.2)
	_santtu_walking = true


func _santtu_tick(delta: float) -> void:
	if _santtu_walking:
		var target: Vector2 = _santtu_path[0]
		var p := Vector2(santtu.position.x, santtu.position.z)
		var d := target - p
		var step := SANTTU_WALK * delta
		if d.length() <= step:
			p = target
			_santtu_path.pop_front()
		else:
			p += d.normalized() * step
		if d.length() > 0.01:
			santtu.rotation.y = B.yaw_to(Vector3(d.x, 0, d.y))
		santtu.position = Vector3(p.x, h(p.x, p.y), p.y)
		if _santtu_path.is_empty():
			_santtu_walking = false
			if _santtu_away:
				santtu.rotation.y = B.yaw_to(_santtu_look - santtu.position)
				santtu.play("Idle", 0.3)
			else:
				santtu.position = SANTTU_LOCAL + Vector3(0, h(SANTTU_LOCAL.x, SANTTU_LOCAL.z) + 0.2, 0)
				santtu.rotation.y = B.yaw_to(Vector3(0, 0, -1))
				santtu.play("Sitting_Idle", 0.3)
	# Puhekupla ja nimi seuraavat Santtua (istuessa matalammalla).
	var sitting: bool = santtu.current().begins_with("Sitting")
	_bubble.position = santtu.position + Vector3(0, 1.4 if sitting else 2.05, 0)
	_name_label.position = santtu.position + Vector3(0, 1.1 if sitting else 1.85, 0)


## Kävely seis (minipeli ottaa Santun katsojaksi).
func santtu_stop() -> void:
	_santtu_path.clear()
	_santtu_walking = false


## Reitti kulmapisteiden kautta esteiden ohi (enintään kaksi kulmaa).
func _route(a: Vector2, b: Vector2, depth := 0) -> Array:
	var blk: Variant = _blocked(a, b)
	if blk == null or depth >= 2:
		return [b]
	var r: Rect2 = blk.grow(0.7)
	var best: Array = []
	var best_len := INF
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		if _blocked(a, c) != null:
			continue
		var rest := _route(c, b, depth + 1)
		var len: float = a.distance_to(c) + c.distance_to(rest[0])
		if len < best_len:
			best_len = len
			best = [c] + rest
	return best if not best.is_empty() else [b]


func _blocked(a: Vector2, b: Vector2) -> Variant:
	var n := maxi(1, int(a.distance_to(b) / 0.4))
	for r in SANTTU_BLOCKS:
		if r.has_point(a) or r.has_point(b):
			continue
		for i in range(1, n):
			if r.has_point(a.lerp(b, float(i) / n)):
				return r
	return null


# --- Katsojarajapinta kodan minipeleille (kota_minigame.gd): mökillä katsojana Santtu --------

func watcher_node(_who: String) -> Node3D:
	return santtu


func watcher_bubble(_who: String) -> Label3D:
	return _bubble


func watcher_say(_who: String, text: String, seconds: float) -> void:
	_bubble.text = "Santtu: " + text if text != "" else ""
	_bubble_t = seconds
