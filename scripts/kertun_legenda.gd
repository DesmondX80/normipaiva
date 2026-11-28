extends CanvasLayer
## Legendaarinen hetki "kertun_rauta" (Viimeisen sepän kirves): kun kirves on viety Saloisten Pirttiin ja lehtijuttu
## näytetään ensimmäistä kertaa Raimolle ja Veikolle kodalla (main.gd _kota_logic), hetki lavastetaan Haapajärven
## kodassa tulen ääressä. Vaiheet:
##   lehti    pelaaja astuu kotaan ja ojentaa lehden istuvalle Raimolle ("Mikäs se on?")
##   raimo    Raimo lukee, nousee seisomaan ja nostaa etusivun ilmaan: "No? NO? Mitä mää sanoin! Lehdessä! Kuvan kanssa!"
##   veikko   Veikko lukee pitkään: "...Museo sano, että rautakautinen. Perkele." Raimo osoittaa kylttiä selkänsä takana:
##            "Kiroilu kielletty, Veikko. Lue kylttiä." (kodan vanha vitsi)
##   kaljat   Veikko kaivaa kassista kolme kaljaa: "Lupaus on lupaus." Kolme tölkkiä kilahtaa yhteen, tuli räiskähtää.
##   leike    Raimo painaa lehden seinään "Tarinoiden liioittelu kielletty" -kyltin viereen: "Ei ollu liioittelua."
##   otsikko  Raimo ja Veikko istuvat kaljoineen; "Ukki ois ylpee." VIIMEISEN SEPÄN KIRVES
## Kehys: kodan paikallinen kehys (kota.gd: -Z = oviaukko, tulisija origossa, lattia y = 0,2). Hahmojen etu -Z (Looks).
## Lehtileike jää seinälle (kota.set_clipping), Raimo ja Veikko muistelevat jutellessa (MUISTO, main.gd _kota_chat_line).

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const Kota := preload("res://scripts/kota.gd")

const DUR := {"lehti": 5.6, "raimo": 7.0, "veikko": 7.4, "kaljat": 6.8, "leike": 6.0, "otsikko": 6.6}
const ORDER := ["lehti", "raimo", "veikko", "kaljat", "leike", "otsikko"]
const FLOOR := 0.2
## Istumapaikat (kota.gd _build_people: seinät k = 3 ja 5, kasvot tulta kohti).
const S_R := Vector2(-1.587, 1.587)
const S_V := Vector2(1.587, 1.587)
const R_ST := Vector2(-1.12, 1.08)  # Raimo seisoo istuimensa edessä
const P_DOOR := Vector2(0.0, -2.55)
const P_GIVE := Vector2(-1.0, 1.3)  # Raimon polvien vieressä, hieman hänen oikealla puolellaan  # pelaaja ojentaa lehden istuvalle Raimolle
const P_WATCH := Vector2(-0.25, -1.4)
## Kilistely: kolmio tulisijan takana (keskus M, kärjet 0,62 m päässä; tulisijan säde 0,85).
const TOAST := Vector2(0.0, 1.33)
const T_V := Vector2(0.0, 1.83)
const T_R := Vector2(-0.45, 1.07)
const T_P := Vector2(0.45, 1.07)
const KIROILU := Vector3(-1.912, 1.45, 1.912)  # "Kiroilu kielletty (koskee myös Pekkaa)" Raimon istuimen yllä (k = 3)
const LIIOITTELU := Vector3(1.912, 1.45, -1.912)  # "Tarinoiden liioittelu kielletty" (k = 7)
## Raimo ja Veikko muistelevat jutellessa (main.gd _kota_chat_line): [puhuja, repliikki].
const MUISTO := [["raimo", "Kakskymmentä vuotta mää sanoin sitä seppää todeks. Nyt se on lehdessä. Tuossa seinällä."],
	["veikko", "Ensimmäinen kerta, ku mää tarjosin Raimolle mitään. Viimeinen kans, toivottavasti."],
	["raimo", "Tarinoiden liioittelu kielletty. Lue leikettä sen vieressä, Veikko."],
	["veikko", "Museo sano rautakautinen. Mää sanoin perkele. Raimo sano lue kylttiä. Joka ilta sama juttu nykyään."]]

var kota: Node3D
var hide_nodes: Array = []  # oikea pelaaja piiloon kohtauksen ajaksi (kopio näyttelee)
var _was_visible := {}
var _fire_was := false
var _fire_time := 0.0

