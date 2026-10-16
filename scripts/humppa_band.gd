extends Node3D
## Humppabändi esiintymislavalla soittamassa: laulaja mikkitelineellä, harmonikka, kitara, basso ja rummut
## (juhannuksena lisäksi trumpetti, saksofoni ja kaksi taustalaulajaa). Soittimet on mallinnettu (palkeet, koskettimet,
## kielet, kalvot, symbaalit), ja kädet ovat soittimilla IK:lla tahdin mukaan: harmonikan palkeet aukeavat ja
## sulkeutuvat, kitaristi näppäilee iskujen välissä, rumpali lyö bassorumpua iskulla ja virveliä välissä, symbaalit
## heilahtavat. Päät nyökkäävät tahdissa.
## Paikallinen kehys: yleisö -Z:n suunnassa (hahmojen oletuskatse), lavan takaseinä +Z. Lavan pinta y = 0.
## Käyttö: vaala.gd (lava ulkoa, ikkunoista näkyy) ja lava_game.gd (tanssit). bpm ja playing ohjaavat soittoa.
## Ohjelmisto: vanhat iskelmät ja lavamusiikki äänitteinä (iskelmat.gd); jos tiedostoja ei ole, syntetisoitu humppa
## (humppa_synth.gd). Äänitteen loputtua bändi soittaa seuraavan.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Synth := preload("res://scripts/humppa_synth.gd")
const Iskelmat := preload("res://scripts/iskelmat.gd")

signal song_started(song: Dictionary, stream: AudioStream)

var bpm := 128.0
var playing := true
var juhannus := false
var band_name := "OULUJÄRVEN HUMPPAVEIKOT"
## Kamera kauempana kuin tämä: hahmot eivät päivity (animaatio ja IK maksavat).
var active_range := 110.0

var _t := 0.0
var _members: Array = []  # {ch, role, nodes...}
var _cymbals: Array = []  # [solmu, heilahdus]
var _built := false
## Kappale soi lavalta 3D-äänenä (kuuluu ulos pihalle); lava_game.gd soittaa saman kappaleen musiikkina ja
## hiljentää tämän.
var speaker := true
var current_song := {}
var _player: AudioStreamPlayer3D
var _pending := {}
var _song_left := -1.0  # äänitteen jäljellä oleva aika (s); -1 = syntetisoitu silmukka


## Bändin ohjelmisto (toivelista): iskelmäaänitteet, tai syntetisoitu humppa, jos tiedostoja ei ole.
static func repertoire() -> Array:
	var songs := Iskelmat.available()
	return songs if not songs.is_empty() else Synth.SONGS


## Kappaleen tunniste (Sfx.music_play vaihtaa soittimen sisällön, kun tunniste vaihtuu).
static func song_id(song: Dictionary) -> String:
	return song.path if song.has("path") else Synth.song_key(song)


## Seuraava kappale ohjelmistosta: jokin muu kuin juuri soinut.
func next_song() -> Dictionary:
	var songs := repertoire().filter(func(sg: Dictionary) -> bool: return sg.title != current_song.get("title", ""))
	return songs.pick_random() if not songs.is_empty() else repertoire()[0]


## Toivekappale (repertoire): äänite tai valmis syntetisoitu kappale alkaa heti, muuten se renderöidään
## taustasäikeessä.
func request(song: Dictionary) -> void:
	if song.has("path"):
		_pending = {}
		_start(song, Iskelmat.stream(song.path))
		return
	var wav := Synth.cached(song)
	if wav != null:
		_start(song, wav)
		return
	if not _pending.is_empty():
		_pending = song  # säie on jo käynnissä: uusin toive voittaa
		return
	_pending = song
	WorkerThreadPool.add_task(func() -> void:
		var pcm := Synth.render_bytes(song)
		_rendered.call_deferred(song, pcm))


func _rendered(song: Dictionary, pcm: PackedByteArray) -> void:
	var wav := Synth.store(song, pcm)
	var want := _pending
	_pending = {}
	if not is_inside_tree():
		return
	if Synth.song_key(want) != Synth.song_key(song):
		request(want)
		return
	_start(song, wav)


