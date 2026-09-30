extends Node3D
## Drooninlennätys kotipihalta: kauko-ohjattava kuvauskopteri, jolla tutkitaan Saloisia ilmasta.
## W/S eteen ja taakse, A/D sivuttain, hiiri tai Q/E kääntää, Space nousee, C/Ctrl laskee, Shift = sport-tila.
## Hiiren pystyliike kallistaa kameran gimbaalia. Vasen nappi / Enter ottaa ilmakuvan: tunnetut paikat ja hahmot
## (pois-lista) tunnistetaan kuvasta ja tallentuvat kokoelmaan (photographed-signaali). V vaihtaa FPV- ja
## seurantakameran, H palaa kotiin, F laskeutuu alustalle (vain alustan lähellä).
## Akku riittää viideksi minuutiksi; 20 %:ssa varoitus, 8 %:ssa automaattinen paluu kotiin. Yli kantaman
## signaali heikkenee ja drooni palaa itse. Kova törmäys maahan, taloon tai puuhun rikkoo droonin.
## main.gd:n lapsi, paikka = laskeutumisalusta; body liikkuu maailmassa (tutka, kompassi ja kartta seuraavat sitä).
## Lennetään kotipihalta Saloisissa tai mökin pihalta: maanpinta, vesi ja lentoalue annetaan kutsuttavina
## (oletuksena Saloisten maasto ja pelialue).

signal photographed(id: String)
signal finished(result: String)  # "landed" | "crashed"

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")
const M := preload("res://scripts/map_data.gd")

const SPEED := 11.0
const SPORT := 19.0
const VSPEED := 4.0
const YAW_KEY := 1.6
const MAX_ALT := 120.0  # EU:n avoimen luokan korkeusraja lähtöpisteestä
const RANGE := 1300.0
const RANGE_WARN := 1050.0
const CRASH_SPEED := 7.5
const BATTERY_S := 300.0
const RTH_ALT := 40.0
const PHOTO_RANGE := 320.0
const PHOTO_CONE := 0.3  # rad kuvan keskeltä

var battery := 1.0  # 0..1 (main.gd säilyttää lentojen välillä)
var pois: Array = []  # [{id, name, pos: Callable -> Vector3}]
var photo_count := 0
var photo_total := 0
var hud: CanvasLayer  # pelin HUD, piilotetaan kuvan ottamisen ajaksi
var ground := func(x: float, z: float) -> float: return Terrain.h(x, z)  # pinnan korkeus maailmassa (vesi = pinta)
var is_water := func(_x: float, _z: float) -> bool: return false
var in_bounds := Callable()  # (Vector2 maailman x/z) -> bool; oletuksena Saloisten pelialue

var body: CharacterBody3D
var _model: Node3D
var _props: Array[Node3D] = []
var _cam: Camera3D
var _buzz: AudioStreamPlayer3D
var _yaw := 0.0
var _gimbal := -0.25
var _vel := Vector3.ZERO
var _home := Vector3.ZERO
var _home_ground := 0.0
var _mode := "fly"  # fly | rth | landing | done
var _landed := true
var _t := 0.0
var _warned := {}
var _saved_fps := false
var _play_poly := PackedVector2Array()

var _layer: CanvasLayer
var _tele: Label
var _warn: Label
var _warn_t := 0.0
var _help: Label
var _flash: ColorRect
var _thumb: TextureRect
var _thumb_t := 0.0
var _rec: Label


