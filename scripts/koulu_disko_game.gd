extends CanvasLayer
## Koulun disko Saloisten koulukeskuksen liikuntasalissa (perjantaisin 18–21): DJ on hukassa, ja pelaaja lupautuu
## pyörittämään kasetteja. Lapset huutavat toiveita (puhekuplat), ja pelaaja valitsee kolmesta kasetista seuraavan
## biisin ennen kuin edellinen loppuu. Vaihto ajoitetaan biisin saumaan (miksauspalkki): sujuva miksaus, kesken
## biisin katkaisu tai hiljaisuus. Oikea toive täyttää tanssilattiaa, väärä tyhjentää, kolmas samaa peräkkäin
## tylsistyttää. Opettaja toivoo kerran polkkaa: lapset voihkivat, mutta opettaja muistaa sen. Kuusi biisiä, tulos
## tanssilattian keskimääräisestä täyttöasteesta (maine).
## Sali on oma lavasteensa koulun yläpuolella (rasvanappi_hall.gd:n näkyvyyskerros LAYER, kuten disko_game.gd):
## parketti pelikenttäviivoineen, puolapuut, koripallokori, patjat, serpentiinit, ilmapallot, KOULUDISKO-banderolli,
## peilipallo valotäplineen ja värivalot. Hahmot ovat 3D-hahmoja (Looks.make): 12 lasta, opettaja ja pelaaja DJ-pöydän
## takana. Ruudulla vain käyttöliittymä: tanssilattiamittari, soiva kasetti, kasettivalinta, miksauspalkki ja näppäinohje.

signal finished(result: Dictionary)

