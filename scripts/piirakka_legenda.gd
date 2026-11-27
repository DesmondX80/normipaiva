extends CanvasLayer
## Legendaarinen hetki "piirakkakuningas" (Lihapiirakkakuningas): Juntin ennätyksen ensimmäinen rikkominen Reipparin
## lihapiirakkahaasteessa lavastetaan kioskin pihapöydässä (piirakka_game.gd käynnistää haasteen lopussa). Vaiheet:
##   lasku    viimeinen pala suuhun, koko pöytä huutaa luvun, kuningas nojaa taakse kädet vatsalla (laaja kuva pöydän päästä)
##   paperit  Juntti tulee pöydän päähän ja laskee rypistetyt piirakkapaperit sormella yksi kerrallaan
##   mitta    "Ne oli pienempiä!" Juntti mittaa Raijan tuoman piirakan rullamitalla: 23 cm, niinku aina
##   taulu    Raija vetää tussilla viivan Juntin nimen yli ja teippaa alle lapun, johon kirjoittaa uuden nimen
##   royhtays Juntti vaatii uusintaa naama kuninkaan naamassa, kuningas röyhtäisee sipulipilven, Juntti perääntyy
##   otsikko  kuningas taulun vieressä nyrkki ylhäällä, Juntti kädet puuskassa, kultainen LIHAPIIRAKKAKUNINGAS
## Kaikki koordinaatit ovat kioskin kehyksessä (game = piirakka_game.gd, world.reippari_root): -Z = julkisivu tielle,
## ennätystaulu julkisivussa (2.2, 1.6, -2.1), penkkipöytä (4.8, 0.75, -3.8). Hahmojen etu on -Z (Looks/character.gd).

signal finished

const B := preload("res://scripts/build.gd")
const Pose := preload("res://scripts/pose.gd")
const Room := preload("res://scripts/ilta_room.gd")
const Looks := preload("res://scripts/looks.gd")
const PiirakkaGame := preload("res://scripts/piirakka_game.gd")

const RATE := 22050.0
const ORDER := ["lasku", "paperit", "mitta", "taulu", "royhtays", "otsikko"]
const TABLE_Y := 0.79  # pöydän pinta
const SEAT := Vector3(5.5, 0.0, -3.17)  # pelaajan paikka lähemmällä penkillä, katse -Z (pöytään)
const PIE_AT := Vector3(5.47, TABLE_Y + 0.004, -3.98)  # Raijan tuoma vertailupiirakka pöydän päässä, pituus Z:n suuntaan
const BOARD := Vector3(2.2, 1.6, -2.1)  # ennätystaulun keskipiste (world.gd _build_reippari)
const PAPER_COL := Color(0.96, 0.94, 0.87)  # rasvapaperi
const WORDS := ["Yks", "Kaks", "Kolme", "Neljä", "Viis", "Kuus", "Seittemän", "Kaheksan", "Yheksän", "Kymmenen",
	"Yksitoista", "Kakstoista", "Kolmetoista", "Neljätoista", "Viistoista"]
## Juntin muistot seuraavissa haasteissa (piirakka_game.gd recall): mittaus ja paperit jäivät mieleen.
const MUISTO := [["juntti", "Mää mittasin ne piirakat viimeks. En silti usko."],
	["raija", "Kuningas tuli puolustaan ennätystä!"],
	["juntti", "Tänään mää lasken paperit ite."]]

var game: Node3D  # piirakka_game.gd (kioskin kehys)
var people := {}  # game._people: raija, reiska, juntti, rekka, mummo
var apron: Node3D  # Reiskan esiliina (game._apron)
var pies := 8
var phase := ""
var _t := 0.0
var _dur := {}
var _cam: Camera3D
var _ui: Control
var _keys: Node
var _story := ""
var _bub := {}  # hahmo -> repliikki
var _once := {}
var _me: Node3D  # pelaajan hahmo (Looks.player)
var _papers: Array[Node3D] = []
var _piece: Node3D  # viimeinen pala pelaajan kädessä
var _pie: Node3D  # vertailupiirakka
var _tape_case: Node3D
var _tape: Node3D
var _hook: Node3D
var _marker: Node3D
var _strike: MeshInstance3D
var _note: Node3D  # lappu taulun alla
var _note_lab: Label3D
var _plate: Node3D
var _cloud: Array = []  # sipulipilvi [paikka, nopeus, ikä]
var _crumbs: Array = []  # paperin hyppy laskiessa
var _sfx: AudioStreamPlayer
var _shake := 0.0
var _orig := {}  # hahmo -> [paikka, kulma, animaatio]
var _note_text := ""


func _ready() -> void:
	layer = 7
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_keys.set_text("%s ohita" % Settings.cap("interact"))
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "SFX"
	add_child(_sfx)
	_dur = {"lasku": 3.8, "paperit": 0.5 + pies * 0.42 + 1.9, "mitta": 5.2, "taulu": 5.6, "royhtays": 4.6, "otsikko": 6.0}
	_note_text = "Järvikuja 1 — %d" % pies
	for k in people:
		var c: Node3D = people[k]
		_orig[c] = [c.position, c.rotation.y, c.get_meta("pose", "Idle")]
	if apron != null:
		apron.visible = false  # irrallinen esiliinalevy näyttää kohtauksen lähikuvissa kyltiltä
	_cam = Camera3D.new()
	game.add_child(_cam)
	_cam.current = true
	_build_props()
	_begin("lasku")


func _exit_tree() -> void:
	for n in [_cam, _me, _pie, _tape_case, _tape, _hook, _strike, _note, _plate]:
		if is_instance_valid(n):
			n.queue_free()
	for p in _papers:
		if is_instance_valid(p):
			p.queue_free()


# --- Rekvisiitta --------------------------------------------------------------------

