extends Node3D
## Kodan FPS-minipelien (halonhakkuu, sahaus) yhteinen pohja: kamera ja hiiritähtäys, käsien huojunta,
## tuulenpuuskat (ääni, lehdet, tähtäyksen heitto), HUD (tähtäin, tehtävä, tuuli, tekstitys) sekä kodan
## vakiovieraat Raimo ja Veikko, jotka tulevat ulos katsomaan ja kommentoivat.
## Aliluokka asettaa _init():ssä eye, watcher_spots, watch_at, help_text ja lines ja toteuttaa koukut
## _start, _tick, _action, _alt_action, _mouse_moved, _can_quit, _gust_comment_ok ja _cleanup.
## kota.gd:n lapsi: kaikki koordinaatit ovat tämän solmun paikallisia. Isäntä (kota) voi olla myös mökki
## (mokki.gd), jolloin katsojana on Santtu: isäntä tarjoaa silloin watcher_node(), watcher_bubble() ja
## watcher_say() (kodalla raimo/veikko, _bubbles ja say()).

signal finished

const B := preload("res://scripts/build.gd")
const SENS := 0.0028

var kota: Node3D
## Aliluokan asetukset.
var eye := Vector3.ZERO
var watcher_spots := {}  # "raimo"/"veikko" -> paikka
var watch_at := Vector3.ZERO  # mitä katsojat katsovat
var help_text := ""
var lines := {}  # tilanne -> [[puhuja ("raimo"/"veikko"/"" = kumpi tahansa), repliikki]]
var mouse_aims := true  # false: hiiren liike menee _mouse_moved()-koukulle, kamera pysyy aliluokan suunnassa
var yaw_center := 0.0  # katseen keskisuunta (0 = +Z)
var yaw_limit := 1.2
var pitch_min := -1.35
var pitch_max := 0.2

var _cam: Camera3D
var _yaw := 0.0  # 0 = katse +Z-suuntaan
var _pitch := 0.0
var _t := 0.0
var _shake := 0.0
var _saved := {}
var _debris: Array[Node3D] = []
var _done := false

# Tuuli: puuska kestää hetken ja heittää tähtäystä sivulle.
var _gust_next := 3.0
var _gust_t := -1.0
var _gust_len := 1.0
var _gust_dir := Vector2.ZERO
var _gust_amt := 0.0
var _gust_said := 0.0
var _wind: AudioStreamPlayer3D
var _leaves: CPUParticles3D

var _layer: CanvasLayer
var _cross: Array[Control] = []
var _task: Label
var _wind_label: Label
var _sub: Label
var _sub_t := 0.0
var _count: Label
var _talk_t := {}
var _last_line := ""


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.fov = 68.0
	_cam.near = 0.05
	add_child(_cam)
	_cam.current = true
	_build_leaves()
	_wind = Sfx.loop_on(self, "wind", -40.0)
	if _wind != null:
		_wind.position = eye
	_build_hud()
	_setup_watchers()
	_saved["camctl"] = [CamCtl.yaw, CamCtl.pitch]
	CamCtl.need_mouse = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start()
	# HUD ei saa napata hiirtä: lukittuna kursori on ruudun keskellä tähtäimen päällä, ja
	# ColorRect/ProgressBar söisivät klikkaukset ja liikkeet ennen _unhandled_inputia.
	for c in _layer.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_camera(0.0)


# --- Koukut aliluokalle -------------------------------------------------------------

func _start() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _action() -> void:
	pass


func _alt_action() -> void:
	pass


func _mouse_moved(_rel: Vector2) -> void:
	pass


func _can_quit() -> bool:
	return true


func _gust_comment_ok() -> bool:
	return true


func _cleanup() -> void:
	pass


# --- Kulku ----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or _done:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = SENS * Settings.get_v("mouse_sens")
		var inv := -1.0 if Settings.get_v("invert_y") else 1.0
		var rel := Vector2(event.relative.x, event.relative.y * inv) * sens
		if mouse_aims:
			_yaw = clampf(_yaw - rel.x, yaw_center - yaw_limit, yaw_center + yaw_limit)
			_pitch = clampf(_pitch - rel.y, pitch_min, pitch_max)
		else:
			_mouse_moved(rel)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return  # hiiri ei vielä lukittu (CamCtl lukitsee sen seuraavalla framella)
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_action()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				_alt_action()


func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("mount") and _can_quit():
		_quit()
		return
	if Input.is_action_just_pressed("interact"):
		_action()
	if Input.is_action_just_pressed("bell"):
		_alt_action()
	_update_wind(delta)
	_update_camera(delta)
	_tick(delta)
	if _done:
		return
	for who in _talk_t:
		if _talk_t[who] > 0.0:
			_talk_t[who] -= delta
			if _talk_t[who] <= 0.0:
				_watcher(who).play("Idle", 0.3)
	if _sub_t > 0.0:
		_sub_t -= delta
		if _sub_t <= 0.0:
			_sub.text = ""
	for i in range(_debris.size() - 1, -1, -1):
		var d := _debris[i]
		if d.has_meta("ttl"):
			var ttl: float = d.get_meta("ttl") - delta
			d.set_meta("ttl", ttl)
			if ttl <= 0.0:
				d.queue_free()
				_debris.remove_at(i)


