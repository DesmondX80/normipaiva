extends CanvasLayer
## Karaoke Siitarissa ja Kapteenin Kellarissa, Frets on Fire -tyylinen näppäily: neljä nuottiraitaa (A S K L tai nuolet)
## laskeutuvat kaistaa pitkin osumalinjalle, ja nuotti painetaan tahtiin (laulettavan tavun alkaessa). Pitkät nuotit
## pidetään pohjassa loppuun asti. Sanat alhaalla, laulettava tavu korostettuna. Osuma-ajan mukaan putki (combo) ja
## kerroin kasvavat, ohi menneet ja väärät näppäilyt katkaisevat putken. Humala nykii nuottien paikkaa ja viivästää
## painalluksia. Tulos 0…1 (osumien laatu / nuotit, pitkistä pitämisen bonus) finished-signaalilla; line-signaali
## päivittää baarin ruudun.
## Kappale valitaan valikosta (menu_titles): paikan oma kappale (nuotit tavuista, sävelkorkeus → kaista, melodia
## syntetisoidaan: osuma laulaa nuotin) tai tunnari "Normipäivä Saloisissa" lyhennettynä oikealla soittoraidalla
## (normipaiva_lyhyt.mp3, sanat sana sanalta normipaiva_sanat_lyhyt.json; kaista arvotaan sanasta).

signal finished(score: float)
signal line(text: String)

const W := 1280.0
const H := 720.0
const RATE := 22050.0
const BASE_HZ := 196.0  # G3: sävel 0
const LEAD := 2.4  # sisääntulo ennen ensimmäistä nuottia
const SYL := 0.42  # tavun perusmitta (s)
const LANES := 4
const LANE_KEYS := [[KEY_A, KEY_LEFT], [KEY_S, KEY_DOWN], [KEY_K, KEY_UP], [KEY_L, KEY_RIGHT]]
const LANE_NAMES := ["A", "S", "K", "L"]
const LANE_COLS := [Color(0.25, 0.85, 0.3), Color(0.95, 0.25, 0.25), Color(1.0, 0.85, 0.2), Color(0.3, 0.55, 1.0)]
const WIN_PERFECT := 0.08  # osumaikkunat (s)
const WIN_GOOD := 0.15
const WIN_OK := 0.25
const SPEED := 1.9  # nuotin näkymisaika kaistan yläreunasta osumalinjalle (s)
const HOLD_MIN := 0.55  # tätä pidempi nuotti pidetään pohjassa
const REAL_TRACK := "res://assets/music/normipaiva_lyhyt.mp3"
const REAL_LYRICS := "res://assets/music/normipaiva_sanat_lyhyt.json"
## Kaista (osumalinja alhaalla, yläreuna kaukana): suorakulmio kuvassa ja perspektiivi.
const TOP_Y := 96.0
const HIT_Y := 478.0
const TOP_W := 250.0
const BOT_W := 470.0

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
var cancelled := false  # valikosta pois ennen kappaletta (F/Esc): ei esitystä, maksu palautetaan
var song: Array = SONG  # laulettava kappale (rivit tavuina)
var menu_titles: Array = []  # [[avain, nimi, kuvaus]]: kappalevalikko ennen laulua; tyhjä = suoraan song-kappaleeseen
var real := false  # aito (lyhennetty) versio: oikea soittoraita, ajoitetut sanat

# Nuotti: {t, dur, lane, pitch, text, line, wi, state ("odottaa"/"osuma"/"ohi"), q (laatu 0..1), held (pitoaika), hold (pidossa)}
var _notes: Array = []
var _t := -0.5
var _title := "Mopolla Vaalaan"
var _menu := false
var _menu_i := 0
var _menu_rects: Array[Rect2] = []
var _real_lines: Array = []
var _track: AudioStreamPlayer
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
var _down := [false, false, false, false]
var _flash := [0.0, 0.0, 0.0, 0.0]  # painikkeen välähdys (osuma)
var _burst: Array = []  # osumakipinät [lane, aika, laatu]
var _combo := 0
var _best_combo := 0
var _meter := 0.5  # yleisömittari 0..1
var _sum := 0.0
var _hit := 0
var _miss := 0
var _judge := ""
var _judge_t := 0.0
var _lag := 0.0  # humalan painallusviive (s)
var _total_w := 0.0
var _end := 0.0
var _bar := 0.0  # tahdin pituus (s), kaistan tahtiviivoille


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	layer = 20
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
	if menu_titles.is_empty():
		_begin()
	else:
		_menu = true
		_keys.set_text("%s valitse · E / Enter / klikkaus aloittaa · %s / Esc takaisin" % [Settings.pair("forward", "back"), Settings.cap("mount")])


