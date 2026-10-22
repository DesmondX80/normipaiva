extends Node3D
## Tiskaus 3D:nä (kokeilu, tiski_game.gd:n rinnalle): minäkuva mökin tiskialtaan ääreltä. Astia kerrallaan altaassa:
## hankaa A/D vuorotellen (tai hiirtä edestakaisin), kunnes astia on puhdas, ja nosta se kuivaustelineeseen
## (välilyönti tai E). Humalassa märkä astia lipsahtaa ja särkyy altaan reunaan. F / Esc lopettaa kesken.
## Pelillä on oma pieni näkymä (tiskipöytä, allas, hana, välitila ja teline) omalla näkyvyyskerroksellaan, joten mökin
## karkea keittiö ei näy kameralle. Origo = altaan keskikohta työtason pinnan korkeudella, pelaaja +Z:ssa katse -Z:aan.
## Sama rajapinta kuin tiski_game.gd: dishes_left, drunk, washed, broken, signaalit finished ja comment.

signal finished(washed: int, broken: int)
signal comment(text: String)

const B := preload("res://scripts/build.gd")
const DISHES := preload("res://scripts/tiski_game.gd").DISHES
const LINES := preload("res://scripts/tiski_game.gd").LINES
const SCRUB := 0.09  # yksi veto puhdistaa
const LAYER := 1 << 19  # oma näkyvyyskerros (20)

const BASIN := Vector3(0.5, 0.18, 0.38)  # altaan sisämitat
const WATER_Y := -0.075
const DISH_AT := Vector3(0.0, -0.035, 0.02)  # pestävän astian paikka
const STEEL := Color(0.72, 0.74, 0.77)
const COUNTER := Color(0.66, 0.48, 0.3)
const TILE := Color(0.94, 0.93, 0.88)

var dishes_left := DISHES.size()
var drunk := 0.0
var washed := 0
var broken := 0

var _cam: Camera3D
var _prev_cam: Camera3D
var _dish: Node3D
var _spots: Array[StandardMaterial3D] = []
var _brush: Node3D
var _rack: Node3D
var _rack_items: Array = []
var _rack_list: Array = []  # telineeseen nostetut astiat (DISHES-rivit)
var _dirt := 1.0
var _last_dir := 0
var _wobble := 0.0
var _shake := 0.0
var _busy_t := -1.0  # nosto tai särkyminen käynnissä
var _t := 0.0
var _done := false
var _layer: CanvasLayer
var _info: Label
var _keys: Control
var _sub: Label
var _sub_t := 0.0
var _bar_fill: ColorRect
var _bar_label: Label
var _krash: Label


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	_prev_cam = get_viewport().get_camera_3d()
	_build_scene()
	_cam = Camera3D.new()
	_cam.cull_mask = LAYER
	_cam.fov = 62.0
	_cam.near = 0.03
	# Oma ympäristö: lämmin tasainen ympäristövalo ilman taivasta (mökin ympäristö värjäisi kaiken siniseksi).
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.18, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.95, 0.88)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_cam.environment = env
	add_child(_cam)
	_cam.current = true
	_build_hud()
	_new_dish()
	_rebuild_rack()
	_say(LINES.start.pick_random())


# --- Näkymä ---------------------------------------------------------------------------------------------------------

func _mesh(parent: Node3D, m: Mesh, pos: Vector3, col: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := B.mesh(parent, m, pos, col, rot)
	mi.layers = LAYER
	return mi


func _chrome() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.86, 0.88)
	m.metallic = 0.6
	m.roughness = 0.25
	return m


