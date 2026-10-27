extends Node3D
## Manamansalon muistokirkko ja hautausmaasaari (retket.gd "manamansalo"): taskukohtaus kuten retki_rojuniemi.gd. Kävely player_walker.gd:llä.
## Legenda (manamansalo_legenda.gd, main.gd): `legenda` asetetaan ennen enter()iä, ja kivijalan kynttilä seuraa sen tilaa.
## Faktat (hautausmaasaari, Kainuun ensimmäinen kirkko 1559, nimen "kuolemansaari" tulkinta) "sanotaan"-muodossa, tarkistettava.
## Paikallinen -Z = Oulujärvi (takaseinä), +Z = tie ja parkki (kamera). Kirkko on x -3, hautausmaa x 3..13, laituri x -10.
## Alassalmen lossi (P15): lossimies myy lipun, lautta ajaa salmeen ja takaisin (`ride()`, signaali `ride_done`). Vuorot ja lippu hoitaa main.gd.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")
const Vehicles := preload("res://scripts/vehicles.gd")

const SIGN_TILT := 38.0  # asteita: levyn normaali kääntyy +Z:sta ylös kameraa kohti
const HALF := Vector2(15.0, 10.0)
const SHORE_Z := -6.4  # rantaviiva: kävelyraja

signal exited
signal acted(kind: String)
signal ride_done

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var spot := ""
var legenda: RefCounted
var spots := {
	"ovi": [Vector3(-12.0, 0, 6.4), "[E] Taksille: takaisin lähtöpaikkaan"],
	"opas": [Vector3(-3.0, 0, 2.1), "[E] Juttele oppaan kanssa"],
	"infotaulu": [Vector3(3.4, 0, 2.3), "[E] Lue hautausmaan infotaulu"],
	"jaanteet": [Vector3(9.0, 0, 0.6), "[E] Tutki kirkon kivijalkaa"],
	"laituri": [Vector3(-10.0, 0, -5.0), "[E] Lossille (juttele lossimiehen kanssa)"],
}
var _enter_frame := -1
var _guide: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
const BUBBLE_AT := Vector3(-6.4, 0.4, 2.6)  # kuplan alareuna: oppaan (x -3) vasemmalla puolella, nurmen yllä (HUD-viestit ovat ruudun oikealla)
const BUBBLE_FAR := 4.5  # kupla sulkeutuu, kun pelaaja kävelee tätä kauemmas oppaasta
var _candle: Node3D
var _lautta: Node3D
var _lossimies: Node3D
var _bubble2: Label3D  # lossimiehen kupla
var _bubble2_t := 0.0
const BUBBLE2_AT := Vector3(-7.6, 0.4, -3.6)
const LAUTTA_HOME := Vector3(-10.0, 0.0, -15.0)  # lautan keskipiste laiturin päässä (laiturin kansi päättyy z -12.5)
const LAUTTA_OUT := 11.0  # matka salmeen (-Z)
const DECK_TOP := 0.41  # laiturin ja lautan kannen yläpinta
var _t := 0.0


func _ready() -> void:
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF.x, SHORE_Z, HALF.x * 2.0, HALF.y - SHORE_Z)]
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
	_guide.play("Idle_Talking", 0.2)


## Lossimiehen puhekupla (maailmassa, laiturin vieressä).
func say_lossi(text: String, t := 3.6) -> void:
	_bubble2.text = text
	_bubble2_t = t
	_lossimies.play("Idle_Talking", 0.2)


