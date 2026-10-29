extends Node3D
## Vaalan apteekki sisältä (erillinen tasku kuten Siitarin baari): pieni vaalea liiketila, tiski ja farmaseutti tiskin
## takana, lääkehyllyt takaseinällä, käsikauppahylly ja odotustuolit. Kävely player_walker.gd:llä ylhäältä kuvattuna.
## Tiskin valikko (reseptilääkkeet ja käsikauppa) on main.gd:ssä (acted("tiski")), ulko-ovelta exited.
## Paikallinen +X = ulko-ovi, -Z = tiski ja hyllyt takaseinällä, +Z = tien puoli (kamera).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(6.0, 4.5)
const WALL_H := 3.0
const LINES := ["Seuraava, olkaa hyvä.", "Resepti mukana? Ilman reseptiä vain käsikauppaa.", "Panadol vai Burana? Molemmat on tuolla.",
	"Kolmiolääkkeet vain reseptillä, ei neuvotella.", "Muistakaa juoda vettä.", "Apteekki on auki arkisin yhdeksästä viiteen."]

signal exited
signal acted(kind: String)

## Toimintopisteet: id -> [paikka, vihje].
var spots := {
	"ovi": [Vector3(5.2, 0, 2.2), "[E] Ulos ja mopolle"],
	"tiski": [Vector3(-0.5, 0, -0.9), "[E] Apteekin tiski: reseptilääkkeet ja käsikauppa"],
}
var spot := ""
var hint := ""
var active := false
var busy := false
var walker: CharacterBody3D
var _enter_frame := -1
var built := false
var _pharmacist: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _chat_t := 8.0


## Rakennetaan vasta ensimmäisellä käynnillä.
func ensure_built() -> void:
	if built:
		return
	built = true
	_build_room()
	_build_counter()
	_build_shelves()
	_pharmacist = Looks.make(self, {"model": "female", "shirt": Color(0.96, 0.96, 0.94), "pants": Color(0.2, 0.22, 0.26),
		"shoes": Color(0.95, 0.95, 0.95), "hair": "Hair_Buns", "hair_color": Color(0.35, 0.25, 0.18), "height": 1.66})
	_pharmacist.position = Vector3(-0.5, 0, -3.3)
	_pharmacist.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_pharmacist.play("Idle", 0.0)
	_bubble = B.bubble(_pharmacist, Vector3(0, 1.85, 0), Color.WHITE, 0.7)
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF, HALF * 2.0)]
	add_child(walker)


func enter() -> void:
	ensure_built()
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(-1.2, 0, 0)
	walker.rotation.y = B.yaw_to(Vector3(1, 0, 0))
	walker.activate()
	say("Hyvää päivää! Apteekki palvelee.")


func leave() -> void:
	active = false
	if built:
		walker.controls_enabled = false


func say(text: String, t := 3.4) -> void:
	if _bubble == null:
		return
	_bubble.text = text
	_bubble_t = t
	_pharmacist.play("Idle_Talking", 0.3)


## Valikosta palatessa sama E-painallus ei saa avata uutta toimintoa.
func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


