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
const TIE := "res://assets/vaala/tie.json"
const MAASTO := "res://assets/vaala/maasto.bin"

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
	_build_buildings()
	_build_parkings()
	_build_signs()
	_build_trees()
	_build_lamps()
	_build_atm()
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var xfs: Array[Transform3D] = []
	for j in _fnz - 1:
		for i in _fnx - 1:
			for n in 1:
				var x := _fx0 + (i + rng.randf()) * _fcell
				var z := _fz0 + (j + rng.randf()) * _fcell
				if code_at(x, z) != OUTSIDE:
					continue
				var sc := rng.randf_range(0.9, 1.5)
				xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, _far_h(x, z) + 1.3, z)))
	_multimesh(_far_pine_mesh(), xfs)


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


func _build_atm() -> void:
	var sc := Vector3(siitari.x, 0, siitari.y)
	var ni: Array = nearest(sc)
	var rp := road_pos(ni[0])
	var away := Vector3(rp.x - sc.x, 0, rp.z - sc.z).normalized()
	var at: Vector3 = rp + away * (float(road[ni[0]][4]) + 5.0)
	at.y = h(at.x, at.z)
	atm_pos = at
	Atm.build(self, at, atan2(away.x, away.z), true)


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
			# Rata ylittää Oulujoen ratasillalla: kiskot vähintään 3 m vedenpinnan yläpuolella.
			var gy := func(p: Vector2) -> float: return maxf(h(p.x, p.y), water_level + 3.0) if kind == "rail" else h(p.x, p.y)
			var v := func(p: Vector2) -> Vector3: return Vector3(p.x, gy.call(p) + lift, p.y)
			_quad(st, v.call(a - n), v.call(b - n), v.call(b + n), v.call(a + n))
			if kind == "rail":
				var dir := (b - a).normalized()
				var steps := int(a.distance_to(b) / 0.8)
				for s in steps:
					var p := a.lerp(b, float(s) / steps)
					sleepers.append(Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), Vector3(p.x, gy.call(p) + 0.1, p.y)))
				for off in [-0.72, 0.72]:
					var o: Vector2 = dir.orthogonal() * off
					B.tube(self, Vector3(a.x + o.x, gy.call(a) + 0.22, a.y + o.y), Vector3(b.x + o.x, gy.call(b) + 0.22, b.y + o.y),
						0.04, Color(0.5, 0.45, 0.4))
				if h(a.x, a.y) < water_level + 2.5:
					# Teräksinen ristikkopalkki ja pilari veteen.
					var ya: float = gy.call(a)
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
		_multimesh(B.boxm(Vector3(2.4, 0.16, 0.24)), sleepers)


