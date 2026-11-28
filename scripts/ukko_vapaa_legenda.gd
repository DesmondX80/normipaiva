extends CanvasLayer
## Legendaarinen hetki "ukko_vapaa" (Ukko vapaaksi): kun Tekojärven Ukko päästetään ensimmäistä kertaa takaisin
## järveen Kaitasaaren kärjestä (main.gd _ukko_release), hetki lavastetaan rannalla. Vaiheet:
##   ranta    pelaaja kyykyssä vesirajassa, Ukko vaakatasossa vedessä käsien varassa; Tauno tulee rantaa pitkin
##            termospullo kainalossa: "Päästätkö sen?" – "Päästän."
##   lusikka  Tauno kyykistyy, kurottaa Ukon selän yli ja irrottaa isänsä punavalkoisen lusikan kyljestä, nostaa sen
##            kasvojensa eteen: "Tämän mää otan. Isä veisti sen itse." Loput uistimet jäävät Ukolle.
##   vapaa    kädet laskevat, Ukko lepää hetken, pyrstö läimäyttää (roiske, Tauno hätkähtää) ja Ukko liukuu selkä
##            pinnassa kohti ladon raunioita; perässä vanavesi ja renkaat. Tauno ja pelaaja nousevat seisomaan.
##   hyppy    huipennus: ladon raunioiden tolppien välissä Ukko hyppää kerran ilmaan kaarena (roiskeet, iso rengas),
##            sitten järvi tasaantuu. Tauno nostaa käden: "Kiitti, Ukko."
##   kahvit   Tauno kaataa termarista kahvit emalimukiin ja ojentaa sen pelaajalle, kaataa itselleen kanteen; höyry nousee.
##            "Isä joi aina kahvit tässä, kun Ukko vei uistimen." – "Kukaan ei usko tätä." – "Ei tarvi."
##   otsikko  takaa: kaksi hahmoa mukit kädessä rannalla, järvi, rauniot ja tasaantuvat renkaat. UKKO VAPAAKSI.
## Kehys: rannan solmu G Kaitasaaren kalapaikalla (main.gd _kala_spot "tekojarvi"), paikallinen -Z = järvelle (dir),
## +x rannalta järvelle katsoen oikealla. Hahmojen etu -Z (Looks). Hauen oma akseli (tekojarvi_legenda.gd): +X kuono,
## +Y selkä, -Z kylki uistimineen. Vedenpinta = Terrain.h vesialueella (kuten shore_fish_game.gd _surface).
## Ladon rauniot (build_ruins) ovat pysyviä: main.gd rakentaa ne järveen, kun kalapaikka tunnetaan (Taunon isän mukaan
## Ukko asuu ladon raunioilla). Tauno muistelee myöhemmin kirppiksellä (main.gd _talk_kirppis "ukko_vapaa_muisto").

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const T := preload("res://scripts/terrain.gd")
const TekojarviLegenda := preload("res://scripts/tekojarvi_legenda.gd")

const DUR := {"ranta": 7.0, "lusikka": 6.6, "vapaa": 7.6, "hyppy": 6.0, "kahvit": 8.4, "otsikko": 6.4}
const ORDER := ["ranta", "lusikka", "vapaa", "hyppy", "kahvit", "otsikko"]
const LEN := 1.32
## Otteet hauen alla (u: 0 = pyrstön tyvi, 1 = kuono): pelaajan kädet vatsan alla keskeltä.
const HOLD_U := [0.62, 0.3]
const JUMP_H := 1.15  # hypyn korkeus vedestä (m)
## Lavastus siirretään kalapaikalta rantaa pitkin (-x): kalapaikan vieressä +x:ssä kasvaa iso kuusi vesirajassa.
const SHIFT_X := -2.5
## Tauno muistelee kirppiksellä (main.gd _talk_kirppis "ukko_vapaa_muisto").
const MUISTO := ["Mää kävin eilen Kaitasaaren kärjessä termarin kanssa. Rauniot oli tyynenä. Mutta tiedätkö, se on siellä.",
	"Isän lusikka on nyt mun pöytälaatikossa. Joskus otan sen esiin. Ukko sai pitää loput, se on reilu kauppa.",
	"Se hyppäsi. Kuuskymmentä vuotta oon kalastanu tuolla, enkä oo nähny sen hyppäävän. Ja sitte se hyppäsi.",
	"Pekka kysy, mihin se Ukko joutu. Sanoin, että kotiin. Pekka ei kysyny enempää."]

var world: Node3D
var spot := Vector3.ZERO  # kalapaikka rannalla (main.gd _kala_spot)
var dir := Vector3.FORWARD  # järvelle
var hide_nodes: Array = []  # oikea pelaaja piiloon kohtauksen ajaksi (kopio näyttelee)
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
var tauno: Node3D
var pike: Node3D
var lure_isa: Node3D  # isän punavalkoinen lusikka (Tauno ottaa)
var thermos: Node3D
var mug: Node3D  # emalimuki (pelaajalle)
var lid: Node3D  # termarin kansi = Taunon kuppi
var _stream: MeshInstance3D
var ruins_c := Vector3.ZERO  # raunioiden keskusta (globaali, vedenpinnalla)
var edge := 1.0  # vesirajan etäisyys kalapaikasta järvelle (m)
var _hold_basis := Basis()
var _hold_pos := Vector3.ZERO
var _swim_basis := Basis()
var _drops: Array = []  # [mesh, nopeus, ikä]
var _rings: Array = []  # [mesh, ikä, kesto, max säde]
var _steam: Array = []  # [mesh, ikä]
var _ring_t := 0.0
var _steam_t := 0.0
var spoon_taken := false
var jumped := false  # testi lukee
var jump_top := 0.0  # hypyn korkein kohta vedestä (testi lukee)
var mug_given := false
var poured := 0.0  # kahvia mukissa 0..1


func _ready() -> void:
	layer = 6
	dir = Vector3(dir.x, 0, dir.z).normalized()
	_G = Node3D.new()
	world.add_child(_G)
	_props.append(_G)
	_G.global_position = Vector3(spot.x, 0.0, spot.z)
	_G.rotation.y = B.yaw_to(dir)  # -Z järvelle
	_G.global_position += _G.global_basis.x * SHIFT_X
	_cam = Camera3D.new()
	_cam.far = 1500.0
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
	_begin("ranta")


