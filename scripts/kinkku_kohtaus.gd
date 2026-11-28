extends CanvasLayer
## Legendaarinen hetki "kinkku" (Bingon jättipotti): kun bingossa osuu ensimmäistä kertaa jättipotti (main.gd
## _start_bingo, palkinto "kinkku"), voitto lavastetaan seuraintalon saliin salin omilla kalusteilla (kirppis_interior.gd
## stage: salin väki ja kävelijä piiloon, kohtauksen hahmot tilalle). Vaiheet:
##   bingo      pelaaja ponnahtaa pöydän päästä seisomaan lappu ylhäällä: "BINGO!" Mummojen päät kääntyvät kuin
##              naruista vedettyinä, Erkki lavalta: "...Tarkistetaan."
##   tarkistus  Erkki tulee lavalta, ottaa lapun ja lukee numerot (lähikuva lapusta, ympyröidyt numerot). Hiljaisuus.
##              "Se on bingo." Mummo Elvin kynä katkeaa kädessä (palat ja lastut).
##   kinkku     huipennus: Raili kantaa kahviosta jättipotin, kiiltävän joulukinkun vadilla (ristiviillot, neilikat,
##              paperikrusidi luussa ja punainen rusetti). Erkki: "JÄTTIPOTTI!" Kinkku pelaajan syliin, ja paino
##              notkauttaa selän.
##   mummot     mummot nousevat tuoliensa takaa yksi kerrallaan, kädet puuskassa, mulkoilevat ja sanovat sanansa; Tauno
##              lysähtää ("joka viikko sama numero puuttuu"). Lopuksi mummot kääntävät selkänsä yhtä aikaa: "Hmph!"
##   otsikko    pelaaja nostaa kinkun pään yli, mummot selin kädet puuskassa, Raili taputtaa yksin. BINGON JÄTTIPOTTI.
## Kehys: salin paikalliset koordinaatit (kirppis_interior.gd: +Z = pääovi, -Z = lava; keskipöytä 3 x 1 m keskellä,
## pinta y 0,75; lava z -6..-3,4, pinta y 0,5). Bingopöydän tuolit rivissä z 0,9 (kasvot lavalle, -Z), pelaaja pöydän
## päässä x 2,55. Hahmojen etu -Z (Looks), B.yaw_to(v) kääntää etupuolen suuntaan v. Hilkka muistelee bingoon tultaessa
## (main.gd _on_kirppis_entered, MUISTO).

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")

const DUR := {"bingo": 5.0, "tarkistus": 8.6, "kinkku": 7.4, "mummot": 8.6, "otsikko": 6.6}
const ORDER := ["bingo", "tarkistus", "kinkku", "mummot", "otsikko"]
const TABLE_Y := 0.75
const ROW_Z := 0.9
const SEATS := [-2.0, -1.0, 0.0, 1.0]  # Aili, Hilkka, Elvi, Tauno
const ME_AT := Vector3(2.55, 0.0, 0.95)
const ERKKI_FROM := Vector3(2.9, 0.0, -2.6)
const ERKKI_AT := Vector3(2.6, 0.0, 0.18)
const RAILI_FROM := Vector3(0.6, 0.0, 3.2)
const RAILI_AT := Vector3(2.05, 0.0, 1.72)
const MUMMO := {"model": "female", "shirt": Color(0.45, 0.4, 0.6), "pants": Color(0.25, 0.22, 0.3), "shoes": Color(0.3, 0.25, 0.2), "shoe": "kavelykenka",
	"hair": "Hair_Buns", "hair_color": Color(0.9, 0.9, 0.9), "height": 1.56, "skin": Color(0.95, 0.8, 0.74), "belly": 0.5}
## Lapun numerot (ylärivi täynnä: B I N G O).
const ROW := ["7", "22", "★", "51", "68"]
## Hilkka muistelee (main.gd _on_kirppis_entered).
const MUISTO := ["Kas, kinkkuvaras. Ei meille kukaan oo antanu kinkkua kolmeenkymmeneen vuoteen.",
	"Elvi osti uuden kynän. Sanoo, että vanha katkes sun takia.",
	"Mää en puhu kinkusta. Mää en puhu siitä ikinä. ...Oliko se hyvää?",
	"Tiistaina on bingo. Älä tuu. Tai tuu, mutta älä voita."]

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
var _G: Node3D
var _props: Array[Node3D] = []
var me: Node3D
var erkki: Node3D
var raili: Node3D
var elvi: Node3D
var aili: Node3D
var hilkka: Node3D
var tauno: Node3D
var row: Array[Node3D] = []  # Aili, Hilkka, Elvi, Tauno (tuolit SEATS)
var kinkku: Node3D
var slip: Node3D
var pencil_a: Node3D
var pencil_b: Node3D
var _chips: Array[MeshInstance3D] = []
var snapped := false
var kinkku_holder := "kahvio"  # "kahvio", "raili", "me"
var slip_holder := "me"  # "me", "erkki"
var turned_away := false


