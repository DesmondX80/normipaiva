extends Node3D
## Satunnainen juna Vaalan mopomatkan radalla (vaala.gd _build_train): radan OSM-pätkistä ketjutettua reittiä pitkin
## päästä päähän. Juna lähtee satunnaisin välein siitä päästä, joka on kauempana kamerasta (ilmestyminen ei näy), ja
## katoaa toiseen päähän. Sr1-veturi ja neljä sinistä vaunua (yksi ravintolavaunu), 70-90 km/h. Jyrinä 3D-äänenä
## veturissa, vihellys ohittaessa kameran.
## Aikataulun mukainen juna (main.gd _train_schedule): call_station tuo matkustajajunan asemalle, joka jarruttaa
## junan keskikohta laiturin kohdalle, seisoo STOP_DWELL s (vain silloin pääsee kyytiin, at_station) ja jatkaa
## matkaa. arrive_stopped: juna jolla pelaaja juuri tuli, seisoo asemalla ja lähtee. random = false: ei
## satunnaisia ohikulkujunia (Saloisissa vain aikataulun junat).

const B := preload("res://scripts/build.gd")

const WAIT := Vector2(60.0, 180.0)  # junien väli (s)
const RAIL_TOP := 0.22             # kiskon yläpinta reitin pisteiden yläpuolella

var path := PackedVector3Array()   # kiskojen keskilinja (y = ratapölkkyjen taso)
var _cum := PackedFloat32Array()
var _length := 0.0
var _units: Array = []             # [solmu, pituus, keskikohdan etäisyys veturin keulasta]
var _active := false
var _s := 0.0                      # veturin keulan matka reitillä ajosuuntaan
var _dir := 1
var _speed := 25.0
var _wait := 0.0
var _train_len := 0.0
var _rumble: AudioStreamPlayer3D
var _honked := false
var random := true
var _phase := ""                   # "" vapaa tai satunnainen, "in" saapuu, "stop" asemalla, "out" lähtee
var _stop_s := 0.0                 # _s, jolla junan keskikohta on laiturilla
var _dwell := 0.0
var _pending := -1.0               # lähtevän junan aikana kutsuttu seuraava pysähdys (stop_t)
const STOP_DWELL := 30.0
const BRAKE := 0.8                 # m/s²
const ACCEL := 0.5
const CRUISE := 25.0
const APPROACH := 600.0            # saapuva juna ilmestyy näin kauas laiturista


func setup(p: PackedVector3Array) -> void:
	path = p
	_cum.resize(path.size())
	_cum[0] = 0.0
	for i in range(1, path.size()):
		_cum[i] = _cum[i - 1] + path[i].distance_to(path[i - 1])
	_length = _cum[path.size() - 1]
	_wait = randf_range(15.0, 45.0)


## Seuraava juna heti (testit).
func spawn_now(passenger := true, from_start := -1) -> void:
	_spawn(passenger, from_start)


func _process(delta: float) -> void:
	if path.size() < 2:
		return
	if not _active:
		if not random:
			return
		_wait -= delta
		if _wait <= 0.0:
			_spawn(randf() < 0.6)
		return
	match _phase:
		"in":
			var left := _stop_s - _s
			_speed = minf(CRUISE, sqrt(2.0 * BRAKE * maxf(left, 0.0)) + 0.4)
			if left <= 0.05:
				_s = _stop_s
				_speed = 0.0
				_phase = "stop"
				_dwell = STOP_DWELL
		"stop":
			_speed = 0.0
			_dwell -= delta
			if _dwell <= 0.0:
				_phase = "out"
				if _units.size() > 0:
					Sfx.play_on(_units[0][0], "horn", 4.0, 0.48, 2.6)
		"out":
			_speed = minf(CRUISE, _speed + ACCEL * delta)
			if _pending >= 0.0 and _s - _stop_s > _train_len + 150.0:
				var t := _pending
				_pending = -1.0
				call_station(t)
				return
	_s += _speed * delta
	if _rumble != null:
		_rumble.volume_db = lerpf(-12.0, 6.0, clampf(_speed / CRUISE, 0.0, 1.0))
	_place()
	var cam := get_viewport().get_camera_3d()
	if cam != null and not _honked and _units.size() > 0:
		var loco: Node3D = _units[0][0]
		if loco.visible and loco.global_position.distance_to(cam.global_position) < 160.0:
			_honked = true
			Sfx.play_on(loco, "horn", 6.0, 0.48, 2.6)
	if _s - _train_len > _length + 5.0:
		var pend := _pending
		_despawn()
		if pend >= 0.0:
			call_station(pend)


