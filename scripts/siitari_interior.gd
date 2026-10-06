extends Node3D
## Hotelli-Ravintola Siitarin baari sisältä (erillinen tasku kuten mökin tupa): pitkä baaritiski pullohyllyineen
## ja baarimikko, karaokelava ruutuineen ja tanssilattia, pöydät, pajatso ja jukeboksi. Asiakkaina romaniseurue
## (naisilla perinteiset samettihameet ja pitsipuserot, miehillä tummat puvut; välillä joku heistä laulaa
## karaokea), pari paikallista korttipelissä ja naapurin Sinikka baaritiskillä.
## Kävely player_walker.gd:llä ylhäältä kuvattuna. Toiminnot ilmoitetaan acted-signaalilla (valikot, karaoke,
## Sinikka ja Päivin motkotus main.gd:ssä), ulko-ovelta exited (mopolla takaisin Paapeliin).
## Paikallinen +X = ulko-ovi ja parkkipaikka, -Z = baaritiski takaseinällä, +Z = tien puoli (kamera).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(8.0, 5.5)
const WALL_H := 3.0
const STAGE := Rect2(-8.0, 1.2, 3.6, 4.3)  # karaokelava vasemmassa etunurkassa
const DANCE := Vector3(-2.6, 0, 3.2)       # tanssilattian keskikohta lavan edessä
## Toimintopisteet: id -> [paikka, vihje]. Sinikan paikka päivittyy (tanssilattialla eri kohdassa).
var spot := ""  # lähin toimintopiste (main.gd näyttää puhuttaville puhevihjeen)
var spots := {
	"ovi": [Vector3(7.2, 0, 3.4), "[E] Ulos ja mopolla takaisin Paapeliin"],
	"tiski": [Vector3(-4.2, 0, -3.3), "[E] Tilaa baaritiskiltä"],
	"karaoke": [Vector3(-4.0, 0, 2.2), "[E] Laula karaokea (2 €)"],
	"sinikka": [Vector3(-0.6, 0, -3.3), "[E] Sinikka baaritiskillä"],
	"seurue": [Vector3(2.6, 0, 1.3), "[E] Juttele pöytäseurueen kanssa"],
	"pajatso": [Vector3(6.6, 0, -4.2), "[E] Pelaa pajatsoa (1 €)"],
	"kortit": [Vector3(3.6, 0, -1.2), "[E] Katso korttipeliä"],
}
const SEURUE_LINES := [
	"Istu vaan! Mistäs päin sitä ollaan?", "Paapelista mopolla? Sehän on ihan tuossa lähellä.",
	"Täällä on karaokessa hyvä äänentoisto. Laula sinäkin jotain!", "Meillä on serkun synttärit, tultiin koko porukalla.",
	"Oulujoen rannalla on kaunista näin iltaisin.", "Kahvia ja pullaa, se on parasta.",
	"Siitarissa on aina hyvä tunnelma, kun joku laulaa.", "Onko sulla Päivi kotona? Kannattaa soittaa sille välillä!",
]
const SINGER_LINES := ["♪ Vaalan illassa joki virtaa hiljaa... ♪", "♪ Sä olit mun kesäni ja syksyni myös... ♪",
	"♪ Mopolla kotiin kuutamossa... ♪", "♪ Tanssi kanssani vielä kerran... ♪"]
const BARTENDER_LINES := ["Mitäs laitetaan?", "Karaoke alkaa kun joku uskaltaa.", "Sinikka käy täällä joka viikko.",
	"Mopo on hyvässä turvassa ikkunan alla.", "Pajatso antaa joskus. Harvoin, mutta joskus."]
const CARD_LINES := ["\"Tuplaan!\"", "\"Ässä! Kuka jakoi tän?\"", "\"Hertta on valttia.\"", "\"Vielä yksi jako, sitten kotiin.\""]

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var sinikka_dancing := false
var _enter_frame := -1

