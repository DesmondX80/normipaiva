extends Node3D
## Rautatieaseman odotussali sisältä (Saloinen ja Vaala, sama tasku; enter() vaihtaa nimen): ruutulattia, ruskea
## paneloitu seinän alaosa ja vaaleanvihreä yläosa, selkä selkää vasten olevat puupenkit, suljettu lippuluukku,
## lähtevien junien taulu, kaakeliuuni, seinäkello, kahviautomaatti ja VR:n juliste. Loisteputket, yksi välkkyy.
## Penkeillä ja nurkissa kaksi juoppoa ja kaksi narkkaria, jotka pyytävät viinahörppyä ja kertovat palkaksi
## rahakätkön paikan (main.gd: esinevalikko, kätkön merkki kartalle).
## Kävely player_walker.gd:llä ylhäältä kuvattuna. Paikallinen +Z = kadun puoli (matala etuseinä, kamera),
## -Z = laiturin puoli (ovi laiturille ja ikkunat), -X = lippuluukku, +X = kaakeliuuni.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(7.0, 4.5)
const WALL_H := 3.4
const FLOOR_A := Color(0.78, 0.72, 0.6)
const FLOOR_B := Color(0.5, 0.36, 0.24)
const PANEL := Color(0.42, 0.27, 0.15)
const UPPER := Color(0.72, 0.8, 0.68)

var spot := ""
var spots := {
	"ovi": [Vector3(3.6, 0, 3.7), "[E] Ulos kadulle"],
	"laituri": [Vector3(-1.5, 0, -3.7), "[E] Laiturille"],
	"luukku": [Vector3(-5.8, 0, -0.8), "[E] Lippuluukku"],
	"taulu": [Vector3(2.4, 0, -3.7), "[E] Lähtevät junat"],
	"automaatti": [Vector3(5.5, 0, 2.6), "[E] Kahviautomaatti (1 €)"],
}
## Asukkaat: nimi, ulkonäkö, paikka, katse, asento ja vihjeen kuvaus.
const PEOPLE := [
	{"name": "Rane", "kind": "juoppo", "at": Vector3(-1.6, 0, 0.42), "face": Vector3(0, 0, 1), "pose": "Sitting_Idle",
		"look": {"shirt": Color(0.35, 0.3, 0.22), "pants": Color(0.2, 0.2, 0.24), "shoes": Color(0.15, 0.12, 0.1), "hair": "Hair_Long",
			"hair_color": Color(0.5, 0.45, 0.4), "beard": true, "height": 1.76, "skin": Color(0.95, 0.72, 0.66), "belly": 0.7, "shine": 0.2}},
	{"name": "Make", "kind": "juoppo", "at": Vector3(5.0, 0, -2.2), "face": Vector3(-1, 0, 0.4), "pose": "Idle",
		"look": {"shirt": Color(0.12, 0.25, 0.45), "pants": Color(0.3, 0.32, 0.36), "shoes": Color(0.9, 0.9, 0.88), "hair": "Hair_Buzzed",
			"hair_color": Color(0.6, 0.6, 0.58), "height": 1.8, "skin": Color(0.98, 0.7, 0.62), "belly": 0.9, "bulk": 0.2,
			"tracksuit": {"a": Color(0.85, 0.85, 0.85), "b": Color(0.12, 0.25, 0.45)}, "stripes": true, "stripe_color": Color.WHITE}},
	{"name": "Nisse", "kind": "narkkari", "at": Vector3(-6.2, 0, 2.9), "face": Vector3(1, 0, -0.3), "pose": "Crouch_Idle",
		"look": {"shirt": Color(0.18, 0.18, 0.2), "pants": Color(0.25, 0.28, 0.35), "shoes": Color(0.3, 0.3, 0.3), "hair": "Hair_Buzzed",
			"hair_color": Color(0.3, 0.25, 0.2), "height": 1.75, "skin": Color(0.9, 0.86, 0.8), "bulk": -0.8, "shoulders": -0.7, "shine": 0.1}},
	{"name": "Jonna", "kind": "narkkari", "at": Vector3(1.9, 0, 0.42), "face": Vector3(0, 0, 1), "pose": "Sitting_Idle",
		"look": {"model": "female", "shirt": Color(0.45, 0.12, 0.3), "pants": Color(0.1, 0.1, 0.12), "shoes": Color(0.2, 0.2, 0.2),
			"hair": "Hair_Long", "hair_color": Color(0.55, 0.45, 0.3), "height": 1.64, "skin": Color(0.92, 0.88, 0.84), "bulk": -0.7}},
]
const BEG := {
	"juoppo": ["Hei kaveri... ois sulla yks hörppy? Kurkku on ku Saharan hiekka.",
		"Anna nyt pikku tilkka, niin mä kerron sulle salaisuuden. Rahasta.",
		"Veli hei. Yks huikka vaan. Mä tiedän paikan, mistä löytyy satanen."],
	"narkkari": ["Psst. Mulla on tietoa. Tieto maksaa yhen huikan.",
		"Mä tiedän missä on kätkö. Ihan oikeesti. Anna hörppy, niin kerron.",
		"Tärisee vähän... Anna jotain juotavaa, niin mä kerron mihin Late piilotti rahat."],
}
const NO_DRINK := ["Ei sulla oo mitään. Tuu takas pullon kanssa.", "Tyhjin käsin? Ei tieto ilmaiseks tuu.",
	"Kalja, kossu, pontikka, mikä vaan käy. Sitten jutellaan."]