func _ready() -> void:
	layer = 6
	_G = Node3D.new()
	hall.add_child(_G)
	_props.append(_G)
	hall.stage(true)
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
	_begin("bingo")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	# Salin etuseinä täyteen korkeuteen (kanttori_virsi.gd): lavan puolelta otetut kuvat näyttävät seinän ja pariovet,
	# eivät taivasta. Lattian ULOS-merkki piiloon kohtauksen ajaksi.
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
	for x in SEATS + [2.0]:
		_chair(Vector3(x, 0, ROW_Z))
	var looks := [MUMMO.duplicate(), _look("hilkka"), MUMMO.duplicate(), _look("tauno")]
	looks[0]["shirt"] = Color(0.35, 0.5, 0.42)
	looks[0]["hair_color"] = Color(0.75, 0.74, 0.72)
	for i in SEATS.size():
		var c := _sit(looks[i], float(SEATS[i]))
		row.append(c)
		Looks.hunch(c, 0.2)
	aili = row[0]
	hilkka = row[1]
	elvi = row[2]
	tauno = row[3]
	me = _sit(Looks.player(), 2.0)
	erkki = _person(_look("huutaja"), ERKKI_FROM, Vector3(0, 0, 1))
	raili = _person(_look("raili"), RAILI_FROM, RAILI_AT - RAILI_FROM)
	raili.visible = false  # kahviossa kinkun luona, tulee kinkku-vaiheessa
	# Lappu ja kynä jokaiselle; pelaajan lappu on oma (ylärivi ympyröity).
	for x in SEATS:
		B.mesh(_G, B.boxm(Vector3(0.24, 0.006, 0.24)), Vector3(x, TABLE_Y + 0.003, 0.28), Color(0.98, 0.97, 0.9))
	slip = _build_slip()
	_G.add_child(slip)
	_props.append(slip)
	pencil_a = _pencil(0.075)  # puolikkaat: origo katkeamiskohdassa, kynä jatkuu +Y:hen
	pencil_b = _pencil(0.075)
	for i in 6:
		var ch := B.mesh(_G, B.boxm(Vector3(0.008, 0.004, 0.006)), Vector3.ZERO, Color(0.85, 0.7, 0.4) if i % 2 == 0 else Color(0.2, 0.3, 0.75))
		ch.visible = false
		_chips.append(ch)
	kinkku = build_kinkku()
	_G.add_child(kinkku)
	_props.append(kinkku)


func _look(id: String) -> Dictionary:
	for p: Dictionary in hall.PEOPLE:
		if p.id == id and p.has("look"):
			return p.look
	return MUMMO


func _person(look: Dictionary, at: Vector3, face: Vector3) -> Node3D:
	var c: Node3D = Looks.make(_G, look)
	c.position = at
	c.rotation.y = B.yaw_to(face)
	c.play("Idle", 0.0)
	_props.append(c)
	return c


## Istuva hahmo tuolilla x (bingo_game.gd: lantio istuimen kohdalle), kasvot lavalle.
func _sit(look: Dictionary, x: float) -> Node3D:
	var c := _person(look, Vector3(x, 0, ROW_Z), Vector3(0, 0, -1))
	c.play("Sitting_Idle", 0.0)
	c.anim.advance(0.01)
	var pelvis: Vector3 = c.bone_position("pelvis")
	c.position = Vector3(x, 0, ROW_Z) + Vector3(-pelvis.x, 0.05, 0.06 - pelvis.z)
	c.set_meta("seat", c.position)
	return c


## Puutuoli: istuin, selkänoja (+Z), neljä jalkaa. Tuolin etu -Z.
func _chair(at: Vector3) -> void:
	var wood := Color(0.45, 0.28, 0.16)
	B.mesh(_G, B.boxm(Vector3(0.45, 0.05, 0.42)), at + Vector3(0, 0.45, 0), wood)
	B.mesh(_G, B.boxm(Vector3(0.45, 0.45, 0.04)), at + Vector3(0, 0.7, 0.2), wood)
	for lx in [-0.19, 0.19]:
		for lz in [-0.17, 0.17]:
			B.mesh(_G, B.boxm(Vector3(0.04, 0.45, 0.04)), at + Vector3(lx, 0.22, lz), wood.darkened(0.2))


## Bingolappu: valkoinen kartonki, vihreä BINGO-otsake, 5×5 ruudukko ja punaiset ympyrät yläriviin. Paikallinen +Z =
## painettu puoli, koko 0,2 x 0,24 m (vähän oikeaa isompi, jotta lähikuvassa numerot erottuvat).
func _build_slip() -> Node3D:
	var g := Node3D.new()
	var w := 0.2
	B.mesh(g, B.boxm(Vector3(w, 0.24, 0.002)), Vector3.ZERO, Color(0.98, 0.97, 0.9))
	B.mesh(g, B.boxm(Vector3(w, 0.035, 0.003)), Vector3(0, 0.1, 0.0005), Color(0.15, 0.5, 0.25))
	var hdr := Label3D.new()
	hdr.text = "B I N G O"
	hdr.font_size = 40
	hdr.pixel_size = 0.0006
	hdr.modulate = Color(1, 1, 0.9)
	hdr.outline_size = 0
	hdr.position = Vector3(0, 0.1, 0.0025)
	g.add_child(hdr)
	var cell := w / 5.0
	for k in 6:
		B.mesh(g, B.boxm(Vector3(0.0015, 0.2, 0.0005)), Vector3(-w / 2.0 + k * cell, -0.018, 0.0012), Color(0.3, 0.3, 0.3))
		B.mesh(g, B.boxm(Vector3(w, 0.0015, 0.0005)), Vector3(0, 0.0825 - k * cell, 0.0012), Color(0.3, 0.3, 0.3))
	var nums := [ROW, ["3", "19", "40", "55", "71"], ["12", "28", "★", "47", "63"], ["9", "16", "33", "60", "74"], ["1", "25", "44", "49", "66"]]
	nums[2][2] = "37"
	for r in 5:
		for c in 5:
			var lb := Label3D.new()
			lb.text = nums[r][c]
			lb.font_size = 48
			lb.pixel_size = 0.0004
			lb.modulate = Color(0.1, 0.1, 0.12)
			lb.outline_size = 0
			lb.position = Vector3(-w / 2.0 + (c + 0.5) * cell, 0.0825 - (r + 0.5) * cell, 0.0032)
			lb.render_priority = 2
			g.add_child(lb)
	# Punaiset tussiympyrät ylärivissä (rengas kahdesta kaaresta ohuina laatikoina).
	for c in 5:
		var center := Vector3(-w / 2.0 + (c + 0.5) * cell, 0.0825 - 0.5 * cell, 0.002)
		for k in 14:
			var a := k * TAU / 14.0
			var seg := B.mesh(g, B.boxm(Vector3(0.0085, 0.0022, 0.0005)), center + Vector3(cos(a), sin(a), 0) * 0.0165, Color(0.85, 0.08, 0.06))
			seg.rotation.z = a + PI / 2.0
	return g


