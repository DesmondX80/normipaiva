extends Node3D
## Mopomatkan maailma Paapelista Vaalan keskustaan Hotelli-Ravintola Siitarille (erillinen tasku kuten mökki).
## Data: tools/vaala_reitti.py (OSM, OSRM-reitti, EU-DEM) -> tools/vaala_bake.py -> assets/vaala/tie.json ja
## maasto.bin. Todellinen 11,6 km on tiivistetty n. 3,4 km:iin: mökin pää ja Vaalan keskusta ovat 1:1, välillä
## jokainen tien pala on lyhennetty samassa suhteessa (suunnat ja risteykset säilyvät). Tien näytteissä on
## todellinen matka, joten mittari näyttää oikeat kilometrit.
## Paikallinen kehys = leivonnan kehys: origo mökin osoitepisteessä (Kaisuantie 62), x itään, z etelään, y mpy.

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Atm := preload("res://scripts/atm.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const TIE := "res://assets/vaala/tie.json"
const MAASTO := "res://assets/vaala/maasto.bin"
const TREES := "res://assets/vaala/puut.bin"
const Forest := preload("res://scripts/forest.gd")

enum { FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL }
const OUTSIDE := 255
## Siitarin rakennukset (OSM): ravintola Vaalantie 12 ja hotellisiipi.
const SIITARI_ID := 225699578
const HOTEL_ID := 225699572
## Pinnat ajettaessa: nopeuskerroin ja töyssyt.
const SURF := {
	FOREST: {"speed": 0.35, "bump": 0.08}, FIELD: {"speed": 0.55, "bump": 0.05}, BOG: {"speed": 0.25, "bump": 0.06},
	WATER: {"speed": 0.15, "bump": 0.0}, YARD: {"speed": 0.8, "bump": 0.02}, SHOULDER: {"speed": 0.85, "bump": 0.03},
	ROAD: {"speed": 1.0, "bump": 0.0}, RAIL: {"speed": 0.6, "bump": 0.1},
}

var data := {}
var road: Array = []        # [x, y, z, s_real, half_w, gravel, bridge]
var road_names: Array = []
var k := 6.0
var real_total := 11583.0
var siitari := Vector2.ZERO  # ravintolan keskipiste (paikallinen)
var siitari_door := Vector3.ZERO
var siitari_park := Vector3.ZERO
var siitari_yaw := 0.0       # ovelta ulos
var water_level := 118.0
var built := false

var _nx := 0
var _nz := 0
var _x0 := 0.0
var _z0 := 0.0
var _cell := 4.0
var _h := PackedFloat32Array()
var _codes := PackedByteArray()
var _fnx := 0
var _fnz := 0
var _fx0 := 0.0
var _fz0 := 0.0
var _fcell := 32.0
var _far := PackedFloat32Array()
var _road_grid := {}  # ruutu (20 m) -> näytteiden indeksit
## Rakennukset yhdistettyinä meshinä (verteksiväreillä) ja ikkunat MultiMeshinä: satoja taloja vähin piirroin.
var _walls: SurfaceTool
var _roofs: SurfaceTool
var _win_frames: Array[Transform3D] = []
var _win_glass: Array[Transform3D] = []


func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(TIE))
	road = data.road
	road_names = data.road_names
	k = data.k
	real_total = data.real_total
	siitari = Vector2(data.siitari[0], data.siitari[1])
	water_level = data.water_level
	var f := FileAccess.open(MAASTO, FileAccess.READ)
	_nx = f.get_32()
	_nz = f.get_32()
	_x0 = f.get_float()
	_z0 = f.get_float()
	_cell = f.get_float()
	_h = f.get_buffer(_nx * _nz * 4).to_float32_array()
	_codes = f.get_buffer(_nx * _nz)
	_fnx = f.get_32()
	_fnz = f.get_32()
	_fx0 = f.get_float()
	_fz0 = f.get_float()
	_fcell = f.get_float()
	_far = f.get_buffer(_fnx * _fnz * 4).to_float32_array()
	for i in road.size():
		var key := Vector2i(floori(road[i][0] / 20.0), floori(road[i][2] / 20.0))
		if not _road_grid.has(key):
			_road_grid[key] = []
		_road_grid[key].append(i)


# --- Kyselyt (paikallinen kehys) --------------------------------------------------------------------------------

## Maan korkeus (tarkka ruudukko, sen ulkopuolella kaukomaasto).
func h(x: float, z: float) -> float:
	var fx := (x - _x0) / _cell
	var fz := (z - _z0) / _cell
	if fx < 0.0 or fz < 0.0 or fx > _nx - 1 or fz > _nz - 1:
		return _far_h(x, z)
	var i := mini(int(fx), _nx - 2)
	var j := mini(int(fz), _nz - 2)
	var u := fx - i
	var v := fz - j
	var q := j * _nx + i
	if u + v <= 1.0:
		return _h[q] + (_h[q + 1] - _h[q]) * u + (_h[q + _nx] - _h[q]) * v
	return _h[q + _nx + 1] + (_h[q + _nx] - _h[q + _nx + 1]) * (1.0 - u) + (_h[q + 1] - _h[q + _nx + 1]) * (1.0 - v)


