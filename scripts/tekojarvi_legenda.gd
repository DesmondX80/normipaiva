extends CanvasLayer
## Legendaarinen hetki "tekojarven_ukko" (Tekojärven Ukko): kun Ukko viedään ensimmäistä kertaa Saloisten Pirttiin
## täytettäväksi (main.gd _ukko_museum), hetki lavastetaan Pirtin pihalla. Vaiheet:
##   punnitus  pihalla kolmijalka ja vanha puntari, Ukko roikkuu koukussa leuastaan ja heilahtelee; opas tasaa sen,
##             puntarin viisari heilahtaa ja asettuu: 18,4 kg (lähikuva taulusta)
##   uistimet  opas mittaa (132 cm) ja osoittaa kylkeä: kolme vanhaa uistinta kuin mitalit, suussa isän kuparilusikka
##   tauno     Tauno kävelee pihalle, pysähtyy Ukon eteen ja koskettaa punavalkoista lusikkaa ("Isä veisti sen itse.
##             Ukko vei sen kesällä -79."), kääntyy pois, pyyhkii silmää: kyynel poskella. "Isä oli oikeassa."
##   kuva      Tauno ja pelaaja nostavat Ukon vaakaan lehtikuvaan, Pekka ja Arto myöntävät, Anna-Liisa kuvaa
##             puhelimella: salama
##   otsikko   lehtikuva: TEKOJÄRVEN UKKO, 18,4 kg · 132 cm, Tauno itki vähän
## Kehys: pihan solmu G Pirtin oven edustalla (world.museum_door), paikallinen -Z = ulos pihalle (julkisivun normaali
## world.museum_nrm), +Z = Pirttiä kohti. Pihalta katsoen paikallinen +x näkyy vasemmalla. Hahmojen etu -Z (Looks).
## Hauen oma akseli: +X = kuono, +Y = selkä, -Z = kylki, jossa uistimet (näkyy pihalle). Maan korkeus Terrain.h:sta.
## Ukko jää museoon täytettäväksi. Tauno muistelee myöhemmin kirppiksellä (main.gd _talk_kirppis "ukko_muisto").

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const T := preload("res://scripts/terrain.gd")

const DUR := {"punnitus": 6.6, "uistimet": 5.8, "tauno": 8.6, "kuva": 7.4, "otsikko": 6.2}
const ORDER := ["punnitus", "uistimet", "tauno", "kuva", "otsikko"]
const LEN := 1.32  # Ukon pituus (m)
const KG := 18.4
const TRIPOD := Vector2(0.0, -1.0)  # kolmijalan keskusta pihalla
const HOOK_Y := 1.86  # puntarin koukun korkeus maasta
const HOLD_X := 0.42  # lehtikuvassa Tauno (+x) ja pelaaja (-x) Ukon takana
const HOLD_Z := -1.5
## Otteet hauen alla olkapäiden edessä: Tauno kiduksista ja keskeltä, pelaaja vatsasta ja pyrstön tyvestä.
const HOLD_U := [0.86, 0.6, 0.3, 0.04]
const PHOTO := Vector2(-0.15, -4.4)  # Anna-Liisa kuvaa tästä (otsikon kamera on hänen puhelimensa)
## Puntarin taulu: 0..25 kg viisarin kierroksella (270°), 0 vasemmalla alhaalla.
const DIAL_MAX := 25.0
const DIAL_SWEEP := 4.71
## Kirppiksen Tauno (kirppis_interior.gd PEOPLE): sänki, harmaa siili, oliivinvihreä paita.
const TAUNO := {"shirt": Color(0.3, 0.32, 0.25), "pants": Color(0.2, 0.22, 0.35), "shoes": Color(0.2, 0.15, 0.1), "shoe": "tyokenka",
	"hair": "Hair_Buzzed", "hair_color": Color(0.7, 0.7, 0.68), "beard": true, "height": 1.78, "skin": Color(0.95, 0.72, 0.64), "belly": 0.8}
## Pirtin opas (sama kuin aarnivalkea_legenda.gd): harmaa tukka, pyöreät lasit, ruskea tweedtakki.
const OPAS := {"shirt": Color(0.42, 0.3, 0.2), "pants": Color(0.28, 0.27, 0.25), "shoes": Color(0.2, 0.13, 0.08), "shoe": "kavelykenka",
	"hair": "Hair_SimpleParted", "hair_color": Color(0.78, 0.78, 0.76), "height": 1.74, "skin": Color(0.96, 0.8, 0.7), "belly": 0.6, "muscle": -0.8, "shoulders": -0.3,
	"round_glasses": true}
## Tauno muistelee myöhemmin (main.gd _talk_kirppis "ukko_muisto").
const MUISTO := ["Kahdeksantoista pilkku neljä. Mää kävin eilen Pirtissä kattomassa. Se punavalkonen on vieläki sen leuassa.",
	"Isä sano aina, että Ukko on ladon raunioilla. Kukaan ei uskonu. Nyt se on Pirtin seinällä, ja isän lusikka sen kyljessä.",
	"Pekka tuli kirppikselle ja osti multa virvelin. Ei sanonu mitään. Mää tiedän, mitä se tarkotti.",
	"Lehdessä oli se kuva. Mää näytän siinä ihan hölmöltä. Leikkasin sen silti seinälle, isän kuvan viereen."]

var world: Node3D
var hide_nodes: Array = []  # oikea pelaaja (jalan tai pyörällä) piiloon kohtauksen ajaksi (kopio näyttelee)
var _was_visible := {}

var phase := ""
var _t := 0.0
var _cam: Camera3D
var _ui: Control
var _keys: Node
var _story := ""
var _bub := {}
var _once := {}
var _G: Node3D
var _props: Array[Node3D] = []
var me: Node3D
var opas: Node3D
var tauno: Node3D
var pekka: Node3D
var arto: Node3D
var annaliisa: Node3D
var pike: Node3D  # Ukko
var lure_isa: Node3D  # isän punavalkoinen lusikka kyljessä (Tauno koskettaa)
var lures: Array[Node3D] = []
var scale_dial: Node3D  # puntarin taulu (viisari lapsena)
var needle: Node3D
var phone: Node3D
var tear: MeshInstance3D
var _streak: MeshInstance3D
var _flash_light: OmniLight3D
var needle_kg := 0.0  # viisarin lukema (testi lukee)
var tear_shown := false
var flashed := false
var _flash := 0.0


