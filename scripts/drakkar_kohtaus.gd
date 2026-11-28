extends CanvasLayer
## Legendaarinen hetki "drakkar" (Drakkar Noir): kun Drakkar Noir ostetaan ensimmäistä kertaa Railin kirppispöydältä
## (main.gd _kirppis_give "drakkar"), kauppa lavastetaan seuraintalon saliin salin omilla kalusteilla (kirppis_interior.gd
## stage: salin väki ja kävelijä piiloon, kohtauksen hahmot tilalle) ja lopuksi seuraintalon pihalle. Vaiheet:
##   pullo    Raili nostaa mustan pullon pöydältä ja ojentaa sen pöydän yli ("Puolillaan, mutta riittää koko kylälle"),
##            pelaaja ottaa pullon ja nostaa sen silmien korkeudelle.
##   suihku   pelaaja suihkaisee kaulaan: pssst, violetti tuoksupilvi pöllähtää. Raili sulkee silmänsä, käsi rinnalla:
##            "Voi -94. Zabukin tanssit."
##   pilvi    huipennus: tuoksupilvi leviää salin yli renkaana (säde cloud_r). Kun reuna saavuttaa hahmon, se reagoi:
##            Anna-Liisa leyhyttää kättä nenän edessä, Hilkka aivastaa, Tauno oikaisee selkänsä, sipaisee tukkaansa ja
##            muistaa oman Drakkarinsa -89.
##   kyla     pihalla pilvi valuu pariovesta Seurantielle ja nousee kylän ylle. Sinikka pysähtyy tiellä, kääntyy ja haistaa:
##            "Mmm... onks toi Drakkar Noir?", ja Pekka tienvarressa: "Kuka siellä on noin laittautunu?"
##   otsikko  salissa: Anna-Liisa pitelee nenäänsä, Hilkka niistää, Raili leyhyttää VHS-kasetilla, Tauno kumartuu
##            haistelemaan, pelaaja nostaa pullon. DRAKKAR NOIR.
## Kehys: salin paikalliset koordinaatit (kirppis_interior.gd: +Z = pääovi, -Z = lava; keskipöytä keskellä 3 x 1 m,
## pinta y 0,75). Piha: world.seura_kuisti (julkisivun keskikohta, paikallinen -Z = pihalle päin). Hahmojen etu -Z
## (Looks), B.yaw_to(v) kääntää etupuolen suuntaan v. Raili muistelee myöhemmin kirppikselle tultaessa (main.gd
## _on_kirppis_entered, MUISTO).

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const T := preload("res://scripts/terrain.gd")

const DUR := {"pullo": 6.4, "suihku": 5.6, "pilvi": 8.4, "kyla": 7.4, "otsikko": 6.6}
const ORDER := ["pullo", "suihku", "pilvi", "kyla", "otsikko"]
const TABLE_Y := 0.75
const BOTTLE_AT := Vector3(0.15, TABLE_Y, 0.2)  # pullo Railin pöydällä (salin oma pullo samassa kohdassa)
const RAILI_AT := Vector3(0.12, 0.0, -0.82)
const ME_AT := Vector3(0.28, 0.0, 0.92)
const ANNA_AT := Vector3(1.85, 0.0, 1.55)
const HILKKA_AT := Vector3(-4.25, 0.0, -0.95)
const TAUNO_AT := Vector3(4.25, 0.0, -1.15)
const CLOUD_MAX := 8.6
const CLOUD_SPEED := 1.25  # m/s
const HAZE := Color(0.6, 0.52, 0.78)  # tumma laventeli: tuoksu näkyy, hahmot erottuvat läpi
const N_HALL := 64
const SINIKKA_X := 0.4  # Sinikan reitti tiellä (pihan kehys): x 0,4 -> -1,2, z -10,4 (kuvan oikea puoli)
const SINIKKA_Z := -10.4
const N_OUT := 40
## Raili muistelee (main.gd _on_kirppis_entered).
const MUISTO := ["Kulta, sitä Drakkaria haistettiin Seurantiellä asti. Hilkka aivasteli viikon.",
	"Mää myin sulle sen pullon, ja kolme mummoa kysy seuraavana päivänä, onko mulla toista.",
	"Tauno kävi kysymässä, mistä niitä saa. Kuolinpesistä, kulta. Kuolinpesistä.",
	"Ysärin tuoksu. Mää meinasin itkeä, ku se pilvi tuli pöydän yli."]

var world: Node3D
var hall: Node3D  # kirppis_interior.gd
var hide_nodes: Array = []
var _was_visible := {}

