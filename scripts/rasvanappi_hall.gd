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
## Naisen olohuone (kolmiomittaus.gd): olohuone = true, floor = parketti, wall = tapetti, sofa = sohvan kangas,
## rug = matto. Tyhjä = makasiinin takahuone.
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
	if style.get("olohuone", false):
		crack.light_color = Color(1.0, 0.85, 0.6)  # eteisen lamppu, ei ULOS-valoa
		set_lit(1.0)
		return
	var exit := OmniLight3D.new()  # ULOS-valon vihreä hehku
	exit.light_color = Color(0.3, 1.0, 0.45)
	exit.light_energy = 0.5
	exit.omni_range = 1.3
	exit.position = Vector3(0.3, 2.2, door_y)
	add_child(exit)
	set_lit(1.0)


func _build_room(obst: Array) -> void:
	if style.get("olohuone", false):
		_build_living(obst)
		return
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


## Naisen olohuone (kolmiomittaus.gd): samat esteet huonekaluina. Penkki = TV-taso (vaatteet sen päällä), lavapino =
## piano ja jakkara, laatikot = kirjahylly ja takka, patjapino = ruokapöytä tuoleineen, sohva = sohva, lava =
## puuarkku, pilarit = jalkalamppu ja viherkasvi, jakkara = rahi ja kermavaahto. Takaseinällä ikkuna verhoineen,
## vasemmalla eteisen ovi (valo raosta). Sohva katsoo televisioon (-Z = taaksepäin).
func _build_living(obst: Array) -> void:
	var wood: Color = style.get("floor", Color(0.62, 0.46, 0.3))
	var wall: Color = style.get("wall", Color(0.8, 0.72, 0.6))
	var fabric: Color = style.get("sofa", Color(0.36, 0.42, 0.3))
	var rug: Color = style.get("rug", Color(0.6, 0.22, 0.2))
	var white := Color(0.93, 0.92, 0.88)
	var p := Makasiini.Parts.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Parketti: kalanruoto-tyyliset lyhyet sauvat vuorotellen eri sävyin.
	p.box(Vector3(room.x + 0.4, 0.1, room.y + 0.4), Vector3(room.x / 2.0, -0.05, room.y / 2.0), wood)
	for i in int(room.y / 0.14):
		var z := (i + 0.5) * 0.14
		var x := -0.6 * (i % 2)
		while x < room.x:
			var l := minf(1.2, room.x - maxf(x, 0.0))
			var x0 := maxf(x, 0.0)
			p.box(Vector3(l - 0.01, 0.003, 0.13), Vector3(x0 + l / 2.0, 0.0015, z), wood.darkened(rng.randf_range(-0.06, 0.12)))
			x += 1.2
	# Matto keskellä: reunus, kenttä ja kuvio.
	var rc := Vector3(6.0, 0.0, 3.6)
	p.box(Vector3(5.4, 0.012, 3.4), rc + Vector3(0, 0.006, 0), rug.darkened(0.35))
	p.box(Vector3(5.1, 0.014, 3.1), rc + Vector3(0, 0.007, 0), rug)
	p.box(Vector3(4.5, 0.016, 2.5), rc + Vector3(0, 0.008, 0), rug.lightened(0.15))
	for k in 5:
		p.box(Vector3(0.32, 0.018, 0.32), rc + Vector3((k - 2) * 0.9, 0.009, 0), rug.darkened(0.25), Basis(Vector3.UP, PI / 4.0))
	for k in 18:  # hapsut päädyissä
		for sx in [-1.0, 1.0]:
			p.box(Vector3(0.12, 0.006, 0.03), rc + Vector3(sx * 2.76, 0.004, -1.6 + k * 3.2 / 17.0), white.darkened(0.1))
	# Seinät: tapetti pystyraidoin, valkoinen jalkalista; edessä matala (kamera näkee yli), vasemmalla eteisen ovi.
	p.box(Vector3(room.x + 0.32, WALL_H, 0.16), Vector3(room.x / 2.0, WALL_H / 2.0, -0.08), wall)
	p.box(Vector3(0.16, WALL_H, room.y), Vector3(room.x + 0.08, WALL_H / 2.0, room.y / 2.0), wall)
	p.box(Vector3(room.x + 0.32, 0.45, 0.16), Vector3(room.x / 2.0, 0.225, room.y + 0.08), wall)
	var d0 := door_y - 0.5
	var d1 := door_y + 0.5
	p.box(Vector3(0.16, WALL_H, d0), Vector3(-0.08, WALL_H / 2.0, d0 / 2.0), wall)
	p.box(Vector3(0.16, WALL_H, room.y - d1), Vector3(-0.08, WALL_H / 2.0, (d1 + room.y) / 2.0), wall)
	p.box(Vector3(0.16, WALL_H - 2.1, 1.0), Vector3(-0.08, 2.1 + (WALL_H - 2.1) / 2.0, door_y), wall)
	for i in int(room.x / 0.3):
		p.box(Vector3(0.1, WALL_H - 0.1, 0.004), Vector3(0.15 + i * 0.3, WALL_H / 2.0 + 0.05, 0.002), wall.darkened(0.08))
	for i in int(room.y / 0.3):
		p.box(Vector3(0.004, WALL_H - 0.1, 0.1), Vector3(room.x - 0.002, WALL_H / 2.0 + 0.05, 0.15 + i * 0.3), wall.darkened(0.08))
	p.box(Vector3(room.x, 0.09, 0.025), Vector3(room.x / 2.0, 0.045, 0.012), white)
	p.box(Vector3(0.025, 0.09, room.y), Vector3(room.x - 0.012, 0.045, room.y / 2.0), white)
	p.box(Vector3(room.x, 0.06, 0.02), Vector3(room.x / 2.0, 0.42, room.y - 0.01), white)
	# Eteisen ovi: valkoinen peiliovi raollaan, karmit ja messinkikahva.
	for sz in [-1.0, 1.0]:
		p.box(Vector3(0.05, 2.12, 0.07), Vector3(0.02, 1.06, door_y + sz * 0.52), white)
	p.box(Vector3(0.05, 0.07, 1.1), Vector3(0.02, 2.13, door_y), white)
	var leaf := Basis(Vector3.UP, 0.35)
	var hinge := Vector3(0.0, 0, door_y + 0.47)
	var lc := hinge + leaf * Vector3(0.0, 0, -0.46)
	p.box(Vector3(0.04, 2.04, 0.9), lc + Vector3(0.04, 1.03, 0), white.darkened(0.05), leaf)
	for py in [0.55, 1.5]:
		p.box(Vector3(0.012, 0.6, 0.6), lc + Vector3(0.065, py, 0) + leaf * Vector3(0.01, 0, 0), white.darkened(0.12), leaf)
	p.ball(0.03, lc + leaf * Vector3(0.07, 0, -0.36) + Vector3(0.04, 1.0, 0), Color(0.8, 0.65, 0.3))
	# Ikkuna takaseinällä: valkoiset puitteet, sininen yö, verhot ja ikkunalauta.
	var wx := 7.9
	p.box(Vector3(1.7, 1.25, 0.02), Vector3(wx, 1.5, 0.005), Color(0.1, 0.14, 0.28))
	for k in 3:
		p.box(Vector3(0.06, 1.3, 0.05), Vector3(wx - 0.85 + k * 0.85, 1.5, 0.02), white)
	for yy in [0.86, 1.5, 2.14]:
		p.box(Vector3(1.76, 0.06, 0.05), Vector3(wx, yy, 0.02), white)
	p.box(Vector3(1.9, 0.04, 0.2), Vector3(wx, 0.84, 0.1), white)
	p.box(Vector3(2.6, 0.04, 0.04), Vector3(wx, 2.32, 0.1), Color(0.55, 0.4, 0.25))
	for sx in [-1.0, 1.0]:  # verhot laskoksina
		for k in 5:
			p.box(Vector3(0.09, 1.9, 0.07), Vector3(wx + sx * (0.95 + k * 0.08), 1.32, 0.11 + (k % 2) * 0.03),
				fabric.lightened(0.25).darkened((k % 2) * 0.12))
	p.cyl(0.07, 0.12, Vector3(wx - 0.5, 0.92, 0.1), Color(0.75, 0.4, 0.25))  # ikkunalaudan kukka
	p.ball(0.11, Vector3(wx - 0.5, 1.06, 0.1), Color(0.2, 0.45, 0.22), Vector3(1, 0.8, 1))
	# Taulut oikealla seinällä: kehys ja maisema.
	for t in [[1.4, Color(0.35, 0.55, 0.75)], [3.6, Color(0.75, 0.55, 0.3)]]:
		var tz: float = t[0]
		p.box(Vector3(0.04, 0.7, 0.95), Vector3(room.x - 0.02, 1.55, tz), Color(0.6, 0.45, 0.2))
		p.box(Vector3(0.045, 0.56, 0.81), Vector3(room.x - 0.025, 1.55, tz), t[1])
		p.box(Vector3(0.05, 0.2, 0.81), Vector3(room.x - 0.028, 1.37, tz), Color(0.25, 0.42, 0.22))
	# TV-taso (penkki): matala lipasto, laatikot ja nupit; televisio, kaiuttimet ja vaatepinot.
	var tv: Rect2 = obst[0]
	var tc := Vector3(tv.get_center().x, 0, tv.get_center().y)
	var oak := Color(0.6, 0.44, 0.27)
	p.box(Vector3(tv.size.x, 0.48, tv.size.y), tc + Vector3(0, 0.26, 0), oak)
	p.box(Vector3(tv.size.x + 0.04, 0.03, tv.size.y + 0.03), tc + Vector3(0, 0.515, 0), oak.lightened(0.1))
	for k in 4:
		var dx := (k - 1.5) * tv.size.x / 4.0
		p.box(Vector3(tv.size.x / 4.0 - 0.04, 0.36, 0.01), tc + Vector3(dx, 0.26, tv.size.y / 2.0 + 0.003), oak.darkened(0.12))
		p.ball(0.018, tc + Vector3(dx, 0.36, tv.size.y / 2.0 + 0.02), Color(0.75, 0.6, 0.3))
	for sx in [-1.0, 1.0]:
		p.box(Vector3(0.05, 0.04, 0.05), tc + Vector3(sx * (tv.size.x / 2.0 - 0.06), 0.02, 0), oak.darkened(0.3))
	var tvx := tv.position.x + 0.95
	p.box(Vector3(1.2, 0.7, 0.05), Vector3(tvx, 0.98, tc.z - 0.05), Color(0.05, 0.05, 0.06))
	p.box(Vector3(1.12, 0.63, 0.01), Vector3(tvx, 0.98, tc.z - 0.02), Color(0.08, 0.1, 0.14))
	p.box(Vector3(0.3, 0.02, 0.2), Vector3(tvx, 0.54, tc.z - 0.03), Color(0.1, 0.1, 0.1))
	p.box(Vector3(0.05, 0.1, 0.05), Vector3(tvx, 0.6, tc.z - 0.06), Color(0.1, 0.1, 0.1))
	for sx in [-0.78, 0.78]:
		p.box(Vector3(0.2, 0.38, 0.2), Vector3(tvx + sx, 0.72, tc.z), Color(0.2, 0.14, 0.1))
		p.cyl(0.06, 0.01, Vector3(tvx + sx, 0.77, tc.z + 0.1), Color(0.08, 0.08, 0.08), Basis(Vector3.RIGHT, PI / 2.0))
	var piles := [Color(0.25, 0.32, 0.55), Color(0.8, 0.45, 0.6), Color(0.85, 0.82, 0.7)]
	for i in piles.size():
		var c := Vector3(tv.position.x + 2.15 + i * 0.4, 0.53, tc.z)
		for j in 3:
			p.box(Vector3(0.34 - j * 0.03, 0.05, 0.3 - j * 0.03), c + Vector3(rng.randf_range(-0.02, 0.02), 0.025 + j * 0.05, 0),
				(piles[i] as Color).darkened(j * 0.08))
	# Piano (lavapino) ja pianojakkara.
	var pr: Rect2 = obst[1]
	var px := pr.get_center().x
	var black := Color(0.06, 0.05, 0.05)
	p.box(Vector3(1.5, 1.2, 0.55), Vector3(px, 0.6, pr.position.y + 0.3), black)
	p.box(Vector3(1.4, 0.06, 0.28), Vector3(px, 0.74, pr.position.y + 0.68), black)
	p.box(Vector3(1.3, 0.025, 0.16), Vector3(px, 0.78, pr.position.y + 0.7), white)
	for k in 26:
		if k % 7 in [0, 3]:
			continue
		p.box(Vector3(0.024, 0.02, 0.09), Vector3(px - 0.63 + k * 0.05, 0.8, pr.position.y + 0.66), black)
	for sx in [-0.7, 0.7]:
		p.box(Vector3(0.08, 0.74, 0.3), Vector3(px + sx, 0.37, pr.position.y + 0.68), black)
	p.box(Vector3(0.2, 0.25, 0.02), Vector3(px, 1.0, pr.position.y + 0.58), white.darkened(0.05), Basis(Vector3.RIGHT, -0.25))
	p.cyl(0.05, 0.12, Vector3(px + 0.5, 1.26, pr.position.y + 0.3), Color(0.85, 0.82, 0.75))  # kynttilä
	p.box(Vector3(0.6, 0.06, 0.32), Vector3(px, 0.47, pr.end.y - 0.2), black)
	for sx in [-0.26, 0.26]:
		for sz in [-0.12, 0.12]:
			p.box(Vector3(0.04, 0.44, 0.04), Vector3(px + sx, 0.22, pr.end.y - 0.2 + sz), black)
	# Kirjahylly takaseinää vasten (laatikot): hyllyt ja kirjojen selät.
	var br: Rect2 = obst[2]
	var bz := br.position.y + 0.2
	p.box(Vector3(br.size.x, 2.1, 0.04), Vector3(br.get_center().x, 1.05, br.position.y + 0.02), oak.darkened(0.15))
	for sx in [-1.0, 1.0]:
		p.box(Vector3(0.04, 2.1, 0.4), Vector3(br.get_center().x + sx * (br.size.x / 2.0 - 0.02), 1.05, bz), oak)
	for k in 6:
		var sy := 0.05 + k * 0.4
		p.box(Vector3(br.size.x, 0.03, 0.4), Vector3(br.get_center().x, sy, bz), oak)
		if k == 5:
			break
		var bx := br.position.x + 0.06
		while bx < br.end.x - 0.1:
			var bw := rng.randf_range(0.03, 0.07)
			var bh := rng.randf_range(0.22, 0.33)
			var col := Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.7), rng.randf_range(0.35, 0.75))
			p.box(Vector3(bw, bh, 0.26), Vector3(bx + bw / 2.0, sy + 0.015 + bh / 2.0, bz - 0.02), col)
			bx += bw + 0.005
	# Varaava takka nurkassa (laatikko 2): rapattu runko, musta luukku ja hiilloksen hehku.
	var fr: Rect2 = obst[3]
	var fc := Vector3(fr.get_center().x, 0, fr.get_center().y)
	p.box(Vector3(fr.size.x, 1.7, fr.size.y), fc + Vector3(0, 0.85, 0), white.darkened(0.04))
	p.box(Vector3(fr.size.x + 0.06, 0.06, fr.size.y + 0.06), fc + Vector3(0, 1.72, 0), white.darkened(0.1))
	p.box(Vector3(fr.size.x + 0.06, 0.12, fr.size.y + 0.06), fc + Vector3(0, 0.06, 0), Color(0.3, 0.3, 0.32))
	p.box(Vector3(0.02, 0.4, 0.46), fc + Vector3(-fr.size.x / 2.0 - 0.005, 0.5, 0), black)
	p.box(Vector3(0.02, 0.3, 0.36), fc + Vector3(-fr.size.x / 2.0 - 0.012, 0.5, 0), Color(0.75, 0.3, 0.08))
	p.box(Vector3(0.025, 0.04, 0.2), fc + Vector3(-fr.size.x / 2.0 - 0.02, 0.74, 0), Color(0.3, 0.3, 0.3))
	for k in 3:  # halkoja vieressä
		p.cyl(0.05, 0.4, fc + Vector3(-fr.size.x / 2.0 - 0.15, 0.05 + k * 0.08, fr.size.y / 2.0 - 0.1 - (k % 2) * 0.1),
			Color(0.55, 0.42, 0.3), Basis(Vector3.FORWARD, PI / 2.0))
	# Ruokapöytä (patjapino): pöytälevy, jalat, liina ja neljä tuolia.
	var dr: Rect2 = obst[4]
	var dc := Vector3(dr.get_center().x, 0, dr.get_center().y)
	p.box(Vector3(1.6, 0.05, 0.9), dc + Vector3(0, 0.74, 0), oak)
	for sx in [-0.72, 0.72]:
		for sz in [-0.38, 0.38]:
			p.box(Vector3(0.06, 0.72, 0.06), dc + Vector3(sx, 0.36, sz), oak.darkened(0.15))
	p.box(Vector3(0.5, 0.004, 0.94), dc + Vector3(0, 0.767, 0), white)
	p.cyl(0.1, 0.02, dc + Vector3(0, 0.78, 0), Color(0.7, 0.72, 0.75))
	for k in 3:
		p.ball(0.03, dc + Vector3(-0.04 + k * 0.04, 0.81, (k % 2) * 0.03), Color(0.85, 0.15, 0.2))
	for t in [[-0.95, 0.0, PI / 2.0], [0.95, 0.0, -PI / 2.0], [-0.4, 0.62, PI], [0.4, -0.62, 0.0]]:
		var cb := Basis(Vector3.UP, t[2])
		var cc: Vector3 = dc + Vector3(t[0], 0, t[1])
		p.box(Vector3(0.42, 0.04, 0.42), cc + Vector3(0, 0.45, 0), oak.darkened(0.05), cb)
		p.box(Vector3(0.42, 0.45, 0.04), cc + cb * Vector3(0, 0, 0.19) + Vector3(0, 0.7, 0), oak.darkened(0.05), cb)
		for sx in [-0.18, 0.18]:
			for sz in [-0.18, 0.18]:
				p.box(Vector3(0.035, 0.45, 0.035), cc + cb * Vector3(sx, 0, sz) + Vector3(0, 0.225, 0), oak.darkened(0.2), cb)
	# Sohva etuseinää vasten (kasvot -Z, televisioon): runko, selkä, käsinojat, tyynyt ja viltti.
	var so: Rect2 = obst[5]
	var sc := Vector3(so.get_center().x, 0, so.get_center().y)
	p.box(Vector3(so.size.x, 0.4, so.size.y), sc + Vector3(0, 0.22, 0), fabric)
	p.box(Vector3(so.size.x, 0.45, 0.2), sc + Vector3(0, 0.62, so.size.y / 2.0 - 0.1), fabric.darkened(0.1))
	for sx in [-1.0, 1.0]:
		p.box(Vector3(0.18, 0.58, so.size.y), sc + Vector3(sx * (so.size.x / 2.0 - 0.09), 0.29, 0), fabric.darkened(0.15))
		p.box(Vector3(0.05, 0.06, 0.05), sc + Vector3(sx * (so.size.x / 2.0 - 0.06), 0.02, so.size.y / 2.0 - 0.06), oak.darkened(0.3))
	for k in 3:
		p.box(Vector3(so.size.x / 3.0 - 0.14, 0.12, so.size.y - 0.26), sc + Vector3((k - 1) * (so.size.x - 0.36) / 3.0, 0.48, -0.06),
			fabric.lightened(0.1))
	p.box(Vector3(0.36, 0.32, 0.12), sc + Vector3(-so.size.x / 2.0 + 0.4, 0.66, 0.12), rug.lightened(0.2), Basis(Vector3.FORWARD, 0.2))
	p.box(Vector3(0.6, 0.03, so.size.y - 0.2), sc + Vector3(so.size.x / 2.0 - 0.5, 0.55, -0.03), Color(0.85, 0.75, 0.55))
	# Puuarkku (lava): matala, ettei peitä esittelyriviä; raudoitukset, lukko ja viltti kannella.
	var ar: Rect2 = obst[6]
	var ac := Vector3(ar.get_center().x, 0, ar.get_center().y)
	p.box(Vector3(ar.size.x, 0.4, ar.size.y - 0.1), ac + Vector3(0, 0.2, 0), oak.darkened(0.2))
	p.box(Vector3(ar.size.x + 0.03, 0.07, ar.size.y - 0.07), ac + Vector3(0, 0.43, 0), oak.darkened(0.1))
	for sx in [-0.4, 0.4]:
		p.box(Vector3(0.06, 0.48, ar.size.y - 0.06), ac + Vector3(sx * ar.size.x, 0.235, 0), Color(0.18, 0.17, 0.16))
	p.box(Vector3(0.1, 0.12, 0.02), ac + Vector3(0, 0.36, -ar.size.y / 2.0 + 0.04), Color(0.7, 0.6, 0.3))
	p.box(Vector3(0.7, 0.035, ar.size.y - 0.04), ac + Vector3(0.1, 0.48, 0), rug.lightened(0.25))
	# Jalkalamppu (pilari 1): jalka, varsi ja kangasvarjostin.
	var l1: Rect2 = obst[7]
	var lc1 := Vector3(l1.get_center().x, 0, l1.get_center().y)
	p.cyl(0.15, 0.03, lc1 + Vector3(0, 0.015, 0), Color(0.2, 0.2, 0.2))
	p.cyl(0.015, 1.5, lc1 + Vector3(0, 0.78, 0), Color(0.75, 0.62, 0.35))
	p.cyl(0.2, 0.3, lc1 + Vector3(0, 1.6, 0), Color(0.95, 0.88, 0.7))
	# Viherkasvi (pilari 2): ruukku ja lehtipallot.
	var l2: Rect2 = obst[8]
	var lc2 := Vector3(l2.get_center().x, 0, l2.get_center().y)
	p.cyl(0.15, 0.36, lc2 + Vector3(0, 0.18, 0), Color(0.72, 0.42, 0.28))
	p.cyl(0.16, 0.04, lc2 + Vector3(0, 0.36, 0), Color(0.62, 0.36, 0.24))
	p.cyl(0.02, 0.6, lc2 + Vector3(0, 0.65, 0), Color(0.4, 0.3, 0.2))
	for k in 9:
		var a := k * TAU / 9.0
		var h := 0.95 + (k % 3) * 0.2
		p.ball(0.16, lc2 + Vector3(cos(a) * 0.17, h, sin(a) * 0.17), Color(0.2, 0.48 + (k % 3) * 0.06, 0.24), Vector3(1.2, 0.5, 1.2))
	# Rahi ja kermavaahtopullo (jakkara ovensuussa).
	var st: Rect2 = obst[9]
	var stc := Vector3(st.get_center().x, 0, st.get_center().y)
	p.cyl(0.25, 0.38, stc + Vector3(0, 0.19, 0), rug.darkened(0.1))
	p.cyl(0.255, 0.04, stc + Vector3(0, 0.38, 0), rug.darkened(0.25))
	p.cyl(0.035, 0.2, stc + Vector3(0.05, 0.5, 0), Color(0.95, 0.95, 0.97))
	p.cyl(0.036, 0.05, stc + Vector3(0.05, 0.43, 0), Color(0.2, 0.45, 0.8))
	p.cyl(0.012, 0.05, stc + Vector3(0.05, 0.625, 0), Color(0.95, 0.95, 0.97))
	p.cyl(0.07, 0.04, stc + Vector3(-0.1, 0.4, 0.06), Color(0.85, 0.15, 0.2))  # mansikkakulho
	p.commit(self)
	# Kuunvalo ikkunasta ja eteisen valo ovenraosta.
	var moon := OmniLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.6
	moon.omni_range = 2.5
	moon.position = Vector3(wx, 1.4, 0.5)
	add_child(moon)
