extends CanvasLayer
## Legendaarinen hetki "hanhikiven_rajakivi" (Hanhikiven rajakivi): kun Hanhikiveä tutkitaan ensimmäistä kertaa
## molempien vihjeiden jälkeen (main.gd _hanhikivi_kivi), hetki lavastetaan Pyhäjoen Koskipuistossa
## (retki_hanhikivi.gd, taskukohtaus). Sävy on salaperäinen ja hymyilevä: mitään ei todisteta. Vaiheet:
##   kivi     pelaaja kyykistyy kiven juurelle ja painaa kämmenen kylkeen: "Kivi on kuin on ollut."
##   kuoppa   pelaaja kävelee rantaan kiven muotoiselle painaumalle (harva ruoho, reunakivet). Kalastaja tulee viereen:
##            "Mun isä sano, ettei kiveen kosketa." – "Kuka sen tänne toi?" – "Ei kukaan tiedä."
##   hanhet   (huipennus) hanhiaura lentää joen yli, yksi hanhi irtoaa, liukuu alas ja laskeutuu Hanhikiven päälle,
##            taittaa siipensä ja huutaa. "Sanotaan, että sama hanhi on Pyhäjoen vaakunassa."
##   kuski    taksikuski tulee katsomaan: "Ei oo totta." Kalastaja käsi rinnalla: "Kukaan ei voi todistaa mitään."
##            Hanhi lähtee joen yli, ja sulka leijuu kiven päälle (jää sinne). "...Ja hyvä niin."
##   otsikko  HANHIKIVEN RAJAKIVI: kolme miestä kivellä, aura kaukana puiden yllä.
## Kehys: retki_hanhikivi.gd:n paikallinen kehys: -Z joki ja Hourunkoski, +Z tie ja taksi, maa y 0. Hahmojen etu -Z
## (Looks), hanhen etu myös -Z. Oikea pelaaja, kalastaja ja taksikuski piiloon kohtauksen ajaksi (kopiot näyttelevät).
## Kalastaja muistelee myöhemmin (MUISTO, retki_hanhikivi.gd "onkija").

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")

const RATE := 22050.0
const DUR := {"kivi": 6.0, "kuoppa": 7.6, "hanhet": 9.4, "kuski": 9.6, "otsikko": 6.2}
const ORDER := ["kivi", "kuoppa", "hanhet", "kuski", "otsikko"]

const STONE := Vector3(4.0, 0, -3.4)  # retki_hanhikivi.gd sx, sz
const HOLLOW := Vector3(9.0, 0, -3.35)  # retki_hanhikivi.gd _hollow
const ME_CROUCH := Vector2(6.32, -3.62)  # kiven itäpäässä, kasvot länteen (kiveen); laatta jää lännen puolelle
const ME_HOLLOW := Vector2(7.35, -1.95)
const ME_LOOK := Vector2(7.0, -1.75)
const FISH_FROM := Vector2(11.2, 0.6)
const FISH_AT := Vector2(8.55, -1.55)
const KUSKI_FROM := Vector2(3.6, 3.0)
const KUSKI_AT := Vector2(5.75, -0.55)
const GOOSE_S := 1.2  # hanhi hieman oikeaa isompi, jotta se näkyy kivellä
## Kalastaja muistelee hetkeä myöhemmin (retki_hanhikivi.gd "onkija").
const MUISTO := ["Muistatko sen hanhen? Istu kivellä kuin omallaan. En oo kertonu kenellekään. Ei kukaan uskois.",
	"Mää tuun tähän joka ilta. Hanhia menee yli, mutta yksikään ei oo enää laskeutunu.",
	"Se sulka on vieläkin kiven päällä. Tuuli ei vie sitä. En tiedä miksi.",
	"Kuski kysy multa jälkeenpäin, että näinkö mää saman. Mää sanoin, etten mää nähny mitään. Hyvä niin."]

var interior: Node3D  # retki_hanhikivi.gd
var _was_visible := {}

var phase := ""
var _t := 0.0
var _cam: Camera3D
var _ui: Control
var _keys: Node
var _story := ""
var _bub := {}
var _once := {}
var _props: Array[Node3D] = []
var me: Node3D
var fisher: Node3D
var kuski: Node3D
var goose: Node3D  # laskeutuva hanhi
var flock: Array[Node3D] = []  # aura (ilman laskeutujaa)
var feather: Node3D
var top := Vector3.ZERO  # kiven korkein kohta (laskettu verkosta), hanhen jalat ja sulka tähän
var _fill: OmniLight3D
var _audio: AudioStreamPlayer
var _honk: AudioStreamWAV
var _look := Vector3.ZERO  # pehmennetty katsepiste (hanhien seuranta)
var _honk_t := -1.0  # nokka auki huudon ajan
var goose_landed := false  # testi lukee
var feather_on_stone := false


func _ready() -> void:
	layer = 6
	_cam = Camera3D.new()
	interior.add_child(_cam)
	_props.append(_cam)
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
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_honk = _honk_wav()
	for nd in [interior.walker, interior._fisher, interior.kuski, interior.feather]:
		if nd != null:
			_was_visible[nd] = (nd as Node3D).visible
			(nd as Node3D).visible = false
	interior._bubble.text = ""
	top = stone_top(interior)
	_build()
	_begin("kivi")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	me = Looks.make(interior, Looks.player())
	Looks.add_cap(me)
	fisher = Looks.make(interior, interior.FISHER_LOOK)
	kuski = Looks.make(interior, Looks.TAXI_DRIVER)
	for c in [me, fisher, kuski]:
		_props.append(c)
	goose = build_goose(interior)
	goose.scale = Vector3.ONE * GOOSE_S
	_props.append(goose)
	for i in 8:
		var g := build_goose(interior)
		g.scale = Vector3.ONE * GOOSE_S
		_props.append(g)
		flock.append(g)
		goose_pose(g, "fly", 0.0, i * 0.37)
	feather = build_feather(interior)
	_props.append(feather)
	feather.visible = false
	_fill = OmniLight3D.new()
	interior.add_child(_fill)
	_props.append(_fill)
	_fill.light_color = Color(1.0, 0.92, 0.78)
	_fill.light_energy = 0.7
	_fill.omni_range = 7.0


