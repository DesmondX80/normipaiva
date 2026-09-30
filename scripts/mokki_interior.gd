extends Node3D
## Mökin sisätila (Airbnb-ilmoituksen kuvien mukaan, noin 1,5x mitoitettuna pelattavuuden vuoksi): avokeittiö ja
## ruokailutila (pitkä pöytä penkkeineen, vuodesohvat, TV, kivitakka), makuuhuone violetteine kerrossänkyineen, kylpyhuone suihkuineen
## ja sisäsauna sekä Santun PA-laitteet (kaiuttimet jalustoilla, mikseri pöydän päässä, pääte lattialla). Erillinen tasku kuten kaupan sisätila: kuistin ovelta sisään (main.gd _enter_mokki), kävely
## player_walker.gd:llä ylhäältä kuvattuna, katto pois. Toiminnot ilmoitetaan acted-signaalilla (tilavaikutukset
## ja viestit main.gd:ssä), nukkuminen slept-signaalilla (päivä vaihtuu, uusi päivä alkaa mökiltä).
## Paikallinen -Z = kuistin puoli: keittiö ja ulko-ovi (vasen nurkka), +Z = tien puoli (makuuhuone, kamera).
## Sama suunta kuin mökin rungossa (mokki.gd _build_cottage).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")
const Mokki := preload("res://scripts/mokki.gd")

const HALF := Vector2(7.0, 3.75)  # huoneiston puolikas (x, z)
const WALL_H := 2.4
## Pohja on suorakaide, jonka vasemmasta kuistin puoleisesta nurkasta puuttuu lovi (NOTCH, ulkona; ulko-ovi loven seinässä).
## Keittiö on loven vieressä tuvan takaseinän (väliseinä TV:n takana) takana, aukko KITCHEN_GAP (x alku, x loppu).
const NOTCH := Rect2(-7.0, -3.75, 1.6, 1.95)
const KITCHEN := Rect2(-5.4, -3.75, 6.4, 1.95)
const KITCHEN_GAP := Vector2(-2.3, -1.2)
## Toimintopisteet: id -> [paikka, vihje].
const SPOTS := {
	"ovi": [Vector3(-6.3, 0, -1.1), "[E] Ulos kuistille"],
	"santtu": [Vector3(-1.5, 0, -2.2), "[E] Jutskaa Santun kanssa"],
	"kahvi": [Vector3(-2.8, 0, -2.4), "[E] Keitä suodatinkahvit"],
	"jaakaappi": [Vector3(0.4, 0, -2.4), "[E] Kurkkaa jääkaappiin"],
	"takka": [Vector3(-0.4, 0, -0.9), "[E] Sytytä takka"],
	"tv": [Vector3(-3.9, 0, -0.6), "[E] Katso telkkaria"],
	"sanky": [Vector3(4.9, 0, 1.2), "[E] Mene nukkumaan kerrossänkyyn (päivä päättyy)"],
	"suihku": [Vector3(2.3, 0, -1.75), "[E] Käy suihkussa"],
	"sauna": [Vector3(5.0, 0, -2.05), "[E] Käy sisäsaunassa"],
	"pa": [Vector3(-0.9, 0, 1.55), "[E] Kytke Santun PA-laitteet"],
}
## PA-kaiuttimet (jalustoilla sohvien päädyissä) ja tunnusmusiikin voimakkuus: taso 0..1 -> dB.
const PA_SPEAKERS := [Vector3(-4.95, 0, 3.2), Vector3(0.2, 0, 3.2)]
const PA_DB := -2.0
const SANTTU_IN_LINES := [
	"Suodatinkahvia on aina tarjolla. Se on ilmoituksen kohokohtia!",
	"Kerrossängyt on violetit. Tytär maalas, en kehdannu kieltää.",
	"Sisäsauna on sähköllä... ei kun puulla. Savusauna pihalla on se oikea.",
	"Takka vetää hyvin, kunhan muistaa avata pellin.",
	"Vesi ja sähkö on, mitä muuta ihminen tarvii?",
	"Superhost, viides vuosi. Arvosteluja ei vielä yhtään, mutta tulee, tulee.",
	"PA-kamat on vanhoilta keikoilta. Pääte päälle viimeisenä, muista se.",
]
const SANTTU_PA_LINES := [
	"Tää on se Normipäivän tunnari! Kova biisi.",
	"Kuuluu varmaan Likasen yli naapuriin asti.",
	"Vanhat keikkakamat toimii vieläkin!",
]

