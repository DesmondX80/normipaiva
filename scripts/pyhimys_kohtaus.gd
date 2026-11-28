extends CanvasLayer
## Legendaarinen hetki "palon_pyhimys" (Palon yön pyhimys): kun Tokolan orrelta löytynyt pyhimys annetaan ensimmäistä kertaa
## suntiolle (main.gd _talk_pyhimys "pyhimys_anna"), hetki lavastetaan Saloisten kirkon portailla ja talollisen haudalla.
## Hiljainen ja kunnioittava: ei voitonhuutoja, ei tarjoilua. Vaiheet:
##   kaare     portailla pelaaja ojentaa nahkakääreen, suntio avaa läpät ja nostaa pyhimyksen esiin: naisen kaiverretut
##             kasvot, palon noki pohjassa
##   luettelo  suntio laskee pyhimyksen pöydälle avoimen esineluettelon viereen ja kulkee sormella yliviivatun rivin
##             "Pieni pyhimyskuva, puuta" yli. "Kirjoitusvirhe, minä sanoin." Hän kirjoittaa viereen: palautettu.
##   nimi      "Mistä talosta se löytyi?" - "Suvun nimeä ei mainita." Suntio nyökkää ("Ei mainita."), sulkee kirjan ja
##             nostaa pyhimyksen molemmin käsin
##   ovi       ovet aukeavat ja asehuoneen kynttilänvalo lankeaa portaille; suntio kantaa pyhimyksen sisään seinäsyvennykseen
##             kahden kynttilän väliin ja painaa päänsä; ovet sulkeutuvat ja tapulin kello lyö kerran
##   kynttila  talollisen haudalla iäkäs nainen kynttilän ääressä kädet ristissä, hoitaja pysähtyy haravoimasta; vire
##             sammuttaa kynttilän ja savukiehkura nousee. "Nyt se on kotona." Nainen lähtee kirkolle päin.
##   otsikko   PALON YÖN PYHIMYS: suvun nimi pysyi salassa, ja kynttilä sammui
## Kehykset: ovi = world.kirkko_ovi (oven pinta maan tasossa, paikallinen -Z = ulos portaille, +Z = tornin sisään).
## Portaiden taso z -1,4..0, korkeus 0,3 m (world.gd _build_kirkko). Torni ulottuu z 0..5,2 ja x ±2,8. Kohtauksen ajaksi
## tornin umpinainen laatikko, oven karmi ja oikeat ovilehdet piilotetaan, ja tilalle rakennetaan seinät oviaukolla ja
## asehuone (lattia 0,3, väliseinä syvennyksineen z 3,0); lopuksi alkuperäiset palautetaan. Ovilehdet aukeavat
## ulospäin saranoistaan x = ±1,22, joten pöytä on oven sivulla x > 1,3 eikä kukaan seiso lehtien kaaressa niiden
## liikkuessa. Hauta = world.kynttila_hauta (paikallinen -Z = hautakivi z -0,8, kynttilälyhty z -0,45, hauta-alue +z).
## Hahmojen etu -Z (Looks). Oikea pelaaja, suntio, hoitaja ja nainen piiloon kohtauksen ajaksi (kopiot näyttelevät).
## Suntio muistelee myöhemmin (main.gd "pyhimys_muisto").

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const T := preload("res://scripts/terrain.gd")

const DUR := {"kaare": 7.4, "luettelo": 8.4, "nimi": 7.0, "ovi": 9.6, "kynttila": 9.0, "otsikko": 6.6}
const ORDER := ["kaare", "luettelo", "nimi", "ovi", "kynttila", "otsikko"]
const LANDING_Z := -1.4  # portaiden ulkoreuna
const FLOOR_H := 0.3  # portaiden ja asehuoneen lattian korkeus
const HINGE_X := 1.22  # ovilehtien saranat
const LEAF := Vector2(1.22, 3.2)  # yhden ovilehden leveys ja korkeus
const LEAF_Z := -0.14  # kohtauksen ovilehdet oviaukon eteen
const TOWER := Vector3(2.8, 11.5, 5.2)  # tornin puolileveys (x), korkeus ja syvyys (z)
const WALL_T := 0.25
const INNER_Z := 2.4  # asehuoneen väliseinän etupinta (syvennys)
const TABLE := Vector3(1.56, 0.82, -0.6)  # pöydän keskusta (x, korkeus lattiasta, z)
const TABLE_SIZE := Vector2(0.4, 0.8)
const SUNTIO_AT := Vector2(0.0, -0.5)
const ME_AT := Vector2(0.0, -1.22)
const ME_ASIDE := Vector2(-0.85, -1.12)
const SUNTIO_TABLE := Vector2(1.56, -1.1)  # pöydän edessä kasvot sisään (+Z); pöydän reuna z -1,0
const SUNTIO_DOOR := Vector2(0.0, -0.8)
const SUNTIO_NICHE := Vector2(0.0, INNER_Z - 0.5)
const BOOK_AT := Vector2(1.62, -0.8)  # kirjan keskusta pöydällä, käden ulottuvilla
const SAINT_TABLE := Vector2(1.415, -0.78)  # pyhimys pöydällä kirjan oikealla puolella (suntion oikealla)
const NICHE_Y := 1.38  # syvennyksen hyllyn korkeus lattiasta (pyhimys näkyy suntion olan yli)
const PW := 0.13  # kirjan sivun leveys
const PH := 0.2
const LINE0 := 0.026  # ensimmäisen rivin etäisyys sivun yläreunasta
const LINE_DZ := 0.022
## Haudan kehys: nainen hautakiven vieressä, hoitaja haravan kanssa polulla.
const NAINEN_AT := Vector2(0.78, -0.15)
const HOITAJA_AT := Vector2(3.2, 1.6)
const FLAME_AT := Vector3(0.0, 0.305, -0.45)  # kynttilän liekki lyhdyn päällä (haudan paikallinen)
const WRITTEN := "← palautettu"

## Suntio muistelee myöhemmin (main.gd _talk_pyhimys "pyhimys_muisto").
const MUISTO := ["Joka loppiainen minä avaan luettelon. Yliviivattu rivi, ja vieressä minun käsialallani: palautettu.",
	"Kynttilää ei ole sen jälkeen näkynyt. Hoitaja sanoo, että hyvä niin. Minä sanon samaa.",
	"Iäkäs rouva käy joka vuosipäivä asehuoneessa ja seisoo hetken syvennyksen edessä. Minä en kysy mitään. Niin sovittiin.",
	"Kirjoitusvirhe, minä sanoin. Sitä lausetta minä kadun vieläkin, nuori mies."]

var world: Node3D
var hide_nodes: Array = []  # oikea pelaaja, suntio, hoitaja ja nainen piiloon kohtauksen ajaksi
var suntio_look: Dictionary = {}
var nainen_look: Dictionary = {}
var hoitaja_look: Dictionary = {}
var _was_visible := {}
var _tower_hidden: Array[Node3D] = []  # tornin umpilaatikko, karmi ja oikeat ovilehdet (palautetaan lopuksi)

var phase := ""
var _t := 0.0
var _cam: Camera3D
var _ui: Control
var _keys: Node
var _story := ""
var _bub := {}
var _once := {}
var _D: Node3D  # oven kehys
var _H: Node3D  # haudan kehys
var _props: Array[Node3D] = []
var me: Node3D
var suntio: Node3D
var nainen: Node3D
var hoitaja: Node3D
var bundle: Node3D  # nahkakääre (pohja ja läpät)
var flaps: Array[Node3D] = []
var cord: MeshInstance3D
var saint: Node3D
var book: Node3D
var book_cover: Node3D  # kirjan oikea puolisko (sulkeutuu)
var written: Label3D  # "palautettu" (kirjoitetaan)
var written_chars := 0  # testi lukee
var pen: Node3D
var leaves: Array[Node3D] = []  # ovilehtien saranat [vasen +x, oikea -x]
var glow_light: SpotLight3D  # asehuoneesta portaille lankeava valo
var hall_light: OmniLight3D
var crack: MeshInstance3D  # valorako suljettujen ovien välissä
var rake: Node3D
var flame: Node3D
var flame_light: OmniLight3D
var _smoke: CPUParticles3D
var flame_out := false  # testi lukee
var door_open := 0.0  # 0 kiinni, 1 auki (testi lukee)
var saint_in_niche := false  # testi lukee
var _saint_held_by: Node3D = null
var _church_dir := Vector2(0, 1)  # haudalta kirkolle (haudan kehyksessä x, z)


