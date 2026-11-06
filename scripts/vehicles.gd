extends RefCounted
## Tarkemmat ajoneuvot: henkilöauto (maalipinta, lasit, kattopilarit, pyöräkotelot, vanteet, valot,
## suomalaiset rekisterikilvet) sekä moderni ja vanha traktori (kuviopinnaiset renkaat, lokasuojat,
## lasiohjaamo, maski säleikköineen, pakoputki, etupainot, nostolaite, majakka).

const B := preload("res://scripts/build.gd")

## Poliisi-Saabin (saab(police = true)) vilkkupalkin kupujen keskipisteet ja koko: vilkkuvat valot (police_lights) peittävät
## kuvut juuri ja juuri.
const SAAB_DOMES := [Vector3(-0.4, 1.555, 0.0), Vector3(0.4, 1.555, 0.0)]
const SAAB_DOME_SIZE := Vector3(0.42, 0.11, 0.21)

static var _mats := {}
static var _merged := {}  # avain -> ArrayMesh (yksi pinta materiaalia kohden)


## Solmun suorat MeshInstance3D-lapset indeksistä from alkaen yhdeksi meshiksi, jossa yksi pinta materiaalia
## kohden: auto oli ~70 osaa ja pyörä ~13 (kymmeniä piirtokutsuja autoa kohden). Valmis mesh jaetaan avaimen
## mukaan (sama malli ja väri = sama mesh). Osiin ei viitata myöhemmin, joten ne vapautetaan.
static func _merge_parts(parent: Node3D, from: int, key: String) -> MeshInstance3D:
	var parts: Array[MeshInstance3D] = []
	for c in parent.get_children().slice(from):
		if c is MeshInstance3D and c.get_child_count() == 0:
			parts.append(c)
	if parts.is_empty():
		return null
	var am: ArrayMesh = _merged.get(key)
	if am == null:
		var by_mat := {}
		var order: Array = []
		for mi in parts:
			var m: Material = mi.material_override
			if not by_mat.has(m):
				var st := SurfaceTool.new()
				by_mat[m] = st
				order.append(m)
			(by_mat[m] as SurfaceTool).append_from(mi.mesh, 0, mi.transform)
		am = ArrayMesh.new()
		for m in order:
			(by_mat[m] as SurfaceTool).commit(am)
			am.surface_set_material(am.get_surface_count() - 1, m)
		_merged[key] = am
	var out := MeshInstance3D.new()
	out.mesh = am
	parent.add_child(out)
	for mi in parts:
		mi.free()
	return out


static func paint(color: Color) -> StandardMaterial3D:
	var key := "paint" + color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = 0.45
		m.roughness = 0.28
		m.clearcoat_enabled = true
		m.clearcoat = 0.8
		m.clearcoat_roughness = 0.1
		_mats[key] = m
	return _mats[key]


static func _mat(key: String, color: Color, metallic: float, rough: float, alpha := 1.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color, alpha)
		m.metallic = metallic
		m.roughness = rough
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func glass() -> StandardMaterial3D:
	return _mat("glass", Color(0.08, 0.1, 0.13), 0.6, 0.04)


static func cab_glass() -> StandardMaterial3D:
	return _mat("cabglass", Color(0.35, 0.45, 0.5), 0.3, 0.05, 0.28)


static func chrome() -> StandardMaterial3D:
	return _mat("chrome", Color(0.8, 0.8, 0.82), 1.0, 0.18)


static func rubber() -> StandardMaterial3D:
	return _mat("rubber", Color(0.05, 0.05, 0.05), 0.0, 0.92)


static func plastic() -> StandardMaterial3D:
	return _mat("plastic", Color(0.08, 0.08, 0.09), 0.0, 0.6)


static func lamp(color: Color) -> StandardMaterial3D:
	var key := "lamp" + color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.6
		m.roughness = 0.1
		_mats[key] = m
	return _mats[key]


static func part(parent: Node3D, m: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Laatta kahden pisteen välille YZ-tasossa (tuulilasi, takalasi, pilarit).
static func slab(parent: Node3D, p0: Vector3, p1: Vector3, width: float, thick: float, mat: Material) -> MeshInstance3D:
	var z := (p1 - p0).normalized()
	var x := Vector3.RIGHT
	var y := z.cross(x).normalized()
	var mi := part(parent, B.boxm(Vector3(width, thick, p0.distance_to(p1))), (p0 + p1) / 2.0, mat)
	mi.basis = Basis(x, y, z)
	return mi


## Pyörä kuviopinnoin: palauttaa pyörivän solmun (akseli X). slots > 0: pölykapselissa niin monta vinoa
## turbiiniuraa (Saab 900).
static func wheel(parent: Node3D, pos: Vector3, r: float, w: float, lugs: int, rim_mat: Material, rim_r := 0.6, slots := 0) -> Node3D:
	var piv := Node3D.new()
	piv.position = pos
	parent.add_child(piv)
	part(piv, B.cyl(r * 0.94, r * 0.94, w, 20), Vector3.ZERO, rubber(), Vector3(0, 0, PI / 2.0))
	for side in [-1.0, 1.0]:
		part(piv, B.cyl(r * rim_r, r * rim_r, 0.02, 16), Vector3(side * (w / 2.0 + 0.005), 0, 0), rim_mat, Vector3(0, 0, PI / 2.0))
		# Keskiö ja pultit satiinikromia: chrome() näkyy ilman heijastuksia mustana.
		var cap := _mat("ponykromi", Color(0.86, 0.87, 0.89), 0.45, 0.3)
		part(piv, B.cyl(r * 0.14, r * 0.14, 0.04, 12), Vector3(side * (w / 2.0 + 0.02), 0, 0), cap, Vector3(0, 0, PI / 2.0))
		for k in 5:
			var a := TAU * k / 5.0
			part(piv, B.cyl(r * 0.035, r * 0.035, 0.03, 6), Vector3(side * (w / 2.0 + 0.02), cos(a) * r * 0.25, sin(a) * r * 0.25),
				cap, Vector3(0, 0, PI / 2.0))
		for k in slots:
			var a := TAU * k / slots
			var slot := part(piv, B.boxm(Vector3(0.012, r * 0.045, r * 0.2)), Vector3(side * (w / 2.0 + 0.01), sin(a) * r * 0.5, cos(a) * r * 0.5), plastic())
			slot.basis = Basis(Vector3.RIGHT, -a + side * 0.35)  # ura säteen suuntaan, hieman vinossa kuin turbiinin siipi
	if lugs > 0:
		for k in lugs:
			var a := TAU * k / lugs
			for side in [-1.0, 1.0]:
				var lug := part(piv, B.boxm(Vector3(w * 0.46, r * 0.11, r * 0.2)), Vector3(side * w * 0.24, cos(a) * r * 0.97, sin(a) * r * 0.97), rubber())
				lug.basis = Basis(Vector3.RIGHT, a) * Basis(Vector3.UP, side * 0.45)
	else:
		part(piv, B.cyl(r, r, w * 0.8, 24), Vector3.ZERO, rubber(), Vector3(0, 0, PI / 2.0))
	_merge_parts(piv, 0, "wheel/%s/%s/%d/%s/%s/%d" % [r, w, lugs, rim_mat.get_instance_id(), rim_r, slots])
	return piv


static func _plate(parent: Node3D, pos: Vector3, back: bool, text: String) -> void:
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = 0.0 if back else PI
	parent.add_child(p)
	part(p, B.boxm(Vector3(0.52, 0.12, 0.015)), Vector3.ZERO, _mat("plate", Color(0.97, 0.97, 0.95), 0.2, 0.4))
	part(p, B.boxm(Vector3(0.05, 0.12, 0.018)), Vector3(-0.235, 0, 0), _mat("eu", Color(0.05, 0.2, 0.6), 0.0, 0.5))
	var l := Label3D.new()
	l.text = text
	l.font_size = 22
	l.pixel_size = 0.004
	l.modulate = Color.BLACK
	l.outline_size = 0
	l.double_sided = false
	l.position = Vector3(0.02, 0, 0.01)
	p.add_child(l)


## Henkilöauto -Z-suuntaan, n. 1,8 × 1,45 × 4,3 m. Palauttaa pyörät pyöritystä varten.
static func car(parent: Node3D, color: Color, plate := "") -> Array[Node3D]:
	var first := parent.get_child_count()
	var body := paint(color)
	if plate == "":
		plate = "%s%s%s-%d" % [char(65 + randi() % 26), char(65 + randi() % 26), char(65 + randi() % 26), 100 + randi() % 900]
	part(parent, B.boxm(Vector3(1.8, 0.5, 4.3)), Vector3(0, 0.6, 0), body)
	part(parent, B.boxm(Vector3(1.82, 0.12, 4.32)), Vector3(0, 0.4, 0), plastic())  # helmapuskuri
	slab(parent, Vector3(0, 0.84, -2.15), Vector3(0, 0.95, -0.95), 1.76, 0.1, body)  # konepelti
	slab(parent, Vector3(0, 0.95, 1.4), Vector3(0, 0.9, 2.15), 1.76, 0.1, body)  # takaluukku
	# Ohjaamo: tumma lasi sisällä, pilarit ja katto maalattuina.
	var wf0 := Vector3(0, 0.96, -0.95)
	var wf1 := Vector3(0, 1.42, -0.45)
	var wr0 := Vector3(0, 1.42, 0.95)
	var wr1 := Vector3(0, 0.96, 1.4)
	part(parent, B.boxm(Vector3(1.5, 0.44, 1.8)), Vector3(0, 1.18, 0.25), glass())
	slab(parent, wf0, wf1, 1.52, 0.04, glass())
	slab(parent, wr0, wr1, 1.52, 0.04, glass())
	part(parent, B.boxm(Vector3(1.56, 0.07, 1.45)), Vector3(0, 1.45, 0.25), body)
	for sx in [-0.77, 0.77]:
		slab(parent, wf0 + Vector3(sx, 0, 0), wf1 + Vector3(sx, 0, 0), 0.07, 0.07, body)
		slab(parent, wr0 + Vector3(sx, 0, 0), wr1 + Vector3(sx, 0, 0), 0.1, 0.07, body)
		part(parent, B.boxm(Vector3(0.06, 0.46, 0.1)), Vector3(sx, 1.18, 0.3), body)  # B-pilari
		part(parent, B.boxm(Vector3(0.06, 0.035, 1.9)), Vector3(sx, 0.96, 0.22), chrome())  # ikkunalista
		# Sivupeili, ovisaumat ja kahvat.
		part(parent, B.boxm(Vector3(0.14, 0.1, 0.18)), Vector3(sx * 1.2, 1.02, -0.8), body)
		part(parent, B.boxm(Vector3(0.02, 0.08, 0.14)), Vector3(sx * 1.28, 1.02, -0.8), glass())
		for dz in [-0.95, 0.3, 1.35]:
			part(parent, B.boxm(Vector3(0.01, 0.46, 0.012)), Vector3(sx * 1.171, 0.65, dz), plastic())
		for hz in [-0.1, 1.05]:
			part(parent, B.boxm(Vector3(0.03, 0.035, 0.16)), Vector3(sx * 1.175, 0.78, hz), chrome())
		# Pyöräkotelot.
		for wz in [-1.35, 1.35]:
			part(parent, B.cyl(0.4, 0.4, 0.04, 20), Vector3(sx * 1.155, 0.38, wz), plastic(), Vector3(0, 0, PI / 2.0))
	# Keula: maski, ajovalot, puskuri, kilpi.
	part(parent, B.boxm(Vector3(0.9, 0.2, 0.04)), Vector3(0, 0.68, -2.16), plastic())
	for k in 3:
		part(parent, B.boxm(Vector3(0.86, 0.02, 0.05)), Vector3(0, 0.6 + k * 0.07, -2.17), chrome())
	for sx in [-0.62, 0.62]:
		part(parent, B.boxm(Vector3(0.38, 0.13, 0.05)), Vector3(sx, 0.74, -2.16), lamp(Color(1.0, 0.98, 0.9)))
		part(parent, B.boxm(Vector3(0.36, 0.1, 0.05)), Vector3(sx, 0.76, 2.16), lamp(Color(0.8, 0.04, 0.03)))
		part(parent, B.boxm(Vector3(0.12, 0.08, 0.05)), Vector3(sx * 1.2, 0.76, 2.165), lamp(Color(1.0, 0.5, 0.1)))
	part(parent, B.boxm(Vector3(1.84, 0.18, 0.12)), Vector3(0, 0.45, -2.18), plastic())
	part(parent, B.boxm(Vector3(1.84, 0.18, 0.12)), Vector3(0, 0.45, 2.18), plastic())
	_plate(parent, Vector3(0, 0.47, -2.25), false, plate)
	_plate(parent, Vector3(0, 0.62, 2.18), true, plate)
	_merge_parts(parent, first, "car/" + color.to_html())
	var wheels: Array[Node3D] = []
	for sx in [-0.84, 0.84]:
		for wz in [-1.35, 1.35]:
			wheels.append(wheel(parent, Vector3(sx, 0.34, wz), 0.34, 0.22, 0, chrome(), 0.62))
	return wheels


## Ohut kupera monikulmio sivuprofiilina x:n kohdalla (pisteet (z, y)), molemmin puolin näkyvä: C-pilarin levy.
static func _side_panel(parent: Node3D, x: float, pts: Array, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		st.set_normal(Vector3(side, 0, 0))
		for k in range(1, pts.size() - 1):
			var tri := [pts[0], pts[k], pts[k + 1]] if side < 0.0 else [pts[0], pts[k + 1], pts[k]]
			for p: Vector2 in tri:
				st.add_vertex(Vector3(side * 0.004, p.y, p.x))
	st.index()  # _merge_parts: indeksoimaton verkko katoaa, jos se on materiaalinsa ensimmäinen osa
	var mi := part(parent, st.commit(), Vector3(x, 0, 0), mat)
	return mi


## Kolmio normaalin n puolelle näkyväksi: kiertosuunta valitaan normaalista (Godotissa etupinta myötäpäivään).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	st.set_normal(n)
	for p in [a, b, c]:
		st.set_uv(Vector2(p.x + p.z, p.y))  # UV ja tangentit kuten BoxMeshissä: _merge_parts yhdistää samaan pintaan
		st.add_vertex(p)


## Viistetty kappale: sivuprofiili pts (z, y; saa olla kovera) pursotetaan X-suunnassa -half_w…half_w, ja
## profiilin reunat viistetään kyljissä 45° c:n verran (kylki on profiili c:n verran sisennettynä). Profiilin
## kulmat viistetään pisteinä profiilissa. Ulkomitat ovat profiilin ja leveyden mukaiset: viiste ei kasvata
## kappaletta. Tasaiset normaalit: viisteeseen tulee oma valoreuna.
static func _bevel(parent: Node3D, pts: PackedVector2Array, half_w: float, c: float, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var n := pts.size()
	var area := 0.0
	for i in n:
		area += pts[i].cross(pts[(i + 1) % n])
	var outward: Array[Vector2] = []  # reunan i (pts[i] -> pts[i+1]) ulkonormaali
	for i in n:
		var e := (pts[(i + 1) % n] - pts[i]).normalized()
		outward.append(Vector2(e.y, -e.x) if area > 0.0 else Vector2(-e.y, e.x))
	var inset := PackedVector2Array()
	for i in n:
		var ep: Vector2 = pts[(i + n - 1) % n] - outward[(i + n - 1) % n] * c
		var en: Vector2 = pts[i] - outward[i] * c
		var hit = Geometry2D.line_intersects_line(ep, pts[i] - pts[(i + n - 1) % n], en, pts[(i + 1) % n] - pts[i])
		inset.append(hit if hit != null else en)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := half_w - c
	for i in n:
		var j := (i + 1) % n
		var o: Vector2 = outward[i]
		var on := Vector3(0, o.y, o.x)
		var a := Vector3(0, pts[i].y, pts[i].x)
		var b := Vector3(0, pts[j].y, pts[j].x)
		_tri(st, a + Vector3(-hx, 0, 0), a + Vector3(hx, 0, 0), b + Vector3(hx, 0, 0), on)
		_tri(st, a + Vector3(-hx, 0, 0), b + Vector3(hx, 0, 0), b + Vector3(-hx, 0, 0), on)
		var ai := Vector3(0, inset[i].y, inset[i].x)
		var bi := Vector3(0, inset[j].y, inset[j].x)
		for s in [1.0, -1.0]:
			var bn := (on + Vector3(s, 0, 0)).normalized()
			_tri(st, a + Vector3(s * hx, 0, 0), b + Vector3(s * hx, 0, 0), bi + Vector3(s * half_w, 0, 0), bn)
			_tri(st, a + Vector3(s * hx, 0, 0), bi + Vector3(s * half_w, 0, 0), ai + Vector3(s * half_w, 0, 0), bn)
	var idx := Geometry2D.triangulate_polygon(inset)
	for s in [1.0, -1.0]:
		for k in range(0, idx.size(), 3):
			var t: Array[Vector3] = []
			for m in 3:
				t.append(Vector3(s * half_w, inset[idx[k + m]].y, inset[idx[k + m]].x))
			_tri(st, t[0], t[1], t[2], Vector3(s, 0, 0))
	st.index()  # _merge_parts yhdistää indeksoituihin BoxMesheihin: indeksoimattomat kärjet jäisivät ilman kolmioita
	st.generate_tangents()
	return part(parent, st.commit(), pos, mat)


## Pyöränkaaren reunus: poikkileikkaus (säde, ulostulo) pyöräytetään X-akselin ympäri kulmasta a0 kulmaan PI - a0
## (0 = +Z, PI/2 = ylös). Kaari nousee kyljestä x0:ssa sx-suuntaan depth verran ja laskee ulkoreunaa kohti.
static func _arch(parent: Node3D, x0: float, sx: float, center: Vector2, r0: float, r1: float, depth: float, a0: float, mat: Material) -> MeshInstance3D:
	var crest := r0 + (r1 - r0) * 0.35  # kapea tasainen harja sisäreunassa, siitä loiva lasku kylkeen: erottuu varjostuksena
	var prof: Array[Vector2] = [Vector2(r0, 0.0), Vector2(r0, depth), Vector2(crest, depth), Vector2(r1, 0.0)]  # (r, ulos)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 32
	for i in seg:
		var ang: Array[float] = [lerpf(a0, PI - a0, float(i) / seg), lerpf(a0, PI - a0, float(i + 1) / seg)]
		var mid := (ang[0] + ang[1]) / 2.0
		var radial := Vector3(0, sin(mid), cos(mid))
		for k in prof.size() - 1:
			var e := prof[k + 1] - prof[k]
			var nrm := Vector2(-e.y, e.x).normalized()  # profiili kiertää vastapäivään: sisäreuna -r, etupinta +ulos, ulkoreuna +r
			var n3 := (radial * nrm.x + Vector3(sx * nrm.y, 0, 0)).normalized()
			var q: Array[Vector3] = []
			for a: float in ang:
				for pr: Vector2 in [prof[k], prof[k + 1]]:
					q.append(Vector3(x0 + sx * pr.y, center.y + sin(a) * pr.x, center.x + cos(a) * pr.x))
			_tri(st, q[0], q[1], q[3], n3)
			_tri(st, q[0], q[3], q[2], n3)
	st.index()
	st.generate_tangents()
	return part(parent, st.commit(), Vector3.ZERO, mat)


## Laatikko, jonka kaikki 12 reunaa on viistetty c:n verran (ulkomitat = size).
static func _bevel_box(parent: Node3D, size: Vector3, pos: Vector3, c: float, mat: Material) -> MeshInstance3D:
	var hz := size.z / 2.0
	var hy := size.y / 2.0
	var pts := PackedVector2Array([Vector2(-hz + c, -hy), Vector2(hz - c, -hy), Vector2(hz, -hy + c), Vector2(hz, hy - c),
		Vector2(hz - c, hy), Vector2(-hz + c, hy), Vector2(-hz, hy - c), Vector2(-hz, -hy + c)])
	return _bevel(parent, pts, size.x / 2.0, c, mat, pos)


## Päivin Hyundai Pony (Pony 2, 1982–90, Giugiaro) -Z-suuntaan: 5-ovinen viistoperä n. 1,6 × 1,38 × 4,0 m
## puskureineen, akseliväli 2,38 m. Esikuvat .claude/tyo/pony-realistinen/esikuva_pony2*.jpg: matala tasainen
## konepelti, suorakaiteiset ajovalot ja kulmavilkut, musta ruudukkosäleikkö HYUNDAI-merkillä, leveät mustat
## puskurit punaisella raidalla, kolme sivuikkunaa mustin kehyksin, leveä takapilari, viisto takaluukku ja
## vaakatakavalot kilven molemmin puolin. Kori viistetyin reunoin (_bevel), pyöreät pyöränkaaret (_arch), läpinäkyvät
## lasit ja sisusta (selkänojat niskatukineen, kojelauta, ratti). Palauttaa pyörät kuten car().
static func pony(parent: Node3D, color: Color, plate := "") -> Array[Node3D]:
	# Mitat sivukuvasta esikuva_pony2_sivu.jpg (233 px/m akselivälistä): pyörät z ±1,19, keula 0,75 ja perä 0,87 pyörän
	# keskeltä puskureineen, tuulilasi z -0,68…-0,15, katto päättyy z 1,18, takalasi viistää (1,33; 1,18) -> (0,98; 1,88).
	const SIDE := 0.80  # kyljen x
	const SILL := 0.20  # alakorin alapinta
	const NOSE_Y := 0.76  # konepellin etureuna: pitkä matala pelti laskee BELT -> NOSE_Y
	const BELT := 0.87  # vyötärölinja, ikkunoiden alareuna
	const ROOF := 1.38  # katon yläpinta (esikuva 1380 mm)
	const ROOF_T := 0.05
	const FRONT := -1.86
	const BACK := 1.96
	const WS0 := -0.68  # tuulilasin alareuna z
	const WS1 := -0.15  # tuulilasin yläreuna z
	const HT0 := 1.18  # takalasin yläreuna z (katon takareuna)
	const HT1 := BACK - 0.08  # takalasin alareuna z; sen alla lyhyt pysty peltiosa takavaloineen
	const HT_Y := 0.98  # takalasin alareuna y
	const BP := 0.32  # B-pilari z
	const RW := 0.88  # takaoven ikkunan takareuna = kolmion muotoisen takasivuikkunan etureuna z
	const QA := 1.04  # takasivuikkunan takareuna ylhäällä z (C-pilari viistää taakse)
	const QB := 1.30  # takasivuikkunan takareuna vyölinjalla z
	const GLASS_W := 1.36
	const LAMP_Y := 0.63  # ajovalojen ja vilkkujen keskikorkeus
	const TAIL_Y := 0.72  # takavalojen ja takakilven keskikorkeus
	const BUMP_Y := 0.38  # puskurien keskikorkeus
	const WHEEL_R := 0.29  # 155/80R13: 330 + 2 × 124 = 578 mm
	const WHEEL_Z := 1.19  # akseliväli 2,38 m
	const ARCH_R := WHEEL_R + 0.045  # pyöränkaaren säde
	const ARCH_Y := ARCH_R  # kaaren keskipiste renkaan keskeltä ylempänä: kotelo ulottuu maahan asti, ei alle
	const LIP_R := ARCH_R + 0.045  # kaaren maalatun reunuksen ulkosäde
	const SC := 0.03  # kyljen reunojen viiste
	const CF := 0.035  # keulan ja perän ylä- ja alareunan viiste
	var first := parent.get_child_count()
	var body := paint(color)
	var win := _mat("ponylasi", Color(0.22, 0.27, 0.32), 0.3, 0.05, 0.32)  # Ponyn oma läpinäkyvä lasi (ei glass()): sisusta näkyy
	var frame := plastic()
	var bar := _mat("ponykromi", Color(0.86, 0.87, 0.89), 0.45, 0.3)  # satiinikromi: chrome() näkyy ilman heijastuksia mustana
	var stripe := _mat("ponyraita", Color(0.75, 0.08, 0.06), 0.0, 0.5)
	if plate == "":
		plate = "%s%s%s-%d" % [char(65 + randi() % 26), char(65 + randi() % 26), char(65 + randi() % 26), 100 + randi() % 900]
	var top := ROOF - ROOF_T  # lasien yläreuna
	var roof_x := GLASS_W / 2.0 + 0.03  # katon alareunan x = pilarien ja sadevesilistojen ulkopinta
	const ROOF_C := 0.02  # katon reunojen viiste: katto on viisteen verran leveämpi, jotta alareuna on roof_x:ssä
	# Alakori, konepelti ja takaluukun pystyosa yhtenä sivuprofiilina: kyljen reunat viistetty SC:n verran
	# (vyölinja, keulan ja perän pystykulmat, helma) ja profiilin kulmat CF:n verran (keulan ja perän yläreuna).
	var nose_cf: float = NOSE_Y + (BELT - NOSE_Y) * CF / (WS0 - FRONT)  # konepellin pinta CF:n päässä keulasta
	_bevel(parent, PackedVector2Array([Vector2(FRONT, SILL + CF), Vector2(FRONT + CF, SILL), Vector2(BACK - CF, SILL),
		Vector2(BACK, SILL + CF), Vector2(BACK, HT_Y - CF), Vector2(BACK - CF, HT_Y), Vector2(HT1 - 0.04, HT_Y),
		Vector2(HT1 - 0.04, BELT), Vector2(WS0, BELT), Vector2(FRONT + CF, nose_cf), Vector2(FRONT, NOSE_Y - CF)]), SIDE, SC, body)
	# Ikkunat ohuina läpinäkyvinä levyinä: tuulilasi, takalasi ja sivulasit (takasivuikkunan takana C-pilarin levy).
	var wf0 := Vector3(0, BELT, WS0)
	var wf1 := Vector3(0, top, WS1)
	var wr0 := Vector3(0, top, HT0)
	var wr1 := Vector3(0, HT_Y, HT1)
	for sx in [-1.0, 1.0]:
		_side_panel(parent, sx * GLASS_W / 2.0, [Vector2(WS0, BELT), Vector2(WS1, top), Vector2(QA, top), Vector2(QB, BELT)], win)
	# Sisusta lasien läpi (vasemmanpuoleinen ohjaus: kuljettaja -X:ssä, etu -Z). Kori on umpinainen vyölinjaan asti,
	# joten istuinosat jäävät sen sisään; näkyvissä ovat selkänojat niskatukineen, kojelauta, ratti ja verhoilu.
	_cabin(parent, BELT, top, WS0, WS1, HT0, HT1, HT_Y, GLASS_W, bar, 0.36, 1.02, 1.5, 0.62, ISTUIMET.pony.ratti)
	slab(parent, wf0, wf1, GLASS_W + 0.02, 0.04, win)  # tuulilasi
	slab(parent, wr0, wr1, GLASS_W + 0.02, 0.04, win)  # takaluukun lasi
	# Luukun lyhyen pystyn peltiosan (takavalot ja kilpi, alakorin profiilissa) yläreunassa pieni musta huulispoileri.
	slab(parent, Vector3(0, HT_Y + 0.012, HT1 - 0.02), Vector3(0, HT_Y + 0.035, BACK + 0.04), GLASS_W + 0.04, 0.025, frame)
	_bevel_box(parent, Vector3((roof_x + ROOF_C) * 2.0, ROOF_T, HT0 - WS1 + 0.04), Vector3(0, ROOF - ROOF_T / 2.0, (WS1 + HT0) / 2.0), ROOF_C, body)  # katto
	# Takalasin musta kehys ja pyyhin, konepellin takareunan tuuletusritilät, tuulilasin pyyhkimet.
	var hat := (wr1 - wr0).normalized()
	slab(parent, wr0, wr0.lerp(wr1, 0.05), GLASS_W, 0.05, frame)
	slab(parent, wr0.lerp(wr1, 0.96), wr1, GLASS_W, 0.05, frame)
	# Katon liitokset: tuulilasin yläreunan kumilista (muuten kattoverhoilu näkyy raosta vaaleana juovana) ja
	# sadevesilistat katon kyljissä katon alareunan ja ikkunakehyksen välisen sauman päällä, pilarien välissä.
	slab(parent, wf0.lerp(wf1, 0.95), wf1 + (wf1 - wf0).normalized() * 0.01, GLASS_W + 0.02, 0.05, frame)
	for sx in [-1.0, 1.0]:
		var rz0 := WS1 + 0.015  # A-pilarin yläpää on tuulilasin linjassa: lista alkaa heti sen takaa, ettei verhoilu näy raosta
		var rz1 := HT0 - 0.04
		part(parent, B.boxm(Vector3(0.025, 0.035, rz1 - rz0)), Vector3(sx * (roof_x - 0.0125), top + 0.005, (rz0 + rz1) / 2.0), frame)
	part(parent, B.boxm(Vector3(0.5, 0.012, 0.02)), wr0.lerp(wr1, 0.75) + hat.cross(Vector3.RIGHT) * 0.03, frame)
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.38, 0.012, 0.06)), Vector3(sx * 0.38, BELT - 0.12 * (BELT - NOSE_Y) / (WS0 - FRONT) + 0.008, WS0 - 0.12), frame)  # tuuletusritilä konepellin pinnassa
		var wp := part(parent, B.boxm(Vector3(0.5, 0.015, 0.02)), wf0.lerp(wf1, 0.08) + Vector3(sx * 0.3 - 0.06, 0.03, 0), frame)  # pyyhin tuulilasin päällä
		wp.rotation.z = 0.08 * sx
	for sx in [-1.0, 1.0]:
		# Pilarien ulkopinta katon alareunan tasossa (roof_x) ja yläpää katon alle: muuten pilari porrastuu katon reunasta ulos.
		var ax: float = sx * (roof_x - 0.035)
		slab(parent, wf0 + Vector3(ax, 0, 0), wf1 + Vector3(ax, 0, 0) + (wf1 - wf0).normalized() * 0.02, 0.07, 0.06, body)  # A-pilari
		var ex: float = sx * (roof_x - 0.05)
		slab(parent, wr0 + Vector3(ex, 0, 0) - hat * 0.03, wr1 + Vector3(ex, 0, 0), 0.1, 0.06, body)  # takaluukun reuna
		slab(parent, wr0 + Vector3(sx * (GLASS_W / 2.0 - 0.01), 0, 0), wr1 + Vector3(sx * (GLASS_W / 2.0 - 0.01), 0, 0), 0.03, 0.05, frame)  # takalasin sivukehys
		# Leveä C-pilari: maalattu levy sivulasin päällä takasivuikkunan viistosta takareunasta takaluukkuun.
		var cx: float = sx * (GLASS_W / 2.0 + 0.012)
		_side_panel(parent, cx, [Vector2(QA, top), Vector2(HT0, top), Vector2(HT1, HT_Y), Vector2(HT1, BELT), Vector2(QB, BELT)], body)
		# Mustat ikkunakehykset: yläreuna, vyölista, B-pilari, takaoven ikkunan takareuna ja takasivuikkunan viisto reuna.
		var fx: float = sx * (GLASS_W / 2.0 + 0.016)
		part(parent, B.boxm(Vector3(0.02, 0.03, QA - WS1)), Vector3(fx, top - 0.015, (WS1 + QA) / 2.0), frame)
		part(parent, B.boxm(Vector3(0.02, 0.03, QB - WS0)), Vector3(fx, BELT + 0.015, (WS0 + QB) / 2.0), frame)
		slab(parent, Vector3(fx, top, QA), Vector3(fx, BELT, QB), 0.02, 0.03, frame)
		part(parent, B.boxm(Vector3(0.05, top - BELT, 0.09)), Vector3(fx, (BELT + top) / 2.0, BP), frame)  # B-pilari
		part(parent, B.boxm(Vector3(0.02, top - BELT, 0.03)), Vector3(fx, (BELT + top) / 2.0, RW), frame)
		slab(parent, wf0 + Vector3(fx, 0, 0.01), wf1 + Vector3(fx, 0, 0.01), 0.02, 0.03, frame)  # oven etureunan kehys
		# Kylki: ovisaumat (2 ovea), kromiset kahvat, musta kylkilista ovien keskikorkeudella, kromilista helmassa,
		# peili, pyöränkaaret (musta kotelo ja maalattu reunus).
		var sz: float = sx * (SIDE + 0.001)
		for dz in [WS0, BP, 0.95]:
			part(parent, B.boxm(Vector3(0.01, BELT - SILL - SC * 2.0 - 0.04, 0.012)), Vector3(sz, (SILL + BELT) / 2.0, dz), frame)  # viisteiden välissä
		for hz in [BP - 0.12, RW - 0.1]:
			part(parent, B.boxm(Vector3(0.03, 0.035, 0.14)), Vector3(sx * (SIDE + 0.01), 0.80, hz), bar)
		var lip_z: float = sqrt(LIP_R * LIP_R - pow(0.52 - ARCH_Y, 2.0))  # kylkilista päättyy kaaren reunuksen ulkoreunaan
		var arch_out := [FRONT, -WHEEL_Z - lip_z, -WHEEL_Z + lip_z, WHEEL_Z - lip_z, WHEEL_Z + lip_z, BACK]
		for k in 3:
			var z0: float = arch_out[k * 2] + (0.02 if k > 0 else 0.0)
			var z1: float = arch_out[k * 2 + 1] - (0.02 if k < 2 else 0.0)
			part(parent, B.boxm(Vector3(0.03, 0.05, z1 - z0)), Vector3(sx * (SIDE + 0.012), 0.52, (z0 + z1) / 2.0), frame)  # kylkilista
		part(parent, B.boxm(Vector3(0.012, 0.018, 2.0 * (WHEEL_Z - LIP_R) - 0.04)), Vector3(sx * (SIDE + 0.006), SILL + 0.05, 0), bar)  # helmalista
		part(parent, B.boxm(Vector3(0.12, 0.09, 0.15)), Vector3(sx * (SIDE + 0.07), BELT + 0.09, WS0 + 0.12), frame)  # peili
		part(parent, B.boxm(Vector3(0.02, 0.07, 0.12)), Vector3(sx * (SIDE + 0.13), BELT + 0.09, WS0 + 0.12), glass())
		for wz in [-WHEEL_Z, WHEEL_Z]:
			_wheel_arch(parent, sx, SIDE, SILL, wz, ARCH_R, ARCH_Y, LIP_R, frame, body)
	part(parent, B.boxm(Vector3(0.012, 0.1, 0.12)), Vector3(-(SIDE + 0.004), 0.78, 1.6), frame)  # tankkiluukku vasemmassa takakyljessä
	part(parent, B.boxm(Vector3(0.014, 0.085, 0.105)), Vector3(-(SIDE + 0.005), 0.78, 1.6), body)
	# Keula (esikuva_pony2_edesta.jpg): suorakaiteiset ajovalot, kulmavilkut, musta säleikkö ohuin kromisin
	# vaakasälein ja HD-merkki keskellä.
	part(parent, B.boxm(Vector3(0.66, 0.17, 0.03)), Vector3(0, LAMP_Y, FRONT - 0.01), frame)
	for k in 7:
		part(parent, B.boxm(Vector3(0.64, 0.008, 0.035)), Vector3(0, LAMP_Y - 0.072 + k * 0.024, FRONT - 0.013), bar)  # vaakasäleet
	part(parent, B.boxm(Vector3(0.11, 0.065, 0.04)), Vector3(0, LAMP_Y, FRONT - 0.02), bar)  # HD-merkin kehys
	part(parent, B.boxm(Vector3(0.095, 0.05, 0.04)), Vector3(0, LAMP_Y, FRONT - 0.022), frame)
	var hd := Label3D.new()
	hd.text = "HD"
	hd.font_size = 32
	hd.pixel_size = 0.0012
	hd.outline_size = 0
	hd.modulate = Color(0.92, 0.92, 0.9)
	hd.double_sided = false
	hd.position = Vector3(0, LAMP_Y, FRONT - 0.043)
	hd.rotation.y = PI
	parent.add_child(hd)
	var amber := lamp(Color(1.0, 0.42, 0.04))
	var lens := _mat("ponylinssi", Color(0.62, 0.65, 0.68), 0.3, 0.15)
	for sx in [-1.0, 1.0]:
		# Ajovalo: kromireunus, heijastin ja lasin pystyurat.
		part(parent, B.boxm(Vector3(0.32, 0.18, 0.025)), Vector3(sx * 0.50, LAMP_Y, FRONT - 0.005), bar)
		part(parent, B.boxm(Vector3(0.29, 0.15, 0.03)), Vector3(sx * 0.50, LAMP_Y, FRONT - 0.01), _mat("ponyvalo", Color(0.74, 0.76, 0.75), 0.2, 0.1))  # lasi päivällä: ei hehku
		# Pyöreä heijastin suorakaidelasin takana: kromirengas ja kirkas polttimo.
		part(parent, B.cyl(0.062, 0.062, 0.03, 20), Vector3(sx * 0.50, LAMP_Y, FRONT - 0.014), lens, Vector3(PI / 2.0, 0, 0))
		part(parent, B.cyl(0.05, 0.05, 0.03, 20), Vector3(sx * 0.50, LAMP_Y, FRONT - 0.017), lamp(Color(1.0, 0.98, 0.9)), Vector3(PI / 2.0, 0, 0))
		part(parent, B.cyl(0.018, 0.018, 0.03, 10), Vector3(sx * 0.50, LAMP_Y, FRONT - 0.02), bar, Vector3(PI / 2.0, 0, 0))
		for k in 6:
			part(parent, B.boxm(Vector3(0.006, 0.15, 0.032)), Vector3(sx * (0.385 + k * 0.046), LAMP_Y, FRONT - 0.012), lens)
		part(parent, B.boxm(Vector3(0.29, 0.006, 0.032)), Vector3(sx * 0.50, LAMP_Y, FRONT - 0.012), lens)
		part(parent, B.boxm(Vector3(0.09, 0.16, 0.03)), Vector3(sx * (SIDE - SC - 0.045), LAMP_Y, FRONT - 0.01), amber)  # kulmavilkku viisteen sisäpuolella
		part(parent, B.boxm(Vector3(0.02, 0.16, 0.08)), Vector3(sx * (SIDE + 0.005), LAMP_Y, FRONT + SC + 0.045), amber)
		part(parent, B.boxm(Vector3(SC * 1.414 + 0.012, 0.16, 0.02)), Vector3(sx * (SIDE - SC / 2.0 + 0.004), LAMP_Y, FRONT + SC / 2.0 - 0.004),
			amber, Vector3(0, -sx * PI / 4.0, 0))  # korin pystyviisteessä etu- ja sivuvilkun välissä
	# Perä: vaakatakavalot kilven molemmin puolin (punainen yläosa, alhaalla vilkku ulkona ja peruutusvalo sisällä).
	part(parent, B.boxm(Vector3(0.58, 0.2, 0.03)), Vector3(0, TAIL_Y, BACK + 0.01), frame)  # kilven syvennys
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.48, 0.2, 0.025)), Vector3(sx * 0.53, TAIL_Y, BACK + 0.005), frame)  # valon kehys, ulkoreuna viisteen sisäpuolella
		part(parent, B.boxm(Vector3(0.45, 0.085, 0.03)), Vector3(sx * 0.53, TAIL_Y + 0.045, BACK + 0.01), lamp(Color(0.72, 0.02, 0.05)))
		part(parent, B.boxm(Vector3(0.29, 0.075, 0.03)), Vector3(sx * 0.61, TAIL_Y - 0.045, BACK + 0.01), amber)
		part(parent, B.boxm(Vector3(0.15, 0.075, 0.03)), Vector3(sx * 0.38, TAIL_Y - 0.045, BACK + 0.01), lamp(Color(0.95, 0.95, 0.92)))
		for k in 4:
			part(parent, B.boxm(Vector3(0.45, 0.004, 0.032)), Vector3(sx * 0.53, TAIL_Y + 0.012 + k * 0.022, BACK + 0.01), frame)  # punaisen lasin urat
	# Leveät mustat puskurit punaisella raidalla, pakoputki.
	for bz in [FRONT - 0.05, BACK + 0.05]:
		var face: float = signf(bz) * 0.08
		_bevel_box(parent, Vector3(SIDE * 2.0 + 0.04, 0.2, 0.16), Vector3(0, BUMP_Y, bz), 0.03, frame)
		part(parent, B.boxm(Vector3(SIDE * 2.0 - 0.02, 0.015, 0.005)), Vector3(0, BUMP_Y + 0.04, bz + face), stripe)  # päät viisteiden sisäpuolella
		var wrap_z: float = bz - signf(bz) * 0.2  # puskurin kylkiosa kohti pyörää
		var za: float = bz + signf(bz) * 0.05  # kylkiraita etupinnan viisteestä kylkiosan päätyviisteeseen
		var zb: float = wrap_z - signf(bz) * 0.125
		for sx in [-1.0, 1.0]:
			_bevel_box(parent, Vector3(0.04, 0.2, 0.28), Vector3(sx * SIDE, BUMP_Y, wrap_z), 0.015, frame)  # ei kaaren reunukseen
			part(parent, B.boxm(Vector3(0.005, 0.015, absf(za - zb))), Vector3(sx * (SIDE + 0.022), BUMP_Y + 0.04, (za + zb) / 2.0), stripe)
	part(parent, B.cyl(0.03, 0.03, 0.16, 8), Vector3(0.35, 0.21, BACK + 0.04), bar, Vector3(PI / 2.0, 0, 0))  # pakoputki
	for sx in [-1.0, 1.0]:
		for wz in [-WHEEL_Z, WHEEL_Z]:
			part(parent, B.boxm(Vector3(0.18, 0.24, 0.012)), Vector3(sx * 0.71, 0.18, wz + WHEEL_R + 0.08), frame)  # kuraläppä
	_plate(parent, Vector3(0, BUMP_Y - 0.01, FRONT - 0.14), false, plate)
	_plate(parent, Vector3(0, TAIL_Y, BACK + 0.03), true, plate)
	_merge_parts(parent, first, "pony/" + color.to_html())
	var hub := _mat("ponyvanne", Color(0.78, 0.79, 0.8), 0.5, 0.35)
	var wheels: Array[Node3D] = []
	for sx in [-0.74, 0.74]:
		for wz in [-WHEEL_Z, WHEEL_Z]:
			wheels.append(wheel(parent, Vector3(sx, WHEEL_R, wz), WHEEL_R, 0.16, 0, hub, 0.7))
	return wheels