signal exited
signal slept
signal acted(kind: String)

var active := false
var walker: CharacterBody3D
var hint := ""
var takka_on := false
var _enter_frame := -1

var _santtu: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _chat_t := 5.0
var _takka_fire: Node3D
var _tv_screen: MeshInstance3D
## PA: päällä (onnistunut kytkentä), minipeli käynnissä (busy), kaiuttimien soittimet ja päällä näkyvät osat.
var pa_on := false
var busy := false
var _pa_players: Array[AudioStreamPlayer3D] = []
var _pa_lit: Array[Node3D] = []
var _pa_cones: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_room()
	_build_kitchen_dining()
	_build_bedroom()
	_build_bath_sauna()
	_build_pa()
	_santtu = Looks.make(self, Mokki.SANTTU_LOOK)
	_santtu.position = Vector3(-1.5, 0, -3.0)
	_santtu.rotation.y = B.yaw_to(Vector3(0.3, 0, 1))
	_santtu.play("Idle", 0.0)
	var body := StaticBody3D.new()
	body.position = _santtu.position
	body.add_child(B.capsule_shape(0.3, 1.8))
	add_child(body)
	_bubble = B.label(self, "", _santtu.position + Vector3(0, 2.1, 0), 34, Color.WHITE, true)
	walker = Walker.new()
	walker.position = SPOTS.ovi[0]
	add_child(walker)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()  # sisään vienyt E ei saa samalla ruudulla viedä ulos
	walker.position = SPOTS.ovi[0] + Vector3(0, 0, 1.5)
	walker.rotation.y = B.yaw_to(Vector3(0, 0, -1))  # katse tupaan (walkerin kääntö on yaw_to:n vastainen)
	walker.activate()
	say("No terve! Tuu sisälle vaan.")


func leave() -> void:
	active = false
	walker.controls_enabled = false


func say(text: String) -> void:
	_bubble.text = "Santtu: " + text
	_bubble_t = 3.2
	_santtu.play("Idle_Talking", 0.3)


func _process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble_t <= 0.0 and _bubble.text != "":
		_bubble.text = ""
		_santtu.play("Idle", 0.3)
	if _tv_screen != null and _tv_screen.visible:
		(_tv_screen.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.45, 0.8).lightened(
			0.3 * sin(Time.get_ticks_msec() / 180.0))
	if not _pa_players.is_empty() and _pa_players[0].playing:
		var beat := 1.0 + 0.05 * maxf(sin(Time.get_ticks_msec() / 1000.0 * TAU * 2.0), 0.0)  # elementit sykkivät
		for c in _pa_cones:
			c.scale = Vector3(beat, 1.0, beat)
	if not active or busy:
		hint = ""
		return
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(12.0, 20.0)
		say((SANTTU_PA_LINES if pa_on and randf() < 0.5 else SANTTU_IN_LINES).pick_random())
	var p := walker.position
	var best := ""
	var bd := 1.3
	for id in SPOTS:
		var d := Vector2(p.x - SPOTS[id][0].x, p.z - SPOTS[id][0].z).length()
		if d < bd:
			bd = d
			best = id
	hint = ""
	if best == "":
		return
	hint = SPOTS[best][1]
	if best == "pa" and pa_on:
		hint = "[E] Sammuta PA (pääte ensin pois)"
	if best == "takka" and takka_on:
		hint = "Takka lämmittää mukavasti."
		return
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	match best:
		"ovi":
			exited.emit()
		"sanky":
			slept.emit()
		"santtu":
			say(SANTTU_IN_LINES.pick_random())
		"takka":
			takka_on = true
			_takka_fire.visible = true
			Sfx.play("whoosh", 0.0, 0.5)
			acted.emit("takka")
		"tv":
			_tv_screen.visible = true
			acted.emit("tv")
		"kahvi":
			say("Suodatinkahvia! Ota mukiin, lisää löytyy.")
			acted.emit("kahvi")
		_:
			acted.emit(best)


