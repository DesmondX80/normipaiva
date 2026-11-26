extends CanvasLayer
## Karaoke-ilta naisen olohuoneessa (kolmiomittauksen iltakiva, K-18 ja vähän rivo): mikrofoniteline maton keskellä,
## putkitelkkari sanoineen sivulla, ja yleisö (nainen ja vuoroaan odottava kaveri) istuu jakkaroilla reunoilla.
## Vuorot: kaveri 1, pelaaja ja kaveri 2, kullakin oma rivo säkeistö (kolmiomittaus.gd KARAOKE_LINES "sakeet").
## Laulu on pelin oma karaoke (karaoke_game.gd: nuottikaistat, syntetisoitu melodia, pisteet 0..1); kaverien vuoroilla
## tekoäly näppäilee nuotit (lane_press) oman tarkkuutensa mukaan. Karaoken tausta on läpikuultavampi, jotta laulaja
## näkyy olohuoneessa. Vuorojen välissä nainen kommentoi, ja lopuksi paras laulaja voittaa.

signal finished(result: Dictionary)

const Room := preload("res://scripts/ilta_room.gd")
const B := preload("res://scripts/build.gd")
const KaraokeGame := preload("res://scripts/karaoke_game.gd")
const Hall := preload("res://scripts/rasvanappi_hall.gd")
const Rasva := preload("res://scripts/rasvanappi_game.gd")
const MG := preload("res://scripts/mg_draw.gd")
const Pose := preload("res://scripts/pose.gd")

const CENTER := Vector3(6.0, 0.0, 3.6)
const MIC := Vector3(0.0, 0.0, 0.05)  # laulajan paikka (CENTER + MIC), kasvot +Z kameraan
const AUDIENCE := [Vector3(-1.15, 0, 1.05), Vector3(1.15, 0, 1.05)]  # vasen (kaveri) ja oikea (nainen) jakkara
const TV := Vector3(-1.25, 0.0, -0.55)
const STOOL_H := 0.475
## Säkeistön rivien melodiat (puolisävelinä G3:sta, kuten karaoke_game.gd SONG).
const MELODY := [[4, 4, 5, 7, 7, 9, 7, 5], [4, 5, 7, 5, 4, 2, 4, 0], [7, 7, 9, 7, 11, 9, 7, 5], [4, 5, 7, 9, 7, 5, 4, 0]]

var site := "saloinen"
var anchor: Node3D
var sun: DirectionalLight3D
var style := {}
var people: Array = []  # [pelaaja, kaveri 1, kaveri 2, nainen]
var lines := {}
var auto := false
var drunk := 0.0

var _hall: Node3D
var _cam: Camera3D
var _cam_base: Transform3D
var _singer: Node3D
var _audience: Array = [null, null]
var _tv_text: Label3D
var _turns := [1, 0, 2]
var _turn := 0
var _scores := [0.0, 0.0, 0.0]
var _kg: CanvasLayer  # käynnissä oleva karaoke
var _plan := {}  # nuotin indeksi -> [painallusaika, vapautusaika, osuuko, painettu, vapautettu]
var _phase := "alku"  # alku, laulu, reaktio, loppu, valmis
var _t := 0.0
var _story := ""
var _ui: Control
var _keys: Node
var _bubbles: Array = ["", "", "", ""]
var _bubble_t := [0.0, 0.0, 0.0, 0.0]
var _rng := RandomNumberGenerator.new()
var _spot: OmniLight3D
var _tvl: OmniLight3D
var _scr_mat: StandardMaterial3D

## Legendaarinen hetki "karaokekunkku" (main.gd _kolmio_ilta: ensimmäinen voitto, lines.legenda): kertosäe koko
## porukalla, naapuri hakkaa patteria ja huutaa ikkunastaan, viimeinen rivo rivi suoraan naapuriin, ennätys
## telkkarissa ja otsikko. recall: hetki on jo koettu, joku muistelee illan alussa (lines.muisto).
var legend := false
var recall := false
const LEG := ["kerto", "naapuri", "finaali", "ennatys", "otsikko"]
const WIN_X := 7.9  # takaseinän ikkunan keskikohta (rasvanappi_hall.gd _build_living)
var _leg_chars: Array = [null, null, null, null]  # legendan hahmot istuinnumeroittain (0 pelaaja, 3 nainen)
var _rad: Node3D  # patteri ikkunan alla
var _rad_base := Vector3.ZERO
var _nb_wins: Array = []  # naapuritalon ikkunat (MeshInstance3D), ensimmäinen on huutajan
var _nb_fig: Node3D  # naapurin siluetti ikkunassa
var _nb_text := ""
var _shake := 0.0
var _leg_cam_base: Transform3D
var _leg_pb: AudioStreamGeneratorPlayback
var _mus := {"on": false, "t": 0.0, "vol": 0.0, "crowd": 0.0, "hold": -1.0}
var _ph: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
var _once := {}


func _ready() -> void:
	layer = 6
	add_to_group("esc_lopettaa")
	_rng.randomize()
	_build()
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_place(_turns[0])
	_story = "Karaoke-ilta! Jokainen laulaa oman säkeistön. Paras laulaja saa valita, kenen viereen nukkuu."
	if recall and lines.has("muisto"):  # hetki on jo koettu: mikillä seisova kaveri tai nainen muistelee naapuria
		var m: Array = (lines.muisto as Array).pick_random()
		_say(int(m[0]), String(m[1]))
		_bubble_t[int(m[0])] = 5.0
	else:
		_say(3, _line("alku", "Karaoke! Kuka aloittaa?"))


func _exit_tree() -> void:
	if is_instance_valid(_hall):
		_hall.queue_free()


# --- Olohuone, televisio ja hahmot --------------------------------------------------------------------------------

