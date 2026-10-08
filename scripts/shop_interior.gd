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
## Alkon hylly vasemmalla seinällä (vain Vaalan K-Market Tervaportissa, vaala = true): viina kätköviinaksi.
const ALKO_SPOT := Vector3(-10.4, 0, -2.0)
const ALKO := ["Koskenkorva 0,5 l", 21.90]
const ALKO_MAX := 2
const CANDY := ["suklaa", "suklaalevy", 2.49]
## Leipähylly karkkitelineen vieressä: eväät (syödään T:llä, ks. main.gd _eat_menu). Avain -> [nimi, hinta].
const BAKERY_SPOT := Vector3(3.2, 0, 7.2)
const BAKERY := {"pulla": ["korvapuusti", 1.50], "piirakka": ["lihapiirakka", 2.20]}
## Kotiviinihylly etuseinällä oven vasemmalla: turbohiiva ja sokeri (kotiviini autotallin saavissa, main.gd).
const BREW_SPOT := Vector3(-4.0, 0, 7.2)
const BREW := {"turbohiiva": ["turbohiiva", 4.90], "sokeri": ["sokeri 1 kg", 1.60]}
## Päivin hylly oikealla seinällä (kauppalistan muistipeli, #12): jokaisella tuotteella oma lokero, jossa kaikki
## värit. Tuotteet maksetaan Päivin rahoilla. Tuote -> laatikon koko (muoto erottaa tuotteet toisistaan).
const PRODUCTS := {
	"tamponi": Vector3(0.1, 0.12, 0.07), "maito": Vector3(0.09, 0.24, 0.09), "ristikkolehti": Vector3(0.14, 0.02, 0.2),
	"voi": Vector3(0.12, 0.06, 0.08), "jogurtti": Vector3(0.09, 0.1, 0.09), "tiskiaine": Vector3(0.07, 0.22, 0.05),
	"vessapaperi": Vector3(0.14, 0.14, 0.14), "kahvi": Vector3(0.09, 0.18, 0.06), "hammastahna": Vector3(0.16, 0.04, 0.04),
	"kynttilä": Vector3(0.05, 0.2, 0.05),
}
const COLORS := {
	"punainen": Color(0.85, 0.12, 0.1), "sininen": Color(0.15, 0.35, 0.85), "vihreä": Color(0.15, 0.62, 0.2),
	"keltainen": Color(0.95, 0.85, 0.15), "violetti": Color(0.55, 0.25, 0.72),
}
const SHELF_X := 11.45  # hyllyn keskilinja; pelaaja seisoo sen edessä (x ~ 10.4)
const SHELF_Z0 := -8.0  # ensimmäisen lokeron alku, lokerot 1 m välein +Z-suuntaan
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
var at_till := false  # kassalla vuorossa: main.gd näyttää puhevihjeen kauppiaalle

var active := false
var has_beer := false
var has_paid := false
var stolen := false  # juoksukaljat: rahat ei riittäneet, kaljat ja viinat vietiin maksamatta
var cart := {}  # grillituotteet: avain -> hinta
## Moraali-tilan palkinto/haitta (main.gd _stat_effects): kassan loppusumman kerroin (0,9 / 1,1).
var price_mult := 1.0
var bag := {}  # Päivin hyllyn tuotteet: tuote -> väri
var _sel := {}  # lokeron valittu väri: tuote -> värin indeksi
var _items := {}  # tuote -> väri -> MeshInstance3D (valittu nostetaan esiin)
var money := 20.0  # main päivittää ennen sisääntuloa
## Vaalan K-Market Tervaportti: Alkon hylly näkyvissä, eikä Saloisten naapuri (Anna-Liisa) tule kauppaan.
var vaala := false
var alko := true  # Vaalassa: Alkon hylly (Tervaportti)
var _alko: Node3D

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
	_build_paivi_shelf()
	_build_alko()
	walker = Walker.new()
	walker.position = DOOR
	walker.bounds = [Rect2(-12.0, -9.0, 24.0, 18.0)]  # myymälän seinät
	add_child(walker)
	for i in 3:
		_queue.append(_grandpa(QUEUE_FRONT + QUEUE_STEP * i, i))
	_count_label = B.label(self, "", Vector3.ZERO, 44, Color(1, 1, 0.8), true)