func _spawn(passenger: bool, from_start := -1) -> void:
	_despawn()
	var cam := get_viewport().get_camera_3d()
	if from_start < 0:
		var c := to_local(cam.global_position) if cam != null else path[0]
		from_start = 1 if c.distance_to(path[0]) > c.distance_to(path[path.size() - 1]) else 0
	_dir = 1 if from_start == 1 else -1
	_speed = 25.0 if passenger else 19.0
	var specs: Array = [["loco", 18.96], ["coach", 26.4], ["coach", 26.4], ["dining", 26.4], ["coach", 26.4]]
	var off := 0.0
	for sp in specs:
		var n := Node3D.new()
		add_child(n)
		var ln: float = sp[1]
		match sp[0]:
			"loco":
				build_loco(n, ln)
			_:
				build_coach(n, ln, sp[0] == "dining")
		_units.append([n, ln, off + ln / 2.0])
		off += ln + 0.8
	_train_len = off
	_s = 0.0
	_active = true
	_honked = false
	_rumble = AudioStreamPlayer3D.new()
	_rumble.stream = Sfx.stream("tractor_engine")
	_rumble.pitch_scale = 0.42
	_rumble.volume_db = 6.0
	_rumble.unit_size = 25.0
	_rumble.max_distance = 700.0
	_rumble.bus = "SFX"
	(_units[0][0] as Node3D).add_child(_rumble)
	_rumble.play()
	_place()


func _despawn() -> void:
	for u in _units:
		(u[0] as Node3D).queue_free()
	_units.clear()
	_active = false
	_phase = ""
	_pending = -1.0
	_rumble = null
	_wait = randf_range(WAIT.x, WAIT.y)


## Aikataulun juna asemalle: stop_t = laiturin kohta reitillä (path-koordinaatti, ks. nearest_t). Tulee siitä
## päästä, joka on kauempana kamerasta, APPROACH m:n päästä laiturista.
func call_station(stop_t: float) -> void:
	if _active and _phase == "out":
		_pending = stop_t  # edellinen lähtee ensin laiturilta pois näkyvistä
		return
	var cam := get_viewport().get_camera_3d()
	var c := to_local(cam.global_position) if cam != null else path[0]
	var from_start := 1 if c.distance_to(path[0]) > c.distance_to(path[path.size() - 1]) else 0
	# Tulopäässä oltava tilaa saapua ja jarruttaa (asema voi olla lähellä reitin päätä).
	var room := stop_t if from_start == 1 else _length - stop_t
	if room < APPROACH * 0.75 and _length - room > room:
		from_start = 1 - from_start
	_start_at_station(stop_t, from_start)
	_s = maxf(0.0, _stop_s - APPROACH)
	_speed = CRUISE
	_phase = "in"
	_place()


## Juna, jolla pelaaja juuri saapui: seisoo laiturilla hetken ja lähtee.
func arrive_stopped(stop_t: float, dwell := 8.0) -> void:
	_start_at_station(stop_t, randi() % 2)
	_s = _stop_s
	_speed = 0.0
	_phase = "stop"
	_dwell = dwell
	_place()


func _start_at_station(stop_t: float, from_start: int) -> void:
	_spawn(true, from_start)
	var d := stop_t if _dir == 1 else _length - stop_t
	_stop_s = d + _train_len / 2.0


func arriving() -> bool:
	return _active and (_phase == "in" or _pending >= 0.0)


func at_station() -> bool:
	return _active and _phase == "stop"


## Aikataulun juna tulossa tai asemalla (lähtevä ei enää).
func calling() -> bool:
	return arriving() or at_station()