var _bartender: Node3D
var _sinikka: Node3D
var _seurue: Array[Node3D] = []
var _singer: Node3D
var _cardplayers: Array[Node3D] = []
var _bubbles := {}  # hahmo -> [Label3D, aika]
var _screen: Label3D
var _lights: Array[OmniLight3D] = []
var _disco: MeshInstance3D
var _sing_t := 8.0
var _singing := 0.0
var _chat_t := 6.0
var _dance_t := 0.0
var _t := 0.0


func _ready() -> void:
	_build_room()
	_build_bar()
	_build_stage()
	_build_tables()
	_build_people()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	add_child(walker)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(-1.2, 0, 0)
	walker.rotation.y = B.yaw_to(Vector3(1, 0, 0))
	walker.activate()
	say(_bartender, "Iltaa! Tervetuloa Siitariin.")


func leave() -> void:
	active = false
	walker.controls_enabled = false
	sinikka_dancing = false
	_place_sinikka()


func say(who: Node3D, text: String, t := 3.2) -> void:
	var b: Label3D = _bubbles[who]
	b.text = text
	b.set_meta("t", t)
	if who == _singer and _singing > 0.0:
		return
	if who in _seurue or who in _cardplayers:
		who.play("Sitting_Talking", 0.3)
	elif not (who == _sinikka and sinikka_dancing):
		who.play("Idle_Talking", 0.3)


func sinikka_say(text: String) -> void:
	say(_sinikka, text, 3.6)


func bartender_say(text: String) -> void:
	say(_bartender, text)


## Tanssi Sinikan kanssa tanssilattialla: molemmat tanssivat hetken, sitten takaisin tiskille.
func dance_with_sinikka(seconds: float) -> void:
	sinikka_dancing = true
	_dance_t = seconds
	_sinikka.position = DANCE + Vector3(0.7, 0, 0)
	_sinikka.rotation.y = B.yaw_to(Vector3(-1, 0, 0))
	_sinikka.play("Dance", 0.3)
	walker.controls_enabled = false
	walker.position = DANCE + Vector3(-0.7, 0, 0)
	walker.rotation.y = B.yaw_to(Vector3(-1, 0, 0))
	walker._body.play("Dance", 0.3)
	busy = true


func _place_sinikka() -> void:
	_sinikka.position = Vector3(-0.6, 0, -2.6)
	_sinikka.rotation.y = B.yaw_to(Vector3(0.3, 0, 1))
	_sinikka.play("Idle", 0.3)


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
			if who == _sinikka and sinikka_dancing:
				continue
			if who in _seurue or who in _cardplayers:
				who.play("Sitting_Idle", 0.3)
			elif not (who == _singer and _singing > 0.0):
				who.play("Idle", 0.3)
	# Karaokeruutu ja valot sykkivät, discopallo pyörii.
	_disco.rotation.y += delta * 0.8
	for i in _lights.size():
		_lights[i].light_energy = 0.9 + 0.6 * maxf(sin(_t * 3.0 + i * 2.1), 0.0)
	# Seurueen laulaja käy välillä lavalla, kun pelaaja ei laula.
	if not busy:
		_sing_t -= delta
		if _singing > 0.0:
			_singing -= delta
			if _singing <= 0.0:
				_singer.position = Vector3(2.0, 0, 3.4)
				_singer.rotation.y = B.yaw_to(Vector3(0, 0, -1))
				_singer.play("Sitting_Idle", 0.3)
				_screen.text = "KARAOKE\nValitse biisi"
		elif _sing_t <= 0.0:
			_sing_t = randf_range(25.0, 40.0)
			_singing = 9.0
			_singer.position = Vector3(-6.0, 0.35, 3.0)
			_singer.rotation.y = B.yaw_to(Vector3(1, 0, 0.3))
			_singer.play("Idle_Talking", 0.3)
			var line: String = SINGER_LINES.pick_random()
			say(_singer, line, 8.5)
			_screen.text = line.replace("♪ ", "").replace(" ♪", "")
	if sinikka_dancing:
		_dance_t -= delta
		if _dance_t <= 0.0:
			sinikka_dancing = false
			busy = false
			_place_sinikka()
			walker.controls_enabled = active
			walker._body.play("Idle", 0.3)
			acted.emit("tanssi_loppu")
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(10.0, 18.0)
		match randi() % 3:
			0:
				say(_seurue.pick_random(), SEURUE_LINES.pick_random())
			1:
				say(_cardplayers.pick_random(), CARD_LINES.pick_random())
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
	spot = best
	if best == "":
		return
	hint = spots[best][1]
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	match best:
		"ovi":
			exited.emit()
		"seurue":
			say(_seurue.pick_random(), SEURUE_LINES.pick_random())
		"kortit":
			say(_cardplayers.pick_random(), CARD_LINES.pick_random())
		_:
			acted.emit(best)


