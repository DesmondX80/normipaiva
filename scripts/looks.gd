extends RefCounted
## Hahmojen ulkonäöt character.gd:lle ja yhteiset apurit.

const Character := preload("res://scripts/character.gd")
const B := preload("res://scripts/build.gd")

## Pelaaja: 90-luvun tuulipuku (violetti, turkoosi ja musta) ja kaljamaha superhero-lihasten tilalla.
const PLAYER := {
	"shirt": Color(0.42, 0.18, 0.58), "pants": Color(0.42, 0.18, 0.58), "shoes": Color(0.9, 0.9, 0.88),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.22, 0.15, 0.1), "shine": 0.85, "height": 1.8,
	"tracksuit": {"a": Color(0.08, 0.66, 0.64), "b": Color(0.07, 0.07, 0.09)},
	"stripes": true, "stripe_color": Color(0.08, 0.66, 0.64),
	"belly": 0.75, "bulk": 0.1, "shoulders": -0.55,
}
## Pelaajan asut (vaatekaappi kotona ja Paapelin makuuhuoneessa, main.gd tallentaa valinnan): tuulipuku ja
## Karhu-lippis on oletus. Kaikissa vaaleat hiukset, pukinparta, kello, rannekoru ja tatuointi vasemmassa olkavarressa.
const OUTFITS := {
	"tuulipuku": {"name": "Tuulipuku ja Karhu-lippis"},
	"farkut": {"name": "Farkut, verkkopaita ja rasvaletti"},
	"tyovaatteet": {"name": "Työvaatteet ja Karjala-lippis"},
}
const PLAYER_HAIR := Color(0.82, 0.66, 0.4)
static var outfit := "tuulipuku"
## Pelaajan päähine lippiksen tilalle (kodin vaatekaappi): "" = asun oma lippis, "stetson" = cowboyhattu.
static var hat := ""


## Pelaajan ulkonäkö valitussa asussa (Looks.make lisää asusteet, add_cap lippiksen asun mukaan).
static func player(which := "") -> Dictionary:
	var o := which if which != "" else outfit
	var look: Dictionary = PLAYER.duplicate(true)
	look.merge({"player": true, "outfit": o, "hair_color": PLAYER_HAIR, "skin": Color(1.0, 0.92, 0.84), "tattoo": true,
		"cap": "karhu", "shades": "pilotti", "bare_skin": Color(0.95, 0.75, 0.6)}, true)
	match o:
		"farkut":
			for k in ["tracksuit", "stripe_color"]:
				look.erase(k)
			look.merge({"shirt": Color(0.78, 0.68, 0.5), "net_shirt": true, "shirt_puff": 0.006, "suspenders": true,
				"pants": Color(0.46, 0.6, 0.78), "jeans": true, "belt_y": 0.99, "pants_puff": 0.01,
				"shoes": Color(0.33, 0.22, 0.13), "stripes": false, "shine": 0.0, "hair": "", "letti": true,
				"shades": "valkoiset", "chain": true, "cap": ""}, true)
		"tyovaatteet":
			for k in ["tracksuit", "stripe_color"]:
				look.erase(k)
			look.merge({"shirt": Color(0.62, 0.1, 0.08), "flannel": true, "pants": Color(0.24, 0.25, 0.27), "workwear": true,
				"shoes": Color(0.1, 0.09, 0.08), "stripes": false, "shine": 0.0, "cap": "karjala", "shades": ""}, true)
	return look


## Pelaajan malli uuteen asuun paikallaan (asun vaihto vaatekaapilla): asusteet ja lippis uudelleen.
static func restyle_player(c: Node3D) -> void:
	var look := player()
	var capped: bool = c.get_meta("capped", false)
	c.restyle(look)
	_add_player_gear(c, look)
	if capped:
		add_cap(c)


## Lauantain Raahen jätkät Siitarin pajatsolla (siitari_interior.gd, fight.gd "raahelainen"): takatukka ja
## farkkuliivi, toisella hevirokkipaita ja parta.
const RAAHEN_JATKAT := [
	{"shirt": Color(0.36, 0.48, 0.66), "pants": Color(0.08, 0.08, 0.1), "shoes": Color(0.92, 0.92, 0.9), "hair": "Hair_Long",
		"hair_color": Color(0.62, 0.5, 0.3), "height": 1.83, "belly": 0.5, "bulk": 0.2, "shoulders": 0.2},
	{"shirt": Color(0.07, 0.07, 0.08), "pants": Color(0.32, 0.44, 0.62), "shoes": Color(0.1, 0.08, 0.06), "hair": "Hair_Buzzed",
		"hair_color": Color(0.3, 0.22, 0.14), "beard": true, "height": 1.8, "belly": 0.7, "bulk": 0.35},
]
## Siitarin seurueen kaksi hedelmäpelillä (siitari_interior.gd): nainen pelaa, mies katsoo vieressä. Mies
## tappelee pihalla, jos jukeboksista laitetaan ysäriä (fight.gd "hedelmamies").
const HEDELMA_PELAAJAT := [
	{"model": "female", "shirt": Color(0.9, 0.85, 0.95), "pants": Color(0.04, 0.04, 0.05), "shoes": Color(0.05, 0.05, 0.05), "hair": "Hair_Long",
		"hair_color": Color(0.07, 0.05, 0.04), "height": 1.6, "skin": Color(0.92, 0.76, 0.62), "shine": 0.7},
	{"shirt": Color(0.12, 0.12, 0.14), "pants": Color(0.12, 0.12, 0.14), "shoes": Color(0.05, 0.05, 0.05), "hair": "Hair_SimpleParted",
		"hair_color": Color(0.1, 0.08, 0.06), "height": 1.76, "skin": Color(0.9, 0.74, 0.6), "belly": 0.5},
]
const JUNTTI := {
	"shirt": Color(0.06, 0.06, 0.07), "pants": Color(0.06, 0.06, 0.07), "shoes": Color(0.95, 0.95, 0.95),
	"hair": "Hair_Long", "hair_color": Color(0.85, 0.72, 0.42), "stripes": true, "shine": 0.35, "height": 1.86, "belly": 1.0, "bulk": 0.35, "shoulders": 0.5, "muscle": -0.35,
}
const ANNA_LIISA := {
	"model": "female", "shirt": Color(0.28, 0.58, 0.54), "pants": Color(0.22, 0.22, 0.27),
	"hair": "Hair_Buns", "hair_color": Color(0.55, 0.22, 0.12), "height": 1.66,
}
## K-Marketin kauppias: juoksukaljojen perään juokseva kung fu -mies (shop_chaser.gd, fight.gd "kauppias").
const KAUPPIAS := {
	"shirt": Color(1.0, 0.42, 0.0), "pants": Color(0.12, 0.12, 0.16), "shoes": Color(0.9, 0.9, 0.92),
	"hair": "Hair_Buzzed", "hair_color": Color(0.55, 0.55, 0.55), "beard": true, "height": 1.86, "belly": 0.3,
	"muscle": 0.4,
}
const CASHIER := {
	"model": "female", "shirt": Color(1.0, 0.42, 0.0), "pants": Color(0.15, 0.15, 0.2),
	"hair": "Hair_Long", "hair_color": Color(0.9, 0.78, 0.45), "height": 1.68,
}
const GRANDPAS := [
	{"shirt": Color(0.6, 0.55, 0.45), "pants": Color(0.3, 0.3, 0.32), "hair": "Hair_Buzzed",
		"hair_color": Color(0.85, 0.85, 0.85), "beard": true, "height": 1.72, "skin": Color(1.0, 0.9, 0.86),
		"belly": 0.35, "bulk": -0.5, "shoulders": -0.5},
	{"shirt": Color(0.4, 0.42, 0.45), "pants": Color(0.25, 0.23, 0.2), "hair": "Hair_SimpleParted",
		"hair_color": Color(0.75, 0.75, 0.75), "height": 1.7, "skin": Color(1.0, 0.9, 0.86),
		"belly": 0.15, "bulk": -0.65, "shoulders": -0.6},
	{"shirt": Color(0.55, 0.35, 0.3), "pants": Color(0.3, 0.3, 0.32), "hair": "Hair_Buzzed",
		"hair_color": Color(0.9, 0.9, 0.9), "beard": true, "height": 1.74, "skin": Color(1.0, 0.9, 0.86),
		"belly": 0.55, "bulk": -0.4, "shoulders": -0.4},
]

