extends Node
## Äänten soitto, autoload "Sfx". Kaikki äänet ovat CC0-äänitteitä (assets/sounds, ks. LICENSE.md).



var _streams := {}
const DIR := "res://assets/sounds/"
## Äänitteet (CC0, ks. assets/sounds/LICENSE.md): avain -> [tiedostot], silmukka?
const FILES := {
	"engine": [["car_engine.wav"], true],
	"tractor_engine": [["tractor_engine.ogg"], true],
	"bike_roll": [["bike_roll.ogg"], true],
	"amb_forest": [["amb_forest.mp3"], true],
	"amb_birds": [["amb_birds.ogg"], true],
	"water": [["water.ogg"], true],
	"fire": [["fire_loop.wav"], true],
	"bell": [["bike_bell.ogg"], false],
	"spokes": [["bike_spokes.ogg"], false],
	"crow": [["crow_1.wav", "crow_2.ogg"], false],
	"dog": [["dog.wav"], false],
	"glass": [["glass_1.wav", "glass_2.ogg", "glass_3.ogg"], false],
	"punch": [["punch_0.ogg", "punch_1.ogg", "punch_2.ogg", "punch_3.ogg", "punch_4.ogg"], false],
	"punch_heavy": [["punch_heavy_0.ogg", "punch_heavy_1.ogg", "punch_heavy_2.ogg", "punch_heavy_3.ogg", "punch_heavy_4.ogg"], false],
	"step_grass": [["step_grass_0.ogg", "step_grass_1.ogg", "step_grass_2.ogg", "step_grass_3.ogg", "step_grass_4.ogg"], false],
	"step_hard": [["step_hard_0.ogg", "step_hard_1.ogg", "step_hard_2.ogg", "step_hard_3.ogg", "step_hard_4.ogg"], false],
	"step_wood": [["step_wood_0.ogg", "step_wood_1.ogg", "step_wood_2.ogg", "step_wood_3.ogg", "step_wood_4.ogg"], false],
	"coin": [["coins_1.ogg", "coins_2.ogg"], false],
	"door": [["door_open.ogg"], false],
	"door_close": [["door_close.ogg"], false],
	"cloth": [["cloth.ogg"], false],
	"bike_fall": [["bike_fall.ogg"], false],
	"win": [["win.ogg"], false],
	"win_small": [["win_small.ogg"], false],
	"lose": [["lose.ogg"], false],
	"alert": [["alert.ogg", "alert_2.ogg"], false],
	"pickup": [["pickup.ogg", "pickup_2.ogg"], false],
	"register": [["register_1.ogg", "register_2.ogg"], false],
	"whoosh": [["swish_1.wav", "swish_3.wav", "swish_5.wav", "swish_8.wav", "swish_10.wav", "swish_12.wav"], false],
	"wind": [["wind.ogg"], true],
	"horn": [["horn.wav"], false],
	"spokes_loop": [["bike_spokes.ogg"], true],
	"pedal_squeak": [["pedal_squeak_0.ogg", "pedal_squeak_1.ogg", "pedal_squeak_2.ogg"], false],
	"pedal_creak": [["pedal_creak_0.ogg", "pedal_creak_1.ogg"], false],
	"rattle": [["rattle_0.ogg", "rattle_1.ogg", "rattle_2.ogg", "rattle_3.ogg", "rattle_4.ogg"], false],
	"rattle_hard": [["rattle_hard_0.ogg", "rattle_hard_1.ogg", "rattle_hard_2.ogg"], false],
	"body_fall": [["body_fall.ogg"], false],
	"grunt": [["grunt_0.wav", "grunt_1.wav", "grunt_2.wav"], false],
	"groan": [["groan_0.wav", "groan_1.wav"], false],
	"saw": [["saw_0.wav", "saw_1.wav", "saw_2.wav", "saw_3.wav", "saw_4.wav", "saw_5.wav", "saw_6.wav", "saw_7.wav"], false],
	"axe": [["axe_0.wav", "axe_1.wav", "axe_2.wav", "axe_3.wav", "axe_4.wav", "axe_5.wav"], false],
	"fart": [["fart_0.wav", "fart_1.wav", "fart_2.wav"], false],
	"shotgun": [["shotgun.wav"], false],
}