func enter() -> void:
	active = true
	walker.position = ENTRY
	walker.rotation.y = 0.0
	walker.activate()
	_alko.visible = vaala and alko
	if not vaala and not _neighbor_spawned and _neighbor_t < 0.0:
		_neighbor_t = randf_range(4.0, 10.0)


func leave() -> void:
	active = false
	walker.controls_enabled = false


var busy := false  # syö/juo-valikko auki (main.gd): ovi ja hyllyt eivät reagoi E:hen
var _enter_frame := -1


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
	var has_items := has_beer or not cart.is_empty() or not bag.is_empty()
	var in_queue := has_items and not has_paid and _flat(p, my_spot) < SPOT_RADIUS
	if in_queue and not _queue_started:
		_queue_started = true
		_serve_t = randf_range(5.0, 8.0)

	hint = ""
	at_till = false
	var e := Input.is_action_just_pressed("interact") and not busy and Engine.get_process_frames() != _enter_frame
	var broke := not has_paid and _total() > money + 0.001
	if _flat(p, DOOR) < 1.4:
		if has_items and not has_paid:
			# Maksamatta saa lähteä milloin vain, mutta kauppias tulee perään (main.gd _start_shop_chase).
			hint = "[E] Lähde maksamatta (%s €) – kauppias tulee perään!%s" % [_eur(_total()),
				"" if not broke else "  · Tai vie tavarat takaisin hyllyyn."]
			if e:
				_run_out()
		else:
			hint = "[E] Poistu kaupasta"
			if e:
				exited.emit(has_paid and has_beer)
	elif not has_paid and _shelf_section(p) != "":
		_shelf_logic(_shelf_section(p), e)
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
		_return_logic(EXTRAS)
	elif _flat(p, BAKERY_SPOT) < 1.2 and not has_paid:
		var next := ""
		for k in BAKERY:
			if not cart.has(k):
				next = k
				break
		if next == "":
			hint = "Korvapuusti ja lihapiirakka kassissa."
		else:
			hint = "[E] Ota %s (%s €)" % [BAKERY[next][0], _eur(BAKERY[next][1])]
			if e:
				cart[next] = BAKERY[next][1]
				walker.set_carrying(true)
				Sfx.play("pickup", -4.0, 0.9)
		_return_logic(BAKERY)
	elif vaala and alko and _flat(p, ALKO_SPOT) < 1.5 and not has_paid:
		var n := alko_count()
		if n >= ALKO_MAX:
			hint = "Kaksi pulloa riittää. Kassalle!"
		else:
			hint = "[E] Ota %s Alkon hyllystä (%s €)" % [ALKO[0], _eur(ALKO[1])]
			if e:
				cart["viina%d" % n] = ALKO[1]
				walker.set_carrying(true)
				Sfx.play("glass", -6.0, 1.1)
		if n > 0:
			hint += "   [Q] palauta pullo hyllyyn"
			if Input.is_action_just_pressed("bell"):
				cart.erase("viina%d" % (n - 1))
				_update_carry()
				Sfx.play("glass", -8.0, 0.8)
	elif _flat(p, BREW_SPOT) < 1.2 and not has_paid:
		var next := ""
		for k in BREW:
			if not cart.has(k):
				next = k
				break
		if next == "":
			hint = "Turbohiiva ja sokeri kassissa."
		else:
			hint = "[E] Ota %s (%s €)" % [BREW[next][0], _eur(BREW[next][1])]
			if e:
				cart[next] = BREW[next][1]
				walker.set_carrying(true)
				Sfx.play("pickup", -4.0, 1.0)
		_return_logic(BREW)
	elif _flat(p, CANDY_SPOT) < 1.2 and not has_paid:
		if cart.has(CANDY[0]):
			hint = "[E] Palauta %s telineeseen" % CANDY[1]
			if e:
				cart.erase(CANDY[0])
				_update_carry()
				Sfx.play("pickup", -8.0, 0.7)
		else:
			hint = "[E] Ota %s (%s €)" % [CANDY[1], _eur(CANDY[2])]
			if e:
				cart[CANDY[0]] = CANDY[2]
				walker.set_carrying(true)
				Sfx.play("pickup", -4.0, 1.1)
	elif not has_paid and _flat(p, COOLER_SPOT) < 1.5:
		hint = "[E] Ota kuutonen keskaria" if not has_beer else "[E] Palauta kuutonen kylmiöön"
		if e:
			has_beer = not has_beer
			_update_carry()
			Sfx.play("pickup", 0.0 if has_beer else -6.0, 1.0 if has_beer else 0.7)
	elif not has_paid and in_queue and _queue.is_empty():
		at_till = true  # kauppiaan kanssa puhutaan keskusteluikkunassa (main.gd): maksu, ostokset tiskille, neuvot
	elif not has_paid and in_queue:
		hint = "Jonotat... edessä %d harmaapäätä" % _queue.size()
	elif not has_paid and has_items:
		hint = "Kassajonoon (keltainen ympyrä)%s" % ("" if has_beer else " – tai kaljat takaseinältä")
		if broke:
			hint += "