## Henkilöauton istujat lasketaan kuten mopon ja kalusteiden istujat (Pose.seat + Pose.feet_to_floor), ei kiinteillä
## hahmon sijainneilla: lantio etuistuimen pinnan pisteeseen (kuljettaja -X, kasvot -Z) ja jalkapohjat jalkatilan
## lattialle. Kori on umpinainen vyölinjaan asti, joten jalat jäävät korin sisään (lattia helman SILL yläpuolella) ja
## vyön yläpuolella näkyvät vartalo ja pää; pää jää katon alle. Pisteet mallin paikallisessa avaruudessa.
const RATTI_R := 0.1775  # ratin kehän keskisäde (_cabin: TorusMesh 0,165–0,19)


## Istuimet säädetään kuin oikeassa autossa, jotta kyytiin mahtuu: "p" istuimen pinnan piste (korkeus ja pituussuunta),
## "nojaus" selkänojan kallistus taakse (rad, spine_01). Pään rako kattoon, jalat ja ratti: autossa_kuvat.tscn mittaa.
const ISTUIMET := {
	"volvo": {
		"kuski": {"p": Vector3(-0.36, 0.4, 0.02), "nojaus": 0.1},  # istuin alas (pää ei katon läpi), selkä vähän taakse: kädet yltävät rattiin
		"etu": {"p": Vector3(0.36, 0.38, 0.06), "nojaus": 0.3},  # Sitting_Idle istuu pystyssä: istuin alas ja taakse, selkänoja taakse
		"lattia": 0.3,
		"ratti": Vector3(-0.36, 1.0, -0.3),  # ratti eteen ja ylös polvien yltä; kuljettajan kädet IK:lla kehälle (istuta)
	},
	# Volvon mallilla: istuin katon alapinnan mukaan (Volvo 1,39 -> 0,40), ratti vyölinjan yläpuolelle ja tuulilasin taakse
	# (WS0 + 0,47), istuin ratin taakse 0,35. Pony, Saab ja Lada: liikenteen kuskit (traffic_car.gd, Vehicles.kuski).
	"pony": {  # vyö 0,87, katon ala 1,33, tuulilasi WS0 -0,68
		"kuski": {"p": Vector3(-0.34, 0.34, 0.14), "nojaus": 0.2},
		"etu": {"p": Vector3(0.34, 0.33, 0.18), "nojaus": 0.3},
		"lattia": 0.26,
		"ratti": Vector3(-0.34, 0.93, -0.21),
	},
	"saab": {  # vyö 0,93, katon ala 1,37, tuulilasi WS0 -0,89
		"kuski": {"p": Vector3(-0.36, 0.38, -0.07), "nojaus": 0.15},
		"etu": {"p": Vector3(0.36, 0.37, -0.03), "nojaus": 0.3},
		"lattia": 0.28,
		"ratti": Vector3(-0.36, 0.99, -0.42),
	},
	"lada": {  # vyö 0,92, katon ala 1,39, tuulilasi WS0 -0,80, kapea ohjaamo
		"kuski": {"p": Vector3(-0.33, 0.4, 0.02), "nojaus": 0.1},
		"etu": {"p": Vector3(0.33, 0.38, 0.06), "nojaus": 0.3},
		"lattia": 0.32,
		"ratti": Vector3(-0.33, 0.98, -0.33),
	},
	"mercedes": {  # W123: vyö 0,92, katon ala 1,39, selkänoja z 0,2
		"kuski": {"p": Vector3(-0.38, 0.37, 0.04), "nojaus": 0.15},  # taksikuski: istuin alas, pää katon alle
		"etu": {"p": Vector3(0.38, 0.38, 0.06), "nojaus": 0.3},
		"lattia": 0.3,
		"ratti": Vector3(-0.38, 0.98, -0.35),
	},
}


## Liikenteen kuskien ulkonäöt: arvotaan väreistä ja hiuksista, jotta kuskit eivät ole nimettyjä hahmoja.
const KUSKI_HIUKSET := ["Hair_Buzzed", "Hair_SimpleParted", "Hair_Long"]
const KUSKI_PAIDAT := [Color(0.2, 0.3, 0.55), Color(0.55, 0.15, 0.12), Color(0.25, 0.4, 0.25), Color(0.85, 0.85, 0.8),
	Color(0.15, 0.15, 0.17), Color(0.6, 0.5, 0.3)]


## Kuski henkilöautomallin (MALLIT tai "pony"/"mercedes") ratin taakse: look tai arvottu ulkonäkö, Driving-animaatio,
## istutus kuten Volvossa (istuta). Palauttaa hahmon.
static func kuski(car: Node3D, malli: String, look := {}) -> Node3D:
	var istuin := "volvo" if malli == "volvo_farmari" else malli
	if not ISTUIMET.has(istuin):
		return null
	if look.is_empty():
		var nainen := randf() < 0.4
		look = {"model": "female" if nainen else "male", "shirt": KUSKI_PAIDAT.pick_random(),
			"pants": Color(0.15, 0.17, 0.25), "shoes": Color(0.1, 0.08, 0.07), "hair": KUSKI_HIUKSET.pick_random(),
			"hair_color": Color(randf_range(0.15, 0.6), randf_range(0.1, 0.45), randf_range(0.05, 0.3)),
			"height": randf_range(1.62, 1.78) if nainen else randf_range(1.7, 1.82)}
	var ch: Node3D = load("res://scripts/looks.gd").make(car, look)
	ch.play("Driving", 0.0)
	istuta(ch, istuin, "kuski")
	return ch


## Istuttaa hahmon autoon (ISTUIMET[malli][paikka], paikka "kuski" tai "etu"): kasvot -Z, lantio istuimelle, selkä
## nojaa taakse istuimen säädön mukaan ja jalkapohjat jalkatilan lattialle. Hahmon pitää olla puussa ja animaation valittuna.
static func istuta(ch: Node3D, malli: String, paikka: String) -> void:
	var Pose = load("res://scripts/pose.gd")
	var auto: Dictionary = ISTUIMET[malli]
	var s: Dictionary = auto[paikka]
	var fwd := Vector3(0, 0, -1)
	Pose.seat(ch, fwd, s.p)
	if float(s.get("nojaus", 0.0)) != 0.0:
		ch.set_override("spine_01", Vector3.RIGHT, float(s.nojaus))  # selkä nojaa taakse selkänojaan
	# Jalat ojennetaan pitkälle eteen jalkatilan lattialle kuten autossa (Pose.feet_to_floor rajaa askeleen reiden mittaan,
	# jolloin matalalla istuimella polvet nousisivat ratin tasolle): polvi koukussa n. 45°, jalkaterät korin sisällä.
	var foot_h: float = Pose.FOOT_H + float(ch.get("shoe_sole") if ch.get("shoe_sole") != null else 0.0)
	var inv_l := ch.transform.affine_inverse()
	for lr: String in ["_l", "_r"]:
		var hip: Vector3 = ch.transform * ch.bone_position("thigh" + lr)
		var l1: float = ch.bone_position("thigh" + lr).distance_to(ch.bone_position("calf" + lr))
		var l2: float = ch.bone_position("calf" + lr).distance_to(ch.bone_position("foot" + lr))
		var dy: float = hip.y - (float(auto.lattia) + foot_h)
		var eteen := sqrt(maxf((l1 + l2) * (l1 + l2) * 0.86 - dy * dy, 0.0025))
		var tgt := Vector3(hip.x, float(auto.lattia) + foot_h, hip.z) + fwd * eteen
		var pole := (hip + tgt) / 2.0 + Vector3(0, 0.4, 0)  # polvi ylös
		ch.set_ik("leg" + lr, "thigh" + lr, "calf" + lr, "foot" + lr, inv_l * tgt, inv_l * pole)
	if paikka == "kuski" and auto.has("ratti"):
		# Kädet ratin kehälle kello 9 ja 3 (hieman ylempänä), kyynärpäät alas ja sivulle: ratti säädetään kuljettajalle,
		# kädet seuraavat rattia eivätkä animaation kiinteää paikkaa.
		var hub: Vector3 = auto.ratti
		var akseli := Vector3(0, 0.5, 0.866)  # _cabin: ratti kierretty 60° X:n ympäri
		var ylos := akseli.cross(Vector3.RIGHT)
		var inv := ch.transform.affine_inverse()
		for lr: String in ["_l", "_r"]:
			var sx := -1.0 if lr == "_l" else 1.0
			var ote: Vector3 = hub + Vector3.RIGHT * sx * RATTI_R * cos(0.25) + ylos * RATTI_R * sin(0.25)
			var olka: Vector3 = ch.transform * ch.bone_position("upperarm" + lr)
			var kyynar := (olka + ote) / 2.0 + Vector3(sx * 0.2, -0.25, 0.05)
			ch.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, inv * ote, inv * kyynar)


