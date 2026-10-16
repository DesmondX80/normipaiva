## Vanha tavaramakasiini aseman takana (Saloinen world.gd, Vaala vaala.gd): punamultalaudoitus haalistunut ja
## lohkeillut, ikkunat lankutettu, huopakatto, kivijalka ja lastauslaituri radan puolella, kadun puolella ketjulla
## lukitut liukuovet. Länsipäädyssä portaiden päällä teräksinen takaovi kurkistusluukkuineen ja punainen lamppu
## häkissä: siellä pelataan rasvanappia (main.gd _makasiini_logic, rasvanappi_game.gd).
## Paikallinen kehys: X radan suuntaan, -Z radan puoli, takaovi -X-päädyssä. Kivijalka ulottuu 1 m maan alle.

const B := preload("res://scripts/build.gd")
const StationBuild := preload("res://scripts/station_build.gd")

const L := 13.0
const D := 7.0
## Takaoven edusta portaiden alla (paikallinen): tästä koputetaan.
const DOOR := Vector3(-L / 2.0 - 1.95, 0, 1.2)
## Pohja romuineen ja portaineen (paikallinen, XZ): maaston tasaisuus ja raivaus.
const FOOTPRINT := Rect2(-L / 2.0 - 2.6, -D / 2.0 - 2.0, L + 3.2, D + 2.6)
## Takaoven solmu (rasvanappi_game.gd): oven paikallinen +Z ulos, origo kynnyksellä seinän ulkopinnassa.
## Lapset: "Ovi" (saranasolmu, kiertyy Y:n ympäri ulos), "Ovi/Luukku" (kansi liukuu +X:ään), "Lamppu" (OmniLight3D).
const DOOR_Z := 1.2  # oven keskikohta paikallisessa Z:ssa
const GAP := 0.45  # eteiskomeron syvyys päätyseinän ja hallin välissä (portsari seisoo siinä)
const HOLE := Vector2(1.16, 2.18)  # oviaukko karmeineen
const HATCH_Y := 1.63  # luukun keskikohta kynnyksestä
const HATCH := Vector2(0.3, 0.13)  # luukun aukko
const HATCH_TRAVEL := 0.31  # kannen liuku auki


