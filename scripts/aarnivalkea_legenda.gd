extends CanvasLayer
## Legendaarinen hetki "aarnivalkea" (Isonvihan hopeat): kun Lapinraunion hopeat viedään ensimmäistä kertaa Saloisten
## Pirttiin (main.gd _aarni_museum), hetki lavastetaan Pirtin pihalla. Vaiheet:
##   kontti   pihapöydällä sammaleinen tuohikontti, Pirtin opas lukee käräjäpöytäkirjaa ("kivien alle, sammalen sekaan")
##   kansi    opas nostaa kannen: kontista lehahtaa viimeinen sininen liekki, joka lepattaa ja sammuu (kansanperinne:
##            aarnivalkea sammuu, kun aarre nostetaan); opas ja pelaaja hätkähtävät taaksepäin
##   hopeat   rahat, lusikat ja pikari liinalle; opas nostaa taalerin valoon (välähdys) ja vertaa pöytäkirjaan: "Juuri nämä!"
##   hilkka   Mummo Hilkka tulee pihalle, perässä epäilijät Arto, Anna-Liisa ja Pekka: "No? Mitäs minä sanoin."
##   otsikko  Pekka tarjoaa kierroksen; ISONVIHAN HOPEAT, Hilkka oli oikeassa
## Kehys: pihan solmu G Pirtin oven edustalla (world.museum_door), paikallinen -Z = ulos pihalle (julkisivun normaali
## world.museum_nrm), +Z = Pirtin seinälle (seinä z = +2). Hahmojen etu -Z (Looks). Maan korkeus Terrain.h:sta.
## Hopeat jäävät museoon (eivät jää pihalle). Hilkka muistelee myöhemmin (main.gd _talk_kirppis "aarni_muisto").

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const T := preload("res://scripts/terrain.gd")

const DUR := {"kontti": 5.0, "kansi": 5.8, "hopeat": 6.2, "hilkka": 6.8, "otsikko": 6.4}
const ORDER := ["kontti", "kansi", "hopeat", "hilkka", "otsikko"]
const TABLE := Vector2(0.0, -0.5)  # pöydän keskusta (pitkä sivu x-suunnassa)
const TABLE_SIZE := Vector3(1.5, 0.76, 0.75)
const KONTTI_AT := Vector2(-0.38, -0.36)  # pöydän oikea takakulma kuvassa (+x näkyy pihalta katsoen vasemmalla)
## Hilkka (kirppis_interior.gd PEOPLE): harmaa nuttura, luumunvärinen neule.
const HILKKA := {"model": "female", "shirt": Color(0.55, 0.3, 0.45), "pants": Color(0.25, 0.22, 0.3), "shoes": Color(0.3, 0.25, 0.2),
	"shoe": "kavelykenka", "hair": "Hair_Buns", "hair_color": Color(0.85, 0.85, 0.85), "height": 1.58, "skin": Color(0.95, 0.8, 0.74),
	"belly": 0.4}
## Pirtin opas: harmaa tukka, pyöreät lasit, ruskea tweedtakki.
const OPAS := {"shirt": Color(0.42, 0.3, 0.2), "pants": Color(0.28, 0.27, 0.25), "shoes": Color(0.2, 0.13, 0.08), "shoe": "kavelykenka",
	"hair": "Hair_SimpleParted", "hair_color": Color(0.78, 0.78, 0.76), "height": 1.74, "skin": Color(0.96, 0.8, 0.7), "belly": 0.6, "muscle": -0.8, "shoulders": -0.3,
	"round_glasses": true}