## Kappalevalikko: paikan oma kappale ja aito versio.
static func menu_for(own_title: String) -> Array:
	return [["oma", own_title, "Oma sävellys: näppäile nuotit tahtiin (A S K L tai nuolet), melodia syntetisoidaan."],
		["aito", "Normipäivä Saloisissa (lyhennetty aito versio)", "Tunnari oikealla soittoraidalla, noin minuutti: näppäile sanat tahtiin (A S K L tai nuolet), pitkät sanat pidetään pohjassa. Esc lopettaa."]]


# --- Kappaleen rakennus --------------------------------------------------------------------------------------------

func _begin() -> void:
	_menu = false
	_notes.clear()
	if real and not _build_real_notes():
		real = false  # sanatiedosto tai raita puuttuu: oma kappale
	if not real:
		_build_own_notes()
	_total_w = 0.0  # täydet pisteet: kaikki täydellisiä ja pitkät pidetty loppuun
	for n in _notes:
		_total_w += 1.5 if float(n.dur) > 0.0 else 1.0
	var last: Dictionary = _notes[_notes.size() - 1]
	_end = float(last.t) + float(last.dur) + 1.4
	if real:
		_t = 0.0
		_track = AudioStreamPlayer.new()
		_track.stream = load(REAL_TRACK)
		_track.volume_db = -4.0
		_track.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
		add_child(_track)
		_track.play()
		_bar = 0.4068 * 4.0  # tunnarin tahti (n. 147,5 bpm)
	else:
		_t = -0.5
		_bar = SYL * 2.0 * 4.0
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
	_keys.set_text("%s näppäile nuotit tahtiin · pitkät pohjassa · %s lopeta" % ["A S K L / ←↓↑→", Settings.cap("mount")])


func _build_own_notes() -> void:
	var t := LEAD
	for li in song.size():
		for wi in (song[li] as Array).size():
			var syl: Array = song[li][wi]
			var d: float = syl[2] * SYL
			_notes.append(_note(t, d * 0.92, clampi(int(syl[1]) / 3, 0, LANES - 1), float(syl[1]), syl[0], li, wi))
			t += d
		t += SYL * 2.0  # hengitystauko rivien välissä


func _note(t: float, dur: float, lane: int, pitch: float, text: String, li: int, wi: int) -> Dictionary:
	return {"t": t, "dur": dur if dur >= HOLD_MIN else 0.0, "lane": lane, "pitch": pitch, "text": text, "line": li, "wi": wi,
		"state": "odottaa", "q": 0.0, "held": 0.0, "hold": false, "len": dur}


## Aito: sanat ja ajoitukset JSON:ista (peliaika = raidan aika). Kaista arvotaan sanasta, ei kolmea samaa peräkkäin.
func _build_real_notes() -> bool:
	var f := FileAccess.open(REAL_LYRICS, FileAccess.READ)
	if f == null or not ResourceLoader.exists(REAL_TRACK):
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary) or not d.has("lines"):
		return false
	_real_lines.clear()
	var prev := -1
	var same := 0
	for li in (d.lines as Array).size():
		var ws: Array = []
		for wi in (d.lines[li].words as Array).size():
			var w: Array = d.lines[li].words[wi]
			var h := 0
			for ch in (w[0] as String):
				h = (h * 31 + ch.unicode_at(0)) % 9973
			var lane := (h + li * 3 + wi * 2) % LANES
			if lane == prev:
				same += 1
				if same >= 2:
					lane = (lane + 1 + (h % 3)) % LANES
					same = 0
			else:
				same = 0
			prev = lane
			var dur := float(w[2]) - float(w[1])
			_notes.append(_note(float(w[1]), dur * 0.9, lane, 6.0, w[0], li, wi))
			ws.append(w[0])
		_real_lines.append(ws)
	return true


# --- Syöte ------------------------------------------------------------------------------------------------------

