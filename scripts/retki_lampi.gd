extends Node3D
## Teeriniemen leirintäalue ja istutettu kalalampi (retket.gd "lampi"): taskukohtaus kuten raahe_interior.gd.
## Tiskiltä ostetaan kalalupa (main.gd), lammella onkiminen (shore_fish_game.gd, tila `stocked`). Kävely player_walker.gd:llä.
## Paikallinen -Z = tiski ja mökki (takaseinä), +Z = parkkipaikka ja tie (kamera), lampi oikealla (+X).
## Kalastajan paikka on lammen eteläpenkka (fish_spot), vedelle päin -Z.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")
const Vehicles := preload("res://scripts/vehicles.gd")

const HALF := Vector2(15.0, 10.0)
const POND := Rect2(0.0, -8.0, 14.0, 10.0)  # lampi (paikallinen xz): x 0..14, z -8..2
const WATER_Y := -0.1  # veden pinta (penkat y = 0)

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var spot := ""
var spots := {
	"ovi": [Vector3(-12.0, 0, 6.4), "[E] Taksille: takaisin Saloisiin"],
	"tiski": [Vector3(-7.0, 0, -3.4), "[E] Leirintäalueen tiski: kalalupa"],
	"lampi": [Vector3(5.5, 0, 2.6), "[E] Onkimaan kalalammelle"],
}
var _enter_frame := -1
var _clerk: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _fish: Array = []  # [Node3D, kulma, säde, nopeus, keskipiste]
var _t := 0.0


func _ready() -> void:
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	# Lampi on aukko lattiassa: länsipuoli ja eteläpenkka (rectit limittyvät, ettei väliin jää juuttumiskohtaa).
	walker.bounds = [Rect2(-HALF.x, -HALF.y, HALF.x + POND.position.x + 0.3, HALF.y * 2.0),
		Rect2(-1.0, POND.end.y + 0.3, HALF.x + 1.0, HALF.y - POND.end.y - 0.3)]
	add_child(walker)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(1.6, 0, -1.0)
	walker.rotation.y = B.yaw_to(Vector3(1, 0, -1))
	walker.visible = true
	walker.activate()
	say("Tervetuloa Teeriniemeen! Kalaonkeen tarvii luvan, tiskille vaan.")


func leave() -> void:
	active = false
	walker.controls_enabled = false


func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


func say(text: String, t := 3.6) -> void:
	_bubble.text = text
	_bubble_t = t
	_clerk.play("Idle_Talking", 0.2)


## Kalastajan paikka maailmankoordinaateissa (lammen eteläpenkka) ja suunta vedelle.
func fish_spot() -> Vector3:
	return to_global(Vector3(5.5, 0, 2.4))


func fish_dir() -> Vector3:
	return Vector3(0, 0, -1)


func water_y() -> float:
	return global_position.y + WATER_Y


## Onko maailmankoordinaattipiste lammen vettä (pieni reunavara rantaruovikolle).
func is_water(p: Vector3) -> bool:
	var q := to_local(p)
	return POND.grow(-0.3).has_point(Vector2(q.x, q.z))


func _process(delta: float) -> void:
	_t += delta
	_bubble_t -= delta
	if _bubble.text != "" and _bubble_t <= 0.0:
		_bubble.text = ""
		_clerk.play("Idle", 0.3)
	for f in _fish:
		f[1] += delta * f[3]
		var c: Vector3 = f[4]
		var a: float = f[1]
		f[0].position = c + Vector3(cos(a), 0, sin(a)) * f[2]
		f[0].rotation.y = -a  # kulkee ympyrää vastapäivään: pää menosuuntaan
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	var p := walker.position
	var best := ""
	var bd := 1.6
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


func _on_test_exit() -> void:
	exited.emit()


# --- Rakennus -------------------------------------------------------------------------------

func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := B.mesh(self, B.boxm(size), pos, col)
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	add_child(body)
	return mi


