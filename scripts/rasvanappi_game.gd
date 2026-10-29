extends CanvasLayer
## Rasvanappi aseman makasiinin takahuoneessa Saloisissa ja Vaalassa (vain aikuisille, makasiini.gd).
## 1. Takaovella koputetaan, kurkistusluukku aukeaa ja portsari kysyy salasanan (väärä = luukku kiinni). Kohtaus on
##    3D:nä makasiinin oikealla takaovella (makasiini.gd _build_door): kamera oven edessä, portsari eteiskomerossa
##    luukun takana, oikealla salasanalla ovi aukeaa.
## 2. Sisällä pelaajat esittäytyvät pyyhkeissään: kuka kiroilee, kuka kikattaa, kuka niiskuttaa. Muista äänet.
## 3. Valot pois, kaikki konttaavat pimeässä (ylhäältä kuvattu halli, näkyy vain käsivarren mitta). Rasvanappi
##    hiipii jonkun taakse, tökkää peppuun ja huutaa nimen. Oikein = tökätty nuolee sormen ja on seuraava nappi,
##    väärin = tökkääjä nuolee itse ja jatkaa. Pimeässä muut tunnistaa vain äänestä.
## Kun nappi on joku muu, se jahtaa pimeässä: pysy liikkeessä äläkä anna takapuolta. Ripeä konttaus (juoksu)
## kolisee: muut kuulevat sen, ja nappi arvaa helpommin, kuka kolisi.

signal finished(r: Dictionary)

const MG := preload("res://scripts/mg_draw.gd")
const Makasiini := preload("res://scripts/makasiini.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const Hall := preload("res://scripts/rasvanappi_hall.gd")
const HAIRS := {"short": "Hair_Buzzed", "parted": "Hair_SimpleParted", "long": "Hair_Long"}
## Portsari luukun takana: ruskea venäläinen sotilaspuku (Looks.add_army_uniform), mustat otsalle vinosti kammatut
## hiukset (Looks.add_fringe) ja Charlie Chaplinin viikset (Looks.add_chaplin), tukeva.
const BOUNCER := {
	"shirt": Color(0.4, 0.31, 0.19), "pants": Color(0.34, 0.27, 0.17), "shoes": Color(0.05, 0.05, 0.05),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.04, 0.035, 0.03), "chaplin": true, "fringe": true, "army": true,
	"height": 1.78,
	"skin": Color(0.95, 0.76, 0.66), "belly": 0.45, "bulk": 0.45, "shoulders": 0.5, "muscle": -0.4,
}

const ROOM := Vector2(12.0, 7.0)  # halli metreinä, ovi vasemmalla seinällä
const DOOR_Y := 3.5
const MAX_POKES := 7
const MAX_TIME := 240.0
const CRAWL := 0.75
const HURRY := 1.45
const NPC_CRAWL := 0.5
const HUNT_SPEED := 0.82
const LIGHT_R := 1.7  # näkyvyys pimeässä (m)
const REACH := 0.45
const ME_NAME := "Päivin äijä"
const SKIN_DARK := Color(0.62, 0.5, 0.45)  # pimeässä kaikki ovat saman värisiä
const HAIR_DARK := Color(0.16, 0.13, 0.12)

## Pelaajat: tunnusäänet (puhe pimeässä), ääni [nimi, korkeus], ruumiinrakenne, ulkonäkö esittelyyn.
const PEOPLE := [
	{"id": "pekka", "name": "Pekka", "gen": "Pekan", "desc": "kiroilee", "bulk": 1.25, "col": Color(1.0, 0.62, 0.3),
		"tics": ["Perkele, polvet!", "…perkele…", "Missä perkeleessä te ootte?", "Saatanan lattia."],
		"snd": ["grunt", 0.8], "lick": "Perkele. Floraa.", "towel": Color(0.25, 0.45, 0.25),
		"look": {"hair": "short", "hair_col": Color(0.3, 0.2, 0.12), "beard": true, "skin": Color(0.95, 0.72, 0.6)}},
	{"id": "arto", "name": "Arto", "gen": "Arton", "desc": "hyräilee", "bulk": 0.95, "col": Color(0.55, 0.9, 0.45),
		"tics": ["Hmm-hmm-hmm…", "Lähekkö puolukkaan?", "Hmm-hm… hmm.", "♪ Hmm-hmmm ♪"],
		"snd": ["grunt", 1.15], "lick": "Hmm. Suolatonta.", "towel": Color(0.85, 0.75, 0.3),
		"look": {"hair": "parted", "hair_col": Color(0.55, 0.52, 0.48), "glasses": true, "skin": Color(0.96, 0.78, 0.68)}},
	{"id": "sinikka", "name": "Sinikka", "gen": "Sinikan", "desc": "kikattaa", "bulk": 0.9, "col": Color(1.0, 0.55, 0.75),
		"tics": ["Hihii!", "Voi kulta…", "Hihihii, kuka siellä?", "Ihan kuin piirakkaa…"],
		"snd": ["grunt", 1.75], "lick": "Hihii! Lisää!", "towel": Color(0.9, 0.4, 0.55), "woman": true,
		"look": {"hair": "long", "hair_col": Color(0.95, 0.82, 0.45), "skin": Color(0.98, 0.8, 0.7)}},
	{"id": "raimo", "name": "Raimo", "gen": "Raimon", "desc": "niiskuttaa", "bulk": 1.05, "col": Color(0.6, 0.75, 1.0),
		"tics": ["*niisk*", "*röh-röh*", "Ennen vanhaan… *niisk*", "*niiiisk*"],
		"snd": ["groan", 0.7], "lick": "Ennen vanhaan oli voita.", "towel": Color(0.3, 0.4, 0.75),
		"look": {"hair": "short", "hair_col": Color(0.82, 0.82, 0.8), "beard": true, "skin": Color(0.93, 0.74, 0.66)}},
	{"id": "helena", "name": "Helena", "gen": "Helenan", "desc": "huokailee", "bulk": 0.92, "col": Color(0.95, 0.85, 0.45),
		"tics": ["Huoh…", "Ai että.", "Älä vielä mene…", "Huuuoh."],
		"snd": ["groan", 1.35], "lick": "Ai että.", "towel": Color(0.95, 0.95, 0.92), "woman": true,
		"look": {"hair": "long", "hair_col": Color(0.6, 0.22, 0.12), "skin": Color(0.97, 0.79, 0.7)}},
]

const PASSWORDS := [
	["Rasvanappi.", true, "…Sisään. Kengät ja kaikki muu naulakkoon.", "ok"],
	["Avaa seesam.", false, "Ei avaa. Eikä seesam.", "viha"],
	["Poliisi! Avatkaa!", false, "…Täällä on vaan tavaraa. Varastossa. Tavaraa.", "pelko"],
	["Mää oon Pekan kaveri.", false, "Pekalla ei oo kavereita.", "viha"],
]

## Esteet hallissa (m): lavapinot, laatikot, patjat, sohva, pilarit ja penkki vaatteineen.
const OBST := [
	Rect2(0.3, 0.2, 3.2, 0.45),  # penkki vaatteineen
	Rect2(4.5, 0.2, 1.6, 1.2),  # lavapino
	Rect2(9.9, 0.2, 1.9, 1.0),  # laatikot
	Rect2(10.5, 1.2, 1.3, 0.9),
	Rect2(8.0, 5.3, 2.3, 1.5),  # patjapino
	Rect2(1.4, 6.15, 2.2, 0.65),  # sohva
	Rect2(5.4, 6.0, 1.2, 0.8),  # lava
	Rect2(3.85, 3.35, 0.3, 0.3),  # pilarit
	Rect2(7.85, 3.35, 0.3, 0.3),
	Rect2(0.35, 4.45, 0.55, 0.55),  # jakkara ja margariinirasia
]

var drunk := 0.0
## Erikoissäännöt (kolmiomittaus.gd, #255): peli naisen pimennetyssä olohuoneessa ilman takaovea ja portsaria.
## Avaimet: host (emännän nimi portsarin repliikeissä), kerma (kermavaahto margariinin tilalla), mansikka (oikeasta
## arvauksesta mansikka palkinnoksi), call (Päivin puhelu kesken pelin: [[puhuja, teksti], ...]), end_quote
## (loppurepliikki), style (hallin värit, rasvanappi_hall.gd). Tyhjä = makasiinin tavallinen peli.
var rules := {}
var people: Array = PEOPLE  # pelaajat (ilman Päivin äijää), enintään viisi
var anchor: Node3D  # ilman ovea: halli rakennetaan tämän solmun yläpuolelle ja peli alkaa esittelystä
var strawberries := 0
var _call_done := false
var _call_line := 0
var door: Node3D  # makasiinin takaovi (makasiini.gd "Takaovi"), main.gd asettaa ennen add_childia
var sun: DirectionalLight3D  # maailman aurinko: rajataan pois hallin kerrokselta (rasvanappi_hall.gd)

# Halli 3D:nä (rasvanappi_hall.gd) kaukana taivaalla makasiinin yllä; konttaajat 0..4 = npcs, 5 = pelaaja.
var _hall: Node3D
var _poke_anim := {}  # {"who", "poked", "t"}: tökkääjän käsi kurottaa, tökätty säpsähtää
var _disguised := false

# 3D-ovikohtaus: kamera, portsari ja valot oven lapsina (_rig), ovilehti, luukun kansi ja lamppu oven omia.
var _rig: Node3D
var _cam: Camera3D
var _zoom := 0.0  # kamera luukulla (0 = oven edessä portailla, 1 = lähellä luukkua)
var _bouncer: Node3D
var _leaf: Node3D
var _cover: Node3D
var _lamp: OmniLight3D
var _lamp_e := 2.0
var _dust: CPUParticles3D
var _open := 0.0  # ovilehti auki (0..1)
var _rattle := 0.0  # ovilehden tärinä koputuksesta
var _flicker := 0.0  # lampun lepatus paukahduksesta
var _talk_t := 0.0

var _root: Control
var _top: Control
var _dark: ColorRect
var _dmat: ShaderMaterial
var _info: Label
var _keys: Control
var _mode := "luukku"
var _t := 0.0
var _shake := 0.0
var _fade := 0.0  # siirtymä mustaan (0..1)

# Luukku
var _hatch := 0.0
var _hatch_to := 0.0
var _eyes := "epaily"
var _bubble := ""
var _knocks: Array = []
var _opts: Array = []
var _sel := 0
var _answered := -1
var _answer_t := 0.0