func _exit_tree() -> void:
	CamCtl.need_mouse = false


func _quit() -> void:
	if _done:
		return
	_done = true
	_cleanup()
	_restore_watchers()
	CamCtl.yaw = _saved["camctl"][0]
	CamCtl.pitch = _saved["camctl"][1]
	set_process(false)
	finished.emit()
	queue_free()


## Kappale, joka poistuu ttl sekunnin päästä (ttl < 0: pelin loppuun asti).
func _add_debris(node: Node3D, ttl: float) -> void:
	if ttl > 0.0:
		node.set_meta("ttl", ttl)
	_debris.append(node)


# --- Kamera, huojunta ja tuuli ---------------------------------------------------------

## Tuulenpuuskat: satunnaisin välein puuska, joka heittää tähtäystä sivulle (ja vähän pystyyn).
func _update_wind(delta: float) -> void:
	_gust_said -= delta
	if _gust_t < 0.0:
		_gust_next -= delta
		_gust_amt = move_toward(_gust_amt, 0.0, delta * 0.2)
		if _gust_next <= 0.0:
			_gust_t = 0.0
			_gust_len = randf_range(1.3, 2.8)
			var a := randf_range(-0.35, 0.35) + (0.0 if randf() < 0.5 else PI)
			_gust_dir = Vector2(cos(a), sin(a) * 0.5)
			_gust_amt = randf_range(0.022, 0.055)
			if _gust_said <= 0.0 and randf() < 0.4 and _gust_comment_ok():
				_gust_said = 15.0
				_say_kind("gust")
	else:
		_gust_t += delta
		if _gust_t >= _gust_len:
			_gust_t = -1.0
			_gust_next = randf_range(3.0, 7.5)
	var env := _gust_env()
	if _wind != null:
		_wind.volume_db = lerpf(-30.0, -4.0, env)
	# Lehdet lentävät kameran sivusuunnassa puuskan mukana.
	var right := _cam.transform.basis.x
	right.y = 0.0
	right = right.normalized()
	_leaves.emitting = env > 0.35
	_leaves.direction = -right * signf(_gust_dir.x) + Vector3(0, 0.1, 0)
	_leaves.position = eye + right * 2.2 * signf(_gust_dir.x) + (-_cam.transform.basis.z * Vector3(1, 0, 1)) * 1.5
	if env > 0.15:
		var arrows := "←" if _gust_dir.x > 0.0 else "→"
		_wind_label.text = "Tuulenpuuska %s" % arrows.repeat(1 + int(env * _gust_amt * 70.0))
		_wind_label.modulate.a = clampf(env * 1.5, 0.0, 1.0)
	else:
		_wind_label.text = ""


func _gust_env() -> float:
	if _gust_t < 0.0:
		return 0.0
	var s := sin(PI * _gust_t / _gust_len)
	return s * s * (0.85 + 0.15 * sin(_t * 17.0))


## Puuskan heitto (yaw, pitch) radiaaneina tällä hetkellä.
func _gust_offset() -> Vector2:
	return _gust_dir * _gust_amt * _gust_env()


## Kamera: suunta + hengityksen ja käsien huojunta + tuulenpuuska + tärähdys.
func _update_camera(delta: float) -> void:
	var sway_y := 0.0085 * sin(_t * 1.1) + 0.005 * sin(_t * 2.7 + 1.3) + 0.0025 * sin(_t * 6.1)
	var sway_p := 0.0065 * sin(_t * 1.6 + 0.4) + 0.004 * sin(_t * 0.7) + 0.002 * sin(_t * 5.3 + 2.0)
	var g := _gust_offset()
	sway_y += g.x
	sway_p += g.y
	_shake = maxf(0.0, _shake - delta * 4.0)
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.02
	var roll := 0.012 * sin(_t * 0.9) + 0.02 * _gust_env() * signf(_gust_dir.x)
	var bs := Basis(Vector3.UP, PI + _yaw + sway_y + sh.x) * Basis(Vector3.RIGHT, _pitch + sway_p + sh.y) \
		* Basis(Vector3.BACK, roll)
	_cam.transform = Transform3D(bs, eye + Vector3(0.01 * sin(_t * 0.8), 0.008 * sin(_t * 1.6), 0))
	_cam.fov = Settings.get_v("fov") * 0.95


## Suunta (yaw, pitch), jolla kamera katsoo silmistä pisteeseen p.
func _aim_to(p: Vector3) -> Vector2:
	var d := p - eye
	return Vector2(atan2(d.x, d.z), -atan2(-d.y, Vector2(d.x, d.z).length()))


## Tähtäimen säde leikattuna vaakatasolla y.
func _ray_plane(y: float) -> Vector3:
	var o := _cam.transform.origin
	var d := -_cam.transform.basis.z
	if d.y > -0.02:
		return o + d * 5.0
	return o + d * ((y - o.y) / d.y)


