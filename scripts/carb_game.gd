extends CanvasLayer
## Karburaattorin säätö (autotalli, SLN-73): kaksi ruuvia, seos (A/D) ja tyhjäkäynti (W/S). Oikeat asennot
## arvotaan. Moottorin ääni ja kierroslukumittari kertovat tilan: rikas seos savuttaa mustaa ja käy raskaasti,
## laiha seos nikottelee ja paukkuu, tyhjäkäynti liian alhaalla sammuttaa, liian ylhäällä ulvoo. Tavoite: kierrokset
## vihreällä alueella ja tasainen käynti HOLD sekuntia. Humalassa ruuvimeisseli lipsuu. F / Esc lopettaa kesken.

signal finished(success: bool)
signal comment(text: String)

const HOLD := 3.0
const TIME := 50.0
const GREEN := Vector2(800.0, 1000.0)  # tyhjäkäynnin kierrokset

var drunk := 0.0

var _root: Control
var _info: Label
var _mix := 0.0  # ruuvien asento -1..1
var _idle := 0.0
var _mix_ok := 0.0
var _idle_ok := 0.0
var _rpm := 0.0
var _rough := 0.0
var _ok_t := 0.0
var _t := 0.0
var _done := false
var _stalled := false
var _bang_t := -1.0
var _smoke: Array = []  # [paikka, ikä, musta]
var _engine: AudioStreamPlayer
var _tip_t := 0.0


func _ready() -> void:
	layer = 6
	_mix_ok = randf_range(-0.55, 0.55)
	_idle_ok = randf_range(-0.5, 0.5)
	_mix = clampf(_mix_ok + [-0.45, 0.45].pick_random(), -1.0, 1.0)  # alussa käy, mutta epätasaisesti
	_idle = clampf(_idle_ok + randf_range(-0.1, 0.5), -1.0, 1.0)
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_root)
	add_child(_root)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 24)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 8)
	_info.anchor_right = 1.0
	_info.offset_top = 40
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_info)
	# Vinkit (comment) näkyvät paneelin alla.
	var tip := Label.new()
	tip.add_theme_font_size_override("font_size", 22)
	tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	tip.add_theme_color_override("font_outline_color", Color.BLACK)
	tip.add_theme_constant_override("outline_size", 6)
	tip.anchor_top = 1.0
	tip.anchor_bottom = 1.0
	tip.anchor_right = 1.0
	tip.offset_top = -90
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tip)
	comment.connect(func(t: String) -> void: tip.text = t)
	_engine = AudioStreamPlayer.new()
	_engine.stream = Sfx.stream("engine")
	_engine.bus = "SFX"
	_engine.volume_db = -8.0
	add_child(_engine)
	_engine.play()
	comment.emit(["Seosruuvi ja tyhjäkäyntiruuvi. Kuuntele moottoria.", "Vanha Lada-tekniikka, korvakuulolla säädetään."].pick_random())


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_root.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish(false)
		return
	var shake := sin(_t * 7.0) * drunk * 0.6
	var tm := Input.get_axis("left", "right")
	var ti := Input.get_axis("back", "forward")
	_mix = clampf(_mix + (tm * 0.35 + (shake if tm != 0.0 else 0.0)) * delta, -1.0, 1.0)
	_idle = clampf(_idle + (ti * 0.35 + (shake if ti != 0.0 else 0.0)) * delta, -1.0, 1.0)
	# Moottorin tila: seosvirhe tekee käynnistä epätasaisen ja laskee kierroksia, tyhjäkäyntiruuvi siirtää tasoa.
	var me := _mix - _mix_ok  # > 0 rikas, < 0 laiha
	var base := 900.0 + (_idle - _idle_ok) * 900.0 - absf(me) * 500.0
	_rough = clampf(absf(me) * 2.2 + (0.35 if base < 600.0 else 0.0), 0.0, 1.0)
	_stalled = base < 380.0
	var want := 0.0 if _stalled else base + sin(_t * (9.0 + 14.0 * _rough)) * 260.0 * _rough + randf_range(-60, 60) * _rough
	_rpm = lerpf(_rpm, want, 1.0 - exp(-6.0 * delta))
	_engine.pitch_scale = clampf(0.45 + _rpm / 1500.0, 0.3, 2.2)
	_engine.volume_db = -40.0 if _rpm < 100.0 else -8.0
	# Laiha seos paukkuu, rikas savuttaa mustaa.
	_bang_t -= delta
	if me < -0.25 and not _stalled and randf() < delta * 1.2:
		_bang_t = 0.35
		Sfx.play("shotgun", -18.0, 2.2)
	if not _stalled and randf() < delta * (3.0 + 6.0 * clampf(me, 0.0, 1.0)):
		_smoke.append([Vector2(randf_range(-6, 6), 0), 0.0, me > 0.2])
	for s in _smoke:
		s[1] += delta
	_smoke = _smoke.filter(func(s): return s[1] < 1.6)
	var good := not _stalled and _rpm > GREEN.x and _rpm < GREEN.y and _rough < 0.18
	_ok_t = _ok_t + delta if good else maxf(0.0, _ok_t - delta * 2.0)
	_tip_t -= delta
	if _tip_t <= 0.0:
		_tip_t = 5.0
		if _stalled:
			comment.emit("Sammui! Tyhjäkäyntiä ylös (W).")
		elif me > 0.25:
			comment.emit("Musta savu – liian rikas. Seosruuvia vasemmalle (A).")
		elif me < -0.25:
			comment.emit("Paukkuu – laiha seos. Seosruuvia oikealle (D).")
		elif _rpm > GREEN.y:
			comment.emit("Ulvoo. Tyhjäkäyntiä alas (S).")
	if _ok_t >= HOLD:
		_finish(true)
		return
	if _t >= TIME:
		_finish(false)
		return
	_info.text = "Karburaattori · A/D seosruuvi · W/S tyhjäkäynti · %d s · F lopettaa" % ceili(TIME - _t)