func _build() -> void:
	_hall = Room.hall(anchor, style, sun)
	# Mikrofoniteline: jalka, putki ja mikrofoni suun korkeudella laulajan edessä.
	var m := CENTER + MIC + Vector3(0, 0, 0.38)
	B.mesh(_hall, B.cyl(0.14, 0.16, 0.025, 16), m + Vector3(0, 0.012, 0), Color(0.1, 0.1, 0.11))
	B.mesh(_hall, B.cyl(0.012, 0.012, 1.42, 8), m + Vector3(0, 0.71, 0), Color(0.6, 0.6, 0.64))
	B.mesh(_hall, B.cyl(0.024, 0.017, 0.13, 12), m + Vector3(0, 1.47, -0.05), Color(0.12, 0.12, 0.13), Vector3(-0.6, 0, 0))
	B.mesh(_hall, B.sphere(0.032, 12), m + Vector3(0, 1.52, -0.1), Color(0.55, 0.55, 0.58))
	# Putkitelkkari tasolla, ruudulla sininen karaoketausta ja nykyinen rivi.
	var tv := CENTER + TV
	B.mesh(_hall, B.boxm(Vector3(0.9, 0.5, 0.45)), tv + Vector3(0, 0.25, 0), Room.WOOD.darkened(0.2))
	B.mesh(_hall, B.boxm(Vector3(0.72, 0.56, 0.5)), tv + Vector3(0, 0.78, 0), Color(0.16, 0.16, 0.17))
	var scr := B.mesh(_hall, B.boxm(Vector3(0.6, 0.44, 0.01)), tv + Vector3(0, 0.79, 0.255), Color(0.1, 0.2, 0.7))
	var sm := StandardMaterial3D.new()
	_scr_mat = sm
	sm.albedo_color = Color(0.1, 0.2, 0.7)
	sm.emission_enabled = true
	sm.emission = Color(0.1, 0.25, 0.85)
	sm.emission_energy_multiplier = 1.4
	scr.material_override = sm
	_tv_text = Label3D.new()
	_tv_text.font_size = 40
	_tv_text.pixel_size = 0.0011
	_tv_text.width = 520
	_tv_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tv_text.modulate = Color(1, 1, 0.85)
	_tv_text.outline_size = 6
	_tv_text.text = "KARAOKE"
	_tv_text.position = tv + Vector3(0, 0.79, 0.262)
	_hall.add_child(_tv_text)
	var tvl := OmniLight3D.new()
	_tvl = tvl
	tvl.light_color = Color(0.35, 0.5, 1.0)
	tvl.light_energy = 0.8
	tvl.omni_range = 2.0
	tvl.position = tv + Vector3(0, 0.8, 0.5)
	_hall.add_child(tvl)
	var spot := OmniLight3D.new()  # laulajan valo
	_spot = spot
	spot.light_color = Color(1.0, 0.85, 0.65)
	spot.light_energy = 1.4
	spot.omni_range = 2.2
	spot.position = CENTER + MIC + Vector3(0, 2.0, 0.9)
	_hall.add_child(spot)
	for a: Vector3 in AUDIENCE:
		var p := CENTER + a
		B.mesh(_hall, B.cyl(0.19, 0.19, 0.05, 16), p + Vector3(0, STOOL_H - 0.025, 0), Room.WOOD.lightened(0.1))
		for k in 3:
			var ang := TAU * k / 3.0
			B.mesh(_hall, B.cyl(0.018, 0.022, STOOL_H - 0.05, 6), p + Vector3(cos(ang) * 0.13, (STOOL_H - 0.05) / 2.0,
				sin(ang) * 0.13), Room.WOOD.darkened(0.2))
	_cam = Room.camera(_hall)
	_frame_cam()
	_cam.current = true
	_hall._set_layers(_hall)


## Kamera edestä: laulaja ja mikrofoni keskelle, televisio vasempaan reunaan, yleisö rajautuu reunoilta (projisoitu).
func _frame_cam() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aim := CENTER + MIC + Vector3(-0.3, 1.1, 0)
	for i in 30:
		var d := 2.2 + i * 0.08
		var eye := CENTER + MIC + Vector3(0.0, 1.4 + d * 0.08, d)
		_cam.transform = Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye)
		var tvp := _cam.unproject_position(_hall.to_global(CENTER + TV + Vector3(-0.2, 0.8, 0.25)))
		var head := _cam.unproject_position(_hall.to_global(CENTER + MIC + Vector3(0, 1.8, 0)))
		if tvp.x >= vs.x * 0.04 and head.y >= vs.y * 0.18:
			break
	_cam_base = _cam.transform


## Laulaja mikrofonille, muut jakkaroille: vasemmalla vuoroaan odottava (tai jo laulanut) mies, oikealla nainen.
func _place(s: int) -> void:
	for c in [_singer] + _audience:
		if c != null:
			(c as Node).queue_free()
	_singer = Room.stand(_hall, people[s].look, CENTER + MIC, Vector3(0, 0, 1), "Idle")
	var wait: int = _turns[_turn + 1] if _turn + 1 < _turns.size() else _turns[0]
	if wait == s:
		wait = _turns[1]
	for k in 2:
		var who: int = wait if k == 0 else 3
		var at: Vector3 = CENTER + AUDIENCE[k]
		var c := Room.seat(_hall, people[who].look, at, (CENTER + MIC - at).normalized(), 0.0)
		var pel: float = _hall.to_local(c.to_global(c.bone_position("pelvis"))).y
		c.position.y += STOOL_H + 0.1 - pel  # lantion luu 10 cm jakkaran kannen yllä
		_audience[k] = c
	_hall._set_layers(_hall)


## Säkeistö karaoke_game.gd:n muotoon: rivi = [[sana, sävel, kesto tavuina], ...]; melodia riveittäin, rivin
## viimeinen sana pitkä ja pitkät sanat kahden tavun mittaisia.
static func verse_song(verse: Array) -> Array:
	var out: Array = []
	for li in verse.size():
		var ws: PackedStringArray = String(verse[li]).split(" ", false)
		var row: Array = []
		var mel: Array = MELODY[li % MELODY.size()]
		for i in ws.size():
			var last := i == ws.size() - 1
			var p: int = mel[mini(roundi(i * 7.0 / maxf(1.0, ws.size() - 1)), 7)]
			row.append([ws[i], p, 3 if last else (2 if ws[i].length() > 7 else 1)])
		out.append(row)
	return out


