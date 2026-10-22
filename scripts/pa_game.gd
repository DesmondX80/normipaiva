extends CanvasLayer
## PA-laitteiden kytkentä Santun mökin tuvassa: laitteiden takapaneelit ruudulla, johdot kytketään hiirellä
## (klikkaa liitintä ja sitten toista, tai vedä). Signaalitie: Santun kännykkä Bluetoothilla mokkulaan ->
## mokkulan LINE OUT mikserin CH2:een (linja),
## MAIN L/R -> päätevahvistimen tulot A/B -> Speakon-lähdöt kaiuttimiin, ja virrat jatkojohdosta.
## Virrat päälle oikeassa järjestyksessä: mikseri ensin, pääte viimeisenä (muuten kaiuttimet paukahtavat).
## Lopuksi CH2 ja MASTER nostetaan niin, että taso pysyy vihreällä. Mikrofonin kanava auki = kierto (kiljunta).
## Kolme mokaa ja Santtu ottaa homman pois käsistä. Musiikin taso välitetään level-signaalilla mökin kaiuttimille
## (mokki_interior.gd), joten tunnusmusiikki alkaa soida tuvassa jo säätövaiheessa.

const MG := preload("res://scripts/mg_draw.gd")

signal finished(won: bool)
signal level(v: float)  # 0 = hiljaa, 1 = täysillä (mökin kaiuttimien voimakkuus)

const W := 1280.0
const H := 720.0
const MAX_STRIKES := 3
const WIN_HOLD := 2.0
const GREEN := Vector2(0.5, 0.82)  # tason vihreä alue
const CLIP := 0.9
const PORT_R := 17.0
const TYPE_NAMES := {"xlr": "XLR", "jakki": "6,3 mm jakki", "speakon": "Speakon", "virta": "virtapistoke"}
const CABLE_COLS := {"xlr": Color(0.25, 0.35, 0.55), "jakki": Color(0.8, 0.2, 0.18), "speakon": Color(0.95, 0.6, 0.1),
	"virta": Color(0.1, 0.1, 0.1)}

## Laitteet: id -> [otsikko, suorakaide, väri].
const DEVICES := {
	"puh": ["BT-mokkula", Rect2(60, 90, 170, 150), Color(0.16, 0.17, 0.2)],
	"mic": ["Mikrofoni", Rect2(60, 300, 170, 150), Color(0.2, 0.2, 0.22)],
	"mix": ["Mikseri", Rect2(330, 60, 560, 330), Color(0.28, 0.3, 0.33)],
	"amp": ["Päätevahvistin", Rect2(330, 450, 560, 150), Color(0.13, 0.13, 0.15)],
	"spk_l": ["Kaiutin V", Rect2(990, 90, 220, 190), Color(0.1, 0.1, 0.11)],
	"spk_r": ["Kaiutin O", Rect2(990, 330, 220, 190), Color(0.1, 0.1, 0.11)],
	"jj": ["Jatkojohto", Rect2(990, 570, 220, 110), Color(0.9, 0.9, 0.88)],
}
## Liittimet: id -> [laite, paikka, tyyppi, "out"/"in", nimi].
const PORTS := {
	"puh_out": ["puh", Vector2(145, 200), "jakki", "out", "LINE OUT"],
	"mic_out": ["mic", Vector2(145, 410), "xlr", "out", "XLR"],
	"mix_ch1": ["mix", Vector2(390, 350), "xlr", "in", "CH1 MIC"],
	"mix_ch2": ["mix", Vector2(470, 350), "jakki", "in", "CH2 LINE"],
	"mix_mon": ["mix", Vector2(640, 350), "jakki", "out", "MONITOR"],
	"mix_main_l": ["mix", Vector2(720, 350), "xlr", "out", "MAIN L"],
	"mix_main_r": ["mix", Vector2(800, 350), "xlr", "out", "MAIN R"],
	"mix_pow": ["mix", Vector2(860, 110), "virta", "in", "AC"],
	"amp_in_a": ["amp", Vector2(400, 540), "xlr", "in", "IN A"],
	"amp_in_b": ["amp", Vector2(480, 540), "xlr", "in", "IN B"],
	"amp_out_a": ["amp", Vector2(600, 540), "speakon", "out", "OUT A"],
	"amp_out_b": ["amp", Vector2(680, 540), "speakon", "out", "OUT B"],
	"amp_pow": ["amp", Vector2(850, 540), "virta", "in", "AC"],
	"spk_l_in": ["spk_l", Vector2(1100, 240), "speakon", "in", "IN"],
	"spk_r_in": ["spk_r", Vector2(1100, 480), "speakon", "in", "IN"],
	"jj_1": ["jj", Vector2(1040, 640), "virta", "out", ""],
	"jj_2": ["jj", Vector2(1100, 640), "virta", "out", ""],
	"jj_3": ["jj", Vector2(1160, 640), "virta", "out", ""],
}
## Liukusäätimet mikserissä: id -> [kisko alhaalta ylös, nimi].
const FADERS := {
	"ch1": [Vector2(390, 290), Vector2(390, 150), "CH1"],
	"ch2": [Vector2(470, 290), Vector2(470, 150), "CH2"],
	"master": [Vector2(560, 290), Vector2(560, 150), "MASTER"],
}
const SW_MIX := Rect2(800, 90, 34, 44)
const SW_AMP := Rect2(780, 480, 34, 44)
const METER := Rect2(640, 140, 24, 160)

const LINES := {
	"start": ["Kamat on tossa. Mää en muista enää mikä menee mihinkin.", "Keikkakamat! Kytke ne, niin laitetaan tunnari soimaan."],
	"pop": ["PAM! Pääte päälle vasta viimeisenä, pois ensimmäisenä!", "Auts, kaiuttimet paukahti. Pääte viimeisenä päälle!"],
	"hot": ["Ei johtoja irrotella, kun pääte on päällä ja tasot ylhäällä!"],
	"feedback": ["KIERTO! Mikin kanava alas, se kiljuu kaiuttimiin!", "Mikki kiertää! Vedä CH1 alas!"],
	"clip": ["Rätisee! Liian kovaa, MASTER alemmas.", "Punaisella rätisee. Vihreälle!"],
	"almost": ["Kuuluu! Nyt taso vihreälle ja pidä siinä.", "Soi! Säädä vielä taso kohdalleen."],
	"swap": ["Stereo on ristissä, mutta ei se tanssilattialla haittaa."],
	"win": ["Nyt soi! Tää on se Normipäivän tunnari!", "Kuuluu Vaalaan asti! Hyvä!"],
	"lose": ["Anna ku mää... ei, antaa olla. Ei tänään enää keikkaa."],
}

