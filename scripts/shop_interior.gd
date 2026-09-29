extends Node3D
## K-Marketin sisätila: oluthylly, kassajono kolikoita laskevine harmaapäineen ja naapurin Anna-Liisa.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")
const Neighbor := preload("res://scripts/neighbor.gd")

const DOOR := Vector3(0, 0, 7.6)
const ENTRY := Vector3(0, 0, 5.6)
const COOLER_SPOT := Vector3(-6, 0, -7.2)
const GRILL_SPOT := Vector3(-9.6, 0, 6.4)
const BEER_PRICE := 12.90
## Grillihyllyn tuotteet: avain -> [nimi, hinta].
const EXTRAS := {"makkara": ["grillimakkara", 3.50], "tikut": ["tulitikut", 1.20]}
## Karkkiteline kassan lähellä (heräteostos): suklaalevy.
const CANDY_SPOT := Vector3(5.2, 0, 7.2)
const CANDY := ["suklaa", "suklaalevy", 2.49]
const QUEUE_FRONT := Vector3(7.6, 0, 5.4)
const QUEUE_STEP := Vector3(0, 0, -1.4)
const SPOT_RADIUS := 1.1
const GRANDPA_SPEED := 1.1

const COUNTING := [
	"5 senttiä...", "10...", "20...", "25...", "ai hetkinen...",
	"missäs se viiskymppinen oli...", "...", "alotetaan alusta.", "5 senttiä...",
	"onko teillä bonuskorttia?", "no ei ole.", "10...",
]
const CASHIER_LINES := ["Seuraava!", "Bonuskortti?", "Kuitti mukaan?"]
## Viime hetken lisäykset, kun vuoro on jo loppumassa: [harmaapää, kassa, lisäaika s].
const LAST_MINUTE := [
	["Ottaisin vielä yhden ässäarvan.", "Onnea arvontaan!", 4.0],
	["Ainiin, oli se pakettiki vielä!", "Mikäs paketti se oli?", 6.0],
	["Ja kaks ässäarpaa, ku on perjantai.", "Kaks ässää, olkaa hyvä.", 4.5],
	["Ainiin! Se paketti... mihinkäs mää sen lapun laitoin...", "Otetaan vaikka nimellä.", 7.0],
]

signal paid(total: float)
signal busted
signal exited(bought: bool)

var active := false
var has_beer := false
var has_paid := false
var cart := {}  # grillituotteet: avain -> hinta
var money := 20.0  # main päivittää ennen sisääntuloa

var walker: CharacterBody3D
var neighbor: CharacterBody3D
var hint := ""

var _queue: Array[Node3D] = []
var _leaving: Array[Node3D] = []
var _queue_started := false
var _serve_t := 0.0
var _count_i := 0
var _count_t := 0.0
var _count_label: Label3D
var _cashier_bubble: Label3D
var _cashier: Node3D
var _cashier_t := 0.0
var _neighbor_t := -1.0
var _neighbor_spawned := false


func _ready() -> void:
	_build_room()
	_build_checkout()
	walker = Walker.new()
	walker.position = DOOR
	add_child(walker)
	for i in 3:
		_queue.append(_grandpa(QUEUE_FRONT + QUEUE_STEP * i, i))
	_count_label = B.label(self, "", Vector3.ZERO, 44, Color(1, 1, 0.8), true)


func enter() -> void:
	active = true
	walker.position = ENTRY
	walker.rotation.y = 0.0
	walker.activate()
	if not _neighbor_spawned and _neighbor_t < 0.0:
		_neighbor_t = randf_range(4.0, 10.0)


func leave() -> void:
	active = false
	walker.controls_enabled = false


