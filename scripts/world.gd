extends Node3D
## Rakentaa Saloisten maiseman map_data.gd:n pohjalta: maasto, tiet, metsät, talot,
## vesistöt, koti (Järvikuja 1) ja K-Market. Tarjoaa tieverkon vaimon partiointiin.

const B := preload("res://scripts/build.gd")
const M := preload("res://scripts/map_data.gd")
const Foliage := preload("res://scripts/foliage.gd")
const T := preload("res://scripts/terrain.gd")
const Kota := preload("res://scripts/kota.gd")
const Looks := preload("res://scripts/looks.gd")
const DroneGame := preload("res://scripts/drone_game.gd")
const DRAPE_EDGE := 3.0  # maakerrosten kolmioiden maksimisivu, jotta ne myötäilevät maastoa
## Lehvästökorttien näkyvyysraja: tätä kauempana puut piirretään kevyinä perusmuotoina.
const TREE_NEAR := 210.0

const STYLES := {
	"highway": {"w": 12.0, "surf": "asphalt", "dash": true, "edge": "shoulder"},
	"road": {"w": 8.0, "surf": "asphalt", "dash": true, "edge": "shoulder"},
	"street": {"w": 5.5, "surf": "street", "dash": false, "edge": ""},
	"path": {"w": 3.0, "surf": "gravel", "dash": false, "edge": ""},
}
## Maanpintojen värit shaderille: [väri a, väri b, karkea skaala, hieno skaala, kuoppaisuus, karheus, rivit].
const SURFACES := {
	"meadow": [Color(0.32, 0.46, 0.18), Color(0.46, 0.58, 0.25), 0.02, 0.35, 0.5, 0.95, 0.0],
	"forest": [Color(0.28, 0.32, 0.17), Color(0.5, 0.48, 0.32), 0.03, 0.6, 0.7, 0.95, 0.0],
	"clearcut": [Color(0.36, 0.3, 0.2), Color(0.55, 0.47, 0.32), 0.04, 0.9, 0.9, 1.0, 0.0],
	"field": [Color(0.5, 0.45, 0.26), Color(0.7, 0.63, 0.36), 0.02, 0.4, 0.5, 0.95, 2.2],
	"bog": [Color(0.38, 0.36, 0.2), Color(0.56, 0.5, 0.3), 0.04, 0.5, 0.6, 0.9, 0.0],
	"lawn": [Color(0.28, 0.52, 0.2), Color(0.4, 0.64, 0.27), 0.05, 0.6, 0.3, 0.95, 0.7],
	"asphalt": [Color(0.17, 0.17, 0.18), Color(0.27, 0.27, 0.28), 0.05, 2.5, 0.25, 0.8, 0.0],
	"street": [Color(0.24, 0.24, 0.25), Color(0.33, 0.33, 0.33), 0.05, 2.5, 0.25, 0.85, 0.0],
	"gravel": [Color(0.53, 0.47, 0.37), Color(0.64, 0.57, 0.45), 0.08, 1.1, 0.6, 1.0, 0.0],
	"shoulder": [Color(0.47, 0.46, 0.42), Color(0.56, 0.55, 0.5), 0.08, 1.1, 0.6, 1.0, 0.0],
}
## Alustat: nopeuskatto, kiihtyvyys, lisävastus, töyssyisyys, ohjattavuus, uppoaminen, nimi HUDiin.
const TERRAIN := {
	"asphalt": {"speed": 1.0, "accel": 1.0, "drag": 0.0, "bump": 0.0, "steer": 1.0, "sink": 0.0, "name": "Asfaltti"},
	"gravel": {"speed": 0.85, "accel": 0.85, "drag": 0.6, "bump": 0.025, "steer": 0.9, "sink": 0.0, "name": "Sora"},
	"lawn": {"speed": 0.78, "accel": 0.8, "drag": 1.0, "bump": 0.02, "steer": 0.9, "sink": 0.0, "name": "Nurmikko"},
	"meadow": {"speed": 0.6, "accel": 0.6, "drag": 2.0, "bump": 0.05, "steer": 0.85, "sink": 0.02, "name": "Niitty"},
	"forest": {"speed": 0.5, "accel": 0.5, "drag": 2.5, "bump": 0.09, "steer": 0.8, "sink": 0.02, "name": "Metsä"},
	"field": {"speed": 0.4, "accel": 0.45, "drag": 3.5, "bump": 0.04, "steer": 0.7, "sink": 0.04, "name": "Viljapelto"},
	"bog": {"speed": 0.3, "accel": 0.35, "drag": 5.0, "bump": 0.03, "steer": 0.6, "sink": 0.12, "name": "Räme"},
	"water": {"speed": 0.15, "accel": 0.2, "drag": 8.0, "bump": 0.02, "steer": 0.5, "sink": 0.3, "name": "Vesi"},
}
## Sama alusta hidastaa eri tavalla: auto kärsii pehmeästä maasta eniten, jalankulkija vähiten.
const TERRAIN_BY := {
	"car": {"asphalt": 1.0, "gravel": 0.9, "lawn": 0.75, "meadow": 0.7, "forest": 0.5, "field": 0.45, "bog": 0.2, "water": 0.1},
	"runner": {"asphalt": 1.0, "gravel": 1.0, "lawn": 1.0, "meadow": 0.9, "forest": 0.8, "field": 0.6, "bog": 0.5, "water": 0.4},
}
## Pintojen korkeudet selvin välein, ettei päällekkäisiä pintoja piirretä samaan tasoon (välkyntä):
## polku < piennar < kaupan piha < katu < maantie < valtatie < keskiviivat.
## Porrastus muutama millimetri: pinnat pysyvät maan tasossa (pyörä ei uppoa), mutta eivät välky.
## Maakerrosten korkeus maaston yläpuolella (kerrokset pilkotaan maastokolmioiden mukaan, _conform, joten maasto
## säilyy 2 m korkeusmallin muotoisena eikä pistä läpi).
const LAYER := {"path": 0.012, "shoulder": 0.017, "lot": 0.021, "street": 0.025, "road": 0.029, "highway": 0.033, "dash": 0.037}
const CELL := 40.0
const CHUNK := 150.0
const MASK_PX := 2.0  # metriä per maskin pikseli
const JARVIKUJA_HALF := 3.0  # Järvikujan puolileveys naapuripihojen mitoitukseen
const WALLS := [Color(0.6, 0.15, 0.11), Color(0.9, 0.8, 0.45), Color(0.88, 0.78, 0.44), Color(0.86, 0.8, 0.66),
	Color(0.84, 0.77, 0.62), Color(0.93, 0.93, 0.9),
	Color(0.92, 0.91, 0.87), Color(0.58, 0.6, 0.61), Color(0.58, 0.7, 0.78), Color(0.45, 0.3, 0.2),
	Color(0.75, 0.82, 0.7)]
## Matalat peltikatot: enimmäkseen tummanharmaita/mustia, osa punaruskeita (ilmakuvan mukaan).
const ROOFS := [Color(0.2, 0.21, 0.22), Color(0.2, 0.21, 0.22), Color(0.12, 0.12, 0.13), Color(0.3, 0.31, 0.33),
	Color(0.4, 0.14, 0.1), Color(0.3, 0.2, 0.15)]
const DOORS := [Color(0.35, 0.22, 0.14), Color(0.15, 0.25, 0.4), Color(0.5, 0.1, 0.08), Color(0.9, 0.9, 0.88)]
const WHITE := Color(0.95, 0.95, 0.92)

var graph_nodes: Array[Vector3] = []
var graph_adj: Array = []
var graph_fast: Array = []  # solmu maantiellä ("road"): liikenne ajaa kovempaa kuin asuinkaduilla
## Pyöräilyverkko (tiet, kadut ja polut, ei valtatietä): pyörävaras ajaa sitä pitkin (main.gd _thief_tick).
var ride := AStar3D.new()
var neighbor_yards := {}  # "arto" / "pekka" / "sinikka" -> pihan puuhapisteet (ensimmäinen = ulko-ovi)
var neighbor_faces := {}  # nimi -> suunta, johon puuhapisteessä katsotaan (valinnainen, sama järjestys)
var drone_pad_pos: Vector3  # droonin laskeutumisalusta kotipihan asfaltilla (ks. main.gd _drone_logic)
var home_zone: Vector3
var shop_zone: Vector3
var taxi_pos: Vector3  # K-Marketin taksitolpalla odottava taksi
var station_pos: Vector3  # Saloisten asema K-Marketin takana: oven edusta (E: junalla Vaalaan)
var station_arrive: Vector3  # junalla tultaessa tästä
## Sinikan takapihan nurmikko (tarinan "Sinikan nurmikko, ettei Päivi nää"): pivot, koko, kulma ja leikkurin paikka.
var sinikka_lawn := {}
var follow: Node3D  # ruoho seuraa tätä (pelaaja)

var _rng := RandomNumberGenerator.new()
var _seg_grid := {}
var _houses: Array[Vector2] = []
var _house_grid := {}  # Vector2i -> talojen pisteet (HOUSE_CELL-ruudut)
const HOUSE_CELL := 20.0
var _trees: Array = []  # [Vector2 pos, String kind, float scale, bool collide]
var _water: Array[PackedVector2Array] = []
var _forests: Array[PackedVector2Array] = []
var _fields: Array[PackedVector2Array] = []
var _bogs: Array[PackedVector2Array] = []
var _agility := PackedVector2Array()
var _clearings: Array[PackedVector2Array] = []
var _lots: Array[PackedVector2Array] = []  # asfalttikentät (kotipiha, kaupan parkkipaikka): ei puita
## Puun rungon vähimmäisetäisyys tien tai polun reunasta (kaikki puut, myös metsäreuna ja hakkuuaukeiden männyt).
const TREE_ROAD_GAP := 1.0
var fire: Node3D  # laavun nuotio (näkyy kun sytytetty)
var kota: Node3D  # Haapajärven tekoaltaan kota (kota.gd)
var waste_sign: Node3D  # Raahen kaupungin jätteentuontikielto kodan polulla (_waste_sign)
## Marja- ja sienipaikat: {pos: Vector3, kind: String, node: Node3D, taken: bool}. Arto paljastaa ne karttaan.
var forage: Array = []
var forage_revealed := false
const FORAGE_KINDS := {
	"puolukka": {"weight": 0.35, "liters": 2, "color": Color(0.8, 0.08, 0.1)},
	"mustikka": {"weight": 0.3, "liters": 2, "color": Color(0.15, 0.2, 0.55)},
	"kantarelli": {"weight": 0.2, "liters": 1, "color": Color(0.95, 0.65, 0.1)},
	"herkkutatti": {"weight": 0.15, "liters": 1, "color": Color(0.5, 0.3, 0.15)},
}
var _surf_mats := {}
var _batches := {}
var _play := PackedVector2Array()
var edge_bodies: Array[StaticBody3D] = []  # pelialueen reunaseinät (reunakommentit)
var _grass_mat: ShaderMaterial
var _lawn_st: SurfaceTool
var _clearcuts: Array[PackedVector2Array] = []
## Suorakaiteet, joilta ruoho poistetaan maskista: [keskipiste, puolileveys, puolisyvyys, kierto].
var _mask_clear: Array = []
## Rakennusten ja pihaesteiden pohjat [keskipiste, puolikoko (x, z), yaw] naapurien reitinhakuun (villager.gd).
var blockers: Array = []
var _hedge_batch := B.Batch.new()
var _hedge_cards := B.Batch.new()
var _hedge_quad: QuadMesh
## Kotipihan nurmikko (lawn.gd piirtää ruohon itse, joten yleinen ruoho ja puut pidetään poissa).
var lamp_spots: Array[Vector3] = []  # katuvalojen lamppujen paikat (main.gd sytyttää illalla)
var lamps: MultiMeshInstance3D
var garage_door := Vector3.ZERO  # autotallin nosturioven edusta (main.gd _garage_door_logic)
var garage_out := Vector3.FORWARD  # nosturiovelta ulospäin
var lawn_rect: Rect2  # nurmikko omassa kehyksessään (keskipiste origossa), ks. in_lawn
var lawn_pivot: Vector2
var lawn_angle := 0.0


## deferred: main.gd rakentaa maailman build()-korutiinilla latausruudun takana (ruutu päivittyy vaiheiden välissä).
var deferred := false


func _ready() -> void:
	_rng.seed = 1917
	_hedge_batch.lift = true
	_hedge_cards.lift = true
	home_zone = M.w(M.HOME_ZONE)
	shop_zone = M.w(M.SHOP_ZONE)
	lawn_pivot = M.w2(M.LAWN_CENTER)
	lawn_angle = M.LAWN_AXIS.angle()
	lawn_rect = Rect2(-M.LAWN_SIZE * M.SCALE / 2.0, M.LAWN_SIZE * M.SCALE)
	if not deferred:
		build(func(_text: String, _frac: float) -> void: pass)


## Maailman rakennus vaiheittain. step(teksti, osuus 0..1) kutsutaan ennen kutakin vaihetta ja odotetaan: latausruutu
## odottaa siinä ruudunpäivityksen, testiajossa (deferred = false) se palaa heti eikä rakennus keskeydy.
func build(step: Callable) -> void:
	await step.call("Luetaan karttaa", 0.01)
	for p in M.WATER:
		_water.append(_poly(p))
	for p in M.FORESTS:
		_forests.append(_poly(p))
	for p in M.FIELDS:
		_fields.append(_poly(p))
	for p in M.BOGS:
		_bogs.append(_poly(p))
	_agility = _poly(M.AGILITY)
	_play = _poly(M.PLAY_AREA)
	for p in M.CLEARINGS:
		_clearings.append(_poly(p))
	_index_segments()
	await step.call("Muotoillaan maastoa ja järviä", 0.03)
	_build_ground()
	await step.call("Asfaltoidaan teitä ja polkuja", 0.3)
	_build_roads()
	_build_graph()
	_build_ride_graph()
	for p in M.CLEARCUTS:
		_clearcuts.append(_poly(p))
	_lawn_st = _new_st()
	await step.call("Rakennetaan Järvikuja 1 ja naapurit", 0.49)
	_build_home()
	await step.call("Avataan K-Market", 0.5)
	_build_shop()
	_build_station()
	_build_agility()
	await step.call("Laavu, grillikatos ja kota", 0.53)
	_build_laavu()
	_build_grillikatos()
	_build_kota()
	_build_pontikka()
	_build_bales()
	await step.call("Rakennetaan Saloisten talot", 0.56)
	_build_houses()
	await step.call("Kylvetään nurmikot", 0.63)
	_commit_strip(_lawn_st, _surf("lawn"))
	_lawn_st = null
	await step.call("Pientareet, katuvalot ja sähkölinjat", 0.67)
	_build_verges()
	_build_streetlights()
	_build_power_lines()
	await step.call("Hakkuuaukeat", 0.73)
	_build_clearcuts()
	_commit_batches()
	await step.call("Istutetaan metsää", 0.75)
	_scatter_trees()
	var still := M.w2(M.PONTIKKA)
	var n0 := _trees.size()
	_trees = _trees.filter(func(t: Array) -> bool:
		return not in_lawn(t[0], 2.5) and t[0].distance_to(still) > 6.5 and _road_clearance(t[0]) >= TREE_ROAD_GAP \
			and not _in_any(t[0], _lots))
	if OS.get_cmdline_user_args().has("--puut"):
		print("PUUT kylässä %d, pois %d · pensasaitaa tien kohdalta pois %.1f m" % [_trees.size(), n0 - _trees.size(),
			hedges_cut * 0.25])
	await step.call("Puut kasvavat", 0.84)
	_build_trees()
	await step.call("Marjat ja sienet metsään", 0.86)
	_build_forage()
	await step.call("Ruoho kasvaa", 0.87)
	_build_grass()
	await step.call("Paikannimet ja viimeistely", 0.95)
	_build_names()
	_lift_objects()
	build_lamps()


var _near_trees: Array[GeometryInstance3D] = []
var _far_trees: Array[GeometryInstance3D] = []
var _grass_mm: MultiMesh


## Laatutaso 0–3: ruohon määrä ja lehvästöpuiden etäisyys.
func set_quality(q: int) -> void:
	if _grass_mm != null:
		_grass_mm.visible_instance_count = int(_grass_mm.instance_count * [0.2, 0.35, 0.7, 1.0][q])
	var near: float = [80.0, 110.0, 160.0, TREE_NEAR][q]
	for g in _near_trees:
		g.visibility_range_end = near
	for g in _far_trees:
		g.visibility_range_begin = near - 10.0


func _process(_delta: float) -> void:
	if follow != null and _grass_mat != null:
		_grass_mat.set_shader_parameter("center", follow.global_position)
	_process_fire()


# --- Apurit ------------------------------------------------------------------