func _build_props() -> void:
	# Pelaaja penkille (Sitting_Idle, lantio penkin päälle kuten piirakka_game.gd _person).
	_me = Looks.make(game, Looks.player())
	_seat_me()
	# Viimeinen pala oikeassa kädessä: piirakan pää samoista paloista kuin haasteessa.
	_piece = Node3D.new()
	var s := Node3D.new()
	_piece.add_child(s)
	PiirakkaGame._pie_slice(s, 0, -1)
	_me.attach("hand_r", _piece, Vector3(0.0, 0.06, 0.02))
	_piece.rotation = Vector3(0.0, 0.0, PI / 2.0)
	# Tyhjä lautanen murusineen pöydän vasemmalle puolelle (haasteen lautanen piiloon).
	_plate = Node3D.new()
	game.add_child(_plate)
	_plate.position = Vector3(4.82, TABLE_Y, -3.66)
	B.mesh(_plate, B.cyl(0.2, 0.17, 0.02, 20), Vector3(0, 0.01, 0), Color(0.97, 0.97, 0.95))
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	for i in 14:
		var crumb := B.mesh(_plate, B.boxm(Vector3(0.01, 0.006, 0.009) * rng.randf_range(0.7, 1.4)),
			Vector3(rng.randf_range(-0.13, 0.13), 0.023, rng.randf_range(-0.13, 0.13)), PiirakkaGame.BUN.lightened(rng.randf_range(0.0, 0.3)))
		crumb.rotation.y = rng.randf() * TAU
	for i in 3:  # ketsuppi- ja sinappijäljet
		var smear := B.mesh(_plate, B.cyl(0.018, 0.018, 0.002, 10), Vector3(rng.randf_range(-0.1, 0.1), 0.021, rng.randf_range(-0.1, 0.1)),
			PiirakkaGame.KETCHUP if i != 1 else PiirakkaGame.MUSTARD)
		smear.scale = Vector3(1.8, 1.0, 0.8)
	# Rypistetyt piirakkapaperit kahteen riviin kuninkaan eteen (yksi paperi = yksi piirakka).
	for i in pies:
		_papers.append(_paper(i))
	# Vertailupiirakka paperin päällä pöydän päässä (pituus Z:n suuntaan: Juntti mittaa sen poikittain edestään).
	_pie = Node3D.new()
	game.add_child(_pie)
	_pie.position = PIE_AT
	_pie.rotation.y = PI / 2.0
	var nap := B.mesh(_pie, B.boxm(Vector3(0.3, 0.003, 0.16)), Vector3(0, -0.002, 0), PAPER_COL)
	nap.rotation.y = 0.08
	for k in PiirakkaGame.BITES:
		var sl := Node3D.new()
		sl.position = Vector3(-0.084 + k * 0.042, 0, 0)
		_pie.add_child(sl)
		PiirakkaGame._pie_slice(sl, k, -1 if k == 0 else (1 if k == PiirakkaGame.BITES - 1 else 0))
	_pie.visible = false
	# Rullamitta: keltainen kotelo mustin kyljin, teräsnauha mittamerkein ja koukku.
	_tape_case = Node3D.new()
	game.add_child(_tape_case)
	var yel := Color(0.98, 0.78, 0.08)
	var body := B.mesh(_tape_case, B.boxm(Vector3(0.075, 0.072, 0.034)), Vector3.ZERO, yel)
	body.material_override = PiirakkaGame._gloss(yel, 0.35)
	for z in [-0.018, 0.018]:
		B.mesh(_tape_case, B.cyl(0.026, 0.026, 0.004, 16), Vector3(0, 0, z), Color(0.08, 0.08, 0.09), Vector3(90, 0, 0))
		B.mesh(_tape_case, B.cyl(0.008, 0.008, 0.006, 10), Vector3(0, 0, z * 1.15), Color(0.75, 0.75, 0.78), Vector3(90, 0, 0))
	B.mesh(_tape_case, B.boxm(Vector3(0.022, 0.03, 0.036)), Vector3(0.03, 0.03, 0), Color(0.12, 0.12, 0.13))  # lukitusnappi
	_tape_case.visible = false
	_tape = Node3D.new()
	game.add_child(_tape)
	var strip := B.mesh(_tape, B.boxm(Vector3(1.0, 0.0025, 0.02)), Vector3(0.5, 0, 0), Color(0.98, 0.84, 0.15))
	strip.name = "Nauha"
	for i in 50:  # mittamerkit 2 cm välein, joka viides pidempi
		var tick := B.mesh(_tape, B.boxm(Vector3(0.0018, 0.003, 0.012 if i % 5 == 0 else 0.006)), Vector3(i * 0.02, 0.0005, -0.004), Color(0.05, 0.05, 0.05))
		tick.set_meta("x", i * 0.02)
	_tape.visible = false
	_hook = Node3D.new()
	game.add_child(_hook)
	B.mesh(_hook, B.boxm(Vector3(0.004, 0.03, 0.022)), Vector3(0, -0.012, 0), Color(0.78, 0.78, 0.82))
	_hook.visible = false
	# Tussi Raijan käteen (piiloon, kunnes taulu).
	_marker = Node3D.new()
	B.mesh(_marker, B.cyl(0.009, 0.009, 0.13, 10), Vector3.ZERO, Color(0.95, 0.95, 0.95))
	B.mesh(_marker, B.cyl(0.0095, 0.0095, 0.04, 10), Vector3(0, 0.055, 0), Color(0.1, 0.25, 0.75))  # korkki
	B.mesh(_marker, B.cyl(0.003, 0.006, 0.014, 8), Vector3(0, -0.071, 0), Color(0.1, 0.25, 0.75))  # kärki
	(people.raija as Node3D).attach("hand_r", _marker, Vector3(0, 0.07, 0.03))
	_marker.visible = false