func _far_h(x: float, z: float) -> float:
	var fx := clampf((x - _fx0) / _fcell, 0.0, _fnx - 1.001)
	var fz := clampf((z - _fz0) / _fcell, 0.0, _fnz - 1.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var q := j * _fnx + i
	return lerpf(lerpf(_far[q], _far[q + 1], u), lerpf(_far[q + _fnx], _far[q + _fnx + 1], u), v)


## Maankäyttö kohdassa (FOREST ... RAIL, OUTSIDE tarkan alueen ulkopuolella).
func code_at(x: float, z: float) -> int:
	var i := int(roundf((x - _x0) / _cell))
	var j := int(roundf((z - _z0) / _cell))
	if i < 0 or j < 0 or i >= _nx or j >= _nz:
		return OUTSIDE
	return _codes[j * _nx + i]


## Lähin tien näyte ja etäisyys siitä (vaakatasossa). [-1, INF], jos tie on yli 60 m päässä.
func nearest(p: Vector3) -> Array:
	var ci := floori(p.x / 20.0)
	var cj := floori(p.z / 20.0)
	var best := -1
	var bd := INF
	for dj in range(-3, 4):
		for di in range(-3, 4):
			for i in _road_grid.get(Vector2i(ci + di, cj + dj), []):
				var r: Array = road[i]
				var d := Vector2(p.x - r[0], p.z - r[2]).length()
				if d < bd:
					bd = d
					best = i
	return [best, bd]


func road_pos(i: int) -> Vector3:
	var r: Array = road[clampi(i, 0, road.size() - 1)]
	return Vector3(r[0], r[1], r[2])


func road_dir(i: int) -> Vector3:
	var a := road_pos(i - 1)
	var b := road_pos(i + 1)
	return Vector3(b.x - a.x, 0, b.z - a.z).normalized()


## Todellinen matka (m) tien alusta näytteen kohdalla.
func real_s(i: int) -> float:
	return road[clampi(i, 0, road.size() - 1)][3]


# --- Rakentaminen ---------------------------------------------------------------------------------------------

func ensure_built() -> void:
	if built:
		return
	built = true
	var t0 := Time.get_ticks_msec()
	_build_terrain()
	_build_far()
	_build_road()
	_build_bridges()
	_build_side_roads()
	_build_underpass()
	_build_buildings()
	_build_parkings()
	_build_signs()
	_build_trees()
	_build_lamps()
	_build_atm()
	_build_lava()
	print("VAALA rakennettu %d ms" % (Time.get_ticks_msec() - t0))


func _ground_mat(a: Color, b: Color, scale := 0.04, fine := 0.8) -> Material:
	return B.shader_mat("res://shaders/ground.gdshader", {
		"color_a": a, "color_b": b, "scale": scale, "fine_scale": fine, "bump": 0.7, "roughness_v": 0.95, "stripes": 0.0,
	})


func _build_terrain() -> void:
	var mats := {
		FOREST: _ground_mat(Color(0.28, 0.32, 0.17), Color(0.5, 0.48, 0.32), 0.03, 0.6),
		FIELD: _ground_mat(Color(0.45, 0.5, 0.25), Color(0.6, 0.62, 0.32), 0.02, 0.4),
		BOG: _ground_mat(Color(0.4, 0.38, 0.22), Color(0.55, 0.45, 0.3), 0.03, 0.5),
		WATER: _ground_mat(Color(0.3, 0.3, 0.22), Color(0.42, 0.4, 0.3), 0.05, 0.8),
		YARD: _ground_mat(Color(0.3, 0.42, 0.18), Color(0.42, 0.52, 0.24), 0.05, 0.9),
		SHOULDER: _ground_mat(Color(0.5, 0.46, 0.38), Color(0.62, 0.58, 0.48), 0.08, 1.4),
	}
	mats[ROAD] = mats[SHOULDER]
	mats[RAIL] = _ground_mat(Color(0.35, 0.33, 0.3), Color(0.5, 0.47, 0.42), 0.1, 1.6)
	var arrays := {}
	for c in mats:
		arrays[c] = {"v": [], "i": [], "map": {}}  # Array (viite): Packed-taulukot kopioituisivat sanakirjasta
	var water_v := PackedVector3Array()
	for j in _nz - 1:
		for i in _nx - 1:
			var q := j * _nx + i
			var c: int = _codes[q]
			if c == OUTSIDE or _codes[q + 1] == OUTSIDE or _codes[q + _nx] == OUTSIDE or _codes[q + _nx + 1] == OUTSIDE:
				continue
			var a: Dictionary = arrays[c]
			var vs: Array = a.v
			var ids: Array = a.i
			var mp: Dictionary = a.map
			var idx: Array[int] = []
			for corner: int in [q, q + 1, q + _nx, q + _nx + 1]:
				if not mp.has(corner):
					mp[corner] = vs.size()
					vs.append(Vector3(_x0 + (corner % _nx) * _cell, _h[corner], _z0 + (corner / _nx) * _cell))
				idx.append(mp[corner])
			# Sama lävistäjä kuin h():ssa: (1,0)-(0,1).
			ids.append_array([idx[0], idx[1], idx[2], idx[1], idx[3], idx[2]])
			if c == WATER:
				# Vesipinta laajennettuna 2 ruutua: rantojen maasto peittää reunan (ei porrasta).
				var p := Vector3(_x0 + (i - 2) * _cell, water_level, _z0 + (j - 2) * _cell)
				var e := _cell * 5.0
				for w in [Vector3.ZERO, Vector3(e, 0, 0), Vector3(0, 0, e), Vector3(e, 0, 0), Vector3(e, 0, e), Vector3(0, 0, e)]:
					water_v.append(p + w)
	for c in arrays:
		var a: Dictionary = arrays[c]
		if a.i.is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in a.v:
			st.add_vertex(v)
		for ix in a.i:
			st.add_index(ix)
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mats[c]
		add_child(mi)
	if not water_v.is_empty():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for v in water_v:
			st.add_vertex(v)
		var wm := MeshInstance3D.new()
		wm.mesh = st.commit()
		wm.material_override = B.shader_mat("res://shaders/water.gdshader")
		add_child(wm)
	# Törmäys koko tarkalle ruudukolle (tarkan alueen ulkopuoli kaukomaaston korkeudella).
	var body := StaticBody3D.new()
	body.collision_layer = Terrain.COLLISION_LAYER
	body.collision_mask = 0
	var hm := HeightMapShape3D.new()
	hm.map_width = _nx
	hm.map_depth = _nz
	hm.map_data = _h
	var cs := CollisionShape3D.new()
	cs.shape = hm
	cs.scale = Vector3(_cell, 1.0, _cell)
	body.position = Vector3(_x0 + (_nx - 1) * _cell * 0.5, 0.0, _z0 + (_nz - 1) * _cell * 0.5)
	body.add_child(cs)
	add_child(body)
	# Näkymättömät seinät tarkan ruudukon reunoille (kaukomaastoon ei ajeta).
	for side in [[Vector3(_x0, 0, _z0 + _nz * _cell / 2.0), Vector3(1, 400, _nz * _cell)],
			[Vector3(_x0 + (_nx - 1) * _cell, 0, _z0 + _nz * _cell / 2.0), Vector3(1, 400, _nz * _cell)],
			[Vector3(_x0 + _nx * _cell / 2.0, 0, _z0), Vector3(_nx * _cell, 400, 1)],
			[Vector3(_x0 + _nx * _cell / 2.0, 0, _z0 + (_nz - 1) * _cell), Vector3(_nx * _cell, 400, 1)]]:
		var wall := StaticBody3D.new()
		wall.position = side[0]
		wall.add_child(B.box_shape(side[1], Vector3(0, 120, 0)))
		add_child(wall)


## Kaukomaasto (32 m) metsänvärisenä ja harvana kaukometsänä horisonttiin.
func _build_far() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in _fnz - 1:
		for i in _fnx - 1:
			var q := j * _fnx + i
			var v := func(di: int, dj: int) -> Vector3:
				return Vector3(_fx0 + (i + di) * _fcell, _far[q + dj * _fnx + di], _fz0 + (j + dj) * _fcell)
			for corner in [v.call(0, 0), v.call(1, 0), v.call(0, 1), v.call(1, 0), v.call(1, 1), v.call(0, 1)]:
				st.add_vertex(corner)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _ground_mat(Color(0.22, 0.27, 0.15), Color(0.34, 0.36, 0.22), 0.01, 0.3)
	add_child(mi)
	# Kaukomaaston metsä tulee laserpuista (forest.gd, _build_trees).


func _multimesh(mesh: Mesh, xfs: Array[Transform3D], col := Color.TRANSPARENT) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if col.a > 0.0:
		mmi.material_override = B.mat(col)
	add_child(mmi)


## Tiet: reitti ja risteysten haarat. Asfaltti kaksikaistaisena (keltainen katkoviiva keskellä ja valkoiset
## reunaviivat kuten Suomen maanteillä), sora vaaleana ja karkeana kahden tummemman ajouran kera.
func _build_road() -> void:
	_road_mats()
	var pts: Array[Vector3] = []
	var hws: Array[float] = []
	var grav: Array[bool] = []
	for i in road.size():
		pts.append(road_pos(i))
		hws.append(road[i][4])
		grav.append(road[i][5] == 1)
	_road_strip(pts, hws, grav)
	for br in data.branches:
		var bp: Array[Vector3] = []
		var bh: Array[float] = []
		var bg: Array[bool] = []
		for q in br.pts:
			bp.append(Vector3(q[0], h(q[0], q[2]), q[2]))
			bh.append(br.hw)
			bg.append(br.gravel == 1)
		# Risteyksen pää tien reunaan asti: haara alkaa reitin keskeltä, joten ensimmäiset metrit jätetään pois.
		var skip := 0
		while skip < bp.size() - 2 and Vector2(bp[skip].x - bp[0].x, bp[skip].z - bp[0].z).length() < 3.0:
			skip += 1
		_road_strip(bp.slice(skip), bh.slice(skip), bg.slice(skip))
		_dead_end(bp[-1], (bp[-1] - bp[-2]).normalized(), br.hw)
	for key in _strips:
		var st: SurfaceTool = _strips[key]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _rmats[key]
		add_child(mi)


var _strips := {}
var _rmats := {}


func _road_mats() -> void:
	_rmats = {
		"asphalt": _ground_mat(Color(0.17, 0.17, 0.18), Color(0.27, 0.27, 0.28), 0.3, 3.0),
		"gravel": _ground_mat(Color(0.5, 0.45, 0.36), Color(0.68, 0.62, 0.5), 0.25, 3.5),
		"rut": _ground_mat(Color(0.4, 0.35, 0.28), Color(0.5, 0.45, 0.36), 0.3, 3.0),
		"white": B.mat(Color(0.92, 0.92, 0.9)),
		"yellow": B.mat(Color(0.95, 0.75, 0.1)),
	}
	for k2 in _rmats:
		_strips[k2] = SurfaceTool.new()
		_strips[k2].begin(Mesh.PRIMITIVE_TRIANGLES)


func _road_strip(pts: Array, hws: Array, grav: Array) -> void:
	var dirs: Array[Vector3] = []
	for i in pts.size():
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		dirs.append(Vector3(b.x - a.x, 0, b.z - a.z).normalized())
	var dash := 0.0
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var na := dirs[i].cross(Vector3.UP)
		var nb := dirs[i + 1].cross(Vector3.UP)
		var wa: float = hws[i]
		var wb: float = hws[i + 1]
		var lift := Vector3(0, 0.04, 0)
		if grav[i]:
			_quad(_strips.gravel, a - na * wa + lift, b - nb * wb + lift, b + nb * wb + lift, a + na * wa + lift)
			var up := Vector3(0, 0.05, 0)
			for s: float in [-0.95, 0.95]:
				_quad(_strips.rut, a + na * (s - 0.25) + up, b + nb * (s - 0.25) + up, b + nb * (s + 0.25) + up, a + na * (s + 0.25) + up)
		else:
			_quad(_strips.asphalt, a - na * wa + lift, b - nb * wb + lift, b + nb * wb + lift, a + na * wa + lift)
			var up := Vector3(0, 0.055, 0)
			for s: float in [-1.0, 1.0]:
				_quad(_strips.white, a + na * s * (wa - 0.3) + up, b + nb * s * (wb - 0.3) + up,
					b + nb * s * (wb - 0.42) + up, a + na * s * (wa - 0.42) + up)
			dash += a.distance_to(b)
			if fmod(dash, 12.0) < 4.0:  # katkoviiva 4 m + 8 m väli
				_quad(_strips.yellow, a - na * 0.07 + up, b - nb * 0.07 + up, b + nb * 0.07 + up, a + na * 0.07 + up)


## Umpitie: puna-valkoinen puomi tolppineen ja liikennemerkki "Umpitie"; puomille törmäys.
func _dead_end(at: Vector3, dir: Vector3, hw: float) -> void:
	var right := dir.cross(Vector3.UP)
	var root := Node3D.new()
	root.position = at
	root.rotation.y = atan2(-dir.x, -dir.z)
	add_child(root)
	for s: float in [-1.0, 1.0]:
		B.mesh(root, B.cyl(0.06, 0.06, 1.1, 8), Vector3(s * (hw + 0.4), 0.55, 0), Color(0.9, 0.9, 0.9))
	for k2 in 8:
		var w := (hw * 2.0 + 0.8) / 8.0
		B.mesh(root, B.boxm(Vector3(w, 0.18, 0.08)), Vector3(-(hw + 0.4) + w * (k2 + 0.5), 1.0, 0),
			Color(0.85, 0.08, 0.08) if k2 % 2 == 0 else Color(0.95, 0.95, 0.95))
	var body := StaticBody3D.new()
	root.add_child(body)
	body.add_child(B.box_shape(Vector3(hw * 2.0 + 1.0, 1.4, 0.4), Vector3(0, 0.7, 0)))
	var pole := B.sign_pole(self, at - dir * 3.0 + right * (hw + 1.2), 2.2)
	var plate := B.sign_plate(pole, "UMPITIE", Color(0.0, 0.3, 0.6), Color.WHITE, 0.3, 40, Color(0.95, 0.95, 0.95), "Helvetica Neue")
	plate.position.y = 2.0
	plate.rotation.y = atan2(-dir.x, -dir.z) + PI


## Pankkiautomaatti Siitaria vastapäätä Vaalantien toisella puolella (oma kioski).
var atm_pos := Vector3.ZERO
## K-Market Tervaportin oven edusta (tyhjä, jos kauppaa ei löytynyt datasta), ulospäin ja julkisivun suunta.
var kmarket_door := Vector3.ZERO
var kmarket_out := Vector3.ZERO
var kmarket_along := Vector3.ZERO


## Pankkiautomaatti K-Market Tervaportin seinälle oven viereen kuten kylän K-Marketissa (ennen Siitarin luona).
func _build_atm() -> void:
	if kmarket_door != Vector3.ZERO:
		var at := kmarket_door - kmarket_out * 1.9 + kmarket_along * 4.6
		at.y = h(at.x, at.z)
		atm_pos = at + kmarket_out * 1.2
		Atm.build(self, at, atan2(kmarket_out.x, kmarket_out.z), true)
		return
	var sc := Vector3(siitari.x, 0, siitari.y)
	var ni: Array = nearest(sc)
	var rp := road_pos(ni[0])
	var away := Vector3(rp.x - sc.x, 0, rp.z - sc.z).normalized()
	var at: Vector3 = rp + away * (float(road[ni[0]][4]) + 5.0)
	at.y = h(at.x, at.z)
	atm_pos = at
	Atm.build(self, at, atan2(away.x, away.z), true)


# --- Oulujärven lava ------------------------------------------------------------------------------------------
## Oulujärven lava (1977-2010) oikealla paikallaan Oulujoen etelärannalla Pahalahdentien päässä (64.550921 N,
## 26.822649 E; tools/vaala_lava.py) 90-luvun asussaan: 1 500 m² suurlava (34 x 44 m), punamullatut lautaseinät,
## ikkunaluukut auki, matala peltinen harjakatto, lautalattia, esiintymislava pohjoispäädyssä, lipunmyyntikoju ja
## kyltti oven puolella, parkkipaikka ja ajotie Pahalahdentieltä (tie.json "lava").
## Tansseissa käydään mopolla (mopo_trip.gd, lava_game.gd).
var lava_center := Vector3.ZERO  # lattian keskipiste (lattian korkeudella)
var lava_door := Vector3.ZERO    # oven edusta ulkona (mopon pysäköinti)
var lava_out := Vector3.ZERO     # ovelta ulospäin


func _build_lava() -> void:
	var lv: Dictionary = data.get("lava", {})
	if lv.is_empty():
		return
	var c := Vector2(lv.x, lv.z)
	var w: float = lv.w
	var l: float = lv.l
	var side: float = lv.get("door_side", 1.0)
	var lo := INF
	var hi := -INF
	for k in 9:
		var q := c + Vector2((k % 3 - 1) * w / 2.0, (k / 3 - 1) * l / 2.0)
		lo = minf(lo, h(q.x, q.y))
		hi = maxf(hi, h(q.x, q.y))
	var fy := hi + 0.5  # lattia paalujen päällä rinteessä
	var root := Node3D.new()
	root.position = Vector3(c.x, fy, c.y)
	add_child(root)
	lava_center = root.position
	lava_out = Vector3(side, 0, 0)
	lava_door = lava_center + lava_out * (w / 2.0 + 3.5)
	lava_door.y = h(lava_door.x, lava_door.z)
	var red := Color(0.55, 0.16, 0.11)
	var trim := Color(0.93, 0.91, 0.85)
	var roof := Color(0.36, 0.12, 0.1)
	var body := StaticBody3D.new()
	root.add_child(body)
	# Sokkeli ja lattia.
	B.mesh(root, B.boxm(Vector3(w, fy - lo + 0.2, l)), Vector3(0, -(fy - lo) / 2.0 - 0.1, 0), Color(0.5, 0.5, 0.48))
	B.mesh(root, B.boxm(Vector3(w - 0.4, 0.12, l - 0.4)), Vector3(0, 0.0, 0), Color(0.72, 0.56, 0.36))
	for k in int(w / 0.6):
		B.mesh(root, B.boxm(Vector3(0.02, 0.005, l - 0.5)), Vector3(-w / 2.0 + 0.3 + k * 0.6, 0.065, 0), Color(0.55, 0.4, 0.25))
	body.add_child(B.box_shape(Vector3(w, 0.4, l), Vector3(0, -0.2, 0)))
	# Seinät: alaosa umpilautaa, ikkunavyö luukut auki (tolpat 2,2 m välein), yläreuna. Ovi oven puolen keskellä.
	var wall_parts := [[Vector3(0, 0, -l / 2.0), Vector3(1, 0, 0), w], [Vector3(0, 0, l / 2.0), Vector3(1, 0, 0), w],
		[Vector3(-w / 2.0, 0, 0), Vector3(0, 0, 1), l], [Vector3(w / 2.0, 0, 0), Vector3(0, 0, 1), l]]
	for wp in wall_parts:
		var mid: Vector3 = wp[0]
		var along: Vector3 = wp[1]
		var length: float = wp[2]
		var is_door := absf(mid.x - side * w / 2.0) < 0.1 and mid.z == 0.0
		var n := int(length / 2.2)
		for k in n:
			var t := -length / 2.0 + (k + 0.5) * length / n
			if is_door and absf(t) < 2.4:
				continue  # pariovet
			var p := mid + along * t
			var sz := Vector3(length / n + 0.02, 1.2, 0.15) if along.x != 0.0 else Vector3(0.15, 1.2, length / n + 0.02)
			B.mesh(root, B.boxm(sz), p + Vector3(0, 0.6, 0), red)
			body.add_child(B.box_shape(sz + Vector3(0, 1.0, 0), p + Vector3(0, 1.1, 0)))
			# Avattu luukku vinossa ikkuna-aukon yllä.
			var sh := B.mesh(root, B.boxm(Vector3(length / n - 0.2, 0.05, 0.9) if along.x != 0.0 else Vector3(0.9, 0.05, length / n - 0.2)),
				p + Vector3(0, 2.95, 0) - (mid.normalized() * -0.45 if mid.length() > 0.1 else Vector3.ZERO), red.darkened(0.15))
			sh.rotation = Vector3(0.45 * signf(mid.z), 0, 0) if along.x != 0.0 else Vector3(0, 0, -0.45 * signf(mid.x))
		for k in n + 1:
			var t := -length / 2.0 + k * length / n
			B.mesh(root, B.boxm(Vector3(0.18, 3.2, 0.18)), mid + along * t + Vector3(0, 1.6, 0), trim)
		var top := Vector3(length, 0.55, 0.16) if along.x != 0.0 else Vector3(0.16, 0.55, length)
		B.mesh(root, B.boxm(top), mid + Vector3(0, 3.0, 0), red)
		B.mesh(root, B.boxm(top * Vector3(1, 0.2, 1.2) + Vector3(0, 0, 0)), mid + Vector3(0, 1.22, 0), trim)
	# Matala harjakatto pituussuunnassa (peltiä), räystäät yli.
	var pm := PrismMesh.new()
	pm.size = Vector3(w + 2.0, 3.2, l + 2.0)
	B.mesh(root, pm, Vector3(0, 3.27 + 1.6, 0), roof)
	for gz in [-l / 2.0 - 0.05, l / 2.0 + 0.05]:
		var gable := PrismMesh.new()
		gable.size = Vector3(w, 3.0, 0.1)
		B.mesh(root, gable, Vector3(0, 3.27 + 1.5, gz), red)
	# Esiintymislava pohjoispäädyssä: koroke, takaseinä, vahvistimet ja rummut.
	var st := Vector3(0, 0, -l / 2.0 + 3.2)
	B.mesh(root, B.boxm(Vector3(14, 1.0, 5.6)), st + Vector3(0, 0.5, 0), Color(0.3, 0.22, 0.16))
	body.add_child(B.box_shape(Vector3(14, 1.0, 5.6), st + Vector3(0, 0.5, 0)))
	B.mesh(root, B.boxm(Vector3(14, 2.8, 0.2)), st + Vector3(0, 2.4, -2.7), Color(0.12, 0.12, 0.2))
	for x in [-5.5, 5.5]:
		B.mesh(root, B.boxm(Vector3(1.0, 1.6, 0.7)), st + Vector3(x, 1.8, -1.6), Color(0.1, 0.1, 0.1))
	for k in 3:
		B.mesh(root, B.cyl(0.32, 0.32, 0.3, 14), st + Vector3(-1.0 + k * 0.8, 1.3 + (0.25 if k == 1 else 0.0), -1.2), Color(0.85, 0.2, 0.15),
			Vector3(90 if k == 1 else 0, 0, 0))
	var band := B.sign_plate(root, "TANSSIT", Color(0.9, 0.75, 0.2), Color(0.12, 0.1, 0.2), 0.5, 70, Color(0.12, 0.1, 0.2))
	band.position = st + Vector3(0, 3.3, -2.55)
	# Valot sisällä (lämmin), lyhdyt räystään alla.
	for z in [-12.0, 0.0, 12.0]:
		var ol := OmniLight3D.new()
		ol.position = Vector3(0, 3.0, z)
		ol.omni_range = 18.0
		ol.light_energy = 0.6
		ol.light_color = Color(1.0, 0.85, 0.6)
		root.add_child(ol)
	# Kyltti oven yllä ja lipunmyynti oven vieressä.
	var face := side * (w / 2.0 + 0.12)
	var signp := B.sign_plate(root, "OULUJÄRVEN LAVA", Color(0.95, 0.92, 0.82), Color(0.5, 0.1, 0.08), 0.8, 110, Color(0.5, 0.1, 0.08))
	signp.position = Vector3(face, 3.0, 0)
	signp.rotation.y = side * PI / 2.0
	var booth := Vector3(side * (w / 2.0 + 2.2), 0, 4.2)
	B.mesh(root, B.boxm(Vector3(2.0, 2.3, 2.0)), booth + Vector3(0, 1.15 - 0.3, 0), red)
	B.mesh(root, B.boxm(Vector3(2.4, 0.15, 2.4)), booth + Vector3(0, 2.05, 0), roof)
	B.mesh(root, B.boxm(Vector3(0.05, 0.6, 1.0)), booth + Vector3(side * 1.02, 1.2, 0), Color(0.15, 0.2, 0.25))
	var tick := B.sign_plate(root, "LIPUT", Color(0.95, 0.92, 0.82), Color(0.5, 0.1, 0.08), 0.3, 44, Color(0.5, 0.1, 0.08))
	tick.position = booth + Vector3(side * 1.05, 1.75, 0)
	tick.rotation.y = side * PI / 2.0
	body.add_child(B.box_shape(Vector3(2.0, 2.3, 2.0), booth + Vector3(0, 0.85, 0)))
	var poster := B.sign_plate(root, "LA KLO 21-02", Color(0.2, 0.25, 0.55), Color(1, 0.95, 0.6), 0.35, 44, Color(1, 0.95, 0.6))
	poster.position = Vector3(face + side * 0.02, 1.6, -3.6)
	poster.rotation.y = side * PI / 2.0
	# Portaat ovelta maahan.
	var steps := int(ceil((fy - lava_door.y) / 0.25))
	for k in steps:
		B.mesh(root, B.boxm(Vector3(0.45, 0.25, 4.6)), Vector3(side * (w / 2.0 + 0.25 + k * 0.45), -0.12 - k * 0.25, 0),
			Color(0.55, 0.55, 0.53))
	# Ajotie kadulta ja parkkipaikka 90-luvun autoineen.
	var road_pts: Array = lv.get("road", [])
	if road_pts.size() >= 2:
		var a := Vector2(road_pts[0][0], road_pts[0][1])
		var b := Vector2(road_pts[1][0], road_pts[1][1])
		var segs := maxi(1, int(a.distance_to(b) / 2.0))
		for k in segs:
			var p0 := a.lerp(b, float(k) / segs)
			var p1 := a.lerp(b, float(k + 1) / segs)
			var m2 := (p0 + p1) / 2.0
			var seg := B.mesh(self, B.boxm(Vector3(3.6, 0.1, p0.distance_to(p1) + 0.2)), Vector3(m2.x, h(m2.x, m2.y) + 0.03, m2.y),
				Color(0.56, 0.5, 0.42))
			seg.rotation.y = atan2(p1.x - p0.x, p1.y - p0.y)
	var park := Vector2(lava_door.x, lava_door.z) + Vector2(side * 4.0, 0)
	var cols := [Color(0.6, 0.1, 0.1), Color(0.8, 0.8, 0.82), Color(0.15, 0.25, 0.45), Color(0.3, 0.35, 0.3)]
	for k in 4:
		var pz := park + Vector2(side * 3.0, -14.0 - k * 3.0)
		if absf(pz.y - c.y) > l / 2.0 + 8.0:
			continue
		var car := Node3D.new()
		car.position = Vector3(pz.x, h(pz.x, pz.y), pz.y)
		car.rotation.y = PI / 2.0
		add_child(car)
		Vehicles.car(car, cols[k])


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


## Oulujoen silta: betonikansi, reunapalkit, kaiteet ja pilarit veteen; törmäys kannelle ja kaiteille.
func _build_bridges() -> void:
	var conc := Color(0.62, 0.62, 0.6)
	for br in data.bridges:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var body := StaticBody3D.new()
		add_child(body)
		for i in range(int(br[0]), int(br[1])):
			var a := road_pos(i)
			var b := road_pos(i + 1)
			var na := road_dir(i).cross(Vector3.UP)
			var nb := road_dir(i + 1).cross(Vector3.UP)
			var w: float = road[i][4] + 1.6
			var down := Vector3(0, -0.8, 0)
			_quad(st, a - na * w + down, b - nb * w + down, b + nb * w + down, a + na * w + down)
			for s in [-1.0, 1.0]:
				_quad(st, a + na * s * w + down, b + nb * s * w + down, b + nb * s * w, a + na * s * w)
				_quad(st, a + na * s * w, b + nb * s * w, b + nb * s * (w - 0.5) + Vector3(0, 0.25, 0), a + na * s * (w - 0.5) + Vector3(0, 0.25, 0))
			# Tie jatkuu kannella.
			var mid := (a + b) / 2.0
			var seg := B.box_shape(Vector3(w * 2.0, 0.5, a.distance_to(b) + 0.2), Vector3.ZERO)
			seg.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), mid + Vector3(0, -0.2, 0))
			body.add_child(seg)
			if i % 2 == 0:
				for s in [-1.0, 1.0]:
					var rp: Vector3 = mid + na * s * (w - 0.25)
					B.mesh(self, B.boxm(Vector3(0.08, 1.0, 0.08)), rp + Vector3(0, 0.7, 0), Color(0.35, 0.4, 0.42))
			for s in [-1.0, 1.0]:
				var ra: Vector3 = a + na * s * (w - 0.25) + Vector3(0, 1.15, 0)
				var rb: Vector3 = b + nb * s * (w - 0.25) + Vector3(0, 1.15, 0)
				B.tube(self, ra, rb, 0.05, Color(0.35, 0.4, 0.42))
				var wall := B.box_shape(Vector3(0.3, 1.4, a.distance_to(b) + 0.1), Vector3.ZERO)
				wall.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (ra + rb) / 2.0 + Vector3(0, -0.4, 0))
				body.add_child(wall)
			if (i - int(br[0])) % 12 == 6:
				B.mesh(self, B.boxm(Vector3(w * 1.6, mid.y - water_level + 2.0, 1.2)), Vector3(mid.x, (mid.y + water_level) / 2.0 - 1.5, mid.z),
					conc, Vector3(0, rad_to_deg(atan2(-road_dir(i).x, -road_dir(i).z)), 0))
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = B.mat(conc)
		mi.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		add_child(mi)


