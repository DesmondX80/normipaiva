extends CanvasLayer
## Räsytuppi naisen olohuoneessa (kolmiomittauksen iltakiva toisesta kerrasta alkaen, vain aikuisille). Säännöt ja
## tekoäly: tuppi.gd. Olohuone on Rasvanapin olohuone (rasvanappi_hall.gd, valot päällä) naisen talon yläpuolella
## omalla näkyvyyskerroksellaan; maton keskellä korttipöytä ja neljä jakkaraa. Pelaajat istuvat oikeina hahmoina
## (Looks.make, Sitting_Idle): pelaaja kameran puolella, nainen vastapäätä (pari), kaverit sivuilla.
## Ruudulla vain käyttöliittymä: oma käsi alareunassa, tilanne ylhäällä, kerronta laatikossa ja näppäinohje
## (hint_bar, näppäimet asetuksista). Pelatut kortit ovat 3D-kortteja pöydällä (vähän oikeaa isompia, jotta ne näkyvät).
## Räsysääntö: jaon hävinnyt pari riisuu (tuppi.gd RASY): kengät, paita (naisella rintaliivit jäävät), housut
## (kalsarit / pikkuhousut). Kalsareissa hävinnyt pari on pantu tuppeen, ja ilta päättyy (finished).

signal finished(result: Dictionary)

const Tuppi := preload("res://scripts/tuppi.gd")
const Hall := preload("res://scripts/rasvanappi_hall.gd")
const Rasva := preload("res://scripts/rasvanappi_game.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const Pose := preload("res://scripts/pose.gd")
const MG := preload("res://scripts/mg_draw.gd")

const CENTER := Vector3(6.0, 0.0, 3.6)  # pöydän keskipiste olohuoneessa (maton keskellä)
const TABLE_H := 0.72
const TABLE_W := 0.9
const LIFT := 0.08  # hahmo jakkaralla tämän verran ylempänä: Sitting_Idle-jalkaterät eivät mene lattiaan
const SEAT := 0.95  # lantion etäisyys pöydän keskeltä: jalkaterät jäävät pöydän alle erilleen (läpimenotesti)
const CARD := Vector2(0.12, 0.168)  # pöydän kortti (m): oikeaa (63 x 88 mm) isompi, jotta näkyy pelikameralta
const AI_DELAY := 0.75
const TRICK_PAUSE := 1.1
## Paikat myötäpäivään ylhäältä katsottuna (kamera +Z:n puolella): 0 pelaaja +Z, 1 vasen -X, 2 nainen -Z, 3 oikea +X.
const DIRS := [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)]

var site := "saloinen"
var anchor: Node3D
var sun: DirectionalLight3D
var style := {}
## [pelaajan ulkonäkö, vasen kaveri, nainen, oikea kaveri]: {"id", "name", "look"}
var seats: Array = []
## Rivot repliikit: {"rami": [...], "nolo": [...], "riisuu": {id: [vaiheittain]}, "voitto": [...], "tuppeen": [...]}
var lines := {}
var auto := false  # testi: tekoäly pelaa pelaajankin puolesta

var game := Tuppi.new()
var _hall: Node3D
var _cam: Camera3D
var _chars: Array = [null, null, null, null]
var _bubbles: Array = ["", "", "", ""]  # puhekuplan teksti paikoittain (piirretään käyttöliittymään puhujan pään kohdalle)
var _bubble_t := [0.0, 0.0, 0.0, 0.0]
var _table_cards: Array = []  # [MeshInstance3D, paikka]
var _piles: Array = [null, null, null, null]  # kädessä olevat kortit selkä ylöspäin pelaajan edessä
var _phase := "alku"  # alku, ilmoitus, peli, tikki, jako, loppu
var _t := 0.0
var _sel := 0
var _bid_sel := 0  # 0 rami, 1 nolo
var _result := {}
var _story := ""  # kerronta laatikossa
var _ui: Control
var _keys: Node
var _hand_rects: Array = []  # [Rect2, kortti] käyttöliittymän kortit hiiren osumaan


