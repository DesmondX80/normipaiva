extends CanvasLayer
## Legendaarinen hetki "kuninkaan_tapuli" (Kuninkaan tapuli): kun Kustaa III:n piirustus näytetään ensimmäistä kertaa
## Pirtin oppaalle (main.gd _kuningas_pirtti), Raahen museon intendentti tulee vahvistamaan sen kellotapulin juurelle.
## Vaiheet:
##   sinetti    taittopöytä tapulin edessä, lyijykotelo auki. Intendentti nostaa rullan ja suurentaa riippusinettiä:
##              punainen vaha, kruunu ja G. R. "Gustavus Rex. Sinetti on aito."
##   piirustus  intendentti ja opas kävelevät pihalle ja avaavat rullan välilleen: kuninkaan oma tussipiirros tapulista.
##   torni      he nostavat piirustuksen tapulia vasten. Kamera heidän takanaan: paperi haalistuu ja kuninkaan viivat osuvat
##              oikean tapulin reunoihin viiva viivalta. Kello heilahtaa ja lyö itsestään, kaikki katsovat ylös.
##              Suntio: "...Kuninkaan tuuli."
##   kierros    Pekka ja Arto tulevat kaljakori sylissä. Arto myöntää, Pekka jakaa tölkit (suntiokin ottaa) ja nostaa
##              tapulille: "Gustavukselle!"
##   otsikko    KUNINKAAN TAPULI, kruunu
## Kehys: tapulin solmu (world.tapuli_root): paikallinen -Z = ovesta pihalle, ovi z = -2,6, tapulin keskus origossa.
## Pihalta katsoen paikallinen +x näkyy oikealla. Hahmojen etu -Z (Looks). Maan korkeus Terrain.h:sta.
## Piirustuksen viivat lasketaan projisoimalla tapulin julkisivun ääriviivat kameran pisteestä paperin tasoon, joten
## nostettu piirustus osuu tapuliin täsmälleen (ei arvattuja koordinaatteja).
## Oikea pelaaja ja suntio (sekä Pekka ja Arto) piiloon kohtauksen ajaksi. Suntio muistelee (main.gd "kuningas_muisto").

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const T := preload("res://scripts/terrain.gd")
const Aarni := preload("res://scripts/aarnivalkea_legenda.gd")

const DUR := {"sinetti": 7.0, "piirustus": 7.0, "torni": 8.0, "kierros": 8.0, "otsikko": 6.4}
const ORDER := ["sinetti", "piirustus", "torni", "kierros", "otsikko"]
const EYE := Vector3(0.0, -15.0, 1.5)  # piirustuskuvan kamera (x, z, korkeus maasta): tapulin edessä pihalla
const PW := 0.52  # piirustuksen leveys (m)
const PH := 0.72  # korkeus
const TABLE := Vector2(2.3, -13.0)  # taittopöytä pihalla, pitkä sivu x-suuntaan
const TABLE_H := 0.74
const INT_AT := Vector2(2.3, -12.55)  # intendentti pöydän takana tapulin puolella, kasvot pihalle
const OPAS_AT := Vector2(3.25, -12.7)
const SUNTIO_AT := Vector2(1.2, -12.75)
const ME_AT := Vector2(0.55, -13.45)
const PEKKA_AT := Vector2(-1.9, -15.6)
const ARTO_AT := Vector2(-2.8, -15.0)
const SUNTIO_LATER := Vector2(-0.95, -14.25)  # nostosta eteenpäin pitäjien oikealla takana
const ME_LATER := Vector2(1.5, -14.9)
## Raahen museon intendentti: tummansininen jakku, harmaa nuttura, pyöreät lasit.
const INTENDENTTI := {"model": "female", "shirt": Color(0.14, 0.18, 0.32), "pants": Color(0.16, 0.17, 0.22), "shoes": Color(0.1, 0.08, 0.07),
	"shoe": "kavelykenka", "hair": "Hair_Buns", "hair_color": Color(0.72, 0.7, 0.68), "height": 1.68, "skin": Color(0.95, 0.8, 0.72),
	"round_glasses": true}
## Suntio muistelee myöhemmin (main.gd _talk_kuningas "kuningas_muisto").
const MUISTO := ["Kello löi itsestään sinä päivänä. Minä olen soittanut sitä neljäkymmentä vuotta, enkä ole kuullut sen lyövän noin.",
	"Kuninkaan viivat osui joka nurkkaan. Rakennusmestarin työ, minä sanoin. No. Kuninkaan.",
	"Join kaljaa kirkon mäellä. Kerran kahdessasadassa vuodessa, sanoin Pekalle. Se sanoi, että ensi kerralla tarjoaa taas.",
	"Intendentti soitti eilen. Piirustus on lasin alla Raahessa, ja siinä lukee meidän tapulin nimi."]

var world: Node3D
var hide_nodes: Array = []
var suntio_look: Dictionary = {}
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
var intendentti: Node3D
var opas: Node3D
var suntio: Node3D
var pekka: Node3D
var arto: Node3D
var case_box: Node3D  # lyijykotelo
var case_lid: Node3D
var scroll: Node3D  # piirustus: paperi ja rullat (paikallinen +Z = piirustuksen puoli, +X oikealle)
var roll_l: Node3D
var roll_r: Node3D
var paper_bg: MeshInstance3D
var paper_ink: MeshInstance3D
var seal: Node3D
var lens: Node3D
var kori: Node3D  # Pekan kaljakori
var cans: Array[Node3D] = []
var _bell_t := -1.0
var _bell0 := 0.0
var _eye := Vector3.ZERO  # piirustuskuvan kamera (maailma)
var _paper_at := Vector3.ZERO  # nostetun piirustuksen keskusta
var _paper_basis := Basis()
var _paper_w := 0.0  # rullan avautuma 0..1
var _paper_alpha := 1.0
var _pointing := {}
var ink_hits := 0  # testi lukee: tapulin ääriviivojen projisoituja pisteitä paperin sisällä
var bell_swung := false


func _ready() -> void:
	layer = 6
	process_priority = 100
	_G = Node3D.new()
	world.add_child(_G)
	_props.append(_G)
	var tr: Node3D = world.tapuli_root
	_G.global_position = Vector3(tr.global_position.x, 0.0, tr.global_position.z)
	_G.global_rotation = Vector3(0, tr.global_rotation.y, 0)
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
	if world.tapuli_bell != null:
		_bell0 = (world.tapuli_bell as Node3D).rotation.z
	_build()
	_begin("sinetti")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	_build_table()
	case_box = _build_case()
	case_box.global_position = _L(TABLE.x - 0.05, TABLE.y, TABLE_H + 0.012)
	case_box.global_rotation = Vector3(0, _G.global_rotation.y, 0)
	_plan_paper()
	scroll = _build_scroll()
	lens = _build_lens()
	lens.visible = false
	kori = _build_kori()
	kori.visible = false
	intendentti = _person(INTENDENTTI, INT_AT.x, INT_AT.y)
	opas = _person(Aarni.OPAS, OPAS_AT.x, OPAS_AT.y)
	suntio = _person(suntio_look, SUNTIO_AT.x, SUNTIO_AT.y)
	me = _person(Looks.player(), ME_AT.x, ME_AT.y)
	pekka = _person(Looks.PEKKA, -5.5, -21.0)
	arto = _person(Looks.ARTO, -6.4, -20.4)
	pekka.visible = false
	arto.visible = false
	for c in [intendentti, opas, suntio, pekka, arto, me]:
		var can := _build_can()
		can.visible = false
		cans.append(can)
	_place_scroll_rolled()