## Kynä Elvin kädessä: sininen kuusikulmainen runko, teroitettu puupää ja grafiitti. Pala on puolikas (katkeaa).
func _pencil(length: float) -> Node3D:
	var g := Node3D.new()
	_G.add_child(g)
	_props.append(g)
	B.mesh(g, B.cyl(0.0045, 0.0045, length, 6), Vector3(0, length / 2.0, 0), Color(0.15, 0.25, 0.7))
	return g


## Joulukinkku vadilla: kinkun runko yhtenä umpinaisena verkkona (pyöreä takapää, kapeneva koipi, litteä pohja), lasite
## yläpinnalla vaaleampi ja alapinnassa tumma, ristiviillot ja neilikat yläpinnassa, luu ja paperikrusidi kapeassa
## päässä, punainen rusetti, persiljaa vadilla. Solmun origo vadin pohjan keskellä; kinkun pituusakseli paikallinen X
## (luu -X:ssä), korkeus noin 0,2 m, pituus 0,46 m.
static func build_kinkku() -> Node3D:
	var g := Node3D.new()
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.92, 0.93, 0.95)
	plate.metallic = 0.6
	plate.roughness = 0.25
	var pm := MeshInstance3D.new()
	pm.mesh = B.cyl(0.3, 0.27, 0.025, 28)
	pm.material_override = plate
	pm.scale = Vector3(1.0, 1.0, 0.68)
	pm.position = Vector3(0, 0.0125, 0)
	g.add_child(pm)
	var rim := MeshInstance3D.new()
	rim.mesh = B.cyl(0.305, 0.305, 0.012, 28)
	rim.material_override = plate
	rim.scale = Vector3(1.0, 1.0, 0.68)
	rim.position = Vector3(0, 0.026, 0)
	g.add_child(rim)
	var inner := B.mesh(g, B.cyl(0.26, 0.26, 0.004, 28), Vector3(0, 0.032, 0), Color(0.97, 0.97, 0.98))
	inner.scale = Vector3(1.0, 1.0, 0.68)
	# Kinkun runko: profiili pituusakselin mukaan, poikkileikkaus ellipsi, pohja litistetty.
	var ham := MeshInstance3D.new()
	ham.mesh = _ham_mesh()
	var hm := StandardMaterial3D.new()
	hm.vertex_color_use_as_albedo = true
	hm.vertex_color_is_srgb = true
	hm.roughness = 0.28
	hm.clearcoat_enabled = true
	hm.clearcoat = 0.6
	ham.material_override = hm
	ham.position = Vector3(0.03, 0.034, 0)
	g.add_child(ham)
	# Ristiviillot ja neilikat yläpinnassa (vinot rivit kahteen suuntaan, risteyksissä neilikka).
	var score := Color(0.38, 0.17, 0.06)
	for i in range(-3, 4):
		for j in range(-2, 3):
			var u := (i + j) * 0.11
			var v := (i - j) * 0.33
			if absf(u) > 0.62 or absf(v) > 1.0:
				continue
			var p := ham.position + _ham_point(u, v, 1.003)
			var cl := B.mesh(g, B.sphere(0.006, 6), p, Color(0.16, 0.08, 0.04))
			cl.scale = Vector3(1.0, 0.7, 1.0)
			for d in [Vector2(0.11, 0.33), Vector2(0.11, -0.33)]:
				var q := ham.position + _ham_point(u + d.x * 0.5, v + d.y * 0.5, 1.004)
				var e := ham.position + _ham_point(u + d.x, v + d.y, 1.004)
				if absf(u + d.x) > 0.66 or absf(v + d.y) > 1.05:
					continue
				var seg := B.mesh(g, B.boxm(Vector3(0.004, 0.003, p.distance_to(e))), q, score)
				seg.look_at_from_position(q, e, (q - ham.position).normalized())
	# Luu ja paperikrusidi kapeassa päässä (-X), punainen rusetti krusidin juureen.
	var bone := B.mesh(g, B.cyl(0.018, 0.022, 0.09, 12), ham.position + Vector3(-0.27, 0.06, 0), Color(0.93, 0.88, 0.78), Vector3(0, 0, 90))
	bone.rotation.z = deg_to_rad(80.0)
	var frill := Node3D.new()
	frill.position = ham.position + Vector3(-0.31, 0.068, 0)
	frill.rotation.z = deg_to_rad(80.0)
	g.add_child(frill)
	B.mesh(frill, B.cyl(0.026, 0.024, 0.04, 14), Vector3.ZERO, Color(0.99, 0.99, 0.98))
	for k in 12:
		var a := k * TAU / 12.0
		var tip := B.mesh(frill, B.boxm(Vector3(0.012, 0.03, 0.004)), Vector3(cos(a) * 0.027, -0.03, sin(a) * 0.027), Color(0.99, 0.99, 0.98))
		tip.rotation.y = -a
		tip.rotation.z = 0.35
	var red := Color(0.8, 0.06, 0.08)
	B.mesh(frill, B.cyl(0.03, 0.03, 0.012, 14), Vector3(0, 0.026, 0), red)
	for sx in [-1.0, 1.0]:
		var loop := B.mesh(frill, B.sphere(0.022, 10), Vector3(0, 0.03, sx * 0.03), red)
		loop.scale = Vector3(0.45, 0.9, 1.0)
	# Persiljaa ja appelsiininviipaleita vadin reunalla.
	for k in 7:
		var a := k * 0.9 + 0.4
		var pp := Vector3(cos(a) * 0.23, 0.045, sin(a) * 0.15)
		if pp.x < -0.15:
			continue
		for m in 3:
			B.mesh(g, B.sphere(0.016, 6), pp + Vector3(m * 0.012 - 0.012, 0.004 * m, (m % 2) * 0.01), Color(0.22, 0.55, 0.2).darkened(0.1 * m))
	for k in 3:
		var o := B.mesh(g, B.cyl(0.032, 0.032, 0.008, 14), Vector3(0.05 + k * 0.07, 0.042, 0.165 - k * 0.005), Color(1.0, 0.6, 0.12))
		o.rotation.x = -0.3
	return g