func _choose(i: int) -> void:
	if not _menu:
		return
	var e: Array = menu_titles[i]
	real = e[0] == "aito"
	_title = e[1]
	Sfx.play("pickup", -6.0)
	_begin()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if _menu:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_W, KEY_UP:
					_menu_i = (_menu_i + menu_titles.size() - 1) % menu_titles.size()
				KEY_S, KEY_DOWN:
					_menu_i = (_menu_i + 1) % menu_titles.size()
				KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_SPACE:
					_choose(_menu_i)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for i in _menu_rects.size():
				if _menu_rects[i].has_point(_draw_node.get_local_mouse_position()):
					_menu_i = i
					_choose(i)
		return
	if event is InputEventKey and not event.echo:
		for lane in LANES:
			if event.keycode in LANE_KEYS[lane] or event.physical_keycode in LANE_KEYS[lane]:
				if event.pressed:
					lane_press(lane)
				else:
					lane_release(lane)


## Raidan painallus (myös testit kutsuvat): osuu lähimpään nuottiin ikkunan sisällä, muuten putki katkeaa.
func lane_press(lane: int, at := -1.0) -> void:
	if _menu or _done or _down[lane]:
		return
	_down[lane] = true
	_flash[lane] = 1.0
	var t := (at if at >= 0.0 else _t) - _lag  # humalan painallusviive
	var best: Dictionary = {}
	var bd := WIN_OK + 0.0001
	for n in _notes:
		if n.lane != lane or n.state != "odottaa":
			continue
		var dt := absf(float(n.t) - t)
		if dt < bd:
			bd = dt
			best = n
	if best.is_empty():
		_break_combo("Ohi!")
		Sfx.play("bike_fall", -22.0, 1.6)
		return
	best.state = "osuma"
	best.q = 1.0 if bd <= WIN_PERFECT else (0.75 if bd <= WIN_GOOD else 0.5)
	best.hold = float(best.dur) > 0.0
	_hit += 1
	_combo += 1
	_best_combo = maxi(_best_combo, _combo)
	_meter = minf(1.0, _meter + 0.04)
	_sum += float(best.q)
	_judge = "TÄYDELLINEN!" if best.q >= 1.0 else ("HYVÄ" if best.q >= 0.75 else "OK")
	_judge_t = 0.6
	_burst.append([lane, 0.0, best.q])
	Sfx.play("pickup", -18.0, 1.0 + lane * 0.12)
	if not real:
		_voice_hz = BASE_HZ * pow(2.0, float(best.pitch) / 12.0)


func lane_release(lane: int) -> void:
	_down[lane] = false
	if not real:
		_voice_hz = 0.0


func _break_combo(text: String) -> void:
	_combo = 0
	_meter = maxf(0.0, _meter - 0.07)
	_judge = text
	_judge_t = 0.5


func _multiplier() -> int:
	return clampi(1 + _combo / 8, 1, 4)


# --- Peli -------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _done:
		return
	if _menu:
		_info.text = "KARAOKE · valitse kappale"
		_draw_node.queue_redraw()
		if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
			cancelled = true
			_done = true
			finished.emit(0.0)
		return
	_t += delta
	if real and _track != null and _track.playing:
		var tp := _track.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		if absf(tp - _t) > 0.12:
			_t = lerpf(_t, tp, 0.25)
	_lag = drunk * 0.07 * (0.5 + 0.5 * sin(_t * 2.1))
	for i in LANES:
		_flash[i] = maxf(_flash[i] - delta * 5.0, 0.0)
	_judge_t = maxf(_judge_t - delta, 0.0)
	for b in _burst:
		b[1] += delta
	_burst = _burst.filter(func(b: Array) -> bool: return b[1] < 0.5)
	var cur_text: Dictionary = {}
	for n in _notes:
		match n.state:
			"odottaa":
				if _t - float(n.t) > WIN_OK:
					n.state = "ohi"
					_miss += 1
					_break_combo("Huti")
			"osuma":
				if n.hold:
					# Pitkä nuotti: pidä kaistan näppäintä pohjassa loppuun asti.
					if _t >= float(n.t) + float(n.dur):
						n.hold = false
						_sum += 0.5 * clampf(float(n.held) / float(n.dur), 0.0, 1.0)
						_meter = minf(1.0, _meter + 0.02)
					elif _down[n.lane]:
						n.held += delta
					else:
						n.hold = false  # päästetty irti kesken
						_sum += 0.5 * clampf(float(n.held) / float(n.dur), 0.0, 1.0)
						_break_combo("Irti!")
		if _t >= float(n.t) - 0.05 and _t < float(n.t) + maxf(float(n.dur), float(n.len)) + 0.5:
			cur_text = n
	var li := -1
	for n in _notes:
		if _t < float(n.t) + float(n.len) + SYL * 2.0:
			li = int(n.line)
			break
	if li != _last_line and li >= 0:
		_last_line = li
		line.emit(_line_text(li, {}))
	_update_lyrics(cur_text)
	var pct := roundi(_current_score() * 100.0)
	_info.text = "KARAOKE · %s    %d %%    Putki %d  ×%d" % [_title, pct, _combo, _multiplier()]
	if not real:
		_fill_audio()
	_draw_node.queue_redraw()
	if _t > _end or Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish()