func _ready() -> void:


	for key in FILES:
		var list: Array = []
		for f in FILES[key][0]:
			var st: AudioStream = load(DIR + f)
			if st == null:
				continue
			if FILES[key][1]:
				_set_loop(st)
			list.append(st)
		if not list.is_empty():
			_streams[key] = list  # äänite korvaa syntetisoidun
	# Puuskutus (hengästynyt hahmo): ei äänitettä, joten suodatettua kohinaa hengityksen verhokäyrällä.
	_streams["breath"] = [_breath(0.42, 0.62, 1), _breath(0.5, 0.48, 2), _breath(0.38, 0.7, 3)]


## Uloshengitys "hhah": kohina alipäästön (pehmeä huohotus) ja kaistanpäästön (kurkun "aa") läpi. Nopea nousu,
## pitkä häivytys. dur = kesto (s), tone = kaistan korkeus (0–1).
func _breath(dur: float, tone: float, seed_i: int) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var bp_lo := 0.0
	var bp_hi := 0.0
	var a_lp := 0.12
	var a_hi := lerpf(0.12, 0.3, tone)
	var a_lo := a_hi * 0.35
	for i in n:
		var t := float(i) / n
		var env := smoothstep(0.0, 0.12, t) * pow(1.0 - t, 1.6)
		var w := rng.randf_range(-1.0, 1.0)
		lp += a_lp * (w - lp)
		bp_hi += a_hi * (w - bp_hi)
		bp_lo += a_lo * (bp_hi - bp_lo)
		var v := (lp * 0.9 + (bp_hi - bp_lo) * 1.6) * env * 0.9
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.data = data
	return st


## Suljettaessa soimassa olevat äänet pysäytetään ja irrotetaan, muuten äänipalvelin pitää äänitteen varattuna
## ("resources still in use at exit").
func _exit_tree() -> void:
	for c in get_children():
		if c is AudioStreamPlayer:
			c.stop()
			c.stream = null
	_streams.clear()


func _set_loop(st: AudioStream) -> void:
	if st is AudioStreamOggVorbis or st is AudioStreamMP3:
		st.loop = true
	elif st is AudioStreamWAV:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = int(st.get_length() * st.mix_rate)


func stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		push_warning("Ääntä ei löydy: " + sound)
		return null
	return _streams[sound].pick_random()


# --- Tunnusmusiikki ----------------------------------------------------------------
# Pelin biisi (esim. Sunolla tehty) tiedostoon assets/music/normipaiva.ogg/.mp3/.wav.
# Soi päävalikossa ja onnellisissa lopuissa; jos tiedostoa ei ole, mitään ei soi.

const MUSIC_FILES := ["res://assets/music/normipaiva.ogg", "res://assets/music/normipaiva.mp3",
	"res://assets/music/normipaiva.wav"]
const MUSIC_DB := -4.0
## Lirkuttelubiisi (junan ravintolavaunu): tools/lirkuttelu.py.
const SONG_LIRKUTTELU := "res://assets/music/lirkuttelu.wav"
var _music: AudioStreamPlayer
var _music_tw: Tween
var _music_file := ""  # "" = tunnusmusiikki


func has_music() -> bool:
	for f in MUSIC_FILES:
		if ResourceLoader.exists(f):
			return true
	return false


## Tunnusmusiikki silmukkana (esim. mökin PA-kaiuttimille), null jos tiedostoa ei ole.
func music_stream() -> AudioStream:
	for f in MUSIC_FILES:
		if ResourceLoader.exists(f):
			var st: AudioStream = load(f)
			_set_loop(st)
			return st
	return null


