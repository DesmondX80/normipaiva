extends CanvasLayer
## Legendaarinen hetki "kanttorin_virsi" (Kanttorin virsi): kun kanttorin nuotit annetaan ensimmäistä kertaa Sinikan
## kuorolle (main.gd _talk_kanttori "kanttori_kuoro"), kohtaus lavastetaan viikon päähän seuraintalon saliin
## (kirppis_interior.gd, salin oma tila "konsertti": kalusteet ja salin väki piiloon, tuolirivit ja kuoro tilalle) ja
## lopuksi Kanttorilan pihalle. Vaiheet:
##   sali      tuolirivit täynnä, kuoro lavalla mustat kansiot käsissä, Sinikka lavan edessä nuottitelineen takana
##             (nuottiarkin puolikkaat teipillä yhteen, toinen kellastunut). Sinikka esittelee virren yleisölle.
##   laulu     Sinikka johtaa (kolmijakoinen lyönti), kuoro laulaa (KanttoriLegenda.tune("kuoro")); Hilkka pyyhkii silmää
##   harmooni  huipennus: lavan vieressä oleva vanha harmooni (huutokaupan harmooni, jonka palkeesta nuottiarkki löytyi)
##             avaa kantensa itsestään ja soittaa mukana: koskettimet painuvat sävelen mukaan, polkimet liikkuvat, eikä
##             jakkaralla ole ketään. Sinikka vilkaisee, nyökkää ja jatkaa. Yleisö kääntyy katsomaan.
##   aamen     viimeinen sointu: Sinikka katkaisee, koskettimet nousevat ja kansi laskeutuu hitaasti kiinni. Hiljaisuus.
##             Kanttorilan pihalla ikkunan kajo himmenee ja yösävelen viimeinen urkusointu vaimenee: urut vaikenivat.
##   otsikko   sali nousee taputtamaan, kuoro ja Sinikka kumartavat. KANTTORIN VIRSI.
## Kehys: salin paikalliset koordinaatit (kirppis_interior.gd: +Z = pääovi, -Z = lava; lava z -6..-3,4, pinta y 0,5,
## x ±4). Hahmojen etu -Z (Looks), B.yaw_to(v) kääntää etupuolen suuntaan v. Harmoonin koskettimet ovat sen paikallisella
## -Z-puolella. Kanttorilan kajo: julkisivun ulospäin osoittava suunta lasketaan world.kanttorila_pos:sta (piha 3 m
## julkisivun edessä) ja world.kanttorila_root:sta (julkisivun keskikohta). Sinikka muistelee myöhemmin (main.gd
## _talk_kanttori "kanttori_muisto", MUISTO).

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const T := preload("res://scripts/terrain.gd")
const KanttoriLegenda := preload("res://scripts/kanttori_legenda.gd")

const DUR := {"sali": 6.5, "laulu": 7.0, "harmooni": 6.0, "aamen": 6.6, "otsikko": 6.4}
const ORDER := ["sali", "laulu", "harmooni", "aamen", "otsikko"]
const STAGE_Y := 0.5
const RISER_Y := 0.82  # takarivin koroke lavalla
const HARMOONI := Vector3(-5.3, 0.0, -2.3)  # harmoonin keskikohta salin lattialla
const HARM_FACE := Vector3(0.75, 0.0, 0.66)  # koskettimet katsovat salin keskelle
const KEY_Y := 0.74  # koskettimien pinta harmoonin juuresta
const SINIKKA_AT := Vector3(0.0, 0.0, -2.55)
const STAND_AT := Vector3(0.42, 0.0, -2.95)
const FIRST_MIDI := 48  # koskettimisto C3..B5
const KEY_COUNT := 36
const TUNE_MIDI := 57  # KanttoriLegenda.TUNE puolisävelet A3:sta
const CHAIR_ROWS := [0.7, 1.7, 2.7]
const CHAIR_X := [-4.2, -3.4, -2.6, -1.8, -1.0, 1.0, 1.8, 2.6, 3.4, 4.2]
const HILKKA := {"model": "female", "shirt": Color(0.55, 0.3, 0.45), "pants": Color(0.25, 0.22, 0.3), "shoes": Color(0.3, 0.25, 0.2),
	"shoe": "kavelykenka", "hair": "Hair_Buns", "hair_color": Color(0.85, 0.85, 0.85), "height": 1.58, "skin": Color(0.95, 0.8, 0.74),
	"belly": 0.4}
const TAUNO := {"shirt": Color(0.3, 0.32, 0.25), "pants": Color(0.2, 0.22, 0.35), "shoes": Color(0.2, 0.15, 0.1), "shoe": "tyokenka",
	"hair": "Hair_Buzzed", "hair_color": Color(0.7, 0.7, 0.68), "beard": true, "height": 1.78, "skin": Color(0.95, 0.72, 0.64), "belly": 0.8}