const Room := preload("res://scripts/ilta_room.gd")
const Hall := preload("res://scripts/rasvanappi_hall.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const MG := preload("res://scripts/mg_draw.gd")

const GENRES := {
	"tekno": {"name": "Tekno", "col": Color(0.2, 0.78, 0.95), "speed": 1.2},
	"dance": {"name": "Dance", "col": Color(0.98, 0.35, 0.72), "speed": 1.0},
	"hidas": {"name": "Hidas", "col": Color(0.98, 0.6, 0.25), "speed": 0.45},
	"polkka": {"name": "Polkka", "col": Color(0.45, 0.78, 0.3), "speed": 1.35},
}
## Kasetit: [nimi, tyyli, tiedosto, aloituskohta s]. 90-luvun biisit CC BY (assets/music/kuulokkeet, tekijät
## docs/tekijanoikeudet.md), hitaat ja polkat pelin omista (slow_stride.ogg, assets/music/iskelma).
const KASETIT := [
	["Robotertanz", "tekno", "res://assets/music/kuulokkeet/01_Robotertanz.mp3", 32.0],
	["90s Racer Techno", "tekno", "res://assets/music/kuulokkeet/02_90s_Racer_Techno.mp3", 32.0],
	["Acid Action", "tekno", "res://assets/music/kuulokkeet/03_Acid_Action.mp3", 30.0],
	["Rave Spider", "tekno", "res://assets/music/kuulokkeet/07_Bitten_by_the_Rave_Spider.ogg", 24.0],
	["I'm Free", "dance", "res://assets/music/kuulokkeet/04_Im_Free.mp3", 30.0],
	["It's Love", "dance", "res://assets/music/kuulokkeet/05_Its_Love.mp3", 30.0],
	["Dance and Jump", "dance", "res://assets/music/kuulokkeet/06_Dance_and_Jump.ogg", 32.0],
	["Slow Stride", "hidas", "res://assets/music/slow_stride.ogg", 20.0],
	["Kulkurin valssi", "hidas", "res://assets/music/iskelma/03_Kulkurin_valssi.mp3", 12.0],
	["Säkkijärven polkka", "polkka", "res://assets/music/iskelma/01_Sakkijarven_polkka.mp3", 8.0],
	["Immu-polkka", "polkka", "res://assets/music/iskelma/08_Immu-polkka.mp3", 8.0],
	["Kylän jenkka", "polkka", "res://assets/music/iskelma/07_Kylan_jenkka.mp3", 8.0],
]
const ROUNDS := 6
const SEG := 20.0  # biisin pituus diskossa (s)
const MIX_BAR := 4.0  # miksauspalkki näkyy biisin viimeiset sekunnit
const MIX_WIN := 1.1  # sujuvan miksauksen ikkuna palkin lopussa (s)
const GAP := 1.6  # hiljaisuus, jos DJ ei miksaa ajoissa
const KIDS := 12
## Salin koordinaatit: -Z = sali (kori ja banderolli), +Z = DJ-pöytä ja kamera. Lattia x -7..7, z -9..7.
const FLOOR_SLOTS := [Vector3(-2.4, 0, -1.2), Vector3(-0.8, 0, -1.2), Vector3(0.8, 0, -1.2), Vector3(2.4, 0, -1.2),
	Vector3(-2.4, 0, 0.4), Vector3(-0.8, 0, 0.4), Vector3(0.8, 0, 0.4), Vector3(2.4, 0, 0.4),
	Vector3(-2.4, 0, 2.0), Vector3(-0.8, 0, 2.0), Vector3(0.8, 0, 2.0), Vector3(2.4, 0, 2.0)]
const DJ_AT := Vector3(-3.6, 0, 3.9)
const DJ_FACE := Vector3(3.6, 0, -4.4)  # DJ katsoo lattian keskelle (pöydän etupuoli -Z paikallisesti)
const TEACHER_AT := Vector3(4.3, 0, -1.6)
const SHIRTS := [Color(0.95, 0.2, 0.55), Color(0.2, 0.8, 0.9), Color(0.6, 0.9, 0.2), Color(0.98, 0.8, 0.15),
	Color(0.55, 0.3, 0.85), Color(0.95, 0.45, 0.15), Color(0.15, 0.35, 0.85), Color(0.92, 0.92, 0.94)]
const HAIRS := [Color(0.85, 0.7, 0.4), Color(0.35, 0.22, 0.12), Color(0.15, 0.1, 0.07), Color(0.62, 0.35, 0.15)]
const TEACHER_LOOK := {"woman": true, "hair": "Hair_Buns", "hair_color": Color(0.5, 0.36, 0.26), "height": 1.66,
	"shirt": Color(0.42, 0.52, 0.4), "skirt": Color(0.26, 0.26, 0.36), "shoes": Color(0.3, 0.2, 0.15), "skin": Color(0.95, 0.8, 0.72)}
## Lasten toiveet tyyleittäin ja reaktiot.
const WANT_LINES := {
	"tekno": ["Jotain teknoa!", "Lisää bassoa, setä!", "Rave! Rave! Rave!", "Laita se Robotertanz!"],
	"dance": ["Jotain tanssittavaa!", "Eurodancea!", "Laita se Dance and Jump!", "I'm Free, pliis!"],
	"hidas": ["HIDAS! Jonna on täällä!", "Hitaita, setä!", "Hidas! Mää haen Villen!"],
}
const TEACHER_ASK := "Laitappa välillä polkkaa. Se on perinnettä, lapset tykkää kyllä!"
const REACT := {
	"hyva": ["JEE!", "Tää on mun biisi!", "Setä osaa!", "Kaikki lattialle!"],
	"huono": ["Tylsää...", "Kuka tän toivo?", "Mennään juomaan mehua."],
	"polkka": ["Ei polkkaa!", "Yäk, mummojen musaa!", "Opettaja taas..."],
	"kesken": ["Hei, se oli kesken!", "Mitä toi oli?!"],
	"hiljaa": ["DJ nukkuu!", "Hei, musiikki loppu!"],
	"tylsa": ["Taas samaa...", "Eiks oo muita kasetteja?"],
}

var anchor: Node3D
var sun: DirectionalLight3D
var player_look: Dictionary = {}
var maine := 50.0
var auto := false  # testit: valitse toive ja miksaa ikkunassa

var _room: Node3D
var _env: Environment
var _cam: Camera3D
var _cam_base: Transform3D
var _sun_mask := 0
var _dj: Node3D
var _teacher: Node3D
var _kids: Array = []  # {"c", "wall": Vector3, "face_wall": Vector3, "slot": int (-1 = seinällä), "from", "to", "t", "busy"}
var _ball: Node3D
var _dots: Array = []  # peilipallon valotäplät (Node3D, kulma, säde, korkeus)
var _spots: Array = []  # värivalot
var _vu: Array = []  # kasettidekin VU-palkit
var _music: Array = []  # kaksi soitinta ristiinhäivytykseen
var _cur := 0  # soiva soitin
var _ui: Control
var _keys: Node
var _rng := RandomNumberGenerator.new()

var _phase := "alku"  # alku / soi / tauko / loppu / valmis
var _t := 0.0  # aika biisin alusta (tai vaiheen alusta)
var _round := 0  # soitetut biisit
var _playing := -1  # KASETIT-indeksi
var _offer: Array = []  # kolme KASETIT-indeksiä
var _sel := 1
var _wants := {}  # tyyli -> toiveiden määrä
var _history: Array = []  # soitetut tyylit
var _floor := 3  # lapsia lattialla
var _fill_sum := 0.0
var _teacher_asked := false
var _teacher_happy := false
var _asks_done := 0  # tämän biisin aikana esitetyt toiveet
var _bubbles := {}  # Node3D -> [teksti, jäljellä s]
var _story := ""
var _flash := ""  # palaute miksauksesta (ruudun keskellä hetken)
var _flash_t := 0.0
var _flash_col := Color.WHITE
var _shake := 0.0
var _sparks: Array = []
var _result := {}
var _last_mix := ""


func _ready() -> void:
	layer = 6
	add_to_group("esc_lopettaa")
	_rng.randomize()
	_build()
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
		m.volume_db = -4.0
		add_child(m)
		_music.append(m)
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
	_make_offer()
	_story = "DJ on hukassa! Lapset huutavat toiveita: valitse kasetti ja paina soimaan. Vaihda biisi saumassa, kun palkin neula on vihreällä."
	_ask_random()
	_ask_random()


func _exit_tree() -> void:
	if sun != null and is_instance_valid(sun):
		sun.light_cull_mask = _sun_mask
	if is_instance_valid(_room):
		_room.queue_free()


# --- Pelilogiikka (testattava ilman ruutua) ------------------------------------------------------------------------

## Eniten toivottu tyyli ("" jos ei toiveita).
func top_want() -> String:
	var best := ""
	var n := 0
	for g in _wants:
		if int(_wants[g]) > n:
			n = int(_wants[g])
			best = g
	return best


## Tanssilattian muutos, kun tyylin g biisi alkaa miksauksella mix (sujuva / kesken / hiljaisuus / alku).
func score_change(g: String, mix: String) -> int:
	var d := 0
	var top := top_want()
	if g == "polkka":
		d -= 3
	elif top != "" and g == top:
		d += 3
	elif int(_wants.get(g, 0)) > 0:
		d += 1
	else:
		d -= 1
	if _history.size() >= 2 and _history[-1] == g and _history[-2] == g:
		d -= 1  # kolmas samaa peräkkäin: tylsää
	d += {"sujuva": 1, "kesken": -1, "hiljaisuus": -2}.get(mix, 0)
	return d


## Tulos keskimääräisestä täyttöasteesta: [otsikko, maine].
static func rating(avg: float, teacher_asked: bool, teacher_happy: bool) -> Array:
	var title := "Tyhjä lattia"
	var rep := -1
	if avg >= 8.0:
		title = "Diskon kuningas"
		rep = 4
	elif avg >= 5.0:
		title = "Kelpo DJ"
		rep = 2
	elif avg >= 2.0:
		title = "Kuin mummojen tanssit"
		rep = 0
	if teacher_asked:
		rep += 1 if teacher_happy else -1
	return [title, rep]


## Kolme kasettia eri tyyleistä; eniten toivottu on mukana neljällä kerralla viidestä.
func _make_offer() -> void:
	var styles: Array = GENRES.keys()
	styles.shuffle()
	var top := top_want()
	if top != "" and not top in styles.slice(0, 3) and _rng.randf() < 0.8:
		styles[2] = top
	elif top != "" and _rng.randf() >= 0.8:
		styles.erase(top)
	_offer.clear()
	for g in styles.slice(0, 3):
		var pool: Array = []
		for i in KASETIT.size():
			if KASETIT[i][1] == g and i != _playing:
				pool.append(i)
		if pool.is_empty():
			continue
		_offer.append(pool[_rng.randi() % pool.size()])
	_sel = clampi(_sel, 0, _offer.size() - 1)


## Lapsi (tai opettaja, kerran polkkaa) huutaa toiveen.
func _ask_random(force := "") -> void:
	var g := force
	if g == "":
		var r := _rng.randf()
		var hidas_p := 0.12 + 0.05 * _round
		g = "hidas" if r < hidas_p else ("tekno" if r < hidas_p + (1.0 - hidas_p) / 2.0 else "dance")
	_wants[g] = int(_wants.get(g, 0)) + 1
	var who := _visible_kid()
	if who != null:
		_say(who, (WANT_LINES[g] as Array).pick_random())


## Satunnainen lapsi, jonka pää näkyy ruudulla (puhekupla osoittaa puhujaan); muuten kuka tahansa.
func _visible_kid() -> Node3D:
	if _kids.is_empty():
		return null
	var pool: Array = []
	if _cam != null:
		var vs := get_viewport().get_visible_rect().size
		for k: Dictionary in _kids:
			var c: Node3D = k.c
			var p := _cam.unproject_position(c.to_global(Vector3(0, 1.4, 0)))
			if p.x > vs.x * 0.08 and p.x < vs.x * 0.92 and p.y > vs.y * 0.2 and p.y < vs.y * 0.8 and not _cam.is_position_behind(c.global_position):
				pool.append(c)
	if pool.is_empty():
		return _kids[_rng.randi() % _kids.size()].c
	return pool[_rng.randi() % pool.size()]


## Puhekupla puhujalle. Lähellä toisiaan (ruudulla alle 300 px) olevat kuplat menisivät päällekkäin: uusin korvaa.
func _say(c: Node3D, text: String, secs := 3.2) -> void:
	if c == null:
		return
	if _cam != null:
		var p := _cam.unproject_position(c.to_global(Vector3(0, 1.5, 0)))
		for o in _bubbles.keys():
			if o != c and is_instance_valid(o) and _cam.unproject_position((o as Node3D).to_global(Vector3(0, 1.5, 0))).distance_to(p) < 300.0:
				_bubbles.erase(o)
	_bubbles[c] = [text, secs]


## Biisi alkaa: lattia muuttuu, toive täyttyy, uusi tarjous. mix = alku / sujuva / kesken / hiljaisuus.
func _start_song(idx: int, mix: String) -> void:
	var g: String = KASETIT[idx][1]
	var d := score_change(g, mix) if mix != "alku" else (3 if g == top_want() else (-1 if g == "polkka" else 1))
	_last_mix = mix
	_history.append(g)
	_wants.erase(g)
	_playing = idx
	_round += 1
	_t = 0.0
	_asks_done = 0
	_phase = "soi"
	_set_floor(clampi(_floor + d, 0, KIDS))
	_react(g, d, mix)
	if g == "polkka" and _teacher_asked:
		_teacher_happy = true
		_say(_teacher, "No niin! Tätä minä toivoin.")  # lasten voihkaisun jälkeen: opettajan kupla jää näkyviin
	_play_audio(idx, mix)
	_make_offer()


func _react(g: String, d: int, mix: String) -> void:
	var key := "hyva" if d >= 2 else "huono"
	if g == "polkka":
		key = "polkka"
	elif mix == "kesken":
		key = "kesken"
	elif mix == "hiljaisuus":
		key = "hiljaa"
	elif _history.size() >= 3 and _history[-2] == g and _history[-3] == g:
		key = "tylsa"
	var who := _visible_kid()
	_say(who, (REACT[key] as Array).pick_random(), 2.4)
	var good := d >= 2
	_flash = "%s  %+d" % [{"sujuva": "Sujuva miksaus!", "kesken": "Kesken biisin!", "hiljaisuus": "Hiljaisuus...", "alku": "Soimaan!"}.get(mix, ""), d]
	_flash_t = 1.6
	_flash_col = Color(0.4, 1.0, 0.5) if good else (Color(1.0, 0.85, 0.3) if d >= 0 else Color(1.0, 0.4, 0.35))
	if good:
		var vs := _ui.size if _ui != null else Vector2(1280, 720)
		MG.sparks_burst(_sparks, Vector2(vs.x * 0.5, vs.y * 0.42), GENRES[g].col, 30)
		Sfx.play("win_small", -8.0, 1.2)
	elif d < 0:
		_shake = 0.6
		Sfx.play("groan", -6.0, 1.3)


func _play_audio(idx: int, mix: String) -> void:
	if _music.is_empty():
		return
	var k: Array = KASETIT[idx]
	var st: AudioStream = load(k[2])
	var nxt: AudioStreamPlayer = _music[1 - _cur]
	var old: AudioStreamPlayer = _music[_cur]
	nxt.stream = st
	var start: float = minf(k[3], maxf(0.0, st.get_length() - SEG - 2.0)) if st != null else 0.0
	nxt.volume_db = -30.0 if mix == "sujuva" else -4.0
	nxt.play(start)
	var tw := create_tween().set_parallel(true)
	if mix == "sujuva":
		tw.tween_property(nxt, "volume_db", -4.0, 1.2)
		tw.tween_property(old, "volume_db", -40.0, 1.2)
		tw.chain().tween_callback(old.stop)
	elif old.playing:
		if mix == "kesken":  # levyn raapaisu: sävel putoaa ja katkeaa
			tw.tween_property(old, "pitch_scale", 0.3, 0.25)
			tw.chain().tween_callback(func() -> void:
				old.stop()
				old.pitch_scale = 1.0)
		else:
			old.stop()
	_cur = 1 - _cur


## Miksaus: sujuva ikkunassa, muuten kesken biisin.
func _mix() -> void:
	if _phase == "alku":
		_start_song(_offer[_sel], "alku")
		_story = ""
		return
	if _phase != "soi" or _offer.is_empty():
		return
	var left := SEG - _t
	var mix := "sujuva" if left <= MIX_WIN else "kesken"
	_end_song()
	if _round >= ROUNDS:
		return
	if _dj != null:
		_dj.restart("Interact", 0.1, 1.0)
	_start_song(_offer[_sel], mix)


## Biisi loppuu (tai vaihdetaan): täyttöaste kirjataan.
func _end_song() -> void:
	_fill_sum += _floor
	if _round >= ROUNDS:
		_finish_game()


func _finish_game() -> void:
	_phase = "loppu"
	_t = 0.0
	for m: AudioStreamPlayer in _music:
		var tw := create_tween()
		tw.tween_property(m, "volume_db", -40.0, 2.0)
	var avg := _fill_sum / float(maxi(_round, 1))
	var r := rating(avg, _teacher_asked, _teacher_happy)
	_result = {"lattia": avg, "title": r[0], "rep": r[1], "opettaja": _teacher_happy if _teacher_asked else null,
		"biisit": _history.duplicate(), "luovutti": false}
	_bubbles.clear()  # tuloslaatikon päällä vain opettajan kiitos
	_flash_t = 0.0
	if _teacher_asked and not _teacher_happy:
		_say(_teacher, "Ei sitten polkkaa. Ensi kerralla pyydetään Hilkka DJ:ksi.", 4.0)
	else:
		_say(_teacher, "Kiitos, DJ! Lapset puhuu tästä viikon.", 4.0)
	Sfx.play("win" if r[1] > 0 else "win_small", -4.0)


func _quit() -> void:
	if _phase == "valmis":
		return
	_phase = "valmis"
	if _result.is_empty():
		var avg := _fill_sum / float(maxi(_round, 1))
		_result = {"lattia": avg, "title": "Lähti kesken", "rep": -1, "opettaja": null, "biisit": _history.duplicate(),
			"luovutti": true}
	finished.emit(_result)
	queue_free()


# --- Kulku --------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _phase == "valmis":
		return
	_t += delta
	if Input.is_action_just_pressed("mount") or Input.is_action_just_pressed("ui_cancel"):
		_quit()
		return
	match _phase:
		"alku":
			if Input.is_action_just_pressed("left"):
				_sel = maxi(0, _sel - 1)
			if Input.is_action_just_pressed("right"):
				_sel = mini(_offer.size() - 1, _sel + 1)
			if Input.is_action_just_pressed("interact") or (auto and _t > 1.0):
				if auto:
					_auto_pick()
				_mix()
		"soi":
			if Input.is_action_just_pressed("left"):
				_sel = maxi(0, _sel - 1)
				Sfx.play("cloth", -14.0, 1.6)
			if Input.is_action_just_pressed("right"):
				_sel = mini(_offer.size() - 1, _sel + 1)
				Sfx.play("cloth", -14.0, 1.6)
			# Toiveet biisin aikana (ja opettajan polkka kerran, kolmannessa biisissä).
			if _asks_done == 0 and _t > 3.0 and _round < ROUNDS:
				_asks_done = 1
				if _round == 3 and not _teacher_asked:
					_teacher_asked = true
					_wants["polkka"] = int(_wants.get("polkka", 0)) + 1
					_say(_teacher, TEACHER_ASK, 4.0)
				else:
					_ask_random()
			elif _asks_done == 1 and _t > 10.0 and _round < ROUNDS:
				_asks_done = 2
				_ask_random()
			if auto:
				_auto_pick()
				if SEG - _t <= MIX_WIN * 0.5:
					_mix()
					return
			elif Input.is_action_just_pressed("interact") and SEG - _t <= MIX_BAR:
				_mix()
				return
			if _t >= SEG:
				# Kukaan ei miksannut: hiljaisuus.
				_end_song()
				if _phase == "soi":
					_music[_cur].stop()
					_phase = "tauko"
					_t = 0.0
		"tauko":
			if _t >= GAP:
				_start_song(_offer[_sel], "hiljaisuus")
		"loppu":
			if _t > 2.5 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump") or auto):
				_quit()
				return
	_animate(delta)
	_update_keys()
	_ui.queue_redraw()


func _auto_pick() -> void:
	var top := top_want()
	for i in _offer.size():
		if KASETIT[_offer[i]][1] == top:
			_sel = i
			return


# --- Hahmot ja lattia -----------------------------------------------------------------------------------------------

## Lattialle n lasta: seinältä tulijat ja lattialta lähtijät kävelevät (Walk), perillä tanssi tai seisoskelu.
func _set_floor(n: int) -> void:
	var on: Array = _kids.filter(func(k: Dictionary) -> bool: return k.slot >= 0)
	var off: Array = _kids.filter(func(k: Dictionary) -> bool: return k.slot < 0)
	on.shuffle()
	off.shuffle()
	while on.size() > n:
		var k: Dictionary = on.pop_back()
		k.slot = -1
		_walk(k, k.wall)
	var used: Array = on.map(func(k: Dictionary) -> int: return k.slot)
	var free: Array = []
	for i in FLOOR_SLOTS.size():
		if not i in used:
			free.append(i)
	free.shuffle()
	while on.size() < n and not off.is_empty() and not free.is_empty():
		var k: Dictionary = off.pop_back()
		k.slot = free.pop_back()
		on.append(k)
		_walk(k, FLOOR_SLOTS[k.slot])
	_floor = on.size()
	_restyle()


func _walk(k: Dictionary, to: Vector3) -> void:
	k.from = (k.c as Node3D).position
	k.to = to
	k.t = 0.0
	k.busy = true
	var dir: Vector3 = to - k.from
	if dir.length() > 0.05:
		(k.c as Node3D).rotation.y = B.yaw_to(dir)
	(k.c as Node3D).restart("Walk", 0.15, 1.0)


## Tanssin tyyli soivan biisin mukaan. Hitaalla vierekkäisten paikkojen lapset kävelevät pariksi (35 cm toisistaan),
## muulla biisillä takaisin omalle paikalleen.
func _restyle() -> void:
	var g := "" if _playing < 0 else String(KASETIT[_playing][1])
	for k: Dictionary in _kids:
		if k.slot >= 0:
			var at := _slot_pos(k, g)
			if (k.c as Node3D).position.distance_to(at) > 0.3 and not (k.busy and (k.to as Vector3).distance_to(at) < 0.3):
				_walk(k, at)
				continue
		if k.busy:
			continue
		_settle(k, g)


## Lattiapaikan kohta: hitaalla pari keskelle (jos parin toinenkin on lattialla), muuten oma paikka.
func _slot_pos(k: Dictionary, g: String) -> Vector3:
	var own: Vector3 = FLOOR_SLOTS[k.slot]
	if g != "hidas":
		return own
	var mate := _mate_slot(k.slot)
	if not _kids.any(func(o: Dictionary) -> bool: return o.slot == mate):
		return own
	var mid: Vector3 = (own + FLOOR_SLOTS[mate]) / 2.0
	return mid + (own - mid).normalized() * 0.18


static func _mate_slot(slot: int) -> int:
	return slot + (1 if slot % 2 == 0 else -1)


func _settle(k: Dictionary, g: String) -> void:
	var c: Node3D = k.c
	if k.slot < 0:
		c.rotation.y = B.yaw_to(k.face_wall)
		c.restart("Idle_Talking" if k.i % 3 == 0 else "Idle", 0.2, 1.0)
		return
	if g == "hidas":
		var dir: Vector3 = FLOOR_SLOTS[_mate_slot(k.slot)] - FLOOR_SLOTS[k.slot]
		c.rotation.y = B.yaw_to(dir)
	else:
		c.rotation.y = B.yaw_to(Vector3(DJ_AT.x * 0.3, 0, 6.0) - c.position) + _rng.randf_range(-0.4, 0.4)
	var sp: float = GENRES[g].speed if g != "" else 1.0
	c.restart("Dance" if g != "" else "Idle", 0.2, sp * _rng.randf_range(0.9, 1.1))


func _animate(delta: float) -> void:
	for k: Dictionary in _kids:
		if k.busy:
			k.t += delta / 1.4
			var c: Node3D = k.c
			c.position = (k.from as Vector3).lerp(k.to, clampf(k.t, 0.0, 1.0))
			if k.t >= 1.0:
				k.busy = false
				_settle(k, "" if _playing < 0 else String(KASETIT[_playing][1]))
	for c in _bubbles.keys():
		_bubbles[c][1] -= delta
		if _bubbles[c][1] <= 0.0:
			_bubbles.erase(c)
	# Peilipallo, valotäplät ja värivalot pyörivät; VU-mittari soivan biisin mukaan.
	var beat := 0.0
	if _phase == "soi":
		var g: String = KASETIT[_playing][1]
		var bpm := 128.0 if g in ["tekno", "dance"] else (72.0 if g == "hidas" else 150.0)
		beat = pow(maxf(0.0, cos(_t * bpm / 60.0 * TAU)), 6.0)
	if is_instance_valid(_ball):
		_ball.rotation.y += delta * 0.6
	for d: Array in _dots:
		var n: Node3D = d[0]
		d[1] += delta * 0.35
		n.position = Vector3(cos(d[1]) * d[2], d[3], -1.0 + sin(d[1]) * d[2] * 0.8)
		n.visible = _phase in ["soi", "alku", "loppu"]
	for i in _spots.size():
		var sp: SpotLight3D = _spots[i]
		sp.rotation.y = sin(_t * 0.7 + i * 1.7) * 0.6
		sp.light_energy = 5.0 + beat * 5.0 if _phase == "soi" else 2.0
	for i in _vu.size():
		var bar: Node3D = _vu[i]
		var lvl := 0.15 if _phase != "soi" else clampf(0.35 + beat * 0.6 + sin(_t * 9.0 + i) * 0.15, 0.1, 1.0)
		bar.scale.y = lvl
	if _dj != null and _phase == "soi":
		Room.nod(_dj, beat * 0.12)
	_shake = maxf(0.0, _shake - delta * 2.5)
	_flash_t = maxf(0.0, _flash_t - delta)
	MG.sparks_step(_sparks, delta)
	if _cam != null:
		_cam.transform = _cam_base.translated_local(Vector3(sin(_t * 40.0) * _shake * 0.03, 0, 0))


# --- Sali -----------------------------------------------------------------------------------------------------------

func _build() -> void:
	_room = Node3D.new()
	anchor.get_parent().add_child(_room)
	_room.top_level = true
	_room.global_transform = Transform3D(Basis(), anchor.global_position + Vector3(0, 250, 0))
	if sun != null:
		_sun_mask = sun.light_cull_mask
		sun.light_cull_mask = _sun_mask & ~Hall.LAYER
	_build_floor()
	_build_walls()
	_build_gym_gear()
	_build_decor()
	_build_dj()
	_build_people()
	_build_lights()
	_cam = Camera3D.new()
	_cam.fov = 52.0
	_cam.cull_mask = Hall.LAYER
	_cam.environment = _env
	_room.add_child(_cam)
	_frame_cam()
	_cam.current = true
	Room.set_layers(_room)


func _build_floor() -> void:
	var wood := Color(0.8, 0.6, 0.36)
	B.mesh(_room, B.boxm(Vector3(14, 0.1, 16)), Vector3(0, -0.05, -1), wood)
	for i in 28:  # parketin lautarivit
		var x := -6.75 + i * 0.5
		B.mesh(_room, B.boxm(Vector3(0.015, 0.004, 16)), Vector3(x, 0.002, -1), wood.darkened(0.18 + 0.06 * (i % 3)))
	for i in 32:  # lautojen päät porrastettuna
		var z := -8.75 + (i % 16) * 1.0
		var x := -6.5 + (i / 16) * 0.5 + (i % 4) * 3.0
		B.mesh(_room, B.boxm(Vector3(0.5, 0.004, 0.012)), Vector3(x, 0.002, z), wood.darkened(0.25))
	# Pelikenttä: punaiset rajat, keskiviiva ja -ympyrä, siniset korialueet.
	var red := Color(0.78, 0.16, 0.14)
	var blue := Color(0.15, 0.3, 0.65)
	for z in [-8.0, 5.0]:
		B.mesh(_room, B.boxm(Vector3(12.2, 0.006, 0.06)), Vector3(0, 0.004, z), red)
	for x in [-6.1, 6.1]:
		B.mesh(_room, B.boxm(Vector3(0.06, 0.006, 13.0)), Vector3(x, 0.004, -1.5), red)
	B.mesh(_room, B.boxm(Vector3(12.2, 0.006, 0.06)), Vector3(0, 0.004, -1.5), red)
	for a in 32:
		var th := a / 32.0 * TAU
		B.mesh(_room, B.boxm(Vector3(0.24, 0.006, 0.06)), Vector3(cos(th) * 1.6, 0.005, -1.5 + sin(th) * 1.6), red, Vector3(0, -th + PI / 2, 0))
	B.mesh(_room, B.boxm(Vector3(3.6, 0.005, 3.0)), Vector3(0, 0.003, -6.5), blue)  # korialue


func _build_walls() -> void:
	var low := Color(0.42, 0.55, 0.72)
	var up := Color(0.9, 0.86, 0.75)
	for sx in [-1.0, 1.0]:
		B.mesh(_room, B.boxm(Vector3(0.2, 1.3, 16)), Vector3(sx * 7.1, 0.65, -1), low)
		B.mesh(_room, B.boxm(Vector3(0.2, 4.9, 16)), Vector3(sx * 7.1, 3.75, -1), up)
		B.mesh(_room, B.boxm(Vector3(0.06, 0.08, 16)), Vector3(sx * 6.98, 1.3, -1), low.darkened(0.35))
	B.mesh(_room, B.boxm(Vector3(14.4, 1.3, 0.2)), Vector3(0, 0.65, -9.1), low)
	B.mesh(_room, B.boxm(Vector3(14.4, 4.9, 0.2)), Vector3(0, 3.75, -9.1), up)
	B.mesh(_room, B.boxm(Vector3(14.4, 0.08, 0.06)), Vector3(0, 1.3, -8.98), low.darkened(0.35))
	B.mesh(_room, B.boxm(Vector3(14.4, 0.2, 16.4)), Vector3(0, 6.3, -1), Color(0.75, 0.74, 0.7))  # katto
	for i in 5:  # kattopalkit
		B.mesh(_room, B.boxm(Vector3(14, 0.3, 0.25)), Vector3(0, 6.05, -8.0 + i * 3.2), Color(0.6, 0.58, 0.55))
	# Oikean seinän korkeat ikkunat: ilta, tummansininen taivas, valkoiset karmit.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.12, 0.18, 0.38)
	glass.emission_enabled = true
	glass.emission = Color(0.1, 0.16, 0.4)
	glass.emission_energy_multiplier = 0.6
	for z in [-7.0, -4.0, -1.0, 2.0]:
		var w := B.mesh(_room, B.boxm(Vector3(0.04, 1.3, 2.0)), Vector3(6.98, 4.6, z), Color.WHITE)
		w.material_override = glass
		B.mesh(_room, B.boxm(Vector3(0.05, 1.42, 0.08)), Vector3(6.96, 4.6, z - 1.0), Color(0.95, 0.95, 0.92))
		B.mesh(_room, B.boxm(Vector3(0.05, 1.42, 0.08)), Vector3(6.96, 4.6, z + 1.0), Color(0.95, 0.95, 0.92))
		B.mesh(_room, B.boxm(Vector3(0.05, 0.08, 2.08)), Vector3(6.96, 5.3, z), Color(0.95, 0.95, 0.92))
		B.mesh(_room, B.boxm(Vector3(0.05, 0.08, 2.08)), Vector3(6.96, 3.9, z), Color(0.95, 0.95, 0.92))
		B.mesh(_room, B.boxm(Vector3(0.05, 1.3, 0.05)), Vector3(6.96, 4.6, z), Color(0.95, 0.95, 0.92))
	# Ovi oikealla edessä (opettajan vieressä) ja ULOS-valo.
	B.mesh(_room, B.boxm(Vector3(0.08, 2.1, 1.0)), Vector3(6.97, 1.05, 4.8), Color(0.55, 0.38, 0.22))
	var exit := B.mesh(_room, B.boxm(Vector3(0.04, 0.18, 0.4)), Vector3(6.95, 2.35, 4.8), Color(0.2, 0.8, 0.3))
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.2, 0.8, 0.3)
	em.emission_enabled = true
	em.emission = Color(0.2, 0.9, 0.35)
	em.emission_energy_multiplier = 2.0
	exit.material_override = em