var phase := ""
var _t := 0.0
var _cam: Camera3D
var _ui: Control
var _keys_bar: Node
var _story := ""
var _bub := {}
var _G: Node3D  # salin kehys
var _X: Node3D  # pihan kehys
var _props: Array[Node3D] = []
var me: Node3D
var raili: Node3D
var annaliisa: Node3D
var hilkka: Node3D
var tauno: Node3D
var sinikka: Node3D
var pekka: Node3D
var bottle: Node3D
var vhs: Node3D
var hankie: Node3D
var _hall_puffs: Array[MeshInstance3D] = []
var _out_puffs: Array[MeshInstance3D] = []
var _seed: Array = []  # [kulma, osuus, korkeus, koko] salin pilven hiukkasille
var cloud_r := 0.0  # testi lukee: pilven reunan säde pelaajasta
var reacted := {}  # hahmo -> aika, jolloin pilvi saavutti
var sprayed := false
var bottle_holder := "poyta"  # "poyta", "raili", "me"


func _ready() -> void:
	layer = 6
	_G = Node3D.new()
	hall.add_child(_G)
	_props.append(_G)
	hall.stage(true)
	if "drakkar" in hall and hall.drakkar != null:
		_was_visible[hall.drakkar] = hall.drakkar.visible
		hall.drakkar.visible = false
	_cam = Camera3D.new()
	_G.add_child(_cam)
	_cam.make_current()
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	_keys_bar = preload("res://scripts/hint_bar.gd").new()
	_keys_bar.compact = true
	_keys_bar.centered = true
	add_child(_keys_bar)
	_keys_bar.set_text("%s ohita" % Settings.cap("interact"))
	for nd in hide_nodes:
		if is_instance_valid(nd):
			_was_visible[nd] = (nd as Node3D).visible
			(nd as Node3D).visible = false
	_build()
	_build_yard()
	_begin("pullo")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	# Salin etuseinä täyteen korkeuteen (salin oma on matala ylhäältä kuvaavaa kävelykameraa varten, kanttori_virsi.gd):
	# Railin olan yli otetut kuvat näyttävät seinän ja pariovet, eivät taivasta. Lattian ULOS-merkki piiloon kohtauksen
	# ajaksi (pelin ohjeteksti, ei kuulu kuvaan).
	var panel := Color(0.86, 0.8, 0.66)
	for seg in [[-5.1, 7.8], [5.1, 7.8]]:
		B.mesh(_G, B.boxm(Vector3(seg[1], 3.8, 0.12)), Vector3(seg[0], 1.9, 6.02), panel)
	B.mesh(_G, B.boxm(Vector3(2.4, 1.4, 0.12)), Vector3(0, 3.1, 6.02), panel)
	B.mesh(_G, B.boxm(Vector3(18.0, 1.0, 0.04)), Vector3(0, 0.5, 5.94), Color(0.45, 0.3, 0.18))
	B.mesh(_G, B.boxm(Vector3(2.44, 2.44, 0.06)), Vector3(0, 1.22, 6.0), Color(0.42, 0.27, 0.15))
	B.mesh(_G, B.boxm(Vector3(0.03, 2.3, 0.08)), Vector3(0, 1.15, 5.98), Color(0.3, 0.18, 0.1))
	for lb in hall.find_children("*", "Label3D", false, false):
		if (lb as Label3D).text == "ULOS":
			_was_visible[lb] = (lb as Label3D).visible
			(lb as Label3D).visible = false
	raili = _person(_look("raili"), RAILI_AT, Vector3(0, 0, 1))
	me = _person(Looks.player(), ME_AT, Vector3(-0.15, 0, -1))
	annaliisa = _person(_look("annaliisa"), ANNA_AT, Vector3(-1, 0, 0.35))  # pelaajaa kohti, kasvot salin ovelle päin
	hilkka = _person(_look("hilkka"), HILKKA_AT, Vector3(1, 0, 0.25))
	tauno = _person(_look("tauno"), TAUNO_AT, Vector3(-1, 0, 0.3))
	Looks.hunch(hilkka, 0.15)
	Looks.hunch(tauno, 0.15)
	bottle = build_bottle()
	_G.add_child(bottle)
	bottle.position = BOTTLE_AT
	bottle.rotation.y = 0.3
	_props.append(bottle)
	vhs = _build_vhs()
	_G.add_child(vhs)
	vhs.position = Vector3(-0.55, TABLE_Y + 0.012, 0.15)
	vhs.rotation = Vector3(-PI / 2.0, 0.2, 0)
	_props.append(vhs)
	hankie = Node3D.new()  # Hilkan nenäliina (otsikko): valkoinen, pitsireunainen, rypyssä
	_G.add_child(hankie)
	_props.append(hankie)
	for k in 3:
		var leaf := B.mesh(hankie, B.boxm(Vector3(0.13 - k * 0.025, 0.11 - k * 0.02, 0.004)), Vector3(0, -0.02 * k, -0.01 * k), Color(0.98, 0.97, 0.94))
		leaf.rotation = Vector3(0.25 * k, 0.35 * k - 0.3, 0.2 * k)
	B.mesh(hankie, B.boxm(Vector3(0.135, 0.008, 0.005)), Vector3(0, -0.055, 0.002), Color(0.85, 0.75, 0.85))
	hankie.visible = false
	var pm := _puff_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = 94
	for i in N_HALL:
		_hall_puffs.append(_puff(_G, pm))
		_seed.append([rng.randf() * TAU, rng.randf_range(0.3, 1.0), rng.randf_range(0.35, 2.3), rng.randf_range(0.7, 1.3)])