## Sisusta lasien läpi (vasemmanpuoleinen ohjaus: kuljettaja -X:ssä, etu -Z): lattia vyölinjalla, kattoverhoilu,
## kojelauta, ratti, etupenkkien selkänojat niskatukineen, takapenkin selkänoja ja hattuhylly. Kori on umpinainen
## vyölinjaan asti, joten istuinosat jäävät sen sisään. seat_z = etuselkänojan alapää, rear_z = takaselkänojan
## alapää, hat_z ja hat_len = hattuhyllyn keskikohta ja pituus. Yhteinen Ponylle ja Saabille.
static func _cabin(parent: Node3D, belt: float, top: float, ws0: float, ws1: float, ht0: float, ht1: float, ht_y: float,
		glass_w: float, bar: Material, seat_z: float, rear_z: float, hat_z: float, hat_len: float, ratti := Vector3.INF) -> void:
	var trim := _mat("ponysisus", Color(0.13, 0.13, 0.14), 0.0, 0.85)
	var seat := _mat("ponyistuin", Color(0.46, 0.44, 0.41), 0.0, 0.95)
	var cab_w := glass_w - 0.03
	var seat_top := belt + 0.17
	part(parent, B.boxm(Vector3(cab_w, 0.01, ht1 - 0.08 - ws0)), Vector3(0, belt + 0.005, (ws0 + ht1 - 0.08) / 2.0), trim)  # lattia
	part(parent, B.boxm(Vector3(cab_w, 0.01, ht0 - ws1 - 0.02)), Vector3(0, top - 0.008, (ws1 + ht0) / 2.0), _mat("ponykatto", Color(0.7, 0.68, 0.64), 0.0, 0.9))  # kattoverhoilu
	part(parent, B.boxm(Vector3(cab_w, 0.12, 0.28)), Vector3(0, belt + 0.06, ws0 + 0.34), trim)  # kojelauta tuulilasin takana
	var hub_p := Vector3(-0.36, belt + 0.17, ws0 + 0.58) if ratti == Vector3.INF else ratti  # ratti: säädetty kuljettajan mukaan (ISTUIMET)
	var akseli := Vector3(0, 0.5, 0.866)  # ratin akseli (kierretty 60° X:n ympäri), osoittaa kuljettajaa kohti
	if ratti == Vector3.INF:
		part(parent, B.boxm(Vector3(0.36, 0.06, 0.13)), Vector3(-0.36, belt + 0.15, ws0 + 0.4), trim)  # mittariston kotelo
		slab(parent, Vector3(-0.36, belt + 0.09, ws0 + 0.46), hub_p, 0.05, 0.05, trim)  # ohjausakseli
	else:
		# Säädetty ratti: mittariston kotelo ratin yläkehän takana (ei ratin päällä) ja ohjausakseli kojelautaan akselin suunnassa.
		part(parent, B.boxm(Vector3(0.36, 0.06, 0.13)), Vector3(hub_p.x, maxf(belt + 0.12, hub_p.y + 0.08), hub_p.z - 0.2), trim)
		slab(parent, hub_p - akseli * 0.3, hub_p, 0.05, 0.05, trim)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.165
	ring.outer_radius = 0.19
	ring.rings = 24
	ring.ring_segments = 8
	part(parent, ring, hub_p, trim, Vector3(deg_to_rad(60.0), 0, 0))  # ratti: akseli (0; 0,5; 0,87) kohti kuljettajaa
	part(parent, B.boxm(Vector3(0.34, 0.03, 0.02)), hub_p, trim, Vector3(deg_to_rad(-30.0), 0, 0))  # puolat
	part(parent, B.cyl(0.05, 0.05, 0.04, 12), hub_p, trim, Vector3(deg_to_rad(60.0), 0, 0))  # napa
	for sx in [-1.0, 1.0]:
		# Etupenkki: taakse kallistuva selkänoja ja niskatuki kahdella tangolla.
		var b0 := Vector3(sx * 0.36, belt + 0.01, seat_z)
		var b1 := Vector3(sx * 0.36, seat_top, seat_z + 0.07)
		slab(parent, b0, b1, 0.48, 0.11, seat)
		for px in [-0.07, 0.07]:
			part(parent, B.cyl(0.008, 0.008, 0.05, 6), b1 + Vector3(px, 0.025, 0.0), bar)
		_bevel_box(parent, Vector3(0.26, 0.15, 0.09), b1 + Vector3(0, 0.125, 0.01), 0.025, seat)  # niskatuki
	slab(parent, Vector3(0, belt + 0.01, rear_z), Vector3(0, seat_top, rear_z + 0.08), cab_w - 0.04, 0.12, seat)  # takapenkin selkänoja
	part(parent, B.boxm(Vector3(cab_w, 0.012, hat_len)), Vector3(0, ht_y - 0.006, hat_z), trim)  # hattuhylly


## Pyöränkaari kyljessä sx (esikuva_pony2_sivu.jpg): pyöreä maalattu reunus, joka nousee kyljestä ja jatkuu helman
## alareunaan asti, ja sen sisällä tumma kotelo vain helman yläpuolella (ei mustaa kiekkoa maahan asti).
static func _wheel_arch(parent: Node3D, sx: float, side: float, sill: float, wz: float, arch_r: float, arch_y: float,
		lip_r: float, frame: Material, body: Material) -> void:
	var a0: float = -asin((arch_y - sill) / lip_r)
	var well: Array = []
	for k in 17:
		var a: float = lerpf(a0, PI - a0, k / 16.0)
		well.append(Vector2(wz + cos(a) * (arch_r + 0.005), arch_y + sin(a) * (arch_r + 0.005)))
	_side_panel(parent, sx * (side + 0.007), well, frame)
	_arch(parent, sx * side, sx, Vector2(wz, arch_y), arch_r, lip_r, 0.028, a0, body)


## Tasainen monikulmio sivuprofiilina x:n kohdalla (pisteet (z, y), saa olla kovera), molemmin puolin näkyvä:
## maalauskuvio kyljessä (poliisin valkoiset lokasuojat pyöränkaaren kohdalta lovettuina).
static func _flat_panel(parent: Node3D, x: float, pts: PackedVector2Array, mat: Material) -> MeshInstance3D:
	var idx := Geometry2D.triangulate_polygon(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [1.0, -1.0]:
		for k in range(0, idx.size(), 3):
			var t: Array[Vector3] = []
			for m in 3:
				t.append(Vector3(s * 0.002, pts[idx[k + m]].y, pts[idx[k + m]].x))
			_tri(st, t[0], t[1], t[2], Vector3(s, 0, 0))
	st.index()
	st.generate_tangents()
	return part(parent, st.commit(), Vector3(x, 0, 0), mat)


## Saab 900 GLi/GLS (pystykeula, 1979–87; poliisilla Valmetin autoja 1990-luvulle) -Z-suuntaan: 4-ovinen sedan
## n. 1,69 × 1,42 × 4,69 m puskureineen, akseliväli 2,517 m, raide 1430/1440, renkaat 185/65R15. Rakennettiin myös
## Uudenkaupungin Saab-Valmetilla. Sama kori liikenteessä ja poliisilla. Mitat 1981 Saab 900 GLS 4-door
## -blueprintista (getoutlines.com, sivukuva 129,5 px/m akselivälistä) ja 1988 Saab 900 -mittapiirroksesta (pituus
## 4687, ylitykset 1032/1138, leveys 1693, korkeus 1420); esikuvat .claude/tyo/saab/esikuva_poliisi_*.jpg. Pitkä
## konepelti ja simpukkapellin kylkisauma, pysty keula: isot suorakaidevalot, oranssi vilkku kulman ympäri ja musta
## vaakasäleikkö; kiertävä tuulilasi (A-pilari jyrkempi kuin lasi), neljä ovea ja pieni takasivuikkuna, takalasi
## lyhyen viettävän tavaratilan kannen yllä, syvät mustat puskurit ja kylkilista samassa linjassa hopearaidalla,
## aero-pölykapselit.
## police: Suomen poliisin 1980–90-lukujen väritys: tummansininen kori, valkoiset etulokasuojat konepellin saumaan ja
## takakyljet, POLIISI molempien ovien yli, katolla sininen vilkkupalkki POLIISI-kyltillä ja puskurissa lisävalot.
## Palauttaa pyörät kuten car().
static func saab(parent: Node3D, color: Color, plate := "", police := false) -> Array[Node3D]:
	const SIDE := 0.81  # kyljen x: puskureineen ja kylkilistoineen leveys 1690 mm
	const SILL := 0.20  # alakorin alapinta
	const NOSE_LO := 0.49  # pystyn keulapinnan alareuna (puskurin yläreuna peittää)
	const NOSE_Y := 0.76  # konepellin etureuna
	const BELT := 0.93  # vyötärölinja, ikkunoiden alareuna
	const ROOF := 1.42  # katon yläpinta (1420 mm)
	const ROOF_T := 0.05
	const FRONT := -2.16  # keulapinta z: puskurin etupinta n. 1030 mm etupyörän edessä
	const BACK := 2.30  # peräpaneeli z: puskurin takapinta n. 1150 mm takapyörän takana
	const WS0 := -0.89  # tuulilasin alareuna z
	const WS1 := -0.46  # tuulilasin yläreuna z
	const AP0 := WS0 + 0.2  # A-pilarin alapää: kiertävä tuulilasi jatkuu kylkeen pilarin edessä
	const HT0 := 1.08  # takalasin yläreuna z (katon takareuna)
	const HT1 := 1.58  # takalasin alareuna z; sen takana tavaratilan kansi
	const HT_Y := 1.05  # takalasin alareuna y
	const TAIL_TOP := 0.97  # tavaratilan kansi viettää peräpaneelin yläreunaan
	const BP := 0.24  # B-pilari z
	const RW := 0.84  # takaoven ikkunan takareuna = takasivuikkunan etureuna z
	const QA := 0.98  # takasivuikkunan takareuna ylhäällä z
	const QB := 1.14  # takasivuikkunan takareuna vyölinjalla z
	const GLASS_W := 1.40
	const LAMP_Y := 0.64  # ajovalojen keskikorkeus
	const TAIL_Y := 0.68  # takavalojen keskikorkeus
	const BUMP_Y := 0.42  # puskurien ja kylkilistan keskikorkeus
	const BUMP_H := 0.24
	const WHITE_Y := 0.80  # poliisin valkoisen takakyljen yläreuna
	const WHEEL_R := 0.31  # 185/65R15: 381 + 2 × 120 = 621 mm
	const WHEEL_Z := 1.2585  # akseliväli 2517 mm
	const ARCH_R := WHEEL_R + 0.045
	const ARCH_Y := ARCH_R
	const LIP_R := ARCH_R + 0.045
	const SC := 0.03
	const CF := 0.035
	var first := parent.get_child_count()
	if police:
		color = Color(0.05, 0.08, 0.2)
	var body := paint(color)
	var win := _mat("ponylasi", Color(0.22, 0.27, 0.32), 0.3, 0.05, 0.32)
	var frame := plastic()
	var bar := _mat("ponykromi", Color(0.86, 0.87, 0.89), 0.45, 0.3)
	var silver := _mat("saabraita", Color(0.7, 0.71, 0.72), 0.4, 0.4)
	var amber := lamp(Color(1.0, 0.42, 0.04))
	if plate == "":
		plate = "%s%s%s-%d" % [char(65 + randi() % 26), char(65 + randi() % 26), char(65 + randi() % 26), 100 + randi() % 900]
	var top := ROOF - ROOF_T
	var roof_x := GLASS_W / 2.0 + 0.03  # katon alareunan x = pilarien ja sadevesilistojen ulkopinta
	const ROOF_C := 0.024  # katon reunojen viiste: katto on viisteen verran leveämpi, jotta alareuna on roof_x:ssä
	# Alakori, konepelti, pysty keulapinta, viettävä tavaratilan kansi ja peräpaneeli yhtenä viistettynä sivuprofiilina.
	_bevel(parent, PackedVector2Array([Vector2(FRONT, SILL + CF), Vector2(FRONT + CF, SILL), Vector2(BACK - CF, SILL),
		Vector2(BACK, SILL + CF), Vector2(BACK, TAIL_TOP - CF), Vector2(BACK - CF, TAIL_TOP), Vector2(HT1 - 0.04, HT_Y),
		Vector2(HT1 - 0.04, BELT), Vector2(WS0, BELT), Vector2(FRONT + CF * 1.5, NOSE_Y), Vector2(FRONT, NOSE_Y - CF * 1.5)]), SIDE, SC, body)
	var hood_y := func(z: float) -> float: return lerpf(NOSE_Y, BELT, (z - FRONT) / (WS0 - FRONT))
	var deck_y := func(z: float) -> float: return lerpf(HT_Y, TAIL_TOP, (z - HT1 + 0.04) / (BACK - CF - HT1 + 0.04))
	# Lasit: sivulasi tuulilasin reunasta (kiertävä lasi) takasivuikkunan viistoon takareunaan, sisusta, tuulilasi, takalasi.
	var wf0 := Vector3(0, BELT, WS0)
	var wf1 := Vector3(0, top, WS1)
	var wr0 := Vector3(0, top, HT0)
	var wr1 := Vector3(0, HT_Y, HT1)
	var hat_dir := (wr1 - wr0).normalized()
	for sx in [-1.0, 1.0]:
		_side_panel(parent, sx * GLASS_W / 2.0, [Vector2(WS0, BELT), Vector2(WS1, top), Vector2(QA, top), Vector2(QB, BELT)], win)
	_cabin(parent, BELT, top, WS0, WS1, HT0, HT1, HT_Y, GLASS_W, bar, 0.12, 0.95, 1.3, 0.5, ISTUIMET.saab.ratti)
	slab(parent, wf0, wf1, GLASS_W + 0.02, 0.04, win)  # tuulilasi
	slab(parent, wr0, wr1, GLASS_W + 0.02, 0.04, win)  # takalasi
	_bevel_box(parent, Vector3((roof_x + ROOF_C) * 2.0, ROOF_T, HT0 - WS1 + 0.04), Vector3(0, ROOF - ROOF_T / 2.0, (WS1 + HT0) / 2.0), ROOF_C, body)  # katto
	# Takalasin musta kehys, tavaratilan kannen saumat, tuulilasin pyyhkimet ja konepellin takareunan ilmanottoritilä.
	slab(parent, wr0, wr0.lerp(wr1, 0.05), GLASS_W, 0.05, frame)
	slab(parent, wr0.lerp(wr1, 0.95), wr1, GLASS_W, 0.05, frame)
	# Katon liitokset: tuulilasin yläreunan kumilista (muuten kattoverhoilu näkyy raosta vaaleana juovana) ja
	# sadevesilistat katon kyljissä katon alaviisteen ja ikkunakehyksen välisen sauman päällä.
	slab(parent, wf0.lerp(wf1, 0.95), wf1 + (wf1 - wf0).normalized() * 0.01, GLASS_W + 0.02, 0.05, frame)
	for sx in [-1.0, 1.0]:
		var rz0 := WS1 + 0.06  # A-pilarin yläpään takana
		var rz1 := HT0 - 0.04  # C-pilarin yläpään edessä: päät eivät pistä pilarien ohi
		part(parent, B.boxm(Vector3(0.025, 0.035, rz1 - rz0)), Vector3(sx * (roof_x - 0.0125), top + 0.005, (rz0 + rz1) / 2.0), frame)  # ulkopinta katon alareunan tasossa
	part(parent, B.boxm(Vector3(GLASS_W - 0.06, 0.004, 0.012)), Vector3(0, deck_y.call(HT1 + 0.03) + 0.003, HT1 + 0.03), frame)
	for sx in [-1.0, 1.0]:
		var lx: float = sx * (GLASS_W / 2.0 - 0.03)
		slab(parent, Vector3(lx, deck_y.call(HT1 + 0.03) + 0.003, HT1 + 0.03), Vector3(lx, deck_y.call(BACK - 0.05) + 0.003, BACK - 0.05), 0.012, 0.004, frame)
	part(parent, B.boxm(Vector3(GLASS_W - 0.1, 0.012, 0.07)), Vector3(0, hood_y.call(WS0 - 0.07) + 0.006, WS0 - 0.07), frame)
	for sx in [-1.0, 1.0]:
		var wp := part(parent, B.boxm(Vector3(0.5, 0.015, 0.02)), wf0.lerp(wf1, 0.08) + Vector3(sx * 0.3 - 0.06, 0.03, 0), frame)
		wp.rotation.z = 0.08 * sx
	var seam0 := Vector2(AP0 - 0.02, BELT - 0.07)  # konepellin kylkisauma A-pilarin juuresta keulaan
	var seam1 := Vector2(FRONT + 0.1, NOSE_Y - 0.08)
	var lip_z: float = sqrt(LIP_R * LIP_R - pow(BUMP_Y - ARCH_Y, 2.0))
	var a0: float = -asin((ARCH_Y - SILL) / LIP_R)
	var white := paint(Color(0.94, 0.95, 0.95))
	var rear_seam: float = WHEEL_Z - LIP_R - 0.03  # takaoven takareuna juuri pyöränkaaren edessä (kaari pullistuu z:aa pienemmäksi)
	for sx in [-1.0, 1.0]:
		var fx: float = sx * (GLASS_W / 2.0 + 0.016)
		# A-pilari jyrkempänä kuin tuulilasi: sen eteen jää kylkeen kiertyvä lasikolmio. Pilarien ulkopinta on katon kyljen
		# tasossa (roof_x) ja yläpää ulottuu katon alle: muuten pilari porrastuu katon reunasta ulos.
		var ax: float = sx * (roof_x - 0.035)
		var ap1 := Vector3(ax, top, WS1 + 0.03)
		var ap0 := Vector3(ax, BELT, AP0)
		slab(parent, ap0, ap1 + (ap1 - ap0).normalized() * 0.02, 0.07, 0.06, body)
		slab(parent, Vector3(fx, BELT, AP0 + 0.035), Vector3(fx, top, WS1 + 0.065), 0.02, 0.03, frame)  # etuoven ikkunakehys
		var cx: float = sx * (roof_x - 0.05)
		slab(parent, wr0 + Vector3(cx, 0, 0) - hat_dir * 0.03, wr1 + Vector3(cx, 0, 0), 0.1, 0.06, body)  # C-pilarin takareuna, yläpää katon alle
		slab(parent, wr0 + Vector3(sx * (GLASS_W / 2.0 - 0.01), 0, 0), wr1 + Vector3(sx * (GLASS_W / 2.0 - 0.01), 0, 0), 0.03, 0.05, frame)
		# C-pilari: maalattu levy takasivuikkunan viistosta takareunasta takalasin reunaan.
		_side_panel(parent, sx * (GLASS_W / 2.0 + 0.012), [Vector2(QA, top), Vector2(HT0, top), Vector2(HT1, HT_Y), Vector2(HT1, BELT), Vector2(QB, BELT)], body)
		# Mustat ikkunakehykset: yläreuna, vyölista, B-pilari, takaoven ikkunan takareuna ja takasivuikkunan viisto takareuna.
		part(parent, B.boxm(Vector3(0.02, 0.03, QA - WS1)), Vector3(fx, top - 0.015, (WS1 + QA) / 2.0), frame)
		part(parent, B.boxm(Vector3(0.02, 0.03, QB - AP0)), Vector3(fx, BELT + 0.015, (AP0 + QB) / 2.0), frame)
		slab(parent, Vector3(fx, top, QA), Vector3(fx, BELT, QB), 0.02, 0.03, frame)
		part(parent, B.boxm(Vector3(0.05, top - BELT, 0.08)), Vector3(fx, (BELT + top) / 2.0, BP), frame)  # B-pilari
		part(parent, B.boxm(Vector3(0.02, top - BELT, 0.035)), Vector3(fx, (BELT + top) / 2.0, RW), frame)
		# Kylki: ovisaumat, konepellin kylkisauma (simpukkapelti), kahvat ja peili.
		var sz: float = sx * (SIDE + 0.003)
		for dz in [AP0 - 0.02, BP + 0.05, rear_seam]:
			part(parent, B.boxm(Vector3(0.01, BELT - SILL - SC * 2.0 - 0.04, 0.012)), Vector3(sz, (SILL + BELT) / 2.0, dz), frame)
		slab(parent, Vector3(sz, seam0.y, seam0.x), Vector3(sz, seam1.y, seam1.x), 0.01, 0.012, frame)
		for hz in [BP - 0.1, RW - 0.08]:
			part(parent, B.boxm(Vector3(0.03, 0.035, 0.14)), Vector3(sx * (SIDE + 0.01), 0.80, hz), bar)  # kahvat
		part(parent, B.boxm(Vector3(0.12, 0.09, 0.16)), Vector3(sx * (SIDE + 0.06), BELT + 0.09, AP0 + 0.06), frame)  # peili
		part(parent, B.boxm(Vector3(0.02, 0.07, 0.13)), Vector3(sx * (SIDE + 0.12), BELT + 0.09, AP0 + 0.06), glass())
		if police:
			# Valkoinen etulokasuoja konepellin saumaan asti ja takakylki, molemmat pyöränkaaren kohdalta lovettuina.
			var fz0: float = FRONT + SC
			var fz1: float = seam0.x
			var t0: float = (fz0 - seam1.x) / (seam0.x - seam1.x)
			var front_pts := PackedVector2Array([Vector2(fz0, SILL + SC)])
			var rear_pts := PackedVector2Array([Vector2(rear_seam + 0.006, SILL + SC)])
			for k in 17:
				var a: float = lerpf(PI - a0, a0, k / 16.0)
				front_pts.append(Vector2(-WHEEL_Z + cos(a) * (LIP_R + 0.004), ARCH_Y + sin(a) * (LIP_R + 0.004)))
				rear_pts.append(Vector2(WHEEL_Z + cos(a) * (LIP_R + 0.004), ARCH_Y + sin(a) * (LIP_R + 0.004)))
			front_pts.append_array([Vector2(fz1, SILL + SC), Vector2(fz1, seam0.y - 0.008), Vector2(fz0, lerpf(seam1.y, seam0.y, t0) - 0.008)])
			rear_pts.append_array([Vector2(BACK - SC, SILL + SC), Vector2(BACK - SC, WHITE_Y), Vector2(rear_seam + 0.006, WHITE_Y)])
			_flat_panel(parent, sx * SIDE, front_pts, white)
			_flat_panel(parent, sx * SIDE, rear_pts, white)
		# Kylkilista puskurien linjassa pyöränkaaresta toiseen, hopearaita keskellä.
		var z0: float = -WHEEL_Z + lip_z + 0.02
		var z1: float = WHEEL_Z - lip_z - 0.02
		_bevel_box(parent, Vector3(0.04, 0.1, z1 - z0), Vector3(sx * (SIDE + 0.01), BUMP_Y, (z0 + z1) / 2.0), 0.012, frame)
		part(parent, B.boxm(Vector3(0.01, 0.014, z1 - z0 - 0.04)), Vector3(sx * (SIDE + 0.031), BUMP_Y + 0.012, (z0 + z1) / 2.0), silver)
		# Syvät puskurit kiertävät kylkeen pyöränkaareen asti.
		for end in [[FRONT, -WHEEL_Z - lip_z - 0.015], [BACK, WHEEL_Z + lip_z + 0.015]]:
			var za: float = end[0]
			var zb: float = end[1]
			_bevel_box(parent, Vector3(0.05, BUMP_H, absf(za - zb)), Vector3(sx * (SIDE + 0.005), BUMP_Y, (za + zb) / 2.0), 0.015, frame)
			part(parent, B.boxm(Vector3(0.01, 0.014, absf(za - zb) - 0.03)), Vector3(sx * (SIDE + 0.031), BUMP_Y + 0.012, (za + zb) / 2.0), silver)
		for wz in [-WHEEL_Z, WHEEL_Z]:
			_wheel_arch(parent, sx, SIDE, SILL, wz, ARCH_R, ARCH_Y, LIP_R, frame, body)
	# Tankkiluukku oikeassa takakyljessä.
	part(parent, B.cyl(0.065, 0.065, 0.012, 20), Vector3(SIDE + 0.006, 0.66, 1.78), frame, Vector3(0, 0, PI / 2.0))
	part(parent, B.cyl(0.058, 0.058, 0.014, 20), Vector3(SIDE + 0.007, 0.66, 1.78), white if police else body, Vector3(0, 0, PI / 2.0))
	# Pysty keula: isot suorakaidevalot vaakaurin, oranssi vilkku kulman ympäri, musta vaakasäleikkö ja merkki konepellissä.
	var lens := _mat("ponylinssi", Color(0.62, 0.65, 0.68), 0.3, 0.15)
	var fz: float = FRONT - 0.01
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.42, 0.19, 0.02)), Vector3(sx * 0.47, LAMP_Y, fz), frame)
		part(parent, B.boxm(Vector3(0.40, 0.17, 0.02)), Vector3(sx * 0.47, LAMP_Y, fz - 0.005), _mat("ponyvalo", Color(0.74, 0.76, 0.75), 0.2, 0.1))
		part(parent, B.cyl(0.06, 0.06, 0.02, 20), Vector3(sx * 0.47, LAMP_Y, fz - 0.008), lens, Vector3(PI / 2.0, 0, 0))
		part(parent, B.cyl(0.032, 0.032, 0.02, 16), Vector3(sx * 0.47, LAMP_Y, fz - 0.011), lamp(Color(1.0, 0.98, 0.9)), Vector3(PI / 2.0, 0, 0))
		for k in 4:
			part(parent, B.boxm(Vector3(0.40, 0.004, 0.02)), Vector3(sx * 0.47, LAMP_Y - 0.06 + k * 0.04, fz - 0.012), lens)
		part(parent, B.boxm(Vector3(0.10, 0.17, 0.02)), Vector3(sx * (SIDE - SC - 0.05), LAMP_Y, fz - 0.005), amber)
		part(parent, B.boxm(Vector3(0.02, 0.17, 0.12)), Vector3(sx * (SIDE + 0.004), LAMP_Y, FRONT + SC + 0.06), amber)  # kulman ympäri
		part(parent, B.boxm(Vector3(SC * 1.414 + 0.012, 0.17, 0.02)), Vector3(sx * (SIDE - SC / 2.0 + 0.004), LAMP_Y, FRONT + SC / 2.0 - 0.004),
			amber, Vector3(0, -sx * PI / 4.0, 0))  # korin pystyviisteessä etu- ja sivuvilkun välissä
	var slat := _mat("saabsale", Color(0.2, 0.2, 0.21), 0.3, 0.5)
	part(parent, B.boxm(Vector3(0.50, 0.21, 0.02)), Vector3(0, LAMP_Y, fz), frame)
	for k in 6:
		var gy: float = LAMP_Y - 0.08 + k * 0.03 + (0.02 if k >= 3 else 0.0)
		part(parent, B.boxm(Vector3(0.46, 0.012, 0.02)), Vector3(0, gy, fz - 0.006), slat)
	part(parent, B.boxm(Vector3(0.12, 0.025, 0.02)), Vector3(0, LAMP_Y + 0.0, fz - 0.01), bar)  # SAAB-merkin listake
	part(parent, B.cyl(0.035, 0.035, 0.01, 20), Vector3(0, hood_y.call(FRONT + 0.08) + 0.004, FRONT + 0.08), _mat("saabsininen", Color(0.08, 0.2, 0.55), 0.2, 0.4))
	part(parent, B.cyl(0.018, 0.018, 0.012, 14), Vector3(0, hood_y.call(FRONT + 0.08) + 0.006, FRONT + 0.08), lamp(Color(0.85, 0.1, 0.08)))
	# Peräpaneeli: vaakatakavalot (punainen yläosa, alhaalla vilkku ulkona ja peruutusvalo sisällä) ja kilpi välissä.
	part(parent, B.boxm(Vector3(SIDE * 2.0 - 0.1, 0.22, 0.02)), Vector3(0, TAIL_Y, BACK + 0.005), frame)
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.44, 0.1, 0.03)), Vector3(sx * 0.57, TAIL_Y + 0.05, BACK + 0.01), lamp(Color(0.72, 0.02, 0.05)))
		part(parent, B.boxm(Vector3(0.26, 0.08, 0.03)), Vector3(sx * 0.66, TAIL_Y - 0.05, BACK + 0.01), amber)
		part(parent, B.boxm(Vector3(0.16, 0.08, 0.03)), Vector3(sx * 0.44, TAIL_Y - 0.05, BACK + 0.01), lamp(Color(0.95, 0.95, 0.92)))
		for k in 4:
			part(parent, B.boxm(Vector3(0.44, 0.004, 0.032)), Vector3(sx * 0.57, TAIL_Y + 0.012 + k * 0.022, BACK + 0.01), frame)
	# Puskurit eteen ja taakse hopearaidalla, pakoputki, kuraläpät.
	for bz in [FRONT - 0.03, BACK + 0.03]:
		_bevel_box(parent, Vector3(SIDE * 2.0 + 0.06, BUMP_H, 0.16), Vector3(0, BUMP_Y, bz), 0.035, frame)
		part(parent, B.boxm(Vector3(SIDE * 2.0 - 0.02, 0.014, 0.005)), Vector3(0, BUMP_Y + 0.012, bz + signf(bz) * 0.08), silver)
	part(parent, B.cyl(0.03, 0.03, 0.14, 8), Vector3(0.4, 0.24, BACK + 0.05), bar, Vector3(PI / 2.0, 0, 0))
	for sx in [-1.0, 1.0]:
		for wz in [-WHEEL_Z, WHEEL_Z]:
			part(parent, B.boxm(Vector3(0.18, 0.2, 0.012)), Vector3(sx * 0.72, 0.17, wz + WHEEL_R + 0.1), frame)
	if police:
		# Lisävalot puskurin päällä säleikön edessä.
		for sx in [-1.0, 1.0]:
			var lp := Vector3(sx * 0.27, BUMP_Y + BUMP_H / 2.0 + 0.075, FRONT - 0.06)
			part(parent, B.boxm(Vector3(0.03, 0.06, 0.03)), lp - Vector3(0, 0.07, -0.02), frame)
			part(parent, B.cyl(0.075, 0.075, 0.06, 20), lp, bar, Vector3(PI / 2.0, 0, 0))
			part(parent, B.cyl(0.062, 0.062, 0.01, 20), lp - Vector3(0, 0, 0.031), _mat("ponyvalo", Color(0.74, 0.76, 0.75), 0.2, 0.1), Vector3(PI / 2.0, 0, 0))
			part(parent, B.cyl(0.025, 0.025, 0.01, 12), lp - Vector3(0, 0, 0.034), lamp(Color(1.0, 0.98, 0.9)), Vector3(PI / 2.0, 0, 0))
		# Vilkkupalkki katolla: musta runko jaloilla, siniset kuvut ja keskellä valkoinen POLIISI-kyltti.
		var by := ROOF + 0.06
		var bz := 0.0
		for fx in [-0.45, 0.45]:
			part(parent, B.boxm(Vector3(0.05, 0.05, 0.16)), Vector3(fx, ROOF + 0.02, bz), frame)
		part(parent, B.boxm(Vector3(1.24, 0.04, 0.24)), Vector3(0, by, bz), frame)
		for sx in [-1.0, 1.0]:
			_bevel_box(parent, SAAB_DOME_SIZE, Vector3(sx * 0.4, by + 0.075, bz), 0.03, lamp(Color(0.1, 0.25, 0.95)))  # = SAAB_DOMES
		part(parent, B.boxm(Vector3(0.36, 0.12, 0.2)), Vector3(0, by + 0.08, bz), _mat("saabkyltti", Color(0.96, 0.96, 0.95), 0.0, 0.4))
		part(parent, B.cyl(0.04, 0.04, 0.05, 12), Vector3(0.62, by + 0.06, bz), lamp(Color(0.85, 0.05, 0.05)), Vector3(0, 0, PI / 2.0))
	_plate(parent, Vector3(0, BUMP_Y - 0.01, FRONT - 0.12), false, plate)
	_plate(parent, Vector3(0, TAIL_Y - 0.04, BACK + 0.02), true, plate)
	_merge_parts(parent, first, "saab/" + color.to_html() + ("/poliisi" if police else ""))
	if police:
		# Tekstit eivät kuulu yhdistettyyn verkkoon: ovien yli ja vilkkupalkin kyltissä edessä ja takana.
		for sx in [-1.0, 1.0]:
			var l := Label3D.new()
			l.text = "POLIISI"
			l.font_size = 96
			l.pixel_size = 0.0036
			l.outline_size = 0
			l.modulate = Color(0.95, 0.96, 0.96)
			l.double_sided = false
			l.position = Vector3(sx * (SIDE + 0.004), 0.64, (AP0 + RW) / 2.0 + 0.04)
			l.rotation.y = sx * PI / 2.0
			parent.add_child(l)
		for face_z in [-1.0, 1.0]:
			var s := Label3D.new()
			s.text = "POLIISI"
			s.font_size = 40
			s.pixel_size = 0.0016
			s.outline_size = 0
			s.modulate = Color(0.05, 0.1, 0.4)
			s.double_sided = false
			s.position = Vector3(0, ROOF + 0.14, face_z * 0.102)
			s.rotation.y = 0.0 if face_z > 0.0 else PI
			parent.add_child(s)
	var badge := Label3D.new()
	badge.text = "SAAB"
	badge.font_size = 32
	badge.pixel_size = 0.0018
	badge.outline_size = 0
	badge.modulate = Color(0.85, 0.86, 0.88)
	badge.double_sided = false
	badge.position = Vector3(0, TAIL_Y + 0.075, BACK + 0.017)
	parent.add_child(badge)
	var hub := _mat("ponyvanne", Color(0.78, 0.79, 0.8), 0.5, 0.35)
	var wheels: Array[Node3D] = []
	for sx in [-0.73, 0.73]:  # raide 1460 (esikuva 1430/1440): pyörä ulottuu kotelon mustan levyn ulkopuolelle
		for wz in [-WHEEL_Z, WHEEL_Z]:
			wheels.append(wheel(parent, Vector3(sx, WHEEL_R, wz), WHEEL_R, 0.19, 0, hub, 0.72, 14))  # aero-pölykapselit
	return wheels