## Valikosta palatessa sama E-painallus ei saa avata uutta toimintoa.
func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


## Karaokeruudun teksti (karaoke_game.gd päivittää laulaessa).
func set_screen(text: String) -> void:
	_screen.text = text


## Pelaaja lavalle mikin taakse (karaoke).
func to_stage() -> void:
	busy = true
	walker.controls_enabled = false
	walker.position = Vector3(-6.0, 0.35, 3.0)
	walker.rotation.y = B.yaw_to(Vector3(-1, 0, -0.3))
	walker._body.play("Idle", 0.2)
	if _singing > 0.0:
		_singing = 0.01


func from_stage(cheer: bool) -> void:
	busy = false
	walker.position = spots.karaoke[0]
	walker.controls_enabled = active
	_screen.text = "KARAOKE\nValitse biisi"
	if cheer:
		for s in _seurue:
			s.play("Sitting_Talking", 0.2)
		say(_seurue[0], "Bravo! Vielä toinen!")
		say(_sinikka, "Ihana ääni... laula mulle joskus uudestaan.")
	else:
		say(_cardplayers[0], "Korvat soi vieläkin.")


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


func _build_room() -> void:
	var wood := Color(0.36, 0.22, 0.13)  # tumma puupaneeli kuten ulkoverhous
	B.mesh(self, B.boxm(Vector3(80, 0.2, 80)), Vector3(0, -0.2, 0), Color(0.08, 0.07, 0.07))
	# Lattia: ruskea laminaatti, tanssilattia mustavalkoisena shakkiruutuna.
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), Color(0.42, 0.28, 0.18))
	for i in 20:
		B.mesh(self, B.boxm(Vector3(0.02, 0.01, HALF.y * 2.0)), Vector3(-HALF.x + 0.4 + i * 0.8, 0.005, 0), Color(0.33, 0.21, 0.13))
	for ix in 5:
		for iz in 4:
			var q := DANCE + Vector3((ix - 2) * 0.8, 0.01, (iz - 1.5) * 0.8)
			B.mesh(self, B.boxm(Vector3(0.8, 0.02, 0.8)), q, Color(0.92, 0.9, 0.86) if (ix + iz) % 2 == 0 else Color(0.08, 0.08, 0.1))
	# Ulkoseinät: taka ja päädyt täyskorkeat, etuseinä matala (kamera), törmäys täyskorkea.
	_wall(Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, -HALF.y), WALL_H, wood)
	_wall(Vector2(-HALF.x, -HALF.y), Vector2(-HALF.x, HALF.y), WALL_H, wood)
	_wall(Vector2(HALF.x, -HALF.y), Vector2(HALF.x, 2.6), WALL_H, wood)
	_wall(Vector2(HALF.x, 4.2), Vector2(HALF.x, HALF.y), WALL_H, wood)
	_wall(Vector2(-HALF.x, HALF.y), Vector2(HALF.x, HALF.y), 0.6, wood)
	# Ulko-ovi (lasiovi) päädyssä ja isot ikkunat tien puolelle (matalan seinän reunassa näkyy karmi).
	B.mesh(self, B.boxm(Vector3(0.08, 2.3, 1.6)), Vector3(HALF.x - 0.02, 1.15, 3.4), Color(0.85, 0.85, 0.82))
	B.mesh(self, B.boxm(Vector3(0.1, 2.1, 1.4)), Vector3(HALF.x - 0.03, 1.1, 3.4), Color(0.3, 0.42, 0.45))
	B.label(self, "ULOS", Vector3(HALF.x - 0.1, 2.5, 3.4), 40, Color(0.3, 1.0, 0.4)).rotation.y = -PI / 2.0
	for wx in [-4.5, -0.5, 3.5]:
		B.mesh(self, B.boxm(Vector3(3.0, 0.1, 0.12)), Vector3(wx, 0.62, HALF.y), Color(0.9, 0.88, 0.8))
	# Päätyseinän ikkunoista näkyy ilta.
	for wz in [-2.5, 0.5]:
		B.mesh(self, B.boxm(Vector3(0.08, 1.4, 1.8)), Vector3(-HALF.x + 0.12, 1.7, wz), Color(0.9, 0.88, 0.8))
		B.mesh(self, B.boxm(Vector3(0.09, 1.2, 1.6)), Vector3(-HALF.x + 0.13, 1.7, wz), Color(0.18, 0.22, 0.38))
	# Seinäkoristeet: kalastusjulisteita ja vanha Karhu-kyltti.
	var sign := B.sign_plate(self, "SIITARI", Color(0.55, 0.05, 0.06), Color(1.0, 0.92, 0.6), 0.7, 90, Color(0.3, 0.02, 0.03), "Helvetica Neue")
	sign.position = Vector3(2.5, 2.35, -HALF.y + 0.12)
	B.mesh(self, B.boxm(Vector3(1.2, 0.8, 0.04)), Vector3(5.5, 1.9, -HALF.y + 0.12), Color(0.2, 0.35, 0.55))
	B.label(self, "Oulujoen\nlohet 1978", Vector3(5.5, 1.9, -HALF.y + 0.16), 26, Color(0.95, 0.92, 0.8))
	# Valaistus: lämmin yleisvalo ja värilliset lavavalot.
	for l in [Vector3(-4.0, 2.7, -2.0), Vector3(3.0, 2.7, -2.0), Vector3(3.0, 2.7, 2.5)]:
		var light := OmniLight3D.new()
		light.position = l
		light.omni_range = 9.0
		light.light_energy = 0.7
		light.light_color = Color(1.0, 0.85, 0.65)
		add_child(light)
	for c in [Color(1.0, 0.2, 0.5), Color(0.2, 0.5, 1.0), Color(0.3, 1.0, 0.4)]:
		var light := OmniLight3D.new()
		light.position = DANCE + Vector3(randf_range(-2.0, 2.0), 2.6, randf_range(-1.0, 1.0))
		light.omni_range = 5.0
		light.light_color = c
		add_child(light)
		_lights.append(light)
	_disco = B.mesh(self, B.sphere(0.3, 12), DANCE + Vector3(0, 2.7, 0), Color(0.85, 0.85, 0.9))
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.9, 0.9, 0.95)
	dm.metallic = 1.0
	dm.roughness = 0.15
	_disco.material_override = dm


