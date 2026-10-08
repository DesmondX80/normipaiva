extends Node3D
## Mopomatkan maailma Paapelista Vaalan keskustaan Hotelli-Ravintola Siitarille (erillinen tasku kuten mökki).
## Data: tools/vaala_reitti.py (OSM, OSRM-reitti, EU-DEM) -> tools/vaala_bake.py -> assets/vaala/tie.json ja
## maasto.bin. Todellinen 11,6 km on tiivistetty n. 2 km:iin: mökin pää, alikulku lavan niemineen ja Vaalan keskusta
## ovat 1:1, välillä jokainen tien pala on lyhennetty samassa suhteessa (suunnat ja risteykset säilyvät); Oulujoen
## ylitys keskustaan on lievemmin tiivistetty kaista. Tien näytteissä on todellinen matka, joten mittari näyttää
## oikeat kilometrit.
## Paikallinen kehys = leivonnan kehys: origo mökin osoitepisteessä (Kaisuantie 62), x itään, z etelään, y mpy.

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Atm := preload("res://scripts/atm.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const TIE := "res://assets/vaala/tie.json"
const MAASTO := "res://assets/vaala/maasto.bin"
const TREES := "res://assets/vaala/puut.bin"
const Forest := preload("res://scripts/forest.gd")
const Train := preload("res://scripts/train.gd")
## Mökin pihapiiri Vaalan maailman alussa (mopomatkan lähtö näyttää samalta kuin mökillä): rakennukset tehdään
## mökin omilla rakennusfunktioilla (mokki.gd ladataan ajonaikaisesti: mokki.gd -> mopo.gd -> vaala.gd).
const MOKKI_PATH := "res://scripts/mokki.gd"
const MOKKI_CLEAR_R := 45.0  # tämän säteen OSM-rakennukset jätetään pois mökin kohdalta

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
## Mopo parkissa mökin takana kuten mökillä (paikallinen) ja sen suunta: mopomatka alkaa tästä.
var mokki_mopo := Vector3.ZERO
var mokki_mopo_yaw := 0.0

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
	var ast0 = data.get("keskusta", {}).get("asema")
	if ast0 != null and ast0.get("id") != null:
		station_id = int(ast0.id)
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


## Ajopinta kohdassa p: sillan kannella tie (maankäyttö kannen alla on vettä tai rantaa), asfaltoiduilla
## sivukaduilla, ympyrässä, torilla ja parkeissa tie, soraisilla sivuteillä piennar, muuten code_at.
func drive_code(p: Vector3) -> int:
	var ni := nearest(p)
	if ni[0] >= 0:
		var r: Array = road[ni[0]]
		if int(r[6]) == 1 and ni[1] < float(r[4]) + 1.7 and absf(p.y - float(r[1])) < 2.0:
			return ROAD
	var c := code_at(p.x, p.z)
	if c != ROAD and not _surf.is_empty():
		var i := int((p.x - _x0) / DRIVE_CELL)
		var j := int((p.z - _z0) / DRIVE_CELL)
		if i >= 0 and j >= 0 and i < _dnx and j < _dnz:
			match _surf[j * _dnx + i]:
				2:
					return ROAD
				1:
					return SHOULDER if c != WATER else c
	return c


## Järviseudun järven pinta kohdassa (lähimmän järven taso), -INF jos järveä ei ole lähellä.
func lake_level_at(x: float, z: float) -> float:
	var best := INF
	var lvl := -INF
	for nl in data.get("north_lakes", []):
		var d := Vector2(x - float(nl.c[0]), z - float(nl.c[1])).length()
		if d < best and d < 250.0:
			best = d
			lvl = float(nl.level)
	return lvl


## Vedessä: maankäyttö vettä tai järviseudulla maasto järven pinnan alla (pinta piirtyy rannan matalikon päälle).
func wet(x: float, z: float, margin := 0.05) -> bool:
	return code_at(x, z) == WATER or h(x, z) < lake_level_at(x, z) + margin


## Sivuteiden pinta ajoalueen ruudukossa: 0 = maasto, 1 = sora, 2 = asfaltti tai kiveys (_build_drive_mask).
var _surf := PackedByteArray()
var _surf_val := 0  # _drive_seg / _drive_poly merkitsevät myös pinnan, kun > 0


## Mopolla ajettava alue (DRIVE_CELL m ruudukko tarkan maaston päällä): reitti pientareineen, risteysten haarat,
## sivutiet ja polut, parkit, tori, lavan ajotie ja niitty, mökin piha ja ovien edustat. Mopo ei aja tämän
## ulkopuolelle (mopo.gd _keep_on_road): metsään, pellolle ja pihoille ei köröttele.
const DRIVE_CELL := 2.0
var _drive := PackedByteArray()
var _dnx := 0
var _dnz := 0


func drivable(x: float, z: float) -> bool:
	if _drive.is_empty():
		return true
	var i := int((x - _x0) / DRIVE_CELL)
	var j := int((z - _z0) / DRIVE_CELL)
	if i < 0 or j < 0 or i >= _dnx or j >= _dnz:
		return false
	return _drive[j * _dnx + i] != 0


func _drive_seg(a: Vector2, b: Vector2, r: float) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r, r)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r, r)
	var i0 := maxi(int((lo.x - _x0) / DRIVE_CELL), 0)
	var j0 := maxi(int((lo.y - _z0) / DRIVE_CELL), 0)
	var i1 := mini(int((hi.x - _x0) / DRIVE_CELL), _dnx - 1)
	var j1 := mini(int((hi.y - _z0) / DRIVE_CELL), _dnz - 1)
	var r2 := (r + DRIVE_CELL * 0.5) * (r + DRIVE_CELL * 0.5)
	for j in range(j0, j1 + 1):
		var cz := _z0 + (j + 0.5) * DRIVE_CELL
		for i in range(i0, i1 + 1):
			var c := Vector2(_x0 + (i + 0.5) * DRIVE_CELL, cz)
			if c.distance_squared_to(Geometry2D.get_closest_point_to_segment(c, a, b)) <= r2:
				_drive[j * _dnx + i] = 1
				if _surf_val > 0 and _surf_val > _surf[j * _dnx + i]:
					_surf[j * _dnx + i] = _surf_val


func _drive_poly(pts: PackedVector2Array, grow: float) -> void:
	if pts.size() < 3:
		return
	var lo := pts[0]
	var hi := pts[0]
	for q in pts:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	for j in range(maxi(int((lo.y - _z0) / DRIVE_CELL), 0), mini(int((hi.y - _z0) / DRIVE_CELL), _dnz - 1) + 1):
		for i in range(maxi(int((lo.x - _x0) / DRIVE_CELL), 0), mini(int((hi.x - _x0) / DRIVE_CELL), _dnx - 1) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(_x0 + (i + 0.5) * DRIVE_CELL, _z0 + (j + 0.5) * DRIVE_CELL), pts):
				_drive[j * _dnx + i] = 1
				if _surf_val > 0 and _surf_val > _surf[j * _dnx + i]:
					_surf[j * _dnx + i] = _surf_val
	for k in pts.size():
		_drive_seg(pts[k], pts[(k + 1) % pts.size()], grow)


func _drive_ellipse(c: Vector2, rx: float, rz: float) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		pts.append(c + Vector2(cos(TAU * k / 24) * rx, sin(TAU * k / 24) * rz))
	_drive_poly(pts, 0.0)


func _build_drive_mask() -> void:
	var t0 := Time.get_ticks_msec()
	_dnx = int(_nx * _cell / DRIVE_CELL) + 1
	_dnz = int(_nz * _cell / DRIVE_CELL) + 1
	_drive.resize(_dnx * _dnz)
	_drive.fill(0)
	_surf.resize(_dnx * _dnz)
	_surf.fill(0)
	for i in road.size() - 1:
		_drive_seg(Vector2(road[i][0], road[i][2]), Vector2(road[i + 1][0], road[i + 1][2]), float(road[i][4]) + 1.5)
	# Jyrkät mutkat ja risteysten käännökset leveämmiksi (kulman ulkopuolelle ei jää taskua, johon mopo juuttuu).
	for i in range(4, road.size() - 4):
		var turn := road_dir(i - 4).angle_to(road_dir(i + 4))
		if turn > 0.5:
			_drive_seg(Vector2(road[i][0], road[i][2]), Vector2(road[i][0], road[i][2]), float(road[i][4]) + 1.5 + minf(turn, 1.6) * 4.0)
	for br in data.branches:
		for k in br.pts.size() - 1:
			_drive_seg(Vector2(br.pts[k][0], br.pts[k][2]), Vector2(br.pts[k + 1][0], br.pts[k + 1][2]), float(br.hw) + 1.0)
	for r in data.side_roads:
		if r.kind == "rail" or r.pts.size() < 2:
			continue
		var hw: String = r.hw
		var half := 2.2
		if hw in ["footway", "cycleway", "path", "pedestrian", "steps"]:
			half = 1.3
		elif hw in ["secondary", "tertiary"]:
			half = 3.2
		elif hw in ["residential", "unclassified"] or r.surface in ["asphalt", "paved"]:
			half = 2.6
		elif hw == "service":
			half = 1.8
		# Pinta kuten piirrossa (_build_side_roads): asfaltti täyttä vauhtia, sora ja polut pientareen vauhtia.
		var paved: bool = hw in ["secondary", "tertiary", "residential"] or r.surface in ["asphalt", "paved"]
		_surf_val = 2 if paved else 1
		if r.name == "Vaalan tori":
			var tp := PackedVector2Array()
			for q in r.pts:
				tp.append(Vector2(q[0], q[1]))
			_surf_val = 2
			_drive_poly(tp, 1.0)
			_surf_val = 0
			continue
		for k in r.pts.size() - 1:
			# Reunan yli 0,6 m: tienvarren puut ovat vähintään 0,8 m reunasta (puut_teilta.py), runkoon ei ajeta.
			_drive_seg(Vector2(r.pts[k][0], r.pts[k][1]), Vector2(r.pts[k + 1][0], r.pts[k + 1][1]), half + 0.6)
		_surf_val = 0
	_surf_val = 2  # parkit ja liikenneympyrä
	var polys: Array = data.parkings.duplicate()
	var ks: Dictionary = data.get("keskusta", {})
	if ks.get("parking") != null:
		polys.append(ks.parking)
	for poly in polys:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(Vector2(q[0], q[1]))
		_drive_poly(pts, 1.0)
	var ast = data.get("keskusta", {}).get("asema")
	if ast != null:
		var rcen := Vector2(ast.roundabout.c[0], ast.roundabout.c[1])
		for k in 24:
			_drive_seg(rcen + Vector2.from_angle(TAU * k / 24) * (float(ast.roundabout.r) - 3.2),
				rcen + Vector2.from_angle(TAU * (k + 1) / 24) * (float(ast.roundabout.r) - 3.2), 4.2)
	_surf_val = 0
	if data.has("lava"):
		var lr: Array = data.lava.road
		for k in lr.size() - 1:
			_drive_seg(Vector2(lr[k][0], lr[k][1]), Vector2(lr[k + 1][0], lr[k + 1][1]), 3.5)
		_drive_ellipse(Vector2(lava_door.x, lava_door.z), 9.0, 9.0)
	# Järviseudun tiet: Nuojuankoskentie Ranta-Rosvolle ja Salmiselle, soratie laavun ja tynnyrisaunan pihaan.
	var nbox := Rect2()
	for r in north_roads:
		var pts: PackedVector2Array = r.pts
		_surf_val = 2 if r.asphalt else 1
		for i in pts.size() - 1:
			_drive_seg(pts[i], pts[i + 1], float(r.half) + 0.6)
			nbox = Rect2(pts[i], Vector2.ZERO) if nbox.size == Vector2.ZERO and nbox.position == Vector2.ZERO else nbox.expand(pts[i])
	_surf_val = 0
	for poly in north_areas:
		_drive_poly(poly, 0.5)
		# Rantapihoista vesi pois: mopolla ei ajeta järveen.
		var bb := Rect2(poly[0], Vector2.ZERO)
		for v in poly:
			bb = bb.expand(v)
		bb = bb.grow(2.0)
		for j in range(maxi(int((bb.position.y - _z0) / DRIVE_CELL), 0), mini(int((bb.end.y - _z0) / DRIVE_CELL), _dnz - 1) + 1):
			for i in range(maxi(int((bb.position.x - _x0) / DRIVE_CELL), 0), mini(int((bb.end.x - _x0) / DRIVE_CELL), _dnx - 1) + 1):
				if code_at(_x0 + (i + 0.5) * DRIVE_CELL, _z0 + (j + 0.5) * DRIVE_CELL) == WATER:
					_drive[j * _dnx + i] = 0
	# Järviseudun järviin ei ajeta (tien levennys rannassa ulottuisi veteen): vesi ja pinnan alle jäävä matalikko
	# pois ajoalueesta.
	if nbox.size != Vector2.ZERO:
		nbox = nbox.grow(60.0)
		for j in range(maxi(int((nbox.position.y - _z0) / DRIVE_CELL), 0), mini(int((nbox.end.y - _z0) / DRIVE_CELL), _dnz - 1) + 1):
			for i in range(maxi(int((nbox.position.x - _x0) / DRIVE_CELL), 0), mini(int((nbox.end.x - _x0) / DRIVE_CELL), _dnx - 1) + 1):
				var cx := _x0 + (i + 0.5) * DRIVE_CELL
				var cz := _z0 + (j + 0.5) * DRIVE_CELL
				if wet(cx, cz, 0.35) and nearest(Vector3(cx, 0, cz))[1] > 12.0:
					_drive[j * _dnx + i] = 0
	# Mökin piha (hiekkasoikio) ja mopon parkkipaikka tielle asti.
	var MokkiScript: GDScript = load(MOKKI_PATH)
	var yard := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24
		yard.append(MokkiScript.to_map2(Vector2(-2.0 + cos(a) * 19.0, 6.0 + sin(a) * 17.0)))
	_drive_poly(yard, 0.0)
	var mm := Vector2(mokki_mopo.x, mokki_mopo.z)
	_drive_seg(mm, mm, 4.0)
	_drive_seg(mm, Vector2(road[0][0], road[0][2]), 2.5)
	# Ovien ja pysäköintipaikkojen edustat: ovelle ja sieltä lähimmälle tielle.
	var stops: Array[Vector3] = [siitari_park, siitari_door, kmarket_door, atm_pos, lava_door]
	for d in doors:
		if not d.get("walk", false):  # rannoilla ja laiturilla ei ajeta veteen
			stops.append(d.pos)
	for sp in stops:
		if sp == Vector3.ZERO:
			continue
		var p := Vector2(sp.x, sp.z)
		var near_drive := drivable(p.x, p.y)
		for k in 8:
			var q := p + Vector2.from_angle(TAU * k / 8) * 6.0
			near_drive = near_drive or drivable(q.x, q.y)
		if not near_drive:
			var ni := nearest(sp)
			if ni[0] >= 0 and ni[1] < 40.0:
				_drive_seg(p, Vector2(road[ni[0]][0], road[ni[0]][2]), 2.5)
		_drive_seg(p, p, 5.0)
	print("VAALA ajoalue %d ms, %.0f %% ruuduista" % [Time.get_ticks_msec() - t0, 100.0 * _drive.count(1) / _drive.size()])


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
	_plan_north()
	_build_terrain()
	_build_far()
	_build_road()
	_build_bridges()
	_build_side_roads()
	_build_underpass()
	_tori_prep()
	_build_buildings()
	_build_parkings()
	_build_tori()
	_build_station()
	_build_signs()
	_build_trees()
	_build_lamps()
	_build_atm()
	_build_lava()
	_build_mokki_yard()
	_build_north()
	_build_drive_mask()
	print("VAALA rakennettu %d ms" % (Time.get_ticks_msec() - t0))


