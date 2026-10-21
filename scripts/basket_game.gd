extends Node3D
## Koripallo kentän laidan korilla minäkuvakulmasta (3D): pojat lyövät vetoa, ettei setä saa NEED koria putkeen.
## Lisätään korin (build_hoop) lapseksi: paikallinen kehys = korin kehys, renkaan keskipiste RIM, kenttä +z.
## Hiiri tähtää (katse), vasen nappi pohjassa nostaa pallon ja voimamittari täyttyy; päästä oikealla hetkellä.
## Heittokulma on vakio, voima ratkaisee pituuden: mittarin keskikohta osuu renkaan keskelle. Pallo kimpoaa renkaasta,
## levystä ja maasta oikeasti (oma pieni fysiikka). Ohi heitto nollaa putken. Poika levyn alla palauttaa pallon.
## Joka neljännen korin jälkeen heittopaikka vaihtuu. Humalassa katse huojuu ja mittari nykii. F / Esc lopettaa.

signal finished(result: String)  # "voitto" / "kesken"

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const NEED := 16
const RIM := Vector3(0, 3.05, 0)
const RIM_R := 0.225
const BALL_R := 0.12
const BOARD_Z := -0.375
const G := 9.81
const ANGLE := deg_to_rad(62.0)  # korkea kaari: pallo tulee renkaaseen n. 45 asteen kulmassa
const EYE := 1.7
const FILL := 1.4  # mittari täyteen (s)
const SENS := 0.0028
## Heittopaikat [etäisyys renkaasta, kulma]: vapaaheittoviiva, sivut ja kauempaa.
const SPOTS := [[4.225, 0.0], [4.4, 0.55], [4.4, -0.55], [5.0, 0.0]]
const ORANGE := Color(0.92, 0.42, 0.1)
const LINES := {
	"start": ["Setä ei saa kuuttatoista putkeen! Jeren isän kalja panoksena.", "Kuustoista putkeen tai ei kaljaa. Ei oo helppoa, setä."],
	"make": ["%d!", "%d. Tuuria.", "%d... ei paha.", "%d! Kato setää!"],
	"air": ["Hahaa, ilmapallo!", "Ei osunu ees renkaaseen!"],
	"rim": ["Rautaa! Alusta, setä.", "Kolisi mutta ei menny."],
	"short": ["Lyhyt! Ihan lyhyt!", "Voimaa, setä!"],
	"long": ["Pitkä! Ei se oo amerikkalainen jalkapallo.", "Liian lujaa!"],
	"spot": ["Siirry sivulle, setä. Ei pelkkää vapaaheittoa.", "Kauempaa nyt!"],
	"win": ["KUUSTOISTA! Ei voi olla totta... Tässä, Jeren isän kalja.", "Setä on ammattilainen! Ota kalja."],
}

var drunk := 0.0
var best := 0
var streak := 0
var run_best := 0  # pisin putki tällä kertaa (best = kaikkien aikojen)

var _cam: Camera3D
var _prev_cam: Camera3D
var _body: Node3D
var _ball: Node3D
var _kids: Array[Node3D] = []
var _bubbles: Array[Label3D] = []
var _bubble_t: Array[float] = [0.0, 0.0]
var _net: Node3D
var _hud: CanvasLayer
var _info: Label
var _keys: Control
var _meter: Control
var _rng := RandomNumberGenerator.new()
var _done := false
var _phase := "kasissa"  # kasissa / lataa / lento / palautus / voitto
var _t := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _spot := Vector3.ZERO
var _lmb := false
var _power := 0.0
var _last_power := -1.0
var _pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _spin := Vector3.ZERO
var _scored := false
var _flight_t := 0.0
var _clang_t := 0.0
var _touched := false  # rengas tai levy osui tällä heitolla
var _net_t := 10.0
var _shake := 0.0
var _follow := 0.0  # heiton jälkeinen käsien ojennus (1 -> 0)
var _return_from := Vector3.ZERO
var _return_t := 0.0
var _end_t := 0.0


