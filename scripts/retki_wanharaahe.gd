extends Node3D
## Wanha Raahe -kävelykierros (retket.gd "wanharaahe"): taskukohtaus kuten retki_rojuniemi.gd. Kävely player_walker.gd:llä.
## Viisi pysähdystä järjestyksessä (wanharaahe_legenda.gd STOPS): kullakin pysähdyspaikalla (spots) E ottaa valokuvan, jos hahmo katsoo
## kohdetta kohti: sama tarkistus kuin drone_game.gd take_photo (PHOTO_RANGE/PHOTO_CONE, kulma vaakatasossa). Tilan päivittää main.gd.
## Faktat (Brahe 1649, patsas 1888, vanhat puutalot) "sanotaan"-muodossa, tarkistettava. Patsas on yleinen 1600-luvun aatelismies, ei tarkka kopio.
## Paikallinen -Z = talorivi ja ranta (takaseinä), +Z = tie ja taksi (kamera). Talojen julkisivut ovat z = FRONT_Z, ovet ja ikkunat katsovat +Z.
## Brahen patsas x -9 (Pekkatori), talot x -2..17, rantakuja x 17..19.6, makasiini x 19.6..24.8. Hahmon etu = -Z (basis * -Z).

const B := preload("res://scripts/build.gd")
const Walker := preload("res://scripts/player_walker.gd")
const Vehicles := preload("res://scripts/vehicles.gd")

const FRONT_Z := -4.6  # talojen julkisivu
const WALK_RECT := Rect2(-20.0, -4.2, 46.0, 14.0)
const PHOTO_RANGE := 12.0  # m (drone: 320)
const PHOTO_CONE := 0.45  # rad kuvan keskeltä vaakatasossa (drone: 0.3)
const WHITE := Color(0.95, 0.94, 0.9)
const GLASS := Color(0.32, 0.42, 0.5)

signal exited
signal acted(kind: String)

## Pysähdykset: nimi, seisomapaikka ja kuvattavan kohteen paikka.
const STOPS := {
	"patsas": {"nimi": "Brahen patsas Pekkatorilla", "pos": Vector3(-9.0, 0, 2.4), "target": Vector3(-9.0, 2.9, -1.8)},
	"ovet": {"nimi": "vanhat ovet", "pos": Vector3(1.0, 0, -1.2), "target": Vector3(1.0, 1.3, -4.55)},
	"kauppiaantalo": {"nimi": "kauppiaan kaksikerroksinen talo", "pos": Vector3(13.85, 0, 0.4), "target": Vector3(13.85, 3.0, -4.6)},
	"kuja": {"nimi": "rantakuja ja katulyhty", "pos": Vector3(18.3, 0, -0.6), "target": Vector3(18.3, 2.3, -4.0)},
	"makasiini": {"nimi": "punamullattu makasiini", "pos": Vector3(22.2, 0, 0.4), "target": Vector3(22.2, 1.8, -4.6)},
}

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var spot := ""
var note := ""  # viesti pelaajalle (main.gd näyttää, kun acted("viesti"))
var legenda: RefCounted
var spots := {"ovi": [Vector3(-17.0, 0, 6.4), "[E] Taksille: takaisin lähtöpaikkaan"]}
var _enter_frame := -1
var _flash: ColorRect
var _t := 0.0


func _ready() -> void:
	var n := 0
	for id in STOPS:
		n += 1
		spots[id] = [STOPS[id].pos, "[E] Ota kuva (%d/%d): %s" % [n, STOPS.size(), STOPS[id].nimi]]
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [WALK_RECT]
	add_child(walker)
	var cl := CanvasLayer.new()
	cl.layer = 60
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_flash)
	add_child(cl)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(1.6, 0, -1.0)
	walker.rotation.y = B.yaw_to(Vector3(1, 0, -1))
	walker.visible = true
	walker.activate()


func leave() -> void:
	active = false
	walker.controls_enabled = false


func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


## Kuvan ottamisen räpsäys ja ääni.
func take_flash() -> void:
	_flash.color.a = 0.85
	Sfx.play("pickup", -6.0, 2.2)