func _ready() -> void:
	layer = 6
	add_to_group("esc_lopettaa")
	game.rng.randomize()
	_build_room()
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui.draw.connect(_draw_ui)
	_ui.gui_input.connect(_on_ui_input)
	add_child(_ui)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_story = "Räsytuppi. Häviävä pari riisuu jaon jälkeen yhden vaatekappaleen. Kalsareissa hävinnyt pari pannaan tuppeen."
	_say(1, lines.get("alku", ["No niin, korttia."]).pick_random())
	_new_hand()


func _exit_tree() -> void:
	if is_instance_valid(_hall):
		_hall.queue_free()


# --- Olohuone, pöytä ja hahmot ------------------------------------------------------------------------------------

func _build_room() -> void:
	_hall = Hall.new()
	_hall.room = Rasva.ROOM
	_hall.door_y = Rasva.DOOR_Y
	_hall.style = style if not style.is_empty() else {"olohuone": true}
	anchor.get_parent().add_child(_hall)  # naisen talon kohta (kolmiomittaus) tai testin ankkuri
	_hall.top_level = true
	_hall.global_transform = Transform3D(Basis(), anchor.global_position + Vector3(0, 250, 0))
	_hall.build(Rasva.OBST, [], {}, sun)
	var wood := Color(0.55, 0.38, 0.22)
	# Korttipöytä: kansi reunalistoineen, vihreä huopa ja neljä jalkaa; jakkarat tikkuineen.
	B.mesh(_hall, B.boxm(Vector3(TABLE_W + 0.06, 0.04, TABLE_W + 0.06)), CENTER + Vector3(0, TABLE_H - 0.02, 0), wood)
	B.mesh(_hall, B.boxm(Vector3(TABLE_W - 0.04, 0.006, TABLE_W - 0.04)), CENTER + Vector3(0, TABLE_H + 0.002, 0), Color(0.12, 0.38, 0.2))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.mesh(_hall, B.boxm(Vector3(0.05, TABLE_H - 0.04, 0.05)), CENTER + Vector3(sx * (TABLE_W / 2.0 - 0.06), (TABLE_H - 0.04) / 2.0,
				sz * (TABLE_W / 2.0 - 0.06)), wood.darkened(0.15))
	# Pöydällä: kaljat ja tuhkakuppi (lämmin iltavalo pöydän yllä).
	B.mesh(_hall, B.cyl(0.033, 0.033, 0.12, 10), CENTER + Vector3(0.36, TABLE_H + 0.06, -0.34), Color(0.25, 0.4, 0.18))
	B.mesh(_hall, B.cyl(0.033, 0.033, 0.12, 10), CENTER + Vector3(-0.35, TABLE_H + 0.06, 0.33), Color(0.45, 0.25, 0.1))
	B.mesh(_hall, B.cyl(0.06, 0.05, 0.025, 12), CENTER + Vector3(-0.34, TABLE_H + 0.013, -0.33), Color(0.75, 0.75, 0.78))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.62)
	lamp.light_energy = 1.6
	lamp.omni_range = 3.2
	lamp.position = CENTER + Vector3(0, 2.0, 0.2)
	_hall.add_child(lamp)
	for s in 4:
		_seat_char(s)
		var pile := MeshInstance3D.new()
		_hall.add_child(pile)
		_piles[s] = pile
	# Jakkarat hahmojen alle: kansi pakaroiden kohdalla (lantion luu noin 10 cm istuinpinnan yllä), mitattu hahmosta.
	for s in 4:
		var c: Node3D = _chars[s]
		var pel: Vector3 = c.to_global(c.bone_position("pelvis"))
		var sh: float = _hall.to_local(pel).y - 0.1
		var d: Vector3 = DIRS[s]
		var sp := CENTER + d * (SEAT + 0.02)
		B.mesh(_hall, B.cyl(0.19, 0.19, 0.05, 16), sp + Vector3(0, sh - 0.025, 0), wood.lightened(0.1))
		for k in 3:
			var a := TAU * k / 3.0
			B.mesh(_hall, B.cyl(0.018, 0.022, sh - 0.05, 6), sp + Vector3(cos(a) * 0.13, (sh - 0.05) / 2.0, sin(a) * 0.13),
				wood.darkened(0.2))
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.cull_mask = Hall.LAYER
	_cam.environment = _hall._env
	_hall.add_child(_cam)
	_frame_cam()
	_cam.current = true
	_hall._set_layers(_hall)


