extends Node3D
## Raahen baari: kädenvääntö terästehtaan Teron kanssa. A ja D vuorotellen tasaiseen tahtiin vääntää
## kättä omalle puolelle, Tero vääntää vastaan kasvavin aalloin. Liian hätäinen räpellys ja väärä nappi
## eivät auta. Voittaja on se, jonka puolelle käsi kaatuu (tai joka johtaa ajan loppuessa).
## Häviäjä tarjoaa kierroksen. finished(won) lopuksi; kutsuja poistaa solmun.

signal finished(won: bool)

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const TIME := 20.0  # s
const PUSH := 0.07  # oikea painallus oikeaan tahtiin
const SLIP := 0.03  # väärä nappi
const TOO_FAST := 0.09  # s: nopeampi näpyttely on räpellystä
const TERO_FORCE := 0.2  # Teron perusvääntö (/s), kasvaa loppua kohti
const TABLE_Y := 0.76
const HANDS_Z := -0.1  # kourien kohta pöydällä (Teron puolella keskikohtaa)
const SKIN := Color(0.93, 0.76, 0.64)
const TERO_LINES := ["Hnnngh!", "Saloisista vai? Heh.", "Terästehtaalla nostellaan isompia!", "Nyt se lähtee!"]

var _phase := "intro"  # intro | count | wrestle | result
var _t := 0.0
var _angle := 0.0  # -1 Tero voittaa ... +1 pelaaja voittaa
var _next := "left"
var _idle := 1.0
var _talk_t := 2.0

var _cam: Camera3D
var _prev_cam: Camera3D
var _hand: MeshInstance3D
var _my_arm: MeshInstance3D
var _tero: Node3D
var _bubble: Label3D
var _layer: CanvasLayer
var _title: Label
var _info: Label
var _meter: ProgressBar


func _ready() -> void:
	_build_room()
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.05
	add_child(_cam)
	_cam.look_at_from_position(to_global(Vector3(0.08, 1.32, 0.95)), to_global(Vector3(0, 0.98, -0.45)), Vector3.UP)
	_cam.current = true
	_build_hud()
	_title.text = "RAAHEN BAARI"
	_info.text = "Terästehtaan Tero haastaa kädenvääntöön. Häviäjä tarjoaa kierroksen.\n" \
		+ "Vuorottele A ja D tasaiseen tahtiin. Räpellys ei auta.\n\n[E] Tartu Teron kättä"
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
	_info.text = "%s   %d s" % ["[A]" if _next == "left" else "[D]", ceili(TIME - _t)]
	_talk_t -= delta
	if _talk_t <= 0.0:
		_talk_t = randf_range(2.5, 4.0)
		_bubble.text = TERO_LINES.pick_random()
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
	_bubble.text = "Perkele, sää oot vahva! Mää tarjoan." if won else "Heh. Sää tarjoot."
	_tero.play("Sitting_Talking", 0.2)


## Kädet: kyynärpäät pöydällä, kourat yhdessä; kulma kallistaa kouria voittajan vasemmalle.
## Pelaajan kyynärvarsi on oma kappaleensa (ensimmäinen persoona), Tero kurottaa omalla kädellään (IK).
func _update_arms() -> void:
	var a := _angle * 1.2
	var hand := Vector3(-sin(a) * 0.28, TABLE_Y + 0.05 + cos(a) * 0.28, HANDS_Z)
	_hand.position = hand
	_place_arm(_my_arm, Vector3(0.03, TABLE_Y + 0.05, HANDS_Z + 0.28), hand)
	var inv := _tero.transform.affine_inverse()
	_tero.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * (hand + Vector3(0, 0, -0.06)),
		inv * Vector3(-0.35, TABLE_Y - 0.1, HANDS_Z - 0.35))
	_tero.set_override("spine_01", Vector3.RIGHT, 0.15 + maxf(0.0, -_angle) * 0.15)


func _place_arm(arm: MeshInstance3D, elbow: Vector3, hand: Vector3) -> void:
	(arm.mesh as BoxMesh).size = Vector3(0.09, 0.09, elbow.distance_to(hand))
	arm.position = (elbow + hand) / 2.0
	arm.look_at(to_global(hand), Vector3.RIGHT)


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
	B.box(self, Vector3(1.2, 0.06, 0.9), Vector3(0, TABLE_Y, 0), wood, false)
	B.box(self, Vector3(0.12, TABLE_Y, 0.12), Vector3(0, TABLE_Y / 2.0, 0), Color(0.15, 0.15, 0.15), false)
	for x in [-0.45, 0.45]:
		B.mesh(self, B.cyl(0.045, 0.04, 0.15, 10), Vector3(x, TABLE_Y + 0.1, 0.25 if x > 0 else -0.25), Color(0.9, 0.7, 0.2))
	B.box(self, Vector3(0.5, 0.45, 0.45), Vector3(0, 0.22, -0.72), wood, false)  # Teron jakkara
	_tero = Looks.make(self, Looks.TERO)
	_tero.position = Vector3(0, 0.0, -0.62)
	_tero.rotation.y = PI
	_tero.play("Sitting_Idle", 0.0)
	_bubble = B.label(self, "", Vector3(0.35, 1.72, -0.62), 12, Color.WHITE, true)
	_bubble.outline_size = 4
	# Kädet.
	_my_arm = _arm_mesh()
	_hand = MeshInstance3D.new()
	_hand.mesh = B.sphere(0.075, 10)
	_hand.material_override = _skin()
	add_child(_hand)
	for p in [Vector3(-1.5, 2.6, -1.5), Vector3(1.2, 2.6, 0.8)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color(1.0, 0.75, 0.45)
		l.light_energy = 1.6
		l.omni_range = 6.0
		add_child(l)


func _arm_mesh() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	m.material_override = _skin()
	add_child(m)
	return m


func _skin() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = SKIN
	m.roughness = 0.7
	return m


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