func _start(song: Dictionary, wav: AudioStream) -> void:
	current_song = song
	bpm = float(song.bpm)
	_t = 0.0
	playing = true
	if _player == null:
		_player = AudioStreamPlayer3D.new()
		_player.bus = "Music"
		_player.unit_size = 8.0
		_player.max_distance = 160.0
		_player.position = Vector3(0, 2.0, -2.0)
		add_child(_player)
	_player.stream = wav
	_player.volume_db = -4.0
	_song_left = wav.get_length() if song.has("path") else -1.0
	if speaker:
		_player.play()
	else:
		_player.stop()
	song_started.emit(song, wav)


func set_speaker(on: bool) -> void:
	speaker = on
	if _player == null:
		return
	if on and not _player.playing and playing:
		_player.play()
	elif not on:
		_player.stop()


func stop_playing() -> void:
	playing = false
	if _player != null:
		_player.stop()


func build() -> void:
	for ch in get_children():
		if ch != _player:
			ch.queue_free()
	_members.clear()
	_cymbals.clear()
	var red := Color(0.72, 0.08, 0.1) if not juhannus else Color(0.95, 0.95, 0.92)
	var vest := {"shirt": Color(0.95, 0.95, 0.93), "pants": Color(0.1, 0.1, 0.12), "shoes": Color(0.08, 0.08, 0.08),
		"stripes": false, "height": 1.8, "belly": 0.45}
	var hairs := ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Long", "Hair_SimpleParted", "Hair_Buzzed"]
	var hair_cols := [Color(0.3, 0.2, 0.12), Color(0.55, 0.55, 0.55), Color(0.2, 0.15, 0.1), Color(0.7, 0.6, 0.4), Color(0.15, 0.12, 0.1)]
	var look := func(k: int) -> Dictionary:
		var l := vest.duplicate()
		l.shirt = red
		l.hair = hairs[k % hairs.size()]
		l.hair_color = hair_cols[k % hair_cols.size()]
		l.beard = k == 2
		l.belly = [0.5, 0.7, 0.3, 0.6, 0.4][k % 5]
		return l
	_add_singer(Vector3(0, 0, -1.7), look.call(0))
	_add_accordion(Vector3(-2.3, 0, -0.9), look.call(1))
	_add_guitar(Vector3(2.3, 0, -0.9), look.call(2), false)
	_add_guitar(Vector3(3.9, 0, 0.5), look.call(3), true)
	_add_drums(Vector3(0, 0, 1.3), look.call(4))
	if juhannus:
		_add_horn(Vector3(-4.0, 0, 0.2), look.call(5), false)
		_add_horn(Vector3(-5.3, 0, -0.7), look.call(6), true)
		for k in 2:
			var bv := Looks.make(self, {"model": "female", "shirt": Color(0.85, 0.1, 0.35), "pants": Color(0.85, 0.1, 0.35),
				"hair": "Hair_Long", "hair_color": [Color(0.9, 0.75, 0.4), Color(0.35, 0.2, 0.1)][k], "height": 1.68})
			bv.position = Vector3(5.2 + k * 0.9, 0, -1.2 + k * 0.4)
			bv.play("Dance", 0.0, 0.55)
			_members.append({"ch": bv, "role": "taustat"})
	_build_lights()
	_built = true


# --- Soittajat --------------------------------------------------------------------------------------------------

func _chest(ch: Node3D) -> Vector3:
	return ch.bone_position("spine_03")