# --- Vuorot -------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	for s in 4:
		if _bubble_t[s] > 0.0:
			_bubble_t[s] -= delta
			if _bubble_t[s] <= 0.0:
				_bubbles[s] = ""
	if _phase in LEG:
		if Input.is_action_just_pressed("mount"):
			_leg_result()
			return
		_leg_step(delta)
		_update_keys()
		_ui.queue_redraw()
		return
	if _phase != "laulu" and Input.is_action_just_pressed("mount") and _phase != "loppu" and _phase != "valmis":
		_finish({"luovutti": true, "kiva": "karaoke"})
		return
	match _phase:
		"alku":
			if _t > 3.0:
				_sing()
		"laulu":
			_drive()
			if _singer != null and _kg != null:
				Room.nod(_singer, 0.12 if float(_kg.get("_voice_hz")) > 0.0 else 0.0)
		"reaktio":
			if _t > 3.0:
				_turn += 1
				if _turn >= _turns.size():
					_end()
				else:
					_place(_turns[_turn])
					_sing()
		"loppu":
			if _pressed() or (auto and _t > 2.0):
				_finish({"voitto": _winner() == 0, "pisteet": roundi(_scores[0] * 100.0), "kiva": "karaoke"})
	_cam.transform = _cam_base
	_update_keys()
	_ui.queue_redraw()


func _pressed() -> bool:
	return Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")


## Vuoron laulu: karaoke_game.gd laulajan säkeistöllä; tausta läpikuultavammaksi, sanarivi televisioon.
func _sing() -> void:
	var s: int = _turns[_turn]
	_phase = "laulu"
	_t = 0.0
	_story = ""
	_plan.clear()
	_singer.play("Idle_Talking", 0.3)
	var g := KaraokeGame.new()
	g.song = verse_song(lines.get("sakeet", {}).get(String(people[s].id), ["La la la la"]))
	g.drunk = drunk if s == 0 else 0.0
	g.set("_title", "%s: %s" % ["Sinä" if s == 0 else String(people[s].name), _line("nimet_" + String(people[s].id), "Iltalaulu")])
	g.line.connect(func(text: String) -> void: _tv_text.text = text)
	g.finished.connect(func(sc: float) -> void:
		_scores[s] = sc
		g.queue_free()
		_kg = null
		_after(s, sc))
	add_child(g)
	var bg := g.get_child(0) as ColorRect
	var bc := bg.color
	bc.a = 0.45  # olohuone ja laulaja näkyvät nuottikaistojen takaa
	bg.color = bc
	_kg = g


## Tekoäly näppäilee kaverin vuorolla (ja testissä pelaajan): jokaiselle nuotille painallusaika tarkkuuden mukaan.
func _drive() -> void:
	var s: int = _turns[_turn]
	if _kg == null or (s == 0 and not auto):
		return
	var skill: float = {0: 0.9, 1: 0.72, 2: 0.82}.get(s, 0.75)
	var t: float = float(_kg.get("_t"))
	var notes: Array = _kg.get("_notes")
	for i in notes.size():
		var n: Dictionary = notes[i]
		if not _plan.has(i):
			var hit := _rng.randf() < skill
			var err := _rng.randfn(0.0, 0.05 if hit else 0.3)
			var at: float = float(n.t) + err
			_plan[i] = [at, at + maxf(float(n.dur), 0.12), hit, false, false]
		var p: Array = _plan[i]
		if not p[3] and t >= float(p[0]):
			p[3] = true
			if p[2]:
				_kg.lane_press(int(n.lane), float(p[0]))
		if p[3] and not p[4] and t >= float(p[1]):
			p[4] = true
			_kg.lane_release(int(n.lane))


func _after(s: int, sc: float) -> void:
	_phase = "reaktio"
	_t = 0.0
	_singer.play("Idle", 0.3)
	_tv_text.text = "%d %%" % roundi(sc * 100.0)
	_story = "%s: %d %%." % ["Sinä" if s == 0 else String(people[s].name), roundi(sc * 100.0)]
	var key := "kehu" if sc >= 0.6 else "pilkka"
	var t: String = _line(key, "Hehe.")
	_say(3, t % ("sää" if s == 0 else String(people[s].name)) if "%s" in t else t)
	if s != 0:
		var own: Array = lines.get("kommentti", {}).get(String(people[s].id), [])
		if not own.is_empty() and _rng.randf() < 0.7:
			_say(1 if _audience[0] != null else s, own.pick_random())
	Sfx.play("win_small" if sc >= 0.6 else "lose", -10.0)


func _winner() -> int:
	var best := 0
	for s in 3:
		if _scores[s] > _scores[best]:
			best = s
	return best


func _end() -> void:
	_phase = "loppu"
	_t = 0.0
	var w := _winner()
	if w == 0 and legend and lines.has("legenda"):
		_leg_begin()
		return
	Sfx.play("win" if w == 0 else "lose", -4.0)
	if w == 0:
		_story = "Voitit karaoken (%d %%)! %s nukkuu sun vieressä, ja naapurit kuuli jokaisen sanan." % [roundi(_scores[0] * 100.0),
			people[3].name]
		_say(3, _line("voitto", "Sää lauloit parhaiten."))
	else:
		_story = "%s voitti (%d %%, sinä %d %%). Sää nukut sohvalla mikrofoni kainalossa." % [people[w].name,
			roundi(_scores[w] * 100.0), roundi(_scores[0] * 100.0)]
		var t: String = _line("havio", "%s voitti!")
		_say(3, t % people[w].name if "%s" in t else t)


func _finish(r: Dictionary) -> void:
	if _phase == "valmis":
		return
	_phase = "valmis"
	if _kg != null:
		_kg.queue_free()
	_mus.on = false
	finished.emit(r)
	queue_free()


# --- Puhe ja käyttöliittymä ---------------------------------------------------------------------------------------

func _line(key: String, fallback: String) -> String:
	var l: Variant = lines.get(key, [])
	return (l as Array).pick_random() if l is Array and not (l as Array).is_empty() else fallback