func _ready() -> void:
	layer = 6
	_G = Node3D.new()
	world.add_child(_G)
	_props.append(_G)
	var md: Vector3 = world.museum_door
	var n: Vector2 = world.museum_nrm
	_G.global_position = Vector3(md.x, 0.0, md.z)
	_G.rotation.y = B.yaw_to(Vector3(n.x, 0, n.y))  # -Z ulos pihalle
	_cam = Camera3D.new()
	world.add_child(_cam)
	_cam.make_current()
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_keys.set_text("%s ohita" % Settings.cap("interact"))
	for nd in hide_nodes:
		if is_instance_valid(nd):
			_was_visible[nd] = (nd as Node3D).visible
			(nd as Node3D).visible = false
	_build()
	_begin("punnitus")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	_build_tripod()
	pike = _build_pike()
	opas = _person(OPAS, 0.55, -1.42)
	me = _person(Looks.player(), -1.0, -1.55)
	tauno = _person(TAUNO, 4.4, -4.4)
	pekka = _person(Looks.PEKKA, 4.8, -3.6)
	arto = _person(Looks.ARTO, -5.4, -3.2)
	annaliisa = _person(Looks.ANNA_LIISA, -5.8, -4.0)
	for c in [tauno, pekka, arto, annaliisa]:
		c.visible = false
	phone = _build_phone()
	phone.visible = false
	tear = B.mesh(world, B.sphere(0.5, 8), Vector3.ZERO, Color.WHITE)
	tear.scale = Vector3(0.014, 0.02, 0.011)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.75, 0.9, 1.0, 0.85)
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.metallic = 0.3
	tm.roughness = 0.05
	tm.emission_enabled = true
	tm.emission = Color(0.5, 0.7, 0.9)
	tm.emission_energy_multiplier = 0.6
	tear.material_override = tm
	tear.visible = false
	_props.append(tear)
	_streak = B.mesh(world, B.boxm(Vector3.ONE), Vector3.ZERO, Color.WHITE)  # märkä juova poskella
	_streak.material_override = tm
	_streak.visible = false
	_props.append(_streak)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 1.0, 0.97)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 9.0
	world.add_child(_flash_light)
	_props.append(_flash_light)
	# Lämmin lamppu oven päällä (iltaisin piha on valaistu; Ukko saadaan illalla).
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.2
	lamp.omni_range = 7.5
	world.add_child(lamp)
	_props.append(lamp)
	lamp.global_position = _L(0.0, 0.6, 2.6)


## Punnituspukki: kaksi kuorittua salkoa Ukon takana sivuilla (pihan x = ±0,85), poikkipuu 2,4 m:ssä, tukivinot
## maahan; poikkipuun keskeltä köysi ja ketju vanhalle messinkiselle puntarille, pyöreä taulu pihalle päin. Pukin
## edessä on tilaa seistä (hahmot pukin ja kameran välissä).
func _build_tripod() -> void:
	var wood := Color(0.62, 0.5, 0.36)
	var bar_y := 2.42
	var pz := TRIPOD.y + 0.3  # salot hieman Ukon takana
	for sx in [-0.85, 0.85]:
		var base := _L(TRIPOD.x + sx, pz)
		var g := Node3D.new()
		world.add_child(g)
		_props.append(g)
		var h := bar_y + 0.12 + (_L(TRIPOD.x, TRIPOD.y).y - base.y)  # salko poikkipuun yli
		g.global_position = base + Vector3(0, h / 2.0, 0)
		B.mesh(g, B.cyl(0.045, 0.055, h, 10), Vector3.ZERO, wood)
		for k in 4:  # kuoren jämät ja oksantyngät
			B.mesh(g, B.cyl(0.057, 0.057, 0.03, 10), Vector3(0, -h * 0.38 + k * h * 0.24, 0), wood.darkened(0.35))
		# Tukivino taakse maahan (Pirttiä kohti), ei hahmojen tiellä.
		var bt := _L(TRIPOD.x + sx, pz + 0.9)
		var tp := base + Vector3(0, 1.3, 0)
		var br := Node3D.new()
		world.add_child(br)
		_props.append(br)
		br.global_position = (bt + tp) / 2.0
		B.mesh(br, B.cyl(0.03, 0.035, bt.distance_to(tp), 8), Vector3.ZERO, wood.darkened(0.1))
		br.look_at(tp, Vector3.UP if absf((tp - bt).normalized().y) < 0.99 else Vector3.FORWARD)
		br.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	# Poikkipuu.
	var bc := _L(TRIPOD.x, pz, bar_y)
	var bar := Node3D.new()
	world.add_child(bar)
	_props.append(bar)
	bar.global_position = bc
	bar.rotation.y = _G.global_rotation.y
	var beam := B.mesh(bar, B.cyl(0.045, 0.045, 1.95, 10), Vector3.ZERO, wood.lightened(0.04))
	beam.rotation.z = PI / 2.0
	for sx in [-0.85, 0.85]:
		var lash := B.mesh(bar, B.cyl(0.06, 0.06, 0.08, 10), Vector3(sx, 0, 0), Color(0.72, 0.62, 0.42))
		lash.rotation.z = PI / 2.0
	# Köysilenkki poikkipuun keskellä ja ketju puntarille (ripustus kohti Ukon pystylinjaa).
	var rope := Color(0.72, 0.62, 0.42)
	B.mesh(bar, B.cyl(0.055, 0.055, 0.05, 10), Vector3(0, 0, 0), rope).rotation.z = PI / 2.0
	var top := _L(TRIPOD.x, TRIPOD.y, bar_y - 0.05)
	var r0 := B.mesh(world, B.cyl(0.006, 0.006, (bc - top).length(), 6), (bc + top) / 2.0, rope.darkened(0.2))
	r0.look_at(top + Vector3(0.0001, 0, 0), Vector3.UP)
	r0.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	_props.append(r0)
	var chain_top := top
	var dial_y := _L(TRIPOD.x, TRIPOD.y).y + HOOK_Y + 0.2
	var n := 6
	for k in n:
		var y := chain_top.y - (chain_top.y - dial_y - 0.1) * (k + 0.5) / n
		var ring := B.mesh(world, B.cyl(0.018, 0.018, 0.006, 10), Vector3(top.x, y, top.z), Color(0.35, 0.35, 0.36))
		ring.rotation = Vector3(PI / 2.0, _G.global_rotation.y + (PI / 2.0 if k % 2 == 0 else 0.0), 0)
		_props.append(ring)
	# Puntari: messinkirunko, valkoinen taulu (asteikko ja viisari), lasin kiilto; koukku alla.
	var sg := Node3D.new()
	world.add_child(sg)
	_props.append(sg)
	sg.global_position = Vector3(top.x, dial_y, top.z)
	sg.rotation.y = _G.global_rotation.y
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.6, 0.28)
	brass.metallic = 0.85
	brass.roughness = 0.35
	var body := B.mesh(sg, B.cyl(0.085, 0.085, 0.05, 24), Vector3.ZERO, Color.WHITE)
	body.rotation.x = PI / 2.0
	body.material_override = brass
	var eye := B.mesh(sg, B.cyl(0.016, 0.016, 0.012, 10), Vector3(0, 0.095, 0), Color.WHITE)  # ripustuslenkki
	eye.rotation.z = PI / 2.0
	eye.material_override = brass
	scale_dial = Node3D.new()
	scale_dial.position = Vector3(0, 0, -0.026)
	sg.add_child(scale_dial)
	var face := B.mesh(scale_dial, B.cyl(0.074, 0.074, 0.002, 28), Vector3.ZERO, Color(0.96, 0.95, 0.9))
	face.rotation.x = PI / 2.0
	face.material_override = B.unshaded(Color(0.93, 0.92, 0.86))
	# Asteikko pihalta katsoen myötäpäivään (pihalta katsoen paikallinen +x on vasemmalla: kulma a -> (-sin a, cos a)).
	# Viivat 1 kg välein, pitkät 5 kg välein, punainen alue yli 20 kg.
	for k in 26:
		var a := _dial_angle(float(k))
		var long := k % 5 == 0
		var r0t := 0.054 if long else 0.062
		var tick := B.mesh(scale_dial, B.boxm(Vector3(0.004 if long else 0.0022, 0.07 - r0t, 0.001)),
			Vector3(-sin(a), cos(a), 0) * ((r0t + 0.07) / 2.0) + Vector3(0, 0, -0.0015), Color.WHITE)
		tick.material_override = B.unshaded(Color(0.8, 0.12, 0.08) if k > 20 else Color(0.08, 0.08, 0.08))
		tick.rotation.z = a
	# Kiekon keskellä musta valmistajan rengas.
	var ring2 := B.mesh(scale_dial, B.cyl(0.03, 0.03, 0.0008, 24), Vector3(0, -0.022, -0.0012), Color.WHITE)
	ring2.rotation.x = PI / 2.0
	ring2.material_override = B.unshaded(Color(0.75, 0.72, 0.62))
	needle = Node3D.new()
	needle.position = Vector3(0, 0, -0.004)
	scale_dial.add_child(needle)
	var nm := B.unshaded(Color(0.85, 0.08, 0.06))
	B.mesh(needle, B.boxm(Vector3(0.004, 0.066, 0.0015)), Vector3(0, 0.026, 0), Color.WHITE).material_override = nm
	B.mesh(needle, B.boxm(Vector3(0.006, 0.016, 0.0015)), Vector3(0, -0.012, 0), Color.WHITE).material_override = nm
	var hub := B.mesh(needle, B.cyl(0.007, 0.007, 0.004, 10), Vector3(0, 0, -0.001), Color(0.2, 0.2, 0.2))
	hub.rotation.x = PI / 2.0
	var rim := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.072
	tor.outer_radius = 0.084
	tor.rings = 32
	rim.mesh = tor
	rim.rotation.x = PI / 2.0
	rim.position = Vector3(0, 0, -0.002)
	rim.material_override = brass
	scale_dial.add_child(rim)
	# Koukku: varsi ja kaari alas (hauen leuka kaaressa).
	var hook_m := StandardMaterial3D.new()
	hook_m.albedo_color = Color(0.4, 0.4, 0.42)
	hook_m.metallic = 0.9
	hook_m.roughness = 0.4
	var shank := B.mesh(sg, B.cyl(0.006, 0.006, 0.14, 8), Vector3(0, -0.15, 0), Color.WHITE)
	shank.material_override = hook_m
	for k in 5:
		var a := PI * k / 4.0
		var seg := B.mesh(sg, B.cyl(0.006, 0.006, 0.022, 6), Vector3(0.022 * sin(a), -0.22 - 0.022 * (1.0 - cos(a)) - 0.02, 0), Color.WHITE)
		seg.rotation.z = a + PI / 2.0
		seg.material_override = hook_m


