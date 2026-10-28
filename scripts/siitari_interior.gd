extends Node3D
## Hotelli-Ravintola Siitarin baari sisältä (erillinen tasku kuten mökin tupa): pitkä baaritiski pullohyllyineen
## ja baarimikko, karaokelava ruutuineen ja tanssilattia, pöydät, pajatso ja jukeboksi. Asiakkaina romaniseurue
## (naisilla perinteiset samettihameet ja pitsipuserot, miehillä tummat puvut; välillä joku heistä laulaa
## karaokea), pari paikallista korttipelissä ja naapurin Sinikka baaritiskillä.
## Kävely player_walker.gd:llä ylhäältä kuvattuna. Toiminnot ilmoitetaan acted-signaalilla (valikot, karaoke,
## Sinikka ja Päivin motkotus main.gd:ssä), ulko-ovelta exited (mopolla takaisin Paapeliin).
## Paikallinen +X = ulko-ovi ja parkkipaikka, -Z = baaritiski takaseinällä, +Z = tien puoli (kamera).
## Hotelli (HOTEL, samassa taskussa, mutta Vaalassa oma rakennus ravintolan takana): vastaanotto, käytävän ovet ja
## huone 12, jossa Dingo-yhtye kiertueellaan hajottaa hotellihuonetta (tuoli lentää, telkkari lattialla, patja
## seinää vasten). Sisään vain hotellin omasta ovesta (main.gd "hotelli"), baarista ei ole käyntiä hotelliin.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(8.0, 5.5)
const WALL_H := 3.0
const STAGE := Rect2(-8.0, 1.2, 3.6, 4.3)  # karaokelava vasemmassa etunurkassa
const DANCE := Vector3(-2.6, 0, 3.2)       # tanssilattian keskikohta lavan edessä
## Toimintopisteet: id -> [paikka, vihje]. Sinikan paikka päivittyy (tanssilattialla eri kohdassa).
var spot := ""  # lähin toimintopiste (main.gd näyttää puhuttaville puhevihjeen)
## Lauantaina pajatsolla Raahen jätkät (main.gd asettaa ennen enter-kutsua): pelaavat, kiroilevat ja haastavat
## riitaa; pajatsolla E avaa riidan (main.gd), tappelu Siitarin pihalla (fight.gd).
var raahe_on := false
var _raahe: Array[Node3D] = []
var _raahe_t := 4.0
## Hedelmäpelillä pelaa romaniseurueen kaksi jäsentä joka käynnillä. Vuoron saa kysymällä (main.gd), jolloin he
## siirtyvät tanssilattian laitaan juttelemaan, ja kone on vapaa.
var hedelma_busy := true
var _hedelma: Array[Node3D] = []
const HEDELMA_LINES := ["Kirsikka, kirsikka... ja sitruuna. Voi että!", "Lukitse ne kaks kelloa, Elsa!",
	"Tänään tää kone on ollu nuuka.", "Vielä yks kierros, sitten mennään laulamaan."]
const HEDELMA_AT := [[Vector3(1.4, 0, -4.35), Vector3(0, 0, -1)], [Vector3(2.15, 0, -4.05), Vector3(-0.8, 0, -0.6)]]
const HEDELMA_AWAY := [[Vector3(0.9, 0, 2.3), Vector3(1, 0, 0.2)], [Vector3(1.0, 0, 3.2), Vector3(1, 0, -0.2)]]
const RAAHE_LINES := ["Perkele, taas meni ohi!", "Tää kone on viritetty, sanon mää!", "Mitä sää siinä tuijotat?",
	"Ei oo sun vuoro, äijä. Me pelataan tätä koko ilta.", "Raahessa on paremmat pajatsot.", "Anna sitä kolikkoa, Make!"]
