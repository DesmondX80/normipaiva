extends CanvasLayer
## Oman mopon potkukäynnistys autotallissa (#155). Kylmä 70-luvun kaksitahtinen: rikastin päälle ([S]), potkun
## voima ladataan pitämällä [E] pohjassa (mittari heiluu ylös ja alas) ja potkaistaan päästämällä irti. Vihreällä
## potkulla kylmä kone köhäisee rikastimella; kahden köhäisyn jälkeen rikastin pois ja vielä yksi hyvä potku, niin
## mopo lähtee. Rikastin päällä liian kauan kastelee tulpan, punaisella potkupoljin potkaisee takaisin nilkkaan,
## ja Päivi kommentoi ikkunasta. Humalassa mittari heiluu arvaamattomasti. F / Esc lopettaa kesken.

signal finished(success: bool)
signal comment(text: String)

const MG := preload("res://scripts/mg_draw.gd")

const MAX_KICKS := 16
const GREEN := Vector2(0.62, 0.86)
const RED := 0.93
const COUGHS := 2
const PLAYER := {"skin": Color(0.95, 0.76, 0.66), "hair": "short", "hair_col": Color(0.2, 0.15, 0.1), "shirt": Color(0.42, 0.2, 0.62),
	"cap": true, "stripes": true}
const PAIVI := {"skin": Color(0.96, 0.8, 0.72), "hair": "long", "hair_col": Color(0.55, 0.32, 0.18), "shirt": Color(0.75, 0.3, 0.4)}
const PAIVI_LINES := ["Joko se romu lähtee, vai soitanko Pekalle?", "Naapurit luulee, että täällä teurastetaan jotain!",
	"Sää potkit tota kovemmin ku nurmikkoa koskaan leikkaat.", "Jos tuo lähtee käyntiin, mää syön hattuni.",
	"Oisit vaan ostanu bussikortin."]
const FAIL_LINES := ["Pöh.", "Ei mitään. Mopo katsoo sinua pettyneenä.", "Pöhöhö... ei.", "Kone hiljaa kuin Seppo maanantaina."]

var drunk := 0.0

var _root: Control
var _info: Label
var _keys: Control
var _t := 0.0
var _done := false
var _choke := false
var _coughs := 0
var _kicks := 0
var _charge := 0.0  # 0..1 potkun voima
var _phase := 0.0
var _holding := false
var _kick_anim := 0.0  # 1 -> 0: jalka alas, poljin painuu
var _shake := 0.0
var _smoke: Array = []  # [paikka, ikä, musta, koko]
var _sparks: Array = []
var _word := ""  # PÖH!, AIJAI!, PÖRPÖRPÖR
var _word_t := 0.0
var _paivi_t := 0.0
var _paivi_line := ""
var _running := false
var _run_t := 0.0
var _engine: AudioStreamPlayer
var _tip_t := 0.0


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
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
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
	comment.emit("Kylmä kone. Rikastin päälle (%s), ja potku vihreälle: pidä %s pohjassa ja päästä irti." % [
		Settings.action_key("back"), Settings.action_key("interact")])


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_root.queue_redraw()
	_word_t = maxf(0.0, _word_t - delta)
	_paivi_t = maxf(0.0, _paivi_t - delta)
	_kick_anim = maxf(0.0, _kick_anim - delta * 3.0)
	_shake = maxf(0.0, _shake - delta * 2.5)
	for s in _smoke:
		s[1] += delta
	_smoke = _smoke.filter(func(s): return s[1] < 2.0)
	MG.sparks_step(_sparks, delta)
	if _running:
		# Käy! Pörinä ja sininen kaksitahtisavu hetken, sitten valmis.
		_run_t += delta
		_shake = maxf(_shake, 0.25)
		_engine.pitch_scale = 1.3 + sin(_run_t * 13.0) * 0.08 + (0.6 if fmod(_run_t, 1.2) < 0.3 else 0.0)
		if randf() < delta * 10.0:
			_smoke.append([Vector2(randf_range(-4, 4), 0), 0.0, false, randf_range(0.8, 1.3)])
		if _run_t > 3.2:
			_finish(true)
		return
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish(false)
		return
	if Input.is_action_just_pressed("back"):
		_choke = not _choke
		Sfx.play("rattle", -10.0, 1.6)
		_word = "RIKASTIN %s" % ("PÄÄLLE" if _choke else "POIS")
		_word_t = 0.9
	# Potkun lataus: mittari heiluu ylös-alas (humalassa epätasaisesti), irti päästäessä potkaistaan.
	var hold := Input.is_action_pressed("interact")
	if hold:
		_holding = true
		var sp := 1.15 + drunk * (0.9 + sin(_t * 5.3) * 0.8)
		_phase += delta * sp
		_charge = 0.5 - 0.5 * cos(_phase * PI)
	elif _holding:
		_holding = false
		_kick(_charge)
		_charge = 0.0
		_phase = 0.0
	_tip_t -= delta
	if _tip_t <= 0.0 and _kicks > 0:
		_tip_t = 6.0
		if _coughs >= COUGHS and _choke:
			comment.emit("Köhii jo! Rikastin pois (%s) ja vielä yksi hyvä potku." % Settings.action_key("back"))
		elif not _choke and _coughs < COUGHS:
			comment.emit("Kylmä kone ei syty ilman rikastinta (%s)." % Settings.action_key("back"))
	_info.text = "Potkukäynnistys · potkuja %d / %d" % [_kicks, MAX_KICKS]
	_keys.set_text("%s potku (pidä ja päästä)   %s rikastin   %s lopeta" % [Settings.cap("interact"), Settings.cap("back"),
		Settings.cap("mount")])