## Kiven korkein kohta retkikohtauksen kehyksessä: pystysäde kiven verkon kolmioihin keskustan lähellä (sama kohta
## hanhelle ja sulalle). retki_hanhikivi.gd käyttää tätä myös sulan pysyvään paikkaan.
static func stone_top(r: Node3D) -> Vector3:
	var bm: MeshInstance3D = r.boulder
	var faces: PackedVector3Array = bm.mesh.get_faces()
	var xf: Transform3D = bm.transform
	var best := Vector3(bm.position.x, -1.0, bm.position.z)
	for ox in [-0.3, 0.0, 0.3]:
		for oz in [-0.2, 0.0, 0.2]:
			var o := Vector3(bm.position.x + ox, 5.0, bm.position.z + oz)
			for i in range(0, faces.size(), 3):
				var hit = Geometry3D.ray_intersects_triangle(o, Vector3.DOWN, xf * faces[i], xf * faces[i + 1], xf * faces[i + 2])
				if hit != null and (hit as Vector3).y > best.y:
					best = hit
	return best


## Kiven kyljen pinta pelaajan kämmenelle: vaakasäde pisteestä `from` kohti kiven keskustaa, lähin osuma.
static func stone_side(r: Node3D, from: Vector3) -> Vector3:
	var bm: MeshInstance3D = r.boulder
	var faces: PackedVector3Array = bm.mesh.get_faces()
	var xf: Transform3D = bm.transform
	var dir := Vector3(bm.position.x - from.x, 0, bm.position.z - from.z).normalized()
	var best := from
	var bd := 1e9
	for i in range(0, faces.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(from, dir, xf * faces[i], xf * faces[i + 1], xf * faces[i + 2])
		if hit != null and from.distance_to(hit) < bd:
			bd = from.distance_to(hit)
			best = hit
	return best


## Merihanhi (n. 0,8 m, etu -Z, juuri vartalon keskellä): harmaanruskea vartalo, vaalea vatsa ja valkoinen peräalus,
## selän ja kylkien höyhenrivit vaaleine reunoineen, kaula ja pää, oranssi nokka vaalealla kynnellä, silmät,
## vaaleanpunaiset jalat räpylöineen. Siivet kahtena nivelenä (käsivarsi ja kämmen, käsisulat viuhkana) lennossa,
## ja levossa taitetut siivet kyljillä (vaihdetaan näkyvyydellä). Osat metassa "parts" (goose_pose).
static func build_goose(parent: Node3D) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	var grey := Color(0.5, 0.46, 0.4)
	var dark := Color(0.36, 0.32, 0.28)
	var pale := Color(0.84, 0.81, 0.74)
	var edge := Color(0.78, 0.74, 0.66)
	var body := Node3D.new()  # vartalo kallistuu (lento, laskeutuminen)
	g.add_child(body)
	var b := B.mesh(body, B.sphere(0.2, 18), Vector3.ZERO, grey)
	b.scale = Vector3(0.78, 0.66, 1.42)
	var belly := B.mesh(body, B.sphere(0.19, 16), Vector3(0, -0.035, 0.02), pale)
	belly.scale = Vector3(0.72, 0.56, 1.25)
	var under := B.mesh(body, B.sphere(0.08, 12), Vector3(0, -0.04, 0.24), Color(0.96, 0.95, 0.92))
	under.scale = Vector3(0.9, 0.7, 1.1)
	var back := B.mesh(body, B.sphere(0.19, 16), Vector3(0, 0.035, 0.03), dark)
	back.scale = Vector3(0.7, 0.45, 1.3)
	# Selän höyhenrivit: tummat suomut vaalealla reunalla, kolme riviä kummallakin puolella.
	for row in 3:
		for k in 5:
			for s in [-1.0, 1.0]:
				var z := -0.12 + k * 0.075 + row * 0.03
				var x: float = s * (0.04 + row * 0.045)
				var y := 0.075 - row * 0.03
				var f := B.mesh(body, B.sphere(0.034, 8), Vector3(x, y, z), edge)
				f.scale = Vector3(0.9, 0.3, 1.2)
				var fi := B.mesh(body, B.sphere(0.03, 8), Vector3(x, y + 0.004, z - 0.006), dark.darkened(0.08))
				fi.scale = Vector3(0.8, 0.3, 1.05)
	# Pyrstö: tumma viuhka valkoisella kärjellä.
	var tail := B.mesh(body, B.boxm(Vector3(0.12, 0.025, 0.12)), Vector3(0, 0.03, 0.31), dark, Vector3(-12, 0, 0))
	tail.scale = Vector3(1.0, 1.0, 1.0)
	B.mesh(body, B.boxm(Vector3(0.12, 0.026, 0.03)), Vector3(0, 0.044, 0.37), Color(0.95, 0.94, 0.9), Vector3(-12, 0, 0))
	# Kaula: tyvi vartalon etuyläosassa, kaula ylöspäin (+Y), pää kaulan päässä. Kulma säädetään (goose_pose).
	var neck := Node3D.new()
	neck.position = Vector3(0, 0.06, -0.2)
	body.add_child(neck)
	B.mesh(neck, B.cyl(0.038, 0.06, 0.14, 12), Vector3(0, 0.06, 0), grey)
	var neck2 := Node3D.new()
	neck2.position = Vector3(0, 0.13, 0)
	neck.add_child(neck2)
	B.mesh(neck2, B.cyl(0.032, 0.039, 0.13, 12), Vector3(0, 0.06, 0), grey.lightened(0.04))
	# Kaulan pystyuurteet (merihanhen tummat juovat).
	for s in [-1.0, 1.0]:
		B.mesh(neck2, B.boxm(Vector3(0.004, 0.11, 0.02)), Vector3(s * 0.033, 0.06, 0.0), dark)
	var head := Node3D.new()
	head.position = Vector3(0, 0.13, 0)
	neck2.add_child(head)
	var hd := B.mesh(head, B.sphere(0.046, 14), Vector3(0, 0.01, -0.01), grey.lightened(0.06))
	hd.scale = Vector3(0.85, 0.9, 1.25)
	var orange := Color(0.96, 0.56, 0.24)
	var beak_up := B.mesh(head, B.cyl(0.012, 0.026, 0.07, 10), Vector3(0, 0.006, -0.085), orange, Vector3(-90, 0, 0))
	beak_up.scale = Vector3(1.0, 1.0, 0.75)
	B.mesh(head, B.sphere(0.011, 8), Vector3(0, 0.004, -0.122), Color(0.95, 0.9, 0.8))  # kynsi
	var jaw := Node3D.new()  # alaleuka aukeaa huutaessa
	jaw.position = Vector3(0, -0.006, -0.05)
	head.add_child(jaw)
	var bl := B.mesh(jaw, B.cyl(0.008, 0.02, 0.064, 10), Vector3(0, -0.004, -0.032), orange.darkened(0.12), Vector3(-90, 0, 0))
	bl.scale = Vector3(1.0, 1.0, 0.5)
	for s in [-1.0, 1.0]:
		B.mesh(head, B.sphere(0.008, 8), Vector3(s * 0.034, 0.018, -0.02), Color(0.08, 0.06, 0.05))
		B.mesh(head, B.sphere(0.003, 6), Vector3(s * 0.04, 0.022, -0.024), Color(1, 1, 1))
		B.mesh(head, B.sphere(0.011, 8), Vector3(s * 0.03, 0.02, -0.02), orange.lightened(0.3)).scale = Vector3(0.4, 1, 1)  # silmärengas
	# Siivet lennossa: juuri hartioissa, käsivarsiosa ja kämmenosa (käsisulat viuhkana). Ei peilausta negatiivisella
	# skaalalla: puoli s kerrotaan koordinaatteihin.
	var wings := []
	var outers := []
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(s * 0.11, 0.07, -0.06)
		body.add_child(w)
		var inner := B.mesh(w, B.sphere(0.2, 14), Vector3(s * 0.18, 0, 0.04), grey)
		inner.scale = Vector3(0.95, 0.06, 0.55)  # pyöreä etureuna, ohut siipi
		for k in 6:  # peitinhöyhenet ja kyynärsulat
			B.mesh(w, B.boxm(Vector3(0.055, 0.016, 0.1)), Vector3(s * (0.04 + k * 0.058), -0.004, 0.14), dark.lightened(0.05))
			B.mesh(w, B.boxm(Vector3(0.05, 0.012, 0.012)), Vector3(s * (0.04 + k * 0.058), 0.006, 0.075), edge)
		var o := Node3D.new()
		o.position = Vector3(s * 0.36, 0, 0)
		w.add_child(o)
		var om := B.mesh(o, B.sphere(0.12, 12), Vector3(s * 0.09, 0, 0.02), grey.darkened(0.06))
		om.scale = Vector3(0.95, 0.08, 0.72)
		for k in 7:  # käsisulat viuhkana, tummat
			var a := deg_to_rad(-8.0 + k * 9.0)
			var fl := 0.22 - absf(k - 2.0) * 0.012
			var fm := B.mesh(o, B.boxm(Vector3(fl, 0.01, 0.034)), Vector3(s * (0.17 + cos(a) * fl * 0.5), -0.002, 0.03 + sin(a) * fl * 0.45),
				Color(0.24, 0.22, 0.2))
			fm.rotation.y = -s * a
		wings.append(w)
		outers.append(o)
	# Taitetut siivet levossa: kyljillä vartalon mukaisina, käsisulat ristiin pyrstön päällä.
	var folded := Node3D.new()
	body.add_child(folded)
	for s in [-1.0, 1.0]:
		var fw := B.mesh(folded, B.sphere(0.13, 14), Vector3(s * 0.1, 0.045, 0.06), dark.lightened(0.04))
		fw.scale = Vector3(0.38, 0.42, 1.55)
		fw.rotation.y = s * 0.06
		for k in 4:
			var e := B.mesh(folded, B.boxm(Vector3(0.012, 0.03, 0.05)), Vector3(s * 0.142, 0.03 - k * 0.012, -0.03 + k * 0.06), edge)
			e.rotation.y = s * 0.06
		var tip := B.mesh(folded, B.boxm(Vector3(0.03, 0.014, 0.16)), Vector3(s * 0.03, 0.08, 0.27), Color(0.24, 0.22, 0.2))
		tip.rotation.y = -s * 0.18
	# Jalat: vaaleanpunaiset, räpylät; lennossa vedetty taakse (goose_pose).
	var legs := []
	for s in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(s * 0.055, -0.1, 0.03)
		body.add_child(leg)
		var pink := Color(0.93, 0.6, 0.55)
		B.mesh(leg, B.cyl(0.013, 0.016, 0.06, 8), Vector3(0, -0.02, 0), pale.darkened(0.1))  # reisi höyhenissä
		B.mesh(leg, B.cyl(0.009, 0.009, 0.12, 8), Vector3(0, -0.1, 0), pink)
		for k in 3:
			var toe := B.mesh(leg, B.boxm(Vector3(0.008, 0.008, 0.06)), Vector3((k - 1) * 0.018, -0.16, -0.026), pink)
			toe.rotation.y = (k - 1) * 0.35
		var web := B.mesh(leg, B.boxm(Vector3(0.05, 0.004, 0.045)), Vector3(0, -0.162, -0.028), pink.darkened(0.08))
		web.scale = Vector3(1, 1, 1)
		legs.append(leg)
	g.set_meta("parts", {"body": body, "neck": neck, "neck2": neck2, "head": head, "jaw": jaw, "wings": wings, "outers": outers,
		"folded": folded, "legs": legs})
	return g


## Hanhen asento: "fly" (siivet auki ja lyönti vaiheessa ph, kaula eteen, jalat taakse), "glide" (siivet auki ja
## loiva lyönti), "brake" (vartalo pystyyn, isot lyönnit, jalat eteen), "stand" (siivet taitettu, kaula pystyssä).
## t = aika (s), ph = vaihesiirto. Seisovan hanhen juuri on jalkapohjien yllä LEG_H (kerrottuna skaalalla).
const LEG_H := 0.27
static func goose_pose(g: Node3D, mode: String, t: float, ph := 0.0, honk := 0.0, neck_up := 0.0) -> void:
	var p: Dictionary = g.get_meta("parts")
	var open := mode != "stand"
	for w in p.wings:
		(w as Node3D).visible = open
	(p.folded as Node3D).visible = not open
	var flap := 0.0
	var pitch := 0.0
	var neck_a := 0.0
	var leg_a := 0.0
	match mode:
		"fly":
			flap = sin(t * 7.5 + ph) * 0.62 + 0.08
			pitch = 0.0
			neck_a = -1.35
			leg_a = 1.4
		"glide":
			flap = sin(t * 3.0 + ph) * 0.12 + 0.12
			pitch = 0.08
			neck_a = -1.25
			leg_a = 1.2
		"brake":
			flap = sin(t * 9.0 + ph) * 0.75 + 0.15
			pitch = 0.75
			neck_a = -0.7
			leg_a = -0.3
		"stand":
			neck_a = -0.12 + neck_up
			leg_a = 0.0
	(p.body as Node3D).rotation.x = pitch
	(p.neck as Node3D).rotation.x = neck_a * 0.6
	(p.neck2 as Node3D).rotation.x = neck_a * 0.4
	(p.head as Node3D).rotation.x = -(neck_a + pitch) * 0.95  # pää vaakatasossa
	(p.jaw as Node3D).rotation.x = honk * 0.45
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		(p.wings[i] as Node3D).rotation = Vector3(0, 0, s * flap)
		(p.outers[i] as Node3D).rotation = Vector3(0, 0, s * flap * 0.55)
		(p.legs[i] as Node3D).rotation.x = leg_a
		(p.legs[i] as Node3D).visible = mode != "fly" and mode != "glide"


## Hanhen sulka (n. 18 cm): ruoti ja kaksi hiukan kaarevaa lippua, harmaa tummalla kärjellä. Juuri ruodin keskellä.
static func build_feather(parent: Node3D) -> Node3D:
	var f := Node3D.new()
	parent.add_child(f)
	B.mesh(f, B.cyl(0.0015, 0.0025, 0.19, 6), Vector3(0, 0.003, 0), Color(0.92, 0.9, 0.84), Vector3(90, 0, 0))
	for s in [-1.0, 1.0]:
		for k in 6:
			var z := -0.075 + k * 0.026
			var wdt := 0.022 * sin(PI * (k + 0.6) / 6.6)
			var col := Color(0.55, 0.52, 0.47).darkened(0.2 * float(k) / 5.0)
			var v := B.mesh(f, B.boxm(Vector3(wdt, 0.002, 0.03)), Vector3(s * (wdt / 2.0 + 0.002), 0.004 + wdt * 0.15, z), col)
			v.rotation.z = -s * 0.12
	return f


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	for c in [me, fisher, kuski]:
		c.clear_ik()
		_lean(c, 0.0)
		_look_up(c, 0.0)
	fisher.visible = p != "kivi"
	kuski.visible = p == "kuski" or p == "otsikko"
	goose.visible = p == "hanhet" or p == "kuski"
	for g in flock:
		g.visible = p == "hanhet"
	match p:
		"kivi":
			_story = ""
			_stand(me, ME_CROUCH.x, ME_CROUCH.y)
			_face(me, STONE)
			me.play("Crouch_Idle", 0.0)
		"kuoppa":
			_story = ""
			_stand(me, ME_CROUCH.x, ME_CROUCH.y)
			me.play("Walk", 0.2)
			_stand(fisher, FISH_FROM.x, FISH_FROM.y)
			fisher.play("Walk", 0.2)
		"hanhet":
			_story = ""
			_stand(me, ME_LOOK.x, ME_LOOK.y)
			_stand(fisher, FISH_AT.x, FISH_AT.y)
			_face(me, STONE)
			_face(fisher, STONE)
			me.play("Idle", 0.2)
			fisher.play("Idle", 0.2)
			_look = Vector3(14.0, 5.0, -9.0)
			goose_landed = false
		"kuski":
			_story = ""
			_stand(me, ME_LOOK.x, ME_LOOK.y)
			_stand(fisher, FISH_AT.x, FISH_AT.y)
			_face(me, STONE)
			_face(fisher, STONE)
			me.play("Idle", 0.2)
			fisher.play("Idle", 0.2)
			_stand(kuski, KUSKI_FROM.x, KUSKI_FROM.y)
			kuski.play("Walk", 0.2)
			_set_goose_on_stone()
			feather.visible = false
		"otsikko":
			_story = ""
			# Ryhmäkuva: miehet rivissä kiven vieressä, kasvot joelle päin (kamera joen yllä).
			_stand(me, 7.2, -1.35)
			_stand(fisher, 8.4, -1.65)
			_stand(kuski, 6.05, -1.1)
			for c in [me, fisher, kuski]:
				c.play("Idle", 0.2)
				_face(c, Vector3(6.0, 0, -9.0))
			_place_feather()
			Sfx.play("win", -7.0, 0.92)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa kiven E-painalluksesta: sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "kivi" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"kivi":
			_step_kivi()
		"kuoppa":
			_step_kuoppa()
		"hanhet":
			_step_hanhet(delta)
		"kuski":
			_step_kuski()
		"otsikko":
			_step_otsikko()
	_honk_t -= delta
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
	queue_free()


func _step_kivi() -> void:
	# Kyykyssä kiven juurella: kämmen kiven kylkeen (0,4-1,4 s), hipaisee alas kohti maata (2,4-3,8), pelaaja nousee
	# ja katsoo rantaan (4,4-).
	# Vasen käsi: kamera on etelässä, ja pelaajan vasen kylki on kameraan päin (kasvot länteen).
	var sh := interior.to_local(me.to_global(me.bone_position("upperarm_l")))
	var hi := stone_side(interior, Vector3(sh.x, 0.5, sh.z))
	var lo := stone_side(interior, Vector3(sh.x, 0.3, sh.z))
	var n := Vector3(me.position.x - hi.x, 0, me.position.z - hi.z).normalized() * 0.035  # kämmen pinnan päällä
	var reach := _ease(clampf((_t - 0.4) / 1.0, 0.0, 1.0)) * (1.0 - _ease(clampf((_t - 4.2) / 0.5, 0.0, 1.0)))
	var slide := _ease(clampf((_t - 2.4) / 1.4, 0.0, 1.0))
	if _t < 4.4:
		_reach(me, _g(hi.lerp(lo, slide) + n), reach, 0.12 * reach, "_l")
	elif not _once.has("nousu"):
		_once["nousu"] = true
		me.clear_ik()
		_lean(me, 0.0)
		me.play("Idle", 0.3)
	if _t > 4.6:
		_face(me, STONE.lerp(HOLLOW, _ease(clampf((_t - 4.6) / 0.8, 0.0, 1.0))))
	if _t > 0.5:
		_story = "Kivi on kuin on ollut."
	if _t > 3.0:
		_story = "Sammal kasvaa vain päällä. Juurelta kivi on paljas, kuin se olisi laskettu tähän."
	# Kamera: matala sivukuva etelästä: pelaajan vasen profiili, kämmen kiven kyljellä, joki takana.
	var eye := Vector3(6.35, 1.05, -0.95)
	var look := Vector3(5.85, 0.55, -3.55)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.2))
	_fill.position = Vector3(6.6, 1.8, -1.2)