const AKKA := {
	"model": "female", "shirt": Color(0.72, 0.1, 0.12), "pants": Color(0.18, 0.26, 0.2), "shoes": Color(0.25, 0.2, 0.15),
	"hair": "Hair_Buns", "hair_color": Color(0.7, 0.68, 0.66), "height": 1.62, "skin": Color(1.0, 0.9, 0.86), "shine": 0.4,
}
const TEENS := [
	{"shirt": Color(0.12, 0.12, 0.13), "pants": Color(0.45, 0.55, 0.7), "shoes": Color(0.95, 0.95, 0.95),
		"hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.2, 0.12), "height": 1.74, "bulk": -0.75, "shoulders": -0.6},
	{"shirt": Color(0.1, 0.35, 0.2), "pants": Color(0.2, 0.2, 0.22), "shoes": Color(0.9, 0.2, 0.2),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.8, 0.65, 0.35), "height": 1.7, "bulk": -0.85, "shoulders": -0.7},
	{"model": "female", "shirt": Color(0.85, 0.4, 0.7), "pants": Color(0.1, 0.1, 0.12), "shoes": Color(0.95, 0.95, 0.95),
		"hair": "Hair_Long", "hair_color": Color(0.12, 0.1, 0.1), "height": 1.65, "bulk": -0.6, "shoulders": -0.4},
]

const ARTO := {
	"shirt": Color(0.62, 0.12, 0.1), "pants": Color(0.22, 0.3, 0.5), "shoes": Color(0.3, 0.22, 0.15),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.45, 0.38, 0.3), "beard": true, "height": 1.8,
}
const PAIVI := {
	"model": "female", "shirt": Color(0.75, 0.2, 0.35), "pants": Color(0.12, 0.12, 0.16), "shoes": Color(0.2, 0.15, 0.12),
	"hair": "Hair_Long", "hair_color": Color(0.45, 0.28, 0.16), "height": 1.68,
}
const JEMMARI := {
	"shirt": Color(0.2, 0.3, 0.55), "pants": Color(0.2, 0.3, 0.55), "shoes": Color(0.12, 0.1, 0.08),
	"hair": "Hair_Buzzed", "hair_color": Color(0.5, 0.4, 0.3), "beard": true, "height": 1.84, "skin": Color(1.0, 0.85, 0.78), "belly": 0.8, "bulk": 0.35, "shoulders": 0.3,
}
## Taksikuski ja Raahen baarin kädenvääntäjä (terästehtaan duunari).
const TAXI_DRIVER := {
	"shirt": Color(0.9, 0.9, 0.88), "pants": Color(0.12, 0.12, 0.14), "shoes": Color(0.08, 0.08, 0.08),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.6, 0.58, 0.55), "height": 1.76, "belly": 0.5,
}
const TERO := {
	"shirt": Color(0.95, 0.5, 0.05), "pants": Color(0.15, 0.2, 0.35), "shoes": Color(0.2, 0.15, 0.1),
	"hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.22, 0.15), "beard": true, "height": 1.88,
	"belly": 0.6, "bulk": 0.6, "shoulders": 0.6, "muscle": 0.3,
}
## Naapurin Sinikka, kylän seksipommi Salosten tapaan: platinablondi, tiimalasivartalo, punainen ysärin
## tuubitoppi, revityt minifarkkushortsit ja punaiset korkokengät, kesärusketus; leveälierinen olkihattu,
## isot aurinkolasit ja kultaiset rengaskorvakorut (glam, ks. add_glam).
const SINIKKA := {
	"model": "female", "shirt": Color(0.82, 0.02, 0.1), "pants": Color(0.38, 0.5, 0.7), "shoes": Color(0.78, 0.02, 0.08),
	"hair": "Hair_Long", "hair_color": Color(0.98, 0.92, 0.72), "height": 1.76, "shine": 0.85, "bulk": -0.2,
	"curves": 1.0, "bust": 2.0, "skin": Color(1.0, 0.97, 0.93), "bare_skin": Color(0.8, 0.58, 0.46), "glam": true,
	"shorts_y": 0.8, "crop_y": 1.23, "tube_y": 1.41, "sleeve_x": 0.2, "denim": true,
}
## Sinikka uimarannalla (world.gd): pienet punaiset lappubikinit, paljaat jalat.
static func sinikka_bikini() -> Dictionary:
	var look: Dictionary = SINIKKA.duplicate()
	look.merge({"shirt": Color(0.9, 0.05, 0.12), "pants": Color(0.9, 0.05, 0.12), "shoes": Color(0.95, 0.75, 0.62), "shine": 0.7,
		"denim": false, "string_bikini": true}, true)
	for k in ["crop_y", "tube_y", "sleeve_x", "shorts_y"]:
		look.erase(k)
	return look


const PEKKA := {
	"shirt": Color(0.3, 0.36, 0.2), "pants": Color(0.35, 0.33, 0.22), "shoes": Color(0.15, 0.12, 0.1),
	"hair": "Hair_Buzzed", "hair_color": Color(0.35, 0.28, 0.2), "beard": true, "height": 1.78, "shine": 0.2, "belly": 0.65, "bulk": 0.1,
}

## Jalkapalloa pelaavat pojat (#29): lyhyitä ja hoikkia.
const POJAT := [
	{"shirt": Color(0.85, 0.15, 0.15), "pants": Color(0.12, 0.12, 0.14), "shoes": Color(0.95, 0.95, 0.95),
		"hair": "Hair_Buzzed", "hair_color": Color(0.85, 0.72, 0.42), "height": 1.35, "bulk": -0.8, "shoulders": -0.8},
	{"shirt": Color(0.15, 0.35, 0.85), "pants": Color(0.2, 0.2, 0.25), "shoes": Color(0.2, 0.2, 0.2),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.35, 0.22, 0.12), "height": 1.4, "bulk": -0.85, "shoulders": -0.8},
	{"shirt": Color(0.95, 0.85, 0.15), "pants": Color(0.25, 0.3, 0.45), "shoes": Color(0.9, 0.3, 0.2),
		"hair": "Hair_Buzzed", "hair_color": Color(0.15, 0.1, 0.08), "height": 1.3, "bulk": -0.8, "shoulders": -0.85},
]
## Kaupan edustan mummot (kettukarkit taskussa): suomalaisen mummon esikuvan mukaan tiivis valkoinen permanentti,
## silmälasit, villatakki, polvipituinen hame ja ruskeat sukkahousut (shorts_y polvessa, bare_skin = sukkahousut)
## tai housut ja kävelykengät. Kaksi ensimmäistä istuu penkillä, kolmas seisoo rollaattorin takana kävelytakissa
## ja huopahatussa. Asusteet (perm, glasses, hat, skirt, lap_skirt) rakentaa mummot.gd.
const MUMMOT := [
	{"model": "female", "shirt": Color(0.56, 0.36, 0.55), "pants": Color(0.32, 0.24, 0.2), "shoes": Color(0.22, 0.14, 0.1),
		"hair": "", "perm": Color(0.93, 0.92, 0.9), "glasses": true, "lap_skirt": true, "shorts_y": 0.5,
		"bare_skin": Color(0.62, 0.48, 0.4), "hair_color": Color(0.85, 0.85, 0.83), "height": 1.56,
		"skin": Color(1.0, 0.9, 0.86), "bulk": 0.35, "belly": 0.3, "shoulders": -0.4, "muscle": -1.0},
	{"model": "female", "shirt": Color(0.36, 0.5, 0.66), "pants": Color(0.4, 0.4, 0.42), "shoes": Color(0.15, 0.12, 0.1),
		"hair": "", "perm": Color(0.78, 0.78, 0.8), "glasses": true, "hair_color": Color(0.75, 0.75, 0.75), "height": 1.6,
		"skin": Color(1.0, 0.9, 0.86), "bulk": 0.15, "belly": 0.2, "shoulders": -0.4, "muscle": -1.0},
	{"model": "female", "shirt": Color(0.66, 0.58, 0.44), "pants": Color(0.2, 0.24, 0.32), "shoes": Color(0.12, 0.1, 0.1),
		"hair": "", "perm": Color(0.95, 0.94, 0.92), "glasses": true, "hat": Color(0.45, 0.1, 0.16),
		"skirt": Color(0.2, 0.24, 0.32), "coat_hem": true, "shorts_y": 0.62, "bare_skin": Color(0.62, 0.48, 0.4),
		"hair_color": Color(0.85, 0.85, 0.83), "height": 1.54, "skin": Color(1.0, 0.9, 0.86), "bulk": 0.25, "belly": 0.35, "shoulders": -0.5, "muscle": -1.0},
]
## Pannu-Sulo, metsän pontikankeittäjä: ruutupaita, maastohousut, harmaa parta.
const SULO := {
	"shirt": Color(0.55, 0.12, 0.1), "pants": Color(0.25, 0.3, 0.2), "shoes": Color(0.12, 0.1, 0.08),
	"hair": "Hair_Buzzed", "hair_color": Color(0.7, 0.7, 0.68), "beard": true, "height": 1.72,
	"skin": Color(1.0, 0.84, 0.78), "belly": 0.45, "bulk": -0.2, "shoulders": -0.3,
}