## Kuoro: valkoiset puserot ja tummat housut tai hameet, kaksi miestä takarivissä.
const CHOIR := [
	{"model": "female", "hair": "Hair_Buns", "hair_color": Color(0.88, 0.88, 0.86), "height": 1.58, "belly": 0.5, "skin": Color(0.96, 0.8, 0.74)},
	{"model": "female", "hair": "Hair_Long", "hair_color": Color(0.55, 0.32, 0.18), "height": 1.66, "belly": 0.2, "skin": Color(0.97, 0.8, 0.72)},
	{"model": "female", "hair": "Hair_Buns", "hair_color": Color(0.62, 0.6, 0.58), "height": 1.6, "belly": 0.45, "skin": Color(0.95, 0.78, 0.7)},
	{"model": "female", "hair": "Hair_Long", "hair_color": Color(0.85, 0.78, 0.6), "height": 1.62, "belly": 0.3, "skin": Color(0.98, 0.84, 0.78)},
	{"hair": "Hair_SimpleParted", "hair_color": Color(0.6, 0.6, 0.58), "height": 1.78, "belly": 0.6, "skin": Color(0.95, 0.74, 0.66)},
	{"model": "female", "hair": "Hair_Buns", "hair_color": Color(0.4, 0.28, 0.2), "height": 1.64, "belly": 0.35, "skin": Color(0.96, 0.8, 0.72)},
	{"hair": "Hair_Buzzed", "hair_color": Color(0.35, 0.28, 0.2), "beard": true, "height": 1.82, "belly": 0.5, "skin": Color(0.93, 0.72, 0.62)},
]
## Kuoron paikat: [x, z, takarivi]. Etu- ja takarivi lomittain, ettei kukaan peitä toista.
const CHOIR_AT := [[-1.35, -4.15, false], [-0.45, -4.15, false], [0.45, -4.15, false], [1.35, -4.15, false],
	[-0.9, -4.95, true], [0.0, -4.95, true], [0.9, -4.95, true]]
## Sinikka muistelee (main.gd _talk_kanttori "kanttori_muisto").
const MUISTO := ["Kun se harmooni alko soittaa, mää meinasin lopettaa. Sitten mää aattelin: antaa kanttorin soittaa.",
	"Kuoro laulaa sitä nyt joka sunnuntai. Harmoonin kansi pysyy kiinni. Ei sitä kukaan avaa.",
	"Mää kävin yöllä Kanttorilan pihalla. Hiljasta. Ihan hiljasta. Vähän mää kaipaan sitä säveltä.",
	"Hilkka itki koko virren. Ja Pekka. Älä sano Pekalle, että mää sanoin."]

var world: Node3D
var hall: Node3D  # kirppis_interior.gd
var hide_nodes: Array = []
var _was_visible := {}

var phase := ""
var _t := 0.0
var _tune_t := -1.0  # aika virren alusta (laulu 0..)
var _cam: Camera3D
var _ui: Control
var _keys_bar: Node
var _story := ""
var _bub := {}
var _G: Node3D  # salin kehys (salin lapsi)
var _props: Array[Node3D] = []
var me: Node3D
var sinikka: Node3D
var hilkka: Node3D
var pekka: Node3D
var arto: Node3D
var annaliisa: Node3D
var tauno: Node3D
var extras: Array[Node3D] = []
var choir: Array[Node3D] = []
var audience: Array[Node3D] = []  # istuvat: [hahmo]
var _seat := {}  # hahmo -> istuimen paikka (salin koordinaatit)
var _folders := {}  # kuorolainen -> kansio
var harmooni: Node3D
var _lid: Node3D  # kansi (sarana koskettimien takana)
var _keys: Array = []  # [MeshInstance3D, lepo-y, midi]
var _pedals: Array[Node3D] = []
var _glow: OmniLight3D
var _choir_snd: AudioStreamPlayer
var _organ_snd: AudioStreamPlayer
var _K: Node3D  # Kanttorilan kajo (maailmassa)
var _window_light: OmniLight3D
var lid_open := 0.0  # testi lukee
var pressed := []  # testi lukee: painetut midit
var window_glow := 1.0
var cut_off := false