func _step_kuoppa() -> void:
	# Pelaaja kävelee rantaan painauman reunalle (0-3,2 s) ja katsoo alas; kalastaja tulee viereen (0,8-4,0).
	var path := [ME_CROUCH, Vector2(6.75, -2.6), ME_HOLLOW]
	var k := clampf(_t / 3.2, 0.0, 1.0)
	var pp := _path(path, k)
	_stand(me, pp.x, pp.y)
	if k < 1.0:
		var nx := _path(path, minf(1.0, k + 0.05))
		_face(me, Vector3(nx.x, 0, nx.y))
	else:
		if not _once.has("me_stop"):
			_once["me_stop"] = true
			me.play("Idle", 0.3)
		_face(me, HOLLOW)
		Room.nod(me, 0.35 * _ease(clampf((_t - 3.3) / 0.6, 0.0, 1.0)))
	var fk := clampf((_t - 0.8) / 3.2, 0.0, 1.0)
	var fp := FISH_FROM.lerp(FISH_AT, fk)
	_stand(fisher, fp.x, fp.y)
	if fk < 1.0:
		_face(fisher, Vector3(FISH_AT.x, 0, FISH_AT.y) + Vector3(FISH_AT.x - FISH_FROM.x, 0, FISH_AT.y - FISH_FROM.y).normalized())
	else:
		if not _once.has("f_stop"):
			_once["f_stop"] = true
			fisher.play("Idle", 0.3)
		_face(fisher, HOLLOW if _t < 4.2 else me.position)
	if _t > 3.0:
		_story = "Rannassa on kiven muotoinen painauma. Ruoho kasvaa siinä harvana."
	if _t > 4.2:
		_bub[fisher] = "Mun isä sano, ettei kiveen kosketa."
	if _t > 5.6:
		_bub.erase(fisher)
		_face(me, fisher.position)
		Room.nod(me, 0.0)
		_bub[me] = "Kuka sen tänne toi?"
	if _t > 6.6:
		_bub.erase(me)
		_bub[fisher] = "Ei kukaan tiedä."
	# Kamera: idästä rannan suuntaisesti: painauma etualalla, pelaaja ja kalastaja kasvot kameraan päin, kivi taustalla.
	_fit(Vector3(13.2, 2.1, -1.0), [_g(HOLLOW + Vector3(1.6, 0, -0.4)), _g(HOLLOW + Vector3(-1.4, 0, 0.9)),
		_head(me) + Vector3(0, 0.35, 0), _head(fisher) + Vector3(0, 0.35, 0), _g(STONE + Vector3(0, 1.0, 0))], 1.12)
	_fill.position = Vector3(8.5, 2.4, 0.4)