func _ground_mat(a: Color, b: Color, scale := 0.04, fine := 0.8, bump := 0.7, rough := 0.95) -> Material:
	return B.shader_mat("res://shaders/ground.gdshader", {
		"color_a": a, "color_b": b, "scale": scale, "fine_scale": fine, "bump": bump, "roughness_v": rough, "stripes": 0.0,
	})


func _build_terrain() -> void:
	# Maankäyttö verteksiväreinä yhteen meshiin (ground_blend.gdshader): [väri a, väri b, sorapintaisuus].
	# Rajat liukuvat ruudun matkalla, joten pihat, pientareet ja metsänpohja eivät näy 4 m portaina.
	var pal := {
		FOREST: [Color(0.28, 0.32, 0.17), Color(0.5, 0.48, 0.32), 0.0],
		FIELD: [Color(0.45, 0.5, 0.25), Color(0.6, 0.62, 0.32), 0.0],
		BOG: [Color(0.4, 0.38, 0.22), Color(0.55, 0.45, 0.3), 0.0],
		WATER: [Color(0.3, 0.3, 0.22), Color(0.42, 0.4, 0.3), 0.3],
		YARD: [Color(0.3, 0.42, 0.18), Color(0.42, 0.52, 0.24), 0.2],
		SHOULDER: [Color(0.5, 0.46, 0.38), Color(0.62, 0.58, 0.48), 1.0],
		RAIL: [Color(0.35, 0.33, 0.3), Color(0.5, 0.47, 0.42), 1.0],
	}
	pal[ROAD] = pal[SHOULDER]
	var lin := {}
	for c in pal:
		lin[c] = [(pal[c][0] as Color).srgb_to_linear(), (pal[c][1] as Color).srgb_to_linear(), pal[c][2]]
	var n := _nx * _nz
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var cust := PackedFloat32Array()
	verts.resize(n)
	norms.resize(n)
	cols.resize(n)
	cust.resize(n * 4)
	for j in _nz:
		for i in _nx:
			var q := j * _nx + i
			verts[q] = Vector3(_x0 + i * _cell, _h[q], _z0 + j * _cell)
			var hl := _h[q - 1] if i > 0 else _h[q]
			var hr := _h[q + 1] if i < _nx - 1 else _h[q]
			var hu := _h[q - _nx] if j > 0 else _h[q]
			var hd := _h[q + _nx] if j < _nz - 1 else _h[q]
			norms[q] = Vector3(hl - hr, 2.0 * _cell, hu - hd).normalized()
			var e: Array = lin.get(_codes[q], lin[FOREST])
			cols[q] = e[0]
			var b: Color = e[1]
			cust[q * 4] = b.r
			cust[q * 4 + 1] = b.g
			cust[q * 4 + 2] = b.b
			cust[q * 4 + 3] = e[2]
	# Lohkot (TCHUNK ruutua) kolmella tarkkuudella: lähellä joka ruutu, kauempana joka toinen ja neljäs piste.
	# Harvempien tasojen reunoilla helma alaspäin peittää saumat. Lohkot karsitaan näkymästä erikseen, ja vain
	# lähin taso heittää varjoja.
	var mat := B.shader_mat("res://shaders/ground_blend.gdshader")
	var lods := [[1, 0.0, TLOD[0]], [2, TLOD[0], TLOD[1]], [4, TLOD[1], 0.0]]
	var half := TCHUNK * _cell * 0.71
	for cj in range(0, _nz - 1, TCHUNK):
		for ci in range(0, _nx - 1, TCHUNK):
			for lod in lods:
				var am := _terrain_chunk(ci, cj, mini(ci + TCHUNK, _nx - 1), mini(cj + TCHUNK, _nz - 1), lod[0], verts, norms, cols, cust)
				if am == null:
					continue
				var mi := MeshInstance3D.new()
				mi.mesh = am
				mi.material_override = mat
				mi.visibility_range_begin = maxf(lod[1] - half, 0.0) if lod[1] > 0.0 else 0.0
				mi.visibility_range_end = lod[2] + half if lod[2] > 0.0 else 0.0
				if lod[0] > 1:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mi)
	_build_water()
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


## Maaston lohko ruuduista [i0, i1] x [j0, j1] askeleella st (1, 2 tai 4); harvoilla tasoilla helma reunoille.
const TCHUNK := 32
const TLOD := [320.0, 700.0]


func _terrain_chunk(i0: int, j0: int, i1: int, j1: int, st: int, verts: PackedVector3Array, norms: PackedVector3Array,
		cols: PackedColorArray, cust: PackedFloat32Array) -> ArrayMesh:
	var ii := []
	var jj := []
	for i in range(i0, i1, st):
		ii.append(i)
	ii.append(i1)
	for j in range(j0, j1, st):
		jj.append(j)
	jj.append(j1)
	var w := ii.size()
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var u := PackedFloat32Array()
	for j in jj:
		for i in ii:
			var q: int = j * _nx + i
			v.append(verts[q])
			n.append(norms[q])
			c.append(cols[q])
			u.append_array([cust[q * 4], cust[q * 4 + 1], cust[q * 4 + 2], cust[q * 4 + 3]])
	var ids := PackedInt32Array()
	for b in jj.size() - 1:
		for a in w - 1:
			var q := b * w + a
			ids.append_array([q, q + 1, q + w, q + 1, q + w + 1, q + w])
	if st > 1:
		# Helma: reunan pisteet 3 m alas, kolmiot molemmin puolin (kumpi tahansa puoli näkyy).
		var ring := []
		for a in w:
			ring.append(a)
		for b in range(1, jj.size()):
			ring.append(b * w + w - 1)
		for a in range(w - 2, -1, -1):
			ring.append((jj.size() - 1) * w + a)
		for b in range(jj.size() - 2, -1, -1):
			ring.append(b * w)
		var base := v.size()
		for k in ring.size():
			var q: int = ring[k]
			v.append(v[q] - Vector3(0, 3.0, 0))
			n.append(n[q])
			c.append(c[q])
			u.append_array([u[q * 4], u[q * 4 + 1], u[q * 4 + 2], u[q * 4 + 3]])
		for k in ring.size() - 1:
			var a0: int = ring[k]
			var a1: int = ring[k + 1]
			var b0 := base + k
			var b1 := base + k + 1
			ids.append_array([a0, b0, a1, a1, b0, b1, a0, a1, b0, a1, b1, b0])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_CUSTOM0] = u
	arr[Mesh.ARRAY_INDEX] = ids
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return am


## Vedet tarkalla alueella: jokaisella järvellä oma pintansa (pohja on 1,2 m pinnan alla, vaala_bake.py). Rivin
## peräkkäiset vesiruudut samalla pinnalla yhdeksi suorakaiteeksi, ruudun verran laajennettuna rantojen yli.
func _build_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var any := false
	for j in _nz:
		var run := -1
		var lv := 0.0
		for i in _nx + 1:
			var q := j * _nx + i
			var wet := i < _nx and _codes[q] == WATER
			var l := _h[q] + 1.2 if wet else 0.0
			if run >= 0 and (not wet or absf(l - lv) > 0.05):
				var a := Vector3(_x0 + (run - 1) * _cell, lv, _z0 + (j - 1) * _cell)
				var b := Vector3(_x0 + i * _cell, lv, _z0 + (j + 1) * _cell)
				for p in [a, Vector3(b.x, lv, a.z), Vector3(a.x, lv, b.z), Vector3(b.x, lv, a.z), b, Vector3(a.x, lv, b.z)]:
					st.add_vertex(p)
				any = true
				run = -1
			if wet and run < 0:
				run = i
				lv = l
	if not any:
		return
	var wm := MeshInstance3D.new()
	wm.mesh = st.commit()
	wm.material_override = B.shader_mat("res://shaders/water.gdshader")
	wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wm)


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
	# Oulujärvi ja Oulujoki kaukomaastossa: pohja painettu vedenpinnan alle (tools/vaala_lava.py), vesi ruutuihin,
	# joiden jokin kulma on pohjaa. Tarkan maaston kokonaan peittämät ruudut ohitetaan (tarkka piirtää oman vetensä).
	var water_v := PackedVector3Array()
	for j in _fnz - 1:
		for i in _fnx - 1:
			var q := j * _fnx + i
			if minf(minf(_far[q], _far[q + 1]), minf(_far[q + _fnx], _far[q + _fnx + 1])) > water_level - 1.9:
				continue
			var a := Vector3(_fx0 + i * _fcell, water_level, _fz0 + j * _fcell)
			var covered := true
			for dc: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				if code_at(a.x + dc.x * _fcell, a.z + dc.y * _fcell) == OUTSIDE:
					covered = false
			if covered:
				continue
			var e := _fcell
			for w in [Vector3.ZERO, Vector3(e, 0, 0), Vector3(0, 0, e), Vector3(e, 0, 0), Vector3(e, 0, e), Vector3(0, 0, e)]:
				water_v.append(a + w)
	if not water_v.is_empty():
		var ws := SurfaceTool.new()
		ws.begin(Mesh.PRIMITIVE_TRIANGLES)
		ws.set_normal(Vector3.UP)
		for v in water_v:
			ws.add_vertex(v)
		var wm := MeshInstance3D.new()
		wm.mesh = ws.commit()
		wm.material_override = B.shader_mat("res://shaders/water.gdshader")
		add_child(wm)
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
		if br.name == "Neittäväntie" and not north_roads.is_empty():
			continue  # haara jatkuu Nuojuankoskentienä Ranta-Rosvolle ja Salmiselle (_plan_north): ei puomia
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
		"asphalt": _ground_mat(Color(0.2, 0.2, 0.21), Color(0.26, 0.26, 0.27), 0.12, 1.6, 0.22, 0.85),
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
				# Reunaviivat: sisäreunasta ulkoreunaan samassa kiertosuunnassa kummallakin puolella (materiaali
				# karsii takapinnat, ennen oikea reunaviiva jäi näkymättömäksi).
				var ia := na * minf(s * (wa - 0.3), s * (wa - 0.42))
				var oa := na * maxf(s * (wa - 0.3), s * (wa - 0.42))
				var ib := nb * minf(s * (wb - 0.3), s * (wb - 0.42))
				var ob := nb * maxf(s * (wb - 0.3), s * (wb - 0.42))
				_quad(_strips.white, a + ia + up, b + ib + up, b + ob + up, a + oa + up)
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


## Pankkiautomaatti K-Market Tervaportin seinällä (tai, jos kauppaa ei ole datassa, Siitaria vastapäätä omassa kioskissa).
var atm_pos := Vector3.ZERO
## K-Market Tervaportin oven edusta (tyhjä, jos kauppaa ei löytynyt datasta), ulospäin ja julkisivun suunta.
var kmarket_door := Vector3.ZERO
var kmarket_out := Vector3.ZERO
var kmarket_along := Vector3.ZERO
var kmarket_center := Vector3.ZERO  # rakennuksen keskipiste maan tasossa
var kmarket_half := Vector2.ZERO  # puolikkaat: x = julkisivun suunta (kmarket_along), y = syvyys (kmarket_face)
var kmarket_face := Vector3.ZERO  # julkisivun normaali kadulle (kmarket_out on vino: ovi ei ole keskellä)
## Keskustan ovet, joista mennään sisään E:llä (mopo_trip.gd door-signaali): {id, pos = oven edusta, out = ulospäin,
## hint}. K-Market Tervaportti, torin Zabuki ja Gasthaus.
var doors: Array = []


