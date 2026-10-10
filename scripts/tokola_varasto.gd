extends Node3D
## Tokolan vanha varasto sisältä (#120): pölyinen lautalattia, hyllyt täynnä kauppiaan aikaisia laatikoita,
## ruosteiset rautalankakelat, pahvilaatikko (sähköpyörän ohjain ja kaasukahva) ja hyllyllä kauppiaan tilikirja.
## Yksi lattialankku narisee eri tavalla (peltirasia lankun alla). Valo tulee raoista ja taskulampusta.
## Toiminnot acted-signaalilla (main.gd _on_varasto_acted). Paikallinen +Z = ovi (kamera), -Z = takaseinä.

const B := preload("res://scripts/build.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(4.0, 3.2)
const WALL_H := 3.0
const BOARD := Color(0.42, 0.33, 0.24)
const DUST := Color(0.55, 0.5, 0.42)

var spot := ""
var spots := {
	"ovi": [Vector3(0.0, 0, 2.7), "[E] Ulos"],
	"laatikko": [Vector3(-2.8, 0, -2.0), "[E] Pölyinen pahvilaatikko hyllyn perällä"],
	"kelat": [Vector3(2.9, 0, -1.6), "[E] Ruosteiset rautalankakelat"],
	"hylly": [Vector3(0.6, 0, -2.3), "[E] Kauppiaan hylly: vanhoja kirjoja ja kuitteja"],
	"lankku": [Vector3(-0.9, 0, 0.4), ""],  # vihje main.gd:stä (tilikirjan piirros)
}

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var hints := {}  # main.gd: spot -> vihje (tyhjä = ei toimintoa), ohittaa spots-vihjeen
var _enter_frame := -1
var _box: Node3D
var _coils: Node3D
var _book: Node3D
var _plank: MeshInstance3D


func _ready() -> void:
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0] + Vector3(0, 0, -0.8)
	walker.bounds = [Rect2(-HALF, HALF * 2.0)]
	add_child(walker)


func enter() -> void:
	active = true
	busy = false
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(0, 0, -0.8)
	walker.rotation.y = B.yaw_to(Vector3(0, 0, -1))
	walker.activate()


func leave() -> void:
	active = false
	walker.controls_enabled = false


func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


## Löydöt pois näkyvistä (main.gd tilan mukaan).
func set_taken(box: bool, coils: bool, book: bool, plank_open: bool) -> void:
	_box.visible = not box
	_coils.visible = not coils
	_book.visible = not book
	_plank.rotation_degrees.z = 25.0 if plank_open else 0.0
	_plank.position.y = 0.12 if plank_open else 0.02


func _process(_delta: float) -> void:
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	var p := walker.position
	var best := ""
	var bd := 1.3
	for id in spots:
		var d := Vector2(p.x - spots[id][0].x, p.z - spots[id][0].z).length()
		if d < bd and hints.get(id, spots[id][1]) != "":
			bd = d
			best = id
	spot = best
	hint = "" if best == "" else hints.get(best, spots[best][1])
	if best == "" or not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	if best == "ovi":
		exited.emit()
	else:
		acted.emit(best)


func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := B.mesh(self, B.boxm(size), pos, col)
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	add_child(body)
	return mi


