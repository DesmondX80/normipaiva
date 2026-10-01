extends RefCounted
## Tarkemmat ajoneuvot: henkilöauto (maalipinta, lasit, kattopilarit, pyöräkotelot, vanteet, valot,
## suomalaiset rekisterikilvet) sekä moderni ja vanha traktori (kuviopinnaiset renkaat, lokasuojat,
## lasiohjaamo, maski säleikköineen, pakoputki, etupainot, nostolaite, majakka).

const B := preload("res://scripts/build.gd")

static var _mats := {}


static func paint(color: Color) -> StandardMaterial3D:
	var key := "paint" + color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = 0.45
		m.roughness = 0.28
		m.clearcoat_enabled = true
		m.clearcoat = 0.8
		m.clearcoat_roughness = 0.1
		_mats[key] = m
	return _mats[key]


static func _mat(key: String, color: Color, metallic: float, rough: float, alpha := 1.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color, alpha)
		m.metallic = metallic
		m.roughness = rough
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func glass() -> StandardMaterial3D:
	return _mat("glass", Color(0.08, 0.1, 0.13), 0.6, 0.04)


static func cab_glass() -> StandardMaterial3D:
	return _mat("cabglass", Color(0.35, 0.45, 0.5), 0.3, 0.05, 0.28)


static func chrome() -> StandardMaterial3D:
	return _mat("chrome", Color(0.8, 0.8, 0.82), 1.0, 0.18)


static func rubber() -> StandardMaterial3D:
	return _mat("rubber", Color(0.05, 0.05, 0.05), 0.0, 0.92)


static func plastic() -> StandardMaterial3D:
	return _mat("plastic", Color(0.08, 0.08, 0.09), 0.0, 0.6)


static func lamp(color: Color) -> StandardMaterial3D:
	var key := "lamp" + color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.6
		m.roughness = 0.1
		_mats[key] = m
	return _mats[key]