func _dial_angle(kg: float) -> float:
	return -DIAL_SWEEP / 2.0 + DIAL_SWEEP * clampf(kg / DIAL_MAX, 0.0, 1.06)


## Ukko: loftattu ruumis (litteä ankannokka, pitkä selkä, evät takana kuten hauella), vihreä selkä ja kyljet, vaaleat
## papumaiset täplät, kermanvalkoinen vatsa, oranssinruskeat evät, keltaiset silmät. Kyljessä (-Z) kolme vanhaa
## uistinta ja suupielessä isän kuparilusikka.
func _build_pike() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var rings := 44
	var segs := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var back := Color(0.14, 0.2, 0.09)
	var side := Color(0.3, 0.38, 0.17)
	var belly := Color(0.9, 0.87, 0.7)
	for i in rings + 1:
		var u := float(i) / rings  # 0 = pyrstön tyvi, 1 = kuono
		var x := -LEN * 0.42 + u * LEN * 0.92
		var hw := _pike_wh(u)
		for j in segs + 1:
			var a := TAU * j / segs
			var yy := sin(a) * hw.x
			var zz := cos(a) * hw.y
			# Alaleuka: kuonon alapuoli hieman pidempi (hauen leuka työntyy esiin): litistetään vain yläpuolta.
			var s := sin(a)
			var col := side.lerp(back, clampf(s * 1.6, 0.0, 1.0)) if s > -0.15 else side.lerp(belly, clampf((-s - 0.15) * 2.2, 0.0, 1.0))
			st.set_color(col)
			st.set_uv(Vector2(u, float(j) / segs))
			st.add_vertex(Vector3(x, yy, zz))
	for i in rings:
		for j in segs:
			var a0 := i * (segs + 1) + j
			var a1 := a0 + segs + 1
			st.add_index(a0)
			st.add_index(a0 + 1)
			st.add_index(a1)
			st.add_index(a1)
			st.add_index(a0 + 1)
			st.add_index(a1 + 1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.45
	m.metallic_specular = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	g.add_child(mi)
	# Päät umpeen: kuonon kärki ja pyrstön tyvi pienillä palloilla.
	var nose := B.mesh(g, B.sphere(0.5, 10), Vector3(LEN * 0.5, 0, 0), back.lerp(side, 0.5))
	nose.scale = Vector3(0.03, _pike_wh(1.0).x * 2.0, _pike_wh(1.0).y * 2.0)
	# Täplät kyljissä: vaaleat papumaiset, rivit hieman vinossa.
	var rng := RandomNumberGenerator.new()
	rng.seed = 18
	for zs in [-1.0, 1.0]:
		for k in 30:
			var u := rng.randf_range(0.08, 0.8)
			var a := rng.randf_range(-0.35, 0.95)  # kulma kyljellä (0 = kyljen keskilinja, + selkää kohti)
			var hw := _pike_wh(u)
			var x := -LEN * 0.42 + u * LEN * 0.92
			var p := Vector3(x, sin(a) * hw.x, zs * cos(a) * hw.y)
			var sp := B.mesh(g, B.sphere(0.5, 6), p * Vector3(1, 0.985, 0.985), Color(0.8, 0.8, 0.52))
			sp.scale = Vector3(rng.randf_range(0.016, 0.024), rng.randf_range(0.008, 0.011), 0.006)
			sp.rotation.x = -a * zs
	# Silmät: keltainen iiris, musta pupilli.
	var ue := 0.9
	var hwe := _pike_wh(ue)
	var xe := -LEN * 0.42 + ue * LEN * 0.92
	for zs in [-1.0, 1.0]:
		var e := B.mesh(g, B.sphere(0.5, 10), Vector3(xe, hwe.x * 0.45, zs * hwe.y * 0.86), Color(0.92, 0.78, 0.2))
		e.scale = Vector3(0.026, 0.024, 0.014)
		var pu := B.mesh(g, B.sphere(0.5, 8), Vector3(xe + 0.002, hwe.x * 0.45, zs * (hwe.y * 0.86 + 0.006)), Color(0.04, 0.04, 0.04))
		pu.scale = Vector3(0.013, 0.012, 0.006)
		# Suu: tumma viiva kuonon kyljessä silmän alta kärkeen, kiduskannen kaari.
		var mo := B.mesh(g, B.boxm(Vector3(LEN * 0.13, 0.004, 0.003)), Vector3(LEN * 0.43, -0.004, zs * _pike_wh(0.94).y * 0.98), Color(0.12, 0.1, 0.06))
		mo.rotation.z = 0.06
		for k in 5:
			var ga := -0.9 + k * 0.45
			var gu := 0.79
			var gw := _pike_wh(gu)
			var gl := B.mesh(g, B.boxm(Vector3(0.004, gw.x * 0.42, 0.003)), Vector3(-LEN * 0.42 + gu * LEN * 0.92 + 0.012 * cos(ga), sin(ga) * gw.x * 0.8, zs * gw.y * cos(ga * 0.6) * 1.0), back.darkened(0.2))
			gl.rotation.z = ga * 0.3
	# Evät (oranssinruskeat, ohuet levyt): selkä- ja peräevä kaukana takana, rinta- ja vatsaevät, haarainen pyrstö.
	var fin := Color(0.78, 0.45, 0.22)
	var tail_x := -LEN * 0.42
	_fin(g, [Vector3(tail_x + 0.02, 0, 0), Vector3(tail_x - 0.2, 0.13, 0), Vector3(tail_x - 0.13, 0.0, 0), Vector3(tail_x - 0.2, -0.13, 0)], fin.darkened(0.08))
	var du := 0.2
	var dx := -LEN * 0.42 + du * LEN * 0.92
	_fin(g, [Vector3(dx - 0.06, _pike_wh(0.14).x * 0.9, 0), Vector3(dx + 0.02, _pike_wh(du).x + 0.09, 0), Vector3(dx + 0.12, _pike_wh(0.3).x * 0.95, 0)], fin.darkened(0.15))
	_fin(g, [Vector3(dx - 0.05, -_pike_wh(0.14).x * 0.9, 0), Vector3(dx + 0.03, -_pike_wh(du).x - 0.08, 0), Vector3(dx + 0.11, -_pike_wh(0.3).x * 0.95, 0)], fin)
	for zs in [-1.0, 1.0]:
		var px := -LEN * 0.42 + 0.74 * LEN * 0.92
		var pw := _pike_wh(0.74)
		_fin(g, [Vector3(px, -pw.x * 0.55, zs * pw.y * 0.9), Vector3(px - 0.1, -pw.x * 0.9 - 0.03, zs * (pw.y + 0.03)), Vector3(px - 0.04, -pw.x * 0.95, zs * pw.y * 0.85)], fin.lightened(0.08))
		var vx := -LEN * 0.42 + 0.45 * LEN * 0.92
		var vw := _pike_wh(0.45)
		_fin(g, [Vector3(vx, -vw.x * 0.9, zs * vw.y * 0.4), Vector3(vx - 0.09, -vw.x - 0.04, zs * vw.y * 0.6), Vector3(vx - 0.04, -vw.x * 0.98, zs * vw.y * 0.3)], fin)
	# Uistimet kyljessä (-Z, kohti pihaa): isän punavalkoinen lusikka kidusten takana, messinkilusikka ja puinen vaappu.
	lure_isa = _lure(g, "punavalko", 0.74, 0.25)
	lures.append(lure_isa)
	lures.append(_lure(g, "messinki", 0.56, -0.05))
	lures.append(_lure(g, "vaappu", 0.4, 0.35))
	# Isän kuparilusikka suupielessä (sillä Ukko saatiin), siiman pätkä roikkuu.
	var cu := _spoon_mesh(g, Color(0.82, 0.48, 0.25), Color(0.95, 0.65, 0.4))
	cu.position = Vector3(LEN * 0.44, -0.035, -_pike_wh(0.95).y - 0.012)
	cu.rotation = Vector3(0, 0, -1.2)
	cu.scale = Vector3.ONE * 1.15
	return g


## Hauen puolikorkeus (x) ja puolileveys (y) ruumiin kohdassa u (0 = pyrstön tyvi, 1 = kuono).
static func _pike_wh(u: float) -> Vector2:
	# Pyrstön tyvi kapea, ruumis korkeimmillaan keskivaiheilla, pää pitkä ja litistyvä kohti ankannokkaa.
	var h: float
	var w: float
	if u < 0.12:
		var k := u / 0.12
		h = lerpf(0.028, 0.05, k)
		w = lerpf(0.016, 0.03, k)
	elif u < 0.62:
		var k := (u - 0.12) / 0.5
		h = lerpf(0.05, 0.1, sin(k * PI / 2.0))
		w = lerpf(0.03, 0.064, sin(k * PI / 2.0))
	elif u < 0.8:
		var k := (u - 0.62) / 0.18
		h = lerpf(0.1, 0.075, k)
		w = lerpf(0.064, 0.054, k)
	else:
		var k := (u - 0.8) / 0.2
		h = lerpf(0.075, 0.016, pow(k, 0.85))
		w = lerpf(0.054, 0.026, k)
	return Vector2(h, w)


## Ohut evä pisteistä (kolmioviuhka ensimmäisestä pisteestä), molemmin puolin näkyvä; säteet tummina viivoina.
func _fin(parent: Node3D, pts: Array, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, pts.size() - 1):
		for p in [pts[0], pts[i], pts[i + 1]]:
			st.set_color(col)
			st.set_normal(Vector3(0, 0, -1))
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	mi.material_override = m
	parent.add_child(mi)
	for i in range(1, pts.size()):
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[i]
		var ray := B.mesh(parent, B.boxm(Vector3(a.distance_to(b) * 0.9, 0.0025, 0.002)), (a + b) / 2.0, col.darkened(0.3))
		ray.rotation.z = atan2(b.y - a.y, b.x - a.x)
		ray.position.z = a.z + 0.001 * signf(a.z + 0.0001)


## Uistin hauen kyljessä kohdassa u, kulma a (0 = kyljen keskilinja): ruostunut perukelanka ja kolmihaarakoukku
## upoksissa kyljessä, uistin roikkuu painovoiman suuntaan (Ukon roikkuessa heilahtaa alas).
func _lure(parent: Node3D, kind: String, u: float, a: float) -> Node3D:
	var hw := _pike_wh(u)
	var x := -LEN * 0.42 + u * LEN * 0.92
	var g := Node3D.new()
	g.position = Vector3(x, sin(a) * hw.x, -cos(a) * hw.y - 0.004)
	parent.add_child(g)
	var rust := Color(0.45, 0.25, 0.12)
	# Kolmihaarakoukun kärjet näkyvät kyljessä.
	for k in 3:
		var hk := B.mesh(g, B.boxm(Vector3(0.003, 0.016, 0.003)), Vector3(0.006 * cos(k * 2.1), 0.006 * sin(k * 2.1), 0.002), rust)
		hk.rotation.z = k * 2.1
	var body := Node3D.new()
	body.position = Vector3(-0.012, 0, -0.012)
	g.add_child(body)
	match kind:
		"punavalko":
			var s := _spoon_mesh(body, Color(0.86, 0.12, 0.1), Color(0.97, 0.95, 0.9))
			s.rotation = Vector3(0, 0, 0.4)
			s.scale = Vector3.ONE * 1.25
		"messinki":
			var s2 := _spoon_mesh(body, Color(0.82, 0.66, 0.3), Color(0.95, 0.85, 0.5))
			s2.rotation = Vector3(0, 0, -0.3)
			s2.scale = Vector3.ONE * 1.1
		"vaappu":
			# Puinen vaappu: kalanmuotoinen runko, keltavihreä, punainen pää, lasisilmä ja muovinen kieli.
			var w := Node3D.new()
			w.rotation.z = 0.5
			body.add_child(w)
			var r := B.mesh(w, B.sphere(0.5, 10), Vector3(-0.035, 0, 0), Color(0.85, 0.78, 0.25))
			r.scale = Vector3(0.075, 0.022, 0.016)
			var bk := B.mesh(w, B.sphere(0.5, 10), Vector3(-0.035, 0.006, 0), Color(0.25, 0.45, 0.2))
			bk.scale = Vector3(0.07, 0.012, 0.014)
			var hd := B.mesh(w, B.sphere(0.5, 10), Vector3(-0.072, 0, 0), Color(0.8, 0.15, 0.1))
			hd.scale = Vector3(0.022, 0.02, 0.016)
			B.mesh(w, B.sphere(0.004, 6), Vector3(-0.076, 0.004, -0.008), Color(0.95, 0.95, 0.9))
			var lip := B.mesh(w, B.boxm(Vector3(0.016, 0.002, 0.012)), Vector3(-0.088, -0.006, 0), Color(0.8, 0.85, 0.9, 0.7))
			lip.rotation.z = 0.6
	# Perukelanka uistimesta koukkuun.
	var wire := B.mesh(g, B.boxm(Vector3(0.018, 0.0015, 0.0015)), Vector3(-0.006, 0, -0.006), rust.lightened(0.2))
	wire.rotation.y = 0.8
	return g


## Lusikkauistin: pisaranmuotoinen kupera levy (etupuoli väri, raita), rengas ja pieni koukku. Pituus n. 6 cm.
func _spoon_mesh(parent: Node3D, col: Color, stripe: Color) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.6
	m.roughness = 0.3
	var blade := B.mesh(g, B.sphere(0.5, 12), Vector3(0, -0.032, 0), Color.WHITE)
	blade.scale = Vector3(0.026, 0.06, 0.007)
	blade.material_override = m
	var tip := B.mesh(g, B.sphere(0.5, 10), Vector3(0, -0.012, 0), Color.WHITE)
	tip.scale = Vector3(0.017, 0.03, 0.006)
	tip.material_override = m
	var sm := StandardMaterial3D.new()
	sm.albedo_color = stripe
	sm.metallic = 0.4
	sm.roughness = 0.35
	var s := B.mesh(g, B.sphere(0.5, 10), Vector3(0, -0.036, -0.0025), Color.WHITE)
	s.scale = Vector3(0.012, 0.04, 0.004)
	s.material_override = sm
	var ring := B.mesh(g, B.cyl(0.004, 0.004, 0.0015, 8), Vector3(0, 0.002, 0), Color(0.6, 0.6, 0.62))
	ring.rotation.x = PI / 2.0
	for k in 3:
		var hk := B.mesh(g, B.boxm(Vector3(0.002, 0.014, 0.002)), Vector3(0.004 * cos(k * 2.1), -0.068, 0.004 * sin(k * 2.1)), Color(0.5, 0.5, 0.52))
		hk.rotation.x = 0.4 * sin(k * 2.1)
	return g


## Anna-Liisan puhelin: musta runko, kamera ja salamavalo takana, näyttö edessä.
func _build_phone() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	B.mesh(g, B.boxm(Vector3(0.072, 0.15, 0.009)), Vector3.ZERO, Color(0.08, 0.08, 0.1))
	B.mesh(g, B.boxm(Vector3(0.064, 0.138, 0.001)), Vector3(0, 0, 0.005), Color(0.3, 0.5, 0.7))  # näyttö (kohti kuvaajaa)
	B.mesh(g, B.cyl(0.007, 0.007, 0.003, 10), Vector3(-0.02, 0.055, -0.006), Color(0.02, 0.02, 0.03)).rotation.x = PI / 2.0
	B.mesh(g, B.cyl(0.004, 0.004, 0.003, 8), Vector3(-0.005, 0.058, -0.006), Color(1.0, 1.0, 0.85)).rotation.x = PI / 2.0
	return g


func _person(look: Dictionary, x: float, z: float) -> Node3D:
	var c: Node3D = Looks.make(world, look)
	_props.append(c)
	_stand(c, x, z)
	c.play("Idle", 0.0)
	return c


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	for c in [me, opas, tauno, pekka, arto, annaliisa]:
		c.clear_ik()
		_relax(c)
	tear.visible = false
	_streak.visible = false
	phone.visible = false
	match p:
		"punnitus":
			_story = "Saloisten Pirtin piha. Tekojärven Ukko puntarin koukkuun."
		"uistimet":
			_story = ""
			_stand(opas, 0.5, -1.3)
			_hang_pike(0.0)
		"tauno":
			_story = ""
			tauno.visible = true
			_stand(opas, -0.55, -1.3)  # opas ja pelaaja Ukon toisella puolella: Tauno tulee pihalta vapaan puolen kautta
			_stand(me, -1.2, -1.8)
			_hang_pike(0.0)
		"kuva":
			_story = ""
			for c in [tauno, pekka, arto, annaliisa]:
				c.visible = true
			_stand(tauno, HOLD_X, HOLD_Z)
			_stand(me, -HOLD_X, HOLD_Z)
			_stand(opas, 1.05, -0.95)
		"otsikko":
			_story = ""
			for c in [tauno, pekka, arto, annaliisa]:
				c.visible = true
				c.play("Idle", 0.2)
			_stand(tauno, HOLD_X, HOLD_Z)
			_stand(me, -HOLD_X, HOLD_Z)
			_stand(opas, 1.05, -0.95)
			_stand(pekka, 1.55, -1.5)
			_stand(arto, -1.25, -1.25)
			_stand(annaliisa, PHOTO.x, PHOTO.y)
			annaliisa.visible = false  # kamera on Anna-Liisan puhelin
			Sfx.play("win", -6.0, 0.95)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa E-painalluksesta Pirtin ovella: sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "punnitus" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"punnitus":
			_step_punnitus(delta)
		"uistimet":
			_step_uistimet(delta)
		"tauno":
			_step_tauno(delta)
		"kuva":
			_step_kuva(delta)
		"otsikko":
			_step_otsikko(delta)
	_flash = maxf(0.0, _flash - delta * 1.4)
	_flash_light.light_energy = 6.0 * _flash
	_ui.queue_redraw()
	if phase != "" and _t >= DUR[phase]:
		var i := ORDER.find(phase)
		if i == ORDER.size() - 1:
			_finish()
		else:
			_begin(ORDER[i + 1])


func _finish() -> void:
	if phase == "":
		return
	phase = ""
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	for nd in _was_visible:
		if is_instance_valid(nd):
			(nd as Node3D).visible = _was_visible[nd]
	finished.emit()
	_cam.queue_free()
	queue_free()


func _step_punnitus(_delta: float) -> void:
	# Ukko heilahtaa koukussa (vaimenee), viisari heilahtaa yli ja asettuu 18,4:ään. Opas tasaa kalaa kädellä.
	var damp := exp(-_t * 0.9)
	_hang_pike(0.16 * damp * sin(_t * 3.6))
	var over := 4.5 * exp(-_t * 1.1) * cos(_t * 5.2)
	needle_kg = clampf(KG + over * clampf(_t / 0.4, 0.0, 1.0) - KG * (1.0 - clampf(_t / 0.4, 0.0, 1.0)), 0.0, DIAL_MAX * 1.05)
	needle.rotation.z = _dial_angle(needle_kg)
	if not _once.has("narina"):
		_once["narina"] = true
		Sfx.play("pedal_creak", -6.0, 0.7)
	_face(opas, _pike_pt(0.5))
	_face(me, _pike_pt(0.5))
	if _t > 0.6:
		_reach(opas, _pike_pt(0.45, 0.0, -0.06), clampf((_t - 0.6) / 0.6, 0.0, 1.0), 0.0)
	if _t > 0.9 and _t < 3.0:
		_bub[opas] = "No niin. Annetaan sen rauhottua."
	if _t < 3.0:
		# Kuva pihalta: Ukko keskellä koko pituudeltaan (kolmijalka, puntari), opas ja pelaaja sivuilla (korkeus 2,4 m).
		var look := _L(TRIPOD.x - 0.1, TRIPOD.y - 0.3, 1.32)
		var eye := _L(0.6, -5.4, 1.6)
		_cam_at(eye, look, _fov_h(eye.distance_to(look), 2.55))
	else:
		_bub.erase(opas)
		# Lähikuva puntarin taulusta: viisari asettuu (taulu n. 1/3 ruudun korkeudesta).
		var dc := scale_dial.global_position
		var fwd := -scale_dial.global_basis.z  # taulun normaali pihalle
		var eye2 := dc + fwd * 0.55 + Vector3(0, -0.04, 0)
		_cam_at(eye2, dc, _fov_h(eye2.distance_to(dc), 0.42))
		if _t > 4.4:
			_story = "Kahdeksantoista pilkku neljä kiloa."
			if not _once.has("lukema"):
				_once["lukema"] = true
				Sfx.play("bell", -10.0, 1.4)


func _step_uistimet(_delta: float) -> void:
	# Opas osoittaa uistimia yksi kerrallaan; lähikuva kyljestä, oppaan käsi ja kasvot reunalla.
	needle.rotation.z = _dial_angle(KG)
	needle_kg = KG
	_hang_pike(0.0)
	var targets := [lures[2], lures[1], lure_isa]
	var k := clampi(int((_t - 0.8) / 1.4), 0, 2)
	var tgt: Vector3 = (targets[k] as Node3D).global_position - _G.global_basis.z * 0.07
	_reach(opas, tgt, clampf((_t - 0.4) / 0.5, 0.0, 1.0), 0.1)
	_face(opas, _pike_pt(0.6))
	_face(me, _pike_pt(0.6))
	if _t < 2.6:
		_bub[opas] = "Sata kolmekymmentäkaksi senttiä."
	else:
		_bub[opas] = "Ja kyljessä kolme vanhaa uistinta. Kuin mitalit."
	if _t > 1.2:
		_story = "Suupielessä Taunon isän kuparilusikka. Kyljessä vanhemmat."
	# Kyljen lähikuva yläviistosta: uistimet ja kuono keskellä (leveys 1,15 m), oppaan pää ja käsi vasemmassa reunassa.
	var look := _pike_pt(0.7) + _G.global_basis.x * 0.15
	var eye := look - _G.global_basis.z * 1.8 - _G.global_basis.x * 0.75 + Vector3(0, 0.1, 0)
	_cam_at(eye, look, _fov_h(eye.distance_to(look), 1.05))


func _step_tauno(_delta: float) -> void:
	needle.rotation.z = _dial_angle(KG)
	_hang_pike(0.0)
	# 0–2,8 Tauno kävelee pihalle ja pysähtyy Ukon viereen. 2,8–5 koskettaa isän lusikkaa.
	# 5–8,6 kääntyy pois pihalle päin, käsi silmille, pää painuu; kyynel valuu poskelle.
	var from := Vector2(4.4, -4.4)
	var to := Vector2(0.3, -1.32)
	var k := clampf(_t / 2.8, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var p := from.lerp(to, e)
	_stand(tauno, p.x, p.y)
	tauno.play("Walk" if k < 1.0 else "Idle", 0.25, 0.8)
	_face(opas, tauno.global_position)
	_face(me, tauno.global_position)
	if k < 1.0:
		_face(tauno, _L(to.x, to.y))
		var look := _L(0.9, -1.9, 1.25)
		var eye := _L(0.4, -6.4, 1.7)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.6))
		if _t > 1.6:
			_bub[tauno] = "...Se on se."
		return
	if _t < 5.0:
		_face(tauno, _pike_pt(0.72))
		tauno.set_override("neck_01", Vector3.RIGHT, 0.18)  # katse ylös Ukkoon
		# Sormet lusikan alle (nostaa sitä kämmenellään), lusikka jää näkyviin.
		_reach(tauno, lure_isa.global_position - _G.global_basis.z * 0.03 + Vector3(0, -0.07, 0), clampf((_t - 3.0) / 0.6, 0.0, 1.0), 0.0)
		if _t > 3.2:
			_bub[tauno] = "Tuo punavalkonen. Isä veisti sen itse. Ukko vei sen kesällä -79."
		# Kuva pihalta vinosti: Ukko ja Tauno, käsi lusikalla (leveys 1,6 m).
		# Kuva pihalta vinosti: Taunon kasvot ja isän lusikka samassa kuvassa (korkeus 1,0 m pään ja lusikan väliltä).
		var th := tauno.to_global(tauno.bone_position("Head"))
		var look2 := (th + lure_isa.global_position) / 2.0 + Vector3(0, -0.05, 0)
		var eye2 := look2 - _G.global_basis.z * 2.1 - _G.global_basis.x * 0.8 + Vector3(0, 0.05, 0)
		_cam_at(eye2, look2, _fov_h(eye2.distance_to(look2), 1.0))
		return
	# Käännös pois ja silmien pyyhintä.
	var turn := clampf((_t - 5.0) / 0.8, 0.0, 1.0)
	var away := _L(to.x + 1.0, to.y - 3.0)  # pois pihalle päin, poispäin muista
	var fwd_pike := _pike_pt(0.72)
	_face(tauno, fwd_pike.lerp(away, turn))
	# Pyyhintä 5,6–6,9 (käsi silmälle), käsi alas 6,9–7,4; sen jälkeen kyynel valuu toisesta silmästä poskelle.
	var wipe := clampf((_t - 5.6) / 0.5, 0.0, 1.0) * (1.0 - clampf((_t - 6.9) / 0.5, 0.0, 1.0))
	var bow := clampf((_t - 5.6) / 0.5, 0.0, 1.0)
	tauno.set_override("neck_01", Vector3.RIGHT, -0.2 * bow)
	tauno.set_override("spine_01", Vector3.RIGHT, -0.08 * bow)
	var hd := tauno.to_global(tauno.bone_position("Head"))
	var sr: Vector3 = tauno.bone_position("upperarm_r")
	var s := signf(sr.x) if sr.x != 0.0 else 1.0
	var eye_pt := hd + tauno.global_basis * Vector3(s * 0.035, 0.06, -0.13)
	_reach(tauno, eye_pt, wipe, 0.0)
	if _t > 7.0:
		var tk := clampf((_t - 7.0) / 1.4, 0.0, 1.0)
		tear.visible = true
		tear_shown = true
		tear.global_position = hd + tauno.global_basis * Vector3(-s * 0.036, 0.055 - 0.065 * tk, -0.118 + 0.012 * tk)
		_streak.visible = true
		var top := hd + tauno.global_basis * Vector3(-s * 0.036, 0.055, -0.117)
		_streak.global_position = (top + tear.global_position) / 2.0
		_streak.global_basis = tauno.global_basis
		_streak.scale = Vector3(0.004, maxf(0.001, top.distance_to(tear.global_position)), 0.003)
	if _t > 6.0:
		_bub[tauno] = "Isä oli oikeassa."
	if _t > 7.0:
		_story = "Tauno itki vähän."
	if not _once.has("niisk"):
		_once["niisk"] = true
		Sfx.play("breath", -8.0, 0.8)
	# Lähikuva Taunon kasvoista edestä vinosti (leveys 0,9 m), Ukon kylki taustalla.
	var look3 := hd + tauno.global_basis * Vector3(-0.02, -0.05, 0.0)
	var eye3 := look3 + tauno.global_basis * Vector3(-0.45, 0.04, -1.2)
	_cam_at(eye3, look3, _fov_w(eye3.distance_to(look3), 0.95))


