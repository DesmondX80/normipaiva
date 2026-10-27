extends Node3D
## Pyhäjoen Koskipuisto ja Hanhikivi (retket.gd "hanhikivi"): taskukohtaus kuten retki_lampi.gd. Kävely player_walker.gd:llä.
## Kivellä tehdään legendan loppu (hanhikivi_legenda.gd, main.gd), kyltti antaa toisen vihjeen.
## Teoria rajakivestä on huhu: kaikki tekstit "sanotaan"-muodossa. Tarkistettava: kiven tarkka paikka ja vaakunan yhteys.
## Paikallinen -Z = joki ja Hourunkosken kosket (takaseinä), +Z = tie ja parkki (kamera). Kivi on rannalla (x 4).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")
const Vehicles := preload("res://scripts/vehicles.gd")

const HALF := Vector2(15.0, 10.0)
const SHORE_Z := -4.6  # rantaviiva: joki on tämän takana (kävelyraja)

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var spot := ""
var spots := {
	"ovi": [Vector3(-12.0, 0, 6.4), "[E] Taksille: takaisin lähtöpaikkaan"],
	"kyltti": [Vector3(-3.0, 0, -2.6), "[E] Lue Koskipuiston kyltti"],
	"kivi": [Vector3(4.0, 0, -2.4), "[E] Tutki Hanhikiveä"],
	"onkija": [Vector3(-9.0, 0, -3.0), "[E] Juttele kalastajan kanssa"],
}
var _enter_frame := -1
var _fisher: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _foam: Array = []  # [Node3D, vaihe, perus-y]
var _t := 0.0
const FISHER_LINES := ["Hourunkoski on kaunis, kun vettä tulee. Lohta ei oo näkynyt.", "Hanhikivi? Sanotaan, että se oli ennen rajalla. Joku sen siirsi.",
	"Mun isä sano, ettei kiveen kosketa. En tiedä miksi.", "Kuulemma vaakunassakin on hanhi. En oo tarkistanut."]


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
	_fisher.play("Idle_Talking", 0.2)


func _process(delta: float) -> void:
	_t += delta
	_bubble_t -= delta
	if _bubble.text != "" and _bubble_t <= 0.0:
		_bubble.text = ""
		_fisher.play("Idle", 0.3)
	for f in _foam:
		f[0].position.y = f[2] + sin(_t * 3.0 + f[1]) * 0.04
		f[0].scale = Vector3.ONE * (1.0 + sin(_t * 2.3 + f[1] * 2.0) * 0.15)
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
	match best:
		"ovi":
			exited.emit()
		"onkija":
			say(FISHER_LINES.pick_random(), 4.5)
		_:
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
	for k in 4:
		B.mesh(self, B.boxm(Vector3(0.14 * s, 0.05 * s, 0.01)), at + Vector3(0, (0.7 + k * 0.6) * s, 0.09 * s), Color(0.15, 0.14, 0.14))
	B.mesh(self, B.sphere(1.0 * s, 8), at + Vector3(0, 3.5 * s, 0), Color(0.35, 0.6, 0.22)).scale = Vector3(1.0, 1.2, 1.0)


