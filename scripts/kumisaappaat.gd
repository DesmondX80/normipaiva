extends RefCounted
## Kumisaappaat esineenä (#274): kodin eteisessä (home_interior.gd) ja mökin ovensuussa (mokki_interior.gd) seisova
## vihreä pari. E vaihtaa ne pelaajan jalkaan ja takaisin (main.gd _toggle_boots, Looks.boots); jalassa olevat
## piilotetaan paikaltaan. Mitat pelin saappaasta (kengat.tscn kumisaapas_m: korkeus 0,375 m, pituus 0,33 m) ja esikuvasta
## (Hunter Original, EU 43: varsi noin 40 cm). Umpinaiset palat: vaalea kaksikerroksinen pohja pyöreine kärkineen ja
## kantoineen, matala kärki ja pullea rinta, tummempi kantaraita, kartiomainen varsi, vaalea suun reunus, tumma suu, sivusolki
## ja kantalappu.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const COLOR := Color(0.13, 0.3, 0.14)  # sama vihreä kuin Santun saappaissa (mokki.gd SANTTU_LOOK) ja Looks.player
const RUBBER := Color(0.17, 0.42, 0.19)  # esineen kumi: kirkkaampi, koska kengän varjostin (shoe.gdshader) näyttää saman vihreän
                                         # jalassa vaaleampana kuin StandardMaterial lattialla; erottuu pelikameralta
const MAT := Vector2(0.5, 0.75)  # kuramatto oletuksena (kärkien suunta, sivusuunta): vaalea kumialusta, jolla pari erottuu lattiasta
const MAT_H := 0.01  # maton pohjan paksuus (saappaat sen päällä)
const SOLE := Color(0.93, 0.9, 0.82)  # vaalea pohja kuten shoes.gd sole_col
const TREAD := Color(0.36, 0.3, 0.24)  # kulunut pohjan kulutuspinta
const HEIGHT := 0.375  # varren yläreuna lattiasta
const SOLE_H := 0.026  # pohjan paksuus (kulutuspinta 0,007 + vaalea 0,019)
const VAMP_HEEL := 0.12  # jalkaosan kantapää (varren sisällä)
const VAMP_TIP := -0.137  # jalkaosan kärki (pohjan kärki -0,142, reunus jää näkyviin)
const VAMP_W := 0.049  # jalkaosan puolileveys (pohja 0,052)
const VAMP_INSTEP_H := 0.13  # rinnan korkeus pohjan yläpinnasta varren kohdalla
const VAMP_TOE_H := 0.05  # kärkiosan korkeus pohjan yläpinnasta
const VAMP_SLICES := 24
const VAMP_RING := 16


## Pari vierekkäin kuramaton päällä: at = parin ja maton keskikohta (y = lattian yläpinta), face = kärkien suunta (XZ),
## mat = maton koko (kärkien suunta, sivusuunta; vähintään 0,4 x 0,4). Palauttaa parin juurisolmun (näkyvyys: Looks.boots,
## meta "matto" = maton koko); matto jää lattialle, kun pari on jalassa.
static func build(parent: Node3D, at: Vector3, face: Vector3, mat := MAT) -> Node3D:
	_mat(parent, at, B.yaw_to(face), mat)
	var pair := Node3D.new()
	pair.set_meta("matto", mat)
	pair.position = at + Vector3(0, MAT_H, 0)
	pair.rotation.y = B.yaw_to(face)  # -Z = kärjet
	parent.add_child(pair)
	var rubber := StandardMaterial3D.new()  # kumin kiilto
	rubber.albedo_color = RUBBER
	rubber.roughness = 0.38
	for side in [-1.0, 1.0]:
		var boot := Node3D.new()
		boot.position = Vector3(side * 0.085, 0, 0)
		boot.rotation.y = side * deg_to_rad(-4.0)  # kärjet hieman erilleen kuten lattialle jätetyt
		pair.add_child(boot)
		_boot(boot, side, rubber)
	return pair


