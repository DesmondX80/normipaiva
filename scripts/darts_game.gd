extends Node3D
## Tikanheitto mökin pihalla, minipeli: heittoviivalta katsotaan männyn tikkataulua, tähdätään hiirellä
## (kosketuksella vetämällä) ja heitetään vasemmalla napilla / E. Käsi huojuu, humalassa enemmän; oikea nappi
## pohjassa (kosketuksella Keskity) rauhoittaa hetkeksi. Kolme kierrosta, kolme tikkaa kierroksella; lopuksi
## verrataan Santun tulokseen. Taulu on oikean tikkataulun mittainen ja pisteytys kuten oikeassa (tuplat, triplat,
## bull). F lopettaa. mokki.gd:n lapsi identiteettimuunnoksella: koordinaatit ovat mökin paikallisia.
## finished(total, santtu): pelaajan ja Santun pisteet (total < 0 = lopetettiin kesken).

signal finished(total: int, santtu: int)

const B := preload("res://scripts/build.gd")

## Sektorit ylhäältä myötäpäivään.
const ORDER := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
## Säteet metreinä (oikea tikkataulu): bull, ulkobull, triplan sisä/ulko, tuplan sisä/ulko, taulun reuna.
const R_BULL := 0.00635
const R_OUTER_BULL := 0.0159
const R_TRIPLE := [0.099, 0.107]
const R_DOUBLE := [0.162, 0.170]
const R_BOARD := 0.225
const THROW_DIST := 2.37
const EYE_UP := 0.2  # silmät taulun keskustan yläpuolella
const DARTS := 3
const ROUNDS := 3
const SENS := 0.0009
const FLIGHT := 0.28

## Taulun keskipiste ja kehys mökin koordinaateissa (mokki.gd asettaa ennen add_childia).
var board_center := Vector3.ZERO
var drunk := 0.0  # 0..1, humalatila lisää huojuntaa ja hajontaa

var _aim := Vector2.ZERO  # tähtäyspiste taulun tasossa (x oikealle, y ylös)
var _t := 0.0
var _focus := 0.0  # 0..1 keskittyminen (oikea nappi), kestää hetken
var _focus_left := 2.5
var _round := 0
var _dart := 0
var _rounds: Array = []  # kierrosten pisteet
var _thrown: Array = []  # taululla olevat tikat
var _flying: Dictionary = {}
var _phase := "aim"  # aim | fly | pause | end
var _pause_t := 0.0
var _santtu := 0
var _saved_cam := []

var _cam: Camera3D
var _cross: Control
var _layer: CanvasLayer
var _title: Label
var _score_l: Label
var _sub: Label
var _sub_t := 0.0


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.fov = 26.0  # taulu isona, kuin katse keskittyisi siihen
	add_child(_cam)
	var eye := board_center + Vector3(0, EYE_UP, -THROW_DIST)
	_cam.transform = Transform3D(Basis.looking_at(board_center + Vector3(0, 0.03, 0) - eye, Vector3.UP), eye)
	_cam.current = true
	_build_hud()
	_saved_cam = [CamCtl.yaw, CamCtl.pitch]
	CamCtl.need_mouse = true
	if Touch.active:
		Touch.look.connect(_move_aim)
		Touch.set_extra([[-1, "Keskity"]])
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_santtu = _simulate_santtu()
	_say("Tikanheitto: kolme kierrosta, kolme tikkaa. Santtu heitti äsken, voita se!", 3.0)