func _ready() -> void:
	_home = global_position
	_home_ground = ground.call(_home.x, _home.z)
	body = CharacterBody3D.new()
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.28
	cs.shape = sh
	body.add_child(cs)
	add_child(body)
	body.top_level = true
	body.global_position = _home + Vector3(0, 0.25, 0)
	_model = make_model(body)
	for c in _model.get_children():
		if c.has_meta("prop"):
			_props.append(c)
	_cam = Camera3D.new()
	_cam.fov = 78.0
	_cam.near = 0.05
	_cam.far = 3000.0
	_cam.top_level = true
	add_child(_cam)
	_cam.current = true
	_buzz = AudioStreamPlayer3D.new()
	_buzz.bus = "SFX"
	_buzz.stream = _buzz_stream()
	_buzz.unit_size = 3.0
	_buzz.volume_db = -20.0
	body.add_child(_buzz)
	_buzz.play()
	if not in_bounds.is_valid():
		for p in M.PLAY_AREA:
			_play_poly.append(M.w2(p))
		in_bounds = func(p: Vector2) -> bool: return Geometry2D.is_point_in_polygon(p, _play_poly)
	_saved_fps = CamCtl.fps
	CamCtl.fps = true
	CamCtl.need_mouse = true
	if Touch.active:
		Touch.look.connect(_look)
		Touch.set_extra([[KEY_P, "Kuva"], [KEY_C, "Alas"], [KEY_H, "Kotiin"]])
	_build_hud()
	_say("Drooni valmiina. Space nostaa ilmaan.", 3.0)


func _exit_tree() -> void:
	CamCtl.need_mouse = false
	CamCtl.fps = _saved_fps
	if Touch.active:
		Touch.look.disconnect(_look)
		Touch.set_extra([])


## Nelikopterin malli: runko, varret, moottorit, potkurit (meta "prop") ja kamera gimbaalissa (-Z eteen).
static func make_model(parent: Node3D) -> Node3D:
	var m := Node3D.new()
	parent.add_child(m)
	var grey := Color(0.32, 0.33, 0.35)
	B.mesh(m, B.boxm(Vector3(0.22, 0.08, 0.34)), Vector3(0, 0, 0), grey)
	B.mesh(m, B.boxm(Vector3(0.16, 0.03, 0.2)), Vector3(0, 0.055, 0.02), Color(0.2, 0.2, 0.22))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tip := Vector3(sx * 0.24, 0.02, sz * 0.24)
			B.tube(m, Vector3(sx * 0.06, 0, sz * 0.1), tip, 0.014, grey)
			B.mesh(m, B.cyl(0.025, 0.025, 0.05, 8), tip + Vector3(0, 0.02, 0), Color(0.12, 0.12, 0.12))
			var prop := B.mesh(m, B.boxm(Vector3(0.24, 0.005, 0.025)), tip + Vector3(0, 0.05, 0), Color(0.15, 0.15, 0.16))
			prop.set_meta("prop", true)
			var led := B.mesh(m, B.sphere(0.012, 6), tip + Vector3(0, -0.015, 0), Color.WHITE)
			led.material_override = B.unshaded(Color(1, 0.15, 0.1) if sz < 0.0 else Color(0.2, 1.0, 0.3))
	B.mesh(m, B.sphere(0.04, 10), Vector3(0, -0.06, -0.17), Color(0.1, 0.1, 0.1))
	B.mesh(m, B.cyl(0.018, 0.018, 0.02, 10), Vector3(0, -0.06, -0.21), Color(0.2, 0.35, 0.6), Vector3(90, 0, 0))
	for sx in [-1.0, 1.0]:
		B.mesh(m, B.boxm(Vector3(0.015, 0.1, 0.24)), Vector3(sx * 0.09, -0.08, 0), Color(0.2, 0.2, 0.2))
	return m


