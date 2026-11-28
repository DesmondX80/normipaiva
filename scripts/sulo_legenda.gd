extends CanvasLayer
## Legendaarinen hetki "sulon_pannu" (Vanhan Sulon pannu): kun Pilkkarinnevalta kaivettu kuparipannu viedään
## ensimmäistä kertaa Pannu-Sulolle (main.gd _pannu_to_sulo), hetki lavastetaan Sulon pontikkapannun luona metsässä.
## Vaiheet:
##   pannu    rämeen vihertämä kuparipannu laakealle kivelle tulen viereen. Sulo kääntyy pannultaan: "...Mistä sää tämän sait?"
##   leima    Sulo polvistuu ja hankaa hihallaan vihreää kylkeä: kuparin alta paljastuu isän lyömä leima "V.S. 1952"
##   myonto   Sulo nousee ja katsoo Pilkkarinnevalle päin, käsi rinnalla. Kuusikymmentä vuotta kieltämistä loppuu:
##            "Isä keitti. Ja hyvää keitti."
##   tipat    Sulo ottaa tynnyrin kanneltä kuksan ja heittää ensimmäiset tipat tuleen isälle: liekki leimahtaa sinisenä.
##            Pekka ja Arto tulevat savun perässä, Pekka maistaa: "...Perkele. Kaljapuhetta, mää sanoin. Taas väärin."
##   otsikko  kaikki pannun ympärillä: VANHAN SULON PANNU, Sulo myönsi
## Kehys: solmu G pontikkapannun paikalla (M.PONTIKKA) samassa kierrossa kuin world.gd _build_pontikka (0,4 rad), joten
## paikalliset koordinaatit ovat samat kuin rakennuksessa: tuli ja pannu origossa, sininen tynnyri +x 1,45, kanisterit
## +z, pressukatos -z -1,6. Avoin aukea on -z puolella (x 0..2), sinne kivi ja hahmot. Hahmojen etu -Z (Looks).
## Maan korkeus Terrain.h:sta. Oikea Sulo ja pelaaja piiloon kohtauksen ajaksi (kopiot näyttelevät).
## Isän pannu jää pontikkapannun viereen kivelle pysyvästi (main.gd _pannu_update). Sulo muistelee (main.gd "pannu_muisto").

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const T := preload("res://scripts/terrain.gd")
const M := preload("res://scripts/map_data.gd")
const SuloPannu := preload("res://scripts/sulo_pannu.gd")

const DUR := {"pannu": 5.6, "leima": 7.0, "myonto": 7.4, "tipat": 9.6, "otsikko": 6.4}
const ORDER := ["pannu", "leima", "myonto", "tipat", "otsikko"]
const YAW := 0.4  # world.gd _build_pontikka root.rotation.y
const STONE := Vector2(0.75, -1.45)  # laakea kivi, jolle isän pannu lasketaan
const STONE_H := 0.16
const SULO_KNEEL := Vector2(0.75, -0.98)  # Sulo polvillaan kiven ja tulen välissä, kasvot -z (pannuun)
const SULO_STAND := Vector2(0.95, -1.05)
const SULO_BARREL := Vector2(1.25, -0.62)  # tynnyrin edessä (kuksa kannella)
const ME_AT := Vector2(-0.35, -1.95)
const ME_FIRE := Vector2(0.45, 1.3)  # tulen takana (heittokuvassa kameraa vastapäätä, ei etualalla)
const PEKKA_AT := Vector2(1.95, -1.75)
const ARTO_AT := Vector2(2.35, -1.05)
const BARREL := Vector3(1.45, 0.9, 0.0)  # tynnyrin kansi (world.gd: cyl 0,3 x 0,9 keskellä y 0,45)
const FIRE := Vector3(0.0, 0.2, 0.0)
const COPPER := Color(0.78, 0.45, 0.24)
const PATINA := Color(0.33, 0.56, 0.47)
## Sulo muistelee myöhemmin (main.gd _talk_choose "sulo" -> "pannu_muisto").
const MUISTO := ["Muistatko, kun liekki leimahti siniseksi? Isä otti omansa. Niin mää sen ajattelen.",
	"Leima on nyt kirkas. Hankaan sitä joka kerta, ennen ku pannu menee tulelle. V. S. viiskytkaks.",
	"Pekka kävi eilen ja pyysi anteeks. Ei sanonu sitä suoraan, mutta toi sokeria.",
	"Kuuskymmentä vuotta mää kielsin. Nyt mää kerron kaikille, kuka sitä kysyy. Isä keitti."]

var world: Node3D
var hide_nodes: Array = []  # oikea pelaaja ja oikea Sulo piiloon kohtauksen ajaksi
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
var sulo: Node3D
var pekka: Node3D
var arto: Node3D
var pan: Node3D  # isän pannu
var stamp: Node3D  # leima kyljessä (paikallinen +x pannussa)
var _patina_mat: StandardMaterial3D  # leiman päällä oleva vihreä kerros, haihtuu hangatessa
var kuksa: Node3D
var _kuksa_rest := Vector3.ZERO  # kuksa tynnyrin kannella (käsi kurottaa tähän, ei kuksan nykyiseen paikkaan)
var _flare: CPUParticles3D
var _splash: CPUParticles3D
var _flare_light: OmniLight3D
var _pointing := {}
var rubbed := 0.0  # 0 = leima vihreän alla, 1 = kirkas (testi lukee)
var flared := false  # testi lukee
var tasted := false  # testi lukee