static func part(parent: Node3D, m: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Laatta kahden pisteen välille YZ-tasossa (tuulilasi, takalasi, pilarit).
static func slab(parent: Node3D, p0: Vector3, p1: Vector3, width: float, thick: float, mat: Material) -> MeshInstance3D:
	var z := (p1 - p0).normalized()
	var x := Vector3.RIGHT
	var y := z.cross(x).normalized()
	var mi := part(parent, B.boxm(Vector3(width, thick, p0.distance_to(p1))), (p0 + p1) / 2.0, mat)
	mi.basis = Basis(x, y, z)
	return mi


## Pyörä kuviopinnoin: palauttaa pyörivän solmun (akseli X).
static func wheel(parent: Node3D, pos: Vector3, r: float, w: float, lugs: int, rim_mat: Material, rim_r := 0.6) -> Node3D:
	var piv := Node3D.new()
	piv.position = pos
	parent.add_child(piv)
	part(piv, B.cyl(r * 0.94, r * 0.94, w, 20), Vector3.ZERO, rubber(), Vector3(0, 0, PI / 2.0))
	for side in [-1.0, 1.0]:
		part(piv, B.cyl(r * rim_r, r * rim_r, 0.02, 16), Vector3(side * (w / 2.0 + 0.005), 0, 0), rim_mat, Vector3(0, 0, PI / 2.0))
		part(piv, B.cyl(r * 0.14, r * 0.14, 0.04, 8), Vector3(side * (w / 2.0 + 0.02), 0, 0), chrome(), Vector3(0, 0, PI / 2.0))
		for k in 5:
			var a := TAU * k / 5.0
			part(piv, B.cyl(r * 0.035, r * 0.035, 0.03, 6), Vector3(side * (w / 2.0 + 0.02), cos(a) * r * 0.25, sin(a) * r * 0.25),
				chrome(), Vector3(0, 0, PI / 2.0))
	if lugs > 0:
		for k in lugs:
			var a := TAU * k / lugs
			for side in [-1.0, 1.0]:
				var lug := part(piv, B.boxm(Vector3(w * 0.46, r * 0.11, r * 0.2)), Vector3(side * w * 0.24, cos(a) * r * 0.97, sin(a) * r * 0.97), rubber())
				lug.basis = Basis(Vector3.RIGHT, a) * Basis(Vector3.UP, side * 0.45)
	else:
		part(piv, B.cyl(r, r, w * 0.8, 24), Vector3.ZERO, rubber(), Vector3(0, 0, PI / 2.0))
	return piv


static func _plate(parent: Node3D, pos: Vector3, back: bool, text: String) -> void:
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = 0.0 if back else PI
	parent.add_child(p)
	part(p, B.boxm(Vector3(0.52, 0.12, 0.015)), Vector3.ZERO, _mat("plate", Color(0.97, 0.97, 0.95), 0.2, 0.4))
	part(p, B.boxm(Vector3(0.05, 0.12, 0.018)), Vector3(-0.235, 0, 0), _mat("eu", Color(0.05, 0.2, 0.6), 0.0, 0.5))
	var l := Label3D.new()
	l.text = text
	l.font_size = 22
	l.pixel_size = 0.004
	l.modulate = Color.BLACK
	l.outline_size = 0
	l.double_sided = false
	l.position = Vector3(0.02, 0, 0.01)
	p.add_child(l)


## Henkilöauto -Z-suuntaan, n. 1,8 × 1,45 × 4,3 m. Palauttaa pyörät pyöritystä varten.
static func car(parent: Node3D, color: Color, plate := "") -> Array[Node3D]:
	var body := paint(color)
	if plate == "":
		plate = "%s%s%s-%d" % [char(65 + randi() % 26), char(65 + randi() % 26), char(65 + randi() % 26), 100 + randi() % 900]
	part(parent, B.boxm(Vector3(1.8, 0.5, 4.3)), Vector3(0, 0.6, 0), body)
	part(parent, B.boxm(Vector3(1.82, 0.12, 4.32)), Vector3(0, 0.4, 0), plastic())  # helmapuskuri
	slab(parent, Vector3(0, 0.84, -2.15), Vector3(0, 0.95, -0.95), 1.76, 0.1, body)  # konepelti
	slab(parent, Vector3(0, 0.95, 1.4), Vector3(0, 0.9, 2.15), 1.76, 0.1, body)  # takaluukku
	# Ohjaamo: tumma lasi sisällä, pilarit ja katto maalattuina.
	var wf0 := Vector3(0, 0.96, -0.95)
	var wf1 := Vector3(0, 1.42, -0.45)
	var wr0 := Vector3(0, 1.42, 0.95)
	var wr1 := Vector3(0, 0.96, 1.4)
	part(parent, B.boxm(Vector3(1.5, 0.44, 1.8)), Vector3(0, 1.18, 0.25), glass())
	slab(parent, wf0, wf1, 1.52, 0.04, glass())
	slab(parent, wr0, wr1, 1.52, 0.04, glass())
	part(parent, B.boxm(Vector3(1.56, 0.07, 1.45)), Vector3(0, 1.45, 0.25), body)
	for sx in [-0.77, 0.77]:
		slab(parent, wf0 + Vector3(sx, 0, 0), wf1 + Vector3(sx, 0, 0), 0.07, 0.07, body)
		slab(parent, wr0 + Vector3(sx, 0, 0), wr1 + Vector3(sx, 0, 0), 0.1, 0.07, body)
		part(parent, B.boxm(Vector3(0.06, 0.46, 0.1)), Vector3(sx, 1.18, 0.3), body)  # B-pilari
		part(parent, B.boxm(Vector3(0.06, 0.035, 1.9)), Vector3(sx, 0.96, 0.22), chrome())  # ikkunalista
		# Sivupeili, ovisaumat ja kahvat.
		part(parent, B.boxm(Vector3(0.14, 0.1, 0.18)), Vector3(sx * 1.2, 1.02, -0.8), body)
		part(parent, B.boxm(Vector3(0.02, 0.08, 0.14)), Vector3(sx * 1.28, 1.02, -0.8), glass())
		for dz in [-0.95, 0.3, 1.35]:
			part(parent, B.boxm(Vector3(0.01, 0.46, 0.012)), Vector3(sx * 1.171, 0.65, dz), plastic())
		for hz in [-0.1, 1.05]:
			part(parent, B.boxm(Vector3(0.03, 0.035, 0.16)), Vector3(sx * 1.175, 0.78, hz), chrome())
		# Pyöräkotelot.
		for wz in [-1.35, 1.35]:
			part(parent, B.cyl(0.4, 0.4, 0.04, 20), Vector3(sx * 1.155, 0.38, wz), plastic(), Vector3(0, 0, PI / 2.0))
	# Keula: maski, ajovalot, puskuri, kilpi.
	part(parent, B.boxm(Vector3(0.9, 0.2, 0.04)), Vector3(0, 0.68, -2.16), plastic())
	for k in 3:
		part(parent, B.boxm(Vector3(0.86, 0.02, 0.05)), Vector3(0, 0.6 + k * 0.07, -2.17), chrome())
	for sx in [-0.62, 0.62]:
		part(parent, B.boxm(Vector3(0.38, 0.13, 0.05)), Vector3(sx, 0.74, -2.16), lamp(Color(1.0, 0.98, 0.9)))
		part(parent, B.boxm(Vector3(0.36, 0.1, 0.05)), Vector3(sx, 0.76, 2.16), lamp(Color(0.8, 0.04, 0.03)))
		part(parent, B.boxm(Vector3(0.12, 0.08, 0.05)), Vector3(sx * 1.2, 0.76, 2.165), lamp(Color(1.0, 0.5, 0.1)))
	part(parent, B.boxm(Vector3(1.84, 0.18, 0.12)), Vector3(0, 0.45, -2.18), plastic())
	part(parent, B.boxm(Vector3(1.84, 0.18, 0.12)), Vector3(0, 0.45, 2.18), plastic())
	_plate(parent, Vector3(0, 0.47, -2.25), false, plate)
	_plate(parent, Vector3(0, 0.62, 2.18), true, plate)
	var wheels: Array[Node3D] = []
	for sx in [-0.84, 0.84]:
		for wz in [-1.35, 1.35]:
			wheels.append(wheel(parent, Vector3(sx, 0.34, wz), 0.34, 0.22, 0, chrome(), 0.62))
	return wheels


## Pakettiauto -Z-suuntaan (Transit-tyyppinen): lyhyt keula, korkea umpinainen tavaratila, takaovien sauma.
## Palauttaa pyörät kuten car().
static func van(parent: Node3D, color: Color, plate := "") -> Array[Node3D]:
	var body := paint(color)
	if plate == "":
		plate = "%s%s%s-%d" % [char(65 + randi() % 26), char(65 + randi() % 26), char(65 + randi() % 26), 100 + randi() % 900]
	part(parent, B.boxm(Vector3(1.95, 1.75, 3.9)), Vector3(0, 1.38, 0.45), body)  # tavaratila ja ohjaamo
	part(parent, B.boxm(Vector3(1.9, 0.62, 0.95)), Vector3(0, 0.82, -1.95), body)  # keula
	slab(parent, Vector3(0, 1.13, -2.42), Vector3(0, 1.16, -1.5), 1.86, 0.08, body)  # konepelti
	slab(parent, Vector3(0, 1.17, -1.5), Vector3(0, 2.05, -1.0), 1.8, 0.05, glass())  # tuulilasi
	part(parent, B.boxm(Vector3(1.98, 0.14, 4.9)), Vector3(0, 0.5, -0.05), plastic())  # helma
	for sx in [-0.98, 0.98]:
		part(parent, B.boxm(Vector3(0.02, 0.5, 0.75)), Vector3(sx, 1.65, -0.85), glass())  # sivuikkuna
		part(parent, B.boxm(Vector3(0.14, 0.12, 0.2)), Vector3(sx * 1.12, 1.6, -1.45), body)  # peili
		part(parent, B.boxm(Vector3(0.012, 1.3, 0.012)), Vector3(sx * 0.99, 1.25, 0.2), plastic())  # liukuoven sauma
		part(parent, B.boxm(Vector3(0.36, 0.13, 0.05)), Vector3(sx * 0.66, 0.98, -2.43), lamp(Color(1.0, 0.98, 0.9)))
		part(parent, B.boxm(Vector3(0.12, 0.42, 0.05)), Vector3(sx * 0.9, 1.0, 2.41), lamp(Color(0.8, 0.04, 0.03)))
	part(parent, B.boxm(Vector3(0.012, 1.5, 0.02)), Vector3(0, 1.38, 2.41), plastic())  # takaovien sauma
	part(parent, B.boxm(Vector3(0.95, 0.24, 0.04)), Vector3(0, 0.88, -2.43), plastic())  # maski
	part(parent, B.boxm(Vector3(1.96, 0.2, 0.12)), Vector3(0, 0.52, -2.47), plastic())
	part(parent, B.boxm(Vector3(1.96, 0.2, 0.12)), Vector3(0, 0.52, 2.45), plastic())
	_plate(parent, Vector3(0, 0.55, -2.54), false, plate)
	_plate(parent, Vector3(0, 0.62, 2.45), true, plate)
	var wheels: Array[Node3D] = []
	for sx in [-0.86, 0.86]:
		for wz in [-1.65, 1.55]:
			wheels.append(wheel(parent, Vector3(sx, 0.36, wz), 0.36, 0.24, 0, chrome(), 0.6))
	return wheels


## Taksi: tumma farmari, katolla keltainen TAXI-kupu. Palauttaa pyörät kuten car().
static func taxi(parent: Node3D, plate := "") -> Array[Node3D]:
	var wheels := car(parent, Color(0.08, 0.08, 0.1), plate)
	part(parent, B.boxm(Vector3(0.5, 0.18, 0.2)), Vector3(0, 1.58, 0.25), lamp(Color(1.0, 0.85, 0.2)))
	for side in [0.0, PI]:
		var l := Label3D.new()
		l.text = "TAXI"
		l.font_size = 26
		l.pixel_size = 0.005
		l.modulate = Color(0.1, 0.08, 0.02)
		l.outline_size = 0
		l.double_sided = false
		l.rotation.y = side
		l.position = Vector3(0, 1.58, 0.25 + (0.105 if side == 0.0 else -0.105))
		parent.add_child(l)
	return wheels


## Traktori -Z-suuntaan. style "modern" (Valtra-tyylinen lasiohjaamo) tai "old" (pieni vanha, ei ohjaamoa).
## Palauttaa {"rear": [pyörät], "front": [pyörät]}.
static func tractor(parent: Node3D, color: Color, style := "modern") -> Dictionary:
	var body := paint(color)
	var dark := plastic()
	var steel := _mat("steel", Color(0.3, 0.3, 0.32), 0.6, 0.45)
	var rim := paint(Color(0.85, 0.85, 0.82)) if style == "modern" else paint(Color(0.2, 0.2, 0.2))
	var old := style == "old"
	var k := 0.75 if old else 1.0  # vanha on pienempi
	# Runko ja moottori.
	part(parent, B.boxm(Vector3(0.7 * k, 0.45 * k, 2.8 * k)), Vector3(0, 0.75 * k, -0.2 * k), steel)
	part(parent, B.boxm(Vector3(0.95 * k, 0.8 * k, 2.0 * k)), Vector3(0, 1.3 * k, -1.0 * k), body)  # konepelti
	slab(parent, Vector3(0, 1.7 * k, -2.0 * k), Vector3(0, 1.72 * k, -0.2 * k), 0.95 * k, 0.06, body)
	# Maski: säleikkö ja valot.
	part(parent, B.boxm(Vector3(0.85 * k, 0.6 * k, 0.05)), Vector3(0, 1.28 * k, -2.02 * k), dark)
	for i in 6:
		part(parent, B.boxm(Vector3(0.8 * k, 0.03, 0.06)), Vector3(0, 1.02 * k + i * 0.1 * k, -2.04 * k), steel)
	for sx in [-0.32, 0.32]:
		part(parent, B.boxm(Vector3(0.14 * k, 0.1 * k, 0.05)), Vector3(sx * k, 1.62 * k, -2.03 * k), lamp(Color(1, 0.98, 0.9)))
	# Konepellin sivujen ilmanotot.
	for sx in [-1.0, 1.0]:
		for i in 5:
			part(parent, B.boxm(Vector3(0.02, 0.04, 0.5 * k)), Vector3(sx * 0.48 * k, 1.2 * k + i * 0.08 * k, -1.2 * k), dark)
	# Pakoputki ja imuputki.
	part(parent, B.cyl(0.06, 0.06, 1.3 * k, 10), Vector3(0.3 * k, 2.2 * k, -0.45 * k), steel)
	part(parent, B.cyl(0.075, 0.06, 0.12, 10), Vector3(0.3 * k, 2.88 * k, -0.45 * k), dark)
	if not old:
		part(parent, B.cyl(0.07, 0.07, 1.0, 10), Vector3(-0.3, 2.1, -0.45), dark)
		# Etupainot ja etunostolaite.
		for i in 6:
			part(parent, B.boxm(Vector3(0.8, 0.14, 0.2)), Vector3(0, 0.65 + i * 0.15, -2.35), dark)
		part(parent, B.boxm(Vector3(1.0, 0.1, 0.25)), Vector3(0, 0.55, -2.3), steel)
	# Ohjaamo.
	if old:
		part(parent, B.boxm(Vector3(0.45, 0.1, 0.4)), Vector3(0, 1.3, 0.55), dark)  # istuin
		part(parent, B.cyl(0.18, 0.18, 0.03, 16), Vector3(0, 1.55, 0.1), dark, Vector3(-0.8, 0, 0))  # ratti
	else:
		var cz := 0.75
		part(parent, B.boxm(Vector3(1.55, 0.12, 1.55)), Vector3(0, 1.1, cz), steel)  # lattia
		part(parent, B.boxm(Vector3(1.5, 1.5, 1.5)), Vector3(0, 1.95, cz), cab_glass())
		for sx in [-0.76, 0.76]:
			for sz in [-0.74, 0.74]:
				part(parent, B.boxm(Vector3(0.07, 1.55, 0.07)), Vector3(sx, 1.95, cz + sz), dark)
			part(parent, B.boxm(Vector3(0.05, 0.05, 1.5)), Vector3(sx, 2.72, cz), dark)
			part(parent, B.boxm(Vector3(0.05, 0.05, 1.5)), Vector3(sx, 1.2, cz), dark)
			# Peilit varsineen.
			part(parent, B.boxm(Vector3(0.4, 0.03, 0.03)), Vector3(sx * 1.2, 2.45, cz - 0.7), dark)
			part(parent, B.boxm(Vector3(0.03, 0.3, 0.18)), Vector3(sx * 1.45, 2.35, cz - 0.7), dark)
		part(parent, B.boxm(Vector3(1.7, 0.14, 1.75)), Vector3(0, 2.8, cz), body)  # katto
		part(parent, B.boxm(Vector3(1.72, 0.04, 1.77)), Vector3(0, 2.72, cz), paint(Color(0.92, 0.92, 0.9)))
		for sx in [-0.6, 0.6]:
			part(parent, B.boxm(Vector3(0.16, 0.08, 0.06)), Vector3(sx, 2.8, cz - 0.9), lamp(Color(1, 0.98, 0.9)))
		part(parent, B.cyl(0.08, 0.1, 0.16, 12), Vector3(0.55, 2.95, cz + 0.6), lamp(Color(1.0, 0.55, 0.05)))  # majakka
		part(parent, B.boxm(Vector3(0.5, 0.12, 0.45)), Vector3(0, 1.45, cz + 0.2), dark)
		part(parent, B.cyl(0.18, 0.18, 0.03, 16), Vector3(0, 1.85, cz - 0.4), dark, Vector3(-0.9, 0, 0))
		# Astinlaudat.
		for i in 3:
			part(parent, B.boxm(Vector3(0.3, 0.03, 0.25)), Vector3(-0.85, 0.5 + i * 0.25, cz - 0.3), steel)
	# Takanostolaite.
	for sx in [-0.3, 0.3]:
		slab(parent, Vector3(sx * k, 0.8 * k, 1.1 * k), Vector3(sx * k, 0.55 * k, 1.8 * k), 0.07, 0.07, steel)
	part(parent, B.cyl(0.04, 0.04, 0.2, 8), Vector3(0, 0.75 * k, 1.25 * k), steel, Vector3(PI / 2.0, 0, 0))
	# Pyörät ja lokasuojat.
	var rr := 0.82 * k
	var fr := 0.5 * k
	var rear: Array[Node3D] = []
	var front: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		rear.append(wheel(parent, Vector3(sx * 0.98 * k, rr, 0.75 * k), rr, 0.55 * k, 22, rim, 0.55))
		front.append(wheel(parent, Vector3(sx * 0.8 * k, fr, -1.6 * k), fr, 0.36 * k, 16, rim, 0.55))
		# Takalokasuoja: katto + viistot päät.
		var fx: float = sx * 0.98 * k
		part(parent, B.boxm(Vector3(0.62 * k, 0.05, 0.9 * k)), Vector3(fx, rr * 2.0 + 0.08, 0.75 * k), body)
		slab(parent, Vector3(fx, rr * 2.0 + 0.08, 0.3 * k), Vector3(fx, rr * 1.35, -0.25 * k), 0.62 * k, 0.05, body)
		slab(parent, Vector3(fx, rr * 2.0 + 0.08, 1.2 * k), Vector3(fx, rr * 1.35, 1.72 * k), 0.62 * k, 0.05, body)
		part(parent, B.boxm(Vector3(0.1, 0.1, 0.12)), Vector3(fx, rr * 1.6, 1.75 * k), lamp(Color(0.8, 0.05, 0.03)))
		if not old:
			part(parent, B.boxm(Vector3(0.42, 0.04, 0.6)), Vector3(sx * 0.8, fr * 2.0 + 0.1, -1.6), body)  # etulokasuoja
	part(parent, B.boxm(Vector3(1.5 * k, 0.12, 0.14)), Vector3(0, fr, -1.6 * k), steel)  # etuakseli
	return {"rear": rear, "front": front}
