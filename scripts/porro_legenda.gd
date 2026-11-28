extends CanvasLayer
## Legendaarinen hetki "porron_kyltti" (Pörrön muistokyltti): kun muistolauta on maalattu ja naulattu
## (muistokyltti_game.gd, main.gd _start_muistokyltti), hetki lavastetaan Lemmikki Enkelien muistolehdossa. Vaiheet:
##   lehto   kyltti tolpassa, lyhty syttyy; pojat tuovat pikkuveljen katsomaan ("Onko toi Pörrön?" / "On. Setä maalas.")
##   kukka   pikkuveli kyykistyy ja laskee voikukan kyltin juurelle, isommat pojat painavat päänsä
##   kivet   pojat kaivavat taskuistaan kivet, jotka oli tarkoitettu sedälle, ja asettavat ne yksi kerrallaan kyltin
##           juurelle ("Nää oli setää varten." / "Nyt ne on Pörrön." / "Ei heitetä enää.")
##   seta    pojat kääntyvät pelaajaan: "Setä on ihan ok." Pikkuveli vilkuttaa, pelaaja nyökkää
##   otsikko pojat lähtevät portille, kyltti, kivet ja kukka lyhdyn valossa; PÖRRÖN MUISTOKYLTTI
## Kivet ja voikukka jäävät lehtoon pysyvästi (world.gd _build_lemmikki: stone(), voikukka() Pörrön tolpan juurelle).
## Kehys: lehdon solmu G (world.lehto_plate:n vanhempi): paikallinen +Z = rakennukseen ja portille päin, kylttien
## lukupuoli -Z (penkin puoli). Pörrön tolppa G:ssä (3,6, 0, -0,6). Hahmojen etu -Z (Looks).

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")

const T := {"lehto": 5.0, "kukka": 5.4, "kivet": 6.6, "seta": 5.4, "otsikko": 6.4}
const ORDER := ["lehto", "kukka", "kivet", "seta", "otsikko"]
const POST := Vector2(3.6, -0.6)  # Pörrön tolppa G:ssä
## Kivien ja kukan paikat tolpan juurella (tolpan kehyksessä, x, z; -Z lukupuoli). Sama world.gd:n pysyvissä.
const STONES := [Vector2(-0.28, -0.1), Vector2(0.28, -0.1), Vector2(0.16, -0.34)]
const FLOWER := Vector2(-0.06, -0.24)
## Pikkuveli: isoveljiä pienempi, vaalea tukka, vihreä paita.
const PIKKUVELI := {"shirt": Color(0.42, 0.72, 0.42), "pants": Color(0.25, 0.3, 0.5), "shoes": Color(0.92, 0.92, 0.95),
	"shoe": "lenkkari", "hair": "Hair_SimpleParted", "hair_color": Color(0.92, 0.8, 0.52), "height": 1.1, "bulk": -0.85,
	"shoulders": -0.9}
## Pojat muistelevat myöhemmin (main.gd _talk_lemmikki "lemmikki_porro").
const MUISTO := ["Me käytiin eilen Pörrön luona. Kivet on vielä siinä, ja pikkuveli vei uuden voikukan.",
	"Pikkuveli sanoo kaikille, että setä maalas Pörrölle kyltin. Se ei enää itke.",
	"Me ei heitetä enää kiviä. Ne on Pörrön. Setä on ihan ok.",
	"Lemmikki Enkelien täti sanoi, että Pörrön kyltti on lehdon kaunein."]

var world: Node3D
var hide_nodes: Array = []  # oikeat pojat ja jalan kulkeva pelaaja piiloon kohtauksen ajaksi (kopiot näyttelevät)
var _was_visible := {}

