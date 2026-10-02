extends Node3D
## Kodin (Järvikuja 1) sisätila: erillinen tasku kuten mökin sisätila (mokki_interior.gd). Etuovelta sisään
## (main.gd _enter_home), kävely player_walker.gd:llä ylhäältä kuvattuna, katto pois. Etuovelta katsottuna:
## vasemman seinän täyttävät makuuhuoneet (edessä kerrossänky, perällä parisänky) ja niiden välissä WC, johon
## pääsee tupakeittiöstä; oikealla kylpyhuone ja sauna; suoraan edessä tupakeittiö, joka jatkuu oikealle, ja
## perimmäisenä oikealla nörtin huone. Tupakeittiön takaseinässä etuovea vastapäätä takaovi pihalle. Nukkumaan
## pääsee vain parisänkyyn (slept: päivä päättyy).
## Toiminnot ilmoitetaan acted-signaalilla (tilavaikutukset ja viestit main.gd _on_home_acted).
## Paikallinen +Z = etuovi (kameran puoli), -Z = takaseinä ja takaovi, -X = vasen.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(10.0, 6.0)  # huoneiston puolikas (x, z)
const WALL_H := 2.5
const LOW_WALL := 1.0  # kameran puoleisten (x-akselin suuntaisten) väliseinien näkyvä korkeus
## Pohja (x vasemmalta oikealle, z edestä taakse): vasen seinä täynnä makuuhuoneita (edessä kerrossänky, välissä
## tupakeittiöstä aukeava WC, perällä parisänky), eteinen etuovelta suoraan tupakeittiöön, oikealla edessä
## kylpyhuone ja sauna, tupakeittiö jatkuu oikealle ja perimmäisenä oikealla nörtin huone.
const LEFT_X := -4.0   # makuuhuoneiden ja WC:n seinä (eteinen ja tupakeittiö sen oikealla)
const HALL_X := -1.0   # eteisen oikea seinä (kylpyhuone sen oikealla)
const FRONT_Z := 1.5   # etuosan (makuuhuone 1, eteinen, kylpyhuone, sauna) ja tupakeittiön raja
const WC_Z := -0.5     # WC:n ja makuuhuone 2:n välinen seinä
const BATH_X := 4.5    # kylpyhuoneen ja saunan välinen seinä
const NERD_X := 6.0    # tupakeittiön ja nörtin huoneen välinen seinä
const DOOR_X := -2.5   # etuovi ja sitä vastapäätä takaovi
## Toimintopisteet: id -> [paikka, vihje].
const SPOTS := {
	"ovi": [Vector3(DOOR_X, 0, 5.3), "[E] Ulos etuovesta"],
	"takaovi": [Vector3(DOOR_X, 0, -5.3), "[E] Ulos takaovesta pihalle"],
	"kerrossanky": [Vector3(-8.6, 0, 3.9), "Kerrossänky. Vieraille ja kavereille, ei Päivin viereen."],
	"sanky": [Vector3(-6.6, 0, -3.2), "[E] Mene nukkumaan parisänkyyn (päivä päättyy)"],
	"wc": [Vector3(-8.6, 0, 0.5), "[E] Käy pöntöllä"],
	"peili": [Vector3(-6.4, 0, 0.6), "[E] Katso peiliin"],
	"suihku": [Vector3(3.6, 0, 4.9), "[E] Käy suihkussa"],
	"sauna": [Vector3(7.0, 0, 3.6), "[E] Heitä löylyä"],
	"kahvi": [Vector3(2.0, 0, -4.6), "[E] Keitä kahvit"],
	"jaakaappi": [Vector3(5.0, 0, -4.4), "[E] Kurkkaa jääkaappiin"],
	"tv": [Vector3(-0.2, 0, -4.3), "[E] Katso telkkaria"],
	"sohva": [Vector3(1.7, 0, -2.8), "[E] Ota nokoset sohvalla"],
	"nortti": [Vector3(8.0, 0, -3.6), "[E] Jutskaa nörtin kanssa"],
}
const NERD_LOOK := {
	"shirt": Color(0.12, 0.12, 0.14), "pants": Color(0.25, 0.27, 0.32), "shoes": Color(0.9, 0.9, 0.9),
	"hair": "Hair_Long", "hair_color": Color(0.2, 0.15, 0.1), "height": 1.82, "belly": 0.2, "bulk": -0.2,
}
const NERD_LINES := [
	"Älä tuu tänne, mulla on raidi kesken!",
	"Ookko sää kuullu, että Saloisissa on nyt valokuitu? No ei oo. Siksi lagaa.",
	"Mää en lähe kauppaan. Tilaa vaikka ruokaa netistä... ai ei tänne tuu.",
	"Hiljaa! Mää striimaan. Kakskytäviis kattojaa, niistä kolme on Raahesta.",
	"Isä, oikeesti. Ovi kiinni ku lähet.",
	"Mää rakensin tähän kolmannen näytön. Päivi sano, että sähkölasku tuplaantu.",
	"Jos sää löydät mun energiajuomat jääkaapista, ne on mun.",
]