# --- Ladon rauniot (pysyvät, main.gd) ------------------------------------------------

## Raunioiden keskusta järvessä: kalapaikalta järvelle 16–34 m, ensimmäinen kohta, jonka ympärillä on vettä joka
## suuntaan (4 m). Palauttaa Vector3.INF, jos ei löydy.
static func ruins_center(w: Node3D, at: Vector3, d: Vector3) -> Vector3:
	d = Vector3(d.x, 0, d.z).normalized()
	var side := d.cross(Vector3.UP)
	for r in range(18, 36):
		var c := at + d * float(r) + side * 3.0
		var ok := true
		for k in 8:
			var a := k * TAU / 8.0
			if w.surface_at(c + Vector3(cos(a), 0, sin(a)) * 4.5) != "water":
				ok = false
				break
		if ok and w.surface_at(c) == "water":
			return Vector3(c.x, T.h(c.x, c.z), c.z)
	return Vector3.INF


## Vanhan ladon rauniot tekojärvessä: harmaantuneet hirsitolpat kahdessa rivissä (kolme sortunut vinoon), katon
## harjapuun pätkä vinossa vedessä, pari lankkua vesirajassa, ulpukanlehtiä ja kaislatuppaita. Tolpissa tumma märkä
## raita vesirajassa. Paikallinen -Z = järvelle (rannasta poispäin).
static func build_ruins(parent: Node3D, c: Vector3, d: Vector3) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	g.global_position = c
	d = Vector3(d.x, 0, d.z).normalized()
	g.rotation.y = B.yaw_to(d) + 0.35
	var wood := Color(0.47, 0.44, 0.4)
	var wet := Color(0.2, 0.19, 0.16)
	var posts := [[-2.6, -1.7, 0.95, 0.0], [0.0, -1.8, 0.62, 0.0], [2.5, -1.6, 0.4, 0.22],
		[-2.5, 1.7, 0.5, -0.18], [0.1, 1.75, 1.05, 0.0], [2.6, 1.8, 0.75, 0.12]]
	for pd in posts:
		var h: float = pd[2]
		var p := Node3D.new()
		p.position = Vector3(pd[0], 0, pd[1])
		p.rotation = Vector3(pd[3], 0, pd[3] * 0.6)
		g.add_child(p)
		B.mesh(p, B.cyl(0.085, 0.1, h + 1.4, 7), Vector3(0, (h - 1.4) / 2.0, 0), wood)
		B.mesh(p, B.cyl(0.103, 0.103, 0.16, 7), Vector3(0, 0.05, 0), wet)  # märkä raita vesirajassa
		# Lahonnut, sahalaitainen pää: kaksi vinoa sälettä.
		B.mesh(p, B.boxm(Vector3(0.05, 0.12, 0.09)), Vector3(0.03, h + 0.05, 0.0), wood.darkened(0.1), Vector3(0, 0, 18))
		B.mesh(p, B.boxm(Vector3(0.04, 0.08, 0.07)), Vector3(-0.04, h + 0.03, 0.02), wood.lightened(0.06), Vector3(10, 0, -14))
	# Harjapuu: pitkä hirsi korkeimman tolpan nojassa, toinen pää vedessä.
	var beam := B.mesh(g, B.cyl(0.075, 0.085, 3.4, 7), Vector3(0.9, 0.42, 1.2), wood.darkened(0.05))
	beam.rotation = Vector3(0, 0.5, deg_to_rad(73))
	# Lankut vesirajassa.
	B.mesh(g, B.boxm(Vector3(2.4, 0.05, 0.22)), Vector3(-1.3, 0.02, -1.75), wood.darkened(0.12), Vector3(0, 6, 2))
	B.mesh(g, B.boxm(Vector3(1.6, 0.05, 0.2)), Vector3(1.4, 0.03, 1.55), wood.darkened(0.08), Vector3(0, -12, -3))
	# Ulpukanlehdet ja kaislat raunioiden ympärillä.
	var rng := RandomNumberGenerator.new()
	rng.seed = 79
	for k in 16:
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.6, 4.4)
		var lp := B.mesh(g, B.cyl(0.16, 0.16, 0.01, 10), Vector3(cos(a) * r, 0.015, sin(a) * r), Color(0.22, 0.42, 0.16).lerp(Color(0.35, 0.5, 0.18), rng.randf()))
		lp.scale = Vector3(1.0, 1.0, rng.randf_range(0.7, 1.0))
	for k in 5:
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.2, 4.6)
		var tuft := Node3D.new()
		tuft.position = Vector3(cos(a) * r, 0, sin(a) * r)
		g.add_child(tuft)
		for j in 9:
			var bl := B.mesh(tuft, B.cyl(0.004, 0.012, 1.1, 4), Vector3(rng.randf_range(-0.18, 0.18), 0.5, rng.randf_range(-0.18, 0.18)), Color(0.45, 0.52, 0.25))
			bl.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
	return g


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	# Vesiraja: kalapaikalta järvelle ensimmäinen vesi.
	for i in 40:
		var z := i * 0.1
		if world.surface_at(_G.to_global(Vector3(0, 0, -z))) == "water":
			edge = z
			break
	var tl: CanvasLayer = TekojarviLegenda.new()  # sama Ukon malli kuin Pirtin pihalla (ei puuhun: vain malli)
	tl.world = world
	pike = tl._build_pike()
	lure_isa = tl.lure_isa
	tl.free()
	_props.append(pike)
	ruins_c = ruins_center(world, spot, dir)
	if ruins_c == Vector3.INF:
		ruins_c = _L(3.0, -(edge + 20.0))
	me = _person(Looks.player(), 0.1, -(edge - 0.04))
	Looks.add_cap(me)
	tauno = _person(TekojarviLegenda.TAUNO, 3.8, -(edge - 0.4))
	thermos = _build_thermos()
	mug = _build_mug()
	mug.visible = false
	_stream = B.mesh(world, B.cyl(0.006, 0.006, 1.0, 6), Vector3.ZERO, Color(0.28, 0.16, 0.08))
	_stream.visible = false
	_props.append(_stream)
	# Pidetty Ukko: vaakatasossa vesirajan edessä, kuono +x (Taunon puolella), uistinkylki järvelle päin (kameraan).
	var gb := _G.global_basis
	_hold_basis = Basis(gb.x, gb.y, gb.z)
	var hp := _L(0.12, -(edge + 0.1))
	_hold_pos = Vector3(hp.x, _water_y(hp) + 0.01, hp.z)
	var d := ruins_c - _hold_pos
	d.y = 0.0
	d = d.normalized()
	_swim_basis = Basis(d, Vector3.UP, d.cross(Vector3.UP))
	pike.global_basis = _hold_basis
	pike.global_position = _hold_pos
	# Ilta-aurinko: lämmin sivuvalo rannalle (kasvot erottuvat vedenpuoleisesta kamerasta).
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.92, 0.82)
	lamp.light_energy = 0.35
	lamp.omni_range = 6.0
	world.add_child(lamp)
	_props.append(lamp)
	lamp.global_position = _L(1.5, -(edge + 2.5), 2.2)