## Sivutiet, pihatiet, kevyen liikenteen väylät ja rautatie (OSM, tien mukana siirrettyinä).
func _build_side_roads() -> void:
	var sts := {}
	for kind in ["asphalt", "gravel", "path", "rail"]:
		sts[kind] = SurfaceTool.new()
		sts[kind].begin(Mesh.PRIMITIVE_TRIANGLES)
	var sleepers: Array[Transform3D] = []
	for r in data.side_roads:
		var pts: Array = r.pts
		var hw: String = r.hw
		var kind := "gravel"
		var half := 2.2
		if r.kind == "rail":
			kind = "rail"
			half = 1.6
		elif hw in ["footway", "cycleway", "path", "pedestrian"]:
			kind = "path" if r.surface != "asphalt" else "asphalt"
			half = 1.3
		elif hw in ["secondary", "tertiary", "residential"] or r.surface in ["asphalt", "paved"]:
			kind = "asphalt"
			half = 3.2 if hw in ["secondary", "tertiary"] else 2.6
		elif hw == "service":
			half = 1.8
		var st: SurfaceTool = sts[kind]
		for j in pts.size() - 1:
			var a := Vector2(pts[j][0], pts[j][1])
			var b := Vector2(pts[j + 1][0], pts[j + 1][1])
			var n := (b - a).normalized().orthogonal() * half
			var lift := 0.03 if kind != "rail" else 0.05
			# Rata: leivottu korkeus (penger ja alikulun ratasilta), Oulujoen ratasillalla kiskot vähintään 3 m
			# vedenpinnan yläpuolella.
			var ya := h(a.x, a.y)
			var yb := h(b.x, b.y)
			if kind == "rail":
				ya = maxf(maxf(ya, pts[j][2] if pts[j].size() > 2 else ya), water_level + 3.0)
				yb = maxf(maxf(yb, pts[j + 1][2] if pts[j + 1].size() > 2 else yb), water_level + 3.0)
			var gy := func(p: Vector2) -> float:
				if kind != "rail":
					return h(p.x, p.y)
				return lerpf(ya, yb, clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.01), 0.0, 1.0))
			var v := func(p: Vector2) -> Vector3: return Vector3(p.x, gy.call(p) + lift, p.y)
			_quad(st, v.call(a - n), v.call(b - n), v.call(b + n), v.call(a + n))
			if kind == "rail":
				# Sepeliluiskat sivuille (ei rakoa maastoon).
				var skirt := Vector3(0, -0.7, 0)
				for sn: float in [-1.0, 1.0]:
					var e := n * sn
					var e2 := n * sn * 1.6
					_quad(st, v.call(a + e), v.call(b + e), v.call(b + e2) + skirt, v.call(a + e2) + skirt)
				var dir := (b - a).normalized()
				var steps := int(a.distance_to(b) / 0.8)
				for s in steps:
					var p := a.lerp(b, float(s) / steps)
					sleepers.append(Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), Vector3(p.x, gy.call(p) + 0.1, p.y)))
				for off in [-0.72, 0.72]:
					var o: Vector2 = dir.orthogonal() * off
					B.tube(self, Vector3(a.x + o.x, ya + 0.22, a.y + o.y), Vector3(b.x + o.x, yb + 0.22, b.y + o.y),
						0.04, Color(0.5, 0.45, 0.4))
				if h(a.x, a.y) < water_level + 2.5:
					# Teräksinen ristikkopalkki ja pilari veteen.
					var mid := (a + b) / 2.0
					for s2 in [-1.0, 1.0]:
						var q: Vector2 = mid + dir.orthogonal() * 1.9 * s2
						B.mesh(self, B.boxm(Vector3(0.25, 1.6, a.distance_to(b) + 0.1)), Vector3(q.x, ya + 0.6, q.y), Color(0.3, 0.32, 0.3),
							Vector3(0, rad_to_deg(atan2(dir.x, dir.y)), 0))
					B.mesh(self, B.boxm(Vector3(3.2, ya - water_level + 2.0, 1.0)), Vector3(mid.x, (ya + water_level) / 2.0 - 1.2, mid.y),
						Color(0.55, 0.55, 0.53), Vector3(0, rad_to_deg(atan2(dir.x, dir.y)), 0))
	var cols := {"asphalt": Color(0.24, 0.24, 0.25), "gravel": Color(0.56, 0.5, 0.42), "path": Color(0.5, 0.45, 0.36),
		"rail": Color(0.38, 0.35, 0.32)}
	for kind in sts:
		var st: SurfaceTool = sts[kind]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = B.mat(cols[kind])
		add_child(mi)
	if not sleepers.is_empty():
		_multimesh(B.boxm(Vector3(2.4, 0.16, 0.24)), sleepers, Color(0.4, 0.38, 0.35))