func _ready() -> void:
	layer = 6
	process_priority = 100  # hahmojen asento lasketaan ensin, sitten esineet käsiin
	_D = Node3D.new()
	world.add_child(_D)
	_props.append(_D)
	_D.global_transform = world.kirkko_ovi.global_transform
	_H = Node3D.new()
	world.add_child(_H)
	_props.append(_H)
	_H.global_transform = world.kynttila_hauta.global_transform
	var cd := _H.to_local(world.kirkko_pos)
	_church_dir = Vector2(cd.x, cd.z).normalized()
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
	_begin("kaare")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	_build_tower()
	_build_doors()
	_build_table()
	book = _build_book()
	saint = _build_saint()
	world.add_child(saint)
	_props.append(saint)
	bundle = _build_bundle()
	pen = _build_pen()
	pen.visible = false
	rake = _build_rake()
	_build_flame()
	me = _person(Looks.player(), ME_AT.x, ME_AT.y)
	suntio = _person(suntio_look, SUNTIO_AT.x, SUNTIO_AT.y)
	nainen = _person(nainen_look, 0, 0)
	hoitaja = _person(hoitaja_look, 0, 0)
	_stand_h(nainen, NAINEN_AT.x, NAINEN_AT.y)
	_stand_h(hoitaja, HOITAJA_AT.x, HOITAJA_AT.y)
	_face(me, suntio.global_position)
	_face(suntio, me.global_position)


## Torni sisätiloineen: piilotetaan world.gd:n umpilaatikko, karmi ja ovilehdet (world.kirkko_torni_osat) ja
## rakennetaan tilalle valkoiset seinät, joissa oviaukko, sekä asehuone: lankkulattia, katto, väliseinä z = 3,0, jonka
## puusyvennyksessä on hylly pyhimykselle, kaksi messinkistä kynttilänjalkaa palavine kynttilöineen, penkki ja
## virsitaulu. Sisällä lämmin valo; ulos portaille lankeaa valokeila, kun ovet aukeavat.
func _build_tower() -> void:
	for c: MeshInstance3D in world.kirkko_torni_osat:
		if is_instance_valid(c) and c.visible:
			_tower_hidden.append(c)
			c.visible = false
	var wall := Color(0.94, 0.93, 0.88)
	var g := Node3D.new()
	_D.add_child(g)
	var hx := TOWER.x
	var h := TOWER.y
	var d := TOWER.z
	var t := WALL_T
	var dw := HINGE_X + 0.04  # oviaukon puolileveys
	var dh := 0.2 + LEAF.y  # oviaukon yläreuna
	# Etuseinä oviaukon ympärillä, sivu- ja takaseinät.
	for sx: float in [-1.0, 1.0]:
		B.mesh(g, B.boxm(Vector3(hx - dw, h, t)), Vector3(sx * (dw + hx) / 2.0, h / 2.0, t / 2.0), wall)
		B.mesh(g, B.boxm(Vector3(t, h, d)), Vector3(sx * (hx - t / 2.0), h / 2.0, d / 2.0), wall)
	B.mesh(g, B.boxm(Vector3(2 * dw, h - dh, t)), Vector3(0, dh + (h - dh) / 2.0, t / 2.0), wall)
	B.mesh(g, B.boxm(Vector3(2 * dw, 0.2, t)), Vector3(0, 0.1, t / 2.0), wall.darkened(0.3))  # kynnys
	B.mesh(g, B.boxm(Vector3(2 * hx, h, t)), Vector3(0, h / 2.0, d - t / 2.0), wall)
	# Valkoinen karmi oviaukon ympärillä (kuten world.gd:ssä), syvyys seinän läpi.
	for sx: float in [-1.0, 1.0]:
		B.mesh(g, B.boxm(Vector3(0.16, dh + 0.3, 0.12)), Vector3(sx * (dw + 0.08), (dh + 0.3) / 2.0, -0.06), Color.WHITE)
	B.mesh(g, B.boxm(Vector3(2 * dw + 0.32, 0.3, 0.12)), Vector3(0, dh + 0.15, -0.06), Color.WHITE)
	# Asehuone: lattia, katto, väliseinä.
	var plank := Color(0.55, 0.4, 0.26)
	var fl := B.mesh(g, B.boxm(Vector3(2 * hx - 2 * t, FLOOR_H, INNER_Z - t)), Vector3(0, FLOOR_H / 2.0, t + (INNER_Z - t) / 2.0), plank)
	fl.name = "lattia"
	for k in 12:  # lankkujen raot
		var x := -hx + t + 0.2 + k * (2 * hx - 2 * t - 0.4) / 11.0
		B.mesh(g, B.boxm(Vector3(0.01, 0.003, INNER_Z - t)), Vector3(x, FLOOR_H + 0.001, t + (INNER_Z - t) / 2.0), plank.darkened(0.35))
	B.mesh(g, B.boxm(Vector3(2 * hx, 0.2, d)), Vector3(0, 4.1, d / 2.0), wall.darkened(0.08))
	B.mesh(g, B.boxm(Vector3(2 * hx - 2 * t, 3.9, 0.3)), Vector3(0, FLOOR_H + 1.95, INNER_Z + 0.15), wall.darkened(0.03))
	# Syvennys: tumma puupaneeli kaarineen, kehys ja hylly.
	var oak := Color(0.42, 0.26, 0.13)
	var ny := FLOOR_H + NICHE_Y
	B.mesh(g, B.boxm(Vector3(0.62, 0.86, 0.04)), Vector3(0, ny + 0.4, INNER_Z - 0.02), oak.darkened(0.25))
	var arch := B.mesh(g, B.cyl(0.31, 0.31, 0.04, 20), Vector3(0, ny + 0.83, INNER_Z - 0.02), oak.darkened(0.25))
	arch.rotation.x = PI / 2.0
	for sx: float in [-1.0, 1.0]:
		B.mesh(g, B.boxm(Vector3(0.06, 0.9, 0.08)), Vector3(sx * 0.34, ny + 0.4, INNER_Z - 0.04), oak)
	var frame_arch := B.mesh(g, B.cyl(0.37, 0.37, 0.06, 24), Vector3(0, ny + 0.83, INNER_Z - 0.035), oak)
	frame_arch.rotation.x = PI / 2.0
	B.mesh(g, B.boxm(Vector3(0.6, 0.04, 0.22)), Vector3(0, ny - 0.02, INNER_Z - 0.11), oak.lightened(0.05))  # hylly
	B.mesh(g, B.boxm(Vector3(0.14, 0.16, 0.12)), Vector3(0, ny - 0.12, INNER_Z - 0.07), oak)  # kannake
	# Kynttilänjalat syvennyksen molemmin puolin palavine kynttilöineen.
	var brass := _metal(Color(0.8, 0.62, 0.3), 0.3)
	for sx: float in [-1.0, 1.0]:
		var base := Vector3(sx * 0.75, FLOOR_H, INNER_Z - 0.35)
		B.mesh(g, B.cyl(0.11, 0.14, 0.05, 14), base + Vector3(0, 0.025, 0), Color.WHITE).material_override = brass
		B.mesh(g, B.cyl(0.022, 0.03, 1.3, 10), base + Vector3(0, 0.7, 0), Color.WHITE).material_override = brass
		B.mesh(g, B.cyl(0.07, 0.03, 0.05, 12), base + Vector3(0, 1.37, 0), Color.WHITE).material_override = brass
		B.mesh(g, B.cyl(0.028, 0.028, 0.26, 10), base + Vector3(0, 1.52, 0), Color(0.96, 0.94, 0.86))
		var f := B.mesh(g, B.sphere(0.5, 10), base + Vector3(0, 1.68, 0), Color.WHITE)
		f.scale = Vector3(0.025, 0.06, 0.025)
		f.material_override = B.unshaded(Color(1.0, 0.85, 0.45))
		var cl := OmniLight3D.new()
		cl.light_color = Color(1.0, 0.72, 0.4)
		cl.omni_range = 2.6
		cl.light_energy = 0.9
		g.add_child(cl)
		cl.position = base + Vector3(0, 1.75, 0.1)
	# Penkki sivuseinällä ja virsitaulu toisella (numerot kylttinä taululla).
	B.mesh(g, B.boxm(Vector3(0.4, 0.05, 2.0)), Vector3(-hx + t + 0.25, FLOOR_H + 0.45, 1.6), oak)
	for z: float in [0.8, 2.4]:
		B.mesh(g, B.boxm(Vector3(0.36, 0.43, 0.05)), Vector3(-hx + t + 0.25, FLOOR_H + 0.215, z), oak.darkened(0.15))
	var board := Node3D.new()
	g.add_child(board)
	board.position = Vector3(hx - t - 0.03, FLOOR_H + 1.7, 1.7)
	board.rotation.y = -PI / 2.0
	B.sign_plate(board, "341\n 26\n452", Color(0.22, 0.14, 0.08), Color(0.96, 0.9, 0.7), 0.6, 64, Color(0.75, 0.6, 0.3), "Helvetica Neue")
	hall_light = OmniLight3D.new()
	hall_light.light_color = Color(1.0, 0.75, 0.45)
	hall_light.omni_range = 5.0
	hall_light.light_energy = 1.4
	g.add_child(hall_light)
	hall_light.position = Vector3(0, 3.2, 1.8)