func _current_score() -> float:
	return clampf(_sum / maxf(_total_w, 0.001), 0.0, 1.0)


func _finish() -> void:
	_done = true
	score = _current_score()
	if _track != null:
		_track.stop()
	if _player != null:
		_player.stop()
	finished.emit(score)


func _update_lyrics(cur: Dictionary) -> void:
	if _last_line < 0:
		_lyrics.text = ""
		return
	_lyrics.text = _line_text(_last_line, cur)
	var hot: bool = not cur.is_empty() and cur.state == "osuma"
	_lyrics.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2) if hot else Color(1, 1, 1))


## Rivin sanat (laulettava sana tai tavu isolla hakasulkeissa).
func _line_text(li: int, cur: Dictionary) -> String:
	if real:
		var parts: Array[String] = []
		for wi in (_real_lines[li] as Array).size():
			var w: String = _real_lines[li][wi]
			if not cur.is_empty() and cur.line == li and cur.wi == wi:
				w = "[" + w.to_upper() + "]"
			parts.append(w)
		return " ".join(parts)
	var txt := ""
	for wi in (song[li] as Array).size():
		var syl: Array = song[li][wi]
		var s: String = syl[0]
		var joined := s.ends_with("-")
		s = s.trim_suffix("-")
		if not cur.is_empty() and cur.line == li and cur.wi == wi:
			s = "[" + s.to_upper() + "]"
		txt += s + ("" if joined else " ")
	return txt.strip_edges()


# --- Piirto -----------------------------------------------------------------------------------------------------

## Perspektiivi: u = 0 yläreunassa (kaukana), 1 osumalinjalla; palauttaa [y, mittakaava].
func _persp(u: float) -> Array:
	var s := lerpf(TOP_W / BOT_W, 1.0, u * u * 0.4 + u * 0.6)
	return [lerpf(TOP_Y, HIT_Y, u), s]


func _lane_x(lane: int, s: float) -> float:
	return W / 2.0 + (lane - 1.5) * (BOT_W / LANES) * s


