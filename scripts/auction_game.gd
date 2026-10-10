extends CanvasLayer
## Huutokauppa Saloisten seuraintalon lavalla (#114): huutaja Erkki vilkuilee yleisöä vuorotellen, ja huuto menee
## läpi vain, kun hän katsoo sinua (E tai välilyönti). Kilpailijat (mummo ja ukko) huutavat omaan kattohintaansa asti.
## Jokaisen huudon jälkeen "ensimmäisen kerran, toisen kerran... kolmannen kerran!": viimeinen huutaja voittaa.
## Huuto ei voi ylittää rahoja. F / Esc luovuttaa. finished(won, price).

signal finished(won: bool, price: float)

const MG := preload("res://scripts/mg_draw.gd")

const SLOTS := 3  # 0 = mummo vasemmalla, 1 = sinä, 2 = ukko oikealla
const GAZE_MIN := 0.7
const GAZE_MAX := 1.3
const CALL_STEP := 1.5  # sekuntia per "kerta"
const CALLS := ["Ensimmäisen kerran...", "Toisen kerran...", "Kolmannen kerran... MYYTY!"]

var lot := "Napamoottori"
var start_price := 5.0
var step := 1.0
var money := 20.0
var drunk := 0.0
## Kilpailijat: [nimi, kattohinta] paikoille 0 ja 2.
var rivals := [["Mummo Elvi", 12.0], ["Ukko Veikkonen", 18.0]]