func _kick(power: float) -> void:
	_kicks += 1
	_kick_anim = 1.0
	_shake = 0.35
	Sfx.play("rattle_hard", -6.0, randf_range(0.8, 1.0))
	if power >= RED:
		# Takaisinpotku nilkkaan.
		_word = "AIJAI!"
		_word_t = 1.2
		_shake = 1.0
		Sfx.play("grunt", -2.0, 0.9)
		comment.emit(["Potkupoljin potkaisi takaisin! Nilkka sanoo sanasen.", "AU! Liian kova potku, poljin palasi kuin bumerangi."].pick_random())
	elif power >= GREEN.x and power <= GREEN.y:
		if _coughs >= COUGHS and not _choke:
			_start()
			return
		if _coughs >= COUGHS and _choke:
			_coughs = 1
			_word = "PLÖRTS"
			_word_t = 1.0
			for i in 8:
				_smoke.append([Vector2(randf_range(-8, 8), randf_range(-4, 4)), randf() * 0.3, true, 1.4])
			comment.emit("Rikastin päällä liian kauan: tulppa kastui! Rikastin pois ja yritä uudestaan.")
		elif _choke:
			_coughs += 1
			_word = ["PÖH!", "PÖH-PÖH!"][mini(_coughs - 1, 1)]
			_word_t = 1.0
			Sfx.play("shotgun", -20.0, 2.6)
			for i in 4:
				_smoke.append([Vector2(randf_range(-6, 6), 0), randf() * 0.2, false, 1.0])
			comment.emit("Köhäisi! %s" % ("Vielä kerran." if _coughs < COUGHS else "Nyt rikastin pois (%s)." % Settings.action_key("back")))
		else:
			_word = FAIL_LINES[0]
			_word_t = 0.8
			comment.emit("Ei syty. Kylmä kone haluaa rikastimen.")
	elif power < 0.35:
		_word = "pöh"
		_word_t = 0.8
		comment.emit("Liian laimea potku. Mopo ei edes huomannut.")
	else:
		_word = FAIL_LINES.pick_random() if randf() < 0.5 else "Pöh."
		_word_t = 0.8
		comment.emit("Melkein. Potku vihreälle.")
	if _kicks in [4, 8, 12]:
		_paivi_line = PAIVI_LINES[(int(_kicks / 4.0) - 1 + randi() % 2) % PAIVI_LINES.size()]
		_paivi_t = 3.5
	if _kicks >= MAX_KICKS:
		comment.emit("Jalka ei enää nouse. Huomenna uudestaan.")
		_finish(false)


func _start() -> void:
	_running = true
	_word = "PÖRPÖRPÖR!"
	_word_t = 3.0
	_engine.play()
	Sfx.play("win_small", -4.0)
	MG.sparks_burst(_sparks, Vector2.ZERO, Color(0.6, 0.7, 1.0), 10)
	_paivi_line = "...No voi hyvä tavaton. Se lähti."
	_paivi_t = 3.0
	comment.emit("KÄY! Kaksitahtinen pärisee ja talli täyttyy sinisestä savusta.")


