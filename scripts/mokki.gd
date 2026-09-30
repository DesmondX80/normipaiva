extends Node3D
## Mökki: Santtu-isännän vuokramökki Kaisuantie 62, Vaala (Neittävä), mallinnettu Airbnb-ilmoituksen kuvien ja
## drone-kuvan mukaan. Erillinen tasku maailman ulkopuolella, tavoitettavissa vain taksilla kotoa. Ympäristö
## 500 x 500 m oikean kartan mukaan (assets/mokki/kartta.json: OpenStreetMap ja EU-DEM 25 m): Likanen,
## Tervalampi, Kiiskeroinen, tiet, pellot, naapurirakennukset ja metsä. Pelilogiikka main.gd:ssä.
##
## Koordinaatit: paikallinen kehys on mökin kehys (mökin pitkä sivu X-akselilla, kuisti +Z eli järvelle päin).
## Karttadata on osoitepisteen kehyksessä (x itään, z etelään); mökki on kiertynyt siihen nähden YARD_ROT_DEG.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Terrain := preload("res://scripts/terrain.gd")

const DATA_PATH := "res://assets/mokki/kartta.json"
## Mökin kehys karttakehyksessä: paikallisen origon paikka (m osoitepisteestä) ja kierto (OSM:n mökin mukaan).
const YARD_C := Vector2(1.0, 2.35)
const YARD_ROT_DEG := 17.6
const AREA_HALF := 100.0  # alue 200 x 200 m osoitepisteen ympärillä

# Pihan asettelu: mökki OSM:n rakennuksen kohdalla, sauna, poreamme ja laituri drone-kuvasta.
# Rannan puolella kuistilta katsottuna vasemmalta oikealle (+X -> -X): savusauna, poreamme ja kesäkeittiö.
const TAXI_LOCAL := Vector3(-7.0, 0, -29.0)    # Kaisuantien varressa mökin takana
const SAUNA_LOCAL := Vector3(5.9, 0, 18.1)     # kiuas savusaunan sisällä
const TUB_LOCAL := Vector3(-0.7, 0, 14.8)      # puukuumenteinen poreamme
const DART_LOCAL := Vector3(4.2, 0, 8.0)       # heittopiste tikkataulun edessä (taulu männyssä)
const DOCK_LOCAL := Vector3(8.9, 0, 55.4)      # laiturin pää Likaisella
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

# Karttageometria (ks. minimap.gd ja paper_map.gd: mökin oma kartta korvaa kyläkartan täällä).
const YARD_CENTER := Vector2(-2.0, 10.0)
const YARD_R := Vector2(21.0, 19.0)
const GRID_STEP := 2.0   # maastoverkon ja törmäyksen ruutu (korkeusmallin tarkkuus)
const COTTAGE_LOCAL := Vector2(0.0, -1.0)
## OSM-rakennukset, jotka mallinnetaan käsin (mökki) tai jätetään tyhjäksi tontiksi (käyttämätön vaja purettu).
const OWN_BUILDINGS := ["1074462394", "1555232405"]
const COTTAGE_SIZE := Vector2(9.4, 5.0)

const SAUNA_HEAT := 20.0    # s ennen kuin kiuas on kuuma
const SAUNA_BURN := 260.0   # s sytytyksestä sammumiseen
const TUB_HEAT := 30.0
const TUB_BURN := 320.0

