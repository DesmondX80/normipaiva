extends Node3D
## Muskelivene Oulujärvelle: punavalkoinen nopea moottorivene ja sillä ajo. W/S kaasu, A/D ohjaus, E laiturille
## ja pois. Vene liikkuu vain siellä, missä vaala.boat_free(x, z) on tosi (esilaskettu venemaski), ja y tulee
## vaala.water_y(x, z):stä. Oma kamera kuten fish_game.gd. Vaala-kehyksen lapsi: koordinaatit ovat Vaalan.
## build(parent) rakentaa pelkän veneen (myös parkissa olevaksi): keula -Z, vesiraja y = 0.
## finished(pos): vene on takaisin parkissa (start), pos on parkin paikka.

signal finished(pos: Vector3)

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const L := 7.0              # rungon pituus
const W := 2.4              # leveys
const FREEBOARD := 0.9      # laidan korkeus perässä (vesirajasta)
const TRANSOM_H := 0.9      # peräpeilin yläreuna
const DRAFT := 0.35         # kölin syvyys perässä
const MAX_SPEED := 17.0     # n. 60 km/h
const REVERSE_SPEED := 3.0
const ACCEL := 6.0
const DRAG := 2.2
const TURN := 0.75

const SEAT_Z := 0.6
const SEAT_TOP := 0.62

static var _hull_mat: StandardMaterial3D

var vaala: Object
var drunk := 0.0
var start := Transform3D.IDENTITY

var _parts := {}
var _boat: Node3D
var _cam: Camera3D
var _pos := Vector3.ZERO
var _yaw := 0.0
var _speed := 0.0
var _turn_v := 0.0
var _pitch := 0.0
var _roll := 0.0
var _t := 0.0
var _shake := 0.0
var _bump_cd := 0.0
var _blocked_t := 0.0
var _hist: Array = []
var _hist_t := 0.0
var _slide_t := 0.0  # alun liuku: paikka on laiturien väliin jäävä tasku, josta ei käännytä ulos
var _state := "drive"       # drive | dock
var _engine: AudioStreamPlayer
var _ui: CanvasLayer
var _hint: Control
var _msg: Label
var _spd_label: Label
var _msg_t := 0.0
var _splash_t := 0.0


func _ready() -> void:
	_boat = Node3D.new()
	add_child(_boat)
	_parts = build(_boat, true)
	_yaw = start.basis.get_euler().y
	_pos = start.origin
	_pos.y = _wy(_pos.x, _pos.z)
	_hist.append([_pos, _yaw])
	_cam = Camera3D.new()
	_cam.fov = 68.0
	_cam.far = 1500.0
	add_child(_cam)
	_cam.current = true
	_engine = AudioStreamPlayer.new()
	_engine.stream = Sfx.stream("engine")
	_engine.bus = "SFX"
	_engine.volume_db = -8.0
	_engine.pitch_scale = 0.5
	add_child(_engine)
	_engine.play()
	_build_ui()
	_apply_pose(0.0)
	_cam.position = _cam_target()
	_say("Muskelivene. %s kaasu, %s ohjaus. Laiturille palaat %s." % [
		Settings.pair("forward", "back"), Settings.pair("left", "right"), Settings.action_key("interact")], 4.0)


# ---------- Vene ----------

## Rungon poikkileikkaus: [x-kerroin, y, väri] vasemmalta laidalta pohjaan. Oikea puoli peilataan.
static func _ring(t: float) -> Array:
	# t = 0 keula, 1 perä.
	var k := clampf(t / 0.55, 0.0, 1.0)
	var hw := W * 0.5 * (pow(k, 0.65) * 0.97 + 0.03)
	var g := FREEBOARD + 0.4 * pow(1.0 - t, 2.2)           # laita nousee keulassa
	var keel := lerpf(0.08, -DRAFT, clampf(t / 0.6, 0.0, 1.0))
	var white := Color(0.95, 0.95, 0.92)
	var red := Color(0.78, 0.1, 0.1)
	var dark := Color(0.42, 0.06, 0.07)
	var pts: Array = []
	pts.append([Vector3(hw, g, 0), white])
	pts.append([Vector3(hw * 0.985, g - 0.28, 0), white])
	pts.append([Vector3(hw * 0.98, g - 0.3, 0), red])
	pts.append([Vector3(hw * 0.93, minf(0.0, g - 0.31), 0), red])
	pts.append([Vector3(hw * 0.9, 0.0, 0), dark])
	pts.append([Vector3(hw * 0.62, lerpf(keel, 0.0, 0.3), 0), dark])
	pts.append([Vector3(0, keel, 0), dark])
	return pts


