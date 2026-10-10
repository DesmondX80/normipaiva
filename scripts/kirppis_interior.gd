extends Node3D
## Saloisten seuraintalon kirpputori sisältä (#114): lankkulattia, vaalea paneliseinä, pöytärivit myyjineen ja
## perällä esiintymislava, jolla huutaja pitää huutokauppaa (auction_game.gd). Myyjät: mummo Hilkka (virkkuuliinat),
## Raili (rihkama: VHS-kasetit, posliinikoirat), Tauno (työkalut: ruuvipurkki ja rautalanka sähköpyörään) ja huutaja
## Erkki. Asiakkaana tinkii naapurin Anna-Liisa. Kauppa ja tinkiminen hoidetaan main.gd:n keskusteluikkunassa
## (acted("hloN") -> _talk_open). Takahuoneen ovi on lukossa.
## Kävely player_walker.gd:llä ylhäältä kuvattuna. Paikallinen +Z = pääovi (matala etuseinä, kamera), -Z = lava.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(9.0, 6.0)
const WALL_H := 3.8
const FLOOR := Color(0.62, 0.45, 0.28)
const PANEL := Color(0.86, 0.8, 0.66)
const TRIM := Color(0.45, 0.3, 0.18)
const CLOTH := Color(0.9, 0.88, 0.8)

var spot := ""
var spots := {
	"ovi": [Vector3(0.0, 0, 5.2), "[E] Ulos Seurantielle"],
	"takahuone": [Vector3(-8.0, 0, -4.4), "[E] Takahuoneen ovi (YKSITYINEN)"],
}
## Myyjät ja asiakkaat: id (main.gd TALKERS), nimi, rooli vihjeeseen, paikka, katse, asento ja ulkonäkö.
const PEOPLE := [
	{"id": "hilkka", "name": "Hilkka", "role": "myy virkkuuliinoja", "at": Vector3(-6.2, 0, -1.4), "face": Vector3(1, 0, 0.3),
		"pose": "Sitting_Idle", "look": {"model": "female", "shirt": Color(0.55, 0.3, 0.45), "pants": Color(0.25, 0.22, 0.3),
			"shoes": Color(0.3, 0.25, 0.2), "hair": "Hair_Buns", "hair_color": Color(0.85, 0.85, 0.85), "height": 1.58,
			"skin": Color(0.95, 0.8, 0.74), "belly": 0.4}},
	{"id": "raili", "name": "Raili", "role": "myy rihkamaa", "at": Vector3(0.0, 0, -0.9), "face": Vector3(0, 0, 1),
		"pose": "Sitting_Idle", "look": {"model": "female", "shirt": Color(0.2, 0.45, 0.4), "pants": Color(0.15, 0.15, 0.2),
			"shoes": Color(0.2, 0.2, 0.2), "hair": "Hair_Long", "hair_color": Color(0.6, 0.25, 0.15), "height": 1.65,
			"skin": Color(0.96, 0.78, 0.7), "belly": 0.3}},
	{"id": "tauno", "name": "Tauno", "role": "myy työkaluja", "at": Vector3(6.2, 0, -1.4), "face": Vector3(-1, 0, 0.3),
		"pose": "Sitting_Idle", "look": {"shirt": Color(0.3, 0.32, 0.25), "pants": Color(0.2, 0.22, 0.35), "shoes": Color(0.2, 0.15, 0.1),
			"hair": "Hair_Buzzed", "hair_color": Color(0.7, 0.7, 0.68), "beard": true, "height": 1.78, "skin": Color(0.95, 0.72, 0.64),
			"belly": 0.8}},
	{"id": "huutaja", "name": "Erkki", "role": "huutokaupan huutaja", "at": Vector3(0.0, 0.5, -4.7), "face": Vector3(0, 0, 1),
		"pose": "Idle", "look": {"shirt": Color(0.85, 0.85, 0.8), "pants": Color(0.15, 0.15, 0.18), "shoes": Color(0.1, 0.1, 0.1),
			"hair": "Hair_SimpleParted", "hair_color": Color(0.35, 0.3, 0.25), "height": 1.82, "skin": Color(0.96, 0.75, 0.66),
			"belly": 0.6}},
	{"id": "annaliisa", "name": "Anna-Liisa", "role": "naapuri, tinkii", "at": Vector3(1.8, 0, 1.4), "face": Vector3(-0.6, 0, -1),
		"pose": "Idle", "look": {"model": "female", "shirt": Color(0.75, 0.55, 0.6), "pants": Color(0.3, 0.3, 0.35),
			"shoes": Color(0.9, 0.9, 0.9), "hair": "Hair_Buns", "hair_color": Color(0.55, 0.45, 0.35), "height": 1.62,
			"skin": Color(0.95, 0.8, 0.74)}},
]
const AMBIENT := {
	"hilkka": ["Itte virkattu, joka silmukka.", "Näillä liinoilla on kaunis joulupöytä.", "Halvemmalla ei saa ku Prismasta, ja sielä on kiinalaista."],
	"raili": ["Uuno Turhapuro, kaikki osat! Melkein kaikki.", "Posliinikoira vahtii taloa, ku isäntä on Paapelissa.",
		"Joka kolmas VHS toimii. Joka toinen melkein."],
	"tauno": ["Ruuvit lajiteltu purkkiin. Melkein lajiteltu.", "Rautalangalla korjaa kaiken, mitä teippi ei korjaa.",
		"Tää jakoavain on ollu mun isän. Ei oo myytävänä. Paitsi kympillä."],
	"huutaja": ["Huutokauppa käy! Ensimmäinen kohde odottaa!", "Tänään erikoinen kohde, sähköinen jopa!",
		"Huutaja ei odota, huutaja huutaa!"],
	"annaliisa": ["Kaks euroa liinasta? Ryöstöä.", "Kyllä mää kerron Päiville, mitä sää täältä ostat.",
		"Mää tiän kaikki, mitä tällä kylällä myydään. Ja kenelle."],
}

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var lot_visible := true:  # huutokaupan napamoottori lavan pöydällä (main.gd piilottaa myynnin jälkeen)
	set(v):
		lot_visible = v
		if _lot != null:
			_lot.visible = v