func _say(s: int, text: String) -> void:
	_bubbles[s] = "%s: %s" % [people[s].name, text] if s != 0 else text
	_bubble_t[s] = 3.4


## Puhujan hahmo: laulaja, oikea jakkara (nainen) tai vasen jakkara (odottava kaveri).
func _who(s: int) -> Node3D:
	if _phase in LEG:
		return _leg_chars[s]
	if _turn < _turns.size() and s == _turns[_turn]:
		return _singer
	return _audience[1] if s == 3 else _audience[0]


func _update_keys() -> void:
	match _phase:
		"laulu":
			_keys.set_text("")  # karaoke näyttää omat näppäimensä
		"loppu":
			_keys.set_text("%s jatka" % Settings.cap("interact"))
		"kerto", "naapuri", "finaali", "ennatys", "otsikko":
			_keys.set_text("%s ohita" % Settings.cap("mount"))
		_:
			_keys.set_text("%s lopeta" % Settings.cap("mount"))


func _draw_ui() -> void:
	if _phase == "laulu":
		return  # karaoke piirtää oman näkymänsä
	if _phase in LEG:
		_draw_legend(_ui.size)
		return
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	var top := "KARAOKE   Sinä %d %%   %s %d %%   %s %d %%" % [roundi(_scores[0] * 100.0), people[1].name,
		roundi(_scores[1] * 100.0), people[2].name, roundi(_scores[2] * 100.0)]
	Room.box(_ui, Rect2(vs.x / 2.0 - 380, 14, 760, 40), Color(0, 0, 0, 0.55))
	_ui.draw_string(font, Vector2(vs.x / 2.0 - 370, 42), top, HORIZONTAL_ALIGNMENT_CENTER, 740, 20, Color.WHITE)
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 400, 62, 800, 60)
		Room.box(_ui, r)
		_ui.draw_multiline_string(font, r.position + Vector2(16, 25), _story, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 18, 2,
			Color(1.0, 0.92, 0.75))
	for s in 4:
		Room.bubble(_ui, _cam, _who(s), _bubbles[s], 130.0 if _story != "" else 64.0, 120.0)


# --- Legendaarinen hetki "karaokekunkku" ------------------------------------------------------------------------
# Ensimmäinen voitto (main.gd _kolmio_ilta legend): kerto (kaverit nousevat jakkaroilta mikin viereen, nainen
# kiipeää jakkaralle, koko porukka laulaa), naapuri (naapuritalon ikkuna syttyy, patteri kolisee, naapuri huutaa
# ikkunasta; vastakuva ikkunan suunnasta, kaikki jähmettyvät), finaali (rivoin rivi suoraan naapurin suuntaan,
# naapuritalo herää), ennatys (telkkari laskee pisteet ennätykseen) ja otsikko.

func _leg_begin() -> void:
	_phase = "kerto"
	_t = 0.0
	_once.clear()
	_story = String(lines.legenda.kerto)
	for s in 4:
		_bubbles[s] = ""
		_bubble_t[s] = 0.0
	for c in [_singer] + _audience:
		if c != null:
			(c as Node).queue_free()
	_singer = null
	_audience = [null, null]
	var mic := CENTER + MIC
	_leg_chars[0] = Room.stand(_hall, people[0].look, mic, Vector3(0, 0, 1), "Idle_Talking")
	_leg_chars[1] = Room.stand(_hall, people[1].look, mic + Vector3(-0.8, 0, 0.22), Vector3(0.3, 0, 1).normalized(), "Dance")
	_leg_chars[2] = Room.stand(_hall, people[2].look, mic + Vector3(0.68, 0, 0.12), Vector3(-0.2, 0, 1).normalized(), "Dance")
	# Nainen seisoo jakkaralla (oikea jakkara): jalkapohjat kannen pinnalle.
	var st: Vector3 = CENTER + AUDIENCE[1]
	_leg_chars[3] = Room.stand(_hall, people[3].look, st + Vector3(0, STOOL_H, 0), Vector3(-0.45, 0, 1).normalized(), "Idle_Talking")
	_stool_feet()
	_build_leg_props()
	_tv_text.text = String((lines.legenda.tv as Array)[0])
	_mus.on = true
	_mus.t = 0.0
	_mus.vol = 0.8
	_mus.crowd = 1.0
	_mus.hold = -1.0
	if _leg_pb == null:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = KaraokeGame.RATE
		gen.buffer_length = 0.15
		var pl := AudioStreamPlayer.new()
		pl.stream = gen
		pl.volume_db = -4.0
		pl.bus = "SFX"
		add_child(pl)
		pl.play()
		_leg_pb = pl.get_stream_playback()
	_leg_wide(0.0)
	Sfx.play("win_small", -8.0)