static func _hull_material() -> StandardMaterial3D:
	if _hull_mat == null:
		_hull_mat = StandardMaterial3D.new()
		_hull_mat.vertex_color_use_as_albedo = true
		_hull_mat.vertex_color_is_srgb = true
		_hull_mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # kaksipuolinen: kiertosuunnalla ei ole väliä
		_hull_mat.roughness = 0.3
		_hull_mat.metallic_specular = 0.7
	return _hull_mat


## Runko SurfaceToolilla: poikkileikkaukset keulasta perään, kansi keulassa, peräpeili.
static func _hull_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var rings: Array = []  # jokainen: Array[[Vector3, Color]] vasen laita -> köli -> oikea laita
	for i in n + 1:
		var t := float(i) / n
		var z := -L * 0.5 + L * t
		var half := _ring(t)
		var full: Array = []
		for p in half:
			full.append([Vector3(-p[0].x, p[0].y, z), p[1]])
		for j in range(half.size() - 2, -1, -1):
			full.append([Vector3(half[j][0].x, half[j][0].y, z), half[j][1]])
		rings.append(full)
	for i in n:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for j in a.size() - 1:
			_quad(st, a[j], a[j + 1], b[j + 1], b[j])
	# Kansi keulassa (laidasta laitaan), ohjaamon etuseinään asti.
	var deck_to := 5
	var deck_col := Color(0.86, 0.86, 0.82)
	for i in deck_to:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var al: Array = a[0]
		var ar: Array = a[a.size() - 1]
		var bl: Array = b[0]
		var br: Array = b[b.size() - 1]
		_quad(st, [al[0], deck_col], [ar[0], deck_col], [br[0], deck_col], [bl[0], deck_col])
	# Peräpeili: viuhka kölistä.
	var last: Array = rings[n]
	var keel_i: int = (last.size() - 1) / 2
	for j in last.size() - 1:
		_tri(st, last[j], last[j + 1], last[keel_i])
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	for p in [a, b, c]:
		st.set_color(p[1])
		st.add_vertex(p[0])


static func _quad(st: SurfaceTool, a: Array, b: Array, c: Array, d: Array) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