## Taittopöytä: vaalea levy, metallijalat ristissä ja valkoinen liina.
func _build_table() -> void:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	g.global_position = _L(TABLE.x, TABLE.y)
	g.rotation.y = _G.global_rotation.y
	B.mesh(g, B.boxm(Vector3(1.2, 0.03, 0.62)), Vector3(0, TABLE_H - 0.015, 0), Color(0.8, 0.74, 0.62))
	B.mesh(g, B.boxm(Vector3(1.24, 0.004, 0.66)), Vector3(0, TABLE_H + 0.002, 0), Color(0.95, 0.94, 0.9))  # liina
	B.mesh(g, B.boxm(Vector3(1.24, 0.12, 0.004)), Vector3(0, TABLE_H - 0.058, -0.33), Color(0.93, 0.92, 0.88))  # liinan helma
	var met := _metal(Color(0.55, 0.55, 0.57), 0.4)
	for sx in [-0.5, 0.5]:
		for k in [-1.0, 1.0]:
			var leg := B.mesh(g, B.boxm(Vector3(0.025, 0.86, 0.025)), Vector3(sx, TABLE_H / 2.0, 0), Color.WHITE)
			leg.rotation.x = k * 0.6
			leg.material_override = met


## Lyijykotelo: himmeä harmaa pitkä laatikko, kansi saranoitu tapulin puoleiseen reunaan, kolhuja ja vanha tina.
func _build_case() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var lead := Color(0.42, 0.43, 0.45)
	var m := _metal(lead, 0.75)
	m.metallic = 0.6
	var w := 0.82
	var h := 0.09
	var d := 0.13
	var t := 0.006
	for part in [[Vector3(w, t, d), Vector3(0, t / 2.0, 0)], [Vector3(w, h, t), Vector3(0, h / 2.0, -d / 2.0)],
			[Vector3(w, h, t), Vector3(0, h / 2.0, d / 2.0)], [Vector3(t, h, d), Vector3(-w / 2.0, h / 2.0, 0)],
			[Vector3(t, h, d), Vector3(w / 2.0, h / 2.0, 0)]]:
		var mi := B.mesh(g, B.boxm(part[0]), part[1], Color.WHITE)
		mi.material_override = m
	B.mesh(g, B.boxm(Vector3(w - 2 * t, 0.002, d - 2 * t)), Vector3(0, t + 0.001, 0), Color(0.14, 0.12, 0.1))
	for k in 3:  # kolhut ja tummat läikät
		B.mesh(g, B.boxm(Vector3(0.06, 0.025, 0.002)), Vector3(-0.28 + k * 0.26, 0.04, -d / 2.0 - 0.002), lead.darkened(0.3))
	case_lid = Node3D.new()
	case_lid.position = Vector3(0, h, d / 2.0)  # sarana tapulin puoleisessa (+Z) reunassa
	g.add_child(case_lid)
	var lm := B.mesh(case_lid, B.boxm(Vector3(w + 0.01, 0.01, d + 0.01)), Vector3(0, 0.005, -d / 2.0), Color.WHITE)
	lm.material_override = m
	B.mesh(case_lid, B.boxm(Vector3(0.12, 0.002, 0.05)), Vector3(0.1, 0.011, -d / 2.0), lead.darkened(0.35))
	return g


## Piirustuksen paikka nostettuna: kamera EYE, katse tapulin julkisivun keskelle; paperi kohtisuoraan katseeseen sille
## etäisyydelle, jolla projisoitu tapuli täyttää 66 % paperin korkeudesta.
func _plan_paper() -> void:
	_eye = _L(EYE.x, EYE.y, EYE.z)
	var tr: Node3D = world.tapuli_root
	var c := tr.to_global(Vector3(0, 5.95, -2.6))
	var dir := (c - _eye).normalized()
	var x := dir.cross(Vector3.UP).normalized()
	var z := -dir
	_paper_basis = Basis(x, z.cross(x), z)
	# Projektio etäisyydellä 1 m: korkeus suhteessa, sitten etäisyys niin, että tapuli täyttää 66 %.
	var lo := INF
	var hi := -INF
	for p in _outline_pts():
		var q := _project(tr.to_global(p), _eye + dir, 1.0)
		lo = minf(lo, q.y)
		hi = maxf(hi, q.y)
	var d := 0.66 * PH / maxf(hi - lo, 0.01)
	_paper_at = _eye + dir * d
	# Keskitetään tapuli paperille pystysuunnassa (paperi siirtyy tasossaan, viivat lasketaan uudesta paikasta).
	var mid := (lo + hi) / 2.0 * d
	_paper_at += _paper_basis.y * mid


## Piste paperin tasolla (paikallinen x, y metreinä) säteestä silmä -> piste.
func _project(pw: Vector3, plane_at: Vector3, _scale: float) -> Vector2:
	var n := _paper_basis.z
	var v := pw - _eye
	var t := (plane_at - _eye).dot(n) / v.dot(n)
	var q := _eye + v * t - plane_at
	return Vector2(q.dot(_paper_basis.x), q.dot(_paper_basis.y))