func _ready() -> void:
	layer = 6
	_G = Node3D.new()
	hall.add_child(_G)
	_props.append(_G)
	if hall.has_method("concert"):
		hall.concert(true)
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
	_choir_snd = AudioStreamPlayer.new()
	_choir_snd.stream = KanttoriLegenda.tune("kuoro")
	_choir_snd.volume_db = -5.0
	add_child(_choir_snd)
	_organ_snd = AudioStreamPlayer.new()
	_organ_snd.stream = KanttoriLegenda.tune("urut")
	_organ_snd.volume_db = -9.0
	add_child(_organ_snd)
	_build()
	_build_kanttorila()
	_begin("sali")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	# Takarivin koroke lavalla ja sininen kangas lavan reunassa.
	B.mesh(_G, B.boxm(Vector3(3.2, RISER_Y - STAGE_Y, 0.9)), Vector3(0, (STAGE_Y + RISER_Y) / 2.0, -4.95), Color(0.42, 0.28, 0.17))
	B.mesh(_G, B.boxm(Vector3(3.22, 0.04, 0.92)), Vector3(0, RISER_Y + 0.01, -4.95), Color(0.36, 0.23, 0.14))
	var sign := B.sign_plate(_G, "SALOISTEN KIRKKOKUORO", Color(0.12, 0.2, 0.42), Color(1.0, 0.92, 0.7), 0.42, 56,
		Color(0.85, 0.7, 0.35), "Helvetica Neue")
	sign.position = Vector3(0, 2.9, -5.67)
	# Salin etuseinä täyteen korkeuteen (salin oma on matala ylhäältä kuvaavaa kävelykameraa varten): kuvat lavalta
	# salin perälle näyttävät seinän ja oven, eivät taivasta.
	var panel := Color(0.86, 0.8, 0.66)
	for seg in [[-5.1, 7.8], [5.1, 7.8]]:
		B.mesh(_G, B.boxm(Vector3(seg[1], 3.8, 0.12)), Vector3(seg[0], 1.9, 6.02), panel)
	B.mesh(_G, B.boxm(Vector3(2.4, 1.4, 0.12)), Vector3(0, 3.1, 6.02), panel)
	B.mesh(_G, B.boxm(Vector3(18.0, 1.0, 0.04)), Vector3(0, 0.5, 5.94), Color(0.45, 0.3, 0.18))
	B.mesh(_G, B.boxm(Vector3(2.44, 2.44, 0.06)), Vector3(0, 1.22, 6.0), Color(0.42, 0.27, 0.15))  # pariovi
	B.mesh(_G, B.boxm(Vector3(0.03, 2.3, 0.08)), Vector3(0, 1.15, 5.98), Color(0.3, 0.18, 0.1))
	for z in CHAIR_ROWS:
		for x in CHAIR_X:
			_chair(Vector3(x, 0, z))
	_build_stand()
	_build_harmooni()
	# Hahmot: Sinikka, kuoro, yleisö.
	sinikka = _person(Looks.sinikka_seura(), SINIKKA_AT, Vector3(0, 0, 1))
	for i in CHOIR.size():
		var look: Dictionary = CHOIR[i].duplicate()
		var male := not look.has("model")
		look["shirt"] = Color(0.95, 0.94, 0.9) if not male else Color(0.92, 0.93, 0.95)
		look["pants"] = Color(0.1, 0.1, 0.14)
		look["shoes"] = Color(0.08, 0.07, 0.07)
		look["shoe"] = "nauhakenka" if male else "kavelykenka"
		var a: Array = CHOIR_AT[i]
		var c := _person(look, Vector3(a[0], RISER_Y if a[2] else STAGE_Y, a[1]), Vector3(0, 0, 1))
		choir.append(c)
		var f := Node3D.new()
		_G.add_child(f)
		B.mesh(f, B.boxm(Vector3(0.24, 0.32, 0.018)), Vector3.ZERO, Color(0.06, 0.06, 0.07))
		B.mesh(f, B.boxm(Vector3(0.21, 0.29, 0.004)), Vector3(0, 0, 0.011), Color(0.95, 0.93, 0.86))  # nuottisivu laulajaan päin
		for k in 5:
			B.mesh(f, B.boxm(Vector3(0.18, 0.002, 0.002)), Vector3(0, 0.1 - k * 0.045, 0.014), Color(0.2, 0.2, 0.2))
		_folders[c] = f
	annaliisa = _sit(Looks.ANNA_LIISA, -2.6, 0)
	hilkka = _sit(HILKKA, -1.8, 0)
	me = _sit(Looks.player(), -1.0, 0)
	pekka = _sit(Looks.PEKKA, 1.0, 0)
	arto = _sit(Looks.ARTO, 1.8, 0)
	tauno = _sit(TAUNO, 2.6, 0)
	Looks.hunch(hilkka, 0.15)
	var ex := [[Looks.AKKA, -3.4, 1], [HILKKA, -1.0, 1], [Looks.AKKA, 1.8, 1], [TAUNO, 3.4, 1]]
	for e: Array in ex:
		var look: Dictionary = (e[0] as Dictionary).duplicate()
		look["shirt"] = [Color(0.3, 0.45, 0.6), Color(0.6, 0.5, 0.3), Color(0.45, 0.25, 0.3), Color(0.35, 0.4, 0.3)][extras.size()]
		extras.append(_sit(look, e[1], e[2]))


## Taitettava puutuoli: istuin, selkänoja ja metallijalat. Tuolin etu -Z (lavalle päin).
func _chair(at: Vector3) -> void:
	var wood := Color(0.55, 0.36, 0.2)
	var metal := Color(0.25, 0.25, 0.27)
	B.mesh(_G, B.boxm(Vector3(0.44, 0.03, 0.42)), at + Vector3(0, 0.45, 0.02), wood)
	B.mesh(_G, B.boxm(Vector3(0.44, 0.22, 0.025)), at + Vector3(0, 0.78, 0.25), wood)
	for sx in [-0.2, 0.2]:
		B.mesh(_G, B.boxm(Vector3(0.022, 0.92, 0.022)), at + Vector3(sx, 0.46, 0.24), metal)
		B.mesh(_G, B.boxm(Vector3(0.022, 0.45, 0.022)), at + Vector3(sx, 0.225, -0.17), metal)