## Radan alikulku (Vuolijoentie radan ali juuri ennen Oulujokea): betonilaatta ja siniset teräspalkit kaiteineen
## ratapenkereen aukon yli, maatuet tien molemmin puolin (yläreuna seuraa penkereen luiskaa) ja
## alikulkukorkeuden kilpi. Penger ja kiskojen korkeus ovat leivonnassa (vaala_bake.py).
var underpass_i := -1


func _build_underpass() -> void:
	var u = data.get("underpass")
	if u == null:
		return
	var i: int = u.i
	underpass_i = i
	var at := Vector3(u.at[0], float(u.road_y), u.at[1])
	var rd := Vector3(u.dir[0], 0, u.dir[1]).normalized()
	var fd := road_dir(i)
	var rn := fd.cross(Vector3.UP)
	var sin_a := maxf(absf(rd.cross(fd).y), 0.35)
	var hw: float = u.hw
	var deck: float = u.deck
	var H := deck - 0.1 - at.y
	var conc := Color(0.66, 0.65, 0.62)
	# Kansi radan suuntaan aukon yli.
	var dl := (hw + 1.6) / sin_a * 2.0 + 2.0
	var basis := Basis(Vector3.UP, atan2(rd.x, rd.z))
	var deck_c := Vector3(at.x, deck - 0.5, at.z)
	var dm := B.mesh(self, B.boxm(Vector3(6.2, 0.8, dl)), deck_c, conc)
	dm.basis = basis
	var steel := Color(0.2, 0.36, 0.55)
	for s: float in [-1.0, 1.0]:
		var gp := deck_c + basis.x * s * 3.25 + Vector3(0, 0.35, 0)
		var g := B.mesh(self, B.boxm(Vector3(0.35, 1.6, dl)), gp, steel)
		g.basis = basis
		var rail_top := gp + Vector3(0, 1.3, 0)
		B.tube(self, rail_top - basis.z * dl / 2.0, rail_top + basis.z * dl / 2.0, 0.05, steel)
		for k2 in int(dl / 1.5) + 1:
			var pp: Vector3 = gp - basis.z * dl / 2.0 + basis.z * k2 * 1.5 + Vector3(0, 1.05, 0)
			B.mesh(self, B.boxm(Vector3(0.06, 0.5, 0.06)), pp, steel)
	# Alikulkukorkeus kannen reunaan molempiin ajosuuntiin.
	for s: float in [-1.0, 1.0]:
		var plate := B.sign_plate(self, "4,6 m", Color(0.98, 0.98, 0.95), Color(0.05, 0.05, 0.05), 0.4, 60, Color(0.85, 0.1, 0.08), "Helvetica Neue")
		plate.position = at - fd * s * (3.4 / sin_a + 0.1) + Vector3(0, H - 1.25, 0)
		plate.rotation.y = atan2(-fd.x * s, -fd.z * s)
	# Maatuet: paksu betoniseinä pientareen takana, yläreuna penkereen korkeudella (luiskassa laskee).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(conc.r, conc.g, conc.b, CONCRETE))
	var body := StaticBody3D.new()
	add_child(body)
	var X := (2.8 + H / 0.75) / sin_a + 1.0
	var segs := 14
	for s: float in [-1.0, 1.0]:
		var l1 := hw + 1.3
		var l2 := hw + 6.8
		var prev := {}
		for k2 in segs + 1:
			var x := -X + 2.0 * X * k2 / segs
			var ry := road_pos(i + roundi(x / 2.0)).y
			var dr := absf(x) * sin_a
			var top := at.y + maxf(H - maxf(0.0, dr - 2.8) * 0.75, 0.3) + 0.25
			var c := at + fd * x
			var cur := {
				"b1": Vector3(c.x, ry - 0.8, c.z) + rn * s * l1, "t1": Vector3(c.x, top, c.z) + rn * s * l1,
				"b2": Vector3(c.x, ry - 0.8, c.z) + rn * s * l2, "t2": Vector3(c.x, top, c.z) + rn * s * l2,
			}
			if prev.is_empty():
				_quad(st, cur.b1, cur.t1, cur.t2, cur.b2)
			else:
				_quad(st, prev.b1, cur.b1, cur.t1, prev.t1)
				_quad(st, prev.t1, cur.t1, cur.t2, prev.t2)
				var lo := minf(prev.b1.y, cur.b1.y)
				var hi := maxf(prev.t1.y, cur.t1.y)
				var mid: Vector3 = (prev.b1 + cur.b1 + prev.b2 + cur.b2) / 4.0
				var cs := B.box_shape(Vector3(l2 - l1, hi - lo, (prev.b1 as Vector3).distance_to(cur.b1) + 0.05), Vector3.ZERO)
				cs.transform = Transform3D(Basis.looking_at(fd, Vector3.UP), Vector3(mid.x, (hi + lo) / 2.0, mid.z))
				body.add_child(cs)
			prev = cur
		_quad(st, prev.b1, prev.t1, prev.t2, prev.b2)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = B.shader_mat("res://shaders/facade.gdshader")
	add_child(mi)