func _add_singer(at: Vector3, look: Dictionary) -> void:
	var ch := Looks.make(self, look)
	ch.position = at
	ch.play("Idle", 0.0)
	# Mikkiteline: kolmijalka, putki, puomi ja mikrofoni.
	var stand := Node3D.new()
	stand.position = at + Vector3(0.05, 0, -0.42)
	add_child(stand)
	var metal := Color(0.18, 0.18, 0.2)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var leg := B.tube(stand, Vector3.ZERO + Vector3(0, 0.05, 0), Vector3(cos(a) * 0.32, 0.0, sin(a) * 0.32), 0.012, metal)
		leg.name = "jalka"
	B.tube(stand, Vector3(0, 0.05, 0), Vector3(0, 1.38, 0), 0.014, metal)
	B.mesh(stand, B.cyl(0.022, 0.022, 0.05, 10), Vector3(0, 0.95, 0), Color(0.6, 0.6, 0.62))  # kiristin
	var mic_at := Vector3(0, 1.52, 0.12)
	B.tube(stand, Vector3(0, 1.38, 0), mic_at, 0.01, metal)
	var mic := B.mesh(stand, B.cyl(0.022, 0.016, 0.16, 12), mic_at + Vector3(0, 0, 0.06), Color(0.08, 0.08, 0.09), Vector3(70, 0, 0))
	B.mesh(mic, B.sphere(0.032, 10), Vector3(0, 0.1, 0), Color(0.7, 0.7, 0.72))  # ritilä
	_members.append({"ch": ch, "role": "laulu", "mic": stand.position + mic_at + Vector3(0, -0.02, 0.18)})


func _add_accordion(at: Vector3, look: Dictionary) -> void:
	var ch := Looks.make(self, look)
	ch.position = at
	ch.play("Idle", 0.0)
	var chest := _chest(ch)
	var acc := Node3D.new()
	acc.position = at + Vector3(0, chest.y - 0.12, -0.24)
	add_child(acc)
	var body_red := Color(0.68, 0.05, 0.08)
	var chrome := Color(0.82, 0.82, 0.85)
	# Diskanttipuoli (oikea): kotelo, kromisäleikkö ja koskettimisto kehoa vasten.
	var treble := Node3D.new()
	treble.position = Vector3(0.2, 0, 0)
	acc.add_child(treble)
	B.mesh(treble, B.boxm(Vector3(0.11, 0.44, 0.22)), Vector3.ZERO, body_red)
	B.mesh(treble, B.boxm(Vector3(0.112, 0.2, 0.15)), Vector3(0, 0.08, -0.005), chrome)  # säleikkö
	for k in 7:
		B.mesh(treble, B.boxm(Vector3(0.114, 0.006, 0.14)), Vector3(0, 0.0 + k * 0.026, -0.005), Color(0.35, 0.35, 0.38))
	B.mesh(treble, B.boxm(Vector3(0.05, 0.42, 0.035)), Vector3(-0.02, 0, 0.125), Color(0.97, 0.96, 0.92))  # koskettimet
	for k in 12:
		if k % 7 in [2, 6]:
			continue
		B.mesh(treble, B.boxm(Vector3(0.03, 0.016, 0.02)), Vector3(-0.02, -0.19 + k * 0.034, 0.145), Color(0.06, 0.06, 0.06))
	var logo := B.label(treble, "Hohmeri", Vector3(0, -0.15, -0.115), 18, Color(1.0, 0.9, 0.5))
	logo.rotation.y = PI
	logo.pixel_size = 0.002
	# Palkeet: taitteet vuorotellen tumma ja punainen, kulmissa metallisuojat. Skaalataan x-suunnassa.
	var bel := Node3D.new()
	bel.position = Vector3(0.145, 0, 0)
	acc.add_child(bel)
	for k in 9:
		var x := -(k + 0.5) * 0.034
		B.mesh(bel, B.boxm(Vector3(0.03, 0.43 - (k % 2) * 0.02, 0.21 - (k % 2) * 0.02)), Vector3(x, 0, 0),
			Color(0.12, 0.1, 0.1) if k % 2 == 0 else Color(0.55, 0.05, 0.07))
		if k % 2 == 0:
			for cy in [-0.2, 0.2]:
				for cz in [-0.1, 0.1]:
					B.mesh(bel, B.boxm(Vector3(0.032, 0.03, 0.03)), Vector3(x, cy, cz), chrome)
	# Bassopuoli (vasen): kotelo, napit ja hihna.
	var bass := Node3D.new()
	acc.add_child(bass)
	B.mesh(bass, B.boxm(Vector3(0.1, 0.42, 0.21)), Vector3.ZERO, body_red)
	for r in 4:
		for c in 6:
			B.mesh(bass, B.cyl(0.008, 0.008, 0.012, 6), Vector3(-0.055, -0.1 + c * 0.04, -0.06 + r * 0.035), Color(0.95, 0.95, 0.92),
				Vector3(0, 0, 90))
	B.mesh(bass, B.boxm(Vector3(0.012, 0.3, 0.05)), Vector3(-0.06, 0, 0.04), Color(0.2, 0.12, 0.08))  # käsihihna
	# Olkahihnat.
	for sx in [-0.12, 0.12]:
		B.mesh(acc, B.boxm(Vector3(0.04, 0.5, 0.02)), Vector3(sx, 0.2, 0.18), Color(0.12, 0.1, 0.08), Vector3(-20, 0, 0))
	_members.append({"ch": ch, "role": "harmonikka", "acc": acc, "bel": bel, "bass": bass, "treble": treble})