## Termospullo: vihreä teräsrunko, kiiltävät renkaat, hopeinen kansi-kuppi päällä. Pohja origossa.
func _build_thermos() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.18, 0.4, 0.26)
	body.metallic = 0.5
	body.roughness = 0.35
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.78, 0.79, 0.8)
	steel.metallic = 0.9
	steel.roughness = 0.2
	var b := B.mesh(g, B.cyl(0.046, 0.048, 0.27, 14), Vector3(0, 0.135, 0), Color.WHITE)
	b.material_override = body
	for y in [0.012, 0.265]:
		B.mesh(g, B.cyl(0.05, 0.05, 0.018, 14), Vector3(0, y, 0), Color.WHITE).material_override = steel
	B.mesh(g, B.cyl(0.022, 0.03, 0.025, 10), Vector3(0, 0.287, 0), Color(0.15, 0.15, 0.16))  # korkki
	lid = Node3D.new()  # erillinen solmu: kulkee termarin päällä, kunnes kierretään irti (_sync_lid)
	world.add_child(lid)
	_props.append(lid)
	B.mesh(lid, B.cyl(0.05, 0.044, 0.07, 14), Vector3(0, 0.0, 0), Color.WHITE).material_override = steel
	var cf := B.mesh(lid, B.cyl(0.042, 0.042, 0.004, 12), Vector3(0, 0.03, 0), Color(0.22, 0.12, 0.06))
	cf.name = "Kahvi"
	cf.visible = false
	return g


## Emalimuki: valkoinen, sininen reuna, korva. Pohja origossa.
func _build_mug() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var en := StandardMaterial3D.new()
	en.albedo_color = Color(0.95, 0.95, 0.92)
	en.roughness = 0.2
	en.metallic_specular = 0.8
	B.mesh(g, B.cyl(0.042, 0.038, 0.085, 14), Vector3(0, 0.0425, 0), Color.WHITE).material_override = en
	B.mesh(g, B.cyl(0.044, 0.044, 0.008, 14), Vector3(0, 0.084, 0), Color(0.15, 0.25, 0.6))
	var hd := B.mesh(g, B.boxm(Vector3(0.012, 0.055, 0.03)), Vector3(0.05, 0.045, 0), Color(0.95, 0.95, 0.92))
	hd.name = "Korva"
	var cf := B.mesh(g, B.cyl(0.038, 0.038, 0.004, 12), Vector3(0, 0.07, 0), Color(0.22, 0.12, 0.06))
	cf.name = "Kahvi"
	cf.visible = false
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
	for c in [me, tauno]:
		c.clear_ik()
		_lean(c, 0.0)
	_stream.visible = false
	match p:
		"ranta":
			_story = "Kaitasaaren kärki, ilta. Ukko lepää vedessä käsien varassa."
			me.play("Crouch_Idle", 0.0)
			tauno.play("Walk", 0.0, 0.8)
		"lusikka":
			_story = ""
			me.play("Crouch_Idle", 0.0)
			_stand(tauno, 0.62, -(edge + 0.02))
			tauno.play("Crouch_Idle", 0.25)
			_put_thermos_down()
		"vapaa":
			_story = ""
			lure_isa.visible = false  # Tauno pani isän lusikan taskuun
			spoon_taken = true
			me.play("Crouch_Idle", 0.0)
			tauno.play("Crouch_Idle", 0.0)
			_stand(tauno, 0.62, -(edge + 0.02))
		"hyppy":
			_story = ""
			for c in [me, tauno]:
				c.play("Idle", 0.2)
			_stand(me, 0.0, -(edge - 0.35))
			_stand(tauno, 0.8, -(edge - 0.3))
			pike.visible = false
		"kahvit":
			_story = ""
			pike.visible = false
			for c in [me, tauno]:
				c.play("Idle", 0.2)
			_stand(me, -0.05, -(edge - 0.35))
			_stand(tauno, 0.62, -(edge - 0.3))
		"otsikko":
			_story = ""
			pike.visible = false
			for c in [me, tauno]:
				c.play("Idle", 0.2)
			_stand(me, -0.05, -(edge - 0.35))
			_stand(tauno, 0.62, -(edge - 0.3))
			mug_given = true
			poured = 1.0
			Sfx.play("win", -7.0, 0.9)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa rannan E-painalluksesta: sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "ranta" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"ranta":
			_step_ranta()
		"lusikka":
			_step_lusikka()
		"vapaa":
			_step_vapaa(delta)
		"hyppy":
			_step_hyppy(delta)
		"kahvit":
			_step_kahvit(delta)
		"otsikko":
			_step_otsikko(delta)
	_step_fx(delta)
	if not _once.has("kansi"):
		lid.global_transform = thermos.global_transform.translated_local(Vector3(0, 0.3, 0))
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
	for a in [_drops, _rings, _steam]:
		for e in a:
			if is_instance_valid(e[0]):
				e[0].queue_free()
	for nd in _was_visible:
		if is_instance_valid(nd):
			(nd as Node3D).visible = _was_visible[nd]
	finished.emit()
	_cam.queue_free()
	queue_free()