## Laskeutumisalusta: tumma kiekko, keltainen H ja kantolaukku vieressä. pos = alustan keskipiste maanpinnalla.
static func make_pad(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var pad := Node3D.new()
	pad.position = pos + Vector3(0, 0.01, 0)
	pad.rotation.y = yaw
	parent.add_child(pad)
	B.mesh(pad, B.cyl(0.9, 0.9, 0.02, 24), Vector3.ZERO, Color(0.12, 0.12, 0.13))
	B.mesh(pad, B.cyl(0.8, 0.8, 0.025, 24), Vector3.ZERO, Color(0.9, 0.75, 0.1))
	B.mesh(pad, B.cyl(0.74, 0.74, 0.03, 24), Vector3.ZERO, Color(0.12, 0.12, 0.13))
	for hx in [-0.22, 0.22]:
		B.mesh(pad, B.boxm(Vector3(0.08, 0.02, 0.6)), Vector3(hx, 0.02, 0), Color(0.9, 0.75, 0.1))
	B.mesh(pad, B.boxm(Vector3(0.44, 0.02, 0.08)), Vector3(0, 0.02, 0), Color(0.9, 0.75, 0.1))
	B.mesh(pad, B.boxm(Vector3(0.5, 0.18, 0.35)), Vector3(1.3, 0.09, 0.2), Color(0.1, 0.1, 0.1))  # kantolaukku
	return pad


# --- Syöte ja lento ---------------------------------------------------------------

## Kääntö ja kameran kallistus (hiiri tai kosketusveto).
func _look(rel: Vector2) -> void:
	if _mode == "done" or get_tree().paused:
		return
	var sens: float = 0.0028 * Settings.get_v("mouse_sens")
	_yaw -= rel.x * sens
	var inv := -1.0 if Settings.get_v("invert_y") else 1.0
	_gimbal = clampf(_gimbal - rel.y * sens * inv, -PI / 2.0, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if _mode == "done":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Touch.active:
		_look(event.relative)
	elif event is InputEventMouseButton and not Touch.active and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		take_photo()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_P:
				take_photo()
			KEY_H:
				if _mode == "fly" and not _landed:
					_start_rth("Paluu kotiin.")
			KEY_F:
				if _home_dist() < 6.0 and _mode == "fly":
					_mode = "landing"
					_say("Laskeudutaan alustalle.", 2.0)
				elif _mode == "fly":
					_say("Alusta on %d m päässä. Lennä sen yläpuolelle tai paina H." % int(_home_dist()), 2.5)


func _physics_process(delta: float) -> void:
	if _mode == "done":
		return
	_t += delta
	var pos := body.global_position
	var floor_y: float = ground.call(pos.x, pos.z)
	var alt := pos.y - _home_ground
	var target := Vector3.ZERO
	var vy := 0.0
	var sport := Input.is_key_pressed(KEY_SHIFT)
	match _mode:
		"fly":
			var v := Input.get_vector("left", "right", "forward", "back")
			var yk := (1.0 if Input.is_key_pressed(KEY_Q) else 0.0) - (1.0 if Input.is_key_pressed(KEY_E) else 0.0)
			_yaw += yk * YAW_KEY * delta
			target = Basis(Vector3.UP, _yaw) * Vector3(v.x, 0, v.y) * (SPORT if sport else SPEED)
			if Input.is_action_pressed("jump"):
				vy = VSPEED
			elif Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL):
				vy = -VSPEED
		"rth":
			var to := Vector2(_home.x - pos.x, _home.z - pos.z)
			if alt < RTH_ALT - 1.0 and to.length() > 20.0:
				vy = VSPEED
			if to.length() > 1.0:
				target = Vector3(to.x, 0, to.y).normalized() * minf(14.0, to.length() * 0.8 + 0.5)
				_yaw = lerp_angle(_yaw, atan2(-to.x, -to.y), 1.0 - exp(-2.0 * delta))
			if to.length() < 1.5:
				_mode = "landing"
		"landing":
			var to := Vector2(_home.x - pos.x, _home.z - pos.z)
			target = Vector3(to.x, 0, to.y) * 1.5
			vy = -clampf((pos.y - floor_y) * 0.8, 0.6, 3.0)
	# Tuulenpuuskat heiluttavat ilmassa, sitä enemmän mitä korkeammalla.
	var gust := Vector3(sin(_t * 0.37) + 0.5 * sin(_t * 1.3), 0, cos(_t * 0.29)) * clampf(alt / 60.0, 0.0, 1.0) * 0.6
	var h := Vector2(_vel.x, _vel.z).lerp(Vector2(target.x, target.z), 1.0 - exp(-2.2 * delta))
	_vel = Vector3(h.x, lerpf(_vel.y, vy, 1.0 - exp(-4.0 * delta)), h.y)
	if _landed and _vel.y <= 0.05:
		_vel = Vector3.ZERO
	# Korkeusraja ja alueen raja.
	if alt > MAX_ALT and _vel.y > 0.0:
		_vel.y = 0.0
		_warn_once("alt", "Korkeusraja 120 m.")
	var p2 := Vector2(pos.x, pos.z)
	if not in_bounds.call(p2):
		var back := (Vector2(_home.x, _home.z) - p2).normalized() * 6.0
		_vel.x = back.x
		_vel.z = back.y
		_warn_once("edge", "Lentoalueen raja! Ei lupaa lentää pidemmälle.")
	var before := _vel.length()
	body.velocity = _vel + gust
	body.move_and_slide()
	for i in body.get_slide_collision_count():
		if before > CRASH_SPEED:
			_crash("Drooni osui esteeseen %d km/h vauhdissa!" % roundi(before * 3.6))
			return
		_vel *= 0.3
	pos = body.global_position
	floor_y = ground.call(pos.x, pos.z)
	if pos.y < floor_y + 0.18:
		if is_water.call(pos.x, pos.z):
			_crash("Drooni tipahti järveen!")
			return
		if _vel.y < -3.5 or Vector2(_vel.x, _vel.z).length() > CRASH_SPEED:
			_crash("Drooni iskeytyi maahan!")
			return
		body.global_position.y = floor_y + 0.18
		if not _landed and _vel.y <= 0.0:
			_landed = true
			_vel = Vector3.ZERO
			if _mode == "landing" or _home_dist() < 3.0:
				_finish("landed")
				return
	elif pos.y > floor_y + 0.4:
		_landed = false
	_tick_battery(delta, sport)
	_tick_range()
	_update_visuals(delta)


func _home_dist() -> float:
	var p := body.global_position
	return Vector2(p.x - _home.x, p.z - _home.z).length()


func _tick_battery(delta: float, sport: bool) -> void:
	if _landed:
		return
	battery -= delta / BATTERY_S * (1.4 if sport else 1.0)
	if battery < 0.2:
		_warn_once("bat20", "Akku 20 %! Aika kääntyä kotiin.")
	if battery < 0.08 and _mode == "fly":
		_start_rth("Akku loppumassa: automaattinen paluu kotiin.")
	if battery <= 0.0:
		battery = 0.0
		_crash("Akku loppui kesken lennon!")


func _tick_range() -> void:
	var d := _home_dist()
	if d > RANGE_WARN:
		_warn_once("range", "Signaali heikkenee...")
	if d > RANGE and _mode == "fly":
		_start_rth("Signaali katkesi: drooni palaa kotiin.")


func _start_rth(msg: String) -> void:
	_mode = "rth"
	_say(msg, 3.0)
	Sfx.play("alert", -10.0, 1.6)


func _warn_once(key: String, msg: String) -> void:
	if _warned.get(key, -99.0) > _t - 8.0:
		return
	_warned[key] = _t
	_say(msg, 2.5)
	Sfx.play("alert", -12.0, 1.8)


func _crash(msg: String) -> void:
	_mode = "done"
	_buzz.stop()
	Sfx.play("rattle_hard", 0.0, 0.7)
	Sfx.play("glass", -4.0, 1.4)
	_model.rotation = Vector3(0.9, 0.3, 1.8)
	body.global_position.y = ground.call(body.global_position.x, body.global_position.z) + 0.1
	_say(msg + "\nDROONI RIKKI", 3.0)
	await get_tree().create_timer(2.5).timeout
	finished.emit("crashed")


func _finish(result: String) -> void:
	_mode = "done"
	_buzz.stop()
	Sfx.play("pickup", -8.0, 0.8)
	_say("Laskeutunut alustalle.", 1.5)
	await get_tree().create_timer(1.0).timeout
	finished.emit(result)


func _update_visuals(delta: float) -> void:
	var local := Basis(Vector3.UP, _yaw).inverse() * _vel
	var tilt_x := clampf(local.z / SPORT, -1.0, 1.0) * 0.45
	var tilt_z := clampf(-local.x / SPORT, -1.0, 1.0) * 0.45
	_model.rotation = _model.rotation.lerp(Vector3(tilt_x, _yaw, tilt_z), 1.0 - exp(-8.0 * delta))
	var spin := 0.0 if _landed else 60.0
	for pr in _props:
		pr.rotation.y += spin * delta
	_buzz.pitch_scale = 0.94 + 0.14 * clampf(_vel.length() / SPORT + absf(_vel.y) / VSPEED * 0.3, 0.0, 1.0) \
		if not _landed else 0.8
	# Kamera: FPV gimbaalista (vakaa, ei kallistu rungon mukana) tai seuranta takaa.
	var bp := body.global_position
	if CamCtl.fps:
		_cam.global_position = bp + Basis(Vector3.UP, _yaw) * Vector3(0, -0.08, -0.22)
		_cam.global_basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _gimbal)
	else:
		var back := Basis(Vector3.UP, _yaw) * Vector3(0, 0.9, 2.6)
		var want := bp + back
		want.y = maxf(want.y, ground.call(want.x, want.z) + 0.5)
		_cam.global_position = _cam.global_position.lerp(want, 1.0 - exp(-6.0 * delta))
		_cam.look_at(bp + Vector3(0, 0.2, 0), Vector3.UP)