## Rakentaa veneen parentin alle. Palauttaa {prop, motor, spray_l, spray_r, wake, driver, wheel, grips}.
## with_driver: kuski rattiin (ajossa ja parkissa pelaajaa ei ole).
static func build(parent: Node3D, with_driver := false) -> Dictionary:
	var grey := Color(0.3, 0.32, 0.35)
	var black := Color(0.08, 0.08, 0.1)
	var seat_c := Color(0.12, 0.12, 0.16)
	var hull := MeshInstance3D.new()
	hull.mesh = _hull_mesh()
	hull.material_override = _hull_material()
	parent.add_child(hull)
	# Ääriviivat: tumma hankauslista laidan päälle ja vaalea vesirajaviiva.
	for s: float in [-1.0, 1.0]:
		B.mesh(parent, B.boxm(Vector3(0.07, 0.07, L * 0.62)), Vector3(s * (W * 0.5 - 0.02), FREEBOARD + 0.03, L * 0.19), black)
		B.mesh(parent, B.boxm(Vector3(0.04, 0.05, L * 0.55)), Vector3(s * (W * 0.5 * 0.93), 0.02, L * 0.12), Color(0.95, 0.95, 0.95))
	# Ohjaamon lattia ja sisäsivut.
	B.mesh(parent, B.boxm(Vector3(W * 0.78, 0.05, L * 0.52)), Vector3(0, 0.16, L * 0.2), Color(0.55, 0.57, 0.6))
	for s: float in [-1.0, 1.0]:
		B.mesh(parent, B.boxm(Vector3(0.05, 0.5, L * 0.5)), Vector3(s * (W * 0.5 - 0.1), 0.45, L * 0.22), Color(0.9, 0.9, 0.86))
	B.mesh(parent, B.boxm(Vector3(W - 0.2, 0.55, 0.05)), Vector3(0, 0.45, L * 0.5 - 0.06), Color(0.9, 0.9, 0.86))  # peräpeilin sisäpuoli
	# Konsoli keskellä edessä ja tuulilasi.
	var cz := -0.3
	B.mesh(parent, B.boxm(Vector3(1.5, 0.55, 0.7)), Vector3(0, 0.85, cz), Color(0.9, 0.9, 0.86))
	B.mesh(parent, B.boxm(Vector3(1.5, 0.08, 0.72)), Vector3(0, 1.15, cz), grey)
	B.mesh(parent, B.boxm(Vector3(1.0, 0.04, 0.3)), Vector3(0, 1.0, cz + 0.28), Color(0.1, 0.12, 0.15), Vector3(-30, 0, 0))  # mittaristo
	var glass := B.mesh(parent, B.boxm(Vector3(1.9, 0.5, 0.04)), Vector3(0, 1.42, cz - 0.2), Color(0.6, 0.8, 0.9, 0.35), Vector3(-22, 0, 0))
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.65, 0.85, 0.95, 0.35)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.05
	glass.material_override = gm
	for s: float in [-1.0, 1.0]:
		B.mesh(parent, B.boxm(Vector3(0.05, 0.55, 0.05)), Vector3(s * 0.95, 1.4, cz - 0.2), grey, Vector3(-22, 0, 0))  # kehys
	B.mesh(parent, B.boxm(Vector3(1.95, 0.05, 0.05)), Vector3(0, 1.67, cz - 0.28), grey, Vector3(-22, 0, 0))
	# Ratti (kiertyy ohjauksen mukana) konsolin takasivulla.
	var wheel_pivot := Node3D.new()
	wheel_pivot.position = Vector3(0.0, 1.12, cz + 0.4)
	wheel_pivot.rotation_degrees = Vector3(-55, 0, 0)
	parent.add_child(wheel_pivot)
	var wheel := Node3D.new()
	wheel_pivot.add_child(wheel)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.17
	tm.outer_radius = 0.21
	B.mesh(wheel, tm, Vector3.ZERO, black, Vector3(90, 0, 0))
	for a in [0.0, 120.0, 240.0]:
		var spoke := Node3D.new()
		spoke.rotation_degrees = Vector3(0, a, 0)
		wheel.add_child(spoke)
		B.mesh(spoke, B.boxm(Vector3(0.36, 0.02, 0.025)), Vector3.ZERO, Color(0.7, 0.7, 0.74))
	# Istuimet: kuskin ja kaverin penkki jalustalla sekä takapenkki.
	for s: float in [-1.0, 1.0]:
		var sx := s * 0.45
		B.mesh(parent, B.boxm(Vector3(0.14, SEAT_TOP - 0.15, 0.14)), Vector3(sx, 0.15 + (SEAT_TOP - 0.15) * 0.5, SEAT_Z), grey)
		B.mesh(parent, B.boxm(Vector3(0.62, 0.12, 0.55)), Vector3(sx, SEAT_TOP - 0.06, SEAT_Z), seat_c)
		B.mesh(parent, B.boxm(Vector3(0.62, 0.55, 0.1)), Vector3(sx, SEAT_TOP + 0.3, SEAT_Z + 0.3), seat_c, Vector3(-8, 0, 0))
		B.mesh(parent, B.boxm(Vector3(0.64, 0.05, 0.56)), Vector3(sx, SEAT_TOP - 0.01, SEAT_Z), Color(0.7, 0.1, 0.1))  # punainen reunaommel
	B.mesh(parent, B.boxm(Vector3(W - 0.5, 0.42, 0.5)), Vector3(0, 0.4, L * 0.5 - 0.55), seat_c)  # takapenkki
	B.mesh(parent, B.boxm(Vector3(W - 0.5, 0.08, 0.52)), Vector3(0, 0.63, L * 0.5 - 0.55), Color(0.7, 0.1, 0.1))
	# Keulapollari, köysi ja etulyhty.
	B.mesh(parent, B.cyl(0.05, 0.06, 0.18, 8), Vector3(0, _bow_deck_y(0.15) + 0.09, -L * 0.5 + 0.7), Color(0.75, 0.75, 0.78))
	B.mesh(parent, B.sphere(0.06, 8), Vector3(0, FREEBOARD + 0.62, L * 0.5 - 0.15), Color(0.95, 0.95, 0.8))
	B.mesh(parent, B.cyl(0.015, 0.015, 0.5, 6), Vector3(0, FREEBOARD + 0.35, L * 0.5 - 0.15), grey)
	# Perämoottori peräpeilin yläreunaan.
	var mz := L * 0.5 + 0.22
	var motor := Node3D.new()
	motor.position = Vector3(0, TRANSOM_H, mz)
	parent.add_child(motor)
	B.mesh(motor, B.boxm(Vector3(0.7, 0.08, 0.3)), Vector3(0, -0.08, -0.2), grey)  # kiinnityslevy
	B.mesh(motor, B.boxm(Vector3(0.62, 0.8, 0.62)), Vector3(0, 0.38, 0), black)  # kopa
	B.mesh(motor, B.boxm(Vector3(0.5, 0.14, 0.5)), Vector3(0, 0.83, 0), Color(0.14, 0.14, 0.17))  # kansi
	B.mesh(motor, B.boxm(Vector3(0.66, 0.04, 0.66)), Vector3(0, 0.0, 0), Color(0.75, 0.75, 0.78))  # kiilto
	B.mesh(motor, B.boxm(Vector3(0.48, 0.22, 0.05)), Vector3(0, 0.45, 0.325), Color(0.85, 0.1, 0.1))  # kiilloraita
	B.mesh(motor, B.boxm(Vector3(0.4, TRANSOM_H + 0.85, 0.38)), Vector3(0, -(TRANSOM_H + 0.85) * 0.5 - 0.0, 0.0), Color(0.12, 0.12, 0.15))  # jalka
	B.mesh(motor, B.boxm(Vector3(0.56, 0.05, 0.55)), Vector3(0, -TRANSOM_H * 0.5 - 0.15, 0.0), Color(0.15, 0.15, 0.18))  # vaahtolevy
	for s: float in [-1.0, 1.0]:
		var decal := B.sign_plate(motor, "300", Color(0.9, 0.1, 0.1), Color.WHITE, 0.2, 40, Color.WHITE)
		decal.position = Vector3(s * 0.32, 0.45, 0.0)
		decal.rotation.y = s * PI * 0.5
		decal.scale = Vector3.ONE * 0.8
	# Potkuri kääntyy omassa nivelessään jalan perässä.
	var prop := Node3D.new()
	prop.position = Vector3(0, -TRANSOM_H - 0.7, 0.3)
	motor.add_child(prop)
	B.mesh(prop, B.sphere(0.1, 8), Vector3.ZERO, Color(0.55, 0.55, 0.6))
	for a in [0.0, 120.0, 240.0]:
		var blade := Node3D.new()
		blade.rotation_degrees = Vector3(0, 0, a)
		prop.add_child(blade)
		B.mesh(blade, B.boxm(Vector3(0.07, 0.34, 0.03)), Vector3(0, 0.2, 0), Color(0.78, 0.7, 0.4), Vector3(0, 0, 0))
	# Kuohu perän takana ja roiskeet keulan sivuilla.
	var wake := CPUParticles3D.new()
	wake.position = Vector3(0, 0.05, L * 0.5 + 0.7)
	wake.amount = 90
	wake.lifetime = 2.6
	wake.local_coords = false
	wake.emitting = false
	wake.direction = Vector3(0, 0.15, 1)
	wake.spread = 28.0
	wake.initial_velocity_min = 0.8
	wake.initial_velocity_max = 2.4
	wake.gravity = Vector3(0, -0.6, 0)
	wake.scale_amount_min = 0.8
	wake.scale_amount_max = 2.2
	wake.mesh = _foam_mesh(0.28, Color(0.95, 0.98, 1.0, 0.55))
	parent.add_child(wake)
	var sp: Array[CPUParticles3D] = []
	for s: float in [-1.0, 1.0]:
		var p := CPUParticles3D.new()
		p.position = Vector3(s * 0.35, 0.3, -L * 0.5 + 1.2)
		p.amount = 36
		p.lifetime = 0.7
		p.local_coords = false
		p.emitting = false
		p.direction = Vector3(s * 1.0, 1.1, 0.1)
		p.spread = 22.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 4.2
		p.gravity = Vector3(0, -9.0, 0)
		p.mesh = _foam_mesh(0.07, Color(0.92, 0.97, 1.0, 0.85))
		parent.add_child(p)
		sp.append(p)
	var out := {"prop": prop, "motor": motor, "spray_l": sp[0], "spray_r": sp[1], "wake": wake,
		"driver": null, "wheel": wheel, "grips": [Vector3(-0.2, 1.1, cz + 0.4), Vector3(0.2, 1.1, cz + 0.4)]}
	if with_driver:
		var d := Looks.make(parent, Looks.player())
		Looks.add_cap(d)
		d.play("Sitting_Idle", 0.0)
		d.position = Vector3(0.45, SEAT_TOP - 0.1, SEAT_Z)
		d.rotation.y = 0.0  # kasvot keulaan päin (kuten fish_game.gd:n soutaja)
		out["driver"] = d
	return out


