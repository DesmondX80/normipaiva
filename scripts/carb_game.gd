extends CanvasLayer
## Karburaattorin säätö (autotalli, SLN-73): kaksi ruuvia, seos (A/D) ja tyhjäkäynti (W/S). Oikeat asennot
## arvotaan. Moottorin ääni ja kierroslukumittari kertovat tilan: rikas seos savuttaa mustaa ja käy raskaasti,
## laiha seos nikottelee ja paukkuu, tyhjäkäynti liian alhaalla sammuttaa, liian ylhäällä ulvoo. Tavoite: kierrokset
## vihreällä alueella ja tasainen käynti HOLD sekuntia. Humalassa ruuvimeisseli lipsuu. F / Esc lopettaa kesken.

const MG := preload("res://scripts/mg_draw.gd")

signal finished(success: bool)
signal comment(text: String)

const HOLD := 3.0
const TIME := 50.0
const GREEN := Vector2(800.0, 1000.0)  # tyhjäkäynnin kierrokset

var drunk := 0.0

var _root: Control
var _info: Label
var _keys: Control
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
var _shake := 0.0  # ruudun tärähdys (PAM, sammuminen)
var _sparks: Array = []  # pakoputken liekin kipinät (MG.sparks_*)
var _flame_t := -1.0
var _was_stalled := false
var _drv := ""  # ruuvi, jota meisseli kääntää ("seos" / "tyhja"), näkyy hetken viimeisen säädön jälkeen
var _drv_t := 0.0
var _drv_spin := 0.0

const ALU := Color(0.7, 0.71, 0.72)  # valualumiini
const STEEL := Color(0.72, 0.73, 0.76)
const BRASS := Color(0.86, 0.68, 0.3)
const BENCH := Color(0.5, 0.36, 0.22)
const ENGINE_SCALE := 1.0


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
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
	_keys = preload("res://scripts/hint_bar.gd").new()  # näppäinohjeet hattuina, näppäimet asetuksista
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
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
	if tm != 0.0 or ti != 0.0:  # meisseli siihen ruuviin, jota käännetään
		_drv = "seos" if absf(tm) >= absf(ti) else "tyhja"
		_drv_t = 0.7
		_drv_spin += (tm if _drv == "seos" else ti) * delta * 6.0
	_drv_t -= delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	_flame_t -= delta
	MG.sparks_step(_sparks, delta)
	# Moottorin tila: seosvirhe tekee käynnistä epätasaisen ja laskee kierroksia, tyhjäkäyntiruuvi siirtää tasoa.
	var me := _mix - _mix_ok  # > 0 rikas, < 0 laiha
	var base := 900.0 + (_idle - _idle_ok) * 900.0 - absf(me) * 500.0
	_rough = clampf(absf(me) * 2.2 + (0.35 if base < 600.0 else 0.0), 0.0, 1.0)
	_stalled = base < 380.0
	if _stalled and not _was_stalled:  # sammui: yskäisy ja nytkähdys
		Sfx.play("rattle_hard", -10.0, 0.6)
		_shake = maxf(_shake, 0.5)
	_was_stalled = _stalled
	var want := 0.0 if _stalled else base + sin(_t * (9.0 + 14.0 * _rough)) * 260.0 * _rough + randf_range(-60, 60) * _rough
	_rpm = lerpf(_rpm, want, 1.0 - exp(-6.0 * delta))
	_engine.pitch_scale = clampf(0.45 + _rpm / 1500.0, 0.3, 2.2)
	_engine.volume_db = -40.0 if _rpm < 100.0 else -8.0
	# Laiha seos paukkuu, rikas savuttaa mustaa.
	_bang_t -= delta
	if me < -0.25 and not _stalled and randf() < delta * 1.2:
		_bang_t = 0.35
		_flame_t = 0.3
		_shake = 1.0
		MG.sparks_burst(_sparks, _outlet_screen(), Color(1.0, 0.6, 0.15), 14)
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
			comment.emit("Sammui! Tyhjäkäyntiä ylös (%s)." % Settings.action_key("forward"))
		elif me > 0.25:
			comment.emit("Musta savu – liian rikas. Seosruuvia vasemmalle (%s)." % Settings.action_key("left"))
		elif me < -0.25:
			comment.emit("Paukkuu – laiha seos. Seosruuvia oikealle (%s)." % Settings.action_key("right"))
		elif _rpm > GREEN.y:
			comment.emit("Ulvoo. Tyhjäkäyntiä alas (%s)." % Settings.action_key("back"))
	if _ok_t >= HOLD:
		_finish(true)
		return
	if _t >= TIME:
		_finish(false)
		return
	_info.text = "Karburaattori · %d s" % ceili(TIME - _t)
	_keys.set_text("%s seosruuvi   %s tyhjäkäynti   %s lopeta" % [Settings.pair("left", "right"),
		Settings.pair("forward", "back"), Settings.cap("mount")])


