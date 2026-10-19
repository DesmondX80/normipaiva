extends SubViewport
## Kymmenen uutiset videonauhalta (cutscene.gd news_tape): oma 3D-maailma telkkarin ruudulle. Kolme lavastetta:
## alkutunnus (kanava 3:n tapaan sinivihreä tausta, maapallo ja valkoinen ja punainen nauha, joista kiertyy 3),
## uutisstudio (uutistenlukija pöydän takana, videoseinällä kymmentä näyttävä kello kuten Kymmenen uutisten
## vanhassa tunnuksessa) ja säästudio (meteorologi karttaseinän edessä). Päälle piirretään TV-grafiikat kuten oikeassa lähetyksessä (alakolmannes, kello, logo)
## ja VHS-nauhan jäljet (juovat, aikakoodi, seurantahäiriö). Vaiheet (seg): "play" (videon sininen ruutu), "tunnus",
## "studio" ja "saa". Kartta piirretään omaan SubViewportiinsa ja näytetään säästudion videoseinällä.

const B := preload("res://scripts/build.gd")
const MG := preload("res://scripts/mg_draw.gd")
const Looks := preload("res://scripts/looks.gd")

const SIZE := Vector2i(640, 400)
const GLOBE_AT := Vector3(-60, 0, 0)
const WEATHER_AT := Vector3(60, 0, 0)
const ANCHOR := {"shirt": Color(0.1, 0.13, 0.22), "pants": Color(0.1, 0.11, 0.15), "shoes": Color(0.05, 0.05, 0.05),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.28, 0.2, 0.13), "height": 1.8, "skin": Color(0.98, 0.84, 0.74)}
const METEOROLOGI := {"model": "female", "shirt": Color(0.62, 0.1, 0.14), "pants": Color(0.1, 0.1, 0.12),
	"shoes": Color(0.08, 0.06, 0.05), "hair": "Hair_Long", "hair_color": Color(0.85, 0.68, 0.38), "height": 1.7,
	"skin": Color(0.98, 0.86, 0.76), "curves": 0.6, "bust": 1.6}
## Suomen ja naapurien rajat pituus- ja leveyspiireinä (karkea, tunnistettava muoto). Lounaisrannikolta
## itärajaa pohjoiseen, Lapin käsivarsi ja Tornionjoki alas, sitten Pohjanlahden rannikko etelään.
const FINLAND := [Vector2(22.95, 59.82), Vector2(24.0, 60.0), Vector2(24.95, 60.15), Vector2(25.7, 60.28), Vector2(26.9, 60.42),
	Vector2(27.8, 60.55), Vector2(28.8, 61.15), Vector2(29.6, 61.6), Vector2(30.6, 62.2), Vector2(31.5, 62.85), Vector2(31.0, 63.3),
	Vector2(30.2, 63.9), Vector2(30.0, 64.6), Vector2(29.6, 65.1), Vector2(29.9, 65.7), Vector2(29.5, 66.1), Vector2(29.2, 66.8),
	Vector2(29.0, 67.5), Vector2(28.6, 68.1), Vector2(28.4, 68.5), Vector2(28.8, 68.9), Vector2(28.4, 69.6), Vector2(27.9, 70.08),
	Vector2(27.0, 69.9), Vector2(26.0, 69.6), Vector2(25.8, 69.3), Vector2(25.2, 68.8), Vector2(24.4, 68.65), Vector2(23.4, 68.75),
	Vector2(22.4, 68.7), Vector2(21.5, 69.05), Vector2(20.6, 69.05), Vector2(21.3, 68.75), Vector2(22.4, 68.4), Vector2(23.2, 67.9),
	Vector2(23.6, 67.4), Vector2(23.7, 66.8), Vector2(24.0, 66.3), Vector2(24.15, 65.85), Vector2(24.6, 65.72), Vector2(25.2, 65.5),
	Vector2(25.45, 65.0), Vector2(24.9, 64.85), Vector2(24.47, 64.68), Vector2(23.9, 64.25), Vector2(23.1, 63.84), Vector2(22.4, 63.5),
	Vector2(21.6, 63.1), Vector2(21.3, 62.6), Vector2(21.4, 62.27), Vector2(21.5, 61.6), Vector2(21.45, 61.13), Vector2(21.35, 60.8),
	Vector2(21.6, 60.55), Vector2(22.2, 60.4), Vector2(22.5, 60.1)]
const SWEDEN := [Vector2(20.6, 69.05), Vector2(21.3, 68.75), Vector2(22.4, 68.4), Vector2(23.2, 67.9), Vector2(23.6, 67.4),
	Vector2(23.7, 66.8), Vector2(24.0, 66.3), Vector2(24.15, 65.85), Vector2(23.0, 65.8), Vector2(22.1, 65.55), Vector2(21.3, 64.9),
	Vector2(20.3, 63.85), Vector2(19.0, 63.4), Vector2(18.2, 62.8), Vector2(17.3, 62.3), Vector2(17.0, 61.2), Vector2(17.3, 60.6),
	Vector2(18.5, 60.1), Vector2(18.9, 59.4), Vector2(18.0, 58.8), Vector2(14.0, 58.8), Vector2(14.0, 69.5)]
