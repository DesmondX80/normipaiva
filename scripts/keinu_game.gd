extends Node3D
## Aikuisen keinuhyppykisa leikkipuistossa (#146), pelataan oikealla keinulla: pelaajan hahmo istuu keinussa kädet
## ketjuissa, kamera kuvaa sivulta ja penkin äidit katsovat taustalla. D eteenpäin heilahtaessa ja A taaksepäin
## heilahtaessa lisää vauhtia (jalat ojentuvat ja koukistuvat), väärä tahti hidastaa. Liian kova vauhti löysää ketjut.
## Välilyönti hyppää: eteenpäin heilahduksen nousussa pitkä lento, taaksepäin heilahtaessa selälleen hiekkaan.
## Pituus mitataan keinutelineen alta; hiekassa ennätyslippu, oma paras ja metrimerkit. F / Esc luovuttaa.
## Solmu lisätään keinutelineen (world.gd playgrounds[i].frame) lapseksi: paikallinen orsi on X-akselin suuntainen
## korkeudella PIVOT_H, keinu SEAT_X:ssä ja hyppy +Z-suuntaan. finished(metrit, kaatui); landing = alastulopaikka.

signal finished(dist: float, crashed: bool)

const MG := preload("res://scripts/mg_draw.gd")
const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const L := 1.9  # ketjun pituus (m)
const PIVOT_H := 2.4
const SEAT_X := 0.7  # käytettävä keinu (world.gd Keinu1)
const G := 9.81
const PUMP := 0.32
const TIME := 30.0
const MUM_LINES := ["Äiti penkillä: \"Joko se setä lopettaa?\"", "Äiti penkillä: \"Eetu, tuu pois sieltä keinun läheltä.\"",
	"Pikkupoika: \"Äiti, miks tuo setä keinuu?\"", "Äiti penkillä kaivaa puhelimen esiin..."]

var record := 3.4
var record_holder := "Honganpalon Jere"
var best := 0.0
var drunk := 0.0
var landing := Vector3.ZERO  # alastulopaikka maailmassa (main.gd siirtää pelaajan siihen)

var _hud: CanvasLayer
var _gauge: Control
var _info: Label
var _tip: Label
var _keys: Control
var _phase := "swing"  # swing / fly / landed / done
var _t := -1.5
var _th := 0.15  # kulma (rad), + = eteenpäin
var _w := 0.0  # kulmanopeus
var _last := ""
var _pos := Vector2.ZERO  # lento (m): x eteenpäin telineen alta, y maasta
var _vel := Vector2.ZERO
var _crash := false
var _dist := 0.0
var _shake := 0.0
var _tip_t := 5.0
var _slack := 0.0
var _leg := 0.0  # -1 jalat koukussa taakse .. 1 ojennettu eteen
var _hidden: Node3D  # maailman oma keinu piilossa pelin ajan

var _pivot: Node3D
var _chains: Array[MeshInstance3D] = []
var _seat: Node3D
var _rider: Node3D
var _cam: Camera3D
var _cam_z := 1.0
var _dust: CPUParticles3D
var _dist_sign: Node3D


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	_hidden = get_parent().get_node_or_null("Keinu1")
	if _hidden != null:
		_hidden.visible = false
	_build_swing()
	_build_marks()
	_cam = Camera3D.new()
	_cam.fov = 55.0
	add_child(_cam)
	_cam.current = true
	_place_camera(1.0, true)
	_build_hud()
	_tip.text = ("Keinuhyppy! Oma ennätys %s m. Vauhtia oikeaan tahtiin." % _m(record)) if _own_record() else \
		"Keinuhyppy! Ennätys %s %s m. Vauhtia oikeaan tahtiin." % [record_holder, _m(record)]


static func _m(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")


# --- Rakennus ------------------------------------------------------------------

func _build_swing() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(SEAT_X, PIVOT_H, 0)
	add_child(_pivot)
	for cx in [-0.2, 0.2]:
		var ch := B.mesh(_pivot, B.cyl(0.012, 0.012, L, 4), Vector3(cx, -L / 2.0, 0), Color(0.7, 0.7, 0.72))
		_chains.append(ch)
	_seat = Node3D.new()
	_seat.position = Vector3(0, -L, 0)
	_pivot.add_child(_seat)
	B.mesh(_seat, B.boxm(Vector3(0.45, 0.04, 0.2)), Vector3.ZERO, Color(0.1, 0.1, 0.1))
	_rider = Looks.make(self, Looks.player())
	Looks.add_cap(_rider)
	_rider.play("Sitting_Idle", 0.0)
	_rider.anim.advance(0.01)
	_dust = CPUParticles3D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 40
	_dust.lifetime = 0.9
	_dust.explosiveness = 0.95
	_dust.direction = Vector3(0, 1, 0)
	_dust.spread = 70.0
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 2.6
	_dust.gravity = Vector3(0, -6, 0)
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.4
	var dm := BoxMesh.new()
	dm.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.8, 0.58)
	mat.roughness = 1.0
	dm.material = mat
	_dust.mesh = dm
	add_child(_dust)