## Kohtauksen ovilehdet oviaukossa: tummanruskeat pystylaudat, peilit, rautaiset saranaraudat ja vetorenkaat. Lehdet
## aukeavat ulospäin. Ovesta ulos lankeava valokeila ja valorako suljettujen lehtien välissä.
func _build_doors() -> void:
	var w := LEAF.x
	var h := LEAF.y
	var wood := Color(0.36, 0.2, 0.09)
	glow_light = SpotLight3D.new()
	glow_light.light_color = Color(1.0, 0.72, 0.38)
	glow_light.spot_range = 7.0
	glow_light.spot_angle = 45.0
	glow_light.light_energy = 0.0
	glow_light.shadow_enabled = true
	_D.add_child(glow_light)
	glow_light.position = Vector3(0, 2.8, 1.4)
	glow_light.rotation.x = deg_to_rad(-30.0)  # ulos ja alas portaille (valo osoittaa -Z)
	crack = B.mesh(_D, B.boxm(Vector3(0.012, h - 0.1, 0.01)), Vector3(0, 0.2 + h / 2.0, LEAF_Z - 0.03), Color.WHITE)
	crack.material_override = B.unshaded(Color(1.0, 0.82, 0.5))
	crack.visible = false
	var iron := _metal(Color(0.12, 0.11, 0.1), 0.6)
	for side: float in [1.0, -1.0]:
		var hinge := Node3D.new()
		_D.add_child(hinge)
		hinge.position = Vector3(side * HINGE_X, 0.2, LEAF_Z)
		leaves.append(hinge)
		var cx := -side * w / 2.0  # lehden keskusta saranasta oven keskelle
		B.mesh(hinge, B.boxm(Vector3(w - 0.01, h, 0.05)), Vector3(cx, h / 2.0, 0), wood)
		for k in 6:  # pystylaudat molemmin puolin
			var x := -side * (0.1 + k * (w - 0.2) / 5.0)
			for fz: float in [-0.028, 0.028]:
				B.mesh(hinge, B.boxm(Vector3(0.012, h - 0.04, 0.008)), Vector3(x, h / 2.0, fz), wood.darkened(0.3))
		for y: float in [0.75, 2.3]:  # peilit
			B.mesh(hinge, B.boxm(Vector3(w - 0.3, 0.9 if y < 1.0 else 1.3, 0.02)), Vector3(cx, y, -0.034), wood.lightened(0.08))
		for y: float in [0.4, h - 0.4]:  # saranaraudat
			B.mesh(hinge, B.boxm(Vector3(0.5, 0.05, 0.012)), Vector3(-side * 0.25, y, -0.032), Color.WHITE).material_override = iron
		var ring := MeshInstance3D.new()  # vetorengas
		var tm := TorusMesh.new()
		tm.inner_radius = 0.045
		tm.outer_radius = 0.06
		ring.mesh = tm
		ring.material_override = iron
		hinge.add_child(ring)
		ring.position = Vector3(-side * (w - 0.16), 1.25, -0.05)
		ring.rotation.x = PI / 2.0


## Pöytä oven sivulla: tumma puupöytä sorvatuin jaloin, pellavaliina.
func _build_table() -> void:
	var g := Node3D.new()
	_D.add_child(g)
	g.position = Vector3(TABLE.x, FLOOR_H, TABLE.z)
	var top := TABLE.y
	var wood := Color(0.4, 0.25, 0.13)
	B.mesh(g, B.boxm(Vector3(TABLE_SIZE.x, 0.035, TABLE_SIZE.y)), Vector3(0, top - 0.018, 0), wood)
	B.mesh(g, B.boxm(Vector3(TABLE_SIZE.x - 0.06, 0.08, TABLE_SIZE.y - 0.06)), Vector3(0, top - 0.075, 0), wood.darkened(0.15))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(sx * (TABLE_SIZE.x / 2.0 - 0.04), 0, sz * (TABLE_SIZE.y / 2.0 - 0.04))
			B.mesh(g, B.cyl(0.022, 0.018, top - 0.04, 8), p + Vector3(0, (top - 0.04) / 2.0, 0), wood.darkened(0.1))
	B.mesh(g, B.boxm(Vector3(TABLE_SIZE.x + 0.02, 0.004, TABLE_SIZE.y * 0.7)), Vector3(0, top + 0.002, 0), Color(0.92, 0.9, 0.84))  # liina


## Vanha esineluettelo: ruskeat nahkakannet, kellastuneet sivut, käsin kirjoitetut rivit. Kirjan paikallinen -Z on
## sivun yläreuna ja +x rivien suunta; pöydällä yläreuna osoittaa sisään (+Z), joten pöydän edessä seisova suntio
## lukee sitä oikein päin.
func _build_book() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	g.global_position = _Dt(BOOK_AT.x, BOOK_AT.y)
	g.global_rotation = Vector3(0, _D.global_rotation.y + PI, 0)
	var leather := Color(0.36, 0.18, 0.1)
	var page := Color(0.93, 0.88, 0.74)
	B.mesh(g, B.boxm(Vector3(PW + 0.01, 0.006, PH + 0.012)), Vector3(-PW / 2.0, 0.003, 0), leather)  # vasen kansi
	B.mesh(g, B.boxm(Vector3(PW, 0.016, PH)), Vector3(-PW / 2.0, 0.014, 0), page.darkened(0.06))  # vasen sivupino
	B.mesh(g, B.boxm(Vector3(PW - 0.004, 0.002, PH - 0.004)), Vector3(-PW / 2.0, 0.023, 0), page)
	book_cover = Node3D.new()  # oikea puolisko (kansi ja sivut) kääntyy selän ympäri kiinni
	g.add_child(book_cover)
	B.mesh(book_cover, B.boxm(Vector3(PW + 0.01, 0.006, PH + 0.012)), Vector3(PW / 2.0, 0.003, 0), leather)
	B.mesh(book_cover, B.boxm(Vector3(PW, 0.016, PH)), Vector3(PW / 2.0, 0.014, 0), page.darkened(0.06))
	B.mesh(book_cover, B.boxm(Vector3(PW - 0.004, 0.002, PH - 0.004)), Vector3(PW / 2.0, 0.023, 0), page)
	B.mesh(g, B.cyl(0.01, 0.01, PH + 0.012, 10), Vector3(0, 0.012, 0), leather.darkened(0.2), Vector3(90, 0, 0))  # selkä
	# Vasen sivu: otsikko ja rivit. Viivat himmeinä, rivi 4 yliviivattu.
	var lines := ["Pelastetut esineet 6.1.1930", "Pyhä Olavi, veistos ..... 1", "Neitsyt Maria, veistos . 1",
		"Alttarikaappi ............. 2", "Pieni pyhimyskuva, puuta 1", "Ehtoollisvälineet ....... 1", "Kirkonkirjat .............. 4"]
	for i in lines.size():
		var z := _row_z(i)
		var lb := _ink(g, lines[i], Vector3(-PW + 0.008, 0.0245, z), 19 if i > 0 else 20)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i > 0:
			B.mesh(g, B.boxm(Vector3(PW - 0.014, 0.0005, 0.0007)), Vector3(-PW / 2.0, 0.0242, z + 0.0065), page.darkened(0.15))
	B.mesh(g, B.boxm(Vector3(0.1, 0.0008, 0.0018)), Vector3(-PW + 0.058, 0.0252, _row_z(4) - 0.0003), Color(0.12, 0.08, 0.06))  # yliviivaus
	# Oikea sivu: kirjoitetaan "← palautettu" yliviivatun rivin kohdalle sinisellä musteella.
	written = _ink(book_cover, " ", Vector3(0.008, 0.0245, _row_z(4)), 22, Color(0.1, 0.16, 0.45))
	written.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for i in 6:
		B.mesh(book_cover, B.boxm(Vector3(PW - 0.014, 0.0005, 0.0007)), Vector3(PW / 2.0, 0.0242, _row_z(i + 1) + 0.0065), page.darkened(0.15))
	return g


func _row_z(i: int) -> float:
	return -PH / 2.0 + LINE0 + i * LINE_DZ


## Musteteksti sivun pinnassa (makaa sivulla, ei billboard).
func _ink(parent: Node3D, text: String, pos: Vector3, size: int, col := Color(0.15, 0.1, 0.07)) -> Label3D:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = size
	lb.pixel_size = 0.00028
	lb.modulate = col
	lb.outline_size = 0
	lb.shaded = false
	lb.double_sided = false
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(lb)
	lb.position = pos
	lb.rotation = Vector3(-PI / 2.0, 0, 0)
	return lb


