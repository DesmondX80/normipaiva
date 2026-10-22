extends CanvasLayer
## Räkäleima (Oulujärven lavan piha): rahaton kopioi tuoreen leiman pihalla juovan teinin kädestä.
## Vaihe 1 "kopio": vie oma käsi teinin kämmenselän leiman päälle (hiiri) ja paina vasenta nappia pohjaan. Muste kuivuu
##   noin 16 sekunnissa, joten se tarttuu sitä paremmin, mitä tuoreempaa se on; R kostuttaa kämmenen ("räkä"), jolloin muste
##   irtoaa paremmin. Teini vilkaisee välillä (merkki ennen vilkaisua): painaminen hänen katsoessaan herättää epäilyn.
## Vaihe 2 "peili": kopio tulee kätesi päälle PEILIKUVANA (kasvot vastakkain painettu). Välilyönti painaa käden vielä
##   toiseen käteen kun merkki on vihreällä: kuva kääntyy oikein päin mutta haalistuu. Enter näyttää sellaisenaan.
## F / Esc keskeyttää. finished({ok, q, mirrored, caught}): q = kopion laatu 0–1, mirrored = peilikuva.

signal finished(result: Dictionary)

const DRY_T := 16.0  # tuoreen musteen kuivumisaika (s)
const INK := Color(0.36, 0.12, 0.56)
const SKIN := Color(0.93, 0.74, 0.6)
const SKIN_SHADE := Color(0.8, 0.58, 0.46)
const MIN_Q := 0.12
const TEEN_LINES := ["Joo, tää leima on vielä märkä. Älä hierro.", "Portsari leimas mut juuri. Kylmä on se leimasin.",
	"Mä en pese kättä koko iltana, ettei leima lähde.", "Mitä sää tuijotat mun kättä?"]
const LINES := {
	"kopio": ["Käsi teinin leiman päälle ja vasen nappi pohjaan. Muste kuivuu kohta!",
		"Kostuta kämmen (R), niin muste irtoaa paremmin.", "Odota, että teini kääntää katseen pois."],
	"peili": ["Peilikuva! Portsari huomaa sen. Paina käsi toiseen käteen, niin kuva kääntyy.",
		"Kasvot vastakkain painettu kuva on aina väärinpäin."],
}

var drunk := 0.0
var day_stamp := "4172"  # päivän leimassa näkyvä nelinumeroinen koodi (peilikuvassa kopio on takaperin)

