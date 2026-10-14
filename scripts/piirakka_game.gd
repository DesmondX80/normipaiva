extends Node3D
## Reipparin lihapiirakkahaaste (#115), pelataan FPS-näkymässä Reipparin pihapöydän päässä kuten halonhakkuu:
## kädessä kameran edessä lihapiirakka kaikilla (halkaistu kuori, kaksi nakkia, ketsuppi, sinappi, kurkkusalaatti ja
## sipuli), edessä lautasellinen lisää ja pöydän takana kioskin luukku, jossa Raija nojaa. Ympärillä grillin
## omistaja Reiska, ennätyksen haltija Juntti, rekkamies ja mummo kommentoivat, kannustavat ja epäilevät
## puhekuplissa tilanteen mukaan. Montako piirakkaa ehdit syödä TIME sekunnissa? Välilyönti haukkaa (palan katoaa
## piirakasta), A ja D vuorotellen pureskelevat (kamera nyökkää; CHEWS kertaa haukun jälkeen), sitten voi haukata
## taas. Jokainen haukku täyttää vatsaa; vatsa sulattaa hitaasti, ja limu (W, pullo huulille) laskee vatsaa mutta
## vie hetken. Täyttyvä vatsa huojuttaa kuvaa ja vihertää reunat; täysi vatsa: "Ei mahdu!" ja haaste päättyy.
## F / Esc luovuttaa. Solmun kehys = kioski (world.reippari_root): -Z julkisivu. finished(pies).

signal finished(pies: int)

const MG := preload("res://scripts/mg_draw.gd")
const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const TIME := 40.0
const BITES := 5  # haukkua piirakkaa kohti
const CHEWS := 2  # pureskeluja haukun jälkeen (A/D vuorotellen)
const BITE_FILL := 0.028
const DIGEST := 0.009  # vatsa sulattaa sekunnissa
const SODA := 0.15
const SODA_T := 1.1
const LINES := ["Kaikilla mausteilla, niinku Juntti tilas!", "Älä tukehdu, mää en osaa ensiapua.",
	"Juntti söi seittemän ja oksensi parkkipaikalle.", "Pureskele, poika, pureskele!"]
## Istutaan pihapöydän penkillä (world.gd: pöytä keskellä x 4.8, z -3.8, kansi y 0.79, penkit z -4.4 ja -3.2,
## aurinkovarjon tanko keskellä): silmät penkiltä pöydän yli, väki kerääntyy pöydän ympärille.
const EYE := Vector3(5.5, 1.2, -3.05)
const LOOK := Vector3(5.2, 0.95, -5.4)
const PLATE := Vector3(5.45, 0.8, -3.62)
const CRUST := Color(0.82, 0.52, 0.22)
const BUN := Color(0.45, 0.22, 0.1)  # uppopaistettu kuori
const CRUMB := Color(0.96, 0.92, 0.8)  # valkoinen sisus
const SAUSAGE := Color(0.93, 0.62, 0.52)
const RELISH := Color(0.42, 0.55, 0.12)
const KETCHUP := Color(0.78, 0.06, 0.04)
const MUSTARD := Color(0.78, 0.6, 0.25)
const FRY_EDGE := Color(0.72, 0.42, 0.16)  # kullanruskea paistoreuna
## Katsojat: avain -> [nimi, ulkonäkö, paikka, asento].
const REISKA := {"shirt": Color(0.95, 0.95, 0.92), "pants": Color(0.2, 0.2, 0.25), "shoes": Color(0.15, 0.12, 0.1),
	"hair": "Hair_Buzzed", "hair_color": Color(0.35, 0.28, 0.2), "beard": true, "height": 1.8, "belly": 0.9, "skin": Color(0.95, 0.74, 0.64)}
const REKKAMIES := {"shirt": Color(0.2, 0.3, 0.55), "pants": Color(0.25, 0.25, 0.3), "shoes": Color(0.2, 0.15, 0.1),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.4, 0.3, 0.2), "height": 1.84, "belly": 0.8, "bulk": 0.4}
const RAIJA := {"model": "female", "shirt": Color(0.95, 0.45, 0.1), "pants": Color(0.2, 0.2, 0.25), "shoes": Color(0.9, 0.9, 0.9),
	"hair": "Hair_Long", "hair_color": Color(0.7, 0.3, 0.15), "height": 1.66, "skin": Color(0.95, 0.78, 0.68), "belly": 0.4}
const MUMMO := {"model": "female", "shirt": Color(0.5, 0.6, 0.45), "pants": Color(0.3, 0.28, 0.32), "shoes": Color(0.3, 0.25, 0.2),
	"hair": "Hair_Buns", "hair_color": Color(0.88, 0.88, 0.88), "height": 1.58, "skin": Color(0.96, 0.8, 0.74), "belly": 0.4}