static func make(parent: Node3D, look: Dictionary) -> Node3D:
	var c := Character.new()
	parent.add_child(c)
	c.setup(look)
	if look.get("player", false):
		c.set_meta("player_body", true)
		_add_player_gear(c, look)
	if look.get("glam", false):
		add_glam(c)
	if look.get("chaplin", false):
		add_chaplin(c)
	if look.get("fringe", false):
		add_fringe(c, look.get("hair_color", Color(0.05, 0.04, 0.04)))
	if look.get("army", false):
		add_army_uniform(c)
	return c


## Glamour-asusteet päähän: leveälierinen olkihattu punaisella nauhalla, isot tummat aurinkolasit ja kultaiset
## rengaskorvakorut. Mitat hahmon avaruudessa pääluun lepopaikasta (kuten lippis, CAP_OFFSET).
static func add_glam(c: Node3D) -> void:
	var straw := Color(0.93, 0.85, 0.62)
	var hat := Node3D.new()
	B.mesh(hat, B.cyl(0.3, 0.3, 0.012, 32), Vector3(0, 0, 0), straw)
	B.mesh(hat, B.cyl(0.1, 0.115, 0.11, 24), Vector3(0, 0.055, 0), straw)
	B.mesh(hat, B.cyl(0.117, 0.117, 0.035, 24), Vector3(0, 0.02, 0), Color(0.8, 0.03, 0.1))
	hat.rotation.x = deg_to_rad(-8)  # lieri hieman kallellaan taaksepäin
	c.attach("Head", hat, Vector3(0, 0.15, -0.01))
	var shades := Node3D.new()
	var dark := Color(0.04, 0.03, 0.03)
	for s in [-1.0, 1.0]:
		B.mesh(shades, B.sphere(0.5, 12), Vector3(s * 0.037, 0, 0), dark).scale = Vector3(0.066, 0.052, 0.02)
		B.mesh(shades, B.boxm(Vector3(0.006, 0.006, 0.09)), Vector3(s * 0.07, 0.008, -0.045), Color(0.85, 0.7, 0.3))
	B.mesh(shades, B.boxm(Vector3(0.018, 0.005, 0.005)), Vector3(0, 0.012, 0), Color(0.85, 0.7, 0.3))
	c.attach("Head", shades, Vector3(0, 0.07, 0.105))
	for s in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.019
		tm.outer_radius = 0.024
		tm.rings = 16
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = B.mat(Color(0.95, 0.75, 0.25)).duplicate()
		(ring.material_override as StandardMaterial3D).metallic = 0.9
		(ring.material_override as StandardMaterial3D).roughness = 0.25
		ring.rotation = Vector3(0, 0, PI / 2.0)
		c.attach("Head", ring, Vector3(s * 0.072, 0.015, 0.005))


## Charlie Chaplinin hammasharjaviikset nenän alle: pieni musta, hieman pyöristetty töyhtö (mitat kuten glam-asusteissa
## pääluun lepopaikasta hahmon avaruudessa, kasvot -Z).
static func add_chaplin(c: Node3D) -> void:
	var m := Node3D.new()
	var black := Color(0.04, 0.035, 0.03)
	B.mesh(m, B.boxm(Vector3(0.034, 0.014, 0.012)), Vector3.ZERO, black)
	for s in [-1.0, 1.0]:  # pyöristetyt kulmat
		B.mesh(m, B.cyl(0.007, 0.007, 0.012, 8), Vector3(s * 0.017, 0, 0), black, Vector3(90, 0, 0))
	for k in 5:  # karvan suunta: ohuet pystyurat
		B.mesh(m, B.boxm(Vector3(0.002, 0.015, 0.002)), Vector3(-0.012 + k * 0.006, 0, -0.0065), Color(0.1, 0.09, 0.08))
	c.attach("Head", m, Vector3(0, 0.04, -0.104))


## Otsalle vinosti kammattu kiiltävä sivujakaus: litistetty suortuva otsan poikki ohimolta toiselle kulmakarvan
## yläpuolelle (lyhyt tukka "Hair_SimpleParted" pohjana, look.fringe).
static func add_fringe(c: Node3D, col: Color) -> void:
	var f := Node3D.new()  # attach() asettaa tämän muunnoksen: kierto lapsessa
	var piv := Node3D.new()
	f.add_child(piv)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.35
	mat.metallic = 0.1
	var lock := MeshInstance3D.new()
	lock.mesh = B.sphere(0.5, 14)
	lock.material_override = mat
	lock.scale = Vector3(0.17, 0.028, 0.085)
	piv.add_child(lock)
	var tip := MeshInstance3D.new()  # suortuvan kärki kapenee kulmakarvan päälle
	tip.mesh = B.sphere(0.5, 10)
	tip.material_override = mat
	tip.scale = Vector3(0.08, 0.02, 0.05)
	tip.position = Vector3(0.075, 0.0, 0.006)
	piv.add_child(tip)
	# Otsan myötäisesti (kallistus eteen ylhäältä) ja vinoon: korkealta vasemmalta alas oikean kulmakarvan päälle.
	piv.rotation = Vector3(1.15, 0.0, 0.5)
	c.attach("Head", f, Vector3(-0.005, 0.15, -0.07))