## Saapumiseen kuluva aika (s) call_stationista pysähdykseen.
static func approach_secs() -> float:
	var brake_d := CRUISE * CRUISE / (2.0 * BRAKE)
	return (APPROACH - brake_d) / CRUISE + CRUISE / BRAKE


## Lähimmän reitin kohdan path-koordinaatti (matka reitin alusta).
func nearest_t(p: Vector3) -> float:
	var best := INF
	var bt := 0.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var u := clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := Vector2(p.x - a.x, p.z - a.z).distance_to(ab * u)
		if d < best:
			best = d
			bt = _cum[i] + (_cum[i + 1] - _cum[i]) * u
	return bt


## Piste reitillä matkan d kohdalla ajosuunnassa (d = 0 lähtöpäässä).
func _at(d: float) -> Vector3:
	var t := d if _dir == 1 else _length - d
	t = clampf(t, 0.0, _length)
	var lo := 0
	var hi := path.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _cum[mid] <= t:
			lo = mid
		else:
			hi = mid
	var seg := maxf(_cum[hi] - _cum[lo], 0.001)
	return path[lo].lerp(path[hi], (t - _cum[lo]) / seg)


func _place() -> void:
	for u in _units:
		var n: Node3D = u[0]
		var ln: float = u[1]
		var c: float = _s - float(u[2])
		var df := c + ln / 2.0 - 2.5
		var dr := c - ln / 2.0 + 2.5
		n.visible = dr >= 0.0 and df <= _length
		if not n.visible:
			continue
		var pf := _at(df)
		var pr := _at(dr)
		var mid := (pf + pr) / 2.0 + Vector3(0, RAIL_TOP, 0)
		n.position = mid  # paikallinen kehys (Vaalan maailma voi olla siirretty)
		if pf.distance_to(pr) > 0.1:
			n.basis = Basis.looking_at(pf - pr, Vector3.UP)


# --- Mallit (-Z eteenpäin, kiskon yläpinta y = 0); staattisina, myös ravintolavaunun välikuva käyttää niitä ---------

const VR_RED := Color(0.74, 0.07, 0.06)
const VR_WHITE := Color(0.95, 0.95, 0.93)
const VR_GREEN := Color(0.0, 0.46, 0.26)
const DARK := Color(0.1, 0.1, 0.11)
const GLASS := Color(0.07, 0.1, 0.13)


## Telit: sivupalkit, akselilaatikot, jousitus ja neljä pyörää laippoineen.
static func _bogies(n: Node3D, ln: float, inset := 3.4) -> void:
	for z: float in [-(ln / 2.0 - inset), ln / 2.0 - inset]:
		B.mesh(n, B.boxm(Vector3(2.0, 0.22, 2.9)), Vector3(0, 0.82, z), DARK)  # telin runko
		for sx: float in [-1.0, 1.0]:
			B.mesh(n, B.boxm(Vector3(0.14, 0.42, 3.1)), Vector3(sx * 0.98, 0.55, z), Color(0.16, 0.16, 0.17))  # sivupalkki
			for wz: float in [-1.05, 1.05]:
				B.mesh(n, B.cyl(0.46, 0.46, 0.1, 16), Vector3(sx * 0.76, 0.46, z + wz), Color(0.25, 0.24, 0.23), Vector3(0, 0, 90))
				B.mesh(n, B.cyl(0.5, 0.5, 0.03, 16), Vector3(sx * 0.7, 0.46, z + wz), Color(0.3, 0.29, 0.28), Vector3(0, 0, 90))  # laippa
				B.mesh(n, B.boxm(Vector3(0.22, 0.26, 0.3)), Vector3(sx * 1.08, 0.46, z + wz), Color(0.2, 0.2, 0.2))  # akselilaatikko
			B.mesh(n, B.cyl(0.11, 0.11, 0.34, 8), Vector3(sx * 0.98, 0.98, z), Color(0.35, 0.33, 0.3))  # jousi


