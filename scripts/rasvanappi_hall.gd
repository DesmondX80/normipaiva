extends Node3D
## Rasvanapin halli 3D:nä (rasvanappi_game.gd): makasiinin takahuone ylhäältä viistosti, katto pois. Pelin 2D-metrit
## (x 0..12, y 0..7) ovat hallin paikallisia X ja Z, lattia y = 0. Esteet samoista suorakaiteista kuin pelin
## törmäykset (OBST). Pimeys on oikeaa valaistusta: hallin geometria on omalla näkyvyyskerroksellaan (LAYER), jolta
## maailman aurinko rajataan pois, kameralla on oma ympäristö ilman ympäristövaloa, ja pelaajan ympärillä on himmeä
## "silmät tottuneet" -valo. Kattolamppu palaa esittelyn jälkeen hetken ja lopussa (set_lit).

const Makasiini := preload("res://scripts/makasiini.gd")
const Crawler := preload("res://scripts/crawler3d.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

const LAYER := 1 << 19  # näkyvyyskerros 20: vain hallin kamera ja valot
const WALL_H := 2.6
const LINE_Z := 4.4  # esittelyrivi

var room := Vector2(12, 7)
var door_y := 3.5
## Värit (kolmiomittaus.gd: naisen olohuone): floor = lattia, wall = seinät. Tyhjä = makasiinin takahuone.
var style := {}
var crawlers: Array = []  # Crawler, pelaajan konttaaja viimeisenä
var cam: Camera3D  # pelin kamera ylhäältä viistosti
var line_cam: Camera3D  # esittely edestä
var _sun: DirectionalLight3D
var _sun_mask := 0
var _ceiling: OmniLight3D
var _bulb_mat: StandardMaterial3D
var _sight: OmniLight3D
var _env: Environment


## obst: esteet (Rect2, m), looks: [{look, towel, woman}] (pelaaja viimeisenä), bouncer: portsarin ulkonäkö (tyhjä = ei
## portsaria, esim. naisen olohuoneessa).
func build(obst: Array, looks: Array, bouncer: Dictionary, sun: DirectionalLight3D) -> void:
	_sun = sun
	if _sun != null:
		_sun_mask = _sun.light_cull_mask
		_sun.light_cull_mask = _sun_mask & ~LAYER
	_build_room(obst)
	for lk: Dictionary in looks:
		var c := Crawler.new()
		add_child(c)
		c.setup(lk.look, lk.towel, lk.woman)
		crawlers.append(c)
	if not bouncer.is_empty():
		var b := Looks.make(self, bouncer)
		b.position = Vector3(0.75, 0, door_y - 1.0)
		b.rotation.y = -PI / 2.0  # katsoo halliin (+X)
		b.play("Idle")
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.0, 0.0, 0.0)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.5, 0.55, 0.7)
	_env.ambient_light_energy = 0.0
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	_env.glow_hdr_threshold = 1.3
	_build_lights()
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.cull_mask = LAYER
	cam.environment = _env
	add_child(cam)
	var eye := Vector3(room.x / 2.0, 10.6, room.y + 4.6)
	cam.transform = Transform3D(Basis.looking_at(Vector3(room.x / 2.0, 0, room.y / 2.0 + 0.25) - eye, Vector3.UP), eye)
	line_cam = Camera3D.new()
	line_cam.fov = 48.0
	line_cam.cull_mask = LAYER
	line_cam.environment = _env
	add_child(line_cam)
	var le := Vector3(room.x / 2.0, 1.5, room.y + 2.6)
	line_cam.transform = Transform3D(Basis.looking_at(Vector3(room.x / 2.0, 1.05, LINE_Z) - le, Vector3.UP), le)
	_set_layers(self)


func _exit_tree() -> void:
	if _sun != null and is_instance_valid(_sun):
		_sun.light_cull_mask = _sun_mask


func _set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = LAYER
	if n is Light3D:
		(n as Light3D).light_cull_mask = LAYER
	for c in n.get_children():
		_set_layers(c)


## Kattolamppu 0..1 (0 = pimeä halli: vain ovenrako, ULOS-valo ja pelaajan ympäristö).
func set_lit(v: float) -> void:
	_ceiling.light_energy = 2.6 * v
	_bulb_mat.emission_energy_multiplier = 0.2 + 5.0 * v
	_env.ambient_light_energy = 0.5 * v
	_sight.light_energy = 0.9 * (1.0 - v)


## Pelaajan näkövalo (silmät tottuneet pimeään): säde metreinä.
func set_sight(p: Vector2, radius: float) -> void:
	_sight.position = Vector3(p.x, 1.3, p.y)
	_sight.omni_range = radius + 0.4