## Rakennukset OSM:n pohjista: omakotitalot vaakapaneelilla ja harjakatolla, vajat pystylaudoituksella, isot
## tiilestä, rappauksesta tai betonielementeistä tasakatolla. Seinä- ja kattokuviot shadereista (facade, roof),
## materiaali verteksivärin alfassa. Nimetyille kyltti tien puolelle, kirkolle torni, asemalle laituri.
const WOOD := 1.0
const BOARD := 0.75
const BRICK := 0.5
const PLASTER := 0.25
const CONCRETE := 0.0
const SEAM_ROOF := 1.0
const TILE_ROOF := 0.5
const FELT_ROOF := 0.0

var _doors: Array[Transform3D] = []
var _chimneys: Array[Transform3D] = []
var _balconies: Array[Transform3D] = []
var _win_mull: Array[Transform3D] = []
var _shop_glass: Array[Transform3D] = []


func _build_buildings() -> void:
	_walls = SurfaceTool.new()
	_walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	_roofs = SurfaceTool.new()
	_roofs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	add_child(body)
	var house_cols := [Color(0.62, 0.16, 0.12), Color(0.86, 0.74, 0.42), Color(0.92, 0.91, 0.86), Color(0.45, 0.3, 0.2),
		Color(0.55, 0.62, 0.66), Color(0.8, 0.55, 0.3), Color(0.93, 0.9, 0.78), Color(0.7, 0.72, 0.62)]
	var brick_cols := [Color(0.6, 0.26, 0.17), Color(0.72, 0.42, 0.28), Color(0.52, 0.3, 0.22), Color(0.82, 0.7, 0.5)]
	var plaster_cols := [Color(0.9, 0.88, 0.82), Color(0.86, 0.8, 0.66), Color(0.78, 0.8, 0.8), Color(0.92, 0.86, 0.74)]
	for bd in data.buildings:
		var pts := PackedVector2Array()
		for q in bd.pts:
			pts.append(Vector2(q[0], q[1]))
		if pts.size() < 3:
			continue
		var id: int = bd.id
		if id == SIITARI_ID:
			_build_siitari(pts, body)
			continue
		var name: String = bd.name
		var type: String = bd.type
		var levels: int = bd.levels
		var obb := _obb(pts)
		var base := INF
		for p in pts:
			base = minf(base, h(p.x, p.y))
		base -= 0.3
		var hsh := absi(id)
		var kind: String = bd.kind
		var col: Color
		var mat := WOOD
		var roof_col: Color = [Color(0.18, 0.18, 0.2), Color(0.45, 0.14, 0.1), Color(0.3, 0.3, 0.32), Color(0.22, 0.28, 0.24)][(hsh / 7) % 4]
		var roof_mat := SEAM_ROOF if (hsh / 3) % 3 != 0 else TILE_ROOF
		var wall_h := 2.8 * levels + 0.4
		var flat := false
		if kind == "shed":
			wall_h = 2.4
			col = [Color(0.55, 0.14, 0.1), Color(0.4, 0.3, 0.22), Color(0.6, 0.6, 0.58), Color(0.72, 0.6, 0.35)][hsh % 4]
			mat = BOARD
			roof_mat = SEAM_ROOF
		elif kind == "house" or type in ["terrace", "house", "detached", "residential"]:
			col = house_cols[hsh % house_cols.size()]
		else:
			flat = true
			roof_mat = FELT_ROOF
			roof_col = Color(0.24, 0.24, 0.26)
			match hsh % 3:
				0:
					mat = BRICK
					col = brick_cols[(hsh / 3) % brick_cols.size()]
				1:
					mat = PLASTER
					col = plaster_cols[(hsh / 3) % plaster_cols.size()]
				_:
					mat = CONCRETE
					col = Color(0.74, 0.72, 0.68)
			if levels <= 1:
				wall_h = 4.6  # liikerakennus: korkea kerros
		if type in ["roof", "service"]:
			wall_h = 3.2
		# Pohjapiirros ei ole suorakaide (siivet, L- ja U-muodot): tasakatto pohjan mukaan, ei laatikon harjakattoa.
		var area := absf(_poly_area(pts))
		var boxy: bool = area > 0.75 * obb.size.x * obb.size.y
		if not boxy:
			flat = true
		# Korkeus laserkeilauksesta (tools/kartta/vaala_tarkka.py): harjakatossa seinät harjasta katon nousun verran
		# alempana, tasakatossa katon taso.
		var ridge: float = bd.get("h", 0.0)
		if ridge > 2.0:
			if flat:
				wall_h = clampf(ridge - 0.3, 2.2, 30.0)
			else:
				wall_h = clampf(ridge - clampf(obb.size.y * 0.32, 0.8, 3.2) - 0.3, 2.2, 12.0)
		var church := name.contains("kirkko")
		var station := type == "train_station"
		if church:
			col = Color(0.95, 0.94, 0.9)
			mat = PLASTER
			wall_h = 6.5
			flat = false
			roof_mat = SEAM_ROOF
			roof_col = Color(0.3, 0.3, 0.33)
		elif station:
			col = Color(0.88, 0.72, 0.36)  # keltainen puuasema
			mat = WOOD
			flat = false
			roof_mat = SEAM_ROOF
			roof_col = Color(0.5, 0.14, 0.1)
		elif type == "church":
			flat = false
			mat = WOOD
			col = Color(0.93, 0.92, 0.88)
		if id == HOTEL_ID:
			col = Color(0.78, 0.62, 0.46)
			mat = BRICK
			wall_h = 6.4
			flat = false
		var top := base + wall_h + 0.3
		_prism(pts, base, top, col, mat)
		if flat:
			_flat_roof(pts, top, roof_col)
			_parapet(pts, top, col, mat)
		else:
			var rise := clampf(obb.size.y * 0.32, 0.8, 3.2)
			if church:
				rise = obb.size.y * 0.5
			_gable(obb, top, rise, roof_col, col, mat, roof_mat)
			if kind == "house" and not station and (hsh / 5) % 4 != 0:
				# Piippu harjan viereen.
				var cq: Vector2 = obb.center + (obb.ax as Vector2) * obb.size.x * 0.2 + (obb.ay as Vector2) * 0.6
				_chimneys.append(Transform3D(Basis(Vector3.UP, -obb.angle), Vector3(cq.x, top + rise - 0.2, cq.y)))
		# Ikkunat kaikille sivuille, ovi tien puolelle, isoissa kerrostaloissa parvekkeet.
		if kind != "shed":
			var shop := type in ["retail", "commercial"] or name.contains("market") or name.contains("Market")
			var door := _door(obb, base + 0.3)
			_windows(pts, base + 0.3, maxi(levels, 1) if id != HOTEL_ID else 2, wall_h, shop, door)
			if type == "apartments":
				_balcony_rows(pts, base + 0.3, levels, obb)
		if boxy:
			var cs := B.box_shape(Vector3(obb.size.x, wall_h + 2.0, obb.size.y), Vector3.ZERO)
			cs.transform = Transform3D(Basis(Vector3.UP, -obb.angle), Vector3(obb.center.x, base + wall_h / 2.0, obb.center.y))
			body.add_child(cs)
		else:
			# Seinä kerrallaan: siipien väliset pihat jäävät vapaiksi.
			for k in pts.size():
				var a := pts[k]
				var b2 := pts[(k + 1) % pts.size()]
				var cs := B.box_shape(Vector3(a.distance_to(b2) + 0.4, wall_h + 2.0, 0.6), Vector3.ZERO)
				cs.transform = Transform3D(Basis(Vector3.UP, -atan2(b2.y - a.y, b2.x - a.x)),
					Vector3((a.x + b2.x) / 2.0, base + wall_h / 2.0, (a.y + b2.y) / 2.0))
				body.add_child(cs)
		if church:
			_church_tower(obb, base, body)
		if id == HOTEL_ID:
			name = "HOTELLI SIITARI"
		if name.contains("K-Market"):
			# K-Market Tervaportti: ovi kadun puolella, pankkiautomaatti oven viereen (_build_atm), mopolla E kauppaan.
			name = "K-MARKET TERVAPORTTI"
			var kd := _door(obb, base + 0.3)
			var out := (kd - (obb.center as Vector2)).normalized()
			kmarket_door = Vector3(kd.x, h(kd.x, kd.y), kd.y) + Vector3(out.x, 0, out.y) * 2.5
			kmarket_out = Vector3(out.x, 0, out.y)
			kmarket_along = Vector3((obb.ax as Vector2).x, 0, (obb.ax as Vector2).y)
		if name != "" and not church:
			var fg := Color(0.98, 0.95, 0.85)
			var bg := Color(0.12, 0.2, 0.35)
			if name.contains("S-market"):
				bg = Color(0.0, 0.45, 0.25)
			elif name.contains("K-Market") or name.contains("K-MARKET"):
				bg = Color(0.9, 0.35, 0.05)
			elif station:
				name = "VAALA"
				bg = Color(0.95, 0.95, 0.95)
				fg = Color(0.1, 0.1, 0.1)
			var plate := B.sign_plate(self, name, bg, fg, 0.5 if kind == "big" or station else 0.35, 60 if kind == "big" or station else 44,
				Color(0.1, 0.12, 0.2), "Helvetica Neue")
			plate.position.y = minf(top - 0.9, base + 3.4)
			_face_road(plate, obb)
	for pair in [[_walls, "res://shaders/facade.gdshader"], [_roofs, "res://shaders/roof.gdshader"]]:
		var st: SurfaceTool = pair[0]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = B.shader_mat(pair[1])
		add_child(mi)
	_multimesh(B.boxm(Vector3(1.1, 1.3, 0.06)), _win_frames, Color(0.93, 0.93, 0.9))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.1, 0.14, 0.2)
	glass.metallic = 0.7
	glass.roughness = 0.08
	_multimesh_mat(B.boxm(Vector3(0.94, 1.14, 0.07)), _win_glass, glass)
	_multimesh(_mullion_mesh(), _win_mull, Color(0.93, 0.93, 0.9))
	_multimesh_mat(B.boxm(Vector3(2.8, 2.2, 0.07)), _shop_glass, glass)
	_multimesh(_door_mesh(), _doors)
	_multimesh(_chimney_mesh(), _chimneys)
	_multimesh(_balcony_mesh(), _balconies)