## Repliikit tilanteittain: [puhuja, repliikki]. Puhujat: reiska, juntti, rekka, mummo, raija.
const SAY := {
	"start": [["reiska", "Kello käy, kun mää sanon NYT!"], ["juntti", "Seittemän. Sitä ei kukaan riko."]],
	"cheer": [["mummo", "Pureskele kunnolla, poika!"], ["rekka", "Tahti päälle! Haukku, pure, pure!"],
		["rekka", "Älä hidastele, Raahessa syödään nopeemmin!"], ["mummo", "Kyllä sää jaksat, isokin mies."]],
	"doubt": [["juntti", "Se on jo punanen. Ei se jaksa."], ["juntti", "Turhaan yrität. Mun ennätys pysyy."],
		["reiska", "Kahvia ei saa pöytään ennen ku haaste on ohi."], ["juntti", "Kato sen naamaa, se on ihan vihree."]],
	"soda": [["reiska", "Limu ei oo huijaamista. Melkein."], ["juntti", "Huijari juo limua."], ["mummo", "Juo, juo, se auttaa."]],
	"full": [["mummo", "Älä nyt vaan oksenna pöytään!"], ["juntti", "Kohta tulee takasin. Mää tiän."], ["reiska", "Ämpäri on tiskin alla."]],
	"tie": [["juntti", "Ei... ei voi olla."], ["rekka", "TASAN SEITTEMÄN! Vielä yks!"]],
	"record": [["reiska", "UUSI ENNÄTYS! Mää haen tussin!"], ["juntti", "Huijausta! Ne oli pienempiä piirakoita!"]],
}
const COUNT := ["YKS!", "KAKS!", "KOLME!", "NELJÄ!", "VIIS!", "KUUS!", "SEITTEMÄN!", "KAHEKSAN!", "YHEKSÄN!", "KYMMENEN!"]

var record := 7
var record_holder := "Juntti"
var drunk := 0.0
var raija: Node3D  # world.reippari_raija: piiloon luukulta, Raija tulee pöydän ääreen

var _hud: CanvasLayer
var _ui: Control
var _info: Label
var _keys: Control
var _tip: Label
var _done := false
var _t := -2.0  # alkulaskenta
var _pies := 0
var _bite := 0  # haukkuja nykyisestä piirakasta
var _chew := 0  # pureskelut jäljellä
var _last := ""
var _belly := 0.0
var _soda_t := 0.0
var _jaw := 0.0
var _tip_t := 3.0
var _new_pie := 0.0  # uusi piirakka nousee käteen
var _said := {}

var _cam: Camera3D
var _cam_base := Basis()
var _pie: Node3D
var _slices: Array[Node3D] = []
var _bitten: Array[Node3D] = []  # puraisupinnat (näkyy edessä olevassa palassa)
var _hand_shell: Array = []  # kädessä olevan piirakan kuori (_shell)
var _cap_bite := -1  # minkä haukun päätypinnat on rakennettu
var _bottle: Node3D
var _crumbs: CPUParticles3D
var _plate_pies: Array[Node3D] = []
var _people := {}  # avain -> hahmo
var _bubbles := {}  # avain -> [Label3D, aika]


func _ready() -> void:
	_build_scene()
	_cam = Camera3D.new()
	_cam.fov = 70.0
	add_child(_cam)
	_cam.current = true
	_cam.position = EYE
	_cam.look_at(to_global(LOOK), Vector3.UP)
	_cam_base = _cam.basis
	_build_hand()
	_build_hud()
	_tip.text = "Raija: \"Ennätys on %s, %d piirakkaa. Kello käy kun sanon nyt...\"" % [record_holder, record]
	_event("start")


# --- Rakennus ------------------------------------------------------------------