func _step_ranta() -> void:
	# Pelaaja pitää Ukkoa vedessä (kädet vatsan alla), Ukko hengittää: pieni keinunta. Tauno kävelee rantaa pitkin
	# (0–3,4) ja pysähtyy pelaajan viereen termari kainalossa.
	_hold_pike(0.006 * sin(_t * 2.2))
	_hold_hands(1.0)
	var from := Vector2(3.8, -(edge - 0.4))
	var to := Vector2(0.62, -(edge + 0.02))
	var k := clampf(_t / 3.4, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var p := from.lerp(to, e)
	_stand(tauno, p.x, p.y)
	tauno.play("Walk" if k < 1.0 else "Idle", 0.25, 0.8)
	_face(tauno, _pike_pt(0.6) if k >= 1.0 else _L(to.x, to.y))
	_carry_thermos(tauno)
	if _t > 1.8 and _t < 4.2:
		_bub[tauno] = "Kuulin, että sää sait sen."
	elif _t >= 4.2 and _t < 5.6:
		_bub[tauno] = "Päästätkö sen?"
	elif _t >= 5.6:
		_bub.erase(tauno)
		_bub[me] = "Päästän."
	if not _once.has("lisk"):
		_once["lisk"] = true
		Sfx.play("water", -10.0, 0.7)
	# Kuva järveltä matalalta: Ukko vedessä edessä, pelaaja kyykyssä ja Tauno rannalla (rajaus lasketaan).
	var eye := _L(1.4, -(edge + 3.4), 0.0)
	eye.y = _water_y(eye) + 0.85
	_frame(eye, [_pike_pt(1.0), _pike_pt(0.0), _head(me), _head(tauno) + Vector3(0, 0.15, 0), _L(p.x, p.y)], 1.18)


func _step_lusikka() -> void:
	# Tauno kyykyssä Ukon kuonon puolella: kurottaa selän yli (0,4–1,4), irrottaa lusikan (1,6) ja nostaa sen
	# kasvojensa eteen (2,2–3,4). Pelaaja pitää Ukkoa koko ajan.
	_hold_pike(0.004 * sin(_t * 2.2))
	_hold_hands(1.0)
	_face(tauno, _pike_pt(0.75))
	var reach := clampf((_t - 0.4) / 1.0, 0.0, 1.0)
	var lift := clampf((_t - 2.2) / 1.2, 0.0, 1.0)
	var hd := _head(tauno)
	var spoon_at := lure_isa.global_position + _G.global_basis.z * -0.02 + Vector3(0, 0.02, 0)
	var face_pt := hd + tauno.global_basis * Vector3(0.05, -0.12, -0.3)
	if _t < 1.6:
		_reach(tauno, spoon_at, reach, 1.1, "_r")
	else:
		if not spoon_taken:
			spoon_taken = true
			Sfx.play("pickup", -6.0, 1.3)
		_reach(tauno, spoon_at.lerp(face_pt, _ease(lift)), 1.0, 1.1 * (1.0 - lift), "_r")
		var hpos := _hand(tauno, "_r")
		lure_isa.global_basis = tauno.global_basis * Basis(Vector3.RIGHT, -0.3)
		lure_isa.global_position = hpos + tauno.global_basis * Vector3(0, 0.075, -0.05)  # sormien päällä, ei kämmenen takana
	if _t > 2.4 and _t < 4.6:
		_bub[tauno] = "Tämän mää otan. Isä veisti sen itse."
	elif _t >= 4.6:
		_bub[tauno] = "Loput saa Ukko pitää."
	if _t > 2.8:
		_story = "Taunon isän punavalkoinen lusikka. Ukko vei sen kesällä -79."
	# 0–2,2 kuva järveltä Ukosta ja Taunon kurotuksesta; sitten lähikuva Taunon kasvoista ja lusikasta.
	if _t < 2.2:
		var eye := _L(1.5, -(edge + 2.6), 0.0)
		eye.y = _water_y(eye) + 0.75
		_frame(eye, [_pike_pt(1.0), _pike_pt(0.0), _head(tauno), _head(me), lure_isa.global_position], 1.22)
	else:
		var sp := lure_isa.global_position
		var look := (hd + sp) / 2.0
		var eye2 := look + tauno.global_basis * Vector3(-0.45, 0.05, -1.6)
		_frame(eye2, [hd + Vector3(0, 0.16, 0), sp + Vector3(0, -0.06, 0), hd + tauno.global_basis * Vector3(0.24, 0, 0),
			hd + tauno.global_basis * Vector3(-0.24, 0, 0), _hand(tauno, "_r")], 1.35)


func _step_vapaa(delta: float) -> void:
	# 0–1,2 kädet laskevat ja vetäytyvät, Ukko lepää; 1,3 pyrstö läimäyttää (roiske, Tauno hätkähtää);
	# 1,8– Ukko liukuu selkä pinnassa kohti raunioita (vanavesi), hahmot nousevat (2,3) ja katsovat perään.
	var lower := clampf(_t / 1.0, 0.0, 1.0)
	if _t < 1.8:
		var flick := 0.0
		if _t > 1.3:
			flick = sin((_t - 1.3) * 22.0) * 0.35 * exp(-(_t - 1.3) * 4.0)
		pike.global_basis = Basis(Vector3.UP, flick) * _hold_basis
		pike.global_position = _hold_pos + Vector3(0, -0.015 * lower, 0)
		_hold_hands(1.0 - lower)
		if _t > 1.3 and not _once.has("lais"):
			_once["lais"] = true
			Sfx.play("water", -2.0, 1.1)
			_splash(_pike_pt(0.02), 14, 2.4)
			_ring(_pike_pt(0.0), 1.4, 1.2)
		if _t > 1.3:
			var fl := clampf((_t - 1.3) / 0.25, 0.0, 1.0) * (1.0 - clampf((_t - 1.8) / 0.4, 0.0, 1.0))
			tauno.set_override("spine_01", Vector3.RIGHT, 0.22 * fl)  # hätkähdys taaksepäin
	else:
		var k := clampf((_t - 1.8) / 5.4, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 1.7)  # lähtö nopeasti, hidastuu raunioille
		var turn := _ease(clampf((_t - 1.8) / 0.7, 0.0, 1.0))
		var wig := sin(_t * 9.0) * 0.12 * (1.0 - k * 0.5)
		var b := Basis(Quaternion(_hold_basis).slerp(Quaternion(_swim_basis), turn))
		pike.global_basis = Basis(Vector3.UP, wig) * b
		var end := ruins_c - (_swim_basis.x) * 1.2
		var pos := _hold_pos.lerp(end, e)
		pos.y = _water_y(pos) - 0.07 - 0.25 * clampf((k - 0.85) / 0.15, 0.0, 1.0)  # selkä pinnassa, sukeltaa lopuksi
		pike.global_position = pos
		_ring_t -= delta
		if _ring_t <= 0.0 and k < 0.97:
			_ring_t = 0.16
			_ring(_pike_pt(0.15), 0.9 + k, 1.4)
	if _t > 2.3:
		for c in [me, tauno]:
			c.play("Idle", 0.35)
		_face(me, pike.global_position)
		_face(tauno, pike.global_position)
		_stand(me, 0.0, -(edge - 0.35))
		_stand(tauno, 0.8, -(edge - 0.3))
	if _t > 3.0:
		_story = "Ukko liukuu kohti vanhan ladon raunioita."
	if _t > 4.4:
		_bub[tauno] = "Kotiin se menee."
	if _t < 1.9:
		# Matala kuva järveltä: kädet, Ukko ja pyrstön roiske.
		var eye := _L(0.6, -(edge + 1.9), 0.0)
		eye.y = _water_y(eye) + 0.6
		_frame(eye, [_pike_pt(1.0) + Vector3(0, 0.1, 0), _pike_pt(0.0) + Vector3(0, 0.45, 0), _pike_pt(0.0) + Vector3(0, -0.08, 0),
			_hand(me, "_r"), _hand(me, "_l")], 1.2)
	else:
		# Hahmojen takaa korkealta: Ukon vanavesi ja rauniot, hahmot alareunassa.
		var eye := _L(0.35, 2.6, 2.3)
		_frame(eye, [_head(me), _head(tauno), pike.global_position, ruins_c + Vector3(0, 1.0, 0), _L(0.4, -(edge - 0.3))], 1.1)


func _step_hyppy(delta: float) -> void:
	# Huipennus: 0–0,9 tyyntä raunioilla; 0,9–2,1 Ukko hyppää kaarena tolppien välissä (roiske ylös ja alas, iso
	# rengas); 2,6– Tauno nostaa käden ja vilkuttaa.
	var jt := clampf((_t - 0.9) / 1.2, 0.0, 1.0)
	var fwd: Vector3 = _G.global_basis.x  # hyppy rannan suuntaisesti: kaari näkyy rannalta sivuprofiilina
	var jb := Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP))
	if _t >= 0.9 and _t < 2.1:
		pike.visible = true
		var pos := ruins_c - fwd * 1.0 + fwd * 2.0 * jt
		var hgt := JUMP_H * sin(PI * jt)
		pos.y = _water_y(pos) + hgt - 0.05
		var pitch := lerpf(1.0, -1.1, jt)
		var bend := sin(_t * 14.0) * 0.12
		pike.global_basis = jb * Basis(Vector3(0, 0, 1), pitch) * Basis(Vector3.UP, bend)
		pike.global_position = pos
		jumped = true
		jump_top = maxf(jump_top, hgt)
		if not _once.has("ylos"):
			_once["ylos"] = true
			Sfx.play("water", 0.0, 0.9)
			_splash(ruins_c - fwd * 1.0, 26, 3.6)
			_ring(ruins_c - fwd * 1.0, 2.6, 2.4)
	elif _t >= 2.1:
		pike.visible = false
		if not _once.has("alas"):
			_once["alas"] = true
			Sfx.play("water", 2.0, 0.7)
			_splash(ruins_c + fwd * 1.0, 34, 4.2)
			_ring(ruins_c + fwd * 1.0, 3.6, 3.0)
			_ring(ruins_c + fwd * 1.0, 2.2, 2.2)
	if _t > 0.6:
		_story = "Ladon raunioilla Ukko hyppäsi kerran. Sitten järvi tasaantui."
	for c in [me, tauno]:
		_face(c, ruins_c)
	var wave := clampf((_t - 2.7) / 0.5, 0.0, 1.0)
	if wave > 0.0:
		var hd := _head(tauno)
		var up := hd + tauno.global_basis * Vector3(0.32, 0.25 + 0.05 * sin(_t * 7.0), -0.15)
		_reach(tauno, up, wave, 0.0, "_r")
	if _t > 3.0:
		_bub[tauno] = "Kiitti, Ukko."
	if _t < 2.6:
		# Teleobjektiivi rannalta hahmojen välistä: rauniot ja hyppy (leveys n. 7 m).
		var eye := _L(-0.6, -(edge - 0.3) + 1.6, 2.1)
		var look := ruins_c + Vector3(0, 0.7, 0)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 6.2))
	else:
		# Olan yli sivulta: Taunon vilkutus ja renkaat raunioilla taustalla.
		var eye := _L(2.2, 1.5, 1.7)
		_frame(eye, [_head(tauno) + Vector3(0, 0.25, 0), _hand(tauno, "_r"), _head(me), ruins_c + Vector3(0, 0.6, 0)], 1.12)