var phase := ""
var _t := 0.0
var _cam: Camera3D
var _ui: Control
var _keys: Node
var _story := ""
var _bub := {}  # hahmo -> repliikki
var _once := {}
var _G: Node3D
var _post: Node3D  # world.lehto_plate (Pörrön tolppa)
var _props: Array[Node3D] = []
var _hidden_muisto: Array[Node3D] = []  # tolpan pysyvät kivet ja kukka piiloon kohtauksen ajaksi
var me: Node3D
var veli: Node3D
var pojat: Array[Node3D] = []
var flower: Node3D
var stones: Array[Node3D] = []
var carried := {}  # esine -> kantaja (seuraa kättä)
var placed := {}  # esine -> laskuhetken käden etäisyys (testi lukee)
var _lamp: OmniLight3D


func _ready() -> void:
	layer = 6
	_post = world.lehto_plate
	_G = _post.get_parent()
	_post.visible = true
	for c in _post.get_children():
		if c.has_meta("porro_muisto"):
			c.visible = false
			_hidden_muisto.append(c)
	_cam = Camera3D.new()
	world.add_child(_cam)
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
	for n in hide_nodes:
		if is_instance_valid(n):
			_was_visible[n] = (n as Node3D).visible
			(n as Node3D).visible = false
	_build()
	_begin("lehto")


func _build() -> void:
	me = _person(Looks.player(), 1.85, -2.2)
	veli = _person(PIKKUVELI, 1.4, -3.2)
	var spots := [Vector2(2.75, -2.0), Vector2(3.65, -2.45), Vector2(4.55, -2.05)]
	for i in 3:
		pojat.append(_person(Looks.POJAT[i], spots[i].x, spots[i].y))
	# Voikukka pikkuveljen kädessä, kivet poikien taskuissa (näkyvät, kun ne kaivetaan esiin).
	flower = Node3D.new()
	world.add_child(flower)
	_props.append(flower)
	voikukka(flower)
	for i in 3:
		var s := Node3D.new()
		world.add_child(s)
		_props.append(s)
		stone(s, i)
		s.visible = false
		stones.append(s)
	# Lämmin valo kyltin luo (lyhty syttyy lehto-vaiheessa).
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.78, 0.45)
	_lamp.omni_range = 3.2
	_lamp.light_energy = 0.0
	_lamp.shadow_enabled = false
	world.add_child(_lamp)
	_props.append(_lamp)
	_lamp.global_position = _L(POST.x + 0.28, POST.y + 0.1, 0.45)  # tolpan lyhdyn kohdalla


func _person(look: Dictionary, x: float, z: float) -> Node3D:
	var c: Node3D = Looks.make(world, look)
	_props.append(c)
	c.global_position = _L(x, z)
	c.play("Idle", 0.0)
	_face(c, _L(POST.x, POST.y))
	return c


## Pysyvä kivi (i = 0..2): harmaa, litteähkö pyöreä kivi; vaalea yläpinta, tumma pohja ja sammaltäplä.
static func stone(parent: Node3D, i: int) -> void:
	var cols := [Color(0.52, 0.5, 0.47), Color(0.6, 0.56, 0.5), Color(0.45, 0.45, 0.48)]
	var sz := [Vector3(0.11, 0.065, 0.085), Vector3(0.09, 0.06, 0.1), Vector3(0.1, 0.055, 0.08)]
	var col: Color = cols[i]
	var s: Vector3 = sz[i]
	var body := B.mesh(parent, B.sphere(0.5, 12), Vector3(0, s.y * 0.45, 0), col)
	body.scale = s
	body.rotation.y = i * 1.3
	var top := B.mesh(parent, B.sphere(0.5, 10), Vector3(-0.01, s.y * 0.7, 0.005), col.lightened(0.22))
	top.scale = Vector3(s.x * 0.7, s.y * 0.45, s.z * 0.65)
	var moss := B.mesh(parent, B.sphere(0.5, 8), Vector3(s.x * 0.22, s.y * 0.62, -s.z * 0.15), Color(0.35, 0.45, 0.2))
	moss.scale = Vector3(0.035, 0.02, 0.03)


