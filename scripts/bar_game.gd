extends Node3D
## Raahen baari: kädenvääntö terästehtaan Teron kanssa. A ja D vuorotellen tasaiseen tahtiin vääntää
## kättä omalle puolelle, Tero vääntää vastaan kasvavin aalloin. Liian hätäinen räpellys ja väärä nappi
## eivät auta. Voittaja on se, jonka puolelle käsi kaatuu (tai joka johtaa ajan loppuessa).
## Häviäjä tarjoaa kierroksen. finished(won) lopuksi; kutsuja poistaa solmun.

signal finished(won: bool)

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Pose := preload("res://scripts/pose.gd")

const TIME := 20.0  # s
const PUSH := 0.07  # oikea painallus oikeaan tahtiin
const SLIP := 0.03  # väärä nappi
const TOO_FAST := 0.09  # s: nopeampi näpyttely on räpellystä
const TERO_FORCE := 0.2  # Teron perusvääntö (/s), kasvaa loppua kohti
const TABLE_Y := 0.68  # vääntöpöytä (keskipiste): pinta 0.71, esikuvan kokoinen
const SEAT_Z := 0.55  # lantion alkuarvaus pöydän keskeltä; _fit sovittaa hahmon pöytään
const TABLE_D := 0.66  # pöydän syvyys (z)
const EDGE := TABLE_D / 2.0  # pöydän reuna keskiviivasta
const ELBOW_R := 0.04  # kyynärnivelen säde: nivel on tämän verran pöydän pinnan yläpuolella
const GRIP_Z := 0.05  # ranne keskiviivalta omalle puolelle
const FOREARM_TILT := 0.6  # kyynärvarren kallistus pystystä keskeä kohti (35°)
const BELLY_GAP := 0.01  # vatsan etupinnan ja pöydän reunan väli
const SHOULDER_BACK := 0.04  # olkapää vatsan etupintaa tämän verran takana
const LEAN0 := 0.30  # kumarruksen alkuarvaus (rad), _fit säätää
const LEAN_MIN := 0.15
const LEAN_MAX := 0.45
const FIT_LAST := 8  # ruutu, jolla sovitus päättyy (λ säädetään ruuduilla 2, 4 ja 6)
const SIDE := 0.15  # hahmo oman kätensä vasemmalla puolella: päät ohi toistensa
const CURL := 1.4  # sormien taivutus nivelessä (rad)
const CURL_JOINT := [1.0, 0.9, 0.45]  # tyvi-, keski- ja kärkinivelen osuus taivutuksesta
const HAND_TILT := 0.87  # kämmenen kallistus vastustajaa kohti (50°)
const THUMB_CURL := 0.9  # peukalon taivutus vastustajan peukalon yli
const TERO_LINES := ["Hnnngh!", "Saloisista vai? Heh.", "Terästehtaalla nostellaan isompia!", "Nyt se lähtee!"]

var _phase := "intro"  # intro | count | wrestle | result
var _t := 0.0
var _angle := 0.0  # -1 Tero voittaa ... +1 pelaaja voittaa
var _next := "left"
var _idle := 1.0
var _talk_t := 2.0
var _frame := 0

var _cam: Camera3D
var _prev_cam: Camera3D
var _me: Node3D  # pelaaja tuulipuvussa pöydän tällä puolella (kamera sivulta pelaajan takaviistosta)
var _tero: Node3D
var _bubble: Label3D
var _layer: CanvasLayer
var _title: Label
var _info: Label
var _meter: ProgressBar