func _draw_chart() -> void:
	var c := _draw_node
	if _menu:
		_draw_menu()
		return
	var f := ThemeDB.fallback_font
	var wob := Vector2(sin(_t * 3.1), cos(_t * 2.3)) * drunk * 7.0
	# Kaista: tumma sävytetty puolisuunnikas, reunaviivat ja tahtiviivat.
	var top := _persp(0.0)
	var bot := _persp(1.0)
	var poly := PackedVector2Array([Vector2(_lane_x(0, top[1]) - BOT_W / LANES * 0.5 * top[1], top[0]), Vector2(_lane_x(3, top[1]) + BOT_W / LANES * 0.5 * top[1], top[0]),
		Vector2(_lane_x(3, bot[1]) + BOT_W / LANES * 0.5, bot[0]), Vector2(_lane_x(0, bot[1]) - BOT_W / LANES * 0.5, bot[0])])
	c.draw_colored_polygon(poly, Color(0.06, 0.05, 0.12, 0.9))
	for k in LANES + 1:
		var a := Vector2(_lane_x(0, top[1]) - BOT_W / LANES * 0.5 * top[1] + k * BOT_W / LANES * top[1], top[0])
		var b := Vector2(_lane_x(0, bot[1]) - BOT_W / LANES * 0.5 + k * BOT_W / LANES, bot[0])
		c.draw_line(a, b, Color(0.55, 0.6, 0.85, 0.5), 2.0)
	var beat := _bar / 4.0
	var first := floorf(_t / beat) * beat
	for k in range(0, 8):
		var bt := first + k * beat
		var uu := 1.0 - (bt - _t) / SPEED
		if uu < 0.0 or uu > 1.0:
			continue
		var p := _persp(uu)
		var strong := int(roundf(bt / beat)) % 4 == 0
		c.draw_line(Vector2(_lane_x(0, p[1]) - BOT_W / LANES * 0.5 * p[1], p[0]), Vector2(_lane_x(3, p[1]) + BOT_W / LANES * 0.5 * p[1], p[0]),
			Color(1, 1, 1, 0.28 if strong else 0.1), 3.0 * p[1] if strong else 1.5)
	# Nuotit: kaukaa osumalinjalle, pitkien hännät ensin.
	for n in _notes:
		var t0 := float(n.t)
		var u0 := 1.0 - (t0 - _t) / SPEED
		if u0 < -0.4:
			continue
		var u1 := 1.0 - (t0 + float(n.dur) - _t) / SPEED
		if u1 > 1.2 and u0 > 1.2:
			continue
		var lane: int = n.lane
		var col: Color = LANE_COLS[lane]
		if n.state == "ohi":
			col = Color(0.35, 0.35, 0.4)
		if float(n.dur) > 0.0 and u1 < 1.0:
			var y_to := clampf(u0, 0.0, 1.0)
			var y_from := clampf(u1, 0.0, 1.0)
			var pt := _persp(y_from)
			var pb := _persp(y_to)
			var wt: float = 12.0 * float(pt[1])
			var wb: float = 12.0 * float(pb[1])
			var bright := 1.0 if (n.state == "osuma" and n.hold) else 0.55
			var tc := Color(col.r, col.g, col.b, bright * (0.9 if n.state != "ohi" else 0.4))
			c.draw_colored_polygon(PackedVector2Array([Vector2(_lane_x(lane, pt[1]) - wt, pt[0]), Vector2(_lane_x(lane, pt[1]) + wt, pt[0]),
				Vector2(_lane_x(lane, pb[1]) + wb, pb[0]), Vector2(_lane_x(lane, pb[1]) - wb, pb[0])]), tc)
		if n.state == "osuma":
			continue
		var uc := clampf(u0, 0.0, 1.05)
		var pc := _persp(uc)
		var jitter := Vector2(sin(t0 * 7.0), 0) * drunk * 6.0
		var pos := Vector2(_lane_x(lane, pc[1]), pc[0]) + wob + jitter
		var r: float = 26.0 * float(pc[1])
		c.draw_circle(pos + Vector2(0, 3.0 * pc[1]), r, Color(0, 0, 0, 0.45))
		c.draw_circle(pos, r, col.darkened(0.25))
		c.draw_circle(pos, r * 0.78, col)
		c.draw_circle(pos - Vector2(r * 0.25, r * 0.3), r * 0.28, Color(1, 1, 1, 0.55))
		c.draw_arc(pos, r, 0.0, TAU, 28, Color(1, 1, 1, 0.9 if n.state == "odottaa" else 0.3), 2.5 * pc[1], true)
		if float(n.dur) > 0.0:
			c.draw_circle(pos, r * 0.2, Color(1, 1, 1, 0.9))
	# Osumalinja ja painikkeet.
	var hp := _persp(1.0)
	c.draw_line(Vector2(_lane_x(0, 1.0) - BOT_W / LANES * 0.5, hp[0]), Vector2(_lane_x(3, 1.0) + BOT_W / LANES * 0.5, hp[0]), Color(1, 1, 1, 0.6), 3.0)
	for lane in LANES:
		var col: Color = LANE_COLS[lane]
		var pos := Vector2(_lane_x(lane, 1.0), hp[0]) + wob
		var fl: float = _flash[lane]
		var down: bool = _down[lane]
		c.draw_circle(pos, 31.0, Color(0, 0, 0, 0.6))
		c.draw_circle(pos, 29.0 + 4.0 * fl, col.lightened(0.5 * fl) if down else col.darkened(0.45))
		c.draw_arc(pos, 29.0, 0.0, TAU, 28, Color(1, 1, 1, 0.9 if down else 0.55), 3.0, true)
		c.draw_string(f, pos + Vector2(-9, 9), LANE_NAMES[lane], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.95))
	for b in _burst:
		var pos := Vector2(_lane_x(int(b[0]), 1.0), hp[0]) + wob
		var k: float = b[1] / 0.5
		for i in 8:
			var ang: float = TAU * i / 8.0 + float(b[1]) * 3.0
			c.draw_circle(pos + Vector2(cos(ang), sin(ang)) * (24.0 + 46.0 * k), 4.0 * (1.0 - k), Color(LANE_COLS[int(b[0])].lightened(0.4), 1.0 - k))
	# Tuomio ja putki.
	if _judge_t > 0.0:
		var a := clampf(_judge_t / 0.3, 0.0, 1.0)
		c.draw_string(f, Vector2(0, 300 - (0.6 - _judge_t) * 40.0), _judge, HORIZONTAL_ALIGNMENT_CENTER, W, 40, Color(1, 0.95, 0.5, a))
	# Yleisömittari (vasemmalla): vihreä hyvä, punainen huono.
	var mx := 70.0
	c.draw_rect(Rect2(mx, 120, 26, 340), Color(0, 0, 0, 0.6))
	var mh := 340.0 * _meter
	c.draw_rect(Rect2(mx, 120 + 340 - mh, 26, mh), Color(0.9, 0.2, 0.2).lerp(Color(0.3, 0.9, 0.35), _meter))
	c.draw_string(f, Vector2(mx - 20, 108), "YLEISÖ", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))
	# Kerroin ja pisteet (oikealla).
	var rx := W - 220.0
	c.draw_string(f, Vector2(rx, 150), "× %d" % _multiplier(), HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(1.0, 0.85, 0.3))
	c.draw_string(f, Vector2(rx, 200), "Putki %d" % _combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	c.draw_string(f, Vector2(rx, 236), "Paras %d" % _best_combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.7))
	c.draw_string(f, Vector2(rx, 272), "Osumia %d / %d" % [_hit, _notes.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.7))
	if _t < LEAD - 0.4:
		c.draw_string(f, Vector2(W / 2.0 - 30.0, 330), str(ceili(LEAD - _t)), HORIZONTAL_ALIGNMENT_LEFT, -1, 90, Color.WHITE)


