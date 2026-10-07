extends CanvasLayer
## Vessanpönttö (kodin WC, mökin pesuhuone, mökin huussi): ykkönen tai kakkonen omana minipelinään.
## Ykkönen: pidä suihku pöntössä (WASD / nuolet tai hiiri). Tähtäin vaeltaa itsestään, humalassa enemmän; ohi
## menneet tipat jäävät lattialle. Kakkonen: ponnista (E / välilyönti), kun mittarin neula on vihreällä, kolme
## kertaa; punaisella sattuu. Sitten paperia (E repäisee arkin, välilyönti valmis): liian vähän on säästeliäs,
## liian paljon tukkii pöntön (huussissa ei tukkeudu). F / Esc lopettaa kesken.

signal finished(mode: String, result: Dictionary)
signal comment(text: String)

const PEE_TIME := 7.0
const BOWL := Vector2(170, 120)  # pöntön reuna (ellipsin puoliakselit, px)
const WATER := Vector2(105, 70)  # vesi pöntön pohjalla
const PUSHES := 3
const GREEN := Vector2(0.42, 0.62)  # ponnistuksen vihreä alue mittarilla
const RED := 0.84  # tästä ylöspäin liian kovaa
const PAPER_OK := Vector2i(3, 7)  # sopiva määrä arkkeja
const PAPER_CLOG := 10  # tästä alkaen pönttö tukkeutuu
const LINES := {
	"pee_start": ["Tähtää nyt kunnolla, siivottiin just.", "Rauhassa vaan, ei oo kiire mihinkään."],
	"pee_miss": ["Ohi meni!", "Hups, lattialle.", "Reunalle tippuu..."],
	"poo_start": ["No niin. Rauhassa nyt.", "Puhelin pois, keskity."],
	"poo_push": ["Hyvä, liikettä!", "Nyt tulee.", "Vielä vähän!"],
	"poo_hard": ["AI! Liian kovaa!", "Ei noin kovaa, perkele!"],
	"poo_weak": ["Ei tuu mittään...", "Heikosti meni."],
	"paper": ["Paperia sitten.", "Ja nyt paperia, ei säästellä mutta ei tuhlatakaan."],
}

var mode := "ykkonen"  # ykkonen / kakkonen
var drunk := 0.0
var flush := true  # huussissa ei ole vesivessaa (ei tukkeudu)

var _root: Control
var _info: Label
var _keys: Control
var _say: Label  # kommentit pelin aikana (HUD on piilossa)
var _say_t := 0.0
var _done := false
var _t := 0.0
# Ykkönen
var _aim := Vector2.ZERO
var _drift := Vector2.ZERO
var _inside := 0.0
var _total := 0.0
var _puddles: Array[Vector2] = []
var _miss_cd := 0.0
# Kakkonen
var _phase := "push"  # push / paper
var _needle := 0.0
var _needle_dir := 1.0
var _needle_speed := 0.9
var _pushes := 0
var _hard := 0
var _weak := 0
var _sheets := 0
var _flash := 0.0
var _flash_col := Color.WHITE
var _stream: AudioStreamPlayer  # ykkösen solina: korkea vedessä, matala lattialla


func _ready() -> void:
	layer = 6
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
	_say = Label.new()
	_say.add_theme_font_size_override("font_size", 30)
	_say.add_theme_color_override("font_outline_color", Color.BLACK)
	_say.add_theme_constant_override("outline_size", 10)
	_say.anchor_right = 1.0
	_say.anchor_top = 1.0
	_say.anchor_bottom = 1.0
	_say.offset_top = -120
	_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_say)
	comment.connect(func(t: String) -> void:
		_say.text = t
		_say_t = 1.8)
	comment.emit(LINES.pee_start.pick_random() if mode == "ykkonen" else LINES.poo_start.pick_random())
	Sfx.play("cloth", -6.0, 1.6)  # vetoketju / housut alas
	if mode == "ykkonen":
		_stream = AudioStreamPlayer.new()
		_stream.bus = "SFX"
		_stream.stream = Sfx.stream("water")
		_stream.volume_db = -12.0
		add_child(_stream)
		_stream.play()


func _input(event: InputEvent) -> void:
	if _done or mode != "ykkonen":
		return
	if event is InputEventMouseMotion:
		_aim += event.relative * 0.6


