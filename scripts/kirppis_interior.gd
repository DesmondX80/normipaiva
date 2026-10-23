extends Node3D
## Saloisten seuraintalon sali sisältä kolmessa tilassa (main.gd _seura_mode):
## "kirppis" (#114, päivisin 10–18): pöytärivit myyjineen (Hilkka liinat, Raili rihkama, Tauno työkalut) ja lavalla
##   huutokauppa (huutaja Erkki, auction_game.gd); asiakkaana tinkii Anna-Liisa. Takahuoneen ovi on lukossa.
## "tanssit" (#129, lauantaisin 21–01): keskipöytä pois, lavalla Saloisten Saapasjalat, lattialla tanssivia pareja;
##   tanssiin voi hakea Sinikan, Hilkan tai Anna-Liisan (tanssi_game.gd), kahviossa Raili myy kahvia ja munkkia,
##   takaovesta pihalle ukkojen luo takakontille.
## "bingo" (#129, tiistaisin 18–20): mummot ja Tauno pöydän ääressä bingolappujen kanssa, Erkki lavalla pallokoneen
##   kanssa (bingo_game.gd).
## Kaupat, tanssit ja bingo hoidetaan main.gd:n keskusteluikkunassa (acted("hloN") -> _talk_open).
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
const MODES := ["kirppis", "tanssit", "bingo"]
const DANCE_C := Vector3(0, 0, 0.6)  # tanssilattian keskipiste

var spot := ""
## Toimintopisteet: paikka, vihje ja tilat, joissa piste on käytössä.
var spots := {
	"ovi": [Vector3(0.0, 0, 5.2), "[E] Ulos Seurantielle", MODES],
	"takahuone": [Vector3(-8.0, 0, -4.4), "[E] Takahuoneen ovi (YKSITYINEN)", ["kirppis"]],
	"takaovi": [Vector3(8.0, 0, -3.2), "[E] Takaovesta pihalle (ukot takakontilla)", ["tanssit"]],
	"poyta": [Vector3(-3.4, 0, 2.7), "[E] Oma kirppispöytä (paikka 2 €/päivä, Hilkka)", ["kirppis"]],
}
const MUMMO := {"model": "female", "shirt": Color(0.45, 0.4, 0.6), "pants": Color(0.25, 0.22, 0.3), "shoes": Color(0.3, 0.25, 0.2),
	"hair": "Hair_Buns", "hair_color": Color(0.9, 0.9, 0.9), "height": 1.56, "skin": Color(0.95, 0.8, 0.74), "belly": 0.5}