## Kinkun pinnan piste: u -1..1 pituusakselilla (-1 = luupää), v -1..1 poikki yläpinnan yli (0 = selkä).
static func _ham_point(u: float, v: float, s := 1.0) -> Vector3:
	var a := v * PI * 0.5  # 0 = ylös
	return _ham_surf(u, a) * s


static func _ham_surf(u: float, a: float) -> Vector3:
	var prof := sqrt(maxf(0.0, 1.0 - u * u)) * (0.8 + 0.25 * u) + 0.18 * maxf(0.0, -u)  # takapää paksumpi, koipi kapenee
	var ry := 0.17 * prof
	var rz := 0.15 * prof
	var y := cos(a) * ry
	var z := sin(a) * rz
	y = maxf(y, -0.025)  # litteä pohja vadin päällä
	return Vector3(u * 0.23, y + 0.03, z)


static func _ham_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 28
	var na := 24
	var top := Color(0.82, 0.48, 0.2)
	var low := Color(0.5, 0.25, 0.1)
	var grid := []
	for i in nu + 1:
		var u := -1.0 + 2.0 * i / nu
		var ring := []
		for j in na + 1:
			var a := TAU * j / na
			ring.append(_ham_surf(clampf(u, -0.985, 0.985), a))
		grid.append(ring)
	var cen := Vector3(0, 0.03, 0)
	for i in nu:
		for j in na:
			var q := [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var p0: Vector3 = q[tri[0]]
				var p1: Vector3 = q[tri[1]]
				var p2: Vector3 = q[tri[2]]
				var n := (p1 - p0).cross(p2 - p0).normalized()
				var mid := (p0 + p1 + p2) / 3.0
				if n.dot(mid - cen) > 0.0:  # kiertosuunta normaalin mukaan: Godotin etupinta myötäpäivään ulkoa katsoen
					var tmp := p1
					p1 = p2
					p2 = tmp
				n = (p1 - p0).cross(p2 - p0).normalized() * -1.0  # ulospäin
				for p: Vector3 in [p0, p1, p2]:
					var k := clampf((p.y + 0.0) / 0.2, 0.0, 1.0)
					st.set_color(low.lerp(top, k))
					st.set_normal((p - cen).normalized().lerp(n, 0.4).normalized())
					st.add_vertex(p)
	# Päätykannet (umpinainen verkko molemmista päistä).
	for i in [0, nu]:
		var c0 := Vector3(grid[i][0].x, 0.03, 0)
		for j in na:
			var p1: Vector3 = grid[i][j]
			var p2: Vector3 = grid[i][j + 1]
			var n := (p1 - c0).cross(p2 - c0).normalized()
			var out := Vector3(-1 if i == 0 else 1, 0, 0)
			if n.dot(out) > 0.0:
				var tmp := p1
				p1 = p2
				p2 = tmp
			for p: Vector3 in [c0, p1, p2]:
				st.set_color(low)
				st.set_normal(out)
				st.add_vertex(p)
	return st.commit()


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	for c in [me, erkki, raili] + row:
		c.clear_ik()
		c.set_override("spine_01", Vector3.RIGHT, 0.0)
		c.set_override("spine_03", Vector3.RIGHT, 0.0)
		c.set_override("neck_01", Vector3.RIGHT, 0.0)
		c.set_override("Head", Vector3.UP, 0.0)
	match p:
		"bingo":
			_story = "Tiistain bingo, seuraintalo. Pallo numero 68."
			Sfx.play("alert", -6.0, 1.2)
		"tarkistus":
			_story = ""
			erkki.position = ERKKI_FROM
		"kinkku":
			_story = ""
			raili.visible = true
			slip_holder = "erkki"
			snapped = true
			kinkku_holder = "raili"
			erkki.position = ERKKI_AT
			erkki.rotation.y = B.yaw_to(Vector3(-0.3, 0, 1))
		"mummot":
			_story = ""
			kinkku_holder = "me"
			erkki.position = ERKKI_AT
			raili.visible = true
			raili.position = Vector3(3.25, 0, -0.35)
			raili.rotation.y = B.yaw_to(ME_AT - raili.position)
			raili.play("Idle", 0.0)
		"otsikko":
			_story = ""
			kinkku_holder = "me"
			erkki.position = Vector3(3.15, 0, 2.0)
			erkki.rotation.y = B.yaw_to(ME_AT - erkki.position)
			raili.visible = true
			raili.position = Vector3(1.75, 0, 2.0)
			raili.play("Idle", 0.0)
			turned_away = true
			for i in 3:
				_stand_up(row[i], 1.0)
			Sfx.play("win", -6.0, 0.95)


func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("interact") and (phase != "bingo" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"bingo":
			_step_bingo()
		"tarkistus":
			_step_tarkistus()
		"kinkku":
			_step_kinkku()
		"mummot":
			_step_mummot()
		"otsikko":
			_step_otsikko()
	_place_props()
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
	if is_instance_valid(hall):
		hall.stage(false)
	for nd in _was_visible:
		if is_instance_valid(nd):
			(nd as Node3D).visible = _was_visible[nd]
	finished.emit()
	queue_free()


## Pelaaja seisomaan pöydän päähän (k 0..1): istumasta Idleen tuolin vieressä.
func _me_stand(face: Vector3) -> void:
	me.play("Idle", 0.15)
	me.position = ME_AT
	me.rotation.y = B.yaw_to(face)


func _stand_up(c: Node3D, k: float) -> void:
	if k <= 0.0:
		return
	var seat: Vector3 = c.get_meta("seat")
	c.play("Idle", 0.2)
	c.position = Vector3(seat.x, 0.0, ROW_Z + 0.5)  # tuolin taakse


func _step_bingo() -> void:
	# 0,3 s pelaaja ponnahtaa ylös, lappu ylhäällä; mummojen päät kääntyvät 0,7-1,4 s porrastetusti; Erkki 2,6 s.
	if _t > 0.3:
		_me_stand(Vector3(-0.2, 0, -1))
		var up := me.to_global(me.bone_position("upperarm_r")) + me.global_basis * Vector3(0.05, 0.55, -0.12)
		_reach(me, "r", up, _ease(clampf((_t - 0.3) / 0.3, 0.0, 1.0)))
		if _t < 2.4:
			_bub[me] = "BINGO!"
		if not me.has_meta("huusi"):
			me.set_meta("huusi", true)
			Sfx.play("grunt", -2.0, 1.25)
	for i in row.size():
		var k := _ease(clampf((_t - 0.7 - i * 0.14) / 0.18, 0.0, 1.0))
		_glare(row[i], k)
	_hand_on_table(elvi, 1.0)
	if _t > 2.6:
		_bub.erase(me)
		_bub[erkki] = "...Tarkistetaan."
		erkki.position = Vector3(1.2, 0.5, -3.9)
		erkki.rotation.y = B.yaw_to(ME_AT - erkki.position)
	else:
		erkki.position = Vector3(1.2, 0.5, -3.9)
		erkki.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	# Kuva pöydän edestä (lavan puolelta): mummojen rivi ja pelaaja pöydän päässä, kasvot kameraan.
	var look := _H(0.5, 1.3, ROW_Z)
	var eye := _H(1.0, 1.75, -2.6)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 6.0))