func _build() -> void:
	var grass := Color(0.35, 0.58, 0.25)
	var path_c := Color(0.8, 0.72, 0.52)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.2, 0.4, 0.18))
	# Puisto: nurmikko rantaviivasta tielle, hiekkapolku parkilta kyltille ja kivelle.
	var park_d := HALF.y - SHORE_Z
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, park_d)), Vector3(0, -0.05, (HALF.y + SHORE_Z) / 2.0), grass)
	B.mesh(self, B.boxm(Vector3(1.4, 0.02, 9.0)), Vector3(-11.0, 0.005, 2.0), path_c)
	B.mesh(self, B.boxm(Vector3(16.0, 0.02, 1.4)), Vector3(-3.0, 0.005, -1.4), path_c)
	B.mesh(self, B.boxm(Vector3(1.4, 0.02, 2.0)), Vector3(4.0, 0.005, -1.2), path_c)
	# Joki ja Hourunkosken kosket: tumma vesi, vaahtoa ja kiviä virrassa, vastarannan metsä.
	var water := B.mesh(self, B.boxm(Vector3(80, 0.02, 9.0)), Vector3(0, -0.12, -9.2), Color(0.2, 0.4, 0.5))
	water.material_override.roughness = 0.12
	water.material_override.metallic = 0.3
	B.mesh(self, B.boxm(Vector3(80, 0.4, 0.3)), Vector3(0, -0.25, SHORE_Z - 0.1), Color(0.35, 0.3, 0.22))
	for i in 16:
		var x := -13.0 + i * 1.75 + sin(i * 2.7) * 0.5
		var z := -6.2 - fposmod(i * 1.9, 3.2)
		var rock := B.mesh(self, B.sphere(0.45, 8), Vector3(x, -0.08, z), Color(0.42, 0.42, 0.44).darkened((i % 3) * 0.1))
		rock.scale = Vector3(1.2 + (i % 2) * 0.4, 0.7, 1.0)
		var foam := B.mesh(self, B.sphere(0.3, 8), Vector3(x, -0.05, z + 0.55), Color(0.95, 0.97, 1.0))
		foam.scale = Vector3(1.6, 0.35, 0.8)
		_foam.append([foam, i * 0.8, -0.05])
	for i in 7:
		var fx := -12.0 + i * 4.0
		var streak := B.mesh(self, B.boxm(Vector3(2.0, 0.01, 0.16)), Vector3(fx, -0.105, -7.0 - (i % 3) * 1.1), Color(0.8, 0.9, 0.95))
		streak.rotation.y = 0.1 * ((i % 2) * 2 - 1)
	for k in 14:
		var tx := -14.0 + k * 2.2
		B.mesh(self, B.cyl(0.1, 0.14, 1.4, 6), Vector3(tx, 0.7, -13.4), Color(0.3, 0.2, 0.12))
		B.mesh(self, B.cyl(0.0, 1.3, 3.4, 8), Vector3(tx, 2.6, -13.4), Color(0.1, 0.3 + (k % 3) * 0.04, 0.15))
	# Hanhikivi: iso rosoinen graniittilohkare rannalla (esikuva: siirtolohkare, pyöristyneet särmät, halkeamat, sammalta
	# päällä ja kolossa), varjo maassa, pari pienempää kiveä juurella ja kiven viereen kivinen laatta.
	var sx := 4.0
	var sz := -3.4
	B.mesh(self, B.sphere(1.0, 16), Vector3(sx + 0.1, 0.012, sz + 0.15), Color(0.1, 0.22, 0.1)).scale = Vector3(2.5, 0.01, 1.7)
	var boulder := MeshInstance3D.new()
	boulder.mesh = _boulder_mesh(Vector3(1.75, 0.95, 1.05), 7)
	boulder.material_override = B.vcol_srgb_mat()
	boulder.position = Vector3(sx, 0.78, sz)
	boulder.rotation.y = 0.25
	add_child(boulder)
	for r in [[Vector3(-1.75, 0.0, 0.85), 0.32, 3], [Vector3(1.9, 0.0, 0.55), 0.26, 5], [Vector3(-0.6, 0.0, 1.0), 0.18, 9]]:
		var sm := MeshInstance3D.new()
		sm.mesh = _boulder_mesh(Vector3(r[1], r[1] * 0.65, r[1] * 0.8), r[2])
		sm.material_override = B.vcol_srgb_mat()
		sm.position = Vector3(sx + r[0].x, r[1] * 0.45, sz + r[0].z)
		sm.rotation.y = r[2]
		add_child(sm)
	var body := StaticBody3D.new()
	body.position = Vector3(sx, 0.7, sz)
	body.add_child(B.box_shape(Vector3(3.6, 1.4, 1.8)))
	add_child(body)
	# Hanhikiven laatta (kyltti kiven edessä).
	B.sign_pole(self, Vector3(sx, 0, sz + 1.45), 0.5)
	var stone_plate := B.sign_plate(self, "HANHIKIVI\nsanotaan: rajakivi", Color(0.88, 0.86, 0.8), Color(0.12, 0.12, 0.16), 0.3, 64, Color(0.4, 0.4, 0.42))
	stone_plate.position = Vector3(sx, 0.62, sz + 1.5)
	stone_plate.rotation.x = -0.45  # kallistettu taaksepäin kuin opastaulu: luettavissa ylhäältä
	# Koskipuiston opaskyltti: huhu rajakivestä (vihje 2).
	B.sign_pole(self, Vector3(-3.0, 0, -3.1), 2.4)
	var info := B.sign_plate(self, "KOSKIPUISTO\nHanhikivi on kuulemma\nvanha rajamerkki. Sanotaan,\nettä joku siirsi sen.\nKukaan ei tiedä, kuka.",
		Color(0.95, 0.93, 0.82), Color(0.08, 0.16, 0.25), 0.34, 60, Color(0.1, 0.3, 0.2))
	info.position = Vector3(-3.0, 2.0, -3.05)
	info.rotation.x = -0.25
	# Kalastaja rannalla (seisoo, ei erikoisasentoa).
	_fisher = Looks.make(self, {"shirt": Color(0.3, 0.45, 0.3), "pants": Color(0.3, 0.3, 0.35),
		"shoes": Color(0.2, 0.15, 0.12), "hair": "Hair_Buzzed", "hair_color": Color(0.5, 0.5, 0.5), "height": 1.74})
	_fisher.position = Vector3(-9.0, 0, -3.8)
	_fisher.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_fisher.play("Idle", 0.0)
	_bubble = B.bubble(_fisher, Vector3(0, 1.95, 0), Color.WHITE, 0.7)
	# Penkki on pelkkä koriste (kukaan ei istu): -Z = penkin etupuoli (joelle päin), selkä +Z:ssa.
	var bench_x := -8.0
	_solid(Vector3(1.8, 0.08, 0.45), Vector3(bench_x, 0.5, -1.2), Color(0.6, 0.42, 0.24))
	B.mesh(self, B.boxm(Vector3(1.8, 0.4, 0.06)), Vector3(bench_x, 0.78, -0.97), Color(0.55, 0.38, 0.2))
	for lx in [-0.8, 0.8]:
		B.mesh(self, B.boxm(Vector3(0.08, 0.5, 0.4)), Vector3(bench_x + lx, 0.25, -1.2), Color(0.35, 0.25, 0.15))
	# Tie ja taksi, koivuja ja kuusia.
	B.mesh(self, B.boxm(Vector3(30.0, 0.02, 3.0)), Vector3(0, 0.003, 8.8), Color(0.3, 0.3, 0.32))
	B.mesh(self, B.boxm(Vector3(30.0, 0.025, 0.12)), Vector3(0, 0.01, 8.8), Color(0.9, 0.8, 0.3))
	var taxi := Node3D.new()
	taxi.position = Vector3(-12.0, 0, 8.3)
	taxi.rotation.y = PI / 2.0
	add_child(taxi)
	Vehicles.taxi(taxi)
	for p in [Vector3(-14.0, 0, -1.0), Vector3(-6.0, 0, 3.5), Vector3(0.5, 0, 4.0), Vector3(9.0, 0, 1.5), Vector3(13.5, 0, -2.5), Vector3(12.0, 0, 5.0)]:
		_birch(p, 0.9 + fposmod(p.x, 0.3))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 4.0, 0.0)
	lamp.light_color = Color(1.0, 0.95, 0.8)
	lamp.light_energy = 0.6
	lamp.omni_range = 14.0
	add_child(lamp)


