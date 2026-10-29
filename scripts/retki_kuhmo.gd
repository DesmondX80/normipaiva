extends Node3D
## Kuhmon karhukätkö (retket.gd "kuhmo"): taskukohtaus kuten retki_tietokonemuseo.gd. Kävely player_walker.gd:llä.
## Takana puinen kätkö, jonka ikkunasta katsotaan niitylle; edessä penkki ja ikkunan luona [E] aloittaa kuvauksen (karhu_game.gd). Opas kertoo
## karhuista ja kuvaamisesta. Paikka ja aikataulut "sanotaan"-muodossa, tarkistettava; kätkö on tyylitelty.
## Paikallinen -Z = takaseinä ja niitty, +Z = ovi ja kamera. Opas katsoo +Z:aan. Penkki: -Z = penkin etupuoli (kasvot ikkunaan päin); penkki on suora,
## tolpat ja rimat samasta mitasta (ei kallistusta).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(8.0, 6.0)
const TILT := -25.0

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var spot := ""
var legenda: RefCounted
var spots := {
	"ovi": [Vector3(6.4, 0, 4.8), "[E] Ulos: taksille takaisin lähtöpaikkaan"],
	"opas": [Vector3(-3.6, 0, 1.0), "[E] Juttele oppaan kanssa"],
	"kyltti": [Vector3(3.6, 0, 3.4), "[E] Lue infokyltti"],
	"ikkuna": [Vector3(0.0, 0, -2.2), "[E] Kuvaa karhuja ikkunasta"],
}
var _enter_frame := -1
var _guide: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
const BUBBLE_AT := Vector3(-5.6, 0.4, 2.4)  # oppaan vasemmalla lattialla, ei hahmon päällä
const BUBBLE_FAR := 4.5
const GUIDE_LINES := ["Täällä istutaan hiljaa. Karhu tulee hämärässä, sanotaan, ja lähtee jos kuulee kahinaa.",
	"Etsimeen kannattaa saada karhu keskelle. Pystyssä seisova karhu katsoo suoraan kameraan, se on paras kuva.",
	"Kameran kanssa pitää olla selvin päin. Kuppi kädessä kuva tärähtää, ja karhu huomaa.",
	"Yleensä niitylle tulee yksi tai kaksi karhua illassa. Joskus ei yhtään, sanotaan."]
var _line := 0
var _sway_t := 0.0
var _bears: Array[Node3D] = []


func _ready() -> void:
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF.x + 0.6, -HALF.y + 2.6, HALF.x * 2.0 - 1.2, HALF.y * 2.0 - 3.0)]
	add_child(walker)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(-2.6, 0, -0.9)
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
	_guide.play("Idle_Talking", 0.2)


func next_line() -> String:
	_line = (_line + 1) % GUIDE_LINES.size()
	return GUIDE_LINES[_line]


func _process(delta: float) -> void:
	_bubble_t -= delta
	_sway_t += delta
	if _bubble.text != "" and (_bubble_t <= 0.0 or (active and walker.position.distance_to(_guide.position) > BUBBLE_FAR)):
		_bubble.text = ""
		_guide.play("Idle", 0.3)
	for i in _bears.size():  # kaukainen karhu kulkee niityllä
		_bears[i].position.x = -3.0 + sin(_sway_t * 0.12 + i * 2.0) * 9.0
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
	if best == "ikkuna" and legenda != null and legenda.paras > 0:
		hint = "[E] Kuvaa karhuja ikkunasta (paras kuva %d / 100)" % legenda.paras
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	if best == "ovi":
		exited.emit()
	else:
		acted.emit(best)


# --- Rakennus -------------------------------------------------------------------------------

func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	return B.solid(self, size, pos, col)


func _pine(pos: Vector3, h: float) -> void:
	B.mesh(self, B.cyl(0.14, 0.2, h * 0.4, 8), pos + Vector3(0, h * 0.2, 0), Color(0.3, 0.2, 0.12))
	for k in 3:
		B.mesh(self, B.cyl(0.02, 1.0 - k * 0.25, h * 0.4, 8), pos + Vector3(0, h * (0.5 + k * 0.2), 0), Color(0.1, 0.27 + k * 0.03, 0.15))


## Penkki: istuin ja selkänoja, neljä tolppaa. -Z = etupuoli (ikkunaan päin), selkänoja +Z-reunassa.
func _bench(c: Vector3, w: float) -> void:
	var wood := Color(0.5, 0.36, 0.22)
	B.mesh(self, B.boxm(Vector3(w, 0.06, 0.4)), c + Vector3(0, 0.45, 0), wood)
	B.mesh(self, B.boxm(Vector3(w, 0.3, 0.04)), c + Vector3(0, 0.75, 0.19), wood.darkened(0.1))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.mesh(self, B.boxm(Vector3(0.06, 0.45, 0.06)), c + Vector3(sx * (w / 2.0 - 0.08), 0.225, sz * 0.16), wood.darkened(0.25))