func _poly(px: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in px:
		out.append(M.w2(p))
	return out


func _surf(kind: String) -> Material:
	if kind == "water":
		if not _surf_mats.has(kind):
			_surf_mats[kind] = B.shader_mat("res://shaders/water.gdshader")
		return _surf_mats[kind]
	if not _surf_mats.has(kind):
		var s: Array = SURFACES[kind]
		_surf_mats[kind] = B.shader_mat("res://shaders/ground.gdshader", {
			"color_a": s[0], "color_b": s[1], "scale": s[2], "fine_scale": s[3],
			"bump": s[4], "roughness_v": s[5], "stripes": s[6], "stripe_angle": 0.35,
		})
	return _surf_mats[kind]


## Litteä monikulmio maan pinnalle.
func _flat_poly(poly: PackedVector2Array, y: float, material: Material) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		return
	var st := _new_st()
	for i in idx:
		st.add_vertex(Vector3(poly[i].x, y, poly[i].y))
	_commit_strip(st, material)


## Nauha murtoviivaa pitkin, nivelet täytetään kiekoilla.
func _strip(st: SurfaceTool, pts: PackedVector2Array, half_w: float, y: float) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := (b - a).normalized().orthogonal() * half_w
		for v in [a + n, b + n, b - n, a + n, b - n, a - n]:
			st.add_vertex(Vector3(v.x, y, v.y))
	for p in pts:
		for k in 12:
			var a0 := TAU * k / 12.0
			var a1 := TAU * (k + 1) / 12.0
			st.add_vertex(Vector3(p.x, y, p.y))
			st.add_vertex(Vector3(p.x + cos(a0) * half_w, y, p.y + sin(a0) * half_w))
			st.add_vertex(Vector3(p.x + cos(a1) * half_w, y, p.y + sin(a1) * half_w))


func _commit_strip(st: SurfaceTool, material: Material) -> void:
	var src: PackedVector3Array = st.commit_to_arrays()[Mesh.ARRAY_VERTEX]
	if src.is_empty():
		return
	# Maakerros myötäilee maastoa: kolmiot pilkotaan maastoruudukon kolmioiden mukaan ja nostetaan maaston
	# korkeudelle, jolloin jokainen pala on täsmälleen maastokolmion tasossa (2 m mallin ojat eivät pistä läpi).
	var out := PackedVector3Array()
	var conform := T.available()
	for t in range(0, src.size() - 2, 3):
		if conform:
			_conform(src[t], src[t + 1], src[t + 2], out)
		else:
			_subdivide(src[t], src[t + 1], src[t + 2], out)
	var nrm := PackedVector3Array()
	nrm.resize(out.size())
	for i in out.size():
		var p := out[i]
		out[i] = Vector3(p.x, p.y + T.h(p.x, p.z), p.z)
		nrm[i] = T.grid_normal(p.x, p.z)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = out
	arr[Mesh.ARRAY_NORMAL] = nrm
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("draped", true)
	add_child(mi)


## Leikkaa kolmion maastoruudukon viivoilla (x-, z- ja lävistäjäviivat kuten Terrain.h:n kolmioinnissa), niin että
## jokainen pala on yhden maastokolmion sisällä, ja lisää palat viuhkoina.
func _conform(a: Vector3, b: Vector3, c: Vector3, out: PackedVector3Array) -> void:
	var polys: Array[PackedVector3Array] = [PackedVector3Array([a, b, c])]
	for fam in 3:
		var nxt: Array[PackedVector3Array] = []
		for poly in polys:
			_split_family(poly, fam, nxt)
		polys = nxt
	for poly in polys:
		for i in range(1, poly.size() - 1):
			out.append(poly[0])
			out.append(poly[i])
			out.append(poly[i + 1])


## Ruudukkokoordinaatti viivaperheelle: 0 = x, 1 = z, 2 = x + z (lävistäjät).
func _grid_f(p: Vector3, fam: int) -> float:
	var fx := (p.x - T.origin.x) / T.CELL
	var fz := (p.z - T.origin.y) / T.CELL
	return fx if fam == 0 else (fz if fam == 1 else fx + fz)


func _split_family(poly: PackedVector3Array, fam: int, out: Array[PackedVector3Array]) -> void:
	var lo := INF
	var hi := -INF
	for p in poly:
		var f := _grid_f(p, fam)
		lo = minf(lo, f)
		hi = maxf(hi, f)
	var rest := poly
	for k in range(floori(lo) + 1, ceili(hi)):
		var below := PackedVector3Array()
		var above := PackedVector3Array()
		for i in rest.size():
			var p := rest[i]
			var q := rest[(i + 1) % rest.size()]
			var fp := _grid_f(p, fam) - k
			var fq := _grid_f(q, fam) - k
			if fp <= 0.0:
				below.append(p)
			if fp >= 0.0:
				above.append(p)
			if (fp < 0.0 and fq > 0.0) or (fp > 0.0 and fq < 0.0):
				var x := p.lerp(q, fp / (fp - fq))
				below.append(x)
				above.append(x)
		if below.size() >= 3:
			out.append(below)
		rest = above
		if rest.size() < 3:
			return
	out.append(rest)


## Pilkkoo kolmion pisimmän sivun kohdalta, kunnes kaikki sivut ovat alle DRAPE_EDGE (ei maastoruudukkoa).
func _subdivide(a: Vector3, b: Vector3, c: Vector3, out: PackedVector3Array) -> void:
	var ab := a.distance_squared_to(b)
	var bc := b.distance_squared_to(c)
	var ca := c.distance_squared_to(a)
	var m := maxf(ab, maxf(bc, ca))
	if m <= DRAPE_EDGE * DRAPE_EDGE:
		out.append(a)
		out.append(b)
		out.append(c)
		return
	if m == ab:
		var d := (a + b) * 0.5
		_subdivide(a, d, c, out)
		_subdivide(d, b, c, out)
	elif m == bc:
		var d := (b + c) * 0.5
		_subdivide(a, b, d, out)
		_subdivide(a, d, c, out)
	else:
		var d := (c + a) * 0.5
		_subdivide(a, b, d, out)
		_subdivide(d, b, c, out)


## Maailman rakennuksen jälkeen: kaikki esineet (talot, puut, kyltit, pylväät...) maaston pinnalle.
## Maakerrokset ja yhdistetyt verkot on jo nostettu pisteittäin (merkitty "draped").
func _lift_objects() -> void:
	for c in get_children():
		_lift_node(c)


func _lift_node(c: Node) -> void:
	if c.has_meta("draped") or not (c is Node3D):
		return
	if c is MultiMeshInstance3D:
		var mmi := c as MultiMeshInstance3D
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var t := mm.get_instance_transform(i)
			var wp := mmi.transform * t.origin
			t.origin.y += T.h(wp.x, wp.z)
			mm.set_instance_transform(i, t)
		return
	var n := c as Node3D
	if n.position.length() < 0.5 and n.get_child_count() > 0 and not (n is VisualInstance3D):
		# Keräävä solmu origossa (esim. puiden törmäysmuodot): nostetaan lapset kukin omasta kohdastaan.
		for g in n.get_children():
			_lift_node(g)
	else:
		n.position.y += T.h(n.global_position.x, n.global_position.z)


func _new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	return st


func _index_segments() -> void:
	for r in M.ROADS:
		var pts := _poly(r.pts)
		var hw: float = STYLES[r.type].w / 2.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * (hw + 12.0)
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * (hw + 12.0)
			for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
				for cz in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
					var key := Vector2i(cx, cz)
					if not _seg_grid.has(key):
						_seg_grid[key] = []
					_seg_grid[key].append([a, b, hw, r.type])


## Etäisyys lähimmän tien reunaan (iso luku jos tietä ei ole lähellä).
func _road_clearance(p: Vector2) -> float:
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var best := 999.0
	for s in _seg_grid.get(key, []):
		var c := Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
		best = minf(best, p.distance_to(c) - s[2])
	return best


## Mikä alusta pisteessä on (ks. TERRAIN).
func surface_at(pos: Vector3) -> String:
	var p := Vector2(pos.x, pos.z)
	if _in_any(p, _water):
		return "water"
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var best := 999.0
	var best_type := ""
	for s in _seg_grid.get(key, []):
		var c := Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
		var d: float = p.distance_to(c) - s[2]
		if d < best:
			best = d
			best_type = s[3]
	if best <= 0.0:
		return "gravel" if best_type == "path" else "asphalt"
	if best <= 1.2 and best_type != "path":
		return "gravel"  # piennar
	if _near_stream(p):
		return "water"
	if p.distance_to(M.w2(M.LAAVU)) < 7.0:
		return "gravel"  # laavun kenttä
	if _in_rect(p, M.w2(M.SHOP_BUILDING) + Vector2(-18, 9), M.w2(M.SHOP_BUILDING) + Vector2(18, 31)):
		return "asphalt"  # kaupan parkkipaikka
	if Geometry2D.is_point_in_polygon(p, _agility) or in_lawn(p, 1.0):
		return "lawn"
	if _in_any(p, _fields):
		return "field"
	if _in_any(p, _bogs):
		return "bog"
	if _in_any(p, _forests):
		return "forest"
	return "meadow"


## Nopeuskerroin alustalle: "bike" käyttää TERRAIN-taulua, muut TERRAIN_BY-taulua.
func speed_factor(pos: Vector3, who: String) -> float:
	var kind := surface_at(pos)
	if who == "bike":
		return TERRAIN[kind].speed
	return TERRAIN_BY[who][kind]


func _near_stream(p: Vector2) -> bool:
	for s in M.STREAMS:
		var pts := _poly(s)
		for i in pts.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])) < 1.3:
				return true
	return false


func _in_rect(p: Vector2, a: Vector2, b: Vector2) -> bool:
	return p.x >= a.x and p.y >= a.y and p.x <= b.x and p.y <= b.y


func _in_any(p: Vector2, polys: Array[PackedVector2Array]) -> bool:
	for poly in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


## Onko maailman piste (x, z) kotipihan nurmikolla (margin m reunan yli).
func in_lawn(p: Vector2, margin := 0.0) -> bool:
	return lawn_rect.grow(margin).has_point((p - lawn_pivot).rotated(-lawn_angle))


## Vapaa paikka pylväälle tai kyltille: ei minkään tien tai polun päällä (reunasta vähintään clear m),
## ei talon vieressä eikä vedessä.
func _free_spot(p: Vector2, clear: float, house: float) -> bool:
	return _road_clearance(p) > clear and not _near_house(p, house) and not _in_any(p, _water)


## Talo (tai sen osa) listaan ja ruudukkoon: puut ja muut kohteet pysyvät kaukana.
func _add_house(c: Vector2) -> void:
	_houses.append(c)
	var key := Vector2i(floori(c.x / HOUSE_CELL), floori(c.y / HOUSE_CELL))
	if not _house_grid.has(key):
		_house_grid[key] = []
	_house_grid[key].append(c)


func _near_house(p: Vector2, dist: float) -> bool:
	var r := ceili(dist / HOUSE_CELL)
	var k0 := Vector2i(floori(p.x / HOUSE_CELL), floori(p.y / HOUSE_CELL))
	for cx in range(k0.x - r, k0.x + r + 1):
		for cz in range(k0.y - r, k0.y + r + 1):
			for h: Vector2 in _house_grid.get(Vector2i(cx, cz), []):
				if h.distance_squared_to(p) < dist * dist:
					return true
	return false


## Onko piste pelialueella (M.PLAY_AREA) vähintään margin metriä reunasta (negatiivinen = reunan ulkopuolella).
func _in_bounds(p: Vector2, margin: float) -> bool:
	var inside := Geometry2D.is_point_in_polygon(p, _play)
	var d := _play_edge_dist(p)
	return (inside and d > margin) if margin >= 0.0 else (inside or d < -margin)


func _play_edge_dist(p: Vector2) -> float:
	var best := INF
	for i in _play.size():
		var a := _play[i]
		var b := _play[(i + 1) % _play.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


func _batch_at(p: Vector2) -> B.Batch:
	var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
	if not _batches.has(key):
		_batches[key] = B.Batch.new()
		_batches[key].lift = true
	return _batches[key]


## Pensasaita (pituus paikallisella x-akselilla). Tien tai polun kohdalta aita katkaistaan: tien viereen se saa
## tulla, mutta ei tien päälle (HEDGE_ROAD_GAP reunasta).
const HEDGE_ROAD_GAP := 0.1
var hedges_cut := 0  # tien kohdalta pois leikattuja aidan pätkiä (testinäkymä aidat)
var hedge_cut_at: Array[Vector2] = []  # leikkauskohdat maailmassa (yksi per 20 m ruutu)


func _add_hedge(xf: Transform3D, center: Vector3, size: Vector3, col: Color) -> void:
	var step := 0.25
	var n := maxi(1, ceili(size.x / step))
	var dx := size.x / n
	var run_start := -1
	for i in n + 1:
		var ok := false
		if i < n:
			ok = true
			var lx := center.x - size.x / 2.0 + (i + 0.5) * dx
			for dz in [-size.z / 2.0, 0.0, size.z / 2.0]:
				var w: Vector3 = xf * Vector3(lx, 0.0, center.z + dz)
				if _road_clearance(Vector2(w.x, w.z)) < HEDGE_ROAD_GAP:
					ok = false
					break
			if not ok:
				hedges_cut += 1
				var cw: Vector3 = xf * Vector3(lx, 0.0, center.z)
				var c2 := Vector2(cw.x, cw.z)
				if not hedge_cut_at.any(func(q: Vector2) -> bool: return q.distance_to(c2) < 20.0):
					hedge_cut_at.append(c2)
		if ok and run_start < 0:
			run_start = i
		elif not ok and run_start >= 0:
			var len := (i - run_start) * dx
			if len >= 0.5:
				var mid := center.x - size.x / 2.0 + (run_start + i) * dx / 2.0
				_hedge_box(xf, Vector3(mid, center.y, center.z), Vector3(len, size.y, size.z), col)
			run_start = -1


## Pensasaita: lehtitekstuurinen runko + pinnalle hajautetut lehväkortit pörröiseksi siluetiksi.
func _hedge_box(xf: Transform3D, center: Vector3, size: Vector3, col: Color) -> void:
	_hedge_batch.add(B.boxm(size - Vector3(0.1, 0.1, 0.1)), xf * Transform3D(Basis(), center), col)
	if _hedge_quad == null:
		_hedge_quad = QuadMesh.new()
		_hedge_quad.size = Vector2(0.62, 0.62)
	var n := maxi(2, int(size.x / 0.28))
	for i in n:
		var x := -size.x / 2.0 + (i + _rng.randf()) * size.x / n
		# Päälle ja molemmille kyljille.
		for face in [Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			var p := center + Vector3(x, 0, 0)
			if face.y > 0.0:
				p += Vector3(0, size.y / 2.0 - 0.05, _rng.randf_range(-size.z / 2.0, size.z / 2.0) * 0.8)
			else:
				p += Vector3(0, _rng.randf_range(-size.y / 2.0, size.y / 2.0) * 0.85, face.z * (size.z / 2.0 - 0.05))
			var basis := Basis.looking_at(-face if face.y == 0.0 else Vector3(0, -1, 0.01).normalized(), Vector3.UP if face.y == 0.0 else Vector3.FORWARD)
			basis = basis.rotated(face, _rng.randf() * TAU)
			basis = basis.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
			_hedge_cards.add(_hedge_quad, xf * Transform3D(basis, p), col.lightened(_rng.randf_range(0.0, 0.2)))


func _commit_batches() -> void:
	if not _hedge_batch.is_empty():
		var hm := MeshInstance3D.new()
		hm.set_meta("draped", true)
		hm.mesh = _hedge_batch.commit()
		hm.material_override = B.shader_mat("res://shaders/hedge.gdshader", {"leaf_tex": Foliage.hedge_texture()})
		add_child(hm)
		var hc := MeshInstance3D.new()
		hc.set_meta("draped", true)
		hc.mesh = _hedge_cards.commit()
		hc.material_override = B.shader_mat("res://shaders/foliage_card.gdshader", {"leaf_tex": Foliage.leaf_texture(), "sway": 0.015})
		hc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hc)
		_hedge_batch = B.Batch.new()
		_hedge_cards = B.Batch.new()
		_hedge_batch.lift = true
		_hedge_cards.lift = true
	for key in _batches:
		var batch: B.Batch = _batches[key]
		if batch.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.set_meta("draped", true)
		mi.mesh = batch.commit()
		mi.material_override = B.vcol_mat()
		add_child(mi)
	_batches.clear()


# --- Maasto & tiet -----------------------------------------------------------

func _build_ground() -> void:
	var lo := M.w2(Vector2.ZERO)
	var hi := M.w2(M.SIZE)
	var c := (lo + hi) / 2.0
	var size := hi - lo
	if T.available():
		_build_terrain(lo, hi)
	else:
		var ground := B.box(self, Vector3(size.x + 600, 1, size.y + 600), Vector3(c.x, -0.5, c.y), Color.WHITE)
		(ground.get_child(1) as MeshInstance3D).material_override = _surf("meadow")
		ground.set_meta("draped", true)
		for poly in _forests:
			_flat_poly(poly, 0.002, _surf("forest"))
		for poly in _fields:
			_flat_poly(poly, 0.004, _surf("field"))
		for poly in _bogs:
			_flat_poly(poly, 0.0045, _surf("bog"))
	for poly in _water:
		_flat_poly(poly, 0.007, _surf("water"))
	var st := _new_st()
	for s in M.STREAMS:
		_strip(st, _poly(s), 1.2, 0.006)
	_commit_strip(st, _surf("water"))
	# Näkymättömät reunat pelialueen ympärillä (korkeat, jotta maaston korkeuserot eivät jätä rakoja).
	for i in _play.size():
		var a := _play[i]
		var b := _play[(i + 1) % _play.size()]
		var body := StaticBody3D.new()
		body.position = Vector3((a.x + b.x) / 2.0, 0, (a.y + b.y) / 2.0)
		body.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		body.add_child(B.box_shape(Vector3(a.distance_to(b) + 2.0, 400, 2)))
		body.set_meta("draped", true)
		body.set_meta("edge", true)
		add_child(body)
		edge_bodies.append(body)


## Korkeusmallin maastoverkko (5 m ruudut) laattoina pintakarttoineen + korkeuskenttä törmäyksiin.
## Laatat, jotka ovat kaukana pelialueen ulkopuolella, jätetään pois (niitä ei koskaan näe).
const TERRAIN_TILE := 40  # ruutua
func _build_terrain(lo: Vector2, hi: Vector2) -> void:
	var nx := T.nx
	var nz := T.nz
	var tiles: Array[ArrayMesh] = []
	for tj in range(0, nz - 1, TERRAIN_TILE):
		for ti in range(0, nx - 1, TERRAIN_TILE):
			var cw := mini(TERRAIN_TILE, nx - 1 - ti)
			var ch := mini(TERRAIN_TILE, nz - 1 - tj)
			var cen := T.origin + (Vector2(ti, tj) + Vector2(cw, ch) * 0.5) * T.CELL
			if not _in_bounds(cen, -(320.0 + TERRAIN_TILE * T.CELL * 0.71)):
				continue
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			for j in range(tj, tj + ch + 1):
				for i in range(ti, ti + cw + 1):
					var k := j * nx + i
					var x := T.origin.x + i * T.CELL
					var z := T.origin.y + j * T.CELL
					verts.append(Vector3(x, T.heights[k], z))
					norms.append(T.grid_normal(x, z))
			var idx := PackedInt32Array()
			var rw := cw + 1
			for j in ch:
				for i in cw:
					var a := j * rw + i
					# Lävistäjä (1,0)-(0,1) kuten Terrain.h().
					idx.append_array(PackedInt32Array([a, a + 1, a + rw, a + 1, a + rw + 1, a + rw]))
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_INDEX] = idx
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			tiles.append(am)
	var params := {"splat": load(T.SPLAT), "map_lo": lo, "map_size": hi - lo, "noise_tex": B.noise_tex(),
		"field_stripes": SURFACES.field[6], "stripe_angle": 0.35}
	for pair in [["meadow", "meadow"], ["forest", "forest"], ["field", "field"], ["bog", "bog"], ["cut", "clearcut"]]:
		var sd: Array = SURFACES[pair[1]]
		params[pair[0] + "_a"] = sd[0]
		params[pair[0] + "_b"] = sd[1]
		params[pair[0] + "_p"] = Vector4(sd[2], sd[3], sd[4], sd[5])
	var tmat := B.shader_mat("res://shaders/terrain.gdshader", params)
	for am in tiles:
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = tmat
		mi.set_meta("draped", true)
		add_child(mi)
	var body := StaticBody3D.new()
	body.set_meta("draped", true)
	# Oma törmäyskerros: vain pelaaja (pyörä, jalan) ja kamera osuvat maastoon; NPC:t kulkevat
	# maaston korkeudella suoraan (niiden laatikot eivät juutu ylämäkiin).
	body.collision_layer = T.COLLISION_LAYER
	body.collision_mask = 0
	var hm := HeightMapShape3D.new()
	hm.map_width = nx
	hm.map_depth = nz
	hm.map_data = T.heights
	var cs := CollisionShape3D.new()
	cs.shape = hm
	cs.scale = Vector3(T.CELL, 1.0, T.CELL)
	body.position = Vector3(T.origin.x + (nx - 1) * T.CELL * 0.5, 0.0, T.origin.y + (nz - 1) * T.CELL * 0.5)
	body.add_child(cs)
	add_child(body)


func _build_roads() -> void:
	var surfaces := {}
	var dashes := _new_st()
	for r in M.ROADS:
		var style: Dictionary = STYLES[r.type]
		var pts := _poly(r.pts)
		if style.edge != "":
			if not surfaces.has(style.edge):
				surfaces[style.edge] = _new_st()
			_strip(surfaces[style.edge], pts, style.w / 2.0 + 1.2, LAYER.shoulder)
		var sk: String = style.surf + ("_hw" if r.type == "highway" else "")
		if not surfaces.has(sk):
			surfaces[sk] = _new_st()
		_strip(surfaces[sk], pts, style.w / 2.0, LAYER[r.type])
		if style.dash:
			for i in pts.size() - 1:
				var a := pts[i]
				var b := pts[i + 1]
				var d := (b - a).normalized()
				var n := d.orthogonal() * 0.12
				var t := 4.0
				while t < a.distance_to(b) - 4.0:
					var p0 := a + d * t
					var p1 := a + d * (t + 3.0)
					for v in [p0 + n, p1 + n, p1 - n, p0 + n, p1 - n, p0 - n]:
						dashes.add_vertex(Vector3(v.x, LAYER.dash, v.y))
					t += 9.0
	for key in surfaces:
		var kind: String = key.trim_suffix("_hw")
		_commit_strip(surfaces[key], _surf(kind))
	_commit_strip(dashes, B.mat(Color(0.9, 0.9, 0.84)))


## Tieverkko autolle: tie- ja katuverkon taitepisteet, jaetut pisteet yhdistyvät risteyksiksi.
func _build_graph() -> void:
	var ids := {}
	for r in M.ROADS:
		if r.type != "road" and r.type != "street":
			continue
		var prev := -1
		for p in r.pts:
			var key := Vector2i(roundi(p.x), roundi(p.y))
			if not ids.has(key):
				ids[key] = graph_nodes.size()
				graph_nodes.append(M.w(p))
				graph_adj.append([])
				graph_fast.append(false)
			var id: int = ids[key]
			if r.type == "road":
				graph_fast[id] = true
			if prev >= 0 and prev != id:
				if not graph_adj[prev].has(id):
					graph_adj[prev].append(id)
				if not graph_adj[id].has(prev):
					graph_adj[id].append(prev)
			prev = id