func _finish(success: bool) -> void:
	_done = true
	_engine.stop()
	finished.emit(success)
	queue_free()


# --- Piirto -------------------------------------------------------------------------------------

func _draw_root() -> void:
	var sz := _root.size
	var c := sz / 2.0 + Vector2(0, 30)
	var font := ThemeDB.fallback_font
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.55))
	var panel := Rect2(c - Vector2(470, 270), Vector2(940, 540))
	MG.box(_root, panel.grow(6), Color(0.12, 0.1, 0.09), 18, 16)
	var jit := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _shake
	# Takaseinä tiiltä ja betonilattia.
	var wall := Rect2(panel.position, Vector2(panel.size.x, panel.size.y * 0.68))
	MG.grad_rect(_root, wall, Color(0.82, 0.68, 0.48), Color(0.66, 0.52, 0.36))
	for row in int(wall.size.y / 26.0) + 1:
		var y := wall.position.y + row * 26.0
		_root.draw_line(Vector2(wall.position.x, y), Vector2(wall.end.x, y), Color(0.55, 0.42, 0.3, 0.6), 2.0)
		var off := 0.0 if row % 2 == 0 else 30.0
		var x := wall.position.x + off
		while x < wall.end.x:
			_root.draw_line(Vector2(x, y), Vector2(x, minf(y + 26.0, wall.end.y)), Color(0.55, 0.42, 0.3, 0.6), 2.0)
			x += 60.0
	var floor_r := Rect2(Vector2(panel.position.x, wall.end.y), Vector2(panel.size.x, panel.size.y - wall.size.y))
	MG.grad_rect(_root, floor_r, Color(0.55, 0.55, 0.53), Color(0.4, 0.4, 0.39))
	_root.draw_line(floor_r.position, floor_r.position + Vector2(floor_r.size.x, 0), Color(0.3, 0.28, 0.25), 3.0)
	_root.draw_colored_polygon(_ellipse(c + Vector2(-20, 200), Vector2(110, 22)), Color(0.15, 0.14, 0.12, 0.35))  # öljytahra
	# Ikkuna vasemmalla: Päivi kurkkii kommentoidessaan.
	var win := Rect2(panel.position + Vector2(40, 40), Vector2(170, 120))
	MG.box(_root, win.grow(8), Color(0.9, 0.9, 0.86), 4, 3, MG.OUTLINE, 2)
	MG.grad_rect(_root, win, Color(0.55, 0.75, 0.95), Color(0.8, 0.9, 0.98))
	_root.draw_line(win.position + Vector2(85, 0), win.position + Vector2(85, 120), Color(0.9, 0.9, 0.86), 6.0)
	_root.draw_line(win.position + Vector2(0, 60), win.position + Vector2(170, 60), Color(0.9, 0.9, 0.86), 6.0)
	if _paivi_t > 0.0:  # ikkuna auki, Päivi nojaa sisään
		MG.person(_root, win.position + Vector2(85, 72), 0.85, PAIVI, Vector2(1, 0.3), fmod(_t, 0.3) < 0.15)
	if _paivi_t > 0.0:
		MG.bubble(_root, Rect2(win.position + Vector2(190, -6), Vector2(470, 56)), win.position + Vector2(150, 60), _paivi_line, 20)
	# Työpöytä ja työkalutaulu oikealla takana.
	var bench := Rect2(panel.position + Vector2(640, 250), Vector2(280, 22))
	MG.wood(_root, Rect2(panel.position + Vector2(650, 120), Vector2(260, 110)), Color(0.75, 0.62, 0.42), 36.0, 7)
	for i in 6:
		var tx := panel.position.x + 675 + i * 40
		MG.solid(_root, Rect2(Vector2(tx, panel.position.y + 135 + (i % 2) * 12), Vector2(10, 60 - (i % 3) * 10)),
			[Color(0.3, 0.3, 0.32), Color(0.75, 0.12, 0.1), Color(0.85, 0.65, 0.1)][i % 3])
	MG.wood(_root, bench, Color(0.5, 0.35, 0.2), 22.0, 3)
	MG.solid(_root, Rect2(bench.position + Vector2(20, 22), Vector2(16, 90)), Color(0.4, 0.28, 0.16))
	MG.solid(_root, Rect2(bench.position + Vector2(244, 22), Vector2(16, 90)), Color(0.4, 0.28, 0.16))
	for i in 3:  # tyhjät kaljatölkit pöydällä
		MG.solid(_root, Rect2(bench.position + Vector2(150 + i * 26, -34), Vector2(18, 34)), Color(0.85, 0.75, 0.2))
	# Mopo sivulta: keula oikealle.
	var m := c + Vector2(-60, 120) + jit
	_draw_mopo(m)
	# Pelaaja mopon takana vasemmalla: ylävartalo, kädet tangossa ja potkujalka polkimella.
	var lift := _charge if _holding else 0.0
	var pc := m + Vector2(-150, -230 - lift * 18.0 + _kick_anim * 10.0)
	var pedal := _pedal_end(m, lift)
	var hip := pc + Vector2(14, 120)
	var knee := hip.lerp(pedal, 0.5) + Vector2(-38 + lift * -20.0, -30 - lift * 40.0)
	_root.draw_line(hip, knee, Color(0.12, 0.12, 0.16), 24.0)
	_root.draw_line(knee, pedal + Vector2(0, -10), Color(0.12, 0.12, 0.16), 22.0)
	_root.draw_circle(knee, 11.0, Color(0.12, 0.12, 0.16))
	MG.box(_root, Rect2(pedal + Vector2(-26, -20), Vector2(46, 18)), Color(0.95, 0.95, 0.95), 7, 0, MG.OUTLINE, 2)  # lenkkari
	_root.draw_line(pedal + Vector2(-22, -6), pedal + Vector2(16, -6), Color(0.1, 0.4, 0.8), 3.0)
	MG.person(_root, pc, 1.0, PLAYER, Vector2(1, 0.4), _word_t > 0.0 and _word == "AIJAI!")
	_root.draw_line(pc + Vector2(32, 44), m + Vector2(-20, -175), PLAYER.shirt.darkened(0.1), 14.0)  # käsi tankoon
	_root.draw_circle(m + Vector2(-20, -175), 8.0, PLAYER.skin)
	# Savu pakoputkesta (vasemmalla takana).
	var ex := m + Vector2(-175, -40)
	for s in _smoke:
		var age: float = s[1]
		var p: Vector2 = ex + s[0] + Vector2(-age * 60.0 + sin(age * 3.0) * 10.0, -age * 50.0)
		var col := Color(0.08, 0.08, 0.08, 0.75 * (1.0 - age / 2.0)) if s[2] else Color(0.65, 0.72, 0.9, 0.45 * (1.0 - age / 2.0))
		_root.draw_circle(p, (10.0 + age * 26.0) * s[3], col)
	MG.sparks_draw(_root, _sparks)
	if _word_t > 0.0:
		var a := clampf(_word_t * 2.0, 0.0, 1.0)
		var big := _word in ["PÖRPÖRPÖR!", "AIJAI!", "PLÖRTS"]
		_root.draw_string(font, m + Vector2(-260, 95 - (1.0 - a) * 20.0), _word, HORIZONTAL_ALIGNMENT_CENTER, 520, 52 if big else 36,
			Color(1, 0.85, 0.3, a) if _word != "AIJAI!" else Color(1, 0.35, 0.25, a))
	# Potkumittari oikealla: vihreä alue, punainen yläpää ja nykyinen voima.
	var g := Rect2(panel.position + Vector2(866, 300), Vector2(44, 200))
	MG.box(_root, g.grow(6), Color(0.08, 0.08, 0.09), 10, 4)
	var to_y := func(v: float) -> float: return g.end.y - g.size.y * v
	_root.draw_rect(Rect2(Vector2(g.position.x, to_y.call(GREEN.y)), Vector2(g.size.x, g.size.y * (GREEN.y - GREEN.x))), Color(0.3, 0.8, 0.4, 0.85))
	_root.draw_rect(Rect2(Vector2(g.position.x, g.position.y), Vector2(g.size.x, g.size.y * (1.0 - RED))), Color(0.9, 0.2, 0.15, 0.9))
	var cy: float = to_y.call(_charge)
	_root.draw_rect(Rect2(Vector2(g.position.x, cy), Vector2(g.size.x, g.end.y - cy)), Color(1, 0.85, 0.3, 0.55))
	_root.draw_line(Vector2(g.position.x - 8, cy), Vector2(g.end.x + 8, cy), Color.WHITE, 4.0)
	_root.draw_string(font, g.position + Vector2(-40, -14), "POTKU", HORIZONTAL_ALIGNMENT_CENTER, 124, 18, Color.WHITE)
	# Mittaripaneeli: rikastinvipu ja köhäisyt.
	var dash := Rect2(panel.position + Vector2(640, 318), Vector2(200, 192))
	MG.box(_root, dash, Color(0.12, 0.12, 0.13, 0.92), 12, 4, Color(0.45, 0.45, 0.48), 2)
	MG.sign(_root, Rect2(dash.position + Vector2(20, 14), Vector2(160, 36)), "RIKASTIN", Color(0.2, 0.22, 0.25), Color.WHITE, 20)
	var lever := dash.position + Vector2(100, 84)
	MG.box(_root, Rect2(lever + Vector2(-46, -8), Vector2(92, 16)), Color(0.3, 0.3, 0.32), 8)
	var knob := lever + Vector2(34 if _choke else -34, 0)
	MG.ball(_root, knob, 14.0, Color(0.85, 0.15, 0.1) if _choke else Color(0.55, 0.55, 0.58))
	_root.draw_string(font, lever + Vector2(-90, 34), "POIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE if not _choke else Color(0.6, 0.6, 0.6))
	_root.draw_string(font, lever + Vector2(30, 34), "PÄÄLLÄ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE if _choke else Color(0.6, 0.6, 0.6))
	var kr := dash.position + Vector2(16, 166)
	_root.draw_string(font, kr, "Köhäisyt", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	for i in COUGHS:
		MG.ball(_root, kr + Vector2(118 + i * 30, -6), 10.0, Color(0.95, 0.8, 0.2) if i < _coughs else Color(0.3, 0.3, 0.3), 0.6)


## Potkupolkimen pää: lepoasennossa vaakatasossa taaksepäin, ladatessa nousee ja potkussa painuu alas.
func _pedal_end(m: Vector2, lift: float) -> Vector2:
	var pivot := m + Vector2(-40, -78)
	var a := -0.15 - lift * 0.65 + _kick_anim * 0.9
	return pivot + Vector2(-70, 0).rotated(a)


func _draw_mopo(m: Vector2) -> void:
	var red := Color(0.72, 0.1, 0.07)
	var chrome := Color(0.78, 0.78, 0.8)
	var black := Color(0.07, 0.07, 0.08)
	# Varjo.
	_root.draw_colored_polygon(_ellipse(m + Vector2(0, 4), Vector2(250, 18)), Color(0, 0, 0, 0.3))
	# Pyörät: rengas, vanne, pinnat ja napa.
	for wx in [-150.0, 150.0]:
		var w := m + Vector2(wx, -62)
		_root.draw_circle(w, 62.0, black)
		_root.draw_arc(w, 56.0, 0, TAU, 40, Color(0.2, 0.2, 0.22), 4.0, true)
		_root.draw_circle(w, 44.0, chrome.darkened(0.15))
		_root.draw_circle(w, 40.0, Color(0.25, 0.22, 0.2))
		var spin := _t * (14.0 if _running else 0.0)
		for k in 12:
			var a := spin + k * TAU / 12.0
			_root.draw_line(w, w + Vector2(cos(a), sin(a)) * 40.0, chrome, 2.0)
		MG.ball(_root, w, 10.0, chrome, 0.6)
		# Lokasuoja.
		_root.draw_arc(w, 72.0, PI * 1.1, PI * 1.9, 20, chrome, 8.0, true)
	# Runko: putki etuhaarukasta moottorin alle ja takahaarukka.
	_root.draw_line(m + Vector2(150, -62), m + Vector2(110, -200), chrome, 9.0)  # etuhaarukka
	_root.draw_line(m + Vector2(105, -180), m + Vector2(-10, -90), red, 14.0)
	_root.draw_line(m + Vector2(-10, -90), m + Vector2(-150, -62), red.darkened(0.15), 10.0)
	_root.draw_line(m + Vector2(-60, -150), m + Vector2(-150, -62), red.darkened(0.15), 8.0)  # iskari
	_root.draw_line(m + Vector2(-60, -150), m + Vector2(-150, -62), chrome, 3.0)
	# Moottori ja sylinteri jäähdytysrivoineen.
	MG.solid(_root, Rect2(m + Vector2(-60, -120), Vector2(90, 62)), Color(0.32, 0.32, 0.34))
	for k in 5:
		MG.solid(_root, Rect2(m + Vector2(-4, -170 + k * 9), Vector2(46, 6)), Color(0.55, 0.55, 0.58), false)
	MG.solid(_root, Rect2(m + Vector2(4, -176), Vector2(30, 52)), Color(0.48, 0.48, 0.5))
	# Kaasari ja ilmanpuhdistin.
	MG.ball(_root, m + Vector2(-20, -128), 14.0, Color(0.6, 0.6, 0.62))
	# Pakoputki taakse.
	_root.draw_line(m + Vector2(-30, -70), m + Vector2(-170, -44), chrome.darkened(0.1), 14.0)
	_root.draw_line(m + Vector2(-30, -74), m + Vector2(-170, -48), chrome.lightened(0.2), 3.0)
	MG.box(_root, Rect2(m + Vector2(-180, -56), Vector2(18, 22)), Color(0.2, 0.2, 0.2), 4)
	# Tankki kiiltoineen ja tarra.
	var tank := PackedVector2Array([m + Vector2(-20, -205), m + Vector2(90, -215), m + Vector2(105, -180), m + Vector2(-10, -168)])
	_root.draw_colored_polygon(tank, red)
	_root.draw_polyline(tank + PackedVector2Array([tank[0]]), MG.OUTLINE, 2.0)
	_root.draw_line(m + Vector2(-5, -201), m + Vector2(80, -209), red.lightened(0.45), 4.0)
	_root.draw_string(ThemeDB.fallback_font, m + Vector2(10, -182), "HOPEANUOLI", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.9, 0.7))
	# Satula ja tavarateline.
	MG.box(_root, Rect2(m + Vector2(-125, -200), Vector2(110, 24)), black, 10, 0, MG.OUTLINE, 2)
	_root.draw_line(m + Vector2(-118, -196), m + Vector2(-30, -196), Color(0.3, 0.3, 0.32), 2.0)
	_root.draw_line(m + Vector2(-180, -150), m + Vector2(-125, -150), chrome, 5.0)
	_root.draw_line(m + Vector2(-178, -150), m + Vector2(-150, -100), chrome, 4.0)
	MG.box(_root, Rect2(m + Vector2(-196, -160), Vector2(16, 12)), Color(0.85, 0.1, 0.08), 3)  # takavalo
	# Ohjaustanko, peili ja ajovalo.
	_root.draw_line(m + Vector2(110, -200), m + Vector2(95, -232), chrome, 7.0)
	_root.draw_line(m + Vector2(95, -232), m + Vector2(-20, -178), chrome, 6.0)
	_root.draw_line(m + Vector2(98, -230), m + Vector2(110, -270), chrome, 3.0)
	MG.ball(_root, m + Vector2(112, -276), 10.0, chrome, 0.8)
	MG.ball(_root, m + Vector2(136, -196), 20.0, chrome, 0.6)
	_root.draw_circle(m + Vector2(146, -196), 12.0, Color(1.0, 0.95, 0.7) if _running else Color(0.7, 0.7, 0.62))
	if _running:
		MG.glow(_root, m + Vector2(156, -196), 60.0, Color(1.0, 0.95, 0.7, 0.8))
	# Potkupoljin.
	var pivot := m + Vector2(-40, -78)
	var lift := _charge if _holding else 0.0
	var tip := _pedal_end(m, lift)
	_root.draw_line(pivot, tip, Color(0.2, 0.2, 0.22), 9.0)
	_root.draw_line(tip, tip + Vector2(0, 10), Color(0.2, 0.2, 0.22), 9.0)
	MG.ball(_root, pivot, 8.0, chrome, 0.6)
	# Rekisterikilpi.
	MG.sign(_root, Rect2(m + Vector2(-206, -128), Vector2(48, 28)), "SPP-79", Color(0.95, 0.95, 0.95), Color.BLACK, 11, Color(0.2, 0.2, 0.2))


func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 24:
		var a := k * TAU / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
