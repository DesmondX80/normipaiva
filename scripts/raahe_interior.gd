extends Node3D
## Raahen baari: Kapteenin Kulma ja Kellari (Kirkkokatu 32, Kirkkokadun ja kävelykadun kulma, Raahe).
## Erillinen tasku kuten Siitari: ylhäällä Kulma (isot ikkunat kävelykadulle ja Kirkkokadulle, kesäterassi,
## baaritiski merihenkisine koristeineen: ruori, pelastusrengas, laivataulu Raahen purjelaivojen ajoilta ja kuva
## Pekkatorin Brahen patsaasta), tiistain pubivisa, ikkunapöydässä vanha kapteeni ja terästehtaan porukka
## yövuoron jälkeen (Tero haastaa kädenvääntöön). Portaat alas Kapteenin Kellariin (ent. Kajuutta): karaoke,
## pyöreät "kajuutan" ikkunat, köydet ja ankkuri. Puhe on raahelaista: ruotsalaisperäiset murresanat (räknätä,
## skooli, kööki, talriikki, retari, seeli) ja ruukin vuorotyö.
## Kävely player_walker.gd:llä ylhäältä kuvattuna; toiminnot acted-signaalilla (tiski, kädenvääntö, visa,
## karaoke main.gd:ssä), ulko-ovelta exited (taksi kotiin).
## Paikallinen -Z = takaseinä (tiski), +Z = kävelykatu (kamera), -X = Kirkkokatu. Kellari on taskussa sivussa (CELLAR).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(9.0, 5.5)
const WALL_H := 3.0
const CELLAR := Vector3(30.0, 0, 0)  # Kellarin keskikohta taskussa
const CELLAR_HALF := Vector2(7.0, 4.5)
const STAGE := Rect2(-7.0, 0.6, 3.4, 3.9)  # karaokelava Kellarissa (CELLAR-suhteellinen)
## Toimintopisteet: id -> [paikka, vihje].
var spots := {
	"ovi": [Vector3(-8.2, 0, 4.2), "[E] Ulos Kirkkokadulle: taksi kotiin Saloisiin"],
	"tiski": [Vector3(0.2, 0, -3.0), "[E] Tilaa tiskiltä"],
	"tero": [Vector3(4.2, 0, 1.6), "[E] Haasta Tero kädenvääntöön (häviäjä tarjoaa)"],
	"ruukki": [Vector3(6.4, 0, 0.0), "[E] Juttele ruukin porukan kanssa"],
	"kapteeni": [Vector3(-6.0, 0, 1.4), "[E] Juttele kapteenin kanssa"],
	"visa": [Vector3(-1.6, 0, 2.6), "[E] Osallistu tiistain pubivisaan"],
	"alas": [Vector3(7.8, 0, 4.0), "[E] Portaat alas Kapteenin Kellariin (karaoke)"],
	"ylos": [CELLAR + Vector3(6.0, 0, 3.4), "[E] Portaat ylös Kulmaan"],
	"karaoke": [CELLAR + Vector3(-2.9, 0, 2.2), "[E] Laula karaokea (2 €)"],
	"kellari_tiski": [CELLAR + Vector3(1.5, 0, -2.9), "[E] Tilaa Kellarin tiskiltä"],
	"kellari_porukka": [CELLAR + Vector3(2.4, 0, 1.0), "[E] Juttele karaokeporukan kanssa"],
}
const BARTENDER_LINES := ["Mitäs laitetaan? Hanasta tullee kaikki mitä tarviit.",
	"Tiistaina on visa. Tuu räknäämään pisteitä!", "Kapteeni istuu tuossa ikkunan vieressä joka päivä, se on sen paikka.",
	"Kellarissa lauletaan, täällä ylhäällä vaan puhutaan. Ja juuaan.", "Kesällä terassi on täynnä, koko kävelykatu kattoo.",
	"Ruukin porukka tullee aina vuoronvaihdon jälkeen.", "Skooli vaan, mutta lasit takasin tiskille, ei talriikeille."]
const RUUKKI_LINES := ["Yövuoro takana, nyt mennää!", "Masuunilla oli taas kuuma. Ei siellä tarvii saunaa.",
	"Kolmivuorossa ei tiiä mikä päivä on. Kalenterista räknätään.", "Skooli! Seuraavan vuoron puolesta.",
	"Tehtaan piippu savuaa, Raahessa kaikki hyvin.", "Tero vääntää kättä joka perjantai. Ei sitä kukaan oo voittanu... melkein.",
	"Ko Ruukilta pääsee, niin tänne. Ko täältä pääsee, niin Ruukille.", "Saloisista vai? No, istu vaan, naapuri."]
const KAPTEENI_LINES := ["Raahe oli aikoinaan Suomen suurin laivakaupunki. Retarit räknäs rahaa ko roskaa.",
	"Ko mää olin nuori, nostettiin seelit ja lähettiin Lontooseen asti.", "Pekka seisoo torilla ja kattoo merelle. Se tietää, mistä tää kaupunki tullee.",
	"Tää kellari oli ennen Kajuutta. Siellä laulettiin merimiesvalssia, ei mitään iskelmää.",
	"Skooli, poika! Merellä ei räknätä tunteja, vaan aaltoja.", "Vanhassa Raahessa joka talossa oli kööki ja kammari, ja retarilla sali.",
	"Kapteenin kulma, kapteenin paikka. Mää istun tässä vaikka myrsky tulis."]
