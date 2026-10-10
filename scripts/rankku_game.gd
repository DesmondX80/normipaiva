extends CanvasLayer
## Rankkarit Saloisten kentällä (#116): viisi laukausta ja viisi torjuntaa poikia vastaan vuorotellen.
## Laukaus: tähtäin heiluu maalin leveydellä, välilyönti lukitsee suunnan, sitten korkeuden ja lyö. Kulmiin
## tähdätty pallo on vaikea torjua, mutta liian laaja menee ohi. Torjunta: potkija juoksee, ja hetkeä ennen potkua
## lantio kääntyy siihen suuntaan, mihin pallo menee (useimmiten); A / S / D heittäytyy vasemmalle, keskelle tai
## oikealle. F / Esc luovuttaa. finished(oma, pojat).

signal finished(mine: int, theirs: int)

const MG := preload("res://scripts/mg_draw.gd")
const ROUNDS := 5
const KID_LOOKS := [
	{"skin": Color(0.95, 0.8, 0.7), "hair": "short", "hair_col": Color(0.6, 0.45, 0.2), "shirt": Color(0.9, 0.2, 0.15)},
	{"skin": Color(0.95, 0.8, 0.7), "hair": "short", "hair_col": Color(0.3, 0.2, 0.12), "shirt": Color(0.15, 0.4, 0.85)},
	{"skin": Color(0.92, 0.76, 0.66), "hair": "short", "hair_col": Color(0.85, 0.75, 0.4), "shirt": Color(0.95, 0.8, 0.15)},
]
const TAUNTS := ["\"Ei se ees osaa potkasta!\"", "\"Mun mummo potkas kovempaa!\"", "\"Kato nyt, äijä on ihan punanen.\"",
	"\"Viimenen mahollisuus, setä!\""]

var drunk := 0.0

