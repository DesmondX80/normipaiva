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
	tvl.light_color = Color(0.35, 0.5, 1.0)
	tvl.light_energy = 0.8
	tvl.omni_range = 2.0
	tvl.position = tv + Vector3(0, 0.8, 0.5)
	_hall.add_child(tvl)
	var spot := OmniLight3D.new()  # laulajan valo
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
	if _turn < _turns.size() and s == _turns[_turn]:
		return _singer
	return _audience[1] if s == 3 else _audience[0]


func _update_keys() -> void:
	match _phase:
		"laulu":
			_keys.set_text("")  # karaoke näyttää omat näppäimensä
		"loppu":
			_keys.set_text("%s jatka" % Settings.cap("interact"))
		_:
			_keys.set_text("%s lopeta" % Settings.cap("mount"))


func _draw_ui() -> void:
	if _phase == "laulu":
		return  # karaoke piirtää oman näkymänsä
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


# --- Testi (tools/testit/iltakivat_kuvat.gd) ----------------------------------------------------------------------

func test_target() -> Array:
	return [_hall.to_global(CENTER + MIC + Vector3(0, 1.52, 0.28)), 0.06]


func test_closeup() -> void:
	var p := CENTER + MIC + Vector3(0, 1.45, 0.2)
	var eye := p + Vector3(0.3, 0.1, 1.3)
	_cam.transform = Transform3D(Basis.looking_at(p - eye, Vector3.UP), eye)