## Ihmiset: id (main.gd TALKERS; "" = pelkkä tausta), nimi, rooli vihjeeseen, tilat, paikka, katse, asento ja ulkonäkö
## (look tai look_ref = looks.gd-vakion nimi). Sama henkilö voi olla eri tiloissa eri paikassa omana rivinään.
const PEOPLE := [
	{"id": "hilkka", "name": "Hilkka", "role": "myy virkkuuliinoja", "modes": ["kirppis"], "at": Vector3(-6.2, 0, -1.4),
		"face": Vector3(1, 0, 0.3), "pose": "Sitting_Idle", "look": {"model": "female", "shirt": Color(0.55, 0.3, 0.45),
			"pants": Color(0.25, 0.22, 0.3), "shoes": Color(0.3, 0.25, 0.2), "hair": "Hair_Buns", "hair_color": Color(0.85, 0.85, 0.85),
			"height": 1.58, "skin": Color(0.95, 0.8, 0.74), "belly": 0.4}},
	{"id": "raili", "name": "Raili", "role": "myy rihkamaa", "modes": ["kirppis"], "at": Vector3(0.0, 0, -0.9),
		"face": Vector3(0, 0, 1), "pose": "Sitting_Idle", "look": {"model": "female", "shirt": Color(0.2, 0.45, 0.4),
			"pants": Color(0.15, 0.15, 0.2), "shoes": Color(0.2, 0.2, 0.2), "hair": "Hair_Long", "hair_color": Color(0.6, 0.25, 0.15),
			"height": 1.65, "skin": Color(0.96, 0.78, 0.7), "belly": 0.3}},
	{"id": "tauno", "name": "Tauno", "role": "myy työkaluja", "modes": ["kirppis"], "at": Vector3(6.2, 0, -1.4),
		"face": Vector3(-1, 0, 0.3), "pose": "Sitting_Idle", "look": {"shirt": Color(0.3, 0.32, 0.25), "pants": Color(0.2, 0.22, 0.35),
			"shoes": Color(0.2, 0.15, 0.1), "hair": "Hair_Buzzed", "hair_color": Color(0.7, 0.7, 0.68), "beard": true, "height": 1.78,
			"skin": Color(0.95, 0.72, 0.64), "belly": 0.8}},
	{"id": "huutaja", "name": "Erkki", "role": "huutaja", "modes": ["kirppis", "bingo"], "at": Vector3(0.0, 0.5, -4.7), "reach": 2.4,
		"face": Vector3(0, 0, 1), "pose": "Idle", "look": {"shirt": Color(0.85, 0.85, 0.8), "pants": Color(0.15, 0.15, 0.18),
			"shoes": Color(0.1, 0.1, 0.1), "hair": "Hair_SimpleParted", "hair_color": Color(0.35, 0.3, 0.25), "height": 1.82,
			"skin": Color(0.96, 0.75, 0.66), "belly": 0.6}},
	{"id": "annaliisa", "name": "Anna-Liisa", "role": "naapuri", "modes": ["kirppis", "tanssit"], "at": Vector3(1.8, 0, 1.4),
		"face": Vector3(-0.6, 0, -1), "pose": "Idle", "look": {"model": "female", "shirt": Color(0.75, 0.55, 0.6),
			"pants": Color(0.3, 0.3, 0.35), "shoes": Color(0.9, 0.9, 0.9), "hair": "Hair_Buns", "hair_color": Color(0.55, 0.45, 0.35),
			"height": 1.62, "skin": Color(0.95, 0.8, 0.74)}},
	# Tanssit: tanssiin haettavat, kahvio ja bändi.
	{"id": "sinikka_seura", "name": "Sinikka", "role": "tanssiin?", "modes": ["tanssit"], "at": Vector3(-4.0, 0, 2.6),
		"face": Vector3(0.5, 0, -1), "pose": "Idle", "look_ref": "SINIKKA"},
	{"id": "hilkka", "name": "Hilkka", "role": "tanssiin?", "modes": ["tanssit"], "at": Vector3(4.6, 0, 2.4),
		"face": Vector3(-0.5, 0, -1), "pose": "Idle", "look": {"model": "female", "shirt": Color(0.55, 0.3, 0.45),
			"pants": Color(0.25, 0.22, 0.3), "shoes": Color(0.3, 0.25, 0.2), "hair": "Hair_Buns", "hair_color": Color(0.85, 0.85, 0.85),
			"height": 1.58, "skin": Color(0.95, 0.8, 0.74), "belly": 0.4}},
	{"id": "raili", "name": "Raili", "role": "kahvio", "modes": ["tanssit", "bingo"], "at": Vector3(-5.5, 0, 3.3),
		"face": Vector3(0, 0, 1), "pose": "Idle", "look": {"model": "female", "shirt": Color(0.2, 0.45, 0.4),
			"pants": Color(0.15, 0.15, 0.2), "shoes": Color(0.2, 0.2, 0.2), "hair": "Hair_Long", "hair_color": Color(0.6, 0.25, 0.15),
			"height": 1.65, "skin": Color(0.96, 0.78, 0.7), "belly": 0.3}},
	{"id": "", "name": "Haitarinsoittaja", "role": "", "modes": ["tanssit"], "at": Vector3(-1.8, 0.5, -4.6), "face": Vector3(0.2, 0, 1),
		"pose": "Idle", "instrument": "haitari", "look": {"shirt": Color(0.75, 0.1, 0.1), "pants": Color(0.1, 0.1, 0.12),
			"shoes": Color(0.1, 0.1, 0.1), "hair": "Hair_SimpleParted", "hair_color": Color(0.25, 0.2, 0.15), "height": 1.76}},
	{"id": "", "name": "Kitaristi", "role": "", "modes": ["tanssit"], "at": Vector3(0.0, 0.5, -4.9), "face": Vector3(0, 0, 1),
		"pose": "Idle", "instrument": "kitara", "look": {"shirt": Color(0.75, 0.1, 0.1), "pants": Color(0.1, 0.1, 0.12),
			"shoes": Color(0.1, 0.1, 0.1), "hair": "Hair_Long", "hair_color": Color(0.5, 0.35, 0.2), "height": 1.8}},
	{"id": "", "name": "Rumpali", "role": "", "modes": ["tanssit"], "at": Vector3(1.9, 0.5, -4.9), "face": Vector3(-0.2, 0, 1),
		"pose": "Sitting_Idle", "instrument": "rummut", "look": {"shirt": Color(0.75, 0.1, 0.1), "pants": Color(0.1, 0.1, 0.12),
			"shoes": Color(0.1, 0.1, 0.1), "hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.25, 0.2), "height": 1.74, "belly": 0.7}},
	# Bingo: pelaajat lappujen ääressä keskipöydässä, katse lavalle.
	{"id": "hilkka", "name": "Hilkka", "role": "bingossa", "modes": ["bingo"], "at": Vector3(-1.0, 0, 0.9),
		"face": Vector3(0, 0, -1), "pose": "Sitting_Idle", "look": {"model": "female", "shirt": Color(0.55, 0.3, 0.45),
			"pants": Color(0.25, 0.22, 0.3), "shoes": Color(0.3, 0.25, 0.2), "hair": "Hair_Buns", "hair_color": Color(0.85, 0.85, 0.85),
			"height": 1.58, "skin": Color(0.95, 0.8, 0.74), "belly": 0.4}},
	{"id": "", "name": "Mummo Elvi", "role": "", "modes": ["bingo"], "at": Vector3(0.0, 0, 0.9), "face": Vector3(0, 0, -1),
		"pose": "Sitting_Idle", "look": MUMMO},
	{"id": "tauno", "name": "Tauno", "role": "bingossa", "modes": ["bingo"], "at": Vector3(1.0, 0, 0.9),
		"face": Vector3(0, 0, -1), "pose": "Sitting_Idle", "look": {"shirt": Color(0.3, 0.32, 0.25), "pants": Color(0.2, 0.22, 0.35),
			"shoes": Color(0.2, 0.15, 0.1), "hair": "Hair_Buzzed", "hair_color": Color(0.7, 0.7, 0.68), "beard": true, "height": 1.78,
			"skin": Color(0.95, 0.72, 0.64), "belly": 0.8}},
	{"id": "", "name": "Mummo Aili", "role": "", "modes": ["bingo"], "at": Vector3(-1.0, 0, -0.9), "face": Vector3(0, 0, -1),
		"pose": "Sitting_Idle", "look": MUMMO},
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
## Tilakohtaiset taustapuheet: id -> repliikit (ohittaa AMBIENTin).
const AMBIENT_MODE := {
	"tanssit": {
		"sinikka_seura": ["Ei kukaan hae... Missä ne kunnon miehet on?", "Tää biisi on niin ihana!", "Saapasjalat soittaa ku ennen vanhaan."],
		"hilkka": ["Mää tanssin jo viiskytluvulla tällä samalla lattialla.", "Valssi, nuori mies. Osaatko valssin?"],
		"raili": ["Kahvia ja munkkia! Kaljaa ei, tää on nuorisoseuran talo.", "Munkit on vielä lämpimiä!"],
		"annaliisa": ["Kas, Järvikujan mies tansseissa. Tietääkö Päivi?", "Mää nään kaikki, ketkä tanssii kenenkin kanssa."],
	},
	"bingo": {
		"huutaja": ["Bingo alkaa! Laput esiin!", "Tänään jättipotti: kinkku!", "Kynät valmiina, mummot!"],
		"hilkka": ["Mulla on onnenkynä, tällä voitin -98.", "Tauno, älä kurki mun lappua."],
		"tauno": ["Tänään se kinkku tulee mulle.", "Joka viikko sama numero puuttuu."],
		"raili": ["Kahvia bingoon? Euro kuppi.", "Munkki tuo onnea, sanotaan."],
	},
}

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var mode := "kirppis"
var veksi_open := false  # Veksi ottaa vastaan takahuoneessa (Kertunkankaan kirves mukana, main.gd)
var auction_done := false  # tämän päivän huutokauppa pidetty (main.gd): Erkki ei enää huuda kauppaa
var lot_visible := true:  # huutokaupan napamoottori lavan pöydällä (main.gd piilottaa myynnin jälkeen)
	set(v):
		lot_visible = v
		_apply_mode()
var _enter_frame := -1
var _people: Array[Node3D] = []  # hahmot PEOPLE-järjestyksessä
var _holders: Array[Node3D] = []  # hahmo, jakkara, soitin ja törmäys yhdessä (näkyvyys tilan mukaan)
var _bubbles := {}
var _groups := {}  # tila -> Node3D (tilan omat kalusteet ja kyltit)
var _no_dance: Node3D  # keskipöytä: pois tansseista
var _lot: Node3D
var _dancers: Array[Node3D] = []
var drakkar: Node3D  # Drakkar Noir Railin pöydällä (main.gd piilottaa ostettuna)
var haalari: Node3D  # neonpinkki hiihtohaalari Railin vaatetangossa (main.gd piilottaa ostettuna)
var _chat_t := 4.0
var _t := 0.0


func _ready() -> void:
	for m in MODES:
		var g := Node3D.new()
		add_child(g)
		_groups[m] = g
	_no_dance = Node3D.new()
	add_child(_no_dance)
	_build_room()
	_build_tables()
	_build_people()
	_build_dancers()
	walker = Walker.new()
	walker.position = spots.ovi[0] + Vector3(0, 0, -1.0)
	walker.bounds = [Rect2(-HALF, HALF * 2.0)]
	add_child(walker)
	_apply_mode()


func enter(m := "kirppis") -> void:
	mode = m
	_apply_mode()
	for who in _bubbles:
		_bubbles[who].text = ""
		who.play(who.get_meta("pose"), 0.0)
	active = true
	busy = false
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(0, 0, -1.0)
	walker.rotation.y = B.yaw_to(Vector3(0, 0, -1))
	walker.activate()
	match mode:
		"tanssit":
			say_id("raili", "Tervetuloa tansseihin! Kahvio on tässä, kaljat jätetään pihalle.")
		"bingo":
			say_id("huutaja", "Bingo alkaa pian! Lappu kaks euroa, tule hakemaan.")
		_:
			say_id("hilkka", "Tervetuloa kirppikselle! Kahvi ja munkki kaks euroa, liinat halvalla.")


func leave() -> void:
	active = false
	walker.controls_enabled = false


func _shown(i: int) -> bool:
	return mode in PEOPLE[i].modes


## Ensimmäinen tässä tilassa näkyvä henkilö, jolla on annettu id.
func person_index(id: String) -> int:
	for i in PEOPLE.size():
		if PEOPLE[i].id == id and _shown(i):
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


## Näkyvyys ja törmäykset tilan mukaan.
func _apply_mode() -> void:
	if _holders.is_empty():
		return
	for i in _holders.size():
		_set_on(_holders[i], _shown(i))
	for m in _groups:
		_set_on(_groups[m], m == mode)
	_set_on(_no_dance, mode != "tanssit")
	if _lot != null:
		_lot.visible = mode == "kirppis" and lot_visible
	for d in _dancers:
		d.visible = mode == "tanssit"


static func _set_on(n: Node3D, on: bool) -> void:
	n.visible = on
	for cs in n.find_children("*", "CollisionShape3D", true, false):
		(cs as CollisionShape3D).disabled = not on


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
	if mode == "tanssit":  # parit kiertävät tanssilattiaa
		for k in _dancers.size():
			var a := _t * 0.35 + k * TAU / _dancers.size()
			var d := _dancers[k]
			d.position = DANCE_C + Vector3(cos(a) * 2.4, 0, sin(a) * 1.5)
			d.rotation.y = -a + _t * 1.8
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(8.0, 14.0)
		var talkers: Array = []
		for i in PEOPLE.size():
			if _shown(i) and PEOPLE[i].id != "":
				talkers.append(i)
		if not talkers.is_empty():
			var i: int = talkers.pick_random()
			var pool: Dictionary = AMBIENT_MODE.get(mode, {})
			var lines: Array = pool.get(PEOPLE[i].id, AMBIENT.get(PEOPLE[i].id, []))
			if not lot_visible:  # napamoottori myyty: Erkki ei enää mainosta sähköistä kohdetta
				lines = lines.filter(func(l): return not "sähköinen" in l)
			if auction_done and PEOPLE[i].id == "huutaja":
				lines = lines.filter(func(l): return not "Huutokauppa" in l and not "kohde" in l)
			if not lines.is_empty():
				say(_people[i], lines.pick_random())
	var p := walker.position
	var best := ""
	var bd := INF  # lähin voittaa; jokaisella oma ulottuvuus (toimintopiste 1,4 m, henkilöt alla)
	for id in spots:
		if not (mode in spots[id][2]):
			continue
		var d := Vector2(p.x - spots[id][0].x, p.z - spots[id][0].z).length()
		if d < 1.4 and d < bd:
			bd = d
			best = id
	for i in _people.size():
		if not _shown(i) or PEOPLE[i].id == "":
			continue
		var q: Vector3 = PEOPLE[i].at
		var d := Vector2(p.x - q.x, p.z - q.z).length()
		# Myyjien eteen pöydän yli: pöydän leveys lasketaan mukaan.
		# Erkki lavalla: lavan reuna lasketaan mukaan, myös kulmasta vinottain.
		if d < bd and d < PEOPLE[i].get("reach", 2.1 if PEOPLE[i].pose == "Sitting_Idle" else 1.7):
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
			if veksi_open:
				acted.emit("takahuone")
			else:
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


func _solid(size: Vector3, pos: Vector3, col: Color, parent: Node3D = null) -> MeshInstance3D:
	var par: Node3D = self if parent == null else parent
	var mi := B.mesh(par, B.boxm(size), pos, col)
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	par.add_child(body)
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
	# Lava perällä: koroke, punaiset verhot ja tilan mukainen kyltti.
	_solid(Vector3(8.0, 0.5, 2.6), Vector3(0, 0.25, -HALF.y + 1.3), Color(0.5, 0.33, 0.2))
	for x in [-4.4, 4.4]:
		B.mesh(self, B.boxm(Vector3(1.0, WALL_H, 0.2)), Vector3(x, WALL_H / 2.0, -HALF.y + 0.2), Color(0.6, 0.08, 0.1))
	B.mesh(self, B.boxm(Vector3(9.8, 0.6, 0.2)), Vector3(0, WALL_H - 0.3, -HALF.y + 0.2), Color(0.6, 0.08, 0.1))
	var stage_signs := {"kirppis": ["HUUTOKAUPPA", Color(0.95, 0.78, 0.15), Color(0.45, 0.06, 0.05)],
		"tanssit": ["SALOISTEN SAAPASJALAT", Color(0.1, 0.1, 0.35), Color(1.0, 0.85, 0.3)],
		"bingo": ["BINGO", Color(0.15, 0.5, 0.25), Color(1.0, 1.0, 0.9)]}
	for m in stage_signs:
		var sd: Array = stage_signs[m]
		var ss := B.sign_plate(_groups[m], sd[0], sd[1], sd[2], 0.5, 64, Color(0.35, 0.2, 0.08), "Helvetica Neue")
		ss.position = Vector3(0, 2.9, -HALF.y + 0.33)
	# Kirppis: huutajan pöytä ja nuija, myytävä kohde (napamoottori) lavan pöydällä.
	var kg: Node3D = _groups.kirppis
	_solid(Vector3(1.2, 0.9, 0.6), Vector3(-1.6, 0.95, -HALF.y + 1.6), Color(0.42, 0.28, 0.16), kg)
	B.mesh(kg, B.cyl(0.05, 0.05, 0.25, 8), Vector3(-1.5, 1.45, -HALF.y + 1.6), Color(0.35, 0.2, 0.1), Vector3(0, 0, 90))
	_solid(Vector3(1.2, 0.8, 0.8), Vector3(2.0, 0.9, -HALF.y + 1.6), CLOTH, kg)
	_lot = Node3D.new()
	_lot.position = Vector3(2.0, 1.32, -HALF.y + 1.6)
	add_child(_lot)
	B.mesh(_lot, B.cyl(0.24, 0.24, 0.16, 18), Vector3.ZERO, Color(0.13, 0.13, 0.14), Vector3(0, 0, 90))
	B.mesh(_lot, B.cyl(0.06, 0.06, 0.3, 8), Vector3.ZERO, Color(0.7, 0.7, 0.72), Vector3(0, 0, 90))
	B.mesh(_lot, B.cyl(0.01, 0.01, 0.4, 6), Vector3(0.35, 0.05, 0.25), Color(0.5, 0.35, 0.2))
	var tag := B.sign_plate(_lot, "NAPAMOOTTORI\nlähtö 5 €", Color(0.98, 0.97, 0.92), Color(0.1, 0.1, 0.1), 0.09, 22,
		Color(0.8, 0.15, 0.1))
	tag.position = Vector3(0.35, 0.32, 0.25)
	# Bingo: pallokone lavalla ja numerotaulu seinällä.
	var bg: Node3D = _groups.bingo
	_solid(Vector3(1.0, 0.9, 0.6), Vector3(-1.5, 0.95, -HALF.y + 1.6), Color(0.42, 0.28, 0.16), bg)
	var drum := B.mesh(bg, B.sphere(0.32, 14), Vector3(-1.5, 1.75, -HALF.y + 1.6), Color(0.7, 0.85, 0.95))
	drum.transparency = 0.4
	for k in 6:
		B.mesh(bg, B.sphere(0.06, 8), Vector3(-1.6 + (k % 3) * 0.1, 1.62 + (k / 3) * 0.1, -HALF.y + 1.6), [Color.RED, Color.YELLOW, Color.WHITE][k % 3])
	var nb := B.sign_plate(bg, "B  I  N  G  O\n1–75", Color(0.08, 0.1, 0.08), Color(1.0, 0.85, 0.3), 0.3, 40, Color(0.55, 0.4, 0.2))
	nb.position = Vector3(3.0, 2.0, -HALF.y + 0.33)
	# Tanssit: rumpusetti, valosarja ja viirit.
	var tg: Node3D = _groups.tanssit
	B.mesh(tg, B.cyl(0.32, 0.32, 0.4, 14), Vector3(1.9, 0.75, -HALF.y + 0.55), Color(0.85, 0.85, 0.9), Vector3(90, 0, 0))
	for x in [1.4, 2.4]:
		B.mesh(tg, B.cyl(0.18, 0.18, 0.12, 12), Vector3(x, 1.2, -HALF.y + 1.0), Color(0.75, 0.65, 0.2))
	for k in 18:  # viirinauha salin yli
		var x := -8.0 + k * 0.95
		var flag := B.mesh(tg, PrismMesh.new(), Vector3(x, 3.2 - absf(sin(k * 0.35)) * 0.3, 1.0), [Color.RED, Color.YELLOW, Color(0.2, 0.5, 1.0), Color.WHITE][k % 4])
		flag.scale = Vector3(0.35, -0.35, 0.02)
	for k in 6:
		var light := OmniLight3D.new()
		light.position = Vector3(-6.0 + k * 2.4, 2.8, 0.5)
		light.omni_range = 4.0
		light.light_energy = 0.5
		light.light_color = [Color(1, 0.3, 0.3), Color(0.3, 0.5, 1), Color(1, 0.85, 0.3)][k % 3]
		tg.add_child(light)
	# Ovi, takahuone, takaovi ja ilmoitustaulu.
	B.mesh(self, B.boxm(Vector3(2.0, 0.08, 0.15)), Vector3(0, 0.04, HALF.y), Color(0.3, 0.3, 0.3))
	B.label(self, "ULOS", Vector3(0, 0.9, HALF.y), 40, Color(0.3, 1.0, 0.4), true)
	B.mesh(self, B.boxm(Vector3(0.08, 2.2, 1.1)), Vector3(-HALF.x + 0.08, 1.1, -4.4), Color(0.4, 0.26, 0.14))
	var priv := B.sign_plate(self, "YKSITYINEN", Color(0.97, 0.97, 0.95), Color(0.8, 0.08, 0.06), 0.16, 30,
		Color(0.8, 0.08, 0.06), "Helvetica Neue")
	priv.position = Vector3(-HALF.x + 0.14, 1.75, -4.4)
	priv.rotation.y = PI / 2.0
	B.mesh(self, B.boxm(Vector3(0.08, 2.2, 1.1)), Vector3(HALF.x - 0.08, 1.1, -3.2), Color(0.4, 0.26, 0.14))
	var back := B.sign_plate(self, "PIHA", Color(0.15, 0.45, 0.2), Color.WHITE, 0.16, 30, Color.WHITE, "Helvetica Neue")
	back.position = Vector3(HALF.x - 0.14, 2.45, -3.2)
	back.rotation.y = -PI / 2.0
	var board := Node3D.new()
	board.position = Vector3(HALF.x - 0.12, 2.0, 1.5)
	board.rotation.y = -PI / 2.0
	add_child(board)
	B.mesh(board, B.boxm(Vector3(1.8, 1.2, 0.04)), Vector3.ZERO, Color(0.4, 0.26, 0.12))
	B.mesh(board, B.boxm(Vector3(1.68, 1.08, 0.05)), Vector3.ZERO, Color(0.72, 0.55, 0.36))
	var notes := [["Saloisten\nNuorisoseura\nTANSSIT\nla klo 21–01", Color(1.0, 0.95, 0.75), Vector3(-0.42, 0.05, 0.04)],
		["BINGO\nti klo 18–20", Color(0.85, 0.95, 1.0), Vector3(0.4, 0.18, 0.04)],
		["Myydään\nmopo,\nsoita Jani", Color(0.95, 0.85, 0.95), Vector3(0.42, -0.3, 0.04)]]
	for n in notes:
		var np := B.sign_plate(board, n[0], n[1], Color(0.12, 0.12, 0.2), 0.08, 18, Color(0.85, 0.85, 0.82))
		np.position = n[2]
		np.rotation.z = randf_range(-0.08, 0.08)
		B.mesh(np, B.sphere(0.02, 6), Vector3(0, np.get_meta("height") / 2.0 - 0.03, 0.03), Color(0.85, 0.1, 0.1))
	_build_ceiling()
	for i in 4:  # lamput
		var lx := -6.0 + i * 4.0
		B.mesh(self, B.cyl(0.25, 0.4, 0.25, 12), Vector3(lx, WALL_H - 0.3, 0), Color(0.95, 0.9, 0.7))
		B.mesh(self, B.cyl(0.012, 0.012, 0.2, 6), Vector3(lx, WALL_H - 0.08, 0), Color(0.15, 0.15, 0.15))  # johto kattoon
		var light := OmniLight3D.new()
		light.position = Vector3(lx, WALL_H - 0.6, 0.5)
		light.omni_range = 7.0
		light.light_energy = 0.6
		light.light_color = Color(1.0, 0.92, 0.78)
		add_child(light)


## Paneelikatto ja kattopalkkien alapinnat. Pinnat katsovat alas: salin sisältä (huutokaupan ja bingon kamera) näkyy katto
## eikä taivas, mutta ylhäältä kuvaava kävelykamera näkee katon läpi. Katto ei heitä varjoa, joten valaistus pysyy.
func _build_ceiling() -> void:
	var down := func(size: Vector2, pos: Vector3, col: Color) -> void:
		var pm := PlaneMesh.new()
		pm.size = size
		pm.flip_faces = true  # normaali alas: näkyy vain alapuolelta
		var mi := B.mesh(self, pm, pos, col)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	down.call(Vector2(HALF.x * 2.0, HALF.y * 2.0), Vector3(0, WALL_H, 0), PANEL.lightened(0.15))
	for i in 7:  # kattopalkkien alapinnat poikittain (kyljet näkyisivät ylhäältä viivoina salin yli)
		down.call(Vector2(HALF.x * 2.0, 0.16), Vector3(0, WALL_H - 0.01, -HALF.y + 1.5 + i * 1.5), TRIM)


func _table(at: Vector3, size: Vector2, parent: Node3D = null) -> void:
	_solid(Vector3(size.x, 0.75, size.y), at + Vector3(0, 0.375, 0), CLOTH, parent)


func _build_tables() -> void:
	var kg: Node3D = _groups.kirppis
	# Hilkan liinapöytä ja Taunon työkalupöytä sivuilla (kaikissa tiloissa; tavarat vain kirppiksellä).
	_table(Vector3(-5.2, 0, -1.4), Vector2(1.0, 2.6))
	for i in 6:
		var col: Color = [Color(0.95, 0.95, 0.9), Color(0.9, 0.6, 0.7), Color(0.6, 0.75, 0.9)][i % 3]
		B.mesh(kg, B.cyl(0.18, 0.18, 0.02, 12), Vector3(-5.2, 0.77 + (i / 3) * 0.02, -2.2 + (i % 3) * 0.8), col)
	_table(Vector3(5.2, 0, -1.4), Vector2(1.0, 2.6))
	var jar := B.mesh(kg, B.cyl(0.11, 0.11, 0.22, 12), Vector3(5.2, 0.86, -2.2), Color(0.75, 0.8, 0.85))
	jar.transparency = 0.3
	for z in [-1.5, -1.1]:
		B.mesh(kg, B.cyl(0.12, 0.12, 0.06, 12), Vector3(5.2, 0.78, z), Color(0.55, 0.55, 0.58))
	for z in [-0.6, -0.4]:
		B.mesh(kg, B.boxm(Vector3(0.08, 0.02, 0.3)), Vector3(5.2, 0.77, z), Color(0.65, 0.65, 0.7))
	# Oma pöytäpaikka (#128): vuokrattava pöytä, johon pelaaja asettuu myymään omia tavaroitaan.
	_table(Vector3(-3.4, 0, 2.2), Vector2(1.8, 0.8), kg)
	var cloth := B.mesh(kg, B.boxm(Vector3(1.84, 0.02, 0.84)), Vector3(-3.4, 0.76, 2.2), Color(0.85, 0.2, 0.2))
	cloth.rotation.y = 0.0
	for k in 3:
		B.mesh(kg, B.boxm(Vector3(0.5, 0.025, 0.84)), Vector3(-4.0 + k * 0.6, 0.77, 2.2), Color(0.97, 0.95, 0.9))
	var own := B.sign_plate(kg, "OMA PÖYTÄ\nvuokra 2 € / päivä", Color(0.15, 0.4, 0.3), Color(1, 0.97, 0.85), 0.2, 34, Color.WHITE)
	own.position = Vector3(-3.4, 0.9, 2.55)
	# Keskipöytä: kirppiksellä Railin rihkama, bingossa laput; tansseissa pois tanssilattian tieltä.
	_table(Vector3(0.0, 0, 0.0), Vector2(3.0, 1.0), _no_dance)
	for i in 5:
		B.mesh(kg, B.boxm(Vector3(0.2, 0.04 * (i + 2), 0.11)), Vector3(-1.2 + i * 0.25, 0.75 + 0.02 * (i + 2), 0.1), Color(0.08, 0.08, 0.08))
	# Drakkar Noir: musta kulmikas pullo, hopeinen kaula ja suihkupää, hopeinen etiketti ja hintalappu.
	drakkar = Node3D.new()
	drakkar.position = Vector3(0.15, 0.75, 0.25)
	drakkar.rotation.y = 0.3
	kg.add_child(drakkar)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.04, 0.04, 0.05)
	glass.roughness = 0.08
	glass.metallic = 0.3
	var body := MeshInstance3D.new()
	body.mesh = B.boxm(Vector3(0.085, 0.14, 0.04))
	body.material_override = glass
	body.position.y = 0.07
	drakkar.add_child(body)
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.78, 0.79, 0.83)
	silver.metallic = 0.9
	silver.roughness = 0.2
	for part in [[B.cyl(0.013, 0.015, 0.028, 10), 0.154], [B.cyl(0.01, 0.01, 0.014, 8), 0.175]]:
		var m := MeshInstance3D.new()
		m.mesh = part[0]
		m.material_override = silver
		m.position.y = part[1]
		drakkar.add_child(m)
	var label := MeshInstance3D.new()
	label.mesh = B.boxm(Vector3(0.06, 0.018, 0.002))
	label.material_override = silver
	label.position = Vector3(0, 0.06, 0.021)
	drakkar.add_child(label)
	# Pieni hintalappu nojaa pöytään pullon edessä (kyltti pienennetty: sign_plate on tehty seinäkylteiksi).
	var tag := B.sign_plate(drakkar, "12 €", Color(0.98, 0.96, 0.85), Color(0.6, 0.1, 0.1), 0.05, 22, Color(0.6, 0.1, 0.1))
	tag.scale = Vector3.ONE * 0.22
	tag.position = Vector3(0.0, 0.012, 0.07)
	tag.rotation.x = -1.1
	_build_rack(kg)
	for x in [0.6, 1.1]:
		B.mesh(kg, B.sphere(0.1, 10), Vector3(x, 0.88, 0.0), Color(0.97, 0.97, 0.95))
		B.mesh(kg, B.sphere(0.06, 8), Vector3(x, 1.0, 0.05), Color(0.97, 0.97, 0.95))
	var bg: Node3D = _groups.bingo
	for x in [-1.0, 0.0, 1.0]:  # bingolaput ja kynät
		B.mesh(bg, B.boxm(Vector3(0.3, 0.01, 0.3)), Vector3(x, 0.76, 0.25), Color(0.98, 0.97, 0.9))
		B.mesh(bg, B.cyl(0.01, 0.01, 0.15, 6), Vector3(x + 0.2, 0.77, 0.25), Color(0.1, 0.2, 0.7), Vector3(0, 0, 90))
	# Kahvipöytä oven vieressä (kahvio tansseissa ja bingossa).
	_table(Vector3(-5.5, 0, 4.0), Vector2(1.6, 0.8))
	B.mesh(self, B.cyl(0.1, 0.12, 0.3, 10), Vector3(-5.8, 0.9, 4.0), Color(0.8, 0.1, 0.1))
	for k in 4:  # munkit
		B.mesh(_groups.tanssit, B.cyl(0.07, 0.07, 0.04, 10), Vector3(-5.3 + (k % 2) * 0.16, 0.78, 3.9 + (k / 2) * 0.16), Color(0.8, 0.55, 0.25))
	var tent := B.sign_plate(self, "KAHVI + PULLA 1 €", Color(0.98, 0.96, 0.9), Color(0.45, 0.12, 0.06), 0.1, 26,
		Color(0.45, 0.12, 0.06))
	tent.position = Vector3(-5.2, 0.9, 4.15)
	tent.rotation.x = -0.25


## Railin vaatetanko keskipöydän vasemmalla puolella: kromattu teline, vakosamettitakki, flanellipaita ja
## neonpinkki hiihtohaalari (tikkauskanavat, valkoinen sahalaitainen kaarroke, raidat, vetoketju, resorit).
const RACK_AT := Vector3(-2.35, 0, -0.45)
const RACK_TOP := 1.78


func _build_rack(kg: Node3D) -> void:
	var rack := Node3D.new()
	rack.position = RACK_AT
	kg.add_child(rack)
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.78, 0.79, 0.82)
	chrome.metallic = 0.9
	chrome.roughness = 0.18
	var tube := func(m: Mesh, pos: Vector3, rot := Vector3.ZERO) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = chrome
		mi.position = pos
		mi.rotation_degrees = rot
		rack.add_child(mi)
	for x in [-0.72, 0.72]:
		tube.call(B.cyl(0.014, 0.014, RACK_TOP, 10), Vector3(x, RACK_TOP / 2.0, 0))
		tube.call(B.cyl(0.012, 0.012, 0.5, 8), Vector3(x, 0.03, 0), Vector3(90, 0, 0))  # jalka
		for z in [-0.24, 0.24]:  # pyörät
			B.mesh(rack, B.cyl(0.025, 0.025, 0.02, 10), Vector3(x, 0.025, z), Color(0.08, 0.08, 0.09), Vector3(0, 0, 90))
	tube.call(B.cyl(0.013, 0.013, 1.46, 10), Vector3(0, RACK_TOP, 0), Vector3(0, 0, 90))
	var body := StaticBody3D.new()
	body.position = Vector3(0, 0.9, 0)
	body.add_child(B.box_shape(Vector3(1.5, 1.8, 0.5)))
	rack.add_child(body)
	_garment_coat(rack, -0.5)
	_garment_flannel(rack, 0.5)
	haalari = Node3D.new()
	haalari.position = Vector3(0, RACK_TOP, 0.03)
	rack.add_child(haalari)
	_garment_haalari(haalari)