func _step_tarkistus() -> void:
	_me_stand(Vector3(0.05, 0, -1))
	for i in row.size():
		_glare(row[i], 1.0)
	_grip_pencil(elvi, _ease(clampf(_t / 0.6, 0.0, 1.0)))
	# 0-2 s Erkki kävelee lavalta pelaajan eteen, 2-2,6 s ottaa lapun, 2,6-6 lukee (lähikuva), 6,0 "Se on bingo",
	# 6,9 Elvin kynä katkeaa (lähikuva Elvistä).
	var walk := clampf(_t / 2.0, 0.0, 1.0)
	erkki.position = ERKKI_FROM.lerp(ERKKI_AT, walk)
	erkki.rotation.y = B.yaw_to(ERKKI_AT - ERKKI_FROM) if walk < 1.0 else B.yaw_to(ME_AT - ERKKI_AT)
	erkki.play("Walk" if walk < 1.0 else "Idle", 0.2)
	var hold := erkki.to_global(erkki.bone_position("spine_03")) + erkki.global_basis * Vector3(0.0, 0.02, -0.34)
	if _t < 2.0:
		slip_holder = "me"
		var up := me.to_global(me.bone_position("upperarm_r")) + me.global_basis * Vector3(0.05, 0.45, -0.15)
		_reach(me, "r", up, 1.0)
	elif _t < 2.6:
		var k := _ease(clampf((_t - 2.0) / 0.5, 0.0, 1.0))
		slip_holder = "me" if _t < 2.35 else "erkki"
		var give := me.to_global(me.bone_position("upperarm_r")) + me.global_basis * Vector3(0.0, -0.05, -0.4)
		var up := me.to_global(me.bone_position("upperarm_r")) + me.global_basis * Vector3(0.05, 0.45, -0.15)
		_reach(me, "r", up.lerp(give, k), 1.0 - clampf((_t - 2.35) / 0.25, 0.0, 1.0))
		_reach(erkki, "r", give, k)
	else:
		slip_holder = "erkki"
		_reach(erkki, "r", hold + erkki.global_basis * Vector3(0.06, 0, 0), 1.0)
		_reach(erkki, "l", hold + erkki.global_basis * Vector3(-0.07, -0.04, 0), 1.0)
	if _t > 2.7 and _t < 6.0:
		var n := clampi(int((_t - 2.7) / 0.6), 0, 4)
		var said := ["B seittemän...", "I kakskytkaks...", "N vapaa...", "G viiskytyks...", "O kuuskytkaheksan."]
		_bub[erkki] = said[n]
		reading = n
	elif _t >= 6.0 and _t < 6.8:
		_bub[erkki] = "..."
	elif _t >= 6.8:
		_bub[erkki] = "Se on bingo."
	if _t >= 7.0 and not snapped:
		snapped = true
		Sfx.play("punch", -6.0, 2.4)
	if _t < 2.6:
		var look := _H(2.0, 1.25, 0.2)
		var eye := _H(4.5, 1.65, -1.6)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.2))
	elif _t < 6.8:
		# Erkin olan yli lappuun: ympyröity ylärivi ja numerot, pelaajan kasvot taustalla.
		var sp := slip.global_position
		var eye := slip.to_global(Vector3(0.3, 0.2, 0.46))  # Erkin oikean olan yli (lapun +Z = Erkkiin päin)
		_cam_at(eye, sp + Vector3(0, 0.01, 0), _fov_w(eye.distance_to(sp), 0.36))
	else:
		# Elvi lähikuvassa: kynä katkeaa kädessä.
		var look := _H(0.0, 0.98, ROW_Z - 0.2)
		var eye := _H(-0.55, 1.35, -0.55)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 1.3))


var reading := -1  # testi lukee: monesko numero luetaan