## Baaritiski takaseinällä: tumma puutiski messinkitangolla, jakkarat, hanat, takana pullohylly ja peili.
func _build_bar() -> void:
	var counter := Color(0.28, 0.16, 0.09)
	_solid(Vector3(7.0, 1.1, 0.8), Vector3(-3.5, 0.55, -3.9), counter)
	B.mesh(self, B.boxm(Vector3(7.2, 0.06, 0.95)), Vector3(-3.5, 1.13, -3.9), Color(0.15, 0.1, 0.06))
	B.tube(self, Vector3(-7.0, 0.2, -3.42), Vector3(0.0, 0.2, -3.42), 0.03, Color(0.8, 0.65, 0.3))
	# Hanat: Karhu ja Lapin Kulta -tyyliset hanakahvat.
	for i in 4:
		var x := -5.5 + i * 0.5
		B.mesh(self, B.cyl(0.03, 0.03, 0.3, 8), Vector3(x, 1.3, -4.05), Color(0.8, 0.8, 0.82))
		B.mesh(self, B.boxm(Vector3(0.06, 0.18, 0.04)), Vector3(x, 1.53, -4.05), [Color(0.05, 0.05, 0.05), Color(0.85, 0.7, 0.2), Color(0.1, 0.3, 0.6), Color(0.7, 0.1, 0.1)][i])
	# Jakkarat.
	for i in 6:
		var x := -6.4 + i * 1.1
		B.mesh(self, B.cyl(0.05, 0.05, 0.75, 8), Vector3(x, 0.37, -3.1), Color(0.6, 0.6, 0.62))
		B.mesh(self, B.cyl(0.22, 0.22, 0.08, 14), Vector3(x, 0.78, -3.1), Color(0.55, 0.08, 0.08))
	# Takahylly ja pullot, peili.
	B.mesh(self, B.boxm(Vector3(6.6, 1.2, 0.05)), Vector3(-3.5, 2.0, -HALF.y + 0.1), Color(0.55, 0.6, 0.65))
	for shelf in 2:
		var y := 1.45 + shelf * 0.55
		B.mesh(self, B.boxm(Vector3(6.6, 0.04, 0.3)), Vector3(-3.5, y, -HALF.y + 0.25), Color(0.2, 0.12, 0.07))
		for i in 22:
			var col: Color = [Color(0.2, 0.45, 0.2), Color(0.55, 0.3, 0.1), Color(0.85, 0.85, 0.9), Color(0.4, 0.1, 0.1), Color(0.8, 0.6, 0.2)][(i * 7 + shelf) % 5]
			B.mesh(self, B.cyl(0.04, 0.05, 0.3, 8), Vector3(-6.6 + i * 0.29, y + 0.17, -HALF.y + 0.25), col)
	_solid(Vector3(2.0, 0.9, 0.6), Vector3(-6.8, 0.45, -5.0), Color(0.5, 0.5, 0.52))  # kylmiö
	# Pajatso ja jukeboksi oven puolella.
	B.mesh(self, B.boxm(Vector3(0.9, 1.7, 0.6)), Vector3(6.6, 0.85, -5.0), Color(0.75, 0.1, 0.12))
	B.mesh(self, B.boxm(Vector3(0.7, 0.9, 0.05)), Vector3(6.6, 1.25, -4.68), Color(0.95, 0.85, 0.3))
	B.label(self, "PAJATSO", Vector3(6.6, 1.8, -4.66), 28, Color(1.0, 0.95, 0.8))
	var jb := _solid(Vector3(1.0, 1.5, 0.6), Vector3(4.6, 0.75, -5.0), Color(0.25, 0.12, 0.3))
	jb.material_override = B.unshaded(Color(0.55, 0.25, 0.6))
	B.label(self, "JUKEBOKSI", Vector3(4.6, 1.6, -4.66), 22, Color(1.0, 0.9, 0.5))