## Auran hanhen paikka ajassa t (s vaiheen alusta): aura lentää joen yli idästä länteen.
func _flock_pos(i: int, t: float) -> Vector3:
	var lead := Vector3(30.0 - 6.4 * t, 7.5, -10.5)
	var side := 1.0 if i % 2 == 0 else -1.0
	var rank := float(i / 2 + 1)
	return lead + Vector3(rank * 1.05, -rank * 0.08, side * rank * 0.95)


const LAND_T0 := 1.8
const LAND_T1 := 5.0


func _goose_path(t: float) -> Vector3:
	var p0 := _flock_pos(5, LAND_T0)  # laskeutuja irtoaa auran oikeasta haarasta
	var p3 := top + Vector3(0, LEG_H * GOOSE_S, 0)
	var p1 := p0 + Vector3(-6.0, -1.0, 1.6)
	var p2 := p3 + Vector3(2.6, 1.4, -0.6)
	var u := clampf((t - LAND_T0) / (LAND_T1 - LAND_T0), 0.0, 1.0)
	u = 1.0 - pow(1.0 - u, 1.6)  # hidastuu loppua kohti
	var a := p0.lerp(p1, u)
	var b2 := p1.lerp(p2, u)
	var c := p2.lerp(p3, u)
	return a.lerp(b2, u).lerp(b2.lerp(c, u), u)