func _step_kuva(_delta: float) -> void:
	# Tauno ja pelaaja pitelevät Ukkoa vaakatasossa rinnan edessä; Pekka, Arto ja Anna-Liisa tulevat pihalle.
	_hold_pike()
	var paths := {pekka: [Vector2(4.8, -3.6), Vector2(1.55, -1.5), 0.0, 2.4],
		arto: [Vector2(-5.4, -3.2), Vector2(-1.25, -1.25), 0.2, 2.6],
		annaliisa: [Vector2(-5.8, -5.2), PHOTO, 0.3, 2.6]}
	for c: Node3D in paths:
		var pth: Array = paths[c]
		var k := clampf((_t - float(pth[2])) / float(pth[3]), 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var p: Vector2 = (pth[0] as Vector2).lerp(pth[1], e)
		_stand(c, p.x, p.y)
		c.play("Walk" if k > 0.0 and k < 1.0 else "Idle", 0.2)
		_face(c, _L(p.x + (pth[1].x - pth[0].x), p.y + (pth[1].y - pth[0].y)) if k < 1.0 else _pike_pt(0.5))
	_face(opas, _pike_pt(0.5))
	if _t > 1.2 and _t < 3.2:
		_bub[pekka] = "Kahdeksantoista kiloa, perkele."
	elif _t >= 3.2 and _t < 5.0:
		_bub.erase(pekka)
		_bub[arto] = "No ei se tuuli ollukkaan. Anteeks, Tauno."
	elif _t >= 5.0:
		_bub.erase(arto)
		_bub[annaliisa] = "Kuva lehteen! Hymyä, Tauno."
	# Anna-Liisa nostaa puhelimen kuvatakseen (käsi silmien edessä, näyttö kohti häntä).
	if _t > 4.6:
		_face(annaliisa, _pike_pt(0.5))
		var hd := annaliisa.to_global(annaliisa.bone_position("Head"))
		var ph := hd + annaliisa.global_basis * Vector3(0.0, -0.06, -0.32)
		_reach(annaliisa, ph, clampf((_t - 4.6) / 0.5, 0.0, 1.0), 0.0)
		phone.visible = true
		phone.global_position = _hand(annaliisa) + annaliisa.global_basis * Vector3(0, 0.05, -0.02)
		phone.global_rotation = Vector3(0, annaliisa.global_rotation.y, 0)
	if _t > 6.4 and not flashed:
		flashed = true
		_flash = 1.0
		_flash_light.global_position = phone.global_position
		Sfx.play("pickup", -2.0, 1.6)
	# Leveä kuva pihalta Anna-Liisan takaa: Ukko vaakatasossa keskellä, kaikki hahmot kuvassa (leveys 4,6 m).
	var look := _L(0.0, -1.5, 1.2)
	var eye := _L(0.9, -7.6, 1.85)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.6))