func _build_gym_gear() -> void:
	# Puolapuut vasemmalla seinällä: pystypuut ja pyöreät askelpuut.
	var pine := Color(0.86, 0.68, 0.42)
	for s in 6:
		var z0 := -7.0 + s * 1.0
		for zz in [z0, z0 + 0.9]:
			B.mesh(_room, B.boxm(Vector3(0.08, 4.2, 0.07)), Vector3(-6.92, 2.1, zz), pine.darkened(0.1))
		for r in 16:
			B.mesh(_room, B.cyl(0.022, 0.022, 0.9, 8), Vector3(-6.88, 0.25 + r * 0.25, z0 + 0.45), pine, Vector3(PI / 2, 0, 0))
	# Koripallokori takaseinällä: taulu, punainen neliö, rengas ja verkko.
	var hoop := Node3D.new()
	hoop.position = Vector3(0, 0, -8.85)
	_room.add_child(hoop)
	B.mesh(hoop, B.boxm(Vector3(0.12, 0.5, 0.6)), Vector3(0, 3.55, 0.25), Color(0.3, 0.3, 0.32))
	B.mesh(hoop, B.boxm(Vector3(1.8, 1.05, 0.05)), Vector3(0, 3.55, 0.55), Color(0.97, 0.97, 0.97))
	for e in [[Vector3(0.6, 0.04, 0.02), Vector3(0, 3.65, 0.585)], [Vector3(0.6, 0.04, 0.02), Vector3(0, 3.25, 0.585)],
			[Vector3(0.04, 0.44, 0.02), Vector3(-0.29, 3.45, 0.585)], [Vector3(0.04, 0.44, 0.02), Vector3(0.29, 3.45, 0.585)]]:
		B.mesh(hoop, B.boxm(e[0]), e[1], Color(0.85, 0.15, 0.1))
	for a in 16:
		var th := a / 16.0 * TAU
		B.mesh(hoop, B.boxm(Vector3(0.09, 0.025, 0.025)), Vector3(cos(th) * 0.23, 3.05, 0.85 + sin(th) * 0.23), Color(0.95, 0.4, 0.1), Vector3(0, -th + PI / 2, 0))
		B.mesh(hoop, B.cyl(0.004, 0.004, 0.42, 4), Vector3(cos(th) * 0.19, 2.84, 0.85 + sin(th) * 0.19), Color(0.95, 0.95, 0.95), Vector3(sin(th) * 0.12, 0, -cos(th) * 0.12))
	# Patjapino oikeassa takakulmassa.
	for i in 3:
		B.mesh(_room, B.boxm(Vector3(2.0, 0.24, 1.2)), Vector3(5.5, 0.12 + i * 0.25, -7.6 + i * 0.03), Color(0.2, 0.35, 0.7).lightened(i * 0.06))
		B.mesh(_room, B.boxm(Vector3(2.02, 0.03, 1.22)), Vector3(5.5, 0.245 + i * 0.25, -7.6 + i * 0.03), Color(0.12, 0.2, 0.45))
	# Penkki vasemmalla seinällä (seinäruusujen istuin).
	B.mesh(_room, B.boxm(Vector3(0.35, 0.05, 4.0)), Vector3(-6.6, 0.42, 0.5), pine)
	for z in [-1.3, 0.5, 2.3]:
		B.mesh(_room, B.boxm(Vector3(0.3, 0.42, 0.06)), Vector3(-6.6, 0.21, z), pine.darkened(0.2))


