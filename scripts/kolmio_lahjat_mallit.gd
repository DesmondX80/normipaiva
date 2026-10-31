extends RefCounted
## Kolmiomittauksen lahjojen 3D-mallit (#255, kolmio_kohtaus.gd _gift_prop): litran mansikkarasia, kermavaahtospray
## ja ruusukimppu. Esikuvat: torin litran pahvirasia (aaltopahvi, kaltevat seinät, marjat kekona yli reunan, jokainen
## marja oma umpinainen kappale verholehtineen, koska ne syödään), suomalainen kermavaahtospray (valkoinen
## alumiinipurkki, sininen etiketti, valkoinen kaareva suutin; parodianimi, ei merkkiä) ja punaiset ruusut
## voimapaperikääreessä nauhan kera.
## Kehykset: rasia ja purkki pohja origossa +Y ylös, kimppu varsien otekohta (kääreen kapein kohta) origossa, kukat
## +Y:ssä. Purkin suutin osoittaa -Z:aan (kantajan kasvojen suuntaan). Kantaminen: kolmio_kohtaus.gd _hold.

const B := preload("res://scripts/build.gd")

## Rasia: yläreunan ja pohjan puolikoot (x, z) ja korkeus.
const RASIA_YLA := Vector2(0.08, 0.055)
const RASIA_ALA := Vector2(0.065, 0.043)
const RASIA_H := 0.075
const RASIA_TAYTTO := RASIA_H  # umpinaisen rasian yläpinta reunan tasolla (marjat kekona sen päällä)
const PURKKI_R := 0.027
const PURKKI_H := 0.15


## Lahjan malli lajin mukaan ("mansikat", "kermavaahto", "ruusut").
static func tee(laji: String) -> Node3D:
	match laji:
		"mansikat":
			return mansikat()
		"kermavaahto":
			return kermavaahto()
		"ruusut":
			return ruusut()
	return Node3D.new()


## Rasian puolileveys (x) korkeudella y pohjasta: seinät kallistuvat pohjasta yläreunaan.
static func rasia_half(y: float) -> float:
	return lerpf(RASIA_ALA.x, RASIA_YLA.x, clampf(y / RASIA_H, 0.0, 1.0))


# --- Mansikat -------------------------------------------------------------------------------------------------

## Marjan mitat: verhiön leveys (säde) ja pituus verhiöstä kärkeen.
const MARJA_R := 0.0145
const MARJA_L := 0.034