func _process(delta: float) -> void:
	_update_grandpas(delta)
	_cashier_t -= delta
	if _cashier_t <= 0.0:
		_cashier_bubble.text = ""
		_cashier.play("Idle", 0.4)
	if not active:
		return

	if _neighbor_t > 0.0:
		_neighbor_t -= delta
		if _neighbor_t <= 0.0:
			_spawn_neighbor()

	var p := walker.position
	var my_spot := QUEUE_FRONT + QUEUE_STEP * _queue.size()
	var has_items := has_beer or not cart.is_empty()
	var in_queue := has_items and not has_paid and _flat(p, my_spot) < SPOT_RADIUS
	if in_queue and not _queue_started:
		_queue_started = true
		_serve_t = randf_range(5.0, 8.0)

	hint = ""
	var e := Input.is_action_just_pressed("interact")
	if _flat(p, DOOR) < 1.4:
		if has_items and not has_paid:
			hint = "Maksa ensin! Kassalle jonoon."
		else:
			hint = "[E] Poistu kaupasta"
			if e:
				exited.emit(has_paid and has_beer)
	elif _flat(p, GRILL_SPOT) < 1.6 and not has_paid:
		var next := ""
		for k in EXTRAS:
			if not cart.has(k):
				next = k
				break
		if next == "":
			hint = "Makkarat ja tikut kassissa. Kassalle!"
		else:
			hint = "[E] Ota %s (%s €)" % [EXTRAS[next][0], _eur(EXTRAS[next][1])]
			if e:
				cart[next] = EXTRAS[next][1]
				walker.set_carrying(true)
				Sfx.play("pickup", -2.0, 0.8)
	elif _flat(p, CANDY_SPOT) < 1.2 and not has_paid:
		if cart.has(CANDY[0]):
			hint = "Suklaalevy kassissa."
		else:
			hint = "[E] Ota %s (%s €)" % [CANDY[1], _eur(CANDY[2])]
			if e:
				cart[CANDY[0]] = CANDY[2]
				walker.set_carrying(true)
				Sfx.play("pickup", -4.0, 1.1)
	elif not has_beer and _flat(p, COOLER_SPOT) < 1.5:
		hint = "[E] Ota kuutonen keskaria"
		if e:
			has_beer = true
			walker.set_carrying(true)
			Sfx.play("pickup")
	elif not has_paid and in_queue and _queue.is_empty():
		var total := _total()
		hint = "[E] Maksa %s €" % _eur(total)
		if e:
			if total > money + 0.001 and not cart.is_empty():
				cart.clear()
				_cashier_say("Rahat ei riitä makkaroihin! Ne jää tänne.")
			elif total > money + 0.001:
				_cashier_say("Rahat ei riitä!")
			else:
				has_paid = true
				Sfx.play("register")
				_cashier_say("Kiitos, hei!")
				paid.emit(total)
	elif not has_paid and in_queue:
		hint = "Jonotat... edessä %d harmaapäätä" % _queue.size()
	elif not has_paid and has_items:
		hint = "Kassajonoon (keltainen ympyrä)%s" % ("" if has_beer else " – tai kaljat takaseinältä")
	elif not has_paid:
		hint = "Kaljat takaseinältä, grillitarvikkeet oven vierestä"
	else:
		hint = "Maksettu! Ulos ovesta."


func _total() -> float:
	var t := BEER_PRICE if has_beer else 0.0
	for k in cart:
		t += cart[k]
	return t