## Kitara (kaikukoppa, ääniaukko, kaula ja kielet) tai sähköbasso (umpirunko, pidempi kaula, neljä kieltä).
func _add_guitar(at: Vector3, look: Dictionary, is_bass: bool) -> void:
	var ch := Looks.make(self, look)
	ch.position = at
	ch.play("Idle", 0.0)
	var chest := _chest(ch)
	var holder := Node3D.new()
	holder.position = at + Vector3(0.06, chest.y - 0.38, -0.2)
	holder.rotation.z = -0.42  # kaula vasemmalle ylös
	add_child(holder)
	var g := Node3D.new()
	holder.add_child(g)
	var wood := Color(0.78, 0.45, 0.16) if not is_bass else Color(0.1, 0.1, 0.12)
	var rim := wood.darkened(0.45)
	var thick := 0.09 if not is_bass else 0.045
	var big := 0.19 if not is_bass else 0.16
	var small := 0.15 if not is_bass else 0.12
	for part in [[Vector3(0.06, 0, 0), big], [Vector3(-0.16, 0, 0), small]]:
		B.mesh(g, B.cyl(part[1] + 0.008, part[1] + 0.008, thick, 24), part[0], rim, Vector3(90, 0, 0))
		B.mesh(g, B.cyl(part[1], part[1], thick + 0.004, 24), part[0], wood.lightened(0.15), Vector3(90, 0, 0))
	if not is_bass:
		B.mesh(g, B.cyl(0.05, 0.05, thick + 0.01, 18), Vector3(-0.1, 0, 0), Color(0.05, 0.04, 0.03), Vector3(90, 0, 0))  # ääniaukko
		B.mesh(g, B.cyl(0.062, 0.062, thick + 0.006, 18), Vector3(-0.1, 0, 0), Color(0.3, 0.18, 0.08), Vector3(90, 0, 0))
		B.mesh(g, B.boxm(Vector3(0.03, 0.12, 0.012)), Vector3(0.13, 0, -thick / 2.0 - 0.006), Color(0.12, 0.08, 0.05))  # talla
	else:
		B.mesh(g, B.boxm(Vector3(0.06, 0.1, 0.012)), Vector3(0.0, 0, -thick / 2.0 - 0.006), Color(0.85, 0.85, 0.85))  # mikrofoni
		B.mesh(g, B.boxm(Vector3(0.025, 0.09, 0.012)), Vector3(0.12, 0, -thick / 2.0 - 0.006), Color(0.6, 0.6, 0.62))
	var neck_len := 0.5 if not is_bass else 0.72
	var nx := -0.28 - neck_len / 2.0
	B.mesh(g, B.boxm(Vector3(neck_len, 0.05, 0.03)), Vector3(nx, 0, -0.01), Color(0.55, 0.35, 0.18))
	B.mesh(g, B.boxm(Vector3(neck_len, 0.052, 0.008)), Vector3(nx, 0, -0.03), Color(0.15, 0.1, 0.07))  # otelauta
	for k in int(neck_len / 0.05):
		B.mesh(g, B.boxm(Vector3(0.004, 0.054, 0.01)), Vector3(-0.3 - k * 0.05 * (1.0 - k * 0.012), 0, -0.032), Color(0.8, 0.8, 0.78))
	var head_x := -0.28 - neck_len - 0.07
	B.mesh(g, B.boxm(Vector3(0.16, 0.075, 0.025)), Vector3(head_x, 0, -0.01), Color(0.12, 0.08, 0.05))
	for k in (6 if not is_bass else 4):
		var side := 1.0 if k % 2 == 0 else -1.0
		B.mesh(g, B.cyl(0.008, 0.008, 0.04, 6), Vector3(head_x - 0.05 + (k / 2) * 0.045, side * 0.05, -0.01), Color(0.8, 0.8, 0.82))
	var strings := 6 if not is_bass else 4
	for k in strings:
		var y := (k - (strings - 1) / 2.0) * (0.008 if not is_bass else 0.011)
		B.mesh(g, B.boxm(Vector3(neck_len + 0.42, 0.0025, 0.0025)), Vector3(-0.28 - neck_len / 2.0 + 0.2, y, -thick / 2.0 - 0.012),
			Color(0.85, 0.85, 0.82))
	# Hihna olan yli.
	B.mesh(holder, B.boxm(Vector3(0.04, 0.62, 0.012)), Vector3(-0.12, 0.3, 0.12), Color(0.1, 0.08, 0.06), Vector3(10, 0, 30))
	_members.append({"ch": ch, "role": "basso" if is_bass else "kitara", "g": g, "neck_x": -0.32 - neck_len * 0.4,
		"strum_x": -0.06 if not is_bass else 0.04, "front": -thick / 2.0 - 0.02})


