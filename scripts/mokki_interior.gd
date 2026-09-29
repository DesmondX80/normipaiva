extends Node3D
## Mökin sisätila (Airbnb-ilmoituksen kuvien mukaan, noin 1,5x mitoitettuna pelattavuuden vuoksi): avokeittiö ja
## ruokailutila (pitkä pöytä, vuodesofa, TV, takka), makuuhuone violetteine kerrossänkyineen, kylpyhuone suihkuineen
## ja sisäsauna. Erillinen tasku kuten kaupan sisätila: kuistin ovelta sisään (main.gd _enter_mokki), kävely
## player_walker.gd:llä ylhäältä kuvattuna, katto pois. Toiminnot ilmoitetaan acted-signaalilla (tilavaikutukset
## ja viestit main.gd:ssä), nukkuminen slept-signaalilla (päivä vaihtuu, uusi päivä alkaa mökiltä).
## Paikallinen +Z = etuseinä ja ulko-ovi (kameran puoli), -Z = takaseinä ja keittiö.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")
const Mokki := preload("res://scripts/mokki.gd")

const HALF := Vector2(7.0, 3.75)  # huoneiston puolikas (x, z)
const WALL_H := 2.4
## Toimintopisteet: id -> [paikka, vihje].
const SPOTS := {
	"ovi": [Vector3(-3.0, 0, 2.9), "[E] Ulos kuistille"],
	"santtu": [Vector3(-1.6, 0, -2.0), "[E] Jutskaa Santun kanssa"],
	"kahvi": [Vector3(-3.1, 0, -2.3), "[E] Keitä suodatinkahvit"],
	"jaakaappi": [Vector3(-6.2, 0, -2.3), "[E] Kurkkaa jääkaappiin"],
	"takka": [Vector3(-0.2, 0, -1.4), "[E] Sytytä takka"],
	"tv": [Vector3(-1.4, 0, 1.9), "[E] Katso telkkaria"],
	"sanky": [Vector3(3.0, 0, -2.0), "[E] Mene nukkumaan kerrossänkyyn (päivä päättyy)"],
	"suihku": [Vector3(2.3, 0, 2.6), "[E] Käy suihkussa"],
	"sauna": [Vector3(5.0, 0, 2.3), "[E] Käy sisäsaunassa"],
}
const SANTTU_IN_LINES := [
	"Suodatinkahvia on aina tarjolla. Se on ilmoituksen kohokohtia!",
	"Kerrossängyt on violetit. Tytär maalas, en kehdannu kieltää.",
	"Sisäsauna on sähköllä... ei kun puulla. Savusauna pihalla on se oikea.",
	"Takka vetää hyvin, kunhan muistaa avata pellin.",
	"Vesi ja sähkö on, mitä muuta ihminen tarvii?",
	"Superhost, viides vuosi. Arvosteluja ei vielä yhtään, mutta tulee, tulee.",
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


func _ready() -> void:
	_build_room()
	_build_kitchen_dining()
	_build_bedroom()
	_build_bath_sauna()
	_santtu = Looks.make(self, Mokki.SANTTU_LOOK)
	_santtu.position = Vector3(-2.0, 0, -2.9)
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
	walker.position = SPOTS.ovi[0] + Vector3(0, 0, -1.5)
	walker.rotation.y = PI
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
	if not active:
		return
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(12.0, 20.0)
		say(SANTTU_IN_LINES.pick_random())
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
	# Ulkoseinät: taka ja päädyt täyskorkeat, etuseinä matala kameran vuoksi (törmäys täyskorkea).
	_wall(Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, -HALF.y), WALL_H, panel)
	_wall(Vector2(-HALF.x, -HALF.y), Vector2(-HALF.x, HALF.y), WALL_H, panel)
	_wall(Vector2(HALF.x, -HALF.y), Vector2(HALF.x, HALF.y), WALL_H, panel)
	_wall(Vector2(-HALF.x, HALF.y), Vector2(HALF.x, HALF.y), 0.5, panel)
	# Ulko-ovi etuseinässä.
	B.mesh(self, B.boxm(Vector3(1.1, 0.06, 0.12)), Vector3(-3.0, 0.53, HALF.y), Color(0.4, 0.26, 0.15))
	# Punapuitteiset ikkunat takaseinässä (keittiö) ja päädyssä.
	for wx in [-5.8, -3.6, -1.2, 2.2, 5.2]:
		B.mesh(self, B.boxm(Vector3(1.3, 1.1, 0.06)), Vector3(wx, 1.45, -HALF.y + 0.1), Color(0.55, 0.12, 0.14))
		B.mesh(self, B.boxm(Vector3(1.1, 0.9, 0.07)), Vector3(wx, 1.45, -HALF.y + 0.11), Color(0.55, 0.75, 0.6))
	# Väliseinät: makuuhuone ja kylpyhuone oikealla, oviaukot.
	var wall2 := panel.darkened(0.05)
	_wall(Vector2(1.0, -HALF.y), Vector2(1.0, -1.6), WALL_H, wall2)
	_wall(Vector2(1.0, -0.5), Vector2(1.0, 1.8), WALL_H, wall2)
	_wall(Vector2(1.0, 2.9), Vector2(1.0, HALF.y), WALL_H, wall2)
	_wall(Vector2(1.0, 0.6), Vector2(HALF.x, 0.6), WALL_H, wall2)
	_wall(Vector2(4.0, 0.6), Vector2(4.0, 1.7), WALL_H, Color(0.3, 0.22, 0.15))
	_wall(Vector2(4.0, 2.8), Vector2(4.0, HALF.y), WALL_H, Color(0.3, 0.22, 0.15))
	for l in [Vector3(-3.5, 2.3, 0.0), Vector3(3.5, 2.3, -1.5)]:
		var light := OmniLight3D.new()
		light.position = l
		light.omni_range = 9.0
		light.light_energy = 0.4
		add_child(light)