## Pyöräilyverkko AStar3D:nä: kaikkien teiden, katujen ja polkujen taitepisteet, jaetut pisteet risteyksinä.
func _build_ride_graph() -> void:
	var ids := {}
	for r in M.ROADS:
		if r.type == "highway":
			continue
		var prev := -1
		for p in r.pts:
			var key := Vector2i(roundi(p.x), roundi(p.y))
			if not ids.has(key):
				var id := ids.size()
				ids[key] = id
				var w := M.w(p)
				ride.add_point(id, Vector3(w.x, 0, w.z))
			var cur: int = ids[key]
			if prev >= 0 and prev != cur and not ride.are_points_connected(prev, cur):
				ride.connect_points(prev, cur)
			prev = cur


## Reitti pyöräilyverkossa lähimmästä pisteestä lähimpään (maailman xz, y = 0).
func ride_route(from: Vector3, to: Vector3) -> PackedVector3Array:
	if ride.get_point_count() == 0:
		return PackedVector3Array()
	var a := ride.get_closest_point(Vector3(from.x, 0, from.z))
	var b := ride.get_closest_point(Vector3(to.x, 0, to.z))
	return ride.get_point_path(a, b)


func nearest_node(p: Vector3) -> int:
	var best := 0
	for i in graph_nodes.size():
		if graph_nodes[i].distance_squared_to(p) < graph_nodes[best].distance_squared_to(p):
			best = i
	return best


# --- Rakennukset -------------------------------------------------------------