const THANKS := ["Kiitti, veli. Sä oot hyvä tyyppi.", "Aah. Nyt lähtee päivä käyntiin.", "Glug glug... Tää jää muistiin."]
const AMBIENT := ["Juna myöhässä taas. Niinku aina.", "Ennen tässä oli lipunmyynti ja kioski. Nyt on vaan me.",
	"Konnari heitti mut ulos viime viikolla. Ilman lippua kuulemma.", "Onks kellään tulta?",
	"Tää uuni lämmitti kunnolla vielä kasarilla.", "Älä istu siihen, siinä nukkuu Rane."]

signal exited(where: String)
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var town := "Saloinen"
var _enter_frame := -1
var _people: Array[Node3D] = []
var _bubbles := {}
var _sign: Label3D
var _board: Label3D
var _flicker: OmniLight3D
var _tube: MeshInstance3D
var _chat_t := 5.0
var _twitch_t := 2.0
var _t := 0.0


func _ready() -> void:
	_build_room()
	_build_furniture()
	_build_people()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF, HALF * 2.0)]
	add_child(walker)


## from: "ovi" (kadulta) tai "laituri" (laiturilta sisään).
func enter(town_name: String, from := "ovi") -> void:
	town = town_name
	_sign.text = town.to_upper()
	for who in _bubbles:  # edellisen käynnin (toisen aseman) puheet pois
		_bubbles[who].text = ""
		who.play(who.get_meta("pose"), 0.0)
	active = true
	busy = false
	_enter_frame = Engine.get_process_frames()
	var at: Vector3 = spots[from][0]
	walker.position = at + (Vector3(0, 0, -1.0) if from == "ovi" else Vector3(0, 0, 1.0))
	walker.rotation.y = B.yaw_to(Vector3(0, 0, -1) if from == "ovi" else Vector3(0, 0, 1))
	walker.activate()
	say(_people[1], "No terve! Tervetuloa %s asemalle. Palvelu pelaa." % ("Saloisten" if town == "Saloinen" else "Vaalan"))


func leave() -> void:
	active = false
	walker.controls_enabled = false


func set_board(text: String) -> void:
	_board.text = text


func person(i: int) -> Node3D:
	return _people[i]


func say(who: Node3D, text: String, t := 3.6) -> void:
	var b: Label3D = _bubbles[who]
	b.text = text
	b.set_meta("t", t)
	var pose: String = who.get_meta("pose")
	if pose == "Sitting_Idle":
		who.play("Sitting_Talking", 0.3)
	elif pose == "Idle":
		who.play("Idle_Talking", 0.3)


func beg(i: int) -> void:
	say(_people[i], BEG[PEOPLE[i].kind].pick_random(), 4.5)


func no_drink(i: int) -> void:
	say(_people[i], NO_DRINK.pick_random())


