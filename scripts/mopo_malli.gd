extends RefCounted
## Oman mopon (oma_mopo.gd, #155) 3D-malli: tallissa (garage_interior.gd), ajossa (player_bike.gd) ja tappelun taustalla.

const B := preload("res://scripts/build.gd")


## 70-luvun mopo: punainen runko ja tankki, musta satula, kromilokasuojat, pyöreä ajovalo, tavarateline.
## Palauttaa pyörien kääntöpisteet (pyörivät ajettaessa).
static func build_model(parent: Node3D) -> Array[Node3D]:
	var red := Color(0.72, 0.08, 0.06)
	var black := Color(0.05, 0.05, 0.05)
	var chrome := Color(0.8, 0.8, 0.82)
	var wheels: Array[Node3D] = []
	for z in [-0.58, 0.6]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.3, z)
		parent.add_child(pivot)
		var tire := TorusMesh.new()
		tire.inner_radius = 0.2
		tire.outer_radius = 0.3
		tire.rings = 18
		tire.ring_segments = 8
		B.mesh(pivot, tire, Vector3.ZERO, black, Vector3(0, 0, 90))
		B.mesh(pivot, B.cyl(0.19, 0.19, 0.05, 14), Vector3.ZERO, chrome, Vector3(0, 0, 90))
		B.mesh(parent, B.boxm(Vector3(0.12, 0.03, 0.5)), Vector3(0, 0.63, z + (0.05 if z > 0 else -0.05)), chrome)
		wheels.append(pivot)
	# Runko: putki etuhaarukasta satulan alle ja moottori keskellä.
	B.tube(parent, Vector3(0, 1.0, -0.5), Vector3(0, 0.3, -0.58), 0.03, chrome)
	B.tube(parent, Vector3(0, 0.95, -0.46), Vector3(0, 0.45, 0.05), 0.04, red)
	B.tube(parent, Vector3(0, 0.45, 0.05), Vector3(0, 0.3, 0.6), 0.035, red)
	B.mesh(parent, B.boxm(Vector3(0.24, 0.26, 0.36)), Vector3(0, 0.38, 0.05), Color(0.25, 0.25, 0.27))
	B.mesh(parent, B.cyl(0.09, 0.09, 0.24, 10), Vector3(0.0, 0.38, -0.1), Color(0.55, 0.55, 0.57), Vector3(0, 0, 90))
	B.tube(parent, Vector3(0.1, 0.32, 0.1), Vector3(0.12, 0.3, 0.75), 0.035, chrome)  # pakoputki
	B.mesh(parent, B.boxm(Vector3(0.22, 0.2, 0.42)), Vector3(0, 0.78, -0.2), red)  # tankki
	B.mesh(parent, B.boxm(Vector3(0.24, 0.1, 0.5)), Vector3(0, 0.84, 0.25), black)  # satula
	B.mesh(parent, B.boxm(Vector3(0.3, 0.03, 0.34)), Vector3(0, 0.82, 0.62), chrome)  # tavarateline
	B.mesh(parent, B.boxm(Vector3(0.26, 0.24, 0.1)), Vector3(0, 0.72, 0.52), red)
	# Ohjaustanko, peilit ja ajovalo.
	B.tube(parent, Vector3(-0.32, 1.08, -0.46), Vector3(0.32, 1.08, -0.46), 0.018, chrome)
	for gx in [-0.3, 0.3]:
		B.tube(parent, Vector3(gx - 0.05, 1.08, -0.46), Vector3(gx + 0.05, 1.08, -0.46), 0.028, black)
		B.tube(parent, Vector3(gx * 0.8, 1.08, -0.46), Vector3(gx * 0.9, 1.3, -0.5), 0.01, chrome)
		B.mesh(parent, B.cyl(0.05, 0.05, 0.02, 10), Vector3(gx * 0.9, 1.32, -0.5), chrome, Vector3(90, 0, 0))
	B.mesh(parent, B.cyl(0.09, 0.1, 0.12, 14), Vector3(0, 0.95, -0.6), chrome, Vector3(90, 0, 0))
	B.mesh(parent, B.cyl(0.075, 0.075, 0.02, 14), Vector3(0, 0.95, -0.665), Color(1.0, 0.95, 0.75), Vector3(90, 0, 0))
	B.mesh(parent, B.boxm(Vector3(0.08, 0.05, 0.02)), Vector3(0, 0.72, 0.8), Color(0.8, 0.05, 0.05))  # takavalo
	var plate := B.mesh(parent, B.boxm(Vector3(0.16, 0.1, 0.01)), Vector3(0, 0.6, 0.82), Color(0.95, 0.95, 0.95))
	B.label(plate, "V12", Vector3(0, 0, 0.01), 18, Color.BLACK)
	return wheels