## Patteri ikkunan alle, naapuritalo ikkunan vasempaan alaruutuun (kaukana pimeässä, ikkunat sammuksissa) ja
## etuseinä täyteen korkeuteen ja katto (vastakuva ikkunan suunnasta katsoo niitä kohti).
func _build_leg_props() -> void:
	var white := Color(0.9, 0.9, 0.86)
	_rad = Node3D.new()
	_rad_base = Vector3(WIN_X, 0.0, 0.0)
	_rad.position = _rad_base
	_hall.add_child(_rad)
	B.mesh(_rad, B.boxm(Vector3(1.1, 0.48, 0.05)), Vector3(0, 0.46, 0.07), white.darkened(0.08))
	for i in 16:  # rivat: vaalea etupinta, tumma rako välissä
		B.mesh(_rad, B.boxm(Vector3(0.045, 0.5, 0.09)), Vector3(-0.51 + i * 0.068, 0.46, 0.1), white)
	B.mesh(_rad, B.boxm(Vector3(1.12, 0.03, 0.1)), Vector3(0, 0.72, 0.1), white.lightened(0.3))
	B.mesh(_rad, B.cyl(0.016, 0.016, 0.22, 8), Vector3(0.62, 0.11, 0.1), Color(0.75, 0.75, 0.72))
	B.mesh(_rad, B.cyl(0.032, 0.032, 0.05, 10), Vector3(0.62, 0.25, 0.1), Color(0.85, 0.85, 0.85))  # termostaatti
	# Naapuritalo: tumma siluetti katolla, kolme ikkunaa (sammuksissa), huutajan ikkuna keskellä.
	var nx := WIN_X + 0.43  # oikea alaruutu (vasemmassa on ikkunalaudan kukka)
	var house := Color(0.05, 0.06, 0.12)
	B.mesh(_hall, B.boxm(Vector3(0.74, 0.36, 0.004)), Vector3(nx, 1.06, 0.021), house)
	var roof := PrismMesh.new()
	roof.size = Vector3(0.82, 0.2, 0.004)
	B.mesh(_hall, roof, Vector3(nx, 1.34, 0.021), house)
	B.mesh(_hall, B.boxm(Vector3(0.05, 0.12, 0.004)), Vector3(nx + 0.2, 1.35, 0.019), house)  # savupiippu
	_nb_wins.clear()
	for w in [[0.0, 1.08, 0.19, 0.13], [-0.25, 1.04, 0.1, 0.1], [0.25, 1.04, 0.1, 0.1]]:
		var m := B.mesh(_hall, B.boxm(Vector3(w[2], w[3], 0.004)), Vector3(nx + w[0], w[1], 0.024), Color(0.1, 0.1, 0.13))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.13)
		mat.emission = Color(1.0, 0.78, 0.38)
		m.material_override = mat
		_nb_wins.append(m)
	# Naapuri ikkunassa: pää, hartiat ja nyrkkiin puristettu käsi ylhäällä (tumma vastavaloa vasten).
	_nb_fig = Node3D.new()
	_nb_fig.position = Vector3(nx, 1.03, 0.027)
	_hall.add_child(_nb_fig)
	var fc := Color(0.03, 0.02, 0.02)
	B.mesh(_nb_fig, B.sphere(0.022, 10), Vector3(0, 0.07, 0), fc)
	B.mesh(_nb_fig, B.boxm(Vector3(0.09, 0.06, 0.003)), Vector3(0, 0.025, 0), fc)
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = Vector3(0.04, 0.045, 0)
	_nb_fig.add_child(arm)
	B.mesh(arm, B.boxm(Vector3(0.016, 0.06, 0.003)), Vector3(0, 0.03, 0), fc)
	B.mesh(arm, B.sphere(0.013, 8), Vector3(0, 0.065, 0), fc)
	_nb_fig.visible = false
	var wall: Color = _hall.style.get("wall", Color(0.82, 0.72, 0.58))
	var fw := B.mesh(_hall, B.boxm(Vector3(Rasva.ROOM.x, Hall.WALL_H, 0.16)), Vector3(Rasva.ROOM.x / 2.0, Hall.WALL_H / 2.0, Rasva.ROOM.y + 0.08), wall)
	for i in int(Rasva.ROOM.x / 0.3):
		B.mesh(fw, B.boxm(Vector3(0.1, Hall.WALL_H - 0.1, 0.004)), Vector3(-Rasva.ROOM.x / 2.0 + 0.15 + i * 0.3, 0.05, -0.082), wall.darkened(0.08))
	B.mesh(_hall, B.boxm(Vector3(Rasva.ROOM.x, 0.06, Rasva.ROOM.y + 0.3)), Vector3(Rasva.ROOM.x / 2.0, Hall.WALL_H + 0.03,
		Rasva.ROOM.y / 2.0), Color(0.94, 0.92, 0.86))
	_hall._set_layers(_hall)


func _nb_light(i: int, on: bool) -> void:
	var mat := (_nb_wins[i] as MeshInstance3D).material_override as StandardMaterial3D
	mat.emission_enabled = on
	mat.emission_energy_multiplier = 2.2
	mat.albedo_color = Color(1.0, 0.8, 0.45) if on else Color(0.1, 0.1, 0.13)