func _step_hanhet(delta: float) -> void:
	# Aura joen yllä; laskeutuja irtoaa 1,8 s, liukuu alas ja jarruttaa kiven päälle 5,0 s, taittaa siivet ja huutaa.
	if _t > 0.2 and not _once.has("aura"):
		_once["aura"] = true
		_play_honk(-14.0, 1.05)
	if _t > 1.3 and not _once.has("aura2"):
		_once["aura2"] = true
		_play_honk(-11.0, 0.95)
	for i in flock.size():
		var g: Node3D = flock[i]
		g.position = _flock_pos(i if i < 5 else i + 1, _t)
		g.rotation = Vector3(0, PI / 2.0, 0)  # etu -Z -> -X (länteen)
		goose_pose(g, "fly", _t, i * 0.37)
	var gp: Vector3
	if _t < LAND_T0:
		gp = _flock_pos(5, _t)
		goose.rotation = Vector3(0, PI / 2.0, 0)
		goose_pose(goose, "fly", _t, 1.7)
	elif _t < LAND_T1:
		gp = _goose_path(_t)
		var ahead := _goose_path(minf(LAND_T1, _t + 0.05))
		var v := ahead - gp
		if Vector2(v.x, v.z).length() > 0.002:
			goose.rotation.y = lerp_angle(goose.rotation.y, B.yaw_to(v), 0.2)
		var u := (_t - LAND_T0) / (LAND_T1 - LAND_T0)
		goose_pose(goose, "glide" if u < 0.7 else "brake", _t, 1.7)
		if u > 0.7 and not _once.has("jarru"):
			_once["jarru"] = true
			Sfx.play("cloth", -2.0, 0.6)
			Sfx.play("whoosh", -8.0, 0.55)
	else:
		_set_goose_on_stone()
		gp = goose.position
		if not _once.has("laskeutui"):
			_once["laskeutui"] = true
			goose_landed = true
			Sfx.play("cloth", -4.0, 0.8)
		# Taittaa siivet (5,0-5,4), kääntyy katsomaan pelaajaa, ojentaa kaulan ja huutaa 6,2 ja 7,4.
		var face := me.position + Vector3(0, 0, 0.3)
		goose.rotation.y = lerp_angle(goose.rotation.y, B.yaw_to(face - goose.position), 0.08)
		var up := 0.0
		for ht in [6.2, 7.4]:
			if _t > ht and not _once.has("huuto%.1f" % ht):
				_once["huuto%.1f" % ht] = true
				_honk_t = 0.45
				_play_honk(-3.0, 1.0 if ht < 7.0 else 0.92)
			if _t > ht - 0.3 and _t < ht + 0.6:
				up = maxf(up, sin(PI * clampf((_t - ht + 0.3) / 0.9, 0.0, 1.0)) * 0.45)
		goose_pose(goose, "stand", _t, 0.0, 1.0 if _honk_t > 0.0 else 0.0, up)
	goose.position = gp if _t < LAND_T1 else goose.position
	# Pelaaja ja kalastaja kääntyvät ääneen ja seuraavat katseella.
	var look_at := gp
	for c in [me, fisher]:
		if _t > 0.5:
			_face(c, c.position.lerp(look_at, 1.0) if _t > 1.0 else Vector3(14, 0, -9))
			var hgt := look_at.y - 1.6
			var dist := Vector2(look_at.x - c.position.x, look_at.z - c.position.z).length()
			_look_up(c, clampf(atan2(hgt, maxf(dist, 0.5)), 0.0, 0.7))
	if _t > 5.8:
		_story = "Sanotaan, että sama hanhi on Pyhäjoen vaakunassa."
	# Kamera: puiston puolelta (pelaajat oikealla keskietäisyydellä), katse seuraa auraa ja laskeutujaa ja tarkentaa
	# kivellä istuvaan hanheen.
	var eye := Vector3(6.6, 2.1, 1.2)  # laatan itäpuolelta ja yläpuolelta: laatta jää kuvan alle, koivu taakse
	var want := gp if _t > LAND_T0 - 0.4 else (_flock_pos(0, _t) + _flock_pos(5, _t)) / 2.0
	_look = _look.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
	var zoom := _ease(clampf((_t - 5.2) / 1.0, 0.0, 1.0))
	var look := _look.lerp(top + Vector3(0.5, 0.15, 0.2), zoom)
	var w := lerpf(26.0, 4.2, _ease(clampf((_t - LAND_T0) / (LAND_T1 - LAND_T0 + 0.6), 0.0, 1.0)))
	_cam_at(eye, look, _fov_w(eye.distance_to(look), w))
	_fill.position = top + Vector3(1.2, 1.2, 1.6)