# --- Rakennus ---------------------------------------------------------------------

## Seinä (törmäyksellä) paikallisesta pisteestä a pisteeseen b (akselinsuuntainen), korkeus h.
func _wall(a: Vector2, b: Vector2, h: float, col: Color, collide_h := WALL_H) -> void:
	var c := (a + b) / 2.0
	var size := Vector3(maxf(absf(b.x - a.x), 0.15), h, maxf(absf(b.y - a.y), 0.15))
	B.mesh(self, B.boxm(size), Vector3(c.x, h / 2.0, c.y), col)
	var body := StaticBody3D.new()
	body.position = Vector3(c.x, 0, c.y)
	body.add_child(B.box_shape(Vector3(size.x, collide_h, size.z), Vector3(0, collide_h / 2.0, 0)))
	add_child(body)


## Kiinteä huonekalu (laatikko törmäyksellä).
func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := B.mesh(self, B.boxm(size), pos, col)
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	add_child(body)
	return mi


func _build_room() -> void:
	var panel := Color(0.9, 0.89, 0.83)  # vaaleat paneeliseinät kuten kuvissa
	# Harmaa lautalattia.
	B.mesh(self, B.boxm(Vector3(80, 0.2, 80)), Vector3(0, -0.2, 0), Color(0.12, 0.12, 0.14))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), Color(0.48, 0.5, 0.5))
	for i in 18:
		var x := -HALF.x + 0.4 + i * 0.78
		B.mesh(self, B.boxm(Vector3(0.02, 0.01, HALF.y * 2.0)), Vector3(x, 0.005, 0), Color(0.38, 0.4, 0.4))
	# Lovi (ulkotilaa) vasemmassa nurkassa kuistin puolella: maan värinen lattia lattialautojen päälle.
	B.mesh(self, B.boxm(Vector3(NOTCH.size.x + 0.1, 0.02, NOTCH.size.y + 0.1)), Vector3(NOTCH.get_center().x - 0.05, 0.02,
		NOTCH.get_center().y - 0.05), Color(0.3, 0.33, 0.22))
	# Ulkoseinät: takaseinä (keittiön perä), loven kaksi seinää ja päädyt täyskorkeat, etuseinä matala kameran
	# vuoksi (törmäys täyskorkea).
	_wall(Vector2(NOTCH.end.x, -HALF.y), Vector2(HALF.x, -HALF.y), WALL_H, panel)
	_wall(Vector2(-HALF.x, NOTCH.end.y), Vector2(NOTCH.end.x, NOTCH.end.y), WALL_H, panel)
	_wall(Vector2(NOTCH.end.x, -HALF.y), Vector2(NOTCH.end.x, NOTCH.end.y), WALL_H, panel)
	_wall(Vector2(-HALF.x, NOTCH.end.y), Vector2(-HALF.x, HALF.y), WALL_H, panel)
	_wall(Vector2(HALF.x, -HALF.y), Vector2(HALF.x, HALF.y), WALL_H, panel)
	_wall(Vector2(-HALF.x, HALF.y), Vector2(HALF.x, HALF.y), 0.5, panel)
	# Lasiovi ulos loven seinässä (tuvan vasen takanurkka), päätyseinällä ikkuna.
	B.mesh(self, B.boxm(Vector3(1.0, 2.05, 0.06)), Vector3(SPOTS.ovi[0].x, 1.02, NOTCH.end.y + 0.08), Color(0.95, 0.95, 0.93))
	B.mesh(self, B.boxm(Vector3(0.8, 1.8, 0.07)), Vector3(SPOTS.ovi[0].x, 1.05, NOTCH.end.y + 0.09), Color(0.6, 0.78, 0.7))
	B.mesh(self, B.boxm(Vector3(0.06, 1.1, 1.3)), Vector3(-HALF.x + 0.08, 1.45, 2.2), Color(0.95, 0.95, 0.93))
	B.mesh(self, B.boxm(Vector3(0.07, 0.9, 1.1)), Vector3(-HALF.x + 0.09, 1.45, 2.2), Color(0.55, 0.75, 0.6))
	# Punapuitteiset ikkunat takaseinässä (keittiö, kylpyhuone ja sauna).
	for wx in [-1.5, 2.2, 5.2]:
		B.mesh(self, B.boxm(Vector3(1.3, 1.1, 0.06)), Vector3(wx, 1.45, -HALF.y + 0.1), Color(0.55, 0.12, 0.14))
		B.mesh(self, B.boxm(Vector3(1.1, 0.9, 0.07)), Vector3(wx, 1.45, -HALF.y + 0.11), Color(0.55, 0.75, 0.6))
	# Väliseinät oikealla: kylpyhuone ja sauna takana, makuuhuone edessä (tien puolella), oviaukot.
	var wall2 := panel.darkened(0.05)
	_wall(Vector2(1.0, -HALF.y), Vector2(1.0, -2.8), WALL_H, wall2)
	_wall(Vector2(1.0, -1.85), Vector2(1.0, 1.55), WALL_H, wall2)
	_wall(Vector2(1.0, 2.65), Vector2(1.0, HALF.y), WALL_H, wall2)
	_wall(Vector2(1.0, -0.6), Vector2(HALF.x, -0.6), WALL_H, wall2)
	_wall(Vector2(4.0, -HALF.y), Vector2(4.0, -2.65), WALL_H, Color(0.3, 0.22, 0.15))
	_wall(Vector2(4.0, -1.55), Vector2(4.0, -0.6), WALL_H, Color(0.3, 0.22, 0.15))
	# Keittiön ja tuvan väliseinä (TV:n takana) ja aukko pylvään kohdalla.
	_wall(Vector2(NOTCH.end.x, KITCHEN.end.y), Vector2(KITCHEN_GAP.x, KITCHEN.end.y), WALL_H, wall2)
	_wall(Vector2(KITCHEN_GAP.y, KITCHEN.end.y), Vector2(KITCHEN.end.x, KITCHEN.end.y), WALL_H, wall2)
	for l in [Vector3(-3.5, 2.3, 0.0), Vector3(3.5, 2.3, -1.5)]:
		var light := OmniLight3D.new()
		light.position = l
		light.omni_range = 9.0
		light.light_energy = 0.4
		add_child(light)