## Tapulin näkyvät ääriviivat 3D-pisteinä (paikallinen x, y, z) world.gd _build_tapulin mitoin: julkisivun taso
## z = -2,6, sokkeli ja vyölauta ulompana, kellokerroksen etupylväät z = -2,49, katon räystäs z = -2,87, harja, risti,
## kello ja poikkipalkki keskellä (z = 0). Syvyys mukana, jotta projektio osuu myös katon harjaan ja kelloon.
func _outline_segs() -> Array:
	var s := []
	var rect := func(x0: float, x1: float, y0: float, y1: float, z: float) -> void:
		s.append([Vector3(x0, y0, z), Vector3(x1, y0, z)])
		s.append([Vector3(x1, y0, z), Vector3(x1, y1, z)])
		s.append([Vector3(x1, y1, z), Vector3(x0, y1, z)])
		s.append([Vector3(x0, y1, z), Vector3(x0, y0, z)])
	rect.call(-2.75, 2.75, 0.0, 0.5, -2.75)  # sokkeli
	rect.call(-2.6, 2.6, 0.5, 3.9, -2.6)  # runko
	rect.call(-0.55, 0.55, 0.55, 2.65, -2.64)  # ovi
	rect.call(-2.85, 2.85, 3.8, 4.1, -2.85)  # vyölauta
	for k in 5:  # pystylaudoitus
		var x := -2.6 + (k + 1) * 5.2 / 6.0
		if absf(x) > 0.6:
			s.append([Vector3(x, 0.55, -2.63), Vector3(x, 3.85, -2.63)])
	for sx in [-1.0, 1.0]:  # kellokerroksen etupylväät
		rect.call(sx * 2.11, sx * 2.49, 4.1, 7.1, -2.49)
	rect.call(-2.4, 2.4, 6.75, 7.05, 0.0)  # poikkipalkki
	s.append([Vector3(-0.2, 6.7, 0), Vector3(-0.75, 5.7, 0)])  # kello
	s.append([Vector3(0.2, 6.7, 0), Vector3(0.75, 5.7, 0)])
	s.append([Vector3(-0.75, 5.7, 0), Vector3(0.75, 5.7, 0)])
	s.append([Vector3(-0.2, 6.7, 0), Vector3(0.2, 6.7, 0)])
	s.append([Vector3(-2.87, 7.1, -2.87), Vector3(2.87, 7.1, -2.87)])  # katon räystäs ja harjat
	s.append([Vector3(-2.87, 7.1, -2.87), Vector3(0.0, 10.7, 0.0)])
	s.append([Vector3(2.87, 7.1, -2.87), Vector3(0.0, 10.7, 0.0)])
	s.append([Vector3(0.0, 10.7, 0.0), Vector3(0.0, 11.9, 0.0)])  # risti
	s.append([Vector3(-0.3, 11.55, 0.0), Vector3(0.3, 11.55, 0.0)])
	return s


func _outline_pts() -> Array:
	var out := []
	for sg in _outline_segs():
		out.append(sg[0])
		out.append(sg[1])
	return out


## Piirustus: kaksi tummaa puurullaa nuppeineen, välissä kellertävä paperi (tausta ja mustekerros erikseen, jotta
## paperi voi haalistua ja viivat jäävät) sekä riippusinetti: punainen vaha kruunuineen sini-keltaisessa nauhassa.
func _build_scroll() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var wood := Color(0.3, 0.17, 0.09)
	roll_l = Node3D.new()
	roll_r = Node3D.new()
	for r in [roll_l, roll_r]:
		g.add_child(r)
		B.mesh(r, B.cyl(0.018, 0.018, PH + 0.04, 12), Vector3.ZERO, wood)
		for sy in [-1.0, 1.0]:
			B.mesh(r, B.sphere(0.024, 10), Vector3(0, sy * (PH / 2.0 + 0.03), 0), wood.darkened(0.2))
		B.mesh(r, B.cyl(0.026, 0.026, PH, 12), Vector3.ZERO, Color(0.86, 0.78, 0.58))  # käärityn paperin kerrokset
	var bg := QuadMesh.new()
	bg.size = Vector2(1, 1)
	paper_bg = MeshInstance3D.new()
	paper_bg.mesh = bg
	var bm := StandardMaterial3D.new()
	bm.albedo_texture = ImageTexture.create_from_image(_paper_image())
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.roughness = 0.95
	paper_bg.material_override = bm
	g.add_child(paper_bg)
	paper_ink = MeshInstance3D.new()
	var im := QuadMesh.new()
	im.size = Vector2(1, 1)
	paper_ink.mesh = im
	var inkm := StandardMaterial3D.new()
	inkm.albedo_texture = ImageTexture.create_from_image(_ink_image())
	inkm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inkm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inkm.render_priority = 1
	paper_ink.material_override = inkm
	paper_ink.position = Vector3(0, 0, 0.002)
	g.add_child(paper_ink)
	# Riippusinetti paperin alareunan keskeltä.
	seal = Node3D.new()
	g.add_child(seal)
	for k in [-1.0, 1.0]:
		var rb := B.mesh(seal, B.boxm(Vector3(0.012, 0.09, 0.002)), Vector3(k * 0.008, -0.045, 0), Color(0.15, 0.3, 0.65) if k < 0 else Color(0.95, 0.78, 0.15))
		rb.rotation.z = k * 0.12
	var wax := B.mesh(seal, B.cyl(0.042, 0.042, 0.014, 22), Vector3(0, -0.12, 0), Color(0.62, 0.06, 0.05))
	wax.rotation.x = PI / 2.0
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.6, 0.07, 0.05)
	wm.roughness = 0.35
	wax.material_override = wm
	var rim := B.mesh(seal, B.cyl(0.046, 0.044, 0.008, 22), Vector3(0, -0.12, -0.002), Color(0.5, 0.05, 0.04))
	rim.rotation.x = PI / 2.0
	# Sinetin kuva (kruunu ja G R kohokuvana) omana tekstuurinaan vahan etupinnassa.
	var face := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.084, 0.084)
	face.mesh = fq
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = ImageTexture.create_from_image(_seal_image())
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	fm.roughness = 0.4
	face.material_override = fm
	face.position = Vector3(0, -0.12, 0.0078)
	seal.add_child(face)
	return g


## Sinetin kuva: punainen vaha reunarenkaineen, kruunu ja G R kohokuvana (vaalea yläreuna, tumma varjo alla).
func _seal_image() -> Image:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d < 62.0:
				var col := Color(0.62, 0.07, 0.05)
				if d > 54.0:
					col = col.darkened(0.25)
				elif d > 50.0:
					col = col.lightened(0.12)
				img.set_pixel(x, y, col)
	var hi := Color(0.85, 0.3, 0.22)
	var lo := Color(0.32, 0.03, 0.02)
	var crown := [Vector2(-24, 6), Vector2(-28, -14), Vector2(-12, -2), Vector2(0, -20), Vector2(12, -2), Vector2(28, -14), Vector2(24, 6), Vector2(-24, 6)]
	var cc := c + Vector2(0, -12)
	for pass_i in 2:
		var off := Vector2(1.5, 2) if pass_i == 0 else Vector2.ZERO
		var col2: Color = lo if pass_i == 0 else hi
		for i in crown.size() - 1:
			_line(img, cc + crown[i] + off, cc + crown[i + 1] + off, 4, col2)
		_line(img, cc + Vector2(-24, 11) + off, cc + Vector2(24, 11) + off, 4, col2)
		var gc := c + Vector2(-13, 26) + off
		for i in 10:
			var a0 := deg_to_rad(40 + i * 28)
			var a1 := deg_to_rad(40 + (i + 1) * 28)
			_line(img, gc + Vector2(cos(a0), -sin(a0)) * 9, gc + Vector2(cos(a1), -sin(a1)) * 9, 4, col2)
		_line(img, gc + Vector2(9, 3), gc + Vector2(2, 3), 4, col2)
		var rc := c + Vector2(6, 17) + off
		_line(img, rc, rc + Vector2(0, 18), 4, col2)
		_line(img, rc, rc + Vector2(8, 1), 4, col2)
		_line(img, rc + Vector2(8, 1), rc + Vector2(8, 8), 4, col2)
		_line(img, rc + Vector2(8, 8), rc + Vector2(0, 9), 4, col2)
		_line(img, rc + Vector2(2, 9), rc + Vector2(10, 18), 4, col2)
	return img