## Pysyvä voikukka: vihreä varsi, sahalaitaiset lehdet maassa ja keltainen kukinto (tumma keskus).
static func voikukka(parent: Node3D) -> void:
	var green := Color(0.28, 0.55, 0.18)
	var stem := B.mesh(parent, B.cyl(0.005, 0.006, 0.17, 6), Vector3(0, 0.085, 0), green)
	stem.rotation.z = 0.12
	for k in 4:
		var leaf := B.mesh(parent, B.boxm(Vector3(0.028, 0.004, 0.11)), Vector3.ZERO, green.darkened(0.1))
		var a := k * TAU / 4.0 + 0.4
		leaf.position = Vector3(sin(a) * 0.05, 0.006, cos(a) * 0.05)
		leaf.rotation.y = a
		leaf.rotation.x = -0.15
	var head := Node3D.new()
	head.position = Vector3(-0.011, 0.172, 0)
	parent.add_child(head)
	var petals := B.mesh(head, B.sphere(0.5, 12), Vector3.ZERO, Color(1.0, 0.82, 0.1))
	petals.scale = Vector3(0.05, 0.022, 0.05)
	var rim := B.mesh(head, B.sphere(0.5, 12), Vector3(0, -0.004, 0), Color(0.98, 0.7, 0.05))
	rim.scale = Vector3(0.058, 0.012, 0.058)
	var mid := B.mesh(head, B.sphere(0.5, 8), Vector3(0, 0.008, 0), Color(0.9, 0.6, 0.05))
	mid.scale = Vector3(0.022, 0.012, 0.022)


func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	for c in [me, veli] + pojat:
		c.clear_ik()
		_relax(c)
	match p:
		"lehto":
			_story = "Pörrön kyltti on tolpassa. Pojat tuovat pikkuveljen katsomaan."
			flower.visible = true
		"kukka":
			_story = "Pikkuveli tuo voikukan. Pörrö söi niitä aina vähän liikaa."
			_stand(veli, POST.x - 0.02, POST.y - 0.62)
			veli.play("Crouch_Idle", 0.3)
			_face(veli, _L(POST.x, POST.y))
		"kivet":
			_story = "Kivet oli tarkoitettu sedälle."
			_drop_on_ground(flower, FLOWER, true)
			_stand(veli, 2.95, -1.55)
			veli.play("Idle", 0.3)
			_face(veli, _L(POST.x, POST.y))
		"seta":
			_story = ""
			for i in 3:
				_drop_on_ground(stones[i], STONES[i], true)
			var spots := [Vector2(2.75, -1.75), Vector2(3.55, -2.05), Vector2(4.35, -1.75)]
			for i in 3:
				_stand(pojat[i], spots[i].x, spots[i].y)
				pojat[i].play("Idle", 0.3)
			_stand(veli, 2.95, -1.55)
			veli.play("Idle", 0.3)
			Sfx.play("win_small", -10.0, 0.8)
		"otsikko":
			_story = ""
			_drop_on_ground(flower, FLOWER, true)
			for i in 3:
				_drop_on_ground(stones[i], STONES[i], true)
			for c in [veli] + pojat:
				c.play("Walk", 0.3)
			_stand(veli, 2.95, -1.55)
			Sfx.play("win", -6.0, 0.9)


func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("interact"):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"lehto":
			_step_lehto(delta)
		"kukka":
			_step_kukka(delta)
		"kivet":
			_step_kivet(delta)
		"seta":
			_step_seta(delta)
		"otsikko":
			_step_otsikko(delta)
	_lamp.light_energy = lerpf(_lamp.light_energy, 0.55 + 0.06 * sin(_t * 11.0) * sin(_t * 3.7), minf(1.0, delta * 2.0))
	_follow_hands()
	_ui.queue_redraw()
	if phase != "" and _t >= T[phase]:
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
	for c in _hidden_muisto:
		if is_instance_valid(c):
			c.visible = true
	for n in _was_visible:
		if is_instance_valid(n):
			(n as Node3D).visible = _was_visible[n]
	finished.emit()
	_cam.queue_free()
	queue_free()