const NORWAY := [Vector2(14.0, 69.5), Vector2(20.6, 69.05), Vector2(21.5, 69.05), Vector2(22.4, 68.7), Vector2(23.4, 68.75),
	Vector2(24.4, 68.65), Vector2(25.2, 68.8), Vector2(25.8, 69.3), Vector2(26.0, 69.6), Vector2(27.0, 69.9), Vector2(27.9, 70.08),
	Vector2(28.4, 69.6), Vector2(29.5, 69.8), Vector2(30.5, 70.4), Vector2(31.0, 71.0), Vector2(14.0, 71.0)]
const RUSSIA := [Vector2(27.8, 60.55), Vector2(28.8, 61.15), Vector2(29.6, 61.6), Vector2(30.6, 62.2), Vector2(31.5, 62.85),
	Vector2(31.0, 63.3), Vector2(30.2, 63.9), Vector2(30.0, 64.6), Vector2(29.6, 65.1), Vector2(29.9, 65.7), Vector2(29.5, 66.1),
	Vector2(29.2, 66.8), Vector2(29.0, 67.5), Vector2(28.6, 68.1), Vector2(28.4, 68.5), Vector2(28.8, 68.9), Vector2(28.4, 69.6),
	Vector2(29.5, 69.8), Vector2(30.5, 70.4), Vector2(38.0, 70.4), Vector2(38.0, 58.8), Vector2(28.5, 58.8), Vector2(28.5, 59.9)]
const ESTONIA := [Vector2(21.8, 59.0), Vector2(23.4, 59.2), Vector2(24.75, 59.45), Vector2(26.0, 59.6), Vector2(28.0, 59.45),
	Vector2(28.5, 59.0)]
## Järvet: [keskipiste (pituus, leveys), säteet asteina].
const LAKES := [[Vector2(28.4, 61.4), Vector2(0.75, 0.22)], [Vector2(25.6, 61.6), Vector2(0.18, 0.4)], [Vector2(27.3, 64.3), Vector2(0.45, 0.13)],
	[Vector2(27.8, 63.0), Vector2(0.3, 0.25)], [Vector2(24.0, 61.6), Vector2(0.35, 0.12)], [Vector2(27.3, 69.0), Vector2(0.45, 0.2)],
	[Vector2(29.3, 62.3), Vector2(0.25, 0.3)], [Vector2(26.0, 62.4), Vector2(0.2, 0.15)]]

var seg := "play"
var headline := ""
var talk := false:
	set(v):
		talk = v
		if _anchor != null:
			_anchor.play("Sitting_Talking" if v else "Sitting_Idle", 0.3)

var _t := 0.0
var _seg_t := 0.0
var _last_seg := ""
var _cam: Camera3D
var _overlay: Node2D
var _map: Node2D
var _globe: Node3D
var _ribbons: Node3D
var _anchor: Node3D
var _weather: Node3D


func _init() -> void:
	size = SIZE
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_2X


func _ready() -> void:
	var root := Node3D.new()
	add_child(root)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.75)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	we.environment = env
	root.add_child(we)
	_build_globe(root)
	_build_studio(root)
	_build_weather(root)
	_cam = Camera3D.new()
	_cam.fov = 32.0
	root.add_child(_cam)
	_cam.current = true
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _process(delta: float) -> void:
	_t += delta
	_seg_t = 0.0 if seg != _last_seg else _seg_t + delta
	_last_seg = seg
	_globe.rotation.y += delta * 0.35
	match seg:
		"play", "tunnus":
			# Alkutunnus: nauhat kiertyvät sivulta paikoilleen 3:ksi, kamera liukuu hitaasti sisään.
			var u := clampf(_seg_t / 3.0, 0.0, 1.0)
			var k := clampf(_seg_t / 1.1, 0.0, 1.0) if seg == "tunnus" else 0.0
			_ribbons.rotation.y = lerpf(PI * 0.55, 0.0, 1.0 - pow(1.0 - k, 3.0))
			_ribbons.scale = Vector3.ONE * lerpf(0.4, 1.0, k)
			_cam.fov = 40.0
			_cam.look_at_from_position(GLOBE_AT + Vector3(0, 0.25, lerpf(4.6, 4.0, u)), GLOBE_AT + Vector3(0, 0.25, 0))
		"studio":
			# Uutisstudio: puolilähikuva, hidas ajo sisään.
			var u := clampf(_seg_t / 8.0, 0.0, 1.0)
			_cam.fov = lerpf(30.0, 24.0, u)
			_cam.look_at_from_position(Vector3(0.25, 1.35, 3.6), Vector3(0, 1.12, -0.6))
		"saa":
			_cam.fov = 34.0
			_cam.look_at_from_position(WEATHER_AT + Vector3(-0.2, 1.4, 3.3), WEATHER_AT + Vector3(-0.2, 1.4, 0))
	_overlay.queue_redraw()