## Kori asfalttikenttineen: tolppa pehmusteineen, varsi, levy (valkoinen, punainen kehys ja neliö), oranssi rengas ja
## verkko. Paikallinen kehys: renkaan alla origo, kenttä +z. Palauttaa korin solmun (verkko lapsena "Net").
static func build_hoop(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = yaw
	parent.add_child(h)
	var white := Color(0.95, 0.95, 0.92)
	var red := Color(0.8, 0.12, 0.1)
	B.mesh(h, B.boxm(Vector3(8.0, 0.06, 8.5)), Vector3(0, 0.03, 2.3), Color(0.3, 0.3, 0.32))  # asfaltti
	var line := func(size: Vector3, p: Vector3) -> void:
		B.mesh(h, B.boxm(size), p, white)
	var base := BOARD_Z - 1.2
	line.call(Vector3(8.0, 0.012, 0.06), Vector3(0, 0.066, base))  # päätyviiva
	for x in [-2.45, 2.45]:
		line.call(Vector3(0.06, 0.012, 5.8), Vector3(x, 0.066, base + 2.9))  # bunkkerin sivut
	line.call(Vector3(4.9, 0.012, 0.06), Vector3(0, 0.066, base + 5.8))  # vapaaheittoviiva
	for k in 12:  # vapaaheittoympyrän kenttäpuoli
		var a := PI * (k + 0.5) / 12.0 - PI / 2.0
		var seg := B.mesh(h, B.boxm(Vector3(0.06, 0.012, 0.5)), Vector3(sin(a) * 1.8, 0.066, base + 5.8 + cos(a) * 1.8), white)
		seg.rotation.y = a + PI / 2.0
	# Tolppa, pehmuste, varsi.
	var pz := base - 0.5
	B.mesh(h, B.cyl(0.08, 0.08, 3.5, 12), Vector3(0, 1.75, pz), Color(0.45, 0.47, 0.5))
	B.mesh(h, B.boxm(Vector3(0.24, 1.8, 0.24)), Vector3(0, 0.95, pz), Color(0.12, 0.25, 0.55))
	B.mesh(h, B.boxm(Vector3(0.1, 0.1, -BOARD_Z + 0.05 - pz)), Vector3(0, 3.3, (pz + BOARD_Z) / 2.0), Color(0.45, 0.47, 0.5))
	B.tube(h, Vector3(0, 2.9, pz), Vector3(0, 3.25, BOARD_Z - 0.06), 0.03, Color(0.45, 0.47, 0.5))
	var sb := StaticBody3D.new()
	sb.position = Vector3(0, 0, pz)
	sb.add_child(B.box_shape(Vector3(0.3, 3.5, 0.3), Vector3(0, 1.75, 0)))
	h.add_child(sb)
	# Levy: valkoinen, punainen kehys ja heittoneliö renkaan yläpuolella.
	var bz := BOARD_Z - 0.02
	B.mesh(h, B.boxm(Vector3(1.8, 1.05, 0.04)), Vector3(0, 3.4, bz), white)
	for e in [[Vector3(1.8, 0.05, 0.01), Vector3(0, 3.9, bz + 0.022)], [Vector3(1.8, 0.05, 0.01), Vector3(0, 2.9, bz + 0.022)],
			[Vector3(0.05, 1.05, 0.01), Vector3(-0.875, 3.4, bz + 0.022)], [Vector3(0.05, 1.05, 0.01), Vector3(0.875, 3.4, bz + 0.022)],
			[Vector3(0.59, 0.04, 0.01), Vector3(0, 3.5, bz + 0.022)], [Vector3(0.59, 0.04, 0.01), Vector3(0, 3.07, bz + 0.022)],
			[Vector3(0.04, 0.45, 0.01), Vector3(-0.295, 3.285, bz + 0.022)], [Vector3(0.04, 0.45, 0.01), Vector3(0.295, 3.285, bz + 0.022)]]:
		B.mesh(h, B.boxm(e[0]), e[1], red)
	# Rengas ja kiinnike.
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RIM_R - 0.01
	tm.outer_radius = RIM_R + 0.01
	tm.rings = 32
	rim.mesh = tm
	rim.material_override = B.mat(ORANGE)
	rim.position = RIM
	h.add_child(rim)
	B.mesh(h, B.boxm(Vector3(0.14, 0.03, 0.16)), Vector3(0, RIM.y - 0.01, BOARD_Z + 0.08), ORANGE)
	# Verkko: 12 narua renkaasta alas kapenevaan alarenkaaseen ristiin, ja kaksi vaakakierrosta.
	var net := Node3D.new()
	net.name = "Net"
	net.position = RIM
	h.add_child(net)
	var nc := Color(0.96, 0.96, 0.96)
	var n := 12
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 0.5) / n
		var a2 := TAU * (k + 1.0) / n
		var top := Vector3(cos(a0), 0, sin(a0)) * RIM_R
		var mid := Vector3(cos(a1), 0, sin(a1)) * 0.18 + Vector3(0, -0.22, 0)
		var low := Vector3(cos(a2), 0, sin(a2)) * 0.13 + Vector3(0, -0.42, 0)
		B.tube(net, top, mid, 0.005, nc)
		B.tube(net, mid, low, 0.005, nc)
		B.tube(net, Vector3(cos(a2), 0, sin(a2)) * RIM_R, mid, 0.005, nc)
		B.tube(net, mid, Vector3(cos(a0 + TAU / n * 1.5), 0, sin(a0 + TAU / n * 1.5)) * 0.13 + Vector3(0, -0.42, 0), 0.005, nc)
	return h