var _enter_frame := -1
var _people: Array[Node3D] = []
var _bubbles := {}
var _lot: Node3D
var _chat_t := 4.0


func _ready() -> void:
	_build_room()
	_build_tables()
	_build_people()
	walker = Walker.new()
	walker.position = spots.ovi[0] + Vector3(0, 0, -1.0)
	walker.bounds = [Rect2(-HALF, HALF * 2.0)]
	add_child(walker)


func enter() -> void:
	for who in _bubbles:
		_bubbles[who].text = ""
		who.play(who.get_meta("pose"), 0.0)
	active = true
	busy = false
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(0, 0, -1.0)
	walker.rotation.y = B.yaw_to(Vector3(0, 0, -1))
	walker.activate()
	say_id("hilkka", "Tervetuloa kirppikselle! Kahvi ja pulla euron, liinat halvalla.")


func leave() -> void:
	active = false
	walker.controls_enabled = false


func person_index(id: String) -> int:
	for i in PEOPLE.size():
		if PEOPLE[i].id == id:
			return i
	return -1


func say_id(id: String, text: String, t := 3.6) -> void:
	var i := person_index(id)
	if i >= 0:
		say(_people[i], text, t)


func say(who: Node3D, text: String, t := 3.6) -> void:
	var b: Label3D = _bubbles[who]
	b.text = text
	b.set_meta("t", t)
	var pose: String = who.get_meta("pose")
	if pose == "Sitting_Idle":
		who.play("Sitting_Talking", 0.3)
	elif pose == "Idle":
		who.play("Idle_Talking", 0.3)


func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


