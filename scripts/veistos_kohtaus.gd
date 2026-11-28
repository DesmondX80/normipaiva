extends CanvasLayer
## Legendaarinen hetki "pakkahuoneen_veistos" (Pakkahuoneen veistos): kun kellarin luukku avataan ensimmäistä kertaa
## molempien vihjeiden jälkeen (main.gd _pakkahuone_acted "luukku"), hetki lavastetaan Raahen Pakkahuoneen salissa
## (retki_pakkahuone.gd, taskukohtaus). Vaiheet:
##   luukku   pelaaja polvistuu luukulle ja kääntää kunnostajan avainta; kansi narahtaa auki ja kellarista pöllähtää pölyä.
##            Kuraattori kiiruhtaa pöydän takaa: "Avain! Missä se oli?"
##   laatikko kuraattori polvistuu, nostaa kunnostuslaatikon kellarista lattialle, avaa kannen ja nostaa puulastujen
##            seasta pienen puupyhimyksen. Pyyhkii hihalla pölyt kasvoilta: "Siinähän sinä olet."
##   kanto    kuraattori kantaa pyhimyksen itse salin poikki (kävijät väistävät ja kääntyvät katsomaan), nostaa sen
##            jalustalle ja säätää: "Noin. ...Ei. Noin." (huipennus: legendan "kuraattori kantoi sen itse jalustalle")
##   valo     kuraattori kääntää POISSA-kyltin, astuu taaksepäin, ja aurinko osuu ikkunasta pyhimykseen (sädekehä
##            välähtää, pöly leijuu valokeilassa). Kävijät taputtavat hiljaa: "Kolmesataa vuotta se on seissyt tässä."
##   otsikko  "Kiitos. Pakkahuone pitää omansa." PAKKAHUONEEN VEISTOS
## Kehys: museon paikallinen kehys (retki_pakkahuone.gd): -Z takaseinä (ikkunat, veistokset), +Z ovi ja avoin etureuna,
## lattia y 0. Kamerat katsovat aina takaseinää tai sivuseiniä kohti (etureuna on avoin). Hahmojen etu -Z (Looks).
## Oikea pelaaja ja kuraattori piiloon kohtauksen ajaksi (kopiot näyttelevät); museon näyttö odottaa (interior.staged),
## ja main.gd palauttaa sen lopuksi. Kuraattori muistelee myöhemmin (MUISTO, main.gd _pakkahuone_acted).

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")

const RATE := 22050.0
const DUR := {"luukku": 6.0, "laatikko": 7.4, "kanto": 8.4, "valo": 7.0, "otsikko": 6.2}
const ORDER := ["luukku", "laatikko", "kanto", "valo", "otsikko"]

## Kadonneen pyhimyksen jalusta ja mitat (myös retki_pakkahuone.gd käyttää näitä).
const PED_AT := Vector3(4.5, 0, -3.9)
const PED_H := 0.9
const BASE := Vector3(0.18, 0.05, 0.15)  # pyhimyksen jalka
const SAINT_H := 0.6
const HATCH := Vector3(-5.0, 0, 1.0)  # kellarin luukun keskusta (1 x 1 m), sarana z 0.5
const KEYHOLE := Vector3(-5.0, 0.1, 1.38)  # avaimenreikä kannen etureunassa (pelaajan puolella)
const ME_KNEEL := Vector2(-5.0, 1.74)
const ME_ASIDE := Vector2(-3.55, 1.45)
const CUR_DESK := Vector2(-2.5, -3.6)
const CUR_KNEEL := Vector2(-5.0, 1.78)
const CRATE := Vector3(0.48, 0.28, 0.3)
const CRATE_FLOOR := Vector3(-4.35, 0, 1.85)
const CUR_STAND := Vector2(-4.75, 2.3)
const CUR_PED := Vector2(5.08, -3.85)  # jalustan itäpuolella, kasvot jalustaan (kamera näkee kasvot)
const PLATE_AT := Vector2(4.12, -2.95)  # kyltin kääntö jalustan edestä
const PLATE := Vector3(4.5, 0.56, -3.585)  # kyltti jalustan etupinnassa
const CUR_BACK := Vector2(3.75, -3.05)  # jalustan vasemmalla, kasvot pyhimykseen (kamera idästä näkee kasvot)
const ME_PED := Vector2(2.85, -2.3)
const ME_WAIT := Vector2(2.4, -1.4)  # pelaaja odottaa kannon ajan sivussa (ei jalustakuvan edessä)
const VIS1 := Vector2(1.55, -2.45)
const VIS2 := Vector2(0.55, -2.25)
const VIS1_BACK := Vector2(1.95, -3.05)  # kävijät väistävät seinän viereen
const VIS2_BACK := Vector2(1.05, -2.85)
const VIS1_SUN := Vector2(2.95, -3.4)  # auringon aikaan kävijät tulevat lähemmäs katsomaan
const VIS2_SUN := Vector2(2.45, -3.0)
const WINDOW := Vector3(5.5, 2.05, -4.75)

## Kuraattori (retki_pakkahuone.gd): viininpunainen paita, siili, nyt pyöreät lasit kuten museoväellä.
const CURATOR := {"shirt": Color(0.5, 0.25, 0.3), "pants": Color(0.25, 0.25, 0.3), "shoes": Color(0.15, 0.12, 0.1),
	"shoe": "nauhakenka", "hair": "Hair_Buzzed", "hair_color": Color(0.35, 0.3, 0.28), "height": 1.66}
const VISITOR1 := {"shirt": Color(0.35, 0.5, 0.65), "pants": Color(0.3, 0.28, 0.25), "shoes": Color(0.3, 0.2, 0.12),
	"hair": "Hair_Buzzed", "hair_color": Color(0.85, 0.85, 0.82), "height": 1.74, "belly": 0.25}
const VISITOR2 := {"shirt": Color(0.75, 0.55, 0.6), "pants": Color(0.3, 0.3, 0.38), "shoes": Color(0.25, 0.18, 0.12),
	"hair": "Hair_Buns", "hair_color": Color(0.8, 0.78, 0.75), "height": 1.62, "skirt": Color(0.3, 0.32, 0.45)}
## Kuraattori muistelee myöhemmin (main.gd _pakkahuone_acted "kuraattori").
const MUISTO := ["Muistatko, kun kannoin sen salin poikki? Kädet tärisi koko illan. Ei se ole painava, mutta se on vanha.",
	"Kävijät kysyy, miksi tuo pieni pyhimys on niin kiiltävä. Minä pyyhin sen joka aamu. Viikko kellarissa riitti.",
	"Kunnostaja soitti perjantaina ja kysyi, missä avain on. Minä sanoin, että vierailijakirjassa. Siellä se on nyt aina.",
	"Aurinko osuu siihen joka päivä kolmelta. Ennen en ollut huomannut. Nyt huomaan."]

var interior: Node3D  # retki_pakkahuone.gd
var _was_visible := {}

var phase := ""
var _t := 0.0
var _cam: Camera3D
var _ui: Control
var _keys: Node
var _story := ""
var _bub := {}
var _once := {}
var _props: Array[Node3D] = []
var me: Node3D
var curator: Node3D
var vis1: Node3D
var vis2: Node3D
var saint: Node3D
var crate: Node3D
var crate_lid: Node3D
var key: Node3D
var _dust: CPUParticles3D
var _motes: CPUParticles3D
var _sun: SpotLight3D
var _fill: OmniLight3D
var _glint := 0.0
var _audio: AudioStreamPlayer
var _ladder: Node3D
var _plate_rig: Node3D
var _beam: MeshInstance3D
var saint_placed := false  # testi lukee
var plate_turned := false