## Hahmo jakkaralle paikalle s kasvot pöytään: lantio jakkaran kohdalle (bar_game.gd _seat).
func _seat_char(s: int) -> void:
	if _chars[s] != null:
		(_chars[s] as Node).queue_free()
	var info: Dictionary = seats[s]
	var c := Looks.make(_hall, rasy_look(info.look, game.rasy[Tuppi.team(s)]))
	var d: Vector3 = DIRS[s]
	c.rotation.y = atan2(d.x, d.z)  # hahmon eteenpäin on -Z (bar_game.gd _seat): kasvot pöytää kohti
	c.play("Sitting_Idle", 0.0)
	c.anim.advance(0.01)
	var pel: Vector3 = c.basis * c.bone_position("pelvis")
	var sp := CENTER + d * SEAT
	c.position = Vector3(sp.x - pel.x, LIFT, sp.z - pel.z)
	_chars[s] = c
	_hall._set_layers(c)


## Kamera pelaajan oikean olan yli: pöytä keskelle (enintään 62 % ruudun leveydestä), naisen pää ruudulle ja oma pää
## vasempaan alakulmaan, jottei se peitä pöydän keskustaa (lasketaan projisoimalla, korkkiläpsyn _frame_cam-malli).
func _frame_cam() -> void:
	var vs := get_viewport().get_visible_rect().size
	var top := CENTER + Vector3(0, TABLE_H, 0)
	var head2 := CENTER + Vector3(0, LIFT + 1.25, -SEAT)  # naisen pää vastapäätä
	var aim := CENTER + Vector3(0, TABLE_H + 0.22, -0.18)
	for i in 30:
		var dist := 0.95 + i * 0.05
		var eye := CENTER + Vector3(0.42, TABLE_H + 0.95 + dist * 0.35, dist)
		_cam.transform = Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye)  # olohuoneen kehyksessä
		var l := _cam.unproject_position(_hall.to_global(top + Vector3(-TABLE_W / 2.0, 0, 0)))
		var r := _cam.unproject_position(_hall.to_global(top + Vector3(TABLE_W / 2.0, 0, 0)))
		var h := _cam.unproject_position(_hall.to_global(head2))
		if r.x - l.x <= vs.x * 0.62 and h.y > vs.y * 0.1:
			break


# --- Riisuminen ---------------------------------------------------------------------------------------------------

## Ulkonäkö riisumisvaiheessa 0–3 (tuppi.gd RASY): 1 sukkasillaan, 2 paidatta (nainen rintaliiveissä), 3 kalsareissa.
static func rasy_look(base: Dictionary, stage: int) -> Dictionary:
	var look: Dictionary = base.duplicate(true)
	if stage <= 0:
		return look
	var woman := String(look.get("model", "male")) == "female"
	var skin: Color = look.get("skin", Color(0.96, 0.78, 0.66))
	var k: float = float(look.get("height", 1.76)) / 1.76  # lepoasennon korkeudet suhteessa pituuteen
	look["shoe"] = "paljas"
	look["shoes"] = Color(0.93, 0.93, 0.9) if not woman else skin  # miehillä valkoiset tennissukat
	look.erase("shoe_rough")
	if stage >= 2:
		for key in ["tracksuit", "net_shirt", "suspenders", "flannel", "chain", "shirt_puff", "vest_open", "ski_suit", "glam",
				"sleeve_x", "crop_y", "tube_y"]:
			look.erase(key)
		look["bare_skin"] = skin
		if woman:
			look["shirt"] = Color(0.85, 0.08, 0.2)  # punaiset rintaliivit: kapea kaistale rinnan kohdalla
			look["crop_y"] = 1.2 * k
			look["tube_y"] = 1.37 * k
		else:
			look["tube_y"] = 0.01  # paljas yläkroppa (kuten saunassa)
	if stage >= 3:
		for key in ["jeans", "denim", "workwear", "belt_y", "pants_puff", "skirt", "gown"]:
			look.erase(key)
		look["pants"] = Color(0.85, 0.08, 0.2) if woman else Color(0.92, 0.92, 0.95)
		look["shorts_y"] = (0.86 if woman else 0.8) * k
		look["stripes"] = false
	return look


