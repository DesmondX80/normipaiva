extends CanvasLayer
## Sivikki-disko Katjan pihalla Vaalassa (kolmiomittauksen iltakiva, K-18 ja vähän rivo): Timon punainen Civic
## pihassa ovet auki, ajovalot tanssipaikalle ja sininen pohjavalo, stereoista 90-luvun tanssibiisi. Pelaaja, Tero ja
## Timo tanssivat Katjan edessä, ja Katja valitsee parhaan tanssijan hitaille.
## Mekaniikka: liikkeet tulevat neljällä kaistalla biisin tahdissa (tempo ja ensimmäinen isku mitattu biisistä,
## BIISIT), ja näppäin painetaan, kun liike osuu viivaan: vasen ja oikea = lantio, eteen = kädet ilmaan, taakse =
## pyllistys (hahmo kääntyy ja pyllistää kameraan). Osuma näkyy hahmon liikkeenä ja valojen sykkeenä.
## Piha rakennetaan omaksi lavasteekseen talon yläpuolelle (rasvanappi_hall.gd:n kerros LAYER): nurmi, asfaltti,
## rivitalon seinä ikkunoineen, pihavalo ja Civic (vehicles.gd). Ruudulla vain käyttöliittymä.

signal finished(result: Dictionary)

const Room := preload("res://scripts/ilta_room.gd")
const Hall := preload("res://scripts/rasvanappi_hall.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const PariOte := preload("res://scripts/pari_ote.gd")
const Contact := preload("res://scripts/contact.gd")
const Pose := preload("res://scripts/pose.gd")

## Biisit (assets/music/kuulokkeet, CC BY): [polku, BPM, ensimmäisen iskun aika s, aloituskohta s]. Tempo ja vaihe
## mitattu iskuenergiasta 30 s jaksoissa (vakaat jaksot 30–120 s), ks. docs/kehitys.md.
const BIISIT := [
	["res://assets/music/kuulokkeet/06_Dance_and_Jump.ogg", 130.0, 0.165, 32.0],
	["res://assets/music/kuulokkeet/02_90s_Racer_Techno.mp3", 140.0, 0.345, 32.0],
	["res://assets/music/kuulokkeet/01_Robotertanz.mp3", 140.0, 0.369, 32.0],
]
const LANES := ["left", "back", "forward", "right"]  # kaistat vasemmalta oikealle
const LANE_NAMES := ["Lantio", "Pyllistys", "Kädet ylös", "Lantio"]
const PERFECT := 0.09
const GOOD := 0.18
const KISA_ISKUT := 96  # liikkeitä noin 45 s
const LEAD := 1.6  # sekuntia, jonka liike näkyy kaistalla ennen viivaa
const CENTER := Vector3(0.0, 0.0, 0.0)
const DANCERS := [Vector3(0.0, 0, 1.0), Vector3(-1.45, 0, 0.35), Vector3(1.45, 0, 0.35), Vector3(0.0, 0, -0.75)]
const CIVIC_AT := Vector3(-3.3, 0.0, -1.6)

var site := "vaala"
var anchor: Node3D
var sun: DirectionalLight3D
var style := {}
var people: Array = []  # [pelaaja, Tero, Timo, Katja]
var lines := {}
var auto := false
## Legendaarinen hetki "sivikkidisko" (main.gd _kolmio_ilta: ensimmäinen voitto, lines.legenda): viimeinen biisi ja
## bassodroppi, Katja hakee voittajan parikseen, Sivikin akku hyytyy kesken ja koko piha laulaa biisin loppuun pimeässä.
## recall: hetki on jo koettu, joku muistelee illan alussa.
var legend := false
var recall := false
const LEG := ["droppi", "pari", "sammuu", "laulu", "otsikko"]

var _room: Node3D
var _env: Environment
var _cam: Camera3D
var _cam_base: Transform3D
var _chars: Array = []
var _music: AudioStreamPlayer
var _bpm := 130.0
var _first := 0.0
var _start_at := 32.0
var _k0 := 0  # biisin iskun numero, josta pelin isku 0 alkaa (ensimmäinen isku aloituskohdan jälkeen)
var _notes: Array = []  # {"beat": float, "lane": int, "hit": bool, "miss": bool}
var _score := [0, 0, 0]  # pelaaja, Tero, Timo
var _combo := 0
var _judge := ""
var _judge_t := 0.0
var _judge_lane := 0
var _moves: Array = [{}, {}, {}, {}]  # hahmo -> {"kind", "t"} käynnissä oleva liike
var _glow: OmniLight3D
var _heads: Array = []  # ajovalojen spotit
var _bubbles: Array = ["", "", "", ""]
var _bubble_t := [0.0, 0.0, 0.0, 0.0]
var _phase := "alku"
var _t := 0.0
var _song_t := 0.0
var _story := ""
var _ui: Control
var _keys: Node
var _shake := 0.0
var _sun_mask := 0
var _last_beat := -1
var _rng := RandomNumberGenerator.new()
var _fade_tw: Tween
var _civic: Node3D
var _speaker_cone: Node3D
var _yard: OmniLight3D
var _lamps: Array = []  # Civicin ajovalolasit [mesh, alkuperäinen materiaali]
var _lit := 1.0  # Sivikin sähköt 1 = päällä, 0 = akku loppu
var _strobe := 0.0
var _pump := 0.0
var _once := {}
var _walk: Dictionary = {}  # hahmo -> [mistä, mihin, aika, kesto]
var _hold_w := 0.0
var _prof := {}
var _notes_fx: Array = []  # laulun nuotit: [hahmo-indeksi, ikä, sivuheitto]
var _singers: Array = []
var _cam_from: Transform3D
var _cam_to: Transform3D
var _cam_glide := -1.0


func _ready() -> void:
	layer = 6
	add_to_group("esc_lopettaa")
	_rng.randomize()
	var b: Array = BIISIT[_rng.randi() % BIISIT.size()]
	_bpm = b[1]
	_first = b[2]
	_start_at = b[3]
	_k0 = ceili((_start_at - _first) * _bpm / 60.0)
	_build()
	_make_notes()
	_music = AudioStreamPlayer.new()
	_music.stream = load(b[0])
	_music.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	_music.volume_db = -2.0
	add_child(_music)
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
	_story = "Sivikki-disko! Paina liike, kun se osuu viivaan. Katja valitsee parhaan tanssijan hitaille."
	if recall and lines.has("muisto"):
		var m: Array = (lines.muisto as Array).pick_random()
		_say(int(m[0]), String(m[1]))
		_bubble_t[int(m[0])] = 5.0
	else:
		_say(2, _line("alku", "Ovet auki ja bassot kaakkoon!"))


func _exit_tree() -> void:
	if sun != null and is_instance_valid(sun):
		sun.light_cull_mask = _sun_mask
	if is_instance_valid(_room):
		_room.queue_free()


# --- Piha ---------------------------------------------------------------------------------------------------------

func _build() -> void:
	_room = Node3D.new()
	anchor.get_parent().add_child(_room)
	_room.top_level = true
	_room.global_transform = Transform3D(Basis(), anchor.global_position + Vector3(0, 250, 12.0))
	if sun != null:
		_sun_mask = sun.light_cull_mask
		sun.light_cull_mask = _sun_mask & ~Hall.LAYER
	# Nurmi ja asfalttipiha, nurmella tuppaita.
	B.mesh(_room, B.boxm(Vector3(16, 0.1, 12)), Vector3(0, -0.05, 1.0), Color(0.18, 0.32, 0.14))
	B.mesh(_room, B.boxm(Vector3(4.2, 0.02, 7)), Vector3(-3.4, 0.0, 0.0), Color(0.22, 0.22, 0.24))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 70:
		var p := Vector3(rng.randf_range(-1.0, 7.0), 0.03, rng.randf_range(-2.2, 5.0))
		B.mesh(_room, B.cyl(0.0, 0.035, 0.07, 5), p, Color(0.22, 0.4, 0.16).darkened(rng.randf() * 0.3))
	# Rivitalon seinä taustalla: vaalea lautaverhous, valaistut ikkunat, ovi ja räystäs.
	var wall := Color(0.86, 0.8, 0.62)
	B.mesh(_room, B.boxm(Vector3(14, 3.0, 0.2)), Vector3(0, 1.5, -3.2), wall)
	for i in 28:
		B.mesh(_room, B.boxm(Vector3(14, 0.012, 0.02)), Vector3(0, 0.1 + i * 0.105, -3.09), wall.darkened(0.18))
	B.mesh(_room, B.boxm(Vector3(14.6, 0.12, 0.9)), Vector3(0, 3.05, -2.9), Color(0.3, 0.18, 0.12))
	for x: float in [-5.0, -1.6, 1.8, 5.2]:
		var win := B.mesh(_room, B.boxm(Vector3(1.1, 0.9, 0.04)), Vector3(x, 1.55, -3.08), Color(1.0, 0.85, 0.5))
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(1.0, 0.85, 0.5)
		wm.emission_enabled = true
		wm.emission = Color(1.0, 0.75, 0.4)
		wm.emission_energy_multiplier = 1.2
		win.material_override = wm
		B.mesh(_room, B.boxm(Vector3(1.22, 1.02, 0.03)), Vector3(x, 1.55, -3.1), Color(0.95, 0.95, 0.92))
		B.mesh(_room, B.boxm(Vector3(0.04, 0.9, 0.05)), Vector3(x, 1.55, -3.05), Color(0.95, 0.95, 0.92))
	B.mesh(_room, B.boxm(Vector3(0.9, 2.0, 0.06)), Vector3(3.5, 1.0, -3.08), Color(0.45, 0.28, 0.16))  # Katjan ovi
	B.mesh(_room, B.boxm(Vector3(0.06, 0.06, 0.08)), Vector3(3.2, 1.0, -3.02), Color(0.8, 0.75, 0.6))
	# Pihavalo tolpassa.
	B.mesh(_room, B.cyl(0.04, 0.05, 3.0, 8), Vector3(5.5, 1.5, 0.0), Color(0.2, 0.2, 0.22))
	var lamp_m := B.mesh(_room, B.sphere(0.16, 12), Vector3(5.5, 3.05, 0.0), Color(1, 0.9, 0.7))
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1, 0.9, 0.7)
	lm.emission_enabled = true
	lm.emission = Color(1, 0.85, 0.55)
	lm.emission_energy_multiplier = 3.0
	lamp_m.material_override = lm
	var yard := OmniLight3D.new()
	_yard = yard
	yard.light_color = Color(1.0, 0.82, 0.55)
	yard.light_energy = 1.6
	yard.omni_range = 9.0
	yard.position = Vector3(5.5, 2.9, 0.0)
	_room.add_child(yard)
	# Timon Civic vinosti pihassa keula tanssijoihin, ajovalot ja pohjavalo.
	var civic := Node3D.new()
	_room.add_child(civic)
	Vehicles.civic(civic, Color(0.72, 0.04, 0.07), "VTC-916")
	civic.position = CIVIC_AT
	civic.rotation.y = B.yaw_to(Vector3(0.0, 0, 0.6) - CIVIC_AT)
	_civic = civic
	for mi: MeshInstance3D in civic.find_children("*", "MeshInstance3D", true, false):
		var mat := mi.get_active_material(0) as StandardMaterial3D
		if mat != null and mat.emission_enabled and mi.position.z < -1.6 and mat.albedo_color.b > 0.7:
			_lamps.append([mi, mi.material_override])  # ajovalolasit keulassa (valkoiset)
	_build_speaker()
	for sx: float in [-0.55, 0.55]:
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.95, 0.85)
		sp.light_energy = 4.0
		sp.spot_range = 9.0
		sp.spot_angle = 26.0
		sp.position = Vector3(sx, 0.6, -2.0)
		civic.add_child(sp)
		sp.rotation.x = -0.1
		_heads.append(sp)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.2, 0.45, 1.0)
	_glow.light_energy = 2.0
	_glow.omni_range = 2.8
	_glow.position = Vector3(0, 0.12, 0)
	civic.add_child(_glow)
	# Tanssijat: pelaaja edessä, Tero ja Timo sivuilla, Katja takana tuomarina; kaikki kasvot kameraan (+Z).
	for s in 4:
		var c := Room.stand(_room, people[s].look, DANCERS[s], Vector3(0, 0, 1), "Dance" if s < 3 else "Idle")
		_chars.append(c)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.05, 0.07, 0.16)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.45, 0.5, 0.75)
	_env.ambient_light_energy = 0.45
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.4
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.cull_mask = Hall.LAYER
	_cam.environment = _env
	_room.add_child(_cam)
	_frame_cam()
	_cam.current = true
	_set_layers(_room)