func _ready() -> void:
	layer = 6
	_cam = Camera3D.new()
	interior.add_child(_cam)
	_props.append(_cam)
	_cam.make_current()
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_keys.set_text("%s ohita" % Settings.cap("interact"))
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	# Museon lattiakyltit ovat pelin yläkameraa varten (vinossa lattialla): kohtauksessa jalustan etupinnan kyltti.
	for nd in [interior.walker, interior._curator, interior._special, interior._plate_on, interior._plate_off, interior._footprint]:
		_was_visible[nd] = (nd as Node3D).visible
		(nd as Node3D).visible = false
	interior._footprint.visible = true
	interior._lid.rotation_degrees.x = 0.0
	_build()
	_begin("luukku")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	me = Looks.make(interior, Looks.player())
	Looks.add_cap(me)
	curator = Looks.make(interior, CURATOR)
	Looks.add_round_glasses(curator, CURATOR.height / 1.8)
	vis1 = Looks.make(interior, VISITOR1)
	vis2 = Looks.make(interior, VISITOR2)
	for c in [me, curator, vis1, vis2]:
		_props.append(c)
	saint = build_saint(interior)
	_props.append(saint)
	crate = _build_crate()
	key = _build_key()
	# Avaimenreiän messinkilaatta kannessa (kääntyy kannen mukana).
	var esc := Node3D.new()
	interior._lid.add_child(esc)
	_props.append(esc)
	esc.position = Vector3(0, 0.031, KEYHOLE.z - 0.5)
	var e1 := B.mesh(esc, B.boxm(Vector3(0.05, 0.004, 0.075)), Vector3.ZERO, Color(0.8, 0.62, 0.28))
	e1.material_override = _metal(Color(0.8, 0.62, 0.28))
	B.mesh(esc, B.boxm(Vector3(0.006, 0.005, 0.02)), Vector3(0, 0.001, 0), Color(0.05, 0.04, 0.03))
	# Jalustan kyltti: POISSA edessä, oikea kyltti takana; kuraattori kääntää telineen.
	_plate_rig = Node3D.new()
	interior.add_child(_plate_rig)
	_props.append(_plate_rig)
	_plate_rig.position = PLATE
	var off := B.sign_plate(_plate_rig, "POISSA\nKysy kuraattorilta", Color(0.9, 0.82, 0.8), Color(0.5, 0.1, 0.1), 0.2, 44, Color(0.5, 0.15, 0.15))
	off.scale = Vector3.ONE * 0.24
	off.position = Vector3(0, 0, 0.012)
	var on := B.sign_plate(_plate_rig, "PUUPYHIMYS\n1600-luku (kuulemma)", Color(0.95, 0.93, 0.82), Color(0.15, 0.12, 0.1), 0.2, 44, Color(0.45, 0.3, 0.17))
	on.scale = Vector3.ONE * 0.24
	on.position = Vector3(0, 0, -0.012)
	on.rotation.y = PI
	# Kellarin aukko: tikkaiden yläpäät pistävät luukusta (kuin oikeissa kellareissa), aukon reunalista.
	var hole := Node3D.new()
	hole.position = HATCH
	interior.add_child(hole)
	_props.append(hole)
	var lad := Color(0.42, 0.3, 0.18)
	_ladder = Node3D.new()
	hole.add_child(_ladder)
	_ladder.visible = false
	for sx in [-0.2, 0.2]:
		B.mesh(_ladder, B.boxm(Vector3(0.05, 0.42, 0.05)), Vector3(sx, 0.17, -0.3), lad, Vector3(12, 0, 0))
	B.mesh(_ladder, B.boxm(Vector3(0.44, 0.03, 0.04)), Vector3(0, 0.02, -0.3), lad.darkened(0.2))
	for e in [[Vector3(1.06, 0.025, 0.04), Vector3(0, 0.012, 0.51)], [Vector3(1.06, 0.025, 0.04), Vector3(0, 0.012, -0.51)],
			[Vector3(0.04, 0.025, 1.0), Vector3(0.51, 0.012, 0)], [Vector3(0.04, 0.025, 1.0), Vector3(-0.51, 0.012, 0)]]:
		B.mesh(hole, B.boxm(e[0]), e[1], Color(0.3, 0.2, 0.12))
	# Pöly kellarista kannen auetessa.
	_dust = CPUParticles3D.new()
	interior.add_child(_dust)
	_props.append(_dust)
	_dust.position = HATCH + Vector3(0, 0.16, 0)
	var dm := QuadMesh.new()
	dm.size = Vector2(0.3, 0.3)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.78, 0.72, 0.62, 0.55)
	dmat.albedo_texture = _soft_tex()
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.billboard_keep_scale = true
	dmat.no_depth_test = false
	dm.material = dmat
	_dust.mesh = dm
	_dust.amount = 70
	_dust.lifetime = 2.2
	_dust.one_shot = true
	_dust.explosiveness = 0.8
	_dust.emitting = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.42, 0.02, 0.42)
	_dust.direction = Vector3.UP
	_dust.spread = 30.0
	_dust.initial_velocity_min = 0.3
	_dust.initial_velocity_max = 0.8
	_dust.gravity = Vector3(0, -0.05, 0)
	_dust.damping_min = 0.4
	_dust.damping_max = 0.8
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.8
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(0.6, 1.4))
	sc.add_point(Vector2(1, 0.0))  # hiukkanen hälvenee kutistuen (ei värirampia: musta kiekko)
	_dust.scale_amount_curve = sc
	# Auringon keila ikkunasta pyhimykseen ja pölyhiukkaset keilassa.
	_sun = SpotLight3D.new()
	interior.add_child(_sun)
	_props.append(_sun)
	_sun.light_color = Color(1.0, 0.86, 0.6)
	_sun.light_energy = 0.0
	_sun.spot_range = 6.0
	_sun.spot_angle = 11.0
	_sun.spot_attenuation = 0.4
	var head := PED_AT + Vector3(0, PED_H + SAINT_H * 0.78, 0)
	_sun.look_at_from_position(WINDOW + Vector3(-0.1, 0.0, 0.25), head)
	# Näkyvä valokeila: läpikuultava kartio ikkunasta pyhimykseen (additiivinen), voimistuu auringon mukana.
	var from_w := WINDOW + Vector3(-0.1, 0.0, 0.25)
	var len := from_w.distance_to(head)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.38
	cm.bottom_radius = 0.16
	cm.height = len
	cm.radial_segments = 20
	cm.cap_top = false
	cm.cap_bottom = false
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.88, 0.6, 0.0)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.material = bmat
	_beam = MeshInstance3D.new()
	_beam.mesh = cm
	interior.add_child(_beam)
	_props.append(_beam)
	var axis := (from_w - head).normalized()  # +Y kohti ikkunaa (leveä pää)
	var bx := axis.cross(Vector3.FORWARD).normalized()
	_beam.transform = Transform3D(Basis(bx, axis, bx.cross(axis)).orthonormalized(), (from_w + head) / 2.0)
	_motes = CPUParticles3D.new()
	interior.add_child(_motes)
	_props.append(_motes)
	var mm := SphereMesh.new()
	mm.radius = 0.006
	mm.height = 0.012
	var mmat := B.mat(Color(1.0, 0.92, 0.7))
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.material = mmat
	_motes.mesh = mm
	_motes.amount = 70
	_motes.lifetime = 4.0
	_motes.emitting = false
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var mid := (WINDOW + head) / 2.0
	_motes.position = mid
	_motes.emission_box_extents = Vector3(0.35, 0.3, 0.25)
	_motes.direction = Vector3.UP
	_motes.spread = 180.0
	_motes.initial_velocity_min = 0.01
	_motes.initial_velocity_max = 0.05
	_motes.gravity = Vector3(0, -0.005, 0)
	# Pehmeä täytevalo kasvoille (salin kaksi kattolamppua jäävät kauas).
	_fill = OmniLight3D.new()
	interior.add_child(_fill)
	_props.append(_fill)
	_fill.light_color = Color(1.0, 0.93, 0.8)
	_fill.light_energy = 0.55
	_fill.omni_range = 5.0