func door_pos(id: String) -> Vector3:
	for d in doors:
		if d.id == id:
			return d.pos
	return Vector3.ZERO


## Pankkiautomaatti omaan kioskiinsa K-Market Tervaportin päätyyn Siitarin puolelle: julkisivu on näyteikkunaa
## päästä päähän, joten seinään se peittäisi ikkunan. Kioski on julkisivun linjassa, näyttö kadulle päin. Kauppa
## on pelissä Siitarin vieressä Vaalantien varressa (tools/vaala_keskusta.py).
func _build_atm() -> void:
	if kmarket_door != Vector3.ZERO:
		var to_siitari := Vector3(siitari.x, 0, siitari.y) - kmarket_center
		var side := 1.0 if kmarket_along.dot(to_siitari) >= 0.0 else -1.0
		var at := kmarket_center + kmarket_along * side * (kmarket_half.x + 1.6) + kmarket_face * (kmarket_half.y - 0.9)
		at.y = h(at.x, at.z)
		atm_pos = at + kmarket_face * 1.2
		Atm.build(self, at, atan2(-kmarket_face.x, -kmarket_face.z), true)  # näyttö (-Z) kadulle
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
## Oulujärven lava (1977-2010) niemellä, jossa Oulujoki alkaa Oulujärvestä (todellisuudessa niemen kärjessä
## Pahalahdentien päässä, 64.550921 N, 26.822649 E; pelissä vähän lähempänä Vuolijoentietä, tools/vaala_lava.py)
## 90-luvun asussaan: 1 500 m² suurlava (34 x 44 m), punamullatut lautaseinät, ikkunaluukut auki, matala peltinen
## harjakatto, lautalattia, esiintymislava pohjoispäädyssä, lipunmyyntikoju ja kyltti oven puolella, parkkipaikka,
## asfaltoitu ajotie Pahalahdentieltä ja lautatarha-aita joelta Pahalahteen (päät vedessä, portti tiellä;
## tie.json "lava").
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
	for ri in road_pts.size() - 1:
		var a := Vector2(road_pts[ri][0], road_pts[ri][1])
		var b := Vector2(road_pts[ri + 1][0], road_pts[ri + 1][1])
		var segs := maxi(1, int(a.distance_to(b) / 2.0))
		for k in segs:
			var p0 := a.lerp(b, float(k) / segs)
			var p1 := a.lerp(b, float(k + 1) / segs)
			var m2 := (p0 + p1) / 2.0
			var seg := B.mesh(self, B.boxm(Vector3(4.4, 0.1, p0.distance_to(p1) + 0.2)), Vector3(m2.x, h(m2.x, m2.y) + 0.03, m2.y),
				Color(0.24, 0.24, 0.25))
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
	_build_lava_fence(lv)


## Lavan aita: 2 m lautatarha punamullattuna, tolpat 2,4 m välein; päät vedessä (tolpat pohjaan asti), portti
## Pahalahdentiellä auki (portinpielet ja aukaistut lehdet). Törmäys aidalle, ei portille.
func _build_lava_fence(lv: Dictionary) -> void:
	var pts: Array = lv.get("fence", [])
	if pts.size() < 2:
		return
	var gate := Vector2.INF
	if lv.get("gate") != null:
		gate = Vector2(lv.gate[0], lv.gate[1])
	var gw: float = lv.get("gate_w", 6.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	add_child(body)
	var red := Color(0.5, 0.15, 0.1)
	var post := B.boxm(Vector3(0.14, 1.0, 0.14))
	# Aita kahtena pätkänä portin molemmin puolin (portti on ensimmäisellä, joen puoleisella sivulla).
	var line: Array[Vector2] = []
	for q in pts:
		line.append(Vector2(q[0], q[1]))
	var runs: Array = [line]
	if gate != Vector2.INF:
		var gd0 := (line[1] - line[0]).normalized()
		var g0 := gate - gd0 * gw / 2.0
		var g1 := gate + gd0 * gw / 2.0
		runs = [[line[0], g0], [g1] + line.slice(1)]
	for run: Array in runs:
		for s in run.size() - 1:
			_fence_run(st, body, run[s], run[s + 1], post)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = B.mat(red)
	add_child(mi)
	if gate == Vector2.INF:
		return
	# Portinpielet ja lehdet auki sisäänpäin (etelään).
	var a0 := Vector2(pts[0][0], pts[0][1])
	var a1 := Vector2(pts[1][0], pts[1][1])
	var gd := (a1 - a0).normalized()
	for sg in [-1.0, 1.0]:
		var gp: Vector2 = gate + gd * sg * gw / 2.0
		var gy: float = h(gp.x, gp.y)
		B.mesh(self, B.boxm(Vector3(0.25, 2.6, 0.25)), Vector3(gp.x, gy + 1.3, gp.y), red.darkened(0.2))
		var leaf := B.mesh(self, B.boxm(Vector3(0.05, 1.8, gw / 2.0 - 0.2)), Vector3.ZERO, red)
		var inward := Vector2(-gd.y, gd.x) if (Vector2(lv.x, lv.z) - gate).dot(Vector2(-gd.y, gd.x)) > 0.0 else Vector2(gd.y, -gd.x)
		var lc: Vector2 = gp + inward * (gw / 4.0)
		leaf.position = Vector3(lc.x, gy + 1.05, lc.y)
		leaf.rotation.y = atan2(inward.x, inward.y)
	var plate := B.sign_plate(self, "OULUJÄRVEN LAVA", Color(0.95, 0.92, 0.82), Color(0.5, 0.1, 0.08), 0.45, 64, Color(0.5, 0.1, 0.08))
	var outward := (gate - Vector2(lv.x, lv.z)).normalized()
	var sp: Vector2 = gate + gd * (gw / 2.0 + 1.6) + outward * 0.2
	plate.position = Vector3(sp.x, h(sp.x, sp.y) + 1.6, sp.y)
	plate.rotation.y = atan2(outward.x, outward.y)



## Aidan suora pätkä a -> b: tolpat 2,4 m välein, lautaseinä ja johteet tolppien välissä, törmäys seinälle. Maalla
## seinä seuraa maata, vedessä se ulottuu pinnan alle ja tolpat pohjaan.
func _fence_run(st: SurfaceTool, body: StaticBody3D, a: Vector2, b: Vector2, post: Mesh) -> void:
	var top := func(p: Vector2) -> float: return maxf(h(p.x, p.y), water_level) + 2.0
	var dir := (b - a).normalized()
	var n := maxi(1, int(ceil(a.distance_to(b) / 2.4)))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		var y0 := h(p.x, p.y) - 0.3
		var y1: float = top.call(p) + 0.1
		st.append_from(post, 0, Transform3D(Basis().scaled(Vector3(1, y1 - y0, 1)), Vector3(p.x, (y0 + y1) / 2.0, p.y)))
	for k in n:
		var p0 := a.lerp(b, float(k) / n)
		var p1 := a.lerp(b, float(k + 1) / n)
		var m := (p0 + p1) / 2.0
		var y0 := minf(h(p0.x, p0.y), h(p1.x, p1.y)) + 0.08
		if y0 < water_level:
			y0 = water_level - 0.3  # vedessä lauta ulottuu pinnan alle
		var y1: float = minf(top.call(p0), top.call(p1))
		var seg_len := p0.distance_to(p1)
		var xf := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(m.x, (y0 + y1) / 2.0, m.y))
		st.append_from(B.boxm(Vector3(0.04, y1 - y0, seg_len)), 0, xf)
		# Johteet aidan toisella puolella ylhäällä ja alhaalla.
		for jy in [y0 + 0.25, y1 - 0.25]:
			st.append_from(B.boxm(Vector3(0.05, 0.1, seg_len)), 0, Transform3D(xf.basis, Vector3(m.x, jy, m.y) + Vector3(dir.y, 0, -dir.x) * 0.045))
		var cs := B.box_shape(Vector3(0.2, y1 - y0 + 1.0, seg_len), Vector3(m.x, (y0 + y1) / 2.0, m.y))
		cs.rotation.y = atan2(dir.x, dir.y)
		body.add_child(cs)

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
			var mid := (a + b) / 2.0
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
		_bridge_deck(body, int(br[0]), int(br[1]))
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = B.mat(conc)
		mi.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		add_child(mi)


## Sillan kannen törmäys yhtenä ohuena pintana (tien pinta + 5 cm). Päissä pinta jatkuu 6 m luiskana 0,5 m maan
## alle: laatikon etureuna jäi tien päähän 10-20 cm kynnykseksi, johon mopo pysähtyi kuin seinään.
const DECK_RAMP := 6.0
const DECK_DROP := 0.5


func _bridge_deck(body: StaticBody3D, i0: int, i1: int) -> void:
	var rows: Array = []  # [keskipiste, sivuvektori * puolileveys]
	var first := road_pos(i0)
	var d0 := road_dir(i0)
	var last := road_pos(i1)
	var d1 := road_dir(i1)
	for k in [DECK_RAMP, DECK_RAMP / 2.0]:
		rows.append([first - d0 * k + Vector3(0, 0.05 - DECK_DROP * k / DECK_RAMP, 0), d0.cross(Vector3.UP) * (float(road[i0][4]) + 1.6)])
	for i in range(i0, i1 + 1):
		rows.append([road_pos(i) + Vector3(0, 0.05, 0), road_dir(i).cross(Vector3.UP) * (float(road[i][4]) + 1.6)])
	for k in [DECK_RAMP / 2.0, DECK_RAMP]:
		rows.append([last + d1 * k + Vector3(0, 0.05 - DECK_DROP * k / DECK_RAMP, 0), d1.cross(Vector3.UP) * (float(road[i1][4]) + 1.6)])
	var faces := PackedVector3Array()
	for r in rows.size() - 1:
		var a: Vector3 = rows[r][0]
		var b: Vector3 = rows[r + 1][0]
		var na: Vector3 = rows[r][1]
		var nb: Vector3 = rows[r + 1][1]
		faces.append_array([a - na, b - nb, b + nb, a - na, b + nb, a + na])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)


## Sivutiet, pihatiet, kevyen liikenteen väylät ja rautatie (OSM, tien mukana siirrettyinä).
func _build_side_roads() -> void:
	var sts := {}
	for kind in ["asphalt", "gravel", "path", "rail"]:
		sts[kind] = SurfaceTool.new()
		sts[kind].begin(Mesh.PRIMITIVE_TRIANGLES)
	var sleepers: Array[Transform3D] = []
	var rail_bridge: Array = []  # [a, b] kiskojen tasossa joen yli
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
			if kind != "rail":
				# Tienpinta enintään 2 m paloina maaston mukaan (pitkällä välillä maasto puskisi läpi), ja pätkät
				# limittyvät mutkissa (muuten ulkokaarteeseen jää kiila nurmea).
				var sd := (b - a).normalized()
				var a2 := a - (sd * half * 0.6 if j > 0 else Vector2.ZERO)
				var b2 := b + (sd * half * 0.6 if j < pts.size() - 2 else Vector2.ZERO)
				var sn := sd.orthogonal() * half
				var pieces := maxi(1, ceili(a2.distance_to(b2) / 2.0))
				for k in pieces:
					var p0 := a2.lerp(b2, float(k) / pieces)
					var p1 := a2.lerp(b2, float(k + 1) / pieces)
					var lift := 0.05 if kind == "asphalt" else 0.04
					_quad(st, Vector3(p0.x + sn.x, h(p0.x + sn.x, p0.y + sn.y) + lift, p0.y + sn.y),
						Vector3(p1.x + sn.x, h(p1.x + sn.x, p1.y + sn.y) + lift, p1.y + sn.y),
						Vector3(p1.x - sn.x, h(p1.x - sn.x, p1.y - sn.y) + lift, p1.y - sn.y),
						Vector3(p0.x - sn.x, h(p0.x - sn.x, p0.y - sn.y) + lift, p0.y - sn.y))
				continue
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
			_quad(st, v.call(a + n), v.call(b + n), v.call(b - n), v.call(a - n))
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
				var up = data.get("underpass")
				var at_under: bool = up != null and a.distance_to(Vector2(up.at[0], up.at[1])) < 60.0
				# Joen yli (kiskot reilusti maan yläpuolella): teräsristikkosilta (_build_truss) koko jaksolle.
				if not at_under and minf(ya, yb) - maxf(h(a.x, a.y), h(b.x, b.y)) > 2.0:
					rail_bridge.append([Vector3(a.x, ya, a.y), Vector3(b.x, yb, b.y)])
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
	# Peräkkäiset siltapätkät yhdeksi jaksoksi, kullekin oma ristikkosilta.
	var runs: Array = []
	for sg in rail_bridge:
		if not runs.is_empty() and (runs[-1][1] as Vector3).distance_to(sg[0]) < 1.0:
			runs[-1][1] = sg[1]
		else:
			runs.append([sg[0], sg[1]])
	for rn in runs:
		if (rn[0] as Vector3).distance_to(rn[1]) > 8.0:
			Train.build_truss(self, rn[0], rn[1], water_level)
	_build_train()