# --- Pelin kulku ------------------------------------------------------------------------------------------------

func _new_hand() -> void:
	game.new_hand()
	_clear_table()
	_phase = "ilmoitus"
	_t = 0.0
	_sel = 0
	_bid_sel = 0 if game.strength(0) >= 15 else 1
	_update_piles()
	_ui.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	for s in 4:
		if _bubble_t[s] > 0.0:
			_bubble_t[s] -= delta
			if _bubble_t[s] <= 0.0:
				_bubbles[s] = ""
				_ui.queue_redraw()
	if Input.is_action_just_pressed("mount") and _phase != "loppu":
		_finish({"luovutti": true})
		return
	match _phase:
		"ilmoitus":
			_bidding()
		"peli":
			_playing()
		"tikki":
			if _t > TRICK_PAUSE:
				_collect_trick()
		"jako":
			if _pressed() or (auto and _t > 1.5):
				if _result.get("tuppeen", false):
					_phase = "loppu"
					_t = 0.0
					_end_texts()
				else:
					_new_hand()
		"loppu":
			if _pressed() or (auto and _t > 1.5):
				var won: bool = int(_result.haviaja) == 1
				_finish({"voitto": won, "jaot": game.points, "rasy": game.rasy})
	_update_keys()
	_ui.queue_redraw()


func _pressed() -> bool:
	return Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")


func _bidding() -> void:
	var b := game.next_bidder()
	if b < 0:
		_phase = "peli"
		_t = 0.0
		_story = "%s! %s" % ["RAMI" if game.mode == "rami" else "NOLO", ("%s ramasi: parin pitää saada 7 tikkiä." % _nimi(game.ramaaja))
			if game.mode == "rami" else "Kukaan ei ramannut: vähemmän tikkejä ottanut pari voittaa."]
		_say(game.leader if game.leader != 0 else 2, lines.get(game.mode, ["No niin."]).pick_random())
		return
	if b == 0 and not auto:
		if Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right"):
			_bid_sel = 1 - _bid_sel
		if _pressed():
			_do_bid(0, "rami" if _bid_sel == 0 else "nolo")
		return
	if _t > AI_DELAY:
		_do_bid(b, game.ai_bid(b))


func _do_bid(s: int, what: String) -> void:
	game.bid(s, what)
	_say(s, "Rami!" if what == "rami" else "Nolo.")
	Sfx.play("cloth", -12.0, 1.4)
	_t = 0.0


func _playing() -> void:
	var s := game.to_play()
	if s == 0 and not auto:
		var hand: Array = game.hands[0]
		_sel = clampi(_sel, 0, hand.size() - 1)
		if Input.is_action_just_pressed("left"):
			_sel = maxi(0, _sel - 1)
		if Input.is_action_just_pressed("right"):
			_sel = mini(hand.size() - 1, _sel + 1)
		if _pressed() and hand[_sel] in game.legal(0):
			_play(0, hand[_sel])
		return
	if _t > AI_DELAY:
		_play(s, game.ai_card(s))


func _play(s: int, c: int) -> void:
	var before := game.trick.size()
	var w := game.play(s, c)
	_t = 0.0
	_place_card(s, c, before)
	Sfx.play("cloth", -8.0, randf_range(1.6, 1.9))
	_update_piles()
	if w >= 0:
		_phase = "tikki"
		if randf() < 0.35:
			_say(w, _trick_line(w))