## Hiekkaan liidulla metrimerkit, kyltit parillisille metreille, ennätyslippu ja oma paras.
func _build_marks() -> void:
	for m in range(1, 8):
		B.mesh(self, B.boxm(Vector3(0.7, 0.005, 0.04)), Vector3(SEAT_X, 0.035, m), Color(0.97, 0.97, 0.95))
		if m % 2 == 0:
			B.mesh(self, B.boxm(Vector3(0.03, 0.4, 0.03)), Vector3(SEAT_X + 0.5, 0.2, m), Color(0.5, 0.35, 0.2))
			var s := B.sign_plate(self, "%d m" % m, Color(0.95, 0.93, 0.85), Color(0.2, 0.15, 0.1), 0.12, 32, Color(0.5, 0.35, 0.2))
			s.position = Vector3(SEAT_X + 0.5, 0.45, m)
			s.rotation.y = -PI / 2.0
	if not _own_record():  # oma ennätys: OMA-lippu riittää
		_flag(record, Color(0.9, 0.15, 0.15), "%s %s" % [record_holder.get_slice(" ", record_holder.get_slice_count(" ") - 1).to_upper(), _m(record)], -0.45)
	if best > 0.0:
		_flag(best, Color(0.2, 0.5, 0.9), "OMA %s" % _m(best), -0.75)


## Ennätys on pelaajan oma (main.gd asettaa haltijaksi "Järvikuja 1").
func _own_record() -> bool:
	return record_holder == "Järvikuja 1"