## Liikenteen henkilöautojen mallit (#283): arvotaan liikenteeseen ja pysäköidyiksi, kaapattu auto perii mallin.
const MALLIT := ["saab", "lada", "volvo", "volvo_farmari"]


## Henkilöauto mallin nimellä (MALLIT): palauttaa pyörät kuten car().
static func henkiloauto(parent: Node3D, malli: String, color: Color, plate := "") -> Array[Node3D]:
	match malli:
		"lada":
			return lada(parent, color, plate)
		"volvo":
			return volvo(parent, color, plate)
		"volvo_farmari":
			return volvo(parent, color, plate, true)
	return saab(parent, color, plate)


## Lada 2105 (Suomessa Lada 1500 S, 1980–2010) -Z-suuntaan: laatikkomainen 4-ovinen sedan n. 1,62 × 1,45 × 4,15 m
## puskureineen, akseliväli 2,424 m, raide 1365/1321, renkaat 175/70R13. Mitat 1982 Lada 2107 -blueprintista
## (getoutlines.com, sivukuva 106,9 px/m: pituus 4145, ylitykset 664/1057, korkeus 1446, leveys 1620); 2105 on samaa
## koria. Esikuvat Wikimedia Commonsista (1990 Lada 1500 S Vantaa keula, Lada 2107 Riva kylki, 2008 Lada 210540 perä):
## pysty keula, jossa suorakaiteiset ajovalot oranssein ulkovilkuin ja niiden välissä musta vaakasäleikkö
## merkkeineen, lähes tasainen konepelti, kapea ohjaamo ja pystyt pilarit, etuoven tuuletusikkuna, C-pilarin
## tuuletusritilä, pitkä tavaratila, kulmien suorakaiteiset takavalot ja kilpi kannessa niiden välissä, isot
## alumiinipuskurit mustin kumilistoin ja päädyin, kromiset sadevesilistat ja ikkunalistat, peltivanteet.
## Palauttaa pyörät kuten car().
static func lada(parent: Node3D, color: Color, plate := "") -> Array[Node3D]:
	const SIDE := 0.79  # kyljen x: listoineen ja puskureineen leveys 1620 mm
	const SILL := 0.24  # alakorin alapinta (maavara)
	const NOSE_LO := 0.46  # pystyn keulapinnan alareuna (puskuri peittää)
	const NOSE_Y := 0.82  # konepellin etureuna
	const BELT := 0.92  # vyötärölinja, ikkunoiden alareuna
	const ROOF := 1.44  # katon yläpinta (1446 mm)
	const ROOF_T := 0.05
	const FRONT := -1.806  # keulapinta z: puskurin etupinta 664 mm etupyörän edessä
	const BACK := 2.20  # peräpaneeli z: puskurin takapinta 1057 mm takapyörän takana
	const WS0 := -0.80  # tuulilasin alareuna z
	const WS1 := -0.40  # tuulilasin yläreuna z
	const VENT := WS0 + 0.30  # etuoven tuuletusikkunan takareuna z
	const HT0 := 1.00  # takalasin yläreuna z (katon takareuna)
	const HT1 := 1.34  # takalasin alareuna z; sen takana pitkä tavaratilan kansi
	const HT_Y := 0.98  # takalasin alareuna y
	const TAIL_TOP := 0.90  # tavaratilan kansi viettää peräpaneelin yläreunaan
	const BP := 0.27  # B-pilari z
	const QA := 0.84  # takaoven ikkunan takareuna ylhäällä z (sen takana leveä C-pilari)
	const QB := 0.90  # takaoven ikkunan takareuna vyölinjalla z
	const GLASS_W := 1.30  # kapea ohjaamo: kyljet kallistuvat sisäänpäin ikkunoiden kohdalla
	const LAMP_Y := 0.70  # ajovalojen keskikorkeus
	const TAIL_Y := 0.74  # takavalojen keskikorkeus
	const BUMP_Y := 0.42  # puskurien keskikorkeus
	const BUMP_H := 0.15
	const WHEEL_R := 0.29  # 175/70R13: 330 + 2 × 122 = 575 mm
	const WHEEL_Z := 1.212  # akseliväli 2424 mm
	const ARCH_R := WHEEL_R + 0.05
	const ARCH_Y := ARCH_R
	const LIP_R := ARCH_R + 0.04
	const SC := 0.03
	const CF := 0.035
	const ROOF_C := 0.02
	var first := parent.get_child_count()
	var body := paint(color)
	var win := _mat("ponylasi", Color(0.22, 0.27, 0.32), 0.3, 0.05, 0.32)
	var frame := plastic()
	var bar := _mat("ponykromi", Color(0.86, 0.87, 0.89), 0.45, 0.3)
	var alu := _mat("ladapuskuri", Color(0.7, 0.71, 0.72), 0.5, 0.35)
	var amber := lamp(Color(1.0, 0.42, 0.04))
	if plate == "":
		plate = "%s%s%s-%d" % [char(65 + randi() % 26), char(65 + randi() % 26), char(65 + randi() % 26), 100 + randi() % 900]
	var top := ROOF - ROOF_T
	var roof_x := GLASS_W / 2.0 + 0.03  # katon alareunan x = pilarien ja sadevesilistojen ulkopinta
	# Alakori, konepelti, pysty keula, viettävä tavaratilan kansi ja peräpaneeli yhtenä viistettynä sivuprofiilina.
	_bevel(parent, PackedVector2Array([Vector2(FRONT, SILL + CF), Vector2(FRONT + CF, SILL), Vector2(BACK - CF, SILL),
		Vector2(BACK, SILL + CF), Vector2(BACK, TAIL_TOP - CF), Vector2(BACK - CF, TAIL_TOP), Vector2(HT1 - 0.04, HT_Y),
		Vector2(HT1 - 0.04, BELT), Vector2(WS0, BELT), Vector2(FRONT + CF, NOSE_Y), Vector2(FRONT, NOSE_Y - CF)]), SIDE, SC, body)
	var hood_y := func(z: float) -> float: return lerpf(NOSE_Y, BELT, (z - FRONT) / (WS0 - FRONT))
	var deck_y := func(z: float) -> float: return lerpf(HT_Y, TAIL_TOP, (z - HT1 + 0.04) / (BACK - CF - HT1 + 0.04))
	# Lasit: sivulasi tuulilasin reunasta takaoven ikkunan lähes pystyyn takareunaan, sisusta, tuulilasi, takalasi.
	var wf0 := Vector3(0, BELT, WS0)
	var wf1 := Vector3(0, top, WS1)
	var wr0 := Vector3(0, top, HT0)
	var wr1 := Vector3(0, HT_Y, HT1)
	var hat := (wr1 - wr0).normalized()
	for sx in [-1.0, 1.0]:
		_side_panel(parent, sx * GLASS_W / 2.0, [Vector2(WS0, BELT), Vector2(WS1, top), Vector2(QA, top), Vector2(QB, BELT)], win)
	_cabin(parent, BELT, top, WS0, WS1, HT0, HT1, HT_Y, GLASS_W, bar, 0.15, 0.82, 1.15, 0.36, ISTUIMET.lada.ratti)
	slab(parent, wf0, wf1, GLASS_W + 0.02, 0.04, win)  # tuulilasi
	slab(parent, wr0, wr1, GLASS_W + 0.02, 0.04, win)  # takalasi
	_bevel_box(parent, Vector3((roof_x + ROOF_C) * 2.0, ROOF_T, HT0 - WS1 + 0.04), Vector3(0, ROOF - ROOF_T / 2.0, (WS1 + HT0) / 2.0), ROOF_C, body)  # katto
	# Kumilistat tuuli- ja takalasin reunoissa, kromiset sadevesilistat katon kyljissä pilarien välissä, tavaratilan
	# kannen saumat, konepellin takareunan ilmanottoritilä ja pyyhkimet.
	slab(parent, wr0, wr0.lerp(wr1, 0.06), GLASS_W, 0.05, frame)
	slab(parent, wr0.lerp(wr1, 0.94), wr1, GLASS_W, 0.05, frame)
	slab(parent, wf0.lerp(wf1, 0.95), wf1 + (wf1 - wf0).normalized() * 0.01, GLASS_W + 0.02, 0.05, frame)
	slab(parent, wf0, wf0.lerp(wf1, 0.04), GLASS_W + 0.02, 0.05, frame)
	part(parent, B.boxm(Vector3(GLASS_W - 0.06, 0.004, 0.012)), Vector3(0, deck_y.call(HT1 + 0.04) + 0.003, HT1 + 0.04), frame)
	for sx in [-1.0, 1.0]:
		var lx: float = sx * (GLASS_W / 2.0 - 0.02)
		slab(parent, Vector3(lx, deck_y.call(HT1 + 0.04) + 0.003, HT1 + 0.04), Vector3(lx, deck_y.call(BACK - 0.05) + 0.003, BACK - 0.05), 0.012, 0.004, frame)
		var rz0 := WS1 + 0.015
		var rz1 := HT0 - 0.04
		part(parent, B.boxm(Vector3(0.025, 0.035, rz1 - rz0)), Vector3(sx * (roof_x - 0.0125), top + 0.005, (rz0 + rz1) / 2.0), bar)
		var wp := part(parent, B.boxm(Vector3(0.45, 0.015, 0.02)), wf0.lerp(wf1, 0.08) + Vector3(sx * 0.28 - 0.06, 0.03, 0), frame)
		wp.rotation.z = 0.08 * sx
	part(parent, B.boxm(Vector3(GLASS_W - 0.1, 0.012, 0.06)), Vector3(0, hood_y.call(WS0 - 0.06) + 0.006, WS0 - 0.06), frame)
	var lip_z: float = sqrt(LIP_R * LIP_R - pow(0.36 - ARCH_Y, 2.0))
	for sx in [-1.0, 1.0]:
		var fx: float = sx * (GLASS_W / 2.0 + 0.016)
		# Pilarit: ulkopinta katon alareunan tasossa ja yläpää katon alle (ei porrasta katon reunaan).
		var ax: float = sx * (roof_x - 0.03)
		slab(parent, wf0 + Vector3(ax, 0, 0), wf1 + Vector3(ax, 0, 0) + (wf1 - wf0).normalized() * 0.02, 0.06, 0.06, body)  # A-pilari
		var ex: float = sx * (roof_x - 0.05)
		slab(parent, wr0 + Vector3(ex, 0, 0) - hat * 0.03, wr1 + Vector3(ex, 0, 0), 0.1, 0.06, body)  # C-pilarin takareuna
		# C-pilari: musta muovinen levy takaoven ikkunasta takalasiin (2105, sivukuva Krakova), alaosassa tuuletusritilä.
		_side_panel(parent, sx * (GLASS_W / 2.0 + 0.012), [Vector2(QA, top), Vector2(HT0, top), Vector2(HT1, HT_Y), Vector2(HT1, BELT), Vector2(QB, BELT)], frame)
		part(parent, B.boxm(Vector3(0.012, 0.06, 0.13)), Vector3(sx * (GLASS_W / 2.0 + 0.016), BELT + 0.1, 1.08), frame)
		for k in 3:
			part(parent, B.boxm(Vector3(0.014, 0.006, 0.12)), Vector3(sx * (GLASS_W / 2.0 + 0.018), BELT + 0.08 + k * 0.02, 1.08), bar)
		# Ikkunalistat: kromi ylhäällä ja vyölinjalla, musta B-pilari, tuuletusikkunan ja takaoven ikkunan pystylistat.
		part(parent, B.boxm(Vector3(0.02, 0.025, QA - WS1)), Vector3(fx, top - 0.0125, (WS1 + QA) / 2.0), bar)
		part(parent, B.boxm(Vector3(0.02, 0.025, QB - WS0)), Vector3(fx, BELT + 0.0125, (WS0 + QB) / 2.0), bar)
		slab(parent, Vector3(fx, top, QA), Vector3(fx, BELT, QB), 0.02, 0.03, bar)
		part(parent, B.boxm(Vector3(0.05, top - BELT, 0.07)), Vector3(fx, (BELT + top) / 2.0, BP), frame)  # B-pilari
		var vent_top: float = lerpf(BELT, top, (VENT - WS0) / (WS1 - WS0))
		part(parent, B.boxm(Vector3(0.02, vent_top - BELT, 0.02)), Vector3(fx, (BELT + vent_top) / 2.0, VENT), bar)  # tuuletusikkuna
		# Kylki: ovisaumat, kahvat, peili, sivuvilkku, musta kumilista helmassa ja pyöränkaaret.
		var sz: float = sx * (SIDE + 0.003)
		for dz in [WS0 + 0.04, BP + 0.04, WHEEL_Z - LIP_R - 0.03]:
			part(parent, B.boxm(Vector3(0.01, BELT - SILL - SC * 2.0 - 0.04, 0.012)), Vector3(sz, (SILL + BELT) / 2.0, dz), frame)
		for hz in [BP - 0.1, WHEEL_Z - LIP_R - 0.12]:
			part(parent, B.boxm(Vector3(0.025, 0.03, 0.11)), Vector3(sx * (SIDE + 0.008), 0.83, hz), bar)  # kahvat
		part(parent, B.boxm(Vector3(0.1, 0.08, 0.13)), Vector3(sx * (SIDE + 0.05), BELT + 0.07, WS0 + 0.1), frame)  # peili
		part(parent, B.boxm(Vector3(0.02, 0.06, 0.1)), Vector3(sx * (SIDE + 0.1), BELT + 0.07, WS0 + 0.1), glass())
		part(parent, B.boxm(Vector3(0.02, 0.04, 0.08)), Vector3(sx * (SIDE + 0.004), 0.68, FRONT + 0.3), amber)  # sivuvilkku
		var z0: float = -WHEEL_Z + lip_z + 0.02
		var z1: float = WHEEL_Z - lip_z - 0.02
		_bevel_box(parent, Vector3(0.03, 0.05, z1 - z0), Vector3(sx * (SIDE + 0.008), 0.36, (z0 + z1) / 2.0), 0.01, frame)
		for wz in [-WHEEL_Z, WHEEL_Z]:
			_wheel_arch(parent, sx, SIDE, SILL, wz, ARCH_R, ARCH_Y, LIP_R, frame, body)
	# Tankkiluukku oikeassa takakyljessä.
	part(parent, B.boxm(Vector3(0.012, 0.11, 0.11)), Vector3(SIDE + 0.004, 0.74, 1.72), frame)
	part(parent, B.boxm(Vector3(0.014, 0.095, 0.095)), Vector3(SIDE + 0.005, 0.74, 1.72), body)
	# Pysty keula: ajovalot kromikehyksin (valo vaakaurin ja oranssi vilkku ulkona), musta vaakasäleikkö ja merkki.
	var lens := _mat("ponylinssi", Color(0.62, 0.65, 0.68), 0.3, 0.15)
	var fz: float = FRONT - 0.01
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.415, 0.155, 0.02)), Vector3(sx * 0.5375, LAMP_Y, fz), bar)  # kehys linssin ja vilkun ympärillä
		part(parent, B.boxm(Vector3(0.295, 0.135, 0.02)), Vector3(sx * 0.48, LAMP_Y, fz - 0.005), _mat("ponyvalo", Color(0.74, 0.76, 0.75), 0.2, 0.1))
		part(parent, B.cyl(0.055, 0.055, 0.02, 20), Vector3(sx * 0.48, LAMP_Y, fz - 0.008), lens, Vector3(PI / 2.0, 0, 0))
		part(parent, B.cyl(0.03, 0.03, 0.02, 16), Vector3(sx * 0.48, LAMP_Y, fz - 0.011), lamp(Color(1.0, 0.98, 0.9)), Vector3(PI / 2.0, 0, 0))
		for k in 3:
			part(parent, B.boxm(Vector3(0.295, 0.004, 0.02)), Vector3(sx * 0.48, LAMP_Y - 0.035 + k * 0.035, fz - 0.012), lens)
		part(parent, B.boxm(Vector3(0.105, 0.135, 0.02)), Vector3(sx * 0.685, LAMP_Y, fz - 0.005), amber)
	part(parent, B.boxm(Vector3(0.66, 0.15, 0.02)), Vector3(0, LAMP_Y, fz), frame)
	var slat := _mat("saabsale", Color(0.2, 0.2, 0.21), 0.3, 0.5)
	for k in 5:
		part(parent, B.boxm(Vector3(0.62, 0.01, 0.02)), Vector3(0, LAMP_Y - 0.05 + k * 0.025, fz - 0.006), slat)
	part(parent, B.boxm(Vector3(0.05, 0.07, 0.02)), Vector3(0, LAMP_Y, fz - 0.012), bar)  # merkki
	part(parent, B.boxm(Vector3(0.035, 0.05, 0.02)), Vector3(0, LAMP_Y, fz - 0.014), lamp(Color(0.7, 0.05, 0.05)))
	# Perä: kulmien takavalot (punainen yläosa, alhaalla oranssi vilkku ulkona ja peruutusvalo sisällä), kilpi välissä.
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.38, 0.18, 0.02)), Vector3(sx * 0.56, TAIL_Y, BACK + 0.005), frame)
		part(parent, B.boxm(Vector3(0.35, 0.08, 0.03)), Vector3(sx * 0.56, TAIL_Y + 0.04, BACK + 0.01), lamp(Color(0.72, 0.02, 0.05)))
		part(parent, B.boxm(Vector3(0.22, 0.07, 0.03)), Vector3(sx * 0.625, TAIL_Y - 0.04, BACK + 0.01), amber)
		part(parent, B.boxm(Vector3(0.12, 0.07, 0.03)), Vector3(sx * 0.445, TAIL_Y - 0.04, BACK + 0.01), lamp(Color(0.95, 0.95, 0.92)))
		for k in 3:
			part(parent, B.boxm(Vector3(0.35, 0.004, 0.032)), Vector3(sx * 0.56, TAIL_Y + 0.015 + k * 0.02, BACK + 0.01), frame)
	part(parent, B.boxm(Vector3(0.56, 0.15, 0.02)), Vector3(0, TAIL_Y - 0.01, BACK + 0.005), frame)  # kilven syvennys
	# Alumiinipuskurit mustalla kumilistalla ja mustilla kulmapäädyillä, pakoputki ja kuraläpät.
	for bz in [FRONT - 0.02, BACK + 0.02]:
		var face: float = signf(bz) * 0.05
		_bevel_box(parent, Vector3(SIDE * 2.0 - 0.1, BUMP_H, 0.1), Vector3(0, BUMP_Y, bz), 0.025, alu)
		part(parent, B.boxm(Vector3(SIDE * 2.0 - 0.2, 0.035, 0.01)), Vector3(0, BUMP_Y, bz + face), frame)
		for sx in [-1.0, 1.0]:
			_bevel_box(parent, Vector3(0.12, BUMP_H + 0.01, 0.24), Vector3(sx * (SIDE - 0.04), BUMP_Y, bz - signf(bz) * 0.06), 0.03, frame)
	part(parent, B.cyl(0.025, 0.025, 0.1, 8), Vector3(-0.45, 0.3, BACK + 0.03), bar, Vector3(PI / 2.0, 0, 0))
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.16, 0.2, 0.012)), Vector3(sx * 0.7, 0.2, WHEEL_Z + WHEEL_R + 0.09), frame)
	_plate(parent, Vector3(0, BUMP_Y - 0.11, FRONT - 0.04), false, plate)
	_plate(parent, Vector3(0, TAIL_Y - 0.01, BACK + 0.02), true, plate)
	_merge_parts(parent, first, "lada/" + color.to_html())
	var badge := Label3D.new()
	badge.text = "LADA"
	badge.font_size = 32
	badge.pixel_size = 0.0018
	badge.outline_size = 0
	badge.modulate = Color(0.85, 0.86, 0.88)
	badge.double_sided = false
	badge.position = Vector3(-0.55, TAIL_Y + 0.13, BACK + 0.005)
	parent.add_child(badge)
	var steel := _mat("ladavanne", Color(0.75, 0.76, 0.77), 0.4, 0.4)
	var wheels: Array[Node3D] = []
	for sx in [-0.71, 0.71]:  # raide 1420 (esikuva 1365/1321): pyörä ulottuu kotelon mustan levyn ulkopuolelle
		for wz in [-WHEEL_Z, WHEEL_Z]:
			wheels.append(wheel(parent, Vector3(sx, WHEEL_R, wz), WHEEL_R, 0.175, 0, steel, 0.6))  # peltivanteet
	return wheels