## Hilkka muistelee myöhemmin (main.gd _talk_kirppis "aarni_muisto").
const MUISTO := ["Se liekki, kun opas nosti kannen! Sininen, ihan niinku mummo kerto. Ja sitte se sammu. Mää tiesin.",
	"Arto tuli eilen kirppikselle ja osti liinan. Ei sanonu mitään. Mää tiedän, mitä se tarkotti.",
	"Lehdessä oli kuva. Mää leikkasin sen jääkaapin oveen, ihan mummon kuvan viereen.",
	"Mää näin sen tyttönä, ja sää näit sen Pirtin pihalla. Nyt meitä on kaks."]

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
var hilkka: Node3D
var arto: Node3D
var annaliisa: Node3D
var pekka: Node3D
var kontti: Node3D
var lid: Node3D  # kannen sarana (takareuna)
var flame: Node3D
var _flame_light: OmniLight3D
var _flame_core: MeshInstance3D
var _tongues: Array[Node3D] = []
var _sparks: CPUParticles3D
var paper: Node3D  # käräjäpöytäkirja
var held_coin: Node3D
var coins: Array[Node3D] = []
var spoons: Array[Node3D] = []
var pikari: Node3D
var _table_y := 0.0
var flame_peak := 0.0  # liekin suurin korkeus (testi lukee)
var _glint := 0.0


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
	_begin("kontti")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	var tc := _L(TABLE.x, TABLE.y)
	_table_y = tc.y + TABLE_SIZE.y
	_build_table()
	kontti = _build_kontti()
	kontti.global_position = _top(KONTTI_AT.x, KONTTI_AT.y)
	kontti.rotation.y = _G.global_rotation.y
	flame = _build_flame()
	flame.global_position = _top(KONTTI_AT.x, KONTTI_AT.y, 0.26)
	flame.scale = Vector3.ONE * 0.001
	flame.visible = false
	paper = _build_paper()
	held_coin = _coin(world)
	held_coin.visible = false
	_props.append(held_coin)
	# Rahat, lusikat ja pikari (näkyviin hopeat-vaiheessa).
	var spots := [Vector2(0.06, -0.62), Vector2(0.11, -0.6), Vector2(0.09, -0.66), Vector2(0.16, -0.64), Vector2(0.04, -0.7),
		Vector2(0.2, -0.58), Vector2(0.14, -0.72), Vector2(0.23, -0.68), Vector2(0.01, -0.56), Vector2(0.27, -0.62),
		Vector2(0.1, -0.53), Vector2(0.19, -0.76)]
	for i in spots.size():
		spots[i] += Vector2(0.07, 0.0)
	for i in spots.size():
		var c := _coin(world)
		_props.append(c)
		var s: Vector2 = spots[i]
		c.set_meta("at", s)
		c.set_meta("lift", 0.002 + 0.004 * (i % 3))
		c.visible = false
		coins.append(c)
	for i in 5:
		var sp := _spoon()
		sp.set_meta("at", Vector2(-0.24 + i * 0.055, -0.74))
		sp.visible = false
		spoons.append(sp)
	pikari = _pikari()
	pikari.visible = false
	# Hahmot.
	opas = _person(OPAS, -0.2, 0.12)
	me = _person(Looks.player(), 1.1, -0.6)
	hilkka = _person(HILKKA, -5.0, -2.6)
	Looks.hunch(hilkka, 0.2)
	arto = _person(Looks.ARTO, -6.0, -2.2)
	annaliisa = _person(Looks.ANNA_LIISA, -6.2, -3.0)
	pekka = _person(Looks.PEKKA, 5.4, -2.2)
	for c in [hilkka, arto, annaliisa, pekka]:
		c.visible = false
	_face(opas, _L(0, -2.0))
	_face(me, _L(TABLE.x, TABLE.y))
	# Lämmin lamppu oven päällä (iltaisin piha on valaistu).
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.1
	lamp.omni_range = 7.0
	world.add_child(lamp)
	_props.append(lamp)
	lamp.global_position = _L(0.0, 1.6, 2.6)


func _build_table() -> void:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	g.global_position = Vector3(_L(TABLE.x, TABLE.y).x, _table_y, _L(TABLE.x, TABLE.y).z)
	g.rotation.y = _G.global_rotation.y
	var wood := Color(0.55, 0.38, 0.22)
	var sx := TABLE_SIZE.x
	var sz := TABLE_SIZE.z
	# Kansi: kolme lankkua syineen, tummempi reuna.
	for i in 3:
		var pz := (i - 1) * sz / 3.0
		B.mesh(g, B.boxm(Vector3(sx, 0.035, sz / 3.0 - 0.008)), Vector3(0, -0.018, pz), wood.lightened(0.04 * i))
		for k in 3:
			B.mesh(g, B.boxm(Vector3(sx * (0.5 + 0.15 * k), 0.002, 0.004)), Vector3(0.1 * (k - 1), 0.0005, pz + 0.05 * (k - 1)), wood.darkened(0.25))
	# Pukkijalat (X) ja poikkipuu: jalat ulottuvat maahan saakka joka kulmassa.
	for x in [-sx / 2.0 + 0.15, sx / 2.0 - 0.15]:
		for side in [-1.0, 1.0]:
			var foot := g.to_global(Vector3(x, 0, side * sz * 0.42))
			var fy := T.h(foot.x, foot.z)
			var h := _table_y - 0.035 - fy
			var leg := B.mesh(g, B.boxm(Vector3(0.05, h / cos(0.28), 0.05)), Vector3(x, -0.035 - h / 2.0, side * sz * 0.22), wood.darkened(0.15))
			leg.rotation.x = side * 0.28
		B.mesh(g, B.boxm(Vector3(0.05, 0.05, sz * 0.5)), Vector3(x, -0.3, 0), wood.darkened(0.2))
	B.mesh(g, B.boxm(Vector3(sx - 0.3, 0.05, 0.05)), Vector3(0, -0.3, 0), wood.darkened(0.2))
	# Valkoinen pellavaliina, reunat roikkuvat.
	var cloth := Color(0.95, 0.93, 0.86)
	B.mesh(g, B.boxm(Vector3(sx * 0.62, 0.004, sz + 0.06)), Vector3(0.05, 0.002, 0), cloth)
	for side in [-1.0, 1.0]:
		B.mesh(g, B.boxm(Vector3(sx * 0.62, 0.16, 0.004)), Vector3(0.05, -0.078, side * (sz / 2.0 + 0.03)), cloth.darkened(0.06))
	for k in 6:  # pitsireunus
		B.mesh(g, B.boxm(Vector3(0.04, 0.012, 0.005)), Vector3(-0.38 + k * 0.17, -0.16, -(sz / 2.0 + 0.032)), cloth.darkened(0.15))