var phase := ""
var _t := 0.0
var _cam: Camera3D
var _ui: Control
var _keys: Node
var _story := ""
var _bub := {}
var _once := {}
var _props: Array[Node3D] = []
var me: Node3D
var raimo: Node3D
var veikko: Node3D
var paper: Node3D
var bag: Node3D
var cans := {}  # hahmo -> tölkki
var _sparks: CPUParticles3D
var paper_on_wall := false


func _ready() -> void:
	layer = 6
	_cam = Camera3D.new()
	kota.add_child(_cam)
	_cam.make_current()
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
	# Oikeat Raimo ja Veikko, nimilaput ja puhekuplat piiloon; kopiot näyttelevät.
	var hide: Array = hide_nodes.duplicate()
	hide.append_array([kota.raimo, kota.veikko])
	hide.append_array(kota.name_tags.values())
	hide.append_array(kota._bubbles.values())
	for nd in hide:
		if is_instance_valid(nd):
			_was_visible[nd] = (nd as Node3D).visible
			(nd as Node3D).visible = false
	_fire_was = kota.fire_on
	_fire_time = kota.fire_time
	kota.set_fire(true, 600.0)
	_build()
	_begin("lehti")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	raimo = _person(Kota.RAIMO)
	veikko = _person(Kota.VEIKKO)
	me = _person(Looks.player())
	paper = Kota.lehti()
	kota.add_child(paper)
	_props.append(paper)
	# Veikon oranssi kauppakassi lattialla polvien vieressä (kaljat tulevat siitä).
	bag = Looks.beer_bag()
	kota.add_child(bag)
	_props.append(bag)
	# Kassi penkillä Veikon oikealla puolella (penkin kansi y 0,655, kassin pohja 0,43 sangoista alaspäin).
	var fwd := _fwd_of(S_V)
	var side := Vector2(-fwd.y, fwd.x)
	var bp := -fwd * 2.45 + side * 0.5
	bag.position = Vector3(bp.x, 0.655 + 0.43, bp.y)
	bag.rotation.y = B.yaw_to(Vector3(fwd.x, 0, fwd.y))
	for c in [raimo, veikko, me]:
		var can := _can()
		can.visible = false
		cans[c] = can
	# Lämmin täytevalo kodan katonrajassa, jotta kasvot erottuvat tulen vastavalossa.
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.78, 0.55)
	fill.light_energy = 0.7
	fill.omni_range = 5.0
	fill.position = Vector3(0.0, 2.3, -0.6)
	kota.add_child(fill)
	_props.append(fill)
	# Kipinäsuihku tulesta kilistyksessä.
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 40
	_sparks.lifetime = 1.3
	_sparks.explosiveness = 0.9
	_sparks.direction = Vector3.UP
	_sparks.spread = 35.0
	_sparks.initial_velocity_min = 1.6
	_sparks.initial_velocity_max = 3.2
	_sparks.gravity = Vector3(0, -2.0, 0)
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.006
	sm.height = 0.012
	sm.material = B.unshaded(Color(2.0, 1.1, 0.3))
	_sparks.mesh = sm
	_sparks.position = Vector3(0, 0.85, 0)
	kota.add_child(_sparks)
	_props.append(_sparks)


func _person(look: Dictionary) -> Node3D:
	var c: Node3D = Looks.make(kota, look)
	_props.append(c)
	c.play("Idle", 0.0)
	return c