func _build_decor() -> void:
	# Banderolli takaseinällä (kangas, narut kulmissa).
	var ban := Node3D.new()
	ban.position = Vector3(-3.8, 4.3, -8.95)
	_room.add_child(ban)
	var plate := B.sign_plate(ban, "KOULUDISKO", Color(0.92, 0.2, 0.5), Color(1.0, 0.95, 0.4), 0.8, 96, Color(0.92, 0.2, 0.5), "Helvetica Neue")
	plate.position = Vector3(0, 0, 0.02)
	for sx in [-1.0, 1.0]:
		B.mesh(ban, B.cyl(0.008, 0.008, 0.6, 4), Vector3(sx * 2.4, 0.55, 0.02), Color(0.9, 0.9, 0.85), Vector3(0, 0, sx * 0.6))
	# Serpentiinit katosta: notkollaan roikkuvat kreppipaperiketjut.
	var cols := [Color(0.95, 0.25, 0.45), Color(0.25, 0.7, 0.95), Color(0.98, 0.85, 0.2), Color(0.5, 0.85, 0.3)]
	for s in 4:
		var a := Vector3(-6.8 if s < 2 else 6.8, 5.6, -8.0 + (s % 2) * 9.0)
		var b := Vector3(0, 5.4, -1.0)
		for i in 18:
			var t := (i + 0.5) / 18.0
			var p := a.lerp(b, t) + Vector3(0, -sin(t * PI) * 1.0, 0)
			B.mesh(_room, B.boxm(Vector3(0.22, 0.12, 0.03)), p, cols[(i + s) % 4], Vector3(0, atan2(b.x - a.x, b.z - a.z) + PI / 2, sin(i * 1.3) * 0.5))
	# Ilmapalloryppäät: takakulmat ja DJ-pöydän kulma, narut.
	for spot in [Vector3(-6.2, 0, -8.2), Vector3(6.2, 0, -5.5), Vector3(6.3, 0, 4.2)]:
		for i in 3:
			var off := Vector3(cos(i * 2.1) * 0.22, 2.0 + i * 0.18, sin(i * 2.1) * 0.22)
			var bm := B.mesh(_room, B.sphere(0.2, 12), spot + off, cols[(i + int(spot.x)) % 4])
			bm.scale = Vector3(1, 1.18, 1)
			var mm := StandardMaterial3D.new()
			mm.albedo_color = cols[(i + int(spot.x)) % 4]
			mm.roughness = 0.25
			mm.metallic_specular = 0.8
			bm.material_override = mm
			B.mesh(_room, B.cyl(0.004, 0.004, off.y - 0.2, 4), spot + Vector3(off.x * 0.5, (off.y - 0.2) / 2.0, off.z * 0.5), Color(0.9, 0.9, 0.9))