var spots := {
	"ovi": [Vector3(7.2, 0, 3.4), "[E] Ulos ja mopolla takaisin Paapeliin"],
	"tiski": [Vector3(-4.2, 0, -3.3), "[E] Tilaa baaritiskiltä"],
	"karaoke": [Vector3(-4.0, 0, 2.2), "[E] Laula karaokea (2 €)"],
	"sinikka": [Vector3(-0.6, 0, -3.3), "[E] Sinikka baaritiskillä"],
	"seurue": [Vector3(2.6, 0, 1.3), "[E] Juttele pöytäseurueen kanssa"],
	"pajatso": [Vector3(6.6, 0, -4.2), "[E] Pelaa pajatsoa (1 €)"],
	"hedelmapeli": [Vector3(1.4, 0, -4.2), "[E] Pelaa hedelmäpeliä (1 €)"],
	"kortit": [Vector3(3.6, 0, -1.2), "[E] Katso korttipeliä"],
	"jukeboksi": [Vector3(4.4, 0, -4.2), "[E] Jukeboksi: toivo biisi (50 snt)"],
	"hotelli_ovi": [HOTEL + Vector3(-8.2, 0, 0.6), "[E] Ulos ja mopolla takaisin Paapeliin"],
	"vastaanotto": [HOTEL + Vector3(-5.6, 0, -2.4), "[E] Vastaanoton tiski"],
	"dingo": [HOTEL + Vector3(4.2, 0, 1.6), "[E] Huone 12: Dingo"],
}
## Hotellin puoli: alueen keskipiste taskussa ja puolikoko. Väliseinä x = HOTEL_WALL_X (oviaukko z 2,4–4,2)
## erottaa vastaanoton ja käytävän (vasen) huoneesta 12 (oikea).
const HOTEL := Vector3(0, 0, -30)
const HOTEL_HALF := Vector2(9.0, 6.0)
const HOTEL_WALL_X := 0.5
const DINGO_LINES := ["Pori ei kestäny meitä, ei kestä Vaalakaan!", "Huonepalvelu! Lisää kaljaa ja uus telkkari!",
	"Kiertue jatkuu huomenna Kajaaniin. Jos bussi lähtee.", "Tää huone oli valmiiks rikki. Ihan totta.",
	"Rock'n'roll, Vaala!", "Ei me sitä telkkaria heitetty. Se lensi itte.", "Kuka vei mun kampauksen? Ai se on tässä.",
	"Kaheksankymmentäluku ei loppunu, se vaan muutti hotelliin."]
const RECEPTION_LINES := ["Huone kakstoista. Taas.", "Ne maksaa käteisellä ja etukäteen. Ei voi mitään.",
	"Mää en mene sinne. Viimeks lensi lamppu.", "Kahvia? Mää tarviin itte."]
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
var bar_closed := false  # aukioloajat (main.gd): hotellin puolelta ei pääse kiinni olevaan ravintolaan
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


## Rakennetaan vasta ensimmäisellä käynnillä (ensure_built): baari, lava, väki ja hotelli veivät käynnistyksestä 0,17 s.
var built := false


func ensure_built() -> void:
	if built:
		return
	built = true
	_build_room()
	_build_bar()
	_build_stage()
	_build_tables()
	_build_people()
	_build_hotel()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF, HALF * 2.0), Rect2(Vector2(HOTEL.x, HOTEL.z) - HOTEL_HALF, HOTEL_HALF * 2.0)]  # oviaukoista ei ulos
	add_child(walker)


func enter() -> void:
	ensure_built()
	_apply_raahe()
	_place_hedelma(true)
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(-1.2, 0, 0)
	walker.rotation.y = B.yaw_to(Vector3(1, 0, 0))
	walker.activate()
	say(_bartender, "Iltaa! Tervetuloa Siitariin.")


## Raahen jätkät pajatson ääreen tai pois (raahe_on).
func _apply_raahe() -> void:
	if raahe_on and _raahe.is_empty():
		var spots_r := [[Vector3(6.6, 0, -4.05), Vector3(0, 0, -1)], [Vector3(7.6, 0, -3.5), Vector3(-0.8, 0, -0.6)]]
		for i in 2:
			var c := Looks.make(self, Looks.RAAHEN_JATKAT[i])
			c.position = spots_r[i][0]
			c.rotation.y = B.yaw_to(spots_r[i][1])
			c.play("Idle" if i == 0 else "Idle_Talking", 0.0)
			_add_bubble(c)
			var body := StaticBody3D.new()
			body.position = spots_r[i][0]
			body.add_child(B.capsule_shape(0.3, 1.8))
			c.add_child(body)
			body.top_level = true
			_raahe.append(c)
	elif not raahe_on:
		for c in _raahe:
			_bubbles.erase(c)
			c.queue_free()
		_raahe.clear()


func raahe_say(text: String, who := 0) -> void:
	if who < _raahe.size():
		say(_raahe[who], text, 3.5)


## Tappelun jälkeen jätkät lähtevät (hävisivät) tai jäävät pelaamaan (voittivat).
func raahe_leave() -> void:
	raahe_on = false
	_apply_raahe()