## Osuuko kohde kuvaan: hahmon katse (vaakatasossa) kohti kohdetta ja lähellä (drone_game.gd take_photo -tarkistus).
func photo_hits(id: String) -> bool:
	var v: Vector3 = to_global(STOPS[id].target) - (walker.global_position + Vector3(0, 1.5, 0))
	var d := v.length()
	if d > PHOTO_RANGE or d < 1.0:
		return false
	var fwd := -walker.global_basis.z
	fwd.y = 0.0
	v.y = 0.0
	return fwd.angle_to(v) <= PHOTO_CONE


func _process(delta: float) -> void:
	_t += delta
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 3.0)
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	var p := walker.position
	var best := ""
	var bd := 1.8
	for id in spots:
		var d := Vector2(p.x - spots[id][0].x, p.z - spots[id][0].z).length()
		if d < bd:
			bd = d
			best = id
	hint = ""
	spot = best
	if best == "":
		return
	hint = spots[best][1]
	if best != "ovi" and legenda != null and legenda.kuvat.has(best):
		hint = "Kuvattu: %s" % STOPS[best].nimi
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	if best == "ovi":
		exited.emit()
		return
	press(best)


## E pysähdyspaikalla: kuva otetaan, jos kohde on vuorossa ja kameran edessä.
func press(id: String) -> void:
	if legenda != null and legenda.kuvat.has(id):
		note = "Tämä on jo kuvattu: %s." % STOPS[id].nimi
		acted.emit("viesti")
	elif legenda != null and legenda.next_id() != id:
		note = "Reitillä on vuorossa: %s." % STOPS[legenda.next_id()].nimi
		acted.emit("viesti")
	elif not photo_hits(id):
		note = "Kamera ei osoita kohti. Käänny kohti kohdetta (%s) ja paina E uudelleen." % STOPS[id].nimi
		acted.emit("viesti")
	else:
		take_flash()
		acted.emit("kuva:" + id)


# --- Rakennus -------------------------------------------------------------------------------

func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := B.mesh(self, B.boxm(size), pos, col)
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	add_child(body)
	return mi


func _birch(at: Vector3, s := 1.0) -> void:
	B.mesh(self, B.cyl(0.07 * s, 0.1 * s, 3.0 * s, 8), at + Vector3(0, 1.5 * s, 0), Color(0.92, 0.9, 0.86))
	B.mesh(self, B.sphere(1.0 * s, 8), at + Vector3(0, 3.5 * s, 0), Color(0.35, 0.6, 0.22)).scale = Vector3(1.0, 1.2, 1.0)


## Harjakatto, harja X:n suuntaan: kaksi lappeen levyä ja päätykolmiot. Lappeen kulma yhdestä luvusta, kallistus X:n ympäri.
func _roof_x(c: Vector3, half_d: float, len: float, wall_col: Color, roof_col: Color, deg := 30.0) -> void:
	var a := deg_to_rad(deg)
	var rise := half_d * tan(a)
	var rl := half_d / cos(a) + 0.2
	for s in [-1.0, 1.0]:
		B.mesh(self, B.boxm(Vector3(len + 0.4, 0.12, rl)), c + Vector3(0, rise * 0.5 + 0.06, s * half_d * 0.5), roof_col, Vector3(s * deg, 0, 0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-len * 0.5, len * 0.5]:
		for v in [Vector3(x, 0, -half_d), Vector3(x, 0, half_d), Vector3(x, rise, 0)]:
			st.add_vertex(c + v)
	st.generate_normals()
	var m := B.mat(wall_col)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)