## Pieni puupyhimys (n. 0,6 m, juuri jalan pohjassa, etu +Z): vihreä kaapu kultareunuksin, laskokset, rukoilevat
## kädet, ruskeat hiukset, kullattu sädekehä ja kulunutta maalia (puu näkyy). Retki_pakkahuone.gd käyttää samaa mallia.
static func build_saint(parent: Node3D) -> Node3D:
	var r := Node3D.new()
	parent.add_child(r)
	var wood := Color(0.5, 0.34, 0.2)
	var robe := Color(0.2, 0.42, 0.28)
	var gold := Color(0.86, 0.68, 0.26)
	var skin := Color(0.88, 0.72, 0.58)
	var hair := Color(0.36, 0.2, 0.1)
	B.mesh(r, B.boxm(BASE), Vector3(0, BASE.y / 2.0, 0), wood.darkened(0.3))
	B.mesh(r, B.boxm(Vector3(BASE.x - 0.02, 0.012, BASE.z - 0.02)), Vector3(0, BASE.y + 0.006, 0), wood.darkened(0.1))
	var y0 := BASE.y + 0.012
	# Helma kultareunuksella ja kaapu alhaalta levenevänä.
	B.mesh(r, B.cyl(0.084, 0.086, 0.016, 18), Vector3(0, y0 + 0.008, 0), gold)
	B.mesh(r, B.cyl(0.056, 0.082, 0.27, 18), Vector3(0, y0 + 0.016 + 0.135, 0), robe)
	# Laskokset: pystyharjanteet etupuolella, tummempi vihreä.
	for a in [-1.1, -0.65, -0.22, 0.22, 0.65, 1.1]:
		var ang := float(a)
		B.mesh(r, B.cyl(0.006, 0.012, 0.25, 6), Vector3(sin(ang) * 0.066, y0 + 0.14, cos(ang) * 0.066), robe.darkened(0.25),
			Vector3(cos(ang) * -6.0, 0, sin(ang) * 6.0))
	# Viitan kultareunus etuaukossa (kaksi pystyä nauhaa).
	for sx in [-0.022, 0.022]:
		B.mesh(r, B.boxm(Vector3(0.008, 0.3, 0.006)), Vector3(sx, y0 + 0.17, 0.068), gold, Vector3(-8, 0, 0))
	var ty := y0 + 0.016 + 0.27
	B.mesh(r, B.cyl(0.044, 0.056, 0.12, 16), Vector3(0, ty + 0.06, 0), robe.lightened(0.06))
	var sh := B.mesh(r, B.sphere(0.058, 12), Vector3(0, ty + 0.12, 0), robe.lightened(0.08))
	sh.scale = Vector3(1.15, 0.55, 0.82)
	B.mesh(r, B.cyl(0.026, 0.032, 0.012, 14), Vector3(0, ty + 0.145, 0), gold)
	# Hihat olkapäistä rinnan eteen ja rukoilevat kädet sormet ylöspäin.
	for sx in [-1.0, 1.0]:
		B.mesh(r, B.cyl(0.016, 0.02, 0.1, 8), Vector3(sx * 0.036, ty + 0.085, 0.032), robe.lightened(0.04), Vector3(-62, 0, sx * 28.0))
		B.mesh(r, B.cyl(0.018, 0.018, 0.008, 8), Vector3(sx * 0.014, ty + 0.072, 0.064), gold, Vector3(-62, 0, sx * 28.0))
		B.mesh(r, B.boxm(Vector3(0.014, 0.036, 0.026)), Vector3(sx * 0.0072, ty + 0.098, 0.072), skin, Vector3(-12, 0, sx * -6.0))
	# Kaula, pää, hiukset taakse ja olkapäille.
	B.mesh(r, B.cyl(0.016, 0.018, 0.03, 10), Vector3(0, ty + 0.16, 0), skin)
	var hd := B.mesh(r, B.sphere(0.04, 14), Vector3(0, ty + 0.2, 0.006), skin)
	hd.scale = Vector3(0.9, 1.06, 0.96)
	var hr := B.mesh(r, B.sphere(0.044, 14), Vector3(0, ty + 0.208, -0.012), hair)
	hr.scale = Vector3(1.0, 1.04, 0.95)
	B.mesh(r, B.boxm(Vector3(0.074, 0.09, 0.022)), Vector3(0, ty + 0.15, -0.036), hair)
	for sx in [-1.0, 1.0]:
		B.mesh(r, B.boxm(Vector3(0.016, 0.07, 0.02)), Vector3(sx * 0.034, ty + 0.165, 0.004), hair, Vector3(0, 0, sx * 6.0))
	# Kasvot: silmät, kulmat, nenä, suu ja posket (maalattu puu).
	for sx in [-1.0, 1.0]:
		B.mesh(r, B.sphere(0.0045, 6), Vector3(sx * 0.013, ty + 0.205, 0.04), Color(0.12, 0.08, 0.06))
		B.mesh(r, B.boxm(Vector3(0.012, 0.0025, 0.003)), Vector3(sx * 0.013, ty + 0.214, 0.04), hair.darkened(0.2), Vector3(0, 0, sx * -10.0))
		B.mesh(r, B.sphere(0.006, 6), Vector3(sx * 0.02, ty + 0.193, 0.034), Color(0.9, 0.58, 0.5))
	B.mesh(r, B.boxm(Vector3(0.006, 0.014, 0.008)), Vector3(0, ty + 0.198, 0.045), skin.darkened(0.06))
	B.mesh(r, B.boxm(Vector3(0.013, 0.003, 0.004)), Vector3(0, ty + 0.182, 0.041), Color(0.65, 0.22, 0.2))
	# Sädekehä pään takana: kullattu kiekko, tumma reunus ja säteet.
	B.mesh(r, B.cyl(0.074, 0.074, 0.005, 24), Vector3(0, ty + 0.215, -0.05), gold.darkened(0.35), Vector3(90, 0, 0))
	B.mesh(r, B.cyl(0.068, 0.068, 0.006, 24), Vector3(0, ty + 0.215, -0.047), gold, Vector3(90, 0, 0))
	for i in 12:
		var a := TAU * i / 12.0
		B.mesh(r, B.boxm(Vector3(0.004, 0.03, 0.002)), Vector3(sin(a) * 0.052, ty + 0.215 + cos(a) * 0.052, -0.043),
			gold.lightened(0.25), Vector3(0, 0, -rad_to_deg(a)))
	# Kulunut maali: puu näkyy helmassa ja hihassa, nokea laskoksissa.
	for p in [[Vector3(0.052, y0 + 0.05, 0.062), Vector3(0.022, 0.03, 0.006)], [Vector3(-0.07, y0 + 0.11, 0.03), Vector3(0.006, 0.04, 0.02)],
			[Vector3(0.05, ty + 0.07, 0.04), Vector3(0.012, 0.016, 0.006)]]:
		B.mesh(r, B.boxm(p[1]), p[0], wood.lightened(0.1))
	return r


