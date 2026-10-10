extends CanvasLayer
## Tanssit Saloisten seuraintalolla (#129): pari tanssii salin lattialla, lavalla Saloisten Saapasjalat. Askeleet
## A ja D vuorotellen tahdissa: nuotit liukuvat kohti osumarengasta, ja painallus osuman hetkellä vie paria eteenpäin.
## Väärä näppäin tai ohi tahdin: kompastus ("Auts, varpaat!"). Humala levittää ikkunaa mutta heiluttaa nuotteja.
## Kappale kestää SONG sekuntia. F / Esc lopettaa kesken (tulos tähän asti). finished(score 0..1).

signal finished(score: float)

const MG := preload("res://scripts/mg_draw.gd")
const BPM := 112.0
const SONG := 24.0
const WINDOW := 0.15
const LEAD := 1.6  # sekuntia, jonka nuotti näkyy ennen osumaa
const SONGS := ["Saapasjalkavalssi", "Seuraintalon humppa", "Tokolan tango", "Saloisten letkajenkka"]
const PARTNER := {
	"sinikka_seura": {"name": "Sinikka", "look": {"skin": Color(0.97, 0.8, 0.72), "hair": "long", "hair_col": Color(0.85, 0.65, 0.3),
		"shirt": Color(0.9, 0.35, 0.55)}, "hit": ["Hyvin viet!", "Ooh, sää osaat!", "Lähemmäs vaan..."], "miss": ["Auts, varpaat!", "Hups!"]},
	"hilkka": {"name": "Hilkka", "look": {"skin": Color(0.95, 0.8, 0.74), "hair": "buns", "hair_col": Color(0.88, 0.88, 0.88),
		"shirt": Color(0.55, 0.3, 0.45), "glasses": true}, "hit": ["Niin sitä ennen tanssittiin!", "Kevyt jalka!"],
		"miss": ["Varovasti, nuori mies!", "Lonkka, lonkka!"]},
	"annaliisa": {"name": "Anna-Liisa", "look": {"skin": Color(0.95, 0.8, 0.74), "hair": "buns", "hair_col": Color(0.55, 0.45, 0.35),
		"shirt": Color(0.75, 0.55, 0.6)}, "hit": ["Päivi ei kyllä tanssi näin hyvin.", "No kappas."],
		"miss": ["Tästä mää kerron Päiville!", "Auts! Kömpelö."]},
}
const ME := {"skin": Color(0.95, 0.76, 0.66), "hair": "short", "hair_col": Color(0.2, 0.15, 0.1), "shirt": Color(0.42, 0.2, 0.62), "cap": true, "stripes": true}

var partner := "hilkka"
var drunk := 0.0

var _root: Control
var _info: Label
var _keys: Control
var _done := false
var _t := -1.5  # alkulaskenta
var _beat := 60.0 / BPM
var _beats: Array = []  # [aika, "A"/"D", tila: 0 tulossa, 1 osui, 2 ohi]
var _hits := 0
var _misses := 0
var _say := ""
var _say_t := 0.0
var _stumble := 0.0
var _song := ""
var _sparks: Array = []
var _spin := 0.0


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	add_child(_root)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 24)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 7)
	_info.anchor_right = 1.0
	_info.offset_top = 24.0
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_info)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_song = SONGS.pick_random()
	var n := int(SONG / _beat)
	for i in n:
		_beats.append([1.0 + i * _beat, "A" if i % 2 == 0 else "D", 0])
	_say = "%s: \"%s\"" % [PARTNER[partner].name, ["Tanssitaanko?", "No niin, viepä sitten."].pick_random()]
	_say_t = 2.5


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_say_t -= delta
	_stumble = maxf(0.0, _stumble - delta)
	MG.sparks_step(_sparks, delta)
	_root.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish()
		return
	var win := WINDOW * (1.0 + drunk * 0.5)
	for key in [["left", "A"], ["right", "D"]]:
		if Input.is_action_just_pressed(key[0]):
			_press(key[1], win)
	for b in _beats:  # ohi menneet
		if b[2] == 0 and _t - b[0] > win:
			b[2] = 2
			_miss()
	_spin += delta * (2.0 if _stumble <= 0.0 else -1.0)
	if _t > SONG + 1.5:
		_finish()
	_info.text = "%s · %s · osumat %d, kompastukset %d" % [PARTNER[partner].name, _song, _hits, _misses]
	_keys.set_text("%s / %s askel tahdissa   %s lopeta" % [Settings.cap("left"), Settings.cap("right"), Settings.cap("mount")])