func _eur(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")


func _update_grandpas(delta: float) -> void:
	for i in _queue.size():
		_step_toward(_queue[i], QUEUE_FRONT + QUEUE_STEP * i, delta)
	for g in _leaving.duplicate():
		if _step_toward(g, DOOR, delta):
			_leaving.erase(g)
			g.queue_free()

	if _queue.is_empty():
		_count_label.text = ""
		return
	var front := _queue[0]
	_count_label.position = front.position + Vector3(0, 2.6, 0)
	if not _queue_started:
		_count_label.text = ""
		return
	_count_t -= delta
	if _count_t <= 0.0:
		var line: String = COUNTING[_count_i % COUNTING.size()]
		_count_label.text = line
		if line.length() > 8:
			Sfx.babble(front, "mummo", line)
		else:
			Sfx.play_on(front, "coin", -2.0)
		_count_i += 1
		_count_t = 1.3
	_serve_t -= delta
	if _serve_t <= 0.0 and not front.has_meta("extra") and randf() < 0.55:
		# Harmaapää keksii vielä jotain: ässäarpa tai unohtunut paketti.
		var extra: Array = LAST_MINUTE.pick_random()
		front.set_meta("extra", true)
		_count_label.text = extra[0]
		_count_t = 2.5
		Sfx.babble(front, "mummo", extra[0])
		_cashier_say(extra[1])
		_serve_t = extra[2]
		return
	if _serve_t <= 0.0:
		_queue.pop_front()
		_leaving.append(front)
		_cashier_say(CASHIER_LINES.pick_random())
		_serve_t = randf_range(5.0, 8.0)
		_count_i = 0


## Liikuttaa hahmoa kohti pistettä. Palauttaa true kun perillä.
func _step_toward(n: Node3D, goal: Vector3, delta: float) -> bool:
	var to_g := goal - n.position
	to_g.y = 0.0
	if to_g.length() < 0.05:
		n.play("Idle_Talking" if n == _front() and _queue_started else "Idle", 0.3)
		n.rotation.y = lerp_angle(n.rotation.y, B.yaw_to(Vector3(0, 0, 1)), 1.0 - exp(-4.0 * delta))
		return true
	n.rotation.y = lerp_angle(n.rotation.y, B.yaw_to(to_g), 1.0 - exp(-6.0 * delta))
	n.position += to_g.normalized() * minf(GRANDPA_SPEED * delta, to_g.length())
	n.play("Walk", 0.25, GRANDPA_SPEED / 1.4)
	return false


func _front() -> Node3D:
	return _queue[0] if not _queue.is_empty() else null


func _spawn_neighbor() -> void:
	_neighbor_spawned = true
	neighbor = Neighbor.new()
	neighbor.position = DOOR
	neighbor.target = walker
	var wps: Array[Vector3] = [
		Vector3(-3, 0, 5.5), Vector3(-7, 0, 5.5), Vector3(-7, 0, -6.8), Vector3(-3, 0, -6.8),
		Vector3(3.5, 0, -6.8), Vector3(3.5, 0, 5.5),
	]
	neighbor.waypoints = wps
	neighbor.pauses = {2: 2.0, 4: 1.5, 5: 1.0}
	neighbor.busted.connect(func() -> void: busted.emit())
	add_child(neighbor)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _cashier_say(text: String) -> void:
	_cashier_bubble.text = text
	_cashier_t = 2.0
	_cashier.play("Idle_Talking", 0.3)
	Sfx.babble(_cashier, "kassa", text)


# --- Rakennus ----------------------------------------------------------------

func _build_room() -> void:
	var wall := Color(0.8, 0.79, 0.75)
	var orange := Color(1.0, 0.42, 0.0)
	B.box(self, Vector3(80, 0.2, 80), Vector3(0, -0.2, 0), Color(0.12, 0.12, 0.14), false)
	B.box(self, Vector3(24, 0.2, 18), Vector3(0, -0.1, 0), Color(0.62, 0.62, 0.58), false)
	# Lattialaatat.
	for x in range(-11, 12, 2):
		B.box(self, Vector3(0.04, 0.01, 18), Vector3(x, 0.005, 0), Color(0.7, 0.7, 0.66), false)
	B.box(self, Vector3(24, 3.5, 0.3), Vector3(0, 1.75, -9), wall)
	B.box(self, Vector3(0.3, 3.5, 18), Vector3(-12, 1.75, 0), wall)
	B.box(self, Vector3(0.3, 3.5, 18), Vector3(12, 1.75, 0), wall)
	B.box(self, Vector3(24.2, 0.5, 0.32), Vector3(0, 3.3, -9), orange, false)
	# Etuseinä matala, ettei peitä kameraa; törmäys täyskorkea.
	var front := StaticBody3D.new()
	front.position = Vector3(0, 1.75, 9)
	front.add_child(B.box_shape(Vector3(24, 3.5, 0.3)))
	add_child(front)
	B.box(self, Vector3(24, 0.6, 0.3), Vector3(0, 0.3, 9), wall, false)
	B.box(self, Vector3(2.4, 0.08, 0.35), Vector3(0, 0.64, 9), orange, false)
	# Vihreä poistumistiekyltti tolpassa oven vieressä.
	var exit := B.sign_plate(B.sign_pole(self, Vector3(1.7, 0, 8.6), 2.0), "ULOS", Color(0.05, 0.55, 0.25), Color.WHITE,
		0.22, 36, Color.WHITE)
	exit.position.y = 1.9

	# Hyllyt tuotteineen.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var products := [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(0.95, 0.8, 0.2),
		Color(0.3, 0.7, 0.3), Color(0.95, 0.95, 0.95), Color(0.6, 0.3, 0.15)]
	for x in [-9.0, -5.0, -1.0]:
		B.box(self, Vector3(1.2, 1.9, 9), Vector3(x, 0.95, -1.5), Color(0.55, 0.55, 0.58))
		for h in [0.45, 0.95, 1.45]:
			for z in range(-5, 3):
				var c: Color = products[rng.randi() % products.size()]
				B.box(self, Vector3(1.26, 0.3, 0.8), Vector3(x, h, z + 0.5), c, false)

	# Oluthylly takaseinällä.
	B.box(self, Vector3(8, 2.3, 1), Vector3(-6, 1.15, -8.4), Color(0.85, 0.85, 0.88))
	var glass := MeshInstance3D.new()
	glass.mesh = B.boxm(Vector3(7.6, 1.9, 0.05))
	glass.material_override = B.unshaded(Color(0.6, 0.85, 1.0, 0.5))
	glass.position = Vector3(-6, 1.15, -7.88)
	add_child(glass)
	for x in range(-9, -2):
		for h in [0.6, 1.2, 1.8]:
			B.box(self, Vector3(0.7, 0.35, 0.4), Vector3(x + 0.5, h, -8.2), Color(0.95, 0.75, 0.1), false)
	var beer_sign := B.sign_plate(self, "OLUET", Color(1.0, 0.42, 0.0), Color.WHITE, 0.6, 110, Color.WHITE)
	beer_sign.position = Vector3(-6, 2.75, -8.8)

	# Grillihylly oven vieressä: makkarapaketit ja tulitikut.
	B.box(self, Vector3(1.2, 1.0, 2.4), GRILL_SPOT + Vector3(-1.3, 0.5, 0), Color(0.85, 0.88, 0.9))
	B.box(self, Vector3(1.1, 0.06, 2.3), GRILL_SPOT + Vector3(-1.3, 1.02, 0), Color(0.6, 0.8, 0.95), false)
	for i in 6:
		B.box(self, Vector3(0.35, 0.08, 0.3), GRILL_SPOT + Vector3(-1.45 + (i % 2) * 0.4, 1.09, -0.8 + (i / 2) * 0.5),
			Color(0.85, 0.25, 0.2), false)
	for i in 4:
		B.box(self, Vector3(0.12, 0.05, 0.08), GRILL_SPOT + Vector3(-0.95, 1.08, 0.7 + i * 0.12), Color(0.95, 0.8, 0.2), false)
	# Karkkiteline etuseinää vasten kassan lähellä: suklaalevyjä kääreissään.
	B.box(self, Vector3(1.0, 1.1, 0.5), CANDY_SPOT + Vector3(0, 0.55, 1.2), Color(0.85, 0.88, 0.9))
	for i in 8:
		var wrap: Color = [Color(0.1, 0.25, 0.7), Color(0.45, 0.15, 0.5), Color(0.75, 0.1, 0.12)][i % 3]
		B.box(self, Vector3(0.2, 0.03, 0.1), CANDY_SPOT + Vector3(-0.33 + (i % 4) * 0.22, 1.13, 1.08 + (i / 4) * 0.14), wrap, false)
	# Hyllynreunakyltti grillihyllyn päällä, käytävän puolelle päin.
	var grill_sign := B.sign_plate(self, "GRILLI", Color(0.8, 0.15, 0.1), Color.WHITE, 0.2, 36, Color.WHITE)
	grill_sign.position = GRILL_SPOT + Vector3(-1.3, 1.3, 0)
	grill_sign.rotation.y = PI / 2.0

	for p in [Vector3(-8, 3.2, -3), Vector3(0, 3.2, -3), Vector3(8, 3.2, 3), Vector3(-6, 3.2, 5)]:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 12.0
		l.light_energy = 0.25
		add_child(l)