const KELLARI_LINES := ["Kellarissa on Raahen paras karaoke, sanoo kaikki.", "Laula sinäkin! Täällä ei kukaan räknää nuotteja.",
	"Ruukin Raija laulo eilen kolme kertaa saman biisin.", "Kajuutan aikaan täällä oli tanssit joka lauantai.",
	"Skooli laulajalle!"]
const SINGER_LINES := ["♪ Ruukin valot syttyy yöhön... ♪", "♪ Pekka torilla vahtii, merelle kattoo... ♪",
	"♪ Seelit ylös, retari huutaa... ♪", "♪ Skooli, kaverit, Kellarissa... ♪"]

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var _enter_frame := -1

var _bartender: Node3D
var _cellar_bartender: Node3D
var _tero: Node3D
var _kapteeni: Node3D
var _ruukki: Array[Node3D] = []
var _quizmaster: Node3D
var _kellari: Array[Node3D] = []
var _singer: Node3D
var _bubbles := {}  # hahmo -> Label3D
var _screen: Label3D
var _lights: Array[OmniLight3D] = []
var _sing_t := 10.0
var _singing := 0.0
var _chat_t := 5.0
var _t := 0.0


func _ready() -> void:
	_build_kulma()
	_build_kellari()
	_build_people()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	add_child(walker)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(1.2, 0, -0.6)
	walker.rotation.y = B.yaw_to(Vector3(1, 0, -0.5))
	walker.activate()
	say(_bartender, "No terve! Kapteenin Kulmaan tervetuloa. Mitäs laitetaan?")


func leave() -> void:
	active = false
	walker.controls_enabled = false


func in_cellar() -> bool:
	return walker.position.x > CELLAR.x - CELLAR_HALF.x - 1.0


func say(who: Node3D, text: String, t := 3.4) -> void:
	var b: Label3D = _bubbles[who]
	b.text = text
	b.set_meta("t", t)
	if who == _singer and _singing > 0.0:
		return
	who.play("Sitting_Talking" if who.has_meta("sitting") else "Idle_Talking", 0.3)


func bartender_say(text: String) -> void:
	say(_cellar_bartender if in_cellar() else _bartender, text)


func tero_say(text: String) -> void:
	say(_tero, text)


func quizmaster_say(text: String, t := 4.0) -> void:
	say(_quizmaster, text, t)


func _process(delta: float) -> void:
	_t += delta
	for who in _bubbles:
		var b: Label3D = _bubbles[who]
		if b.text == "":
			continue
		var left: float = b.get_meta("t") - delta
		b.set_meta("t", left)
		if left <= 0.0:
			b.text = ""
			if not (who == _singer and _singing > 0.0):
				who.play("Sitting_Idle" if who.has_meta("sitting") else "Idle", 0.3)
	for i in _lights.size():
		_lights[i].light_energy = 0.8 + 0.6 * maxf(sin(_t * 2.6 + i * 2.1), 0.0)
	# Kellarin vakiolaulaja käy lavalla, kun pelaaja ei laula.
	if not busy:
		_sing_t -= delta
		if _singing > 0.0:
			_singing -= delta
			if _singing <= 0.0:
				_singer.position = CELLAR + Vector3(2.4, 0, 2.0)
				_singer.rotation.y = B.yaw_to(Vector3(-1, 0, 0))
				_singer.play("Sitting_Idle", 0.3)
				_singer.set_meta("sitting", true)
				_screen.text = "KAPTEENIN KELLARI\nKaraoke · valitse biisi"
		elif _sing_t <= 0.0:
			_sing_t = randf_range(22.0, 35.0)
			_singing = 9.0
			_singer.remove_meta("sitting")
			_singer.position = CELLAR + Vector3(-5.4, 0.3, 2.6)
			_singer.rotation.y = B.yaw_to(Vector3(1, 0, 0.3))
			_singer.play("Idle_Talking", 0.3)
			var line: String = SINGER_LINES.pick_random()
			say(_singer, line, 8.5)
			_screen.text = line.replace("♪ ", "").replace(" ♪", "")
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(9.0, 16.0)
		if in_cellar():
			say(_kellari.pick_random(), KELLARI_LINES.pick_random())
		else:
			match randi() % 3:
				0:
					say(_ruukki.pick_random(), RUUKKI_LINES.pick_random())
				1:
					say(_kapteeni, KAPTEENI_LINES.pick_random(), 4.5)
				_:
					say(_bartender, BARTENDER_LINES.pick_random())
	var p := walker.position
	var best := ""
	var bd := 1.4
	for id in spots:
		var d := Vector2(p.x - spots[id][0].x, p.z - spots[id][0].z).length()
		if d < bd:
			bd = d
			best = id
	hint = ""
	if best == "":
		return
	hint = spots[best][1]
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	match best:
		"ovi":
			exited.emit()
		"ruukki":
			say(_ruukki.pick_random(), RUUKKI_LINES.pick_random())
		"kapteeni":
			say(_kapteeni, KAPTEENI_LINES.pick_random(), 4.5)
		"kellari_porukka":
			say(_kellari.pick_random(), KELLARI_LINES.pick_random())
		"alas":
			walker.position = spots.ylos[0] + Vector3(-1.0, 0, 0)
			walker.rotation.y = B.yaw_to(Vector3(-1, 0, 0))
			block_interact()
			Sfx.play("step_wood", -4.0, 0.8)
			say(_cellar_bartender, "Tervetuloa Kellariin! Ennen tää oli Kajuutta.")
		"ylos":
			walker.position = spots.alas[0] + Vector3(-1.0, 0, -0.6)
			walker.rotation.y = B.yaw_to(Vector3(-1, 0, 0))
			block_interact()
			Sfx.play("step_wood", -4.0, 0.8)
		"kellari_tiski":
			acted.emit("tiski")
		_:
			acted.emit(best)