## Kaljatölkki: sininen kylki (kuten kassin tölkit), kultainen raita, alumiinikansi ja repäisyrengas.
func _can() -> Node3D:
	var can := Node3D.new()
	kota.add_child(can)
	_props.append(can)
	B.mesh(can, B.cyl(0.033, 0.033, 0.12, 14), Vector3.ZERO, Color(0.12, 0.22, 0.55))
	B.mesh(can, B.cyl(0.0335, 0.0335, 0.022, 14), Vector3(0, 0.012, 0), Color(0.85, 0.7, 0.25))
	var lid := B.mesh(can, B.cyl(0.028, 0.033, 0.012, 14), Vector3(0, 0.066, 0), Color(0.8, 0.8, 0.82))
	(lid.material_override as StandardMaterial3D).metallic = 0.8
	(lid.material_override as StandardMaterial3D).roughness = 0.3
	B.mesh(can, B.boxm(Vector3(0.014, 0.003, 0.02)), Vector3(0.006, 0.073, 0), Color(0.7, 0.7, 0.72))
	return can


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	_story = ""
	for c in [raimo, veikko, me]:
		c.clear_ik()
		_relax(c)
	for c in cans:
		cans[c].visible = false
	match p:
		"lehti":
			_story = "Haapajärven kota. Raimo ja Veikko istuvat tulilla. Lehti on taskussa."
			_sit(raimo, S_R)
			_sit(veikko, S_V)
			_stand(me, P_DOOR)
			_face(me, P_GIVE)
		"raimo":
			_sit(raimo, S_R)
			_sit(veikko, S_V)
			_stand(me, P_WATCH)
			_face(me, R_ST)
		"veikko":
			_sit(veikko, S_V)
			_stand(raimo, R_ST)
			_face(raimo, S_V)
			_stand(me, P_WATCH)
			_face(me, S_V)
		"kaljat":
			_sit(veikko, S_V)
			_stand(raimo, R_ST)
			_face(raimo, S_V)
			_stand(me, P_WATCH)
			_face(me, S_V)
			_paper_on_lap(veikko)
		"leike":
			_sit(veikko, S_V)
			_stand(me, P_WATCH + Vector2(0.55, 0.05))
			var at := _clip_stand()
			_stand(raimo, at)
			cans[veikko].visible = true
			cans[me].visible = true
		"otsikko":
			paper_on_wall = true
			_paper_on_wall()
			_sit(raimo, S_R)
			_sit(veikko, S_V)
			_stand(me, Vector2(-0.95, -0.9))
			_face(me, Vector2(0.0, 1.2))
			for c in [raimo, veikko, me]:
				cans[c].visible = true
			Sfx.play("win", -6.0, 0.95)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa E-painalluksesta kodalla: sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "lehti" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"lehti":
			_step_lehti(delta)
		"raimo":
			_step_raimo(delta)
		"veikko":
			_step_veikko(delta)
		"kaljat":
			_step_kaljat(delta)
		"leike":
			_step_leike(delta)
		"otsikko":
			_step_otsikko(delta)
	_ui.queue_redraw()
	if phase != "" and _t >= DUR[phase]:
		var i := ORDER.find(phase)
		if i == ORDER.size() - 1:
			_finish()
		else:
			_begin(ORDER[i + 1])


func _finish() -> void:
	if phase == "":
		return
	phase = ""
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	for nd in _was_visible:
		if is_instance_valid(nd):
			(nd as Node3D).visible = _was_visible[nd]
	kota.set_fire(_fire_was, maxf(_fire_time, 1.0))
	kota.set_clipping(true)
	finished.emit()
	_cam.queue_free()
	queue_free()


func _step_lehti(_delta: float) -> void:
	# Pelaaja kävelee ovelta tulen ohi Raimon eteen (3,0 s) ja ojentaa lehden; Raimo kurottaa ja ottaa sen.
	var k := clampf(_t / 3.0, 0.0, 1.0)
	var mid := Vector2(-0.75, -0.85)
	var pos: Vector2
	if k < 0.55:
		pos = P_DOOR.lerp(mid, k / 0.55)
	else:
		pos = mid.lerp(P_GIVE, (k - 0.55) / 0.45)
	_stand(me, pos)
	me.play("Walk" if k < 1.0 else "Idle", 0.2)
	_face(me, P_GIVE if k < 0.5 else S_R)
	var give := clampf((_t - 3.1) / 0.6, 0.0, 1.0)
	var hand_over := _K(lerpf(P_GIVE.x, S_R.x, 0.5), 1.02, lerpf(P_GIVE.y, S_R.y, 0.5))
	# Ojennus Raimoa lähempänä olevalla kädellä, Raimo ottaa omalla lähemmällä kädellään.
	var ms := _near_side(me, hand_over)
	var rs := _near_side(raimo, hand_over)
	if _t < 4.2:
		# Lehti taiteltuna pelaajan kädessä, sitten ojennettuna.
		var sh: Vector3 = me.bone_position("upperarm_" + ms)
		var rest := me.to_global(sh + Vector3(signf(sh.x) * 0.1, -0.5, -0.12))
		var tgt := rest.lerp(hand_over, give)
		_reach_g(me, ms, tgt)
		paper.global_position = _hand(me, ms) + Vector3(0, 0.01, 0)
		paper.global_rotation = Vector3(-PI / 2.0 + 0.25, me.global_rotation.y + PI * 0.5, 0)
		paper.scale = Vector3(0.5, 0.5, 1.0)  # taiteltuna
	if _t > 3.4:
		var take := clampf((_t - 3.4) / 0.5, 0.0, 1.0)
		raimo.set_override("spine_01", Vector3.RIGHT, -0.35 * take)
		_reach_g(raimo, rs, hand_over, take)
	if _t >= 4.2:
		me.clear_ik()
		paper.global_position = _hand(raimo, rs) + Vector3(0, 0.01, 0)
		var back := clampf((_t - 4.4) / 0.8, 0.0, 1.0)
		_reach_g(raimo, rs, hand_over.lerp(_K(S_R.x + 0.25, 0.95, S_R.y - 0.25), back))
		raimo.set_override("spine_01", Vector3.RIGHT, -0.35 * (1.0 - back))
	if _t > 0.8 and _t < 3.0:
		_bub[raimo] = "Kukas sieltä tulee? Puita toit?"
	elif _t >= 3.4:
		_bub[raimo] = "Mikäs se on? Lehti?"
		_bub.erase(veikko)
	if _t > 2.0 and _t < 3.4:
		_bub[veikko] = "Ei tuo puita. Paperia."
	if _t >= 3.0:
		# Leikkaus sivulle: ojennus profiilissa takaseinän edestä (pelaaja ei peitä Raimoa).
		var mid2 := (P_GIVE + S_R) / 2.0
		var perp := Vector2(P_GIVE.y - S_R.y, S_R.x - P_GIVE.x).normalized()  # etuvasemmalle (Raimon kasvot kolme neljäsosaa)
		var e2 := mid2 + perp * 1.7
		_frame(_K(e2.x, 1.55, e2.y), [_hd(raimo, 0.3), _hd(me, 0.3), hand_over, _K(S_R.x, 0.3, S_R.y), _K(P_GIVE.x, 0.3, P_GIVE.y)], 1.1)
		return
	# Kuva oven suusta sisään: tuli keskellä, Raimo ja Veikko penkeillä takana, pelaaja tulee selin.
	_frame(_K(0.95, 1.85, -2.45), [_hd(raimo, 0.35), _hd(veikko, 0.35), _K(S_R.x, 0.3, S_R.y), _K(S_V.x, 0.3, S_V.y), _K(0, 0.35, -0.7)], 1.08)