func _step_kahvit(delta: float) -> void:
	# 0–0,8 Tauno ottaa termarin ja kannen; 0,8–2,6 kaataa kahvia mukiin (vasen käsi pitää mukia); 2,6–3,6 ojentaa
	# mukin pelaajalle; 3,6–5,2 kaataa itselleen kanteen; 5,6– molemmat juovat ja katsovat järvelle.
	var tb := tauno.global_basis
	var th := _head(tauno)
	var mug_l := th + tb * Vector3(-0.08, -0.55, -0.34)  # muki rinnan edessä
	var pour_r := mug_l + tb * Vector3(0.11, 0.16, 0.0)
	var to_me := (_head(me) + _head(tauno)) / 2.0 + Vector3(0, -0.45, 0) + tb * Vector3(0, 0, -0.18)
	var cup_r := th + tb * Vector3(0.08, -0.55, -0.34)
	var pour_l := cup_r + tb * Vector3(-0.11, 0.16, 0.0)
	var take := _ease(clampf(_t / 0.8, 0.0, 1.0))
	_face(me, _L(0.3, -(edge + 6.0)) if _t > 5.4 else _head(tauno))
	_face(tauno, _L(0.3, -(edge + 6.0)) if _t > 5.4 else _head(me))
	mug.visible = true
	if _t < 3.6:  # kansi kierretty irti ja laskettu kivelle odottamaan
		_once["kansi"] = true
		lid.global_basis = Basis()
		lid.global_position = _L(1.2, -(edge - 0.55), 0.035)
	if _t < 2.6:
		_reach(tauno, mug_l, take, 0.0, "_l")
		_reach(tauno, pour_r, take, 0.0, "_r")
		_place_in(mug, _hand(tauno, "_l"), tb, false)
		var tilt := _ease(clampf((_t - 0.8) / 0.4, 0.0, 1.0))
		_place_thermos(_hand(tauno, "_r"), mug.global_position, tilt * 1.9)
		if _t > 1.1:
			poured = clampf((_t - 1.1) / 1.3, 0.0, 1.0)
			_pour_stream(mug.global_position + Vector3(0, 0.07, 0))
			if not _once.has("kaato"):
				_once["kaato"] = true
				Sfx.play("glass", -12.0, 0.6)
	elif _t < 3.6:
		var g := _ease(clampf((_t - 2.6) / 0.6, 0.0, 1.0))
		_reach(tauno, mug_l.lerp(to_me, g), 1.0, 0.0, "_l")
		_reach(tauno, pour_r, 1.0 - g * 0.6, 0.0, "_r")
		_place_thermos(_hand(tauno, "_r"), Vector3.ZERO, 0.0)
		if _t > 3.15:
			_reach(me, to_me, clampf((_t - 3.0) / 0.3, 0.0, 1.0), 0.0, "_r")
		if _t > 3.35:
			mug_given = true
		_place_in(mug, _hand(me, "_r") if mug_given else _hand(tauno, "_l"), me.global_basis if mug_given else tb, mug_given)
	else:
		_place_in(mug, _hand(me, "_r"), me.global_basis, true)
		var drink_me := _ease(clampf((_t - 5.8) / 0.6, 0.0, 1.0)) * (1.0 - _ease(clampf((_t - 7.4) / 0.5, 0.0, 1.0)))
		var mh := _head(me)
		var me_chest := mh + me.global_basis * Vector3(0.1, -0.5, -0.3)
		var me_mouth := mh + me.global_basis * Vector3(0.02, -0.17, -0.15)
		_reach(me, me_chest.lerp(me_mouth, drink_me), 1.0, 0.0, "_r")
		if _t < 5.4:
			_reach(tauno, cup_r, 1.0, 0.0, "_r")
			_reach(tauno, pour_l, 1.0, 0.0, "_l")
			var tilt2 := _ease(clampf((_t - 3.8) / 0.3, 0.0, 1.0)) * (1.0 - _ease(clampf((_t - 5.0) / 0.3, 0.0, 1.0)))
			_place_lid(_hand(tauno, "_r"), tb)
			_place_thermos(_hand(tauno, "_l"), lid.global_position, tilt2 * 1.9)
			if _t > 4.0 and _t < 5.0:
				_pour_stream(lid.global_position + Vector3(0, 0.03, 0))
				lid.get_node("Kahvi").visible = true
		else:
			var drink := _ease(clampf((_t - 6.2) / 0.6, 0.0, 1.0)) * (1.0 - _ease(clampf((_t - 7.8) / 0.4, 0.0, 1.0)))
			var t_chest := th + tb * Vector3(0.1, -0.5, -0.3)
			var t_mouth := th + tb * Vector3(0.02, -0.17, -0.15)
			_reach(tauno, t_chest.lerp(t_mouth, drink), 1.0, 0.0, "_r")
			_place_lid(_hand(tauno, "_r"), tb)
			tauno.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", tauno.bone_position("upperarm_l") + Vector3(0.1, -0.5, -0.05), tauno.bone_position("upperarm_l") + Vector3(0.4, -0.2, 0.2))
			thermos.global_position = _L(1.05, -(edge - 0.45))
			thermos.global_basis = Basis()
	mug.get_node("Kahvi").visible = poured > 0.05
	_steam_t -= delta
	if _steam_t <= 0.0 and poured > 0.3:
		_steam_t = 0.14
		_puff(mug.global_position + Vector3(0, 0.1, 0))
		if lid.get_node("Kahvi").visible:
			_puff(lid.global_position + Vector3(0, 0.05, 0))
	if _t > 0.8 and _t < 3.6:
		_bub[tauno] = "Kahvit. Isä joi aina kahvit tässä, kun Ukko vei uistimen."
	elif _t >= 3.6 and _t < 5.6:
		_bub[tauno] = "Kukaan ei usko tätä."
	elif _t >= 5.6 and _t < 7.0:
		_bub.erase(tauno)
		_bub[me] = "Ei tarvi."
	elif _t >= 7.0:
		_bub.erase(me)
		_bub[tauno] = "Ei niin."
	# Kaksoiskuva järveltä vinosti: kasvot, kädet ja mukit (leveys lasketaan pisteistä).
	var eye := _L(1.6, -(edge + 2.4), 0.0)
	eye.y = _water_y(eye) + 1.35
	_frame(eye, [_head(me) + Vector3(0, 0.2, 0), _head(tauno) + Vector3(0, 0.2, 0), mug.global_position, _hand(tauno, "_l"),
		_hand(tauno, "_r"), _head(me) + Vector3(0, -0.75, 0)], 1.15)