## Tuohikontti: tuohisuikaleista vinoon punottu laatikko (vaalea tuohi, tummat linssit, ristikkäiset suikaleet),
## puinen kansi saranoituna takareunaan, sammaltupsuja kyljissä.
func _build_kontti() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var w := 0.34
	var h := 0.26
	var d := 0.24
	var tuohi := Color(0.86, 0.74, 0.52)
	# Punos: vinoon palmikoitu tuohi tekstuurina (triplanar, ei BoxMeshin atlas-UV:tä), joten suikaleet eivät pistä
	# laatikon reunojen yli.
	var body := B.mesh(g, B.boxm(Vector3(w, h, d)), Vector3(0, h / 2.0, 0), Color.WHITE)
	var bm := StandardMaterial3D.new()
	bm.albedo_texture = _tuohi_tex()
	bm.uv1_triplanar = true
	bm.uv1_scale = Vector3(4.2, 4.2, 4.2)
	bm.roughness = 0.85
	body.material_override = bm
	# Yläreunan vanne ja kantohihnan lenkit.
	B.mesh(g, B.boxm(Vector3(w + 0.012, 0.03, d + 0.012)), Vector3(0, h - 0.015, 0), tuohi.darkened(0.3))
	B.mesh(g, B.boxm(Vector3(w + 0.012, 0.02, d + 0.012)), Vector3(0, 0.01, 0), tuohi.darkened(0.35))  # pohjavanne
	for x in [-0.1, 0.1]:
		var loop := B.mesh(g, B.boxm(Vector3(0.025, 0.12, 0.012)), Vector3(x, h * 0.55, d / 2.0 + 0.01), Color(0.4, 0.28, 0.16))
		loop.rotation.x = 0.1
	# Sammaltupsut ja multaa (kontti oli sammalen alla).
	var moss := Color(0.32, 0.45, 0.18)
	for m in [Vector3(-0.16, 0.05, -0.1), Vector3(0.17, 0.2, 0.06), Vector3(0.05, 0.02, -0.12), Vector3(-0.17, 0.17, 0.08), Vector3(0.12, 0.27, -0.06)]:
		var b := B.mesh(g, B.sphere(0.5, 8), m, moss.lightened(randf_range(-0.05, 0.1)))
		b.scale = Vector3(0.06, 0.03, 0.05)
	# Kansi: sarana takareunassa (+Z paikallisesti = kohti Pirttiä; opas avaa sen itseään kohti).
	lid = Node3D.new()
	lid.position = Vector3(0, h, d / 2.0)
	g.add_child(lid)
	var lw := Color(0.5, 0.36, 0.2)
	B.mesh(lid, B.boxm(Vector3(w + 0.02, 0.025, d + 0.02)), Vector3(0, 0.0125, -d / 2.0), lw)
	for k in 3:
		B.mesh(lid, B.boxm(Vector3(w, 0.002, 0.004)), Vector3(0, 0.026, -d / 2.0 + (k - 1) * 0.06), lw.darkened(0.3))
	var mm := B.mesh(lid, B.sphere(0.5, 8), Vector3(0.07, 0.03, -d * 0.6), moss)
	mm.scale = Vector3(0.09, 0.025, 0.07)
	# Sisältä tumma (hopeat mustuneina pohjalla).
	B.mesh(g, B.boxm(Vector3(w - 0.02, 0.01, d - 0.02)), Vector3(0, h - 0.04, 0), Color(0.12, 0.1, 0.08))
	for i in 6:
		var c := _coin(g)
		c.position = Vector3(-0.1 + i * 0.04, h - 0.032, 0.03 * sin(i * 2.1))
	return g