## Tiskipöytä: laatoitettu välitila, puinen työtaso altaan aukolla, teräsallas vesineen ja vaahtoineen, hana,
## tiskiainepullo, sieni ja kuivausteline. Oma valo, ettei mökin valaistus pimennä lähikuvaa.
func _build_scene() -> void:
	var hx := BASIN.x / 2.0 + 0.03
	var hz := BASIN.z / 2.0 + 0.03
	# Työtaso altaan ympärillä neljänä palana (aukko altaalle).
	var top_t := 0.04
	_mesh(self, B.boxm(Vector3(1.0 - hx, top_t, 0.75)), Vector3(-(1.0 + hx) / 2.0, -top_t / 2.0, 0.0), COUNTER)
	_mesh(self, B.boxm(Vector3(1.1 - hx, top_t, 0.75)), Vector3((1.1 + hx) / 2.0, -top_t / 2.0, 0.0), COUNTER)
	_mesh(self, B.boxm(Vector3(hx * 2.0, top_t, 0.375 - hz)), Vector3(0, -top_t / 2.0, -(0.375 + hz) / 2.0), COUNTER)
	_mesh(self, B.boxm(Vector3(hx * 2.0, top_t, 0.375 - hz)), Vector3(0, -top_t / 2.0, (0.375 + hz) / 2.0), COUNTER)
	for k in 9:  # puun syyt työtasossa (ei altaan aukon kohdalla)
		var gz := -0.33 + k * 0.08
		var gc := COUNTER.darkened(0.14 + 0.04 * (k % 3))
		if absf(gz) < hz:
			_mesh(self, B.boxm(Vector3(1.0 - hx, 0.001, 0.004)), Vector3(-(1.0 + hx) / 2.0, 0.0006, gz), gc)
			_mesh(self, B.boxm(Vector3(1.1 - hx, 0.001, 0.004)), Vector3((1.1 + hx) / 2.0, 0.0006, gz), gc)
		else:
			_mesh(self, B.boxm(Vector3(2.1, 0.001, 0.004)), Vector3(0.05, 0.0006, gz), gc)
	_mesh(self, B.boxm(Vector3(2.1, 0.05, 0.03)), Vector3(0.05, -0.03, 0.385), COUNTER.darkened(0.25))  # etureuna
	_mesh(self, B.boxm(Vector3(2.1, 0.6, 0.6)), Vector3(0.05, -0.52, 0.06), Color(0.93, 0.92, 0.88))  # kaapisto altaan alla
	# Välitila: saumat ja laatat.
	_mesh(self, B.boxm(Vector3(2.1, 0.75, 0.02)), Vector3(0.05, 0.37, -0.385), Color(0.62, 0.6, 0.56))
	for ix in 21:
		for iy in 7:
			var tile := _mesh(self, B.boxm(Vector3(0.094, 0.094, 0.012)), Vector3(-0.95 + ix * 0.1, 0.05 + iy * 0.1, -0.372), TILE)
			if (ix * 3 + iy * 5) % 17 == 4:  # kuviolaatta
				_mesh(self, B.cyl(0.014, 0.014, 0.002, 12), Vector3(-0.95 + ix * 0.1, 0.05 + iy * 0.1, -0.365), Color(0.35, 0.55, 0.72),
					Vector3(90, 0, 0))
			elif iy == 6:
				tile.material_override = B.mat(TILE.darkened(0.04))
	# Allas: reunalaippa, seinät, pohja ja pohjaventtiili.
	var steel_dark := STEEL.darkened(0.5)
	_mesh(self, B.boxm(Vector3(BASIN.x + 0.08, 0.008, 0.04)), Vector3(0, 0.004, -hz + 0.01), STEEL)
	_mesh(self, B.boxm(Vector3(BASIN.x + 0.08, 0.008, 0.04)), Vector3(0, 0.004, hz - 0.01), STEEL)
	_mesh(self, B.boxm(Vector3(0.04, 0.008, BASIN.z + 0.08)), Vector3(-hx + 0.01, 0.004, 0), STEEL)
	_mesh(self, B.boxm(Vector3(0.04, 0.008, BASIN.z + 0.08)), Vector3(hx - 0.01, 0.004, 0), STEEL)
	_mesh(self, B.boxm(Vector3(BASIN.x, 0.01, BASIN.z)), Vector3(0, -BASIN.y, 0), steel_dark)
	for side in [-1.0, 1.0]:
		_mesh(self, B.boxm(Vector3(BASIN.x, BASIN.y, 0.01)), Vector3(0, -BASIN.y / 2.0, side * BASIN.z / 2.0), STEEL.darkened(0.3 if side < 0 else 0.5))
		_mesh(self, B.boxm(Vector3(0.01, BASIN.y, BASIN.z)), Vector3(side * BASIN.x / 2.0, -BASIN.y / 2.0, 0), STEEL.darkened(0.4))
	_mesh(self, B.cyl(0.035, 0.035, 0.004, 16), Vector3(0.15, -BASIN.y + 0.006, -0.1), Color(0.3, 0.3, 0.32))
	# Vesi: läpikuultava pinta ja vaahtokasoja reunoilla.
	var water := _mesh(self, B.boxm(Vector3(BASIN.x - 0.004, 0.004, BASIN.z - 0.004)), Vector3(0, WATER_Y, 0), Color.WHITE)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.3, 0.47, 0.58, 0.65)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.05
	wm.metallic_specular = 0.9
	water.material_override = wm
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var foam := StandardMaterial3D.new()
	foam.albedo_color = Color(1, 1, 1, 0.8)
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for c in 9:  # vaahtokasat: pieniä kuplia ryppäinä reunoilla
		var a := c * TAU / 9.0 + rng.randf_range(-0.2, 0.2)
		var cp := Vector3(cos(a) * 0.19, WATER_Y + 0.004, sin(a) * 0.14)
		for k in 9:
			var p := cp + Vector3(rng.randf_range(-0.035, 0.035), rng.randf_range(0.0, 0.008), rng.randf_range(-0.025, 0.025))
			var b := _mesh(self, B.sphere(rng.randf_range(0.006, 0.014), 12), p, Color.WHITE)
			b.material_override = foam
			b.scale = Vector3(1, 0.7, 1)
	# Hana: jalka, pystyputki, nokka altaan päälle ja vipukahva.
	var ch := _chrome()
	var parts: Array = []
	parts.append(_mesh(self, B.cyl(0.03, 0.034, 0.03, 16), Vector3(0, 0.015, -hz - 0.03), Color.WHITE))
	parts.append(_mesh(self, B.cyl(0.014, 0.014, 0.2, 12), Vector3(0, 0.13, -hz - 0.03), Color.WHITE))
	parts.append(_mesh(self, B.cyl(0.012, 0.012, 0.17, 12), Vector3(0, 0.23, -hz + 0.05), Color.WHITE, Vector3(90, 0, 0)))
	parts.append(_mesh(self, B.cyl(0.013, 0.011, 0.03, 12), Vector3(0, 0.21, -hz + 0.13), Color.WHITE))
	parts.append(_mesh(self, B.boxm(Vector3(0.012, 0.012, 0.09)), Vector3(0, 0.255, -hz - 0.06), Color.WHITE, Vector3(-25, 0, 0)))
	for m in parts:
		(m as MeshInstance3D).material_override = ch
	# Tiskiainepullo ja sieni vasemmalla.
	_mesh(self, B.cyl(0.03, 0.032, 0.17, 14), Vector3(-0.42, 0.085, -0.22), Color(0.15, 0.6, 0.3))
	_mesh(self, B.cyl(0.012, 0.016, 0.03, 10), Vector3(-0.42, 0.185, -0.22), Color(0.95, 0.95, 0.95))
	_mesh(self, B.boxm(Vector3(0.05, 0.06, 0.002)), Vector3(-0.42, 0.08, -0.189), Color(0.98, 0.96, 0.88))  # etiketti
	_mesh(self, B.cyl(0.012, 0.012, 0.002, 10), Vector3(-0.42, 0.09, -0.187), Color(0.95, 0.75, 0.1), Vector3(90, 0, 0))
	_mesh(self, B.boxm(Vector3(0.1, 0.03, 0.065)), Vector3(-0.42, 0.015, 0.0), Color(0.98, 0.85, 0.25))  # sieni
	_mesh(self, B.boxm(Vector3(0.1, 0.012, 0.065)), Vector3(-0.42, 0.036, 0.0), Color(0.2, 0.55, 0.3))
	# Kuivausteline oikealla: ritilä, piikit lautasille ja pohja.
	_rack = Node3D.new()
	_rack.position = Vector3(0.55, 0.0, -0.05)
	add_child(_rack)
	_mesh(_rack, B.boxm(Vector3(0.42, 0.012, 0.36)), Vector3(0, 0.006, 0), Color(0.85, 0.86, 0.88))
	for ix in 8:
		for side in [-1.0, 1.0]:
			_mesh(_rack, B.cyl(0.003, 0.003, 0.09, 6), Vector3(-0.17 + ix * 0.045, 0.05, side * 0.06 - 0.06), STEEL)
	for side in [-1.0, 1.0]:
		_mesh(_rack, B.cyl(0.004, 0.004, 0.42, 6), Vector3(0, 0.1, side * 0.06 - 0.06), STEEL, Vector3(0, 0, 90))
		_mesh(_rack, B.cyl(0.004, 0.004, 0.36, 6), Vector3(side * 0.21, 0.04, 0), STEEL, Vector3(90, 0, 0))
	# Valo ylhäältä (vain tämän kerroksen kappaleille).
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.1, 0.9, 0.4)
	lamp.omni_range = 3.0
	lamp.light_energy = 1.2
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.light_cull_mask = LAYER
	lamp.shadow_enabled = true
	add_child(lamp)


