extends Node3D
## Saloisten tietokonemuseo (retket.gd "tietokonemuseo"): taskukohtaus kuten retki_paltaniemi.gd. Kävely player_walker.gd:llä.
## Takaseinällä vasemmalla Datasaab D22 -koneen kaapit (nauha-asemat, merkkivalopaneeli, korttilukija) ja konsolipöytä, oikealla mikrotietokonehuone
## (kolme tyyliteltyä 1980-luvun konetta) ja oikealla edessä Pong-pelikone. Intendentti kertoo koneista. Faktat (D22 1971, heinäkuun aukioloaika)
## "sanotaan"-muodossa, tarkistettava; koneet ovat tyyliteltyjä, eivät tarkkoja kopioita.
## Paikallinen -Z = takaseinä (koneet), +Z = ovi ja kamera. Kaikki koneet ja pelikone katsovat +Z:aan (kameraa kohti). Hahmon etu = -Z (basis * -Z);
## intendentti katsoo +Z:aan (kävijöitä kohti).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(8.0, 6.0)
const TILT := -25.0  # kyltit ja otsikot kallistetaan kameraa kohti

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var spot := ""
var legenda: RefCounted
var spots := {
	"ovi": [Vector3(6.8, 0, 4.8), "[E] Ulos: taksille takaisin lähtöpaikkaan"],
	"intendentti": [Vector3(-0.4, 0, -2.5), "[E] Juttele intendentin kanssa"],
	"d22": [Vector3(-4.4, 0, -2.4), "[E] Katso Datasaab D22:ta"],
	"mikrot": [Vector3(4.0, 0, -2.9), "[E] Katso mikrotietokoneita"],
	"pong": [Vector3(5.4, 0, 1.5), "[E] Pelaa Pongia"],
}
var _enter_frame := -1
var _curator: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
const BUBBLE_AT := Vector3(3.0, 0.4, -1.8)  # maailmassa intendentin oikealla lattialla: ei koneiden eikä intendentin päällä
const BUBBLE_FAR := 4.5  # kupla sulkeutuu, kun pelaaja kävelee tätä kauemmas intendentista
const CURATOR_LINES := ["Tämä on Datasaab D22, sanotaan vuodelta 1971. Tällainen kone täytti kokonaisen huoneen.",
	"Tuolla toisessa päässä on mikrot. Niillä pelattiin, ja välillä ohjelmoitiinkin.",
	"Pong-kone on käytössä. Ensin viiteen pisteeseen voittaa, mutta kone ei anna periksi.",
	"Museo on avoinna heinäkuussa, sanotaan. Muulloin tulee soittaa etukäteen."]
var _line := 0
var _blink_t := 0.0
var _lamps: Array = []  # [Material, väri päällä, väri pois]
var _spins: Array[Node3D] = []


func _ready() -> void:
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF.x + 0.6, -HALF.y + 2.2, HALF.x * 2.0 - 1.2, HALF.y * 2.0 - 2.6)]
	add_child(walker)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(-2.6, 0, -0.9)  # kyltti (5.9, 5.3) jää hahmon viereen, ei eteen
	walker.rotation.y = B.yaw_to(Vector3(-1, 0, -1))
	walker.visible = true
	walker.activate()


func leave() -> void:
	active = false
	walker.controls_enabled = false


func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


func say(text: String, t := 3.6) -> void:
	_bubble.text = text
	_bubble_t = t
	_curator.play("Idle_Talking", 0.2)


## Seuraava intendentin repliikki kierrossa.
func next_line() -> String:
	_line = (_line + 1) % CURATOR_LINES.size()
	return CURATOR_LINES[_line]