## Santun jutut: poimittu suoraan hänen omasta Airbnb-ilmoituksestaan (Neittävä, Pohjois-Pohjanmaa).
const SANTTU_LINES := [
	"Oon täällä Superhost, viides vuosi menossa!",
	"Ilmoitus on ihan uus – ei oo vielä yhtään arvostelua.",
	"Muilla mökeillä on jo 106 arvostelua, keskiarvo 4.86. Kyllä tää vielä nousee.",
	"Parkkipaikka on ilmainen, harvinaista täällä päin.",
	"Suodatinkahvia on aina tarjolla. Se on listan kohokohtia, usko tai älä.",
	"Savusauna ja puukuumenteinen poreamme – kokeile molempia, ennen ku lähet.",
	"Pihalla on ulkokeittiö ja savustin. Kokkaa jotain, jos on aikaa.",
	"Lähin kauppa on Vaalassa, viistoista kilsaa. Täällä on rauhallista.",
	"Synnyin 80-luvulla, opiskelin Oulun yliopistossa. Sitä ei tästä äkkiä arvais.",
	"Vastausprosentti sata, vastaan yleensä tunnissa. Paitsi kun oon saunassa.",
]
const SANTTU_AMBIENT := [
	"Löylyä riittää, älä säästele.", "Poreamme lämpiää hitaasti, mutta kunnolla.",
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

var sauna_fire_on := false
var sauna_fire_time := 0.0
var tub_fire_on := false
var tub_fire_time := 0.0

var santtu: Node3D
var _bubble: Label3D
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
	_build_pingis_spot()
	_build_trees()
	_build_santtu()
	# Kaikki pihan rakennukset ja esineet maanpinnalle (maasto ja vesi ovat jo oikealla korkeudella).
	for c in get_children():
		if c is Node3D and not c.has_meta("ground"):
			c.position.y += h(c.position.x, c.position.z)


func sauna_ready() -> bool:
	return sauna_fire_on and sauna_fire_time <= SAUNA_BURN - SAUNA_HEAT


func tub_ready() -> bool:
	return tub_fire_on and tub_fire_time <= TUB_BURN - TUB_HEAT


func set_sauna_fire(on: bool) -> void:
	sauna_fire_on = on
	if on:
		sauna_fire_time = SAUNA_BURN
	elif _sauna_fire != null:
		_sauna_fire.visible = false


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


func say(text: String, seconds := 3.2) -> void:
	if not built:
		return
	_bubble.text = text
	_bubble_t = seconds


func _process(delta: float) -> void:
	if not built:
		return
	_t += delta
	if sauna_fire_on:
		sauna_fire_time -= delta
		if sauna_fire_time <= 0.0:
			set_sauna_fire(false)
		else:
			_sauna_fire.visible = true
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
	var out := {"water": [], "water_names": [], "fields": [], "roads": [], "buildings": [], "streams": [], "dem": d.dem}
	var keep := Rect2(-Vector2.ONE * (AREA_HALF + 40.0), Vector2.ONE * (AREA_HALF + 40.0) * 2.0)
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
		match f.kind:
			"water":
				out.water.append(pts)
				out.water_names.append(f.name)
			"field":
				out.fields.append(pts)
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
	for poly in map_data().water:
		if Geometry2D.is_point_in_polygon(Vector2(x, z), poly):
			return true
	return false


## Onko paikallinen piste 200 x 200 m alueella (reunan sisäpuolella margin m).
static func in_area(x: float, z: float, margin := 0.0) -> bool:
	var m := to_map2(Vector2(x, z))
	return absf(m.x) < AREA_HALF - margin and absf(m.y) < AREA_HALF - margin


## Korkeusmallin arvo (m merenpinnasta) paikallisessa pisteessä, bilineaarisesti.
static func _dem(x: float, z: float) -> float:
	var dem: Dictionary = map_data().dem
	var m := to_map2(Vector2(x, z))
	var n: int = dem.n
	var fx := clampf((m.x - dem.x0) / dem.step, 0.0, n - 1.001)
	var fz := clampf((m.y - dem.z0) / dem.step, 0.0, n - 1.001)
	var i := int(fx)
	var j := int(fz)
	var vals: Array = dem.values
	var a: float = lerpf(vals[j * n + i], vals[j * n + i + 1], fx - i)
	var b: float = lerpf(vals[(j + 1) * n + i], vals[(j + 1) * n + i + 1], fx - i)
	return lerpf(a, b, fz - j)


## Mökin paikallinen maanpinnan korkeus (mökki = 0). Vesistöissä pohja on pinnan alla, rannalla maa pysyy
## hieman pinnan yläpuolella.
static func h(x: float, z: float) -> float:
	var water := water_y()
	if in_water(x, z):
		return water - 1.0
	return maxf(_dem(x, z) - _base(), water + 0.12)


static func _base() -> float:
	return _dem(COTTAGE_LOCAL.x, COTTAGE_LOCAL.y)


## Järvien pinnan korkeus mökin tasoon nähden (Likanen 125,3 m N2000).
static func water_y() -> float:
	return float(map_data().dem.water) - _base()


## Paikallinen piste maanpinnalle (y = h + local.y) maailmakoordinaatteina.
func gpos(local: Vector3) -> Vector3:
	return to_global(Vector3(local.x, h(local.x, local.z) + local.y, local.z))


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
	for bd in map_data().buildings:
		var poly: PackedVector2Array = bd.poly
		if poly.size() > 0 and p.distance_to(poly[0]) < 16.0:
			return true
	return false


## Maasto 2 m verkkona korkeusmallin mukaan: metsä, pihat, pellot ja järvien pohjat omilla materiaaleillaan,
## törmäys samasta ruudukosta (HeightMapShape3D kuten world.gd:ssä).
func _build_ground() -> void:
	var data := map_data()
	var mats := {
		"forest": _ground_mat(Color(0.28, 0.32, 0.17), Color(0.5, 0.48, 0.32), 0.03, 0.6),
		"yard": _ground_mat(Color(0.36, 0.3, 0.2), Color(0.55, 0.47, 0.32), 0.04, 0.9),
		"field": _ground_mat(Color(0.45, 0.5, 0.25), Color(0.6, 0.62, 0.32), 0.02, 0.4),
		"shore": _ground_mat(Color(0.3, 0.3, 0.22), Color(0.42, 0.4, 0.3), 0.05, 0.8),
	}
	var half := AREA_HALF * 1.45  # kierretty neliö mahtuu
	var lo := Vector2(-half, -half)
	var n := int(half * 2.0 / GRID_STEP) + 1
	var sts := {}
	for k in mats:
		sts[k] = SurfaceTool.new()
		sts[k].begin(Mesh.PRIMITIVE_TRIANGLES)
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			var p := lo + Vector2(i, j) * GRID_STEP
			hs[j * n + i] = h(p.x, p.y)
	for j in n - 1:
		for i in n - 1:
			var c := lo + (Vector2(i, j) + Vector2(0.5, 0.5)) * GRID_STEP
			if not in_area(c.x, c.y, -40.0):
				continue  # alueen ulkopuolelle vain kapea metsäreunus
			var kind := "forest"
			if in_water(c.x, c.y):
				kind = "shore"
			else:
				for f in data.fields:
					if Geometry2D.is_point_in_polygon(c, f):
						kind = "field"
						break
				if kind == "forest" and _is_yard(c):
					kind = "yard"
			var st: SurfaceTool = sts[kind]
			var v := func(di: int, dj: int) -> Vector3:
				var q := lo + Vector2(i + di, j + dj) * GRID_STEP
				return Vector3(q.x, hs[(j + dj) * n + i + di], q.y)
			for corner in [v.call(0, 0), v.call(1, 0), v.call(1, 1), v.call(0, 0), v.call(1, 1), v.call(0, 1)]:
				st.add_vertex(corner)
	for k in sts:
		var st: SurfaceTool = sts[k]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mats[k]
		mi.set_meta("ground", true)
		add_child(mi)
	var ground_body := StaticBody3D.new()
	ground_body.collision_layer = Terrain.COLLISION_LAYER
	ground_body.collision_mask = 0
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	hm.map_data = hs
	var cs := CollisionShape3D.new()
	cs.shape = hm
	cs.scale = Vector3(GRID_STEP, 1.0, GRID_STEP)
	ground_body.position = Vector3(lo.x + (n - 1) * GRID_STEP * 0.5, 0.0, lo.y + (n - 1) * GRID_STEP * 0.5)
	ground_body.add_child(cs)
	ground_body.set_meta("ground", true)
	add_child(ground_body)
	# Alueen reunat: näkymättömät seinät 200 m neliön laidoilla.
	var area: PackedVector2Array = data.area
	for k in 4:
		var a := area[k]
		var b := area[(k + 1) % 4]
		var wall := StaticBody3D.new()
		var mid := (a + b) / 2.0
		wall.position = Vector3(mid.x, 0, mid.y)
		wall.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		wall.add_child(B.box_shape(Vector3(a.distance_to(b), 30.0, 1.0), Vector3(0, 5.0, 0)))
		wall.set_meta("ground", true)
		add_child(wall)


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
	var wy := water_y()
	for poly: PackedVector2Array in data.water:
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
	for r in data.roads:
		var w := 2.6 if r.type == "unclassified" else (1.4 if r.type == "service" else 1.8)
		_strip(r.pts, w, 0.05, gravel)
	Sfx.loop_on(self, "water", -14.0).position = Vector3(DOCK_LOCAL.x, 0, DOCK_LOCAL.z - 4.0)


## Naapurit OSM-rakennuksina: seinät, harjakatto ja törmäys (oma mökki ja vaja mallinnetaan erikseen).
func _build_neighbors() -> void:
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
		var body := StaticBody3D.new()
		body.position = Vector3(cen.x, h(cen.x, cen.y), cen.y)
		body.rotation.y = -ang
		body.set_meta("ground", true)
		add_child(body)
		var col: Color = walls[hash(bd.id) % walls.size()]
		B.mesh(body, B.boxm(Vector3(size.x, wall_h, size.y)), Vector3(0, wall_h / 2.0 - 0.2, 0), col)
		var roof := PrismMesh.new()
		roof.size = Vector3(size.y + 0.8, 1.0 if small else 1.6, size.x + 0.6)
		B.mesh(body, roof, Vector3(0, wall_h - 0.2 + roof.size.y / 2.0, 0), Color(0.22, 0.22, 0.24), Vector3(0, 90, 0))
		body.add_child(B.box_shape(Vector3(size.x, wall_h, size.y), Vector3(0, wall_h / 2.0, 0)))


## Metsä: männyt MultiMeshinä koko alueelle (ei vesiin, pelloille, teille eikä pihoille); törmäys lähimmille.
func _build_forest() -> void:
	var data := map_data()
	var pine := _pine_mesh()
	var xforms: Array[Transform3D] = []
	var bodies := StaticBody3D.new()
	bodies.set_meta("ground", true)
	add_child(bodies)
	var rng := RandomNumberGenerator.new()
	rng.seed = 62
	var step := 7.0
	var z := -AREA_HALF * 1.45
	while z < AREA_HALF * 1.45:
		var x := -AREA_HALF * 1.45
		while x < AREA_HALF * 1.45:
			var p := Vector2(x, z) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			x += step
			if not in_area(p.x, p.y, -30.0) or in_water(p.x, p.y) or _is_yard(p):
				continue
			# Ranta-alue laiturille johtavalta polulta: puu ei saa tukkia kulkua laiturille.
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, DOCK_PATH_A, DOCK_PATH_B)) < 3.0:
				continue
			# Metsästysaukea ja näkölinja lavalta sinne.
			var lava := Vector2(HUNT_LOCAL.x, HUNT_LOCAL.z)
			if p.distance_to(HUNT_GLADE) < HUNT_GLADE_R \
					or p.distance_to(Geometry2D.get_closest_point_to_segment(p, lava + Vector2(-2.0, 0), HUNT_GLADE)) < 6.0:
				continue
			var skip := false
			for f in data.fields:
				if Geometry2D.is_point_in_polygon(p, f):
					skip = true
					break
			if not skip:
				for r in data.roads:
					if not r.bbox.has_point(p):
						continue
					var pts: PackedVector2Array = r.pts
					for k in pts.size() - 1:
						if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])) < 4.0:
							skip = true
							break
					if skip:
						break
			if skip:
				continue
			var s := rng.randf_range(0.8, 1.4)
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, h(p.x, p.y), p.y)))
			if p.length() < 110.0:
				var cs := B.capsule_shape(0.25 * s, 5.6 * s)
				cs.position = Vector3(p.x, h(p.x, p.y), p.y)
				bodies.add_child(cs)
		z += step
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pine
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.set_meta("ground", true)
	add_child(mmi)


