extends CanvasLayer
## Lettukisa naisen olohuoneessa (kolmiomittauksen iltakiva, K-18 ja vähän rivo): pelaaja ja kaksi kaveria istuvat
## pitkän pöydän takana kasvot kameraan, edessä lautaset kermalettupinoineen, ja nainen seisoo pöydän päässä
## kermavaahtopurkin kanssa ja tuo lisää lettuja. Minuutissa eniten lettuja syönyt voittaa.
## Mekaniikka: haukku (interact) täyttää suuta HAUKKU verran, ja suu tyhjenee pureskellessa NIELU / s. Jos suu menee yli
## täyden, kerma tulee nenästä: yskintä vie YSKA sekuntia. Taito on haukata, kun suussa on tilaa (vihreä alue).
## Letut ovat umpinaisista paloista (kolme sektoria, CLAUDE.md: syötävä esine paloista), ja jokainen haukku vie palan.
## Olohuone ja istuminen: ilta_room.gd. Ruudulla vain käyttöliittymä: tilanne ylhäällä, oma suumittari alhaalla,
## kerronta laatikossa, puhekuplat puhujaan ja näppäinohje (hint_bar, näppäimet asetuksista).

signal finished(result: Dictionary)

const Room := preload("res://scripts/ilta_room.gd")
const B := preload("res://scripts/build.gd")

const CENTER := Vector3(6.0, 0.0, 3.6)  # pöydän keskipiste olohuoneessa (maton keskellä)
const TABLE_H := 0.72
const TABLE := Vector2(2.15, 0.8)  # pöydän leveys (X) ja syvyys (Z)
const SEAT_Z := -0.72  # istujien lantio pöydän keskeltä (-Z = pöydän takapuoli; istujien etu on +Z, kameraa kohti)
const SEAT_X := [0.0, -0.66, 0.66]  # 0 pelaaja keskellä, 1 vasen kaveri, 2 oikea kaveri
const PLATE_Z := -0.18
const LETTU_R := 0.12  # letun säde (oikea lettu noin 20–24 cm): näkyy pelikameralta
const LETTU_H := 0.009
const HAUKKU := 0.27  # suun täyttö yhdestä haukusta (1 = täysi)
const NIELU := 0.17  # suun tyhjenemä sekunnissa
const YSKA := 2.2
const KISA_AIKA := 60.0
const START := 5  # lettuja lautasella alussa
const WOMAN_AT := Vector3(1.4, 0.017, -0.12)  # y: maton paksuus (jalkapohjat eivät painu mattoon)

var site := "saloinen"
var anchor: Node3D
var sun: DirectionalLight3D
var style := {}
## [pelaaja, vasen kaveri, oikea kaveri, nainen]: {"id", "name", "look"}
var people: Array = []
## Repliikit: {"alku": [...], "kerma": [...], "tukehtuu": {id: [...]}, "kommentti": {id: [...]}, "voitto": [...],
## "havio": [...] ("%s" = voittajan nimi)}
var lines := {}
var auto := false  # testi: tekoäly syö pelaajankin puolesta

var _hall: Node3D
var _cam: Camera3D
var _chars: Array = []  # istujat 0..2 ja nainen 3
var _eaters: Array = []  # {"mouth", "cough", "eaten", "bites", "next", "greed", "nod"}
var _stacks: Array = [[], [], []]  # lautasen letut alhaalta ylös: [Node3D (palat lapsina)]
var _kerma: Array = [null, null, null]  # kermanokare päällimmäisen letun päällä
var _bubbles: Array = ["", "", "", ""]
var _bubble_t := [0.0, 0.0, 0.0, 0.0]
var _phase := "alku"  # alku, kisa, loppu, valmis
var _t := 0.0
var _left := KISA_AIKA
var _story := ""
var _ui: Control
var _keys: Node
var _shake := 0.0
var _cam_base: Transform3D
var _comment_t := 6.0
var _serve_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 6
	add_to_group("esc_lopettaa")
	_rng.randomize()
	_build()
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
	_story = "Lettukisa! Minuutti aikaa. Haukkaa, kun suussa on tilaa: liian iso suullinen ja kerma tulee nenästä."
	_say(3, _line("alku", "Lettukisa! Kerma suuhun ja nielkää."))