func _press(key: String, win: float) -> void:
	var best: Array = []
	var bd := 1e9
	for b in _beats:
		if b[2] == 0 and absf(b[0] - _t) < bd:
			bd = absf(b[0] - _t)
			best = b
	if best.is_empty() or bd > win * 2.0:
		_miss()
		return
	if bd <= win and best[1] == key:
		best[2] = 1
		_hits += 1
		MG.sparks_burst(_sparks, _hit_pos(), Color(1.0, 0.85, 0.3), 10)
		Sfx.play("pickup", -14.0, 1.6 if key == "A" else 1.8)
		if randf() < 0.18:
			_say = "%s: \"%s\"" % [PARTNER[partner].name, (PARTNER[partner].hit as Array).pick_random()]
			_say_t = 2.0
	else:
		best[2] = 2
		_miss()


func _miss() -> void:
	_misses += 1
	_stumble = 0.4
	Sfx.play("body_fall", -18.0, 1.6)
	if randf() < 0.35:
		_say = "%s: \"%s\"" % [PARTNER[partner].name, (PARTNER[partner].miss as Array).pick_random()]
		_say_t = 2.0


func _finish() -> void:
	if _done:
		return
	_done = true
	var total := float(maxi(1, _hits + _misses))
	finished.emit(clampf(_hits / maxf(total, float(_beats.size()) * 0.6), 0.0, 1.0))
	queue_free()


# --- Piirto -------------------------------------------------------------------

func _hit_pos() -> Vector2:
	return Vector2(_root.size.x * 0.5, _root.size.y * 0.86)