func _step_raimo(_delta: float) -> void:
	# 0-2,2 s Raimo lukee istuen (lehti kasvoja kohti), 2,2-3,3 s nousee, sitten nostaa etusivun ilmaan näytille.
	if _t < 2.2:
		_hold_paper(raimo, "read")
		Room.nod(raimo, 0.25)
		if _t > 0.6:
			_bub[raimo] = "\"Rautakautinen kirves Kertunkankaalta...\""
		_frame(_K(S_R.x + 1.2, 1.4, S_R.y - 0.95), [_hd(raimo, 0.3), _hd(raimo, -0.15), paper.to_global(Vector3(0, -0.26, 0)),
			paper.to_global(Vector3(-0.2, 0.0, 0)), paper.to_global(Vector3(0.2, 0.0, 0))], 1.12)
		return
	var up := clampf((_t - 2.2) / 1.1, 0.0, 1.0)
	if up < 1.0:
		var e := up * up * (3.0 - 2.0 * up)
		_stand(raimo, S_R.lerp(R_ST, e))
		raimo.play("Idle", 0.35)
		_face(raimo, Vector2(0.4, -0.6))
		_hold_paper(raimo, "read")
		_bub.erase(raimo)
	else:
		_stand(raimo, R_ST)
		_face(raimo, Vector2(0.6, -0.7))
		_hold_paper(raimo, "show")
		_bub[raimo] = "No? NO? Mitä mää sanoin! Lehdessä! Kuvan kanssa!"
		if not _once.has("lyonti"):
			_once["lyonti"] = true
			Sfx.play("cloth", -2.0, 0.8)
	_face(me, R_ST)
	# Puolilähikuva tulisijan puolelta: Raimon kasvot ja koko etusivu.
	var pts := [_hd(raimo, 0.32)]
	for cx in [-0.19, 0.19]:
		for cy in [-0.25, 0.25]:
			pts.append(paper.to_global(Vector3(cx, cy, 0)))
	_frame(_K(R_ST.x + 1.2, 1.55, R_ST.y - 1.4), pts, 1.1)