## Drakkar Noir: musta kulmikas lasipullo (viistetyt reunat, kiiltävä), hopeinen kaulus ja suihkupää, hopeinen
## etiketti ja punainen viiva. Pullon juuri on solmun origossa, korkeus noin 0,2 m (vähän oikeaa isompi: kuvassa
## näkyvä). Paikallinen +Z = etiketti.
static func build_bottle() -> Node3D:
	var g := Node3D.new()
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.035, 0.035, 0.045)
	glass.roughness = 0.06
	glass.metallic = 0.35
	glass.clearcoat_enabled = true
	glass.clearcoat = 1.0
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.8, 0.81, 0.85)
	silver.metallic = 0.9
	silver.roughness = 0.18
	var add := func(m: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		g.add_child(mi)
		return mi
	add.call(B.boxm(Vector3(0.1, 0.15, 0.048)), glass, Vector3(0, 0.077, 0))
	for sx in [-1.0, 1.0]:  # viistetyt pystyreunat
		add.call(B.boxm(Vector3(0.014, 0.15, 0.014)), glass, Vector3(sx * 0.05, 0.077, 0.0), Vector3(0, PI / 4.0, 0))
	add.call(B.boxm(Vector3(0.088, 0.012, 0.04)), glass, Vector3(0, 0.158, 0))  # olkapää
	add.call(B.cyl(0.016, 0.018, 0.03, 12), silver, Vector3(0, 0.178, 0))  # kaulus
	add.call(B.cyl(0.012, 0.012, 0.016, 10), silver, Vector3(0, 0.2, 0))  # suihkupää
	add.call(B.cyl(0.004, 0.004, 0.006, 6), glass, Vector3(0, 0.2, 0.012), Vector3(PI / 2.0, 0, 0))  # suutin
	add.call(B.boxm(Vector3(0.07, 0.022, 0.002)), silver, Vector3(0, 0.085, 0.0245))  # etiketti
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.7, 0.06, 0.06)
	add.call(B.boxm(Vector3(0.07, 0.004, 0.0025)), red, Vector3(0, 0.07, 0.0246))
	# Kiiltoviiru lasissa: valkoinen ohut pystyraita (näyttää lasilta myös hämärässä).
	var hi := StandardMaterial3D.new()
	hi.albedo_color = Color(1, 1, 1, 0.35)
	hi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hi.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	add.call(B.boxm(Vector3(0.006, 0.12, 0.001)), hi, Vector3(-0.03, 0.08, 0.0247))
	return g


## Railin VHS-kasetti (Uuno Turhapuro), jolla hän leyhyttää otsikossa.
func _build_vhs() -> Node3D:
	var g := Node3D.new()
	B.mesh(g, B.boxm(Vector3(0.19, 0.025, 0.105)), Vector3.ZERO, Color(0.07, 0.07, 0.08))
	B.mesh(g, B.boxm(Vector3(0.12, 0.002, 0.06)), Vector3(0, 0.0135, 0), Color(0.95, 0.85, 0.3))
	B.mesh(g, B.boxm(Vector3(0.1, 0.0025, 0.012)), Vector3(0, 0.014, -0.012), Color(0.8, 0.1, 0.1))
	return g


func _puff_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true  # hiukkasen koko scalella (ilman tätä jokainen olisi metrin kokoinen)
	m.vertex_color_use_as_albedo = false
	m.no_depth_test = false
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.add_point(0.45, Color(1, 1, 1, 0.55))
	gr.set_color(gr.get_point_count() - 1, Color(1, 1, 1, 0))
	gt.gradient = gr
	m.albedo_texture = gt
	return m