## Henkari tangolle: koukku ja puinen olkapuu (h = vaatteen juurisolmu, origo tangon kohdalla).
func _hanger(h: Node3D) -> void:
	var wire := Color(0.7, 0.71, 0.74)
	B.mesh(h, B.cyl(0.004, 0.004, 0.06, 6), Vector3(0, -0.03, 0), wire)
	B.mesh(h, B.cyl(0.004, 0.004, 0.03, 6), Vector3(0, 0.012, -0.01), wire, Vector3(60, 0, 0))
	B.mesh(h, B.boxm(Vector3(0.42, 0.025, 0.03)), Vector3(0, -0.07, 0), Color(0.55, 0.36, 0.2))


func _garment_coat(rack: Node3D, x: float) -> void:
	var h := Node3D.new()
	h.position = Vector3(x, RACK_TOP, -0.03)
	rack.add_child(h)
	_hanger(h)
	var brown := Color(0.45, 0.3, 0.16)
	B.mesh(h, B.boxm(Vector3(0.44, 0.86, 0.1)), Vector3(0, -0.52, 0), brown)
	for k in 14:  # vakosametin urat
		B.mesh(h, B.boxm(Vector3(0.006, 0.84, 0.102)), Vector3(-0.2 + k * 0.03, -0.53, 0), brown.darkened(0.2))
	for s in [-1.0, 1.0]:
		B.mesh(h, B.boxm(Vector3(0.1, 0.72, 0.09)), Vector3(s * 0.26, -0.46, 0), brown.darkened(0.08), Vector3(0, 0, s * 6))
		B.mesh(h, B.boxm(Vector3(0.09, 0.22, 0.012)), Vector3(s * 0.07, -0.2, 0.052), brown.darkened(0.3), Vector3(0, 0, -s * 18))  # kaulus
	for k in 4:
		B.mesh(h, B.cyl(0.012, 0.012, 0.01, 10), Vector3(0.02, -0.36 - k * 0.15, 0.054), Color(0.2, 0.12, 0.06), Vector3(90, 0, 0))