## Vinopunos: kaksi 45° suikalesuuntaa vuorotellen päällä (päällimmäinen vaaleampi, reunat tummuvat), tuohen
## tummat linssit vaakaviivoina. 128 px = 8 suikaletta.
static func _tuohi_tex() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var base := Color(0.86, 0.75, 0.53)
	var sw := 16.0 * sqrt(2.0)  # suikaleen leveys diagonaalina
	for y in n:
		for x in n:
			var u := float(x + y) / sw
			var v := float(x - y + n) / sw
			var i := int(floor(u))
			var j := int(floor(v))
			var a_on_top := (i + j) % 2 == 0
			var fu := u - i
			var fv := v - j
			var edge := minf(minf(fu, 1.0 - fu), minf(fv, 1.0 - fv))
			var c := base.lightened(0.08) if a_on_top else base.darkened(0.12)
			var along := fu if a_on_top else fv  # suikaleen poikkisuunta
			c = c.darkened(0.35 * (1.0 - smoothstep(0.0, 0.12, edge)))
			c = c.darkened(0.08 * absf(along - 0.5))
			if (x * 7 + y * 13) % 97 < 3 and y % 9 < 1:
				c = Color(0.3, 0.22, 0.15)  # linssi
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Sininen liekki: läpikuultava kartio, kirkas sisäliekki, leijuvat kipinät ja sininen valo (kuten main.gd _aarni_nodes).
func _build_flame() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	# Kielekkeet: venytetyt pallot additiivisesti (päällekkäin kirkastuvat kuin tuli), keskellä valkoinen ydin.
	var add := func(col: Color) -> StandardMaterial3D:
		var m := B.unshaded(col)
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = false
		return m
	for k in 6:
		var tongue := Node3D.new()
		var ang := k * TAU / 6.0
		tongue.position = Vector3(cos(ang) * 0.05, 0.0, sin(ang) * 0.05)
		g.add_child(tongue)
		var mi := B.mesh(tongue, B.sphere(0.5, 12), Vector3(0, 0.2, 0), Color.WHITE)
		mi.scale = Vector3(0.13, 0.46, 0.13) * (0.8 + 0.12 * (k % 3))
		mi.material_override = add.call(Color(0.18, 0.38, 1.0, 0.75))
		tongue.set_meta("ang", ang)
		_tongues.append(tongue)
	_flame_core = B.mesh(g, B.sphere(0.5, 12), Vector3(0, 0.13, 0), Color.WHITE)
	_flame_core.scale = Vector3(0.1, 0.26, 0.1)
	_flame_core.material_override = add.call(Color(0.7, 0.85, 1.0, 0.9))
	var tip_n := Node3D.new()  # animaatio skaalaa solmua, ei verkkoa (verkon oma skaala säilyy)
	g.add_child(tip_n)
	var tip := B.mesh(tip_n, B.sphere(0.5, 10), Vector3(0.0, 0.5, 0), Color.WHITE)
	tip.scale = Vector3(0.07, 0.28, 0.07)
	tip.material_override = add.call(Color(0.2, 0.4, 1.0, 0.6))
	_tongues.append(tip_n)
	_sparks = CPUParticles3D.new()
	_sparks.amount = 30
	_sparks.lifetime = 1.4
	_sparks.direction = Vector3.UP
	_sparks.spread = 30.0
	_sparks.initial_velocity_min = 0.3
	_sparks.initial_velocity_max = 0.9
	_sparks.gravity = Vector3(0, 0.25, 0)
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 0.1
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	sm.material = B.unshaded(Color(0.6, 0.82, 1.0, 0.95))
	_sparks.mesh = sm
	_sparks.position = Vector3(0, 0.3, 0)
	g.add_child(_sparks)
	_flame_light = OmniLight3D.new()
	_flame_light.light_color = Color(0.4, 0.6, 1.0)
	_flame_light.light_energy = 0.0
	_flame_light.omni_range = 4.0
	_flame_light.position = Vector3(0, 0.35, 0)
	g.add_child(_flame_light)
	return g


## Käräjäpöytäkirjan jäljennös: kellastunut arkki, tummat tekstirivit ja punainen sinetti.
func _build_paper() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	B.mesh(g, B.boxm(Vector3(0.21, 0.002, 0.29)), Vector3.ZERO, Color(0.9, 0.82, 0.6))
	B.mesh(g, B.boxm(Vector3(0.17, 0.001, 0.012)), Vector3(0, 0.0015, -0.12), Color(0.3, 0.2, 0.12))  # otsikko
	for k in 11:
		B.mesh(g, B.boxm(Vector3(0.17 - 0.04 * float(k % 3 == 2), 0.001, 0.004)), Vector3(-0.02 * float(k % 3 == 2), 0.0015, -0.09 + k * 0.017), Color(0.32, 0.24, 0.16))
	var seal := B.mesh(g, B.cyl(0.018, 0.018, 0.004, 14), Vector3(0.06, 0.003, 0.11), Color(0.7, 0.1, 0.08))
	seal.name = "sinetti"
	return g


## Mustunut hopeataaleri: kiekko, vaaleampi kohokuva ja reuna, metallinen kiilto.
func _coin(parent: Node3D) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.5, 0.48)
	m.metallic = 0.85
	m.roughness = 0.35
	var body := B.mesh(g, B.cyl(0.02, 0.02, 0.004, 16), Vector3(0, 0.002, 0), Color.WHITE)
	body.material_override = m
	var rim := B.mesh(g, B.cyl(0.0205, 0.0205, 0.0035, 16), Vector3(0, 0.0018, 0), Color(0.28, 0.28, 0.27))  # tumma reuna
	rim.scale = Vector3(1, 1, 1)
	body.scale = Vector3(0.94, 1.15, 0.94)
	var relief := B.mesh(g, B.cyl(0.011, 0.011, 0.0012, 10), Vector3(0.002, 0.0044, 0), Color(0.78, 0.77, 0.72))
	relief.scale = Vector3(1, 1, 0.8)
	var tarn := B.mesh(g, B.cyl(0.02, 0.02, 0.001, 16), Vector3(0, 0.0042, 0), Color(0.2, 0.2, 0.2))
	tarn.scale = Vector3(0.55, 1, 0.4)
	tarn.position.x = -0.006
	return g