## Paperin tausta: kellertävä, reunoilta tummuva, muutama kosteusläikkä ja taitekohta.
func _paper_image() -> Image:
	var img := Image.create(128, 176, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1783
	for y in img.get_height():
		for x in img.get_width():
			var ex := minf(x, img.get_width() - 1 - x) / 14.0
			var ey := minf(y, img.get_height() - 1 - y) / 14.0
			var edge := clampf(minf(ex, ey), 0.0, 1.0)
			var c := Color(0.93, 0.85, 0.66).lerp(Color(0.72, 0.58, 0.36), (1.0 - edge) * 0.7)
			c = c.darkened(rng.randf_range(0.0, 0.04))
			img.set_pixel(x, y, c)
	for k in 5:
		var cx := rng.randi_range(10, 118)
		var cy := rng.randi_range(10, 166)
		var r := rng.randi_range(5, 12)
		for y in range(maxi(0, cy - r), mini(176, cy + r)):
			for x in range(maxi(0, cx - r), mini(128, cx + r)):
				if Vector2(x - cx, y - cy).length() < r:
					img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.06))
	for x in 128:
		img.set_pixel(x, 88, img.get_pixel(x, 88).darkened(0.1))  # taite
	return img


## Mustekerros: tapulin ääriviivat projisoituna kameran pisteestä paperin tasoon (osuvat nostettuna oikeaan tapuliin),
## kruunu ja G R tapulin yllä, mittakaava ja allekirjoituksen kiemura alareunassa. Tausta läpinäkyvä.
func _ink_image() -> Image:
	var iw := 512
	var ih := int(iw * PH / PW)
	var img := Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.24, 0.13, 0.06, 1.0)
	var tr: Node3D = world.tapuli_root
	var to_px := func(q: Vector2) -> Vector2:
		return Vector2((q.x / PW + 0.5) * iw, (0.5 - q.y / PH) * ih)
	ink_hits = 0
	for sg in _outline_segs():
		var a: Vector2 = to_px.call(_project(tr.to_global(sg[0]), _paper_at, 1.0))
		var b: Vector2 = to_px.call(_project(tr.to_global(sg[1]), _paper_at, 1.0))
		for p in [a, b]:
			if p.x > 0 and p.x < iw and p.y > 0 and p.y < ih:
				ink_hits += 1
		_line(img, a, b, 3, ink)
	# Kruunu ristin yläpuolella ja G R sen alla oikealla.
	var top: Vector2 = to_px.call(_project(tr.to_global(Vector3(0, 11.9, 0)), _paper_at, 1.0))
	var cc := Vector2(iw * 0.22, maxf(46.0, top.y - 6.0))
	var crown := [Vector2(-26, 10), Vector2(-30, -12), Vector2(-14, 0), Vector2(0, -20), Vector2(14, 0), Vector2(30, -12), Vector2(26, 10), Vector2(-26, 10)]
	for i in crown.size() - 1:
		_line(img, cc + crown[i], cc + crown[i + 1], 3, ink)
	_line(img, cc + Vector2(-26, 16), cc + Vector2(26, 16), 3, ink)
	# G
	var gc := cc + Vector2(-12, 46)
	for i in 10:
		var a0 := deg_to_rad(40 + i * 28)
		var a1 := deg_to_rad(40 + (i + 1) * 28)
		_line(img, gc + Vector2(cos(a0), -sin(a0)) * 12, gc + Vector2(cos(a1), -sin(a1)) * 12, 3, ink)
	_line(img, gc + Vector2(12, 4), gc + Vector2(3, 4), 3, ink)
	# R
	var rc := cc + Vector2(14, 34)
	_line(img, rc, rc + Vector2(0, 24), 3, ink)
	_line(img, rc, rc + Vector2(10, 2), 3, ink)
	_line(img, rc + Vector2(10, 2), rc + Vector2(10, 10), 3, ink)
	_line(img, rc + Vector2(10, 10), rc + Vector2(0, 12), 3, ink)
	_line(img, rc + Vector2(2, 12), rc + Vector2(12, 24), 3, ink)
	# Mittakaava ja allekirjoituksen kiemura.
	var sy := ih - 40.0
	_line(img, Vector2(40, sy), Vector2(200, sy), 2, ink)
	for k in 5:
		_line(img, Vector2(40 + k * 40, sy - 6), Vector2(40 + k * 40, sy + 6), 2, ink)
	var prev := Vector2(300, sy)
	for i in 30:
		var x := 300.0 + i * 6.0
		var p := Vector2(x, sy - 8.0 * sin(i * 0.9) - (10.0 if i in [3, 4, 12] else 0.0))
		_line(img, prev, p, 2, ink)
		prev = p
	return img