## Sivikin "kakssataa wattia ja yks kaiutin": puinen bassokaappi Civicin keulan vieressä, etu tanssijoihin päin. Kartio
## (_speaker_cone) sykkii bassojen tahdissa. Kaapin etu on +Z (paikallinen).
const SPK_AT := Vector3(-2.35, 0.0, 0.25)  # Civicin keulan vieressä asfaltilla, kameran puolella


func _build_speaker() -> void:
	var spk := Node3D.new()
	_room.add_child(spk)
	spk.position = SPK_AT
	spk.rotation.y = B.yaw_to(SPK_AT - Vector3(0.6, 0, 3.0))  # takaosa (-Z) poispäin: etu (+Z) tanssijoihin
	var wood := Color(0.24, 0.16, 0.1)
	B.mesh(spk, B.boxm(Vector3(0.56, 0.86, 0.46)), Vector3(0, 0.45, 0), wood)
	B.mesh(spk, B.boxm(Vector3(0.58, 0.04, 0.48)), Vector3(0, 0.89, 0), wood.lightened(0.12))  # kansi, vaalea yläreuna
	B.mesh(spk, B.boxm(Vector3(0.58, 0.04, 0.48)), Vector3(0, 0.02, 0), wood.darkened(0.4))  # pohja
	for cx: float in [-0.27, 0.27]:
		for cy: float in [0.04, 0.86]:
			B.mesh(spk, B.boxm(Vector3(0.05, 0.05, 0.5)), Vector3(cx, cy, 0), Color(0.7, 0.7, 0.72))  # kulmaraudat
	B.mesh(spk, B.boxm(Vector3(0.5, 0.8, 0.01)), Vector3(0, 0.45, 0.232), Color(0.15, 0.15, 0.17))  # etulevy (harmaa kangas)
	# Bassoelementti: kumireunus, kartio ja pölysuoja, keskeltä ulos (+Z).
	B.mesh(spk, B.cyl(0.2, 0.2, 0.02, 24), Vector3(0, 0.36, 0.24), Color(0.05, 0.05, 0.05), Vector3(PI / 2.0, 0, 0))
	_speaker_cone = Node3D.new()
	spk.add_child(_speaker_cone)
	_speaker_cone.position = Vector3(0, 0.36, 0.245)
	B.mesh(_speaker_cone, B.cyl(0.17, 0.06, 0.05, 24), Vector3(0, 0, -0.012), Color(0.34, 0.34, 0.37), Vector3(-PI / 2.0, 0, 0))
	B.mesh(_speaker_cone, B.sphere(0.055, 14), Vector3(0, 0, 0.0), Color(0.55, 0.55, 0.6))
	# Diskantti ja bassorefleksiputki.
	B.mesh(spk, B.cyl(0.05, 0.05, 0.02, 16), Vector3(-0.12, 0.72, 0.24), Color(0.5, 0.5, 0.55), Vector3(PI / 2.0, 0, 0))
	B.mesh(spk, B.sphere(0.03, 10), Vector3(-0.12, 0.72, 0.25), Color(0.85, 0.85, 0.9))
	B.mesh(spk, B.cyl(0.045, 0.045, 0.02, 14), Vector3(0.14, 0.72, 0.24), Color(0.02, 0.02, 0.02), Vector3(PI / 2.0, 0, 0))
	# Kaapeli maata pitkin autoon.
	var to_car := CIVIC_AT - SPK_AT
	var cab := B.mesh(_room, B.boxm(Vector3(0.025, 0.02, to_car.length() * 0.7)), SPK_AT + to_car * 0.35 + Vector3(0, 0.01, 0),
		Color(0.05, 0.05, 0.05))
	cab.rotation.y = atan2(to_car.x, to_car.z)