func _ready() -> void:
	layer = 6
	process_priority = 100  # hahmojen asento ensin, sitten etusormi suoraksi
	_G = Node3D.new()
	world.add_child(_G)
	_props.append(_G)
	var c := M.w2(M.PONTIKKA)
	_G.global_position = Vector3(c.x, T.h(c.x, c.y), c.y)  # world.gd _lift_objects nostaa pontikkapannun maahan
	_G.rotation.y = YAW
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
	_begin("pannu")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	_build_stone()
	pan = build_pan(world, true)
	_props.append(pan)
	pan.global_position = _L(STONE.x, STONE.y, STONE_H)
	# Leima (pannun +x) kameran puolelle: pannun +x osoittaa paikallista suuntaa (1, 0, -0.6) eli aukealle.
	pan.global_rotation = Vector3(0, YAW + 0.54, 0)
	kuksa = _build_kuksa()
	kuksa.global_position = _G.to_global(BARREL + Vector3(-0.08, 0.002, -0.1))
	kuksa.global_position.y = BARREL.y + _G.global_position.y + 0.002
	_kuksa_rest = kuksa.global_position
	# Tisle tuleen: ohut suihku kuksasta ja leimahdus tulessa (sininen ja oranssi liekki, valo).
	_splash = CPUParticles3D.new()
	world.add_child(_splash)
	_props.append(_splash)
	var sm := SphereMesh.new()
	sm.radius = 0.008
	sm.height = 0.016
	var smat := B.mat(Color(0.85, 0.92, 1.0, 0.7))
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	_splash.mesh = sm
	_splash.amount = 140
	_splash.lifetime = 0.5
	_splash.emitting = false
	_splash.spread = 8.0
	_splash.initial_velocity_min = 1.7
	_splash.initial_velocity_max = 2.0
	_splash.gravity = Vector3(0, -9.0, 0)
	_flare = CPUParticles3D.new()
	world.add_child(_flare)
	_props.append(_flare)
	var fm := QuadMesh.new()
	fm.size = Vector2(0.3, 0.46)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmat.vertex_color_use_as_albedo = true
	fmat.albedo_texture = _flame_tex()
	fm.material = fmat
	_flare.mesh = fm
	_flare.amount = 110
	_flare.lifetime = 0.9
	_flare.emitting = false
	_flare.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flare.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_flare.emission_ring_axis = Vector3.UP
	_flare.emission_ring_radius = 0.42  # pannun kyljen ympäriltä: liekki nousee pannun ohi näkyviin
	_flare.emission_ring_inner_radius = 0.3
	_flare.emission_ring_height = 0.05
	_flare.direction = Vector3(0, 1, 0)
	_flare.spread = 18.0
	_flare.initial_velocity_min = 0.5
	_flare.initial_velocity_max = 1.2
	_flare.gravity = Vector3(0, 0.6, 0)
	_flare.scale_amount_min = 0.8
	_flare.scale_amount_max = 1.8
	var grad := Gradient.new()
	grad.set_color(0, Color(0.2, 0.45, 1.0, 0.95))
	grad.set_color(1, Color(1.0, 0.5, 0.1, 0.0))
	grad.add_point(0.5, Color(0.35, 0.6, 1.0, 0.85))
	_flare.color_ramp = grad
	_flare.global_position = _G.to_global(FIRE)
	_flare_light = OmniLight3D.new()
	world.add_child(_flare_light)
	_props.append(_flare_light)
	_flare_light.light_color = Color(0.55, 0.7, 1.0)
	_flare_light.light_energy = 0.0
	_flare_light.omni_range = 5.0
	_flare_light.global_position = _G.to_global(FIRE + Vector3(0, 0.6, 0))
	sulo = _person(Looks.SULO, SULO_STAND.x, SULO_STAND.y)
	me = _person(Looks.player(), ME_AT.x, ME_AT.y)
	pekka = _person(Looks.PEKKA, 5.5, -5.0)
	arto = _person(Looks.ARTO, 6.2, -4.2)
	pekka.visible = false
	arto.visible = false


func _build_stone() -> void:
	_props.append(build_stone(world, _L(STONE.x, STONE.y)))


## Pysyvä muisto (main.gd _pannu_update): kivi ja kirkkaaksi hangattu isän pannu pontikkapannun vieressä samassa
## paikassa kuin kohtauksessa.
static func build_keepsake(parent: Node3D) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	var c := M.w2(M.PONTIKKA)
	var basis := Basis(Vector3.UP, YAW)
	var p := Vector3(c.x, 0.0, c.y) + basis * Vector3(STONE.x, 0.0, STONE.y)
	p.y = T.h(p.x, p.z)
	var st := build_stone(g, p)
	var pn := build_pan(g, false)
	pn.global_position = p + Vector3(0, STONE_H, 0)
	pn.global_rotation = Vector3(0, YAW + 0.54, 0)
	st.name = "Kivi"
	pn.name = "IsanPannu"
	return g