func _ready() -> void:
	process_priority = 10  # hahmojen animaation ja IK:n jälkeen (sormet nyrkkiin)
	_build_room()
	_prev_cam = get_viewport().get_camera_3d()
	# Kamera sivulta pelaajan takaviistosta: kummankin koko vartalo, ote keskellä.
	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)
	_cam.look_at_from_position(to_global(Vector3(1.55, 1.4, 0.75)), to_global(Vector3(0, TABLE_Y + 0.25, -0.05)), Vector3.UP)
	_cam.current = true
	_build_hud()
	_title.text = "RAAHEN BAARI"
	_info.text = "Terästehtaan Tero haastaa kädenvääntöön. Häviäjä tarjoaa kierroksen.\n" \
		+ "Vuorottele %s ja %s tasaiseen tahtiin. Räpellys ei auta.\n\n%s Tartu Teron kättä" % [
			Settings.action_key("left"), Settings.action_key("right"), Settings.cap("interact")]
	_update_arms()


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		"intro":
			if Input.is_action_just_pressed("interact"):
				_phase = "count"
				_t = 0.0
				_info.text = ""
				Sfx.play("punch", -10.0, 0.8)
		"count":
			_title.text = ["3", "2", "1"][mini(int(_t), 2)] if _t < 3.0 else "VÄÄNNÄ!"
			if _t >= 3.0:
				_phase = "wrestle"
				_t = 0.0
				_meter.visible = true
		"wrestle":
			_wrestle(delta)
		"result":
			if _t > 3.2:
				_phase = "done"
				if _prev_cam != null and is_instance_valid(_prev_cam):
					_prev_cam.current = true
				finished.emit(_angle > 0.0)
	_update_arms()
	_fist(_me, CURL)
	_fist(_tero, CURL)


func _wrestle(delta: float) -> void:
	if _t > 0.6:
		_title.text = ""
	_idle += delta
	var other := "right" if _next == "left" else "left"
	if Input.is_action_just_pressed(_next):
		if _idle >= TOO_FAST:
			_angle += PUSH
			if randf() < 0.2:
				Sfx.play("grunt", -8.0, randf_range(0.95, 1.1))
		_next = other
		_idle = 0.0
	elif Input.is_action_just_pressed(other):
		_angle -= SLIP
		_idle = 0.0
	# Tero vääntää aaltoina, ja voimaa tulee lisää loppua kohti.
	var wave := 1.0 + 0.6 * sin(_t * 1.3) + 0.35 * sin(_t * 3.1 + 1.0)
	_angle -= TERO_FORCE * wave * (1.0 + _t / TIME * 0.8) * delta
	_angle = clampf(_angle, -1.0, 1.0)
	_meter.value = (_angle + 1.0) * 50.0
	_info.text = "%s   %d s" % [Settings.cap(_next), ceili(TIME - _t)]
	_talk_t -= delta
	if _talk_t <= 0.0:
		_talk_t = randf_range(2.5, 4.0)
		_bubble.text = "Tero: " + (TERO_LINES.pick_random())
	elif _talk_t < 1.2:
		_bubble.text = ""
	if absf(_angle) >= 1.0 or _t >= TIME:
		_finish()


func _finish() -> void:
	_phase = "result"
	_t = 0.0
	var won := _angle > 0.0
	Sfx.play("punch_heavy", -4.0)
	Sfx.play("win_small" if won else "lose", -4.0)
	_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if won else Color(0.85, 0.08, 0.08))
	_title.text = "VOITIT!" if won else "HÄVISIT!"
	_info.text = "Tero tarjoaa kierroksen." if won else "Sinä tarjoat kierroksen."
	_bubble.text = "Tero: " + ("Perkele, sää oot vahva! Mää tarjoan." if won else "Heh. Sää tarjoot.")
	_tero.play("Sitting_Talking", 0.2)


## Kädet: kyynärpäät pöydällä omalla puolellaan, kyynärvarret kallellaan keskeä kohti otteeseen; kulma kaataa otetta
## kyynärpäiden kautta kulkevan akselin ympäri voittajan vasemmalle.
func _update_arms() -> void:
	_frame += 1
	if _frame >= 2 and _frame <= FIT_LAST:
		_fit(_tero, -1.0, _frame)
		_fit(_me, 1.0, _frame)
	var a := _angle * 1.2
	_reach(_tero, -1.0, a)
	_reach(_me, 1.0, a)


## Kyynärpään kohde E (s = 1 pelaaja +z, -1 Tero): pöydän pinnalla, otteesta kyynärvarren kallistuksen verran omalle puolelle.
func _elbow(ch: Node3D, s: float) -> Vector3:
	var l2: float = ch.get_meta("l2")
	return Vector3(0.025 * s, TABLE_Y + 0.03 + ELBOW_R, s * (GRIP_Z + l2 * sin(FOREARM_TILT)))