## Hopealusikka: soikea kauha ja kapea varsi, varren päässä nuppi; mustumaa kauhan pohjassa.
func _spoon() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.7, 0.68)
	m.metallic = 0.9
	m.roughness = 0.3
	var bowl := B.mesh(g, B.sphere(0.5, 12), Vector3(0, 0.006, -0.055), Color.WHITE)
	bowl.scale = Vector3(0.036, 0.012, 0.052)
	bowl.material_override = m
	var handle := B.mesh(g, B.boxm(Vector3(0.008, 0.004, 0.11)), Vector3(0, 0.004, 0.025), Color.WHITE)
	handle.material_override = m
	var knob := B.mesh(g, B.sphere(0.5, 8), Vector3(0, 0.005, 0.083), Color.WHITE)
	knob.scale = Vector3(0.016, 0.007, 0.02)
	knob.material_override = m
	var dark := B.mesh(g, B.sphere(0.5, 8), Vector3(0.004, 0.009, -0.05), Color(0.25, 0.24, 0.22))
	dark.scale = Vector3(0.018, 0.004, 0.026)
	return g


## Hopeapikari: kuppi, varsi ja jalka, kiiltävä reunus.
func _pikari() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.66, 0.66, 0.63)
	m.metallic = 0.9
	m.roughness = 0.28
	for part in [[B.cyl(0.045, 0.05, 0.008, 16), 0.004], [B.cyl(0.012, 0.016, 0.06, 10), 0.038], [B.sphere(0.5, 10), 0.07],
			[B.cyl(0.05, 0.035, 0.08, 16), 0.11]]:
		var mi := B.mesh(g, part[0], Vector3(0, part[1], 0), Color.WHITE)
		mi.material_override = m
		if part[0] is SphereMesh:
			mi.scale = Vector3(0.035, 0.025, 0.035)
	B.mesh(g, B.cyl(0.052, 0.052, 0.006, 16), Vector3(0, 0.148, 0), Color(0.82, 0.82, 0.78))
	var inside := B.mesh(g, B.cyl(0.045, 0.045, 0.002, 16), Vector3(0, 0.146, 0), Color(0.15, 0.14, 0.13))
	inside.scale = Vector3(1, 1, 1)
	B.mesh(g, B.boxm(Vector3(0.03, 0.03, 0.002)), Vector3(0, 0.11, -0.046), Color(0.3, 0.3, 0.28))  # mustunut kaiverrus
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
	for c in [me, opas, hilkka, arto, annaliisa, pekka]:
		c.clear_ik()
		_relax(c)
	match p:
		"kontti":
			_story = "Saloisten Pirtin piha. Tuohikontti sammalen alta pöydälle."
		"kansi":
			_story = ""
			_stand(opas, -0.2, 0.12)
			_paper_on_table()
		"hopeat":
			_story = "Aarnivalkea sammui. Aarre on nostettu."
			_lid_aside()
			flame.visible = false
			_stand(opas, -0.2, 0.12)
			_stand(me, 1.1, -0.6)
			_paper_on_table()
		"hilkka":
			_story = ""
			_show_silver(1.0)
			_lid_aside()
			for c in [hilkka, arto, annaliisa, pekka]:
				c.visible = true
		"otsikko":
			_story = ""
			_show_silver(1.0)
			_lid_aside()
			flame.visible = false
			held_coin.visible = false
			for c in [hilkka, arto, annaliisa, pekka]:
				c.visible = true
				c.play("Idle", 0.2)
			_stand(hilkka, -1.05, -1.1)
			_stand(arto, -1.55, 0.4)
			_stand(annaliisa, -1.85, -0.25)
			_stand(pekka, 1.7, 0.45)
			_stand(opas, -0.2, 0.12)
			_stand(me, 1.1, -0.6)
			Sfx.play("win", -6.0, 0.95)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa E-painalluksesta Pirtin ovella: sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "kontti" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"kontti":
			_step_kontti(delta)
		"kansi":
			_step_kansi(delta)
		"hopeat":
			_step_hopeat(delta)
		"hilkka":
			_step_hilkka(delta)
		"otsikko":
			_step_otsikko(delta)
	_glint = maxf(0.0, _glint - delta * 1.6)
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


func _step_kontti(_delta: float) -> void:
	# Opas lukee pöytäkirjaa kädessään, pelaaja odottaa kontin vieressä.
	_hold_paper(opas, 1.0)
	_face(opas, _top(0, -0.6))
	_face(me, _top(KONTTI_AT.x, KONTTI_AT.y))
	if _t > 1.0:
		_bub[opas] = "Käräjäpöytäkirja sanoo: \"kivien alle, sammalen sekaan\"."
	if _t > 3.4:
		_bub[opas] = "Ja tuohikontissa. No, katsotaanpa."
	# Kuva pihalta vinosti: kontti pöydällä keskellä, opas sen takana, pelaaja oikealla (leveys 2,6 m).
	var look := _L(0.05, -0.25, 1.22)
	var eye := _L(-1.3, -3.4, 1.85)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.0))