## Valikosta tai minipelistä palatessa sama E-painallus ei saa avata uutta toimintoa.
func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


func set_screen(text: String) -> void:
	_screen.text = text


## Pelaaja Kellarin lavalle mikin taakse (karaoke).
func to_stage() -> void:
	busy = true
	walker.controls_enabled = false
	walker.position = CELLAR + Vector3(-5.4, 0.3, 2.6)
	walker.rotation.y = B.yaw_to(Vector3(-1, 0, -0.3))
	walker._body.play("Idle", 0.2)
	if _singing > 0.0:
		_singing = 0.01


func from_stage(cheer: bool) -> void:
	busy = false
	walker.position = spots.karaoke[0]
	walker.controls_enabled = active
	_screen.text = "KAPTEENIN KELLARI\nKaraoke · valitse biisi"
	if cheer:
		for s in _kellari:
			s.play("Sitting_Talking", 0.2)
		say(_kellari[0], "Skooli! Vielä toinen!")
	else:
		say(_kellari[1], "No... ei sitä kaikki voi olla Ruukin Raijoja.")


# --- Rakennus ---------------------------------------------------------------------

func _wall(a: Vector2, b: Vector2, h: float, col: Color, collide_h := WALL_H) -> void:
	var c := (a + b) / 2.0
	var size := Vector3(maxf(absf(b.x - a.x), 0.2), h, maxf(absf(b.y - a.y), 0.2))
	B.mesh(self, B.boxm(size), Vector3(c.x, h / 2.0, c.y), col)
	var body := StaticBody3D.new()
	body.position = Vector3(c.x, 0, c.y)
	body.add_child(B.box_shape(Vector3(size.x, collide_h, size.z), Vector3(0, collide_h / 2.0, 0)))
	add_child(body)


func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := B.mesh(self, B.boxm(size), pos, col)
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	add_child(body)
	return mi


func _table(at: Vector3, r := 0.5, col := Color(0.3, 0.18, 0.1)) -> void:
	B.mesh(self, B.cyl(r, r, 0.05, 16), at + Vector3(0, 0.75, 0), col)
	B.mesh(self, B.cyl(0.06, 0.06, 0.75, 8), at + Vector3(0, 0.37, 0), Color(0.15, 0.15, 0.15))
	var body := StaticBody3D.new()
	body.position = at
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = 1.0
	cs.shape = cyl
	cs.position.y = 0.5
	body.add_child(cs)
	add_child(body)
	B.mesh(self, B.cyl(0.045, 0.04, 0.15, 8), at + Vector3(0.15, 0.85, 0.1), Color(0.95, 0.75, 0.25))  # tuoppi


func _chair(at: Vector3) -> void:
	B.mesh(self, B.boxm(Vector3(0.45, 0.06, 0.45)), at + Vector3(0, 0.45, 0), Color(0.35, 0.2, 0.12))
	for dx in [-0.18, 0.18]:
		for dz in [-0.18, 0.18]:
			B.mesh(self, B.cyl(0.02, 0.02, 0.45, 6), at + Vector3(dx, 0.22, dz), Color(0.2, 0.2, 0.2))