## Ruskea venäläinen sotilaspuku (gymnastjorka): pystykaulus, olkalaput punaisin reunoin, napitetut rintataskut,
## nahkavyö messinkisoljella ja saappaat. Paidan ja housujen värit tulevat lookista (shirt, pants, shoes).
static func add_army_uniform(c: Node3D) -> void:
	var khaki := Color(0.4, 0.31, 0.19)
	var leather := Color(0.24, 0.14, 0.07)
	var brass := Color(0.8, 0.62, 0.25)
	var collar := Node3D.new()
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.055
	tm.outer_radius = 0.075
	tm.rings = 18
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = B.mat(khaki.darkened(0.08))
	ring.scale = Vector3(1.0, 1.4, 1.0)
	collar.add_child(ring)
	for s in [-1.0, 1.0]:  # kauluslaatat
		B.mesh(collar, B.boxm(Vector3(0.03, 0.025, 0.004)), Vector3(s * 0.035, 0.0, -0.06), Color(0.55, 0.08, 0.08), Vector3(0, s * 30, 0))
	c.attach("neck_01", collar, Vector3(0, 0.0, 0.0))
	var shoulders := Node3D.new()  # olkalaput rintarangassa (olkavarren luu kääntyisi käsien mukana)
	for s in [-1.0, 1.0]:
		var board := Node3D.new()
		board.position = Vector3(s * 0.15, 0.195, 0.03)
		board.rotation.z = -s * 0.32  # olan kaltevuus
		shoulders.add_child(board)
		B.mesh(board, B.boxm(Vector3(0.11, 0.012, 0.055)), Vector3.ZERO, khaki)
		B.mesh(board, B.boxm(Vector3(0.114, 0.008, 0.06)), Vector3(0, -0.003, 0), Color(0.55, 0.08, 0.08))  # punainen reunus
		B.mesh(board, B.cyl(0.007, 0.007, 0.006, 8), Vector3(-s * 0.04, 0.008, 0), brass)  # nappi
	c.attach("spine_03", shoulders, Vector3.ZERO)
	# Rintataskut rintarankaan, jotta ne seuraavat vartaloa (kumarrus, nojaus). Luu kiertyy animaatiossa kauas
	# lepoasennosta, joten taskut suoristetaan kerran animaation jo pyöriessä: pystyyn rinnan kohdalle hahmon
	# kehyksessä (_align_chest), minkä jälkeen luu kantaa ne.
	var chest_root := Node3D.new()  # attach() asettaa tämän muunnoksen
	var chest := Node3D.new()
	chest_root.add_child(chest)
	for s in [-1.0, 1.0]:
		B.mesh(chest, B.boxm(Vector3(0.11, 0.12, 0.012)), Vector3(s * 0.085, -0.02, 0), khaki.darkened(0.3))  # tasku (tummempi: kangasvarjostin valaisee paitaa himmeämmin)
		B.mesh(chest, B.boxm(Vector3(0.115, 0.035, 0.016)), Vector3(s * 0.085, 0.045, -0.002), khaki.darkened(0.38))  # läppä
		B.mesh(chest, B.cyl(0.007, 0.007, 0.006, 8), Vector3(s * 0.085, 0.04, -0.011), brass, Vector3(90, 0, 0))
	for k in 3:  # kauluksen napitus
		B.mesh(chest, B.cyl(0.006, 0.006, 0.006, 8), Vector3(0, 0.1 - k * 0.05, -0.006), brass, Vector3(90, 0, 0))
	c.attach("spine_03", chest_root, Vector3.ZERO)
	chest.visible = false  # näkyviin vasta suoristettuna
	if c.is_inside_tree():
		c.get_tree().create_timer(0.15).timeout.connect(_align_chest.bind(c, chest))
	else:
		c.ready.connect(func() -> void: c.get_tree().create_timer(0.15).timeout.connect(_align_chest.bind(c, chest)), CONNECT_ONE_SHOT)
	var belt := Node3D.new()
	var band := MeshInstance3D.new()
	var bt := TorusMesh.new()
	bt.inner_radius = 0.2
	bt.outer_radius = 0.225
	bt.rings = 24
	bt.ring_segments = 4
	band.mesh = bt
	band.material_override = B.mat(leather)
	band.scale = Vector3(1.0, 1.6, 1.0)  # selän puolelle asti (pyöreä tukeva vartalo)
	band.rotation.x = -0.22  # selän puoli ylemmäs (ryhti kallistaa lantiota)
	belt.add_child(band)
	B.mesh(belt, B.boxm(Vector3(0.07, 0.05, 0.01)), Vector3(0, 0, -0.228), brass)  # solki
	B.mesh(belt, B.boxm(Vector3(0.05, 0.03, 0.012)), Vector3(0, 0, -0.231), brass.darkened(0.25))
	c.attach("spine_01", belt, Vector3(0, -0.04, 0.0))
	# Punainen käsivarsinauha vasempaan olkavarteen, nauhassa valkoinen pyöreä laatta olkavarren ulkosivulla ja siinä
	# Raahen karateklubin tunnus.
	# Lepoasennossa (T) vasen käsi osoittaa -X:ään: nauhan akseli X:n suuntaan, ulkosivu (+Y) kääntyy käden
	# laskiessa sivulle.
	var arm := Node3D.new()
	var band2 := Node3D.new()
	band2.rotation.z = PI / 2.0
	arm.add_child(band2)
	B.mesh(band2, B.cyl(0.068, 0.068, 0.075, 18), Vector3.ZERO, Color(0.72, 0.06, 0.06))
	B.mesh(arm, B.cyl(0.03, 0.03, 0.006, 20), Vector3(0, 0.069, 0), Color(0.96, 0.95, 0.92))
	# Raahen karateklubin tunnus: kaksi mustaa karatevyötä vinoristissä ja solmu keskellä.
	var emblem := Node3D.new()
	emblem.position = Vector3(0, 0.0725, 0)
	arm.add_child(emblem)
	for a in [PI / 4.0, -PI / 4.0]:
		B.mesh(emblem, B.boxm(Vector3(0.046, 0.002, 0.008)), Vector3.ZERO, Color(0.04, 0.04, 0.04), Vector3(0, rad_to_deg(a), 0))
	B.mesh(emblem, B.boxm(Vector3(0.011, 0.003, 0.011)), Vector3(0, 0.0005, 0), Color(0.08, 0.08, 0.08))  # solmu
	c.attach("upperarm_l", arm, Vector3(-0.14, 0.0, 0.0))


## Rintataskut pystyyn rinnan kohdalle hahmon kehyksessä (rinnan pieni kaltevuus: alareuna vatsaa vasten).
static func _align_chest(c: Node3D, chest: Node3D) -> void:
	if not is_instance_valid(c) or not is_instance_valid(chest):
		return
	var at: Vector3 = c.bone_position("spine_03") + Vector3(0, 0.08, -0.155)
	chest.global_transform = c.global_transform * Transform3D(Basis(Vector3.RIGHT, 0.12), at)
	chest.visible = true


## K-Marketin muovikassi, jossa kuutonen: origo on sankojen kädensija, kassi roikkuu sen alla. Kapea kylki
## (x) on hahmon kylkeä vasten, tölkkien kannet näkyvät avoimesta suusta ja K-logo on molemmissa kyljissä.
static func beer_bag() -> Node3D:
	var bag := Node3D.new()
	var orange := Color(1.0, 0.45, 0.0)
	B.mesh(bag, B.boxm(Vector3(0.15, 0.24, 0.27)), Vector3(0, -0.29, 0), orange)
	B.mesh(bag, B.boxm(Vector3(0.13, 0.03, 0.25)), Vector3(0, -0.42, 0), orange.darkened(0.2))  # pullistunut pohja
	for i in 2:
		for j in 3:
			var p := Vector3((i - 0.5) * 0.066, -0.22, (j - 1) * 0.083)
			B.mesh(bag, B.cyl(0.031, 0.031, 0.12, 12), p, Color(0.12, 0.22, 0.55))
			var lid := B.mesh(bag, B.cyl(0.027, 0.029, 0.006, 12), p + Vector3(0, 0.062, 0), Color(0.8, 0.8, 0.82))
			(lid.material_override as StandardMaterial3D).metallic = 0.8
			(lid.material_override as StandardMaterial3D).roughness = 0.3
	# Sangat: kummankin kyljen reunoista kädensijaan, kassin suu rypistyy kasaan.
	for s in [-1.0, 1.0]:
		for e in [-1.0, 1.0]:
			B.tube(bag, Vector3(s * 0.07, -0.17, e * 0.1), Vector3(s * 0.012, 0.0, e * 0.02), 0.009, orange)
	for s in [-1.0, 1.0]:
		var k := B.label(bag, "K", Vector3(s * 0.077, -0.29, 0), 16, Color.WHITE)
		k.rotation.y = s * PI / 2.0
	return bag


## Kassi roikkuu kädestä pystyssä (ei käänny käden luun mukana, muuten se kääntyisi lepoasennon T-asennosta
## kyljen sisään) hieman kyljen ulkopuolella, ja alapää heilahtaa jäljessä, kun käsi liikkuu hahmoon nähden.
## bag on hahmon lapsi top_level-tilassa.
static func hang_bag(c: Node3D, bag: Node3D, delta: float) -> void:
	var hand: Vector3 = c.bone_position("hand_r")
	var grip := hand + Vector3(signf(hand.x) * 0.04, -0.06, 0)
	var vel: Vector3 = (grip - bag.get_meta("prev", grip)) / maxf(delta, 0.001)
	bag.set_meta("prev", grip)
	var sw: Vector3 = bag.get_meta("swing", Vector3.ZERO)
	sw = sw.lerp((-vel * 0.12).limit_length(0.6), 1.0 - exp(-6.0 * delta))
	bag.set_meta("swing", sw)
	var down := (Vector3.DOWN + Vector3(sw.x, 0, sw.z)).normalized()
	var basis := Basis(Quaternion(Vector3.DOWN, down))
	var gb := c.global_basis.orthonormalized()
	bag.global_transform = Transform3D(gb * basis, c.global_transform * grip)