func _step_kinkku() -> void:
	# Raili kantaa kinkun kahviosta (0-2,6 s), Erkki julistaa, kinkku syliin 3,0-3,6, paino notkauttaa 3,6-4,3 s,
	# pelaaja kääntyy kameraan 4,6 s.
	for i in row.size():
		_glare(row[i], 1.0)
	_reach(erkki, "r", erkki.to_global(erkki.bone_position("upperarm_r")) + erkki.global_basis * Vector3(0.1, 0.55, -0.1), 1.0)
	var hold := erkki.to_global(erkki.bone_position("spine_03")) + erkki.global_basis * Vector3(-0.07, -0.04, -0.34)
	_reach(erkki, "l", hold, 1.0)
	if _t > 0.3 and _t < 3.0:
		_bub[erkki] = "JÄTTIPOTTI! Joulukinkku, seittemän kiloa!"
	var walk := clampf(_t / 2.6, 0.0, 1.0)
	raili.position = RAILI_FROM.lerp(RAILI_AT, walk)
	raili.rotation.y = B.yaw_to(RAILI_AT - RAILI_FROM) if walk < 1.0 else B.yaw_to(ME_AT - RAILI_AT)
	raili.play("Walk" if walk < 1.0 else "Idle", 0.2)
	var me_face := (RAILI_AT - ME_AT).normalized()
	if _t > 4.6:
		me_face = me_face.lerp(Vector3(0.75, 0, 1).normalized(), _ease(clampf((_t - 4.6) / 0.6, 0.0, 1.0))).normalized()
	_me_stand(me_face)
	var tray_r := raili.to_global(raili.bone_position("spine_03")) + raili.global_basis * Vector3(0, -0.2, -0.36)
	var tray_m := me.to_global(me.bone_position("spine_03")) + me.global_basis * Vector3(0, -0.22, -0.33)
	var sag := _ease(clampf((_t - 3.6) / 0.35, 0.0, 1.0)) * (1.0 - 0.6 * _ease(clampf((_t - 4.0) / 0.5, 0.0, 1.0)))
	if _t < 3.0:
		kinkku_holder = "raili"
		_tray(raili, tray_r, 1.0)
		_reach(me, "r", tray_m, _ease(clampf((_t - 2.4) / 0.5, 0.0, 1.0)))
	elif _t < 3.6:
		var k := _ease(clampf((_t - 3.0) / 0.6, 0.0, 1.0))
		kinkku_holder = "raili" if k < 0.5 else "me"
		var mid := tray_r.lerp(tray_m, k)
		_tray(raili, mid, 1.0 - clampf((k - 0.5) * 2.0, 0.0, 1.0))
		_tray(me, mid, 1.0)
	else:
		kinkku_holder = "me"
		_tray(me, tray_m + Vector3(0, -0.08 * sag, 0), 1.0)
		me.set_override("spine_01", Vector3.RIGHT, -0.22 * sag)
		raili.play("Idle", 0.2)
		if not me.has_meta("raskas"):
			me.set_meta("raskas", true)
			Sfx.play("groan", -6.0, 1.1)
		if _t > 3.8 and _t < 5.2:
			_bub[me] = "Ooh... Painava."
		elif _t >= 5.2:
			_bub.erase(me)
			_bub[raili] = "Ja hyvää se on. Mää paistoin itte."
	_kinkku_tray_pos = tray_m
	if _t < 3.6:
		var look := _H(2.25, 1.15, 1.25)
		var eye := _H(4.2, 1.55, 3.0)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 2.8))
	else:
		# Kinkku sylissä: pelaaja kääntyy kameraan, kinkku ruudun keskellä isona.
		var look := _H(2.5, 1.32, 1.05)
		var eye := _H(3.75, 1.55, 2.95)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 2.3))


var _kinkku_tray_pos := Vector3.ZERO


func _step_mummot() -> void:
	# Mummot nousevat tuoliensa taakse porrastetusti (0-2 s), kädet puuskaan, katse pelaajaan; repliikit vuorotellen;
	# Tauno lysähtää; 7,2 s mummot kääntävät selkänsä yhtä aikaa: "Hmph!"
	_me_stand(Vector3(-1, 0, 0.05))
	var tray_m := me.to_global(me.bone_position("spine_03")) + me.global_basis * Vector3(0, -0.24, -0.33)
	_tray(me, tray_m, 1.0)
	me.set_override("spine_01", Vector3.RIGHT, -0.08)
	_reach(erkki, "l", erkki.to_global(erkki.bone_position("spine_03")) + erkki.global_basis * Vector3(-0.07, -0.04, -0.34), 1.0)
	_reach(erkki, "r", erkki.to_global(erkki.bone_position("spine_03")) + erkki.global_basis * Vector3(0.07, -0.02, -0.34), 1.0)
	for i in 3:
		var c := row[i]
		var k := clampf((_t - 0.3 - i * 0.5) / 0.3, 0.0, 1.0)
		if k <= 0.0:
			_glare(c, 1.0)
			continue
		_stand_up(c, k)
		var to_me := ME_AT - c.position
		to_me.y = 0.0
		var away := Vector3(-1, 0, 0.15).normalized()
		var turn := _ease(clampf((_t - 7.2) / 0.35, 0.0, 1.0))
		turned_away = turn > 0.5
		c.rotation.y = B.yaw_to(to_me.normalized().lerp(away, turn).normalized())
		_arms_crossed(c)
		c.set_override("neck_01", Vector3.RIGHT, -0.08)
	# Tauno jää istumaan ja lysähtää.
	tauno.set_override("spine_03", Vector3.RIGHT, -0.25 * _ease(clampf((_t - 5.0) / 0.6, 0.0, 1.0)))
	var lines := [[1.0, 2.6, elvi, "Kolkytkaks vuotta mää oon tullu tiistaisin."], [2.6, 4.1, aili, "Eikä se ees asu Saloisissa."],
		[4.1, 5.5, hilkka, "Me muistetaan tää. Joka tiistai."], [5.5, 7.1, tauno, "Joka viikko sama numero puuttuu..."]]
	for ln: Array in lines:
		if _t >= ln[0] and _t < ln[1]:
			_bub[ln[2]] = ln[3]
		else:
			_bub.erase(ln[2])
	if _t >= 7.25:
		for i in 3:
			_bub[row[i]] = "Hmph!"
		if not me.has_meta("hmph"):
			me.set_meta("hmph", true)
			Sfx.play("cloth", -4.0, 0.8)
	# Pelaajan olan takaa mummojen riviin: kasvot kameraan, pelaajan olka ja kinkku oikeassa reunassa.
	# Kuva salin ovelta päin vinosti: mummot puoliksi kasvot kameraan, pelaaja kinkkuineen oikeassa reunassa.
	var look := _H(0.0, 1.25, 1.2)
	var eye := _H(0.9, 1.7, 4.7)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 5.6))