func _step_veikko(_delta: float) -> void:
	# Veikko lukee pitkään istuen, kiroaa; Raimo osoittaa vasemmalla kädellä kylttiä istuimensa yllä.
	_hold_paper(veikko, "read")
	if _t < 0.8:
		_reach_g(raimo, "r", veikko.global_position + Vector3(0, 1.0, 0), 1.0 - _t / 0.8)
	if _t > 0.6 and _t < 2.6:
		_bub[veikko] = "..."
	elif _t >= 2.6 and _t < 4.6:
		_bub[veikko] = "...Museo sano, että rautakautinen. Perkele."
		Room.nod(veikko, -0.15)
	elif _t >= 4.6:
		_bub.erase(veikko)
	if _t >= 4.4:
		var w := clampf((_t - 4.4) / 0.5, 0.0, 1.0)
		var d := Vector2(KIROILU.x, KIROILU.z) - R_ST
		raimo.rotation.y = B.yaw_to(Vector3(d.x, 0, d.y)) - deg_to_rad(80.0)
		_point(raimo, "l", kota.to_global(KIROILU), w)
		if _t > 4.8:
			_bub[raimo] = "Kiroilu kielletty, Veikko. Lue kylttiä."
	else:
		_face(raimo, S_V)
	_face(me, S_V)
	if _t >= 4.4:
		# Raimon edestä: Raimo, ojennettu käsi ja kyltti hänen vasemmalla puolellaan.
		var f := raimo.global_basis * Vector3(0, 0, -1)
		_frame(raimo.global_position + f * 1.55 + Vector3(0, 1.5, 0) - raimo.global_basis.x * 0.25,
			[_hd(raimo, 0.32), _hd(raimo, -0.55), kota.to_global(KIROILU + Vector3(0, 0.25, 0)), kota.to_global(KIROILU - Vector3(0, 0.3, 0))], 1.1)
	else:
		# Kaksoiskuva tulisijan yli: Veikko lehtineen, Raimo seisoo.
		_frame(_K(0.35, 1.95, -1.55), [_hd(veikko, 0.32), _hd(raimo, 0.32), paper.global_position, _K(S_V.x, 0.45, S_V.y), _K(R_ST.x, 0.5, R_ST.y)], 1.08)


func _step_kaljat(_delta: float) -> void:
	# 0-2,6 s Veikko kumartuu kassille ja nostaa tölkin; sitten leikkaus kilistykseen: kolme tölkkiä yhteen tulen yllä.
	if _t < 2.6:
		var k := clampf((_t - 0.3) / 0.8, 0.0, 1.0) * (1.0 - clampf((_t - 1.7) / 0.7, 0.0, 1.0))
		var into := bag.global_position + Vector3(0, -0.14, 0)
		var hold := _K(S_V.x - 0.3, 1.05, S_V.y - 0.3)
		var tgt := hold.lerp(into, k)
		veikko.set_override("spine_01", Vector3.RIGHT, -0.15 * k)
		_reach_g(veikko, "r", tgt)
		cans[veikko].visible = _t > 1.1
		cans[veikko].global_position = _hand(veikko, "r") + Vector3(0, 0.02, 0)
		cans[veikko].global_rotation = Vector3.ZERO
		_face(raimo, S_V)
		if _t > 0.8:
			_bub[veikko] = "Lupaus on lupaus."
		if _t > 1.2 and not _once.has("kassi"):
			_once["kassi"] = true
			Sfx.play("cloth", -4.0, 1.1)
		_frame(_K(S_V.x - 1.45, 1.45, S_V.y - 1.25), [_hd(veikko, 0.32), bag.global_position + Vector3(0, -0.45, 0), cans[veikko].global_position,
			_K(S_V.x, 0.35, S_V.y)], 1.12)
		return
	if not _once.has("kolmio"):
		_once["kolmio"] = true
		veikko.clear_ik()
		_relax(veikko)
		_stand(veikko, T_V)
		_stand(raimo, T_R)
		_stand(me, T_P)
		for c: Node3D in [veikko, raimo, me]:
			_face(c, TOAST)
			c.rotation.y += 0.45  # oikea olka kohti kolmion keskustaa (tölkit oikeassa kädessä)
			cans[c].visible = true
		paper.visible = false
	var tt := _t - 2.6
	var clink := clampf((tt - 1.1) / 0.45, 0.0, 1.0)
	var m := _K(TOAST.x, 1.32, TOAST.y)
	for c: Node3D in [veikko, raimo, me]:
		var own := c.to_global(c.bone_position("upperarm_r") + Vector3(signf(c.bone_position("upperarm_r").x) * 0.05, -0.25, -0.38))
		var meet := m + (c.global_position - m) * Vector3(1, 0, 1) * 0.07
		_reach_g(c, "r", own.lerp(meet, clink))
		cans[c].global_position = (_hand(c, "r") + Vector3(0, 0.03, 0)).lerp(meet + Vector3(0, 0.03, 0), 0.45 * clink)
		cans[c].global_rotation = Vector3.ZERO
	if tt < 1.2:
		_bub[veikko] = "Kaljat on mulla."
	else:
		_bub.erase(veikko)
	if clink >= 1.0 and not _once.has("kilis"):
		_once["kilis"] = true
		Sfx.play("glass", -2.0, 1.0)
		Sfx.play("glass", -4.0, 1.15)
		Sfx.play("fire", -6.0, 1.3)
		_sparks.restart()
		_sparks.emitting = true
	if tt > 2.0:
		_bub[raimo] = "Viimeiselle sepälle!"
	# Kuva tulisijan yli: tuli alhaalla etualalla, kolme päätä ja tölkit keskellä.
	var pts := [m]
	for c: Node3D in [veikko, raimo, me]:
		pts.append(_hd(c, 0.32))
		pts.append(_hd(c, -0.7))
	_frame(_K(TOAST.x + 0.2, 2.05, TOAST.y - 2.55), pts, 1.06)