## Hedelmäpelin pelaajat koneelle (busy) tai juttelemaan tanssilattian laitaan.
func _place_hedelma(busy_now: bool) -> void:
	hedelma_busy = busy_now
	var at: Array = HEDELMA_AT if busy_now else HEDELMA_AWAY
	for i in _hedelma.size():
		var c := _hedelma[i]
		c.position = at[i][0]
		c.rotation.y = B.yaw_to(at[i][1])
		c.play("Idle" if busy_now and i == 0 else "Idle_Talking", 0.3)
		(c.get_meta("body") as Node3D).position = at[i][0]


## Hedelmäpelin mies (tappeli pihalla) palaa seurueen luo: kone jää vapaaksi.
func hedelma_leave() -> void:
	_place_hedelma(false)


func hedelma_say(text: String, who := 0) -> void:
	if who < _hedelma.size():
		say(_hedelma[who], text, 3.5)


## Seurue antaa vuoron: pelaajat siirtyvät pois koneelta.
func hedelma_free() -> void:
	_place_hedelma(false)


## Hotellin ulko-ovelta suoraan vastaanottoon.
func enter_hotel() -> void:
	enter()
	walker.position = spots.hotelli_ovi[0] + Vector3(1.2, 0, 0)
	walker.rotation.y = B.yaw_to(Vector3(1, 0, 0))
	say(_receptionist, "Tervetuloa Hotelli Siitariin. Huoneet on täynnä. Kiitos vaan Dingolle.")


func in_hotel() -> bool:
	return walker != null and walker.position.z < HOTEL.z + HOTEL_HALF.y + 2.0


func reception_say(text: String) -> void:
	say(_receptionist, text, 3.6)


func dingo_say(text: String) -> void:
	say(_band.pick_random(), text, 3.6)


## Pelaajan apu bändille: telkkari ikkunasta (lentää ikkunasta ulos, lasinsirpaleet).
func throw_tv() -> void:
	_tv.visible = true
	var tw := create_tween()
	var a := _tv.position
	var b := HOTEL + Vector3(6.5, 2.4, -HOTEL_HALF.y - 1.5)
	tw.tween_method(func(t: float) -> void:
		_tv.position = a.lerp(b, t) + Vector3(0, sin(t * PI) * 1.2, 0)
		_tv.rotation = Vector3(t * 5.0, t * 3.0, 0), 0.0, 1.0, 0.9)
	tw.tween_callback(func() -> void:
		Sfx.play("glass", -2.0, 0.8)
		_tv.visible = false)


func leave() -> void:
	active = false
	if not built:
		return
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
	if not built:
		return
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
	# Raahen jätkät kiroilevat pajatsolle ja huutelevat (lauantaisin).
	if not _raahe.is_empty():
		_raahe_t -= delta
		if _raahe_t <= 0.0:
			_raahe_t = randf_range(6.0, 11.0)
			raahe_say(RAAHE_LINES.pick_random(), randi() % _raahe.size())
	if hedelma_busy and not busy and randf() < delta / 9.0:
		hedelma_say(HEDELMA_LINES.pick_random(), randi() % _hedelma.size())
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
	_band_tick(delta)
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	_chat_t -= delta
	if _chat_t <= 0.0 and in_hotel():
		_chat_t = randf_range(6.0, 11.0)
		if randi() % 4 == 0:
			say(_receptionist, RECEPTION_LINES.pick_random())
		else:
			say(_band.pick_random(), DINGO_LINES.pick_random())
	elif _chat_t <= 0.0:
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
	if best == "pajatso" and raahe_on:
		hint = "[E] Raahen jätkät pajatsolla: \"Ei oo sun vuoro, äijä!\""
	if best == "hedelmapeli" and hedelma_busy:
		hint = "[E] Seurue pelaa hedelmäpeliä: kysy vuoroa"
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	match best:
		"ovi":
			exited.emit()
		"seurue":
			say(_seurue.pick_random(), SEURUE_LINES.pick_random())
		"kortit":
			say(_cardplayers.pick_random(), CARD_LINES.pick_random())
		"hotelli_ovi":
			exited.emit()
		_:
			acted.emit(best)


## Valikosta palatessa sama E-painallus ei saa avata uutta toimintoa.
func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


## Karaokeruudun teksti (karaoke_game.gd päivittää laulaessa).
func set_screen(text: String) -> void:
	if _screen != null:
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


