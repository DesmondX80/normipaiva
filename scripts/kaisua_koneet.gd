extends RefCounted
## Kaisuan tilan koneet ja rakennukset (kaisua.gd): vanha ohjaamoton traktori etukuormaimineen ja paalipiikkeineen,
## työkoneet (sivuniittokone, kaksiroottorinen karhotin, pyöröpaalain, S-piikkiäes, kylvökone, viljakärry), vanha
## leikkuupuimuri, muoviin kääritty pyöröpaali ja pihan rakennukset (lato, konevaja, viljankuivuri, kyltti).
##
## Kaikki koneet katsovat -Z:aan. Traktorin origo on maassa taka-akselin alla; työkoneen origo on kytkentäpiste
## (kolmipistenostimen alavarret tai vetoaisan silmä), ja kone jatkuu +Z:aan. Liikkuvat osat ovat omia solmujaan
## (pyörät, kuormaimen puomi, roottorit, luukut, kela, purkuputki, kippilava), muut osat yhdistetään yhdeksi meshiksi
## materiaaleittain (vehicles.gd _merge_parts).

const B := preload("res://scripts/build.gd")
const V := preload("res://scripts/vehicles.gd")

const RED := Color(0.72, 0.14, 0.06)  # traktori ja työkoneet
const COMBINE_RED := Color(0.78, 0.2, 0.06)
const GREY := Color(0.32, 0.32, 0.34)

## Traktorin mitat (kaisua_ajoneuvo.gd): akseliväli, renkaat ja kytkentäpisteet.
const T_WHEELBASE := 2.0
const T_REAR_R := 0.66
const T_FRONT_R := 0.36
const T_LINK := Vector3(0, 0.5, 1.02)  # kolmipistenostimen alavarsien päät (nostettu työkone +0,35 m)
const T_HITCH := Vector3(0, 0.42, 1.18)  # vetoaisan silmä
const T_SEAT := Vector3(0, 1.24, 0.5)
const T_PLATE_Y := 0.915  # astinlautojen yläpinta (urat 1,2 cm päällä)
## Ratti ohjausakselin päässä akselia vastaan kohtisuorassa: akseli nousee kojelaudalta (traktori) tai tasanteen
## etureunasta (puimuri) ylös ja taakse kuljettajaa kohti, joten ratin pinta kääntyy ylös kuljettajaa kohti ja
## etureuna on takareunaa korkeammalla (vrt. Deeren puimuripatentti US3583518A: pystyhkö akseli tasanteen
## etureunasta, istuin ratin takana). Kallistus = X-kierto, + kääntää pinnan normaalin taaksepäin (+Z).
## Vanhan traktorin akseli nousee polttoainesäiliön takaosasta 45° kulmassa kuljettajaa kohti, ja ratti on sitä
## vastaan kohtisuorassa (pinta 45° vaakatasosta, ei bussimaisen latteana).
const T_WHEEL := Vector3(0, 1.82, 0.06)  # ratin keskipiste (kuskin kädet, kaisua_ajoneuvo.gd)
const T_WHEEL_TILT := PI / 4.0
const T_COLUMN := T_WHEEL - Vector3(0, 0.7071, 0.7071) * 0.42  # akselin tyvi säiliön takaosassa
const T_LOADER := Vector3(0, 1.52, -0.38)  # kuormaimen puomin nivel
const T_SPEAR_LOW := Vector3(0, 0.62, -3.05)  # paalipiikin keskipiikin kärjen juuri puomi alhaalla
## Puimuri: vetävä akseli origossa, ohjaavat takapyörät +Z:ssa.
const C_WHEELBASE := 3.0
const C_SEAT := Vector3(0, 2.62, -0.5)  # mahan ja ratin lähireunan väliin jää rako (testi mittaa)
## Aurinkokatoksen alapinta: istuvan kuskin pään laki on n. 3,6 m (pää nousi aiemmin 3,25 m:n katon läpi), joten
## katos on 4,0 m:ssä ja pään yläpuolelle jää noin 35 cm (testi mokkikaisua tarkistaa raon).
const C_ROOF_Y := 3.97
const C_COLUMN := Vector3(0, 2.3, -1.16)  # ohjausakselin tyvi tasanteen etureunassa
const C_WHEEL := Vector3(0, 3.0, -0.88)  # loivan ratin lähireuna kuskin reisien yllä (testi mittaa raon)
const C_WHEEL_TILT := 0.38