## Honda Civic 3-ovinen (neljäs sukupolvi, 1987–91) -Z-suuntaan: matala viistoperä n. 1,67 × 1,33 × 3,97 m, akseliväli
## 2,50 m, renkaat 175/70R13. Mitat Honda Civic 3-Door 1990 -blueprintista (getoutlines.com, sivukuva 344,8 px/m
## akselivälistä: ylitykset 0,79/0,67) ja virallisista mitoista (3965 × 1666 × 1331). Esikuvat Wikimedia Commonsista
## (Civic SiR EF9 keula, 1990 Civic Si kylki, 1990 Civic STD Rio Red perä): matala kiilakeula, jossa leveät upotetut
## valot kaltevalla keulapinnalla ja H-merkki, hyvin loiva tuulilasi, pitkä ovi ja iso takasivuikkuna, pitkä katto
## spoilerilla, jyrkkä takalasi, koko perän levyinen takavalonauha CIVIC-paneelilla, tummat puskurit ja kylkilista.
## Kori ja lasit kuten Saabissa (katto pilarien yli, sadevesilistat). Palauttaa pyörät kuten car().
static func civic(parent: Node3D, color: Color, plate := "") -> Array[Node3D]:
	const SIDE := 0.82  # kyljen x: listoineen leveys 1666 mm
	const SILL := 0.20  # alakorin alapinta
	const NOSE_LO := 0.50  # kaltevan keulapinnan alareuna (puskurin yläreuna peittää)
	const NOSE_Y := 0.66  # konepellin etureuna
	const NOSE_RAKE := 0.10  # keulapinnan yläreuna on näin paljon alareunaa takana
	const HOOD_MID := Vector2(-1.40, 0.815)  # konepellin kaari blueprintista
	const BELT := 0.88  # vyötärölinja, ikkunoiden alareuna
	const ROOF := 1.33  # katon yläpinta (1331 mm)
	const ROOF_T := 0.05
	const FRONT := -1.98  # keulapinnan alareuna z: puskurin etupinta 0,79 m etupyörän edessä
	const BACK := 1.86  # peräpaneeli z: puskurin takapinta 0,67 m takapyörän takana
	const WS0 := -0.90  # tuulilasin alareuna z
	const WS1 := -0.07  # tuulilasin yläreuna z (hyvin loiva lasi)
	const HT0 := 1.50  # takalasin yläreuna z (pitkä katto)
	const HT1 := 1.80  # takalasin alareuna z (jyrkkä luukku)
	const HT_Y := 0.93  # takalasin alareuna y = peräpaneelin yläreuna
	const BP := 0.52  # B-pilari z (pitkä 3-ovisen ovi)
	const QA := 1.42  # takasivuikkunan takareuna ylhäällä z
	const QB := 1.66  # takasivuikkunan takareuna vyölinjalla z
	const GLASS_W := 1.36
	const LAMP_Y := 0.585  # ajovalojen keskikorkeus kaltevalla keulapinnalla
	const TAIL_Y := 0.80  # takavalonauhan keskikorkeus
	const WHEEL_R := 0.29  # 175/70R13
	const WHEEL_Z := 1.25  # akseliväli 2500 mm
	const ARCH_R := WHEEL_R + 0.045
	const ARCH_Y := ARCH_R
	const LIP_R := ARCH_R + 0.04
	const SC := 0.03
	const CF := 0.035
	const ROOF_C := 0.024
	var first := parent.get_child_count()
	var body := paint(color)
	var win := _mat("ponylasi", Color(0.22, 0.27, 0.32), 0.3, 0.05, 0.32)
	var frame := plastic()
	var bar := _mat("ponykromi", Color(0.86, 0.87, 0.89), 0.45, 0.3)
	var dark := _mat("civicpuskuri", Color(0.2, 0.21, 0.22), 0.0, 0.7)  # tummanharmaat puskurit ja listat
	var amber := lamp(Color(1.0, 0.42, 0.04))
	if plate == "":
		plate = "%s%s%s-%d" % [char(65 + randi() % 26), char(65 + randi() % 26), char(65 + randi() % 26), 100 + randi() % 900]
	var top := ROOF - ROOF_T
	var roof_x := GLASS_W / 2.0 + 0.03  # katon alareunan x = pilarien ja sadevesilistojen ulkopinta
	# Alakori, kaareva konepelti, kalteva keulapinta ja peräpaneeli yhtenä viistettynä sivuprofiilina.
	var face_len := Vector2(NOSE_RAKE, NOSE_Y - NOSE_LO).length()
	var nose_top := Vector2(FRONT + NOSE_RAKE, NOSE_Y)
	var hood_dir := (HOOD_MID - nose_top).normalized()
	_bevel(parent, PackedVector2Array([Vector2(FRONT, SILL + CF), Vector2(FRONT + CF, SILL), Vector2(BACK - CF, SILL),
		Vector2(BACK, SILL + CF), Vector2(BACK, HT_Y - CF), Vector2(BACK - CF, HT_Y), Vector2(HT1 - 0.04, HT_Y),
		Vector2(HT1 - 0.04, BELT), Vector2(WS0, BELT), HOOD_MID, nose_top + hood_dir * CF,
		nose_top - Vector2(NOSE_RAKE, NOSE_Y - NOSE_LO) / face_len * CF, Vector2(FRONT, NOSE_LO)]), SIDE, SC, body)
	# Lasit: sivulasi tuulilasin reunasta takasivuikkunan viistoon takareunaan, sisusta, tuulilasi, takalasi.
	var wf0 := Vector3(0, BELT, WS0)
	var wf1 := Vector3(0, top, WS1)
	var wr0 := Vector3(0, top, HT0)
	var wr1 := Vector3(0, HT_Y, HT1)
	var hat := (wr1 - wr0).normalized()
	for sx in [-1.0, 1.0]:
		_side_panel(parent, sx * GLASS_W / 2.0, [Vector2(WS0, BELT), Vector2(WS1, top), Vector2(QA, top), Vector2(QB, BELT)], win)
	_cabin(parent, BELT, top, WS0, WS1, HT0, HT1, HT_Y, GLASS_W, bar, 0.25, 1.1, 1.45, 0.6)
	slab(parent, wf0, wf1, GLASS_W + 0.02, 0.04, win)  # tuulilasi
	slab(parent, wr0, wr1, GLASS_W + 0.02, 0.04, win)  # takalasi
	_bevel_box(parent, Vector3((roof_x + ROOF_C) * 2.0, ROOF_T, HT0 - WS1 + 0.04), Vector3(0, ROOF - ROOF_T / 2.0, (WS1 + HT0) / 2.0), ROOF_C, body)  # katto
	# Kattospoileri luukun yläreunassa, kumilistat, sadevesilistat pilarien välissä, pyyhkimet ja ilmanottoritilä.
	slab(parent, Vector3(0, ROOF + 0.006, HT0 - 0.14), Vector3(0, ROOF - 0.012, HT0 + 0.1), GLASS_W + 0.04, 0.025, frame)  # katon päällä, ei upotettuna
	slab(parent, wr0, wr0.lerp(wr1, 0.08), GLASS_W, 0.05, frame)
	slab(parent, wr0.lerp(wr1, 0.95), wr1, GLASS_W, 0.05, frame)
	slab(parent, wf0.lerp(wf1, 0.96), wf1 + (wf1 - wf0).normalized() * 0.01, GLASS_W + 0.02, 0.05, frame)
	part(parent, B.boxm(Vector3(0.5, 0.012, 0.02)), wr0.lerp(wr1, 0.7) + hat.cross(Vector3.RIGHT) * 0.03, frame)  # takapyyhin
	for sx in [-1.0, 1.0]:
		var rz0 := WS1 + 0.015
		var rz1 := HT0 - 0.13
		part(parent, B.boxm(Vector3(0.025, 0.035, rz1 - rz0)), Vector3(sx * (roof_x - 0.0125), top + 0.005, (rz0 + rz1) / 2.0), frame)
		var wp := part(parent, B.boxm(Vector3(0.55, 0.015, 0.02)), wf0.lerp(wf1, 0.06) + Vector3(sx * 0.3 - 0.06, 0.03, 0), frame)
		wp.rotation.z = 0.06 * sx
	var hood_y := func(z: float) -> float: return lerpf(BELT, HOOD_MID.y, (z - WS0) / (HOOD_MID.x - WS0))
	part(parent, B.boxm(Vector3(GLASS_W - 0.1, 0.012, 0.06)), Vector3(0, hood_y.call(WS0 - 0.06) + 0.006, WS0 - 0.06), frame)
	var lip_z: float = sqrt(LIP_R * LIP_R - pow(0.47 - ARCH_Y, 2.0))
	for sx in [-1.0, 1.0]:
		var fx: float = sx * (GLASS_W / 2.0 + 0.016)
		# Pilarit katon alareunan tasossa ja yläpää katon alle (ei porrasta katon reunaan).
		var ax: float = sx * (roof_x - 0.035)
		slab(parent, wf0 + Vector3(ax, 0, 0), wf1 + Vector3(ax, 0, 0) + (wf1 - wf0).normalized() * 0.02, 0.07, 0.06, body)  # A-pilari
		var ex: float = sx * (roof_x - 0.05)
		slab(parent, wr0 + Vector3(ex, 0, 0) - hat * 0.03, wr1 + Vector3(ex, 0, 0), 0.1, 0.06, body)  # takaluukun reuna
		_side_panel(parent, sx * (GLASS_W / 2.0 + 0.012), [Vector2(QA, top), Vector2(HT0, top), Vector2(HT1, HT_Y), Vector2(HT1, BELT), Vector2(QB, BELT)], body)
		# Mustat ikkunakehykset ja B-pilari.
		part(parent, B.boxm(Vector3(0.02, 0.03, QA - WS1)), Vector3(fx, top - 0.015, (WS1 + QA) / 2.0), frame)
		part(parent, B.boxm(Vector3(0.02, 0.03, QB - WS0)), Vector3(fx, BELT + 0.015, (WS0 + QB) / 2.0), frame)
		slab(parent, Vector3(fx, top, QA), Vector3(fx, BELT, QB), 0.02, 0.03, frame)
		part(parent, B.boxm(Vector3(0.05, top - BELT, 0.08)), Vector3(fx, (BELT + top) / 2.0, BP), frame)
		# Kylki: ovisaumat, kahva, peili, musta kylkilista pyöränkaaresta toiseen ja pyöränkaaret.
		var sz: float = sx * (SIDE + 0.003)
		var door0: float = -WHEEL_Z + LIP_R + 0.06
		for dz in [door0, BP + 0.08]:
			part(parent, B.boxm(Vector3(0.01, BELT - SILL - SC * 2.0 - 0.04, 0.012)), Vector3(sz, (SILL + BELT) / 2.0, dz), frame)
		part(parent, B.boxm(Vector3(0.03, 0.03, 0.12)), Vector3(sx * (SIDE + 0.01), 0.79, BP - 0.08), frame)  # kahva
		part(parent, B.boxm(Vector3(0.11, 0.09, 0.15)), Vector3(sx * (SIDE + 0.055), BELT + 0.08, WS0 + 0.22), frame)  # peili
		part(parent, B.boxm(Vector3(0.02, 0.07, 0.12)), Vector3(sx * (SIDE + 0.11), BELT + 0.08, WS0 + 0.22), glass())
		var z0: float = -WHEEL_Z + lip_z + 0.02
		var z1: float = WHEEL_Z - lip_z - 0.02
		_bevel_box(parent, Vector3(0.025, 0.06, z1 - z0), Vector3(sx * (SIDE + 0.006), 0.47, (z0 + z1) / 2.0), 0.01, dark)
		for wz in [-WHEEL_Z, WHEEL_Z]:
			_wheel_arch(parent, sx, SIDE, SILL, wz, ARCH_R, ARCH_Y, LIP_R, frame, body)
	part(parent, B.boxm(Vector3(0.012, 0.1, 0.12)), Vector3(SIDE + 0.004, 0.74, 1.62), frame)  # tankkiluukku oikeassa takakyljessä
	part(parent, B.boxm(Vector3(0.014, 0.085, 0.105)), Vector3(SIDE + 0.005, 0.74, 1.62), body)
	# Kalteva keula: leveät upotetut ajovalot, niiden välissä kapea säleikkörako ja H-merkki konepellin reunassa.
	var tilt := atan2(NOSE_RAKE, NOSE_Y - NOSE_LO)
	var out_n := Vector3(0, sin(tilt), -cos(tilt))
	var face := func(x: float, y: float, d: float) -> Vector3:
		return Vector3(x, y, FRONT + (y - NOSE_LO) / (NOSE_Y - NOSE_LO) * NOSE_RAKE) + out_n * d
	var rot := Vector3(tilt, 0, 0)
	var rot_c := Vector3(tilt + PI / 2.0, 0, 0)
	var lens := _mat("ponylinssi", Color(0.62, 0.65, 0.68), 0.3, 0.15)
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.52, 0.11, 0.02)), face.call(sx * 0.49, LAMP_Y, 0.0), frame, rot)
		part(parent, B.boxm(Vector3(0.5, 0.09, 0.02)), face.call(sx * 0.49, LAMP_Y, 0.005), _mat("ponyvalo", Color(0.74, 0.76, 0.75), 0.2, 0.1), rot)
		part(parent, B.cyl(0.04, 0.04, 0.02, 18), face.call(sx * 0.42, LAMP_Y, 0.008), lens, rot_c)
		part(parent, B.cyl(0.025, 0.025, 0.02, 14), face.call(sx * 0.42, LAMP_Y, 0.011), lamp(Color(1.0, 0.98, 0.9)), rot_c)
		for k in 2:
			part(parent, B.boxm(Vector3(0.5, 0.004, 0.02)), face.call(sx * 0.49, LAMP_Y - 0.02 + k * 0.04, 0.012), lens, rot)
	part(parent, B.boxm(Vector3(0.44, 0.04, 0.02)), face.call(0.0, LAMP_Y - 0.02, 0.0), frame, rot)  # säleikkörako
	part(parent, B.boxm(Vector3(0.06, 0.045, 0.02)), face.call(0.0, NOSE_Y - 0.03, 0.006), bar, rot)  # H-merkki
	part(parent, B.boxm(Vector3(0.04, 0.03, 0.02)), face.call(0.0, NOSE_Y - 0.03, 0.009), frame, rot)
	# Puskurit: keulassa korinvärinen yläosa punaisella raidalla ja tumma alaosa, jossa aukot ja kulmien vilkut;
	# perässä iso tumma puskuri, jossa kilpi. Molemmat kiertävät kylkeen pyöränkaareen asti.
	var stripe := _mat("ponyraita", Color(0.75, 0.08, 0.06), 0.0, 0.5)
	_bevel_box(parent, Vector3(SIDE * 2.0, 0.1, 0.12), Vector3(0, 0.47, FRONT + 0.0), 0.03, body)
	part(parent, B.boxm(Vector3(SIDE * 2.0 - 0.04, 0.012, 0.005)), Vector3(0, 0.45, FRONT - 0.062), stripe)
	_bevel_box(parent, Vector3(SIDE * 2.0, 0.2, 0.12), Vector3(0, 0.32, FRONT + 0.0), 0.03, dark)
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.28, 0.07, 0.02)), Vector3(sx * 0.32, 0.32, FRONT - 0.065), frame)  # ilma-aukot
		part(parent, B.boxm(Vector3(0.16, 0.06, 0.02)), Vector3(sx * 0.66, 0.33, FRONT - 0.066), amber)  # vilkut puskurin kulmissa
		var fz0: float = FRONT + 0.05
		var fz1: float = -WHEEL_Z - lip_z - 0.015
		_bevel_box(parent, Vector3(0.04, 0.3, fz1 - fz0), Vector3(sx * SIDE, 0.37, (fz0 + fz1) / 2.0), 0.015, dark)
		var rz0b: float = WHEEL_Z + lip_z + 0.015
		_bevel_box(parent, Vector3(0.04, 0.3, BACK - rz0b), Vector3(sx * SIDE, 0.37, (rz0b + BACK) / 2.0), 0.015, dark)
	_bevel_box(parent, Vector3(SIDE * 2.0, 0.32, 0.12), Vector3(0, 0.38, BACK + 0.0), 0.035, dark)
	# Takavalonauha koko perän levyltä: kulmissa punaiset valot (alhaalla vilkku ja peruutusvalo), keskellä tumma
	# punainen paneeli CIVIC-tekstillä, H-merkki yläpuolella.
	part(parent, B.boxm(Vector3(SIDE * 2.0 - 0.06, 0.15, 0.02)), Vector3(0, TAIL_Y, BACK + 0.005), frame)
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.36, 0.07, 0.03)), Vector3(sx * 0.6, TAIL_Y + 0.03, BACK + 0.01), lamp(Color(0.72, 0.02, 0.05)))
		part(parent, B.boxm(Vector3(0.2, 0.05, 0.03)), Vector3(sx * 0.68, TAIL_Y - 0.035, BACK + 0.01), amber)
		part(parent, B.boxm(Vector3(0.14, 0.05, 0.03)), Vector3(sx * 0.5, TAIL_Y - 0.035, BACK + 0.01), lamp(Color(0.95, 0.95, 0.92)))
		part(parent, B.boxm(Vector3(0.02, 0.12, 0.1)), Vector3(sx * (SIDE + 0.002), TAIL_Y, BACK - SC - 0.05), lamp(Color(0.72, 0.02, 0.05)))  # kulman ympäri kyljen tasaisella osalla
	part(parent, B.boxm(Vector3(0.7, 0.11, 0.03)), Vector3(0, TAIL_Y, BACK + 0.01), _mat("civicpaneeli", Color(0.35, 0.03, 0.05), 0.3, 0.3))
	part(parent, B.boxm(Vector3(0.06, 0.045, 0.02)), Vector3(0, TAIL_Y + 0.1, BACK + 0.005), bar)  # H-merkki
	part(parent, B.cyl(0.028, 0.028, 0.06, 8), Vector3(-0.5, 0.24, BACK + 0.04), bar, Vector3(PI / 2.0, 0, 0))  # pakoputki
	_plate(parent, Vector3(0, 0.3, FRONT - 0.068), false, plate)
	_plate(parent, Vector3(0, 0.36, BACK + 0.068), true, plate)
	_merge_parts(parent, first, "civic/" + color.to_html())
	var badge := Label3D.new()
	badge.text = "CIVIC"
	badge.font_size = 32
	badge.pixel_size = 0.0022
	badge.outline_size = 0
	badge.modulate = Color(0.85, 0.86, 0.88)
	badge.double_sided = false
	badge.position = Vector3(0, TAIL_Y, BACK + 0.027)
	parent.add_child(badge)
	var hub := _mat("ponyvanne", Color(0.78, 0.79, 0.8), 0.5, 0.35)
	var wheels: Array[Node3D] = []
	for sx in [-0.74, 0.74]:  # raide 1480 (esikuva n. 1450): pyörä ulottuu kotelon mustan levyn ulkopuolelle
		for wz in [-WHEEL_Z, WHEEL_Z]:
			wheels.append(wheel(parent, Vector3(sx, WHEEL_R, wz), WHEEL_R, 0.18, 0, hub, 0.68, 8))
	return wheels