func _process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble.text != "" and (_bubble_t <= 0.0 or (active and walker.position.distance_to(_curator.position) > BUBBLE_FAR)):
		_bubble.text = ""
		_curator.play("Idle", 0.3)
	# Nauhakelat pyörivät ja merkkivalot vilkkuvat.
	for s in _spins:
		s.rotation.z -= delta * 1.4
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = 0.28
		for l in _lamps:
			l[0].albedo_color = l[1] if randf() < 0.45 else l[2]
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	var p := walker.position
	var best := ""
	var bd := 1.8
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
	if best == "pong" and legenda != null and legenda.voitot > 0:
		hint = "[E] Pelaa Pongia (voittoja %d, paras %d-pistettä)" % [legenda.voitot, legenda.parhaat]
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	if best == "ovi":
		exited.emit()
	else:
		acted.emit(best)


# --- Rakennus -------------------------------------------------------------------------------

func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := B.mesh(self, B.boxm(size), pos, col)
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	add_child(body)
	return mi


func _glow(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := B.mesh(parent, B.boxm(size), pos, col)
	mi.material_override = B.unshaded(col)
	return mi


## Nauharulla: kiekko, napa ja kolme pinnaa, jotka pyörivät (_spins). Akseli +Z (rulla katsoo kameraa kohti).
func _reel(parent: Node3D, pos: Vector3) -> void:
	var spin := Node3D.new()
	spin.position = pos
	parent.add_child(spin)
	B.mesh(spin, B.cyl(0.17, 0.17, 0.03, 18), Vector3.ZERO, Color(0.78, 0.8, 0.82), Vector3(90, 0, 0))
	B.mesh(spin, B.cyl(0.115, 0.115, 0.034, 18), Vector3(0, 0, 0.002), Color(0.2, 0.2, 0.22), Vector3(90, 0, 0))
	for k in 3:
		B.mesh(spin, B.boxm(Vector3(0.3, 0.02, 0.012)), Vector3(0, 0, 0.02), Color(0.78, 0.8, 0.82), Vector3(0, 0, k * 60.0))
	B.mesh(spin, B.cyl(0.04, 0.04, 0.045, 10), Vector3(0, 0, 0.012), Color(0.9, 0.55, 0.15), Vector3(90, 0, 0))
	_spins.append(spin)


## D22-kaapin runko: vaalea teräskuori, tumma jalusta ja yläreuna. Palauttaa kaapin etupinnan z:n (+Z).
func _cabinet(c: Vector3, kind: String) -> void:
	var steel := Color(0.72, 0.77, 0.8)
	_solid(Vector3(1.2, 2.1, 0.9), c + Vector3(0, 1.05, 0), steel)
	B.mesh(self, B.boxm(Vector3(1.24, 0.12, 0.94)), c + Vector3(0, 0.06, 0.0), Color(0.22, 0.24, 0.27))
	B.mesh(self, B.boxm(Vector3(1.24, 0.06, 0.94)), c + Vector3(0, 2.11, 0.0), Color(0.3, 0.34, 0.38))
	var fz := 0.46  # etupinnan edessä
	match kind:
		"nauha":  # kaksi nauha-asemaa päällekkäin: tumma levy, kaksi rullaa, tyhjiökolonnit
			for y in [1.62, 0.95]:
				B.mesh(self, B.boxm(Vector3(1.04, 0.56, 0.02)), c + Vector3(0, y, fz), Color(0.14, 0.15, 0.18))
				_reel(self, c + Vector3(-0.27, y, fz + 0.02))
				_reel(self, c + Vector3(0.27, y, fz + 0.02))
				B.mesh(self, B.boxm(Vector3(0.5, 0.03, 0.012)), c + Vector3(0, y - 0.22, fz + 0.01), Color(0.25, 0.15, 0.1))  # nauha rullien välillä
				B.mesh(self, B.boxm(Vector3(0.08, 0.1, 0.02)), c + Vector3(0, y - 0.22, fz + 0.015), Color(0.7, 0.72, 0.74))
			B.mesh(self, B.boxm(Vector3(0.9, 0.12, 0.02)), c + Vector3(0, 0.5, fz), Color(0.45, 0.5, 0.55))
		"paneeli":  # ohjauspaneeli: merkkivalot ruudukossa ja kytkinrivi
			B.mesh(self, B.boxm(Vector3(1.04, 1.05, 0.02)), c + Vector3(0, 1.45, fz), Color(0.12, 0.13, 0.16))
			var rng := RandomNumberGenerator.new()
			rng.seed = 22
			for ix in 6:
				for iy in 4:
					var col: Color = [Color(1.0, 0.25, 0.15), Color(1.0, 0.75, 0.2), Color(0.95, 0.95, 0.85)][rng.randi() % 3]
					var lamp := _glow(self, Vector3(0.08, 0.08, 0.02), c + Vector3(-0.4 + ix * 0.16, 1.82 - iy * 0.14, fz + 0.015), col)
					_lamps.append([lamp.material_override, col, col.darkened(0.8)])
			for ix in 12:
				B.mesh(self, B.boxm(Vector3(0.03, 0.08, 0.03)), c + Vector3(-0.44 + ix * 0.08, 1.15, fz + 0.025), Color(0.85, 0.85, 0.88))
				B.mesh(self, B.boxm(Vector3(0.05, 0.03, 0.02)), c + Vector3(-0.44 + ix * 0.08, 1.1, fz + 0.012), Color(0.3, 0.3, 0.34))
			B.mesh(self, B.boxm(Vector3(0.9, 0.2, 0.02)), c + Vector3(0, 0.55, fz), Color(0.45, 0.5, 0.55))
		"kortti":  # korttilukija: rako, syöttöpino ja uloskaukalo, reikäkorttipino
			B.mesh(self, B.boxm(Vector3(1.04, 0.5, 0.02)), c + Vector3(0, 1.55, fz), Color(0.14, 0.15, 0.18))
			B.mesh(self, B.boxm(Vector3(0.8, 0.07, 0.03)), c + Vector3(0, 1.62, fz + 0.02), Color(0.03, 0.03, 0.04))
			B.mesh(self, B.boxm(Vector3(0.45, 0.14, 0.2)), c + Vector3(-0.25, 1.35, fz + 0.1), Color(0.95, 0.9, 0.72))  # korttipino
			B.mesh(self, B.boxm(Vector3(0.45, 0.14, 0.2)), c + Vector3(0.25, 1.35, fz + 0.1), Color(0.93, 0.88, 0.7))
			for k in 8:
				B.mesh(self, B.boxm(Vector3(0.012, 0.13, 0.002)), c + Vector3(-0.42 + k * 0.045, 1.35, fz + 0.2), Color(0.35, 0.3, 0.2))
			B.mesh(self, B.boxm(Vector3(1.04, 0.5, 0.02)), c + Vector3(0, 0.75, fz), Color(0.3, 0.34, 0.4))
			_glow(self, Vector3(0.1, 0.1, 0.02), c + Vector3(0.38, 0.85, fz + 0.015), Color(0.4, 1.0, 0.4))


## Näyttöpääte (CRT): runko, takaosan putki ja ruutu (unshaded) pienine tekstiriveineen. Katsoo +Z:aan.
func _crt(parent: Node3D, pos: Vector3, size: Vector3, case: Color, screen: Color) -> void:
	B.mesh(parent, B.boxm(size), pos, case)
	B.mesh(parent, B.boxm(Vector3(size.x * 0.7, size.y * 0.7, size.z * 0.6)), pos + Vector3(0, -size.y * 0.04, -size.z * 0.75), case.darkened(0.12))
	var sc := Vector3(size.x * 0.78, size.y * 0.74, 0.015)
	_glow(parent, sc, pos + Vector3(0, size.y * 0.03, size.z / 2.0 + 0.004), screen.darkened(0.55))
	for k in 4:  # tekstirivit
		var w := size.x * (0.5 - 0.08 * (k % 2))
		_glow(parent, Vector3(w, 0.014, 0.004), pos + Vector3(-size.x * 0.34 + w / 2.0 + 0.0, size.y * 0.25 - k * size.y * 0.13, size.z / 2.0 + 0.014), screen)


func _desk(c: Vector3, w: float, d: float) -> void:
	_solid(Vector3(w, 0.06, d), c + Vector3(0, 0.75, 0), Color(0.55, 0.4, 0.25))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.mesh(self, B.boxm(Vector3(0.06, 0.72, 0.06)), c + Vector3(sx * (w / 2.0 - 0.06), 0.36, sz * (d / 2.0 - 0.06)), Color(0.3, 0.3, 0.33))


## Mikrotietokone pöydällä: kind 0 = ruskea näppäimistökotelo + sininen ruutu, 1 = pieni musta kone + televisio, 2 = beige työpöytäkone + monitori.
func _micro(c: Vector3, kind: int) -> void:
	_desk(c, 1.4, 0.9)
	var top := 0.78
	match kind:
		0:
			B.mesh(self, B.boxm(Vector3(0.56, 0.07, 0.3)), c + Vector3(0, top + 0.035, 0.22), Color(0.72, 0.62, 0.48))
			for r in 3:
				for k in 12:
					B.mesh(self, B.boxm(Vector3(0.028, 0.012, 0.028)), c + Vector3(-0.25 + k * 0.045, top + 0.075, 0.12 + r * 0.06), Color(0.35, 0.3, 0.25))
			_crt(self, c + Vector3(0.0, top + 0.28, -0.1), Vector3(0.5, 0.42, 0.4), Color(0.8, 0.76, 0.66), Color(0.55, 0.65, 1.0))
		1:
			B.mesh(self, B.boxm(Vector3(0.34, 0.04, 0.22)), c + Vector3(-0.3, top + 0.02, 0.15), Color(0.1, 0.1, 0.12))
			for k in 4:  # sateenkaariraita etureunassa
				B.mesh(self, B.boxm(Vector3(0.02, 0.003, 0.014)), c + Vector3(-0.2 + k * 0.022, top + 0.041, 0.245), [Color(0.9, 0.2, 0.15), Color(0.95, 0.7, 0.15), Color(0.3, 0.7, 0.3), Color(0.25, 0.45, 0.85)][k])
			for r in 4:
				for k in 10:
					B.mesh(self, B.boxm(Vector3(0.026, 0.012, 0.026)), c + Vector3(-0.43 + k * 0.032, top + 0.045, 0.2 - r * 0.04), Color(0.7, 0.7, 0.72))
			_crt(self, c + Vector3(0.3, top + 0.2, -0.08), Vector3(0.44, 0.36, 0.34), Color(0.18, 0.18, 0.2), Color(0.95, 0.95, 0.8))
		2:
			B.mesh(self, B.boxm(Vector3(0.62, 0.14, 0.42)), c + Vector3(0, top + 0.07, -0.12), Color(0.8, 0.76, 0.66))
			for fx in [-0.14, 0.14]:
				B.mesh(self, B.boxm(Vector3(0.2, 0.025, 0.012)), c + Vector3(fx, top + 0.075, 0.1), Color(0.12, 0.12, 0.14))  # levykeasema
			_glow(self, Vector3(0.025, 0.015, 0.004), c + Vector3(0.27, top + 0.1, 0.1), Color(0.4, 1.0, 0.4))
			_crt(self, c + Vector3(0.0, top + 0.14 + 0.17, -0.12), Vector3(0.44, 0.34, 0.38), Color(0.8, 0.76, 0.66), Color(1.0, 0.75, 0.25))
			B.mesh(self, B.boxm(Vector3(0.5, 0.035, 0.18)), c + Vector3(0, top + 0.018, 0.28), Color(0.78, 0.74, 0.64))


## Pong-pelikone: keltainen kaappi, kallistettu musta ruutu valkoisine mailoineen ja palloineen, ohjainnupit ja yläkyltti. Katsoo +Z:aan.
func _pong_cabinet(c: Vector3) -> void:
	var yellow := Color(0.92, 0.72, 0.16)
	_solid(Vector3(1.0, 1.0, 0.9), c + Vector3(0, 0.5, 0.0), yellow)
	B.mesh(self, B.boxm(Vector3(1.04, 0.1, 0.94)), c + Vector3(0, 0.05, 0.0), Color(0.15, 0.13, 0.12))
	B.mesh(self, B.boxm(Vector3(1.04, 0.07, 0.5)), c + Vector3(0, 1.03, 0.5), yellow.darkened(0.15))  # ohjauspöytä
	for sx in [-0.28, 0.28]:
		B.mesh(self, B.cyl(0.07, 0.07, 0.05, 14), c + Vector3(sx, 1.1, 0.55), Color(0.85, 0.15, 0.12))
		B.mesh(self, B.cyl(0.04, 0.04, 0.02, 10), c + Vector3(sx, 1.14, 0.55), Color(0.95, 0.95, 0.9))
	_solid(Vector3(1.0, 0.8, 0.7), c + Vector3(0, 1.4, -0.1), yellow)
	# Ruutu: ryhmä kallistettu taaksepäin (-12 astetta), kaikki sisällä ruudun tasossa.
	var scr := Node3D.new()
	scr.position = c + Vector3(0, 1.42, 0.255)
	scr.rotation_degrees.x = -12.0
	add_child(scr)
	B.mesh(scr, B.boxm(Vector3(0.84, 0.64, 0.02)), Vector3.ZERO, Color(0.15, 0.13, 0.12))  # kehys
	_glow(scr, Vector3(0.72, 0.54, 0.01), Vector3(0, 0, 0.012), Color(0.03, 0.06, 0.05))
	for k in 7:
		_glow(scr, Vector3(0.012, 0.04, 0.005), Vector3(0, 0.22 - k * 0.07, 0.02), Color(0.85, 1.0, 0.9))
	for sx in [-0.3, 0.3]:
		_glow(scr, Vector3(0.03, 0.15, 0.005), Vector3(sx, -0.04 if sx < 0.0 else 0.07, 0.02), Color(0.85, 1.0, 0.9))
	_glow(scr, Vector3(0.04, 0.04, 0.005), Vector3(0.12, 0.02, 0.02), Color.WHITE)
	_glow(scr, Vector3(0.05, 0.09, 0.005), Vector3(-0.13, 0.22, 0.02), Color(0.85, 1.0, 0.9))
	_glow(scr, Vector3(0.05, 0.09, 0.005), Vector3(0.13, 0.22, 0.02), Color(0.85, 1.0, 0.9))
	var lamp := OmniLight3D.new()
	lamp.position = c + Vector3(0, 1.6, 0.8)
	lamp.light_color = Color(0.6, 1.0, 0.75)
	lamp.light_energy = 0.5
	lamp.omni_range = 2.5
	add_child(lamp)
	var mq := B.sign_plate(self, "PONG", Color(0.15, 0.13, 0.12), Color(1.0, 0.9, 0.3), 0.3, 72, Color(0.92, 0.72, 0.16))
	mq.position = c + Vector3(0, 2.0, 0.28)
	mq.rotation_degrees.x = TILT


func _build() -> void:
	var floor_c := Color(0.6, 0.62, 0.62)
	var wall_c := Color(0.88, 0.87, 0.82)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.15, 0.13, 0.1))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), floor_c)
	for i in 8:  # laattarivit
		B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.004, 0.03)), Vector3(0, 0.001, -5.0 + i * 1.5), floor_c.darkened(0.2))
	for i in 11:
		B.mesh(self, B.boxm(Vector3(0.03, 0.004, HALF.y * 2.0)), Vector3(-8.0 + i * 1.6, 0.001, 0), floor_c.darkened(0.2))
	B.mesh(self, B.boxm(Vector3(3.2, 0.005, 3.4)), Vector3(4.6, 0.003, 0.0), Color(0.25, 0.3, 0.42))  # matto Pong-koneen edessä
	# Seinät: takaseinä ja sivut; kamera +Z:ssa, etuseinää ei ole.
	_solid(Vector3(HALF.x * 2.0, 4.0, 0.3), Vector3(0, 2.0, -HALF.y), wall_c)
	for sx in [-1.0, 1.0]:
		_solid(Vector3(0.3, 4.0, HALF.y * 2.0), Vector3(sx * HALF.x, 2.0, 0), wall_c.darkened(0.04))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.12, 0.3)), Vector3(0, 0.06, -HALF.y + 0.15), wall_c.darkened(0.35))
	# Otsikkokyltit takaseinällä (kallistettu kameraa kohti).
	var plate_bg := Color(0.14, 0.17, 0.22)
	var plate_fg := Color(0.95, 0.95, 0.85)
	var plate_edge := Color(0.55, 0.62, 0.7)
	var t1 := B.sign_plate(self, "DATASAAB D22\n1971, sanotaan", plate_bg, plate_fg, 0.3, 60, plate_edge)
	t1.position = Vector3(-4.7, 3.0, -HALF.y + 0.4)
	t1.rotation_degrees.x = TILT
	var t2 := B.sign_plate(self, "MIKROTIETOKONEHUONE", plate_bg, plate_fg, 0.3, 60, plate_edge)
	t2.position = Vector3(4.0, 3.0, -HALF.y + 0.4)
	t2.rotation_degrees.x = TILT
	# Oven infokyltti (iso fontti, kallistettu kameraa kohti).
	B.sign_pole(self, Vector3(5.9, 0, 5.3), 1.3)
	var info := B.sign_plate(self, "TIETOKONEMUSEO\nSaloinen\nAvoinna heinäkuussa,\nsanotaan", plate_bg, plate_fg, 0.34, 64, plate_edge)
	info.position = Vector3(5.9, 1.5, 5.2)
	info.rotation_degrees.x = -35.0
	# D22: neljä kaappia vierekkäin ja konsolipöytä kirjoituskoneineen.
	_cabinet(Vector3(-6.5, 0, -5.2), "nauha")
	_cabinet(Vector3(-5.3, 0, -5.2), "paneeli")
	_cabinet(Vector3(-4.1, 0, -5.2), "kortti")
	_cabinet(Vector3(-2.9, 0, -5.2), "nauha")
	_desk(Vector3(-4.4, 0, -3.7), 2.2, 0.8)
	B.mesh(self, B.boxm(Vector3(0.5, 0.18, 0.4)), Vector3(-4.8, 0.87, -3.7), Color(0.3, 0.32, 0.36))  # kirjoituskone
	B.mesh(self, B.boxm(Vector3(0.4, 0.3, 0.02)), Vector3(-4.8, 1.1, -3.9), Color(0.96, 0.95, 0.9), Vector3(-10, 0, 0))  # paperi
	_crt(self, Vector3(-3.8, 1.0, -3.8), Vector3(0.44, 0.34, 0.38), Color(0.45, 0.5, 0.55), Color(0.5, 1.0, 0.6))
	# Mikrotietokoneet kolmella pöydällä.
	_micro(Vector3(2.4, 0, -4.8), 0)
	_micro(Vector3(4.0, 0, -4.8), 1)
	_micro(Vector3(5.6, 0, -4.8), 2)
	_pong_cabinet(Vector3(5.4, 0, -0.2))
	# Intendentti (katsoo +Z:aan) ja kasvi ovensuussa.
	_curator = Looks.make(self, {"shirt": Color(0.32, 0.42, 0.34), "pants": Color(0.25, 0.24, 0.28),
		"shoes": Color(0.12, 0.1, 0.08), "hair": "Hair_SimpleParted", "hair_color": Color(0.62, 0.6, 0.58), "height": 1.76})
	_curator.position = Vector3(-0.4, 0, -4.0)
	_curator.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_curator.play("Idle", 0.0)
	_bubble = B.bubble(self, BUBBLE_AT, Color.WHITE, 0.9)
	# Valo.
	for lx in [-3.5, 3.5]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(lx, 3.4, 0.0)
		lamp.light_color = Color(0.95, 0.97, 1.0)
		lamp.light_energy = 0.9
		lamp.omni_range = 10.0
		add_child(lamp)
