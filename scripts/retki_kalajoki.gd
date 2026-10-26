extends Node3D
## Kalajoki (retket.gd "kalajoki"): Hiekkasärkät, taskukohtaus kuten retki_kajaani.gd. Kävely player_walker.gd:llä.
## Takana meri, keskellä rantajalkapallokenttä (E: peli, rantapallo_game.gd), vasemmalla Hiekkasärkät-kyltti, oikealla turnauksen järjestäjä.
## Juhannuksena (set_juhannus) kentän ympärille nousevat koivut ja lippusiima. Tiedot "sanotaan"-muodossa, tarkistettava.
## Paikallinen -Z = meri (takana), +Z = polku ja kamera. Järjestäjä katsoo +Z:aan. Ei istuvia hahmoja.

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
	"kentta": [Vector3(0.0, 0, -0.6), "[E] Rantajalkapallokenttä: pelaa"],
	"kyltti": [Vector3(-4.6, 0, 1.4), "[E] Hiekkasärkät-kyltti"],
	"jarjestaja": [Vector3(4.2, 0, 0.8), "[E] Turnauksen järjestäjä"],
}
var _enter_frame := -1
var _organizer: Node3D
var _koivut: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
const BUBBLE_AT := Vector3(6.0, 0.4, 2.2)  # järjestäjän oikealla lattialla, ei hahmon päällä
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
	_organizer.play("Idle_Talking", 0.2)


## Juhannuskoristeet (koivut ja siimalippu) päälle tai pois.
func set_juhannus(on: bool) -> void:
	_koivut.visible = on


func _process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble.text != "" and (_bubble_t <= 0.0 or (active and walker.position.distance_to(_organizer.position) > BUBBLE_FAR)):
		_bubble.text = ""
		_organizer.play("Idle", 0.3)
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

func _dune(pos: Vector3, r: float, h: float) -> void:
	var mi := B.mesh(self, B.sphere(1.0, 12), pos + Vector3(0, -0.1, 0), Color(0.74, 0.63, 0.42))
	mi.scale = Vector3(r, h, r * 0.7)


func _pine(pos: Vector3, h: float) -> void:
	B.mesh(self, B.cyl(0.14, 0.2, h * 0.4, 8), pos + Vector3(0, h * 0.2, 0), Color(0.3, 0.2, 0.12))
	for k in 3:
		B.mesh(self, B.cyl(0.02, 1.0 - k * 0.25, h * 0.4, 8), pos + Vector3(0, h * (0.5 + k * 0.2), 0), Color(0.1, 0.27 + k * 0.03, 0.15))


func _goal(x: float) -> void:
	var white := Color(0.95, 0.95, 0.92)
	for dz in [-1.0, 1.0]:
		B.mesh(self, B.cyl(0.05, 0.05, 1.1, 8), Vector3(x, 0.55, -0.6 + dz), white)
	B.mesh(self, B.boxm(Vector3(0.1, 0.08, 2.1)), Vector3(x, 1.1, -0.6), white)
	B.mesh(self, B.boxm(Vector3(0.02, 1.0, 2.0)), Vector3(x + signf(x) * 0.5, 0.55, -0.6), Color(0.9, 0.9, 0.9, 1.0))  # verkon selkä