func _puff(parent: Node3D, base: StandardMaterial3D) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := base.duplicate() as StandardMaterial3D
	m.albedo_color = Color(HAZE.r, HAZE.g, HAZE.b, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


func _set_puff(p: MeshInstance3D, pos: Vector3, size: float, alpha: float) -> void:
	if _cam != null:  # kameran lähellä haalistuu: pilvi ei peitä kuvaa, kun kamera on pilven sisällä
		alpha *= clampf((pos.distance_to(_cam.global_position) - 0.5 - size * 0.4) / 0.9, 0.0, 1.0)
	p.visible = alpha > 0.005
	if not p.visible:
		return
	p.global_position = pos
	p.scale = Vector3.ONE * size
	(p.material_override as StandardMaterial3D).albedo_color.a = alpha


## Piha: Sinikka tiellä ja Pekka tienvarressa seuraintalon edessä, pilven hiukkaset pariovelle.
func _build_yard() -> void:
	if world == null or not ("seura_kuisti" in world) or world.seura_kuisti == null:
		return
	var k: Node3D = world.seura_kuisti
	_X = Node3D.new()
	world.add_child(_X)
	_props.append(_X)
	_X.global_position = Vector3(k.global_position.x, 0.0, k.global_position.z)
	_X.rotation.y = k.global_rotation.y
	sinikka = Looks.make(world, Looks.sinikka_seura())
	_props.append(sinikka)
	sinikka.global_position = _ground(SINIKKA_X, SINIKKA_Z)
	sinikka.rotation.y = _X.rotation.y + B.yaw_to(Vector3(-1, 0, 0))  # kävelee tietä pitkin
	sinikka.play("Walk", 0.0)
	pekka = Looks.make(world, Looks.PEKKA)
	_props.append(pekka)
	pekka.global_position = _ground(2.7, -12.4)  # pihan kehyksen +x näkyy tieltä katsoen vasemmalla
	pekka.rotation.y = _X.rotation.y + B.yaw_to(Vector3(-2.1, 0, -5.6))  # kasvot tielle päin (kameraan)
	pekka.play("Idle", 0.0)
	var pm := _puff_material()
	for i in N_OUT:
		_out_puffs.append(_puff(world, pm))


func _ground(x: float, z: float, y := 0.0) -> Vector3:
	var p := _X.to_global(Vector3(x, 0.0, z))
	return Vector3(p.x, T.h(p.x, p.z) + y, p.z)


func _look(id: String) -> Dictionary:
	for p: Dictionary in hall.PEOPLE:
		if p.id == id and "kirppis" in p.modes and p.has("look"):
			return p.look
	return Looks.AKKA


func _person(look: Dictionary, at: Vector3, face: Vector3) -> Node3D:
	var c: Node3D = Looks.make(_G, look)
	c.position = at
	c.rotation.y = B.yaw_to(face)
	c.play("Idle", 0.0)
	_props.append(c)
	return c


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	for c in [me, raili, annaliisa, hilkka, tauno]:
		c.clear_ik()
		c.set_override("spine_01", Vector3.RIGHT, 0.0)
		c.set_override("spine_03", Vector3.RIGHT, 0.0)
		c.set_override("neck_01", Vector3.RIGHT, 0.0)
		c.set_override("Head", Vector3.UP, 0.0)
	match p:
		"pullo":
			_story = "Railin pöydällä, VHS-kasettien ja posliinikoirien välissä: musta pullo."
		"suihku":
			_story = ""
			bottle_holder = "me"
		"pilvi":
			_story = ""
			bottle_holder = "me"
			sprayed = true
		"kyla":
			_story = "Puolikas pullo, ja koko Saloinen haistaa."
			if _X != null:
				_cam.reparent(_X, false)
		"otsikko":
			_story = ""
			if _cam.get_parent() != _G:
				_cam.reparent(_G, false)
			_cam.current = true
			Sfx.play("win", -6.0, 1.05)


func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("interact") and (phase != "pullo" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"pullo":
			_step_pullo()
		"suihku":
			_step_suihku()
		"pilvi":
			_step_pilvi()
		"kyla":
			_step_kyla()
		"otsikko":
			_step_otsikko()
	_place_bottle()
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
	for p in _out_puffs:
		if is_instance_valid(p):
			p.queue_free()
	if is_instance_valid(hall):
		hall.stage(false)
	for nd in _was_visible:
		if is_instance_valid(nd):
			(nd as Node3D).visible = _was_visible[nd]
	finished.emit()
	queue_free()


func _step_pullo() -> void:
	# 0-2,4 Raili nostaa pullon pöydältä ja ojentaa pöydän yli, 2,4-3,4 pelaaja ottaa, 3,4- pelaaja nostaa pullon
	# silmien korkeudelle ja katsoo. Kuva sivulta pöydän korkeudelta: Railin ja pelaajan kasvot, pullo keskellä.
	var mid := _H(0.2, 1.12, 0.05)
	if _t < 0.8:
		bottle_holder = "poyta"
		_reach(raili, "r", bottle.global_position + Vector3(0, 0.08, 0), clampf(_t / 0.8, 0.0, 1.0))
	elif _t < 2.4:
		bottle_holder = "raili"
		var k := _ease(clampf((_t - 0.8) / 1.0, 0.0, 1.0))
		_reach(raili, "r", _H(0.15, TABLE_Y + 0.1, 0.2).lerp(mid, k), 1.0)
		if _t > 1.0:
			_bub[raili] = "Drakkar Noir, kulta. Puolillaan, mutta riittää koko kylälle."
			raili.play("Idle_Talking", 0.3)
		_reach(me, "r", mid + Vector3(0.0, -0.02, 0.07), _ease(clampf((_t - 1.6) / 0.8, 0.0, 1.0)))
	elif _t < 3.4:
		bottle_holder = "raili" if _t < 2.7 else "me"
		_reach(raili, "r", mid, 1.0 - clampf((_t - 2.7) / 0.6, 0.0, 1.0))
		_reach(me, "r", mid + Vector3(0.0, -0.02, 0.07), 1.0)
		raili.play("Idle", 0.3)
	else:
		bottle_holder = "me"
		_bub.erase(raili)
		var k := _ease(clampf((_t - 3.4) / 0.9, 0.0, 1.0))
		var eye := me.to_global(me.bone_position("Head")) + me.global_basis * Vector3(0.0, -0.02, -0.3)
		_reach(me, "r", (mid + Vector3(0.0, -0.02, 0.07)).lerp(eye, k), 1.0)
		if _t > 4.3:
			_bub[me] = "Ysäri..."
	if _t < 3.4:
		_cam_over_me(2.0)
	else:
		_cam_over_raili(1.7)


func _step_suihku() -> void:
	# 0-1,1 pullo kaulalle, pää kallistuu, 1,2 pssst (pilvi pöllähtää), 2,0- Raili haistaa silmät kiinni.
	var neck := me.to_global(me.bone_position("neck_01"))
	var side := me.global_basis * Vector3(signf(me.bone_position("upperarm_r").x), 0, 0)
	var at_neck := neck + side * 0.13 + me.global_basis * Vector3(0, -0.02, -0.12)
	var k := _ease(clampf(_t / 1.0, 0.0, 1.0))
	var start := me.to_global(me.bone_position("Head")) + me.global_basis * Vector3(0.0, -0.02, -0.3)
	_reach(me, "r", start.lerp(at_neck, k), 1.0)
	me.set_override("Head", Vector3.FORWARD, -0.25 * k * signf(me.bone_position("upperarm_r").x))
	if _t >= 1.2 and not sprayed:
		sprayed = true
		Sfx.play("whoosh", -4.0, 2.4)
	if _t > 1.2 and _t < 2.0:
		_bub[me] = "Pssst."
	# Tuoksupilvi suuttimesta: tiheä pöllähdys, joka laajenee pöydän yli.
	var nozzle := bottle.to_global(Vector3(0, 0.2, 0.02))
	for i in _hall_puffs.size():
		if i >= 14 or _t < 1.2:
			_set_puff(_hall_puffs[i], Vector3.ZERO, 0.0, 0.0)
			continue
		var s: Array = _seed[i]
		var age := _t - 1.2 - i * 0.012
		if age <= 0.0:
			_set_puff(_hall_puffs[i], Vector3.ZERO, 0.0, 0.0)
			continue
		var dir := Vector3(cos(s[0]), 0.35 * sin(s[0] * 3.0), sin(s[0])).normalized()
		var pos: Vector3 = nozzle + dir * (0.03 + 0.13 * sqrt(age) * float(s[1])) + Vector3(0, 0.06 * age, 0)
		_set_puff(_hall_puffs[i], pos, (0.05 + 0.1 * sqrt(age)) * float(s[3]), 0.3 * clampf(age / 0.2, 0.0, 1.0) * (1.0 - 0.6 * clampf((age - 0.8) / 1.5, 0.0, 1.0)))
	if _t > 2.0:
		_bub.erase(me)
		var kk := _ease(clampf((_t - 2.0) / 0.6, 0.0, 1.0))
		raili.set_override("neck_01", Vector3.RIGHT, 0.3 * kk)  # pää taakse, nenä ylös (+ = ylös)
		var chest := raili.to_global(raili.bone_position("spine_03")) + raili.global_basis * Vector3(0, 0.0, -0.13)
		_reach(raili, "l", chest, kk, true)
		if _t > 2.5:
			_bub[raili] = "Voi... -94. Zabukin tanssit."
	if _t < 2.0:
		_cam_over_raili(1.6)
	else:
		_cam_over_me(1.7)


## Pelaajan oikean olan yli Railiin (Railin kasvot, ojennus pöydän yli); posliinikoirat ja kasetit jäävät kuvan alle.
func _cam_over_me(w: float) -> void:
	var look := _H(0.1, 1.28, -0.3)
	var eye := _H(0.98, 1.72, 2.05)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), w))