func w2s(p: Vector2, h := 0.4) -> Vector2:
	return cam.unproject_position(to_global(Vector3(p.x, h, p.y)))


## Pikseliä metrillä hallin keskellä (äänirenkaiden ja tekstien mitoitus).
func ppm() -> float:
	var c := Vector2(room.x / 2.0, room.y / 2.0)
	return w2s(c, 0.0).distance_to(w2s(c + Vector2(1, 0), 0.0))


## Esittely: pelaajat seisovat rivissä hallin keskellä kameraa kohti, oma hahmo piilossa.
func lineup() -> void:
	for i in crawlers.size():
		var c: Node3D = crawlers[i]
		c.set_stance("stand")
		c.disguise(false)
		c.visible = i < crawlers.size() - 1
		c.position = Vector3(2.9 + i * 1.55, 0, LINE_Z)
		c.rotation.y = PI  # kasvot kameraan (+Z)


## Valot pois: kaikki polvilleen konttaamaan.
func crawl_start() -> void:
	for c in crawlers:
		c.visible = true
		c.set_stance("crawl")


## Konttaaja paikalleen: p (m), ang (pelin kulma, eteen = (cos, sin)), askelvaihe ja liike.
func place(i: int, p: Vector2, ang: float, phase: float, moving: bool) -> void:
	var c: Node3D = crawlers[i]
	c.position = Vector3(p.x, 0, p.y)
	c.rotation.y = -ang - PI / 2.0
	c.pose(phase, 1.0 if moving else 0.25)


func _build_lights() -> void:
	_ceiling = OmniLight3D.new()
	_ceiling.light_color = Color(1.0, 0.85, 0.6)
	_ceiling.omni_range = 11.0
	_ceiling.omni_attenuation = 0.8
	_ceiling.shadow_enabled = true
	_ceiling.position = Vector3(room.x / 2.0 - 0.5, 2.3, room.y / 2.0)
	add_child(_ceiling)
	var bulb := MeshInstance3D.new()
	bulb.mesh = B.sphere(0.07)
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.albedo_color = Color(1.0, 0.95, 0.75)
	_bulb_mat.emission_enabled = true
	_bulb_mat.emission = Color(1.0, 0.85, 0.55)
	bulb.material_override = _bulb_mat
	bulb.position = _ceiling.position + Vector3(0, 0.1, 0)
	add_child(bulb)
	B.mesh(self, B.cyl(0.006, 0.006, 0.5), bulb.position + Vector3(0, 0.3, 0), Color(0.05, 0.05, 0.05))
	_sight = OmniLight3D.new()
	_sight.light_color = Color(0.75, 0.8, 0.95)
	_sight.omni_attenuation = 1.6
	add_child(_sight)
	var crack := OmniLight3D.new()  # ovenrako: lämmin valojuova lattiassa
	crack.light_color = Color(1.0, 0.75, 0.45)
	crack.light_energy = 0.8
	crack.omni_range = 1.4
	crack.position = Vector3(0.15, 0.1, door_y)
	add_child(crack)
	var exit := OmniLight3D.new()  # ULOS-valon vihreä hehku
	exit.light_color = Color(0.3, 1.0, 0.45)
	exit.light_energy = 0.5
	exit.omni_range = 1.3
	exit.position = Vector3(0.3, 2.2, door_y)
	add_child(exit)
	set_lit(1.0)


