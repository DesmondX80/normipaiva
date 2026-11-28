extends CanvasLayer
## Legendaarinen hetki "tokolan_aarre" (Tokolan kauppiaan aarre): kun Heinimäen rahalipas näytetään ensimmäistä kertaa
## Aarolle (main.gd _talk_aaro "lipas"), hetki lavastetaan Aaron pihalla Tokolantien varressa. Vaiheet:
##   lipas    ruosteinen rahalipas halkopölkylle; Aaro kumartuu, vääntää kannen puukolla auki (ruostehiutaleet, narahdus)
##   sormus   lipas auki: markkanippu paperinauhassa ja kultasormus. Aaro nostaa sormuksen valoon, käsi vapisee:
##            "Hilman sormus. Kauppiaan vaimon." (välähdys)
##   huuto    Aaro ottaa nipun, marssii pihan laitaan ja nostaa sen tielle päin: "KUUSKYMMENTÄ VUOTTA NE NAURO!" (varikset)
##   pekka    Pekka ja Arto tulevat tietä. Aaro heiluttaa nippua ja osoittaa Pekkaa etusormella: "Kaljapuheita, häh?"
##            Nipusta irtoaa seteli, joka leijailee Pekan rintaan. Pekka sieppaa ja lukee: "...No perkele. Aaro oli oikeassa."
##   otsikko  Arto myöntää, Aaro nostaa nipun kuin pokaalin: TOKOLAN KAUPPIAAN AARRE, Aaro oli oikeassa
## Kehys: pihan solmu G Aaron paikalla (world.aaro_pos, 3 m talon julkisivusta), paikallinen -Z = pihalle pois talosta
## (julkisivun normaali world.aaro_nrm), +Z = talon seinälle (seinä z = +3). Pihalta katsoen paikallinen +x näkyy
## vasemmalla. Hahmojen etu -Z (Looks). Maan korkeus Terrain.h:sta. Halkopino talon seinällä, pölkky pihalla.
## Oikea Aaro ja pelaaja piiloon kohtauksen ajaksi (kopiot näyttelevät). Aaro muistelee myöhemmin (main.gd "tokola_muisto").

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const T := preload("res://scripts/terrain.gd")

const DUR := {"lipas": 6.0, "sormus": 6.4, "huuto": 5.6, "pekka": 7.8, "otsikko": 6.4}
const ORDER := ["lipas", "sormus", "huuto", "pekka", "otsikko"]
const STUMP := Vector2(0.0, 0.35)  # halkopölkyn keskusta pihalla
const STUMP_H := 0.74
const STUMP_R := 0.26
const BOX := Vector3(0.3, 0.1, 0.19)  # rahalipas (x, y, z); sarana +x-reunassa
const AARO_AT := Vector2(0.0, 0.82)  # Aaro pölkyn takana talon puolella, kasvot pihalle
const ME_AT := Vector2(-0.75, 0.5)
const SHOUT_AT := Vector2(0.4, -2.0)  # pihan laita, josta Aaro huutaa tielle
const PEKKA_AT := Vector2(-1.0, -2.95)
const ARTO_AT := Vector2(-1.2, -1.9)
const ME_YARD := Vector2(1.1, -1.2)
## Tokolan Aaro (main.gd AARO_LOOK): valkoinen siili ja parta, harmaanruskea paita.
const AARO := {"shirt": Color(0.4, 0.38, 0.3), "pants": Color(0.25, 0.22, 0.2), "shoes": Color(0.2, 0.15, 0.1), "shoe": "tyokenka",
	"hair": "Hair_Buzzed", "hair_color": Color(0.9, 0.9, 0.88), "beard": true, "height": 1.7, "skin": Color(0.92, 0.72, 0.64),
	"belly": 0.3}
## Aaro muistelee myöhemmin (main.gd _talk_aaro "tokola_muisto").
const MUISTO := ["Muistatko Pekan naaman, kun se seteli lensi sen rintaan? Viiskytseittemän painos. Mää en unohda sitä ikinä.",
	"Sormus on nyt Hilman kuvan vieressä lipaston päällä. Joka aamu mää sanon sille huomenta.",
	"Kuuskymmentä vuotta ne nauro. Nyt ne tuo mulle lihapiirakkaa ja kysyy, mitä muuta mää tiän.",
	"Arto kävi eilen kysymässä, onko kauppiaalla ollu muita kätköjä. Mää sanoin, että ehkä. Antaa pojan kaivella."]

var world: Node3D
var hide_nodes: Array = []  # oikea pelaaja ja oikea Aaro piiloon kohtauksen ajaksi
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
var aaro: Node3D
var pekka: Node3D
var arto: Node3D
var lipas: Node3D
var lid: Node3D  # kannen sarana (+x-reuna)
var ring: Node3D
var nippu: Node3D  # markkanippu (lippaassa, sitten Aaron kädessä)
var note: Node3D  # irtoava seteli
var knife: Node3D
var _flakes: CPUParticles3D
var _stump_y := 0.0
var _glint := 0.0
var _pointing := {}  # hahmo -> "_l"/"_r": etusormi suoraksi tämän ruudun animaation jälkeen
var _note_from := Vector3.ZERO
var note_caught := false  # testi lukee


