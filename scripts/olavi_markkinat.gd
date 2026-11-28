extends CanvasLayer
## Legendaarinen hetki "olavinmarkkinat" (Olavinmarkkinat palasivat): kun kauppias Skytän taalerit viedään ensimmäistä
## kertaa Saloisten Pirttiin (main.gd _olavi_museum), museo vahvistaa vuoden 1616 ja Olavi-pappa avaa markkinat samana
## päivänä Seuranmäellä. Kohtaus lavastetaan seuraintalon pihalla. Vaiheet:
##   kojut    pihalla kaksi kojua (terva, voi ja makkara), väkeä; Olavi-pappa kuistilla vanha myrskylyhty kädessään
##   lyhty    pappa nostaa lyhdyn: suku kantoi sitä Olavinpäivän yönä neljäsataa vuotta. Hän puhaltaa liekin sammuksiin
##            (savukiehkura) ja ripustaa lyhdyn kuistin pylvään koukkuun: lupaus on täytetty
##   avaus    pappa vetää narusta: banderolli OLAVINMARKKINAT 1616 aukeaa kuistin eteen, pappa nostaa käden ja kello soi;
##            väki nostaa kädet
##   tuoppi   Pekka (epäilijä) ostaa tervakojusta ensimmäisen tervatuopin, haistaa ja nostaa tuopin papalle: "Anteeks, pappa."
##   otsikko  OLAVINMARKKINAT PALASIVAT
## Kehys: pihan solmu G seuraintalon julkisivun keskellä (world.seura_kuisti), paikallinen -Z = poispäin seinästä pihalle,
## +x näkyy pihalta katsoen vasemmalla. Kuistin laatta z -1,8..0, pinta y +0,35 kuistin juurisolmusta; pylväät x ±1,6,
## z -1,7. Maan korkeus Terrain.h:sta. Hahmojen etu -Z (Looks). Lyhty jää kuistin pylvääseen pysyvästi (main.gd
## _olavi_keepsake, build_lantern); Olavi-pappa muistelee myöhemmin (main.gd _talk_olavi "olavi_muisto").

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const T := preload("res://scripts/terrain.gd")

const DUR := {"kojut": 5.5, "lyhty": 7.0, "avaus": 6.5, "tuoppi": 8.0, "otsikko": 6.4}
const ORDER := ["kojut", "lyhty", "avaus", "tuoppi", "otsikko"]
const PORCH_Y := 0.35  # kuistin laatan pinta juurisolmusta
const HOOK := Vector3(1.6, 2.05, -1.79)  # lyhdyn koukku pylvään ulkopinnassa (kuistin juurisolmun koordinaatit)
const BANNER_TOP := 2.9
const BANNER_H := 0.62
const TERVA := Vector2(3.9, -3.2)  # tervakojun tiskin keskusta (koju katsoo -x, pihan keskelle)
const VOI := Vector2(-3.9, -3.4)
## Olavi-pappa (main.gd OLAVI_LOOK): valkoinen parta, harmaa takki.
const OLAVI := {"shirt": Color(0.45, 0.42, 0.35), "pants": Color(0.25, 0.25, 0.22), "shoes": Color(0.2, 0.15, 0.1), "shoe": "kavelykenka",
	"hair": "Hair_Buzzed", "hair_color": Color(0.88, 0.88, 0.86), "beard": true, "height": 1.7, "skin": Color(0.93, 0.74, 0.66), "belly": 0.5}
const HILKKA := {"model": "female", "shirt": Color(0.55, 0.3, 0.45), "pants": Color(0.25, 0.22, 0.3), "shoes": Color(0.3, 0.25, 0.2),
	"shoe": "kavelykenka", "hair": "Hair_Buns", "hair_color": Color(0.85, 0.85, 0.85), "height": 1.58, "skin": Color(0.95, 0.8, 0.74),
	"belly": 0.4}
## Tervamyyjä: talonpoika esiliinassa, ruskea liivi.
const TERVAMIES := {"shirt": Color(0.5, 0.32, 0.18), "pants": Color(0.22, 0.2, 0.18), "shoes": Color(0.15, 0.1, 0.07), "shoe": "tyokenka",
	"hair": "Hair_Buzzed", "hair_color": Color(0.35, 0.25, 0.15), "beard": true, "height": 1.8, "skin": Color(0.92, 0.7, 0.6), "belly": 0.6}
## Voimyyjä (kirppiksen Raili): vihreä neule, punertava tukka.
const RAILI := {"model": "female", "shirt": Color(0.2, 0.45, 0.4), "pants": Color(0.15, 0.15, 0.2), "shoes": Color(0.2, 0.2, 0.2),
	"shoe": "kavelykenka", "hair": "Hair_Long", "hair_color": Color(0.6, 0.25, 0.15), "height": 1.65, "skin": Color(0.96, 0.78, 0.7), "belly": 0.3}
## Olavi-pappa muistelee (main.gd _talk_olavi "olavi_muisto").
const MUISTO := ["Neljäsataa vuotta se lyhty paloi. Ja minä sain sen sammuttaa. Isä ois itkeny.",
	"Pekka tuli eilen hautausmaalle. Toi kukat Skytän kivelle. Ei sanonu mitään, mutta toi.",
	"Se banderolli, kun se aukes! Mää vedin narusta ja aattelin, että nyt se repee. Ei revenny.",
	"Joka Olavinpäivä mää käyn kattomassa sitä lyhtyä kuistilla. Ei sitä tarvi enää sytyttää."]