## Omakotitalo harjakatolla yhdistettyyn meshiin + törmäyslaatikko. Paikallinen -Z = etuseinä.
## street_gap = etäisyys etuseinästä kadun reunaan (postilaatikko, aita). extras = false: ei satunnaisia pihaesineitä
## (postilaatikko, aita, autokatos, lipputanko, piharakennus), kun piha kalustetaan itse.
func _house(pos: Vector2, yaw: float, l: float, d: float, h: float, wall: Color, roof: Color,
		street_gap := -1.0, extras := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = Vector3(pos.x, 0, pos.y)
	body.rotation.y = yaw
	add_child(body)
	body.add_child(B.box_shape(Vector3(l, h, d), Vector3(0, h / 2.0, 0)))
	blockers.append([pos, Vector2(l / 2.0, d / 2.0), yaw])
	var xf := body.transform
	var batch := _batch_at(pos)
	if _lawn_st != null:
		var hl := l / 2.0 + 6.0
		var hd := d / 2.0 + (street_gap if street_gap > 0.0 else 6.0)
		var corners := [Vector3(-hl, 0.008, -hd), Vector3(hl, 0.008, -hd), Vector3(hl, 0.008, d / 2.0 + 7.0), Vector3(-hl, 0.008, d / 2.0 + 7.0)]
		for i in [0, 1, 2, 0, 2, 3]:
			var wv: Vector3 = xf * corners[i]
			_lawn_st.add_vertex(Vector3(wv.x, 0.008, wv.z))
	var add := func(m: PrimitiveMesh, p: Vector3, col: Color, rot_y := 0.0) -> void:
		batch.add(m, xf * Transform3D(Basis(Vector3.UP, rot_y), p), col)

	add.call(B.boxm(Vector3(l + 0.2, 0.5, d + 0.2)), Vector3(0, 0.25, 0), Color(0.42, 0.42, 0.42))
	add.call(B.boxm(Vector3(l, h - 0.4, d)), Vector3(0, 0.4 + (h - 0.4) / 2.0, 0), wall)
	var rh := clampf(d * 0.22, 1.2, 2.2)
	var prism := PrismMesh.new()
	prism.size = Vector3(d + 1.0, rh, l + 1.0)
	add.call(prism, Vector3(0, h + rh / 2.0, 0), roof, PI / 2.0)
	add.call(B.boxm(Vector3(l + 1.0, 0.18, d + 1.0)), Vector3(0, h + 0.05, 0), wall.darkened(0.25))
	add.call(B.boxm(Vector3(0.6, 1.5, 0.6)), Vector3(l * 0.25, h + rh * 0.7, 0), Color(0.5, 0.28, 0.22))
	if wall.r > 0.55 and wall.g < 0.3:
		# Punamultatalon valkoiset nurkkalaudat.
		for x in [-l / 2.0, l / 2.0]:
			for z in [-d / 2.0, d / 2.0]:
				add.call(B.boxm(Vector3(0.26, h - 0.4, 0.26)), Vector3(x, 0.4 + (h - 0.4) / 2.0, z), WHITE)
	var glass := Color(0.12, 0.17, 0.24)
	var n := maxi(2, int(l / 3.6))
	var door_i := n / 2
	for i in n:
		var x := -l / 2.0 + l * (i + 0.5) / n
		for z in [-d / 2.0, d / 2.0]:
			if z < 0.0 and i == door_i:
				add.call(B.boxm(Vector3(1.2, 2.3, 0.08)), Vector3(x, 1.55, z - 0.02), WHITE)
				add.call(B.boxm(Vector3(0.95, 2.1, 0.1)), Vector3(x, 1.45, z - 0.03), DOORS[_rng.randi() % DOORS.size()])
				add.call(B.boxm(Vector3(1.8, 0.3, 1.0)), Vector3(x, 0.15, z - 0.5), Color(0.5, 0.5, 0.5))
				continue
			var sgn := signf(z)
			add.call(B.boxm(Vector3(1.55, 1.35, 0.06)), Vector3(x, 1.75, z + sgn * 0.02), WHITE)
			add.call(B.boxm(Vector3(1.3, 1.1, 0.08)), Vector3(x, 1.75, z + sgn * 0.035), glass)
			add.call(B.boxm(Vector3(0.07, 1.1, 0.1)), Vector3(x, 1.75, z + sgn * 0.045), WHITE)
			if h > 4.0:
				add.call(B.boxm(Vector3(1.2, 1.0, 0.06)), Vector3(x, 4.1, z + sgn * 0.02), WHITE)
				add.call(B.boxm(Vector3(1.0, 0.8, 0.08)), Vector3(x, 4.1, z + sgn * 0.035), glass)
	for x in [-l / 2.0, l / 2.0]:
		var sgn := signf(x)
		add.call(B.boxm(Vector3(0.06, 1.35, 1.55)), Vector3(x + sgn * 0.02, 1.75, 0), WHITE)
		add.call(B.boxm(Vector3(0.08, 1.1, 1.3)), Vector3(x + sgn * 0.035, 1.75, 0), glass)

	if street_gap > 0.0 and extras:
		var front := -d / 2.0 - street_gap
		if _rng.randf() < 0.75:
			var mx := l / 2.0 - 1.0
			add.call(B.boxm(Vector3(0.08, 1.1, 0.08)), Vector3(mx, 0.55, front + 1.2), Color(0.35, 0.35, 0.35))
			add.call(B.boxm(Vector3(0.36, 0.3, 0.5)), Vector3(mx, 1.2, front + 1.2),
				[Color(0.9, 0.9, 0.88), Color(0.2, 0.4, 0.25), Color(0.8, 0.6, 0.1)][_rng.randi() % 3])
		var fence_roll := _rng.randf()
		if fence_roll < 0.35:
			# Pensasaita pihan edessä, portti keskellä.
			var hz := front + 2.0
			var hl := (l + 8.0) / 2.0 - 1.6
			var hedge := Color(0.2, 0.36, 0.14).lightened(_rng.randf_range(-0.05, 0.08))
			var hh := _rng.randf_range(0.8, 1.3)
			for sx in [-1.0, 1.0]:
				_add_hedge(xf, Vector3(sx * (1.6 + hl / 2.0), hh / 2.0, hz), Vector3(hl, hh, 0.8), hedge.lightened(0.1))
		elif fence_roll < 0.55:
			var fz := front + 2.2
			var fl := l + 8.0
			for y in [0.4, 0.85]:
				add.call(B.boxm(Vector3(fl, 0.08, 0.05)), Vector3(0, y, fz), WHITE)
			var k := 0.0
			while k <= fl:
				if absf(-fl / 2.0 + k) > 1.8:  # portti keskellä
					add.call(B.boxm(Vector3(0.08, 1.0, 0.08)), Vector3(-fl / 2.0 + k, 0.5, fz), WHITE)
				k += 1.6
	if street_gap > 0.0 and extras and _rng.randf() < 0.35:
		# Autokatos talon päädyssä, sivulla rimasäleikkö.
		var cp := Vector3(l / 2.0 + 2.2, 0, -d / 2.0 + 1.0)
		for px in [-1.5, 1.5]:
			for pz in [-2.4, 2.4]:
				add.call(B.boxm(Vector3(0.12, 2.3, 0.12)), cp + Vector3(px, 1.15, pz), WHITE)
		add.call(B.boxm(Vector3(3.4, 0.15, 5.4)), cp + Vector3(0, 2.35, 0), roof)
		for i in 9:
			add.call(B.boxm(Vector3(0.05, 1.6, 0.07)), cp + Vector3(1.55, 0.95, -2.2 + i * 0.55), wall)
		body.add_child(B.box_shape(Vector3(3.2, 2.3, 0.3), cp + Vector3(0, 1.15, 2.4)))
	if extras and _rng.randf() < 0.13:
		# Lipputanko ja Suomen lippu.
		var fp := Vector3(-l / 2.0 - 3.0, 0, -d / 2.0 - 3.0)
		add.call(B.cyl(0.05, 0.07, 8.0, 6), fp + Vector3(0, 4.0, 0), WHITE)
		add.call(B.boxm(Vector3(1.8, 1.1, 0.03)), fp + Vector3(0.95, 7.35, 0), WHITE)
		add.call(B.boxm(Vector3(1.8, 0.3, 0.05)), fp + Vector3(0.95, 7.35, 0), Color(0.0, 0.2, 0.55))
		add.call(B.boxm(Vector3(0.3, 1.1, 0.05)), fp + Vector3(0.7, 7.35, 0), Color(0.0, 0.2, 0.55))
	if extras and _rng.randf() < 0.3:
		# Piharakennus / sauna.
		var sp := Vector3(_rng.randf_range(-l / 3.0, l / 3.0), 0, d / 2.0 + 5.0)
		var sc: Color = [Color(0.6, 0.15, 0.11), Color(0.45, 0.3, 0.2), Color(0.55, 0.55, 0.5)][_rng.randi() % 3]
		add.call(B.boxm(Vector3(3.5, 2.3, 2.8)), sp + Vector3(0, 1.15, 0), sc)
		var sr := PrismMesh.new()
		sr.size = Vector3(3.2, 1.0, 4.0)
		add.call(sr, sp + Vector3(0, 2.8, 0), roof, PI / 2.0)
		body.add_child(B.box_shape(Vector3(3.5, 2.3, 2.8), sp + Vector3(0, 1.15, 0)))
	return body


## Lähin tieosuuden piste ja tien puolileveys (tyhjä, jos tietä ei ole lähiruuduissa).
func _nearest_road(p: Vector2) -> Array:
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var best := INF
	var out := []
	for s in _seg_grid.get(key, []):
		var c := Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
		var d: float = p.distance_to(c) - s[2]
		if d < best and s[3] != "path":
			best = d
			out = [c, s[2]]
	return out


## Talot OpenStreetMapin rakennuksista (map_osm.gd BUILDINGS): paikka, suunta ja koko pohjapiirroksesta,
## julkisivu lähimmälle tielle. Omat mallit (koti, naapurit, kauppa) ovat M.OWN_BUILDINGS-kohdissa.
## OSM-rakennuksen pohja pelimaailmaan: keskipiste, mitat (l = pitkä sivu), julkisivun normaali lähintä tietä
## kohti, sen suunta (yaw) ja etupihan leveys tielle (gap, -1 = ei tietä lähellä).
func _osm_fit(b: Dictionary) -> Dictionary:
	var c := M.w2(b.c)
	var l: float = b.l * M.SCALE
	var d: float = b.d * M.SCALE
	var ax := Vector2(cos(b.a), sin(b.a))
	var nrm := ax.orthogonal()
	var gap := -1.0
	var near := _nearest_road(c)
	if not near.is_empty():
		var to_road: Vector2 = near[0] - c
		if nrm.dot(to_road) < 0.0:
			nrm = -nrm
		var g: float = absf(nrm.dot(to_road)) - d / 2.0 - near[1]
		if g > 1.5 and g < 18.0:
			gap = g
	return {"c": c, "l": l, "d": d, "ax": ax, "nrm": nrm, "gap": gap, "yaw": B.yaw_to(Vector3(nrm.x, 0, nrm.y))}


## Karttapisteessä px olevan OSM-rakennuksen pohja (_osm_fit); tyhjä, jos rakennusta ei löydy.
func _osm_fit_at(px: Vector2) -> Dictionary:
	for b in M.Osm.BUILDINGS:
		if (b.c as Vector2).distance_to(px) < 4.0:
			return _osm_fit(b)
	return {}


func _build_houses() -> void:
	for b in M.Osm.BUILDINGS:
		var cp: Vector2 = b.c
		var own := false
		for q in M.OWN_BUILDINGS:
			if cp.distance_to(q) < 4.0:
				own = true
		if own:
			continue
		var f := _osm_fit(b)
		var c: Vector2 = f.c
		var l: float = f.l
		var d: float = f.d
		if not _in_bounds(c, 3.0) or _in_any(c, _water):
			continue
		var ax: Vector2 = f.ax
		var nrm: Vector2 = f.nrm
		var gap: float = f.gap
		var area := l * d
		var h := 3.3
		if area < 45.0:
			h = 2.4  # piharakennus, sauna tai autotalli
			gap = -1.0
		elif b.lv >= 2 or area > 260.0:
			h = 3.0 * maxi(b.lv, 2) - 0.4
		_add_house(c)
		var k := 1
		while l > 14.0 * k:  # pitkä rakennus: lisäpisteet päätyihin, ettei puita kasva seinien sisään
			_add_house(c + ax * (l / 2.0 - 5.0) * (float(k) / ceilf(l / 14.0)))
			_add_house(c - ax * (l / 2.0 - 5.0) * (float(k) / ceilf(l / 14.0)))
			k += 1
		_house(c, f.yaw, l, d, h, WALLS[_rng.randi() % WALLS.size()],
			ROOFS[_rng.randi() % ROOFS.size()], gap)
		# Pihapuut: koivuja, pihlajia (lehtipuu), kuusia ja mäntyjä talon taakse ja sivuille.
		if area >= 45.0:
			for tk in _rng.randi_range(1, 3):
				var tp: Vector2 = c - nrm * (d / 2.0 + _rng.randf_range(4.0, 9.0)) + ax * _rng.randf_range(-l / 2.0 - 3.0, l / 2.0 + 3.0)
				if _road_clearance(tp) > 3.0 and not _near_house(tp, 5.0):
					var kind: String = ["birch", "birch", "spruce", "pine"][_rng.randi() % 4]
					_trees.append([tp, kind, _rng.randf_range(0.75, 1.15), true])


## Järvikuja 1 katunäkymän (2022) mukaan: punatiilinen yksikerroksinen talo, musta tiilikuviopeltikatto,
## valkoiset päätykolmiot ja räystäslaudat, isot valkokarmiset ikkunat kukkalaatikoineen, valkoinen ovi kapealla
## pystyikkunalla, musta piippu, autotalli päädyssä, asfalttipiha autoineen, tiheä havupensasaita ja pyörät seinällä.
func _build_home() -> void:
	var c := M.w2(M.HOME_BUILDING)
	_add_house(c)
	var l := 19.0
	var d := 10.0
	var h := 2.9
	var rh := 1.5
	var body := StaticBody3D.new()
	body.position = Vector3(c.x, 0, c.y)
	body.rotation.y = B.yaw_to(Vector3(M.HOME_YAW_DIR.x, 0, M.HOME_YAW_DIR.y))  # julkisivu itään Järvikujalle
	add_child(body)
	body.add_child(B.box_shape(Vector3(l, h + rh, d), Vector3(0, (h + rh) / 2.0, 0)))
	var white := Color(0.95, 0.95, 0.93)
	var brick_mat := B.shader_mat("res://shaders/bricks.gdshader")
	var roof_mat := B.shader_mat("res://shaders/metal_roof.gdshader")
	var put := func(m: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		body.add_child(mi)
		return mi
	# Sokkeli ja tiiliseinät.
	put.call(B.boxm(Vector3(l + 0.1, 0.35, d + 0.1)), Vector3(0, 0.175, 0), B.mat(Color(0.55, 0.55, 0.53)))
	put.call(B.boxm(Vector3(l, h - 0.3, d)), Vector3(0, 0.3 + (h - 0.3) / 2.0, 0), brick_mat)
	# Harjakatto kahtena peltilappeena, valkoiset päätykolmiot ja räystäslaudat.
	var ang := atan(rh / (d / 2.0))
	var half := (d / 2.0 + 0.6) / cos(ang)
	for sz in [-1.0, 1.0]:
		put.call(B.boxm(Vector3(l + 1.0, 0.07, half)), Vector3(0, h + rh / 2.0 - 0.06, sz * (d / 4.0 + 0.15)), roof_mat, Vector3(sz * ang, 0, 0))
		put.call(B.boxm(Vector3(l + 1.0, 0.2, 0.05)), Vector3(0, h - 0.12, sz * (d / 2.0 + 0.58)), B.mat(white))
	for sx in [-1.0, 1.0]:
		var gable := PrismMesh.new()
		gable.size = Vector3(d, rh, 0.06)
		put.call(gable, Vector3(sx * (l / 2.0 + 0.02), h + rh / 2.0, 0), B.mat(white), Vector3(0, PI / 2.0, 0))
		for k in 6:
			put.call(B.boxm(Vector3(0.07, 0.02, 0.02)), Vector3(sx * (l / 2.0 + 0.06), h + 0.15 + k * 0.22, 0), B.mat(Color(0.8, 0.8, 0.78)))
	put.call(B.boxm(Vector3(0.6, 1.3, 0.6)), Vector3(-3.0, h + rh - 0.1, 0.8), B.mat(Color(0.06, 0.06, 0.06)))
	put.call(B.boxm(Vector3(0.8, 0.06, 0.8)), Vector3(-3.0, h + rh + 0.6, 0.8), B.mat(Color(0.1, 0.1, 0.1)))
	# Julkisivu (-Z): ikkunat, ovi, porras, autotalli päädyssä, talonumero.
	var fz := -d / 2.0 - 0.02
	var glass := B.mat(Color(0.12, 0.16, 0.22))
	for wx in [-8.5, -5.0, -1.5, 3.5]:
		put.call(B.boxm(Vector3(1.7, 1.4, 0.06)), Vector3(wx, 1.65, fz), B.mat(white))
		put.call(B.boxm(Vector3(1.45, 1.15, 0.08)), Vector3(wx, 1.65, fz - 0.01), glass)
		put.call(B.boxm(Vector3(0.07, 1.15, 0.1)), Vector3(wx - 0.3, 1.65, fz - 0.02), B.mat(white))
		put.call(B.boxm(Vector3(1.2, 0.18, 0.2)), Vector3(wx, 0.9, fz - 0.12), B.mat(Color(0.12, 0.12, 0.12)))
		for f in 5:
			put.call(B.sphere(0.07, 6), Vector3(wx - 0.45 + f * 0.22, 1.02, fz - 0.14), B.mat([Color(0.85, 0.2, 0.3), Color(0.95, 0.85, 0.2), Color(0.3, 0.55, 0.2)][f % 3]))
	put.call(B.boxm(Vector3(1.05, 2.15, 0.08)), Vector3(1.2, 1.4, fz), B.mat(white))
	put.call(B.boxm(Vector3(0.12, 1.3, 0.1)), Vector3(1.2, 1.55, fz - 0.02), glass)
	put.call(B.boxm(Vector3(1.6, 0.3, 1.1)), Vector3(1.2, 0.15, fz - 0.55), B.mat(Color(0.6, 0.6, 0.58)))
	# Takaovi takapihalle etuovea vastapäätä (kodin sisätila, home_interior.gd): ovi ja porras.
	put.call(B.boxm(Vector3(1.05, 2.15, 0.08)), Vector3(1.2, 1.4, -fz), B.mat(Color(0.55, 0.38, 0.22)))
	put.call(B.boxm(Vector3(1.4, 0.25, 0.9)), Vector3(1.2, 0.125, -fz + 0.45), B.mat(Color(0.6, 0.6, 0.58)))
	put.call(B.boxm(Vector3(2.8, 2.3, 0.06)), Vector3(l / 2.0 - 2.4, 1.45, fz), B.mat(white))
	for k in 5:
		put.call(B.boxm(Vector3(2.8, 0.02, 0.08)), Vector3(l / 2.0 - 2.4, 0.45 + k * 0.45, fz - 0.02), B.mat(Color(0.8, 0.8, 0.8)))
	var num := B.sign_plate(body, "1", Color(0.1, 0.3, 0.6), Color.WHITE, 0.2, 40, Color(0.1, 0.3, 0.6))
	num.position = Vector3(2.1, 2.2, fz - 0.05)
	num.rotation.y = PI
	var koti := B.guide(body, "KOTI", Vector3(0, h + rh + 1.2, 0), 90, Color(0.4, 1.0, 0.5), true)
	koti.no_depth_test = false
	# Takaseinän ikkunat.
	for wx in [-6.0, 0.0, 5.0]:
		put.call(B.boxm(Vector3(1.5, 1.2, 0.06)), Vector3(wx, 1.7, d / 2.0 + 0.02), B.mat(white))
		put.call(B.boxm(Vector3(1.25, 1.0, 0.08)), Vector3(wx, 1.7, d / 2.0 + 0.03), glass)
	# Asfalttipiha kadun puolelle, autot, pensasaita ja pyörät seinällä.
	var xf := body.transform
	var yard := PackedVector2Array()
	for q in [Vector3(-l / 2.0, 0, fz), Vector3(l / 2.0, 0, fz), Vector3(l / 2.0, 0, fz - 8.5), Vector3(-l / 2.0, 0, fz - 8.5)]:
		var wq: Vector3 = xf * q
		yard.append(Vector2(wq.x, wq.z))
	_flat_poly(yard, LAYER.lot, _surf("asphalt"))
	_lots.append(yard)
	var yard_c: Vector3 = xf * Vector3(0, 0, -5.0)
	_mask_clear.append([Vector2(yard_c.x, yard_c.z), l / 2.0 + 1.5, d / 2.0 + 9.5, body.rotation.y])
	for car in [[Vector3(-2.5, 0, fz - 4.0), Color(0.15, 0.35, 0.75)], [Vector3(2.2, 0, fz - 4.0), Color(0.45, 0.08, 0.12)]]:
		var cp: Vector3 = xf * car[0]
		B.parked_car(self, cp, rad_to_deg(body.rotation.y), car[1])
	# Droonin laskeutumisalusta autojen vieressä: tumma kiekko, keltainen H.
	drone_pad_pos = xf * Vector3(-6.0, 0, fz - 7.0)
	DroneGame.make_pad(self, drone_pad_pos + Vector3(0, T.h(drone_pad_pos.x, drone_pad_pos.z), 0), body.rotation.y)
	# Tumma havupensasaita (tuija/kataja) kadun puolella.
	for seg in [[-l / 2.0, -4.5], [5.0, l / 2.0]]:
		var hl: float = seg[1] - seg[0]
		_add_hedge(xf, Vector3((seg[0] + seg[1]) / 2.0, 0.75, fz - 9.0), Vector3(hl, 1.5, 1.0), Color(0.18, 0.34, 0.16))
	for bx in [-0.4, 0.2]:
		_static_bike(body, Vector3(bx - 1.0, 0, fz - 0.35), 0.15)
	# Takapihan nurmikko: nurmipinta maahan, ruohon kasvattaa ja leikkaa lawn.gd (yleinen ruoho pois).
	var lr := lawn_rect.grow(1.0)
	var lawn_poly := PackedVector2Array()
	for q in [lr.position, Vector2(lr.end.x, lr.position.y), lr.end, Vector2(lr.position.x, lr.end.y)]:
		lawn_poly.append((q as Vector2).rotated(lawn_angle) + lawn_pivot)
	_flat_poly(lawn_poly, 0.009, _surf("lawn"))
	_mask_clear.append([lawn_pivot, lawn_rect.size.x / 2.0, lawn_rect.size.y / 2.0, -lawn_angle])
	_build_neighbors()


## Yksinkertainen pyörä nojaamassa seinään (koristeeksi).
func _static_bike(parent: Node3D, pos: Vector3, lean: float) -> void:
	var bk := Node3D.new()
	bk.position = pos
	bk.rotation = Vector3(0, 0, lean)
	parent.add_child(bk)
	var tire := TorusMesh.new()
	tire.inner_radius = 0.28
	tire.outer_radius = 0.33
	tire.rings = 16
	tire.ring_segments = 5
	for z in [-0.5, 0.5]:
		B.mesh(bk, tire, Vector3(z, 0.33, 0), Color(0.06, 0.06, 0.06), Vector3(90, 0, 0))
	B.tube(bk, Vector3(-0.5, 0.33, 0), Vector3(0.05, 0.75, 0), 0.02, Color(0.2, 0.4, 0.7))
	B.tube(bk, Vector3(0.05, 0.75, 0), Vector3(0.5, 0.33, 0), 0.02, Color(0.2, 0.4, 0.7))
	B.tube(bk, Vector3(0.05, 0.75, 0), Vector3(0.45, 0.95, 0), 0.02, Color(0.2, 0.4, 0.7))
	B.tube(bk, Vector3(0.45, 0.95, -0.25), Vector3(0.45, 0.95, 0.25), 0.015, Color(0.1, 0.1, 0.1))


## Järvikujan lähinaapurit katunäkymän mukaan.
func _build_neighbors() -> void:
	var to_east := B.yaw_to(Vector3(M.HOME_YAW_DIR.x, 0, M.HOME_YAW_DIR.y))  # kadun länsipuolelta kadulle
	var dark_roof := Color(0.2, 0.21, 0.22)
	# Naapuritalot OSM-pohjan mukaan (koko ja suunta, julkisivu Järvikujalle); omat värit ja pihat.
	# Talon kehyksessä -Z on julkisivu ja fz sen z, ovi kohdassa (dx, fz) (_house). Etupihan aita, autokatos ja
	# muut satunnaiset pihaesineet jätetään pois (extras false), jotta pihan omat esineet ja puuhapisteet mahtuvat.
	var fit := func(px: Vector2, street: String) -> Dictionary:
		var f := _osm_fit_at(px)
		var c: Vector2 = f.c
		# Julkisivu kadulle (street): se neljästä sivusta, jonka normaali osoittaa kadun lähimpään pisteeseen
		# (neliömäinen talo voi kääntyä päätyyn nähden, jolloin l ja d vaihtavat paikkaa).
		var to_st := Vector2.ZERO
		for r in M.Osm.ROADS:
			if r.get("name", "") == street:
				var best := INF
				for i in r.pts.size() - 1:
					var q := Geometry2D.get_closest_point_to_segment(c, M.w2(r.pts[i]), M.w2(r.pts[i + 1]))
					if q.distance_to(c) < best:
						best = q.distance_to(c)
						to_st = q - c
		var ax: Vector2 = f.ax
		if absf(ax.dot(to_st)) > absf(ax.orthogonal().dot(to_st)):
			f.ax = ax.orthogonal()
			var tmp: float = f.l
			f.l = f.d
			f.d = tmp
		var nrm: Vector2 = (f.ax as Vector2).orthogonal()
		if nrm.dot(to_st) < 0.0:
			nrm = -nrm
		f.nrm = nrm
		f.yaw = B.yaw_to(Vector3(nrm.x, 0, nrm.y))
		f.gap = maxf(nrm.dot(to_st) - f.d / 2.0 - JARVIKUJA_HALF, 2.0)  # etupiha julkisivusta tien reunaan
		_add_house(c)
		for s in [-1.0, 1.0]:  # päädyt, ettei puita kasva seinien sisään
			_add_house(c + (f.ax as Vector2) * s * (f.l / 2.0 - 3.0))
		_mask_clear.append([c, f.l / 2.0 + 0.5, f.d / 2.0 + 1.0, f.yaw])
		f.fz = -f.d / 2.0
		var nw := maxi(2, int(f.l / 3.6))
		f.dx = -f.l / 2.0 + f.l * (nw / 2 + 0.5) / nw
		return f
	# Pekka asuu Lehtikujan päässä vaaleassa, lähes valkoisessa talossa vaalealla peltikatolla; kuisti (valkoinen
	# pergola) etukulmassa, kadun varressa pensasaita ja kaksi valkoista pihavaloa.
	var fn: Dictionary = fit.call(M.NEIGHBOR_PEKKA, "Lehtikuja")
	var nb := _house(fn.c, fn.yaw, fn.l, fn.d, 3.3, Color(0.9, 0.88, 0.8), Color(0.72, 0.7, 0.6), fn.gap, false)
	var pg := Vector3(fn.l / 2.0 - 2.0, 0, fn.fz - 1.6)
	for px in [-1.5, 1.5]:
		B.mesh(nb, B.boxm(Vector3(0.14, 2.6, 0.14)), pg + Vector3(px, 1.3, -1.5), Color(0.95, 0.95, 0.93))
	for k in 7:
		B.mesh(nb, B.boxm(Vector3(3.2, 0.06, 0.06)), pg + Vector3(0, 2.6, -1.5 + k * 0.5), Color(0.95, 0.95, 0.93))
	_street_hedge(nb, fn, 0.0)
	for x in [fn.dx - 1.6, fn.dx + 1.6]:
		var lamp := Vector3(x, 0, fn.fz - fn.gap + 2.0)
		B.mesh(nb, B.cyl(0.08, 0.08, 1.0, 8), lamp + Vector3(0, 0.5, 0), Color(0.95, 0.95, 0.93))
		B.mesh(nb, B.sphere(0.13, 8), lamp + Vector3(0, 1.08, 0), Color(1.0, 0.97, 0.85))
	# Arto asuu heti vasemmalla (kodin eteläpuolella, autotallin takana): matala keltatiilinen talo vaalealla
	# peltikatolla, etupihalla vanha punainen traktori, kadun varressa pensasaita.
	var fa: Dictionary = fit.call(M.NEIGHBOR_ARTO, "Järvikuja")
	var ab := _house(fa.c, fa.yaw, fa.l, fa.d, 3.1, Color(0.84, 0.68, 0.4), Color(0.66, 0.68, 0.62), fa.gap, false)
	var sa := signf((ab.transform.basis.inverse() * Vector3.BACK).x)  # talon x-akselin eteläsuunta
	_street_hedge(ab, fa, sa)
	_old_tractor(ab, Vector3(sa * (fa.l / 2.0 - 1.2), 0, fa.fz - 3.2), 0.4)
	var tp: Vector3 = ab.transform * Vector3(sa * (fa.l / 2.0 - 1.2), 0, fa.fz - 3.2)
	blockers.append([Vector2(tp.x, tp.z), Vector2(1.6, 1.6), fa.yaw])  # traktori (neliö, ettei suunnalla ole väliä)
	# Katettu postilaatikkoteline kadun varressa.
	var mb := Node3D.new()
	var mbp := M.w2(M.MAILBOX)
	mb.position = Vector3(mbp.x, 0, mbp.y)
	mb.rotation.y = to_east
	add_child(mb)
	for x in [-1.0, 1.0]:
		B.mesh(mb, B.boxm(Vector3(0.08, 1.4, 0.08)), Vector3(x, 0.7, 0), Color(0.4, 0.4, 0.42))
	for i in 5:
		B.mesh(mb, B.boxm(Vector3(0.36, 0.3, 0.45)), Vector3(-0.8 + i * 0.4, 1.2, 0), Color(0.62, 0.64, 0.66))
	var mr := PrismMesh.new()
	mr.size = Vector3(0.8, 0.25, 2.4)
	B.mesh(mb, mr, Vector3(0, 1.5, 0), Color(0.25, 0.25, 0.27), Vector3(0, 90, 0))
	# Sinikan talo Järvikujan itäpuolella on katunäkymässä lähes piilossa isojen pyöreiden pensaiden takana; kadun
	# varressa värikkäät postilaatikot. Julkisivun edessä kukkapenkki, aurinkotuoli ja radio, päädyissä kasvimaa
	# ja ruusupensaat.
	var fb: Dictionary = fit.call(M.NEIGHBOR_SINIKKA, "Järvikuja")
	var bb := _house(fb.c, fb.yaw, fb.l, fb.d, 3.1, Color(0.86, 0.8, 0.66), Color(0.33, 0.3, 0.28), fb.gap, false)
	var fz: float = fb.fz
	# Takapihan nurmikko talon takana (julkisivu kadulle -Z, takaseinä +Z): metsä ei kasva sille.
	var lsize := Vector2(maxf(fb.l - 2.0, 8.0), 6.0)
	var lc: Vector3 = bb.transform * Vector3(0, 0, -fz + 1.2 + lsize.y / 2.0)
	var lax: Vector3 = bb.transform.basis.x
	var lang := atan2(lax.z, lax.x)
	sinikka_lawn = {"pivot": Vector2(lc.x, lc.z), "size": lsize, "angle": lang,
		"mower": bb.transform * Vector3(lsize.x / 2.0 + 0.8, 0, -fz + 1.6)}
	_mask_clear.append([Vector2(lc.x, lc.z), lsize.x / 2.0 + 1.0, lsize.y / 2.0 + 1.0, -lang])
	var street_z: float = fz - fb.gap + 1.2
	for k in 5:  # isot pyöreät pensaat kadun varressa, ajotie keskellä
		var bx: float = [-fb.l / 2.0 - 1.0, -fb.l / 2.0 + 2.4, fb.dx + 3.4, fb.l / 2.0 - 1.5, fb.l / 2.0 + 1.8][k]
		var br: float = [1.6, 1.9, 1.7, 2.0, 1.5][k]
		B.mesh(bb, B.sphere(br, 10), Vector3(bx, br * 0.8, street_z + 0.4), Color(0.2, 0.38, 0.15).lightened(0.04 * k))
	var mbox := Vector3(fb.dx + 1.4, 0, street_z - 0.6)
	B.mesh(bb, B.boxm(Vector3(1.9, 0.06, 0.1)), mbox + Vector3(0, 1.05, 0), Color(0.35, 0.35, 0.35))
	for x in [-0.8, 0.8]:
		B.mesh(bb, B.boxm(Vector3(0.08, 1.1, 0.08)), mbox + Vector3(x, 0.55, 0), Color(0.35, 0.35, 0.35))
	var box_cols := [Color(0.9, 0.55, 0.62), Color(0.55, 0.57, 0.6), Color(0.5, 0.52, 0.55), Color(0.2, 0.35, 0.75)]
	for i in 4:
		B.mesh(bb, B.boxm(Vector3(0.36, 0.32, 0.45)), mbox + Vector3(-0.66 + i * 0.44, 1.25, 0), box_cols[i])
	var lounger := Node3D.new()
	lounger.rotation.y = 0.3
	bb.add_child(lounger)
	B.mesh(lounger, B.boxm(Vector3(0.7, 0.08, 1.9)), Vector3(0, 0.35, 0), Color(0.95, 0.3, 0.45))
	B.mesh(lounger, B.boxm(Vector3(0.7, 0.08, 0.7)), Vector3(0, 0.6, 0.95), Color(0.95, 0.3, 0.45), Vector3(-40, 0, 0))
	for lx in [-0.3, 0.3]:
		for lz in [-0.8, 0.8]:
			B.mesh(lounger, B.boxm(Vector3(0.04, 0.35, 0.04)), Vector3(lx, 0.17, lz), Color(0.9, 0.9, 0.9))
	lounger.position = Vector3(fb.l / 2.0 - 2.5, 0, fz - 3.6)
	B.mesh(bb, B.boxm(Vector3(0.4, 0.22, 0.14)), Vector3(fb.l / 2.0 - 3.5, 0.11, fz - 2.6), Color(0.85, 0.1, 0.12))  # radio
	# Sinikan puutarha: kukkapenkki, kasvimaa riveineen ja ruusupensaat (puuhapisteet niiden edessä).
	var soil := Color(0.3, 0.2, 0.12)
	var bed := Vector3(-4.5, 0, fz - 2.8)
	B.mesh(bb, B.boxm(Vector3(3.2, 0.18, 1.1)), bed + Vector3(0, 0.09, 0), soil)
	var petals := [Color(0.95, 0.2, 0.35), Color(1.0, 0.8, 0.1), Color(0.7, 0.3, 0.85), Color(1.0, 0.95, 0.95)]
	for k in 14:
		var fp := bed + Vector3(-1.4 + (k % 7) * 0.47, 0, -0.35 + (k / 7) * 0.6)
		B.mesh(bb, B.cyl(0.015, 0.015, 0.35, 4), fp + Vector3(0, 0.35, 0), Color(0.2, 0.45, 0.15))
		B.mesh(bb, B.sphere(0.09, 6), fp + Vector3(0, 0.55, 0), petals[k % petals.size()])
	var veg := Vector3(-fb.l / 2.0 - 2.4, 0, fz + 3.5)
	B.mesh(bb, B.boxm(Vector3(1.8, 0.14, 3.4)), veg + Vector3(0, 0.07, 0), soil)
	for row in 3:
		for k in 6:
			B.mesh(bb, B.sphere(0.13, 6), veg + Vector3(-0.6 + row * 0.6, 0.2, -1.45 + k * 0.58), Color(0.25, 0.55, 0.2))
	for k in 3:
		var rp := Vector3(fb.l / 2.0 + 1.3, 0, fz + 1.5 + k * 1.0)
		B.mesh(bb, B.sphere(0.45, 8), rp + Vector3(0, 0.45, 0), Color(0.18, 0.4, 0.14))
		B.mesh(bb, B.sphere(0.1, 6), rp + Vector3(-0.3, 0.75, -0.2), Color(0.85, 0.08, 0.2))
	var watering := B.mesh(bb, B.cyl(0.12, 0.14, 0.28, 10), Vector3(-2.2, 0.14, fz - 2.3), Color(0.2, 0.55, 0.3))
	watering.rotation.y = 0.5
	# Pihojen puuhapisteet talon kehyksessä: ensimmäinen on ulko-oven edusta (lähtöpaikka), muut etupihalla ja
	# päädyissä, kaukana seinistä, pergolasta, traktorista ja mahdollisesta lipputangosta (-l/2 - 3, fz - 3).
	var yard_pts := func(body: Node3D, local_pts: Array) -> Array[Vector3]:
		var out: Array[Vector3] = []
		for q: Vector3 in local_pts:
			var wq: Vector3 = body.transform * q
			out.append(Vector3(wq.x, T.h(wq.x, wq.z), wq.z))
		return out
	var door := func(f: Dictionary) -> Vector3:
		return Vector3(f.dx, 0, f.fz - 1.4)
	# Sinikka katsoo puuhapisteessä penkkiin päin (kukat, kasvimaa, ruusut).
	neighbor_faces = {"sinikka": yard_pts.call(bb, [Vector3(fb.dx, 0, fz - 3.0), bed, veg, Vector3(fb.l / 2.0 + 1.3, 0, fz + 2.5)])}
	neighbor_yards = {
		"pekka": yard_pts.call(nb, [door.call(fn), Vector3(-3.5, 0, fn.fz - 2.5), Vector3(fn.l / 2.0 - 3.5, 0, fn.fz - 3.0),
			Vector3(-fn.l / 2.0 - 1.6, 0, fn.fz + 2.0)]),
		"arto": yard_pts.call(ab, [door.call(fa), Vector3(fa.dx - 1.0, 0, fa.fz - 4.5), Vector3(-sa * 2.0, 0, fa.d / 2.0 + 2.5),
			Vector3(-sa * (fa.l / 2.0 + 1.6), 0, fa.fz + 2.0)]),
		"sinikka": yard_pts.call(bb, [door.call(fb), bed + Vector3(0, 0, 1.2), veg + Vector3(1.4, 0, 0),
			Vector3(fb.l / 2.0 + 2.4, 0, fz + 2.5)]),
	}
	# Etelään: keltatiilinen autotalli ruskealla ovella ja luonnonpuinen säleaita.
	var g := M.w2(M.GARAGE)
	_add_house(g)
	var gar := StaticBody3D.new()
	gar.position = Vector3(g.x, 0, g.y)
	gar.rotation.y = to_east
	add_child(gar)
	gar.add_child(B.box_shape(Vector3(7.0, 3.0, 6.0), Vector3(0, 1.5, 0)))
	var yb := B.shader_mat("res://shaders/bricks.gdshader", {"brick": Color(0.86, 0.72, 0.45), "mortar": Color(0.8, 0.78, 0.72)})
	var gw := MeshInstance3D.new()
	gw.mesh = B.boxm(Vector3(7.0, 2.8, 6.0))
	gw.material_override = yb
	gw.position.y = 1.4
	gar.add_child(gw)
	B.mesh(gar, B.boxm(Vector3(7.4, 0.2, 6.4)), Vector3(0, 2.9, 0), Color(0.2, 0.2, 0.22))
	B.mesh(gar, B.boxm(Vector3(2.8, 2.2, 0.06)), Vector3(-1.5, 1.1, -3.02), Color(0.4, 0.25, 0.15))
	for k in 6:  # nosturioven paneelit
		B.mesh(gar, B.boxm(Vector3(2.7, 0.03, 0.03)), Vector3(-1.5, 0.3 + k * 0.36, -3.06), Color(0.32, 0.2, 0.12))
	B.mesh(gar, B.boxm(Vector3(0.3, 0.05, 0.05)), Vector3(-1.5, 0.35, -3.08), Color(0.7, 0.7, 0.72))  # kahva
	garage_out = gar.basis * Vector3(0, 0, -1)
	var gd: Vector3 = gar.position + gar.basis * Vector3(-1.5, 0, -3.9)
	garage_door = Vector3(gd.x, T.h(gd.x, gd.z), gd.z)
	for k in 16:
		B.mesh(gar, B.boxm(Vector3(0.1, 1.6, 0.03)), Vector3(3.8 + k * 0.14, 0.8, -3.0 + k * 0.0), Color(0.72, 0.6, 0.42))
	B.mesh(gar, B.boxm(Vector3(2.4, 0.07, 0.05)), Vector3(4.9, 1.2, -3.0), Color(0.62, 0.5, 0.35))


## Pensasaita naapurin etupihan reunaan kadun varteen (talon kehyksessä, f = _build_neighbors fit). Ajotien
## aukko talon siinä päädyssä, johon drive osoittaa (-1/1 x-akselilla), 0 = portti oven kohdalla.
func _street_hedge(body: Node3D, f: Dictionary, drive: float) -> void:
	var z: float = f.fz - f.gap + 0.8
	var x0: float = -f.l / 2.0 - 2.0
	var x1: float = f.l / 2.0 + 2.0
	var gaps: Array = [[f.dx - 1.2, f.dx + 1.2]] if drive == 0.0 else [[drive * (f.l / 2.0 - 3.5) - 1.8, drive * (f.l / 2.0 - 3.5) + 1.8]]
	var segs: Array = [[x0, gaps[0][0]], [gaps[0][1], x1]]
	for sg in segs:
		var w: float = sg[1] - sg[0]
		if w > 0.5:
			_add_hedge(body.transform, Vector3((sg[0] + sg[1]) / 2.0, 0.55, z), Vector3(w, 1.1, 0.8), Color(0.24, 0.42, 0.16))


## Vanha punainen traktori pihalla (koriste).
func _old_tractor(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var t := Node3D.new()
	t.position = pos
	t.rotation.y = yaw
	parent.add_child(t)
	load("res://scripts/vehicles.gd").tractor(t, Color(0.66, 0.1, 0.07), "old")


func _build_shop() -> void:
	var c := M.w2(M.SHOP_BUILDING)
	_add_house(c)
	var orange := Color(1.0, 0.42, 0.0)
	var p := Vector3(c.x, 0, c.y)
	B.box(self, Vector3(30, 6, 18), p + Vector3(0, 3, 0), Color(0.95, 0.95, 0.93))
	B.box(self, Vector3(30.4, 1.5, 18.4), p + Vector3(0, 5.3, 0), orange, false)
	B.box(self, Vector3(30.6, 0.2, 18.6), p + Vector3(0, 6.1, 0), Color(0.3, 0.3, 0.3), false)
	B.box(self, Vector3(22, 3.0, 0.2), p + Vector3(-2, 1.8, 9), Color(0.2, 0.32, 0.42), false)
	for x in range(-12, 10, 3):
		B.box(self, Vector3(0.12, 3.0, 0.3), p + Vector3(x + 0.5, 1.8, 9.05), Color(0.8, 0.8, 0.8), false)
	B.box(self, Vector3(3.2, 2.8, 0.25), p + Vector3(11, 1.4, 9.05), Color(0.35, 0.5, 0.55), false)
	B.box(self, Vector3(4.2, 0.25, 2.5), p + Vector3(11, 3.1, 10.2), orange, false)
	# K-logo pyöreässä kyltissä.
	B.mesh(self, B.cyl(1.1, 1.1, 0.2, 24), p + Vector3(-11, 5.3, 9.35), orange.darkened(0.1), Vector3(90, 0, 0))
	B.label(self, "K", p + Vector3(-11, 5.3, 9.5), 200, Color.WHITE)
	B.label(self, "K-Market", p + Vector3(2, 5.3, 9.3), 170, Color.WHITE)
	# Ostoskärrykatos.
	for x in [-16.5, -13.5]:
		B.box(self, Vector3(0.1, 2.2, 0.1), p + Vector3(x, 1.1, 14), Color(0.6, 0.6, 0.6), false)
	B.box(self, Vector3(3.6, 0.1, 2.0), p + Vector3(-15, 2.2, 14.5), orange, false)
	var lot := PackedVector2Array([c + Vector2(-18, 9), c + Vector2(18, 9), c + Vector2(18, 31), c + Vector2(-18, 31)])
	_flat_poly(lot, LAYER.lot, _surf("asphalt"))
	_lots.append(lot)
	for x in range(-14, 16, 4):
		B.box(self, Vector3(0.15, 0.01, 4), p + Vector3(x, LAYER.lot + 0.008, 20), Color(0.9, 0.9, 0.9), false)
	B.parked_car(self, p + Vector3(-13, 0, 20), 0.0, Color(0.1, 0.1, 0.1))
	B.parked_car(self, p + Vector3(9, 0, 20), 0.0, Color(0.6, 0.6, 0.55))
	B.parked_car(self, p + Vector3(13, 0, 20), 0.0, Color(0.8, 0.8, 0.82))
	_build_taxi(p + Vector3(-16.5, 0, 26.5))  # parkkipaikan länsikulmassa, kaupasta kauimpana


## Saloisten rautatieasema K-Marketin takana: keltainen puuasema valkoisine listoineen ja punaisella harjakatolla,
## laiturikatos, SALOINEN-kyltti, betonilaituri penkkeineen ja pistoraide puskimineen (päättyy ennen
## Ketunperäntietä). Ovi kaupan puolella; E: junalla Vaalaan (main.gd _station_logic).
func _build_station() -> void:
	var c := M.w2(M.SHOP_BUILDING)
	var root := Node3D.new()
	root.position = Vector3(c.x - 4.0, 0, c.y - 24.0)
	add_child(root)
	var L := 16.0
	var D := 8.0
	var wall_h := 3.8
	var ochre := Color(0.86, 0.66, 0.3)
	var white := Color(0.95, 0.94, 0.9)
	var roof := Color(0.55, 0.12, 0.08)
	B.box(root, Vector3(L + 0.4, 0.5, D + 0.4), Vector3(0, 0.0, 0), Color(0.55, 0.54, 0.5), false)
	B.box(root, Vector3(L, wall_h, D), Vector3(0, 0.25 + wall_h / 2.0, 0), ochre)
	for cx: float in [-L / 2.0, L / 2.0]:
		for cz: float in [-D / 2.0, D / 2.0]:
			B.box(root, Vector3(0.22, wall_h, 0.22), Vector3(cx, 0.25 + wall_h / 2.0, cz), white, false)
	B.box(root, Vector3(L + 0.1, 0.25, D + 0.1), Vector3(0, 0.25 + wall_h, 0), white, false)
	var pitch := 0.5
	var span := D / 2.0 + 0.8
	var ridge := 0.25 + wall_h + span * tan(pitch) + 0.1
	for sz: float in [-1.0, 1.0]:
		var rl := B.mesh(root, B.boxm(Vector3(L + 1.2, 0.18, span / cos(pitch))), Vector3(0, ridge - span * tan(pitch) / 2.0, sz * span / 2.0), roof)
		rl.rotation.x = sz * pitch
	B.mesh(root, B.boxm(Vector3(L + 1.2, 0.2, 0.3)), Vector3(0, ridge + 0.05, 0), roof.darkened(0.2))
	for gx: float in [-L / 2.0, L / 2.0]:
		var tri := SurfaceTool.new()
		tri.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y0 := 0.25 + wall_h
		for v in [Vector3(gx, y0, -D / 2.0), Vector3(gx, y0, D / 2.0), Vector3(gx, y0 + (D / 2.0) * tan(pitch), 0)]:
			tri.add_vertex(v)
		tri.generate_normals()
		var tm := MeshInstance3D.new()
		tm.mesh = tri.commit()
		var gm := B.mat(ochre).duplicate() as StandardMaterial3D
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		tm.material_override = gm
		root.add_child(tm)
	# Laiturikatos pohjoiseen (radan puolelle) pilareineen.
	var canopy := B.mesh(root, B.boxm(Vector3(L + 0.4, 0.15, 4.4)), Vector3(0, 0.25 + wall_h - 0.25, -D / 2.0 - 2.2), roof)
	canopy.rotation.x = 0.08
	for k in 5:
		B.box(root, Vector3(0.16, wall_h - 0.4, 0.16), Vector3(-L / 2.0 + 1.0 + k * (L - 2.0) / 4.0, 0.25 + (wall_h - 0.4) / 2.0, -D / 2.0 - 3.6), white, false)
	for sz: float in [-1.0, 1.0]:
		for k in 4:
			var wx := -L / 2.0 + 2.0 + k * (L - 4.0) / 3.0
			if sz > 0.0 and k == 1:
				B.box(root, Vector3(1.4, 2.3, 0.08), Vector3(wx, 1.4, D / 2.0 + 0.03), Color(0.45, 0.25, 0.12), false)  # ovi kaupalle päin
				B.box(root, Vector3(1.6, 0.12, 0.1), Vector3(wx, 2.65, D / 2.0 + 0.05), white, false)
				continue
			B.box(root, Vector3(1.15, 1.45, 0.06), Vector3(wx, 2.2, sz * (D / 2.0 + 0.03)), white, false)
			B.box(root, Vector3(0.95, 1.25, 0.07), Vector3(wx, 2.2, sz * (D / 2.0 + 0.04)), Color(0.12, 0.16, 0.2), false)
	for sz: float in [-1.0, 1.0]:
		var sign := B.sign_plate(root, "SALOINEN", Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.1), 0.6, 80, Color(0.1, 0.1, 0.1), "Helvetica Neue")
		sign.position = Vector3(0, 3.5, sz * (D / 2.0 + 0.08))
		sign.rotation.y = 0.0 if sz > 0.0 else PI
	var door_x := -L / 2.0 + 2.0 + (L - 4.0) / 3.0
	station_pos = root.position + Vector3(door_x, 0, D / 2.0 + 1.6)
	station_arrive = root.position + Vector3(door_x + 2.0, 0, D / 2.0 + 2.5)
	_add_house(Vector2(root.position.x, root.position.z))
	# Laituri ja pistoraide pohjoisessa; puut pois koko alueelta.
	var plat := Node3D.new()
	plat.position = root.position + Vector3(-6.0, 0, -D / 2.0 - 5.5)
	add_child(plat)
	B.box(plat, Vector3(46, 0.55, 3.0), Vector3(0, 0.0, 0), Color(0.62, 0.61, 0.58))
	B.box(plat, Vector3(46, 0.02, 0.15), Vector3(0, 0.29, -1.15), white, false)
	for k in 3:
		var bx := -15.0 + k * 15.0
		B.box(plat, Vector3(1.8, 0.08, 0.45), Vector3(bx, 0.72, 0.9), Color(0.45, 0.3, 0.18), false)
		B.box(plat, Vector3(1.8, 0.45, 0.06), Vector3(bx, 0.98, 1.12), Color(0.45, 0.3, 0.18), false)
	var tz := plat.position.z - 3.5
	for k in 14:
		var seg := Node3D.new()
		seg.position = Vector3(c.x - 46.0 + k * 4.4 + 2.2, 0, tz)
		add_child(seg)
		B.box(seg, Vector3(4.4, 0.2, 3.2), Vector3(0, 0.1, 0), Color(0.38, 0.35, 0.32), false)  # sepeli
		for sl in 6:
			B.box(seg, Vector3(0.24, 0.16, 2.4), Vector3(-1.85 + sl * 0.74, 0.25, 0), Color(0.4, 0.38, 0.35), false)
		for rz: float in [-0.72, 0.72]:
			B.box(seg, Vector3(4.4, 0.14, 0.08), Vector3(0, 0.38, rz), Color(0.5, 0.45, 0.4), false)
	for e in 2:
		var bs := Node3D.new()
		bs.position = Vector3(c.x - 46.0 + (1.0 if e == 0 else 14 * 4.4 - 1.0), 0, tz)
		bs.rotation.y = PI / 2.0 if e == 0 else -PI / 2.0
		add_child(bs)
		B.box(bs, Vector3(2.6, 0.5, 0.4), Vector3(0, 1.0, 0), Color(0.8, 0.1, 0.08), false)
		for sx: float in [-0.75, 0.75]:
			B.box(bs, Vector3(0.18, 1.1, 0.18), Vector3(sx, 0.55, 0), Color(0.25, 0.25, 0.25), false)
	var lot := PackedVector2Array([c + Vector2(-50, -12), c + Vector2(16, -12), c + Vector2(16, -40), c + Vector2(-50, -40)])
	_lots.append(lot)


## Taksi odottaa K-Marketin taksitolpalla: kuski ratissa ja radiosta soi tunnusbiisi hiljaa (kuuluu vain lähellä).
func _build_taxi(pos: Vector3) -> void:
	# Taksitolppa reunakivellä taksin keulan vieressä: keltainen TAKSI-kyltti mustalla reunuksella
	# tolpan kyljessä lipun tapaan, osoittaa parkkipaikalle päin.
	var pole := B.sign_pole(self, pos + Vector3(-1.8, 0, -2.4), 2.9)
	var plate := B.sign_plate(pole, "TAKSI", Color(1.0, 0.8, 0.1), Color(0.05, 0.05, 0.05), 0.34, 64,
		Color(0.05, 0.05, 0.05), "Helvetica Neue")
	plate.position = Vector3(plate.get_meta("width") / 2.0 + 0.04, 2.55, 0)
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	body.add_child(B.box_shape(Vector3(1.8, 1.4, 4.2), Vector3(0, 0.8, 0)))
	load("res://scripts/vehicles.gd").taxi(body, "TXI-808")
	var driver := Looks.make(body, Looks.TAXI_DRIVER)
	driver.position = Vector3(-0.4, 0.05, 0.1)
	driver.play("Driving", 0.0)
	taxi_pos = pos
	for f in Sfx.MUSIC_FILES:
		if ResourceLoader.exists(f):
			var st: AudioStream = load(f).duplicate()
			Sfx._set_loop(st)
			var radio := AudioStreamPlayer3D.new()
			radio.stream = st
			radio.bus = "Music"
			radio.volume_db = -14.0
			radio.unit_size = 2.5
			radio.max_distance = 16.0
			radio.position = Vector3(0, 1.0, 0)
			radio.autoplay = true
			body.add_child(radio)
			break


func _build_agility() -> void:
	_flat_poly(_agility, 0.009, _surf("lawn"))
	var c := (_agility[0] + _agility[2]) / 2.0
	var red := Color(0.85, 0.15, 0.1)
	for i in 5:
		var p := Vector3(c.x - 18 + i * 9, 0, c.y + (6 if i % 2 == 0 else -6))
		for dx in [-0.9, 0.9]:
			B.mesh(self, B.cyl(0.05, 0.05, 1.0), p + Vector3(dx, 0.5, 0), Color.WHITE)
		B.mesh(self, B.cyl(0.04, 0.04, 1.8), p + Vector3(0, 0.6, 0), red, Vector3(0, 0, 90))
	var lbl := B.guide(self, "Agilitykenttä", Vector3(c.x, 3.5, c.y), 100, Color(1, 1, 0.8), true)
	lbl.no_depth_test = false


## Laavu Antinsuonkankaalla suomalaiseen tapaan: hirsiseinät kolmella sivulla, avoin etupuoli nuotiolle,
## pulpettikatto (etureuna 2,5 m, takaseinä 1 m, n. 30°) bitumikatteella, koholla oleva lautalattia.
## Pihassa kivikehäinen nuotiopaikka ritilöineen, penkit, puuvaja, huussi ja infotaulu.
func _build_laavu() -> void:
	var c := M.w2(M.LAAVU)
	var pit := Vector3(c.x, 0, c.y)
	_add_house(c)  # puut ja talot pysyvät kaukana
	var log_col := Color(0.52, 0.36, 0.22)
	var log_dark := Color(0.44, 0.3, 0.18)
	var board := Color(0.6, 0.44, 0.28)
	var felt := Color(0.16, 0.16, 0.17)
	var w := 3.4
	var d := 2.7
	var hf := 2.5
	var hb := 1.0
	# Katos nuotion eteläpuolella; paikallinen -Z = avoin etupuoli.
	var shelter := StaticBody3D.new()
	shelter.position = pit + Vector3(0, 0, 3.3)
	add_child(shelter)
	shelter.add_child(B.box_shape(Vector3(w + 0.3, 2.0, d), Vector3(0, 1.0, 0.25)))
	var roof_y := func(z: float) -> float: return hf - (z + d / 2.0) / d * (hf - hb)
	# Takaseinä: vaakahirret.
	var r := 0.11
	var y := r
	while y < hb - 0.05:
		B.mesh(shelter, B.cyl(r, r, w + 0.3, 10), Vector3(0, y, d / 2.0), log_col if int(y * 10) % 2 else log_dark, Vector3(0, 0, 90))
		y += 2.0 * r * 0.95
	# Sivuseinät: kolmiot katon linjaa myöten, ylähirret lyhyempiä ja etupainotteisia.
	for sx in [-w / 2.0, w / 2.0]:
		y = r
		while y < hf - 0.15:
			var z_lim: float = minf(d / 2.0, (hf - y - 0.12) / (hf - hb) * d - d / 2.0)
			var l: float = z_lim + d / 2.0
			if l > 0.25:
				B.mesh(shelter, B.cyl(r, r, l, 10), Vector3(sx, y, -d / 2.0 + l / 2.0), log_col if int(y * 10) % 2 else log_dark, Vector3(90, 0, 0))
			y += 2.0 * r * 0.95
		B.mesh(shelter, B.cyl(0.13, 0.13, hf, 10), Vector3(sx, hf / 2.0, -d / 2.0), log_dark)
	# Pulpettikatto: kattotuolit, laudoitus ja bitumikate räystäineen.
	var ang := atan((hf - hb) / d)
	var slope := d / cos(ang) + 0.8
	for x in [-1.5, -0.5, 0.5, 1.5]:
		var raft := B.mesh(shelter, B.boxm(Vector3(0.08, 0.14, slope)), Vector3(x, roof_y.call(0.0) + 0.02, 0), board.darkened(0.2))
		raft.rotation.x = ang
	var deck := B.mesh(shelter, B.boxm(Vector3(w + 0.8, 0.05, slope)), Vector3(0, roof_y.call(0.0) + 0.12, 0), board)
	deck.rotation.x = ang
	var roof := B.mesh(shelter, B.boxm(Vector3(w + 0.9, 0.03, slope + 0.05)), Vector3(0, roof_y.call(0.0) + 0.16, 0), felt)
	roof.rotation.x = ang
	var fascia := B.mesh(shelter, B.boxm(Vector3(w + 0.9, 0.18, 0.04)), Vector3(0, hf + 0.2, -d / 2.0 - 0.4), board.darkened(0.3))
	fascia.rotation.x = ang
	# Lautalattia koholla, kynnyshirsi edessä.
	for i in 5:
		B.mesh(shelter, B.boxm(Vector3(0.12, 0.3, d - 0.2)), Vector3(-1.4 + i * 0.7, 0.15, 0.05), log_dark)
	for i in 10:
		B.mesh(shelter, B.boxm(Vector3(w - 0.1, 0.04, 0.24)), Vector3(0, 0.42, -1.1 + i * 0.25), board.lightened(0.05 * (i % 2)))
	B.mesh(shelter, B.cyl(0.14, 0.14, w, 10), Vector3(0, 0.3, -d / 2.0 + 0.05), log_col, Vector3(0, 0, 90))

	# Nuotiopaikka: kivikehä, hiillos, halot ja grilliritilä jaloillaan.
	for k in 12:
		var a := TAU * k / 12.0
		var stone := B.mesh(self, B.sphere(0.17, 8), pit + Vector3(cos(a) * 0.8, 0.09, sin(a) * 0.8), Color(0.45, 0.45, 0.44).darkened(randf() * 0.15))
		stone.scale = Vector3(1.0, 0.7, 1.0)
	B.mesh(self, B.cyl(0.66, 0.66, 0.04, 16), pit + Vector3(0, 0.03, 0), Color(0.08, 0.07, 0.07))
	for k in 3:
		var fl := B.mesh(self, B.cyl(0.07, 0.07, 0.9, 6), pit + Vector3(0, 0.15, 0), log_dark)
		fl.rotation = Vector3(PI / 2.0, TAU * k / 3.0, 0.35)
	for x in [-0.45, 0.45]:
		for z in [-0.35, 0.35]:
			B.mesh(self, B.boxm(Vector3(0.03, 0.5, 0.03)), pit + Vector3(x, 0.25, z), Color(0.12, 0.12, 0.12))
	for i in 8:
		B.mesh(self, B.boxm(Vector3(0.95, 0.015, 0.015)), pit + Vector3(0, 0.5, -0.35 + i * 0.1), Color(0.15, 0.15, 0.15))
	# Penkit: lankku kahden kannon päällä nuotion ympärillä.
	for bdef in [[Vector3(-2.3, 0, 0), PI / 2.0], [Vector3(2.3, 0, 0), PI / 2.0], [Vector3(0, 0, -2.3), 0.0]]:
		var bench := StaticBody3D.new()
		bench.position = pit + bdef[0]
		bench.rotation.y = bdef[1]
		add_child(bench)
		bench.add_child(B.box_shape(Vector3(2.0, 0.45, 0.4), Vector3(0, 0.22, 0)))
		B.mesh(bench, B.boxm(Vector3(2.0, 0.08, 0.36)), Vector3(0, 0.45, 0), board)
		for sx in [-0.7, 0.7]:
			B.mesh(bench, B.cyl(0.16, 0.18, 0.42, 10), Vector3(sx, 0.21, 0), log_col)
	# Puuvaja halkoineen.
	var shed := StaticBody3D.new()
	shed.position = pit + Vector3(4.6, 0, 2.8)
	shed.rotation.y = -0.4
	add_child(shed)
	shed.add_child(B.box_shape(Vector3(1.8, 1.9, 1.3), Vector3(0, 0.95, 0)))
	for side in [-0.9, 0.9]:
		B.mesh(shed, B.boxm(Vector3(0.05, 1.8, 1.3)), Vector3(side, 0.9, 0), board.darkened(0.1))
	B.mesh(shed, B.boxm(Vector3(1.8, 1.5, 0.05)), Vector3(0, 0.75, 0.62), board.darkened(0.1))
	var sroof := B.mesh(shed, B.boxm(Vector3(2.1, 0.05, 1.7)), Vector3(0, 1.85, 0), felt)
	sroof.rotation.x = 0.25
	for i in 30:
		B.mesh(shed, B.cyl(0.07, 0.07, 0.4, 6), Vector3(-0.75 + (i % 10) * 0.16, 0.12 + floorf(i / 10.0) * 0.15, 0.2),
			Color(0.62, 0.46, 0.3).darkened(randf() * 0.2), Vector3(90, 0, 0))
	# Huussi, oven ikkunassa sydän.
	var outhouse := StaticBody3D.new()
	outhouse.position = pit + Vector3(-8.0, 0, 6.0)
	outhouse.rotation.y = 0.5
	add_child(outhouse)
	outhouse.add_child(B.box_shape(Vector3(1.2, 2.2, 1.2), Vector3(0, 1.1, 0)))
	B.mesh(outhouse, B.boxm(Vector3(1.2, 2.1, 1.2)), Vector3(0, 1.05, 0), Color(0.55, 0.18, 0.12))
	var oroof := B.mesh(outhouse, B.boxm(Vector3(1.5, 0.05, 1.5)), Vector3(0, 2.2, 0), felt)
	oroof.rotation.x = 0.2
	B.mesh(outhouse, B.boxm(Vector3(0.75, 1.8, 0.04)), Vector3(0, 0.95, -0.61), Color(0.62, 0.22, 0.15))
	for hx in [-0.045, 0.045]:
		B.mesh(outhouse, B.sphere(0.055, 8), Vector3(hx, 1.58, -0.64), Color(0.05, 0.03, 0.02))
	var heart_tip := PrismMesh.new()
	heart_tip.size = Vector3(0.2, 0.12, 0.02)
	B.mesh(outhouse, heart_tip, Vector3(0, 1.5, -0.64), Color(0.05, 0.03, 0.02), Vector3(0, 0, 180))
	# Infotaulu katoksella: tolpat ja katos mitoitetaan otsikon leveyden mukaan.
	var info := Node3D.new()
	info.position = pit + Vector3(3.6, 0, -3.2)
	info.rotation.y = 0.45
	add_child(info)
	var brown := Color(0.4, 0.22, 0.1)
	var cream := Color(0.98, 0.95, 0.88)
	var ip := B.sign_plate(info, "TARPION\nLAAVU", brown, cream, 0.22, 40, Color(0.3, 0.17, 0.08), "Helvetica Neue")
	ip.position.y = 1.75
	var note := B.sign_plate(info, "Kaikenlaisten roskien tuonti\nkielletty edesvastuun uhalla", brown, Color(0.95, 0.85, 0.5), 0.13, 26,
		Color(0.3, 0.17, 0.08), "Helvetica Neue")
	note.position.y = 1.2
	var bw: float = maxf(ip.get_meta("width"), note.get_meta("width"))
	for sx in [-bw / 2.0 - 0.06, bw / 2.0 + 0.06]:
		B.mesh(info, B.boxm(Vector3(0.1, 2.2, 0.1)), Vector3(sx, 1.1, -0.06), log_dark)
	var iroof := PrismMesh.new()
	iroof.size = Vector3(bw + 0.6, 0.32, 0.55)
	B.mesh(info, iroof, Vector3(0, 2.36, 0), felt)
	var icon_board := B.mesh(info, B.boxm(Vector3(0.42, 0.38, 0.03)), Vector3(0, 0.78, 0), brown)
	icon_board.name = "IconBoard"
	for z in [0.02, -0.02]:
		B.laavu_icon(info, Vector3(0, 0.78, z), 0.28, cream)

	# Nuotio: liekit, loimu ja savu. Piilossa kunnes sytytetään.
	fire = Node3D.new()
	fire.position = pit
	fire.visible = false
	add_child(fire)
	for k in 5:
		var fl := MeshInstance3D.new()
		fl.mesh = B.cyl(0.0, 0.18 - k * 0.02, 0.6 + k * 0.08, 6)
		fl.material_override = B.unshaded(Color(1.6, 0.6 + k * 0.1, 0.1))
		fl.position = Vector3(cos(k * 1.3) * 0.15, 0.35 + k * 0.03, sin(k * 1.3) * 0.15)
		fl.name = "Flame%d" % k
		fire.add_child(fl)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.2)
	glow.light_energy = 2.5
	glow.omni_range = 9.0
	glow.position.y = 0.8
	glow.name = "Glow"
	fire.add_child(glow)
	var smoke := CPUParticles3D.new()
	smoke.amount = 30
	smoke.lifetime = 3.0
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.2
	smoke.gravity = Vector3(0.3, 0.2, 0)
	smoke.scale_amount_min = 0.4
	smoke.scale_amount_max = 1.4
	smoke.position.y = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	sm.material = B.unshaded(Color(0.6, 0.6, 0.62, 0.25))
	smoke.mesh = sm
	fire.add_child(smoke)


## Haapajärven tekoaltaan kota lintutorneineen (kota.gd); ovi kohti saapuvaa polkua.
func _build_kota() -> void:
	var c := M.w2(M.KOTA)
	kota = Kota.new()
	kota.position = Vector3(c.x, 0, c.y)
	# Käännetään niin, että mallin lintutorni osuu OSM:n tornin kohdalle (niemen kärki).
	var tw := M.w2(M.LINTUTORNI) - c
	kota.rotation.y = atan2(Kota.TOWER_LOCAL.z, Kota.TOWER_LOCAL.x) - atan2(tw.y, tw.x)
	add_child(kota)
	# Puut ja talot pysyvät poissa kodan, halkovajan ja lintutornin kohdalta.
	for lp in [Vector3.ZERO, Kota.SAW_LOCAL, Kota.CHOP_LOCAL + Vector3(-1, 0, 0), Vector3(-6.5, 0, 4.2), Kota.TOWER_LOCAL,
			Kota.TOWER_LOCAL + Vector3(0, 0, -6)]:
		var g: Vector3 = kota.transform * (lp as Vector3)
		_add_house(Vector2(g.x, g.z))


## Kiilinlammen grillikatos: kuusikulmainen puukatos, keskellä grilli savuhormeineen, penkit ympärillä.
## Pannu-Sulon pontikkapannu metsässä: kuparipannu kivien päällä tulella, kiemurainen putki
## jäähdytystynnyriin, sankoon tippuva tisle, kanistereita, sokerisäkkejä ja pressukatos.
func _build_pontikka() -> void:
	var root := StaticBody3D.new()
	var c := M.w2(M.PONTIKKA)
	root.position = Vector3(c.x, 0, c.y)
	root.rotation.y = 0.4
	add_child(root)
	var copper := Color(0.72, 0.4, 0.2)
	var stone := Color(0.45, 0.44, 0.42)
	for k in 7:
		var a := TAU * k / 7.0
		B.mesh(root, B.sphere(0.13, 8), Vector3(cos(a) * 0.42, 0.1, sin(a) * 0.42), stone.lightened(randf_range(-0.1, 0.1)))
	var glow := B.unshaded(Color(1.0, 0.45, 0.08))
	for k in 3:
		var f := MeshInstance3D.new()
		f.mesh = B.boxm(Vector3(0.28, 0.16, 0.06))
		f.material_override = glow
		f.position = Vector3(0, 0.18, 0)
		f.rotation.y = k * PI / 3.0
		root.add_child(f)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 0.8
	light.omni_range = 4.0
	light.position = Vector3(0, 0.4, 0)
	root.add_child(light)
	B.mesh(root, B.cyl(0.34, 0.34, 0.55, 16), Vector3(0, 0.6, 0), copper)
	var dome := B.mesh(root, B.sphere(0.34, 16), Vector3(0, 0.88, 0), copper)
	dome.scale = Vector3(1.0, 0.5, 1.0)
	B.mesh(root, B.cyl(0.06, 0.1, 0.25, 10), Vector3(0, 1.1, 0), copper)
	# Putki kierukaksi jäähdytystynnyriin ja tisle sankoon.
	B.tube(root, Vector3(0, 1.2, 0), Vector3(0.6, 1.3, 0), 0.025, copper)
	B.tube(root, Vector3(0.6, 1.3, 0), Vector3(1.35, 1.0, 0), 0.025, copper)
	B.mesh(root, B.cyl(0.3, 0.3, 0.9, 14), Vector3(1.45, 0.45, 0), Color(0.15, 0.3, 0.6))
	B.tube(root, Vector3(1.7, 0.2, 0), Vector3(1.95, 0.18, 0.1), 0.015, copper)
	B.mesh(root, B.cyl(0.14, 0.11, 0.22, 10), Vector3(2.0, 0.11, 0.15), Color(0.7, 0.72, 0.74))
	# Kanisterit ja sokerisäkit.
	for k in 4:
		var can := B.mesh(root, B.boxm(Vector3(0.18, 0.34, 0.28)), Vector3(-1.1 - k * 0.25, 0.17, 0.9), Color(0.92, 0.92, 0.88))
		can.rotation.y = randf_range(-0.2, 0.2)
		B.mesh(can, B.boxm(Vector3(0.04, 0.06, 0.14)), Vector3(0, 0.2, 0), Color(0.85, 0.15, 0.1))
	for k in 3:
		B.mesh(root, B.boxm(Vector3(0.45, 0.2, 0.3)), Vector3(-1.6, 0.1 + k * 0.2, -0.6), Color(0.93, 0.92, 0.86))
	# Pressukatos istumapaikan yllä ja jakkarana pölkky.
	for x in [-2.6, -0.8]:
		B.mesh(root, B.cyl(0.04, 0.05, 2.1, 6), Vector3(x, 1.05, -1.6), Color(0.35, 0.26, 0.17))
	var tarp := B.mesh(root, B.boxm(Vector3(2.4, 0.02, 2.0)), Vector3(-1.7, 1.75, -0.9), Color(0.22, 0.38, 0.22))
	tarp.rotation.x = -0.45
	B.mesh(root, B.cyl(0.2, 0.22, 0.45, 10), Vector3(-1.2, 0.22, -1.5), Color(0.5, 0.38, 0.25))
	root.add_child(B.box_shape(Vector3(0.8, 1.2, 0.8), Vector3(0, 0.6, 0)))
	root.add_child(B.box_shape(Vector3(0.6, 0.9, 0.6), Vector3(1.45, 0.45, 0)))
	Sfx.loop_on(root, "fire", -14.0)


func _build_grillikatos() -> void:
	var c := M.w2(M.GRILLIKATOS)
	var p := Vector3(c.x, 0, c.y)
	_add_house(c)
	var wood := Color(0.52, 0.36, 0.22)
	var dark := Color(0.35, 0.24, 0.14)
	var felt := Color(0.16, 0.16, 0.17)
	var body := StaticBody3D.new()
	body.position = p
	add_child(body)
	var r := 2.8
	for k in 6:
		var a := TAU * k / 6.0
		var pp := Vector3(cos(a) * r, 0, sin(a) * r)
		B.mesh(body, B.cyl(0.11, 0.12, 2.4, 8), pp + Vector3(0, 1.2, 0), dark)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.12
		sh.height = 2.4
		cs.shape = sh
		cs.position = pp + Vector3(0, 1.2, 0)
		body.add_child(cs)
		# Kaiteet ja penkki jokaiselle sivulle paitsi sisäänkäynti.
		var a2 := TAU * (k + 1) / 6.0
		var q := Vector3(cos(a2) * r, 0, sin(a2) * r)
		if k != 0:
			for y in [0.45, 0.9]:
				B.tube(body, pp + Vector3(0, y, 0), q + Vector3(0, y, 0), 0.05, wood)
			var mid := (pp + q) * 0.5 * 0.82
			var bench := B.mesh(body, B.boxm(Vector3(2.2, 0.06, 0.38)), mid + Vector3(0, 0.45, 0), wood)
			bench.rotation.y = -((a + a2) * 0.5) + PI / 2.0
	# Kuusikulmainen katto: kartio + räystäs.
	B.mesh(body, B.cyl(0.25, r + 0.6, 1.3, 6), Vector3(0, 3.0, 0), felt)
	B.mesh(body, B.cyl(r + 0.62, r + 0.62, 0.12, 6), Vector3(0, 2.38, 0), wood)
	# Grilli ja hormi.
	B.mesh(body, B.cyl(0.55, 0.6, 0.8, 12), Vector3(0, 0.4, 0), Color(0.18, 0.18, 0.19))
	B.mesh(body, B.cyl(0.62, 0.62, 0.05, 16), Vector3(0, 0.82, 0), Color(0.3, 0.3, 0.32))
	B.mesh(body, B.cyl(0.15, 0.15, 3.2, 10), Vector3(0, 2.4, 0), Color(0.15, 0.15, 0.16))
	B.mesh(body, B.cyl(0.25, 0.22, 0.12, 10), Vector3(0, 4.05, 0), Color(0.15, 0.15, 0.16))
	body.add_child(B.box_shape(Vector3(1.2, 0.9, 1.2), Vector3(0, 0.45, 0)))
	var lbl := B.guide(self, "KIILINLAMMEN\nGRILLIKATOS", p + Vector3(0, 4.6, 0), 60, Color(1, 0.95, 0.8), true)
	lbl.no_depth_test = false
	lbl.outline_modulate = Color(0.1, 0.3, 0.1)
	# Soratie kentälle.
	_flat_poly(PackedVector2Array([c + Vector2(-4.5, -4.5), c + Vector2(4.5, -4.5), c + Vector2(4.5, 4.5), c + Vector2(-4.5, 4.5)]),
		LAYER.path, _surf("gravel"))


## Valkoiset säilörehupaalit pellon laidalla.
func _build_bales() -> void:
	for p in M.BALES:
		var c := M.w2(p)
		var body := StaticBody3D.new()
		body.position = Vector3(c.x, 0.65, c.y)
		body.rotation.y = _rng.randf() * TAU
		add_child(body)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.65
		sh.height = 1.2
		cs.shape = sh
		cs.rotation.z = PI / 2.0
		body.add_child(cs)
		B.mesh(body, B.cyl(0.65, 0.65, 1.2, 18), Vector3.ZERO, Color(0.95, 0.95, 0.93), Vector3(0, 0, 90))
		_add_house(c)


func _process_fire() -> void:
	if fire == null or not fire.visible:
		return
	var t := Time.get_ticks_msec() * 0.001
	for k in 5:
		var fl: Node3D = fire.get_node("Flame%d" % k)
		fl.scale = Vector3(1.0, 0.8 + 0.35 * absf(sin(t * (5.0 + k) + k)), 1.0)
	(fire.get_node("Glow") as OmniLight3D).light_energy = 2.2 + 0.6 * sin(t * 13.0) * sin(t * 7.3)


# --- Puut --------------------------------------------------------------------

func _scatter_trees() -> void:
	for poly in _forests:
		var lo := Vector2(INF, INF)
		var hi := -lo
		for p in poly:
			lo = lo.min(p)
			hi = hi.max(p)
		# Iso etelän metsä harvemmalla ruudukolla, ettei puita tule kymmeniätuhansia.
		var step := 12.0 if (hi.x - lo.x) * (hi.y - lo.y) > 800000.0 else 9.0
		var y := lo.y
		while y < hi.y:
			var x := lo.x
			while x < hi.x:
				var p := Vector2(x, y) + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
				if Geometry2D.is_point_in_polygon(p, poly) and not _in_any(p, _fields) and not _in_any(p, _clearings) \
						and not _in_any(p, _bogs) and not _in_any(p, _clearcuts) and not _in_any(p, _water):
					var r := _rng.randf()
					_try_tree(p, "pine" if r < 0.5 else ("spruce" if r < 0.8 else "birch"), _rng.randf_range(0.8, 1.35), 3.5)
				x += step
			y += step
	# Harvat puut niityillä.
	var lo2 := M.w2(Vector2.ZERO)
	var hi2 := M.w2(M.SIZE)
	var y2 := lo2.y
	while y2 < hi2.y:
		var x2 := lo2.x
		while x2 < hi2.x:
			var p := Vector2(x2, y2) + Vector2(_rng.randf_range(-15, 15), _rng.randf_range(-15, 15))
			if _rng.randf() < 0.3 and not _in_any(p, _forests) and not _in_any(p, _fields):
				var r2 := _rng.randf()
				_try_tree(p, "birch" if r2 < 0.5 else ("pine" if r2 < 0.75 else "spruce"), _rng.randf_range(0.7, 1.2), 5.0)
			x2 += 40.0
		y2 += 40.0
	# Rämeen pienet männyt.
	for poly in _bogs:
		for k in 50:
			var p := poly[0].lerp(poly[2], _rng.randf()) + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-20, 20))
			if Geometry2D.is_point_in_polygon(p, poly):
				_try_tree(p, "pine", _rng.randf_range(0.3, 0.55), 3.0)
	# Metsäraja kartan ulkopuolelle, ettei maailma lopu tyhjään.
	var y3 := lo2.y - 90.0
	while y3 < hi2.y + 90.0:
		var x3 := lo2.x - 90.0
		while x3 < hi2.x + 90.0:
			var p := Vector2(x3, y3) + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
			if not _in_bounds(p, -3.0) and _play_edge_dist(p) < 90.0 and not _in_any(p, _water):
				_trees.append([p, "spruce" if _rng.randf() < 0.65 else "birch", _rng.randf_range(0.9, 1.5), false])
			x3 += 10.0
		y3 += 10.0