## Rosoinen lohkare: kuutiopallo (6 ruudukkoa, ei napoja eikä viuhkoja), pyöristetty särmiö (superellipsoidi) + sileä
## kohina, litistetty pohja. Pehmeät normaalit jaetuista pisteistä; verteksiväri: harmaa graniitti, sammal pehmeänä
## liukuna normaalin y-komponentin mukaan, tumma pohja ja kolo (painauma) +Z-kyljessä.
func _boulder_mesh(half: Vector3, seed_i: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_i
	noise.frequency = 1.1
	var fine := FastNoiseLite.new()
	fine.seed = seed_i + 40
	fine.frequency = 2.5
	var n := 16
	var hole_dir := Vector3(0.25, -0.05, 0.97).normalized()
	var pos := {}  # Vector3i(suunta) -> sijainti
	var nrm := {}  # Vector3i(suunta) -> summattu normaali
	var tris: Array = []  # [avain, avain, avain]
	var axes := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.BACK, Vector3.LEFT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	for ax in axes:
		var keys: Array = []
		for j in n + 1:
			for i in n + 1:
				var cp: Vector3 = ax[0] + ax[1] * (2.0 * j / n - 1.0) + ax[2] * (2.0 * i / n - 1.0)
				# Tasainen jako: tangenttikuvaus tasaa ruudukon ruudut pallolla.
				cp = Vector3(tan(cp.x * PI / 4.0), tan(cp.y * PI / 4.0), tan(cp.z * PI / 4.0))
				var d := cp.normalized()
				var key := Vector3i((d * 1000.0).round())
				keys.append(key)
				if not pos.has(key):
					var k := pow(pow(absf(d.x), 4.0) + pow(absf(d.y), 4.0) + pow(absf(d.z), 4.0), 0.25)
					var q := d / k
					q *= 1.0 + noise.get_noise_3dv(d * 2.0) * 0.14 + fine.get_noise_3dv(d * 2.0) * 0.03
					var hd := (d - hole_dir).length()
					if hd < 0.45:
						q *= 1.0 - 0.2 * (1.0 - hd / 0.45) * (1.0 - hd / 0.45)
					q.y = maxf(q.y, -0.62)  # litistettu pohja
					pos[key] = q * half
					nrm[key] = Vector3.ZERO
		for j in n:
			for i in n:
				var k0: Vector3i = keys[j * (n + 1) + i]
				var k1: Vector3i = keys[j * (n + 1) + i + 1]
				var k2: Vector3i = keys[(j + 1) * (n + 1) + i + 1]
				var k3: Vector3i = keys[(j + 1) * (n + 1) + i]
				for t in [[k0, k3, k1], [k1, k3, k2]]:
					var a: Vector3 = pos[t[0]]
					var b: Vector3 = pos[t[1]]
					var c: Vector3 = pos[t[2]]
					var fn := (b - a).cross(c - a)
					var outward := fn.dot((a + b + c) / 3.0) > 0.0
					if outward:
						t = [t[0], t[2], t[1]]  # Godotin etupuoli on myötäpäivään: kiertosuunnan normaali sisäänpäin
					else:
						fn = -fn
					for kk in t:
						nrm[kk] += fn  # ulospäin osoittava, pinta-alalla painotettu
					tris.append(t)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := Color(0.5, 0.48, 0.47)
	for t in tris:
		for kk in t:
			var pt: Vector3 = pos[kk]
			var nn: Vector3 = (nrm[kk] as Vector3).normalized()
			var cl := base.darkened(0.1 + fine.get_noise_3dv(pt * 1.5) * 0.1 + (1.0 - nn.y) * 0.06)
			cl = cl.lightened(clampf(fine.get_noise_3dv(pt * 5.0 + Vector3(9, 0, 0)), 0.0, 1.0) * 0.12)
			var m := smoothstep(0.5, 0.85, nn.y + noise.get_noise_3dv(pt * 2.0 + Vector3(3, 5, 1)) * 0.5)
			cl = cl.lerp(Color(0.3, 0.42, 0.2).darkened(0.1 + fine.get_noise_3dv(pt * 3.0) * 0.12), m * 0.75)
			cl = cl.darkened(smoothstep(-half.y * 0.2, -half.y * 0.6, pt.y) * 0.45)
			var hs := (pt / half).normalized().distance_to(hole_dir)
			cl = cl.darkened(smoothstep(0.35, 0.15, hs) * 0.5)
			st.set_normal(nn)
			st.set_color(cl)
			st.add_vertex(pt)
	return st.commit()