## Satunnainen juna (train.gd) pääradalle: radan OSM-pätkät ketjutetaan läntisimmästä päästä eteenpäin (seuraava
## pätkä alkaa edellisen päästä ja jatkaa samaan suuntaan), korkeus kuten kiskoilla.
var train: Node3D
const TRAIN_WEST_MARGIN := 40.0  # reitti alkaa näin paljon ratasillan itäpään jälkeen


func _build_train() -> void:
	var lines: Array = []
	for r in data.side_roads:
		if r.kind != "rail" or r.pts.size() < 2 or r.name == "Asemaraide":
			continue
		var pl := PackedVector3Array()
		for q in r.pts:
			var y := maxf(maxf(h(q[0], q[1]), q[2] if q.size() > 2 else -INF), water_level + 3.0)
			pl.append(Vector3(q[0], y, q[1]))
		lines.append(pl)
	if lines.is_empty():
		return
	var start := -1
	var rev := false
	for li in lines.size():
		var pl: PackedVector3Array = lines[li]
		for e in 2:
			var q: Vector3 = pl[0] if e == 0 else pl[pl.size() - 1]
			if start < 0 or q.x < (lines[start][0] if not rev else lines[start][lines[start].size() - 1]).x:
				start = li
				rev = e == 1
	var path := PackedVector3Array()
	var used := {start: true}
	var cur: PackedVector3Array = lines[start].duplicate()
	if rev:
		cur.reverse()
	path.append_array(cur)
	while true:
		var end := path[path.size() - 1]
		var d := (end - path[maxi(path.size() - 3, 0)])
		d.y = 0.0
		d = d.normalized()
		var best := -1
		var best_dot := 0.7
		var best_rev := false
		for li in lines.size():
			if used.has(li):
				continue
			var pl: PackedVector3Array = lines[li]
			for e in 2:
				var a: Vector3 = pl[0] if e == 0 else pl[pl.size() - 1]
				var b: Vector3 = pl[mini(2, pl.size() - 1)] if e == 0 else pl[maxi(pl.size() - 3, 0)]
				if Vector2(a.x - end.x, a.z - end.z).length() > 1.5:
					continue
				var nd := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
				if nd.dot(d) > best_dot:
					best_dot = nd.dot(d)
					best = li
					best_rev = e == 1
		if best < 0:
			break
		used[best] = true
		var nxt: PackedVector3Array = lines[best].duplicate()
		if best_rev:
			nxt.reverse()
		path.append_array(nxt.slice(1))
	# Junat eivät aja Oulujoen ratasillalle: reitti alkaa TRAIN_WEST_MARGIN m sillan itäpään (kiskot reilusti maan
	# yläpuolella tai veden päällä) jälkeen. Asema on lähellä radan länsipäätä, ja muuten saapuva juna ilmestyisi
	# ja lähtevä katoaisi sillalla tien vieressä.
	var ast = data.get("keskusta", {}).get("asema")
	if ast != null:
		var west := INF
		for q in ast.platform:
			west = minf(west, float(q[0]))
		var last := -1
		for i in path.size():
			var q: Vector3 = path[i]
			if q.x >= west:
				break
			if code_at(q.x, q.z) == WATER or q.y - h(q.x, q.z) > 2.0:
				last = i
		if last >= 0:
			var cut := last
			while cut < path.size() - 2 and path[cut].distance_to(path[last]) < TRAIN_WEST_MARGIN and path[cut + 1].x < west:
				cut += 1
			path = path.slice(cut)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	if total < 300.0:
		return
	train = load("res://scripts/train.gd").new()
	train.name = "Juna"
	add_child(train)
	train.setup(path)
	if station_plat != Vector3.ZERO:
		station_t = train.nearest_t(station_plat)
	print("VAALA juna: rata %.0f m, %d pätkää, laituri %.0f m radan alusta" % [total, used.size(), station_t])


## Radan alikulku (Vuolijoentie radan ali juuri ennen Oulujokea) ohikulkuvideon mukaan: harmaa betonikansi ohuine
## reunapalkkeineen ja teräskaiteineen, tien molemmin puolin hoikka pilaripari poikkipalkin kanssa, ja kannen päät
## maatukien varassa ratapenkereen luiskien päällä (ei pystymuureja: penger laskee luiskana tien tasoon). Alikulku-
## korkeuden kilpi kannen reunoissa. Penger, luiskat ja kiskot ovat leivonnassa (vaala_bake.py UNDER_OPEN, UNDER_SLOPE).
var underpass_i := -1
const UNDER_PIER := 2.4  # pilarit vähintään näin kauas ajoradan reunasta
const DECK_W := 6.4      # kannen leveys radan poikki
const PIER_R := 0.42     # pyöreä pilari