# Pimeä halli
var me := {"pos": Vector2(1.5, DOOR_Y), "ang": 0.0, "phase": 0.0, "noise": 0.0, "moving": false}
var npcs: Array = []
var nappi := -1  # -1 = pelaaja on rasvanappi, muuten npcs-indeksi
var pokes := 0
var my_pokes := 0
var my_hits := 0
var licks := 0
var _game_t := 0.0
var _puffs: Array = []
var _later: Array = []  # [aika, Callable]
var _pending := {}
var _lick := {}
var _whiff_t := 0.0
var _rustle_t := 0.0
var _hurry_t := 0.0
var _early := false
var _end_lines: Array = []
var _sparks: Array = []
var _npcs_answer: Array = []  # tökätyn vastaus pelaajan arvaukseen [indeksi, teksti]
var _npcs_answer_t := 0.0


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_root)
	add_child(_root)
	_dark = ColorRect.new()
	_dark.anchor_right = 1.0
	_dark.anchor_bottom = 1.0
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 l0; uniform float r0 = 100.0;
uniform vec2 l1; uniform float r1 = 100.0;
uniform vec2 l2; uniform float r2 = 100.0;
uniform float dark = 0.96;
void fragment() {
	vec2 p = UV * rect_size;
	float a = (1.0 - smoothstep(r0 * 0.3, r0, distance(p, l0))) * 0.88;
	float b = (1.0 - smoothstep(0.0, r1, distance(p, l1))) * 0.5;
	float c = (1.0 - smoothstep(0.0, r2, distance(p, l2))) * 0.42;
	float light = clamp(max(a, max(b, c)), 0.0, 1.0);
	vec3 tint = mix(vec3(0.0, 0.005, 0.02), vec3(0.0, 0.07, 0.02), b * 1.6);
	COLOR = vec4(tint, dark * (1.0 - light));
}"""
	_dmat = ShaderMaterial.new()
	_dmat.shader = sh
	_dark.material = _dmat
	_dark.visible = false
	add_child(_dark)
	_top = Control.new()
	_top.anchor_right = 1.0
	_top.anchor_bottom = 1.0
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.draw.connect(_draw_top)
	add_child(_top)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 24)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 8)
	_info.anchor_right = 1.0
	_info.offset_top = 18
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_info)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	var order := range(PASSWORDS.size())
	order.shuffle()
	_opts = order
	for i in people.size():
		npcs.append({"i": i, "pos": Vector2.ZERO, "ang": 0.0, "goal": 0.0, "phase": randf() * TAU, "turn_t": 0.0,
			"pause_t": 0.0, "puff_t": randf_range(1.0, 6.0), "flee_t": 0.0, "flee_from": Vector2.ZERO, "target": -1,
			"hunt_t": 0.0, "butter_t": 0.0, "moving": false})
	var starts := [Vector2(3.0, 2.0), Vector2(6.5, 2.4), Vector2(10.0, 3.6), Vector2(6.0, 4.8), Vector2(3.0, 5.0)]
	for i in npcs.size():
		npcs[i].pos = starts[i]
		npcs[i].ang = randf() * TAU
		npcs[i].goal = npcs[i].ang
	if door != null:
		_setup_door()
		_setup_hall()
	elif anchor != null:
		_setup_hall()
		_mode = "esittely"
		_hall.lineup()
		_hall.set_lit(1.0)
		_hall.line_cam.current = true


# --- Yleiset ---------------------------------------------------------------------------------------------------

func _host() -> String:
	return rules.get("host", "Portsari")


func _kerma() -> bool:
	return rules.get("kerma", false)


## Päivin puhelu pimeässä (rules.call): repliikit vuorotellen, E jatkaa, sitten peli jatkuu.
func _call_step() -> void:
	var lines: Array = rules["call"]
	if _t > 0.5 and (_pressed_ok() or _t > 2.6):
		_call_line += 1
		_t = 0.0
		if _call_line >= lines.size():
			_mode = "pimea"
			_t = 0.0
			_puff(me.pos, "*klik*", Color(0.6, 0.85, 1.0), false, 1.0)


func _draw_call() -> void:
	var s := _size()
	var k := s.y / 720.0
	var lines: Array = rules["call"]
	var r := Rect2(s.x * 0.5 - 170 * k, s.y * 0.5 - 220 * k, 340 * k, 440 * k)
	MG.box(_top, r, Color(0.07, 0.07, 0.08), int(30 * k), int(10 * k), Color(0.35, 0.35, 0.38), int(3 * k))
	var sr := r.grow(-14 * k)
	MG.grad_rect(_top, sr, Color(0.15, 0.3, 0.45), Color(0.05, 0.1, 0.18))
	var font := ThemeDB.fallback_font
	var ring := 1.0 + 0.08 * sin(_t * 18.0) if _call_line == 0 else 1.0
	_top.draw_string(font, sr.position + Vector2(0, 50 * k), "PÄIVI", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(34 * k * ring),
		Color(1.0, 0.85, 0.85))
	_top.draw_string(font, sr.position + Vector2(0, 78 * k), "puhelu 0:%02d" % mini(59, int(_game_t) % 60), HORIZONTAL_ALIGNMENT_CENTER,
		sr.size.x, int(15 * k), Color(0.75, 0.8, 0.9))
	var y := 120.0
	for i in mini(_call_line + 1, lines.size()):
		var l: Array = lines[i]
		var mine: bool = l[0] != "Päivi"
		var br := Rect2(sr.position + Vector2(16 if not mine else 70, y) * k, Vector2(sr.size.x - 86 * k, 62 * k))
		MG.box(_top, br, Color(0.95, 0.95, 0.92) if not mine else Color(0.62, 0.9, 0.6), int(14 * k), 0, MG.OUTLINE, 1)
		_top.draw_string(font, br.position + Vector2(10, 20) * k, l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * k), Color(0.35, 0.3, 0.3))
		_top.draw_string(font, br.position + Vector2(10, 46) * k, l[1], HORIZONTAL_ALIGNMENT_LEFT, br.size.x - 20 * k, int(19 * k),
			Color(0.1, 0.08, 0.06))
		y += 76.0


func _pressed_ok() -> bool:
	return Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")


func _quit_pressed() -> bool:
	return Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE)


## Konttauksen näppäimet ohjeriville: ylös, vasen, alas, oikea (oletuksena [W/A/S/D]).
func _move_keys() -> String:
	return "[%s/%s/%s/%s]" % [Settings.action_key("forward"), Settings.action_key("left"), Settings.action_key("back"),
		Settings.action_key("right")]


func _size() -> Vector2:
	return _root.size if _root.size.x > 10.0 else Vector2(1280, 720)


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 2.5)
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 10.0
	_root.position = off
	match _mode:
		"luukku":
			_luukku_step(delta)
		"esittely":
			_fade = maxf(0.0, _fade - delta * 1.5)
			if _t > 0.8 and _pressed_ok():
				_lights_out()
			elif _quit_pressed():
				_done(false)
				return
		"sammutus":
			if _t > 1.4:
				_mode = "pimea"
				_t = 0.0
				_puff(Vector2(0.6, DOOR_Y - 0.7), "%s: Rasvanappi alkaa. Uusi aloittaa." % _host(), Color(0.85, 0.9, 1.0), true)
		"pimea":
			_dark_step(delta)
		"nimi":
			_name_step()
		"vastaus":
			if not _npcs_answer.is_empty() and _t > _npcs_answer_t:
				_npc_say(_npcs_answer[0], _npcs_answer[1])
				_npcs_answer = []
			if _t > 2.2:
				_mode = "nuolu"
				_t = 0.0
				Sfx.play("water", -14.0, 2.2, 0.6)
		"nuolu":
			if _t > 0.7 and _t < 0.75:
				_shake = 0.25
			if _t > 3.2 or (_t > 1.2 and _pressed_ok()):
				_after_lick()
		"loppu":
			if _t > 1.2 and (_pressed_ok() or _quit_pressed()):
				_done(true)
				return
		"puhelu":
			_call_step()
	for p in _puffs:
		p.t += delta
	for i in range(_puffs.size() - 1, -1, -1):
		if _puffs[i].t > _puffs[i].life:
			_puffs.remove_at(i)
	MG.sparks_step(_sparks, delta)
	if _hall != null and _mode in ["sammutus", "pimea", "nimi", "vastaus", "nuolu", "loppu", "puhelu"]:
		_hall_step(delta)
	_dark.visible = _hall == null and (_mode in ["pimea", "nimi", "vastaus", "nuolu", "loppu", "puhelu"] or (_mode == "sammutus" and _t > 0.35))
	if _dark.visible:
		_update_dark()
	_update_texts()
	_root.queue_redraw()
	_top.queue_redraw()


func _done(got_in: bool) -> void:
	if _mode == "valmis":
		return
	_mode = "valmis"
	finished.emit({"got_in": got_in, "pokes": my_pokes, "hits": my_hits, "licks": licks, "total": pokes, "early": _early,
		"mansikat": strawberries, "puhelu": _call_done})
	queue_free()


func _update_texts() -> void:
	match _mode:
		"luukku":
			_info.text = ""
			if _answered < 0 and _hatch > 0.9 and _t > 2.4:
				_keys.set_text("%s valitse   [%s] sano   %s lähde" % [Settings.pair("forward", "back"), Settings.action_key("interact"),
					Settings.cap("mount")])
			else:
				_keys.set_text("%s lähde" % Settings.cap("mount"))
		"esittely":
			_info.text = "Ennen valojen sammutusta: muista kuka ääntelee miten"
			_keys.set_text("[%s] valot pois   %s lähde" % [Settings.action_key("interact"), Settings.cap("mount")])
		"pimea":
			var left := maxf(0.0, MAX_TIME - _game_t)
			if nappi == -1:
				_info.text = "Olet RASVANAPPI · tökkää jotakuta takaapäin peppuun · tökkäyksiä %d/%d" % [pokes, MAX_POKES]
				_keys.set_text("%s konttaa   %s ripeästi (kolisee)   [%s] tökkää   %s lopeta" % [_move_keys(),
					Settings.cap("sprint"), Settings.action_key("interact"), Settings.cap("mount")])
			else:
				_info.text = "Rasvanappi liikkuu pimeässä · älä anna takapuolta · %d:%02d" % [int(left) / 60, int(left) % 60]
				_keys.set_text("%s konttaa   %s ripeästi (kolisee)   %s lopeta" % [_move_keys(),
					Settings.cap("sprint"), Settings.cap("mount")])
		"nimi":
			_info.text = "Tökkäsit! Kuka se oli?"
			_keys.set_text("%s valitse   [%s] huuda   [1–5] suoraan" % [Settings.pair("forward", "back"), Settings.action_key("interact")])
		"vastaus", "nuolu", "sammutus":
			_info.text = ""
			_keys.set_text("")
		"puhelu":
			_info.text = "Puhelin soi pimeässä!"
			_keys.set_text("[%s] jatka" % Settings.action_key("interact"))
		"loppu":
			_info.text = ""
			_keys.set_text("[%s] pukemaan ja ulos" % Settings.action_key("interact"))


# --- 1. Kurkistusluukku ------------------------------------------------------------------------------------------

func _luukku_step(delta: float) -> void:
	var slam: bool = _answered >= 0 and not PASSWORDS[_answered][1] and _hatch_to == 0.0
	_hatch = move_toward(_hatch, _hatch_to, delta * (14.0 if slam else 3.0))
	_door_step(delta)
	for k in [0.15, 0.42, 0.69]:
		if _t - delta < k and _t >= k:
			Sfx.play("punch", -6.0, 0.6)
			_shake = 0.35
			_rattle = 1.0
			_knocks.append([_t, Vector2(randf_range(-40, 40), randf_range(-30, 30))])
			if k > 0.6:
				_puff_dust()
	if _t - delta < 1.5 and _t >= 1.5:
		_hatch_to = 1.0
		Sfx.play("rattle", -6.0, 0.7)
	if _t - delta < 1.8 and _t >= 1.8:
		_bubble = "Mitä?"
		_talk_t = 0.8
		Sfx.play("grunt", -8.0, 0.6)
	if _t - delta < 2.4 and _t >= 2.4:
		_bubble = "Salasana."
		_talk_t = 0.8
	if _answered < 0:
		if _quit_pressed():
			_done(false)
			return
		if _t < 2.4:
			return
		if Input.is_action_just_pressed("forward") or Input.is_action_just_pressed("left"):
			_sel = (_sel + _opts.size() - 1) % _opts.size()
			Sfx.play("pickup", -16.0, 1.6)
		if Input.is_action_just_pressed("back") or Input.is_action_just_pressed("right"):
			_sel = (_sel + 1) % _opts.size()
			Sfx.play("pickup", -16.0, 1.6)
		for k in _opts.size():
			if Input.is_key_pressed(KEY_1 + k):
				_sel = k
				_answer()
				return
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
			_answer()
		return
	var a := _t - _answer_t
	var pw: Array = PASSWORDS[_answered]
	if pw[1]:
		if a > 1.9 and a - delta <= 1.9:
			_hatch_to = 0.0
			_bubble = ""
			Sfx.play("rattle", -5.0, 0.7)
		if a > 2.4 and a - delta <= 2.4:
			Sfx.play("rattle_hard", -4.0, 0.8)
		if a > 2.9 and a - delta <= 2.9:
			Sfx.play("door", -2.0, 0.8)
		if a > 2.9:
			_open = minf(1.0, (a - 2.9) / 1.1)
		if a > 3.3 and a - delta <= 3.3:
			_bubble = "Sisään."
			_talk_t = 0.8
		if a > 4.0:
			_fade = minf(1.0, (a - 4.0) * 1.6)
		if a > 4.8:
			_mode = "esittely"
			_t = 0.0
			if _hall != null:
				_hall.lineup()
				_hall.set_lit(1.0)
				_hall.line_cam.current = true
			Sfx.play("door_close", -4.0)
	else:
		if a > 2.2 and a - delta <= 2.2:
			_hatch_to = 0.0
			_bubble = ""
			Sfx.play("punch_heavy", -2.0, 0.7)
			_shake = 1.0
			_rattle = 1.0
			_flicker = 1.0
			_puff_dust()
		if a > 3.6:
			_done(false)


func _answer() -> void:
	_answered = _opts[_sel]
	_answer_t = _t
	var pw: Array = PASSWORDS[_answered]
	_bubble = pw[2]
	_eyes = pw[3]
	_talk_t = 1.6
	Sfx.play("grunt", -6.0, 0.6 if pw[1] else 0.5)


# --- 1b. Ovi 3D:nä -------------------------------------------------------------------------------------------------

## Kamera oven eteen portaiden yläpäähän, portsari eteiskomeroon silmät luukun korkeudelle, valot komeroon ja
## pölypilvi karmin yläreunaan. Kaikki oven paikallisessa kehyksessä (+Z ulos).
func _setup_door() -> void:
	_leaf = door.get_node("Ovi")
	_cover = door.get_node("Ovi/Luukku")
	_lamp = door.get_node("Lamppu")
	_lamp_e = _lamp.light_energy
	_rig = Node3D.new()
	door.add_child(_rig)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.near = 0.03
	_rig.add_child(_cam)
	_cam.current = true
	_bouncer = Looks.make(_rig, BOUNCER)
	_bouncer.rotation.y = PI  # kasvot ulos (+Z)
	var head: Vector3 = _bouncer.bone_position("Head")
	_bouncer.position = Vector3(0, Makasiini.HATCH_Y - head.y - 0.075, -0.25)
	_bouncer.play("Idle")
	# Kädet selän takana ristissä oven ollessa kiinni (animaation heilunta ei tuo niitä ovilehden läpi); ovi auki =
	# vapaat kädet (_door_step).
	var hip: Vector3 = _bouncer.bone_position("pelvis")
	for sd in [1.0, -1.0]:
		var sfx := "_r" if sd > 0.0 else "_l"
		_bouncer.set_ik("arm" + sfx, "upperarm" + sfx, "lowerarm" + sfx, "hand" + sfx, hip + Vector3(sd * 0.05, 0.02, 0.17),
			hip + Vector3(sd * 0.45, 0.25, 0.3))
	var fill := OmniLight3D.new()  # komeron hehkulamppu kasvojen edessä: näkyy vain luukusta
	fill.light_color = Color(1.0, 0.9, 0.78)
	fill.light_energy = 0.7
	fill.omni_range = 0.7
	fill.position = Vector3(0.06, Makasiini.HATCH_Y + 0.12, -0.03)
	_rig.add_child(fill)
	var hall := OmniLight3D.new()  # hallin valo komeron perällä: näkyy, kun ovi aukeaa
	hall.light_color = Color(1.0, 0.72, 0.45)
	hall.light_energy = 0.7
	hall.omni_range = 1.8
	hall.position = Vector3(0.3, 2.0, -0.35)
	_rig.add_child(hall)
	_dust = CPUParticles3D.new()
	_dust.one_shot = true
	_dust.emitting = false
	_dust.amount = 60
	_dust.lifetime = 1.4
	_dust.explosiveness = 0.85
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.55, 0.02, 0.04)
	_dust.direction = Vector3(0, -1, 0.4)
	_dust.spread = 35.0
	_dust.initial_velocity_min = 0.05
	_dust.initial_velocity_max = 0.25
	_dust.gravity = Vector3(0, -0.5, 0)
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.4
	_dust.mesh = B.sphere(0.004, 4)
	_dust.material_override = B.mat(Color(0.55, 0.5, 0.44))
	_dust.position = Vector3(0, Makasiini.HOLE.y - 0.06, 0.1)
	_rig.add_child(_dust)


## Halli rakennetaan heti (hahmojen lataus ei nyki valojen sammuessa), kauas makasiinin yläpuolelle.
func _setup_hall() -> void:
	var looks: Array = []
	for p: Dictionary in people:
		var lk: Dictionary = p.look
		var woman: bool = p.get("woman", false)
		var look := {"model": "female" if woman else "male", "skin": lk.skin,
			"hair": HAIRS[lk.hair], "hair_color": lk.hair_col, "beard": lk.get("beard", false), "height": 1.64 if woman else 1.76,
			"bulk": (p.bulk - 1.0) * 2.0, "belly": 0.6 if p.bulk > 1.1 else 0.25, "muscle": -0.9}
		for key in ["bust", "curves", "curls", "long_hair"]:  # erikoissääntöjen pelaajien muodot ja hiukset (kolmiomittaus.gd)
			if lk.has(key):
				look[key] = lk[key]
		looks.append({"towel": p.towel, "woman": woman, "look": look})
	looks.append({"towel": Color(0.95, 0.95, 0.92), "woman": false, "look": {"skin": Color(0.98, 0.8, 0.7),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.22, 0.15, 0.1), "belly": 0.75, "bulk": 0.1, "height": 1.8}})
	_hall = Hall.new()
	_hall.room = ROOM
	_hall.door_y = DOOR_Y
	_hall.style = rules.get("style", {})
	var at: Node3D = door if door != null else anchor
	at.get_parent().add_child(_hall)
	_hall.top_level = true
	_hall.global_transform = Transform3D(Basis(), at.global_position + Vector3(0, 250, 0))
	_hall.build(OBST, looks, {} if rules.has("host") else BOUNCER, sun)
	if _kerma():
		for c in _hall.crawlers:
			c.set_cream()


## Konttaajat, valot ja tökkäysten liike joka ruutu (hallin tiloissa).
func _hall_step(delta: float) -> void:
	var lit := 0.0
	match _mode:
		"sammutus":
			lit = 1.0 if _t < 0.35 else 0.0
		"loppu":
			lit = minf(0.75, _t * 0.9)
	_hall.set_lit(lit)
	_hall.set_sight(me.pos, LIGHT_R)
	var dark := lit < 0.5
	if dark != _disguised:
		_disguised = dark
		for c in _hall.crawlers:
			c.disguise(dark)
	if not _poke_anim.is_empty():
		_poke_anim.t += delta
		if _poke_anim.t > 1.2:
			_poke_anim = {}
	for i in npcs.size() + 1:
		var who: Dictionary = me if i == npcs.size() else npcs[i]
		var idx := -1 if i == npcs.size() else i
		var c: Node3D = _hall.crawlers[i]
		var pt: float = _poke_anim.get("t", 9.0)
		c.reach = sin(clampf(pt / 0.6, 0.0, 1.0) * PI) if _poke_anim.get("who", -2) == idx else 0.0
		c.jolt = clampf((pt - 0.15) / 0.45, 0.0, 1.0) if _poke_anim.get("poked", -2) == idx and pt > 0.15 else 0.0
		c.set_butter(nappi == idx and (idx == -1 or npcs[idx].butter_t <= 0.0))
		_hall.place(i, who.pos, who.ang, who.phase, who.moving)


func _exit_tree() -> void:
	if _hall != null and is_instance_valid(_hall):
		_hall.queue_free()
	if door == null or not is_instance_valid(door):
		return
	_leaf.rotation.y = 0.0
	_cover.position.x = -0.5
	_lamp.light_energy = _lamp_e
	_rig.queue_free()


func _puff_dust() -> void:
	if _dust != null:
		_dust.restart()


## Ovikohtauksen liike joka ruutu: luukun kansi, ovilehden tärinä ja aukeaminen, kameran tärähdys ja humalan huojunta,
## lampun lepatus ja portsarin pään liikkeet mielialan mukaan (_eyes).
func _door_step(delta: float) -> void:
	if door == null:
		return
	_rattle = maxf(0.0, _rattle - delta * 4.0)
	_flicker = maxf(0.0, _flicker - delta * 1.5)
	_talk_t = maxf(0.0, _talk_t - delta)
	var e := _hatch * _hatch * (3.0 - 2.0 * _hatch)
	_cover.position.x = -0.5 + e * Makasiini.HATCH_TRAVEL
	var o := _open * _open * (3.0 - 2.0 * _open)
	if _open > 0.0:
		_bouncer.clear_ik()
	_leaf.rotation.y = o * 1.75 + sin(_t * 70.0) * 0.006 * _rattle
	# Kamera: koputus portailta, luukun auettua lähelle kasvoja, oven auetessa taas taakse.
	var want := 1.0 if _hatch > 0.5 and _open == 0.0 else 0.0
	_zoom = move_toward(_zoom, want, delta * 1.3)
	var z := _zoom * _zoom * (3.0 - 2.0 * _zoom)
	var eye := Vector3(-0.3, 1.62, 2.6).lerp(Vector3(-0.07, 1.66, 1.0), z)
	var look := Vector3(0.0, 1.58, 0).lerp(Vector3(0.0, 1.62, 0), z)
	var sway := Vector3(sin(_t * 0.7), sin(_t * 1.1) * 0.5, 0) * drunk * 0.04
	var jolt := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.012
	_cam.transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye).translated_local(sway + jolt + Vector3(0, 0, o * 0.3))
	var buzz := 0.92 + 0.08 * sin(_t * 23.0) * sin(_t * 3.7)
	if _flicker > 0.0 and fmod(_t * 17.0, 1.0) < _flicker:
		buzz = 0.15
	_lamp.light_energy = _lamp_e * buzz
	# Portsari: nojaa luukulle, vilkuilee, tuijottaa, säikähtää tai nyökkää.
	var b: Node = _bouncer
	b.play("Idle_Talking" if _talk_t > 0.0 else "Idle", 0.3)
	var lean := -0.12
	var yaw := 0.0
	var nod := 0.0
	match _eyes:
		"epaily":
			yaw = sin(_t * 0.9) * 0.3
			nod = 0.05
		"viha":
			lean = -0.17
			nod = 0.14
			yaw = sin(_t * 2.3) * 0.04
		"pelko":
			lean = 0.18
			yaw = sin(_t * 9.0) * 0.28
		"ok":
			nod = 0.18 * maxf(0.0, sin((_t - _answer_t) * 7.0)) if _t - _answer_t < 1.4 else 0.0
	b.set_override("spine_01", Vector3.RIGHT, lean * 0.5)
	b.set_override("spine_03", Vector3.RIGHT, lean * 0.5)
	b.set_override("neck_01", Vector3.RIGHT, nod)
	b.set_override("Head", Vector3.UP, yaw)


## Luukun aukko ruudulla (puhekuplan ja valikon paikka); ilman ovea ruudun keskeltä.
func _hatch_rect() -> Rect2:
	var s := _size()
	if door == null or _cam == null:
		return Rect2(s.x * 0.42, s.y * 0.3, s.x * 0.16, s.y * 0.08)
	var hw := Makasiini.HATCH.x / 2.0
	var hh := Makasiini.HATCH.y / 2.0
	var a := _cam.unproject_position(door.to_global(Vector3(-hw, Makasiini.HATCH_Y + hh, 0.06)))
	var c := _cam.unproject_position(door.to_global(Vector3(hw, Makasiini.HATCH_Y - hh, 0.06)))
	return Rect2(a, c - a).abs()


# --- 2. Esittely ja valot pois ---------------------------------------------------------------------------------

func _lights_out() -> void:
	_mode = "sammutus"
	_t = 0.0
	if _hall != null:
		_hall.crawl_start()
		_hall.cam.current = true
	Sfx.play("rattle", -2.0, 2.2)  # katkaisijan naksahdus
	_shake = 0.2


# --- 3. Pimeä halli ----------------------------------------------------------------------------------------------

func _fwd(a: float) -> Vector2:
	return Vector2(cos(a), sin(a))


func _hand(pos: Vector2, ang: float) -> Vector2:
	return pos + _fwd(ang) * 0.55


func _butt(pos: Vector2, ang: float) -> Vector2:
	return pos - _fwd(ang) * 0.35


func _blocked(p: Vector2, r := 0.28) -> bool:
	if p.x < r + 0.15 or p.y < r + 0.15 or p.x > ROOM.x - r - 0.15 or p.y > ROOM.y - r - 0.15:
		return true
	for o: Rect2 in OBST:
		if o.grow(r).has_point(p):
			return true
	return false


## Siirto törmäyksineen (akseleittain, jotta seinää pitkin liukuu). Palauttaa true, jos jokin esti.
func _move(who: Dictionary, step: Vector2, self_i: int) -> bool:
	var hit := false
	for axis in [Vector2(step.x, 0), Vector2(0, step.y)]:
		var np: Vector2 = who.pos + axis
		var crowd := false
		for j in npcs.size():
			if j != self_i and npcs[j].pos.distance_to(np) < 0.55 and npcs[j].pos.distance_to(np) < npcs[j].pos.distance_to(who.pos):
				crowd = true
		if self_i != -1 and me.pos.distance_to(np) < 0.55 and me.pos.distance_to(np) < me.pos.distance_to(who.pos):
			crowd = true
		if _blocked(np) or crowd:
			hit = true
		else:
			who.pos = np
	return hit


func _dark_step(delta: float) -> void:
	_game_t += delta
	if rules.has("call") and not _call_done and _game_t > 45.0 and _pending.is_empty():
		_call_done = true
		_call_line = 0
		_mode = "puhelu"
		_t = 0.0
		Sfx.play("bell", -6.0, 2.6)
		for n in npcs:
			n.moving = false
		_puff(me.pos, "*piip piip*", Color(0.6, 0.85, 1.0), true, 1.5)
		return
	for i in range(_later.size() - 1, -1, -1):
		_later[i][0] -= delta
		if _later[i][0] <= 0.0:
			var f: Callable = _later[i][1]
			_later.remove_at(i)
			f.call()
			if _mode != "pimea":
				return
	if _quit_pressed():
		_early = true
		_end()
		return
	if _game_t > MAX_TIME and _pending.is_empty():
		_end()
		return
	# Pelaajan konttaus.
	var dir := Input.get_vector("left", "right", "forward", "back")
	var hurry := Input.is_action_pressed("sprint")
	me.moving = dir.length() > 0.1
	if me.moving:
		var spd := (HURRY if hurry else CRAWL) * (1.0 - drunk * 0.25)
		# Vartalo kääntyy heti liikesuuntaan, ettei hahmo kontaa takaperin tai sivuttain kääntyessään.
		var turn := angle_difference(me.ang, dir.angle())
		me.ang = dir.angle() if absf(turn) > PI * 0.4 else me.ang + turn * (1.0 - exp(-25.0 * delta))
		_move(me, dir.normalized() * spd * delta, -1)
		me.phase += delta * spd * 9.0
	if me.moving and hurry:
		me.noise = minf(1.0, me.noise + delta * 0.7)
		_hurry_t -= delta
		if _hurry_t <= 0.0:
			_hurry_t = 0.45
			Sfx.play("step_wood", -10.0, 0.8)
			_puff(me.pos, "", Color(0.8, 0.8, 0.8), false, 0.6)
			for n in npcs:
				if n.pos.distance_to(me.pos) < 2.6 and npcs.find(n) != nappi:
					n.flee_t = 1.4
					n.flee_from = me.pos
	else:
		me.noise = maxf(0.0, me.noise - delta * 0.12)
	_whiff_t = maxf(0.0, _whiff_t - delta)
	for i in npcs.size():
		_npc_step(i, delta)
	if not _pending.is_empty() or _mode != "pimea":
		return
	if nappi == -1 and _pressed_ok() and _whiff_t <= 0.0:
		var hit := _poke_target()
		if hit >= 0:
			var n: Dictionary = npcs[hit]
			if _fwd(n.ang).dot((me.pos - n.pos).normalized()) < -0.15:
				_begin_poke(-1, hit)
			else:
				# Edestä tökkäys ei käy: tökätty kääntyy ja konttaa karkuun.
				_whiff_t = 0.8
				n.flee_t = 1.6
				n.flee_from = me.pos
				Sfx.play("grunt", -6.0, people[hit].snd[1] * 1.2)
				_puff(n.pos, ["Hei! Väärä pää!", "Ei sieltä!", "Takaa, takaa!"].pick_random(), Color(0.9, 0.9, 0.9))
		else:
			_whiff_t = 0.6
			Sfx.play("whoosh", -14.0, 1.4)
			_puff(_hand(me.pos, me.ang), "tyhjää…", Color(0.7, 0.7, 0.7), false, 0.8)


func _poke_target() -> int:
	var best := -1
	var bd := REACH
	var h := _hand(me.pos, me.ang)
	for i in npcs.size():
		var d: float = h.distance_to(_butt(npcs[i].pos, npcs[i].ang))
		if d < bd:
			bd = d
			best = i
	return best


func _npc_step(i: int, delta: float) -> void:
	var n: Dictionary = npcs[i]
	var person: Dictionary = people[i]
	n.puff_t -= delta
	if n.puff_t <= 0.0:
		n.puff_t = randf_range(4.5, 9.0)
		_npc_say(i, person.tics.pick_random())
	var spd := NPC_CRAWL
	n.moving = true
	if n.flee_t > 0.0:
		n.flee_t -= delta
		n.goal = (n.pos - n.flee_from).angle()
		spd = 1.0
	elif i == nappi:
		n.butter_t -= delta
		if n.butter_t > 0.0:
			# Uutta margariinia ovensuun jakkaralta.
			var to: Vector2 = Vector2(1.25, 4.7) - n.pos
			if to.length() < 0.4:
				n.moving = false
				spd = 0.0
			else:
				n.goal = to.angle()
				spd = HUNT_SPEED
		else:
			n.hunt_t -= delta
			if n.hunt_t <= 0.0:
				_pick_target(i, n.target)
			var tp: Vector2 = me.pos if n.target == -1 else npcs[n.target].pos
			var ta: float = me.ang if n.target == -1 else npcs[n.target].ang
			var tb := _butt(tp, ta)
			var behind := tp - _fwd(ta) * 0.95
			var go := behind if n.pos.distance_to(behind) > 0.35 and _hand(n.pos, n.ang).distance_to(tb) > 0.6 else tb - _fwd(n.ang) * 0.5
			n.goal = (go - n.pos).angle()
			spd = HUNT_SPEED
			if _hand(n.pos, n.ang).distance_to(tb) < REACH and _pending.is_empty() and _mode == "pimea":
				_begin_poke(i, n.target)
				return
			# Jahtaaja kahisee, kun se on lähellä.
			if n.target == -1 and n.pos.distance_to(me.pos) < 3.2:
				_rustle_t -= delta
				if _rustle_t <= 0.0:
					_rustle_t = 0.7
					Sfx.play("cloth", -16.0 + (3.2 - n.pos.distance_to(me.pos)) * 3.0, 1.3)
					_puff(n.pos, "", Color(1.0, 0.85, 0.4), false, 0.7)
	else:
		n.pause_t -= delta
		if n.pause_t > 0.0:
			n.moving = false
			spd = 0.0
		n.turn_t -= delta
		if n.turn_t <= 0.0:
			n.turn_t = randf_range(1.0, 3.2)
			n.goal = n.ang + randf_range(-1.5, 1.5)
			if randf() < 0.2:
				n.pause_t = randf_range(0.8, 2.0)
	n.ang = lerp_angle(n.ang, n.goal, 1.0 - exp(-4.0 * delta))
	if spd > 0.0:
		if _move(n, _fwd(n.ang) * spd * delta, i):
			n.goal = n.ang + randf_range(1.2, 2.4) * (1.0 if randf() < 0.5 else -1.0)
			n.turn_t = randf_range(0.6, 1.5)
		n.phase += delta * spd * 9.0


func _pick_target(i: int, avoid: int) -> void:
	var n: Dictionary = npcs[i]
	n.hunt_t = randf_range(18.0, 28.0)
	var pool := [-1, -1]  # pelaaja on kiinnostavin kohde
	for j in npcs.size():
		if j != i and j != avoid:
			pool.append(j)
	if avoid == -1:
		pool.erase(-1)
		pool.erase(-1)
	n.target = pool.pick_random()


func _npc_say(i: int, text: String, big := false) -> void:
	var person: Dictionary = people[i]
	var d: float = npcs[i].pos.distance_to(me.pos)
	Sfx.play(person.snd[0], -8.0 - d * 1.6, person.snd[1] * randf_range(0.95, 1.05))
	_puff(npcs[i].pos, text, Color(0.95, 0.92, 0.85), big)


func _puff(pos: Vector2, text: String, col: Color, big := false, life := 2.4) -> void:
	_puffs.append({"pos": pos, "text": text, "col": col, "big": big, "t": 0.0, "life": life})


func _name_of(i: int) -> String:
	return ME_NAME if i == -1 else people[i].name


func _begin_poke(poker: int, poked: int) -> void:
	_pending = {"poker": poker, "poked": poked}
	_poke_anim = {"who": poker, "poked": poked, "t": 0.0}
	pokes += 1
	_shake = 0.7
	var bp: Vector2 = _butt(me.pos, me.ang) if poked == -1 else _butt(npcs[poked].pos, npcs[poked].ang)
	MG.sparks_burst(_sparks, _w2s(bp), Color(1.0, 0.9, 0.4), 12)
	Sfx.play("punch", -4.0, 1.5)
	_puff(bp, "TÖK!", Color(1.0, 0.9, 0.35), true, 1.2)
	if poked >= 0:
		Sfx.play(people[poked].snd[0], -4.0, people[poked].snd[1] * 1.3)
		npcs[poked].flee_t = 0.0
	if poker == -1:
		my_pokes += 1
		_mode = "nimi"
		_sel = 0
		return
	# Muu nappi arvaa: pelaajan kolinasta tunnistaa helpommin.
	var right: bool
	if poked == -1:
		right = randf() < 0.3 + me.noise * 0.55
	else:
		right = randf() < 0.5
	var guess := _name_of(poked)
	if not right:
		var others := [-1]
		for j in npcs.size():
			if j != poker and j != poked:
				others.append(j)
		others.erase(poked)
		guess = _name_of(others.pick_random())
	_pending.guess = guess
	_pending.right = guess == _name_of(poked)
	_npc_say(poker, "Rasvanappi, %s!" % guess, true)
	if poked == -1:
		_mode = "vastaus"
		_t = 0.0
		_puff(me.pos + Vector2(0, -0.4), "Osui…" if _pending.right else "Ei osunut!", Color(0.7, 0.95, 1.0), true)
		_lick = {"kind": "me_other" if _pending.right else "other_self", "who": poker}
		if _pending.right:
			licks += 1
	else:
		var answer: String = "…osui." if _pending.right else "Väärin! Mää oon %s." % people[poked].name
		_later.append([1.4, func() -> void: _npc_say(poked, answer)])
		var licker: int = poked if _pending.right else poker
		_later.append([2.8, func() -> void:
			_puff(npcs[licker].pos, "*NUOL*", Color(1.0, 0.75, 0.8), true, 1.6)
			Sfx.play("water", -14.0 - npcs[licker].pos.distance_to(me.pos), 2.2, 0.5)
			_new_nappi(licker, poker if licker == poked else poked)])


## Nimen valinta tökkäyksen jälkeen (pelaaja on nappi).
func _name_step() -> void:
	var n := people.size()
	if Input.is_action_just_pressed("forward") or Input.is_action_just_pressed("left"):
		_sel = (_sel + n - 1) % n
		Sfx.play("pickup", -16.0, 1.6)
	if Input.is_action_just_pressed("back") or Input.is_action_just_pressed("right"):
		_sel = (_sel + 1) % n
		Sfx.play("pickup", -16.0, 1.6)
	var pick := -1
	for k in n:
		if Input.is_key_pressed(KEY_1 + k):
			pick = k
	if _pressed_ok():
		pick = _sel
	if pick >= 0:
		_name_pick(pick)


func _name_pick(pick: int) -> void:
	var poked: int = _pending.poked
	_pending.guess = people[pick].name
	_pending.right = pick == poked
	_puff(me.pos + Vector2(0, -0.45), "Rasvanappi, %s!" % people[pick].name, Color(1.0, 0.95, 0.6), true)
	Sfx.play("grunt", -4.0, 1.0)
	_mode = "vastaus"
	_t = 0.0
	if _pending.right:
		my_hits += 1
		_lick = {"kind": "other_me", "who": poked}
		if rules.get("mansikka", false):
			strawberries += 1
			_puff(me.pos + Vector2(0, -0.9), "+ mansikka!", Color(1.0, 0.45, 0.5), true, 2.0)
			Sfx.play("pickup", -6.0, 1.4)
	else:
		licks += 1
		_lick = {"kind": "me_self", "who": poked}
	var answer: String = "…osui." if _pending.right else "Väärin! Mää oon %s." % people[poked].name
	_npcs_answer_t = 0.8
	_npcs_answer = [poked, answer]


func _after_lick() -> void:
	var poker: int = _pending.poker
	var poked: int = _pending.poked
	var right: bool = _pending.right
	_pending = {}
	_lick = {}
	_mode = "pimea"
	_t = 0.0
	var licker := poked if right else poker
	_new_nappi(licker, poker if licker == poked else poked)


func _new_nappi(who: int, partner: int) -> void:
	nappi = who
	if pokes >= MAX_POKES:
		_later.append([1.8, _end])
		_pending = {}
		return
	if who == -1:
		_puff(Vector2(0.7, DOOR_Y - 0.7), "%s: %s" % [_host(), "Kermavaahtoa sormeen. Pssshh." if _kerma() else "Uutta margariinia. Sormi tänne."],
			Color(0.85, 0.9, 1.0), true, 3.0)
		Sfx.play("cloth", -8.0, 0.8)
	else:
		npcs[who].butter_t = 4.0
		_pick_target(who, partner)
		_puff(Vector2(0.7, DOOR_Y - 0.7), "%s: Uusi nappi, %s!" % [_host(), "lisää kermaa" if _kerma() else "uutta rasvaa"],
			Color(0.85, 0.9, 1.0), true, 2.6)
	_pending = {}


func _end() -> void:
	if _mode == "loppu":
		return
	_mode = "loppu"
	_t = 0.0
	Sfx.play("rattle", -2.0, 2.2)
	var lines: Array = rules.get("end_lines", ["Joku löytää valokatkaisijan. Kaikki jähmettyvät.", "Kukaan ei katso ketään silmiin."])
	if _early:
		lines = ["Konttaat ovelle ja haet vaatteet penkiltä.", "Pimeästä kuuluu: \"Hihii, joko lähdet?\""]
	_end_lines = lines


# --- Piirto --------------------------------------------------------------------------------------------------

var _ppm := 90.0
var _org := Vector2.ZERO


func _layout() -> void:
	if _hall != null:
		_ppm = _hall.ppm()
		return
	var s := _size()
	_ppm = minf((s.x - 60.0) / ROOM.x, (s.y - 130.0) / ROOM.y)
	_org = Vector2((s.x - ROOM.x * _ppm) / 2.0, 62.0 + (s.y - 130.0 - ROOM.y * _ppm) / 2.0)


func _w2s(p: Vector2) -> Vector2:
	if _hall != null:
		return _hall.w2s(p)
	return _org + p * _ppm


func _update_dark() -> void:
	_layout()
	_dmat.set_shader_parameter("rect_size", _size())
	_dmat.set_shader_parameter("l0", _w2s(me.pos) + _root.position)
	_dmat.set_shader_parameter("r0", LIGHT_R * _ppm)
	_dmat.set_shader_parameter("l1", _w2s(Vector2(0.3, DOOR_Y - 0.75)) + _root.position)
	_dmat.set_shader_parameter("r1", 1.5 * _ppm)
	_dmat.set_shader_parameter("l2", _w2s(Vector2(0.2, DOOR_Y)) + _root.position)
	_dmat.set_shader_parameter("r2", 0.9 * _ppm)
	var d := 0.965
	if _mode == "sammutus":
		d = minf(0.965, (_t - 0.35) * 3.0)
	elif _mode == "loppu":
		d = maxf(0.6, 0.965 - _t * 0.8)
	_dmat.set_shader_parameter("dark", d)


func _draw_root() -> void:
	match _mode:
		"luukku":
			if door == null:
				_root.draw_rect(Rect2(Vector2(-20, -20), _size() + Vector2(40, 40)), Color(0.05, 0.03, 0.03))
		"esittely":
			if _hall == null:
				_draw_lineup()
		"sammutus":
			if _t < 0.35 and _hall == null:
				_draw_lineup()
			else:
				_draw_hall()
		_:
			_draw_hall()


func _draw_top() -> void:
	var s := _size()
	if _mode == "luukku":
		_draw_door_ui()
		if _fade > 0.0:
			_top.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, _fade))
		return
	if _mode == "esittely":
		var k := s.y / 720.0
		var pc := Vector2(s.x * 0.91, s.y * 0.47)
		if _hall != null:
			_draw_lineup_tags()
		else:
			_hand_draw(_top, pc + Vector2(-70, 210) * k, 0.55 * k, -0.25, Color(0.92, 0.72, 0.6), minf(1.0, _t * 0.8))
		var oil := "%s suihkauttaa kermavaahtoa sormeesi: aloitat napin." % _host() if _kerma() else "Portsari voitelee sormesi: aloitat napin."
		_top.draw_string_outline(ThemeDB.fallback_font, Vector2(s.x * 0.74, s.y * 0.93), oil,
			HORIZONTAL_ALIGNMENT_CENTER, s.x * 0.25, int(16 * k), 5, Color.BLACK)
		_top.draw_string(ThemeDB.fallback_font, Vector2(s.x * 0.74, s.y * 0.93), oil,
			HORIZONTAL_ALIGNMENT_CENTER, s.x * 0.25, int(16 * k), Color(1.0, 0.9, 0.5))
		if _fade > 0.0:
			_top.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, _fade))
		return
	if _mode == "sammutus" and _t < 0.35:
		_top.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 0.9, 0.25 * (1.0 - _t / 0.35)))
		return
	_layout()
	_draw_puffs()
	MG.sparks_draw(_top, _sparks)
	if _mode in ["pimea", "nimi", "vastaus"]:
		_draw_finger_hud()
		if nappi == -1 and _mode == "pimea" and _poke_target() >= 0:
			var t := _poke_target()
			var bp := _w2s(_butt(npcs[t].pos, npcs[t].ang))
			var behind: bool = _fwd(npcs[t].ang).dot((me.pos - npcs[t].pos).normalized()) < -0.15
			_top.draw_string(ThemeDB.fallback_font, bp + Vector2(-60, -26), "[%s] TÖKKÄÄ" % Settings.action_key("interact") if behind
				else "väärä pää…", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(1, 0.9, 0.4) if behind else Color(0.7, 0.7, 0.7))
	if _mode == "nimi":
		_draw_name_menu()
	elif _mode == "puhelu":
		_draw_call()
	elif _mode == "nuolu":
		_draw_lick()
	elif _mode == "loppu":
		_draw_end()


# --- Ovikohtaus --------------------------------------------------------------------------------------------------

func _draw_door_ui() -> void:
	var s := _size()
	var k := s.y / 720.0
	var hr := _hatch_rect()
	var gf := ThemeDB.fallback_font
	for kn in _knocks:  # koputukset oven keskeltä
		var age: float = _t - kn[0]
		if age < 0.6 and door != null:
			var dc := _cam.unproject_position(door.to_global(Vector3(-0.15, 1.25, 0.1)))
			_top.draw_string_outline(gf, dc + kn[1] * k + Vector2(-40, -age * 40) * k, "KOP", HORIZONTAL_ALIGNMENT_CENTER, 80 * k,
				int(38 * k), 8, Color(0, 0, 0, 1.0 - age / 0.6))
			_top.draw_string(gf, dc + kn[1] * k + Vector2(-40, -age * 40) * k, "KOP", HORIZONTAL_ALIGNMENT_CENTER, 80 * k, int(38 * k),
				Color(1, 0.95, 0.85, 1.0 - age / 0.6))
	if _bubble != "" and (_hatch > 0.5 or _open > 0.3):
		var w := clampf(ThemeDB.fallback_font.get_string_size(_bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * k)).x + 40 * k, 160 * k, 560 * k)
		var r := Rect2(hr.end.x + 30 * k, hr.position.y - 90 * k, w, 60 * k)
		if r.end.x > s.x - 10:
			r.position.x = s.x - 10 - w
		MG.bubble(_top, r, Vector2(hr.end.x - 10 * k, hr.get_center().y), _bubble, int(24 * k))
	if _answered < 0 and _t >= 2.4 and _hatch > 0.9:
		var bw := 360.0 * k
		var x0 := 40.0 * k
		var y0 := s.y - 70.0 * k - _opts.size() * 52.0 * k
		MG.box(_top, Rect2(x0 - 14 * k, y0 - 44 * k, bw + 28 * k, _opts.size() * 52 * k + 54 * k), Color(0.05, 0.04, 0.04, 0.82), 12, 6)
		_top.draw_string(ThemeDB.fallback_font, Vector2(x0, y0 - 14 * k), "Sano luukulle:", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * k), Color(0.9, 0.85, 0.7))
		for i in _opts.size():
			var r := Rect2(x0, y0 + i * 52 * k, bw, 44 * k)
			var on := i == _sel
			MG.box(_top, r, Color(0.95, 0.82, 0.35) if on else Color(0.22, 0.2, 0.18), 8, 0, MG.OUTLINE, 2)
			_top.draw_string(ThemeDB.fallback_font, r.position + Vector2(14 * k, 30 * k), "%d  %s" % [i + 1, PASSWORDS[_opts[i]][0]],
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * k), Color(0.1, 0.08, 0.05) if on else Color(0.92, 0.9, 0.85))


# --- Esittely --------------------------------------------------------------------------------------------------

func _draw_lineup() -> void:
	var ci := _root
	var s := _size()
	var k := s.y / 720.0
	MG.wood(ci, Rect2(Vector2.ZERO, s), Color(0.5, 0.37, 0.25), 52.0 * k, 3, true)
	MG.grad_rect(ci, Rect2(0, s.y * 0.8, s.x, s.y * 0.2), Color(0.22, 0.16, 0.11), Color(0.12, 0.09, 0.06))  # lattia
	# Paljas hehkulamppu johdon päässä.
	var bulb := Vector2(s.x * 0.45, s.y * 0.1)
	ci.draw_line(Vector2(bulb.x, 0), bulb, Color(0.08, 0.08, 0.08), 3.0)
	MG.glow(ci, bulb, 560 * k, Color(1.0, 0.85, 0.5, 0.6))
	MG.ball(ci, bulb + Vector2(0, 10 * k), 13 * k, Color(1.0, 0.95, 0.7), 0.8)
	# Naulakko: koukut ja vaatteet.
	var hy := s.y * 0.2
	ci.draw_rect(Rect2(s.x * 0.04, hy - 8 * k, s.x * 0.92, 14 * k), Color(0.3, 0.2, 0.12))
	var clothes := [Color(0.3, 0.38, 0.2), Color(0.2, 0.3, 0.55), Color(0.75, 0.2, 0.2), Color(0.9, 0.5, 0.65), Color(0.85, 0.82, 0.7),
		Color(0.25, 0.25, 0.3), Color(0.55, 0.15, 0.4)]
	for i in clothes.size():
		var x := s.x * (0.08 + i * 0.13)
		ci.draw_circle(Vector2(x, hy), 5 * k, Color(0.6, 0.6, 0.55))
		var c: Color = clothes[i]
		var cr := Rect2(x - 40 * k, hy + 4 * k, 80 * k, 120 * k)
		MG.box(ci, cr, c, 10, 3, MG.OUTLINE, 2)
		ci.draw_line(Vector2(x, hy + 10 * k), Vector2(x, cr.end.y - 6 * k), c.darkened(0.2), 2.0)
		if i == 0:  # Pekan maastotakki
			for j in 6:
				ci.draw_circle(cr.position + Vector2(fmod(j * 37.0, 70.0) + 6, 18 + j * 17) * k, 9 * k, c.darkened(0.3))
		if i == 2:  # flanellipaita
			for j in 4:
				ci.draw_line(cr.position + Vector2(0, 20 + j * 26) * k, cr.position + Vector2(80, 20 + j * 26) * k, c.darkened(0.35), 3.0)
	# Pelaajat pyyhkeissään.
	var n := people.size()
	for i in n:
		var p: Dictionary = people[i]
		var look: Dictionary = p.look.duplicate()
		look["shirt"] = look.skin
		var x := s.x * (0.1 + i * 0.165)
		var c := Vector2(x, s.y * 0.5)
		var sc: float = 1.25 * k * (1.0 + (p.bulk - 1.0) * 0.3)
		var talk := fmod(_t + i * 0.7, 3.5) < 1.2
		MG.person(ci, c, sc, look, Vector2(sin(_t + i) * 0.6, 0.2), talk)
		var tw: Color = p.towel
		var top := 44.0 if p.get("woman", false) else 74.0
		var tr := Rect2(c + Vector2(-38, top) * sc, Vector2(76, 106 - top) * sc)
		MG.box(ci, tr, tw, int(6 * sc), 0, MG.OUTLINE, 2)
		for j in 3:  # pyyhkeen raidat
			ci.draw_line(Vector2(tr.position.x + 4, tr.position.y + (6 + j * 7) * sc), Vector2(tr.end.x - 4, tr.position.y + (6 + j * 7) * sc),
				tw.darkened(0.2), 2.0 * sc)
		MG.sign(ci, Rect2(c + Vector2(-56, 118) * sc, Vector2(112, 30) * sc), p.name, Color(0.12, 0.1, 0.08), p.col, int(20 * sc), Color(0.75, 0.7, 0.6))
		if talk:
			var tic: String = p.tics[int(_t / 3.5 + i) % p.tics.size()]
			var w := ThemeDB.fallback_font.get_string_size(tic, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k)).x + 26 * k
			MG.bubble(ci, Rect2(c + Vector2(-w / 2.0, -112 * sc), Vector2(w, 40 * k)), c + Vector2(6, -34) * sc, tic, int(18 * k))
		ci.draw_string(ThemeDB.fallback_font, c + Vector2(-60, 172) * sc, "(%s)" % p.desc, HORIZONTAL_ALIGNMENT_CENTER, 120 * sc, int(16 * k),
			Color(0.95, 0.9, 0.8))
	# Portsari ja margariinirasia.
	var pc := Vector2(s.x * 0.91, s.y * 0.47)
	# Hämärä nurkista (lamppu valaisee keskeltä).
	for j in 6:
		var a := 0.05 * j
		ci.draw_rect(Rect2(0, 0, s.x * (0.03 * (6 - j)), s.y), Color(0, 0, 0, a))
		ci.draw_rect(Rect2(s.x - s.x * (0.03 * (6 - j)), 0, s.x * (0.03 * (6 - j)), s.y), Color(0, 0, 0, a))
	MG.person(ci, pc, 1.45 * k, {"shirt": Color(0.08, 0.08, 0.09), "hair": "short", "hair_col": Color(0.1, 0.08, 0.06),
		"skin": Color(0.85, 0.65, 0.55)}, Vector2(-0.8, 0.3), fmod(_t, 4.0) < 1.0)
	_tub(ci, pc + Vector2(-70, 90) * k, k)
	ci.draw_string(ThemeDB.fallback_font, pc + Vector2(-80, 180) * k, "Portsari", HORIZONTAL_ALIGNMENT_CENTER, 160 * k, int(18 * k), Color(0.8, 0.85, 1.0))


## 3D-esittelyn nimikyltit, tunnusmerkit ja repliikit hahmojen kohdalle (rasvanappi_hall.gd lineup).
func _draw_lineup_tags() -> void:
	var k := _size().y / 720.0
	var cam: Camera3D = _hall.line_cam
	var font := ThemeDB.fallback_font
	for i in people.size():
		var p: Dictionary = people[i]
		var c: Node3D = _hall.crawlers[i]
		var feet := cam.unproject_position(c.global_position + Vector3(0, -0.05, 0.3))
		var head := cam.unproject_position(c.global_position + Vector3(0, 1.95, 0))
		var w := 112.0 * k
		MG.sign(_top, Rect2(feet + Vector2(-w / 2.0, 4 * k), Vector2(w, 30 * k)), p.name, Color(0.12, 0.1, 0.08), p.col, int(20 * k),
			Color(0.75, 0.7, 0.6))
		_top.draw_string_outline(font, feet + Vector2(-w, 54 * k), "(%s)" % p.desc, HORIZONTAL_ALIGNMENT_CENTER, w * 2.0, int(17 * k), 6,
			Color.BLACK)
		_top.draw_string(font, feet + Vector2(-w, 54 * k), "(%s)" % p.desc, HORIZONTAL_ALIGNMENT_CENTER, w * 2.0, int(17 * k),
			Color(0.98, 0.92, 0.8))
		if fmod(_t + i * 0.7, 3.5) < 1.2:
			var tic: String = p.tics[int(_t / 3.5 + i) % p.tics.size()]
			var tw := font.get_string_size(tic, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k)).x + 26 * k
			MG.bubble(_top, Rect2(head + Vector2(-tw / 2.0, -46 * k), Vector2(tw, 40 * k)), head + Vector2(0, 6 * k), tic, int(18 * k))


func _tub(ci: CanvasItem, c: Vector2, k: float) -> void:
	var r := Rect2(c - Vector2(42, 26) * k, Vector2(84, 52) * k)
	MG.box(ci, r, Color(0.98, 0.85, 0.2), int(10 * k), 3, MG.OUTLINE, 2)
	MG.box(ci, Rect2(r.position - Vector2(4, 8) * k, Vector2(r.size.x + 8 * k, 14 * k)), Color(0.95, 0.92, 0.8), int(6 * k), 0, MG.OUTLINE, 2)
	ci.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 34 * k), "KERMA" if _kerma() else "MARGARIINI", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(12 * k),
		Color(0.2, 0.45, 0.15))
	ci.draw_circle(r.position + Vector2(r.size.x * 0.5, 12 * k), 6 * k, Color(0.3, 0.6, 0.2))


# --- Halli ylhäältä ------------------------------------------------------------------------------------------------

func _rect_px(r: Rect2) -> Rect2:
	return Rect2(_w2s(r.position), r.size * _ppm)


func _draw_hall() -> void:
	_layout()
	if _hall != null:
		return  # halli on 3D:nä (rasvanappi_hall.gd)
	var ci := _root
	var s := _size()
	ci.draw_rect(Rect2(Vector2(-20, -20), s + Vector2(40, 40)), Color(0.03, 0.03, 0.04))
	var floor_r := _rect_px(Rect2(Vector2.ZERO, ROOM))
	MG.wood(ci, floor_r, Color(0.4, 0.3, 0.21), 0.32 * _ppm, 5, true)
	# Seinät.
	var wt := 0.16 * _ppm
	for r in [Rect2(floor_r.position - Vector2(wt, wt), Vector2(floor_r.size.x + wt * 2, wt)),
			Rect2(Vector2(floor_r.position.x - wt, floor_r.end.y), Vector2(floor_r.size.x + wt * 2, wt)),
			Rect2(Vector2(floor_r.end.x, floor_r.position.y), Vector2(wt, floor_r.size.y))]:
		MG.solid(ci, r, Color(0.32, 0.14, 0.1))
	var dtop := _w2s(Vector2(0, DOOR_Y - 0.45))
	var dbot := _w2s(Vector2(0, DOOR_Y + 0.45))
	MG.solid(ci, Rect2(Vector2(floor_r.position.x - wt, floor_r.position.y), Vector2(wt, dtop.y - floor_r.position.y)), Color(0.32, 0.14, 0.1))
	MG.solid(ci, Rect2(Vector2(floor_r.position.x - wt, dbot.y), Vector2(wt, floor_r.end.y - dbot.y)), Color(0.32, 0.14, 0.1))
	MG.solid(ci, Rect2(dtop - Vector2(wt, 0), Vector2(wt * 0.8, dbot.y - dtop.y)), Color(0.22, 0.3, 0.27))  # takaovi
	ci.draw_line(dtop + Vector2(1, 0), dbot + Vector2(1, 0), Color(1.0, 0.85, 0.5, 0.8), 2.0)  # valorako
	# ULOS-valo oven yllä.
	var ex := _w2s(Vector2(0.05, DOOR_Y - 0.75))
	MG.box(ci, Rect2(ex - Vector2(4, 20), Vector2(16, 40)), Color(0.1, 0.75, 0.3), 3, 0, MG.OUTLINE, 2)
	ci.draw_set_transform(ex + Vector2(8, 0), PI / 2.0, Vector2.ONE)
	ci.draw_string(ThemeDB.fallback_font, Vector2(-20, 4), "ULOS", HORIZONTAL_ALIGNMENT_CENTER, 40, 10, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Penkki ja vaatteet, kengät alla.
	var bench := _rect_px(OBST[0])
	MG.wood(ci, bench, Color(0.55, 0.4, 0.25), bench.size.y / 2.0, 9, true)
	ci.draw_rect(bench, MG.OUTLINE, false, 2.0)
	var piles := [Color(0.25, 0.32, 0.55), Color(0.3, 0.38, 0.2), Color(0.8, 0.45, 0.6), Color(0.75, 0.2, 0.2), Color(0.85, 0.82, 0.7)]
	for i in piles.size():
		var pr := Rect2(bench.position + Vector2((0.1 + i * 0.62) * _ppm, 0.05 * _ppm), Vector2(0.5, 0.33) * _ppm)
		MG.box(ci, pr, piles[i], 5, 2, MG.OUTLINE, 1)
		ci.draw_line(pr.position + Vector2(4, pr.size.y * 0.5), pr.end - Vector2(4, pr.size.y * 0.5), piles[i].darkened(0.25), 2.0)
		for sx in [0.12, 0.3]:
			var sp := _w2s(Vector2(0.4 + i * 0.62 + sx, 0.85))
			_ellipse(ci, sp, 0.07 * _ppm, 0.13 * _ppm, Color(0.12, 0.1, 0.09))
			_ellipse(ci, sp - Vector2(0, 0.04 * _ppm), 0.05 * _ppm, 0.07 * _ppm, Color(0.3, 0.25, 0.2))
	# Lavapinot, laatikot, patjat, sohva ja pilarit.
	for r: Rect2 in [OBST[1], OBST[6]]:
		var pr := _rect_px(r)
		MG.solid(ci, pr, Color(0.6, 0.5, 0.35))
		for j in 5:
			var y := pr.position.y + pr.size.y * (0.08 + j * 0.2)
			ci.draw_rect(Rect2(pr.position.x + 3, y, pr.size.x - 6, pr.size.y * 0.13), Color(0.72, 0.6, 0.42))
	for r: Rect2 in [OBST[2], OBST[3]]:
		var pr := _rect_px(r)
		MG.wood(ci, pr, Color(0.55, 0.42, 0.26), pr.size.y / 4.0, 4, false)
		ci.draw_rect(pr, MG.OUTLINE, false, 2.0)
		ci.draw_line(pr.position, pr.end, Color(0.35, 0.25, 0.15), 3.0)
		ci.draw_string(ThemeDB.fallback_font, pr.position + Vector2(0, pr.size.y * 0.6), "VARAOSIA", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 14,
			Color(0.15, 0.1, 0.05, 0.8))
	var mr := _rect_px(OBST[4])
	MG.box(ci, mr, Color(0.75, 0.72, 0.82), 10, 3, MG.OUTLINE, 2)
	for j in 6:
		ci.draw_line(Vector2(mr.position.x + mr.size.x * (j + 0.5) / 6.0, mr.position.y + 4), Vector2(mr.position.x + mr.size.x * (j + 0.5) / 6.0, mr.end.y - 4),
			Color(0.55, 0.55, 0.7), 4.0)
	ci.draw_circle(mr.get_center() + Vector2(-20, 10), 14, Color(0.6, 0.5, 0.3, 0.5))  # tahra
	var so := _rect_px(OBST[5])
	MG.box(ci, so, Color(0.45, 0.25, 0.15), 8, 3, MG.OUTLINE, 2)
	for j in 3:
		MG.box(ci, Rect2(so.position + Vector2(so.size.x * (0.06 + j * 0.31), so.size.y * 0.1), Vector2(so.size.x * 0.28, so.size.y * 0.55)),
			Color(0.55, 0.32, 0.2), 6, 0, MG.OUTLINE, 1)
	for r: Rect2 in [OBST[7], OBST[8]]:
		MG.solid(ci, _rect_px(r), Color(0.45, 0.35, 0.25))
	# Jakkara ja margariini.
	var st := _rect_px(OBST[9])
	MG.ball(ci, st.get_center(), st.size.x * 0.5, Color(0.5, 0.38, 0.25), 0.2)
	_tub(ci, st.get_center(), _ppm / 260.0)
	# Portsari ovensuussa (seisoo, vaatteet päällä).
	var pp := _w2s(Vector2(0.7, DOOR_Y - 1.0))
	_ellipse(ci, pp + Vector2(3, 4), 0.28 * _ppm, 0.18 * _ppm, Color(0, 0, 0, 0.4))
	_ellipse(ci, pp, 0.17 * _ppm, 0.27 * _ppm, Color(0.08, 0.08, 0.09))
	ci.draw_circle(pp, 0.11 * _ppm, Color(0.55, 0.4, 0.33))
	ci.draw_circle(pp - Vector2(0.01, 0) * _ppm, 0.09 * _ppm, Color(0.12, 0.1, 0.09))
	# Konttaajat.
	for i in npcs.size():
		var n: Dictionary = npcs[i]
		_crawler(ci, n.pos, n.ang, n.phase, people[i].bulk, i == nappi and n.butter_t <= 0.0)
	_crawler(ci, me.pos, me.ang, me.phase, 1.0, nappi == -1, true)


func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, outline := false) -> void:
	var pts := PackedVector2Array()
	for a in 20:
		var t := a / 20.0 * TAU
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	ci.draw_colored_polygon(pts, col)
	if outline:
		pts.append(pts[0])
		ci.draw_polyline(pts, MG.OUTLINE, 1.5, true)


## Konttaaja ylhäältä: pää eteenpäin, selkä, pakarat, polvet ja sääret takana, kädet edessä vuorotahdissa.
func _crawler(ci: CanvasItem, pos: Vector2, ang: float, phase: float, bulk: float, butter: bool, is_me := false) -> void:
	var skin := SKIN_DARK.lightened(0.08) if is_me else SKIN_DARK
	var c := _w2s(pos)
	var u := _ppm
	var rot := Transform2D(ang, c)
	var P := func(v: Vector2) -> Vector2: return rot * (v * u)
	var sw := sin(phase)
	var shadow := PackedVector2Array()
	for a in 18:
		var t := a / 18.0 * TAU
		shadow.append(P.call(Vector2(-0.1 + cos(t) * 0.6, sin(t) * 0.3 * bulk)) + Vector2(4, 6))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	for side in [-1.0, 1.0]:
		var hip: Vector2 = Vector2(-0.3, side * 0.1 * bulk)
		var knee: Vector2 = Vector2(-0.3 + 0.07 * sw * side, side * 0.16 * bulk)
		var foot: Vector2 = Vector2(-0.7 + 0.06 * sw * side, side * 0.12)
		ci.draw_line(P.call(hip), P.call(knee), skin.darkened(0.12), 0.13 * u * bulk)
		ci.draw_line(P.call(knee), P.call(foot), skin.darkened(0.18), 0.1 * u)
		ci.draw_circle(P.call(foot), 0.05 * u, skin.darkened(0.25))
		var sh: Vector2 = Vector2(0.2, side * 0.17 * bulk)
		var el: Vector2 = Vector2(0.33 - 0.05 * sw * side, side * 0.26 * bulk)
		var hand: Vector2 = Vector2(0.5 - 0.09 * sw * side, side * 0.22)
		ci.draw_line(P.call(sh), P.call(el), skin.darkened(0.06), 0.1 * u * bulk)
		ci.draw_line(P.call(el), P.call(hand), skin.darkened(0.1), 0.08 * u)
		ci.draw_circle(P.call(hand), 0.055 * u, skin.darkened(0.04))
		if butter and side > 0.0:
			var tip: Vector2 = P.call(hand + Vector2(0.08, 0))
			ci.draw_line(P.call(hand), tip, skin, 0.03 * u)
			ci.draw_rect(Rect2(tip - Vector2(0.03, 0.03) * u, Vector2(0.06, 0.06) * u), Color(1.0, 0.88, 0.35))
			ci.draw_rect(Rect2(tip - Vector2(0.03, 0.03) * u, Vector2(0.06, 0.02) * u), Color(1.0, 0.97, 0.75))
	# Selkä: vartalo, valo selkärangan päällä, lapaluut.
	var torso := PackedVector2Array()
	for a in 22:
		var t := a / 22.0 * TAU
		torso.append(P.call(Vector2(-0.04 + cos(t) * 0.33, sin(t) * 0.19 * bulk)))
	ci.draw_colored_polygon(torso, skin)
	var hl := PackedVector2Array()
	for a in 16:
		var t := a / 16.0 * TAU
		hl.append(P.call(Vector2(-0.02 + cos(t) * 0.24, -0.02 + sin(t) * 0.08 * bulk)))
	ci.draw_colored_polygon(hl, skin.lightened(0.12))
	torso.append(torso[0])
	ci.draw_polyline(torso, MG.OUTLINE, 1.5, true)
	ci.draw_line(P.call(Vector2(0.2, 0)), P.call(Vector2(-0.22, 0)), skin.darkened(0.2), 1.5)
	for side in [-1.0, 1.0]:
		ci.draw_arc(P.call(Vector2(0.12, side * 0.08 * bulk)), 0.06 * u, ang + PI * 0.6, ang + PI * 1.4, 8, skin.darkened(0.15), 1.5)
	# Pakarat.
	for side in [-1.0, 1.0]:
		ci.draw_circle(P.call(Vector2(-0.31, side * 0.075 * bulk)), 0.11 * u * bulk, skin.lightened(0.04))
		ci.draw_arc(P.call(Vector2(-0.31, side * 0.075 * bulk)), 0.11 * u * bulk, 0, TAU, 14, MG.OUTLINE, 1.2, true)
	# Pää ja hiukset.
	ci.draw_circle(P.call(Vector2(0.4, 0)), 0.105 * u, skin)
	for side in [-1.0, 1.0]:
		ci.draw_circle(P.call(Vector2(0.4, side * 0.1)), 0.025 * u, skin.darkened(0.1))
	ci.draw_circle(P.call(Vector2(0.38, 0)), 0.095 * u, HAIR_DARK)
	ci.draw_arc(P.call(Vector2(0.4, 0)), 0.105 * u, 0, TAU, 16, MG.OUTLINE, 1.5, true)


# --- Pimeän yläkerros: äänet, sormi, valikot ------------------------------------------------------------------

func _draw_puffs() -> void:
	var font := ThemeDB.fallback_font
	for p in _puffs:
		var a: float = 1.0 - p.t / p.life
		var c := _w2s(p.pos)
		var col: Color = p.col
		# Ääniaalto: rengas laajenee kohdasta, josta ääni kuului.
		var rr: float = (0.3 + minf(p.t, 0.8) * 1.5) * _ppm
		_top.draw_arc(c, rr, 0, TAU, 32, Color(col.r, col.g, col.b, 0.35 * a), 2.0, true)
		if p.t < 0.6:
			_top.draw_arc(c, rr * 0.6, 0, TAU, 24, Color(col.r, col.g, col.b, 0.25 * a), 1.5, true)
		if p.text == "":
			continue
		var size := 26 if p.big else 19
		var tp := c + Vector2(0, -0.45 * _ppm - p.t * 12.0)
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		tp.x = clampf(tp.x, w / 2.0 + 8.0, _size().x - w / 2.0 - 8.0)
		_top.draw_string_outline(font, tp - Vector2(w / 2.0, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6,
			Color(0, 0, 0, a))
		_top.draw_string(font, tp - Vector2(w / 2.0, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.r, col.g, col.b, a))


## Sormi lähikuvassa: koukistunut käsi, etusormi pystyssä, kynsi ja nokare margariinia sormenpäässä.
## style: "me", "pekka" (karvaiset rystyset), "sinikka" (punaiset kynnet), "raimo" (rypyt), "helena" (sormus), "arto" (laastari).
func _hand_draw(ci: CanvasItem, c: Vector2, sc: float, rot: float, skin: Color, butter: float, style := "me") -> void:
	ci.draw_set_transform(c, rot, Vector2(sc, sc))
	MG.box(ci, Rect2(-30, 40, 60, 70), skin.darkened(0.12), 18, 4, MG.OUTLINE, 2)  # ranne
	MG.box(ci, Rect2(-38, -14, 76, 70), skin, 24, 4, MG.OUTLINE, 2)  # kämmen
	for j in 3:  # koukistetut sormet
		ci.draw_circle(Vector2(-4 + j * 15, -12 + j * 3), 11.0, skin.lightened(0.04))
		ci.draw_arc(Vector2(-4 + j * 15, -12 + j * 3), 11.0, PI, TAU, 10, MG.OUTLINE, 1.5)
		if style == "pekka":
			for h in 3:
				ci.draw_line(Vector2(-8 + j * 15 + h * 4, -18 + j * 3), Vector2(-9 + j * 15 + h * 4, -24 + j * 3), Color(0.25, 0.15, 0.1), 1.2)
	_ellipse(ci, Vector2(-34, 16), 12, 24, skin.darkened(0.06), true)  # peukalo
	MG.box(ci, Rect2(-34, -96, 26, 92), skin.lightened(0.03), 12, 0, MG.OUTLINE, 2)  # etusormi
	ci.draw_line(Vector2(-31, -60), Vector2(-12, -60), skin.darkened(0.2), 1.5)
	ci.draw_line(Vector2(-31, -32), Vector2(-12, -32), skin.darkened(0.2), 1.5)
	if style == "raimo":
		for j in 4:
			ci.draw_arc(Vector2(-21, -46 + j * 6), 8.0, PI * 1.1, PI * 1.9, 6, skin.darkened(0.25), 1.0)
	if style == "arto":
		MG.box(ci, Rect2(-36, -52, 30, 14), Color(0.92, 0.78, 0.62), 3, 0, MG.OUTLINE, 1)
		for j in 3:
			ci.draw_circle(Vector2(-27 + j * 6, -45), 1.2, Color(0.7, 0.55, 0.4))
	if style == "helena":
		MG.box(ci, Rect2(-36, -30, 30, 8), Color(0.95, 0.8, 0.3), 3, 0, MG.OUTLINE, 1)
	var nail := Color(0.85, 0.12, 0.18) if style == "sinikka" else skin.lightened(0.25)
	MG.box(ci, Rect2(-30, -92, 18, 20), nail, 7, 0, MG.OUTLINE, 1)
	ci.draw_line(Vector2(-27, -89), Vector2(-17, -89), nail.lightened(0.5), 2.0)
	if butter > 0.02:
		var h := 22.0 * butter
		var fat := Color(1.0, 0.99, 0.95) if _kerma() else Color(1.0, 0.86, 0.32)
		if _kerma():  # kermavaahtopilvi: pyöreät nokareet ja kiehkura
			for j in 4:
				ci.draw_circle(Vector2(-30 + j * 7, -96 - h * 0.5 - (j % 2) * 5), 8.0 + h * 0.15, fat.darkened(0.04 * (j % 2)))
			ci.draw_arc(Vector2(-21, -100 - h * 0.6), 6.0, 0, PI * 1.5, 8, Color(0.85, 0.82, 0.78), 1.5)
		else:
			MG.box(ci, Rect2(-38, -98 - h, 34, h + 6), fat, 5, 2, MG.OUTLINE, 2)
			ci.draw_rect(Rect2(-35, -96 - h, 26, 4), Color(1.0, 0.97, 0.75))
		ci.draw_circle(Vector2(-10, -88), 4.0 * butter, fat)  # valuu
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_finger_hud() -> void:
	var s := _size()
	var k := s.y / 720.0
	if _mode == "esittely" or nappi == -1:
		var r := Rect2(s.x - 150 * k, s.y - 290 * k, 130 * k, 220 * k)
		MG.box(_top, r, Color(0.06, 0.05, 0.05, 0.85), 14, 6, Color(0.95, 0.8, 0.3), 2)
		_hand_draw(_top, r.position + Vector2(72, 126) * k, 0.62 * k, 0.1, Color(0.92, 0.72, 0.6), 1.0)
		_top.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 24 * k), "RASVANAPPI", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(16 * k),
			Color(1.0, 0.88, 0.35))
		_top.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, r.size.y - 12 * k), "olet sinä", HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
			int(14 * k), Color(0.85, 0.82, 0.75))
	else:
		var r := Rect2(s.x - 230 * k, s.y - 130 * k, 210 * k, 60 * k)
		MG.box(_top, r, Color(0.06, 0.05, 0.05, 0.8), 12, 4, Color(0.6, 0.5, 0.3), 2)
		_top.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 26 * k), "Nappi on joku muu", HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
			int(17 * k), Color(1.0, 0.88, 0.35))
		var near: float = npcs[nappi].pos.distance_to(me.pos) if nappi >= 0 else 99.0
		var warn := "kahinaa lähellä!" if near < 2.5 else "kuuntele…"
		_top.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 48 * k), warn, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(15 * k),
			Color(1.0, 0.5, 0.4) if near < 2.5 else Color(0.8, 0.8, 0.75))


func _draw_name_menu() -> void:
	var s := _size()
	var k := s.y / 720.0
	var w := 420.0 * k
	var h := (people.size() * 48.0 + 80.0) * k
	var r := Rect2((s.x - w) / 2.0, (s.y - h) / 2.0, w, h)
	MG.box(_top, r, Color(0.06, 0.05, 0.05, 0.92), 14, 8, Color(0.95, 0.8, 0.3), 2)
	_top.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 40 * k), "\"Rasvanappi, …!\"", HORIZONTAL_ALIGNMENT_CENTER, w, int(28 * k),
		Color(1.0, 0.9, 0.45))
	for i in people.size():
		var rr := Rect2(r.position + Vector2(24, 62 + i * 48) * k, Vector2(w - 48 * k, 40 * k))
		var on := i == _sel
		MG.box(_top, rr, Color(0.95, 0.82, 0.35) if on else Color(0.2, 0.18, 0.16), 8, 0, MG.OUTLINE, 2)
		_top.draw_string(ThemeDB.fallback_font, rr.position + Vector2(16, 28) * k, "%d   %s   · %s" % [i + 1, people[i].name, people[i].desc],
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(21 * k), Color(0.1, 0.08, 0.05) if on else Color(0.92, 0.9, 0.85))


func _draw_lick() -> void:
	var s := _size()
	var k := s.y / 720.0
	var r := Rect2(s.x * 0.5 - 330 * k, s.y * 0.5 - 210 * k, 660 * k, 420 * k)
	MG.box(_top, r, Color(0.04, 0.03, 0.04, 0.95), 18, 10, Color(0.95, 0.75, 0.8), 3)
	var kind: String = _lick.get("kind", "")
	var who: int = _lick.get("who", 0)
	var p: Dictionary = people[who]
	var own := kind in ["other_me", "me_self"]  # nuoltava sormi on pelaajan
	var style: String = "me" if own else p.id
	var skin: Color = Color(0.92, 0.72, 0.6) if own else p.look.skin
	var lt := clampf((_t - 0.3) / 1.4, 0.0, 1.0)
	var butter := 1.0 - smoothstep(0.35, 0.9, lt)
	var hc := r.position + Vector2(230, 250) * k
	var wob := sin(_t * 30.0) * 3.0 * k if lt > 0.3 and lt < 0.9 else 0.0
	var hs := 1.15 * k
	_hand_draw(_top, hc + Vector2(wob, 0), hs, 0.05, skin, butter, style)
	# Suu ja kieli: muiden suu oikealta, oma vasemmalta alhaalta. Kieli nuolaisee sormenpään alhaalta ylös.
	var from_side := kind in ["other_me", "other_self"]
	var tip := hc + Vector2(-20, -100) * hs
	var mouth := tip + (Vector2(115, 25) if from_side else Vector2(-110, 50)) * k
	var reach := sin(lt * PI)
	var tc := mouth.lerp(tip + Vector2(0, lerpf(30.0, -30.0, lt)) * k, reach)
	var tongue := Color(0.86, 0.36, 0.43)
	_ellipse(_top, mouth, 44 * k, 30 * k, Color(0.6, 0.2, 0.22), true)  # huulet
	_ellipse(_top, mouth, 32 * k, 18 * k, Color(0.18, 0.04, 0.06))
	if reach > 0.02:
		var dir := (tc - mouth).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var w0 := 17.0 * k
		var pts := PackedVector2Array([mouth + nrm * w0, tc + nrm * w0 * 0.9, tc - nrm * w0 * 0.9, mouth - nrm * w0])
		_top.draw_colored_polygon(pts, tongue)
		_top.draw_circle(tc, w0 * 0.9, tongue)
		_top.draw_arc(tc, w0 * 0.9, dir.angle() - PI / 2.0, dir.angle() + PI / 2.0, 10, MG.OUTLINE, 2.0)
		_top.draw_line(mouth + nrm * w0, tc + nrm * w0 * 0.9, MG.OUTLINE, 2.0)
		_top.draw_line(mouth - nrm * w0, tc - nrm * w0 * 0.9, MG.OUTLINE, 2.0)
		_top.draw_line(mouth + dir * 6 * k, tc - dir * 6 * k, tongue.darkened(0.3), 2.0 * k)  # kielen ura
		_top.draw_circle(tc + nrm * 6 * k, 4 * k, tongue.lightened(0.35))
	_ellipse(_top, mouth + Vector2(0, -14 * k), 40 * k, 9 * k, Color(0.66, 0.24, 0.26))  # ylähuuli kielen päällä
	if lt > 0.4:
		var pop := clampf((lt - 0.4) * 4.0, 0.1, 1.0)
		_top.draw_string_outline(ThemeDB.fallback_font, r.position + Vector2(400, 150) * k, "SLUUURP", HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(48 * k * pop), 10, Color(0, 0, 0))
		_top.draw_string(ThemeDB.fallback_font, r.position + Vector2(400, 150) * k, "SLUUURP", HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(48 * k * pop), Color(1.0, 0.6, 0.7))
	var line := ""
	var sub := ""
	match kind:
		"other_me":
			line = "Osui! %s nuolee sormesi puhtaaksi." % p.name
			sub = "%s: \"%s\" Nyt %s on rasvanappi." % [p.name, p.lick, p.name]
		"me_self":
			line = "Väärin, se oli %s. Nuolet oman sormesi." % p.name
			sub = "Kermavaahtoa. Makeaa. Ja jotain muuta. Älä ajattele sitä." if _kerma() else "Margariinia. Ja jotain muuta. Älä ajattele sitä."
		"me_other":
			line = "%s arvasi. Nuolet %s sormen puhtaaksi." % [p.name, p.gen]
			sub = "Nyt sinä olet rasvanappi."
		"other_self":
			line = "Ei osunut! %s nuolee oman sormensa." % p.name
			sub = "%s: \"%s\" Jahti jatkuu." % [p.name, p.lick]
	_wrap(_top, r.position + Vector2(400, 210) * k, line, 240 * k, int(21 * k), Color(1.0, 0.95, 0.85))
	_wrap(_top, r.position + Vector2(400, 300) * k, sub, 240 * k, int(17 * k), Color(0.85, 0.8, 0.75))


func _wrap(ci: CanvasItem, at: Vector2, text: String, w: float, size: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var line := ""
	var y := 0.0
	for word in text.split(" "):
		var t := word if line == "" else line + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w and line != "":
			ci.draw_string(font, at + Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += size * 1.3
			line = word
		else:
			line = t
	ci.draw_string(font, at + Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_end() -> void:
	var s := _size()
	var k := s.y / 720.0
	var r := Rect2(s.x * 0.5 - 300 * k, s.y * 0.5 - 170 * k, 600 * k, 340 * k)
	if _hall != null:  # valaistu halli näkyy: taulu alareunaan
		r.position.y = s.y - 70 * k - r.size.y
	MG.box(_top, r, Color(0.05, 0.04, 0.04, 0.94), 18, 10, Color(0.95, 0.8, 0.3), 3)
	var font := ThemeDB.fallback_font
	_top.draw_string(font, r.position + Vector2(0, 54 * k), "KESKEN LÄHTÖ" if _early else "VALOT PÄÄLLE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
		int(38 * k), Color(1.0, 0.9, 0.45))
	var y := 100.0
	for l in _end_lines:
		_top.draw_string(font, r.position + Vector2(0, y * k), l, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(20 * k), Color(0.95, 0.92, 0.85))
		y += 30.0
	y += 16.0
	var tally := ["Tökkäsit %d kertaa, arvasit oikein %d." % [my_pokes, my_hits], "Nuolit sormia: %d." % licks]
	if rules.get("mansikka", false):
		tally.append("Mansikoita palkinnoksi: %d." % strawberries)
	for l in tally:
		_top.draw_string(font, r.position + Vector2(0, y * k), l, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(22 * k), Color(1.0, 0.85, 0.6))
		y += 32.0
	_top.draw_string(font, r.position + Vector2(0, (y + 20) * k), rules.get("end_quote", "Pekka: \"No niin. Ensi tiistaina uudestaan.\""), HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x, int(18 * k), Color(0.8, 0.8, 0.75))
