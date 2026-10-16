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
	B.box(root, Vector3(L, H, D), Vector3(0, F + H / 2.0, 0), red)
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
	# Takaovi länsipäädyssä: teräsovi, kurkistusluukku, portaat ja punainen lamppu häkissä.
	var dz := 1.2
	var dx := -L / 2.0 - 0.05
	batch.add(Vector3(0.1, 2.25, 1.2), Vector3(dx, F + 1.12, dz), Color(0.12, 0.12, 0.12))
	batch.add(Vector3(0.08, 2.1, 1.0), Vector3(dx - 0.03, F + 1.05, dz), Color(0.2, 0.28, 0.25))
	batch.add(Vector3(0.06, 0.16, 0.42), Vector3(dx - 0.08, F + 1.62, dz), Color(0.08, 0.08, 0.08))  # luukku
	batch.add(Vector3(0.05, 0.12, 0.36), Vector3(dx - 0.11, F + 1.62, dz), Color(0.3, 0.36, 0.33))
	batch.add(Vector3(0.12, 0.05, 0.22), Vector3(dx - 0.1, F + 1.0, dz - 0.32), Color(0.65, 0.63, 0.58))  # kahva
	batch.add(Vector3(0.08, 0.35, 1.0), Vector3(dx - 0.05, F + 0.18, dz), Color(0.42, 0.42, 0.4))  # potkulevy
	for i in 3:
		var sx := dx - 0.4 - i * 0.35
		B.box(root, Vector3(0.35 + (2 - i) * 0.0, F * (3 - i) / 3.0, 1.6), Vector3(sx, F * (3 - i) / 6.0, dz), stone.lightened(0.05), false)
	B.box(root, Vector3(0.45, 0.06, 1.6), Vector3(dx - 0.25, F + 0.03, dz), stone.lightened(0.08), false)
	var bulb_pos := Vector3(dx - 0.2, F + 2.55, dz)
	var bulb := MeshInstance3D.new()
	bulb.mesh = B.sphere(0.09)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.15, 0.1)
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.12, 0.08)
	bm.emission_energy_multiplier = 4.0
	bulb.material_override = bm
	bulb.position = bulb_pos
	root.add_child(bulb)
	for a in 4:
		var ang := a * PI / 4.0
		batch.add(Vector3(0.01, 0.22, 0.01), bulb_pos + Vector3(cos(ang) * 0.11, 0, sin(ang) * 0.11), Color(0.1, 0.1, 0.1))
		batch.add(Vector3(0.01, 0.22, 0.01), bulb_pos - Vector3(cos(ang) * 0.11, 0, sin(ang) * 0.11), Color(0.1, 0.1, 0.1))
	batch.add(Vector3(0.25, 0.04, 0.25), bulb_pos + Vector3(0.02, 0.12, 0), Color(0.1, 0.1, 0.1))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.2, 0.12)
	lamp.light_energy = 2.0
	lamp.omni_range = 4.5
	lamp.position = bulb_pos + Vector3(-0.2, -0.1, 0)
	root.add_child(lamp)
	var note := B.sign_plate(root, "EI MYYJIÄ", Color(0.88, 0.85, 0.72), Color(0.2, 0.1, 0.1), 0.14, 24, Color(0.6, 0.55, 0.45))
	note.position = Vector3(dx - 0.06, F + 1.55, dz + 0.85)
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