var _root: Control
var _info: Label
var _keys: Control
var _tip: Label
var _done := false
var _t := 0.0
var _price := 0.0
var _leader := -1  # -1 = kukaan ei ole huutanut
var _gaze := 0
var _gaze_t := 1.0
var _call := -1  # -1 = ei laskentaa, 0..2 kerrat
var _call_t := 0.0
var _rival_t := -1.0  # kilpailijan huuto tulossa (viive)
var _flash := 0.0
var _flash_slot := -1
var _bang := 0.0  # nuijan isku (MYYTY)
var _sparks: Array = []
## Hahmot (mg_draw.gd person): mummo, pelaaja tuulipuvussa, ukko ja huutaja.
const LOOKS := [
	{"skin": Color(0.96, 0.8, 0.74), "hair": "buns", "hair_col": Color(0.88, 0.88, 0.88), "shirt": Color(0.6, 0.32, 0.5), "glasses": true},
	{"skin": Color(0.95, 0.76, 0.66), "hair": "short", "hair_col": Color(0.2, 0.15, 0.1), "shirt": Color(0.42, 0.2, 0.62), "cap": true, "stripes": true},
	{"skin": Color(0.94, 0.72, 0.62), "hair": "short", "hair_col": Color(0.6, 0.6, 0.58), "shirt": Color(0.32, 0.36, 0.26), "cap": true, "beard": true},
]
const ERKKI := {"skin": Color(0.96, 0.75, 0.66), "hair": "parted", "hair_col": Color(0.35, 0.28, 0.22), "shirt": Color(0.92, 0.92, 0.88), "tie": true}


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	add_child(_root)
	_info = _label(26, 40.0, false)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_tip = _label(24, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_price = start_price
	_tip.text = "Erkki: \"%s! Lähtöhinta %s euroa, kuka aloittaa?\"" % [lot, _eur(start_price)]


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


static func _eur(v: float) -> String:
	return ("%.2f" % v).replace(".", ",") if fmod(v, 1.0) != 0.0 else str(int(v))


func _next_price() -> float:
	return _price + step if _leader >= 0 else start_price


func _process(delta: float) -> void:
	_t += delta
	_bang = maxf(0.0, _bang - delta)
	MG.sparks_step(_sparks, delta)
	_root.queue_redraw()
	if _done:
		return
	_flash = maxf(0.0, _flash - delta)
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish(false)
		return
	# Huutajan katse vaeltaa; johtajaa hän ei juuri katso (etsii korkeampaa huutoa).
	_gaze_t -= delta
	if _gaze_t <= 0.0:
		var opts: Array = []
		for i in SLOTS:
			if i != _gaze and i != _leader:
				opts.append(i)
		_gaze = opts.pick_random() if not opts.is_empty() else (_gaze + 1) % SLOTS
		_gaze_t = randf_range(GAZE_MIN, GAZE_MAX) * (1.0 - drunk * 0.3)
		# Katse kilpailijaan: tämä huutaa, jos kattohinta sallii (pieni viive, ettei ole liian robotti).
		if _gaze != 1 and _gaze != _leader:
			var r: Array = rivals[0 if _gaze == 0 else 1]
			if _next_price() <= r[1] and randf() < 0.7:
				_rival_t = randf_range(0.25, 0.55)
	if _rival_t > 0.0:
		_rival_t -= delta
		if _rival_t <= 0.0 and _gaze != 1 and _gaze != _leader:
			var r: Array = rivals[0 if _gaze == 0 else 1]
			if _next_price() <= r[1]:
				_bid(_gaze)
				_tip.text = "%s nostaa kätensä. Erkki: \"%s euroa! Kuulinko %s?\"" % [r[0], _eur(_price), _eur(_price + step)]
	if Input.is_action_just_pressed("interact"):
		_player_bid()
	# Kerrat: viimeisimmän huudon jälkeen huutaja laskee kolmeen.
	if _call >= 0:
		_call_t -= delta
		if _call_t <= 0.0:
			_call += 1
			_call_t = CALL_STEP
			if _call >= CALLS.size():
				_tip.text = "Erkki: \"MYYTY! %s, %s euroa.\" *KOPS*" % [_who(_leader), _eur(_price)]
				Sfx.play("rattle_hard", -2.0, 0.7)
				_bang = 0.6
				MG.sparks_burst(_sparks, _root.size * Vector2(0.5, 0.36), Color(1.0, 0.9, 0.4), 24)
				_done = true
				var won := _leader == 1
				get_tree().create_timer(1.6).timeout.connect(func() -> void:
					finished.emit(won, _price)
					queue_free())
				return
			Sfx.play("rattle", -8.0, 0.8)
	_info.text = "%s · hinta %s € · rahaa %s €" % [lot, _eur(_price), _eur(money)]
	_keys.set_text("%s huuda (kun Erkki katsoo sinua)   %s luovuta" % [Settings.cap("interact"), Settings.cap("mount")])


func _player_bid() -> void:
	if _leader == 1:
		_tip.text = "Sinä johdat jo. Odota, ettei kukaan huuda yli."
		return
	var next := _next_price()
	if next > money + 0.001:
		_tip.text = "Rahat ei riitä %s euroon." % _eur(next)
		return
	if _gaze != 1:
		_tip.text = "Erkki ei huomannut! Huuda, kun hän katsoo sinuun päin."
		return
	_bid(1)
	_tip.text = "Erkki: \"%s euroa takarivistä! Kuulinko %s?\"" % [_eur(_price), _eur(_price + step)]


func _bid(slot: int) -> void:
	_price = _next_price()
	_leader = slot
	_call = 0
	_call_t = CALL_STEP * 1.3
	_flash = 0.5
	_flash_slot = slot
	_rival_t = -1.0
	Sfx.play("pickup", -6.0, 1.3 if slot == 1 else 0.9)


func _who(slot: int) -> String:
	if slot == 1:
		return "Sinulle"
	return str(rivals[0 if slot == 0 else 1][0])


func _finish(won: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(won, _price)
	queue_free()


# --- Piirto -------------------------------------------------------------------

const CURTAIN := Color(0.62, 0.07, 0.1)
const STAGE := Color(0.5, 0.33, 0.2)


func _slot_pos(i: int) -> Vector2:
	var sz := _root.size
	return Vector2(sz.x * (0.26 + i * 0.24), sz.y * 0.64)


func _draw_root() -> void:
	var font := ThemeDB.fallback_font
	var sz := _root.size
	# Sali: paneloitu takaseinä, lava ja verhot laskoksineen.
	MG.grad_rect(_root, Rect2(Vector2.ZERO, sz), Color(0.3, 0.24, 0.18), Color(0.12, 0.09, 0.07))
	for x in range(0, int(sz.x), 48):
		_root.draw_line(Vector2(x, 0), Vector2(x, sz.y * 0.5), Color(0.22, 0.17, 0.12), 2.0)
	var stage := Rect2(Vector2(sz.x * 0.16, sz.y * 0.17), Vector2(sz.x * 0.68, sz.y * 0.27))
	MG.grad_rect(_root, stage, Color(0.2, 0.08, 0.08), Color(0.1, 0.04, 0.04))
	MG.wood(_root, Rect2(Vector2(sz.x * 0.12, stage.end.y), Vector2(sz.x * 0.76, 34)), STAGE, 12.0, 3, false)
	for side in [0, 1]:
		var cx := stage.position.x if side == 0 else stage.end.x - sz.x * 0.09
		for k in 6:  # verhon laskokset
			var r := Rect2(Vector2(cx + k * sz.x * 0.015, stage.position.y - 10), Vector2(sz.x * 0.016, stage.size.y + 44))
			MG.grad_rect(_root, r, CURTAIN.lightened(0.15 if k % 2 == 0 else 0.0), CURTAIN.darkened(0.3 if k % 2 == 0 else 0.45))
	MG.grad_rect(_root, Rect2(Vector2(sz.x * 0.14, stage.position.y - 30), Vector2(sz.x * 0.72, 34)), CURTAIN.lightened(0.1), CURTAIN.darkened(0.3))
	MG.sign(_root, Rect2(Vector2(sz.x * 0.5 - 170, stage.position.y - 26), Vector2(340, 40)), "HUUTOKAUPPA", Color(0.95, 0.8, 0.2), Color(0.45, 0.06, 0.05), 26, Color(0.4, 0.25, 0.1))
	# Valokeila katsottavaan ja huutaja keskellä lavaa.
	var erkki := Vector2(sz.x * 0.44, stage.position.y + stage.size.y * 0.42)
	var target := _slot_pos(_gaze)
	_root.draw_colored_polygon(PackedVector2Array([erkki + Vector2(-20, -40), erkki + Vector2(20, -40), target + Vector2(110, 80), target + Vector2(-110, 80)]),
		Color(1.0, 0.95, 0.65, 0.1 if _gaze != 1 else 0.2))
	MG.glow(_root, target + Vector2(0, 40), 150.0, Color(1.0, 0.95, 0.6, 0.6 if _gaze == 1 else 0.3))
	# Huutajan pöytä ja nuija, kohde pöydällä.
	var desk := Rect2(erkki + Vector2(-90, 40), Vector2(180, 60))
	var look_dir := (target - erkki).normalized() * Vector2(1.0, 0.5)
	MG.person(_root, erkki, 1.0, ERKKI, look_dir, _flash > 0.0 or _call >= 0, 0.9 if _bang > 0.0 else 0.0)
	MG.solid(_root, desk, Color(0.42, 0.26, 0.14))
	var gav := erkki + Vector2(70, 30 + (20.0 * sin(_bang * 25.0) if _bang > 0.0 else -10.0))
	_root.draw_line(gav, gav + Vector2(22, -24), Color(0.45, 0.28, 0.14), 6.0)
	MG.solid(_root, Rect2(gav + Vector2(-16, -10), Vector2(30, 18)), Color(0.35, 0.2, 0.1))
	var lt := Rect2(Vector2(sz.x * 0.6, stage.position.y + stage.size.y * 0.52), Vector2(160, 90))
	MG.solid(_root, Rect2(lt.position + Vector2(0, 60), Vector2(lt.size.x, 30)), Color(0.92, 0.9, 0.84))
	_draw_lot(lt.position + Vector2(lt.size.x / 2.0, 34))
	# Hinta kylttitaululla ja kerrat puhekuplassa.
	MG.sign(_root, Rect2(Vector2(sz.x * 0.5 - 100, sz.y * 0.455), Vector2(200, 56)), "%s €" % _eur(_price), Color(0.08, 0.1, 0.08), Color(1.0, 0.88, 0.3), 36, Color(0.55, 0.4, 0.2))
	if _call >= 0 and _call < CALLS.size():
		MG.bubble(_root, Rect2(erkki + Vector2(-360, -120), Vector2(300, 52)), erkki + Vector2(-34, -30), CALLS[_call], 22)
	elif _done:
		MG.bubble(_root, Rect2(erkki + Vector2(-360, -120), Vector2(300, 52)), erkki + Vector2(-34, -30), "MYYTY!", 30)
	# Yleisö: tuolinselkämykset ja huutajat lappuineen.
	for i in SLOTS:
		var p := _slot_pos(i)
		var arm := clampf(_flash * 3.0, 0.0, 1.0) if i == _flash_slot else (0.35 if i == _leader else 0.0)
		MG.person(_root, p, 1.05, LOOKS[i], (erkki - p).normalized() * 0.6, false, arm, str(17 + i * 9))
		MG.solid(_root, Rect2(p + Vector2(-60, 96), Vector2(120, 30)), Color(0.45, 0.28, 0.16))
		var seen := i == 1 and _gaze == 1 and not _done
		var name: String = ("SINÄ · Erkki katsoo!" if seen else "SINÄ") if i == 1 else str(rivals[0 if i == 0 else 1][0])
		var nw := 230.0 if seen else 160.0
		MG.box(_root, Rect2(p + Vector2(-nw / 2.0, 132), Vector2(nw, 30)), Color(0.1, 0.45, 0.2, 0.85) if seen else Color(0, 0, 0, 0.55), 8)
		_root.draw_string(font, p + Vector2(-nw / 2.0, 154), name, HORIZONTAL_ALIGNMENT_CENTER, nw, 20, Color(0.75, 1.0, 0.75) if i == 1 else Color.WHITE)
		if i == _leader:
			MG.sign(_root, Rect2(p + Vector2(-50, -118), Vector2(100, 30)), "JOHTAA", Color(0.95, 0.75, 0.15), Color(0.25, 0.1, 0.0), 18, Color(0.5, 0.3, 0.05))
	MG.sparks_draw(_root, _sparks)


## Huutokaupan kohde pöydällä: napamoottori tai muu tavara laatikossa.
func _draw_lot(c: Vector2) -> void:
	if lot.begins_with("Napamoottori"):
		MG.ball(_root, c, 34.0, Color(0.18, 0.18, 0.2), 0.3)
		for k in 12:
			var a := k * TAU / 12.0
			_root.draw_circle(c + Vector2(cos(a), sin(a)) * 26.0, 2.5, Color(0.05, 0.05, 0.05))
		MG.ball(_root, c, 12.0, Color(0.72, 0.73, 0.76), 0.6)
	elif lot.begins_with("Moccamaster"):
		MG.solid(_root, Rect2(c + Vector2(-26, -30), Vector2(52, 60)), Color(0.75, 0.1, 0.1))
		MG.solid(_root, Rect2(c + Vector2(-20, 4), Vector2(40, 24)), Color(0.3, 0.2, 0.15))
	else:
		MG.solid(_root, Rect2(c + Vector2(-40, -26), Vector2(80, 52)), Color(0.7, 0.55, 0.35))
		for k in 4:
			MG.solid(_root, Rect2(c + Vector2(-34 + k * 18, -38), Vector2(14, 22)), Color(0.08, 0.08, 0.08), false)
	MG.box(_root, Rect2(c + Vector2(-80, 40), Vector2(160, 22)), Color(0.97, 0.95, 0.88), 4, 2, Color(0.3, 0.2, 0.1), 1)
	_root.draw_string(ThemeDB.fallback_font, c + Vector2(-80, 57), lot.get_slice(",", 0), HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color(0.15, 0.1, 0.05))