## Nuottiteline Sinikan edessä: jalka, kolme jalkaa ja kalteva hylly, jolla kanttorin nuottiarkki teipillä yhteen.
func _build_stand() -> void:
	var s := Node3D.new()
	_G.add_child(s)
	s.position = STAND_AT
	s.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	var metal := Color(0.12, 0.12, 0.13)
	B.mesh(s, B.cyl(0.012, 0.012, 1.0, 8), Vector3(0, 0.55, 0), metal)
	for k in 3:
		var a := k * TAU / 3.0
		var leg := B.mesh(s, B.boxm(Vector3(0.015, 0.015, 0.3)), Vector3(sin(a) * 0.12, 0.04, cos(a) * 0.12), metal)
		leg.rotation.y = a
	var desk := Node3D.new()
	s.add_child(desk)
	desk.position = Vector3(0, 1.08, 0)
	desk.rotation.x = deg_to_rad(-30.0)
	B.mesh(desk, B.boxm(Vector3(0.5, 0.34, 0.01)), Vector3.ZERO, metal)
	B.mesh(desk, B.boxm(Vector3(0.5, 0.03, 0.04)), Vector3(0, -0.17, -0.02), metal)
	# Puolikkaat: vasen valkoinen (harmoonin palkeesta), oikea kellastunut ja ruskeapilkkuinen (Pirtin arkisto).
	B.mesh(desk, B.boxm(Vector3(0.2, 0.28, 0.003)), Vector3(-0.1, 0.0, -0.008), Color(0.93, 0.9, 0.82))
	B.mesh(desk, B.boxm(Vector3(0.2, 0.28, 0.003)), Vector3(0.1, 0.0, -0.008), Color(0.86, 0.76, 0.52))
	for sp in [Vector3(0.14, 0.06, -0.011), Vector3(0.06, -0.08, -0.011), Vector3(0.17, -0.1, -0.011)]:
		B.mesh(desk, B.boxm(Vector3(0.018, 0.014, 0.001)), sp, Color(0.55, 0.38, 0.2))
	for k in 5:
		for side in [-1.0, 1.0]:
			B.mesh(desk, B.boxm(Vector3(0.17, 0.002, 0.001)), Vector3(side * 0.1, 0.09 - k * 0.04, -0.011), Color(0.2, 0.18, 0.15))
	var tape := B.mesh(desk, B.boxm(Vector3(0.035, 0.3, 0.001)), Vector3(0, 0, -0.012), Color(0.95, 0.92, 0.75))
	(tape.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(tape.material_override as StandardMaterial3D).albedo_color.a = 0.6
	_props.append(s)


## Vanha harmooni: pähkinäpuinen runko, koristeltu yläosa, koskettimisto C3..B5 (koskettimet erikseen, painuvat),
## kansi saranalla koskettimien takana, rekisterinupit ja kaksi poljinta. Koskettimet paikallisella -Z-puolella.
func _build_harmooni() -> void:
	harmooni = Node3D.new()
	_G.add_child(harmooni)
	harmooni.position = HARMOONI
	harmooni.rotation.y = B.yaw_to(HARM_FACE)
	var wood := Color(0.36, 0.2, 0.11)
	var dark := Color(0.22, 0.12, 0.06)
	B.mesh(harmooni, B.boxm(Vector3(1.12, 0.66, 0.5)), Vector3(0, 0.36, 0.04), wood)  # alakaappi
	B.mesh(harmooni, B.boxm(Vector3(1.16, 0.05, 0.56)), Vector3(0, 0.03, 0.04), dark)  # jalusta
	B.mesh(harmooni, B.boxm(Vector3(1.16, 0.04, 0.4)), Vector3(0, KEY_Y - 0.03, -0.06), dark)  # koskettimiston pohja
	B.mesh(harmooni, B.boxm(Vector3(1.12, 0.62, 0.2)), Vector3(0, KEY_Y + 0.3, 0.2), wood)  # yläosa
	B.mesh(harmooni, B.boxm(Vector3(1.2, 0.06, 0.26)), Vector3(0, KEY_Y + 0.63, 0.2), dark)  # karniisi
	var crown := B.mesh(harmooni, PrismMesh.new(), Vector3(0, KEY_Y + 0.76, 0.2), dark)
	crown.scale = Vector3(0.7, 0.2, 0.08)
	for sx in [-0.59, 0.59]:  # sivupäädyt koskettimien vieressä
		B.mesh(harmooni, B.boxm(Vector3(0.04, 0.12, 0.42)), Vector3(sx, KEY_Y + 0.03, -0.07), wood)
	# Peilipaneeli ja koristeleikkaus yläosassa.
	B.mesh(harmooni, B.boxm(Vector3(0.7, 0.32, 0.01)), Vector3(0, KEY_Y + 0.36, 0.095), Color(0.5, 0.32, 0.18))
	for k in 7:
		B.mesh(harmooni, B.sphere(0.018, 8), Vector3(-0.3 + k * 0.1, KEY_Y + 0.36, 0.088), Color(0.62, 0.45, 0.25))
	# Rekisterinupit rivissä koskettimiston takana.
	for k in 8:
		var x := -0.42 + k * 0.12
		B.mesh(harmooni, B.cyl(0.012, 0.012, 0.04, 8), Vector3(x, KEY_Y + 0.1, 0.085), Color(0.9, 0.86, 0.78), Vector3(90, 0, 0))
	# Koskettimet: valkoiset 21 kpl, mustat niiden väliin.
	var white_w := 0.042
	var whites := 0
	for i in KEY_COUNT:
		if not _black(FIRST_MIDI + i):
			whites += 1
	var x0 := -white_w * whites / 2.0 + white_w / 2.0
	var wi := 0
	for i in KEY_COUNT:
		var midi := FIRST_MIDI + i
		var key: MeshInstance3D
		var y: float
		if _black(midi):
			y = KEY_Y + 0.022
			key = B.mesh(harmooni, B.boxm(Vector3(0.024, 0.02, 0.085)), Vector3(x0 + (wi - 0.5) * white_w, y, -0.12), Color(0.06, 0.05, 0.05))
		else:
			y = KEY_Y + 0.008
			key = B.mesh(harmooni, B.boxm(Vector3(white_w - 0.004, 0.018, 0.14)), Vector3(x0 + wi * white_w, y, -0.15), Color(0.95, 0.92, 0.84))
			wi += 1
		_keys.append([key, y, midi])
	# Kansi: sarana koskettimien takana, levossa koskettimien päällä (rotation.x 0), auki pystyssä.
	_lid = Node3D.new()
	harmooni.add_child(_lid)
	_lid.position = Vector3(0, KEY_Y + 0.05, -0.02)
	B.mesh(_lid, B.boxm(Vector3(1.12, 0.018, 0.22)), Vector3(0, 0, -0.11), wood.lightened(0.05))
	B.mesh(_lid, B.boxm(Vector3(1.12, 0.03, 0.02)), Vector3(0, -0.01, -0.22), dark)
	# Polkimet: kaksi mattoverhoiltua poljinta alhaalla edessä.
	for sx in [-0.17, 0.17]:
		var p := Node3D.new()
		harmooni.add_child(p)
		p.position = Vector3(sx, 0.1, -0.21)
		B.mesh(p, B.boxm(Vector3(0.22, 0.025, 0.3)), Vector3(0, 0, -0.1), dark)
		B.mesh(p, B.boxm(Vector3(0.2, 0.006, 0.26)), Vector3(0, 0.015, -0.1), Color(0.5, 0.12, 0.1))
		p.rotation.x = 0.35
		_pedals.append(p)
	# Tyhjä jakkara koskettimien edessä.
	B.mesh(harmooni, B.cyl(0.17, 0.17, 0.05, 14), Vector3(0, 0.5, -0.62), wood)
	for k in 3:
		var a := k * TAU / 3.0
		B.mesh(harmooni, B.cyl(0.015, 0.02, 0.48, 6), Vector3(sin(a) * 0.11, 0.24, -0.62 + cos(a) * 0.11), dark)
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0, KEY_Y + 0.3, -0.35)
	_glow.omni_range = 1.6
	_glow.light_color = Color(1.0, 0.82, 0.45)
	_glow.light_energy = 0.0
	harmooni.add_child(_glow)


