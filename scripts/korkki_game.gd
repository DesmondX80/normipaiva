extends Node3D
## Korkkiläpsy (#290, pog-tyylinen) pelimaailmassa 3D:nä: Vaalan lavan pihalla teinien vieressä (main.gd
## _start_korkkilapsy lisää tämän vaala-solmun lapseksi ja asettaa paikan). Pino oikeita 3D-korkkeja asfaltilla nurin
## päin, vastassa teini Jere kyykyssä ja pelaajan oma hahmo pinon ääressä (Looks-hahmot). Kamera pinon yläviistossa.
## Tähtäys A/D tai hiiri, voima ajoituksella (hyppy / klikkaus): kääntyneet korkit lyöjälle, liian kova lyönti lennättää
## korkit asfaltille. Ruudun päällä vain voimamittari, tilanne ja näppäinhatut (hint_bar.gd, näppäimet asetuksista).
## Akselit: f = face (pihan ulos-suunta, pinosta kameraan päin), r = f:n oikea puoli kamerasta katsottuna.
## finished(won: Array, quit: bool) = pelaajan saamat korkit.

signal finished(won: Array, quit: bool)

const Korkit := preload("res://scripts/korkit.gd")
const Looks := preload("res://scripts/looks.gd")
const MG := preload("res://scripts/mg_draw.gd")
const CAP_R := 0.03  # korkin säde (m): pog-kiekon kokoinen, jotta logo erottuu kamerasta
const CAP_H := 0.008
const SWEET := 0.72
const TOO_HARD := 0.93
const JERE := {"shirt": Color(0.2, 0.55, 0.45), "pants": Color(0.2, 0.25, 0.42), "shoes": Color(0.92, 0.92, 0.92),
	"hair": "Hair_Buzzed", "hair_color": Color(0.85, 0.7, 0.35), "height": 1.62, "skin": Color(0.95, 0.77, 0.66), "belly": 0.0}

var stack: Array = []  # [{key, up}] (main.gd täyttää ennen lisäystä)
var drunk := 0.0
var face := Vector3(0, 0, 1)
var _caps: Array = []  # pinon korkit (sama järjestys kuin stack)
var _tex := {}
var _cam: Camera3D
var _prev_cam: Camera3D
var _jere: Node3D
var _me: Node3D
var _slammer: Node3D
var _hud: CanvasLayer
var _hud_c: Control
var _keys: Control
var _t := 0.0
var _pt := 0.0
var _turn := "me"
var _phase := "aim"
var _aim := 0.0
var _power := 0.0
var _pdir := 1.0
var _won_me: Array = []
var _won_teen: Array = []
var _flying: Array = []  # [node, from, to, t, puolikierrokset, alkukulma]
var _shake := 0.0
var _say := ""
var _say_t := 0.0
var _rounds := 0


func _f() -> Vector3:
	return Vector3(face.x, 0, face.z).normalized()


func _r() -> Vector3:
	return _f().cross(Vector3.UP).normalized() * -1.0


func _ready() -> void:
	add_to_group("esc_lopettaa")
	var f := _f()
	var r := _r()
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 60.0
	add_child(_cam)
	_cam.current = true
	# Jere kyykyssä pinon takana kasvot pinoon (Looks-hahmo katsoo oletuksena -Z:aan).
	_jere = Looks.make(self, JERE)
	_jere.position = -f * 0.95
	_jere.rotation.y = atan2(f.x, f.z) + PI
	_jere.play.call_deferred("Crouch_Idle", 0.0)
	# Pelaaja kyykyssä pinon edessä vasemmalla, kasvot pinoon.
	_me = Looks.make(self, Looks.PLAYER)
	_me.position = f * 0.15 - r * 1.0
	_me.rotation.y = atan2(-r.x, -r.z) + PI  # kasvot pinoon sivulta
	_me.play.call_deferred("Crouch_Idle", 0.0)
	for i in stack.size():
		var c := _make_cap(stack[i].key)
		c.position = Vector3(randf_range(-0.003, 0.003), CAP_H * (i + 0.5), randf_range(-0.003, 0.003))
		c.rotation = Vector3(PI, randf() * TAU, 0)  # nurin: logopuoli alas
		_caps.append(c)
	_slammer = _make_slammer()
	_frame_cam()
	_aim_cam()
	_build_hud()
	_say = "Jere: \"Panokset pinoon, nurin päin. Sää aloitat.\""
	_say_t = 3.0