func _ready() -> void:
	layer = 6
	process_priority = 100  # hahmojen asento lasketaan ensin, sitten etusormi suoraksi (_straighten_index)
	_G = Node3D.new()
	world.add_child(_G)
	_props.append(_G)
	var ap: Vector3 = world.aaro_pos
	var n: Vector2 = world.aaro_nrm
	_G.global_position = Vector3(ap.x, 0.0, ap.z)
	_G.rotation.y = B.yaw_to(Vector3(n.x, 0, n.y))  # -Z pihalle
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
	_begin("lipas")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	var sc := _L(STUMP.x, STUMP.y)
	_stump_y = sc.y + STUMP_H
	_build_stump(STUMP, STUMP_H, STUMP_R, true)
	_build_woodpile()
	var small := _build_stump(Vector2(1.35, 1.7), 0.42, 0.21, false)
	_build_axe(small)
	lipas = _build_lipas()
	lipas.global_position = _top(0.0, 0.0)
	lipas.global_rotation = Vector3(0, _G.global_rotation.y + 0.12, 0)
	nippu = _build_nippu()
	lipas.add_child(nippu)
	nippu.position = Vector3(-0.03, 0.012, 0.0)
	ring = _build_ring()
	lipas.add_child(ring)
	ring.position = Vector3(0.075, 0.03, 0.035)
	note = _build_note()
	world.add_child(note)
	_props.append(note)
	note.visible = false
	knife = _build_knife()
	knife.visible = false
	# Ruostehiutaleet kannen raosta väännettäessä.
	_flakes = CPUParticles3D.new()
	world.add_child(_flakes)
	_props.append(_flakes)
	var fm := BoxMesh.new()
	fm.size = Vector3(0.008, 0.002, 0.006)
	fm.material = B.mat(Color(0.55, 0.27, 0.12))
	_flakes.mesh = fm
	_flakes.amount = 40
	_flakes.lifetime = 0.9
	_flakes.emitting = false
	_flakes.direction = Vector3(0, 1, 0)
	_flakes.spread = 70.0
	_flakes.initial_velocity_min = 0.3
	_flakes.initial_velocity_max = 0.8
	_flakes.gravity = Vector3(0, -3.0, 0)
	_flakes.angular_velocity_min = -400.0
	_flakes.angular_velocity_max = 400.0
	# Hahmot.
	aaro = _person(AARO, AARO_AT.x, AARO_AT.y)
	_lean(aaro, 0.0)  # vanhuksen kumara
	me = _person(Looks.player(), ME_AT.x, ME_AT.y)
	pekka = _person(Looks.PEKKA, -6.4, -3.5)
	arto = _person(Looks.ARTO, -7.0, -2.7)
	pekka.visible = false
	arto.visible = false
	_face(aaro, _top(0, 0))
	_face(me, _top(0, 0))


## Halkopölkky: paksu mäntypölkky syineen, kuoren rippeet kyljessä, kirveen jäljet yläpinnassa.
func _build_stump(at: Vector2, h: float, r: float, main_one: bool) -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var base := _L(at.x, at.y)
	g.global_position = base
	g.rotation.y = _G.global_rotation.y
	var bark := Color(0.42, 0.3, 0.2)
	B.mesh(g, B.cyl(r, r * 1.08, h + 0.08, 18), Vector3(0, (h - 0.08) / 2.0, 0), bark)  # 8 cm maan sisään (kalteva maa)
	var wood := Color(0.86, 0.72, 0.5)
	B.mesh(g, B.cyl(r * 0.94, r * 0.94, 0.012, 18), Vector3(0, h - 0.002, 0), wood)
	for k in 4:  # vuosirenkaat
		var rr := r * (0.78 - k * 0.18)
		B.mesh(g, B.cyl(rr, rr, 0.002, 18), Vector3(0, h + 0.005, 0), wood.darkened(0.12 + 0.04 * k))
		B.mesh(g, B.cyl(rr - 0.012, rr - 0.012, 0.0022, 18), Vector3(0, h + 0.0055, 0), wood)
	B.mesh(g, B.cyl(0.015, 0.015, 0.003, 8), Vector3(0, h + 0.007, 0), wood.darkened(0.3))
	for k in 3:  # kirveen jäljet
		var cut := B.mesh(g, B.boxm(Vector3(r * 0.55, 0.003, 0.005)), Vector3(0, h + 0.007, -r * 0.4 + k * r * 0.35), wood.darkened(0.25))
		cut.rotation.y = 0.5 + k * 0.7
	for k in 7:  # kaarnan kohoumat
		var a := k * TAU / 7.0 + 0.3
		var pl := B.mesh(g, B.boxm(Vector3(0.035, h * 0.55, 0.006)), Vector3(cos(a) * r * 1.02, h * 0.45, sin(a) * r * 1.02), bark.darkened(0.08))
		pl.rotation.y = -a + PI / 2.0
	if main_one:
		_stump_y = base.y + h
	return g


## Halkopino talon seinällä: halot päät pihalle (vaalea pää, vuosirengas, tumma kuori), kuusi kerrosta.
func _build_woodpile() -> void:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var c := _L(-0.3, 2.68)
	g.global_position = c
	g.rotation.y = _G.global_rotation.y
	var end := Color(0.84, 0.7, 0.48)
	var bark := Color(0.38, 0.28, 0.18)
	var rng := RandomNumberGenerator.new()
	rng.seed = 120
	for row in 6:
		for k in 14:
			var r := rng.randf_range(0.055, 0.075)
			var x := -1.1 + k * 0.16 + (0.08 if row % 2 == 1 else 0.0) + rng.randf_range(-0.01, 0.01)
			var y := 0.07 + row * 0.135
			var halko := B.mesh(g, B.cyl(r, r, 0.46, 9), Vector3(x, y, 0), bark.lightened(rng.randf_range(-0.05, 0.08)))
			halko.rotation.x = PI / 2.0
			var face := B.mesh(g, B.cyl(r * 0.88, r * 0.88, 0.006, 9), Vector3(x, y, -0.231), end.darkened(rng.randf_range(0.0, 0.12)))
			face.rotation.x = PI / 2.0
			var ringm := B.mesh(g, B.cyl(r * 0.45, r * 0.45, 0.002, 9), Vector3(x, y, -0.235), end.darkened(0.2))
			ringm.rotation.x = PI / 2.0
	# Pinon katos: kaksi lautaa päällä.
	B.mesh(g, B.boxm(Vector3(2.5, 0.025, 0.56)), Vector3(-0.0, 0.9, 0.0), Color(0.45, 0.4, 0.34))