var _root: Control
var _info: Label
var _tip: Label
var _keys: Control
var _phase := "kopio"
var _t := 0.0
var _done := false
var _raw := Vector2.ZERO
var _mouse := Vector2.ZERO
var _lmb := false
var _lift := 1.0
var _press_t := 0.0
var _acc := 0.0
var _blur := 0.0
var _moist := 0.0
var _susp := 0.0
var _gaze := "away"
var _gaze_t := 3.0
var _talk_t := 0.0
var _q := 0.0
var _mirror := true
var _flip_marker := 0.0
var _end_t := -1.0
var _end_res := {}
var _contact_sfx := 0.0
var _sz := Vector2(1280, 720)


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	_root.gui_input.connect(_gui)
	add_child(_root)
	_info = _label(24, 40.0, false)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_tip = _label(22, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_tip.text = (LINES.kopio as Array)[0]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_raw = _root.get_local_mouse_position()
	_gaze_t = randf_range(3.0, 5.0)


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


# --- Tila -------------------------------------------------------------------------------------------------------

func wet() -> float:
	return clampf(1.0 - _t / DRY_T, 0.0, 1.0)


func _stamp_c() -> Vector2:
	return Vector2(_sz.x * 0.6, _sz.y * 0.72)


func _unit() -> float:
	return _sz.y / 720.0


func _align() -> float:
	return clampf(1.0 - _mouse.distance_to(_stamp_c()) / (62.0 * _unit()), 0.0, 1.0)


func _gui(ev: InputEvent) -> void:
	if ev is InputEventMouse:
		_raw = ev.position
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_lmb = ev.pressed
		if not ev.pressed:
			_release()


# Näppäimet luetaan _inputissa: _root ei saa näppäimistön kohdistusta, joten gui_input ei näe niitä.
func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and not _done:
		match ev.keycode:
			KEY_R:
				kostuta()
			KEY_SPACE:
				flip()
			KEY_ENTER, KEY_KP_ENTER:
				accept()


## Kostuttaa kämmenen (näppäin R).
func kostuta() -> void:
	if _phase != "kopio" or _done:
		return
	_moist = 1.0
	Sfx.play("water", -10.0, 1.6, 0.4)
	_tip.text = "Kämmen märkänä. Muste irtoaa nyt helpommin."


func _process(delta: float) -> void:
	if _done:
		return
	_sz = _root.size
	_t += delta
	_talk_t += delta
	var wob := Vector2(sin(_t * 5.0), cos(_t * 4.3)) * drunk * 14.0
	_mouse = _raw + wob
	_root.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish({"ok": false, "caught": false, "aborted": true})
		return
	if _end_t >= 0.0:
		_end_t -= delta
		if _end_t <= 0.0:
			_finish(_end_res)
		return
	_moist = maxf(_moist - delta * 0.1, 0.0)
	if _phase == "kopio":
		_copy_tick(delta)
	else:
		_flip_marker = 0.5 + 0.5 * sin(_t * 3.2)
	_info.text = _status()
	if _phase == "kopio":
		_keys.set_text("R kostuta · %s lopeta" % Settings.cap("mount"))
	else:
		_keys.set_text("Välilyönti käsi toiseen käteen · Enter sellaisenaan")


func _status() -> String:
	if _phase == "kopio":
		return "Tuore leima: muste %d %% · vasen nappi painaa, R kostuttaa kämmenen" % roundi(wet() * 100.0)
	return "Kopio kädessä (%d %%): peilikuva · välilyönti kääntää, Enter jättää" % roundi(_q * 100.0)


# --- Vaihe 1: kopiointi --------------------------------------------------------------------------------------

func _copy_tick(delta: float) -> void:
	# Teinin katse: juo (poispäin) → merkki → vilkaisee.
	_gaze_t -= delta
	if _gaze_t <= 0.0:
		match _gaze:
			"away":
				_gaze = "warn"
				_gaze_t = 0.7
			"warn":
				_gaze = "look"
				_gaze_t = randf_range(1.0, 1.4)
			_:
				_gaze = "away"
				_gaze_t = randf_range(2.5, 5.0)
	var contact := _lmb and _lift < 0.18
	_lift = move_toward(_lift, 0.0 if _lmb else 1.0, delta * (5.0 if _lmb else 4.0))
	var al := _align()
	if contact and al > 0.15:
		_press_t += delta
		_blur = lerpf(_blur, 1.0 - al, minf(delta * 4.0, 1.0))
		var moist_k := 0.45 + 0.55 * _moist
		_acc += al * wet() * moist_k * delta
		_contact_sfx -= delta
		if _contact_sfx <= 0.0:
			_contact_sfx = 0.35
			Sfx.play("pickup", -14.0, 0.5)
	# Epäily: katse + painaminen. Käden vienti vain lähelle ei vielä paljasta, mutta vilkaisu sen yllä hieman.
	var rate := -0.5
	if contact:
		rate = {"look": 1.15, "warn": 0.3}.get(_gaze, 0.08)
	elif _gaze == "look" and al > 0.1:
		rate = 0.25
	_susp = clampf(_susp + rate * delta, 0.0, 1.0)
	if _susp >= 1.0:
		_caught()
		return
	if wet() <= 0.0 and _press_t < 0.3:
		_tip.text = "Muste ehti kuivua. Ei tartu enää."
		_end_res = {"ok": false, "caught": false, "dry": true}
		_end_t = 1.6
		return
	if _talk_t > 7.0 and _gaze == "away":
		_talk_t = 0.0
		_tip.text = "Teini: \"%s\"" % TEEN_LINES.pick_random()


func _release() -> void:
	if _done or _phase != "kopio" or _end_t >= 0.0:
		return
	if _press_t >= 0.3:
		_q = clampf(_acc / 1.0, 0.0, 1.0)
		if _q < MIN_Q:
			_tip.text = "Ei tarttunut. Osu leimaan, paina pitkään ja kostuta kämmen (R)."
			_press_t = 0.0
			_acc = 0.0
			return
		_phase = "peili"
		_mirror = true
		_t = _t  # muste kuivuu edelleen
		Sfx.play("coin", -8.0, 0.7)
		_tip.text = (LINES.peili as Array)[0]
	else:
		_press_t = 0.0


func _caught() -> void:
	Sfx.play("alert")
	_tip.text = "Teini: \"Hei! Mitä sää teet mun kädelle?!\""
	_end_res = {"ok": false, "caught": true}
	_end_t = 1.8


# --- Vaihe 2: peilikuva ---------------------------------------------------------------------------------------

## Painaa käden toiseen käteen: kuva kääntyy oikein päin, mutta haalistuu (näppäin välilyönti).
func flip() -> void:
	if _phase != "peili" or _end_t >= 0.0 or not _mirror:
		return
	var tq := clampf(1.0 - absf(_flip_marker - 0.5) / 0.38, 0.0, 1.0)
	var dry_k := 0.25 + 0.75 * wet()
	_q = clampf(_q * (0.5 + 0.5 * tq) * (0.55 + 0.45 * dry_k), 0.0, 1.0)
	_mirror = false
	Sfx.play("pickup", -8.0, 0.9)
	_tip.text = "Kuva kääntyi oikein päin%s." % ("" if tq > 0.6 else ", mutta jäi haaleaksi")
	_end_res = {"ok": true, "q": _q, "mirrored": false}
	_end_t = 1.7


## Näyttää kopion sellaisenaan (peilikuvana).
func accept() -> void:
	if _phase != "peili" or _end_t >= 0.0:
		return
	_tip.text = "No, ehkä portsari ei katso tarkkaan..."
	_end_res = {"ok": true, "q": _q, "mirrored": _mirror}
	_end_t = 1.2


func _finish(res: Dictionary) -> void:
	if _done:
		return
	_done = true
	finished.emit(res)
	queue_free()


# --- Piirto -----------------------------------------------------------------------------------------------------

func _cap(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	_root.draw_line(a, b, col, w, true)
	_root.draw_circle(a, w * 0.5, col)
	_root.draw_circle(b, w * 0.5, col)


func _ell(c: Vector2, rx: float, ry: float, col: Color, n := 28) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_root.draw_colored_polygon(pts, col)


func _draw_root() -> void:
	var u := _unit()
	_bg(u)
	_teen(u)
	_teen_hand(u)
	_player_hand(u)
	_meters(u)
	if _phase == "peili":
		_result_panel(u)


func _bg(u: float) -> void:
	var s := _sz
	# Taivas: kesäillan hämärä horisontissa oranssina.
	var top := Color(0.08, 0.1, 0.24)
	var mid := Color(0.55, 0.3, 0.38)
	_root.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.34), Vector2(0, s.y * 0.34)]),
		PackedColorArray([top, top, mid, mid]))
	_root.draw_rect(Rect2(0, s.y * 0.34, s.x, s.y * 0.66), Color(0.17, 0.2, 0.15))
	# Koivut taustalla.
	for k in 9:
		var x := s.x * (0.04 + k * 0.115)
		_root.draw_line(Vector2(x, s.y * 0.2), Vector2(x, s.y * 0.5), Color(0.82, 0.8, 0.74), 7.0 * u)
		for m in 4:
			_root.draw_rect(Rect2(x - 3.0 * u, s.y * (0.26 + m * 0.06), 6.0 * u, 3.0 * u), Color(0.15, 0.15, 0.15))
		_ell(Vector2(x, s.y * 0.2), 46.0 * u, 54.0 * u, Color(0.13, 0.25, 0.14))
	# Lavan seinä punamultaa, ikkunat hehkuvat.
	var wall := Rect2(s.x * 0.04, s.y * 0.24, s.x * 0.5, s.y * 0.26)
	_root.draw_rect(wall, Color(0.45, 0.14, 0.1))
	for k in 18:
		_root.draw_line(Vector2(wall.position.x + k * wall.size.x / 18.0, wall.position.y), Vector2(wall.position.x + k * wall.size.x / 18.0, wall.end.y),
			Color(0.33, 0.1, 0.07), 2.0 * u)
	_root.draw_rect(Rect2(wall.position.x - 8.0 * u, wall.position.y - 14.0 * u, wall.size.x + 16.0 * u, 16.0 * u), Color(0.2, 0.2, 0.22))
	for k in 4:
		var wr := Rect2(wall.position.x + 40.0 * u + k * 170.0 * u, wall.position.y + 38.0 * u, 80.0 * u, 62.0 * u)
		_root.draw_rect(wr, Color(1.0, 0.82, 0.4))
		_root.draw_line(wr.position + Vector2(wr.size.x / 2.0, 0), wr.position + Vector2(wr.size.x / 2.0, wr.size.y), Color(0.3, 0.1, 0.08), 3.0 * u)
		_root.draw_rect(wr, Color(0.25, 0.08, 0.06), false, 4.0 * u)
	_root.draw_rect(Rect2(wall.end.x - 90.0 * u, wall.position.y + 50.0 * u, 60.0 * u, wall.size.y - 50.0 * u), Color(0.2, 0.08, 0.06))
	_root.draw_circle(Vector2(wall.end.x - 60.0 * u, wall.position.y + 38.0 * u), 9.0 * u, Color(1.0, 0.9, 0.5))
	# Valonauha.
	var prev := Vector2(0, s.y * 0.2)
	for k in 14:
		var x := s.x * (k + 1) / 14.0
		var y := s.y * 0.2 + sin(k * 0.9) * 6.0 * u + (k % 2) * 4.0 * u
		_root.draw_line(prev, Vector2(x, y), Color(0.1, 0.1, 0.1), 2.0 * u)
		_root.draw_circle(Vector2(x, y + 6.0 * u), 5.0 * u, [Color(1, 0.8, 0.3), Color(1, 0.4, 0.3), Color(0.5, 0.9, 1.0)][k % 3])
		prev = Vector2(x, y)
	# Lautaaita ja sora.
	_root.draw_rect(Rect2(0, s.y * 0.5, s.x, s.y * 0.07), Color(0.34, 0.24, 0.15))
	for k in 24:
		_root.draw_rect(Rect2(s.x * k / 24.0 + 4.0 * u, s.y * 0.48, s.x / 24.0 - 8.0 * u, s.y * 0.07), Color(0.42, 0.3, 0.19))
		_root.draw_line(Vector2(s.x * k / 24.0 + 10.0 * u, s.y * 0.5), Vector2(s.x * k / 24.0 + 10.0 * u, s.y * 0.54), Color(0.3, 0.2, 0.12), 2.0 * u)
	_root.draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.57), Vector2(s.x, s.y * 0.57), Vector2(s.x, s.y), Vector2(0, s.y)]),
		PackedColorArray([Color(0.38, 0.35, 0.3), Color(0.38, 0.35, 0.3), Color(0.2, 0.18, 0.16), Color(0.2, 0.18, 0.16)]))