func _collect_trick() -> void:
	var w := game.last_trick_winner
	var to: Vector3 = _hall.to_global(CENTER + (DIRS[w] as Vector3) * 0.5 + Vector3(0, TABLE_H + 0.01, 0))
	for e: Array in _table_cards:
		var m: MeshInstance3D = e[0]
		var tw := m.create_tween()
		tw.tween_property(m, "global_position", to, 0.35)
		tw.tween_callback(m.queue_free)
	_table_cards.clear()
	Sfx.play("whoosh", -14.0, 1.6)
	_t = 0.0
	if game.hand_over():
		_end_hand()
	else:
		_phase = "peli"


func _end_hand() -> void:
	_result = game.settle()
	_phase = "jako"
	_t = 0.0
	var me_won: bool = int(_result.voittaja) == 0
	var lt: int = _result.haviaja
	var who := "Te" if lt == 0 else "%s ja %s" % [seats[1].name, seats[3].name]
	_story = "Jako %s: %s. Tikit %d–%d, %s %d p.%s" % ["voitettu" if me_won else "hävitty",
		"rami ryöstettiin" if _result.ryosto else game.mode, game.tricks[0], game.tricks[1],
		"te saitte" if me_won else "he saivat", _result.pisteet, "" if _result.tuppeen else
		"  %s: %s." % [who, Tuppi.RASY[game.rasy[lt]]]]
	if _result.tuppeen:
		_story = "%s %s PANTU TUPPEEN!" % [_story, who.to_upper()]
		Sfx.play("lose" if lt == 0 else "win", -4.0)
		return
	# Hävinnyt pari riisuu: hahmot uudelleen riisuttuina ja kummallekin oma repliikki.
	Sfx.play("cloth", -2.0, 0.9)
	for s in [lt, lt + 2]:
		_seat_char(s)
		var r: Dictionary = lines.get("riisuu", {})
		var own: Array = r.get(String(seats[s].id), [])
		var st: int = game.rasy[lt]
		if st - 1 < own.size():
			_say(s, own[st - 1])
	var other := 1 - lt
	_say(other if randf() < 0.5 else other + 2, lines.get("kommentti", ["Hehe."]).pick_random())


func _end_texts() -> void:
	var won: bool = int(_result.haviaja) == 1
	_story = (lines.get("voitto", ["Kaverit tupessa!"]) if won else lines.get("tuppeen", ["Te tupessa!"])).pick_random()
	_say(2, lines.get("loppu", ["No niin. Nukkumaan."]).pick_random())


func _finish(r: Dictionary) -> void:
	if _phase == "valmis":
		return
	_phase = "valmis"
	finished.emit(r)
	queue_free()


# --- Kortit pöydällä ----------------------------------------------------------------------------------------------