const MUSIC_CHORUS := 25.0  # kertosäe alkaa (s): onnelliset loput soivat tästä

## Aloittaa (tai jatkaa) musiikin häivyttäen sisään; from = aloituskohta sekunteina. file = muu biisi kuin
## tunnusmusiikki (esim. SONG_LIRKUTTELU); toinen biisi vaihtaa soittimen sisällön. stream = valmis ääni (esim.
## lavabändin syntetisoima humppa, humppa_synth.gd), file on silloin sen tunniste.
func music_play(fade := 1.5, from := 0.0, file := "", stream: AudioStream = null) -> void:
	if _music != null and file != _music_file:
		_music.stop()
		_music.queue_free()
		_music = null
	if _music == null:
		_music_file = file
		var st: AudioStream = music_stream()
		if stream != null:
			st = stream
		elif file != "":
			st = null
			if ResourceLoader.exists(file):
				st = load(file)
				_set_loop(st)
		if st != null:
			_music = AudioStreamPlayer.new()
			_music.bus = "Music"
			_music.stream = st
			_music.process_mode = Node.PROCESS_MODE_ALWAYS  # soi myös valikon tauon aikana
			add_child(_music)
	if _music == null:
		return
	if _music_tw != null:
		_music_tw.kill()
	if not _music.playing:
		_music.volume_db = -40.0
		_music.play(from)
	_music_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tw.tween_property(_music, "volume_db", MUSIC_DB, fade)
	if OS.get_cmdline_user_args().has("--music-debug"):
		print("MUSIC play ", _music.stream.resource_path)


## Soivan musiikin kohta sekunteina (äänilaitteen viive huomioituna, rytmipelien tahti) tai -1, jos ei soi.
func music_pos() -> float:
	if _music == null or not _music.playing:
		return -1.0
	return _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


## Häivyttää musiikin pois ja pysäyttää sen.
func music_stop(fade := 1.5) -> void:
	if _music == null or not _music.playing:
		return
	if _music_tw != null:
		_music_tw.kill()
	_music_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tw.tween_property(_music, "volume_db", -40.0, fade)
	_music_tw.tween_callback(_music.stop)


## Ei-sijainnillinen ääni (HUD-tyyppiset, pelaajan omat).
## Kertaääni. Silmukaksi merkitty äänite (esim. "water", jota käytetään myös jatkuvana) ei pääty itsestään,
## joten se hiljennetään ja pysäytetään loop_secs sekunnin kuluttua.
func play(sound: String, volume_db := 0.0, pitch := 1.0, loop_secs := 1.8) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	_limit_loop(p, sound, loop_secs)


## Kertaäänenä soitettu silmukka hiljenee ja pysähtyy loop_secs sekunnin kuluttua (muuten se soisi ikuisesti).
func _limit_loop(p: Node, sound: String, loop_secs: float) -> void:
	if not (FILES.has(sound) and FILES[sound][1]):
		return
	var tw := p.create_tween()
	tw.tween_interval(maxf(0.0, loop_secs - 0.4))
	tw.tween_property(p, "volume_db", -40.0, 0.4)
	tw.tween_callback(p.queue_free)


## Sijainnillinen ääni, joka seuraa annettua solmua.
func play_on(node: Node3D, sound: String, volume_db := 0.0, pitch := 1.0, loop_secs := 1.8) -> AudioStreamPlayer3D:
	var p := _player3d(stream(sound), volume_db, pitch)
	node.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	_limit_loop(p, sound, loop_secs)
	return p


## Sijainnillinen ääni kiinteään pisteeseen.
func play_at(pos: Vector3, sound: String, volume_db := 0.0, pitch := 1.0, loop_secs := 1.8) -> void:
	var p := _player3d(stream(sound), volume_db, pitch)
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	_limit_loop(p, sound, loop_secs)