## Lossimatka: hahmo kävelee lautalle, lautta ajaa salmeen ja takaisin, hahmo palaa laiturille. Fysiikka pois ajaksi (kansi on laituria korkeammalla).
func ride() -> void:
	busy = true
	hint = ""
	walker.controls_enabled = false
	walker.set_physics_process(false)
	var bounds_saved: Array = walker.bounds
	walker.bounds = []
	var seat := Vector3(0, DECK_TOP + 0.04, 0.9)  # paikka lautalla lautan keskipisteestä
	walker.rotation.y = B.yaw_to(Vector3(0, 0, -1))
	await _walk_to(LAUTTA_HOME + seat, 2.2)
	var t0 := Time.get_ticks_msec()
	var total := 9.0
	while true:
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		if t >= total:
			break
		var k := 0.5 * (1.0 - cos(TAU * t / total))  # 0 -> 1 -> 0
		_lautta.position = LAUTTA_HOME + Vector3(0, sin(t * 2.0) * 0.015, -LAUTTA_OUT * k)
		_lautta.rotation.z = sin(t * 1.3) * 0.01
		walker.position = _lautta.position + seat
		walker._update_camera()
		await get_tree().process_frame
	_lautta.position = LAUTTA_HOME
	_lautta.rotation.z = 0.0
	walker.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	await _walk_to(Vector3(spots.laituri[0].x, 0.0, spots.laituri[0].z), 2.2)
	walker.bounds = bounds_saved
	walker.set_physics_process(true)
	walker.controls_enabled = true
	busy = false
	ride_done.emit()


## Hahmo liukuu paikkaan (fysiikka pois: kamera päivitetään itse).
func _walk_to(to: Vector3, secs: float) -> void:
	var from := walker.position
	var t0 := Time.get_ticks_msec()
	while true:
		var k := minf((Time.get_ticks_msec() - t0) / 1000.0 / secs, 1.0)
		walker.position = from.lerp(to, k)
		walker._update_camera()
		if k >= 1.0:
			break
		await get_tree().process_frame


func _process(delta: float) -> void:
	_t += delta
	_bubble_t -= delta
	_bubble2_t -= delta
	if _bubble2.text != "" and _bubble2_t <= 0.0:
		_bubble2.text = ""
		_lossimies.play("Idle", 0.3)
	if _bubble.text != "" and (_bubble_t <= 0.0 or (active and walker.position.distance_to(_guide.position) > BUBBLE_FAR)):
		_bubble.text = ""
		_guide.play("Idle", 0.3)
	_candle.visible = legenda != null and legenda.found
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


func _spruce(at: Vector3, s := 1.0) -> void:
	B.mesh(self, B.cyl(0.08 * s, 0.12 * s, 1.0 * s, 8), at + Vector3(0, 0.5 * s, 0), Color(0.35, 0.24, 0.15))
	for k in 3:
		B.mesh(self, B.cyl(0.02, (1.3 - k * 0.3) * s, 1.3 * s, 10), at + Vector3(0, (1.2 + k * 0.8) * s, 0), Color(0.12, 0.3, 0.17))


func _birch(at: Vector3, s := 1.0) -> void:
	B.mesh(self, B.cyl(0.07 * s, 0.1 * s, 3.0 * s, 8), at + Vector3(0, 1.5 * s, 0), Color(0.92, 0.9, 0.86))
	B.mesh(self, B.sphere(1.0 * s, 8), at + Vector3(0, 3.5 * s, 0), Color(0.35, 0.6, 0.22)).scale = Vector3(1.0, 1.2, 1.0)


## Ristikumpu: pystypuu ja poikkipuu, kallistus yhdestä kulmasta (rot_z asteina).
func _cross(at: Vector3, yaw: float, rot_z: float, col: Color) -> void:
	var c := Node3D.new()
	c.position = at
	c.rotation_degrees = Vector3(0, yaw, rot_z)
	add_child(c)
	B.mesh(c, B.boxm(Vector3(0.1, 1.0, 0.07)), Vector3(0, 0.5, 0), col)
	B.mesh(c, B.boxm(Vector3(0.5, 0.1, 0.07)), Vector3(0, 0.75, 0), col)