func _teen(u: float) -> void:
	var s := _sz
	var hx := s.x * 0.74
	var head := Vector2(hx, s.y * 0.36)
	# Mopo (sivulta) teinin alla: runko, tankki, penkki, etupyörä.
	var seat_y := s.y * 0.62
	_ell(Vector2(hx - 60.0 * u, s.y * 0.8), 190.0 * u, 18.0 * u, Color(0, 0, 0, 0.35))
	_root.draw_arc(Vector2(hx + 90.0 * u, s.y * 0.76), 60.0 * u, 0, TAU, 32, Color(0.07, 0.07, 0.07), 14.0 * u, true)
	_root.draw_arc(Vector2(hx + 90.0 * u, s.y * 0.76), 38.0 * u, 0, TAU, 32, Color(0.6, 0.6, 0.64), 3.0 * u, true)
	_root.draw_arc(Vector2(hx - 190.0 * u, s.y * 0.76), 60.0 * u, 0, TAU, 32, Color(0.07, 0.07, 0.07), 14.0 * u, true)
	_root.draw_line(Vector2(hx - 190.0 * u, s.y * 0.76), Vector2(hx - 20.0 * u, seat_y + 20.0 * u), Color(0.75, 0.15, 0.12), 12.0 * u, true)
	_root.draw_line(Vector2(hx + 90.0 * u, s.y * 0.76), Vector2(hx + 40.0 * u, seat_y - 40.0 * u), Color(0.7, 0.7, 0.74), 8.0 * u, true)
	_root.draw_line(Vector2(hx + 40.0 * u, seat_y - 40.0 * u), Vector2(hx + 80.0 * u, seat_y - 56.0 * u), Color(0.1, 0.1, 0.1), 7.0 * u, true)
	_ell(Vector2(hx - 60.0 * u, seat_y + 12.0 * u), 120.0 * u, 20.0 * u, Color(0.1, 0.09, 0.09))
	_ell(Vector2(hx - 70.0 * u, seat_y + 4.0 * u), 100.0 * u, 11.0 * u, Color(0.22, 0.19, 0.17))
	# Vartalo (farkkutakki), jalat.
	var shoulder_l := Vector2(hx - 60.0 * u, s.y * 0.47)
	var shoulder_r := Vector2(hx + 38.0 * u, s.y * 0.47)
	_root.draw_colored_polygon(PackedVector2Array([shoulder_l, shoulder_r, Vector2(hx + 50.0 * u, seat_y + 8.0 * u), Vector2(hx - 74.0 * u, seat_y + 8.0 * u)]),
		Color(0.22, 0.34, 0.55))
	_root.draw_line(Vector2(hx - 10.0 * u, s.y * 0.47), Vector2(hx - 10.0 * u, seat_y + 8.0 * u), Color(0.14, 0.22, 0.38), 3.0 * u)
	_root.draw_line(Vector2(hx - 70.0 * u, seat_y + 8.0 * u), Vector2(hx - 40.0 * u, s.y * 0.78), Color(0.12, 0.13, 0.2), 28.0 * u, true)
	_root.draw_line(Vector2(hx + 40.0 * u, seat_y + 8.0 * u), Vector2(hx + 50.0 * u, s.y * 0.78), Color(0.12, 0.13, 0.2), 28.0 * u, true)
	# Kaula ja pää.
	_cap(Vector2(hx - 10.0 * u, s.y * 0.47), head + Vector2(0, 40.0 * u), 30.0 * u, SKIN_SHADE)
	# Katse: pois (olutta kohti), merkki (silmät liukuvat), vilkaisu (katsoo pelaajaa).
	var look := -1.0 if _gaze == "away" else (-0.4 if _gaze == "warn" else -1.0)
	var face_dx := -6.0 * u if _gaze != "look" else -16.0 * u
	_ell(head, 50.0 * u, 58.0 * u, SKIN)
	_ell(head + Vector2(face_dx * 0.3, 8.0 * u), 44.0 * u, 50.0 * u, SKIN.lightened(0.04))
	# Lippis väärinpäin, takaa hiukset.
	_root.draw_colored_polygon(PackedVector2Array([head + Vector2(-48.0 * u, -8.0 * u), head + Vector2(-34.0 * u, -52.0 * u), head + Vector2(30.0 * u, -52.0 * u),
		head + Vector2(48.0 * u, -8.0 * u), head + Vector2(40.0 * u, -14.0 * u), head + Vector2(-40.0 * u, -14.0 * u)]), Color(0.85, 0.2, 0.15))
	_root.draw_rect(Rect2(head + Vector2(-8.0 * u, -62.0 * u), Vector2(16.0 * u, 12.0 * u)), Color(0.75, 0.15, 0.1))
	_root.draw_colored_polygon(PackedVector2Array([head + Vector2(40.0 * u, -14.0 * u), head + Vector2(76.0 * u, -8.0 * u), head + Vector2(44.0 * u, -4.0 * u)]), Color(0.65, 0.13, 0.1))
	_cap(head + Vector2(-46.0 * u, -4.0 * u), head + Vector2(-52.0 * u, 20.0 * u), 12.0 * u, Color(0.55, 0.4, 0.2))
	# Kasvot: silmät katsovat suuntaan look-gaze.
	var eye_c := head + Vector2(face_dx - 4.0 * u, 2.0 * u)
	for k in 2:
		var ex := eye_c + Vector2(-16.0 * u + k * 30.0 * u, 0)
		_ell(ex, 9.0 * u, 7.0 * u, Color.WHITE)
		var pupil := Vector2(look * 4.0 * u, 0)
		if _gaze == "look":
			pupil = Vector2(-5.0 * u, 4.0 * u)
		_root.draw_circle(ex + pupil, 4.0 * u, Color(0.12, 0.1, 0.1))
		_root.draw_line(ex + Vector2(-10.0 * u, -11.0 * u - (5.0 * u if _gaze == "warn" else 0.0)), ex + Vector2(10.0 * u, -10.0 * u), Color(0.4, 0.28, 0.18), 3.0 * u, true)
	_root.draw_line(head + Vector2(face_dx - 6.0 * u, 34.0 * u), head + Vector2(face_dx + 14.0 * u, 32.0 * u + (4.0 * u if _gaze == "look" else 0.0)), Color(0.5, 0.2, 0.2), 3.0 * u, true)
	# Olutpurkki toisessa kädessä.
	var can := Vector2(hx + 56.0 * u, seat_y - 40.0 * u)
	_cap(shoulder_r, can + Vector2(0, 24.0 * u), 22.0 * u, Color(0.22, 0.34, 0.55))
	_root.draw_rect(Rect2(can + Vector2(-13.0 * u, -22.0 * u), Vector2(26.0 * u, 46.0 * u)), Color(0.85, 0.75, 0.25))
	_root.draw_rect(Rect2(can + Vector2(-13.0 * u, -22.0 * u), Vector2(9.0 * u, 46.0 * u)), Color(1, 1, 1, 0.25))
	_root.draw_circle(can + Vector2(0, 24.0 * u), 11.0 * u, SKIN)
	# Epäilyn kysymysmerkki.
	if _gaze == "warn" or _gaze == "look" or _susp > 0.15:
		var f := ThemeDB.fallback_font
		_root.draw_string(f, head + Vector2(-80.0 * u, -74.0 * u), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(54 * u), Color(1, 0.85, 0.2))