# --- Ilmakuvat ------------------------------------------------------------------------

## Ottaa kuvan kameran suuntaan. Tunnistaa lähimmän kuvan keskelle osuvan kohteen.
func take_photo() -> void:
	if _mode == "done":
		return
	Sfx.play("pickup", -6.0, 2.2)
	var fwd := -_cam.global_basis.z
	var best := ""
	var best_name := ""
	var best_score := 99.0
	for poi in pois:
		var at: Vector3 = poi.pos.call()
		var v := at - _cam.global_position
		var d := v.length()
		if d > PHOTO_RANGE or d < 1.0:
			continue
		var ang := fwd.angle_to(v)
		if ang > PHOTO_CONE:
			continue
		var score := ang + d / PHOTO_RANGE * 0.2
		if score < best_score:
			best_score = score
			best = poi.id
			best_name = poi.name
	# Pikkukuvaan pelkkä maisema: HUD:t piiloon yhdeksi ruuduksi (näyttää sulkimen räpsäykseltä).
	_layer.visible = false
	if hud != null:
		hud.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_layer.visible = true
	if hud != null:
		hud.visible = true
	img.resize(img.get_width() / 4, img.get_height() / 4)
	_flash.color.a = 0.8
	_thumb.texture = ImageTexture.create_from_image(img)
	_thumb_t = 3.0
	if best != "":
		photographed.emit(best)
		_say("Ilmakuva: %s" % best_name, 2.5)
	else:
		_say("Kuva otettu. Ei mitään erityistä kuvassa.", 1.8)