## Karhu (+X = nokka): runko, kyttyrä, pää kuonolla ja korvilla, neljä tassua.
func _bear_parts(bear: Node3D) -> void:
	var fur := Color(0.34, 0.23, 0.15)
	var dark := Color(0.2, 0.13, 0.09)
	var body := B.mesh(bear, B.sphere(0.5, 14), Vector3(0, 0.78, 0), fur)
	body.scale = Vector3(1.35, 0.9, 0.85)
	var hump := B.mesh(bear, B.sphere(0.4, 12), Vector3(0.35, 1.08, 0), fur.lightened(0.05))
	hump.scale = Vector3(1.0, 0.85, 0.95)
	B.mesh(bear, B.sphere(0.32, 12), Vector3(1.0, 0.92, 0), fur.lightened(0.08))  # pää
	var snout := B.mesh(bear, B.sphere(0.14, 10), Vector3(1.26, 0.84, 0), Color(0.6, 0.45, 0.33))
	snout.scale = Vector3(1.3, 0.9, 0.95)
	B.mesh(bear, B.sphere(0.05, 8), Vector3(1.42, 0.87, 0), Color(0.05, 0.04, 0.04))  # nenä
	for sz in [-1.0, 1.0]:
		B.mesh(bear, B.sphere(0.1, 8), Vector3(0.92, 1.2, sz * 0.2), dark)  # korva
		B.mesh(bear, B.sphere(0.04, 6), Vector3(1.2, 1.02, sz * 0.14), Color(0.05, 0.04, 0.04))  # silmä
		for sx in [-0.5, 0.65]:
			B.mesh(bear, B.cyl(0.2, 0.16, 0.55, 8), Vector3(sx, 0.3, sz * 0.3), dark)  # jalka
			var paw := B.mesh(bear, B.sphere(0.17, 8), Vector3(sx + 0.06, 0.06, sz * 0.3), dark)  # tassu
			paw.scale = Vector3(1.4, 0.6, 1.0)
	B.mesh(bear, B.sphere(0.09, 8), Vector3(-0.68, 0.85, 0), dark)  # häntä
	bear.scale = Vector3.ONE * 1.5


func _build() -> void:
	var grass := Color(0.3, 0.42, 0.22)
	var logc := Color(0.45, 0.3, 0.18)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.15, 0.2, 0.12))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), grass)
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.006, 1.2)), Vector3(0, 0.002, -4.2), Color(0.42, 0.36, 0.22))  # polku kätkön edessä
	# Kätkö: takaseinä ikkunaraolla, sivuseinät ja matala katto.
	_solid(Vector3(4.2, 2.2, 0.3), Vector3(-2.9, 1.1, -3.4), logc)
	_solid(Vector3(4.2, 2.2, 0.3), Vector3(2.9, 1.1, -3.4), logc)
	_solid(Vector3(1.6, 0.9, 0.3), Vector3(0, 0.45, -3.4), logc)
	_solid(Vector3(1.6, 0.5, 0.3), Vector3(0, 1.95, -3.4), logc)
	B.mesh(self, B.boxm(Vector3(9.6, 0.2, 2.4)), Vector3(0, 2.3, -3.0), Color(0.22, 0.16, 0.12), Vector3(-6, 0, 0))
	_bench(Vector3(0, 0, -2.6), 1.8)
	# Niitty ikkunan takana: lampi ja kaukainen karhu.
	B.mesh(self, B.boxm(Vector3(26, 0.02, 10)), Vector3(0, 0.0, -9.5), Color(0.36, 0.44, 0.24))
	B.mesh(self, B.boxm(Vector3(8, 0.03, 3)), Vector3(4, 0.01, -8), Color(0.32, 0.5, 0.6))
	var bear := Node3D.new()
	bear.position = Vector3(-3, 0, -9.0)
	add_child(bear)
	_bear_parts(bear)
	_bears.append(bear)
	for i in 9:
		_pine(Vector3(-12.0 + i * 3.2, 0, -14.0 + (i % 3)), 5.0 + (i % 4) * 0.6)
	# Kyltit (kallistettu kameraa kohti, iso fontti).
	var bg := Color(0.2, 0.14, 0.09)
	var fg := Color(0.98, 0.92, 0.75)
	var edge := Color(0.7, 0.55, 0.35)
	var t1 := B.sign_plate(self, "KARHUKÄTKÖ", bg, fg, 0.34, 72, edge)
	t1.position = Vector3(0, 3.0, -3.1)
	t1.rotation_degrees.x = TILT
	B.sign_pole(self, Vector3(3.6, 0, 4.3), 1.3)
	var info := B.sign_plate(self, "KUHMO\nKarhut kuvattavissa\nhämärässä, sanotaan", bg, fg, 0.34, 62, edge)
	info.position = Vector3(3.6, 1.5, 4.2)
	info.rotation_degrees.x = -35.0
	# Opas (katsoo +Z:aan).
	_guide = Looks.make(self, {"shirt": Color(0.3, 0.38, 0.25), "pants": Color(0.25, 0.22, 0.18),
		"shoes": Color(0.12, 0.1, 0.08), "hair": "Hair_SimpleParted", "hair_color": Color(0.4, 0.3, 0.2), "height": 1.78})
	_guide.position = Vector3(-3.6, 0, -0.2)
	_guide.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_guide.play("Idle", 0.0)
	_bubble = B.bubble(self, BUBBLE_AT, Color.WHITE, 0.9)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.6, 1.0)
	lamp.light_color = Color(1.0, 0.85, 0.65)
	lamp.light_energy = 1.0
	lamp.omni_range = 12.0
	add_child(lamp)