func _build_room(obst: Array) -> void:
	var wood: Color = style.get("floor", Color(0.4, 0.3, 0.21))
	var wall: Color = style.get("wall", Color(0.32, 0.15, 0.1))
	var p := Makasiini.Parts.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# Lattia: lankut X-suunnassa, saumat ja kuluneet laudat, öljytahroja.
	p.box(Vector3(room.x + 0.4, 0.1, room.y + 0.4), Vector3(room.x / 2.0, -0.05, room.y / 2.0), wood)
	var n := int(room.y / 0.18)
	for i in n:
		var z := (i + 0.5) * room.y / n
		p.box(Vector3(room.x, 0.004, 0.012), Vector3(room.x / 2.0, 0.002, z - room.y / n / 2.0), wood.darkened(0.35))
		if rng.randf() < 0.35:
			p.box(Vector3(room.x, 0.003, room.y / n - 0.014), Vector3(room.x / 2.0, 0.001, z), wood.darkened(rng.randf_range(0.08, 0.18)))
	for i in 6:
		p.cyl(rng.randf_range(0.12, 0.3), 0.004, Vector3(rng.randf_range(1, 11), 0.002, rng.randf_range(0.8, 6.2)), wood.darkened(0.22))
	# Seinät: taka- ja oikea seinä korkeina, edessä matala (kamera näkee yli), vasemmalla ovi.
	p.box(Vector3(room.x + 0.32, WALL_H, 0.16), Vector3(room.x / 2.0, WALL_H / 2.0, -0.08), wall)
	p.box(Vector3(0.16, WALL_H, room.y), Vector3(room.x + 0.08, WALL_H / 2.0, room.y / 2.0), wall)
	p.box(Vector3(room.x + 0.32, 0.45, 0.16), Vector3(room.x / 2.0, 0.225, room.y + 0.08), wall)
	var d0 := door_y - 0.5
	var d1 := door_y + 0.5
	p.box(Vector3(0.16, WALL_H, d0), Vector3(-0.08, WALL_H / 2.0, d0 / 2.0), wall)
	p.box(Vector3(0.16, WALL_H, room.y - d1), Vector3(-0.08, WALL_H / 2.0, (d1 + room.y) / 2.0), wall)
	p.box(Vector3(0.16, WALL_H - 2.1, 1.0), Vector3(-0.08, 2.1 + (WALL_H - 2.1) / 2.0, door_y), wall)
	for i in int(room.x / 0.45):  # peitelistat takaseinässä
		p.box(Vector3(0.06, WALL_H, 0.03), Vector3(0.2 + i * 0.45, WALL_H / 2.0, 0.015), wall.darkened(0.25))
	for i in int(room.y / 0.45):
		p.box(Vector3(0.03, WALL_H, 0.06), Vector3(room.x - 0.015, WALL_H / 2.0, 0.2 + i * 0.45), wall.darkened(0.25))
	# Takaovi sisältä: teräslevy, valorako alla.
	p.box(Vector3(0.05, 2.08, 0.98), Vector3(0.02, 1.05, door_y), Color(0.2, 0.28, 0.25))
	p.box(Vector3(0.02, 0.05, 0.08), Vector3(0.06, 1.0, door_y + 0.32), Color(0.6, 0.58, 0.52))
	# Penkki vaatteineen ja kengät alla.
	var bench: Rect2 = obst[0]
	_wood_box(p, bench, 0.42, Color(0.55, 0.4, 0.25))
	var piles := [Color(0.25, 0.32, 0.55), Color(0.3, 0.38, 0.2), Color(0.8, 0.45, 0.6), Color(0.75, 0.2, 0.2), Color(0.85, 0.82, 0.7)]
	for i in piles.size():
		var c: Vector3 = Vector3(bench.position.x + 0.35 + i * 0.62, 0.42, bench.get_center().y)
		for j in 3:  # taiteltu vaatepino
			p.box(Vector3(0.46 - j * 0.04, 0.05, 0.32 - j * 0.03), c + Vector3(rng.randf_range(-0.02, 0.02), 0.025 + j * 0.05, 0),
				(piles[i] as Color).darkened(j * 0.08))
		for sx in [-0.09, 0.09]:  # kengät penkin edessä
			p.box(Vector3(0.1, 0.09, 0.26), Vector3(c.x + sx, 0.045, bench.end.y + 0.25), Color(0.12, 0.1, 0.09))
			p.box(Vector3(0.1, 0.02, 0.27), Vector3(c.x + sx, 0.01, bench.end.y + 0.25), Color(0.75, 0.72, 0.65))
	# Lavapinot.
	for r: Rect2 in [obst[1], obst[6]]:
		var h := 0.9 if r.size.y > 1.0 else 0.45
		var layers := int(h / 0.15)
		for l in layers:
			var y := l * 0.15
			for bx in 3:
				p.box(Vector3(0.1, 0.08, r.size.y), Vector3(r.position.x + 0.05 + bx * (r.size.x - 0.1) / 2.0, y + 0.04, r.get_center().y),
					Color(0.5, 0.4, 0.27))
			for bz in 5:
				p.box(Vector3(r.size.x, 0.022, 0.12), Vector3(r.get_center().x, y + 0.091, r.position.y + 0.06 + bz * (r.size.y - 0.12) / 4.0),
					Color(0.68, 0.56, 0.38).darkened(rng.randf_range(0.0, 0.15)))
	# Varaosalaatikot: kehykset ja vinotuki.
	for r: Rect2 in [obst[2], obst[3]]:
		var h := 1.0 if r.size.x > 1.5 else 0.8
		_wood_box(p, r, h, Color(0.55, 0.42, 0.26))
		var top := Vector3(r.get_center().x, h + 0.005, r.get_center().y)
		for s in [-1.0, 1.0]:
			p.box(Vector3(r.size.x, 0.012, 0.06), top + Vector3(0, 0, s * (r.size.y / 2.0 - 0.03)), Color(0.38, 0.28, 0.17))
			p.box(Vector3(0.06, 0.012, r.size.y), top + Vector3(s * (r.size.x / 2.0 - 0.03), 0, 0), Color(0.38, 0.28, 0.17))
		p.box(Vector3(r.size.length(), 0.01, 0.06), top, Color(0.38, 0.28, 0.17), Basis(Vector3.UP, -atan2(r.size.y, r.size.x)))
	# Patjapino tahroineen.
	var m: Rect2 = obst[4]
	for j in 3:
		var c := Vector3(m.get_center().x + rng.randf_range(-0.05, 0.05), 0.09 + j * 0.18, m.get_center().y)
		p.box(Vector3(m.size.x - j * 0.03, 0.17, m.size.y - j * 0.04), c, Color(0.74, 0.7, 0.82))
		p.box(Vector3(m.size.x - j * 0.03 + 0.005, 0.02, m.size.y - j * 0.04 + 0.005), c, Color(0.55, 0.55, 0.7))
	for k in 7:
		p.box(Vector3(0.05, 0.004, m.size.y - 0.15), Vector3(m.position.x + 0.2 + k * 0.32, 0.53, m.get_center().y), Color(0.6, 0.58, 0.74))
	p.cyl(0.18, 0.004, Vector3(m.get_center().x - 0.3, 0.537, m.get_center().y + 0.15), Color(0.66, 0.6, 0.6))
	# Sohva etuseinää vasten: runko, selkä, käsinojat ja tyynyt.
	var so: Rect2 = obst[5]
	var sc := Vector3(so.get_center().x, 0, so.get_center().y)
	var brown := Color(0.42, 0.24, 0.14)
	p.box(Vector3(so.size.x, 0.4, so.size.y), sc + Vector3(0, 0.2, 0), brown)
	p.box(Vector3(so.size.x, 0.45, 0.18), sc + Vector3(0, 0.6, so.size.y / 2.0 - 0.09), brown.darkened(0.1))
	for s in [-1.0, 1.0]:
		p.box(Vector3(0.18, 0.58, so.size.y), sc + Vector3(s * (so.size.x / 2.0 - 0.09), 0.29, 0), brown.darkened(0.15))
	for k in 3:
		p.box(Vector3(so.size.x / 3.0 - 0.14, 0.12, so.size.y - 0.24), sc + Vector3((k - 1) * (so.size.x - 0.36) / 3.0, 0.46, -0.06),
			Color(0.55, 0.32, 0.2))
	# Pilarit kattoon.
	for r: Rect2 in [obst[7], obst[8]]:
		p.box(Vector3(r.size.x, WALL_H, r.size.y), Vector3(r.get_center().x, WALL_H / 2.0, r.get_center().y), Color(0.45, 0.35, 0.25))
	# Jakkara ja margariinirasia ovensuussa.
	var st: Rect2 = obst[9]
	var stc := Vector3(st.get_center().x, 0, st.get_center().y)
	p.cyl(0.22, 0.04, stc + Vector3(0, 0.43, 0), Color(0.5, 0.38, 0.25))
	for a in 3:
		var ang := a * TAU / 3.0
		p.box(Vector3(0.035, 0.42, 0.035), stc + Vector3(cos(ang) * 0.15, 0.21, sin(ang) * 0.15), Color(0.42, 0.3, 0.2))
	p.cyl(0.1, 0.08, stc + Vector3(0, 0.49, 0), Color(0.98, 0.85, 0.2))
	p.cyl(0.105, 0.015, stc + Vector3(0, 0.535, 0), Color(0.95, 0.92, 0.8))
	p.commit(self)
	# ULOS-kyltti oven yllä (valaistu levy).
	var sign := B.sign_plate(self, "ULOS", Color(0.1, 0.7, 0.3), Color(1, 1, 1), 0.2, 40, Color(0.05, 0.4, 0.15))
	sign.position = Vector3(0.03, 2.3, door_y)
	sign.rotation.y = PI / 2.0


func _wood_box(p: RefCounted, r: Rect2, h: float, col: Color) -> void:
	p.box(Vector3(r.size.x, h, r.size.y), Vector3(r.get_center().x, h / 2.0, r.get_center().y), col)
	for k in int(h / 0.15):  # laudat
		p.box(Vector3(r.size.x + 0.004, 0.008, r.size.y + 0.004), Vector3(r.get_center().x, 0.15 * (k + 1), r.get_center().y), col.darkened(0.3))