## Koripallo: oranssi pallo, mustat saumat (kaksi pituuspiiriä ja päiväntasaaja).
static func make_ball(parent: Node3D) -> Node3D:
	var b := Node3D.new()
	parent.add_child(b)
	var s := B.mesh(b, B.sphere(BALL_R, 24), Vector3.ZERO, ORANGE)
	var m := StandardMaterial3D.new()
	m.albedo_color = ORANGE
	m.roughness = 0.75
	s.material_override = m
	for rot in [Vector3.ZERO, Vector3(PI / 2.0, 0, 0), Vector3(0, 0, PI / 2.0)]:
		var seam := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = BALL_R - 0.002
		t.outer_radius = BALL_R + 0.003
		t.rings = 32
		t.ring_segments = 4
		seam.mesh = t
		seam.material_override = B.mat(Color(0.08, 0.06, 0.05))
		seam.rotation = rot
		b.add_child(seam)
	return b


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	process_priority = 10  # oman hahmon animaation ja IK:n jälkeen (sormet pallon ympärille)
	_rng.randomize()
	_net = get_parent().get_node_or_null("Net")
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.near = 0.03
	add_child(_cam)
	_cam.current = true
	_body = Looks.make(self, Looks.player())
	_body.play("Idle", 0.0)
	_ball = make_ball(self)
	var kid_cols := [Color(0.2, 0.7, 0.3), Color(0.95, 0.5, 0.1)]
	for i in 2:
		var kid := Looks.make(self, {"model": "male", "shirt": kid_cols[i], "pants": Color(0.15, 0.15, 0.2), "shoes": Color(0.9, 0.9, 0.9),
			"hair": "Hair_Buzzed", "hair_color": Color(0.5, 0.35, 0.2), "height": 1.4 + i * 0.08, "skin": Color(0.95, 0.8, 0.7)})
		kid.play("Idle", 0.0)
		_kids.append(kid)
		var bub := B.bubble(kid, Vector3(0, 1.75, 0))
		bub.text = ""
		_bubbles.append(bub)
	_kids[0].position = Vector3(0.9, 0, 0.8)  # levyn alla palauttaja
	_kids[1].position = Vector3(3.4, 0, 3.6)  # sivussa naureskelija
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_go_spot(true)
	_kid_say(1, LINES.start.pick_random(), 4.0)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 30)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 9)
	_info.anchor_right = 1.0
	_info.offset_top = 22
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_info)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	_hud.add_child(_keys)
	_meter = Control.new()
	_meter.anchor_left = 1.0
	_meter.anchor_right = 1.0
	_meter.anchor_top = 0.5
	_meter.anchor_bottom = 0.5
	_meter.offset_left = -150
	_meter.offset_right = -90
	_meter.offset_top = -170
	_meter.offset_bottom = 170
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	_hud.add_child(_meter)