## Oikea käsi otteeseen: kyynärpää E, ranne kyynärvarren mitan päässä siitä keskeä kohti ja ylös (kämmenet vastakkain
## kuin kättelyssä). Napa vie kyynärpään taakse-alas omalle puolelle. Kumarrus λ jaetaan selkänikamille ja päälle.
func _reach(ch: Node3D, s: float, a: float) -> void:
	var l2: float = ch.get_meta("l2")
	var elbow := _elbow(ch, s)
	var hz := -s * l2 * sin(FOREARM_TILT)
	var rise := sqrt(maxf(l2 * l2 - hz * hz - 0.022 * 0.022, 0.0))
	var wrist := Vector3(0, elbow.y, elbow.z) + Basis(Vector3.BACK, a) * Vector3(0.022 * s, rise, 0) + Vector3(0, 0, hz)
	var shoulder: Vector3 = ch.transform * ch.bone_position("upperarm_r")
	var pole := elbow + (elbow - (shoulder + wrist) * 0.5).normalized() * 0.3
	var inv := ch.transform.affine_inverse()
	ch.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * wrist, inv * pole)
	var lam: float = ch.get_meta("lam")
	ch.set_override("spine_01", Vector3.RIGHT, -lam * 0.6)  # negatiivinen = eteen
	ch.set_override("spine_02", Vector3.RIGHT, -lam * 0.25)
	ch.set_override("spine_03", Vector3.RIGHT, -lam * 0.15)
	ch.set_override("neck_01", Vector3.RIGHT, lam * 0.35)  # pää vastaan: katse vastustajassa
	ch.set_override("Head", Vector3.RIGHT, lam * 0.25)


## Sovittaa hahmon pöytään vatsan etupinnasta (paistettu verkko, ruudut 2..FIT_LAST): λ säädetään ruuduilla 2, 4 ja 6
## (kumarrus vie olkaa enemmän kuin vatsaa), joka ruutu z viedään niin, että vatsa on reunan takana BELLY_GAP,
## ja y niin, että olkapää on olkavarren mitan päässä kyynärpäästä E. Viimeisellä ruudulla jakkara lantion alle.
func _fit(ch: Node3D, s: float, f: int) -> void:
	var top := TABLE_Y + 0.03
	var torso := Pose.limb_points(ch, self, ["pelvis", "spine_01", "spine_02", "spine_03"])
	var belly := INF
	for q in torso:
		if q.y > top - 0.07 and q.y < top + 0.01 and absf(q.x) < 0.5:
			belly = minf(belly, q.z * s)
	if belly == INF:  # headless: ei verkkoa, varalla selkäranka
		belly = (ch.transform * ch.bone_position("spine_02")).z * s - 0.14
	var sh: Vector3 = ch.transform * ch.bone_position("upperarm_r")
	if f % 2 == 0 and f < FIT_LAST:
		var lam: float = ch.get_meta("lam")
		var k := sh.z * s - belly
		lam += (k - BELLY_GAP - SHOULDER_BACK) / maxf(sh.y - top, 0.05)
		ch.set_meta("lam", clampf(lam, LEAN_MIN, LEAN_MAX))
	var dz := (EDGE + BELLY_GAP - belly) * s
	ch.position.z += dz
	sh.z += dz
	var l1: float = ch.get_meta("l1")
	var e := _elbow(ch, s)
	var dx := sh.x - e.x
	var h := absf(sh.z - e.z)
	var rad := l1 * l1 - dx * dx - h * h
	if rad < 0.36 * l1 * l1:
		push_warning("baari: olkavarsi ei yllä (%s)" % ch.name)
		rad = 0.36 * l1 * l1
	ch.position.y += e.y + sqrt(rad) - sh.y
	if f == FIT_LAST:
		Pose.feet_to_floor(ch, 0.0, Vector3(-0.35 * s, 0, -s))  # polvet hahmon vasemmalle
		var pv: Vector3 = ch.transform * ch.bone_position("pelvis")
		var seat_top := pv.y - Pose.HIP_OVER_SEAT
		B.box(self, Vector3(0.45, seat_top, 0.4), Vector3(pv.x, seat_top / 2.0, pv.z + 0.04 * s), Color(0.35, 0.22, 0.12), false)
		if ch == _tero:
			_bubble.position = ch.transform * ch.bone_position("Head") + Vector3(0, 0.35, 0)
		print("baari_fit ", "pelaaja" if s > 0.0 else "tero", " lam ", snappedf(ch.get_meta("lam"), 0.001), " jakkara ", snappedf(seat_top, 0.001))