## Harjakatto: kaksi lappeen levyä ja päätykolmiot (pysty prisma harjan suunnassa Z). Lappeen kulma yhdestä luvusta.
func _roof(c: Vector3, half_w: float, depth: float, wall_col: Color, roof_col: Color) -> void:
	var a := deg_to_rad(33.0)
	var rise := half_w * tan(a)
	var rl := half_w / cos(a) + 0.18
	for s in [-1.0, 1.0]:
		B.mesh(self, B.boxm(Vector3(rl, 0.12, depth + 0.5)), c + Vector3(s * half_w * 0.5, rise * 0.5 + 0.06, 0), roof_col, Vector3(0, 0, -s * 33.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [-depth * 0.5, depth * 0.5]:
		for v in [Vector3(-half_w, 0, z), Vector3(half_w, 0, z), Vector3(0, rise, z)]:
			st.add_vertex(c + v)
	st.generate_normals()
	var m := B.mat(wall_col)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)


## Kyltti tolpalla: levy kallistettu kameraa kohti (kamera on +Z:n puolella ylhäällä), tolppa levyn alla.
func _post_sign(plate: Node3D, foot: Vector3, h: float) -> void:
	B.sign_pole(self, foot, h)
	plate.position = foot + Vector3(0, h + 0.2, 0.05)
	plate.rotation_degrees.x = -SIGN_TILT


func _build() -> void:
	var grass := Color(0.38, 0.55, 0.25)
	var path_c := Color(0.78, 0.74, 0.62)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.2, 0.34, 0.18))
	var park_d := HALF.y - SHORE_Z
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, park_d)), Vector3(0, -0.05, (HALF.y + SHORE_Z) / 2.0), grass)
	# Oulujärvi rannan takana ja kivinen rantaviiva.
	B.mesh(self, B.boxm(Vector3(70.0, 0.1, 30.0)), Vector3(0, -0.12, SHORE_Z - 15.0), Color(0.2, 0.42, 0.55))
	for i in 12:
		B.mesh(self, B.sphere(0.35, 6), Vector3(-14.0 + i * 2.6, 0.0, SHORE_Z + 0.1 + fposmod(i * 0.37, 0.4)), Color(0.5, 0.5, 0.52)).scale = Vector3(1.0, 0.5, 0.8)
	# Polut: tieltä kirkon ovelle ja hautausmaan portille.
	B.mesh(self, B.boxm(Vector3(1.4, 0.02, 9.0)), Vector3(-11.0, 0.005, 2.0), path_c)
	B.mesh(self, B.boxm(Vector3(12.0, 0.02, 1.4)), Vector3(-5.0, 0.005, 2.4), path_c)
	B.mesh(self, B.boxm(Vector3(14.0, 0.02, 1.4)), Vector3(3.0, 0.005, 2.4), path_c)
	B.mesh(self, B.boxm(Vector3(1.4, 0.02, 3.0)), Vector3(9.0, 0.005, 0.8), path_c)
	# Muistokirkko: punamullattu hirsirunko, valkoiset nurkat ja ikkunat, tumma harjakatto, risti harjalla, ovi päädyssä (+Z).
	var church := Vector3(-3.0, 0, -2.5)
	var wall := Color(0.62, 0.2, 0.15)
	_solid(Vector3(4.6, 3.0, 6.2), church + Vector3(0, 1.5, 0), wall)
	B.mesh(self, B.boxm(Vector3(4.8, 0.3, 6.4)), church + Vector3(0, 0.15, 0), Color(0.5, 0.5, 0.52))
	for sx in [-2.3, 2.3]:
		for sz in [-3.1, 3.1]:
			B.mesh(self, B.boxm(Vector3(0.18, 3.0, 0.18)), church + Vector3(sx, 1.5, sz), Color(0.95, 0.94, 0.9))
	_roof(church + Vector3(0, 3.0, 0), 2.45, 6.2, wall, Color(0.15, 0.15, 0.17))
	B.mesh(self, B.boxm(Vector3(1.1, 2.0, 0.08)), church + Vector3(0, 1.0, 3.12), Color(0.95, 0.94, 0.9))
	B.mesh(self, B.boxm(Vector3(0.9, 1.8, 0.1)), church + Vector3(0, 0.95, 3.15), Color(0.3, 0.2, 0.12))
	B.mesh(self, B.sphere(0.05, 6), church + Vector3(0.3, 0.95, 3.22), Color(0.85, 0.7, 0.2))
	for sz in [-1.8, 0.2, 2.0]:
		for sx in [-2.33, 2.33]:
			B.mesh(self, B.boxm(Vector3(0.05, 1.0, 0.72)), church + Vector3(sx * 1.003, 1.7, sz), Color(0.95, 0.94, 0.9))
			B.mesh(self, B.boxm(Vector3(0.02, 0.86, 0.58)), church + Vector3(sx * 1.0155, 1.7, sz), Color(0.55, 0.72, 0.85))
	B.mesh(self, B.boxm(Vector3(0.12, 1.3, 0.12)), church + Vector3(0, 5.2, 2.9), Color(0.95, 0.94, 0.9))
	B.mesh(self, B.boxm(Vector3(0.7, 0.12, 0.12)), church + Vector3(0, 5.5, 2.9), Color(0.95, 0.94, 0.9))
	# Opas kirkon oven edessä.
	_guide = Looks.make(self, {"shirt": Color(0.2, 0.42, 0.3), "pants": Color(0.25, 0.25, 0.3),
		"shoes": Color(0.15, 0.12, 0.1), "hair": "Hair_Buzzed", "hair_color": Color(0.55, 0.5, 0.45), "height": 1.7})
	_guide.position = Vector3(-3.0, 0, 1.4)
	_guide.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_guide.play("Idle", 0.0)
	# Puhekupla on oppaan vieressä nurmella (ei oppaan pään päällä), jottei se peitä kirkkoa; sijainti maailmassa.
	_bubble = B.bubble(self, BUBBLE_AT, Color.WHITE, 0.8)
	# Hautausmaa: matala puuaita (kolme sivua, länsi auki), ristit ja kivet.
	var fence_c := Color(0.92, 0.9, 0.85)
	for edge in [[Vector3(8.0, 0.45, -5.4), Vector3(11.0, 0.08, 0.1)], [Vector3(13.5, 0.45, -1.6), Vector3(0.1, 0.08, 7.6)],
			[Vector3(8.0, 0.45, 2.0), Vector3(11.0, 0.08, 0.1)]]:
		B.mesh(self, B.boxm(edge[1] + Vector3(0, 0.02, 0)), edge[0], fence_c)
		B.mesh(self, B.boxm(edge[1] + Vector3(0, 0.02, 0)), edge[0] + Vector3(0, 0.3, 0), fence_c)
		var along_x: bool = edge[1].x > 1.0
		var length: float = edge[1].x if along_x else edge[1].z
		var n := int(length / 1.1)
		for i in n + 1:
			var off: float = -0.5 * length + i * length / n
			B.mesh(self, B.boxm(Vector3(0.1, 0.9, 0.1)), edge[0] + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off)), fence_c)
	var wood := Color(0.45, 0.32, 0.2)
	var stone := Color(0.55, 0.55, 0.58)
	for i in 7:
		var gp := Vector3(4.8 + (i % 4) * 2.2, 0, -4.2 + (i >> 2) * 2.4)
		if gp.distance_to(Vector3(9.0, 0, -2.2)) < 2.4:
			continue
		if i % 2 == 0:
			_cross(gp, fposmod(i * 17.0, 24.0) - 12.0, fposmod(i * 7.0, 8.0) - 4.0, wood)
		else:
			B.mesh(self, B.boxm(Vector3(0.5, 0.8, 0.12)), gp + Vector3(0, 0.4, 0), stone, Vector3(0, fposmod(i * 11.0, 16.0) - 8.0, 0))
		B.mesh(self, B.boxm(Vector3(0.7, 0.04, 1.4)), gp + Vector3(0, 0.02, 0.8), Color(0.3, 0.45, 0.2))
	# Kirkon kivijalka: matala kumpu, jonka päällä kivirivi suorakaiteena (sanotaan 1559); kynttilä ilmestyy löydön jälkeen.
	var fj := Vector3(9.0, 0, -2.2)
	B.mesh(self, B.boxm(Vector3(3.6, 0.12, 2.6)), fj + Vector3(0, 0.04, 0), Color(0.33, 0.48, 0.22))
	for i in 8:
		B.mesh(self, B.sphere(0.3, 6), fj + Vector3(-1.5 + i * 0.43, 0.14, -1.1), Color(0.5, 0.5, 0.52)).scale = Vector3(1.0, 0.55, 0.8)
		B.mesh(self, B.sphere(0.3, 6), fj + Vector3(-1.5 + i * 0.43, 0.14, 1.1), Color(0.46, 0.46, 0.5)).scale = Vector3(1.0, 0.55, 0.8)
	for i in 5:
		B.mesh(self, B.sphere(0.3, 6), fj + Vector3(-1.6, 0.14, -0.9 + i * 0.45), Color(0.5, 0.5, 0.52)).scale = Vector3(0.8, 0.55, 1.0)
		B.mesh(self, B.sphere(0.3, 6), fj + Vector3(1.6, 0.14, -0.9 + i * 0.45), Color(0.46, 0.46, 0.5)).scale = Vector3(0.8, 0.55, 1.0)
	B.sign_pole(self, fj + Vector3(2.4, 0, 1.0), 1.0)
	var fj_sign := B.sign_plate(self, "KIVIJALKKA\nSanotaan: ensimmäinen kirkko 1559", Color(0.95, 0.93, 0.82), Color(0.1, 0.2, 0.3), 0.22, 26, Color(0.15, 0.25, 0.45))
	fj_sign.position = fj + Vector3(2.4, 1.0, 1.0)
	_candle = Node3D.new()
	_candle.position = fj + Vector3(0, 0.2, 0)
	add_child(_candle)
	B.mesh(_candle, B.cyl(0.06, 0.06, 0.28, 8), Vector3(0, 0.14, 0), Color(0.95, 0.92, 0.8))
	B.mesh(_candle, B.sphere(0.06, 8), Vector3(0, 0.34, 0), Color(1.0, 0.8, 0.3))
	var cl := OmniLight3D.new()
	cl.position = Vector3(0, 0.5, 0)
	cl.light_color = Color(1.0, 0.8, 0.45)
	cl.light_energy = 1.2
	cl.omni_range = 4.0
	_candle.add_child(cl)
	_candle.visible = false
	# Infotaulu hautausmaan portilla (vihje 2): tarina huhuna, nimen tulkinta epävarma.
	# Kyltit mitoitetaan pelikameralle: fontti 64, taulu kallistettu kameraa kohti (TILT yhdestä luvusta), ei puiden takana.
	var info := B.sign_plate(self, "MANAMANSALO\nSanotaan: metsästäjien\nhautausmaa, kirkko 1559.\nNimen tulkinta epävarma.",
		Color(0.95, 0.93, 0.82), Color(0.1, 0.2, 0.3), 0.34, 64, Color(0.15, 0.25, 0.45))
	_post_sign(info, Vector3(3.4, 0, 1.0), 2.2)
	# Laituri (varattu lossille, P15): lankkukansi paalujen päällä, kyltti ja kaide.
	var dock_c := Color(0.5, 0.38, 0.25)
	B.mesh(self, B.boxm(Vector3(2.0, 0.12, 7.0)), Vector3(-10.0, 0.35, SHORE_Z - 2.6), dock_c)
	for i in 14:
		B.mesh(self, B.boxm(Vector3(2.02, 0.01, 0.03)), Vector3(-10.0, 0.415, SHORE_Z + 0.8 - i * 0.5), dock_c.darkened(0.3))
	for pz in [1.0, -2.0, -5.0]:
		for sx in [-0.9, 0.9]:
			B.mesh(self, B.cyl(0.08, 0.08, 1.0, 8), Vector3(-10.0 + sx, 0.0, SHORE_Z + pz - 0.6), dock_c.darkened(0.25))
	B.mesh(self, B.boxm(Vector3(2.0, 0.06, 0.8)), Vector3(-10.0, 0.18, SHORE_Z + 1.3), dock_c)
	var dock_sign := B.sign_plate(self, "ALASSALMEN LOSSI\nVuoro 30 min välein\nLippu 3 €", Color(0.15, 0.25, 0.45), Color(0.95, 0.95, 0.95), 0.34, 64, Color(0.85, 0.85, 0.9))
	# Laiturin vasemmalla puolella (pelaajan rinnalla): [E]-vihje ruudun alareunassa ja lossimiehen kupla eivät peitä kylttiä.
	_post_sign(dock_sign, Vector3(-12.9, 0, -3.4), 1.8)
	# Lossi: keltainen lautta laiturin päässä (kansi, kaiteet, ohjaamo, ajoramppi), kaikki lautan lapsina.
	_lautta = Node3D.new()
	_lautta.position = LAUTTA_HOME
	add_child(_lautta)
	var yellow := Color(0.9, 0.72, 0.15)
	B.mesh(_lautta, B.boxm(Vector3(3.2, 0.34, 5.0)), Vector3(0, DECK_TOP - 0.17, 0), yellow.darkened(0.15))
	B.mesh(_lautta, B.boxm(Vector3(3.3, 0.06, 5.1)), Vector3(0, DECK_TOP - 0.03, 0), Color(0.35, 0.36, 0.38))
	for sx in [-1.55, 1.55]:
		B.mesh(_lautta, B.boxm(Vector3(0.08, 0.08, 4.4)), Vector3(sx, DECK_TOP + 0.95, 0), Color(0.95, 0.95, 0.95))
		for pz in [-2.2, -0.7, 0.7, 2.2]:
			B.mesh(_lautta, B.boxm(Vector3(0.08, 0.95, 0.08)), Vector3(sx, DECK_TOP + 0.47, pz), Color(0.95, 0.95, 0.95))
	B.mesh(_lautta, B.boxm(Vector3(1.0, 1.9, 1.3)), Vector3(1.0, DECK_TOP + 0.95, -1.7), Color(0.95, 0.95, 0.92))
	B.mesh(_lautta, B.boxm(Vector3(1.04, 0.5, 1.34)), Vector3(1.0, DECK_TOP + 1.2, -1.7), Color(0.55, 0.72, 0.85)).scale = Vector3(1.0, 1.0, 0.9)
	B.mesh(_lautta, B.boxm(Vector3(1.2, 0.1, 1.5)), Vector3(1.0, DECK_TOP + 1.95, -1.7), Color(0.2, 0.2, 0.22))
	B.mesh(_lautta, B.boxm(Vector3(2.9, 0.05, 0.12)), Vector3(0, DECK_TOP + 0.03, 2.3), Color(0.95, 0.95, 0.95))
	_lossimies = Looks.make(self, {"shirt": Color(0.15, 0.25, 0.45), "pants": Color(0.2, 0.2, 0.24),
		"shoes": Color(0.12, 0.1, 0.08), "hair": "Hair_Buzzed", "hair_color": Color(0.35, 0.3, 0.25), "height": 1.75})
	_lossimies.position = Vector3(-8.7, 0, -4.9)  # laiturin kyljessä, katsoo laiturin paikkaa (-X)
	_lossimies.rotation.y = B.yaw_to(Vector3(-1, 0, 0))
	_lossimies.play("Idle", 0.0)
	_bubble2 = B.bubble(self, BUBBLE2_AT, Color.WHITE, 0.8)
	# Tie, taksi, puita.
	B.mesh(self, B.boxm(Vector3(30.0, 0.02, 3.0)), Vector3(0, 0.003, 8.8), Color(0.3, 0.3, 0.32))
	B.mesh(self, B.boxm(Vector3(30.0, 0.025, 0.12)), Vector3(0, 0.01, 8.8), Color(0.9, 0.8, 0.3))
	var taxi := Node3D.new()
	taxi.position = Vector3(-12.0, 0, 8.3)
	taxi.rotation.y = PI / 2.0
	add_child(taxi)
	Vehicles.taxi(taxi)
	for p in [Vector3(-14.0, 0, -2.0), Vector3(-3.6, 0, -4.8), Vector3(0.5, 0, -5.0), Vector3(14.0, 0, -4.8), Vector3(14.0, 0, 4.5)]:
		_spruce(p, 1.0 + fposmod(p.x, 0.4))
	for p in [Vector3(-14.0, 0, 3.5), Vector3(-0.8, 0, 5.8), Vector3(10.5, 0, 5.4), Vector3(-6.0, 0, 5.0)]:
		_birch(p, 0.9 + fposmod(p.x, 0.3))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 4.0, 2.0)
	lamp.light_color = Color(1.0, 0.95, 0.8)
	lamp.light_energy = 0.6
	lamp.omni_range = 16.0
	add_child(lamp)