## Teinin käsi: kyynärvarsi tulee oikealta, kämmenselkä ylöspäin ja leima keskellä.
func _teen_hand(u: float) -> void:
	var c := _stamp_c()
	var sleeve_from := Vector2(_sz.x * 0.9, _sz.y * 0.5)
	_cap(sleeve_from, c + Vector2(110.0 * u, -60.0 * u), 56.0 * u, Color(0.22, 0.34, 0.55))
	_cap(c + Vector2(100.0 * u, -56.0 * u), c + Vector2(30.0 * u, -18.0 * u), 48.0 * u, SKIN_SHADE)
	_hand(c, 1.25 * u, SKIN, SKIN_SHADE, -0.5)
	_stamp(c, 1.0 * u, false, INK, 0.35 + 0.6 * wet(), wet())


## Kämmenselkä ylhäältä: sormet ylöspäin (rot kääntää), s = mittakaava.
func _hand(c: Vector2, s: float, skin: Color, shade: Color, rot: float) -> void:
	_root.draw_set_transform(c, rot, Vector2.ONE)
	var z := Vector2.ZERO
	_ell(z + Vector2(3, 6) * s, 46.0 * s, 56.0 * s, Color(0, 0, 0, 0.18))
	for k in 4:
		var bx := (-27.0 + k * 18.0) * s
		var len_f: float = [44.0, 54.0, 50.0, 40.0][k] * s
		var fan := (k - 1.5) * 0.09
		var base := Vector2(bx, -34.0 * s)
		var tip: Vector2 = base + Vector2(sin(fan), -cos(fan)) * len_f
		_cap(base, tip, 17.0 * s, skin)
		_ell(tip + Vector2(0, 4.0 * s), 5.2 * s, 6.5 * s, Color(1, 0.88, 0.82))
	_cap(Vector2(-34.0 * s, 14.0 * s), Vector2(-62.0 * s, -14.0 * s), 17.0 * s, skin)
	_ell(Vector2(-62.0 * s, -14.0 * s) + Vector2(2, 2) * s, 5.0 * s, 6.0 * s, Color(1, 0.88, 0.82))
	_ell(z, 41.0 * s, 52.0 * s, skin)
	for k in 4:
		_root.draw_arc(Vector2((-27.0 + k * 18.0) * s, -32.0 * s), 6.0 * s, PI * 1.1, PI * 1.9, 8, shade, 2.0 * s, true)
	_root.draw_line(Vector2(-10.0 * s, -20.0 * s), Vector2(-6.0 * s, 20.0 * s), shade.lerp(skin, 0.5), 2.0 * s, true)
	_root.draw_set_transform_matrix(Transform2D.IDENTITY)