func _add_drums(at: Vector3, look: Dictionary) -> void:
	var kit := Node3D.new()
	kit.position = at
	add_child(kit)
	var wrap := Color(0.7, 0.06, 0.08)
	var chrome := Color(0.82, 0.82, 0.85)
	var head := Color(0.95, 0.94, 0.9)
	var brass := Color(0.85, 0.65, 0.25)
	var metal := Color(0.2, 0.2, 0.22)
	# Bassorumpu kyljellään, etukalvossa bändin nimi.
	var kick := Vector3(0, 0.3, -0.62)
	B.mesh(kit, B.cyl(0.28, 0.28, 0.4, 24), kick, wrap, Vector3(90, 0, 0))
	for dz in [-0.2, 0.2]:
		B.mesh(kit, B.cyl(0.295, 0.295, 0.03, 24), kick + Vector3(0, 0, dz), chrome, Vector3(90, 0, 0))
	B.mesh(kit, B.cyl(0.27, 0.27, 0.41, 24), kick, head, Vector3(90, 0, 0))
	var name_l := B.label(kit, band_name.replace(" ", "\n"), kick + Vector3(0, 0, -0.215), 26, Color(0.7, 0.05, 0.08))
	name_l.rotation.y = PI
	name_l.pixel_size = 0.0022
	# Virveli, tomit ja telineet.
	var snare := Vector3(-0.27, 0.62, -0.28)
	_drum(kit, snare, 0.18, 0.14, Color(0.9, 0.9, 0.92), Vector3(8, 0, -6))
	_drum(kit, Vector3(0.14, 0.78, -0.55), 0.13, 0.16, wrap, Vector3(20, 0, 0))
	_drum(kit, Vector3(0.46, 0.5, -0.12), 0.2, 0.32, wrap, Vector3.ZERO)
	for k in 3:
		var a := TAU * k / 3.0
		B.tube(kit, snare + Vector3(0, -0.08, 0), snare + Vector3(cos(a) * 0.2, -0.62, sin(a) * 0.2), 0.008, metal)
	# Hi-hat ja symbaalit (heiluvat lyötäessä).
	var hh := Vector3(-0.55, 0.9, -0.22)
	B.tube(kit, Vector3(hh.x, 0, hh.z), hh, 0.012, metal)
	for dy in [0.0, 0.025]:
		var c := B.mesh(kit, B.cyl(0.18, 0.02, 0.012, 20), hh + Vector3(0, dy, 0), brass)
		if dy > 0.0:
			_cymbals.append([c, 0.0])
	var ride := Node3D.new()
	ride.position = Vector3(0.62, 1.08, -0.48)
	kit.add_child(ride)
	B.tube(kit, Vector3(0.62, 0, -0.48), ride.position, 0.012, metal)
	B.mesh(ride, B.cyl(0.25, 0.025, 0.014, 22), Vector3.ZERO, brass)
	_cymbals.append([ride, 0.0])
	var crash := Node3D.new()
	crash.position = Vector3(-0.42, 1.28, -0.66)
	kit.add_child(crash)
	B.tube(kit, Vector3(-0.42, 0, -0.66), crash.position, 0.012, metal)
	B.mesh(crash, B.cyl(0.21, 0.022, 0.012, 22), Vector3.ZERO, brass)
	_cymbals.append([crash, 0.0])
	# Jakkara ja rumpali.
	B.mesh(kit, B.cyl(0.18, 0.18, 0.08, 16), Vector3(0, 0.44, 0.18), Color(0.08, 0.08, 0.08))
	B.tube(kit, Vector3(0, 0.0, 0.18), Vector3(0, 0.4, 0.18), 0.02, metal)
	var ch := Looks.make(kit, look)
	ch.position = Vector3(0, 0.04, 0.12)
	ch.play("Sitting_Idle", 0.0)
	var sticks: Array = []
	for k in 2:
		var st := Node3D.new()
		kit.add_child(st)
		B.mesh(st, B.cyl(0.008, 0.006, 0.4, 6), Vector3(0, 0, -0.2), Color(0.85, 0.72, 0.5), Vector3(90, 0, 0))
		sticks.append(st)
	_members.append({"ch": ch, "role": "rummut", "kit": kit, "snare": snare + Vector3(0, 0.08, 0), "hh": hh + Vector3(0, 0.04, 0),
		"sticks": sticks})