func _process(delta: float) -> void:
	if not built:
		return
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.text = ""
			_pharmacist.play("Idle", 0.3)
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(10.0, 18.0)
		say(LINES.pick_random())
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
	if best == "ovi":
		exited.emit()
	else:
		acted.emit(best)


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
	var cream := Color(0.93, 0.92, 0.86)
	var green := Color(0.05, 0.5, 0.28)
	B.mesh(self, B.boxm(Vector3(80, 0.2, 80)), Vector3(0, -0.2, 0), Color(0.08, 0.08, 0.08))
	# Lattia: vaalea laatta ruutuina.
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), Color(0.82, 0.84, 0.82))
	for ix in 12:
		for iz in 9:
			if (ix + iz) % 2 == 0:
				B.mesh(self, B.boxm(Vector3(1.0, 0.01, 1.0)), Vector3(-HALF.x + 0.5 + ix, 0.005, -HALF.y + 0.5 + iz), Color(0.74, 0.77, 0.74))
	# Seinät: taka ja päädyt täyskorkeat, etuseinä matala (kamera); oviaukko oikeassa päädyssä.
	_wall(Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, -HALF.y), WALL_H, cream)
	_wall(Vector2(-HALF.x, -HALF.y), Vector2(-HALF.x, HALF.y), WALL_H, cream)
	_wall(Vector2(HALF.x, -HALF.y), Vector2(HALF.x, 1.4), WALL_H, cream)
	_wall(Vector2(HALF.x, 3.0), Vector2(HALF.x, HALF.y), WALL_H, cream)
	_wall(Vector2(-HALF.x, HALF.y), Vector2(HALF.x, HALF.y), 0.6, cream)
	# Vihreä raita seinissä, lasiovi ja ULOS-merkki.
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.25, 0.04)), Vector3(0, 1.3, -HALF.y + 0.11), green)
	B.mesh(self, B.boxm(Vector3(0.04, 0.25, HALF.y * 2.0)), Vector3(-HALF.x + 0.11, 1.3, 0), green)
	B.mesh(self, B.boxm(Vector3(0.08, 2.3, 1.6)), Vector3(HALF.x - 0.02, 1.15, 2.2), Color(0.85, 0.85, 0.82))
	B.mesh(self, B.boxm(Vector3(0.1, 2.1, 1.4)), Vector3(HALF.x - 0.03, 1.1, 2.2), Color(0.5, 0.68, 0.74))
	B.label(self, "ULOS", Vector3(HALF.x - 0.1, 2.5, 2.2), 40, Color(0.3, 1.0, 0.4)).rotation.y = -PI / 2.0
	for wx in [-3.5, -0.5, 2.5]:
		B.mesh(self, B.boxm(Vector3(2.4, 0.1, 0.12)), Vector3(wx, 0.62, HALF.y), Color(0.9, 0.9, 0.86))
	# Apteekki-kyltti ja vihreä risti takaseinällä tiskin yläpuolella.
	var sign_p := B.sign_plate(self, "APTEEKKI", green, Color.WHITE, 0.6, 80, Color(0.9, 0.95, 0.9), "Helvetica Neue")
	sign_p.position = Vector3(-0.5, 2.5, -HALF.y + 0.14)
	for arm in [Vector3(0.7, 0.22, 0.05), Vector3(0.22, 0.7, 0.05)]:
		B.mesh(self, B.boxm(arm), Vector3(-3.4, 2.5, -HALF.y + 0.14), green).material_override = B.unshaded(Color(0.1, 0.8, 0.4))
	var notice := B.sign_plate(self, "Kolmiolääkkeet\nvain reseptillä", Color(0.97, 0.97, 0.95), Color(0.75, 0.08, 0.08), 0.22, 34,
		Color(0.75, 0.08, 0.08), "Helvetica Neue")
	notice.position = Vector3(2.8, 1.9, -HALF.y + 0.14)
	for l in [Vector3(-2.0, 2.7, -1.0), Vector3(2.5, 2.7, 1.0)]:
		var light := OmniLight3D.new()
		light.position = l
		light.omni_range = 9.0
		light.light_energy = 0.8
		light.light_color = Color(1.0, 0.98, 0.92)
		add_child(light)


## Tiski: valkoinen tiski, kassa ja punainen jonotusnumeroautomaatti.
func _build_counter() -> void:
	_solid(Vector3(6.4, 1.05, 0.8), Vector3(-0.5, 0.525, -2.2), Color(0.95, 0.95, 0.93))
	B.mesh(self, B.boxm(Vector3(6.6, 0.06, 1.0)), Vector3(-0.5, 1.08, -2.2), Color(0.2, 0.55, 0.38))
	B.mesh(self, B.boxm(Vector3(0.5, 0.3, 0.4)), Vector3(1.8, 1.26, -2.3), Color(0.15, 0.15, 0.17))  # kassa
	B.mesh(self, B.boxm(Vector3(0.4, 0.2, 0.02)), Vector3(1.8, 1.32, -2.1), Color(0.3, 0.7, 0.45))
	_solid(Vector3(0.3, 1.3, 0.3), Vector3(4.2, 0.65, -0.6), Color(0.75, 0.1, 0.1))  # jonotusnumeroautomaatti
	B.label(self, "NUMERO", Vector3(4.2, 1.45, -0.42), 22, Color.WHITE)
	# Odotustuolit seinän vieressä.
	for cx in [-4.6, -3.8, -3.0]:
		_solid(Vector3(0.6, 0.45, 0.6), Vector3(cx, 0.225, 2.6), Color(0.2, 0.45, 0.35))
		B.mesh(self, B.boxm(Vector3(0.6, 0.5, 0.1)), Vector3(cx, 0.7, 2.9), Color(0.2, 0.45, 0.35))


## Lääkehyllyt takaseinällä (laatikkorivit) ja käsikauppahylly oikealla seinällä.
func _build_shelves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cols := [Color(0.95, 0.95, 0.95), Color(0.2, 0.55, 0.38), Color(0.85, 0.2, 0.18), Color(0.2, 0.4, 0.75), Color(0.95, 0.8, 0.2)]
	for x in [-4.4, -0.5, 3.0]:
		_solid(Vector3(2.8, 2.2, 0.4), Vector3(x, 1.1, -HALF.y + 0.3), Color(0.78, 0.78, 0.74))
		for row in 5:
			for k in 6:
				B.mesh(self, B.boxm(Vector3(0.36, 0.3, 0.06)), Vector3(x - 1.1 + k * 0.44, 0.35 + row * 0.42, -HALF.y + 0.52), cols[rng.randi() % cols.size()])
	for z in [-0.4, 0.8]:
		_solid(Vector3(0.5, 1.7, 1.0), Vector3(HALF.x - 0.5, 0.85, z), Color(0.82, 0.82, 0.8))
		for row in 4:
			B.mesh(self, B.boxm(Vector3(0.1, 0.25, 0.7)), Vector3(HALF.x - 0.8, 0.35 + row * 0.38, z), cols[(row + int(z * 3.0)) % cols.size()])
