## Saloisten uusi apteekki Kinnapotin teollisuusalueella (huumekauppa Saloisiin): pieni vaalea liikerakennus Valtatien
## varressa hallien vieressä. Etuovi on lukossa ja AVOINNA-kyltti roikkuu vinossa; takaseinän teräsovessa on
## kurkistusluukku (makasiini.gd _build_door) ja vihreä lamppu. Luukulla myy eläkkeellä oleva sairaanhoitaja.
## Paikallinen kehys: X rakennuksen pituus, +Z = julkisivu tielle, -Z = takaseinä (takaovi). Juuri y = 0 ennen
## world.gd _lift_objects -nostoa; kivijalka ja porras jatkuvat 1 m maan alle.

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const M := preload("res://scripts/map_data.gd")
const Looks := preload("res://scripts/looks.gd")
const Makasiini := preload("res://scripts/makasiini.gd")
const Contact := preload("res://scripts/contact.gd")

## Paikan ensisijainen keskipiste (karttapikseli) ja Valtatien osuus, jonka varresta paikka haetaan.
const PX := Vector2(610.3, -527.2)
const ROAD_A := Vector2(523, -367)
const ROAD_B := Vector2(685, -574)
const L := 10.0
const D := 7.0
const H := 3.6  # seinän korkeus lattiasta
const F := 0.5  # lattian korkeus (kivijalka)
const STOOP := Vector3(1.8, F, 0.9)  # takaoven betoniporras (leveys, korkeus, syvyys)
const DOOR_X := 2.0  # takaoven keskikohta paikallisessa X:ssä
const KNOCK := 1.7  # koputuspiste takaseinästä (m)
## Hoitajan paikka oven kehyksessä (+Z ulos): komeron takaseinän sisäpinta -0.428, ovilehden sisäpinta +0.005;
## mitattu rako selkä 3.8 cm, nenä 5.0 cm (apteekki_s_kuvat.tscn --vain-hoitaja).
const NURSE_Z := -0.175
## Pohja pihoineen (paikallinen XZ): paikan tarkistus ja puuton alue.
const FOOTPRINT := Rect2(-L / 2.0 - 1.0, -D / 2.0 - 2.6, L + 2.0, D + 3.6)

## Myyjä: eläkkeellä oleva sairaanhoitaja. Valkoinen hoitotakki (paita + helma), harmaa permanentti, pyöreät
## silmälasit ja vaaleat kävelykengät (asusteet Looks.make: perm_col, round_glasses; helma _coat_hem).
const NAME := "Hoitaja Raili"
const HOITAJA_LOOK := {
	"model": "female", "shirt": Color(0.95, 0.95, 0.93), "pants": Color(0.72, 0.76, 0.82), "shoes": Color(0.86, 0.83, 0.76),
	"hair": "", "perm_col": Color(0.74, 0.74, 0.76), "round_glasses": true, "hair_color": Color(0.7, 0.7, 0.72),
	"height": 1.62, "skin": Color(1.0, 0.89, 0.84), "bulk": 0.2, "belly": 0.25, "shoulders": -0.4, "muscle": -1.0,
}

## Repliikit (Saloisten paikat: Kinnapotti, Raahen sairaala, Seuranmäki).
const HELLO := "No? Luukku on auki, mutta minä en ole täällä. Mitä tarvitaan?"
const CHAT := [
	"Neljäkymmentä vuotta Raahen sairaalassa. Eläke on pieni, ja lääkekaappi oli iso.",
	"Täällä Kinnapotissa kukaan ei kysele. Katsastusasemalla on omat murheensa.",
	"Seuranmäen pojat tulevat illalla. Minä en kysy, mihin ne menee, eikä ne kysy minulta.",
	"Etuovi on ollut lukossa avajaisista asti. AVOINNA-kyltti on vain koriste.",
	"Annostus on aina pakkauksessa. Minä vain unohdan sen joskus laittaa mukaan.",
]
const OSTO := [
	"Tässä. Ota ruuan kanssa, äläkä aja mopolla.",
	"Pussiin ja taskuun. Kinnapotissa ei ole kameroita.",
	"Pieni pisto ei tunnu missään, mutta tämä tuntuu. Luukku kiinni, kiitos.",
]
const EI_RAHAA := "Rahat ensin, kulta. Eläkeläinen ei anna velaksi."
const LUKOSSA := "Etuovi on lukossa. AVOINNA-kyltti roikkuu vinossa, ja lasin takana on pimeää."
const LAUKKU := "Ota tämä vanha lääkelaukkuni. Siinä tehdään puhdasta työtä, ei ruokapöydän sotkua. Jätin sen portaalle."