func _exit_tree() -> void:
	if is_instance_valid(_hall):
		_hall.queue_free()


# --- Olohuone, pöytä, hahmot ja letut -----------------------------------------------------------------------------

func _build() -> void:
	_hall = Room.hall(anchor, style, sun)
	var wood := Room.WOOD
	# Pitkä pöytä: kansi, ruutuliina ja neljä jalkaa.
	B.mesh(_hall, B.boxm(Vector3(TABLE.x, 0.04, TABLE.y)), CENTER + Vector3(0, TABLE_H - 0.02, 0), wood)
	B.mesh(_hall, B.boxm(Vector3(TABLE.x - 0.1, 0.004, TABLE.y - 0.08)), CENTER + Vector3(0, TABLE_H + 0.002, 0),
		Color(0.92, 0.9, 0.84))
	for i in 9:  # liinan punaiset raidat
		B.mesh(_hall, B.boxm(Vector3(0.05, 0.005, TABLE.y - 0.08)), CENTER + Vector3(-0.8 + i * 0.2, TABLE_H + 0.003, 0),
			Color(0.78, 0.16, 0.16))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.mesh(_hall, B.boxm(Vector3(0.06, TABLE_H - 0.04, 0.06)), CENTER + Vector3(sx * (TABLE.x / 2.0 - 0.08),
				(TABLE_H - 0.04) / 2.0, sz * (TABLE.y / 2.0 - 0.08)), wood.darkened(0.15))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.88, 0.66)
	lamp.light_energy = 1.7
	lamp.omni_range = 3.6
	lamp.position = CENTER + Vector3(0, 2.0, 0.4)
	_hall.add_child(lamp)
	# Istujat pöydän takana kasvot kameraan, jakkarat alle.
	for s in 3:
		var at := CENTER + Vector3(SEAT_X[s], 0, SEAT_Z)
		var c := Room.seat(_hall, people[s].look, at, Vector3(0, 0, 1))
		_chars.append(c)
		Room.stool(_hall, c, at + Vector3(0, 0, -0.02))
		_eaters.append({"mouth": 0.0, "cough": 0.0, "eaten": 0, "bites": 0, "next": _rng.randf_range(0.2, 0.6),
			"greed": 0.7, "nod": 0.0, "lift": 0.0, "lift_t": 9.0, "fork": _make_fork()})
		# Lautanen.
		var p := CENTER + Vector3(SEAT_X[s], TABLE_H, PLATE_Z)
		B.mesh(_hall, B.cyl(0.15, 0.12, 0.018, 24), p + Vector3(0, 0.009, 0), Color(0.97, 0.97, 0.95))
		B.mesh(_hall, B.cyl(0.125, 0.125, 0.003, 24), p + Vector3(0, 0.019, 0), Color(0.9, 0.9, 0.88))
		for i in START:
			_add_lettu(s, false)
	# Kaverien luonteet: Esa ja Timo varovaisia ja tasaisia, Joni ja Tero ahneita (yskivät joskus).
	_eaters[1].greed = 0.85
	_eaters[2].greed = 0.72
	# Nainen pöydän päässä kermavaahtopurkki kädessä, lettupino ja pannu vieressä.
	var w := Room.stand(_hall, people[3].look, CENTER + WOMAN_AT, Vector3(-1, 0, 0.25).normalized())
	_chars.append(w)
	_eaters.append({})
	var side := CENTER + Vector3(TABLE.x / 2.0 - 0.18, TABLE_H, 0.18)
	B.mesh(_hall, B.cyl(0.035, 0.035, 0.17, 12), side + Vector3(0, 0.085, 0), Color(0.95, 0.95, 0.97))  # kermavaahtopurkki
	B.mesh(_hall, B.cyl(0.012, 0.03, 0.04, 10), side + Vector3(0, 0.19, 0), Color(0.85, 0.2, 0.2))
	B.mesh(_hall, B.cyl(0.05, 0.05, 0.07, 12), side + Vector3(-0.14, 0.035, -0.1), Color(0.75, 0.1, 0.15))  # hillopurkki
	_cam = Room.camera(_hall)
	_frame_cam()
	_cam.current = true
	_hall._set_layers(_hall)