## Volvo 240 (1986–93) -Z-suuntaan: 244 sedan tai 245 farmari (farmari = true) n. 1,71 × 1,44 × 4,74 m puskureineen,
## akseliväli 2,64 m, raide 1430/1360, renkaat 185/70R14. Mitat Volvo 240 ja 245 -blueprinteista (getoutlines.com,
## sivukuvat 91,5 px/m akselivälistä, pystysuunta korkeudesta 1435) ja virallisista mitoista (4785 × 1715, akseliväli
## 2640). Esikuvat Wikimedia Commonsista (1988–91 Volvo 240 GL farmari keula ja kylki, 1993 Volvo 240 SE farmari perä):
## laatikkomainen kori, pysty keula, jossa suorakaiteiset ajovalot ja kulman ympäri kiertävät oranssit vilkut,
## kromikehyksinen musta pystysäleikkö vinolla palkilla ja rautamerkillä, isot mustat puskurit, musta kylkilista ja
## helmalista. Sedanissa takalasi laskee pitkälle tavaratilalle ja kulmissa on vaakaurilliset takavalot; farmarissa
## suora katto kattokiskoineen, iso takasivuikkuna, lähes pysty takaluukku ja korkeat takavalot D-pilareissa.
## Palauttaa pyörät kuten car().
static func volvo(parent: Node3D, color: Color, plate := "", farmari := false) -> Array[Node3D]:
	const SIDE := 0.84  # kyljen x: listoineen leveys 1715 mm
	const SILL := 0.22  # alakorin alapinta
	const NOSE_LO := 0.48  # pystyn keulapinnan alareuna (puskuri peittää)
	const NOSE_Y := 0.88  # konepellin etureuna
	const BELT := 0.99  # vyötärölinja, ikkunoiden alareuna
	const ROOF := 1.44  # katon yläpinta (1435 sedan; farmarissa kiskot päälle)
	const ROOF_T := 0.05
	const FRONT := -2.08  # keulapinta z
	const BACK := 2.44  # peräpaneeli z
	const WS0 := -0.75  # tuulilasin alareuna z
	const WS1 := -0.31  # tuulilasin yläreuna z
	const BP := 0.24  # B-pilari z
	const RW := 1.0  # takaoven ikkunan takareuna z
	const GLASS_W := 1.44  # leveä ohjaamo: kyljet lähes pystyt
	const LAMP_Y := 0.72  # ajovalojen keskikorkeus
	const BUMP_Y := 0.45  # puskurien keskikorkeus
	const BUMP_H := 0.22
	const WHEEL_R := 0.307  # 185/70R14
	const WHEEL_Z := 1.32  # akseliväli 2640 mm
	const ARCH_R := WHEEL_R + 0.045
	const ARCH_Y := ARCH_R
	const LIP_R := ARCH_R + 0.04
	const SC := 0.03
	const CF := 0.035
	const ROOF_C := 0.024
	# Sedan: katto päättyy z 1,20, takalasi laskee tavaratilan kanteen (1,60; 1,04), kansi viettää perään 0,99:ään.
	# Farmari: katto jatkuu z 2,20:een, takaluukun lasi lähes pysty (2,37; 0,98), takasivuikkuna takaovesta D-pilariin.
	var ht0 := 2.20 if farmari else 1.20  # takalasin yläreuna z (katon takareuna)
	var ht1 := 2.37 if farmari else 1.60  # takalasin alareuna z
	var ht_y := 0.98 if farmari else 1.04  # takalasin alareuna y
	var tail_top := 0.98 if farmari else 0.99  # peräpaneelin yläreuna
	var qa := 2.06 if farmari else 0.98  # viimeisen sivuikkunan takareuna ylhäällä z
	var qb := 2.12 if farmari else 1.06  # ... vyölinjalla z
	var tail_y := 0.80 if farmari else 0.80  # takavalojen keskikorkeus
	var first := parent.get_child_count()
	var body := paint(color)
	var win := _mat("ponylasi", Color(0.22, 0.27, 0.32), 0.3, 0.05, 0.32)
	var frame := plastic()
	var bar := _mat("ponykromi", Color(0.86, 0.87, 0.89), 0.45, 0.3)
	var amber := lamp(Color(1.0, 0.42, 0.04))
	var red := lamp(Color(0.72, 0.02, 0.05))
	if plate == "":
		plate = "%s%s%s-%d" % [char(65 + randi() % 26), char(65 + randi() % 26), char(65 + randi() % 26), 100 + randi() % 900]
	var top := ROOF - ROOF_T
	var roof_x := GLASS_W / 2.0 + 0.03  # katon alareunan x = pilarien ja sadevesilistojen ulkopinta
	# Alakori, konepelti, pysty keula, (sedanissa viettävä tavaratilan kansi) ja peräpaneeli yhtenä viistettynä profiilina.
	_bevel(parent, PackedVector2Array([Vector2(FRONT, SILL + CF), Vector2(FRONT + CF, SILL), Vector2(BACK - CF, SILL),
		Vector2(BACK, SILL + CF), Vector2(BACK, tail_top - CF), Vector2(BACK - CF, tail_top), Vector2(ht1 - 0.04, ht_y),
		Vector2(ht1 - 0.04, BELT), Vector2(WS0, BELT), Vector2(FRONT + CF, NOSE_Y), Vector2(FRONT, NOSE_Y - CF)]), SIDE, SC, body)
	var hood_y := func(z: float) -> float: return lerpf(NOSE_Y, BELT, (z - FRONT) / (WS0 - FRONT))
	var deck_y := func(z: float) -> float: return lerpf(ht_y, tail_top, (z - ht1 + 0.04) / maxf(BACK - CF - ht1 + 0.04, 0.01))
	# Lasit: sivulasi tuulilasista viimeisen sivuikkunan takareunaan, sisusta, tuulilasi ja takalasi.
	var wf0 := Vector3(0, BELT, WS0)
	var wf1 := Vector3(0, top, WS1)
	var wr0 := Vector3(0, top, ht0)
	var wr1 := Vector3(0, ht_y, ht1)
	var hat := (wr1 - wr0).normalized()
	for sx in [-1.0, 1.0]:
		_side_panel(parent, sx * GLASS_W / 2.0, [Vector2(WS0, BELT), Vector2(WS1, top), Vector2(qa, top), Vector2(qb, BELT)], win)
	if farmari:
		_cabin(parent, BELT, top, WS0, WS1, ht0, ht1, ht_y, GLASS_W, bar, 0.2, 1.08, 1.72, 1.1, ISTUIMET.volvo.ratti)  # hylly = tavaratilan lattia
	else:
		_cabin(parent, BELT, top, WS0, WS1, ht0, ht1, ht_y, GLASS_W, bar, 0.2, 1.02, 1.32, 0.48, ISTUIMET.volvo.ratti)
	slab(parent, wf0, wf1, GLASS_W + 0.02, 0.04, win)  # tuulilasi
	slab(parent, wr0, wr1, GLASS_W + 0.02, 0.04, win)  # takalasi
	_bevel_box(parent, Vector3((roof_x + ROOF_C) * 2.0, ROOF_T, ht0 - WS1 + 0.04), Vector3(0, ROOF - ROOF_T / 2.0, (WS1 + ht0) / 2.0), ROOF_C, body)  # katto
	# Kumilistat, sadevesilistat pilarien välissä, pyyhkimet ja konepellin takareunan ilmanottoritilä.
	slab(parent, wr0, wr0.lerp(wr1, 0.05), GLASS_W, 0.05, frame)
	slab(parent, wr0.lerp(wr1, 0.95), wr1, GLASS_W, 0.05, frame)
	slab(parent, wf0.lerp(wf1, 0.95), wf1 + (wf1 - wf0).normalized() * 0.01, GLASS_W + 0.02, 0.05, frame)
	for sx in [-1.0, 1.0]:
		var rz0 := WS1 + 0.015
		var rz1 := ht0 - 0.04
		part(parent, B.boxm(Vector3(0.025, 0.035, rz1 - rz0)), Vector3(sx * (roof_x - 0.0125), top + 0.005, (rz0 + rz1) / 2.0), frame)
		var wp := part(parent, B.boxm(Vector3(0.5, 0.015, 0.02)), wf0.lerp(wf1, 0.08) + Vector3(sx * 0.3 - 0.06, 0.03, 0), frame)
		wp.rotation.z = 0.08 * sx
	part(parent, B.boxm(Vector3(GLASS_W - 0.1, 0.012, 0.07)), Vector3(0, hood_y.call(WS0 - 0.07) + 0.006, WS0 - 0.07), frame)
	if farmari:
		# Kattokiskot jaloilla (Pekan kattoteline lepää niiden päällä) ja takaluukun pyyhin.
		for sx in [-1.0, 1.0]:
			part(parent, B.boxm(Vector3(0.035, 0.025, 2.1)), Vector3(sx * (roof_x - 0.09), ROOF + 0.048, 0.95), frame)
			for fz in [-0.08, 0.95, 1.98]:
				part(parent, B.boxm(Vector3(0.04, 0.05, 0.08)), Vector3(sx * (roof_x - 0.09), ROOF + 0.02, fz), frame)
		var rp := part(parent, B.boxm(Vector3(0.5, 0.012, 0.02)), wr0.lerp(wr1, 0.75) + hat.cross(Vector3.RIGHT) * 0.03, frame)
		rp.rotation.z = 0.5
	else:
		# Tavaratilan kannen saumat.
		part(parent, B.boxm(Vector3(GLASS_W - 0.06, 0.004, 0.012)), Vector3(0, deck_y.call(ht1 + 0.04) + 0.003, ht1 + 0.04), frame)
		for sx in [-1.0, 1.0]:
			var lx: float = sx * (GLASS_W / 2.0 - 0.02)
			slab(parent, Vector3(lx, deck_y.call(ht1 + 0.04) + 0.003, ht1 + 0.04), Vector3(lx, deck_y.call(BACK - 0.05) + 0.003, BACK - 0.05), 0.012, 0.004, frame)
	var lip_z: float = sqrt(LIP_R * LIP_R - pow(0.36 - ARCH_Y, 2.0))
	for sx in [-1.0, 1.0]:
		var fx: float = sx * (GLASS_W / 2.0 + 0.016)
		# Pilarit katon alareunan tasossa ja yläpää katon alle (ei porrasta katon reunaan).
		var ax: float = sx * (roof_x - 0.035)
		slab(parent, wf0 + Vector3(ax, 0, 0), wf1 + Vector3(ax, 0, 0) + (wf1 - wf0).normalized() * 0.02, 0.07, 0.06, body)  # A-pilari
		var ex: float = sx * (roof_x - 0.05)
		slab(parent, wr0 + Vector3(ex, 0, 0) - hat * 0.03, wr1 + Vector3(ex, 0, 0), 0.1, 0.06, body)  # C/D-pilarin takareuna
		_side_panel(parent, sx * (GLASS_W / 2.0 + 0.012), [Vector2(qa, top), Vector2(ht0, top), Vector2(ht1, ht_y), Vector2(ht1, BELT), Vector2(qb, BELT)], body)
		# Mustat ikkunakehykset, B-pilari ja takaoven ikkunan takareuna (farmarissa leveä C-pilari).
		part(parent, B.boxm(Vector3(0.02, 0.03, qa - WS1)), Vector3(fx, top - 0.015, (WS1 + qa) / 2.0), frame)
		part(parent, B.boxm(Vector3(0.02, 0.03, qb - WS0)), Vector3(fx, BELT + 0.015, (WS0 + qb) / 2.0), frame)
		slab(parent, Vector3(fx, top, qa), Vector3(fx, BELT, qb), 0.02, 0.03, frame)
		part(parent, B.boxm(Vector3(0.05, top - BELT, 0.08)), Vector3(fx, (BELT + top) / 2.0, BP), frame)  # B-pilari
		part(parent, B.boxm(Vector3(0.05, top - BELT, 0.09 if farmari else 0.03)), Vector3(fx, (BELT + top) / 2.0, RW + (0.03 if farmari else 0.0)), frame)
		# Kylki: ovisaumat, kahvat, peili, musta kylkilista vyön alla ja helmalista, merkki etulokasuojassa.
		var sz: float = sx * (SIDE + 0.003)
		var rear_seam: float = WHEEL_Z - LIP_R - 0.03
		for dz in [WS0 + 0.04, BP + 0.05, rear_seam]:
			part(parent, B.boxm(Vector3(0.01, BELT - SILL - SC * 2.0 - 0.04, 0.012)), Vector3(sz, (SILL + BELT) / 2.0, dz), frame)
		for hz in [BP - 0.1, RW - 0.12]:
			part(parent, B.boxm(Vector3(0.03, 0.035, 0.13)), Vector3(sx * (SIDE + 0.01), 0.88, hz), frame)  # kahvat
		part(parent, B.boxm(Vector3(0.12, 0.1, 0.16)), Vector3(sx * (SIDE + 0.06), BELT + 0.09, WS0 + 0.12), frame)  # peili
		part(parent, B.boxm(Vector3(0.02, 0.08, 0.13)), Vector3(sx * (SIDE + 0.12), BELT + 0.09, WS0 + 0.12), glass())
		part(parent, B.boxm(Vector3(0.025, 0.025, BACK - FRONT - 0.5)), Vector3(sx * (SIDE + 0.006), 0.82, (FRONT + BACK) / 2.0 + 0.05), frame)  # kylkilista
		var z0: float = -WHEEL_Z + lip_z + 0.02
		var z1: float = WHEEL_Z - lip_z - 0.02
		_bevel_box(parent, Vector3(0.03, 0.09, z1 - z0), Vector3(sx * (SIDE + 0.008), 0.33, (z0 + z1) / 2.0), 0.012, frame)  # helmalista
		part(parent, B.boxm(Vector3(0.02, 0.04, 0.08)), Vector3(sx * (SIDE + 0.004), 0.74, FRONT + 0.32), amber)  # sivuvilkku
		for wz in [-WHEEL_Z, WHEEL_Z]:
			_wheel_arch(parent, sx, SIDE, SILL, wz, ARCH_R, ARCH_Y, LIP_R, frame, body)
		# Puskurin kylkiosat pyöränkaariin asti.
		for end in [[FRONT, -WHEEL_Z - lip_z - 0.015], [BACK, WHEEL_Z + lip_z + 0.015]]:
			var za: float = end[0]
			var zb: float = end[1]
			_bevel_box(parent, Vector3(0.05, BUMP_H, absf(za - zb)), Vector3(sx * (SIDE + 0.005), BUMP_Y, (za + zb) / 2.0), 0.015, frame)
	part(parent, B.boxm(Vector3(0.012, 0.11, 0.13)), Vector3(SIDE + 0.004, 0.84, 1.96), frame)  # tankkiluukku oikeassa takakyljessä
	part(parent, B.boxm(Vector3(0.014, 0.095, 0.115)), Vector3(SIDE + 0.005, 0.84, 1.96), body)
	# Pysty keula: ajovalot, kulman ympäri kiertävät vilkut, kromikehyksinen musta pystysäleikkö, vino palkki ja merkki.
	var lens := _mat("ponylinssi", Color(0.62, 0.65, 0.68), 0.3, 0.15)
	var fz: float = FRONT - 0.01
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.36, 0.19, 0.02)), Vector3(sx * 0.53, LAMP_Y, fz), frame)
		part(parent, B.boxm(Vector3(0.34, 0.17, 0.02)), Vector3(sx * 0.53, LAMP_Y, fz - 0.005), _mat("ponyvalo", Color(0.74, 0.76, 0.75), 0.2, 0.1))
		part(parent, B.cyl(0.06, 0.06, 0.02, 20), Vector3(sx * 0.5, LAMP_Y, fz - 0.008), lens, Vector3(PI / 2.0, 0, 0))
		part(parent, B.cyl(0.032, 0.032, 0.02, 16), Vector3(sx * 0.5, LAMP_Y, fz - 0.011), lamp(Color(1.0, 0.98, 0.9)), Vector3(PI / 2.0, 0, 0))
		for k in 3:
			part(parent, B.boxm(Vector3(0.34, 0.004, 0.02)), Vector3(sx * 0.53, LAMP_Y - 0.05 + k * 0.05, fz - 0.012), lens)
		part(parent, B.boxm(Vector3(0.09, 0.17, 0.02)), Vector3(sx * (SIDE - SC - 0.045), LAMP_Y, fz - 0.005), amber)
		part(parent, B.boxm(Vector3(SC * 1.414 + 0.012, 0.17, 0.02)), Vector3(sx * (SIDE - SC / 2.0 + 0.004), LAMP_Y, FRONT + SC / 2.0 - 0.004),
			amber, Vector3(0, -sx * PI / 4.0, 0))  # korin pystyviisteessä
		part(parent, B.boxm(Vector3(0.02, 0.17, 0.09)), Vector3(sx * (SIDE + 0.004), LAMP_Y, FRONT + SC + 0.045), amber)  # kyljen puolella
	part(parent, B.boxm(Vector3(0.62, 0.22, 0.02)), Vector3(0, LAMP_Y, fz), bar)  # säleikön kehys
	part(parent, B.boxm(Vector3(0.58, 0.18, 0.02)), Vector3(0, LAMP_Y, fz - 0.004), frame)
	var slat := _mat("saabsale", Color(0.2, 0.2, 0.21), 0.3, 0.5)
	for k in 13:
		part(parent, B.boxm(Vector3(0.012, 0.17, 0.02)), Vector3(-0.27 + k * 0.045, LAMP_Y, fz - 0.007), slat)
	var diag := part(parent, B.boxm(Vector3(0.66, 0.02, 0.02)), Vector3(0, LAMP_Y, fz - 0.012), bar)
	diag.rotation.z = 0.3  # vino palkki rautamerkin halki
	part(parent, B.cyl(0.04, 0.04, 0.02, 20), Vector3(0.0, LAMP_Y, fz - 0.016), bar, Vector3(PI / 2.0, 0, 0))
	part(parent, B.cyl(0.03, 0.03, 0.02, 20), Vector3(0.0, LAMP_Y, fz - 0.019), _mat("saabsininen", Color(0.08, 0.2, 0.55), 0.2, 0.4), Vector3(PI / 2.0, 0, 0))
	# Perä: sedanissa vaakaurilliset takavalot kulmissa ja kilpi välissä, farmarissa korkeat valot D-pilareissa ja kilpi luukussa.
	if farmari:
		for sx in [-1.0, 1.0]:
			var lx: float = sx * (SIDE - SC - 0.055)  # ulkoreuna viisteeseen asti
			part(parent, B.boxm(Vector3(0.13, 0.44, 0.02)), Vector3(lx, tail_y, BACK + 0.005), frame)
			part(parent, B.boxm(Vector3(0.11, 0.14, 0.03)), Vector3(lx, tail_y + 0.13, BACK + 0.01), red)
			part(parent, B.boxm(Vector3(0.11, 0.08, 0.03)), Vector3(lx, tail_y + 0.02, BACK + 0.01), amber)
			part(parent, B.boxm(Vector3(0.11, 0.06, 0.03)), Vector3(lx, tail_y - 0.06, BACK + 0.01), lamp(Color(0.95, 0.95, 0.92)))
			part(parent, B.boxm(Vector3(0.11, 0.09, 0.03)), Vector3(lx, tail_y - 0.15, BACK + 0.01), red)
			part(parent, B.boxm(Vector3(0.02, 0.4, 0.08)), Vector3(sx * (SIDE + 0.004), tail_y, BACK - SC - 0.04), red)  # kulman ympäri
			part(parent, B.boxm(Vector3(SC * 1.414 + 0.012, 0.4, 0.02)), Vector3(sx * (SIDE - SC / 2.0 + 0.004), tail_y, BACK - SC / 2.0 + 0.004),
				red, Vector3(0, sx * PI / 4.0, 0))  # korin pystyviisteessä
			part(parent, B.boxm(Vector3(0.012, ht_y - BUMP_Y - BUMP_H / 2.0 - 0.02, 0.012)), Vector3(sx * 0.62, (ht_y + BUMP_Y + BUMP_H / 2.0) / 2.0, BACK + 0.002), frame)  # luukun sauma
		part(parent, B.boxm(Vector3(0.62 * 2.0, 0.012, 0.012)), Vector3(0, BUMP_Y + BUMP_H / 2.0 + 0.012, BACK + 0.002), frame)
		part(parent, B.boxm(Vector3(0.4, 0.03, 0.03)), Vector3(0, 0.68, BACK + 0.012), bar)  # luukun kahva
	else:
		part(parent, B.boxm(Vector3(SIDE * 2.0 - 0.1, 0.26, 0.02)), Vector3(0, tail_y, BACK + 0.005), frame)
		for sx in [-1.0, 1.0]:
			part(parent, B.boxm(Vector3(0.44, 0.09, 0.03)), Vector3(sx * 0.6, tail_y + 0.07, BACK + 0.01), red)  # ulkoreuna viisteeseen asti
			part(parent, B.boxm(Vector3(0.44, 0.06, 0.03)), Vector3(sx * 0.6, tail_y, BACK + 0.01), amber)
			part(parent, B.boxm(Vector3(0.44, 0.07, 0.03)), Vector3(sx * 0.6, tail_y - 0.07, BACK + 0.01), red)
			part(parent, B.boxm(Vector3(0.12, 0.06, 0.032)), Vector3(sx * 0.42, tail_y - 0.07, BACK + 0.012), lamp(Color(0.95, 0.95, 0.92)))
			for k in 5:
				part(parent, B.boxm(Vector3(0.44, 0.004, 0.032)), Vector3(sx * 0.6, tail_y - 0.09 + k * 0.045, BACK + 0.012), frame)  # urat
			part(parent, B.boxm(Vector3(0.02, 0.22, 0.08)), Vector3(sx * (SIDE + 0.004), tail_y, BACK - SC - 0.04), red)  # kulman ympäri
			part(parent, B.boxm(Vector3(SC * 1.414 + 0.012, 0.22, 0.02)), Vector3(sx * (SIDE - SC / 2.0 + 0.004), tail_y, BACK - SC / 2.0 + 0.004),
				red, Vector3(0, sx * PI / 4.0, 0))  # korin pystyviisteessä
	# Isot mustat puskurit, pakoputki.
	for bz in [FRONT - 0.03, BACK + 0.03]:
		_bevel_box(parent, Vector3(SIDE * 2.0 + 0.06, BUMP_H, 0.16), Vector3(0, BUMP_Y, bz), 0.035, frame)
	part(parent, B.cyl(0.03, 0.03, 0.08, 8), Vector3(-0.45, 0.28, BACK + 0.08), bar, Vector3(PI / 2.0, 0, 0))
	_plate(parent, Vector3(0, BUMP_Y, FRONT - 0.115), false, plate)
	_plate(parent, Vector3(0, 0.82 if farmari else tail_y - 0.0, BACK + 0.02), true, plate)
	_merge_parts(parent, first, "volvo/" + color.to_html() + ("/farmari" if farmari else ""))
	var badge := Label3D.new()
	badge.text = "VOLVO"
	badge.font_size = 32
	badge.pixel_size = 0.0022
	badge.outline_size = 0
	badge.modulate = Color(0.85, 0.86, 0.88)
	badge.double_sided = false
	badge.position = Vector3(-0.42, 0.7 if farmari else tail_y + 0.17, BACK + 0.012)
	parent.add_child(badge)
	var hub := _mat("ponyvanne", Color(0.78, 0.79, 0.8), 0.5, 0.35)
	var wheels: Array[Node3D] = []
	for sx in [-0.755, 0.755]:  # raide 1510 (esikuva 1430/1360): pyörä ulottuu kotelon mustan levyn ulkopuolelle
		for wz in [-WHEEL_Z, WHEEL_Z]:
			wheels.append(wheel(parent, Vector3(sx, WHEEL_R, wz), WHEEL_R, 0.185, 0, hub, 0.7, 10))
	return wheels


## Poliisin vilkkuvalon materiaali (palaa tai sammunut tumma), kerran luotu: vilkun vaihto ei luo materiaalia joka ruudulla.
static func vilkku_mat(palaa: bool) -> Material:
	var key := "vilkku_palaa" if palaa else "vilkku_pois"
	if not _mats.has(key):
		_mats[key] = B.unshaded(Color(0.2, 0.4, 1.0) if palaa else Color(0.05, 0.08, 0.2))
	return _mats[key]