func _step_kansi(delta: float) -> void:
	# Opas laskee paperin, kurottaa kanteen ja nostaa sen. Liekki lehahtaa (1,45 s), lepattaa ja sammuu (3,7 s).
	var at := _top(KONTTI_AT.x, KONTTI_AT.y + 0.1, 0.27)
	var r := clampf((_t - 0.5) / 0.7, 0.0, 1.0)
	if _t < 1.45:
		_reach(opas, at, r, 0.3)
		lid.rotation.x = 1.9 * clampf((_t - 1.1) / 0.35, 0.0, 1.0)
	else:
		lid.rotation.x = 1.9
	var t0 := 1.45
	var t1 := 3.7
	if _t >= t0 and _t < t1 + 0.5:
		flame.visible = true
		var k := (_t - t0) / (t1 - t0)
		var grow := clampf((_t - t0) / 0.25, 0.0, 1.0)
		var fade := 1.0 - clampf((k - 0.35) / 0.65, 0.0, 1.0)
		var flick := 0.85 + 0.15 * sin(_t * 31.0) * sin(_t * 7.0)
		var sc := maxf(0.001, grow * fade * flick)
		flame.scale = Vector3(1.0, 1.0 + 0.2 * sin(_t * 19.0), 1.0) * sc
		for ti in _tongues.size():
			var tg := _tongues[ti]
			var ph := ti * 1.7
			tg.rotation = Vector3(0.25 * sin(_t * 9.0 + ph), 0.0, 0.25 * cos(_t * 11.0 + ph))
			tg.scale = Vector3(1.0, 0.8 + 0.35 * absf(sin(_t * 13.0 + ph)), 1.0)
		flame_peak = maxf(flame_peak, sc * 0.75)
		_flame_light.light_energy = 5.0 * grow * fade
		_sparks.emitting = fade > 0.05
		if not _once.has("liekki"):
			_once["liekki"] = true
			Sfx.play("whoosh", -2.0, 0.55)
			Sfx.play("fire", -10.0, 0.7)
		if fade <= 0.0 and not _once.has("sammui"):
			_once["sammui"] = true
			Sfx.play("whoosh", -12.0, 1.6)
		# Hätkähdys: opas ja pelaaja nojaavat taaksepäin ja ottavat askeleen.
		var jump := clampf((_t - t0) / 0.25, 0.0, 1.0) * (1.0 - clampf((_t - 3.2) / 1.0, 0.0, 1.0))
		opas.clear_ik()
		_stand(opas, -0.2, 0.12 + 0.28 * jump)
		opas.set_override("spine_01", Vector3.RIGHT, 0.28 * jump)
		_stand(me, 1.1 + 0.25 * jump, -0.6 - 0.1 * jump)
		me.set_override("spine_01", Vector3.RIGHT, 0.22 * jump)
		_hands_up(opas, jump)
	else:
		flame.visible = false
		_flame_light.light_energy = 0.0
	if _t > 1.9 and _t < 3.9:
		_bub[opas] = "Herranen aika!"
	elif _t >= 3.9:
		_bub.erase(opas)
		_story = "Aarnivalkea sammuu, kun aarre nostetaan. Niin Hilkan mummo kertoi."
	_face(me, _top(KONTTI_AT.x, KONTTI_AT.y))
	_face(opas, _top(KONTTI_AT.x, KONTTI_AT.y))
	# Lähempi kuva: kontti ja liekki keskellä, oppaan kasvot ja pelaaja reunoilla (leveys 2,0 m).
	var look := _top(0.2, -0.2, 0.52)
	var eye := _L(-1.3, -2.8, 1.75)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.0))


func _step_hopeat(_delta: float) -> void:
	# Rahat ja lusikat liinalle (näkyviin vähitellen), opas nostaa taalerin valoon ja vertaa pöytäkirjaan.
	_show_silver(clampf((_t - 0.2) / 1.6, 0.0, 1.0))
	if _t < 2.0:
		_hold_paper(opas, 0.0)
		_stand(opas, 0.1, 0.12)
		var rw := clampf((_t - 0.2) / 0.5, 0.0, 1.0) * (1.0 - clampf((_t - 1.6) / 0.4, 0.0, 1.0) * 0.0)
		_reach(opas, _top(0.12, -0.52, 0.03), rw, 0.45)
		held_coin.visible = false
	else:
		# Taaleri silmien korkeudelle valoa vasten.
		var lift := clampf((_t - 2.0) / 0.7, 0.0, 1.0)
		var eye_pt := opas.to_global(opas.bone_position("Head")) + (opas.global_basis * Vector3(0.2, -0.06, -0.4))
		_stand(opas, 0.1, 0.12)
		var tgt := _top(0.12, -0.52, 0.03).lerp(eye_pt, lift)
		_reach(opas, tgt, 1.0, 0.45 * (1.0 - lift))
		held_coin.visible = true
		held_coin.global_position = _hand(opas) + Vector3(0, 0.01, 0)
		held_coin.global_rotation = Vector3(PI / 2.0, _G.global_rotation.y, 0)
		if lift >= 1.0 and not _once.has("glint"):
			_once["glint"] = true
			_glint = 1.0
			Sfx.play("coin", -4.0, 1.2)
	if _t > 0.9 and _t < 3.4:
		_bub[opas] = "Kolmekymmentä taaleria, kuusi lusikkaa, pikari..."
	elif _t >= 3.4:
		_bub[opas] = "Juuri nämä!"
	_face(opas, _top(0.1, -0.6))
	_face(me, _top(0.2, -0.6))
	# Ensin lähikuva liinasta yläviistosta (taaleri n. 55 px, lusikat, pikari ja pöytäkirjan reuna), sitten taalerin noustessa
	# puolilähikuva oppaasta: kasvot, taaleri ja välähdys (leveys 1,1 m).
	var look: Vector3
	var eye: Vector3
	var w := 0.95
	if _t < 2.0:
		look = _top(0.12, -0.6, 0.0)
		eye = _top(0.05, -1.5, 0.78)
	else:
		var hd := opas.to_global(opas.bone_position("Head"))
		look = hd + opas.global_basis * Vector3(0.12, -0.12, 0.0)
		eye = look + opas.global_basis * Vector3(0.4, 0.15, -1.8)
		w = 1.7
	_cam_at(eye, look, _fov_w(eye.distance_to(look), w))