func _build_leaves() -> void:
	_leaves = CPUParticles3D.new()
	_leaves.amount = 40
	_leaves.lifetime = 2.5
	_leaves.emitting = false
	_leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_leaves.emission_box_extents = Vector3(2.5, 1.0, 2.5)
	_leaves.gravity = Vector3(0, -0.6, 0)
	_leaves.spread = 25.0
	_leaves.initial_velocity_min = 2.0
	_leaves.initial_velocity_max = 4.0
	_leaves.angular_velocity_min = -360.0
	_leaves.angular_velocity_max = 360.0
	_leaves.scale_amount_min = 0.6
	_leaves.scale_amount_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.035)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.62, 0.12)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	_leaves.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.95, 0.7, 0.15))
	ramp.set_color(1, Color(0.75, 0.3, 0.08))
	_leaves.color_initial_ramp = ramp
	add_child(_leaves)


# --- Katsojat ja kommentit --------------------------------------------------------------

## Katsojan hahmo, puhekupla ja puhe isännän mukaan (kota: Raimo ja Veikko, mökki: Santtu).
func _watcher(who: String) -> Node3D:
	if kota.has_method("watcher_node"):
		return kota.watcher_node(who)
	return kota.raimo if who == "raimo" else kota.veikko


func _watcher_bubble(who: String) -> Label3D:
	if kota.has_method("watcher_bubble"):
		return kota.watcher_bubble(who)
	return kota._bubbles[who]


func _watcher_say(who: String, text: String, seconds: float) -> void:
	if kota.has_method("watcher_say"):
		kota.watcher_say(who, text, seconds)
	else:
		kota.say(who, text, seconds)


## Katsojat (kodalla Raimo ja Veikko, mökillä Santtu) tulevat seisomaan katsomaan (paikat aliluokalta).
func _setup_watchers() -> void:
	for who in watcher_spots:
		_talk_t[who] = 0.0
		var c: Node3D = _watcher(who)
		var bubble: Label3D = _watcher_bubble(who)
		_saved[who] = [c.transform, bubble.position, c.current()]
		var p: Vector3 = transform * (watcher_spots[who] as Vector3)
		c.position = p
		c.rotation = Vector3(0, B.yaw_to(transform * watch_at - p), 0)
		c.play("Idle", 0.3)
		bubble.position = p + Vector3(0, 2.05, 0)


func _restore_watchers() -> void:
	for who in watcher_spots:
		var c: Node3D = _watcher(who)
		c.transform = _saved[who][0]
		_watcher_bubble(who).position = _saved[who][1]
		c.play(_saved[who][2], 0.0)
		_watcher_say(who, "", 0.0)


func _say_kind(kind: String) -> void:
	var opts: Array = lines[kind].filter(func(l): return l[1] != _last_line)
	if opts.is_empty():
		opts = lines[kind]
	var line: Array = opts.pick_random()
	var who: String = line[0] if line[0] != "" and watcher_spots.has(line[0]) else watcher_spots.keys().pick_random()
	_last_line = line[1]
	var dur := clampf(1.8 + line[1].length() * 0.05, 2.5, 5.5)
	_watcher_say(who, line[1], dur)
	_watcher(who).play("Idle_Talking", 0.2)
	_talk_t[who] = dur
	_sub.text = "%s: %s" % [who.capitalize(), line[1]]
	_sub_t = dur


# --- HUD --------------------------------------------------------------------------------

func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	# Tähtäin: valkoinen risti ja musta keskipiste.
	for spec in [[Vector2(18, 2), Color(1, 1, 1, 0.85)], [Vector2(2, 18), Color(1, 1, 1, 0.85)], [Vector2(2, 2), Color(0, 0, 0, 0.9)]]:
		var r := ColorRect.new()
		var sz: Vector2 = spec[0]
		r.color = spec[1]
		r.anchor_left = 0.5
		r.anchor_right = 0.5
		r.anchor_top = 0.5
		r.anchor_bottom = 0.5
		r.offset_left = -sz.x / 2.0
		r.offset_right = sz.x / 2.0
		r.offset_top = -sz.y / 2.0
		r.offset_bottom = sz.y / 2.0
		_layer.add_child(r)
		_cross.append(r)
	_task = _label(28, 0.0, 50, 90)
	_wind_label = _label(24, 0.0, 94, 128)
	_wind_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_sub = _label(26, 1.0, -170, -100)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.offset_left = 80
	_sub.offset_right = -80
	_sub.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_count = _label(22, 0.0, 16, 44)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_count.offset_left = 20
	var help := _label(16, 1.0, -36, -12)
	help.text = help_text


func _set_crosshair(v: bool) -> void:
	for c in _cross:
		c.visible = v


func _label(size: int, anchor_y: float, top: float, bottom: float) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.anchor_right = 1.0
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_top = top
	l.offset_bottom = bottom
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_layer.add_child(l)
	return l