func _finish(success: bool) -> void:
	_done = true
	_engine.stop()
	finished.emit(success)
	queue_free()


## Piirtoalue: autotallin seinä ja työpöytä (sama talli kuin sähköpyörässä).
func _area() -> Rect2:
	return Rect2(_root.size / 2.0 - Vector2(470, 260), Vector2(940, 500))


## Moottorin origo ruudulla (kampikammion yläreunan keskikohta).
func _engine_origin() -> Vector2:
	return _area().position + Vector2(380, 345)


## Pakoputken suu ruudulla (moottorin paikalliset koordinaatit kerrottuna mittakaavalla).
func _outlet_screen() -> Vector2:
	return _engine_origin() + Vector2(-292, 40) * ENGINE_SCALE


func _draw_root() -> void:
	var font := ThemeDB.fallback_font
	_root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0, 0, 0, 0.6))
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 8.0 * _shake
	_root.draw_set_transform(sh)
	_draw_workshop()
	# Moottori täristää käydessään (rikas tai laiha seos enemmän).
	var jit := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (1.0 + 5.0 * _rough) * (0.0 if _stalled or _rpm < 100.0 else 1.0)
	_root.draw_set_transform(sh + _engine_origin() + jit, 0.0, Vector2.ONE * ENGINE_SCALE)
	_draw_engine()
	_draw_smoke()
	_draw_screwdriver()
	_root.draw_set_transform(sh)
	_draw_labels(font)
	_draw_tach(font)
	_draw_bars(font)
	MG.sparks_draw(_root, _sparks)
	if _bang_t > 0.0:
		var bp := _outlet_screen() + Vector2(-10, -70)
		_root.draw_string(font, bp + Vector2(3, 3), "PAM!", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(0, 0, 0, _bang_t / 0.35 * 0.6))
		_root.draw_string(font, bp, "PAM!", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(1, 0.55, 0.1, _bang_t / 0.35))
	_root.draw_set_transform(Vector2.ZERO)