## Juoma annettu: where = kätkön paikka (ensimmäisellä kerralla), muuten pelkkä kiitos.
func thank(i: int, where: String) -> void:
	if where != "":
		say(_people[i], "Glug glug... Aah. Okei, kuuntele: %s. Siellä on satanen. Ota ennen ku muut löytää." % where, 7.0)
	else:
		say(_people[i], THANKS.pick_random())


func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


func _process(delta: float) -> void:
	_t += delta
	for who in _bubbles:
		var b: Label3D = _bubbles[who]
		if b.text == "":
			continue
		var left: float = b.get_meta("t") - delta
		b.set_meta("t", left)
		if left <= 0.0:
			b.text = ""
			who.play(who.get_meta("pose"), 0.3)
	# Loisteputki välkkyy satunnaisesti.
	var on := fmod(_t, 4.3) > 0.25 or sin(_t * 60.0) > 0.0
	_flicker.light_energy = 0.55 if on else 0.05
	_tube.visible = on
	# Narkkari Nisse nytkähtelee kyykyssä.
	_twitch_t -= delta
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(1.5, 4.0)
		var n: Node3D = _people[2]
		n.rotation.y = B.yaw_to(PEOPLE[2].face) + randf_range(-0.5, 0.5)
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(9.0, 16.0)
		say(_people.pick_random(), AMBIENT.pick_random())
	var p := walker.position
	var best := ""
	var bd := 1.4
	for id in spots:
		var d := Vector2(p.x - spots[id][0].x, p.z - spots[id][0].z).length()
		if d < bd:
			bd = d
			best = id
	for i in _people.size():
		var q: Vector3 = PEOPLE[i].at
		var d := Vector2(p.x - q.x, p.z - q.z).length()
		if d < minf(bd, 1.6):
			bd = d
			best = "hlo%d" % i
	spot = best
	hint = ""
	if best == "":
		return
	if best.begins_with("hlo"):
		var i := int(best.substr(3))
		hint = "[E] %s (%s) pyytää viinahörppyä" % [PEOPLE[i].name, PEOPLE[i].kind]
	else:
		hint = spots[best][1]
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	match best:
		"ovi", "laituri":
			exited.emit(best)
		"luukku":
			say(_people[0], "Ei siellä oo ketään ollu vuosiin. Liput ostetaan junasta konnarilta.")
		"taulu":
			acted.emit("taulu")
		_:
			acted.emit(best)


# --- Rakennus ---------------------------------------------------------------------

func _wall(a: Vector2, b: Vector2, h: float, col: Color, collide_h := WALL_H) -> void:
	var c := (a + b) / 2.0
	var size := Vector3(maxf(absf(b.x - a.x), 0.2), h, maxf(absf(b.y - a.y), 0.2))
	B.mesh(self, B.boxm(size), Vector3(c.x, h / 2.0, c.y), col)
	var body := StaticBody3D.new()
	body.position = Vector3(c.x, 0, c.y)
	body.add_child(B.box_shape(Vector3(size.x, collide_h, size.z), Vector3(0, collide_h / 2.0, 0)))
	add_child(body)


func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := B.mesh(self, B.boxm(size), pos, col)
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	add_child(body)
	return mi