## Laakea harmaa kivi: litistetty pallo, sammaltäplä ja tumma pohja.
static func build_stone(parent: Node3D, at: Vector3) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	g.global_position = at
	var st := B.mesh(g, B.sphere(0.34, 14), Vector3(0, STONE_H * 0.4, 0), Color(0.5, 0.49, 0.46))
	st.scale = Vector3(1.0, 0.42, 0.85)
	var top := B.mesh(g, B.cyl(0.26, 0.28, 0.02, 14), Vector3(0, STONE_H - 0.01, 0), Color(0.56, 0.55, 0.52))
	top.scale = Vector3(1.0, 1.0, 0.82)
	var moss := B.mesh(g, B.sphere(0.1, 8), Vector3(-0.2, STONE_H * 0.5, 0.08), Color(0.3, 0.42, 0.18))
	moss.scale = Vector3(1.0, 0.35, 0.8)
	return g


## Vanhan Sulon kuparipannu: pyöreä vasaroitu runko niittisaumoineen, kupera kansi, hattu ja joutsenkaula, kaksi
## kantokahvaa. Rämeen patina: vihreä pinta, kuparinruskeita läikkiä ja kolhuja. Leima "V.S. 1952" paikallisessa +x
## kyljessä; with_patina = vihreä kerros leiman päällä (kohtaus hankaa sen pois). Käytetään myös main.gd:n pysyvässä
## pannussa (with_patina = false, leima kirkas).
static func build_pan(parent: Node3D, with_patina: bool) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	var pat := PATINA
	var cop := COPPER.darkened(0.25)
	var body_r := 0.24
	B.mesh(g, B.cyl(body_r, body_r * 0.94, 0.3, 24), Vector3(0, 0.15, 0), pat)
	B.mesh(g, B.cyl(body_r * 0.94, body_r * 0.8, 0.03, 24), Vector3(0, 0.0, 0), pat.darkened(0.25))  # pohjan pyöristys
	var dome := B.mesh(g, B.sphere(body_r, 24), Vector3(0, 0.3, 0), pat.lightened(0.05))
	dome.scale = Vector3(1.0, 0.42, 1.0)
	B.mesh(g, B.cyl(body_r + 0.006, body_r + 0.006, 0.018, 24), Vector3(0, 0.3, 0), pat.darkened(0.18))  # kannen huuli
	B.mesh(g, B.cyl(0.075, 0.09, 0.07, 14), Vector3(0, 0.42, 0), pat)  # kaula
	var hat := B.mesh(g, B.sphere(0.1, 14), Vector3(0, 0.5, 0), pat.lightened(0.04))  # hattu
	hat.scale = Vector3(1.0, 0.75, 1.0)
	# Joutsenkaula: kaartuva putki hatusta alas sivulle (-x), pää painunut.
	var pts := [Vector3(-0.07, 0.53, 0), Vector3(-0.17, 0.56, 0), Vector3(-0.27, 0.52, 0), Vector3(-0.34, 0.44, 0),
		Vector3(-0.38, 0.36, 0)]
	for i in pts.size() - 1:
		B.tube(g, pts[i], pts[i + 1], 0.022 - i * 0.002, pat.darkened(0.05 * i))
	B.mesh(g, B.cyl(0.02, 0.02, 0.02, 8), Vector3(-0.38, 0.35, 0), cop)  # avoin pää (kupari)
	# Niittisauma pystyyn runkoon ja vaakaan kannen alle.
	for k in 9:
		var y := 0.03 + k * 0.032
		B.mesh(g, B.sphere(0.006, 6), Vector3(0, y, body_r + 0.002), pat.darkened(0.3))
	for k in 20:
		var a := TAU * k / 20.0
		B.mesh(g, B.sphere(0.006, 6), Vector3(cos(a) * (body_r + 0.002), 0.285, sin(a) * (body_r + 0.002)), pat.darkened(0.3))
	# Kantokahvat (taivutettu tanko) sivuilla z.
	for s in [-1.0, 1.0]:
		var zz: float = s * (body_r + 0.005)
		B.tube(g, Vector3(-0.06, 0.24, zz), Vector3(-0.05, 0.25, zz + s * 0.06), 0.01, pat.darkened(0.2))
		B.tube(g, Vector3(-0.05, 0.25, zz + s * 0.06), Vector3(0.05, 0.25, zz + s * 0.06), 0.01, pat.darkened(0.2))
		B.tube(g, Vector3(0.05, 0.25, zz + s * 0.06), Vector3(0.06, 0.24, zz), 0.01, pat.darkened(0.2))
	# Kuparinruskeat läikät ja tummat kolhut (vasaran jäljet) kyljissä.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1952
	for k in 16:
		var a := rng.randf_range(0.4, TAU - 0.4)  # ei leiman päälle (+x = kulma 0)
		var y := rng.randf_range(0.05, 0.27)
		var rr := rng.randf_range(0.018, 0.04)
		var d := B.mesh(g, B.cyl(rr, rr, 0.003, 10), Vector3(cos(a) * (body_r + 0.0005), y, sin(a) * (body_r + 0.0005)),
			cop if k % 3 == 0 else pat.darkened(rng.randf_range(0.1, 0.2)))
		d.rotation = Vector3(0, -a, PI / 2.0)  # levy kyljen tangenttitasoon (akseli = rungon normaali)
		d.scale = Vector3(1.0, 1.0, rng.randf_range(0.6, 1.3))
	# Leima: kirkas kuparilevy kyljessä ja lyöty teksti; päällä vihreä patina, joka haihtuu.
	var st := Node3D.new()
	st.name = "Leima"
	g.add_child(st)
	st.position = Vector3(body_r + 0.001, 0.16, 0)
	st.rotation.y = PI / 2.0  # +z ulos rungosta (paikallinen +x)
	var plate := B.mesh(st, B.cyl(0.075, 0.075, 0.006, 20), Vector3(0, 0, 0.0), COPPER.lightened(0.08), Vector3(90, 0, 0))
	plate.scale = Vector3(1.25, 1.0, 0.8)
	var ring := B.mesh(st, B.cyl(0.058, 0.058, 0.007, 20), Vector3(0, 0, 0.0012), COPPER.darkened(0.35), Vector3(90, 0, 0))
	ring.scale = Vector3(1.25, 1.0, 0.8)
	var inner := B.mesh(st, B.cyl(0.053, 0.053, 0.0075, 20), Vector3(0, 0, 0.0016), COPPER.lightened(0.12), Vector3(90, 0, 0))
	inner.scale = Vector3(1.25, 1.0, 0.8)
	var t1 := B.label(st, "V.S.", Vector3(0, 0.014, 0.0058), 30, COPPER.darkened(0.6))
	t1.pixel_size = 0.0011
	t1.outline_size = 0
	t1.shaded = true
	var t2 := B.label(st, "1952", Vector3(0, -0.018, 0.0058), 22, COPPER.darkened(0.6))
	t2.pixel_size = 0.0011
	t2.outline_size = 0
	t2.shaded = true
	for t in [t1, t2]:
		(t as Label3D).alpha_cut = Label3D.ALPHA_CUT_DISCARD  # syvyys kirjoitetaan: patina peittää tekstin
	if with_patina:
		var pm := StandardMaterial3D.new()
		pm.albedo_color = PATINA
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.roughness = 0.9
		pm.render_priority = 5
		var cover := MeshInstance3D.new()
		cover.name = "Patina"
		var cm := B.cyl(0.085, 0.085, 0.004, 20)
		cover.mesh = cm
		cover.material_override = pm
		cover.position = Vector3(0, 0, 0.007)
		cover.rotation_degrees = Vector3(90, 0, 0)
		cover.scale = Vector3(1.25, 1.0, 0.8)
		st.add_child(cover)
		# Kiillon varjostin: metallinen kupari leiman alla.
	for mi in [plate, inner]:
		var mm := B.mat(COPPER.lightened(0.1))
		mm.metallic = 0.85
		mm.roughness = 0.28
		(mi as MeshInstance3D).material_override = mm
	return g