func _step_otsikko(_delta: float) -> void:
	# Lehtikuva: Tauno ja pelaaja Ukon kanssa suoraan edestä, kaikki katsovat kameraan.
	_hold_pike()
	var cam_pos := _L(PHOTO.x, PHOTO.y, 1.5)
	for c in [pekka, arto, opas]:
		_face(c, cam_pos)
	if _t < 0.05:
		_flash = 1.0
	# Anna-Liisan puhelimen kuva: ryhmä suoraan edestä (leveys 3,9 m), Ukko keskellä.
	var look := _L(0.0, -1.35, 1.12)
	_cam_at(cam_pos, look, _fov_w(cam_pos.distance_to(look), 3.9))


# --- Ukko, kädet ---------------------------------------------------------------------

## Ukko roikkuu puntarin koukussa leuastaan (kuono ylhäällä), heilahdus swing (rad) koukun ympäri pihan x-suunnassa.
func _hang_pike(swing: float) -> void:
	var gb := _G.global_basis
	var bas := Basis(gb.y, -gb.x, gb.z)  # hauen +X ylös, +Y (selkä) pihan -x, +Z Pirttiä kohti (kylki -Z pihalle)
	bas = Basis(gb.z, swing) * bas
	var hook := _L(TRIPOD.x, TRIPOD.y, 0.0)
	hook.y = T.h(hook.x, hook.z) + HOOK_Y + 0.2 - 0.25
	pike.global_basis = bas
	pike.global_position = hook - bas * Vector3(LEN * 0.47, 0, 0)