func _draw_root() -> void:
	var sz := _root.size
	var font := ThemeDB.fallback_font
	# Sali: vaalea paneliseinä, lava verhoineen ja viirit.
	MG.grad_rect(_root, Rect2(Vector2.ZERO, Vector2(sz.x, sz.y * 0.55)), Color(0.9, 0.84, 0.7), Color(0.75, 0.68, 0.55))
	for x in range(0, int(sz.x), 60):
		_root.draw_line(Vector2(x, 0), Vector2(x, sz.y * 0.55), Color(0.7, 0.62, 0.48), 2.0)
	var stage := Rect2(Vector2(sz.x * 0.2, sz.y * 0.1), Vector2(sz.x * 0.6, sz.y * 0.32))
	MG.grad_rect(_root, stage, Color(0.25, 0.1, 0.12), Color(0.12, 0.05, 0.06))
	for side in [0, 1]:
		var cx := stage.position.x - 30 if side == 0 else stage.end.x - 40
		for k in 5:
			MG.grad_rect(_root, Rect2(Vector2(cx + k * 14, stage.position.y - 8), Vector2(15, stage.size.y + 30)),
				Color(0.7, 0.1, 0.12) if k % 2 == 0 else Color(0.55, 0.06, 0.08), Color(0.35, 0.03, 0.05))
	MG.sign(_root, Rect2(Vector2(sz.x * 0.5 - 200, stage.position.y + 8), Vector2(400, 40)), "SALOISTEN SAAPASJALAT", Color(0.1, 0.1, 0.35), Color(1.0, 0.85, 0.3), 22)
	# Bändi heiluu tahdissa: haitari, kitara ja rummut.
	var bob := sin(_t * TAU * BPM / 60.0) * 3.0
	var band := [Vector2(0.36, 0.3), Vector2(0.5, 0.29), Vector2(0.64, 0.3)]
	var shirt := {"skin": Color(0.95, 0.76, 0.66), "shirt": Color(0.75, 0.1, 0.1), "hair": "parted", "hair_col": Color(0.25, 0.2, 0.15)}
	for k in 3:
		var p := Vector2(sz.x * band[k].x, sz.y * band[k].y + (bob if k != 1 else -bob))
		MG.person(_root, p, 0.55, shirt, Vector2.ZERO, false)
		match k:
			0:
				MG.solid(_root, Rect2(p + Vector2(-22, 22), Vector2(44, 30)), Color(0.75, 0.1, 0.12))
				for f in 5:
					_root.draw_line(p + Vector2(-20 + f * 9, 22), p + Vector2(-20 + f * 9, 52), Color(0.95, 0.95, 0.9), 2.0)
			1:
				_root.draw_circle(p + Vector2(4, 44), 16.0, Color(0.6, 0.3, 0.12))
				_root.draw_line(p + Vector2(4, 44), p + Vector2(-30, 14), Color(0.3, 0.18, 0.08), 5.0)
			2:
				MG.ball(_root, p + Vector2(0, 46), 20.0, Color(0.9, 0.9, 0.95), 0.4)
				_root.draw_circle(p + Vector2(-26, 30), 10.0, Color(0.85, 0.7, 0.2))
	for k in 16:  # viirit
		var x := k * sz.x / 15.0
		var y := sz.y * 0.05 + absf(sin(k * 0.6)) * 12.0
		_root.draw_colored_polygon(PackedVector2Array([Vector2(x - 14, y), Vector2(x + 14, y), Vector2(x, y + 24)]),
			[Color.RED, Color.YELLOW, Color(0.2, 0.5, 1.0), Color.WHITE][k % 4])
	# Lattia ja muut tanssijat taustalla.
	MG.wood(_root, Rect2(Vector2(0, sz.y * 0.55), Vector2(sz.x, sz.y * 0.45)), Color(0.62, 0.45, 0.28), 70.0, 11, false)
	for k in 4:
		var a := _t * 0.5 + k * TAU / 4.0
		var p := Vector2(sz.x * (0.5 + cos(a) * 0.38), sz.y * (0.6 + sin(a) * 0.04))
		var pl := {"skin": Color(0.94, 0.76, 0.68), "shirt": [Color(0.2, 0.3, 0.5), Color(0.5, 0.45, 0.35), Color(0.3, 0.45, 0.3), Color(0.45, 0.3, 0.2)][k],
			"hair": "short", "hair_col": Color(0.3, 0.22, 0.15)}
		var pr := {"skin": Color(0.97, 0.8, 0.72), "shirt": [Color(0.85, 0.3, 0.35), Color(0.4, 0.6, 0.85), Color(0.55, 0.25, 0.6), Color(0.9, 0.7, 0.2)][k],
			"hair": "long", "hair_col": Color(0.55, 0.4, 0.25)}
		MG.person(_root, p + Vector2(-16, 0), 0.5, pl)
		MG.person(_root, p + Vector2(16, 0), 0.5, pr)
	# Pelaaja ja pari keskellä: pyörivät tahdissa, kompastuessa nytkähtää.
	var c := Vector2(sz.x * 0.5, sz.y * 0.56)
	var sway := sin(_spin) * 26.0
	var jolt := Vector2(randf_range(-6, 6), randf_range(-3, 3)) * (_stumble / 0.4)
	var hop := absf(sin(_t * PI * BPM / 60.0)) * -8.0
	MG.person(_root, c + Vector2(-46 + sway, hop) + jolt, 1.05, ME, Vector2(1, 0), false)
	MG.person(_root, c + Vector2(46 + sway, hop) - jolt, 1.0, PARTNER[partner].look, Vector2(-1, 0), _say_t > 0.0)
	_root.draw_line(c + Vector2(-14 + sway, 60 + hop), c + Vector2(14 + sway, 60 + hop), Color(0.95, 0.78, 0.68), 10.0)  # kädet kiinni
	if _say_t > 0.0 and _say != "":
		MG.bubble(_root, Rect2(c + Vector2(80 + sway, -150), Vector2(360, 50)), c + Vector2(60 + sway, -40), _say, 20)
	# Nuottirata: nuotit liukuvat osumarenkaaseen.
	var hp := _hit_pos()
	MG.box(_root, Rect2(Vector2(sz.x * 0.1, hp.y - 34), Vector2(sz.x * 0.8, 68)), Color(0, 0, 0, 0.55), 30)
	_root.draw_arc(hp, 30.0, 0, TAU, 32, Color(1, 1, 1, 0.9), 4.0)
	for b in _beats:
		var dt: float = b[0] - _t
		if dt < -0.3 or dt > LEAD:
			continue
		var x := hp.x + dt / LEAD * sz.x * 0.38 * (-1.0 if b[1] == "A" else 1.0)
		var y := hp.y + sin(_t * 5.0 + b[0]) * drunk * 14.0
		var col := Color(0.35, 0.85, 1.0) if b[1] == "A" else Color(1.0, 0.6, 0.3)
		if b[2] == 1:
			col = Color(0.4, 1.0, 0.5, 0.5)
		elif b[2] == 2:
			col = Color(1.0, 0.25, 0.2, 0.5)
		MG.ball(_root, Vector2(x, y), 22.0, col, 0.5)
		_root.draw_string(font, Vector2(x - 12, y + 9), b[1], HORIZONTAL_ALIGNMENT_CENTER, 24, 24, Color(0.1, 0.1, 0.1))
	if _t < 0.0:
		_root.draw_string(font, Vector2(0, sz.y * 0.5), str(ceili(-_t)), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 80, Color(1.0, 0.9, 0.3))
	MG.sparks_draw(_root, _sparks)
