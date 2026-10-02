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
	_info.text = "Ykkönen · pidä suihku pöntössä (WASD / nuolet tai hiiri) · %.0f s · F lopettaa" % maxf(0.0, PEE_TIME - _t)
	if _t >= PEE_TIME:
		_finish()


func _poo(delta: float) -> void:
	var press := Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("brake")
	if _phase == "push":
		_needle += _needle_dir * _needle_speed * delta * (1.0 + drunk * 0.6)
		if _needle > 1.0 or _needle < 0.0:
			_needle_dir = -_needle_dir
			_needle = clampf(_needle, 0.0, 1.0)
		_info.text = "Kakkonen · ponnista vihreällä (E / välilyönti) · %d / %d · F lopettaa" % [_pushes, PUSHES]
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
	_info.text = "Paperia: %d arkkia · E repäisee arkin · välilyönti valmis" % _sheets
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
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.5))
	# Lattialaatat ja pönttö ylhäältä.
	_root.draw_rect(Rect2(c - Vector2(360, 260), Vector2(720, 520)), Color(0.82, 0.84, 0.85))
	for i in 10:
		_root.draw_line(c + Vector2(-360 + i * 72, -260), c + Vector2(-360 + i * 72, 260), Color(0.7, 0.72, 0.74), 2.0)
	for j in 8:
		_root.draw_line(c + Vector2(-360, -260 + j * 72), c + Vector2(360, -260 + j * 72), Color(0.7, 0.72, 0.74), 2.0)
	if flush:
		_root.draw_rect(Rect2(c + Vector2(-110, -BOWL.y - 120), Vector2(220, 90)), Color(0.96, 0.96, 0.96))  # säiliö
	else:
		_root.draw_rect(Rect2(c - Vector2(360, 260), Vector2(720, 520)), Color(0.55, 0.38, 0.22, 0.85))  # huussin lauta
	_ellipse_fill(c, BOWL + Vector2(22, 22), Color(0.97, 0.97, 0.97) if flush else Color(0.45, 0.3, 0.18))
	_ellipse_fill(c, BOWL, Color(0.9, 0.92, 0.93) if flush else Color(0.12, 0.09, 0.06))
	_ellipse_fill(c, WATER, Color(0.55, 0.75, 0.85) if flush else Color(0.08, 0.06, 0.04))
	if mode == "ykkonen":
		for pd in _puddles:
			_root.draw_circle(c + pd, 9.0, Color(0.95, 0.88, 0.3, 0.7))
		var tip := c + _aim
		_root.draw_line(c + Vector2(0, 240), tip, Color(0.98, 0.9, 0.35, 0.85), 5.0)
		_root.draw_circle(tip, 10.0, Color(0.98, 0.9, 0.35))
		var acc := _inside / maxf(_total, 0.01)
		var bar := Rect2(c + Vector2(-150, 270), Vector2(300, 18))
		_root.draw_rect(bar, Color(0.1, 0.1, 0.1, 0.8))
		_root.draw_rect(Rect2(bar.position, Vector2(bar.size.x * acc, bar.size.y)), Color(0.4, 0.85, 0.5))
		return
	# Kakkonen: ponnistusmittari ja paperirulla.
	var m := Rect2(c + Vector2(260, -200), Vector2(40, 400))
	_root.draw_rect(m, Color(0.15, 0.15, 0.15))
	var g0 := m.end.y - m.size.y * GREEN.y
	_root.draw_rect(Rect2(Vector2(m.position.x, g0), Vector2(m.size.x, m.size.y * (GREEN.y - GREEN.x))), Color(0.3, 0.8, 0.4))
	_root.draw_rect(Rect2(m.position, Vector2(m.size.x, m.size.y * (1.0 - RED))), Color(0.85, 0.2, 0.15))
	var ny := m.end.y - m.size.y * _needle
	_root.draw_rect(Rect2(Vector2(m.position.x - 12, ny - 4), Vector2(m.size.x + 24, 8)), Color.WHITE)
	for k in PUSHES:
		_root.draw_circle(c + Vector2(-60 + k * 60, 0), 18.0, Color(0.45, 0.3, 0.15) if k < _pushes else Color(0, 0, 0, 0.15))
	if _phase == "paper":
		var rc := c + Vector2(-300, -120)
		_root.draw_circle(rc, 46.0, Color(0.97, 0.97, 0.95))
		_root.draw_circle(rc, 16.0, Color(0.7, 0.6, 0.45))
		for k in mini(_sheets, 14):
			_root.draw_rect(Rect2(rc + Vector2(-34, 50 + k * 14), Vector2(68, 12)), Color(0.98, 0.98, 0.96))
	if _flash > 0.0:
		_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(_flash_col, _flash * 0.25))


func _ellipse_fill(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_root.draw_colored_polygon(pts, col)
