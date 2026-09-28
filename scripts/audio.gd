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
	"saw": [["saw_0.wav", "saw_1.wav", "saw_2.wav", "saw_3.wav", "saw_4.wav", "saw_5.wav", "saw_6.wav", "saw_7.wav"], false],
	"axe": [["axe_0.wav", "axe_1.wav", "axe_2.wav", "axe_3.wav", "axe_4.wav", "axe_5.wav"], false],
	"grunt": [["grunt_0.wav", "grunt_1.wav", "grunt_2.wav"], false],
	"groan": [["groan_0.wav", "groan_1.wav"], false],
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
var _music: AudioStreamPlayer
var _music_tw: Tween


func has_music() -> bool:
	for f in MUSIC_FILES:
		if ResourceLoader.exists(f):
			return true
	return false


const MUSIC_CHORUS := 25.0  # kertosäe alkaa (s): onnelliset loput soivat tästä

## Aloittaa (tai jatkaa) musiikin häivyttäen sisään; from = aloituskohta sekunteina.
func music_play(fade := 1.5, from := 0.0) -> void:
	if _music == null:
		for f in MUSIC_FILES:
			if ResourceLoader.exists(f):
				var st: AudioStream = load(f)
				_set_loop(st)
				_music = AudioStreamPlayer.new()
				_music.bus = "Music"
				_music.stream = st
				_music.process_mode = Node.PROCESS_MODE_ALWAYS  # soi myös valikon tauon aikana
				add_child(_music)
				break
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
func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Sijainnillinen ääni, joka seuraa annettua solmua.
func play_on(node: Node3D, sound: String, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	var p := _player3d(stream(sound), volume_db, pitch)
	node.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Sijainnillinen ääni kiinteään pisteeseen.
func play_at(pos: Vector3, sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := _player3d(stream(sound), volume_db, pitch)
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## Jatkuva silmukka solmussa (moottori). Äänenvoimakkuutta ja sävelkorkeutta säädetään kutsujassa.
func loop_on(node: Node3D, sound: String, volume_db := 0.0) -> AudioStreamPlayer3D:
	var p := _player3d(stream(sound), volume_db, 1.0)
	node.add_child(p)
	p.play()
	return p


## Puhekupla-höpötys, pituus tekstin mukaan. Uusi repliikki katkaisee edellisen.
## Puhekuplat ovat äänettömiä (ei CC0-puheäänitteitä); kutsut säilyvät yhteensopivuuden vuoksi.
func babble(_node: Node3D, _voice: String, _text: String) -> void:
	pass


func _player3d(s: AudioStream, volume_db: float, pitch: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 12.0
	p.max_distance = 120.0
	return p