## Pestävä astia altaassa: muodot astiatyypin mukaan, likaläiskät omilla materiaaleillaan (haalistuvat hangatessa).
func _new_dish() -> void:
	_dirt = 1.0
	if _dish != null:
		_dish.queue_free()
	_dish = _make_dish(_cur()[0], _cur()[1])
	_dish.position = DISH_AT
	_dish.rotation.x = 0.35  # kallistettu pelaajaa kohti
	add_child(_dish)
	_spots.clear()
	var r: float = _dish.get_meta("r")
	var top: float = _dish.get_meta("top")
	for k in 9:
		var a := randf() * TAU
		var d := sqrt(randf()) * r * 0.65
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.36, 0.24, 0.1).lerp(Color(0.55, 0.38, 0.15), randf())
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var s := _mesh(_dish, B.sphere(randf_range(0.016, 0.032), 8), Vector3(cos(a) * d, top + 0.002, sin(a) * d), Color.WHITE)
		s.scale = Vector3(1.0, 0.15, randf_range(0.6, 1.0))
		s.material_override = m
		_spots.append(m)
	if _brush == null:
		_build_brush()


func _cur() -> Array:
	return DISHES[DISHES.size() - dishes_left]


## Astia umpinaisista paloista (lautanen: jalka, kartio ja pohja; muki: runko, sisäpohja ja korva). Meta r ja top =
## säde ja yläpinta likaa varten.
func _make_dish(kind: String, col: Color) -> Node3D:
	var d := Node3D.new()
	match kind:
		"muki":
			_mesh(d, B.cyl(0.045, 0.042, 0.09, 20), Vector3(0, 0.045, 0), col)
			_mesh(d, B.cyl(0.039, 0.039, 0.002, 20), Vector3(0, 0.091, 0), col.darkened(0.35))  # sisäpinta suusta
			_mesh(d, B.cyl(0.03, 0.03, 0.002, 16), Vector3(0, 0.0925, 0), Color(0.3, 0.18, 0.08))  # kahvinpohja
			var handle := _mesh(d, TorusMesh.new(), Vector3(0.055, 0.048, 0), col.darkened(0.08), Vector3(90, 0, 0))
			(handle.mesh as TorusMesh).inner_radius = 0.018
			(handle.mesh as TorusMesh).outer_radius = 0.028
			d.set_meta("r", 0.036)
			d.set_meta("top", 0.092)
		"lasi":
			var g := _mesh(d, B.cyl(0.038, 0.032, 0.11, 20), Vector3(0, 0.055, 0), Color.WHITE)
			var gm := StandardMaterial3D.new()
			gm.albedo_color = Color(col, 0.45)
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gm.roughness = 0.05
			gm.metallic_specular = 1.0
			g.material_override = gm
			_mesh(d, B.cyl(0.033, 0.033, 0.006, 20), Vector3(0, 0.003, 0), col.darkened(0.1))
			d.set_meta("r", 0.03)
			d.set_meta("top", 0.006)
		"kattila":
			_mesh(d, B.cyl(0.11, 0.105, 0.1, 28), Vector3(0, 0.05, 0), col)
			_mesh(d, B.cyl(0.1, 0.1, 0.002, 28), Vector3(0, 0.101, 0), col.darkened(0.3))  # sisus
			_mesh(d, B.cyl(0.098, 0.098, 0.002, 28), Vector3(0, 0.03, 0), col.darkened(0.15))
			_mesh(d, B.boxm(Vector3(0.16, 0.014, 0.03)), Vector3(0.18, 0.09, 0), Color(0.12, 0.12, 0.13))  # kahva
			var lip := _mesh(d, TorusMesh.new(), Vector3(0, 0.1, 0), col.lightened(0.2))  # pyöristetty reuna
			(lip.mesh as TorusMesh).inner_radius = 0.104
			(lip.mesh as TorusMesh).outer_radius = 0.114
			d.set_meta("r", 0.09)
			d.set_meta("top", 0.03)
		_:
			_mesh(d, B.cyl(0.05, 0.045, 0.008, 24), Vector3(0, 0.004, 0), col.darkened(0.08))  # jalka
			_mesh(d, B.cyl(0.125, 0.08, 0.016, 32), Vector3(0, 0.016, 0), col)  # reunan kartio
			# Kartion umpinainen yläpinta on lautasen pinta: pohja ja reunat piirretään sen päälle.
			_mesh(d, B.cyl(0.08, 0.08, 0.001, 32), Vector3(0, 0.0245, 0), col.darkened(0.05))  # pohja
			var rim := _mesh(d, TorusMesh.new(), Vector3(0, 0.0245, 0), col.darkened(0.12))  # pyöristetty reuna
			(rim.mesh as TorusMesh).inner_radius = 0.119
			(rim.mesh as TorusMesh).outer_radius = 0.127
			var well := _mesh(d, TorusMesh.new(), Vector3(0, 0.0245, 0), col.darkened(0.2))  # pohjan ja reunan raja
			(well.mesh as TorusMesh).inner_radius = 0.079
			(well.mesh as TorusMesh).outer_radius = 0.083
			if kind.begins_with("mummon"):
				for k in 10:
					var a := k * TAU / 10.0
					var fp := Vector3(cos(a) * 0.104, 0.025, sin(a) * 0.104)
					for pk in 5:
						var pa := pk * TAU / 5.0
						var pet := _mesh(d, B.sphere(0.006, 6), fp + Vector3(cos(pa), 0, sin(pa)) * 0.006, Color(0.6, 0.35, 0.75))
						pet.scale = Vector3(1, 0.3, 1)
					_mesh(d, B.sphere(0.003, 6), fp + Vector3(0, 0.001, 0), Color(0.95, 0.8, 0.3))
				var gold := _mesh(d, TorusMesh.new(), Vector3(0, 0.0255, 0), Color(0.85, 0.7, 0.3))
				(gold.mesh as TorusMesh).inner_radius = 0.121
				(gold.mesh as TorusMesh).outer_radius = 0.126
			d.set_meta("r", 0.08)
			d.set_meta("top", 0.025)
	return d