func _light(at: Vector3, col: Color, energy := 0.8, rng := 9.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.omni_range = rng
	l.light_energy = energy
	l.light_color = col
	add_child(l)
	return l


## Kulma: katutason pubi kahden kadun kulmassa.
func _build_kulma() -> void:
	var panel := Color(0.3, 0.2, 0.12)  # tumma laivapaneeli
	var navy := Color(0.08, 0.14, 0.28)
	var brass := Color(0.85, 0.66, 0.28)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(10, -0.2, 0), Color(0.08, 0.07, 0.07))
	# Lankkulattia kuin laivan kannella.
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), Color(0.5, 0.36, 0.22))
	for i in 24:
		B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.01, 0.02)), Vector3(0, 0.005, -HALF.y + 0.45 * i + 0.2), Color(0.3, 0.2, 0.12))
	# Seinät: takaseinä ja oikea pääty täyskorkeat, Kirkkokadun puoli (-X) ikkunaseinä, kävelykadun puoli (+Z)
	# matala ikkunaseinä (kamera), törmäys täyskorkea. Ulko-ovi kulmassa Kirkkokadun puolella.
	_wall(Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, -HALF.y), WALL_H, panel)
	_wall(Vector2(HALF.x, -HALF.y), Vector2(HALF.x, HALF.y), WALL_H, panel)
	_wall(Vector2(-HALF.x, -HALF.y), Vector2(-HALF.x, HALF.y), 1.0, panel, WALL_H)  # ikkunaseinä ja ovi (E vie ulos)
	_wall(Vector2(-HALF.x, HALF.y), Vector2(HALF.x, HALF.y), 0.6, panel, WALL_H)
	# Isot ikkunat: karmit kävelykadun puolella ja Kirkkokadun puolella; ikkunoista näkyy ilta-Raahe.
	for wx in [-6.0, -2.0, 2.0, 6.0]:
		B.mesh(self, B.boxm(Vector3(3.4, 0.08, 0.12)), Vector3(wx, 0.62, HALF.y), Color(0.9, 0.88, 0.8))
	for wz in [-3.5, -0.5, 2.0]:
		B.mesh(self, B.boxm(Vector3(0.12, 0.08, 2.4)), Vector3(-HALF.x, 1.02, wz), Color(0.9, 0.88, 0.8))
	B.mesh(self, B.boxm(Vector3(0.1, 2.2, 1.3)), Vector3(-HALF.x + 0.02, 1.1, 4.25), Color(0.25, 0.18, 0.1))  # ulko-ovi
	var ulos := B.label(self, "ULOS · KIRKKOKATU", Vector3(-HALF.x + 0.2, 2.45, 4.25), 30, Color(0.3, 1.0, 0.4))
	ulos.rotation.y = PI / 2.0
	# Kadut ikkunoiden takana: kävelykadun kiveys ja Kirkkokadun asfaltti, vastapäätä vanhan Raahen puutaloja.
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0 + 8.0, 0.02, 7.0)), Vector3(-2.0, 0.01, HALF.y + 3.5), Color(0.55, 0.52, 0.48))
	B.mesh(self, B.boxm(Vector3(7.0, 0.02, HALF.y * 2.0 + 8.0)), Vector3(-HALF.x - 3.5, 0.0, 2.0), Color(0.22, 0.22, 0.24))
	for i in 4:
		var hx := -8.0 + i * 5.5
		B.mesh(self, B.boxm(Vector3(5.0, 3.6, 0.3)), Vector3(hx, 1.8, HALF.y + 7.2), [Color(0.85, 0.75, 0.45), Color(0.75, 0.25, 0.18), Color(0.92, 0.9, 0.82), Color(0.55, 0.65, 0.5)][i])
		B.mesh(self, B.boxm(Vector3(0.9, 1.1, 0.05)), Vector3(hx - 1.2, 2.0, HALF.y + 7.03), Color(0.95, 0.85, 0.5))
	# Kesäterassi kävelykadulla: pöydät, aurinkovarjot ja aita.
	for tx in [-5.0, -1.0, 3.0]:
		var tp := Vector3(tx, 0, HALF.y + 2.0)
		_table(tp, 0.45, Color(0.85, 0.85, 0.82))
		B.mesh(self, B.cyl(0.03, 0.03, 2.2, 6), tp + Vector3(0, 1.1, 0), Color(0.9, 0.9, 0.9))
		B.mesh(self, B.cyl(0.05, 1.2, 0.35, 12), tp + Vector3(0, 2.25, 0), Color(0.12, 0.25, 0.55))
	B.mesh(self, B.boxm(Vector3(14.0, 0.8, 0.05)), Vector3(-1.0, 0.4, HALF.y + 3.4), Color(0.12, 0.25, 0.55))
	# Merihenkiset koristeet takaseinällä: ruori, pelastusrengas, laivataulu, Pekan kuva, liitutaulu.
	var wheel := Node3D.new()
	wheel.position = Vector3(6.2, 1.9, -HALF.y + 0.15)
	add_child(wheel)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.38
	tm.outer_radius = 0.45
	rim.mesh = tm
	rim.material_override = B.mat(Color(0.45, 0.28, 0.12))
	rim.rotation.x = PI / 2.0
	wheel.add_child(rim)
	for k in 8:
		var a := k * TAU / 8.0
		B.mesh(wheel, B.boxm(Vector3(0.04, 1.1, 0.04)), Vector3.ZERO, Color(0.45, 0.28, 0.12), Vector3(0, 0, rad_to_deg(a)))
	B.mesh(wheel, B.cyl(0.08, 0.08, 0.06, 12), Vector3(0, 0, 0.03), brass, Vector3(90, 0, 0))
	var buoy := MeshInstance3D.new()
	var bt := TorusMesh.new()
	bt.inner_radius = 0.22
	bt.outer_radius = 0.38
	buoy.mesh = bt
	buoy.material_override = B.mat(Color(0.95, 0.35, 0.12))
	buoy.rotation.x = PI / 2.0
	buoy.position = Vector3(-6.5, 1.9, -HALF.y + 0.2)
	add_child(buoy)
	var bl := B.label(self, "KAPTEENIN KULMA · RAAHE", Vector3(-6.5, 1.35, -HALF.y + 0.2), 22, Color(0.95, 0.95, 0.95))
	bl.outline_size = 6
	B.mesh(self, B.boxm(Vector3(1.6, 1.0, 0.04)), Vector3(-3.6, 2.0, -HALF.y + 0.12), Color(0.55, 0.42, 0.2))
	B.mesh(self, B.boxm(Vector3(1.45, 0.85, 0.05)), Vector3(-3.6, 2.0, -HALF.y + 0.13), Color(0.35, 0.5, 0.65))
	B.label(self, "Raahelainen parkki\nlähtee Lontooseen 1870", Vector3(-3.6, 2.0, -HALF.y + 0.17), 18, Color(0.98, 0.95, 0.85))
	B.mesh(self, B.boxm(Vector3(0.7, 0.9, 0.04)), Vector3(3.6, 2.1, -HALF.y + 0.12), Color(0.15, 0.12, 0.1))
	B.label(self, "PEKKA\nPekkatori 1888", Vector3(3.6, 2.1, -HALF.y + 0.16), 18, Color(0.95, 0.9, 0.75))
	B.mesh(self, B.boxm(Vector3(1.2, 1.4, 0.05)), Vector3(HALF.x - 0.12, 1.6, -2.0), Color(0.08, 0.1, 0.08), Vector3(0, 90, 0))
	var chalk := B.label(self, "TIISTAINA\nPUBIVISA!\nEdullista\nvisajuomaa\n& hyviä\npalkintoja", Vector3(HALF.x - 0.18, 1.6, -2.0), 20, Color(0.95, 0.95, 0.9))
	chalk.rotation.y = -PI / 2.0
	var sign := B.sign_plate(self, "KAPTEENIN KULMA", navy, Color(0.98, 0.9, 0.6), 0.55, 80, Color(0.02, 0.05, 0.15), "Helvetica Neue")
	sign.position = Vector3(0.2, 2.55, -HALF.y + 0.12)
	# Baaritiski takaseinällä: tumma tiski messinkitangolla, hanat, jakkarat, pullohylly ja laivalyhdyt.
	_solid(Vector3(7.0, 1.1, 0.8), Vector3(0.2, 0.55, -4.0), Color(0.24, 0.14, 0.08))
	B.mesh(self, B.boxm(Vector3(7.2, 0.06, 0.95)), Vector3(0.2, 1.13, -4.0), Color(0.12, 0.08, 0.05))
	B.tube(self, Vector3(-3.3, 0.2, -3.52), Vector3(3.7, 0.2, -3.52), 0.03, brass)
	for i in 5:
		var x := -1.0 + i * 0.5
		B.mesh(self, B.cyl(0.03, 0.03, 0.3, 8), Vector3(x, 1.3, -4.15), Color(0.8, 0.8, 0.82))
		B.mesh(self, B.boxm(Vector3(0.06, 0.18, 0.04)), Vector3(x, 1.53, -4.15),
			[Color(0.05, 0.05, 0.05), Color(0.85, 0.7, 0.2), Color(0.1, 0.3, 0.6), Color(0.7, 0.1, 0.1), Color(0.9, 0.9, 0.9)][i])
	for i in 6:
		var x := -2.6 + i * 1.1
		B.mesh(self, B.cyl(0.05, 0.05, 0.75, 8), Vector3(x, 0.37, -3.2), Color(0.6, 0.6, 0.62))
		B.mesh(self, B.cyl(0.22, 0.22, 0.08, 14), Vector3(x, 0.78, -3.2), navy)
	for shelf in 2:
		var y := 1.45 + shelf * 0.5
		B.mesh(self, B.boxm(Vector3(6.6, 0.04, 0.3)), Vector3(0.2, y, -HALF.y + 0.25), Color(0.2, 0.12, 0.07))
		for i in 22:
			var col: Color = [Color(0.2, 0.45, 0.2), Color(0.55, 0.3, 0.1), Color(0.85, 0.85, 0.9), Color(0.4, 0.1, 0.1), Color(0.8, 0.6, 0.2)][(i * 7 + shelf) % 5]
			B.mesh(self, B.cyl(0.04, 0.05, 0.3, 8), Vector3(-3.0 + i * 0.29, y + 0.17, -HALF.y + 0.25), col)
	for lx in [-2.4, 2.8]:
		B.mesh(self, B.cyl(0.1, 0.12, 0.28, 8), Vector3(lx, 2.55, -HALF.y + 0.3), brass)
		var lamp := B.mesh(self, B.sphere(0.08, 8), Vector3(lx, 2.5, -HALF.y + 0.3), Color.WHITE)
		lamp.material_override = B.unshaded(Color(1.0, 0.85, 0.5))
	# Pöydät: kapteenin ikkunapöytä, ruukin porukan pöytä (Teron kädenvääntöpöytä), visapöytä ja pari muuta.
	for t in [Vector3(-7.0, 0, 1.4), Vector3(5.2, 0, 0.6), Vector3(-1.6, 0, 1.4), Vector3(-4.2, 0, -1.4), Vector3(1.6, 0, 3.4)]:
		_table(t)
	for ch in [Vector3(-7.8, 0, 1.4), Vector3(-6.2, 0, 1.4), Vector3(5.2, 0, -0.2), Vector3(4.4, 0, 0.6), Vector3(6.0, 0, 0.6),
			Vector3(-1.6, 0, 0.6), Vector3(-2.4, 0, 1.4), Vector3(-4.2, 0, -0.6), Vector3(-5.0, 0, -1.4), Vector3(1.6, 0, 4.2)]:
		_chair(ch)
	# Visan kysymyspaperit ja kynät pöydällä.
	for i in 3:
		B.mesh(self, B.boxm(Vector3(0.21, 0.005, 0.3)), Vector3(-1.8 + i * 0.22, 0.785, 1.3), Color(0.97, 0.97, 0.95))
	# Portaat alas Kellariin oikeassa etunurkassa: kaide ja kyltti.
	B.mesh(self, B.boxm(Vector3(1.6, 0.02, 1.8)), Vector3(7.9, 0.01, 4.4), Color(0.12, 0.1, 0.08))
	for k in 4:
		B.mesh(self, B.boxm(Vector3(1.4, 0.03, 0.3)), Vector3(7.9, 0.02, 3.8 + k * 0.35), Color(0.4, 0.28, 0.16).darkened(0.15 * k))
	B.tube(self, Vector3(7.05, 1.0, 3.5), Vector3(7.05, 0.2, 5.3), 0.025, brass)
	var kl := B.label(self, "↓ KELLARI · KARAOKE", Vector3(7.9, 2.2, 3.3), 26, Color(1.0, 0.85, 0.3))
	kl.outline_size = 6
	# Valaistus: lämmin pubivalo.
	for l in [Vector3(-5.0, 2.7, -1.5), Vector3(0.5, 2.7, -2.5), Vector3(5.0, 2.7, 0.5), Vector3(-2.0, 2.7, 3.0)]:
		_light(l, Color(1.0, 0.82, 0.55), 0.8)