## Voimamittari: pystypalkki, täyttö punaisesta (heikko) keltaisen kautta, keskikohdan lovi ja edellisen heiton merkki.
func _draw_meter() -> void:
	var r := Rect2(Vector2(14, 0), Vector2(32, _meter.size.y))
	_meter.draw_rect(r.grow(5), Color(0, 0, 0, 0.55))
	_meter.draw_rect(r, Color(0.15, 0.15, 0.17))
	var p := _power if _phase == "lataa" else 0.0
	var fill := Rect2(Vector2(r.position.x, r.end.y - r.size.y * p), Vector2(r.size.x, r.size.y * p))
	var col := Color(0.85, 0.25, 0.15).lerp(Color(1.0, 0.85, 0.2), clampf(p * 1.6, 0.0, 1.0))
	if p > 0.7:
		col = col.lerp(Color(0.9, 0.3, 0.1), (p - 0.7) / 0.3)
	_meter.draw_rect(fill, col)
	_meter.draw_line(Vector2(r.position.x - 8, r.get_center().y), Vector2(r.end.x + 8, r.get_center().y), Color(1, 1, 1, 0.8), 2.0)
	if _last_power >= 0.0:
		var y := r.end.y - r.size.y * _last_power
		_meter.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x - 2, y), Vector2(r.position.x - 14, y - 7),
			Vector2(r.position.x - 14, y + 7)]), Color(1, 1, 1, 0.9))
	_meter.draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)


## Heittopaikka putken mukaan (joka neljäs kori vaihtaa); katse kääntyy renkaaseen.
func _go_spot(first := false) -> void:
	var s: Array = SPOTS[mini(streak / 4, SPOTS.size() - 1)]
	var sp := Vector3(sin(s[1]) * s[0], 0, cos(s[1]) * s[0])
	if not first and sp.distance_to(_spot) > 0.1:
		_kid_say(1, LINES.spot.pick_random(), 2.5)
	_spot = sp
	var to := RIM - (sp + Vector3(0, EYE, 0))
	_yaw = atan2(-to.x, -to.z)
	_pitch = atan2(to.y, Vector2(to.x, to.z).length()) - 0.08


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * SENS
		_pitch = clampf(_pitch - event.relative.y * SENS, -0.8, 0.9)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_lmb = event.pressed


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish("kesken")
		return
	for i in 2:
		_bubble_t[i] -= delta
		if _bubble_t[i] <= 0.0 and _bubbles[i].text != "":
			_bubbles[i].text = ""
			_kids[i].play("Idle")
	_shake = maxf(0.0, _shake - delta * 3.0)
	_follow = maxf(0.0, _follow - delta * 1.2)
	_net_tick(delta)
	match _phase:
		"kasissa":
			if _lmb:
				_phase = "lataa"
				_power = 0.0
		"lataa":
			_power = minf(1.0, _power + delta / FILL)
			if drunk > 0.0:
				_power = clampf(_power + sin(_t * 23.0) * drunk * 0.01, 0.0, 1.0)
			if not _lmb:
				_release(_power)
		"lento":
			_fly(delta)
		"palautus":
			_return_tick(delta)
		"voitto":
			_end_t += delta
			if _end_t > 4.0:
				_finish("voitto")
				return
	_place(delta)
	_kids_face()
	_meter.queue_redraw()
	_info.text = "Putkessa %d / %d   ·   ennätys %d" % [streak, NEED, best]
	_keys.set_text("Hiiri tähtää · vasen nappi pohjassa nostaa ja täyttää mittarin, päästä keskikohdalla   %s lopeta" % Settings.cap("mount"))