func _set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = Hall.LAYER
	if n is Light3D:
		(n as Light3D).light_cull_mask = Hall.LAYER
	for c in n.get_children():
		_set_layers(c)


## Kamera tanssijoiden edestä: neljä tanssijaa ja Civicin keula ruudulle, pelaajan hahmo keskelle (projisoitu).
func _frame_cam() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aim := Vector3(0.5, 1.05, 0.0)  # tanssijat ruudun vasemmalle 3/4:lle, liikekaistat oikeaan reunaan
	for i in 40:
		var d := 3.6 + i * 0.1
		var eye := Vector3(0.3, 1.5 + d * 0.12, d)
		_cam.transform = Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye)
		var l := _cam.unproject_position(_room.to_global(CIVIC_AT + Vector3(0.6, 1.0, 1.0)))
		var r := _cam.unproject_position(_room.to_global(DANCERS[2] + Vector3(0.45, 1.9, 0)))
		var top := _cam.unproject_position(_room.to_global(DANCERS[3] + Vector3(0, 1.9, 0)))
		if l.x >= vs.x * 0.02 and r.x <= vs.x * 0.74 and top.y >= vs.y * 0.17:  # oikea reuna liikekaistoille
			break
	_cam_base = _cam.transform


# --- Liikkeet ja tahti --------------------------------------------------------------------------------------------

## Liikekuvio: alussa joka toinen isku, sitten joka isku ja lopussa kahdeksasosia; sama kaista ei toistu liikaa.
func _make_notes() -> void:
	var beat := 4.0
	var lane := 0
	var n := 0
	while n < KISA_ISKUT and beat < 4.0 + KISA_ISKUT * 1.2:
		var step := 2.0 if n < 16 else (1.0 if n < 70 else (0.5 if _rng.randf() < 0.35 else 1.0))
		lane = (lane + _rng.randi_range(1, 3)) % 4
		_notes.append({"beat": beat, "lane": lane, "hit": false, "miss": false})
		beat += step
		n += 1


## Pelin iskun b aika biisissä (s).
func _beat_time(b: float) -> float:
	return _first + (_k0 + b) * 60.0 / _bpm


func _process(delta: float) -> void:
	_t += delta
	for s in 4:
		if _bubble_t[s] > 0.0:
			_bubble_t[s] -= delta
			if _bubble_t[s] <= 0.0:
				_bubbles[s] = ""
	if _phase in LEG:
		if Input.is_action_just_pressed("mount"):
			_finish(_leg_result())
			return
		_leg_step(delta)
		_shake = maxf(0.0, _shake - delta * 3.0)
		_cam.transform = _cam_base.translated_local(Vector3(randf_range(-1, 1) * _shake * 0.02, -_shake * 0.03, 0))
		_update_keys()
		_ui.queue_redraw()
		return
	if Input.is_action_just_pressed("mount") and _phase != "loppu" and _phase != "valmis":
		_finish({"luovutti": true, "kiva": "disko"})
		return
	match _phase:
		"alku":
			if _t > 2.5:
				_phase = "kisa"
				_t = 0.0
				_story = ""
				# Aloitus tahdin alusta: ensimmäinen liike (isku 4) osuu tahtiin, musiikki alkaa iskusta 0.
				_music.play(_start_at)
		"kisa":
			_dance(delta)
		"loppu":
			if _pressed() or (auto and _t > 2.0):
				var won := _winner() == 0
				if won and legend and lines.has("legenda"):
					_leg_begin()
				else:
					_finish({"voitto": won, "pisteet": _score[0], "kiva": "disko"})
	_animate(delta)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_cam.transform = _cam_base.translated_local(Vector3(0, -_shake * 0.03, 0))
	_judge_t = maxf(0.0, _judge_t - delta)
	_update_keys()
	_ui.queue_redraw()


func _pressed() -> bool:
	return Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")


## Biisin kohta (s): soittimen kohta miksauksen viiveellä korjattuna; ennen soittoa (ja ilman ääntä) oma kello.
func _now() -> float:
	if _music == null or not _music.playing:
		return _start_at + _song_t
	var pos := _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	if _song_t > 0.6 and pos < _start_at + 0.1:
		return _start_at + _song_t  # äänilaite ei etene (testiajon dummy-ääni): oma kello
	return pos