## Kellari (ent. Kajuutta): matala karaokekellari, kajuutan pyöreät ikkunat, köydet, ankkuri ja verkot.
func _build_kellari() -> void:
	var c := CELLAR
	var dark := Color(0.16, 0.11, 0.08)
	var brass := Color(0.85, 0.66, 0.28)
	var H := CELLAR_HALF
	B.mesh(self, B.boxm(Vector3(H.x * 2.0, 0.1, H.y * 2.0)), c + Vector3(0, -0.05, 0), Color(0.3, 0.22, 0.16))
	_wall(Vector2(c.x - H.x, -H.y), Vector2(c.x + H.x, -H.y), 2.4, dark)
	_wall(Vector2(c.x - H.x, -H.y), Vector2(c.x - H.x, H.y), 2.4, dark)
	_wall(Vector2(c.x + H.x, -H.y), Vector2(c.x + H.x, H.y), 2.4, dark)
	_wall(Vector2(c.x - H.x, H.y), Vector2(c.x + H.x, H.y), 0.6, dark, WALL_H)
	# Kajuutan pyöreät "ikkunat" messinkikehyksin, köysi kaiteena ja ankkuri seinällä.
	for k in 4:
		var px := c.x - 1.0 + k * 1.6
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.24
		tm.outer_radius = 0.31
		ring.mesh = tm
		ring.material_override = B.mat(brass)
		ring.rotation.x = PI / 2.0
		ring.position = Vector3(px, 1.7, -H.y + 0.15)
		add_child(ring)
		var glass := B.mesh(self, B.cyl(0.24, 0.24, 0.02, 16), Vector3(px, 1.7, -H.y + 0.13), Color.WHITE, Vector3(90, 0, 0))
		glass.material_override = B.unshaded(Color(0.08, 0.18, 0.35))
	B.tube(self, Vector3(c.x - 1.4, 1.2, -H.y + 0.18), Vector3(c.x + 5.0, 1.2, -H.y + 0.18), 0.035, Color(0.8, 0.7, 0.5))
	var anchor := Node3D.new()
	anchor.position = Vector3(c.x + H.x - 0.15, 1.5, 0.0)
	anchor.rotation.y = -PI / 2.0
	add_child(anchor)
	B.mesh(anchor, B.boxm(Vector3(0.08, 1.0, 0.06)), Vector3.ZERO, Color(0.25, 0.25, 0.27))
	B.mesh(anchor, B.boxm(Vector3(0.5, 0.06, 0.06)), Vector3(0, 0.4, 0), Color(0.25, 0.25, 0.27))
	B.mesh(anchor, B.boxm(Vector3(0.7, 0.08, 0.06)), Vector3(0, -0.48, 0), Color(0.25, 0.25, 0.27), Vector3(0, 0, 0))
	var net := B.mesh(self, B.boxm(Vector3(2.2, 1.2, 0.02)), Vector3(c.x + 3.0, 1.75, -H.y + 0.12), Color(0.6, 0.55, 0.4))
	net.transparency = 0.5
	var old := B.label(self, "KAJUUTTA", Vector3(c.x + 3.0, 2.15, -H.y + 0.16), 34, Color(0.8, 0.7, 0.45))
	old.outline_size = 6
	var sign := B.sign_plate(self, "KAPTEENIN KELLARI", Color(0.45, 0.06, 0.06), Color(1.0, 0.9, 0.55), 0.45, 70, Color(0.2, 0.02, 0.02), "Helvetica Neue")
	sign.position = c + Vector3(-1.2, 2.05, -H.y + 0.12)
	# Pieni tiski takaseinällä ja karaokelava vasemmassa etunurkassa ruutuineen.
	_solid(Vector3(3.4, 1.1, 0.7), c + Vector3(1.5, 0.55, -3.7), Color(0.22, 0.13, 0.07))
	B.mesh(self, B.boxm(Vector3(3.6, 0.06, 0.85)), c + Vector3(1.5, 1.13, -3.7), Color(0.12, 0.08, 0.05))
	var sc := STAGE.get_center()
	_solid(Vector3(STAGE.size.x, 0.3, STAGE.size.y), c + Vector3(sc.x, 0.15, sc.y), Color(0.1, 0.08, 0.1))
	B.mesh(self, B.boxm(Vector3(STAGE.size.x + 0.05, 0.05, 0.06)), c + Vector3(sc.x, 0.28, STAGE.position.y), brass)
	B.mesh(self, B.cyl(0.02, 0.02, 1.5, 6), c + Vector3(-4.9, 1.05, 2.6), Color(0.15, 0.15, 0.15))
	B.mesh(self, B.sphere(0.05, 8), c + Vector3(-4.9, 1.82, 2.6), Color(0.3, 0.3, 0.32))
	B.mesh(self, B.boxm(Vector3(0.08, 1.2, 2.2)), Vector3(c.x - H.x + 0.12, 1.6, 2.6), Color(0.05, 0.05, 0.06))
	var scr := B.mesh(self, B.boxm(Vector3(0.09, 1.05, 2.0)), Vector3(c.x - H.x + 0.13, 1.6, 2.6), Color.WHITE)
	scr.material_override = B.unshaded(Color(0.08, 0.12, 0.35))
	_screen = B.label(self, "KAPTEENIN KELLARI\nKaraoke · valitse biisi", Vector3(c.x - H.x + 0.2, 1.6, 2.6), 28, Color(1.0, 0.9, 0.2))
	_screen.rotation.y = PI / 2.0
	_screen.width = 380.0
	_screen.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Pöydät ja tuolit, portaat ylös oikeassa etunurkassa.
	for t in [c + Vector3(2.4, 0, 2.0), c + Vector3(0.0, 0, 0.6), c + Vector3(3.6, 0, -0.8)]:
		_table(t)
	for ch in [c + Vector3(3.2, 0, 2.0), c + Vector3(2.4, 0, 2.8), c + Vector3(0.0, 0, 1.4), c + Vector3(-0.8, 0, 0.6), c + Vector3(3.6, 0, 0.0)]:
		_chair(ch)
	for k in 4:
		B.mesh(self, B.boxm(Vector3(1.2, 0.03, 0.3)), c + Vector3(6.2, 0.02 + k * 0.0, 3.0 + k * 0.3), Color(0.4, 0.28, 0.16).lightened(0.1 * k))
	var yl := B.label(self, "↑ KULMA", c + Vector3(6.2, 2.0, 2.8), 26, Color(1.0, 0.85, 0.3))
	yl.outline_size = 6
	_light(c + Vector3(0.0, 2.2, -1.0), Color(1.0, 0.75, 0.45), 0.6, 8.0)
	for col in [Color(1.0, 0.2, 0.5), Color(0.2, 0.5, 1.0), Color(0.3, 1.0, 0.4)]:
		_lights.append(_light(c + Vector3(-5.0 + randf_range(-1.0, 1.0), 2.2, 2.4 + randf_range(-1.0, 1.0)), col, 0.8, 5.0))