var strikes := 0
var conns := {}  # sisääntulo -> ulostulo
var faders := {"ch1": 0.0, "ch2": 0.0, "master": 0.0}
var mix_sw := false
var amp_sw := false
var out_level := 0.0

var _board: Control
var _held := ""  # liitin, josta johto on tartuttu
var _drag_fader := ""
var _task: Label
var _sub: Label
var _sub_t := 0.0
var _title: Label
var _strike_label: Label
var _mix_live := false
var _amp_live := false
var _fb := 0.0  # kierron voimakkuus 0..1
var _fb_struck := false
var _fb_said := false
var _clip_t := 0.0
var _hold := 0.0
var _done := false
var _said_almost := false
var _said_swap := false
var _t := 0.0
var _squeal: AudioStreamPlayer
var _crackle: AudioStreamPlayer
var _board_pos := Vector2.ZERO  # laudan paikka ilman tärähdystä
var _shake := 0.0
var _pop_t := 0.0  # paukahduksen välähdys ja kaiutinkartioiden hyppy
var _sparks: Array = []  # kytkennän kipinät (MG.sparks_*)
var _bad: Array = []  # väärä kytkentä: [liitin, ikä] punainen rasti

const WOOD := Color(0.62, 0.44, 0.26)
const STEEL := Color(0.62, 0.64, 0.68)


func _ready() -> void:
	layer = 12
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_board = Control.new()
	_board.size = Vector2(W, H)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_draw_board)
	add_child(_board)
	_task = _make_label(24, Color(1.0, 0.85, 0.35), Control.PRESET_TOP_WIDE, Rect2(0, 12, 0, 0))
	_sub = _make_label(24, Color.WHITE, Control.PRESET_BOTTOM_WIDE, Rect2(0, -100, 0, -64))
	var keys: Control = preload("res://scripts/hint_bar.gd").new()  # näppäinohjeet hattuina, näppäimet asetuksista
	keys.compact = true
	keys.centered = true
	add_child(keys)
	keys.set_text("[Hiiri vasen] kytke tai irrota johto, vedä säädintä   [Rulla] säädä   %s lopeta" % Settings.cap("mount"))
	_strike_label = _make_label(22, Color(1.0, 0.5, 0.4), Control.PRESET_TOP_RIGHT, Rect2(-330, 12, -20, 40))
	_strike_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title = _make_label(72, Color(1.0, 0.8, 0.2), Control.PRESET_CENTER, Rect2(-500, -60, 500, 60))
	_title.add_theme_constant_override("outline_size", 14)
	_squeal = _synth_player(_tone(2640.0, 1.0), -80.0)
	_crackle = _synth_player(_noise(0.6), -80.0)
	CamCtl.free_mouse = true
	_say("start")
	get_viewport().size_changed.connect(_fit)
	_fit()


func _exit_tree() -> void:
	CamCtl.free_mouse = false


## Otsikko ankkureineen; offsets = (vasen, ylä, oikea, ala). Ankkurit asetetaan ennen puuhun lisäystä,
## muuten koko jää tekstin minimikooksi eikä keskitys toimi.
func _make_label(size: int, col: Color, preset: Control.LayoutPreset, offsets: Rect2) -> Label:
	var l := Label.new()
	l.set_anchors_preset(preset)
	l.offset_left = offsets.position.x
	l.offset_top = offsets.position.y
	l.offset_right = offsets.size.x
	l.offset_bottom = offsets.size.y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := minf(vp.x / W, (vp.y - 90.0) / H)
	_board.scale = Vector2(s, s)
	_board_pos = Vector2((vp.x - W * s) / 2.0, 44.0 + (vp.y - 90.0 - H * s) / 2.0)
	_board.position = _board_pos


func _say(key: String) -> void:
	_sub.text = "Santtu: " + str(LINES[key].pick_random())
	_sub_t = 3.5


# --- Syöte -------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.is_action("mount"):
		_finish(false, true)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var p := _board.get_local_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press(p)
			else:
				_drag_fader = ""
				# Vedetty johto kytkeytyy, jos se päästetään toisen liittimen päällä.
				var at := _port_at(p)
				if _held != "" and at != "" and at != _held:
					connect_ports(_held, at)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_held = ""
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var f := _fader_at(p)
			if f != "":
				_set_fader(f, faders[f] + (0.05 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.05))
	elif event is InputEventMouseMotion and _drag_fader != "":
		_drag_to(_drag_fader, _board.get_local_mouse_position())


func _press(p: Vector2) -> void:
	if SW_MIX.grow(6).has_point(p):
		mix_sw = not mix_sw
		Sfx.play("rattle", -10.0, 1.6)
		return
	if SW_AMP.grow(6).has_point(p):
		amp_sw = not amp_sw
		Sfx.play("rattle", -10.0, 1.6)
		return
	var f := _fader_at(p)
	if f != "":
		_drag_fader = f
		_drag_to(f, p)
		return
	var port := _port_at(p)
	if port == "":
		_held = ""
		return
	if _held != "" and port != _held:
		connect_ports(_held, port)
		return
	# Kytketyn liittimen klikkaus irrottaa johdon.
	var other := _connected_to(port)
	if other != "":
		unplug(port)
		return
	_held = port
	Sfx.play("cloth", -12.0, 1.4)


func _port_at(p: Vector2) -> String:
	for id in PORTS:
		if p.distance_to(PORTS[id][1]) < PORT_R + 6.0:
			return id
	return ""


func _fader_at(p: Vector2) -> String:
	for id in FADERS:
		var a: Vector2 = FADERS[id][0]
		var b: Vector2 = FADERS[id][1]
		if absf(p.x - a.x) < 22.0 and p.y > b.y - 16.0 and p.y < a.y + 16.0:
			return id
	return ""


func _drag_to(id: String, p: Vector2) -> void:
	var a: Vector2 = FADERS[id][0]
	var b: Vector2 = FADERS[id][1]
	_set_fader(id, (a.y - p.y) / (a.y - b.y))