func _build_room() -> void:
	B.mesh(self, B.boxm(Vector3(80, 0.2, 80)), Vector3(0, -0.2, 0), Color(0.06, 0.06, 0.07))
	# Ruutulattia vinoon ladottuna kahdella sävyllä.
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), FLOOR_A)
	for ix in int(HALF.x * 2.0 / 0.6):
		for iz in int(HALF.y * 2.0 / 0.6):
			if (ix + iz) % 2 == 0:
				B.mesh(self, B.boxm(Vector3(0.6, 0.01, 0.6)), Vector3(-HALF.x + 0.3 + ix * 0.6, 0.005, -HALF.y + 0.3 + iz * 0.6), FLOOR_B)
	# Seinät: alaosa ruskeaa paneelia, yläosa vaaleanvihreä; etuseinä matala (kamera).
	for w in [[Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, -HALF.y)], [Vector2(-HALF.x, -HALF.y), Vector2(-HALF.x, HALF.y)],
			[Vector2(HALF.x, -HALF.y), Vector2(HALF.x, HALF.y)]]:
		_wall(w[0], w[1], WALL_H, UPPER)
	_wall(Vector2(-HALF.x, HALF.y), Vector2(2.6, HALF.y), 0.7, PANEL)
	_wall(Vector2(4.6, HALF.y), Vector2(HALF.x, HALF.y), 0.7, PANEL)
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 1.2, 0.04)), Vector3(0, 0.6, -HALF.y + 0.12), PANEL)
	B.mesh(self, B.boxm(Vector3(0.04, 1.2, HALF.y * 2.0)), Vector3(-HALF.x + 0.12, 0.6, 0), PANEL)
	B.mesh(self, B.boxm(Vector3(0.04, 1.2, HALF.y * 2.0)), Vector3(HALF.x - 0.12, 0.6, 0), PANEL)
	for i in int(HALF.x * 2.0 / 0.3):
		B.mesh(self, B.boxm(Vector3(0.02, 1.2, 0.02)), Vector3(-HALF.x + 0.15 + i * 0.3, 0.6, -HALF.y + 0.15), PANEL.darkened(0.25))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.06, 0.06)), Vector3(0, 1.22, -HALF.y + 0.15), Color(0.3, 0.18, 0.1))
	# Laiturin puoli: pariovi lasiruutuineen ja ikkunat, joista näkyy laituri ja rata.
	var dx: float = spots.laituri[0].x
	B.mesh(self, B.boxm(Vector3(1.7, 2.6, 0.08)), Vector3(dx, 1.3, -HALF.y + 0.12), Color(0.95, 0.94, 0.9))
	for e: float in [-0.38, 0.38]:
		B.mesh(self, B.boxm(Vector3(0.7, 2.4, 0.06)), Vector3(dx + e, 1.2, -HALF.y + 0.15), Color(0.5, 0.28, 0.14))
		var g := B.mesh(self, B.boxm(Vector3(0.46, 1.1, 0.05)), Vector3(dx + e, 1.6, -HALF.y + 0.18), Color(0.6, 0.72, 0.8))
		g.material_override = B.unshaded(Color(0.62, 0.72, 0.78))
	B.label(self, "LAITURILLE  →", Vector3(dx, 2.85, -HALF.y + 0.2), 34, Color(1, 1, 1))
	for wx in [-5.0, 1.0, 5.0]:
		B.mesh(self, B.boxm(Vector3(1.3, 1.7, 0.06)), Vector3(wx, 2.0, -HALF.y + 0.12), Color(0.95, 0.94, 0.9))
		var gl := B.mesh(self, B.boxm(Vector3(1.1, 1.5, 0.07)), Vector3(wx, 2.0, -HALF.y + 0.13), Color(0.6, 0.7, 0.75))
		gl.material_override = B.unshaded(Color(0.66, 0.74, 0.76))
		B.mesh(self, B.boxm(Vector3(0.05, 1.5, 0.08)), Vector3(wx, 2.0, -HALF.y + 0.15), Color(0.95, 0.94, 0.9))
		B.mesh(self, B.boxm(Vector3(1.1, 0.05, 0.08)), Vector3(wx, 2.25, -HALF.y + 0.15), Color(0.95, 0.94, 0.9))
	# Katu-ovi etuseinässä.
	B.mesh(self, B.boxm(Vector3(2.0, 0.08, 0.15)), Vector3(spots.ovi[0].x, 0.04, HALF.y), Color(0.3, 0.3, 0.3))
	B.label(self, "ULOS", Vector3(spots.ovi[0].x, 0.9, HALF.y), 40, Color(0.3, 1.0, 0.4), true)
	# Nimikyltti takaseinällä ja seinäkello.
	_sign = B.label(self, "SALOINEN", Vector3(-5.0, 3.12, -HALF.y + 0.2), 44, Color(0.1, 0.18, 0.4))
	_sign.outline_modulate = Color(0.95, 0.95, 0.9)
	var clock := B.mesh(self, B.cyl(0.32, 0.32, 0.05, 20), Vector3(-3.3, 2.3, -HALF.y + 0.16), Color.WHITE, Vector3(90, 0, 0))
	clock.material_override = B.unshaded(Color(0.97, 0.97, 0.93))
	B.mesh(self, B.boxm(Vector3(0.03, 0.24, 0.02)), Vector3(-3.6, 2.5, -HALF.y + 0.2), Color(0.05, 0.05, 0.05))
	B.mesh(self, B.boxm(Vector3(0.18, 0.03, 0.02)), Vector3(-3.52, 2.4, -HALF.y + 0.2), Color(0.05, 0.05, 0.05))
	# Loisteputket: kylmä valo, yksi välkkyy.
	for i in 3:
		var lx := -4.5 + i * 4.5
		var tube := B.mesh(self, B.boxm(Vector3(1.4, 0.06, 0.12)), Vector3(lx, WALL_H - 0.1, 0), Color(0.95, 0.97, 1.0))
		tube.material_override = B.unshaded(Color(0.93, 0.97, 1.0))
		var light := OmniLight3D.new()
		light.position = Vector3(lx, WALL_H - 0.4, 0.5)
		light.omni_range = 7.0
		light.light_energy = 0.55
		light.light_color = Color(0.85, 0.95, 1.0)
		add_child(light)
		if i == 2:
			_flicker = light
			_tube = tube


