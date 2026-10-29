extends Node3D
## Pyhäkoski (retket.gd "pyhakoski"): Oulujoen voimalaitoskylä, taskukohtaus kuten retki_hiidenportti.gd. Kävely player_walker.gd:llä.
## Takana joki ja voimalaitos, edessä kioski, tanssipaikan portaat ja pari rivitaloa. Vahtimestari kertoo voimalaitoksesta, kioski ja portaat
## kertovat omat tarinansa; hiljainen, kunnioittava sävy. Tiedot "sanotaan"-muodossa, tarkistettava; kylä on tyylitelty.
## Paikallinen -Z = joki ja voimalaitos (takana), +Z = kylätie ja kamera. Vahtimestari katsoo +Z:aan. Ei istuvia hahmoja.

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
	"vahtimestari": [Vector3(-3.4, 0, 0.8), "[E] Juttele vahtimestarin kanssa"],
	"kioski": [Vector3(3.2, 0, -0.8), "[E] Kioski: kuuntele kioskin tarina"],
	"portaat": [Vector3(-0.2, 0, 3.2), "[E] Tanssipaikan portaat"],
}
var _enter_frame := -1
var _guard: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
const BUBBLE_AT := Vector3(-5.4, 0.4, 2.2)  # vahtimestarin vasemmalla lattialla, ei hahmon päällä
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
	_guard.play("Idle_Talking", 0.2)


func _process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble.text != "" and (_bubble_t <= 0.0 or (active and walker.position.distance_to(_guard.position) > BUBBLE_FAR)):
		_bubble.text = ""
		_guard.play("Idle", 0.3)
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
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), Color(0.32, 0.38, 0.24))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.006, 2.4)), Vector3(0, 0.002, 3.4), Color(0.42, 0.4, 0.36))  # kylätie
	# Joki (takana) ja voimalaitos: betoninen patorakennus, jonka päällä ikkunarivi.
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.05, 3.0)), Vector3(0, 0.0, -4.6), Color(0.18, 0.32, 0.45))
	_solid(Vector3(7.0, 3.6, 2.6), Vector3(-1.0, 1.8, -5.4), Color(0.62, 0.6, 0.56))
	for i in 5:
		B.mesh(self, B.boxm(Vector3(0.8, 0.9, 0.05)), Vector3(-3.6 + i * 1.4, 2.4, -4.05), Color(0.25, 0.32, 0.4))
	B.mesh(self, B.boxm(Vector3(7.4, 0.3, 3.0)), Vector3(-1.0, 3.75, -5.4), Color(0.4, 0.4, 0.42))
	# Kioski (oikealla): punainen, luukku ja markiisi.
	_solid(Vector3(2.2, 2.2, 1.8), Vector3(4.6, 1.1, -0.2), Color(0.72, 0.25, 0.2))
	B.mesh(self, B.boxm(Vector3(2.6, 0.12, 0.9)), Vector3(4.6, 2.2, 1.0), Color(0.95, 0.9, 0.8))
	B.mesh(self, B.boxm(Vector3(1.2, 0.7, 0.05)), Vector3(4.6, 1.3, 0.72), Color(0.15, 0.12, 0.1))
	# Tanssipaikan portaat (keskellä): kolme porrasta ja lava-ovi.
	for i in 3:
		B.mesh(self, B.boxm(Vector3(2.4, 0.16, 0.5)), Vector3(0, 0.08 + i * 0.16, 2.4 - i * 0.5), Color(0.5, 0.36, 0.22))
	# Rivitalot taustalle vasemmalle ja männiköt.
	_solid(Vector3(4.0, 2.4, 1.8), Vector3(-5.2, 1.2, -1.8), Color(0.78, 0.7, 0.45))
	_solid(Vector3(0.9, 2.5, 1.9), Vector3(-7.4, 1.25, -1.8), Color(0.55, 0.3, 0.22))
	for i in 7:
		_pine(Vector3(-12.0 + i * 4.0, 0, -9.0 + (i % 2) * 2.0), 6.0 + (i % 3) * 0.7)
	# Kyltit (kallistettu kameraa kohti, iso fontti).
	var bg := Color(0.2, 0.14, 0.09)
	var fg := Color(0.98, 0.92, 0.75)
	var edge := Color(0.7, 0.55, 0.35)
	var t1 := B.sign_plate(self, "PYHÄKOSKI", bg, fg, 0.34, 72, edge)
	# Pääkyltti kylätien etureunalla kahdella tolpalla (tulopaikan edessä, pelikameralle), ei voimalaitoksen takana.
	t1.position = Vector3(3.0, 1.9, 5.0)
	t1.rotation_degrees.x = -35.0
	for px in [-1.2, 1.2]:
		_solid(Vector3(0.12, 1.9, 0.12), Vector3(3.0 + px, 0.95, 5.0), Color(0.3, 0.2, 0.12))
	var t2 := B.sign_plate(self, "KIOSKI", Color(0.95, 0.9, 0.8), Color(0.55, 0.15, 0.12), 0.34, 64, Color(0.72, 0.25, 0.2))
	t2.position = Vector3(4.6, 2.7, 1.3)
	t2.rotation_degrees.x = TILT
	B.sign_pole(self, Vector3(-2.6, 0, 4.3), 1.3)
	var info := B.sign_plate(self, "OULUJOKI\nVoimalaitoskylä\nrakennettu 1950-luvulla, sanotaan", bg, fg, 0.34, 60, edge)
	info.position = Vector3(-2.6, 1.5, 4.2)
	info.rotation_degrees.x = -35.0
	# Vahtimestari (katsoo +Z:aan).
	_guard = Looks.make(self, {"shirt": Color(0.3, 0.4, 0.5), "pants": Color(0.2, 0.22, 0.28),
		"shoes": Color(0.12, 0.1, 0.08), "hair": "Hair_SimpleParted", "hair_color": Color(0.6, 0.6, 0.62), "height": 1.76})
	_guard.position = Vector3(-3.4, 0, -0.2)
	_guard.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_guard.play("Idle", 0.0)
	_bubble = B.bubble(self, BUBBLE_AT, Color.WHITE, 0.9)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 4.0, 1.0)
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.light_energy = 1.0
	lamp.omni_range = 12.0
	add_child(lamp)