# --- Vaiheet ------------------------------------------------------------------------

func _step_lehto(delta: float) -> void:
	# Pikkuveli kävelee isoveljien välistä kyltin eteen ja pysähtyy katsomaan.
	var k := clampf((_t - 0.6) / 2.6, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var a := Vector2(1.4, -3.2)
	var b := Vector2(POST.x - 0.35, POST.y - 1.05)
	var p := a.lerp(b, e)
	_stand(veli, p.x, p.y)
	veli.play("Walk" if k > 0.0 and k < 1.0 else "Idle", 0.2)
	_face(veli, _L(POST.x, POST.y) if k >= 1.0 else _L(b.x, b.y))
	_carry(flower, veli, false)
	for c in pojat:
		_face(c, veli.global_position.lerp(_L(POST.x, POST.y), 0.5))
	_face(me, _L(POST.x, POST.y))
	if _t > 2.4:
		_bub[veli] = "Onko toi Pörrön?"
	if _t > 3.6:
		_bub[pojat[0]] = "On. Setä maalas."
	# Kamera rakennuksen puolelta yli tolpparivin: Pörrön kyltti, lyhty, pojat ja pelaaja (leveys 4 m lasketaan).
	var look := _L(3.05, -1.7, 0.95)
	var eye := _L(4.9, 2.9, 2.3)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 5.0))


func _step_kukka(delta: float) -> void:
	# Pikkuveli kyykyssä ojentaa voikukan kyltin juurelle; isoveljet painavat päänsä.
	var reach := clampf((_t - 0.7) / 1.4, 0.0, 1.0)
	var at := _postL(FLOWER.x, FLOWER.y, 0.04)
	if _t < 2.6:
		_reach(veli, at, reach, true)
		_carry(flower, veli, true)
	else:
		_drop_on_ground(flower, FLOWER)
		_reach(veli, at, 1.0 - clampf((_t - 2.6) / 0.8, 0.0, 1.0), true)
		if not _once.has("kukka"):
			_once["kukka"] = true
			Sfx.play("cloth", -10.0, 1.3)
	if _t > 2.9:
		_bub[veli] = "Hei Pörrö. Tässä sulle."
	for c in pojat:
		c.set_override("neck_01", Vector3.RIGHT, 0.45 * clampf((_t - 0.4) / 1.0, 0.0, 1.0))
		_face(c, _L(POST.x, POST.y))
	me.set_override("neck_01", Vector3.RIGHT, 0.3 * clampf((_t - 0.8) / 1.0, 0.0, 1.0))
	# Matala kuva tolpan takaa (rakennuksen puolelta): kyltin teksti, pikkuveljen kasvot ja kukka, isoveljet taustalla.
	var look := _L(POST.x - 0.15, POST.y - 0.7, 0.55)
	var eye := _L(POST.x + 1.0, POST.y + 1.35, 1.15)
	_cam_at(eye, look, _fov_for(eye.distance_to(look), 1.5, 0.82))