func _drum(kit: Node3D, at: Vector3, r: float, h: float, shell: Color, rot: Vector3) -> void:
	var d := Node3D.new()
	d.position = at
	d.rotation_degrees = rot
	kit.add_child(d)
	B.mesh(d, B.cyl(r, r, h, 20), Vector3.ZERO, shell)
	B.mesh(d, B.cyl(r - 0.005, r - 0.005, h + 0.006, 20), Vector3.ZERO, Color(0.95, 0.94, 0.9))  # kalvo
	for dy in [-h / 2.0, h / 2.0]:
		B.mesh(d, B.cyl(r + 0.008, r + 0.008, 0.015, 20), Vector3(0, dy, 0), Color(0.82, 0.82, 0.85))  # vanne


## Trumpetti (venttiilit, kello) tai saksofoni (kaula, runko, kaari ja kello), suukappale huulilla.
func _add_horn(at: Vector3, look: Dictionary, sax: bool) -> void:
	var ch := Looks.make(self, look)
	ch.position = at
	ch.play("Idle", 0.0)
	var mouth: Vector3 = ch.bone_position("Head") + Vector3(0, 0.02, -0.11)
	var horn := Node3D.new()
	horn.position = at + mouth
	add_child(horn)
	var brass := Color(0.88, 0.7, 0.25)
	if not sax:
		B.tube(horn, Vector3.ZERO, Vector3(0, -0.02, -0.18), 0.008, brass)
		B.mesh(horn, B.boxm(Vector3(0.05, 0.07, 0.09)), Vector3(0, -0.04, -0.22), brass)
		for k in 3:
			B.mesh(horn, B.cyl(0.009, 0.009, 0.06, 8), Vector3(0, 0.01, -0.195 - k * 0.024), Color(0.95, 0.95, 0.9))
		B.tube(horn, Vector3(0, -0.02, -0.26), Vector3(0, -0.02, -0.4), 0.012, brass)
		B.mesh(horn, B.cyl(0.075, 0.014, 0.14, 16), Vector3(0, -0.02, -0.47), brass, Vector3(-90, 0, 0))
		_members.append({"ch": ch, "role": "trumpetti", "horn": horn, "grip_r": Vector3(0.0, -0.0, -0.21), "grip_l": Vector3(-0.03, -0.06, -0.28)})
	else:
		B.tube(horn, Vector3.ZERO, Vector3(0, -0.06, -0.1), 0.01, brass)
		B.tube(horn, Vector3(0, -0.06, -0.1), Vector3(0.02, -0.18, -0.12), 0.018, brass)
		B.tube(horn, Vector3(0.02, -0.18, -0.12), Vector3(0.05, -0.6, -0.1), 0.03, brass)
		B.tube(horn, Vector3(0.05, -0.6, -0.1), Vector3(0.06, -0.68, -0.18), 0.04, brass)
		B.tube(horn, Vector3(0.06, -0.68, -0.18), Vector3(0.06, -0.5, -0.26), 0.045, brass)
		B.mesh(horn, B.cyl(0.08, 0.05, 0.08, 16), Vector3(0.06, -0.44, -0.27), brass)
		for k in 5:
			B.mesh(horn, B.cyl(0.014, 0.014, 0.01, 8), Vector3(0.0, -0.25 - k * 0.07, -0.15), Color(0.95, 0.9, 0.7), Vector3(90, 0, 0))
		_members.append({"ch": ch, "role": "saksofoni", "horn": horn, "grip_r": Vector3(0.04, -0.5, -0.16), "grip_l": Vector3(0.0, -0.27, -0.16)})