func _set_fader(id: String, v: float) -> void:
	faders[id] = clampf(v, 0.0, 1.0)


func _connected_to(port: String) -> String:
	if conns.has(port):
		return conns[port]
	for k in conns:
		if conns[k] == port:
			return k
	return ""


# --- Kytkentä (julkinen testejä varten) --------------------------------------------

## Yrittää kytkeä johdon kahden liittimen välille. Palauttaa true, jos kytkentä onnistui.
func connect_ports(a: String, b: String) -> bool:
	_held = ""
	var pa: Array = PORTS[a]
	var pb: Array = PORTS[b]
	if pa[2] != pb[2]:
		_bad.append([b, 0.0])
		var what: String = TYPE_NAMES[pa[2]]
		_sub.text = "%s ei sovi %s-liittimeen." % [what[0].to_upper() + what.substr(1), TYPE_NAMES[pb[2]]]
		_sub_t = 2.5
		Sfx.play("rattle", -8.0, 0.8)
		return false
	if pa[3] == pb[3]:
		_sub.text = "Molemmat ovat %s. Johto kulkee ulostulosta sisääntuloon." % (
			"ulostuloja" if pa[3] == "out" else "sisääntuloja")
		_sub_t = 2.5
		return false
	if pa[0] == pb[0]:
		_sub.text = "Laitetta ei kytketä itseensä."
		_sub_t = 2.0
		return false
	var src := a if pa[3] == "out" else b
	var dst := b if src == a else a
	if _connected_to(src) != "" or _connected_to(dst) != "":
		_sub.text = "Liittimessä on jo johto. Irrota se ensin klikkaamalla."
		_sub_t = 2.0
		return false
	_hot_swap_check(dst)
	conns[dst] = src
	Sfx.play("rattle_hard" if pa[2] == "speakon" or pa[2] == "xlr" else "rattle", -8.0, 1.3)
	MG.sparks_burst(_sparks, PORTS[dst][1], Color(0.5, 1.0, 0.5), 10)  # klik: liitin paikallaan
	return true


func unplug(port: String) -> void:
	var other := _connected_to(port)
	if other == "":
		return
	var dst := port if conns.has(port) else other
	_hot_swap_check(dst)
	conns.erase(dst)
	Sfx.play("rattle", -10.0, 0.9)


## Signaalijohdon irrotus tai kytkentä päätteen ollessa päällä ja tason ollessa ylhäällä paukauttaa.
func _hot_swap_check(dst: String) -> void:
	if PORTS[dst][2] == "virta" or not _amp_live:
		return
	if faders.master > 0.15 or PORTS[dst][2] == "speakon":
		_pop("hot")


# --- Signaalitie --------------------------------------------------------------------

func _powered(dev_port: String) -> bool:
	return conns.has(dev_port)


## Palauttaa mikserin lähdön ("L"/"R"/""), joka päätyy kaiuttimeen.
func _speaker_feed(spk_port: String) -> String:
	var amp_out: String = conns.get(spk_port, "")
	if amp_out == "":
		return ""
	var amp_in := "amp_in_a" if amp_out == "amp_out_a" else "amp_in_b"
	match conns.get(amp_in, ""):
		"mix_main_l":
			return "L"
		"mix_main_r":
			return "R"
	return ""


func path_ok() -> bool:
	var l := _speaker_feed("spk_l_in")
	var r := _speaker_feed("spk_r_in")
	return l != "" and r != "" and l != r


func _update_power() -> void:
	var mix_live := mix_sw and _powered("mix_pow")
	var amp_live := amp_sw and _powered("amp_pow")
	if amp_live and not _amp_live and not mix_live:
		_pop("pop")  # pääte päälle ennen mikseriä
	elif mix_live != _mix_live and amp_live and _amp_live:
		_pop("pop")  # mikserin virta muuttui päätteen ollessa päällä
	_mix_live = mix_live
	_amp_live = amp_live


func _pop(key: String) -> void:
	_pop_t = 1.0
	_shake = 1.0
	Sfx.play("punch_heavy", 2.0, 0.5)
	Sfx.play("body_fall", 0.0, 0.6)
	_strike(key)


func _strike(key: String) -> void:
	strikes += 1
	_say(key)
	if strikes >= MAX_STRIKES:
		_finish(false)


# --- Päivitys -----------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_sub_t -= delta
	if _sub_t <= 0.0:
		_sub.text = ""
	_shake = maxf(0.0, _shake - delta * 2.5)
	_pop_t = maxf(0.0, _pop_t - delta * 1.5)
	MG.sparks_step(_sparks, delta)
	for b in _bad:
		b[1] += delta
	_bad = _bad.filter(func(b): return b[1] < 0.8)
	var jit := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (14.0 * _shake + 3.0 * _fb)
	_board.position = _board_pos + jit * _board.scale.x
	_board.queue_redraw()
	if _done:
		return
	_update_power()
	var live := _mix_live and _amp_live and path_ok()
	var music: float = faders.ch2 * faders.master * 1.25 if live and conns.get("mix_ch2", "") == "puh_out" else 0.0
	# Mikin kierto: mikki kytketty, kanava ja master auki -> kiljunta voimistuu, kunnes kanava vedetään alas.
	var mic_gain: float = faders.ch1 * faders.master if live and conns.get("mix_ch1", "") == "mic_out" else 0.0
	if mic_gain > 0.3:
		_fb = minf(_fb + delta * 0.8, 1.0)
		if _fb > 0.2 and not _fb_said:
			_fb_said = true
			_say("feedback")
		if _fb >= 1.0 and not _fb_struck:
			_fb_struck = true
			_strike("feedback")
	else:
		_fb = maxf(_fb - delta * 2.5, 0.0)
		if _fb <= 0.0:
			_fb_struck = false
			_fb_said = false
	_squeal.volume_db = linear_to_db(_fb) - 4.0 if _fb > 0.01 else -80.0
	_squeal.pitch_scale = 1.0 + 0.02 * sin(_t * 9.0) + 0.1 * _fb
	out_level = music
	level.emit(music)
	# Liian kova taso rätisee.
	if music > CLIP:
		_clip_t += delta
		_crackle.volume_db = -14.0 + 8.0 * randf()
		if _clip_t > 1.5:
			_clip_t = -1.5
			_strike("clip")
	else:
		_clip_t = maxf(_clip_t - delta, 0.0) if _clip_t > 0.0 else minf(_clip_t + delta, 0.0)
		_crackle.volume_db = -80.0
	if music > 0.05 and not _said_almost:
		_said_almost = true
		_say("almost")
	if music > 0.05 and not _said_swap and _speaker_feed("spk_l_in") == "R":
		_said_swap = true
		_say("swap")
	var in_green: bool = music >= GREEN.x and music <= GREEN.y and _fb <= 0.0
	_hold = _hold + delta if in_green else 0.0
	if _hold >= WIN_HOLD:
		_finish(true)
	_task.text = _task_text(live, music)
	_strike_label.text = "Santun hermot: " + "●".repeat(MAX_STRIKES - strikes) + "○".repeat(strikes)
	_board.queue_redraw()