## Haarukka (-Z = piikkien suunta): varsi, kaula ja neljä piikkiä; piikeissä lettupala, kun haarukka nousee suulle.
func _make_fork() -> Node3D:
	var f := Node3D.new()
	_hall.add_child(f)
	var steel := Color(0.8, 0.8, 0.84)
	B.mesh(f, B.boxm(Vector3(0.014, 0.005, 0.12)), Vector3(0, 0, -0.04), steel)
	B.mesh(f, B.boxm(Vector3(0.022, 0.004, 0.025)), Vector3(0, 0, -0.112), steel)
	for i in 4:
		B.mesh(f, B.boxm(Vector3(0.003, 0.003, 0.045)), Vector3(-0.0085 + i * 0.0057, 0, -0.146), steel)
	var bite := MeshInstance3D.new()
	bite.mesh = B.boxm(Vector3(0.045, 0.012, 0.04))
	bite.material_override = B.mat(Color(0.93, 0.76, 0.42))
	bite.position = Vector3(0, 0.008, -0.15)
	bite.name = "pala"
	f.add_child(bite)
	B.mesh(bite, B.sphere(0.014, 8), Vector3(0, 0.012, 0), Color(1, 1, 0.97))  # kermaa palan päällä
	return f


## Oikea käsi haarukkoineen: lepää lautasen takareunalla ja nousee haukatessa suulle (IK; tavoitteet hallin
## koordinaateissa, hahmon etu on +Z). lift 0..1 = käsi lautaselta suulle.
func _arm(s: int, delta: float) -> void:
	var e: Dictionary = _eaters[s]
	var c: Node3D = _chars[s]
	e.lift_t += delta
	var lt: float = e.lift_t
	e.lift = clampf(lt / 0.22, 0.0, 1.0) if lt < 0.4 else clampf(1.0 - (lt - 0.4) / 0.3, 0.0, 1.0)
	var k: float = smoothstep(0.0, 1.0, float(e.lift))
	var plate := CENTER + Vector3(SEAT_X[s], TABLE_H, PLATE_Z)
	var sh := _hall.to_local(c.to_global(c.bone_position("upperarm_r")))
	var head := _hall.to_local(c.to_global(c.bone_position("Head")))
	var side := signf(sh.x - (CENTER.x + SEAT_X[s]))
	var rest := Vector3(lerpf(sh.x, plate.x, 0.55), TABLE_H + 0.045, plate.z - 0.16)
	var mouth := head + Vector3(0, -0.01, 0.12)
	var hand := rest.lerp(mouth + Vector3(side * 0.05, -0.12, 0.08), k)
	var pole := hand + Vector3(side * 0.4, -0.35, -0.15)
	var inv := c.transform.affine_inverse()
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * hand, inv * pole)
	# Haarukka kädestä: levossa piikit lautaselle, noustessa suuhun.
	var f: Node3D = e.fork
	var tip := (plate + Vector3(0, 0.03, 0)).lerp(mouth, k)
	var dir := (tip - hand).normalized()
	f.position = hand + dir * 0.03
	f.look_at(_hall.to_global(tip) + (_hall.to_global(tip) - _hall.to_global(hand)) * 0.01, Vector3.UP)
	f.get_node("pala").visible = k > 0.15
	_hall._set_layers(f)


## Kamera pöydän edestä: kaikki kolme lautasta ja istujaa ruudulle, nainen oikeaan reunaan (projisoidaan, ei arvata).
func _frame_cam() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aim := CENTER + Vector3(0.18, TABLE_H + 0.3, -0.42)
	for i in 40:
		var dist := 1.3 + i * 0.05
		var eye := CENTER + Vector3(0.18, TABLE_H + 0.5 + dist * 0.3, dist - 0.2)
		_cam.transform = Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye)
		var l := _cam.unproject_position(_hall.to_global(CENTER + Vector3(SEAT_X[1] - 0.25, TABLE_H, 0.3)))
		var wh := _cam.unproject_position(_hall.to_global(CENTER + WOMAN_AT + Vector3(0, 1.75, 0)))
		var eh := _cam.unproject_position(_hall.to_global(CENTER + Vector3(0, 1.35, SEAT_Z)))
		if l.x >= vs.x * 0.04 and wh.x <= vs.x * 0.95 and wh.y >= vs.y * 0.1 and eh.y >= vs.y * 0.2:
			break
	_cam_base = _cam.transform