func _build_axe(stump: Node3D) -> void:
	var g := Node3D.new()
	stump.add_child(g)
	g.position = Vector3(0.02, 0.42, 0.0)
	g.rotation = Vector3(0, 0.4, -0.5)
	B.mesh(g, B.boxm(Vector3(0.03, 0.02, 0.6)), Vector3(0, 0.0, 0.3), Color(0.62, 0.45, 0.26))  # varsi
	var head := B.mesh(g, B.boxm(Vector3(0.012, 0.11, 0.08)), Vector3(0, -0.02, 0.0), Color(0.3, 0.3, 0.32))
	head.material_override = _metal(Color(0.35, 0.35, 0.37), 0.5)


## Ruosteinen peltinen rahalipas: harmaanvihreä maali lohkeillut, ruosteläiskät, avaimenreikä, kantokahva kannessa.
func _build_lipas() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var w := BOX.x
	var h := BOX.y
	var d := BOX.z
	var paint := Color(0.35, 0.4, 0.33)
	var rust := Color(0.5, 0.26, 0.12)
	var t := 0.006
	# Pohja ja seinät (ylhäältä auki, jotta sisus näkyy kannen noustua).
	B.mesh(g, B.boxm(Vector3(w, t, d)), Vector3(0, t / 2.0, 0), paint.darkened(0.2))
	for side in [-1.0, 1.0]:
		B.mesh(g, B.boxm(Vector3(w, h, t)), Vector3(0, h / 2.0, side * (d - t) / 2.0), paint)
		B.mesh(g, B.boxm(Vector3(t, h, d)), Vector3(side * (w - t) / 2.0, h / 2.0, 0), paint.darkened(0.05))
	B.mesh(g, B.boxm(Vector3(w - 2 * t, 0.002, d - 2 * t)), Vector3(0, t + 0.001, 0), Color(0.16, 0.12, 0.09))  # tumma pohja
	# Ruosteläiskät ja reunojen ruoste.
	var spots := [[Vector3(-0.08, 0.03, -d / 2.0 - 0.001), Vector2(0.07, 0.04)], [Vector3(0.09, 0.06, -d / 2.0 - 0.001), Vector2(0.05, 0.05)],
		[Vector3(-w / 2.0 - 0.001, 0.04, 0.03), Vector2(0.06, 0.05)]]
	for k in 6:  # alareunan ruoste: epätasaisia läikkiä, ei yhtenäistä listaa
		spots.append([Vector3(-w / 2.0 + 0.03 + k * 0.048, 0.004 + 0.006 * (k % 3), -d / 2.0 - 0.001), Vector2(0.03 + 0.012 * (k % 2), 0.01 + 0.008 * ((k + 1) % 3))])
	for s in spots:
		var p: Vector3 = s[0]
		var sz: Vector2 = s[1]
		var thin := Vector3(sz.x, sz.y, 0.002) if absf(p.z) > 0.05 else Vector3(0.002, sz.y, sz.x)
		B.mesh(g, B.boxm(thin), p, rust.lightened(randf_range(-0.05, 0.1)))
	# Avaimenreikä etuseinässä (pihalle päin, -Z).
	B.mesh(g, B.boxm(Vector3(0.03, 0.035, 0.002)), Vector3(-0.0, h * 0.62, -d / 2.0 - 0.002), Color(0.62, 0.55, 0.35))
	B.mesh(g, B.boxm(Vector3(0.006, 0.014, 0.002)), Vector3(-0.0, h * 0.6, -d / 2.0 - 0.0035), Color(0.08, 0.06, 0.05))
	# Kansi: sarana +x-reunassa, avautuu ylös +x-suuntaan (ei peitä sisusta pihan kamerasta).
	lid = Node3D.new()
	lid.position = Vector3(w / 2.0, h, 0)
	g.add_child(lid)
	B.mesh(lid, B.boxm(Vector3(w + 0.008, 0.012, d + 0.008)), Vector3(-w / 2.0, 0.006, 0), paint.lightened(0.04))
	B.mesh(lid, B.boxm(Vector3(w * 0.5, 0.0025, d * 0.4)), Vector3(-w * 0.55, 0.013, 0.02), rust)
	B.mesh(lid, B.boxm(Vector3(0.05, 0.002, 0.07)), Vector3(-w * 0.2, 0.013, -0.04), rust.lightened(0.12))
	var hm := _metal(Color(0.42, 0.4, 0.36), 0.55)
	for x in [-0.045, 0.045]:  # kahva
		var post := B.mesh(lid, B.boxm(Vector3(0.008, 0.016, 0.008)), Vector3(-w / 2.0 + x, 0.02, 0), Color.WHITE)
		post.material_override = hm
	var bar := B.mesh(lid, B.boxm(Vector3(0.1, 0.008, 0.012)), Vector3(-w / 2.0, 0.03, 0), Color.WHITE)
	bar.material_override = hm
	return g


## Markkanippu: kymmenkunta vanhaa satasta pinossa (harmaanvihreä, tummempi kehys ja muotokuvan soikio), valkoinen
## paperinauha keskellä.
func _build_nippu() -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1957
	for i in 10:
		var nt := _note_mesh(g)
		nt.position = Vector3(rng.randf_range(-0.004, 0.004), 0.0015 * i, rng.randf_range(-0.003, 0.003))
		nt.rotation.y = rng.randf_range(-0.04, 0.04)
	B.mesh(g, B.boxm(Vector3(0.032, 0.018, 0.075)), Vector3(0, 0.007, 0), Color(0.95, 0.93, 0.85))  # nauha
	return g


