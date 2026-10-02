extends RefCounted
## Pankkiautomaatti (Otto.): seinään tai omaan kioskiin. Nosto 20 € kerran päivässä (main.gd _atm_use).
## Vaalassa K-Market Tervaportin seinällä Siitarin vieressä (vaala.gd), Saloisissa K-Marketin takaseinällä (world.gd / main.gd).

const B := preload("res://scripts/build.gd")
const DAILY := 20.0


## Automaatti kohtaan pos, näyttö suuntaan yaw (0 = -Z). kiosk = oma katollinen kioski (muuten seinäkotelo).
static func build(parent: Node3D, pos: Vector3, yaw: float, kiosk := false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var grey := Color(0.32, 0.34, 0.36)
	var blue := Color(0.0, 0.33, 0.62)
	if kiosk:
		var body := StaticBody3D.new()
		root.add_child(body)
		body.add_child(B.box_shape(Vector3(1.6, 2.6, 1.2), Vector3(0, 1.3, 0.3)))
		B.mesh(root, B.boxm(Vector3(1.6, 2.4, 1.2)), Vector3(0, 1.2, 0.3), Color(0.85, 0.86, 0.87))
		B.mesh(root, B.boxm(Vector3(1.9, 0.15, 1.6)), Vector3(0, 2.5, 0.2), grey)
	# Kotelo, näyttö, näppäimistö, kortti- ja setelirako.
	B.mesh(root, B.boxm(Vector3(0.9, 1.5, 0.1)), Vector3(0, 1.15, -0.32), grey)
	B.mesh(root, B.boxm(Vector3(0.9, 0.35, 0.1)), Vector3(0, 2.05, -0.32), blue)
	var logo := B.label(root, "Otto.", Vector3(0, 2.05, -0.38), 26, Color.WHITE)  # mahtuu siniseen kylttiin (0,9 × 0,35 m)
	logo.rotation.y = PI
	var screen := MeshInstance3D.new()
	screen.mesh = B.boxm(Vector3(0.5, 0.36, 0.02))
	screen.material_override = B.unshaded(Color(0.35, 0.6, 0.85))
	screen.position = Vector3(0, 1.45, -0.38)
	root.add_child(screen)
	B.mesh(root, B.boxm(Vector3(0.5, 0.06, 0.22)), Vector3(0, 1.08, -0.45), Color(0.2, 0.2, 0.22), Vector3(-25, 0, 0))
	B.mesh(root, B.boxm(Vector3(0.12, 0.02, 0.02)), Vector3(0.28, 1.25, -0.38), Color(0.05, 0.05, 0.05))
	B.mesh(root, B.boxm(Vector3(0.3, 0.03, 0.02)), Vector3(0, 0.88, -0.38), Color(0.05, 0.05, 0.05))
	return root