## Karaokelava: koroke, mikkiteline, ruutu seinällä sanoille ja kaiuttimet.
func _build_stage() -> void:
	var c := STAGE.get_center()
	_solid(Vector3(STAGE.size.x, 0.35, STAGE.size.y), Vector3(c.x, 0.175, c.y), Color(0.12, 0.1, 0.12))
	B.mesh(self, B.boxm(Vector3(STAGE.size.x + 0.05, 0.05, 0.06)), Vector3(c.x, 0.33, STAGE.position.y), Color(0.9, 0.75, 0.2))
	B.mesh(self, B.cyl(0.02, 0.02, 1.5, 6), Vector3(-5.5, 1.1, 3.0), Color(0.15, 0.15, 0.15))
	B.mesh(self, B.cyl(0.18, 0.18, 0.03, 12), Vector3(-5.5, 0.37, 3.0), Color(0.15, 0.15, 0.15))
	B.mesh(self, B.sphere(0.05, 8), Vector3(-5.5, 1.87, 3.0), Color(0.3, 0.3, 0.32))
	# Ruutu vasemmalla päätyseinällä lavan vieressä, sanat keltaisella.
	B.mesh(self, B.boxm(Vector3(0.08, 1.3, 2.2)), Vector3(-HALF.x + 0.12, 2.0, 3.4), Color(0.05, 0.05, 0.06))
	var scr := B.mesh(self, B.boxm(Vector3(0.09, 1.15, 2.0)), Vector3(-HALF.x + 0.13, 2.0, 3.4), Color(0.1, 0.15, 0.4))
	scr.material_override = B.unshaded(Color(0.08, 0.12, 0.35))
	_screen = B.label(self, "KARAOKE\nValitse biisi", Vector3(-HALF.x + 0.2, 2.0, 3.4), 30, Color(1.0, 0.9, 0.2))
	_screen.rotation.y = PI / 2.0
	_screen.width = 380.0
	_screen.autowrap_mode = TextServer.AUTOWRAP_WORD
	for z in [1.6, 5.0]:
		_solid(Vector3(0.5, 1.0, 0.5), Vector3(-7.5, 0.85, z), Color(0.08, 0.08, 0.08))
		B.mesh(self, B.cyl(0.16, 0.16, 0.02, 12), Vector3(-7.24, 1.0, z), Color(0.25, 0.25, 0.27), Vector3(0, 0, 90))