var world: Node3D
var hide_nodes: Array = []  # oikea pelaaja ja Olavi-pappa piiloon kohtauksen ajaksi (kopiot näyttelevät)
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
var _base_y := 0.0  # kuistin juurisolmun korkeus (maa julkisivun kohdalla)
var _props: Array[Node3D] = []
var me: Node3D
var olavi: Node3D
var hilkka: Node3D
var arto: Node3D
var annaliisa: Node3D
var pekka: Node3D
var tervamies: Node3D
var raili: Node3D
var crowd: Array[Node3D] = []
var lantern: Node3D
var banner: Node3D  # banderollin sarana (yläreuna); scale.y 0..1 aukeaa alas
var _roll: Node3D  # rulla banderollin alareunassa
var _cord: MeshInstance3D
var tuoppi: Node3D
var coin: Node3D
var _smoke: CPUParticles3D
var _awnings: Array[Node3D] = []
var lantern_out := false  # testi lukee
var lantern_hung := false
var banner_open := 0.0


func _ready() -> void:
	layer = 6
	_G = Node3D.new()
	world.add_child(_G)
	_props.append(_G)
	var k: Node3D = world.seura_kuisti
	_base_y = k.global_position.y
	_G.global_position = Vector3(k.global_position.x, 0.0, k.global_position.z)
	_G.rotation.y = k.global_rotation.y
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
	_begin("kojut")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	_build_stall(TERVA, -1.0, Color(0.75, 0.12, 0.1), "TERVAA\ntuopit, tervaskannot", "terva")
	_build_stall(VOI, 1.0, Color(0.15, 0.4, 0.75), "VOITA\nja markkinamakkaraa", "voi")
	_build_banner()
	lantern = build_lantern(world)
	_props.append(lantern)
	_smoke = CPUParticles3D.new()
	_smoke.amount = 40
	_smoke.lifetime = 2.2
	_smoke.emitting = false
	_smoke.direction = Vector3.UP
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 0.12
	_smoke.initial_velocity_max = 0.25
	_smoke.gravity = Vector3(0.05, 0.08, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.8
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	_smoke.scale_amount_curve = curve
	# Pehmeät savuhattarat: kameraan kääntyvät neliöt, säteittäinen liukuväri (ei erillisiä palloja).
	var sm := QuadMesh.new()
	sm.size = Vector2(0.1, 0.1)
	var smm := StandardMaterial3D.new()
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smm.vertex_color_use_as_albedo = true
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(0.88, 0.88, 0.9, 0.7))
	gr.set_color(1, Color(0.85, 0.85, 0.87, 0.0))
	gt.gradient = gr
	smm.albedo_texture = gt
	sm.material = smm
	_smoke.mesh = sm
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	_smoke.color_ramp = fade
	lantern.add_child(_smoke)
	_smoke.position = Vector3(0, 0.27, 0)
	# Kuistin katon alla lämmin lamppu: varjossa olevan papan kasvot erottuvat punaista seinää vasten.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.9, 0.75)
	lamp.light_energy = 0.9
	lamp.omni_range = 4.5
	world.add_child(lamp)
	_props.append(lamp)
	lamp.global_position = _K(0.0, 2.7, -1.6)
	tuoppi = _build_tuoppi(world)
	_props.append(tuoppi)
	coin = Node3D.new()
	world.add_child(coin)
	_props.append(coin)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.85, 0.7, 0.35)
	cm.metallic = 0.9
	cm.roughness = 0.3
	var cmi := B.mesh(coin, B.cyl(0.013, 0.013, 0.003, 14), Vector3.ZERO, Color.WHITE)
	cmi.material_override = cm
	coin.visible = false
	# Hahmot.
	olavi = _person(OLAVI, 0.45, -1.25, true)
	me = _person(Looks.player(), -1.7, -3.1)
	hilkka = _person(HILKKA, -0.7, -3.7)
	Looks.hunch(hilkka, 0.2)
	arto = _person(Looks.ARTO, 0.55, -4.0)
	annaliisa = _person(Looks.ANNA_LIISA, 1.5, -3.5)
	pekka = _person(Looks.PEKKA, 2.3, -4.2)
	tervamies = _person(TERVAMIES, TERVA.x + 0.75, TERVA.y)
	raili = _person(RAILI, VOI.x - 0.75, VOI.y)
	crowd = [me, hilkka, arto, annaliisa, pekka]
	for c in crowd:
		_face(c, _P(0.45, -1.25))
	_face(olavi, _L(0.0, -6.0))
	_face(tervamies, _L(0.0, TERVA.y))
	_face(raili, _L(0.0, VOI.y))