func _try_tree(p: Vector2, kind: String, s: float, road_gap: float) -> void:
	if not _in_bounds(p, 3.0) or _road_clearance(p) < road_gap or _in_any(p, _water) or _near_house(p, 9.0):
		return
	if Geometry2D.is_point_in_polygon(p, _agility):
		return
	_trees.append([p, kind, s, true])


## Puut MultiMesheinä ruuduittain (näkymän rajaus toimii) + törmäyssylinterit.
func _build_trees() -> void:
	var chunks := {}
	for t in _trees:
		var key := Vector2i(floori(t[0].x / CHUNK), floori(t[0].y / CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(t)

	var foliage := B.shader_mat("res://shaders/foliage.gdshader")
	var bark := B.shader_mat("res://shaders/bark.gdshader")
	var wood := B.vcol_mat()
	var leaf := Color(0.36, 0.58, 0.22)
	var needle := Color(0.12, 0.28, 0.15)
	# Lähipuiden lehvästö korteista (kaksi muunnelmaa lajia kohden), kaukana kevyet perusmuodot.
	var card := func(tex: Texture2D, sway: float) -> ShaderMaterial:
		return B.shader_mat("res://shaders/foliage_card.gdshader", {"leaf_tex": tex, "sway": sway})
	var leaf_mat: ShaderMaterial = card.call(Foliage.leaf_texture(), 0.08)
	var spruce_mat: ShaderMaterial = card.call(Foliage.spruce_texture(), 0.04)
	var pine_mat: ShaderMaterial = card.call(Foliage.pine_texture(), 0.05)
	var near_parts := {
		"birch": [[[Foliage.birch_crown(1), Vector3.ZERO, Color(0.42, 0.62, 0.26), leaf_mat]],
			[[Foliage.birch_crown(2), Vector3.ZERO, Color(0.4, 0.6, 0.25), leaf_mat]]],
		"pine": [[[Foliage.pine_crown(3), Vector3.ZERO, Color(0.3, 0.45, 0.22), pine_mat]],
			[[Foliage.pine_crown(4), Vector3.ZERO, Color(0.28, 0.43, 0.2), pine_mat]]],
		"spruce": [[[Foliage.spruce_crown(5), Vector3.ZERO, Color(0.22, 0.38, 0.2), spruce_mat],
				[B.cyl(0.0, 1.3, 7.6, 7), Vector3(0, 4.6, 0), Color(0.06, 0.14, 0.07), foliage]],
			[[Foliage.spruce_crown(6), Vector3.ZERO, Color(0.2, 0.36, 0.19), spruce_mat],
				[B.cyl(0.0, 1.3, 7.6, 7), Vector3(0, 4.6, 0), Color(0.06, 0.14, 0.07), foliage]]],
	}
	# [mesh, paikka, väri, materiaali] (runko näkyy aina, latvus vain kaukana)
	var parts := {
		"birch": [
			[B.cyl(0.11, 0.2, 6.0, 7), Vector3(0, 3.0, 0), Color.WHITE, bark],
			[B.sphere(1.6, 8), Vector3(0, 5.9, 0), leaf, foliage],
			[B.sphere(1.3, 8), Vector3(0.9, 5.1, 0.35), leaf, foliage],
			[B.sphere(1.25, 8), Vector3(-0.75, 6.7, -0.35), leaf.lightened(0.05), foliage],
		],
		"pine": [
			[B.cyl(0.13, 0.22, 5.0, 7), Vector3(0, 2.5, 0), Color(0.42, 0.32, 0.24), wood],
			[B.cyl(0.09, 0.13, 4.5, 7), Vector3(0, 7.2, 0), Color(0.72, 0.42, 0.24), wood],
			[_flat_sphere(1.7, 0.9), Vector3(0.2, 9.1, 0), Color(0.16, 0.32, 0.15), foliage],
			[_flat_sphere(1.3, 0.8), Vector3(-0.8, 8.3, 0.4), Color(0.18, 0.34, 0.16), foliage],
			[_flat_sphere(1.2, 0.7), Vector3(0.7, 8.0, -0.6), Color(0.15, 0.3, 0.14), foliage],
			[_flat_sphere(0.9, 0.6), Vector3(0, 9.9, 0.2), Color(0.17, 0.33, 0.15), foliage],
		],
		"spruce": [
			[B.cyl(0.15, 0.24, 2.2, 6), Vector3(0, 1.1, 0), Color(0.33, 0.24, 0.16), wood],
			[B.cyl(0.0, 2.1, 3.4, 8), Vector3(0, 2.9, 0), needle, foliage],
			[B.cyl(0.0, 1.65, 3.0, 8), Vector3(0, 4.6, 0), needle, foliage],
			[B.cyl(0.0, 1.15, 2.6, 8), Vector3(0, 6.2, 0), needle, foliage],
			[B.cyl(0.0, 0.6, 1.8, 7), Vector3(0, 7.6, 0), needle, foliage],
		],
	}

	# Rungot yhteen kappaleeseen, joka lisätään maailmaan vasta lopuksi: muotojen lisääminen
	# fysiikkamaailmassa olevaan kappaleeseen rakentaisi sen joka kerta uudelleen (hidas).
	var colliders := StaticBody3D.new()
	colliders.set_meta("draped", true)
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 4.0

	for key in chunks:
		var list: Array = chunks[key]
		for kind in parts:
			var mine := list.filter(func(t: Array) -> bool: return t[1] == kind)
			if mine.is_empty():
				continue
			var xforms: Array[Transform3D] = []
			var tints: Array[float] = []
			for t in mine:
				var s: float = t[2]
				var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.15), s))
				xforms.append(Transform3D(basis, Vector3(t[0].x, 0, t[0].y)))
				tints.append(_rng.randf_range(-0.12, 0.12))
			# Lähilatvukset: puut jaetaan kahteen muunnelmaan.
			for v in 2:
				var idx: Array[int] = []
				for i in mine.size():
					if i % 2 == v:
						idx.append(i)
				if idx.is_empty():
					continue
				for part in near_parts[kind][v]:
					var mmn := MultiMesh.new()
					mmn.transform_format = MultiMesh.TRANSFORM_3D
					mmn.use_colors = true
					mmn.mesh = part[0]
					mmn.instance_count = idx.size()
					for j in idx.size():
						var xf := xforms[idx[j]]
						mmn.set_instance_transform(j, Transform3D(xf.basis, xf.origin + xf.basis * part[1]))
						var base_n: Color = part[2]
						var tn: float = tints[idx[j]]
						mmn.set_instance_color(j, base_n.lightened(tn) if tn > 0.0 else base_n.darkened(-tn))
					var near_mmi := MultiMeshInstance3D.new()
					near_mmi.multimesh = mmn
					near_mmi.material_override = part[3]
					near_mmi.visibility_range_end = TREE_NEAR
					near_mmi.visibility_range_end_margin = 15.0
					near_mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
					add_child(near_mmi)
					_near_trees.append(near_mmi)
			for part in parts[kind]:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_colors = true
				mm.mesh = part[0]
				mm.instance_count = mine.size()
				for i in mine.size():
					var xf := xforms[i]
					mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin + xf.basis * part[1]))
					var base: Color = part[2]
					mm.set_instance_color(i, base.lightened(tints[i]) if tints[i] > 0.0 else base.darkened(-tints[i]))
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.material_override = part[3]
				if part[3] != bark and part[3] != wood:
					mmi.visibility_range_begin = TREE_NEAR - 10.0  # perusmuotoinen latvus vain kaukana
					mmi.visibility_range_begin_margin = 15.0
					mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
					_far_trees.append(mmi)
				add_child(mmi)
	for t in _trees:
		if not t[3]:
			continue
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(t[0].x, 2.0 + T.h(t[0].x, t[0].y), t[0].y)
		colliders.add_child(cs)
	add_child(colliders)