func _dance(delta: float) -> void:
	_song_t += delta
	var now := _now()
	var beat := floori((now - _first) * _bpm / 60.0) - _k0
	if beat != _last_beat and beat >= 0:
		_last_beat = beat
		_on_beat(beat)
	var any := false
	for n: Dictionary in _notes:
		if n.hit or n.miss:
			continue
		any = true
		var dt := now - _beat_time(n.beat)
		if dt > GOOD:
			n.miss = true
			_combo = 0
			_judge = "Ohi"
			_judge_t = 0.5
			_judge_lane = n.lane
			if _rng.randf() < 0.25:
				_say(3, _line("ohi_sina", "Sää liikut ku Sivikki talvirenkailla."))
		elif auto and absf(dt) < 0.03 and _rng.randf() < 0.85:
			_hit(n, dt)
	if not auto:
		for i in 4:
			if Input.is_action_just_pressed(LANES[i]):
				_press(i, now)
	if not any:
		_end()


## Iskulla: valot sykkivät, kamera nytkähtää ja tekoälytanssijat tekevät liikkeitä (pisteet tarkkuuden mukaan).
func _on_beat(beat: int) -> void:
	_glow.light_energy = 4.5
	_shake = 0.35
	for s in [1, 2]:
		var acc: float = 0.72 if s == 1 else 0.8
		if beat >= 4 and _rng.randf() < 0.75:
			if _rng.randf() < acc:
				_score[s] += 100 if _rng.randf() < 0.5 else 60
			_move(s, ["lantio_v", "pylly", "kadet", "lantio_o"][_rng.randi() % 4])
	if beat % 16 == 8 and _rng.randf() < 0.6:
		var s := _rng.randi_range(1, 3)
		var own: Array = lines.get("kommentti", {}).get(String(people[s].id), [])
		if not own.is_empty():
			_say(s, own.pick_random())


func _press(lane: int, now: float) -> void:
	var best: Dictionary = {}
	var bd := 99.0
	for n: Dictionary in _notes:
		if n.hit or n.miss or n.lane != lane:
			continue
		var dt := now - _beat_time(n.beat)
		if absf(dt) < absf(bd):
			bd = dt
			best = n
	if best.is_empty() or absf(bd) > GOOD:
		_judge = "Väärä tahti"
		_judge_t = 0.4
		_judge_lane = lane
		_combo = 0
		return
	_hit(best, bd)


func _hit(n: Dictionary, dt: float) -> void:
	n.hit = true
	var perfect := absf(dt) <= PERFECT
	_combo += 1
	_score[0] += (100 if perfect else 60) + mini(_combo, 20) * 5
	_judge = "Täydellinen!" if perfect else "Hyvä"
	_judge_t = 0.5
	_judge_lane = n.lane
	_move(0, ["lantio_v", "pylly", "kadet", "lantio_o"][n.lane])
	if n.lane == 1 and _rng.randf() < 0.3:
		_say(3, _line("pylly", "Hehe, kato ny tota!"))


## Liike hahmolle s: lantio sivulle, kädet ylös tai pyllistys (hahmo kääntyy selin, kumartuu ja kääntyy takaisin).
func _move(s: int, kind: String) -> void:
	_moves[s] = {"kind": kind, "t": 0.0}


func _animate(delta: float) -> void:
	_glow.light_energy = move_toward(_glow.light_energy, 2.0, delta * 8.0)
	for s in 3:
		var c: Node3D = _chars[s]
		var m: Dictionary = _moves[s]
		c.clear_overrides()
		c.rotation.y = PI  # kasvot kameraan (+Z; hahmon etu on -Z)
		if m.is_empty():
			continue
		m.t += delta
		var k := sin(clampf(m.t / 0.42, 0.0, 1.0) * PI)  # liike edestakaisin 0,42 s:ssa
		match String(m.kind):
			"lantio_v", "lantio_o":
				var sg := 1.0 if m.kind == "lantio_v" else -1.0
				c.set_override("pelvis", Vector3.FORWARD, sg * 0.35 * k)
				c.set_override("spine_02", Vector3.FORWARD, -sg * 0.3 * k)
			"kadet":
				c.set_override("upperarm_l", Vector3.FORWARD, -1.9 * k)
				c.set_override("upperarm_r", Vector3.FORWARD, 1.9 * k)
			"pylly":
				c.rotation.y = PI + PI * k  # selin kameraan
				c.set_override("spine_01", Vector3.RIGHT, -0.75 * k)
				c.set_override("spine_03", Vector3.RIGHT, -0.35 * k)
		if m.t > 0.42:
			_moves[s] = {}


func _winner() -> int:
	var best := 0
	for s in 3:
		if _score[s] > _score[best]:
			best = s
	return best


func _end() -> void:
	_phase = "loppu"
	_t = 0.0
	var w := _winner()
	Sfx.play("win" if w == 0 else "lose", -4.0)
	_fade_tw = create_tween()
	_fade_tw.tween_property(_music, "volume_db", -30.0, 3.0)
	_chars[3].play("Dance", 0.3)
	if w == 0 and legend and lines.has("legenda"):
		_story = "Voitit! %d pistettä. Katja nousee: vielä yks biisi." % _score[0]
		_say(3, _line("voitto", "Sää vietät mut hitaille."))
	elif w == 0:
		_story = "Voitit! %d pistettä. Katja vie sut hitaille, ja Timon akku hyytyy kesken biisin." % _score[0]
		_say(3, _line("voitto", "Sää vietät mut hitaille."))
	else:
		_story = "%s voitti (%d p, sinä %d p). Sää tanssit hitaat Teron kanssa." % [people[w].name, _score[w], _score[0]]
		var t: String = _line("havio", "%s voitti!")
		_say(3, t % people[w].name if "%s" in t else t)


func _finish(r: Dictionary) -> void:
	if _phase == "valmis":
		return
	_phase = "valmis"
	finished.emit(r)
	queue_free()


# --- Puhe ja käyttöliittymä ---------------------------------------------------------------------------------------

func _line(key: String, fallback: String) -> String:
	var l: Variant = lines.get(key, [])
	return (l as Array).pick_random() if l is Array and not (l as Array).is_empty() else fallback


func _say(s: int, text: String) -> void:
	_bubbles[s] = "%s: %s" % [people[s].name, text] if s != 0 else text
	_bubble_t[s] = 3.2


func _update_keys() -> void:
	match _phase:
		"kisa":
			_keys.set_text("%s lantio   %s pyllistys   %s kädet ylös   %s lopeta" % [Settings.pair("left", "right"),
				Settings.cap("back"), Settings.cap("forward"), Settings.cap("mount")])
		"loppu":
			_keys.set_text("%s jatka" % Settings.cap("interact"))
		"droppi", "pari", "sammuu", "laulu", "otsikko":
			_keys.set_text("%s ohita" % Settings.cap("mount"))
		_:
			_keys.set_text("%s lopeta" % Settings.cap("mount"))