## Ikkuna julkisivussa: valkoinen karmi, tummat ruudut ristikolla, ikkunalauta ja halutessa ikkunaluukut.
func _window(x: float, y: float, shutter := Color(0, 0, 0, 0)) -> void:
	B.mesh(self, B.boxm(Vector3(1.0, 1.2, 0.06)), Vector3(x, y, FRONT_Z + 0.03), WHITE)
	B.mesh(self, B.boxm(Vector3(0.8, 1.0, 0.03)), Vector3(x, y, FRONT_Z + 0.075), GLASS)
	B.mesh(self, B.boxm(Vector3(0.05, 1.0, 0.04)), Vector3(x, y, FRONT_Z + 0.09), WHITE)
	B.mesh(self, B.boxm(Vector3(0.8, 0.05, 0.04)), Vector3(x, y + 0.1, FRONT_Z + 0.09), WHITE)
	B.mesh(self, B.boxm(Vector3(1.2, 0.07, 0.18)), Vector3(x, y - 0.63, FRONT_Z + 0.08), WHITE)
	if shutter.a > 0.0:
		for s in [-1.0, 1.0]:
			B.mesh(self, B.boxm(Vector3(0.38, 1.2, 0.04)), Vector3(x + s * 0.7, y, FRONT_Z + 0.05), shutter)
			for k in 4:
				B.mesh(self, B.boxm(Vector3(0.3, 0.02, 0.02)), Vector3(x + s * 0.7, y - 0.4 + k * 0.27, FRONT_Z + 0.08), shutter.darkened(0.3))


## Vanha ovi julkisivussa: valkoinen karmi ja otsalauta, neliruutuinen ovilehti kehyksineen, ikkuna ovilehden yläosassa
## ja ovilehden päällä tuuletusikkuna (valoikkuna), messinkinen kahva ja kivinen kynnysaskel. Oven alareuna on y 0.25.
func _door(x: float, col: Color, w := 1.1, h := 2.1) -> void:
	var y0 := 0.25
	B.mesh(self, B.boxm(Vector3(w + 0.36, h + 0.62, 0.05)), Vector3(x, y0 + (h + 0.62) / 2.0, FRONT_Z + 0.025), WHITE)
	B.mesh(self, B.boxm(Vector3(w + 0.5, 0.1, 0.12)), Vector3(x, y0 + h + 0.64, FRONT_Z + 0.06), WHITE)  # otsalauta
	B.mesh(self, B.boxm(Vector3(w, h, 0.07)), Vector3(x, y0 + h / 2.0, FRONT_Z + 0.07), col)
	for sx in [-1.0, 1.0]:
		# kaksi korkeaa kehyspeiliä per ovilehti-puolisko: ylempi lasi, alempi umpinainen
		B.mesh(self, B.boxm(Vector3(w * 0.34, h * 0.36, 0.03)), Vector3(x + sx * w * 0.24, y0 + h * 0.28, FRONT_Z + 0.12), col.darkened(0.25))
		B.mesh(self, B.boxm(Vector3(w * 0.3, h * 0.28, 0.02)), Vector3(x + sx * w * 0.24, y0 + h * 0.72, FRONT_Z + 0.115), GLASS)
	B.mesh(self, B.boxm(Vector3(0.04, h, 0.09)), Vector3(x, y0 + h / 2.0, FRONT_Z + 0.115), col.darkened(0.4))  # pieli
	# valoikkuna oven yllä: kaaren sijaan tasainen, kolme ruutua
	B.mesh(self, B.boxm(Vector3(w, 0.4, 0.04)), Vector3(x, y0 + h + 0.28, FRONT_Z + 0.07), GLASS)
	for k in 2:
		B.mesh(self, B.boxm(Vector3(0.04, 0.4, 0.05)), Vector3(x - w / 6.0 + k * w / 3.0, y0 + h + 0.28, FRONT_Z + 0.08), WHITE)
	for sx in [-1.0, 1.0]:
		B.mesh(self, B.boxm(Vector3(0.05, 0.2, 0.05)), Vector3(x + sx * 0.1, y0 + h * 0.5, FRONT_Z + 0.16), Color(0.85, 0.65, 0.2))
	B.mesh(self, B.boxm(Vector3(w + 0.6, 0.25, 0.6)), Vector3(x, 0.125, FRONT_Z + 0.3), Color(0.55, 0.55, 0.57))