## Kunnostuslaatikko: lankut, kulmatolpat, köysikahvat, sapluunakyltti ja kansi (oma solmu). Puulastut sisällä.
func _build_crate() -> Node3D:
	var c := Node3D.new()
	interior.add_child(c)
	_props.append(c)
	var w := Color(0.66, 0.5, 0.3)
	var hx := CRATE.x / 2.0
	var hz := CRATE.z / 2.0
	B.mesh(c, B.boxm(Vector3(CRATE.x, 0.02, CRATE.z)), Vector3(0, 0.01, 0), w.darkened(0.2))
	for i in 3:
		var y := 0.02 + 0.045 + i * 0.087
		for sz in [-1.0, 1.0]:
			B.mesh(c, B.boxm(Vector3(CRATE.x, 0.08, 0.016)), Vector3(0, y, sz * (hz - 0.008)), w.lerp(Color(0.55, 0.4, 0.24), i * 0.3))
		for sx in [-1.0, 1.0]:
			B.mesh(c, B.boxm(Vector3(0.016, 0.08, CRATE.z - 0.032)), Vector3(sx * (hx - 0.008), y, 0), w.lerp(Color(0.6, 0.44, 0.26), i * 0.25))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.mesh(c, B.boxm(Vector3(0.03, CRATE.y, 0.03)), Vector3(sx * (hx - 0.012), CRATE.y / 2.0, sz * (hz - 0.012)), w.darkened(0.3))
		# Köysikahva päädyssä.
		B.mesh(c, B.cyl(0.008, 0.008, 0.12, 6), Vector3(sx * (hx + 0.012), CRATE.y - 0.06, 0), Color(0.75, 0.66, 0.45), Vector3(90, 0, 0))
	var tag := B.sign_plate(c, "KUNNOSTUS\nÄLÄ KÄÄNNÄ", Color(0.62, 0.48, 0.28), Color(0.15, 0.1, 0.06), 0.045, 40, Color(0.4, 0.28, 0.15))
	tag.scale = Vector3.ONE * 0.3
	tag.position = Vector3(0, CRATE.y * 0.52, hz + 0.004)
	# Puulastut: vaaleat kiemurat täytteenä.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1616
	for i in 70:
		var p := Vector3(rng.randf_range(-hx + 0.04, hx - 0.04), CRATE.y - rng.randf_range(0.01, 0.05), rng.randf_range(-hz + 0.04, hz - 0.04))
		B.mesh(c, B.boxm(Vector3(0.05, 0.004, 0.008)), p, Color(0.88, 0.78, 0.52).darkened(rng.randf() * 0.2),
			Vector3(rng.randf_range(-40, 40), rng.randf_range(0, 180), rng.randf_range(-40, 40)))
	B.mesh(c, B.boxm(Vector3(CRATE.x - 0.05, 0.02, CRATE.z - 0.05)), Vector3(0, CRATE.y - 0.05, 0), Color(0.82, 0.72, 0.48))
	crate_lid = Node3D.new()
	c.add_child(crate_lid)
	crate_lid.position = Vector3(0, CRATE.y, 0)
	for i in 3:
		B.mesh(crate_lid, B.boxm(Vector3(CRATE.x + 0.02, 0.018, CRATE.z / 3.0 - 0.004)), Vector3(0, 0.009, -hz + CRATE.z / 6.0 + i * CRATE.z / 3.0), w.lightened(0.05))
	B.mesh(crate_lid, B.boxm(Vector3(0.03, 0.022, CRATE.z)), Vector3(-hx + 0.05, 0.011, 0), w.darkened(0.15))
	B.mesh(crate_lid, B.boxm(Vector3(0.03, 0.022, CRATE.z)), Vector3(hx - 0.05, 0.011, 0), w.darkened(0.15))
	return c


## Kunnostajan messinkiavain: rengas, varsi ja lehti.
func _build_key() -> Node3D:
	var k := Node3D.new()
	interior.add_child(k)
	_props.append(k)
	var br := Color(0.85, 0.68, 0.3)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.012
	tm.outer_radius = 0.02
	ring.mesh = tm
	ring.material_override = _metal(br)
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(0, 0.056, 0)
	k.add_child(ring)
	var sh := B.mesh(k, B.cyl(0.004, 0.004, 0.07, 8), Vector3(0, 0.0, 0), br)
	sh.material_override = _metal(br)
	var bit := B.mesh(k, B.boxm(Vector3(0.014, 0.016, 0.004)), Vector3(0.009, -0.026, 0), br)
	bit.material_override = _metal(br)
	k.visible = false
	return k


## Pehmeä pyöreä pölyhiukkanen (säteittäinen liukuma läpinäkyväksi).
func _soft_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


