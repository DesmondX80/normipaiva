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

const HALF := Vector2(7.0, 3.75)  # huoneiston puolikas (x, z); tien puoli z = HALF.y
## Kuistin puoleinen ulkoseinä: keittiö ja pesutilat on levennetty kuistille päin pelattavuuden vuoksi.
const BACK := -5.0
const WALL_H := 2.4
const LOW_WALL := 1.0  # kameran puoleisten väliseinien näkyvä korkeus
## Pohja on suorakaide, jonka vasemmasta kuistin puoleisesta nurkasta puuttuu lovi (NOTCH, ulkona; ulko-ovi loven seinässä).
## Keittiö on loven vieressä tuvan takaseinän (väliseinä TV:n takana) takana, aukko KITCHEN_GAP (x alku, x loppu).
const NOTCH := Rect2(-7.0, BACK, 1.6, -1.8 - BACK)
const KITCHEN := Rect2(-5.4, BACK, 6.4, -1.8 - BACK)
const KITCHEN_GAP := Vector2(-2.3, -1.2)
## Pesutilat (kuvien mukaan): keittiöstä oviaukko pitkään pesuhuoneeseen (WASH, kuistin puolella). Vasemmalla
## seinällä ovi kuistille ja ikkuna, oikealla saunan lasiovi, perällä suihku ja sen oikealla lasisen suihkuseinän
## takana pönttö istumasuunta suihkuun päin; pesuhuoneen perällä oikealla penkki pesuvateineen.
## Sauna (SAUNA) pesuhuoneen ja makuuhuoneen välissä: ovelta katsottuna lauteet vasemmalla ja perällä, kiuas oikealla
## perimmäisessä nurkassa.
const WASH := Rect2(1.0, BACK, 6.0, 2.4)
const SAUNA := Rect2(1.0, -2.6, 4.2, 2.0)
const WASH_DOOR := Vector2(-4.4, -3.4)  # keittiön ja pesuhuoneen oviaukko (z alku, z loppu) seinässä x = 1
const SAUNA_DOOR := Vector2(2.4, 3.3)  # saunan oviaukko (x alku, x loppu) seinässä z = -2.6
const SHOWER_Z := -3.7  # suihkuseinä (lasi) perällä
## Toimintopisteet: id -> [paikka, vihje].
const SPOTS := {
	"ovi": [Vector3(-6.3, 0, -1.1), "[E] Ulos kuistille"],
	"ovi2": [Vector3(2.0, 0, -4.3), "[E] Ulos kuistille (pesuhuoneen ovi)"],
	"santtu": [Vector3(-1.5, 0, -2.6), "[E] Jutskaa Santun kanssa"],
	"kahvi": [Vector3(-2.8, 0, -3.7), "[E] Keitä suodatinkahvit"],
	"tiskit": [Vector3(-4.3, 0, -3.7), "[E] Tiskaa astiat"],
	"jaakaappi": [Vector3(0.4, 0, -3.7), "[E] Kurkkaa jääkaappiin"],
	"takka": [Vector3(-0.4, 0, -0.9), "[E] Sytytä takka"],
	"tv": [Vector3(-3.9, 0, -0.6), "[E] Katso telkkaria"],
	"sanky": [Vector3(4.9, 0, 1.2), "[E] Mene nukkumaan kerrossänkyyn (päivä päättyy)"],
	"suihku": [Vector3(5.4, 0, -4.4), "[E] Käy suihkussa"],
	"wc": [Vector3(5.5, 0, -3.1), "[E] Käy pöntöllä"],
	"sauna": [Vector3(2.85, 0, -1.7), "[E] Käy sisäsaunassa"],
	"pa": [Vector3(-0.9, 0, 1.55), "[E] Kytke Santun PA-laitteet"],
	"sokeri": [Vector3(-1.4, 0, -3.7), "[E] Ota sokeria Santun keittiön kaapista (Santtu suuttuu!)"],
	"sangot": [Vector3(5.75, 0, -1.75), ""],  # Paapelin viinisaavi pöntön takana: vihje main.gd:stä
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
var exit_door := "ovi"  # kummasta ovesta viimeksi lähdettiin ulos (ovi / ovi2)
var walker: CharacterBody3D
var hint := ""
var spot := ""  # lähin toimintopiste
var _wine_liquid: Array[MeshInstance3D] = []
var _wine_cloth: Array[MeshInstance3D] = []
var _blubs: Array[Label3D] = []
var _blub_t := 0.0
var wine_stage := ""
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
## Likaisia astioita tiskipöydällä (Santun homma: tiski_game.gd). 0 = tiskipöytä on siisti.
var dishes := 0
var _dish_pile: Node3D


func _ready() -> void:
	_build_room()
	_build_wine_buckets()
	_build_kitchen_dining()
	_build_bedroom()
	_build_bath_sauna()
	_build_pa()
	_santtu = Looks.make(self, Mokki.SANTTU_LOOK)
	_santtu.position = Vector3(-1.5, 0, -3.4)
	_santtu.rotation.y = B.yaw_to(Vector3(0.3, 0, 1))
	_santtu.play("Idle", 0.0)
	var body := StaticBody3D.new()
	body.position = _santtu.position
	body.add_child(B.capsule_shape(0.3, 1.8))
	add_child(body)
	_bubble = B.bubble(self, _santtu.position + Vector3(0, 1.9, 0), Color.WHITE, 0.7)
	walker = Walker.new()
	walker.position = SPOTS.ovi[0]
	add_child(walker)


func enter(door := "ovi") -> void:
	active = true
	_enter_frame = Engine.get_process_frames()  # sisään vienyt E ei saa samalla ruudulla viedä ulos
	if door == "ovi2":
		walker.position = SPOTS.ovi2[0] + Vector3(0, 0, 0.9)  # pesuhuoneeseen
		walker.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	else:
		walker.position = SPOTS.ovi[0] + Vector3(0, 0, 1.5)
		walker.rotation.y = B.yaw_to(Vector3(0, 0, -1))  # katse tupaan (walkerin kääntö on yaw_to:n vastainen)
	walker.activate()
	say("No terve! Tuu sisälle vaan.")


func leave() -> void:
	active = false
	walker.controls_enabled = false


## Likaiset astiat tiskipöydälle (n kpl, 0 = siisti).
func set_dishes(n: int) -> void:
	dishes = n
	if _dish_pile != null:
		_dish_pile.visible = n > 0
		for i in _dish_pile.get_child_count():
			(_dish_pile.get_child(i) as Node3D).visible = i < n


## Paapelin viinisaavi pesuhuoneessa pöntön takana: puinen saavi vanteineen, liina ja vesilukko.
const WINE_VAT := Vector3(6.4, 0, -2.2)


func _build_wine_buckets() -> void:
	var c := WINE_VAT
	var wood := Color(0.52, 0.34, 0.18)
	B.mesh(self, B.cyl(0.34, 0.29, 0.6, 18), c + Vector3(0, 0.3, 0), wood)
	for y in [0.12, 0.52]:
		B.mesh(self, B.cyl(0.33 if y > 0.3 else 0.305, 0.33 if y > 0.3 else 0.305, 0.04, 18), c + Vector3(0, y, 0), Color(0.3, 0.3, 0.32))
	for k in 10:
		var a := k * TAU / 10.0
		B.mesh(self, B.boxm(Vector3(0.012, 0.58, 0.02)), c + Vector3(cos(a) * 0.315, 0.3, sin(a) * 0.315), wood.darkened(0.25),
			Vector3(0, -rad_to_deg(a), 0))
	var body := StaticBody3D.new()
	body.position = c + Vector3(0, 0.35, 0)
	body.add_child(B.box_shape(Vector3(0.7, 0.7, 0.7)))
	add_child(body)
	var liq := B.mesh(self, B.cyl(0.31, 0.31, 0.01, 18), c + Vector3(0, 0.58, 0), Color(0.35, 0.12, 0.25))
	_wine_liquid.append(liq)
	var cloth := B.mesh(self, B.cyl(0.36, 0.36, 0.012, 18), c + Vector3(0, 0.62, 0), Color(0.9, 0.86, 0.78))
	B.mesh(cloth, B.cyl(0.025, 0.025, 0.16, 8), Vector3(0, 0.08, 0), Color(0.85, 0.9, 0.92, 0.8))
	B.mesh(cloth, B.sphere(0.04, 8), Vector3(0, 0.17, 0), Color(0.8, 0.9, 0.95))
	_wine_cloth.append(cloth)
	for i in 3:
		var bl := B.guide(self, "blub", c + Vector3(0, 1.0, 0), 24, Color(0.9, 0.7, 0.85), true)
		bl.visible = false
		_blubs.append(bl)
	B.guide(self, "Viinisaavi", c + Vector3(0, 1.25, 0), 20, Color(1, 1, 1), true)
	set_wine("")


func set_wine(stage: String) -> void:
	wine_stage = stage
	for l in _wine_liquid:
		l.visible = stage != ""
		(l.material_override as StandardMaterial3D).albedo_color = Color(0.45, 0.05, 0.2) if stage == "valmis" \
			else Color(0.35, 0.12, 0.25)
	for c in _wine_cloth:
		c.visible = stage == "kay"
	for bl in _blubs:
		bl.visible = false


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
	if wine_stage == "kay":
		_blub_t -= delta
		if _blub_t <= 0.0:
			_blub_t = randf_range(1.4, 2.8)
			for bl in _blubs:
				if not bl.visible:
					bl.visible = true
					bl.position = WINE_VAT + Vector3(randf_range(-0.15, 0.15), 1.0, 0)
					bl.modulate.a = 1.0
					break
		for bl in _blubs:
			if bl.visible:
				bl.position.y += delta * 0.4
				bl.modulate.a -= delta * 0.6
				if bl.modulate.a <= 0.0:
					bl.visible = false
	if not active or busy:
		hint = ""
		spot = ""
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
	spot = best
	if best == "":
		return
	hint = SPOTS[best][1]
	if best == "pa" and pa_on:
		hint = "[E] Sammuta PA (pääte ensin pois)"
	if best == "takka" and takka_on:
		hint = "Takka lämmittää mukavasti."
		return
	if best == "tiskit":
		if dishes <= 0:
			hint = "Tiskipöytä on siisti."
			return
		hint = "[E] Tiskaa astiat (%d likaista)" % dishes
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	match best:
		"ovi", "ovi2":
			exit_door = best
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
	var depth := HALF.y - BACK
	var mid_z := (HALF.y + BACK) / 2.0
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, depth)), Vector3(0, -0.05, mid_z), Color(0.48, 0.5, 0.5))
	for i in 18:
		var x := -HALF.x + 0.4 + i * 0.78
		B.mesh(self, B.boxm(Vector3(0.02, 0.01, depth)), Vector3(x, 0.005, mid_z), Color(0.38, 0.4, 0.4))
	# Lovi (ulkotilaa) vasemmassa nurkassa kuistin puolella: maan värinen lattia lattialautojen päälle.
	B.mesh(self, B.boxm(Vector3(NOTCH.size.x + 0.1, 0.02, NOTCH.size.y + 0.1)), Vector3(NOTCH.get_center().x - 0.05, 0.02,
		NOTCH.get_center().y - 0.05), Color(0.3, 0.33, 0.22))
	# Ulkoseinät: takaseinä (keittiön perä), loven kaksi seinää ja päädyt täyskorkeat, etuseinä matala kameran
	# vuoksi (törmäys täyskorkea).
	_wall(Vector2(NOTCH.end.x, BACK), Vector2(HALF.x, BACK), WALL_H, panel)
	_wall(Vector2(-HALF.x, NOTCH.end.y), Vector2(NOTCH.end.x, NOTCH.end.y), WALL_H, panel)
	_wall(Vector2(NOTCH.end.x, BACK), Vector2(NOTCH.end.x, NOTCH.end.y), WALL_H, panel)
	_wall(Vector2(-HALF.x, NOTCH.end.y), Vector2(-HALF.x, HALF.y), WALL_H, panel)
	_wall(Vector2(HALF.x, BACK), Vector2(HALF.x, HALF.y), WALL_H, panel)
	_wall(Vector2(-HALF.x, HALF.y), Vector2(HALF.x, HALF.y), 0.5, panel)
	# Lasiovi ulos loven seinässä (tuvan vasen takanurkka), päätyseinällä ikkuna.
	B.mesh(self, B.boxm(Vector3(1.0, 2.05, 0.06)), Vector3(SPOTS.ovi[0].x, 1.02, NOTCH.end.y + 0.08), Color(0.95, 0.95, 0.93))
	B.mesh(self, B.boxm(Vector3(0.8, 1.8, 0.07)), Vector3(SPOTS.ovi[0].x, 1.05, NOTCH.end.y + 0.09), Color(0.6, 0.78, 0.7))
	B.mesh(self, B.boxm(Vector3(0.06, 1.1, 1.3)), Vector3(-HALF.x + 0.08, 1.45, 2.2), Color(0.95, 0.95, 0.93))
	B.mesh(self, B.boxm(Vector3(0.07, 0.9, 1.1)), Vector3(-HALF.x + 0.09, 1.45, 2.2), Color(0.55, 0.75, 0.6))
	# Punapuitteinen ikkuna keittiön kuistin puoleisessa seinässä.
	B.mesh(self, B.boxm(Vector3(1.3, 1.1, 0.06)), Vector3(-1.5, 1.45, BACK + 0.1), Color(0.55, 0.12, 0.14))
	B.mesh(self, B.boxm(Vector3(1.1, 0.9, 0.07)), Vector3(-1.5, 1.45, BACK + 0.11), Color(0.55, 0.75, 0.6))
	# Väliseinät oikealla: pesuhuone kuistin puolella, sauna sen ja makuuhuoneen välissä, makuuhuone tien puolella.
	var wall2 := panel.darkened(0.05)
	_wall(Vector2(1.0, BACK), Vector2(1.0, WASH_DOOR.x), WALL_H, wall2)
	_wall(Vector2(1.0, WASH_DOOR.y), Vector2(1.0, 1.55), WALL_H, wall2)
	_wall(Vector2(1.0, 2.65), Vector2(1.0, HALF.y), WALL_H, wall2)
	# Kameran suuntaiset (x-akselin) väliseinät matalina kuten etuseinä: ylhäältä vinosti kuvattaessa ne
	# eivät peitä takana olevia huoneita (pesuhuone, sauna); törmäys on täyskorkea.
	_wall(Vector2(1.0, -0.6), Vector2(HALF.x, -0.6), LOW_WALL, wall2, WALL_H)
	var dark := Color(0.3, 0.22, 0.15)
	_wall(Vector2(1.0, SAUNA.position.y), Vector2(SAUNA_DOOR.x, SAUNA.position.y), LOW_WALL, dark, WALL_H)
	_wall(Vector2(SAUNA_DOOR.y, SAUNA.position.y), Vector2(SAUNA.end.x, SAUNA.position.y), LOW_WALL, dark, WALL_H)
	_wall(Vector2(SAUNA.end.x, SAUNA.position.y), Vector2(SAUNA.end.x, -0.6), WALL_H, dark)
	# Keittiön ja tuvan väliseinä (TV:n takana) ja aukko pylvään kohdalla.
	_wall(Vector2(NOTCH.end.x, KITCHEN.end.y), Vector2(KITCHEN_GAP.x, KITCHEN.end.y), WALL_H, wall2)
	_wall(Vector2(KITCHEN_GAP.y, KITCHEN.end.y), Vector2(KITCHEN.end.x, KITCHEN.end.y), WALL_H, wall2)
	for l in [Vector3(-3.5, 2.3, 0.0), Vector3(-2.0, 2.3, -3.4), Vector3(4.0, 2.3, -3.8), Vector3(3.0, 2.3, -1.6),
			Vector3(4.0, 2.3, 1.5)]:
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
	# Tiskiallas ja hana mikron ja lieden välissä, likaiset astiat pinossa vieressä (tiskipäivinä).
	B.mesh(self, B.boxm(Vector3(0.5, 0.03, 0.42)), Vector3(SPOTS.tiskit[0].x, 0.955, kback + 0.45), Color(0.62, 0.64, 0.67))
	B.mesh(self, B.cyl(0.015, 0.015, 0.25, 6), Vector3(SPOTS.tiskit[0].x, 1.08, kback + 0.22), Color(0.7, 0.7, 0.72))
	_dish_pile = Node3D.new()
	_dish_pile.position = Vector3(SPOTS.tiskit[0].x + 0.45, 0.95, kback + 0.5)
	add_child(_dish_pile)
	for k in 6:
		B.mesh(_dish_pile, B.cyl(0.13, 0.11, 0.025, 12), Vector3(randf_range(-0.03, 0.03), 0.015 + k * 0.03, randf_range(-0.03, 0.03)),
			Color(0.92, 0.9, 0.86) if k % 2 == 0 else Color(0.78, 0.66, 0.5))
	_dish_pile.visible = false
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
	var tile := Color(0.95, 0.94, 0.9)
	var floor_tile := Color(0.55, 0.3, 0.18)
	var pine := Color(0.72, 0.52, 0.3)
	# Pesuhuone: ruskea klinkkerilattia, valkoinen laatoitus seinillä, mäntypaneelikatto (katto pois kameran vuoksi).
	B.mesh(self, B.boxm(Vector3(WASH.size.x, 0.02, WASH.size.y)), Vector3(WASH.get_center().x, 0.02, WASH.get_center().y), floor_tile)
	for k in 12:
		B.mesh(self, B.boxm(Vector3(0.015, 0.025, WASH.size.y)), Vector3(WASH.position.x + 0.5 * k, 0.025, WASH.get_center().y),
			Color(0.2, 0.12, 0.08))
	B.mesh(self, B.boxm(Vector3(WASH.size.x, WALL_H, 0.03)), Vector3(WASH.get_center().x, WALL_H / 2.0, BACK + 0.09), tile)
	B.mesh(self, B.boxm(Vector3(0.03, WALL_H, WASH.size.y)), Vector3(HALF.x - 0.09, WALL_H / 2.0, WASH.get_center().y), tile)
	# Vasemmalla (kuistin puoli) puinen ovi kuistille ikkunoineen ja pieni ikkuna.
	var dx: float = SPOTS.ovi2[0].x
	B.mesh(self, B.boxm(Vector3(0.95, 2.05, 0.06)), Vector3(dx, 1.02, BACK + 0.12), Color(0.7, 0.5, 0.3))
	B.mesh(self, B.boxm(Vector3(0.55, 0.6, 0.07)), Vector3(dx, 1.55, BACK + 0.13), Color(0.55, 0.75, 0.6))
	B.mesh(self, B.boxm(Vector3(0.05, 0.08, 0.1)), Vector3(dx + 0.35, 1.0, BACK + 0.16), Color(0.75, 0.72, 0.6))
	B.mesh(self, B.boxm(Vector3(0.75, 0.6, 0.06)), Vector3(3.4, 1.7, BACK + 0.12), Color(0.55, 0.32, 0.2))
	B.mesh(self, B.boxm(Vector3(0.6, 0.45, 0.07)), Vector3(3.4, 1.7, BACK + 0.13), Color(0.55, 0.75, 0.6))
	# Perällä suihku: hana ja suihkuletku seinässä, lattiakaivo; oikealla lasinen suihkuseinä.
	var sx := HALF.x - 0.12
	var sz := (BACK + SHOWER_Z) / 2.0
	B.mesh(self, B.cyl(0.015, 0.015, 1.1, 6), Vector3(sx, 1.35, sz), Color(0.8, 0.8, 0.82))
	B.mesh(self, B.cyl(0.06, 0.04, 0.12, 10), Vector3(sx - 0.05, 1.92, sz), Color(0.8, 0.8, 0.82), Vector3(0, 0, 60))
	B.mesh(self, B.boxm(Vector3(0.08, 0.06, 0.2)), Vector3(sx - 0.04, 0.95, sz), Color(0.8, 0.8, 0.82))
	B.mesh(self, B.cyl(0.08, 0.08, 0.01, 12), Vector3(HALF.x - 0.6, 0.035, sz), Color(0.35, 0.35, 0.36))
	var glass := B.mesh(self, B.boxm(Vector3(1.1, 2.0, 0.03)), Vector3(HALF.x - 0.6, 1.0, SHOWER_Z), Color.WHITE)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.8, 0.9, 0.95, 0.35)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override = gm
	var gb := StaticBody3D.new()
	gb.position = Vector3(HALF.x - 0.6, 0, SHOWER_Z)
	gb.add_child(B.box_shape(Vector3(1.1, WALL_H, 0.05), Vector3(0, WALL_H / 2.0, 0)))
	add_child(gb)
	# Pönttö suihkuseinän takana, istumasuunta suihkuun päin (-Z); peili ja pyyhkeet seinällä.
	var wc := Node3D.new()
	wc.position = Vector3(HALF.x - 0.55, 0, SHOWER_Z + 0.55)
	add_child(wc)
	B.mesh(wc, B.boxm(Vector3(0.38, 0.4, 0.3)), Vector3(0, 0.2, 0.05), Color(0.97, 0.97, 0.97))
	B.mesh(wc, B.cyl(0.19, 0.17, 0.08, 16), Vector3(0, 0.42, -0.05), Color(0.97, 0.97, 0.97))
	B.mesh(wc, B.boxm(Vector3(0.38, 0.4, 0.18)), Vector3(0, 0.62, 0.25), Color(0.97, 0.97, 0.97))  # säiliö
	var wb := StaticBody3D.new()
	wb.add_child(B.box_shape(Vector3(0.4, 0.8, 0.6), Vector3(0, 0.4, 0.05)))
	wc.add_child(wb)
	B.mesh(self, B.boxm(Vector3(0.03, 0.6, 0.5)), Vector3(HALF.x - 0.12, 1.5, SHOWER_Z + 0.6), Color(0.75, 0.8, 0.85))
	# Oikealla saunan oven vieressä puupenkki pesuvateineen ja pyyhkeet naulakossa.
	var bench_x := SAUNA_DOOR.y + 0.9
	_solid(Vector3(1.0, 0.45, 0.45), Vector3(bench_x, 0.225, SAUNA.position.y - 0.3), pine)
	B.mesh(self, B.cyl(0.2, 0.16, 0.14, 12), Vector3(bench_x - 0.2, 0.52, SAUNA.position.y - 0.3), Color(0.85, 0.12, 0.12))
	B.mesh(self, B.cyl(0.18, 0.14, 0.12, 12), Vector3(bench_x + 0.25, 0.51, SAUNA.position.y - 0.3), Color(0.9, 0.9, 0.9))
	for k in 3:
		B.mesh(self, B.boxm(Vector3(0.3, 0.9, 0.05)), Vector3(bench_x + 0.8 + k * 0.32, 1.3, SAUNA.position.y - 0.05),
			[Color(0.35, 0.45, 0.7), Color(0.9, 0.9, 0.88), Color(0.3, 0.55, 0.75)][k])
	# Saunan lasiovi puukehyksessä (auki: oviaukko).
	B.mesh(self, B.boxm(Vector3(0.08, LOW_WALL, 0.08)), Vector3(SAUNA_DOOR.x, LOW_WALL / 2.0, SAUNA.position.y), pine)
	B.mesh(self, B.boxm(Vector3(0.08, LOW_WALL, 0.08)), Vector3(SAUNA_DOOR.y, LOW_WALL / 2.0, SAUNA.position.y), pine)
	# Sisäsauna: tummat paneelit, betonilattia, ovelta katsottuna lauteet vasemmalla (+X) ja perällä,
	# kiuas savupiippuineen oikeassa perimmäisessä nurkassa (-X, tien puoli), rappausseinä kiukaan takana.
	var dark := Color(0.28, 0.2, 0.13)
	B.mesh(self, B.boxm(Vector3(SAUNA.size.x, 0.02, SAUNA.size.y)), Vector3(SAUNA.get_center().x, 0.02, SAUNA.get_center().y),
		Color(0.6, 0.58, 0.54))
	B.mesh(self, B.boxm(Vector3(SAUNA.size.x, LOW_WALL, 0.03)), Vector3(SAUNA.get_center().x, LOW_WALL / 2.0, -0.63), dark)
	B.mesh(self, B.boxm(Vector3(0.03, WALL_H, SAUNA.size.y)), Vector3(1.04, WALL_H / 2.0, SAUNA.get_center().y), Color(0.7, 0.7, 0.68))
	var lx := SAUNA.end.x - 0.55
	_solid(Vector3(1.0, 0.45, SAUNA.size.y - 0.1), Vector3(lx - 0.15, 0.225, SAUNA.get_center().y + 0.05), pine)  # alalaude
	_solid(Vector3(0.7, 0.9, SAUNA.size.y - 0.1), Vector3(SAUNA.end.x - 0.35, 0.45, SAUNA.get_center().y + 0.05), pine)
	B.mesh(self, B.boxm(Vector3(2.4, 0.06, 0.55)), Vector3(SAUNA.end.x - 1.25, 0.9, -0.9), pine)  # peräseinän laude
	B.mesh(self, B.cyl(0.12, 0.1, 0.22, 10), Vector3(SAUNA.end.x - 0.4, 1.02, -0.9), Color(0.1, 0.35, 0.8))  # sininen kiulu
	B.mesh(self, B.sphere(0.06, 8), Vector3(SAUNA.end.x - 0.8, 0.96, -0.95), Color(0.75, 0.1, 0.1))  # punainen kauha
	_solid(Vector3(0.6, 0.75, 0.55), Vector3(1.4, 0.375, -1.0), Color(0.12, 0.12, 0.12))  # kiuas
	B.mesh(self, B.cyl(0.08, 0.08, 1.4, 10), Vector3(1.25, 1.45, -0.8), Color(0.1, 0.1, 0.1))
	for k in 9:
		B.mesh(self, B.sphere(0.08, 6), Vector3(1.25 + (k % 3) * 0.14, 0.8, -1.15 + (k / 3) * 0.14), Color(0.35, 0.35, 0.36))


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