func _multimesh_mat(mesh: Mesh, xfs: Array[Transform3D], m: Material) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	add_child(mmi)


func _parts_mesh(parts: Array) -> ArrayMesh:
	var am := ArrayMesh.new()
	for part in parts:
		var st := SurfaceTool.new()
		st.append_from(part[0], 0, Transform3D(Basis.from_euler(part[3] if part.size() > 3 else Vector3.ZERO), part[1]))
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, B.mat(part[2]))
	return am


## Ikkunan puitteet: pystypuite keskellä ja vaakapuite yläosassa (kuten suomalaisessa kolmiruutuisessa ikkunassa).
func _mullion_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.append_from(B.boxm(Vector3(0.06, 1.14, 0.1)), 0, Transform3D(Basis(), Vector3.ZERO))
	st.append_from(B.boxm(Vector3(0.94, 0.06, 0.1)), 0, Transform3D(Basis(), Vector3(0, 0.22, 0)))
	st.append_from(B.boxm(Vector3(1.2, 0.05, 0.16)), 0, Transform3D(Basis(), Vector3(0, -0.68, 0.05)))  # vesipelti
	return st.commit()


func _door_mesh() -> ArrayMesh:
	return _parts_mesh([
		[B.boxm(Vector3(1.2, 2.25, 0.08)), Vector3(0, 1.12, 0), Color(0.93, 0.93, 0.9)],
		[B.boxm(Vector3(1.0, 2.1, 0.1)), Vector3(0, 1.05, 0), Color(0.36, 0.22, 0.12)],
		[B.boxm(Vector3(0.25, 1.1, 0.11)), Vector3(0.22, 1.3, 0), Color(0.55, 0.7, 0.8)],
		[B.boxm(Vector3(0.1, 0.04, 0.16)), Vector3(-0.35, 1.0, 0.06), Color(0.8, 0.8, 0.8)],
		[B.boxm(Vector3(1.6, 0.18, 1.0)), Vector3(0, -0.2, 0.45), Color(0.55, 0.55, 0.53)],  # porraskivi
		[B.boxm(Vector3(1.8, 0.08, 1.2)), Vector3(0, 2.55, 0.5), Color(0.25, 0.25, 0.27)],  # lippa
	])


func _chimney_mesh() -> ArrayMesh:
	return _parts_mesh([
		[B.boxm(Vector3(0.6, 1.6, 0.6)), Vector3(0, 0.8, 0), Color(0.55, 0.25, 0.18)],
		[B.boxm(Vector3(0.75, 0.1, 0.75)), Vector3(0, 1.62, 0), Color(0.3, 0.3, 0.32)],
		[B.boxm(Vector3(0.5, 0.18, 0.5)), Vector3(0, 1.8, 0), Color(0.15, 0.15, 0.16)],
	])


func _balcony_mesh() -> ArrayMesh:
	return _parts_mesh([
		[B.boxm(Vector3(2.8, 0.16, 1.3)), Vector3(0, 0, 0.65), Color(0.7, 0.7, 0.68)],
		[B.boxm(Vector3(2.8, 1.0, 0.06)), Vector3(0, 0.55, 1.28), Color(0.85, 0.85, 0.82)],
		[B.boxm(Vector3(0.06, 1.0, 1.3)), Vector3(-1.37, 0.55, 0.65), Color(0.85, 0.85, 0.82)],
		[B.boxm(Vector3(0.06, 1.0, 1.3)), Vector3(1.37, 0.55, 0.65), Color(0.85, 0.85, 0.82)],
	])


## Ovi pitkälle sivulle tien puolelle. Palauttaa oven paikan (ikkunat väistävät sitä).
func _door(obb: Dictionary, y0: float) -> Vector2:
	var ni: Array = nearest(Vector3(obb.center.x, 0, obb.center.y))
	var ay: Vector2 = obb.ay
	var side := ay
	if ni[0] >= 0:
		var rp := road_pos(ni[0])
		if ay.dot(Vector2(rp.x, rp.z) - (obb.center as Vector2)) < 0.0:
			side = -ay
	var ax: Vector2 = obb.ax
	var q: Vector2 = obb.center + side * ((obb.size as Vector2).y / 2.0 + 0.05) + ax * (obb.size as Vector2).x * 0.18
	var y := h(q.x, q.y) + 0.1
	_doors.append(Transform3D(Basis(Vector3.UP, atan2(side.x, side.y)), Vector3(q.x, maxf(y, y0 - 0.1), q.y)))
	return q


## Parvekkeet kerrostalon pitkille sivuille (toinen kerros ylöspäin), 6 m välein.
func _balcony_rows(pts: PackedVector2Array, y0: float, levels: int, obb: Dictionary) -> void:
	var ax: Vector2 = obb.ax
	var ay: Vector2 = obb.ay
	var n := int((obb.size as Vector2).x / 6.0)
	for s in [-1.0, 1.0]:
		var out: Vector2 = ay * s
		for lv in range(1, levels):
			for w in n:
				var q: Vector2 = obb.center + out * ((obb.size as Vector2).y / 2.0) + ax * (6.0 * (w + 0.5) - n * 3.0)
				_balconies.append(Transform3D(Basis(Vector3.UP, atan2(out.x, out.y)), Vector3(q.x, y0 + lv * 2.8 - 0.1, q.y)))