func _spruce(at: Vector3, s := 1.0) -> void:
	B.mesh(self, B.cyl(0.12 * s, 0.17 * s, 1.2 * s), at + Vector3(0, 0.6 * s, 0), Color(0.32, 0.2, 0.12))
	for i in 3:
		var r := (1.25 - i * 0.3) * s
		B.mesh(self, B.cyl(0.0, r, 1.5 * s, 8), at + Vector3(0, (1.6 + i * 0.85) * s, 0), Color(0.1, 0.3 + i * 0.04, 0.16))


func _build() -> void:
	var grass := Color(0.35, 0.55, 0.25)
	var sand := Color(0.78, 0.68, 0.45)
	var wood := Color(0.55, 0.36, 0.2)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.2, 0.4, 0.18))
	# Penkat lammen ympärillä (lampi jää aukoksi), ruohoa ja hiekkapolku tiskiltä lammelle.
	var gy := -0.05
	B.mesh(self, B.boxm(Vector3(HALF.x, 0.1, HALF.y * 2.0)), Vector3(-HALF.x / 2.0, gy, 0), grass)  # x -15..0
	B.mesh(self, B.boxm(Vector3(1.0, 0.1, HALF.y * 2.0)), Vector3(14.5, gy, 0), grass)
	B.mesh(self, B.boxm(Vector3(POND.size.x, 0.1, HALF.y + POND.position.y)), Vector3(7.0, gy, (-HALF.y + POND.position.y) / 2.0), grass)
	B.mesh(self, B.boxm(Vector3(POND.size.x, 0.1, HALF.y - POND.end.y)), Vector3(7.0, gy, (HALF.y + POND.end.y) / 2.0), grass)
	B.mesh(self, B.boxm(Vector3(9.0, 0.02, 1.4)), Vector3(-3.5, 0.005, -2.8), sand)
	B.mesh(self, B.boxm(Vector3(1.4, 0.02, 7.0)), Vector3(-7.0, 0.005, 0.5), sand)
	B.mesh(self, B.boxm(Vector3(1.4, 0.02, 3.0)), Vector3(5.5, 0.005, 3.8), sand)
	# Lampi: tumma pohja ja vesi, vaalea reunus, ruovikko ja lummeita.
	B.mesh(self, B.boxm(Vector3(POND.size.x, 0.6, POND.size.y)), Vector3(POND.get_center().x, -0.6, POND.get_center().y), Color(0.12, 0.2, 0.18))
	var water := B.mesh(self, B.boxm(Vector3(POND.size.x, 0.02, POND.size.y)), Vector3(POND.get_center().x, WATER_Y, POND.get_center().y), Color(0.2, 0.45, 0.55))
	water.material_override.roughness = 0.15
	water.material_override.metallic = 0.3
	# Ruovikko lammen länsi- ja pohjoisreunalla sekä eteläreunan päissä (kalastuspaikka jää auki).
	var reeds: Array[Vector2] = []
	for i in 10:
		reeds.append(Vector2(POND.position.x + 0.35, POND.position.y + 0.5 + i * 0.9))
	for i in 14:
		reeds.append(Vector2(POND.position.x + 0.8 + i * 0.95, POND.position.y + 0.35))
	for i in 3:
		reeds.append(Vector2(POND.position.x + 0.8 + i * 0.9, POND.end.y - 0.35))
		reeds.append(Vector2(POND.end.x - 0.8 - i * 0.9, POND.end.y - 0.35))
	for r in reeds:
		for j in 3:
			B.mesh(self, B.cyl(0.012, 0.02, 1.1 + j * 0.15, 4), Vector3(r.x + j * 0.08, 0.5, r.y + j * 0.05), Color(0.45, 0.5, 0.2), Vector3(j * 3.0 - 3.0, 0, j * 4.0 - 4.0))
	for p in [Vector3(9.5, 0, -5.5), Vector3(11.5, 0, -2.0), Vector3(3.5, 0, -6.2), Vector3(12.8, 0, -6.4)]:
		B.mesh(self, B.cyl(0.35, 0.35, 0.012, 14), Vector3(p.x, WATER_Y + 0.016, p.z), Color(0.22, 0.5, 0.25))
		B.mesh(self, B.sphere(0.07, 6), Vector3(p.x + 0.1, WATER_Y + 0.03, p.z), Color(0.98, 0.95, 0.9))
	# Istutetut kalat: vaaleanpunertava kirjolohi ja ruskea taimen kiertävät lammessa (varjot veden alla).
	for i in 7:
		var f := Node3D.new()
		add_child(f)
		var rainbow := i % 3 != 0
		var col := Color(0.5, 0.42, 0.42) if rainbow else Color(0.32, 0.25, 0.15)
		var body := B.mesh(f, B.sphere(0.5, 8), Vector3.ZERO, col)
		body.scale = Vector3(0.18, 0.08, 0.5 if rainbow else 0.62)
		B.mesh(f, B.boxm(Vector3(0.14, 0.01, 0.12)), Vector3(0, 0, -0.3), col.darkened(0.15))
		f.position.y = WATER_Y - 0.12
		var cen := Vector3(POND.get_center().x + sin(i * 2.1) * 2.5, WATER_Y - 0.12, POND.get_center().y + cos(i * 1.7) * 1.6)
		_fish.append([f, i * 0.9, 1.0 + (i % 3) * 0.55, 0.45 + (i % 4) * 0.12, cen])
	# Konttori: tukkimökki, katto, ikkuna, tiski ja kyltti.
	var log_c := Color(0.5, 0.31, 0.16)
	_solid(Vector3(7.0, 2.7, 3.2), Vector3(-7.0, 1.35, -7.6), log_c)
	for k in 9:
		B.mesh(self, B.cyl(0.14, 0.14, 7.0, 8), Vector3(-7.0, 0.15 + k * 0.3, -5.95), log_c.darkened(0.08 * (k % 2)), Vector3(0, 0, 90))
	B.mesh(self, B.boxm(Vector3(7.8, 0.2, 4.2)), Vector3(-7.0, 2.8, -7.4), Color(0.25, 0.18, 0.14))
	B.mesh(self, B.boxm(Vector3(2.8, 1.0, 0.06)), Vector3(-7.0, 1.4, -5.8), Color(0.65, 0.82, 0.9))  # luukku
	B.mesh(self, B.boxm(Vector3(3.0, 0.08, 0.12)), Vector3(-7.0, 0.88, -5.78), Color(0.9, 0.88, 0.8))
	_solid(Vector3(3.4, 1.0, 0.7), Vector3(-7.0, 0.5, -5.2), wood)
	B.mesh(self, B.boxm(Vector3(3.5, 0.06, 0.8)), Vector3(-7.0, 1.03, -5.2), Color(0.7, 0.5, 0.3))
	B.mesh(self, B.boxm(Vector3(0.3, 0.02, 0.4)), Vector3(-6.0, 1.07, -5.2), Color(0.95, 0.95, 0.9))  # kuittilappu
	var plate := B.sign_plate(self, "TEERINIEMEN LEIRINTÄALUE\nKALALUPA 8 €", Color(0.1, 0.3, 0.2), Color(1, 0.95, 0.8), 0.34, 40)
	plate.position = Vector3(-7.0, 2.35, -5.96)
	_clerk = Looks.make(self, {"model": "female", "shirt": Color(0.2, 0.45, 0.35), "pants": Color(0.25, 0.25, 0.3),
		"shoes": Color(0.2, 0.15, 0.12), "hair": "Hair_Buns", "hair_color": Color(0.6, 0.45, 0.25), "height": 1.66})
	_clerk.position = Vector3(-7.0, 0, -5.75)
	_clerk.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_clerk.play("Idle", 0.0)
	_bubble = B.bubble(_clerk, Vector3(0, 1.85, 0), Color.WHITE, 0.7)
	# Lampun ohjetaulu penkalla.
	B.sign_pole(self, Vector3(1.4, 0, 3.6), 1.9)
	var info := B.sign_plate(self, "ISTUTETTU KALALAMPI\nTaimen · Kirjolohi\nLupa tiskiltä · Onki 8 matoa", Color(0.95, 0.93, 0.82), Color(0.1, 0.2, 0.3), 0.26, 32, Color(0.1, 0.3, 0.2))
	info.position = Vector3(1.4, 1.55, 3.64)
	# Portti ja taksi: puomi, leirintäaluekyltti ja odottava taksi tien reunassa.
	B.mesh(self, B.boxm(Vector3(30.0, 0.02, 3.0)), Vector3(0, 0.003, 8.8), Color(0.3, 0.3, 0.32))  # tie
	B.mesh(self, B.boxm(Vector3(30.0, 0.025, 0.12)), Vector3(0, 0.01, 8.8), Color(0.9, 0.8, 0.3))
	for px in [-10.4, -8.4]:
		B.mesh(self, B.cyl(0.07, 0.07, 1.5, 8), Vector3(px, 0.75, 5.8), Color(0.35, 0.22, 0.12))
	B.mesh(self, B.boxm(Vector3(2.0, 0.1, 0.1)), Vector3(-9.4, 1.2, 5.8), Color(0.9, 0.9, 0.9))
	var taxi := Node3D.new()
	taxi.position = Vector3(-12.0, 0, 8.3)
	taxi.rotation.y = PI / 2.0
	add_child(taxi)
	Vehicles.taxi(taxi)
	# Asuntovaunu, teltta, nuotiopaikka ja piknikpöytä; kuuset reunoilla.
	_solid(Vector3(4.2, 2.0, 2.0), Vector3(-12.0, 1.0, -3.0), Color(0.93, 0.93, 0.9))
	B.mesh(self, B.boxm(Vector3(4.24, 0.3, 2.04)), Vector3(-12.0, 0.5, -3.0), Color(0.3, 0.45, 0.7))
	B.mesh(self, B.boxm(Vector3(1.0, 0.7, 0.04)), Vector3(-12.0, 1.3, -1.98), Color(0.6, 0.78, 0.9))
	B.mesh(self, B.boxm(Vector3(0.6, 0.08, 0.1)), Vector3(-9.6, 0.4, -3.0), Color(0.3, 0.3, 0.3))  # vetotanko
	var tent := B.mesh(self, B.cyl(0.0, 1.5, 1.3, 4), Vector3(-11.8, 0.65, 1.2), Color(0.85, 0.45, 0.15), Vector3(0, 45, 0))
	tent.scale = Vector3(1.0, 1.0, 1.3)
	B.mesh(self, B.boxm(Vector3(0.5, 0.9, 0.04)), Vector3(-11.8, 0.4, 2.15), Color(0.2, 0.15, 0.1))
	for k in 6:
		B.mesh(self, B.sphere(0.13, 6), Vector3(-3.0 + cos(k * 1.05) * 0.5, 0.1, 5.0 + sin(k * 1.05) * 0.5), Color(0.5, 0.5, 0.52))
	B.mesh(self, B.cyl(0.04, 0.06, 0.5, 6), Vector3(-3.1, 0.18, 5.0), Color(0.3, 0.2, 0.12), Vector3(0, 0, 25))
	_solid(Vector3(2.0, 0.08, 0.8), Vector3(-2.0, 0.78, 0.0), Color(0.6, 0.42, 0.24))
	B.mesh(self, B.boxm(Vector3(2.0, 0.06, 0.3)), Vector3(-2.0, 0.45, -0.7), Color(0.55, 0.38, 0.2))
	B.mesh(self, B.boxm(Vector3(2.0, 0.06, 0.3)), Vector3(-2.0, 0.45, 0.7), Color(0.55, 0.38, 0.2))
	for lx in [-2.8, -1.2]:
		B.mesh(self, B.boxm(Vector3(0.08, 0.75, 1.5)), Vector3(lx, 0.38, 0.0), Color(0.5, 0.34, 0.18))
	for k in 9:
		_spruce(Vector3(-14.0 + k * 3.4, 0, -9.3), 0.9 + (k % 3) * 0.2)
	for k in 3:
		_spruce(Vector3(14.2, 0, -7.0 + k * 5.5), 1.0 + (k % 2) * 0.2)
	for p in [Vector3(-14.2, 0, 3.8), Vector3(-9.0, 0, 3.4)]:
		_spruce(p, 1.1)
	# Aurinkoinen kesäpäivä: lämmin valo mökin kohdalle.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-7.0, 3.5, -3.0)
	lamp.light_color = Color(1.0, 0.9, 0.7)
	lamp.light_energy = 0.7
	lamp.omni_range = 9.0
	add_child(lamp)