static func _foam_mesh(r: float, c: Color) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = B.unshaded(c)
	return m


## Keulakannen korkeus tietyllä etäisyydellä keulasta (peräkkäisten renkaiden kansitaso).
static func _bow_deck_y(dist: float) -> float:
	return FREEBOARD + 0.4 * pow(1.0 - dist / L, 2.2)


# ---------- Ajo ----------

func _wy(x: float, z: float) -> float:
	return vaala.water_y(x, z)


func _fwd() -> Vector3:
	return Vector3(-sin(_yaw), 0, -cos(_yaw))


## Törmäystarkistus viidellä pisteellä: keula, perä ja kyljet.
func _free(p: Vector3, yaw: float) -> bool:
	var f := Vector3(-sin(yaw), 0, -cos(yaw))
	var s := Vector3(f.z, 0, -f.x)
	for q in [f * (L * 0.5), -f * (L * 0.5), s * (W * 0.5), -s * (W * 0.5), Vector3.ZERO]:
		if not vaala.boat_free(p.x + q.x, p.z + q.z):
			return false
	return true


func _say(text: String, t := 2.5) -> void:
	_msg.text = text
	_msg_t = t


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 15
	add_child(_ui)
	_hint = preload("res://scripts/hint_bar.gd").new()
	_hint.compact = true
	_hint.centered = true
	_ui.add_child(_hint)
	_msg = _mk_label(Vector2(0, 90), 32, HORIZONTAL_ALIGNMENT_CENTER)
	_spd_label = _mk_label(Vector2(0, 640), 36, HORIZONTAL_ALIGNMENT_RIGHT)
	_spd_label.position.x = 440.0  # oikea alakulma, leveys 800