# --- Materiaalit ---------------------------------------------------------------------

static func _gloss(col: Color, rough := 0.25, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


static func _glow(col: Color, energy := 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col.darkened(0.5)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


static func _grad_tex(top: Color, bottom: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	return t


func _part(parent: Node3D, m: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _light(parent: Node3D, pos: Vector3, target: Vector3, col: Color, energy: float, angle := 35.0, rng := 12.0) -> void:
	var l := SpotLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.spot_angle = angle
	l.spot_range = rng
	parent.add_child(l)
	l.look_at_from_position(pos, target)


# --- Alkutunnus: maapallo ---------------------------------------------------------------

func _build_globe(root: Node3D) -> void:
	var g := Node3D.new()
	g.position = GLOBE_AT
	root.add_child(g)
	_globe = Node3D.new()
	_globe.rotation_degrees = Vector3(18, 0, 0)
	_globe.position = Vector3(0.75, 0.2, -0.6)
	g.add_child(_globe)
	# Mantereet kohinasta: meri sininen, maa vihreä ja ruskea, napajäätä ei tarvita.
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 5
	n.seed = 7
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.52, 0.54, 0.62, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(0.03, 0.12, 0.35), Color(0.08, 0.3, 0.6), Color(0.75, 0.7, 0.5), Color(0.25, 0.5, 0.2),
		Color(0.35, 0.33, 0.2), Color(0.9, 0.9, 0.9)])
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	tex.color_ramp = ramp
	var em := StandardMaterial3D.new()
	em.albedo_texture = tex
	em.roughness = 0.5
	em.emission_enabled = true
	em.emission_texture = tex
	em.emission_energy_multiplier = 0.35
	var earth := SphereMesh.new()
	earth.radius = 1.0
	earth.height = 2.0
	earth.radial_segments = 48
	earth.rings = 24
	_part(_globe, earth, Vector3.ZERO, em)
	# Ilmakehän hehku: hieman isompi läpikuultava pallo.
	var air := SphereMesh.new()
	air.radius = 1.06
	air.height = 2.12
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.albedo_color = Color(0.4, 0.7, 1.0, 0.18)
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.cull_mode = BaseMaterial3D.CULL_FRONT
	_part(_globe, air, Vector3.ZERO, am)
	# Sinivihreä taustaseinä ja hennot säteet.
	var bg := StandardMaterial3D.new()
	bg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.albedo_texture = _grad_tex(Color(0.05, 0.55, 0.6), Color(0.0, 0.12, 0.28))
	_part(g, B.boxm(Vector3(16, 9, 0.1)), Vector3(0, 0, -5.0), bg)
	for k in 10:
		var ray := _part(g, B.boxm(Vector3(0.03, 12.0, 0.02)), Vector3(1.0, 0.2, -4.0), _glow(Color(0.4, 0.95, 0.95), 0.5), Vector3(0, 0, k * 18.0))
		ray.transparency = 0.7
	# Valkoinen ja punainen nauha, joista muodostuu 3 maapallon eteen.
	_ribbons = Node3D.new()
	_ribbons.position = Vector3(-0.55, 0.35, 0.9)
	g.add_child(_ribbons)
	_ribbon3(_ribbons, Color(0.97, 0.97, 0.97), Vector2(0.0, 0.0), 0.02)
	_ribbon3(_ribbons, Color(0.88, 0.1, 0.12), Vector2(-0.07, 0.05), -0.02)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.2
	sun.rotation_degrees = Vector3(-20, 40, 0)
	g.add_child(sun)


## Nauha 3:n muotoon (yläkaari ja alakaari myötäpäivään), leveys 0.11, hento aaltoilu syvyyssuunnassa.
## shift siirtää nauhaa (rinnakkainen toinen nauha), dz syvyyttä.
func _ribbon3(parent: Node3D, col: Color, shift: Vector2, dz: float) -> void:
	var pts: Array[Vector2] = []
	for i in 25:
		var a := deg_to_rad(lerpf(150.0, -90.0, i / 24.0))
		pts.append(Vector2(0, 0.4) + Vector2(cos(a), sin(a)) * 0.4)
	for i in range(1, 27):
		var a := deg_to_rad(lerpf(90.0, -150.0, i / 26.0))
		pts.append(Vector2(0, -0.44) + Vector2(cos(a), sin(a)) * 0.44)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var p := pts[i] + shift
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-t.y, t.x) * 0.055
		var z := dz + 0.04 * sin(i * 0.35)
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3(p.x + n.x, p.y + n.y, z))
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3(p.x - n.x, p.y - n.y, z))
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.3
	m.metallic = 0.2
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	parent.add_child(mi)


