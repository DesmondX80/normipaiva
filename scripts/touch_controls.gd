extends CanvasLayer
## Kosketusohjaimet puhelimelle ja tabletille (autoload "Touch"), näkyvät vain kosketusnäytöllä (tai --touch).
## Vasemmalla puolella tatti ilmestyy sormen kohdalle ja painaa W/A/S/D (reunaan asti: + Shift = juoksu/spurtti).
## Oikealla puolella vetäminen kääntää kameraa (look-signaali: kamera, metsästyksen ja droonin tähtäys).
## Napit syöttävät samat näppäintapahtumat kuin näppäimistö (Input.parse_input_event), joten kaikki toiminnot,
## myös minipelien omat näppäimet, toimivat ilman muutoksia. Minipelit voivat lisätä omia nappejaan (set_extra).
## Kun peli on pysäytetty (valikko, kartta, reppu), näkyvät vain reunan valikkonapit.

signal look(rel: Vector2)

const LOOK_SENS := 1.6  # kosketusvedon herkkyys hiireen verrattuna
const JOY_R := 90.0
const DEAD := 0.3
const SPRINT := 0.92

var active := false
var aim := false  # metsästyksen tarkka tähtäys (hiiren oikea nappi)

var _canvas: Node2D
var _font: Font
var _size := Vector2(1280, 720)
## Napit: {key, label, pos, r, side} ; side = "main" (pelissä), "edge" (aina), "extra" (minipelin omat).
var _buttons: Array = []
var _extra: Array = []
var _finger_btn := {}  # sormi -> nappi
var _joy_finger := -1
var _joy_center := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _look_finger := -1
var _keys := {}  # näppäinkoodi -> painettuna


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
		or OS.get_cmdline_user_args().has("--touch")
	visible = active
	set_process(active)
	set_process_input(active)
	if not active:
		return
	_font = ThemeDB.fallback_font
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_pad)
	add_child(_canvas)


## Minipelin omat napit: [[näppäin, "teksti"], ...]; näppäin -1 = tarkka tähtäys (aim). Tyhjä lista poistaa.
func set_extra(list: Array) -> void:
	_extra = list
	aim = false
	_layout()


func _process(_delta: float) -> void:
	var s := get_viewport().get_visible_rect().size
	if s != _size or _buttons.is_empty():
		_size = s
		_layout()
	_canvas.queue_redraw()


func _layout() -> void:
	var w := _size.x
	var h := _size.y
	# Pääklusteri oikealla alhaalla minikartan vasemmalla puolella, reunanapit oikeassa reunassa kartan yläpuolella.
	_buttons = [
		{"key": KEY_E, "label": "Toiminto", "pos": Vector2(w - 330, h - 110), "r": 58.0, "side": "main"},
		{"key": KEY_SPACE, "label": "Hyppy\nJarru", "pos": Vector2(w - 470, h - 80), "r": 46.0, "side": "main"},
		{"key": KEY_F, "label": "Pyörä", "pos": Vector2(w - 330, h - 250), "r": 46.0, "side": "main"},
		{"key": KEY_T, "label": "Syö", "pos": Vector2(w - 470, h - 205), "r": 38.0, "side": "main"},
	]
	var col := [[KEY_ESCAPE, "Valikko"], [KEY_M, "Kartta"], [KEY_I, "Reppu"], [KEY_Q, "Kello"], [KEY_V, "Kamera"]]
	for i in col.size():
		_buttons.append({"key": col[i][0], "label": col[i][1], "pos": Vector2(w - 42, 150 + i * 64), "r": 29.0,
			"side": "edge"})
	for i in _extra.size():
		_buttons.append({"key": _extra[i][0], "label": _extra[i][1], "pos": Vector2(w - 560 + i * 100, h - 330),
			"r": 40.0, "side": "extra"})