## Kuramatto: vaalea kumipohja, korotettu reunus ja poikittaiset urat (kuten eteisen saapastarjotin). -Z = kärkien suunta.
static func _mat(parent: Node3D, at: Vector3, yaw: float, size: Vector2) -> void:
	var m := Node3D.new()
	m.position = at
	m.rotation.y = yaw
	parent.add_child(m)
	var col := Color(0.8, 0.79, 0.75)
	B.mesh(m, B.boxm(Vector3(size.y, MAT_H, size.x)), Vector3(0, MAT_H / 2.0, 0), col)
	for sx in [-1.0, 1.0]:  # reunus: pitkät sivut ja päädyt, vaalea yläreuna ja tumma ulkokylki
		B.mesh(m, B.boxm(Vector3(0.025, 0.022, size.x)), Vector3(sx * (size.y / 2.0 - 0.0125), 0.011, 0), col.lightened(0.15))
		B.mesh(m, B.boxm(Vector3(size.y, 0.022, 0.025)), Vector3(0, 0.011, sx * (size.x / 2.0 - 0.0125)), col.lightened(0.15))
		B.mesh(m, B.boxm(Vector3(0.002, 0.02, size.x)), Vector3(sx * (size.y / 2.0 + 0.001), 0.01, 0), col.darkened(0.35))
		B.mesh(m, B.boxm(Vector3(size.y, 0.02, 0.002)), Vector3(0, 0.01, sx * (size.x / 2.0 + 0.001)), col.darkened(0.35))
	for k in 7:  # urat sivusuuntaan
		var z := -size.x / 2.0 + 0.07 + k * (size.x - 0.14) / 6.0
		B.mesh(m, B.boxm(Vector3(size.y - 0.07, 0.002, 0.012)), Vector3(0, MAT_H + 0.001, z), col.darkened(0.2))


## Yksi saapas (side = ulkosivun suunta x:ssä, -Z = kärki).
static func _boot(b: Node3D, side: float, rubber: StandardMaterial3D) -> void:
	# Pohja: tumma kulutuspinta ja vaalea välipohja, kumpikin laatta + pyöreä kärki + pyöreä kanta.
	_slab(b, 0.0, 0.007, 0.0, TREAD)
	_slab(b, 0.007, SOLE_H - 0.007, 0.0, SOLE)
	# Tummempi kantaraita (rand) pohjan päällä kiertää jalkaosan alareunan.
	_slab(b, SOLE_H, 0.016, 0.003, COLOR.darkened(0.35))
	# Jalkaosa: yksi umpinainen loftattu kappale kannasta kärkeen (kuten pelin kumisaappaan kuori, shoes.gd): korkea rinta
	# varren sisällä laskee tasaisesti pitkäksi matalaksi kärjeksi, joka pyöristyy pohjan reunaan.
	var vamp := MeshInstance3D.new()
	vamp.mesh = _vamp_mesh()
	vamp.material_override = rubber
	b.add_child(vamp)
	# Varsi: kartio kannan päältä yläreunaan, leveämpi ylhäältä (pohje).
	var shaft_h := HEIGHT - 0.018 - SOLE_H - 0.01
	var shaft_y0 := SOLE_H + 0.01
	var shaft := B.mesh(b, B.cyl(0.064, 0.053, shaft_h, 16), Vector3(0, shaft_y0 + shaft_h / 2.0, 0.088), COLOR)
	shaft.material_override = rubber
	# Suun reunus vaalea kuten jalassa olevassa saappaassa (shoes.gd: vaalea reunus varren suussa) ja tumma suu.
	var rim_y := HEIGHT - 0.009
	B.mesh(b, B.cyl(0.067, 0.066, 0.018, 16), Vector3(0, rim_y, 0.088), SOLE.darkened(0.08))
	B.mesh(b, B.cyl(0.057, 0.057, 0.003, 16), Vector3(0, HEIGHT + 0.0005, 0.088), Color(0.04, 0.05, 0.04))
	# Sivusolki ulkosivulla yläreunan alla: hihna ja metallisolki.
	var sx := side * 0.066
	B.mesh(b, B.boxm(Vector3(0.006, 0.02, 0.06)), Vector3(sx, HEIGHT - 0.045, 0.088), COLOR.darkened(0.2))
	B.mesh(b, B.boxm(Vector3(0.008, 0.026, 0.014)), Vector3(sx + side * 0.002, HEIGHT - 0.045, 0.07), Color(0.72, 0.72, 0.68))
	# Kantalappu takana yläreunassa.
	B.mesh(b, B.boxm(Vector3(0.03, 0.045, 0.008)), Vector3(0, HEIGHT - 0.01, 0.088 + 0.066), COLOR.darkened(0.3))