func _step_kivet(delta: float) -> void:
	# Pojat yksi kerrallaan: kivi taskusta, askel kyltille, kyykky, kivi juurelle, takaisin seisomaan.
	var lines := ["Nää oli setää varten.", "Nyt ne on Pörrön.", "Ei heitetä enää."]
	var spots := [Vector2(2.75, -2.0), Vector2(3.65, -2.45), Vector2(4.55, -2.05)]
	for i in 3:
		var c: Node3D = pojat[i]
		var t0 := 0.2 + i * 2.05
		var lt := _t - t0
		var st: Vector2 = STONES[i]
		var target := _postL(st.x, st.y, 0.035)
		# Kyykkypaikka: kiven kohdalta poispäin tolpasta (lukupuolelle).
		var kneel := _post_xz(st.x * 1.05, st.y - 0.2)
		var home: Vector2 = spots[i]
		if lt < 0.0:
			c.set_override("neck_01", Vector3.RIGHT, 0.35)
			continue
		if lt < 0.5:  # kivi taskusta
			stones[i].visible = true
			_hand_to_pocket(c, lt / 0.5)
			_carry(stones[i], c, false)
			_bub[c] = lines[i]
		elif lt < 1.0:  # askel kyltille
			var k := (lt - 0.5) / 0.5
			var p := home.lerp(kneel, k * k * (3.0 - 2.0 * k))
			_stand(c, p.x, p.y)
			c.play("Walk", 0.15)
			_face(c, _postL(st.x, st.y))
			_carry(stones[i], c, false)
			_bub[c] = lines[i]
		elif lt < 1.75:  # kyykky ja kivi juurelle
			_stand(c, kneel.x, kneel.y)
			c.play("Crouch_Idle", 0.15)
			_face(c, _postL(st.x, st.y))
			var r := clampf((lt - 1.0) / 0.5, 0.0, 1.0)
			_reach(c, target, r, true)
			if r < 1.0:
				_carry(stones[i], c, true)
			else:
				if not placed.has(stones[i]):
					placed[stones[i]] = _hand(c).distance_to(target)
					Sfx.play("step_hard", -4.0, 1.6 + i * 0.12)
				_drop_on_ground(stones[i], st)
			_bub[c] = lines[i]
		else:  # takaisin paikalle
			_bub.erase(c)
			_drop_on_ground(stones[i], st)
			c.clear_ik()
			c.set_override("spine_01", Vector3.RIGHT, 0.0)
			var k := clampf((lt - 1.75) / 0.5, 0.0, 1.0)
			var p := kneel.lerp(home, k)
			_stand(c, p.x, p.y)
			c.play("Walk" if k < 1.0 else "Idle", 0.2)
			_face(c, _L(POST.x, POST.y))
			c.set_override("neck_01", Vector3.RIGHT, 0.3)
	_face(veli, _L(POST.x, POST.y))
	if _t > 4.5:
		_story = "Nyt ne on Pörrön."
	# Matala kuva tolpan takaa rakennuksen puolelta: kyltin juuri, kyykkyvän pojan kasvot ja muut pojat taustalla.
	var look := _L(POST.x - 0.05, POST.y - 0.75, 0.5)
	var eye := _L(POST.x + 1.75, POST.y + 1.25, 1.25)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 2.9))


func _step_seta(delta: float) -> void:
	# Pojat kääntyvät pelaajaan, isoveli sanoo sen, pikkuveli vilkuttaa, pelaaja nyökkää.
	for c in pojat:
		_face(c, me.global_position)
	_face(veli, me.global_position)
	_face(me, pojat[1].global_position)
	if _t > 0.6 and _t < 3.0:
		_bub[pojat[0]] = "Setä on ihan ok."
	else:
		_bub.erase(pojat[0])
	if _t > 1.9:
		_bub[pojat[2]] = "Ihan ok."
	if _t > 2.6:
		# Pikkuveli juoksee pelaajan eteen ja vilkuttaa.
		var k := clampf((_t - 2.6) / 0.6, 0.0, 1.0)
		var p := Vector2(2.95, -1.55).lerp(Vector2(2.5, -2.3), k)
		_stand(veli, p.x, p.y)
		veli.play("Walk" if k < 1.0 else "Idle", 0.15)
		_face(veli, me.global_position)
	if _t > 3.2:
		_bub[veli] = "Kiitti, setä!"
		_wave(veli, _t)
	if _t > 1.4:
		me.set_override("neck_01", Vector3.RIGHT, 0.22 * maxf(0.0, sin((_t - 1.4) * 3.2)))
	# Kaksoiskuva tolpparivin takaa (rakennuksen puolelta): pelaaja vasemmalla, pojat oikealla, Pörrön kyltin selkä
	# oikeassa etualassa.
	var look := _L(2.95, -2.0, 0.95)
	var eye := _L(2.45, 0.7, 1.55)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 3.8))