static func _m(color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	return V._mat("kaisua/%s/%s/%s" % [color.to_html(), rough, metal], color, metal, rough)


static func _p(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return V.part(parent, mesh, pos, mat, rot)


## Putki kahden pisteen välille (sylinteri).
static func _tube(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, seg := 8) -> MeshInstance3D:
	var mi := _p(parent, B.cyl(r, r, a.distance_to(b), seg), (a + b) / 2.0, mat)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, y, x.cross(y))
	return mi


## Palkki kahden pisteen välille (neliöputki, leveys w, korkeus h).
static func _beam(parent: Node3D, a: Vector3, b: Vector3, w: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := _p(parent, B.boxm(Vector3(w, h, a.distance_to(b))), (a + b) / 2.0, mat)
	var z := (b - a).normalized()
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var x := up.cross(z).normalized()
	mi.basis = Basis(x, z.cross(x), z)
	return mi


## Ratin kehä omana kappaleenaan (ei yhdistetty runkoon): kuskin sormet puristuvat 3 cm:n kehän ympäri, joten käsi ja
## kehä ovat tarkoituksella sisäkkäin (meta "pehmea": asentotarkistus ohittaa otteen, Asento.solids).
static func _rim(parent: Node3D, c: Vector3, tilt: float, r_in: float, r_out: float, mat: Material) -> MeshInstance3D:
	var tor := TorusMesh.new()
	tor.inner_radius = r_in
	tor.outer_radius = r_out
	tor.rings = 24
	tor.ring_segments = 6
	var mi := _p(parent, tor, c, mat, Vector3(tilt, 0, 0))
	mi.name = "Ratti"
	mi.set_meta("pehmea", true)
	return mi


static func _merge(node: Node3D, key: String) -> void:
	V._merge_parts(node, 0, "kaisua/" + key)


# --- Traktori ------------------------------------------------------------------------------------------------------

## Vanha ohjaamoton traktori (60–70-luku): pyöreä konepelti, säleikkö ja kaksi lyhtyä, pystypakoputki ja
## esipuhdistin, pellinen istuin, kaarevat takalokasuojat, kolmipistenostin ja vetoaisa, etukuormain paalipiikillä.
## Palauttaa {"rear": [pyörät], "front": [ohjausnivelet, joissa pyörä], "front_spin": [pyörät], "loader": puomi,
## "spear": piikki, "body": runko}.
static func traktori(parent: Node3D) -> Dictionary:
	var body := Node3D.new()
	body.name = "Runko"
	parent.add_child(body)
	var red := V.paint(RED)
	var dark := _m(Color(0.14, 0.14, 0.15), 0.6, 0.3)
	var steel := _m(Color(0.42, 0.42, 0.44), 0.45, 0.6)
	var engine := _m(Color(0.3, 0.3, 0.32), 0.55, 0.4)
	var chrome := V._mat("ponykromi", Color(0.86, 0.87, 0.89), 0.45, 0.3)
	var black := _m(Color(0.06, 0.06, 0.06), 0.5)
	# Moottori, vaihteisto ja taka-akselin kotelot.
	_p(body, B.boxm(Vector3(0.48, 0.46, 1.6)), Vector3(0, 0.66, -1.1), engine)
	_p(body, B.boxm(Vector3(0.36, 0.14, 1.3)), Vector3(0, 0.38, -1.15), engine)  # öljypohja
	_p(body, B.boxm(Vector3(0.56, 0.56, 0.9)), Vector3(0, 0.7, -0.12), red)  # vaihteisto: pohkeet sen ulkoreunan yllä
	_p(body, B.cyl(0.13, 0.13, 1.3, 12), Vector3(0, T_REAR_R, 0), red, Vector3(0, 0, PI / 2.0))
	for sx in [-1.0, 1.0]:
		_p(body, B.cyl(0.2, 0.15, 0.14, 12), Vector3(sx * 0.33, T_REAR_R, 0), red, Vector3(0, 0, PI / 2.0))
	# Konepelti: suora alaosa ja pyöreä yläosa, sivuilla ilmanottosäleet.
	_p(body, B.boxm(Vector3(0.62, 0.34, 1.62)), Vector3(0, 1.05, -1.16), red)
	_p(body, B.cyl(0.31, 0.31, 1.62, 20), Vector3(0, 1.21, -1.16), red, Vector3(PI / 2.0, 0, 0))
	for sx in [-1.0, 1.0]:
		for i in 6:
			_p(body, B.boxm(Vector3(0.02, 0.025, 0.42)), Vector3(sx * 0.312, 0.96 + i * 0.05, -1.62), dark)
		_p(body, B.boxm(Vector3(0.012, 0.03, 1.56)), Vector3(sx * 0.316, 1.21, -1.16), V.paint(Color(0.92, 0.9, 0.84)))  # valkoinen raita
	# Maski: kehys, säleikkö ja lyhdyt kromikehyksin.
	_p(body, B.boxm(Vector3(0.6, 0.7, 0.06)), Vector3(0, 1.08, -1.99), red)
	_p(body, B.boxm(Vector3(0.46, 0.56, 0.04)), Vector3(0, 1.05, -2.02), dark)
	for i in 9:
		_p(body, B.boxm(Vector3(0.44, 0.022, 0.03)), Vector3(0, 0.81 + i * 0.06, -2.045), chrome)
	_p(body, B.cyl(0.31, 0.31, 0.06, 20), Vector3(0, 1.21, -1.99), red, Vector3(PI / 2.0, 0, 0))
	for sx in [-1.0, 1.0]:
		var lamp := Vector3(sx * 0.4, 1.28, -1.78)
		_p(body, B.boxm(Vector3(0.12, 0.05, 0.1)), Vector3(sx * 0.33, 1.28, -1.78), red)
		_p(body, B.cyl(0.085, 0.085, 0.12, 14), lamp, chrome, Vector3(PI / 2.0, 0, 0))
		_p(body, B.cyl(0.07, 0.07, 0.02, 14), lamp + Vector3(0, 0, -0.06), V.lamp(Color(1.0, 0.97, 0.85)), Vector3(PI / 2.0, 0, 0))
	# Pakoputki äänenvaimentimineen ja sadeläppä, esipuhdistin ja polttoainesäiliön korkki.
	_p(body, B.cyl(0.045, 0.045, 0.85, 10), Vector3(0.17, 1.86, -1.5), dark)
	_p(body, B.cyl(0.075, 0.075, 0.34, 12), Vector3(0.17, 1.72, -1.5), dark)
	_p(body, B.boxm(Vector3(0.1, 0.012, 0.1)), Vector3(0.17, 2.3, -1.52), dark, Vector3(0.5, 0, 0))
	_p(body, B.cyl(0.055, 0.055, 0.24, 12), Vector3(-0.16, 1.62, -1.62), dark)
	_p(body, B.cyl(0.07, 0.06, 0.1, 12), Vector3(-0.16, 1.78, -1.62), _m(Color(0.55, 0.5, 0.35), 0.15))
	_p(body, B.boxm(Vector3(0.56, 0.3, 0.46)), Vector3(0, 1.38, -0.28), red)  # polttoainesäiliö (kapea: kuskin polvet sivuilla)
	_p(body, B.cyl(0.05, 0.05, 0.05, 10), Vector3(0.18, 1.55, -0.32), chrome)
	# Mittaristo: vino paneeli säiliön takapinnassa (pinta kuljettajaa kohti), kaksi mittaria lasikehyksin ja
	# punaiset viisarit, virta-avain. Ohjausakseli säiliön takaosasta 45° kuljettajaa kohti, akselin juuressa suojakuppi.
	var dash := Basis(Vector3.RIGHT, -0.35)
	var dc := Vector3(0, 1.4, -0.035)
	var panel := _p(body, B.boxm(Vector3(0.54, 0.22, 0.03)), dc, dark)
	panel.basis = dash
	for sx in [-0.15, 0.15]:
		var g := dc + dash * Vector3(sx, 0.01, 0.02)
		var face := _p(body, B.cyl(0.045, 0.045, 0.012, 16), g, _m(Color(0.93, 0.92, 0.86), 0.3))
		face.basis = dash * Basis(Vector3.RIGHT, PI / 2.0)
		var rim := _p(body, B.cyl(0.052, 0.052, 0.008, 16), g - dash * Vector3(0, 0, 0.004), V._mat("ponykromi", Color(0.86, 0.87, 0.89), 0.45, 0.3))
		rim.basis = dash * Basis(Vector3.RIGHT, PI / 2.0)
		var needle := _p(body, B.boxm(Vector3(0.006, 0.035, 0.003)), g + dash * Vector3(0.008, 0.01, 0.008), _m(Color(0.8, 0.1, 0.05), 0.4))
		needle.basis = dash * Basis(Vector3.BACK, 0.5 + sx)
	var key := _p(body, B.boxm(Vector3(0.02, 0.02, 0.04)), dc + dash * Vector3(0, -0.07, 0.03), steel)
	key.basis = dash
	var nwheel := Basis(Vector3.RIGHT, T_WHEEL_TILT)  # ratin taso: paikallinen XZ, normaali akselin suunta
	_tube(body, T_COLUMN, T_WHEEL - nwheel * Vector3(0, 0.04, 0), 0.025, dark)
	var boot := _p(body, B.cyl(0.04, 0.06, 0.08, 12), T_COLUMN + nwheel * Vector3(0, 0.03, 0), black)
	boot.basis = nwheel
	# Napa hieman kehän alapuolella (kupera ratti) ja kolme puolaa kello 3, 9 ja 6 (6 = kuljettajan puoli, +Z).
	var hub := T_WHEEL - nwheel * Vector3(0, 0.035, 0)
	var cap := _p(body, B.cyl(0.04, 0.045, 0.04, 14), hub, black)
	cap.basis = nwheel
	for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK]:
		_tube(body, hub, T_WHEEL + nwheel * (dir * 0.175), 0.011, black)
	# Istuin: pellinen kuppi jousipalkilla.
	_p(body, B.boxm(Vector3(0.08, 0.06, 0.62)), Vector3(0, 1.04, 0.42), steel, Vector3(-0.35, 0, 0))
	_p(body, B.cyl(0.22, 0.18, 0.07, 16), T_SEAT + Vector3(0, -0.07, 0), black)  # kuppi reisien alla (ei painu)
	_p(body, B.boxm(Vector3(0.4, 0.2, 0.04)), T_SEAT + Vector3(0, 0.1, 0.24), black, Vector3(0.25, 0, 0))  # selkä nojaa, ei painu
	# Astinlaudat uritettuina taka-akselin napakoteloiden yläpuolella (kotelon laki 0,86 m): jalat lepäävät korkealla,
	# polvet koukussa, eivätkä reidet painu istuinkuppiin.
	for sx in [-1.0, 1.0]:
		_p(body, B.boxm(Vector3(0.28, 0.03, 0.7)), Vector3(sx * 0.44, T_PLATE_Y - 0.015, -0.05), steel)
		for i in 5:
			_p(body, B.boxm(Vector3(0.26, 0.012, 0.03)), Vector3(sx * 0.44, T_PLATE_Y + 0.006, -0.33 + i * 0.14), dark)
	# Kaarevat takalokasuojat (kaari taka-akselin ympäri, -Z eteen) ja takavalot.
	for sx in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		for k in 9:
			var th := lerpf(0.25, PI - 0.4, k / 8.0)
			var q := Vector3(sx * 0.78, T_REAR_R + sin(th) * 0.8, cos(th) * 0.8)
			if k > 0:
				V.slab(body, prev, q, 0.44, 0.035, red)
			prev = q
		_p(body, B.boxm(Vector3(0.03, 0.42, 0.75)), Vector3(sx * 0.56, 1.12, 0.06), red)  # sisäsivu
		_p(body, B.boxm(Vector3(0.07, 0.07, 0.05)), Vector3(sx * 0.78, 1.15, 0.79), V.lamp(Color(0.8, 0.05, 0.03)))
	# Etuakseli ja keskinivel.
	_p(body, B.boxm(Vector3(1.32, 0.1, 0.12)), Vector3(0, T_FRONT_R, -T_WHEELBASE), steel)
	_p(body, B.boxm(Vector3(0.2, 0.2, 0.3)), Vector3(0, T_FRONT_R + 0.12, -T_WHEELBASE), engine)
	# Kolmipistenostin ja vetoaisa.
	for sx in [-1.0, 1.0]:
		_beam(body, Vector3(sx * 0.22, 0.52, 0.32), Vector3(sx * 0.36, T_LINK.y, T_LINK.z), 0.05, 0.06, steel)
		_beam(body, Vector3(sx * 0.2, 1.02, 0.36), Vector3(sx * 0.3, 0.78, 0.7), 0.06, 0.06, red)  # nostovarret
		_tube(body, Vector3(sx * 0.3, 0.78, 0.7), Vector3(sx * 0.33, 0.55, 0.78), 0.018, steel)
	_beam(body, Vector3(0, 0.98, 0.4), Vector3(0, 0.95, 0.95), 0.06, 0.06, steel)  # yläveto
	_p(body, B.boxm(Vector3(0.12, 0.05, 0.7)), Vector3(0, 0.42, 0.85), steel)
	_p(body, B.cyl(0.025, 0.025, 0.14, 8), T_HITCH + Vector3(0, 0.03, 0), chrome)
	_p(body, B.cyl(0.05, 0.05, 0.14, 10), Vector3(0, 0.62, 0.62), steel, Vector3(PI / 2.0, 0, 0))  # voimanottoakseli
	# Kuormaimen tornit.
	for sx in [-1.0, 1.0]:
		_p(body, B.boxm(Vector3(0.08, 0.9, 0.16)), Vector3(sx * 0.5, 1.08, -0.38), red)
		_p(body, B.boxm(Vector3(0.12, 0.12, 0.3)), Vector3(sx * 0.48, 0.66, -0.38), red)
	_merge(body, "traktori")
	_rim(body, T_WHEEL, T_WHEEL_TILT, 0.17, 0.2, black)
	# Pyörät: takana kuviopinnat (rivit vinoon), edessä ohjausnivelet.
	var rim := V.paint(Color(0.82, 0.8, 0.76))
	var rear: Array[Node3D] = []
	var front: Array[Node3D] = []
	var spin: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		rear.append(V.wheel(parent, Vector3(sx * 0.8, T_REAR_R, 0), T_REAR_R, 0.36, 22, rim, 0.55))
		var piv := Node3D.new()
		piv.position = Vector3(sx * 0.68, T_FRONT_R, -T_WHEELBASE)
		parent.add_child(piv)
		front.append(piv)
		spin.append(V.wheel(piv, Vector3.ZERO, T_FRONT_R, 0.17, 0, rim, 0.6))
	# Etukuormain: puomi tornien nivelestä eteen ja alas, poikkiputki ja nostosylinterit; piikki pysyy vaakatasossa.
	var loader := Node3D.new()
	loader.name = "Kuormain"
	loader.position = T_LOADER
	parent.add_child(loader)
	var arm_mat := red
	for sx in [-1.0, 1.0]:
		var a := Vector3(sx * 0.5, 0, 0)
		var bend := Vector3(sx * 0.5, -0.28, -1.36)
		var tip := Vector3(sx * 0.5, T_SPEAR_LOW.y - T_LOADER.y + 0.05, T_SPEAR_LOW.z - T_LOADER.z + 0.45)
		_beam(loader, a, bend, 0.08, 0.12, arm_mat)
		_beam(loader, bend, tip, 0.08, 0.12, arm_mat)
		_tube(loader, Vector3(sx * 0.56, -0.72, -0.18), Vector3(sx * 0.56, -0.2, -0.95), 0.04, _m(Color(0.86, 0.87, 0.89), 0.3, 0.6))
	_tube(loader, Vector3(-0.5, -0.4, -1.75), Vector3(0.5, -0.4, -1.75), 0.05, arm_mat)
	_merge(loader, "kuormain")
	var spear := Node3D.new()
	spear.name = "Piikki"
	spear.position = Vector3(0, T_SPEAR_LOW.y - T_LOADER.y, T_SPEAR_LOW.z - T_LOADER.z + 0.45)
	loader.add_child(spear)
	_p(spear, B.boxm(Vector3(1.2, 0.7, 0.06)), Vector3(0, 0.12, 0), _m(Color(0.16, 0.16, 0.17), 0.6, 0.3))
	for sx in [-0.42, 0.42]:
		_p(spear, B.boxm(Vector3(0.08, 0.7, 0.1)), Vector3(sx, 0.12, 0.02), arm_mat)
	_tube(spear, Vector3(0, 0, 0), Vector3(0, 0, -1.05), 0.025, steel)
	_p(spear, B.cyl(0.0, 0.025, 0.12, 8), Vector3(0, 0, -1.11), steel, Vector3(-PI / 2.0, 0, 0))
	for sx in [-0.38, 0.38]:
		_tube(spear, Vector3(sx, 0.05, 0), Vector3(sx, 0.05, -0.5), 0.02, steel)
		_p(spear, B.cyl(0.0, 0.02, 0.08, 8), Vector3(sx, 0.05, -0.54), steel, Vector3(-PI / 2.0, 0, 0))
	_merge(spear, "piikki")
	return {"rear": rear, "front": front, "front_spin": spin, "loader": loader, "spear": spear, "body": body}


# --- Puimuri -------------------------------------------------------------------------------------------------------

## Vanha leikkuupuimuri avoimella ohjaamotasanteella ja aurinkokatoksella: leikkuupöytä kelalla ja syöttöruuvilla,
## viljasäiliö (jyväpinta nousee), kääntyvä purkuputki, olkipeite ja tikkaat. Vetävät pyörät edessä, ohjaavat takana.
## Palauttaa {"front": [pyörät], "rear": [ohjausnivelet], "rear_spin": [pyörät], "reel": kela, "auger": ruuvi,
## "spout": purkuputken nivel, "grain": säiliön jyväpinta, "spout_tip": Node3D (putken pää)}.
static func puimuri(parent: Node3D) -> Dictionary:
	var body := Node3D.new()
	parent.add_child(body)
	var red := V.paint(COMBINE_RED)
	var white := V.paint(Color(0.93, 0.92, 0.88))
	var dark := _m(Color(0.13, 0.13, 0.14), 0.6, 0.3)
	var steel := _m(Color(0.45, 0.45, 0.47), 0.45, 0.6)
	var black := _m(Color(0.06, 0.06, 0.06), 0.5)
	# Runko: puintikoneisto, sivuluukut ja olkipeite.
	# Runko alkaa kuljettajan selän takaa (z -0,05); tasanteen alla kapeampi jalusta.
	_p(body, B.boxm(Vector3(2.0, 1.9, 3.95)), Vector3(0, 1.95, 1.925), red)
	_p(body, B.boxm(Vector3(1.3, 1.2, 0.5)), Vector3(0, 1.6, -0.3), red)
	for sx in [-1.0, 1.0]:
		for i in 3:
			_p(body, B.boxm(Vector3(0.02, 1.2, 1.0)), Vector3(sx * 1.005, 2.0, 0.6 + i * 1.15), red)
			_p(body, B.boxm(Vector3(0.025, 1.24, 0.03)), Vector3(sx * 1.01, 2.0, 0.08 + i * 1.15), dark)
		_p(body, B.boxm(Vector3(0.02, 0.08, 3.95)), Vector3(sx * 1.01, 2.88, 1.925), white)
		for i in 8:
			_p(body, B.boxm(Vector3(0.025, 0.035, 0.5)), Vector3(sx * 1.01, 1.25 + i * 0.07, 3.4), dark)  # moottorin säleet
	V.slab(body, Vector3(0, 2.9, 3.9), Vector3(0, 1.4, 4.5), 1.9, 0.05, red)  # olkipeite
	_p(body, B.boxm(Vector3(1.6, 0.5, 0.3)), Vector3(0, 1.15, 4.45), dark)
	# Viljasäiliö ja sen reunat.
	_p(body, B.boxm(Vector3(1.9, 0.08, 1.9)), Vector3(0, 2.92, 0.9), red)
	for sx in [-1.0, 1.0]:
		_p(body, B.boxm(Vector3(0.06, 0.8, 1.9)), Vector3(sx * 0.95, 3.32, 0.9), red)
		_p(body, B.boxm(Vector3(1.9, 0.8, 0.06)), Vector3(0, 3.32, 0.9 + sx * 0.95), red)
	_p(body, B.boxm(Vector3(2.0, 0.06, 0.1)), Vector3(0, 3.74, -0.05), white)
	_p(body, B.boxm(Vector3(2.0, 0.06, 0.1)), Vector3(0, 3.74, 1.85), white)
	# Moottorin pakoputki ja ilmanotto.
	_p(body, B.cyl(0.06, 0.06, 0.9, 10), Vector3(0.6, 3.3, 2.9), dark)
	_p(body, B.cyl(0.22, 0.22, 0.3, 16), Vector3(-0.5, 3.0, 3.1), dark)
	# Syöttökuilu ja leikkuupöytä.
	V.slab(body, Vector3(0, 1.45, 0.0), Vector3(0, 0.72, -1.75), 1.15, 0.6, red)
	_p(body, B.boxm(Vector3(4.2, 0.7, 0.08)), Vector3(0, 0.58, -1.95), red)  # takaseinä
	_p(body, B.boxm(Vector3(4.2, 0.05, 0.95)), Vector3(0, 0.22, -2.4), steel)  # pohja
	for sx in [-1.0, 1.0]:
		_p(body, B.boxm(Vector3(0.05, 0.7, 1.0)), Vector3(sx * 2.1, 0.58, -2.4), red)
		_p(body, B.cyl(0.0, 0.14, 0.7, 4), Vector3(sx * 2.1, 0.32, -3.15), red, Vector3(-PI / 2.0, 0, 0))  # jakokärki
		_beam(body, Vector3(sx * 2.05, 0.9, -1.9), Vector3(sx * 2.05, 1.5, -2.75), 0.07, 0.07, red)  # kelan kannattimet
	_p(body, B.boxm(Vector3(4.2, 0.04, 0.06)), Vector3(0, 0.2, -2.88), steel)  # terä
	for i in 42:
		_p(body, B.cyl(0.0, 0.025, 0.12, 4), Vector3(-2.05 + i * 0.1, 0.2, -2.93), steel, Vector3(-PI / 2.0, 0, 0))
	# Ohjaamotasanne, kaide, istuin, ratti ja aurinkokatos.
	_p(body, B.boxm(Vector3(1.5, 0.08, 1.05)), Vector3(0, 2.26, -0.6), steel)
	for sx in [-0.72, 0.72]:
		_tube(body, Vector3(sx, 2.3, -1.1), Vector3(sx, C_ROOF_Y, -1.1), 0.025, dark)
		_tube(body, Vector3(sx, 2.3, -0.1), Vector3(sx, C_ROOF_Y, -0.1), 0.025, dark)
		_tube(body, Vector3(sx, 2.8, -1.1), Vector3(sx, 2.8, -0.1), 0.02, dark)
	_tube(body, Vector3(-0.72, 2.8, -1.1), Vector3(0.72, 2.8, -1.1), 0.02, dark)
	_p(body, B.boxm(Vector3(1.6, 0.06, 1.2)), Vector3(0, C_ROOF_Y + 0.03, -0.6), white)
	_p(body, B.boxm(Vector3(1.62, 0.12, 0.05)), Vector3(0, C_ROOF_Y - 0.02, -1.2), red)
	_p(body, B.cyl(0.2, 0.17, 0.07, 14), C_SEAT + Vector3(0, -0.04, 0), black)
	_p(body, B.boxm(Vector3(0.4, 0.3, 0.05)), C_SEAT + Vector3(0, 0.14, 0.26), black, Vector3(0.2, 0, 0))  # selkä nojaa, ei painu
	_tube(body, C_COLUMN, C_WHEEL, 0.03, dark)
	_p(body, B.cyl(0.05, 0.05, 0.05, 10), C_WHEEL, dark, Vector3(C_WHEEL_TILT, 0, 0))  # navan kansi
	for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK]:  # puolat kello 3, 9 ja 6: otteet (kymmentä vaille kaksi) vapaana
		_tube(body, C_WHEEL, C_WHEEL + Basis(Vector3.RIGHT, C_WHEEL_TILT) * dir * 0.18, 0.012, black)
	# Tikkaat vasemmalle kyljelle.
	for sz in [-0.95, -0.55]:
		_tube(body, Vector3(-1.08, 0.5, sz), Vector3(-1.08, 2.3, sz), 0.02, dark)
	for i in 6:
		_tube(body, Vector3(-1.08, 0.6 + i * 0.3, -0.95), Vector3(-1.08, 0.6 + i * 0.3, -0.55), 0.015, dark)
	# Akselit.
	_p(body, B.boxm(Vector3(2.4, 0.18, 0.2)), Vector3(0, 0.72, 0), dark)
	_p(body, B.boxm(Vector3(2.0, 0.12, 0.14)), Vector3(0, 0.42, C_WHEELBASE), dark)
	_merge(body, "puimuri")
	_rim(body, C_WHEEL, C_WHEEL_TILT, 0.17, 0.2, black)
	# Pyörät.
	var rim := white
	var front: Array[Node3D] = []
	var rear: Array[Node3D] = []
	var spin: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		front.append(V.wheel(parent, Vector3(sx * 1.25, 0.72, 0), 0.72, 0.42, 20, rim, 0.55))
		var piv := Node3D.new()
		piv.position = Vector3(sx * 0.95, 0.42, C_WHEELBASE)
		parent.add_child(piv)
		rear.append(piv)
		spin.append(V.wheel(piv, Vector3.ZERO, 0.42, 0.24, 14, rim, 0.6))
	# Kela: viisi puolaa piikkeineen akselin ympärillä.
	var reel := Node3D.new()
	reel.position = Vector3(0, 1.4, -2.72)
	parent.add_child(reel)
	_tube(reel, Vector3(-2.05, 0, 0), Vector3(2.05, 0, 0), 0.04, steel)
	for k in 5:
		var a := TAU * k / 5.0
		var r := Vector3(0, sin(a), cos(a)) * 0.55
		_tube(reel, r + Vector3(-2.0, 0, 0), r + Vector3(2.0, 0, 0), 0.03, V.paint(Color(0.95, 0.75, 0.1)))
		for sx in [-1.6, 0.0, 1.6]:
			_tube(reel, Vector3(sx, 0, 0), Vector3(sx, 0, 0) + r, 0.018, steel)
		for i in 14:
			var tp := r + Vector3(-1.95 + i * 0.3, 0, 0)
			_tube(reel, tp, tp + Vector3(0, -0.22, 0.04).rotated(Vector3.RIGHT, a), 0.008, steel)
	_merge(reel, "kela")
	# Syöttöruuvi pöydän pohjalla.
	var auger := Node3D.new()
	auger.position = Vector3(0, 0.45, -2.25)
	parent.add_child(auger)
	_p(auger, B.cyl(0.11, 0.11, 4.0, 12), Vector3.ZERO, steel, Vector3(0, 0, PI / 2.0))
	for i in 26:
		var x := -1.95 + i * 0.15
		var a2 := i * 0.9 * (1.0 if x < 0.0 else -1.0)
		_p(auger, B.boxm(Vector3(0.02, 0.4, 0.05)), Vector3(x, 0, 0), steel, Vector3(a2, 0, 0.25 * signf(x)))
	_merge(auger, "ruuvi")
	# Viljasäiliön jyväpinta (skaalataan täyttöasteen mukaan).
	var grain := MeshInstance3D.new()
	grain.mesh = B.boxm(Vector3(1.82, 1.0, 1.82))
	grain.material_override = _m(Color(0.86, 0.74, 0.42), 0.95)
	grain.position = Vector3(0, 2.96, 0.9)
	grain.scale = Vector3(1, 0.01, 1)
	parent.add_child(grain)
	# Purkuputki: nivel säiliön vasemmassa takakulmassa, kuljetusasennossa taaksepäin kylkeä pitkin.
	var spout := Node3D.new()
	spout.position = Vector3(-0.95, 3.3, 1.8)
	parent.add_child(spout)
	_tube(spout, Vector3.ZERO, Vector3(0, 0.35, 0), 0.14, red)
	_tube(spout, Vector3(0, 0.35, 0), Vector3(0, 0.55, 3.2), 0.12, red)
	_p(spout, B.cyl(0.14, 0.1, 0.35, 12), Vector3(0, 0.38, 3.32), dark)
	_merge(spout, "purkuputki")
	var tip := Node3D.new()
	tip.position = Vector3(0, 0.25, 3.35)
	spout.add_child(tip)
	return {"front": front, "rear": rear, "rear_spin": spin, "reel": reel, "auger": auger, "spout": spout, "grain": grain,
		"spout_tip": tip}