func _build_scene() -> void:
	# Lautanen ja pino piirakoita pöydällä.
	B.mesh(self, B.cyl(0.2, 0.17, 0.02, 20), PLATE, Color(0.97, 0.97, 0.95))
	for k in 9:
		var p := Node3D.new()
		# Kuusi pohjalle kahteen riviin ja kolme päälle: keko lautasella.
		p.position = PLATE + (Vector3(-0.055 + (k % 2) * 0.11, 0.02, -0.07 + int(k / 2.0) * 0.07) if k < 6 else Vector3(0.0, 0.07, -0.06 + (k - 6) * 0.06))
		p.rotation.y = 0.1 * ((k * 7) % 3) - 0.1
		add_child(p)
		for i in BITES:  # lautasen piirakat samoista paloista kuin kädessä
			var s := Node3D.new()
			s.position = Vector3(-0.084 + i * 0.042, 0, 0)
			p.add_child(s)
			_pie_slice(s, i, -1 if i == 0 else (1 if i == BITES - 1 else 0))
		_fit_shell(_shell(p, 300 + k), -0.108, 0.108)
		p.scale = Vector3.ONE * 0.5
		_plate_pies.append(p)
	# Katsojat kerääntyvät pöydän ympärille: Raija ja grillin omistaja Reiska vastapäätä (henkilökuntakin tuli ulos),
	# Juntti kädet puuskassa pöydän päässä, mummo toisessa päässä ja rekkamies vastapäisellä penkillä.
	_person("raija", RAIJA, Vector3(5.05, 0, -4.8))
	_person("reiska", REISKA, Vector3(5.75, 0, -4.85))
	_person("juntti", Looks.JUNTTI, Vector3(6.75, 0, -4.75))  # pöydän päässä
	_person("rekka", REKKAMIES, Vector3(4.3, 0.0, -4.45), true)  # vastapäisellä penkillä
	_person("mummo", MUMMO, Vector3(3.9, 0, -4.75))
	# Reiskan esiliina ja mummon kahvikuppi.
	var apron := B.mesh(_people.reiska, B.boxm(Vector3(0.38, 0.6, 0.02)), Vector3(0, 0.95, -0.2), Color(0.98, 0.98, 0.98))
	apron.rotation.x = 0.1
	var cup := Node3D.new()
	_people.mummo.attach("hand_r", cup, Vector3(0, -0.05, 0))
	B.mesh(cup, B.cyl(0.04, 0.035, 0.08, 10), Vector3.ZERO, Color(0.95, 0.95, 0.92))
	# Juntti kädet puuskassa.
	var j: Node3D = _people.juntti
	for side in [["_l", -1.0], ["_r", 1.0]]:
		var s: float = side[1]
		j.set_ik("arm" + side[0], "upperarm" + side[0], "lowerarm" + side[0], "hand" + side[0], Vector3(-s * 0.12, 1.25, -0.2),
			Vector3(s * 0.4, 1.1, 0.2))  # hahmon avaruudessa
	if raija != null:
		raija.visible = false  # Raija tuli luukulta pöydän ääreen


func _person(key: String, look: Dictionary, at: Vector3, sitting := false) -> void:
	var c := Looks.make(self, look)
	var to := EYE - at
	c.rotation.y = atan2(-to.x, -to.z)
	if sitting:
		c.play("Sitting_Idle", 0.0)
		c.anim.advance(0.01)
		var pelvis: Vector3 = c.basis * c.bone_position("pelvis")
		c.position = at + Vector3(-pelvis.x, 0.02, -pelvis.z)
	else:
		c.position = at
		c.play("Idle", 0.0)
	c.set_meta("pose", "Sitting_Idle" if sitting else "Idle")
	_people[key] = c
	_bubbles[key] = [_bubble(at + Vector3(0, 1.55 if sitting else 2.05, 0)), 0.0]


func _bubble(at: Vector3, global := false) -> Label3D:
	var b := Label3D.new()
	b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.font_size = 40
	b.pixel_size = 0.0035
	b.outline_size = 12
	b.modulate = Color(1.0, 0.97, 0.88)
	b.no_depth_test = true
	b.width = 520.0
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(b)
	if global:
		b.global_position = at
	else:
		b.position = at
	return b


## Yksi pala lihapiirakkaa kaikilla, haastekoko (pituus X-akselilla 0,042 m; viisi palaa = koko piirakka, PROFILE
## antaa palan paksuuden, joten piirakka on soikea ja suippenee päistä). Uppopaistettu kiiltävän tummanruskea kuori,
## kullanruskea paistoreuna halkiossa ja paistokuplia kannessa; halkaistu ja avattu kuin simpukka (kansi nojaa taakse,
## -Z). Sisällä valkoinen sisus, kolme vaaleanpunaista nakkia (päät pyöreinä piirakan päistä ulos), kiiltävä
## kurkkusalaattikasa, ketsupin ja sinapin siksakit valumineen ja sipulisilppu. k = palan järjestys, ends = -1 / 1
## pyöristetty pää (0 keskipala).
const PROFILE := [0.74, 0.95, 1.0, 0.95, 0.74]
const HAND_X0 := -0.03  # kädessä olevan piirakan kuoren X-väli
const HAND_X1 := 0.198