func _process(delta: float) -> void:
	for who in _bubbles:
		var b: Label3D = _bubbles[who]
		if b.text == "":
			continue
		var left: float = b.get_meta("t") - delta
		b.set_meta("t", left)
		if left <= 0.0:
			b.text = ""
			who.play(who.get_meta("pose"), 0.3)
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(8.0, 14.0)
		var i := randi() % PEOPLE.size()
		say(_people[i], AMBIENT[PEOPLE[i].id].pick_random())
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
		# Myyjien eteen pöydän yli: pöydän leveys lasketaan mukaan.
		if d < minf(bd, 2.1 if PEOPLE[i].pose == "Sitting_Idle" else 1.7):
			bd = d
			best = "hlo%d" % i
	spot = best
	hint = ""
	if best == "":
		return
	if best.begins_with("hlo"):
		var i := int(best.substr(3))
		hint = "[E] %s (%s)" % [PEOPLE[i].name, PEOPLE[i].role]
	else:
		hint = spots[best][1]
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	match best:
		"ovi":
			exited.emit()
		"takahuone":
			say_id("raili", "Takahuone on Veksin varasto. Ei asiakkaille. Älä ees kysy.")
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
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), FLOOR)
	for i in int(HALF.x * 2.0 / 0.5):  # lankkujen raot
		B.mesh(self, B.boxm(Vector3(0.02, 0.01, HALF.y * 2.0)), Vector3(-HALF.x + i * 0.5, 0.005, 0), FLOOR.darkened(0.3))
	for w in [[Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, -HALF.y)], [Vector2(-HALF.x, -HALF.y), Vector2(-HALF.x, HALF.y)],
			[Vector2(HALF.x, -HALF.y), Vector2(HALF.x, HALF.y)]]:
		_wall(w[0], w[1], WALL_H, PANEL)
	_wall(Vector2(-HALF.x, HALF.y), Vector2(-1.2, HALF.y), 0.8, TRIM)
	_wall(Vector2(1.2, HALF.y), Vector2(HALF.x, HALF.y), 0.8, TRIM)
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 1.0, 0.04)), Vector3(0, 0.5, -HALF.y + 0.12), TRIM)
	# Lava perällä: koroke, punaiset verhot ja kyltti.
	_solid(Vector3(8.0, 0.5, 2.6), Vector3(0, 0.25, -HALF.y + 1.3), Color(0.5, 0.33, 0.2))
	for x in [-4.4, 4.4]:
		B.mesh(self, B.boxm(Vector3(1.0, WALL_H, 0.2)), Vector3(x, WALL_H / 2.0, -HALF.y + 0.2), Color(0.6, 0.08, 0.1))
	B.mesh(self, B.boxm(Vector3(9.8, 0.6, 0.2)), Vector3(0, WALL_H - 0.3, -HALF.y + 0.2), Color(0.6, 0.08, 0.1))
	var stage_sign := B.sign_plate(self, "HUUTOKAUPPA", Color(0.95, 0.78, 0.15), Color(0.45, 0.06, 0.05), 0.5, 72,
		Color(0.35, 0.2, 0.08), "Helvetica Neue")
	stage_sign.position = Vector3(0, 2.9, -HALF.y + 0.33)
	# Huutajan pöytä ja nuija, myytävä kohde (napamoottori) lavan pöydällä.
	_solid(Vector3(1.2, 0.9, 0.6), Vector3(-1.6, 0.95, -HALF.y + 1.6), Color(0.42, 0.28, 0.16))
	B.mesh(self, B.cyl(0.05, 0.05, 0.25, 8), Vector3(-1.5, 1.45, -HALF.y + 1.6), Color(0.35, 0.2, 0.1), Vector3(0, 0, 90))
	_solid(Vector3(1.2, 0.8, 0.8), Vector3(2.0, 0.9, -HALF.y + 1.6), CLOTH)
	_lot = Node3D.new()
	_lot.position = Vector3(2.0, 1.32, -HALF.y + 1.6)
	add_child(_lot)
	B.mesh(_lot, B.cyl(0.24, 0.24, 0.16, 18), Vector3.ZERO, Color(0.13, 0.13, 0.14), Vector3(0, 0, 90))
	B.mesh(_lot, B.cyl(0.06, 0.06, 0.3, 8), Vector3.ZERO, Color(0.7, 0.7, 0.72), Vector3(0, 0, 90))
	# Hintalappu tikun nokassa kohteen vieressä.
	B.mesh(_lot, B.cyl(0.01, 0.01, 0.4, 6), Vector3(0.35, 0.05, 0.25), Color(0.5, 0.35, 0.2))
	var tag := B.sign_plate(_lot, "NAPAMOOTTORI\nlähtö 5 €", Color(0.98, 0.97, 0.92), Color(0.1, 0.1, 0.1), 0.09, 22,
		Color(0.8, 0.15, 0.1))
	tag.position = Vector3(0.35, 0.32, 0.25)
	# Ovi, takahuone ja seinäjulisteet.
	B.mesh(self, B.boxm(Vector3(2.0, 0.08, 0.15)), Vector3(0, 0.04, HALF.y), Color(0.3, 0.3, 0.3))
	B.label(self, "ULOS", Vector3(0, 0.9, HALF.y), 40, Color(0.3, 1.0, 0.4), true)
	B.mesh(self, B.boxm(Vector3(0.08, 2.2, 1.1)), Vector3(-HALF.x + 0.08, 1.1, -4.4), Color(0.4, 0.26, 0.14))
	var priv := B.sign_plate(self, "YKSITYINEN", Color(0.97, 0.97, 0.95), Color(0.8, 0.08, 0.06), 0.16, 30,
		Color(0.8, 0.08, 0.06), "Helvetica Neue")
	priv.position = Vector3(-HALF.x + 0.14, 1.75, -4.4)
	priv.rotation.y = PI / 2.0
	# Ilmoitustaulu: korkkitaulu, jolla nuorisoseuran ilmoitukset nastoilla.
	var board := Node3D.new()
	board.position = Vector3(HALF.x - 0.12, 2.0, 1.5)
	board.rotation.y = -PI / 2.0
	add_child(board)
	B.mesh(board, B.boxm(Vector3(1.8, 1.2, 0.04)), Vector3.ZERO, Color(0.4, 0.26, 0.12))
	B.mesh(board, B.boxm(Vector3(1.68, 1.08, 0.05)), Vector3.ZERO, Color(0.72, 0.55, 0.36))
	var notes := [["Saloisten\nNuorisoseura\nTANSSIT\nla klo 21", Color(1.0, 0.95, 0.75), Vector3(-0.42, 0.05, 0.04)],
		["BINGO\nti klo 18", Color(0.85, 0.95, 1.0), Vector3(0.4, 0.18, 0.04)],
		["Myydään\nmopo,\nsoita Jani", Color(0.95, 0.85, 0.95), Vector3(0.42, -0.3, 0.04)]]
	for n in notes:
		var np := B.sign_plate(board, n[0], n[1], Color(0.12, 0.12, 0.2), 0.08, 18, Color(0.85, 0.85, 0.82))
		np.position = n[2]
		np.rotation.z = randf_range(-0.08, 0.08)
		B.mesh(np, B.sphere(0.02, 6), Vector3(0, np.get_meta("height") / 2.0 - 0.03, 0.03), Color(0.85, 0.1, 0.1))
	for i in 4:  # lamput
		var lx := -6.0 + i * 4.0
		B.mesh(self, B.cyl(0.25, 0.4, 0.25, 12), Vector3(lx, WALL_H - 0.3, 0), Color(0.95, 0.9, 0.7))
		var light := OmniLight3D.new()
		light.position = Vector3(lx, WALL_H - 0.6, 0.5)
		light.omni_range = 7.0
		light.light_energy = 0.6
		light.light_color = Color(1.0, 0.92, 0.78)
		add_child(light)