## Talli: reikälevyseinä työkaluineen, lamppu, SLN-73-kyltti ja puinen työpöytä.
func _draw_workshop() -> void:
	var a := _area()
	MG.box(_root, a.grow(10), Color(0.1, 0.07, 0.05), 12, 14)
	var wall := Rect2(a.position, Vector2(a.size.x, 110))
	MG.grad_rect(_root, wall, Color(0.62, 0.5, 0.36), Color(0.5, 0.4, 0.28))
	for x in range(int(a.position.x) + 14, int(a.end.x), 22):  # reikälevy
		for y in range(int(a.position.y) + 12, int(a.position.y) + 104, 20):
			_root.draw_circle(Vector2(x, y), 2.2, Color(0.3, 0.22, 0.14))
	# Työkalut seinällä: kiintoavaimet koon mukaan, pihdit ja ruuvimeisselit.
	for k in 4:
		var w0 := a.position + Vector2(36 + k * 26, 20)
		var ln := 50.0 + k * 8.0
		_root.draw_line(w0, w0 + Vector2(0, ln), STEEL.darkened(0.15), 7.0)
		_root.draw_line(w0 + Vector2(-1, 0), w0 + Vector2(-1, ln), STEEL.lightened(0.2), 2.0)
		_root.draw_circle(w0, 9.0 + k, STEEL.darkened(0.15))
		_root.draw_circle(w0 + Vector2(0, -4), 4.5 + k * 0.5, Color(0.58, 0.47, 0.34))
	var pl := a.position + Vector2(160, 22)
	for side in [-1.0, 1.0]:
		_root.draw_line(pl + Vector2(side * 5, 26), pl + Vector2(side * 12, 70), Color(0.75, 0.15, 0.1), 8.0)
		_root.draw_line(pl + Vector2(0, 26), pl + Vector2(side * 4, 0), STEEL.darkened(0.2), 6.0)
	_root.draw_circle(pl + Vector2(0, 26), 5.0, STEEL.darkened(0.4))
	for k in 3:
		var sd := a.position + Vector2(205 + k * 24, 20)
		MG.solid(_root, Rect2(sd, Vector2(12, 30)), [Color(0.85, 0.15, 0.1), Color(0.95, 0.75, 0.1), Color(0.15, 0.4, 0.8)][k], false)
		_root.draw_line(sd + Vector2(6, 30), sd + Vector2(6, 68), STEEL, 4.0)
	MG.sign(_root, Rect2(a.position + Vector2(300, 30), Vector2(200, 42)), "SLN-73 TALLI", Color(0.15, 0.25, 0.55), Color.WHITE, 20)
	# Öljykannu hyllyllä.
	var can := a.position + Vector2(560, 46)
	MG.box(_root, Rect2(can, Vector2(46, 56)), Color(0.8, 0.12, 0.1), 6, 3, MG.OUTLINE, 2)
	_root.draw_line(can + Vector2(40, 8), can + Vector2(70, -14), Color(0.6, 0.1, 0.08), 5.0)
	_root.draw_string(ThemeDB.fallback_font, can + Vector2(0, 36), "2T", HORIZONTAL_ALIGNMENT_CENTER, 46, 18, Color(1, 0.95, 0.8))
	_root.draw_rect(Rect2(a.position + Vector2(540, 102), Vector2(110, 6)), Color(0.35, 0.24, 0.14))
	var lamp := Vector2(a.position.x + a.size.x * 0.4, a.position.y + 6)
	MG.glow(_root, lamp + Vector2(0, 220), 420.0, Color(1.0, 0.9, 0.6, 0.45))
	_root.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-34, 30), lamp + Vector2(34, 30), lamp + Vector2(18, 0), lamp + Vector2(-18, 0)]),
		Color(0.2, 0.35, 0.25))
	_root.draw_circle(lamp + Vector2(0, 30), 12.0, Color(1.0, 0.97, 0.8))
	MG.wood(_root, Rect2(a.position + Vector2(0, 110), Vector2(a.size.x, a.size.y - 110)), BENCH, 68.0, 11)
	_root.draw_line(a.position + Vector2(0, 110), a.position + Vector2(a.size.x, 110), Color(0.2, 0.13, 0.07), 4.0)
	# Öljytahra ja rätti pöydällä.
	_root.draw_circle(a.position + Vector2(120, 455), 30.0, Color(0.15, 0.1, 0.06, 0.35))
	_root.draw_circle(a.position + Vector2(140, 445), 18.0, Color(0.15, 0.1, 0.06, 0.3))
	var rag := PackedVector2Array([a.position + Vector2(470, 440), a.position + Vector2(540, 430), a.position + Vector2(560, 470),
		a.position + Vector2(500, 486), a.position + Vector2(462, 470)])
	_root.draw_colored_polygon(rag, Color(0.8, 0.3, 0.25))
	_root.draw_polyline(rag + PackedVector2Array([rag[0]]), MG.OUTLINE, 2.0)
	_root.draw_line(rag[0] + Vector2(10, 8), rag[2] + Vector2(-12, -6), Color(0.65, 0.2, 0.18), 3.0)


## Valualumiininen kappale: tumma reuna ja varjo, vaalea yläosa, ääriviiva.
func _cast(r: Rect2, col: Color, radius := 10) -> void:
	MG.box(_root, r, col.darkened(0.28), radius, 6, MG.OUTLINE, 2)
	MG.box(_root, Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, r.size.y * 0.5)), col.lightened(0.08), maxi(radius - 3, 2))
	_root.draw_line(r.position + Vector2(radius, 3), r.position + Vector2(r.size.x - radius, 3), col.lightened(0.4), 2.0)