signal exited
signal slept
signal acted(kind: String)

var active := false
var exit_door := "ovi"  # kummasta ovesta viimeksi lähdettiin ulos (ovi / takaovi)
var walker: CharacterBody3D
var hint := ""
var _enter_frame := -1

var _nerd: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _tv_screen: MeshInstance3D
var _screens: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_room()
	_build_bedrooms()
	_build_bath_sauna()
	_build_kitchen_living()
	_build_nerd_room()
	walker = Walker.new()
	walker.position = SPOTS.ovi[0]
	add_child(walker)


func enter(door := "ovi") -> void:
	active = true
	_enter_frame = Engine.get_process_frames()  # sisään vienyt E ei saa samalla ruudulla viedä ulos
	if door == "takaovi":
		walker.position = SPOTS.takaovi[0] + Vector3(0, 0, 1.3)
		walker.rotation.y = B.yaw_to(Vector3(0, 0, -1))
	else:
		walker.position = SPOTS.ovi[0] + Vector3(0, 0, -1.3)
		walker.rotation.y = B.yaw_to(Vector3(0, 0, 1))  # katse eteiseen (walkerin kääntö on yaw_to:n vastainen)
	walker.activate()


func leave() -> void:
	active = false
	walker.controls_enabled = false


func nerd_say(text: String) -> void:
	_bubble.text = "Nörtti: " + text
	_bubble_t = 3.5
	_nerd.play("Sitting_Talking", 0.3)


func _process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble_t <= 0.0 and _bubble.text != "":
		_bubble.text = ""
		_nerd.play("Sitting_Idle", 0.3)
	var t := Time.get_ticks_msec() / 1000.0
	if _tv_screen.visible:
		(_tv_screen.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.45, 0.8).lightened(0.3 * sin(t * 5.5))
	for i in _screens.size():
		(_screens[i].material_override as StandardMaterial3D).albedo_color = Color(0.2, 0.75, 0.4).lerp(
			Color(0.6, 0.3, 0.9), 0.5 + 0.5 * sin(t * (2.0 + i)))
	if not active:
		hint = ""
		return
	var p := walker.position
	var best := ""
	var bd := 1.3
	for id in SPOTS:
		var d := Vector2(p.x - SPOTS[id][0].x, p.z - SPOTS[id][0].z).length()
		if d < bd:
			bd = d
			best = id
	hint = "" if best == "" else SPOTS[best][1]
	if best == "" or not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	match best:
		"ovi", "takaovi":
			exit_door = best
			exited.emit()
		"sanky":
			slept.emit()
		"kerrossanky":
			pass
		"nortti":
			nerd_say(NERD_LINES.pick_random())
			acted.emit("nortti")
		"tv":
			_tv_screen.visible = true
			acted.emit("tv")
		_:
			acted.emit(best)