func _step_hilkka(_delta: float) -> void:
	# Hilkka kävelee pihalle hitaasti, Arto ja Anna-Liisa perässä, Pekka toiselta puolelta.
	var paths := {hilkka: [Vector2(-5.0, -2.6), Vector2(-1.05, -1.1), 0.0, 3.0],
		arto: [Vector2(-6.0, -2.2), Vector2(-1.55, 0.4), 0.5, 3.4],
		annaliisa: [Vector2(-6.2, -3.0), Vector2(-1.85, -0.25), 0.7, 3.5],
		pekka: [Vector2(5.4, -2.2), Vector2(1.7, 0.45), 0.4, 3.0]}
	for c: Node3D in paths:
		var pth: Array = paths[c]
		var k := clampf((_t - float(pth[2])) / float(pth[3]), 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var p: Vector2 = (pth[0] as Vector2).lerp(pth[1], e)
		_stand(c, p.x, p.y)
		c.play("Walk" if k > 0.0 and k < 1.0 else "Idle", 0.2)
		_face(c, _L(p.x + (pth[1].x - pth[0].x), p.y + (pth[1].y - pth[0].y)) if k < 1.0 else _top(0.0, -0.6))
	_face(opas, hilkka.global_position)
	_face(me, hilkka.global_position)
	if _t > 3.1:
		_bub[hilkka] = "No? Mitäs minä sanoin."
		_face(hilkka, me.global_position)
	if _t > 4.4 and _t < 5.6:
		_bub[arto] = "No en mää sitä ihan valheeksi sanonu…"
		_bub.erase(hilkka)
	if _t >= 5.6:
		_bub.erase(arto)
		_bub[annaliisa] = "Lehteen tästä tulee juttu."
	# Leveä kuva pihalta: pöytä hopeineen keskellä, Hilkka vasemmalla, Pekka oikealla (leveys 5,0 m).
	var look := _L(-0.15, -0.3, 1.0)
	var eye := _L(-0.4, -5.4, 2.2)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 5.0))


func _step_otsikko(_delta: float) -> void:
	# Pekka tarjoaa kierroksen, Hilkka nostaa lusikan ja katsoo sitä.
	for c in [hilkka, arto, annaliisa, pekka, opas, me]:
		_face(c, _top(0.0, -0.6))
	if _t < 2.2:
		_bub[pekka] = "Perkele. Mää tarjoan kierroksen."
	else:
		_bub.erase(pekka)
	var look := _L(0.1, -0.5, 0.95)
	var eye := _L(-0.4, -4.6, 2.6)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.8))


# --- Esineet ja hahmot --------------------------------------------------------------

## Kansi irti kontista pöydälle kontin eteen (ei peitä opasta matalasta kuvasta).
func _lid_aside() -> void:
	if lid.get_parent() != world:
		lid.reparent(world)
		_props.append(lid)
	# Kannen sarana on takareunassa: pöydälle laskettu kansi ulottuu saranasta d verran eteen (-Z).
	lid.global_position = _top(-0.5, -0.56, 0.0)
	lid.global_rotation = Vector3(0, _G.global_rotation.y + 0.15, 0)


func _paper_on_table() -> void:
	paper.global_position = _top(0.5, -0.36, 0.001)
	paper.global_rotation = Vector3(0, _G.global_rotation.y - 0.25, 0)


func _show_silver(k: float) -> void:
	var n := int(ceil(k * coins.size()))
	for i in coins.size():
		var c := coins[i]
		c.visible = i < n
		var s: Vector2 = c.get_meta("at")
		c.global_position = _top(s.x, s.y, float(c.get_meta("lift")))
		c.global_rotation = Vector3(0, i * 0.7, 0)
	var ns := int(ceil(clampf(k * 1.3 - 0.2, 0.0, 1.0) * spoons.size()))
	for i in spoons.size():
		var sp := spoons[i]
		sp.visible = i < ns
		var a: Vector2 = sp.get_meta("at")
		sp.global_position = _top(a.x, a.y, 0.0)
		sp.global_rotation = Vector3(0, _G.global_rotation.y + 0.1 * (i - 2), 0)
	pikari.visible = k > 0.5
	pikari.global_position = _top(0.49, -0.64, 0.0)