## Rakennukset OSM:n pohjista: omakotitalot harjakatolla, isot laatikkona tasakatolla, Siitari erikseen.
func _build_buildings() -> void:
	_walls = SurfaceTool.new()
	_walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	_roofs = SurfaceTool.new()
	_roofs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	add_child(body)
	var house_cols := [Color(0.62, 0.16, 0.12), Color(0.86, 0.74, 0.42), Color(0.92, 0.91, 0.86), Color(0.45, 0.3, 0.2),
		Color(0.55, 0.62, 0.66), Color(0.8, 0.55, 0.3)]
	var big_cols := [Color(0.72, 0.52, 0.4), Color(0.85, 0.83, 0.78), Color(0.6, 0.58, 0.55), Color(0.78, 0.66, 0.5)]
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
		var levels: int = bd.levels
		var wall_h := 2.8 * levels + (0.4 if bd.kind != "shed" else 0.0)
		if bd.kind == "shed":
			wall_h = 2.4
		var col: Color = (house_cols if bd.kind != "big" else big_cols)[absi(id) % (house_cols.size() if bd.kind != "big" else big_cols.size())]
		if bd.kind == "shed":
			col = [Color(0.55, 0.14, 0.1), Color(0.4, 0.3, 0.22), Color(0.6, 0.6, 0.58)][absi(id) % 3]
		if id == HOTEL_ID:
			col = Color(0.78, 0.62, 0.46)
			wall_h = 6.4
		var base := INF
		for p in pts:
			base = minf(base, h(p.x, p.y))
		base -= 0.3
		_prism(pts, base, base + wall_h + 0.3, col)
		var obb := _obb(pts)
		# Katto: pienet ja keskikokoiset talot harjakatolla pitkän sivun suuntaan, isot tasakatolla.
		var roof_col: Color = [Color(0.18, 0.18, 0.2), Color(0.45, 0.14, 0.1), Color(0.3, 0.3, 0.32)][absi(id / 7) % 3]
		var top := base + wall_h + 0.3
		if bd.kind == "big" and id != HOTEL_ID:
			_flat_roof(pts, top, Color(0.25, 0.25, 0.27))
		else:
			_gable(obb, top, clampf(obb.size.y * 0.32, 0.8, 3.2), roof_col)
		# Ikkunat pitkille sivuille.
		if bd.kind != "shed":
			_windows(pts, base + 0.3, levels if id != HOTEL_ID else 2)
		var cs := B.box_shape(Vector3(obb.size.x, wall_h + 2.0, obb.size.y), Vector3.ZERO)
		cs.transform = Transform3D(Basis(Vector3.UP, -obb.angle), Vector3(obb.center.x, base + wall_h / 2.0, obb.center.y))
		body.add_child(cs)
		if id == HOTEL_ID:
			var plate := B.sign_plate(self, "HOTELLI SIITARI", Color(0.12, 0.2, 0.35), Color(0.98, 0.95, 0.85), 0.5, 60,
				Color(0.1, 0.12, 0.2), "Helvetica Neue")
			plate.position.y = top - 0.9
			_face_road(plate, obb)
	for st in [_walls, _roofs]:
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := B.vcol_mat().duplicate() as StandardMaterial3D
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_is_srgb = true
		mi.material_override = m
		add_child(mi)
	_multimesh(B.boxm(Vector3(1.1, 1.2, 0.05)), _win_frames, Color(0.93, 0.93, 0.9))
	_multimesh(B.boxm(Vector3(0.9, 1.0, 0.06)), _win_glass, Color(0.12, 0.16, 0.22))


## Suunnattu rajauslaatikko: keskipiste, koko (pitkä sivu x), kulma (pitkän sivun suunta).
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


func _prism(pts: PackedVector2Array, y0: float, y1: float, col: Color) -> void:
	_walls.set_color(col)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		# Seinäpari eri kiertosuuntiin, jotta normaali osoittaa ulos kummassakin kiertosuunnassa.
		_quad(_walls, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y))