var _eye := Vector3.ZERO  # kameran paikka ja katsepiste paikallisesti (_frame_cam laskee)
var _look := Vector3.ZERO


func _aim_cam() -> void:
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.006
	_cam.look_at_from_position(to_global(_eye) + sh, to_global(_look))


## Rajaus laskemalla, peli edellä: kokeillaan kameran korkeuksia, etäisyyksiä ja katsepisteitä ja valitaan se, jossa
## pino on ruudun keskellä hieman alempana (y 0,6) ja korkin halkaisija noin 90 px; hahmot saavat rajautua reunoilta
## (Jeren kädet ja polvet näkyvät pinon takana).
func _frame_cam() -> void:
	var f := _f()
	var size := Vector2(get_viewport().get_visible_rect().size)
	var pile := Vector3.UP * CAP_H * 3.0
	var edge := pile + _r() * CAP_R
	var best := INF
	for hi in 12:
		for di in 10:
			for li in 6:
				var eye := f * (0.12 + di * 0.05) + Vector3.UP * (0.2 + hi * 0.05)
				var look := -f * (li * 0.04)
				_cam.look_at_from_position(to_global(eye), to_global(look))
				if _cam.is_position_behind(to_global(pile)):
					continue
				var a := _cam.unproject_position(to_global(pile))
				var d := 2.0 * a.distance_to(_cam.unproject_position(to_global(edge)))
				var err := absf(a.y / size.y - 0.6) + absf(a.x / size.x - 0.5) * 0.5 + absf(d - 90.0) / 90.0
				# Kamera vinosti ylhäältä (ei suoraan alas): kulma 40–65 astetta.
				var tilt := rad_to_deg(atan2(eye.y, Vector2(eye.x, eye.z).length()))
				if tilt < 40.0 or tilt > 65.0:
					continue
				if err < best:
					best = err
					_eye = eye
					_look = look


## Korkki: rihlattu kylki (21 hammasta) ja kannet umpinaisena kappaleena. Kansikuva piirretään kerran SubViewportissa
## (logo, sävytys, kiilto; nurjalla puolella korkkitiiviste). Logopuoli on +Y.
func _make_cap(key: String) -> Node3D:
	var n := Node3D.new()
	n.set_meta("key", key)
	add_child(n)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 42
	for i in seg:
		var a0 := i * TAU / seg
		var a1 := (i + 1) * TAU / seg
		var r0 := CAP_R * (1.08 if i % 2 == 0 else 1.0)
		var r1 := CAP_R * (1.08 if (i + 1) % 2 == 0 else 1.0)
		var p0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r1, 0, sin(a1) * r1)
		var nrm := Vector3(cos((a0 + a1) / 2.0), 0, sin((a0 + a1) / 2.0))
		for v in [p0 - Vector3(0, CAP_H / 2, 0), p1 + Vector3(0, CAP_H / 2, 0), p0 + Vector3(0, CAP_H / 2, 0),
				p0 - Vector3(0, CAP_H / 2, 0), p1 - Vector3(0, CAP_H / 2, 0), p1 + Vector3(0, CAP_H / 2, 0)]:
			st.set_normal(nrm)
			st.add_vertex(v)
	var side := MeshInstance3D.new()
	side.mesh = st.commit()
	var sm := StandardMaterial3D.new()
	var br: Dictionary = Korkit.BRANDS.get(key.split(":")[0], {"vari": Color(0.95, 0.75, 0.2)})
	sm.albedo_color = (br.vari as Color).darkened(0.25)
	sm.metallic = 0.6
	sm.roughness = 0.35
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	side.material_override = sm
	n.add_child(side)
	for up in [true, false]:
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(CAP_R * 2.0, CAP_R * 2.0)
		q.mesh = pm
		q.position.y = CAP_H / 2.0 if up else -CAP_H / 2.0
		if not up:
			q.rotation.x = PI
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _face_tex(key, up)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.metallic = 0.35
		mat.roughness = 0.45
		q.material_override = mat
		n.add_child(q)
	return n