func _step_kuski() -> void:
	# Kuski kävelee tieltä (0-2,6 s): "Ei oo totta." Kalastaja käsi rinnalla (0,6-4,6): "Kukaan ei voi todistaa mitään."
	# Hanhi katsoo jokaista, lähtee 5,0 s joen yli; sulka irtoaa ja leijuu kiven päälle (5,3-7,6). "...Ja hyvä niin."
	var k := clampf(_t / 2.6, 0.0, 1.0)
	var kp := KUSKI_FROM.lerp(KUSKI_AT, _ease(k))
	_stand(kuski, kp.x, kp.y)
	if k < 1.0:
		_face(kuski, Vector3(KUSKI_AT.x, 0, KUSKI_AT.y) + Vector3(KUSKI_AT.x - KUSKI_FROM.x, 0, KUSKI_AT.y - KUSKI_FROM.y).normalized())
	elif not _once.has("k_stop"):
		_once["k_stop"] = true
		kuski.play("Idle", 0.3)
	if k >= 1.0:
		_face(kuski, goose.position)
	# Kalastaja: oikea käsi rinnalle ja pää painuu (kunnioitus).
	var hand_w := _ease(clampf((_t - 0.6) / 0.6, 0.0, 1.0)) * (1.0 - _ease(clampf((_t - 4.6) / 0.6, 0.0, 1.0)))
	var chest: Vector3 = fisher.bone_position("spine_03")
	var sh: Vector3 = fisher.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	fisher.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", rest.lerp(chest + Vector3(s * 0.07, 0.02, -0.17), hand_w),
		sh + Vector3(s * 0.4, -0.3, 0.15))
	Room.nod(fisher, 0.3 * hand_w)
	var gone := _t > 5.0
	if not gone:
		_set_goose_on_stone()
		var who: Node3D = kuski if _t > 2.0 and _t < 3.6 else (fisher if _t < 4.6 else me)
		goose.rotation.y = lerp_angle(goose.rotation.y, B.yaw_to(who.position - goose.position), 0.06)
		goose_pose(goose, "stand", _t, 0.0, 0.0, 0.15 if _t > 2.2 and _t < 2.8 else 0.0)
	else:
		# Lähtö: muutama askel kiven reunalle ja ylös joen yli (-Z), kauas puiden yli.
		var u := clampf((_t - 5.0) / 4.0, 0.0, 1.0)
		var p0 := top + Vector3(0, LEG_H * GOOSE_S, 0)
		var p1 := p0 + Vector3(1.6, 0.8, -0.7)  # joen suuntaisesti itään, Hourunkosken yli
		var p2 := p0 + Vector3(7.0, 4.0, -3.0)
		var p3 := p0 + Vector3(24.0, 9.0, -7.0)
		var a := p0.lerp(p1, u)
		var b2 := p1.lerp(p2, u)
		var c := p2.lerp(p3, u)
		var gp := a.lerp(b2, u).lerp(b2.lerp(c, u), u)
		var v := gp - goose.position
		if v.length() > 0.001:
			goose.rotation.y = lerp_angle(goose.rotation.y, B.yaw_to(v), 0.15)
		goose.position = gp
		goose_pose(goose, "brake" if u < 0.12 else "fly", _t, 0.0)
		if not _once.has("lahto"):
			_once["lahto"] = true
			Sfx.play("cloth", -2.0, 0.7)
			Sfx.play("whoosh", -6.0, 0.6)
			_play_honk(-6.0, 1.08)
	# Sulka: irtoaa lähdössä ja leijuu heilahdellen kiven päälle.
	if _t > 5.3:
		feather.visible = true
		var fu := clampf((_t - 5.3) / 2.3, 0.0, 1.0)
		var start := top + Vector3(0.5, 1.4, -0.3)
		var end := top + Vector3(0, 0.006, 0)
		var sway := (1.0 - fu) * 0.22
		feather.position = start.lerp(end, _ease(fu)) + Vector3(sin(_t * 5.5) * sway, 0, cos(_t * 4.3) * sway * 0.6)
		feather.rotation = Vector3(sin(_t * 6.0) * 0.5 * (1.0 - fu), 0.9 + sin(_t * 2.0) * 0.4 * (1.0 - fu), cos(_t * 5.0) * 0.4 * (1.0 - fu))
		if fu >= 1.0:
			_place_feather()
	for c in [me, fisher, kuski]:
		if gone:
			_look_up(c, clampf((_t - 5.0) * 0.25, 0.0, 0.45))
			if c != kuski or k >= 1.0:
				_face(c, goose.position)
	if _t > 2.4:
		_bub[kuski] = "Ei oo totta."
	if _t > 3.8:
		_bub.erase(kuski)
		_bub[fisher] = "Kukaan ei voi todistaa mitään."
	if _t > 6.9:
		_bub.erase(fisher)
		_bub[kuski] = "...Ja hyvä niin."
	# Kamera: joen yltä etelään: hanhi kivellä, ja miehet kasvot kameraan päin (he katsovat kiveä).
	var pts := [_g(top + Vector3(0, 0.75, 0)), _g(top - Vector3(0, 0.5, 0)), _g(top + Vector3(0.6, 0.4, 0)), _g(top + Vector3(-0.6, 0.4, 0)), _head(me) + Vector3(0, 0.3, 0), _head(fisher) + Vector3(0, 0.3, 0),
		_g(Vector3(KUSKI_AT.x, 0.0, KUSKI_AT.y)), _g(Vector3(KUSKI_AT.x, 2.1, KUSKI_AT.y))]
	_fit(Vector3(6.4, 3.1, -8.6), pts, 1.1)
	_fill.position = Vector3(5.5, 2.6, -4.6)