## Jalkaosan verkko (-Z = kärki): superellipsin yläkaari ja suora pohja poikkileikkauksina kannasta (z VAMP_HEEL, varren
## sisällä) kärkeen (z VAMP_TIP). Korkeus laskee rinnasta kärkiosaan, ja kärki pyöristyy sivulta ja ylhäältä katsottuna
## neljännesellipsinä yhteen pisteeseen pohjan tasolle; kannan pää suljetaan viuhkalla.
static func _vamp_mesh() -> ArrayMesh:
	var rings: Array[PackedVector3Array] = []
	for i in VAMP_SLICES + 1:
		var u := float(i) / VAMP_SLICES
		var z := lerpf(VAMP_HEEL, VAMP_TIP, u)
		var h := VAMP_TOE_H + (VAMP_INSTEP_H - VAMP_TOE_H) * smoothstep(0.72, 0.22, u)
		var w := VAMP_W
		if u > 0.7:  # kärjen pyöristys
			var k := sqrt(maxf(0.0, 1.0 - pow((u - 0.7) / 0.3, 2.0)))
			h *= lerpf(0.35, 1.0, k)  # nenä laskee pohjan reunaan, mutta ei aivan nollaan ennen kärkipistettä
			w *= k
		var ring := PackedVector3Array()
		for j in VAMP_RING + 1:
			var a := PI * float(j) / VAMP_RING  # 0 = ulkosivu +x, PI = -x
			var c := cos(a)
			var sn := sin(a)
			ring.append(Vector3(w * signf(c) * pow(absf(c), 2.0 / 3.0), SOLE_H + h * pow(sn, 2.0 / 3.0), z))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := VAMP_RING + 1
	for i in VAMP_SLICES:
		var r0 := rings[i]
		var r1 := rings[i + 1]
		for j in n:  # j = n - 1 -> 0 on pohjan suora reuna
			var j1 := (j + 1) % n
			# r1 on kärjen puolella (-Z): ulospäin osoittava normaali vastapäivään ulkoa katsottuna
			st.add_vertex(r0[j])
			st.add_vertex(r0[j1])
			st.add_vertex(r1[j1])
			st.add_vertex(r0[j])
			st.add_vertex(r1[j1])
			st.add_vertex(r1[j])
	var heel := rings[0]
	var hc := Vector3(0, SOLE_H + VAMP_INSTEP_H * 0.4, VAMP_HEEL)
	for j in n:
		st.add_vertex(hc)
		st.add_vertex(heel[(j + 1) % n])
		st.add_vertex(heel[j])
	st.generate_normals()
	return st.commit()


## Pohjan kerros: laatta ja pyöreät päät (kärki -Z, kanta +Z), alareuna y0, paksuus h, sisennys inset.
static func _slab(b: Node3D, y0: float, h: float, inset: float, col: Color) -> void:
	var y := y0 + h / 2.0
	B.mesh(b, B.boxm(Vector3(0.104 - inset * 2.0, h, 0.2)), Vector3(0, y, 0.01), col)
	B.mesh(b, B.cyl(0.052 - inset, 0.052 - inset, h, 16), Vector3(0, y, -0.09), col)  # kärki
	B.mesh(b, B.cyl(0.048 - inset, 0.048 - inset, h, 16), Vector3(0, y, 0.11), col)  # kanta


## Vihje saappaiden luona (place = "koti" tai "mokki"): laita jalkaan, ota pois tai kerro, miksi ei.
static func hint(place: String) -> String:
	if Looks.outfit == "hiihtohaalari":
		return "Kumisaappaat. Hiihtohaalarissa pidetään kuukengät."
	if Looks.boots == place:
		return "[E] Kumisaappaat pois, omat kengät jalkaan"
	if Looks.boots != "":
		return "Kumisaappaat on jo jalassa (%s)." % ("kodin" if Looks.boots == "koti" else "mökin")
	return "[E] Vedä kumisaappaat jalkaan"