func from_stage(cheer: bool, quiet := false) -> void:
	busy = false
	walker.position = spots.karaoke[0]
	walker.controls_enabled = active
	_screen.text = "KARAOKE\nValitse biisi"
	if quiet:  # ei laulettu (valikosta pois)
		return
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
	var ps := B.sign_plate(self, "PAJATSO", Color(0.12, 0.1, 0.3), Color(1.0, 0.82, 0.15), 0.16, 40, Color(0.95, 0.8, 0.3))
	ps.position = Vector3(6.6, 1.82, -4.66)
	_build_hedelmapeli(Vector3(1.4, 0, -5.0))
	var jb := _solid(Vector3(1.0, 1.5, 0.6), Vector3(4.6, 0.75, -5.0), Color(0.25, 0.12, 0.3))
	jb.material_override = B.unshaded(Color(0.55, 0.25, 0.6))
	B.label(self, "JUKEBOKSI", Vector3(4.6, 1.6, -4.66), 22, Color(1.0, 0.9, 0.5))


## Hedelmäpeli takaseinällä baaritiskin päädyssä: musta kaappi punaisin kyljin, valaistu yläpaneeli, kolme
## rullaa voittolinjoineen, nappirivi ja kolikkotarjotin (minipeli hedelmapeli_game.gd).
func _build_hedelmapeli(at: Vector3) -> void:
	var front := at.z + 0.3
	_solid(Vector3(0.75, 1.55, 0.6), at + Vector3(0, 0.775, 0), Color(0.06, 0.06, 0.08))
	for sx in [-0.39, 0.39]:
		B.mesh(self, B.boxm(Vector3(0.04, 1.6, 0.62)), at + Vector3(sx, 0.8, 0), Color(0.75, 0.1, 0.1))
	var top := B.mesh(self, B.boxm(Vector3(0.72, 0.32, 0.5)), at + Vector3(0, 1.72, -0.04), Color(1.0, 0.5, 0.15))
	top.material_override = B.unshaded(Color(1.0, 0.55, 0.2))
	var hs := B.sign_plate(self, "HEDELMÄPELI", Color(0.6, 0.05, 0.15), Color(1.0, 0.92, 0.3), 0.12, 34, Color(0.95, 0.8, 0.3))
	hs.position = Vector3(at.x, 1.74, front - 0.05)
	# Rullaikkuna: kromikehys ja kolme valkoista rullaa, punainen voittolinja.
	B.mesh(self, B.boxm(Vector3(0.6, 0.3, 0.02)), Vector3(at.x, 1.28, front + 0.005), Color(0.75, 0.76, 0.8))
	for k in 3:
		var reel := B.mesh(self, B.boxm(Vector3(0.16, 0.24, 0.02)), Vector3(at.x - 0.19 + k * 0.19, 1.28, front + 0.012), Color(0.97, 0.96, 0.92))
		reel.material_override = B.unshaded(Color(0.95, 0.94, 0.9))
		B.mesh(self, B.sphere(0.03, 8), Vector3(at.x - 0.19 + k * 0.19, 1.28, front + 0.02), [Color(0.9, 0.1, 0.1), Color(1.0, 0.85, 0.1),
			Color(0.5, 0.15, 0.55)][k])
	B.mesh(self, B.boxm(Vector3(0.6, 0.012, 0.01)), Vector3(at.x, 1.28, front + 0.03), Color(0.95, 0.15, 0.1))
	# Voittotaulukko rullien yllä ja nappihylly alla.
	var pt := B.mesh(self, B.boxm(Vector3(0.6, 0.16, 0.02)), Vector3(at.x, 1.5, front + 0.005), Color(0.08, 0.1, 0.3))
	pt.material_override = B.unshaded(Color(0.12, 0.15, 0.4))
	B.mesh(self, B.boxm(Vector3(0.72, 0.05, 0.2)), Vector3(at.x, 1.02, front + 0.08), Color(0.2, 0.2, 0.22))
	for k in 5:
		var bcol: Color = [Color(0.95, 0.95, 0.9), Color(0.95, 0.95, 0.9), Color(0.95, 0.95, 0.9), Color(0.95, 0.8, 0.2), Color(0.25, 0.8, 0.3)][k]
		var b := B.mesh(self, B.sphere(0.025, 8), Vector3(at.x - 0.26 + k * 0.13, 1.055, front + 0.1), bcol)
		b.material_override = B.unshaded(bcol)
	B.mesh(self, B.boxm(Vector3(0.4, 0.08, 0.14)), Vector3(at.x, 0.3, front + 0.05), Color(0.7, 0.72, 0.76))
	var glow := OmniLight3D.new()
	glow.position = Vector3(at.x, 1.6, front + 0.5)
	glow.omni_range = 2.2
	glow.light_energy = 0.6
	glow.light_color = Color(1.0, 0.55, 0.35)
	add_child(glow)


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
	# Seurueen kaksi hedelmäpelillä: nainen pelaa, mies katsoo vieressä.
	var hl := Looks.HEDELMA_PELAAJAT
	for i in hl.size():
		var c := Looks.make(self, hl[i])
		_add_bubble(c)
		var body := StaticBody3D.new()
		body.add_child(B.capsule_shape(0.3, 1.8))
		c.add_child(body)
		body.top_level = true
		c.set_meta("body", body)
		_hedelma.append(c)
	_place_hedelma(true)
	# Paikalliset korttipelissä.
	_cardplayers.append(_seat(Looks.GRANDPAS[0], Vector3(3.6, 0, -1.1), Vector3(0, 0, -1)))
	_cardplayers.append(_seat(Looks.GRANDPAS[2], Vector3(3.6, 0, -2.7), Vector3(0, 0, 1)))


