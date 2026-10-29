extends Node3D
## Paltaniemen kuvakirkko (retket.gd "paltaniemi"): taskukohtaus kuten retki_pakkahuone.gd. Kävely player_walker.gd:llä.
## Kirkon sisus: penkkirivit, alttari, saarnastuoli ja takaseinällä kolme maalausta. Maalauksille E avaa piilokuvaetsinnän
## (kuvakirkko_game.gd, main.gd käynnistää). Suntio kertoo kirkosta. Faktat (1700-luvun maalaukset, Kajaanin Paltaniemi) "sanotaan"-muodossa,
## tarkistettava; maalaukset ovat tyyliteltyjä, eivät kopioita.
## Paikallinen -Z = alttari ja maalaukset (takaseinä), +Z = ovi ja kamera. Penkit katsovat -Z:aan: -Z = penkin etupuoli, selkänoja +Z:ssa.
## Hahmon etu = -Z (basis * -Z); suntio katsoo +Z:aan (kävijöitä kohti).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")
const KuvakirkkoGame := preload("res://scripts/kuvakirkko_game.gd")

const HALF := Vector2(8.0, 6.0)
const SEAT := 0.46  # istuinlaudan yläpinta
const PX_M := 0.0055  # maalaustekstuurin metriä per pikseli
const PEW_L := 4.0  # penkin pituus (x)
const PEW_ROWS := [-1.6, 0.2, 2.0]  # penkkien z (istuimen keskilinja)

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var spot := ""
var legenda: RefCounted
var spots := {
	"ovi": [Vector3(6.8, 0, 4.8), "[E] Ulos: taksille takaisin lähtöpaikkaan"],
	"suntio": [Vector3(-3.6, 0, -3.2), "[E] Juttele suntion kanssa"],
	"maalaukset": [Vector3(0.0, 0, -3.2), "[E] Katso maalauksia (piilokuvaetsintä)"],
}
var _enter_frame := -1
var _verger: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
const BUBBLE_AT := Vector3(-7.2, 0.4, -2.0)  # maailmassa suntion vasemmalla lattialla: ei maalauksen eikä saapumisviestin (ruudun keskellä) päällä
const BUBBLE_FAR := 4.5  # kupla sulkeutuu, kun pelaaja kävelee tätä kauemmas suntiosta
const VERGER_LINES := ["Tämä on kuvakirkko: seinät ja katto on maalattu täyteen, sanotaan 1700-luvulla.",
	"Maalauksissa on pieniä yksityiskohtia. Lapset etsivät niitä, minä en enää löydä kaikkia.",
	"Kuusi kuvaa, kuulemma. Kala, kissa ja muuta. Käy katsomassa taulut."]
var _line := 0


func _ready() -> void:
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF.x + 0.6, -HALF.y + 2.2, HALF.x * 2.0 - 1.2, HALF.y * 2.0 - 2.6)]
	add_child(walker)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(-2.6, 0, -0.9)  # kyltti (5.9, 5.3) jää hahmon viereen, ei eteen
	walker.rotation.y = B.yaw_to(Vector3(-1, 0, -1))
	walker.visible = true
	walker.activate()


func leave() -> void:
	active = false
	walker.controls_enabled = false


func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


func say(text: String, t := 3.6) -> void:
	_bubble.text = text
	_bubble_t = t
	_verger.play("Idle_Talking", 0.2)


## Seuraava suntion repliikki kierrossa.
func next_line() -> String:
	_line = (_line + 1) % VERGER_LINES.size()
	return VERGER_LINES[_line]


func _process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble.text != "" and (_bubble_t <= 0.0 or (active and walker.position.distance_to(_verger.position) > BUBBLE_FAR)):
		_bubble.text = ""
		_verger.play("Idle", 0.3)
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	var p := walker.position
	var best := ""
	var bd := 1.8
	for id in spots:
		var d := Vector2(p.x - spots[id][0].x, p.z - spots[id][0].z).length()
		if d < bd:
			bd = d
			best = id
	hint = ""
	spot = best
	if best == "":
		return
	hint = spots[best][1]
	if best == "maalaukset" and legenda != null:
		hint = "[E] Katso maalauksia (löydetty %d/%d)" % [legenda.found.size(), legenda.TOTAL]
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	if best == "ovi":
		exited.emit()
	else:
		acted.emit(best)


# --- Rakennus -------------------------------------------------------------------------------

func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	return B.solid(self, size, pos, col)