## Mopon moottori sivulta (paikalliset koordinaatit, origo kampikammion yläreunassa): kampikammio, ripasylinteri,
## kansi ja sytytystulppa, pakoputki äänenvaimentimineen sekä kaasutin uimurikammioineen ja ilmanpuhdistimineen.
func _draw_engine() -> void:
	# Pakoputki ensin (kulkee kampikammion takaa).
	var pipe := PackedVector2Array([Vector2(-80, -70), Vector2(-140, -62), Vector2(-185, -32), Vector2(-200, 20)])
	_root.draw_polyline(pipe, MG.OUTLINE, 20.0)
	_root.draw_polyline(pipe, Color(0.3, 0.27, 0.25), 16.0)
	_root.draw_polyline(pipe, Color(0.5, 0.45, 0.4), 4.0)
	var muff := Rect2(Vector2(-280, 14), Vector2(130, 48))
	MG.box(_root, muff, Color(0.22, 0.21, 0.2), 22, 6, MG.OUTLINE, 2)
	MG.box(_root, Rect2(muff.position + Vector2(10, 5), Vector2(110, 14)), Color(0.42, 0.4, 0.38), 7)
	for k in 3:  # lämpösuojan reiät
		_root.draw_circle(muff.position + Vector2(40 + k * 26, 34), 4.0, Color(0.1, 0.1, 0.1))
	MG.box(_root, Rect2(Vector2(-298, 30), Vector2(24, 20)), Color(0.3, 0.29, 0.28), 4, 0, MG.OUTLINE, 2)  # suu
	_root.draw_circle(Vector2(-296, 40), 6.0, Color(0.05, 0.05, 0.05))
	# Kampikammio ja kannen pultit.
	_cast(Rect2(Vector2(-150, -10), Vector2(270, 115)), ALU, 26)
	_root.draw_circle(Vector2(-40, 48), 34.0, ALU.darkened(0.12))  # kytkinkoppa
	_root.draw_arc(Vector2(-40, 48), 34.0, 0, TAU, 32, MG.OUTLINE, 2.0)
	_root.draw_arc(Vector2(-40, 48), 26.0, PI * 1.1, PI * 1.6, 12, ALU.lightened(0.35), 3.0)
	for b in [Vector2(-130, 8), Vector2(100, 8), Vector2(-130, 88), Vector2(100, 88), Vector2(30, 92)]:
		MG.ball(_root, b, 5.0, STEEL, 0.6)
	_root.draw_line(Vector2(60, 60), Vector2(118, 60), Color(0.1, 0.1, 0.1), 6.0)  # polkimen akseli
	# Sylinteri ripoineen ja kansi.
	MG.solid(_root, Rect2(Vector2(-78, -160), Vector2(96, 152)), ALU.darkened(0.4))
	for i in 8:
		MG.solid(_root, Rect2(Vector2(-102 + (i % 2) * 2, -152 + i * 18), Vector2(144, 9)), ALU.darkened(0.05))
	_cast(Rect2(Vector2(-92, -188), Vector2(124, 32)), ALU, 8)
	# Sytytystulppa ja johto.
	MG.solid(_root, Rect2(Vector2(-38, -204), Vector2(16, 16)), STEEL.darkened(0.2))
	MG.box(_root, Rect2(Vector2(-36, -232), Vector2(12, 28)), Color(0.95, 0.94, 0.9), 4, 0, MG.OUTLINE, 2)
	MG.box(_root, Rect2(Vector2(-41, -258), Vector2(22, 30)), Color(0.12, 0.12, 0.12), 8, 3, MG.OUTLINE, 2)
	# Tulpanjohto sytytyspuolalle kampikammion kylkeen.
	_root.draw_polyline(PackedVector2Array([Vector2(-30, -258), Vector2(-60, -262), Vector2(-122, -230), Vector2(-150, -150),
		Vector2(-142, -20)]), Color(0.1, 0.1, 0.1), 5.0)
	MG.box(_root, Rect2(Vector2(-150, -26), Vector2(18, 14)), Color(0.12, 0.12, 0.12), 4, 0, MG.OUTLINE, 2)
	# Imusarja kaasuttimelle.
	MG.solid(_root, Rect2(Vector2(18, -84), Vector2(54, 30)), Color(0.15, 0.15, 0.15))
	# Kaasutin: runko, liukutorni vaijereineen, uimurikammio ja ilmanpuhdistin.
	# Kaasuvaijeri (kahva irrotettu): kaartuu pöydälle, päässä nippa.
	var cable := PackedVector2Array([Vector2(118, -164), Vector2(124, -200), Vector2(190, -222), Vector2(262, -188), Vector2(272, -110),
		Vector2(258, 40)])
	_root.draw_polyline(cable, Color(0.1, 0.1, 0.1), 5.0)
	MG.ball(_root, Vector2(258, 44), 5.0, BRASS, 0.5)
	_cast(Rect2(Vector2(100, -152), Vector2(38, 46)), ALU, 6)
	MG.ball(_root, Vector2(119, -156), 8.0, STEEL, 0.6)
	_cast(Rect2(Vector2(70, -110), Vector2(100, 78)), ALU.lightened(0.04), 12)
	_cast(Rect2(Vector2(80, -36), Vector2(80, 48)), ALU.darkened(0.06), 14)
	MG.ball(_root, Vector2(120, 16), 5.0, BRASS, 0.5)  # tyhjennysruuvi
	_root.draw_line(Vector2(84, -34), Vector2(156, -34), ALU.darkened(0.45), 3.0)  # kammion sauma
	MG.box(_root, Rect2(Vector2(170, -118), Vector2(76, 96)), Color(0.13, 0.13, 0.14), 18, 5, MG.OUTLINE, 2)
	for k in 5:  # suodattimen rivat
		_root.draw_line(Vector2(182 + k * 13, -110), Vector2(182 + k * 13, -30), Color(0.24, 0.24, 0.26), 4.0)
	MG.solid(_root, Rect2(Vector2(166, -82), Vector2(10, 24)), STEEL.darkened(0.2))  # kiristin
	# Säätöruuvit: seos (messinki, rungon kyljessä) ja tyhjäkäynti (teräs, jousi).
	_screw(Vector2(92, -54), _mix, BRASS, false)
	_screw(Vector2(150, -86), _idle, STEEL, true)