static func mansikat() -> Node3D:
	var root := Node3D.new()
	root.name = "Mansikat"
	var pahvi := Color(0.72, 0.56, 0.36)
	var box := MeshInstance3D.new()
	box.mesh = _rasia_mesh(pahvi, Color(0.16, 0.05, 0.04))
	var bm := B.vcol_srgb_mat().duplicate() as StandardMaterial3D
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	box.material_override = bm
	root.add_child(box)
	# Reunan taite (vaaleampi yläreuna).
	for s in [-1.0, 1.0]:
		B.mesh(root, B.boxm(Vector3(RASIA_YLA.x * 2.0 + 0.006, 0.006, 0.006)), Vector3(0, RASIA_H, s * (RASIA_YLA.y + 0.002)), pahvi.lightened(0.25))
		B.mesh(root, B.boxm(Vector3(0.006, 0.006, RASIA_YLA.y * 2.0 + 0.006)), Vector3(s * (RASIA_YLA.x + 0.002), RASIA_H, 0), pahvi.lightened(0.25))
	# Marjat: alakerros rasian reunan tasolla, yläkerros keoksi reunan yli. Satunnaiset asennot (kärki eri suuntiin,
	# verhiö useimmiten ylös tai sivulle).
	var rng := RandomNumberGenerator.new()
	rng.seed = 255
	# Alakerros täyttöpinnan päällä (RASIA_TAYTTO), yläkerros keoksi reunan yli.
	var paikat: Array = []
	for j in 3:
		for i in 5:
			paikat.append(Vector3(-0.054 + i * 0.027 + rng.randf_range(-0.002, 0.002), RASIA_TAYTTO + 0.006,
				-0.03 + j * 0.03 + rng.randf_range(-0.002, 0.002)))
	for p in [Vector3(-0.035, 0.1, -0.016), Vector3(0.0, 0.102, 0.014), Vector3(0.036, 0.1, -0.012),
			Vector3(-0.02, 0.101, 0.026), Vector3(0.024, 0.101, 0.03), Vector3(0.008, 0.112, -0.006), Vector3(-0.05, 0.097, 0.01),
			Vector3(0.052, 0.097, 0.015)]:
		paikat.append(p)
	var seeds: Array[Transform3D] = []
	for pi in paikat.size():
		var p: Vector3 = paikat[pi]
		var sc := rng.randf_range(0.9, 1.12)
		# Alakerros pystymmässä (kärki ei puhkaise seinää), yläkerros miten sattuu.
		var lean := 0.45 if pi < 15 else 1.0
		var up := Vector3(rng.randf_range(-lean, lean), rng.randf_range(0.3, 1.2), rng.randf_range(-lean, lean)).normalized()
		var xf := Transform3D(_from_y(up).scaled(Vector3.ONE * sc), p)
		root.add_child(_marja(rng, xf, seeds))
	# Siemenet yhtenä MultiMeshinä (pienet kellertävät pisarat pinnalla).
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = B.sphere(0.0008, 6)
	mm.instance_count = seeds.size()
	for i in seeds.size():
		mm.set_instance_transform(i, seeds[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Siemenet"
	mmi.multimesh = mm
	mmi.material_override = B.mat(Color(0.88, 0.72, 0.3))
	mmi.set_meta("pehmea", true)  # millimetrin pisarat marjan pinnalla, eivät kiinteitä kappaleita
	root.add_child(mmi)
	return root


## Yksi mansikka (umpinainen kappale, syödään): kierretty profiili, leveä hartia verhiön alla ja kapeneva kärki,
## yläosa vaaleampi ja kärki tummempi. Verhiö (viisi lehteä) ja varsi päällä. Siementen paikat lisätään listaan
## (rasian kehyksessä). xf = marjan paikka rasiassa; marjan +Y verhiöön, kärki -Y.
static func _marja(rng: RandomNumberGenerator, xf: Transform3D, seeds: Array[Transform3D]) -> Node3D:
	var n := Node3D.new()
	n.name = "Marja"
	n.transform = xf
	var red := Color(0.8, 0.07, 0.08).lightened(rng.randf_range(-0.06, 0.06))
	var seg := 14
	var rings := 10
	var prof := func(t: float) -> Vector2:  # t 0 = verhiö, 1 = kärki -> (säde, y)
		var shoulder := sin(PI / 2.0 * minf(1.0, (t + 0.12) / 0.32))
		return Vector2(MARJA_R * shoulder * pow(1.0 - t, 0.85) * (1.0 + 0.12 * t), 0.008 - t * MARJA_L)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := func(r: int, k: int) -> Vector3:
		var pr: Vector2 = prof.call(float(r) / rings)
		var a := TAU * k / seg
		return Vector3(cos(a) * pr.x, pr.y, sin(a) * pr.x)
	var col := func(v: Vector3) -> Color:
		var tt := clampf((0.008 - v.y) / MARJA_L, 0.0, 1.0)
		return red.lightened(0.15 * (1.0 - tt) * (1.0 - tt)).darkened(0.22 * tt * tt)
	var top: Vector2 = prof.call(0.0)
	for k in seg:  # kansi verhiön alla (umpinainen); kiertosuunta ulospäin (Godot: myötäpäivään edestä)
		for v in [Vector3(0, top.y, 0), ring.call(0, k), ring.call(0, k + 1)]:
			st.set_color(col.call(v))
			st.add_vertex(v)
	for r in rings:
		for k in seg:
			for v in [ring.call(r, k), ring.call(r + 1, k), ring.call(r, k + 1), ring.call(r, k + 1), ring.call(r + 1, k), ring.call(r + 1, k + 1)]:
				st.set_color(col.call(v))
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = B.vcol_srgb_mat()
	n.add_child(mi)
	# Siemenet: lomittain renkaissa, pinnalla hieman upotettuina.
	for r in range(1, rings - 1, 2):
		for k in 6:
			var t := (r + 0.5) / rings
			var pr: Vector2 = prof.call(t)
			var a := TAU * (k + 0.5 * ((r / 2) % 2)) / 6.0 + rng.randf_range(-0.15, 0.15)
			seeds.append(xf * Transform3D(Basis(), Vector3(cos(a) * pr.x * 0.99, pr.y, sin(a) * pr.x * 0.99)))
	var green := Color(0.24, 0.52, 0.16)
	for k in 5:
		var a := TAU * k / 5.0 + rng.randf() * 0.3
		var leaf := B.mesh(n, B.sphere(0.5, 6), Vector3(cos(a) * 0.0075, top.y + 0.0015, sin(a) * 0.0075), green.lightened(0.1 * (k % 2)))
		leaf.basis = Basis(Vector3.UP, -a) * Basis(Vector3.BACK, -0.3) * Basis.from_scale(Vector3(0.0095, 0.0018, 0.004))
	B.mesh(n, B.cyl(0.0012, 0.0016, 0.008, 5), Vector3(0, top.y + 0.005, 0), green.darkened(0.2))
	return n


## Rasia umpinaisena kappaleena: kaltevat seinät, pohja ja yläpinta reunan tasolla (marjojen alla tumma, jottei
## ontto rasia sekoita läpimenotarkistusta). Pistevärit: pahvi, alareuna tummempi, yläpinta tumma.
static func _rasia_mesh(pahvi: Color, sisus: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lo := [Vector3(-RASIA_ALA.x, 0, -RASIA_ALA.y), Vector3(RASIA_ALA.x, 0, -RASIA_ALA.y),
		Vector3(RASIA_ALA.x, 0, RASIA_ALA.y), Vector3(-RASIA_ALA.x, 0, RASIA_ALA.y)]
	var hi := [Vector3(-RASIA_YLA.x, RASIA_H, -RASIA_YLA.y), Vector3(RASIA_YLA.x, RASIA_H, -RASIA_YLA.y),
		Vector3(RASIA_YLA.x, RASIA_H, RASIA_YLA.y), Vector3(-RASIA_YLA.x, RASIA_H, RASIA_YLA.y)]
	for i in 4:
		var j := (i + 1) % 4
		for v in [lo[i], hi[i], hi[j], lo[i], hi[j], lo[j]]:
			st.set_color(pahvi.darkened(0.25) if v.y == 0.0 else pahvi.lightened(0.08))
			st.add_vertex(v)
	# Kiertosuunta kuten seinissä ((v1 - v0) x (v2 - v0) ulospäin): pohja alas, täyttöpinta ylös.
	for v in [lo[0], lo[1], lo[2], lo[0], lo[2], lo[3]]:
		st.set_color(pahvi.darkened(0.35))
		st.add_vertex(v)
	var k := RASIA_TAYTTO / RASIA_H
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_color(sisus)
		st.add_vertex((lo[i] as Vector3).lerp(hi[i], k))
	st.generate_normals()
	return st.commit()


static func _from_y(y: Vector3) -> Basis:
	var yy := y.normalized()
	var x := yy.cross(Vector3.FORWARD if absf(yy.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, yy, x.cross(yy))


# --- Kermavaahto ------------------------------------------------------------------------------------------------

static func kermavaahto() -> Node3D:
	var root := Node3D.new()
	root.name = "Kermavaahto"
	var alu := B.mat(Color(0.97, 0.97, 0.96)).duplicate() as StandardMaterial3D  # valkoiseksi maalattu alumiini
	alu.metallic = 0.15
	alu.roughness = 0.3
	var can := B.mesh(root, B.cyl(PURKKI_R, PURKKI_R, PURKKI_H, 24), Vector3(0, PURKKI_H / 2.0, 0), Color.WHITE)
	can.material_override = alu
	# Pohjan tumma reuna ja olkapää (kupera yläosa).
	B.mesh(root, B.cyl(PURKKI_R - 0.002, PURKKI_R - 0.001, 0.006, 24), Vector3(0, 0.003, 0), Color(0.55, 0.57, 0.6))
	var dome := B.mesh(root, B.sphere(PURKKI_R, 20), Vector3(0, PURKKI_H, 0), Color.WHITE)
	dome.scale = Vector3(1.0, 0.45, 1.0)
	dome.material_override = alu
	B.mesh(root, B.cyl(0.0125, 0.0125, 0.008, 16), Vector3(0, PURKKI_H + 0.013, 0), Color(0.75, 0.77, 0.8))  # venttiilikuppi
	# Etiketti: tummansininen leveä vyö, vaaleansininen ohut raita ja kermapursotus (kolme pyörylää) edessä (-Z).
	var navy := Color(0.1, 0.22, 0.55)
	B.mesh(root, B.cyl(PURKKI_R + 0.0008, PURKKI_R + 0.0008, 0.07, 24), Vector3(0, 0.07, 0), navy)
	B.mesh(root, B.cyl(PURKKI_R + 0.001, PURKKI_R + 0.001, 0.008, 24), Vector3(0, 0.109, 0), Color(0.45, 0.7, 0.95))
	B.mesh(root, B.cyl(PURKKI_R + 0.001, PURKKI_R + 0.001, 0.004, 24), Vector3(0, 0.033, 0), Color(0.85, 0.12, 0.15))
	var cream := Color(0.99, 0.97, 0.9)
	for q in [[Vector3(0, 0.058, 0), 0.011], [Vector3(0, 0.071, 0), 0.0085], [Vector3(0, 0.081, 0), 0.006]]:
		var bl := B.mesh(root, B.sphere(q[1], 10), (q[0] as Vector3) + Vector3(0, 0, -PURKKI_R - 0.001), cream)
		bl.scale = Vector3(1.0, 0.7, 0.35)
	B.mesh(root, B.sphere(0.006, 8), Vector3(0.012, 0.052, -PURKKI_R - 0.0015), Color(0.8, 0.08, 0.1)).scale = Vector3(1, 1.2, 0.4)  # mansikka
	# Metallin kiilto: kapea vaalea pystyjuova vasemmalla edessä (olkapäästä pohjaan).
	var glint := B.mesh(root, B.boxm(Vector3(0.004, PURKKI_H - 0.02, 0.001)), Vector3(0, PURKKI_H / 2.0, 0), Color(1, 1, 1))
	glint.position = Vector3(-sin(0.6) * (PURKKI_R + 0.0012), PURKKI_H / 2.0 + 0.005, -cos(0.6) * (PURKKI_R + 0.0012))
	glint.rotation.y = 0.6
	var gm := B.mat(Color(1, 1, 1)).duplicate() as StandardMaterial3D
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1, 1, 1, 0.55)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glint.material_override = gm
	glint.set_meta("pehmea", true)  # heijastus, ei kappale
	# Valkoinen muovisuutin: jalka venttiilistä ylös ja kaareva nokka eteen.
	var white := Color(0.97, 0.97, 0.96)
	B.mesh(root, B.cyl(0.009, 0.011, 0.02, 12), Vector3(0, PURKKI_H + 0.026, 0), white)
	var prev := Vector3(0, PURKKI_H + 0.036, 0)
	for k in range(1, 6):
		var a := k / 5.0 * 1.0
		var p := Vector3(0, PURKKI_H + 0.036 + sin(a) * 0.022, -(1.0 - cos(a)) * 0.022 - k * 0.002)
		B.tube(root, prev, p, 0.0055 - k * 0.0004, white)
		prev = p
	for k in 6:
		var a := TAU * k / 6.0
		B.mesh(root, B.boxm(Vector3(0.002, 0.004, 0.002)), prev + Vector3(cos(a) * 0.004, 0.002, sin(a) * 0.004), white.darkened(0.2))
	return root


# --- Ruusut ----------------------------------------------------------------------------------------------------

## Kääre: kartio otekohdan alta (y = KAARE_Y0, säde KAARE_R0) kukkien alle (KAARE_Y1, KAARE_R1). Ote kääreen kapeasta
## kohdasta (origo).
const KAARE_Y0 := -0.08
const KAARE_Y1 := 0.2
const KAARE_R0 := 0.02
const KAARE_R1 := 0.1


## Kääreen säde korkeudella y (varret kääreen alla 0.012), -1 = ei kimppua tällä korkeudella.
static func kaare_r(y: float) -> float:
	if y >= KAARE_Y0 and y <= KAARE_Y1:
		return lerpf(KAARE_R0, KAARE_R1, (y - KAARE_Y0) / (KAARE_Y1 - KAARE_Y0))
	if y < KAARE_Y0 and y > KAARE_Y0 - 0.07:
		return 0.012
	return -1.0


static func ruusut() -> Node3D:
	var root := Node3D.new()
	root.name = "Ruusut"
	var green := Color(0.2, 0.42, 0.15)
	var heads := [Vector3(0, 0.31, 0), Vector3(0.045, 0.29, 0.03), Vector3(-0.045, 0.29, 0.025), Vector3(0.03, 0.285, -0.045),
		Vector3(-0.035, 0.28, -0.04), Vector3(0.0, 0.27, 0.06), Vector3(0.062, 0.265, -0.01)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for h in heads:
		var hp: Vector3 = h
		B.tube(root, Vector3(hp.x * 0.3, KAARE_Y1 - 0.06, hp.z * 0.3), hp - Vector3(0, 0.01, 0), 0.0035, green)
		var head := _ruusu(rng)
		head.position = hp
		head.basis = _from_y(Vector3(hp.x * 2.5, 1.0, hp.z * 2.5))
		root.add_child(head)
	# Lehdet kukkien alla kääreen reunalla.
	for k in 6:
		var a := TAU * k / 6.0 + 0.4
		var leaf := B.mesh(root, B.sphere(0.5, 8), Vector3(cos(a) * 0.075, KAARE_Y1 + 0.01, sin(a) * 0.075), green.lightened(0.1 * (k % 2)))
		leaf.basis = Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.45) * Basis.from_scale(Vector3(0.05, 0.004, 0.024))
	# Voimapaperikääre: kartio (umpinainen, ote kapeasta kohdasta), vaalea taitettu yläreuna; punainen nauha ja rusetti.
	var kraft := Color(0.78, 0.62, 0.42)
	var cm := CylinderMesh.new()
	cm.top_radius = KAARE_R1
	cm.bottom_radius = KAARE_R0
	cm.height = KAARE_Y1 - KAARE_Y0
	cm.radial_segments = 12
	var cone := B.mesh(root, cm, Vector3(0, (KAARE_Y0 + KAARE_Y1) / 2.0, 0), kraft)
	cone.name = "Kaare"
	B.mesh(root, B.cyl(KAARE_R1 + 0.0015, KAARE_R1 - 0.004, 0.014, 12), Vector3(0, KAARE_Y1 - 0.006, 0), kraft.lightened(0.25))
	# Kääreen suu: tumma vihreä lehvistö kartion kannen päällä (ei vaaleaa kantta näkyviin).
	B.mesh(root, B.cyl(KAARE_R1 - 0.004, KAARE_R1 - 0.006, 0.006, 12), Vector3(0, KAARE_Y1 + 0.002, 0), Color(0.1, 0.24, 0.08))
	for k in 6:  # pystytaitokset
		var a := TAU * k / 6.0 + 0.2
		B.tube(root, Vector3(cos(a) * KAARE_R0, KAARE_Y0 + 0.01, sin(a) * KAARE_R0) * 1.03,
			Vector3(cos(a) * KAARE_R1, KAARE_Y1 - 0.01, sin(a) * KAARE_R1) * 1.0, 0.0022, kraft.darkened(0.18))
	var ribbon := Color(0.85, 0.08, 0.15)
	# Nauha kääreen pinnalle (säde kääreestä korkeuden mukaan, 1,5 mm päällä) ja rusetti sen eteen (-Z).
	var ry := KAARE_Y0 + 0.045
	B.mesh(root, B.cyl(kaare_r(ry + 0.006) + 0.0015, kaare_r(ry - 0.006) + 0.0015, 0.012, 12), Vector3(0, ry, 0), ribbon)
	for sx in [-1.0, 1.0]:
		var bow := B.mesh(root, B.sphere(0.5, 8), Vector3(sx * 0.018, ry + 0.005, -kaare_r(ry) - 0.004), ribbon.lightened(0.1))
		bow.basis = Basis(Vector3.BACK, sx * 0.4) * Basis.from_scale(Vector3(0.026, 0.014, 0.008))
	# Varsien päät kääreen alta.
	for k in 5:
		var a := TAU * k / 5.0
		B.tube(root, Vector3(cos(a) * 0.006, KAARE_Y0 + 0.005, sin(a) * 0.006), Vector3(cos(a) * 0.007, KAARE_Y0 - 0.06, sin(a) * 0.007),
			0.0032, green.darkened(0.15))
	return root


## Ruusun kukka: tiivis nuppu keskellä ja terälehtien kehä kupiksi (kaksi kerrosta), alta tummempi. Origo kukan
## pohjalla, +Y ylös.
static func _ruusu(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var red := Color(0.72, 0.03, 0.1).lightened(rng.randf_range(-0.04, 0.06))
	var bud := B.mesh(n, B.sphere(0.012, 10), Vector3(0, 0.022, 0), red.darkened(0.15))
	bud.scale = Vector3(1.0, 1.35, 1.0)
	B.mesh(n, B.cyl(0.006, 0.009, 0.01, 8), Vector3(0, 0.003, 0), Color(0.22, 0.42, 0.16))  # verhiö
	for layer in 2:
		var cnt := 5 + layer
		for k in cnt:
			var a := TAU * k / cnt + layer * 0.5
			var r := 0.009 + layer * 0.006
			var p := B.mesh(n, B.sphere(0.5, 10), Vector3(cos(a) * r, 0.018 + layer * 0.002, sin(a) * r), red.lightened(0.06 * layer))
			p.scale = Vector3(0.022 + layer * 0.006, 0.026, 0.006)
			# Terälehti pystyssä kukan ympärillä, yläreuna ulospäin kallellaan.
			p.basis = Basis(Vector3.UP, -a + PI / 2.0) * Basis(Vector3.RIGHT, -(0.25 + layer * 0.3)) * p.basis
	return n