static func _black(midi: int) -> bool:
	return (midi % 12) in [1, 3, 6, 8, 10]


## Kanttorilan ikkunoiden kajo: talo on vanha _house-malli (world.gd _house), jonka julkisivun ikkunat ovat paikoissa
## x = -l/2 + l*(i+0,5)/n (n = max(2, int(l/3,6))), ovi paikassa n/2, keskikorkeus 1,75 m. Kehys on julkisivun
## juurisolmu world.kanttorila_root (sama suunta kuin talolla: -Z ulos pihalle). Jokaisen ikkunan lasin päälle hehkuva
## ruutu ristikkoineen ja valo pihalle; aamenessa ne himmenevät.
var _win_x := 0.0
var _win_mats: Array[StandardMaterial3D] = []


func _build_kanttorila() -> void:
	if world == null or not ("kanttorila_root" in world) or world.kanttorila_root == null:
		return
	var l: float = world.kanttorila_l if world.kanttorila_l > 0.0 else 8.0
	_K = Node3D.new()
	(world.kanttorila_root as Node3D).add_child(_K)
	_props.append(_K)
	var n := maxi(2, int(l / 3.6))
	var door_i := n / 2
	var white := Color(0.92, 0.92, 0.9)
	var first := true
	for i in n:
		if i == door_i:
			continue
		var x := -l / 2.0 + l * (i + 0.5) / n
		if first or absf(x) < absf(_win_x):
			_win_x = x
		first = false
		var glass := B.mesh(_K, B.boxm(Vector3(1.3, 1.1, 0.01)), Vector3(x, 1.75, -0.085), Color(1.0, 0.78, 0.4))
		var m := glass.material_override as StandardMaterial3D
		m.emission_enabled = true
		m.emission = Color(1.0, 0.7, 0.32)
		m.emission_energy_multiplier = 2.0
		_win_mats.append(m)
		B.mesh(_K, B.boxm(Vector3(0.07, 1.1, 0.02)), Vector3(x, 1.75, -0.1), white)
		B.mesh(_K, B.boxm(Vector3(1.3, 0.06, 0.02)), Vector3(x, 1.9, -0.1), white)
	_window_light = OmniLight3D.new()
	_window_light.position = Vector3(_win_x, 1.75, -1.0)
	_window_light.omni_range = 4.5
	_window_light.light_color = Color(1.0, 0.72, 0.38)
	_window_light.light_energy = 1.2
	_K.add_child(_window_light)


## Hehkuvan ikkunan keskikohta maailmassa (testi mittaa, onko se kuvassa).
func window_point() -> Vector3:
	return _K.to_global(Vector3(_win_x, 1.75, -0.085)) if _K != null else Vector3.ZERO


func _set_window(k: float) -> void:
	window_glow = k
	for m in _win_mats:
		m.emission_energy_multiplier = 2.0 * k
		m.albedo_color = Color(0.12, 0.17, 0.24).lerp(Color(1.0, 0.78, 0.4), k)  # sammunut = talon tumma lasi
	if _window_light != null:
		_window_light.light_energy = 1.2 * k


func _person(look: Dictionary, at: Vector3, face: Vector3) -> Node3D:
	var c: Node3D = Looks.make(_G, look)
	c.position = at
	c.rotation.y = B.yaw_to(face)
	c.play("Idle", 0.0)
	_props.append(c)
	return c


func _sit(look: Dictionary, x: float, row: int) -> Node3D:
	var at := Vector3(x, 0.02, float(CHAIR_ROWS[row]))
	var c := _person(look, at, Vector3(0, 0, -1))
	c.play("Sitting_Idle", 0.0)
	_seat[c] = at
	audience.append(c)
	return c


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	for c in [sinikka] + choir:
		c.clear_ik()
		c.set_override("spine_01", Vector3.RIGHT, 0.0)
		c.set_override("spine_03", Vector3.RIGHT, 0.0)
		c.set_override("neck_01", Vector3.RIGHT, 0.0)
	for c: Node3D in audience:
		c.clear_ik()
	match p:
		"sali":
			_story = "Viikon päästä seuraintalolla. Kuoro on harjoitellut kanttorin virttä joka ilta."
		"laulu":
			_story = ""
			_tune_t = 0.0
			_choir_snd.play()
			sinikka.rotation.y = B.yaw_to(Vector3(0, 0, -1))
		"harmooni":
			_story = ""
			_tune_t = 7.0
			if not _choir_snd.playing:
				_choir_snd.play(7.0)
			_organ_snd.play(7.0)
		"aamen":
			_story = ""
			_tune_t = 13.0
			_set_lid(1.0)
		"otsikko":
			_story = ""
			_tune_t = -1.0
			_choir_snd.stop()
			_organ_snd.stop()
			_set_lid(0.0)
			_press([])
			_glow.light_energy = 0.0
			_set_window(0.0)
			sinikka.rotation.y = B.yaw_to(Vector3(0, 0, 1))
			for c: Node3D in audience:  # nousevat seisomaan tuolien eteen
				c.play("Idle", 0.25)
				c.position = _seat[c] + Vector3(0, -0.02, -0.38)
				c.rotation.y = B.yaw_to(Vector3(0, 0, -1))
			Sfx.play("win", -6.0, 0.95)