## Säätöruuvin kanta: jousi (tyhjäkäynti), sävytetty kanta ja ura asennon mukaan.
func _screw(p: Vector2, v: float, col: Color, spring: bool) -> void:
	if spring:
		for k in 3:
			_root.draw_arc(p, 17.0 + k * 3.0, 0, TAU, 24, STEEL.darkened(0.3 + k * 0.1), 2.0)
	MG.ball(_root, p, 14.0, col, 0.6)
	var a := v * PI * 1.5
	_root.draw_line(p + Vector2(-10, 0).rotated(a), p + Vector2(10, 0).rotated(a), Color(0.1, 0.08, 0.06), 4.0)


func _screw_pos(which: String) -> Vector2:
	return Vector2(92, -54) if which == "seos" else Vector2(150, -86)


## Ruuvimeisseli käännettävässä ruuvissa: varsi ja kahva, jonka urat pyörivät käännön mukana.
func _draw_screwdriver() -> void:
	if _drv_t <= 0.0:
		return
	var p := _screw_pos(_drv)
	var dir := Vector2(0.62, 0.78)
	var h0 := p + dir * 46.0
	var h1 := p + dir * 104.0
	_root.draw_line(p, h0, MG.OUTLINE, 9.0)
	_root.draw_line(p, h0, STEEL, 6.0)
	_root.draw_line(p + Vector2(-1, -1), h0 + Vector2(-1, -1), STEEL.lightened(0.4), 2.0)
	var hc := Color(0.85, 0.15, 0.1) if _drv == "seos" else Color(0.95, 0.75, 0.1)
	_root.draw_line(h0, h1, MG.OUTLINE, 26.0)
	_root.draw_line(h0, h1, hc, 22.0)
	_root.draw_line(h0 + Vector2(-4, 3), h1 + Vector2(-4, 3), hc.lightened(0.35), 5.0)
	var side := Vector2(-dir.y, dir.x)
	for k in 4:  # kahvan urat pyörivät
		var ph := fposmod(_drv_spin + k * 0.25, 1.0)
		var o := side * (ph - 0.5) * 18.0
		_root.draw_line(h0 + dir * 6.0 + o, h1 - dir * 6.0 + o, hc.darkened(0.35), 2.0)