# --- Työkoneet -----------------------------------------------------------------------------------------------------

## Työkoneen tiedot: kiinnitys ("nostin" = kolmipiste jäykästi, "aisa" = vetoaisa, perävaunu seuraa), työalue
## koneen kehyksessä (keskipiste, puolileveys sivulle, puolipituus ajosuuntaan), akselin etäisyys (aisa) ja nimi.
const IMPLEMENTS := {
	"niittokone": {"name": "Niittokone", "mount": "nostin", "work": "niitto", "c": Vector3(2.05, 0, 0.9), "hw": 1.75, "hl": 0.35, "speed": 4.2},
	"karhotin": {"name": "Karhotin", "mount": "nostin", "work": "karhous", "c": Vector3(0, 0, 1.75), "hw": 3.0, "hl": 1.2, "speed": 4.2},
	"paalain": {"name": "Paalain", "mount": "aisa", "work": "paalaus", "c": Vector3(0, 0, 1.95), "hw": 0.95, "hl": 0.35, "axle": 2.7, "speed": 3.6},
	"aura": {"name": "Aura", "mount": "nostin", "work": "kynto", "c": Vector3(0.9, 0, 1.6), "hw": 1.5, "hl": 0.6, "speed": 3.6},
	"aes": {"name": "Äes", "mount": "nostin", "work": "aestys", "c": Vector3(0, 0, 1.15), "hw": 2.25, "hl": 0.8, "speed": 4.2},
	"kylvokone": {"name": "Kylvökone", "mount": "nostin", "work": "kylvo", "c": Vector3(0, 0, 1.05), "hw": 2.0, "hl": 0.45, "speed": 3.6},
	"perakarry": {"name": "Viljakärry", "mount": "aisa", "work": "", "c": Vector3.ZERO, "hw": 0.0, "hl": 0.0, "axle": 4.3, "speed": 7.0},
}


## Työkone: palauttaa {"root": Node3D, "parts": {liikkuvat osat}}.
static func implement(parent: Node3D, id: String) -> Dictionary:
	var root := Node3D.new()
	root.name = id
	parent.add_child(root)
	var parts := {}
	match id:
		"niittokone":
			parts = _niittokone(root)
		"karhotin":
			parts = _karhotin(root)
		"paalain":
			parts = _paalain(root)
		"aura":
			parts = _aura(root)
		"aes":
			parts = _aes(root)
		"kylvokone":
			parts = _kylvokone(root)
		"perakarry":
			parts = _perakarry(root)
	return {"root": root, "parts": parts}


## Sivuniittokone (lautasniittokone): A-kehys kolmipisteeseen, niittopalkki oikealle kuudella lautasella,
## suojapeite ja kumiverho. Palkin nivel nostaa palkin pystyyn kuljetukseen ("bar").
static func _niittokone(root: Node3D) -> Dictionary:
	var red := V.paint(RED)
	var dark := _m(Color(0.13, 0.13, 0.14), 0.6, 0.3)
	var steel := _m(Color(0.45, 0.45, 0.47), 0.45, 0.6)
	var frame := Node3D.new()
	root.add_child(frame)
	for sx in [-0.36, 0.36]:
		_beam(frame, Vector3(sx, 0.5, 0), Vector3(0.05, 0.98, 0.05), 0.07, 0.07, red)
	_beam(frame, Vector3(-0.36, 0.5, 0.02), Vector3(0.36, 0.5, 0.02), 0.07, 0.07, red)
	_beam(frame, Vector3(0.0, 0.5, 0.1), Vector3(0.55, 0.35, 0.85), 0.1, 0.1, red)
	_p(frame, B.boxm(Vector3(0.3, 0.3, 0.3)), Vector3(0.45, 0.42, 0.75), dark)  # vaihteisto
	_tube(frame, Vector3(0, 0.62, -0.05), Vector3(0.4, 0.42, 0.65), 0.035, steel)  # nivelakseli
	_merge(frame, "niitto_runko")
	var bar := Node3D.new()
	bar.name = "Palkki"
	bar.position = Vector3(0.55, 0.12, 0.9)
	root.add_child(bar)
	_p(bar, B.boxm(Vector3(3.4, 0.08, 0.32)), Vector3(1.7, -0.04, 0), steel)
	# Suojapeite: punainen kalteva kansi ja kumiverho edessä.
	V.slab(bar, Vector3(0.05, 0.42, 0.25), Vector3(0.05, 0.22, -0.4), 0.04, 0.03, red)
	for i in 8:
		var x := 0.1 + i * 0.47
		_p(bar, B.boxm(Vector3(0.44, 0.03, 0.7)), Vector3(x + 0.2, 0.38, -0.05), red, Vector3(-0.35, 0, 0))
		_p(bar, B.boxm(Vector3(0.44, 0.3, 0.01)), Vector3(x + 0.2, 0.15, -0.38), _m(Color(0.08, 0.08, 0.08), 0.8))
	_p(bar, B.boxm(Vector3(0.05, 0.42, 0.75)), Vector3(3.45, 0.18, -0.03), red)
	_merge(bar, "niitto_palkki")
	var discs: Array[Node3D] = []
	for i in 6:
		var d := Node3D.new()
		d.position = Vector3(0.35 + i * 0.56, 0.04, -0.02)
		bar.add_child(d)
		_p(d, B.cyl(0.24, 0.24, 0.05, 16), Vector3.ZERO, dark)
		for sx in [-1.0, 1.0]:
			_p(d, B.boxm(Vector3(0.12, 0.012, 0.05)), Vector3(sx * 0.27, 0, 0), steel)
		discs.append(d)
	return {"bar": bar, "spin": discs}