var _root: Control
var _info: Label
var _tip: Label
var _keys: Control
var _round := 0  # 0..9: parilliset laukauksia, parittomat torjuntoja
var _mine := 0
var _theirs := 0
var _phase := "intro"  # intro / aim_x / aim_y / flight / runup / dive / result / done
var _t := 0.0
var _aim := Vector2(0.0, 0.5)  # -1..1 vaaka, 0..1 korkeus (0 = maa)
var _ball_from := Vector2.ZERO  # ruudun koordinaatit
var _ball_to := Vector2.ZERO
var _ball_u := 0.0
var _keeper_dive := 0  # -1 / 0 / 1 (maalivahdin heittäytyminen)
var _keeper_u := 0.0
var _kick_dir := 0  # torjunnassa pallon suunta
var _tell := 0  # potkijan lantion suunta
var _goal := false
var _net := 0.0
var _shake := 0.0
var _sparks: Array = []
var _results: Array = []  # [oma laukaus/torjunta, maali]


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	add_child(_root)
	_info = _label(26, 18.0, false)
	_tip = _label(24, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_tip.text = "Pojat: \"Viis rankkaria kumpikin. Sää aloitat, setä.\""


func _label(size: int, y: float, bottom: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.anchor_right = 1.0
	if bottom:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _shooting() -> bool:
	return _round % 2 == 0


## Maalin suorakaide ruudulla.
func _goal_rect() -> Rect2:
	var sz := _root.size
	var w := sz.x * (0.5 if _shooting() else 0.62)
	var h := w * 0.33
	return Rect2(Vector2((sz.x - w) / 2.0, sz.y * (0.3 if _shooting() else 0.36)), Vector2(w, h))


func _goal_point(a: Vector2) -> Vector2:
	var g := _goal_rect()
	return Vector2(g.position.x + (a.x + 1.0) / 2.0 * g.size.x, g.end.y - a.y * g.size.y)


func _process(delta: float) -> void:
	_t += delta
	_net = maxf(0.0, _net - delta * 2.0)
	_shake = maxf(0.0, _shake - delta * 3.0)
	MG.sparks_step(_sparks, delta)
	_root.queue_redraw()
	if _phase == "done":
		return
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish("Luovutit. Pojat: \"Setä lähti itkemään!\"")
		return
	_info.text = "Rankkarit  %d – %d  ·  kierros %d/%d" % [_mine, _theirs, mini(_round / 2 + 1, ROUNDS), ROUNDS]
	var sp := Input.is_action_just_pressed("jump")
	match _phase:
		"intro":
			if _t > 1.6:
				_start_round()
		"aim_x":
			var spd := 1.6 + drunk * 1.2
			_aim.x = sin(_t * spd) * 1.25 + sin(_t * 7.0) * drunk * 0.15
			if sp:
				_phase = "aim_y"
				_t = 0.0
		"aim_y":
			_aim.y = 0.55 + sin(_t * 2.2) * 0.62
			if sp:
				_kick()
		"flight":
			_ball_u = minf(1.0, _ball_u + delta * 2.4)
			_keeper_u = minf(1.0, _keeper_u + delta * 3.0)
			if _ball_u >= 1.0:
				_resolve()
		"runup":
			if _t > 1.1 and _tell == 2:
				_tell = _kick_dir if randf() < 0.75 else [-1, 0, 1].pick_random()
			if _t > 1.9:
				_phase = "dive"
				_t = 0.0
				_ball_u = 0.0
				_ball_from = Vector2(_root.size.x / 2.0, _root.size.y * 0.66)
				_ball_to = Vector2(_root.size.x / 2.0 + _kick_dir * _root.size.x * 0.33, _root.size.y * randf_range(0.42, 0.6))
				_keeper_dive = 2  # ei vielä heittäytynyt
				Sfx.play("thud", -4.0, 1.1)
			for k in [["left", -1], ["back", 0], ["right", 1]]:
				if Input.is_action_just_pressed(k[0]):
					_tip.text = "Liian aikaisin! Potkija näki sen."
					_keeper_dive = k[1]
					_kick_dir = [-1, 0, 1].filter(func(d): return d != k[1]).pick_random()
		"dive":
			_ball_u = minf(1.0, _ball_u + delta * 1.9)
			if _keeper_dive == 2:
				for k in [["left", -1], ["back", 0], ["right", 1]]:
					if Input.is_action_just_pressed(k[0]):
						_keeper_dive = k[1]
						_keeper_u = 0.0
			if _keeper_dive != 2:
				_keeper_u = minf(1.0, _keeper_u + delta * 4.0)
			if _ball_u >= 1.0:
				_resolve()
		"result":
			if _t > 1.7:
				_round += 1
				if _round >= ROUNDS * 2 or _decided():
					var txt := "VOITIT %d – %d! Pojat: \"Ens kerralla, setä...\"" % [_mine, _theirs] if _mine > _theirs else \
						("Tasapeli %d – %d. Pojat: \"Ensi kerralla ratkastaan.\"" % [_mine, _theirs] if _mine == _theirs else
						"Hävisit %d – %d. Pojat nauraa koko matkan kotiin." % [_mine, _theirs])
					_finish(txt)
				else:
					_start_round()
	_keys.set_text(("%s lukitse tähtäin" % Settings.cap("jump")) if _shooting() else
		("%s / %s / %s heittäydy vasemmalle / keskelle / oikealle" % [Settings.cap("left"), Settings.cap("back"), Settings.cap("right")]))


## Ratkesiko ennen viidettä kierrosta (toinen ei voi enää kiriä)?
func _decided() -> bool:
	var shots_left := ROUNDS - (_round + 1) / 2
	var saves_left := ROUNDS - _round / 2
	return _mine > _theirs + saves_left or _theirs > _mine + shots_left


func _start_round() -> void:
	_t = 0.0
	_ball_u = 0.0
	_keeper_u = 0.0
	_goal = false
	if _shooting():
		_phase = "aim_x"
		_aim = Vector2(0.0, 0.5)
		_keeper_dive = 0
		_tip.text = "Sinun laukauksesi. Tähtää kulmaan, mutta ei ohi."
	else:
		_phase = "runup"
		_kick_dir = [-1, 0, 1].pick_random()
		_tell = 2
		_keeper_dive = 2
		_tip.text = "Sinä maalissa. Katso potkijan lantiota..."


func _kick() -> void:
	_phase = "flight"
	_t = 0.0
	_ball_u = 0.0
	_ball_from = Vector2(_root.size.x / 2.0, _root.size.y * 0.86)
	_ball_to = _goal_point(_aim)
	# Maalivahti arvaa: kulmiin tähdätty jää useammin kiinni ottamatta.
	var guess: int = [-1, 0, 1].pick_random()
	if randf() < 0.35:
		guess = signi(roundi(_aim.x * 1.4))
	_keeper_dive = guess
	_keeper_u = 0.0
	Sfx.play("thud", -2.0, 0.9)


func _resolve() -> void:
	_phase = "result"
	_t = 0.0
	if _shooting():
		var wide := absf(_aim.x) > 1.0 or _aim.y > 1.0 or _aim.y < 0.0
		var zone := 0 if absf(_aim.x) < 0.35 else signi(roundi(_aim.x * 10))
		var reach := 0.9 if zone == _keeper_dive else 0.0
		if zone == _keeper_dive and absf(_aim.x) > 0.75:
			reach = 0.35  # aivan kulmassa sormenpäät ei riitä
		if wide:
			_goal = false
			_tip.text = ["OHI! Pallo lensi aidan yli.", "Tolppaan ja ulos! KLONK."][int(absf(_aim.x) < 1.08)]
			Sfx.play("thud", -2.0, 0.6)
		elif randf() < reach:
			_goal = false
			_tip.text = "TORJUTTU! " + TAUNTS.pick_random()
			Sfx.play("whoosh", -4.0)
		else:
			_goal = true
			_mine += 1
			_net = 1.0
			_shake = 0.6
			MG.sparks_burst(_sparks, _ball_to, Color(1.0, 0.95, 0.5), 22)
			_tip.text = ["MAALI!", "MAALI! Suoraan yläkulmaan!", "MAALI! Maalivahti meni väärään suuntaan."][randi() % 3]
			Sfx.play("win_small", -4.0)
	else:
		var saved := _keeper_dive == _kick_dir
		if saved:
			_goal = false
			_shake = 0.5
			MG.sparks_burst(_sparks, _ball_to, Color(0.6, 0.9, 1.0), 22)
			_tip.text = ["TORJUIT! Pojat on hiljaa.", "TORJUNTA! Nyrkillä pois!", "Sormenpäillä! Ei mene!"][randi() % 3]
			Sfx.play("win_small", -4.0)
		else:
			_goal = true
			_theirs += 1
			_net = 1.0
			_tip.text = "Maali. " + TAUNTS.pick_random()
			Sfx.play("thud", -4.0, 0.7)
	_results.append([_shooting(), _goal])


func _finish(text: String) -> void:
	_phase = "done"
	_tip.text = text
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		finished.emit(_mine, _theirs)
		queue_free())


# --- Piirto -------------------------------------------------------------------

func _draw_root() -> void:
	var sz := _root.size
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 10.0
	_root.draw_set_transform(sh, 0.0, Vector2.ONE)
	# Taivas, metsänreuna ja valomastot.
	MG.grad_rect(_root, Rect2(Vector2.ZERO, Vector2(sz.x, sz.y * 0.4)), Color(0.45, 0.68, 0.92), Color(0.82, 0.9, 0.95))
	for k in 18:
		var x := k * sz.x / 17.0
		var th := 90.0 + float((k * 37) % 50)
		_root.draw_colored_polygon(PackedVector2Array([Vector2(x - 40, sz.y * 0.4), Vector2(x, sz.y * 0.4 - th), Vector2(x + 40, sz.y * 0.4)]),
			Color(0.15, 0.35, 0.18).darkened((k % 3) * 0.1))
	for mx in [0.08, 0.92]:
		_root.draw_rect(Rect2(Vector2(sz.x * mx - 4, sz.y * 0.04), Vector2(8, sz.y * 0.36)), Color(0.55, 0.56, 0.58))
		MG.box(_root, Rect2(Vector2(sz.x * mx - 30, sz.y * 0.02), Vector2(60, 26)), Color(0.3, 0.3, 0.32), 4)
	# Nurmi raidoin ja viivat.
	for k in 8:
		var y0 := sz.y * 0.4 + k * sz.y * 0.6 / 8.0
		_root.draw_rect(Rect2(Vector2(0, y0), Vector2(sz.x, sz.y * 0.6 / 8.0 + 1)), Color(0.3, 0.58, 0.22) if k % 2 == 0 else Color(0.34, 0.63, 0.25))
	if _shooting():
		_draw_shoot_view(sz)
	else:
		_draw_save_view(sz)
	# Tähtäin.
	if _phase in ["aim_x", "aim_y"]:
		var ap := _goal_point(Vector2(_aim.x, _aim.y if _phase == "aim_y" else 0.5))
		var col := Color(1.0, 0.3, 0.2) if absf(_aim.x) > 1.0 or _aim.y > 1.0 or _aim.y < 0.0 else Color(1.0, 0.95, 0.3)
		_root.draw_arc(ap, 18.0, 0, TAU, 24, col, 4.0)
		_root.draw_line(ap - Vector2(26, 0), ap + Vector2(26, 0), col, 2.0)
		_root.draw_line(ap - Vector2(0, 26), ap + Vector2(0, 26), col, 2.0)
	MG.sparks_draw(_root, _sparks)
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Tulostaulu.
	var board := Rect2(Vector2(sz.x - 300, 70), Vector2(270, 96))
	MG.box(_root, board, Color(0.08, 0.08, 0.1), 8, 6, Color(0.6, 0.6, 0.6), 2)
	var font := ThemeDB.fallback_font
	_root.draw_string(font, board.position + Vector2(14, 34), "SINÄ", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.3))
	_root.draw_string(font, board.position + Vector2(14, 76), "POJAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.3))
	var mi := 0
	var ti := 0
	for r in _results:
		var col := mi if r[0] else ti
		if r[0]:
			mi += 1
		else:
			ti += 1
		var good: bool = r[1] if r[0] else not r[1]  # oma maali tai oma torjunta
		_root.draw_circle(board.position + Vector2(110 + col * 30, 26.0 if r[0] else 68.0), 10.0,
			Color(0.3, 0.9, 0.3) if good else Color(0.9, 0.25, 0.2))


## Laukaus: maali edessä, poika maalissa, pallo pilkulla ruudun alareunassa.
func _draw_shoot_view(sz: Vector2) -> void:
	var g := _goal_rect()
	_root.draw_line(Vector2(0, g.end.y + 2), Vector2(sz.x, g.end.y + 2), Color(0.95, 0.95, 0.9), 4.0)
	_root.draw_rect(Rect2(Vector2(g.position.x - g.size.x * 0.4, g.end.y), Vector2(g.size.x * 1.8, sz.y * 0.16)), Color(0.95, 0.95, 0.9), false, 4.0)
	var bulge := _net * 18.0
	var net_col := Color(0.92, 0.92, 0.92, 0.55)
	for i in 13:
		var x := g.position.x + i * g.size.x / 12.0
		_root.draw_line(Vector2(x, g.position.y - bulge * 0.3), Vector2(x + (x - g.get_center().x) * 0.05, g.end.y - 6), net_col, 1.5)
	for j in 6:
		var y := g.position.y + j * g.size.y / 5.0
		_root.draw_line(Vector2(g.position.x, y), Vector2(g.end.x, y + bulge * sin(j * 0.6)), net_col, 1.5)
	var post := Color(0.98, 0.98, 0.98)
	_root.draw_rect(Rect2(g.position + Vector2(-8, -8), Vector2(g.size.x + 16, 10)), post)
	_root.draw_rect(Rect2(g.position + Vector2(-8, -8), Vector2(10, g.size.y + 8)), post)
	_root.draw_rect(Rect2(Vector2(g.end.x - 2, g.position.y - 8), Vector2(10, g.size.y + 8)), post)
	var kd := float(_keeper_dive)
	var kp := Vector2(g.get_center().x + kd * _keeper_u * g.size.x * 0.32, g.end.y - g.size.y * 0.45 - absf(kd) * _keeper_u * 10.0)
	MG.person(_root, kp, g.size.y / 150.0, KID_LOOKS[0].merged({"shirt": Color(0.2, 0.2, 0.22)}), Vector2(kd, 0), false,
		1.0 if _keeper_u > 0.2 else 0.4)
	var bp := _ball_from.lerp(_ball_to, _ball_u)
	var br := lerpf(30.0, 10.0, _ball_u)
	var arc := sin(_ball_u * PI) * 40.0
	if _phase in ["aim_x", "aim_y", "intro"]:
		bp = Vector2(sz.x / 2.0, sz.y * 0.86)
		br = 30.0
	_root.draw_circle(Vector2(bp.x, bp.y + br * 0.9 + arc * 0.2), br * 0.9, Color(0, 0, 0, 0.25))
	_draw_ball(bp - Vector2(0, arc), br)


## Torjunta maalivahdin silmin: tolpat ja rima ruudun reunoilla, potkija juoksee pilkulle, pallo lentää kohti ja
## hanskat heittäytyvät.
func _draw_save_view(sz: Vector2) -> void:
	var line := Color(0.95, 0.95, 0.9)
	# Rangaistusalue perspektiivissä ja pilkku.
	_root.draw_line(Vector2(sz.x * 0.22, sz.y * 0.47), Vector2(sz.x * 0.78, sz.y * 0.47), line, 3.0)
	_root.draw_line(Vector2(sz.x * 0.22, sz.y * 0.47), Vector2(-sz.x * 0.1, sz.y * 0.95), line, 4.0)
	_root.draw_line(Vector2(sz.x * 0.78, sz.y * 0.47), Vector2(sz.x * 1.1, sz.y * 0.95), line, 4.0)
	_root.draw_circle(Vector2(sz.x / 2.0, sz.y * 0.672), 5.0, line)
	# Potkija: juoksee vinosti pallolle, lantio kääntyy (vihje).
	var run := clampf(_t / 1.9, 0.0, 1.0) if _phase == "runup" else 1.0
	var kc := Vector2(sz.x / 2.0 - 120.0 + run * 100.0, sz.y * 0.42 + run * 30.0)
	var lean := 0.0 if _tell == 2 else float(_tell)
	MG.person(_root, kc, 0.9 + run * 0.15, KID_LOOKS[(_round / 2) % 3], Vector2(lean, 0.3), _phase == "runup" and run < 0.4)
	if _tell != 2 and _phase == "runup":
		_root.draw_line(kc + Vector2(-26, 96), kc + Vector2(26 + lean * 40.0, 96), Color(1, 1, 1, 0.6), 5.0)
	# Pallo: pilkulla, sitten kohti ruutua.
	var bp := Vector2(sz.x / 2.0, sz.y * 0.66)
	var br := 12.0
	if _phase in ["dive", "result"]:
		bp = _ball_from.lerp(_ball_to, _ball_u)
		br = lerpf(12.0, 70.0, _ball_u * _ball_u)
	_root.draw_circle(bp + Vector2(0, br * 0.9), br * 0.8, Color(0, 0, 0, 0.2))
	_draw_ball(bp, br)
	# Maalikehikko reunoilla ja verkko kulmissa.
	var post := Color(0.98, 0.98, 0.98)
	var net := Color(0.95, 0.95, 0.95, 0.35)
	for k in 6:
		_root.draw_line(Vector2(0, k * 40.0), Vector2(60.0 - k * 6.0, 0), net, 1.5)
		_root.draw_line(Vector2(sz.x, k * 40.0), Vector2(sz.x - 60.0 + k * 6.0, 0), net, 1.5)
	_root.draw_rect(Rect2(Vector2(14, 0), Vector2(30, sz.y * 0.92)), post)
	_root.draw_rect(Rect2(Vector2(sz.x - 44, 0), Vector2(30, sz.y * 0.92)), post)
	_root.draw_rect(Rect2(Vector2(14, 0), Vector2(sz.x - 28, 26)), post)
	_root.draw_rect(Rect2(Vector2(14, 22), Vector2(sz.x - 28, 4)), Color(0, 0, 0, 0.15))
	# Hanskat.
	var kd := 0.0 if _keeper_dive == 2 else float(_keeper_dive)
	var shift := Vector2(kd * _keeper_u * sz.x * 0.33, -_keeper_u * (60.0 if kd != 0.0 else 120.0))
	for sx in [-1.0, 1.0]:
		var gp: Vector2 = Vector2(sz.x / 2.0 + sx * 170.0, sz.y * 0.86) + shift + Vector2(kd * sx * _keeper_u * 30.0, 0)
		_glove(gp, sx)


func _glove(c: Vector2, side: float) -> void:
	var palm := Rect2(c + Vector2(-48, -40), Vector2(96, 92))
	MG.box(_root, palm.grow(3), Color(0.1, 0.1, 0.1), 26)
	MG.box(_root, palm, Color(0.98, 0.55, 0.1), 24)
	for f in 4:  # sormet
		var fr := Rect2(c + Vector2(-44 + f * 23, -86), Vector2(20, 52))
		MG.box(_root, fr.grow(2), Color(0.1, 0.1, 0.1), 10)
		MG.box(_root, fr, Color(0.98, 0.6, 0.15), 9)
	var thumb := Rect2(c + Vector2(-side * 70 - 14, -30), Vector2(28, 48))
	MG.box(_root, thumb.grow(2), Color(0.1, 0.1, 0.1), 12)
	MG.box(_root, thumb, Color(0.98, 0.6, 0.15), 11)
	_root.draw_rect(Rect2(c + Vector2(-48, 30), Vector2(96, 22)), Color(0.15, 0.15, 0.18))  # ranneke
	_root.draw_rect(Rect2(c + Vector2(-48, 34), Vector2(96, 5)), Color(0.95, 0.95, 0.95))


func _draw_ball(c: Vector2, r: float) -> void:
	_root.draw_circle(c, r, Color(0.98, 0.98, 0.98))
	_root.draw_arc(c, r, 0, TAU, 24, Color(0.1, 0.1, 0.1), 2.0)
	var pent := PackedVector2Array()
	for k in 5:
		var a := -PI / 2.0 + k * TAU / 5.0 + _ball_u * 6.0
		pent.append(c + Vector2(cos(a), sin(a)) * r * 0.38)
	_root.draw_colored_polygon(pent, Color(0.1, 0.1, 0.1))
	_root.draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.18, Color(1, 1, 1, 0.8))