## Pakokaasu: rikas seos tummaa nokea, muuten vaaleaa kaksitahtisavua. Liekki PAM-paukahduksessa.
func _draw_smoke() -> void:
	var ex := Vector2(-300, 40)
	for s in _smoke:
		var age: float = s[1]
		var k := age / 1.6
		var p: Vector2 = ex + Vector2(-age * 22.0 + s[0].x + sin(age * 3.0 + s[0].x) * 8.0, -age * 95.0)
		var col := Color(0.1, 0.09, 0.08, 0.75 * (1.0 - k)) if s[2] else Color(0.86, 0.86, 0.9, 0.4 * (1.0 - k))
		var rad := 9.0 + age * 24.0
		_root.draw_circle(p, rad, col)
		_root.draw_circle(p + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.55, col.lightened(0.15) if s[2] else Color(1, 1, 1, col.a * 0.6))
	if _flame_t > 0.0:
		var f := _flame_t / 0.3
		var pts := PackedVector2Array()
		for i in 10:
			var a := PI + (i - 4.5) * 0.22
			var r := (34.0 if i % 2 == 0 else 16.0) * (0.6 + f)
			pts.append(ex + Vector2(cos(a), sin(a)) * r)
		_root.draw_colored_polygon(PackedVector2Array([ex]) + pts, Color(1.0, 0.55, 0.1, f))
		_root.draw_circle(ex + Vector2(-8, 0), 10.0 * (0.6 + f), Color(1.0, 0.95, 0.5, f))