func _table(at: Vector3, size: Vector2) -> void:
	_solid(Vector3(size.x, 0.75, size.y), at + Vector3(0, 0.375, 0), CLOTH)


func _build_tables() -> void:
	# Hilkan liinapöytä: värikkäitä virkkuuliinoja pinoissa.
	_table(Vector3(-5.2, 0, -1.4), Vector2(1.0, 2.6))
	for i in 6:
		var col: Color = [Color(0.95, 0.95, 0.9), Color(0.9, 0.6, 0.7), Color(0.6, 0.75, 0.9)][i % 3]
		B.mesh(self, B.cyl(0.18, 0.18, 0.02, 12), Vector3(-5.2, 0.77 + (i / 3) * 0.02, -2.2 + (i % 3) * 0.8), col)
	# Railin rihkamapöytä: VHS-pinot ja posliinikoirat.
	_table(Vector3(0.0, 0, 0.0), Vector2(3.0, 1.0))
	for i in 5:
		B.mesh(self, B.boxm(Vector3(0.2, 0.04 * (i + 2), 0.11)), Vector3(-1.2 + i * 0.25, 0.75 + 0.02 * (i + 2), 0.1), Color(0.08, 0.08, 0.08))
	for x in [0.6, 1.1]:
		B.mesh(self, B.sphere(0.1, 10), Vector3(x, 0.88, 0.0), Color(0.97, 0.97, 0.95))
		B.mesh(self, B.sphere(0.06, 8), Vector3(x, 1.0, 0.05), Color(0.97, 0.97, 0.95))
	# Taunon työkalupöytä: ruuvipurkki, rautalankakelat, jakoavaimia.
	_table(Vector3(5.2, 0, -1.4), Vector2(1.0, 2.6))
	var jar := B.mesh(self, B.cyl(0.11, 0.11, 0.22, 12), Vector3(5.2, 0.86, -2.2), Color(0.75, 0.8, 0.85))
	jar.transparency = 0.3
	for z in [-1.5, -1.1]:
		B.mesh(self, B.cyl(0.12, 0.12, 0.06, 12), Vector3(5.2, 0.78, z), Color(0.55, 0.55, 0.58))
	for z in [-0.6, -0.4]:
		B.mesh(self, B.boxm(Vector3(0.08, 0.02, 0.3)), Vector3(5.2, 0.77, z), Color(0.65, 0.65, 0.7))
	# Kahvipöytä oven vieressä.
	_table(Vector3(-5.5, 0, 4.0), Vector2(1.6, 0.8))
	B.mesh(self, B.cyl(0.1, 0.12, 0.3, 10), Vector3(-5.8, 0.9, 4.0), Color(0.8, 0.1, 0.1))
	# Pöytäkyltti teltan muotoon taiteltuna.
	var tent := B.sign_plate(self, "KAHVI + PULLA 1 €", Color(0.98, 0.96, 0.9), Color(0.45, 0.12, 0.06), 0.1, 26,
		Color(0.45, 0.12, 0.06))
	tent.position = Vector3(-5.2, 0.9, 4.15)
	tent.rotation.x = -0.25


func _build_people() -> void:
	for i in PEOPLE.size():
		var pd: Dictionary = PEOPLE[i]
		var c := Looks.make(self, pd.look)
		var lift := 0.02 if pd.pose == "Sitting_Idle" else 0.0
		c.position = pd.at + Vector3(0, lift, 0)
		c.rotation.y = B.yaw_to(pd.face)
		c.set_meta("pose", pd.pose)
		c.play(pd.pose, 0.0)
		if pd.pose == "Sitting_Idle":  # jakkara alle
			B.mesh(self, B.cyl(0.2, 0.2, 0.45, 10), pd.at + Vector3(0, 0.22, 0) - Vector3(pd.face.x, 0, pd.face.z).normalized() * 0.05, TRIM)
		if pd.id in ["hilkka", "tauno"]:
			Looks.hunch(c, 0.2)
		var body := StaticBody3D.new()
		body.position = pd.at
		body.add_child(B.capsule_shape(0.3, 1.4))
		add_child(body)
		_bubbles[c] = B.bubble(c, Vector3(0, 1.85, 0), Color.WHITE, 0.7)
		_people.append(c)