## Railin olan yli pelaajaan (pelaajan kasvot ja pullo).
func _cam_over_raili(w: float) -> void:
	var look := _H(0.3, 1.45, 0.85)
	var eye := _H(0.78, 1.66, -1.85)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), w))


func _step_pilvi() -> void:
	# Pilven reuna etenee pelaajasta (CLOUD_SPEED); kukin hahmo reagoi, kun reuna saavuttaa sen.
	cloud_r = minf(0.6 + CLOUD_SPEED * _t, CLOUD_MAX)
	_cloud(cloud_r, 0.32)
	raili.set_override("neck_01", Vector3.RIGHT, 0.25)
	_reach(raili, "l", raili.to_global(raili.bone_position("spine_03")) + raili.global_basis * Vector3(0, 0.0, -0.13), 1.0, true)
	for c: Node3D in [annaliisa, hilkka, tauno]:
		var d := Vector2(c.position.x - ME_AT.x, c.position.z - ME_AT.z).length()
		if cloud_r >= d and not reacted.has(c):
			reacted[c] = _t
	if reacted.has(annaliisa):
		var a: float = _t - reacted[annaliisa]
		_fan(annaliisa, a)
		if a < 2.6:
			_bub[annaliisa] = "Mikä toi haju on?!"
		else:
			_bub.erase(annaliisa)
	if reacted.has(hilkka):
		var a: float = _t - reacted[hilkka]
		_sneeze(hilkka, a)
		if a > 0.55 and a < 2.4:
			_bub[hilkka] = "ATSIUH!"
		elif a >= 2.4:
			_bub.erase(hilkka)
	if reacted.has(tauno):
		var a: float = _t - reacted[tauno]
		_tauno_smooth(a)
		if a > 0.6:
			_bub[tauno] = "...Drakkar. Mää käytin tätä -89."
	if _t < 5.0:
		# Leveä kuva salin ovelta: pöytä keskellä, pilvi leviää, Hilkka ja Tauno sivuilla.
		var look := _H(0.0, 1.05, -0.6)
		var eye := _H(0.0, 3.1, 5.5)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 11.6))
	else:
		# Tauno lähempää: selkä suoraksi, kampaa tukkaa, virne.
		var look := _H(4.1, 1.45, -1.05)
		var eye := _H(2.4, 1.6, 0.45)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 2.4))