func _build() -> void:
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.7, 0.6, 0.4))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), Color(0.78, 0.66, 0.42))
	# Meri takana ja vaahtoreuna.
	B.mesh(self, B.boxm(Vector3(60, 0.06, 7.0)), Vector3(0, 0.0, -10.0), Color(0.2, 0.42, 0.6))
	B.mesh(self, B.boxm(Vector3(60, 0.03, 0.25)), Vector3(0, 0.05, -6.6), Color(0.92, 0.96, 0.96))
	for i in 5:
		_dune(Vector3(-12.0 + i * 6.0, 0, -5.6 - (i % 2) * 0.4), 3.2 + (i % 3) * 0.6, 0.35 + (i % 2) * 0.15)
	# Kenttä: hiekan päälle viivat ja kaksi maalia.
	var line := Color(0.97, 0.95, 0.88)
	B.mesh(self, B.boxm(Vector3(7.6, 0.01, 0.07)), Vector3(0, 0.008, -2.0), line)
	B.mesh(self, B.boxm(Vector3(7.6, 0.01, 0.07)), Vector3(0, 0.008, 0.8), line)
	for sx in [-3.8, 3.8]:
		B.mesh(self, B.boxm(Vector3(0.07, 0.01, 2.8)), Vector3(sx, 0.008, -0.6), line)
	B.mesh(self, B.boxm(Vector3(0.07, 0.01, 2.8)), Vector3(0, 0.008, -0.6), line)
	_goal(-3.8)
	_goal(3.8)
	B.mesh(self, B.sphere(0.16, 12), Vector3(0, 0.17, -0.6), Color(0.97, 0.97, 0.95))
	# Kyltit (kallistettu kameraa kohti, iso fontti).
	var bg := Color(0.1, 0.3, 0.45)
	var fg := Color(0.99, 0.95, 0.8)
	var edge := Color(0.9, 0.75, 0.35)
	var t1 := B.sign_plate(self, "HIEKKASÄRKÄT", bg, fg, 0.34, 72, edge)
	B.sign_pole(self, Vector3(-4.6, 0, 0.9), 1.4)
	t1.position = Vector3(-4.6, 1.7, 1.0)
	t1.rotation_degrees.x = TILT
	var t2 := B.sign_plate(self, "RANTAJALKAPALLO\nJUHANNUSTURNAUS", Color(0.95, 0.9, 0.8), Color(0.12, 0.3, 0.45), 0.34, 60, Color(0.9, 0.75, 0.35))
	B.sign_pole(self, Vector3(0.0, 0, -3.4), 1.5)
	t2.position = Vector3(0.0, 1.7, -3.3)
	t2.rotation_degrees.x = -30.0
	# Juhannuskoristeet: koivut kentän kulmissa ja siimalippu maalien välillä.
	_koivut = Node3D.new()
	_koivut.visible = false
	add_child(_koivut)
	for sx in [-4.4, 4.4]:
		for sz in [-1.9, 0.7]:
			B.mesh(_koivut, B.cyl(0.05, 0.07, 2.0, 8), Vector3(sx, 1.0, sz), Color(0.92, 0.92, 0.88))
			var crown := B.mesh(_koivut, B.sphere(0.6, 10), Vector3(sx, 2.2, sz), Color(0.35, 0.6, 0.25))
			crown.scale = Vector3(1.0, 1.3, 1.0)
	for i in 9:
		B.mesh(_koivut, B.boxm(Vector3(0.22, 0.28, 0.02)), Vector3(-3.6 + i * 0.9, 1.95 - 0.06 * absf(i - 4), 0.7), [Color(0.2, 0.4, 0.8), Color(0.95, 0.95, 0.9)][i % 2])
	B.mesh(_koivut, B.boxm(Vector3(8.8, 0.02, 0.02)), Vector3(0, 2.1, 0.7), Color(0.4, 0.3, 0.2))
	# Järjestäjä (katsoo +Z:aan) ja kioskin sateenvarjo.
	_organizer = Looks.make(self, {"shirt": Color(0.2, 0.5, 0.75), "pants": Color(0.9, 0.85, 0.7),
		"shoes": Color(0.8, 0.7, 0.5), "hair": "Hair_SimpleParted", "hair_color": Color(0.8, 0.65, 0.3), "height": 1.74})
	_organizer.position = Vector3(4.6, 0, 0.4)
	_organizer.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_organizer.play("Idle", 0.0)
	B.mesh(self, B.cyl(0.03, 0.03, 2.1, 8), Vector3(5.8, 1.05, -0.4), Color(0.4, 0.3, 0.2))
	B.mesh(self, B.cyl(0.05, 1.3, 0.4, 12), Vector3(5.8, 2.2, -0.4), Color(0.9, 0.3, 0.25))
	_bubble = B.bubble(self, BUBBLE_AT, Color.WHITE, 0.9)
	for i in 7:
		_pine(Vector3(-12.0 + i * 4.0, 0, -11.0 + (i % 2) * 1.5), 6.0 + (i % 3) * 0.7)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 4.0, 1.0)
	lamp.light_color = Color(1.0, 0.97, 0.88)
	lamp.light_energy = 0.8
	lamp.omni_range = 12.0
	add_child(lamp)