static func _buffers(n: Node3D, z: float, dir: float) -> void:
	B.mesh(n, B.boxm(Vector3(2.9, 0.42, 0.18)), Vector3(0, 1.05, z), DARK)  # puskinpalkki
	for sx: float in [-0.88, 0.88]:
		B.mesh(n, B.cyl(0.07, 0.07, 0.42, 8), Vector3(sx, 1.05, z + dir * 0.3), Color(0.25, 0.25, 0.25), Vector3(90, 0, 0))
		B.mesh(n, B.cyl(0.2, 0.2, 0.05, 14), Vector3(sx, 1.05, z + dir * 0.52), Color(0.3, 0.3, 0.3), Vector3(90, 0, 0))
	B.mesh(n, B.boxm(Vector3(0.18, 0.16, 0.5)), Vector3(0, 1.0, z + dir * 0.3), Color(0.2, 0.2, 0.2))  # kytkin


## VR:n Sr1-sähköveturi valokuvan mukaan: valkoinen kori, punainen alaraita ja punaiset keulat, ohjaamon ikkunat
## mustin kehyksin, kolme valoa, ylhäällä tummat ilmanottosäleiköt ja katolla kaksi virroitinta.
static func build_loco(n: Node3D, ln := 18.96) -> void:
	_bogies(n, ln)
	B.mesh(n, B.boxm(Vector3(2.95, 0.35, ln - 0.4)), Vector3(0, 1.2, 0), DARK)  # alusta
	B.mesh(n, B.boxm(Vector3(3.1, 2.55, ln - 2.6)), Vector3(0, 2.65, 0), VR_WHITE)  # kori
	B.mesh(n, B.boxm(Vector3(3.12, 0.55, ln - 2.5)), Vector3(0, 1.62, 0), VR_RED)  # punainen alaraita
	B.mesh(n, B.boxm(Vector3(3.12, 0.1, ln - 2.5)), Vector3(0, 2.05, 0), VR_RED)  # ohut raita
	for sx: float in [-1.0, 1.0]:
		for k in 6:  # säleiköt korin yläosassa
			var z := -ln / 2.0 + 3.0 + k * (ln - 6.0) / 5.0
			B.mesh(n, B.boxm(Vector3(0.05, 0.75, 1.5)), Vector3(sx * 1.56, 3.35, z), Color(0.22, 0.24, 0.26))
		for k in 3:  # pienet sivuikkunat
			B.mesh(n, B.boxm(Vector3(0.05, 0.55, 0.7)), Vector3(sx * 1.56, 2.55, -ln / 2.0 + 5.0 + k * 4.4), GLASS)
		var logo := B.label(n, "VR", Vector3(sx * 1.58, 1.62, 0), 110, VR_WHITE)
		logo.rotation.y = sx * PI / 2.0
	B.mesh(n, B.boxm(Vector3(2.8, 0.2, ln - 2.4)), Vector3(0, 4.02, 0), Color(0.5, 0.52, 0.53))  # katto
	for zs: float in [-1.0, 1.0]:
		var ze := zs * (ln / 2.0 - 0.95)
		# Ohjaamo: punainen keula, valkoinen yläosa ja tuulilasit.
		B.mesh(n, B.boxm(Vector3(3.08, 1.3, 1.7)), Vector3(0, 1.95, ze), VR_RED)
		var top := B.mesh(n, B.boxm(Vector3(3.0, 1.35, 1.6)), Vector3(0, 3.25, ze - zs * 0.05), VR_WHITE)
		top.rotation.x = zs * -0.1
		for wx: float in [-0.7, 0.7]:
			B.mesh(n, B.boxm(Vector3(1.25, 0.85, 0.06)), Vector3(wx, 3.2, ze + zs * 0.86), GLASS)
		B.mesh(n, B.boxm(Vector3(0.16, 0.95, 0.07)), Vector3(0, 3.2, ze + zs * 0.87), Color(0.12, 0.12, 0.12))
		for sx: float in [-1.0, 1.0]:
			B.mesh(n, B.boxm(Vector3(0.05, 0.7, 0.8)), Vector3(sx * 1.55, 3.2, ze - zs * 0.1), GLASS)
		for lx: float in [-1.0, 1.0]:
			var lamp := B.mesh(n, B.cyl(0.13, 0.13, 0.06, 12), Vector3(lx, 2.2, ze + zs * 0.86), Color(1.0, 0.96, 0.85), Vector3(90, 0, 0))
			if zs < 0.0:
				lamp.material_override = B.unshaded(Color(1.0, 0.97, 0.85))
		var top_lamp := B.mesh(n, B.cyl(0.11, 0.11, 0.06, 12), Vector3(0, 3.85, ze + zs * 0.84), Color(1.0, 0.96, 0.85), Vector3(90, 0, 0))
		if zs < 0.0:
			top_lamp.material_override = B.unshaded(Color(1.0, 0.97, 0.85))
		_buffers(n, zs * (ln / 2.0 - 0.1), zs)
	# Kaksi virroitinta (timanttikehys) eristimineen.
	var steel := Color(0.2, 0.2, 0.22)
	for pz: float in [-ln / 2.0 + 4.3, ln / 2.0 - 4.3]:
		var pc := Vector3(0, 4.1, pz)
		for sx: float in [-0.6, 0.6]:
			B.mesh(n, B.cyl(0.08, 0.08, 0.3, 8), pc + Vector3(sx, 0.15, 0), Color(0.75, 0.55, 0.3))
		var lean := -0.6 if pz < 0.0 else 0.6
		B.tube(n, pc + Vector3(-0.6, 0.3, 0), pc + Vector3(0, 0.9, lean), 0.035, steel)
		B.tube(n, pc + Vector3(0.6, 0.3, 0), pc + Vector3(0, 0.9, lean), 0.035, steel)
		B.tube(n, pc + Vector3(0, 0.9, lean), pc + Vector3(0, 1.5, 0.0), 0.035, steel)
		B.mesh(n, B.boxm(Vector3(1.7, 0.05, 0.25)), pc + Vector3(0, 1.53, 0.0), Color(0.15, 0.15, 0.15))