func _build_dj() -> void:
	# Taittopöytä: valkoinen levy, metallijalat, musta helma salin puolella.
	var t := Node3D.new()
	t.position = DJ_AT + DJ_FACE.normalized() * 0.75
	t.rotation.y = B.yaw_to(DJ_FACE)
	_room.add_child(t)
	B.mesh(t, B.boxm(Vector3(2.0, 0.05, 0.8)), Vector3(0, 0.76, 0), Color(0.94, 0.94, 0.92))
	for sx in [-0.92, 0.92]:
		for sz in [-0.34, 0.34]:
			B.mesh(t, B.cyl(0.02, 0.02, 0.74, 6), Vector3(sx, 0.37, sz), Color(0.6, 0.6, 0.63))
	B.mesh(t, B.boxm(Vector3(2.02, 0.6, 0.02)), Vector3(0, 0.46, -0.41), Color(0.08, 0.08, 0.1))
	# Tuplakasettideki (hopea runko, kasettiluukut kelat näkyvissä, näppäinrivi ja VU-mittari DJ:n puolella).
	var deck := Node3D.new()
	deck.position = Vector3(0.1, 0.79, 0.05)
	t.add_child(deck)
	# Dekki vinossa kameraa kohti (kamera DJ:n takana oikealla, _frame_cam): luukut ja VU-mittari näkyvät, ja DJ
	# käyttää sitä sivulta. Hieman oikeaa isompi, jotta yksityiskohdat erottuvat.
	var to_cam := Vector3(1.0, 0, 9.0) - t.position
	deck.rotation.y = B.yaw_to(-to_cam) - t.rotation.y
	deck.scale = Vector3.ONE * 1.3
	var silver := Color(0.75, 0.76, 0.8)
	B.mesh(deck, B.boxm(Vector3(0.9, 0.3, 0.26)), Vector3(0, 0.15, 0), silver)
	B.mesh(deck, B.boxm(Vector3(0.9, 0.02, 0.27)), Vector3(0, 0.3, 0), silver.lightened(0.25))
	B.mesh(deck, B.boxm(Vector3(0.6, 0.03, 0.03)), Vector3(0, 0.36, 0), Color(0.2, 0.2, 0.22))  # kahva
	for sx in [-0.29, 0.29]:
		B.mesh(deck, B.boxm(Vector3(0.03, 0.06, 0.03)), Vector3(sx, 0.33, 0), Color(0.2, 0.2, 0.22))
	for sx in [-0.22, 0.22]:  # kasettiluukut DJ:n puolella (+Z)
		B.mesh(deck, B.boxm(Vector3(0.3, 0.15, 0.01)), Vector3(sx, 0.16, 0.131), Color(0.1, 0.1, 0.12))
		for rx in [-0.06, 0.06]:
			B.mesh(deck, B.cyl(0.028, 0.028, 0.012, 10), Vector3(sx + rx, 0.17, 0.136), Color(0.9, 0.9, 0.88), Vector3(PI / 2, 0, 0))
	for i in 8:  # näppäimet
		B.mesh(deck, B.boxm(Vector3(0.045, 0.02, 0.04)), Vector3(-0.2 + i * 0.057, 0.31, 0.08), Color(0.2, 0.2, 0.22) if i % 3 else Color(0.85, 0.2, 0.15))
	for i in 10:  # VU-palkit (skaalataan tahtiin)
		var bar := Node3D.new()
		bar.position = Vector3(-0.09 + i * 0.02, 0.255, 0.132)
		deck.add_child(bar)
		var bm := B.mesh(bar, B.boxm(Vector3(0.014, 0.06, 0.004)), Vector3(0, 0.03, 0), Color.WHITE)
		var vm := StandardMaterial3D.new()
		var vc := Color(0.3, 1.0, 0.35) if i < 7 else Color(1.0, 0.3, 0.2)
		vm.albedo_color = vc
		vm.emission_enabled = true
		vm.emission = vc
		vm.emission_energy_multiplier = 2.0
		bm.material_override = vm
		_vu.append(bar)
	# Kasettipino ja avoin kotelo.
	for i in 5:
		B.mesh(t, B.boxm(Vector3(0.11, 0.018, 0.07)), Vector3(-0.7, 0.79 + i * 0.019, 0.1), Color(0.15, 0.15, 0.17))
		B.mesh(t, B.boxm(Vector3(0.112, 0.006, 0.05)), Vector3(-0.7, 0.8 + i * 0.019, 0.1), SHIRTS[i])
	# Kaiuttimet jalustoilla salin puolelle päin.
	for sx in [-1.25, 1.25]:
		var sp := Node3D.new()
		sp.position = Vector3(sx, 0, -0.2)
		t.add_child(sp)
		B.mesh(sp, B.cyl(0.02, 0.02, 1.2, 6), Vector3(0, 0.6, 0), Color(0.2, 0.2, 0.22))
		B.mesh(sp, B.boxm(Vector3(0.42, 0.62, 0.36)), Vector3(0, 1.5, 0), Color(0.1, 0.1, 0.11))
		B.mesh(sp, B.cyl(0.13, 0.13, 0.02, 16), Vector3(0, 1.58, -0.18), Color(0.25, 0.25, 0.27), Vector3(PI / 2, 0, 0))
		B.mesh(sp, B.cyl(0.05, 0.05, 0.02, 12), Vector3(0, 1.3, -0.18), Color(0.25, 0.25, 0.27), Vector3(PI / 2, 0, 0))
	# Pöytälamppu: lämmin valo DJ:n käsiin.
	B.mesh(t, B.cyl(0.06, 0.08, 0.02, 10), Vector3(0.8, 0.79, 0.2), Color(0.2, 0.2, 0.22))
	B.mesh(t, B.cyl(0.01, 0.01, 0.3, 6), Vector3(0.8, 0.94, 0.2), Color(0.2, 0.2, 0.22))
	B.mesh(t, B.cyl(0.03, 0.08, 0.1, 10), Vector3(0.75, 1.1, 0.22), Color(0.9, 0.2, 0.15))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.55)
	lamp.light_energy = 1.4
	lamp.omni_range = 2.2
	lamp.position = Vector3(0.5, 1.2, 0.5)
	t.add_child(lamp)