func _build_underpass() -> void:
	var u = data.get("underpass")
	if u == null:
		return
	var i: int = u.i
	underpass_i = i
	var at := road_pos(i)
	at.y = float(u.road_y)
	var rd := Vector3(u.dir[0], 0, u.dir[1]).normalized()
	var fd := road_dir(i)
	var sin_a := maxf(absf(rd.cross(fd).y), 0.35)
	var hw: float = u.hw
	var deck: float = u.deck
	var H := deck - 0.1 - at.y
	var conc := Color(0.7, 0.69, 0.66)
	var under := Color(0.5, 0.5, 0.48)
	var steel := Color(0.42, 0.44, 0.45)
	# Kansi radan suuntaan luiskan yläpäähän asti (tien keskilinjasta aukko + luiska).
	var reach: float = hw + float(u.get("open", 13.0)) + H / float(u.get("slope", 0.55)) + 1.5
	var dl := reach / sin_a * 2.0
	var basis := Basis(Vector3.UP, atan2(rd.x, rd.z))
	var deck_c := Vector3(at.x, deck - 0.45, at.z)
	var slab := B.mesh(self, B.boxm(Vector3(DECK_W - 0.6, 0.7, dl)), deck_c, under)
	slab.basis = basis
	# Reunapalkit: vaalea betoni kannen pinnan yläpuolelle, alareuna laatan alle.
	for e: float in [-1.0, 1.0]:
		var em := B.mesh(self, B.boxm(Vector3(0.36, 1.25, dl)), deck_c + basis.x * e * (DECK_W / 2.0 - 0.18) + Vector3(0, 0.12, 0), conc)
		em.basis = basis
		# Kaide: tolpat 1,6 m välein, käsijohde ja välijohde.
		var gp := deck_c + basis.x * e * (DECK_W / 2.0 - 0.18) + Vector3(0, 0.75, 0)
		for k2 in int(dl / 1.6) + 1:
			var pp: Vector3 = gp - basis.z * dl / 2.0 + basis.z * k2 * 1.6 + Vector3(0, 0.55, 0)
			B.mesh(self, B.boxm(Vector3(0.07, 1.1, 0.07)), pp, steel)
		for ry: float in [1.1, 0.55]:
			var rt := gp + Vector3(0, ry, 0)
			B.tube(self, rt - basis.z * dl / 2.0, rt + basis.z * dl / 2.0, 0.035, steel)
	# Pilaririvit tien molemmin puolin: kaksi pyöreää pilaria kannen leveydellä ja poikkipalkki. Paikka haetaan radan
	# akselilta mittaamalla todellinen etäisyys tien keskilinjaan (tie kaartaa alikulussa): kumpikaan pilari ei osu
	# kaistalle eikä pientareelle.
	var pier_body := StaticBody3D.new()
	add_child(pier_body)
	var road_dist := func(q: Vector3) -> float:
		var best := INF
		for k in range(maxi(i - 40, 0), mini(i + 40, road.size() - 1)):
			var pa := road_pos(k)
			var pb := road_pos(k + 1)
			var c := Geometry2D.get_closest_point_to_segment(Vector2(q.x, q.z), Vector2(pa.x, pa.z), Vector2(pb.x, pb.z))
			best = minf(best, c.distance_to(Vector2(q.x, q.z)))
		return best
	var cols_x: Array[float] = [-(DECK_W / 2.0 - 1.0), DECK_W / 2.0 - 1.0]
	for s: float in [-1.0, 1.0]:
		var along := 0.0
		while along < 40.0:
			var ok := true
			for w: float in cols_x:
				var q := Vector3(at.x, 0, at.z) + basis.z * along * s + basis.x * w
				if road_dist.call(q) < hw + UNDER_PIER + PIER_R:
					ok = false
			if ok:
				break
			along += 0.25
		var row := Vector3(at.x, 0, at.z) + basis.z * along * s
		for w: float in cols_x:
			var pp := row + basis.x * w
			var gy := minf(h(pp.x, pp.z), at.y) - 0.3
			var ph := deck - 1.45 - gy
			B.mesh(self, B.cyl(PIER_R, PIER_R, ph, 14), Vector3(pp.x, gy + ph / 2.0, pp.z), conc)
			var pcs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = PIER_R
			cyl.height = ph
			pcs.shape = cyl
			pcs.position = Vector3(pp.x, gy + ph / 2.0, pp.z)
			pier_body.add_child(pcs)
		var bm := B.mesh(self, B.boxm(Vector3(DECK_W - 0.4, 0.6, 1.1)), Vector3(row.x, deck - 1.15, row.z), conc)
		bm.basis = basis
	# Maatuet kannen päissä luiskan päällä (osin maan sisällä).
	for s: float in [-1.0, 1.0]:
		var ab := Vector3(at.x, deck - 1.5, at.z) + basis.z * s * (dl / 2.0 - 0.7)
		var am := B.mesh(self, B.boxm(Vector3(DECK_W + 0.6, 2.2, 1.4)), ab, conc.darkened(0.08))
		am.basis = basis
	# Alikulkukorkeus kannen reunaan molempiin ajosuuntiin.
	for s: float in [-1.0, 1.0]:
		var plate := B.sign_plate(self, "4,6 m", Color(0.98, 0.98, 0.95), Color(0.05, 0.05, 0.05), 0.4, 60, Color(0.85, 0.1, 0.08), "Helvetica Neue")
		plate.position = at - fd * s * (DECK_W / 2.0 / sin_a + 0.1) + Vector3(0, H - 1.05, 0)
		plate.rotation.y = atan2(-fd.x * s, -fd.z * s)


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
		var cen := Vector2.ZERO
		for q in pts:
			cen += q
		if (cen / pts.size()).distance_to(_mokki_c()) < MOKKI_CLEAR_R:
			continue  # mökin pihapiiri tehdään mökin malleilla (_build_mokki_yard)
		if bd.kind == "shed" and _zabuki != Vector3.INF and (cen / pts.size()).distance_to(Vector2(_zabuki.x, _zabuki.z)) < 5.0:
			continue  # torin kioskin paikalla on Zabuki (_build_tori)
		if id == SIITARI_ID:
			_build_siitari(pts, body)
			continue
		if id == station_id:
			continue  # asemarakennus omalla mallillaan (_build_station)
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
		elif id == GASTHAUS_ID:
			col = Color(0.93, 0.84, 0.6)  # keltainen rappaus, valkoiset nurkat kuin vanhassa majatalossa
			mat = PLASTER
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
			var door := _door(obb, base + 0.3) if id != GASTHAUS_ID else \
				(obb.center as Vector2) + _gasthaus_side(obb) * ((obb.size as Vector2).y / 2.0 + 0.05)
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
		if id == GASTHAUS_ID:
			_gasthaus_front(obb, base, top)
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
			kmarket_center = Vector3((obb.center as Vector2).x, 0, (obb.center as Vector2).y)
			kmarket_half = (obb.size as Vector2) / 2.0
			var ay: Vector2 = obb.ay
			var face: Vector2 = ay if ay.dot(kd - (obb.center as Vector2)) >= 0.0 else -ay
			kmarket_face = Vector3(face.x, 0, face.y)
			doors.append({"id": "kmarket", "pos": kmarket_door, "out": kmarket_out, "hint": "K-Market Tervaporttiin (myös Alko)"})
		if name != "" and not church:
			var fg := Color(0.98, 0.95, 0.85)
			var bg := Color(0.12, 0.2, 0.35)
			if name.contains("K-Market") or name.contains("K-MARKET"):
				bg = Color(0.9, 0.35, 0.05)
			elif station:
				name = "VAALA"
				bg = Color(0.95, 0.95, 0.95)
				fg = Color(0.1, 0.1, 0.1)
			var big_sign := kind == "big" or station or name == "K-MARKET TERVAPORTTI"
			var plate := B.sign_plate(self, name, bg, fg, (0.9 if name == "K-MARKET TERVAPORTTI" else 0.5) if big_sign else 0.35,
				60 if big_sign else 44,
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


# --- Vaalan tori: Zabuki ja Gasthaus ------------------------------------------------------------------------
## Gasthaus (OSM 534430535, huone yöksi kympillä, main.gd "gasthaus") on Siitaria vastapäätä tien toisella
## puolella ja Zabuki (baaritiski luukulla, olutta ja hampurilaisia, main.gd "zabuki") sen vieressä, molemmat
## julkisivu tielle. Tori ("Vaalan tori") on niiden takana, ja sinne vie asfalttitie Zabukin vierestä
## (tools/vaala_keskusta.py; paikat ja julkisivut tie.json:n "keskusta"-osassa). Tori kivetään ja sille tulee kojuja.
const GASTHAUS_ID := 534430535
var _tori := PackedVector2Array()
var _tori_c := Vector2.ZERO
var _zabuki := Vector3.INF  # Zabukin keskipiste maan tasossa; INF = toria ei ole datassa
var _zabuki_face := Vector2.ZERO  # julkisivu (tiski) torille päin


func _tori_prep() -> void:
	for r in data.side_roads:
		if r.name == "Vaalan tori":
			for q in r.pts:
				_tori.append(Vector2(q[0], q[1]))
	if _tori.size() < 3:
		return
	if _tori[0].distance_to(_tori[_tori.size() - 1]) < 0.01:
		_tori.remove_at(_tori.size() - 1)
	for q in _tori:
		_tori_c += q
	_tori_c /= _tori.size()
	var kz = data.get("keskusta", {}).get("zabuki")
	if kz != null:
		_zabuki = Vector3(kz.c[0], h(kz.c[0], kz.c[1]), kz.c[1])
		_zabuki_face = Vector2(kz.face[0], kz.face[1]).normalized()
		return
	var at := Vector2.INF
	for bd in data.buildings:
		if bd.kind != "shed":
			continue
		var c := Vector2.ZERO
		for q in bd.pts:
			c += Vector2(q[0], q[1])
		c /= bd.pts.size()
		if c.distance_to(_tori_c) < 30.0 and c.distance_to(_tori_c) < at.distance_to(_tori_c):
			at = c
	if at == Vector2.INF:
		at = _tori_c + Vector2(0, -12.0)  # ei kioskia: torin pohjoislaidalle
	_zabuki = Vector3(at.x, h(at.x, at.y), at.y)
	_zabuki_face = (_tori_c - at).normalized()


## Rautatieasema radan varressa Siitarin kaakkoispuolella, liikenneympyrästä oikealle Ratatietä ja aseman ajotietä
## (vaala_keskusta.py place_station; oikea asema jää piirtämättä): keltainen puinen asemarakennus valkoisine
## nurkkalautoineen ja ikkunanpuitteineen, punainen harjakatto, laiturin puolella katos, VAALA-kyltti, betonilaituri
## valkoisella reunaviivalla, penkit ja valaisimet sekä asemaraiteen puskimet. Ovi päädyssä (E: junalla Saloisiin).
## Lisäksi Vaalantien liikenneympyrä: asfalttirengas ja reunakivetty nurmisaareke.
var station_door := Vector3.ZERO
var station_plat := Vector3.ZERO  # laiturin keskikohta (aikataulun juna pysähtyy tähän)
var station_t := 0.0  # laiturin kohta junan reitillä (train.nearest_t)
var station_id: int = -1  # keskusta.asema.id: tämän rakennuksen paikalle asema (yleinen piirto ohittaa)


func _build_station() -> void:
	var st = data.get("keskusta", {}).get("asema")
	if st == null:
		return
	# Liikenneympyrä.
	var rb: Dictionary = st.roundabout
	var rc := Vector2(rb.c[0], rb.c[1])
	var rr: float = rb.r
	var ring := SurfaceTool.new()
	ring.begin(Mesh.PRIMITIVE_TRIANGLES)
	var isle := SurfaceTool.new()
	isle.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kerb := SurfaceTool.new()
	kerb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	var inner := rr - 6.5
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var p := func(r: float, a: float, lift: float) -> Vector3:
			var q := rc + Vector2.from_angle(a) * r
			return Vector3(q.x, h(q.x, q.y) + lift, q.y)
		_quad(ring, p.call(inner, a0, 0.06), p.call(rr, a0, 0.06), p.call(rr, a1, 0.06), p.call(inner, a1, 0.06))
		for v in [p.call(0.0, 0.0, 0.25), p.call(inner - 0.2, a0, 0.2), p.call(inner - 0.2, a1, 0.2)]:
			isle.add_vertex(v)
		_quad(kerb, p.call(inner - 0.2, a0, 0.2), p.call(inner, a0, 0.06), p.call(inner, a1, 0.06), p.call(inner - 0.2, a1, 0.2))
	ring.generate_normals()
	var rm := MeshInstance3D.new()
	rm.mesh = ring.commit()
	rm.material_override = _rmats.get("asphalt", B.mat(Color(0.24, 0.24, 0.25)))
	add_child(rm)
	kerb.generate_normals()
	var km := MeshInstance3D.new()
	km.mesh = kerb.commit()
	var kmat := B.mat(Color(0.7, 0.7, 0.68)).duplicate() as StandardMaterial3D
	kmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	km.material_override = kmat
	add_child(km)
	isle.generate_normals()
	var im := MeshInstance3D.new()
	im.mesh = isle.commit()
	im.material_override = B.mat(Color(0.32, 0.46, 0.2))
	add_child(im)
	var rsign := B.sign_pole(self, Vector3(rc.x, h(rc.x, rc.y) + 0.2, rc.y), 2.0)
	var rplate := B.sign_plate(rsign, "↻", Color(0.1, 0.3, 0.65), Color.WHITE, 0.6, 80, Color.WHITE, "Helvetica Neue")
	rplate.position.y = 1.8
	# Asemarakennus.
	var pts := PackedVector2Array()
	for q in st.pts:
		pts.append(Vector2(q[0], q[1]))
	var obb := _obb(pts)
	var c: Vector2 = obb.center
	var along := Vector2(st.along[0], st.along[1])
	var plat_c := Vector2.ZERO
	for q in st.platform:
		plat_c += Vector2(q[0], q[1])
	plat_c /= float(st.platform.size())
	station_plat = Vector3(plat_c.x, h(plat_c.x, plat_c.y), plat_c.y)
	if train != null:  # juna rakennetaan jo raiteiden kanssa (_build_side_roads)
		station_t = train.nearest_t(station_plat)
		print("VAALA laituri %.0f m radan alusta" % station_t)
	var back := (plat_c - c).normalized()  # laiturin puoli
	var L: float = (obb.size as Vector2).x if absf((obb.ax as Vector2).dot(along)) > 0.7 else (obb.size as Vector2).y
	var D: float = (obb.size as Vector2).y if absf((obb.ax as Vector2).dot(along)) > 0.7 else (obb.size as Vector2).x
	var base := INF
	for q in pts:
		base = minf(base, h(q.x, q.y))
	var root := Node3D.new()
	root.position = Vector3(c.x, base, c.y)
	root.basis = Basis.looking_at(Vector3(back.x, 0, back.y), Vector3.UP)  # -Z laiturille, X radan suuntaan
	add_child(root)
	var body := StaticBody3D.new()
	root.add_child(body)
	var ochre := Color(0.86, 0.66, 0.3)
	var white := Color(0.95, 0.94, 0.9)
	var roof := Color(0.55, 0.12, 0.08)
	var wall_h := 4.0
	B.mesh(root, B.boxm(Vector3(L + 0.4, 0.5, D + 0.4)), Vector3(0, 0.0, 0), Color(0.55, 0.54, 0.5))  # sokkeli
	B.mesh(root, B.boxm(Vector3(L, wall_h, D)), Vector3(0, 0.25 + wall_h / 2.0, 0), ochre)
	body.add_child(B.box_shape(Vector3(L, wall_h, D), Vector3(0, wall_h / 2.0, 0)))
	for cx: float in [-L / 2.0, L / 2.0]:
		for cz: float in [-D / 2.0, D / 2.0]:
			B.mesh(root, B.boxm(Vector3(0.22, wall_h, 0.22)), Vector3(cx, 0.25 + wall_h / 2.0, cz), white)  # nurkkalaudat
	B.mesh(root, B.boxm(Vector3(L + 0.1, 0.25, D + 0.1)), Vector3(0, 0.25 + wall_h, 0), white)  # räystäslista
	# Harjakatto: kaksi lappeen laattaa, harja radan suuntaan; laiturin puolella pidempi katos pilareilla.
	var pitch := 0.5
	var span := D / 2.0 + 0.8
	var ridge := 0.25 + wall_h + span * tan(pitch) + 0.1
	for sz: float in [-1.0, 1.0]:
		var rl := B.mesh(root, B.boxm(Vector3(L + 1.2, 0.18, span / cos(pitch))), Vector3(0, ridge - span * tan(pitch) / 2.0, sz * span / 2.0), roof)
		rl.rotation.x = sz * pitch
	B.mesh(root, B.boxm(Vector3(L + 1.2, 0.2, 0.3)), Vector3(0, ridge + 0.05, 0), roof.darkened(0.2))
	# Päätykolmiot seinän ja katon väliin.
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
	# Laiturikatos: loiva lippa seinästä pilareille.
	var canopy := B.mesh(root, B.boxm(Vector3(L + 0.4, 0.15, 4.4)), Vector3(0, 0.25 + wall_h - 0.25, -D / 2.0 - 2.2), roof)
	canopy.rotation.x = -0.08
	for k in 5:
		var px := -L / 2.0 + 1.0 + k * (L - 2.0) / 4.0
		B.mesh(root, B.boxm(Vector3(0.16, wall_h - 0.4, 0.16)), Vector3(px, 0.25 + (wall_h - 0.4) / 2.0, -D / 2.0 - 3.6), white)
	# Ikkunat ja ovet: valkoiset puitteet, laiturin puolella ovi keskellä.
	for sz: float in [-1.0, 1.0]:
		for k in 5:
			var wx := -L / 2.0 + 2.0 + k * (L - 4.0) / 4.0
			if k == 2:  # ovet keskellä: laiturille ja kadulle (E: junalla Saloisiin)
				B.mesh(root, B.boxm(Vector3(1.3, 2.3, 0.08)), Vector3(wx, 1.4, sz * (D / 2.0 + 0.03)), Color(0.45, 0.25, 0.12))
				continue
			B.mesh(root, B.boxm(Vector3(1.15, 1.45, 0.06)), Vector3(wx, 2.2, sz * (D / 2.0 + 0.03)), white)
			B.mesh(root, B.boxm(Vector3(0.95, 1.25, 0.07)), Vector3(wx, 2.2, sz * (D / 2.0 + 0.04)), Color(0.12, 0.16, 0.2))
			B.mesh(root, B.boxm(Vector3(0.06, 1.25, 0.09)), Vector3(wx, 2.2, sz * (D / 2.0 + 0.05)), white)
	# Kyltti VAALA laiturille ja kadulle.
	for sz: float in [-1.0, 1.0]:
		var sign := B.sign_plate(root, "VAALA", Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.1), 0.7, 80, Color(0.1, 0.1, 0.1), "Helvetica Neue")
		sign.position = Vector3(0, 3.6, sz * (D / 2.0 + 0.08))
		sign.rotation.y = 0.0 if sz > 0.0 else PI
	var dp := Vector2(st.door[0], st.door[1])
	var dout := Vector3(st.out[0], 0, st.out[1])
	station_door = Vector3(dp.x, h(dp.x, dp.y), dp.y) + dout * 2.2
	doors.append({"id": "asema", "pos": station_door, "out": dout, "hint": "asemalle (juna Saloisiin 10 €)"})
	# Laituri: betonilaatta reunaviivoineen, penkit ja valaisimet.
	var ppts := PackedVector2Array()
	for q in st.platform:
		ppts.append(Vector2(q[0], q[1]))
	var pob := _obb(ppts)
	var pc: Vector2 = pob.center
	var ph := h(pc.x, pc.y)
	var proot := Node3D.new()
	proot.position = Vector3(pc.x, ph, pc.y)
	proot.basis = root.basis
	add_child(proot)
	var PL: float = maxf((pob.size as Vector2).x, (pob.size as Vector2).y)
	var PW: float = minf((pob.size as Vector2).x, (pob.size as Vector2).y)
	B.mesh(proot, B.boxm(Vector3(PL, 0.55, PW)), Vector3(0, 0.0, 0), Color(0.62, 0.61, 0.58))
	B.mesh(proot, B.boxm(Vector3(PL, 0.02, 0.15)), Vector3(0, 0.29, -PW / 2.0 + 0.35), white)
	var pbody := StaticBody3D.new()
	proot.add_child(pbody)
	pbody.add_child(B.box_shape(Vector3(PL, 0.55, PW), Vector3.ZERO))
	for k in int(PL / 14.0):
		var bx := -PL / 2.0 + 7.0 + k * 14.0
		B.mesh(proot, B.boxm(Vector3(1.8, 0.08, 0.45)), Vector3(bx, 0.72, PW / 2.0 - 0.6), Color(0.45, 0.3, 0.18))
		B.mesh(proot, B.boxm(Vector3(1.8, 0.45, 0.06)), Vector3(bx, 0.98, PW / 2.0 - 0.38), Color(0.45, 0.3, 0.18))
		B.mesh(proot, B.cyl(0.06, 0.06, 4.0, 8), Vector3(bx + 3.5, 2.27, 0.2), Color(0.3, 0.3, 0.32))
		var lamp := B.mesh(proot, B.boxm(Vector3(0.5, 0.15, 0.3)), Vector3(bx + 3.5, 4.25, 0.2), Color(1.0, 0.92, 0.7))
		lamp.material_override = B.unshaded(Color(1.0, 0.92, 0.7))
	# Puskimet asemaraiteen päihin (jos asemalla on oma pistoraide).
	var tr: Array = st.track
	if tr.size() < 2:
		return
	var t0 := Vector2(tr[0][0], tr[0][1])
	var t1 := Vector2(tr[1][0], tr[1][1])
	for e in 2:
		var at := t0 if e == 0 else t1
		var inward := (t1 - t0).normalized() * (1.0 if e == 0 else -1.0)
		var bs := Node3D.new()
		var y := maxf(h(at.x, at.y), water_level + 3.0)
		bs.position = Vector3(at.x, y, at.y) + Vector3(inward.x, 0, inward.y) * 1.0
		bs.basis = Basis.looking_at(Vector3(inward.x, 0, inward.y), Vector3.UP)
		add_child(bs)
		B.mesh(bs, B.boxm(Vector3(2.6, 0.5, 0.4)), Vector3(0, 1.0, 0), Color(0.8, 0.1, 0.08))
		for sx: float in [-0.75, 0.75]:
			B.mesh(bs, B.boxm(Vector3(0.18, 1.1, 0.18)), Vector3(sx, 0.55, 0), Color(0.25, 0.25, 0.25))
			B.mesh(bs, B.cyl(0.18, 0.18, 0.3, 12), Vector3(sx, 1.0, -0.3), Color(0.3, 0.3, 0.3), Vector3(90, 0, 0))
		for k in 4:
			B.mesh(bs, B.boxm(Vector3(0.3, 0.5, 0.42)), Vector3(-1.05 + k * 0.7, 1.0, 0.01), Color(0.95, 0.95, 0.95) if k % 2 == 0 else Color(0.8, 0.1, 0.08))