## Jatkuva silmukka solmussa (moottori). Äänenvoimakkuutta ja sävelkorkeutta säädetään kutsujassa.
func loop_on(node: Node3D, sound: String, volume_db := 0.0) -> AudioStreamPlayer3D:
	var p := _player3d(stream(sound), volume_db, 1.0)
	node.add_child(p)
	p.play()
	return p


## Puhekupla-höpötys: kutsujat antavat puhujan äänen nimen (voice) ja repliikin; ääni on syntetisoitu puhe (speak).
func babble(_node: Node3D, voice: String, text: String) -> void:
	speak("paivi" if voice == "paivi" else "muu", text)


## Puheäänet: assets/aanet/<ryhmä>/<repliikin tiiviste>.mp3, ryhmä "paivi" (Satu, nalkutus) tai "muu" (Eddy, rauhallinen
## tenori). Tiedosto haetaan repliikin tekstin SHA-1:stä; puuttuva repliikki on hiljainen. Uusi repliikki katkaisee
## edellisen. Äänet tehdään `--aanisynteesi`-lipulla ajettaessa (tools/aanet/syntetisoi.sh, vain macOS): ajo
## syntetisoi jokaisen vastaan tulevan repliikin ja kirjaa sen assets/aanet/hakemisto.json:iin; `godot --import` tuo uudet.
const VOICE_DIR := "res://assets/aanet/"
var _voice_player: AudioStreamPlayer
var _voice_index := {}
var _last_spoken := ""
var _last_spoken_ms := 0


static func voice_key(text: String) -> String:
	return text.strip_edges().sha1_text().substr(0, 12)


func speak(group: String, text: String) -> void:
	text = text.strip_edges()
	# "Nimi: repliikki" -> pelkkä repliikki; Päivin nimi valitsee Päivin äänen (kupla ja babble antavat saman tekstin).
	var colon := text.find(": ")
	if colon > 0 and colon <= 24 and text.unicode_at(0) != 0x2A and not text.substr(0, colon).contains(" 0"):
		if text.substr(0, colon) == "Päivi":
			group = "paivi"
		text = text.substr(colon + 2).strip_edges()
	if text.length() < 3 or text.begins_with("*") or text.contains("♪"):
		return  # äänitehosteet ("*pirr pirr*") ja laulun sanat (♪) eivät ole puhetta
	var now := Time.get_ticks_msec()
	if text == _last_spoken and now - _last_spoken_ms < 800:
		return  # sama repliikki kuplasta ja babblesta yhtä aikaa
	_last_spoken = text
	_last_spoken_ms = now
	var path := "%s%s/%s.mp3" % [VOICE_DIR, group, voice_key(text)]
	if ResourceLoader.exists(path):
		if _voice_player == null:
			_voice_player = AudioStreamPlayer.new()
			_voice_player.bus = "SFX"
			_voice_player.volume_db = 2.0
			add_child(_voice_player)
		_voice_player.stream = load(path)
		_voice_player.play()
	elif OS.get_cmdline_user_args().has("--aanisynteesi"):
		_synthesize(group, text, path)


func stop_speech() -> void:
	if _voice_player != null:
		_voice_player.stop()


func _synthesize(group: String, text: String, path: String) -> void:
	var out := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(out) or _voice_index.has(path):
		return
	var tool := ProjectSettings.globalize_path("res://tools/aanet/syntetisoi.sh")
	var rc := OS.execute(tool, [group, text, out])
	if rc != 0:
		push_warning("puhesynteesi epäonnistui (%d): %s" % [rc, text])
		return
	_voice_index[path] = true
	var idx_path := ProjectSettings.globalize_path(VOICE_DIR + "hakemisto.json")
	var all: Dictionary = {}
	if FileAccess.file_exists(idx_path):
		all = JSON.parse_string(FileAccess.get_file_as_string(idx_path))
	all["%s/%s" % [group, voice_key(text)]] = text
	var f := FileAccess.open(idx_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(all, "\t", true))
	f.close()


func _player3d(s: AudioStream, volume_db: float, pitch: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 12.0
	p.max_distance = 120.0
	return p