func _step_otsikko(delta: float) -> void:
	# Takaa ja ylhäältä: kaksi hahmoa mukit kädessä, järvi ja rauniot, renkaat tasaantuvat.
	var tb := tauno.global_basis
	_place_in(mug, _hand(me, "_r"), me.global_basis, true)
	for c in [me, tauno]:
		_face(c, ruins_c)
	var mh := _head(me)
	_reach(me, mh + me.global_basis * Vector3(0.1, -0.5, -0.3), 1.0, 0.0, "_r")
	var th := _head(tauno)
	_reach(tauno, th + tb * Vector3(0.1, -0.5, -0.3), 1.0, 0.0, "_r")
	_place_lid(_hand(tauno, "_r"), tb)
	lid.get_node("Kahvi").visible = true
	mug.get_node("Kahvi").visible = true
	thermos.global_position = _L(1.05, -(edge - 0.45))
	thermos.global_basis = Basis()
	if _t < 0.05:
		_ring(ruins_c, 2.4, 3.0)
	_steam_t -= delta
	if _steam_t <= 0.0:
		_steam_t = 0.18
		_puff(mug.global_position + Vector3(0, 0.1, 0))
		_puff(lid.global_position + Vector3(0, 0.05, 0))
	var eye := _L(-0.6, 3.6, 2.6)
	_frame(eye, [_head(me), _head(tauno), _L(0.3, -(edge - 0.35)), ruins_c + Vector3(0, 1.2, 0), ruins_c + _G.global_basis.x * 4.0,
		ruins_c - _G.global_basis.x * 4.0], 1.12)