func _flag(at: float, col: Color, text: String, dx: float) -> void:
	var p := Vector3(SEAT_X + dx, 0, at)
	B.mesh(self, B.cyl(0.015, 0.015, 1.2, 6), p + Vector3(0, 0.6, 0), Color(0.75, 0.75, 0.78))
	var flag := B.mesh(self, B.boxm(Vector3(0.01, 0.2, 0.32)), p + Vector3(0, 1.08, -0.16), col)
	flag.rotation.x = 0.05
	var s := B.sign_plate(self, text, col.darkened(0.2), Color.WHITE, 0.1, 28, Color.WHITE)
	s.position = p + Vector3(0, 0.8, 0)
	s.rotation.y = -PI / 2.0


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	_gauge = Control.new()
	_gauge.position = Vector2(40, 80)
	_gauge.size = Vector2(240, 120)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	_hud.add_child(_gauge)
	_info = _label(26, 18.0, false)
	_tip = _label(24, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	_hud.add_child(_keys)


func _label(size: int, y: float, bottom: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.anchor_right = 1.0
	if bottom:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(l)
	return l


# --- Peli ----------------------------------------------------------------------

func _seat_pos() -> Vector2:
	return Vector2(sin(_th) * L, PIVOT_H - cos(_th) * L)


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	_slack = maxf(0.0, _slack - delta)
	_gauge.queue_redraw()
	if _phase != "done":
		if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
			_finish("Luovutit. Pikkupoika pääsee vihdoin keinuun.")
		else:
			match _phase:
				"swing":
					_swing(delta)
				"fly":
					_fly(delta)
				"landed":
					if _t > 2.0:
						var txt := ""
						if _crash:
							txt = "Selälleen hiekkaan! %s m. Äidit pudistelee päätään." % _m(_dist)
						elif _dist > record and _own_record():
							txt = "%s METRIÄ! Oma ennätys parani." % _m(_dist)
						elif _dist > record:
							txt = "%s METRIÄ! UUSI ENNÄTYS! %s jää historiaan." % [_m(_dist), record_holder]
						else:
							txt = ("%s metriä. Oma ennätys %s m pitää." % [_m(_dist), _m(record)]) if _own_record() else \
								"%s metriä. Ennätys %s %s m pitää." % [_m(_dist), record_holder, _m(record)]
						_finish(txt)
	_pose(delta)
	_info.text = ("Keinuhyppy · ennätys %s m (sinun)" % _m(record)) if _own_record() else \
		"Keinuhyppy · ennätys %s %s m%s" % [record_holder, _m(record), (" · oma %s m" % _m(best)) if best > 0.0 else ""]
	if _phase in ["landed", "done"] and _dist > 0.0:
		_info.text = "%s m" % _m(_dist) + ("  ·  UUSI ENNÄTYS!" if _dist > record and not _crash else "")
	_keys.set_text("%s eteen heilahtaessa · %s taakse heilahtaessa · %s hyppää · %s luovuta" % [Settings.cap("right"),
		Settings.cap("left"), Settings.cap("jump"), Settings.cap("mount")])


func _swing(delta: float) -> void:
	if _t < 0.0:
		return
	# Heiluri: painovoima, pieni vaimennus ja ketjujen löystyminen liian korkealla.
	_w += (-G / L * sin(_th) - 0.12 * _w) * delta
	_th += _w * delta
	if absf(_th) > 1.45:
		_th = signf(_th) * 1.45
		_w *= -0.3
		_slack = 0.6
		_shake = 0.6
		Sfx.play("rattle_hard", -6.0, 1.3)
		_tip.text = "KLONK! Ketjut löystyi. Äidit kirkaisee."
	for k in [["right", 1.0], ["left", -1.0]]:  # kamera sivulta: eteenpäin heilahdus menee ruudulla oikealle
		if Input.is_action_just_pressed(k[0]):
			var right: bool = signf(_w) == k[1] and absf(_th) < 0.9
			if right and k[0] != _last:
				_w += k[1] * PUMP * (1.0 - drunk * 0.4)
				Sfx.play("pedal_creak", -12.0, 1.2)
			else:
				_w *= 0.85
				_tip.text = "Väärä tahti! Keinu hidastuu."
			_last = k[0]
	if Input.is_action_just_pressed("jump"):
		var s := _seat_pos()
		_pos = s + Vector2(0, 0.45)
		var v := _w * L
		_vel = Vector2(cos(_th), sin(_th)) * v
		_crash = _w < 0.0 or absf(v) < 0.6
		_phase = "fly"
		_t = 0.0
		_rider.restart("Jump", 0.1)
		Sfx.play("whoosh", -4.0, 1.0)
		return
	if _t > TIME:
		_tip.text = "Äiti: \"Nyt riittää!\" Hyppää tai luovuta."
	_tip_t -= delta
	if _tip_t <= 0.0:
		_tip_t = 6.0
		_tip.text = MUM_LINES.pick_random()


func _fly(delta: float) -> void:
	_vel.y -= G * delta
	_pos += _vel * delta
	# Tyhjä keinu heiluu vielä hetken ja hiljenee.
	_w += (-G / L * sin(_th) - 0.6 * _w) * delta
	_th += _w * delta
	if _pos.y <= 0.0:
		_pos.y = 0.0
		_dist = maxf(0.0, _pos.x)
		_phase = "landed"
		_t = 0.0
		_shake = 1.0 if _crash else 0.6
		landing = to_global(Vector3(SEAT_X, 0, _dist))
		_dust.position = Vector3(SEAT_X, 0.1, _dist)
		_dust.restart()
		if _crash:
			_rider.restart("Death01", 0.15)
		else:
			_rider.restart("Jump_Land", 0.1)
		Sfx.play("body_fall" if _crash else "step_grass", -2.0, 0.8)
		var s := B.sign_plate(self, "%s m" % _m(_dist), Color(1.0, 0.92, 0.3), Color(0.15, 0.1, 0.05), 0.16, 40, Color(0.2, 0.15, 0.1))
		s.position = Vector3(SEAT_X + 0.6, 0.95, _dist)  # merkkikepin nokassa hiekassa keinujan takana
		B.mesh(self, B.boxm(Vector3(0.03, 0.9, 0.03)), Vector3(SEAT_X + 0.6, 0.45, _dist), Color(0.5, 0.35, 0.2))
		s.rotation.y = -PI / 2.0
		_dist_sign = s


## Keinu, ketjut ja keinuja: istuessa kädet ketjuissa ja jalat pumppaavat, lennossa hyppy (kaatuessa
## selkä edellä pyörähtäen), alastulon jälkeen hiekalla.
func _pose(delta: float) -> void:
	_pivot.rotation.x = -_th
	var sag := _slack * 0.12
	for ch in _chains:
		ch.scale.y = 1.0 - sag * 0.2
	if _phase == "swing":
		var want := clampf(_w * 1.5, -1.0, 1.0)
		_leg = lerpf(_leg, want, 1.0 - exp(-6.0 * delta))
		var seat_g: Vector3 = _seat.position.rotated(Vector3.RIGHT, -_th) + _pivot.position
		_rider.position = seat_g + Vector3(0, 0.03, 0)
		_rider.rotation = Vector3(-_th * 0.85, PI, 0)
		_rider.position -= _rider.basis * _rider.bone_position("pelvis")
		var inv: Transform3D = _rider.transform.affine_inverse()
		var pv: Vector3 = _pivot.position
		for side in [["_l", -1.0], ["_r", 1.0]]:
			var s: float = side[1]
			# Ote ketjusta 0,55 m istuimen yläpuolelta.
			var grip: Vector3 = pv + Vector3(0.2 * s, -(L - 0.6), 0).rotated(Vector3.RIGHT, -_th)
			_rider.set_ik("arm" + side[0], "upperarm" + side[0], "lowerarm" + side[0], "hand" + side[0],
				inv * grip, inv * (grip + Vector3(0.4 * s, -0.3, -0.3)))
			# Jalat: ojennettu eteen tai koukussa istuimen alle.
			var fwd := Vector3(0.14 * s, -0.12 + 0.12 * _leg, 0.25 + 0.4 * maxf(_leg, 0.0) - 0.4 * maxf(-_leg, 0.0))
			var foot: Vector3 = seat_g + fwd.rotated(Vector3.RIGHT, -_th) - Vector3(0, 0.35 * (1.0 - absf(_leg)) * 0.5, 0)
			_rider.set_ik("leg" + side[0], "thigh" + side[0], "calf" + side[0], "foot" + side[0],
				inv * foot, inv * (seat_g + Vector3(0.14 * s, 0.4, 1.0)))
		_place_camera(delta)
		return
	_rider.clear_ik()
	if _phase == "fly":
		_rider.position = Vector3(SEAT_X, _pos.y - 0.5, _pos.x)
		var spin := (-_t * 6.0) if _crash else -0.25
		_rider.rotation = Vector3(spin, PI, 0)
	else:
		_rider.position = Vector3(SEAT_X, 0.0, _dist)
		_rider.rotation = Vector3(0, PI, 0)
		if _t > 0.6 and not _crash:
			_rider.play("Idle", 0.3)
	_place_camera(delta)


## Kamera sivulta (-X, liukumäen vastapuolelta: penkin äidit näkyvät taustalla), seuraa lentoa ja alastuloa; tärähtää ketjujen kolahtaessa ja alastulossa.
func _place_camera(delta: float, snap := false) -> void:
	var target_z := 0.8
	if _phase in ["fly", "landed", "done"]:
		target_z = maxf(0.8, _pos.x * 0.75 + 0.4)
	_cam_z = target_z if snap else lerpf(_cam_z, target_z, 1.0 - exp(-3.0 * delta))
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.08
	_cam.position = Vector3(SEAT_X - 6.4, 2.0, _cam_z + 0.4) + shake
	_cam.look_at(to_global(Vector3(SEAT_X, 1.25, _cam_z)), Vector3.UP)


func _finish(text: String) -> void:
	_phase = "done"
	_tip.text = text
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		if _hidden != null:
			_hidden.visible = true
		finished.emit(_dist, _crash)
		queue_free())


# --- HUD -----------------------------------------------------------------------

## Vauhtimittari: keinun kulma.
func _draw_gauge() -> void:
	var g := Rect2(Vector2.ZERO, _gauge.size)
	MG.box(_gauge, g, Color(0.08, 0.08, 0.1, 0.85), 10)
	var gc := g.position + Vector2(g.size.x / 2.0, g.size.y - 14)
	_gauge.draw_arc(gc, 90.0, PI, TAU, 30, Color(0.4, 0.4, 0.45), 8.0)
	var amp := clampf(absf(_th) / 1.45, 0.0, 1.0)
	_gauge.draw_arc(gc, 90.0, PI, PI + PI * amp, 30, Color(0.3, 0.9, 0.3).lerp(Color(0.95, 0.3, 0.2), maxf(0.0, amp - 0.75) * 4.0), 8.0)
	_gauge.draw_string(ThemeDB.fallback_font, gc + Vector2(-60, -20), "VAUHTI", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, Color.WHITE)
