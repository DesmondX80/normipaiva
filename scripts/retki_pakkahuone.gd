extends Node3D
## Raahen Pakkahuone, museo (retket.gd "pakkahuone"): taskukohtaus kuten retki_hanhikivi.gd. Kävely player_walker.gd:llä.
## Veistoslegenda (pakkahuone_legenda.gd, main.gd): `legenda` asetetaan ennen enter()iä, ja jalusta, kyltit ja luukku
## seuraavat sen tilaa. Faktat (Suomen vanhin paikallismuseo, 1600-luvun veistokset) "sanotaan"-muodossa, tarkistettava.
## Paikallinen -Z = takaseinä (ikkunat, kyltti), +Z = ovi ja kamera. Veistokset katsovat +Z:aan.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(7.0, 5.0)

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var spot := ""
var legenda: RefCounted
var spots := {
	"ovi": [Vector3(5.6, 0, 4.0), "[E] Ulos: taksille takaisin lähtöpaikkaan"],
	"kuraattori": [Vector3(-2.5, 0, -2.4), "[E] Juttele kuraattorin kanssa"],
	"kirja": [Vector3(0.5, 0, 2.6), "[E] Lue vierailijakirja"],
	"veistos": [Vector3(4.5, 0, -2.4), "[E] Katso veistoksia"],
	"luukku": [Vector3(-5.0, 0, 1.0), "[E] Kellarin luukku"],
}
var _enter_frame := -1
var _curator: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _special: Node3D  # kadonnut veistos
var _plate_on: Node3D
var _plate_off: Node3D
var _lid: Node3D
var _shown := -1  # 1 = esillä, 0 = kadonnut, -1 = ei vielä asetettu
var _lid_open := false
const CURATOR_LINES := ["Pakkahuone on vanha, sanotaan, että Suomen vanhin paikallismuseo. Veistoksia on paljon.",
	"Nämä ovat 1600-luvulta, kuulemma. Ei koskea lasiin.", "Ullakolla on enemmän kuin täällä. Ei sinne pääse."]


func _ready() -> void:
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF.x + 0.5, -HALF.y + 1.2, HALF.x * 2.0 - 1.0, HALF.y * 2.0 - 1.6)]
	add_child(walker)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(-1.2, 0, -0.6)
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


## Näyttö vastaa legendan tilaa: veistos jalustalla vai tyhjä jalusta, luukku auki löydön jälkeen.
func _refresh() -> void:
	var on: int = 1 if legenda == null or legenda.on_display() else 0
	if on != _shown:
		_shown = on
		_special.visible = on == 1
		_plate_on.visible = on == 1
		_plate_off.visible = on == 0
	var open: bool = legenda != null and legenda.found
	if open != _lid_open:
		_lid_open = open
		_lid.rotation_degrees.x = -100.0 if open else 0.0


func _process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble.text != "" and _bubble_t <= 0.0:
		_bubble.text = ""
		_curator.play("Idle", 0.3)
	_refresh()
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
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	if best == "ovi":
		exited.emit()
	else:
		acted.emit(best)


func _on_test_exit() -> void:
	exited.emit()


# --- Rakennus -------------------------------------------------------------------------------

func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	return B.solid(self, size, pos, col)