## Kymmenen uutisten kello: sininen taulu, valkoinen kehä ja tuntimerkit, viisarit kymmenessä (tunti 300°).
func _clock(parent: Node3D, pos: Vector3, rad: float) -> void:
	var c := Node3D.new()
	c.position = pos
	parent.add_child(c)
	_part(c, B.cyl(rad, rad, 0.03, 48), Vector3.ZERO, _glow(Color(0.1, 0.3, 0.85), 0.9), Vector3(90, 0, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = rad * 0.93
	rim.outer_radius = rad * 1.02
	_part(c, rim, Vector3(0, 0, 0.02), _glow(Color(0.95, 0.97, 1.0), 1.6), Vector3(90, 0, 0))
	for k in 12:
		var a := TAU * k / 12.0
		var tick := _part(c, B.boxm(Vector3(rad * (0.05 if k % 3 else 0.08), rad * (0.12 if k % 3 else 0.18), 0.01)),
			Vector3(sin(a), cos(a), 0) * rad * 0.8 + Vector3(0, 0, 0.025), _glow(Color.WHITE, 1.4))
		tick.rotation.z = -a
	for h in [[300.0, 0.5, 0.07], [0.0, 0.75, 0.045]]:
		var a := deg_to_rad(h[0])
		var hand := _part(c, B.boxm(Vector3(rad * h[2], rad * h[1], 0.012)), Vector3(sin(a), cos(a), 0) * rad * h[1] * 0.5 + Vector3(0, 0, 0.035),
			_glow(Color.WHITE, 1.6))
		hand.rotation.z = -a
	_part(c, B.cyl(rad * 0.06, rad * 0.06, 0.02, 16), Vector3(0, 0, 0.045), _glow(Color(0.9, 0.1, 0.12), 1.5), Vector3(90, 0, 0))


# --- Uutisstudio ---------------------------------------------------------------------

func _build_studio(root: Node3D) -> void:
	var s := Node3D.new()
	root.add_child(s)
	# Kiiltävä tumma lattia ja kaareva videoseinä taustalla.
	_part(s, B.boxm(Vector3(14, 0.05, 10)), Vector3(0, -0.025, 0), _gloss(Color(0.06, 0.07, 0.1), 0.15))
	var wall := StandardMaterial3D.new()
	wall.albedo_texture = _grad_tex(Color(0.06, 0.38, 0.55), Color(0.01, 0.08, 0.2))
	wall.emission_enabled = true
	wall.emission_texture = wall.albedo_texture
	wall.emission_energy_multiplier = 0.45
	for k in 9:
		var a := deg_to_rad(-48.0 + k * 12.0)
		var p := Vector3(sin(a) * 5.0, 1.6, -cos(a) * 5.0 + 1.2)
		var panel := _part(s, B.boxm(Vector3(1.0, 2.9, 0.04)), p, wall)
		panel.rotation.y = -a
		_part(panel, B.boxm(Vector3(1.04, 2.94, 0.02)), Vector3(0, 0, -0.03), _gloss(Color(0.02, 0.02, 0.03), 0.4))  # kehys
		_part(panel, B.boxm(Vector3(1.0, 0.025, 0.05)), Vector3(0, -0.6, 0.01), _glow(Color(0.5, 0.8, 1.0), 2.0))  # valojuova
		# Kaupungin siluetti paneelien alaosassa (iltakuva).
		var rng := RandomNumberGenerator.new()
		rng.seed = k
		for b in 4:
			var h := rng.randf_range(0.25, 0.8)
			_part(panel, B.boxm(Vector3(0.22, h, 0.01)), Vector3(-0.36 + b * 0.24, -1.45 + h / 2.0, 0.025),
				_glow(Color(0.08, 0.12, 0.3), 0.4))
	# Videoseinän keskellä Kymmenen uutisten kello uutistenlukijan takana.
	_clock(s, Vector3(0, 2.25, -3.72), 0.42)
	# Uutispöytä: kaareva etulevy, kiiltävä kansi ja punainen valojuova.
	var desk := Node3D.new()
	desk.position = Vector3(0, 0, -0.1)
	s.add_child(desk)
	for k in 7:
		var a := deg_to_rad(-27.0 + k * 9.0)
		var front := _part(desk, B.boxm(Vector3(0.42, 0.72, 0.06)), Vector3(sin(a) * 2.6, 0.36, -cos(a) * 2.6 + 2.6), _gloss(Color(0.12, 0.16, 0.3), 0.3, 0.4))
		front.rotation.y = -a
		_part(front, B.boxm(Vector3(0.42, 0.03, 0.07)), Vector3(0, 0.12, 0.01), _glow(Color(0.95, 0.15, 0.15), 2.2))
		var top := _part(desk, B.boxm(Vector3(0.44, 0.04, 0.75)), Vector3(sin(a) * 2.25, 0.74, -cos(a) * 2.25 + 2.6), _gloss(Color(0.85, 0.87, 0.92), 0.1))
		top.rotation.y = -a
	_part(desk, B.boxm(Vector3(0.24, 0.005, 0.32)), Vector3(0.12, 0.765, -0.15), _gloss(Color(0.96, 0.96, 0.94), 0.8), Vector3(0, 8, 0))  # paperit
	_part(desk, B.cyl(0.035, 0.03, 0.1, 12), Vector3(-0.55, 0.81, -0.05), _gloss(Color(0.95, 0.95, 0.95), 0.3))  # kahvikuppi
	# Tuoli ja uutistenlukija.
	_part(s, B.boxm(Vector3(0.55, 0.08, 0.5)), Vector3(0, 0.48, -0.95), _gloss(Color(0.08, 0.08, 0.09), 0.5))
	_part(s, B.boxm(Vector3(0.5, 0.75, 0.08)), Vector3(0, 0.9, -1.22), _gloss(Color(0.08, 0.08, 0.09), 0.5))
	_anchor = Looks.make(s, ANCHOR)
	_anchor.position = Vector3(0, 0.02, -0.82)
	_anchor.rotation.y = PI  # kohti kameraa (+Z)
	_anchor.play("Sitting_Idle", 0.0)
	_dress_anchor(_anchor)
	# Studiovalot: avainvalo edestä vasemmalta, täyte oikealta ja sininen takavalo.
	_light(s, Vector3(-2.2, 3.2, 2.6), Vector3(0, 1.1, -0.8), Color(1.0, 0.95, 0.88), 4.0)
	_light(s, Vector3(2.5, 2.6, 2.4), Vector3(0, 1.1, -0.8), Color(0.85, 0.9, 1.0), 1.8)
	_light(s, Vector3(0, 3.0, -2.6), Vector3(0, 1.3, -0.8), Color(0.45, 0.6, 1.0), 3.0, 40.0)


## Puvun yksityiskohdat kaula-aukossa: valkoisen kauluspaidan V (alaspäin osoittava kolmioprisma), punainen solmio
## solmuineen ja tummat kauluksen käänteet V:n reunoilla.
func _dress_anchor(c: Node3D) -> void:
	var v := Node3D.new()
	var shirt := PrismMesh.new()
	shirt.size = Vector3(0.1, 0.11, 0.01)
	_part(v, shirt, Vector3(0, -0.045, 0), _gloss(Color(0.95, 0.95, 0.97), 0.6), Vector3(0, 0, 180))
	var red := _gloss(Color(0.72, 0.08, 0.1), 0.35)
	_part(v, B.boxm(Vector3(0.024, 0.02, 0.01)), Vector3(0, -0.008, -0.008), red)  # solmu
	var tie := PrismMesh.new()
	tie.size = Vector3(0.026, 0.08, 0.008)
	_part(v, tie, Vector3(0, -0.055, -0.008), red, Vector3(0, 0, 180))
	v.rotation.y = PI  # kiinnityskehyksessä eteenpäin on -Z (solmio V:n edessä)
	c.attach("neck_01", v, Vector3(0, -0.038, -0.105))


# --- Säästudio ---------------------------------------------------------------------

func _build_weather(root: Node3D) -> void:
	var w := Node3D.new()
	w.position = WEATHER_AT
	root.add_child(w)
	_part(w, B.boxm(Vector3(10, 0.05, 8)), Vector3(0, -0.025, 0), _gloss(Color(0.05, 0.06, 0.09), 0.2))
	_part(w, B.boxm(Vector3(10, 4, 0.1)), Vector3(0, 2, -1.2), _gloss(Color(0.08, 0.12, 0.25), 0.6))
	# Karttaseinä: piirretty kartta omasta SubViewportista.
	var mv := SubViewport.new()
	mv.size = Vector2i(640, 800)
	mv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mv.transparent_bg = false
	_map = Node2D.new()
	_map.draw.connect(_draw_map)
	mv.add_child(_map)
	add_child(mv)
	var screen := StandardMaterial3D.new()
	screen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.albedo_texture = mv.get_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.95, 2.44)
	_part(w, quad, Vector3(0.45, 1.5, -1.1), screen)
	_part(w, B.boxm(Vector3(2.05, 2.54, 0.04)), Vector3(0.45, 1.5, -1.13), _gloss(Color(0.02, 0.02, 0.03), 0.3))
	_weather = Looks.make(w, METEOROLOGI)
	_weather.position = Vector3(-0.95, 0, -0.3)
	_weather.rotation.y = PI - 0.45  # kohti kameraa, hieman karttaan päin
	_weather.play("Idle_Talking", 0.0)
	_light(w, Vector3(-2.0, 3.0, 3.0), Vector3(-0.9, 1.3, -0.3), Color(1.0, 0.95, 0.88), 3.5)
	_light(w, Vector3(2.0, 2.5, 2.5), Vector3(-0.9, 1.3, -0.3), Color(0.85, 0.9, 1.0), 1.2)


## Pituus- ja leveysaste karttaviewportin pikseleiksi (14,3–37,4° E, 58,9–71° N; pituusaste kavennettu 65° leveydellä).
static func _ll(p: Vector2) -> Vector2:
	return Vector2((p.x - 14.3) * 27.7, (71.0 - p.y) * 66.0)


func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(_ll(p))
	return out


## Säätiedotuksen kartta: meri, naapurimaat, Suomi varjostettuna, järvet, kaupunkipisteet, sääsymbolit ja lämpötilat.
func _draw_map() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(640, 800))
	MG.grad_rect(_map, r, Color(0.16, 0.36, 0.66), Color(0.08, 0.22, 0.48))
	for y in range(0, 800, 40):  # leveyspiirien hento ruudukko
		_map.draw_line(Vector2(0, y), Vector2(640, y), Color(1, 1, 1, 0.05), 1.0)
	for poly in [SWEDEN, NORWAY, RUSSIA, ESTONIA + [Vector2(28.5, 58.0), Vector2(21.8, 58.0)]]:
		var pts := _poly(poly)
		_map.draw_colored_polygon(pts, Color(0.33, 0.38, 0.33))
		pts.append(pts[0])
		_map.draw_polyline(pts, Color(0.6, 0.65, 0.58), 1.5, true)
	var fi := _poly(FINLAND)
	var shadow := PackedVector2Array()
	for p in fi:
		shadow.append(p + Vector2(6, 8))
	_map.draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	_map.draw_colored_polygon(fi, Color(0.36, 0.62, 0.3))
	# Maaston sävy: etelä vihreämpi, Lappi ruskeampi tunturi (vaakajuovat päälle läpikuultavina).
	for k in 10:
		var y0 := 60.0 + k * 34.0
		var row := PackedVector2Array([Vector2(0, y0), Vector2(640, y0), Vector2(640, y0 + 34.0), Vector2(0, y0 + 34.0)])
		for band in Geometry2D.intersect_polygons(fi, row):
			_map.draw_colored_polygon(band, Color(0.55, 0.45, 0.3, 0.05 * (10 - k)))
	var outline := fi.duplicate()
	outline.append(fi[0])
	_map.draw_polyline(outline, Color(0.95, 0.95, 0.88), 3.0, true)
	for l in LAKES:
		var c := _ll(l[0])
		var rr: Vector2 = _ll(l[0] + l[1]) - c
		_ellipse(_map, c, Vector2(absf(rr.x), absf(rr.y)), Color(0.22, 0.45, 0.78))
	# Kaupungit ja sää.
	var spots := [["Helsinki", Vector2(24.95, 60.17), "aurinko", "+17"], ["Kuopio", Vector2(27.68, 62.9), "puolipilvi", "+14"],
		["Saloinen", Vector2(24.55, 64.6), "sade", "+12"], ["Rovaniemi", Vector2(25.73, 66.5), "pilvi", "+9"],
		["Inari", Vector2(27.03, 68.9), "pilvi", "+7"]]
	var f := ThemeDB.fallback_font
	for sp in spots:
		var p := _ll(sp[1])
		_map.draw_circle(p, 5.0, Color(1, 1, 1))
		_map.draw_circle(p, 3.0, Color(0.85, 0.1, 0.1))
		_map.draw_string_outline(f, p + Vector2(-90, 22), sp[0], HORIZONTAL_ALIGNMENT_CENTER, 180, 22, 5, Color(0, 0, 0, 0.7))
		_map.draw_string(f, p + Vector2(-90, 22), sp[0], HORIZONTAL_ALIGNMENT_CENTER, 180, 22, Color.WHITE)
		var icon := p + Vector2(-46, -34)
		match sp[2]:
			"aurinko":
				_sun(icon, 20.0)
			"puolipilvi":
				_sun(icon + Vector2(10, -8), 15.0)
				_cloud(icon + Vector2(-4, 4), 0.85, false)
			"sade":
				_cloud(icon, 1.0, true)
			_:
				_cloud(icon, 0.95, false)
		MG.box(_map, Rect2(p + Vector2(14, -50), Vector2(62, 36)), Color(0.04, 0.08, 0.2, 0.85), 6, 0, Color(1, 1, 1, 0.5), 1)
		_map.draw_string(f, p + Vector2(14, -23), sp[3], HORIZONTAL_ALIGNMENT_CENTER, 62, 28, Color(1.0, 0.9, 0.35))