## Rakentaa apteekin maailmaan (world.gd _build_kinnapotti) ja kirjaa sen esteisiin, taloihin, puuttomiin alueisiin
## ja pihoihin. Palauttaa {root, back (takaoven solmu), knock, out (koputuspiste ja ulossuunta maailmassa), stoop_top
## (portaan yläpinnan keskipiste maailmassa), nurse, fill (luukun valo, sammuksissa)}; tyhjä, jos paikkaa ei löydy.
static func build(world) -> Dictionary:
	var site := _pick_site(world)
	if site.is_empty():
		push_warning("Saloisten apteekille ei löytynyt paikkaa Valtatien varresta")
		return {}
	var c: Vector2 = site.c
	var f: Vector2 = site.f
	var yaw := atan2(f.x, f.y)  # paikallinen +Z = f (julkisivu tielle)
	var base: float = site.lo - 0.05
	var root := Node3D.new()
	root.name = "ApteekkiSaloinen"
	root.position = Vector3(c.x, base - T.h(c.x, c.y), c.y)  # _lift_objects lisää keskipisteen korkeuden
	root.rotation.y = yaw
	world.add_child(root)
	var parts := _build_body(root)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, base, c.y))
	# Esteet, talot (puut väistävät) ja pohja pihoineen.
	world.blockers.append([c, Vector2(L / 2.0, D / 2.0), yaw])
	world._add_house(c)
	world._tree_free.append([c, 11.0])
	var lot := PackedVector2Array()
	for k in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var q := xf * Vector3(FOOTPRINT.position.x + k.x * FOOTPRINT.size.x, 0, FOOTPRINT.position.y + k.y * FOOTPRINT.size.y)
		lot.append(Vector2(q.x, q.z))
	world._lots.append(lot)
	var knock := xf * Vector3(DOOR_X, 0, -D / 2.0 - KNOCK)
	knock.y = T.h(knock.x, knock.z)
	return {"root": root, "back": parts.back, "knock": knock, "out": Vector3(-f.x, 0, -f.y),
		"stoop_top": xf * Vector3(DOOR_X, F, -D / 2.0 - STOOP.z / 2.0), "nurse": parts.nurse, "fill": parts.fill}


## Paikka Valtatien varresta (02-arkkitehtuuri.md): ehdokkaat t (m tien alusta) × s (m keskiviivasta länteen);
## kelpaa ensimmäinen, jonka pohjan ja pihan jokainen piste on ≥ 12 m tien reunasta, kuivalla maalla, OSM-rakennusten
## keskipisteistä ≥ l/2 + 8 m ja maaston korkeusero < 1 m. Palauttaa {c, f, lo}.
static func _pick_site(world) -> Dictionary:
	var a := M.w2(ROAD_A)
	var b := M.w2(ROAD_B)
	var dir := (b - a).normalized()
	var west := Vector2(-dir.y, dir.x)  # vasen normaali = tieltä länteen (kohti halleja)
	if west.dot(M.w2(PX) - a) < 0.0:
		west = -west
	var f := -west  # julkisivu tielle
	var yaw := atan2(f.x, f.y)
	for t in [180.0, 170.0, 190.0]:
		for s in [30.0, 34.0]:
			var c: Vector2 = a + dir * t + west * s
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, 0, c.y))
			var lo := INF
			var hi := -INF
			var ok := true
			var why := ""
			for i in 9:
				for j in 6:
					var q := xf * Vector3(FOOTPRINT.position.x + FOOTPRINT.size.x * i / 8.0, 0, FOOTPRINT.position.y + FOOTPRINT.size.y * j / 5.0)
					var p := Vector2(q.x, q.z)
					if world._road_clearance(p) < 12.0:
						why = "tie"
					elif world._in_any(p, world._water):
						why = "vesi"
					else:
						for bd in M.Osm.BUILDINGS:
							if p.distance_to(M.w2(bd.c)) < float(bd.l) * M.SCALE / 2.0 + 8.0:
								why = "rakennus %s" % str(bd.c)
								break
					if why != "":
						ok = false
						break
					var y := T.h(p.x, p.y)
					lo = minf(lo, y)
					hi = maxf(hi, y)
				if not ok:
					break
			if ok and hi - lo < 1.0:
				print("APTEEKKI_S paikka t=%.0f s=%.0f px %s maailma %s korkeusero %.2f m" % [t, s, str(M.to_px(Vector3(c.x, 0, c.y)).snapped(Vector2.ONE * 0.1)),
					str(c.snapped(Vector2.ONE * 0.1)), hi - lo])
				return {"c": c, "f": f, "lo": lo}
			print("APTEEKKI_S ehdokas t=%.0f s=%.0f hylätty: %s" % [t, s, why if why != "" else "korkeusero %.2f m" % (hi - lo)])
	return {}