func _draw_menu() -> void:
	var c := _draw_node
	var f := ThemeDB.fallback_font
	c.draw_string(f, Vector2(0, 150), "VALITSE KAPPALE", HORIZONTAL_ALIGNMENT_CENTER, W, 44, Color(1.0, 0.9, 0.5))
	_menu_rects.clear()
	for i in menu_titles.size():
		var r := Rect2(W / 2.0 - 440.0, 190.0 + i * 140.0, 880.0, 124.0)
		_menu_rects.append(r)
		var sel := i == _menu_i
		c.draw_rect(r, Color(0.2, 0.28, 0.5, 0.95) if sel else Color(0.1, 0.12, 0.2, 0.9))
		c.draw_rect(r, Color(1.0, 0.85, 0.3) if sel else Color(0.4, 0.45, 0.6), false, 3.0)
		var e: Array = menu_titles[i]
		c.draw_string(f, r.position + Vector2(24, 44), ("▶ " if sel else "") + str(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE if sel else Color(0.85, 0.85, 0.95))
		c.draw_multiline_string(f, r.position + Vector2(24, 76), str(e[2]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 48.0, 20, 2, Color(0.8, 0.85, 1.0, 0.9))


# --- Syntetisoitu säestys (oma kappale) ---------------------------------------------------------------------------

## Rumpu (vaimeneva sini) ja basso tahdissa, hiljainen ohjausmelodia ja osuessa nuotti sahalaitana.
func _fill_audio() -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	var beat := SYL * 2.0
	var guide_hz := 0.0
	for nt in _notes:
		if _t >= float(nt.t) and _t < float(nt.t) + float(nt.len) and nt.state != "ohi":
			guide_hz = BASE_HZ * pow(2.0, float(nt.pitch) / 12.0)
			break
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
			s += sin(_ph_guide * TAU) * 0.05
		if _voice_hz > 0.0:
			_ph_voice = fmod(_ph_voice + _voice_hz / RATE, 1.0)
			var saw := _ph_voice * 2.0 - 1.0
			var sq := 1.0 if _ph_voice < 0.5 else -1.0
			s += (saw * 0.6 + sq * 0.4) * 0.12
		_pb.push_frame(Vector2(s, s))