## Tiskiharja (kuten kuvassa, punaisena): litteä pitkänomainen harjaspää pyöristetyllä kärjellä, valkoiset harjakset
## pään alla viuhkana ulos ja eteen, kapea kevyesti kaartuva kahva, joka levenee päätä kohti, ja ripustuskoukku.
## Rungon kehyksessä harjan pituusakseli = +X (kärki -X), harjakset alas.
func _build_brush() -> void:
	_brush = Node3D.new()
	add_child(_brush)
	var body := Node3D.new()
	body.rotation = Vector3(0, 0.55, 0)  # kahva oikealle ja taakse (ei peitä astiaa kameralta)
	_brush.add_child(body)
	var red := Color(0.82, 0.16, 0.14)
	# Harjaspää: lättä ja pyöreä kärki, yläpinnassa matala ura.
	_mesh(body, B.boxm(Vector3(0.075, 0.009, 0.03)), Vector3(0.0, 0.012, 0), red)
	var tip := _mesh(body, B.cyl(0.015, 0.015, 0.009, 16), Vector3(-0.0375, 0.012, 0), red)
	tip.scale = Vector3(1.0, 1.0, 1.0)
	_mesh(body, B.boxm(Vector3(0.06, 0.002, 0.016)), Vector3(0.0, 0.0165, 0), red.darkened(0.2))
	# Harjakset: kolme riviä, reunarivit kallistuvat ulos, kärjen harjakset eteen.
	var white := Color(0.96, 0.96, 0.94)
	for row in 3:
		var z := (row - 1) * 0.01
		for k in 8:
			var x := -0.038 + k * 0.011
			var tilt_x := -float(row - 1) * 18.0  # ulospäin sivuille
			var tilt_z := 22.0 if k == 0 else (10.0 if k == 1 else 0.0)  # kärjessä eteen
			_mesh(body, B.cyl(0.0022, 0.0016, 0.024, 5), Vector3(x, -0.003, z * 1.2), white, Vector3(tilt_x, 0, tilt_z))
	for k in 5:  # kärjen kaari
		var a := PI / 2.0 + (k - 2) * 0.45
		_mesh(body, B.cyl(0.0022, 0.0016, 0.024, 5), Vector3(-0.042 - cos(a - PI / 2.0) * 0.004, -0.002, sin(a - PI / 2.0) * 0.011), white,
			Vector3(-sin(a - PI / 2.0) * 25.0, 0, 26.0))
	# Kahva: kaula kapenee pään takaa, varsi nousee kevyesti kaarelle ja levenee taas päätä kohti.
	var pts := [Vector3(0.04, 0.013, 0), Vector3(0.07, 0.022, 0), Vector3(0.11, 0.036, 0), Vector3(0.15, 0.05, 0),
		Vector3(0.19, 0.062, 0), Vector3(0.225, 0.068, 0)]
	var widths := [0.026, 0.014, 0.012, 0.015, 0.018, 0.016]
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var seg := _mesh(body, B.boxm(Vector3(a.distance_to(b) + 0.006, 0.008, (widths[k] + widths[k + 1]) / 2.0)), (a + b) / 2.0, red)
		seg.rotation.z = atan2(b.y - a.y, b.x - a.x)
	var hook := _mesh(body, TorusMesh.new(), Vector3(0.232, 0.062, 0), red.darkened(0.05), Vector3(90, 0, 0))
	(hook.mesh as TorusMesh).inner_radius = 0.004
	(hook.mesh as TorusMesh).outer_radius = 0.009