## Talo: kivijalka, runko, valkoiset nurkkalaudat, harjakatto ja piippu. Ikkunat ja ovi lisätään erikseen.
func _house(x0: float, w: float, depth: float, hh: float, wall: Color, roof_col: Color, roof_deg := 30.0) -> void:
	var cx := x0 + w / 2.0
	var cz := FRONT_Z - depth / 2.0
	_solid(Vector3(w + 0.1, 0.25, depth + 0.1), Vector3(cx, 0.125, cz), Color(0.5, 0.5, 0.52))
	_solid(Vector3(w, hh, depth), Vector3(cx, 0.25 + hh / 2.0, cz), wall)
	for sx in [x0, x0 + w]:
		B.mesh(self, B.boxm(Vector3(0.16, hh, 0.16)), Vector3(sx, 0.25 + hh / 2.0, FRONT_Z + 0.02), WHITE)
	B.mesh(self, B.boxm(Vector3(w + 0.05, 0.14, 0.05)), Vector3(cx, 0.32, FRONT_Z + 0.03), WHITE)  # vesilauta
	var base_y := 0.25 + hh
	_roof_x(Vector3(cx, base_y, cz), depth / 2.0, w, wall, roof_col, roof_deg)
	var rise := depth / 2.0 * tan(deg_to_rad(roof_deg))
	B.mesh(self, B.boxm(Vector3(0.55, rise + 0.7, 0.55)), Vector3(x0 + w * 0.78, base_y + (rise + 0.7) / 2.0 - 0.1, cz - depth * 0.18), Color(0.55, 0.3, 0.25))
	B.mesh(self, B.boxm(Vector3(0.7, 0.1, 0.7)), Vector3(x0 + w * 0.78, base_y + rise + 0.55, cz - depth * 0.18), Color(0.25, 0.25, 0.27))