## Pieni puinen pyhimys (30 cm): nokinen jalusta, haalistunut sininen viitta kultareunuksin, ristityt kädet, naisen
## kaiverretut kasvot huntunsa alla, haalistunut kultasädekehä. Puun syyt näkyvät maalin läpi, noki tummentaa alaosan.
## Etupuoli -Z.
func _build_saint() -> Node3D:
	var g := Node3D.new()
	var wood := Color(0.62, 0.45, 0.28)
	var soot := Color(0.12, 0.1, 0.08)
	var blue := Color(0.34, 0.43, 0.55)
	var gold := Color(0.72, 0.58, 0.3)
	var skin := Color(0.86, 0.72, 0.58)
	var veil_c := Color(0.88, 0.85, 0.78)
	B.mesh(g, B.boxm(Vector3(0.085, 0.03, 0.075)), Vector3(0, 0.015, 0), soot)  # jalusta noessa
	B.mesh(g, B.boxm(Vector3(0.09, 0.006, 0.08)), Vector3(0, 0.031, 0), soot.lightened(0.1))
	# Viitta: kapeneva runko, alaosa nokinen, kultareunus helmassa ja etureunassa.
	B.mesh(g, B.cyl(0.03, 0.042, 0.06, 14), Vector3(0, 0.064, 0), soot.lerp(blue, 0.35))
	B.mesh(g, B.cyl(0.027, 0.03, 0.12, 14), Vector3(0, 0.154, 0), blue)
	B.mesh(g, B.cyl(0.0425, 0.0425, 0.005, 14), Vector3(0, 0.094, 0), gold.darkened(0.2))
	B.mesh(g, B.boxm(Vector3(0.006, 0.15, 0.004)), Vector3(0.0, 0.14, -0.031), gold)  # viitan etureuna
	for k in 4:  # poimut
		var a := -0.9 + k * 0.6
		var f := B.mesh(g, B.boxm(Vector3(0.004, 0.13, 0.003)), Vector3(sin(a) * 0.031, 0.15, -cos(a) * 0.031), blue.darkened(0.25))
		f.rotation.y = -a
	B.mesh(g, B.boxm(Vector3(0.002, 0.08, 0.002)), Vector3(0.016, 0.2, -0.027), wood)  # kulunut kohta, puu näkyy
	# Ristityt kädet rinnalla.
	var hands := B.mesh(g, B.sphere(0.5, 10), Vector3(0, 0.19, -0.029), skin)
	hands.scale = Vector3(0.026, 0.03, 0.018)
	B.mesh(g, B.boxm(Vector3(0.004, 0.022, 0.003)), Vector3(0, 0.198, -0.038), skin.darkened(0.2))
	# Hartiat ja pää huntuineen: huntu takaraivolla ja hartioilla, kasvot jäävät esiin.
	B.mesh(g, B.cyl(0.022, 0.03, 0.025, 14), Vector3(0, 0.226, 0), blue.lightened(0.05))
	var veil := B.mesh(g, B.sphere(0.5, 14), Vector3(0, 0.264, 0.007), veil_c)
	veil.scale = Vector3(0.042, 0.048, 0.038)
	B.mesh(g, B.boxm(Vector3(0.046, 0.04, 0.026)), Vector3(0, 0.236, 0.011), veil_c)
	var head := B.mesh(g, B.sphere(0.5, 14), Vector3(0, 0.258, -0.008), skin)
	head.scale = Vector3(0.032, 0.04, 0.032)
	# Kasvot: silmät, kulmat, nenä ja suu kaiverruksena (tummat urat).
	for sx: float in [-1.0, 1.0]:
		B.mesh(g, B.boxm(Vector3(0.007, 0.0025, 0.002)), Vector3(sx * 0.007, 0.262, -0.0235), Color(0.25, 0.17, 0.12))
		B.mesh(g, B.boxm(Vector3(0.008, 0.0015, 0.002)), Vector3(sx * 0.0073, 0.2675, -0.0225), Color(0.4, 0.28, 0.2))
	B.mesh(g, B.boxm(Vector3(0.004, 0.009, 0.004)), Vector3(0, 0.256, -0.0245), skin.darkened(0.1))
	B.mesh(g, B.boxm(Vector3(0.008, 0.002, 0.002)), Vector3(0, 0.247, -0.0225), Color(0.5, 0.25, 0.2))
	# Sädekehä takaraivon takana: ohut haalistunut kultakiekko.
	var halo := B.mesh(g, B.cyl(0.035, 0.035, 0.003, 18), Vector3(0, 0.274, 0.028), gold)
	halo.rotation.x = PI / 2.0
	halo.material_override = _metal(gold, 0.55)
	# Nokiläikät viitassa.
	for p: Vector3 in [Vector3(-0.03, 0.07, -0.02), Vector3(0.033, 0.11, 0.01), Vector3(0.0, 0.06, -0.038)]:
		var s := B.mesh(g, B.sphere(0.5, 8), p, soot)
		s.scale = Vector3(0.022, 0.03, 0.01)
	return g


## Nahkakääre: tummanruskea nahka ja neljä läppää (kiinni pyhimyksen ympärillä, avattaessa lasketaan auki).
func _build_bundle() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var leather := Color(0.4, 0.26, 0.15)
	B.mesh(g, B.boxm(Vector3(0.13, 0.008, 0.13)), Vector3(0, 0.004, 0), leather)
	for k in 4:
		var hinge := Node3D.new()
		g.add_child(hinge)
		hinge.rotation.y = k * PI / 2.0
		var pivot := Node3D.new()  # läpän sarana pohjan reunassa, läppä kääntyy pivotin x-akselin ympäri
		hinge.add_child(pivot)
		pivot.position = Vector3(0, 0.006, -0.065)
		var col := leather.lightened(0.06 * (k % 2))
		B.mesh(pivot, B.boxm(Vector3(0.13 - 0.012 * (k % 2), 0.006, 0.3)), Vector3(0, 0.004 * (k % 2), -0.15), col)
		B.mesh(pivot, B.boxm(Vector3(0.1, 0.0015, 0.004)), Vector3(0, 0.0035 + 0.004 * (k % 2), -0.27), col.darkened(0.25))  # ommel
		flaps.append(pivot)
	# Nyöri kääreen ympärillä (näkyy kiinni ollessa).
	cord = B.mesh(g, B.cyl(0.075, 0.075, 0.008, 16), Vector3(0, 0.16, 0), Color(0.75, 0.68, 0.5))
	_set_flaps(0.0)
	return g


## Läpät: 0 kiinni (pystyssä pyhimyksen ympärillä, kärjet kallistuvat sisään), 1 auki (roikkuvat pelaajan käsien yli).
func _set_flaps(open: float) -> void:
	for i in flaps.size():
		flaps[i].rotation.x = lerpf(1.85 + 0.03 * i, -0.75, open)
	if cord != null:
		cord.visible = open < 0.05


func _build_pen() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	B.mesh(g, B.cyl(0.0045, 0.0045, 0.12, 10), Vector3(0, 0, 0.06), Color(0.08, 0.08, 0.1), Vector3(90, 0, 0))
	B.mesh(g, B.cyl(0.0048, 0.0048, 0.012, 10), Vector3(0, 0, 0.0), Color(0.75, 0.62, 0.3), Vector3(90, 0, 0))
	var nib := B.mesh(g, B.cyl(0.0, 0.004, 0.016, 8), Vector3(0, 0, -0.008), Color.WHITE, Vector3(-90, 0, 0))
	nib.material_override = _metal(Color(0.78, 0.68, 0.35), 0.3)
	return g


## Hoitajan lehtiharava: puuvarsi ja viuhkamaiset piikit (paikallinen +Y varren suunta, -Z piikkien suunta).
func _build_rake() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	B.mesh(g, B.cyl(0.014, 0.014, 1.45, 8), Vector3(0, 0.72, 0), Color(0.68, 0.52, 0.32))
	for k in 9:
		var a := -0.5 + k * 0.125
		var tine := B.mesh(g, B.boxm(Vector3(0.006, 0.003, 0.28)), Vector3(sin(a) * 0.14, 0.02, -cos(a) * 0.14), Color(0.3, 0.32, 0.3))
		tine.rotation.y = -a
		tine.rotation.x = 0.15
	return g