func _metal(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.85
	m.roughness = 0.3
	return m


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	_ladder.visible = p != "luukku"
	for c in [me, curator, vis1, vis2]:
		c.clear_ik()
		_lean(c, 0.0)
	_stand(vis1, VIS1.x, VIS1.y)
	_stand(vis2, VIS2.x, VIS2.y)
	_face(vis1, Vector3(0.8, 0, -3.9))
	_face(vis2, Vector3(0.8, 0, -3.9))
	vis1.play("Idle", 0.2)
	vis2.play("Idle", 0.2)
	match p:
		"luukku":
			_story = "Kunnostajan avain oli vierailijakirjan välissä."
			_stand(me, ME_KNEEL.x, ME_KNEEL.y)
			_face(me, HATCH)
			me.play("Crouch_Idle", 0.0)
			_stand(curator, CUR_DESK.x, CUR_DESK.y)
			_face(curator, Vector3(0, 0, 3))
			curator.play("Idle", 0.0)
			crate.position = HATCH + Vector3(0, -0.5, 0.3)
			_lay_saint()
		"laatikko":
			_story = ""
			interior._lid.rotation_degrees.x = -100.0
			key.visible = false
			_stand(me, ME_ASIDE.x, ME_ASIDE.y)
			_face(me, HATCH)
			me.play("Idle", 0.2)
			_stand(curator, CUR_KNEEL.x, CUR_KNEEL.y)
			_face(curator, HATCH + Vector3(0, 0, -1))
			curator.play("Crouch_Idle", 0.2)
			crate.position = HATCH + Vector3(0, -0.5, 0.3)
			crate.rotation = Vector3.ZERO
			crate_lid.position = Vector3(0, CRATE.y, 0)
			crate_lid.rotation = Vector3.ZERO
			_lay_saint()
		"kanto":
			_story = ""
			interior._lid.rotation_degrees.x = -100.0
			_place_crate_floor(true)
			_take_saint()
			_stand(me, ME_ASIDE.x, ME_ASIDE.y)
			_stand(curator, -2.2, 0.2)
			curator.play("Walk", 0.2)
			me.play("Walk", 0.2)
		"valo":
			_story = ""
			interior._lid.rotation_degrees.x = -100.0
			_place_crate_floor(true)
			_put_saint_on_pedestal(0.0)
			_stand(curator, CUR_PED.x, CUR_PED.y)
			_face(curator, PED_AT)
			_stand(me, ME_WAIT.x, ME_WAIT.y)
			_face(me, PED_AT)
			curator.play("Idle", 0.2)
			me.play("Idle", 0.2)
			_stand(vis1, VIS1_BACK.x, VIS1_BACK.y)
			_stand(vis2, VIS2_BACK.x, VIS2_BACK.y)
		"otsikko":
			_story = ""
			interior._lid.rotation_degrees.x = -100.0
			_place_crate_floor(true)
			_put_saint_on_pedestal(0.0)
			_turn_plate()
			_stand(curator, CUR_BACK.x, CUR_BACK.y)
			_stand(me, ME_PED.x, ME_PED.y)
			_stand(vis1, VIS1_SUN.x, VIS1_SUN.y)
			_stand(vis2, VIS2_SUN.x, VIS2_SUN.y)
			for c in [curator, me, vis1, vis2]:
				c.play("Idle", 0.2)
			_face(curator, me.position)
			_face(me, curator.position)
			_face(vis1, PED_AT)
			_face(vis2, PED_AT)
			_sun.light_energy = 3.0
			(_beam.mesh.material as StandardMaterial3D).albedo_color.a = 0.09
			_motes.emitting = true
			Sfx.play("win", -7.0, 0.92)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa luukun E-painalluksesta: sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "luukku" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"luukku":
			_step_luukku()
		"laatikko":
			_step_laatikko()
		"kanto":
			_step_kanto()
		"valo":
			_step_valo()
		"otsikko":
			_step_otsikko()
	_fill.position = _cam.position.lerp(curator.position + Vector3(0, 1.5, 0), 0.5) + Vector3(0, 0.6, 0)
	_glint = maxf(0.0, _glint - delta * 1.3)
	_ui.queue_redraw()
	if phase != "" and _t >= DUR[phase]:
		var i := ORDER.find(phase)
		if i == ORDER.size() - 1:
			_finish()
		else:
			_begin(ORDER[i + 1])


func _finish() -> void:
	if phase == "":
		return
	phase = ""
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	for nd in _was_visible:
		if is_instance_valid(nd):
			(nd as Node3D).visible = _was_visible[nd]
	finished.emit()
	queue_free()


func _step_luukku() -> void:
	# Pelaaja polvillaan luukulla: avain reikään (0,4-1,2 s), kääntö ja naksahdus (1,4-2,0), kansi narahtaa auki (2,2-3,3),
	# pölypilvi. Kuraattori kuulee narahduksen ja kiiruhtaa pöydän takaa luukulle (2,4-5,2).
	var reach := clampf((_t - 0.3) / 0.6, 0.0, 1.0)
	var open := _ease(clampf((_t - 2.2) / 1.1, 0.0, 1.0))
	if open < 0.15:
		_reach(me, _g(KEYHOLE + Vector3(0, 0.09, 0.02)), reach, 0.75 * reach)
	else:
		_reach(me, _g(KEYHOLE + Vector3(0, 0.09, 0.02)), 1.0 - clampf((_t - 2.3) / 0.5, 0.0, 1.0), 0.75 * (1.0 - clampf((_t - 2.3) / 0.6, 0.0, 1.0)))
	key.visible = _t > 0.5 and _t < 2.3
	if key.visible:
		var turn := _ease(clampf((_t - 1.4) / 0.5, 0.0, 1.0))
		var ins := clampf((_t - 0.5) / 0.6, 0.0, 1.0)
		key.position = KEYHOLE + Vector3(0, 0.035 + 0.035 * (1.0 - ins), 0)  # varsi kanteen, rengas ylhäällä
		key.rotation = Vector3(0, turn * PI / 2.0, 0)
		if turn > 0.9 and not _once.has("naks"):
			_once["naks"] = true
			Sfx.play("rattle", -4.0, 1.6)
	interior._lid.rotation_degrees.x = -100.0 * open
	_ladder.visible = open > 0.3
	if _t > 2.2 and not _once.has("narahdus"):
		_once["narahdus"] = true
		Sfx.play("door", -3.0, 0.7)
	if open > 0.5 and not _once.has("poly"):
		_once["poly"] = true
		_dust.emitting = true
		Sfx.play("whoosh", -12.0, 0.6)
	# Kuraattori: kääntyy ääneen 2,4 s, kiiruhtaa luukulle.
	var path := [CUR_DESK, Vector2(-4.6, -2.2), Vector2(-6.0, -0.4), Vector2(-5.95, 0.95)]  # kannen taitse luukun länsireunalle
	var k := clampf((_t - 2.5) / 2.6, 0.0, 1.0)
	var p := _path(path, k)
	_stand(curator, p.x, p.y)
	if _t < 2.5:
		curator.play("Idle", 0.2)
		_face(curator, Vector3(0, 0, 3) if _t < 2.3 else HATCH)
	elif k < 1.0:
		curator.play("Jog_Fwd", 0.2, 0.75)
		var nx := _path(path, minf(1.0, k + 0.05))
		_face(curator, Vector3(nx.x, 0, nx.y))
	else:
		curator.play("Idle", 0.2)
		_face(curator, HATCH)
	if _t > 3.2:
		_bub[curator] = "Avain! Missä se oli?"
	if _t > 4.6:
		_story = "Vierailijakirjan välissä. Kunnostaja unohti sen sinne."
	# Kamera: matala sivukuva luukulta idästä (pelaaja ja aukko), väljenee kuraattorin tullessa luukun länsireunalle
	# kasvot kameraan päin.
	var w := _ease(clampf((_t - 2.9) / 1.4, 0.0, 1.0))
	var eye := Vector3(-2.75, 1.05, 3.1).lerp(Vector3(-2.3, 1.6, 3.5), w)
	var look := Vector3(-4.85, 0.35, 1.3).lerp(Vector3(-5.2, 0.75, 0.6), w)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), lerpf(2.2, 3.6, w)))


func _step_laatikko() -> void:
	# Kuraattori polvillaan luukun reunalla kurkottaa aukkoon (0-0,5 s), nostaa laatikon köysikahvoista (0,5-2,1),
	# laskee sen oikealle lattialle (2,1-2,9), nostaa kannen sivuun (3,1-3,8) ja pyhimyksen lastujen seasta (4,0-4,9),
	# nousee ja kääntyy kameraan päin, pyyhkii hihalla pölyt kasvoilta (5,4-6,4).
	if _t < 2.9:
		var rise := _ease(clampf((_t - 0.5) / 1.6, 0.0, 1.0))
		var side := _ease(clampf((_t - 2.1) / 0.8, 0.0, 1.0))
		var lifted := HATCH + Vector3(0, -0.5 + 0.62 * rise, 0.3)
		var pos := lifted.lerp(CRATE_FLOOR, side)
		pos.y = lerpf(lifted.y, 0.0, side) + 0.12 * sin(side * PI)
		crate.position = pos
		crate.rotation.y = -0.25 * side
		_face(curator, Vector3(CUR_KNEEL.x, 0, 0.0).lerp(CRATE_FLOOR + Vector3(0.1, 0, -0.6), side))  # kääntyy laatikon mukana
		var w := clampf(_t / 0.5, 0.0, 1.0)
		_both(curator, crate.to_global(Vector3(-CRATE.x / 2.0 - 0.01, CRATE.y - 0.06, 0)), crate.to_global(Vector3(CRATE.x / 2.0 + 0.01, CRATE.y - 0.06, 0)), w,
			lerpf(0.95, 0.55, rise) * w)
		if rise > 0.05 and not _once.has("nosto"):
			_once["nosto"] = true
			Sfx.play("grunt", -6.0, 1.25)
		if side >= 1.0 and not _once.has("kops"):
			_once["kops"] = true
			Sfx.play("step_wood", -2.0, 0.7)
	else:
		_place_crate_floor(false)
		if _t < 3.9:
			var lw := clampf((_t - 2.9) / 0.3, 0.0, 1.0)
			var lift := _ease(clampf((_t - 3.1) / 0.7, 0.0, 1.0))
			crate_lid.position = Vector3(0, CRATE.y + 0.2 * sin(lift * PI * 0.5), 0.0) + Vector3(0, 0, 0.42 * lift)
			crate_lid.rotation.x = 0.0
			if lift >= 0.95:
				crate_lid.position = Vector3(0, -CRATE.y + 0.01, 0.42)  # lattialle laatikon eteen
			_reach(curator, crate_lid.global_position + Vector3(0, 0.03, 0), lw * (1.0 - clampf((_t - 3.75) / 0.15, 0.0, 1.0)), 0.6)
			if lift > 0.1 and not _once.has("kansi"):
				_once["kansi"] = true
				Sfx.play("door_close", -10.0, 1.4)
		else:
			crate_lid.position = Vector3(0, -CRATE.y + 0.01, 0.42)
			if _t < 4.9:
				var g := clampf((_t - 3.9) / 0.4, 0.0, 1.0)
				var up := _ease(clampf((_t - 4.3) / 0.6, 0.0, 1.0))
				if up <= 0.0:
					_both(curator, saint.to_global(Vector3(-0.07, 0.3, 0)), saint.to_global(Vector3(0.07, 0.3, 0)), g, 0.7 * g)
				else:
					if not _once.has("ylos"):
						_once["ylos"] = true
						curator.play("Idle", 0.5)  # nousee polviltaan noston aikana
						saint.reparent(interior)
						saint.scale = Vector3.ONE
						Sfx.play("cloth", -6.0, 0.8)
					var from := interior.to_local(crate.to_global(Vector3(0, CRATE.y - 0.03, 0)))
					var to := _chest_hold(curator)
					saint.position = from.lerp(to, up) - Vector3(0, SAINT_H * 0.45, 0) * (1.0 - up)
					var upright := Basis(Vector3.UP, curator.rotation.y + PI)
					saint.basis = LAY.rotated(Vector3.UP, crate.rotation.y).slerp(upright, up)
					_hold_saint_hands(curator, 1.0, 0.7 * (1.0 - up))
			else:
				# Seisaallaan, pyhimys rinnan edessä kasvot kameraan, hihapyyhkäisy.
				if not _once.has("seisoo"):
					_once["seisoo"] = true
					curator.play("Idle", 0.3)
				var sw := _ease(clampf((_t - 4.9) / 0.5, 0.0, 1.0))
				var st := CUR_KNEEL.lerp(CUR_STAND, sw)
				_stand(curator, st.x, st.y)
				_face(curator, Vector3(-3.0, 0, 3.4))
				saint.position = _chest_hold(curator)
				var to_cam := _cam.position - saint.position
				to_cam.y = 0.0
				saint.rotation = Vector3(0, B.yaw_to(-to_cam), 0)
				var wipe := clampf((_t - 5.4) / 1.0, 0.0, 1.0)
				if wipe > 0.0 and wipe < 1.0:
					_hold_saint_hands(curator, 1.0, 0.0, true)
					var face := saint.to_global(Vector3(0.0, SAINT_H * 0.82, 0.07))
					var sway := sin(wipe * TAU * 1.5) * 0.045
					curator.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r",
						curator.to_local(face + saint.global_basis.x * sway + Vector3(0, 0, 0)), curator.bone_position("upperarm_r") + Vector3(0.4, -0.3, 0.2))
					if not _once.has("pyyhi"):
						_once["pyyhi"] = true
						Sfx.play("cloth", -8.0, 1.3)
				else:
					_hold_saint_hands(curator, 1.0, 0.0)
				if _t > 6.45:
					_bub[curator] = "Siinähän sinä olet."
	# Pelaaja katsoo vieressä.
	_face(me, crate.global_position if _t < 4.9 else curator.position)
	# Kamera: nosto kuvataan luukun kaakkoispuolelta, pyhimys lähikuvana kuraattorin edestä.
	var eye: Vector3
	var look: Vector3
	var wdt: float
	if _t < 4.95:
		var u := _ease(clampf((_t - 3.9) / 1.0, 0.0, 1.0))  # pyhimyksen nousu: kuva nousee ja väljenee mukana
		eye = Vector3(-3.15, 1.15, 3.25).lerp(Vector3(-2.8, 1.45, 3.6), u)
		look = Vector3(-4.7, 0.35, 1.45).lerp(Vector3(-4.75, 0.95, 1.7), u)
		wdt = lerpf(2.3, 3.0, u)
	else:
		var sp := saint.position + Vector3(0, SAINT_H * 0.55, 0)
		var hd := interior.to_local(curator.to_global(curator.bone_position("Head")))
		look = sp + (hd - sp) * 0.7
		eye = look + Vector3(1.1, 0.1, 1.3)
		wdt = 1.3
	_cam_at(eye, look, _fov_w(eye.distance_to(look), wdt))