func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _phase in LEG:
		_draw_legend(vs)
		return
	var top := "SIVIKKI-DISKO   Sinä %d   %s %d   %s %d   %s" % [_score[0], people[1].name, _score[1], people[2].name,
		_score[2], ("Combo %d" % _combo) if _combo >= 4 else ""]
	Room.box(_ui, Rect2(vs.x / 2.0 - 380, 14, 760, 40), Color(0, 0, 0, 0.55))
	_ui.draw_string(font, Vector2(vs.x / 2.0 - 370, 42), top, HORIZONTAL_ALIGNMENT_CENTER, 740, 20, Color.WHITE)
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 400, 62, 800, 60)
		Room.box(_ui, r)
		_ui.draw_multiline_string(font, r.position + Vector2(16, 25), _story, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 18, 2,
			Color(1.0, 0.92, 0.75))
	for s in 4:
		Room.bubble(_ui, _cam, _chars[s], _bubbles[s], 130.0 if _story != "" else 64.0, 120.0)
	if _phase != "kisa":
		return
	# Liikekaistat oikeassa reunassa: liikkeet tulevat ylhäältä ja osuvat viivaan.
	var lw := 58.0
	var x0 := vs.x - 4 * lw - 30.0
	var y_hit := vs.y - 120.0
	var y_top := y_hit - 330.0
	Room.box(_ui, Rect2(x0 - 8, y_top - 8, 4 * lw + 16, y_hit - y_top + 50), Color(0, 0, 0, 0.5))
	var cols := [Color(0.95, 0.35, 0.6), Color(0.95, 0.75, 0.2), Color(0.35, 0.85, 0.95), Color(0.95, 0.35, 0.6)]
	var arrows := ["◀", "▼", "▲", "▶"]
	for i in 4:
		var x := x0 + i * lw
		_ui.draw_rect(Rect2(x + 4, y_top, lw - 8, y_hit - y_top + 30), Color(1, 1, 1, 0.05))
		_ui.draw_string(font, Vector2(x, y_hit + 32), LANE_NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, lw, 11, Color(1, 1, 1, 0.75))
	_ui.draw_line(Vector2(x0, y_hit), Vector2(x0 + 4 * lw, y_hit), Color.WHITE, 3.0)
	var now := _now()
	for n: Dictionary in _notes:
		if n.hit:
			continue
		var dt: float = _beat_time(n.beat) - now
		if dt > LEAD or dt < -0.3:
			continue
		var y := y_hit - dt / LEAD * (y_hit - y_top)
		var c := Vector2(x0 + (n.lane + 0.5) * lw, y)
		var col: Color = cols[n.lane] if not n.miss else Color(0.4, 0.4, 0.4)
		_ui.draw_circle(c, 21.0, col.darkened(0.4))
		_ui.draw_circle(c, 18.0, col)
		_ui.draw_string(font, c + Vector2(-20, 8), arrows[n.lane], HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color(0.1, 0.05, 0.1))
	if _judge_t > 0.0:
		var jx := x0 + (_judge_lane + 0.5) * lw
		_ui.draw_string(font, Vector2(jx - 90, y_hit - 40 - (0.5 - _judge_t) * 60), _judge, HORIZONTAL_ALIGNMENT_CENTER, 180,
			22, Color(1, 1, 0.7, minf(1.0, _judge_t * 3.0)))


# --- Legendaarinen hetki "sivikkidisko" ---------------------------------------------------------------------------
# Ensimmäinen voitto (main.gd _kolmio_ilta legend): Timo vääntää Sivikin stereot kaakkoon ja basso pudottaa (droppi:
# valot välkkyvät, kaiutin ja auto pomppivat), Katja hakee voittajan parikseen ja he tanssivat sylikkäin (pari,
# PariOte.hali), Sivikin akku hyytyy kesken biisin: musiikki venyy hiljaiseksi ja valot sammuvat (sammuu), ja pimeällä
# pihalla koko porukka laulaa biisin itse loppuun (laulu, nuotit nousevat laulajista), otsikko (otsikko).
# Pari tanssii X-akselilla kasvokkain (pelaajan etu +X, Katjan -X), jolloin edestä (+Z) kuvattuna molemmat näkyvät sivulta.

const PAIR_MID := Vector3(0.02, 0.0, 0.95)
const HOLD_LAHI := 0.27  # rintakehien spine_03-luiden väli ennen pair_fitiä (m), kuten tanssi_game.gd
const STROBE := [Color(1.0, 0.3, 0.75), Color(0.3, 0.85, 1.0)]  # pinkki ja syaani ajovalojen välke

var _dropped := false
var _dark_lamp: StandardMaterial3D
var _sway := 0.0
var _note_t := 0.0
var _beat_n := 0
var _pair_base := 0.0  # parin akselin kierto (0 = pelaaja +X:ään); laulussa pelaajan kasvot kameraan päin


func _leg_result() -> Dictionary:
	return {"voitto": true, "pisteet": _score[0], "kiva": "disko"}


func _once_k(key: String) -> bool:
	if _once.has(key):
		return false
	_once[key] = true
	return true


func _leg_say(i: int, sec := 3.0) -> void:
	var r: Array = lines.legenda.rivit[i]
	for s in 4:
		_bubbles[s] = ""  # yksi kupla kerrallaan
	_say(int(r[0]), String(r[1]))
	_bubble_t[int(r[0])] = sec