## Kamera, oma hahmo ja pallo käsissä. Ladatessa pallo nousee otsan eteen, heiton jälkeen kädet ojentuvat.
func _place(_delta: float) -> void:
	var sway := Vector2(sin(_t * 1.7) * 0.6 + sin(_t * 4.3) * 0.4, cos(_t * 1.3) * 0.7 + sin(_t * 3.1) * 0.3) * drunk * 0.04
	var shk := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake * 0.01
	var eye := _spot + Vector3(0, EYE, 0) + shk
	_cam.position = eye
	_cam.rotation = Vector3(_pitch + sway.y, _yaw + sway.x, 0)
	var fwd := -_cam.transform.basis.z
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	var right := _cam.transform.basis.x
	var lift := _power if _phase == "lataa" else 0.0
	# Pallo pysyy kuvan alaosassa katseen mukana; ladatessa se nousee kohti kuvan keskustaa (otsan eteen).
	var cup := _cam.transform.basis.y
	var hold := eye + fwd * (0.46 - lift * 0.04) - cup * (0.21 - lift * 0.09) - right * 0.02
	if _phase in ["kasissa", "lataa"]:
		_ball.position = hold
		_ball.rotation.y = _yaw
	_body.position = _spot + flat * 0.16  # olkapäät kameran tasolle, jotta kädet ylettyvät palloon (pää piilossa)
	_body.rotation.y = atan2(-flat.x, -flat.z)
	var inv := _body.transform.affine_inverse()
	# Kädet pallon sivuilla kämmenet palloa vasten, oikea hieman takempana työntäjänä.
	var lh := hold - right * 0.155 - fwd * 0.01 + cup * 0.01
	var rh := hold + right * 0.165 + fwd * 0.01 + cup * 0.01
	if _phase not in ["kasissa", "lataa"]:
		# Heiton jälkeen ranne taittuu ja kädet jäävät hetkeksi ylös, sitten laskeutuvat.
		var up := eye + flat * 0.45 + Vector3(0, 0.15, 0)
		var down := eye + flat * 0.25 + Vector3(0, -0.75, 0)
		var target := down.lerp(up, _follow)
		lh = target - right * 0.12
		rh = target + right * 0.1
	_body.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", inv * lh, inv * (lh - right * 0.4 + Vector3(0, -0.5, 0)))
	_body.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * rh, inv * (rh + right * 0.4 + Vector3(0, -0.5, 0)))
	var hi: int = _body.skeleton.find_bone("Head")
	if hi >= 0:
		_body.skeleton.set_bone_pose_scale(hi, Vector3.ONE * 0.01)  # pää ei peitä kameraa
	if _phase in ["kasissa", "lataa"]:
		var bi := _body.transform.basis.inverse()
		_grip("l", bi * (hold - lh).normalized(), 0.45)
		_grip("r", bi * (hold - rh).normalized(), 0.45)


## Heitto: vaakasuunta katseesta, kulma vakio, nopeus mittarista. Mittarin keskikohta = tarkka nopeus renkaan keskelle.
func _release(p: float) -> void:
	_last_power = p
	_phase = "lento"
	_lmb = false
	_follow = 1.0
	_scored = false
	_touched = false
	_flight_t = 0.0
	_pos = _ball.position
	var fwd := -_cam.transform.basis.z
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	# Tähtäyspiste vähän renkaan keskikohdan takana: pallo ei hipaise etureunaa.
	var aim := RIM + Vector3(RIM.x - _pos.x, 0, RIM.z - _pos.z).normalized() * 0.05
	var d := Vector2(aim.x - _pos.x, aim.z - _pos.z).length()
	var h := aim.y - _pos.y
	var v_req := sqrt(G * d * d / (2.0 * pow(cos(ANGLE), 2.0) * maxf(0.05, d * tan(ANGLE) - h)))
	var v := v_req * (0.9 + 0.2 * p)  # keskikohta tarkka; onnistumisikkuna n. 0,14 mittaria (n. 200 ms)
	_vel = flat * v * cos(ANGLE) + Vector3.UP * v * sin(ANGLE)
	_spin = flat.cross(Vector3.UP) * 8.0  # takakierre
	Sfx.play("whoosh", -14.0, 1.3)