func _build_kitchen_dining() -> void:
	var white := Color(0.93, 0.92, 0.88)
	var wood := Color(0.72, 0.52, 0.3)  # vaalea mänty kuten pöytä ja penkit kuvissa
	# Keittiö loven vieressä tuvan takana (väliseinä ja aukko _build_roomissa): valkoiset kaapit takaseinällä,
	# liesi, mikro ja kahvinkeitin, aukon reunassa valkoinen pylväs (kuva 1), jääkaappi perällä väliseinän vieressä.
	var kback := KITCHEN.position.y
	var kc := -3.8
	_solid(Vector3(2.9, 0.9, 0.8), Vector3(kc, 0.45, kback + 0.45), white)
	B.mesh(self, B.boxm(Vector3(3.0, 0.05, 0.85)), Vector3(kc, 0.92, kback + 0.45), Color(0.62, 0.42, 0.22))
	B.mesh(self, B.boxm(Vector3(2.9, 0.7, 0.4)), Vector3(kc, 1.85, kback + 0.25), white)  # yläkaapit
	B.mesh(self, B.boxm(Vector3(0.7, 0.04, 0.6)), Vector3(kc + 0.4, 0.95, kback + 0.45), Color(0.1, 0.1, 0.1))  # liesi
	for kx in [kc + 0.2, kc + 0.6]:
		B.mesh(self, B.cyl(0.1, 0.1, 0.02, 12), Vector3(kx, 0.98, kback + 0.4), Color(0.25, 0.25, 0.25))
	B.mesh(self, B.boxm(Vector3(0.45, 0.28, 0.35)), Vector3(kc - 1.0, 1.08, kback + 0.35), Color(0.85, 0.85, 0.85))  # mikro
	B.mesh(self, B.cyl(0.08, 0.1, 0.3, 12), Vector3(SPOTS.kahvi[0].x, 1.1, kback + 0.4), Color(0.08, 0.08, 0.08))  # kahvinkeitin
	B.mesh(self, B.cyl(0.07, 0.07, 0.12, 12), Vector3(SPOTS.kahvi[0].x, 1.0, kback + 0.62), Color(0.6, 0.7, 0.75))  # kannu
	B.mesh(self, B.boxm(Vector3(0.15, WALL_H, 0.15)), Vector3(KITCHEN_GAP.y, WALL_H / 2.0, KITCHEN.end.y), white)  # pylväs
	_solid(Vector3(0.8, 1.9, 0.75), Vector3(0.4, 0.95, kback + 0.45), white)  # jääkaappi
	# Kuvioitu matto ja pitkä mäntypöytä: penkki vuodesohvien puolella, tuolit toisella.
	B.mesh(self, B.boxm(Vector3(4.2, 0.01, 2.8)), Vector3(-3.0, 0.01, 1.4), Color(0.72, 0.72, 0.68))
	_solid(Vector3(3.2, 0.75, 0.9), Vector3(-3.0, 0.375, 1.55), wood)
	_solid(Vector3(2.8, 0.45, 0.35), Vector3(-3.0, 0.22, 2.3), wood)  # penkki
	for cx in [-4.0, -3.0, -2.0]:
		B.mesh(self, B.boxm(Vector3(0.42, 0.45, 0.42)), Vector3(cx, 0.22, 0.75), Color(0.8, 0.55, 0.25))
		B.mesh(self, B.boxm(Vector3(0.42, 0.4, 0.05)), Vector3(cx, 0.65, 0.55), Color(0.8, 0.55, 0.25))
	# Kaksi vuodesohvaa peräkkäin tien puoleisella seinällä ja musta nojatuoli nurkassa.
	for bx in [-1.3, -3.5]:
		_solid(Vector3(2.0, 0.42, 0.85), Vector3(bx, 0.21, HALF.y - 0.5), wood)
		B.mesh(self, B.boxm(Vector3(1.9, 0.12, 0.8)), Vector3(bx, 0.48, HALF.y - 0.5), Color(0.86, 0.86, 0.84))
	_solid(Vector3(0.7, 0.5, 0.7), Vector3(-6.3, 0.25, HALF.y - 0.6), Color(0.12, 0.12, 0.13))
	B.mesh(self, B.boxm(Vector3(0.7, 0.6, 0.12)), Vector3(-6.3, 0.8, HALF.y - 0.3), Color(0.12, 0.12, 0.13))
	# Punainen korkea uuni päätyseinällä ikkunan ja lasioven välissä.
	_solid(Vector3(0.6, 2.3, 0.6), Vector3(-HALF.x + 0.4, 1.15, 0.2), Color(0.62, 0.12, 0.12))
	# TV-taso keittiön ja tuvan väliseinää vasten, CD-hylly vieressä (näyttö syttyy katsottaessa).
	_solid(Vector3(1.2, 0.5, 0.5), Vector3(-3.9, 0.25, KITCHEN.end.y + 0.3), Color(0.18, 0.18, 0.2))
	B.mesh(self, B.boxm(Vector3(1.0, 0.6, 0.08)), Vector3(-3.9, 0.85, KITCHEN.end.y + 0.3), Color(0.06, 0.06, 0.07))
	_tv_screen = B.mesh(self, B.boxm(Vector3(0.9, 0.5, 0.02)), Vector3(-3.9, 0.85, KITCHEN.end.y + 0.35), Color.BLACK)
	_tv_screen.material_override = B.unshaded(Color(0.3, 0.45, 0.8))
	_tv_screen.visible = false
	_solid(Vector3(0.3, 1.4, 0.25), Vector3(-5.0, 0.7, KITCHEN.end.y + 0.2), Color(0.45, 0.3, 0.18))
	# Harmaa kivitakka mustine luukkuineen väliseinällä keskellä mökkiä, lipasto ja sisäikkuna sen vieressä
	# (kuva 2); makuuhuoneen oviaukko oikealla.
	_solid(Vector3(0.5, 1.3, 1.2), Vector3(0.72, 0.65, -0.9), Color(0.36, 0.37, 0.38))
	B.mesh(self, B.boxm(Vector3(0.05, 0.6, 0.6)), Vector3(0.46, 0.55, -0.9), Color(0.05, 0.05, 0.05))
	B.mesh(self, B.boxm(Vector3(0.9, 0.03, 1.5)), Vector3(0.4, 0.015, -0.9), Color(0.2, 0.18, 0.16))
	_solid(Vector3(0.5, 0.8, 0.7), Vector3(0.72, 0.4, 0.35), wood)  # lipasto
	B.mesh(self, B.boxm(Vector3(0.07, 0.6, 0.8)), Vector3(0.93, 1.45, 1.0), Color(0.55, 0.7, 0.72))  # sisäikkuna
	_takka_fire = Node3D.new()
	_takka_fire.position = Vector3(0.43, 0.5, -0.9)
	add_child(_takka_fire)
	var flame := B.mesh(_takka_fire, B.boxm(Vector3(0.02, 0.25, 0.4)), Vector3.ZERO, Color.WHITE)
	flame.material_override = B.unshaded(Color(1.0, 0.5, 0.1))
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.55, 0.2)
	fl.omni_range = 4.0
	fl.position = Vector3(-0.4, 0.3, 0)
	_takka_fire.add_child(fl)
	_takka_fire.visible = false