## Markkinakoju: neljä pylvästä, tiski lankuista, raidallinen kangaskatto ja etureunan liehureunus, kyltti katon
## alla. side = koju katsoo paikallista -x:ää (-1) tai +x:ää (+1).
func _build_stall(at: Vector2, side: float, stripe: Color, text: String, kind: String) -> void:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	g.global_position = _L(at.x, at.y)
	g.rotation.y = _G.global_rotation.y + side * PI / 2.0  # koju: oma -Z = etupuoli (asiakas), +Z = myyjä
	var wood := Color(0.58, 0.42, 0.26)
	var w := 2.0
	var d := 1.1
	# Pylväät maahan joka kulmassa (maaston kallistus).
	for x in [-w / 2.0, w / 2.0]:
		for z in [-d / 2.0, d / 2.0]:
			var p := g.to_global(Vector3(x, 0, z))
			var fy := T.h(p.x, p.z) - g.global_position.y
			var top := 2.25 if z < 0 else 2.0
			B.mesh(g, B.boxm(Vector3(0.08, top - fy, 0.08)), Vector3(x, fy + (top - fy) / 2.0, z), wood.darkened(0.15))
	# Tiski: kansi lankuista syineen ja etulauta.
	for i in 3:
		B.mesh(g, B.boxm(Vector3(w, 0.04, 0.2)), Vector3(0, 0.92, -d / 2.0 + 0.12 + i * 0.205), wood.lightened(0.05 * i))
		B.mesh(g, B.boxm(Vector3(w * 0.7, 0.002, 0.004)), Vector3(0.1 * (i - 1), 0.941, -d / 2.0 + 0.1 + i * 0.205), wood.darkened(0.3))
	B.mesh(g, B.boxm(Vector3(w, 0.7, 0.03)), Vector3(0, 0.55, -d / 2.0 - 0.01), wood.darkened(0.08))
	for k in 4:
		B.mesh(g, B.boxm(Vector3(w, 0.004, 0.032)), Vector3(0, 0.25 + k * 0.17, -d / 2.0 - 0.012), wood.darkened(0.35))
	# Kangaskatto: raidat, kalteva taaksepäin, etureunan liehureunus kolmioina.
	var awn := Node3D.new()
	awn.position = Vector3(0, 2.25, -d / 2.0 - 0.15)
	g.add_child(awn)
	_awnings.append(awn)
	var slope := atan2(0.25, d + 0.3)
	awn.rotation.x = -slope
	var n := 8
	for i in n:
		var col := stripe if i % 2 == 0 else Color(0.97, 0.95, 0.9)
		B.mesh(awn, B.boxm(Vector3(w / n + 0.002, 0.012, d + 0.35)), Vector3(-w / 2.0 + (i + 0.5) * w / n, 0.0, (d + 0.35) / 2.0), col)
		var flap := B.mesh(awn, B.boxm(Vector3(w / n, 0.16, 0.01)), Vector3(-w / 2.0 + (i + 0.5) * w / n, -0.08, 0.0), col.darkened(0.08))
		flap.rotation.x = slope
	# Kyltti katon alla etureunassa.
	var sign := B.sign_plate(g, text, Color(0.96, 0.93, 0.84), stripe.darkened(0.3), 0.13, 30, stripe.darkened(0.3), "Helvetica Neue")
	sign.position = Vector3(0, 2.02, -d / 2.0 - 0.03)  # katon alla korkealla: ei peitä asiakkaan kasvoja myyjän puolelta
	sign.rotation.y = PI  # teksti asiakkaan puolelle (-Z)
	# Tavarat tiskillä ja vieressä.
	var top_y := 0.94
	match kind:
		"terva":
			for x in [-0.75, -0.45]:  # tervatynnyrit tiskin vieressä maassa
				_barrel(g, Vector3(x - 0.55, 0, -d / 2.0 - 0.45))
			for i in 5:
				var tp := _build_tuoppi(g)
				tp.position = Vector3(-0.6 + i * 0.22, top_y, -0.2 + 0.08 * (i % 2))
				tp.rotation.y = 0.4 * i
			for i in 3:  # tervaskannot (pihkaiset puunpalat)
				var s := B.mesh(g, B.boxm(Vector3(0.22, 0.07, 0.08)), Vector3(0.55, top_y + 0.035 + i * 0.07, 0.0), Color(0.62, 0.33, 0.14))
				s.rotation.y = 0.3 * i
		"voi":
			for i in 6:  # voipaketit paperissa, sininen leima
				var p := B.mesh(g, B.boxm(Vector3(0.16, 0.06, 0.09)), Vector3(-0.5 + (i % 3) * 0.19, top_y + 0.03 + 0.06 * int(i / 3), -0.15), Color(0.98, 0.94, 0.75))
				B.mesh(p, B.boxm(Vector3(0.07, 0.062, 0.05)), Vector3(0, 0.0, -0.001), Color(0.2, 0.35, 0.75))
			var tub := B.mesh(g, B.cyl(0.14, 0.12, 0.16, 16), Vector3(0.4, top_y + 0.08, -0.1), wood.darkened(0.05))
			B.mesh(tub, B.cyl(0.13, 0.13, 0.01, 16), Vector3(0, 0.075, 0), Color(1.0, 0.88, 0.45))
			for k in 2:
				B.mesh(tub, B.cyl(0.145, 0.145, 0.015, 16), Vector3(0, -0.05 + k * 0.09, 0), Color(0.3, 0.3, 0.3))
			for i in 4:  # makkararengas kiekoilla
				var m := B.mesh(g, B.cyl(0.025, 0.025, 0.22, 10), Vector3(0.75, top_y + 0.025, -0.2 + i * 0.07), Color(0.6, 0.22, 0.15), Vector3(0, 0, PI / 2.0))
				m.rotation.z = PI / 2.0


func _barrel(parent: Node3D, pos: Vector3) -> void:
	var g := Node3D.new()
	parent.add_child(g)
	g.position = pos
	var p := g.global_position
	g.position.y += T.h(p.x, p.z) - parent.global_position.y
	var stave := Color(0.32, 0.22, 0.14)
	B.mesh(g, B.cyl(0.21, 0.21, 0.56, 16), Vector3(0, 0.28, 0), stave)
	var belly := B.mesh(g, B.sphere(0.5, 16), Vector3(0, 0.28, 0), stave.lightened(0.04))
	belly.scale = Vector3(0.47, 0.5, 0.47)
	for y in [0.07, 0.49]:
		B.mesh(g, B.cyl(0.215, 0.215, 0.04, 16), Vector3(0, y, 0), Color(0.18, 0.18, 0.2))
	B.mesh(g, B.cyl(0.2, 0.2, 0.01, 16), Vector3(0, 0.565, 0), Color(0.08, 0.06, 0.04))  # tervainen kansi
	for k in 8:
		var a := k * TAU / 8.0
		B.mesh(g, B.boxm(Vector3(0.006, 0.5, 0.004)), Vector3(cos(a) * 0.232, 0.28, sin(a) * 0.232), stave.darkened(0.35))