func _leg_set_cam(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = fov
	_leg_cam_base = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
	_cam.transform = _leg_cam_base


## Laaja kuva edestä: mikki ja pelaaja keskellä, kaverit vierellä, nainen jakkaralla oikealla ja ikkuna takana.
## push = hidas lähestyminen 0..1.
func _leg_wide(push: float) -> void:
	var mic := CENTER + MIC
	_leg_frame(mic + Vector3(0.5, 1.5, 0.4), Vector3(0.05, 0.1, 1.0), 0.3, 62.0, push * 0.3)


## Kamera suunnasta dir kohteeseen aim, niin kaukaa, että kaikkien hahmojen päät ovat ruudulla vähintään top_frac
## ylhäältä ja sivureunojen sisällä (projisoitu, etuseinä rajoittaa); push siirtää lopuksi lähemmäs.
func _leg_frame(aim: Vector3, dir: Vector3, top_frac: float, fov: float, push := 0.0) -> void:
	var vs := get_viewport().get_visible_rect().size
	var d := dir.normalized()
	var eye := aim + d * 2.0
	for i in 40:
		eye = aim + d * (2.0 + i * 0.08)
		if eye.z > Rasva.ROOM.y - 0.2:
			break
		_leg_set_cam(eye, aim, fov)
		var ok := true
		for c in _leg_chars:
			var h := _cam.unproject_position((c as Node3D).to_global((c as Node3D).bone_position("Head")) + Vector3(0, 0.16, 0))
			if h.y < vs.y * top_frac or h.x < vs.x * 0.06 or h.x > vs.x * 0.94:
				ok = false
		if ok:
			break
	_leg_set_cam(eye - d * push, aim, fov)


## Nainen seisoo jakkaralla: lantio kannen keskikohdan yllä ja jalkaterät IK:lla vierekkäin kannelle (animaation
## haara-asento ei mahdu 19 cm:n kannelle), pohjat vaakaan. Kutsutaan, kun naisen suunta on asetettu.
func _stool_feet() -> void:
	var w: Node3D = _leg_chars[3]
	var st: Vector3 = CENTER + AUDIENCE[1]
	w.anim.advance(0.01)
	var pel: Vector3 = w.basis * w.bone_position("pelvis")
	w.position = Vector3(st.x - pel.x, STOOL_H, st.z - pel.z)
	var f := -w.basis.z
	f = Vector3(f.x, 0, f.z).normalized()
	var left := Vector3.UP.cross(f)
	var sole: float = float(w.get("shoe_sole") if w.get("shoe_sole") != null else 0.0)
	var inv := w.transform.affine_inverse()
	var gb := w.transform.basis.orthonormalized()
	var want := Basis(Vector3.UP.cross(-f).normalized(), Vector3.UP, -f)
	for lr: String in ["_l", "_r"]:
		var tgt := st + Vector3(0, STOOL_H + Pose.FOOT_H + sole, 0) + left * (0.075 if lr == "_l" else -0.075) - f * 0.03
		var hip: Vector3 = w.transform * w.bone_position("thigh" + lr)
		var pole := (hip + tgt) / 2.0 + f * 0.4
		w.set_ik("leg" + lr, "thigh" + lr, "calf" + lr, "foot" + lr, inv * tgt, inv * pole)
		w.set_ik_orient("leg" + lr, gb.inverse() * want * Pose.Contact.foot_basis(w, lr, true), 1.0)


func _face(c: Node3D, target: Vector3) -> void:
	var f := target - c.position
	f.y = 0.0
	c.rotation.y = atan2(-f.x, -f.z)
	if c == _leg_chars[3]:
		_stool_feet()


func _bang() -> void:
	Sfx.play("punch_heavy", -2.0, 0.6)
	Sfx.play("rattle_hard", -12.0, 0.7)
	_shake = 0.5


func _leg_step(delta: float) -> void:
	_leg_audio()
	_shake = maxf(0.0, _shake - delta * 2.2)
	if is_instance_valid(_rad):
		_rad.position = _rad_base + Vector3(randf_range(-1, 1) * 0.012, 0, randf_range(-1, 1) * 0.008) * (_shake / 0.5)
	var mic := CENTER + MIC
	var p: Node3D = _leg_chars[0]
	match _phase:
		"kerto":
			var u := clampf(_t / 6.0, 0.0, 1.0)
			if not _once.has("wide"):
				_once.wide = true
				_leg_wide(0.0)
				_once.wide_base = _leg_cam_base
			var wb: Transform3D = _once.wide_base
			_leg_cam_base = Transform3D(wb.basis, wb.origin - wb.basis.z * u * 0.3)
			Room.nod(p, 0.1 + 0.08 * sin(_t * 9.0))
			_spot.light_energy = 1.4 + 0.6 * absf(sin(_t * 5.2))
			if _t > 0.8 and not _once.has("r0"):
				_once.r0 = true
				_leg_say(0, 3.4)
			if _t > 2.9 and not _once.has("r1"):
				_once.r1 = true
				_bubbles[int(lines.legenda.rivit[0][0])] = ""
				_tv_text.text = String((lines.legenda.tv as Array)[1])
				_leg_say(1, 3.0)
			if _t > 6.2:
				_phase = "naapuri"
				_t = 0.0
				for s in 4:
					_bubbles[s] = ""
				_story = String(lines.legenda.naapuri_story)
				# Ikkunan ja patterin lähikuva: naapuritalo pimeänä, olohuoneen laulu jatkuu.
				_leg_set_cam(Vector3(WIN_X + 0.15, 1.2, 2.1), Vector3(WIN_X + 0.25, 0.95, 0.0), 42.0)
		"naapuri":
			if _t > 0.5 and not _once.has("valo"):
				_once.valo = true
				_nb_light(0, true)
				_nb_fig.visible = true
				Sfx.play("door_close", -16.0, 1.4)
			for k in 3:
				var at := 1.05 + k * 0.38
				if _t > at and not _once.has("kop%d" % k):
					_once["kop%d" % k] = true
					_bang()
					if k == 0:
						_mus.on = false  # musiikki katkeaa kesken
						Sfx.play("rattle", -8.0, 0.5)
			var arm := _nb_fig.get_node("Arm") as Node3D
			arm.rotation.z = -0.25 + 0.35 * sin(_t * 14.0) if _t > 2.0 and _t < 4.3 else -0.1
			if _t > 2.2 and not _once.has("huuto"):
				_once.huuto = true
				_nb_text = "Naapuri: " + String(lines.legenda.naapuri)
				Sfx.play("grunt", -6.0, 0.8)
			if _t > 4.5 and not _once.has("jahmo"):
				_once.jahmo = true
				_nb_text = ""
				_story = String(lines.legenda.hiljaisuus)
				# Vastakuva ikkunan suunnasta: koko porukka jähmettyneenä katsoo ikkunaan (ja kameraan).
				var win := Vector3(WIN_X, 0.0, 0.0)
				for s in 4:
					var c: Node3D = _leg_chars[s]
					_face(c, win)
					c.play("Idle", 0.15)
				Room.nod(p, 0.0)
				_leg_set_cam(Vector3(WIN_X - 0.35, 1.45, 1.0), mic + Vector3(0.45, 1.25, 0.4), 50.0)
			if _t > 5.0 and not _once.has("vastaus"):
				_once.vastaus = true
				_leg_say(2, 3.0)
			if _t > 7.4:
				_phase = "finaali"
				_t = 0.0
				for s in 4:
					_bubbles[s] = ""
				_story = String(lines.legenda.finaali_story)
				for s in 4:
					var c: Node3D = _leg_chars[s]
					_face(c, c.position + Vector3(0, 0, 1) if s == 0 else mic + Vector3(0, 0, 2.0))
					if s > 0:
						c.play("Dance" if s < 3 else "Idle_Talking", 0.2)
				p.play("Idle_Talking", 0.1)
				_tv_text.text = String(lines.legenda.finaali)
				_mus.on = true
				_mus.t = 0.0
				_mus.vol = 1.15
				_mus.crowd = 1.6
				# Lähikuva alaviistosta: laulaja täysillä mikkiin.
				_leg_set_cam(mic + Vector3(-0.3, 1.25, 1.5), mic + Vector3(0.15, 1.5, 0.0), 34.0)
		"finaali":
			if _t < 2.3:
				Room.nod(p, 0.16 + 0.1 * sin(_t * 11.0))
			_spot.light_energy = 1.6 + 1.4 * absf(sin(_t * 7.0))
			if _t > 0.25 and not _once.has("laulu"):
				_once.laulu = true
				_bubbles[0] = "♪ " + String(lines.legenda.finaali) + " ♪"
				_bubble_t[0] = 3.0
			if _t > 2.3 and not _once.has("ikkunaan"):
				_once.ikkunaan = true
				# Koko porukka kääntyy ikkunaan ja laulaa rivin suoraan naapuriin; kuva kunkun olan yli ikkunaan.
				_story = String(lines.legenda.ikkunaan_story)
				var win := Vector3(WIN_X + 0.4, 0.0, 0.0)
				for s in 4:
					var c: Node3D = _leg_chars[s]
					_face(c, win)
					c.play("Idle_Talking", 0.15)
				Room.nod(p, 0.0)
				var f := (win - p.position)
				f.y = 0.0
				f = f.normalized()
				var right := f.cross(Vector3.UP)
				_leg_set_cam(p.position - f * 1.0 + right * 0.42 + Vector3(0, 1.85, 0), Vector3(WIN_X + 0.43, 1.12, 0.0), 40.0)
				_bubbles[0] = ""  # rivi on jo kuplassa; nyt näkyy naapuritalo
			if _t > 3.0 and not _once.has("pito"):
				_once.pito = true
				_mus.hold = 12.0  # viimeinen pitkä sävel oktaavia ylempää
			for k in 2:
				if _t > 3.3 + k * 0.4 and not _once.has("nb%d" % k):
					_once["nb%d" % k] = true
					_nb_light(k + 1, true)  # koko naapuritalo herää
			if _t > 4.6:
				_mus.on = false
				_mus.hold = -1.0
				Sfx.play("glass", -8.0, 1.6)
				_phase = "ennatys"
				_t = 0.0
				for s in 4:
					_bubbles[s] = ""
				_story = ""
				Room.nod(p, 0.0)
				var tv := CENTER + TV
				_tv_text.font_size = 64
				_leg_set_cam(tv + Vector3(-0.2, 0.9, 1.0), tv + Vector3(0, 0.79, 0.25), 40.0)
		"ennatys":
			var sc := roundi(_scores[0] * 100.0)
			var u := clampf((_t - 0.3) / 1.5, 0.0, 1.0)
			var shown := roundi(sc * u)
			if _t < 1.9:
				_tv_text.text = "PISTEET\n%d %%" % shown
				if shown / 10 > int(_once.get("tick", -1)):
					_once.tick = shown / 10
					Sfx.play("coin", -16.0, 0.8 + shown / 80.0)
			else:
				var blink := int(_t * 6.0) % 2 == 0
				_tv_text.text = "UUSI ENNÄTYS!\n%d %%" % sc
				_tv_text.modulate = Color(1, 1, 0.85) if blink else Color(1, 0.9, 0.3)
				var hue := fmod(_t * 0.9, 1.0)
				_scr_mat.emission = Color.from_hsv(hue, 0.8, 1.0)
				_scr_mat.albedo_color = Color.from_hsv(hue, 0.8, 0.8)
				_tvl.light_color = Color.from_hsv(hue, 0.6, 1.0)
				_tvl.light_energy = 1.6
				if not _once.has("ennatys"):
					_once.ennatys = true
					Sfx.play("register", -6.0, 1.3)
					Sfx.play("win_small", -6.0)
			if _t > 2.7 and not _once.has("kuva2"):
				_once.kuva2 = true
				_story = String(lines.legenda.ennatys_story)
				_tv_text.font_size = 40
				_face(p, p.position + Vector3(0, 0, 1))
				for s in [1, 2, 3]:
					var c: Node3D = _leg_chars[s]
					_face(c, p.position + Vector3(0, 0, 1.6))
					c.play("Idle_Talking", 0.2)
				_leg_wide(0.15)
				_leg_say(3, 2.6)
			if _t > 5.3:
				_phase = "otsikko"
				_t = 0.0
				for s in 4:
					_bubbles[s] = ""
				_story = ""
				for s in 4:
					var c: Node3D = _leg_chars[s]
					_face(c, c.position + Vector3(0, 0, 1))
					c.play("Dance" if s < 3 else "Idle_Talking", 0.2)
				p.play("Dance", 0.2)
				_leg_frame(mic + Vector3(0.45, 1.45, 0.3), Vector3(-0.12, 0.0, 1.0), 0.3, 60.0)
				Sfx.play("win", -4.0)
		"otsikko":
			_spot.light_energy = 1.4 + 0.8 * absf(sin(_t * 4.0))
			if _t > 5.6:
				_leg_result()
				return
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.025 * _shake
	_cam.transform = Transform3D(_leg_cam_base.basis, _leg_cam_base.origin + _leg_cam_base.basis * off)


## Legendan repliikki i (lines.legenda.rivit: [istuin, teksti]) kuplaksi puhujan pään yläpuolelle.
func _leg_say(i: int, dur: float) -> void:
	var r: Array = lines.legenda.rivit[i]
	_say(int(r[0]), String(r[1]))
	_bubble_t[int(r[0])] = dur


func _leg_result() -> void:
	_mus.on = false
	_finish({"voitto": true, "pisteet": roundi(_scores[0] * 100.0), "kiva": "karaoke", "legenda": true})


## Syntetisoitu kertosäe (kuten karaoke_game.gd _fill_audio): rumpu, basso ja melodia sahalaitana; crowd lisää
## kaksi hieman epävireistä ääntä (kaverit ja nainen laulavat mukana), hold pitää viimeisen sävelen.
func _leg_audio() -> void:
	if _leg_pb == null:
		return
	var n := _leg_pb.get_frames_available()
	var mel: Array = MELODY[0] + MELODY[1] + MELODY[2] + MELODY[3]
	var rate: float = KaraokeGame.RATE
	var on: bool = _mus.on
	var vol: float = _mus.vol
	var crowd: float = _mus.crowd
	var hold: float = _mus.hold
	var t: float = _mus.t
	for i in n:
		var s := 0.0
		if on:
			t += 1.0 / rate
			var bt := fmod(t, 0.6)
			s += sin(_ph[0]) * exp(-bt * 18.0) * 0.45
			_ph[0] = fmod(_ph[0] + TAU * (55.0 + 90.0 * exp(-bt * 30.0)) / rate, TAU)
			var bass_hz: float = [98.0, 130.8, 110.0, 146.8][int(t / 2.4) % 4]
			_ph[1] = fmod(_ph[1] + bass_hz / rate, 1.0)
			s += (absf(_ph[1] * 2.0 - 1.0) * 2.0 - 1.0) * 0.16
			var pitch: float = hold if hold >= 0.0 else float(mel[int(t / 0.3) % mel.size()])
			var hz := KaraokeGame.BASE_HZ * pow(2.0, pitch / 12.0)
			var env := 1.0 if hold >= 0.0 else 1.0 - fmod(t, 0.3) / 0.3 * 0.5
			for v in 3:
				if v > 0 and crowd <= 0.0:
					break
				var det: float = [1.0, 1.007, 0.994][v]
				_ph[2 + v] = fmod(_ph[2 + v] + hz * det / rate, 1.0)
				s += (_ph[2 + v] * 2.0 - 1.0) * env * (0.13 if v == 0 else 0.06 * crowd)
			s *= vol
		_leg_pb.push_frame(Vector2(s, s))
	_mus.t = t


## Kupla naapurin siluetille (piste maailmassa), nokka ikkunaan.
func _bubble_at(pos: Vector3, text: String) -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	var head := _cam.unproject_position(_hall.to_global(pos))
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var w := minf(tw + 32.0, 420.0)
	var nl := clampi(ceili(tw * 1.08 / (w - 32.0)), 1, 3)
	var bh := 24.0 * nl + 20.0
	var r := Rect2(head.x - w * 0.3, head.y - bh - 70.0, w, bh)
	r.position.x = clampf(r.position.x, 10.0, vs.x - w - 10.0)
	r.position.y = clampf(r.position.y, 90.0, vs.y - bh - 60.0)
	MG.bubble(_ui, r, head, "", 20)
	_ui.draw_multiline_string(font, r.position + Vector2(16, 30), text, HORIZONTAL_ALIGNMENT_CENTER, w - 32.0, 20, nl,
		Color(0.1, 0.08, 0.06))


func _draw_legend(vs: Vector2) -> void:
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 430, 24, 860, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for s in 4:
		Room.bubble(_ui, _cam, _leg_chars[s], _bubbles[s], 90.0, 120.0)
	if _nb_text != "":
		_bubble_at(_nb_fig.position + Vector3(0, 0.08, 0), _nb_text)
	if _phase != "otsikko":
		return
	_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.02, 0.05, 0.42 * clampf(_t / 0.8, 0.0, 1.0)))
	var a := clampf((_t - 0.5) / 0.8, 0.0, 1.0)
	var x0 := vs.x * 0.15
	var w := vs.x * 0.7
	var y := vs.y * 0.24
	var title := "KARAOKEKUNKKU"
	var size := 72
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var tx := x0 + (w - tw) / 2.0
	# Nuotit nousevat kirjaimista ja keinuvat (kuin kaiuttimesta), vuorotellen kahdeksasosa ja kahdeksasosapari.
	for i in 10:
		var ph := fmod(_t * 0.45 + i * 0.137, 1.0)
		var nx := tx + tw * (0.04 + 0.1 * i) + sin(_t * 2.4 + i) * 10.0
		var ny := y - 30.0 - ph * 150.0
		var na := a * (1.0 - ph) * clampf(ph * 6.0, 0.0, 1.0)
		var col := Color(1.0, 0.85, 0.4, na)
		_ui.draw_circle(Vector2(nx, ny), 7.0, col)
		_ui.draw_line(Vector2(nx + 6.0, ny), Vector2(nx + 6.0, ny - 26.0), col, 2.5)
		if i % 2 == 0:
			_ui.draw_line(Vector2(nx + 6.0, ny - 26.0), Vector2(nx + 15.0, ny - 17.0), col, 2.5)
		else:
			_ui.draw_circle(Vector2(nx + 20.0, ny + 3.0), 7.0, col)
			_ui.draw_line(Vector2(nx + 26.0, ny + 3.0), Vector2(nx + 26.0, ny - 23.0), col, 2.5)
			_ui.draw_line(Vector2(nx + 6.0, ny - 26.0), Vector2(nx + 26.0, ny - 23.0), col, 4.0)
	_ui.draw_string_outline(font, Vector2(x0, y), title, HORIZONTAL_ALIGNMENT_CENTER, w, size, 10, Color(0.1, 0.05, 0.0, a))
	_ui.draw_string(font, Vector2(x0, y), title, HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(1.0, 0.82, 0.35, a))
	var sr := Rect2(vs.x * 0.2, vs.y - 168.0, vs.x * 0.6, 100)
	_ui.draw_rect(sr, Color(0.05, 0.04, 0.03, 0.75 * a))
	var sub := "%d %% ja uusi ennätys. %s" % [roundi(_scores[0] * 100.0), String(lines.legenda.sub)]
	_ui.draw_multiline_string(font, sr.position + Vector2(18, 34), sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 36, 20, 4,
		Color(1.0, 0.94, 0.8, a))


# --- Testi (tools/testit/iltakivat_kuvat.gd) ----------------------------------------------------------------------

func test_target() -> Array:
	return [_hall.to_global(CENTER + MIC + Vector3(0, 1.52, 0.28)), 0.06]


func test_closeup() -> void:
	var p := CENTER + MIC + Vector3(0, 1.45, 0.2)
	var eye := p + Vector3(0.3, 0.1, 1.3)
	_cam_base = Transform3D(Basis.looking_at(p - eye, Vector3.UP), eye)
	_cam.transform = _cam_base