func _build_bedroom() -> void:
	var purple := Color(0.72, 0.4, 0.72)
	var mattress := Color(0.9, 0.88, 0.82)
	# Kaksi violettia kerrossänkyä L-muodossa perimmäisessä nurkassa (väliseinä ja päätyseinä, kuva 3).
	for bunk in [[Vector3(5.3, 0, -0.1), 0.0], [Vector3(HALF.x - 0.5, 0, 1.9), PI / 2.0]]:
		var n := Node3D.new()
		n.position = bunk[0]
		n.rotation.y = bunk[1]
		add_child(n)
		for y in [0.4, 1.4]:
			B.mesh(n, B.boxm(Vector3(2.0, 0.08, 0.85)), Vector3(0, y, 0), purple)
			B.mesh(n, B.boxm(Vector3(1.9, 0.14, 0.8)), Vector3(0, y + 0.1, 0), mattress)
		for px in [-0.98, 0.98]:
			for pz in [-0.4, 0.4]:
				B.mesh(n, B.boxm(Vector3(0.07, 1.8, 0.07)), Vector3(px, 0.9, pz), purple)
		var body := StaticBody3D.new()
		body.add_child(B.box_shape(Vector3(2.0, 1.8, 0.9), Vector3(0, 0.9, 0)))
		n.add_child(body)
	# Jakkaraportaat sängyn edessä, valkoinen pöytä radioineen ikkunan alla ja oranssi tuoli.
	B.mesh(self, B.boxm(Vector3(0.4, 0.6, 0.35)), Vector3(4.8, 0.3, 0.65), Color(0.7, 0.55, 0.35))
	_solid(Vector3(1.3, 0.7, 0.6), Vector3(4.3, 0.35, HALF.y - 0.4), Color(0.93, 0.92, 0.88))
	B.mesh(self, B.boxm(Vector3(0.3, 0.18, 0.12)), Vector3(4.7, 0.8, HALF.y - 0.4), Color(0.2, 0.2, 0.22))
	B.mesh(self, B.boxm(Vector3(0.42, 0.45, 0.42)), Vector3(4.0, 0.22, 2.75), Color(0.85, 0.55, 0.15))


