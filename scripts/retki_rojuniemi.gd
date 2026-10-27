extends Node3D
## Rautaruukin Rojuniemi, peruskivi (retket.gd "rojuniemi"): taskukohtaus kuten retki_hanhikivi.gd. Kävely player_walker.gd:llä.
## Legenda (peruskivi_legenda.gd, main.gd): `legenda` asetetaan ennen enter()iä, ja laatta seuraa sen tilaa.
## Faktat (peruskivi 1962, Kekkonen, ensimmäinen lähetys 1964) "sanotaan"-muodossa, tarkistettava. Kätkö on keksitty.
## Paikallinen -Z = tehtaan aita ja hallit (takaseinä), +Z = tie ja parkki (kamera). Kivi on x 5.5, vartijakoppi x -7.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")
const Vehicles := preload("res://scripts/vehicles.gd")

const HALF := Vector2(15.0, 10.0)
const FENCE_Z := -5.2  # tehtaan aita: kävelyraja

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var spot := ""
var legenda: RefCounted
var spots := {
	"ovi": [Vector3(-12.0, 0, 6.4), "[E] Taksille: takaisin lähtöpaikkaan"],
	"vartija": [Vector3(-7.0, 0, -2.0), "[E] Juttele vartijan kanssa"],
	"kyltti": [Vector3(-1.5, 0, -2.4), "[E] Lue Rojuniemen kyltti"],
	"kivi": [Vector3(3.4, 0, -2.2), "[E] Tutki peruskiveä"],
	"laatta": [Vector3(6.8, 0, -0.4), "[E] Tutki kiven edessä olevaa laattaa"],
}
var _enter_frame := -1
var _guard: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _slab: Node3D
var _hole: Node3D
var _opened := -1  # 1 = laatta sivussa, 0 = paikallaan, -1 = ei vielä asetettu
var _smoke: Array = []  # [Node3D, vaihe]
var _t := 0.0
const GUARD_LINES := ["Rautaruukki on iso työnantaja, kuulemma. Aita on aidattu syystä.", "Peruskivi on tuossa. Kekkonen sen paljasti, sanotaan.",
	"Ei saa mennä aidan taakse. Kivelle saa."]


func _ready() -> void:
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF.x, FENCE_Z, HALF.x * 2.0, HALF.y - FENCE_Z)]
	add_child(walker)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(1.6, 0, -1.0)
	walker.rotation.y = B.yaw_to(Vector3(1, 0, -1))
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
	_guard.play("Idle_Talking", 0.2)


## Laatta kiven edessä: paikallaan ennen löytöä, sivulle työnnetty ja kolo näkyvissä löydön jälkeen.
func _refresh() -> void:
	var open: int = 1 if legenda != null and legenda.found else 0
	if open == _opened:
		return
	_opened = open
	_hole.visible = open == 1
	_slab.position = Vector3(6.5 + (0.95 if open == 1 else 0.0), 0.04, -1.4 + (0.2 if open == 1 else 0.0))
	_slab.rotation_degrees.y = 25.0 if open == 1 else 0.0


func _process(delta: float) -> void:
	_t += delta
	_bubble_t -= delta
	if _bubble.text != "" and _bubble_t <= 0.0:
		_bubble.text = ""
		_guard.play("Idle", 0.3)
	for s in _smoke:
		var ph: float = fposmod(_t * 0.25 + s[1], 1.0)
		s[0].position = Vector3(-6.0 + ph * 3.0, 10.0 + ph * 5.0, -11.0)
		s[0].scale = Vector3.ONE * (0.6 + ph * 1.6)
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
	var mi := B.mesh(self, B.boxm(size), pos, col)
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	add_child(body)
	return mi


func _birch(at: Vector3, s := 1.0) -> void:
	B.mesh(self, B.cyl(0.07 * s, 0.1 * s, 3.0 * s, 8), at + Vector3(0, 1.5 * s, 0), Color(0.92, 0.9, 0.86))
	B.mesh(self, B.sphere(1.0 * s, 8), at + Vector3(0, 3.5 * s, 0), Color(0.35, 0.6, 0.22)).scale = Vector3(1.0, 1.2, 1.0)


