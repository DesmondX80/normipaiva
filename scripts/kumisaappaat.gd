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
const SOLE := Color(0.93, 0.9, 0.82)  # vaalea pohja kuten shoes.gd sole_col
const TREAD := Color(0.36, 0.3, 0.24)  # kulunut pohjan kulutuspinta
const HEIGHT := 0.375  # varren yläreuna lattiasta
const SOLE_H := 0.026  # pohjan paksuus (kulutuspinta 0,007 + vaalea 0,019)


## Pari vierekkäin lattialla: at = parin keskikohta (y = lattian yläpinta), face = kärkien suunta (XZ). Palauttaa parin
## juurisolmun (näkyvyys: Looks.boots).
static func build(parent: Node3D, at: Vector3, face: Vector3) -> Node3D:
	var pair := Node3D.new()
	pair.position = at
	pair.rotation.y = B.yaw_to(face)  # -Z = kärjet
	parent.add_child(pair)
	var rubber := StandardMaterial3D.new()  # kumin kiilto
	rubber.albedo_color = COLOR
	rubber.roughness = 0.38
	for side in [-1.0, 1.0]:
		var boot := Node3D.new()
		boot.position = Vector3(side * 0.085, 0, 0)
		boot.rotation.y = side * deg_to_rad(-4.0)  # kärjet hieman erilleen kuten lattialle jätetyt
		pair.add_child(boot)
		_boot(boot, side, rubber)
	return pair


## Yksi saapas (side = ulkosivun suunta x:ssä, -Z = kärki).
static func _boot(b: Node3D, side: float, rubber: StandardMaterial3D) -> void:
	# Pohja: tumma kulutuspinta ja vaalea välipohja, kumpikin laatta + pyöreä kärki + pyöreä kanta.
	_slab(b, 0.0, 0.007, 0.0, TREAD)
	_slab(b, 0.007, SOLE_H - 0.007, 0.0, SOLE)
	# Tummempi kantaraita (rand) pohjan päällä kiertää jalkaosan alareunan.
	_slab(b, SOLE_H, 0.016, 0.003, COLOR.darkened(0.35))
	# Jalkaosa: matala litistetty kärki ja sen takana pullea rinta, joka nousee varteen.
	var toe := B.mesh(b, B.capsule(0.047, 0.2), Vector3(0, SOLE_H + 0.034, -0.05), COLOR, Vector3(90, 0, 0))
	toe.scale = Vector3(1.0, 1.0, 0.78)  # kapselin paikallinen z = maailman pysty (kierto 90° x:n ympäri)
	toe.material_override = rubber
	var instep := B.mesh(b, B.sphere(0.056), Vector3(0, SOLE_H + 0.05, 0.035), COLOR)
	instep.scale = Vector3(0.92, 1.0, 1.4)
	instep.material_override = rubber
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
