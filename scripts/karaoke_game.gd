extends CanvasLayer
## Karaoke Siitarissa: sävelpalkit vierivät oikealta vasemmalle, ja oma ääni (pallo) pidetään palkin korkeudella
## W/S:llä (tai hiirellä). Sanat alhaalla, laulettava tavu korostettuna. Musiikki syntetisoidaan
## (AudioStreamGenerator): rumpu, basso, hiljainen ohjausmelodia ja pelaajan "ääni", joka laulaa pallon
## korkeudella, joten nuotin vierestä laulaminen kuuluu. Humala saa äänen huojumaan ja laahaamaan.
## Tulos 0…1 (osuma-aika / nuottien kesto) finished-signaalilla; line-signaali päivittää baarin ruudun.

signal finished(score: float)
signal line(text: String)

const W := 1280.0
const H := 720.0
const RATE := 22050.0
const BASE_HZ := 196.0  # G3: sävel 0
const SPAN := 14.0       # sävelalue ruudulla (puolisävelaskelia)
const LEAD := 2.4        # sisääntulo ennen ensimmäistä tavua
const SYL := 0.42        # tavun perusmitta (s)
const PX_PER_S := 260.0
const NOW_X := 320.0
const TOL := 0.9         # osuman toleranssi (puolisävelaskelia)
## Kappale "Mopolla Vaalaan" (oma sävellys): rivit tavuina [tavu, sävel, kesto tavuina]; "-" = sana jatkuu.
const SONG := [
	[["Mo-", 4, 1], ["pol-", 4, 1], ["la", 5, 1], ["Vaa-", 7, 2], ["laan,", 7, 2], ["Sii-", 9, 1], ["ta-", 7, 1], ["riin", 5, 3]],
	[["Jo-", 4, 1], ["ki", 5, 1], ["vir-", 7, 2], ["taa,", 5, 2], ["yö", 4, 2], ["on", 2, 1], ["nuo-", 4, 1], ["ri", 0, 3]],
	[["Päi-", 7, 1], ["vi", 7, 1], ["soit-", 9, 2], ["taa,", 7, 2], ["en", 11, 1], ["mä", 9, 1], ["vas-", 7, 2], ["taa", 5, 3]],
	[["Nor-", 4, 1], ["mi-", 5, 1], ["päi-", 7, 2], ["vä,", 9, 2], ["nor-", 7, 1], ["mi-", 5, 1], ["yyyy-", 4, 2], ["öö", 0, 4]],
]

## Raahen Kapteenin Kellarin kappale "Ruukin valot" (oma sävellys, raahelaisittain).
const SONG_RAAHE := [
	[["Ruu-", 4, 1], ["kin", 4, 1], ["va-", 5, 1], ["lot", 7, 2], ["syt-", 7, 1], ["tyy", 5, 1], ["yö-", 4, 2], ["hön", 2, 3]],
	[["Pek-", 4, 1], ["ka", 5, 1], ["to-", 7, 2], ["ril-", 5, 1], ["la", 4, 1], ["vah-", 2, 1], ["tii", 4, 1], ["merta", 0, 3]],
	[["Skoo-", 7, 1], ["li,", 7, 1], ["ka-", 9, 2], ["ve-", 7, 1], ["rit,", 11, 1], ["Kel-", 9, 1], ["la-", 7, 2], ["rissa", 5, 3]],
	[["Raa-", 4, 1], ["hen", 5, 1], ["yö", 7, 2], ["on", 9, 2], ["te-", 7, 1], ["rästä", 5, 1], ["ja", 4, 2], ["laulua", 0, 4]],
]

var drunk := 0.0
var score := 0.0
var song: Array = SONG  # laulettava kappale (rivit tavuina)

var _notes: Array = []  # [alku, kesto, sävel, tavu, rivi]
var _total_len := 0.0
var _hit_time := 0.0
var _t := -0.5
var _pitch := 6.0
var _wobble_t := 0.0
var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _ph_voice := 0.0
var _ph_guide := 0.0
var _ph_bass := 0.0
var _ph_kick := 0.0
var _audio_t := 0.0
var _voice_hz := 0.0
var _draw_node: Control
var _lyrics: Label
var _info: Label
var _keys: Control
var _last_line := -1
var _done := false
var _hit_now := false
var _mouse_used := false