func _build_kitchen_dining() -> void:
	var white := Color(0.93, 0.92, 0.88)
	var wood := Color(0.62, 0.42, 0.22)
	# Keittiö takaseinällä: valkoiset kaapit, puiset työtasot, liesi, jääkaappi ja kahvinkeitin.
	_solid(Vector3(4.2, 0.9, 0.8), Vector3(-4.3, 0.45, -HALF.y + 0.45), white)
	B.mesh(self, B.boxm(Vector3(4.3, 0.05, 0.85)), Vector3(-4.3, 0.92, -HALF.y + 0.45), wood)
	B.mesh(self, B.boxm(Vector3(0.7, 0.04, 0.6)), Vector3(-4.6, 0.95, -HALF.y + 0.45), Color(0.1, 0.1, 0.1))  # liesi
	for kx in [-4.8, -4.4]:
		B.mesh(self, B.cyl(0.1, 0.1, 0.02, 12), Vector3(kx, 0.98, -HALF.y + 0.4), Color(0.25, 0.25, 0.25))
	_solid(Vector3(0.8, 1.9, 0.75), Vector3(-6.5, 0.95, -HALF.y + 0.45), white)  # jääkaappi
	B.mesh(self, B.boxm(Vector3(0.45, 0.28, 0.35)), Vector3(-5.9, 1.08, -HALF.y + 0.35), Color(0.85, 0.85, 0.85))  # mikro
	B.mesh(self, B.cyl(0.08, 0.1, 0.3, 12), Vector3(-3.1, 1.1, -HALF.y + 0.4), Color(0.08, 0.08, 0.08))  # kahvinkeitin
	B.mesh(self, B.cyl(0.07, 0.07, 0.12, 12), Vector3(-3.1, 1.0, -HALF.y + 0.62), Color(0.6, 0.7, 0.75))  # kannu
	# Kuvioitu matto ja pitkä puupöytä tuoleineen.
	B.mesh(self, B.boxm(Vector3(3.6, 0.01, 2.4)), Vector3(-4.0, 0.01, 0.4), Color(0.55, 0.58, 0.5))
	_solid(Vector3(2.6, 0.75, 0.9), Vector3(-4.0, 0.375, 0.4), wood)
	for cx in [-5.0, -4.0, -3.0]:
		for cz in [-0.35, 1.15]:
			B.mesh(self, B.boxm(Vector3(0.42, 0.45, 0.42)), Vector3(cx, 0.22, 0.4 + cz), Color(0.85, 0.55, 0.15))
	# Vuodesofa vasemmalla seinällä.
	_solid(Vector3(0.9, 0.5, 2.2), Vector3(-HALF.x + 0.55, 0.25, 1.8), Color(0.8, 0.8, 0.78))
	B.mesh(self, B.boxm(Vector3(0.2, 0.5, 2.2)), Vector3(-HALF.x + 0.15, 0.6, 1.8), Color(0.62, 0.45, 0.28))
	# TV-nurkkaus: taso ja televisio (näyttö syttyy katsottaessa).
	_solid(Vector3(1.2, 0.5, 0.5), Vector3(-1.4, 0.25, 3.1), Color(0.3, 0.22, 0.16))
	B.mesh(self, B.boxm(Vector3(1.0, 0.6, 0.08)), Vector3(-1.4, 0.85, 3.2), Color(0.06, 0.06, 0.07))
	_tv_screen = B.mesh(self, B.boxm(Vector3(0.9, 0.5, 0.02)), Vector3(-1.4, 0.85, 3.15), Color.BLACK)
	_tv_screen.material_override = B.unshaded(Color(0.3, 0.45, 0.8))
	_tv_screen.visible = false
	# Musta takka (kamina) piippuineen väliseinän vieressä.
	_solid(Vector3(0.8, 0.9, 0.6), Vector3(0.3, 0.45, -2.2), Color(0.1, 0.1, 0.11))
	B.mesh(self, B.cyl(0.12, 0.12, 1.6, 10), Vector3(0.3, 1.7, -2.3), Color(0.1, 0.1, 0.11))
	_takka_fire = Node3D.new()
	_takka_fire.position = Vector3(0.3, 0.35, -1.88)
	add_child(_takka_fire)
	var flame := B.mesh(_takka_fire, B.boxm(Vector3(0.4, 0.25, 0.02)), Vector3.ZERO, Color.WHITE)
	flame.material_override = B.unshaded(Color(1.0, 0.5, 0.1))
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.55, 0.2)
	fl.omni_range = 4.0
	fl.position = Vector3(0, 0.3, 0.4)
	_takka_fire.add_child(fl)
	_takka_fire.visible = false