func _build_lights() -> void:
	for k in 2:
		var sp := SpotLight3D.new()
		sp.position = Vector3(-3.5 + k * 7.0, 4.2, -4.5)
		sp.light_color = [Color(1.0, 0.75, 0.45), Color(0.85, 0.6, 1.0)][k]
		sp.light_energy = 6.0
		sp.spot_range = 12.0
		sp.spot_angle = 38.0
		add_child(sp)
		sp.look_at(to_global(Vector3(-1.5 + k * 3.0, 1.0, 0.0)), Vector3.UP)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 3.0, -2.5)
	fill.light_color = Color(1.0, 0.85, 0.65)
	fill.light_energy = 1.4
	fill.omni_range = 9.0
	add_child(fill)


# --- Soitto --------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _built:
		return
	if playing and _song_left > 0.0:
		_song_left -= delta
		if _song_left <= 0.0:
			request(next_song())  # äänite loppui: bändi soittaa seuraavan (myös kun lavapeli soittaa samaa sisällä)
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and cam.global_position.distance_to(global_position) < active_range and is_visible_in_tree()
	for m in _members:
		(m.ch as Node).process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
	if not near:
		return
	if playing:
		_t += delta
	var beat := 60.0 / bpm
	var ph := fmod(_t, beat) / beat  # 0 = isku
	var half := fmod(_t + beat * 0.5, beat) / beat  # 0 = iskujen välissä (humpan "pa")
	var bar := int(_t / beat)
	var go := 1.0 if playing else 0.0
	for c in _cymbals:
		var n: Node3D = c[0]
		c[1] = maxf(c[1] - delta * 3.0, 0.0)
		n.rotation.x = sin(_t * 18.0) * 0.12 * c[1]
	for m in _members:
		var ch: Node3D = m.ch
		var inv := ch.transform.affine_inverse()
		ch.set_override("neck_01", Vector3.RIGHT, -0.09 * go * (1.0 - ph) * (1.0 - ph))  # nyökkäys iskulla
		match m.role:
			"laulu":
				var mic: Vector3 = m.mic
				ch.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * mic, inv * (mic + Vector3(0.4, -0.5, 0.3)))
				ch.set_override("spine_01", Vector3.FORWARD, sin(_t * PI / beat * 0.5) * 0.05 * go)
				ch.play("Idle_Talking" if playing and bar % 8 < 6 else "Idle", 0.4)
			"harmonikka":
				# Palkeet: neljä iskua auki, neljä kiinni.
				var cyc := fmod(_t / (beat * 8.0), 1.0)
				var open := 0.75 + 0.5 * (cyc * 2.0 if cyc < 0.5 else 2.0 - cyc * 2.0) if playing else 0.75
				var bel: Node3D = m.bel
				bel.scale.x = open
				(m.bass as Node3D).position.x = 0.145 - 0.306 * open - 0.05
				var acc: Node3D = m.acc
				var rh := acc.position + Vector3(0.24, 0.02 - 0.06 * sin(_t * 9.0) * go * 0.3, 0.09)
				var lh := acc.position + Vector3((m.bass as Node3D).position.x - 0.08, -0.02, 0.0)
				ch.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * rh, inv * (rh + Vector3(0.45, -0.3, 0.35)))
				ch.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", inv * lh, inv * (lh + Vector3(-0.45, -0.3, 0.35)))
			"kitara", "basso":
				var g: Node3D = m.g
				var strum := (0.07 * cos(half * TAU) if m.role == "kitara" else 0.03 * cos(ph * TAU)) * go
				var rh := g.to_global(Vector3(m.strum_x, strum, m.front - 0.05))
				var fret := float(m.neck_x) + (0.06 if (bar / 2) % 2 == 1 else 0.0) * go
				var lh := g.to_global(Vector3(fret, -0.04, -0.02))
				rh = to_local(rh)
				lh = to_local(lh)
				ch.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * rh, inv * (rh + Vector3(0.45, -0.2, 0.35)))
				ch.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", inv * lh, inv * (lh + Vector3(-0.3, -0.5, 0.3)))
			"rummut":
				var kit: Node3D = m.kit
				var lift_r := 0.13 * absf(sin(PI * fmod(_t * 2.0, beat) / beat)) * go
				var lift_l := 0.16 * absf(sin(PI * half)) * go
				var hh: Vector3 = m.hh
				var sn: Vector3 = m.snare
				var rt := hh + Vector3(0.1, 0.1 + lift_r, 0.24)
				var lt := sn + Vector3(0.0, 0.1 + lift_l, 0.26)
				var kinv := ch.transform.affine_inverse()  # rumpali on rumpusetin lapsi: kohteet setin kehyksessä
				# Ristikkäin: oikea käsi hi-hatilla vasemmalla, vasen virvelillä.
				ch.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", kinv * rt, kinv * (rt + Vector3(0.45, -0.3, 0.3)))
				ch.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", kinv * lt, kinv * (lt + Vector3(-0.45, -0.3, 0.25)))
				var sticks: Array = m.sticks
				for k in 2:
					var st: Node3D = sticks[k]
					var hand: Vector3 = kit.to_local(ch.to_global(ch.bone_position("hand_r" if k == 0 else "hand_l")))
					var tip: Vector3 = (hh if k == 0 else sn) + Vector3(0, 0.02 + (lift_r if k == 0 else lift_l) * 0.6, 0)
					st.position = hand
					if hand.distance_to(tip) > 0.01:
						st.look_at(kit.to_global(tip), Vector3.UP)
				if playing and ph < delta / beat * 1.5:
					for c in _cymbals:
						if randf() < 0.35:
							c[1] = 1.0
			"trumpetti", "saksofoni":
				var horn: Node3D = m.horn
				var rh := horn.position + (m.grip_r as Vector3)
				var lh := horn.position + (m.grip_l as Vector3)
				ch.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * rh, inv * (rh + Vector3(0.4, -0.4, 0.2)))
				ch.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", inv * lh, inv * (lh + Vector3(-0.4, -0.4, 0.2)))