func _step_otsikko(delta: float) -> void:
	# Pojat lähtevät portille tolppien välistä, pelaaja jää kyltin luo.
	var path := [Vector2(2.95, -1.55), Vector2(2.4, -0.6), Vector2(2.4, 3.6)]
	var ks := [0.0, 0.5, 0.85, 1.2]
	var all := [veli] + pojat
	for j in all.size():
		var c: Node3D = all[j]
		var u := maxf(0.0, (_t - ks[j]) * 0.9)
		var p := _along(path, u)
		var off := Vector2(0.35 * (j - 1.5), 0.0) if u > 0.0 else Vector2.ZERO
		if u <= 0.0:
			var base := [Vector2(2.95, -1.55), Vector2(2.75, -1.75), Vector2(3.55, -2.05), Vector2(4.35, -1.75)]
			p = base[j]
			off = Vector2.ZERO
		_stand(c, p.x + off.x * minf(u, 1.0), p.y)
		var nxt := _along(path, u + 0.3)
		if u > 0.0:
			_face(c, _L(nxt.x + off.x, nxt.y))
			c.play("Walk", 0.2)
	if _t < 1.2:
		_bub[veli] = "Moikka Pörrö!"
	else:
		_bub.erase(veli)
	_face(me, _L(POST.x, POST.y))
	# Kuva penkin puolelta kylttiin: kyltti, kivet ja kukka lyhdyn valossa, pojat lähtevät taustalla.
	var look := _L(POST.x - 0.45, POST.y + 0.4, 0.34)
	var eye := _L(POST.x + 0.7, POST.y - 3.4, 1.45)
	_cam_at(eye, look, _fov_w(eye.distance_to(look), 4.5))


func _along(path: Array, u: float) -> Vector2:
	var left := u
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var l := a.distance_to(b)
		if left <= l:
			return a.lerp(b, left / l)
		left -= l
	return path[path.size() - 1]


# --- Hahmot ja esineet --------------------------------------------------------------

## Ohitukset nollaan (ei clear_overrides: luut, joilla ei ole animaatioraitaa, jäisivät viimeiseen kulmaan, ja selkä
## jäisi kumaraan; nollakulmainen ohitus palauttaa luun lepoon joka ruutu).
func _relax(c: Node3D) -> void:
	c.set_override("spine_01", Vector3.RIGHT, 0.0)
	c.set_override("neck_01", Vector3.RIGHT, 0.0)


func _stand(c: Node3D, x: float, z: float) -> void:
	c.global_position = _L(x, z)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.global_position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


func _hand(c: Node3D) -> Vector3:
	return c.to_global((c.bone_position("hand_r") + c.bone_position("index_01_r")) / 2.0)


## Oikea käsi kohti maassa olevaa pistettä (w 0..1), selkä kumaraan, kyynärpää ulos.
func _reach(c: Node3D, at_global: Vector3, w: float, lean: bool) -> void:
	if lean:
		c.set_override("spine_01", Vector3.RIGHT, -0.6 * w)
		c.set_override("neck_01", Vector3.RIGHT, 0.3 * w)
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at_global) + Vector3(0, 0.02, 0), w)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", tgt, sh + Vector3(s * 0.45, -0.25, 0.25))