Rahat ei riitä (%s / %s €): palauta tavaraa samaan hyllyyn, josta otit" % [_eur(money), _eur(_total())]
	elif not has_paid:
		hint = where_text()
	else:
		hint = "Maksettu! Ulos ovesta."


## Mistä mitäkin löytyy (vihje ja kauppiaan neuvo).
func where_text() -> String:
	return "Kaljat takaseinältä, grillitarvikkeet oven vierestä, Päivin tuotteet oikealta seinältä" + \
		(", Alko vasemmalta seinältä" if vaala and alko else "")


## Kassalla: summa, riittävätkö rahat ja hinnan mielialalisä (main.gd keskusteluikkuna).
func till_total() -> float:
	return _total()


func can_pay() -> bool:
	return _total() <= money + 0.001


func own_items() -> bool:
	return has_beer or not cart.is_empty()


func price_note() -> String:
	if price_mult < 1.0:
		return "Hyvä mieli: kassa antaa −10 %."
	if price_mult > 1.0:
		return "Nyrpeä naama: +10 %."
	return ""


func pay() -> void:
	var total := _total()
	has_paid = true
	Sfx.play("register")
	paid.emit(total)


## Omat ostokset (kalja, kori) jätetään tiskille, Päivin tavarat jäävät kassiin.
func leave_own() -> void:
	has_beer = false
	cart.clear()
	_update_carry()
	Sfx.play("rattle", -10.0, 0.8)


## Maksamatta ulos: kaikki korin tavarat ja Päivin kassi lähtevät mukaan, kauppias tulee perään.
func _run_out() -> void:
	stolen = true
	has_paid = true
	_cashier_say("Hei! Maksamatta! Tuu takasin!")
	Sfx.play("door", -1.0, 1.3)
	exited.emit(has_beer)


## Montako Alkon pulloa korissa.
func alko_count() -> int:
	var n := 0
	for k in cart:
		if String(k).begins_with("viina"):
			n += 1
	return n