## Poliisi-Saabin vilkkuvat valot vilkkupalkin kupujen päälle (SAAB_DOMES): palauttaa valot, joiden materiaalia
## vaihdetaan (police_car.gd, ratsia.gd). Hieman kupua suuremmat, ettei kupu näy läpi.
static func police_lights(parent: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for p: Vector3 in SAAB_DOMES:
		var l := MeshInstance3D.new()
		l.mesh = B.boxm(SAAB_DOME_SIZE + Vector3(0.02, 0.01, 0.01))
		l.material_override = vilkku_mat(true)
		l.position = p
		parent.add_child(l)
		out.append(l)
	return out


## Toyota HiAce H100 (1989–2004) -Z-suuntaan: 90-luvun pakettiauto, n. 1,69 × 1,93 × 4,60 m (korkea katto 2,20),
## akseliväli 2,56 m, renkaat 195R14C. Mitat ja muodot H100-blueprintista (getoutlines.com, 4 Gen H100 Short MWB High
## Roof 1989, sivukuva 130,9 px/m: pituus 602 px, akseliväli 340 px) ja leveys virallisesta 1690 mm:stä. Nokaton
## kori: moottori etuistuinten alla ja etupyörät ohjaamon ovien alla. Matala pysty keulapaneeli (tumma valopaneeli:
## suorakaiteiset ajovalot, vaakasäleikkö ja kulmavilkut kylkeen asti), sen yllä viisto pelti tuulilasin alareunaan,
## loiva tuulilasi, kyljet kallistuvat vyölinjasta kattoa kohti (edestä kapenee), iso tumma puskuri ilmanottoaukolla,
## isot mustat peilit. Umpikylkinen pakettiauto: ikkunat vain ohjaamossa, liukuovi oikeassa kyljessä (kisko
## takakyljessä), takana yläsaranallinen takaluukku ikkunoineen ja pystyt kulmatakavalot. Ohjaamossa sisusta lasien
## läpi (_cabin); ohjaamon takana umpinainen väliseinä. korkea = true: lasikuituinen korotettu katto (ambulanssi,
## kauppa-auto). Palauttaa pyörät kuten car().
const HIACE_KYLKI := 0.845  # alakorin kyljen x (leveys 1690 mm)
const HIACE_VYO := 1.20  # vyölinja: kyljet kallistuvat tästä ylöspäin
const HIACE_OLKA := 1.86  # kallistuvan kyljen yläpää (katon pyöristys alkaa)
const HIACE_OLKA_X := 0.73  # edestä: vyölinjalla 1,69 m, olalla 1,46 m (blueprintin etukuva)
const HIACE_KATTO := 1.93  # matalan katon yläpinta
const HIACE_KATTO_KORKEA := 2.20  # korotetun katon yläpinta
const HIACE_KEULA := -2.20  # keulapaneeli z (puskuri -2,30)
const HIACE_PERA := 2.28  # takaluukku z (puskuri 2,32)
const HIACE_WS := Vector2(-2.845, 0.7625)  # tuulilasin taso z = x + y * korkeus: alareuna (1,20; -1,93), loiva kuten esikuvassa


## Hiacen kyljen x korkeudella y (alakori pysty, vyölinjan yläpuolella kallistuu): kylkeen kiinnitettävät kuviot.
static func hiace_kylki(y: float) -> float:
	return HIACE_KYLKI - (HIACE_KYLKI - HIACE_OLKA_X) * clampf((y - HIACE_VYO) / (HIACE_OLKA - HIACE_VYO), 0.0, 1.0)


## Pursotus Z-suunnassa: poikkileikkaus sec (x, y; kupera tai kovera monikulmio) etupinnasta z = zf.x + zf.y * y
## takapintaan z = zb.x + zb.y * y. Molemmat päädyt ovat tasoja (kalteva tuulilasi, viisto keula), kyljet suoria
## (Hiacen kallistuvat kyljet ja katon pyöristys ovat poikkileikkauksessa). Tasaiset normaalit kuten _bevel.
static func _loft(parent: Node3D, sec: PackedVector2Array, zf: Vector2, zb: Vector2, mat: Material) -> MeshInstance3D:
	var n := sec.size()
	var area := 0.0
	for i in n:
		area += sec[i].cross(sec[(i + 1) % n])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a := sec[i]
		var b := sec[(i + 1) % n]
		var e := (b - a).normalized()
		var o := Vector2(e.y, -e.x) if area > 0.0 else Vector2(-e.y, e.x)
		var a0 := Vector3(a.x, a.y, zf.x + zf.y * a.y)
		var b0 := Vector3(b.x, b.y, zf.x + zf.y * b.y)
		var a1 := Vector3(a.x, a.y, zb.x + zb.y * a.y)
		var b1 := Vector3(b.x, b.y, zb.x + zb.y * b.y)
		_tri(st, a0, b0, b1, Vector3(o.x, o.y, 0))
		_tri(st, a0, b1, a1, Vector3(o.x, o.y, 0))
	var idx := Geometry2D.triangulate_polygon(sec)
	for k in range(0, idx.size(), 3):
		var f: Array[Vector3] = []
		var r: Array[Vector3] = []
		for m in 3:
			var p := sec[idx[k + m]]
			f.append(Vector3(p.x, p.y, zf.x + zf.y * p.y))
			r.append(Vector3(p.x, p.y, zb.x + zb.y * p.y))
		_tri(st, f[0], f[1], f[2], Vector3(0, zf.y, -1).normalized())
		_tri(st, r[0], r[1], r[2], Vector3(0, -zb.y, 1).normalized())
	st.index()
	st.generate_tangents()
	return part(parent, st.commit(), Vector3.ZERO, mat)


## Ohut monikulmio (pisteet (z, y)) Hiacen kyljen pinnalla sx-puolella lift verran ulkona: kallistuvalla kyljellä
## kuvio kallistuu kyljen mukana (ikkunat, saumat ja kiskot vyölinjan yläpuolella). Näkyy vain ulospäin.
static func _hiace_skin(parent: Node3D, sx: float, pts: PackedVector2Array, lift: float, mat: Material) -> MeshInstance3D:
	var k := (HIACE_KYLKI - HIACE_OLKA_X) / (HIACE_OLKA - HIACE_VYO)
	var idx := Geometry2D.triangulate_polygon(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, idx.size(), 3):
		var t: Array[Vector3] = []
		var above := false
		for m in 3:
			var p := pts[idx[i + m]]
			t.append(Vector3(sx * (hiace_kylki(p.y) + lift), p.y, p.x))
			above = above or p.y > HIACE_VYO + 0.001
		var nrm := Vector3(sx, k if above else 0.0, 0).normalized()
		_tri(st, t[0], t[1], t[2], nrm)
	st.index()
	st.generate_tangents()
	return part(parent, st.commit(), Vector3.ZERO, mat)


## Tuulilasin tason z korkeudella y.
static func _hiace_ws(y: float) -> float:
	return HIACE_WS.x + HIACE_WS.y * y


## Kapea pystysauma tai -kuvio (z0…z1, y0…y1) Hiacen kyljessä: vyölinjan alla laatikko pystykylkeen, yläpuolella
## kallistuvan kyljen mukainen levy (_hiace_skin), jottei kuvio jää korin sisään tai irtoa kyljestä.
static func _hiace_strip(parent: Node3D, sx: float, z0: float, z1: float, y0: float, y1: float, lift: float, mat: Material) -> void:
	if y0 < HIACE_VYO:
		var yt := minf(y1, HIACE_VYO)
		part(parent, B.boxm(Vector3(0.01, yt - y0, z1 - z0)), Vector3(sx * (HIACE_KYLKI + lift - 0.003), (y0 + yt) / 2.0, (z0 + z1) / 2.0), mat)
	if y1 > HIACE_VYO:
		var yb := maxf(y0, HIACE_VYO)
		_hiace_skin(parent, sx, PackedVector2Array([Vector2(z0, yb), Vector2(z1, yb), Vector2(z1, y1), Vector2(z0, y1)]), lift, mat)


static func hiace(parent: Node3D, color: Color, plate := "", korkea := false) -> Array[Node3D]:
	const SIDE := HIACE_KYLKI
	const SILL := 0.33  # alakorin alareuna (nokaton: korkea maavara)
	const NOSE_Y := 0.98  # keulapaneelin yläreuna: viisto pelti nousee tästä tuulilasin alareunaan
	const BELT := HIACE_VYO
	const WT := 1.76  # ikkunoiden ja tuulilasin yläreuna
	const ROOF := HIACE_KATTO
	const FRONT := HIACE_KEULA
	const BACK := HIACE_PERA
	const BP := -0.76  # B-pilari = ohjaamon takaseinä z
	const SLIDE := 0.69  # liukuoven takareuna z
	const LAMP_Y := 0.885  # ajovalojen keskikorkeus
	const BUMP_Y := 0.55
	const WHEEL_R := 0.31  # 195R14C
	const WHEEL_Z := 1.28  # akseliväli 2560 mm (blueprint)
	const ARCH_R := WHEEL_R + 0.05
	const ARCH_Y := WHEEL_R
	const LIP_R := ARCH_R + 0.04
	var first := parent.get_child_count()
	var body := paint(color)
	var win := _mat("ponylasi", Color(0.22, 0.27, 0.32), 0.3, 0.05, 0.32)
	var frame := plastic()
	var bar := _mat("ponykromi", Color(0.86, 0.87, 0.89), 0.45, 0.3)
	var grey := _mat("hiaceharmaa", Color(0.24, 0.24, 0.25), 0.05, 0.7)  # puskurit ja valopaneeli (tummanharmaa muovi)
	var amber := lamp(Color(1.0, 0.42, 0.04))
	var red := lamp(Color(0.72, 0.02, 0.05))
	if plate == "":
		plate = "%s%s%s-%d" % [char(65 + randi() % 26), char(65 + randi() % 26), char(65 + randi() % 26), 100 + randi() % 900]
	var xw := hiace_kylki(WT)
	# Kori neljänä pursotuksena: alakori (pysty keula), viisto pelti tuulilasin alle, kallistuva kylkivyöhyke
	# ohjaamon takaa perään (ohjaamon kohdalla lasit) ja katto tuulilasista perään pyöristetyin kulmin.
	var c := 0.03
	_loft(parent, PackedVector2Array([Vector2(-SIDE + c, SILL), Vector2(SIDE - c, SILL), Vector2(SIDE, SILL + c), Vector2(SIDE, NOSE_Y),
		Vector2(-SIDE, NOSE_Y), Vector2(-SIDE, SILL + c)]), Vector2(FRONT, 0), Vector2(BACK, 0), body)
	var nb := (_hiace_ws(BELT) - FRONT) / (BELT - NOSE_Y)
	_loft(parent, PackedVector2Array([Vector2(-SIDE, NOSE_Y), Vector2(SIDE, NOSE_Y), Vector2(SIDE, BELT), Vector2(-SIDE, BELT)]),
		Vector2(FRONT - nb * NOSE_Y, nb), Vector2(BACK, 0), body)
	_loft(parent, PackedVector2Array([Vector2(-SIDE, BELT), Vector2(SIDE, BELT), Vector2(xw, WT), Vector2(-xw, WT)]),
		Vector2(BP, 0), Vector2(BACK, 0), body)
	var roof_sec := PackedVector2Array([Vector2(-xw, WT), Vector2(xw, WT), Vector2(HIACE_OLKA_X, HIACE_OLKA), Vector2(0.71, ROOF - 0.025),
		Vector2(0.67, ROOF), Vector2(-0.67, ROOF), Vector2(-0.71, ROOF - 0.025), Vector2(-HIACE_OLKA_X, HIACE_OLKA)])
	_loft(parent, roof_sec, HIACE_WS, Vector2(BACK, 0), body)
	if korkea:
		# Lasikuituinen korotettu katto: etuosa viettää taakse tuulilasin yläreunan takaa, takaosa pyöristyy luukun yllä.
		var hr := HIACE_KATTO_KORKEA
		_loft(parent, PackedVector2Array([Vector2(-0.68, ROOF - 0.01), Vector2(0.68, ROOF - 0.01), Vector2(0.65, hr - 0.08),
			Vector2(0.61, hr - 0.02), Vector2(0.55, hr), Vector2(-0.55, hr), Vector2(-0.61, hr - 0.02), Vector2(-0.65, hr - 0.08)]),
			Vector2(-1.30 - 1.357 * (ROOF - 0.01), 1.357), Vector2(2.26 + 0.714 * (ROOF - 0.01), -0.714), body)
		for sx in [-1.0, 1.0]:
			part(parent, B.boxm(Vector3(0.012, 0.012, 3.5)), Vector3(sx * 0.675, ROOF + 0.004, 0.45), frame)  # liimasauma
	# Ohjaamo: tuulilasi ja sivulasit kallistuvalla kyljellä, A-pilarit, sisusta (kojelauta, ratti, etupenkit).
	_cabin(parent, BELT, WT, _hiace_ws(BELT), _hiace_ws(WT), BP - 0.01, BP - 0.01, BELT, xw * 2.0, bar, -0.98, -0.72, BP + 0.02, 0.02)
	var wsec := PackedVector2Array([Vector2(-SIDE + 0.07, BELT + 0.01), Vector2(SIDE - 0.07, BELT + 0.01), Vector2(xw - 0.07, WT - 0.005),
		Vector2(-xw + 0.07, WT - 0.005)])
	_loft(parent, wsec, HIACE_WS - Vector2(0.012, 0), HIACE_WS, win)  # tuulilasi
	for sx in [-1.0, 1.0]:
		var ax0: float = sx * SIDE
		var ax1: float = sx * xw
		var ap := PackedVector2Array([Vector2(ax0 - sx * 0.075, BELT), Vector2(ax0, BELT), Vector2(ax1, WT), Vector2(ax1 - sx * 0.075, WT)])
		_loft(parent, ap, HIACE_WS - Vector2(0.005, 0), HIACE_WS + Vector2(0.09, 0), body)  # A-pilari
		_loft(parent, PackedVector2Array([Vector2(ax0 - sx * 0.075, BELT), Vector2(ax0 - sx * 0.065, BELT), Vector2(ax1 - sx * 0.065, WT),
			Vector2(ax1 - sx * 0.075, WT)]), HIACE_WS - Vector2(0.008, 0), HIACE_WS + Vector2(0.01, 0), frame)  # lasin kumilista
		var wz0: float = _hiace_ws(BELT) + 0.09
		var wz1: float = _hiace_ws(WT) + 0.09
		_hiace_skin(parent, sx, PackedVector2Array([Vector2(wz0, BELT), Vector2(BP, BELT), Vector2(BP, WT), Vector2(wz1, WT)]), -0.004, win)
		# Ikkunan musta kehys: yläreuna, alareuna (vyölista) ja B-pilari.
		_hiace_skin(parent, sx, PackedVector2Array([Vector2(wz1 - 0.01, WT - 0.025), Vector2(BP, WT - 0.025), Vector2(BP, WT), Vector2(wz1 - 0.01, WT)]), 0.002, frame)
		_hiace_skin(parent, sx, PackedVector2Array([Vector2(wz0 - 0.02, BELT - 0.004), Vector2(BP, BELT - 0.004), Vector2(BP, BELT + 0.02), Vector2(wz0 - 0.02, BELT + 0.02)]), 0.002, frame)
		_hiace_skin(parent, sx, PackedVector2Array([Vector2(BP - 0.07, BELT), Vector2(BP + 0.005, BELT), Vector2(BP + 0.005, WT), Vector2(BP - 0.07, WT)]), 0.002, frame)
		# Kattokouru olan yläpuolella tuulilasista perään.
		var gz0: float = _hiace_ws(HIACE_OLKA) + 0.03
		part(parent, B.boxm(Vector3(0.025, 0.02, BACK - 0.03 - gz0)), Vector3(sx * (HIACE_OLKA_X + 0.005), HIACE_OLKA + 0.012, (gz0 + BACK - 0.03) / 2.0), frame)
		# Isot mustat peilit varressa ohjaamon oven etukulmassa.
		var mz := _hiace_ws(1.35) + 0.16
		var arm_x: float = hiace_kylki(1.33) - 0.01
		part(parent, B.boxm(Vector3(0.9 - arm_x, 0.03, 0.03)), Vector3(sx * (arm_x + 0.9) / 2.0, 1.33, mz + 0.02), frame)  # varsi
		_bevel_box(parent, Vector3(0.11, 0.17, 0.06), Vector3(sx * 0.935, 1.36, mz + 0.03), 0.015, frame)
		part(parent, B.boxm(Vector3(0.09, 0.15, 0.01)), Vector3(sx * 0.935, 1.36, mz + 0.062), glass())
		# Pyyhkimet tuulilasin alareunassa.
		var wp := part(parent, B.boxm(Vector3(0.6, 0.015, 0.02)), Vector3(sx * 0.33 - 0.08, BELT + 0.04, _hiace_ws(BELT + 0.04) - 0.02), frame)
		wp.rotation.z = 0.12 * sx
	# Kyljet: ohjaamon ovien saumat ja kahvat, liukuovi oikealla (+X), vaakasauma (esikuvan kylkiviiva), pyöränkaaret.
	for sx in [-1.0, 1.0]:
		var sz: float = sx * (SIDE + 0.003)
		var dz0: float = FRONT + 0.36
		part(parent, B.boxm(Vector3(0.01, BELT - SILL - 0.08, 0.012)), Vector3(sz, (SILL + BELT) / 2.0 + 0.02, dz0), frame)
		part(parent, B.boxm(Vector3(0.01, BELT - SILL - 0.08, 0.012)), Vector3(sz, (SILL + BELT) / 2.0 + 0.02, BP), frame)
		part(parent, B.boxm(Vector3(0.03, 0.035, 0.15)), Vector3(sx * (SIDE + 0.012), 1.12, BP - 0.2), frame)  # kahva
		part(parent, B.boxm(Vector3(0.01, 0.008, BACK - FRONT - 0.1)), Vector3(sz, 0.905, (FRONT + BACK) / 2.0), frame)  # kylkiviiva
		part(parent, B.boxm(Vector3(0.02, 0.05, 0.22)), Vector3(sx * (SIDE + 0.004), LAMP_Y, FRONT + 0.14), amber)  # kulmavilkku kyljessä
		for wz in [-WHEEL_Z, WHEEL_Z]:
			_wheel_arch(parent, sx, SIDE, SILL, wz, ARCH_R, ARCH_Y, LIP_R, frame, body)
	_hiace_strip(parent, 1.0, BP + 0.03, BP + 0.042, SILL + 0.06, WT - 0.03, 0.003, frame)  # liukuoven etusauma
	_hiace_strip(parent, 1.0, SLIDE - 0.006, SLIDE + 0.006, SILL + 0.06, WT - 0.03, 0.003, frame)  # takasauma
	_hiace_strip(parent, 1.0, BP + 0.03, SLIDE + 0.006, WT - 0.042, WT - 0.03, 0.003, frame)  # yläsauma
	part(parent, B.boxm(Vector3(0.015, 0.03, BACK - 0.12 - SLIDE)), Vector3(SIDE + 0.007, 1.0, (SLIDE + BACK - 0.12) / 2.0), frame)  # kisko
	part(parent, B.boxm(Vector3(0.03, 0.12, 0.035)), Vector3(SIDE + 0.012, 1.0, BP + 0.1), frame)  # liukuoven kahva
	part(parent, B.cyl(0.06, 0.06, 0.012, 20), Vector3(-SIDE - 0.004, 1.0, 1.85), frame, Vector3(0, 0, PI / 2.0))  # tankkiluukku
	part(parent, B.cyl(0.054, 0.054, 0.014, 20), Vector3(-SIDE - 0.005, 1.0, 1.85), body, Vector3(0, 0, PI / 2.0))
	# Alusta pyörien välissä: korkean korin alta ei näy läpi.
	part(parent, B.boxm(Vector3(1.3, 0.14, BACK - FRONT - 0.5)), Vector3(0, SILL - 0.06, (FRONT + BACK) / 2.0), frame)
	# Keula: tummanharmaa valopaneeli (ajovalot, vaakasäleikkö, kulmavilkut), iso puskuri ilmanottoaukkoineen.
	var fz := FRONT - 0.005
	var lens := _mat("ponylinssi", Color(0.62, 0.65, 0.68), 0.3, 0.15)
	part(parent, B.boxm(Vector3(SIDE * 2.0 - 0.02, NOSE_Y - 0.79, 0.02)), Vector3(0, (NOSE_Y + 0.79) / 2.0, fz), grey)
	for k in 3:
		part(parent, B.boxm(Vector3(0.84, 0.012, 0.025)), Vector3(0, LAMP_Y - 0.045 + k * 0.045, fz - 0.008), frame)
	for k in 6:
		part(parent, B.boxm(Vector3(0.012, 0.11, 0.025)), Vector3(-0.35 + k * 0.14, LAMP_Y, fz - 0.009), frame)
	part(parent, B.boxm(Vector3(0.1, 0.035, 0.02)), Vector3(0, LAMP_Y + 0.0, fz - 0.016), bar)  # merkki
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.25, 0.15, 0.02)), Vector3(sx * 0.615, LAMP_Y, fz - 0.006), frame)
		part(parent, B.boxm(Vector3(0.23, 0.13, 0.02)), Vector3(sx * 0.615, LAMP_Y, fz - 0.01), _mat("ponyvalo", Color(0.74, 0.76, 0.75), 0.2, 0.1))
		part(parent, B.cyl(0.045, 0.045, 0.02, 16), Vector3(sx * 0.6, LAMP_Y + 0.005, fz - 0.013), lamp(Color(1.0, 0.98, 0.9)), Vector3(PI / 2.0, 0, 0))
		for k in 3:
			part(parent, B.boxm(Vector3(0.23, 0.004, 0.02)), Vector3(sx * 0.615, LAMP_Y - 0.035 + k * 0.035, fz - 0.014), lens)
		part(parent, B.boxm(Vector3(0.05, 0.1, 0.02)), Vector3(sx * (SIDE - 0.035), LAMP_Y, fz - 0.008), amber)
	_bevel_box(parent, Vector3(SIDE * 2.0 + 0.03, 0.44, 0.1), Vector3(0, BUMP_Y, FRONT - 0.05), 0.03, grey)
	part(parent, B.boxm(Vector3(0.84, 0.13, 0.02)), Vector3(0, 0.55, FRONT - 0.096), frame)  # ilmanottoaukko
	for k in 2:
		part(parent, B.boxm(Vector3(0.82, 0.014, 0.02)), Vector3(0, 0.53 + k * 0.04, FRONT - 0.1), grey)
	for sx in [-1.0, 1.0]:
		_bevel_box(parent, Vector3(0.05, 0.4, 0.42), Vector3(sx * (SIDE - 0.01), BUMP_Y, FRONT + 0.17), 0.02, grey)  # puskurin kulma
	_plate(parent, Vector3(0, 0.4, FRONT - 0.11), false, plate)
	# Perä: takaluukku saumoineen ja ikkunoineen, pystyt kulmatakavalot kylkeen asti, porraspuskuri, kilpi valojen välissä.
	var bz := BACK + 0.004
	var gate_top := ROOF - 0.05
	part(parent, B.boxm(Vector3(1.28, 0.44, 0.012)), Vector3(0, 1.53, bz), frame)
	part(parent, B.boxm(Vector3(1.22, 0.39, 0.012)), Vector3(0, 1.53, bz + 0.002), glass())  # takaikkuna (tavaratila pimeä)
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.012, gate_top - 0.6, 0.01)), Vector3(sx * 0.71, (gate_top + 0.6) / 2.0, bz), frame)
		var lx: float = sx * (SIDE - 0.065)
		part(parent, B.boxm(Vector3(0.13, 0.4, 0.02)), Vector3(lx, 0.9, bz), frame)
		part(parent, B.boxm(Vector3(0.11, 0.13, 0.03)), Vector3(lx, 1.025, bz + 0.004), red)
		part(parent, B.boxm(Vector3(0.11, 0.09, 0.03)), Vector3(lx, 0.91, bz + 0.004), amber)
		part(parent, B.boxm(Vector3(0.11, 0.05, 0.03)), Vector3(lx, 0.84, bz + 0.004), lamp(Color(0.95, 0.95, 0.92)))
		part(parent, B.boxm(Vector3(0.11, 0.08, 0.03)), Vector3(lx, 0.765, bz + 0.004), red)
		part(parent, B.boxm(Vector3(0.02, 0.38, 0.06)), Vector3(sx * (SIDE + 0.004), 0.9, BACK - 0.025), red)  # kiertää kylkeen
	part(parent, B.boxm(Vector3(1.43, 0.012, 0.01)), Vector3(0, gate_top, bz), frame)
	part(parent, B.boxm(Vector3(1.43, 0.012, 0.01)), Vector3(0, 0.6, bz), frame)
	part(parent, B.boxm(Vector3(0.16, 0.035, 0.03)), Vector3(0, 1.24, bz + 0.01), bar)  # luukun kahva
	var rw := part(parent, B.boxm(Vector3(0.4, 0.015, 0.02)), Vector3(0.05, 1.4, bz + 0.012), frame)  # takapyyhkijä
	rw.rotation.z = 0.5
	_bevel_box(parent, Vector3(SIDE * 2.0 + 0.02, 0.2, 0.12), Vector3(0, 0.44, BACK + 0.04), 0.03, grey)
	part(parent, B.boxm(Vector3(0.7, 0.012, 0.1)), Vector3(0, 0.546, BACK + 0.04), frame)  # porras
	part(parent, B.cyl(0.03, 0.03, 0.12, 8), Vector3(0.55, 0.27, BACK - 0.02), bar, Vector3(PI / 2.0, 0, 0))  # pakoputki
	_plate(parent, Vector3(0, 0.8, BACK + 0.012), true, plate)
	_merge_parts(parent, first, "hiace/" + color.to_html() + ("/korkea" if korkea else ""))
	var hub := _mat("hiacevanne", Color(0.74, 0.75, 0.76), 0.5, 0.4)
	var wheels: Array[Node3D] = []
	for sx in [-1.0, 1.0]:  # raide 1520: rengas kotelon mustan levyn tasalla kuten muissa malleissa
		for wz in [-WHEEL_Z, WHEEL_Z]:
			wheels.append(wheel(parent, Vector3(sx * (SIDE - 0.085), WHEEL_R, wz), WHEEL_R, 0.19, 0, hub, 0.6, 8))
	return wheels


## Pakettiauto: Toyota HiAce H100 (hiace). korkea = korotettu katto (ambulanssi, kauppa-auto).
static func van(parent: Node3D, color: Color, plate := "", korkea := false) -> Array[Node3D]:
	return hiace(parent, color, plate, korkea)


## Taksin väri: beige/kerma (norsunluu, Mercedes-taksien perinteinen sävy).
const TAKSI_VARI := Color(0.94, 0.86, 0.66)