func _flat_roof(pts: PackedVector2Array, y: float, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(pts)
	_roofs.set_color(col)
	for ix in tris:
		_roofs.add_vertex(Vector3(pts[ix].x, y, pts[ix].y))


## Harjakatto suunnatun laatikon päälle: harja pitkän sivun suuntaan, päätykolmiot, räystäät 0,4 m.
func _gable(obb: Dictionary, y: float, rise: float, col: Color) -> void:
	var ax: Vector2 = obb.ax
	var ay: Vector2 = obb.ay
	var c: Vector2 = obb.center
	var hx: float = obb.size.x / 2.0 + 0.4
	var hy: float = obb.size.y / 2.0 + 0.4
	var p := func(u: float, v: float, yy: float) -> Vector3:
		var q := c + ax * u + ay * v
		return Vector3(q.x, yy, q.y)
	var ridge := y + rise
	_roofs.set_color(col)
	_quad(_roofs, p.call(-hx, -hy, y - 0.12), p.call(hx, -hy, y - 0.12), p.call(hx, 0, ridge), p.call(-hx, 0, ridge))
	_quad(_roofs, p.call(-hx, hy, y - 0.12), p.call(-hx, 0, ridge), p.call(hx, 0, ridge), p.call(hx, hy, y - 0.12))
	var ex: float = obb.size.x / 2.0
	var ey: float = obb.size.y / 2.0
	_walls.set_color(Color(0.93, 0.92, 0.88))
	for s in [-1.0, 1.0]:
		for v in [p.call(s * ex, -ey, y), p.call(s * ex, ey, y), p.call(s * ex, 0, ridge)]:
			_walls.add_vertex(v)


## Ikkunat seinille 3 m välein kerroksittain (tummat lasit valkoisin karmein).
func _windows(pts: PackedVector2Array, y0: float, levels: int) -> void:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
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
		var n := int(L / 3.0)
		for lv in levels:
			for w in n:
				var q := a + dir * (L * (w + 0.5) / n) + out * 0.04
				var xf := Transform3D(Basis(Vector3.UP, atan2(out.x, out.y)), Vector3(q.x, y0 + 1.5 + lv * 2.8, q.y))
				_win_frames.append(xf)
				_win_glass.append(xf.translated_local(Vector3(0, 0, 0.01)))


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
	_gable(obb, base + wall_h, 2.4, Color(0.2, 0.2, 0.22))
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
func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1170
	var pines: Array[Transform3D] = []
	var birches: Array[Transform3D] = []
	var body := StaticBody3D.new()
	add_child(body)
	for j in range(1, _nz - 1):
		for i in range(1, _nx - 1):
			var q := j * _nx + i
			var c: int = _codes[q]
			if c != FOREST and c != BOG and c != YARD:
				continue
			var chance := 0.3 if c == FOREST else (0.08 if c == BOG else 0.025)
			if rng.randf() > chance:
				continue
			var near_road := false
			var bad := false
			for dj in range(-2, 3):
				for di in range(-2, 3):
					var qq := q + dj * _nx + di
					if qq < 0 or qq >= _codes.size():
						continue
					var cc: int = _codes[qq]
					if cc == ROAD or cc == SHOULDER or cc == RAIL or cc == WATER:
						if absi(di) <= 1 and absi(dj) <= 1:
							bad = true
						near_road = true
			if bad:
				continue
			var x := _x0 + (i + rng.randf_range(-0.5, 0.5)) * _cell
			var z := _z0 + (j + rng.randf_range(-0.5, 0.5)) * _cell
			var sc := rng.randf_range(0.8, 1.4) * (0.6 if c == BOG else 1.0)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, h(x, z), z))
			if c == YARD:
				birches.append(xf)
			else:
				pines.append(xf)
			if near_road:
				var cs := B.capsule_shape(0.25 * sc, 5.0 * sc)
				cs.position = Vector3(x, h(x, z) + 2.5 * sc, z)
				body.add_child(cs)
	_multimesh(_pine_mesh(), pines)
	_multimesh(_birch_mesh(), birches)


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


func _pine_mesh() -> ArrayMesh:
	var am := ArrayMesh.new()
	var parts := [[B.cyl(0.12, 0.22, 3.5, 7), Vector3(0, 1.75, 0), Color(0.35, 0.25, 0.16)]]
	for n in 4:
		var fh := 1.6 * (1.0 - n * 0.12)
		parts.append([B.cyl(0.03, fh * 0.62, fh, 7), Vector3(0, 2.8 + n * 1.12, 0), Color(0.15, 0.26, 0.14).lightened(0.04 * n)])
	for part in parts:
		var st := SurfaceTool.new()
		st.append_from(part[0], 0, Transform3D(Basis(), part[1]))
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, B.mat(part[2]))
	return am


func _birch_mesh() -> ArrayMesh:
	var am := ArrayMesh.new()
	for part in [[B.cyl(0.09, 0.14, 4.2, 7), Vector3(0, 2.1, 0), Color(0.9, 0.9, 0.86)],
			[B.sphere(1.5, 8), Vector3(0, 4.6, 0), Color(0.33, 0.5, 0.2)]]:
		var st := SurfaceTool.new()
		st.append_from(part[0], 0, Transform3D(Basis(), part[1]))
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, B.mat(part[2]))
	return am


func _far_pine_mesh() -> ArrayMesh:
	var am := ArrayMesh.new()
	for part in [[B.cyl(0.1, 0.2, 3.0, 5), Vector3(0, 1.5, 0), Color(0.35, 0.25, 0.16)],
			[B.cyl(0.05, 1.1, 5.6, 6), Vector3(0, 4.6, 0), Color(0.16, 0.27, 0.15)]]:
		var st := SurfaceTool.new()
		st.append_from(part[0], 0, Transform3D(Basis(), part[1]))
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, B.mat(part[2]))
	return am