func _step_kanto() -> void:
	# Kuraattori kantaa pyhimyksen salin poikki (0-5,0 s), pelaaja perässä; kävijät väistävät ja kääntyvät katsomaan.
	# Jalustalla (5,0-6,3) nosto jalustan kannelle, säätö (6,5-8,0): "Noin. ...Ei. Noin."
	var path := [Vector2(-2.2, 0.2), Vector2(1.4, -1.55), Vector2(3.6, -2.45), Vector2(5.15, -3.1), CUR_PED]
	var k := clampf(_t / 5.0, 0.0, 1.0)
	var p := _path(path, k)
	_stand(curator, p.x, p.y)
	if k < 1.0:
		curator.play("Walk", 0.2, 0.85)
		var nx := _path(path, minf(1.0, k + 0.04))
		_face(curator, Vector3(nx.x, 0, nx.y))
		saint.position = _chest_hold(curator)
		saint.rotation = Vector3(0, curator.rotation.y + PI, 0)  # pyhimys katsoo kulkusuuntaan
		_hold_saint_hands(curator, 1.0, 0.0)
		if fmod(_t, 0.55) < 0.02:
			Sfx.play("step_wood", -12.0, 1.0)
	else:
		curator.play("Idle", 0.2)
		_face(curator, PED_AT)
		var up := _ease(clampf((_t - 5.0) / 1.2, 0.0, 1.0))
		if up < 1.0:
			var from := _chest_hold(curator)
			var to := PED_AT + Vector3(0, PED_H, 0)
			var pp := from.lerp(to, up)
			pp.y += 0.18 * sin(up * PI)
			saint.position = pp
			saint.rotation = Vector3(0, lerp_angle(curator.rotation.y + PI, 0.0, up), 0)
			_hold_saint_hands(curator, 1.0, 0.4 * sin(up * PI * 0.5))
		else:
			if not _once.has("paikalla"):
				_once["paikalla"] = true
				saint_placed = true
				interior._footprint.visible = false
				Sfx.play("step_wood", -4.0, 1.3)
			# Säätö: pieni kierto oikealle, liikaa, takaisin (kädet pyhimyksen kyljillä).
			var adj := 0.0
			if _t > 6.5:
				var a := (_t - 6.5) / 1.4
				adj = 0.16 * sin(clampf(a / 0.35, 0.0, 1.0) * PI * 0.5) * (1.0 - clampf((a - 0.45) / 0.25, 0.0, 1.0)) \
					- 0.06 * clampf((a - 0.45) / 0.2, 0.0, 1.0) * (1.0 - clampf((a - 0.8) / 0.2, 0.0, 1.0))
			_put_saint_on_pedestal(adj)
			var off := clampf((_t - 7.6) / 0.4, 0.0, 1.0)
			# Kuraattori on jalustan itäpuolella: kädet pyhimyksen etu- ja takakyljellä.
			_both(curator, saint.to_global(Vector3(0.0, 0.32, 0.065)), saint.to_global(Vector3(0.0, 0.32, -0.065)), 1.0 - off, 0.45 * (1.0 - off))
			if _t > 6.5 and _t < 7.3:
				_bub[curator] = "Noin."
			elif _t >= 7.3:
				_bub[curator] = "...Ei. Noin."
	# Pelaaja perässä etäämpänä.
	var mp := ME_ASIDE.lerp(ME_WAIT, _ease(clampf((_t - 0.6) / 4.6, 0.0, 1.0)))
	_stand(me, mp.x, mp.y)
	me.play("Walk" if _t > 0.6 and _t < 5.2 else "Idle", 0.2, 0.9)
	_face(me, curator.position if _t > 5.0 else Vector3(ME_WAIT.x, 0, ME_WAIT.y))
	# Kävijät väistävät taaksepäin (+Z) kuraattorin lähestyessä ja kääntyvät katsomaan.
	for v in [[vis1, VIS1, VIS1_BACK, 1.6], [vis2, VIS2, VIS2_BACK, 1.9]]:
		var c: Node3D = v[0]
		var bk := _ease(clampf((_t - float(v[3])) / 1.0, 0.0, 1.0))
		var vp: Vector2 = (v[1] as Vector2).lerp(v[2], bk)
		_stand(c, vp.x, vp.y)
		c.play("Walk" if bk > 0.0 and bk < 1.0 else "Idle", 0.2, 0.6)
		_face(c, curator.position if _t > 1.0 else Vector3(0.8, 0, -3.9))
	# Kamera: seuraa kuraattoria salin etupuolelta (tausta takaseinä ja veistokset), jalustalla lähempi kuva.
	var eye: Vector3
	var look: Vector3
	var wdt: float
	if _t < 5.0:
		var cp := curator.position
		look = cp + Vector3(0.25, 1.05, 0)
		eye = cp + Vector3(1.0, 1.45, 3.0)
		wdt = 3.1
	else:
		look = Vector3(4.75, 1.2, -3.55)
		eye = Vector3(3.2, 1.45, -1.35)
		wdt = 2.2
	_cam_at(eye, look, _fov_w(eye.distance_to(look), wdt))