## Banderolli kuistin edessä pylväiden välissä: punainen kangas, keltainen teksti ja reunus, ylärima ja narut. Aukeaa
## alas saranasta (scale.y), alareunassa rulla.
func _build_banner() -> void:
	var bar := B.mesh(world, B.cyl(0.025, 0.025, 3.3, 10), Vector3.ZERO, Color(0.45, 0.32, 0.2))
	_props.append(bar)
	bar.global_position = _K(0.0, BANNER_TOP + 0.02, -1.76)
	bar.global_rotation = Vector3(0, _G.global_rotation.y, PI / 2.0)
	banner = Node3D.new()
	world.add_child(banner)
	_props.append(banner)
	banner.global_position = _K(0.0, BANNER_TOP, -1.78)
	banner.rotation.y = _G.global_rotation.y + PI  # teksti pihalle (-Z)
	var plate := B.sign_plate(banner, "OLAVINMARKKINAT · 1616", Color(0.8, 0.12, 0.08), Color(1.0, 0.9, 0.45), BANNER_H - 0.06, 50,
		Color(1.0, 0.9, 0.45), "Helvetica Neue")
	plate.position = Vector3(0, -BANNER_H / 2.0, 0)
	banner.scale = Vector3(1, 0.02, 1)
	_roll = Node3D.new()
	world.add_child(_roll)
	_props.append(_roll)
	var r := B.mesh(_roll, B.cyl(0.05, 0.05, 2.9, 12), Vector3.ZERO, Color(0.75, 0.13, 0.09))
	r.rotation.z = PI / 2.0
	_roll.rotation.y = _G.global_rotation.y
	# Vetonaru oikeasta reunasta kuistille (papan käteen).
	_cord = B.mesh(world, B.cyl(0.005, 0.005, 1.0, 6), Vector3.ZERO, Color(0.9, 0.85, 0.7))
	_props.append(_cord)
	_set_banner(0.0)


func _set_banner(k: float) -> void:
	banner_open = k
	var s := maxf(0.02, k)
	banner.scale = Vector3(1, s, 1)
	_roll.global_position = _K(0.0, BANNER_TOP - BANNER_H * s - 0.03, -1.8)
	_roll.visible = k < 0.97
	var r: MeshInstance3D = _roll.get_child(0)
	r.scale = Vector3(1.0 - 0.6 * k, 1, 1.0 - 0.6 * k)


## Myrskylyhty: peltinen jalka, lasikupu (läpikuultava), suojalangat, hattu ja sanka; sisällä liekki ja valo.
## Liekki ja valo meta-avaimissa "flame" ja "light". Origo jalan pohjassa; sangan yläreuna y 0,36.
static func build_lantern(parent: Node3D) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	var tin := StandardMaterial3D.new()
	tin.albedo_color = Color(0.32, 0.36, 0.3)
	tin.metallic = 0.6
	tin.roughness = 0.5
	var add := func(m: Mesh, pos: Vector3) -> MeshInstance3D:
		var mi := B.mesh(g, m, pos, Color.WHITE)
		mi.material_override = tin
		return mi
	add.call(B.cyl(0.07, 0.075, 0.07, 16), Vector3(0, 0.035, 0))  # säiliö
	add.call(B.cyl(0.072, 0.072, 0.008, 16), Vector3(0, 0.072, 0))
	var glass := B.mesh(g, B.sphere(0.5, 16), Vector3(0, 0.15, 0), Color.WHITE)
	glass.scale = Vector3(0.11, 0.16, 0.11)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.9, 0.85, 0.7, 0.28)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.05
	gm.metallic_specular = 1.0
	glass.material_override = gm
	for k in 4:  # suojalangat kuvun ympärillä
		var a := k * TAU / 4.0 + PI / 4.0
		var wv := B.mesh(g, B.boxm(Vector3(0.005, 0.16, 0.005)), Vector3(cos(a) * 0.06, 0.15, sin(a) * 0.06), Color.WHITE)
		wv.material_override = tin
	add.call(B.cyl(0.035, 0.065, 0.04, 16), Vector3(0, 0.245, 0))  # hattu
	add.call(B.cyl(0.02, 0.03, 0.025, 12), Vector3(0, 0.275, 0))
	var bail := B.mesh(g, B.cyl(0.004, 0.004, 0.16, 6), Vector3(0, 0.3, 0), Color(0.25, 0.25, 0.25))
	bail.rotation.z = PI / 2.0
	for x in [-0.075, 0.075]:
		var arm := B.mesh(g, B.cyl(0.004, 0.004, 0.12, 6), Vector3(x, 0.24, 0), Color(0.25, 0.25, 0.25))
		arm.rotation.z = -signf(x) * 0.12
	var top := B.mesh(g, B.cyl(0.004, 0.004, 0.1, 6), Vector3(0, 0.335, 0), Color(0.25, 0.25, 0.25))
	top.rotation.z = PI / 2.0
	B.mesh(g, B.cyl(0.004, 0.004, 0.06, 6), Vector3(-0.05, 0.32, 0), Color(0.25, 0.25, 0.25)).rotation.z = 0.8
	B.mesh(g, B.cyl(0.004, 0.004, 0.06, 6), Vector3(0.05, 0.32, 0), Color(0.25, 0.25, 0.25)).rotation.z = -0.8
	var flame := Node3D.new()
	flame.position = Vector3(0, 0.12, 0)
	g.add_child(flame)
	var fm := B.unshaded(Color(1.0, 0.75, 0.3, 0.9))
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var f1 := B.mesh(flame, B.sphere(0.5, 10), Vector3(0, 0.025, 0), Color.WHITE)
	f1.scale = Vector3(0.03, 0.07, 0.03)
	f1.material_override = fm
	var core := B.mesh(flame, B.sphere(0.5, 8), Vector3(0, 0.015, 0), Color.WHITE)
	core.scale = Vector3(0.014, 0.035, 0.014)
	var cmat := B.unshaded(Color(1.0, 0.97, 0.85))
	core.material_override = cmat
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 0.6
	light.omni_range = 2.5
	light.position = Vector3(0, 0.15, 0)
	g.add_child(light)
	g.set_meta("flame", flame)
	g.set_meta("light", light)
	return g