## Hautakynttilän liekki lyhdyn päällä: kirkas ydin, kellertävä vaippa ja valo; sammuessa savukiehkura.
func _build_flame() -> void:
	flame = Node3D.new()
	_H.add_child(flame)
	flame.position = FLAME_AT
	var outer := B.mesh(flame, B.sphere(0.5, 10), Vector3(0, 0.022, 0), Color.WHITE)
	outer.scale = Vector3(0.022, 0.05, 0.022)
	outer.material_override = B.unshaded(Color(1.0, 0.72, 0.25))
	var core := B.mesh(flame, B.sphere(0.5, 10), Vector3(0, 0.014, 0), Color.WHITE)
	core.scale = Vector3(0.011, 0.026, 0.011)
	core.material_override = B.unshaded(Color(1.0, 0.97, 0.8))
	B.mesh(flame, B.cyl(0.0015, 0.0015, 0.012, 6), Vector3(0, -0.002, 0), Color(0.1, 0.08, 0.06))  # sydänlanka
	flame_light = OmniLight3D.new()
	flame_light.light_color = Color(1.0, 0.7, 0.35)
	flame_light.omni_range = 1.6
	flame_light.light_energy = 1.0
	flame.add_child(flame_light)
	flame_light.position = Vector3(0, 0.08, 0.1)
	_smoke = CPUParticles3D.new()
	_H.add_child(_smoke)
	_smoke.position = FLAME_AT + Vector3(0, 0.01, 0)
	var sm := QuadMesh.new()
	sm.size = Vector2(0.025, 0.025)
	var gt := GradientTexture2D.new()  # pehmeä pyöreä savuhiukkanen
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.vertex_color_use_as_albedo = true
	smat.albedo_texture = gt
	sm.material = smat
	_smoke.mesh = sm
	_smoke.amount = 90
	_smoke.lifetime = 2.8
	_smoke.emitting = false
	_smoke.direction = Vector3(0, 1, 0)
	_smoke.spread = 4.0
	_smoke.initial_velocity_min = 0.1
	_smoke.initial_velocity_max = 0.14
	_smoke.gravity = Vector3(0.04, 0.03, 0.0)  # vire kuljettaa hiukan sivuun
	_smoke.scale_amount_min = 0.7
	_smoke.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.4))
	_smoke.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.7, 0.7, 0.72, 0.55))
	ramp.set_color(1, Color(0.85, 0.85, 0.88, 0.0))
	_smoke.color_ramp = ramp
	_props.append(_smoke)


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
	for c in [me, suntio, nainen, hoitaja]:
		c.clear_ik()
		c.clear_overrides()
	match p:
		"kaare":
			_story = "Saloisten kirkon portailla. Nahkakääre Tokolan orrelta."
			_set_flaps(0.0)
			saint.visible = false
		"luettelo":
			_story = ""
			bundle.visible = false
			saint.visible = true
			_saint_held_by = suntio
			_stand(me, ME_ASIDE.x, ME_ASIDE.y)
		"nimi":
			_story = ""
			bundle.visible = false
			_saint_on_table()
			_set_written(WRITTEN.length())
			pen.visible = false
			_stand(suntio, SUNTIO_TABLE.x, SUNTIO_TABLE.y)
			_stand(me, ME_ASIDE.x, ME_ASIDE.y)
		"ovi":
			_story = ""
			bundle.visible = false
			_set_written(WRITTEN.length())
			book_cover.rotation.z = PI
			pen.visible = false
			saint.visible = true
			_saint_held_by = suntio
			_stand(me, ME_ASIDE.x, ME_ASIDE.y)
		"kynttila":
			_story = ""
			_set_door(0.0)
			crack.visible = true
			glow_light.light_energy = 0.0
			suntio.visible = false
			me.visible = false
			_saint_held_by = null
			_saint_in_niche()
			bundle.visible = false
			flame.visible = true
			flame_out = false
			Sfx.play("bell", -9.0, 0.35)  # kaukainen lyönti kantaa haudalle
		"otsikko":
			_story = ""
			suntio.visible = false
			me.visible = false
			_saint_held_by = null
			_saint_in_niche()
			bundle.visible = false
			flame.visible = false
			flame_out = true
			_smoke.emitting = false
			_set_door(0.0)
			glow_light.light_energy = 0.0
			Sfx.play("win_small", -12.0, 0.8)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa keskustelun valinnasta (E tai napsautus): sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "kaare" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"kaare":
			_step_kaare(delta)
		"luettelo":
			_step_luettelo(delta)
		"nimi":
			_step_nimi(delta)
		"ovi":
			_step_ovi(delta)
		"kynttila":
			_step_kynttila(delta)
		"otsikko":
			_step_otsikko(delta)
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
	for n in _tower_hidden:
		if is_instance_valid(n):
			n.visible = true
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	for nd in _was_visible:
		if is_instance_valid(nd):
			(nd as Node3D).visible = _was_visible[nd]
	finished.emit()
	_cam.queue_free()
	queue_free()


func _step_kaare(_delta: float) -> void:
	# Pelaaja ojentaa kääreen (0-1,2 s). Suntio avaa läpät (1,4-2,6 s) pelaajan pitäessä kääretta, nostaa pyhimyksen
	# molemmin käsin esiin (2,8-3,6 s); pelaaja laskee nahan ja astuu sivuun. Lähikuva pyhimyksestä 3,8 s.
	_face(me, suntio.global_position)
	_face(suntio, me.global_position)
	var mid := me.global_position.lerp(suntio.global_position, 0.42) + Vector3(0, 1.02, 0)
	var ext := clampf(_t / 1.0, 0.0, 1.0)
	var lower := clampf((_t - 3.6) / 0.6, 0.0, 1.0)
	var hold_at := _chest(me).lerp(mid, ext).lerp(_chest(me) + Vector3(0, -0.35, 0), lower)
	if _t < 4.2:
		_hold2(me, hold_at, 1.0, 0.07)
		_place_between_hands(me, bundle, -0.035)
	else:
		bundle.visible = false
		me.clear_ik()
	if _t > 3.8:
		var s := clampf((_t - 3.8) / 1.2, 0.0, 1.0)
		var p := ME_AT.lerp(ME_ASIDE, s * (2.0 - s))
		_stand(me, p.x, p.y)
		me.play("Walk" if s < 1.0 else "Idle", 0.2)
	_set_flaps(clampf((_t - 1.4) / 1.2, 0.0, 1.0))
	if _t > 1.4 and not _once.has("auki"):
		_once["auki"] = true
		Sfx.play("cloth", -6.0, 0.8)
	var in_bundle := bundle.to_global(Vector3(0, 0.01, 0))
	if _t < 1.4:
		suntio.clear_ik()
	elif _t < 2.8:
		# Oikea käsi avaa läpät: käy kääreen yllä kumpaankin suuntaan.
		var side := suntio.global_basis.x * (0.1 * sin((_t - 1.4) * 4.5))
		_reach_r(suntio, in_bundle + Vector3(0, 0.22, 0) + side, clampf((_t - 1.4) / 0.4, 0.0, 1.0))
		_neck(suntio, 0.35)
	else:
		var lift := clampf((_t - 2.9) / 0.7, 0.0, 1.0)
		var held := _chest(suntio) + suntio.global_basis * Vector3(0, -0.12, -0.12)
		_hold2(suntio, in_bundle.lerp(held, lift) + Vector3(0, 0.1, 0), clampf((_t - 2.8) / 0.25, 0.0, 1.0), 0.05)
		_neck(suntio, 0.35)
		_saint_held_by = suntio
	saint.visible = _t > 1.9
	if _saint_held_by == null:
		saint.global_position = in_bundle
		_saint_face(suntio.global_position + Vector3(0, 1.6, 0))
	else:
		_hold_saint()
		if _t > 3.8:
			_saint_face(_cam.global_position.lerp(suntio.to_global(suntio.bone_position("Head")), 0.35))
	if _t > 0.3 and _t < 1.6:
		_bub[me] = "Tokolan vanhan varaston orrelta."
	else:
		_bub.erase(me)
	if _t > 1.8 and _t < 3.6:
		_bub[suntio] = "Mitä tässä on?"
	else:
		_bub.erase(suntio)
	if _t >= 3.9:
		_story = "Kaiverrettu naisen kasvot. Palon noki pohjassa."
	var look: Vector3
	var eye: Vector3
	if _t < 3.8:
		# Portaiden sivulta: molemmat profiilissa, kääre välissä, kirkon ovi taustalla.
		look = mid + Vector3(0, 0.18, 0)
		eye = look + _D.global_basis * Vector3(-2.5, 0.2, -0.9)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 2.2))
	else:
		# Lähikuva: pyhimys suntion käsissä edestä vinosti, suntion kasvot yläreunassa katsomassa sitä.
		var hd := suntio.to_global(suntio.bone_position("Head"))
		look = saint.global_position.lerp(hd, 0.5)
		eye = look + suntio.global_basis * Vector3(0.45, -0.14, -0.8)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 1.0))