func _line(img: Image, a: Vector2, b: Vector2, w: int, col: Color) -> void:
	var n := int(maxf(1.0, a.distance_to(b)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var x := int(p.x) - w / 2
		var y := int(p.y) - w / 2
		if x >= 0 and y >= 0 and x + w < img.get_width() and y + w < img.get_height():
			img.fill_rect(Rect2i(x, y, w, w), col)


## Suurennuslasi: messinkikehys, lasi ja tumma kahva.
func _build_lens() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.04
	tm.outer_radius = 0.047
	var rim := MeshInstance3D.new()
	rim.mesh = tm
	rim.material_override = _metal(Color(0.8, 0.62, 0.3), 0.3)
	rim.rotation.x = PI / 2.0
	g.add_child(rim)
	var glass := B.mesh(g, B.cyl(0.041, 0.041, 0.004, 24), Vector3.ZERO, Color.WHITE)
	glass.rotation.x = PI / 2.0
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.85, 0.92, 1.0, 0.22)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.metallic = 0.3
	gm.roughness = 0.05
	glass.material_override = gm
	B.mesh(g, B.boxm(Vector3(0.016, 0.11, 0.016)), Vector3(0, -0.1, 0), Color(0.18, 0.1, 0.06))
	return g


## Kaljakori: muovinen tummanvihreä kori, tölkkien kannet näkyvät, kyljessä kädensijan aukko.
func _build_kori() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	var green := Color(0.12, 0.32, 0.16)
	B.mesh(g, B.boxm(Vector3(0.4, 0.2, 0.27)), Vector3(0, 0.1, 0), green)
	for sx in [-1.0, 1.0]:
		B.mesh(g, B.boxm(Vector3(0.004, 0.035, 0.1)), Vector3(sx * 0.201, 0.16, 0), Color(0.03, 0.06, 0.04))
	var lid := _metal(Color(0.78, 0.78, 0.8), 0.3)
	for ix in 4:
		for iz in 3:
			var c := B.mesh(g, B.cyl(0.032, 0.032, 0.01, 12), Vector3(-0.15 + ix * 0.1, 0.205, -0.08 + iz * 0.08), Color.WHITE)
			c.material_override = lid
	return g


## Kaljatölkki: sininen kylki, valkoinen raita ja hopeinen kansi.
func _build_can() -> Node3D:
	var g := Node3D.new()
	world.add_child(g)
	_props.append(g)
	B.mesh(g, B.cyl(0.033, 0.033, 0.115, 14), Vector3(0, 0.0575, 0), Color(0.12, 0.3, 0.7))
	B.mesh(g, B.cyl(0.0335, 0.0335, 0.025, 14), Vector3(0, 0.06, 0), Color(0.95, 0.95, 0.92))
	var top := B.mesh(g, B.cyl(0.03, 0.033, 0.008, 14), Vector3(0, 0.119, 0), Color.WHITE)
	top.material_override = _metal(Color(0.8, 0.8, 0.82), 0.3)
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


# --- Piirustuksen paikka ------------------------------------------------------------

## Avautuma 0..1: rullat erkanevat paperin leveydelle, paperi ja muste skaalautuvat (UV pysyy: muste avautuu mukana).
func _set_open(k: float) -> void:
	_paper_w = k
	var w := lerpf(0.04, PW, k)
	roll_l.position = Vector3(-w / 2.0 - 0.02, 0, 0)
	roll_r.position = Vector3(w / 2.0 + 0.02, 0, 0)
	for mi in [paper_bg, paper_ink]:
		mi.scale = Vector3(maxf(w, 0.001), PH, 1.0)
		mi.visible = k > 0.02
	seal.position = Vector3(0, -PH / 2.0, 0.004)


func _set_alpha(a: float) -> void:
	_paper_alpha = a
	(paper_bg.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, a)


## Rulla kiinni intendentin oikeassa kädessä (pystyssä, sinetti roikkuu).
func _place_scroll_rolled() -> void:
	_set_open(0.0)
	_set_alpha(1.0)


## Paperin keskusta ja suunta: nostettuna (raise 1) kameran mukaan laskettu paikka, matalalla (raise 0) rinnan korkeudella
## samassa kohdassa vaakasuunnassa, kallistettu katsojaa kohti.
func _paper_pose(raise: float) -> Transform3D:
	var low := _paper_at
	low.y = T.h(low.x, low.z) + 1.18
	var low_b := Basis(_paper_basis.x, Vector3.UP, _paper_basis.x.cross(Vector3.UP)).rotated(_paper_basis.x, -0.45)
	var pos := low.lerp(_paper_at, raise)
	var b := low_b.slerp(_paper_basis, raise).orthonormalized()
	return Transform3D(b, pos)


## Pitäjien paikat paperin vieressä (vasen: intendentti, oikea: opas), kasvot tapulille.
func _holder_spot(left: bool) -> Vector3:
	var side := -1.0 if left else 1.0
	var p := _paper_at + _paper_basis.x * side * (PW / 2.0 + 0.3)
	var fwd := -_paper_basis.z
	fwd.y = 0.0
	p += fwd.normalized() * 0.22
	return Vector3(p.x, T.h(p.x, p.z), p.z)


## Kädet rullille: vasen pitäjä tarttuu vasempaan rullaan molemmin käsin (ylempi ja alempi ote), oikea oikeaan.
func _hold_rolls(w: float) -> void:
	for pair in [[intendentti, roll_l, -1.0], [opas, roll_r, 1.0]]:
		var c: Node3D = pair[0]
		var r: Node3D = pair[1]
		var s: float = pair[2]
		var hi := r.to_global(Vector3(0, PH * 0.22, 0))
		var lo := r.to_global(Vector3(0, -PH * 0.12, 0))
		# Ulompi käsi ylempään otteeseen, sisempi alempaan.
		var outer := "_r" if s > 0 else "_l"
		var inner := "_l" if s > 0 else "_r"
		_arm(c, outer, hi, w)
		_arm(c, inner, lo, w)


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	_pointing.clear()
	for c in [me, intendentti, opas, suntio, pekka, arto]:
		c.clear_ik()
		_lean(c, 0.0)
		c.set_override("neck_01", Vector3.RIGHT, 0.0)
	match p:
		"sinetti":
			_story = "Kellotapulin juurella. Raahen museon intendentti avaa lyijykotelon."
		"piirustus":
			_story = ""
			case_lid.rotation.x = 1.9
			lens.visible = false
			_stand(suntio, SUNTIO_AT.x, SUNTIO_AT.y)
		"torni":
			_story = ""
			case_lid.rotation.x = 1.9
			lens.visible = false
			_set_open(1.0)
			for c in [intendentti, opas]:
				c.play("Idle", 0.2)
			var hl := _holder_spot(true)
			var hr := _holder_spot(false)
			intendentti.global_position = hl
			opas.global_position = hr
			_stand(suntio, SUNTIO_LATER.x, SUNTIO_LATER.y)
			_stand(me, ME_LATER.x, ME_LATER.y)
		"kierros":
			_story = ""
			case_lid.rotation.x = 1.9
			_set_open(1.0)
			_set_alpha(1.0)
			intendentti.global_position = _holder_spot(true)
			opas.global_position = _holder_spot(false)
			_stand(suntio, SUNTIO_LATER.x, SUNTIO_LATER.y)
			_stand(me, ME_LATER.x, ME_LATER.y)
			pekka.visible = true
			arto.visible = true
			_bell_t = -1.0
			if world.tapuli_bell != null:
				(world.tapuli_bell as Node3D).rotation.z = _bell0
		"otsikko":
			_story = ""
			case_lid.rotation.x = 1.9
			_set_open(1.0)
			_set_alpha(1.0)
			intendentti.global_position = _holder_spot(true)
			opas.global_position = _holder_spot(false)
			_stand(suntio, SUNTIO_LATER.x, SUNTIO_LATER.y)
			_stand(me, ME_LATER.x, ME_LATER.y)
			pekka.visible = true
			arto.visible = true
			_stand(pekka, PEKKA_AT.x, PEKKA_AT.y)
			_stand(arto, ARTO_AT.x, ARTO_AT.y)
			kori.visible = true
			kori.global_position = _L(PEKKA_AT.x + 0.35, PEKKA_AT.y - 0.35)
			kori.global_rotation = Vector3(0, _G.global_rotation.y + 0.3, 0)
			for c in [pekka, arto, intendentti, opas, suntio, me]:
				c.play("Idle", 0.2)
			_bell_t = -1.0
			if world.tapuli_bell != null:
				(world.tapuli_bell as Node3D).rotation.z = _bell0
			Sfx.play("win", -6.0, 0.95)


func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("interact") and (phase != "sinetti" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"sinetti":
			_step_sinetti(delta)
		"piirustus":
			_step_piirustus(delta)
		"torni":
			_step_torni(delta)
		"kierros":
			_step_kierros(delta)
		"otsikko":
			_step_otsikko(delta)
	_step_bell(delta)
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
	if world.tapuli_bell != null and is_instance_valid(world.tapuli_bell):
		(world.tapuli_bell as Node3D).rotation.z = _bell0
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	for nd in _was_visible:
		if is_instance_valid(nd):
			(nd as Node3D).visible = _was_visible[nd]
	finished.emit()
	_cam.queue_free()
	queue_free()


## Kello heilahtaa (vaimeneva heilunta nivelen ympäri) ja lyö joka ääriasennossa.
func _step_bell(delta: float) -> void:
	if _bell_t < 0.0 or world.tapuli_bell == null:
		return
	_bell_t += delta
	var amp := 0.42 * exp(-_bell_t * 0.28) * clampf(_bell_t / 0.5, 0.0, 1.0)
	var a := sin(_bell_t * 3.1) * amp
	(world.tapuli_bell as Node3D).rotation.z = _bell0 + a
	if absf(a) > 0.1:
		bell_swung = true
	var beat := int(floor(_bell_t * 3.1 / PI))
	if beat > 0 and not _once.has("lyonti%d" % beat) and amp > 0.08:
		_once["lyonti%d" % beat] = true
		Sfx.play("bell", -1.0 - beat * 0.8, 0.35)


func _step_sinetti(_delta: float) -> void:
	# Kansi nousee (0,4-1,2 s), intendentti nostaa rullan (1,4-2,4 s) ja suurennuslasin sinetin eteen (3,0 s ->).
	for c in [suntio, opas, me]:
		_face(c, case_box.global_position)
	_face(intendentti, _L(INT_AT.x, INT_AT.y - 3.0))
	case_lid.rotation.x = lerpf(0.0, 1.9, clampf((_t - 0.4) / 0.8, 0.0, 1.0))
	if _once.has("kansi") == false and _t > 0.4:
		_once["kansi"] = true
		Sfx.play("door", -8.0, 1.6)
	var in_case := case_box.to_global(Vector3(0, 0.05, 0))
	var held := intendentti.to_global(intendentti.bone_position("spine_03")) + intendentti.global_basis * Vector3(0.0, 0.42, -0.4)
	if _t < 1.4:
		scroll.global_transform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0).rotated(Vector3.UP, _G.global_rotation.y), in_case)
		_lean(intendentti, 0.35 * clampf((_t - 0.6) / 0.6, 0.0, 1.0))
		_arm(intendentti, "_r", in_case + Vector3(0.12, 0.03, 0), clampf((_t - 0.7) / 0.6, 0.0, 1.0))
	else:
		var k := clampf((_t - 1.4) / 1.0, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var b0 := Basis(Vector3.FORWARD, PI / 2.0).rotated(Vector3.UP, _G.global_rotation.y)
		var b1 := Basis(Vector3.UP, intendentti.global_rotation.y + PI)  # pystyssä, sinetin kuva intendentistä poispäin
		scroll.global_transform = Transform3D(b0.slerp(b1, e).orthonormalized(), in_case.lerp(held, e))
		_lean(intendentti, 0.35 * (1.0 - e))
		# Oikea käsi rullan yläpäähän, vasen pitelee suurennuslasia.
		_arm(intendentti, "_r", roll_r.to_global(Vector3(0, PH * 0.3, 0)), 1.0)
		if _t > 2.8:
			lens.visible = true
			var sp := seal.to_global(Vector3(0, -0.12, 0))
			var k2 := clampf((_t - 2.8) / 0.5, 0.0, 1.0)
			var lp := sp + (scroll.global_basis.z * 0.08) + scroll.global_basis.x * 0.02
			var hand_rest := intendentti.to_global(intendentti.bone_position("hand_l"))
			lens.global_position = hand_rest.lerp(lp, k2)
			lens.global_basis = scroll.global_basis
			_arm(intendentti, "_l", lens.global_position + Vector3(0, -0.13, 0), k2)
	if _t > 3.4 and _t < 5.1:
		_bub[intendentti] = "Kruunu. G. R. Gustavus Rex."
	elif _t >= 5.1:
		_bub[intendentti] = "Kuninkaan oma sinetti. Aito."
		_story = ""
	if _t > 5.6:
		_bub[suntio] = "...Herra varjele."
	# Ensin pöytä ja tapuli pihalta, sitten lähikuva sinetistä suurennuslasin takaa.
	var look: Vector3
	var eye: Vector3
	if _t < 3.0:
		# Pihalta pöydän yli tapulia kohti: pöytä ja intendentti keskellä, tapuli niiden takana.
		look = _L(TABLE.x - 0.25, TABLE.y + 0.4, 1.3)
		eye = _L(3.1, -16.7, 1.75)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.6))
	else:
		var sp2 := seal.to_global(Vector3(0, -0.12, 0))
		look = sp2 + Vector3(0, 0.1, 0)
		eye = sp2 + scroll.global_basis.z * 0.62 + Vector3(0, 0.12, 0) + scroll.global_basis.x * 0.1
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 0.6))