func _step_leike(_delta: float) -> void:
	# Raimo painaa lehden seinään "Tarinoiden liioittelu kielletty" -kyltin viereen ja kääntyy.
	var ct: Transform3D = Kota.clip_transform()
	var n_l := ct.basis * Vector3(0, 0, 1)  # seinästä kohti tulta
	var tg_l := ct.basis * Vector3(1, 0, 0)  # seinän suuntaan, kyltistä poispäin
	var clip_g := kota.to_global(ct.origin)
	var press := clampf((_t - 0.3) / 0.9, 0.0, 1.0)
	var at := _clip_stand()
	var eye_l := ct.origin + n_l * 1.5 - tg_l * 1.05
	eye_l.y = 1.6
	if _t < 2.0:
		_face(raimo, Vector2(ct.origin.x, ct.origin.z))
		var side := kota.global_basis * (ct.basis * Vector3(0.17, 0, 0))
		var off := kota.global_basis * (n_l * 0.3 * (1.0 - press))
		var hr := clip_g + off + side
		var hl := clip_g + off - side
		if raimo.to_global(raimo.bone_position("upperarm_r")).distance_to(hl) < raimo.to_global(raimo.bone_position("upperarm_r")).distance_to(hr):
			var tmp := hr
			hr = hl
			hl = tmp
		_reach_g(raimo, "r", hr)
		_reach_g(raimo, "l", hl)
		if press < 1.0:
			paper.visible = true
			paper.scale = Vector3.ONE
			# Lehti seinän suuntaisena käsien välissä, painuu seinään.
			paper.transform = Transform3D(ct.basis, ct.origin + n_l * 0.3 * (1.0 - press))
		else:
			paper_on_wall = true
			_paper_on_wall()
			if not _once.has("naputus"):
				_once["naputus"] = true
				Sfx.play("step_wood", -4.0, 1.4)
	else:
		raimo.clear_ik()
		paper_on_wall = true
		_paper_on_wall()
		_face(raimo, Vector2(eye_l.x, eye_l.z))
		var sg := kota.to_global(LIIOITTELU)
		var side_p := "l" if raimo.to_global(raimo.bone_position("upperarm_l")).distance_to(sg) < raimo.to_global(raimo.bone_position("upperarm_r")).distance_to(sg) else "r"
		_point(raimo, side_p, sg, clampf((_t - 2.1) / 0.4, 0.0, 1.0))
	if _t > 2.2 and _t < 4.4:
		_bub[raimo] = "Tarinoiden liioittelu kielletty. Ei ollu liioittelua."
	elif _t >= 4.4:
		_bub[raimo] = "Ei ollu, Veikko?"
	_face(me, at)
	_hold_can(veikko)
	_hold_can(me)
	# Kuva vinosti kyltin puolelta: kyltti lähinnä, leike, Raimo leikkeen toisella puolella kasvot kameraan.
	var tg := ct.basis * Vector3(1, 0, 0)
	_frame(kota.to_global(eye_l), [_hd(raimo, 0.32), kota.to_global(ct.origin + Vector3(0, -0.28, 0)), kota.to_global(LIIOITTELU + Vector3(0, 0.22, 0)),
		kota.to_global(LIIOITTELU - Vector3(0, 0.25, 0)), kota.to_global(ct.origin + tg * 0.2)], 1.1)


func _step_otsikko(_delta: float) -> void:
	# Raimo ja Veikko istuvat kaljoineen, Raimo nostaa tölkin; pelaaja seisoo tulen vieressä.
	for c in [raimo, veikko, me]:
		_hold_can(c)
	if _t < 2.6:
		_bub[raimo] = "Ukki ois ylpee. Ja se viimeinen seppä kans."
	else:
		_bub.erase(raimo)
	var pts := []
	for c: Node3D in [raimo, veikko, me]:
		pts.append(_hd(c, 0.35))
		pts.append(c.global_position + Vector3(0, 0.25, 0))
	_frame(_K(0.95, 1.9, -2.45), pts, 1.06)