func _step_valo() -> void:
	# Kuraattori kyykistyy kääntämään POISSA-kyltin (0,3-1,2 s), astuu taakse (1,4-2,2). Aurinko syttyy ikkunasta
	# pyhimykseen (2,2-3,2), sädekehä välähtää 3,0. Kävijät taputtavat hiljaa (3,4-), kuraattorin repliikit.
	if _t < 1.45:
		var wk := _ease(clampf(_t / 0.6, 0.0, 1.0))
		var wp := CUR_PED.lerp(PLATE_AT, wk)
		_stand(curator, wp.x, wp.y)
		curator.play("Walk" if wk > 0.0 and wk < 1.0 else "Idle", 0.2, 0.7)
		_face(curator, PLATE + Vector3(0, 0, 0.6) if wk < 1.0 else PLATE)
		var rw := clampf((_t - 0.6) / 0.3, 0.0, 1.0) * (1.0 - clampf((_t - 1.25) / 0.2, 0.0, 1.0))
		_reach(curator, _g(PLATE + Vector3(0.09, 0.0, 0.03)), rw, 0.45 * rw)
		var flip := _ease(clampf((_t - 0.9) / 0.35, 0.0, 1.0))
		_plate_rig.rotation.y = PI * flip
		if flip > 0.5 and not plate_turned:
			plate_turned = true
			Sfx.play("pickup", -6.0, 0.9)
	else:
		var b := _ease(clampf((_t - 1.45) / 0.8, 0.0, 1.0))
		var cp := PLATE_AT.lerp(CUR_BACK, b)
		_stand(curator, cp.x, cp.y)
		curator.play("Walk" if b > 0.0 and b < 1.0 else "Idle", 0.2, -0.7)
		_face(curator, PED_AT)
	var sun := _ease(clampf((_t - 2.2) / 1.0, 0.0, 1.0))
	_sun.light_energy = 3.0 * sun
	(_beam.mesh.material as StandardMaterial3D).albedo_color.a = 0.09 * sun
	if sun > 0.0 and not _motes.emitting:
		_motes.emitting = true
	if _t > 3.0 and not _once.has("valahdys"):
		_once["valahdys"] = true
		_glint = 1.0
		Sfx.play("bell", -14.0, 1.5)
	for v in [[vis1, VIS1_BACK, VIS1_SUN, 0.4], [vis2, VIS2_BACK, VIS2_SUN, 0.7]]:
		var c: Node3D = v[0]
		var ak := _ease(clampf((_t - float(v[3])) / 1.6, 0.0, 1.0))
		var ap: Vector2 = (v[1] as Vector2).lerp(v[2], ak)
		_stand(c, ap.x, ap.y)
		if _t <= 3.4:
			c.play("Walk" if ak > 0.0 and ak < 1.0 else "Idle", 0.2, 0.6)
		else:
			c.play("Idle", 0.2)
	if _t > 3.4:
		_clap(vis1, _t, 0.0)
		_clap(vis2, _t, 0.3)
		if not _once.has("aplodit"):
			_once["aplodit"] = true
			_audio.stream = _applause_wav()
			_audio.volume_db = -14.0
			_audio.play()
	var mw := _ease(clampf((_t - 0.2) / 1.2, 0.0, 1.0))
	var mpp := ME_WAIT.lerp(ME_PED, mw)
	_stand(me, mpp.x, mpp.y)
	me.play("Walk" if mw > 0.0 and mw < 1.0 else "Idle", 0.2, 0.8)
	_face(me, PED_AT)
	for c in [vis1, vis2]:
		_face(c, PED_AT)
	if _t > 3.6 and _t < 5.2:
		_bub[curator] = "Kolmesataa vuotta se on seissyt tässä."
	elif _t >= 5.2:
		_bub[curator] = "Viikon se oli poissa, enkä nukkunut yhtään yötä."
	# Kamera: matala kuva edestä ylös pyhimykseen (aurinko ja sädekehä), kuraattori vasemmalla.
	# Kyltti kuvataan idästä matalalta (kuraattori lännestä kasvot kameraan), leikkaus 1,45 s aurinkokuvaan.
	if _t < 1.45:
		var e1 := Vector3(5.75, 1.2, -1.2)
		var l1 := Vector3(4.35, 0.95, -3.3)
		_cam_at(e1, l1, _fov_w(e1.distance_to(l1), 2.9))
	else:
		var k := _ease(clampf((_t - 1.45) / 1.6, 0.0, 1.0))
		var look := Vector3(4.3, 1.25, -3.4)
		var eye := Vector3(5.75, 1.0, -0.9)
		_cam_at(eye, look, _fov_w(eye.distance_to(look), lerpf(2.2, 3.3, k)))


func _step_otsikko() -> void:
	# Kuraattori kääntyy pelaajaan: "Kiitos. Pakkahuone pitää omansa." Aurinko pyhimyksessä, kävijät katsovat.
	if _t < 2.6:
		_bub[curator] = "Kiitos. Pakkahuone pitää omansa."
	else:
		_bub.erase(curator)
	var look := Vector3(3.7, 1.1, -3.1)
	var eye := Vector3(5.7, 1.85, 0.3)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.7))


# --- Esineet ja hahmot --------------------------------------------------------------

## Pyhimys makaa laatikossa selällään pää +x:ään (kasvot ylös), pienennettynä mahtumaan (lastut peittävät reunat).
const LAY := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
const LAY_K := 0.72


func _lay_saint() -> void:
	if saint.get_parent() != crate:
		saint.reparent(crate)
	saint.transform = Transform3D(LAY.scaled(Vector3.ONE * LAY_K), Vector3(-SAINT_H * LAY_K / 2.0, CRATE.y - 0.09, 0))


## Laatikko lattialla kuraattorin oikealla puolella (kansi lattialla edessä, kun open).
func _place_crate_floor(open: bool) -> void:
	crate.position = CRATE_FLOOR
	crate.rotation = Vector3(0, -0.25, 0)
	if open:
		crate_lid.position = Vector3(0, -CRATE.y + 0.01, 0.42)


## Pyhimys pois laatikosta kuraattorin käsiin (vaiheen alku).
func _take_saint() -> void:
	if saint.get_parent() != interior:
		saint.reparent(interior)
	saint.scale = Vector3.ONE
	saint.position = _chest_hold(curator)


func _put_saint_on_pedestal(adj: float) -> void:
	if saint.get_parent() != interior:
		saint.reparent(interior)
	saint.scale = Vector3.ONE
	saint.position = PED_AT + Vector3(0, PED_H, 0)
	saint.rotation = Vector3(0, adj, 0)
	saint_placed = true
	interior._footprint.visible = false


## POISSA-kyltti käännetään: telineen takana oikea kyltti.
func _turn_plate() -> void:
	plate_turned = true
	_plate_rig.rotation.y = PI


## Pyhimyksen jalan keskikohta kuraattorin rinnan edessä (käsivarret koukussa), museon kehyksessä.
func _chest_hold(c: Node3D) -> Vector3:
	return interior.to_local(c.to_global(Vector3(0, 0.86, -0.3)))


## Museon paikallinen piste globaaliksi (IK ja hahmojen to_local tarvitsevat globaalin).
func _g(v: Vector3) -> Vector3:
	return interior.to_global(v)