func _fly(delta: float) -> void:
	_flight_t += delta
	var steps := 6
	var dt := delta / steps
	_clang_t -= delta
	for s in steps:
		var prev := _pos
		_vel.y -= G * dt
		_pos += _vel * dt
		# Rengas: lähin piste renkaan kehältä, pallo kimpoaa sen normaalin suuntaan.
		var rel := _pos - RIM
		var fl := Vector2(rel.x, rel.z)
		var dirr := fl.normalized() if fl.length() > 0.001 else Vector2(1, 0)
		var q := RIM + Vector3(dirr.x, 0, dirr.y) * RIM_R
		var dv := _pos - q
		var dist := dv.length()
		if dist < BALL_R + 0.01:
			var n := dv / maxf(dist, 0.0001)
			_pos = q + n * (BALL_R + 0.01)
			var vn := _vel.dot(n)
			if vn < 0.0:
				_vel -= 1.55 * vn * n
				_vel *= 0.88
				if _clang_t <= 0.0:
					_clang_t = 0.12
					_touched = true
					Sfx.play("rattle_hard", -6.0, 1.7 + _rng.randf() * 0.3)
					_shake = 0.4
					_net_t = minf(_net_t, 0.3)
		# Levy.
		if _pos.z - BALL_R < BOARD_Z and _pos.z > BOARD_Z - 0.15 and absf(_pos.x) < 0.9 and _pos.y > 2.875 and _pos.y < 3.925 and _vel.z < 0.0:
			_pos.z = BOARD_Z + BALL_R
			_vel.z = -_vel.z * 0.6
			Sfx.play("punch", -10.0, 1.5)
			_touched = true
		# Kori: pallo kulkee renkaan tason läpi alaspäin keskeltä.
		if not _scored and prev.y >= RIM.y and _pos.y < RIM.y and _vel.y < 0.0 and Vector2(_pos.x - RIM.x, _pos.z - RIM.z).length() < RIM_R - BALL_R * 0.35:
			_scored = true
			_net_t = 0.0
			Sfx.play("whoosh", -4.0, 0.7)
			_vel *= 0.6  # verkko jarruttaa
		# Maa.
		if _pos.y < BALL_R:
			_pos.y = BALL_R
			if absf(_vel.y) > 1.0:
				Sfx.play("punch", -12.0, 0.7)
			_vel.y = -_vel.y * 0.68
			_vel.x *= 0.85
			_vel.z *= 0.85
			_resolve()
			return
	_ball.position = _pos
	if _spin.length() > 0.0:
		_ball.rotate(_spin.normalized(), _spin.length() * delta)
	if _flight_t > 4.0:
		_resolve()


## Heiton tulos: kori jatkaa putkea, ohi nollaa. Sitten pallo palautetaan.
func _resolve() -> void:
	_ball.position = _pos
	if _scored:
		streak += 1
		best = maxi(best, streak)
		run_best = maxi(run_best, streak)
		if streak >= NEED:
			_phase = "voitto"
			Sfx.play("win")
			_kid_say(1, LINES.win.pick_random(), 4.0)
			_kid_say(0, "EI VOI OLLA TOTTA!", 3.0)
			return
		var line: String = LINES.make.pick_random()
		_kid_say(0 if streak % 2 == 0 else 1, line % streak if "%d" in line else line, 1.8)
		Sfx.play("pickup", -8.0, 1.0 + streak * 0.04)
	else:
		if streak > 0:
			Sfx.play("lose", -10.0)
		streak = 0
		var kind := "rim" if _touched else "air"
		if _last_power < 0.42:
			kind = "short"
		elif _last_power > 0.6:
			kind = "long"
		_kid_say(1, (LINES[kind] as Array).pick_random(), 2.2)
	_phase = "palautus"
	_return_t = 0.0
	_return_from = _pos