static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


func _sun(c: Vector2, r: float) -> void:
	MG.glow(_map, c, r * 2.2, Color(1.0, 0.85, 0.3, 0.8))
	for k in 10:
		var a := TAU * k / 10.0 + _t * 0.4
		_map.draw_line(c + Vector2(cos(a), sin(a)) * (r + 4), c + Vector2(cos(a), sin(a)) * (r + 13), Color(1.0, 0.82, 0.15), 4.0)
	MG.ball(_map, c, r, Color(1.0, 0.8, 0.15), 0.45)


func _cloud(c: Vector2, s: float, rain: bool) -> void:
	var col := Color(0.62, 0.66, 0.72) if rain else Color(0.93, 0.94, 0.96)
	if rain:
		for k in 5:
			var x := c.x - 22 * s + k * 11 * s
			var y := c.y + 16 * s + fmod(_t * 50.0 + k * 9.0, 20.0) * s
			_map.draw_line(Vector2(x, y), Vector2(x - 4 * s, y + 10 * s), Color(0.35, 0.6, 1.0), 3.0)
	var blobs := [[Vector2(-16, 4), 14.0], [Vector2(0, -6), 18.0], [Vector2(16, 3), 13.0]]
	for b in blobs:
		_map.draw_circle(c + b[0] * s + Vector2(2, 4), b[1] * s, Color(0, 0, 0, 0.25))
	_map.draw_rect(Rect2(c + Vector2(-28, 4) * s + Vector2(2, 4), Vector2(56, 13) * s), Color(0, 0, 0, 0.25))
	for b in blobs:
		_map.draw_circle(c + b[0] * s, b[1] * s, col)
	_map.draw_rect(Rect2(c + Vector2(-28, 4) * s, Vector2(56, 13) * s), col)
	_map.draw_circle(c + Vector2(-4, -12) * s, 7.0 * s, col.lightened(0.4))  # kiilto


