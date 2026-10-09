extends CanvasLayer
## Huutokauppa Saloisten seuraintalon lavalla (#114): huutaja Erkki vilkuilee yleisöä vuorotellen, ja huuto menee
## läpi vain, kun hän katsoo sinua (E tai välilyönti). Kilpailijat (mummo ja ukko) huutavat omaan kattohintaansa asti.
## Jokaisen huudon jälkeen "ensimmäisen kerran, toisen kerran... kolmannen kerran!": viimeinen huutaja voittaa.
## Huuto ei voi ylittää rahoja. F / Esc luovuttaa. finished(won, price).

signal finished(won: bool, price: float)

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
	if _done:
		return
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_root.queue_redraw()
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

func _slot_pos(i: int) -> Vector2:
	var sz := _root.size
	return Vector2(sz.x * (0.25 + i * 0.25), sz.y * 0.68)


func _draw_root() -> void:
	var font := ThemeDB.fallback_font
	var sz := _root.size
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.08, 0.04, 0.04, 0.82))
	# Lava ja verhot.
	_root.draw_rect(Rect2(Vector2(sz.x * 0.2, sz.y * 0.12), Vector2(sz.x * 0.6, sz.y * 0.28)), Color(0.45, 0.3, 0.18))
	_root.draw_rect(Rect2(Vector2(sz.x * 0.2, sz.y * 0.1), Vector2(sz.x * 0.06, sz.y * 0.32)), Color(0.6, 0.08, 0.1))
	_root.draw_rect(Rect2(Vector2(sz.x * 0.74, sz.y * 0.1), Vector2(sz.x * 0.06, sz.y * 0.32)), Color(0.6, 0.08, 0.1))
	var erkki := Vector2(sz.x * 0.5, sz.y * 0.24)
	_root.draw_circle(erkki, 34.0, Color(0.96, 0.75, 0.66))
	_root.draw_rect(Rect2(erkki + Vector2(-34, 36), Vector2(68, 70)), Color(0.85, 0.85, 0.8))
	# Katse: valokeila kohti katsottavaa.
	var target := _slot_pos(_gaze)
	var beam := PackedVector2Array([erkki + Vector2(-8, 10), erkki + Vector2(8, 10), target + Vector2(70, -60), target + Vector2(-70, -60)])
	_root.draw_colored_polygon(beam, Color(1.0, 0.95, 0.6, 0.18 if _gaze != 1 else 0.32))
	var eye := erkki + (target - erkki).normalized() * 12.0
	_root.draw_circle(eye + Vector2(-9, -6), 5.0, Color.BLACK)
	_root.draw_circle(eye + Vector2(9, -6), 5.0, Color.BLACK)
	# Huutajat.
	for i in SLOTS:
		var p := _slot_pos(i)
		var col := Color(0.0, 0.55, 0.55) if i == 1 else (Color(0.55, 0.3, 0.45) if i == 0 else Color(0.3, 0.32, 0.25))
		if i == _gaze:
			_root.draw_circle(p + Vector2(0, 20), 90.0, Color(0.3, 0.9, 0.4, 0.25) if i == 1 else Color(1, 1, 1, 0.08))
		_root.draw_circle(p, 30.0, Color(0.95, 0.78, 0.7))
		_root.draw_rect(Rect2(p + Vector2(-32, 32), Vector2(64, 80)), col)
		if i == _flash_slot and _flash > 0.0:  # käsi ylös
			_root.draw_line(p + Vector2(30, 40), p + Vector2(46, -40), col, 14.0)
		var name: String = "SINÄ" if i == 1 else str(rivals[0 if i == 0 else 1][0])
		_root.draw_string(font, p + Vector2(-80, 140), name, HORIZONTAL_ALIGNMENT_CENTER, 160, 22, Color.WHITE)
		if i == _leader:
			_root.draw_string(font, p + Vector2(-80, -50), "JOHTAA", HORIZONTAL_ALIGNMENT_CENTER, 160, 22, Color(1.0, 0.85, 0.2))
	# Hinta ja kerrat.
	_root.draw_string(font, Vector2(0, sz.y * 0.47), "%s €" % _eur(_price), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 54, Color(1.0, 0.9, 0.3))
	if _call >= 0 and _call < CALLS.size():
		_root.draw_string(font, Vector2(0, sz.y * 0.53), CALLS[_call], HORIZONTAL_ALIGNMENT_CENTER, sz.x, 30, Color(1, 1, 1))