func _set_cam(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam_base = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
	_cam.transform = _cam_base


## Kamera suunnasta dir kohti pistettä look: lähin etäisyys, jolla kaikki pisteet (pihan paikallisia) osuvat ruutuun
## reunuksen sisään (projisoitu, ei arvattu).
func _fit_cam(look: Vector3, dir: Vector3, fov: float, pts: Array, margin := 0.08) -> void:
	var vs := get_viewport().get_visible_rect().size
	var d := dir.normalized()
	for i in 120:
		var eye := look + d * (0.8 + i * 0.06)
		_set_cam(eye, look, fov)
		var ok := true
		for p: Vector3 in pts:
			var g := _room.to_global(p)
			var q := _cam.unproject_position(g)
			if _cam.is_position_behind(g) or q.x < vs.x * margin or q.x > vs.x * (1.0 - margin) or q.y < vs.y * margin \
					or q.y > vs.y * (1.0 - margin):
				ok = false
				break
		if ok:
			return


func _bone(s: int, b: String) -> Vector3:
	var c: Node3D = _chars[s]
	return _room.to_local(c.to_global(c.bone_position(b)))


## Civicin etusuunta ja oikea puoli (vaakatasossa, pihan avaruudessa).
func _car_f() -> Vector3:
	return (Vector3(0.0, 0, 0.6) - CIVIC_AT).normalized()


func _car_r() -> Vector3:
	var f := _car_f()
	return Vector3(-f.z, 0, f.x)


## Timo Civicin oikealla kyljellä kuskin ikkunan kohdalla (stereot ja virta-avain), kasvot autoon päin.
func _timo_spot() -> Vector3:
	return CIVIC_AT + _car_r() * 1.05 + _car_f() * 0.25


func _face(s: int, f: Vector3) -> void:
	(_chars[s] as Node3D).rotation.y = atan2(-f.x, -f.z)


func _walk_to(s: int, to: Vector3, dur: float) -> void:
	var c: Node3D = _chars[s]
	_walk[s] = [c.position, to, 0.0, dur]
	c.play("Walk", 0.2)


func _update_walk(delta: float) -> void:
	for s: int in _walk.keys():
		var w: Array = _walk[s]
		w[2] += delta
		var k := clampf(float(w[2]) / float(w[3]), 0.0, 1.0)
		var c: Node3D = _chars[s]
		c.position = (w[0] as Vector3).lerp(w[1], k)
		var dv: Vector3 = w[1] - w[0]
		if dv.length() > 0.05:
			_face(s, dv)
		if k >= 1.0:
			_walk.erase(s)
			c.play("Idle", 0.25)


func _leg_begin() -> void:
	_phase = "droppi"
	_t = 0.0
	process_priority = 1  # hahmojen animaation jälkeen: tanssiote lasketaan ruudun lopulliseen asentoon
	_story = String(lines.legenda.droppi)
	for s in 4:
		_bubbles[s] = ""
		var c: Node3D = _chars[s]
		c.clear_overrides()
		c.rotation.y = PI
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	if not _music.playing:
		_music.play(_now())
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -3.0, 0.5)
	# Timo stereoiden ääreen Civicin kylkeen (leikkaus: hän on jo siellä), Katja tanssii takana.
	var timo: Node3D = _chars[2]
	timo.position = _timo_spot()
	_face(2, -_car_r())
	timo.play("Interact", 0.1)
	_chars[0].play("Dance", 0.1)
	_chars[1].play("Dance", 0.1)
	_chars[3].play("Dance", 0.1)
	_dark_lamp = StandardMaterial3D.new()
	_dark_lamp.albedo_color = Color(0.28, 0.29, 0.3)
	_dark_lamp.roughness = 0.15
	_dark_lamp.metallic = 0.3
	_frame_stereo()


## Ennen droppia: Timo Civicin kyljessä ja Sivikin kaiutin samassa kuvassa (kaiutin etualalla oikealla).
func _frame_stereo() -> void:
	var head := _timo_spot() + Vector3(0, 1.75, 0)
	var pts := [head + Vector3(0, 0.25, 0), _timo_spot(), SPK_AT + Vector3(0.35, 0.95, 0.3), SPK_AT + Vector3(-0.35, 0.0, 0.3)]
	_fit_cam((head + SPK_AT) * 0.5 + Vector3(0, -0.1, 0), Vector3(0.1, 0.12, 1.0), 42.0, pts, 0.12)


## Droppi: laaja kuva edestä, kaikki tanssijat ja välkkyvä Civic.
func _frame_drop() -> void:
	var f := _car_f()
	var pts := [CIVIC_AT + f * 2.0 + Vector3(0, 0.3, 0), _timo_spot() + Vector3(0, 2.0, 0), DANCERS[2] + Vector3(0.3, 2.0, 0),
		DANCERS[0] + Vector3(0, 0.0, 0.2), DANCERS[3] + Vector3(0, 2.0, 0)]
	_fit_cam(Vector3(-0.8, 1.0, -0.2), Vector3(0.12, 0.1, 1.0), 48.0, pts, 0.05)


func _leg_step(delta: float) -> void:
	_t += delta
	_song_t += delta
	_update_walk(delta)
	_beat_fx(delta)
	if _cam_glide >= 0.0:
		_cam_glide = minf(1.0, _cam_glide + delta / 6.5)
		_cam_base = _cam_from.interpolate_with(_cam_to, smoothstep(0.0, 1.0, _cam_glide))
	match _phase:
		"droppi":
			if _t > 0.3 and _once_k("d_r0"):
				_leg_say(0, 2.6)
			if _t > 1.4 and _once_k("d_drop"):
				_dropped = true
				_shake = 1.0
				Sfx.play("punch_heavy", 0.0, 0.45)
				Sfx.play("whoosh", -6.0, 0.6)
				(_chars[2] as Node3D).play("Dance", 0.15)
				_frame_drop()
			if _dropped:
				for s: int in [0, 1]:  # kädet ilmaan bassojen tahdissa
					var c: Node3D = _chars[s]
					c.clear_overrides()
					var k := 0.75 + 0.25 * _pump
					c.set_override("upperarm_l", Vector3.FORWARD, -1.9 * k)
					c.set_override("upperarm_r", Vector3.FORWARD, 1.9 * k)
			if _t > 4.2:
				_leg_pari()
		"pari":
			_pair_place(delta, true)
			if _t > 0.5 and _once_k("p_r1"):
				_leg_say(1, 2.8)
			if _t > 3.5 and _once_k("p_r2"):
				_leg_say(2, 2.6)
			if _t > 6.2:
				_leg_sammuu()
		"sammuu":
			_pair_place(delta, false)
			_lit = 0.0 if _t > 1.5 else (1.0 - smoothstep(0.0, 1.5, _t)) * (0.35 + 0.65 * randf())
			if _lit < 0.3 and _once_k("s_lamps"):
				for l: Array in _lamps:
					(l[0] as MeshInstance3D).material_override = _dark_lamp
			if _t > 1.55 and _once_k("s_cut"):
				_music.stop()
				_story = String(lines.legenda.sammuu)
				_frame_timo()
			if _t > 2.0 and _once_k("s_key1"):
				Sfx.play("car_engine", -4.0, 0.55)
				_face(2, -_car_r())  # Timo kurottaa ikkunasta virta-avaimeen
				(_chars[2] as Node3D).play("Interact", 0.1)
			if _t > 2.9 and _once_k("s_key2"):
				Sfx.play("car_engine", -9.0, 0.4)
			if _t > 3.6 and _once_k("s_click"):
				Sfx.play("rattle", -6.0, 1.6)
			if _t > 3.9 and _once_k("s_r3"):
				_leg_say(3, 2.6)
			if _t > 6.6:
				_leg_laulu()
		"laulu":
			_pair_place(delta, true)
			if _t > 0.3 and _once_k("l_r4"):
				_leg_say(4, 2.2)
				_singers = [3]
			if _t > 2.6 and _once_k("l_r5"):
				_leg_say(5, 2.0)
				_singers = [3, 0, 1]
				(_chars[1] as Node3D).play("Dance", 0.3)
			if _t > 4.8 and _once_k("l_r6"):
				_leg_say(6, 2.4)
				_singers = [3, 0, 1, 2]
				(_chars[2] as Node3D).play("Dance", 0.3)
			if _t > 7.6:
				_phase = "otsikko"
				_t = 0.0
				_story = ""
				for s in 4:
					_bubbles[s] = ""
				Sfx.play("win", -4.0)
		"otsikko":
			_pair_place(delta, true)
			if _t > 5.5 or (auto and _t > 4.5):
				_finish(_leg_result())
	_update_notes(delta)