# --- TV-grafiikat ja VHS ---------------------------------------------------------------

func _text(pos: Vector2, s: String, size_px: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, outline := 0) -> void:
	var f := ThemeDB.fallback_font
	if outline > 0:
		_overlay.draw_string_outline(f, pos, s, align, width, size_px, outline, Color(0, 0, 0, 0.6))
	_overlay.draw_string(f, pos, s, align, width, size_px, col)


## Kymmenen uutisten kello: sininen taulu, valkoinen kehä, tuntimerkit ja viisarit kymmenessä.
func _clock_icon(c: Vector2, rad: float, a: float) -> void:
	var o := _overlay
	o.draw_circle(c + Vector2(2, 3), rad, Color(0, 0, 0, 0.35 * a))
	o.draw_circle(c, rad, Color(0.12, 0.35, 0.9, a))
	o.draw_circle(c - Vector2(rad, rad) * 0.25, rad * 0.55, Color(0.4, 0.6, 1.0, 0.25 * a))  # kiilto
	o.draw_arc(c, rad, 0, TAU, 40, Color(1, 1, 1, a), maxf(2.0, rad * 0.1), true)
	for k in 12:
		var d := Vector2(sin(TAU * k / 12.0), -cos(TAU * k / 12.0))
		o.draw_line(c + d * rad * 0.72, c + d * rad * (0.86 if k % 3 else 0.9), Color(1, 1, 1, a), maxf(1.0, rad * 0.06))
	o.draw_line(c, c + Vector2(sin(deg_to_rad(300.0)), -cos(deg_to_rad(300.0))) * rad * 0.5, Color(1, 1, 1, a), maxf(2.0, rad * 0.11))
	o.draw_line(c, c + Vector2(0, -rad * 0.78), Color(1, 1, 1, a), maxf(1.5, rad * 0.07))
	o.draw_circle(c, rad * 0.08, Color(0.9, 0.1, 0.12, a))