## Tehdashalli: laatikko, pulpettikatto ja ikkunarivi.
func _hall(x: float, w: float, h: float, col: Color) -> void:
	B.mesh(self, B.boxm(Vector3(w, h, 6.0)), Vector3(x, h / 2.0, -12.0), col)
	for i in int(w / 2.0):
		B.mesh(self, B.boxm(Vector3(1.2, 0.7, 0.05)), Vector3(x - w / 2.0 + 1.5 + i * 2.0, h * 0.7, -8.97), Color(0.7, 0.8, 0.85))
	B.mesh(self, B.boxm(Vector3(w + 0.3, 0.3, 6.3)), Vector3(x, h + 0.15, -12.0), col.darkened(0.3))


func _build() -> void:
	var grass := Color(0.38, 0.55, 0.25)
	var path_c := Color(0.78, 0.74, 0.62)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.2, 0.34, 0.18))
	var park_d := HALF.y - FENCE_Z
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, park_d)), Vector3(0, -0.05, (HALF.y + FENCE_Z) / 2.0), grass)
	B.mesh(self, B.boxm(Vector3(1.4, 0.02, 9.0)), Vector3(-11.0, 0.005, 2.0), path_c)
	B.mesh(self, B.boxm(Vector3(20.0, 0.02, 1.4)), Vector3(0.0, 0.005, -1.4), path_c)
	B.mesh(self, B.boxm(Vector3(3.0, 0.02, 3.0)), Vector3(6.5, 0.005, -1.4), path_c)
	# Tehdas aidan takana: hallit, korkea piippu (punavalkoinen) ja savu.
	_hall(-9.0, 9.0, 4.5, Color(0.42, 0.48, 0.56))
	_hall(1.0, 8.0, 6.0, Color(0.5, 0.42, 0.38))
	_hall(10.0, 7.0, 4.0, Color(0.4, 0.5, 0.45))
	for k in 6:
		B.mesh(self, B.cyl(0.9 - k * 0.02, 1.0 - k * 0.02, 1.6, 10), Vector3(-6.0, 0.8 + k * 1.6, -11.0), Color(0.85, 0.2, 0.15) if k % 2 == 0 else Color(0.95, 0.95, 0.95))
	for i in 5:
		var puff := B.mesh(self, B.sphere(1.0, 8), Vector3(-6.0, 10.0, -11.0), Color(0.85, 0.85, 0.88))
		_smoke.append([puff, i * 0.2])
	# Aita (verkko ja tolpat) ja portti.
	for i in 31:
		B.mesh(self, B.cyl(0.04, 0.05, 2.0, 6), Vector3(-15.0 + i, 1.0, FENCE_Z), Color(0.4, 0.42, 0.45))
	var mesh_c := Color(0.55, 0.57, 0.6)
	B.mesh(self, B.boxm(Vector3(30.0, 1.5, 0.03)), Vector3(0, 1.0, FENCE_Z), mesh_c)
	B.mesh(self, B.boxm(Vector3(30.0, 0.06, 0.08)), Vector3(0, 2.0, FENCE_Z), Color(0.4, 0.42, 0.45))
	var gate_sign := B.sign_plate(self, "RAUTARUUKKI · ROJUNIEMI\nAsiaton liikenne kielletty", Color(0.15, 0.25, 0.45), Color(0.95, 0.95, 0.95), 0.28, 30, Color(0.85, 0.85, 0.9))
	gate_sign.position = Vector3(-10.0, 2.7, FENCE_Z + 0.1)
	# Vartijakoppi: laatikko, ikkuna ja katto.
	_solid(Vector3(2.0, 2.2, 1.8), Vector3(-9.0, 1.1, -3.9), Color(0.85, 0.82, 0.72))
	B.mesh(self, B.boxm(Vector3(1.2, 0.7, 0.05)), Vector3(-9.0, 1.4, -2.98), Color(0.5, 0.7, 0.8))
	B.mesh(self, B.boxm(Vector3(2.3, 0.15, 2.1)), Vector3(-9.0, 2.28, -3.9), Color(0.3, 0.3, 0.33))
	_guard = Looks.make(self, {"shirt": Color(0.9, 0.8, 0.2), "pants": Color(0.2, 0.22, 0.3),
		"shoes": Color(0.15, 0.12, 0.1), "hair": "Hair_Buzzed", "hair_color": Color(0.4, 0.35, 0.3), "height": 1.78})
	_guard.position = Vector3(-7.0, 0, -3.0)
	_guard.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_guard.play("Idle", 0.0)
	_bubble = B.bubble(_guard, Vector3(0, 1.95, 0), Color.WHITE, 0.7)
	# Opaskyltti (vihje 2): vuosiluvut ja kätkö huhuna.
	B.sign_pole(self, Vector3(-1.5, 0, -3.1), 1.9)
	var info := B.sign_plate(self, "ROJUNIEMI · RAUTARUUKIN PERUSKIVI\nPeruskivi paljastettiin sanotaan 25.8.1962.\nEnsimmäinen lähetys sanotaan 5.9.1964.\nKuulemma kiven eteen jäi kapseli: laatta.",
		Color(0.95, 0.93, 0.82), Color(0.1, 0.2, 0.3), 0.3, 28, Color(0.15, 0.25, 0.45))
	info.position = Vector3(-1.5, 1.55, -3.05)
	# Peruskivi: kiillotettu graniittilohkare, kuvun yläreuna ja laatta (kyltti) etupinnassa.
	var gran := Color(0.36, 0.36, 0.4)
	_solid(Vector3(2.4, 1.3, 1.1), Vector3(5.5, 0.65, -3.8), gran)
	B.mesh(self, B.boxm(Vector3(2.5, 0.1, 1.2)), Vector3(5.5, 1.35, -3.8), gran.lightened(0.15))
	B.mesh(self, B.boxm(Vector3(2.8, 0.2, 1.5)), Vector3(5.5, 0.1, -3.8), gran.darkened(0.2))
	var stone_plate := B.sign_plate(self, "PERUSKIVI\nSanotaan: Kekkonen 1962", Color(0.7, 0.55, 0.25), Color(0.1, 0.08, 0.05), 0.22, 28, Color(0.45, 0.35, 0.15))
	stone_plate.position = Vector3(5.5, 0.8, -3.22)
	# Laatta kiven edessä (kätkön peite) ja kolo sen alla (näkyy vasta löydön jälkeen).
	_hole = Node3D.new()
	_hole.position = Vector3(6.5, 0.0, -1.4)
	add_child(_hole)
	B.mesh(_hole, B.boxm(Vector3(0.9, 0.04, 0.9)), Vector3(0, 0.01, 0), Color(0.07, 0.05, 0.04))
	B.mesh(_hole, B.cyl(0.13, 0.13, 0.42, 10), Vector3(0, 0.16, 0), Color(0.72, 0.45, 0.25), Vector3(90, 0, 20))
	B.mesh(_hole, B.cyl(0.14, 0.14, 0.06, 10), Vector3(0.07, 0.16, 0.19), Color(0.5, 0.3, 0.15), Vector3(90, 0, 20))
	_slab = Node3D.new()
	add_child(_slab)
	B.mesh(_slab, B.boxm(Vector3(1.0, 0.06, 1.0)), Vector3.ZERO, Color(0.55, 0.55, 0.58))
	B.mesh(_slab, B.boxm(Vector3(0.96, 0.01, 0.04)), Vector3(0, 0.035, 0.2), Color(0.4, 0.4, 0.43))
	# Tie, taksi, puita.
	B.mesh(self, B.boxm(Vector3(30.0, 0.02, 3.0)), Vector3(0, 0.003, 8.8), Color(0.3, 0.3, 0.32))
	B.mesh(self, B.boxm(Vector3(30.0, 0.025, 0.12)), Vector3(0, 0.01, 8.8), Color(0.9, 0.8, 0.3))
	var taxi := Node3D.new()
	taxi.position = Vector3(-12.0, 0, 8.3)
	taxi.rotation.y = PI / 2.0
	add_child(taxi)
	Vehicles.taxi(taxi)
	for p in [Vector3(-14.0, 0, -1.0), Vector3(-4.0, 0, 4.5), Vector3(2.0, 0, 5.0), Vector3(10.0, 0, 2.5), Vector3(13.5, 0, -3.0)]:
		_birch(p, 0.9 + fposmod(p.x, 0.3))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 4.0, 0.0)
	lamp.light_color = Color(1.0, 0.95, 0.8)
	lamp.light_energy = 0.6
	lamp.omni_range = 14.0
	add_child(lamp)