func _build_note() -> Node3D:
	var g := Node3D.new()
	_note_mesh(g)
	return g


## Yksi seteli (14 x 7 cm): pohja, kehys, muotokuvan soikio ja numero 100.
func _note_mesh(parent: Node3D) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	var base := Color(0.72, 0.76, 0.62)
	B.mesh(g, B.boxm(Vector3(0.14, 0.0012, 0.07)), Vector3.ZERO, base)
	B.mesh(g, B.boxm(Vector3(0.128, 0.0004, 0.058)), Vector3(0, 0.0008, 0), base.darkened(0.18))
	B.mesh(g, B.boxm(Vector3(0.12, 0.0004, 0.05)), Vector3(0, 0.001, 0), base.lightened(0.05))
	var oval := B.mesh(g, B.cyl(0.5, 0.5, 0.0004, 14), Vector3(0.035, 0.0013, 0), base.darkened(0.35))
	oval.scale = Vector3(0.04, 1.0, 0.034)
	B.mesh(g, B.boxm(Vector3(0.022, 0.0004, 0.012)), Vector3(-0.042, 0.0013, -0.012), Color(0.3, 0.38, 0.25))  # "100"
	B.mesh(g, B.boxm(Vector3(0.04, 0.0004, 0.004)), Vector3(-0.03, 0.0013, 0.014), Color(0.4, 0.45, 0.32))
	return g


## Kultasormus: kiiltävä torus ja pieni punainen kivi.
func _build_ring() -> Node3D:
	var g := Node3D.new()
	g.scale = Vector3.ONE * 1.3  # hieman oikeaa isompi, jotta näkyy sormien välissä
	var tm := TorusMesh.new()
	tm.inner_radius = 0.0085
	tm.outer_radius = 0.0115
	tm.rings = 24
	tm.ring_segments = 8
	var band := MeshInstance3D.new()
	band.mesh = tm
	band.material_override = _metal(Color(1.0, 0.78, 0.3), 0.18)
	band.rotation.x = PI / 2.0  # pystyyn: kivi ylhäällä
	g.add_child(band)
	var gem := B.mesh(g, B.sphere(0.5, 10), Vector3(0, 0.0125, 0), Color(0.75, 0.08, 0.12))
	gem.scale = Vector3(0.007, 0.006, 0.007)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.8, 0.1, 0.15)
	gm.metallic = 0.3
	gm.roughness = 0.1
	gm.emission_enabled = true
	gm.emission = Color(0.4, 0.02, 0.05)
	gem.material_override = gm
	return g


## Puukko: kiiltävä terä ja koivuinen kahva helan kera (Aaron oikeassa kädessä kannen väännön ajan).
func _build_knife() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var blade := B.mesh(g, B.boxm(Vector3(0.004, 0.018, 0.09)), Vector3(0, 0, -0.05), Color.WHITE)
	blade.material_override = _metal(Color(0.78, 0.78, 0.8), 0.25)
	var tip := B.mesh(g, B.boxm(Vector3(0.004, 0.012, 0.02)), Vector3(0, 0.003, -0.1), Color.WHITE)
	tip.material_override = blade.material_override
	tip.rotation.x = 0.4
	B.mesh(g, B.boxm(Vector3(0.022, 0.026, 0.1)), Vector3(0, 0, 0.05), Color(0.82, 0.7, 0.5))  # koivukahva
	B.mesh(g, B.boxm(Vector3(0.024, 0.028, 0.008)), Vector3(0, 0, 0.0), Color(0.6, 0.5, 0.3))  # hela
	return g


func _metal(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.85
	m.roughness = rough
	return m


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
	_pointing.clear()
	for c in [me, aaro, pekka, arto]:
		c.clear_ik()
		_relax(c)
	match p:
		"lipas":
			_story = "Aaron piha Tokolassa. Heinimäen rahalipas halkopölkylle."
		"sormus":
			_story = ""
			lid.rotation.z = -1.95
			knife.visible = false
			_flakes.emitting = false
			_stand(aaro, AARO_AT.x, AARO_AT.y)
		"huuto":
			_story = ""
			lid.rotation.z = -1.95
			ring.visible = false  # Aaro pani sormuksen rintataskuun
			knife.visible = false
		"pekka":
			_story = ""
			lid.rotation.z = -1.95
			ring.visible = false
			_take_nippu()
			_stand(aaro, SHOUT_AT.x, SHOUT_AT.y)
			_stand(me, ME_YARD.x, ME_YARD.y)
			pekka.visible = true
			arto.visible = true
		"otsikko":
			_story = ""
			lid.rotation.z = -1.95
			ring.visible = false
			knife.visible = false
			_take_nippu()
			pekka.visible = true
			arto.visible = true
			for c in [pekka, arto, aaro, me]:
				c.play("Idle", 0.2)
			_stand(aaro, SHOUT_AT.x, SHOUT_AT.y)
			_stand(me, ME_YARD.x, ME_YARD.y)
			_stand(pekka, PEKKA_AT.x, PEKKA_AT.y)
			_stand(arto, ARTO_AT.x, ARTO_AT.y)
			note.visible = false
			Sfx.play("win", -6.0, 0.95)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa keskustelun valinnasta (E tai napsautus): sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "lipas" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"lipas":
			_step_lipas(delta)
		"sormus":
			_step_sormus(delta)
		"huuto":
			_step_huuto(delta)
		"pekka":
			_step_pekka(delta)
		"otsikko":
			_step_otsikko(delta)
	_straighten_index()
	_glint = maxf(0.0, _glint - delta * 1.6)
	_ui.queue_redraw()
	if phase != "" and _t >= DUR[phase]:
		var i := ORDER.find(phase)
		if i == ORDER.size() - 1:
			_finish()
		else:
			_begin(ORDER[i + 1])


## Etusormi suoraksi osoittavaan käteen hahmojen asennon jälkeen (process_priority): muut sormet jäävät animaation
## koukkuun, joten käsi osoittaa etusormella eikä nyrkillä. Asetus lepoon on idempotentti (harvemmin päivittyvä hahmo).
func _straighten_index() -> void:
	for c: Node3D in _pointing:
		var lr: String = _pointing[c]
		var sk: Skeleton3D = c.skeleton
		for k in ["01", "02", "03"]:
			var i := sk.find_bone("index_%s%s" % [k, lr])
			if i >= 0:
				sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion())


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