func _build_tori() -> void:
	if _zabuki == Vector3.INF:
		return
	# Kiveys: harmaa noppakivi kävelyalueen muodossa.
	var tris := Geometry2D.triangulate_polygon(_tori)
	if not tris.is_empty():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for t in range(0, tris.size(), 3):
			_drape(st, _tori[tris[t]], _tori[tris[t + 1]], _tori[tris[t + 2]])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _ground_mat(Color(0.56, 0.55, 0.52), Color(0.46, 0.45, 0.43), 0.9, 2.5)
		mi.position.y = 0.02  # parkkien yläpuolelle
		add_child(mi)
	_build_stalls()
	_build_zabuki()


## Torikojut torin keskelle riviin: pöytä, neljä tolppaa ja raidallinen katos, kojuittain eri värit.
func _build_stalls() -> void:
	var ax := (_tori[1] - _tori[0]).normalized()
	var ay := ax.orthogonal()
	var yaw := atan2(ax.y, ax.x)
	var deg := -rad_to_deg(yaw)
	var cols := [Color(0.75, 0.1, 0.1), Color(0.1, 0.35, 0.7), Color(0.15, 0.5, 0.2), Color(0.9, 0.6, 0.1)]
	var body := StaticBody3D.new()
	add_child(body)
	# Kojut riviin torin pituussuunnassa 6 m välein: tien pihalenkki kulkee torin halki, joten kojut väistävät
	# ajorataa (3,5 m reunasta) ja Zabukin edustaa.
	var spots: Array[Vector2] = []
	for side: float in [2.0, -4.0, 8.0]:
		var off := -30.0
		while off <= 30.0 and spots.size() < 4:
			var c := _tori_c + ax * off + ay * side
			var ni := nearest(Vector3(c.x, 0, c.y))
			var clear: bool = ni[0] < 0 or ni[1] > float(road[ni[0]][4]) + 3.5
			if clear and _zabuki != Vector3.INF:
				clear = c.distance_to(Vector2(_zabuki.x, _zabuki.z)) > 9.0
			for o in spots:
				clear = clear and (absf((c - o).dot(ax)) >= 4.0 or absf((c - o).dot(ay)) >= 5.0)
			for q in [ax * 2.0, -ax * 2.0, ay * 1.5, -ay * 1.5]:
				clear = clear and Geometry2D.is_point_in_polygon(c + q, _tori)
			if clear:
				spots.append(c)
			off += 0.5
	for k in spots.size():
		var c := spots[k]
		var y := h(c.x, c.y)
		var at := func(u: float, v: float, up: float) -> Vector3:
			var q: Vector2 = c + ax * u + ay * v
			return Vector3(q.x, y + up, q.y)
		B.mesh(self, B.boxm(Vector3(3.0, 0.08, 1.4)), at.call(0, 0, 0.85), Color(0.55, 0.4, 0.25), Vector3(0, deg, 0))
		B.mesh(self, B.boxm(Vector3(3.0, 0.8, 0.06)), at.call(0, -0.68, 0.43), Color(0.45, 0.32, 0.2), Vector3(0, deg, 0))
		for u in [-1.4, 1.4]:
			for v in [-0.65, 0.65]:
				B.mesh(self, B.cyl(0.04, 0.04, 2.3, 6), at.call(u, v, 1.15), Color(0.85, 0.85, 0.82))
		for s in 6:
			B.mesh(self, B.boxm(Vector3(0.52, 0.05, 1.7)), at.call(-1.3 + s * 0.52, 0, 2.32),
				cols[k] if s % 2 == 0 else Color(0.97, 0.96, 0.92), Vector3(0, deg, 0))
		# Myytävää: laatikoita pöydällä.
		for u in [-0.9, 0.0, 0.9]:
			B.mesh(self, B.boxm(Vector3(0.6, 0.18, 0.4)), at.call(u, -0.2, 0.98), cols[(k + int(u + 1.0)) % 4].lightened(0.3), Vector3(0, deg, 0))
		var cs := B.box_shape(Vector3(3.0, 1.0, 1.4), Vector3.ZERO)
		cs.transform = Transform3D(Basis(Vector3.UP, -yaw), at.call(0, 0, 0.5))
		body.add_child(cs)


## Zabuki: matala tumma kioskibaari, punakeltainen markiisi, tiski luukulla ja baarijakkarat torin puolella.
func _build_zabuki() -> void:
	var f := _zabuki_face
	var ax := Vector2(-f.y, f.x)
	var c := Vector2(_zabuki.x, _zabuki.z)
	var base := INF
	for u in [-4.5, 4.5]:
		for v in [-3.0, 3.0]:
			var q: Vector2 = c + ax * u + f * v
			base = minf(base, h(q.x, q.y))
	base -= 0.2
	var yaw := atan2(f.x, f.y)
	var deg := rad_to_deg(yaw)
	var at := func(u: float, v: float, y: float) -> Vector3:
		var q := c + ax * u + f * v
		return Vector3(q.x, base + y, q.y)
	var wall := Color(0.14, 0.14, 0.16)
	var red := Color(0.72, 0.08, 0.06)
	var yel := Color(1.0, 0.78, 0.1)
	var steel := Color(0.7, 0.72, 0.74)
	# Runko 9 x 5 m, tasakatto ja katon reunan valokyltti.
	B.mesh(self, B.boxm(Vector3(9.0, 3.3, 5.0)), at.call(0, -0.5, 1.65), wall, Vector3(0, deg, 0))
	B.mesh(self, B.boxm(Vector3(9.3, 0.25, 5.3)), at.call(0, -0.5, 3.4), Color(0.1, 0.1, 0.11), Vector3(0, deg, 0))
	var logo := B.sign_plate(self, "ZABUKI", red, yel, 1.0, 110, Color(0.3, 0.02, 0.02), "Helvetica Neue")
	logo.position = at.call(0, 2.08, 3.95)
	logo.rotation.y = yaw
	# Tiskiluukku: valoisa aukko, teräksinen tiski ja markiisi.
	B.mesh(self, B.boxm(Vector3(5.6, 1.3, 0.06)), at.call(-0.6, 2.0, 1.85), Color(1.0, 0.86, 0.55), Vector3(0, deg, 0)).material_override = 		B.unshaded(Color(1.0, 0.86, 0.55))
	B.mesh(self, B.boxm(Vector3(6.0, 0.08, 0.7)), at.call(-0.6, 2.25, 1.12), steel, Vector3(0, deg, 0))
	B.mesh(self, B.boxm(Vector3(6.0, 1.08, 0.12)), at.call(-0.6, 2.05, 0.54), Color(0.2, 0.2, 0.22), Vector3(0, deg, 0))
	for k in 6:
		B.mesh(self, B.boxm(Vector3(1.0, 0.08, 1.4)), at.call(-3.1 + k, 2.7, 2.9), red if k % 2 == 0 else yel,
			Vector3(-18.0, deg, 0))
	var menu := B.sign_plate(self, "BURGERIT · OLUT", Color(0.08, 0.08, 0.08), yel, 0.32, 40, Color(0.9, 0.7, 0.1), "Helvetica Neue")
	menu.position = at.call(3.4, 2.06, 2.1)
	menu.rotation.y = yaw
	# Hampurilainen kyltissä: sämpylä, pihvi ja juusto.
	var bun := Color(0.85, 0.55, 0.22)
	B.mesh(self, B.cyl(0.32, 0.36, 0.16, 16), at.call(3.4, 2.15, 2.85), bun)
	B.mesh(self, B.cyl(0.37, 0.37, 0.08, 16), at.call(3.4, 2.15, 2.73), Color(0.35, 0.18, 0.1))
	B.mesh(self, B.boxm(Vector3(0.62, 0.03, 0.62)), at.call(3.4, 2.15, 2.78), yel, Vector3(0, deg + 45.0, 0))
	B.mesh(self, B.cyl(0.36, 0.33, 0.12, 16), at.call(3.4, 2.15, 2.63), bun)
	# Baarijakkarat tiskin edessä ja kaksi seisomapöytää.
	for k in 5:
		var sp: Vector3 = at.call(-3.0 + k * 1.2, 2.85, 0.0)
		B.mesh(self, B.cyl(0.03, 0.03, 0.75, 6), sp + Vector3(0, 0.37, 0), steel)
		B.mesh(self, B.cyl(0.2, 0.2, 0.07, 12), sp + Vector3(0, 0.78, 0), red)
	for u in [-2.5, 2.5]:
		var tp: Vector3 = at.call(u, 6.0, 0.0)
		B.mesh(self, B.cyl(0.05, 0.05, 1.05, 8), tp + Vector3(0, 0.52, 0), steel)
		B.mesh(self, B.cyl(0.4, 0.4, 0.04, 14), tp + Vector3(0, 1.06, 0), Color(0.85, 0.85, 0.82))
	var body := StaticBody3D.new()
	add_child(body)
	var cs := B.box_shape(Vector3(9.0, 3.6, 5.6), Vector3.ZERO)
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), at.call(0, -0.3, 1.8))
	body.add_child(cs)
	var front: Vector3 = at.call(-0.6, 4.6, 0.0)
	front.y = h(front.x, front.z)
	doors.append({"id": "zabuki", "pos": front, "out": Vector3(f.x, 0, f.y), "hint": "Zabukin tiskille (olut ja hampurilaiset)"})


## Gasthaus: kyltti ja ovi tien (Siitarin) puoleiselle pitkälle sivulle, "Huoneet 10 €" oven pieleen.
func _gasthaus_front(obb: Dictionary, base: float, top: float) -> void:
	var c: Vector2 = obb.center
	var side := _gasthaus_side(obb)
	var ax: Vector2 = obb.ax
	var hy: float = (obb.size as Vector2).y / 2.0
	var dq := c + side * (hy + 0.05)
	var yaw := atan2(side.x, side.y)
	var y := maxf(h(dq.x, dq.y) + 0.1, base + 0.2)
	_doors.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(dq.x, y, dq.y)))
	var lamp := B.mesh(self, B.sphere(0.12, 8), Vector3(dq.x, y + 2.5, dq.y) + Vector3(side.x, 0, side.y) * 0.3, Color.WHITE)
	lamp.material_override = B.unshaded(Color(1.0, 0.85, 0.55))
	var plate := B.sign_plate(self, "GASTHAUS", Color(0.16, 0.24, 0.16), Color(0.98, 0.9, 0.62), 0.8, 90,
		Color(0.6, 0.5, 0.2), "Georgia")
	var sp := c + side * (hy + 0.12)
	plate.position = Vector3(sp.x, minf(top - 0.9, base + 4.6), sp.y)
	plate.rotation.y = yaw
	var price := B.sign_plate(self, "HUONEET 10 €", Color(0.95, 0.93, 0.86), Color(0.16, 0.24, 0.16), 0.24, 36,
		Color(0.16, 0.24, 0.16), "Georgia")
	var pq := dq + ax * 1.0 + side * 0.08
	price.position = Vector3(pq.x, y + 1.6, pq.y)
	price.rotation.y = yaw
	var out := Vector3(side.x, 0, side.y)
	var front := Vector3(dq.x, h(dq.x, dq.y), dq.y) + out * 2.2
	doors.append({"id": "gasthaus", "pos": front, "out": out, "hint": "Gasthausiin (huone yöksi 10 €)"})


## Gasthausin julkisivun suunta (pitkän sivun normaali): tielle päin (tie.json), vanhassa datassa torille.
func _gasthaus_side(obb: Dictionary) -> Vector2:
	var ay: Vector2 = obb.ay
	var gf = data.get("keskusta", {}).get("gasthaus_face")
	var to_front: Vector2 = Vector2(gf[0], gf[1]) if gf != null else ((_tori_c - (obb.center as Vector2)) if _tori.size() >= 3 else ay)
	return ay if ay.dot(to_front) >= 0.0 else -ay


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
		for t in range(0, tris.size(), 3):
			_drape(st, pts[tris[t]], pts[tris[t + 1]], pts[tris[t + 2]])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := B.mat(Color(0.26, 0.26, 0.27)).duplicate() as StandardMaterial3D
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		add_child(mi)