func _step_luettelo(_delta: float) -> void:
	# Suntio kävelee pöydän eteen (0-1,6 s), laskee pyhimyksen pöydälle (1,6-2,3 s), kulkee sormella rivejä (2,5-5,0 s),
	# ottaa kynän ja kirjoittaa "palautettu" (5,3-7,4 s).
	_face(me, suntio.global_position)
	var k := clampf(_t / 1.6, 0.0, 1.0)
	var p := SUNTIO_AT.lerp(SUNTIO_TABLE, k * (2.0 - k))
	_stand(suntio, p.x, p.y)
	var into := _Dg(SUNTIO_TABLE.x, SUNTIO_TABLE.y + 2.0)
	if k < 1.0:
		suntio.play("Walk", 0.2)
		_face(suntio, _Dg(SUNTIO_TABLE.x, SUNTIO_TABLE.y) if k < 0.85 else into)
		_hold2(suntio, _chest(suntio) + suntio.global_basis * Vector3(0, -0.12, -0.12), 1.0, 0.05)
		_hold_saint()
	else:
		suntio.play("Idle", 0.2)
		_face(suntio, into)
		if _t < 2.3:
			var d := clampf((_t - 1.6) / 0.6, 0.0, 1.0)
			var from := _chest(suntio) + suntio.global_basis * Vector3(0, -0.12, -0.12)
			_hold2(suntio, from.lerp(_Dt(SAINT_TABLE.x, SAINT_TABLE.y) + Vector3(0, 0.1, 0), d), 1.0, 0.05, 0.35 * d)
			_hold_saint()
			if d >= 1.0:
				_saint_on_table()
		else:
			_saint_on_table()
			_lean(suntio, 0.4)
			_neck(suntio, 0.35)
			if _t < 5.1:
				# Sormi rivejä pitkin: alas riville 4 ja sitten sen yli.
				var f := clampf((_t - 2.5) / 1.3, 0.0, 1.0)
				var tgt := _line_point(-0.06).lerp(_line_point(0.0), f) if f < 1.0 else _line_point(clampf((_t - 3.8) / 1.0, 0.0, 1.0) * 0.08)
				_reach_l(suntio, tgt + Vector3(0, 0.03, 0), clampf((_t - 2.3) / 0.4, 0.0, 1.0))  # rivit alkavat suntion vasemmalta
				_point_index(suntio, "_l")
				pen.visible = false
			else:
				var wr := clampf((_t - 5.3) / 2.1, 0.0, 1.0)
				var tip := written.global_position + _book_x() * (0.003 + 0.05 * wr) + Vector3(0, 0.001 + 0.003 * absf(sin(_t * 26.0)), 0)
				if not _once.has("vasen_pois"):
					_once["vasen_pois"] = true
					suntio.clear_ik()  # vasen käsi pois riviltä, oikea ottaa kynän
				var hand_at := tip + Vector3(0, 0.1, 0) - _book_x() * 0.02 + _D.global_basis.z * -0.04
				_reach_r(suntio, hand_at, clampf((_t - 5.1) / 0.3, 0.0, 1.0))
				pen.visible = true
				var hp := suntio.to_global((suntio.bone_position("index_02_r") + suntio.bone_position("thumb_02_r")) / 2.0)
				pen.global_position = tip
				pen.look_at_from_position(tip, tip + (tip - hp).normalized(), _D.global_basis.z)  # kärki (-Z) paperissa, varsi kädessä
				_set_written(int(wr * WRITTEN.length()) if _t > 5.3 else 0)
				if _t > 5.3 and not _once.has("kyna"):
					_once["kyna"] = true
					Sfx.play("pedal_squeak", -18.0, 2.4)
			if _t > 2.6 and _t < 4.4:
				_bub[suntio] = "Pieni pyhimyskuva, puuta."
			elif _t >= 4.4 and _t < 5.8:
				_bub[suntio] = "Kirjoitusvirhe, minä sanoin."
			elif _t >= 6.4:
				_bub[suntio] = "...Palautettu."
			else:
				_bub.erase(suntio)
			_story = "Yliviivattu rivi vuodelta 1930." if _t > 2.4 and _t < 4.4 else ""
	var look: Vector3
	var eye: Vector3
	if _t < 2.4:
		# Suntio pöydälle: väljä kuva portailta, pöytä ja ovi taustalla.
		look = _Dg(1.0, -0.8, 1.0)
		eye = look + _D.global_basis * Vector3(-1.2, 0.4, -3.4)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.2))
	else:
		# Lähikuva kirjasta suntion vasemman olan yli: sivut oikein päin, yliviivattu rivi, pyhimys oikealla.
		look = book.global_position + Vector3(0, 0.02, 0) + _D.global_basis * Vector3(-0.03, 0, -0.06)
		eye = look + _D.global_basis * Vector3(-0.3, 0.55, -0.36)  # oikean olan yli: vasen käsi rivillä kaukana puolella
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 0.5))


func _step_nimi(_delta: float) -> void:
	# Suntio kääntyy pelaajaan: "Mistä talosta se löytyi?" - "Suvun nimeä ei mainita." Suntio nyökkää, sulkee kirjan
	# ja nostaa pyhimyksen molemmin käsin.
	_face(me, suntio.global_position)
	var into := _Dg(SUNTIO_TABLE.x, SUNTIO_TABLE.y + 2.0)
	if _t < 4.2:
		_face(suntio, me.global_position)
	else:
		_face(suntio, into)
	if _t > 0.4 and _t < 2.0:
		_bub[suntio] = "Mistä talosta se löytyi?"
	elif _t >= 2.0 and _t < 3.6:
		_bub.erase(suntio)
		_bub[me] = "Suvun nimeä ei mainita."
	elif _t >= 3.6 and _t < 5.4:
		_bub.erase(me)
		_bub[suntio] = "Ei mainita."
	else:
		_bub.erase(suntio)
	if _t > 3.6 and _t < 4.6:
		_neck(suntio, 0.3 * sin((_t - 3.6) / 1.0 * PI))  # hidas nyökkäys
	if _t >= 4.4:
		var cl := clampf((_t - 4.4) / 0.7, 0.0, 1.0)
		book_cover.rotation.z = PI * cl  # oikea puolisko kääntyy selän yli vasemman päälle
		_reach_r(suntio, book.to_global(Vector3(PW * cos(PI * cl), 0.03 + PW * sin(PI * cl), 0)), clampf((_t - 4.3) / 0.2, 0.0, 1.0) * (1.0 - clampf((_t - 5.1) / 0.2, 0.0, 1.0)))
		if not _once.has("kirja"):
			_once["kirja"] = true
			Sfx.play("cloth", -8.0, 0.6)
	if _t >= 5.3:
		var spot := _Dt(SAINT_TABLE.x, SAINT_TABLE.y) + Vector3(0, 0.1, 0)
		var lift := clampf((_t - 5.8) / 0.8, 0.0, 1.0)
		var held := _chest(suntio) + suntio.global_basis * Vector3(0, -0.08, -0.2)
		_hold2(suntio, spot.lerp(held, lift), clampf((_t - 5.3) / 0.5, 0.0, 1.0), 0.05, 0.35 * (1.0 - lift))
		if _t > 5.8:
			_saint_held_by = suntio
	_hold_saint()
	# Kaksoiskuva portaiden alta: molempien kasvot, pöytä, kirja ja pyhimys suntion edessä.
	var a := _Dg(ME_ASIDE.x, ME_ASIDE.y, 1.45)
	var b := _Dg(SUNTIO_TABLE.x, SUNTIO_TABLE.y, 1.45)
	var look := a.lerp(b, 0.55) + Vector3(0, -0.15, 0) + _D.global_basis.z * 0.25
	var eye := look + _D.global_basis * Vector3(1.3, 0.25, -3.4)  # pöydän puolelta vinosti: suntion kasvot ja nosto näkyvät
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.9))