# --- Rakennus ---------------------------------------------------------------------

## Seinä (törmäyksellä) paikallisesta pisteestä a pisteeseen b (akselinsuuntainen), korkeus h.
func _wall(a: Vector2, b: Vector2, h: float, col: Color, collide_h := WALL_H) -> void:
	var c := (a + b) / 2.0
	var size := Vector3(maxf(absf(b.x - a.x), 0.15), h, maxf(absf(b.y - a.y), 0.15))
	B.mesh(self, B.boxm(size), Vector3(c.x, h / 2.0, c.y), col)
	var body := StaticBody3D.new()
	body.position = Vector3(c.x, 0, c.y)
	body.add_child(B.box_shape(Vector3(size.x, collide_h, size.z), Vector3(0, collide_h / 2.0, 0)))
	add_child(body)


## Seinä x-akselin suuntaan (z vakio) väleistä x0..x1 aukkoja ohittaen (gaps = [[x_alku, x_loppu], ...]).
func _wall_x(z: float, x0: float, x1: float, gaps: Array, h: float, col: Color) -> void:
	var x := x0
	for g in gaps:
		if g[0] > x:
			_wall(Vector2(x, z), Vector2(g[0], z), h, col)
		x = g[1]
	if x1 > x:
		_wall(Vector2(x, z), Vector2(x1, z), h, col)


## Seinä z-akselin suuntaan (x vakio) väleistä z0..z1 aukkoja ohittaen.
func _wall_z(x: float, z0: float, z1: float, gaps: Array, h: float, col: Color) -> void:
	var z := z0
	for g in gaps:
		if g[0] > z:
			_wall(Vector2(x, z), Vector2(x, g[0]), h, col)
		z = g[1]
	if z1 > z:
		_wall(Vector2(x, z), Vector2(x, z1), h, col)


## Kiinteä huonekalu (laatikko törmäyksellä).
func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := B.mesh(self, B.boxm(size), pos, col)
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	add_child(body)
	return mi


func _floor(r: Rect2, col: Color, y := 0.0) -> void:
	B.mesh(self, B.boxm(Vector3(r.size.x, 0.04, r.size.y)), Vector3(r.get_center().x, y + 0.02, r.get_center().y), col)


func _door_leaf(pos: Vector3, along_x: bool, col: Color) -> void:
	B.mesh(self, B.boxm(Vector3(1.0, 2.1, 0.06) if along_x else Vector3(0.06, 2.1, 1.0)), pos + Vector3(0, 1.05, 0), col)