func _exit_tree() -> void:
	CamCtl.need_mouse = false
	if Touch.active:
		Touch.look.disconnect(_move_aim)
		Touch.set_extra([])


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or _phase == "end" or Touch.active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_move_aim(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_throw()


func _move_aim(rel: Vector2) -> void:
	if get_tree().paused or _phase == "end":
		return
	var sens: float = SENS * Settings.get_v("mouse_sens")
	var inv := -1.0 if Settings.get_v("invert_y") else 1.0
	_aim += Vector2(rel.x, -rel.y * inv) * sens
	_aim = _aim.limit_length(R_BOARD + 0.1)


func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("mount") and _phase != "end":
		_end(true)
		return
	if Input.is_action_just_pressed("interact") and _phase == "aim":
		_throw()
	# Keskittyminen: oikea nappi pohjassa rauhoittaa, mutta vain hetken (sitten käsi alkaa täristä).
	var hold: bool = (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Touch.aim) and _phase == "aim"
	if hold and _focus_left > 0.0:
		_focus = move_toward(_focus, 1.0, delta * 3.0)
		_focus_left -= delta
	else:
		_focus = move_toward(_focus, 0.0, delta * 4.0)
		if not hold:
			_focus_left = minf(2.5, _focus_left + delta * 0.8)
	match _phase:
		"fly":
			_update_flight(delta)
		"pause":
			_pause_t -= delta
			if _pause_t <= 0.0:
				_next_round()
	_update_hud(delta)


## Huojunta: hengitys ja käden vapina, humalassa moninkertainen, keskittyessä pieni.
func _sway() -> Vector2:
	var amp := (0.012 + 0.05 * drunk) * lerpf(1.0, 0.3, _focus)
	var shake := 0.0 if _focus_left > 0.0 else 0.006
	return Vector2(sin(_t * 1.3) + 0.5 * sin(_t * 3.1 + 1.0), cos(_t * 1.1) + 0.5 * sin(_t * 2.7)) * amp \
		+ Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake


func _board_point(p: Vector2) -> Vector3:
	return board_center + Vector3(-p.x, p.y, 0)  # taulu katsoo -Z:aan: pelaajan oikea on mökin -X


func _throw() -> void:
	if _phase != "aim" or get_tree().paused:
		return
	var spread := 0.011 + 0.03 * drunk
	var hit := _aim + _sway() + Vector2(randfn(0.0, spread), randfn(0.0, spread))
	var dart := _dart_mesh()
	add_child(dart)
	_flying = {"node": dart, "from": _cam.position + Vector3(0.12, -0.15, 0.3), "hit": hit, "t": 0.0}
	_phase = "fly"
	Sfx.play("whoosh", -6.0, 1.4)


func _update_flight(delta: float) -> void:
	_flying.t += delta / FLIGHT
	var to := _board_point(_flying.hit) + Vector3(0, 0, -0.11)  # kärjen pää (-0,10 m) uppoaa sentin tauluun
	var k: float = minf(_flying.t, 1.0)
	var p: Vector3 = _flying.from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.08, 0)
	var node: Node3D = _flying.node
	node.transform = Transform3D(Basis.looking_at(Vector3(0, 0, 1), Vector3.UP), p)  # kärki (-Z malli) tauluun
	if _flying.t < 1.0:
		return
	var res := score(_flying.hit)
	_thrown.append(node)
	if res[0] == 0:
		node.queue_free()  # ohi taulun: tikka putoaa nurmikolle
		_thrown.erase(node)
	if _rounds.size() <= _round:
		_rounds.append(0)
	_rounds[_round] += res[0]
	Sfx.play("step_wood" if res[0] > 0 else "step_grass", -4.0, 1.6)
	_say(res[1], 1.6)
	_dart += 1
	if _dart >= DARTS:
		_phase = "pause"
		_pause_t = 1.6
	else:
		_phase = "aim"


func _next_round() -> void:
	for d in _thrown:
		d.queue_free()
	_thrown.clear()
	_dart = 0
	_round += 1
	if _round >= ROUNDS:
		_end(false)
	else:
		_phase = "aim"
		_say("Kierros %d." % (_round + 1), 1.5)


## Pisteet ja selite osumakohdasta taulun tasossa (metreinä, x oikealle, y ylös).
static func score(p: Vector2) -> Array:
	var r := p.length()
	if r <= R_BULL:
		return [50, "BULLSEYE! 50"]
	if r <= R_OUTER_BULL:
		return [25, "Bull 25"]
	if r > R_DOUBLE[1]:
		return [0, "Ohi taulun." if r > R_BOARD else "Reunaan, ei pisteitä."]
	var a := fposmod(90.0 - rad_to_deg(atan2(p.y, p.x)) + 9.0, 360.0)
	var n: int = ORDER[int(a / 18.0) % 20]
	if r > R_TRIPLE[0] and r <= R_TRIPLE[1]:
		return [n * 3, "Tripla %d = %d" % [n, n * 3]]
	if r > R_DOUBLE[0]:
		return [n * 2, "Tupla %d = %d" % [n, n * 2]]
	return [n, "%d" % n]