func _finish(success: bool) -> void:
	_done = true
	_engine.stop()
	finished.emit(success)
	queue_free()


func _draw_root() -> void:
	var sz := _root.size
	var c := sz / 2.0 + Vector2(0, 30)
	var font := ThemeDB.fallback_font
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.55))
	var panel := Rect2(c - Vector2(470, 270), Vector2(940, 540))
	_box(panel, Color(0.2, 0.19, 0.18), 16, Color(0, 0, 0, 0.5), 16)
	# Moottorin tärinä.
	var jit := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (2.0 + 10.0 * _rough) * (0.0 if _stalled else 1.0)
	# Kaasutin ylhäältä: runko, kurkku, kaksi ruuvia uurteineen.
	var body := c + Vector2(-140, 0) + jit
	_box(Rect2(body - Vector2(150, 130), Vector2(300, 260)), Color(0.62, 0.62, 0.6), 20, Color(0, 0, 0, 0.4), 8)
	_root.draw_circle(body, 78.0, Color(0.35, 0.35, 0.36))
	_root.draw_circle(body, 64.0, Color(0.08, 0.08, 0.09))  # kurkku
	_root.draw_line(body + Vector2(-60, 0).rotated(0.4 + _idle * 0.8), body + Vector2(60, 0).rotated(0.4 + _idle * 0.8),
		Color(0.55, 0.55, 0.56), 6.0)  # kuristinläppä
	for k in 4:  # kiinnityspultit
		var a := k * TAU / 4.0 + PI / 4.0
		_root.draw_circle(body + Vector2(cos(a), sin(a)) * 125.0, 9.0, Color(0.45, 0.45, 0.47))
	_screw(body + Vector2(-95, 105), _mix, "SEOS  A / D", Color(0.85, 0.7, 0.3))
	_screw(body + Vector2(95, 105), _idle, "TYHJÄKÄYNTI  W / S", Color(0.75, 0.75, 0.8))
	# Pakoputken savu.
	var ex := c + Vector2(-140, -200)
	for s in _smoke:
		var age: float = s[1]
		var p: Vector2 = ex + s[0] + Vector2(sin(age * 3.0 + s[0].x) * 14.0, -age * 70.0)
		var col := Color(0.08, 0.08, 0.08, 0.7 * (1.0 - age / 1.6)) if s[2] else Color(0.85, 0.85, 0.88, 0.35 * (1.0 - age / 1.6))
		_root.draw_circle(p, 10.0 + age * 22.0, col)
	if _bang_t > 0.0:
		_root.draw_string(font, ex + Vector2(40, -20), "PAM!", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(1, 0.5, 0.1, _bang_t / 0.35))
	# Kierroslukumittari.
	var g := c + Vector2(260, -20)
	_root.draw_circle(g, 150.0, Color(0.1, 0.1, 0.11))
	_root.draw_arc(g, 150.0, 0, TAU, 64, Color(0.6, 0.6, 0.62), 5.0, true)
	var a0 := PI * 0.75
	var span := PI * 1.5
	var to_a := func(r: float) -> float: return a0 + span * clampf(r / 3000.0, 0.0, 1.0)
	_root.draw_arc(g, 128.0, to_a.call(GREEN.x), to_a.call(GREEN.y), 16, Color(0.3, 0.85, 0.4), 14.0)
	_root.draw_arc(g, 128.0, to_a.call(2400.0), to_a.call(3000.0), 16, Color(0.9, 0.2, 0.15), 14.0)
	for k in 7:
		var a: float = to_a.call(k * 500.0)
		_root.draw_line(g + Vector2(cos(a), sin(a)) * 105.0, g + Vector2(cos(a), sin(a)) * 140.0, Color.WHITE, 3.0)
		_root.draw_string(font, g + Vector2(cos(a), sin(a)) * 85.0 - Vector2(10, -6), str(k * 5), HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(0.9, 0.9, 0.9))
	var na: float = to_a.call(_rpm)
	_root.draw_line(g, g + Vector2(cos(na), sin(na)) * 125.0, Color(1, 0.3, 0.2), 5.0, true)
	_root.draw_circle(g, 12.0, Color(0.3, 0.3, 0.32))
	_root.draw_string(font, g + Vector2(-60, 60), "x100 r/min", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(0.8, 0.8, 0.8))
	_root.draw_string(font, g + Vector2(-80, 90), "SAMMUI" if _stalled else "%d" % roundi(_rpm), HORIZONTAL_ALIGNMENT_CENTER, 160, 28,
		Color(1, 0.4, 0.3) if _stalled else Color.WHITE)
	# Käynnin tasaisuus ja onnistumisaika.
	var bar := Rect2(c + Vector2(110, 175), Vector2(300, 18))
	_box(bar.grow(3.0), Color(0.05, 0.05, 0.05), 8)
	_box(Rect2(bar.position, Vector2(bar.size.x * (1.0 - _rough), bar.size.y)), Color(0.3, 0.8, 0.45).lerp(Color(0.9, 0.3, 0.2), _rough), 6)
	_root.draw_string(font, bar.position + Vector2(0, -8), "Käynnin tasaisuus", HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 18, Color.WHITE)
	var hb := Rect2(c + Vector2(110, 225), Vector2(300, 12))
	_box(hb.grow(3.0), Color(0.05, 0.05, 0.05), 6)
	_box(Rect2(hb.position, Vector2(hb.size.x * _ok_t / HOLD, hb.size.y)), Color(0.95, 0.8, 0.2), 5)


func _screw(p: Vector2, v: float, label: String, col: Color) -> void:
	_root.draw_circle(p, 26.0, col.darkened(0.3))
	_root.draw_circle(p, 22.0, col)
	var a := v * PI * 1.5
	_root.draw_line(p + Vector2(-18, 0).rotated(a), p + Vector2(18, 0).rotated(a), Color(0.15, 0.15, 0.15), 5.0)
	_root.draw_string(ThemeDB.fallback_font, p + Vector2(-90, 50), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 16, Color.WHITE)


func _box(r: Rect2, col: Color, radius: int, shadow := Color(0, 0, 0, 0), shadow_size := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.shadow_color = shadow
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(4, 6)
	sb.anti_aliasing = true
	_root.draw_style_box(sb, r)