func _garment_flannel(rack: Node3D, x: float) -> void:
	var h := Node3D.new()
	h.position = Vector3(x, RACK_TOP, -0.03)
	rack.add_child(h)
	_hanger(h)
	var red := Color(0.7, 0.1, 0.08)
	var dark := Color(0.25, 0.05, 0.05)
	B.mesh(h, B.boxm(Vector3(0.42, 0.66, 0.06)), Vector3(0, -0.41, 0), red)
	for s in [-1.0, 1.0]:
		B.mesh(h, B.boxm(Vector3(0.09, 0.56, 0.05)), Vector3(s * 0.25, -0.36, 0), red.darkened(0.1), Vector3(0, 0, s * 6))
	for k in 10:  # ruudutus: tummat raidat pysty- ja vaakasuoraan, ohut keltainen viiva harvakseltaan
		B.mesh(h, B.boxm(Vector3(0.016, 0.66, 0.062)), Vector3(-0.19 + k * 0.042, -0.41, 0), dark)
	for k in 15:
		B.mesh(h, B.boxm(Vector3(0.42, 0.016, 0.062)), Vector3(0, -0.1 - k * 0.042, 0), dark)
	for k in 5:
		B.mesh(h, B.boxm(Vector3(0.003, 0.66, 0.063)), Vector3(-0.17 + k * 0.084, -0.41, 0), Color(0.85, 0.7, 0.25))
	for k in 6:  # napit ja kaulus
		B.mesh(h, B.cyl(0.008, 0.008, 0.008, 8), Vector3(0, -0.14 - k * 0.1, 0.033), Color(0.92, 0.9, 0.85), Vector3(90, 0, 0))
	for s in [-1.0, 1.0]:
		B.mesh(h, B.boxm(Vector3(0.08, 0.1, 0.01)), Vector3(s * 0.05, -0.12, 0.034), red.darkened(0.15), Vector3(0, 0, -s * 25))