## Runko, julkisivu, kyltit, takaovi portaineen ja hoitaja komerossa. Palauttaa {back, nurse, fill}.
static func _build_body(root: Node3D) -> Dictionary:
	var wall := Color(0.92, 0.92, 0.88)
	var plinth := Color(0.36, 0.36, 0.38)
	var green := Color(0.05, 0.5, 0.28)
	var frame := Color(0.3, 0.33, 0.34)
	var glass := Color(0.2, 0.26, 0.3)  # pimeä myymälä lasin takana
	var stone := Color(0.56, 0.56, 0.54)
	var front := D / 2.0
	var back_z := -D / 2.0
	var gap := Makasiini.GAP
	var hole := Makasiini.HOLE
	# Kivijalka 1 m maan alle, runko GAP:n verran lyhyempi takaa (eteiskomero takaoven taakse, makasiini.gd).
	B.box(root, Vector3(L + 0.2, F + 1.0, D + 0.2), Vector3(0, (F - 1.0) / 2.0, 0), plinth)
	B.box(root, Vector3(L, H, D - gap), Vector3(0, F + H / 2.0, gap / 2.0), wall)
	# Ohut takaseinä, jossa oviaukko; komeron päätyseinät ja katto.
	var ex := back_z + 0.025
	var hx0 := DOOR_X - hole.x / 2.0
	var hx1 := DOOR_X + hole.x / 2.0
	B.box(root, Vector3(hx0 + L / 2.0, H, 0.05), Vector3((hx0 - L / 2.0) / 2.0, F + H / 2.0, ex), wall)
	B.box(root, Vector3(L / 2.0 - hx1, H, 0.05), Vector3((hx1 + L / 2.0) / 2.0, F + H / 2.0, ex), wall)
	B.box(root, Vector3(hole.x, H - hole.y, 0.05), Vector3(DOOR_X, F + hole.y + (H - hole.y) / 2.0, ex), wall)
	for xs in [-1.0, 1.0]:
		B.box(root, Vector3(0.05, H, gap), Vector3(xs * (L / 2.0 - 0.025), F + H / 2.0, back_z + gap / 2.0), wall, false)
	# Tasakatto ja kattoreunus, IV-konehuone.
	B.mesh(root, B.boxm(Vector3(L + 0.4, 0.3, D + 0.4)), Vector3(0, F + H + 0.15, 0), Color(0.36, 0.37, 0.4))
	B.mesh(root, B.boxm(Vector3(L + 0.5, 0.08, D + 0.5)), Vector3(0, F + H + 0.33, 0), Color(0.28, 0.29, 0.31))
	B.mesh(root, B.boxm(Vector3(1.6, 0.8, 1.2)), Vector3(-3.0, F + H + 0.7, -1.2), Color(0.62, 0.64, 0.66))
	# Julkisivu: kaksi pimeää näyteikkunaa ja lukittu lasiovi keskellä, katos ja kynnys.
	for wx in [-3.2, 3.2]:
		B.mesh(root, B.boxm(Vector3(3.0, 2.2, 0.08)), Vector3(wx, F + 1.5, front + 0.03), frame)
		B.mesh(root, B.boxm(Vector3(2.75, 1.95, 0.09)), Vector3(wx, F + 1.5, front + 0.04), glass)
		B.mesh(root, B.boxm(Vector3(0.06, 1.95, 0.1)), Vector3(wx, F + 1.5, front + 0.06), frame)
	B.mesh(root, B.boxm(Vector3(2.0, 2.3, 0.08)), Vector3(0, F + 1.15, front + 0.03), frame)
	B.mesh(root, B.boxm(Vector3(1.8, 2.15, 0.09)), Vector3(0, F + 1.1, front + 0.04), glass)
	B.mesh(root, B.boxm(Vector3(0.05, 2.15, 0.1)), Vector3(0, F + 1.1, front + 0.06), frame)
	for hx in [-0.12, 0.12]:  # vetimet ja niiden läpi ketju munalukolla
		B.mesh(root, B.boxm(Vector3(0.03, 0.5, 0.05)), Vector3(hx, F + 1.05, front + 0.12), Color(0.7, 0.7, 0.72))
	for i in 7:
		B.mesh(root, B.boxm(Vector3(0.05, 0.03, 0.03)), Vector3(-0.15 + i * 0.05, F + 1.1 - absf(i - 3) * 0.03, front + 0.16), Color(0.45, 0.45, 0.45))
	B.mesh(root, B.boxm(Vector3(0.08, 0.1, 0.04)), Vector3(0, F + 0.98, front + 0.18), Color(0.7, 0.6, 0.2))
	B.mesh(root, B.boxm(Vector3(3.2, 0.14, 1.4)), Vector3(0, F + 2.65, front + 0.7), green)
	B.box(root, Vector3(2.4, F + 1.0, 1.2), Vector3(0, (F - 1.0) / 2.0, front + 0.6), stone)
	# Kyltit: APTEEKKI katoksen yllä, vihreä risti nurkassa, rikkinäinen AVOINNA vinossa ovessa.
	var sign_p := B.sign_plate(root, "APTEEKKI", green, Color.WHITE, 0.7, 100, Color(0.9, 0.95, 0.9), "Helvetica Neue")
	sign_p.position = Vector3(0, F + 3.2, front + 0.06)
	for arm in [Vector3(0.9, 0.3, 0.1), Vector3(0.3, 0.9, 0.1)]:
		B.mesh(root, B.boxm(arm), Vector3(-3.8, F + 3.05, front + 0.08), green).material_override = B.unshaded(Color(0.1, 0.8, 0.4))
	var open := B.sign_plate(root, "AVOINNA", Color(0.97, 0.97, 0.95), Color(0.75, 0.1, 0.1), 0.2, 60, Color(0.5, 0.5, 0.5), "Helvetica Neue")
	open.position = Vector3(0.45, F + 1.55, front + 0.12)
	open.rotation.z = -0.32  # toinen naru katkennut
	B.tube(root, Vector3(0.45 - 0.3, F + 1.79, front + 0.11), Vector3(0.45, F + 1.98, front + 0.11), 0.004, Color(0.3, 0.3, 0.3))
	var body := StaticBody3D.new()
	body.add_child(B.box_shape(Vector3(L, H + 0.4, D - gap), Vector3(0, F + (H + 0.4) / 2.0, gap / 2.0)))
	root.add_child(body)
	# Takaovi (oven +Z = ulos rakennuksen taakse), porras ja HENKILÖKUNTA-kyltti. Lamppu ja polttimo vihreiksi.
	var door: Node3D = Makasiini._build_door()
	door.position = Vector3(DOOR_X, F, back_z)
	door.rotation.y = PI
	root.add_child(door)
	var lamp_col := Color(0.3, 1.0, 0.45)
	(door.get_node("Lamppu") as OmniLight3D).light_color = lamp_col
	var bm := (door.get_node("Polttimo") as MeshInstance3D).material_override as StandardMaterial3D
	bm.albedo_color = Color(0.2, 1.0, 0.4)
	bm.emission = Color(0.15, 1.0, 0.35)
	B.box(root, Vector3(STOOP.x, STOOP.y + 1.0, STOOP.z), Vector3(DOOR_X, (STOOP.y - 1.0) / 2.0, back_z - STOOP.z / 2.0), stone)
	var staff := B.sign_plate(root, "HENKILÖKUNTA", Color(0.88, 0.88, 0.84), Color(0.1, 0.35, 0.2), 0.2, 60, Color(0.4, 0.45, 0.42), "Helvetica Neue")
	staff.position = Vector3(DOOR_X, F + 2.95, back_z - 0.02)
	staff.rotation.y = PI
	var nurse := _build_nurse(door)
	var fill := OmniLight3D.new()  # komeron lamppu kasvojen edessä: näkyy vain luukusta (main.gd sytyttää luukun auetessa)
	fill.name = "Valo"
	fill.light_color = Color(1.0, 0.92, 0.82)
	fill.light_energy = 0.7
	fill.omni_range = 0.7
	fill.position = Vector3(-0.06, Makasiini.HATCH_Y + 0.12, -0.03)
	fill.visible = false
	door.add_child(fill)
	return {"back": door, "nurse": nurse, "fill": fill}