func _build_bath_sauna() -> void:
	# Kylpyhuone takana: valkoinen laatta, ruskea lattialaatta, suihku ja punainen saavi.
	B.mesh(self, B.boxm(Vector3(2.9, 0.02, 3.0)), Vector3(2.5, 0.02, -2.15), Color(0.45, 0.25, 0.15))
	B.mesh(self, B.boxm(Vector3(2.9, WALL_H, 0.05)), Vector3(2.5, WALL_H / 2.0, -0.65), Color(0.95, 0.95, 0.93))
	B.mesh(self, B.cyl(0.02, 0.02, 1.9, 6), Vector3(1.4, 0.95, -0.95), Color(0.75, 0.75, 0.78))
	B.mesh(self, B.cyl(0.08, 0.05, 0.05, 10), Vector3(1.4, 1.9, -1.05), Color(0.75, 0.75, 0.78))
	B.mesh(self, B.cyl(0.18, 0.15, 0.25, 12), Vector3(3.4, 0.13, -1.05), Color(0.85, 0.12, 0.12))
	# Sisäsauna kylpyhuoneen vieressä: tummat paneelit, kaksitasoiset lauteet ja puukiuas.
	var dark := Color(0.3, 0.22, 0.15)
	B.mesh(self, B.boxm(Vector3(2.9, 0.02, 3.0)), Vector3(5.5, 0.02, -2.15), Color(0.5, 0.48, 0.44))
	_solid(Vector3(2.8, 0.45, 0.7), Vector3(5.5, 0.22, -1.05), Color(0.62, 0.48, 0.3))
	B.mesh(self, B.boxm(Vector3(2.8, 0.05, 0.6)), Vector3(5.5, 0.9, -0.9), Color(0.62, 0.48, 0.3))
	B.mesh(self, B.boxm(Vector3(2.9, WALL_H, 0.05)), Vector3(5.5, WALL_H / 2.0, -0.65), dark)
	_solid(Vector3(0.6, 0.8, 0.6), Vector3(6.5, 0.4, -3.15), Color(0.12, 0.12, 0.12))
	for k in 6:
		B.mesh(self, B.sphere(0.09, 6), Vector3(6.35 + (k % 3) * 0.15, 0.85, -3.25 + (k / 3) * 0.2), Color(0.45, 0.44, 0.42))
	B.mesh(self, B.cyl(0.1, 0.12, 0.22, 10), Vector3(5.8, 0.11, -3.35), Color(0.15, 0.4, 0.8))  # sininen kiulu kuten kuvassa


