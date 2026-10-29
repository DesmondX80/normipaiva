extends Node3D
## Kajaani (retket.gd "kajaani"): Kajaanin linnan rauniot Kajaaninjoen saarella, taskukohtaus kuten retki_pyhakoski.gd. Kävely player_walker.gd:llä.
## Takana joki ja rauniomuuri, vasemmalla tervavene laiturissa (E: vene lipuu joella, tervamies kertoo), oikealla Messeniuksen muistotaulu.
## Tiedot "sanotaan"-muodossa, tarkistettava; rauniot on tyylitelty. Paikallinen -Z = joki ja rauniot (takana), +Z = polku ja kamera.
## Tervamies katsoo +Z:aan. Ei istuvia hahmoja.

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
	"rauniot": [Vector3(0.6, 0, -0.4), "[E] Linnan rauniot"],
	"tervavene": [Vector3(-4.2, 0, 0.6), "[E] Tervavene: katso, kun vene lähtee"],
	"messenius": [Vector3(4.2, 0, 1.4), "[E] Messeniuksen muistotaulu"],
}
var _enter_frame := -1
var _boatman: Node3D
var _boat: Node3D
var _boat_t := -1.0
var _bubble: Label3D
var _bubble_t := 0.0
const BOAT_X0 := -5.6
const BOAT_X1 := 5.2
const BOAT_Z := -3.7
const BUBBLE_AT := Vector3(-6.4, 0.4, 2.6)  # tervamiehen vasemmalla lattialla, ei hahmon päällä
const BUBBLE_FAR := 4.5


func _ready() -> void:
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF.x + 0.6, -HALF.y + 3.4, HALF.x * 2.0 - 1.2, HALF.y * 2.0 - 3.8)]
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


func say(text: String, t := 4.5) -> void:
	_bubble.text = text
	_bubble_t = t
	_boatman.play("Idle_Talking", 0.2)


## Tervavene lipuu laiturista joen poikki (kohtaus); kutsutaan main.gd:stä tervavene-valinnan jälkeen.
func launch_boat() -> void:
	_boat_t = 0.0


func _process(delta: float) -> void:
	if _boat_t >= 0.0:
		_boat_t += delta
		var k := clampf(_boat_t / 6.0, 0.0, 1.0)
		_boat.position.x = lerpf(BOAT_X0, BOAT_X1, k)
		_boat.position.y = sin(_boat_t * 2.2) * 0.03
		_boat.rotation_degrees.z = sin(_boat_t * 1.7) * 2.0
		if k >= 1.0:  # perillä: takaisin laituriin
			_boat_t = -1.0
			_boat.position = Vector3(BOAT_X0, 0, BOAT_Z)
			_boat.rotation_degrees.z = 0.0
	_bubble_t -= delta
	if _bubble.text != "" and (_bubble_t <= 0.0 or (active and walker.position.distance_to(_boatman.position) > BUBBLE_FAR)):
		_bubble.text = ""
		_boatman.play("Idle", 0.3)
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