func _mk_label(pos: Vector2, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(1280 if align == HORIZONTAL_ALIGNMENT_CENTER else 800, 60)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	_ui.add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	_msg_t -= delta
	_bump_cd -= delta
	if _msg_t <= 0.0:
		_msg.text = ""
	if _state == "drive":
		_drive(delta)
	_apply_pose(delta)
	_update_fx(delta)


func _drive(delta: float) -> void:
	if _slide_t < 1.4:
		# Paikasta liu'utaan sivuun avoveteen (T-pää ja sormilaituri rajaavat taskun), sen jälkeen ajo alkaa.
		_slide_t += delta
		_pos += (-start.basis.x * 3.4 + _fwd() * 1.8) / 1.4 * delta
		_pos.y = _wy(_pos.x, _pos.z)
		_hist.clear()
		_hist.append([_pos, _yaw])
		return
	var fwd_in := Input.get_axis("back", "forward")
	var turn_in := Input.get_axis("right", "left")
	var wob := sin(_t * 0.8) * 0.4 * drunk
	var target := fwd_in * (MAX_SPEED if fwd_in > 0.0 else REVERSE_SPEED)
	var rate := ACCEL if absf(fwd_in) > 0.1 else DRAG
	if fwd_in > 0.1 and _speed > MAX_SPEED * 0.75:
		rate = ACCEL * 0.5  # huippuvauhdissa kiihtyvyys hiipuu
	var prev := _speed
	_speed = move_toward(_speed, target, rate * delta)
	var accel := (_speed - prev) / maxf(delta, 0.0001)
	# Ohjaus vähenee vauhdin kasvaessa vain hiukan, mutta paikallaan ei käännytä.
	var steer_k := clampf(absf(_speed) / 3.0, 0.0, 1.0) * (1.0 - 0.35 * clampf(_speed / MAX_SPEED, 0.0, 1.0))
	var sgn := 1.0 if _speed >= -0.1 else -1.0
	_turn_v = lerpf(_turn_v, (turn_in + wob) * TURN * steer_k * sgn, 1.0 - exp(-3.5 * delta))
	var new_yaw := _yaw + _turn_v * delta
	var f := Vector3(-sin(new_yaw), 0, -cos(new_yaw))
	var new_pos := _pos + f * _speed * delta
	if _free(new_pos, new_yaw):
		_yaw = new_yaw
		_pos = new_pos
		_blocked_t = maxf(_blocked_t - delta * 0.5, 0.0)  # pomppiminen rantaa vasten ei nollaa jumia
		_hist_t -= delta
		if _hist_t <= 0.0:
			_hist_t = 0.4
			_hist.append([_pos, _yaw])
			if _hist.size() > 12:
				_hist.pop_front()
	else:
		if absf(_speed) > 1.5 and _bump_cd <= 0.0:
			_bump_cd = 0.6
			_shake = clampf(absf(_speed) / 10.0, 0.2, 1.0)
			Sfx.play("body_fall", -6.0, 0.8)
			var far := Vector2(_pos.x - start.origin.x, _pos.z - start.origin.z).length() > 300.0
			_say("Oulujärvi jatkuu horisonttiin." if far and absf(_speed) > 6.0 else "Kolahti rantaan.", 1.6)
		_speed = -_speed * 0.25
		_turn_v = 0.0
		_blocked_t += delta
		if _blocked_t > 1.5 and _hist.size() > 0:  # jumi: takaisin vanhaan vapaaseen asentoon
			var h: Array = _hist[0]
			_pos = h[0]
			_yaw = h[1]
			_speed = 0.0
			_turn_v = 0.0
			_blocked_t = 0.0
			_hist.clear()
			_hist.append(h)
	_pos.y = _wy(_pos.x, _pos.z)
	# Pitch: kiihdytyksessä keula nousee, liukutasolle päästessä laskee.
	var frac := clampf(absf(_speed) / MAX_SPEED, 0.0, 1.0)
	var plane := clampf((absf(_speed) - 4.0) / 9.0, 0.0, 1.0)
	var tp := clampf(accel * 0.012, -0.06, 0.12) + sin(plane * PI) * 0.1 + frac * 0.03
	_pitch = lerpf(_pitch, tp, 1.0 - exp(-4.0 * delta))
	var troll := clampf(_turn_v * _speed * 0.045, -0.35, 0.35) + sin(_t * 1.3) * 0.015 * drunk
	_roll = lerpf(_roll, troll, 1.0 - exp(-4.0 * delta))
	_engine.pitch_scale = lerpf(_engine.pitch_scale, 0.5 + 0.9 * frac + 0.15 * absf(fwd_in), 1.0 - exp(-5.0 * delta))
	_spd_label.text = "%d km/h" % roundi(absf(_speed) * 3.6)
	var near := _near_dock()
	if near and absf(_speed) < 1.5:
		_hint.set_text("%s kaasu   %s ohjaus   %s nouse laiturille" % [
			Settings.pair("forward", "back"), Settings.pair("left", "right"), Settings.cap("interact")])
	else:
		_hint.set_text("%s kaasu   %s ohjaus   %s laiturille (aja laiturin viereen)" % [
			Settings.pair("forward", "back"), Settings.pair("left", "right"), Settings.cap("interact")])
	if Input.is_action_just_pressed("interact") and _t > 0.6:
		if near and absf(_speed) < 1.5:
			_dock_out()
		else:
			_say("Aja laiturin viereen ja hidasta.", 1.8)


func _near_dock() -> bool:
	return Vector2(_pos.x - start.origin.x, _pos.z - start.origin.z).length() < 6.0


## Vene liukuu parkkiin ja ajo päättyy.
func _dock_out() -> void:
	_state = "dock"
	_speed = 0.0
	_turn_v = 0.0
	var from_pos := _pos
	var from_yaw := _yaw
	var to_yaw := start.basis.get_euler().y
	var to_pos := start.origin
	to_pos.y = _wy(to_pos.x, to_pos.z)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		_pos = from_pos.lerp(to_pos, k)
		_yaw = lerp_angle(from_yaw, to_yaw, k), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_engine.stop()
	finished.emit(start.origin)


func _apply_pose(delta: float) -> void:
	var bob := sin(_t * 1.6) * 0.025 * (1.0 - clampf(_speed / 8.0, 0.0, 0.8))
	var lift := clampf((absf(_speed) - 4.0) / 9.0, 0.0, 1.0) * 0.18
	_boat.position = _pos + Vector3(0, 0.05 + bob + lift, 0)
	_boat.rotation = Vector3(_pitch + sin(_t * 1.1) * 0.01, _yaw, _roll + sin(_t * 0.9) * 0.012)
	var prop: Node3D = _parts["prop"]
	prop.rotation.z += (6.0 + absf(_speed) * 3.0) * delta * 3.0
	var wheel: Node3D = _parts["wheel"]
	wheel.rotation.y = lerpf(wheel.rotation.y, _turn_v * 2.5, 1.0 - exp(-8.0 * maxf(delta, 0.001)))
	var d: Node3D = _parts["driver"]
	if d != null:
		var inv := d.transform.affine_inverse()
		var g: Array = _parts["grips"]
		var gl: Vector3 = g[0] + Vector3(0, 0.0, 0)
		var gr: Vector3 = g[1]
		d.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", inv * gl, inv * Vector3(-0.6, 0.9, 0.3))
		d.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * gr, inv * Vector3(0.6, 0.9, 0.3))
	# Kamera veneen takaa, kauempana vauhdissa; tärähdys törmäyksestä.
	var want := _cam_target()
	_cam.position = _cam.position.lerp(want, 1.0 - exp(-4.0 * maxf(delta, 0.001))) if _t > 0.1 else want
	_shake = maxf(0.0, _shake - delta * 2.5)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.25
	_cam.position += sh
	_cam.fov = 66.0 + 12.0 * clampf(absf(_speed) / MAX_SPEED, 0.0, 1.0)
	var fwd := _fwd()
	_cam.look_at(to_global(_pos + fwd * 6.0 + Vector3(0, 0.8, 0)), Vector3.UP)


func _cam_target() -> Vector3:
	var back := -_fwd()
	var dist := 9.0 + 2.0 * clampf(absf(_speed) / MAX_SPEED, 0.0, 1.0)
	return _pos + back * dist + Vector3(0, 3.8, 0)


func _update_fx(delta: float) -> void:
	var sp := absf(_speed)
	var wake: CPUParticles3D = _parts["wake"]
	wake.emitting = sp > 1.0
	wake.initial_velocity_max = 1.0 + sp * 0.2
	wake.amount = 90
	for k in ["spray_l", "spray_r"]:
		var p: CPUParticles3D = _parts[k]
		p.emitting = sp > 5.0
		p.initial_velocity_min = 1.0 + sp * 0.12
		p.initial_velocity_max = 2.0 + sp * 0.2
	_splash_t -= delta
	if sp > 6.0 and _splash_t <= 0.0:
		_splash_t = lerpf(0.9, 0.35, clampf(sp / MAX_SPEED, 0.0, 1.0))
		Sfx.play("water", -14.0, randf_range(1.0, 1.4))