## Tervatuoppi: puusta veistetty kannellinen tuoppi (tummat kyljet, kaksi vannetta, kahva), sisältä tervanmusta.
func _build_tuoppi(parent: Node3D) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	var wood := Color(0.42, 0.26, 0.13)
	B.mesh(g, B.cyl(0.05, 0.056, 0.13, 14), Vector3(0, 0.065, 0), wood)
	for y in [0.02, 0.11]:
		B.mesh(g, B.cyl(0.058, 0.058, 0.014, 14), Vector3(0, y, 0), Color(0.22, 0.14, 0.08))
	B.mesh(g, B.cyl(0.044, 0.044, 0.004, 14), Vector3(0, 0.128, 0), Color(0.05, 0.04, 0.03))  # terva
	for k in 7:  # puun syyt
		var a := k * TAU / 7.0
		B.mesh(g, B.boxm(Vector3(0.003, 0.1, 0.002)), Vector3(cos(a) * 0.054, 0.065, sin(a) * 0.054), wood.darkened(0.3))
	B.mesh(g, B.boxm(Vector3(0.016, 0.085, 0.018)), Vector3(0.075, 0.068, 0), wood.darkened(0.1))  # kahva
	for y in [0.105, 0.03]:
		B.mesh(g, B.boxm(Vector3(0.03, 0.014, 0.018)), Vector3(0.062, y, 0), wood.darkened(0.1))
	return g


func _person(look: Dictionary, x: float, z: float, porch := false) -> Node3D:
	var c: Node3D = Looks.make(world, look)
	_props.append(c)
	if porch:
		c.global_position = _P(x, z)
	else:
		_stand(c, x, z)
	c.play("Idle", 0.0)
	return c


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	for c in [me, olavi, hilkka, arto, annaliisa, pekka, tervamies, raili]:
		c.clear_ik()
		_relax(c)
	match p:
		"kojut":
			_story = "Pirtti vahvisti taalerit: vuosi 1616. Samana päivänä Seuranmäellä…"
		"lyhty":
			_story = ""
		"avaus":
			_story = ""
			_lantern_on_hook()
			_set_flame(false)
		"tuoppi":
			_story = ""
			_lantern_on_hook()
			_set_flame(false)
			_set_banner(1.0)
		"otsikko":
			_story = ""
			_lantern_on_hook()
			_set_flame(false)
			_set_banner(1.0)
			_stand(pekka, 2.4, -3.6)
			coin.visible = false
			Sfx.play("win", -6.0, 0.95)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa E-painalluksesta Pirtin ovella: sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "kojut" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"kojut":
			_step_kojut(delta)
		"lyhty":
			_step_lyhty(delta)
		"avaus":
			_step_avaus(delta)
		"tuoppi":
			_step_tuoppi(delta)
		"otsikko":
			_step_otsikko(delta)
	for i in _awnings.size():  # kangaskaton liehureunus tuulessa
		_awnings[i].rotation.z = 0.012 * sin(_t * 2.3 + i * 1.7)
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


func _step_kojut(_delta: float) -> void:
	# Väki kuistin edessä, pappa lyhty kädessä. Leveä kuva: kuisti keskellä, kojut reunoilla (leveys 11 m).
	_hold_lantern(0.0)
	if _t > 1.4 and _t < 3.6:
		_bub[annaliisa] = "Kattokaa. Pappa toi sen lyhdyn."
	if _t >= 3.6:
		_bub.erase(annaliisa)
		_bub[hilkka] = "Ihan päivällä. Ei se oo ennen päivällä tullu."
	var look := _L(0.0, -2.4, 1.6)
	var eye := _L(0.0, -12.0, 3.4)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 11.5))