## Leima: pelkkä päivän nelinumeroinen koodi (ei kehystä, tekstiä eikä nuolta). Käsi kopioituu aina peilikuvana, joten koodi
## on kopiossa takaperin, kunnes kopio käännetään oikein päin. Märkä muste kiiltää numeroiden päällä.
func _stamp(c: Vector2, s: float, mirror: bool, col: Color, alpha: float, wet_k: float) -> void:
	var f := ThemeDB.fallback_font
	_root.draw_set_transform_matrix(Transform2D(Vector2(-s if mirror else s, 0), Vector2(0, s), c))
	var a := clampf(alpha, 0.0, 1.0)
	var ink := Color(col.r, col.g, col.b, a)
	var halo := Color(col.r, col.g, col.b, a * 0.28 * (0.4 + wet_k))
	var size := 40
	var dw := f.get_string_size(day_stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-dw / 2.0, size * 0.34)
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:  # muste tihkuu reunoilta
		_root.draw_string(f, at + o, day_stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, size, halo)
	_root.draw_string(f, at, day_stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	if wet_k > 0.25:
		_root.draw_string(f, at + Vector2(-1.5, -1.5), day_stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.22 * wet_k))
	_root.draw_set_transform_matrix(Transform2D.IDENTITY)


## Pelaajan käsi: kohoaa kursorin mukana, painettaessa laskeutuu teinin käden päälle.
func _player_hand(u: float) -> void:
	var p := _mouse if _root.get_rect().has_point(_mouse) else Vector2(_sz.x * 0.3, _sz.y * 0.8)
	var sc := (1.0 + 0.22 * _lift) * 1.45 * u
	var shadow_off := Vector2(14.0, 22.0) * _lift * u
	_ell(p + shadow_off + Vector2(0, 26.0 * u), 36.0 * sc, 44.0 * sc, Color(0, 0, 0, 0.1 + 0.1 * (1.0 - _lift)))
	var skin := SKIN.lerp(Color(0.9, 0.62, 0.52), _moist * 0.35)
	_cap(p + Vector2(-10.0, 110.0 * u), p + Vector2(0, 40.0 * u), 62.0 * u, Color(0.5, 0.15, 0.15))  # hiha
	_hand(p, sc, skin, SKIN_SHADE, 0.0)
	if _phase == "kopio" and _lift < 0.95:
		# Haamuleima oman kämmenen päällä: näkee, mihin kohtaan teinin leima jää.
		var sc_c := _stamp_c()
		_root.draw_arc(sc_c, 44.0 * u, 0.0, TAU, 40, Color(1, 1, 1, 0.55), 2.0 * u, true)
		_stamp(sc_c, 1.0 * u, false, INK, 0.45, 0.0)
	if _moist > 0.1:
		for k in 5:
			var a := _t * 3.0 + k * 1.3
			_root.draw_circle(p + Vector2(sin(a) * 26.0, -10.0 + cos(a * 1.3) * 22.0) * u, 3.0 * u, Color(0.8, 0.95, 0.8, 0.5 * _moist))
	# Kopion esikatselu kädessä painettaessa.
	if _lift < 0.3 and _align() > 0.15:
		var a := clampf(_acc, 0.0, 1.0)
		_stamp(p + Vector2(0, 4.0 * u) + Vector2(sin(_t * 30.0), 0) * _blur * 3.0, 1.0 * u, true, INK, 0.7 * a, wet())