func _build_people() -> void:
	_dj = Room.stand(_room, player_look if not player_look.is_empty() else Looks.PLAYER, DJ_AT, DJ_FACE, "Idle")
	_teacher = Room.stand(_room, TEACHER_LOOK, TEACHER_AT, Vector3(-0.8, 0, -0.6), "Idle")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in KIDS:
		var girl := i % 2 == 1
		var look := {"height": rng.randf_range(1.36, 1.58), "bulk": -0.35, "shoulders": -0.45, "muscle": -1.0,
			"hair": (["Hair_Long", "Hair_Buns"] if girl else ["Hair_Buzzed", "Hair_SimpleParted"])[rng.randi() % 2],
			"hair_color": HAIRS[rng.randi() % HAIRS.size()], "shirt": SHIRTS[(i * 3) % SHIRTS.size()],
			"pants": [Color(0.2, 0.3, 0.55), Color(0.1, 0.1, 0.12), Color(0.3, 0.35, 0.6)][rng.randi() % 3],
			"shoes": Color(0.95, 0.95, 0.93), "shoe": "lenkkari", "skin": Color(1.0, 0.9, 0.84).darkened(rng.randf() * 0.05)}
		if girl and rng.randf() < 0.4:
			look["skirt"] = [Color(0.15, 0.15, 0.2), Color(0.55, 0.2, 0.45)][rng.randi() % 2]
		# Seinäpaikat: puolet vasemmalla penkin luona, puolet oikealla ikkunoiden alla.
		var left := i % 2 == 0
		var wall := Vector3(-5.9 if left else 5.9, 0, -3.4 + (i / 2) * 1.15)
		var face := Vector3(1 if left else -1, 0, 0)
		var c := Room.stand(_room, look, wall, face, "Idle")
		_kids.append({"c": c, "i": i, "wall": wall, "face_wall": face, "slot": -1, "from": wall, "to": wall, "t": 1.0, "busy": false})
	# Alussa kolme rohkeinta lattialla valmiiksi.
	for j in 3:
		var k: Dictionary = _kids[j * 4]
		k.slot = [5, 6, 9][j]
		(k.c as Node3D).position = FLOOR_SLOTS[k.slot]
	_floor = 3
	_restyle()


func _build_lights() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.03, 0.03, 0.06)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.5, 0.45, 0.7)
	_env.ambient_light_energy = 0.9
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	# Peilipallo: hopeinen pallo ja peilipalat, naru kattoon.
	_ball = Node3D.new()
	_ball.position = Vector3(0.4, 4.1, -0.6)
	_room.add_child(_ball)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.85, 0.87, 0.92)
	bm.metallic = 0.5
	bm.roughness = 0.3
	bm.emission_enabled = true
	bm.emission = Color(0.35, 0.37, 0.45)
	var core := B.mesh(_ball, B.sphere(0.34, 16), Vector3.ZERO, Color.WHITE)
	core.material_override = bm
	for lat in 6:
		var phi := -1.2 + lat * 0.48
		for lon in 10:
			var th := lon / 10.0 * TAU + lat * 0.3
			var n := Vector3(cos(phi) * cos(th), sin(phi), cos(phi) * sin(th))
			var tile := B.mesh(_ball, B.boxm(Vector3(0.09, 0.09, 0.012)), n * 0.345, Color.WHITE)
			tile.look_at_from_position(n * 0.345, n * 2.0, Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT)
			var tm := StandardMaterial3D.new()
			tm.albedo_color = Color(0.85, 0.88, 0.95)
			tm.metallic = 0.6
			tm.roughness = 0.1
			tm.emission_enabled = true
			tm.emission = Color(1.0, 1.0, 1.0) if (lat + lon) % 3 == 0 else Color(0.45, 0.47, 0.55)
			tm.emission_energy_multiplier = 1.5 if (lat + lon) % 3 == 0 else 0.6
			tile.material_override = tm
	B.mesh(_room, B.cyl(0.008, 0.008, 1.8, 4), Vector3(0.4, 5.1, -0.6), Color(0.3, 0.3, 0.3))
	var ball_light := OmniLight3D.new()
	ball_light.light_color = Color(0.85, 0.85, 1.0)
	ball_light.light_energy = 0.8
	ball_light.omni_range = 4.0
	ball_light.position = Vector3(0.4, 3.6, -0.6)
	_room.add_child(ball_light)
	# Valotäplät lattialla ja seinillä (peilipallon heijastukset).
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(1, 1, 1)
	dm.emission_enabled = true
	dm.emission = Color(1.0, 0.98, 0.9)
	dm.emission_energy_multiplier = 2.5
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 22:
		var dot := B.mesh(_room, B.cyl(0.07, 0.07, 0.004, 8), Vector3.ZERO, Color.WHITE)
		dot.material_override = dm
		_dots.append([dot, i * 0.9, 1.0 + (i % 6) * 0.9, 0.006])
	# Värivalot salin etukulmissa ja takaseinällä, pyyhkivät lattiaa.
	var colors := [Color(1.0, 0.2, 0.6), Color(0.2, 0.7, 1.0), Color(1.0, 0.85, 0.2), Color(0.4, 1.0, 0.4)]
	var at := [Vector3(-6.0, 5.2, 5.5), Vector3(6.0, 5.2, 5.5), Vector3(-5.5, 5.2, -8.0), Vector3(5.5, 5.2, -8.0)]
	for i in 4:
		var holder := Node3D.new()
		holder.position = at[i]
		_room.add_child(holder)
		var sp := SpotLight3D.new()
		sp.light_color = colors[i]
		sp.light_energy = 5.0
		sp.spot_range = 16.0
		sp.spot_angle = 20.0
		holder.add_child(sp)
		holder.rotation.y = B.yaw_to(Vector3(0, 0, -0.5) - at[i])  # perussuunta salin keskelle, valo pyyhkii sen ympäri
		sp.rotation.x = -0.75
		B.mesh(holder, B.cyl(0.08, 0.12, 0.22, 10), Vector3.ZERO, Color(0.15, 0.15, 0.17))
		_spots.append(sp)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.88, 0.75)
	fill.light_energy = 1.6
	fill.omni_range = 14.0
	fill.position = Vector3(0, 5.0, 1.0)
	_room.add_child(fill)
	# Kasvovalo kameran suunnasta (DJ:n takaa): lasten kasvot eivät jää värivalojen varjoon.
	var face := OmniLight3D.new()
	face.light_color = Color(1.0, 0.92, 0.82)
	face.light_energy = 1.2
	face.omni_range = 16.0
	face.position = Vector3(0.5, 3.2, 7.5)
	_room.add_child(face)


