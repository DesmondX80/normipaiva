extends CanvasLayer
## Valentin Vaala -elokuvapäivien esitys Vaalan Veturitallilla (#250 P14): mykkäelokuvan tyylinen sepiakuva
## (maisema, kulkeva hahmo, rakeet, naarmut, välkyntä), välitekstit ja vanhan 78-levyn iskelmä taustalla.
## Ohjelma on yleinen: ei väitettyjä elokuvien nimiä. Esc / F lopettaa. finished(watched) kertoo, katsottiinko loppuun.

signal finished(watched: bool)

const Iskelmat := preload("res://scripts/iskelmat.gd")

const LENGTH := 26.0
const CARDS := [
	[0.0, "VALENTIN VAALA 1909-1976\nARKISTOELOKUVIA"],
	[7.0, "Kylällä oli vilskettä.\nTanssit pidettiin aina lauantaina."],
	[14.0, "Ja sitten tuli kesä,\nkuten aina ennenkin."],
	[21.0, "LOPPU"],
]

var music_path := ""
var _root: Control
var _t := 0.0
var _done := false
var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 60
	_rng.seed = 78
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_paint)
	add_child(_root)
	if music_path != "":
		_player = AudioStreamPlayer.new()
		_player.stream = Iskelmat.stream(music_path)
		_player.volume_db = -6.0
		add_child(_player)
		_player.play()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_root.queue_redraw()
	if _t >= LENGTH:
		_end(true)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e.keycode == KEY_ESCAPE or e.keycode == KEY_F):
		get_viewport().set_input_as_handled()
		_end(false)


func _end(watched: bool) -> void:
	if _done:
		return
	_done = true
	if _player != null:
		_player.stop()
	finished.emit(watched)
	queue_free()


func _paint() -> void:
	var sz := _root.size
	var sep := Color(0.82, 0.7, 0.5)
	var dark := Color(0.12, 0.08, 0.05)
	var flick := 0.92 + 0.08 * sin(_t * 47.0) * _rng.randf()
	# Pimeä sali ja valkokangas (4:3, kehys).
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.02, 0.02))
	var fh := minf(sz.y * 0.82, sz.x * 0.72 * 0.75)
	var fr := Rect2((sz.x - fh * 1.333) / 2.0, (sz.y - fh) / 2.0, fh * 1.333, fh)
	_root.draw_rect(fr.grow(10), Color(0.25, 0.2, 0.15))
	# Taivas ja mäet.
	_root.draw_rect(fr, sep.lerp(Color.WHITE, 0.35) * flick)
	for k in 3:
		var pts := PackedVector2Array([fr.position + Vector2(0, fr.size.y * (0.6 - 0.06 * k))])
		for i in 13:
			var x := fr.size.x * i / 12.0
			pts.append(fr.position + Vector2(x, fr.size.y * (0.55 - 0.05 * k) - 18.0 * sin(i * 0.9 + k * 2.0) * (k + 1)))
		pts.append(fr.position + Vector2(fr.size.x, fr.size.y * 0.8))
		pts.append(fr.position + Vector2(0, fr.size.y * 0.8))
		_root.draw_colored_polygon(pts, dark.lerp(sep, 0.45 + 0.17 * k) * flick)
	_root.draw_rect(Rect2(fr.position.x, fr.position.y + fr.size.y * 0.78, fr.size.x, fr.size.y * 0.22), dark.lerp(sep, 0.3) * flick)
	# Aurinko ja kulkeva hahmo.
	_root.draw_circle(fr.position + Vector2(fr.size.x * 0.78, fr.size.y * 0.2), fr.size.y * 0.07, Color(1, 0.97, 0.88))
	var px := fr.position.x + fr.size.x * fposmod(_t / 22.0, 1.0)
	var py := fr.position.y + fr.size.y * 0.78
	var bob := absf(sin(_t * 7.0)) * 4.0
	var u := fr.size.y / 10.0
	var body := dark
	_root.draw_rect(Rect2(px - u * 0.28, py - u * 1.6 - bob, u * 0.56, u * 1.0), body)
	_root.draw_circle(Vector2(px, py - u * 1.85 - bob), u * 0.3, body)
	_root.draw_line(Vector2(px - u * 0.12, py - u * 0.6 - bob), Vector2(px - u * 0.12 + sin(_t * 7.0) * u * 0.3, py), body, 5.0)
	_root.draw_line(Vector2(px + u * 0.12, py - u * 0.6 - bob), Vector2(px + u * 0.12 - sin(_t * 7.0) * u * 0.3, py), body, 5.0)
	# Rakeet, naarmut ja reunan tummennus.
	for i in 60:
		var q := fr.position + Vector2(_rng.randf() * fr.size.x, _rng.randf() * fr.size.y)
		_root.draw_circle(q, _rng.randf_range(0.8, 2.2), Color(1, 1, 1, 0.25) if i % 2 == 0 else Color(0, 0, 0, 0.3))
	if _rng.randf() < 0.5:
		var sx := fr.position.x + _rng.randf() * fr.size.x
		_root.draw_line(Vector2(sx, fr.position.y), Vector2(sx + _rng.randf_range(-3, 3), fr.end.y), Color(1, 1, 1, 0.25), 1.0)
	for k in 8:
		_root.draw_rect(fr.grow(-k * 3.0), Color(0, 0, 0, 0.045), false, 6.0)
	# Väliteksti.
	var card := ""
	var start := 0.0
	for c in CARDS:
		if _t >= c[0]:
			card = c[1]
			start = c[0]
	if _t - start < 5.0 or card == "LOPPU":
		var f: Font = ThemeDB.fallback_font
		var cr := Rect2(fr.position.x + fr.size.x * 0.1, fr.position.y + fr.size.y * 0.3, fr.size.x * 0.8, fr.size.y * 0.4)
		_root.draw_rect(cr, Color(0.05, 0.04, 0.03, 0.88))
		_root.draw_rect(cr.grow(-6), Color(0.85, 0.78, 0.6), false, 2.0)
		var lines := card.split("\n")
		for i in lines.size():
			var w := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
			_root.draw_string(f, Vector2(cr.get_center().x - w / 2.0, cr.position.y + cr.size.y * 0.42 + i * 46.0), lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.93, 0.88, 0.72))
	_root.draw_string(ThemeDB.fallback_font, Vector2(20, sz.y - 16), "Esc: poistu salista", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.65, 0.55))