## Mänty yhtenä meshinä (runko + neljä latvakartiota), jotta metsä piirtyy MultiMeshinä.
func _pine_mesh() -> ArrayMesh:
	var am := ArrayMesh.new()
	var parts := [[B.cyl(0.12, 0.22, 3.5, 7), Vector3(0, 1.75, 0), Color(0.35, 0.25, 0.16)]]
	for k in 4:
		var fh := 1.6 * (1.0 - k * 0.12)
		parts.append([B.cyl(0.03, fh * 0.62, fh, 7), Vector3(0, 2.8 + k * 1.12, 0), Color(0.15, 0.26, 0.14).lightened(0.04 * k)])
	for part in parts:
		var st := SurfaceTool.new()
		st.append_from(part[0], 0, Transform3D(Basis(), part[1]))
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, B.mat(part[2]))
	return am


func _build_lake_and_dock() -> void:
	_build_waters_and_roads()
	# Laituri: pukit ja lankut rannasta Likaiselle (+Z).
	var dock := StaticBody3D.new()
	dock.position = DOCK_LOCAL + Vector3(0, 0, -11.6)
	add_child(dock)
	var wood := Color(0.5, 0.38, 0.24)
	for i in 12:
		var z := i * 1.05
		for sx in [-0.65, 0.65]:
			B.mesh(dock, B.cyl(0.05, 0.06, 0.75, 8), Vector3(sx, -0.15, z), Color(0.35, 0.26, 0.16))
	B.mesh(dock, B.boxm(Vector3(1.5, 0.06, 12.8)), Vector3(0, 0.22, 6.0), wood)
	for i in 24:
		B.mesh(dock, B.boxm(Vector3(1.46, 0.02, 0.42)), Vector3(0, 0.26, i * 0.55), wood.lightened(0.05 * (i % 2)))
	dock.add_child(B.box_shape(Vector3(1.5, 0.3, 13.0), Vector3(0, 0.2, 6.0)))
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
			dock.add_child(B.box_shape(Vector3(1.3, stair_h + 0.02, 0.36), Vector3(0, sy, sz)))
	# Onkivapa nojaa laiturin päässä (ks. Mokki.DOCK_LOCAL, kalastus main.gd:ssä).
	var rod := Node3D.new()
	rod.position = Vector3(0.55, 0.3, 11.6)
	rod.rotation = Vector3(0, 0.3, -0.35)
	dock.add_child(rod)
	B.mesh(rod, B.cyl(0.012, 0.02, 2.4, 6), Vector3(0, 1.2, 0), Color(0.15, 0.15, 0.16))
	B.mesh(rod, B.sphere(0.03, 6), Vector3(0, 2.35, 0.05), Color(0.85, 0.15, 0.1))
	B.mesh(dock, B.boxm(Vector3(0.3, 0.16, 0.2)), Vector3(-0.5, 0.32, 11.4), Color(0.32, 0.28, 0.24))  # varustelaatikko


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
	# Sokkeli: tummat pystylaudat ja vaaleat betoniharkot vuorotellen.
	for i in 10:
		var x := -l / 2.0 + 0.5 + i * (l - 1.0) / 9.0
		B.mesh(body, B.boxm(Vector3((l - 1.0) / 9.0 - 0.03, found_h, 0.5)), Vector3(x, found_h / 2.0, -d / 2.0 - 0.05),
			conc if i % 3 == 1 else dark_wood)
	# Pohja on suorakaide, jonka takanurkasta (länsi, tien puoli) puuttuu lovi: ulko-ovi on loven sisänurkassa.
	var notch := Vector2(1.1, 1.3)
	var full_h := wall_h + rise + found_h
	for part in [[Vector3(notch.x / 2.0, 0, 0), Vector3(l - notch.x, 0, d)],
			[Vector3(-l / 2.0 + notch.x / 2.0, 0, -notch.y / 2.0), Vector3(notch.x, 0, d - notch.y)]]:
		var pc: Vector3 = part[0]
		var ps: Vector3 = part[1]
		body.add_child(B.box_shape(Vector3(ps.x, full_h, ps.z), Vector3(pc.x, full_h / 2.0 - found_h, pc.z)))
		# Tummanruskeat pystypaneeliseinät.
		B.mesh(body, B.boxm(Vector3(ps.x, wall_h, ps.z)), Vector3(pc.x, found_h + wall_h / 2.0, pc.z), wall_col)
	for i in 9:
		var x := -l / 2.0 + 0.2 + i * l / 8.0
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
	# Savupiippu (musta, korkilla).
	B.mesh(body, B.boxm(Vector3(0.5, 1.1, 0.5)), Vector3(l / 2.0 - 2.2, found_h + wall_h + rise + 0.35, 0.4), Color(0.08, 0.08, 0.09))
	B.mesh(body, B.boxm(Vector3(0.64, 0.08, 0.64)), Vector3(l / 2.0 - 2.2, found_h + wall_h + rise + 0.94, 0.4), Color(0.15, 0.15, 0.16))
	# Ikkunat ja ovi julkisivussa (-Z, kuistin puolella).
	var glass := Color(0.1, 0.14, 0.2)
	for wx in [-3.4, -0.6, 2.0, 3.7]:
		B.mesh(body, B.boxm(Vector3(1.0, 1.15, 0.05)), Vector3(wx, found_h + 1.35, -d / 2.0 - 0.02), white)
		B.mesh(body, B.boxm(Vector3(0.85, 0.98, 0.06)), Vector3(wx, found_h + 1.35, -d / 2.0 - 0.03), glass)
	# Ulko-ovi loven sisänurkassa (tien puolella, sisäkuvien mukaan tuvan vasen takanurkka): lasiovi,
	# eteen pieni porrastasanne ja luiska maahan.
	var door := Node3D.new()
	door.position = Vector3(-l / 2.0 + notch.x / 2.0, found_h, d / 2.0 - notch.y + 0.02)
	body.add_child(door)
	B.mesh(door, B.boxm(Vector3(0.95, 2.05, 0.06)), Vector3(0, 1.02, 0), white)
	B.mesh(door, B.boxm(Vector3(0.75, 1.8, 0.07)), Vector3(0, 1.05, 0), glass)
	B.mesh(door, B.boxm(Vector3(0.1, 0.1, 0.08)), Vector3(0.36, 1.0, 0.03), Color(0.75, 0.72, 0.6))
	# Maan korkeus rungon koordinaateissa mökin lattiatasoon nähden (rinne).
	var g := func(bx: float, bz: float) -> float:
		return h(-bx, -bz - 1.0) - h(0.0, -1.0)
	var sx := -l / 2.0 + notch.x / 2.0
	var stoop_d := notch.y + 0.3  # loven täyttävä tasanne, hieman ulos seinälinjasta
	var stoop_end := d / 2.0 - notch.y + stoop_d
	var stoop_z := stoop_end - stoop_d / 2.0
	var stoop_low := minf(minf(g.call(sx, d / 2.0 - notch.y), g.call(sx, stoop_end)), 0.0) - 0.1
	B.mesh(body, B.boxm(Vector3(notch.x, 0.1, stoop_d)), Vector3(sx, found_h - 0.02, stoop_z), Color(0.62, 0.5, 0.36))
	B.mesh(body, B.boxm(Vector3(notch.x - 0.1, found_h - 0.07 - stoop_low, stoop_d - 0.1)), Vector3(sx, (found_h - 0.07 + stoop_low) / 2.0, stoop_z), dark_wood)
	body.add_child(B.box_shape(Vector3(notch.x, found_h + 0.03 - stoop_low, stoop_d), Vector3(sx, (found_h + 0.03 + stoop_low) / 2.0, stoop_z)))
	var back_foot := minf(g.call(sx, stoop_end + 0.8), found_h - 0.1)
	var back_rise := found_h - back_foot + 0.4
	var back_run := maxf(1.2, back_rise * 1.6)
	var back_steps := maxi(1, ceili((found_h - back_foot) / 0.21))
	for i in back_steps:
		var sh := (found_h - back_foot) / back_steps
		B.mesh(body, B.boxm(Vector3(notch.x - 0.1, sh, 0.3)), Vector3(sx, found_h - (i + 0.5) * sh, stoop_end + 0.15 + i * 0.3), Color(0.5, 0.4, 0.28))
	var back_ramp := B.box_shape(Vector3(notch.x - 0.1, 0.1, Vector2(back_run, back_rise).length()), Vector3.ZERO)
	back_ramp.transform = Transform3D(Basis(Vector3.RIGHT, atan2(back_rise, back_run)),
		Vector3(sx, found_h - back_rise / 2.0 - 0.05, stoop_end + back_run / 2.0))
	body.add_child(back_ramp)
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
	for x2 in [-l / 2.0 + 0.3, -l / 2.0 + 1.9, -l / 2.0 + 3.5, -l / 2.0 + 5.1, -l / 2.0 + 6.7, l / 2.0 - 0.3]:
		B.mesh(body, B.boxm(Vector3(0.1, 0.06, 0.1)), Vector3(x2, found_h + 0.86, deck_z - porch_d / 2.0 + 0.3), white)
	B.mesh(body, B.boxm(Vector3(l - 0.2, 0.06, 0.06)), Vector3(0, found_h + 0.86, deck_z - porch_d + 0.02), white)
	for i in 26:
		B.mesh(body, B.boxm(Vector3(0.03, 0.7, 0.03)), Vector3(-l / 2.0 + 0.3 + i * (l - 0.6) / 25.0, found_h + 0.5, deck_z - porch_d + 0.02), white)
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
	# Luiska alkaa maan tason alta (-0,4), jotta rinteessä sen alapää ei jää askelmaksi.
	var ramp_rise := found_h - foot + 0.4
	var run := maxf(2.0, ramp_rise * 1.6)
	var ramp := B.box_shape(Vector3(Vector2(run, ramp_rise).length(), 0.1, 1.1), Vector3.ZERO)
	ramp.transform = Transform3D(Basis(Vector3.BACK, atan2(ramp_rise, run)),
		Vector3(-l / 2.0 - run / 2.0, found_h - ramp_rise / 2.0 - 0.05, deck_z + 0.5))
	body.add_child(ramp)
	# Kuistin sohva, tuolit ja pöytä (kuten kuvissa).
	body.add_child(B.box_shape(Vector3(1.7, 0.6, 0.9), Vector3(1.5, found_h + 0.3, deck_z + 0.5)))
	body.add_child(B.box_shape(Vector3(0.6, 0.45, 0.6), Vector3(3.6, found_h + 0.22, deck_z + 0.6)))
	B.mesh(body, B.boxm(Vector3(1.7, 0.55, 0.75)), Vector3(1.5, found_h + 0.3, deck_z + 0.55), Color(0.32, 0.26, 0.22))
	B.mesh(body, B.boxm(Vector3(1.7, 0.5, 0.16)), Vector3(1.5, found_h + 0.62, deck_z + 0.2), Color(0.36, 0.3, 0.26))
	B.mesh(body, B.cyl(0.28, 0.3, 0.05, 16), Vector3(3.6, found_h + 0.42, deck_z + 0.6), Color(0.55, 0.42, 0.28))
	# Nimikyltti kuistilla.
	var plate := B.sign_plate(body, "MÖKKI PAAPELI", Color(0.36, 0.2, 0.1), Color(0.98, 0.95, 0.86), 0.2, 34,
		Color(0.3, 0.18, 0.1), "Helvetica Neue")
	plate.position = Vector3(0, found_h + wall_h - 0.15, -d / 2.0 - 0.06)
	plate.rotation.y = PI