## Pelaajan omat yksityiskohdat (inspiraatio: vaaleat hiukset, pukinparta, kello ja rannekoru, asun mukaan
## peililasiset pilottilasit tai valkoiset ovaalit lasit, kultaketju ja rasvaletti). Muutama pieni mesh luissa.
static func _add_player_gear(c: Node3D, look: Dictionary) -> void:
	c.set_meta("cap", look.get("cap", "karhu"))
	var gold := B.mat(Color(0.95, 0.76, 0.3)).duplicate() as StandardMaterial3D  # jaettu materiaali: kopio ennen muokkausta
	gold.metallic = 0.95
	gold.roughness = 0.22
	# Pukinparta: leukatupsu ja ohuet viikset suupielistä alas.
	var beard := Node3D.new()
	var bc: Color = (look.get("hair_color", PLAYER_HAIR) as Color).darkened(0.25)
	# Leuan pinnalla: leukaparta (litistetty pallo), alahuulen tupsu ja ohuet viikset; suupielet yhdistävät.
	B.mesh(beard, B.sphere(0.5, 12), Vector3(0, -0.006, 0.002), bc).scale = Vector3(0.042, 0.036, 0.018)
	B.mesh(beard, B.sphere(0.5, 8), Vector3(0, 0.02, -0.004), bc).scale = Vector3(0.014, 0.014, 0.008)
	B.mesh(beard, B.sphere(0.5, 10), Vector3(0, 0.046, -0.009), bc).scale = Vector3(0.044, 0.008, 0.009)
	c.attach("Head", beard, Vector3(0, -0.005, -0.088))
	match String(look.get("shades", "")):
		"pilotti":
			# Peililasiset pilottilasit: pisaranmuotoiset linssit (kirkas metalli heijastaa taivaan), kultasanka.
			var sh := Node3D.new()
			var lens := StandardMaterial3D.new()
			lens.albedo_color = Color(0.9, 0.62, 0.8)
			lens.metallic = 1.0
			lens.roughness = 0.04
			for sx in [-1.0, 1.0]:
				var l := MeshInstance3D.new()
				l.mesh = B.sphere(0.5, 14)
				l.material_override = lens
				l.position = Vector3(sx * 0.034, -0.004, 0)
				l.scale = Vector3(0.05, 0.046, 0.012)
				l.rotation.z = sx * -0.25
				sh.add_child(l)
				var tm := MeshInstance3D.new()  # sanka korvan taakse
				tm.mesh = B.boxm(Vector3(0.003, 0.003, 0.1))
				tm.material_override = gold
				tm.position = Vector3(sx * 0.068, 0.008, 0.048)
				sh.add_child(tm)
			for y in [0.012, 0.0]:
				var br := MeshInstance3D.new()  # kaksoissilta
				br.mesh = B.boxm(Vector3(0.022, 0.0025, 0.003))
				br.material_override = gold
				br.position = Vector3(0, y, -0.002)
				sh.add_child(br)
			c.attach("Head", sh, Vector3(0, 0.07, -0.105))
		"valkoiset":
			# Valkoiset ovaalit lasit (ysärin rantalasit): paksu kiiltävä kehys, tummat linssit.
			var sh := Node3D.new()
			var frame := B.mat(Color(0.96, 0.96, 0.94)).duplicate() as StandardMaterial3D
			frame.roughness = 0.2
			for sx in [-1.0, 1.0]:
				var f := MeshInstance3D.new()
				f.mesh = B.sphere(0.5, 14)
				f.material_override = frame
				f.position = Vector3(sx * 0.036, 0, 0.002)
				f.scale = Vector3(0.056, 0.032, 0.014)
				sh.add_child(f)
				var l := MeshInstance3D.new()
				l.mesh = B.sphere(0.5, 14)
				l.material_override = B.mat(Color(0.05, 0.05, 0.06)).duplicate()
				(l.material_override as StandardMaterial3D).roughness = 0.05
				l.position = Vector3(sx * 0.036, 0, -0.004)
				l.scale = Vector3(0.042, 0.022, 0.006)
				sh.add_child(l)
				var tm := MeshInstance3D.new()
				tm.mesh = B.boxm(Vector3(0.006, 0.006, 0.1))
				tm.material_override = frame
				tm.position = Vector3(sx * 0.068, 0.006, 0.048)
				sh.add_child(tm)
			var bridge := MeshInstance3D.new()
			bridge.mesh = B.boxm(Vector3(0.02, 0.006, 0.006))
			bridge.material_override = frame
			bridge.position = Vector3(0, 0.006, 0)
			sh.add_child(bridge)
			c.attach("Head", sh, Vector3(0, 0.07, -0.105))
	if look.get("chain", false):
		# Kultaketju kaulassa paidan päällä.
		var ch := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.07
		tm.outer_radius = 0.075
		tm.rings = 24
		tm.ring_segments = 4
		ch.mesh = tm
		ch.material_override = gold
		ch.scale = Vector3(1.0, 1.0, 0.85)
		ch.rotation.x = deg_to_rad(-18)
		c.attach("neck_01", ch, Vector3(0, -0.035, -0.012))
	# Musta älykello vasemmassa ranteessa, hopeinen rannekoru oikeassa.
	var watch := Node3D.new()
	B.mesh(watch, B.cyl(0.031, 0.031, 0.022, 12), Vector3.ZERO, Color(0.05, 0.05, 0.055), Vector3(0, 0, 90))
	B.mesh(watch, B.boxm(Vector3(0.022, 0.012, 0.03)), Vector3(0, 0.03, 0), Color(0.03, 0.03, 0.035))
	c.attach("hand_l", watch, Vector3(-0.045, 0, 0))
	var bracelet := MeshInstance3D.new()
	var bt := TorusMesh.new()
	bt.inner_radius = 0.03
	bt.outer_radius = 0.034
	bt.rings = 16
	bt.ring_segments = 4
	bracelet.mesh = bt
	var silver := B.mat(Color(0.82, 0.83, 0.86)).duplicate() as StandardMaterial3D
	silver.metallic = 0.9
	silver.roughness = 0.25
	bracelet.material_override = silver
	bracelet.rotation.z = PI / 2.0
	c.attach("hand_r", bracelet, Vector3(0.045, 0, 0))
	if look.get("letti", false):
		_add_letti(c, look.get("hair_color", PLAYER_HAIR))


## Rasvaletti: taakse kammattu kiiltävä tukka (kuori kallon pinnasta kuten lippiksen kupu, reuna otsalta niskaan)
## ja niskaan valuva letti. Kampauksen urat ja geelin kiilto varjostimessa.
static func _add_letti(c: Node3D, col: Color) -> void:
	var sk: Skeleton3D = c.skeleton
	var rest := sk.get_bone_global_rest(sk.find_bone("Head"))
	var mb: Basis = (c.model.transform * sk.transform).basis
	var body: MeshInstance3D = null
	for mi in sk.get_children():
		if mi is MeshInstance3D and (body == null or mi.mesh.surface_get_array_len(0) > body.mesh.surface_get_array_len(0)):
			body = mi
	var key := "letti/" + str(body.mesh.get_rid())
	if not _cap_cache.has(key):
		var grid := _skull_grid(body.mesh, rest.origin, mb)
		_cap_cache[key] = _letti_mesh(grid)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/hair_gel.gdshader")
	mat.set_shader_parameter("hair", col)
	var mi := MeshInstance3D.new()
	mi.mesh = _cap_cache[key]
	mi.material_override = mat
	c.attach("Head", mi, CAP_OFFSET)