## Salin tuoksupilvi säteellä r pelaajasta: hiiukkaset renkaana ja täytteenä, lattiasta pään yli.
func _cloud(r: float, alpha: float) -> void:
	var c := _H(ME_AT.x, 0.0, ME_AT.z)
	for i in _hall_puffs.size():
		var s: Array = _seed[i]
		var rr := r * float(s[1])
		var off := Vector3(cos(s[0]) * rr, 0.0, sin(s[0]) * rr)
		var lp := _G.to_local(c) + off
		lp.x = clampf(lp.x, -8.4, 8.4)
		lp.z = clampf(lp.z, -5.4, 5.6)
		lp.y = float(s[2]) + 0.08 * sin(_t * 1.3 + i)
		var size := (0.7 + 1.5 * float(s[1]) * clampf(r / CLOUD_MAX, 0.2, 1.0)) * float(s[3])
		_set_puff(_hall_puffs[i], _G.to_global(lp), size, alpha * (0.55 + 0.45 * float(s[1])))


func _step_kyla() -> void:
	_set_cloud_off()
	if _X == null:
		return
	# Pilvi valuu pariovesta pihalle kohti tietä ja nousee kylän ylle (hiukkaset kiertävät: syntyvät ovella, kulkevat
	# tielle ja haalistuvat ylhäällä).
	var door := _X.to_global(Vector3(0.0, 0.0, -0.4))
	door.y = world.seura_kuisti.global_position.y + 1.2
	var out := _X.global_basis * Vector3(0, 0, -1)
	var side := _X.global_basis * Vector3(1, 0, 0)
	for i in _out_puffs.size():
		var u := fposmod(_t * 0.2 + float(i) / _out_puffs.size(), 1.0)
		var w := sin(i * 2.3)
		var pos := door + out * (u * 11.0) + Vector3(0, 0.1 + u * u * 5.0, 0) + side * w * (0.5 + u * 5.0)
		_set_puff(_out_puffs[i], pos, 1.0 + u * 3.6, 0.5 * clampf(u / 0.06, 0.0, 1.0) * (1.0 - u))
	# Sinikka kävelee tietä, pilvi saavuttaa hänet 1,6 s: pysähtyy, kääntyy kameraan, nenä ylös ja silmät kiinni.
	var walk := clampf(_t / 1.6, 0.0, 1.0)
	sinikka.global_position = _ground(SINIKKA_X - 1.6 * walk, SINIKKA_Z)
	var to_cam := _X.to_local(_cam.global_position)
	var cam_dir := Vector3(to_cam.x - (SINIKKA_X - 1.6), 0, to_cam.z - SINIKKA_Z).normalized()
	if _t >= 1.6:
		sinikka.play("Idle", 0.25)
		var turn := _ease(clampf((_t - 1.6) / 0.6, 0.0, 1.0))
		sinikka.rotation.y = _X.rotation.y + B.yaw_to(Vector3(-1, 0, 0).lerp(cam_dir, 0.85 * turn).normalized())
		sinikka.set_override("neck_01", Vector3.RIGHT, 0.28 * turn)
		if _t > 2.2:
			_bub[sinikka] = "Mmm... onks toi Drakkar Noir?"
	# Pekka tienvarressa: haistaa, kääntää päätä seuraintaloa kohti 3,8 s.
	if _t >= 3.8:
		var turn := _ease(clampf((_t - 3.8) / 0.5, 0.0, 1.0))
		pekka.set_override("neck_01", Vector3.RIGHT, 0.18 * turn)
		pekka.set_override("Head", Vector3.UP, 0.7 * turn)  # kääntää päätä taloa kohti
		if _t > 4.3:
			_bub.erase(sinikka)
			_bub[pekka] = "Kuka siellä on noin laittautunu?"
	var look := _X.to_global(Vector3(-0.8, 0.0, -6.0))
	look.y = world.seura_kuisti.global_position.y + 2.2
	var eye := _ground(0.6, -18.0, 2.0)
	_cam.current = true
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 14.0))