## Santtu heittää triplakahtakymppiä kohti vakaalla kädellä (tulos arvotaan ennen omaa vuoroa).
static func _simulate_santtu() -> int:
	var total := 0
	for i in DARTS * ROUNDS:
		var p := Vector2(0, 0.103) + Vector2(randfn(0.0, 0.035), randfn(0.0, 0.035))
		total += score(p)[0]
	return total


func _end(quit: bool) -> void:
	_phase = "end"
	var total := 0
	for s in _rounds:
		total += s
	if quit:
		_say("Lopetit tikanheiton.", 1.5)
	elif total > _santtu:
		_say("Yhteensä %d, Santtu %d. Voitit Santun!" % [total, _santtu], 3.0)
	elif total == _santtu:
		_say("Yhteensä %d, Santtu %d. Tasapeli!" % [total, _santtu], 3.0)
	else:
		_say("Yhteensä %d, Santtu %d. Santtu vei tällä kertaa." % [total, _santtu], 3.0)
	get_tree().create_timer(2.8 if not quit else 0.8).timeout.connect(func() -> void:
		CamCtl.yaw = _saved_cam[0]
		CamCtl.pitch = _saved_cam[1]
		finished.emit(-1 if quit else total, _santtu)
		queue_free())


func _dart_mesh() -> Node3D:
	# Tikka: kärki +Z (look_at osoittaa -Z:n kohteeseen, joten malli rakennetaan -Z:aan).
	# Pelin mittakaavassa noin kaksinkertainen, jotta tikat erottuvat taulusta heittoviivalta.
	var d := Node3D.new()
	var s := 2.0
	B.mesh(d, B.cyl(0.0015 * s, 0.0005 * s, 0.03 * s, 6), Vector3(0, 0, -0.07 * s + 0.07), Color(0.8, 0.8, 0.82), Vector3(90, 0, 0))
	B.mesh(d, B.cyl(0.004 * s, 0.004 * s, 0.05 * s, 8), Vector3(0, 0, -0.035 * s + 0.07), Color(0.75, 0.62, 0.2), Vector3(90, 0, 0))
	B.mesh(d, B.cyl(0.0015 * s, 0.0015 * s, 0.04 * s, 6), Vector3(0, 0, 0.01 * s + 0.07), Color(0.1, 0.1, 0.1), Vector3(90, 0, 0))
	for k in 2:
		var fl := Vector3(0.024 * s if k == 0 else 0.002, 0.002 if k == 0 else 0.024 * s, 0.03 * s)
		B.mesh(d, B.boxm(fl), Vector3(0, 0, 0.03 * s + 0.07), Color(1.0, 0.85, 0.1))
	return d