## Puuveistos jalustalla (katsoo +Z:aan): kaapu, hartiat, pää, kehä ja ristityt kädet. Palauttaa juurisolmun (jalusta mukana).
func _statue(at: Vector3, robe: Color, tall := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var wood := Color(0.45, 0.3, 0.17)
	var ped_h := 0.9
	B.mesh(root, B.boxm(Vector3(0.8, 0.12, 0.8)), Vector3(0, 0.06, 0), wood.darkened(0.25))
	B.mesh(root, B.boxm(Vector3(0.62, ped_h - 0.24, 0.62)), Vector3(0, 0.06 + (ped_h - 0.24) / 2.0, 0), wood)
	B.mesh(root, B.boxm(Vector3(0.74, 0.12, 0.74)), Vector3(0, ped_h - 0.06, 0), wood.lightened(0.1))
	B.mesh(root, B.cyl(0.11 * tall, 0.26 * tall, 0.9 * tall, 10), Vector3(0, ped_h + 0.45 * tall, 0), robe)
	var sh := B.mesh(root, B.sphere(0.17 * tall, 10), Vector3(0, ped_h + 0.88 * tall, 0), robe.lightened(0.08))
	sh.scale = Vector3(1.2, 0.7, 0.8)
	B.mesh(root, B.sphere(0.12 * tall, 10), Vector3(0, ped_h + 1.05 * tall, 0), Color(0.82, 0.66, 0.48))
	B.mesh(root, B.cyl(0.2 * tall, 0.2 * tall, 0.02, 14), Vector3(0, ped_h + 1.06 * tall, -0.1), Color(0.85, 0.7, 0.25), Vector3(90, 0, 0))
	for sx in [-1.0, 1.0]:
		B.mesh(root, B.boxm(Vector3(0.07, 0.3 * tall, 0.07)), Vector3(sx * 0.1, ped_h + 0.7 * tall, 0.12), robe.darkened(0.12), Vector3(-35, 0, sx * -10))
	B.mesh(root, B.sphere(0.06 * tall, 8), Vector3(0, ped_h + 0.58 * tall, 0.2), Color(0.82, 0.66, 0.48))
	return root


func _build() -> void:
	var floor_c := Color(0.55, 0.4, 0.25)
	var wall_c := Color(0.86, 0.8, 0.66)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.15, 0.13, 0.1))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), floor_c)
	for i in 10:
		B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.004, 0.03)), Vector3(0, 0.001, -4.5 + i * 1.0), floor_c.darkened(0.2))
	# Seinät: takaseinä, sivut ja matala etureuna (kamera +Z:ssa), ovi oikeassa etukulmassa.
	_solid(Vector3(HALF.x * 2.0, 3.6, 0.3), Vector3(0, 1.8, -HALF.y), wall_c)
	for sx in [-1.0, 1.0]:
		_solid(Vector3(0.3, 3.6, HALF.y * 2.0), Vector3(sx * HALF.x, 1.8, 0), wall_c.darkened(0.04))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.12, 0.3)), Vector3(0, 0.06, -HALF.y + 0.15), wall_c.darkened(0.35))
	for wx in [-5.5, 5.5]:
		B.mesh(self, B.boxm(Vector3(1.4, 1.5, 0.05)), Vector3(wx, 2.0, -HALF.y + 0.17), Color(0.55, 0.7, 0.8))
		B.mesh(self, B.boxm(Vector3(1.5, 0.08, 0.08)), Vector3(wx, 2.0, -HALF.y + 0.19), Color(0.9, 0.88, 0.8))
		B.mesh(self, B.boxm(Vector3(0.08, 1.6, 0.08)), Vector3(wx, 2.0, -HALF.y + 0.19), Color(0.9, 0.88, 0.8))
	# Kyltti takaseinällä (kuvaus, tarkistettava).
	var title := B.sign_plate(self, "RAAHEN MUSEO · PAKKAHUONE\nSanotaan: Suomen vanhin paikallismuseo", Color(0.2, 0.16, 0.12),
		Color(0.95, 0.88, 0.7), 0.25, 30, Color(0.7, 0.55, 0.25))
	title.position = Vector3(-1.0, 2.9, -HALF.y + 0.2)
	# Veistokset: kaksi vakiota, yksi kadonnut, ristiinnaulittu seinällä.
	_statue(Vector3(-5.5, 0, -3.9), Color(0.25, 0.35, 0.55))
	_statue(Vector3(0.8, 0, -3.9), Color(0.55, 0.2, 0.2), 0.9)
	_special = _statue(Vector3(4.5, 0, -3.9), Color(0.2, 0.45, 0.3), 1.05)
	var cross_c := Color(0.35, 0.22, 0.12)
	B.mesh(self, B.boxm(Vector3(0.14, 1.5, 0.1)), Vector3(2.9, 2.0, -HALF.y + 0.25), cross_c)
	B.mesh(self, B.boxm(Vector3(0.9, 0.14, 0.1)), Vector3(2.9, 2.5, -HALF.y + 0.25), cross_c)
	B.mesh(self, B.boxm(Vector3(0.12, 0.5, 0.08)), Vector3(2.9, 2.2, -HALF.y + 0.33), Color(0.8, 0.65, 0.5))
	B.mesh(self, B.sphere(0.1, 8), Vector3(2.9, 2.55, -HALF.y + 0.33), Color(0.8, 0.65, 0.5))
	# Jalustan kyltit (-Z:n puolelta katsoen levy katsoo ±Z): kyltti kun veistos on, toinen kun se on poissa.
	_plate_on = B.sign_plate(self, "PUUPYHIMYS\n1600-luku\n(kuulemma)", Color(0.95, 0.93, 0.82), Color(0.15, 0.12, 0.1), 0.2, 52, Color(0.45, 0.3, 0.17))
	_plate_on.position = Vector3(4.5, 0.3, -3.15)
	_plate_on.rotation.x = -1.15  # yläreuna taakse: levy katsoo ylös kameraan
	_plate_on.scale = Vector3.ONE * 1.3
	_plate_off = B.sign_plate(self, "POISSA\nKysy kuraat-\ntorilta", Color(0.9, 0.82, 0.8), Color(0.5, 0.1, 0.1), 0.2, 52, Color(0.5, 0.15, 0.15))
	_plate_off.position = Vector3(4.5, 0.3, -3.15)
	_plate_off.rotation.x = -1.15  # yläreuna taakse: levy katsoo ylös kameraan
	_plate_off.scale = Vector3.ONE * 1.3
	# Kuraattorin pöytä ja kuraattori.
	_solid(Vector3(1.9, 0.8, 0.7), Vector3(-2.5, 0.4, -3.4), Color(0.5, 0.36, 0.22))
	B.mesh(self, B.boxm(Vector3(0.5, 0.03, 0.35)), Vector3(-2.5, 0.82, -3.4), Color(0.9, 0.9, 0.85))
	_curator = Looks.make(self, {"shirt": Color(0.5, 0.25, 0.3), "pants": Color(0.25, 0.25, 0.3),
		"shoes": Color(0.15, 0.12, 0.1), "hair": "Hair_Buzzed", "hair_color": Color(0.35, 0.3, 0.28), "height": 1.66})
	_curator.position = Vector3(-2.5, 0, -4.2)
	_curator.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_curator.play("Idle", 0.0)
	_bubble = B.bubble(_curator, Vector3(0, 1.9, 0), Color.WHITE, 0.7)
	# Vierailijakirja jalustalla.
	_solid(Vector3(0.5, 1.0, 0.4), Vector3(0.5, 0.5, 3.4), Color(0.5, 0.36, 0.22))
	B.mesh(self, B.boxm(Vector3(0.4, 0.04, 0.3)), Vector3(0.5, 1.02, 3.4), Color(0.6, 0.15, 0.15), Vector3(-15, 0, 0))
	# Kellarin luukku (-Z-reunasta saranoitu): kansi kääntyy auki löydön jälkeen.
	B.mesh(self, B.boxm(Vector3(1.0, 0.04, 1.0)), Vector3(-5.0, 0.01, 1.0), Color(0.08, 0.06, 0.05))
	_lid = Node3D.new()
	_lid.position = Vector3(-5.0, 0.05, 0.5)
	add_child(_lid)
	B.mesh(_lid, B.boxm(Vector3(1.0, 0.06, 1.0)), Vector3(0, 0, 0.5), Color(0.4, 0.28, 0.16))
	B.mesh(_lid, B.cyl(0.05, 0.05, 0.03, 8), Vector3(0, 0.05, 0.75), Color(0.6, 0.55, 0.3))
	# Valo.
	for lx in [-3.5, 3.5]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(lx, 3.0, 0.0)
		lamp.light_color = Color(1.0, 0.92, 0.75)
		lamp.light_energy = 0.8
		lamp.omni_range = 10.0
		add_child(lamp)