static func _letti_mesh(grid: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var margin := 0.0045
	# Hiusraja: otsalla korkealla (kaljuuntuva otsa taakse kammattuna), ohimoilla korvien yläpuolella, niskassa alhaalla.
	var rim := func(th: float) -> float:
		var y := lerpf(0.035, -0.1, pow((1.0 - cos(th)) * 0.5, 2.0)) - CAP_C.y
		var ps := 0.0
		for it in 4:
			ps = asin(clampf(y / (_skull_r(grid, th, ps) + margin), -0.95, 0.95))
		return ps
	var pt := func(i: int, j: int, nv: int) -> Vector3:
		var th := TAU * i / NT
		var ps := lerpf(rim.call(th), PI * 0.5, float(j) / nv)
		return CAP_C + _dir(th, ps) * (_skull_r(grid, th, ps) + margin)
	var nv := 14
	for i in NT:
		for j in nv:
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
				var p: Vector3 = pt.call(q[0], q[1], nv)
				st.set_normal((p - CAP_C).normalized())
				st.set_uv(Vector2(float(q[0]) / NT, float(q[1]) / nv))
				st.add_vertex(p)
	# Letti niskaan: kaartuva nauha takaraivolta alas hartioiden päälle, kapenee ja ohenee kärkeä kohti.
	# Alkaa takaraivolta hiusrajan yläpuolelta ja seuraa niskaa alas (hahmon kasvot -Z, niska takaraivon edessä).
	var top: Vector3 = pt.call(NT / 2, 2, nv) + Vector3(0, 0, -0.004)
	var segs := 7
	var sides := 6
	var prev := []
	for s in segs + 1:
		var t := float(s) / segs
		var cen := top + Vector3(0, -0.15 * t, -0.03 * t + 0.012 * sin(t * PI))
		var hw := lerpf(0.026, 0.014, t)
		var hd := lerpf(0.02, 0.011, t)
		var ring := []
		for e in sides:
			var a := TAU * e / sides
			ring.append(cen + Vector3(cos(a) * hw, 0, sin(a) * hd))
		if s > 0:
			for e in sides:
				var a: Vector3 = prev[e]
				var b: Vector3 = prev[(e + 1) % sides]
				var a2: Vector3 = ring[e]
				var b2: Vector3 = ring[(e + 1) % sides]
				var mid := (a + b + a2 + b2) / 4.0
				var n := (mid - cen).normalized()
				for v in [[a, float(e)], [b, e + 1.0], [b2, e + 1.0], [a, float(e)], [b2, e + 1.0], [a2, float(e)]]:
					st.set_normal(n)
					st.set_uv(Vector2(v[1] / sides, 1.0 + t))
					st.add_vertex(v[0])
		prev = ring
	return st.commit()


## Pelaajan lippis päähän.
const CAP_NAVY := Color(0.035, 0.035, 0.04)  # musta kuten Karhu-lippiksissä
const CAP_PIPING := Color(1.0, 0.82, 0.1)  # keltainen kerrosraita lipan reunassa
const KARJALA_RED := Color(0.6, 0.05, 0.06)  # Karjala-lippis (Paapelin työvaatteet): punainen, valkoinen reunus
const CAP_OFFSET := Vector3(0, 0.15, 0.005)  # lippiksen origo pääluun lepopaikasta (hahmon avaruudessa)
const CAP_C := Vector3(0, -0.035, -0.015)  # kallon keskipiste lippiksen avaruudessa
const CAP_RIM_FRONT := -0.004  # reunan korkeus otsalla
const CAP_RIM_BACK := -0.072  # ja niskassa (reuna kallistuu taaksepäin)
const CAP_MARGIN := 0.009  # kangas + väli kallon pintaan
const NT := 48
const NP := 18
const PSI_MIN := -60.0
static var _cap_cache := {}


## Karhu-lippis, joka mukailee kaljun pään muotoja: kupu mallinnetaan hahmon oman kallon pinnasta,
## tukka painetaan kuvun alle (näkyy vain reunan alta). Merkki painettuna etupaneeliin, kaareva lippa.
static func add_cap(c: Node3D) -> void:
	var kind: String = c.get_meta("cap", "karhu")
	c.set_meta("capped", true)
	if hat == "stetson" and c.has_meta("player_body"):
		add_stetson(c)
		return
	if kind == "":
		return  # asussa ei lippistä (rasvaletti)
	var cloth := CAP_NAVY if kind == "karhu" else KARJALA_RED
	var sk: Skeleton3D = c.skeleton
	var rest := sk.get_bone_global_rest(sk.find_bone("Head"))
	var mb: Basis = (c.model.transform * sk.transform).basis
	var body: MeshInstance3D = null
	for mi in sk.get_children():
		if mi is MeshInstance3D and (body == null or mi.mesh.surface_get_array_len(0) > body.mesh.surface_get_array_len(0)):
			body = mi
	var key := kind + "/" + str(body.mesh.get_rid())
	if not _cap_cache.has(key):
		var grid := _skull_grid(body.mesh, rest.origin, mb)
		_cap_cache[key] = {"grid": grid, "crown": _cap_crown(grid), "brim": _cap_brim(grid, cloth,
			CAP_PIPING if kind == "karhu" else Color(0.95, 0.95, 0.92))}
	var data: Dictionary = _cap_cache[key]
	_tuck_hair(sk, body, data.grid, rest.origin, mb)
	var cap := Node3D.new()
	var crown := MeshInstance3D.new()
	crown.mesh = data.crown
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/cap.gdshader")
	cm.set_shader_parameter("cloth", cloth)
	cm.set_shader_parameter("logo", load("res://assets/cap_logo.png" if kind == "karhu" else "res://assets/cap_logo_karjala.png"))
	crown.material_override = cm
	cap.add_child(crown)
	var brim := MeshInstance3D.new()
	brim.mesh = data.brim
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.vertex_color_is_srgb = true
	bm.roughness = 0.8
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	brim.material_override = bm
	cap.add_child(brim)
	var top := _cap_point(data.grid, 0.0, PI * 0.5)
	B.mesh(cap, B.sphere(0.009, 10), top + Vector3(0, 0.001, 0), cloth).scale = Vector3(1, 0.55, 1)  # nappi
	c.attach("Head", cap, CAP_OFFSET)


## Stetson-cowboyhattu (pelaajan päähine, Looks.hat): ruskea huopa, korkea kupu, jonka päällä keskiura edestä taakse
## ja edessä puristukset sivuilla; leveä lieri, joka kaartuu sivuilta ylös ja notkahtaa edestä ja takaa alas; kuvun
## tyvessä tumma nauha ja hopeinen koristelaatta. Aukko sovitetaan hahmon omaan kalloon (_skull_grid kuten lippiksessä),
## ja tukka painetaan hatun alle (_tuck_hair). Mitat lippiksen avaruudessa (CAP_OFFSET pääluun lepopaikasta, -Z eteen).
const STETSON_FELT := Color(0.38, 0.25, 0.14)
const STETSON_BAND := Color(0.16, 0.1, 0.06)
const STETSON_RING_Y := -0.012  # aukon korkeus lippiksen avaruudessa (vaakasuora, otsan yläpuolella)
const STETSON_CROWN_H := 0.125
const STETSON_BRIM := 0.085


static func add_stetson(c: Node3D) -> void:
	var sk: Skeleton3D = c.skeleton
	var rest := sk.get_bone_global_rest(sk.find_bone("Head"))
	var mb: Basis = (c.model.transform * sk.transform).basis
	var body: MeshInstance3D = null
	for mi in sk.get_children():
		if mi is MeshInstance3D and (body == null or mi.mesh.surface_get_array_len(0) > body.mesh.surface_get_array_len(0)):
			body = mi
	var key := "stetson/" + str(body.mesh.get_rid())
	if not _cap_cache.has(key):
		var grid := _skull_grid(body.mesh, rest.origin, mb)
		_cap_cache[key] = {"grid": grid, "mesh": _stetson_mesh(grid)}
	var data: Dictionary = _cap_cache[key]
	_tuck_hair(sk, body, data.grid, rest.origin, mb)
	var h := MeshInstance3D.new()
	h.mesh = data.mesh
	var felt := StandardMaterial3D.new()
	felt.vertex_color_use_as_albedo = true
	felt.vertex_color_is_srgb = true
	felt.roughness = 0.92
	felt.cull_mode = BaseMaterial3D.CULL_DISABLED
	h.material_override = felt
	var hat_node := Node3D.new()
	hat_node.add_child(h)
	# Hopeinen koristelaatta nauhassa vasemmalla sivulla.
	var ring: Array = data.mesh.get_meta("ring")
	var th := PI * 0.5
	var r := _stetson_ring_r(ring, th)
	var concho := MeshInstance3D.new()
	concho.mesh = B.cyl(0.011, 0.011, 0.004, 16)
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.82, 0.83, 0.86)
	silver.metallic = 0.95
	silver.roughness = 0.2
	concho.material_override = silver
	concho.position = Vector3(sin(th), 0, -cos(th)) * (r + 0.004) + Vector3(0, STETSON_RING_Y + 0.016, 0)
	concho.rotation = Vector3(0, 0, PI * 0.5)
	hat_node.add_child(concho)
	c.attach("Head", hat_node, CAP_OFFSET)