## Patsas ja jalusta: graniittijalusta, nimilaatta ja pronssinen 1600-luvun aatelismies (hattu, kaulus, viitta, kääröä pitelevä käsi).
func _statue(at: Vector3) -> void:
	var granite := Color(0.42, 0.42, 0.45)
	B.mesh(self, B.boxm(Vector3(2.0, 0.35, 2.0)), at + Vector3(0, 0.175, 0), granite.darkened(0.1))
	B.mesh(self, B.boxm(Vector3(1.5, 1.1, 1.5)), at + Vector3(0, 0.9, 0), granite)
	B.mesh(self, B.boxm(Vector3(1.75, 0.18, 1.75)), at + Vector3(0, 1.54, 0), granite.lightened(0.08))
	var body := StaticBody3D.new()
	body.position = at + Vector3(0, 0.9, 0)
	body.add_child(B.box_shape(Vector3(2.0, 1.8, 2.0)))
	add_child(body)
	# Nimilaatta omalla kallistetulla jalustallaan jalustan edessä (+Z = patsaan etu), luettava pelikameralla.
	var plate := B.sign_plate(self, "PIETARI BRAHE\nRaahen perustaja", Color(0.2, 0.2, 0.22), Color(0.95, 0.85, 0.55), 0.3, 64, Color(0.7, 0.6, 0.35))
	plate.position = at + Vector3(0, 0.95, 1.7)
	plate.rotation_degrees.x = -35.0
	for sx in [-1.0, 1.0]:
		B.mesh(self, B.boxm(Vector3(0.1, 0.8, 0.1)), at + Vector3(sx * 0.9, 0.4, 1.66), Color(0.2, 0.2, 0.22))
	# Yksivärinen pronssi: pinnat erottuvat vain sävyllä. Etu = +Z, hahmon vasen käsi = -X.
	var y0 := 1.63
	var bronze := Color(0.3, 0.32, 0.28)
	var bl := bronze.lightened(0.18)
	var bd := bronze.darkened(0.2)
	for s in [-1.0, 1.0]:
		var fz := 0.07 if s > 0.0 else -0.03  # toinen jalka hieman edessä
		B.mesh(self, B.boxm(Vector3(0.16, 0.12, 0.3)), at + Vector3(s * 0.12, y0 + 0.06, fz + 0.06), bd)  # saapas
		B.tube(self, at + Vector3(s * 0.12, y0 + 0.1, fz), at + Vector3(s * 0.12, y0 + 0.5, fz - 0.02), 0.065, bronze)  # pohje
		B.mesh(self, B.sphere(0.075, 8), at + Vector3(s * 0.12, y0 + 0.5, fz - 0.02), bronze)  # polvi
	B.mesh(self, B.cyl(0.23, 0.35, 0.68, 14), at + Vector3(0, y0 + 0.88, 0), bl)  # takin helma
	B.mesh(self, B.cyl(0.24, 0.24, 0.05, 14), at + Vector3(0, y0 + 1.22, 0), bd)  # vyö
	B.mesh(self, B.cyl(0.27, 0.22, 0.5, 14), at + Vector3(0, y0 + 1.47, 0), bl)  # vartalo
	B.mesh(self, B.sphere(0.29, 14), at + Vector3(0, y0 + 1.62, 0), bl).scale = Vector3(1.0, 0.45, 0.6)  # rinta ja hartiat
	B.mesh(self, B.cyl(0.25, 0.3, 0.45, 14), at + Vector3(0, y0 + 1.42, -0.11), bd)  # olkaviitta
	B.mesh(self, B.cyl(0.2, 0.17, 0.06, 12), at + Vector3(0, y0 + 1.73, 0), bl.lightened(0.15))  # pitsikaulus
	B.mesh(self, B.cyl(0.07, 0.07, 0.1, 8), at + Vector3(0, y0 + 1.78, 0), bl)
	B.mesh(self, B.sphere(0.15, 14), at + Vector3(0, y0 + 1.93, 0.01), bl)  # pää
	B.mesh(self, B.sphere(0.03, 6), at + Vector3(0, y0 + 1.92, 0.15), bl)  # nenä
	B.mesh(self, B.cyl(0.08, 0.02, 0.2, 8), at + Vector3(0, y0 + 1.82, 0.11), bd, Vector3(-20, 0, 0))  # kärkiparta
	B.mesh(self, B.cyl(0.31, 0.31, 0.03, 18), at + Vector3(0, y0 + 2.05, 0.01), bd)  # lierihattu
	B.mesh(self, B.cyl(0.14, 0.17, 0.22, 12), at + Vector3(0, y0 + 2.16, 0.01), bd)
	B.mesh(self, B.cyl(0.175, 0.175, 0.04, 12), at + Vector3(0, y0 + 2.08, 0.01), bl)  # hatunnauha
	# oikea käsi (+X) pitää käärettä, vasen (-X) lepää miekan kahvalla
	_arm(at, y0, Vector3(0.29, 1.6, 0), Vector3(0.4, 1.3, 0.1), Vector3(0.34, 1.4, 0.36), false, bl)
	B.tube(self, at + Vector3(0.34, y0 + 1.42, 0.45) + Vector3(-0.17, 0, 0), at + Vector3(0.34, y0 + 1.42, 0.45) + Vector3(0.17, 0, 0), 0.04, bl.lightened(0.2))  # kääre
	_arm(at, y0, Vector3(-0.29, 1.6, 0), Vector3(-0.42, 1.32, 0.0), Vector3(-0.28, 1.2, 0.22), true, bl)
	B.mesh(self, B.sphere(0.04, 8), at + Vector3(-0.27, y0 + 1.2, 0.34), bd)  # kahvan nuppi
	B.tube(self, at + Vector3(-0.27, y0 + 1.2, 0.34), at + Vector3(-0.33, y0 + 0.4, -0.32), 0.03, bd)  # miekka


## Käsivarsi: olka, kyynärpää, ranne ja kämmen (laatta + peukalo) kyynärvarren jatkeena.
func _arm(at: Vector3, y0: float, sh: Vector3, el: Vector3, wr: Vector3, left: bool, col: Color) -> void:
	var o := at + Vector3(0, y0, 0)
	B.tube(self, o + sh, o + el, 0.07, col)
	B.mesh(self, B.sphere(0.07, 8), o + el, col)
	B.tube(self, o + el, o + wr, 0.055, col)
	var dir := (wr - el).normalized()
	var hand := MeshInstance3D.new()
	hand.mesh = B.boxm(Vector3(0.085, 0.035, 0.12))
	var m := StandardMaterial3D.new()
	m.albedo_color = col.lightened(0.1)
	hand.material_override = m
	hand.basis = Basis.looking_at(-dir, Vector3.UP)  # +Z = sormien suunta
	hand.position = o + wr + dir * 0.07
	add_child(hand)
	var thumb := MeshInstance3D.new()
	thumb.mesh = B.boxm(Vector3(0.03, 0.03, 0.07))
	thumb.material_override = m
	thumb.basis = hand.basis
	thumb.position = hand.position + hand.basis.x * (0.05 if left else -0.05) + dir * 0.02
	add_child(thumb)