## Kanavan logo kulmassa: valkoinen ja punainen nauha 3:n muotoisina kaarina, hieman läpikuultava.
func _ribbon_bug(c: Vector2, s: float) -> void:
	for rib in [[Color(1, 1, 1, 0.85), Vector2.ZERO], [Color(0.92, 0.12, 0.14, 0.85), Vector2(-4, 3)]]:
		var off: Vector2 = c + rib[1] * s
		_overlay.draw_arc(off + Vector2(0, -11) * s, 11.0 * s, deg_to_rad(-150), deg_to_rad(90), 20, rib[0], 4.5 * s, true)
		_overlay.draw_arc(off + Vector2(0, 12) * s, 12.0 * s, deg_to_rad(-90), deg_to_rad(150), 20, rib[0], 4.5 * s, true)


func _draw_overlay() -> void:
	var o := _overlay
	var w := float(SIZE.x)
	var h := float(SIZE.y)
	match seg:
		"play":
			# Videon oma sininen ruutu ennen kuvaa.
			o.draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.18, 0.72))
			_text(Vector2(36, 70), "PLAY ▶", 44, Color.WHITE)
			_text(Vector2(36, h - 36), "SP", 30, Color.WHITE)
			_text(Vector2(0, h - 36), "0:00:%02d" % int(_seg_t), 30, Color.WHITE, w - 36, HORIZONTAL_ALIGNMENT_RIGHT)
		"tunnus":
			# Kymmenen uutisten tunnus: sininen kello kymmenessä ja sen vieressä KYMMENEN / UUTISET.
			var a := clampf((_seg_t - 0.9) / 0.5, 0.0, 1.0)
			var band := Rect2(0, h - 128, w, 92)
			MG.grad_rect(o, band, Color(0.0, 0.08, 0.2, 0.75 * a), Color(0.0, 0.03, 0.1, 0.85 * a))
			o.draw_line(band.position, band.position + Vector2(w, 0), Color(0.5, 0.9, 1.0, 0.8 * a), 2.0)
			var sweep := fmod(_seg_t * 0.8, 1.6) * w  # valon pyyhkäisy
			if sweep < w:
				o.draw_rect(Rect2(sweep, band.position.y, 40, band.size.y), Color(1, 1, 1, 0.08 * a))
			_clock_icon(Vector2(w / 2.0 - 150, h - 82), 36.0, a)
			_text(Vector2(w / 2.0 - 100, h - 90), "KYMMENEN", 24, Color(0.75, 0.9, 1.0, a), -1, HORIZONTAL_ALIGNMENT_LEFT, 3)
			_text(Vector2(w / 2.0 - 102, h - 50), "UUTISET", 50, Color(1, 1, 1, a), -1, HORIZONTAL_ALIGNMENT_LEFT, 4)
			if _seg_t < 1.2:
				_text(Vector2(36, 60), "PLAY ▶", 32, Color(1, 1, 1, 0.8))
		"studio":
			# Logo ja kello yläkulmissa, alakolmannes liukuu sisään.
			_ribbon_bug(Vector2(w - 56, 52), 1.0)
			_text(Vector2(28, 52), "22.0%d" % mini(9, 1 + int(_seg_t / 6.0)), 24, Color(1, 1, 1, 0.9), -1, HORIZONTAL_ALIGNMENT_LEFT, 3)
			if headline != "":
				var a := clampf(_seg_t / 0.4, 0.0, 1.0)
				var x0 := lerpf(-w, 0.0, a) + 28.0
				var bar := Rect2(x0 + 120, h - 92, w - 176, 50)
				MG.grad_rect(o, bar, Color(0.05, 0.3, 0.42, 0.95), Color(0.01, 0.1, 0.18, 0.95))
				o.draw_line(bar.position, bar.position + Vector2(bar.size.x, 0), Color(0.5, 0.9, 1.0), 2.0)
				var tag := Rect2(x0, h - 92, 120, 50)
				MG.grad_rect(o, tag, Color(0.12, 0.38, 0.85), Color(0.04, 0.16, 0.5))
				_clock_icon(tag.position + Vector2(22, 25), 15.0, 1.0)
				_text(tag.position + Vector2(40, 33), "UUTISET", 18, Color.WHITE, 78, HORIZONTAL_ALIGNMENT_CENTER)
				_text(bar.position + Vector2(14, 32), headline, 18, Color.WHITE, bar.size.x - 24)
		"saa":
			var bar := Rect2(28, h - 86, 260, 44)
			MG.grad_rect(o, bar, Color(0.95, 0.75, 0.15, 0.95), Color(0.75, 0.5, 0.05, 0.95))
			_text(bar.position + Vector2(0, 30), "SÄÄ  ·  HUOMENNA", 22, Color(0.1, 0.08, 0.05), bar.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# VHS: hennot juovat, reunojen tummuus ja välillä alhaalta nouseva seurantahäiriö.
	for y in range(0, int(h), 3):
		o.draw_line(Vector2(0, y), Vector2(w, y), Color(0, 0, 0, 0.07), 1.0)
	if seg != "play":
		var band := fmod(_t * 0.3, 1.8)
		if band < 1.0:
			var y := h * (1.0 - band)
			o.draw_rect(Rect2(0, y, w, 6), Color(1, 1, 1, 0.06))
			for i in 30:
				var x := fmod(i * 97.3 + _t * 900.0, w)
				o.draw_line(Vector2(x, y + fmod(i * 7.0, 8.0)), Vector2(x + 14 + fmod(i * 13.0, 26.0), y + fmod(i * 7.0, 8.0)),
					Color(1, 1, 1, 0.3), 1.5)
	for k in 6:  # vinjetti
		o.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)).grow(-k * 4.0), Color(0, 0, 0, 0.12), false, 4.0)