## Hiihtohaalari henkarissa: vartalo, roikkuvat hihat ja lahkeet. Etupaneelin kuvio (kaarroke, raidat, vetoketju,
## tikkaukset) on piirretty kuvaksi samoilla mitoilla kuin pelaajan varjostimessa (character.gdshader ski_cloth).
func _garment_haalari(h: Node3D) -> void:
	_hanger(h)
	var pink := Looks.HAALARI_PINK
	var seam := pink.darkened(0.18)
	var white := Color(0.95, 0.95, 0.97)
	var yellow := Color(1.0, 0.9, 0.05)
	var turq := Color(0.0, 0.78, 0.82)
	var black := Color(0.06, 0.06, 0.07)
	var torso_h := 0.62
	var ty := -0.07 - torso_h / 2.0
	B.mesh(h, B.boxm(Vector3(0.44, torso_h - 0.04, 0.12)), Vector3(0, ty - 0.02, 0), pink)
	for s in [-1.0, 1.0]:  # pyöreät toppaolkapäät
		B.mesh(h, B.sphere(0.5, 14), Vector3(s * 0.2, -0.1, 0), white).scale = Vector3(0.13, 0.09, 0.12)
	B.mesh(h, B.cyl(0.07, 0.075, 0.06, 16), Vector3(0, -0.07, 0), black).scale = Vector3(1, 1, 0.6)  # pystykaulus
	var front := MeshInstance3D.new()  # kuvioitu etupaneeli
	var q := QuadMesh.new()
	q.size = Vector2(0.44, torso_h - 0.04)
	front.mesh = q
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = _haalari_front(pink, white, yellow, turq)
	fm.roughness = 0.5
	front.material_override = fm
	front.position = Vector3(0, ty - 0.02, 0.0605)
	h.add_child(front)
	# Raaja: soikea lieriö (pituus l, säteet ylhäällä ja alhaalla), osat lueteltuna [alku, loppu, väri] ylhäältä alas.
	var limb := func(parent: Node3D, r0: float, r1: float, l: float, parts: Array, depth: float) -> void:
		for part in parts:
			var y0: float = part[0]
			var y1: float = part[1]
			var ra := lerpf(r0, r1, y0 / l) + 0.002 * float(part.size() > 3)
			var rb := lerpf(r0, r1, y1 / l) + 0.002 * float(part.size() > 3)
			var m := B.mesh(parent, B.cyl(ra, rb, y1 - y0, 16), Vector3(0, -(y0 + y1) / 2.0, 0), part[2])
			m.scale = Vector3(1, 1, depth)
	for s in [-1.0, 1.0]:
		# Hiha roikkuu olkapäästä hieman ulospäin: valkoinen olkavarsi, raidat, tikattu pinkki kyynärvarsi, resori.
		var arm := Node3D.new()
		arm.position = Vector3(s * 0.24, -0.11, 0)
		arm.rotation.z = s * 0.1
		h.add_child(arm)
		var ap := [[0.0, 0.22, white], [0.22, 0.25, yellow], [0.25, 0.27, turq], [0.27, 0.52, pink], [0.52, 0.58, black]]
		for k in 3:
			ap.append([0.33 + k * 0.07, 0.336 + k * 0.07, seam, true])
		limb.call(arm, 0.065, 0.052, 0.58, ap, 0.85)
		# Lahje: tikattu pinkki, keltainen ja turkoosi sivuraita ulkosivulla, musta nilkkaresori.
		var leg := Node3D.new()
		leg.position = Vector3(s * 0.11, -0.07 - torso_h + 0.03, 0)
		h.add_child(leg)
		var lh := 0.7
		var lp := [[0.0, lh - 0.06, pink], [lh - 0.06, lh, black]]
		for k in 9:
			lp.append([0.06 + k * 0.07, 0.066 + k * 0.07, seam, true])
		limb.call(leg, 0.11, 0.09, lh, lp, 0.55)
		for k in 2:  # sivuraidat: ohuet levyt lahkeen ulkosivulla
			var st := B.mesh(leg, B.boxm(Vector3(0.004, lh - 0.1, [0.03, 0.016][k])), Vector3(s * (0.1 + 0.002 * k), -lh / 2.0 + 0.02,
				[0.0, 0.025][k]), [yellow, turq][k])
			st.rotation.z = s * 0.028
	# Vyötärön kuminauha ja hintalappu hihassa.
	B.mesh(h, B.boxm(Vector3(0.45, 0.035, 0.125)), Vector3(0, -0.07 - torso_h + 0.04, 0), pink.darkened(0.25))
	var tag := B.sign_plate(h, "6 €", Color(0.98, 0.96, 0.85), Color(0.6, 0.1, 0.1), 0.05, 22, Color(0.6, 0.1, 0.1))
	tag.scale = Vector3.ONE * 0.3
	tag.position = Vector3(0.33, -0.66, 0.07)


