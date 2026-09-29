extends Node3D
## Mökki: Santtu-isännän oma vuokramökki (mallinnettu Airbnb-ilmoituksen "The warmth of a smoke
## sauna and cottage life" kuvien mukaan). Erillinen tasku maailman ulkopuolella, tavoitettavissa
## vain taksilla kotoa (ks. main.gd _taxi_logic). Paikallinen -Z = pihatie/taksipysäkki,
## +Z = ranta ja laituri. Pelilogiikka (kiuas, poreallas, tikka, laituri) main.gd:ssä.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Terrain := preload("res://scripts/terrain.gd")

const TAXI_LOCAL := Vector3(0, 0, -15.5)
const SAUNA_LOCAL := Vector3(7.4, 0, 5.4)   # kiuas savusaunan sisällä
const TUB_LOCAL := Vector3(10.6, 0, 7.7)    # puukuumenteinen poreamme
const DART_LOCAL := Vector3(9.0, 0, 2.0)    # heittopiste tikkataulun edessä (suoraan etelään puusta)
const DOCK_LOCAL := Vector3(7.2, 0, 27.5)   # laiturin pää
const SANTTU_LOCAL := Vector3(-1.5, 0, -7.0)  # pihatuolilla, kuistin eteläpuolella

# Karttageometria (ks. minimap.gd ja paper_map.gd: mökin oma lähikartta korvaa kyläkartan täällä).
const YARD_CENTER := Vector2(2.0, 5.0)
const YARD_R := Vector2(24.0, 22.0)
const FOREST_R := Vector2(55.0, 55.0)
const LAKE_CENTER := Vector2(8.0, 34.0)
const LAKE_R := Vector2(22.0, 16.0)
const COTTAGE_LOCAL := Vector2(0.0, -1.0)
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
	"Meitä on täällä kaksi aikuista ja kolme kakaraa: 21, 16 ja 11.",
	"Vastausprosentti sata, vastaan yleensä tunnissa. Paitsi kun oon saunassa.",
	"Taksikuski on serkkuni. Älä kerro kenellekään mitä se laskutti.",
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
	{"name": "särjen", "kg": 0.25}, {"name": "ahvenen", "kg": 0.35}, {"name": "lahnan", "kg": 0.9},
	{"name": "hauen", "kg": 1.6}, {"name": "mateen", "kg": 0.8},
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


func _ready() -> void:
	_build_ground()
	_build_lake_and_dock()
	_build_cottage()
	_build_woodshed()
	_build_savusauna()
	_build_hottub()
	_build_yard_extras()
	_build_trees()
	_build_santtu()


func sauna_ready() -> bool:
	return sauna_fire_on and sauna_fire_time <= SAUNA_BURN - SAUNA_HEAT


func tub_ready() -> bool:
	return tub_fire_on and tub_fire_time <= TUB_BURN - TUB_HEAT


func set_sauna_fire(on: bool) -> void:
	sauna_fire_on = on
	if on:
		sauna_fire_time = SAUNA_BURN
	else:
		_sauna_fire.visible = false


func set_tub_fire(on: bool) -> void:
	tub_fire_on = on
	if on:
		tub_fire_time = TUB_BURN
	else:
		_tub_fire.visible = false


func say(text: String, seconds := 3.2) -> void:
	_bubble.text = text
	_bubble_t = seconds


func _process(delta: float) -> void:
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
	for f in [_sauna_fire, _tub_fire]:
		if f.visible:
			for k in 4:
				var fl: Node3D = f.get_node("Flame%d" % k)
				fl.scale = Vector3(1.0, 0.8 + 0.35 * absf(sin(_t * (5.0 + k) + k)), 1.0)
			(f.get_node("Glow") as OmniLight3D).light_energy = 2.0 + 0.6 * sin(_t * 13.0) * sin(_t * 7.1)
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.text = ""


# --- Maasto, järvi ja laituri ------------------------------------------------------