## Ukko vaakatasossa Taunon ja pelaajan välissä (kuono Taunon puolella, pihan +x), kylki uistimineen kameraan.
## Kädet hauen vatsan alle olkapäiden eteen (HOLD_U): Taunon kädet kiduksilla ja keskellä, pelaajan pyrstön tyvellä.
func _hold_pike() -> void:
	var gb := _G.global_basis
	pike.global_basis = Basis(gb.x, gb.y, gb.z).rotated(gb.z, 0.04)
	var c := _L(0.0, HOLD_Z - 0.32)
	c.y = T.h(c.x, c.z) + 1.15
	pike.global_position = c
	for ch in [tauno, me]:
		_face(ch, _L(_G.to_local(ch.global_position).x, PHOTO.y))  # suoraan kameraan: olkapäät samalla etäisyydellä
	_hold2(tauno, _pike_pt(HOLD_U[0], -1.0), _pike_pt(HOLD_U[1], -1.0))
	_hold2(me, _pike_pt(HOLD_U[2], -1.0), _pike_pt(HOLD_U[3], -1.0))


## Piste hauen pinnalla: u pituudella (0 = pyrstön tyvi, 1 = kuono), side -1 = vatsa, 0 = kylki (-Z), +1 = selkä;
## dz lisää kyljen suuntaan.
func _pike_pt(u: float, side := 0.0, dz := 0.0) -> Vector3:
	var hw := _pike_wh(u)
	var x := -LEN * 0.42 + u * LEN * 0.92
	var a := side * PI / 2.0
	return pike.to_global(Vector3(x, sin(a) * (hw.x + 0.012), -cos(a) * hw.y + dz))