static func _pie_slice(s: Node3D, k: int, ends := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 155 + k * 31
	var L := 0.042
	var r: float = 0.042 * PROFILE[clampi(k, 0, PROFILE.size() - 1)]
	# Nakit: kolme rinnakkain; piirakan päissä pyöreä pää pilkistää ulos.
	for i in 3:
		var z: float = (-0.022 + i * 0.022) * r / 0.042
		var y := 0.034 - absf(z) * 0.12
		var n := B.mesh(s, B.cyl(0.0125, 0.0125, L, 12), Vector3(0, y, z - 0.003), SAUSAGE, Vector3(0, 0, 90))
		n.material_override = _gloss(SAUSAGE, 0.3)
		if ends != 0:
			var tip := B.mesh(s, B.sphere(0.0125, 10), Vector3(ends * (L * 0.5 + 0.004 + i * 0.003), y, z - 0.003), SAUSAGE)
			tip.material_override = _gloss(SAUSAGE, 0.3)
			tip.scale = Vector3(1.4, 1.0, 1.0)
	# Kurkkusalaatti: kiiltävä kasa pieniä paloja, pursuaa nakkien väliin ja yli reunojen.
	var heap := 9 if ends != 0 else 18
	for i in heap:
		var p := Vector3(rng.randf_range(-0.019, 0.019), 0.044 + rng.randf_range(0.0, 0.018) * (1.0 - absf(float(ends)) * 0.4),
			rng.randf_range(-0.032, 0.028) * r / 0.042)
		var col := RELISH.lightened(rng.randf_range(-0.2, 0.25))
		var c := B.mesh(s, B.boxm(Vector3(0.007, 0.005, 0.007) * rng.randf_range(0.8, 1.5)), p, col)
		c.material_override = _gloss(col, 0.25)
		c.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * 1.5
	# Ketsupin ja sinapin siksakit (kolme lenkkiä palassa) ja valuvat pisarat reunoilta.
	for sauce in [[KETCHUP, -0.008, 0.058], [MUSTARD, 0.009, 0.061]]:
		for i in 3:
			var x := -L * 0.5 + (i + 0.5) * L / 3.0
			var dz: float = (0.012 if (i + k) % 2 == 0 else -0.012) * r / 0.042
			var seg := B.mesh(s, B.boxm(Vector3(0.016, 0.004, 0.006)), Vector3(x, sauce[2], sauce[1] + dz * 0.5), sauce[0])
			seg.material_override = _gloss(sauce[0], 0.2)
			seg.rotation.y = 0.8 if dz > 0.0 else -0.8
	for i in 2:
		var drip_c: Color = KETCHUP if (k + i) % 2 == 0 else MUSTARD
		var d := B.mesh(s, B.sphere(0.005, 8), Vector3(rng.randf_range(-0.015, 0.015), 0.018 - i * 0.008, -r * 0.98), drip_c)
		d.material_override = _gloss(drip_c, 0.2)
		d.scale = Vector3(1.0, 1.6, 0.8)  # valuva tippa
	for i in 4:  # sipulisilppu
		B.mesh(s, B.boxm(Vector3(0.005, 0.004, 0.005)), Vector3(rng.randf_range(-0.018, 0.018), 0.064 + rng.randf() * 0.004,
			rng.randf_range(-0.022, 0.016)), Color(0.97, 0.95, 0.88))


## Piirakan kuori kahtena yhtenäisenä puolikkaana (ei paloina): pohja on veneenmuotoinen puolikas soikiota, sisus
## ylöspäin, ja kansi kupera puolikas, joka on saranoitu takareunasta (-Z) ja avattu kuin simpukka. Uppopaistettu
## pinta kiiltää, halkion reunoilla kullanruskea paistoreuna ja kannessa tummia paistokuplia. Kuori pysyy koko
## piirakan mittaisena; haukattu osa leikataan pois varjostimella (_set_cut): kaareva puraisu hammasjälkineen, ja
## leikkauksesta näkyy kuoren sisäpinta leivän sisuksen värisenä. Palauttaa [pohja, kannen sarana, kansi].
static func _shell(parent: Node3D, seed_i: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var bottom := Node3D.new()
	parent.add_child(bottom)
	_half(bottom, true, rng)
	var hinge := Node3D.new()
	parent.add_child(hinge)
	var lid := Node3D.new()
	lid.position = Vector3(0, 0, 0.044)
	hinge.add_child(lid)
	_half(lid, false, rng)
	hinge.rotation.x = -0.55  # etureuna nousee, kupu nojaa taakse
	return [bottom, hinge, lid]


## Yksikkökokoinen puolikas (säde 1): kupu alas (pohja) tai ylös (kansi), sisus halkiopinnassa ja paistoreuna.
static func _half(n: Node3D, down: bool, rng: RandomNumberGenerator) -> void:
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 2.0  # koko pallon korkeus; puolipallona 0..1
	dome.is_hemisphere = true
	dome.radial_segments = 28
	dome.rings = 10
	var d := MeshInstance3D.new()
	d.mesh = dome
	d.rotation.x = PI if down else 0.0
	n.add_child(d)
	_bun_shade(d, BUN, 0.28)
	var face := B.mesh(n, B.cyl(0.97, 0.97, 0.06, 28), Vector3(0, 0.03 if down else -0.03, 0), CRUMB)  # sisus
	_bun_shade(face, CRUMB, 0.9)
	var rim := B.mesh(n, B.cyl(1.0, 1.0, 0.12, 28), Vector3(0, -0.06 if down else 0.06, 0), FRY_EDGE)  # paistoreuna
	_bun_shade(rim, FRY_EDGE, 0.35)
	var spots := 4 if down else 9
	for i in spots:  # paistokuplat ja tummemmat läikät kuvun pinnalla
		var a := rng.randf() * TAU
		var t := rng.randf_range(0.25, 0.85)
		var p := Vector3(cos(a) * t, sqrt(1.0 - t * t) * (-1.0 if down else 1.0), sin(a) * t)
		var b := B.mesh(n, B.sphere(0.09 + rng.randf() * 0.07, 8), p, BUN.darkened(0.35))
		_bun_shade(b, BUN.darkened(0.35), 0.3)


## Kuori X-välille x0..x1: pohjan ja kannen pituus, kannen leveys ja kuvun korkeus.
static func _fit_shell(sh: Array, x0: float, x1: float) -> void:
	var cx := (x0 + x1) / 2.0
	var hl := (x1 - x0) / 2.0
	var bottom: Node3D = sh[0]
	bottom.position = Vector3(cx, 0.022, 0)
	bottom.scale = Vector3(hl, 0.026, 0.045)
	var hinge: Node3D = sh[1]
	hinge.position = Vector3(cx, 0.024, -0.045)
	var lid: Node3D = sh[2]

	lid.scale = Vector3(hl * 0.98, 0.022, 0.044)  # matala kupu

## Puraisu: kuoresta leikataan suoraan pois kaikki x < cut (piirakan avaruudessa; -INF = ei puraisua). Varjostin
## tarvitsee leikkaustason maailman koordinaateissa, joten kutsutaan joka ruutu (kamera liikkuu).
static func _set_cut(sh: Array, pie: Node3D, cut: float) -> void:
	var gt := pie.global_transform
	var o: Vector3 = gt * Vector3(cut, 0, 0)
	var ax: Vector3 = gt.basis.x.normalized()
	if cut <= -1.0:  # ei puraisua: taso kauas
		o = Vector3(0, -1000, 0)
		ax = Vector3.UP
	for root in [sh[0], sh[1]]:
		for mi in (root as Node).find_children("*", "MeshInstance3D", true, false):
			if mi.name == "Puraisu":
				continue
			var g := mi as GeometryInstance3D
			g.set_instance_shader_parameter("cut_o", o)
			g.set_instance_shader_parameter("cut_x", ax)


## Puraisukohdan umpinaiset päätypinnat kuoren puolikkaille (kuten nakkien lieriöillä on omat päätynsä). Leikkaus on
## suora, joten kuoren poikkileikkaus on tarkalleen puolisoikio: yksikköpuolipallon leikkaus kohdassa u on
## puoliympyrä säteellä sqrt(1 - u²), ja puolikkaan solmun skaalaus venyttää sen kuoren muotoon. Keskeltä leivän
## sisuksen värinen, reunalta paahtunut. Rakennetaan uudelleen vain haukun vaihtuessa.
static func _bite_caps(sh: Array, cut: float, x0: float, x1: float) -> void:
	var cx := (x0 + x1) / 2.0
	var hl := (x1 - x0) / 2.0
	for half in [[sh[0], -1.0, hl], [sh[2], 1.0, hl * 0.98]]:
		var node: Node3D = half[0]
		var old := node.get_node_or_null("Puraisu")
		if old != null:
			old.free()
		if cut <= -1.0:
			continue
		var u := (cut + 0.0004 - cx) / float(half[2])  # hieman leikkauksen sisäpuolelle, ettei rakoa näy
		var rho := sqrt(maxf(0.0, 1.0 - u * u))
		var sgn: float = half[1]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 32
		for i in n:
			var a0 := PI * i / n
			var a1 := PI * (i + 1) / n
			for p in [[Vector3(u, 0, 0), Color(0.95, 0.9, 0.76)],
					[Vector3(u, sgn * sin(a0) * rho, cos(a0) * rho), Color(0.82, 0.58, 0.32)],
					[Vector3(u, sgn * sin(a1) * rho, cos(a1) * rho), Color(0.82, 0.58, 0.32)]]:
				st.set_color(p[1])
				st.add_vertex(p[0])
		var mi := MeshInstance3D.new()
		mi.name = "Puraisu"
		mi.mesh = st.commit()
		mi.material_override = _cap_mat()
		node.add_child(mi)


static var _cap_m: StandardMaterial3D


## Päätypinta: valaisematon (pinnan suunta on venytetyssä kuoressa mikä sattuu), väri pistekohtaisesti.
static func _cap_mat() -> StandardMaterial3D:
	if _cap_m == null:
		_cap_m = StandardMaterial3D.new()
		_cap_m.vertex_color_use_as_albedo = true
		_cap_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cap_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _cap_m


const BUN_SHADER := """
shader_type spatial;
// Lihapiirakan kuori: kiiltävä pinta, ja puraisu leikkaa suoraan pois kaiken leikkaustason takaa (päätypinta
// _bite_caps sulkee leikkauksen).
instance uniform vec4 albedo : source_color = vec4(1.0);
instance uniform float rough = 0.3;
instance uniform vec3 cut_o = vec3(0.0, -1000.0, 0.0);
instance uniform vec3 cut_x = vec3(0.0, 1.0, 0.0);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (dot(wpos - cut_o, cut_x) < 0.0) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = rough;
	SPECULAR = 0.7;
}
"""
static var _bun_sh: Shader
static var _bun_sm: ShaderMaterial


## Kuoren osa samalla leikkaavalla varjostimella (väri ja kiilto instanssikohtaisina).
static func _bun_shade(mi: MeshInstance3D, col: Color, rough: float) -> void:
	if _bun_sm == null:
		_bun_sh = Shader.new()
		_bun_sh.code = BUN_SHADER
		_bun_sm = ShaderMaterial.new()
		_bun_sm.shader = _bun_sh
	mi.material_override = _bun_sm
	mi.set_instance_shader_parameter("albedo", col)
	mi.set_instance_shader_parameter("rough", rough)


static var _gloss_m := {}


## Kiiltävä materiaali (rasva, kastike, nakki): välimuistissa värin mukaan.
static func _gloss(col: Color, rough: float) -> StandardMaterial3D:
	var key := col.to_html() + str(rough)
	if not _gloss_m.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		m.specular = 0.7
		_gloss_m[key] = m
	return _gloss_m[key]


## Piirakka kädessä kameran edessä: viisi palaa (vasen pää syödään ensin), kuori, nakit ja mausteet. Limupullo vasemmalla.
func _build_hand() -> void:
	_pie = Node3D.new()
	_cam.add_child(_pie)
	# Piirakka poikittain oikeassa kädessä: palat vasemmalta oikealle, vasen pää (suun puoli) syödään ensin.
	for k in BITES:
		var s := Node3D.new()
		s.position = Vector3(k * 0.042, 0, 0)
		_pie.add_child(s)
		_pie_slice(s, k, -1 if k == 0 else (1 if k == BITES - 1 else 0))
		# Puraisujälki: katkaistujen nakkien poikkipinnat (kuori jatkuu hieman puraisukohdan yli, _fit_shell).
		var bite := Node3D.new()
		bite.position = Vector3(-0.0215, 0, 0)
		s.add_child(bite)
		var r: float = 0.042 * PROFILE[k]
		for i in 3:
			var z: float = (-0.022 + i * 0.022) * r / 0.042
			B.mesh(bite, B.cyl(0.012, 0.012, 0.002, 12), Vector3(0, 0.034 - absf(z) * 0.12, z - 0.003), SAUSAGE.lightened(0.15), Vector3(0, 0, 90))
		bite.visible = false
		_slices.append(s)
		_bitten.append(bite)
	_hand_shell = _shell(_pie, 7)
	_fit_shell(_hand_shell, HAND_X0, HAND_X1)
	_bottle = Node3D.new()
	_cam.add_child(_bottle)
	var glass := B.mesh(_bottle, B.cyl(0.026, 0.028, 0.16, 12), Vector3(0, 0.08, 0), Color(0.2, 0.55, 0.25))
	glass.transparency = 0.25
	B.mesh(_bottle, B.cyl(0.01, 0.024, 0.06, 10), Vector3(0, 0.19, 0), Color(0.2, 0.55, 0.25))
	B.mesh(_bottle, B.cyl(0.029, 0.029, 0.05, 12), Vector3(0, 0.07, 0), Color(0.95, 0.5, 0.1))  # etiketti
	_crumbs = CPUParticles3D.new()
	_crumbs.position = Vector3(0.0, -0.09, -0.22)
	_crumbs.emitting = false
	_crumbs.one_shot = true
	_crumbs.amount = 14
	_crumbs.lifetime = 0.6
	_crumbs.explosiveness = 0.9
	_crumbs.direction = Vector3(0, -0.3, -1)
	_crumbs.spread = 50.0
	_crumbs.initial_velocity_min = 0.3
	_crumbs.initial_velocity_max = 0.8
	_crumbs.gravity = Vector3(0, -3, 0)
	var cm := BoxMesh.new()
	cm.size = Vector3(0.008, 0.008, 0.008)
	cm.material = B.mat(CRUST.darkened(0.1))
	_crumbs.mesh = cm
	_cam.add_child(_crumbs)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	_hud.add_child(_ui)
	_info = _label(24, 20.0, false)
	_tip = _label(22, -86.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	_hud.add_child(_keys)


func _label(fs: int, y: float, bottom: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.anchor_right = 1.0
	if bottom:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(l)
	return l


# --- Puheet --------------------------------------------------------------------

const NAMES := {"reiska": "Reiska", "juntti": "Juntti", "rekka": "Rekkamies", "mummo": "Mummo", "raija": "Raija"}


func _speak(who: String, text: String, t := 2.4) -> void:
	if not _bubbles.has(who):
		return
	var b: Label3D = _bubbles[who][0]
	b.text = text
	_bubbles[who][1] = t
	_tip.text = "%s: \"%s\"" % [NAMES[who], text]
	_tip_t = 4.0
	if _people.has(who):
		var c: Node3D = _people[who]
		if c.get_meta("pose") == "Idle":
			c.play("Idle_Talking", 0.2)


## Tilanteen repliikki satunnaiselta puhujalta (sama repliikki ei toistu heti).
func _event(kind: String) -> void:
	var opts: Array = (SAY[kind] as Array).filter(func(l): return _said.get(kind, "") != l[1])
	var l: Array = opts.pick_random() if not opts.is_empty() else SAY[kind].pick_random()
	_said[kind] = l[1]
	_speak(l[0], l[1])


# --- Peli ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_animate(delta)
	if _done:
		return
	_t += delta
	_jaw = maxf(0.0, _jaw - delta * 4.0)
	_soda_t = maxf(0.0, _soda_t - delta)
	_new_pie = maxf(0.0, _new_pie - delta * 3.0)
	_ui.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish("Luovutit. Raija: \"Heikko sukupolvi.\"")
		_speak("juntti", "Mitä mää sanoin.")
		return
	if _t < 0.0:
		_info.text = "Lihapiirakkahaaste alkaa: %d" % ceili(-_t)
		return
	var full_before := _belly
	_belly = maxf(0.0, _belly - DIGEST * delta)
	if _soda_t <= 0.0:
		if Input.is_action_just_pressed("jump") and _chew == 0:
			_bitten[_bite].visible = false
			_slices[_bite].visible = false
			_bite += 1
			if _bite < BITES:
				_bitten[_bite].visible = true
			_chew = CHEWS
			_belly += BITE_FILL * (1.0 + drunk * 0.3)
			_jaw = 1.0
			_crumbs.restart()
			Sfx.play("pickup", -14.0, 0.6)
			if _bite >= BITES:
				_bite = 0
				_pies += 1
				_new_pie = 1.0
				for k in BITES:
					_slices[k].visible = true
					_bitten[k].visible = false
				if _pies <= _plate_pies.size():
					_plate_pies[_plate_pies.size() - _pies].visible = false
				Sfx.play("win_small", -10.0, 1.3)
				if _pies == record + 1:
					_tip.text = "UUSI ENNÄTYS! Raija hakee tussin."
					_event("record")
				elif _pies == record:
					_event("tie")
				else:
					_speak("rekka", COUNT[mini(_pies - 1, COUNT.size() - 1)], 1.6)
		for k in [["left", "A"], ["right", "D"]]:
			if Input.is_action_just_pressed(k[0]) and _chew > 0 and k[1] != _last:
				_last = k[1]
				_chew -= 1
				_jaw = 0.6
		if Input.is_action_just_pressed("forward"):
			_soda_t = SODA_T
			_belly = maxf(0.0, _belly - SODA)
			Sfx.play("glass", -10.0, 1.5)
			if randf() < 0.5:
				_event("soda")
	if full_before < 0.75 and _belly >= 0.75:
		_event("full")
	if _belly >= 1.0:
		_finish("EI MAHDU! Vatsa täynnä. %d piirakkaa." % _pies)
		_speak("reiska", "Ei mahdu! Haaste ohi.")
		return
	if _t >= TIME:
		_finish("Aika loppu! %d piirakkaa." % _pies)
		_speak("reiska", "AIKA! %d piirakkaa." % _pies)
		return
	_tip_t -= delta
	if _tip_t <= 0.0 and _pies <= record:
		_tip_t = 4.5
		var r := randf()
		if r < 0.25:
			_speak("raija", LINES.pick_random())
		elif r < 0.6:
			_event("cheer")
		else:
			_event("doubt")
	_info.text = "Piirakoita %d · aikaa %d s · ennätys %s %d" % [_pies, ceili(TIME - _t), record_holder, record]
	_keys.set_text("%s haukkaa · %s / %s pureskele · %s limua · %s luovuta" % [Settings.cap("jump"), Settings.cap("left"),
		Settings.cap("right"), Settings.cap("forward"), Settings.cap("mount")])


func _finish(text: String) -> void:
	_done = true
	_tip.text = text
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		if raija != null:
			raija.visible = true  # takaisin luukulle
		finished.emit(_pies)
		queue_free())


# --- Animaatio -----------------------------------------------------------------

## Kamera: pureskelu nyökyttää, limu kallistaa taakse ja täyttyvä vatsa huojuttaa. Piirakka käy suulla haukatessa,
## uusi nousee käteen ja limupullo nousee huulille.
func _animate(delta: float) -> void:
	var sway := maxf(0.0, _belly - 0.55) * 2.2
	var tt := Time.get_ticks_msec() / 1000.0
	var nod := sin(_jaw * PI) * 0.06
	var tilt := sin(clampf(_soda_t / SODA_T, 0.0, 1.0) * PI) * 0.35
	var b := _cam_base
	b = b.rotated(b.x, tilt - nod)
	b = b.rotated(Vector3.UP, sin(tt * 1.3) * 0.05 * sway)
	b = b.rotated(b.z, sin(tt * 0.9) * 0.05 * sway)
	_cam.basis = b
	_cam.position = EYE + Vector3(0, -0.02 * _jaw, 0)
	# Piirakka oikeassa kädessä: haukatessa suulle, pureskellessa laskee hieman.
	var bite_u := maxf(_jaw - 0.6, 0.0) / 0.4
	_pie.position = Vector3(0.05, -0.12 - _new_pie * 0.25, -0.3).lerp(Vector3(-0.035, -0.065, -0.17), bite_u)
	_pie.rotation = Vector3(0.6 - bite_u * 0.2, 0.15 + bite_u * 0.3, 0.0)
	if not _hand_shell.is_empty():  # puraisu leikkaa kuoren (maailman koordinaateissa, joten joka ruutu)
		_set_cut(_hand_shell, _pie, _bite * 0.042 - 0.021 if _bite > 0 else -INF)
		if _cap_bite != _bite:
			_cap_bite = _bite
			_bite_caps(_hand_shell, _bite * 0.042 - 0.021 if _bite > 0 else -INF, HAND_X0, HAND_X1)
	# Pullo vasemmassa kädessä: juodessa huulille kallellaan.
	var drink := sin(clampf(_soda_t / SODA_T, 0.0, 1.0) * PI)
	_bottle.position = Vector3(-0.22, -0.26, -0.42).lerp(Vector3(-0.05, -0.1, -0.2), drink)
	_bottle.rotation = Vector3(-drink * 1.7, 0, 0.1)
	# Puhekuplat hiipuvat.
	for k in _bubbles:
		_bubbles[k][1] -= delta
		if _bubbles[k][1] <= 0.0 and (_bubbles[k][0] as Label3D).text != "":
			(_bubbles[k][0] as Label3D).text = ""
			if _people.has(k):
				_people[k].play(_people[k].get_meta("pose"), 0.3)


# --- HUD -----------------------------------------------------------------------

func _draw_ui() -> void:
	var sz := _ui.size
	var font := ThemeDB.fallback_font
	# Täyttyvä vatsa: reunat vihertävät.
	var green := clampf((_belly - 0.6) * 1.6, 0.0, 0.55)
	if green > 0.0:
		for k in 6:
			var w := sz.x * (0.03 + k * 0.02)
			var a := green * (1.0 - k / 6.0) * 0.5
			var col := Color(0.35, 0.55, 0.15, a)
			_ui.draw_rect(Rect2(Vector2.ZERO, Vector2(w, sz.y)), col)
			_ui.draw_rect(Rect2(Vector2(sz.x - w, 0), Vector2(w, sz.y)), col)
			_ui.draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x, w * 0.5)), col)
			_ui.draw_rect(Rect2(Vector2(0, sz.y - w * 0.5), Vector2(sz.x, w * 0.5)), col)
	# Vatsamittari vasemmalla.
	var bar := Rect2(Vector2(40, sz.y * 0.16), Vector2(36, sz.y * 0.45))
	MG.box(_ui, bar.grow(4), Color(0.08, 0.08, 0.08, 0.9), 8)
	var fill := clampf(_belly, 0.0, 1.0)
	MG.grad_rect(_ui, Rect2(Vector2(bar.position.x, bar.end.y - bar.size.y * fill), Vector2(bar.size.x, bar.size.y * fill)),
		Color(0.95, 0.3, 0.2).lerp(Color(0.95, 0.85, 0.2), 1.0 - fill), Color(0.6, 0.2, 0.1))
	_ui.draw_string_outline(font, bar.position + Vector2(-20, bar.size.y + 32), "VATSA", HORIZONTAL_ALIGNMENT_CENTER, 76, 18, 6, Color.BLACK)
	_ui.draw_string(font, bar.position + Vector2(-20, bar.size.y + 32), "VATSA", HORIZONTAL_ALIGNMENT_CENTER, 76, 18, Color.WHITE)
	# Pureskeluohje: A ja D vuorotellen keskellä alhaalla.
	if _chew > 0 and not _done:
		for i in 2:
			var key: String = ["A", "D"][i]
			var kr := Rect2(Vector2(sz.x * 0.08 + i * 90, sz.y * 0.74), Vector2(70, 56))  # vasemmalla, ei lautasen päällä
			var lit := key != _last
			MG.box(_ui, kr, Color(0.98, 0.95, 0.85) if lit else Color(0.5, 0.48, 0.45), 8, 4, Color(0.2, 0.15, 0.1), 2)
			_ui.draw_string(font, kr.position + Vector2(0, 40), key, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, 30, Color(0.15, 0.1, 0.05))
	if _t < 0.0:
		_ui.draw_string_outline(font, Vector2(0, sz.y * 0.42), str(ceili(-_t)), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 90, 10, Color.BLACK)
		_ui.draw_string(font, Vector2(0, sz.y * 0.42), str(ceili(-_t)), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 90, Color(1.0, 0.95, 0.4))