## Kolmio maan pintaan: jaetaan alle 2 m:n paloiksi, jotta asfaltti myötäilee maastoa (maa ei pistä läpi).
func _drape(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2) -> void:
	var ab := a.distance_to(b)
	var bc := b.distance_to(c)
	var ca := c.distance_to(a)
	var m := maxf(ab, maxf(bc, ca))
	if m > 2.0:
		# Pisin sivu kahtia.
		if m == ab:
			var d := (a + b) / 2.0
			_drape(st, a, d, c)
			_drape(st, d, b, c)
		elif m == bc:
			var d := (b + c) / 2.0
			_drape(st, a, b, d)
			_drape(st, a, d, c)
		else:
			var d := (c + a) / 2.0
			_drape(st, a, b, d)
			_drape(st, d, b, c)
		return
	for p in [a, b, c]:
		st.add_vertex(Vector3(p.x, h(p.x, p.y) + 0.08, p.y))


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
	f.load_data(TREES, {} if _tree_clear.is_empty() else {"mask": _tree_clear, "x0": _x0, "z0": _z0, "cell": DRIVE_CELL,
		"nx": _dnx, "nz": _dnz})


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


# --- Neittävän järviseutu mopolla: Ranta-Rosvo, Salminen ja Keskimmäisen laavu ----------------------------------

## Mökin pohjoiset järvet ovat tässä maailmassa loivalla kuvauksella T (vaala_bake.py NL_*, tie.json mokki_map:
## todellinen karttapiste p -> c + (p - ref) * s). Tiet kuvataan T:llä, kohteet tehdään mökin rakennusfunktioilla
## 1:1 ankkuripisteen ympärille (rakennukset eivät veny):
## - Risteyksessä, jossa Siitariin käännytään oikealle, vasemmalle kääntyvä asfaltti (Neittäväntien haara) jatkuu
##   Nuojuankoskentienä pohjoiseen: varrella Ranta-Rosvo ja Taka-Salmisen uimaranta.
## - Samasta risteyksestä lähtee asfaltin yli suoraan soratie Keskimmäisen laavulle ja tynnyrisaunalle (pihaan asti
##   ajettava). Tiet tasoitetaan maastoon, metsä raivataan ja pinta on ajettavaa (drive_code, drivable).
const NUOJUA_Z := Vector2(-1560.0, -430.0)  # Nuojuankoskentie todellisessa kehyksessä tällä z-välillä (8794)
## Soratien kulku risteyksestä laavulle (pelin kehys): Etu-Salmisen itäpuolelta ja suon (Keskimmäisen etelärannan
## räme) itäpuolelta kaartaen laavun taakse. Päätepiste lasketaan laavun asettelusta (mokki.gd keskimmainen_layout).
const LAAVU_ROAD := [Vector2(-22, -280), Vector2(-40, -320), Vector2(-62, -360), Vector2(-82, -395), Vector2(-95, -425)]
const NORTH_ASPHALT_HALF := 3.0
const NORTH_GRAVEL_HALF := 2.2
const NORTH_SPUR_HALF := 1.8
var north_roads: Array = []  # {pts: PackedVector2Array (n. 4 m välein), half, asphalt: bool, name}
var north_areas: Array = []  # ajettavat ja raivatut pihat: PackedVector2Array-monikulmiot
var rosvo_pos := Vector3.ZERO
var beach_pos := Vector3.ZERO
var laavu_fire := Vector3.ZERO
var barrel_door := Vector3.ZERO
var _north_anchor := {}  # kohde -> [mökin paikallinen ankkuri, pelin piste]
var _tree_clear := PackedByteArray()  # DRIVE_CELL-ruudukko: 1 = puu pois (tiet ja pihat)


## Järviseudun tien nimi, jos p on sen päällä (mopomatkan HUD), muuten "".
func north_road_name(p: Vector3) -> String:
	for r in north_roads:
		var pts: PackedVector2Array = r.pts
		var q := Vector2(p.x, p.z)
		for i in pts.size() - 1:
			if q.distance_to(Geometry2D.get_closest_point_to_segment(q, pts[i], pts[i + 1])) < float(r.half) + 3.0:
				return r.name
	return ""


## Todellinen karttapiste mopomaailmaan järviseudun kuvauksella T.
func nl_t(p: Vector2) -> Vector2:
	var mm: Dictionary = data.mokki_map
	return Vector2(mm.c[0] + (p.x - mm.ref[0]) * mm.s[0], mm.c[1] + (p.y - mm.ref[1]) * mm.s[1])


## Mökin paikallinen piste p mopomaailmaan, kun kohde on ankkuroitu: mökin piste a on pelissä g (T:n kuva tai
## pelin rantaviivalle kohdistettu) ja kohteen osat siitä 1:1 (karttakehyksen suunnissa).
func _site_pt(a: Vector2, g: Vector2, p: Vector2) -> Vector2:
	var M: GDScript = load(MOKKI_PATH)
	return g + M.to_map2(p) - M.to_map2(a)


## Rantakohteen ankkuri pelin rantaviivalle: mökin rantapiste q (suunta järvelle d) kuvataan T:llä ja siitä
## kuljetaan järven suuntaan, kunnes vastaan tulee pelin vesi (tiivistetyn järven ranta ei osu T:n pisteeseen).
func _shore_anchor(q: Vector2, d: Vector2) -> Vector2:
	var M: GDScript = load(MOKKI_PATH)
	var dm := _site_dir(d).normalized()
	var start := nl_t(M.to_map2(q)) - dm * 40.0
	for k in 120:
		var p := start + dm * k
		if code_at(p.x, p.y) == WATER:
			return p - dm * 0.5
	return nl_t(M.to_map2(q))


## Mökin paikallinen suunta karttakehykseen.
func _site_dir(v: Vector2) -> Vector2:
	var M: GDScript = load(MOKKI_PATH)
	return M.to_map2(v) - M.to_map2(Vector2.ZERO)


## Polyline pehmeäksi (Chaikin) ja tasavälein näytteiksi.
static func _smooth_line(raw: Array, step := 4.0, rounds := 2) -> PackedVector2Array:
	var pts := PackedVector2Array(raw)
	for _r in rounds:
		var o := PackedVector2Array([pts[0]])
		for i in pts.size() - 1:
			o.append(pts[i].lerp(pts[i + 1], 0.25))
			o.append(pts[i].lerp(pts[i + 1], 0.75))
		o.append(pts[-1])
		pts = o
	var out := PackedVector2Array([pts[0]])
	var carry := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var L := a.distance_to(b)
		var t := step - carry
		while t <= L:
			out.append(a.lerp(b, t / L))
			t += step
		carry = L - (t - step)
	if out[-1].distance_to(pts[-1]) > 0.5:
		out.append(pts[-1])
	return out


## Tiet ja kohteiden ankkurit ennen maaston rakentamista: maasto tasoitetaan teiden kohdalta ja pinta merkitään
## tieksi (asfaltti ROAD, sora SHOULDER), puut raivataan teiltä ja pihoilta.
func _plan_north() -> void:
	var M: GDScript = load(MOKKI_PATH)
	var neitt: Dictionary = {}
	for br in data.branches:
		if br.name == "Neittäväntie":
			neitt = br
	if neitt.is_empty():
		push_warning("Neittäväntien haaraa ei löydy: järviseudun tiet jäävät pois")
		return
	var bp: Array = neitt.pts
	var junction := Vector2(bp[0][0], bp[0][2])
	var bend := Vector2(bp[-1][0], bp[-1][2])
	var bprev := Vector2(bp[-4][0], bp[-4][2])
	# Asfaltti: haaran päästä Nuojuankoskentietä pohjoiseen.
	var raw: Array = [bprev, bend]
	for r in M.map_data().roads:
		if r.name != "Nuojuankoskentie":
			continue
		for lp in r.pts:
			var mp: Vector2 = M.to_map2(lp)
			if mp.y > NUOJUA_Z.x and mp.y < NUOJUA_Z.y:
				raw.append(nl_t(mp))
		break
	var asphalt := _smooth_line(raw)
	asphalt.remove_at(0)  # haaran oma pätkä
	north_roads.append({"pts": asphalt, "half": NORTH_ASPHALT_HALF, "asphalt": true, "name": "Nuojuankoskentie"})
	# Ranta-Rosvo tien varressa: levike patsaan eteen.
	var ra: Vector2 = M.to_local2(M.ROSVO_MAP)
	var rg := nl_t(M.ROSVO_MAP)
	_north_anchor.rosvo = [ra, rg]
	var rface: Vector2 = M.to_local2(M.ROSVO_FACE_MAP) - M.to_local2(Vector2.ZERO)
	var rfront := _site_pt(ra, rg, ra + rface.normalized() * 2.5)
	north_roads.append({"pts": _smooth_line([_closest_on(asphalt, rfront), rfront], 2.0, 0), "half": NORTH_SPUR_HALF, "asphalt": false,
		"name": "Ranta-Rosvo"})
	north_areas.append(_circle(rfront, 4.0))
	# Uimaranta: rantapiste ankkurina, levike rannan puolelle.
	var bsh: Array = M.shore_near(M.BEACH_LAKE, M.to_local2(M.BEACH_MAP))
	if not bsh.is_empty():
		var q: Vector2 = bsh[0]
		var d: Vector2 = bsh[1]
		var bg := _shore_anchor(q, d)
		_north_anchor.beach = [q, bg]
		var bc := _site_pt(q, bg, q - d * 7.0)
		north_roads.append({"pts": _smooth_line([_closest_on(asphalt, bc), bc], 2.0, 0), "half": NORTH_SPUR_HALF, "asphalt": false,
			"name": "Salmisen uimaranta"})
		var ring := PackedVector2Array()
		for k in 16:
			var lp: Vector2 = q - d * 6.0 + d * cos(TAU * k / 16) * 6.0 + d.orthogonal() * sin(TAU * k / 16) * 9.0
			ring.append(_site_pt(q, bg, lp))
		north_areas.append(ring)
	# Soratie risteyksestä suoraan asfaltin yli laavulle; päättyy laavun ja saunan pihaan.
	var lay: Dictionary = M.keskimmainen_layout()
	if not lay.is_empty():
		var q: Vector2 = lay.q
		var d: Vector2 = lay.d
		var side: Vector2 = lay.side
		var lp: Vector2 = lay.laavu
		var lg := _shore_anchor(q, d)
		_north_anchor.laavu = [q, lg]
		var end := _site_pt(q, lg, lp - d * 6.0 + side * 2.6)
		var g: Array = [junction]
		g.append_array(LAAVU_ROAD)
		g.append(end)
		north_roads.append({"pts": _smooth_line(g), "half": NORTH_GRAVEL_HALF, "asphalt": false, "name": "Keskimmäisentie"})
		# Piha laavun takaa saunan ovelle ja rantaan: laavun ja saunan ympäri.
		var yard := PackedVector2Array()
		for c in [Vector2(-4.5, -7.0), Vector2(9.5, -7.0), Vector2(9.5, 11.0), Vector2(-4.5, 11.0)]:
			yard.append(_site_pt(q, lg, lp + side * c.x + d * c.y))
		north_areas.append(yard)
	_north_ground()


func _closest_on(line: PackedVector2Array, p: Vector2) -> Vector2:
	var best := line[0]
	for i in line.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])
		if c.distance_squared_to(p) < best.distance_squared_to(p):
			best = c
	return best


static func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 16:
		out.append(c + Vector2.from_angle(TAU * k / 16) * r)
	return out


## Teiden kohdalla maasto tasoitetaan tien suuntaan pehmennettyyn korkeuteen (poikkisuunnassa tasainen) ja pinta
## tieksi; raivausruudukko teille ja pihoille. Vesi, reitti ja sen pientareet jätetään ennalleen.
func _north_ground() -> void:
	var best := {}  # maastoruutu -> [etäisyys, tien korkeus, puolileveys, asfaltti]
	for r in north_roads:
		var pts: PackedVector2Array = r.pts
		var raw := PackedFloat32Array()
		for p in pts:
			raw.append(h(p.x, p.y))
		var ys := PackedFloat32Array()
		for i in pts.size():
			var s := 0.0
			var n := 0
			for k in range(maxi(i - 6, 0), mini(i + 7, pts.size())):
				s += raw[k]
				n += 1
			ys.append(s / n)
		var half: float = r.half
		var reach := half + 6.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach)
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach)
			for j in range(maxi(int((lo.y - _z0) / _cell), 0), mini(int(ceil((hi.y - _z0) / _cell)), _nz - 1) + 1):
				for ii in range(maxi(int((lo.x - _x0) / _cell), 0), mini(int(ceil((hi.x - _x0) / _cell)), _nx - 1) + 1):
					var c := Vector2(_x0 + ii * _cell, _z0 + j * _cell)
					var cp := Geometry2D.get_closest_point_to_segment(c, a, b)
					var dist := c.distance_to(cp)
					if dist > reach:
						continue
					var q := j * _nx + ii
					if best.has(q) and best[q][0] <= dist:
						continue
					var t := clampf(cp.distance_to(a) / maxf(a.distance_to(b), 0.01), 0.0, 1.0)
					best[q] = [dist, lerpf(ys[i], ys[i + 1], t), half, r.asphalt]
	for q in best:
		var code: int = _codes[q]
		if code in [WATER, ROAD, SHOULDER, RAIL]:
			continue
		var e: Array = best[q]
		var w := 1.0 - smoothstep(float(e[2]) + 1.0, float(e[2]) + 6.0, float(e[0]))
		_h[q] = lerpf(_h[q], float(e[1]) - 0.05, w)
		if float(e[0]) < float(e[2]) + 2.5:
			_codes[q] = ROAD if e[3] and float(e[0]) < float(e[2]) + 0.5 else SHOULDER
	# Pihat (patsaan levike, uimaranta, laavun ja saunan piha) sorapinnaksi.
	for poly in north_areas:
		var bb := Rect2(poly[0], Vector2.ZERO)
		for v in poly:
			bb = bb.expand(v)
		for j in range(maxi(int((bb.position.y - _z0) / _cell), 0), mini(int(ceil((bb.end.y - _z0) / _cell)), _nz - 1) + 1):
			for ii in range(maxi(int((bb.position.x - _x0) / _cell), 0), mini(int(ceil((bb.end.x - _x0) / _cell)), _nx - 1) + 1):
				var q := j * _nx + ii
				if _codes[q] != WATER and Geometry2D.is_point_in_polygon(Vector2(_x0 + ii * _cell, _z0 + j * _cell), poly):
					_codes[q] = SHOULDER
	# Raivaus: tiet reunoineen ja pihat.
	_dnx = int(_nx * _cell / DRIVE_CELL) + 1
	_dnz = int(_nz * _cell / DRIVE_CELL) + 1
	_tree_clear.resize(_dnx * _dnz)
	_tree_clear.fill(0)
	var keep := _drive
	_drive = _tree_clear  # piirtoapurit kirjoittavat _driveen
	for r in north_roads:
		var pts: PackedVector2Array = r.pts
		for i in pts.size() - 1:
			_drive_seg(pts[i], pts[i + 1], float(r.half) + 2.0)
	for poly in north_areas:
		_drive_poly(poly, 2.0)
	_tree_clear = _drive
	_drive = keep