func _step_ovi(_delta: float) -> void:
	# Suntio kävelee ovelle pyhimys käsissään (0-1,6 s), ovet aukeavat (1,8-3,0 s) ja valo lankeaa portaille. Hän
	# kävelee asehuoneeseen syvennyksen eteen (3,2-5,4 s), nostaa pyhimyksen hyllylle (5,4-6,2 s) ja painaa päänsä;
	# ovet sulkeutuvat (7,2-8,2 s), rako hehkuu ja tapulin kello lyö.
	_face(me, suntio.global_position)
	if _t < 3.2:
		var k := clampf(_t / 1.6, 0.0, 1.0)
		var p := SUNTIO_TABLE.lerp(SUNTIO_DOOR, k * (2.0 - k))
		_stand(suntio, p.x, p.y)
		suntio.play("Walk" if k < 1.0 else "Idle", 0.2)
		_face(suntio, _Dg(0.0, 2.0) if k >= 0.8 else _Dg(SUNTIO_DOOR.x, SUNTIO_DOOR.y))
	else:
		var s := clampf((_t - 3.2) / 2.2, 0.0, 1.0)
		var p2 := SUNTIO_DOOR.lerp(SUNTIO_NICHE, s)
		_stand(suntio, p2.x, p2.y)
		suntio.play("Walk" if s < 1.0 else "Idle", 0.2)
		_face(suntio, _Dg(0.0, INNER_Z + 1.0))
	var shelf := _D.to_global(Vector3(0, FLOOR_H + NICHE_Y, INNER_Z - 0.11))
	if _t < 5.4:
		_hold2(suntio, _chest(suntio) + suntio.global_basis * Vector3(0, -0.08, -0.2), 1.0, 0.05)
		_hold_saint()
	elif _t < 6.4:
		var r := clampf((_t - 5.4) / 0.8, 0.0, 1.0)
		var from := _chest(suntio) + suntio.global_basis * Vector3(0, -0.08, -0.2)
		_hold2(suntio, from.lerp(shelf + Vector3(0, 0.1, 0), r), 1.0, 0.05)
		_hold_saint()
		if r >= 1.0:
			_saint_held_by = null
			_saint_in_niche()
	else:
		_saint_held_by = null
		_saint_in_niche()
		var back := 1.0 - clampf((_t - 6.4) / 0.5, 0.0, 1.0)
		_hold2(suntio, shelf + Vector3(0, 0.1, 0), back, 0.05)
		var st := clampf((_t - 6.5) / 0.6, 0.0, 1.0)  # askel taakse ja sivuun, jotta pyhimys näkyy
		var p3 := SUNTIO_NICHE.lerp(SUNTIO_NICHE + Vector2(-0.45, -0.35), st * (2.0 - st))
		_stand(suntio, p3.x, p3.y)
		suntio.play("Walk" if st > 0.0 and st < 1.0 else "Idle", 0.2)
		_neck(suntio, 0.45 * clampf((_t - 7.0) / 0.5, 0.0, 1.0))  # pää painuu
	var o := clampf((_t - 1.8) / 1.2, 0.0, 1.0)
	var c := clampf((_t - 7.2) / 1.0, 0.0, 1.0)
	_set_door(o * (2.0 - o) * (1.0 - c * c))
	glow_light.light_energy = 3.0 * door_open
	if _t > 1.8 and not _once.has("ovi"):
		_once["ovi"] = true
		Sfx.play("door", -6.0, 0.7)
	if _t > 8.2:
		crack.visible = true
		if not _once.has("kello"):
			_once["kello"] = true
			Sfx.play("door_close", -6.0, 0.7)
			Sfx.play("bell", -3.0, 0.35)
	if _t > 8.4:
		_story = "Tapulin kello lyö kerran."
	# Portailta suntion takaa: oviaukko keskellä, asehuoneen kynttilät ja syvennys; kamera liukuu oviaukkoa kohti.
	var push := clampf((_t - 3.0) / 3.0, 0.0, 1.0)
	push = push * (2.0 - push) * (1.0 - c * 0.6)
	var look := _Dg(0.1, 1.0, 1.45)
	var eye := _D.to_global(Vector3(0.45, FLOOR_H + 1.85, lerpf(-5.6, -4.0, push)))
	_cam_at(eye, look, _fov_w(eye.distance_to(look), lerpf(5.2, 3.8, push)))


func _step_kynttila(_delta: float) -> void:
	# Haudalla: nainen kädet ristissä, kynttilä palaa; hoitaja pysähtyy (1,0 s) ja painaa päänsä. Vire (3,0 s): liekki
	# lepattaa, kutistuu ja sammuu (3,0-4,4 s), savu nousee. "Nyt se on kotona." (4,9 s) Nainen lähtee kirkolle (6,8 s).
	var lantern := _H.to_global(FLAME_AT)
	if _t < 6.8:
		_face_h(nainen, Vector2(0.0, -0.5))
		_hold_hands(nainen, 1.0 - clampf((_t - 6.4) / 0.3, 0.0, 1.0))
		_neck(nainen, 0.3)
	_face(hoitaja, nainen.global_position)
	_place_rake(clampf((_t - 1.0) / 0.6, 0.0, 1.0))
	if _t > 1.4:
		_neck(hoitaja, 0.4 * clampf((_t - 1.4) / 0.6, 0.0, 1.0))
	var flick := 1.0
	if _t < 3.0:
		flick = 1.0 + 0.08 * sin(_t * 17.0)
	elif _t < 4.4:
		var e := (_t - 3.0) / 1.4
		flick = (1.0 - e * e) * (1.0 + 0.4 * sin(_t * 41.0))
		flame.rotation.z = 0.35 * e * sin(_t * 23.0)
		if not _once.has("vire"):
			_once["vire"] = true
			Sfx.play("whoosh", -16.0, 0.5)
	else:
		flick = 0.0
	flame.scale = Vector3(1.0, maxf(flick, 0.0), 1.0)
	flame_light.light_energy = 1.0 * maxf(flick, 0.0)
	if _t >= 4.4 and not flame_out:
		flame_out = true
		flame.visible = false
		_smoke.emitting = true
	if _t > 6.2:
		_smoke.emitting = false
	if _t > 4.9 and _t < 6.8:
		_bub[nainen] = "Nyt se on kotona."
	else:
		_bub.erase(nainen)
	_story = "Kynttilä sammui." if _t > 5.4 and _t < 7.4 else ""
	if _t > 6.8:
		var w := clampf((_t - 6.8) / 2.2, 0.0, 1.0)
		var p := _exit_path(w * 0.45)
		_stand_h(nainen, p.x, p.y)
		nainen.play("Walk", 0.3, 0.7)
		_face_h(nainen, _exit_path(minf(1.0, w * 0.45 + 0.1)))
	var look: Vector3
	var eye: Vector3
	if _t < 6.6:
		# Matalalta hautakiven vierestä: liekki etualalla, nainen sen takana kasvot kameraan, hoitaja taustalla.
		var hd := nainen.to_global(nainen.bone_position("Head"))
		look = lantern.lerp(hd, 0.56)  # pää ruudun keskiosaan: puhekupla mahtuu pään yläpuolelle
		eye = _H.to_global(Vector3(-2.3, 0.0, 0.4))  # hautakiven edestä (kivi z -0,8 jää kuvan sivuun)
		eye.y = lantern.y + 0.7
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.8))
	else:
		_frame_exit()


func _step_otsikko(_delta: float) -> void:
	# Hauta ja sammunut kynttilä etualalla, nainen kulkee kirkolle päin, hoitaja haravoi taas.
	var w := clampf(_t / 6.6, 0.0, 1.0)
	var p := _exit_path(0.45 + 0.55 * w)
	_stand_h(nainen, p.x, p.y)
	nainen.play("Walk", 0.3, 0.7)
	_face_h(nainen, _exit_path(minf(1.0, 0.55 + 0.55 * w)))
	_face(hoitaja, nainen.global_position)
	_place_rake(0.0)
	_frame_exit()


## Naisen polku haudalta kirkolle päin (k 0..1, noin 6,5 m) haudan kehyksessä: ensin sivuun haudan reunalta, sitten
## kirkon suuntaan.
func _exit_path(k: float) -> Vector2:
	var side := Vector2(-_church_dir.y, _church_dir.x)
	if side.dot(NAINEN_AT) < 0.0:
		side = -side
	var a := NAINEN_AT + side * 0.5
	if k < 0.08:
		return NAINEN_AT.lerp(a, k / 0.08)
	return a.lerp(a + _church_dir * 6.0, (k - 0.08) / 0.92)


## Hauta ja sammunut kynttilä etualalla, naisen polku kirkolle taustalla (kamera haudan takaa kirkkoa kohti).
func _frame_exit() -> void:
	var back := -_church_dir
	var side := Vector2(-_church_dir.y, _church_dir.x)
	if side.dot(NAINEN_AT) > 0.0:
		side = -side  # kamera haudan toiselle puolelle kuin naisen polku: hautakivi ei peitä häntä
	var e := back * 2.4 + side * 2.2
	var eye := _Hg(e.x, e.y, 1.5)
	var l := _church_dir * 3.5 - side * 0.6
	var look := _Hg(l.x, l.y, 1.0)
	_cam_at(eye, look, 50.0)


# --- Esineet ja hahmot --------------------------------------------------------------

## Ovilehdet auki (0..1): 1 = noin 100 astetta ulospäin.
func _set_door(open: float) -> void:
	door_open = open
	var a := open * deg_to_rad(100.0)
	leaves[0].rotation.y = -a  # vasen (+x) sarana: vapaa reuna kiertää -Z:aan
	leaves[1].rotation.y = a


## Kirjoitettu osa tekstistä (Label3D:ssä ei ole visible_characters-ominaisuutta).
func _set_written(n: int) -> void:
	written_chars = n
	written.text = WRITTEN.left(n) if n > 0 else " "


func _saint_on_table() -> void:
	_saint_held_by = null
	saint.global_position = _Dt(SAINT_TABLE.x, SAINT_TABLE.y)
	saint.global_rotation = Vector3(0, _D.global_rotation.y - 0.5, 0)  # kasvot kohti pöydän edustaa ja oviaukkoa


func _saint_in_niche() -> void:
	saint_in_niche = true
	saint.visible = true
	saint.global_position = _D.to_global(Vector3(0, FLOOR_H + NICHE_Y, INNER_Z - 0.11))
	saint.global_rotation = Vector3(0, _D.global_rotation.y, 0)  # kasvot ovelle (-Z)