func _process(delta: float) -> void:
	if _done:
		return
	_root.queue_redraw()
	_flash = maxf(0.0, _flash - delta * 2.5)
	_say_t -= delta
	if _say_t <= 0.0:
		_say.text = ""
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish()
		return
	_t += delta
	if mode == "ykkonen":
		_pee(delta)
	else:
		_poo(delta)


func _pee(delta: float) -> void:
	# Tähtäin vaeltaa satunnaisesti (humala lisää), pelaaja korjaa.
	var shake := 140.0 + drunk * 320.0
	_drift = (_drift + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * delta * 3.0).limit_length(shake)
	var move := Vector2(Input.get_axis("left", "right"), Input.get_axis("forward", "back"))
	_aim += (_drift + move * 300.0) * delta
	_aim = _aim.limit_length(BOWL.x * 1.8)
	var w := _ellipse(_aim, WATER)
	var r := _ellipse(_aim, BOWL)
	_total += delta
	_miss_cd -= delta
	if w <= 1.0:
		_inside += delta
		_sound(-7.0, 1.8)  # solina vedessä
	elif r <= 1.0:
		_inside += delta * 0.5  # reunalle: puoliksi
		_sound(-11.0, 1.35)
	else:
		_sound(-15.0, 0.85)  # lätinä lattialle
		if _miss_cd <= 0.0:
			_puddles.append(_aim + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
			_miss_cd = 0.12
			if randf() < 0.25:
				comment.emit(LINES.pee_miss.pick_random())
	_info.text = "Ykkönen · pidä suihku pöntössä · %.0f s" % maxf(0.0, PEE_TIME - _t)
	_keys.set_text("[%s/%s/%s/%s] suuntaa suihkua (tai hiiri)   %s lopeta" % [Settings.action_key("forward"),
		Settings.action_key("left"), Settings.action_key("back"), Settings.action_key("right"), Settings.cap("mount")])
	if _t >= PEE_TIME:
		_finish()


func _poo(delta: float) -> void:
	var press := Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("brake")
	if _phase == "push":
		_needle += _needle_dir * _needle_speed * delta * (1.0 + drunk * 0.6)
		if _needle > 1.0 or _needle < 0.0:
			_needle_dir = -_needle_dir
			_needle = clampf(_needle, 0.0, 1.0)
		_info.text = "Kakkonen · %d / %d" % [_pushes, PUSHES]
		_keys.set_text("[%s / %s] ponnista vihreällä   %s lopeta" % [Settings.action_key("interact"),
			Settings.action_key("brake"), Settings.cap("mount")])
		if not press:
			return
		if _needle >= RED:
			_hard += 1
			_flash_col = Color(1, 0.2, 0.15)
			comment.emit(LINES.poo_hard.pick_random())
			Sfx.play("groan", -4.0)
		elif _needle >= GREEN.x and _needle <= GREEN.y:
			_pushes += 1
			_needle_speed += 0.35
			_flash_col = Color(0.3, 1, 0.4)
			comment.emit(LINES.poo_push.pick_random())
			Sfx.play("grunt", -6.0, randf_range(0.9, 1.05))
			Sfx.play("water", -10.0, 0.5)  # molskahdus
			if randf() < 0.4:
				Sfx.play("fart", -4.0, randf_range(0.9, 1.2))
			if _pushes >= PUSHES:
				_phase = "paper"
				comment.emit(LINES.paper.pick_random())
		else:
			_weak += 1
			_flash_col = Color(1, 0.85, 0.3)
			comment.emit(LINES.poo_weak.pick_random())
			Sfx.play("grunt", -12.0, 1.2)
		_flash = 1.0
		return
	_info.text = "Paperia: %d arkkia" % _sheets
	_keys.set_text("%s repäise arkki   %s valmis" % [Settings.cap("interact"), Settings.cap("brake")])
	if Input.is_action_just_pressed("interact"):
		_sheets += 1
		Sfx.play("cloth", -12.0, 1.4)
	elif Input.is_action_just_pressed("brake") and _sheets > 0:
		_finish()


## Solinan voimakkuus ja korkeus sen mukaan, mihin suihku osuu (pehmeä siirtymä).
func _sound(db: float, pitch: float) -> void:
	if _stream == null:
		return
	_stream.volume_db = lerpf(_stream.volume_db, db, 0.2)
	_stream.pitch_scale = lerpf(_stream.pitch_scale, pitch, 0.2)


## Pisteen etäisyys ellipsin keskeltä suhteessa ellipsiin (<= 1 sisällä).
func _ellipse(p: Vector2, r: Vector2) -> float:
	return pow(p.x / r.x, 2.0) + pow(p.y / r.y, 2.0)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _stream != null:
		_stream.stop()
	var ended: bool = (mode == "ykkonen" and _total >= PEE_TIME - 0.05) or (mode == "kakkonen" and _phase == "paper" and _sheets > 0)
	if ended:
		if flush:
			Sfx.play("water", -2.0, 0.55, 2.5)  # vesi vedetään
		else:
			Sfx.play("door_close", -6.0, 1.3)  # huussin luukku kiinni
	var res := {}
	if mode == "ykkonen":
		res.accuracy = _inside / maxf(_total, 0.01)
		res.puddles = _puddles.size()
		res.done = _total >= PEE_TIME - 0.05
	else:
		res.pushes = _pushes
		res.hard = _hard
		res.weak = _weak
		res.sheets = _sheets
		res.clog = flush and _sheets >= PAPER_CLOG
		res.done = _phase == "paper" and _sheets > 0
	finished.emit(mode, res)
	queue_free()


func _draw_root() -> void:
	var sz := _root.size
	var c := sz / 2.0 + Vector2(0, 30)
	var t := Time.get_ticks_msec() / 1000.0
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.55))
	var room := Rect2(c - Vector2(360, 260), Vector2(720, 520))
	_box(room.grow(8.0), Color(0.12, 0.12, 0.13), 14, Color(0, 0, 0, 0.5), 18)
	if flush:
		# Lattia: vaaleat laatat, hieman eri sävyjä ja tummempi sauma.
		_root.draw_rect(room, Color(0.66, 0.68, 0.7))
		for i in 10:
			for j in 8:
				var tile := Rect2(room.position + Vector2(i * 72 + 2, j * 72 + 2), Vector2(68, 68)).intersection(room)
				var v := 0.03 * sin(i * 12.9 + j * 7.3)
				_root.draw_rect(tile, Color(0.84 + v, 0.86 + v, 0.87 + v))
				_root.draw_rect(Rect2(tile.position, Vector2(tile.size.x, 6)), Color(1, 1, 1, 0.12))
	else:
		# Huussin lankkulattia: lankut syineen ja nauloineen.
		for i in 8:
			var plank := Rect2(room.position + Vector2(0, i * 65), Vector2(room.size.x, 63))
			_root.draw_rect(plank, Color(0.5, 0.35, 0.2).darkened(0.05 * (i % 3)))
			for k in 4:
				var y := plank.position.y + 12 + k * 13 + 3.0 * sin(i * 3.1 + k)
				_root.draw_line(Vector2(plank.position.x, y), Vector2(plank.end.x, y + 4.0 * sin(i + k)), Color(0.35, 0.22, 0.12, 0.35), 2.0)
			for x in [24.0, room.size.x - 24.0]:
				_root.draw_circle(plank.position + Vector2(x, 31), 4.0, Color(0.25, 0.25, 0.27))
	# Varjo pöntön alla.
	_ellipse_fill(c + Vector2(14, 18), BOWL + Vector2(40, 40), Color(0, 0, 0, 0.22))
	if flush:
		# Vesisäiliö kannella ja huuhtelunapilla.
		var tank := Rect2(c + Vector2(-125, -BOWL.y - 128), Vector2(250, 100))
		_box(tank.grow(4.0), Color(0, 0, 0, 0.0), 16, Color(0, 0, 0, 0.3), 10)
		_box(tank, Color(0.93, 0.94, 0.95), 16)
		_box(Rect2(tank.position + Vector2(10, 8), Vector2(tank.size.x - 20, 40)), Color(0.98, 0.98, 0.99), 12)
		_root.draw_circle(tank.get_center() + Vector2(0, -22), 15.0, Color(0.72, 0.74, 0.77))
		_root.draw_circle(tank.get_center() + Vector2(0, -22), 11.0, Color(0.85, 0.87, 0.9))
		# Saranat.
		for sx in [-60.0, 60.0]:
			_box(Rect2(c + Vector2(sx - 16, -BOWL.y - 34), Vector2(32, 18)), Color(0.8, 0.82, 0.85), 5)
		# Istuinrengas: ulkoreuna, varjostus sisäreunalle, kiilto.
		_ellipse_fill(c, BOWL + Vector2(26, 26), Color(0.86, 0.87, 0.88))
		_ellipse_fill(c + Vector2(0, -3), BOWL + Vector2(22, 22), Color(0.98, 0.98, 0.99))
		_ring(c + Vector2(-30, -40), BOWL + Vector2(6, 6), 0.25, 0.85, Color(1, 1, 1, 0.9), 3.0)
		# Kulhon sisäpinta tummuu syvemmälle.
		for k in 5:
			var f := k / 5.0
			_ellipse_fill(c + Vector2(0, 6 * f), BOWL.lerp(WATER, f), Color(0.9, 0.92, 0.93).darkened(0.1 * f))
		# Vesi: syvyys, väreet ja heijastus.
		_ellipse_fill(c + Vector2(0, 8), WATER, Color(0.45, 0.66, 0.78))
		_ellipse_fill(c + Vector2(0, 14), WATER * 0.62, Color(0.36, 0.56, 0.7))
		_ring(c + Vector2(-20, -8), WATER * 0.75, 0.6, 1.4, Color(1, 1, 1, 0.45), 3.0)
	else:
		# Huussin penkki ja reikä.
		_box(Rect2(c - Vector2(BOWL.x + 70, BOWL.y + 70), (BOWL + Vector2(70, 70)) * 2.0), Color(0.58, 0.42, 0.26), 10, Color(0, 0, 0, 0.35), 12)
		_ellipse_fill(c, BOWL + Vector2(10, 10), Color(0.4, 0.28, 0.16))
		_ellipse_fill(c, BOWL, Color(0.1, 0.07, 0.05))
		_ellipse_fill(c + Vector2(0, 10), WATER, Color(0.05, 0.04, 0.03))
		_box(Rect2(c + Vector2(-BOWL.x - 40, -BOWL.y - 120), Vector2(BOWL.x * 2 + 80, 50)), Color(0.45, 0.32, 0.2), 6)  # kansi
	if mode == "ykkonen":
		for pd in _puddles:
			_ellipse_fill(c + pd, Vector2(13, 9), Color(0.95, 0.85, 0.25, 0.45))
			_root.draw_circle(c + pd + Vector2(-3, -2), 3.0, Color(1, 1, 1, 0.4))
		var tip := c + _aim
		var base := c + Vector2(0, 250)
		# Suihku: kaartuva, ohenee ja lepattaa.
		var pts := PackedVector2Array()
		for k in 13:
			var f := k / 12.0
			var bend := Vector2(sin(t * 9.0 + f * 6.0) * 4.0 * f, -40.0 * sin(f * PI))
			pts.append(base.lerp(tip, f) + bend)
		_root.draw_polyline(pts, Color(0.98, 0.88, 0.3, 0.55), 9.0, true)
		_root.draw_polyline(pts, Color(1.0, 0.95, 0.55, 0.9), 4.0, true)
		# Osumakohta: väreet vedessä, roiskeet muualla.
		var in_water := _ellipse(_aim, WATER) <= 1.0
		if in_water:
			for k in 3:
				var ph := fmod(t * 1.6 + k / 3.0, 1.0)
				_ring(tip, Vector2(10, 7) + Vector2(36, 24) * ph, 0.0, TAU, Color(1, 1, 1, 0.55 * (1.0 - ph)), 2.0)
		else:
			for k in 6:
				var a := t * 13.0 + k * 1.05
				_root.draw_circle(tip + Vector2(cos(a), sin(a) * 0.6) * (10 + 8 * sin(t * 20 + k)), 3.0, Color(1, 0.92, 0.45, 0.85))
		_root.draw_circle(tip, 8.0, Color(1.0, 0.95, 0.6))
		# Osumatarkkuus.
		var acc := _inside / maxf(_total, 0.01)
		_meter_h(Rect2(c + Vector2(-335, -225), Vector2(190, 18)), acc, Color(0.3, 0.8, 0.45), "Osumatarkkuus %d %%" % roundi(acc * 100.0))
		return
	# Kakkonen: ponnistusmittari (pystysuora, asteikolla) ja paperirulla seinätelineessä.
	var m := Rect2(c + Vector2(262, -200), Vector2(46, 400))
	_box(m.grow(6.0), Color(0.12, 0.12, 0.13), 10, Color(0, 0, 0, 0.4), 8)
	var steps := 40
	for k in steps:
		var f := (k + 0.5) / steps
		var col := Color(0.25, 0.35, 0.55)
		if f >= RED:
			col = Color(0.9, 0.22, 0.16)
		elif f >= GREEN.x and f <= GREEN.y:
			col = Color(0.3, 0.85, 0.4)
		elif f > GREEN.y:
			col = Color(0.95, 0.7, 0.2)
		_root.draw_rect(Rect2(Vector2(m.position.x, m.end.y - m.size.y * (k + 1) / steps + 1), Vector2(m.size.x, m.size.y / steps - 2)), col)
	var ny := m.end.y - m.size.y * _needle
	_root.draw_colored_polygon(PackedVector2Array([Vector2(m.position.x - 22, ny - 10), Vector2(m.position.x - 4, ny), Vector2(m.position.x - 22, ny + 10)]), Color.WHITE)
	_root.draw_rect(Rect2(Vector2(m.position.x - 4, ny - 2), Vector2(m.size.x + 8, 4)), Color(1, 1, 1, 0.9))
	# Ponnistukset kuvakkeina.
	for k in PUSHES:
		var pc := c + Vector2(-70 + k * 70, 0)
		if k < _pushes:
			_ellipse_fill(pc + Vector2(0, 6), Vector2(24, 14), Color(0.36, 0.24, 0.12))
			_ellipse_fill(pc, Vector2(18, 12), Color(0.45, 0.3, 0.15))
			_root.draw_circle(pc + Vector2(-5, -5), 4.0, Color(1, 1, 1, 0.25))
		else:
			_ring(pc, Vector2(18, 12), 0.0, TAU, Color(1, 1, 1, 0.25), 2.0)
	if _phase == "paper":
		# Seinäteline ja rulla; repäistyt arkit kasaan.
		var rc := c + Vector2(-305, -150)
		_box(Rect2(rc + Vector2(-60, -14), Vector2(120, 28)), Color(0.7, 0.72, 0.75), 8)
		_root.draw_circle(rc, 48.0, Color(0.85, 0.85, 0.83))
		_root.draw_circle(rc, 44.0, Color(0.98, 0.98, 0.96))
		_root.draw_circle(rc, 15.0, Color(0.72, 0.6, 0.42))
		_box(Rect2(rc + Vector2(-34, 40), Vector2(68, 52)), Color(0.98, 0.98, 0.96), 3)  # roikkuva pää
		for k in 6:
			_root.draw_line(rc + Vector2(-34 + k * 13, 92), rc + Vector2(-28 + k * 13, 92), Color(0.75, 0.75, 0.72), 2.0)
		for k in mini(_sheets, 14):
			var sp := c + Vector2(-300 + (k % 2) * 8, 40 + k * 13)
			_box(Rect2(sp, Vector2(70, 12)), Color(0.98, 0.98, 0.96), 2, Color(0, 0, 0, 0.2), 3)
		if flush and _sheets >= PAPER_CLOG:
			_root.draw_string(ThemeDB.fallback_font, c + Vector2(-120, -40), "TUKOSVAARA!", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.95, 0.3, 0.2))
	if _flash > 0.0:
		_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(_flash_col, _flash * 0.25))


func _ellipse_fill(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_root.draw_colored_polygon(pts, col)


## Ellipsin kaari (a0..a1 radiaaneina) viivana.
func _ring(c: Vector2, r: Vector2, a0: float, a1: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := lerpf(a0, a1, i / 32.0)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_root.draw_polyline(pts, col, w, true)


## Pyöristetty laatikko (valinnainen varjo).
func _box(r: Rect2, col: Color, radius: int, shadow := Color(0, 0, 0, 0), shadow_size := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.shadow_color = shadow
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(4, 6)
	sb.anti_aliasing = true
	_root.draw_style_box(sb, r)


## Vaakamittari tekstillä.
func _meter_h(r: Rect2, v: float, col: Color, text: String) -> void:
	_box(r.grow(4.0), Color(0.08, 0.08, 0.09, 0.9), 10)
	if v > 0.01:
		_box(Rect2(r.position, Vector2(r.size.x * clampf(v, 0.0, 1.0), r.size.y)), col, 8)
	_root.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, r.size.y + 22), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18,
		Color(0.15, 0.15, 0.17))