# --- Ukko, kädet, esineet --------------------------------------------------------------

func _hold_pike(bob: float) -> void:
	pike.global_basis = _hold_basis
	pike.global_position = _hold_pos + Vector3(0, bob, 0)


## Pelaajan kädet Ukon vatsan alle (w 1 = otteessa, 0 = kädet levossa polvilla); kumarrus kantaa olkapäät eteen.
func _hold_hands(w: float) -> void:
	_lean(me, 1.4 * w)
	var pa := grip_pt(HOLD_U[0])
	var pb := grip_pt(HOLD_U[1])
	var la := me.to_local(pa)
	var lb := me.to_local(pb)
	var sr: Vector3 = me.bone_position("upperarm_r")
	var sl: Vector3 = me.bone_position("upperarm_l")
	if (la.x - lb.x) * (sr.x - sl.x) < 0.0:
		var tmp := la
		la = lb
		lb = tmp
	# IK vie ranteen; kämmenen keskikohta (ranne–etusormen tyvi) osuu kylkeen, kun ranne siirretään sen verran taakse.
	la -= (me.bone_position("index_01_r") - me.bone_position("hand_r")) * 0.5
	lb -= (me.bone_position("index_01_l") - me.bone_position("hand_l")) * 0.5
	var rr := sr + Vector3(signf(sr.x) * 0.1, -0.45, -0.25)
	var rl := sl + Vector3(signf(sl.x) * 0.1, -0.45, -0.25)
	me.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", rr.lerp(la, w), sr + Vector3(signf(sr.x) * 0.4, -0.2, 0.2))
	me.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", rl.lerp(lb, w), sl + Vector3(signf(sl.x) * 0.4, -0.2, 0.2))


## Otteen kohta: rannanpuoleinen kylki (hauen +Z) vesirajan alla kohdassa u; kädet kannattelevat kylkeä, eivät
## katoa kokonaan vatsan alle veteen.
func grip_pt(u: float) -> Vector3:
	var hw := TekojarviLegenda._pike_wh(u)
	var x := -LEN * 0.42 + u * LEN * 0.92
	return pike.to_global(Vector3(x, -hw.x * 0.1, hw.y + 0.012))


## Piste hauen pinnalla (kuten tekojarvi_legenda.gd): u pituudella, side -1 = vatsa, 0 = uistinkylki, +1 = selkä.
func _pike_pt(u: float, side := 0.0, dz := 0.0) -> Vector3:
	var hw := TekojarviLegenda._pike_wh(u)
	var x := -LEN * 0.42 + u * LEN * 0.92
	var a := side * PI / 2.0
	return pike.to_global(Vector3(x, sin(a) * (hw.x + 0.012), -cos(a) * hw.y + dz))


func _carry_thermos(c: Node3D) -> void:
	# Termari vasemmassa kädessä pystyssä (käsi alhaalla kyljellä).
	var sl: Vector3 = c.bone_position("upperarm_l")
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", sl + Vector3(signf(sl.x) * 0.08, -0.5, -0.12), sl + Vector3(signf(sl.x) * 0.4, -0.2, 0.2))
	_place_thermos(_hand(c, "_l"), Vector3.ZERO, 0.0, -0.13)


func _put_thermos_down() -> void:
	thermos.global_basis = Basis()
	thermos.global_position = _L(1.32, -(edge - 0.32))


## Termari käteen: ote rungon keskeltä (oy = otteen korkeus termarin akselilla, negatiivinen = ote pohjan yläpuolella).
## tilt kallistaa termarin suun kohti pistettä toward (kaato); 0 = pystyssä.
func _place_thermos(hand: Vector3, toward: Vector3, tilt: float, oy := -0.14) -> void:
	var b := Basis()
	var dh := toward - hand
	dh.y = 0.0
	if tilt != 0.0 and dh.length() > 0.001:
		b = Basis(Vector3.UP.cross(dh.normalized()), tilt)
	thermos.global_basis = b
	thermos.global_position = hand + b * Vector3(0, oy, 0)


func _place_lid(hand: Vector3, basis: Basis) -> void:
	# Kansi irti termarista Taunon oikeaan käteen kupiksi.
	_once["kansi"] = true
	lid.global_basis = basis
	lid.global_position = hand + basis * Vector3(0, 0.0, -0.02)


func _place_in(obj: Node3D, hand: Vector3, basis: Basis, _flip: bool) -> void:
	obj.global_basis = basis
	obj.global_position = hand + basis * Vector3(0, -0.035, -0.035)


func _pour_stream(to: Vector3) -> void:
	# Kahvisuihku termarin suulta astiaan (lieriön akseli Y suuta kohti).
	var mouth := thermos.global_position + thermos.global_basis * Vector3(0, 0.3, 0)
	var d := to - mouth
	if d.length() < 0.01:
		return
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	_stream.visible = true
	_stream.global_basis = Basis(x, y, x.cross(y))
	_stream.global_position = (mouth + to) / 2.0
	_stream.scale = Vector3(1.0, d.length(), 1.0)


# --- Roiskeet, renkaat, höyry --------------------------------------------------------