## Kirkon kellotapuli: valkoinen torni rakennuksen päätyyn, kellokerroksen aukot, kapea kattoterävä ja risti.
func _church_tower(obb: Dictionary, base: float, body: StaticBody3D) -> void:
	var ax: Vector2 = obb.ax
	var q: Vector2 = obb.center + ax * ((obb.size as Vector2).x / 2.0 + 2.4)
	var p := Vector3(q.x, base, q.y)
	var rot := Vector3(0, rad_to_deg(-obb.angle), 0)
	var white := Color(0.95, 0.94, 0.9)
	B.mesh(self, B.boxm(Vector3(4.4, 17.0, 4.4)), p + Vector3(0, 8.5, 0), white, rot)
	for k2 in 4:
		var a: float = -float(obb.angle) + k2 * PI / 2.0
		var o := Vector3(sin(a), 0, cos(a)) * 2.22
		B.mesh(self, B.boxm(Vector3(1.4, 2.4, 0.06)), p + o + Vector3(0, 14.2, 0), Color(0.12, 0.12, 0.14), Vector3(0, rad_to_deg(a), 0))
	var spire := CylinderMesh.new()
	spire.top_radius = 0.02
	spire.bottom_radius = 3.3
	spire.height = 9.0
	spire.radial_segments = 4
	spire.rings = 0
	B.mesh(self, spire, p + Vector3(0, 21.5, 0), Color(0.3, 0.3, 0.33), Vector3(0, rad_to_deg(-obb.angle) + 45.0, 0))
	B.mesh(self, B.boxm(Vector3(0.12, 2.0, 0.12)), p + Vector3(0, 27.0, 0), Color(0.85, 0.72, 0.3))
	B.mesh(self, B.boxm(Vector3(1.0, 0.12, 0.12)), p + Vector3(0, 27.4, 0), Color(0.85, 0.72, 0.3), rot)
	var cs := B.box_shape(Vector3(4.4, 17.0, 4.4), Vector3.ZERO)
	cs.transform = Transform3D(Basis(Vector3.UP, -obb.angle), p + Vector3(0, 8.5, 0))
	body.add_child(cs)


## Suunnattu rajauslaatikko: keskipiste, koko (pitkä sivu x), kulma (pitkän sivun suunta).
static func _poly_area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for k in pts.size():
		var p := pts[k]
		var q := pts[(k + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return a / 2.0


func _obb(pts: PackedVector2Array) -> Dictionary:
	var best := 0.0
	var ang := 0.0
	for i in pts.size():
		var e := pts[(i + 1) % pts.size()] - pts[i]
		if e.length() > best:
			best = e.length()
			ang = atan2(e.y, e.x)
	var ax := Vector2(cos(ang), sin(ang))
	var ay := ax.orthogonal()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		var q := Vector2(p.dot(ax), p.dot(ay))
		mn = mn.min(q)
		mx = mx.max(q)
	var c := (mn + mx) / 2.0
	return {"center": ax * c.x + ay * c.y, "size": mx - mn, "angle": ang, "ax": ax, "ay": ay}


func _prism(pts: PackedVector2Array, y0: float, y1: float, col: Color, kind := WOOD) -> void:
	_walls.set_color(Color(col.r, col.g, col.b, kind))
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		_quad(_walls, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y))


func _flat_roof(pts: PackedVector2Array, y: float, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(pts)
	_roofs.set_color(Color(col.r, col.g, col.b, FELT_ROOF))
	for ix in tris:
		_roofs.add_vertex(Vector3(pts[ix].x, y, pts[ix].y))


## Tasakaton räystäskaide (0,5 m) seinän materiaalilla.
func _parapet(pts: PackedVector2Array, y: float, col: Color, kind: float) -> void:
	_prism(pts, y - 0.1, y + 0.5, col.darkened(0.08), kind)
	_walls.set_color(Color(0.4, 0.4, 0.42, CONCRETE))
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := (b - a).normalized().orthogonal() * 0.25
		_quad(_walls, Vector3(a.x - n.x, y + 0.5, a.y - n.y), Vector3(b.x - n.x, y + 0.5, b.y - n.y),
			Vector3(b.x + n.x, y + 0.5, b.y + n.y), Vector3(a.x + n.x, y + 0.5, a.y + n.y))


## Harjakatto suunnatun laatikon päälle: harja pitkän sivun suuntaan, päätykolmiot seinän värillä, räystäät 0,5 m
## ja otsalaudat.
func _gable(obb: Dictionary, y: float, rise: float, col: Color, wall_col := Color(0.93, 0.92, 0.88), wall_kind := WOOD,
		roof_kind := SEAM_ROOF) -> void:
	var ax: Vector2 = obb.ax
	var ay: Vector2 = obb.ay
	var c: Vector2 = obb.center
	var hx: float = obb.size.x / 2.0 + 0.5
	var hy: float = obb.size.y / 2.0 + 0.5
	var p := func(u: float, v: float, yy: float) -> Vector3:
		var q := c + ax * u + ay * v
		return Vector3(q.x, yy, q.y)
	var ridge := y + rise
	var drop := rise / maxf(obb.size.y / 2.0, 0.5) * 0.5
	_roofs.set_color(Color(col.r, col.g, col.b, roof_kind))
	_quad(_roofs, p.call(-hx, -hy, y - drop), p.call(hx, -hy, y - drop), p.call(hx, 0, ridge), p.call(-hx, 0, ridge))
	_quad(_roofs, p.call(-hx, hy, y - drop), p.call(-hx, 0, ridge), p.call(hx, 0, ridge), p.call(hx, hy, y - drop))
	# Harjapelti.
	_roofs.set_color(Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, FELT_ROOF))
	_quad(_roofs, p.call(-hx, -0.15, ridge - 0.05), p.call(hx, -0.15, ridge - 0.05), p.call(hx, 0, ridge + 0.08), p.call(-hx, 0, ridge + 0.08))
	_quad(_roofs, p.call(-hx, 0.15, ridge - 0.05), p.call(-hx, 0, ridge + 0.08), p.call(hx, 0, ridge + 0.08), p.call(hx, 0.15, ridge - 0.05))
	var ex: float = obb.size.x / 2.0
	var ey: float = obb.size.y / 2.0
	_walls.set_color(Color(wall_col.r, wall_col.g, wall_col.b, wall_kind))
	for s in [-1.0, 1.0]:
		for v in [p.call(s * ex, -ey, y), p.call(s * ex, ey, y), p.call(s * ex, 0, ridge)]:
			_walls.add_vertex(v)
	# Otsalaudat valkoisina päätyihin.
	_walls.set_color(Color(0.95, 0.95, 0.93, PLASTER))
	for s in [-1.0, 1.0]:
		var u: float = s * (hx + 0.02)
		for sv in [-1.0, 1.0]:
			_quad(_walls, p.call(u, sv * hy, y - drop), p.call(u, 0, ridge), p.call(u, 0, ridge + 0.22), p.call(u, sv * hy, y - drop + 0.22))


## Ikkunat seinille kerroksittain (tummat heijastavat lasit, valkoiset karmit, puitteet ja vesipelti). Liiketiloissa
## maantasoon leveät näyteikkunat.
func _windows(pts: PackedVector2Array, y0: float, levels: int, wall_h := 3.2, shop := false, door := Vector2(INF, INF)) -> void:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var storey := wall_h / maxf(levels, 1)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var L := a.distance_to(b)
		if L < 3.0:
			continue
		var dir := (b - a) / L
		var out := dir.orthogonal()
		if out.dot((a + b) / 2.0 - c) < 0.0:
			out = -out
		var basis := Basis(Vector3.UP, atan2(out.x, out.y))
		var n := int(L / 3.0)
		for lv in levels:
			if shop and lv == 0 and L > 8.0:
				var m := int(L / 3.2)
				for w in m:
					var q := a + dir * (L * (w + 0.5) / m) + out * 0.04
					_shop_glass.append(Transform3D(basis, Vector3(q.x, y0 + 1.4, q.y)))
				continue
			for w in n:
				var q := a + dir * (L * (w + 0.5) / n) + out * 0.04
				if lv == 0 and q.distance_to(door) < 1.4:
					continue
				var xf := Transform3D(basis, Vector3(q.x, y0 + minf(1.5, storey * 0.55) + lv * storey, q.y))
				_win_frames.append(xf)
				_win_glass.append(xf.translated_local(Vector3(0, 0, 0.01)))
				_win_mull.append(xf.translated_local(Vector3(0, 0, 0.02)))


func _face_road(node: Node3D, obb: Dictionary) -> void:
	var ni: Array = nearest(Vector3(obb.center.x, 0, obb.center.y))
	if ni[0] < 0:
		return
	var rp := road_pos(ni[0])
	var to_road := Vector2(rp.x, rp.z) - (obb.center as Vector2)
	var ay: Vector2 = obb.ay
	var side := ay if ay.dot(to_road) > 0.0 else -ay
	var c: Vector2 = obb.center + side * ((obb.size as Vector2).y / 2.0 + 0.08)
	node.position.x = c.x
	node.position.z = c.y
	node.rotation.y = atan2(side.x, side.y)


## Hotelli-Ravintola Siitari (Vaalantie 12): OSM:n pohja 25,3 x 17,2 m. Tumma puuverhous, isot ikkunat tielle,
## lasiovi ja katos pysäköintipaikan puolella, terassi kaiteineen, valomainos "SIITARI" katolla.
func _build_siitari(pts: PackedVector2Array, body: StaticBody3D) -> void:
	var obb := _obb(pts)
	var base := INF
	for p in pts:
		base = minf(base, h(p.x, p.y))
	base -= 0.2
	var wall_h := 4.2
	var wood := Color(0.36, 0.22, 0.13)
	_prism(pts, base, base + wall_h, wood)
	_gable(obb, base + wall_h, 2.4, Color(0.2, 0.2, 0.22), wood, WOOD, SEAM_ROOF)
	var cs := B.box_shape(Vector3(obb.size.x, wall_h + 3.0, obb.size.y), Vector3.ZERO)
	cs.transform = Transform3D(Basis(Vector3.UP, -obb.angle), Vector3(obb.center.x, base + wall_h / 2.0, obb.center.y))
	body.add_child(cs)
	# Pääty ja pitkä sivu tien puolella: kumpi pitkä sivu on lähempänä Vaalantietä.
	var ni: Array = nearest(Vector3(obb.center.x, 0, obb.center.y))
	var rp := road_pos(ni[0])
	var ax: Vector2 = obb.ax
	var ay: Vector2 = obb.ay
	var front: Vector2 = ay if ay.dot(Vector2(rp.x, rp.z) - obb.center) > 0.0 else -ay
	var c: Vector2 = obb.center
	var hx: float = obb.size.x / 2.0
	var hy: float = obb.size.y / 2.0
	var yaw := atan2(front.x, front.y)
	var at := func(u: float, v: float, y: float) -> Vector3:
		var q := c + ax * u + front * v
		return Vector3(q.x, base + y, q.y)
	# Isot ravintolaikkunat tien puolelle.
	for u in [-8.5, -4.5, -0.5, 3.5]:
		B.mesh(self, B.boxm(Vector3(3.0, 1.9, 0.08)), at.call(u, hy + 0.04, 1.9), Color(0.9, 0.88, 0.8), Vector3(0, rad_to_deg(yaw), 0))
		B.mesh(self, B.boxm(Vector3(2.8, 1.7, 0.09)), at.call(u, hy + 0.05, 1.9), Color(0.95, 0.8, 0.45), Vector3(0, rad_to_deg(yaw), 0))
	# Valomainos katon lappeella.
	var logo := B.sign_plate(self, "SIITARI", Color(0.55, 0.05, 0.06), Color(1.0, 0.92, 0.6), 1.3, 120,
		Color(0.3, 0.02, 0.03), "Helvetica Neue")
	logo.position = at.call(-2.5, hy + 0.12, wall_h + 0.1)
	logo.rotation.y = yaw
	var sub := B.sign_plate(self, "HOTELLI-RAVINTOLA", Color(0.12, 0.1, 0.08), Color(0.98, 0.95, 0.85), 0.45, 54,
		Color(0.1, 0.1, 0.1), "Helvetica Neue")
	sub.position = at.call(-2.5, hy + 0.12, wall_h - 0.95)
	sub.rotation.y = yaw
	# Ovi päädyssä (pysäköinnin puolella, +x) ja lippakatos.
	var door_u := hx
	var dq := c + ax * (door_u + 0.05) + front * (hy - 3.0)
	siitari_door = Vector3(dq.x, base + 0.2, dq.y)
	siitari_yaw = atan2(ax.x, ax.y)
	var dyaw := rad_to_deg(siitari_yaw)
	B.mesh(self, B.boxm(Vector3(1.8, 2.3, 0.1)), siitari_door + Vector3(0, 1.15, 0), Color(0.85, 0.85, 0.82), Vector3(0, dyaw, 0))
	B.mesh(self, B.boxm(Vector3(1.6, 2.1, 0.12)), siitari_door + Vector3(0, 1.1, 0), Color(0.3, 0.42, 0.45), Vector3(0, dyaw, 0))
	var canopy := Vector3(ax.x, 0, ax.y) * 1.2
	B.mesh(self, B.boxm(Vector3(3.2, 0.15, 2.4)), siitari_door + canopy + Vector3(0, 2.7, 0), Color(0.2, 0.2, 0.22), Vector3(0, dyaw, 0))
	for s in [-1.4, 1.4]:
		var side: Vector3 = Vector3(front.x, 0, front.y) * s
		B.mesh(self, B.cyl(0.06, 0.06, 2.7, 8), siitari_door + canopy * 1.9 + side + Vector3(0, 1.35, 0), Color(0.2, 0.2, 0.22))
	var sign2 := B.sign_plate(self, "BAARI · RAVINTOLA", Color(0.55, 0.05, 0.06), Color(1.0, 0.92, 0.6), 0.3, 36,
		Color(0.3, 0.02, 0.03), "Helvetica Neue")
	sign2.position = siitari_door + canopy * 2.0 + Vector3(0, 2.95, 0)
	sign2.rotation.y = siitari_yaw
	# Terassi tien puolella: lautakansi, kaide, pöydät ja punaiset aurinkovarjot.
	var deck_c := c + front * (hy + 2.6) + ax * (-2.5)
	var deck_y := h(deck_c.x, deck_c.y) + 0.25
	B.mesh(self, B.boxm(Vector3(14.0, 0.3, 4.6)), Vector3(deck_c.x, deck_y - 0.1, deck_c.y), Color(0.55, 0.42, 0.28), Vector3(0, rad_to_deg(yaw), 0))
	var tb := StaticBody3D.new()
	add_child(tb)
	for s in [-1.0, 1.0]:
		var rq: Vector2 = deck_c + ax * s * 7.0
		B.mesh(self, B.boxm(Vector3(0.08, 1.0, 4.6)), Vector3(rq.x, deck_y + 0.5, rq.y), Color(0.3, 0.2, 0.12), Vector3(0, rad_to_deg(yaw), 0))
	var rf := deck_c + front * 2.3
	B.mesh(self, B.boxm(Vector3(14.0, 1.0, 0.08)), Vector3(rf.x, deck_y + 0.5, rf.y), Color(0.3, 0.2, 0.12), Vector3(0, rad_to_deg(yaw), 0))
	var rail := B.box_shape(Vector3(14.0, 1.2, 0.3), Vector3.ZERO)
	rail.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(rf.x, deck_y + 0.6, rf.y))
	tb.add_child(rail)
	for t in 4:
		var tq := deck_c + ax * (-5.0 + t * 3.3)
		var tp := Vector3(tq.x, deck_y, tq.y)
		B.mesh(self, B.cyl(0.45, 0.45, 0.05, 14), tp + Vector3(0, 0.75, 0), Color(0.85, 0.85, 0.82))
		B.mesh(self, B.cyl(0.04, 0.04, 0.75, 6), tp + Vector3(0, 0.37, 0), Color(0.3, 0.3, 0.3))
		B.mesh(self, B.cyl(0.02, 0.02, 2.4, 6), tp + Vector3(0, 1.2, 0), Color(0.9, 0.9, 0.9))
		B.mesh(self, B.cyl(0.05, 1.3, 0.45, 12), tp + Vector3(0, 2.3, 0), Color(0.75, 0.1, 0.1))
		for cs2 in [-0.7, 0.7]:
			var ch: Vector3 = tp + Vector3(front.x, 0, front.y) * cs2
			B.mesh(self, B.boxm(Vector3(0.42, 0.45, 0.42)), ch + Vector3(0, 0.22, 0), Color(0.2, 0.2, 0.22))
	# Mopon paikka oven edessä pysäköintipaikan reunassa.
	var pq := c + ax * (hx + 5.0) + front * (hy - 1.0)
	siitari_park = Vector3(pq.x, h(pq.x, pq.y), pq.y)