## Aukon säde kiertokulmassa th (rengas: NT säteen lista), lineaarinen interpolointi.
static func _stetson_ring_r(ring: Array, th: float) -> float:
	var f := fposmod(th, TAU) / TAU * NT
	var i0 := int(floorf(f)) % NT
	return lerpf(ring[i0], ring[(i0 + 1) % NT], f - floorf(f))


static func _stetson_mesh(grid: Array) -> ArrayMesh:
	# Aukon säde kussakin suunnassa: kallon pinta korkeudella STETSON_RING_Y + huopa ja väli.
	var ring := []
	for i in NT:
		var th := TAU * i / NT
		var ps := 0.0
		for it in 5:
			ps = asin(clampf((STETSON_RING_Y - CAP_C.y) / (_skull_r(grid, th, ps) + 0.012), -0.95, 0.95))
		var p := CAP_C + _dir(th, ps) * (_skull_r(grid, th, ps) + 0.012)
		ring.append(Vector2(p.x, p.z).length())
	var y0 := STETSON_RING_Y
	var felt := STETSON_FELT
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Nelikulmio a-b-c-d; kiertosuunta valitaan niin, että pinnan normaali osoittaa vihjeen (ulospäin) puolelle
	# (Godotin etupinta myötäpäivään normaalin puolelta katsottuna; generate_normals laskee normaalit kiertosuunnasta).
	var quad := func(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color, hint: Vector3) -> void:
		var n := (b - a).cross(d - a).normalized()
		var order := [a, cc, b, a, d, cc]
		if n.dot(hint) < 0.0:
			n = -n
			order = [a, b, cc, a, cc, d]
		for v in order:
			st.set_color(col)
			st.add_vertex(v)
	# Kupu: seinä aukolta ylös, kapenee hieman; etupuristukset painavat seinää sisään yläosassa edessä sivuilla.
	var nv := 10
	var wall := func(th: float, v: float) -> Vector3:
		var r := _stetson_ring_r(ring, th) * lerpf(1.0, 0.9, v)
		var front := maxf(0.0, -cos(th))  # 1 edessä
		var pinch := pow(absf(sin(th)), 1.5) * front * front * smoothstep(0.45, 1.0, v)
		r *= 1.0 - 0.22 * pinch
		var y := y0 + STETSON_CROWN_H * v - 0.012 * (1.0 - front) * v  # kupu laskee hieman taakse
		return Vector3(sin(th) * r, y, -cos(th) * r)
	for i in NT:
		var t0 := TAU * i / NT
		var t1 := TAU * (i + 1) / NT
		for j in nv:
			var v0 := float(j) / nv
			var v1 := float(j + 1) / nv
			var col := STETSON_BAND if v1 <= 0.2 else felt.lightened(0.04 * v0)
			quad.call(wall.call(t0, v0), wall.call(t1, v0), wall.call(t1, v1), wall.call(t0, v1), col, Vector3(sin(t0), 0, -cos(t0)))
	# Katto: seinän yläreunasta keskelle, keskiura edestä taakse (x ≈ 0 painuu alas).
	var nr := 6
	var roof := func(th: float, u: float) -> Vector3:
		var top: Vector3 = wall.call(th, 1.0)
		var p := Vector3(top.x * (1.0 - u), top.y, top.z * (1.0 - u))
		var crease := exp(-pow(p.x / 0.028, 2.0)) * smoothstep(0.0, 0.5, u)
		p.y += 0.012 * sin(u * PI * 0.5) - 0.035 * crease
		return p
	for i in NT:
		var t0 := TAU * i / NT
		var t1 := TAU * (i + 1) / NT
		for j in nr:
			var u0 := float(j) / nr
			var u1 := float(j + 1) / nr
			quad.call(roof.call(t0, u0), roof.call(t1, u0), roof.call(t1, u1), roof.call(t0, u1), felt.lightened(0.06), Vector3.UP)
	# Lieri: aukolta ulos; sivuilla kaartuu ylös, edessä ja takana notkahtaa alas. Reunassa paksumpi kantti.
	var nb := 8
	var brim := func(th: float, t: float, lift: float) -> Vector3:
		var r := _stetson_ring_r(ring, th) + STETSON_BRIM * t
		var side := sin(th) * sin(th)
		var y := y0 + 0.042 * side * t * t - 0.012 * (1.0 - side) * t * t + lift
		return Vector3(sin(th) * r, y, -cos(th) * r)
	for i in NT:
		var t0 := TAU * i / NT
		var t1 := TAU * (i + 1) / NT
		for j in nb:
			var a0 := float(j) / nb
			var a1 := float(j + 1) / nb
			var col := felt.darkened(0.08) if j == nb - 1 else felt
			quad.call(brim.call(t0, a0, 0.0), brim.call(t1, a0, 0.0), brim.call(t1, a1, 0.0), brim.call(t0, a1, 0.0), col, Vector3.UP)
		# Reunan paksuus: kapea pystykaista lierin ulkoreunassa.
		quad.call(brim.call(t0, 1.0, -0.004), brim.call(t1, 1.0, -0.004), brim.call(t1, 1.0, 0.0), brim.call(t0, 1.0, 0.0),
			felt.darkened(0.2), Vector3(sin(t0), 0, -cos(t0)))
	# Pehmeät normaalit: samat kärkipisteet yhdistetään (värin raja, esim. nauha, jää teräväksi).
	st.index()
	st.generate_normals()
	var out := st.commit()
	out.set_meta("ring", ring)
	return out


## Kallon säde suunnittain (θ = kiertokulma, 0 = eteen -Z; ψ = korotuskulma) ilman tukkaa.
static func _skull_grid(mesh: Mesh, origin: Vector3, mb: Basis) -> Array:
	var raw := []
	for i in NT:
		var row := []
		row.resize(NP)
		row.fill(0.0)
		raw.append(row)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for p in verts:
		var q: Vector3 = mb * (p - origin) - CAP_OFFSET
		var d := q - CAP_C
		var r := d.length()
		if r < 0.03 or r > 0.2 or q.y < -0.13:
			continue
		var ti := _t_index(atan2(d.x, -d.z))
		var pj := _p_index(asin(clampf(d.y / r, -1.0, 1.0)))
		if pj >= 0:
			raw[ti][pj] = maxf(raw[ti][pj], r)
	# Aukot täytetään naapureista, sitten laajennus (ettei kupu leikkaa kalloa) ja pehmennys.
	for it in 6:
		for i in NT:
			for j in NP:
				if raw[i][j] == 0.0:
					var sum := 0.0
					var n := 0
					for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
						var jj: int = j + o[1]
						if jj < 0 or jj >= NP:
							continue
						var v: float = raw[(i + o[0] + NT) % NT][jj]
						if v > 0.0:
							sum += v
							n += 1
					if n > 0:
						raw[i][j] = sum / n
	var dil := _grid_pass(raw, true)
	return _grid_pass(dil, false)


static func _grid_pass(g: Array, take_max: bool) -> Array:
	var out := []
	for i in NT:
		var row := []
		for j in NP:
			var acc := 0.0
			var n := 0
			for di in [-1, 0, 1]:
				for dj in [-1, 0, 1]:
					var jj: int = clampi(j + dj, 0, NP - 1)
					var v: float = g[(i + di + NT) % NT][jj]
					acc = maxf(acc, v) if take_max else acc + v
					n += 1
			row.append(acc if take_max else acc / n)
		out.append(row)
	return out


static func _t_index(th: float) -> int:
	return int(floorf(fposmod(th, TAU) / TAU * NT + 0.5)) % NT


static func _p_index(ps: float) -> int:
	var f := (rad_to_deg(ps) - PSI_MIN) / (90.0 - PSI_MIN) * (NP - 1)
	return int(round(f)) if f >= -0.5 and f <= NP - 0.5 else -1