func _process(delta: float) -> void:
	_t += delta
	if _tune_t >= 0.0:
		_tune_t += delta
	if Input.is_action_just_pressed("interact") and (phase != "sali" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"sali":
			_step_sali()
		"laulu":
			_step_laulu()
		"harmooni":
			_step_harmooni()
		"aamen":
			_step_aamen()
		"otsikko":
			_step_otsikko()
	_hold_folders()
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
	_choir_snd.stop()
	_organ_snd.stop()
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	if is_instance_valid(hall) and hall.has_method("concert"):
		hall.concert(false)
	for nd in _was_visible:
		if is_instance_valid(nd):
			(nd as Node3D).visible = _was_visible[nd]
	finished.emit()
	queue_free()


func _step_sali() -> void:
	# Leveä kuva salin perältä: tuolirivit, kuoro lavalla, Sinikka ja harmooni vasemmalla.
	sinikka.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	if _t > 0.6 and _t < 2.4:
		_bub[pekka] = "Onko tää se kummitusvirsi?"
	if _t >= 2.4:
		_bub.erase(pekka)
		_bub[sinikka] = "Kanttorin virsi. Ensimmäistä kertaa sitten kanttorin."
		sinikka.play("Idle_Talking", 0.3)
	var look := _H(-0.6, 1.25, -2.6)
	var eye := _H(0.9, 2.35, 5.4)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 12.2))


func _step_laulu() -> void:
	sinikka.play("Idle", 0.3)
	_conduct(1.0)
	if _t < 3.8:
		# Kuoron kasvot ja Sinikan nostetut kädet sivulta.
		var look := _H(-0.2, 1.75, -4.45)
		var eye := _H(2.7, 1.55, -1.5)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.4))
	else:
		# Eturivi lavan reunalta: Hilkka pyyhkii silmää.
		var k := clampf((_t - 4.2) / 0.6, 0.0, 1.0)
		_wipe_eye(hilkka, k)
		if _t > 4.4:
			_bub[hilkka] = "Niin se meni. Juuri noin se meni."
		var look := _H(-1.7, 0.95, 0.7)
		var eye := _H(-4.4, 1.3, -0.75)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.4))


func _step_harmooni() -> void:
	_set_lid(clampf(_t / 1.2, 0.0, 1.0))
	_play_keys()
	_glow.light_energy = 0.45 * clampf(_t / 1.0, 0.0, 1.0) * (0.85 + 0.15 * sin(_t * 9.0))
	if _t < 3.2:
		_conduct(1.0)
		# Lähikuva harmoonista: kansi aukeaa, koskettimet painuvat, jakkara tyhjä.
		var look := harmooni.to_global(Vector3(0.0, KEY_Y + 0.08, -0.12))
		var eye := harmooni.to_global(Vector3(0.42, KEY_Y + 0.62, -0.95))
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 1.45))
	else:
		# 3,2-4,8 s eturivi kääntyy harmooniin päin (kuva lavan reunalta yleisöön), 4,8-6 s Sinikka kääntyy harmooniin,
		# nyökkää ja jatkaa (kuva harmoonin puolelta: Sinikan kasvot, kuoro taustalla).
		for c: Node3D in audience:
			var v: Vector3 = HARMOONI - c.position
			v.y = 0.0
			var turn := clampf((_t - 3.25 - fposmod(c.position.x * 0.37, 0.4)) / 0.5, 0.0, 1.0)
			c.rotation.y = B.yaw_to(Vector3(0, 0, -1).lerp(v.normalized(), 0.5 * turn).normalized())
		if _t < 4.8:
			_conduct(1.0)
			if _t > 3.35 and _t < 4.1:
				_bub[annaliisa] = "Kuka sitä soittaa?"
			if _t >= 4.1:
				_bub.erase(annaliisa)
				_bub[hilkka] = "Kanttori."
			var look := _H(-2.0, 0.95, 0.8)
			var eye := _H(-0.7, 1.45, -2.2)
			_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.4))
		else:
			_bub.clear()
			var k := clampf((_t - 4.8) / 0.35, 0.0, 1.0)
			var back := clampf((_t - 5.65) / 0.3, 0.0, 1.0)
			var to_h := (HARMOONI - SINIKKA_AT).normalized()
			sinikka.rotation.y = B.yaw_to(Vector3(0, 0, -1).lerp(to_h, 0.8 * k * (1.0 - back)).normalized())
			if _t > 5.1 and _t < 5.65:
				sinikka.set_override("neck_01", Vector3.RIGHT, 0.3 * sin((_t - 5.1) / 0.55 * PI))
			_conduct(1.0)  # johtaa koko ajan, vain katse käy harmoonissa
			var look := _H(0.0, 1.45, -2.75)
			var eye := _H(-3.3, 1.55, -1.45)
			_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.0))