func _disc(center: Vector2, rx: float, rz: float, material: Material, y := 0.0, segs := 40) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := center + Vector2(cos(a0) * rx, sin(a0) * rz)
		var p1 := center + Vector2(cos(a1) * rx, sin(a1) * rz)
		st.add_vertex(Vector3(center.x, y, center.y))
		st.add_vertex(Vector3(p0.x, y, p0.y))
		st.add_vertex(Vector3(p1.x, y, p1.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	add_child(mi)


func _build_ground() -> void:
	var forest_mat := B.shader_mat("res://shaders/ground.gdshader", {
		"color_a": Color(0.28, 0.32, 0.17), "color_b": Color(0.5, 0.48, 0.32),
		"scale": 0.03, "fine_scale": 0.6, "bump": 0.7, "roughness_v": 0.95, "stripes": 0.0,
	})
	var yard_mat := B.shader_mat("res://shaders/ground.gdshader", {
		"color_a": Color(0.36, 0.3, 0.2), "color_b": Color(0.55, 0.47, 0.32),
		"scale": 0.04, "fine_scale": 0.9, "bump": 0.9, "roughness_v": 1.0, "stripes": 0.0,
	})
	_disc(YARD_CENTER, FOREST_R.x, FOREST_R.y, forest_mat, -0.03)
	_disc(YARD_CENTER, YARD_R.x, YARD_R.y, yard_mat, -0.02)
	# Maastolevyt (_disc) ovat pelkkää visuaalia. Tasku on kaukana pääkartan korkeusmallista,
	# joten Terrain.h() palauttaa täällä aina 0 eikä world.gd:n maaston HeightMapShape3D ulotu
	# tänne: ilman omaa törmäystasoa pelaaja putoaa suoraan maan läpi saapuessaan taksilla.
	var ground_body := StaticBody3D.new()
	ground_body.collision_layer = Terrain.COLLISION_LAYER
	ground_body.collision_mask = 0
	ground_body.add_child(B.box_shape(Vector3(FOREST_R.x * 2.0 + 10.0, 1.0, FOREST_R.y * 2.0 + 10.0),
		Vector3(YARD_CENTER.x, -0.5, YARD_CENTER.y)))
	add_child(ground_body)


func _build_lake_and_dock() -> void:
	# Vesi piirretään maan yläpuolelle, jotta se ei jää nurmi-/metsälevyjen alle niiden mahdollisen
	# päällekkäisyyden kohdalla (litteät levyt, ei todellista maastoa tässä taskussa).
	var water_mat := B.shader_mat("res://shaders/water.gdshader")
	_disc(LAKE_CENTER, LAKE_R.x, LAKE_R.y, water_mat, 0.0, 48)
	Sfx.loop_on(self, "water", -14.0).position = Vector3(8.0, 0, 30.0)
	# Ruovikko rantaviivalla.
	for i in 26:
		var a := randf() * TAU
		var r := 15.0 + randf() * 4.0
		var p := Vector2(8.0, 19.5) + Vector2(cos(a), sin(a) * 0.6) * r
		if p.y < 15.0:
			continue
		var reed := B.mesh(self, B.cyl(0.0, 0.02, 0.9 + randf() * 0.5, 5), Vector3(p.x, 0, p.y),
			Color(0.42, 0.5, 0.22).lightened(randf() * 0.15))
		reed.rotation.x = (randf() - 0.5) * 0.15
	# Laituri: pukit ja lankut rannasta veteen.
	var dock := StaticBody3D.new()
	dock.position = Vector3(6.4, 0, 15.5)
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
	var cream := Color(0.85, 0.83, 0.74)
	var dark_wood := Color(0.22, 0.18, 0.14)
	var conc := Color(0.62, 0.62, 0.6)
	var white := Color(0.94, 0.94, 0.9)
	var roof_col := Color(0.5, 0.51, 0.53)
	var deck_z := -d / 2.0 - porch_d / 2.0
	var body := StaticBody3D.new()
	body.position = Vector3(0, 0, -1.0)
	add_child(body)
	# Sokkeli: tummat pystylaudat ja vaaleat betoniharkot vuorotellen.
	for i in 10:
		var x := -l / 2.0 + 0.5 + i * (l - 1.0) / 9.0
		B.mesh(body, B.boxm(Vector3((l - 1.0) / 9.0 - 0.03, found_h, 0.5)), Vector3(x, found_h / 2.0, -d / 2.0 - 0.05),
			conc if i % 3 == 1 else dark_wood)
	body.add_child(B.box_shape(Vector3(l, wall_h + rise + found_h, d), Vector3(0, (wall_h + rise + found_h) / 2.0 - found_h, 0)))
	# Vaaleat pystypaneeliseinät.
	B.mesh(body, B.boxm(Vector3(l, wall_h, d)), Vector3(0, found_h + wall_h / 2.0, 0), cream)
	for i in 9:
		var x := -l / 2.0 + 0.2 + i * l / 8.0
		B.mesh(body, B.boxm(Vector3(0.03, wall_h, 0.01)), Vector3(x, found_h + wall_h / 2.0, -d / 2.0 - 0.01), cream.darkened(0.12))
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
	var door := Node3D.new()
	door.position = Vector3(-1.9, found_h, -d / 2.0 - 0.02)
	body.add_child(door)
	B.mesh(door, B.boxm(Vector3(0.9, 2.0, 0.06)), Vector3(0, 1.0, 0), Color(0.4, 0.26, 0.15))
	B.mesh(door, B.boxm(Vector3(0.1, 0.1, 0.08)), Vector3(0.32, 1.0, 0.02), Color(0.75, 0.72, 0.6))
	# Kuisti: kansi, valkoinen kaide, tolpat ja portaat länsipäässä.
	B.mesh(body, B.boxm(Vector3(l, 0.1, porch_d)), Vector3(0, found_h - 0.02, deck_z), Color(0.62, 0.5, 0.36))
	for x in [-l / 2.0 + 0.3, -l / 2.0 + 1.9, -l / 2.0 + 3.5, -l / 2.0 + 5.1, -l / 2.0 + 6.7, l / 2.0 - 0.3]:
		B.mesh(body, B.boxm(Vector3(0.14, wall_h, 0.14)), Vector3(x, found_h + wall_h / 2.0, deck_z - porch_d / 2.0), white)
	for x2 in [-l / 2.0 + 0.3, -l / 2.0 + 1.9, -l / 2.0 + 3.5, -l / 2.0 + 5.1, -l / 2.0 + 6.7, l / 2.0 - 0.3]:
		B.mesh(body, B.boxm(Vector3(0.1, 0.06, 0.1)), Vector3(x2, found_h + 0.86, deck_z - porch_d / 2.0 + 0.3), white)
	B.mesh(body, B.boxm(Vector3(l - 0.2, 0.06, 0.06)), Vector3(0, found_h + 0.86, deck_z - porch_d + 0.02), white)
	for i in 26:
		B.mesh(body, B.boxm(Vector3(0.03, 0.7, 0.03)), Vector3(-l / 2.0 + 0.3 + i * (l - 0.6) / 25.0, found_h + 0.5, deck_z - porch_d + 0.02), white)
	# Portaat lännessä maahan.
	var stx := -l / 2.0 - 0.15
	for i in 3:
		var sy := found_h - i * found_h / 3.0 - found_h / 6.0
		B.mesh(body, B.boxm(Vector3(1.1, found_h / 3.0, 0.32)), Vector3(stx - i * 0.32, sy, deck_z + 0.2 + i * 0.32), Color(0.5, 0.4, 0.28))
	# Kuistin lattia kiinteäksi (muuten kävellään maata pitkin ja kansi leikkaa polvista) ja portaiden kohdalle
	# loiva luiska: CharacterBody ei nouse porrasaskelmia, mutta kävelee alle 45° rinnettä ylös.
	body.add_child(B.box_shape(Vector3(l, found_h + 0.03, porch_d), Vector3(0, (found_h + 0.03) / 2.0, deck_z)))
	var run := 1.2
	var ramp := B.box_shape(Vector3(Vector2(run, found_h).length(), 0.1, 1.1), Vector3.ZERO)
	ramp.transform = Transform3D(Basis(Vector3.BACK, atan2(found_h, run)), Vector3(-l / 2.0 - run / 2.0, found_h / 2.0 - 0.05, deck_z + 0.5))
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


# --- Halkovaja ja vedenlämmitin --------------------------------------------------

func _build_woodshed() -> void:
	var dark := Color(0.28, 0.22, 0.16)
	var shed := StaticBody3D.new()
	shed.position = Vector3(-8.6, 0, -3.6)
	shed.rotation.y = 0.35
	add_child(shed)
	shed.add_child(B.box_shape(Vector3(3.0, 2.1, 2.2), Vector3(0, 1.05, 0)))
	B.mesh(shed, B.boxm(Vector3(3.0, 2.1, 2.2)), Vector3(0, 1.05, 0), dark)
	B.mesh(shed, B.boxm(Vector3(3.2, 0.08, 2.4)), Vector3(0, 2.14, 0), Color(0.2, 0.19, 0.18)).rotation.x = 0.1
	# Lämminvesivaraaja ulkoseinällä.
	B.mesh(shed, B.cyl(0.26, 0.26, 1.1, 12), Vector3(1.7, 0.9, -0.2), Color(0.85, 0.85, 0.87))
	B.mesh(shed, B.cyl(0.05, 0.05, 0.3, 8), Vector3(1.7, 1.5, -0.2), Color(0.5, 0.5, 0.52))
	var sign := B.sign_plate(shed, "HALKOVAJA", Color(0.36, 0.2, 0.1), Color(0.98, 0.95, 0.86), 0.16, 24,
		Color(0.3, 0.18, 0.1), "Helvetica Neue")
	sign.position = Vector3(0, 1.85, 1.15)
	# Halkopino.
	for row in 5:
		for col in 8:
			var h := B.mesh(shed, B.cyl(0.07, 0.07, 0.4, 5), Vector3(-1.3 + col * 0.32, 0.12 + row * 0.2, 1.14),
				Color(0.72, 0.58, 0.38) if (row + col) % 3 else Color(0.62, 0.48, 0.3))
			h.rotation.x = PI / 2.0


# --- Savusauna ------------------------------------------------------------------

func _build_savusauna() -> void:
	var w := 3.4
	var d := 2.9
	var wall_h := 2.0
	var rise := 0.7
	var log_col := Color(0.42, 0.32, 0.2)
	var sauna := StaticBody3D.new()
	sauna.position = Vector3(7.4, 0, 6.4)  # akselinsuuntainen: ei kiertoa, ovi -X:ssä
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
	tree.position = Vector3(9.0, 0, 5.0)
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
	# Ulkokeittiö ja savustin kuistin nurkalla.
	var kitchen := Node3D.new()
	kitchen.position = Vector3(-4.6, 0, -6.0)
	add_child(kitchen)
	B.mesh(kitchen, B.boxm(Vector3(1.6, 0.9, 0.6)), Vector3(0, 0.45, 0), Color(0.32, 0.3, 0.28))
	B.mesh(kitchen, B.boxm(Vector3(1.6, 0.05, 0.6)), Vector3(0, 0.92, 0), Color(0.5, 0.5, 0.5))
	var smoker := Node3D.new()
	smoker.position = Vector3(1.4, 0, 0.2)
	kitchen.add_child(smoker)
	B.mesh(smoker, B.cyl(0.35, 0.4, 1.0, 14), Vector3(0, 0.55, 0), Color(0.15, 0.15, 0.16), Vector3(0, 0, 90))
	B.mesh(smoker, B.cyl(0.22, 0.24, 0.55, 12), Vector3(-0.55, 0.4, 0), Color(0.15, 0.15, 0.16), Vector3(0, 0, 90))
	B.mesh(smoker, B.cyl(0.04, 0.04, 0.6, 8), Vector3(-0.55, 0.85, 0), Color(0.15, 0.15, 0.16))
	for legx in [-0.4, 0.4]:
		B.mesh(smoker, B.cyl(0.03, 0.03, 0.5, 6), Vector3(legx, 0.25, 0.28), Color(0.1, 0.1, 0.1))
		B.mesh(smoker, B.cyl(0.03, 0.03, 0.5, 6), Vector3(legx, 0.25, -0.28), Color(0.1, 0.1, 0.1))
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
	var b := Vector2(0, -8.0)
	var n := (b - a).normalized().orthogonal() * 1.6
	for v in [a + n, b + n, b - n, a + n, b - n, a - n]:
		st.add_vertex(Vector3(v.x, 0.005, v.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = road_mat
	add_child(mi)


# --- Männyt ympärillä --------------------------------------------------------------

func _build_trees() -> void:
	for i in 46:
		var a := randf() * TAU
		var r := 16.0 + randf() * 26.0
		var p := Vector2(2.0, 5.0) + Vector2(cos(a) * r, sin(a) * r)
		if p.distance_to(Vector2(8.0, 30.0)) < 14.0:
			continue  # ei puita järveen
		if p.distance_to(Vector2(TAXI_LOCAL.x, TAXI_LOCAL.z)) < 6.0:
			continue  # ei puita taksipysäkille tai pihatielle
		_pine(Vector3(p.x, 0, p.y), 0.8 + randf() * 0.6)


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
## Mökin ovi kuistilla (paikallinen): E vie sisään (main.gd _mokki_logic).
const DOOR_LOCAL := Vector3(-1.9, 0, -4.1)


func _build_santtu() -> void:
	var look := SANTTU_LOOK
	B.mesh(self, B.cyl(0.22, 0.26, 0.42, 12), SANTTU_LOCAL + Vector3(0, 0.21, 0), Color(0.4, 0.28, 0.17))  # pihatuoli (kanto)
	santtu = Looks.make(self, look)
	santtu.position = SANTTU_LOCAL + Vector3(0, 0.2, 0)
	santtu.rotation.y = B.yaw_to(Vector3(0, 0, 1))  # kasvot kohti mökkiä
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