func _ready() -> void:
	layer = 20
	var t := LEAD
	for li in song.size():
		for syl in song[li]:
			var d: float = syl[2] * SYL
			_notes.append([t, d * 0.92, float(syl[1]), syl[0], li])
			_total_len += d * 0.92
			t += d
		t += SYL * 2.0  # hengitystauko rivien välissä
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.08, 0.86)
	bg.position = Vector2(0, 60)
	bg.size = Vector2(W, 470)
	add_child(bg)
	_draw_node = Control.new()
	_draw_node.size = Vector2(W, H)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_draw_chart)
	add_child(_draw_node)
	_lyrics = Label.new()
	_lyrics.position = Vector2(0, 545)
	_lyrics.size = Vector2(W, 80)
	_lyrics.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lyrics.add_theme_font_size_override("font_size", 44)
	_lyrics.add_theme_color_override("font_outline_color", Color.BLACK)
	_lyrics.add_theme_constant_override("outline_size", 10)
	add_child(_lyrics)
	_info = Label.new()
	_info.position = Vector2(20, 14)
	_info.add_theme_font_size_override("font_size", 26)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 8)
	add_child(_info)
	_keys = preload("res://scripts/hint_bar.gd").new()  # näppäinohjeet hattuina, näppäimet asetuksista
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_keys.set_text("%s pidä pallo palkin korkeudella (tai hiiri)" % Settings.pair("forward", "back"))
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -4.0
	_player.bus = "SFX"
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_used = true


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	# Oma ääni: W/S liikuttaa, hiiri asettaa suoraan. Humalassa ääni huojuu ja reagoi laahaten.
	var target := _pitch
	var axis := Input.get_axis("back", "forward")
	if absf(axis) > 0.05:
		_mouse_used = false
		target += axis * 16.0 * delta
	elif _mouse_used:
		target = _y_to_pitch(_draw_node.get_local_mouse_position().y)
	_wobble_t += delta
	var wob := (sin(_wobble_t * 2.3) * 0.7 + sin(_wobble_t * 5.1 + 1.0) * 0.3) * drunk * 2.2
	_pitch = clampf(lerpf(_pitch, target, 1.0 - exp(-lerpf(30.0, 5.0, drunk) * delta)), -1.0, SPAN - 1.0)
	var sung := _pitch + wob
	var cur: Array = _note_at(_t)
	_hit_now = false
	if not cur.is_empty() and absf(sung - float(cur[2])) < TOL:
		_hit_time += delta
		_hit_now = true
	_voice_hz = BASE_HZ * pow(2.0, sung / 12.0) if not cur.is_empty() else 0.0
	var li := -1
	for n in _notes:
		if _t < n[0] + n[1] + SYL * 2.0:
			li = n[4]
			break
	if li != _last_line and li >= 0:
		_last_line = li
		line.emit(_line_text(li, []))
	_update_lyrics(cur)
	_info.text = "KARAOKE · Mopolla Vaalaan    %d %%" % roundi(_hit_time / _total_len * 100.0)
	_fill_audio()
	_draw_node.queue_redraw()
	var end: float = _notes[-1][0] + _notes[-1][1] + 1.2
	if _t > end:
		_done = true
		score = clampf(_hit_time / _total_len, 0.0, 1.0)
		_player.stop()
		finished.emit(score)


func _note_at(t: float) -> Array:
	for n in _notes:
		if t >= n[0] and t < n[0] + n[1]:
			return n
	return []


func _update_lyrics(cur: Array) -> void:
	if _last_line < 0:
		_lyrics.text = ""
		return
	_lyrics.text = _line_text(_last_line, cur)
	_lyrics.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2) if _hit_now else Color(1, 1, 1))