func _build_bedroom() -> void:
	var purple := Color(0.72, 0.4, 0.72)
	var mattress := Color(0.9, 0.88, 0.82)
	# Kaksi violettia kerrossänkyä L-muodossa (takaseinä ja päätyseinä).
	for bunk in [[Vector3(2.9, 0, -HALF.y + 0.5), 0.0], [Vector3(HALF.x - 0.5, 0, -1.9), PI / 2.0]]:
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
	# Portaat, pöytä, oranssi tuoli ja radio.
	B.mesh(self, B.boxm(Vector3(0.4, 0.6, 0.35)), Vector3(4.2, 0.3, -2.6), Color(0.7, 0.55, 0.35))
	_solid(Vector3(0.9, 0.7, 0.6), Vector3(5.8, 0.35, -0.1), Color(0.93, 0.92, 0.88))
	B.mesh(self, B.boxm(Vector3(0.3, 0.18, 0.12)), Vector3(6.0, 0.8, -0.1), Color(0.2, 0.2, 0.22))
	B.mesh(self, B.boxm(Vector3(0.42, 0.45, 0.42)), Vector3(5.0, 0.22, -0.2), Color(0.85, 0.55, 0.15))


func _build_bath_sauna() -> void:
	# Kylpyhuone: valkoinen laatta, ruskea lattialaatta, suihku ja punainen saavi.
	B.mesh(self, B.boxm(Vector3(2.9, 0.02, 3.0)), Vector3(2.5, 0.02, 2.2), Color(0.45, 0.25, 0.15))
	B.mesh(self, B.boxm(Vector3(2.9, WALL_H, 0.05)), Vector3(2.5, WALL_H / 2.0, HALF.y - 0.05), Color(0.95, 0.95, 0.93))
	B.mesh(self, B.cyl(0.02, 0.02, 1.9, 6), Vector3(1.4, 0.95, 3.4), Color(0.75, 0.75, 0.78))
	B.mesh(self, B.cyl(0.08, 0.05, 0.05, 10), Vector3(1.4, 1.9, 3.3), Color(0.75, 0.75, 0.78))
	B.mesh(self, B.cyl(0.18, 0.15, 0.25, 12), Vector3(3.4, 0.13, 3.3), Color(0.85, 0.12, 0.12))
	# Sisäsauna: tummat paneelit, kaksitasoiset lauteet ja puukiuas.
	var dark := Color(0.3, 0.22, 0.15)
	B.mesh(self, B.boxm(Vector3(2.9, 0.02, 3.0)), Vector3(5.5, 0.02, 2.2), Color(0.5, 0.48, 0.44))
	_solid(Vector3(2.8, 0.45, 0.7), Vector3(5.5, 0.22, 3.3), Color(0.62, 0.48, 0.3))
	B.mesh(self, B.boxm(Vector3(2.8, 0.05, 0.6)), Vector3(5.5, 0.9, 3.45), Color(0.62, 0.48, 0.3))
	B.mesh(self, B.boxm(Vector3(2.9, WALL_H, 0.05)), Vector3(5.5, WALL_H / 2.0, HALF.y - 0.05), dark)
	_solid(Vector3(0.6, 0.8, 0.6), Vector3(6.5, 0.4, 1.2), Color(0.12, 0.12, 0.12))
	for k in 6:
		B.mesh(self, B.sphere(0.09, 6), Vector3(6.35 + (k % 3) * 0.15, 0.85, 1.1 + (k / 3) * 0.2), Color(0.45, 0.44, 0.42))
	B.mesh(self, B.cyl(0.1, 0.12, 0.22, 10), Vector3(5.8, 0.11, 1.0), Color(0.15, 0.4, 0.8))  # sininen kiulu kuten kuvassa