# --- Metsän antimet -----------------------------------------------------------

func _build_forage() -> void:
	var laavu := M.w2(M.LAAVU)
	var spots: Array[Vector2] = []
	var kinds: Array[String] = []
	# Arton vinkki: Antinsuonkankaalla laavun lähellä on hyvä puolukkapaikka.
	var tries := 0
	while spots.size() < 3 and tries < 400:
		tries += 1
		var p := laavu + Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-60, 60))
		if _forage_ok(p, spots) and p.distance_to(laavu) > 12.0:
			spots.append(p)
			kinds.append("puolukka")
	tries = 0
	while spots.size() < 30 and tries < 6000:
		tries += 1
		var poly: PackedVector2Array = _forests[_rng.randi() % _forests.size()]
		var lo := Vector2(INF, INF)
		var hi := -lo
		for q in poly:
			lo = lo.min(q)
			hi = hi.max(q)
		var p := Vector2(_rng.randf_range(lo.x, hi.x), _rng.randf_range(lo.y, hi.y))
		if Geometry2D.is_point_in_polygon(p, poly) and _forage_ok(p, spots):
			spots.append(p)
			var r := _rng.randf()
			var acc := 0.0
			var pick := "puolukka"
			for k in FORAGE_KINDS:
				acc += FORAGE_KINDS[k].weight
				if r <= acc:
					pick = k
					break
			kinds.append(pick)
	for i in spots.size():
		var pos := Vector3(spots[i].x, 0, spots[i].y)
		forage.append({"pos": pos, "kind": kinds[i], "node": _forage_visual(kinds[i], pos), "taken": false})