func _step_lyhty(_delta: float) -> void:
	# 0-2,6 s lyhty kasvojen eteen ja puhe; 2,6-3,4 s puhallus (liekki lepattaa ja sammuu, savu); 3,8-6 s ripustus koukkuun.
	var raise := clampf(_t / 0.9, 0.0, 1.0)
	if _t < 3.6:
		_hold_lantern(raise)
		if _t > 2.6:
			var k := clampf((_t - 2.6) / 0.5, 0.0, 1.0)
			var fl: Node3D = lantern.get_meta("flame")
			fl.scale = Vector3(1.0 + 0.6 * k, maxf(0.01, 1.0 - k), 1.0 + 0.6 * k)
			fl.rotation.z = 0.5 * k
			(lantern.get_meta("light") as OmniLight3D).light_energy = 0.6 * (1.0 - k)
			olavi.set_override("neck_01", Vector3.RIGHT, 0.15 * sin(clampf((_t - 2.6) / 0.6, 0.0, 1.0) * PI))
			if k >= 1.0 and not lantern_out:
				lantern_out = true
				_set_flame(false)
				_smoke.emitting = true
				Sfx.play("whoosh", -10.0, 1.8)
	else:
		# Pappa kääntyy pylväälle ja ripustaa lyhdyn koukkuun.
		var hk := _K(HOOK.x, HOOK.y, HOOK.z)
		var k := clampf((_t - 3.6) / 1.4, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		olavi.global_position = _P(0.45, -1.25).lerp(_P(1.12, -1.45), e)
		_face(olavi, _K(HOOK.x + 0.3, 0.0, HOOK.z - 0.15).lerp(_L(0.0, -6.0), 0.0) if k > 0.3 else _L(0.0, -6.0))
		if k < 1.0:
			var tgt := _lantern_hand_pos().lerp(hk + Vector3(0, -0.02, 0), e)
			_hand_to(olavi, "l", tgt, 1.0)
			lantern.global_position = _hand(olavi, "l") - Vector3(0, 0.34, 0)
			lantern.global_rotation = Vector3(0, _G.global_rotation.y, 0)
		else:
			_lantern_on_hook()
			if not lantern_hung:
				lantern_hung = true
				Sfx.play("rattle", -12.0, 1.4)
		if _t > 5.4:
			olavi.clear_ik()
			_face(olavi, _L(0.0, -6.0))
	if _t > 0.6 and _t < 2.6:
		_bub[olavi] = "Neljäsataa vuotta Skytän suku kanto tätä lyhtyä Olavinpäivän yönä."
	elif _t >= 2.6 and _t < 3.4:
		_bub.erase(olavi)
	elif _t >= 3.4:
		_bub[olavi] = "Nyt sen saa sammuttaa." if _t < 5.4 else "Lupaus on pidetty."
	for c in crowd:
		_face(c, olavi.global_position)
	# Ensin puolilähikuva: papan kasvot ja lyhty (leveys 1,5 m); ripustuksessa kuva levenee pylvääseen (2,6 m).
	var hd := olavi.to_global(olavi.bone_position("Head"))
	var out := _G.global_basis * Vector3(0, 0, -1)
	var side := _G.global_basis * Vector3(1, 0, 0)
	var look: Vector3
	var eye: Vector3
	var w: float
	if _t < 3.6:
		look = hd + Vector3(0, -0.15, 0) + side * 0.1
		eye = look + out * 2.6 - side * 0.7 + Vector3(0, -0.1, 0)
		w = 2.1
	else:
		look = _K(0.95, 1.8, -1.4)
		eye = look + out * 3.6 - side * 1.2 + Vector3(0, -0.1, 0)
		w = 2.7
	_cam_at(eye, look, _fov_w(eye.distance_to(look), w))


func _step_avaus(_delta: float) -> void:
	# Pappa ottaa narun (0,4-1,2 s) ja vetää (1,4-2,2 s): banderolli aukeaa. Käsi ylös ja kello (2,6 s), väki hurraa.
	olavi.global_position = _P(0.3, -1.4)
	_face(olavi, _L(0.0, -6.0))
	var cord_top := _K(-1.45, BANNER_TOP - 0.02, -1.78)
	var grab := clampf((_t - 0.4) / 0.8, 0.0, 1.0)
	var pull := clampf((_t - 1.4) / 0.8, 0.0, 1.0)
	_set_banner(pull * pull * (3.0 - 2.0 * pull))
	if pull > 0.0 and not _once.has("veto"):
		_once["veto"] = true
		Sfx.play("cloth", -2.0, 0.8)
	var hand_end: Vector3
	if _t < 2.4:
		var rest := olavi.to_global(olavi.bone_position("upperarm_r") + Vector3(-0.12, -0.42, -0.08))
		var cord_hand := cord_top.lerp(_K(-0.6, 1.5, -1.6), 0.55 + 0.4 * pull)
		_hand_to(olavi, "r", rest.lerp(cord_hand, grab), 1.0)
		hand_end = _hand(olavi, "r")
	else:
		var up := clampf((_t - 2.4) / 0.4, 0.0, 1.0)
		_arm_up(olavi, "r", up)
		hand_end = _K(-0.6, 1.4, -1.65)
		if not _once.has("kello"):
			_once["kello"] = true
			for i in 3:
				get_tree().create_timer(0.35 * i).timeout.connect(func() -> void: Sfx.play("bell", -3.0, 0.55))
	_place_cord(cord_top, hand_end)
	var cheer := clampf((_t - 2.9) / 0.4, 0.0, 1.0)
	for c in crowd:
		_face(c, olavi.global_position)
		_hands_up(c, cheer * (0.75 + 0.25 * sin(_t * 9.0 + c.get_instance_id() % 7)))
	if cheer > 0.0 and not _once.has("hurraa"):
		_once["hurraa"] = true
		Sfx.play("win", -5.0, 1.0)
	if _t > 2.6:
		_bub[olavi] = "Saloisten vapaat markkinat on auki!"
	# Kuva väen takaa ylös kuistille: banderolli ja pappa keskellä, väen päät alareunassa (leveys 4,6 m).
	var look := _K(0.0, 2.05, -1.6)
	var eye := _L(-0.6, -6.6, 1.75)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.6))