## Hoitaja eteiskomerossa oven takana (oven kehys: +Z ulos, origo kynnyksellä). Silmät luukun korkeudelle lasketaan
## pääluusta (kuten rasvanappi_game.gd portsari); jos jalat jäisivät ilmaan, alle tulee juuri sen korkuinen jakkara.
## Kasvot ulos (+Z): rotation.y = PI. Staattinen seisonta-asento (Idle nopeudella 0), kädet sivuilla.
static func _build_nurse(door: Node3D) -> Node3D:
	var floor_y := 0.016  # komeron lattialaudan yläpinta (makasiini.gd _build_door)
	var ch := Looks.make(door, HOITAJA_LOOK)
	ch.name = "Hoitaja"
	ch.rotation.y = PI
	ch.play("Idle", 0.0, 0.0)
	ch.anim.seek(0.0, true)
	# Idlen jalat ovat askelasennossa (takajalka 0.24 m taaempana): komero on vain 0.43 m syvä, joten jalkaterät
	# lantion alle oman lonkan kohdalle animaation korkeudelle (kuten mummot.gd _seat), polvi eteen (-Z).
	# Jalkaterä pysyy Idlen asennossa (pohja vaakaan), muuten IK kallistaa kärjen lattian sisään.
	var pel: Vector3 = ch.bone_position("pelvis")
	for side in ["_l", "_r"]:
		var f: Vector3 = ch.bone_position("foot" + side)
		var fb := Contact.foot_basis(ch, side, false)
		var foot := Vector3(ch.bone_position("thigh" + side).x, f.y, pel.z)
		ch.set_ik("leg" + side, "thigh" + side, "calf" + side, "foot" + side, foot, foot + Vector3(0, 0.5, -0.6))
		ch.set_ik_orient("leg" + side, fb, 1.0)
	var head: Vector3 = ch.bone_position("Head")
	var y := Makasiini.HATCH_Y - head.y - 0.075
	if y > floor_y + 0.02:
		var stool := B.mesh(door, B.boxm(Vector3(0.5, y - floor_y, 0.32)), Vector3(0, floor_y + (y - floor_y) / 2.0, NURSE_Z), Color(0.32, 0.24, 0.18))
		stool.name = "Jakkara"
	else:
		y = maxf(y, floor_y)
	ch.position = Vector3(0, y, NURSE_Z)
	_coat_hem(ch)
	return ch


## Hoitotakin helma lantiolle (kuten mummot.gd kävelytakki): valkoinen kartio ja napit edessä (lantioluun -Z).
static func _coat_hem(ch: Node3D) -> void:
	var k := float(HOITAJA_LOOK.height) / 1.8
	var hem := Node3D.new()
	var col: Color = HOITAJA_LOOK.shirt
	var cone := B.mesh(hem, B.cyl(0.165, 0.2, 0.3, 24), Vector3(0, -0.1, 0), col)
	cone.scale = Vector3(1.0, 1.0, 0.85)
	for i in 3:
		B.mesh(hem, B.sphere(0.008, 6), Vector3(0, 0.02 - i * 0.08, -0.17 - i * 0.006), Color(0.8, 0.8, 0.8))
	hem.scale = Vector3.ONE * k
	ch.attach("pelvis", hem, Vector3(0, 0.06, -0.01) * k)