## Letun palat: kolme umpinaista sektoria (yläpinta, alapinta, kaari ja kaksi leikkauspintaa), reuna paistettua ruskeaa.
static func _wedge_mesh(a0: float, a1: float) -> ArrayMesh:
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var n := 10
	var mid := Color(0.96, 0.8, 0.45)
	var rim := Color(0.72, 0.45, 0.18)
	var h := LETTU_H / 2.0
	for i in n:
		var u0 := lerpf(a0, a1, float(i) / n)
		var u1 := lerpf(a0, a1, float(i + 1) / n)
		var p0 := Vector3(cos(u0), 0, sin(u0)) * LETTU_R
		var p1 := Vector3(cos(u1), 0, sin(u1)) * LETTU_R
		# Yläpinta (normaali ylös) ja alapinta.
		for y: float in [h, -h]:
			var nrm := Vector3(0, signf(y), 0)
			var tri := [Vector3(0, y, 0), p1 + Vector3(0, y, 0), p0 + Vector3(0, y, 0)] if y > 0 else \
				[Vector3(0, y, 0), p0 + Vector3(0, y, 0), p1 + Vector3(0, y, 0)]
			var cols := [mid, rim, rim]
			for k in 3:
				vs.append(tri[k])
				ns.append(nrm)
				cs.append(cols[k])
		# Kaari.
		var na := (p0 + p1).normalized()
		for v: Vector3 in [p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), p1 + Vector3(0, -h, 0), p0 + Vector3(0, h, 0),
				p1 + Vector3(0, -h, 0), p0 + Vector3(0, -h, 0)]:
			vs.append(v)
			ns.append(na)
			cs.append(rim.darkened(0.15))
	# Leikkauspinnat (sisus vaaleampi).
	for u: float in [a0, a1]:
		var p := Vector3(cos(u), 0, sin(u)) * LETTU_R
		var nrm := Vector3(sin(u), 0, -cos(u)) * (1.0 if u == a0 else -1.0)
		var quad := [Vector3(0, h, 0), p + Vector3(0, h, 0), p + Vector3(0, -h, 0), Vector3(0, h, 0), p + Vector3(0, -h, 0),
			Vector3(0, -h, 0)]
		if u == a1:
			quad = [Vector3(0, h, 0), p + Vector3(0, -h, 0), p + Vector3(0, h, 0), Vector3(0, h, 0), Vector3(0, -h, 0),
				p + Vector3(0, -h, 0)]
		for v: Vector3 in quad:
			vs.append(v)
			ns.append(nrm)
			cs.append(Color(0.98, 0.9, 0.62))
	# Kolmiot käänteisessä järjestyksessä: Godotin etupinta kiertää myötäpäivään katsojasta.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, vs.size(), 3):
		for k: int in [0, 2, 1]:
			st.set_normal(ns[i + k])
			st.set_color(cs[i + k])
			st.add_vertex(vs[i + k])
	return st.commit()