func _bench(at: Vector3) -> void:
	var wood := Color(0.5, 0.35, 0.2)
	B.mesh(self, B.boxm(Vector3(1.7, 0.06, 0.5)), at + Vector3(0, 0.45, 0), wood)
	B.mesh(self, B.boxm(Vector3(1.7, 0.4, 0.05)), at + Vector3(0, 0.75, 0.24), wood, Vector3(-10, 0, 0))
	for sx in [-0.75, 0.75]:
		B.mesh(self, B.boxm(Vector3(0.06, 0.45, 0.45)), at + Vector3(sx, 0.225, 0), Color(0.2, 0.2, 0.22))


func _lantern(at: Vector3) -> void:
	B.mesh(self, B.cyl(0.04, 0.05, 2.3, 8), at + Vector3(0, 1.15, 0), Color(0.12, 0.12, 0.14))
	B.mesh(self, B.boxm(Vector3(0.32, 0.42, 0.32)), at + Vector3(0, 2.5, 0), Color(1.0, 0.85, 0.45))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.mesh(self, B.boxm(Vector3(0.03, 0.44, 0.03)), at + Vector3(sx * 0.16, 2.5, sz * 0.16), Color(0.12, 0.12, 0.14))
	B.mesh(self, PrismMesh.new(), at + Vector3(0, 2.85, 0), Color(0.12, 0.12, 0.14)).scale = Vector3(0.5, 0.3, 0.5)
	B.mesh(self, B.boxm(Vector3(0.4, 0.04, 0.4)), at + Vector3(0, 2.28, 0), Color(0.12, 0.12, 0.14))
	var l := OmniLight3D.new()
	l.position = at + Vector3(0, 2.4, 0.3)
	l.light_color = Color(1.0, 0.85, 0.55)
	l.light_energy = 0.8
	l.omni_range = 5.0
	add_child(l)


func _stop_sign(id: String, num: int, text: String) -> void:
	var p: Vector3 = STOPS[id].pos
	B.sign_pole(self, p + Vector3(1.3, 0, 0.4), 1.5)
	var s := B.sign_plate(self, "%d  %s" % [num, text], Color(0.18, 0.32, 0.22), Color(0.97, 0.95, 0.85), 0.34, 72, Color(0.9, 0.85, 0.6))
	s.position = p + Vector3(1.3, 1.5, 0.35)
	s.rotation_degrees.x = -35.0  # kallistettu ylhäältä katsovaa kameraa kohti