## Oikean näköinen tikkataulu (sektorit, tupla- ja triplarenkaat, bull, numerot). Etupinta -Z:aan, x = taulun
## vasen (katsojan oikea on -X), y ylös. Käytetään sekä pihan tauluna (mokki.gd) että minipelissä.
static func make_board(parent: Node3D) -> Node3D:
	var board := Node3D.new()
	parent.add_child(board)
	var cols := {"black": Color(0.08, 0.08, 0.08), "cream": Color(0.93, 0.88, 0.72), "red": Color(0.78, 0.08, 0.08),
		"green": Color(0.05, 0.45, 0.2)}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, -1))
	var ring := func(r0: float, r1: float, a0: float, a1: float, col: Color, z: float) -> void:
		st.set_color(col)
		var seg := 4
		for k in seg:
			var t0 := deg_to_rad(lerpf(a0, a1, float(k) / seg))
			var t1 := deg_to_rad(lerpf(a0, a1, float(k + 1) / seg))
			var p00 := Vector3(-cos(t0) * r0, sin(t0) * r0, z)
			var p01 := Vector3(-cos(t0) * r1, sin(t0) * r1, z)
			var p10 := Vector3(-cos(t1) * r0, sin(t1) * r0, z)
			var p11 := Vector3(-cos(t1) * r1, sin(t1) * r1, z)
			for v in [p00, p11, p01, p00, p10, p11]:
				st.add_vertex(v)
	# Musta numerorengas ja reunus.
	for i in 40:
		ring.call(R_DOUBLE[1], R_BOARD, i * 9.0, (i + 1) * 9.0, cols.black, 0.0)
	for i in 20:
		# Sektori i on keskeltä kulmassa 90° - 18° * i (myötäpäivään ylhäältä).
		var ac := 90.0 - 18.0 * i
		var a0 := ac - 9.0
		var a1 := ac + 9.0
		var dark := i % 2 == 0
		ring.call(R_OUTER_BULL, R_TRIPLE[0], a0, a1, cols.black if dark else cols.cream, -0.001)
		ring.call(R_TRIPLE[0], R_TRIPLE[1], a0, a1, cols.red if dark else cols.green, -0.001)
		ring.call(R_TRIPLE[1], R_DOUBLE[0], a0, a1, cols.black if dark else cols.cream, -0.001)
		ring.call(R_DOUBLE[0], R_DOUBLE[1], a0, a1, cols.red if dark else cols.green, -0.001)
	for i in 20:
		ring.call(R_BULL, R_OUTER_BULL, i * 18.0, (i + 1) * 18.0, cols.green, -0.0012)
		ring.call(0.0, R_BULL, i * 18.0, (i + 1) * 18.0, cols.red, -0.0014)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mi.material_override = mat
	board.add_child(mi)
	# Taulun runko ja numerot.
	B.mesh(board, B.cyl(R_BOARD + 0.01, R_BOARD + 0.01, 0.04, 32), Vector3(0, 0, 0.021), Color(0.12, 0.12, 0.12),
		Vector3(90, 0, 0))
	for i in 20:
		var ac := deg_to_rad(90.0 - 18.0 * i)
		var lab := Label3D.new()
		lab.text = str(ORDER[i])
		lab.font_size = 48
		lab.pixel_size = 0.0006
		lab.modulate = Color(0.95, 0.95, 0.95)
		lab.outline_size = 0
		lab.position = Vector3(-cos(ac) * 0.197, sin(ac) * 0.197, -0.002)
		lab.rotation.y = PI  # teksti -Z:n suuntaan
		board.add_child(lab)
	return board


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_cross = Control.new()
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_cross)
	for spec in [[Vector2(18, 2), Vector2(-13, 0)], [Vector2(18, 2), Vector2(13, 0)], [Vector2(2, 18), Vector2(0, -13)],
			[Vector2(2, 18), Vector2(0, 13)], [Vector2(3, 3), Vector2.ZERO]]:
		var r := ColorRect.new()
		var sz: Vector2 = spec[0]
		var off: Vector2 = spec[1]
		r.color = Color(1, 0.25, 0.2, 0.95) if off == Vector2.ZERO else Color(1, 1, 1, 0.9)
		r.position = off - sz / 2.0
		r.size = sz
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cross.add_child(r)
	_title = _label(26, 0.0, 44, 84, HORIZONTAL_ALIGNMENT_CENTER)
	_score_l = _label(22, 0.0, 12, 120, HORIZONTAL_ALIGNMENT_LEFT)
	_sub = _label(30, 1.0, -170, -120, HORIZONTAL_ALIGNMENT_CENTER)
	_sub.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	var help := _label(16, 1.0, -36, -12, HORIZONTAL_ALIGNMENT_CENTER)
	help.text = "Hiiri tähtää · vasen nappi / E heittää · oikea nappi pohjassa: keskity (hetken) · F lopeta"


func _label(size: int, anchor_y: float, top: float, bottom: float, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.anchor_right = 1.0
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_left = 24
	l.offset_right = -24
	l.offset_top = top
	l.offset_bottom = bottom
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(l)
	return l


func _say(text: String, seconds: float) -> void:
	_sub.text = text
	_sub_t = seconds


func _update_hud(delta: float) -> void:
	var pt := _board_point(_aim + _sway())
	_cross.visible = _phase == "aim"
	_cross.position = _cam.unproject_position(to_global(pt))
	var left := "➶ ".repeat(DARTS - _dart) if _phase == "aim" else ""
	_title.text = "TIKANHEITTO · kierros %d/%d   %s" % [mini(_round + 1, ROUNDS), ROUNDS, left]
	var lines := PackedStringArray()
	var total := 0
	for i in _rounds.size():
		lines.append("Kierros %d: %d" % [i + 1, _rounds[i]])
		total += _rounds[i]
	lines.append("Yhteensä: %d" % total)
	lines.append("Santtu: %d" % _santtu)
	_score_l.text = "\n".join(lines)
	if _sub_t > 0.0:
		_sub_t -= delta
		if _sub_t <= 0.0:
			_sub.text = ""