## Rypistetty rasvapaperi: muutama vinottain limittäinen pala (rypyt), rasvatäplä ja ketsuppitahra.
func _paper(i: int) -> Node3D:
	var p := Node3D.new()
	game.add_child(p)
	p.position = _paper_at(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41 + i * 13
	for k in 5:
		var col := PAPER_COL.darkened(rng.randf_range(0.0, 0.12))
		var m := B.mesh(p, B.boxm(Vector3(0.056, 0.04, 0.048) * rng.randf_range(0.8, 1.1)),
			Vector3(rng.randf_range(-0.016, 0.016), 0.028 + rng.randf_range(-0.008, 0.008), rng.randf_range(-0.016, 0.016)), col)
		m.rotation = Vector3(rng.randf_range(-0.9, 0.9), rng.randf() * TAU, rng.randf_range(-0.9, 0.9))
	var spot := B.mesh(p, B.sphere(0.015, 8), Vector3(0.015, 0.052, 0.01), Color(0.85, 0.68, 0.42))
	spot.scale = Vector3(1.0, 0.25, 0.8)
	var ket := B.mesh(p, B.sphere(0.01, 8), Vector3(-0.018, 0.048, -0.013), PiirakkaGame.KETCHUP)
	ket.scale = Vector3(1.2, 0.3, 0.9)
	return p


## Paperien paikat: kaksi riviä pöydän päästä kuninkaan eteen (Juntti ulottuu niihin pöydän päästä).
func _paper_at(i: int) -> Vector3:
	var cols := ceili(pies / 2.0)
	var col := i % cols
	var row := i / cols
	return Vector3(5.52 - col * 0.11, TABLE_Y, -3.53 - row * 0.14)


func _seat_me() -> void:
	_me.rotation.y = 0.0
	_me.play("Sitting_Idle", 0.0)
	_me.anim.advance(0.01)
	var pelvis: Vector3 = _me.basis * _me.bone_position("pelvis")
	_me.position = SEAT + Vector3(-pelvis.x, 0.02, -pelvis.z)


# --- Vaiheet --------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_once.clear()
	_bub.clear()
	var j: Node3D = people.juntti
	var raija: Node3D = people.raija
	match p:
		"lasku":
			_story = "Viimeinen pala lähtee. Koko pöytä laskee ääneen."
			for k in people:
				var c: Node3D = people[k]
				c.rotation.y = B.yaw_to(_flat(SEAT - c.position))
			Sfx.play("pickup", -10.0, 0.7)
		"paperit":
			_story = "Juntti ei usko. Hän laskee piirakkapaperit itse."
			_piece.visible = false
			_me.clear_ik()
			j.clear_ik()
			j.position = Vector3(5.88, 0, -3.6)
			j.rotation.y = B.yaw_to(Vector3(-1, 0, 0))
			j.play("Idle", 0.1)
			# Raija ja Reiska siirtyvät Juntin taakse katsomaan (vastapäinen puoli jää kameralle).
			raija.position = Vector3(6.35, 0, -4.15)
			raija.rotation.y = B.yaw_to(_flat(_paper_at(0) - raija.position))
			var rk: Node3D = people.reiska
			rk.position = Vector3(6.45, 0, -3.15)
			rk.rotation.y = B.yaw_to(_flat(_paper_at(0) - rk.position))
			Sfx.play("step_hard", -10.0, 0.9)
		"mitta":
			_story = "\"Ne oli pienempiä!\" Raija tuo vertailupiirakan, Juntti kaivaa rullamitan."
			for pp in _papers:
				pp.position = _paper_at(_papers.find(pp))
			j.clear_ik()
			j.clear_overrides()
			j.play("Idle", 0.15)
			j.position = Vector3(5.8, 0, PIE_AT.z)
			j.rotation.y = B.yaw_to(Vector3(-1, 0, 0))
			raija.position = Vector3(5.95, 0, -4.5)
			raija.rotation.y = B.yaw_to(_flat(PIE_AT - raija.position))
			raija.play("Idle", 0.1)
			_pie.visible = true
			_tape_case.visible = true
			_tape.visible = true
			_hook.visible = true
			Sfx.play("rattle", -14.0, 2.0)
		"taulu":
			_story = "Raija vetää tussilla viivan Juntin yli ja teippaa alle lapun."
			j.clear_ik()
			_tape_case.visible = false
			_tape.visible = false
			_hook.visible = false
			raija.clear_ik()
			raija.position = Vector3(2.7, 0, -2.52)
			raija.rotation.y = B.yaw_to(Vector3(0, 0, 1))  # kasvot taululle
			raija.play("Idle", 0.1)
			_marker.visible = true
			j.position = Vector3(3.55, 0, -3.25)
			j.rotation.y = B.yaw_to(_flat(BOARD - j.position))
			_arms_crossed(j)
			_build_board_marks()
		"royhtays":
			_story = "Juntti vaatii uusintaa naama kuninkaan naamassa."
			raija.clear_ik()
			_marker.visible = false
			_me.clear_ik()
			_me.clear_overrides()
			_me.position = Vector3(6.0, 0, -2.88)
			_me.rotation.y = B.yaw_to(Vector3(0, 0, -1))
			_me.play("Idle", 0.15)
			j.clear_ik()
			j.position = Vector3(6.0, 0, -3.56)
			j.rotation.y = B.yaw_to(Vector3(0, 0, 1))
			j.play("Idle_Talking", 0.1)
			var mm: Node3D = people.mummo
			mm.position = Vector3(4.55, 0, -3.15)
			mm.rotation.y = B.yaw_to(_flat(Vector3(6.0, 0, -3.2) - mm.position))
			var rk: Node3D = people.reiska  # pois kameran ja parin välistä taustalle
			rk.position = Vector3(4.75, 0, -2.55)
			rk.rotation.y = B.yaw_to(_flat(Vector3(6.0, 0, -3.2) - rk.position))
		"otsikko":
			_story = ""
			_cloud.clear()
			_me.clear_ik()
			_me.clear_overrides()
			_me.position = Vector3(3.15, 0, -2.78)
			_me.rotation.y = B.yaw_to(Vector3(-0.15, 0, -1))
			_me.play("Idle", 0.1)
			j.clear_ik()
			j.clear_overrides()
			j.position = Vector3(4.05, 0, -3.05)
			j.rotation.y = B.yaw_to(_flat(_me.position - j.position))
			j.play("Idle", 0.1)
			_arms_crossed(j)
			var mm: Node3D = people.mummo
			mm.position = Vector3(1.55, 0, -3.15)
			mm.rotation.y = B.yaw_to(_flat(_me.position - mm.position))
			raija.position = Vector3(2.0, 0, -2.95)
			raija.rotation.y = B.yaw_to(_flat(_me.position - raija.position))
			Sfx.play("win", -4.0)


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	_ui.queue_redraw()
	if Input.is_action_just_pressed("interact"):
		if phase != "otsikko":
			_sfx.stop()
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"lasku":
			_step_lasku()
		"paperit":
			_step_paperit()
		"mitta":
			_step_mitta()
		"taulu":
			_step_taulu()
		"royhtays":
			_step_royhtays()
		"otsikko":
			_step_otsikko()
	for c: Array in _cloud:
		c[2] += delta
		c[0] += (c[1] as Vector3) * delta
		c[1] *= 1.0 - delta * 0.9
	_cloud = _cloud.filter(func(c: Array) -> bool: return c[2] < 2.4)
	if phase != "" and _t >= float(_dur[phase]):
		var i := ORDER.find(phase)
		if i == ORDER.size() - 1:
			_finish()
		else:
			_begin(ORDER[i + 1])


func _finish() -> void:
	if phase == "":
		return
	phase = ""
	_sfx.stop()
	for c: Node3D in _orig:
		c.clear_ik()
		c.clear_overrides()
		c.position = _orig[c][0]
		c.rotation.y = _orig[c][1]
		c.play(_orig[c][2], 0.2)
	if is_instance_valid(_marker):
		_marker.queue_free()
	finished.emit()
	queue_free()


func _step_lasku() -> void:
	# Pala suuhun (0..1,1 s), sitten kädet vatsalle ja nojaus taakse.
	var head := _bone(_me, "Head")
	var fwd := Vector3(0, 0, -1)
	var mouth := head + fwd * 0.13 + Vector3(0, -0.07, 0)
	var eat := clampf(_t / 0.5, 0.0, 1.0) * (1.0 - clampf((_t - 0.9) / 0.3, 0.0, 1.0))
	var lean := _ease(clampf((_t - 1.3) / 0.7, 0.0, 1.0))
	if _t < 1.2:
		var rest := _me.to_global(_me.bone_position("upperarm_r") + Vector3(0.12, -0.3, -0.3))
		_hand_to(_me, "_r", game.to_global(game.to_local(rest).lerp(mouth, eat)), Vector3(0.45, -0.5, 0.2))
		_me.set_ik_orient("arm_r", Pose.palm_on(Vector3(-0.3, 0.4, -1.0).normalized(), Vector3(-1, 0, 0), false), 1.0)
	else:
		_piece.visible = false
		_hands_on_belly(lean)
	if _t > 0.95 and not _once.has("gulp"):
		_once.gulp = true
		Sfx.play("pickup", -8.0, 0.55)
		Sfx.play("win_small", -8.0, 1.2)
	_me.set_override("spine_01", Vector3.RIGHT, 0.22 * lean)
	_me.set_override("spine_02", Vector3.RIGHT, 0.16 * lean)
	_me.set_override("neck_01", Vector3.RIGHT, -0.12 * lean)
	if _t > 1.0 and not _once.has("count"):
		_once.count = true
		_say("rekka", "%s!" % WORDS[mini(pies - 1, WORDS.size() - 1)].to_upper())
		for k in ["reiska", "mummo", "rekka", "raija"]:
			(people[k] as Node3D).play("Idle_Talking", 0.1)
	if _t > 2.3 and not _once.has("reiska"):
		_once.reiska = true
		_bub.clear()
		_say("reiska", "Uus ennätys! Raija, tussi!")
	# Laaja kuva pöydän päästä: kuningas vasemmalla edessä, pöytä ja koko porukka vastapäätä.
	var eye := Vector3(7.05, 1.42, -3.45)
	var look := Vector3(5.05, 0.98, -3.95)
	_cam_at(eye.lerp(Vector3(6.75, 1.32, -3.4), _ease(clampf(_t / _dur.lasku, 0.0, 1.0))), look, 52.0)


func _step_paperit() -> void:
	var j: Node3D = people.juntti
	var lean := _ease(clampf((_t - 0.2) / 0.4, 0.0, 1.0))
	j.set_override("spine_01", Vector3.RIGHT, -0.32 * lean)
	j.set_override("spine_02", Vector3.RIGHT, -0.26 * lean)
	j.set_override("neck_01", Vector3.RIGHT, 0.4 * lean)
	_hands_on_belly(1.0)
	var step := 0.42
	var i := int(floor((_t - 0.5) / step))
	if _t >= 0.5 and i < pies:
		var u := fmod(_t - 0.5, step) / step
		# Sormi osoittaa paperia ojennetulla kädellä (pöytä on kumarassakin ulottumattomissa): käsi olan ja paperin
		# suoralle käsivarren mitan päähän, ja osoitus nytkähtää paperia kohti joka luvulla.
		var shp := _bone(j, "upperarm_r")
		var reach := shp.distance_to(_bone(j, "lowerarm_r")) + _bone(j, "lowerarm_r").distance_to(_bone(j, "hand_r"))
		var aim_prev := _paper_at(maxi(i - 1, 0)) + Vector3(0, 0.03, 0)
		var aim := aim_prev.lerp(_paper_at(i) + Vector3(0, 0.03, 0), _ease(minf(u * 2.5, 1.0)))
		var at := shp + (aim - shp).normalized() * reach * (0.9 + 0.07 * sin(u * PI))
		_hand_to(j, "_r", game.to_global(at), Vector3(0.4, -0.5, 0.1))
		j.set_ik_orient("arm_r", Pose.palm_down(Vector3(-1, -0.6, 0).normalized(), false), 1.0)
		var key := "p%d" % i
		if u > 0.35 and not _once.has(key):
			_once[key] = true
			_papers[i].position = _paper_at(i) + Vector3(0, 0.012, 0)
			Sfx.play("cloth", -14.0, 1.6 + i * 0.05)
			_say("juntti", "%s..." % WORDS[mini(i, WORDS.size() - 1)])
		_papers[i].position = _paper_at(i) + Vector3(0, 0.012 * maxf(0.0, 1.0 - absf(u - 0.5) * 3.0), 0)
	elif i >= pies:
		j.clear_ik()
		if not _once.has("end"):
			_once.end = true
			_say("juntti", "...%s. Ei voi olla." % WORDS[mini(pies - 1, WORDS.size() - 1)].to_lower())
	# Paperit keskellä ja isona, Juntti oikealla kumarassa, kuningas taustalla vatsa pystyssä.
	var mid := _paper_at(0).lerp(_paper_at(pies - 1), 0.5)
	# Vastapäiseltä puolelta: paperit edessä, Juntti oikealla pöydän päässä, kuningas taustalla katsomassa.
	var eye := mid + Vector3(-0.35, 0.7, -1.6)
	var look := mid.lerp(_bone(j, "Head"), 0.62)
	_cam_at(eye, look, 40.0)


func _step_mitta() -> void:
	var j: Node3D = people.juntti
	var raija: Node3D = people.raija
	# Piirakan päät Juntin edessä (pituus Z:n suuntaan); kotelo oikeassa kädessä, koukku vasemman sormen alla.
	var a := PIE_AT + Vector3(0, 0.1, -0.128)
	var b := PIE_AT + Vector3(0, 0.1, 0.128)
	var right_end := a if _side_of(j, a) > 0.0 else b
	var left_end := b if right_end == a else a
	var pull := _ease(clampf((_t - 0.9) / 0.8, 0.0, 1.0))
	var lean := _ease(clampf((_t - 0.4) / 0.5, 0.0, 1.0))
	j.set_override("spine_01", Vector3.RIGHT, -0.45 * lean)
	j.set_override("spine_02", Vector3.RIGHT, -0.38 * lean)
	j.set_override("neck_01", Vector3.RIGHT, 0.4 * lean)
	var case_at := right_end + Vector3(0.0, 0.03, 0.0) + (right_end - left_end).normalized() * 0.035
	var hook_at := right_end.lerp(left_end, pull)
	var dir := (left_end - right_end).normalized()
	var yaw := atan2(-dir.z, dir.x)  # paikallinen +X nauhan suuntaan
	_tape_case.position = case_at
	_tape_case.rotation = Vector3(0, yaw, 0)
	_hook.position = hook_at
	_hook.rotation.y = yaw
	var start := case_at + Vector3(0, -0.028, 0) + dir * 0.035
	var len := maxf((hook_at - start).dot(dir), 0.001)
	_tape.position = start
	_tape.rotation = Vector3(0, yaw, 0)
	var nauha: Node3D = _tape.get_node("Nauha")
	nauha.scale = Vector3(len, 1, 1)
	nauha.position = Vector3(len / 2.0, 0, 0)
	for t in _tape.get_children():
		if t.has_meta("x"):
			(t as Node3D).visible = float(t.get_meta("x")) < len
	_hand_to(j, "_r", game.to_global(case_at + Vector3(0, 0.035, 0)), Vector3(0.4, -0.5, 0.1))
	j.set_ik_orient("arm_r", Pose.palm_down((left_end - right_end).normalized() * 0.3 + Vector3(-1, -0.4, 0), false), 1.0)
	_hand_to(j, "_l", game.to_global(hook_at + Vector3(0, 0.04, 0)), Vector3(0.4, -0.5, 0.1))
	j.set_ik_orient("arm_l", Pose.palm_down(Vector3(-1, -0.7, 0).normalized(), true), 1.0)
	if pull > 0.1 and not _once.has("zip"):
		_once.zip = true
		Sfx.play("rattle", -12.0, 2.6)
	if _t > 0.2 and not _once.has("j"):
		_once.j = true
		_say("juntti", "Ne oli pienempiä piirakoita! Mää mittaan.")
	if _t > 2.9 and not _once.has("r"):
		_once.r = true
		_bub.clear()
		_say("raija", "Kakskymmentäkolme senttiä, niinku sullakin, Juntti.")
		raija.play("Idle_Talking", 0.1)
	# Piirakka ja mitta keskellä isona, Juntin kasvot oikealla ylhäällä.
	var head := _bone(j, "Head")
	if _t > 1.0 and not _once.has("close"):
		_once.close = true
		_bub.clear()  # lähikuvassa Juntti on rajattu pois: repliikki jäi edelliseen kuvaan
	if _t > 1.0 and _t < 2.8:
		# Lähikuva: nauha vedetään piirakan yli, lukema 23 cm (vinosti ylhäältä, aurinkovarjon tanko jää taakse).
		_cam_at(Vector3(4.95, 1.45, -3.45), PIE_AT.lerp(head, 0.32), 46.0)
	else:
		# Kahden kuva vastapäiseltä puolelta: Juntti mittaa, Raija vieressä, piirakka edessä.
		_cam_at(Vector3(4.85, 1.5, -5.0), Vector3(5.62, 1.15, -4.12), 46.0)


func _step_taulu() -> void:
	var raija: Node3D = people.raija
	var lh := _line_h()
	var line3 := BOARD + Vector3(0, -lh, -0.045)
	var w := _juntti_w()
	var strike := clampf((_t - 0.5) / 0.7, 0.0, 1.0)
	var write := clampf((_t - 2.0) / 2.4, 0.0, 1.0)
	var tip: Vector3
	if _t < 1.4:
		tip = line3 + Vector3(-w / 2.0 + w * strike, 0.0, 0.0)
		_strike.scale = Vector3(maxf(strike, 0.001), 1, 1)
		_strike.position = line3 + Vector3(-w / 2.0 + w * strike / 2.0, 0.005, 0.0)
		if strike > 0.0 and strike < 1.0 and not _once.has("sq"):
			_once.sq = true
			Sfx.play("cloth", -10.0, 2.6)
	elif _t < 2.0:
		# Lappu teipataan taulun alle.
		_note.visible = true
		var k := _ease(clampf((_t - 1.4) / 0.4, 0.0, 1.0))
		_note.scale = Vector3(1, k, 1)
		tip = _note.position + Vector3(0.28, 0.0, -0.02)
		if not _once.has("tape"):
			_once.tape = true
			Sfx.play("rattle", -14.0, 1.4)
	else:
		var n := int(write * _note_text.length())
		_note_lab.text = _note_text.substr(0, n)
		var nw := 0.62
		tip = _note.position + Vector3(-nw / 2.0 + nw * write, -0.01 + 0.012 * sin(_t * 40.0), -0.02)
		if n > 0 and n < _note_text.length() and int(_t * 8.0) != int((_t - get_process_delta_time()) * 8.0):
			Sfx.play("cloth", -16.0, 2.3)
	_hand_to(raija, "_r", game.to_global(tip + Vector3(0, 0.07, -0.02)), Vector3(0.45, -0.4, 0.2))
	raija.set_ik_orient("arm_r", Pose.palm_on(Vector3(0.1, 1.0, 0.25).normalized(), Vector3(0, 0, 1), false), 1.0)
	if _t > 2.4 and not _once.has("r"):
		_once.r = true
		_say("raija", "Järvikuja 1. %s piirakkaa. Taulu ei valehtele." % WORDS[mini(pies - 1, WORDS.size() - 1)])
	# Olan yli Raijasta taululle: taulu ja lappu isona, Juntti taustalla oikealla kädet puuskassa.
	var eye := BOARD + Vector3(-0.75, -0.2, -1.75)
	var look := BOARD + Vector3(0.25, -0.3, 0.0)
	_cam_at(eye, look, 46.0)


func _step_royhtays() -> void:
	var j: Node3D = people.juntti
	var burp := 1.55  # röyhtäyksen hetki
	if _t > 0.2 and not _once.has("j"):
		_once.j = true
		_say("juntti", "Mää en usko. Mää vaadin uusinnan!")
	# Kuningas vetää henkeä (rinta pystyyn), sitten röyhtäisee eteenpäin.
	var inhale := _ease(clampf((_t - 0.9) / 0.6, 0.0, 1.0)) * (1.0 - clampf((_t - burp) / 0.15, 0.0, 1.0))
	var push := clampf(sin(clampf((_t - burp) / 0.9, 0.0, 1.0) * PI), 0.0, 1.0)
	_me.set_override("spine_02", Vector3.RIGHT, 0.2 * inhale - 0.18 * push)
	_me.set_override("neck_01", Vector3.RIGHT, -0.25 * inhale + 0.12 * push)
	_hands_on_belly(1.0)
	if _t >= burp and not _once.has("burp"):
		_once.burp = true
		_bub.clear()
		_play(_burp_wav(), 0.0)
		_shake = 1.0
		var mouth := _bone(_me, "Head") + Vector3(0, -0.08, -0.14)
		for i in 26:
			var dir := Vector3(randf_range(-0.25, 0.25), randf_range(-0.05, 0.3), -1.0).normalized()
			_cloud.append([mouth, dir * randf_range(0.5, 1.3), randf_range(-0.15, 0.0)])
	# Juntti perääntyy, kääntää päänsä ja peittää nenänsä.
	var recoil := _ease(clampf((_t - burp - 0.15) / 0.5, 0.0, 1.0))
	j.set_override("spine_01", Vector3.RIGHT, 0.2 * recoil)
	j.set_override("spine_02", Vector3.RIGHT, 0.15 * recoil)
	j.set_override("neck_01", Vector3.UP, 0.55 * recoil)
	if recoil > 0.0:
		var nose := _bone(j, "Head") + j.basis * Vector3(0, -0.05, -0.12)
		var rest := _bone(j, "upperarm_l") + j.basis * Vector3(0, -0.4, -0.15)
		_hand_to(j, "_l", game.to_global(rest.lerp(nose, recoil)), Vector3(0.4, -0.5, 0.2))
		j.set_ik_orient("arm_l", Pose.palm_on(Vector3(0, 1, 0), j.basis * Vector3(0, 0, 1), true), recoil)
	if _t > burp + 0.9 and not _once.has("m"):
		_once.m = true
		_say("mummo", "Siinä kuuluu kuninkaan ääni!")
		(people.mummo as Node3D).play("Idle_Talking", 0.1)
	# Profiili sivulta: kuningas vasemmalla, Juntti oikealla, pöytä ja mummo taustalla.
	var mid := Vector3(6.0, 1.42, -3.22)
	_cam_at(mid + Vector3(1.95, -0.05, 0.05), mid + Vector3(0, -0.1, 0), 50.0)


func _step_otsikko() -> void:
	# Nyrkki ylös.
	var up := _ease(clampf(_t / 0.6, 0.0, 1.0))
	var sh: Vector3 = _me.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest: Vector3 = sh + Vector3(s * 0.15, -0.55, 0.0)
	var top: Vector3 = sh + Vector3(s * 0.2, 0.55, -0.12)
	_me.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", rest.lerp(top, up), sh + Vector3(s * 0.55, 0.0, 0.3))
	_me.set_ik_orient("arm_r", Pose.palm_on(Vector3(0, 1, 0), Vector3(0, 0, -1), false), up)
	_hands_on_belly(1.0, true)
	if not _once.has("board"):
		_once.board = true
		if _strike == null:
			_build_board_marks()
		_strike.scale = Vector3.ONE
		_strike.position = BOARD + Vector3(0, -_line_h() + 0.005, -0.045)
		_note.visible = true
		_note.scale = Vector3.ONE
		_note_lab.text = _note_text
	var eye := Vector3(2.95, 1.42, -6.15)
	var look := Vector3(2.85, 1.25, -2.4)
	_cam_at(eye, look, 44.0)


# --- Taulu ----------------------------------------------------------------------------

func _line_h() -> float:
	return ThemeDB.fallback_font.get_height(24) * 0.005


func _juntti_w() -> float:
	return ThemeDB.fallback_font.get_string_size("Juntti 7", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x * 0.005 * 1.25


## Punainen tussiviiva Juntin nimen yli ja valkoinen lappu taulun alle (teippi kulmissa), sininen käsiala.
func _build_board_marks() -> void:
	if _strike != null:
		return
	var w := _juntti_w()
	_strike = B.mesh(game, B.boxm(Vector3(w, 0.016, 0.004)), BOARD + Vector3(-w / 2.0, -_line_h(), -0.045), Color(0.9, 0.08, 0.06))
	_strike.rotation.z = 0.04
	_strike.scale = Vector3(0.001, 1, 1)
	_note = Node3D.new()
	game.add_child(_note)
	var plate_h := 0.57
	_note.position = BOARD + Vector3(0.0, -plate_h / 2.0 - 0.13, -0.035)
	_note.rotation.z = -0.03
	B.mesh(_note, B.boxm(Vector3(0.82, 0.18, 0.002)), Vector3(0.006, -0.006, 0.001), Color(0.55, 0.52, 0.45))  # varjo seinässä
	B.mesh(_note, B.boxm(Vector3(0.8, 0.16, 0.003)), Vector3.ZERO, Color(1.0, 0.93, 0.55))  # keltainen lappu
	for x in [-0.38, 0.38]:  # teipinpalat kulmissa
		var t := B.mesh(_note, B.boxm(Vector3(0.06, 0.03, 0.002)), Vector3(x, 0.075, -0.002), Color(0.9, 0.88, 0.75, 0.8))
		t.rotation.z = 0.5 if x < 0.0 else -0.5
	_note_lab = Label3D.new()
	_note_lab.text = ""
	_note_lab.font_size = 30
	_note_lab.pixel_size = 0.003
	_note_lab.modulate = Color(0.08, 0.2, 0.75)
	_note_lab.outline_size = 0
	_note_lab.double_sided = false
	_note_lab.rotation.y = PI  # luettava julkisivun puolelta (-Z)
	_note_lab.position = Vector3(0, 0, -0.003)
	_note.add_child(_note_lab)
	_note.visible = false


# --- Asennot --------------------------------------------------------------------------

## Kädet vatsalle (kylläinen kuningas). keep_right: oikea käsi on muualla (otsikon nyrkki).
func _hands_on_belly(w: float, keep_left_only := false) -> void:
	if w <= 0.0:
		return
	var belly: Vector3 = _me.bone_position("spine_01")
	for lr in (["_l"] if keep_left_only else ["_l", "_r"]):
		var sh: Vector3 = _me.bone_position("upperarm" + lr)
		var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
		var rest := sh + Vector3(s * 0.12, -0.5, 0.0)
		var on := belly + Vector3(s * 0.11, 0.02, -0.26)
		_me.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, rest.lerp(on, w), sh + Vector3(s * 0.5, -0.3, 0.3))
		_me.set_ik_orient("arm" + lr, Pose.palm_on(Vector3(-s, -0.25, 0).normalized(), Vector3(0, 0, 1), lr == "_l"), w)


## Juntti kädet puuskassa (kuten piirakka_game.gd _build_scene).
func _arms_crossed(j: Node3D) -> void:
	for side in [["_l", -1.0], ["_r", 1.0]]:
		var s: float = side[1]
		j.set_ik("arm" + side[0], "upperarm" + side[0], "lowerarm" + side[0], "hand" + side[0], Vector3(-s * 0.12, 1.25, -0.2),
			Vector3(s * 0.4, 1.1, 0.2))


## Käsi kehyksen (globaaliin) pisteeseen; pole hahmon avaruudessa olkapäästä.
func _hand_to(c: Node3D, lr: String, p_global: Vector3, pole_off: Vector3) -> void:
	var local := c.to_local(p_global)
	var sh: Vector3 = c.bone_position("upperarm" + lr)
	var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
	c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, local, sh + Vector3(s * absf(pole_off.x), pole_off.y, pole_off.z))