func _patina() -> StandardMaterial3D:
	if _patina_mat == null:
		var c := pan.get_node_or_null("Leima/Patina") as MeshInstance3D
		if c != null:
			_patina_mat = c.material_override as StandardMaterial3D
	return _patina_mat


## Puinen kuksa: pyöreä kuppi, reunan kahva reikineen, puun syyt tummina renkaina, sisällä kirkas tisle.
func _build_kuksa() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var wood := Color(0.62, 0.42, 0.24)
	B.mesh(g, B.cyl(0.048, 0.036, 0.05, 16), Vector3(0, 0.025, 0), wood)
	B.mesh(g, B.cyl(0.05, 0.05, 0.006, 16), Vector3(0, 0.05, 0), wood.lightened(0.12))
	B.mesh(g, B.cyl(0.042, 0.042, 0.004, 16), Vector3(0, 0.049, 0), Color(0.75, 0.82, 0.86))  # tisle
	for k in 2:
		B.mesh(g, B.cyl(0.0485 - k * 0.004, 0.0485 - k * 0.004, 0.003, 16), Vector3(0, 0.018 + k * 0.016, 0), wood.darkened(0.25))
	B.mesh(g, B.boxm(Vector3(0.045, 0.02, 0.026)), Vector3(0.065, 0.04, 0), wood.darkened(0.08))
	B.mesh(g, B.cyl(0.007, 0.007, 0.028, 8), Vector3(0.072, 0.04, 0), wood.darkened(0.5), Vector3(90, 0, 0))
	return g