## Kaksiroottorinen keskikarhotin: keskipalkki, poikkipalkki ja kaksi roottoria piikkivarsineen, karhoverho keskellä.
static func _karhotin(root: Node3D) -> Dictionary:
	var red := V.paint(RED)
	var dark := _m(Color(0.13, 0.13, 0.14), 0.6, 0.3)
	var steel := _m(Color(0.5, 0.5, 0.52), 0.4, 0.7)
	var frame := Node3D.new()
	root.add_child(frame)
	for sx in [-0.36, 0.36]:
		_beam(frame, Vector3(sx, 0.5, 0), Vector3(0, 1.0, 0.2), 0.07, 0.07, red)
	_beam(frame, Vector3(-0.36, 0.5, 0.02), Vector3(0.36, 0.5, 0.02), 0.07, 0.07, red)
	_beam(frame, Vector3(0, 0.95, 0.15), Vector3(0, 0.75, 1.75), 0.14, 0.14, red)
	_beam(frame, Vector3(-1.6, 0.75, 1.75), Vector3(1.6, 0.75, 1.75), 0.12, 0.12, red)
	_p(frame, B.boxm(Vector3(1.2, 0.7, 0.02)), Vector3(0, 0.38, 3.1), _m(Color(0.1, 0.25, 0.5), 0.8))  # karhoverho
	_beam(frame, Vector3(0, 0.75, 1.75), Vector3(0, 0.75, 3.1), 0.06, 0.06, red)
	_tube(frame, Vector3(-0.6, 0.75, 3.1), Vector3(0.6, 0.75, 3.1), 0.03, red)
	for sx in [-1.55, 1.55]:
		_p(frame, B.cyl(0.18, 0.2, 0.3, 12), Vector3(sx, 0.62, 1.75), red)
		_p(frame, B.cyl(0.14, 0.14, 0.12, 10), Vector3(sx * 1.25, 0.16, 1.75), dark, Vector3(0, 0, PI / 2.0))  # kannatinpyörät
	_merge(frame, "karho_runko")
	var rotors: Array[Node3D] = []
	for sx in [-1.55, 1.55]:
		var r := Node3D.new()
		r.position = Vector3(sx, 0.48, 1.75)
		root.add_child(r)
		for k in 10:
			var a := TAU * k / 10.0
			var dir := Vector3(cos(a), 0, sin(a))
			_tube(r, Vector3.ZERO, dir * 1.4 + Vector3(0, 0.02, 0), 0.022, red, 6)
			for t in 4:
				var tp := dir * 1.4 + dir.cross(Vector3.UP) * (t - 1.5) * 0.06
				_tube(r, tp, tp + Vector3(0, -0.42, 0) - dir.cross(Vector3.UP) * 0.05, 0.008, steel, 4)
		_merge(r, "roottori")
		rotors.append(r)
	return {"spin": rotors}


## Pyöröpaalain: vetoaisa, karheensyöttäjä (pyörivä piikkitela), paalauskammio sivulevyineen ja takaluukku, joka
## aukeaa ylös paalia pudottaessa. Akseli 2,7 m kytkennästä.
static func _paalain(root: Node3D) -> Dictionary:
	var red := V.paint(RED)
	var white := V.paint(Color(0.93, 0.92, 0.88))
	var dark := _m(Color(0.13, 0.13, 0.14), 0.6, 0.3)
	var steel := _m(Color(0.5, 0.5, 0.52), 0.4, 0.7)
	var frame := Node3D.new()
	root.add_child(frame)
	_beam(frame, Vector3(0, 0.42, 0), Vector3(0, 0.62, 1.6), 0.12, 0.14, red)  # aisa, silmä vetokoukun korkeudella
	_p(frame, B.cyl(0.05, 0.05, 0.12, 10), Vector3(0, 0.42, 0.05), dark)
	_tube(frame, Vector3(0, 0.6, -0.4), Vector3(0, 0.66, 1.55), 0.03, steel)  # nivelakseli voimanottoon
	# Kammio: rumpu ja sivulevyt (etupuolisko kiinteä).
	_p(frame, B.cyl(0.78, 0.78, 1.36, 24), Vector3(0, 1.05, 2.55), red, Vector3(0, 0, PI / 2.0))
	for sx in [-1.0, 1.0]:
		_p(frame, B.cyl(0.8, 0.8, 0.04, 24), Vector3(sx * 0.7, 1.05, 2.55), red, Vector3(0, 0, PI / 2.0))
		_p(frame, B.cyl(0.25, 0.25, 0.05, 16), Vector3(sx * 0.73, 1.05, 2.55), white, Vector3(0, 0, PI / 2.0))
		_p(frame, B.boxm(Vector3(0.05, 0.1, 1.2)), Vector3(sx * 0.73, 0.35, 2.55), dark)
	_p(frame, B.boxm(Vector3(1.9, 0.12, 0.14)), Vector3(0, 0.38, 2.7), dark)  # akseli
	_p(frame, B.boxm(Vector3(1.4, 0.04, 0.5)), Vector3(0, 0.95, 1.85), steel, Vector3(0.6, 0, 0))  # syöttölevy
	_merge(frame, "paalain_runko")
	var pickup := Node3D.new()
	pickup.position = Vector3(0, 0.24, 1.95)
	root.add_child(pickup)
	_p(pickup, B.cyl(0.12, 0.12, 1.8, 12), Vector3.ZERO, dark, Vector3(0, 0, PI / 2.0))
	for k in 4:
		var a := TAU * k / 4.0
		for i in 12:
			var x := -0.85 + i * 0.155
			var d := Vector3(0, sin(a), cos(a))
			_tube(pickup, Vector3(x, 0, 0) + d * 0.1, Vector3(x, 0, 0) + d * 0.26, 0.008, steel, 4)
	_merge(pickup, "noukin")
	var gate := Node3D.new()
	gate.name = "Takaluukku"
	gate.position = Vector3(0, 1.78, 2.55)
	root.add_child(gate)
	_p(gate, B.boxm(Vector3(1.4, 0.06, 0.8)), Vector3(0, 0.02, 0.4), red, Vector3(0.1, 0, 0))
	for sx in [-1.0, 1.0]:
		_p(gate, B.cyl(0.8, 0.8, 0.04, 24), Vector3(sx * 0.72, -0.73, 0.02), red, Vector3(0, 0, PI / 2.0))
	_p(gate, B.boxm(Vector3(1.4, 1.4, 0.06)), Vector3(0, -0.72, 0.78), red)
	for sx in [-0.4, 0.4]:
		_p(gate, B.boxm(Vector3(0.18, 0.08, 0.04)), Vector3(sx, -1.25, 0.82), V.lamp(Color(0.85, 0.05, 0.03)))
	_merge(gate, "luukku")
	var wheels: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		wheels.append(V.wheel(root, Vector3(sx * 0.98, 0.36, 2.7), 0.36, 0.22, 14, white, 0.6))
	return {"spin": [pickup], "gate": gate, "wheels": wheels}


## Nelisiipinen kääntöaura: A-kehys ja kääntölaite, runkopalkki vinosti oikealle taakse, neljä vannasta (kiiltäväksi
## kulunut siipi, terä ja kärki, varsi ja kantapää) ja yläpuolella samat peilattuna toiseen suuntaan (kääntöaura),
## takana syvyyspyörä. Töissä aura painuu 18 cm maahan (kaisua_ajoneuvo.gd).
static func _aura(root: Node3D) -> Dictionary:
	var red := V.paint(RED)
	var dark := _m(Color(0.12, 0.12, 0.13), 0.6, 0.3)
	var shine := _m(Color(0.78, 0.79, 0.8), 0.22, 0.95)  # mullan kiillottama siipi
	var steel := _m(Color(0.5, 0.5, 0.52), 0.4, 0.7)
	var frame := Node3D.new()
	root.add_child(frame)
	for sx in [-0.36, 0.36]:
		_beam(frame, Vector3(sx, 0.5, 0), Vector3(0, 1.05, 0.2), 0.07, 0.07, red)
	_beam(frame, Vector3(-0.36, 0.5, 0.02), Vector3(0.36, 0.5, 0.02), 0.07, 0.07, red)
	_p(frame, B.cyl(0.13, 0.13, 0.3, 14), Vector3(0, 0.78, 0.32), dark, Vector3(PI / 2.0, 0, 0))  # kääntölaite
	var b0 := Vector3(0.05, 0.78, 0.45)
	var b1 := Vector3(1.75, 0.78, 3.3)
	_beam(frame, b0, b1, 0.13, 0.13, red)
	for k in 4:
		var t := 0.12 + k * 0.26
		var at := b0.lerp(b1, t)
		for up: float in [1.0, -1.0]:
			# Varsi palkista maahan (alempi sarja) tai ylös (ylempi, kääntöpuolen sarja).
			var foot := at + Vector3(0, -0.72 * up, 0)
			_beam(frame, at, foot + Vector3(0, 0.12 * up, 0), 0.05, 0.12, dark)
			# Siipi: kolme kiertyvää laattaa terältä ylös ja sivulle (oikealle käännetty multa), terä ja kärki.
			var side := 1.0 if up > 0.0 else -1.0
			for q in 3:
				var y0 := foot.y + up * (0.04 + q * 0.12)
				var x0 := foot.x - side * 0.12 + side * q * 0.1
				var plate := _p(frame, B.boxm(Vector3(0.46, 0.14, 0.012)), Vector3(x0 + side * 0.08, y0 + up * 0.06, foot.z - 0.1 + q * 0.08), shine)
				plate.basis = Basis(Vector3.UP, side * (0.55 + q * 0.25)) * Basis(Vector3.RIGHT, -up * (0.35 + q * 0.12))
			_p(frame, B.boxm(Vector3(0.34, 0.012, 0.16)), foot + Vector3(-side * 0.05, up * 0.02, -0.22), steel, Vector3(0, side * 0.5, 0))
			_p(frame, B.cyl(0.0, 0.035, 0.22, 4), foot + Vector3(-side * 0.17, up * 0.025, -0.36), steel, Vector3(-PI / 2.0, side * 0.5, 0))
			_p(frame, B.boxm(Vector3(0.03, 0.12, 0.45)), foot + Vector3(-side * 0.16, up * 0.07, 0.0), dark)  # kantapää
	_beam(frame, b1, b1 + Vector3(0.0, -0.3, 0.55), 0.06, 0.06, red)
	_merge(frame, "aura_runko")
	var wheel := V.wheel(root, b1 + Vector3(0.32, -0.42, 0.55), 0.33, 0.16, 12, V.paint(Color(0.82, 0.8, 0.76)), 0.6)
	return {"wheels": [wheel]}


## S-piikkiäes: A-kehys, kolme poikkipalkkia porrastetuin S-piikein ja takana murskaintela.
static func _aes(root: Node3D) -> Dictionary:
	var red := V.paint(RED)
	var dark := _m(Color(0.13, 0.13, 0.14), 0.6, 0.3)
	var steel := _m(Color(0.55, 0.55, 0.56), 0.35, 0.75)
	var frame := Node3D.new()
	root.add_child(frame)
	for sx in [-0.36, 0.36]:
		_beam(frame, Vector3(sx, 0.5, 0), Vector3(0, 1.0, 0.3), 0.07, 0.07, red)
		_beam(frame, Vector3(sx, 0.5, 0), Vector3(sx * 2.0, 0.62, 0.6), 0.07, 0.07, red)
	_beam(frame, Vector3(0, 1.0, 0.3), Vector3(0, 0.62, 1.4), 0.08, 0.08, red)
	for zi in 3:
		var z := 0.6 + zi * 0.4
		_beam(frame, Vector3(-2.3, 0.62, z), Vector3(2.3, 0.62, z), 0.08, 0.08, red)
		for i in 7:
			var x := -2.1 + i * 0.7 + zi * 0.23
			# S-piikki: kaari palkilta alas ja eteen, kärki maassa.
			var pts := [Vector3(x, 0.58, z), Vector3(x, 0.4, z + 0.12), Vector3(x, 0.22, z + 0.06), Vector3(x, 0.08, z - 0.1), Vector3(x, 0.01, z - 0.16)]
			for k in pts.size() - 1:
				_beam(frame, pts[k], pts[k + 1], 0.05, 0.012, steel)
	for sx in [-2.3, 2.3]:
		_beam(frame, Vector3(sx, 0.62, 0.6), Vector3(sx, 0.62, 1.6), 0.06, 0.06, red)
		_beam(frame, Vector3(sx, 0.62, 1.6), Vector3(sx, 0.2, 1.95), 0.05, 0.05, red)
	_merge(frame, "aes_runko")
	var roll := Node3D.new()
	roll.position = Vector3(0, 0.2, 1.95)
	root.add_child(roll)
	_p(roll, B.cyl(0.05, 0.05, 4.6, 8), Vector3.ZERO, dark, Vector3(0, 0, PI / 2.0))
	for k in 8:
		var a := TAU * k / 8.0
		_p(roll, B.boxm(Vector3(4.5, 0.025, 0.025)), Vector3(0, sin(a) * 0.17, cos(a) * 0.17), steel)
	_merge(roll, "tela")
	return {"spin": [roll]}