## Tienpinnat, opaste ja kohteet (mökin rakennusfunktioilla, ankkuroituna T:n kuvaamaan pisteeseen).
func _build_north() -> void:
	if north_roads.is_empty():
		return
	var M: GDScript = load(MOKKI_PATH)
	var asph := SurfaceTool.new()
	asph.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grav := SurfaceTool.new()
	grav.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in north_roads:
		var pts: PackedVector2Array = r.pts
		var st: SurfaceTool = asph if r.asphalt else grav
		var half: float = r.half
		var edge := []
		for i in pts.size():
			var dir := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var n := dir.orthogonal() * half
			edge.append([pts[i] + n, pts[i] - n])
		var v := func(p: Vector2) -> Vector3: return Vector3(p.x, h(p.x, p.y) + (0.05 if r.asphalt else 0.04), p.y)
		for i in pts.size() - 1:
			_quad(st, v.call(edge[i][0]), v.call(edge[i + 1][0]), v.call(edge[i + 1][1]), v.call(edge[i][1]))
	for pair in [[asph, Color(0.25, 0.25, 0.26)], [grav, Color(0.55, 0.49, 0.4)]]:
		var st: SurfaceTool = pair[0]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "JarviseudunTiet"
		mi.mesh = st.commit()
		mi.material_override = B.mat(pair[1])
		add_child(mi)
	# Opaste soratien alkuun: laavu.
	var gr: Dictionary = north_roads[-1]
	if not gr.asphalt and gr.pts.size() > 6:
		var p0: Vector2 = gr.pts[3]
		var dir: Vector2 = (gr.pts[6] - gr.pts[3]).normalized()
		var at: Vector2 = p0 + dir.orthogonal() * (NORTH_GRAVEL_HALF + 1.0)
		B.trail_sign(self, Vector3(at.x, h(at.x, at.y), at.y), "Keskimmäisen laavu", atan2(-dir.y, dir.x))
	# Kohteet.
	var rep: Node3D = M.new()
	rep.name = "Jarviseutu"
	rep.set_process(false)
	add_child(rep)
	var lakes := {}
	for nl in data.get("north_lakes", []):
		lakes[nl.name] = float(nl.level)
	var put := func(fn: String, key: String, wl_mokki: float, wl_game: float) -> void:
		var a: Vector2 = _north_anchor[key][0]
		var n0 := rep.get_child_count()
		rep.call(fn)
		for ch in rep.get_children().slice(n0):
			if not ch is Node3D:
				continue
			var n3 := ch as Node3D
			var g := _site_pt(a, _north_anchor[key][1], Vector2(n3.position.x, n3.position.z))
			var y := n3.position.y + (wl_game - wl_mokki if n3.has_meta("ground") else h(g.x, g.y))
			n3.position = Vector3(g.x, y, g.y)
			n3.rotation.y -= deg_to_rad(M.YARD_ROT_DEG)
	var to_game := func(key: String, lp: Vector3) -> Vector3:
		var g := _site_pt(_north_anchor[key][0], _north_anchor[key][1], Vector2(lp.x, lp.z))
		return Vector3(g.x, h(g.x, g.y), g.y)
	if _north_anchor.has("rosvo"):
		put.call("_build_rosvo", "rosvo", 0.0, 0.0)
		rosvo_pos = to_game.call("rosvo", rep.rosvo_pos)
	if _north_anchor.has("beach"):
		put.call("_build_salminen_beach", "beach", 0.0, 0.0)
		beach_pos = to_game.call("beach", rep.beach_pos)
	if _north_anchor.has("laavu"):
		var lay: Dictionary = M.keskimmainen_layout()
		put.call("_build_keskimmainen", "laavu", M.water_level(lay.wi), lakes.get("Keskimmäinen", water_level))
		laavu_fire = to_game.call("laavu", rep.laavu_fire)
		barrel_door = to_game.call("laavu", rep.barrel_door)
	_north_rep = rep
	# Mopomatkan E-kohteet (mopo_trip.gd ovet, main.gd _on_vaala_door): samat kuin mökillä jalan.
	if _north_anchor.has("rosvo"):
		var vs: Vector2 = M.rosvo_stash()
		var stash: Vector3 = to_game.call("rosvo", Vector3(vs.x, 0, vs.y))
		doors.append({"id": "viski", "pos": stash, "out": Vector3.ZERO, "text": "Avaa viinakätkö (Ranta-Rosvon jalustan takana)",
			"walk": true})
	if _north_anchor.has("beach"):
		var bd: Vector2 = _site_dir(rep._beach_dir).normalized()
		beach_tf = Transform3D(Basis(Vector3.UP, atan2(bd.x, bd.y)), beach_pos)
		beach_wl = lakes.get(M.BEACH_LAKE, beach_pos.y)
		doors.append({"id": "salminen", "pos": beach_pos - Vector3(bd.x, 0, bd.y) * 2.0, "out": Vector3.ZERO,
			"text": "Uimaan: Salminen, maailman paras uimaranta", "walk": true, "r": 7.0})
	if _north_anchor.has("laavu"):
		var lay: Dictionary = M.keskimmainen_layout()
		var dy: float = lakes.get("Keskimmäinen", water_level) - M.water_level(lay.wi)
		# Mökin paikallisesta kehyksestä pelin kehykseen (kalastuksen minipeli toimii mökin koordinaateissa).
		var a: Vector2 = _north_anchor.laavu[0]
		var o := _site_pt(a, _north_anchor.laavu[1], Vector2.ZERO)
		north_frame = Transform3D(Basis(Vector3.UP, -deg_to_rad(M.YARD_ROT_DEG)), Vector3(o.x, dy, o.y))
		laavu_lake = _site_dir(lay.d).normalized()
		var dock0: Vector3 = to_game.call("laavu", rep.north_dock - Vector3(rep.north_dock_dir.x, 0, rep.north_dock_dir.y) * 9.0)
		doors.append({"id": "tynnyrisauna", "pos": barrel_door, "out": Vector3.ZERO, "text": "Tynnyrisaunan löylyt", "walk": true})
		doors.append({"id": "laavu", "pos": laavu_fire, "out": Vector3.ZERO, "text": "Laavun nuotiolle (makkaranpaisto)", "walk": true})
		doors.append({"id": "kalastus", "pos": dock0, "out": Vector3.ZERO, "text": "Laiturilta soutuveneellä kalaan Keskimmäiselle",
			"walk": true})
	print("VAALA järviseutu: rosvo %s ranta %s laavu %s sauna %s" % [rosvo_pos, beach_pos, laavu_fire, barrel_door])


## Järviseudun mökkikohteet (mokki.gd-instanssi, lapset pelin kehyksessä): tynnyrisauna, vene ja laituri.
var _north_rep: Node3D
var beach_tf := Transform3D()  # Salmisen ranta pelin kehyksessä: vesiraja, +Z järvelle
var beach_wl := 0.0            # Taka-Salmisen vedenpinta
var north_frame := Transform3D()  # Keskimmäisen mökkikehys -> pelin kehys (kalastus)
var laavu_lake := Vector2(0, 1)  # laavulta järvelle


func barrel_frame() -> Transform3D:
	return _north_rep.barrel_frame()


func beach_frame() -> Transform3D:
	return global_transform * beach_tf


func north_boat() -> Node3D:
	return _north_rep.north_boat


func north_dock_local() -> Array:
	return [_north_rep.north_dock, _north_rep.north_dock_dir]


# --- Mökin pihapiiri (mopomatkan lähtö) -----------------------------------------------------------------------

## Mökin paikallisen kehyksen origo Vaalan kehyksessä (molemmat mitataan mökin osoitepisteestä, x itään, z etelään).
func _mokki_c() -> Vector2:
	return load(MOKKI_PATH).YARD_C


## Mökki, savusauna, kesäkeittiö, palju ja huussi mökin omilla rakennusfunktioilla oikealle paikalleen ja
## kiertoon (mokki.gd YARD_C, YARD_ROT_DEG), Vaalan maaston korkeudelle. Pihan männyt ja ympärille männikkö
## (Vaalan puudatassa pihan ympärys on niittyä), piha hiekkaa. Mopo lähtee mökin takaa samasta paikasta.
func _build_mokki_yard() -> void:
	var MokkiScript: GDScript = load(MOKKI_PATH)
	var yard := Node3D.new()
	yard.name = "MokinPiha"
	var c: Vector2 = MokkiScript.YARD_C
	var rot := -deg_to_rad(MokkiScript.YARD_ROT_DEG)
	yard.position = Vector3(c.x, 0, c.y)
	yard.rotation.y = rot
	add_child(yard)
	var to_vaala := func(lp: Vector3) -> Vector3:
		var m: Vector2 = MokkiScript.to_map2(Vector2(lp.x, lp.z))
		return Vector3(m.x, h(m.x, m.y), m.y)
	# Hiekkapiha mökin, saunan ja kesäkeittiön ympärillä (maaston myötäinen soikio).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid := Vector3(-2.0, 0, 6.0)
	var n := 28
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		for lp in [mid, mid + Vector3(cos(a0) * 19.0, 0, sin(a0) * 17.0), mid + Vector3(cos(a1) * 19.0, 0, sin(a1) * 17.0)]:
			var g: Vector3 = to_vaala.call(lp)
			st.add_vertex(Vector3(lp.x, g.y + 0.05, lp.z))
	st.generate_normals()
	var sand := MeshInstance3D.new()
	sand.mesh = st.commit()
	sand.material_override = _ground_mat(Color(0.58, 0.52, 0.38), Color(0.7, 0.63, 0.47), 0.06, 1.2)
	yard.add_child(sand)
	# Rakennukset: mökin rakennusfunktiot lisäävät lapset y = 0 -tasoon, nostetaan Vaalan maastoon.
	var rep: Node3D = MokkiScript.new()
	rep.set_process(false)
	yard.add_child(rep)
	for f in ["_build_cottage", "_build_savusauna", "_build_summer_kitchen", "_build_hottub", "_build_huussi", "_build_ladder"]:
		rep.call(f)
	for ch in rep.get_children():
		if ch is Node3D:
			var g: Vector3 = to_vaala.call((ch as Node3D).position)
			(ch as Node3D).position.y += g.y
	# Männyt: pihan omat ja ympärille rengas männikköä, ei tielle eikä veteen.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1762
	var trees: Array = []
	for tp in MokkiScript.YARD_PINES:
		var g: Vector3 = to_vaala.call(Vector3(tp.x, 0, tp.y))
		trees.append({"pos": Vector3(tp.x, g.y, tp.y), "h": rng.randf_range(9.5, 13.5), "sp": Forest.PINE})
	for i in 1400:  # mökin männikön tiheys (n. puu / 20 m²)
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(24.0 * 24.0, 110.0 * 110.0))
		var lp := Vector3(cos(a) * r, 0, sin(a) * r + 6.0)
		var g: Vector3 = to_vaala.call(lp)
		var code := code_at(g.x, g.z)
		if code in [ROAD, SHOULDER, WATER, OUTSIDE] or g.y < water_level + 0.5:
			continue
		var ni: Array = nearest(g)
		if ni[0] >= 0 and ni[1] < float(road[ni[0]][4]) + 4.0:
			continue
		trees.append({"pos": Vector3(lp.x, g.y, lp.z), "h": rng.randf_range(10.0, 17.0), "sp": Forest.PINE})
	var forest := Forest.new()
	forest.name = "PihanMannikko"
	yard.add_child(forest)
	forest.load_list(trees)
	# Mopon lähtöpaikka: sama kuin mökin parkkipaikka (mokki.gd _build_mopo: kierto PI * 0.9 mökin kehyksessä).
	mokki_mopo = to_vaala.call(MokkiScript.MOPO_LOCAL)
	mokki_mopo_yaw = PI * 0.9 + rot