func _build() -> void:
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.15, 0.2, 0.12))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), Color(0.34, 0.4, 0.26))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.006, 2.2)), Vector3(0, 0.002, 3.4), Color(0.45, 0.42, 0.36))  # polku
	# Joki edessä rauniomuuria: vesi ja kaksi koskivaahtoa.
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.05, 3.0)), Vector3(0, 0.0, -3.7), Color(0.2, 0.34, 0.46))
	for i in 4:
		B.mesh(self, B.boxm(Vector3(1.4, 0.03, 0.12)), Vector3(-5.0 + i * 3.4, 0.04, -3.0 - (i % 2) * 1.2), Color(0.85, 0.9, 0.92))
	# Rauniot: särkynyt harmaakivimuuri ja kulmatorni (eri korkuisia lohkoja).
	var stone := Color(0.52, 0.5, 0.46)
	var stone2 := Color(0.44, 0.43, 0.4)
	for i in 6:
		var h := 1.4 + (i * 7 % 5) * 0.35
		_solid(Vector3(1.6, h, 1.1), Vector3(-4.6 + i * 1.7, h * 0.5, -5.8), stone if i % 2 == 0 else stone2)
	_solid(Vector3(2.4, 3.2, 2.4), Vector3(4.6, 1.6, -5.4), stone)
	B.mesh(self, B.boxm(Vector3(1.4, 0.8, 1.4)), Vector3(4.2, 3.6, -5.4), stone2)  # sortunut ylälohko
	for i in 3:
		B.mesh(self, B.boxm(Vector3(0.7, 0.35, 0.5)), Vector3(-1.0 + i * 1.1, 0.18, -4.7), stone2)  # romahtaneita lohkareita
	# Tervavene laiturissa: veneen runko, tervatynnyrit ja laituri.
	B.mesh(self, B.boxm(Vector3(2.4, 0.12, 1.0)), Vector3(-5.4, 0.1, -2.3), Color(0.45, 0.32, 0.2))
	_boat = Node3D.new()
	_boat.position = Vector3(BOAT_X0, 0, BOAT_Z)
	add_child(_boat)
	B.mesh(_boat, B.boxm(Vector3(2.6, 0.3, 0.9)), Vector3(0, 0.18, 0), Color(0.3, 0.2, 0.12))
	B.mesh(_boat, B.boxm(Vector3(0.5, 0.3, 0.7)), Vector3(1.5, 0.3, 0), Color(0.3, 0.2, 0.12))  # keula
	B.mesh(_boat, B.boxm(Vector3(0.5, 0.3, 0.7)), Vector3(-1.5, 0.3, 0), Color(0.3, 0.2, 0.12))  # perä
	for i in 3:
		B.mesh(_boat, B.cyl(0.26, 0.26, 0.5, 10), Vector3(-0.6 + i * 0.6, 0.55, 0), Color(0.12, 0.09, 0.07))  # tervatynnyrit
		B.mesh(_boat, B.cyl(0.27, 0.27, 0.05, 10), Vector3(-0.6 + i * 0.6, 0.8, 0), Color(0.5, 0.4, 0.3))
	# Kyltit (kallistettu kameraa kohti, iso fontti).
	var bg := Color(0.2, 0.14, 0.09)
	var fg := Color(0.98, 0.92, 0.75)
	var edge := Color(0.7, 0.55, 0.35)
	var t1 := B.sign_plate(self, "KAJAANIN LINNA", bg, fg, 0.34, 72, edge)
	B.sign_pole(self, Vector3(0.6, 0, -1.9), 1.4)
	t1.position = Vector3(0.6, 1.7, -1.8)
	t1.rotation_degrees.x = TILT
	var t2 := B.sign_plate(self, "TERVAVENE", Color(0.95, 0.9, 0.8), Color(0.3, 0.2, 0.12), 0.34, 64, Color(0.45, 0.32, 0.2))
	t2.position = Vector3(-4.0, 1.7, 1.9)
	t2.rotation_degrees.x = TILT
	B.sign_pole(self, Vector3(4.6, 0, 2.6), 1.3)
	var info := B.sign_plate(self, "MESSENIUS\nvankina linnassa 1616-1636\nsanotaan, tarkistettava", bg, fg, 0.34, 60, edge)
	info.position = Vector3(4.6, 1.5, 2.5)
	info.rotation_degrees.x = -35.0
	# Tervamies (katsoo +Z:aan).
	_boatman = Looks.make(self, {"shirt": Color(0.45, 0.3, 0.2), "pants": Color(0.2, 0.2, 0.24),
		"shoes": Color(0.12, 0.1, 0.08), "hair": "Hair_SimpleParted", "hair_color": Color(0.35, 0.28, 0.2), "height": 1.78})
	_boatman.position = Vector3(-4.2, 0, -0.4)
	_boatman.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_boatman.play("Idle", 0.0)
	_bubble = B.bubble(self, BUBBLE_AT, Color.WHITE, 0.9)
	for i in 7:
		_pine(Vector3(-12.0 + i * 4.0, 0, -9.0 + (i % 2) * 2.0), 6.0 + (i % 3) * 0.7)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 4.0, 1.0)
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.light_energy = 1.0
	lamp.omni_range = 12.0
	add_child(lamp)