func _meters(u: float) -> void:
	var f := ThemeDB.fallback_font
	var x := 36.0 * u
	var y := _sz.y * 0.12
	# Musteen kuivuminen.
	_root.draw_rect(Rect2(x, y, 220.0 * u, 16.0 * u), Color(0, 0, 0, 0.5))
	_root.draw_rect(Rect2(x, y, 220.0 * u * wet(), 16.0 * u), INK.lightened(0.15))
	_root.draw_string(f, Vector2(x, y - 6.0 * u), "Muste märkää", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u), Color(0.9, 0.85, 1))
	_root.draw_rect(Rect2(x, y + 44.0 * u, 220.0 * u, 16.0 * u), Color(0, 0, 0, 0.5))
	_root.draw_rect(Rect2(x, y + 44.0 * u, 220.0 * u * _moist, 16.0 * u), Color(0.7, 0.95, 0.75))
	_root.draw_string(f, Vector2(x, y + 38.0 * u), "Kämmen kostea", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u), Color(0.85, 1, 0.9))
	# Epäily.
	_root.draw_rect(Rect2(x, y + 88.0 * u, 220.0 * u, 16.0 * u), Color(0, 0, 0, 0.5))
	_root.draw_rect(Rect2(x, y + 88.0 * u, 220.0 * u * _susp, 16.0 * u), Color(1.0, 0.5 - 0.35 * _susp, 0.15))
	_root.draw_string(f, Vector2(x, y + 82.0 * u), "Teinin epäily", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u), Color(1, 0.9, 0.7))
	# Kopion laatu painaessa.
	if _phase == "kopio" and _press_t > 0.0:
		_root.draw_rect(Rect2(x, y + 132.0 * u, 220.0 * u, 16.0 * u), Color(0, 0, 0, 0.5))
		_root.draw_rect(Rect2(x, y + 132.0 * u, 220.0 * u * clampf(_acc, 0.0, 1.0), 16.0 * u), Color(0.95, 0.85, 0.3))
		_root.draw_string(f, Vector2(x, y + 126.0 * u), "Kopion tarttuminen", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u), Color(1, 0.95, 0.7))