func _build_furniture() -> void:
	var wood := Color(0.5, 0.32, 0.18)
	# Selkä selkää vasten olevat penkkirivit keskellä.
	for bx: float in [-1.6, 1.6]:
		for side: float in [-1.0, 1.0]:
			B.mesh(self, B.boxm(Vector3(2.6, 0.06, 0.45)), Vector3(bx, 0.45, side * 0.35), wood)
			B.mesh(self, B.boxm(Vector3(2.6, 0.5, 0.05)), Vector3(bx, 0.75, side * 0.1), wood)
		for e: float in [-1.2, 1.2]:
			B.mesh(self, B.boxm(Vector3(0.08, 0.45, 0.9)), Vector3(bx + e, 0.22, 0), Color(0.2, 0.2, 0.22))
		var body := StaticBody3D.new()
		body.position = Vector3(bx, 0, 0)
		body.add_child(B.box_shape(Vector3(2.6, 1.0, 0.9), Vector3(0, 0.5, 0)))
		add_child(body)
	# Penkki laiturin puoleisen seinän vieressä.
	B.mesh(self, B.boxm(Vector3(2.2, 0.06, 0.45)), Vector3(4.6, 0.45, -HALF.y + 0.5), wood)
	# Lippuluukku -X päädyssä: tiski, lasi, suljettu-kyltti.
	_solid(Vector3(0.7, 1.05, 2.4), Vector3(-HALF.x + 0.45, 0.52, -0.8), PANEL.darkened(0.1))
	var glass := B.mesh(self, B.boxm(Vector3(0.04, 1.0, 2.2)), Vector3(-HALF.x + 0.75, 1.6, -0.8), Color(0.5, 0.6, 0.65))
	glass.material_override = B.unshaded(Color(0.45, 0.55, 0.6, 0.5))
	var lbl := B.label(self, "LIPUNMYYNTI\nSULJETTU", Vector3(-HALF.x + 0.8, 2.4, -0.8), 30, Color(0.9, 0.15, 0.1))
	lbl.rotation.y = PI / 2.0
	var lbl2 := B.label(self, "Liput junasta konduktööriltä", Vector3(-HALF.x + 0.8, 1.35, -0.8), 18, Color(1, 1, 1))
	lbl2.rotation.y = PI / 2.0
	# Lähtevien junien taulu takaseinällä.
	var bx2: float = spots.taulu[0].x
	B.mesh(self, B.boxm(Vector3(2.0, 1.1, 0.06)), Vector3(bx2, 2.2, -HALF.y + 0.14), Color(0.05, 0.05, 0.1))
	var scr := B.mesh(self, B.boxm(Vector3(1.85, 0.95, 0.07)), Vector3(bx2, 2.2, -HALF.y + 0.15), Color(0.05, 0.08, 0.25))
	scr.material_override = B.unshaded(Color(0.04, 0.07, 0.22))
	_board = B.label(self, "LÄHTEVÄT JUNAT", Vector3(bx2, 2.2, -HALF.y + 0.2), 22, Color(1.0, 0.85, 0.2))
	_board.width = 360.0
	_board.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Kaakeliuuni +X takanurkassa: vihertävä pönttö, messinkiluukut.
	var stove := _solid(Vector3(1.0, 2.8, 1.0), Vector3(HALF.x - 0.7, 1.4, -HALF.y + 0.7), Color(0.82, 0.88, 0.8))
	stove.rotation.y = 0.0
	for k in 7:
		B.mesh(self, B.boxm(Vector3(1.02, 0.02, 1.02)), Vector3(HALF.x - 0.7, 0.4 + k * 0.36, -HALF.y + 0.7), Color(0.65, 0.72, 0.64))
	B.mesh(self, B.boxm(Vector3(0.35, 0.3, 0.04)), Vector3(HALF.x - 1.05, 0.9, -HALF.y + 1.21), Color(0.75, 0.6, 0.25), Vector3(0, -90, 0))
	B.mesh(self, B.boxm(Vector3(1.1, 0.12, 1.1)), Vector3(HALF.x - 0.7, 2.86, -HALF.y + 0.7), Color(0.75, 0.82, 0.74))
	# Kahviautomaatti ja roskis.
	var cm := _solid(Vector3(0.8, 1.8, 0.7), Vector3(HALF.x - 0.5, 0.9, 2.6), Color(0.55, 0.12, 0.1))
	cm.material_override = B.unshaded(Color(0.6, 0.15, 0.12))
	var cl := B.label(self, "KAHVI\nKAAKAO", Vector3(HALF.x - 0.89, 1.35, 2.6), 24, Color(1.0, 0.95, 0.8))
	cl.rotation.y = -PI / 2.0
	B.mesh(self, B.cyl(0.22, 0.2, 0.6, 12), Vector3(HALF.x - 0.4, 0.3, 1.6), Color(0.3, 0.32, 0.3))
	# VR:n juliste ja töhryjä.
	B.mesh(self, B.boxm(Vector3(0.04, 1.0, 0.7)), Vector3(HALF.x - 0.14, 2.0, 0.0), Color(0.0, 0.46, 0.26))
	var vr := B.label(self, "VR\nJunalla\nkotiin", Vector3(HALF.x - 0.17, 2.0, 0.0), 26, Color(1, 1, 1))
	vr.rotation.y = -PI / 2.0
	var tag := B.label(self, "LATE ♥ JONNA", Vector3(-HALF.x + 0.15, 1.6, 2.4), 26, Color(0.9, 0.2, 0.7))
	tag.rotation.y = PI / 2.0
	# Juoppojen pullot ja kassi lattialla.
	for q in [Vector3(-1.2, 0.12, 1.05), Vector3(-0.9, 0.12, 1.15), Vector3(4.6, 0.12, -1.8)]:
		B.mesh(self, B.cyl(0.04, 0.05, 0.25, 8), q, Color(0.25, 0.4, 0.2))
	B.mesh(self, B.boxm(Vector3(0.4, 0.3, 0.25)), Vector3(-2.4, 0.15, 1.05), Color(0.9, 0.9, 0.88))


func _build_people() -> void:
	for i in PEOPLE.size():
		var pd: Dictionary = PEOPLE[i]
		var c := Looks.make(self, pd.look)
		var lift := 0.02 if pd.pose == "Sitting_Idle" else 0.0
		c.position = pd.at + Vector3(0, lift, 0)
		c.rotation.y = B.yaw_to(pd.face)
		c.set_meta("pose", pd.pose)
		c.play(pd.pose, 0.0)
		if pd.kind == "juoppo":
			Looks.hunch(c, 0.25)
		var body := StaticBody3D.new()
		body.position = pd.at
		body.add_child(B.capsule_shape(0.3, 1.4))
		add_child(body)
		_bubbles[c] = B.bubble(c, Vector3(0, 1.85, 0), Color.WHITE, 0.7)
		_people.append(c)