func _step_piirustus(_delta: float) -> void:
	# Intendentti ja opas kävelevät pitäjien paikoille (0-2,0 s), avaavat rullan välilleen (2,2-3,6 s) ja lukevat.
	var hl := _holder_spot(true)
	var hr := _holder_spot(false)
	var walk := clampf(_t / 2.0, 0.0, 1.0)
	var i0 := _L(INT_AT.x, INT_AT.y)
	var o0 := _L(OPAS_AT.x, OPAS_AT.y)
	intendentti.global_position = i0.lerp(hl, walk)
	opas.global_position = o0.lerp(hr, walk)
	for c in [intendentti, opas]:
		c.play("Walk" if walk < 1.0 else "Idle", 0.2)
	var tower := _L(0, 0)
	if walk < 1.0:
		_face(intendentti, hl + (hl - i0))
		_face(opas, hr + (hr - o0))
	else:
		_face(intendentti, tower)
		_face(opas, tower)
	_face(suntio, intendentti.global_position)
	_face(me, intendentti.global_position)
	var open := clampf((_t - 2.2) / 1.4, 0.0, 1.0)
	_set_open(open * open * (3.0 - 2.0 * open))
	var pose := _paper_pose(0.0)
	if walk < 1.0:
		# Rulla kulkee intendentin kädessä pystyssä.
		var held := intendentti.to_global(intendentti.bone_position("spine_03")) + intendentti.global_basis * Vector3(0.0, 0.0, -0.35)
		scroll.global_transform = Transform3D(Basis(Vector3.UP, intendentti.global_rotation.y + PI), held)
		_arm(intendentti, "_r", roll_r.to_global(Vector3(0, PH * 0.3, 0)), 1.0)
	else:
		var k := clampf((_t - 2.0) / 0.4, 0.0, 1.0)
		var start := scroll.global_transform
		scroll.global_transform = start.interpolate_with(pose, k)
		_hold_rolls(1.0)
		for c in [intendentti, opas]:
			c.set_override("neck_01", Vector3.RIGHT, 0.35)  # katse paperiin
	if _t > 3.8 and _t < 5.5:
		_bub[opas] = "Kuninkaan oma käsi. Tapuli viiva viivalta."
	elif _t >= 5.5:
		_bub[intendentti] = "Nostetaan se tapulia vasten."
	# Ensin pihalta kävely, sitten intendentin olan yli piirustukseen (tussiviivat ja kruunu luettavina).
	var look: Vector3
	var eye: Vector3
	if _t < 2.2:
		look = intendentti.global_position.lerp(opas.global_position, 0.5) + Vector3(0, 1.1, 0)
		eye = _L(3.6, -18.0, 1.7)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.5))
	else:
		look = pose.origin
		eye = pose.origin + pose.basis.z * 1.05 + Vector3(0, 0.15, 0) - pose.basis.x * 0.12
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 0.95))