func _face_tex(key: String, up: bool) -> Texture2D:
	var id := "%s:%s" % [key, up]
	if _tex.has(id):
		return _tex[id]
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var c := Control.new()
	c.size = Vector2(128, 128)
	c.draw.connect(func() -> void: _draw_face(c, Vector2(64, 64), 60.0, key, up))
	vp.add_child(c)
	_tex[id] = vp.get_texture()
	return _tex[id]


func _draw_face(ci: CanvasItem, c: Vector2, r: float, key: String, up: bool) -> void:
	var p := key.split(":")
	var br: Dictionary = Korkit.BRANDS.get(p[0], {"nimi": "MM 95", "vari": Color(0.95, 0.75, 0.2)})
	var col: Color = br.vari if up else Color(0.72, 0.72, 0.7)
	ci.draw_circle(c, r, col.darkened(0.3))
	ci.draw_circle(c, r * 0.92, col)
	ci.draw_arc(c, r * 0.84, PI * 1.1, PI * 1.9, 16, col.lightened(0.45), r * 0.1, true)
	ci.draw_arc(c, r * 0.84, PI * 0.1, PI * 0.9, 16, col.darkened(0.3), r * 0.1, true)
	if not up:
		ci.draw_circle(c, r * 0.68, Color(0.78, 0.66, 0.48))  # korkkitiiviste
		ci.draw_arc(c, r * 0.68, 0, TAU, 24, Color(0.6, 0.5, 0.35), 3.0)
		return
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.16, Color(1, 1, 1, 0.35))
	var taso := p[1] if p.size() > 1 else ""
	if taso == "juhla":
		for i in 12:
			var a := i * TAU / 12.0
			ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.7, c + Vector2(cos(a), sin(a)) * r * 0.86, Color(1, 0.85, 0.2), 4.0)
	var txt := String(br.nimi).left(6).to_upper()
	if taso == "virhe":
		ci.draw_set_transform(c, PI, Vector2.ONE)
		ci.draw_string(ThemeDB.fallback_font, Vector2(-r, 8), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 22, Color(0.3, 0.9, 0.4))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_string(ThemeDB.fallback_font, c + Vector2(-r, 8), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 22, Color(1, 0.95, 0.85))


## Lyöjä: vanha tinanappi (kiiltävä metalli, kupera keskusta).
func _make_slammer() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.72, 0.74)
	m.metallic = 0.95
	m.roughness = 0.25
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = CAP_R * 1.5
	cm.bottom_radius = CAP_R * 1.55
	cm.height = 0.006
	cm.radial_segments = 48
	body.mesh = cm
	body.material_override = m
	n.add_child(body)
	var boss := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = CAP_R * 0.6
	bm.height = CAP_R * 0.5
	boss.mesh = bm
	boss.position.y = 0.003
	boss.material_override = m
	n.add_child(boss)
	return n


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	_hud_c = Control.new()
	_hud_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_c.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_c.draw.connect(_draw_hud)
	_hud_c.gui_input.connect(_gui)
	_hud.add_child(_hud_c)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	_hud.add_child(_keys)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _gui(e: InputEvent) -> void:
	if _turn != "me":
		return
	if e is InputEventMouseMotion and _phase == "aim":
		_aim = clampf((e.position.x / maxf(1.0, _hud_c.size.x) - 0.5) * 3.0, -1.0, 1.0)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_press()