const COACH_BLUE := Color(0.27, 0.38, 0.5)
const COACH_BAND := Color(0.8, 0.84, 0.86)
const COACH_ROOF := Color(0.84, 0.86, 0.86)


## VR:n vanha sininen matkustajavaunu valokuvan mukaan: siniharmaa kori, vaalea raita ikkunoiden yllä, pitkä rivi
## pieniä ikkunoita, tummemmat ovet päissä, vaalea kaareva katto ja palkeet. dining = ravintolavaunu (RAVINTOLA,
## valaistut ikkunat).
static func build_coach(n: Node3D, ln := 26.4, dining := false) -> void:
	_bogies(n, ln, 3.9)
	B.mesh(n, B.boxm(Vector3(2.95, 0.35, ln - 0.6)), Vector3(0, 1.2, 0), DARK)
	B.mesh(n, B.boxm(Vector3(3.1, 2.5, ln - 0.8)), Vector3(0, 2.62, 0), COACH_BLUE)
	B.mesh(n, B.boxm(Vector3(3.12, 0.22, ln - 0.7)), Vector3(0, 3.7, 0), COACH_BAND)  # vaalea raita
	B.mesh(n, B.boxm(Vector3(3.12, 0.06, ln - 0.7)), Vector3(0, 1.5, 0), COACH_BLUE.darkened(0.3))  # alareuna
	# Kaareva katto: litistetty sylinteri radan suuntaan.
	var roof := B.mesh(n, B.cyl(1.55, 1.55, ln - 0.8, 20), Vector3(0, 3.82, 0), COACH_ROOF, Vector3(90, 0, 0))
	roof.scale = Vector3(1.0, 1.0, 0.36)
	for k in int((ln - 2.0) / 1.4):
		B.mesh(n, B.boxm(Vector3(2.6, 0.04, 0.05)), Vector3(0, 4.36, -(ln - 2.0) / 2.0 + k * 1.4), COACH_ROOF.darkened(0.12))  # kattoripa
	for zs: float in [-1.0, 1.0]:
		B.mesh(n, B.boxm(Vector3(1.6, 2.3, 0.5)), Vector3(0, 2.5, zs * (ln / 2.0 - 0.15)), Color(0.12, 0.12, 0.12))  # palkeet
		_buffers(n, zs * (ln / 2.0 - 0.3), zs)
		for sx: float in [-1.0, 1.0]:
			B.mesh(n, B.boxm(Vector3(0.05, 2.15, 0.95)), Vector3(sx * 1.56, 2.4, zs * (ln / 2.0 - 1.6)), COACH_BLUE.darkened(0.25))
			B.mesh(n, B.boxm(Vector3(0.06, 0.55, 0.5)), Vector3(sx * 1.57, 3.0, zs * (ln / 2.0 - 1.6)), GLASS)
	var win := Color(1.0, 0.86, 0.6) if dining else GLASS
	var wins := int((ln - 5.0) / 1.25)
	for sx: float in [-1.0, 1.0]:
		for k in wins:
			var z := -(ln - 5.0) / 2.0 + 0.62 + k * 1.25
			var g := B.mesh(n, B.boxm(Vector3(0.05, 0.75, 0.95)), Vector3(sx * 1.56, 3.0, z), win)
			if dining:
				g.material_override = B.unshaded(win.darkened(0.15))
			B.mesh(n, B.boxm(Vector3(0.04, 0.85, 1.05)), Vector3(sx * 1.555, 3.0, z), Color(0.7, 0.72, 0.74))  # kehys
		var txt := B.label(n, "RAVINTOLA" if dining else "VR", Vector3(sx * 1.58, 2.05, 0), 70, VR_WHITE)
		txt.rotation.y = sx * PI / 2.0