## Bassojen tahti (biisin kohdasta): välke, kaiuttimen kartio ja auton pomppu. Sähköt (_lit) himmentävät kaiken.
func _beat_fx(delta: float) -> void:
	_strobe = maxf(0.0, _strobe - delta * 5.0)
	_pump = maxf(0.0, _pump - delta * 6.0)
	if _phase in ["droppi", "pari"]:
		var b := floori((_now() - _first) * _bpm / 60.0) - _k0
		if b != _beat_n:
			_beat_n = b
			_pump = 1.0 if (_dropped or _phase == "pari") else 0.5
			if _dropped:
				_strobe = 1.0
				_shake = maxf(_shake, 0.3)
	var col: Color = STROBE[_beat_n % 2] if _dropped else Color(1.0, 0.95, 0.85)
	for sp: SpotLight3D in _heads:
		sp.light_color = Color(1.0, 0.95, 0.85).lerp(col, _strobe)
		sp.light_energy = _lit * (4.0 + 6.0 * _strobe)
	_glow.light_color = Color(0.2, 0.45, 1.0).lerp(col, _strobe * 0.6)
	_glow.light_energy = _lit * (2.0 + 5.0 * _strobe)
	if is_instance_valid(_speaker_cone):
		_speaker_cone.position.z = 0.245 + _lit * _pump * 0.03
	if is_instance_valid(_civic):
		_civic.position.y = CIVIC_AT.y + _lit * _pump * 0.035
		_civic.rotation.z = _lit * _pump * 0.012
	_env.ambient_light_energy = lerpf(0.3, 0.45, _lit)


func _leg_pari() -> void:
	_phase = "pari"
	_t = 0.0
	_story = String(lines.legenda.pari)
	for s in 4:
		(_chars[s] as Node3D).clear_overrides()
	# Pelaaja kääntyy Katjaa kohti (etu +X), Katja kävelee takaa pelaajan eteen.
	var me: Node3D = _chars[0]
	me.position = PAIR_MID - Vector3(0.3, 0, 0)
	me.play("Idle", 0.3)
	_face(0, Vector3(1, 0, 0))
	_walk_to(3, PAIR_MID + Vector3(0.32, 0, 0), 1.1)
	(_chars[1] as Node3D).position = Vector3(1.35, 0, 0.3)  # Tero parin oikealle, pois Timon ja auton edestä
	_face(1, Vector3(-0.5, 0, 1))
	_frame_pair()


## Kahden kuva parista edestä: päät ja lantio ruutuun, Tero taustalla vasemmalla, Timo autolla.
func _frame_pair() -> void:
	var look := PAIR_MID + Vector3(0, 1.35, 0)
	var pts := [PAIR_MID + Vector3(-0.45, 2.05, 0), PAIR_MID + Vector3(0.6, 1.9, 0), PAIR_MID + Vector3(-0.5, 0.75, 0),
		PAIR_MID + Vector3(0.6, 0.75, 0)]
	_fit_cam(look, Vector3(1.0, 0.42, 0.75), 40.0, pts, 0.12)


## Pari tanssii sylikkäin: pelaaja paikallaan kasvot +X:ään (keinuen), Katja tanssiotteessa vastapäätä (PariOte.hali:
## pelaajan kädet Katjan vyötäröllä, Katjan kädet pelaajan hartioilla). sway = keinuuko pari.
func _pair_place(delta: float, sway: bool) -> void:
	if _walk.has(3):
		return
	var me: Node3D = _chars[0]
	var her: Node3D = _chars[3]
	if sway:
		_sway += delta
	var a := _pair_base + sin(_sway * 1.1) * 0.22
	var ax := Vector3(cos(a), 0, -sin(a))
	me.position = PAIR_MID - ax * 0.3
	_face(0, ax)
	her.position = PAIR_MID + ax * 0.3
	_face(3, -ax)
	if me.current() != "Idle":
		me.play("Idle", 0.3)
	if her.current() != "Idle":
		her.play("Idle", 0.3)
	_hold_w = minf(1.0, _hold_w + delta / 1.0)
	_hold(smoothstep(0.0, 1.0, _hold_w))


## Tanssiote painolla w (tanssi_game.gd _hold, mutta halausote): jalat IK:lla animaatiosta, Katja lähelle ja pair_fit
## erottaa vartalot kosketukseen, sitten PariOte.hali ja pair_fit käsille. Headless: ei kontaktia (ei paistettua verkkoa).
func _hold(w: float) -> void:
	var me: Node3D = _chars[0]
	var her: Node3D = _chars[3]
	if _prof.is_empty():
		if DisplayServer.get_name() == "headless":
			return
		var pm0 := Contact.profile(me, Pose.limb_points)
		var ph0 := Contact.profile(her, Pose.limb_points)
		if not (pm0.measured and ph0.measured):
			return
		_prof = {0: pm0, 3: ph0}
	var pm: Dictionary = _prof[0]
	var ph: Dictionary = _prof[3]
	PariOte.legs_from_anim(me)
	PariOte.legs_from_anim(her)
	var mfront := -PariOte.back(me)
	var rm := PariOte.right(me)
	var ab := her.to_global(her.bone_position("spine_03")) - me.to_global(me.bone_position("spine_03"))
	her.global_position += (mfront * (HOLD_LAHI - ab.dot(mfront)) - rm * ab.dot(rm)) * w
	Contact.pair_fit(me, pm, her, ph, true, ["leg_l", "leg_r"], 4, false)
	PariOte.hali(her, ph, me, pm, _room, w)
	PariOte.fit(me, pm, her, ph, false, ["arm_l", "arm_r"], 8, ["hand_l", "hand_r"])


func _leg_sammuu() -> void:
	_phase = "sammuu"
	_t = 0.0
	var tw := create_tween()
	tw.tween_property(_music, "pitch_scale", 0.3, 1.5).set_ease(Tween.EASE_IN)  # akku hyytyy: biisi venyy ja hiljenee
	tw.parallel().tween_property(_music, "volume_db", -14.0, 1.5)
	(_chars[1] as Node3D).play("Idle", 0.3)
	(_chars[2] as Node3D).play("Idle", 0.3)


