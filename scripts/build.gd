extends RefCounted
## Staattiset apurit primitiivimuotojen rakentamiseen (talot, ihmiset, autot, kyltit)
## sekä jaetut materiaalit ja kohinatekstuuri.

static var _mats := {}
static var _noise: NoiseTexture2D
static var _shaders := {}


static func mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_mats[key] = m
	return _mats[key]


## Materiaali, joka käyttää verteksiväriä (yhdistetyt meshit, MultiMeshit).
static func vcol_mat() -> StandardMaterial3D:
	if not _mats.has("vcol"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		_mats["vcol"] = m
	return _mats["vcol"]


static func unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func noise_tex() -> NoiseTexture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.012
		n.fractal_octaves = 4
		_noise = NoiseTexture2D.new()
		_noise.width = 512
		_noise.height = 512
		_noise.seamless = true
		_noise.generate_mipmaps = true
		_noise.noise = n
	return _noise


static func shader_mat(path: String, params := {}) -> ShaderMaterial:
	if not _shaders.has(path):
		_shaders[path] = load(path)
	var m := ShaderMaterial.new()
	m.shader = _shaders[path]
	m.set_shader_parameter("noise_tex", noise_tex())
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func boxm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(top: float, bottom: float, height: float, segments := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 0
	return c


static func sphere(radius: float, segments := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = segments / 2
	return s


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 12
	c.rings = 4
	return c


static func mesh(parent: Node3D, m: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


## Sylinteri kahden pisteen välille (putket, pinnat).
static func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mi := mesh(parent, cyl(radius, radius, a.distance_to(b), 6), (a + b) / 2.0, color)
	var dir := (b - a).normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) < 0.999:
		var axis := up.cross(dir).normalized()
		mi.basis = Basis(axis, up.angle_to(dir))
	return mi


## Laatikko, oletuksena törmäyksellä (StaticBody3D).
static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, collide := true) -> Node3D:
	if not collide:
		return mesh(parent, boxm(size), pos, color)
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	body.add_child(box_shape(size))
	mesh(body, boxm(size), Vector3.ZERO, color)
	return body


static func box_shape(size: Vector3, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	return cs


static func capsule_shape(radius: float, height: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	cs.shape = cap
	cs.position.y = height / 2.0
	return cs


## Opaste: maailmassa leijuva paikan tai hahmon nimi. Näkyy vain, kun asetus "Näytä opasteet" on päällä
## (main.gd päivittää ryhmän näkyvyyden asetuksen muuttuessa). Puhekuplat eivät ole opasteita.
const GUIDES := "opasteet"


static func guide(parent: Node3D, text: String, pos: Vector3, size: int, color: Color, billboard := true) -> Label3D:
	var l := label(parent, text, pos, size, color, billboard)
	l.add_to_group(GUIDES)
	l.visible = Settings.get_v("show_guides")
	return l


static func label(parent: Node3D, text: String, pos: Vector3, size: int, color: Color, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = maxi(8, size / 8)
	l.outline_modulate = Color(0.1, 0.05, 0.0)
	l.position = pos
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
	parent.add_child(l)
	return l


## Puhekupla hahmon yläpuolelle: teksti on aina saman kokoista ruudulla (fixed_size: läheltä ei paisu jättimäiseksi
## eikä kaukaa kutistu), rivittyy (BUBBLE_WIDTH px) ja siinä on paksu musta ääriviiva, jotta se erottuu mistä
## taustasta tahansa. Teksti asetetaan label.text:llä.
const BUBBLE_WIDTH := 520.0
const BUBBLE_FONT := 40
const BUBBLE_PIXEL := 0.0012
static func bubble(parent: Node3D, pos: Vector3, color := Color.WHITE, scale := 1.0, guard := true) -> Label3D:
	var l: Label3D = preload("res://scripts/bubble.gd").new()
	l.rest = pos
	l.guard = guard
	l.text = ""
	l.font_size = BUBBLE_FONT
	l.pixel_size = BUBBLE_PIXEL * scale  # sisätilojen yläkamera: scale < 1, ettei kupla karkaa ruudun yläreunan yli
	l.fixed_size = true
	l.width = BUBBLE_WIDTH
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = color
	l.outline_size = 18
	l.outline_modulate = Color(0, 0, 0, 1)
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.outline_render_priority = 9
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM  # kasvaa ylöspäin, alareuna pysyy hahmon yläpuolella
	l.offset = Vector2(0, 0)
	parent.add_child(l)
	return l


## Ihminen, jalat y=0:ssa ja kasvot -Z-suuntaan. Solmut LegL/LegR/Upper/ArmL/ArmR animointia varten.
static func person(parent: Node3D, shirt: Color, pants: Color, skin: Color, hair: Color, hunch := 0.0) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var shoe := Color(0.12, 0.1, 0.1)
	for side in [["LegL", -0.11], ["LegR", 0.11]]:
		var leg := Node3D.new()
		leg.name = side[0]
		leg.position = Vector3(side[1], 0.86, 0)
		root.add_child(leg)
		mesh(leg, capsule(0.095, 0.86), Vector3(0, -0.42, 0), pants)
		mesh(leg, boxm(Vector3(0.14, 0.09, 0.27)), Vector3(0, -0.82, -0.05), shoe)
	var upper := Node3D.new()
	upper.name = "Upper"
	upper.position.y = 0.84
	upper.rotation.x = -hunch
	root.add_child(upper)
	var torso := mesh(upper, capsule(0.23, 0.72), Vector3(0, 0.3, 0), shirt)
	torso.scale = Vector3(1.0, 1.0, 0.65)
	for side in [["ArmL", -0.3], ["ArmR", 0.3]]:
		var arm := Node3D.new()
		arm.name = side[0]
		arm.position = Vector3(side[1], 0.56, 0)
		upper.add_child(arm)
		mesh(arm, capsule(0.065, 0.58), Vector3(0, -0.26, 0), shirt)
		mesh(arm, sphere(0.065, 8), Vector3(0, -0.57, 0), skin)
	mesh(upper, cyl(0.06, 0.07, 0.12, 8), Vector3(0, 0.7, 0), skin)
	mesh(upper, sphere(0.155), Vector3(0, 0.86, 0), skin)
	for x in [-0.055, 0.055]:
		mesh(upper, sphere(0.022, 6), Vector3(x, 0.89, -0.14), Color(0.05, 0.05, 0.08))
	mesh(upper, sphere(0.03, 6), Vector3(0, 0.85, -0.155), skin.darkened(0.08))
	var h := mesh(upper, sphere(0.163), Vector3(0, 0.92, 0.025), hair)
	h.scale = Vector3(1.0, 0.75, 1.0)
	return root


## Kävelyanimaatio: jalat ja kädet heiluvat vastakkain. amount 0 = paikallaan.
static func walk_anim(root: Node3D, phase: float, amount: float) -> void:
	var s := sin(phase) * 0.6 * amount
	root.get_node("LegL").rotation.x = s
	root.get_node("LegR").rotation.x = -s
	var upper := root.get_node("Upper")
	upper.get_node("ArmL").rotation.x = -s * 0.8
	upper.get_node("ArmR").rotation.x = s * 0.8


## Auto -Z-suuntaan (tarkka malli vehicles.gd:ssä; ladataan ajon aikana, ettei preload kierrä).
static func car(parent: Node3D, color: Color) -> void:
	load("res://scripts/vehicles.gd").car(parent, color)


## Pysäköity auto törmäyksellä.
static func parked_car(parent: Node3D, pos: Vector3, rot_y: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees.y = rot_y
	parent.add_child(body)
	body.add_child(box_shape(Vector3(1.8, 1.4, 4.2), Vector3(0, 0.8, 0)))
	car(body, color)


## Kyltin levy: pohjaväri, reunus ja teksti molemmin puolin. Paikallinen X = levyn leveys, levy katsoo ±Z.
static func sign_plate(parent: Node3D, text: String, bg: Color, fg: Color, height := 0.3, font := 44,
		border := Color.WHITE, typeface := "") -> Node3D:
	var plate := Node3D.new()
	parent.add_child(plate)
	var lines := text.split("\n")
	var sf: Font = ThemeDB.fallback_font
	if typeface != "":
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray([typeface, "Helvetica", "Arial", "Liberation Sans"])
		sys.font_weight = 500
		sf = sys
	# Leveys fontin todellisesta tekstileveydestä (Label3D: 1 px = 0.005 m) + reunavarat.
	var text_w := 0.0
	for l in lines:
		text_w = maxf(text_w, sf.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, font).x * 0.005)
	var w := text_w + 0.22
	var h := maxf(height * lines.size(), sf.get_height(font) * 0.005 * lines.size() + 0.08)
	mesh(plate, boxm(Vector3(w + 0.06, h + 0.06, 0.02)), Vector3.ZERO, border)
	mesh(plate, boxm(Vector3(w, h, 0.03)), Vector3.ZERO, bg)
	for side in [0.0, PI]:
		var l := Label3D.new()
		l.text = text
		l.font_size = font
		l.pixel_size = 0.005
		l.modulate = fg
		l.outline_size = 0
		l.double_sided = false
		l.rotation.y = side
		l.position = Vector3(0, 0, 0.02 if side == 0.0 else -0.02)
		if typeface != "":
			l.font = sf
		plate.add_child(l)
	plate.set_meta("width", w + 0.06)
	plate.set_meta("height", h + 0.06)
	return plate


## Kadunnimikilpi suomalaiseen tapaan: valkoinen alumiinilevy, musta Helvetica-teksti, kiinnitetty
## viittakiinnikkeillä tolpan sivuun niin, että kilpi sojottaa kadun suuntaan.
static func street_sign(parent: Node3D, pos: Vector3, text: String, yaw: float) -> Node3D:
	var pole := sign_pole(parent, pos, 2.7)
	var arm := Node3D.new()
	arm.position.y = 2.4
	arm.rotation.y = yaw
	pole.add_child(arm)
	var plate := sign_plate(arm, text, Color(0.97, 0.97, 0.95), Color(0.04, 0.04, 0.04), 0.2, 40,
		Color(0.8, 0.8, 0.8), "Helvetica Neue")
	var w: float = plate.get_meta("width")
	plate.position.x = w / 2.0 + 0.05
	for y in [-0.06, 0.06]:
		mesh(arm, boxm(Vector3(0.1, 0.03, 0.05)), Vector3(0.05, y, 0), Color(0.55, 0.56, 0.58))
	return pole


## Laavun opastesymboli: kalteva katto, takatolppa ja pohjaviiva (valkoinen ruskealla).
static func laavu_icon(parent: Node3D, pos: Vector3, size: float, col: Color) -> void:
	var icon := Node3D.new()
	icon.position = pos
	parent.add_child(icon)
	var roof := mesh(icon, boxm(Vector3(size, size * 0.12, 0.012)), Vector3(0, size * 0.1, 0), col)
	roof.rotation.z = -0.5
	mesh(icon, boxm(Vector3(size * 0.1, size * 0.62, 0.012)), Vector3(-size * 0.4, -size * 0.06, 0), col)
	mesh(icon, boxm(Vector3(size * 1.05, size * 0.09, 0.012)), Vector3(0, -size * 0.36, 0), col)
	mesh(icon, sphere(size * 0.09, 8), Vector3(size * 0.28, -size * 0.25, 0.005), Color(1.0, 0.55, 0.15))


## Ruskea puinen reittiviitta: nuolenkärkinen lauta tolpassa, symboli, teksti molemmin puolin.
static func trail_sign(parent: Node3D, pos: Vector3, text: String, yaw: float) -> Node3D:
	var brown := Color(0.36, 0.2, 0.1)
	var cream := Color(0.98, 0.95, 0.86)
	var post := Node3D.new()
	post.position = pos
	parent.add_child(post)
	mesh(post, boxm(Vector3(0.1, 1.9, 0.1)), Vector3(0, 0.95, 0), Color(0.42, 0.27, 0.15))
	mesh(post, PrismMesh.new(), Vector3(0, 1.93, 0), Color(0.3, 0.18, 0.1)).scale = Vector3(0.12, 0.08, 0.12)
	var arm := Node3D.new()
	arm.position.y = 1.55
	arm.rotation.y = yaw
	post.add_child(arm)
	var tf := SystemFont.new()
	tf.font_names = PackedStringArray(["Helvetica Neue", "Helvetica", "Arial"])
	tf.font_weight = 600
	var w := tf.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x * 0.005 + 0.5
	mesh(arm, boxm(Vector3(w, 0.26, 0.04)), Vector3(w / 2.0 + 0.06, 0, 0), brown)
	var tip := PrismMesh.new()
	tip.size = Vector3(0.26, 0.2, 0.04)
	mesh(arm, tip, Vector3(w + 0.16, 0, 0), brown, Vector3(0, 0, -90))
	for z in [0.022, -0.022]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 36
		l.pixel_size = 0.005
		l.modulate = cream
		l.outline_size = 0
		l.double_sided = false
		l.rotation.y = 0.0 if z > 0.0 else PI
		l.position = Vector3(w / 2.0 + 0.16, 0, z)
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Helvetica Neue", "Helvetica", "Arial"])
		sf.font_weight = 600
		l.font = sf
		arm.add_child(l)
		laavu_icon(arm, Vector3(0.2, 0, z * 1.1), 0.19, cream)
	return post


## Harmaa kylttitolppa, palauttaa tolpan (kiinnitä levyt tähän).
static func sign_pole(parent: Node3D, pos: Vector3, height := 2.6) -> Node3D:
	var pole := Node3D.new()
	pole.position = pos
	parent.add_child(pole)
	mesh(pole, cyl(0.03, 0.03, height, 10), Vector3(0, height / 2.0, 0), Color(0.62, 0.63, 0.65))
	mesh(pole, cyl(0.04, 0.04, 0.05, 8), Vector3(0, height, 0), Color(0.5, 0.5, 0.52))
	return pole


## Valkoinen nuoli levyn viereen (osoittaa +X).
static func sign_arrow(plate: Node3D, x: float, fg: Color) -> void:
	for z in [0.02, -0.02]:
		mesh(plate, boxm(Vector3(0.12, 0.05, 0.01)), Vector3(x - 0.04, 0, z), fg)
		var head := PrismMesh.new()
		head.size = Vector3(0.12, 0.08, 0.01)
		mesh(plate, head, Vector3(x + 0.06, 0, z), fg, Vector3(0, 0, -90))


## Litteä näkökenttäviuhka lattiatasossa, kärki origossa ja aukeaa -Z-suuntaan.
static func vision_fan(radius: float, half_angle: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 16
	for i in steps:
		var a0 := -half_angle + 2.0 * half_angle * i / steps
		var a1 := -half_angle + 2.0 * half_angle * (i + 1) / steps
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a0), 0, -cos(a0)) * radius)
		st.add_vertex(Vector3(sin(a1), 0, -cos(a1)) * radius)
	return st.commit()


## Yaw, jolla -Z osoittaa suuntaan dir (XZ-tasossa).
static func yaw_to(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## Onko näköyhteys kahden pisteen välillä (poissulkien annetut kappaleet).
static func line_of_sight(from_node: Node3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	return from_node.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Kerää monta primitiiviä yhdeksi verteksivärilliseksi meshiksi (vähemmän piirtokutsuja).
class Batch:
	static var _cache := {}
	const Terrain := preload("res://scripts/terrain.gd")

	var lift := false  # true: jokainen piste nostetaan maaston korkeudelle (maailman rakennukset, aidat)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()

	func add(m: PrimitiveMesh, xf: Transform3D, color: Color) -> void:
		var arr: Array = _arrays_for(m)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var base := verts.size()
		var nb := xf.basis.inverse().transposed()
		for i in v.size():
			var p: Vector3 = xf * v[i]
			if lift:
				p.y += Terrain.h(p.x, p.z)
			verts.append(p)
			norms.append((nb * n[i]).normalized())
			cols.append(color)
			uvs.append(uv[i] if i < uv.size() else Vector2.ZERO)
		for i in ind:
			idx.append(base + i)

	func is_empty() -> bool:
		return verts.is_empty()

	func commit() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return am

	static func _arrays_for(m: PrimitiveMesh) -> Array:
		var key := "%s:%s" % [m.get_class(), _mesh_key(m)]
		if not _cache.has(key):
			_cache[key] = m.get_mesh_arrays()
		return _cache[key]

	static func _mesh_key(m: PrimitiveMesh) -> String:
		if m is BoxMesh:
			return str(m.size)
		if m is PrismMesh:
			return str(m.size)
		if m is CylinderMesh:
			return "%s/%s/%s/%s" % [m.top_radius, m.bottom_radius, m.height, m.radial_segments]
		if m is SphereMesh:
			return "%s/%s" % [m.radius, m.radial_segments]
		if m is QuadMesh:
			return str(m.size)
		return str(m.get_instance_id())