func _build_room() -> void:
	var white := Color(0.93, 0.92, 0.88)
	var wall2 := white.darkened(0.06)
	# Lattia: tummaa maata ympärille, parketti eteiseen ja tupakeittiöön, matot makuuhuoneisiin, laatat pesutiloihin.
	B.mesh(self, B.boxm(Vector3(80, 0.2, 80)), Vector3(0, -0.2, 0), Color(0.12, 0.12, 0.14))
	_floor(Rect2(-HALF.x, -HALF.y, HALF.x * 2.0, HALF.y * 2.0), Color(0.66, 0.5, 0.32))
	_floor(Rect2(-HALF.x, FRONT_Z, LEFT_X + HALF.x, HALF.y - FRONT_Z), Color(0.45, 0.55, 0.65), 0.005)
	_floor(Rect2(-HALF.x, WC_Z, LEFT_X + HALF.x, FRONT_Z - WC_Z), Color(0.85, 0.87, 0.88), 0.005)
	_floor(Rect2(-HALF.x, -HALF.y, LEFT_X + HALF.x, WC_Z + HALF.y), Color(0.62, 0.45, 0.5), 0.005)
	_floor(Rect2(HALL_X, FRONT_Z, BATH_X - HALL_X, HALF.y - FRONT_Z), Color(0.85, 0.87, 0.88), 0.005)
	_floor(Rect2(BATH_X, FRONT_Z, HALF.x - BATH_X, HALF.y - FRONT_Z), Color(0.5, 0.36, 0.22), 0.005)
	_floor(Rect2(NERD_X, -HALF.y, HALF.x - NERD_X, FRONT_Z + HALF.y), Color(0.3, 0.3, 0.34), 0.005)
	# Ulkoseinät: takaseinä täyskorkea (takaovi etuovea vastapäätä), päädyt täyskorkeat, etuseinä matala.
	var door_gap := [[DOOR_X - 0.55, DOOR_X + 0.55]]
	_wall_x(-HALF.y, -HALF.x, HALF.x, door_gap, WALL_H, white)
	_wall_x(HALF.y, -HALF.x, HALF.x, door_gap, 0.5, white)
	_wall(Vector2(-HALF.x, -HALF.y), Vector2(-HALF.x, HALF.y), WALL_H, white)
	_wall(Vector2(HALF.x, -HALF.y), Vector2(HALF.x, HALF.y), WALL_H, white)
	_door_leaf(Vector3(DOOR_X, 0, -HALF.y + 0.08), true, Color(0.55, 0.38, 0.22))  # takaovi
	B.mesh(self, B.boxm(Vector3(1.2, 0.04, 0.6)), Vector3(DOOR_X, 0.03, HALF.y - 0.5), Color(0.25, 0.3, 0.2))  # kynnysmatto
	# Vasen seinälinja: makuuhuone 1 (ovi eteisestä), WC ja makuuhuone 2 (ovet tupakeittiöstä).
	_wall_z(LEFT_X, -HALF.y, HALF.y, [[-2.0, -1.0], [0.0, 1.0], [3.3, 4.3]], WALL_H, wall2)
	_wall_x(FRONT_Z, -HALF.x, LEFT_X, [], LOW_WALL, wall2)
	_wall_x(WC_Z, -HALF.x, LEFT_X, [], LOW_WALL, wall2)
	# Eteisen oikea seinä (ovi kylpyhuoneeseen); kylpyhuone ja sauna tupakeittiöstä matalalla seinällä.
	_wall_z(HALL_X, FRONT_Z, HALF.y, [[3.5, 4.5]], WALL_H, wall2)
	_wall_x(FRONT_Z, HALL_X, HALF.x, [], LOW_WALL, wall2)
	_wall_z(BATH_X, FRONT_Z, HALF.y, [[2.3, 3.2]], WALL_H, Color(0.45, 0.32, 0.2))
	# Nörtin huone tupakeittiön oikealla (ovi tupakeittiöstä).
	_wall_z(NERD_X, -HALF.y, FRONT_Z, [[-1.6, -0.6]], WALL_H, wall2)
	for l in [Vector3(DOOR_X, 2.3, 3.5), Vector3(-7.0, 2.3, 3.8), Vector3(-7.0, 2.3, 0.5), Vector3(-7.0, 2.3, -3.2),
			Vector3(1.8, 2.3, 3.8), Vector3(7.2, 2.3, 3.8), Vector3(-1.0, 2.3, -3.0), Vector3(3.5, 2.3, -3.0),
			Vector3(8.0, 2.3, -2.5)]:
		var light := OmniLight3D.new()
		light.position = l
		light.omni_range = 8.0
		light.light_energy = 0.45
		add_child(light)