## Käsi taskulle ja ylös eteen (kivi esiin).
func _hand_to_pocket(c: Node3D, k: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var pocket := sh + Vector3(s * 0.16, -0.5, 0.02)
	var front := sh + Vector3(s * 0.06, -0.28, -0.3)
	var u := clampf(k * 2.0, 0.0, 1.0) if k < 0.5 else 1.0 - clampf((k - 0.5) * 2.0, 0.0, 1.0)
	var tgt := front.lerp(pocket, u) if k < 0.5 else pocket.lerp(front, clampf((k - 0.5) * 2.0, 0.0, 1.0))
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", tgt, sh + Vector3(s * 0.45, -0.3, 0.2))


func _wave(c: Node3D, t: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", sh + Vector3(s * (0.16 + 0.12 * sin(t * 8.0)), 0.36, -0.1),
		sh + Vector3(s * 0.4, 0.0, 0.25))


## Esine kantajan oikeaan käteen (seuraa joka ruutu _follow_hands).
func _carry(item: Node3D, c: Node3D, _reaching: bool) -> void:
	item.visible = true
	carried[item] = c


## Esine maahan tolpan juurelle (snap: heti, muuten liukuu pudotuksena muutamassa ruudussa).
func _drop_on_ground(item: Node3D, at: Vector2, snap := false) -> void:
	carried.erase(item)
	item.visible = true
	var g := _postL(at.x, at.y, 0.0)
	item.global_position = g if snap or item.global_position.distance_to(g) < 0.01 else item.global_position.lerp(g, 0.35)
	item.rotation = Vector3(0, _post.global_rotation.y, 0)


func _follow_hands() -> void:
	for item: Node3D in carried:
		var c: Node3D = carried[item]
		if is_instance_valid(c):
			item.global_position = _hand(c) - Vector3(0, 0.03, 0)


# --- Kehys, kamera ------------------------------------------------------------------

## Lehdon paikallinen piste (x, z) + y. Lehdon pinta on tasainen tolppien juurten tasossa (G:n y = 0); Terrain.h jää
## siellä 0,2–0,3 m näkyvän pinnan alle, joten sitä ei käytetä.
func _L(x: float, z: float, y := 0.0) -> Vector3:
	return _G.to_global(Vector3(x, y, z))


## Piste Pörrön tolpan kehyksessä (x, z) maanpinnalla + y.
func _postL(x: float, z: float, y := 0.0) -> Vector3:
	return _L(POST.x + x, POST.y + z, y)


func _post_xz(x: float, z: float) -> Vector2:
	return Vector2(POST.x + x, POST.y + z)


func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(eye, look)


## Kuvakulma (pystysuora), jolla leveys w etäisyydellä d mahtuu kuvaan vaakasuunnassa.
func _fov_w(d: float, w: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return rad_to_deg(2.0 * atan(w / (2.0 * d) / (vs.x / vs.y)))


## Kuvakulma, jolla korkeus h etäisyydellä d täyttää osuuden frac kuvan korkeudesta.
func _fov_for(d: float, h: float, frac: float) -> float:
	return rad_to_deg(2.0 * atan(h / (2.0 * d * frac)))


# --- Piirto -------------------------------------------------------------------------

func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 440, 24, 880, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for c: Node3D in _bub:
		if is_instance_valid(c) and c.visible:
			Room.bubble(_ui, _cam, c, _bub[c], 90.0, 120.0)
	if phase == "otsikko":
		var a := clampf((_t - 0.9) / 0.9, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.05, 0.22 * a))
		var y := vs.y * 0.17
		_draw_heart(Vector2(vs.x / 2.0, y - 86.0), a)
		var title := "PÖRRÖN MUISTOKYLTTI"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 64, 12, Color(0.12, 0.04, 0.06, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 64, Color(1.0, 0.84, 0.45, a))
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 158.0, 840, 84)
		_ui.draw_rect(sr, Color(0.05, 0.04, 0.03, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Voikukka ja kolme kiveä Lemmikki Enkelien lehdossa",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(1.0, 0.85, 0.4, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Pojat eivät heitä enää kiviä. Setä on ihan ok.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Sydän otsikon yllä (kuten laudan maalattu sydän): kaksi kaarta ja kärki, tumma ääriviiva.
func _draw_heart(c: Vector2, a: float) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var yv := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, yv) * 2.2)
	_ui.draw_colored_polygon(pts, Color(0.88, 0.42, 0.42, a))
	var loop := pts.duplicate()
	loop.append(pts[0])
	_ui.draw_polyline(loop, Color(0.3, 0.08, 0.08, a), 3.0)