func _splash(at: Vector3, n: int, power: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.92, 1.0, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 1.0
	for i in n:
		var d := B.mesh(world, B.sphere(0.5, 6), at, Color.WHITE)
		d.material_override = m
		var s := randf_range(0.012, 0.03)
		d.scale = Vector3(s, s * 2.2, s)
		var a := randf() * TAU
		var v := Vector3(cos(a) * randf_range(0.4, 1.4), power * randf_range(0.55, 1.0), sin(a) * randf_range(0.4, 1.4))
		_drops.append([d, v, 0.0])


func _ring(at: Vector3, max_r: float, dur: float) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.92, 0.95, 1.0, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	world.add_child(mi)
	mi.global_position = Vector3(at.x, _water_y(at) + 0.015, at.z)
	mi.scale = Vector3(0.1, 0.02, 0.1)
	_rings.append([mi, 0.0, dur, max_r])


func _puff(at: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var p := B.mesh(world, B.sphere(0.5, 8), at + Vector3(randf_range(-0.01, 0.01), 0, randf_range(-0.01, 0.01)), Color.WHITE)
	p.material_override = m
	p.scale = Vector3.ONE * 0.025
	_steam.append([p, 0.0])


func _step_fx(delta: float) -> void:
	for e in _drops.duplicate():
		var d: MeshInstance3D = e[0]
		e[2] += delta
		e[1].y -= 9.8 * delta
		d.global_position += e[1] * delta
		if e[2] > 1.6 or (e[1].y < 0.0 and d.global_position.y < _water_y(d.global_position)):
			d.queue_free()
			_drops.erase(e)
	for e in _rings.duplicate():
		var r: MeshInstance3D = e[0]
		e[1] += delta
		var k: float = e[1] / e[2]
		var s: float = lerpf(0.1, e[3], 1.0 - pow(1.0 - minf(k, 1.0), 2.0))
		r.scale = Vector3(s, 0.02, s)
		(r.material_override as StandardMaterial3D).albedo_color.a = 0.55 * (1.0 - k)
		if k >= 1.0:
			r.queue_free()
			_rings.erase(e)
	for e in _steam.duplicate():
		var p: MeshInstance3D = e[0]
		e[1] += delta
		var k: float = e[1] / 1.3
		p.global_position += Vector3(0.02 * sin(e[1] * 5.0), 0.16, 0.0) * delta
		p.scale = Vector3(1.0, 1.6, 1.0) * lerpf(0.015, 0.05, k)
		(p.material_override as StandardMaterial3D).albedo_color.a = 0.16 * (1.0 - k)
		if k >= 1.0:
			p.queue_free()
			_steam.erase(e)


# --- Apufunktiot ---------------------------------------------------------------------

## Kumarrus koko selällä (rad yhteensä), niska kompensoi (kuten tokola_legenda.gd _lean).
func _lean(c: Node3D, a: float) -> void:
	c.set_override("spine_01", Vector3.RIGHT, -a * 0.45)
	c.set_override("spine_02", Vector3.RIGHT, -a * 0.35)
	c.set_override("spine_03", Vector3.RIGHT, -a * 0.2)
	c.set_override("neck_01", Vector3.RIGHT, a * 0.35)


## Käsi (side "_r"/"_l") kohti pistettä (w 0..1); lean kumartaa selkää samassa suhteessa.
func _reach(c: Node3D, at_global: Vector3, w: float, lean := 0.0, side := "_r") -> void:
	if lean != 0.0:
		_lean(c, lean * w)
	var sh: Vector3 = c.bone_position("upperarm" + side)
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at_global), w)
	c.set_ik("arm" + side, "upperarm" + side, "lowerarm" + side, "hand" + side, tgt, sh + Vector3(s * 0.45, -0.25, 0.25))


func _hand(c: Node3D, side := "_r") -> Vector3:
	return c.to_global((c.bone_position("hand" + side) + c.bone_position("index_01" + side)) / 2.0)


func _head(c: Node3D) -> Vector3:
	return c.to_global(c.bone_position("Head"))


func _stand(c: Node3D, x: float, z: float) -> void:
	c.global_position = _L(x, z)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.global_position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


## Rannan piste (x, z) maanpinnalla + y.
func _L(x: float, z: float, y := 0.0) -> Vector3:
	var p := _G.to_global(Vector3(x, 0.0, z))
	return Vector3(p.x, T.h(p.x, p.z) + y, p.z)


func _water_y(p: Vector3) -> float:
	return T.h(p.x, p.z)


func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(eye, look)


func _fov_w(d: float, w: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return rad_to_deg(2.0 * atan(w / (2.0 * d) / (vs.x / vs.y)))


## Kamera silmästä pisteiden keskelle; pystykenttä lasketaan niin, että kaikki pisteet mahtuvat ruutuun (margin).
func _frame(eye: Vector3, pts: Array, margin := 1.15) -> void:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	_cam.look_at_from_position(eye, c)
	var inv := _cam.global_transform.affine_inverse()
	var vs := get_viewport().get_visible_rect().size
	var asp := vs.x / vs.y
	var half := 0.05
	for p in pts:
		var v: Vector3 = inv * p
		var z := maxf(0.1, -v.z)
		half = maxf(half, maxf(absf(v.y) / z, absf(v.x) / z / asp))
	_cam.fov = clampf(rad_to_deg(2.0 * atan(half * margin)), 6.0, 80.0)


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
		var a := clampf((_t - 0.8) / 0.9, 0.0, 1.0)
		var y := vs.y * 0.18
		var title := "UKKO VAPAAKSI"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 64, 12, Color(0.04, 0.07, 0.1, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 64, Color(0.95, 0.88, 0.6, a))
		_draw_icon(Vector2(vs.x / 2.0, y + 50.0), a)
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 150.0, 840, 84)
		_ui.draw_rect(sr, Color(0.03, 0.05, 0.07, 0.78 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 32), "Tekojärven Ukko ui takaisin ladon raunioille.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.8, 0.9, 1.0, a))
		_ui.draw_string(font, sr.position + Vector2(0, 62), "Tauno tarjosi kahvit.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.92, 0.75, a))


## Kuvake: hauen siluetti kaarena aallon yllä.
func _draw_icon(c: Vector2, a: float) -> void:
	var col := Color(0.95, 0.88, 0.6, a)
	var pts := PackedVector2Array()
	for i in 13:
		var k := float(i) / 12.0
		pts.append(c + Vector2(lerpf(-34, 34, k), -14.0 * sin(PI * k)))
	_ui.draw_polyline(pts, col, 6.0, true)
	_ui.draw_colored_polygon(PackedVector2Array([c + Vector2(34, 0), c + Vector2(44, -8), c + Vector2(42, 6)]), col)
	var w := PackedVector2Array()
	for i in 25:
		var k := float(i) / 24.0
		w.append(c + Vector2(lerpf(-50, 50, k), 10.0 + 3.0 * sin(k * TAU * 3.0)))
	_ui.draw_polyline(w, Color(0.6, 0.8, 1.0, a), 2.5, true)