func _build_bedrooms() -> void:
	# Makuuhuone 1 (vasemmalla etuovea lähinnä): violetti kerrossänky vasenta seinää vasten, lelulaatikko.
	var bunk := Color(0.5, 0.32, 0.6)
	var bx := -8.6
	var bz := 5.2
	for y in [0.45, 1.55]:
		_solid(Vector3(2.0, 0.22, 0.95), Vector3(bx, y, bz), bunk)
		B.mesh(self, B.boxm(Vector3(1.9, 0.12, 0.9)), Vector3(bx, y + 0.17, bz), Color(0.92, 0.9, 0.95))
		B.mesh(self, B.boxm(Vector3(0.4, 0.1, 0.6)), Vector3(bx - 0.75, y + 0.27, bz), Color(0.95, 0.95, 0.95))
	for px in [-0.98, 0.98]:
		for pz in [-0.45, 0.45]:
			B.mesh(self, B.boxm(Vector3(0.08, 2.0, 0.08)), Vector3(bx + px, 1.0, bz + pz), bunk.darkened(0.2))
	for k in 5:
		B.mesh(self, B.boxm(Vector3(0.05, 0.05, 0.5)), Vector3(bx + 1.05, 0.5 + k * 0.28, bz - 0.2), bunk.darkened(0.3))  # tikkaat
	_solid(Vector3(0.8, 0.5, 0.5), Vector3(-5.0, 0.25, 2.0), Color(0.85, 0.6, 0.2))  # lelulaatikko
	# Makuuhuone 2 (perällä vasemmalla): parisänky päädyllään vasenta seinää vasten, yöpöydät ja vaatekaappi.
	var bed := Vector3(-8.4, 0, -3.2)
	_solid(Vector3(2.1, 0.45, 1.8), bed + Vector3(0, 0.225, 0), Color(0.55, 0.4, 0.28))
	B.mesh(self, B.boxm(Vector3(2.0, 0.18, 1.7)), bed + Vector3(0.05, 0.54, 0), Color(0.95, 0.94, 0.9))
	B.mesh(self, B.boxm(Vector3(1.3, 0.06, 1.72)), bed + Vector3(0.45, 0.66, 0), Color(0.75, 0.25, 0.3))  # päiväpeitto
	for sz in [-0.45, 0.45]:
		B.mesh(self, B.boxm(Vector3(0.4, 0.14, 0.7)), bed + Vector3(-0.75, 0.7, sz), Color(0.97, 0.97, 0.97))
	B.mesh(self, B.boxm(Vector3(0.12, 1.0, 1.9)), bed + Vector3(-1.1, 0.5, 0), Color(0.45, 0.32, 0.22))  # pääty
	for sz in [-1.3, 1.3]:
		_solid(Vector3(0.5, 0.5, 0.45), bed + Vector3(-0.8, 0.25, sz), Color(0.6, 0.45, 0.3))
	_solid(Vector3(1.6, 2.0, 0.55), Vector3(-6.0, 1.0, -HALF.y + 0.32), Color(0.88, 0.86, 0.8))  # vaatekaappi