## Pyhimys kantajan käsien välissä, kasvot menosuuntaan.
func _hold_saint() -> void:
	if _saint_held_by == null:
		return
	var c := _saint_held_by
	var hl := c.to_global(c.bone_position("hand_l"))
	var hr := c.to_global(c.bone_position("hand_r"))
	saint.global_position = (hl + hr) / 2.0 + Vector3(0, -0.07, 0)
	saint.global_rotation = Vector3(0, c.global_rotation.y, 0)


## Pyhimys kääntyy kasvot kohti pistettä (vain pystyakselin ympäri).
func _saint_face(at: Vector3) -> void:
	var d := at - saint.global_position
	d.y = 0.0
	if d.length() > 0.05:
		saint.global_rotation = Vector3(0, B.yaw_to(d), 0)


## Kääre kantajan käsien väliin (dy pohjan korkeus käsiin nähden).
func _place_between_hands(c: Node3D, obj: Node3D, dy: float) -> void:
	var hl := c.to_global(c.bone_position("hand_l"))
	var hr := c.to_global(c.bone_position("hand_r"))
	obj.global_position = (hl + hr) / 2.0 + Vector3(0, dy, 0)
	obj.global_rotation = Vector3(0, c.global_rotation.y, 0)


## Molemmat kädet esineen ympärille (w 0..1), kämmenet spread päässä keskeltä; lean kumartaa selkää.
func _hold2(c: Node3D, center: Vector3, w: float, spread: float, lean := 0.0) -> void:
	_lean(c, lean)
	for lr: String in ["_l", "_r"]:
		var sh: Vector3 = c.bone_position("upperarm" + lr)
		var s := signf(sh.x) if sh.x != 0.0 else 1.0
		var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
		var tgt := c.to_local(center) + Vector3(s * spread, 0, 0)
		c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, rest.lerp(tgt, w), sh + Vector3(s * 0.45, -0.3, 0.25))


## Kädet ristissä vyötärön edessä (w 0..1).
func _hold_hands(c: Node3D, w: float) -> void:
	_hold2(c, c.to_global(c.bone_position("spine_01") + Vector3(0, 0.12, -0.2)), w, 0.03)


## Oikea käsi kohti pistettä (w 0..1).
func _reach_r(c: Node3D, at_global: Vector3, w: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", rest.lerp(c.to_local(at_global), w), sh + Vector3(s * 0.45, -0.25, 0.25))


## Vasen käsi kohti pistettä (w 0..1).
func _reach_l(c: Node3D, at_global: Vector3, w: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm_l")
	var s := signf(sh.x) if sh.x != 0.0 else -1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", rest.lerp(c.to_local(at_global), w), sh + Vector3(s * 0.45, -0.25, 0.25))


func _hand_l(c: Node3D) -> Vector3:
	return c.to_global((c.bone_position("hand_l") + c.bone_position("index_01_l")) / 2.0)


## Etusormi suoraksi (osoittaa riviä): luut lepoasentoon hahmon asennon jälkeen.
func _point_index(c: Node3D, lr := "_r") -> void:
	var sk: Skeleton3D = c.skeleton
	for k: String in ["01", "02", "03"]:
		var i := sk.find_bone("index_%s%s" % [k, lr])
		if i >= 0:
			sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion())


## Hoitajan haravointi: haravan pää liikkuu edestakaisin hoitajan edessä ja varsi kulkee käden kautta; pysähtyessä
## (stop 1) harava seisoo pystyssä hoitajan vieressä ja käsi lepää varren päällä.
func _place_rake(stop: float) -> void:
	var hb := hoitaja.global_basis
	var hp := hoitaja.global_position
	var sweep := sin(_t * 3.0) * 0.25 * (1.0 - stop)
	var head := hp + hb * Vector3(0.15 + sweep, 0.0, -0.9).lerp(Vector3(0.28, 0.0, -0.25), stop)
	head.y = T.h(head.x, head.z)
	var grip := hp + hb * Vector3(0.2 + sweep * 0.4, 0.95, -0.38).lerp(Vector3(0.26, 1.2, -0.2), stop)
	_reach_r(hoitaja, grip, 1.0)
	var up := (grip - head).normalized()
	rake.global_position = head
	var fwd := hb * Vector3(0, 0, -1)
	var x := up.cross(fwd).normalized()
	if x.length() > 0.5:
		rake.global_basis = Basis(x, up, x.cross(up)).orthonormalized()


func _lean(c: Node3D, a: float) -> void:
	c.set_override("spine_01", Vector3.RIGHT, -a * 0.5)
	c.set_override("spine_02", Vector3.RIGHT, -a * 0.3)
	c.set_override("spine_03", Vector3.RIGHT, -a * 0.2)


func _neck(c: Node3D, a: float) -> void:
	c.set_override("neck_01", Vector3.RIGHT, a)


func _chest(c: Node3D) -> Vector3:
	return c.to_global(c.bone_position("spine_03")) + c.global_basis * Vector3(0, 0.0, -0.22)


func _hand_r(c: Node3D) -> Vector3:
	return c.to_global((c.bone_position("hand_r") + c.bone_position("index_01_r")) / 2.0)


## Kirjan rivisuunta (kirjan paikallinen +x maailmassa).
func _book_x() -> Vector3:
	return book.global_basis.x


## Piste yliviivatulla rivillä (f 0..1 rivin alusta loppuun; negatiivinen = rivin yläpuolella kohti otsikkoa).
func _line_point(f: float) -> Vector3:
	if f < 0.0:
		return book.to_global(Vector3(-PW + 0.02, 0.025, _row_z(4) + f))
	return book.to_global(Vector3(-PW + 0.008 + f * PW, 0.025, _row_z(4)))


func _stand(c: Node3D, x: float, z: float) -> void:
	c.global_position = _Dg(x, z)


func _stand_h(c: Node3D, x: float, z: float) -> void:
	c.global_position = _Hg(x, z)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.global_position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


func _face_h(c: Node3D, at: Vector2) -> void:
	_face(c, _Hg(at.x, at.y))


# --- Kehys, kamera ------------------------------------------------------------------

## Portaat (z -1,4..0) ja asehuoneen lattia (z 0..3) ovat lattiakorkeudella, muualla maasto.
func _on_floor(x: float, z: float) -> bool:
	if z > LANDING_Z and z <= 0.05:
		return absf(x) < 1.7
	return z > 0.05 and z < INNER_Z and absf(x) < TOWER.x - WALL_T


## Oven kehyksen piste maailmassa seisomakorkeudella (portaat, asehuone tai maasto) + y.
func _Dg(x: float, z: float, y := 0.0) -> Vector3:
	if _on_floor(x, z):
		return _D.to_global(Vector3(x, FLOOR_H + y, z))
	var p := _D.to_global(Vector3(x, 0.0, z))
	return Vector3(p.x, T.h(p.x, p.z) + y, p.z)


## Pöydän pinnan piste (oven kehyksen x, z).
func _Dt(x: float, z: float) -> Vector3:
	return _D.to_global(Vector3(x, FLOOR_H + TABLE.y + 0.006, z))


## Haudan kehyksen piste maanpinnalla + y.
func _Hg(x: float, z: float, y := 0.0) -> Vector3:
	var p := _H.to_global(Vector3(x, 0.0, z))
	return Vector3(p.x, T.h(p.x, p.z) + y, p.z)


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
	if phase == "otsikko":
		var a := clampf((_t - 0.9) / 0.9, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.03, 0.03, 0.3 * a))
		var y := vs.y * 0.17
		_draw_candle_icon(Vector2(vs.x / 2.0, y - 84.0), a)
		var title := "PALON YÖN PYHIMYS"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.1, 0.07, 0.05, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(0.98, 0.9, 0.72, a))
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 158.0, 840, 84)
		_ui.draw_rect(sr, Color(0.04, 0.03, 0.03, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Pyhimys palasi kirkkoon. Suvun nimi pysyi salassa,",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.95, 0.86, 0.66, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "ja kynttilä sammui.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.95, 0.85, a))


## Sammunut kynttilä otsikon yllä: punainen hautakynttilä, musta sydänlanka ja kiemurteleva savu.
func _draw_candle_icon(c: Vector2, a: float) -> void:
	var r := Rect2(c + Vector2(-14, 4), Vector2(28, 34))
	_ui.draw_rect(r.grow(2.5), Color(0.15, 0.04, 0.03, a))
	_ui.draw_rect(r, Color(0.72, 0.13, 0.1, a))
	_ui.draw_rect(Rect2(r.position + Vector2(4, 3), Vector2(5, r.size.y - 8)), Color(0.9, 0.35, 0.3, a))  # kiilto
	_ui.draw_line(c + Vector2(0, 4), c + Vector2(0, -4), Color(0.1, 0.08, 0.06, a), 2.5)
	var pts := PackedVector2Array()
	for i in 18:
		var t := i / 17.0
		pts.append(c + Vector2(sin(t * 7.0 + _t * 2.0) * 6.0 * t, -6.0 - t * 34.0))
	_ui.draw_polyline(pts, Color(0.85, 0.85, 0.85, 0.75 * a), 3.0, true)