static func build(root: Node3D) -> void:
	var F := 0.7  # lattian korkeus
	var H := 3.3  # seinän korkeus lattiasta
	var red := Color(0.46, 0.17, 0.12)
	var red_dark := Color(0.36, 0.13, 0.1)
	var white := Color(0.82, 0.8, 0.74)
	var stone := Color(0.5, 0.49, 0.46)
	var felt := Color(0.17, 0.17, 0.19)
	var wood := Color(0.42, 0.34, 0.26)
	var batch := StationBuild.Batch.new()
	# Kivijalka ja seinät (törmäys yhtenä laatikkona).
	B.box(root, Vector3(L + 0.2, F + 1.0, D + 0.2), Vector3(0, (F - 1.0) / 2.0, 0), stone)
	B.box(root, Vector3(L - GAP, H, D), Vector3(GAP / 2.0, F + H / 2.0, 0), red)
	# Länsipääty ohuena seinänä, jossa oviaukko; sen ja hallin väliin jää eteiskomero (GAP).
	var hz0 := DOOR_Z - HOLE.x / 2.0
	var hz1 := DOOR_Z + HOLE.x / 2.0
	var ex := -L / 2.0 + 0.025
	B.box(root, Vector3(0.05, H, hz0 + D / 2.0), Vector3(ex, F + H / 2.0, (hz0 - D / 2.0) / 2.0), red)
	B.box(root, Vector3(0.05, H, D / 2.0 - hz1), Vector3(ex, F + H / 2.0, (hz1 + D / 2.0) / 2.0), red)
	B.box(root, Vector3(0.05, H - HOLE.y, HOLE.x), Vector3(ex, F + HOLE.y + (H - HOLE.y) / 2.0, DOOR_Z), red)
	for zs in [-1.0, 1.0]:
		B.box(root, Vector3(GAP, H, 0.05), Vector3(-L / 2.0 + GAP / 2.0, F + H / 2.0, zs * (D / 2.0 - 0.025)), red, false)
	B.box(root, Vector3(GAP, 0.05, D), Vector3(-L / 2.0 + GAP / 2.0, F + H - 0.025, 0), red, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Pystylautojen peitelistat, lohkeillut maali (harmaat laikut) ja valkoiset nurkkalistat.
	for side in [-1.0, 1.0]:
		var n := int(L / 0.45)
		for i in n + 1:
			var x := -L / 2.0 + i * L / n
			batch.add(Vector3(0.07, H, 0.04), Vector3(x, F + H / 2.0, side * (D / 2.0 + 0.02)), red_dark)
		for i in 9:
			var px := rng.randf_range(-L / 2.0 + 0.5, L / 2.0 - 0.5)
			var py := rng.randf_range(F + 0.3, F + H - 0.4)
			batch.add(Vector3(rng.randf_range(0.2, 0.7), rng.randf_range(0.1, 0.35), 0.01), Vector3(px, py, side * (D / 2.0 + 0.045)),
				Color(0.55, 0.52, 0.48))
		for i in int(D / 0.45) + 1:
			var z := -D / 2.0 + i * D / int(D / 0.45)
			if side < 0.0 and absf(z - DOOR_Z) < HOLE.x / 2.0 + 0.04:
				continue  # oviaukko
			batch.add(Vector3(0.04, H, 0.07), Vector3(side * (L / 2.0 + 0.02), F + H / 2.0, z), red_dark)
		for zs in [-1.0, 1.0]:
			batch.add(Vector3(0.14, H, 0.14), Vector3(side * L / 2.0, F + H / 2.0, zs * D / 2.0), white)
		batch.add(Vector3(L + 0.1, 0.16, 0.06), Vector3(0, F + H - 0.08, side * (D / 2.0 + 0.04)), white)  # räystäslista
	# Päätykolmiot ja katto (loiva harja X-suunnassa, räystäät ulkona, radan puolella pitkä lippa laiturin yllä).
	var rise := 1.4
	for side in [-1.0, 1.0]:
		var gable := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(D, rise, 0.1)
		gable.mesh = pm
		gable.material_override = B.mat(red)
		gable.position = Vector3(side * (L / 2.0 - 0.03), F + H + rise / 2.0, 0)
		gable.rotation.y = PI / 2.0
		root.add_child(gable)
	var slope := atan2(rise, D / 2.0)
	for zs in [-1.0, 1.0]:
		var over := 1.9 if zs < 0.0 else 0.5  # lastauslaiturin lippa radan puolella
		var run := D / 2.0 + over  # harjalta räystään reunaan vaakasuunnassa
		var w := run / cos(slope)
		var slab := MeshInstance3D.new()
		slab.mesh = B.boxm(Vector3(L + 1.0, 0.12, w))
		slab.material_override = B.mat(felt)
		slab.position = Vector3(0, F + H + rise - run / 2.0 * tan(slope) + 0.06, zs * run / 2.0)
		slab.rotation.x = zs * slope
		root.add_child(slab)
		for i in 9:  # huopakaistojen saumat
			var sx := -L / 2.0 + 0.2 + i * (L + 0.6) / 9.0
			var seam := MeshInstance3D.new()
			seam.mesh = B.boxm(Vector3(0.05, 0.03, w))
			seam.material_override = B.mat(felt.lightened(0.12))
			seam.position = slab.position + Vector3(sx, 0.075, 0)
			seam.rotation.x = slab.rotation.x
			root.add_child(seam)
	# Lastauslaituri radan puolella: lankkukansi ja tolpat.
	B.box(root, Vector3(L, 0.12, 1.8), Vector3(0, F - 0.06, -D / 2.0 - 0.9), wood)
	for i in 7:
		batch.add(Vector3(0.18, F + 0.3, 0.18), Vector3(-L / 2.0 + 0.2 + i * (L - 0.4) / 6.0, (F - 0.3) / 2.0, -D / 2.0 - 1.7), wood.darkened(0.3))
	for i in int(L / 0.25):
		batch.add(Vector3(0.02, 0.005, 1.8), Vector3(-L / 2.0 + i * 0.25, F + 0.003, -D / 2.0 - 0.9), wood.darkened(0.25))
	# Liukuovet kummallakin pitkällä sivulla: ristituet, kisko, kadun puolella ketju ja munalukko.
	for zs in [-1.0, 1.0]:
		var z: float = zs * (D / 2.0 + 0.07)
		for dx in [-1.5, 1.5]:
			batch.add(Vector3(2.9, 2.6, 0.08), Vector3(1.0 + dx, F + 1.3, z), Color(0.5, 0.42, 0.33))
			batch.add(Vector3(2.9, 0.12, 0.1), Vector3(1.0 + dx, F + 1.3, z + zs * 0.03), Color(0.4, 0.33, 0.26))
			var brace := Basis(Vector3(0, 0, 1), atan2(2.4, 2.7))
			batch.add(Vector3(3.5, 0.12, 0.1), Vector3(1.0 + dx, F + 1.3, z + zs * 0.04), Color(0.4, 0.33, 0.26), brace)
			batch.add(Vector3(3.5, 0.12, 0.1), Vector3(1.0 + dx, F + 1.3, z + zs * 0.04), Color(0.4, 0.33, 0.26), brace.inverse())
		batch.add(Vector3(6.6, 0.1, 0.12), Vector3(1.0, F + 2.7, z + zs * 0.05), Color(0.2, 0.2, 0.2))
	for i in 7:
		batch.add(Vector3(0.08, 0.05, 0.03), Vector3(0.75 + i * 0.07, F + 1.2 - absf(i - 3) * 0.04, D / 2.0 + 0.16), Color(0.45, 0.45, 0.45))
	batch.add(Vector3(0.12, 0.15, 0.06), Vector3(1.0, F + 1.06, D / 2.0 + 0.18), Color(0.7, 0.6, 0.2))
	# Lankutetut ikkunat.
	for zs in [-1.0, 1.0]:
		for wx in [-4.6, -2.6, 5.3]:
			var z: float = zs * (D / 2.0 + 0.06)
			batch.add(Vector3(1.1, 0.8, 0.04), Vector3(wx, F + 2.3, z), white)
			batch.add(Vector3(0.95, 0.65, 0.05), Vector3(wx, F + 2.3, z + zs * 0.01), Color(0.72, 0.62, 0.45))
			for b in [-1.0, 1.0]:
				batch.add(Vector3(1.2, 0.1, 0.04), Vector3(wx, F + 2.3, z + zs * 0.04), Color(0.58, 0.48, 0.34), Basis(Vector3(0, 0, 1), b * 0.5))
	# Kyltti kadun puolella: haalistunut tavaramakasiinin nimi.
	var sign := B.sign_plate(root, "TAVARAMAKASIINI", Color(0.78, 0.74, 0.62), Color(0.3, 0.22, 0.18), 0.32, 52, Color(0.5, 0.45, 0.38))
	sign.position = Vector3(1.0, F + 3.0, D / 2.0 + 0.1)
	# Takaovi länsipäädyssä (oma solmu, rasvanappi_game.gd liikuttaa ovea, luukkua ja lamppua) ja betoniportaat.
	var dz := DOOR_Z
	var dx := -L / 2.0 - 0.05
	var door := _build_door()
	door.position = Vector3(-L / 2.0, F, dz)
	door.rotation.y = -PI / 2.0
	root.add_child(door)
	for i in 3:
		var sx := dx - 0.4 - i * 0.35
		B.box(root, Vector3(0.35 + (2 - i) * 0.0, F * (3 - i) / 3.0, 1.6), Vector3(sx, F * (3 - i) / 6.0, dz), stone.lightened(0.05), false)
	B.box(root, Vector3(0.45, 0.06, 1.6), Vector3(dx - 0.25, F + 0.03, dz), stone.lightened(0.08), false)
	var note := B.sign_plate(root, "EI MYYJIÄ", Color(0.88, 0.85, 0.72), Color(0.2, 0.1, 0.1), 0.1, 24, Color(0.6, 0.55, 0.45))
	note.position = Vector3(dx - 0.01, F + 1.45, dz + 1.0)
	note.rotation.y = -PI / 2.0
	# Romua takaoven luona: roskalava, kaljakoreja, nojaava kuormalava ja tumppipurkki.
	B.box(root, Vector3(1.0, 1.1, 1.6), Vector3(dx - 0.8, 0.55, -1.6), Color(0.2, 0.38, 0.22))
	batch.add(Vector3(1.05, 0.08, 1.65), Vector3(dx - 0.8, 1.14, -1.6), Color(0.15, 0.3, 0.17), Basis(Vector3(0, 0, 1), -0.08))
	for i in 4:
		var cp := Vector3(dx - 0.6 - (i % 2) * 0.45, 0.16 + (i / 2) * 0.32, 2.6 + (i % 2) * 0.05)
		batch.add(Vector3(0.4, 0.3, 0.3), cp, Color(0.85, 0.65, 0.12))
		batch.add(Vector3(0.36, 0.02, 0.26), cp + Vector3(0, 0.15, 0), Color(0.3, 0.22, 0.05))
	batch.add(Vector3(0.12, 1.2, 0.8), Vector3(dx - 0.12, 0.6, 3.0), Color(0.6, 0.5, 0.35), Basis(Vector3(0, 0, 1), 0.12))
	batch.add(Vector3(0.18, 0.25, 0.18), Vector3(dx - 1.0, 0.12, 0.2), Color(0.5, 0.5, 0.48))
	batch.commit(root)


## Samanväriset palat (laatikot, pallot, lieriöt) yhdeksi meshiksi värikohtaisesti; metal = metallinen kiilto.
class Parts:
	var _st := {}

	func add(m: Mesh, xf: Transform3D, color: Color) -> void:
		var key := color.to_html()
		if not _st.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_st[key] = [st, color]
		(_st[key][0] as SurfaceTool).append_from(m, 0, xf)

	func box(size: Vector3, pos: Vector3, color: Color, basis := Basis()) -> void:
		add(B.boxm(size), Transform3D(basis, pos), color)

	func ball(r: float, pos: Vector3, color: Color, squash := Vector3.ONE) -> void:
		add(B.sphere(r, 8), Transform3D(Basis.from_scale(squash), pos), color)

	func cyl(r: float, h: float, pos: Vector3, color: Color, basis := Basis()) -> void:
		add(B.cyl(r, r, h, 12), Transform3D(basis, pos), color)

	func commit(parent: Node3D, metal := 0.0) -> void:
		for key in _st:
			var mi := MeshInstance3D.new()
			mi.mesh = (_st[key][0] as SurfaceTool).commit()
			var m := StandardMaterial3D.new()
			m.albedo_color = _st[key][1]
			m.metallic = metal
			m.roughness = 0.5 if metal > 0.0 else 0.85
			mi.material_override = m
			parent.add_child(mi)


## Takaovi omana solmunaan (oven paikallinen kehys, +Z ulos): teräskarmi, saranoilla avautuva ovilehti
## kurkistusluukkuineen, niitteineen ja ruosteineen, potkulevy lommoineen, kahva ja lukko, eteiskomero oven takana
## (portsari seisoo siinä, rasvanappi_game.gd) ja punainen lamppu häkissä oven yllä.
static func _build_door() -> Node3D:
	var door := Node3D.new()
	door.name = "Takaovi"
	var steel := Color(0.14, 0.14, 0.15)
	var green := Color(0.2, 0.28, 0.25)
	var rim := green.lightened(0.07)
	var rivet := Color(0.36, 0.4, 0.37)
	var rust := Color(0.17, 0.1, 0.06)
	var chip := Color(0.3, 0.36, 0.33)
	var kick := Color(0.44, 0.44, 0.42)
	var brass := Color(0.66, 0.62, 0.52)
	var dark_wood := Color(0.19, 0.14, 0.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var hy := HATCH_Y
	var hw := HATCH.x / 2.0
	var hh := HATCH.y / 2.0
	# Karmi, saranat ja kynnys.
	var fm := Parts.new()
	for s in [-1.0, 1.0]:
		fm.box(Vector3(0.08, HOLE.y, 0.16), Vector3(s * (HOLE.x / 2.0 - 0.04), HOLE.y / 2.0, 0.01), steel)
	fm.box(Vector3(HOLE.x, 0.08, 0.16), Vector3(0, HOLE.y - 0.04, 0.01), steel)
	fm.box(Vector3(HOLE.x, 0.03, 0.22), Vector3(0, 0.015, 0.04), kick.darkened(0.2))
	for y in [0.3, 1.05, 1.8]:
		fm.cyl(0.022, 0.15, Vector3(0.505, y, 0.065), steel.lightened(0.15))
	fm.commit(door, 0.4)
	# Eteiskomero: seinät, katto ja lattia tummaa lautaa, perällä pimeä halli.
	var vm := Parts.new()
	var depth := GAP - 0.05
	for s in [-1.0, 1.0]:
		vm.box(Vector3(0.04, 2.3, depth), Vector3(s * 0.6, 1.15, -0.05 - depth / 2.0), dark_wood)
	vm.box(Vector3(1.24, 0.04, depth), Vector3(0, 2.2, -0.05 - depth / 2.0), dark_wood)
	vm.box(Vector3(1.2, 0.015, depth), Vector3(0, 0.008, -0.05 - depth / 2.0), dark_wood.darkened(0.2))
	vm.box(Vector3(1.2, 2.2, 0.02), Vector3(0, 1.1, -GAP + 0.012), Color(0.02, 0.018, 0.016))
	for i in 5:
		vm.box(Vector3(0.012, 2.28, 0.01), Vector3(-0.58 + 0.01, 1.14, -0.08 - i * 0.075), dark_wood.darkened(0.3))
	vm.commit(door)
	var body := StaticBody3D.new()
	body.add_child(B.box_shape(Vector3(HOLE.x, HOLE.y, 0.12), Vector3(0, HOLE.y / 2.0, 0.03)))
	door.add_child(body)
	# Ovilehti saranasolmussa (+X-reunalla): palat luukun aukon ympäriltä, kehys, niitit, ruoste, potkulevy.
	var pivot := Node3D.new()
	pivot.name = "Ovi"
	pivot.position = Vector3(0.5, 0, 0.03)
	door.add_child(pivot)
	var lm := Parts.new()
	var lx := -0.5  # lehden keskikohta saranasolmussa
	lm.box(Vector3(1.0, hy - hh - 0.02, 0.05), Vector3(lx, (0.02 + hy - hh) / 2.0, 0), green)
	lm.box(Vector3(1.0, 2.09 - hy - hh, 0.05), Vector3(lx, (hy + hh + 2.09) / 2.0, 0), green)
	var side_w := 0.5 - hw
	lm.box(Vector3(side_w, HATCH.y, 0.05), Vector3(-1.0 + side_w / 2.0, hy, 0), green)
	lm.box(Vector3(side_w, HATCH.y, 0.05), Vector3(-side_w / 2.0, hy, 0), green)
	for x in [-0.975, -0.025]:
		lm.box(Vector3(0.05, 2.07, 0.012), Vector3(x, 1.055, 0.03), rim)
	for y in [0.045, 2.065, 0.95]:
		lm.box(Vector3(1.0, 0.05 if y != 0.95 else 0.035, 0.012), Vector3(lx, y, 0.03), rim)
	var rivets: Array[Vector3] = []
	for i in 12:
		for x in [-0.975, -0.025]:
			rivets.append(Vector3(x, 0.13 + i * 0.165, 0.038))
	for i in 5:
		for y in [0.045, 2.065, 0.95]:
			rivets.append(Vector3(-0.85 + i * 0.175, y, 0.038))
	for r in rivets:
		lm.ball(0.011, r, rivet, Vector3(1, 1, 0.6))
		if rng.randf() < 0.35:  # ruostevana niitin alla
			var ln := rng.randf_range(0.04, 0.16)
			lm.box(Vector3(rng.randf_range(0.006, 0.014), ln, 0.003), r + Vector3(rng.randf_range(-0.003, 0.003), -ln / 2.0 - 0.01, -0.004), rust)
	for i in 10:  # lohkeillut maali
		var p := Vector3(rng.randf_range(-0.9, -0.1), rng.randf_range(0.4, 1.9), 0.0265)
		if absf(p.y - hy) < 0.15 or absf(p.y - 1.0) < 0.15:
			continue
		lm.box(Vector3(rng.randf_range(0.012, 0.035), rng.randf_range(0.008, 0.025), 0.002), p, chip if i % 3 != 0 else rust)
	# Potkulevy lommoineen ja naarmuineen.
	lm.box(Vector3(0.94, 0.3, 0.006), Vector3(lx, 0.2, 0.029), kick)
	for x in [-0.27, -0.55, -0.78]:
		lm.ball(0.05, Vector3(x, 0.2 + rng.randf_range(-0.04, 0.04), 0.031), kick.darkened(0.3), Vector3(1.0, 0.8, 0.06))
	for i in 6:
		lm.box(Vector3(rng.randf_range(0.05, 0.15), 0.003, 0.002), Vector3(rng.randf_range(-0.85, -0.15), rng.randf_range(0.08, 0.33), 0.0325),
			kick.lightened(0.25), Basis(Vector3(0, 0, 1), rng.randf_range(-0.4, 0.4)))
	for i in 4:
		lm.ball(0.004, Vector3(-0.96 + (i % 2) * 0.92, 0.07 + (i / 2) * 0.26, 0.034), rivet)
	# Luukun kehys: kiskot ylä- ja alapuolella saranan puolelle, vasen reuna ja oikea vaste.
	for s in [-1.0, 1.0]:
		lm.box(Vector3(0.68, 0.022, 0.026), Vector3(-0.34, hy + s * (hh + 0.016), 0.038), steel)
	lm.box(Vector3(0.025, HATCH.y + 0.05, 0.026), Vector3(-0.5 - hw - 0.0125, hy, 0.038), steel)
	lm.box(Vector3(0.012, HATCH.y + 0.05, 0.03), Vector3(-0.008, hy, 0.04), steel)
	lm.commit(pivot, 0.15)
	# Kahva, lukko ja kurkistusluukun kansi (metalli).
	var hm := Parts.new()
	hm.box(Vector3(0.065, 0.25, 0.016), Vector3(-0.86, 1.0, 0.033), brass.darkened(0.15))
	hm.box(Vector3(0.03, 0.03, 0.045), Vector3(-0.86, 1.06, 0.06), brass)
	hm.cyl(0.015, 0.15, Vector3(-0.8, 1.06, 0.08), brass, Basis(Vector3(0, 0, 1), PI / 2.0))
	hm.ball(0.02, Vector3(-0.725, 1.06, 0.08), brass)
	hm.cyl(0.019, 0.02, Vector3(-0.86, 0.94, 0.045), brass.lightened(0.1), Basis(Vector3(1, 0, 0), PI / 2.0))
	hm.box(Vector3(0.005, 0.016, 0.004), Vector3(-0.86, 0.94, 0.056), Color(0.05, 0.05, 0.05))
	hm.commit(pivot, 0.6)
	var cover := Node3D.new()
	cover.name = "Luukku"
	cover.position = Vector3(-0.5, hy, 0.042)
	pivot.add_child(cover)
	var cm := Parts.new()
	cm.box(Vector3(HATCH.x + 0.04, HATCH.y + 0.02, 0.012), Vector3.ZERO, green.lightened(0.1))
	cm.box(Vector3(HATCH.x + 0.04, 0.012, 0.014), Vector3(0, -HATCH.y / 2.0 + 0.004, 0.002), green.darkened(0.25))
	cm.ball(0.014, Vector3(-hw + 0.03, 0, 0.012), brass)
	for x in [-0.1, 0.1]:
		cm.ball(0.007, Vector3(x, 0.04, 0.008), rivet)
	cm.commit(cover, 0.3)
	# Punainen lamppu häkissä oven yllä, varsi seinästä.
	var lp := Vector3(0, 2.48, 0.24)
	var lb := Parts.new()
	lb.box(Vector3(0.04, 0.04, 0.24), Vector3(0, lp.y + 0.12, 0.12), steel)
	lb.box(Vector3(0.25, 0.035, 0.25), lp + Vector3(0, 0.12, 0), steel)
	for a in 8:
		var ang := a * TAU / 8.0
		lb.box(Vector3(0.01, 0.22, 0.01), lp + Vector3(cos(ang) * 0.11, 0, sin(ang) * 0.11), steel)
	lb.box(Vector3(0.24, 0.012, 0.012), lp + Vector3(0, -0.11, 0), steel)
	lb.box(Vector3(0.012, 0.012, 0.24), lp + Vector3(0, -0.11, 0), steel)
	lb.commit(door, 0.3)
	var bulb := MeshInstance3D.new()
	bulb.name = "Polttimo"
	bulb.mesh = B.sphere(0.085)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.15, 0.1)
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.12, 0.08)
	bm.emission_energy_multiplier = 4.0
	bulb.material_override = bm
	bulb.position = lp
	door.add_child(bulb)
	var lamp := OmniLight3D.new()
	lamp.name = "Lamppu"
	lamp.light_color = Color(1.0, 0.2, 0.12)
	lamp.light_energy = 1.3
	lamp.omni_range = 4.5
	lamp.position = lp + Vector3(0, -0.1, 0.45)
	door.add_child(lamp)
	return door