func _step_lipas(_delta: float) -> void:
	# Aaro kumartuu lippaan yli, kaivaa puukon ja vääntää kannen auki (1,6-3,7 s); kansi pomppaa auki 3,7 s.
	_face(aaro, _top(0, 0))
	_face(me, _top(0, 0))
	var corner := pry_point()
	if _t < 1.5:
		_lean(aaro, 0.4 * clampf(_t / 0.8, 0.0, 1.0))
		if _t > 0.5:
			_bub[aaro] = "Näytäs sitä..."
	elif _t < 3.7:
		_bub.erase(aaro)
		var pry := sin((_t - 1.5) * 9.0) * 0.012
		_reach(aaro, corner + Vector3(0, 0.03 + pry, 0), clampf((_t - 1.5) / 0.4, 0.0, 1.0), 0.95)
		knife.visible = true
		var hp := _hand(aaro)
		knife.look_at_from_position(hp, corner, Vector3.UP)
		knife.global_position = hp
		_flakes.global_position = corner
		_flakes.emitting = _t > 1.9
		lid.rotation.z = -(0.04 + 0.03 * absf(sin((_t - 1.5) * 9.0))) if _t > 1.9 else 0.0
		for k in [2.0, 2.7, 3.3]:
			if _t > k and not _once.has("narahdus%s" % k):
				_once["narahdus%s" % k] = true
				Sfx.play("pedal_creak", -2.0, 0.55 + randf() * 0.1)
		if _t > 2.2:
			_story = "Kuuskymmentä vuotta juurakon alla. Ruoste pitää."
	else:
		_flakes.emitting = false
		knife.visible = true
		_reach(aaro, corner + Vector3(-0.05, 0.12, -0.05), 1.0 - clampf((_t - 3.7) / 0.6, 0.0, 1.0), 0.8)
		knife.global_position = _hand(aaro)
		var k := clampf((_t - 3.7) / 0.25, 0.0, 1.0)
		lid.rotation.z = -lerpf(0.08, 1.95, k) - (0.12 * sin((_t - 3.95) * 18.0) * exp(-(_t - 3.95) * 4.0) if k >= 1.0 else 0.0)
		if not _once.has("auki"):
			_once["auki"] = true
			Sfx.play("rattle_hard", -3.0, 0.6)
		if _t > 4.2:
			_bub[aaro] = "...Voi pojat."
			_story = ""
	# Pihalta vinosti: pölkky ja lipas keskellä, Aaro sen takana, pelaaja oikealla; halkopino taustalla.
	var look := _L(-0.3, 0.45, 1.3)
	var eye := _L(1.2, -2.5, 2.1)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 2.9))


func _step_sormus(_delta: float) -> void:
	# Ensin lähikuva lippaasta (nippu ja sormus), sitten Aaro nostaa sormuksen valoon: käsi vapisee.
	_lean(aaro, 0.4)
	_face(me, _top(0, 0))
	var rest_pos := lipas.to_global(Vector3(0.075, 0.03, 0.035))
	if _t < 1.4:
		_story = "Markkanippu paperinauhassa. Ja sormus."
		_face(aaro, _top(0, 0))
	elif _t < 2.4:
		_story = ""
		var r := clampf((_t - 1.4) / 0.6, 0.0, 1.0)
		_reach(aaro, rest_pos + Vector3(0, 0.02, 0), r, 0.95)
		if _t > 2.0:
			ring.visible = true
			_hold_ring()
	else:
		var lift := clampf((_t - 2.4) / 0.8, 0.0, 1.0)
		var hd := aaro.to_global(aaro.bone_position("Head"))
		var up := hd + aaro.global_basis * Vector3(0.17, -0.1, -0.3)
		var shake := Vector3(sin(_t * 23.0), sin(_t * 31.0 + 1.0), 0.0) * 0.004
		_lean(aaro, 0.95 * (1.0 - lift))
		_reach(aaro, (rest_pos + Vector3(0, 0.02, 0)).lerp(up, lift) + shake, 1.0, 0.95 * (1.0 - lift))
		_hold_ring()
		if lift >= 1.0 and not _once.has("glint"):
			_once["glint"] = true
			_glint = 1.0
			Sfx.play("coin", -6.0, 1.5)
	if _t > 3.0 and _t < 4.7:
		_bub[aaro] = "Hilman sormus. Kauppiaan vaimon."
	elif _t >= 4.7:
		_bub[aaro] = "Se anto mulle karamellin joka lauantai."
	var look: Vector3
	var eye: Vector3
	var w := 0.6
	if _t < 2.5:  # sormuksen otto näkyy lähikuvassa, Aaron kasvot vasta noston alkaessa
		look = lipas.to_global(Vector3(0.0, 0.02, 0.0))
		eye = look + _G.global_basis * Vector3(-0.08, 0.42, -0.42)
	else:
		var hd2 := aaro.to_global(aaro.bone_position("Head"))
		look = hd2 + aaro.global_basis * Vector3(0.06, -0.02, -0.1)  # pää alempana ruudussa: puhekupla pään yllä, ei kasvoilla
		eye = look + aaro.global_basis * Vector3(-0.45, 0.05, -1.5)
		w = 1.0
	_cam_at(eye, look, _fov_w(eye.distance_to(look), w))