# --- Hotellin puoli ---------------------------------------------------------------

var _receptionist: Node3D
var _band: Array[Node3D] = []
var _chair: Node3D
var _tv: Node3D
var _jumper: Node3D
var _band_t := 3.0
var _music: AudioStreamPlayer3D


func _hwall(a: Vector2, b: Vector2, h: float, col: Color) -> void:
	_wall(a + Vector2(HOTEL.x, HOTEL.z), b + Vector2(HOTEL.x, HOTEL.z), h, col, WALL_H)


func _hmesh(size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return B.mesh(self, B.boxm(size), HOTEL + pos, col, rot)


func _build_hotel() -> void:
	var wall := Color(0.78, 0.72, 0.6)   # 80-luvun beige tapetti
	var carpet := Color(0.45, 0.12, 0.14)  # viininpunainen hotellimatto
	var hx := HOTEL_HALF.x
	var hz := HOTEL_HALF.y
	_hmesh(Vector3(hx * 2.0, 0.1, hz * 2.0), Vector3(0, -0.05, 0), carpet)
	for i in 9:  # maton kuvio
		_hmesh(Vector3(0.08, 0.01, hz * 2.0), Vector3(-hx + 1.0 + i * 2.0, 0.005, 0), Color(0.6, 0.45, 0.2))
	_hwall(Vector2(-hx, -hz), Vector2(hx, -hz), WALL_H, wall)
	_hwall(Vector2(-hx, -hz), Vector2(-hx, hz), WALL_H, wall)
	_hwall(Vector2(hx, -hz), Vector2(hx, hz), WALL_H, wall)
	_hwall(Vector2(-hx, hz), Vector2(hx, hz), 0.6, wall)
	# Väliseinä oviaukolla huoneeseen 12.
	_hwall(Vector2(HOTEL_WALL_X, -hz), Vector2(HOTEL_WALL_X, 2.4), WALL_H, wall)
	_hwall(Vector2(HOTEL_WALL_X, 4.2), Vector2(HOTEL_WALL_X, hz), WALL_H, wall)
	# Huoneen 12 ovi rikki: sarana irti, ovi lattialla.
	_hmesh(Vector3(0.9, 0.05, 2.0), Vector3(HOTEL_WALL_X + 1.2, 0.03, 3.3), Color(0.5, 0.33, 0.2), Vector3(0, 20, 0))
	B.label(self, "12", HOTEL + Vector3(HOTEL_WALL_X - 0.08, 2.5, 3.3), 60, Color(0.95, 0.8, 0.3)).rotation.y = -PI / 2.0
	# Vastaanotto: tiski, avaintaulu, kyltti, palmu ja nojatuolit; ulko-ovi vasemmassa päädyssä.
	var desk := Color(0.4, 0.25, 0.15)
	_hmesh(Vector3(3.4, 1.1, 0.7), Vector3(-5.6, 0.55, -3.3), desk)
	var db := StaticBody3D.new()
	db.position = HOTEL + Vector3(-5.6, 0.55, -3.3)
	db.add_child(B.box_shape(Vector3(3.4, 1.1, 0.7)))
	add_child(db)
	_hmesh(Vector3(3.6, 0.06, 0.9), Vector3(-5.6, 1.13, -3.3), Color(0.25, 0.15, 0.08))
	_hmesh(Vector3(0.3, 0.12, 0.2), Vector3(-4.6, 1.22, -3.3), Color(0.85, 0.75, 0.2))  # soittokello
	_hmesh(Vector3(1.6, 1.0, 0.06), Vector3(-5.6, 1.9, -hz + 0.05), Color(0.35, 0.22, 0.12))  # avaintaulu
	for k in 12:
		_hmesh(Vector3(0.05, 0.14, 0.03), Vector3(-6.2 + (k % 6) * 0.24, 1.75 + (k / 6) * 0.3, -hz + 0.1),
			Color(0.9, 0.8, 0.3) if k != 11 else Color(0.35, 0.22, 0.12))  # huoneen 12 avain puuttuu
	var rs := B.sign_plate(self, "HOTELLI SIITARI · VASTAANOTTO", Color(0.12, 0.1, 0.08), Color(0.98, 0.95, 0.85), 0.18, 34,
		Color(0.95, 0.8, 0.3))
	rs.position = HOTEL + Vector3(-5.6, 2.65, -hz + 0.1)
	_hotel_exit_door(hx, 0.6)
	for cx in [-7.8, -3.4]:  # nojatuolit
		_hmesh(Vector3(0.8, 0.45, 0.8), Vector3(cx, 0.22, 2.4), Color(0.25, 0.4, 0.3))
		_hmesh(Vector3(0.8, 0.5, 0.15), Vector3(cx, 0.65, 2.75), Color(0.25, 0.4, 0.3))
	B.mesh(self, B.cyl(0.25, 0.3, 0.5, 10), HOTEL + Vector3(-8.3, 0.25, -5.2), Color(0.55, 0.3, 0.2))  # palmu ruukussa
	for k in 5:
		_hmesh(Vector3(0.12, 0.05, 0.9), Vector3(-8.3, 1.1 + k * 0.08, -5.2), Color(0.2, 0.5, 0.2), Vector3(30 - k * 15, k * 72, 0))
	# Käytävän ovet 10 ja 11 (kiinni).
	for d in [[-2.6, "10"], [-0.8, "11"]]:
		_hmesh(Vector3(1.0, 2.2, 0.08), Vector3(d[0], 1.1, -hz + 0.05), Color(0.5, 0.33, 0.2))
		B.label(self, d[1], HOTEL + Vector3(d[0], 2.45, -hz + 0.12), 40, Color(0.95, 0.8, 0.3))
	_receptionist = Looks.make(self, {"model": "female", "shirt": Color(0.2, 0.25, 0.45), "pants": Color(0.15, 0.15, 0.2),
		"shoes": Color(0.1, 0.1, 0.1), "hair": "Hair_Buns", "hair_color": Color(0.45, 0.3, 0.2), "height": 1.64})
	_receptionist.position = HOTEL + Vector3(-5.6, 0, -4.3)
	_receptionist.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_receptionist.play("Idle", 0.0)
	_add_bubble(_receptionist)
	_build_room_12()


## Hotellin ulko-ovi vastaanoton päätyseinässä (x = -hx, kohdassa z), piirretty sisältä katsottuna seinän sisäpinnalle (seinä on 0,2 m
## paksu, joten ovi on sen pinnan edessä eikä piiloudu seinään): valkoiset karmit, tumma ovilehti jossa lasi-ikkuna ja paneelit,
## vetokahva, kynnys ja vihreä ULOS-kyltti oven päällä. Pelaajan paikka "hotelli_ovi" on oven edessä sisäpuolella.
func _hotel_exit_door(hx: float, z: float) -> void:
	var x := -hx + 0.1  # seinän sisäpinta
	var frame := Color(0.92, 0.9, 0.84)
	_hmesh(Vector3(0.06, 2.3, 0.12), Vector3(x + 0.03, 1.15, z - 0.86), frame)  # karmit
	_hmesh(Vector3(0.06, 2.3, 0.12), Vector3(x + 0.03, 1.15, z + 0.86), frame)
	_hmesh(Vector3(0.06, 0.12, 1.84), Vector3(x + 0.03, 2.3, z), frame)
	_hmesh(Vector3(0.1, 0.04, 1.6), Vector3(x + 0.05, 0.02, z), Color(0.45, 0.4, 0.35))  # kynnys
	_hmesh(Vector3(0.04, 2.2, 1.6), Vector3(x + 0.03, 1.1, z), Color(0.34, 0.2, 0.12))  # ovilehti (tumma puu)
	_hmesh(Vector3(0.05, 0.9, 1.0), Vector3(x + 0.05, 1.55, z), Color(0.5, 0.7, 0.78))  # lasi-ikkuna
	for pz in [-0.35, 0.35]:  # alapaneelit
		_hmesh(Vector3(0.05, 0.7, 0.5), Vector3(x + 0.05, 0.5, z + pz), Color(0.28, 0.16, 0.1))
	_hmesh(Vector3(0.1, 0.05, 0.22), Vector3(x + 0.1, 1.05, z + 0.62), Color(0.8, 0.75, 0.4))  # kahva
	var exit_sign := B.sign_plate(self, "ULOS", Color(0.05, 0.4, 0.15), Color.WHITE, 0.3, 40, Color(0.9, 0.9, 0.9))
	exit_sign.position = HOTEL + Vector3(x + 0.08, 2.65, z)
	exit_sign.rotation.y = PI / 2.0  # lukusuunta huoneeseen päin (+X)


## Huone 12 sekaisin: sänky nurin, patja seinää vasten, telkkari lattialla, ikkuna rikki, pullot, kitarat ja vahvistin,
## tyynyjen höyhenet. Neljä 80-luvun rokkaria (tupeeratut pitkät hiukset, nahkatakit, valkoiset farkut).
func _build_room_12() -> void:
	var hz := HOTEL_HALF.y
	_hmesh(Vector3(2.0, 0.5, 2.2), Vector3(6.6, 0.25, -3.6), Color(0.45, 0.3, 0.2), Vector3(0, 0, 160))  # sänky nurin
	_hmesh(Vector3(1.8, 2.0, 0.25), Vector3(8.7, 1.0, -1.0), Color(0.9, 0.88, 0.8), Vector3(0, 90, 12))  # patja seinää vasten
	_hmesh(Vector3(2.2, 1.4, 0.1), Vector3(6.0, 1.7, -hz + 0.02), Color(0.2, 0.25, 0.3))  # ikkuna
	for k in 4:  # sirpaleet ikkunan reunassa
		_hmesh(Vector3(0.3, 0.4, 0.04), Vector3(5.2 + k * 0.5, 1.2 + (k % 2) * 0.9, -hz + 0.08), Color(0.7, 0.85, 0.9),
			Vector3(0, 0, 25 * k))
	_hmesh(Vector3(0.5, 1.8, 0.05), Vector3(7.4, 1.6, -hz + 0.12), Color(0.6, 0.2, 0.2), Vector3(0, 0, -15))  # verho repaleena
	# Rikkinäinen telkkari lattialla (kuvaputki säröillä) ja toinen, jonka pelaaja voi auttaa heittämään ikkunasta.
	_hmesh(Vector3(0.7, 0.55, 0.5), Vector3(2.2, 0.28, -4.4), Color(0.15, 0.15, 0.17), Vector3(0, 30, 80))
	_tv = Node3D.new()
	add_child(_tv)
	_tv.position = HOTEL + Vector3(4.6, 0.3, -2.4)
	B.mesh(_tv, B.boxm(Vector3(0.7, 0.55, 0.5)), Vector3.ZERO, Color(0.18, 0.15, 0.12))
	B.mesh(_tv, B.boxm(Vector3(0.55, 0.42, 0.02)), Vector3(0, 0, 0.26), Color(0.1, 0.2, 0.18))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for k in 9:  # pullot
		var p := Vector3(rng.randf_range(1.2, 8.4), 0.08, rng.randf_range(-5.4, 5.4))
		B.mesh(self, B.cyl(0.05, 0.05, 0.28, 8), HOTEL + p, [Color(0.2, 0.45, 0.2), Color(0.45, 0.3, 0.1), Color(0.85, 0.85, 0.9)][k % 3],
			Vector3(90, rng.randf() * 360.0, 0))
	for k in 30:  # höyhenet
		_hmesh(Vector3(0.06, 0.01, 0.03), Vector3(rng.randf_range(1.5, 8.5), 0.02, rng.randf_range(-4.5, 4.5)), Color.WHITE,
			Vector3(0, rng.randf() * 180.0, 0))
	for g in [[Vector3(3.0, 0.08, 4.6), Color(0.8, 0.1, 0.1)], [Vector3(7.6, 0.08, 4.2), Color(0.95, 0.95, 0.95)]]:  # kitarat
		var gp: Vector3 = g[0]
		_hmesh(Vector3(0.38, 0.06, 0.45), gp, g[1], Vector3(0, 35, 0))
		_hmesh(Vector3(0.06, 0.04, 0.6), gp + Vector3(0.3, 0, -0.42), Color(0.3, 0.2, 0.1), Vector3(0, 35, 0))
	_hmesh(Vector3(0.7, 0.8, 0.4), Vector3(8.4, 0.4, 3.2), Color(0.08, 0.08, 0.08))  # vahvistin
	B.label(self, "DINGO", HOTEL + Vector3(8.4, 0.6, 2.98), 30, Color(0.95, 0.85, 0.2)).rotation.y = PI
	# Tuoli, joka lentää välillä seinään.
	_chair = Node3D.new()
	add_child(_chair)
	B.mesh(_chair, B.boxm(Vector3(0.45, 0.06, 0.45)), Vector3(0, 0.45, 0), Color(0.5, 0.35, 0.2))
	B.mesh(_chair, B.boxm(Vector3(0.45, 0.5, 0.06)), Vector3(0, 0.72, -0.2), Color(0.5, 0.35, 0.2))
	for lx in [-0.18, 0.18]:
		for lz in [-0.18, 0.18]:
			B.mesh(_chair, B.boxm(Vector3(0.04, 0.45, 0.04)), Vector3(lx, 0.22, lz), Color(0.4, 0.28, 0.15))
	_chair.position = HOTEL + Vector3(3.2, 0, -0.6)
	var hair := [Color(0.95, 0.85, 0.55), Color(0.12, 0.08, 0.05), Color(0.55, 0.3, 0.15), Color(0.9, 0.8, 0.6)]
	var spots_b := [[Vector3(4.6, 0, -0.8), "Dance"], [Vector3(6.6, 0, 1.2), "Punch_Cross"], [Vector3(3.2, 0, 1.0), "Dance"],
		[Vector3(6.4, 0, -2.0), "Idle_Talking"]]
	for i in 4:
		var c := Looks.make(self, {"shirt": Color(0.06, 0.06, 0.07) if i != 2 else Color(0.95, 0.95, 0.95),
			"pants": Color(0.92, 0.92, 0.9) if i % 2 == 0 else Color(0.25, 0.3, 0.45), "shoes": Color(0.9, 0.9, 0.9),
			"hair": "Hair_Long", "hair_color": hair[i], "height": 1.76 + i * 0.03, "bulk": -0.4})
		c.position = HOTEL + spots_b[i][0]
		c.rotation.y = B.yaw_to(Vector3(-0.3 + i * 0.5, 0, 1 - i * 0.4))
		c.play(spots_b[i][1], 0.0)
		_add_bubble(c)
		_band.append(c)
	_jumper = _band[3]
	_music = AudioStreamPlayer3D.new()
	var st: AudioStream = load("res://scripts/headphones.gd").random_90s()
	if st != null:
		_music.stream = st
		_music.bus = "Music"
		_music.volume_db = -8.0
		_music.unit_size = 4.0
		_music.max_distance = 22.0
		_music.position = HOTEL + Vector3(8.4, 1.0, 3.2)
		add_child(_music)
		_music.finished.connect(_music.play)


## Bändi riehuu: tuoli lentää seinään, joku hyppii sängyllä, musiikki soi vain kun pelaaja on hotellin puolella.
func _band_tick(delta: float) -> void:
	if _music.stream != null:
		var want := active and in_hotel()
		if want and not _music.playing:
			_music.play()
		elif not want and _music.playing:
			_music.stop()
	if not active or not in_hotel():
		return
	_band_t -= delta
	if _band_t > 0.0:
		return
	_band_t = randf_range(5.0, 8.0)
	if randi() % 2 == 0:
		var a := HOTEL + Vector3(3.2, 0, -0.6)
		var b := HOTEL + Vector3(randf_range(5.0, 8.0), 0, -HOTEL_HALF.y + 0.6)
		var tw := create_tween()
		tw.tween_method(func(t: float) -> void:
			_chair.position = a.lerp(b, t) + Vector3(0, sin(t * PI) * 1.6, 0)
			_chair.rotation = Vector3(t * 6.0, t * 2.0, 0), 0.0, 1.0, 0.7)
		tw.tween_callback(func() -> void: Sfx.play("rattle_hard", -6.0))
		tw.tween_interval(1.6)
		tw.tween_callback(func() -> void:
			_chair.position = a
			_chair.rotation = Vector3.ZERO)
		_band[0].play("Punch_Cross", 0.2)
		say(_band[0], ["HEP!", "Kattoon asti!", "Tilaa uus!"].pick_random(), 1.6)
	else:
		_jumper.play("Jump", 0.2)
		say(_jumper, ["Encore!", "Vaala, ootteko valmiina?!", "Kitarasoolo!"].pick_random(), 1.6)