func _step_otsikko() -> void:
	# Aura kaukana tien takana koivujen yllä (kamera katsoo joelta etelään), miehet kasvot kameraan kiven vieressä.
	for i in flock.size():
		var g: Node3D = flock[i]
		g.position = _flock_pos(i, _t + 2.0) + Vector3(-12.0, 4.0, 28.0)
		g.rotation = Vector3(0, PI / 2.0, 0)
		goose_pose(g, "fly", _t, i * 0.37)
	_fit(Vector3(7.2, 2.6, -9.4), [_g(top + Vector3(0, 0.4, 0)), _g(STONE + Vector3(-1.9, 0, 0)), _head(fisher) + Vector3(0.4, 0.4, 0),
		_head(me) + Vector3(0, 1.6, 0), _g(Vector3(6.0, 0, -0.9))], 1.08)
	_fill.position = Vector3(6.0, 2.5, -4.0)


func _set_goose_on_stone() -> void:
	goose.position = top + Vector3(0, LEG_H * GOOSE_S, 0)
	goose.rotation.x = 0.0
	goose.rotation.z = 0.0


func _place_feather() -> void:
	feather.visible = true
	feather.position = top + Vector3(0, 0.006, 0)
	feather.rotation = Vector3(0, 0.9, 0)
	feather_on_stone = true


func _g(v: Vector3) -> Vector3:
	return interior.to_global(v)


func _head(c: Node3D) -> Vector3:
	return c.to_global(c.bone_position("Head"))


## Kamera pisteestä eye niin, että kaikki pisteet (globaalit) mahtuvat kuvaan: katse pisteiden keskelle ja
## pystykenttä suurimman kulmapoikkeaman mukaan (vaaka jaetaan kuvasuhteella), pad = väljyys.
func _fit(eye: Vector3, pts: Array, pad := 1.1) -> void:
	var ge := interior.to_global(eye)
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	_cam.look_at_from_position(ge, c)
	var vs := get_viewport().get_visible_rect().size
	var asp := vs.x / vs.y
	var inv := _cam.global_transform.basis.inverse()
	var need := 0.0
	for p in pts:
		var l: Vector3 = inv * ((p as Vector3) - ge)
		var z := maxf(-l.z, 0.1)
		need = maxf(need, maxf(atan(absf(l.y) / z), atan(absf(l.x) / z / asp)))
	_cam.fov = clampf(rad_to_deg(2.0 * need) * pad, 8.0, 90.0)


