extends Node3D
## Mirkun teltta Tarpion laavun vieressä: kahden hengen harjateltta, oranssi lentokangas vihreän sisäteltan päällä,
## harjatanko, kiristysnarut kiiloineen ja ovipäädyssä rullattu oviliepeä. Illalla sisällä palaa lyhty (set_glow):
## kangas hehkuu lämpimänä. set_closed sulkee oven vetoketjulla (loppukohtaus, main.gd _win_mirkku).
## Paikallinen -Z = ovi.

const B := preload("res://scripts/build.gd")

const L := 2.3   # pituus (Z)
const W := 1.8   # leveys (X)
const H := 1.15  # harjan korkeus

var _fly: StandardMaterial3D
var _light: OmniLight3D
var _door_open: Node3D
var _door_closed: Node3D


func _ready() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.add_child(B.box_shape(Vector3(W, H, L), Vector3(0, H / 2.0, 0)))
	var orange := Color(0.95, 0.45, 0.12)
	var green := Color(0.3, 0.5, 0.25)
	# Pohja: tumma pohjakangas reunuksena teltan alla.
	B.mesh(self, B.boxm(Vector3(W + 0.1, 0.02, L + 0.1)), Vector3(0, 0.01, 0), Color(0.15, 0.17, 0.2))
	# Sisäteltta (vihreä) ja sen päällä hieman isompi lentokangas (oranssi), harja keskellä.
	var inner := PrismMesh.new()
	inner.size = Vector3(W - 0.12, H - 0.06, L - 0.15)
	B.mesh(self, inner, Vector3(0, (H - 0.06) / 2.0, 0.02), green)
	var fly := PrismMesh.new()
	fly.size = Vector3(W, H, L - 0.35)
	_fly = B.mat(orange).duplicate() as StandardMaterial3D
	_fly.emission_enabled = true
	_fly.emission = Color(1.0, 0.6, 0.25)
	_fly.emission_energy_multiplier = 0.0
	var fm := B.mesh(self, fly, Vector3(0, H / 2.0, 0.17), orange)
	fm.material_override = _fly
	# Sauma ja heijastinraita lentokankaan reunassa, harjatanko ja tangon päät.
	for s in [-1.0, 1.0]:
		B.tube(self, Vector3(s * W / 2.0, 0.03, -L / 2.0 + 0.18), Vector3(s * W / 2.0, 0.03, L / 2.0), 0.012, orange.darkened(0.35))
	B.tube(self, Vector3(0, H + 0.01, -L / 2.0 + 0.15), Vector3(0, H + 0.01, L / 2.0 + 0.02), 0.012, Color(0.25, 0.25, 0.27))
	for z in [-L / 2.0 + 0.12, L / 2.0 - 0.02]:
		B.tube(self, Vector3(0, 0, z), Vector3(0, H + 0.03, z), 0.011, Color(0.55, 0.56, 0.6))
		B.mesh(self, B.sphere(0.022, 8), Vector3(0, H + 0.04, z), Color(0.15, 0.15, 0.16))
	# Kiristysnarut harjasta ja kulmista kiiloille.
	var rope := Color(0.92, 0.9, 0.8)
	var steel := Color(0.7, 0.71, 0.74)
	for z in [-L / 2.0 + 0.12, L / 2.0 - 0.02]:
		var out := Vector3(0, 0.02, z + signf(z) * 0.9)
		B.tube(self, Vector3(0, H + 0.02, z), out, 0.004, rope)
		B.mesh(self, B.boxm(Vector3(0.015, 0.08, 0.015)), out + Vector3(0, 0.03, 0), steel)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var a := Vector3(sx * W * 0.32, H * 0.36, sz * (L / 2.0 - 0.25))
			var peg := Vector3(sx * (W / 2.0 + 0.55), 0.02, sz * (L / 2.0 + 0.1))
			B.tube(self, a, peg, 0.004, rope)
			B.mesh(self, B.boxm(Vector3(0.015, 0.08, 0.015)), peg + Vector3(0, 0.03, 0), steel)
	# Ovipääty (-Z): tumma oviaukko ja molemmin puolin rullatut liepeet; suljettuna vetoketjullinen paneeli.
	_door_open = Node3D.new()
	add_child(_door_open)
	var hole := PrismMesh.new()
	hole.size = Vector3(W * 0.62, H * 0.78, 0.02)
	B.mesh(_door_open, hole, Vector3(0, H * 0.39, -L / 2.0 + 0.06), Color(0.06, 0.05, 0.05))
	for s in [-1.0, 1.0]:
		var roll := B.mesh(_door_open, B.cyl(0.04, 0.04, H * 0.62, 8), Vector3(s * W * 0.2, H * 0.34, -L / 2.0 + 0.05), green.darkened(0.1))
		roll.rotation.z = s * 0.52
	B.mesh(_door_open, B.boxm(Vector3(0.5, 0.06, 0.7)), Vector3(0.15, 0.04, -L / 2.0 + 0.45), Color(0.2, 0.35, 0.6))  # makuualusta
	_door_closed = Node3D.new()
	_door_closed.visible = false
	add_child(_door_closed)
	var panel := PrismMesh.new()
	panel.size = Vector3(W * 0.66, H * 0.82, 0.02)
	var pm := B.mesh(_door_closed, panel, Vector3(0, H * 0.41, -L / 2.0 + 0.055), green)
	pm.material_override = _fly
	B.tube(_door_closed, Vector3(0, 0.03, -L / 2.0 + 0.04), Vector3(0, H * 0.8, -L / 2.0 + 0.04), 0.006, Color(0.1, 0.1, 0.1))  # vetoketju
	# Lyhty sisällä: valo ilman varjoja (kangas hehkuu emissiolla, valo osuu ympäristöön).
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.7, 0.35)
	_light.light_energy = 0.0
	_light.omni_range = 5.0
	_light.position = Vector3(0, 0.6, 0)
	add_child(_light)


## Lyhdyn hehku 0..1: kangas loistaa sisältä ja valo osuu maahan teltan ympärillä.
func set_glow(f: float) -> void:
	_fly.emission_energy_multiplier = f * 1.6
	_light.light_energy = f * 1.4


func set_closed(on: bool) -> void:
	_door_open.visible = not on
	_door_closed.visible = on