## Mercedes-Benz W123 (1976–85) -Z-suuntaan: 4-ovinen sedan n. 1,79 × 1,44 × 4,72 m, akseliväli 2,795 m, renkaat
## 175SR14. Mitat W123-blueprintista (getoutlines.com, sivukuva 105,5 px/m akselivälistä) ja virallisista mitoista
## (4725 × 1786 × 1438). Suomalainen klassikkotaksi (#283). Korkea kromisäleikkö pystysäleineen ja tähtineen,
## tähti konepellin kärjessä, isot suorakaiteiset ajovalot ja oranssit vilkut ulkoreunoissa, pitkä matala konepelti,
## suuret ikkunat kromilistoin, leveä musta kylkilista kromireunoin, kromipuskurit mustalla kumilla, kulmien
## vaakaurilliset takavalot ja kilpi välissä. taksi = true: katolla keltainen valaistu TAXI-kupu.
## Palauttaa pyörät kuten car().
static func mercedes(parent: Node3D, color: Color, plate := "", taksi := false) -> Array[Node3D]:
	const SIDE := 0.87  # kyljen x: listoineen leveys 1786 mm
	const SILL := 0.22
	const NOSE_LO := 0.5  # pystyn keulapinnan alareuna (puskuri peittää)
	const NOSE_Y := 0.88  # konepellin etureuna (säleikön yläreuna)
	const BELT := 0.92  # vyötärölinja
	const ROOF := 1.44  # katon yläpinta (1438 mm)
	const ROOF_T := 0.05
	const FRONT := -2.14  # keulapinta z
	const BACK := 2.44  # peräpaneeli z
	const WS0 := -0.85  # tuulilasin alareuna z
	const WS1 := -0.36  # tuulilasin yläreuna z
	const HT0 := 1.21  # takalasin yläreuna z
	const HT1 := 1.64  # takalasin alareuna z
	const HT_Y := 1.0
	const TAIL_TOP := 0.93
	const BP := 0.26  # B-pilari z
	const QA := 1.12  # takaoven ikkunan takareuna ylhäällä z
	const QB := 1.18  # ... vyölinjalla z
	const GLASS_W := 1.48
	const LAMP_Y := 0.73
	const TAIL_Y := 0.76
	const BUMP_Y := 0.52
	const WHEEL_R := 0.321  # 175SR14
	const WHEEL_Z := 1.3975  # akseliväli 2795 mm
	const ARCH_R := WHEEL_R + 0.045
	const ARCH_Y := ARCH_R
	const LIP_R := ARCH_R + 0.04
	const SC := 0.03
	const CF := 0.035
	const ROOF_C := 0.024
	var first := parent.get_child_count()
	var body := paint(color)
	var win := _mat("ponylasi", Color(0.22, 0.27, 0.32), 0.3, 0.05, 0.32)
	var frame := plastic()
	var bar := _mat("ponykromi", Color(0.86, 0.87, 0.89), 0.45, 0.3)
	var amber := lamp(Color(1.0, 0.42, 0.04))
	var red := lamp(Color(0.72, 0.02, 0.05))
	if plate == "":
		plate = "%s%s%s-%d" % [char(65 + randi() % 26), char(65 + randi() % 26), char(65 + randi() % 26), 100 + randi() % 900]
	var top := ROOF - ROOF_T
	var roof_x := GLASS_W / 2.0 + 0.03
	_bevel(parent, PackedVector2Array([Vector2(FRONT, SILL + CF), Vector2(FRONT + CF, SILL), Vector2(BACK - CF, SILL),
		Vector2(BACK, SILL + CF), Vector2(BACK, TAIL_TOP - CF), Vector2(BACK - CF, TAIL_TOP), Vector2(HT1 - 0.04, HT_Y),
		Vector2(HT1 - 0.04, BELT), Vector2(WS0, BELT), Vector2(FRONT + CF, NOSE_Y), Vector2(FRONT, NOSE_Y - CF)]), SIDE, SC, body)
	var hood_y := func(z: float) -> float: return lerpf(NOSE_Y, BELT, (z - FRONT) / (WS0 - FRONT))
	var deck_y := func(z: float) -> float: return lerpf(HT_Y, TAIL_TOP, (z - HT1 + 0.04) / (BACK - CF - HT1 + 0.04))
	var wf0 := Vector3(0, BELT, WS0)
	var wf1 := Vector3(0, top, WS1)
	var wr0 := Vector3(0, top, HT0)
	var wr1 := Vector3(0, HT_Y, HT1)
	var hat := (wr1 - wr0).normalized()
	for sx in [-1.0, 1.0]:
		_side_panel(parent, sx * GLASS_W / 2.0, [Vector2(WS0, BELT), Vector2(WS1, top), Vector2(QA, top), Vector2(QB, BELT)], win)
	_cabin(parent, BELT, top, WS0, WS1, HT0, HT1, HT_Y, GLASS_W, bar, 0.2, 1.08, 1.4, 0.45, ISTUIMET.mercedes.ratti)
	slab(parent, wf0, wf1, GLASS_W + 0.02, 0.04, win)
	slab(parent, wr0, wr1, GLASS_W + 0.02, 0.04, win)
	_bevel_box(parent, Vector3((roof_x + ROOF_C) * 2.0, ROOF_T, HT0 - WS1 + 0.04), Vector3(0, ROOF - ROOF_T / 2.0, (WS1 + HT0) / 2.0), ROOF_C, body)
	# Kumilistat, kromiset sadevesilistat pilarien välissä, tavaratilan kannen saumat, pyyhkimet ja ilmanottoritilä.
	slab(parent, wr0, wr0.lerp(wr1, 0.05), GLASS_W, 0.05, frame)
	slab(parent, wr0.lerp(wr1, 0.95), wr1, GLASS_W, 0.05, frame)
	slab(parent, wf0.lerp(wf1, 0.95), wf1 + (wf1 - wf0).normalized() * 0.01, GLASS_W + 0.02, 0.05, frame)
	part(parent, B.boxm(Vector3(GLASS_W - 0.06, 0.004, 0.012)), Vector3(0, deck_y.call(HT1 + 0.04) + 0.003, HT1 + 0.04), frame)
	part(parent, B.boxm(Vector3(GLASS_W - 0.1, 0.012, 0.07)), Vector3(0, hood_y.call(WS0 - 0.07) + 0.006, WS0 - 0.07), frame)
	for sx in [-1.0, 1.0]:
		var lx: float = sx * (GLASS_W / 2.0 - 0.02)
		slab(parent, Vector3(lx, deck_y.call(HT1 + 0.04) + 0.003, HT1 + 0.04), Vector3(lx, deck_y.call(BACK - 0.05) + 0.003, BACK - 0.05), 0.012, 0.004, frame)
		var rz0 := WS1 + 0.015
		var rz1 := HT0 - 0.04
		part(parent, B.boxm(Vector3(0.025, 0.035, rz1 - rz0)), Vector3(sx * (roof_x - 0.0125), top + 0.005, (rz0 + rz1) / 2.0), bar)
		var wp := part(parent, B.boxm(Vector3(0.55, 0.015, 0.02)), wf0.lerp(wf1, 0.08) + Vector3(sx * 0.3 - 0.06, 0.03, 0), frame)
		wp.rotation.z = 0.08 * sx
	var lip_z: float = sqrt(LIP_R * LIP_R - pow(0.62 - ARCH_Y, 2.0))
	for sx in [-1.0, 1.0]:
		var fx: float = sx * (GLASS_W / 2.0 + 0.016)
		var ax: float = sx * (roof_x - 0.035)
		slab(parent, wf0 + Vector3(ax, 0, 0), wf1 + Vector3(ax, 0, 0) + (wf1 - wf0).normalized() * 0.02, 0.07, 0.06, body)  # A-pilari
		var ex: float = sx * (roof_x - 0.05)
		slab(parent, wr0 + Vector3(ex, 0, 0) - hat * 0.03, wr1 + Vector3(ex, 0, 0), 0.1, 0.06, body)  # C-pilarin takareuna
		_side_panel(parent, sx * (GLASS_W / 2.0 + 0.012), [Vector2(QA, top), Vector2(HT0, top), Vector2(HT1, HT_Y), Vector2(HT1, BELT), Vector2(QB, BELT)], body)
		# Kromiset ikkunalistat, musta B-pilari.
		part(parent, B.boxm(Vector3(0.02, 0.025, QA - WS1)), Vector3(fx, top - 0.0125, (WS1 + QA) / 2.0), bar)
		part(parent, B.boxm(Vector3(0.02, 0.025, QB - WS0)), Vector3(fx, BELT + 0.0125, (WS0 + QB) / 2.0), bar)
		slab(parent, Vector3(fx, top, QA), Vector3(fx, BELT, QB), 0.02, 0.025, bar)
		part(parent, B.boxm(Vector3(0.05, top - BELT, 0.08)), Vector3(fx, (BELT + top) / 2.0, BP), frame)
		slab(parent, wf0 + Vector3(fx, 0, 0.01), wf1 + Vector3(fx, 0, 0.01), 0.02, 0.025, bar)  # A-pilarin kromilista
		# Kylki: ovisaumat, kromikahvat, kromipeili, leveä musta kylkilista kromireunoin, kromihelma, pyöränkaaret.
		var sz: float = sx * (SIDE + 0.003)
		for dz in [WS0 + 0.08, BP + 0.05, WHEEL_Z - LIP_R - 0.03]:
			part(parent, B.boxm(Vector3(0.01, BELT - SILL - SC * 2.0 - 0.04, 0.012)), Vector3(sz, (SILL + BELT) / 2.0, dz), frame)
		for hz in [BP - 0.12, QB - 0.2]:
			part(parent, B.boxm(Vector3(0.03, 0.035, 0.15)), Vector3(sx * (SIDE + 0.012), 0.84, hz), bar)
		part(parent, B.boxm(Vector3(0.1, 0.09, 0.14)), Vector3(sx * (SIDE + 0.05), BELT + 0.08, WS0 + 0.12), bar)  # peili
		part(parent, B.boxm(Vector3(0.02, 0.07, 0.11)), Vector3(sx * (SIDE + 0.1), BELT + 0.08, WS0 + 0.12), glass())
		for seg in [[FRONT + 0.06, -WHEEL_Z - lip_z - 0.02], [-WHEEL_Z + lip_z + 0.02, WHEEL_Z - lip_z - 0.02], [WHEEL_Z + lip_z + 0.02, BACK - 0.06]]:
			var za: float = seg[0]
			var zb: float = seg[1]
			_bevel_box(parent, Vector3(0.03, 0.09, zb - za), Vector3(sx * (SIDE + 0.01), 0.62, (za + zb) / 2.0), 0.012, frame)
			part(parent, B.boxm(Vector3(0.01, 0.01, zb - za - 0.03)), Vector3(sx * (SIDE + 0.026), 0.665, (za + zb) / 2.0), bar)
			part(parent, B.boxm(Vector3(0.01, 0.01, zb - za - 0.03)), Vector3(sx * (SIDE + 0.026), 0.575, (za + zb) / 2.0), bar)
		part(parent, B.boxm(Vector3(0.015, 0.03, 2.0 * (WHEEL_Z - LIP_R) - 0.06)), Vector3(sx * (SIDE + 0.006), SILL + 0.05, 0), bar)  # helmalista
		part(parent, B.boxm(Vector3(0.02, 0.05, 0.1)), Vector3(sx * (SIDE + 0.004), LAMP_Y, FRONT + SC + 0.05), amber)  # sivuvilkku
		for wz in [-WHEEL_Z, WHEEL_Z]:
			_wheel_arch(parent, sx, SIDE, SILL, wz, ARCH_R, ARCH_Y, LIP_R, frame, body)
	part(parent, B.cyl(0.06, 0.06, 0.012, 20), Vector3(SIDE + 0.004, 0.8, 1.95), frame, Vector3(0, 0, PI / 2.0))  # tankkiluukku
	part(parent, B.cyl(0.054, 0.054, 0.014, 20), Vector3(SIDE + 0.005, 0.8, 1.95), body, Vector3(0, 0, PI / 2.0))
	# Keula: korkea kromisäleikkö pystysäleineen ja tähtineen, tähti konepellin kärjessä, isot ajovalot ja vilkut.
	var fz: float = FRONT - 0.01
	var lens := _mat("ponylinssi", Color(0.62, 0.65, 0.68), 0.3, 0.15)
	part(parent, B.boxm(Vector3(0.4, 0.34, 0.04)), Vector3(0, LAMP_Y + 0.0, fz - 0.01), bar)  # säleikön kehys
	part(parent, B.boxm(Vector3(0.34, 0.28, 0.04)), Vector3(0, LAMP_Y, fz - 0.013), frame)
	for k in 9:
		part(parent, B.boxm(Vector3(0.012, 0.28, 0.04)), Vector3(-0.16 + k * 0.04, LAMP_Y, fz - 0.016), bar)
	part(parent, B.boxm(Vector3(0.34, 0.03, 0.04)), Vector3(0, LAMP_Y + 0.04, fz - 0.018), bar)  # vaakapalkki
	part(parent, B.cyl(0.05, 0.05, 0.02, 24), Vector3(0, LAMP_Y + 0.04, fz - 0.035), bar, Vector3(PI / 2.0, 0, 0))  # tähti säleikössä
	part(parent, B.cyl(0.04, 0.04, 0.022, 24), Vector3(0, LAMP_Y + 0.04, fz - 0.036), frame, Vector3(PI / 2.0, 0, 0))
	for k in 3:
		var sp := part(parent, B.boxm(Vector3(0.008, 0.04, 0.024)), Vector3(0, LAMP_Y + 0.04, fz - 0.037), bar)
		sp.rotation.z = TAU * k / 3.0
		sp.position += Vector3(-sin(TAU * k / 3.0), cos(TAU * k / 3.0), 0) * 0.02
	var hs := Vector3(0, NOSE_Y + 0.04, FRONT + 0.06)  # seisova tähti konepellin kärjessä
	part(parent, B.cyl(0.006, 0.006, 0.04, 6), hs - Vector3(0, 0.02, 0), bar)
	part(parent, B.cyl(0.025, 0.025, 0.006, 20), hs + Vector3(0, 0.025, 0), bar, Vector3(PI / 2.0, 0, 0))
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.44, 0.22, 0.02)), Vector3(sx * 0.45, LAMP_Y, fz), frame)
		part(parent, B.boxm(Vector3(0.3, 0.2, 0.02)), Vector3(sx * 0.39, LAMP_Y, fz - 0.005), _mat("ponyvalo", Color(0.74, 0.76, 0.75), 0.2, 0.1))
		part(parent, B.cyl(0.07, 0.07, 0.02, 20), Vector3(sx * 0.37, LAMP_Y + 0.02, fz - 0.008), lens, Vector3(PI / 2.0, 0, 0))
		part(parent, B.cyl(0.035, 0.035, 0.02, 16), Vector3(sx * 0.37, LAMP_Y + 0.02, fz - 0.011), lamp(Color(1.0, 0.98, 0.9)), Vector3(PI / 2.0, 0, 0))
		for k in 4:
			part(parent, B.boxm(Vector3(0.3, 0.004, 0.02)), Vector3(sx * 0.39, LAMP_Y - 0.075 + k * 0.05, fz - 0.012), lens)
		part(parent, B.boxm(Vector3(0.12, 0.2, 0.02)), Vector3(sx * 0.6, LAMP_Y, fz - 0.005), amber)
		part(parent, B.boxm(Vector3(0.45, 0.012, 0.025)), Vector3(sx * 0.45, LAMP_Y + 0.115, fz - 0.002), bar)  # valojen kromireunus
	# Perä: kulmien vaakaurilliset takavalot (punainen, oranssi, valkoinen, punainen) ja kilpi välissä kromilistan alla.
	part(parent, B.boxm(Vector3(SIDE * 2.0 - 0.1, 0.012, 0.02)), Vector3(0, TAIL_Y + 0.14, BACK + 0.005), bar)
	for sx in [-1.0, 1.0]:
		var lx: float = sx * 0.57
		part(parent, B.boxm(Vector3(0.5, 0.24, 0.02)), Vector3(lx, TAIL_Y, BACK + 0.005), frame)
		part(parent, B.boxm(Vector3(0.48, 0.06, 0.03)), Vector3(lx, TAIL_Y + 0.085, BACK + 0.01), red)
		part(parent, B.boxm(Vector3(0.48, 0.05, 0.03)), Vector3(lx, TAIL_Y + 0.03, BACK + 0.01), amber)
		part(parent, B.boxm(Vector3(0.48, 0.05, 0.03)), Vector3(lx, TAIL_Y - 0.025, BACK + 0.01), lamp(Color(0.95, 0.95, 0.92)))
		part(parent, B.boxm(Vector3(0.48, 0.06, 0.03)), Vector3(lx, TAIL_Y - 0.083, BACK + 0.01), red)
		for k in 6:
			part(parent, B.boxm(Vector3(0.48, 0.004, 0.032)), Vector3(lx, TAIL_Y - 0.1 + k * 0.04, BACK + 0.012), frame)
		part(parent, B.boxm(Vector3(0.02, 0.22, 0.08)), Vector3(sx * (SIDE + 0.004), TAIL_Y, BACK - SC - 0.04), red)
		part(parent, B.boxm(Vector3(SC * 1.414 + 0.012, 0.22, 0.02)), Vector3(sx * (SIDE - SC / 2.0 + 0.004), TAIL_Y, BACK - SC / 2.0 + 0.004),
			red, Vector3(0, sx * PI / 4.0, 0))
	# Kromipuskurit mustalla kumilla, kulmat kiertävät kylkeen.
	for bz in [FRONT - 0.035, BACK + 0.035]:
		_bevel_box(parent, Vector3(SIDE * 2.0 + 0.04, 0.1, 0.07), Vector3(0, BUMP_Y, bz), 0.02, bar)
		part(parent, B.boxm(Vector3(SIDE * 2.0, 0.05, 0.075)), Vector3(0, BUMP_Y, bz), frame)
		part(parent, B.boxm(Vector3(SIDE * 2.0 - 0.1, 0.12, 0.05)), Vector3(0, BUMP_Y - 0.11, bz - signf(bz) * 0.03), frame)  # helma
		for sx in [-1.0, 1.0]:
			var zc: float = bz - signf(bz) * 0.15
			_bevel_box(parent, Vector3(0.05, 0.1, 0.3), Vector3(sx * (SIDE + 0.005), BUMP_Y, zc), 0.015, bar)
			part(parent, B.boxm(Vector3(0.055, 0.05, 0.3)), Vector3(sx * (SIDE + 0.005), BUMP_Y, zc), frame)
	part(parent, B.cyl(0.03, 0.03, 0.08, 8), Vector3(0.5, 0.3, BACK + 0.05), bar, Vector3(PI / 2.0, 0, 0))
	_plate(parent, Vector3(0, BUMP_Y - 0.0, FRONT - 0.08), false, plate)
	_plate(parent, Vector3(0, TAIL_Y - 0.0, BACK + 0.02), true, plate)
	if taksi:
		# Keltainen valaistu TAXI-kupu katon keskellä jaloillaan.
		part(parent, B.boxm(Vector3(0.36, 0.03, 0.14)), Vector3(0, ROOF + 0.015, 0.3), frame)
		_bevel_box(parent, Vector3(0.5, 0.17, 0.2), Vector3(0, ROOF + 0.115, 0.3), 0.03, lamp(Color(1.0, 0.82, 0.15)))
	_merge_parts(parent, first, "mercedes/" + color.to_html() + ("/taksi" if taksi else ""))
	if taksi:
		for side in [1.0, -1.0]:
			var l := Label3D.new()
			l.text = "TAXI"
			l.font_size = 48
			l.pixel_size = 0.0024
			l.modulate = Color(0.08, 0.06, 0.02)
			l.outline_size = 0
			l.double_sided = false
			l.rotation.y = 0.0 if side > 0.0 else PI
			l.position = Vector3(0, ROOF + 0.115, 0.3 + side * 0.101)
			parent.add_child(l)
	var hub := _mat("ponyvanne", Color(0.78, 0.79, 0.8), 0.5, 0.35)
	var wheels: Array[Node3D] = []
	for sx in [-0.79, 0.79]:  # raide 1580 (esikuva 1488/1446): pyörä ulottuu kotelon mustan levyn ulkopuolelle
		for wz in [-WHEEL_Z, WHEEL_Z]:
			wheels.append(wheel(parent, Vector3(sx, WHEEL_R, wz), WHEEL_R, 0.175, 0, hub, 0.66, 12))
	return wheels


## Taksi: kermanvärinen Mercedes-Benz W123 keltaisella TAXI-kuvulla (mercedes, TAKSI_VARI). Palauttaa pyörät kuten car().
static func taxi(parent: Node3D, plate := "") -> Array[Node3D]:
	return mercedes(parent, TAKSI_VARI, plate, true)


## Rekka -Z-suuntaan: eurooppalainen nokaton veturi ja umpikoripuoliperävaunu (n. 2,55 × 4,0 × 16 m),
## kyljissä RAAHEN KULJETUS -kyltti. Palauttaa pyörät kuten car().
static func truck(parent: Node3D, color: Color, text := "RAAHEN KULJETUS") -> Array[Node3D]:
	var first := parent.get_child_count()
	var cab := paint(color)
	var white := paint(Color(0.93, 0.93, 0.91))
	var dark := plastic()
	# Alusta ja runko.
	part(parent, B.boxm(Vector3(1.0, 0.3, 15.6)), Vector3(0, 0.75, 0.2), dark)
	# Ohjaamo: kori, tuulilasi, katon spoileri, aurinkolippa ja sivuikkunat.
	part(parent, B.boxm(Vector3(2.5, 2.3, 2.3)), Vector3(0, 2.15, -6.75), cab)
	part(parent, B.boxm(Vector3(2.44, 0.5, 2.0)), Vector3(0, 3.55, -6.6), cab)  # makuuhytin korotus
	slab(parent, Vector3(0, 3.8, -6.2), Vector3(0, 3.95, -5.6), 2.4, 0.06, cab)  # spoileri
	part(parent, B.boxm(Vector3(2.2, 1.0, 0.04)), Vector3(0, 2.75, -7.91), glass())  # tuulilasi
	part(parent, B.boxm(Vector3(2.42, 0.16, 0.28)), Vector3(0, 3.33, -7.98), cab)  # aurinkolippa
	part(parent, B.boxm(Vector3(2.52, 0.08, 0.06)), Vector3(0, 2.22, -7.92), chrome())  # tuulilasin alalista
	# Keula: säleikkö kromisäleillä, ajovalot, puskuri ja kilpi.
	part(parent, B.boxm(Vector3(1.6, 0.8, 0.05)), Vector3(0, 1.6, -7.92), dark)
	for k in 5:
		part(parent, B.boxm(Vector3(1.56, 0.05, 0.06)), Vector3(0, 1.3 + k * 0.15, -7.94), chrome())
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.42, 0.2, 0.06)), Vector3(sx * 0.98, 1.2, -7.93), lamp(Color(1.0, 0.98, 0.9)))
		part(parent, B.boxm(Vector3(0.14, 0.12, 0.06)), Vector3(sx * 1.2, 1.42, -7.93), lamp(Color(1.0, 0.5, 0.1)))
		# Sivuikkuna, peilit varsineen, astinlauta ja ovisauma.
		part(parent, B.boxm(Vector3(0.03, 0.8, 1.2)), Vector3(sx * 1.25, 2.7, -7.1), glass())
		part(parent, B.boxm(Vector3(0.08, 0.06, 0.5)), Vector3(sx * 1.4, 2.95, -7.75), dark, Vector3(0, sx * 0.5, 0))
		part(parent, B.boxm(Vector3(0.12, 0.55, 0.22)), Vector3(sx * 1.62, 2.7, -7.6), dark)
		part(parent, B.boxm(Vector3(0.02, 0.45, 0.16)), Vector3(sx * 1.685, 2.7, -7.6), glass())
		part(parent, B.boxm(Vector3(0.3, 0.06, 0.6)), Vector3(sx * 1.22, 0.75, -6.9), chrome())
		part(parent, B.boxm(Vector3(0.012, 1.7, 0.012)), Vector3(sx * 1.256, 2.1, -6.0), dark)
		part(parent, B.cyl(0.3, 0.3, 1.1, 14), Vector3(sx * 0.85, 0.95, -4.6), chrome(), Vector3(PI / 2.0, 0, 0))  # polttoainetankki
		# Lokasuojat ja roiskeläpät.
		for wz in [-6.55, -4.05, 4.6, 5.9]:
			part(parent, B.boxm(Vector3(0.62, 0.06, 1.3)), Vector3(sx * 0.98, 1.22, wz), dark)
		part(parent, B.boxm(Vector3(0.5, 0.55, 0.03)), Vector3(sx * 0.98, 0.65, 6.65), dark)
	part(parent, B.boxm(Vector3(2.56, 0.4, 0.2)), Vector3(0, 0.82, -7.95), dark)  # puskuri
	_plate(parent, Vector3(0, 0.9, -8.07), false, "RAH-1870")
	# Pakoputki ohjaamon takana.
	part(parent, B.cyl(0.07, 0.07, 1.4, 8), Vector3(1.05, 3.4, -5.5), chrome())
	# Perävaunu: valkoinen kori, alareunan lista, takaovien saumat ja valot.
	part(parent, B.boxm(Vector3(2.55, 2.9, 12.4)), Vector3(0, 2.6, 0.55), white)
	part(parent, B.boxm(Vector3(2.57, 0.18, 12.42)), Vector3(0, 1.18, 0.55), cab)
	part(parent, B.boxm(Vector3(2.57, 0.08, 12.42)), Vector3(0, 4.02, 0.55), dark)
	part(parent, B.boxm(Vector3(0.012, 2.7, 0.02)), Vector3(0, 2.6, 6.76), dark)
	for sx in [-1.0, 1.0]:
		part(parent, B.boxm(Vector3(0.012, 2.7, 0.02)), Vector3(sx * 1.2, 2.6, 6.76), chrome())
		part(parent, B.boxm(Vector3(0.3, 0.14, 0.05)), Vector3(sx * 1.05, 1.05, 6.77), lamp(Color(0.8, 0.04, 0.03)))
	_plate(parent, Vector3(0, 1.05, 6.8), true, "RAH-1870")
	_merge_parts(parent, first, "truck/" + color.to_html())
	# Kylkien kyltit (eivät yhdisty: tekstit).
	for sx in [-1.0, 1.0]:
		var sp := B.sign_plate(parent, text, color, Color.WHITE, 1.3, 120, Color.WHITE, "Helvetica Neue")
		sp.position = Vector3(sx * 1.29, 2.7, 0.55)
		sp.rotation.y = PI / 2.0 if sx > 0.0 else -PI / 2.0
	var wheels: Array[Node3D] = []
	for sx in [-0.98, 0.98]:
		for wz in [-6.55, -4.05, 4.6, 5.9]:
			wheels.append(wheel(parent, Vector3(sx, 0.52, wz), 0.52, 0.34, 0, chrome(), 0.55))
	return wheels


## Traktori -Z-suuntaan. style "modern" (Valtra-tyylinen lasiohjaamo) tai "old" (pieni vanha, ei ohjaamoa).
## Palauttaa {"rear": [pyörät], "front": [pyörät]}.
static func tractor(parent: Node3D, color: Color, style := "modern") -> Dictionary:
	var body := paint(color)
	var dark := plastic()
	var steel := _mat("steel", Color(0.3, 0.3, 0.32), 0.6, 0.45)
	var rim := paint(Color(0.85, 0.85, 0.82)) if style == "modern" else paint(Color(0.2, 0.2, 0.2))
	var old := style == "old"
	var k := 0.75 if old else 1.0  # vanha on pienempi
	# Runko ja moottori.
	part(parent, B.boxm(Vector3(0.7 * k, 0.45 * k, 2.8 * k)), Vector3(0, 0.75 * k, -0.2 * k), steel)
	part(parent, B.boxm(Vector3(0.95 * k, 0.8 * k, 2.0 * k)), Vector3(0, 1.3 * k, -1.0 * k), body)  # konepelti
	slab(parent, Vector3(0, 1.7 * k, -2.0 * k), Vector3(0, 1.72 * k, -0.2 * k), 0.95 * k, 0.06, body)
	# Maski: säleikkö ja valot.
	part(parent, B.boxm(Vector3(0.85 * k, 0.6 * k, 0.05)), Vector3(0, 1.28 * k, -2.02 * k), dark)
	for i in 6:
		part(parent, B.boxm(Vector3(0.8 * k, 0.03, 0.06)), Vector3(0, 1.02 * k + i * 0.1 * k, -2.04 * k), steel)
	for sx in [-0.32, 0.32]:
		part(parent, B.boxm(Vector3(0.14 * k, 0.1 * k, 0.05)), Vector3(sx * k, 1.62 * k, -2.03 * k), lamp(Color(1, 0.98, 0.9)))
	# Konepellin sivujen ilmanotot.
	for sx in [-1.0, 1.0]:
		for i in 5:
			part(parent, B.boxm(Vector3(0.02, 0.04, 0.5 * k)), Vector3(sx * 0.48 * k, 1.2 * k + i * 0.08 * k, -1.2 * k), dark)
	# Pakoputki ja imuputki.
	part(parent, B.cyl(0.06, 0.06, 1.3 * k, 10), Vector3(0.3 * k, 2.2 * k, -0.45 * k), steel)
	part(parent, B.cyl(0.075, 0.06, 0.12, 10), Vector3(0.3 * k, 2.88 * k, -0.45 * k), dark)
	if not old:
		part(parent, B.cyl(0.07, 0.07, 1.0, 10), Vector3(-0.3, 2.1, -0.45), dark)
		# Etupainot ja etunostolaite.
		for i in 6:
			part(parent, B.boxm(Vector3(0.8, 0.14, 0.2)), Vector3(0, 0.65 + i * 0.15, -2.35), dark)
		part(parent, B.boxm(Vector3(1.0, 0.1, 0.25)), Vector3(0, 0.55, -2.3), steel)
	# Ohjaamo.
	if old:
		part(parent, B.boxm(Vector3(0.45, 0.1, 0.4)), Vector3(0, 1.3, 0.55), dark)  # istuin
		part(parent, B.cyl(0.18, 0.18, 0.03, 16), Vector3(0, 1.55, 0.1), dark, Vector3(-0.8, 0, 0))  # ratti
	else:
		var cz := 0.75
		part(parent, B.boxm(Vector3(1.55, 0.12, 1.55)), Vector3(0, 1.1, cz), steel)  # lattia
		part(parent, B.boxm(Vector3(1.5, 1.5, 1.5)), Vector3(0, 1.95, cz), cab_glass())
		for sx in [-0.76, 0.76]:
			for sz in [-0.74, 0.74]:
				part(parent, B.boxm(Vector3(0.07, 1.55, 0.07)), Vector3(sx, 1.95, cz + sz), dark)
			part(parent, B.boxm(Vector3(0.05, 0.05, 1.5)), Vector3(sx, 2.72, cz), dark)
			part(parent, B.boxm(Vector3(0.05, 0.05, 1.5)), Vector3(sx, 1.2, cz), dark)
			# Peilit varsineen.
			part(parent, B.boxm(Vector3(0.4, 0.03, 0.03)), Vector3(sx * 1.2, 2.45, cz - 0.7), dark)
			part(parent, B.boxm(Vector3(0.03, 0.3, 0.18)), Vector3(sx * 1.45, 2.35, cz - 0.7), dark)
		part(parent, B.boxm(Vector3(1.7, 0.14, 1.75)), Vector3(0, 2.8, cz), body)  # katto
		part(parent, B.boxm(Vector3(1.72, 0.04, 1.77)), Vector3(0, 2.72, cz), paint(Color(0.92, 0.92, 0.9)))
		for sx in [-0.6, 0.6]:
			part(parent, B.boxm(Vector3(0.16, 0.08, 0.06)), Vector3(sx, 2.8, cz - 0.9), lamp(Color(1, 0.98, 0.9)))
		part(parent, B.cyl(0.08, 0.1, 0.16, 12), Vector3(0.55, 2.95, cz + 0.6), lamp(Color(1.0, 0.55, 0.05)))  # majakka
		part(parent, B.boxm(Vector3(0.5, 0.12, 0.45)), Vector3(0, 1.45, cz + 0.2), dark)
		part(parent, B.cyl(0.18, 0.18, 0.03, 16), Vector3(0, 1.85, cz - 0.4), dark, Vector3(-0.9, 0, 0))
		# Astinlaudat.
		for i in 3:
			part(parent, B.boxm(Vector3(0.3, 0.03, 0.25)), Vector3(-0.85, 0.5 + i * 0.25, cz - 0.3), steel)
	# Takanostolaite.
	for sx in [-0.3, 0.3]:
		slab(parent, Vector3(sx * k, 0.8 * k, 1.1 * k), Vector3(sx * k, 0.55 * k, 1.8 * k), 0.07, 0.07, steel)
	part(parent, B.cyl(0.04, 0.04, 0.2, 8), Vector3(0, 0.75 * k, 1.25 * k), steel, Vector3(PI / 2.0, 0, 0))
	# Pyörät ja lokasuojat.
	var rr := 0.82 * k
	var fr := 0.5 * k
	var rear: Array[Node3D] = []
	var front: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		rear.append(wheel(parent, Vector3(sx * 0.98 * k, rr, 0.75 * k), rr, 0.55 * k, 22, rim, 0.55))
		front.append(wheel(parent, Vector3(sx * 0.8 * k, fr, -1.6 * k), fr, 0.36 * k, 16, rim, 0.55))
		# Takalokasuoja: katto + viistot päät.
		var fx: float = sx * 0.98 * k
		part(parent, B.boxm(Vector3(0.62 * k, 0.05, 0.9 * k)), Vector3(fx, rr * 2.0 + 0.08, 0.75 * k), body)
		slab(parent, Vector3(fx, rr * 2.0 + 0.08, 0.3 * k), Vector3(fx, rr * 1.35, -0.25 * k), 0.62 * k, 0.05, body)
		slab(parent, Vector3(fx, rr * 2.0 + 0.08, 1.2 * k), Vector3(fx, rr * 1.35, 1.72 * k), 0.62 * k, 0.05, body)
		part(parent, B.boxm(Vector3(0.1, 0.1, 0.12)), Vector3(fx, rr * 1.6, 1.75 * k), lamp(Color(0.8, 0.05, 0.03)))
		if not old:
			part(parent, B.boxm(Vector3(0.42, 0.04, 0.6)), Vector3(sx * 0.8, fr * 2.0 + 0.1, -1.6), body)  # etulokasuoja
	part(parent, B.boxm(Vector3(1.5 * k, 0.12, 0.14)), Vector3(0, fr, -1.6 * k), steel)  # etuakseli
	return {"rear": rear, "front": front}