## Kummalla puolella hahmoa piste on (> 0 = oikea käsi).
func _side_of(c: Node3D, p: Vector3) -> float:
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	return c.to_local(game.to_global(p)).x * s


# --- Kamera ja apu --------------------------------------------------------------------

func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.04 * _shake
	_cam.fov = fov
	_cam.look_at_from_position(game.to_global(eye + sh), game.to_global(look))


func _bone(c: Node3D, bone: String) -> Vector3:
	return game.to_local(c.to_global(c.bone_position(bone)))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _ease(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


func _say(who: String, text: String) -> void:
	if people.has(who):
		_bub[people[who]] = text


# --- Ääni -----------------------------------------------------------------------------

func _play(wav: AudioStreamWAV, db: float) -> void:
	_sfx.stream = wav
	_sfx.volume_db = db
	_sfx.play()


## Röyhtäys: matala, karhea sävel (perustaajuus laskee 110 -> 70 Hz), formantit ja nykivä amplitudi.
func _burp_wav() -> AudioStreamWAV:
	var dur := 1.25
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var ph := 0.0
	var lp := 0.0
	for i in s.size():
		var t := i / RATE
		var f := lerpf(118.0, 68.0, t / dur) * (1.0 + 0.06 * sin(TAU * 23.0 * t))
		ph += TAU * f / RATE
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		var n := rng.randf_range(-1.0, 1.0)
		lp += (saw * 0.7 + n * 0.3 - lp) * 0.18
		var env := minf(t / 0.03, 1.0) * clampf((dur - t) / 0.4, 0.0, 1.0) * (0.75 + 0.25 * sin(TAU * 9.0 * t))
		s[i] = env * 0.85 * (lp + 0.25 * sin(ph * 3.0))
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = bytes
	return w


# --- Piirto ---------------------------------------------------------------------------

func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 440, 24, 880, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for c: Node3D in _bub:
		if is_instance_valid(c):
			Room.bubble(_ui, _cam, c, _bub[c], 90.0, 120.0)
	# Sipulipilvi: kellanvihreät läpikuultavat höyrypallot, laajenevat ja haihtuvat.
	for c: Array in _cloud:
		if float(c[2]) < 0.0:
			continue
		var wp := game.to_global(c[0])
		if _cam.is_position_behind(wp):
			continue
		var sp := _cam.unproject_position(wp)
		var al := clampf(1.0 - float(c[2]) / 2.4, 0.0, 1.0)
		var r := 10.0 + 34.0 * float(c[2])
		_ui.draw_circle(sp, r, Color(0.72, 0.8, 0.32, 0.22 * al))
		_ui.draw_circle(sp + Vector2(-r * 0.25, -r * 0.25), r * 0.55, Color(0.86, 0.9, 0.5, 0.18 * al))
	# Mitta: lukema nauhan kohdalla.
	if phase == "mitta" and _t > 1.8:
		var p := _cam.unproject_position(game.to_global(PIE_AT + Vector3(0, 0.2, 0)))
		var a := clampf((_t - 1.8) / 0.3, 0.0, 1.0)
		var r := Rect2(p - Vector2(58, 26), Vector2(116, 44))
		_ui.draw_rect(r, Color(0.98, 0.84, 0.15, 0.95 * a))
		_ui.draw_rect(r, Color(0.1, 0.08, 0.02, a), false, 3.0)
		_ui.draw_string(font, r.position + Vector2(0, 32), "23 cm", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, Color(0.08, 0.06, 0.02, a))
	if phase == "otsikko":
		var a := clampf((_t - 0.8) / 0.8, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.05, 0.25 * a))
		var y := vs.y * 0.2
		_draw_pie(Vector2(vs.x / 2.0, y - 84.0), a)
		var title := "LIHAPIIRAKKAKUNINGAS"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 70, 12, Color(0.12, 0.04, 0.02, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 70, Color(1.0, 0.82, 0.35, a))
		var sr := Rect2(vs.x / 2.0 - 400, vs.y - 150.0, 800, 74)
		_ui.draw_rect(sr, Color(0.05, 0.04, 0.03, 0.75 * a))
		var sub := "Reipparin ennätystauluun uusi nimi: Järvikuja 1, %d lihapiirakkaa. Juntti laski paperit ja mittasi piirakat, eikä usko vieläkään." % pies
		_ui.draw_multiline_string(font, sr.position + Vector2(18, 30), sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 36, 19, 3, Color(1.0, 0.94, 0.8, a))