## Paperi kädessä rinnan edessä (w = 1) tai pöydällä (w = 0).
func _hold_paper(c: Node3D, w: float) -> void:
	if w <= 0.0:
		_paper_on_table()
		return
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var tgt := sh + Vector3(-s * 0.12, -0.22, -0.32)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", tgt, sh + Vector3(s * 0.4, -0.3, 0.2))
	var shl: Vector3 = c.bone_position("upperarm_l")
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", shl + Vector3(signf(shl.x) * -0.12, -0.22, -0.32), shl + Vector3(signf(shl.x) * 0.4, -0.3, 0.2))
	var hr := _hand(c)
	var hl := c.to_global((c.bone_position("hand_l") + c.bone_position("index_01_l")) / 2.0)
	paper.global_position = (hr + hl) / 2.0 + Vector3(0, 0.05, 0)
	paper.global_rotation = Vector3(-1.0, c.global_rotation.y, 0)


func _hands_up(c: Node3D, w: float) -> void:
	if w <= 0.01:
		return
	for side in ["r", "l"]:
		var sh: Vector3 = c.bone_position("upperarm_" + side)
		var s := signf(sh.x) if sh.x != 0.0 else 1.0
		var rest := sh + Vector3(s * 0.12, -0.45, -0.05)
		var up := sh + Vector3(s * 0.22, -0.05, -0.32)
		c.set_ik("arm_" + side, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, rest.lerp(up, w), sh + Vector3(s * 0.45, -0.3, 0.2))


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


## Oikea käsi kohti pistettä (w 0..1); lean kumartaa selkää (rad) samassa suhteessa.
func _reach(c: Node3D, at_global: Vector3, w: float, lean := 0.0) -> void:
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


## Piste pöydän pinnalla (pihan x, z) + y.
func _top(x: float, z: float, y := 0.0) -> Vector3:
	var p := _G.to_global(Vector3(x, 0.0, z))
	return Vector3(p.x, _table_y + y, p.z)


func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(eye, look)


func _fov_w(d: float, w: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return rad_to_deg(2.0 * atan(w / (2.0 * d) / (vs.x / vs.y)))


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
	if _glint > 0.0 and held_coin.visible and not _cam.is_position_behind(held_coin.global_position):
		_draw_star(_cam.unproject_position(held_coin.global_position), 64.0 * _glint, Color(1.0, 1.0, 0.92, _glint))
	if phase == "otsikko":
		var a := clampf((_t - 0.9) / 0.9, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.03, 0.08, 0.25 * a))
		var y := vs.y * 0.17
		_draw_flame_icon(Vector2(vs.x / 2.0, y - 70.0), a)
		var title := "ISONVIHAN HOPEAT"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 64, 12, Color(0.04, 0.06, 0.16, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 64, Color(0.86, 0.9, 1.0, a))
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 158.0, 840, 84)
		_ui.draw_rect(sr, Color(0.03, 0.04, 0.08, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Lapinraunion aarnivalkea paloi oikean aarteen päällä",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.6, 0.78, 1.0, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Hilkka oli oikeassa.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Välähdys: nelisakarainen tähti ja hehku.
func _draw_star(c: Vector2, r: float, col: Color) -> void:
	_ui.draw_circle(c, r * 0.35, Color(col.r, col.g, col.b, col.a * 0.35))
	for ang in [0.0, PI / 2.0]:
		var d := Vector2(cos(ang), sin(ang))
		var nrm := Vector2(-d.y, d.x)
		_ui.draw_colored_polygon(PackedVector2Array([c + d * r, c + nrm * r * 0.1, c - d * r, c - nrm * r * 0.1]), col)
	_ui.draw_circle(c, r * 0.12, col)


## Sininen liekki otsikon yllä: kolme sisäkkäistä pisaraa (tumma ääriviiva).
func _draw_flame_icon(c: Vector2, a: float) -> void:
	var layers := [[1.0, Color(0.25, 0.45, 0.95, a)], [0.68, Color(0.5, 0.72, 1.0, a)], [0.36, Color(0.9, 0.96, 1.0, a)]]
	for li in layers.size():
		var k: float = layers[li][0]
		var pts := PackedVector2Array()
		for i in 36:
			var t := TAU * i / 36.0
			var x := sin(t) * 20.0 * k
			var yv := (-cos(t) * 26.0 - 12.0 * pow(maxf(0.0, -cos(t)), 3.0) * 2.0) * k
			x *= 1.0 - 0.55 * maxf(0.0, -cos(t))
			pts.append(c + Vector2(x, yv + 14.0 * k))
		_ui.draw_colored_polygon(pts, layers[li][1])
		if li == 0:
			var loop := pts.duplicate()
			loop.append(pts[0])
			_ui.draw_polyline(loop, Color(0.04, 0.08, 0.2, a), 3.0)