## Etupaneelin kuva (0,5 cm / pikseli): kaarroke ja raidat kuten varjostimessa, kaulus, vetoketju ja tikkaukset.
static func _haalari_front(pink: Color, white: Color, yellow: Color, turq: Color) -> ImageTexture:
	var w := 92
	var hgt := 124
	var img := Image.create(w, hgt, false, Image.FORMAT_RGB8)
	for py in hgt:
		for px in w:
			var x := (px + 0.5) / w * 0.46 - 0.23
			var y := -(py + 0.5) / hgt * 0.62  # 0 = olkapäät, alas negatiivinen
			var zig := -0.2 - 0.09 * absf(fposmod(x * 8.0 + 0.5, 1.0) - 0.5) * 2.0
			var d := y - zig
			var col := pink
			if d > 0.0:
				col = white
			elif d > -0.032:
				col = yellow
			elif d > -0.054:
				col = turq
			if y > -0.035:
				col = Color(0.06, 0.06, 0.07)  # kaulus
			var puff := 0.86 + 0.14 * sin(fposmod(y * 14.0, 1.0) * PI)
			col = col * puff if y < -0.035 else col
			if absf(x) < 0.011 and y < -0.02:
				col = Color(0.05, 0.05, 0.05)
				if absf(x) < 0.005 and fposmod(y * 260.0, 1.0) < 0.5:
					col = Color(0.82, 0.83, 0.86)
			if absf(x - 0.012) < 0.008 and absf(y + 0.08) < 0.02:
				col = Color(0.82, 0.83, 0.86)  # vetimen läppä
			col.a = 1.0
			img.set_pixel(px, py, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_people() -> void:
	for i in PEOPLE.size():
		var pd: Dictionary = PEOPLE[i]
		var holder := Node3D.new()
		add_child(holder)
		var look: Dictionary = pd.get("look", {})
		if pd.has("look_ref"):
			look = Looks.SINIKKA if pd.look_ref == "SINIKKA" else Looks.player()
		var c := Looks.make(holder, look)
		var lift := 0.02 if pd.pose == "Sitting_Idle" else 0.0
		c.position = pd.at + Vector3(0, lift, 0)
		c.rotation.y = B.yaw_to(pd.face)
		c.set_meta("pose", pd.pose)
		c.play(pd.pose, 0.0)
		if pd.pose == "Sitting_Idle":  # jakkara alle
			B.mesh(holder, B.cyl(0.2, 0.2, 0.45, 10), pd.at + Vector3(0, 0.22, 0) - Vector3(pd.face.x, 0, pd.face.z).normalized() * 0.05, TRIM)
		if pd.id in ["hilkka", "tauno"] or pd.name.begins_with("Mummo"):
			Looks.hunch(c, 0.2)
		match pd.get("instrument", ""):
			"haitari":
				B.mesh(holder, B.boxm(Vector3(0.45, 0.35, 0.25)), pd.at + Vector3(0, 1.15, 0.3), Color(0.75, 0.1, 0.12))
				B.mesh(holder, B.boxm(Vector3(0.47, 0.3, 0.08)), pd.at + Vector3(0, 1.15, 0.45), Color(0.95, 0.95, 0.9))
			"kitara":
				var g := B.mesh(holder, B.boxm(Vector3(0.35, 0.45, 0.08)), pd.at + Vector3(0.05, 1.05, 0.28), Color(0.6, 0.3, 0.12))
				g.rotation_degrees.z = 35.0
				var neck := B.mesh(holder, B.boxm(Vector3(0.06, 0.55, 0.04)), pd.at + Vector3(-0.22, 1.35, 0.28), Color(0.3, 0.18, 0.08))
				neck.rotation_degrees.z = 35.0
		var body := StaticBody3D.new()
		body.position = pd.at
		body.add_child(B.capsule_shape(0.3, 1.4))
		holder.add_child(body)
		_bubbles[c] = B.bubble(c, Vector3(0, 1.85, 0), Color.WHITE, 0.7)
		_people.append(c)
		_holders.append(holder)


## Tanssivat parit (pelkkä tausta): kaksi hahmoa vastakkain, kiertävät tanssilattiaa _processissa.
func _build_dancers() -> void:
	var looks := [
		[{"shirt": Color(0.2, 0.3, 0.5), "pants": Color(0.15, 0.15, 0.2), "hair": "Hair_SimpleParted", "height": 1.8},
			{"model": "female", "shirt": Color(0.85, 0.3, 0.35), "pants": Color(0.2, 0.2, 0.25), "hair": "Hair_Long", "height": 1.65}],
		[{"shirt": Color(0.5, 0.45, 0.35), "pants": Color(0.2, 0.18, 0.15), "hair": "Hair_Buzzed", "height": 1.75, "belly": 0.6},
			{"model": "female", "shirt": Color(0.4, 0.6, 0.85), "pants": Color(0.25, 0.25, 0.3), "hair": "Hair_Buns", "height": 1.6}],
		[{"shirt": Color(0.95, 0.95, 0.9), "pants": Color(0.1, 0.1, 0.12), "hair": "Hair_SimpleParted", "height": 1.78},
			{"model": "female", "shirt": Color(0.55, 0.25, 0.6), "pants": Color(0.2, 0.2, 0.25), "hair": "Hair_Long", "height": 1.62}],
	]
	for pair in looks:
		var root := Node3D.new()
		add_child(root)
		for k in 2:
			var c := Looks.make(root, pair[k])
			c.position = Vector3(0, 0, -0.3 if k == 0 else 0.3)
			c.rotation.y = 0.0 if k == 0 else PI
			c.play("Dance", 0.0)
		_dancers.append(root)