## Kirkkopenkki (janttu.gd _build_bench -malli): sivulevyt, kolme istuinrimaa ja kaksi selkänojarimaa. Selkänojan tolpat ja rimat
## lasketaan samasta kallistuksesta (lean = tolpan suunta, face = etupinnan normaali). -Z = penkin etupuoli, selkänoja +Z:ssa.
func _pew(at: Vector3) -> void:
	var wood := Color(0.55, 0.36, 0.2)
	var tilt := 12.0
	var lean := Vector3(0, cos(deg_to_rad(tilt)), sin(deg_to_rad(tilt)))
	var face := Vector3(0, sin(deg_to_rad(tilt)), -cos(deg_to_rad(tilt)))
	var base := at + Vector3(0, SEAT - 0.04, 0.2)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (PEW_L / 2.0 - 0.04)
		B.mesh(self, B.boxm(Vector3(0.07, SEAT, 0.5)), at + Vector3(x, SEAT / 2.0, 0.0), wood.darkened(0.3))  # sivulevy
		B.mesh(self, B.boxm(Vector3(0.07, 0.9, 0.07)), base + Vector3(x, 0, 0) + lean * 0.45, wood.darkened(0.3), Vector3(tilt, 0, 0))  # selkänojan tolppa
	for k in 3:
		B.mesh(self, B.boxm(Vector3(PEW_L, 0.04, 0.14)), at + Vector3(0, SEAT - 0.02, -0.17 + k * 0.17), wood.darkened(0.04 * k))
	for k in 2:
		B.mesh(self, B.boxm(Vector3(PEW_L - 0.1, 0.16, 0.035)), base + lean * (0.3 + k * 0.28) + face * (0.035 + 0.0175), wood, Vector3(tilt, 0, 0))
	var sb := StaticBody3D.new()
	add_child(sb)
	sb.add_child(B.box_shape(Vector3(PEW_L, 1.0, 0.55), at + Vector3(0, 0.5, 0.1)))


## Maalaus seinällä: sama piirros kuin minipelissä (kuvakirkko_game.gd painting_viewport, kehys ja piilokuvat mukana) kvadilla ja ohut
## 3D-kehys. kind: taivas | arkki | puutarha. Kallistettu hieman kameraa kohti.
func _painting(c: Vector3, kind: String) -> void:
	var vp := KuvakirkkoGame.painting_viewport(kind)
	add_child(vp)
	var size := Vector2(vp.size) * PX_M
	var root := Node3D.new()
	root.position = c
	root.rotation_degrees.x = -25.0  # yläreuna taakse, taulu katsoo ylöspäin kameraa kohti
	add_child(root)
	B.mesh(root, B.boxm(Vector3(size.x + 0.1, size.y + 0.1, 0.08)), Vector3(0, 0, -0.02), Color(0.78, 0.6, 0.2))
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = vp.get_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material_override = mat
	quad.position = Vector3(0, 0, 0.03)
	root.add_child(quad)