# --- Esineet ja asennot -------------------------------------------------------------

## Lehti kahdessa kädessä: "read" = rinnan edessä etusivu lukijaan päin, "show" = ojennettuna ylös etusivu ulospäin.
func _hold_paper(c: Node3D, mode: String) -> void:
	paper.visible = true
	paper.scale = Vector3.ONE
	var shr: Vector3 = c.bone_position("upperarm_r")
	var shl: Vector3 = c.bone_position("upperarm_l")
	var chest := (shr + shl) / 2.0
	var sr := signf(shr.x) if shr.x != 0.0 else 1.0
	var dy := -0.3
	var dz := -0.32
	if mode == "show":
		dy = -0.2
		dz = -0.42
	var tr := chest + Vector3(sr * 0.17, dy, dz)
	var tl := chest + Vector3(-sr * 0.17, dy, dz)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", tr, shr + Vector3(sr * 0.45, -0.35, 0.15))
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", tl, shl + Vector3(-sr * 0.45, -0.35, 0.15))
	var mid := (_hand(c, "r") + _hand(c, "l")) / 2.0
	if mode == "show":
		paper.global_position = mid + c.global_basis * Vector3(0, 0.0, -0.02)
		paper.global_rotation = Vector3(0.08, c.global_rotation.y + PI, 0)
	else:
		paper.global_position = mid + c.global_basis * Vector3(0, 0.02, -0.03)
		paper.global_rotation = Vector3(-0.2, c.global_rotation.y, 0)


func _paper_on_lap(c: Node3D) -> void:
	paper.visible = true
	paper.scale = Vector3(0.5, 0.5, 1.0)
	var fwd := c.global_basis * Vector3(0, 0, -1)
	paper.global_position = c.global_position + Vector3(0, 0.66, 0) + fwd * 0.18 - c.global_basis.x * 0.15
	paper.global_rotation = Vector3(-PI / 2.0, c.global_rotation.y, 0)


func _paper_on_wall() -> void:
	paper.visible = true
	paper.scale = Vector3.ONE
	paper.transform = Kota.clip_transform()


func _hold_can(c: Node3D) -> void:
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var raise := 0.0
	if c == raimo and phase == "otsikko":
		raise = clampf((_t - 0.6) / 0.6, 0.0, 1.0) * (1.0 - clampf((_t - 3.2) / 0.6, 0.0, 1.0))
	var tgt := sh + Vector3(s * 0.08, -0.3 + 0.35 * raise, -0.3 - 0.05 * raise)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", tgt, sh + Vector3(s * 0.45, -0.3, 0.2))
	cans[c].visible = true
	cans[c].global_position = _hand(c, "r") + Vector3(0, 0.03, 0)
	cans[c].global_rotation = Vector3.ZERO


## Käsi (side "r"/"l") kohti maailman pistettä painolla w.
func _reach_g(c: Node3D, side: String, at_global: Vector3, w := 1.0) -> void:
	var sh: Vector3 = c.bone_position("upperarm_" + side)
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at_global), w)
	c.set_ik("arm_" + side, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, tgt, sh + Vector3(s * 0.45, -0.25, 0.25))