func _step_huuto(_delta: float) -> void:
	# Aaro ottaa nipun, kiertää pölkyn ja marssii pihan laitaan (0,4-2,8 s), nostaa nipun tielle päin ja huutaa.
	_face(me, aaro.global_position)
	if _t < 0.5:
		_reach(aaro, lipas.to_global(Vector3(-0.03, 0.03, 0.0)), clampf(_t / 0.4, 0.0, 1.0), 0.95)
		_face(aaro, _top(0, 0))
	else:
		_take_nippu()
		var path := [AARO_AT, Vector2(0.75, 0.3), Vector2(0.65, -1.0), SHOUT_AT]
		var k := clampf((_t - 0.5) / 2.3, 0.0, 1.0)
		# Kumarrus suoristuu kävellessä; huutaessa rinta ulos (lievä taaksenojaus).
		_lean(aaro, lerpf(0.95, 0.0, clampf((_t - 0.5) / 0.6, 0.0, 1.0)) - 0.2 * clampf((_t - 2.8) / 0.35, 0.0, 1.0))
		var p := _path(path, k)
		_stand(aaro, p.x, p.y)
		if k < 1.0:
			aaro.play("Walk", 0.2)
			var nxt := _path(path, minf(1.0, k + 0.05))
			_face(aaro, _L(nxt.x, nxt.y))
			_carry_nippu(0.0)
		else:
			aaro.play("Idle", 0.2)
			_face(aaro, _L(SHOUT_AT.x, SHOUT_AT.y - 3.0))
			var up := clampf((_t - 2.8) / 0.35, 0.0, 1.0)
			_carry_nippu(up)
			if up >= 1.0 and not _once.has("huuto"):
				_once["huuto"] = true
				Sfx.play("crow", -6.0, 0.9)
				Sfx.play("grunt", -2.0, 0.8)
			if _t > 3.0:
				_bub[aaro] = "KUUSKYMMENTÄ VUOTTA NE NAURO!"
			if _t > 4.4:
				_story = "Tokolantie kuulee."
	# Matala kuva pihan laidalta: Aaro nousee taivasta vasten nippu ylhäällä, piha ja pölkky taustalla.
	var ap := aaro.global_position
	var look := ap + Vector3(0, 1.45, 0)
	var eye := _L(SHOUT_AT.x - 1.3, SHOUT_AT.y - 3.2, 0.75)
	if _t < 2.8:
		look = ap.lerp(_L(SHOUT_AT.x, SHOUT_AT.y), 0.5) + Vector3(0, 1.2, 0)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 2.8))


func _step_pekka(_delta: float) -> void:
	# Pekka ja Arto tulevat tietä (0-2,4 s). Aaro heiluttaa nippua ja osoittaa Pekkaa; seteli irtoaa 2,6 s, leijailee
	# Pekan rintaan 3,6 s, Pekka sieppaa ja lukee.
	var paths := {pekka: [Vector2(-6.4, -3.5), PEKKA_AT, 0.0, 2.4], arto: [Vector2(-7.0, -2.7), ARTO_AT, 0.25, 2.5]}
	for c: Node3D in paths:
		var pth: Array = paths[c]
		var k := clampf((_t - float(pth[2])) / float(pth[3]), 0.0, 1.0)
		var e := k * (2.0 - k)
		var p: Vector2 = (pth[0] as Vector2).lerp(pth[1], e)
		_stand(c, p.x, p.y)
		c.play("Walk" if k < 1.0 else "Idle", 0.2)
		_face(c, _L(pth[1].x + 1.0, pth[1].y) if k < 1.0 else aaro.global_position)
	_face(aaro, pekka.global_position)
	_face(me, pekka.global_position.lerp(aaro.global_position, 0.5))
	var wave := sin(_t * 9.0) * clampf((_t - 1.2) / 0.3, 0.0, 1.0) * (1.0 - clampf((_t - 2.9) / 0.3, 0.0, 1.0))
	_carry_nippu(0.55 + 0.25 * wave, pekka.global_position)
	if _t > 1.3:
		_point(aaro, "_l", pekka.to_global(pekka.bone_position("Head")) + Vector3(0, -0.15, 0), clampf((_t - 1.3) / 0.3, 0.0, 1.0))
	if _t > 1.3 and _t < 3.8:
		_bub[aaro] = "Kaljapuheita, häh, Pekka?"
	# Seteli: irtoaa nipusta 2,6 s, kaari ylös ja leijailu Pekan rintaan (heiluu sivuttain, pyörii).
	var chest := pekka.to_global(pekka.bone_position("spine_03")) + pekka.global_basis * Vector3(0, 0.0, -0.22)
	if _t >= 2.6 and not _once.has("irti"):
		_once["irti"] = true
		_note_from = nippu.global_position + Vector3(0, 0.02, 0)
		note.visible = true
		Sfx.play("cloth", -4.0, 1.6)
	if _t >= 2.6 and _t < 3.6:
		var k := (_t - 2.6) / 1.0
		var side := pekka.global_basis.x
		var p := _note_from.lerp(chest, k) + Vector3(0, 0.35 * sin(k * PI), 0) + side * 0.12 * sin(k * TAU * 1.5)
		note.global_position = p
		note.global_rotation = Vector3(sin(_t * 11.0) * 0.9, _t * 6.0, cos(_t * 8.0) * 0.7)
	var catch := clampf((_t - 3.25) / 0.35, 0.0, 1.0)
	if _t >= 3.25:
		var read := clampf((_t - 4.0) / 0.6, 0.0, 1.0)
		var hd := pekka.to_global(pekka.bone_position("Head"))
		var read_at := hd + pekka.global_basis * Vector3(0.0, -0.3, -0.3)
		var tgt := chest.lerp(read_at, read)
		_reach(pekka, tgt, catch, 0.0)
		if catch >= 1.0:
			note_caught = true
			note.global_position = _hand(pekka) + Vector3(0, 0.05, 0)
			# Seteli sormien välissä pystyssä: kuva puoliksi Pekan kasvoihin, puoliksi kameraan (profiilikuvassa ei syrjällään).
			var to_face := (hd - note.global_position).normalized()
			var to_cam := (_cam.global_position - note.global_position).normalized()
			var nrm := (to_face * 0.45 + to_cam * 0.55).normalized().lerp(Vector3.UP, 1.0 - read).normalized()
			var ax := Vector3.UP.cross(nrm)
			if ax.length() < 0.1:
				ax = pekka.global_basis.x
			ax = ax.normalized()
			note.global_basis = Basis(ax, nrm, ax.cross(nrm)).orthonormalized()
	if _t > 4.5 and _t < 6.0:
		_bub.erase(aaro)
		_bub[pekka] = "Sata markkaa. Painettu viiskytseittemän."
	elif _t >= 6.0:
		_bub[pekka] = "...No perkele. Aaro oli oikeassa."
	# Sivukuva Aaron ja Pekan väliseen linjaan kohtisuoraan pihan puolelta: molemmat profiilissa, Arto ja pelaaja välissä.
	var a2 := Vector2(SHOUT_AT.x, SHOUT_AT.y)
	var p2 := PEKKA_AT
	var mid := (a2 + p2) / 2.0
	var line := (p2 - a2).normalized()
	var perp := Vector2(line.y, -line.x)
	if perp.y > 0.0:
		perp = -perp
	var cpos := mid + perp * 4.0
	var c2 := (ME_YARD + PEKKA_AT) / 2.0
	var look := _L(c2.x, c2.y, 1.25)
	var eye := _L(cpos.x, cpos.y, 1.65)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.2))