# --- Teräsristikkosilta (Oulujoen ratasilta; vaala.gd ja junamatkan välikuva) ---------------------------------

## Valokuvan mukainen läpiajettava teräsristikko: jänteet n. 28 m, yläpaarre puolisuunnikas (vinot päätysauvat,
## keskellä korkeampi), vinosauvat ja pystysauvat, yläsiteet ristiin, kannen poikkipalkit ja huoltokäytävän
## kaide; jänteiden välissä ja päissä massiiviset betonipilarit veteen (pohja water_level - 2,5). a ja b kiskojen
## tasossa.
const TRUSS_W := 5.2     # ristikoiden väli
const TRUSS_SPAN := 28.0
const TRUSS_H0 := 4.6    # ristikon korkeus päätysauvan yläpäässä
const TRUSS_H1 := 6.2    # keskellä


static func build_truss(parent: Node3D, a: Vector3, b: Vector3, water_level: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := flat.length()
	var u := flat / length
	var side := u.cross(Vector3.UP)
	var spans := maxi(1, roundi(length / TRUSS_SPAN))
	var sl := length / spans
	var base := func(t: float) -> Vector3:  # kannen alapaarteen taso kohdassa t (0..length)
		return a.lerp(b, t / length) + Vector3(0, -0.45, 0)
	for k in spans:
		var t0 := k * sl
		var panels := maxi(4, roundi(sl / 4.6))
		var pl := sl / panels
		for sd: float in [-1.0, 1.0]:
			var off := side * sd * TRUSS_W / 2.0
			var bot := func(i: int) -> Vector3: return base.call(t0 + i * pl) + off
			var top := func(i: int) -> Vector3:
				var f := float(i) / panels
				return base.call(t0 + i * pl) + off + Vector3(0, lerpf(TRUSS_H0, TRUSS_H1, sin(f * PI)), 0)
			for i in panels:
				_beam(st, bot.call(i), bot.call(i + 1), 0.5, 0.6)  # alapaarre
			for i in range(1, panels - 1):
				_beam(st, top.call(i), top.call(i + 1), 0.55, 0.5)  # yläpaarre
			_beam(st, bot.call(0), top.call(1), 0.5, 0.5)  # vinot päätysauvat
			_beam(st, bot.call(panels), top.call(panels - 1), 0.5, 0.5)
			for i in range(1, panels):
				_beam(st, bot.call(i), top.call(i), 0.28, 0.3)  # pystysauvat
				if i < panels - 1:
					# Vinosauvat V-muodossa keskeltä päihin päin.
					if i < panels / 2:
						_beam(st, top.call(i), bot.call(i + 1), 0.3, 0.32)
					else:
						_beam(st, bot.call(i), top.call(i + 1), 0.3, 0.32)
			if panels % 2 == 1:
				_beam(st, top.call(panels / 2), bot.call(panels / 2 + 1), 0.3, 0.32)
			# Huoltokäytävän kaide ristikon ulkopuolella.
			var ho := side * sd * 0.7
			for i in panels:
				_beam(st, bot.call(i) + ho + Vector3(0, 1.1, 0), bot.call(i + 1) + ho + Vector3(0, 1.1, 0), 0.06, 0.06)
				_beam(st, bot.call(i) + ho, bot.call(i) + ho + Vector3(0, 1.1, 0), 0.07, 0.07)
		# Poikkipalkit kannen alla ja yläsiteet ristiin.
		for i in range(panels + 1):
			var c: Vector3 = base.call(t0 + i * pl)
			_beam(st, c - side * TRUSS_W / 2.0 - side * 0.7, c + side * TRUSS_W / 2.0 + side * 0.7, 0.4, 0.5)
		for i in range(1, panels - 1):
			var f0 := float(i) / panels
			var f1 := float(i + 1) / panels
			var c0: Vector3 = base.call(t0 + i * pl) + Vector3(0, lerpf(TRUSS_H0, TRUSS_H1, sin(f0 * PI)), 0)
			var c1: Vector3 = base.call(t0 + (i + 1) * pl) + Vector3(0, lerpf(TRUSS_H0, TRUSS_H1, sin(f1 * PI)), 0)
			var hw := side * TRUSS_W / 2.0
			_beam(st, c0 - hw, c0 + hw, 0.25, 0.25)
			_beam(st, c0 - hw, c1 + hw, 0.15, 0.15)
			_beam(st, c0 + hw, c1 - hw, 0.15, 0.15)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var tm := B.mat(Color(0.33, 0.28, 0.25)).duplicate() as StandardMaterial3D
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = tm
	parent.add_child(mi)
	# Kansi (huoltokäytävät ja ratapölkkyjen alusta) ja betonipilarit jänteiden päihin.
	var dm := B.mesh(parent, B.boxm(Vector3(TRUSS_W + 1.6, 0.25, length)), (a + b) / 2.0 + Vector3(0, -0.3, 0), Color(0.3, 0.29, 0.27))
	dm.basis = Basis.looking_at(u, Vector3.UP)
	for k in spans + 1:
		var c: Vector3 = base.call(k * sl)
		var bottom := water_level - 2.5
		var ph := c.y - 0.3 - bottom
		var pm := B.mesh(parent, B.boxm(Vector3(TRUSS_W + 2.2, ph, 2.6)), Vector3(c.x, bottom + ph / 2.0, c.z), Color(0.62, 0.61, 0.58))
		pm.basis = Basis.looking_at(u, Vector3.UP)
		var cap := B.mesh(parent, B.boxm(Vector3(TRUSS_W + 2.8, 0.5, 3.2)), Vector3(c.x, c.y - 0.55, c.z), Color(0.68, 0.67, 0.64))
		cap.basis = Basis.looking_at(u, Vector3.UP)


## Suorakulmainen palkki pisteestä a pisteeseen b (leveys w vaakaan, korkeus hgt).
static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, w: float, hgt: float) -> void:
	var d := (b - a).normalized()
	var ref := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	var x := d.cross(ref).normalized() * w / 2.0
	var y := x.cross(d).normalized() * hgt / 2.0
	var c := [a - x - y, a + x - y, a + x + y, a - x + y, b - x - y, b + x - y, b + x + y, b - x + y]
	for f in [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [3, 2, 1, 0], [4, 5, 6, 7]]:
		for v in [c[f[0]], c[f[1]], c[f[2]], c[f[0]], c[f[2]], c[f[3]]]:
			st.add_vertex(v)