## Uusi lettu lautaselle s (animated: lentää naisen pannulta).
func _add_lettu(s: int, animated: bool) -> void:
	var l := Node3D.new()
	_hall.add_child(l)
	var mat := B.vcol_srgb_mat().duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # palojen kiertosuunta: molemmat puolet näkyviin
	for k in 3:
		var m := MeshInstance3D.new()
		m.mesh = _wedge_mesh(TAU * k / 3.0, TAU * (k + 1) / 3.0)
		m.material_override = mat
		l.add_child(m)
		# Paistopilkut yläpinnalla.
		for j in 3:
			var a := TAU * (k + (j + 0.5) / 3.0) / 3.0
			var sp := MeshInstance3D.new()
			sp.mesh = B.cyl(0.011, 0.011, 0.001, 8)
			sp.material_override = B.mat(Color(0.62, 0.36, 0.13))
			sp.position = Vector3(cos(a), 0, sin(a)) * LETTU_R * (0.35 + 0.18 * j) + Vector3(0, LETTU_H / 2.0 + 0.0005, 0)
			m.add_child(sp)
	l.rotation.y = _rng.randf() * TAU
	var stack: Array = _stacks[s]
	var target := CENTER + Vector3(SEAT_X[s], TABLE_H + 0.021 + LETTU_H * (stack.size() + 0.5), PLATE_Z)
	stack.append(l)
	if animated:
		l.position = CENTER + WOMAN_AT + Vector3(-0.2, 1.1, 0)
		var tw := l.create_tween()
		tw.tween_property(l, "position", target + Vector3(0, 0.25, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position", target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: Sfx.play("cloth", -14.0, 1.5))
	else:
		l.position = target
	_hall._set_layers(l)
	_place_kerma(s)


## Kermanokare ja hillotilkka päällimmäisen letun päälle.
func _place_kerma(s: int) -> void:
	if _kerma[s] == null:
		var k := Node3D.new()
		_hall.add_child(k)
		var dollop := MeshInstance3D.new()
		dollop.mesh = B.sphere(0.045, 16)
		dollop.material_override = B.mat(Color(1.0, 0.99, 0.95))
		dollop.scale = Vector3(1.0, 0.6, 1.0)
		dollop.position = Vector3(0, 0.022, 0)
		k.add_child(dollop)
		var tip := MeshInstance3D.new()
		tip.mesh = B.cyl(0.0, 0.02, 0.03, 10)
		tip.material_override = dollop.material_override
		tip.position = Vector3(0, 0.055, 0)
		k.add_child(tip)
		var jam := MeshInstance3D.new()
		jam.mesh = B.sphere(0.03, 12)
		jam.material_override = B.mat(Color(0.75, 0.05, 0.12))
		jam.scale = Vector3(1.0, 0.35, 1.0)
		jam.position = Vector3(0.055, 0.008, 0.03)
		k.add_child(jam)
		_kerma[s] = k
	var stack: Array = _stacks[s]
	var k3: Node3D = _kerma[s]
	k3.visible = not stack.is_empty()
	if not stack.is_empty():
		var top: Node3D = stack[-1]
		k3.position = top.position + Vector3(0, LETTU_H / 2.0, 0)
	_hall._set_layers(k3)


# --- Kisa ---------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	for s in 4:
		if _bubble_t[s] > 0.0:
			_bubble_t[s] -= delta
			if _bubble_t[s] <= 0.0:
				_bubbles[s] = ""
	if Input.is_action_just_pressed("mount") and _phase != "loppu" and _phase != "valmis":
		_finish({"luovutti": true, "kiva": "lettu"})
		return
	match _phase:
		"alku":
			if _t > 3.0:
				_phase = "kisa"
				_t = 0.0
				_story = ""
				Sfx.play("bell", -6.0, 1.0)
		"kisa":
			_left -= delta
			_race(delta)
			if _left <= 0.0:
				_end_race()
		"loppu":
			if _pressed() or (auto and _t > 2.0):
				var won := _winner() == 0
				_finish({"voitto": won, "letut": _score(0), "kiva": "lettu"})
	for s in 3:
		var e: Dictionary = _eaters[s]
		_arm(s, delta)
		e.nod = move_toward(e.nod, 0.0, delta * 2.2)
		var cough_nod := sin(_t * 26.0) * 0.25 if e.cough > 0.0 else 0.0
		Room.nod(_chars[s], e.nod + cough_nod)
	_shake = maxf(0.0, _shake - delta * 2.5)
	_cam.transform = _cam_base.translated_local(Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.03)
	_update_keys()
	_ui.queue_redraw()


func _pressed() -> bool:
	return Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")


func _race(delta: float) -> void:
	for s in 3:
		var e: Dictionary = _eaters[s]
		e.mouth = maxf(0.0, e.mouth - NIELU * delta)
		if e.cough > 0.0:
			e.cough -= delta
			continue
		if s == 0 and not auto:
			if _pressed():
				_bite(s)
			continue
		e.next -= delta
		if e.next <= 0.0:
			# Tekoäly haukkaa, kun suussa on tilaa sen ahneuden verran (ahne yskii joskus).
			var want: float = e.greed + _rng.randf_range(-0.08, 0.12)
			if e.mouth + HAUKKU <= want or e.mouth < 0.05:
				_bite(s)
			e.next = _rng.randf_range(0.18, 0.35)
	# Nainen tuo lisää, kun jonkun pino on vähissä, ja heittää kommentin.
	_serve_t -= delta
	for s in 3:
		if (_stacks[s] as Array).size() <= 1 and _serve_t <= 0.0:
			for i in 3:
				_add_lettu(s, true)
			_chars[3].restart("Interact", 0.1)
			_serve_t = 1.0
			if _rng.randf() < 0.5:
				_say(3, _line("kerma", "Lisää kermaa!"))
	if _serve_t < -1.5 and (_chars[3] as Node3D).call("current") == "Interact":
		_chars[3].play("Idle", 0.3)
	_comment_t -= delta
	if _comment_t <= 0.0:
		_comment_t = _rng.randf_range(7.0, 11.0)
		var s := _rng.randi_range(1, 2)
		var own: Array = lines.get("kommentti", {}).get(String(people[s].id), [])
		if not own.is_empty():
			_say(s, own.pick_random())


## Haukku: pala päällimmäisestä letusta suuhun. Yli täyden = kerma nenästä ja yskintä.
func _bite(s: int) -> void:
	var e: Dictionary = _eaters[s]
	var stack: Array = _stacks[s]
	if stack.is_empty():
		return
	e.mouth += HAUKKU
	e.nod = 0.35
	e.lift_t = 0.0
	var top: Node3D = stack[-1]
	var piece: Node3D = top.get_child(top.get_child_count() - 1)
	_burst(top.global_position + Vector3(0, 0.02, 0), Color(0.9, 0.72, 0.38), 8)
	top.remove_child(piece)
	piece.queue_free()
	e.bites += 1
	if top.get_child_count() == 0:
		stack.pop_back()
		top.queue_free()
		e.eaten += 1
		_place_kerma(s)
	Sfx.play("cloth", -10.0 if s == 0 else -16.0, _rng.randf_range(0.55, 0.75))
	if e.mouth > 1.0:
		_choke(s)


func _choke(s: int) -> void:
	var e: Dictionary = _eaters[s]
	e.cough = YSKA
	e.mouth = 0.35
	var c: Node3D = _chars[s]
	var mouth: Vector3 = c.to_global(c.bone_position("Head")) + c.global_basis * Vector3(0, 0.02, -0.12)
	_burst(mouth, Color(1, 1, 0.97), 26, 1.6)
	Sfx.play("grunt", -6.0 if s == 0 else -10.0, 1.1)
	if s == 0:
		_shake = 1.0
		_say(3, _line("tukehtuu_sina", "Liian iso suullinen. Kerma tuli nenästä."))
	else:
		var own: Array = lines.get("tukehtuu", {}).get(String(people[s].id), [])
		_say(s, own.pick_random() if not own.is_empty() else "Hhkk!")


## Murut ja kermaroiskeet: pienet 3D-hiukkaset (kertaluonteinen purkaus).
func _burst(at: Vector3, col: Color, n: int, speed := 0.8) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = n
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0.6)
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var m := SphereMesh.new()
	m.radius = 0.008
	m.height = 0.016
	p.mesh = m
	p.material_override = B.mat(col)
	_hall.add_child(p)
	p.global_position = at
	_hall._set_layers(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _score(s: int) -> float:
	return float(_eaters[s].bites) / 3.0


func _winner() -> int:
	var best := 0
	for s in 3:
		if _score(s) > _score(best) + 0.001:
			best = s
	return best


func _end_race() -> void:
	_phase = "loppu"
	_t = 0.0
	var w := _winner()
	Sfx.play("win" if w == 0 else "lose", -4.0)
	if w == 0:
		_story = "Voitit! %d lettua minuutissa. %s nuolee vatkaimen sun kanssa." % [floori(_score(0)), people[3].name]
		_say(3, _line("voitto", "Sää nielit kaikki."))
	else:
		_story = "%s voitti (%d lettua, sinä %d). Häviäjät tiskaavat kalsareissa." % [people[w].name, floori(_score(w)),
			floori(_score(0))]
		var t: String = _line("havio", "%s voitti!")
		_say(3, t % people[w].name if "%s" in t else t)
	for s in 3:
		_chars[s].play("Sitting_Talking", 0.3)


func _finish(r: Dictionary) -> void:
	if _phase == "valmis":
		return
	_phase = "valmis"
	finished.emit(r)
	queue_free()


# --- Puhe ja käyttöliittymä ---------------------------------------------------------------------------------------

func _line(key: String, fallback: String) -> String:
	var l: Variant = lines.get(key, [])
	return (l as Array).pick_random() if l is Array and not (l as Array).is_empty() else fallback


func _say(s: int, text: String) -> void:
	_bubbles[s] = "%s: %s" % [people[s].name, text] if s != 0 else text
	_bubble_t[s] = 3.4


func _update_keys() -> void:
	match _phase:
		"kisa":
			_keys.set_text("%s haukkaa   %s lopeta" % [Settings.cap("interact"), Settings.cap("mount")])
		"loppu":
			_keys.set_text("%s jatka" % Settings.cap("interact"))
		_:
			_keys.set_text("%s lopeta" % Settings.cap("mount"))


func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	# Tilanne ylhäällä: aika ja lettujen määrät.
	var top := "LETTUKISA   %s   Sinä %d   %s %d   %s %d" % ["%d s" % ceili(_left) if _phase != "alku" else "valmiina...",
		floori(_score(0)), people[1].name, floori(_score(1)), people[2].name, floori(_score(2))]
	Room.box(_ui, Rect2(vs.x / 2.0 - 380, 14, 760, 40), Color(0, 0, 0, 0.55))
	_ui.draw_string(font, Vector2(vs.x / 2.0 - 370, 42), top, HORIZONTAL_ALIGNMENT_CENTER, 740, 20, Color.WHITE)
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 400, 62, 800, 60)
		Room.box(_ui, r)
		_ui.draw_multiline_string(font, r.position + Vector2(16, 25), _story, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 18, 2,
			Color(1.0, 0.92, 0.75))
	if _phase == "alku":
		var n := 3 - floori(_t)
		_ui.draw_string(font, Vector2(0, vs.y * 0.45), str(maxi(1, n)), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 96, Color(1, 0.95, 0.8))
	for s in 4:
		Room.bubble(_ui, _cam, _chars[s], _bubbles[s], 130.0 if _story != "" else 64.0, 150.0)
	# Oma suumittari alhaalla: vihreä alue = tilaa haukulle, punainen = kerma nenästä.
	var e: Dictionary = _eaters[0]
	var mr := Rect2(vs.x / 2.0 - 220, vs.y - 104, 440, 26)
	Room.box(_ui, mr.grow(6), Color(0, 0, 0, 0.6))
	var safe := (1.0 - HAUKKU) * mr.size.x
	_ui.draw_rect(Rect2(mr.position, Vector2(safe, mr.size.y)), Color(0.2, 0.55, 0.25, 0.55))
	_ui.draw_rect(Rect2(mr.position + Vector2(safe, 0), Vector2(mr.size.x - safe, mr.size.y)), Color(0.7, 0.15, 0.12, 0.55))
	var fill := clampf(float(e.mouth), 0.0, 1.0) * mr.size.x
	_ui.draw_rect(Rect2(mr.position, Vector2(fill, mr.size.y)), Color(1.0, 0.97, 0.9))
	_ui.draw_rect(mr, Color(1, 1, 1, 0.6), false, 2.0)
	var label := "SUU TÄYNNÄ" if e.mouth > 1.0 - HAUKKU else "SUU: tilaa haukulle"
	if e.cough > 0.0:
		label = "YSKIT KERMAA..."
	Room.box(_ui, Rect2(mr.position + Vector2(mr.size.x / 2.0 - 110, -34), Vector2(220, 24)), Color(0, 0, 0, 0.7))
	_ui.draw_string(font, mr.position + Vector2(0, -16), label, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x, 16, Color.WHITE)


# --- Testi (tools/testit/iltakivat_kuvat.gd) ----------------------------------------------------------------------

## Toiminnan kohde: pelaajan lettupino (keskipiste maailmassa ja säde).
func test_target() -> Array:
	return [_hall.to_global(CENTER + Vector3(SEAT_X[0], TABLE_H + 0.04, PLATE_Z)), LETTU_R]


## Lähikuva pelaajan lautasesta ja kasvoista (letun palat ja kerma).
func test_closeup() -> void:
	var p := CENTER + Vector3(SEAT_X[0], TABLE_H, PLATE_Z)
	var eye := p + Vector3(0.1, 0.45, 0.55)
	_cam_base = Transform3D(Basis.looking_at(p + Vector3(0, 0.2, -0.25) - eye, Vector3.UP), eye)
	_cam.transform = _cam_base