func _forage_ok(p: Vector2, others: Array[Vector2]) -> bool:
	if not _in_bounds(p, 10.0) or _road_clearance(p) < 5.0 or _near_house(p, 18.0):
		return false
	if _in_any(p, _water) or _in_any(p, _fields) or _in_any(p, _bogs) or _near_stream(p):
		return false
	for o in others:
		if o.distance_to(p) < 35.0:
			return false
	return true


## Mättäs varpuineen ja marjoineen tai ryhmä sieniä.
func _forage_visual(kind: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var col: Color = FORAGE_KINDS[kind].color
	if kind in ["puolukka", "mustikka"]:
		var leaf := Color(0.18, 0.4, 0.16) if kind == "puolukka" else Color(0.25, 0.45, 0.2)
		for k in 7:
			var bp := Vector3(_rng.randf_range(-1.2, 1.2), 0.1, _rng.randf_range(-1.2, 1.2))
			var bush := B.mesh(root, B.sphere(0.3, 8), bp, leaf.lightened(_rng.randf_range(-0.05, 0.1)))
			bush.scale = Vector3(1.0, 0.5, 1.0)
			for b in 5:
				B.mesh(root, B.sphere(0.035, 6), bp + Vector3(_rng.randf_range(-0.22, 0.22), 0.12, _rng.randf_range(-0.22, 0.22)), col)
	else:
		for k in 6:
			var mp := Vector3(_rng.randf_range(-0.9, 0.9), 0, _rng.randf_range(-0.9, 0.9))
			var sz := _rng.randf_range(0.8, 1.3)
			if kind == "kantarelli":
				B.mesh(root, B.cyl(0.02 * sz, 0.012 * sz, 0.06 * sz, 6), mp + Vector3(0, 0.03 * sz, 0), col.darkened(0.1))
				B.mesh(root, B.cyl(0.07 * sz, 0.02 * sz, 0.05 * sz, 10), mp + Vector3(0, 0.08 * sz, 0), col)
			else:
				B.mesh(root, B.cyl(0.035 * sz, 0.045 * sz, 0.1 * sz, 8), mp + Vector3(0, 0.05 * sz, 0), Color(0.9, 0.86, 0.75))
				var cap := B.mesh(root, B.sphere(0.08 * sz, 10), mp + Vector3(0, 0.11 * sz, 0), col)
				cap.scale = Vector3(1.0, 0.6, 1.0)
	return root


## Lähin poimimaton paikka ja etäisyys siihen.
func nearest_forage(p: Vector3) -> Array:
	var best: Dictionary = {}
	var bd := INF
	for f in forage:
		if f.taken:
			continue
		var d: float = Vector2(f.pos.x - p.x, f.pos.z - p.z).length()
		if d < bd:
			bd = d
			best = f
	return [best, bd]


func _flat_sphere(r: float, h: float) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = h * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	return sm


## Kadun reunaan leikattu nurmikaista (katunäkymän mukaan ei sorapiennarta).
func _build_verges() -> void:
	var st := _new_st()
	for r in M.ROADS:
		if r.type == "street":
			_strip(st, _poly(r.pts), STYLES.street.w / 2.0 + 2.2, 0.01)
	_commit_strip(st, _surf("lawn"))


## Katuvalot kadun varteen n. 45 m välein.
func _build_streetlights() -> void:
	var grey := Color(0.55, 0.56, 0.58)
	for r in M.ROADS:
		if r.type != "street" and not (r.type == "road" and r.h > 0.0):
			continue
		var pts := _poly(r.pts)
		var hw: float = STYLES[r.type].w / 2.0
		var acc := 20.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var dir := (b - a).normalized()
			var seg := a.distance_to(b)
			var t := acc
			while t < seg:
				var p := a + dir * t + dir.orthogonal() * (hw + 1.4)
				if _free_spot(p, 0.8, 5.0) and _near_house(p, 45.0):  # vain rakennetulla alueella
					var batch := _batch_at(p)
					var base := Vector3(p.x, 0, p.y)
					var arm_dir := Vector3(-dir.orthogonal().x, 0, -dir.orthogonal().y)
					batch.add(B.cyl(0.06, 0.09, 6.5, 8), Transform3D(Basis(), base + Vector3(0, 3.25, 0)), grey)
					var arm_xf := Transform3D(Basis(Vector3.UP, atan2(arm_dir.x, arm_dir.z)), base + Vector3(0, 6.4, 0) + arm_dir * 0.7)
					batch.add(B.boxm(Vector3(0.08, 0.08, 1.4)), arm_xf, grey)
					batch.add(B.boxm(Vector3(0.28, 0.12, 0.55)), Transform3D(arm_xf.basis, base + Vector3(0, 6.35, 0) + arm_dir * 1.35),
						Color(0.35, 0.36, 0.38))
					lamp_spots.append(base + Vector3(0, 6.26, 0) + arm_dir * 1.35)
				t += 45.0
			acc = t - seg


## Katuvalojen hehkuvat lamput (yksi MultiMesh, piilossa päivällä). Korkeus nostetaan maastoon _lift_objects:ssa
## kuten muutkin; tässä maaston korkeus lisätään suoraan.
func build_lamps() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var m := BoxMesh.new()
	m.size = Vector3(0.24, 0.04, 0.48)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.45)
	mat.emission_energy_multiplier = 4.0
	m.material = mat
	mm.mesh = m
	mm.instance_count = lamp_spots.size()
	for i in lamp_spots.size():
		var p := lamp_spots[i]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, p.y + T.h(p.x, p.z), p.z)))
	lamps = MultiMeshInstance3D.new()
	lamps.multimesh = mm
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamps.visible = false
	add_child(lamps)


## Puiset sähköpylväät ja ilmajohdot katujen varressa (katunäkymän mukaan), katuvalojen vastapuolella.
func _build_power_lines() -> void:
	var wood := Color(0.36, 0.26, 0.17)
	var wire := Color(0.08, 0.08, 0.08)
	for r in M.ROADS:
		if r.type != "street":
			continue
		var pts := _poly(r.pts)
		var hw: float = STYLES.street.w / 2.0
		var poles: Array[Vector3] = []
		var acc := 10.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var dir := (b - a).normalized()
			var seg := a.distance_to(b)
			var t := acc
			while t < seg:
				var p := a + dir * t - dir.orthogonal() * (hw + 2.0)
				if _free_spot(p, 0.8, 4.5) and _near_house(p, 45.0):
					poles.append(Vector3(p.x, 0, p.y))
					var batch := _batch_at(p)
					batch.add(B.cyl(0.11, 0.14, 8.5, 7), Transform3D(Basis(), Vector3(p.x, 4.25, p.y)), wood)
					batch.add(B.boxm(Vector3(0.1, 0.1, 1.4)), Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(p.x, 7.9, p.y)), wood)
				t += 40.0
			acc = t - seg
		for i in poles.size() - 1:
			var a3 := poles[i] + Vector3(0, 7.95, 0)
			var b3 := poles[i + 1] + Vector3(0, 7.95, 0)
			if a3.distance_to(b3) > 60.0:
				continue
			var mid := (a3 + b3) / 2.0 - Vector3(0, 0.35, 0)  # riippuma
			for off in [-0.5, 0.5]:
				var side: Vector3 = (b3 - a3).cross(Vector3.UP).normalized() * off
				for pair in [[a3 + side, mid + side], [mid + side, b3 + side]]:
					var p0: Vector3 = pair[0]
					var p1: Vector3 = pair[1]
					var len := p0.distance_to(p1)
					var bas := Basis.looking_at((p1 - p0).normalized(), Vector3.UP)
					_batch_at(Vector2(p0.x, p0.z)).add(B.boxm(Vector3(0.025, 0.025, len)), Transform3D(bas, (p0 + p1) / 2.0), wire)


## Hakkuuaukea: ruskea maa, kantoja, hakkuutähdekasoja ja muutama siemenmänty.
func _build_clearcuts() -> void:
	var stump := B.cyl(0.2, 0.26, 0.35, 8)
	for poly in _clearcuts:
		if not T.available():
			_flat_poly(poly, 0.005, _surf("clearcut"))
		var lo := Vector2(INF, INF)
		var hi := -lo
		for q in poly:
			lo = lo.min(q)
			hi = hi.max(q)
		var y := lo.y
		while y < hi.y:
			var x := lo.x
			while x < hi.x:
				var p := Vector2(x, y) + Vector2(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-2.5, 2.5))
				if Geometry2D.is_point_in_polygon(p, poly) and _road_clearance(p) > 2.0:
					var batch := _batch_at(p)
					var roll := _rng.randf()
					if roll < 0.6:
						batch.add(stump, Transform3D(Basis(), Vector3(p.x, 0.17, p.y)), Color(0.6, 0.45, 0.3).darkened(_rng.randf() * 0.2))
					elif roll < 0.8:
						for k in 4:
							var bx := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, PI / 2.0 - 0.2),
								Vector3(p.x + _rng.randf_range(-1, 1), 0.15, p.y + _rng.randf_range(-1, 1)))
							batch.add(B.cyl(0.04, 0.06, 2.2, 5), bx, Color(0.38, 0.3, 0.2))
					elif roll < 0.84:
						_trees.append([p, "pine", _rng.randf_range(0.9, 1.2), true])
				x += 6.0
			y += 6.0


# --- Ruoho -------------------------------------------------------------------