## Kuivausteline: pestyt astiat paikoilleen (lautaset pystyyn piikkien väliin, muut alassuin pohjalle).
func _rebuild_rack() -> void:
	for n in _rack_items:
		(n as Node3D).queue_free()
	_rack_items.clear()
	var plate_i := 0
	var low_x := -0.17
	for d: Array in _rack_list:
		var kind: String = d[0]
		var n := _make_dish(kind, d[1])
		_rack.add_child(n)
		_rack_items.append(n)
		if kind == "lautanen" or kind.begins_with("mummon"):
			n.position = Vector3(-0.15 + plate_i * 0.045, 0.13, -0.06)
			n.rotation = Vector3(0, 0, PI / 2.0 - 0.15)
			plate_i += 1
		else:
			n.position = Vector3(low_x + 0.05, 0.11 if kind != "kattila" else 0.11, 0.1)
			n.rotation = Vector3(PI, 0, 0)  # alassuin valumaan
			low_x += 0.12 if kind != "kattila" else 0.22
	for n in _rack_items:
		for c in (n as Node3D).find_children("*", "VisualInstance3D", true, false):
			(c as VisualInstance3D).layers = LAYER



# --- HUD ------------------------------------------------------------------------------------------------------------

func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_info = _label(24, 40.0)
	_sub = _label(22, -130.0)
	_sub.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_krash = _label(72, 0.0)
	_krash.anchor_top = 0.42
	_krash.offset_top = 0.0
	_krash.text = "KRÄSH!"
	_krash.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	_krash.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.06, 0.85)
	bg.anchor_left = 0.5
	bg.anchor_right = 0.5
	bg.anchor_top = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = -164
	bg.offset_right = 164
	bg.offset_top = -86
	bg.offset_bottom = -62
	_layer.add_child(bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.35, 0.82, 0.5)
	_bar_fill.position = Vector2(4, 4)
	_bar_fill.size = Vector2(0, 16)
	bg.add_child(_bar_fill)
	_bar_label = _label(18, -112.0)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	_layer.add_child(_keys)