func _flame_tex() -> Texture2D:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 32:
			var u := (x - 15.5) / 15.5
			var v := y / 47.0  # 0 ylhäällä
			var w := lerpf(0.15, 1.0, v) * (1.0 - pow(v, 6.0))
			var a := clampf(1.0 - absf(u) / maxf(w, 0.01), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


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
	for c in [me, sulo, pekka, arto]:
		c.clear_ik()
		_lean(c, 0.0)
	match p:
		"pannu":
			_story = "Pannu-Sulon pannu metsässä. Pilkkarinnevan kupari kivelle tulen viereen."
		"leima":
			_story = ""
			sulo.play("Crouch_Idle", 0.3)
			sulo.global_position = kneel_point()
			_stand(me, ME_AT.x, ME_AT.y)
		"myonto":
			_story = ""
			_set_rub(1.0)
			sulo.play("Idle", 0.3)
			_stand(sulo, SULO_STAND.x, SULO_STAND.y)
		"tipat":
			_story = ""
			_set_rub(1.0)
			kuksa.global_position = _kuksa_rest
			kuksa.global_rotation = Vector3.ZERO
			sulo.play("Idle", 0.2)
			_stand(sulo, SULO_BARREL.x, SULO_BARREL.y)
			_stand(me, ME_FIRE.x, ME_FIRE.y)
			pekka.visible = true
			arto.visible = true
			_stand(pekka, 5.5, -5.0)
			_stand(arto, 6.2, -4.2)
		"otsikko":
			_story = ""
			_set_rub(1.0)
			flared = true
			pekka.visible = true
			arto.visible = true
			for c in [pekka, arto, sulo, me]:
				c.play("Idle", 0.2)
			_stand(sulo, SULO_STAND.x - 0.1, SULO_STAND.y - 0.15)
			_stand(me, ME_AT.x + 0.1, ME_AT.y + 0.15)
			_stand(pekka, PEKKA_AT.x, PEKKA_AT.y)
			_stand(arto, ARTO_AT.x, ARTO_AT.y)
			_splash.emitting = false
			_flare.emitting = false
			_flare_light.light_energy = 0.0
			Sfx.play("win", -6.0, 0.9)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa keskustelun valinnasta (E tai napsautus): sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "pannu" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"pannu":
			_step_pannu(delta)
		"leima":
			_step_leima(delta)
		"myonto":
			_step_myonto(delta)
		"tipat":
			_step_tipat(delta)
		"otsikko":
			_step_otsikko(delta)
	_straighten_index()
	_ui.queue_redraw()
	if phase != "" and _t >= DUR[phase]:
		var i := ORDER.find(phase)
		if i == ORDER.size() - 1:
			_finish()
		else:
			_begin(ORDER[i + 1])


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


func _step_pannu(_delta: float) -> void:
	# Pelaaja on juuri laskenut pannun kivelle ja suoristuu; Sulo kääntyy tulelta pannuun ja jähmettyy.
	var top := pan.global_position + Vector3(0, 0.3, 0)
	var up := clampf((_t - 0.2) / 0.9, 0.0, 1.0)
	_lean(me, 0.55 * (1.0 - up))
	_reach(me, top + Vector3(0, 0.05, 0), 1.0 - up, 0.0)
	_face(me, top)
	if _t < 1.4:
		_face(sulo, _G.to_global(FIRE))
	else:
		var k := clampf((_t - 1.4) / 0.5, 0.0, 1.0)
		var a := _G.to_global(FIRE).lerp(top, k)
		_face(sulo, a)
	if _t > 2.2:
		_bub[sulo] = "...Mistä sää tämän sait?"
	if _t > 3.8:
		_bub[me] = "Pilkkarinnevalta. Aaro näki sen yön."
	# Aukealta vinosti: kivi ja pannu etualalla, Sulo ja pontikkapannu takana, pelaaja vasemmalla.
	var look := _L(0.5, -1.2, 0.8)
	var eye := _L(1.7, -5.7, 2.3)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.6))


func _step_leima(_delta: float) -> void:
	# Sulo kyykistyy pannun viereen ja hankaa hihallaan vihreää kylkeä (1,0-4,4 s): leima kirkastuu.
	_face(me, pan.global_position)
	var sp := stamp_point()
	var n := stamp_normal()
	_face(sulo, pan.global_position)
	if _t < 1.0:
		_story = "Kuusikymmentä vuotta rämeessä. Vihreä kuin kuusenhavu."
	elif _t < 4.4:
		_story = ""
		var k := (_t - 1.0) / 3.4
		var rub := Vector3(0, sin(_t * 11.0) * 0.03, 0) + pan.global_basis.z * cos(_t * 11.0) * 0.04
		_reach(sulo, sp + n * 0.035 + rub, clampf((_t - 1.0) / 0.4, 0.0, 1.0), 0.2)
		_set_rub(clampf(k * 1.15, 0.0, 1.0))
		if fmod(_t, 0.55) < delta_safe() and not _once.has("h%d" % int(_t / 0.55)):
			_once["h%d" % int(_t / 0.55)] = true
			Sfx.play("cloth", -8.0, 0.8 + randf() * 0.2)
	else:
		_set_rub(1.0)
		_reach(sulo, sp + n * 0.12 + Vector3(0, 0.06, 0), 1.0 - clampf((_t - 4.4) / 0.5, 0.0, 1.0), 0.2)
		if not _once.has("kirkas"):
			_once["kirkas"] = true
			Sfx.play("coin", -8.0, 0.7)
		_story = "Kuparin alta: isän leima."
		if _t > 4.8:
			_bub[sulo] = "V. S. Viiskytkaks. Isä löi sen ite."
	# Lähikuva leimasta pannun kyljen suunnasta: leima keskellä, Sulon käsi ja polvi reunoilla.
	var look := sp + Vector3(0, 0.02, 0) + side_dir() * 0.08
	var eye := look + n * 0.7 + Vector3(0, 0.22, 0) - side_dir() * 0.22
	var w := 0.7
	if _t > 4.6:  # leiman jälkeen väljemmin: Sulon kasvot ja leima samassa kuvassa
		look = sp.lerp(sulo.to_global(sulo.bone_position("Head")), 0.5)
		eye = look + n * 1.7 - side_dir() * 0.55 + Vector3(0, 0.25, 0)
		w = 1.5
	_cam_at(eye, look, _fov_w(eye.distance_to(look), w))


func delta_safe() -> float:
	return get_process_delta_time() * 1.01