func _build_parkings() -> void:
	for poly in data.parkings:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(Vector2(q[0], q[1]))
		var tris := Geometry2D.triangulate_polygon(pts)
		if tris.is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for ix in tris:
			st.add_vertex(Vector3(pts[ix].x, h(pts[ix].x, pts[ix].y) + 0.06, pts[ix].y))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := B.mat(Color(0.26, 0.26, 0.27)).duplicate() as StandardMaterial3D
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		add_child(mi)


## Kyltit: tienviitat risteyksiin, kilometritaulut Vaalaan ja joen nimi sillalle.
func _build_signs() -> void:
	for sg in data.signs:
		var i: int = sg.i
		var p := road_pos(i)
		var dir := road_dir(i)
		var right := dir.cross(Vector3.UP)
		var hw: float = road[i][4]
		var at := p + right * (hw + 1.6)
		at.y = h(at.x, at.z)
		match sg.kind:
			"street":
				B.street_sign(self, at, sg.text, atan2(-right.x, -right.z) + PI / 2.0)
			"km":
				var pole := B.sign_pole(self, at, 2.2)
				var plate := B.sign_plate(pole, sg.text, Color(0.0, 0.3, 0.6), Color.WHITE, 0.3, 40, Color(0.95, 0.95, 0.95), "Helvetica Neue")
				plate.position.y = 2.0
				plate.rotation.y = atan2(-dir.x, -dir.z) + PI
			"river":
				var plate := B.sign_plate(self, sg.text, Color(0.0, 0.3, 0.6), Color.WHITE, 0.26, 36, Color(0.95, 0.95, 0.95), "Helvetica Neue")
				plate.position = p + right * (hw + 1.4) + Vector3(0, 1.6, 0)
				plate.rotation.y = atan2(-dir.x, -dir.z) + PI
	# Vaalan taajamamerkki keskustan alkuun (S_B).
	for i in road.size():
		if road[i][3] >= data.s_b:
			var p := road_pos(i)
			var dir := road_dir(i)
			var right := dir.cross(Vector3.UP)
			var at: Vector3 = p + right * (road[i][4] + 1.8)
			at.y = h(at.x, at.z)
			var pole := B.sign_pole(self, at, 2.4)
			var plate := B.sign_plate(pole, "Vaala", Color(0.0, 0.3, 0.6), Color.WHITE, 0.45, 60, Color(0.95, 0.95, 0.95), "Helvetica Neue")
			plate.position.y = 2.1
			plate.rotation.y = atan2(-dir.x, -dir.z) + PI
			break


## Mäntymetsä metsäruuduille (ei tien, pihojen eikä radan viereen), koivuja pihoille; puille törmäys tien lähellä.
## Metsä oikeista puista: MML:n laserkeilaus (paikka, pituus, latvus) ja Luken VMI (laji) tien suhteen pelin
## kehykseen, tiivistetyllä välillä harvennettuna (tools/vaala_bake.py -> assets/vaala/puut.bin, forest.gd).
func _build_trees() -> void:
	var f := Forest.new()
	add_child(f)
	f.load_data(TREES)


## Katuvalot keskustan tien varteen (30 m välein).
func _build_lamps() -> void:
	var last := -INF
	for i in road.size():
		var s: float = road[i][3]
		if s < data.s_b or s - last < 30.0 or road[i][6] == 1:
			continue
		last = s
		var p := road_pos(i)
		var right := road_dir(i).cross(Vector3.UP)
		var at: Vector3 = p - right * (road[i][4] + 2.2)
		at.y = h(at.x, at.z)
		B.mesh(self, B.cyl(0.07, 0.1, 7.5, 8), at + Vector3(0, 3.75, 0), Color(0.5, 0.52, 0.55))
		var head: Vector3 = at + Vector3(0, 7.4, 0) + right * 1.2
		B.tube(self, at + Vector3(0, 7.4, 0), head, 0.05, Color(0.5, 0.52, 0.55))
		B.mesh(self, B.boxm(Vector3(0.6, 0.12, 0.3)), head, Color(0.85, 0.85, 0.8))