func _label(size: int, y: float) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.anchor_right = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if y < 0.0:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	l.offset_top = y
	_layer.add_child(l)
	return l


func _say(t: String) -> void:
	comment.emit(t)
	_sub.text = "Santtu: " + t
	_sub_t = 3.5


# --- Peli -----------------------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseMotion and absf(event.relative.x) > 12.0:
		_scrub(1 if event.relative.x > 0.0 else -1)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_wobble = maxf(0.0, _wobble - delta * 2.0)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_sub_t -= delta
	if _sub_t <= 0.0:
		_sub.text = ""
	_update_camera()
	_update_brush()
	for i in _spots.size():
		_spots[i].albedo_color.a = _dirt * 0.95
	_bar_fill.size.x = 320.0 * (1.0 - _dirt)
	_bar_label.text = "Puhtaus %d %%" % roundi((1.0 - _dirt) * 100.0)
	if _busy_t >= 0.0:
		_busy_t -= delta
		if _busy_t < 0.0:
			_krash.visible = false
			_next()
		return
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish()
		return
	if Input.is_action_just_pressed("left"):
		_scrub(-1)
	if Input.is_action_just_pressed("right"):
		_scrub(1)
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact"):
		_lift()
	_info.text = "%s · jäljellä %d · telineessä %d" % [_cur()[0].capitalize(), dishes_left, washed]
	_keys.set_text("%s hankaa (tai hiiri)   [%s / %s] kuivaustelineeseen   %s lopeta" % [Settings.pair("left", "right"),
		Settings.action_key("jump"), Settings.action_key("interact"), Settings.cap("mount")])