func _build() -> void:
	B.mesh(self, B.boxm(Vector3(60, 0.2, 60)), Vector3(0, -0.2, 0), Color(0.04, 0.04, 0.05))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), DUST)
	for i in int(HALF.x * 2.0 / 0.4):
		B.mesh(self, B.boxm(Vector3(0.02, 0.01, HALF.y * 2.0)), Vector3(-HALF.x + i * 0.4, 0.005, 0), DUST.darkened(0.3))
	# Nariseva lankku hieman eri sävyinen.
	_plank = B.mesh(self, B.boxm(Vector3(0.38, 0.04, 1.2)), Vector3(-0.9, 0.02, 0.4), DUST.lightened(0.08))
	for w in [[Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, -HALF.y)], [Vector2(-HALF.x, -HALF.y), Vector2(-HALF.x, HALF.y)],
			[Vector2(HALF.x, -HALF.y), Vector2(HALF.x, HALF.y)]]:
		var c: Vector2 = (w[0] + w[1]) / 2.0
		var size := Vector3(maxf(absf(w[1].x - w[0].x), 0.2), WALL_H, maxf(absf(w[1].y - w[0].y), 0.2))
		_solid(size, Vector3(c.x, WALL_H / 2.0, c.y), BOARD)
	_solid(Vector3(HALF.x * 2.0 - 2.0, 0.6, 0.2), Vector3(-HALF.x / 2.0 - 0.5, 0.3, HALF.y), BOARD)
	_solid(Vector3(HALF.x - 1.0, 0.6, 0.2), Vector3(HALF.x / 2.0 + 0.5, 0.3, HALF.y), BOARD)
	# Valo raoista ja kattolamppu (vanha hehkulamppu).
	for i in 5:
		var gap := B.mesh(self, B.boxm(Vector3(0.03, WALL_H - 0.4, 0.04)), Vector3(-HALF.x + 0.8 + i * 1.6, WALL_H / 2.0, -HALF.y + 0.11), Color(1.0, 0.95, 0.7))
		gap.material_override = B.unshaded(Color(1.0, 0.92, 0.65))
	var light := OmniLight3D.new()
	light.position = Vector3(0, WALL_H - 0.4, 0)
	light.omni_range = 7.0
	light.light_energy = 0.5
	light.light_color = Color(1.0, 0.85, 0.6)
	add_child(light)
	# Hyllyt takaseinällä: vanhoja laatikoita, purkkeja ja säkkejä.
	_solid(Vector3(HALF.x * 2.0 - 0.6, 2.2, 0.5), Vector3(0, 1.1, -HALF.y + 0.3), BOARD.darkened(0.2))
	for i in 12:
		var x := -HALF.x + 0.7 + (i % 6) * 1.2
		var y := 0.6 + (i / 6) * 0.9
		B.mesh(self, B.boxm(Vector3(0.6, 0.4, 0.35)), Vector3(x, y, -HALF.y + 0.45), [Color(0.6, 0.5, 0.35), Color(0.5, 0.42, 0.3), Color(0.35, 0.3, 0.25)][i % 3])
	var sign := B.label(self, "TOKOLAN KAUPPA", Vector3(0, 2.6, -HALF.y + 0.12), 40, Color(0.75, 0.68, 0.5))
	sign.modulate = Color(1, 1, 1, 0.6)
	# Pahvilaatikko (ohjain ja kaasukahva), rautalankakelat ja tilikirja.
	_box = Node3D.new()
	_box.position = spots.laatikko[0] + Vector3(-0.3, 0, -0.5)
	add_child(_box)
	B.mesh(_box, B.boxm(Vector3(0.55, 0.4, 0.45)), Vector3(0, 0.2, 0), Color(0.7, 0.55, 0.35))
	B.mesh(_box, B.boxm(Vector3(0.12, 0.08, 0.2)), Vector3(0.05, 0.44, 0), Color(0.12, 0.12, 0.13))
	_coils = Node3D.new()
	_coils.position = spots.kelat[0] + Vector3(0.5, 0, -0.3)
	add_child(_coils)
	for k in 3:
		B.mesh(_coils, B.cyl(0.25, 0.25, 0.12, 14), Vector3(0, 0.06 + k * 0.13, 0), Color(0.45, 0.32, 0.22))
	_book = Node3D.new()
	_book.position = Vector3(0.6, 1.52, -HALF.y + 0.5)
	add_child(_book)
	B.mesh(_book, B.boxm(Vector3(0.32, 0.06, 0.24)), Vector3.ZERO, Color(0.35, 0.12, 0.1))
	B.mesh(_book, B.boxm(Vector3(0.3, 0.05, 0.22)), Vector3(0.01, 0.0, 0.0), Color(0.9, 0.85, 0.7))
	# Vanha tiski ja vaaka oven vieressä.
	_solid(Vector3(1.6, 0.9, 0.5), Vector3(2.4, 0.45, 1.6), BOARD.lightened(0.1))
	B.mesh(self, B.cyl(0.18, 0.2, 0.25, 12), Vector3(2.3, 1.05, 1.6), Color(0.6, 0.55, 0.45))