func _press() -> void:
	if _phase == "aim":
		_phase = "power"
		_power = 0.0
		_pdir = 1.0
	elif _phase == "power":
		_strike(_aim, _power)


func _process(delta: float) -> void:
	_t += delta
	_pt += delta
	_say_t -= delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_end(true)
		return
	match _phase:
		"aim", "power":
			if _turn == "me":
				_aim = clampf(_aim + Input.get_axis("left", "right") * delta * 1.6 + sin(_t * 3.0) * drunk * delta, -1.0, 1.0)
				if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact"):
					_press()
				if _phase == "power":
					_power += _pdir * delta * (1.1 + drunk * 0.6)
					if _power >= 1.0 or _power <= 0.0:
						_pdir = -_pdir
						_power = clampf(_power, 0.0, 1.0)
			elif _pt > 1.3:
				_jere.play("Interact", 0.15)
				_strike(randf_range(-0.45, 0.45), clampf(randfn(SWEET, 0.12), 0.3, 1.0))
		"slam":
			if _pt > 0.16:
				_resolve()
		"fly":
			for fl in _flying:
				fl[3] = minf(1.0, fl[3] + delta * 1.7)
				var k: float = fl[3]
				var n: Node3D = fl[0]
				n.position = (fl[1] as Vector3).lerp(fl[2], k) + Vector3.UP * sin(k * PI) * 0.12
				n.rotation.x = fl[5] + fl[4] * PI * k
			if _pt > 0.85:
				_flying.clear()
				_next_turn()
	_place_slammer()
	_aim_cam()
	if _turn == "me" and _phase in ["aim", "power"]:
		_keys.set_text("%s [Hiiri] tähtää   %s %s   %s lopeta" % [Settings.pair("left", "right"), Settings.cap("jump"),
			"lyö nyt!" if _phase == "power" else "voima käyntiin", Settings.cap("mount")])
	else:
		_keys.set_text("%s lopeta" % Settings.cap("mount"))
	_hud_c.queue_redraw()


## Lyöjä tähtäyksen kohdalla pinon yllä (vuorolla), iskussa alas pinon päälle.
func _place_slammer() -> void:
	var top := CAP_H * (_caps.size() + 1.0)
	var lift := 0.05 if _phase != "slam" else 0.05 * maxf(0.0, 1.0 - _pt / 0.16)
	_slammer.visible = _phase in ["aim", "power", "slam"]
	_slammer.position = _r() * _aim * 0.045 + Vector3.UP * (top + lift)


func _strike(aim: float, power: float) -> void:
	_aim = aim
	_power = power
	_phase = "slam"
	_pt = 0.0


## Lyönnin tulos: kääntyneet korkit lentävät lyöjän eteen riviin logo ylös (pariton määrä puolikierroksia nurjasta).
func _resolve() -> void:
	_rounds += 1
	_shake = 0.6 + _power * 0.6
	Sfx.play("rattle_hard" if _power > 0.6 else "rattle", -4.0, randf_range(1.2, 1.5))
	var too_hard := _power > TOO_HARD
	var q := clampf((1.0 - absf(_aim) * 0.6) * (1.0 - absf(_power - SWEET) * 2.2), 0.05, 1.0)
	var mine := _turn == "me"
	var f := _f()
	var r := _r()
	var n_won := 0
	for i in range(_caps.size() - 1, -1, -1):
		var cn: Node3D = _caps[i]
		if too_hard and randf() < 0.6:
			var to := r * randf_range(-0.25, 0.25) + f * randf_range(-0.2, 0.2) + Vector3.UP * CAP_H / 2.0
			_flying.append([cn, cn.position, to, 0.0, 2.0, cn.rotation.x])
		elif not too_hard and randf() < q * 0.8:
			var won: Array = _won_me if mine else _won_teen
			won.append(String(cn.get_meta("key")))
			n_won += 1
			var to := (f * 0.1 if mine else -f * 0.28) + r * (-0.1 + won.size() * 0.065) + Vector3.UP * CAP_H / 2.0
			_flying.append([cn, cn.position, to, 0.0, 3.0, cn.rotation.x])
			_caps.remove_at(i)
			stack.remove_at(i)
	if too_hard:
		_say = "Liian kova! Korkit asfaltilla, ei kenellekään." if mine else "Jere löi liian kovaa. Korkit takaisin pinoon."
		Sfx.play("hit", -6.0, 0.8)
	else:
		_say = ("%d korkkia kääntyi! Sun." % n_won if n_won > 0 else "Ei yhtään. Pino pysyi nurin.") if mine else \
			("Jere sai %d." % n_won if n_won > 0 else "Jeren lyönti meni ohi.")
		if n_won > 0:
			Sfx.play("coin", -6.0, 1.3)
	_say_t = 2.0
	_phase = "fly"
	_pt = 0.0