func _visible_btn(b: Dictionary) -> bool:
	return b.side == "edge" or not get_tree().paused


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			for b in _buttons:
				if _visible_btn(b) and p.distance_to(b.pos) < b.r * 1.2:
					_finger_btn[event.index] = b
					_press(b, true)
					get_viewport().set_input_as_handled()
					return
			if get_tree().paused:
				return
			if p.x < _size.x * 0.42 and p.y > _size.y * 0.3 and _joy_finger < 0:
				_joy_finger = event.index
				_joy_center = p
				_joy_vec = Vector2.ZERO
				get_viewport().set_input_as_handled()
			elif _look_finger < 0:
				_look_finger = event.index
		else:
			if _finger_btn.has(event.index):
				_press(_finger_btn[event.index], false)
				_finger_btn.erase(event.index)
			elif event.index == _joy_finger:
				_joy_finger = -1
				_joy_vec = Vector2.ZERO
				_apply_joy()
			elif event.index == _look_finger:
				_look_finger = -1
	elif event is InputEventScreenDrag:
		if event.index == _joy_finger:
			_joy_vec = ((event.position - _joy_center) / JOY_R).limit_length(1.0)
			_apply_joy()
			get_viewport().set_input_as_handled()
		elif event.index == _look_finger and not get_tree().paused:
			var rel: Vector2 = event.relative * LOOK_SENS
			CamCtl.touch_look(rel)
			look.emit(rel)


func _press(b: Dictionary, down: bool) -> void:
	b["down"] = down
	if b.key == -1:
		aim = down
		return
	_key(b.key, down)


## Tatin suunta näppäimiksi: kuten W/A/S/D, reunaan asti painettuna myös Shift.
func _apply_joy() -> void:
	var v := _joy_vec
	_key(KEY_W, v.y < -DEAD)
	_key(KEY_S, v.y > DEAD)
	_key(KEY_A, v.x < -DEAD)
	_key(KEY_D, v.x > DEAD)
	_key(KEY_SHIFT, v.length() > SPRINT)


func _key(code: int, down: bool) -> void:
	if _keys.get(code, false) == down:
		return
	_keys[code] = down
	var ev := InputEventKey.new()
	ev.physical_keycode = code as Key
	ev.keycode = code as Key
	ev.pressed = down
	Input.parse_input_event(ev)
	# Näppäimet voi vaihtaa asetuksista: painetaan myös oletusnäppäimen toimintoja, jotta kosketusohjaus toimii aina.
	for row in Settings.KEY_ROWS:
		if code in row[2]:
			for a in row[0]:
				if down:
					Input.action_press(a)
				else:
					Input.action_release(a)


func _draw_pad() -> void:
	var paused := get_tree().paused
	if not paused:
		if _joy_finger >= 0:
			_canvas.draw_circle(_joy_center, JOY_R, Color(1, 1, 1, 0.12))
			_canvas.draw_arc(_joy_center, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0)
			_canvas.draw_circle(_joy_center + _joy_vec * JOY_R, 38.0, Color(1, 1, 1, 0.5))
		else:
			# Vihje tatin paikasta vasemmassa alakulmassa.
			var c := Vector2(170, _size.y - 170)
			_canvas.draw_arc(c, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 2.0)
			_canvas.draw_circle(c, 30.0, Color(1, 1, 1, 0.14))
	for b in _buttons:
		if not _visible_btn(b):
			continue
		var down: bool = b.get("down", false)
		_canvas.draw_circle(b.pos, b.r, Color(0, 0, 0, 0.45 if down else 0.28))
		_canvas.draw_arc(b.pos, b.r, 0.0, TAU, 40, Color(1, 1, 1, 0.85 if down else 0.5), 2.5)
		var fs := 15 if b.r < 35.0 else 18
		var lines: PackedStringArray = b.label.split("\n")
		for i in lines.size():
			var y: float = b.pos.y + fs * 0.35 + (i - (lines.size() - 1) / 2.0) * fs * 1.1
			_canvas.draw_string_outline(_font, Vector2(b.pos.x - b.r, y), lines[i], HORIZONTAL_ALIGNMENT_CENTER, b.r * 2.0,
				fs, 4, Color(0, 0, 0, 0.8))
			_canvas.draw_string(_font, Vector2(b.pos.x - b.r, y), lines[i], HORIZONTAL_ALIGNMENT_CENTER, b.r * 2.0, fs,
				Color(1, 1, 1, 0.95))