func _step_otsikko(_delta: float) -> void:
	# Arto myöntää, Aaro nostaa nipun kuin pokaalin, kaikki katsovat Aaroa.
	for c in [pekka, arto, me]:
		_face(c, aaro.global_position)
	_face(aaro, _L(SHOUT_AT.x - 0.3, SHOUT_AT.y - 2.0))
	_carry_nippu(clampf((_t - 1.6) / 0.4, 0.0, 1.0))
	if _t < 2.4:
		_bub[arto] = "Mää koluasin sitä varastoa poikasena. Väärästä paikasta."
	else:
		_bub.erase(arto)
	# Sama suunta kuin Pekan kuvassa, väljemmin: Pekka ja Arto sivuprofiilissa, Aaro nippu ylhäällä.
	var line := (PEKKA_AT - SHOUT_AT).normalized()
	var perp := Vector2(line.y, -line.x)
	if perp.y > 0.0:
		perp = -perp
	var c2 := (ME_YARD + PEKKA_AT) / 2.0
	var cpos := c2 + perp * 5.0
	var look := _L(c2.x, c2.y, 1.35)
	var eye := _L(cpos.x, cpos.y, 1.8)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.8))


# --- Esineet ja hahmot --------------------------------------------------------------

## Kannen avausreuna (saranaa vastapäätä, -x) keskeltä: tähän Aaro iskee puukon.
func pry_point() -> Vector3:
	return lipas.to_global(Vector3(-BOX.x / 2.0 + 0.01, BOX.y + 0.004, 0.02))


## Sormus Aaron peukalon ja etusormen välissä, kivi ylöspäin.
func _hold_ring() -> void:
	var tip := aaro.to_global(aaro.bone_position("index_02_r"))
	var th := aaro.to_global(aaro.bone_position("thumb_02_r"))
	ring.global_position = (tip + th) / 2.0 + Vector3(0, 0.03, 0)  # sormenpäiden yllä, ei nyrkin sisässä
	var to_cam := _cam.global_position - ring.global_position
	to_cam.y = 0.0
	ring.global_rotation = Vector3(0, B.yaw_to(to_cam), 0)  # renkaan aukko kameraan päin (torus pystyssä XY-tasossa)


## Nippu Aaron oikeaan käteen (irti lippaasta).
func _take_nippu() -> void:
	if nippu.get_parent() != world:
		nippu.reparent(world)
		_props.append(nippu)


## Oikea käsi nipun kanssa: lepo vyötäröllä (up 0), suoraan ylös (up 1). toward: nosto kohti pistettä (heilutus).
func _carry_nippu(up: float, toward := Vector3.INF) -> void:
	var sh: Vector3 = aaro.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.1, -0.38, -0.22)
	var high := sh + Vector3(s * 0.08, 0.5, -0.12)
	var tgt := rest.lerp(high, up)
	if toward != Vector3.INF:
		var d := aaro.to_local(toward)
		d.y = 0.0
		tgt = rest.lerp(sh + Vector3(0, 0.25, 0) + d.normalized() * 0.45, up)
	aaro.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", tgt, sh + Vector3(s * 0.45, -0.3, 0.25))
	# Nippu pystyssä nyrkin yllä setelien kuva kameraan päin (setelin normaali = paikallinen +Y).
	var hp := _hand(aaro)
	var arm := (hp - aaro.to_global(aaro.bone_position("lowerarm_r"))).normalized()
	nippu.global_position = hp + arm * 0.06
	var n := (_cam.global_position - nippu.global_position).normalized()
	var x := arm.cross(n).normalized()
	if x.length() < 0.5:
		x = Vector3.RIGHT
	nippu.global_basis = Basis(x, n, x.cross(n)).orthonormalized()