# --- HUD --------------------------------------------------------------------------

func _say(msg: String, secs: float) -> void:
	if _warn == null:
		return
	_warn.text = msg
	_warn_t = secs


func _process(delta: float) -> void:
	if _layer == null:
		return
	_warn_t -= delta
	if _warn_t <= 0.0:
		_warn.text = ""
	_thumb_t -= delta
	_thumb.visible = _thumb_t > 0.0
	_flash.color.a = maxf(_flash.color.a - delta * 3.0, 0.0)
	_rec.modulate.a = 1.0 if fmod(_t, 1.0) < 0.6 else 0.3
	var p := body.global_position
	var alt := p.y - _home_ground
	var hs := Vector2(_vel.x, _vel.z).length()
	var heading := wrapf(rad_to_deg(-_yaw), 0.0, 360.0)
	_tele.text = "KORK %d m   ·   NOPEUS %d km/h   ·   KOTIIN %d m   ·   SUUNTA %03d°   ·   AKKU %d %%%s" % [
		roundi(alt), roundi(hs * 3.6), roundi(_home_dist()), roundi(heading), roundi(battery * 100.0),
		"   ·   PALUU" if _mode == "rth" else ""]
	_tele.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if battery < 0.2 else Color.WHITE)
	_rec.text = "● REC  kuvia %d/%d" % [photo_count, photo_total]


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 11
	add_child(_layer)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_flash)
	# Kuvausrajaus: kulmat ja keskipiste kuten kuvauskopterin näkymässä.
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		var s := frame.size
		var m := 60.0
		var l := 40.0
		var c := Color(1, 1, 1, 0.7)
		for corner in [Vector2(m, m), Vector2(s.x - m, m), Vector2(m, s.y - m), Vector2(s.x - m, s.y - m)]:
			var dx := l if corner.x < s.x / 2.0 else -l
			var dy := l if corner.y < s.y / 2.0 else -l
			frame.draw_line(corner, corner + Vector2(dx, 0), c, 2.0)
			frame.draw_line(corner, corner + Vector2(0, dy), c, 2.0)
		frame.draw_arc(s / 2.0, 14.0, 0, TAU, 24, c, 1.5)
		frame.draw_line(s / 2.0 - Vector2(26, 0), s / 2.0 - Vector2(16, 0), c, 1.5)
		frame.draw_line(s / 2.0 + Vector2(16, 0), s / 2.0 + Vector2(26, 0), c, 1.5))
	_layer.add_child(frame)
	get_viewport().size_changed.connect(frame.queue_redraw)
	_tele = _hud_label(20, Control.PRESET_TOP_WIDE, Rect2(0, 62, 0, 90))
	_rec = _hud_label(20, Control.PRESET_TOP_LEFT, Rect2(76, 70, 400, 96))
	_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rec.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
	_warn = _hud_label(30, Control.PRESET_CENTER, Rect2(-500, 60, 500, 160))
	_warn.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_help = _hud_label(17, Control.PRESET_BOTTOM_WIDE, Rect2(0, -100, 0, -76))
	_help.text = "W/S/A/D liiku · hiiri tai Q/E käänny · Space ylös · C alas · Shift sport · klikkaus kuva · V kamera · H kotiin · F laskeudu"
	_thumb = TextureRect.new()
	_thumb.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_thumb.offset_left = 76
	_thumb.offset_top = 110
	_thumb.offset_right = 76 + 320
	_thumb.offset_bottom = 290
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_thumb.visible = false
	_layer.add_child(_thumb)


func _hud_label(size: int, preset: Control.LayoutPreset, offsets: Rect2) -> Label:
	var l := Label.new()
	l.set_anchors_preset(preset)
	l.offset_left = offsets.position.x
	l.offset_top = offsets.position.y
	l.offset_right = offsets.size.x
	l.offset_bottom = offsets.size.y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(l)
	return l


## Moottorien pieni surina: neljä hieman eri tahtiin pyörivää potkuria (lähes puhtaat siniaallot, jotka huojuvat
## toisiaan vasten) ja hiljainen ilmavirran kohina. Kokonaislukutaajuudet, jotta 1 s silmukka jatkuu saumatta.
static func _buzz_stream() -> AudioStreamWAV:
	var rate := 22050
	var n := rate  # 1 s
	var freqs := [236.0, 241.0, 247.0, 252.0]
	var data := PackedByteArray()
	data.resize(n * 2)
	var hiss := 0.0
	for i in n:
		var t := float(i) / rate
		var s := 0.0
		for f in freqs:
			s += sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t) + 0.08 * sin(TAU * f * 3.0 * t)
		hiss = lerpf(hiss, randf() - 0.5, 0.15)  # pehmennetty kohina
		s = s / freqs.size() * 0.55 + hiss * 0.08
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w