## Rivin sanat tavuista (laulettava tavu isolla hakasulkeissa).
func _line_text(li: int, cur: Array) -> String:
	var txt := ""
	for syl in song[li]:
		var s: String = syl[0]
		var joined := s.ends_with("-")
		s = s.trim_suffix("-")
		if not cur.is_empty() and cur[3] == syl[0] and cur[4] == li:
			s = "[" + s.to_upper() + "]"
		txt += s + ("" if joined else " ")
	return txt.strip_edges()


func _pitch_to_y(p: float) -> float:
	return 500.0 - (p + 1.0) / SPAN * 400.0


func _y_to_pitch(y: float) -> float:
	return (500.0 - y) / 400.0 * SPAN - 1.0


func _draw_chart() -> void:
	var c := _draw_node
	c.draw_line(Vector2(NOW_X, 80), Vector2(NOW_X, 520), Color(1, 1, 1, 0.5), 2.0)
	for n in _notes:
		var x0: float = NOW_X + (n[0] - _t) * PX_PER_S
		var x1: float = x0 + n[1] * PX_PER_S
		if x1 < 0.0 or x0 > W:
			continue
		var y := _pitch_to_y(n[2])
		var passed: bool = n[0] + n[1] < _t
		var col := Color(0.35, 0.8, 1.0) if not passed else Color(0.3, 0.35, 0.5)
		c.draw_rect(Rect2(x0, y - 11.0, x1 - x0, 22.0), col)
		c.draw_string(ThemeDB.fallback_font, Vector2(x0 + 4.0, y - 16.0), (n[3] as String).trim_suffix("-"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.8))
	var wob := (sin(_wobble_t * 2.3) * 0.7 + sin(_wobble_t * 5.1 + 1.0) * 0.3) * drunk * 2.2
	var py := _pitch_to_y(_pitch + wob)
	c.draw_circle(Vector2(NOW_X, py), 15.0, Color(1.0, 0.85, 0.1) if _hit_now else Color(1.0, 0.35, 0.3))
	c.draw_circle(Vector2(NOW_X, py), 6.0, Color(1, 1, 1))
	if _t < LEAD:
		c.draw_string(ThemeDB.fallback_font, Vector2(W / 2.0 - 30.0, 330), str(ceili(LEAD - _t)), HORIZONTAL_ALIGNMENT_LEFT, -1, 90, Color.WHITE)


## Syntetisoitu säestys: rumpu (vaimeneva sini) ja basso tahdissa, ohjausmelodia hiljaa, oma ääni sahalaitana.
func _fill_audio() -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	var beat := SYL * 2.0
	var cur: Array = _note_at(_t)
	var guide_hz: float = BASE_HZ * pow(2.0, float(cur[2]) / 12.0) if not cur.is_empty() else 0.0
	for i in n:
		_audio_t += 1.0 / RATE
		var bt := fmod(maxf(_audio_t - 0.1, 0.0), beat)
		var kick := sin(_ph_kick) * exp(-bt * 18.0) * 0.5
		_ph_kick += TAU * (55.0 + 90.0 * exp(-bt * 30.0)) / RATE
		var bar := int(_audio_t / (beat * 4.0)) % 4
		var bass_hz: float = [98.0, 130.8, 110.0, 146.8][bar]
		_ph_bass = fmod(_ph_bass + bass_hz / RATE, 1.0)
		var bass := (absf(_ph_bass * 2.0 - 1.0) * 2.0 - 1.0) * 0.18
		var s := kick + bass
		if guide_hz > 0.0:
			_ph_guide = fmod(_ph_guide + guide_hz / RATE, 1.0)
			s += sin(_ph_guide * TAU) * 0.07
		if _voice_hz > 0.0:
			_ph_voice = fmod(_ph_voice + _voice_hz / RATE, 1.0)
			var saw := _ph_voice * 2.0 - 1.0
			var sq := 1.0 if _ph_voice < 0.5 else -1.0
			s += (saw * 0.6 + sq * 0.4) * 0.12
		_pb.push_frame(Vector2(s, s))