func _step_otsikko() -> void:
	_me_stand(Vector3(0.15, 0, -1))
	# Kinkku pään yli kahdella kädellä.
	var lift := _ease(clampf(_t / 0.8, 0.0, 1.0))
	var over := me.to_global(me.bone_position("Head")) + me.global_basis * Vector3(0, 0.32, -0.12)
	var chest := me.to_global(me.bone_position("spine_03")) + me.global_basis * Vector3(0, -0.24, -0.33)
	_tray(me, chest.lerp(over, lift), 1.0)
	_kinkku_tray_pos = chest.lerp(over, lift)
	for i in 3:
		var c := row[i]
		c.rotation.y = B.yaw_to(Vector3(-1, 0, 0.15))
		_arms_crossed(c)
	tauno.set_override("spine_03", Vector3.RIGHT, -0.25)
	_clap(raili, _t * 6.0)
	raili.rotation.y = B.yaw_to(ME_AT - raili.position)
	var look := _H(0.7, 1.2, 1.0)
	var eye := _H(1.6, 2.0, -2.6)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 6.6))


# --- Liike ---------------------------------------------------------------------------

func _reach(c: Node3D, side: String, target: Vector3, k: float) -> void:
	if k <= 0.0:
		return
	var sh: Vector3 = c.bone_position("upperarm_" + side)
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.08, -0.5, 0.0)
	c.set_ik("arm_" + side, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, rest.lerp(c.to_local(target), k),
		sh + Vector3(s * 0.5, -0.35, 0.15))


## Vati kahdella kädellä: kämmenet vadin reunojen alla (center = vadin pohjan keskikohta).
func _tray(c: Node3D, center: Vector3, k: float) -> void:
	var side := c.global_basis.x
	for sd in ["r", "l"]:
		var s := signf(c.bone_position("upperarm_" + sd).x)
		_reach(c, sd, center + side * s * 0.22 + Vector3(0, -0.015, 0), k)
		c.set_open_hand(sd, k)


## Mulkoilu: pää kääntyy pelaajaa kohti (k 0..1).
func _glare(c: Node3D, k: float) -> void:
	var to := ME_AT - c.position
	var yaw := wrapf(atan2(-to.x, -to.z) - c.rotation.y, -PI, PI)
	c.set_override("Head", Vector3.UP, clampf(yaw, -1.3, 1.3) * 0.75 * k)
	c.set_override("spine_03", Vector3.UP, clampf(yaw, -1.3, 1.3) * 0.3 * k)


## Elvi puristaa kynää kahdella kädellä rinnan edessä (katkaisee sen 7,0 s); katkettua kädet erkanevat hieman.
func _grip_pencil(c: Node3D, k: float) -> void:
	var chest := c.to_global(c.bone_position("spine_03")) + c.global_basis * Vector3(0, -0.12, -0.3)
	var apart := 0.075 + (0.025 if snapped else 0.0)
	for sd in ["r", "l"]:
		var s := signf(c.bone_position("upperarm_" + sd).x)
		_reach(c, sd, chest + c.global_basis.x * s * apart, k)


func _hand_on_table(c: Node3D, k: float) -> void:
	_reach(c, "r", _H(c.position.x + 0.1, TABLE_Y + 0.03, 0.42), k)


## Kädet puuskassa: kummankin käden kämmen vastakkaisen kyynärpään kohdalle rinnan edessä.
func _arms_crossed(c: Node3D) -> void:
	for sd in ["r", "l"]:
		var sh: Vector3 = c.bone_position("upperarm_" + sd)
		var s := signf(sh.x) if sh.x != 0.0 else 1.0
		var tgt := Vector3(-s * 0.1, sh.y - 0.27 + (0.03 if sd == "r" else 0.0), sh.z - 0.2)
		c.set_ik("arm_" + sd, "upperarm_" + sd, "lowerarm_" + sd, "hand_" + sd, tgt, sh + Vector3(s * 0.5, -0.45, -0.1))


func _clap(c: Node3D, ph: float) -> void:
	var gap := 0.03 + 0.08 * absf(sin(ph))
	for sd in ["r", "l"]:
		var sh: Vector3 = c.bone_position("upperarm_" + sd)
		var s := signf(sh.x) if sh.x != 0.0 else 1.0
		var mid := Vector3(0, sh.y - 0.05, sh.z - 0.3)
		c.set_ik("arm_" + sd, "upperarm_" + sd, "lowerarm_" + sd, "hand_" + sd, mid + Vector3(s * gap, 0, 0), sh + Vector3(s * 0.5, -0.35, 0.05))
		c.set_open_hand(sd, 1.0)