## Alkon hylly vasemmalla seinällä: tummat hyllyt, kirkkaita ja ruskeita pulloja, kyltti ALKO.
func _build_alko() -> void:
	_alko = Node3D.new()
	add_child(_alko)
	var at := ALKO_SPOT + Vector3(-1.0, 0, 0)
	B.box(_alko, Vector3(0.7, 2.2, 3.6), at + Vector3(0, 1.1, 0), Color(0.18, 0.18, 0.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for hy in [0.55, 1.05, 1.55]:
		B.box(_alko, Vector3(0.75, 0.04, 3.5), at + Vector3(0.05, hy - 0.04, 0), Color(0.75, 0.75, 0.78), false)
		for k in 12:
			var col: Color = [Color(0.85, 0.92, 0.95, 1), Color(0.45, 0.25, 0.1), Color(0.2, 0.4, 0.2), Color(0.9, 0.9, 0.85)][rng.randi() % 4]
			var z := -1.6 + k * 0.29
			B.mesh(_alko, B.cyl(0.035, 0.045, 0.3, 8), at + Vector3(0.2, hy + 0.15, z), col)
			B.mesh(_alko, B.cyl(0.015, 0.02, 0.08, 6), at + Vector3(0.2, hy + 0.34, z), col.darkened(0.3))
	var sign := B.sign_plate(_alko, "ALKO", Color(0.75, 0.05, 0.12), Color.WHITE, 0.45, 80, Color.WHITE)
	sign.position = at + Vector3(0.3, 2.55, 0)
	sign.rotation.y = PI / 2.0


## Minkä tuotteen lokeron edessä pelaaja seisoo ("" = ei minkään).
func _shelf_section(p: Vector3) -> String:
	if p.x < SHELF_X - 1.8:
		return ""
	var i := floori(p.z - SHELF_Z0)
	return PRODUCTS.keys()[i] if i >= 0 and i < PRODUCTS.size() else ""


## Lokero: Q vaihtaa valittua väriä, E ottaa valitun kassiin, vaihtaa kassissa olevan tai palauttaa sen.
func _shelf_logic(prod: String, e: bool) -> void:
	var cols: Array = COLORS.keys()
	if Input.is_action_just_pressed("bell"):
		_sel[prod] = (_sel.get(prod, 0) + 1) % cols.size()
		Sfx.play("rattle", -14.0, 1.6)
	var col: String = cols[_sel.get(prod, 0)]
	_highlight(prod, col)
	var have: String = bag.get(prod, "")
	if have == col:
		hint = "[E] Palauta %s %s hyllyyn   [Q] vaihda väriä" % [col, prod]
	elif have != "":
		hint = "[E] Vaihda %s %s → %s   [Q] vaihda väriä" % [have, prod, col]
	else:
		hint = "[E] Ota %s %s   [Q] vaihda väriä" % [col, prod]
	if not e:
		return
	if have == col:
		bag.erase(prod)
		_update_carry()
		Sfx.play("pickup", -8.0, 0.7)
	else:
		bag[prod] = col
		walker.set_carrying(true)
		Sfx.play("pickup", -4.0, 1.2)


## Valittu väri nousee lokerossa esiin.
## Hyllyn kohdalla Q palauttaa viimeksi otetun tuotteen (items: tuote -> [nimi, hinta]).
func _return_logic(items: Dictionary) -> void:
	var last := ""
	for k in items:
		if cart.has(k):
			last = k
	if last == "":
		return
	hint += "   [Q] palauta %s" % items[last][0]
	if Input.is_action_just_pressed("bell"):
		cart.erase(last)
		_update_carry()
		Sfx.play("pickup", -8.0, 0.7)


## Kassi kädessä vain, jos siinä on jotain.
func _update_carry() -> void:
	walker.set_carrying(has_beer or not cart.is_empty() or not bag.is_empty())


func _highlight(prod: String, col: String) -> void:
	for p in _items:
		for c in _items[p]:
			var mi: MeshInstance3D = _items[p][c]
			var lift := 0.14 if p == prod and c == col else 0.0
			mi.position.y = mi.get_meta("y0") + lift
			mi.scale = Vector3.ONE * (1.4 if lift > 0.0 else 1.0)


func _total() -> float:
	var t := BEER_PRICE if has_beer else 0.0
	for k in cart:
		t += cart[k]
	return snappedf(t * price_mult, 0.01)


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


func _cashier_say(text: String, t := 2.0) -> void:
	_cashier_bubble.text = text
	_cashier_t = t
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
	# Leipähylly karkkitelineen vieressä: korvapuusteja ja lihapiirakoita.
	B.box(self, Vector3(1.0, 1.1, 0.5), BAKERY_SPOT + Vector3(0, 0.55, 1.2), Color(0.72, 0.55, 0.35))
	for i in 8:
		var bun := B.mesh(self, B.sphere(0.07, 8), BAKERY_SPOT + Vector3(-0.33 + (i % 4) * 0.22, 1.15, 1.08 + (i / 4) * 0.16),
			Color(0.82, 0.55, 0.25) if i < 4 else Color(0.62, 0.38, 0.18))
		bun.scale = Vector3(1.0, 0.55, 1.0) if i < 4 else Vector3(1.5, 0.5, 0.9)
	var bake_sign := B.sign_plate(self, "LEIPÄ", Color(0.8, 0.55, 0.2), Color.WHITE, 0.14, 26, Color.WHITE)
	bake_sign.position = BAKERY_SPOT + Vector3(0, 1.45, 1.4)
	# Karkkiteline etuseinää vasten kassan lähellä: suklaalevyjä kääreissään.
	B.box(self, Vector3(1.0, 1.1, 0.5), CANDY_SPOT + Vector3(0, 0.55, 1.2), Color(0.85, 0.88, 0.9))
	for i in 8:
		var wrap: Color = [Color(0.1, 0.25, 0.7), Color(0.45, 0.15, 0.5), Color(0.75, 0.1, 0.12)][i % 3]
		B.box(self, Vector3(0.2, 0.03, 0.1), CANDY_SPOT + Vector3(-0.33 + (i % 4) * 0.22, 1.13, 1.08 + (i / 4) * 0.14), wrap, false)
	# Kotiviinihylly: turbohiivapussit ja sokeripussit.
	B.box(self, Vector3(1.0, 1.1, 0.5), BREW_SPOT + Vector3(0, 0.55, 1.2), Color(0.82, 0.84, 0.86))
	for i in 8:
		var turbo := i < 4
		B.box(self, Vector3(0.14, 0.2 if turbo else 0.24, 0.1), BREW_SPOT + Vector3(-0.33 + (i % 4) * 0.22, 1.2, 1.08 + (i / 4) * 0.16),
			Color(0.15, 0.25, 0.6) if turbo else Color(0.95, 0.95, 0.93), false)
	var brew_sign := B.sign_plate(self, "KOTIVIINI", Color(0.45, 0.1, 0.3), Color.WHITE, 0.14, 26, Color.WHITE)
	brew_sign.position = BREW_SPOT + Vector3(0, 1.5, 1.4)
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


## Päivin hylly oikealla seinällä: lokero per tuote, kaikki värit rivissä, nimikyltti hyllyn reunassa.
func _build_paivi_shelf() -> void:
	var n := PRODUCTS.size()
	B.box(self, Vector3(0.8, 1.0, n), Vector3(SHELF_X, 0.5, SHELF_Z0 + n / 2.0), Color(0.85, 0.86, 0.88))
	var head := B.sign_plate(self, "PÄIVIN HYLLY", Color(0.75, 0.2, 0.35), Color.WHITE, 0.3, 48, Color.WHITE)
	head.position = Vector3(11.8, 2.4, SHELF_Z0 + n / 2.0)
	head.rotation.y = PI / 2.0
	var cols: Array = COLORS.keys()
	for i in n:
		var prod: String = PRODUCTS.keys()[i]
		var z := SHELF_Z0 + i + 0.5
		B.box(self, Vector3(0.84, 0.3, 0.03), Vector3(SHELF_X, 1.12, SHELF_Z0 + i), Color(0.7, 0.72, 0.74), false)
		var tag := B.sign_plate(self, prod.to_upper(), Color.WHITE, Color(0.1, 0.1, 0.1), 0.1, 22, Color(0.75, 0.2, 0.35))
		tag.position = Vector3(SHELF_X - 0.42, 0.85, z)
		tag.rotation.y = PI / 2.0
		_items[prod] = {}
		var size: Vector3 = PRODUCTS[prod] * 1.5
		for c in cols.size():
			var mi := B.mesh(self, B.boxm(size), Vector3(SHELF_X - 0.15, 1.0 + size.y / 2.0, z - 0.38 + c * 0.19), COLORS[cols[c]])
			mi.set_meta("y0", mi.position.y)
			_items[prod][cols[c]] = mi


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
	_cashier_bubble = B.bubble(self, Vector3(10.2, 2.3, 5.2), Color.WHITE, 0.7)
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