func _build() -> void:
	var floor_c := Color(0.5, 0.36, 0.22)
	var wall_c := Color(0.9, 0.86, 0.74)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.15, 0.13, 0.1))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), floor_c)
	for i in 12:
		B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.004, 0.03)), Vector3(0, 0.001, -5.5 + i * 1.0), floor_c.darkened(0.2))
	B.mesh(self, B.boxm(Vector3(1.6, 0.005, HALF.y * 2.0 - 0.6)), Vector3(0, 0.003, 0.0), Color(0.62, 0.2, 0.2))  # punainen käytävämatto
	# Seinät: takaseinä (maalaukset) ja sivut; kamera +Z:ssa, etuseinää ei ole.
	_solid(Vector3(HALF.x * 2.0, 4.0, 0.3), Vector3(0, 2.0, -HALF.y), wall_c)
	for sx in [-1.0, 1.0]:
		_solid(Vector3(0.3, 4.0, HALF.y * 2.0), Vector3(sx * HALF.x, 2.0, 0), wall_c.darkened(0.04))
		B.mesh(self, B.boxm(Vector3(0.2, 1.1, HALF.y * 2.0 - 0.4)), Vector3(sx * (HALF.x - 0.16), 0.55, 0.0), Color(0.45, 0.3, 0.17))  # puulambri
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.12, 0.3)), Vector3(0, 0.06, -HALF.y + 0.15), wall_c.darkened(0.35))
	for wx in [-6.5, 6.5]:  # korkeat ikkunat takaseinällä
		B.mesh(self, B.boxm(Vector3(0.9, 2.0, 0.05)), Vector3(wx, 2.4, -HALF.y + 0.17), Color(0.6, 0.75, 0.85))
		B.mesh(self, B.boxm(Vector3(0.08, 2.1, 0.08)), Vector3(wx, 2.4, -HALF.y + 0.19), Color(0.9, 0.88, 0.8))
	# Kolme maalausta takaseinällä (keskimmäinen alttarin yllä).
	_painting(Vector3(-4.6, 2.35, -HALF.y + 0.28), "taivas")
	_painting(Vector3(0.0, 2.35, -HALF.y + 0.28), "arkki")
	_painting(Vector3(4.6, 2.35, -HALF.y + 0.28), "puutarha")
	# Kyltti takaseinällä ja oven infokyltti (iso fontti, kallistettu kameraa kohti).
	var title := B.sign_plate(self, "PALTANIEMEN KUVAKIRKKO", Color(0.2, 0.14, 0.09), Color(0.97, 0.9, 0.7), 0.3, 60, Color(0.78, 0.6, 0.2))
	title.position = Vector3(0.0, 3.6, -HALF.y + 0.4)
	title.rotation_degrees.x = -25.0
	B.sign_pole(self, Vector3(5.9, 0, 5.3), 1.3)
	var info := B.sign_plate(self, "KUVAKIRKKO\nSeinillä 6 piilokuvaa\nEtsi ne maalauksista", Color(0.2, 0.14, 0.09), Color(0.97, 0.9, 0.7), 0.36, 64, Color(0.78, 0.6, 0.2))
	info.position = Vector3(5.9, 1.5, 5.2)
	info.rotation_degrees.x = -35.0
	# Alttari: pöytä, liina, risti ja kynttilät.
	_solid(Vector3(2.0, 0.9, 0.7), Vector3(0, 0.45, -HALF.y + 0.8), Color(0.45, 0.3, 0.17))
	B.mesh(self, B.boxm(Vector3(2.1, 0.03, 0.8)), Vector3(0, 0.92, -HALF.y + 0.8), Color(0.95, 0.94, 0.9))
	B.mesh(self, B.boxm(Vector3(0.06, 0.45, 0.05)), Vector3(0, 1.17, -HALF.y + 0.8), Color(0.85, 0.7, 0.25))
	B.mesh(self, B.boxm(Vector3(0.26, 0.05, 0.05)), Vector3(0, 1.3, -HALF.y + 0.8), Color(0.85, 0.7, 0.25))
	for cx in [-0.7, 0.7]:
		B.mesh(self, B.cyl(0.04, 0.04, 0.3, 8), Vector3(cx, 1.09, -HALF.y + 0.8), Color(0.95, 0.9, 0.7))
		B.mesh(self, B.sphere(0.04, 6), Vector3(cx, 1.28, -HALF.y + 0.8), Color(1.0, 0.8, 0.3))
	# Saarnastuoli oikealla seinällä: jalka, kuori ja katos.
	var pul := Vector3(HALF.x - 0.9, 0, -2.8)
	_solid(Vector3(1.0, 1.1, 1.0), pul + Vector3(0, 1.55, 0), Color(0.5, 0.34, 0.2))
	B.mesh(self, B.boxm(Vector3(0.3, 1.0, 0.3)), pul + Vector3(0, 0.5, 0), Color(0.42, 0.28, 0.16))
	B.mesh(self, B.boxm(Vector3(1.2, 0.1, 1.2)), pul + Vector3(0, 2.4, 0), Color(0.42, 0.28, 0.16))
	# Penkit: kaksi sarjaa, kolme riviä.
	for z in PEW_ROWS:
		_pew(Vector3(-3.9, 0, z))
		_pew(Vector3(3.9, 0, z))
	# Suntio (katsoo +Z:aan) ja kasvit ovensuussa.
	_verger = Looks.make(self, {"shirt": Color(0.22, 0.22, 0.3), "pants": Color(0.2, 0.2, 0.24),
		"shoes": Color(0.12, 0.1, 0.08), "hair": "Hair_Buzzed", "hair_color": Color(0.7, 0.7, 0.72), "height": 1.74})
	_verger.position = Vector3(-3.6, 0, -4.4)
	_verger.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_verger.play("Idle", 0.0)
	_bubble = B.bubble(self, BUBBLE_AT, Color.WHITE, 0.9)
	# Valo.
	for lx in [-3.5, 3.5]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(lx, 3.4, 0.0)
		lamp.light_color = Color(1.0, 0.92, 0.75)
		lamp.light_energy = 0.8
		lamp.omni_range = 10.0
		add_child(lamp)