## Osoitus: käsi suorana kohti pistettä (käsivarren mitan päähän).
func _point(c: Node3D, side: String, at_global: Vector3, w: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm_" + side)
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var d := (c.to_local(at_global) - sh).normalized()
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(sh + d * 0.56, w)
	c.set_ik("arm_" + side, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, tgt, sh + Vector3(s * 0.3, -0.45, 0.25))


func _relax(c: Node3D) -> void:
	c.set_override("spine_01", Vector3.RIGHT, 0.0)
	c.set_override("neck_01", Vector3.RIGHT, 0.0)


func _sit(c: Node3D, at: Vector2) -> void:
	c.position = Vector3(at.x, FLOOR, at.y)
	var f := _fwd_of(at)
	c.rotation.y = B.yaw_to(Vector3(f.x, 0, f.y))
	c.play("Sitting_Idle", 0.0)


func _stand(c: Node3D, at: Vector2) -> void:
	c.position = Vector3(at.x, FLOOR, at.y)
	if c != me or phase != "lehti":
		c.play("Idle", 0.2)


func _face(c: Node3D, at: Vector2) -> void:
	var v := Vector3(at.x - c.position.x, 0, at.y - c.position.z)
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


## Istuimelta tulta kohti (kodan paikallinen xz).
func _fwd_of(seat: Vector2) -> Vector2:
	return -seat.normalized()


## Raimon paikka leikkeen edessä (0,5 m seinästä kodan keskustaa kohti).
func _clip_stand() -> Vector2:
	var ct := Kota.clip_transform()
	var p := ct.origin + ct.basis * Vector3(0.4, 0, 0.5)  # 0,5 m seinästä, 0,4 m sivuun kyltistä poispäin (ei kyltin eteen)
	return Vector2(p.x, p.z)


## Kumpi olka ("l"/"r") on lähempänä pistettä.
func _near_side(c: Node3D, at_global: Vector3) -> String:
	var l := c.to_global(c.bone_position("upperarm_l")).distance_to(at_global)
	var r := c.to_global(c.bone_position("upperarm_r")).distance_to(at_global)
	return "l" if l < r else "r"


func _hand(c: Node3D, side: String) -> Vector3:
	return c.to_global((c.bone_position("hand_" + side) + c.bone_position("index_01_" + side)) / 2.0)


# --- Kehys, kamera ------------------------------------------------------------------

## Kodan paikallinen piste (x, y, z) maailmaan.
func _K(x: float, y: float, z: float) -> Vector3:
	return kota.to_global(Vector3(x, y, z))


func _hd(c: Node3D, up: float) -> Vector3:
	return c.to_global(c.bone_position("Head")) + Vector3(0, up, 0)


## Kamera silmästä niin, että kaikki pisteet mahtuvat kuvaan (keskelle pisteiden keskiö, pystykenttä laskettuna,
## pad = marginaali). Pystykenttä enintään 80°.
func _frame(eye: Vector3, pts: Array, pad := 1.1) -> void:
	var c := Vector3.ZERO
	for p: Vector3 in pts:
		c += p
	c /= float(pts.size())
	_cam.look_at_from_position(eye, c)
	var inv := _cam.global_basis.inverse()
	var vs := get_viewport().get_visible_rect().size
	var asp := vs.x / vs.y
	var m := 0.05
	for p: Vector3 in pts:
		var l := inv * (p - eye)
		var d := -l.z
		if d < 0.05:
			continue
		m = maxf(m, maxf(absf(l.y) / d, absf(l.x) / d / asp))
	_cam.fov = minf(80.0, rad_to_deg(2.0 * atan(m * pad)))


func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(eye, look)


func _fov_w(d: float, w: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return rad_to_deg(2.0 * atan(w / (2.0 * d) / (vs.x / vs.y)))


# --- Piirto -------------------------------------------------------------------------

func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 440, 24, 880, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	if phase != "otsikko" or _t < 1.0:
		for c: Node3D in _bub:
			if is_instance_valid(c) and c.visible:
				Room.bubble(_ui, _cam, c, _bub[c], 90.0, 120.0)
	if phase == "otsikko":
		var a := clampf((_t - 0.9) / 0.9, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.06, 0.03, 0.01, 0.25 * a))
		var y := vs.y * 0.17
		_draw_axe_icon(Vector2(vs.x / 2.0, y - 72.0), a)
		var title := "VIIMEISEN SEPÄN KIRVES"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.12, 0.05, 0.02, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(1.0, 0.8, 0.45, a))
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 158.0, 840, 84)
		_ui.draw_rect(sr, Color(0.06, 0.03, 0.02, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Kertunkankaan legenda todistettu",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(1.0, 0.72, 0.4, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Raimo oli oikeassa, ja Veikko tarjosi.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Kirves otsikon yllä: varsi, ruosteinen terä ja kiiltävä terän särmä (tumma ääriviiva).
func _draw_axe_icon(c: Vector2, a: float) -> void:
	var dark := Color(0.12, 0.05, 0.02, a)
	var h0 := c + Vector2(-34, 30)
	var h1 := c + Vector2(26, -26)
	_ui.draw_line(h0, h1, dark, 11.0)
	_ui.draw_line(h0, h1, Color(0.62, 0.42, 0.22, a), 7.0)
	var blade := PackedVector2Array([c + Vector2(14, -38), c + Vector2(40, -30), c + Vector2(46, -4), c + Vector2(30, 0), c + Vector2(20, -18)])
	_ui.draw_colored_polygon(blade, Color(0.55, 0.32, 0.18, a))
	var loop := blade.duplicate()
	loop.append(blade[0])
	_ui.draw_polyline(loop, dark, 3.0)
	_ui.draw_line(c + Vector2(40, -30), c + Vector2(46, -4), Color(0.95, 0.92, 0.85, a), 3.0)