## Palautus: pallo vierii/pomppaa hetken, sitten poika levyn alta syöttää sen kaarella takaisin käsiin.
func _return_tick(delta: float) -> void:
	_return_t += delta
	if _return_t < 0.6:
		_vel.y -= G * delta
		_pos += _vel * delta
		if _pos.y < BALL_R:
			_pos.y = BALL_R
			_vel.y = -_vel.y * 0.6
		_ball.position = _pos
		_return_from = _pos
		return
	var u := clampf((_return_t - 0.6) / 0.8, 0.0, 1.0)
	if u <= 0.0:
		return
	var kid := _kids[0]
	var to := Vector3(kid.position.x, 1.1, kid.position.z) - _return_from
	kid.rotation.y = lerp_angle(kid.rotation.y, atan2(-to.x, -to.z) + PI, 0.2)
	var dest := _spot + Vector3(0, EYE - 0.42, 0)
	var p := _return_from.lerp(dest, u)
	p.y += sin(u * PI) * 1.2
	_ball.position = p
	if u >= 1.0:
		_go_spot()
		_phase = "kasissa"
		Sfx.play("pickup", -10.0, 0.8)


## Verkko heilahtaa korin tai rengasosuman jälkeen.
func _net_tick(delta: float) -> void:
	if _net == null:
		return
	_net_t += delta
	var e := exp(-_net_t * 5.0)
	_net.scale = Vector3(1.0 + sin(_net_t * 30.0) * 0.08 * e, 1.0 + 0.3 * e * absf(sin(_net_t * 14.0)), 1.0 + cos(_net_t * 27.0) * 0.08 * e)
	_net.rotation.y = sin(_net_t * 18.0) * 0.15 * e


func _kid_say(i: int, text: String, t: float) -> void:
	_bubbles[i].text = text
	_bubble_t[i] = t
	_kids[i].play("Idle_Talking")


func _kids_face() -> void:
	for i in 2:
		if i == 0 and _phase == "palautus":
			continue
		var to := _cam.position - _kids[i].position
		_kids[i].rotation.y = lerp_angle(_kids[i].rotation.y, B.yaw_to(Vector3(to.x, 0, to.z)), 0.1)


## Ote pallosta: kämmen kohti palloa (palm hahmon avaruudessa), sormet kyynärvarren jatkona, nivelet hieman koukkuun.
func _grip(side: String, palm_char: Vector3, curl: float) -> void:
	var sk: Skeleton3D = _body.skeleton
	var to_char: Basis = (_body.model.transform * sk.transform).basis
	var hi := sk.find_bone("hand_" + side)
	var mid := sk.find_bone("middle_01_" + side)
	if hi < 0 or mid < 0:
		return
	var rest := sk.get_bone_global_rest(hi)
	var f_rest := (sk.get_bone_global_rest(mid).origin - rest.origin).normalized()
	var palm := (to_char.inverse() * palm_char).normalized()
	var fore := (sk.get_bone_global_pose(hi).origin - sk.get_bone_global_pose(sk.find_bone("lowerarm_" + side)).origin).normalized()
	var fingers := (fore - palm * fore.dot(palm)).normalized()
	var from := Basis(f_rest, Vector3.DOWN, f_rest.cross(Vector3.DOWN).normalized())
	var to := Basis(fingers, palm, fingers.cross(palm).normalized())
	_body._set_global_rot(hi, (to * from.inverse()) * rest.basis)
	for f in ["index", "middle", "ring", "pinky"]:
		for k in [1, 2, 3]:
			var i := sk.find_bone("%s_0%d_%s" % [f, k, side])
			var nxt := sk.find_bone(("%s_0%d_%s" % [f, k + 1, side]) if k < 3 else ("%s_04_leaf_%s" % [f, side]))
			if i < 0 or nxt < 0:
				continue
			sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion())
			var seg := (sk.get_bone_global_pose(nxt).origin - sk.get_bone_global_pose(i).origin).normalized()
			_body._set_global_rot(i, Basis(seg.cross(palm).normalized(), curl) * sk.get_bone_global_pose(i).basis)


func _finish(result: String) -> void:
	if _done:
		return
	_done = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	if _net != null:
		_net.scale = Vector3.ONE
		_net.rotation = Vector3.ZERO
	finished.emit(result)
	queue_free()