func _update_camera() -> void:
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.008 * _shake
	var sway := Vector3(sin(_t * 0.9) * 0.004 + sin(_t * 1.7) * drunk * 0.02, sin(_t * 1.3) * 0.003, 0)
	var eye := Vector3(0.06, 0.42, 0.36) + sh + sway
	_cam.look_at_from_position(to_global(eye), to_global(Vector3(0.07, -0.05, -0.05) + sway * 0.5), Vector3.UP)  # maailman koordinaatit


## Harja hankaa viimeisimmän vedon suuntaan ja pomppii; nousee pois, kun astia nostetaan.
func _update_brush() -> void:
	if _brush == null:
		return
	var top: float = _dish.get_meta("top") if _dish != null else 0.0
	var lift := 0.12 if _busy_t >= 0.0 else 0.0
	_brush.position = DISH_AT + Vector3(_last_dir * 0.05 * _wobble + 0.02, top + 0.018 + lift + absf(sin(_t * 3.0)) * 0.005, 0.0)
	_brush.rotation = Vector3(0.35, 0.0, -_last_dir * 0.25 * _wobble)


func _scrub(dir: int) -> void:
	if dir == _last_dir or _busy_t >= 0.0:
		return
	_last_dir = dir
	_dirt = maxf(0.0, _dirt - SCRUB * randf_range(0.7, 1.2))
	_wobble = 1.0
	Sfx.play("water", -14.0, randf_range(1.3, 1.7))
	_splash(DISH_AT + Vector3(dir * 0.06, 0.03, 0.0), 4)
	if _dirt <= 0.0 and randf() < 0.5:
		_say(LINES.clean.pick_random())