func _step_torni(_delta: float) -> void:
	# Nosto (0-1,4 s), paperi haalistuu (2,0-3,2 s): viivat oikean tapulin päällä. Kello heilahtaa 3,6 s, kaikki katsovat
	# ylös; kuva leikkaa kellokerrokseen 4,4 s.
	var tower_top := world.tapuli_root.to_global(Vector3(0, 6.2, 0)) as Vector3
	var raise := clampf(_t / 1.4, 0.0, 1.0)
	var e := raise * raise * (3.0 - 2.0 * raise)
	if _t > 4.3:  # kellon lyödessä piirustus laskee rinnalle, jotta kello näkyy (ja paperi kirkastuu taas)
		var down := clampf((_t - 4.3) / 0.4, 0.0, 1.0)
		e = 1.0 - down
		_set_alpha(lerpf(0.18, 1.0, down))
	scroll.global_transform = _paper_pose(e)
	_hold_rolls(1.0)
	_face(intendentti, _L(0, 0))
	_face(opas, _L(0, 0))
	_face(suntio, tower_top)
	_face(me, tower_top)
	if _t > 2.0 and _t <= 4.3:
		_set_alpha(lerpf(1.0, 0.18, clampf((_t - 2.0) / 1.2, 0.0, 1.0)))
	if _t > 2.4 and _t < 3.6:
		_story = "Kuninkaan viivat ja tapuli: nurkka nurkalta."
	if _t > 3.6 and _bell_t < 0.0:
		_bell_t = 0.0
		Sfx.play("wind", -6.0, 1.0)
	if _t > 3.6:
		_story = ""
		var up := clampf((_t - 3.8) / 0.5, 0.0, 1.0)
		for c in [suntio, me, intendentti, opas]:
			c.set_override("neck_01", Vector3.RIGHT, -0.5 * up)
	if _t > 4.8:
		_bub[suntio] = "...Kuninkaan tuuli."
	var look: Vector3
	var eye: Vector3
	if _t < 4.4:
		_cam.fov = 52.0
		_cam.look_at_from_position(_eye, _eye + (-_paper_basis.z))
	else:
		# Matalalta väen takaa ylös kellokerrokseen: päät alareunassa, kello keskellä.
		look = _L(0.0, -1.0, 4.6)
		eye = _L(0.25, -15.7, 1.2)
		_cam_at(eye, look, 40.0)


func _step_kierros(_delta: float) -> void:
	# Pekka ja Arto tulevat pihalta (0-2,6 s), kori laskettuna maahan, Pekka jakaa tölkit (3,0-4,6 s), Arto myöntää,
	# kaikki nostavat (5,4 s) "Gustavukselle!".
	var paths := {pekka: [Vector2(-5.5, -21.0), PEKKA_AT, 0.0, 2.6], arto: [Vector2(-6.4, -20.4), ARTO_AT, 0.2, 2.6]}
	for c: Node3D in paths:
		var pth: Array = paths[c]
		var k := clampf((_t - float(pth[2])) / float(pth[3]), 0.0, 1.0)
		var e := k * (2.0 - k)
		var p: Vector2 = (pth[0] as Vector2).lerp(pth[1], e)
		_stand(c, p.x, p.y)
		c.play("Walk" if k < 1.0 else "Idle", 0.2)
		_face(c, _L(pth[1].x, pth[1].y + 1.0) if k < 1.0 else _L(0.3, -14.4))
	# Kori Pekan sylissä tullessa, sitten maahan.
	kori.visible = true
	if _t < 2.7:
		var ch := pekka.to_global(pekka.bone_position("spine_02")) + pekka.global_basis * Vector3(0, -0.12, -0.32)
		kori.global_position = ch + Vector3(0, -0.1, 0)
		kori.global_rotation = Vector3(0, pekka.global_rotation.y, 0)
		_arm(pekka, "_l", ch + pekka.global_basis * Vector3(0.19, 0.0, 0.0), 1.0)
		_arm(pekka, "_r", ch + pekka.global_basis * Vector3(-0.19, 0.0, 0.0), 1.0)
	else:
		var k := clampf((_t - 2.7) / 0.3, 0.0, 1.0)
		var ground := _L(PEKKA_AT.x + 0.35, PEKKA_AT.y - 0.35)
		kori.global_position = kori.global_position.lerp(ground, k)
	_face(intendentti, pekka.global_position)
	_face(opas, pekka.global_position)
	_face(suntio, pekka.global_position)
	_face(me, pekka.global_position)
	_hold_rolls(1.0)
	scroll.global_transform = _paper_pose(0.0)
	if _t >= 2.7 and not _once.has("kori_alas"):
		_once["kori_alas"] = true
		pekka.clear_ik()
	if _t > 5.4:
		var tt := world.tapuli_root.to_global(Vector3(0, 6.0, 0)) as Vector3
		for c in [pekka, arto, suntio, me]:
			_face(c, tt)
	_bub.clear()
	# Tölkit käsiin vuorotellen.
	var takers := [[pekka, 3.0], [arto, 3.3], [me, 3.6], [suntio, 4.1], [opas, 4.4]]
	var raise := clampf((_t - 5.4) / 0.4, 0.0, 1.0)
	for i in takers.size():
		var c: Node3D = takers[i][0]
		var at: float = takers[i][1]
		var can: Node3D = cans[[intendentti, opas, suntio, pekka, arto, me].find(c)]
		if _t > at:
			can.visible = true
			var hp := _hand(c)
			can.global_position = hp + Vector3(0, -0.04, 0)
			can.global_rotation = Vector3.ZERO
			if c != opas:  # opas pitää rullaa toisella kädellä, tölkki vapaaseen
				var sh: Vector3 = c.bone_position("upperarm_r")
				var s := signf(sh.x) if sh.x != 0.0 else 1.0
				var rest := sh + Vector3(s * 0.12, -0.32, -0.25)
				var up := sh + Vector3(s * 0.05, 0.5, -0.22)
				c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", rest.lerp(up, raise), sh + Vector3(s * 0.45, -0.3, 0.25))
	if _t > 0.8 and _t < 2.8:
		_bub[pekka] = "No? Onko se kuninkaan?"
	elif _t >= 2.8 and _t < 4.4:
		_bub[arto] = "Rakennusmestarin työ, mää sanoin... No. Kuninkaan."
	elif _t >= 4.4 and _t < 5.4:
		_bub[suntio] = "Kirkon mäellä... Kerran kahdessasadassa vuodessa."
	elif _t >= 5.4:
		_bub[pekka] = "Mää tarjoan! GUSTAVUKSELLE!"
		if not _once.has("kilis"):
			_once["kilis"] = true
			Sfx.play("glass", -4.0, 1.2)
	# Sivukuva pihan laidalta: Pekka ja Arto vasemmalla, pitäjät ja suntio keskellä, tapuli taustalla.
	var look := _L(-0.6, -14.8, 1.2)
	var eye := _L(-0.6, -21.0, 2.5)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 6.0))