func _step_aamen() -> void:
	# Viimeinen sointu 0-2 s, Sinikka katkaisee 2,0 s, kansi laskeutuu 2,2-3,4 s. Kanttorilan piha 3,6 s alkaen.
	if _t < 2.0:
		_conduct(1.0, true)
		_play_keys()
		_glow.light_energy = 0.45
	else:
		if not cut_off:
			cut_off = true
			_choir_snd.stop()
			_organ_snd.stop()
			_press([])
		_cutoff(clampf((_t - 2.0) / 0.25, 0.0, 1.0))
		_set_lid(1.0 - clampf((_t - 2.2) / 1.2, 0.0, 1.0))
		_glow.light_energy = 0.45 * (1.0 - clampf((_t - 2.0) / 1.0, 0.0, 1.0))
	for c: Node3D in audience:
		c.rotation.y = B.yaw_to(Vector3(0, 0, -1))
	if _t < 3.6 or _K == null:
		var look := _H(-1.9, 1.2, -3.3)
		var eye := _H(1.1, 1.45, 0.1)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), 8.0))
		return
	_story = "Samaan aikaan Kanttorilassa urut vaikenivat."
	if not _once_window:
		_once_window = true
		_organ_snd.volume_db = -16.0
		_organ_snd.play(13.0)
	var k := 1.0 - clampf((_t - 4.0) / 2.0, 0.0, 1.0)
	_set_window(k)
	_organ_snd.volume_db = -16.0 - 30.0 * (1.0 - k)
	var look2 := _K.to_global(Vector3(_win_x * 0.55, 1.85, 0.0))
	var eye2 := _K.to_global(Vector3(_win_x * 0.55 - signf(_win_x) * 2.4, 1.6, -8.5))
	_cam.current = true
	_cam_at(eye2, look2, _fov_w(eye2.distance_to(look2), 8.5))


var _once_window := false


func _step_otsikko() -> void:
	# Sali seisoo ja taputtaa, kuoro ja Sinikka kumartavat. Kuva lavan oikealta: kasvot näkyvät.
	var bow := sin(clampf((_t - 0.6) / 1.6, 0.0, 1.0) * PI)
	sinikka.set_override("spine_01", Vector3.RIGHT, -0.35 * bow)
	sinikka.set_override("spine_03", Vector3.RIGHT, -0.25 * bow)
	for c: Node3D in choir:
		c.set_override("spine_01", Vector3.RIGHT, -0.22 * bow)
		c.set_override("neck_01", Vector3.RIGHT, 0.2 * bow)
	for i in audience.size():
		_clap(audience[i], _t * 7.0 + i * 0.9)
	var look := _H(-0.8, 1.15, -1.2)
	var eye := _H(5.4, 2.3, -4.3)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 10.5))


# --- Liike ---------------------------------------------------------------------------

## Sinikan johtaminen: kolmijakoinen lyönti (alas, oikealle, ylös) virren tahdissa, vasen käsi peilinä alempana.
## w = kuinka isosti (0 = kädet alhaalla). hold = viimeisen soinnun pito (kädet ylhäällä levällään).
func _conduct(w: float, hold := false) -> void:
	var c := sinikka
	var beat := maxf(_tune_t, 0.0) / 0.5
	var ph := fposmod(beat, 3.0)
	var shape := [Vector2(0.0, -0.1), Vector2(0.16, -0.02), Vector2(0.02, 0.14)]
	var a: Vector2 = shape[int(ph)]
	var b: Vector2 = shape[(int(ph) + 1) % 3]
	var f := fposmod(ph, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var p := a.lerp(b, f)
	if hold:
		p = Vector2(0.12, 0.2)
	for side in ["r", "l"]:
		var sh: Vector3 = c.bone_position("upperarm_" + side)
		var s := signf(sh.x) if sh.x != 0.0 else 1.0
		var rest := sh + Vector3(s * 0.12, -0.45, -0.05)
		var m := 1.0 if side == "r" else 0.75
		var up := sh + Vector3(s * (0.1 + 0.6 * p.x * m), 0.02 + p.y * m, -0.3)  # kyynärpäät koukussa, kädet rinnan edessä
		c.set_ik("arm_" + side, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, rest.lerp(up, w),
			sh + Vector3(s * 0.6, -0.45, 0.15))
		c.set_open_hand(side, 0.8 * w)


## Katkaisu: kädet sulkeutuvat ja laskeutuvat hieman (k 0..1).
func _cutoff(k: float) -> void:
	var c := sinikka
	for side in ["r", "l"]:
		var sh: Vector3 = c.bone_position("upperarm_" + side)
		var s := signf(sh.x) if sh.x != 0.0 else 1.0
		var hi := sh + Vector3(s * 0.34, 0.22, -0.38)
		var lo := sh + Vector3(s * 0.2, -0.05, -0.36)
		c.set_ik("arm_" + side, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, hi.lerp(lo, k), sh + Vector3(s * 0.5, -0.3, 0.1))
		c.set_open_hand(side, 0.8 * (1.0 - k))


func _wipe_eye(c: Node3D, k: float) -> void:
	if k <= 0.0:
		return
	var head: Vector3 = c.bone_position("Head")
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.1, -0.35, -0.2)
	var eye := head + Vector3(s * 0.04, 0.06, -0.11) + Vector3(0, 0.01 * sin(_t * 6.0), 0)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", rest.lerp(eye, k), sh + Vector3(s * 0.4, -0.35, 0.1))


func _clap(c: Node3D, ph: float) -> void:
	var gap := 0.03 + 0.09 * absf(sin(ph))
	for side in ["r", "l"]:
		var sh: Vector3 = c.bone_position("upperarm_" + side)
		var s := signf(sh.x) if sh.x != 0.0 else 1.0
		var mid := Vector3(0, sh.y + 0.02, sh.z - 0.3)
		c.set_ik("arm_" + side, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, mid + Vector3(s * gap, 0, 0),
			sh + Vector3(s * 0.5, -0.35, 0.05))
		c.set_open_hand(side, 1.0)