## Istuva hahmo (katse face-suuntaan) törmäyksellä.
func _seat(look: Dictionary, at: Vector3, face: Vector3) -> Node3D:
	var c := Looks.make(self, look)
	c.position = at + Vector3(0, 0.02, 0)
	c.rotation.y = B.yaw_to(face)
	c.play("Sitting_Idle", 0.0)
	c.set_meta("sitting", true)
	var body := StaticBody3D.new()
	body.position = at
	body.add_child(B.capsule_shape(0.3, 1.4))
	add_child(body)
	_add_bubble(c)
	return c


func _stand(look: Dictionary, at: Vector3, face: Vector3) -> Node3D:
	var c := Looks.make(self, look)
	c.position = at
	c.rotation.y = B.yaw_to(face)
	c.play("Idle", 0.0)
	var body := StaticBody3D.new()
	body.position = at
	body.add_child(B.capsule_shape(0.3, 1.8))
	add_child(body)
	_add_bubble(c)
	return c


func _add_bubble(c: Node3D) -> void:
	var b := B.label(c, "", Vector3(0, 2.15, 0), 30, Color.WHITE, true)
	b.outline_size = 8
	b.width = 560.0
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bubbles[c] = b


## Kapteenin lakki: tummansininen kupu, valkoinen yläosa, musta lippa ja kultainen ankkurimerkki.
func _captain_cap(c: Node3D) -> void:
	var cap := Node3D.new()
	B.mesh(cap, B.cyl(0.115, 0.1, 0.08, 16), Vector3(0, 0.0, 0), Color(0.06, 0.08, 0.18))
	B.mesh(cap, B.cyl(0.13, 0.115, 0.04, 16), Vector3(0, 0.06, -0.01), Color(0.95, 0.95, 0.93))
	B.mesh(cap, B.boxm(Vector3(0.18, 0.015, 0.08)), Vector3(0, -0.03, 0.12), Color(0.04, 0.04, 0.04), Vector3(-15, 0, 0))
	B.mesh(cap, B.sphere(0.02, 6), Vector3(0, 0.01, 0.11), Color(0.95, 0.75, 0.25))
	c.attach("Head", cap, Vector3(0, 0.15, 0.0))