func _step_otsikko(_delta: float) -> void:
	var tower_top := world.tapuli_root.to_global(Vector3(0, 6.0, 0)) as Vector3
	for c in [pekka, arto, suntio, me]:
		_face(c, tower_top)
		var sh: Vector3 = c.bone_position("upperarm_r")
		var s := signf(sh.x) if sh.x != 0.0 else 1.0
		c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", sh + Vector3(s * 0.05, 0.5, -0.22), sh + Vector3(s * 0.45, -0.3, 0.25))
		var can: Node3D = cans[[intendentti, opas, suntio, pekka, arto, me].find(c)]
		can.visible = true
		can.global_position = _hand(c) + Vector3(0, -0.04, 0)
		can.global_rotation = Vector3.ZERO
	_face(intendentti, _L(0, 0))
	_face(opas, _L(0, 0))
	scroll.global_transform = _paper_pose(0.0)
	_hold_rolls(1.0)
	# Pihalta matalalta: väki ja tapuli kokonaan, tölkit tapulia kohti.
	# Kallistus laskettu: ristin kärki noin 0,36 korkeudelle (otsikon ja alatekstin alle), päät noin 0,8.
	var eye := _L(-0.4, -23.0, 1.5)
	var fwd := (_L(0.0, 0.0) - eye)
	fwd.y = 0.0
	fwd = fwd.normalized()
	var look := eye + fwd * 10.0 + Vector3(0, 10.0 * tan(deg_to_rad(16.9)), 0)
	_cam_at(eye, look, 50.0)


# --- Hahmot ------------------------------------------------------------------------

func _arm(c: Node3D, lr: String, at_global: Vector3, w: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm" + lr)
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at_global), w)
	c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, tgt, sh + Vector3(s * 0.45, -0.25, 0.25))


func _lean(c: Node3D, a: float) -> void:
	c.set_override("spine_01", Vector3.RIGHT, -a * 0.45)
	c.set_override("spine_02", Vector3.RIGHT, -a * 0.35)
	c.set_override("spine_03", Vector3.RIGHT, -a * 0.2)


func _stand(c: Node3D, x: float, z: float) -> void:
	c.global_position = _L(x, z)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.global_position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


func _hand(c: Node3D) -> Vector3:
	return c.to_global((c.bone_position("hand_r") + c.bone_position("index_01_r")) / 2.0)


# --- Kehys, kamera ------------------------------------------------------------------

func _L(x: float, z: float, y := 0.0) -> Vector3:
	var p := _G.to_global(Vector3(x, 0.0, z))
	return Vector3(p.x, T.h(p.x, p.z) + y, p.z)


func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(eye, look)


func _fov_w(d: float, w: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return rad_to_deg(2.0 * atan(w / (2.0 * d) / (vs.x / vs.y)))


## Piste ruudulla (0..1) testiä varten.
func screen_frac(p: Vector3) -> Vector2:
	if _cam.is_position_behind(p):
		return Vector2(-1, -1)
	var vs := get_viewport().get_visible_rect().size
	return _cam.unproject_position(p) / vs


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
		_draw_crown(Vector2(vs.x / 2.0, y - 70.0), a)
		var title := "KUNINKAAN TAPULI"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.16, 0.09, 0.03, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(1.0, 0.84, 0.42, a))
		var sr := Rect2(vs.x / 2.0 - 420, y + 22.0, 840, 72)
		_ui.draw_rect(sr, Color(0.06, 0.04, 0.02, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 28), "Kustaa III:n sinetöity piirustus tapulin palkista",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.95, 0.8, 0.5, a))
		_ui.draw_string(font, sr.position + Vector2(0, 56), "Raahen museo vahvisti, ja Pekka tarjosi kierroksen.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Kruunu otsikon yllä: kultainen sakarakruunu tummalla ääriviivalla, punaiset kivet ja pallot sakaroissa.
func _draw_crown(c: Vector2, a: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-34, 18), c + Vector2(-40, -14), c + Vector2(-18, 2), c + Vector2(0, -26),
		c + Vector2(18, 2), c + Vector2(40, -14), c + Vector2(34, 18)])
	var dark := Color(0.2, 0.11, 0.03, a)
	var outline := pts.duplicate()
	outline.append(pts[0])
	_ui.draw_colored_polygon(pts, Color(0.95, 0.72, 0.25, a))
	_ui.draw_polyline(outline, dark, 4.0)
	_ui.draw_rect(Rect2(c + Vector2(-36, 16), Vector2(72, 10)), Color(0.85, 0.6, 0.2, a))
	_ui.draw_rect(Rect2(c + Vector2(-36, 16), Vector2(72, 10)), dark, false, 3.0)
	for p in [Vector2(-40, -14), Vector2(0, -26), Vector2(40, -14)]:
		_ui.draw_circle(c + p, 6.0, dark)
		_ui.draw_circle(c + p, 4.5, Color(1.0, 0.9, 0.5, a))
	for x in [-18.0, 0.0, 18.0]:
		_ui.draw_circle(c + Vector2(x, 21), 3.5, Color(0.85, 0.1, 0.15, a))