## Lähikuva Timosta Civicin keulan yli: pimeät ajovalot etualalla, Timo kääntää virta-avainta ikkunasta.
func _frame_timo() -> void:
	var f := _car_f()
	var r := _car_r()
	var head := _bone(2, "Head")
	var pts := [head + Vector3(0, 0.25, 0), head - Vector3(0, 0.75, 0), CIVIC_AT + f * 1.98 + r * 0.49 + Vector3(0, 0.5, 0),
		CIVIC_AT + f * 1.98 - r * 0.2 + Vector3(0, 0.5, 0)]
	var look := (head + CIVIC_AT + f * 1.9 + Vector3(0, 0.6, 0)) * 0.5
	_fit_cam(look, f - r * 0.3 + Vector3(0, 0.62, 0), 40.0, pts, 0.1)  # kaiuttimen (keulan oikealla) ohi


func _leg_laulu() -> void:
	_phase = "laulu"
	_t = 0.0
	_story = String(lines.legenda.laulu)
	_pair_base = -PI / 4.0  # pelaaja katsoo +X+Z:aan: kasvot Katjan pään yli kameraan
	var timo: Node3D = _chars[2]
	timo.position = _timo_spot() + _car_r() * 0.35
	timo.rotation.y = PI
	# Laaja kuva pimeästä pihasta, kamera vetäytyy hitaasti laulun ajan.
	var pts := [_bone(1, "Head") + Vector3(0, 0.3, 0), timo.position + Vector3(0, 2.0, 0), PAIR_MID + Vector3(0.7, 2.0, 0),
		PAIR_MID + Vector3(0, 0.0, 0.3), SPK_AT + Vector3(0, 0.9, 0)]
	_fit_cam(Vector3(-0.9, 1.1, 0.2), Vector3(0.4, 0.16, 1.0), 46.0, pts, 0.1)
	_cam_from = _cam_base
	var back := _cam_base.basis.z
	_cam_to = Transform3D(_cam_base.basis, _cam_base.origin + back * 1.4 + Vector3(0, 0.3, 0))
	_cam_glide = 0.0


## Laulun nuotit: laulajien päistä nousee nuotteja, jotka keinuvat ja haihtuvat.
func _update_notes(delta: float) -> void:
	for n: Array in _notes_fx:
		n[1] += delta
	_notes_fx = _notes_fx.filter(func(n: Array) -> bool: return float(n[1]) < 2.2)
	if _singers.is_empty() or _phase == "otsikko" and _t > 2.0:
		return
	_note_t -= delta
	if _note_t <= 0.0:
		_note_t = 0.32
		var s: int = _singers[_rng.randi() % _singers.size()]
		_notes_fx.append([s, 0.0, _rng.randf_range(-1.0, 1.0), _rng.randi() % 2])


func _draw_note(p: Vector2, sz: float, col: Color, double: bool) -> void:
	var stem := Vector2(sz * 0.42, 0)
	_ui.draw_circle(p, sz * 0.48, col.darkened(0.6))
	_ui.draw_circle(p, sz * 0.4, col)
	_ui.draw_line(p + stem, p + stem + Vector2(0, -sz * 1.7), col, maxf(2.0, sz * 0.14))
	if double:
		var q := p + Vector2(sz * 1.1, -sz * 0.2)
		_ui.draw_circle(q, sz * 0.48, col.darkened(0.6))
		_ui.draw_circle(q, sz * 0.4, col)
		_ui.draw_line(q + stem, q + stem + Vector2(0, -sz * 1.7), col, maxf(2.0, sz * 0.14))
		_ui.draw_line(p + stem + Vector2(0, -sz * 1.7), q + stem + Vector2(0, -sz * 1.7), col, maxf(3.0, sz * 0.3))
	else:
		_ui.draw_line(p + stem + Vector2(0, -sz * 1.7), p + stem + Vector2(sz * 0.6, -sz * 1.0), col, maxf(2.0, sz * 0.16))


func _draw_legend(vs: Vector2) -> void:
	var font := ThemeDB.fallback_font
	for n: Array in _notes_fx:
		var c: Node3D = _chars[int(n[0])]
		var g := c.to_global(c.bone_position("Head")) + Vector3(0, 0.25, 0)
		if _cam.is_position_behind(g):
			continue
		var age := float(n[1])
		var p := _cam.unproject_position(g) + Vector2(float(n[2]) * 30.0 + sin(age * 4.0 + float(n[2]) * 3.0) * 12.0, -age * 70.0)
		var a := clampf(age * 4.0, 0.0, 1.0) * clampf((2.2 - age) / 0.8, 0.0, 1.0)
		_draw_note(p, 21.0, Color(1.0, 0.92, 0.45, a), int(n[3]) == 1)
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 420, 24, 840, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for s in 4:
		Room.bubble(_ui, _cam, _chars[s], _bubbles[s], 90.0, 120.0)
	if _phase != "otsikko":
		return
	_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.01, 0.04, 0.35 * clampf(_t / 0.8, 0.0, 1.0)))
	var a := clampf((_t - 0.4) / 0.6, 0.0, 1.0)
	if _t < 1.1 and fmod(_t * 13.0, 1.0) < 0.35:
		a *= 0.25  # neonvalo syttyy räpsyen
	var x0 := vs.x * 0.15
	var w := vs.x * 0.7
	var y := vs.y * 0.2
	var title := "SIVIKKI-DISKO"
	for i in 4:  # neonin hehku: leveät läpikuultavat ääriviivat
		_ui.draw_string_outline(font, Vector2(x0, y), title, HORIZONTAL_ALIGNMENT_CENTER, w, 76, 26 - i * 6,
			Color(0.3, 0.85, 1.0, a * (0.12 + i * 0.12)))
	_ui.draw_string_outline(font, Vector2(x0, y), title, HORIZONTAL_ALIGNMENT_CENTER, w, 76, 4, Color(0.1, 0.02, 0.12, a))
	_ui.draw_string(font, Vector2(x0, y), title, HORIZONTAL_ALIGNMENT_CENTER, w, 76, Color(1.0, 0.45, 0.82, a))
	var sr := Rect2(vs.x * 0.2, vs.y - 170.0, vs.x * 0.6, 96)
	_ui.draw_rect(sr, Color(0.03, 0.03, 0.07, 0.78 * a))
	var sub := "%d pistettä. %s" % [_score[0], String(lines.legenda.sub)]
	_ui.draw_multiline_string(font, sr.position + Vector2(18, 34), sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 36, 20, 4,
		Color(1.0, 0.94, 0.85, a))


# --- Testi (tools/testit/iltakivat_kuvat.gd) ----------------------------------------------------------------------

func test_target() -> Array:
	var c: Node3D = _chars[0]
	return [c.to_global(c.bone_position("Head")), 0.11]


func test_closeup() -> void:
	_move(0, "pylly")
	_moves[0].t = 0.21
	var p := DANCERS[0] + Vector3(0, 1.0, 0)
	var eye := p + Vector3(0.6, 0.3, 2.4)
	_cam_base = Transform3D(Basis.looking_at(p - eye, Vector3.UP), eye)
	_cam.transform = _cam_base