## Ruuvien nimikyltit pöydällä, viivat ruuveille.
func _draw_labels(font: Font) -> void:
	var o := _engine_origin()
	for e in [["seos", "SEOS  %s / %s" % [Settings.action_key("left"), Settings.action_key("right")], Vector2(-190, 118), BRASS],
			["tyhja", "TYHJÄKÄYNTI  %s / %s" % [Settings.action_key("forward"), Settings.action_key("back")], Vector2(20, 118), STEEL]]:
		var sp: Vector2 = o + _screw_pos(e[0]) * ENGINE_SCALE
		var r := Rect2(o + e[2], Vector2(190, 32))
		_root.draw_line(sp, r.position + Vector2(r.size.x / 2.0, 0), Color(1, 1, 1, 0.55), 2.0)
		_root.draw_circle(sp, 4.0, Color(1, 1, 1, 0.7))
		MG.box(_root, r, Color(0.97, 0.95, 0.88), 6, 3, MG.OUTLINE, 2)
		_root.draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(8, r.size.y - 12)), (e[3] as Color))
		_root.draw_string(font, r.position + Vector2(16, 22), e[1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 17, Color(0.12, 0.1, 0.08))


## Kierroslukumittari jalustalla: kromikehys, asteikko, vihreä ja punainen alue, neula ja lasin heijastus.
func _draw_tach(font: Font) -> void:
	var a := _area()
	var g := a.position + Vector2(790, 250)
	var rad := 118.0
	# Jalusta pöytään ja johto moottorille.
	_root.draw_line(g + Vector2(0, rad), g + Vector2(0, rad + 60), Color(0.15, 0.15, 0.16), 14.0)
	MG.box(_root, Rect2(g + Vector2(-60, rad + 52), Vector2(120, 22)), Color(0.18, 0.18, 0.2), 8, 4, MG.OUTLINE, 2)
	_root.draw_polyline(PackedVector2Array([g + Vector2(-50, rad + 62), g + Vector2(-140, rad + 84), _engine_origin() + Vector2(112, 80) * ENGINE_SCALE]),
		Color(0.12, 0.12, 0.12), 3.0)
	_root.draw_circle(g + Vector2(4, 6), rad + 14.0, Color(0, 0, 0, 0.35))
	_root.draw_circle(g, rad + 14.0, Color(0.55, 0.56, 0.6))
	_root.draw_arc(g, rad + 9.0, PI * 1.05, PI * 1.7, 24, Color(0.95, 0.95, 1.0), 5.0)
	_root.draw_arc(g, rad + 14.0, 0, TAU, 64, MG.OUTLINE, 2.0)
	_root.draw_circle(g, rad, Color(0.08, 0.08, 0.09))
	var a0 := PI * 0.75
	var span := PI * 1.5
	var to_a := func(r: float) -> float: return a0 + span * clampf(r / 3000.0, 0.0, 1.0)
	_root.draw_arc(g, rad - 18.0, to_a.call(GREEN.x), to_a.call(GREEN.y), 16, Color(0.3, 0.85, 0.4), 12.0)
	_root.draw_arc(g, rad - 18.0, to_a.call(2400.0), to_a.call(3000.0), 16, Color(0.9, 0.2, 0.15), 12.0)
	for k in 31:
		var ta: float = to_a.call(k * 100.0)
		var big := k % 5 == 0
		_root.draw_line(g + Vector2(cos(ta), sin(ta)) * (rad - (26.0 if big else 14.0)), g + Vector2(cos(ta), sin(ta)) * (rad - 4.0),
			Color.WHITE if big else Color(0.75, 0.75, 0.78), 3.0 if big else 1.5)
		if big:
			_root.draw_string(font, g + Vector2(cos(ta), sin(ta)) * (rad - 44.0) - Vector2(12, -7), str(k), HORIZONTAL_ALIGNMENT_CENTER, 24, 17,
				Color(0.92, 0.92, 0.92))
	_root.draw_string(font, g + Vector2(-60, 46), "x100 r/min", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(0.75, 0.75, 0.78))
	_root.draw_string(font, g + Vector2(-80, 78), "SAMMUI" if _stalled else "%d" % roundi(_rpm), HORIZONTAL_ALIGNMENT_CENTER, 160, 26,
		Color(1, 0.4, 0.3) if _stalled else Color.WHITE)
	var na: float = to_a.call(_rpm)
	var tip := g + Vector2(cos(na), sin(na)) * (rad - 14.0)
	_root.draw_line(g + Vector2(3, 4), tip + Vector2(3, 4), Color(0, 0, 0, 0.5), 5.0, true)
	_root.draw_line(g - Vector2(cos(na), sin(na)) * 18.0, tip, Color(1, 0.3, 0.2), 4.0, true)
	MG.ball(_root, g, 11.0, Color(0.35, 0.35, 0.38), 0.5)
	_root.draw_arc(g, rad * 0.78, PI * 1.12, PI * 1.42, 16, Color(1, 1, 1, 0.12), 22.0)  # lasin heijastus


## Käynnin tasaisuus ja onnistumisaika pienellä mittaritaululla.
func _draw_bars(font: Font) -> void:
	var a := _area()
	var panel := Rect2(a.position + Vector2(640, 410), Vector2(290, 80))
	MG.box(_root, panel, Color(0.16, 0.16, 0.17), 8, 5, MG.OUTLINE, 2)
	var bar := Rect2(panel.position + Vector2(14, 26), Vector2(262, 14))
	_root.draw_string(font, panel.position + Vector2(0, 20), "Käynnin tasaisuus", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 15, Color.WHITE)
	MG.box(_root, bar.grow(2.0), Color(0.04, 0.04, 0.04), 6)
	MG.box(_root, Rect2(bar.position, Vector2(bar.size.x * (1.0 - _rough), bar.size.y)), Color(0.3, 0.8, 0.45).lerp(Color(0.9, 0.3, 0.2), _rough), 5)
	var hb := Rect2(panel.position + Vector2(14, 58), Vector2(262, 10))
	_root.draw_string(font, panel.position + Vector2(0, 54), "Tasainen käynti %d / %d s" % [floori(_ok_t), int(HOLD)], HORIZONTAL_ALIGNMENT_CENTER,
		panel.size.x, 13, Color(0.85, 0.85, 0.85))
	MG.box(_root, hb.grow(2.0), Color(0.04, 0.04, 0.04), 5)
	MG.box(_root, Rect2(hb.position, Vector2(hb.size.x * _ok_t / HOLD, hb.size.y)), Color(0.95, 0.8, 0.2), 4)