func _build_bath_sauna() -> void:
	# WC makuuhuoneiden välissä (ovi tupakeittiöstä): pönttö vasemmalla seinällä, allas ja peili.
	_solid(Vector3(0.65, 0.45, 0.45), Vector3(-9.6, 0.225, 0.5), Color(0.97, 0.97, 0.97))  # pönttö
	_solid(Vector3(0.7, 0.85, 0.45), Vector3(-6.4, 0.425, FRONT_Z - 0.28), Color(0.95, 0.95, 0.95))  # allas
	B.mesh(self, B.boxm(Vector3(0.6, 0.7, 0.04)), Vector3(-6.4, 1.5, FRONT_Z - 0.06), Color(0.75, 0.85, 0.9))  # peili
	# Kylpyhuone (oikealla eteisestä): suihku perimmäisessä nurkassa lasiseinän takana, pesukone ja penkki.
	var glass := Color(0.7, 0.85, 0.9, 0.35)
	B.mesh(self, B.boxm(Vector3(0.05, 2.0, 1.4)), Vector3(2.8, 1.0, 5.2), glass)
	B.mesh(self, B.cyl(0.08, 0.08, 0.05, 10), Vector3(3.8, 2.1, 5.4), Color(0.75, 0.75, 0.78))
	_solid(Vector3(0.6, 0.85, 0.6), Vector3(-0.5, 0.425, 2.2), Color(0.95, 0.95, 0.96))  # pesukone
	B.mesh(self, B.cyl(0.18, 0.18, 0.02, 14), Vector3(-0.5, 0.55, 1.88), Color(0.3, 0.35, 0.4), Vector3(90, 0, 0))
	# Sauna (kylpyhuoneen oikealla): lauteet perällä oikeaa seinää vasten ja sähkökiuas perimmäisessä nurkassa.
	var wood := Color(0.72, 0.52, 0.3)
	var sz := (HALF.y + FRONT_Z) / 2.0
	_solid(Vector3(1.4, 0.45, HALF.y - FRONT_Z - 0.2), Vector3(HALF.x - 0.7, 0.225, sz), wood)
	_solid(Vector3(0.8, 0.45, HALF.y - FRONT_Z - 0.2), Vector3(HALF.x - 1.8, 0.45, sz), wood.darkened(0.08))
	_solid(Vector3(0.6, 0.8, 0.6), Vector3(BATH_X + 0.5, 0.4, HALF.y - 0.5), Color(0.25, 0.25, 0.27))  # kiuas
	for k in 6:
		B.mesh(self, B.sphere(0.1, 6), Vector3(BATH_X + 0.35 + (k % 3) * 0.15, 0.85, HALF.y - 0.6 + (k / 3) * 0.2), Color(0.35, 0.33, 0.3))


func _build_kitchen_living() -> void:
	var white := Color(0.93, 0.92, 0.88)
	# Keittiö tupakeittiön oikeassa päässä takaseinällä: kaapit, liesi, kahvinkeitin, jääkaappi; ruokapöytä.
	_solid(Vector3(3.6, 0.9, 0.7), Vector3(2.9, 0.45, -HALF.y + 0.4), white)
	B.mesh(self, B.boxm(Vector3(3.7, 0.05, 0.75)), Vector3(2.9, 0.92, -HALF.y + 0.4), Color(0.25, 0.25, 0.27))
	B.mesh(self, B.boxm(Vector3(0.6, 0.02, 0.5)), Vector3(3.6, 0.95, -HALF.y + 0.4), Color(0.08, 0.08, 0.08))  # liesi
	B.mesh(self, B.boxm(Vector3(0.25, 0.35, 0.25)), Vector3(2.0, 1.12, -HALF.y + 0.35), Color(0.1, 0.1, 0.1))  # kahvinkeitin
	_solid(Vector3(0.8, 1.9, 0.7), Vector3(5.3, 0.95, -HALF.y + 0.4), Color(0.85, 0.86, 0.88))  # jääkaappi
	B.mesh(self, B.boxm(Vector3(3.6, 0.7, 0.4)), Vector3(2.9, 1.85, -HALF.y + 0.25), white)  # yläkaapit
	_solid(Vector3(1.8, 0.75, 1.0), Vector3(3.6, 0.375, -0.8), Color(0.72, 0.52, 0.3))  # ruokapöytä
	for dx in [-0.6, 0.6]:
		for dz in [-0.75, 0.75]:
			B.mesh(self, B.boxm(Vector3(0.42, 0.45, 0.42)), Vector3(3.6 + dx, 0.225, -0.8 + dz), Color(0.6, 0.42, 0.25))
	# Tupa suoraan eteisestä: telkkari takaseinällä takaoven oikealla, sohva sen edessä ja matto.
	var tvx := -0.2
	B.mesh(self, B.boxm(Vector3(3.2, 0.02, 2.4)), Vector3(tvx, 0.02, -3.6), Color(0.35, 0.42, 0.55))
	var sofa := Color(0.3, 0.33, 0.38)
	_solid(Vector3(2.6, 0.45, 0.9), Vector3(tvx, 0.225, -2.8), sofa)
	B.mesh(self, B.boxm(Vector3(2.6, 0.5, 0.25)), Vector3(tvx, 0.7, -2.38), sofa.darkened(0.1))
	_solid(Vector3(1.6, 0.5, 0.45), Vector3(tvx, 0.25, -HALF.y + 0.3), Color(0.25, 0.2, 0.16))  # TV-taso
	B.mesh(self, B.boxm(Vector3(1.5, 0.9, 0.08)), Vector3(tvx, 1.1, -HALF.y + 0.3), Color(0.05, 0.05, 0.06))
	_tv_screen = MeshInstance3D.new()
	_tv_screen.mesh = B.boxm(Vector3(1.38, 0.8, 0.02))
	_tv_screen.material_override = B.unshaded(Color(0.3, 0.45, 0.8))
	_tv_screen.position = Vector3(tvx, 1.1, -HALF.y + 0.36)
	_tv_screen.visible = false
	add_child(_tv_screen)