func _card_mesh(c: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = B.boxm(Vector3(CARD.x, 0.003, CARD.y))
	m.material_override = B.mat(Color(0.97, 0.96, 0.92))
	var red := Tuppi.suit(c) == 1 or Tuppi.suit(c) == 2
	var l := Label3D.new()
	l.text = Tuppi.kortti(c)
	l.font_size = 64
	l.pixel_size = 0.0009
	l.outline_size = 0
	l.modulate = Color(0.8, 0.05, 0.08) if red else Color(0.05, 0.05, 0.08)
	l.rotation = Vector3(-PI / 2.0, 0, 0)
	l.position = Vector3(0, 0.003, 0)
	m.add_child(l)
	return m


func _place_card(s: int, c: int, order: int) -> void:
	var m := _card_mesh(c)
	_hall.add_child(m)
	var d: Vector3 = DIRS[s]
	var target := CENTER + d * 0.15 + Vector3(0, TABLE_H + 0.006 + order * 0.004, 0)
	m.position = CENTER + d * 0.55 + Vector3(0, TABLE_H + 0.1, 0)
	m.rotation.y = randf_range(-0.25, 0.25)  # teksti pelaajan (kameran) suuntaan luettavaksi
	var tw := m.create_tween()
	tw.tween_property(m, "position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_table_cards.append([m, s])
	_hall._set_layers(m)


func _clear_table() -> void:
	for e: Array in _table_cards:
		(e[0] as Node).queue_free()
	_table_cards.clear()


## Kädessä olevat kortit pinona pelaajan edessä pöydällä (selkä ylöspäin, korkeus korttien määrän mukaan).
func _update_piles() -> void:
	for s in 4:
		var n: int = game.hands[s].size()
		var pile: MeshInstance3D = _piles[s]
		pile.visible = n > 0 and s != 0
		if n == 0:
			continue
		pile.mesh = B.boxm(Vector3(CARD.x * 0.8, 0.002 * n, CARD.y * 0.8))
		pile.material_override = B.mat(Color(0.65, 0.12, 0.15))
		var d: Vector3 = DIRS[s]
		pile.position = CENTER + d * 0.34 + Vector3(0, TABLE_H + 0.001 * n, 0)
		pile.rotation.y = atan2(d.x, d.z)
		_hall._set_layers(pile)


# --- Puhe ja nimet ------------------------------------------------------------------------------------------------

func _nimi(s: int) -> String:
	return "Sinä" if s == 0 else String(seats[s].name)


func _say(s: int, text: String) -> void:
	if s == 0:
		return
	_bubbles[s] = "%s: %s" % [seats[s].name, text]
	_bubble_t[s] = 3.2
	if _ui != null:
		_ui.queue_redraw()


func _trick_line(w: int) -> String:
	var own: Array = lines.get("tikki", {}).get(String(seats[w].id), []) if w != 0 else []
	return own.pick_random() if not own.is_empty() else "Mun."


# --- Käyttöliittymä -----------------------------------------------------------------------------------------------

func _update_keys() -> void:
	match _phase:
		"ilmoitus":
			_keys.set_text("%s rami / nolo   %s näytä   %s lopeta" % [Settings.pair("left", "right"), Settings.cap("interact"),
				Settings.cap("mount")] if game.next_bidder() == 0 else "%s lopeta" % Settings.cap("mount"))
		"peli":
			_keys.set_text("%s valitse kortti   %s pelaa   [Hiiri] klikkaa korttia   %s lopeta" % [Settings.pair("left", "right"),
				Settings.cap("interact"), Settings.cap("mount")] if game.to_play() == 0 else "%s lopeta" % Settings.cap("mount"))
		"jako", "loppu":
			_keys.set_text("%s jatka   %s lopeta" % [Settings.cap("interact"), Settings.cap("mount")])
		_:
			_keys.set_text("")


func _on_ui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if _phase == "peli" and game.to_play() == 0:
		for i in range(_hand_rects.size() - 1, -1, -1):
			var hr: Array = _hand_rects[i]
			if (hr[0] as Rect2).has_point(ev.position) and hr[1] in game.legal(0):
				_sel = i
				_play(0, hr[1])
				return
	elif _phase == "ilmoitus" and game.next_bidder() == 0:
		_do_bid(0, "rami" if ev.position.x < _ui.size.x / 2.0 else "nolo")


## Puhekuplat: laatikko puhujan pään yläpuolelle (projisoitu), rajattuna ruudun sisään ja tilannepalkin alle; nokka
## osoittaa puhujan päähän.
func _draw_bubbles(vs: Vector2) -> void:
	var font := ThemeDB.fallback_font
	for s in range(1, 4):
		if _bubbles[s] == "" or _chars[s] == null:
			continue
		var c: Node3D = _chars[s]
		var head := _cam.unproject_position(c.to_global(c.bone_position("Head")) + Vector3(0, 0.12, 0))
		var tw := font.get_string_size(_bubbles[s], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var w := minf(tw + 28.0, 360.0)
		var lines := clampi(ceili(tw * 1.08 / (w - 28.0)), 1, 3)
		var h := 22.0 * lines + 18.0
		var r := Rect2(head.x - w / 2.0, head.y - h - 34.0, w, h)
		r.position.x = clampf(r.position.x, 10.0, vs.x - w - 10.0)
		r.position.y = clampf(r.position.y, 136.0 if _story != "" else 64.0, vs.y - h - 200.0)
		var tail := head if head.y > r.end.y + 8.0 else Vector2(head.x, r.end.y + 24.0)
		MG.bubble(_ui, r, tail, "", 18)
		_ui.draw_multiline_string(font, r.position + Vector2(14, 27), _bubbles[s], HORIZONTAL_ALIGNMENT_CENTER, w - 28.0, 18,
			lines, Color(0.1, 0.08, 0.06))


func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	# Tilanne ylhäällä: pelimuoto, tikit ja kummankin parin riisumisvaihe.
	var top := "%s   Tikit: te %d – %s ja %s %d   Te: %s   He: %s" % [game.mode.to_upper() if game.mode != "" else "ILMOITUS",
		game.tricks[0], seats[1].name, seats[3].name, game.tricks[1], Tuppi.RASY[game.rasy[0]], Tuppi.RASY[game.rasy[1]]]
	_box(Rect2(vs.x / 2.0 - 430, 14, 860, 40), Color(0, 0, 0, 0.55))
	_ui.draw_string(font, Vector2(vs.x / 2.0 - 420, 42), top, HORIZONTAL_ALIGNMENT_CENTER, 840, 20, Color.WHITE)
	# Kerronta laatikossa.
	if _story != "" and _phase in ["ilmoitus", "jako", "loppu"]:
		var r := Rect2(vs.x / 2.0 - 420, 62, 840, 64)
		_box(r, Color(0.05, 0.04, 0.03, 0.8))
		_ui.draw_multiline_string(font, r.position + Vector2(16, 26), _story, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 18, 2,
			Color(1.0, 0.92, 0.75))
	_draw_bubbles(vs)
	# Ilmoitusvalinta.
	if _phase == "ilmoitus" and game.next_bidder() == 0 and not auto:
		for i in 2:
			var r := Rect2(vs.x / 2.0 - 230 + i * 240, vs.y - 330, 220, 70)
			_box(r, (Color(0.75, 0.1, 0.12) if i == 0 else Color(0.1, 0.1, 0.12)).lightened(0.15 if i == _bid_sel else 0.0))
			if i == _bid_sel:
				_ui.draw_rect(r.grow(3), Color(1, 0.9, 0.4), false, 3.0)
			_ui.draw_string(font, r.position + Vector2(0, 30), "RAMI" if i == 0 else "NOLO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26,
				Color.WHITE)
			_ui.draw_string(font, r.position + Vector2(0, 56), "otetaan 7+ tikkiä" if i == 0 else "vältetään tikkejä",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color(1, 1, 1, 0.8))
	# Oma käsi alareunassa: sallitut kortit kirkkaina, valittu nostettuna.
	_hand_rects.clear()
	var hand: Array = game.hands[0]
	if hand.is_empty():
		return
	var cw := 64.0
	var gap := minf(54.0, (vs.x - 200.0) / maxf(1.0, hand.size()))
	var x0 := vs.x / 2.0 - (gap * (hand.size() - 1) + cw) / 2.0
	var legal := game.legal(0) if game.to_play() == 0 and _phase == "peli" else []
	for i in hand.size():
		var c: int = hand[i]
		var up := 18.0 if i == _sel and _phase == "peli" and game.to_play() == 0 else 0.0
		var r := Rect2(x0 + i * gap, vs.y - 170 - up, cw, 92)
		_hand_rects.append([r, c])
		var dim: bool = _phase == "peli" and game.to_play() == 0 and not c in legal
		_ui.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.35))
		_ui.draw_rect(r, Color(0.97, 0.96, 0.92) if not dim else Color(0.6, 0.6, 0.58))
		_ui.draw_rect(r, Color(0.2, 0.2, 0.2), false, 1.5)
		var red := Tuppi.suit(c) == 1 or Tuppi.suit(c) == 2
		var ink := Color(0.8, 0.05, 0.08) if red else Color(0.05, 0.05, 0.08)
		_ui.draw_string(font, r.position + Vector2(6, 24), Tuppi.kortti(c), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
		_ui.draw_string(font, r.position + Vector2(0, 70), Tuppi.MAAT[Tuppi.suit(c)], HORIZONTAL_ALIGNMENT_CENTER, cw, 34, ink)


func _box(r: Rect2, col: Color) -> void:
	_ui.draw_rect(r, col)
	_ui.draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)