func _task_text(live: bool, music: float) -> String:
	var need := []
	if conns.get("mix_ch2", "") != "puh_out":
		need.append("BT-mokkula mikserin linjakanavaan")
	if not path_ok():
		need.append("MAIN L/R päätteen kautta kaiuttimiin")
	if not (_powered("mix_pow") and _powered("amp_pow")):
		need.append("virrat jatkojohtoon")
	if not need.is_empty():
		return "1. Kytke johdot: " + ", ".join(need)
	if not live:
		return "2. Virrat päälle: mikseri ensin, pääte viimeisenä"
	if music <= 0.05:
		return "3. Nosta CH2 ja MASTER (vedä säädintä tai rullaa hiirellä)"
	if _hold > 0.0:
		return "Pidä taso vihreällä... %.1f s" % maxf(WIN_HOLD - _hold, 0.0)
	return "3. Säädä taso vihreälle, ei punaiselle"


func _finish(won: bool, quit := false) -> void:
	if _done:
		return
	_done = true
	_held = ""
	_squeal.stop()
	_crackle.stop()
	if not won:
		level.emit(0.0)
	_title.text = "PA TOIMII!" if won else ("" if quit else "SANTTU OTTI KAMAT POIS")
	if not quit:
		_say("win" if won else "lose")
		Sfx.play("win_small" if won else "lose", -4.0)
	await get_tree().create_timer(0.1 if quit else 2.2).timeout
	finished.emit(won)


# --- Piirto -------------------------------------------------------------------------

## Santun tupa: hirsiseinä taustalla ja leveä mäntypöytä, jolla kamat ovat. Laitteet piirretään omina esineinään,
## liittimet tyyppinsä mukaan, johdot pistokkeineen. Paukahdus välähtää punaisena ja heittää kaiutinkartioita, kierto
## värisyttää kaiuttimia ja lähettää ääniaaltoja.
func _draw_board() -> void:
	var font := ThemeDB.fallback_font
	_draw_room()
	_draw_phone(DEVICES.puh[1])
	_draw_mic(DEVICES.mic[1])
	_draw_mixer(font, DEVICES.mix[1])
	_draw_amp(font, DEVICES.amp[1])
	for id in ["spk_l", "spk_r"]:
		_draw_speaker(DEVICES[id][1])
	_draw_strip(DEVICES.jj[1])
	for id in PORTS:
		_draw_port(id)
	for dst in conns:
		_draw_cable(PORTS[conns[dst]][1], PORTS[dst][1], PORTS[dst][2])
	if _held != "":
		_draw_cable(PORTS[_held][1], _board.get_local_mouse_position(), PORTS[_held][2])
	for id in DEVICES:
		_tape_label(font, DEVICES[id][1], DEVICES[id][0])
	# Liittimien nimet johtojen päälle, ettei roikkuva johto peitä niitä.
	for id in PORTS:
		var p: Array = PORTS[id]
		if p[4] != "":
			_board.draw_string_outline(font, p[1] + Vector2(-40, PORT_R + 20), p[4], HORIZONTAL_ALIGNMENT_CENTER, 80, 14, 4, Color(0.05, 0.05, 0.05))
			_board.draw_string(font, p[1] + Vector2(-40, PORT_R + 20), p[4], HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(0.95, 0.95, 0.92))
	for b in _bad:  # väärä liitin: punainen rasti
		var c: Vector2 = PORTS[b[0]][1]
		var a: float = 1.0 - b[1] / 0.8
		for d in [Vector2(1, 1), Vector2(1, -1)]:
			_board.draw_line(c - d * 16.0, c + d * 16.0, Color(1.0, 0.2, 0.15, a), 6.0)
	MG.sparks_draw(_board, _sparks)
	_draw_waves()
	if _pop_t > 0.0:  # paukahdus: punainen välähdys ja PAM kaiuttimien kohdalle
		_board.draw_rect(Rect2(Vector2(-200, -200), Vector2(W + 400, H + 400)), Color(1.0, 0.15, 0.05, 0.35 * _pop_t))
		for id in ["spk_l", "spk_r"]:
			var sr: Rect2 = DEVICES[id][1]
			_board.draw_string_outline(font, sr.position + Vector2(-30, 40 - 30.0 * (1.0 - _pop_t)), "PAM!", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, 10,
				Color(0, 0, 0, _pop_t))
			_board.draw_string(font, sr.position + Vector2(-30, 40 - 30.0 * (1.0 - _pop_t)), "PAM!", HORIZONTAL_ALIGNMENT_LEFT, -1, 54,
				Color(1.0, 0.85, 0.2, _pop_t))


func _draw_room() -> void:
	# Hirsiseinä: pyöreät hirret varjoineen ja nurkkasalvos.
	for k in 4:
		var y := -40.0 + k * 34.0
		MG.grad_rect(_board, Rect2(Vector2(-200, y), Vector2(W + 400, 34)), Color(0.55, 0.38, 0.22), Color(0.36, 0.24, 0.13))
		_board.draw_line(Vector2(-200, y + 33), Vector2(W + 200, y + 33), Color(0.2, 0.12, 0.06), 3.0)
	# Pöytä: lankut ja etureuna.
	MG.wood(_board, Rect2(Vector2(-200, 96), Vector2(W + 400, H + 200)), WOOD, 90.0, 4)
	_board.draw_line(Vector2(-200, 96), Vector2(W + 200, 96), Color(0.25, 0.15, 0.08), 4.0)
	# Kahvikuppi ja keikkalista pöydällä.
	MG.ball(_board, Vector2(270, 640), 22.0, Color(0.9, 0.9, 0.86), 0.3)
	_board.draw_circle(Vector2(270, 640), 15.0, Color(0.3, 0.18, 0.08))
	var paper := PackedVector2Array([Vector2(130, 520), Vector2(250, 505), Vector2(262, 600), Vector2(140, 615)])
	_board.draw_colored_polygon(paper, Color(0.97, 0.96, 0.9))
	_board.draw_polyline(paper + PackedVector2Array([paper[0]]), MG.OUTLINE, 2.0)
	for k in 5:
		_board.draw_line(Vector2(145, 535 + k * 15), Vector2(240 - (k % 2) * 30, 523 + k * 15), Color(0.2, 0.25, 0.6), 2.0)