## Kamera DJ:n olan yli: lattian lapset ruudun keskelle ja isoiksi, DJ ja kasettideki vasempaan alakulmaan (ei peitä
## lattiaa), kasettivalinta oikeaan alakulmaan. Etäisyys ja suunta valitaan projisoimalla: kaikkien lattiapaikkojen
## lapset (jalat ja pää) ruudun 12–88 % leveydelle ja 18–74 % korkeudelle, DJ:n pää vasemmalle alas.
func _frame_cam() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aim := Vector3(-0.3, 0.8, 0.5)
	var best := Transform3D()
	var found := false
	for side in [1.2, 0.6, 0.0, 1.8]:
		var dir := (Vector3(side, 2.6, 8.0)).normalized()
		for i in 40:
			var d := 6.0 + i * 0.2
			var eye := aim + dir * d
			_cam.transform = Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye)
			var ok := true
			for slot: Vector3 in FLOOR_SLOTS:
				for hgt in [0.0, 1.6]:
					var p := _cam.unproject_position(_room.to_global(slot + Vector3(0, hgt, 0)))
					if p.x < vs.x * 0.12 or p.x > vs.x * 0.88 or p.y < vs.y * 0.18 or p.y > vs.y * 0.74:
						ok = false
			var head := _cam.unproject_position(_room.to_global(DJ_AT + Vector3(0, 1.7, 0)))
			if ok and head.x > vs.x * 0.02 and head.x < vs.x * 0.3 and head.y > vs.y * 0.45:
				best = _cam.transform
				found = true
				break
		if found:
			break
	if not found:
		var eye := aim + Vector3(1.2, 2.6, 8.0).normalized() * 11.0
		best = Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye)
	_cam.transform = best
	_cam_base = best


# --- Käyttöliittymä -----------------------------------------------------------------------------------------------

func _update_keys() -> void:
	match _phase:
		"alku":
			_keys.set_text("%s valitse kasetti   %s soimaan   %s lopeta" % [Settings.pair("left", "right"), Settings.cap("interact"), Settings.cap("mount")])
		"soi", "tauko":
			_keys.set_text("%s valitse seuraava   %s miksaa (neula vihreällä)   %s lopeta" % [Settings.pair("left", "right"), Settings.cap("interact"), Settings.cap("mount")])
		_:
			_keys.set_text("%s jatka" % Settings.cap("interact"))


func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	var k := vs.y / 720.0
	# Puhekuplat puhujien päiden yläpuolelle.
	for c in _bubbles.keys():
		if is_instance_valid(c):
			Room.bubble(_ui, _cam, c, _bubbles[c][0], 150.0 * k, 230.0 * k)
	# Ylävasen: disko ja soiva kasetti.
	var tl := Rect2(16 * k, 14 * k, 360 * k, 104 * k)
	Room.box(_ui, tl)
	_ui.draw_string(font, tl.position + Vector2(14, 26) * k, "KOULUDISKO  ·  biisi %d/%d" % [mini(_round, ROUNDS), ROUNDS],
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k), Color(1.0, 0.9, 0.5))
	if _playing >= 0 and _phase in ["soi", "tauko"]:
		var kk: Array = KASETIT[_playing]
		_cassette(Rect2(tl.position + Vector2(12, 38) * k, Vector2(84, 54) * k), kk, false, true, k)
		_ui.draw_string(font, tl.position + Vector2(108, 58) * k, kk[0], HORIZONTAL_ALIGNMENT_LEFT, 240 * k, int(17 * k), Color.WHITE)
		_tag(Rect2(tl.position + Vector2(108, 66) * k, Vector2(74, 20) * k), kk[1], k)
		var prog := clampf(_t / SEG, 0.0, 1.0) if _phase == "soi" else 1.0
		var pb := Rect2(tl.position + Vector2(190, 70) * k, Vector2(156, 12) * k)
		_ui.draw_rect(pb, Color(0.2, 0.2, 0.24))
		_ui.draw_rect(Rect2(pb.position, Vector2(pb.size.x * prog, pb.size.y)), GENRES[kk[1]].col)
		_ui.draw_rect(pb, Color(1, 1, 1, 0.3), false, 1.0)
	elif _phase == "tauko":
		_ui.draw_string(font, tl.position + Vector2(14, 70) * k, "Hiljaista...", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * k), Color(1, 0.5, 0.4))
	elif _phase == "loppu":
		_ui.draw_string(font, tl.position + Vector2(14, 70) * k, "Disko loppui. Valot päälle!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * k), Color(0.9, 0.9, 0.95))
	else:
		_ui.draw_string(font, tl.position + Vector2(14, 70) * k, "Valitse ensimmäinen kasetti.", HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * k), Color(0.9, 0.9, 0.95))
	# Yläoikea: tanssilattiamittari (lapsikuvakkeet) ja toiveet.
	var tr := Rect2(vs.x - 376 * k, 14 * k, 360 * k, 104 * k)
	Room.box(_ui, tr)
	_ui.draw_string(font, tr.position + Vector2(14, 26) * k, "Tanssilattia %d/%d" % [_floor, KIDS], HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k), Color(1.0, 0.9, 0.5))
	for i in KIDS:
		var p := tr.position + Vector2(22 + i * 27, 44) * k
		var on := i < _floor
		var col := Color(0.4, 1.0, 0.55) if on else Color(0.35, 0.35, 0.4)
		_ui.draw_circle(p + Vector2(0, 6) * k, 6 * k, col)
		_ui.draw_rect(Rect2(p + Vector2(-6, 13) * k, Vector2(12, 14) * k), col)
		if on:
			_ui.draw_line(p + Vector2(-6, 15) * k, p + Vector2(-11, 8) * k, col, 2.5 * k)  # kädet ylhäällä
			_ui.draw_line(p + Vector2(6, 15) * k, p + Vector2(11, 8) * k, col, 2.5 * k)
	var wl: Array = []
	for g in ["tekno", "dance", "hidas", "polkka"]:
		if int(_wants.get(g, 0)) > 0:
			wl.append("%s ×%d" % [GENRES[g].name, _wants[g]])
	_ui.draw_string(font, tr.position + Vector2(14, 94) * k, "Toiveet: " + (", ".join(wl) if not wl.is_empty() else "–"),
		HORIZONTAL_ALIGNMENT_LEFT, 330 * k, int(15 * k), Color(0.85, 0.85, 0.9))
	# Oikea alakulma: kolme kasettia, valittu nostettuna.
	if _phase in ["alku", "soi", "tauko"]:
		var cw := 150.0 * k
		var ch := 96.0 * k
		var x0 := vs.x - (cw * 3 + 24 * k * 2) - 24 * k
		var y0 := vs.y - ch - 66 * k
		_ui.draw_string(font, Vector2(x0, y0 - 26 * k), "Seuraava kasetti" if _phase != "alku" else "Ensimmäinen kasetti",
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * k), Color(1, 1, 1, 0.85))
		for i in _offer.size():
			var r := Rect2(x0 + i * (cw + 24 * k), y0 - (12 * k if i == _sel else 0.0), cw, ch)
			_cassette(r, KASETIT[_offer[i]], i == _sel, false, k)
		# Miksauspalkki kasettien yläpuolella biisin lopussa.
		if _phase == "soi" and SEG - _t <= MIX_BAR:
			var mb := Rect2(x0, y0 - 64 * k, cw * 3 + 48 * k, 22 * k)
			_ui.draw_rect(mb, Color(0.12, 0.1, 0.1, 0.9))
			var gx := mb.position.x + mb.size.x * (1.0 - MIX_WIN / MIX_BAR)
			_ui.draw_rect(Rect2(gx, mb.position.y, mb.end.x - gx, mb.size.y), Color(0.25, 0.8, 0.35))
			var nx := mb.position.x + mb.size.x * clampf(1.0 - (SEG - _t) / MIX_BAR, 0.0, 1.0)
			_ui.draw_line(Vector2(nx, mb.position.y - 6 * k), Vector2(nx, mb.end.y + 6 * k), Color.WHITE, 4 * k)
			_ui.draw_rect(mb, Color(1, 1, 1, 0.5), false, 1.5)
			_ui.draw_string(font, mb.position + Vector2(0, -8 * k), "MIKSAA %s" % Settings.cap("interact"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * k),
				Color(0.5, 1.0, 0.6) if nx >= gx else Color(1, 1, 1))
	# Palaute miksauksesta ruudun keskellä.
	if _flash_t > 0.0:
		var a := clampf(_flash_t / 0.4, 0.0, 1.0)
		var fs := int(34 * k)
		var tw := font.get_string_size(_flash, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_ui.draw_string_outline(font, Vector2((vs.x - tw) / 2.0, vs.y * 0.3), _flash, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(8 * k), Color(0, 0, 0, a * 0.8))
		_ui.draw_string(font, Vector2((vs.x - tw) / 2.0, vs.y * 0.3), _flash, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(_flash_col, a))
	MG.sparks_draw(_ui, _sparks)
	# Kerronta: alussa ohje, lopussa tulos.
	if _story != "" and _phase == "alku":
		var sr := Rect2(vs.x / 2.0 - 240 * k, 14 * k, 480 * k, 104 * k)
		Room.box(_ui, sr)
		_ui.draw_multiline_string(font, sr.position + Vector2(14, 28) * k, _story, HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 28 * k, int(17 * k), 4, Color.WHITE)
	if _phase == "loppu" and not _result.is_empty():
		var rr := Rect2(vs.x / 2.0 - 260 * k, vs.y / 2.0 - 120 * k, 520 * k, 230 * k)
		Room.box(_ui, rr, Color(0.05, 0.04, 0.08, 0.9))
		_ui.draw_string(font, rr.position + Vector2(0, 44) * k, "DISKO LOPPUI", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, int(26 * k), Color(1.0, 0.9, 0.5))
		_ui.draw_string(font, rr.position + Vector2(0, 92) * k, "\"%s\"" % _result.title, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, int(32 * k),
			Color(0.5, 1.0, 0.6) if int(_result.rep) > 0 else Color(1.0, 0.7, 0.4))
		_ui.draw_string(font, rr.position + Vector2(0, 134) * k, "Tanssilattia keskimäärin %.1f/%d  ·  maine %+d" % [_result.lattia, KIDS, _result.rep],
			HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, int(18 * k), Color.WHITE)
		var ope := "Opettaja sai polkkansa." if _result.opettaja == true else ("Opettaja jäi ilman polkkaa." if _result.opettaja == false else "")
		_ui.draw_string(font, rr.position + Vector2(0, 166) * k, ope, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, int(16 * k), Color(0.85, 0.85, 0.9))


## Tyylimerkki (värillinen lappu).
func _tag(r: Rect2, g: String, k: float) -> void:
	MG.box(_ui, r, GENRES[g].col, int(6 * k), 0, Color(0, 0, 0, 0.5), 1)
	_ui.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + r.size.y * 0.75), GENRES[g].name,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(13 * k), Color(0.08, 0.06, 0.05))