## Kylvölannoitin: pitkä säiliö kansineen (siemen ja lannoite), kylvövantaat ja siemenputket, peiteäes ja
## maapyörä. Säiliön kannen raosta näkyy siemenpinta (laskee siemenen mukaan).
static func _kylvokone(root: Node3D) -> Dictionary:
	var red := V.paint(RED)
	var dark := _m(Color(0.13, 0.13, 0.14), 0.6, 0.3)
	var steel := _m(Color(0.55, 0.55, 0.56), 0.35, 0.75)
	var frame := Node3D.new()
	root.add_child(frame)
	for sx in [-0.36, 0.36]:
		_beam(frame, Vector3(sx, 0.5, 0), Vector3(0, 1.05, 0.35), 0.07, 0.07, red)
		_beam(frame, Vector3(sx, 0.5, 0), Vector3(sx * 2.0, 0.5, 0.75), 0.07, 0.07, red)
	_beam(frame, Vector3(-2.05, 0.5, 0.75), Vector3(2.05, 0.5, 0.75), 0.09, 0.09, red)
	# Säiliö: viisto etu- ja takaseinä, päädyt, kansi ja väliseinä.
	_p(frame, B.boxm(Vector3(4.0, 0.62, 0.05)), Vector3(0, 1.12, 0.62), red, Vector3(0.2, 0, 0))
	_p(frame, B.boxm(Vector3(4.0, 0.62, 0.05)), Vector3(0, 1.12, 1.22), red, Vector3(-0.2, 0, 0))
	_p(frame, B.boxm(Vector3(4.0, 0.05, 0.44)), Vector3(0, 0.82, 0.92), red)
	for sx in [-2.0, 2.0]:
		_p(frame, B.boxm(Vector3(0.05, 0.66, 0.78)), Vector3(sx, 1.12, 0.92), red)
	_p(frame, B.boxm(Vector3(4.06, 0.04, 0.4)), Vector3(0, 1.47, 1.1), V.paint(Color(0.93, 0.92, 0.88)), Vector3(-0.25, 0, 0))  # kansi
	_p(frame, B.boxm(Vector3(4.06, 0.03, 0.12)), Vector3(0, 1.45, 0.66), V.paint(Color(0.93, 0.92, 0.88)))
	# Vantaat ja siemenputket 12,5 cm välein (piirretty 25 cm välein), peiteäes.
	for i in 16:
		var x := -1.88 + i * 0.25
		_tube(frame, Vector3(x, 0.8, 0.92), Vector3(x, 0.15, 1.02), 0.015, dark, 5)
		_beam(frame, Vector3(x, 0.5, 0.75), Vector3(x, 0.03, 1.0), 0.03, 0.06, steel)
		_p(frame, B.cyl(0.11, 0.11, 0.015, 12), Vector3(x + 0.03, 0.1, 0.95), steel, Vector3(0, 0, PI / 2.0))
		_beam(frame, Vector3(x + 0.12, 0.35, 1.35), Vector3(x + 0.12, 0.01, 1.5), 0.012, 0.012, steel)
	_beam(frame, Vector3(-2.0, 0.35, 1.35), Vector3(2.0, 0.35, 1.35), 0.05, 0.05, red)
	_p(frame, B.cyl(0.32, 0.32, 0.1, 16), Vector3(2.2, 0.32, 0.9), dark, Vector3(0, 0, PI / 2.0))  # maapyörä
	_merge(frame, "kylvo_runko")
	var seed := MeshInstance3D.new()
	seed.mesh = B.boxm(Vector3(3.9, 0.02, 0.5))
	seed.material_override = _m(Color(0.78, 0.66, 0.38), 0.9)
	seed.position = Vector3(0, 1.32, 0.92)
	root.add_child(seed)
	return {"seed": seed}


## Viljakärry (kippilava): aisa, runko, akseli kahdella pyörällä ja kippaava lava (nivel takana alhaalla), jonka
## sisällä viljakeko nousee kuorman mukaan. Takaluukku aukeaa kipatessa.
static func _perakarry(root: Node3D) -> Dictionary:
	var red := V.paint(RED)
	var dark := _m(Color(0.13, 0.13, 0.14), 0.6, 0.3)
	var white := V.paint(Color(0.93, 0.92, 0.88))
	var frame := Node3D.new()
	root.add_child(frame)
	for sx in [-0.5, 0.5]:
		_beam(frame, Vector3(0, 0.42, 0), Vector3(sx, 0.75, 1.4), 0.1, 0.12, dark)
		_beam(frame, Vector3(sx, 0.75, 1.4), Vector3(sx, 0.75, 6.1), 0.12, 0.16, dark)
	_p(frame, B.cyl(0.05, 0.05, 0.1, 10), Vector3(0, 0.42, 0.05), dark)
	_p(frame, B.boxm(Vector3(2.0, 0.14, 0.14)), Vector3(0, 0.45, 4.3), dark)
	_tube(frame, Vector3(0, 0.78, 2.0), Vector3(0, 1.0, 3.0), 0.08, _m(Color(0.86, 0.87, 0.89), 0.3, 0.6))  # kippisylinteri
	_merge(frame, "karry_runko")
	var bed := Node3D.new()
	bed.name = "Lava"
	bed.position = Vector3(0, 0.9, 6.1)
	root.add_child(bed)
	var L := 4.6
	_p(bed, B.boxm(Vector3(2.1, 0.06, L)), Vector3(0, 0.0, -L / 2.0), red)
	for sx in [-1.0, 1.0]:
		_p(bed, B.boxm(Vector3(0.05, 0.85, L)), Vector3(sx * 1.05, 0.45, -L / 2.0), red)
		for i in 5:
			_p(bed, B.boxm(Vector3(0.06, 0.85, 0.06)), Vector3(sx * 1.08, 0.45, -0.2 - i * 1.05), dark)
		_p(bed, B.boxm(Vector3(0.07, 0.07, L)), Vector3(sx * 1.08, 0.88, -L / 2.0), white)
	_p(bed, B.boxm(Vector3(2.1, 0.85, 0.05)), Vector3(0, 0.45, -L), red)
	_merge(bed, "lava")
	var gate := Node3D.new()
	gate.position = Vector3(0, 0.9, 0.0)
	bed.add_child(gate)
	_p(gate, B.boxm(Vector3(2.1, 0.85, 0.05)), Vector3(0, -0.45, 0.02), red)
	for sx in [-0.7, 0.7]:
		_p(gate, B.boxm(Vector3(0.16, 0.08, 0.04)), Vector3(sx, -0.75, 0.06), V.lamp(Color(0.85, 0.05, 0.03)))
	var heap := MeshInstance3D.new()
	heap.mesh = B.boxm(Vector3(2.0, 1.0, L - 0.1))
	heap.material_override = _m(Color(0.86, 0.74, 0.42), 0.95)
	heap.position = Vector3(0, 0.03, -L / 2.0)
	heap.scale = Vector3(1, 0.01, 1)
	bed.add_child(heap)
	var mound := MeshInstance3D.new()
	mound.mesh = B.sphere(1.0, 16)
	mound.material_override = heap.material_override
	mound.position = Vector3(0, 0.03, -L / 2.0)
	mound.scale = Vector3(0.9, 0.01, 2.0)
	bed.add_child(mound)
	var wheels: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		wheels.append(V.wheel(root, Vector3(sx * 1.0, 0.45, 4.3), 0.45, 0.3, 16, white, 0.6))
	return {"bed": bed, "gate": gate, "heap": heap, "mound": mound, "wheels": wheels}


# --- Paali ---------------------------------------------------------------------------------------------------------

