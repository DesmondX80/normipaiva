extends CanvasLayer
## Tiskaus (Santun homma) mökin keittiössä: astia kerrallaan tiskialtaassa. Hankaa A/D vuorotellen (tai hiirtä
## edestakaisin), kunnes astia on puhdas, ja nosta se kuivauskaappiin (välilyönti tai E). Humalassa märkä astia
## lipsahtaa helposti lattialle. Santtu kommentoi vieressä (mokki_interior.gd say). F / Esc lopettaa kesken.

signal finished(washed: int, broken: int)
signal comment(text: String)

const DISHES := [["lautanen", Color(0.95, 0.95, 0.92)], ["muki", Color(0.85, 0.3, 0.2)], ["lautanen", Color(0.95, 0.95, 0.92)],
	["kattila", Color(0.6, 0.62, 0.65)], ["lasi", Color(0.75, 0.88, 0.95)], ["mummon kukkalautanen", Color(0.92, 0.88, 0.95)]]
const SCRUB := 0.09  # yksi veto puhdistaa
const LINES := {
	"start": ["Tiskiaine on altaan reunalla. Kuumaa vettä riittää.", "Mummon astiastoa, varovasti!"],
	"clean": ["Kiiltää!", "Hyvä. Seuraava.", "Tuo on puhdas."],
	"break": ["Se oli mummon astiastosta!", "No voi... lattia on kova.", "Sirpaleet roskiin, ei mitään."],
	"lazy": ["Tuohon jäi vielä kahvinporoja.", "Pohjat kanssa!"],
	"done": ["Tiskit tehty! Kuivauskaappi täynnä."],
}

var dishes_left := DISHES.size()
var drunk := 0.0
var washed := 0
var broken := 0

var _root: Control
var _dirt := 1.0
var _last_dir := 0
var _wobble := 0.0
var _drop_t := -1.0
var _info: Label
var _done := false
var _spots: Array = []


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
	_new_dish()
	comment.emit(LINES.start.pick_random())


func _new_dish() -> void:
	_dirt = 1.0
	_spots.clear()
	for k in 9:
		_spots.append([Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)), randf_range(0.12, 0.26)])


func _dish() -> Array:
	return DISHES[DISHES.size() - dishes_left]


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseMotion and absf(event.relative.x) > 12.0:
		_scrub(1 if event.relative.x > 0.0 else -1)


func _process(delta: float) -> void:
	if _done:
		return
	_root.queue_redraw()
	_wobble = maxf(0.0, _wobble - delta * 2.0)
	if _drop_t >= 0.0:
		_drop_t += delta
		if _drop_t > 0.7:
			_drop_t = -1.0
			_next()
		return
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish()
		return
	if Input.is_action_just_pressed("left"):
		_scrub(-1)
	if Input.is_action_just_pressed("right"):
		_scrub(1)
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact"):
		_lift()
	_info.text = "Tiskit: %s · jäljellä %d · hankaa A/D (tai hiirtä edestakaisin) · välilyönti / E kuivauskaappiin · F lopettaa" % [
		_dish()[0], dishes_left]


func _scrub(dir: int) -> void:
	if dir == _last_dir or _drop_t >= 0.0:
		return
	_last_dir = dir
	_dirt = maxf(0.0, _dirt - SCRUB * randf_range(0.7, 1.2))
	_wobble = 1.0
	Sfx.play("water", -14.0, randf_range(1.3, 1.7))
	if _dirt <= 0.0 and randf() < 0.5:
		comment.emit(LINES.clean.pick_random())


func _lift() -> void:
	if _dirt > 0.15:
		comment.emit(LINES.lazy.pick_random())
		Sfx.play("alert", -12.0, 1.6)
		return
	# Märkä astia lipsahtaa humalassa (ja mummon kukkalautanen aina vähän helpommin).
	var slip := drunk * 0.45 + (0.08 if _dish()[0].begins_with("mummon") else 0.02)
	if randf() < slip:
		broken += 1
		_drop_t = 0.0
		Sfx.play("glass", 0.0, 0.7)
		comment.emit(LINES["break"].pick_random())
		return
	washed += 1
	Sfx.play("pickup", -8.0, 1.2)
	_next()


func _next() -> void:
	dishes_left -= 1
	if dishes_left <= 0:
		comment.emit(LINES.done[0])
		_finish()
		return
	_new_dish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit(washed, broken)
	queue_free()


func _draw_root() -> void:
	var sz := _root.size
	var c := sz / 2.0 + Vector2(0, 40)
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.45))
	# Tiskiallas: teräksinen allas ja vaahtoinen vesi.
	_root.draw_rect(Rect2(c - Vector2(330, 220), Vector2(660, 440)), Color(0.55, 0.57, 0.6))
	_root.draw_rect(Rect2(c - Vector2(300, 190), Vector2(600, 380)), Color(0.35, 0.45, 0.5))
	for k in 18:
		var a := k * 2.4
		_root.draw_circle(c + Vector2(cos(a) * (120 + k * 9), sin(a * 1.3) * 140), 16 + (k % 4) * 5, Color(1, 1, 1, 0.35))
	if _drop_t >= 0.0:
		var t := _drop_t / 0.7
		_root.draw_string(ThemeDB.fallback_font, c + Vector2(-90, -20 + t * 60), "KRÄSH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 56,
			Color(1, 0.3, 0.2, 1.0 - t))
		return
	var d: Array = _dish()
	var off := Vector2(sin(Time.get_ticks_msec() / 40.0) * 10.0 * _wobble, 0)
	var r := 150.0 if d[0] != "muki" and d[0] != "lasi" else 100.0
	_root.draw_circle(c + off, r, d[1])
	_root.draw_circle(c + off, r * 0.7, d[1].darkened(0.06))
	if d[0] == "mummon kukkalautanen":
		for k in 8:
			var a := k * TAU / 8.0
			_root.draw_circle(c + off + Vector2(cos(a), sin(a)) * r * 0.85, 10, Color(0.55, 0.3, 0.7))
	if d[0] == "kattila":
		_root.draw_rect(Rect2(c + off + Vector2(r - 10, -12), Vector2(110, 24)), Color(0.15, 0.15, 0.16))
	for s in _spots:
		_root.draw_circle(c + off + s[0] * r * 0.8, s[1] * r * 0.6, Color(0.42, 0.3, 0.15, _dirt * 0.85))
	# Puhtausmittari.
	var bar := Rect2(c + Vector2(-150, 200), Vector2(300, 18))
	_root.draw_rect(bar, Color(0.1, 0.1, 0.1, 0.8))
	_root.draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - _dirt), bar.size.y)), Color(0.4, 0.85, 0.5))