# --- PA-laitteet -------------------------------------------------------------------

func _build_pa() -> void:
	var black := Color(0.07, 0.07, 0.08)
	# Kaiuttimet jalustoilla, elementit kohti tupaa (-Z).
	for sp in PA_SPEAKERS:
		B.mesh(self, B.cyl(0.025, 0.025, 1.2, 6), sp + Vector3(0, 0.6, 0), Color(0.2, 0.2, 0.22))
		for a in 3:
			var leg := Vector3(cos(a * TAU / 3.0), 0, sin(a * TAU / 3.0)) * 0.35
			B.tube(self, sp + Vector3(0, 0.45, 0), sp + leg, 0.015, Color(0.2, 0.2, 0.22))
		B.mesh(self, B.boxm(Vector3(0.5, 0.75, 0.42)), sp + Vector3(0, 1.55, 0), black)
		var cone := B.mesh(self, B.cyl(0.17, 0.17, 0.03, 16), sp + Vector3(0, 1.45, -0.215), Color(0.2, 0.2, 0.22),
			Vector3(PI / 2.0, 0, 0))
		_pa_cones.append(cone)
		B.mesh(self, B.boxm(Vector3(0.3, 0.1, 0.02)), sp + Vector3(0, 1.8, -0.215), Color(0.3, 0.3, 0.32))
		var p := AudioStreamPlayer3D.new()
		p.bus = "Music"
		p.stream = Sfx.music_stream()
		p.position = sp + Vector3(0, 1.5, 0)
		p.unit_size = 8.0
		p.max_distance = 60.0
		add_child(p)
		_pa_players.append(p)
	# Mikseri pöydän päässä, pääte räkissä lattialla penkin päädyssä, mikki jalustalla.
	B.mesh(self, B.boxm(Vector3(0.55, 0.08, 0.42)), Vector3(-1.75, 0.79, 1.55), Color(0.28, 0.3, 0.33))
	for k in 6:
		B.mesh(self, B.boxm(Vector3(0.03, 0.02, 0.12)), Vector3(-1.95 + k * 0.08, 0.84, 1.6), Color(0.85, 0.85, 0.85))
	_solid(Vector3(0.5, 0.45, 0.45), Vector3(-1.1, 0.225, 2.4), black)
	B.mesh(self, B.boxm(Vector3(0.46, 0.08, 0.02)), Vector3(-1.1, 0.35, 2.17), Color(0.3, 0.3, 0.32))
	B.mesh(self, B.cyl(0.015, 0.015, 1.3, 6), Vector3(-0.3, 0.65, 2.3), Color(0.2, 0.2, 0.22))
	B.mesh(self, B.cyl(0.03, 0.02, 0.18, 8), Vector3(-0.3, 1.35, 2.25), Color(0.15, 0.15, 0.15), Vector3(-0.5, 0, 0))
	# Päällä: LEDit ja johdot lattialla.
	for led in [Vector3(-1.55, 0.84, 1.4), Vector3(-1.25, 0.35, 2.165), Vector3(-1.2, 0.35, 2.165)]:
		var l := B.mesh(self, B.sphere(0.02, 6), led, Color.WHITE)
		l.material_override = B.unshaded(Color(0.2, 1.0, 0.3))
		_pa_lit.append(l)
	for sp in PA_SPEAKERS:
		var c := B.tube(self, Vector3(-1.1, 0.02, 2.6), sp + Vector3(0, 0.02, 0), 0.012, Color(0.95, 0.6, 0.1))
		_pa_lit.append(c)
	_pa_lit.append(B.tube(self, Vector3(-1.75, 0.02, 1.9), Vector3(-1.1, 0.02, 2.2), 0.012, Color(0.25, 0.35, 0.55)))
	for n in _pa_lit:
		n.visible = false


## Tunnusmusiikin voimakkuus kaiuttimissa (0 = hiljaa). Soittimet käynnistyvät yhtä aikaa, jotta ne pysyvät tahdissa.
func set_pa_level(v: float) -> void:
	for p in _pa_players:
		if p.stream == null:
			continue
		if v <= 0.01:
			p.stop()
			continue
		p.volume_db = PA_DB + linear_to_db(v)
		if not p.playing:
			p.play()
	for n in _pa_lit:
		n.visible = v > 0.01


## Onnistuneen kytkennän jälkeen PA jää päälle (taso minipelin lopusta), sammutus hiljentää.
func set_pa(on: bool, v := 0.0) -> void:
	pa_on = on
	set_pa_level(v if on else 0.0)