## Lappu, kynä ja kinkku käsissä joka ruutu.
func _place_props() -> void:
	# Lappu: pelaajan kädessä painettu puoli eteen, Erkin käsissä painettu puoli Erkkiin päin.
	match slip_holder:
		"me":
			if phase == "bingo" and _t <= 0.3:
				slip.position = Vector3(2.0 - 0.6, TABLE_Y + 0.004, 0.3)
				slip.rotation = Vector3(-PI / 2.0, 0, 0)
			else:
				slip.global_position = _hand(me, "r") + Vector3(0, 0.1, 0)
				slip.global_basis = me.global_basis * Basis(Vector3.UP, PI)
		"erkki":
			var h := (_hand(erkki, "r") + _hand(erkki, "l")) / 2.0 if phase == "tarkistus" and _t >= 2.6 else _hand(erkki, "r")
			slip.global_position = h + Vector3(0, 0.07, 0)
			slip.global_basis = erkki.global_basis * Basis(Vector3.RIGHT, -0.35)
	# Kynä: bingo-vaiheessa pöydällä Elvin käden vieressä, tarkistuksessa Elvin kahden käden välissä rinnan edessä
	# (puristaa sitä lukemisen ajan), 7,0 s katkeaa: puolikkaat taittuvat alas, lastuja lentää.
	var side := elvi.global_basis.x
	var fwd := -elvi.global_basis.z
	if phase != "bingo" and phase != "tarkistus":  # katkennut kynä jää pöydälle Elvin lapun viereen
		pencil_a.global_basis = Basis(Vector3.UP, 0.4) * Basis(Vector3(0, 0, 1), -PI / 2.0)
		pencil_b.global_basis = Basis(Vector3.UP, 2.2) * Basis(Vector3(0, 0, 1), -PI / 2.0)
		pencil_a.global_position = _H(elvi.position.x + 0.05, TABLE_Y + 0.006, 0.42)
		pencil_b.global_position = _H(elvi.position.x + 0.2, TABLE_Y + 0.006, 0.38)
		for ch in _chips:
			ch.visible = false
	elif phase == "bingo":
		var on := _H(elvi.position.x + 0.12, TABLE_Y + 0.006, 0.36)
		pencil_a.global_basis = Basis(Vector3(0, 0, 1), -PI / 2.0)
		pencil_b.global_basis = Basis(Vector3(0, 0, 1), PI / 2.0)
		pencil_a.global_position = on
		pencil_b.global_position = on
	else:
		var c := (_hand(elvi, "r") + _hand(elvi, "l")) / 2.0
		var age := (_t - 7.0) if phase == "tarkistus" else 9.0
		var bend := 0.0 if not snapped else clampf(age / 0.12, 0.0, 1.0) * 0.75
		var gap := 0.0 if not snapped else clampf(age / 0.12, 0.0, 1.0) * 0.012
		for k in 2:
			var pc: Node3D = [pencil_a, pencil_b][k]
			var sgn := 1.0 if k == 0 else -1.0
			var y := (side * sgn).rotated(fwd, -sgn * bend).normalized()
			var z := fwd
			var x := y.cross(z).normalized()
			pc.global_basis = Basis(x, y, x.cross(y)).orthonormalized()
			pc.global_position = c + side * sgn * gap
		for i in _chips.size():
			var ch := _chips[i]
			ch.visible = snapped and age < 1.0
			if ch.visible:
				var d := Vector3(cos(i * 1.7) * 0.3, 0.5 + 0.15 * (i % 3), sin(i * 1.7) * 0.3) + fwd * 0.2
				var a2 := clampf(age, 0.0, 1.0)
				ch.global_position = c + d * a2 + Vector3(0, -1.6 * a2 * a2, 0)
				ch.rotation = Vector3(age * 9.0 + i, age * 7.0, 0)
	# Kinkku: kahviossa piilossa, kantajan vadilla.
	match kinkku_holder:
		"kahvio":
			kinkku.visible = false
		"raili":
			kinkku.visible = true
			var c := (_hand(raili, "r") + _hand(raili, "l")) / 2.0
			kinkku.global_position = c + Vector3(0, 0.0, 0)
			kinkku.global_basis = raili.global_basis
		"me":
			kinkku.visible = true
			var c := (_hand(me, "r") + _hand(me, "l")) / 2.0
			kinkku.global_position = c
			kinkku.global_basis = me.global_basis


## Vadin reunan etäisyys kannattelevasta kädestä (testi mittaa: kädet vadin alla).
func tray_gap(c: Node3D) -> float:
	var worst := 0.0
	for sd in ["r", "l"]:
		var hl := kinkku.to_local(_hand(c, sd))
		worst = maxf(worst, Vector2(maxf(0.0, absf(hl.x) - 0.31), hl.y).length())
	return worst


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
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.08, 0.04, 0.02, 0.22 * a))
		var y := vs.y * 0.22
		_draw_icon(Vector2(vs.x / 2.0, y - 84.0), a)
		var title := "BINGON JÄTTIPOTTI"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.2, 0.06, 0.04, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(1.0, 0.82, 0.4, a))
		var sr := Rect2(vs.x / 2.0 - 440, vs.y - 158.0, 880, 84)
		_ui.draw_rect(sr, Color(0.08, 0.04, 0.03, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Joulukinkku seuraintalon bingosta.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(1.0, 0.85, 0.6, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Mummot ei anna ikinä anteeks.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.85, a))


## Kinkku vadilla: ruskea kinkku ristiviilloin, luu ja krusidi, punainen rusetti.
func _draw_icon(c: Vector2, a: float) -> void:
	_ui.draw_set_transform(c + Vector2(0, 18), 0.0, Vector2(1.0, 0.32))
	_ui.draw_circle(Vector2.ZERO, 46.0, Color(0.9, 0.9, 0.93, a))
	_ui.draw_set_transform(c + Vector2(6, 0), 0.0, Vector2(1.0, 0.62))
	_ui.draw_circle(Vector2.ZERO, 34.0, Color(0.72, 0.4, 0.16, a))
	_ui.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in range(-2, 3):
		_ui.draw_line(c + Vector2(k * 12 - 10, -18), c + Vector2(k * 12 + 10, 16), Color(0.4, 0.18, 0.06, a), 2.0)
		_ui.draw_line(c + Vector2(k * 12 + 10, -18), c + Vector2(k * 12 - 10, 16), Color(0.4, 0.18, 0.06, a), 2.0)
	_ui.draw_rect(Rect2(c + Vector2(-44, -6), Vector2(16, 9)), Color(0.95, 0.9, 0.8, a))
	_ui.draw_rect(Rect2(c + Vector2(-56, -9), Vector2(13, 15)), Color(1, 1, 1, a))
	_ui.draw_circle(c + Vector2(-31, -2), 6.0, Color(0.85, 0.08, 0.08, a))