func _step_myonto(_delta: float) -> void:
	# Sulo nousee, kääntyy Pilkkarinnevalle päin ja laskee käden rinnalle. Pitkä hiljaisuus, sitten myöntö.
	var bog := M.w(SuloPannu.SPOT)
	var sp := sulo.global_position
	var to_bog := Vector3(bog.x - sp.x, 0, bog.z - sp.z).normalized()
	var k := clampf((_t - 0.3) / 1.2, 0.0, 1.0)
	var face_from := pan.global_position
	_face(sulo, (face_from - sp).normalized().lerp(to_bog, k) + sp)
	_face(me, sp)
	if _t > 1.6:
		var sl: Vector3 = sulo.bone_position("upperarm_l")
		var heart := sulo.to_global(sulo.bone_position("spine_03") + Vector3(signf(sl.x) * 0.07, 0.04, -0.2))
		_reach_l(sulo, heart, clampf((_t - 1.6) / 0.5, 0.0, 1.0))
	if _t < 1.5:
		_story = "Sulo nousee. Hän katsoo sinne, missä Pilkkarinneva on."
	else:
		_story = ""
	if _t > 2.0 and _t < 4.4:
		_bub[sulo] = "Kuuskymmentä vuotta mää oon sanonu, ettei isä keittäny."
	elif _t >= 4.4:
		_bub[sulo] = "...Isä keitti. Ja hyvää keitti."
		if not _once.has("myonto"):
			_once["myonto"] = true
			Sfx.play("win_small", -10.0, 0.7)
	# Matalalta Sulon edestä (Pilkkarinnevan puolelta): Sulo puolilähikuvassa metsää vasten, pannu kivellä alhaalla.
	var hd := sulo.to_global(sulo.bone_position("Head"))
	var look := hd.lerp(pan.global_position + Vector3(0, 0.3, 0), 0.38)
	var eye := sp + to_bog * 3.5 + sulo.global_basis.x * 0.7 + Vector3(0, 1.2, 0)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 2.3))