## Vaahtoa ja vesipisaroita lentää harjan kohdalta.
func _splash(at: Vector3, n: int) -> void:
	for k in n:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 1, 1, 0.85) if k % 2 == 0 else Color(0.75, 0.88, 0.98, 0.8)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var b := _mesh(self, B.sphere(randf_range(0.004, 0.009), 6), at, Color.WHITE)
		b.material_override = m
		var peak := at + Vector3(randf_range(-0.08, 0.08), randf_range(0.04, 0.1), randf_range(-0.05, 0.05))
		var tw := create_tween()
		tw.tween_property(b, "position", peak, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(b, "position", Vector3(peak.x * 1.2, WATER_Y, peak.z), 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(b.queue_free)


func _lift() -> void:
	if _dirt > 0.15:
		_say(LINES.lazy.pick_random())
		Sfx.play("alert", -12.0, 1.6)
		return
	# Märkä astia lipsahtaa humalassa (ja mummon kukkalautanen aina vähän helpommin): särkyy altaan reunaan.
	var slip := drunk * 0.45 + (0.08 if _cur()[0].begins_with("mummon") else 0.02)
	if randf() < slip:
		broken += 1
		_busy_t = 0.9
		_shake = 1.0
		_krash.visible = true
		Sfx.play("glass", 0.0, 0.7)
		_say(LINES["break"].pick_random())
		_shatter()
		return
	washed += 1
	Sfx.play("pickup", -8.0, 1.2)
	_busy_t = 0.45
	var tw := create_tween().set_parallel()
	tw.tween_property(_dish, "position", _rack.position + Vector3(0, 0.2, 0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_dish, "rotation", Vector3(0, 0, PI / 2.0), 0.4)
	_rack_list.append(_cur())


## Astia särkyy: kappale katoaa ja tilalle lentää umpinaisia sirpaleita (kolmiosärmiöt), jotka putoavat veteen.
func _shatter() -> void:
	var col: Color = _cur()[1]
	var at := _dish.position + Vector3(0, 0.03, 0)
	_dish.visible = false
	for k in 12:
		var pm := PrismMesh.new()
		pm.size = Vector3(randf_range(0.02, 0.05), randf_range(0.02, 0.04), 0.006)
		var s := _mesh(self, pm, at, col.darkened(randf_range(0.0, 0.2)))
		var a := k * TAU / 12.0
		var peak := at + Vector3(cos(a) * randf_range(0.08, 0.18), randf_range(0.05, 0.14), sin(a) * randf_range(0.05, 0.12))
		var tw := create_tween().set_parallel()
		tw.tween_property(s, "position", peak, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "rotation", Vector3(randf() * 8, randf() * 8, randf() * 8), 0.7)
		tw.chain().tween_property(s, "position", Vector3(peak.x, WATER_Y - 0.02, peak.z), 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.chain().tween_callback(s.queue_free)


func _next() -> void:
	dishes_left -= 1
	_rebuild_rack()
	if dishes_left <= 0:
		_say(LINES.done[0])
		_finish()
		return
	_new_dish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	finished.emit(washed, broken)
	queue_free()