func _build_tables() -> void:
	# Pyöreät pöydät tuoleineen: seurueen kaksi pöytää yhteen ja korttipöytä.
	for t in [Vector3(2.0, 0, 2.6), Vector3(3.6, 0, 2.6), Vector3(3.6, 0, -1.9), Vector3(0.6, 0, -0.2)]:
		B.mesh(self, B.cyl(0.55, 0.55, 0.05, 16), t + Vector3(0, 0.75, 0), Color(0.3, 0.18, 0.1))
		B.mesh(self, B.cyl(0.06, 0.06, 0.75, 8), t + Vector3(0, 0.37, 0), Color(0.2, 0.2, 0.2))
		var body := StaticBody3D.new()
		body.position = t
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.55
		cyl.height = 1.0
		cs.shape = cyl
		cs.position.y = 0.5
		body.add_child(cs)
		add_child(body)
		# Kahvikupit ja tuopit pöydälle.
		B.mesh(self, B.cyl(0.04, 0.035, 0.14, 8), t + Vector3(0.2, 0.85, 0.1), Color(0.95, 0.8, 0.3))
		B.mesh(self, B.cyl(0.045, 0.04, 0.08, 8), t + Vector3(-0.2, 0.82, -0.1), Color(0.95, 0.95, 0.95))
	for ch in [Vector3(2.0, 0, 3.4), Vector3(3.6, 0, 3.4), Vector3(2.0, 0, 1.8), Vector3(3.6, 0, 1.8), Vector3(4.4, 0, 2.6),
			Vector3(3.6, 0, -1.1), Vector3(3.6, 0, -2.7), Vector3(0.6, 0, 0.6)]:
		B.mesh(self, B.boxm(Vector3(0.45, 0.06, 0.45)), ch + Vector3(0, 0.45, 0), Color(0.35, 0.2, 0.12))
		for dx in [-0.18, 0.18]:
			for dz in [-0.18, 0.18]:
				B.mesh(self, B.cyl(0.02, 0.02, 0.45, 6), ch + Vector3(dx, 0.22, dz), Color(0.2, 0.2, 0.2))
	# Korttipöydälle pakka ja kortit.
	for i in 5:
		B.mesh(self, B.boxm(Vector3(0.07, 0.005, 0.1)), Vector3(3.5 + i * 0.06, 0.785, -1.9 + (i % 2) * 0.05), Color(0.95, 0.95, 0.95))