## Molemmat kädet pyhimyksen kyljillä (jalan yllä); wipe: oikea käsi vapaana pyyhkimään.
func _hold_saint_hands(c: Node3D, w: float, lean: float, left_only := false) -> void:
	var l := saint.to_global(Vector3(-0.085, 0.13, 0.0))
	var r := saint.to_global(Vector3(0.085, 0.13, 0.0))
	# Pyhimyksen x-akseli voi osoittaa kumpaan suuntaan tahansa: vasen käsi hahmon vasemmalle puolelle.
	if c.to_local(l).x * signf((c.bone_position("upperarm_l") as Vector3).x) < 0.0:
		var tmp := l
		l = r
		r = tmp
	if left_only:
		_lean(c, lean)
		var shl: Vector3 = c.bone_position("upperarm_l")
		var sl := signf(shl.x) if shl.x != 0.0 else -1.0
		c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", c.to_local(l), shl + Vector3(sl * 0.45, -0.35, 0.2))
	else:
		_both(c, l, r, w, lean)


## Molemmat kädet pisteisiin (globaali, w 0..1); lean kumartaa selkää.
func _both(c: Node3D, l_at: Vector3, r_at: Vector3, w: float, lean: float) -> void:
	_lean(c, lean)
	for side in [["_l", l_at], ["_r", r_at]]:
		var lr: String = side[0]
		var sh: Vector3 = c.bone_position("upperarm" + lr)
		var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
		var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
		var tgt := rest.lerp(c.to_local(side[1]), w)
		c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, tgt, sh + Vector3(s * 0.45, -0.35, 0.2))


## Oikea käsi kohti pistettä (w 0..1); lean kumartaa selkää samassa suhteessa.
func _reach(c: Node3D, at: Vector3, w: float, lean := 0.0) -> void:
	_lean(c, lean)
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at), w)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", tgt, sh + Vector3(s * 0.45, -0.25, 0.25))


## Kumarrus koko selällä (rad yhteensä), niska kompensoi katseen.
func _lean(c: Node3D, a: float) -> void:
	c.set_override("spine_01", Vector3.RIGHT, -a * 0.45)
	c.set_override("spine_02", Vector3.RIGHT, -a * 0.35)
	c.set_override("spine_03", Vector3.RIGHT, -a * 0.2)
	c.set_override("neck_01", Vector3.RIGHT, a * 0.35)


## Taputus käsien IK:lla (kuten karaoke_legenda.gd): kämmenet rinnan edessä, väli sykkii hiljaa.
func _clap(c: Node3D, t: float, off: float) -> void:
	var chest: Vector3 = c.bone_position("spine_03")
	var mid: Vector3 = chest + Vector3(0, 0.02, -0.32)
	var sep := 0.03 + 0.07 * absf(sin(PI * (t * 1.7 + off)))
	for lr in ["_l", "_r"]:
		var sh: Vector3 = c.bone_position("upperarm" + lr)
		var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
		c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, mid + Vector3(s * sep, 0, 0), sh + Vector3(s * 0.35, -0.45, 0.05))


func _stand(c: Node3D, x: float, z: float) -> void:
	c.position = Vector3(x, 0, z)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


func hand(c: Node3D, lr := "_r") -> Vector3:
	return c.to_global((c.bone_position("hand" + lr) + c.bone_position("index_01" + lr)) / 2.0)


func _path(pts: Array, k: float) -> Vector2:
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i] as Vector2).distance_to(pts[i + 1])
	var want := total * k
	for i in pts.size() - 1:
		var seg := (pts[i] as Vector2).distance_to(pts[i + 1])
		if want <= seg or i == pts.size() - 2:
			return (pts[i] as Vector2).lerp(pts[i + 1], clampf(want / maxf(seg, 0.001), 0.0, 1.0))
		want -= seg
	return pts[-1]


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


# --- Kamera -------------------------------------------------------------------------

func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(interior.to_global(eye), interior.to_global(look))


func _fov_w(d: float, w: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return rad_to_deg(2.0 * atan(w / (2.0 * d) / (vs.x / vs.y)))


# --- Ääni ---------------------------------------------------------------------------

## Hiljaiset aplodit: kaksi taputtajaa, harvat kohinapurskeet.
func _applause_wav() -> AudioStreamWAV:
	var dur := 3.2
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1616
	for who in 2:
		var t := 0.1 + who * 0.17
		while t < dur - 0.1:
			var start := int(t * RATE)
			var amp := rng.randf_range(0.25, 0.4) * clampf((dur - t) / 1.0, 0.2, 1.0)
			var lp := 0.0
			for j in int(0.03 * RATE):
				if start + j >= s.size():
					break
				var n := rng.randf_range(-1.0, 1.0)
				lp += (n - lp) * 0.5
				s[start + j] += (n - lp * 0.6) * amp * exp(-j / (0.005 * RATE))
			t += rng.randf_range(0.26, 0.34)
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.data = data
	return w


# --- Piirto -------------------------------------------------------------------------

func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 440, 24, 880, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for c: Node3D in _bub:
		if is_instance_valid(c) and c.visible:
			Room.bubble(_ui, _cam, c, _bub[c], 90.0, 120.0)
	if _glint > 0.0:
		var hp := saint.to_global(Vector3(0.05, SAINT_H * 0.88, -0.04))
		if not _cam.is_position_behind(hp):
			_draw_star(_cam.unproject_position(hp), 46.0 * _glint, Color(1.0, 0.95, 0.75, _glint))
	if phase == "otsikko":
		var a := clampf((_t - 0.9) / 0.9, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.06, 0.04, 0.02, 0.25 * a))
		var y := vs.y * 0.17
		_draw_saint_icon(Vector2(vs.x / 2.0, y - 78.0), a)
		var title := "PAKKAHUONEEN VEISTOS"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.16, 0.09, 0.03, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(1.0, 0.84, 0.42, a))
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 158.0, 840, 84)
		_ui.draw_rect(sr, Color(0.06, 0.04, 0.02, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Kellarin laatikosta takaisin jalustalle",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.95, 0.8, 0.5, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Kuraattori kantoi sen itse.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Välähdys: nelisakarainen tähti ja hehku.
func _draw_star(c: Vector2, r: float, col: Color) -> void:
	_ui.draw_circle(c, r * 0.35, Color(col.r, col.g, col.b, col.a * 0.35))
	for ang in [0.0, PI / 2.0]:
		var d := Vector2(cos(ang), sin(ang))
		var nrm := Vector2(-d.y, d.x)
		_ui.draw_colored_polygon(PackedVector2Array([c + d * r, c + nrm * r * 0.1, c - d * r, c - nrm * r * 0.1]), col)
	_ui.draw_circle(c, r * 0.12, col)


## Pyhimyksen siluetti otsikon yllä: kultainen sädekehä, pää, vihreä kaapu ja jalka.
func _draw_saint_icon(c: Vector2, a: float) -> void:
	var dark := Color(0.16, 0.09, 0.03, a)
	_ui.draw_circle(c + Vector2(0, -22), 19.0, dark)
	_ui.draw_circle(c + Vector2(0, -22), 16.0, Color(0.95, 0.75, 0.3, a))
	_ui.draw_circle(c + Vector2(0, -21), 8.5, dark)
	_ui.draw_circle(c + Vector2(0, -21), 7.0, Color(0.9, 0.74, 0.6, a))
	var robe := PackedVector2Array([c + Vector2(-8, -12), c + Vector2(8, -12), c + Vector2(15, 22), c + Vector2(-15, 22)])
	_ui.draw_colored_polygon(robe, Color(0.2, 0.45, 0.3, a))
	_ui.draw_polyline(PackedVector2Array([robe[0], robe[1], robe[2], robe[3], robe[0]]), dark, 2.0)
	_ui.draw_rect(Rect2(c + Vector2(-18, 22), Vector2(36, 6)), Color(0.42, 0.28, 0.16, a))