## Maskikuva: R = ruohon tiheys, G = viljapelto. Tiet, vesi ja talot nollataan.
func _build_mask() -> ImageTexture:
	var lo := M.w2(Vector2.ZERO)
	var size := M.w2(M.SIZE) - lo
	var w := ceili(size.x / MASK_PX)
	var h := ceili(size.y / MASK_PX)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	var paint := func(polys: Array[PackedVector2Array], col: Color) -> void:
		for poly in polys:
			var a := Vector2(INF, INF)
			var b := -a
			for p in poly:
				a = a.min(p)
				b = b.max(p)
			for j in range(maxi(0, floori((a.y - lo.y) / MASK_PX)), mini(h, ceili((b.y - lo.y) / MASK_PX))):
				for i in range(maxi(0, floori((a.x - lo.x) / MASK_PX)), mini(w, ceili((b.x - lo.x) / MASK_PX))):
					var wp := lo + (Vector2(i, j) + Vector2(0.5, 0.5)) * MASK_PX
					if Geometry2D.is_point_in_polygon(wp, poly):
						img.set_pixel(i, j, col)
	paint.call(_forests, Color(0.35, 0, 0, 1))
	paint.call(_bogs, Color(0.55, 0, 0, 1))
	paint.call(_fields, Color(1, 1, 0, 1))
	paint.call(_water, Color(0, 0, 0, 1))
	var ag: Array[PackedVector2Array] = [_agility]
	paint.call(ag, Color(0.12, 0, 0, 1))
	var stamp := func(wp: Vector2, r: float) -> void:
		var ci := (wp - lo) / MASK_PX
		var rp := ceili(r / MASK_PX)
		for j in range(floori(ci.y) - rp, floori(ci.y) + rp + 1):
			for i in range(floori(ci.x) - rp, floori(ci.x) + rp + 1):
				if i >= 0 and j >= 0 and i < w and j < h:
					img.set_pixel(i, j, Color(0, 0, 0, 1))
	for r in M.ROADS:
		var pts := _poly(r.pts)
		var hw: float = STYLES[r.type].w / 2.0 + (2.4 if STYLES[r.type].edge != "" else 1.2)
		for i in pts.size() - 1:
			var steps := ceili(pts[i].distance_to(pts[i + 1]) / MASK_PX)
			for k in steps + 1:
				stamp.call(pts[i].lerp(pts[i + 1], float(k) / steps), hw)
	for hp in _houses:
		stamp.call(hp, 7.0)
	for s in M.STREAMS:
		var pts := _poly(s)
		for i in pts.size() - 1:
			var steps := ceili(pts[i].distance_to(pts[i + 1]) / MASK_PX)
			for k in steps + 1:
				stamp.call(pts[i].lerp(pts[i + 1], float(k) / steps), 1.2)
	for rc in _mask_clear:
		var cen: Vector2 = rc[0]
		var hx: float = rc[1]
		var hz: float = rc[2]
		var rb := Basis(Vector3.UP, rc[3])
		var gx := -hx
		while gx <= hx:
			var gz := -hz
			while gz <= hz:
				var wv: Vector3 = rb * Vector3(gx, 0, gz)
				stamp.call(cen + Vector2(wv.x, wv.z), 1.0)
				gz += 1.5
			gx += 1.5
	var shop := M.w2(M.SHOP_BUILDING)
	for dx in range(-18, 19, 2):
		for dz in range(-9, 32, 2):
			stamp.call(shop + Vector2(dx, dz), 1.0)
	return ImageTexture.create_from_image(img)


func _build_grass() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3 * k
		var dir := Vector3(cos(a), 0, sin(a))
		var off := Vector3(sin(a * 2.3), 0, cos(a * 1.7)) * 0.14
		var lean := Vector3(-dir.z, 0, dir.x) * (0.08 + 0.05 * (k % 3))
		var tall := 0.75 + 0.25 * ((k * 7) % 4) / 3.0
		st.add_vertex(off - dir * 0.022)
		st.add_vertex(off + dir * 0.022)
		st.add_vertex(off + lean + Vector3.UP * tall)
	var grid := 170
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = grid * grid
	var lo := M.w2(Vector2.ZERO)
	_grass_mat = B.shader_mat("res://shaders/grass.gdshader", {
		"mask": _build_mask(), "map_origin": lo, "map_size": M.w2(M.SIZE) - lo,
		"grid": grid, "spacing": 0.5,
		"terrain_h": T.texture(), "terrain_origin": T.origin, "terrain_cells": Vector2(T.nx, T.nz), "terrain_cell": T.CELL,
	})
	_grass_mm = mm
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _grass_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-5000, -60, -5000), Vector3(10000, 120, 10000))
	mmi.set_meta("draped", true)
	add_child(mmi)


func _build_names() -> void:
	for n in M.PLACE_NAMES:
		var p := M.w2(n[1])
		var l := B.guide(self, n[0], Vector3(p.x, 22, p.y), 600, Color(1, 1, 1, 0.85), true)
		l.no_depth_test = false
	_build_signs()


## Kyltit suomalaisten mallien mukaan: mustavalkoinen kadunnimikilpi, punainen valtatien numero,
## ruskea virkistyskohteen opaste (laavu), valkoinen paikallinen opaste (K-Market), EuroVelo.
## Ensimmäinen vapaa paikka ehdokkaista kyltille (ei tiellä, talon vieressä eikä vedessä); INF jos ei löydy.
func _sign_spot(cands: Array) -> Vector2:
	for c: Vector2 in cands:
		if _in_bounds(c, 2.0) and _free_spot(c, 0.6, 4.0):
			return c
	return Vector2.INF


func _build_signs() -> void:
	var blue := Color(0.0, 0.3, 0.62)
	# Risteykset: pisteet, jotka ovat useammalla tiellä (ajotiet ja kadut).
	var uses := {}
	for r in M.ROADS:
		if r.type == "path":
			continue
		for p in r.pts:
			var k := Vector2i(roundi(p.x), roundi(p.y))
			uses[k] = uses.get(k, 0) + 1
	var placed := {}  # nimi -> kilpien paikat, ettei sama nimi toistu vierekkäin
	for r in M.ROADS:
		if r.name == "" or r.type in ["path", "highway"]:
			continue
		# Kilpi kadun päähän, jos se on risteys.
		for e in [0, r.pts.size() - 1]:
			var j: int = e
			if uses.get(Vector2i(roundi(r.pts[j].x), roundi(r.pts[j].y)), 0) < 2:
				continue
			var nxt: int = 1 if e == 0 else r.pts.size() - 2
			var a := M.w2(r.pts[j])
			var dir := (M.w2(r.pts[nxt]) - a).normalized()
			var hw: float = STYLES[r.type].w / 2.0
			var near := false
			for q: Vector2 in placed.get(r.name, []):
				if q.distance_to(a) < 60.0:
					near = true
			if near:
				continue
			var cands := []
			for along in [hw + 4.0, hw + 7.0, hw + 11.0]:
				for side in [1.0, -1.0]:
					cands.append(a + dir * along + dir.orthogonal() * side * (hw + 2.2))
			var at := _sign_spot(cands)
			if at == Vector2.INF:
				continue
			if not placed.has(r.name):
				placed[r.name] = []
			placed[r.name].append(a)
			B.street_sign(self, Vector3(at.x, 0, at.y), r.name, atan2(-dir.y, dir.x))
	# Valtatie 8: punainen numerokilpi kahteen kohtaan tien varteen.
	var hw_pts := PackedVector2Array()
	for r in M.ROADS:
		if r.type == "highway" and hw_pts.is_empty():
			hw_pts = _poly(r.pts)
	for frac in ([0.3, 0.7] if hw_pts.size() > 2 else []):
		var i := clampi(int(hw_pts.size() * frac), 1, hw_pts.size() - 1)
		var d := (hw_pts[i] - hw_pts[i - 1]).normalized()
		var mid := hw_pts[i - 1].lerp(hw_pts[i], 0.5)
		var at := _sign_spot([mid + d.orthogonal() * 9.0, mid - d.orthogonal() * 9.0, mid + d * 8.0 + d.orthogonal() * 9.0])
		if at == Vector2.INF:
			continue
		var pole := B.sign_pole(self, Vector3(at.x, 0, at.y), 2.4)
		var plate := B.sign_plate(pole, " 8 ", Color(0.78, 0.1, 0.1), Color.WHITE, 0.45, 80)
		plate.position.y = 2.1
		plate.rotation.y = atan2(-d.orthogonal().y, d.orthogonal().x)
	# EuroVelo 10 pyöräreitti K-Marketin kulmassa.
	var jw := M.w2(M.J_W)
	var ev := _sign_spot([jw + Vector2(-8, -7), jw + Vector2(8, -7), jw + Vector2(-8, 7), jw + Vector2(8, 7), jw + Vector2(-11, 0)])
	if ev != Vector2.INF:
		var evp := B.sign_plate(B.sign_pole(self, Vector3(ev.x, 0, ev.y), 2.3), "EV10", blue, Color(1.0, 0.85, 0.1), 0.36, 60)
		evp.position.y = 2.05
	# Ruskea puinen reittiviitta polkujen alkuun: laavun symboli, nimi ja matka, kärki polun suuntaan.
	for pair in [[M.J_H2, Vector2(846, 1300)], [M.J_KL, Vector2(600, 2400)]]:
		var a2 := M.w2(pair[0])
		var dir := (M.w2(pair[1]) - a2).normalized()
		var at := _sign_spot([a2 + dir * 5.0 + dir.orthogonal() * 3.0, a2 + dir * 5.0 - dir.orthogonal() * 3.0,
			a2 + dir * 9.0 + dir.orthogonal() * 3.0])
		if at == Vector2.INF:
			continue
		var dist := int(round(a2.distance_to(M.w2(M.LAAVU)) / 100.0)) * 100
		var km := ("%.1f km" % (dist / 1000.0)).replace(".", ",")
		B.trail_sign(self, Vector3(at.x, 0, at.y), "Laavu  " + km, atan2(-dir.y, dir.x))
	# Reittiviitta laavulta kodalle: OSM-polku lähtee laavun vierestä etelään (laavulta kaakkoon oikaistessa
	# tulee pelialueen reuna vastaan). Matka polkua pitkin.
	var kota_pts := _kota_path()
	if kota_pts.size() > 2:
		var start := 0  # polku alkaa laavun kohdalta (_kota_path)
		var k_len := 0.0
		for i in range(start, kota_pts.size() - 1):
			k_len += kota_pts[i].distance_to(kota_pts[i + 1])
		k_len += kota_pts[-1].distance_to(M.w2(M.KOTA))
		var nxt: Vector2 = kota_pts[mini(start + 2, kota_pts.size() - 1)]
		var kdir := (nxt - kota_pts[start]).normalized()
		var kat := _sign_spot([kota_pts[start] + kdir * 4.0 + kdir.orthogonal() * 2.5, kota_pts[start] + kdir * 4.0 - kdir.orthogonal() * 2.5,
			kota_pts[start] + kdir * 7.0 + kdir.orthogonal() * 2.5])
		if kat != Vector2.INF:
			var kkm := ("%.1f km" % (roundf(k_len / 100.0) / 10.0)).replace(".", ",")
			B.trail_sign(self, Vector3(kat.x, 0, kat.y), "Kota  " + kkm, atan2(-kdir.y, kdir.x))
		# Raahen kaupungin keltainen jätteentuontikielto polun varressa ennen kotaa ja lintutornia, kasvot
		# tulijaa kohti (valokuva Haapajärven tekoaltaan polulta).
		var kc := M.w2(M.KOTA)
		var back := (kota_pts[-1] - kc).normalized()  # kodalta polulle päin = tulijan suunta
		var cands := []
		for d in [14.0, 18.0, 11.0, 22.0]:
			for side in [3.0, -3.0, 5.0, -5.0, 8.0, -8.0]:
				var c: Vector2 = kc + back * d + back.orthogonal() * side
				# Kuivalle maalle kodan puolelle: ei vettä kyltin juurella eikä kyltin ja kodan välissä.
				var dry := true
				for k in 6:
					var q: Vector2 = c.lerp(kc, k / 6.0) + (Vector2.ZERO if k > 0 else Vector2.ZERO)
					if surface_at(Vector3(q.x, 0, q.y)) in ["water", "bog"]:
						dry = false
				for o2 in [Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0, 1.2), Vector2(0, -1.2)]:
					if surface_at(Vector3(c.x + o2.x, 0, c.y + o2.y)) in ["water", "bog"]:
						dry = false
				if dry:
					cands.append(c)
		var ws := _sign_spot(cands)
		if ws != Vector2.INF:
			_waste_sign(Vector3(ws.x, 0, ws.y), atan2(back.x, back.y))  # maailma nostaa maaston tasolle
	# Valkoinen paikallisopaste K-Marketille Ketunperäntien ja Tarpiontien risteyksessä.
	var kd := (M.w2(M.J_W) - M.w2(M.J_K)).normalized()
	var jk := M.w2(M.J_K)
	var ka := _sign_spot([jk + kd * 8.0 - kd.orthogonal() * 6.5, jk + kd * 8.0 + kd.orthogonal() * 6.5,
		jk + kd * 12.0 - kd.orthogonal() * 6.5])
	if ka != Vector2.INF:
		var kp := B.sign_plate(B.sign_pole(self, Vector3(ka.x, 0, ka.y), 2.3), "K-Market  ", Color.WHITE, Color.BLACK, 0.32, 44,
			Color(0.1, 0.1, 0.1))
		kp.position.y = 2.0
		kp.rotation.y = atan2(-kd.y, kd.x)
		B.sign_arrow(kp, kp.get_meta("width") / 2.0 - 0.12, Color.BLACK)


## Kieltokyltti "KIELTO – JÄTTEEN TUONTI ALUEELLE EDESVASTUUN UHALLA KIELLETTY – RAAHEN KAUPUNKI": kaksi
## sinkittyä putkitolppaa, tumma taustalevy, keltainen kalvo, joka on repeytynyt oikeasta yläkulmasta ja
## käpristyy, ruuvit, tussitägi ja kuivaa heinää juurella. Paikallinen +Z = kyltin etupuoli (yaw).
func _waste_sign(pos: Vector3, yaw: float) -> void:
	var s := Node3D.new()
	s.position = pos
	s.rotation.y = yaw
	add_child(s)
	waste_sign = s
	var steel := Color(0.62, 0.64, 0.66)
	var yellow := Color(0.96, 0.8, 0.12)
	var back_col := Color(0.2, 0.16, 0.13)
	var ink := Color(0.06, 0.06, 0.07)
	var cy := 1.3  # kyltin keskikorkeus
	for x in [-0.72, 0.72]:
		var post := B.mesh(s, B.cyl(0.03, 0.03, 2.1, 10), Vector3(x, 1.05, -0.05), steel)
		(post.material_override as StandardMaterial3D).metallic = 0.6
		(post.material_override as StandardMaterial3D).roughness = 0.45
		B.mesh(s, B.cyl(0.032, 0.032, 0.02, 10), Vector3(x, 2.1, -0.05), steel.darkened(0.2))  # tulppa
	var body := StaticBody3D.new()
	body.add_child(B.box_shape(Vector3(1.6, 2.1, 0.12), Vector3(0, 1.05, -0.04)))
	s.add_child(body)
	B.mesh(s, B.boxm(Vector3(1.9, 1.08, 0.025)), Vector3(0, cy, -0.02), back_col)  # taustalevy
	# Keltainen kalvo: koko pinta paitsi repeytynyt oikea yläkulma (kaistale ja kulmapala puuttuvat).
	var fw := 1.8
	var fh := 1.0
	B.mesh(s, B.boxm(Vector3(fw, fh - 0.08, 0.006)), Vector3(0, cy - 0.04, -0.004), yellow)
	B.mesh(s, B.boxm(Vector3(fw * 0.55, 0.08, 0.006)), Vector3(-fw * 0.225, cy + fh / 2.0 - 0.04, -0.004), yellow)
	for i in 6:  # repeämän rosoinen reuna
		var x := -fw * 0.05 + i * 0.13
		var h := 0.08 - 0.012 * i + (0.015 if i % 2 == 0 else 0.0)
		B.mesh(s, B.boxm(Vector3(0.13, maxf(h, 0.01), 0.006)), Vector3(x, cy + fh / 2.0 - 0.08 + h / 2.0, -0.004), yellow)
	for i in 3:  # käpristyneet kalvon kaistaleet yläreunalla
		var curl := B.mesh(s, B.boxm(Vector3(0.12, 0.05, 0.004)), Vector3(0.05 + i * 0.16, cy + fh / 2.0 - 0.05, 0.02),
			yellow.darkened(0.15))
		curl.rotation = Vector3(-0.9 - i * 0.2, 0.2 * i, 0.15)
	B.mesh(s, B.boxm(Vector3(0.06, 0.55, 0.006)), Vector3(fw / 2.0 - 0.03, cy + 0.05, -0.004), back_col.lightened(0.05))  # kuoriutunut oikea reuna
	# Teksti.
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Helvetica Neue", "Helvetica", "Arial", "Liberation Sans"])
	sf.font_weight = 600
	var line := func(text: String, y: float, size: int) -> void:
		var l := Label3D.new()
		l.text = text
		l.font = sf
		l.font_size = size
		l.pixel_size = 0.004
		l.modulate = ink
		l.outline_size = 0
		l.double_sided = false
		l.position = Vector3(0, cy + y, 0.002)
		s.add_child(l)
	line.call("KIELTO", 0.33, 52)
	line.call("JÄTTEEN TUONTI ALUEELLE", 0.12, 30)
	line.call("EDESVASTUUN UHALLA", 0.0, 30)
	line.call("KIELLETTY", -0.12, 30)
	line.call("RAAHEN KAUPUNKI", -0.36, 22)
	# Ruuvit kulmissa ja reunoilla.
	for p in [Vector2(-0.82, 0.42), Vector2(-0.7, 0.42), Vector2(0.7, 0.42), Vector2(0.8, 0.42), Vector2(-0.82, -0.42),
			Vector2(-0.7, -0.42), Vector2(0.72, -0.42), Vector2(0.8, -0.38)]:
		B.mesh(s, B.sphere(0.012, 6), Vector3(p.x, cy + p.y, 0.004), Color(0.25, 0.25, 0.27))
	# Tussitägi KIELLETTY-sanan oikealla puolella.
	var tag := Node3D.new()
	tag.position = Vector3(0.5, cy - 0.12, 0.003)
	s.add_child(tag)
	for st in [[Vector2(-0.08, 0.03), Vector2(0.0, 0.07), 0.5], [Vector2(0.0, 0.07), Vector2(0.05, -0.04), -1.2],
			[Vector2(0.05, -0.04), Vector2(0.14, 0.05), 0.8], [Vector2(-0.06, -0.02), Vector2(0.12, -0.01), 0.05],
			[Vector2(0.08, 0.05), Vector2(0.16, -0.07), -1.0]]:
		var a: Vector2 = st[0]
		var b2: Vector2 = st[1]
		var seg := B.mesh(tag, B.boxm(Vector3(a.distance_to(b2), 0.012, 0.002)), Vector3((a.x + b2.x) / 2.0, (a.y + b2.y) / 2.0, 0), ink)
		seg.rotation.z = (b2 - a).angle()
	# Kuivaa heinää ja horsmanvarsia tolppien juurella.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 70:
		var x := rng.randf_range(-1.1, 1.1)
		var h := rng.randf_range(0.15, 0.75)
		var blade := B.mesh(s, B.boxm(Vector3(0.02, h, 0.003)), Vector3(x, h / 2.0 - 0.02, rng.randf_range(-0.35, 0.35)),
			Color(0.78, 0.68, 0.45).lerp(Color(0.5, 0.48, 0.25), rng.randf()))
		blade.rotation = Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45))
	for i in 5:  # horsmanvarret ja pihlajan vesa
		var x := rng.randf_range(-1.2, 1.2)
		var stem := B.mesh(s, B.cyl(0.006, 0.01, 1.1, 5), Vector3(x, 0.55, rng.randf_range(-0.4, 0.3)), Color(0.45, 0.25, 0.18))
		stem.rotation.z = rng.randf_range(-0.2, 0.2)
		for k in 4:
			B.mesh(stem, B.boxm(Vector3(0.12, 0.004, 0.03)), Vector3(0.04 * (1 if k % 2 == 0 else -1), -0.2 + k * 0.15, 0),
				Color(0.85, 0.55, 0.15).lerp(Color(0.6, 0.6, 0.2), rng.randf()), Vector3(0, rng.randf() * 180.0, 20))


## Kodan polku (OSM): laavun vierestä kulkeva polku, joka käy lähimpänä kotaa. Palauttaa pisteet laavun kohdalta
## kodan lähimpään kohtaan asti (maailman 2D), tai tyhjän.
func _kota_path() -> PackedVector2Array:
	var kota := M.w2(M.KOTA)
	var laavu := M.w2(M.LAAVU)
	var best := PackedVector2Array()
	var bd := INF
	for r in M.ROADS:
		if r.type != "path" or r.pts.size() < 3:
			continue
		var pts := PackedVector2Array()
		for q in r.pts:
			pts.append(M.w2(q))
		var il := 0
		var ik := 0
		for i in pts.size():
			if pts[i].distance_to(laavu) < pts[il].distance_to(laavu):
				il = i
			if pts[i].distance_to(kota) < pts[ik].distance_to(kota):
				ik = i
		var dk: float = pts[ik].distance_to(kota)
		if pts[il].distance_to(laavu) < 60.0 and dk < bd and il != ik:
			bd = dk
			best = pts.slice(il, ik + 1) if ik > il else pts.slice(ik, il + 1)
			if ik < il:
				best.reverse()
	return best if bd < 200.0 else PackedVector2Array()