## Laitteen nimi maalarinteipillä (teippi mitoitetaan tekstin mukaan, ei vuoda reunan yli).
func _tape_label(font: Font, r: Rect2, text: String) -> void:
	var fs := 17
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tr := Rect2(r.position + Vector2(8, -12), Vector2(tw + 16, 24))
	_board.draw_colored_polygon(PackedVector2Array([tr.position + Vector2(0, 2), tr.position + Vector2(tr.size.x, 0), tr.end, tr.position + Vector2(2, tr.size.y)]),
		Color(0.93, 0.88, 0.72))
	_board.draw_string(font, tr.position + Vector2(8, 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.15, 0.12, 0.1))


## Bluetooth-mokkula: pieni musta laatikko, BT-valo (vilkkuu etsiessä, palaa sinisenä soittaessa), virtavalo, napit
## ja LINE OUT -jakki alla. Santun kännykkä on pöydällä vieressä ja soittaa mokkulaan langattomasti.
func _draw_phone(r: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var playing := out_level > 0.0
	var powered := _mix_live  # mokkula saa virtansa mikserin USB:stä
	# Kännykkä pöydällä vasemmalla, näytöllä soitin ja BT-merkki.
	var ph := Rect2(Vector2(14, 104), Vector2(44, 80))
	MG.box(_board, ph, Color(0.1, 0.1, 0.12), 8, 4, MG.OUTLINE, 2)
	var scr := ph.grow(-4)
	MG.grad_rect(_board, scr, Color(0.2, 0.3, 0.55) if playing else Color(0.1, 0.12, 0.18), Color(0.35, 0.18, 0.45) if playing else Color(0.06, 0.07, 0.1))
	MG.box(_board, Rect2(scr.position + Vector2(6, 8), Vector2(24, 22)), Color(0.95, 0.75, 0.2) if playing else Color(0.3, 0.3, 0.3), 3)
	_board.draw_string(font, scr.position + Vector2(10, 26), "♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.15, 0.1))
	_bt_rune(scr.position + Vector2(18, 52), 7.0, Color(0.5, 0.75, 1.0))
	# Langaton yhteys: kaaret kännykästä mokkulaan.
	if playing or fposmod(_t, 1.0) < 0.5:
		for k in 3:
			_board.draw_arc(Vector2(64, 140), 8.0 + k * 7.0, -0.7, 0.7, 8, Color(0.4, 0.7, 1.0, 0.8 - k * 0.2), 2.5)
	# Mokkula.
	var box := Rect2(Vector2(98, 110), Vector2(96, 112))  # LINE OUT -jakki etupaneelin alaosassa
	MG.box(_board, box, Color(0.09, 0.09, 0.1), 12, 6, MG.OUTLINE, 2)
	MG.box(_board, Rect2(box.position + Vector2(5, 4), Vector2(box.size.x - 10, 16)), Color(0.18, 0.18, 0.2), 8)
	_bt_rune(box.position + Vector2(20, 40), 8.0, Color(0.55, 0.6, 0.7))
	var bt_on := powered and (playing or fposmod(_t, 0.8) < 0.4)
	var bt_led := box.position + Vector2(42, 30)
	if bt_on:
		MG.glow(_board, bt_led, 14.0, Color(0.3, 0.55, 1.0, 0.6))
	_board.draw_circle(bt_led, 4.5, Color(0.3, 0.55, 1.0) if bt_on else Color(0.1, 0.13, 0.25))
	var pw_led := box.position + Vector2(56, 30)
	if powered:
		MG.glow(_board, pw_led, 12.0, Color(0.3, 1.0, 0.4, 0.5))
	_board.draw_circle(pw_led, 4.5, Color(0.3, 1.0, 0.4) if powered else Color(0.1, 0.22, 0.12))
	for k in 2:  # pariliitos- ja voimakkuusnapit
		MG.ball(_board, box.position + Vector2(48 + k * 20, 48), 6.0, Color(0.25, 0.25, 0.27), 0.3)
	_board.draw_string(font, box.position + Vector2(66, 34), "BT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.62, 0.68))
	_board.draw_line(box.position + Vector2(10, 64), box.position + Vector2(box.size.x - 10, 64), Color(0.2, 0.2, 0.22), 2.0)  # paneelin sauma


## Bluetooth-merkki (riimut Hagall ja Bjarkan päällekkäin).
func _bt_rune(c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-0.6, -0.5) * s, c + Vector2(0.6, 0.5) * s, c + Vector2(0, 1.1) * s, c + Vector2(0, -1.1) * s,
		c + Vector2(0.6, -0.5) * s, c + Vector2(-0.6, 0.5) * s])
	_board.draw_polyline(pts, col, 2.0, true)


## Dynaaminen laulumikrofoni pöytätelineessä: ritiläpää verkkokuvioin, kartiomainen runko, XLR alapäässä.
func _draw_mic(r: Rect2) -> void:
	var c := Vector2(145, 338)
	_board.draw_colored_polygon(PackedVector2Array([Vector2(129, 362), Vector2(161, 362), Vector2(155, 396), Vector2(135, 396)]), Color(0.12, 0.12, 0.13))
	_board.draw_polyline(PackedVector2Array([Vector2(129, 362), Vector2(161, 362), Vector2(155, 396), Vector2(135, 396), Vector2(129, 362)]), MG.OUTLINE, 2.0)
	_board.draw_line(Vector2(132, 366), Vector2(137, 392), Color(1, 1, 1, 0.25), 2.0)
	_board.draw_rect(Rect2(Vector2(127, 358), Vector2(36, 6)), STEEL)
	MG.ball(_board, c, 26.0, Color(0.7, 0.72, 0.75), 0.35)
	for k in range(-3, 4):  # ritilän verkko
		_board.draw_line(c + Vector2(k * 7, -22 + absf(k) * 2), c + Vector2(k * 7, 22 - absf(k) * 2), Color(0.35, 0.36, 0.4), 1.5)
		_board.draw_line(c + Vector2(-22 + absf(k) * 2, k * 7), c + Vector2(22 - absf(k) * 2, k * 7), Color(0.35, 0.36, 0.4), 1.5)
	_board.draw_arc(c, 26.0, 0, TAU, 32, MG.OUTLINE, 2.0)


## Mikseri: harjattu metallipaneeli, ruuvit, kanavaliuskat nupeineen, liukusäätimet, LED-mittari ja keinukytkin.
func _draw_mixer(font: Font, r: Rect2) -> void:
	MG.box(_board, r, Color(0.2, 0.21, 0.23), 14, 10, MG.OUTLINE, 3)
	MG.grad_rect(_board, r.grow(-8), Color(0.42, 0.44, 0.47), Color(0.3, 0.31, 0.34))
	for k in 40:  # harjattu pinta
		_board.draw_line(Vector2(r.position.x + 10, r.position.y + 12 + k * 8), Vector2(r.end.x - 10, r.position.y + 12 + k * 8), Color(1, 1, 1, 0.03), 1.0)
	for cp in [r.position + Vector2(18, 18), Vector2(r.end.x - 18, r.position.y + 18), r.end - Vector2(18, 18), Vector2(r.position.x + 18, r.end.y - 18)]:
		_screw(cp)
	for id in FADERS:  # kanavaliuskan erotin ja nupit (gain, EQ)
		var a: Vector2 = FADERS[id][0]
		_board.draw_line(Vector2(a.x + 38, r.position.y + 40), Vector2(a.x + 38, r.end.y - 50), Color(0.2, 0.2, 0.22), 2.0)
		for k in 2:
			var kc := Vector2(a.x, r.position.y + 58 + k * 0.0) + Vector2(k * 26 - 13, 0)
			MG.ball(_board, kc, 9.0, Color(0.15, 0.15, 0.16), 0.2)
			_board.draw_line(kc, kc + Vector2(0, -8).rotated(-0.8 + k * 1.3), Color(0.95, 0.95, 0.9), 2.0)
	_board.draw_string(font, r.position + Vector2(r.size.x - 260, 34), "SEKOITIN 8·2", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.85, 0.82, 0.7))
	for id in FADERS:
		var a: Vector2 = FADERS[id][0]
		var b: Vector2 = FADERS[id][1]
		_board.draw_line(a + Vector2(0, 8), b - Vector2(0, 8), Color(0.04, 0.04, 0.05), 8.0)
		for k in 5:
			var ty := lerpf(a.y, b.y, k / 4.0)
			_board.draw_line(Vector2(a.x - 16, ty), Vector2(a.x - 9, ty), Color(0.85, 0.85, 0.85), 1.5)
		var knob := a.lerp(b, faders[id])
		var kc := Color(0.85, 0.2, 0.2) if id == "master" else (Color(0.3, 0.6, 0.9) if id == "ch1" else Color(0.9, 0.9, 0.9))
		_board.draw_rect(Rect2(knob - Vector2(17, 7), Vector2(38, 18)), Color(0, 0, 0, 0.35))
		MG.solid(_board, Rect2(knob - Vector2(19, 10), Vector2(38, 20)), kc)
		_board.draw_line(knob - Vector2(16, 0), knob + Vector2(16, 0), Color(0.05, 0.05, 0.05), 2.0)
		_board.draw_string(font, a + Vector2(-40, 34), FADERS[id][2], HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(0.95, 0.95, 0.92))
	MG.box(_board, METER.grow(4), Color(0.03, 0.03, 0.03), 4)
	var segs := 16
	for k in segs:
		var v := (k + 0.5) / segs
		var col := Color(0.2, 0.85, 0.3)
		if v > GREEN.y:
			col = Color(0.95, 0.2, 0.15)
		elif v < GREEN.x:
			col = Color(0.9, 0.8, 0.2)
		var lit := out_level * (0.93 + 0.07 * sin(_t * 23.0)) >= v
		var sy := METER.end.y - (k + 1) * METER.size.y / segs
		var seg := Rect2(METER.position.x + 3, sy + 1, METER.size.x - 6, METER.size.y / segs - 2)
		if lit:
			MG.glow(_board, seg.get_center(), 14.0, Color(col, 0.35))
		_board.draw_rect(seg, col if lit else col.darkened(0.8))
	_board.draw_string(font, METER.position + Vector2(-20, METER.size.y + 22), "TASO", HORIZONTAL_ALIGNMENT_CENTER, 64, 14, Color(0.95, 0.95, 0.92))
	if _clip_t > 0.0:
		_board.draw_string_outline(font, METER.position + Vector2(-48, -10), "RÄTISEE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color.BLACK)
		_board.draw_string(font, METER.position + Vector2(-48, -10), "RÄTISEE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.35, 0.25))
	_draw_switch(font, SW_MIX, mix_sw, _mix_live)


## Päätevahvistin: 2U-räkkietulevy korvakkeineen, tuuletusritilä, LEDit ja keinukytkin.
func _draw_amp(font: Font, r: Rect2) -> void:
	MG.box(_board, r, Color(0.08, 0.08, 0.09), 8, 10, MG.OUTLINE, 3)
	MG.grad_rect(_board, r.grow(-6), Color(0.2, 0.2, 0.22), Color(0.1, 0.1, 0.11))
	for side in [0.0, 1.0]:  # räkkikorvakkeet ruuvinreikineen
		var ex: float = r.position.x + side * (r.size.x - 26)
		MG.solid(_board, Rect2(Vector2(ex, r.position.y + 6), Vector2(26, r.size.y - 12)), Color(0.3, 0.3, 0.32), false)
		for k in 2:
			_board.draw_circle(Vector2(ex + 13, r.position.y + 30 + k * (r.size.y - 60)), 5.0, Color(0.05, 0.05, 0.05))
	for k in 14:  # tuuletusritilä
		_board.draw_line(Vector2(r.position.x + 230 + k * 9, r.position.y + 14), Vector2(r.position.x + 230 + k * 9, r.position.y + 50), Color(0.02, 0.02, 0.02), 4.0)
	_board.draw_string(font, r.position + Vector2(40, 40), "PÄÄTE 2 × 600 W", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.8, 0.78, 0.8))
	for k in 2:
		var on := _amp_live and out_level > 0.05
		var lc := r.position + Vector2(400 + k * 26, 30)
		if on:
			MG.glow(_board, lc, 16.0, Color(0.2, 1.0, 0.3, 0.5))
		_board.draw_circle(lc, 6.0, Color(0.2, 1.0, 0.3) if on else Color(0.1, 0.25, 0.12))
	var clip_on := _fb > 0.0 or _clip_t > 0.0 or _pop_t > 0.0
	if clip_on:
		MG.glow(_board, r.position + Vector2(452, 30), 16.0, Color(1.0, 0.2, 0.1, 0.5))
	_board.draw_circle(r.position + Vector2(452, 30), 6.0, Color(1.0, 0.2, 0.1) if clip_on else Color(0.3, 0.08, 0.06))
	_board.draw_string(font, r.position + Vector2(388, 52), "SIG      CLIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.78))
	_draw_switch(font, SW_AMP, amp_sw, _amp_live)


## Kaiutin: kotelo kulmasuojineen, bassoelementti (kartio, reunus, pölysuoja) ja diskanttitorvi. Kartio sykkii
## musiikin mukana, hyppää paukahduksessa ja värisee kierrossa.
func _draw_speaker(r: Rect2) -> void:
	var jit := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 3.0 * _fb
	var box := Rect2(r.position + jit, r.size)
	MG.box(_board, box, Color(0.12, 0.12, 0.13), 10, 10, MG.OUTLINE, 3)
	MG.grad_rect(_board, box.grow(-6), Color(0.18, 0.18, 0.2), Color(0.1, 0.1, 0.11))
	for cp in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		MG.ball(_board, cp + (box.get_center() - cp).normalized() * 9.0, 9.0, STEEL, 0.4)
	var wc := box.position + Vector2(84, 80)  # IN-liitin jää elementin alle
	var push := out_level * (0.5 + 0.5 * sin(_t * 13.0)) * 5.0 + _pop_t * 14.0 + _fb * 4.0 * sin(_t * 80.0)
	_board.draw_circle(wc, 54.0, Color(0.05, 0.05, 0.05))
	_board.draw_circle(wc, 50.0, Color(0.16, 0.16, 0.17))  # reunus
	_board.draw_circle(wc, 43.0 + push * 0.4, Color(0.22, 0.22, 0.24))  # kartio
	_board.draw_arc(wc, 31.0 + push * 0.3, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.12), 6.0)
	MG.ball(_board, wc, 15.0 + push * 0.5, Color(0.3, 0.3, 0.33), 0.4)  # pölysuoja
	var hc := box.position + Vector2(178, 46)
	_board.draw_colored_polygon(PackedVector2Array([hc + Vector2(-26, -20), hc + Vector2(26, -20), hc + Vector2(10, 0), hc + Vector2(-10, 0),
		hc + Vector2(26, 20), hc + Vector2(-26, 20)]), Color(0.06, 0.06, 0.06))
	MG.box(_board, Rect2(hc - Vector2(28, 22), Vector2(56, 44)), Color(0, 0, 0, 0), 6, 0, Color(0.3, 0.3, 0.32), 2)
	_board.draw_circle(hc, 6.0, Color(0.25, 0.25, 0.28))


## Jatkojohto: valkoinen kolmen pistorasian rima suojamaadoituskynsin, valokytkin ja johto seinään.
func _draw_strip(r: Rect2) -> void:
	_board.draw_line(Vector2(r.end.x - 4, r.get_center().y), Vector2(W + 200, r.get_center().y + 30), Color(0.92, 0.92, 0.9), 9.0)
	MG.box(_board, Rect2(r.position + Vector2(10, 30), Vector2(r.size.x - 20, 70)), Color(0.95, 0.95, 0.93), 16, 8, MG.OUTLINE, 2)
	_board.draw_line(r.position + Vector2(24, 36), Vector2(r.end.x - 24, r.position.y + 36), Color(1, 1, 1), 3.0)
	var live := _powered("mix_pow") or _powered("amp_pow")
	MG.solid(_board, Rect2(r.position + Vector2(r.size.x - 34, 44), Vector2(14, 30)), Color(0.9, 0.2, 0.15) if live else Color(0.6, 0.15, 0.12))


func _screw(c: Vector2) -> void:
	MG.ball(_board, c, 6.0, STEEL, 0.5)
	_board.draw_line(c - Vector2(4, 0).rotated(0.6), c + Vector2(4, 0).rotated(0.6), Color(0.2, 0.2, 0.22), 2.0)


## Liitin tyyppinsä mukaan: XLR kolmella nastalla ja lukitusnapilla, jakki mutterilla, Speakon lukitusurin,
## virta pistorasiana (jatkojohto) tai IEC-liittimenä (laitteet). Tartuttu liitin hehkuu keltaisena.
func _draw_port(id: String) -> void:
	var p: Array = PORTS[id]
	var c: Vector2 = p[1]
	if id == _held:
		MG.glow(_board, c, 34.0, Color(1.0, 0.9, 0.2, 0.7))
	match p[2]:
		"xlr":
			MG.ball(_board, c, PORT_R + 3.0, STEEL, 0.4)
			_board.draw_circle(c, PORT_R - 2.0, Color(0.06, 0.06, 0.07))
			for k in 3:
				_board.draw_circle(c + Vector2(0, -6).rotated(k * TAU / 3.0 + PI), 2.5, Color(0.85, 0.75, 0.4))
			_board.draw_rect(Rect2(c + Vector2(-4, PORT_R + 1), Vector2(8, 5)), Color(0.15, 0.15, 0.15))
		"jakki":
			var hexp := PackedVector2Array()
			for k in 6:
				hexp.append(c + Vector2(PORT_R + 2.0, 0).rotated(k * TAU / 6.0))
			_board.draw_colored_polygon(hexp, STEEL.lightened(0.1))
			_board.draw_polyline(hexp + PackedVector2Array([hexp[0]]), MG.OUTLINE, 2.0)
			_board.draw_circle(c, 8.0, Color(0.05, 0.05, 0.05))
		"speakon":
			MG.ball(_board, c, PORT_R + 3.0, Color(0.15, 0.25, 0.5), 0.3)
			_board.draw_circle(c, PORT_R - 4.0, Color(0.04, 0.04, 0.05))
			for k in 2:
				_board.draw_arc(c, PORT_R - 8.0, k * PI + 0.4, k * PI + 1.6, 6, Color(0.6, 0.6, 0.62), 3.0)
		"virta":
			if p[0] == "jj":
				MG.ball(_board, c, PORT_R + 6.0, Color(0.9, 0.9, 0.88), 0.2)
				_board.draw_circle(c, PORT_R + 1.0, Color(0.8, 0.8, 0.78))
				for dx in [-6.0, 6.0]:
					_board.draw_circle(c + Vector2(dx, 0), 3.0, Color(0.1, 0.1, 0.1))
				for dy in [-1.0, 1.0]:
					_board.draw_rect(Rect2(c + Vector2(-3, dy * (PORT_R - 1) - 2), Vector2(6, 4)), STEEL)
			else:
				MG.box(_board, Rect2(c - Vector2(PORT_R + 2, PORT_R - 2), Vector2(2 * PORT_R + 4, 2 * PORT_R - 4)), Color(0.08, 0.08, 0.08), 5, 0, STEEL, 2)
				for dx in [-7.0, 0.0, 7.0]:
					_board.draw_rect(Rect2(c + Vector2(dx - 1.5, -5 + (3 if dx == 0.0 else 0)), Vector2(3, 8)), Color(0.85, 0.75, 0.4))


func _draw_switch(font: Font, r: Rect2, on: bool, live: bool) -> void:
	MG.box(_board, r.grow(3), Color(0.05, 0.05, 0.05), 4, 2)
	var knob := Rect2(r.position + Vector2(3, 3 if on else r.size.y / 2.0), Vector2(r.size.x - 6, r.size.y / 2.0 - 3))
	MG.solid(_board, knob, Color(0.9, 0.2, 0.15) if on else Color(0.45, 0.45, 0.47))
	var led := r.position + Vector2(r.size.x + 14, 10)
	if live:
		MG.glow(_board, led, 14.0, Color(1.0, 0.3, 0.2, 0.5))
	_board.draw_circle(led, 5.0, Color(1.0, 0.3, 0.2) if live else Color(0.25, 0.1, 0.1))
	_board.draw_string(font, r.position + Vector2(-30, r.size.y + 16), "POWER", HORIZONTAL_ALIGNMENT_CENTER, 94, 13, Color(0.95, 0.95, 0.92))


## Johto roikkuu pöydällä, päissä pistokkeet tyypin mukaan (XLR/Speakon pyöreä runko, jakki kapea, virta valkoinen).
func _draw_cable(a: Vector2, b: Vector2, kind: String) -> void:
	var col: Color = CABLE_COLS[kind]
	var sag := 60.0 + a.distance_to(b) * 0.15
	var c1 := a + Vector2(0, sag)
	var c2 := b + Vector2(0, sag)
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		var u := 1.0 - t
		pts.append(u * u * u * a + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * b)
	_board.draw_polyline(pts + PackedVector2Array(), Color(0, 0, 0, 0.35), 12.0, true)
	_board.draw_polyline(pts, col.darkened(0.35), 9.0, true)
	_board.draw_polyline(pts, col, 6.0, true)
	var hl := PackedVector2Array()
	for q in pts:
		hl.append(q + Vector2(-1.5, -1.5))
	_board.draw_polyline(hl, col.lightened(0.4), 1.5, true)
	for e in [a, b]:
		var body := col.darkened(0.2) if kind != "virta" else Color(0.15, 0.15, 0.15)
		match kind:
			"jakki":
				MG.box(_board, Rect2(e - Vector2(6, -4), Vector2(12, 26)), body, 4, 2, MG.OUTLINE, 2)
				_board.draw_rect(Rect2(e - Vector2(3, 2), Vector2(6, 8)), STEEL)
			_:
				MG.box(_board, Rect2(e - Vector2(11, -2), Vector2(22, 26)), body, 6, 2, MG.OUTLINE, 2)
				_board.draw_rect(Rect2(e + Vector2(-9, 4), Vector2(18, 4)), STEEL if kind != "virta" else Color(0.3, 0.3, 0.3))


## Kierto: ääniaallot kaiuttimista ja mikistä.
func _draw_waves() -> void:
	if _fb <= 0.02:
		return
	for id in ["spk_l", "spk_r", "mic"]:
		var r: Rect2 = DEVICES[id][1]
		var c := r.position + (Vector2(84, 80) if id != "mic" else Vector2(85, 48))
		for k in 3:
			var rr := 30.0 + fposmod(_t * 120.0 + k * 30.0, 90.0)
			_board.draw_arc(c, rr, PI * 0.75 if id != "mic" else -PI * 0.25, PI * 1.25 if id != "mic" else PI * 0.25, 12,
				Color(1.0, 0.35, 0.3, _fb * (1.0 - (rr - 30.0) / 90.0)), 4.0)


# --- Syntetisoidut silmukat (kierto, rätinä) ----------------------------------------

func _synth_player(st: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = st
	p.volume_db = db
	add_child(p)
	p.play()
	return p


static func _wav(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = samples.size()
	return w


## Siniääni (kierron kiljunta); taajuus pyöristetään niin, että silmukka on saumaton.
static func _tone(freq: float, secs: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * secs)
	var f := roundf(freq * secs) / secs
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / rate
		s[i] = 0.6 * sin(TAU * f * t) + 0.15 * sin(TAU * f * 2.0 * t)
	return _wav(s, rate)


## Rätinä: harvoja naksahduksia kohinassa.
static func _noise(secs: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * secs)
	var s := PackedFloat32Array()
	s.resize(n)
	var burst := 0
	for i in n:
		if burst <= 0 and randf() < 0.004:
			burst = randi_range(40, 400)
		s[i] = (randf() * 2.0 - 1.0) * (0.8 if burst > 0 else 0.05)
		burst -= 1
	return _wav(s, rate)