## Sormet nyrkkiin toisen kouran ympäri: jokainen nivel lepoasennosta (suorat sormet) taivutetaan kämmenen
## puolelle (jokainen nivel jänteen ja kämmenen normaalin mukaan). Ajetaan IK:n jälkeen joka ruutu.
func _fist(ch: Node3D, curl: float) -> void:
	var sk: Skeleton3D = ch.skeleton
	# Kämmen kyynärvarren jatkona mutta kallistettuna vastustajaa kohti (HAND_TILT): sormet osoittavat vinosti
	# eteen, etusormi ylimpänä, ja kiertyvät vaakasuoraan vastustajan kämmenselän ympäri kuten oikeassa otteessa.
	# Kämmen vasemmalle vastustajan kämmentä vasten. Lepoasennon T-asennossa sormet oikealle, kämmen alas.
	var to_char: Basis = (ch.model.transform * sk.transform).basis
	var hi := sk.find_bone("hand_r")
	var fore := (to_char * (sk.get_bone_global_pose(hi).origin
		- sk.get_bone_global_pose(sk.find_bone("lowerarm_r")).origin)).normalized()
	var toward := (Vector3.FORWARD - fore * Vector3.FORWARD.dot(fore)).normalized()  # vastustajaa kohti
	var fingers := fore * cos(HAND_TILT) + toward * sin(HAND_TILT)
	var palm := (Vector3.LEFT - fingers * Vector3.LEFT.dot(fingers)).normalized()  # kämmenen normaali
	var hand_b := Basis(fingers, -palm, fingers.cross(-palm))  # T-asennon akselit (sormet, kämmenselkä, ...) -> nyt
	ch._set_global_rot(hi, to_char.inverse() * hand_b * to_char * sk.get_bone_global_rest(hi).basis)
	# Jokainen nivel taipuu kämmenen puolelle: akseli = jänteen suunta x kämmenen normaali, jolloin positiivinen
	# kierto vie jänteen kärjen kohti kämmentä. Tyvi- ja keskinivel paljon, kärkinivel vähemmän, jotta sormet
	# kiertävät toisen kämmenselän ympäri eivätkä puristu nyrkiksi sen läpi.
	var palm_skel := (to_char.inverse() * palm).normalized()  # kämmenen puoli luurangon avaruudessa
	for f in ["index", "middle", "ring", "pinky"]:
		for k in [1, 2, 3]:
			var i := sk.find_bone("%s_0%d_r" % [f, k])
			sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion())
			var nxt := sk.find_bone("%s_0%d_r" % [f, k + 1] if k < 3 else "%s_04_leaf_r" % f)
			var seg := (sk.get_bone_global_pose(nxt).origin - sk.get_bone_global_pose(i).origin).normalized()
			ch._set_global_rot(i, Basis(seg.cross(palm_skel).normalized(), curl * CURL_JOINT[k - 1])
				* sk.get_bone_global_pose(i).basis)
	# Peukalo lukitsee vastustajan peukalon (kädenväännön ote "peukaloista", yläknoa näkyvissä): kärki taipuu
	# kämmenen puolelle vastustajan käden yli samalla tavalla.
	for k in ["02", "03"]:
		var i := sk.find_bone("thumb_%s_r" % k)
		sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion())
		var tip := sk.get_bone_global_pose(sk.find_bone("thumb_03_r" if k == "02" else "thumb_04_leaf_r")).origin
		var t_dir := (tip - sk.get_bone_global_pose(i).origin).normalized()
		var t_axis := t_dir.cross(palm_skel).normalized()
		ch._set_global_rot(i, Basis(t_axis, THUMB_CURL) * sk.get_bone_global_pose(i).basis)