func _step_tuoppi(_delta: float) -> void:
	# Pekka kävelee tiskille (0-1,6 s), maksaa (1,8 s), saa tuopin (2,4-3,0 s), haistaa (3,0-4,8 s) ja kääntyy papalle (5,0 s-).
	var front := Vector2(TERVA.x - 0.85, TERVA.y)
	var k := clampf(_t / 1.6, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var p := Vector2(2.3, -4.2).lerp(front, e)
	_stand(pekka, p.x, p.y)
	pekka.play("Walk" if k > 0.0 and k < 1.0 else "Idle", 0.2)
	var counter := _L(TERVA.x - 0.3, TERVA.y, 0.94)
	if _t < 5.0:
		_face(pekka, _L(TERVA.x + 1.0, TERVA.y))
	else:
		_face(pekka, olavi.global_position)
	_face(tervamies, pekka.global_position)
	# Kolikko Pekalta tiskille.
	if _t > 1.6 and _t < 2.3:
		_hand_to(pekka, "r", counter + Vector3(0, 0.06, 0), clampf((_t - 1.6) / 0.3, 0.0, 1.0))
		coin.visible = true
		coin.global_position = _hand(pekka, "r")
		if not _once.has("raha"):
			_once["raha"] = true
			Sfx.play("coin", -4.0)
	elif _t >= 2.3:
		coin.visible = true
		coin.global_position = counter + Vector3(0, 0.003, 0)
	# Tuoppi myyjältä Pekalle, sitten nenän alle ja ylös papalle.
	if _t < 2.4:
		tuoppi.global_position = counter + Vector3(0, 0.0, 0) + _G.global_basis.z * 0.12
		tuoppi.global_rotation = Vector3(0, _G.global_rotation.y, 0)
		if _t > 1.9:
			_hand_to(tervamies, "r", tuoppi.global_position + Vector3(0, 0.08, 0), clampf((_t - 1.9) / 0.4, 0.0, 1.0))
	else:
		var hd := pekka.to_global(pekka.bone_position("Head"))
		var fwd := -pekka.global_basis.z
		var chest := pekka.to_global(pekka.bone_position("upperarm_r")) + fwd * 0.35 + Vector3(0, -0.15, 0)
		var nose := hd + fwd * 0.16 + Vector3(0, -0.1, 0)
		var toast := pekka.to_global(pekka.bone_position("upperarm_r")) + fwd * 0.3 + Vector3(0, 0.3, 0)
		var tgt: Vector3
		if _t < 3.0:
			tgt = counter.lerp(chest, clampf((_t - 2.4) / 0.6, 0.0, 1.0))
		elif _t < 5.0:
			tgt = chest.lerp(nose, clampf((_t - 3.0) / 0.5, 0.0, 1.0))
		else:
			tgt = nose.lerp(toast, clampf((_t - 5.0) / 0.5, 0.0, 1.0))
		_hand_to(pekka, "r", tgt, 1.0)
		tuoppi.global_position = _hand(pekka, "r") + Vector3(0, -0.06, 0)
		tuoppi.global_rotation = Vector3(0, pekka.global_rotation.y + PI / 2.0, 0)
		if _t > 3.0 and _t < 4.8:
			pekka.set_override("neck_01", Vector3.RIGHT, 0.2)
	if _t > 0.3 and _t < 1.9:
		_bub[pekka] = "Yks tervatuoppi. Mää oon eka."
	elif _t >= 1.9 and _t < 3.1:
		_bub.erase(pekka)
		_bub[tervamies] = "Ensimmäinen kauppa! Kymmenen euroa."
	elif _t >= 3.1 and _t < 5.0:
		_bub.erase(tervamies)
		_bub[pekka] = "…Haisee ihan oikeilta markkinoilta."
	elif _t >= 5.0 and _t < 6.6:
		_bub[pekka] = "Anteeks, pappa. Kaljapuheita, mää sanoin."
	elif _t >= 6.6:
		_bub.erase(pekka)
		_bub[olavi] = "Kauppias Skyttä ois tyytyväinen."
	for c in [me, hilkka, arto, annaliisa]:
		_face(c, pekka.global_position)
	_face(olavi, pekka.global_position)
	# Ensin tiskin vierestä: Pekka ja myyjä profiilissa, tuoppi isona (leveys 2,2 m); kun Pekka kääntyy papalle, kuva
	# Pekan selän takaa kohti kuistia, jossa pappa ja lyhty (leveys 6,5 m).
	var look: Vector3
	var eye: Vector3
	var w: float
	if _t < 5.0:
		# Myyjän olan yli: Pekan kasvot ja tuoppi tiskin takaa (takapylväät jäävät sivuille).
		look = _L(TERVA.x - 0.85, TERVA.y, 1.5)
		eye = _L(TERVA.x + 1.4, TERVA.y - 0.9, 1.6)
		w = 2.2
	else:
		look = _L(1.6, -2.5, 1.6)
		eye = _L(2.0, -7.6, 2.2)
		w = 5.6
	_cam_at(eye, look, _fov_w(eye.distance_to(look), w))


func _step_otsikko(_delta: float) -> void:
	# Pekka nostaa tuopin papalle, muut kääntyvät Pekkaan. Kuva pihan oikealta etuviistosta: kasvot näkyvät.
	for c in [me, hilkka, arto, annaliisa]:
		_face(c, pekka.global_position.lerp(olavi.global_position, 0.4))
	_face(pekka, olavi.global_position)
	olavi.global_position = _P(0.3, -1.4)
	_face(olavi, _L(0.0, -6.0))
	tuoppi.global_position = _hand(pekka, "r") + Vector3(0, -0.06, 0)
	_hand_to(pekka, "r", pekka.to_global(pekka.bone_position("upperarm_r")) + (-pekka.global_basis.z) * 0.3 + Vector3(0, 0.25, 0), 1.0)
	tuoppi.global_position = _hand(pekka, "r") + Vector3(0, -0.06, 0)
	tuoppi.global_rotation = Vector3(0, pekka.global_rotation.y + PI / 2.0, 0)
	var look := _L(0.5, -2.4, 1.5)
	var eye := _L(4.6, -9.6, 2.7)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 9.0))


# --- Esineet ja hahmot --------------------------------------------------------------

## Lyhty papan vasemmassa kädessä: alhaalla kyljellä (w = 0) tai kasvojen edessä (w = 1).
func _hold_lantern(w: float) -> void:
	var tgt := _lantern_hand_pos(w)
	_hand_to(olavi, "l", tgt, 1.0)
	lantern.global_position = _hand(olavi, "l") - Vector3(0, 0.34, 0)
	lantern.global_rotation = Vector3(0, _G.global_rotation.y, 0)
	if not lantern_out:
		var fl: Node3D = lantern.get_meta("flame")
		fl.scale = Vector3(1.0, 0.9 + 0.12 * sin(_t * 17.0) * sin(_t * 5.0), 1.0)