## Kuorolaisten kansiot rinnan edessä kahdella kädellä (kumarruksessa kansio laskee).
func _hold_folders() -> void:
	for c: Node3D in choir:
		var f: Node3D = _folders[c]
		var neck: Vector3 = c.bone_position("neck_01")
		var center_l := neck + Vector3(0, -0.32, -0.3)
		var basis: Basis = c.global_basis
		f.global_position = c.to_global(center_l)
		f.global_basis = basis * Basis(Vector3.RIGHT, deg_to_rad(-25.0))
		for side in ["r", "l"]:
			var sh: Vector3 = c.bone_position("upperarm_" + side)
			var s := signf(sh.x) if sh.x != 0.0 else 1.0
			var edge := center_l + Vector3(s * 0.115, -0.1, 0.05)  # alakulmat (kansio kallistuu yläreuna eteen)
			c.set_ik("arm_" + side, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, edge, sh + Vector3(s * 0.45, -0.3, 0.2))


## Harmoonin koskettimet ja polkimet virren tahdissa: melodia ja oktaavia alempi basso.
func _play_keys() -> void:
	var n := _note_at(_tune_t)
	if n < 0:
		_press([])
		return
	var m := TUNE_MIDI + n
	_press([m, m - 12, m - 12 + 7 if (m - 5) % 12 < 6 else m - 12 + 3])
	for i in _pedals.size():
		_pedals[i].rotation.x = 0.35 + 0.12 * sin(_tune_t * 4.2 + i * PI)


func _press(midis: Array) -> void:
	pressed = midis
	for k: Array in _keys:
		var key: MeshInstance3D = k[0]
		var down: bool = int(k[2]) in midis
		key.position.y = float(k[1]) - (0.009 if down else 0.0)
		key.rotation.x = 0.06 if down else 0.0


## Virren sävel (puolisävelet A3:sta) hetkellä t virren alusta, -1 = ohi.
static func _note_at(t: float) -> int:
	var acc := 0.0
	for n: Array in KanttoriLegenda.TUNE:
		acc += float(n[1])
		if t < acc:
			return int(n[0])
	return -1


func _set_lid(k: float) -> void:
	lid_open = k
	_lid.rotation.x = deg_to_rad(100.0) * k  # kansi kääntyy taakse pystyyn (etureuna ylös)


# --- Kehys, kamera ------------------------------------------------------------------

## Kuorolaisen kauimman käden etäisyys kansion reunasta (kansion paikallisessa laatikossa), testi mittaa.
func folder_gap(c: Node3D) -> float:
	var f: Node3D = _folders[c]
	var worst := 0.0
	for side in ["r", "l"]:
		var hp := f.to_local(_hand_of(c, side))
		var q := Vector3(clampf(hp.x, -0.12, 0.12), clampf(hp.y, -0.16, 0.16), clampf(hp.z, -0.01, 0.01))
		worst = maxf(worst, hp.distance_to(q))
	return worst


## Käden keskikohta (ranne ja etusormen tyvi) maailmassa: testi mittaa sen.
func _hand_of(c: Node3D, side := "r") -> Vector3:
	return c.to_global((c.bone_position("hand_" + side) + c.bone_position("index_01_" + side)) / 2.0)


func _H(x: float, y: float, z: float) -> Vector3:
	return _G.to_global(Vector3(x, y, z))


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
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.03, 0.08, 0.22 * a))
		var y := vs.y * 0.22
		_draw_icon(Vector2(vs.x / 2.0, y - 84.0), a)
		var title := "KANTTORIN VIRSI"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.1, 0.06, 0.2, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(1.0, 0.88, 0.45, a))
		var sr := Rect2(vs.x / 2.0 - 440, vs.y - 158.0, 880, 84)
		_ui.draw_rect(sr, Color(0.06, 0.04, 0.08, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Kanttorilan yösävel löysi nuottinsa: Sinikan kuoro lauloi virren seuraintalolla",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(1.0, 0.85, 0.55, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "ja urut vaikenivat.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Nuottiarkki teipillä yhteen ja kahdeksasosanuotti sen yllä.
func _draw_icon(c: Vector2, a: float) -> void:
	var ink := Color(0.15, 0.1, 0.08, a)
	_ui.draw_rect(Rect2(c + Vector2(-34, -18), Vector2(34, 44)), Color(0.95, 0.92, 0.84, a))
	_ui.draw_rect(Rect2(c + Vector2(0, -18), Vector2(34, 44)), Color(0.88, 0.78, 0.55, a))
	_ui.draw_rect(Rect2(c + Vector2(-34, -18), Vector2(68, 44)), ink, false, 2.0)
	for k in 5:
		_ui.draw_line(c + Vector2(-30, -10 + k * 7), c + Vector2(30, -10 + k * 7), Color(0.3, 0.25, 0.2, a), 1.0)
	_ui.draw_rect(Rect2(c + Vector2(-4, -20), Vector2(8, 48)), Color(1.0, 0.97, 0.8, 0.7 * a))
	var n := c + Vector2(26, -34)
	_ui.draw_circle(n, 7.0, Color(1.0, 0.88, 0.45, a))
	_ui.draw_line(n + Vector2(6, 0), n + Vector2(6, -30), Color(1.0, 0.88, 0.45, a), 3.0)
	_ui.draw_line(n + Vector2(6, -30), n + Vector2(16, -20), Color(1.0, 0.88, 0.45, a), 3.0)