## Lihapiirakka otsikon yllä: tumma uppopaistettu kuori auki kuin simpukka, nakit, kurkkusalaatti ja ketsuppi.
func _draw_pie(c: Vector2, a: float) -> void:
	var bun := Color(0.45, 0.22, 0.1, a)
	var edge := Color(0.72, 0.42, 0.16, a)
	var outline := Color(0.18, 0.08, 0.03, a)
	var lid := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 17:
		var t := PI * i / 16.0
		lid.append(c + Vector2(-cos(t) * 74.0, -18.0 - sin(t) * 30.0))
		bottom.append(c + Vector2(-cos(t) * 78.0, 6.0 + sin(t) * 26.0))
	_ui.draw_colored_polygon(lid, bun)
	_ui.draw_polyline(lid, outline, 3.0)
	_ui.draw_colored_polygon(bottom, bun)
	_ui.draw_polyline(bottom, outline, 3.0)
	_ui.draw_line(c + Vector2(-76, 6), c + Vector2(76, 6), edge, 5.0)
	for i in 3:  # nakit
		var y := -6.0 + i * 1.0
		_ui.draw_line(c + Vector2(-70 + i * 4, y - i * 4), c + Vector2(70 - i * 4, y - i * 4), Color(0.93, 0.62, 0.52, a), 11.0)
	for i in 9:  # kurkkusalaatti
		_ui.draw_circle(c + Vector2(-56 + i * 14, -12.0 + (i % 3) * 3.0), 4.0, Color(0.42, 0.58, 0.14, a))
	var zig := PackedVector2Array()
	for i in 11:
		zig.append(c + Vector2(-60 + i * 12, -14.0 + (6.0 if i % 2 == 0 else -2.0)))
	_ui.draw_polyline(zig, Color(0.78, 0.06, 0.04, a), 4.0)