func _step_tipat(_delta: float) -> void:
	# 0-0,8 kuksa tynnyrin kanneltä; 1,0-1,8 heitto tuleen ("Isälle."); 1,7-3,4 sininen leimahdus. 2,4-4,8 Pekka ja Arto
	# tulevat savun perässä; 5,0-5,8 Sulo ojentaa kuksan Pekalle; 6,0-7,0 Pekka maistaa ja yskii; myöntö.
	var fire := _G.to_global(FIRE)
	var bar_top := _G.to_global(BARREL)
	bar_top.y = _G.global_position.y + BARREL.y
	_face(me, sulo.global_position)
	if _t < 0.9:
		_face(sulo, bar_top)
		_reach(sulo, _kuksa_rest + Vector3(0, 0.03, 0), clampf(_t / 0.5, 0.0, 1.0), 0.25)
		if _t > 0.5:
			_hold_kuksa(sulo, 0.0)
	elif _t < 4.6:
		_face(sulo, fire)
		var throw_k := clampf((_t - 1.0) / 0.5, 0.0, 1.0)
		var hp_tgt := sulo.to_global(sulo.bone_position("upperarm_r")) + (fire - sulo.global_position).normalized() * 0.42 \
			+ Vector3(0, -0.12 + 0.12 * throw_k, 0)
		var down := clampf((_t - 2.4) / 0.6, 0.0, 1.0)  # heiton jälkeen käsi kuksineen rinnalle
		var chest := sulo.to_global(sulo.bone_position("spine_03")) + sulo.global_basis * Vector3(0.12, -0.15, -0.3)
		_reach(sulo, hp_tgt.lerp(chest, down), 1.0, 0.0)
		_hold_kuksa(sulo, throw_k * 1.2 * (1.0 - down))
		if _t > 1.15 and _t < 1.9:
			_splash.global_position = kuksa.global_position + Vector3(0, 0.04, 0)
			var d := (fire - _splash.global_position)
			d.y = 0.0
			_splash.direction = (d.normalized() + Vector3(0, 0.12, 0)).normalized()
			_splash.emitting = true
		else:
			_splash.emitting = false
		if _t > 1.0 and _t < 3.4:
			_bub[sulo] = "Isälle."
		elif _t >= 3.4:
			_bub.erase(sulo)
		if _t > 1.65 and _t < 3.0:
			if not _once.has("leimahdus"):
				_once["leimahdus"] = true
				flared = true
				Sfx.play("whoosh", -2.0, 0.6)
				Sfx.play("fire", -4.0, 1.3)
			_flare.emitting = true
		else:
			_flare.emitting = false
		var fl := clampf((_t - 1.65) / 0.15, 0.0, 1.0) * clampf((3.4 - _t) / 0.6, 0.0, 1.0)
		_flare_light.light_energy = 3.0 * fl
		if _t > 2.4:
			_story = "Liekki leimahtaa sinisenä. Vanha Sulo otti omansa."
		if _t > 3.6:
			_story = ""
	else:
		_story = ""
		_bub.erase(sulo)
		var give := clampf((_t - 4.8) / 0.6, 0.0, 1.0)
		var take := _t > 5.4
		var pk_hand := pekka.to_global(pekka.bone_position("upperarm_r")) + pekka.global_basis * Vector3(-0.05, -0.25, -0.35)
		var mid := sulo.global_position.lerp(pekka.global_position, 0.5) + Vector3(0, 1.05, 0)
		_face(sulo, pekka.global_position)
		if not take:
			_reach(sulo, mid, give, 0.0)
			_hold_kuksa(sulo, 0.0)
			if give > 0.6:
				_reach(pekka, mid + pekka.global_basis.x * -0.03, clampf((give - 0.6) / 0.4, 0.0, 1.0), 0.0)
		else:
			_reach(sulo, mid, 1.0 - clampf((_t - 5.4) / 0.5, 0.0, 1.0), 0.0)
			var drink := clampf((_t - 5.8) / 0.5, 0.0, 1.0) * (1.0 - clampf((_t - 6.9) / 0.4, 0.0, 1.0))
			var mouth := pekka.to_global(pekka.bone_position("Head")) + pekka.global_basis * Vector3(0.0, -0.1, -0.13)
			_reach(pekka, mid.lerp(mouth, drink) if _t < 6.9 else mid.lerp(pk_hand, clampf((_t - 6.9) / 0.4, 0.0, 1.0)), 1.0, 0.0)
			_hold_kuksa(pekka, -0.9 * drink)
			if drink > 0.9:
				tasted = true
				if not _once.has("ryyppy"):
					_once["ryyppy"] = true
					Sfx.play("glass", -8.0, 0.8)
			if _t > 6.6 and not _once.has("yska"):
				_once["yska"] = true
				Sfx.play("grunt", -2.0, 1.15)
	# Pekka ja Arto tulevat aukealle (2,4-4,8 s).
	var paths := {pekka: [Vector2(5.5, -5.0), PEKKA_AT, 2.4, 2.3], arto: [Vector2(6.2, -4.2), ARTO_AT, 2.7, 2.2]}
	for c: Node3D in paths:
		var pth: Array = paths[c]
		var k := clampf((_t - float(pth[2])) / float(pth[3]), 0.0, 1.0)
		var e := k * (2.0 - k)
		var p: Vector2 = (pth[0] as Vector2).lerp(pth[1], e)
		_stand(c, p.x, p.y)
		c.play("Walk" if k > 0.0 and k < 1.0 else "Idle", 0.2)
		if k < 1.0:
			_face(c, _L(pth[1].x - 0.5, pth[1].y))
		else:
			_face(c, sulo.global_position if c == pekka else pan.global_position)
	if _t > 3.4 and _t < 5.2:
		_bub[arto] = "Täältähän se savu... Onko toi Vanhan Sulon pannu?"
	elif _t >= 5.2:
		_bub.erase(arto)
	if _t > 4.9 and _t < 5.8:
		_bub[sulo] = "Maista. Isän pannu."
	if _t > 7.0:
		_bub[pekka] = "...Perkele. Kaljapuhetta, mää sanoin. Taas väärin."
	if _t > 8.4:
		_story = "Pekka myöntää. Ensimmäistä kertaa."
	# Kamera: heitto ja leimahdus aukealta tulen ja Sulon sivulta; Pekan tulosta lähtien väljempi kuva kaikista neljästä.
	var look: Vector3
	var eye: Vector3
	var w: float
	if _t < 3.6:
		# Sivulta kohtisuoraan Sulon ja tulen väliseen linjaan (aukean puolelta): heitto ja leimahdus profiilissa.
		var sb := _G.to_local(_L(SULO_BARREL.x, SULO_BARREL.y))
		var mid := Vector2(sb.x, sb.z) / 2.0
		var line := Vector2(sb.x, sb.z).normalized()
		var perp := Vector2(line.y, -line.x)
		if perp.y > 0.0:
			perp = -perp
		var e2 := mid + perp * 3.3
		look = _L(mid.x, mid.y, 1.0)
		eye = _L(e2.x, e2.y, 1.45)
		w = 3.3
	elif _t < 4.7:
		var c2 := (sulo.global_position + pekka.global_position + arto.global_position + me.global_position) / 4.0
		look = c2 + Vector3(0, 1.0, 0)
		eye = c2 + _G.global_basis * Vector3(-0.6, 0.0, -5.4) + Vector3(0, 1.9, 0)
		w = 5.0
	else:
		# Ojennus ja maistiaiset Sulon olan yli: Pekan kasvot ja kuksa, Arto taustalla.
		var sp := sulo.global_position
		var pp := pekka.global_position
		var back := Vector3(sp.x - pp.x, 0, sp.z - pp.z).normalized()
		var side := back.cross(Vector3.UP)
		if side.dot(_G.global_basis.x) < 0.0:  # sivu tynnyrin puolelle (+x), pois pontikkapannun päältä
			side = -side
		look = pp.lerp(sp, 0.3) + Vector3(0, 1.35, 0)
		eye = sp + back * 1.5 + side * 0.65 + Vector3(0, 1.7, 0)
		w = 2.4
	_cam_at(eye, look, _fov_w(eye.distance_to(look), w))


func _step_otsikko(_delta: float) -> void:
	# Kaikki pannun ympärillä; Sulo laskee käden pannun kannelle.
	var top := pan.global_position + Vector3(0, 0.36, 0)
	_face(sulo, top)
	_face(me, top)
	_face(pekka, top)
	_face(arto, top)
	_reach(sulo, top + Vector3(0, 0.03, 0), clampf((_t - 0.3) / 0.6, 0.0, 1.0), 0.35)
	_hold_kuksa(pekka, 0.0)  # kuksa jää Pekan käteen
	var look := _L(0.95, -1.4, 0.85)
	var eye := _L(1.0, -4.9, 2.0)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.9))