# --- Kesäkeittiö: avoin katos offset-savustimineen -------------------------------------

## Kuvien mukaan rannan puolella poreammeen oikealla (kuistilta katsottuna): avoin puukatos, jonka alla
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
	sauna.position = SAUNA_LOCAL + Vector3(0, 0, 1.0)  # akselinsuuntainen: ei kiertoa, ovi ja terassi -X:ssä poreammeelle päin
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


# --- Puukuumenteinen poreamme -----------------------------------------------------

func _build_hottub() -> void:
	var tub := StaticBody3D.new()
	tub.position = TUB_LOCAL
	add_child(tub)
	tub.add_child(B.capsule_shape(0.95, 0.9))
	B.mesh(tub, B.cyl(0.95, 0.98, 0.85, 20), Vector3(0, 0.42, 0), Color(0.08, 0.08, 0.09))
	B.mesh(tub, B.cyl(0.86, 0.86, 0.05, 20), Vector3(0, 0.86, 0), Color(0.15, 0.35, 0.42, 0.85))
	for k in 3:
		B.mesh(tub, B.cyl(0.99, 0.99, 0.04, 20), Vector3(0, 0.2 + k * 0.28, 0), Color(0.5, 0.45, 0.4))
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
	tree.position = DART_LOCAL + Vector3(0, 0, 3.0)
	add_child(tree)
	B.mesh(tree, B.cyl(0.22, 0.3, 6.0, 10), Vector3(0, 3.0, 0), Color(0.4, 0.26, 0.16))
	for k in 3:
		B.mesh(tree, B.cyl(0.02, 1.3 - k * 0.3, 1.8, 8), Vector3(0, 4.6 + k * 1.1, 0), Color(0.16, 0.28, 0.14))
	var board := Node3D.new()
	board.position = Vector3(0, 1.5, -0.32)
	board.rotation_degrees = Vector3(-90, 0, 0)  # kiekot pystyyn, "etukuva" osoittaa -Z:aan (heittopisteelle)
	tree.add_child(board)
	B.mesh(board, B.cyl(0.24, 0.24, 0.06, 20), Vector3.ZERO, Color(0.55, 0.4, 0.25))
	for i in 4:
		var ring: float = [0.2, 0.14, 0.08, 0.03][i]
		B.mesh(board, B.cyl(ring, ring, 0.065 + i * 0.002, 20), Vector3.ZERO, Color(0.85, 0.15, 0.1) if i % 2 == 0 else Color(0.92, 0.9, 0.85))
	tree.add_child(B.capsule_shape(0.3, 6.0))
	# Penkit ja nuotiopaikka poreammeen edessä (kuten kuistilta otetussa kuvassa).
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
## Mökin ulko-ovi takanurkan lovessa tien puolella (paikallinen, ovella tasanteella): E vie sisään (main.gd _mokki_logic).
## PORCH_DIR = ovelta ulospäin.
const DOOR_LOCAL := Vector3(4.15, 0, -2.5)
const PORCH_DIR := Vector3(0, 0, -1)


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
	var name := B.label(self, "Santtu, isäntä", SANTTU_LOCAL + Vector3(0, 1.3, 0), 12, Color(1, 0.9, 0.6), true)
	name.no_depth_test = false