func _set_cloud_off() -> void:
	for p in _hall_puffs:
		p.visible = false


func _step_otsikko() -> void:
	for p in _out_puffs:
		p.visible = false
	cloud_r = CLOUD_MAX
	_cloud(CLOUD_MAX, 0.14)
	# Anna-Liisa pitelee nenäänsä (kasvot kameraan), Hilkka niistää nenäliinaan, Raili leyhyttää kasetilla, Tauno
	# kumartuu haistelemaan pelaajaa, pelaaja nostaa pullon.
	annaliisa.position = Vector3(2.35, 0, 1.75)
	annaliisa.rotation.y = B.yaw_to(Vector3(-0.55, 0, 1))
	var nose := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head")) + c.global_basis * Vector3(0, 0.0, -0.12)
	_reach(annaliisa, "r", nose.call(annaliisa), 1.0)
	annaliisa.set_override("spine_03", Vector3.RIGHT, 0.1)
	hilkka.position = Vector3(-2.05, 0, 1.15)
	hilkka.rotation.y = B.yaw_to(Vector3(1, 0, 0.45))
	_reach(hilkka, "r", nose.call(hilkka) + Vector3(0, -0.02, 0), 1.0)
	hankie.visible = true
	hankie.global_position = _hand(hilkka, "r") + hilkka.global_basis * Vector3(0, 0.0, -0.03)
	hankie.global_basis = hilkka.global_basis
	var fan := sin(_t * 9.0) * 0.08
	raili.position = Vector3(-0.85, 0, -0.75)
	raili.rotation.y = B.yaw_to(Vector3(0.35, 0, 1))
	_reach(raili, "r", raili.to_global(raili.bone_position("Head")) + raili.global_basis * Vector3(0.14 + fan, -0.05, -0.2), 1.0)
	vhs.global_position = _hand(raili, "r")
	vhs.global_basis = raili.global_basis * Basis(Vector3.RIGHT, PI / 2.0) * Basis(Vector3.FORWARD, 0.3 + fan * 3.0)
	tauno.position = TAUNO_AT.lerp(Vector3(1.2, 0, 0.85), _ease(clampf(_t / 1.2, 0.0, 1.0)))
	tauno.rotation.y = B.yaw_to(ME_AT - tauno.position)
	tauno.set_override("spine_01", Vector3.RIGHT, -0.28 * clampf((_t - 1.0) / 0.5, 0.0, 1.0))
	tauno.play("Walk" if _t < 1.2 else "Idle", 0.2)
	me.rotation.y = B.yaw_to(Vector3(0.15, 0, 1))
	_reach(me, "r", me.to_global(me.bone_position("upperarm_r")) + me.global_basis * Vector3(0.05, 0.5, -0.18), 1.0)
	var look := _H(0.45, 1.2, 0.4)
	var eye := _H(0.8, 1.85, 4.6)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 6.6))


# --- Liike ---------------------------------------------------------------------------

## Käsi kohteeseen (maailma) painolla k; lepoasento kyljellä. chest: käsi rinnalle (kyynärpää alas ja ulos).
func _reach(c: Node3D, side: String, target: Vector3, k: float, chest := false) -> void:
	if k <= 0.0:
		return
	var sh: Vector3 = c.bone_position("upperarm_" + side)
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.08, -0.5, 0.0)
	var tl := c.to_local(target)
	var pole := sh + (Vector3(s * 0.45, -0.4, 0.1) if chest else Vector3(s * 0.5, -0.35, 0.15))
	c.set_ik("arm_" + side, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, rest.lerp(tl, k), pole)
	if chest:
		c.set_open_hand(side, k)  # kämmen rinnalla, ei nyrkkiä


## Leyhytys: käsi heiluu nenän edessä, pää kääntyy pois (a = aika reaktiosta).
func _fan(c: Node3D, a: float) -> void:
	var k := _ease(clampf(a / 0.3, 0.0, 1.0))
	var head := c.to_global(c.bone_position("Head"))
	var wave := sin(a * 14.0) * 0.07
	_reach(c, "r", head + c.global_basis * Vector3(wave, -0.06, -0.2), k)
	c.set_override("Head", Vector3.UP, 0.35 * k)
	c.set_override("spine_03", Vector3.RIGHT, 0.08 * k)


