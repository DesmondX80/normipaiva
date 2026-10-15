extends RefCounted
## Lavabändin humppa syntetisoituna (humppa_band.gd, lava_game.gd): jokaiselle toivekappaleelle oma sävelmä
## (siemenluvusta kappaleen sävellaji, tempo, sointukulku ja AABA-melodia) ja humpan komppi: basso iskulla
## (pohjasävel ja kvintti vuorotellen), harmonikan soinnut ja virvelirumpu iskujen välissä, bassorumpu iskulla.
## Melodia soi kahdella hieman eri vireisellä sahalaineella kuin musette-harmonikka. Valmis kappale on 16 tahtia
## ja soi silmukkana.
## Välimuisti: renderöity PCM tallennetaan user://humppa/-kansioon (renderöinti vie GDScriptillä sekunteja), ja
## muistissa pidetään enintään CACHE_MAX kappaletta.

const RATE := 22050
const BARS := 16
const VERSION := 1  # nosta, kun ääni muuttuu: vanhat välimuistitiedostot jäävät käyttämättä
const CACHE_DIR := "user://humppa"
const CACHE_MAX := 3

## Toivelista: nimi, tempo (iskua/min), sävellaji (puolisävelaskelia A:sta), siemen.
const SONGS := [
	{"title": "Humppa Oulujärven rannalla", "bpm": 132, "key": 3, "seed": 11},
	{"title": "Vaalan valot", "bpm": 124, "key": 5, "seed": 23},
	{"title": "Mopolla lavalle", "bpm": 138, "key": 0, "seed": 37},
	{"title": "Kainuun kesäyö", "bpm": 118, "key": 8, "seed": 41},
	{"title": "Letkis Pahalahden niemellä", "bpm": 128, "key": 10, "seed": 53},
	{"title": "Tukkijätkän humppa", "bpm": 134, "key": 7, "seed": 67},
	{"title": "Pontikkapolkka", "bpm": 142, "key": 2, "seed": 79},
	{"title": "Siitarin Sirkka", "bpm": 126, "key": 5, "seed": 83},
]
## Duuriasteikko puolisävelaskelina ja sointukulut asteina (I, IV, V, vi): neljän tahdin fraasit.
const MAJOR := [0, 2, 4, 5, 7, 9, 11]
const PROGS := [
	[0, 0, 4, 4, 0, 0, 4, 0], [0, 3, 4, 0, 0, 3, 4, 0], [0, 5, 3, 4, 0, 5, 4, 0], [0, 0, 3, 3, 4, 4, 0, 0],
]

static var _mem := {}  # kappaleen avain -> AudioStreamWAV
static var _order: Array[String] = []


static func song_key(song: Dictionary) -> String:
	return "%d_%d_%d_v%d" % [int(song.seed), int(song.bpm), int(song.key), VERSION]


## Valmis kappale välimuistista (muisti tai levy) tai null, jos se pitää vielä renderöidä.
static func cached(song: Dictionary) -> AudioStreamWAV:
	var key := song_key(song)
	if _mem.has(key):
		return _mem[key]
	var path := "%s/%s.pcm" % [CACHE_DIR, key]
	if FileAccess.file_exists(path):
		var data := FileAccess.get_file_as_bytes(path)
		if data.size() > 1000:
			return _remember(key, _wav(data))
	return null


## Renderöi (raskas: kutsu säikeessä) ja tallentaa välimuistiin. Palauttaa PCM-tavut.
static func render_bytes(song: Dictionary) -> PackedByteArray:
	var pcm := _render(song)
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var f := FileAccess.open("%s/%s.pcm" % [CACHE_DIR, song_key(song)], FileAccess.WRITE)
	if f != null:
		f.store_buffer(pcm)
	return pcm


static func store(song: Dictionary, pcm: PackedByteArray) -> AudioStreamWAV:
	return _remember(song_key(song), _wav(pcm))


static func _remember(key: String, wav: AudioStreamWAV) -> AudioStreamWAV:
	_mem[key] = wav
	_order.erase(key)
	_order.append(key)
	while _order.size() > CACHE_MAX:
		_mem.erase(_order.pop_front())
	return wav