## Käsi osoittaa kohti pistettä etusormella (w 0..1): suora käsivarsi, etusormi suoraksi animaation jälkeen.
func _point(c: Node3D, lr: String, at_global: Vector3, w: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm" + lr)
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.45, -0.05)
	var d := (c.to_local(at_global) - sh).normalized()
	var tgt := rest.lerp(sh + d * 0.56, w)
	c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, tgt, sh + Vector3(s * 0.5, -0.4, 0.1))
	if w > 0.5:
		_pointing[c] = lr
	else:
		_pointing.erase(c)


func _relax(c: Node3D) -> void:
	_lean(c, 0.0)


## Kumarrus koko selällä (rad yhteensä): lanne eniten, rintaranka vähemmän, jotta hartiat tulevat oikeasti eteen ja alas
## (pelkkä spine_01 siirsi olkaa vain 6 cm). Aaron vanhuksen kumara (Looks.hunch 0.15) pysyy pohjalla ja niska
## kompensoi, jotta katse pysyy kohteessa.
func _lean(c: Node3D, a: float) -> void:
	var base := 0.075 if c == aaro else 0.0
	c.set_override("spine_01", Vector3.RIGHT, -a * 0.45 - base)
	c.set_override("spine_02", Vector3.RIGHT, -a * 0.35)
	c.set_override("spine_03", Vector3.RIGHT, -a * 0.2 - base)
	c.set_override("neck_01", Vector3.RIGHT, a * 0.35 + base * 1.2)


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
	_lean(c, lean * w)
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at_global), w)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", tgt, sh + Vector3(s * 0.45, -0.25, 0.25))


## Polku pisteiden kautta (k 0..1 tasaisesti pituuden mukaan).
func _path(pts: Array, k: float) -> Vector2:
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i] as Vector2).distance_to(pts[i + 1])
	var want := total * k
	for i in pts.size() - 1:
		var seg := (pts[i] as Vector2).distance_to(pts[i + 1])
		if want <= seg or i == pts.size() - 2:
			return (pts[i] as Vector2).lerp(pts[i + 1], clampf(want / maxf(seg, 0.001), 0.0, 1.0))
		want -= seg
	return pts[-1]


# --- Kehys, kamera ------------------------------------------------------------------

## Pihan piste (x, z) maanpinnalla + y.
func _L(x: float, z: float, y := 0.0) -> Vector3:
	var p := _G.to_global(Vector3(x, 0.0, z))
	return Vector3(p.x, T.h(p.x, p.z) + y, p.z)


## Piste pölkyn yläpinnalla (pihan x, z suhteessa pölkyn keskustaan) + y.
func _top(x: float, z: float, y := 0.0) -> Vector3:
	var p := _G.to_global(Vector3(STUMP.x + x, 0.0, STUMP.y + z))
	return Vector3(p.x, _stump_y + 0.006 + y, p.z)


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
	if _glint > 0.0 and ring.visible and not _cam.is_position_behind(ring.global_position):
		_draw_star(_cam.unproject_position(ring.global_position + Vector3(0, 0.012, 0)), 56.0 * _glint, Color(1.0, 0.96, 0.8, _glint))
	if phase == "otsikko":
		var a := clampf((_t - 0.9) / 0.9, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.06, 0.04, 0.02, 0.25 * a))
		var y := vs.y * 0.17
		_draw_ring_icon(Vector2(vs.x / 2.0, y - 72.0), a)
		var title := "TOKOLAN KAUPPIAAN AARRE"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.16, 0.09, 0.03, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(1.0, 0.84, 0.42, a))
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 158.0, 840, 84)
		_ui.draw_rect(sr, Color(0.06, 0.04, 0.02, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Kuuskymmentä vuotta Tokola nauroi",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.95, 0.8, 0.5, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Aaro oli oikeassa.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Välähdys: nelisakarainen tähti ja hehku.
func _draw_star(c: Vector2, r: float, col: Color) -> void:
	_ui.draw_circle(c, r * 0.35, Color(col.r, col.g, col.b, col.a * 0.35))
	for ang in [0.0, PI / 2.0]:
		var d := Vector2(cos(ang), sin(ang))
		var nrm := Vector2(-d.y, d.x)
		_ui.draw_colored_polygon(PackedVector2Array([c + d * r, c + nrm * r * 0.1, c - d * r, c - nrm * r * 0.1]), col)
	_ui.draw_circle(c, r * 0.12, col)


## Kultasormus otsikon yllä: paksu kultarengas tummalla ääriviivalla, kiiltoviiru ja punainen kivi.
func _draw_ring_icon(c: Vector2, a: float) -> void:
	_ui.draw_arc(c, 24.0, 0.0, TAU, 40, Color(0.2, 0.11, 0.03, a), 13.0)
	_ui.draw_arc(c, 24.0, 0.0, TAU, 40, Color(0.95, 0.72, 0.25, a), 8.0)
	_ui.draw_arc(c, 24.0, PI * 1.1, PI * 1.6, 12, Color(1.0, 0.95, 0.75, a), 3.0)
	var g := c + Vector2(0, -26)
	_ui.draw_circle(g, 9.0, Color(0.2, 0.05, 0.05, a))
	_ui.draw_circle(g, 7.0, Color(0.85, 0.1, 0.15, a))
	_ui.draw_circle(g + Vector2(-2, -2), 2.2, Color(1.0, 0.7, 0.7, a))