## Istuva hahmo tuolille (katse pöytään päin) törmäyksellä.
func _seat(look: Dictionary, at: Vector3, face: Vector3) -> Node3D:
	var c := Looks.make(self, look)
	c.position = at + Vector3(0, 0.02, 0)
	c.rotation.y = B.yaw_to(face)
	c.play("Sitting_Idle", 0.0)
	var body := StaticBody3D.new()
	body.position = at
	body.add_child(B.capsule_shape(0.3, 1.4))
	add_child(body)
	_add_bubble(c)
	return c


func _add_bubble(c: Node3D) -> void:
	var b := B.bubble(c, Vector3(0, 1.85, 0), Color.WHITE, 0.7)
	_bubbles[c] = b


func _build_people() -> void:
	_bartender = Looks.make(self, {"shirt": Color(0.95, 0.95, 0.93), "pants": Color(0.08, 0.08, 0.1), "shoes": Color(0.08, 0.08, 0.08),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.25, 0.18, 0.12), "beard": true, "height": 1.8, "belly": 0.4})
	_bartender.position = Vector3(-4.2, 0, -4.8)
	_bartender.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_bartender.play("Idle", 0.0)
	_add_bubble(_bartender)
	_sinikka = Looks.make(self, Looks.SINIKKA)
	_add_bubble(_sinikka)
	var sb := StaticBody3D.new()
	sb.position = Vector3(-0.6, 0, -2.6)
	sb.add_child(B.capsule_shape(0.3, 1.8))
	add_child(sb)
	_place_sinikka()
	# Romaniseurue: naisilla mustat samettihameet ja pitsipuserot, miehillä tummat puvut ja valkoiset paidat.
	var skirt := Color(0.04, 0.04, 0.05)
	var looks := [
		{"model": "female", "shirt": Color(0.95, 0.92, 0.95), "pants": skirt, "shoes": Color(0.05, 0.05, 0.05), "hair": "Hair_Buns",
			"hair_color": Color(0.08, 0.06, 0.05), "height": 1.62, "skin": Color(0.92, 0.76, 0.62), "shine": 0.7},
		{"shirt": Color(0.1, 0.1, 0.12), "pants": Color(0.1, 0.1, 0.12), "shoes": Color(0.05, 0.05, 0.05), "hair": "Hair_SimpleParted",
			"hair_color": Color(0.06, 0.05, 0.05), "height": 1.78, "skin": Color(0.9, 0.74, 0.6), "belly": 0.3},
		{"model": "female", "shirt": Color(0.75, 0.15, 0.35), "pants": skirt, "shoes": Color(0.05, 0.05, 0.05), "hair": "Hair_Long",
			"hair_color": Color(0.1, 0.07, 0.05), "height": 1.66, "skin": Color(0.92, 0.76, 0.62), "shine": 0.7},
		{"shirt": Color(0.14, 0.14, 0.18), "pants": Color(0.14, 0.14, 0.18), "shoes": Color(0.05, 0.05, 0.05), "hair": "Hair_Buzzed",
			"hair_color": Color(0.12, 0.1, 0.08), "beard": true, "height": 1.82, "skin": Color(0.9, 0.74, 0.6)},
	]
	var seats := [[Vector3(2.0, 0, 1.8), Vector3(0, 0, 1)], [Vector3(3.6, 0, 1.8), Vector3(0, 0, 1)],
		[Vector3(3.6, 0, 3.4), Vector3(0, 0, -1)], [Vector3(2.0, 0, 3.4), Vector3(0, 0, -1)]]
	for i in looks.size():
		_seurue.append(_seat(looks[i], seats[i][0], seats[i][1]))
	_singer = _seurue[3]
	# Paikalliset korttipelissä.
	_cardplayers.append(_seat(Looks.GRANDPAS[0], Vector3(3.6, 0, -1.1), Vector3(0, 0, -1)))
	_cardplayers.append(_seat(Looks.GRANDPAS[2], Vector3(3.6, 0, -2.7), Vector3(0, 0, 1)))