## Oikea käsi kohti pistettä (w 0..1); lean kumartaa selkää samassa suhteessa.
func _reach(c: Node3D, at: Vector3, w: float, lean := 0.0, lr := "_r") -> void:
	_lean(c, lean)
	var sh: Vector3 = c.bone_position("upperarm" + lr)
	var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at), w)
	c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, tgt, sh + Vector3(s * 0.45, -0.25, 0.25))


## Kumarrus koko selällä (rad yhteensä), niska kompensoi katseen.
func _lean(c: Node3D, a: float) -> void:
	c.set_override("spine_01", Vector3.RIGHT, -a * 0.45)
	c.set_override("spine_02", Vector3.RIGHT, -a * 0.35)
	c.set_override("spine_03", Vector3.RIGHT, -a * 0.2)
	c.set_override("neck_01", Vector3.RIGHT, a * 0.35)


## Katse ylös (rad): niska ja pää taakse.
func _look_up(c: Node3D, a: float) -> void:
	c.set_override("neck_01", Vector3.RIGHT, a * 0.55)
	c.set_override("Head", Vector3.RIGHT, a * 0.45)


func _stand(c: Node3D, x: float, z: float) -> void:
	c.position = Vector3(x, 0, z)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


func hand(c: Node3D, lr := "_r") -> Vector3:
	return c.to_global((c.bone_position("hand" + lr) + c.bone_position("index_01" + lr)) / 2.0)


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


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


# --- Kamera -------------------------------------------------------------------------

func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = clampf(fov, 8.0, 90.0)
	_cam.look_at_from_position(interior.to_global(eye), interior.to_global(look))


func _fov_w(d: float, w: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return rad_to_deg(2.0 * atan(w / (2.0 * d) / (vs.x / vs.y)))


# --- Ääni ---------------------------------------------------------------------------

func _play_honk(db: float, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = _honk
	p.volume_db = db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	p.play()


## Hanhen huuto: kaksi nenäistä "aang"-tavua, sahalaita laskevalla sävelellä ja kaksi formanttia (resonanssisuodin).
func _honk_wav() -> AudioStreamWAV:
	var dur := 0.75
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	var ph := 0.0
	var f1 := [0.0, 0.0]
	var f2 := [0.0, 0.0]
	for syl in 2:
		var t0 := 0.02 + syl * 0.34
		var ln := 0.26
		for j in int(ln * RATE):
			var t := float(j) / RATE
			var u := t / ln
			var f0 := lerpf(430.0, 360.0, u) * (1.0 if syl == 0 else 0.93)
			ph = fposmod(ph + f0 / RATE, 1.0)
			var x := ph * 2.0 - 1.0
			# Kaksi resonanssia (n. 1100 ja 2600 Hz): nasaalinen sävy.
			var y1 := _reso(x, 1100.0, 0.97, f1)
			var y2 := _reso(x, 2600.0, 0.95, f2)
			var env := minf(1.0, u * 12.0) * pow(1.0 - u, 0.6)
			var i := int((t0 + t) * RATE)
			if i < s.size():
				s[i] += (y1 * 0.55 + y2 * 0.35 + x * 0.08) * env * 0.5
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.data = data
	return w


func _reso(x: float, f: float, r: float, st: Array) -> float:
	var c := 2.0 * r * cos(TAU * f / RATE)
	var y := (1.0 - r) * x + c * float(st[0]) - r * r * float(st[1])
	st[1] = st[0]
	st[0] = y
	return y * 4.0


# --- Piirto -------------------------------------------------------------------------

func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 460, 24, 920, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for c: Node3D in _bub:
		if is_instance_valid(c) and c.visible:
			Room.bubble(_ui, _cam, c, _bub[c], 90.0, 120.0)
	if phase == "otsikko":
		var a := clampf((_t - 0.9) / 0.9, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.05, 0.06, 0.22 * a))
		var y := vs.y * 0.17
		_draw_goose_icon(Vector2(vs.x / 2.0, y - 74.0), a)
		var title := "HANHIKIVEN RAJAKIVI"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.05, 0.08, 0.1, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(1.0, 0.84, 0.42, a))
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 158.0, 840, 84)
		_ui.draw_rect(sr, Color(0.03, 0.05, 0.06, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Pyhäjoen Koskipuisto: hanhi istui kivellä",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.95, 0.8, 0.5, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Kukaan ei voi todistaa mitään, ja hyvä niin.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Lentävän hanhen siluetti otsikon yllä (kuin vaakunan hanhi): vartalo, ojennettu kaula, siivet ylhäällä.
func _draw_goose_icon(c: Vector2, a: float) -> void:
	var dark := Color(0.05, 0.08, 0.1, a)
	var col := Color(0.95, 0.92, 0.85, a)
	var body := PackedVector2Array([c + Vector2(-34, 4), c + Vector2(-10, -4), c + Vector2(16, -2), c + Vector2(30, 2),
		c + Vector2(42, -2), c + Vector2(50, 0), c + Vector2(42, 4), c + Vector2(28, 8), c + Vector2(0, 12), c + Vector2(-26, 10)])
	var wing := PackedVector2Array([c + Vector2(-8, -2), c + Vector2(-26, -30), c + Vector2(-4, -38), c + Vector2(14, -2)])
	for poly in [wing, body]:
		_ui.draw_colored_polygon(poly, col)
		var outline: PackedVector2Array = poly.duplicate()
		outline.append(poly[0])
		_ui.draw_polyline(outline, dark, 2.5)
	_ui.draw_colored_polygon(PackedVector2Array([c + Vector2(50, 0), c + Vector2(58, 1), c + Vector2(50, 3)]), Color(0.96, 0.56, 0.24, a))
	_ui.draw_circle(c + Vector2(45, -0.5), 1.6, dark)