func _build_checkout() -> void:
	B.box(self, Vector3(1.0, 1.0, 2.6), Vector3(9, 0.5, 5.2), Color(0.3, 0.3, 0.32))
	B.box(self, Vector3(1.04, 0.06, 2.64), Vector3(9, 1.02, 5.2), Color(1.0, 0.42, 0.0), false)
	B.box(self, Vector3(0.4, 0.3, 0.4), Vector3(9, 1.2, 6.0), Color(0.1, 0.1, 0.1), false)
	# Kassakyltti roikkuu tiskin yllä.
	var till_sign := B.sign_plate(self, "KASSA", Color(1.0, 0.42, 0.0), Color.WHITE, 0.4, 70, Color.WHITE)
	till_sign.position = Vector3(9, 2.7, 5.2)
	till_sign.rotation.y = PI / 2.0
	for dz in [-0.3, 0.3]:
		B.mesh(self, B.cyl(0.008, 0.008, 0.8, 4), Vector3(9, 3.1, 5.2 + dz), Color(0.3, 0.3, 0.3))
	_cashier = Looks.make(self, Looks.CASHIER)
	_cashier.position = Vector3(10.2, 0, 5.2)
	_cashier.rotation.y = B.yaw_to(Vector3(-1, 0, 0))
	_cashier_bubble = B.label(self, "", Vector3(10.2, 2.6, 5.2), 48, Color.WHITE, true)
	# Jonopaikkamerkit lattiassa.
	for i in 5:
		var ring := MeshInstance3D.new()
		ring.mesh = B.cyl(0.5, 0.5, 0.02)
		ring.material_override = B.unshaded(Color(1, 0.85, 0.1, 0.35))
		ring.position = QUEUE_FRONT + QUEUE_STEP * i + Vector3(0, 0.02, 0)
		add_child(ring)


func _grandpa(pos: Vector3, i: int) -> Node3D:
	var g := Looks.make(self, Looks.GRANDPAS[i % Looks.GRANDPAS.size()])
	Looks.hunch(g, 0.4)
	g.position = pos
	g.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	B.guide(g, "Harmaapää", Vector3(0, 2.05, 0), 36, Color(0.85, 0.85, 0.85), true)
	return g