func _build_people() -> void:
	var hivis := {"shirt": Color(1.0, 0.45, 0.05), "pants": Color(0.1, 0.12, 0.2), "shoes": Color(0.1, 0.08, 0.06),
		"stripes": true, "stripe_color": Color(0.85, 0.85, 0.8)}
	_bartender = _stand({"shirt": Color(0.06, 0.06, 0.08), "pants": Color(0.06, 0.06, 0.08), "shoes": Color(0.05, 0.05, 0.05),
		"hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.22, 0.15), "beard": true, "height": 1.84}, Vector3(0.6, 0, -4.8), Vector3(0, 0, 1))
	# Terästehtaan porukka yövuoron jälkeen: Tero ja kaksi työkaveria huomioliiveissä.
	_tero = _seat(Looks.TERO, Vector3(5.2, 0, -0.2), Vector3(0, 0, 1))
	var w1 := hivis.duplicate()
	w1.merge({"hair": "Hair_SimpleParted", "hair_color": Color(0.4, 0.3, 0.2), "height": 1.8, "belly": 0.5})
	var w2 := hivis.duplicate()
	w2.merge({"model": "female", "hair": "Hair_Long", "hair_color": Color(0.55, 0.3, 0.15), "height": 1.7})
	_ruukki.append(_seat(w1, Vector3(4.4, 0, 0.6), Vector3(1, 0, 0)))
	_ruukki.append(_seat(w2, Vector3(6.0, 0, 0.6), Vector3(-1, 0, 0)))
	_ruukki.append(_tero)
	# Vanha kapteeni ikkunapöydässä Kirkkokadun puolella: merikapteenin takki ja lakki, valkoinen parta.
	_kapteeni = _seat({"shirt": Color(0.06, 0.08, 0.2), "pants": Color(0.06, 0.08, 0.2), "shoes": Color(0.05, 0.05, 0.05),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.92, 0.92, 0.9), "beard": true, "height": 1.74,
		"skin": Color(1.0, 0.86, 0.8), "belly": 0.4, "stripes": true, "stripe_color": Color(0.9, 0.75, 0.3)},
		Vector3(-7.8, 0, 1.4), Vector3(1, 0, 0))
	_captain_cap(_kapteeni)
	# Visamestari visapöydän luona kysymyspapereineen.
	_quizmaster = _stand({"shirt": Color(0.55, 0.12, 0.12), "pants": Color(0.25, 0.25, 0.3), "shoes": Color(0.2, 0.15, 0.1),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.2, 0.15, 0.1), "height": 1.76}, Vector3(-1.6, 0, 0.0), Vector3(0, 0, 1))
	# Asiakas ikkunapöydässä ja Kellarin karaokeporukka.
	_seat(Looks.GRANDPAS[1], Vector3(-4.2, 0, -0.6), Vector3(0, 0, -1))
	_cellar_bartender = _stand({"model": "female", "shirt": Color(0.1, 0.1, 0.12), "pants": Color(0.1, 0.1, 0.12),
		"shoes": Color(0.05, 0.05, 0.05), "hair": "Hair_Buns", "hair_color": Color(0.15, 0.1, 0.08), "height": 1.68},
		CELLAR + Vector3(1.5, 0, -4.3), Vector3(0, 0, 1))
	_kellari.append(_seat({"model": "female", "shirt": Color(0.85, 0.3, 0.6), "pants": Color(0.1, 0.1, 0.15), "shoes": Color(0.9, 0.9, 0.9),
		"hair": "Hair_Long", "hair_color": Color(0.9, 0.75, 0.4), "height": 1.66}, CELLAR + Vector3(2.4, 0, 2.8), Vector3(0, 0, -1)))
	_kellari.append(_seat(hivis.merged({"hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.25, 0.2), "height": 1.82, "belly": 0.3}),
		CELLAR + Vector3(0.0, 0, 1.4), Vector3(0, 0, -1)))
	_singer = _seat({"model": "female", "shirt": Color(0.2, 0.55, 0.75), "pants": Color(0.12, 0.12, 0.15), "shoes": Color(0.1, 0.1, 0.1),
		"hair": "Hair_Buns", "hair_color": Color(0.85, 0.55, 0.25), "height": 1.64}, CELLAR + Vector3(3.2, 0, 2.0), Vector3(-1, 0, 0))
	_kellari.append(_singer)