## Kallon säde bilineaarisesti.
static func _skull_r(grid: Array, th: float, ps: float) -> float:
	var ft := fposmod(th, TAU) / TAU * NT
	var fp := clampf((rad_to_deg(ps) - PSI_MIN) / (90.0 - PSI_MIN) * (NP - 1), 0.0, NP - 1.001)
	var i0 := int(floorf(ft)) % NT
	var i1 := (i0 + 1) % NT
	var j0 := int(floorf(fp))
	var tt := ft - floorf(ft)
	var tp := fp - j0
	var a: float = lerpf(grid[i0][j0], grid[i1][j0], tt)
	var b: float = lerpf(grid[i0][j0 + 1], grid[i1][j0 + 1], tt)
	return lerpf(a, b, tp)


static func _dir(th: float, ps: float) -> Vector3:
	return Vector3(sin(th) * cos(ps), sin(ps), -cos(th) * cos(ps))


static func _cap_point(grid: Array, th: float, ps: float) -> Vector3:
	return CAP_C + _dir(th, ps) * (_skull_r(grid, th, ps) + CAP_MARGIN)


## Reunan korotuskulma: reuna kulkee otsalta niskaan kallistuvaa tasoa pitkin.
static func _rim_psi(grid: Array, th: float) -> float:
	var y := lerpf(CAP_RIM_FRONT, CAP_RIM_BACK, (1.0 - cos(th)) * 0.5) - CAP_C.y
	var ps := 0.0
	for it in 4:
		ps = asin(clampf(y / (_skull_r(grid, th, ps) + CAP_MARGIN), -0.95, 0.95))
	return ps


static func _cap_crown(grid: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nv := 16
	var pt := func(i: int, j: int) -> Vector3:
		var th := TAU * i / NT
		var ps := lerpf(_rim_psi(grid, th), PI * 0.5, float(j) / nv)
		return _cap_point(grid, th, ps)
	for i in NT:
		for j in nv:
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
				var p: Vector3 = pt.call(q[0], q[1])
				var du: Vector3 = pt.call(q[0] + 1, q[1]) - pt.call(q[0] - 1, q[1])
				var dv: Vector3 = pt.call(q[0], mini(q[1] + 1, nv)) - pt.call(q[0], maxi(q[1] - 1, 0))
				var n := du.cross(dv).normalized()
				if q[1] == nv or n.length() < 0.5:
					n = Vector3.UP
				if n.dot(p - CAP_C) < 0.0:
					n = -n
				st.set_normal(n)
				st.set_uv(Vector2(float(q[0]) / NT, float(q[1]) / nv))
				st.add_vertex(p)
	return st.commit()


static func _cap_brim(grid: Array, top_col := CAP_NAVY, piping := CAP_PIPING) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var under_col := Color(0.03, 0.03, 0.035)
	var n := 24
	var thick := 0.006
	var inner := []
	var outer := []
	var tips := []
	# Kuvun leveys reunan kohdalla (sivuilla, θ = ±90°).
	var half_w := 0.0
	for th in [PI * 0.5, -PI * 0.5]:
		half_w = maxf(half_w, absf(_cap_point(grid, th, _rim_psi(grid, th)).x))
	half_w *= 0.97
	var front_z := _cap_point(grid, 0.0, _rim_psi(grid, 0.0)).z
	for k in n + 1:
		# Pitkä, pyöreä D-lippa, joka kaartuu voimakkaasti sivuilta alas (esikaareva) ja laskee kärkeä kohti.
		var a := deg_to_rad(lerpf(-80.0, 80.0, float(k) / n))
		var p_in := _cap_point(grid, a, _rim_psi(grid, a)) + Vector3(0, 0.003, 0)
		var d := Vector3(sin(a), 0, -cos(a))
		var reach := 0.088 * pow(maxf(cos(a * 1.1), 0.0), 0.5) + 0.004
		# Ääriviiva ylhäältä: sivut suoraan eteen pään leveydellä (yli menevä osa leikattu pois),
		# etureuna kaartuu pyöreästi sivuihin.
		var p_out := p_in + d * reach
		p_out.x = clampf(p_in.x + d.x * reach * 0.25, -half_w, half_w)
		var u := clampf(absf(p_out.x) / half_w, 0.0, 1.0)
		var outline := front_z - 0.088 * sqrt(maxf(1.0 - pow(u, 2.4), 0.0))
		p_out.z = minf(p_in.z - 0.004, outline)
		var side := pow(sin(a), 2.0)
		p_out.y = p_in.y - 0.022 - 0.05 * side * (reach / 0.09 + 0.3)
		inner.append(p_in)
		outer.append(p_out)
		tips.append(reach)
	# Kolme riviä pituussuunnassa: lippa kaartuu myös pituussuunnassa alaspäin.
	var rows := 3
	var grid_pts := []
	for r in rows + 1:
		var t := float(r) / rows
		var row := []
		for k in n + 1:
			var a_in: Vector3 = inner[k]
			var b_out: Vector3 = outer[k]
			var p := a_in.lerp(b_out, t)
			p.y -= sin(t * PI) * 0.004 * (1.0 - pow(sin(deg_to_rad(lerpf(-80.0, 80.0, float(k) / n))), 2.0))
			row.append(p)
		grid_pts.append(row)
	var dn := Vector3.DOWN * thick
	for r in rows:
		for k in n:
			var a0: Vector3 = grid_pts[r][k]
			var a1: Vector3 = grid_pts[r][k + 1]
			var b0: Vector3 = grid_pts[r + 1][k]
			var b1: Vector3 = grid_pts[r + 1][k + 1]
			var up := (b0 - a0).cross(a1 - a0).normalized()
			if up.y < 0.0:
				up = -up
			for tri in [[a0, b0, b1], [a0, b1, a1]]:
				for v in tri:
					st.set_color(top_col)
					st.set_normal(up)
					st.add_vertex(v)
				for v in [tri[0], tri[2], tri[1]]:
					st.set_color(under_col)
					st.set_normal(-up)
					st.add_vertex(v + dn)
	# Etureunan paksuus: keltainen kerrosraita (sandwich) mustien pintojen välissä.
	for k in n:
		var b0: Vector3 = grid_pts[rows][k]
		var b1: Vector3 = grid_pts[rows][k + 1]
		var prev: Vector3 = grid_pts[rows - 1][k]
		var fwd := (b0 - prev).normalized()
		var mid := dn * 0.5
		for v in [b0, b0 + mid, b1 + mid, b0, b1 + mid, b1]:
			st.set_color(top_col)
			st.set_normal(fwd)
			st.add_vertex(v)
		for v in [b0 + mid, b0 + dn, b1 + dn, b0 + mid, b1 + dn, b1 + mid]:
			st.set_color(piping)
			st.set_normal(fwd)
			st.add_vertex(v)
	return st.commit()


## Tukka kuvun alle: reunan yläpuoliset tukan pisteet painetaan kallon pinnan sisäpuolelle.
static func _tuck_hair(sk: Skeleton3D, body: MeshInstance3D, grid: Array, origin: Vector3, mb: Basis) -> void:
	var inv := mb.inverse()
	for mi in sk.get_children():
		if not (mi is MeshInstance3D) or mi == body or mi.name in ["Eyes", "Eyebrows"]:
			continue
		var src: Mesh = mi.mesh
		var out := ArrayMesh.new()
		for si in src.get_surface_count():
			var arr := src.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts.size():
				var q: Vector3 = mb * (verts[v] - origin) - CAP_OFFSET
				var d := q - CAP_C
				var r := d.length()
				if r < 0.001:
					continue
				var th := atan2(d.x, -d.z)
				var ps := asin(clampf(d.y / r, -1.0, 1.0))
				if ps < _rim_psi(grid, th) + 0.05:
					continue  # reunan alapuolinen tukka näkyy
				var lim := _skull_r(grid, th, ps) + CAP_MARGIN * 0.4
				if r > lim:
					q = CAP_C + d / r * lim
					verts[v] = origin + inv * (q + CAP_OFFSET)
			arr[Mesh.ARRAY_VERTEX] = verts
			var fmt: int = (src as ArrayMesh).surface_get_format(si)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			out.surface_set_material(si, src.surface_get_material(si))
		mi.mesh = out


## Harmaapään kumara selkä.
static func hunch(c: Node3D, amount := 0.3) -> void:
	c.set_override("spine_01", Vector3.RIGHT, -amount * 0.5)
	c.set_override("spine_03", Vector3.RIGHT, -amount * 0.5)
	c.set_override("neck_01", Vector3.RIGHT, amount * 0.6)