## Aivastus: henkäys taakse 0-0,5 s, nykäys eteen 0,55 s, palautuu 1,4 s mennessä.
func _sneeze(c: Node3D, a: float) -> void:
	var back := _ease(clampf(a / 0.5, 0.0, 1.0)) * (1.0 - clampf((a - 0.5) / 0.08, 0.0, 1.0))
	var fwd := clampf((a - 0.52) / 0.06, 0.0, 1.0) * (1.0 - _ease(clampf((a - 0.7) / 0.8, 0.0, 1.0)))
	c.set_override("spine_03", Vector3.RIGHT, 0.22 * back - 0.38 * fwd)
	c.set_override("neck_01", Vector3.RIGHT, 0.25 * back - 0.35 * fwd)
	if a > 0.52 and not c.has_meta("aivasti"):
		c.set_meta("aivasti", true)
		Sfx.play("grunt", -4.0, 1.6)
	var head := c.to_global(c.bone_position("Head"))
	_reach(c, "r", head + c.global_basis * Vector3(0.0, -0.06, -0.14), clampf(a / 0.45, 0.0, 1.0))


## Tauno: selkä suoraksi (kumara pois), haistaa nenä ylhäällä, sipaisee kädellä tukkaa sivulta taakse.
func _tauno_smooth(a: float) -> void:
	var k := _ease(clampf(a / 0.5, 0.0, 1.0))
	tauno.set_override("spine_01", Vector3.RIGHT, 0.12 * k)
	tauno.set_override("neck_01", Vector3.RIGHT, 0.18 * k)
	var head := tauno.to_global(tauno.bone_position("Head"))
	var sweep := clampf((a - 0.8) / 1.2, 0.0, 1.0)
	var s := signf(tauno.bone_position("upperarm_r").x)
	var front := head + tauno.global_basis * Vector3(s * 0.1, 0.1, -0.06)
	var back := head + tauno.global_basis * Vector3(s * 0.1, 0.1, 0.07)
	_reach(tauno, "r", front.lerp(back, _ease(fposmod(sweep * 2.0, 1.0))), clampf((a - 0.6) / 0.3, 0.0, 1.0))
	tauno.set_open_hand("r", 1.0)


## Pullo kädessä tai pöydällä (pullon juuri kämmenen kohdalla, pystyssä).
func _place_bottle() -> void:
	match bottle_holder:
		"poyta":
			bottle.position = BOTTLE_AT
			bottle.rotation = Vector3(0, 0.3, 0)
		"raili", "me":
			var c: Node3D = raili if bottle_holder == "raili" else me
			var h := _hand(c, "r")
			bottle.global_basis = Basis(Vector3.UP, c.global_rotation.y + PI)
			bottle.global_position = h + Vector3(0, -0.075, 0)


## Kädestä pullon keskikohtaan (testi mittaa ojennuksen).
func bottle_gap(c: Node3D) -> float:
	return _hand(c, "r").distance_to(bottle.global_position + Vector3(0, 0.08, 0))


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _hand(c: Node3D, side := "r") -> Vector3:
	return c.to_global((c.bone_position("hand_" + side) + c.bone_position("index_01_" + side)) / 2.0)


# --- Kehys, kamera ------------------------------------------------------------------

func _H(x: float, y: float, z: float) -> Vector3:
	return _G.to_global(Vector3(x, y, z))


func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(eye, look)


func _fov_w(d: float, w: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return rad_to_deg(2.0 * atan(w / (2.0 * d) / (vs.x / vs.y)))


## Kameraa: testi lukee.
func camera() -> Camera3D:
	return _cam


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
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.06, 0.03, 0.1, 0.25 * a))
		var y := vs.y * 0.22
		_draw_icon(Vector2(vs.x / 2.0, y - 86.0), a)
		var title := "DRAKKAR NOIR"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.08, 0.05, 0.14, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(0.86, 0.87, 0.92, a))
		var sr := Rect2(vs.x / 2.0 - 440, vs.y - 158.0, 880, 84)
		_ui.draw_rect(sr, Color(0.06, 0.04, 0.08, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Ysärin legendaarinen tuoksu Railin kirppispöydältä.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.9, 0.85, 1.0, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Puolikas pullo, ja koko Saloinen haistaa.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.85, a))


## Musta kulmikas pullo hopeisella korkilla ja tuoksukiehkurat.
func _draw_icon(c: Vector2, a: float) -> void:
	var glass := Color(0.05, 0.05, 0.07, a)
	var silver := Color(0.82, 0.83, 0.88, a)
	_ui.draw_rect(Rect2(c + Vector2(-18, -12), Vector2(36, 50)), glass)
	_ui.draw_rect(Rect2(c + Vector2(-18, -12), Vector2(36, 50)), silver, false, 2.0)
	_ui.draw_rect(Rect2(c + Vector2(-6, -24), Vector2(12, 12)), silver)
	_ui.draw_rect(Rect2(c + Vector2(-13, 8), Vector2(26, 7)), silver)
	for k in 3:
		var x0 := -14.0 + k * 14.0
		var pts := PackedVector2Array()
		for j in 9:
			pts.append(c + Vector2(x0 + sin(j * 0.9 + k) * 5.0, -30.0 - j * 4.0))
		_ui.draw_polyline(pts, Color(HAZE.r + 0.2, HAZE.g + 0.2, HAZE.b + 0.15, a * 0.9), 3.0)