func _lantern_hand_pos(w := 1.0) -> Vector3:
	var sh := olavi.to_global(olavi.bone_position("upperarm_l"))
	var fwd := -olavi.global_basis.z
	var right := olavi.global_basis.x
	var low := sh + Vector3(0, -0.52, 0) + right * signf((olavi.to_local(sh)).x) * 0.12 + fwd * 0.08
	# Ylhäällä lyhty kasvojen vieressä (ei peitä kasvoja): olan korkeudelta hieman ylös, eteen ja ulospäin.
	var high := sh + Vector3(0, 0.22, 0) + fwd * 0.34 + right * signf((olavi.to_local(sh)).x) * 0.1
	return low.lerp(high, w)


func _lantern_on_hook() -> void:
	var hk := _K(HOOK.x, HOOK.y, HOOK.z)
	lantern.global_position = hk - Vector3(0, 0.36, 0)
	lantern.global_rotation = Vector3(0, _G.global_rotation.y, 0)
	lantern_hung = true


func _set_flame(on: bool) -> void:
	(lantern.get_meta("flame") as Node3D).visible = on
	(lantern.get_meta("light") as OmniLight3D).visible = on
	if not on:
		lantern_out = true


func _place_cord(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) / 2.0
	var d := b - a
	_cord.global_position = mid
	if d.length() > 0.01:
		var up := d.normalized()
		var x := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		_cord.global_basis = Basis(x, up * d.length(), x.cross(up))  # verkon korkeus 1 m venytetään narun mittaiseksi


func _hands_up(c: Node3D, w: float) -> void:
	if w <= 0.01:
		return
	for side in ["r", "l"]:
		_arm_up(c, side, w)


func _arm_up(c: Node3D, side: String, w: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm_" + side)
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.45, -0.05)
	var up := sh + Vector3(s * 0.18, 0.5, -0.12)
	c.set_ik("arm_" + side, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, rest.lerp(up, w), sh + Vector3(s * 0.45, -0.2, 0.25))


## Käsi (r/l) kohti globaalia pistettä painolla w (0 = lepo kyljellä).
func _hand_to(c: Node3D, side: String, at_global: Vector3, w: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm_" + side)
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at_global), w)
	c.set_ik("arm_" + side, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, tgt, sh + Vector3(s * 0.45, -0.25, 0.25))


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


func _hand(c: Node3D, side := "r") -> Vector3:
	return c.to_global((c.bone_position("hand_" + side) + c.bone_position("index_01_" + side)) / 2.0)


# --- Kehys, kamera ------------------------------------------------------------------

## Pihan piste (x, z) maanpinnalla + y.
func _L(x: float, z: float, y := 0.0) -> Vector3:
	var p := _G.to_global(Vector3(x, 0.0, z))
	return Vector3(p.x, T.h(p.x, p.z) + y, p.z)


## Kuistin juurisolmun koordinaateissa (y juurisolmun korkeudesta).
func _K(x: float, y: float, z: float) -> Vector3:
	var p := _G.to_global(Vector3(x, 0.0, z))
	return Vector3(p.x, _base_y + y, p.z)


## Piste kuistin laatalla (x, z) + y.
func _P(x: float, z: float, y := 0.0) -> Vector3:
	return _K(x, PORCH_Y + y, z)


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
	if phase != "otsikko":
		for c: Node3D in _bub:
			if is_instance_valid(c) and c.visible:
				Room.bubble(_ui, _cam, c, _bub[c], 90.0, 120.0)
	if phase == "otsikko":
		var a := clampf((_t - 0.9) / 0.9, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.08, 0.03, 0.02, 0.22 * a))
		var y := vs.y * 0.22
		_draw_lantern_icon(Vector2(vs.x / 2.0, y - 80.0), a)
		var title := "OLAVINMARKKINAT PALASIVAT"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.25, 0.04, 0.02, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(1.0, 0.88, 0.45, a))
		var sr := Rect2(vs.x / 2.0 - 440, vs.y - 158.0, 880, 84)
		_ui.draw_rect(sr, Color(0.08, 0.04, 0.03, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Kauppias Skytän hopea löytyi 1616 vuoden taalereina",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(1.0, 0.85, 0.55, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Olavi-pappa avasi markkinat, ja Pekka osti tervatuopin.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Sammunut myrskylyhty otsikon yllä: jalka, kupu, hattu ja sanka, savukiehkura.
func _draw_lantern_icon(c: Vector2, a: float) -> void:
	var dark := Color(0.2, 0.08, 0.04, a)
	var tin := Color(0.55, 0.6, 0.5, a)
	_ui.draw_rect(Rect2(c + Vector2(-17, 18), Vector2(34, 12)), tin)
	_ui.draw_rect(Rect2(c + Vector2(-17, 18), Vector2(34, 12)), dark, false, 2.0)
	var glass := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		glass.append(c + Vector2(cos(t) * 15.0, sin(t) * 19.0))
	_ui.draw_colored_polygon(glass, Color(0.95, 0.9, 0.75, 0.45 * a))
	glass.append(glass[0])
	_ui.draw_polyline(glass, dark, 2.0)
	_ui.draw_colored_polygon(PackedVector2Array([c + Vector2(-15, -16), c + Vector2(15, -16), c + Vector2(7, -26), c + Vector2(-7, -26)]), tin)
	_ui.draw_arc(c + Vector2(0, -26), 14.0, PI, TAU, 16, dark, 2.5)
	var smoke := PackedVector2Array()
	for i in 12:
		var t := i / 11.0
		smoke.append(c + Vector2(sin(t * 7.0) * 6.0, -42.0 - t * 30.0))
	_ui.draw_polyline(smoke, Color(0.85, 0.85, 0.85, 0.7 * a), 2.5)
