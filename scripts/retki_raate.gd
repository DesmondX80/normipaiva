extends Node3D
## Raatteen Portti (retket.gd "raate"): Suomussalmen Raatteentie, talvisodan muistopaikka, taskukohtaus kuten retki_pyhakoski.gd.
## Hiljainen kävely: portti, tienvarsi ja muistokivi; vanha vierailija kertoo. Ei minipeliä, ei vitsejä. Tiedot "sanotaan"-muodossa,
## tarkistettava; paikka on tyylitelty ja sävy kunnioittava.
## Paikallinen -Z = tie jatkuu metsään (takana), +Z = parkkipaikka ja kamera. Vierailija katsoo +Z:aan. Ei istuvia hahmoja.

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
	"vierailija": [Vector3(-3.6, 0, 1.0), "[E] Juttele vanhan vierailijan kanssa"],
	"portti": [Vector3(0.0, 0, -0.2), "[E] Raatteen Portti"],
	"kivi": [Vector3(4.0, 0, -1.2), "[E] Muistokivi"],
}
var _enter_frame := -1
var _guest: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
const BUBBLE_AT := Vector3(-5.6, 0.4, 2.4)  # vierailijan vasemmalla lattialla, ei hahmon päällä
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
	_guest.play("Idle_Talking", 0.2)


func _process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble.text != "" and (_bubble_t <= 0.0 or (active and walker.position.distance_to(_guest.position) > BUBBLE_FAR)):
		_bubble.text = ""
		_guest.play("Idle", 0.3)
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
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), Color(0.3, 0.36, 0.24))
	# Raatteentie: sorainen tie kulkee portin läpi metsään (-Z).
	B.mesh(self, B.boxm(Vector3(3.0, 0.006, HALF.y * 2.0)), Vector3(0, 0.002, 0), Color(0.46, 0.42, 0.36))
	# Portti: kaksi harmaata kivipilaria ja niiden päällä palkki.
	_solid(Vector3(0.9, 3.2, 0.9), Vector3(-1.9, 1.6, -1.2), Color(0.5, 0.5, 0.5))
	_solid(Vector3(0.9, 3.2, 0.9), Vector3(1.9, 1.6, -1.2), Color(0.5, 0.5, 0.5))
	B.mesh(self, B.boxm(Vector3(4.9, 0.5, 1.1)), Vector3(0, 3.45, -1.2), Color(0.42, 0.42, 0.43))
	# Muistokivi (oikealla): iso kivi ja soihtu sen vieressä.
	_solid(Vector3(1.4, 1.5, 0.9), Vector3(4.6, 0.75, -1.8), Color(0.55, 0.55, 0.57))
	B.mesh(self, B.boxm(Vector3(0.12, 0.7, 0.12)), Vector3(3.4, 0.35, -1.6), Color(0.25, 0.22, 0.2))
	B.mesh(self, B.boxm(Vector3(0.3, 0.2, 0.3)), Vector3(3.4, 0.8, -1.6), Color(0.9, 0.5, 0.15))
	# Metsä molemmin puolin ja takana.
	for i in 8:
		_pine(Vector3(-13.0 + i * 3.8, 0, -7.0 - (i % 2) * 2.0), 6.0 + (i % 3) * 0.7)
	# Kyltit (kallistettu kameraa kohti, iso fontti).
	var bg := Color(0.16, 0.18, 0.2)
	var fg := Color(0.95, 0.93, 0.85)
	var edge := Color(0.55, 0.55, 0.52)
	var t1 := B.sign_plate(self, "RAATTEEN PORTTI", bg, fg, 0.34, 72, edge)
	t1.position = Vector3(0.0, 2.6, -0.4)
	t1.rotation_degrees.x = TILT
	B.sign_pole(self, Vector3(2.4, 0, 4.0), 1.3)
	var info := B.sign_plate(self, "RAATTEENTIE\nSuomussalmi\ntalvisota, sanotaan", bg, fg, 0.34, 60, edge)
	info.position = Vector3(2.4, 1.5, 3.9)
	info.rotation_degrees.x = -35.0
	var t3 := B.sign_plate(self, "TALVISODAN\nUHREILLE", bg, fg, 0.34, 60, edge)
	t3.position = Vector3(4.6, 2.3, -0.9)
	t3.rotation_degrees.x = TILT
	# Vanha vierailija (katsoo +Z:aan).
	_guest = Looks.make(self, {"shirt": Color(0.3, 0.33, 0.38), "pants": Color(0.22, 0.22, 0.25),
		"shoes": Color(0.12, 0.1, 0.08), "hair": "Hair_SimpleParted", "hair_color": Color(0.75, 0.75, 0.77), "height": 1.72})
	_guest.position = Vector3(-3.6, 0, 0.2)
	_guest.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_guest.play("Idle", 0.0)
	_bubble = B.bubble(self, BUBBLE_AT, Color.WHITE, 0.9)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 4.0, 2.0)
	lamp.light_color = Color(0.95, 0.95, 1.0)
	lamp.light_energy = 0.9
	lamp.omni_range = 12.0
	add_child(lamp)