static func _wav(pcm: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = pcm
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = pcm.size() / 2
	return w


static func _hz(semi: float) -> float:
	return 220.0 * pow(2.0, semi / 12.0)


## Nuotit: [alku (iskuina), kesto (iskuina), puolisävel A:sta, ääni (0 melodia, 1 basso, 2 sointu, 3 virveli,
## 4 bassorumpu), voimakkuus].
static func _score(song: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(song.seed)
	var key: int = song.key
	var prog: Array = PROGS[rng.randi() % PROGS.size()]
	var notes: Array = []
	var deg_root := func(d: int) -> int: return MAJOR[d % 7] + 12 * (d / 7)
	# Melodian A- ja B-osa (4 tahtia kumpikin): kahdeksasosia ja neljäsosia soinnun säveliä ja läpikulkuja.
	var phrase := func(bars: Array) -> Array:
		var out: Array = []
		var deg := 7 + 2 * (rng.randi() % 2)  # aloitus terssi tai kvintti ylempää oktaavia
		for b in bars.size():
			var chord: int = bars[b]
			var t := 0.0
			while t < 4.0:
				var dur := 0.5 if rng.randf() < 0.6 else 1.0
				if t + dur > 4.0:
					dur = 4.0 - t
				var on_beat := fmod(t, 1.0) == 0.0
				if on_beat:
					# Iskulla soinnun sävel lähimpänä edellistä.
					var cands := [chord, chord + 2, chord + 4, chord + 7, chord + 9, chord + 11]
					var best: int = cands[0]
					for cd in cands:
						if absi(cd - deg) < absi(best - deg) or (absi(cd - deg) == absi(best - deg) and rng.randf() < 0.5):
							best = cd
					deg = best
				else:
					deg += [-1, 1, 1, -1, 2, -2][rng.randi() % 6]
				deg = clampi(deg, 4, 13)
				out.append([b * 4.0 + t, dur * 0.9, MAJOR[deg % 7] + 12 * (deg / 7), 0, 0.9 if on_beat else 0.7])
				t += dur
		# Fraasin loppu pitkällä pohjasävelellä.
		var last: Array = out[out.size() - 1]
		last[2] = 12 + deg_root.call(bars[bars.size() - 1]) if bars[bars.size() - 1] == 0 else last[2]
		return out
	var a_part: Array = phrase.call(prog.slice(0, 4))
	var b_part: Array = phrase.call(prog.slice(4, 8))
	var form := [a_part, a_part, b_part, a_part]
	for p in form.size():
		for n in form[p]:
			notes.append([n[0] + p * 16.0, n[1], n[2] + key, 0, n[4]])
	# Komppi: basso iskulla (pohjasävel ja kvintti vuorotellen), sointu ja virveli iskujen välissä.
	for bar in BARS:
		var chord: int = prog[(bar % 8)]
		var root: int = deg_root.call(chord) + key - 12
		for beat in 4:
			var t := bar * 4.0 + beat
			notes.append([t, 0.45, root + (7 if beat % 2 == 1 else 0), 1, 1.0])
			notes.append([t, 0.12, 0, 4, 1.0])
			for k in [0, 2, 4]:
				notes.append([t + 0.5, 0.28, deg_root.call(chord + k) + key, 2, 0.55])
			notes.append([t + 0.5, 0.1, 0, 3, 0.8])
	return notes


static func _render(song: Dictionary) -> PackedByteArray:
	var spb := 60.0 / float(song.bpm)
	var total := int(BARS * 4 * spb * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(song.seed) * 7 + 1
	for n in _score(song):
		var start := int(n[0] * spb * RATE)
		var len := int(n[1] * spb * RATE)
		var voice: int = n[3]
		var vol: float = n[4]
		var f := _hz(n[2])
		var p1 := 0.0
		var p2 := 0.0
		var lp := 0.0
		var d1 := f / RATE
		var d2 := f * 1.0035 / RATE  # musette: toinen kieliryhmä hieman ylävireinen
		var end := mini(start + len + int(0.03 * RATE), total)
		for i in range(start, end):
			var k := i - start
			var env := minf(k / (0.01 * RATE), 1.0) * (1.0 if k < len else maxf(0.0, 1.0 - float(k - len) / (0.03 * RATE)))
			var s := 0.0
			match voice:
				0:
					p1 = fmod(p1 + d1 * (1.0 + 0.004 * sin(k * 0.0016)), 1.0)
					p2 = fmod(p2 + d2, 1.0)
					var raw := (p1 * 2.0 - 1.0) + (p2 * 2.0 - 1.0) * 0.8
					lp += (raw - lp) * 0.35
					s = lp * 0.16 * vol * env
				1:
					p1 = fmod(p1 + d1, 1.0)
					var tri := 1.0 - 4.0 * absf(p1 - 0.5)
					s = (tri * 0.7 + sin(p1 * TAU) * 0.5) * 0.32 * vol * env * exp(-k / (0.35 * RATE))
				2:
					p1 = fmod(p1 + d1, 1.0)
					p2 = fmod(p2 + d2, 1.0)
					var sq := (1.0 if p1 < 0.5 else -1.0) + (1.0 if p2 < 0.5 else -1.0)
					lp += (sq - lp) * 0.18
					s = lp * 0.05 * vol * env
				3:
					s = rng.randf_range(-1.0, 1.0) * 0.2 * vol * exp(-k / (0.035 * RATE))
				4:
					var fk := 110.0 * exp(-k / (0.04 * RATE)) + 45.0
					p1 += fk / RATE
					s = sin(p1 * TAU) * 0.55 * vol * exp(-k / (0.09 * RATE))
			buf[i] += s
	var out := PackedByteArray()
	out.resize(total * 2)
	for i in total:
		var v := buf[i]
		v = v / (1.0 + absf(v) * 0.6)  # pehmeä leikkuri
		out.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	return out