## C-kasetti: tumma kuori, vaalea etiketti tyylivärin raidalla, ikkuna ja kelat (pyörivät soidessa), ruuvit ja
## nauhan ohjain alareunassa. Valittu kasetti hehkuu tyylin värillä.
func _cassette(r: Rect2, kk: Array, selected: bool, spinning: bool, k: float) -> void:
	var col: Color = GENRES[kk[1]].col
	var font := ThemeDB.fallback_font
	if selected:
		MG.box(_ui, r.grow(5 * k), Color(col, 0.35), int(14 * k))
	_ui.draw_rect(Rect2(r.position + Vector2(4, 5) * k, r.size), Color(0, 0, 0, 0.35))  # varjo
	MG.box(_ui, r, Color(0.16, 0.16, 0.18), int(8 * k), 0, MG.OUTLINE, 2)
	_ui.draw_line(r.position + Vector2(8, 3) * k, Vector2(r.end.x - 8 * k, r.position.y + 3 * k), Color(1, 1, 1, 0.25), 2.0)
	var lab := Rect2(r.position + Vector2(r.size.x * 0.07, r.size.y * 0.1), Vector2(r.size.x * 0.86, r.size.y * 0.56))
	_ui.draw_rect(lab, Color(0.97, 0.95, 0.88))
	_ui.draw_rect(Rect2(lab.position, Vector2(lab.size.x, lab.size.y * 0.24)), col)
	_ui.draw_string(font, lab.position + Vector2(4 * k, lab.size.y * 0.2), GENRES[kk[1]].name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
		lab.size.x - 8 * k, int(maxf(9.0, r.size.y * 0.11)), Color(0.08, 0.06, 0.05))
	_ui.draw_string(font, lab.position + Vector2(4 * k, lab.size.y * 0.47), kk[0], HORIZONTAL_ALIGNMENT_CENTER, lab.size.x - 8 * k,
		int(maxf(9.0, r.size.y * 0.13)), Color(0.15, 0.12, 0.3))
	# Ikkuna ja kelat.
	var win := Rect2(lab.position + Vector2(lab.size.x * 0.22, lab.size.y * 0.58), Vector2(lab.size.x * 0.56, lab.size.y * 0.36))
	MG.box(_ui, win, Color(0.12, 0.1, 0.1), int(4 * k))
	var rr := win.size.y * 0.36
	for side in [0.25, 0.75]:
		var c := Vector2(win.position.x + win.size.x * side, win.position.y + win.size.y * 0.5)
		_ui.draw_circle(c, rr, Color(0.92, 0.92, 0.9))
		var ang := _t * 5.0 if spinning else 0.0
		for s in 6:
			var a := ang + s * TAU / 6.0
			_ui.draw_line(c + Vector2(cos(a), sin(a)) * rr * 0.35, c + Vector2(cos(a), sin(a)) * rr * 0.9, Color(0.35, 0.35, 0.38), maxf(1.0, 1.5 * k))
		_ui.draw_circle(c, rr * 0.3, Color(0.25, 0.25, 0.28))
	_ui.draw_line(Vector2(win.position.x + win.size.x * 0.25, win.end.y - 2), Vector2(win.position.x + win.size.x * 0.75, win.end.y - 2), Color(0.35, 0.22, 0.12), maxf(1.0, 2 * k))
	# Ruuvit ja alareunan nauhanohjain.
	for p: Vector2 in [Vector2(0.05, 0.08), Vector2(0.95, 0.08), Vector2(0.05, 0.92), Vector2(0.95, 0.92), Vector2(0.5, 0.9)]:
		var sp := r.position + r.size * p
		_ui.draw_circle(sp, maxf(1.5, 2.6 * k), Color(0.55, 0.55, 0.58))
		_ui.draw_line(sp - Vector2(1.6, 0) * k, sp + Vector2(1.6, 0) * k, Color(0.2, 0.2, 0.22), 1.0)
	var guide := PackedVector2Array([Vector2(r.position.x + r.size.x * 0.22, r.end.y), Vector2(r.position.x + r.size.x * 0.28, r.end.y - r.size.y * 0.16),
		Vector2(r.position.x + r.size.x * 0.72, r.end.y - r.size.y * 0.16), Vector2(r.position.x + r.size.x * 0.78, r.end.y)])
	_ui.draw_colored_polygon(guide, Color(0.24, 0.24, 0.27))
	if selected:
		_ui.draw_rect(r.grow(2 * k), col, false, 3.0 * k)