func _next_turn() -> void:
	for i in _caps.size():  # asfaltille lentäneet nurin päin takaisin pinoon
		var cn: Node3D = _caps[i]
		cn.position = Vector3(randf_range(-0.003, 0.003), CAP_H * (i + 0.5), randf_range(-0.003, 0.003))
		cn.rotation.x = PI
	if _caps.is_empty() or _rounds >= 14:
		_phase = "done"
		_say = "Pino on tyhjä. Sää voitit %d korkkia, Jere %d." % [_won_me.size(), _won_teen.size()]
		_say_t = 99.0
		Sfx.play("win_small" if _won_me.size() >= _won_teen.size() else "hit", -4.0)
		get_tree().create_timer(2.6).timeout.connect(_end.bind(false))
		return
	_turn = "teini" if _turn == "me" else "me"
	_phase = "aim"
	_pt = 0.0
	_jere.play("Crouch_Idle", 0.3)


func _end(quit: bool) -> void:
	if is_queued_for_deletion():
		return
	var won := _won_me.duplicate()
	if quit:
		for i in stack.size():
			if i % 2 == 0:
				won.append(stack[i].key)
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	finished.emit(won, quit)
	queue_free()


func _draw_hud() -> void:
	var ci := _hud_c
	var s := ci.size
	MG.box(ci, Rect2(20, 14, 620, 44), Color(0.08, 0.07, 0.06, 0.8), 8)
	ci.draw_string(ThemeDB.fallback_font, Vector2(20, 44), "KORKKILÄPSY · %s · sää %d, Jere %d · pinossa %d" % [
		"sun vuoro" if _turn == "me" else "Jeren vuoro", _won_me.size(), _won_teen.size(), _caps.size()],
		HORIZONTAL_ALIGNMENT_CENTER, 620, 18, Color(1, 0.97, 0.9))
	if _turn == "me" and _phase in ["aim", "power"]:
		var r := Rect2(s.x - 110, s.y * 0.45, 40, 240)
		MG.box(ci, r.grow(6), Color(0.1, 0.1, 0.1, 0.7), 6)
		ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * (1.0 - TOO_HARD)), Color(0.85, 0.2, 0.15))
		ci.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * (SWEET + 0.08), r.size.x, r.size.y * 0.16), Color(0.3, 0.8, 0.35))
		ci.draw_rect(Rect2(r.position.x - 6, r.end.y - r.size.y * _power - 3, r.size.x + 12, 6), Color(1, 1, 1))
		ci.draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 20, r.end.y + 28), "VOIMA", HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Color(1, 0.97, 0.9))
	if _say_t > 0:
		var w := 560.0
		MG.box(ci, Rect2((s.x - w) / 2.0, 80, w, 48), Color(0.98, 0.94, 0.82, 0.95), 10, 4, Color(0.35, 0.25, 0.15), 2)
		ci.draw_string(ThemeDB.fallback_font, Vector2((s.x - w) / 2.0, 112), _say, HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(0.2, 0.14, 0.08))