## Muoviin kääritty pyöröpaali (Ø 1,24 m, leveys 1,2 m), akseli paikallinen X: pyöristetyt reunat, kääreen
## päällekkäiset kaistat ja teipattu sauma.
static func paali(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var film := V._mat("kaisua/kalvo", Color(0.94, 0.95, 0.94), 0.0, 0.28)
	var seam := V._mat("kaisua/kalvo_sauma", Color(0.84, 0.86, 0.85), 0.0, 0.35)
	_p(root, B.cyl(0.62, 0.62, 1.04, 24), Vector3(0, 0.62, 0), film, Vector3(0, 0, PI / 2.0))
	for sx in [-1.0, 1.0]:
		_p(root, B.cyl(0.58, 0.6, 0.06, 24), Vector3(sx * 0.55, 0.62, 0), film, Vector3(0, 0, PI / 2.0))
		_p(root, B.cyl(0.54, 0.58, 0.03, 24), Vector3(sx * 0.595, 0.62, 0), film, Vector3(0, 0, PI / 2.0))
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var band := _p(root, B.boxm(Vector3(1.22, 0.004, 0.05)), Vector3(0, 0.62 + sin(a) * 0.622, cos(a) * 0.622), seam)
		band.basis = Basis(Vector3.RIGHT, -a + PI / 2.0) * Basis(Vector3.UP, 0.35)
	_p(root, B.boxm(Vector3(0.02, 0.3, 0.06)), Vector3(0.6, 0.62, 0.2), seam)
	_merge(root, "paali")
	return root


# --- Dieselsäiliö --------------------------------------------------------------------------------------------------

## Pihan polttoainesäiliö: vihreä 1 000 l lieriö jaloillaan, mittari, letku pistoolilla ja tippa-astia, varoituskyltti.
static func diesel_tank(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var green := V.paint(Color(0.16, 0.36, 0.2))
	var dark := _m(Color(0.12, 0.12, 0.13), 0.6, 0.3)
	var steel := _m(Color(0.5, 0.5, 0.52), 0.4, 0.7)
	_p(root, B.cyl(0.58, 0.58, 1.9, 20), Vector3(0, 1.35, 0), green, Vector3(0, 0, PI / 2.0))
	for sx in [-1.0, 1.0]:
		_p(root, B.cyl(0.6, 0.6, 0.04, 20), Vector3(sx * 0.95, 1.35, 0), V.paint(Color(0.12, 0.28, 0.15)), Vector3(0, 0, PI / 2.0))
		for sz in [-1.0, 1.0]:
			_beam(root, Vector3(sx * 0.7, 0.0, sz * 0.5), Vector3(sx * 0.7, 0.95, sz * 0.32), 0.07, 0.07, dark)
		_beam(root, Vector3(sx * 0.7, 0.4, -0.45), Vector3(sx * 0.7, 0.4, 0.45), 0.05, 0.05, dark)
	_p(root, B.cyl(0.1, 0.1, 0.12, 12), Vector3(0.4, 1.96, 0), steel)  # täyttökansi
	_p(root, B.boxm(Vector3(0.22, 0.3, 0.14)), Vector3(-0.5, 1.2, -0.62), _m(Color(0.85, 0.85, 0.82), 0.4))  # mittari
	_p(root, B.cyl(0.06, 0.06, 0.02, 14), Vector3(-0.5, 1.25, -0.7), _m(Color(0.95, 0.95, 0.9), 0.3), Vector3(PI / 2.0, 0, 0))
	var prev := Vector3(-0.5, 1.02, -0.62)
	for k in 6:
		var q := Vector3(-0.5 + 0.12 * k, 0.9 - 0.13 * k + 0.02 * k * k, -0.68 - 0.05 * k)
		_tube(root, prev, q, 0.02, dark, 6)
		prev = q
	_p(root, B.boxm(Vector3(0.08, 0.2, 0.05)), prev + Vector3(0, 0.05, 0), _m(Color(0.75, 0.1, 0.05), 0.5))  # pistooli
	_p(root, B.boxm(Vector3(0.8, 0.06, 0.6)), Vector3(0, 0.03, -0.1), _m(Color(0.3, 0.3, 0.32), 0.5, 0.5))  # tippa-astia
	var sign := B.sign_plate(root, "DIESEL", Color(0.95, 0.8, 0.1), Color(0.08, 0.08, 0.08), 0.18, 40, Color(0.1, 0.1, 0.1))
	sign.position = Vector3(0, 1.4, -0.6)
	_merge(root, "dieselsailio")
	return root


# --- Kivi ---------------------------------------------------------------------------------------------------------

## Pellon kivi (koko = säde m): särmikäs möhkäle (kuusi muunnelmaa, kärkipisteet siirretty kohinalla, tasainen
## varjostus), väri graniitin harmaasta punertavaan ja jäkäläläiskät pisteväreinä. Alaosa maan sisässä.
## parent = null: irrallinen solmu (käteen).
static var _rock_meshes: Array = []


static func kivi(parent: Node3D, size: float, seed: int) -> Node3D:
	var root := Node3D.new()
	if parent != null:
		parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 17
	if _rock_meshes.is_empty():
		for v in 6:
			_rock_meshes.append(_rock_mesh(v))
	var mi := MeshInstance3D.new()
	mi.mesh = _rock_meshes[rng.randi() % _rock_meshes.size()]
	var tints := [Color(0.48, 0.47, 0.45), Color(0.55, 0.47, 0.43), Color(0.4, 0.4, 0.41), Color(0.52, 0.5, 0.46)]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = tints[rng.randi() % tints.size()] * 1.6
	mat.roughness = 0.88
	mi.material_override = mat
	# SphereMeshin säde on 0,5: kerroin 2 tekee säteestä koon.
	mi.scale = Vector3(size * rng.randf_range(1.0, 1.3), size * rng.randf_range(0.6, 0.85), size * rng.randf_range(0.85, 1.1)) * 2.0
	mi.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
	mi.position.y = size * 0.3
	root.add_child(mi)
	return root


static func _rock_mesh(variant: int) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radial_segments = 9
	sm.rings = 6
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var noise := FastNoiseLite.new()
	noise.seed = 31 + variant * 101
	noise.frequency = 3.2  # kärjet säteellä 0,5
	var moved := {}  # sama paikka = sama siirto (saumat pysyvät kiinni)
	for i in verts.size():
		var v := verts[i]
		var key := Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
		if not moved.has(key):
			var n := noise.get_noise_3dv(v * 1.3)
			var flat := 0.75 if v.y < -0.1 else 1.0  # pohja litteämpi
			moved[key] = v * (1.0 + n * 0.38) * Vector3(1.0, flat, 1.0)
		verts[i] = moved[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lich := FastNoiseLite.new()
	lich.seed = 7 + variant
	lich.frequency = 2.2
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var b := verts[idx[t + 1]]
		var c := verts[idx[t + 2]]
		var mid := (a + b + c) / 3.0
		var nrm := (c - a).cross(b - a).normalized()
		if nrm.dot(mid) < 0.0:
			nrm = -nrm  # normaali ulospäin (kiertosuunta pysyy SphereMeshin omana)
		var shade := 0.6 + 0.12 * lich.get_noise_3dv(mid * 3.0)
		var col := Color(shade, shade, shade)
		if lich.get_noise_3dv(mid) > 0.35 and mid.y > -0.1:
			col = Color(shade * 0.95, shade * 1.02, shade * 0.78)  # jäkälä
		for q in [a, b, c]:
			st.set_color(col)
			st.set_normal(nrm)
			st.add_vertex(q)
	return st.commit()


# --- Rakennukset ---------------------------------------------------------------------------------------------------

## Lautaseinä: pystylaudat ja peitelistat (harmaantunut puu), aukko (x0..x1) jätetään pois. Seinä kulkee paikallista
## X:ää pitkin pisteestä a, pituus len, korkeus h, normaali -Z (ulos), seinä on y 0..h.
static func _board_wall(parent: Node3D, a: Vector3, yaw: float, len: float, h: float, base: Color, gap := Vector2(-1, -1),
		gap_h := 0.0) -> void:
	var wall := Node3D.new()
	wall.position = a
	wall.rotation.y = yaw
	parent.add_child(wall)
	var n := int(len / 0.18)
	var w := len / n
	for i in n:
		var x := (i + 0.5) * w
		var bh := h
		var by := 0.0
		if x > gap.x and x < gap.y:
			if gap_h <= 0.0:
				continue
			by = gap_h
			bh = h - gap_h
		# Sävy neljästä tasosta: jokainen eri sävy on oma materiaali ja yhdistetyn meshin pinta.
		var tone := 0.88 + 0.04 * float(int(fposmod(sin(i * 12.9898) * 43758.5453, 1.0) * 4.0))
		var c := Color(base.r * tone, base.g * tone, base.b * tone)
		_p(wall, B.boxm(Vector3(w - 0.012, bh, 0.025)), Vector3(x, by + bh / 2.0, 0), _m(c, 0.92))
		if i % 2 == 0:
			_p(wall, B.boxm(Vector3(0.05, bh, 0.02)), Vector3(x + w / 2.0, by + bh / 2.0, -0.022), _m(c.darkened(0.12), 0.92))


## Harjakatto (harja X-akselilla): kaksi lappeen laattaa, profiilipellin rimat ja harjapelti.
static func _gable_roof(parent: Node3D, center: Vector3, length: float, width: float, rise: float, over: float, col: Color) -> void:
	var tin := _m(col, 0.55, 0.3)
	var half := width / 2.0 + over
	for sz in [-1.0, 1.0]:
		var eave := center + Vector3(0, -over * rise / (width / 2.0), sz * half)
		var ridge := center + Vector3(0, rise, 0)
		V.slab(parent, ridge, eave, length + over * 2.0, 0.03, tin)
		var n := int((length + over * 2.0) / 0.35)
		for i in n + 1:
			var x := -length / 2.0 - over + i * (length + over * 2.0) / n
			var r := V.slab(parent, ridge + Vector3(x, 0.02, 0), eave + Vector3(x, 0.02, 0), 0.025, 0.02, _m(col.darkened(0.15), 0.5, 0.3))
			r.name = "rima"
	_p(parent, B.boxm(Vector3(length + over * 2.0, 0.08, 0.3)), center + Vector3(0, rise + 0.03, 0), _m(col.darkened(0.25), 0.5, 0.3))


## Päätykolmio laudoista (harja X:llä, pääty z-tasossa): kolmio leveys w, korkeus rise, alareuna y0.
static func _gable_end(parent: Node3D, pos: Vector3, yaw: float, w: float, rise: float, base: Color) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = yaw
	parent.add_child(g)
	var n := int(w / 0.18)
	for i in n:
		var x := -w / 2.0 + (i + 0.5) * w / n
		var hh := rise * (1.0 - absf(x) / (w / 2.0))
		if hh < 0.05:
			continue
		var tone := 0.88 + 0.04 * float(int(fposmod(sin(i * 7.31) * 43758.5453, 1.0) * 4.0))
		_p(g, B.boxm(Vector3(w / n - 0.012, hh, 0.025)), Vector3(x, hh / 2.0, 0), _m(Color(base.r * tone, base.g * tone, base.b * tone), 0.92))


## Lato (9 × 6,5 m): harmaantuneet pystylaudat, ruosteinen peltikatto, leveät pariovet auki (-Z), sisällä lattia.
## Palauttaa {"root", "door": oviaukon keskipiste paikallisesti, "stack": paalipinon alku, "body": törmäys}.
static func lato(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	parent.add_child(root)
	var grey := Color(0.48, 0.45, 0.4)
	var L := 9.0
	var W := 6.5
	var H := 3.4
	_p(root, B.boxm(Vector3(L, 0.3, W)), Vector3(0, -0.12, 0), _m(Color(0.42, 0.4, 0.37), 0.95))  # kivijalka
	_p(root, B.boxm(Vector3(L - 0.1, 0.06, W - 0.1)), Vector3(0, 0.03, 0), _m(Color(0.36, 0.3, 0.22), 0.95))  # lattia
	_board_wall(root, Vector3(-L / 2.0, 0, -W / 2.0), 0.0, L, H, grey, Vector2(2.0, 7.0), 0.0)
	_board_wall(root, Vector3(L / 2.0, 0, W / 2.0), PI, L, H, grey)
	_board_wall(root, Vector3(-L / 2.0, 0, W / 2.0), PI / 2.0, W, H, grey)
	_board_wall(root, Vector3(L / 2.0, 0, -W / 2.0), -PI / 2.0, W, H, grey)
	for sx in [-1.0, 1.0]:
		_gable_end(root, Vector3(sx * L / 2.0, H, 0), PI / 2.0, W, 1.8, grey)
	_p(root, B.boxm(Vector3(5.2, 0.18, 0.18)), Vector3(0, H - 0.1, -W / 2.0 - 0.05), _m(grey.darkened(0.3), 0.9))  # ovipalkki
	# Pariovet auki ulospäin.
	for sx in [-1.0, 1.0]:
		var door := Node3D.new()
		door.position = Vector3(sx * 2.5, 0, -W / 2.0)
		door.rotation.y = sx * -1.9
		root.add_child(door)
		_board_wall(door, Vector3(0 if sx < 0 else -2.45, 0.05, 0), 0.0, 2.45, H - 0.25, grey.darkened(0.05))
		_beam(door, Vector3(0.1 if sx < 0 else -0.1, 0.4, -0.04), Vector3(2.3 if sx < 0 else -2.3, H - 0.6, -0.04), 0.1, 0.03, _m(grey.darkened(0.2), 0.9))
	_gable_roof(root, Vector3(0, H, 0), L, W, 1.8, 0.45, Color(0.45, 0.24, 0.15))
	_merge(root, "lato")
	var body := StaticBody3D.new()
	root.add_child(body)
	body.add_child(B.box_shape(Vector3(L, H, 0.2), Vector3(0, H / 2.0, W / 2.0)))
	for sx in [-1.0, 1.0]:
		body.add_child(B.box_shape(Vector3(0.2, H, W), Vector3(sx * L / 2.0, H / 2.0, 0)))
		body.add_child(B.box_shape(Vector3(2.0, H, 0.2), Vector3(sx * 3.5, H / 2.0, -W / 2.0)))
	return {"root": root, "door": Vector3(0, 0, -W / 2.0), "stack": Vector3(-3.6, 0, 2.2), "body": body}


## Konevaja (14 × 7 m): avoin etusivu (-Z) pilareineen, lautaseinät, pulpettikatto punaista peltiä, sorapohja,
## höylä- ja työpenkki, öljytynnyrit ja siemensäkit lavalla. Palauttaa {"root", "seed": siemensäkkien paikka}.
static func konevaja(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	parent.add_child(root)
	var wood := Color(0.55, 0.36, 0.22)
	var L := 14.0
	var W := 7.0
	var Hf := 3.6
	var Hb := 2.9
	_p(root, B.boxm(Vector3(L, 0.05, W)), Vector3(0, 0.01, 0), _m(Color(0.42, 0.39, 0.34), 0.97))
	_board_wall(root, Vector3(L / 2.0, 0, W / 2.0), PI, L, Hb, wood)
	_board_wall(root, Vector3(-L / 2.0, 0, W / 2.0), PI / 2.0, W, Hb, wood)
	_board_wall(root, Vector3(L / 2.0, 0, -W / 2.0), -PI / 2.0, W, Hb, wood)
	for i in 6:
		var x := -L / 2.0 + 0.1 + i * (L - 0.2) / 5.0
		_p(root, B.boxm(Vector3(0.16, Hf, 0.16)), Vector3(x, Hf / 2.0, -W / 2.0 + 0.1), _m(wood.darkened(0.15), 0.9))
	_p(root, B.boxm(Vector3(L, 0.22, 0.16)), Vector3(0, Hf - 0.1, -W / 2.0 + 0.1), _m(wood.darkened(0.15), 0.9))
	var roof_a := Vector3(-L / 2.0 - 0.4, Hf + 0.05, -W / 2.0 - 0.6)
	var tin := _m(Color(0.6, 0.12, 0.08), 0.5, 0.3)
	V.slab(root, Vector3(0, Hf + 0.05, -W / 2.0 - 0.6), Vector3(0, Hb + 0.05, W / 2.0 + 0.4), L + 0.8, 0.03, tin)
	for i in int((L + 0.8) / 0.35) + 1:
		var x := roof_a.x + i * 0.35
		V.slab(root, Vector3(x, Hf + 0.07, -W / 2.0 - 0.6), Vector3(x, Hb + 0.07, W / 2.0 + 0.4), 0.025, 0.02, _m(Color(0.5, 0.1, 0.07), 0.5, 0.3))
	# Työpenkki, ruuvipenkki ja öljytynnyrit takanurkassa.
	_p(root, B.boxm(Vector3(2.2, 0.06, 0.7)), Vector3(4.5, 0.9, W / 2.0 - 0.5), _m(Color(0.5, 0.38, 0.24), 0.8))
	for sx in [-1.0, 1.0]:
		_p(root, B.boxm(Vector3(0.07, 0.9, 0.6)), Vector3(4.5 + sx * 1.0, 0.45, W / 2.0 - 0.5), _m(Color(0.4, 0.3, 0.2), 0.8))
	_p(root, B.boxm(Vector3(0.18, 0.14, 0.22)), Vector3(5.3, 1.0, W / 2.0 - 0.5), _m(Color(0.2, 0.3, 0.5), 0.5, 0.5))
	for k in 3:
		_p(root, B.cyl(0.29, 0.29, 0.88, 16), Vector3(6.2 - k * 0.0, 0.44, W / 2.0 - 0.45 - k * 0.65), _m([Color(0.1, 0.3, 0.6), Color(0.15, 0.4, 0.15), Color(0.7, 0.1, 0.05)][k], 0.5, 0.4))
	# Siemensäkit lavalla (kaksi suursäkkiä) etukulmassa.
	var seed := Vector3(-5.6, 0, -1.6)
	_p(root, B.boxm(Vector3(1.2, 0.14, 1.0)), seed + Vector3(0, 0.07, 0), _m(Color(0.62, 0.5, 0.34), 0.9))
	for sx in [-0.3, 0.3]:
		_p(root, B.boxm(Vector3(0.55, 0.85, 0.85)), seed + Vector3(sx, 0.57, 0), _m(Color(0.92, 0.92, 0.88), 0.8))
		for lx in [-0.18, 0.18]:
			_tube(root, seed + Vector3(sx + lx, 1.0, 0), seed + Vector3(sx + lx, 1.18, 0), 0.025, _m(Color(0.2, 0.35, 0.65), 0.7))
	_merge(root, "konevaja")
	var body := StaticBody3D.new()
	root.add_child(body)
	body.add_child(B.box_shape(Vector3(L, Hb, 0.2), Vector3(0, Hb / 2.0, W / 2.0)))
	for sx in [-1.0, 1.0]:
		body.add_child(B.box_shape(Vector3(0.2, Hb, W), Vector3(sx * L / 2.0, Hb / 2.0, 0)))
	# Katto törmäyksenä: kameran säde (cam_ctl.gd) pysähtyy katon alle, kun traktori peruuttaa suulle kytkemään konetta.
	var r0 := Vector3(0, Hf + 0.05, -W / 2.0 - 0.6)
	var r1 := Vector3(0, Hb + 0.05, W / 2.0 + 0.4)
	var roof := B.box_shape(Vector3(L + 0.8, 0.12, r0.distance_to(r1)), (r0 + r1) / 2.0)
	roof.rotation.x = atan2(r0.y - r1.y, r1.z - r0.z)  # +X-kierto laskee +Z:n päätä (takaräystäs matalammalla)
	body.add_child(roof)
	return {"root": root, "seed": seed}


## Viljankuivuri: punainen lautarakennus valkoisin nurkkalaudoin, korkea elevaattori kuljetinpäineen, uuni ja
## piippu kyljessä, edessä vastaanottosuppilo (betonilaatta ja ritilä). Palauttaa {"root", "pit": suppilon
## keskipiste paikallisesti}.
static func kuivuri(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	parent.add_child(root)
	var red := Color(0.55, 0.12, 0.08)
	var white := _m(Color(0.92, 0.9, 0.84), 0.8)
	var L := 6.0
	var W := 5.0
	var H := 5.2
	_p(root, B.boxm(Vector3(L + 0.2, 0.35, W + 0.2)), Vector3(0, -0.1, 0), _m(Color(0.55, 0.55, 0.53), 0.95))
	_board_wall(root, Vector3(-L / 2.0, 0, -W / 2.0), 0.0, L, H, red, Vector2(2.2, 3.4), 2.2)
	_board_wall(root, Vector3(L / 2.0, 0, W / 2.0), PI, L, H, red)
	_board_wall(root, Vector3(-L / 2.0, 0, W / 2.0), PI / 2.0, W, H, red)
	_board_wall(root, Vector3(L / 2.0, 0, -W / 2.0), -PI / 2.0, W, H, red)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_p(root, B.boxm(Vector3(0.14, H, 0.14)), Vector3(sx * (L / 2.0 + 0.02), H / 2.0, sz * (W / 2.0 + 0.02)), white)
		_gable_end(root, Vector3(sx * L / 2.0, H, 0), PI / 2.0, W, 1.6, red)
	_p(root, B.boxm(Vector3(1.2, 2.2, 0.05)), Vector3(-0.2, 1.1, -W / 2.0 - 0.02), _m(Color(0.35, 0.1, 0.06), 0.9))  # ovi
	_p(root, B.boxm(Vector3(1.3, 0.08, 0.08)), Vector3(-0.2, 2.24, -W / 2.0 - 0.04), white)
	_gable_roof(root, Vector3(0, H, 0), L, W, 1.6, 0.4, Color(0.18, 0.18, 0.2))
	# Elevaattori: kaksi kuljetinputkea ja pää, kouru katolle.
	var ex := L / 2.0 + 0.6
	_p(root, B.boxm(Vector3(0.5, 9.2, 0.35)), Vector3(ex, 4.6, -1.2), _m(Color(0.7, 0.7, 0.72), 0.4, 0.6))
	_p(root, B.boxm(Vector3(0.8, 0.8, 0.6)), Vector3(ex, 9.4, -1.2), _m(Color(0.7, 0.7, 0.72), 0.4, 0.6))
	_tube(root, Vector3(ex - 0.3, 9.2, -1.2), Vector3(0.5, H + 1.5, -1.2), 0.12, _m(Color(0.7, 0.7, 0.72), 0.4, 0.6))
	for i in 8:
		_p(root, B.boxm(Vector3(0.6, 0.04, 0.45)), Vector3(ex, 1.0 + i * 1.1, -1.2), _m(Color(0.5, 0.5, 0.52), 0.4, 0.6))
	# Uuni ja piippu.
	_p(root, B.boxm(Vector3(1.4, 1.6, 1.4)), Vector3(0.8, 0.8, W / 2.0 + 0.75), _m(Color(0.35, 0.35, 0.37), 0.5, 0.5))
	_p(root, B.cyl(0.16, 0.16, 6.0, 12), Vector3(1.2, 3.8, W / 2.0 + 1.0), _m(Color(0.15, 0.15, 0.16), 0.6, 0.4))
	# Vastaanottosuppilo: betonilaatta, ritilä ja kehys.
	var pit := Vector3(ex + 1.8, 0, -1.2)
	_p(root, B.boxm(Vector3(2.6, 0.12, 2.4)), pit + Vector3(0, 0.0, 0), _m(Color(0.6, 0.6, 0.58), 0.95))
	_p(root, B.boxm(Vector3(2.0, 0.02, 1.8)), pit + Vector3(0, 0.05, 0), _m(Color(0.05, 0.05, 0.05), 0.9))
	for i in 12:
		_p(root, B.boxm(Vector3(0.03, 0.04, 1.8)), pit + Vector3(-0.95 + i * 0.172, 0.07, 0), _m(Color(0.3, 0.3, 0.32), 0.5, 0.6))
	_p(root, B.boxm(Vector3(0.05, 0.04, 1.8)), pit + Vector3(0, 0.08, 0), _m(Color(0.3, 0.3, 0.32), 0.5, 0.6), Vector3(0, 90, 0))
	_merge(root, "kuivuri")
	var body := StaticBody3D.new()
	root.add_child(body)
	body.add_child(B.box_shape(Vector3(L, H, W), Vector3(0, H / 2.0, 0)))
	body.add_child(B.box_shape(Vector3(0.6, 9.0, 0.5), Vector3(ex, 4.5, -1.2)))
	return {"root": root, "pit": pit}


# --- Päärakennus ---------------------------------------------------------------------------------------------------

## Lankku tai laatta p0 -> p1 (pituus), leveys wdir:n suuntaan (kohtisuoraan pituuteen), paksuus näiden normaalina.
static func _plank(parent: Node3D, p0: Vector3, p1: Vector3, wdir: Vector3, width: float, thick: float, mat: Material) -> MeshInstance3D:
	var z := (p1 - p0).normalized()
	var x := (wdir - z * wdir.dot(z)).normalized()
	var y := z.cross(x).normalized()
	var mi := _p(parent, B.boxm(Vector3(width, thick, p0.distance_to(p1))), (p0 + p1) / 2.0, mat)
	mi.basis = Basis(x, y, z)
	return mi


## Laatikko seinän tasossa: size = (seinän suunnassa, ylös, ulos), n = seinän ulkonormaali (vaakasuora).
static func _wbox(parent: Node3D, c: Vector3, n: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var r := Vector3.UP.cross(n)  # oikeakätinen kanta (r, ylös, n): laatikko ei peilaudu
	var mi := _p(parent, B.boxm(size), c, mat)
	mi.basis = Basis(r, Vector3.UP, n)
	return mi


## Kuusiruutuinen ikkuna: valkoiset vuorilaudat ja otsalauta, kaksi puitetta (kolme ruutua kumpikin), tumma lasi
## ja ikkunapelti. c = lasin keskipiste seinän pinnassa, n = ulkonormaali.
static func _window(parent: Node3D, c: Vector3, n: Vector3, w: float, h: float, trim: Material, glass: Material) -> void:
	var r := Vector3.UP.cross(n)
	var up := Vector3.UP
	_wbox(parent, c + n * 0.01, n, Vector3(w - 0.04, h - 0.04, 0.02), glass)
	for s in [-1.0, 1.0]:
		_wbox(parent, c + up * s * (h / 2.0 + 0.06) + n * 0.025, n, Vector3(w + 0.24, 0.12, 0.05), trim)
		_wbox(parent, c + r * s * (w / 2.0 + 0.06) + n * 0.025, n, Vector3(0.12, h + 0.24, 0.05), trim)
		_wbox(parent, c + up * s * (h / 2.0 - 0.025) + n * 0.02, n, Vector3(w, 0.05, 0.03), trim)  # puitteen ylä- ja alaosa
		_wbox(parent, c + r * s * (w / 2.0 - 0.025) + n * 0.02, n, Vector3(0.05, h, 0.03), trim)
		_wbox(parent, c + up * s * h / 6.0 + n * 0.02, n, Vector3(w, 0.03, 0.025), trim)  # välipuitteet
	_wbox(parent, c + n * 0.02, n, Vector3(0.07, h, 0.03), trim)  # puitteiden väli
	_wbox(parent, c + up * (h / 2.0 + 0.16) + n * 0.045, n, Vector3(w + 0.4, 0.07, 0.09), trim)  # otsalauta
	_wbox(parent, c - up * (h / 2.0 + 0.13) + n * 0.055, n, Vector3(w + 0.3, 0.04, 0.11), trim)  # ikkunapenkki


## Kaisuan päärakennus (OSM 1074444651, harja laserista): puolitoistakerroksinen keltamullattu hirsitalo
## vaakalaudoituksella, valkoiset nurkkalaudat, räystäslaudat ja kuusiruutuiset ikkunat, kivijalka, punainen
## peltikatto, kaksi tiilipiippua ja pihan puolella lasikuisti portaineen. Kehys: X pituus, -Z pihan puoli, y = 0
## lattia (kivijalan yläpinta). floor_drop = kuinka paljon maa on lattian alapuolella talon kohdalla (alin kohta),
## step_drop = maa kuistin portaiden kohdalla. Palauttaa {"root", "door": portaiden edusta, "body"}.
static func paarakennus(parent: Node3D, L: float, W: float, ridge: float, door_x: float, floor_drop: float, step_drop: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "Paarakennus"
	parent.add_child(root)
	var wall_c := Color(0.86, 0.66, 0.3)
	var wall := _m(wall_c, 0.9)
	var line := _m(wall_c.darkened(0.22), 0.9)
	var trim := _m(Color(0.93, 0.91, 0.85), 0.75)
	var glass := _m(Color(0.1, 0.14, 0.18), 0.08, 0.7)
	var roof_c := Color(0.5, 0.13, 0.09)
	var brick := _m(Color(0.5, 0.22, 0.15), 0.95)
	var stone := Color(0.5, 0.49, 0.46)
	var wall_h := 3.6
	var rise := clampf(ridge - 0.45 - wall_h, 2.4, 4.0)
	var over := 0.5
	# Kivijalka: harmaa pohja ja lohkareet kahdessa rivissä (sävyt neljästä tasosta).
	var base_h := floor_drop + 0.3
	_p(root, B.boxm(Vector3(L + 0.1, base_h, W + 0.1)), Vector3(0, -base_h / 2.0, 0), _m(stone.darkened(0.25), 0.95))
	var k := 0
	for side in 4:
		var n: Vector3 = [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT][side]
		var span := L if side < 2 else W
		var off := (W if side < 2 else L) / 2.0 + 0.06
		var r := Vector3.UP.cross(n)
		for row in 2:
			var x := -span / 2.0
			while x < span / 2.0 - 0.1:
				var sw := 0.45 + 0.35 * fposmod(sin(k * 3.7) * 91.3, 1.0)
				sw = minf(sw, span / 2.0 - x)
				var tone := 0.86 + 0.06 * float(int(fposmod(sin(k * 12.9898) * 43758.5453, 1.0) * 4.0))
				var sh := 0.24 - 0.04 * fposmod(sin(k * 5.1) * 17.0, 1.0)
				_wbox(root, n * off + r * (x + sw / 2.0) + Vector3.UP * (-0.14 - row * 0.27), n, Vector3(sw - 0.04, sh, 0.12),
					_m(Color(stone.r * tone, stone.g * tone, stone.b * tone), 0.95))
				x += sw
				k += 1
	# Seinät: runko, laudoituksen varjoviivat 16 cm välein, nurkkalaudat, räystäs- ja sokkelilaudat.
	_p(root, B.boxm(Vector3(L, wall_h, W)), Vector3(0, wall_h / 2.0, 0), wall)
	var y := 0.16
	while y < wall_h - 0.2:
		for sz in [-1.0, 1.0]:
			_p(root, B.boxm(Vector3(L, 0.014, 0.012)), Vector3(0, y, sz * (W / 2.0 + 0.004)), line)
		for sx in [-1.0, 1.0]:
			_p(root, B.boxm(Vector3(0.012, 0.014, W)), Vector3(sx * (L / 2.0 + 0.004), y, 0), line)
		y += 0.16
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_p(root, B.boxm(Vector3(0.18, wall_h, 0.18)), Vector3(sx * L / 2.0, wall_h / 2.0, sz * W / 2.0), trim)
		_p(root, B.boxm(Vector3(L + 0.12, 0.24, 0.05)), Vector3(0, wall_h - 0.12, sx * (W / 2.0 + 0.03)), trim)
		_p(root, B.boxm(Vector3(L + 0.12, 0.14, 0.05)), Vector3(0, 0.07, sx * (W / 2.0 + 0.03)), trim)
		_p(root, B.boxm(Vector3(0.05, 0.14, W + 0.12)), Vector3(sx * (L / 2.0 + 0.03), 0.07, 0), trim)
	# Päätykolmiot (ullakko) ja niiden laudoitus, tuulilaudat valkoiset.
	var attic := PrismMesh.new()
	attic.size = Vector3(W, rise, L)
	_p(root, attic, Vector3(0, wall_h + rise / 2.0, 0), wall, Vector3(0, PI / 2.0, 0))
	y = wall_h + 0.16
	while y < wall_h + rise - 0.15:
		var gw := W * (1.0 - (y - wall_h) / rise)
		for sx in [-1.0, 1.0]:
			_p(root, B.boxm(Vector3(0.012, 0.014, gw)), Vector3(sx * (L / 2.0 + 0.004), y, 0), line)
		y += 0.16
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var top := Vector3(sx * (L / 2.0 + over - 0.04), wall_h + rise - 0.06, 0)
			var low := Vector3(sx * (L / 2.0 + over - 0.04), wall_h - over * rise / (W / 2.0) - 0.06, sz * (W / 2.0 + over))
			_plank(root, top, low, Vector3.RIGHT, 0.05, 0.22, trim)
	_gable_roof(root, Vector3(0, wall_h, 0), L, W, rise, over, roof_c)
	# Piiput harjalla: tiiliosa, tummat saumaviivat ja peltihattu.
	for px in [-L * 0.2, L * 0.24]:
		var py := wall_h + rise
		_p(root, B.boxm(Vector3(0.62, 1.9, 0.62)), Vector3(px, py + 0.35, 0), brick)
		for i in 4:
			_p(root, B.boxm(Vector3(0.64, 0.02, 0.64)), Vector3(px, py + 0.3 + i * 0.22, 0), _m(Color(0.3, 0.14, 0.1), 0.95))
		_p(root, B.boxm(Vector3(0.76, 0.08, 0.76)), Vector3(px, py + 1.34, 0), _m(Color(0.16, 0.16, 0.17), 0.6, 0.4))
	# Ikkunat: pihan puolella kuistin molemmin puolin, takana tasaisesti, päädyissä kaksi alhaalla ja ullakolla kaksi.
	var wy := 0.9 + 1.35 / 2.0
	for x in [-7.2, -5.0, -2.8, -0.6, 1.6, 3.8, 6.0, 7.4]:
		if absf(x - door_x) < 2.5 or absf(x) > L / 2.0 - 0.9:
			continue
		_window(root, Vector3(x, wy, -W / 2.0 - 0.004), Vector3.FORWARD, 1.0, 1.35, trim, glass)
	for x in [-6.4, -3.6, -0.8, 2.0, 4.8, 6.9]:
		if absf(x) > L / 2.0 - 0.9:
			continue
		_window(root, Vector3(x, wy, W / 2.0 + 0.004), Vector3.BACK, 1.0, 1.35, trim, glass)
	for sx in [-1.0, 1.0]:
		var n: Vector3 = Vector3.RIGHT * sx
		for z in [-1.9, 1.9]:
			_window(root, Vector3(sx * (L / 2.0 + 0.004), wy, z), n, 1.0, 1.35, trim, glass)
			_window(root, Vector3(sx * (L / 2.0 + 0.004), wall_h + 0.85, z * 0.55), n, 0.7, 0.95, trim, glass)
	# Lasikuisti ovella: laudoitettu alaosa, monijakoiset ikkunat valkoisin puittein, oma harjakatto (harja Z:lla
	# päärakennuksen räystään alla), pariovi lasiaukoin, portaat maahan ja lyhty oven yllä.
	var PW := 3.2
	var PD := 2.3
	var PH := 2.5
	var pr := 0.62
	var pz := -W / 2.0 - PD / 2.0
	var pc := Vector3(door_x, 0, pz)
	_p(root, B.boxm(Vector3(PW + 0.1, base_h, PD + 0.05)), pc + Vector3(0, -base_h / 2.0, 0), _m(stone.darkened(0.15), 0.95))
	_p(root, B.boxm(Vector3(PW, 0.9, PD)), pc + Vector3(0, 0.45, 0), wall)
	_p(root, B.boxm(Vector3(PW, 0.36, PD)), pc + Vector3(0, PH - 0.18, 0), wall)
	_p(root, B.boxm(Vector3(PW - 0.1, PH - 1.26, PD - 0.1)), pc + Vector3(0, 0.9 + (PH - 1.26) / 2.0, 0), glass)
	for yy in [0.92, PH - 0.37, 0.9 + (PH - 1.26) * 0.62]:
		_p(root, B.boxm(Vector3(PW + 0.04, 0.06, PD + 0.04)), pc + Vector3(0, yy, 0), trim)
	for i in 7:
		var x := -PW / 2.0 + i * PW / 6.0
		_p(root, B.boxm(Vector3(0.07, PH - 1.26, 0.07)), pc + Vector3(x, 0.9 + (PH - 1.26) / 2.0, -PD / 2.0 + 0.01), trim)
	for sx in [-1.0, 1.0]:
		for i in 5:
			var z := -PD / 2.0 + i * PD / 4.0
			_p(root, B.boxm(Vector3(0.07, PH - 1.26, 0.07)), pc + Vector3(sx * PW / 2.0, 0.9 + (PH - 1.26) / 2.0, z), trim)
		_p(root, B.boxm(Vector3(0.12, PH, 0.12)), pc + Vector3(sx * PW / 2.0, PH / 2.0, -PD / 2.0), trim)
	y = 0.16
	while y < 0.85:
		_p(root, B.boxm(Vector3(PW, 0.014, 0.012)), pc + Vector3(0, y, -PD / 2.0 - 0.004), line)
		for sx in [-1.0, 1.0]:
			_p(root, B.boxm(Vector3(0.012, 0.014, PD)), pc + Vector3(sx * (PW / 2.0 + 0.004), y, 0), line)
		y += 0.16
	# Kuistin katto: lappeet X-suunnassa, päätykolmio edessä, tuulilaudat.
	var p_ridge := pc + Vector3(0, PH + pr, 0)
	var pf := -PD / 2.0 - 0.35
	var pb := PD / 2.0
	for sx in [-1.0, 1.0]:
		var e0 := pc + Vector3(sx * (PW / 2.0 + 0.3), PH - 0.3 * pr / (PW / 2.0), 0)
		_plank(root, Vector3(p_ridge.x, p_ridge.y, pz + (pf + pb) / 2.0), Vector3(e0.x, e0.y, pz + (pf + pb) / 2.0), Vector3.BACK,
			pb - pf, 0.03, _m(roof_c, 0.55, 0.3))
		for i in 8:
			var z := pz + pf + (i + 0.5) * (pb - pf) / 8.0
			_plank(root, Vector3(p_ridge.x, p_ridge.y + 0.02, z), Vector3(e0.x, e0.y + 0.02, z), Vector3.BACK, 0.025, 0.02, _m(roof_c.darkened(0.15), 0.5, 0.3))
		_plank(root, Vector3(p_ridge.x, p_ridge.y - 0.05, pz + pf + 0.03), Vector3(e0.x, e0.y - 0.05, pz + pf + 0.03), Vector3.BACK, 0.05, 0.18, trim)
	_p(root, B.boxm(Vector3(0.24, 0.08, pb - pf)), Vector3(p_ridge.x, p_ridge.y + 0.03, pz + (pf + pb) / 2.0), _m(roof_c.darkened(0.25), 0.5, 0.3))
	var pg := PrismMesh.new()
	pg.size = Vector3(PW, pr, 0.1)
	_p(root, pg, pc + Vector3(0, PH + pr / 2.0, -PD / 2.0 + 0.05), wall)
	# Ovi: kaksi lehteä peiliovina, yläosassa lasi, kahvat ja vuorilaudat.
	var dz := -W / 2.0 - PD - 0.02
	var door_c := _m(Color(0.32, 0.22, 0.14), 0.7)
	for sx in [-1.0, 1.0]:
		var dc := Vector3(door_x + sx * 0.235, 1.05, dz)
		_p(root, B.boxm(Vector3(0.45, 2.1, 0.05)), dc, door_c)
		_p(root, B.boxm(Vector3(0.3, 0.5, 0.02)), dc + Vector3(0, 0.55, -0.03), glass)
		_p(root, B.boxm(Vector3(0.3, 0.6, 0.02)), dc + Vector3(0, -0.4, -0.03), _m(Color(0.28, 0.19, 0.12), 0.7))
		_p(root, B.boxm(Vector3(0.03, 0.12, 0.04)), dc + Vector3(-sx * 0.17, -0.05, -0.05), _m(Color(0.75, 0.68, 0.4), 0.3, 0.8))
		_p(root, B.boxm(Vector3(0.12, 2.25, 0.06)), Vector3(door_x + sx * 0.53, 1.12, dz - 0.01), trim)
	_p(root, B.boxm(Vector3(1.18, 0.14, 0.07)), Vector3(door_x, 2.2, dz - 0.01), trim)
	_p(root, B.boxm(Vector3(0.14, 0.2, 0.14)), Vector3(door_x + 0.75, 2.05, dz - 0.08), _m(Color(0.12, 0.12, 0.12), 0.5, 0.4))
	_p(root, B.cyl(0.05, 0.05, 0.12, 10), Vector3(door_x + 0.75, 1.96, dz - 0.08), V.lamp(Color(1.0, 0.86, 0.6)))
	# Portaat maahan (harmaa betoni), reunoilla kukkaruukut.
	var steps := maxi(1, ceili(step_drop / 0.18))  # nousuja; viimeinen nousu laskeutuu maahan
	var rise_s := step_drop / steps
	for i in steps - 1:
		var top := -rise_s * (i + 1)
		var sd := 0.32
		var sz2 := dz - 0.05 - sd * (i + 0.5)
		_p(root, B.boxm(Vector3(1.5, top + step_drop + 0.3, sd)), Vector3(door_x, (top - step_drop - 0.3) / 2.0, sz2), _m(Color(0.6, 0.6, 0.58), 0.95))
	for sx in [-1.0, 1.0]:
		var pot := Vector3(door_x + sx * 0.62, -rise_s, dz - 0.05 - 0.16)
		_p(root, B.cyl(0.13, 0.1, 0.22, 12), pot + Vector3(0, 0.11, 0), _m(Color(0.66, 0.3, 0.16), 0.85))
		_p(root, B.sphere(0.16, 10), pot + Vector3(0, 0.3, 0), _m(Color(0.16, 0.36, 0.12), 0.9))
		for j in 6:
			var a := j * 1.05
			_p(root, B.sphere(0.04, 6), pot + Vector3(cos(a) * 0.11, 0.36 + 0.03 * sin(a * 3.0), sin(a) * 0.11), _m(Color(0.85, 0.1, 0.12), 0.6))
	# Penkki kuistin vieressä seinustalla.
	var bx := door_x + PW / 2.0 + 1.1
	var bz := -W / 2.0 - 0.4
	var gy := -step_drop  # maa kuistin edustalla
	_p(root, B.boxm(Vector3(1.5, 0.05, 0.36)), Vector3(bx, gy + 0.45, bz), _m(Color(0.45, 0.32, 0.2), 0.85))
	_p(root, B.boxm(Vector3(1.5, 0.22, 0.04)), Vector3(bx, gy + 0.75, bz + 0.2), _m(Color(0.45, 0.32, 0.2), 0.85), Vector3(-0.15, 0, 0))
	for sx in [-0.6, 0.6]:
		_p(root, B.boxm(Vector3(0.06, 0.75, 0.32)), Vector3(bx + sx, gy + 0.45 - 0.75 / 2.0 + 0.15, bz), _m(Color(0.38, 0.27, 0.17), 0.85))
	_merge(root, "paarakennus")
	var body := StaticBody3D.new()
	root.add_child(body)
	body.add_child(B.box_shape(Vector3(L, wall_h + rise * 0.6, W), Vector3(0, (wall_h + rise * 0.6) / 2.0, 0)))
	body.add_child(B.box_shape(Vector3(PW, PH, PD), Vector3(door_x, PH / 2.0, pz)))
	return {"root": root, "door": Vector3(door_x, -step_drop, dz - 0.05 - (steps - 1) * 0.32 - 0.6), "body": body}