## Molemmat kädet kahteen pisteeseen: kumpikin käsi oman puolensa pisteeseen, kyynärpäät ulos ja alas.
func _hold2(c: Node3D, pa: Vector3, pb: Vector3) -> void:
	var la := c.to_local(pa)
	var lb := c.to_local(pb)
	var sr: Vector3 = c.bone_position("upperarm_r")
	var sl: Vector3 = c.bone_position("upperarm_l")
	if (la.x - lb.x) * (sr.x - sl.x) < 0.0:  # oikea käsi sille puolelle, jolla oikea olkapää on
		var tmp := la
		la = lb
		lb = tmp
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", la, sr + Vector3(signf(sr.x) * 0.35, -0.35, 0.15))
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", lb, sl + Vector3(signf(sl.x) * 0.35, -0.35, 0.15))


func _relax(c: Node3D) -> void:
	c.set_override("spine_01", Vector3.RIGHT, 0.0)
	c.set_override("neck_01", Vector3.RIGHT, 0.0)


func _stand(c: Node3D, x: float, z: float) -> void:
	c.global_position = _L(x, z)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.global_position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


func _hand(c: Node3D) -> Vector3:
	return c.to_global((c.bone_position("hand_r") + c.bone_position("index_01_r")) / 2.0)


func _hand_l(c: Node3D) -> Vector3:
	return c.to_global((c.bone_position("hand_l") + c.bone_position("index_01_l")) / 2.0)