func _build() -> void:
	var grass := Color(0.38, 0.55, 0.25)
	var gravel := Color(0.56, 0.5, 0.4)
	B.mesh(self, B.boxm(Vector3(160, 0.2, 90)), Vector3(0, -0.4, 0), Color(0.2, 0.34, 0.18))
	B.mesh(self, B.boxm(Vector3(WALK_RECT.size.x + 6.0, 0.1, 17.0)), Vector3(2.5, -0.05, 4.0), grass)
	B.mesh(self, B.boxm(Vector3(46.0, 0.02, 9.6)), Vector3(3.0, 0.005, 0.2), gravel)  # katu talojen edessä
	# Rannan vesi talojen takana.
	B.mesh(self, B.boxm(Vector3(80.0, 0.1, 30.0)), Vector3(2.0, -0.12, -25.0), Color(0.2, 0.42, 0.55))
	# Pekkatori: mukulakivipäällyste (pohja ja saumaviivat).
	B.mesh(self, B.boxm(Vector3(12.0, 0.03, 9.0)), Vector3(-9.0, 0.012, 0.0), Color(0.5, 0.47, 0.43))
	for i in 21:
		B.mesh(self, B.boxm(Vector3(0.025, 0.012, 9.0)), Vector3(-14.8 + i * 0.58, 0.03, 0.0), Color(0.32, 0.3, 0.28))
	for i in 15:
		B.mesh(self, B.boxm(Vector3(12.0, 0.012, 0.025)), Vector3(-9.0, 0.032, -4.3 + i * 0.6), Color(0.32, 0.3, 0.28))
	# Rantakuja (x 17..19.6): kiveys talojen välissä rantaan.
	B.mesh(self, B.boxm(Vector3(2.6, 0.03, 8.0)), Vector3(18.3, 0.012, FRONT_Z - 4.0), Color(0.48, 0.45, 0.42))
	for i in 5:
		B.mesh(self, B.boxm(Vector3(2.6, 0.012, 0.03)), Vector3(18.3, 0.032, FRONT_Z - 1.0 - i * 1.5), Color(0.32, 0.3, 0.28))
	# Tie, taksi.
	B.mesh(self, B.boxm(Vector3(46.0, 0.02, 3.0)), Vector3(3.0, 0.003, 8.8), Color(0.3, 0.3, 0.32))
	B.mesh(self, B.boxm(Vector3(46.0, 0.025, 0.12)), Vector3(3.0, 0.01, 8.8), Color(0.9, 0.8, 0.3))
	var taxi := Node3D.new()
	taxi.position = Vector3(-17.0, 0, 8.3)
	taxi.rotation.y = PI / 2.0
	add_child(taxi)
	Vehicles.taxi(taxi)
	# Pekkatori ja patsas, penkit.
	_statue(Vector3(-9.0, 0, -1.8))
	_bench(Vector3(-12.5, 0, 0.2))
	_bench(Vector3(-5.8, 0, 0.2))
	# Talorivi: keltainen, punamulta, kaksikerroksinen valkoinen kauppiaantalo, makasiini.
	_house(-2.0, 6.4, 5.5, 2.7, Color(0.88, 0.72, 0.36), Color(0.3, 0.17, 0.14))
	for wx in [-0.8, 2.7, 3.8]:
		_window(wx, 1.75)
	_door(1.0, Color(0.12, 0.3, 0.22))
	_house(4.9, 5.4, 5.5, 2.7, Color(0.62, 0.2, 0.15), Color(0.25, 0.25, 0.28))
	for wx in [5.9, 9.2]:
		_window(wx, 1.75, Color(0.15, 0.3, 0.22))
	_door(7.6, Color(0.9, 0.88, 0.78))
	_house(10.7, 6.3, 6.0, 5.1, Color(0.93, 0.9, 0.8), Color(0.28, 0.2, 0.18))
	for wx in [11.8, 15.9]:
		_window(wx, 1.75)
	for wx in [11.8, 15.9]:
		_window(wx, 4.0, Color(0.2, 0.35, 0.3))
	_door(13.85, Color(0.2, 0.35, 0.3))
	B.mesh(self, B.boxm(Vector3(1.9, 0.1, 0.9)), Vector3(13.85, 3.1, FRONT_Z + 0.45), Color(0.35, 0.25, 0.2))  # parveke oven yllä
	for sx in [-0.9, 0.9]:
		B.mesh(self, B.boxm(Vector3(0.06, 0.9, 0.06)), Vector3(13.85 + sx, 3.6, FRONT_Z + 0.85), WHITE)
	B.mesh(self, B.boxm(Vector3(1.9, 0.06, 0.06)), Vector3(13.85, 4.05, FRONT_Z + 0.85), WHITE)
	for sx in [-0.9, 0.9]:
		B.mesh(self, B.boxm(Vector3(0.06, 0.9, 0.9)), Vector3(13.85 + sx, 3.6, FRONT_Z + 0.45), WHITE)
	B.mesh(self, B.boxm(Vector3(0.9, 1.6, 0.04)), Vector3(13.85, 3.9, FRONT_Z + 0.03), GLASS)  # parvekkeen ovi
	B.mesh(self, B.boxm(Vector3(0.06, 1.6, 0.05)), Vector3(13.85, 3.9, FRONT_Z + 0.05), WHITE)
	# Makasiini: tervattu punamulta, pystylaudoitus, kaksoisovi, nostopuomi.
	_house(19.6, 5.2, 5.0, 3.4, Color(0.45, 0.14, 0.1), Color(0.2, 0.16, 0.14), 35.0)
	for i in 9:
		B.mesh(self, B.boxm(Vector3(0.05, 3.3, 0.03)), Vector3(19.9 + i * 0.58, 0.25 + 1.65, FRONT_Z + 0.02), Color(0.35, 0.1, 0.07))
	var door_c := Color(0.32, 0.22, 0.14)
	B.mesh(self, B.boxm(Vector3(2.5, 2.6, 0.06)), Vector3(22.2, 0.25 + 1.3, FRONT_Z + 0.06), WHITE)
	for sx in [-1.0, 1.0]:
		B.mesh(self, B.boxm(Vector3(1.1, 2.4, 0.07)), Vector3(22.2 + sx * 0.58, 0.25 + 1.2, FRONT_Z + 0.1), door_c)
		B.tube(self, Vector3(22.2 + sx * 0.1, 0.3, FRONT_Z + 0.15), Vector3(22.2 + sx * 1.1, 2.55, FRONT_Z + 0.15), 0.04, Color(0.15, 0.15, 0.17))  # ristikko
		for k in 3:
			B.mesh(self, B.boxm(Vector3(1.0, 0.04, 0.03)), Vector3(22.2 + sx * 0.58, 0.55 + k * 0.85, FRONT_Z + 0.15), Color(0.15, 0.15, 0.17))
	B.mesh(self, B.boxm(Vector3(0.8, 0.42, 0.05)), Vector3(22.2, 3.08, FRONT_Z + 0.04), door_c)  # yläluukku
	B.mesh(self, B.boxm(Vector3(0.1, 0.1, 1.3)), Vector3(22.2, 3.45, FRONT_Z + 0.6), Color(0.3, 0.2, 0.12))  # nostopuomi, roikkuu räystään alla
	B.mesh(self, B.sphere(0.09, 8), Vector3(22.2, 3.38, FRONT_Z + 1.2), Color(0.15, 0.15, 0.17))
	B.mesh(self, B.cyl(0.015, 0.015, 0.9, 6), Vector3(22.2, 2.9, FRONT_Z + 1.2), Color(0.7, 0.6, 0.4))
	for bp in [Vector3(20.7, 0, -3.8), Vector3(24.0, 0, -3.9)]:
		B.mesh(self, B.cyl(0.32, 0.3, 0.8, 10), bp + Vector3(0, 0.4, 0), Color(0.42, 0.3, 0.18))
		B.mesh(self, B.cyl(0.33, 0.33, 0.05, 10), bp + Vector3(0, 0.28, 0), Color(0.2, 0.2, 0.22))
		B.mesh(self, B.cyl(0.33, 0.33, 0.05, 10), bp + Vector3(0, 0.6, 0), Color(0.2, 0.2, 0.22))
	# Katulyhty rantakujan suulla.
	_lantern(Vector3(18.3, 0, -4.0))
	# Pysähdysten kyltit.
	_stop_sign("patsas", 1, "PEKKATORI")
	_stop_sign("ovet", 2, "VANHAT OVET")
	_stop_sign("kauppiaantalo", 3, "KAUPPIAAN TALO")
	_stop_sign("kuja", 4, "RANTAKUJA")
	_stop_sign("makasiini", 5, "MAKASIINI")
	B.sign_pole(self, Vector3(-18.6, 0, 5.4), 1.9)
	var intro := B.sign_plate(self, "WANHA RAAHE\nKävelyreitti: 5 kuvapaikkaa", Color(0.18, 0.3, 0.4), Color(0.97, 0.95, 0.85), 0.34, 72, Color(0.9, 0.85, 0.6))
	intro.position = Vector3(-18.6, 1.9, 5.35)
	intro.rotation_degrees.x = -35.0
	# Puita ja valaistus.
	for p in [Vector3(-15.5, 0, -2.5), Vector3(-3.3, 0, 3.6), Vector3(10.4, 0, 3.0), Vector3(16.0, 0, 3.8), Vector3(-19.0, 0, 4.5)]:
		_birch(p, 0.8 + fposmod(p.x, 0.3))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(2.0, 6.0, 1.0)
	lamp.light_color = Color(1.0, 0.95, 0.8)
	lamp.light_energy = 0.25
	lamp.omni_range = 40.0
	add_child(lamp)