## Tulospaneeli: teinin alkuperäinen ja oma kopio rinnakkain (kopio peilikuvana), ajoitusmittari kääntämiseen.
func _result_panel(u: float) -> void:
	var f := ThemeDB.fallback_font
	var panel := Rect2(_sz.x * 0.5 - 380.0 * u, _sz.y * 0.14, 760.0 * u, 350.0 * u)
	_root.draw_rect(Rect2(panel.position + Vector2(6, 8) * u, panel.size), Color(0, 0, 0, 0.45))
	_root.draw_rect(panel, Color(0.12, 0.1, 0.14, 0.94))
	_root.draw_rect(panel, Color(0.9, 0.8, 0.5), false, 3.0 * u)
	_root.draw_string(f, panel.position + Vector2(0, 38.0 * u), "Teinin leima ja sinun kätesi", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, int(24 * u), Color(1, 0.95, 0.75))
	var lc := panel.position + Vector2(panel.size.x * 0.26, 195.0 * u)
	var rc := panel.position + Vector2(panel.size.x * 0.74, 195.0 * u)
	_hand(lc, 1.5 * u, SKIN, SKIN_SHADE, 0.0)
	_stamp(lc, 1.5 * u, false, INK, 0.35 + 0.6 * wet(), wet())
	_hand(rc, 1.5 * u, SKIN, SKIN_SHADE, 0.0)
	_stamp(rc, 1.5 * u, _mirror, INK, 0.25 + 0.7 * _q * (0.5 + 0.5 * wet()), wet())
	_root.draw_string(f, lc + Vector2(-90.0, 108.0) * u, "Alkuperäinen", HORIZONTAL_ALIGNMENT_CENTER, 180.0 * u, int(18 * u), Color(0.9, 0.85, 1))
	_root.draw_string(f, rc + Vector2(-110.0, 108.0) * u, "PEILIKUVA!" if _mirror else "Oikein päin", HORIZONTAL_ALIGNMENT_CENTER, 220.0 * u, int(18 * u),
		Color(1.0, 0.5, 0.4) if _mirror else Color(0.6, 1.0, 0.6))
	_root.draw_string(f, panel.position + Vector2(0, 205.0 * u), "→", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, int(46 * u), Color(0.9, 0.8, 0.5))
	if _mirror and _end_t < 0.0:
		# Ajoitusmittari: käsi toiseen käteen, kun merkki on vihreällä.
		var bar := Rect2(panel.position + Vector2(panel.size.x * 0.2, 310.0 * u), Vector2(panel.size.x * 0.6, 18.0 * u))
		_root.draw_rect(bar, Color(0.2, 0.2, 0.24))
		var gw := bar.size.x * 0.38
		_root.draw_rect(Rect2(bar.position.x + (bar.size.x - gw) / 2.0, bar.position.y, gw, bar.size.y), Color(0.3, 0.7, 0.35))
		_root.draw_rect(Rect2(bar.position.x + (bar.size.x - gw * 0.4) / 2.0, bar.position.y, gw * 0.4, bar.size.y), Color(0.5, 0.95, 0.5))
		var mx := bar.position.x + bar.size.x * _flip_marker
		_root.draw_rect(Rect2(mx - 3.0 * u, bar.position.y - 6.0 * u, 6.0 * u, bar.size.y + 12.0 * u), Color(1, 1, 1))