## Oikea käsi kohti pistettä (w 0..1); lean kumartaa selkää (rad) samassa suhteessa.
func _reach(c: Node3D, at_global: Vector3, w: float, lean := 0.0) -> void:
	if lean != 0.0:
		c.set_override("spine_01", Vector3.RIGHT, -lean * w)
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at_global), w)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", tgt, sh + Vector3(s * 0.45, -0.25, 0.25))


# --- Kehys, kamera ------------------------------------------------------------------

## Pihan piste (x, z) maanpinnalla + y.
func _L(x: float, z: float, y := 0.0) -> Vector3:
	var p := _G.to_global(Vector3(x, 0.0, z))
	return Vector3(p.x, T.h(p.x, p.z) + y, p.z)


func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(eye, look)


## Pystykenttä, jolla leveys w mahtuu ruudun leveyteen etäisyydellä d.
func _fov_w(d: float, w: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return rad_to_deg(2.0 * atan(w / (2.0 * d) / (vs.x / vs.y)))


## Pystykenttä, jolla korkeus h mahtuu ruutuun etäisyydellä d.
func _fov_h(d: float, h: float) -> float:
	return rad_to_deg(2.0 * atan(h / (2.0 * d)))


# --- Piirto -------------------------------------------------------------------------

func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 440, 24, 880, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for c: Node3D in _bub:
		if is_instance_valid(c) and c.visible:
			Room.bubble(_ui, _cam, c, _bub[c], 90.0, 120.0)
	if _flash > 0.0:
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, 0.85 * _flash * _flash))
	if phase == "otsikko":
		var a := clampf((_t - 0.9) / 0.9, 0.0, 1.0)
		# Lehtikuvan reunus: harmahtava sanomalehtipaperin kehys ja kuvateksti.
		var m := 26.0
		var paper := Color(0.9, 0.88, 0.82, 0.9 * a)
		_ui.draw_rect(Rect2(0, 0, vs.x, m), paper)
		_ui.draw_rect(Rect2(0, vs.y - m, vs.x, m), paper)
		_ui.draw_rect(Rect2(0, 0, m, vs.y), paper)
		_ui.draw_rect(Rect2(vs.x - m, 0, m, vs.y), paper)
		var y := vs.y * 0.16
		var title := "TEKOJÄRVEN UKKO"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 64, 12, Color(0.05, 0.08, 0.04, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 64, Color(0.95, 0.9, 0.6, a))
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 160.0, 840, 84)
		_ui.draw_rect(sr, Color(0.04, 0.05, 0.04, 0.78 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "18,4 kg · 132 cm · kyljessä kolme vanhaa uistinta",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.85, 0.9, 0.6, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Täytetään Saloisten Pirttiin. Tauno itki vähän.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))
