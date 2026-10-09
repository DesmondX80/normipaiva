extends Node
## Valcon kuulokkeet (#15): löytyvät autotallin työkalukaapin päältä pölyisestä pahvilaatikosta. Päässä ollessaan
## ympäristöäänet (linnut, varikset, koirat, tuuli) vaimenevat selvästi ja kaikki muut äänet (Päivin auto, poliisi,
## juntti) kuuluvat heikommin ja tunkkaisemmin: kuulokkeissa on riskinsä. Samalla soi soittolista: Suno-biisit
## kansiosta MUSIC_DIR (ogg/mp3/wav, lataa omasta Suno-soittolistasta), tai jos kansio on tyhjä, pelin omat biisit.
## Ruudun vasemmassa alakulmassa näkyy soiva biisi. main.gd: found tallennukseen, toggle() ja next() näppäimistä.

const MUSIC_DIR := "res://assets/music/kuulokkeet"
const FALLBACK := ["res://assets/music/normipaiva.mp3", "res://assets/music/lirkuttelu.wav"]
const AMB_DB := -20.0     # ympäristöäänet kuulokkeiden läpi
const AMB_CUTOFF := 700.0
const SFX_DB := -9.0      # vaarat ja muut äänet kuuluvat heikommin
const SFX_CUTOFF := 2200.0
const SONG_DB := -6.0

var found := false
var on := false
var title := ""  # soiva biisi
var _player: AudioStreamPlayer
var _list: Array[String] = []
var _idx := -1
var _fx := {}  # väylä -> [lowpass-indeksi, amplify-indeksi]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.volume_db = SONG_DB
	_player.finished.connect(next)
	add_child(_player)
	for b in [["Ambience", AMB_CUTOFF, AMB_DB], ["SFX", SFX_CUTOFF, SFX_DB]]:
		var bi := AudioServer.get_bus_index(b[0])
		if bi < 0:
			continue
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = b[1]
		var amp := AudioEffectAmplify.new()
		amp.volume_db = b[2]
		AudioServer.add_bus_effect(bi, lp)
		AudioServer.add_bus_effect(bi, amp)
		var n := AudioServer.get_bus_effect_count(bi)
		_fx[b[0]] = [n - 2, n - 1]
	_apply()
	_list = playlist()


## Soittolista: kansion biisit (vientipaketissa tiedostot näkyvät .import/.remap-päätteisinä), muuten pelin omat.
static func playlist() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(MUSIC_DIR)
	if d != null:
		for f in d.get_files():
			var name := f.trim_suffix(".import").trim_suffix(".remap")
			var ext := name.get_extension().to_lower()
			var path := MUSIC_DIR.path_join(name)
			if ext in ["ogg", "mp3", "wav"] and not path in out and ResourceLoader.exists(path):
				out.append(path)
	if out.is_empty():
		for f in FALLBACK:
			if ResourceLoader.exists(f):
				out.append(f)
	out.shuffle()
	return out


## Biisin nimi tiedostonimestä: "02_Me_ollaan_rallikansa.mp3" -> "Me ollaan rallikansa".
static func song_title(path: String) -> String:
	var t := path.get_file().get_basename().replace("_", " ").strip_edges()
	var rx := RegEx.create_from_string(r"^\d+\s*[-.]?\s*")
	t = rx.sub(t, "")
	if path.ends_with("normipaiva.mp3"):
		return "Normipäivä (tunnari)"
	if path.ends_with("lirkuttelu.wav"):
		return "Lirkuttelu"
	return t


func toggle() -> bool:
	if not found:
		return false
	on = not on
	_apply()
	if on:
		if _player.stream == null:
			next()
		else:
			_player.stream_paused = false
	else:
		_player.stream_paused = true
	return true


func next() -> void:
	if _list.is_empty():
		title = ""
		return
	_idx = (_idx + 1) % _list.size()
	var st: AudioStream = load(_list[_idx])
	if st is AudioStreamMP3 or st is AudioStreamOggVorbis:
		st.loop = false
	elif st is AudioStreamWAV:
		st.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_player.stream = st
	_player.stream_paused = not on
	_player.play()
	title = song_title(_list[_idx])


## Pelin oma musiikki (välikuvat, onnelliset loput, valikko) menee kuulokebiisin edelle.
func _process(_delta: float) -> void:
	if not on or _player.stream == null:
		return
	var theme_on: bool = Sfx._music != null and Sfx._music.playing
	_player.stream_paused = theme_on or get_tree().paused


func _apply() -> void:
	for b in _fx:
		var bi := AudioServer.get_bus_index(b)
		for e in _fx[b]:
			AudioServer.set_bus_effect_enabled(bi, e, on)


## HUD-rivi (tyhjä, kun kuulokkeet eivät ole päässä).
func hud_text(next_key: String) -> String:
	if not on:
		return ""
	return "Valcot päässä  ♫ %s   [%s] seuraava" % [title if title != "" else "–", next_key]