func _build_room() -> void:
	var wood := Color(0.35, 0.22, 0.12)
	B.box(self, Vector3(8, 0.1, 8), Vector3(0, -0.05, 0), Color(0.25, 0.18, 0.12), false)
	B.box(self, Vector3(8, 3, 0.2), Vector3(0, 1.5, -3.5), Color(0.45, 0.2, 0.15), false)
	B.box(self, Vector3(0.2, 3, 8), Vector3(-3.5, 1.5, 0), Color(0.45, 0.2, 0.15), false)
	B.box(self, Vector3(0.2, 3, 8), Vector3(3.5, 1.5, 0), Color(0.45, 0.2, 0.15), false)
	B.box(self, Vector3(8, 0.2, 8), Vector3(0, 3.0, 0), Color(0.12, 0.1, 0.08), false)
	# Baaritiski ja pullohylly takaseinällä.
	B.box(self, Vector3(4.5, 1.1, 0.6), Vector3(-0.8, 0.55, -2.6), wood, false)
	B.box(self, Vector3(4.6, 0.06, 0.7), Vector3(-0.8, 1.12, -2.6), Color(0.2, 0.12, 0.06), false)
	for i in 14:
		var c: Color = [Color(0.2, 0.45, 0.2), Color(0.55, 0.35, 0.1), Color(0.8, 0.8, 0.85)][i % 3]
		B.mesh(self, B.cyl(0.04, 0.04, 0.3, 8), Vector3(-2.6 + i * 0.28, 1.75, -3.3), c)
	B.box(self, Vector3(4.2, 0.04, 0.25), Vector3(-0.8, 1.58, -3.3), wood, false)
	# Pöytä, jonka ääressä väännetään, ja tuopit sivussa.
	B.box(self, Vector3(1.0, 0.06, TABLE_D), Vector3(0, TABLE_Y, 0), wood, false)
	B.box(self, Vector3(0.12, TABLE_Y, 0.12), Vector3(0, TABLE_Y / 2.0, 0), Color(0.15, 0.15, 0.15), false)
	for z in [-0.2, 0.2]:  # tuopit pöydän päässä, ei kameran ja otteen välissä
		B.mesh(self, B.cyl(0.045, 0.04, 0.15, 10), Vector3(-0.4, TABLE_Y + 0.1, z), Color(0.9, 0.7, 0.2))
	# Tero ja pelaaja jakkaroillaan vastakkain; istuma-animaatio vie lantion origon taakse, joten hahmo
	# asetetaan lantion mukaan (kuten bingossa).
	_tero = _seat(Looks.TERO, -1.0)
	_bubble = B.bubble(self, Vector3(0.35, 1.5, -SEAT_Z), Color.WHITE)
	_me = _seat(Looks.player(), 1.0)
	Looks.add_cap(_me)
	for p in [Vector3(-1.5, 2.6, -1.5), Vector3(1.2, 2.6, 0.8)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color(1.0, 0.75, 0.45)
		l.light_energy = 1.6
		l.omni_range = 6.0
		add_child(l)


## Hahmo istumaan pöydän puolelle s (1 = +z, kasvot pöytään päin). Vain istuttaa: paikan (z, y), kumarruksen ja
## jakkaran laskee _fit ruuduilla, kun hahmon paistettu pinta on käytettävissä.
func _seat(look: Dictionary, s: float) -> Node3D:
	var c := Looks.make(self, look)
	c.rotation.y = 0.0 if s > 0.0 else PI
	c.play("Sitting_Idle", 0.0)
	c.anim.advance(0.01)
	var pel: Vector3 = c.basis * c.bone_position("pelvis")
	c.position = Vector3(-pel.x - SIDE * s, 0.40 - pel.y, SEAT_Z * s - pel.z)
	c.set_meta("l1", c.bone_position("upperarm_r").distance_to(c.bone_position("lowerarm_r")))
	c.set_meta("l2", c.bone_position("lowerarm_r").distance_to(c.bone_position("hand_r")))
	c.set_meta("lam", LEAN0)
	Pose.feet_to_floor(c, 0.0, Vector3(-0.35 * s, 0, -s))  # polvet hahmon vasemmalle
	return c


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 40
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 12)
	_layer.add_child(_title)
	_info = Label.new()
	_info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_info.offset_top = -200
	_info.offset_bottom = -70
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 24)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 8)
	_layer.add_child(_info)
	_meter = ProgressBar.new()
	_meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_meter.offset_left = -220
	_meter.offset_right = 220
	_meter.offset_top = -50
	_meter.offset_bottom = -32
	_meter.show_percentage = false
	_meter.value = 50.0
	_meter.visible = false  # näkyviin väännön alkaessa
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.8, 0.4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.85, 0.2, 0.15, 0.8)
	_meter.add_theme_stylebox_override("fill", fill)
	_meter.add_theme_stylebox_override("background", bg)
	_layer.add_child(_meter)