# --- Esineet ja hahmot --------------------------------------------------------------

## Sulon polvistumispaikka leiman vieressä: kiven keskeltä leiman suuntaan ja sivulle (pannun +z, tulen puoli), jotta
## käsi yltää leimaan ja kamera näkee leiman suoraan edestä Sulon ohi.
func kneel_point() -> Vector3:
	var n := stamp_normal()
	n.y = 0.0
	var t := pan.global_basis.z
	t.y = 0.0
	var p := pan.global_position + n.normalized() * 0.24 + t.normalized() * 0.46
	return Vector3(p.x, T.h(p.x, p.z), p.z)


func side_dir() -> Vector3:
	var t := pan.global_basis.z
	t.y = 0.0
	return t.normalized()


## Leiman keskusta ja ulkonormaali maailmassa.
func stamp_point() -> Vector3:
	return pan.to_global(Vector3(0.241, 0.16, 0))


func stamp_normal() -> Vector3:
	return pan.global_basis.x.normalized()


func _set_rub(k: float) -> void:
	rubbed = k
	var m := _patina()
	if m != null:
		m.albedo_color.a = 1.0 - k


## Kuksa oikeassa kädessä (tilt: kallistus kohti etusuuntaa, rad).
func _hold_kuksa(c: Node3D, tilt: float) -> void:
	var hp := _hand(c)
	kuksa.global_position = hp + Vector3(0, 0.02, 0)
	kuksa.global_rotation = Vector3(0, c.global_rotation.y + PI / 2.0, 0)
	kuksa.rotate_object_local(Vector3(0, 0, 1), -tilt)


func _lean(c: Node3D, a: float) -> void:
	c.set_override("spine_01", Vector3.RIGHT, -a * 0.45)
	c.set_override("spine_02", Vector3.RIGHT, -a * 0.35)
	c.set_override("spine_03", Vector3.RIGHT, -a * 0.2)
	c.set_override("neck_01", Vector3.RIGHT, a * 0.35)


func _stand(c: Node3D, x: float, z: float) -> void:
	c.global_position = _L(x, z)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.global_position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


func _hand(c: Node3D) -> Vector3:
	return c.to_global((c.bone_position("hand_r") + c.bone_position("index_01_r")) / 2.0)


func _reach(c: Node3D, at_global: Vector3, w: float, lean := 0.0) -> void:
	_lean(c, lean * w)
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at_global), w)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", tgt, sh + Vector3(s * 0.45, -0.25, 0.25))


func _reach_l(c: Node3D, at_global: Vector3, w: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm_l")
	var s := signf(sh.x) if sh.x != 0.0 else -1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at_global), w)
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", tgt, sh + Vector3(s * 0.7, -0.35, -0.2))  # kyynärpää ulos, ei vatsaan


# --- Kehys, kamera ------------------------------------------------------------------

## Aukean piste (x, z) maanpinnalla + y.
func _L(x: float, z: float, y := 0.0) -> Vector3:
	var p := _G.to_global(Vector3(x, 0.0, z))
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
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.06, 0.04, 0.02, 0.25 * a))
		var y := vs.y * 0.17
		_draw_pan_icon(Vector2(vs.x / 2.0, y - 78.0), a)
		var title := "VANHAN SULON PANNU"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.16, 0.09, 0.03, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(1.0, 0.7, 0.4, a))
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 158.0, 840, 84)
		_ui.draw_rect(sr, Color(0.06, 0.04, 0.02, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Kuparipannu nousi Pilkkarinnevalta",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.95, 0.8, 0.5, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "ja Sulo myönsi: isä keitti.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Kuparipannu otsikon yllä: pyöreä runko, kupu, hattu ja joutsenkaula, tumma ääriviiva ja kiilto.
func _draw_pan_icon(c: Vector2, a: float) -> void:
	var dark := Color(0.2, 0.1, 0.04, a)
	var cop := Color(0.9, 0.52, 0.26, a)
	var hi := Color(1.0, 0.82, 0.6, a)
	# Joutsenkaula.
	var neck := PackedVector2Array([c + Vector2(-6, -30), c + Vector2(-22, -36), c + Vector2(-36, -30), c + Vector2(-44, -16)])
	_ui.draw_polyline(neck, dark, 9.0)
	_ui.draw_polyline(neck, cop, 5.0)
	# Runko ja kupu.
	_ui.draw_circle(c + Vector2(0, 6), 27.0, dark)
	_ui.draw_rect(Rect2(c + Vector2(-27, -4), Vector2(54, 30)), dark)
	_ui.draw_circle(c + Vector2(0, 6), 24.0, cop)
	_ui.draw_rect(Rect2(c + Vector2(-24, -2), Vector2(48, 26)), cop)
	_ui.draw_circle(c + Vector2(0, -28), 11.0, dark)
	_ui.draw_circle(c + Vector2(0, -28), 8.0, cop)
	_ui.draw_rect(Rect2(c + Vector2(-5, -22), Vector2(10, 14)), cop)
	_ui.draw_arc(c + Vector2(0, 6), 18.0, PI * 1.1, PI * 1.45, 10, hi, 3.0)
	_ui.draw_line(c + Vector2(-16, 4), c + Vector2(-16, 18), hi, 3.0)