func _build_nerd_room() -> void:
	# Nörtin huone oikealla perällä: kolmen näytön pöytä takaseinällä, pelituoli, sänky ja julisteet.
	var dx := 8.0
	_solid(Vector3(2.4, 0.75, 0.8), Vector3(dx, 0.375, -HALF.y + 0.45), Color(0.15, 0.15, 0.17))
	for i in 3:
		var sx := dx - 0.8 + i * 0.8
		B.mesh(self, B.boxm(Vector3(0.7, 0.45, 0.05)), Vector3(sx, 1.2, -HALF.y + 0.3), Color(0.05, 0.05, 0.06))
		var scr := MeshInstance3D.new()
		scr.mesh = B.boxm(Vector3(0.64, 0.4, 0.02))
		scr.material_override = B.unshaded(Color(0.2, 0.75, 0.4))
		scr.position = Vector3(sx, 1.2, -HALF.y + 0.34)
		add_child(scr)
		_screens.append(scr)
	_solid(Vector3(0.5, 0.6, 0.4), Vector3(HALF.x - 0.4, 0.3, -HALF.y + 0.35), Color(0.1, 0.1, 0.12))  # tornikone
	B.mesh(self, B.boxm(Vector3(0.05, 0.4, 0.05)), Vector3(HALF.x - 0.4, 0.35, -HALF.y + 0.56), Color(0.9, 0.2, 0.9))  # RGB-valo
	_solid(Vector3(0.9, 0.4, 2.0), Vector3(HALF.x - 0.5, 0.2, -0.4), Color(0.2, 0.22, 0.3))  # sänky
	for j in 2:
		B.mesh(self, B.boxm(Vector3(0.04, 0.9, 0.65)), Vector3(HALF.x - 0.05, 1.6, -4.4 + j * 1.0),
			[Color(0.8, 0.2, 0.2), Color(0.2, 0.4, 0.8)][j])  # julisteet
	for k in 4:
		B.mesh(self, B.cyl(0.035, 0.035, 0.13, 8), Vector3(dx + 0.6 + k * 0.12, 0.82, -HALF.y + 0.65), Color(0.1, 0.8, 0.3))  # tölkit
	_nerd = Looks.make(self, NERD_LOOK)
	_nerd.position = Vector3(dx, 0, -4.7)
	_nerd.rotation.y = B.yaw_to(Vector3(0, 0, -1))
	_nerd.play("Sitting_Idle", 0.0)
	var headset := Node3D.new()
	B.mesh(headset, B.cyl(0.09, 0.09, 0.04, 10), Vector3(0, 0, 0), Color(0.05, 0.05, 0.05), Vector3(0, 0, 90))
	_nerd.attach("Head", headset, Vector3(0, 0.12, 0))
	var body := StaticBody3D.new()
	body.position = _nerd.position
	body.add_child(B.capsule_shape(0.35, 1.4))
	add_child(body)
	_bubble = B.bubble(self, _nerd.position + Vector3(0, 1.7, 0.3), Color.WHITE, 0.7)
