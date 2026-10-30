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
const MeshBundle := preload("res://scripts/mesh_bundle.gd")
const Atm := preload("res://scripts/atm.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const TIE := "res://assets/vaala/tie.json"
const MAASTO := "res://assets/vaala/maasto.bin"
const TREES := "res://assets/vaala/puut.bin"
const Forest := preload("res://scripts/forest.gd")
const Train := preload("res://scripts/train.gd")
const StationBuild := preload("res://scripts/station_build.gd")
const Makasiini := preload("res://scripts/makasiini.gd")
const Looks := preload("res://scripts/looks.gd")
const Mummot := preload("res://scripts/mummot.gd")
const HumppaBand := preload("res://scripts/humppa_band.gd")
const Janttu := preload("res://scripts/janttu.gd")
const Muskelivene := preload("res://scripts/muskelivene.gd")
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
var _bld_polys: Array[PackedVector2Array] = []  # rakennusten pohjat (törmäys): ajoalueesta pois (_build_drive_mask)
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
	_move_hotel()


## OSM:n ravintolan pohja koskettaa tietä (seinä 0–0,3 m kaistasta ja terassi tiellä): rakennus siirretään SIITARI_SHIFT metriä
## tiestä poispäin (tien vastakkaiselle sivulle ei). Hotelli johdetaan ravintolan pohjasta, joten se seuraa mukana.
const SIITARI_SHIFT := 6.0


func _move_siitari_back() -> void:
	var so := _siitari_obb()
	if so.is_empty():
		return
	var off: Vector2 = -(so.front as Vector2) * SIITARI_SHIFT
	for bd in data.buildings:
		if bd.id == SIITARI_ID:
			bd.pts = Array(bd.pts).map(func(q: Array) -> Array: return [q[0] + off.x, q[1] + off.y])
	_siitari_obb_cache = {}


## Hotelli Siitari omaksi rakennuksekseen ravintolan taakse (_hotel_pts) jo aineistossa, jotta kartat (minimap.gd,
## paper_map.gd) näyttävät sen samassa paikassa. Uuden pohjan alle jäävät OSM-talot pois.
func _move_hotel() -> void:
	_move_siitari_back()
	var hp := _hotel_pts()
	if hp.is_empty():
		return
	var grown := _hotel_pts(4.0)
	var keep := []
	for bd in data.buildings:
		if bd.id == HOTEL_ID:
			bd.pts = Array(hp).map(func(q: Vector2) -> Array: return [q.x, q.y])
		elif bd.id != SIITARI_ID:
			var cen := Vector2.ZERO
			for q in bd.pts:
				cen += Vector2(q[0], q[1]) / bd.pts.size()
			if Geometry2D.is_point_in_polygon(cen, grown):
				continue
		keep.append(bd)
	data.buildings = keep


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


## Vedessä: maankäyttö vettä tai järviseudulla rannan matalikko järven pinnan alla (pinta piirtyy vesiruutujen
## päälle ruudun verran rannan yli, _build_water). Pelkkä pinnan alla oleva maa ei ole vettä: tiivistetyllä
## järviseudulla tiet kulkevat soiden ja notkojen kautta lähimmän järven pintaa alempana.
func wet(x: float, z: float, margin := 0.05) -> bool:
	if code_at(x, z) == WATER:
		return true
	if h(x, z) >= lake_level_at(x, z) + margin:
		return false
	for dz in [-_cell, 0.0, _cell]:
		for dx in [-_cell, 0.0, _cell]:
			if code_at(x + dx, z + dz) == WATER:
				return true
	return false


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


## Saman istunnon seuraavat mopomatkat: Vaala vapautetaan Saloisissa ja rakennetaan uudelleen, ja rakennus on
## siemennettyä ja siis joka kerta sama, joten ajoalue (0,23 s) ja makasiinin paikka lasketaan vain kerran.
static var _memo := {}


func _build_drive_mask() -> void:
	if _memo.has("drive"):
		var m: Array = _memo.drive
		_dnx = m[0]
		_dnz = m[1]
		_drive = (m[2] as PackedByteArray).duplicate()
		_surf = (m[3] as PackedByteArray).duplicate()
		return
	_build_drive_mask_calc()
	_memo.drive = [_dnx, _dnz, _drive.duplicate(), _surf.duplicate()]


func _build_drive_mask_calc() -> void:
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
		var style := _side_style(r)
		var half: float = style[1]
		# Pinta kuten piirrossa (_build_side_roads): asfaltti täyttä vauhtia, sora ja polut pientareen vauhtia.
		var paved: bool = style[0] in ["asphalt", "street"]
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
	if ast != null and float(ast.roundabout.r) > 0.0:
		var rcen := Vector2(ast.roundabout.c[0], ast.roundabout.c[1])
		for k in 24:
			_drive_seg(rcen + Vector2.from_angle(TAU * k / 24) * (float(ast.roundabout.r) - 3.2),
				rcen + Vector2.from_angle(TAU * (k + 1) / 24) * (float(ast.roundabout.r) - 3.2), 4.2)
	_surf_val = 0
	if data.has("lava"):
		var lr: Array = data.lava.road
		for k in lr.size() - 1:
			_drive_seg(Vector2(lr[k][0], lr[k][1]), Vector2(lr[k + 1][0], lr[k + 1][1]), 3.5)
	if data.has("satama"):
		# Sataman parkki ja laiturin juuri (ovi "satama"): suorakaide parkin takaosasta laiturin juureen, sora.
		var sd: Dictionary = data.satama
		var sdir := Vector2(sd.dir[0], sd.dir[1])
		var ss := Vector2(sdir.y, -sdir.x)
		var sc := Vector2(sd.park[0], sd.park[1])
		var s0 := sc - sdir * float(sd.park_r[1])
		var s1 := Vector2(sd.x, sd.z) + sdir * 1.0
		var sw := float(sd.park_r[0]) * 0.8
		_surf_val = 2  # parkki asfalttia
		_drive_ellipse(sc, float(sd.park_r[0]), float(sd.park_r[1]))
		_surf_val = 1
		_drive_poly(PackedVector2Array([s0 - ss * sw, s0 + ss * sw, s1 + ss * 1.6, s1 - ss * 1.6]), 0.0)
		_surf_val = 0
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
	_clear_buildings()
	# Ovien ja pysäköintipaikkojen edustat: ovelle ja sieltä lähimmälle tielle.
	var stops: Array[Vector3] = [siitari_park, siitari_door, kmarket_door, atm_pos, lava_park]
	for d in doors:
		if not d.get("walk", false) and not in_lava_yard(d.pos):  # rannoilla ja laiturilla ei ajeta veteen, lavan piha on kävelyaluetta
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
	_carve_obstacles()
	_connect_stops(stops)
	_clear_buildings()  # ovien edustat eivät ulotu seinien sisään
	_clear_lava_yard()
	print("VAALA ajoalue %d ms, %.0f %% ruuduista" % [Time.get_ticks_msec() - t0, 100.0 * _drive.count(1) / _drive.size()])


## Lavan aidan sisäpuoli on kävelyaluetta: autoja ja mopoja ei päästetä portista (parkki on aidan ulkopuolella, lava_park).
## in_lava_yard on aidan kahden viivan kulma, joten rajataan lavan niemelle (aidan kaakkoispuoli, x < 760).
func _clear_lava_yard() -> void:
	if _yard_lines.is_empty():
		return
	for j in range(maxi(int((_yard_lines[0][0].y - _z0) / DRIVE_CELL), 0), _dnz):
		for i in range(0, mini(int((760.0 - _x0) / DRIVE_CELL), _dnx)):
			# Myös aidan päälle jäävät ruudut pois (jokin kulma pihalla): mopo pysähtyy aidan ulkopuolelle, ei portin suuhun.
			for o in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)]:
				if in_lava_yard(Vector3(_x0 + (i + o.x) * DRIVE_CELL, 0, _z0 + (j + o.y) * DRIVE_CELL)):
					_drive[j * _dnx + i] = 0
					break


## Rakennusten sisään ei ajeta: pohja pois ajoalueesta, ettei mopo juutu seinään (reunaa vasten se liukuu).
func _clear_buildings() -> void:
	for poly in _bld_polys:
		var lo := poly[0]
		var hi := poly[0]
		for q in poly:
			lo = lo.min(q)
			hi = hi.max(q)
		for j in range(maxi(int((lo.y - _z0) / DRIVE_CELL), 0), mini(int((hi.y - _z0) / DRIVE_CELL), _dnz - 1) + 1):
			for i in range(maxi(int((lo.x - _x0) / DRIVE_CELL), 0), mini(int((hi.x - _x0) / DRIVE_CELL), _dnx - 1) + 1):
				if Geometry2D.is_point_in_polygon(Vector2(_x0 + (i + 0.5) * DRIVE_CELL, _z0 + (j + 0.5) * DRIVE_CELL), poly):
					_drive[j * _dnx + i] = 0


## Pienet esteet (kojut, penkit, laavu, kyltit ja aidanpätkät) pois ajoalueelta: mopo liukuu niiden ohi reunaa
## pitkin eikä juutu niihin. Isot laatikot (rakennukset, lattiat, sillankannet) ja lavan portti jäävät.
func _carve_obstacles() -> void:
	for body in find_children("*", "StaticBody3D", true, false):
		for cs in (body as Node).get_children():
			if not (cs is CollisionShape3D) or cs == _gate_block or not ((cs as CollisionShape3D).shape is BoxShape3D):
				continue
			var size: Vector3 = ((cs as CollisionShape3D).shape as BoxShape3D).size
			if maxf(size.x, size.z) > 12.0 or size.y < 0.5:
				continue
			var xf := Transform3D()
			var n: Node = cs
			while n != self and n != null:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			if n == null:
				continue
			var gy := h(xf.origin.x, xf.origin.z)
			if xf.origin.y - size.y / 2.0 > gy + 1.2 or xf.origin.y + size.y / 2.0 < gy + 0.3:
				continue  # maan alla tai yläpuolella (kansi, katos)
			var poly := PackedVector2Array()
			for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				# Kasvatus puolella ruudulla: ohuetkin esteet (penkki, aidanpätkä) osuvat ruutujen keskipisteisiin.
				var q := xf * Vector3(c.x * (size.x / 2.0 + 0.4 + DRIVE_CELL * 0.5), 0, c.y * (size.z / 2.0 + 0.4 + DRIVE_CELL * 0.5))
				poly.append(Vector2(q.x, q.z))
			var lo := poly[0]
			var hi := poly[0]
			for q in poly:
				lo = lo.min(q)
				hi = hi.max(q)
			for j in range(maxi(int((lo.y - _z0) / DRIVE_CELL), 0), mini(int((hi.y - _z0) / DRIVE_CELL), _dnz - 1) + 1):
				for i in range(maxi(int((lo.x - _x0) / DRIVE_CELL), 0), mini(int((hi.x - _x0) / DRIVE_CELL), _dnx - 1) + 1):
					if Geometry2D.is_point_in_polygon(Vector2(_x0 + (i + 0.5) * DRIVE_CELL, _z0 + (j + 0.5) * DRIVE_CELL), poly):
						_drive[j * _dnx + i] = 0


## Ovien edustat, joihin ei pääse tieverkosta (ajoalueen saareke rakennusten välissä): kapea ajoura lähimpään
## tieverkon ruutuun, jonka suora ei kulje rakennuksen läpi.
func _connect_stops(stops: Array) -> void:
	var mid: Array = road[road.size() / 2]  # reitin keskikohta on varmasti ajoaluetta (alku on mökin pihassa)
	var reach := _drive_flood(Vector2(mid[0], mid[2]))
	for sp in stops:
		if sp == Vector3.ZERO:
			continue
		var p := Vector2(sp.x, sp.z)
		var c := _dcell(p)
		if c >= 0 and reach[c] == 1:
			continue
		var best := Vector2.INF
		var steps := int(60.0 / DRIVE_CELL)
		var ci := c % _dnx
		var cj := c / _dnx
		for dj in range(-steps, steps + 1):
			for di in range(-steps, steps + 1):
				var i := ci + di
				var j := cj + dj
				if i < 0 or j < 0 or i >= _dnx or j >= _dnz or reach[j * _dnx + i] == 0:
					continue
				var q := Vector2(_x0 + (i + 0.5) * DRIVE_CELL, _z0 + (j + 0.5) * DRIVE_CELL)
				if q.distance_squared_to(p) < best.distance_squared_to(p) and not _hits_building(p, q):
					best = q
		if best != Vector2.INF:
			_drive_seg(p, best, 2.5)
		if best == Vector2.INF:
			push_warning("VAALA: ovelta %s ei löytynyt yhteyttä tieverkkoon" % p.round())


func _dcell(p: Vector2) -> int:
	var i := int((p.x - _x0) / DRIVE_CELL)
	var j := int((p.y - _z0) / DRIVE_CELL)
	return j * _dnx + i if i >= 0 and j >= 0 and i < _dnx and j < _dnz else -1


## Ajoalueen ruudut, joihin pääsee pisteestä (1 = tavoitettava).
func _drive_flood(from: Vector2) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(_drive.size())
	var c := _dcell(from)
	if c < 0 or _drive[c] == 0:
		return seen
	var stack := PackedInt32Array([c])
	seen[c] = 1
	while not stack.is_empty():
		var id := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var i := id % _dnx
		for nb in [id - 1 if i > 0 else -1, id + 1 if i < _dnx - 1 else -1, id - _dnx, id + _dnx]:
			if nb >= 0 and nb < _drive.size() and _drive[nb] == 1 and seen[nb] == 0:
				seen[nb] = 1
				stack.append(nb)
	return seen


func _hits_building(a: Vector2, b: Vector2) -> bool:
	for poly in _bld_polys:
		if not Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly).is_empty():
			return true
	return false


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
	var times: Array[String] = []
	for step: Callable in [_plan_north, _build_terrain, _build_far, _build_road, _build_bridges, _build_side_roads,
			_build_underpass, _tori_prep, _build_buildings, _build_parkings, _build_tori, _build_kunnantalo, _build_apteekki, _build_station, _build_poliisi, _build_signs,
			_build_trees, _build_lamps, _build_atm, _build_kmarket_yard, _build_lava, _build_satama, _build_uitto, _build_lava_pier, _build_mokki_yard, _build_north, _build_salminen_trees, _build_drive_mask,
			_build_lava_grounds, _merge_static_meshes]:
		var ts := Time.get_ticks_msec()
		step.call()
		if Time.get_ticks_msec() - ts > 60:
			times.append("%s %d" % [step.get_method().trim_prefix("_build_"), Time.get_ticks_msec() - ts])
	print("VAALA vaiheet (ms): ", ", ".join(times))
	print("VAALA rakennettu %d ms" % (Time.get_ticks_msec() - t0))


## Kylttien, kojujen, aitojen ja pihojen staattiset osat lohkoittain erämesheiksi (B.merge_static): Vaalan
## keskustassa ~3 400 erillistä meshiä teki 700-900 piirtokutsua.
func _merge_static_meshes() -> void:
	if "--ei-yhdistelya" in OS.get_cmdline_user_args():
		return
	var r := B.merge_static(self, 150.0)
	print("VAALA yhdistetty %d meshiä %d erään" % r)


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
	var mat := B.shader_mat("res://shaders/ground_blend.gdshader")
	var lods := [[1, 0.0, TLOD[0]], [2, TLOD[0], TLOD[1]], [4, TLOD[1], 0.0]]
	var half := TCHUNK * _cell * 0.71
	# Lohkot levyvälimuistista (laskenta vie GDScriptillä puoli sekuntia): avain korkeuksista ja maankäytöstä.
	var tkey := "v%d/%d/%d/%d/%d" % [TERRAIN_CACHE_VERSION, _nx, _nz, hash(_h), hash(_codes)]
	var tc := MeshBundle.load_dict("vaala_maasto", tkey)
	var chunks: Array = tc.get("chunks", [])
	if chunks.is_empty():
		chunks = _terrain_chunks(lin, lods)
		MeshBundle.save_dict("vaala_maasto", tkey, {"chunks": chunks})
	for ch in chunks:
		var lod: Array = lods[ch[1]]
		var mi := MeshInstance3D.new()
		mi.mesh = ch[0]
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


## Maaston lohkot [mesh, tarkkuustaso] (MeshBundle-välimuistin laskenta).
func _terrain_chunks(lin: Dictionary, lods: Array) -> Array:
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
	var out: Array = []
	for cj in range(0, _nz - 1, TCHUNK):
		for ci in range(0, _nx - 1, TCHUNK):
			for li in lods.size():
				var am := _terrain_chunk(ci, cj, mini(ci + TCHUNK, _nx - 1), mini(cj + TCHUNK, _nz - 1), lods[li][0], verts, norms, cols, cust)
				if am != null:
					out.append([am, li])
	return out


## Maaston lohko ruuduista [i0, i1] x [j0, j1] askeleella st (1, 2 tai 4); harvoilla tasoilla helma reunoille.
const TCHUNK := 32
const TERRAIN_CACHE_VERSION := 1  # nosta, kun lohkojen laskenta muuttuu
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
	var bridge: Array[bool] = []
	for i in road.size():
		pts.append(road_pos(i))
		hws.append(road[i][4])
		grav.append(road[i][5] == 1)
		bridge.append(road[i][6] == 1)
	_road_strip(pts, hws, grav, bridge)
	for br in data.branches:
		var bp: Array[Vector3] = []
		var bh: Array[float] = []
		var bg: Array[bool] = []
		var bb: Array[bool] = []
		for q in br.pts:
			bp.append(Vector3(q[0], h(q[0], q[2]), q[2]))
			bh.append(br.hw)
			bg.append(br.gravel == 1)
			bb.append(false)
		# Risteyksen pää tien reunaan asti: haara alkaa reitin keskeltä, joten ensimmäiset metrit jätetään pois.
		var skip := 0
		while skip < bp.size() - 2 and Vector2(bp[skip].x - bp[0].x, bp[skip].z - bp[0].z).length() < 3.0:
			skip += 1
		_road_strip(bp.slice(skip), bh.slice(skip), bg.slice(skip), bb.slice(skip))
		if br.name == "Neittäväntie" and not north_roads.is_empty():
			continue  # haara jatkuu Nuojuankoskentienä Ranta-Rosvolle ja Salmiselle (_plan_north): ei puomia
		_dead_end(bp[-1], (bp[-1] - bp[-2]).normalized(), br.hw)
	for key in _strips:
		var st: SurfaceTool = _strips[key]
		if _st_empty(st):
			continue
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _surf_mat(key)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


var _strips := {}


func _road_mats() -> void:
	for k2 in ["asphalt", "shoulder", "dash", "gravel"]:
		_strips[k2] = SurfaceTool.new()
		_strips[k2].begin(Mesh.PRIMITIVE_TRIANGLES)


## Tien jaksot pintalajeittain: sora, asfaltti ja silta (kansi leivotulla korkeudella). Sora ja asfaltti piirretään
## maastoon sovitettuna kuten kaikki muutkin tiet (_ribbon): asfaltti piennarineen ja katkoviivoineen kuten Saloisissa.
func _road_strip(pts: Array, hws: Array, grav: Array, bridge: Array) -> void:
	var kind := func(k: int) -> String:
		if bridge[k] and bridge[k + 1]:
			return "bridge"
		return "gravel" if grav[k] else "asphalt"
	var i := 0
	while i < pts.size() - 1:
		var kd: String = kind.call(i)
		var j := i
		while j < pts.size() - 1 and kind.call(j) == kd:
			j += 1
		var run: Array = pts.slice(i, j + 1)
		var half: float = hws[i]
		if kd == "bridge":
			_bridge_surface(run, half)
		else:
			var line := PackedVector2Array()
			for q: Vector3 in run:
				line.append(Vector2(q.x, q.z))
			if kd == "gravel":
				_ribbon(_strips.gravel, line, GRAVEL_HALF, LIFT_GRAVEL)
			else:
				_ribbon(_strips.shoulder, line, half + ROAD_SHOULDER, LIFT_SHOULDER)
				_ribbon(_strips.asphalt, line, half, LIFT_ASPHALT)
				_dashes(_strips.dash, line, LIFT_DASH, 0.0)
		i = j


## Sillan kansi: asfaltti ja keskiviiva kannen korkeudella (ei maastoa sen alla).
func _bridge_surface(run: Array, half: float) -> void:
	var dist := 0.0
	for i in run.size() - 1:
		var a: Vector3 = run[i]
		var b: Vector3 = run[i + 1]
		var a0 := run[maxi(i - 1, 0)] as Vector3
		var b1 := run[mini(i + 2, run.size() - 1)] as Vector3
		var na := Vector3(b.x - a0.x, 0, b.z - a0.z).normalized().cross(Vector3.UP)
		var nb := Vector3(b1.x - a.x, 0, b1.z - a.z).normalized().cross(Vector3.UP)
		var lift := Vector3(0, LIFT_ASPHALT, 0)
		_quad(_strips.asphalt, a - na * half + lift, b - nb * half + lift, b + nb * half + lift, a + na * half + lift)
		if fmod(dist, 9.0) < 3.0:
			var up := Vector3(0, LIFT_DASH, 0)
			_quad(_strips.dash, a - na * 0.12 + up, b - nb * 0.12 + up, b + nb * 0.12 + up, a + na * 0.12 + up)
		dist += a.distance_to(b)


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
## Asuinrakennusten ovet (kolmiomittaus #255: Katjan rivitalo ja väärät ovet): {pos, out (Vector3), type, len, id}.
var house_doors: Array = []


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


var lava_band: Node3D  # humppa_band.gd
var _lava_crowd: Node3D
var _lava_root: Node3D
var _lava_dims := Vector3.ZERO
var _lava_dancers: Node3D
var _lava_live := false
var _lava_cars: Array[Vector2] = []
var lava_kiosk := Vector3.INF  # grillikioskin paikka (testikuvat)
var _kiosk: Node3D
var _kiosk_table: Node3D
var _smoke_c := Vector2.INF
var _lava_outside: Node3D  # pihan väki (grillikioski, tupakkapaikka) tanssien aikaan


## Tanssit käynnissä (main.gd aukioloaika): bändi soittaa ja väki tanssii. in_game = pelaaja on sisällä
## (lava_game.gd tuo omat tanssijansa ja soittaa kappaleen musiikkina): ulkoyleisö pois ja kaiutin hiljaiseksi.
func set_lava_live(on: bool, in_game := false) -> void:
	if lava_band == null:
		return
	if (on or in_game) and _lava_crowd == null:
		# Ensimmäinen kerta tanssien aikaan: bändi, väki ja pihan väki (hahmojen luonti vie sekunnin).
		lava_band.build()
		_build_lava_crowd(_lava_root, _lava_dims.x, _lava_dims.y, _lava_dims.z)
		_build_lava_kiosk_people()
	if _lava_crowd == null:
		return
	lava_band.visible = on or in_game
	_lava_crowd.visible = on or in_game
	if _lava_outside != null:
		_lava_outside.visible = on or in_game
	_lava_dancers.visible = on and not in_game  # sisällä lava_game.gd tuo omat tanssijansa
	# Piilossa tai kaukana väki ei animoi (hahmojen luustot ovat kalliita).
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and cam.global_position.distance_to(to_global(lava_center)) < 120.0
	_lava_crowd.process_mode = Node.PROCESS_MODE_INHERIT if _lava_crowd.visible and near else Node.PROCESS_MODE_DISABLED
	if _lava_outside != null:
		_lava_outside.process_mode = _lava_crowd.process_mode
	lava_band.set_speaker(not in_game)
	if on == _lava_live and not (in_game and lava_band.speaker):
		return
	_lava_live = on
	if on and lava_band.current_song.is_empty():
		lava_band.request(HumppaBand.repertoire().pick_random())
	elif not on and not in_game:
		lava_band.stop_playing()


## Lavan piha pienemmäksi ja eläväksi: niityn paljaat laidat koivikoksi, katajiksi ja männiköksi (aukio jää
## vain lavan ympärille, ajoteille ja kohteiden ympärille), grillikioski parkin laitaan ja tupakkapaikka oven
## pieleen. Puut kasvavat vain ajoalueen ulkopuolelle (ajetaan _build_drive_maskin jälkeen).
func _build_lava_grounds() -> void:
	var lv: Dictionary = data.get("lava", {})
	if lv.is_empty():
		return
	var c := Vector2(lv.x, lv.z)
	var hw: float = float(lv.w) / 2.0
	var hl: float = float(lv.l) / 2.0
	var side: float = lv.get("door_side", 1.0)
	var fence: Array[Vector2] = []
	for q in lv.get("fence", []):
		fence.append(Vector2(q[0], q[1]))
	var keep_out: Array = []  # [piste, säde]
	for d in doors:
		keep_out.append([Vector2(d.pos.x, d.pos.z), 9.0])
	for q in [pummi_in, pummi_out, kokko_pos, party_pos, yard_teens_pos, gate_out, gate_in, race_spot]:
		if q != Vector3.ZERO and q != Vector3.INF:
			keep_out.append([Vector2(q.x, q.z), 10.0])
	keep_out.append([Vector2(lava_door.x, lava_door.z), 16.0])
	for cp in _lava_cars:
		keep_out.append([cp, 5.0])
	if _wade_c != Vector2.INF:
		keep_out.append([_wade_c, _wade_r])
	var rng := RandomNumberGenerator.new()
	rng.seed = 9031
	var trees: Array = []
	var step := 4.0
	var reach := Vector2(hw + 110.0, hl + 110.0)
	var why := {}
	var x := -reach.x
	while x <= reach.x:
		var z := -reach.y
		while z <= reach.y:
			var p := c + Vector2(x, z) + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
			z += step
			var rect_d := Vector2(maxf(absf(p.x - c.x) - hw, 0.0), maxf(absf(p.y - c.y) - hl, 0.0)).length()
			if rect_d < 11.0 or code_at(p.x, p.y) in [ROAD, SHOULDER, WATER, RAIL, OUTSIDE] or wet(p.x, p.y, 0.12):
				var wk := "lähellä" if rect_d < 11.0 else ("märkä" if wet(p.x, p.y, 0.12) else "koodi%d" % code_at(p.x, p.y))
				why[wk] = why.get(wk, 0) + 1
				continue
			if code_at(p.x, p.y) == FOREST and rng.randf() < 0.45:
				why["metsä"] = why.get("metsä", 0) + 1
				continue  # metsämaalla on jo puita (siirretyn lavan alta puut on raivattu): harvemmin lisää
			if rng.randf() > clampf((rect_d - 11.0) / 18.0, 0.3, 0.9):
				continue
			var blocked := false
			for o in [Vector2.ZERO, Vector2(3.5, 0), Vector2(-3.5, 0), Vector2(0, 3.5), Vector2(0, -3.5)]:
				if drivable(p.x + o.x, p.y + o.y):
					blocked = true
					break
			for ko in keep_out:
				if blocked or p.distance_to(ko[0]) < ko[1]:
					blocked = true
					break
			for k in fence.size() - 1:
				if blocked or Geometry2D.get_closest_point_to_segment(p, fence[k], fence[k + 1]).distance_to(p) < 3.0:
					blocked = true
					break
			if blocked:
				why["este"] = why.get("este", 0) + 1
				continue
			var r := rng.randf()
			var sp := Forest.BIRCH if r < 0.5 else (Forest.PINE if r < 0.68 else (Forest.SPRUCE if r < 0.8 else Forest.BUSH))
			if rect_d < 18.0 and rng.randf() < 0.6:
				sp = Forest.BUSH  # aukion reunassa katajaa ja pajua
			var hh := rng.randf_range(1.2, 2.6) if sp == Forest.BUSH else rng.randf_range(8.0, 15.0)
			trees.append({"pos": Vector3(p.x, h(p.x, p.y), p.y), "h": hh, "sp": sp})
		x += step
	if not trees.is_empty():
		var f := Forest.new()
		f.name = "LavanLehto"
		add_child(f)
		f.load_list(trees, 77)
	_build_lava_kiosk(c, hw, hl, side)
	print("VAALA lavan piha: %d puuta ja pensasta, karsittu %s" % [trees.size(), why])


## Grillikioski parkin laitaan (makkaraperunat ja kahvit), jono ja penkkipöytä; tupakkapaikka oven pieleen.
func _build_lava_kiosk(c: Vector2, hw: float, hl: float, side: float) -> void:
	_lava_outside = Node3D.new()
	_lava_outside.visible = false
	add_child(_lava_outside)
	# Kioskin paikka: oven puolella lavan päädyn kohdalla, ajoalueen ulkopuolella.
	var spot := Vector2.INF
	for dz: float in [hl - 4.0, -hl + 4.0, hl + 4.0, -hl - 4.0, 0.0]:
		for dx: float in [9.0, 12.0, 15.0]:
			var q := c + Vector2(side * (hw + dx), dz)
			if spot == Vector2.INF and not drivable(q.x, q.y) and not drivable(q.x + 2.5, q.y) and not drivable(q.x - 2.5, q.y) \
					and not wet(q.x, q.y, 0.5) and Vector2(lava_door.x, lava_door.z).distance_to(q) > 11.0:
				spot = q
	if spot == Vector2.INF:
		return
	var face := Vector3(-side, 0, 0)  # luukku lavan suuntaan
	lava_kiosk = Vector3(spot.x, h(spot.x, spot.y), spot.y)
	var k := Node3D.new()
	k.position = Vector3(spot.x, h(spot.x, spot.y), spot.y)
	k.rotation.y = B.yaw_to(face)
	add_child(k)  # kioski näkyy aina, väki vain tanssien aikaan
	var body := StaticBody3D.new()
	k.add_child(body)
	body.add_child(B.box_shape(Vector3(2.6, 2.4, 2.0), Vector3(0, 1.2, 0)))
	var white := Color(0.94, 0.93, 0.88)
	var red := Color(0.72, 0.1, 0.08)
	B.mesh(k, B.boxm(Vector3(2.6, 0.9, 2.0)), Vector3(0, 0.45, 0), red)  # alaosa
	B.mesh(k, B.boxm(Vector3(2.6, 1.3, 2.0)), Vector3(0, 1.55, 0.0), white)
	B.mesh(k, B.boxm(Vector3(1.8, 0.8, 0.04)), Vector3(0, 1.5, -1.01), Color(0.15, 0.12, 0.1))  # luukku auki
	B.mesh(k, B.boxm(Vector3(2.0, 0.06, 0.45)), Vector3(0, 0.95, -1.2), Color(0.85, 0.85, 0.82))  # tiski
	B.mesh(k, B.boxm(Vector3(2.9, 0.12, 2.4)), Vector3(0, 2.26, 0), Color(0.25, 0.25, 0.27))  # katto
	for st in 6:  # raidallinen markiisi
		var aw := B.mesh(k, B.boxm(Vector3(0.48, 0.03, 0.8)), Vector3(-1.2 + st * 0.48, 2.05, -1.32), red if st % 2 == 0 else white)
		aw.rotation.x = 0.35
	var sign := B.sign_plate(k, "GRILLI · MAKKARAPERUNAT", Color(0.95, 0.85, 0.2), Color(0.55, 0.05, 0.05), 0.3, 40, Color(0.55, 0.05, 0.05))
	sign.position = Vector3(0, 2.5, -1.0)
	sign.rotation.y = PI
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.0, -1.6)
	lamp.light_color = Color(1.0, 0.85, 0.55)
	lamp.light_energy = 1.2
	lamp.omni_range = 7.0
	k.add_child(lamp)
	# Penkkipöytä kioskin vieressä ja kaksi syöjää.
	var tbl := Node3D.new()
	tbl.position = to_local(k.to_global(Vector3(3.2, 0, -1.5)))
	tbl.position.y = h(tbl.position.x, tbl.position.z)
	tbl.rotation.y = k.rotation.y
	add_child(tbl)
	var wood := Color(0.55, 0.38, 0.22)
	B.mesh(tbl, B.boxm(Vector3(0.8, 0.05, 1.8)), Vector3(0, 0.75, 0), wood)
	for sx in [-0.65, 0.65]:
		B.mesh(tbl, B.boxm(Vector3(0.3, 0.05, 1.8)), Vector3(sx, 0.45, 0), wood)
		for lz in [-0.7, 0.7]:
			B.mesh(tbl, B.boxm(Vector3(0.06, 0.45, 0.06)), Vector3(sx, 0.22, lz), wood.darkened(0.2))
	for lz in [-0.7, 0.7]:
		B.mesh(tbl, B.boxm(Vector3(0.06, 0.75, 0.06)), Vector3(0, 0.37, lz), wood.darkened(0.2))
	_kiosk = k
	_kiosk_table = tbl
	for sx in [-1.0, 1.0]:
		B.mesh(tbl, B.boxm(Vector3(0.2, 0.03, 0.14)), Vector3(sx * 0.2, 0.79, 0.3 * sx), Color(0.95, 0.95, 0.9))  # pahvilautanen
	# Tupakkapaikka oven pielessä (ajoalueen ulkopuolella): kolme tupakoijaa ja tuhkakuppi tolpassa.
	var smoke_c := Vector2(lava_door.x, lava_door.z) + Vector2(side * 2.5, -11.0)
	if drivable(smoke_c.x, smoke_c.y):
		smoke_c = Vector2(lava_door.x, lava_door.z) + Vector2(side * 2.5, 11.0)
	if not drivable(smoke_c.x, smoke_c.y) and not wet(smoke_c.x, smoke_c.y, 0.3):
		var sy := h(smoke_c.x, smoke_c.y)
		B.mesh(_lava_outside, B.cyl(0.03, 0.03, 1.0, 6), Vector3(smoke_c.x, sy + 0.5, smoke_c.y), Color(0.3, 0.3, 0.32))
		B.mesh(_lava_outside, B.cyl(0.12, 0.1, 0.12, 10), Vector3(smoke_c.x, sy + 1.02, smoke_c.y), Color(0.55, 0.55, 0.58))
		_smoke_c = smoke_c


## Kioskin ja tupakkapaikan väki (rakennetaan tanssien alkaessa, set_lava_live).
func _build_lava_kiosk_people() -> void:
	if _kiosk == null:
		return
	var k := _kiosk
	var tbl := _kiosk_table
	# Grillaaja luukulla ja jono.
	var cook := Looks.make(_lava_outside, {"shirt": Color(0.95, 0.95, 0.95), "pants": Color(0.2, 0.2, 0.22), "hair": "Hair_Buzzed",
		"hair_color": Color(0.3, 0.25, 0.2), "height": 1.76, "belly": 0.6})
	cook.position = to_local(k.to_global(Vector3(0.2, 0.0, -0.3)))
	cook.rotation.y = k.rotation.y
	cook.play("Idle_Talking", 0.0)
	var looks := [
		{"shirt": Color(0.2, 0.35, 0.7), "pants": Color(0.25, 0.3, 0.45), "hair": "Hair_SimpleParted", "hair_color": Color(0.5, 0.4, 0.3), "height": 1.82, "belly": 0.5},
		{"model": "female", "shirt": Color(0.85, 0.3, 0.45), "pants": Color(0.2, 0.2, 0.3), "hair": "Hair_Long", "hair_color": Color(0.85, 0.7, 0.4), "height": 1.65},
		{"shirt": Color(0.3, 0.45, 0.25), "pants": Color(0.15, 0.15, 0.17), "hair": "Hair_Buzzed", "hair_color": Color(0.6, 0.6, 0.6), "height": 1.75, "belly": 0.7},
	]
	for i in looks.size():
		var q := Looks.make(_lava_outside, looks[i])
		var lp := Vector3(-0.3 + i * 0.25, 0, -1.9 - i * 0.9)
		q.position = to_local(k.to_global(lp))
		q.position.y = h(q.position.x, q.position.z)
		q.rotation.y = k.rotation.y + PI
		q.play("Idle_Talking" if i == 0 else "Idle", 0.0)
	for sx in [-1.0, 1.0]:
		var e := Looks.make(_lava_outside, looks[1 if sx < 0 else 2])
		e.position = to_local(tbl.to_global(Vector3(sx * 0.7, 0.04, 0.3 * sx)))
		e.rotation.y = tbl.rotation.y + (PI / 2.0 if sx < 0 else -PI / 2.0)
		e.play("Sitting_Talking" if sx < 0 else "Sitting_Idle", 0.0)
	if _smoke_c == Vector2.INF:
		return
	var smoke_c := _smoke_c
	var smokers := [
		{"shirt": Color(0.1, 0.1, 0.12), "pants": Color(0.25, 0.3, 0.45), "hair": "Hair_Long", "hair_color": Color(0.2, 0.15, 0.1), "height": 1.84},
		{"model": "female", "shirt": Color(0.95, 0.85, 0.3), "pants": Color(0.12, 0.12, 0.2), "hair": "Hair_Buns", "hair_color": Color(0.35, 0.2, 0.1), "height": 1.64},
		{"shirt": Color(0.6, 0.15, 0.12), "pants": Color(0.2, 0.2, 0.25), "hair": "Hair_SimpleParted", "hair_color": Color(0.7, 0.7, 0.7), "height": 1.78, "belly": 0.8},
	]
	for i in smokers.size():
		var a := TAU * i / 3.0 + 0.3
		var q := Looks.make(_lava_outside, smokers[i])
		q.position = Vector3(smoke_c.x + cos(a) * 0.9, 0, smoke_c.y + sin(a) * 0.9)
		q.position.y = h(q.position.x, q.position.z)
		q.rotation.y = B.yaw_to(Vector3(smoke_c.x, 0, smoke_c.y) - Vector3(q.position.x, 0, q.position.z))
		q.play("Idle_Talking" if i != 1 else "Idle", 0.0)


## Lavan väki tanssien aikaan: pareja tanssilattialla ja penkeillä seinien vierillä istujia ja juttelijoita.
func _build_lava_crowd(root: Node3D, w: float, l: float, side: float) -> void:
	_lava_crowd = Node3D.new()
	_lava_crowd.visible = false
	root.add_child(_lava_crowd)
	_lava_dancers = Node3D.new()
	_lava_crowd.add_child(_lava_dancers)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var shirts := [Color(0.85, 0.2, 0.3), Color(0.2, 0.35, 0.75), Color(0.95, 0.85, 0.3), Color(0.25, 0.55, 0.3),
		Color(0.95, 0.95, 0.95), Color(0.5, 0.2, 0.55), Color(0.15, 0.15, 0.17), Color(0.85, 0.5, 0.2)]
	var hairs := ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Long", "Hair_Buns"]
	var person := func(female: bool) -> Dictionary:
		return {"model": "female" if female else "male", "shirt": shirts[rng.randi() % shirts.size()],
			"pants": Color(0.15, 0.15, 0.25) if not female else shirts[rng.randi() % shirts.size()],
			"hair": hairs[rng.randi() % hairs.size()] if female else hairs[rng.randi() % 2],
			"hair_color": Color(rng.randf_range(0.1, 0.85), rng.randf_range(0.08, 0.65), 0.1),
			"height": 1.66 if female else 1.8, "belly": rng.randf_range(0.0, 0.6) if not female else 0.0}
	for k in 9:
		var at := Vector3(rng.randf_range(-w / 2.0 + 4.0, w / 2.0 - 4.0), 0.06, rng.randf_range(-l / 2.0 + 8.5, l / 2.0 - 5.0))
		for s2 in 2:
			var d := Looks.make(_lava_dancers, person.call(s2 == 1))
			d.position = at + Vector3(0, 0, 0.45 if s2 == 0 else -0.45)
			d.rotation.y = 0.0 if s2 == 0 else PI
			d.play("Dance", 0.0, rng.randf_range(0.8, 1.1))
	# Penkit pitkien seinien vierellä (ovi ei peity) ja niillä istujat.
	for sx in [-1.0, 1.0]:
		for k in 3:
			var z := -l / 2.0 + 9.0 + k * 8.0
			if sx == side and absf(z) < 4.0:
				continue
			var bx: float = sx * (w / 2.0 - 0.7)
			B.mesh(_lava_crowd, B.boxm(Vector3(0.45, 0.06, 3.0)), Vector3(bx, 0.45, z), Color(0.5, 0.33, 0.18))
			for lz in [-1.3, 1.3]:
				B.mesh(_lava_crowd, B.boxm(Vector3(0.4, 0.42, 0.06)), Vector3(bx, 0.21, z + lz), Color(0.4, 0.26, 0.14))
			for p in 2:
				var c := Looks.make(_lava_crowd, person.call(rng.randf() < 0.5))
				c.position = Vector3(bx - sx * 0.08, 0.08, z - 0.7 + p * 1.3)
				c.rotation.y = sx * PI / 2.0  # kasvot salin keskelle
				c.play("Sitting_Talking" if p == 0 else "Sitting_Idle", 0.0)


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
	# Bändi soittaa lavalla (näkyy ikkunoista, humppa kuuluu pihalle), kun tanssit ovat käynnissä (set_lava_live).
	lava_band = HumppaBand.new()
	lava_band.position = st + Vector3(0, 1.0, 0)
	lava_band.rotation.y = PI  # yleisö (bändin -Z) tanssilattialle
	root.add_child(lava_band)
	lava_band.visible = false
	_lava_root = root
	_lava_dims = Vector3(w, l, side)  # bändi ja väki rakennetaan vasta tanssien alkaessa (hahmot ovat raskaita)
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
	_build_lava_lot(lv)
	_build_lava_fence(lv)
	_build_lava_youth(lv)
	_build_lava_gate(lv, side)


## Lavan parkkipaikka aidan ulkopuolella portin edessä: Pahalahdentie (sora) päättyy tähän, ja autot jäävät tänne. Aidan
## sisäpuoli (piha, lavan ovi) on kävelyaluetta: mopon ajoalue ei ulotu portin läpi (_build_drive_mask_calc). Parkin paikka
## ja mitat ovat tie.json:n kohdassa lava.lot (tools/vaala_asematie.py); mopo jää portin viereiseen ruutuun (lava_park).
var lava_park := Vector3.ZERO  # mopon paikka parkissa portin vieressä
func _build_lava_lot(lv: Dictionary) -> void:
	var lot: Dictionary = lv.get("lot", {})
	if lot.is_empty():
		return
	var c := Vector2(lot.c[0], lot.c[1])
	var ax := Vector2(lot.ax[0], lot.ax[1])
	var front := Vector2(lot.front[0], lot.front[1])
	var ua: float = lot.ua
	var nb: int = lot.nb
	var v0: float = lot.v0
	var g := Vector2(lv.gate[0], lv.gate[1])
	var bay := clampi(int(floorf((((g - c).dot(ax)) - ua) / LOT_BAY_W)), 0, nb - 1)
	var pp := c + ax * (ua + (bay + 0.5) * LOT_BAY_W) + front * (v0 + LOT_BAY_D / 2.0)
	lava_park = Vector3(pp.x, h(pp.x, pp.y), pp.y)
	_lava_cars.clear()
	for cp: Vector2 in _lot_build(c, ax, front, ua, nb, v0, float(lot.aisle), [pp], true):
		_lava_cars.append(cp)


## 90-luvun nuorison lavahommat: aidan järvenpuoleisen pään ympäri kahlataan pummilla sisään (pummi_out maalla aidan
## ulkopuolella, pummi_in sisäpuolella), ja aidan takana metsässä porukka ryyppää nuotiolla mopot puiden välissä
## ja kasettisoitin soimassa (party_pos). main.gd: ovet "pummi" ja "bileet".
var pummi_out := Vector3.ZERO
var pummi_in := Vector3.ZERO
## Kahlausalue aidan vesipään ympärillä: jalan saa kahlata vyötäröä myöten (WADE_DEPTH), muualla ei veteen.
const WADE_DEPTH := 1.3
var _wade_c := Vector2.INF
var _wade_r := 0.0
## Juhannuskokko lavan niemen rannassa aidan ulkopuolella (main.gd: pino juhannuksena, palaa KOKKO_AIKA).
var kokko_pos := Vector3.INF
var _kokko: Node3D
var _kokko_fire: Node3D
var _kokko_people: Node3D
var party_pos := Vector3.ZERO
var party_people: Array[Node3D] = []


func _build_lava_youth(lv: Dictionary) -> void:
	var pts: Array = lv.get("fence", [])
	if pts.size() < 2:
		return
	var lc := Vector2(lv.x, lv.z)
	# Pummireitti: aidan viimeisen pätkän vesipäästä kohti kulmaa, ensimmäinen kuiva kohta rannassa.
	var a := Vector2(pts[-1][0], pts[-1][1])
	var b := Vector2(pts[-2][0], pts[-2][1])
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	if nrm.dot(lc - a) > 0.0:
		nrm = -nrm  # nrm osoittaa aidan ulkopuolelle
	var shore := Vector2.INF
	for k in int(a.distance_to(b)):
		var q := a + dir * k
		if not wet(q.x, q.y, 0.3) and not wet(q.x + nrm.x * 3.0, q.y + nrm.y * 3.0, 0.3) and not wet(q.x - nrm.x * 3.0, q.y - nrm.y * 3.0, 0.3):
			shore = q + dir * 2.0
			break
	_wade_c = a
	_wade_r = (a.distance_to(shore) if shore != Vector2.INF else 10.0) + 9.0
	if shore != Vector2.INF:
		var po := shore + nrm * 2.5
		var pn := shore - nrm * 2.5
		pummi_out = Vector3(po.x, h(po.x, po.y), po.y)
		pummi_in = Vector3(pn.x, h(pn.x, pn.y), pn.y)
		doors.append({"id": "pummi", "pos": pummi_out, "out": Vector3(nrm.x, 0, nrm.y), "r": 4.0, "walk": true, "hint": "pummilla",
			"text": "Pummilla lavan pihalle järven kautta (kahlaa aidan pään ympäri)"})
		for off: float in [12.0, 15.0, 9.0, 18.0]:
			var kq := shore + nrm * off + dir * 3.0
			if not wet(kq.x, kq.y, 0.3) and not wet(kq.x + 2.0, kq.y, 0.3) and not wet(kq.x - 2.0, kq.y, 0.3):
				_build_kokko(kq, -dir)
				doors.append({"id": "kokko", "pos": kokko_pos + Vector3(nrm.x, 0, nrm.y) * 3.5, "out": Vector3(nrm.x, 0, nrm.y), "r": 5.0,
					"walk": true, "hint": "kokolle", "text": "Juhannuskokko rannalla"})
				break
		# Polku on tallattu rannan kaislikkoon: muutama lankku märkään kohtaan.
		for k in 3:
			var q := shore + dir * (-1.5 - k * 1.2) + nrm * 0.8
			var pl := B.mesh(self, B.boxm(Vector3(1.6, 0.06, 0.3)), Vector3(q.x, maxf(h(q.x, q.y), water_level) + 0.04, q.y), Color(0.45, 0.35, 0.22))
			pl.rotation.y = atan2(dir.x, dir.y) + 0.2 * (k - 1)
	# Bileet aidan takana: metsässä aidan pitkän sivun ulkopuolella, lavan kohdalla.
	var fa := Vector2(pts[1][0], pts[1][1])
	var fb := Vector2(pts[2][0], pts[2][1])
	var fd := (fb - fa).normalized()
	var fn := Vector2(-fd.y, fd.x)
	if fn.dot(lc - fa) > 0.0:
		fn = -fn
	var along := clampf((lc - fa).dot(fd), 10.0, fa.distance_to(fb) - 10.0)
	var spot := Vector2.INF
	for off: float in [14.0, 18.0, 11.0, 22.0]:
		for sl: float in [0.0, -10.0, 10.0, -20.0]:
			var q := fa + fd * (along + sl) + fn * off
			if not wet(q.x, q.y, 1.0) and spot == Vector2.INF:
				spot = q
	if spot == Vector2.INF:
		return
	party_pos = Vector3(spot.x, h(spot.x, spot.y), spot.y)
	doors.append({"id": "bileet", "pos": party_pos, "out": Vector3(-fn.x, 0, -fn.y), "r": 6.0, "walk": true, "hint": "bileisiin",
		"text": "Porukka aidan takana metsässä: liity seuraan"})
	_build_party(spot, fn)


## Nuotio kivirenkaineen, kaatuneet tukit penkkeinä, porukka (tuulitakit ja farkut, pipot ja lippikset), kaksi mopoa,
## kasettisoitin (lavan humppa kuuluu aidan takaa) ja tyhjiä pulloja.
func _build_party(c: Vector2, away: Vector2) -> void:
	var root := Node3D.new()
	root.position = Vector3(c.x, h(c.x, c.y), c.y)
	add_child(root)
	for k in 9:
		var a := TAU * k / 9.0
		B.mesh(root, B.sphere(0.16, 6), Vector3(cos(a) * 0.55, 0.08, sin(a) * 0.55), Color(0.42, 0.42, 0.4))
	for k in 3:
		var lg := B.mesh(root, B.cyl(0.05, 0.05, 0.7, 6), Vector3(0, 0.12, 0), Color(0.3, 0.2, 0.12))
		lg.rotation = Vector3(PI / 2.0 - 0.3, k * TAU / 3.0, 0)
	var fire := B.mesh(root, B.sphere(0.28, 8), Vector3(0, 0.3, 0), Color(1.0, 0.5, 0.1))
	fire.scale = Vector3(1, 1.5, 1)
	fire.material_override = B.unshaded(Color(1.0, 0.55, 0.15))
	var fl := OmniLight3D.new()
	fl.position = Vector3(0, 0.8, 0)
	fl.light_color = Color(1.0, 0.6, 0.3)
	fl.omni_range = 7.0
	fl.light_energy = 1.2
	root.add_child(fl)
	var logs := [[Vector3(0, 0, 1.9), 0.0], [Vector3(1.8, 0, -0.6), 1.25], [Vector3(-1.8, 0, -0.6), -1.25]]
	for lgd in logs:
		var lg := B.mesh(root, B.cyl(0.2, 0.22, 2.2, 8), lgd[0] + Vector3(0, 0.2, 0), Color(0.35, 0.25, 0.16))
		lg.rotation = Vector3(0, lgd[1], PI / 2.0)
	var looks := [
		{"shirt": Color(0.1, 0.35, 0.6), "pants": Color(0.25, 0.32, 0.5), "shoes": Color(0.9, 0.9, 0.9), "hair": "Hair_Buzzed",
			"hair_color": Color(0.7, 0.55, 0.3), "height": 1.76, "bulk": -0.6, "shoulders": -0.5, "tracksuit": {"a": Color(0.9, 0.2, 0.3), "b": Color(0.1, 0.35, 0.6)}},
		{"model": "female", "shirt": Color(0.12, 0.12, 0.14), "pants": Color(0.3, 0.38, 0.55), "shoes": Color(0.15, 0.15, 0.15), "hair": "Hair_Long",
			"hair_color": Color(0.85, 0.75, 0.5), "height": 1.66, "bulk": -0.5},
		{"shirt": Color(0.2, 0.45, 0.2), "pants": Color(0.15, 0.15, 0.17), "shoes": Color(0.2, 0.2, 0.2), "hair": "Hair_Long",
			"hair_color": Color(0.15, 0.1, 0.08), "height": 1.82, "bulk": -0.7, "shoulders": -0.6},
		{"model": "female", "shirt": Color(0.6, 0.1, 0.45), "pants": Color(0.1, 0.1, 0.12), "shoes": Color(0.9, 0.9, 0.9), "hair": "Hair_Buns",
			"hair_color": Color(0.35, 0.2, 0.1), "height": 1.62, "bulk": -0.6},
	]
	var seats := [[Vector3(-0.5, 0.0, 1.9), "Sitting_Idle"], [Vector3(0.5, 0.0, 1.9), "Sitting_Talking"], [Vector3(1.75, 0.0, -0.6), "Sitting_Idle"],
		[Vector3(-1.2, 0.0, -1.6), "Idle_Talking"]]
	for i in looks.size():
		var ch := Looks.make(root, looks[i])
		ch.position = seats[i][0] + (Vector3(0, 0.02, 0) if seats[i][1].begins_with("Sitting") else Vector3.ZERO)
		ch.rotation.y = B.yaw_to(-seats[i][0])
		ch.play(seats[i][1], 0.0)
		party_people.append(ch)
		if i == 2:
			Looks.add_cap(ch)
	# Pullot ja tölkit.
	for q in [Vector3(-0.9, 0.12, 1.4), Vector3(0.9, 0.12, 1.3), Vector3(1.3, 0.12, -0.2), Vector3(-1.5, 0.05, 0.6)]:
		B.mesh(root, B.cyl(0.04, 0.05, 0.25, 8), q, Color(0.25, 0.45, 0.25) if q.y > 0.1 else Color(0.85, 0.85, 0.9))
	B.mesh(root, B.cyl(0.035, 0.04, 0.12, 8), Vector3(0.2, 0.06, 1.45), Color(0.15, 0.35, 0.75))  # lonkerotölkki
	# Kasettisoitin tukilla ja musiikki (aidan takaa kuuluva humppa).
	var bb := B.mesh(root, B.boxm(Vector3(0.5, 0.22, 0.14)), Vector3(-1.0, 0.52, 1.9), Color(0.12, 0.12, 0.14))
	for sx: float in [-0.15, 0.15]:
		B.mesh(bb, B.cyl(0.07, 0.07, 0.02, 12), Vector3(sx, 0, 0.075), Color(0.4, 0.4, 0.42), Vector3(90, 0, 0))
	var mus := AudioStreamPlayer3D.new()
	var st90: AudioStream = load("res://scripts/headphones.gd").random_90s()
	mus.stream = st90 if st90 != null else Sfx.music_stream()  # kasetilla 90-luvun eurodancea
	mus.bus = "Music"
	mus.volume_db = -14.0
	mus.unit_size = 3.0
	mus.max_distance = 30.0
	mus.autoplay = true
	bb.add_child(mus)
	# Mopot puiden välissä.
	for k in 2:
		var mp := Node3D.new()
		var q := Vector3(away.x, 0, away.y) * (3.6 + k * 1.2) + Vector3(-away.y, 0, away.x) * (k * 1.6 - 0.8)
		mp.position = q
		mp.rotation.y = atan2(away.y, -away.x) + k * 0.4
		root.add_child(mp)
		var col: Color = [Color(0.85, 0.75, 0.1), Color(0.75, 0.1, 0.1)][k]
		for wz: float in [-0.55, 0.55]:
			B.mesh(mp, B.cyl(0.24, 0.24, 0.08, 14), Vector3(0, 0.24, wz), Color(0.08, 0.08, 0.08), Vector3(0, 0, 90))
		B.mesh(mp, B.boxm(Vector3(0.22, 0.28, 0.75)), Vector3(0, 0.5, 0.05), col)
		B.mesh(mp, B.boxm(Vector3(0.26, 0.1, 0.55)), Vector3(0, 0.7, 0.2), Color(0.1, 0.1, 0.1))
		B.tube(mp, Vector3(0, 0.45, -0.5), Vector3(0, 0.95, -0.4), 0.025, Color(0.7, 0.7, 0.72))
		B.tube(mp, Vector3(-0.3, 0.95, -0.4), Vector3(0.3, 0.95, -0.4), 0.02, Color(0.15, 0.15, 0.15))
	var body := StaticBody3D.new()
	root.add_child(body)
	body.add_child(B.box_shape(Vector3(1.2, 0.6, 1.2), Vector3(0, 0.3, 0)))  # nuotiota ei kävellä läpi
	# Kuusikko ympärillä (aidan puolelle aukko, josta lavan valot näkyvät).
	for k in 9:
		var a := TAU * k / 9.0 + 0.3
		var dirv := Vector2.from_angle(a)
		if dirv.dot(-away) > 0.6:
			continue
		var r := 5.5 + float(k % 3) * 1.6
		var tp := Vector3(dirv.x * r, 0, dirv.y * r)
		var th := 6.0 + float((k * 7) % 4)
		var gy := h(c.x + tp.x, c.y + tp.z) - root.position.y
		B.mesh(root, B.cyl(0.12, 0.18, th * 0.4, 6), tp + Vector3(0, gy + th * 0.2, 0), Color(0.3, 0.22, 0.15))
		for t in 3:
			var cr := (1.6 - t * 0.45) * (th / 7.0)
			B.mesh(root, B.cyl(0.0, cr, th * 0.38, 8), tp + Vector3(0, gy + th * (0.35 + t * 0.2), 0), Color(0.12, 0.28, 0.14).lightened(t * 0.04))
		body.add_child(B.box_shape(Vector3(0.4, 2.0, 0.4), tp + Vector3(0, gy + 1.0, 0)))


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


## Tienpinta maastoon sovitettuna kuten Saloisissa (world.gd _strip + _conform): nauha murtoviivaa pitkin, nivelet
## täytetään kiekoilla (ei kiiloja mutkiin), ja kolmiot leikataan maastoruudukon viivoilla, jolloin jokainen pala on
## täsmälleen yhden maastokolmion tasossa eikä maa pistä läpi eikä pinta roiku ilmassa. lift = korkeus maanpinnasta.
## Päät ovat suorat (risteyksessä toisen tien päälle ei jää pyöristystä); round_ends pyöristää ne.
func _ribbon(st: SurfaceTool, pts: PackedVector2Array, half: float, lift: float, round_ends := false) -> void:
	var tris := PackedVector3Array()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		if a.distance_to(b) < 0.01:
			continue
		var n := (b - a).normalized().orthogonal() * half
		for v in [a + n, b + n, b - n, a + n, b - n, a - n]:
			tris.append(Vector3(v.x, 0.0, v.y))
	for i in pts.size():
		var is_end := i == 0 or i == pts.size() - 1
		if is_end and not round_ends:
			continue
		if not is_end:
			# Suorilla pätkillä (tiheä näytteistys) kiekkoa ei tarvita, vain mutkissa.
			var d0 := pts[i] - pts[i - 1]
			var d1 := pts[i + 1] - pts[i]
			if d0.length() < 0.01 or d1.length() < 0.01 or absf(d0.angle_to(d1)) < 0.03:
				continue
		var p := pts[i]
		for k in 12:
			var a0 := TAU * k / 12.0
			var a1 := TAU * (k + 1) / 12.0
			tris.append(Vector3(p.x, 0.0, p.y))
			tris.append(Vector3(p.x + cos(a0) * half, 0.0, p.y + sin(a0) * half))
			tris.append(Vector3(p.x + cos(a1) * half, 0.0, p.y + sin(a1) * half))
	var out := PackedVector3Array()
	for t in range(0, tris.size() - 2, 3):
		_conform(tris[t], tris[t + 1], tris[t + 2], out)
	st.set_normal(Vector3.UP)
	for v in out:
		st.add_vertex(Vector3(v.x, h(v.x, v.z) + lift, v.z))


## Leikkaa kolmion maastoruudukon viivoilla (x, z ja lävistäjä x + z kuten h():n kolmioinnissa).
func _conform(a: Vector3, b: Vector3, c: Vector3, out: PackedVector3Array) -> void:
	Terrain.conform_tri(a, b, c, out, Vector2(_x0, _z0), _cell)


## Keskiviivan katkoviiva (Saloisten tapaan 3 m viiva / 6 m väli, leveys 0,24 m) tien päälle, päistä marginaali
## (risteyksessä ei viivaa toisen tien päällä).
func _dashes(st: SurfaceTool, pts: PackedVector2Array, lift: float, margin := 6.0) -> void:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var at := 0.0
	var t := margin
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.01:
			continue
		var d := (b - a) / seg
		while t < at + seg and t + 3.0 < total - margin:
			var t1 := minf(t + 3.0, at + seg)
			_ribbon(st, PackedVector2Array([a + d * (t - at), a + d * (t1 - at)]), 0.12, lift)
			t += 9.0
		at += seg


# --- Vaalan satama (Venesatama, tools/vaala_satama.py) -----------------------------------------------------------

const SATAMA_DECK := 0.7     # laiturin kansi vedenpinnan yläpuolella
const SATAMA_PIER_W := 2.2
const SATAMA_HEAD := Vector2(7.0, 2.4)  # T-pään leveys ja syvyys
const SATAMA_FINGER := Vector2(5.0, 1.4)  # sormilaituri: pituus sivuun, leveys
const SATAMA_BOAT_X := 2.6   # muskelivene laiturin kyljessä (laiturin keskiviivalta)
var satama_door := Vector3.ZERO  # laiturin juuri kannella (ovi "satama")
var satama_dock := Vector3.ZERO  # laiturin kärki kannen tasolla
var satama_dir := Vector2.ZERO   # laiturilta järvelle
var satama_park := Vector3.ZERO  # parkkipaikan keskus
var satama_boat: Node3D          # parkissa oleva muskelivene (main.gd piilottaa ajon ajaksi)
var satama_boat_tf := Transform3D.IDENTITY  # veneen paikka parkissa (Vaalan kehyksessä)
var _sat_xf := Transform3D.IDENTITY  # laiturin kehys: origo juurella kannen korkeudella, +Z järvelle, +X sivulle


## Vedenpinnan korkeus kohdassa: lähimmän vesiruudun pohja + 1,2 (kuten _build_water), muuten järven taso.
func water_y(x: float, z: float) -> float:
	var i0 := int(roundf((x - _x0) / _cell))
	var j0 := int(roundf((z - _z0) / _cell))
	for r in 6:
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r:
					continue
				var i := i0 + di
				var j := j0 + dj
				if i >= 0 and j >= 0 and i < _nx and j < _nz and _codes[j * _nx + i] == WATER:
					return _h[j * _nx + i] + 1.2
	return water_level


## Sataman laiturien ja moottoriveneen (T-pää, sormilaituri) suorakaiteet laiturin kehyksessä [x0, z0, x1, z1].
func _sat_rects() -> Array:
	var sd: Dictionary = data.satama
	var dl: float = sd.dock_len
	return [Rect2(-SATAMA_PIER_W / 2.0, -0.5, SATAMA_PIER_W, dl + 0.5),
		Rect2(-SATAMA_HEAD.x / 2.0, dl - SATAMA_HEAD.y / 2.0, SATAMA_HEAD.x, SATAMA_HEAD.y),
		Rect2(SATAMA_PIER_W / 2.0, dl - 10.1, SATAMA_FINGER.x, SATAMA_FINGER.y)]


## Voiko vene olla kohdassa (x, z): vedessä, avovedessä (ei rannan vieressä), ei laiturien, lavan aidan eikä sillan
## kohdalla, ja yhteydessä satamaan (maski lasketaan kerran, _boat_mask). Tarkan ruudukon ulkopuoli on aina false.
func boat_free(x: float, z: float) -> bool:
	if not data.has("satama"):
		return false
	var m: PackedByteArray = _boat_mask()
	var i := int(roundf((x - _x0) / _cell))
	var j := int(roundf((z - _z0) / _cell))
	if i < 0 or j < 0 or i >= _nx or j >= _nz or m[j * _nx + i] == 0:
		return false
	var sd: Dictionary = data.satama
	var d := Vector2(sd.dir[0], sd.dir[1])
	var rel := Vector2(x - sd.x, z - sd.z)
	var lp := Vector2(rel.dot(Vector2(d.y, -d.x)), rel.dot(d))  # laiturin kehys: x sivulle, y järvelle
	for r: Rect2 in _sat_rects():
		if r.grow(0.2).has_point(lp):
			return false
	if _lp_dir != Vector2.ZERO:
		var lrel := Vector2(x, z) - _lp_root
		var llp := Vector2(lrel.dot(Vector2(_lp_dir.y, -_lp_dir.x)), lrel.dot(_lp_dir))
		for r: Rect2 in _lp_rects():
			if r.grow(0.2).has_point(llp):
				return false
	return true


## Veneen alue: vesiruudut, joihin pääsee laiturilta 4-naapuruudun täytöllä, kun rannan ja kaikkien ei-vesiruutujen
## viereiset ruudut, lavan aidan (3 m) ja Oulujoen sillan (20 m) ympäristö on jätetty pois.
func _boat_mask() -> PackedByteArray:
	if _memo.has("boat"):
		return _memo.boat
	var sd: Dictionary = data.satama
	var near := PackedByteArray()
	near.resize(_nx * _nz)
	var blocked := PackedByteArray()
	blocked.resize(_nx * _nz)
	var fence: Array = data.get("lava", {}).get("fence", [])
	for k in fence.size() - 1:
		var a := Vector2(fence[k][0], fence[k][1])
		var b := Vector2(fence[k + 1][0], fence[k + 1][1])
		var steps := ceili(a.distance_to(b) / 2.0)
		for s in steps + 1:
			_sat_block(blocked, a.lerp(b, float(s) / steps), 3.0 + _cell * 0.5)
	for br in data.bridges:
		for q in range(int(br[0]), int(br[1]) + 1):
			_sat_block(blocked, Vector2(road[q][0], road[q][2]), 20.0)
	var mask := PackedByteArray()
	mask.resize(_nx * _nz)
	var d := Vector2(sd.dir[0], sd.dir[1])
	var tip := Vector2(sd.x, sd.z) + d * (float(sd.dock_len) + 3.0)
	var start := Vector2i(int(roundf((tip.x - _x0) / _cell)), int(roundf((tip.y - _z0) / _cell)))
	var stack: Array[Vector2i] = [start]
	var ok := func(i: int, j: int) -> bool:
		if i < 1 or j < 1 or i >= _nx - 1 or j >= _nz - 1:
			return false
		for dj in [-1, 0, 1]:
			for di in [-1, 0, 1]:
				if _codes[(j + dj) * _nx + i + di] != WATER:
					return false
		return blocked[j * _nx + i] == 0
	var count := 0
	var edge := false
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		var q := c.y * _nx + c.x
		if mask[q] != 0 or not ok.call(c.x, c.y):
			continue
		mask[q] = 1
		count += 1
		if c.x >= _nx - 3 or c.y >= _nz - 3:
			edge = true
		stack.append_array([Vector2i(c.x + 1, c.y), Vector2i(c.x - 1, c.y), Vector2i(c.x, c.y + 1), Vector2i(c.x, c.y - 1)])
	print("VAALA venemaski %d ruutua, saavuttaa tarkan alueen kaakkoisreunan: %s" % [count, edge])
	_memo.boat = mask
	return mask


func _sat_block(blocked: PackedByteArray, p: Vector2, r: float) -> void:
	var rc := ceili(r / _cell)
	var i0 := int(roundf((p.x - _x0) / _cell))
	var j0 := int(roundf((p.y - _z0) / _cell))
	for j in range(maxi(j0 - rc, 0), mini(j0 + rc, _nz - 1) + 1):
		for i in range(maxi(i0 - rc, 0), mini(i0 + rc, _nx - 1) + 1):
			if Vector2(_x0 + i * _cell, _z0 + j * _cell).distance_to(p) <= r:
				blocked[j * _nx + i] = 1


## Satama: pääsiltalaituri T-päällä ja sormilaituri (pukit pohjaan, kansi vedenpinnan yläpuolella), rantakivetys,
## pollarit, kaksi soutuvenettä, muskelivene laiturin kyljessä, sorapihan parkki, auto ja kyltti. Ovi "satama"
## laiturin juuressa: E käynnistää ajon (main.gd).
func _build_satama() -> void:
	if not data.has("satama"):
		return
	var sd: Dictionary = data.satama
	var d := Vector2(sd.dir[0], sd.dir[1])
	var side := Vector2(d.y, -d.x)  # laiturin +X
	var dl: float = sd.dock_len
	var root := Vector2(sd.x, sd.z)
	var wy := water_y(root.x + d.x * dl, root.y + d.y * dl)
	var dy := wy + SATAMA_DECK
	var yaw := atan2(d.x, d.y)
	_sat_xf = Transform3D(Basis(Vector3.UP, yaw), Vector3(root.x, dy, root.y))
	satama_dir = d
	satama_door = _sat_xf * Vector3(0, 0, 2.0)
	satama_dock = _sat_xf * Vector3(0, 0, dl)
	var wood := Color(0.6, 0.45, 0.3)
	var dark := Color(0.33, 0.24, 0.16)
	var pile_c := Color(0.27, 0.2, 0.14)
	var dock := StaticBody3D.new()
	dock.set_meta("ground", true)
	dock.transform = _sat_xf
	add_child(dock)
	var pw := SATAMA_PIER_W
	# Pääsilta: kansilaudat poikittain (saumat), reunapalkit ja alapalkit.
	B.mesh(dock, B.boxm(Vector3(pw, 0.1, dl)), Vector3(0, -0.05, dl / 2.0), wood)
	var hd := SATAMA_HEAD
	B.mesh(dock, B.boxm(Vector3(hd.x, 0.1, hd.y)), Vector3(0, -0.05, dl), wood)
	var fg := SATAMA_FINGER
	var fz := dl - 9.4
	B.mesh(dock, B.boxm(Vector3(fg.x, 0.1, fg.y)), Vector3(pw / 2.0 + fg.x / 2.0, -0.05, fz), wood.darkened(0.06))
	for k in int(dl / 0.8):
		B.mesh(dock, B.boxm(Vector3(pw, 0.012, 0.025)), Vector3(0, 0.002, 0.4 + k * 0.8), dark)
	for k in int(hd.y / 0.8):
		B.mesh(dock, B.boxm(Vector3(hd.x, 0.012, 0.025)), Vector3(0, 0.002, dl - hd.y / 2.0 + 0.4 + k * 0.8), dark)
	for k in int(fg.x / 0.8):
		B.mesh(dock, B.boxm(Vector3(0.025, 0.012, fg.y)), Vector3(pw / 2.0 + 0.4 + k * 0.8, 0.002, fz), dark)
	for sx in [-1.0, 1.0]:
		B.mesh(dock, B.boxm(Vector3(0.14, 0.2, dl)), Vector3(sx * (pw / 2.0 - 0.07), -0.2, dl / 2.0), dark)
	B.mesh(dock, B.boxm(Vector3(hd.x, 0.2, 0.14)), Vector3(0, -0.2, dl + hd.y / 2.0 - 0.07), dark)
	B.mesh(dock, B.boxm(Vector3(0.14, 0.2, fg.x)), Vector3(pw / 2.0 + fg.x / 2.0, -0.2, fz + fg.y / 2.0 - 0.07), dark).rotation.y = PI / 2.0
	# Törmäys kansille.
	dock.add_child(B.box_shape(Vector3(pw, 0.3, dl), Vector3(0, -0.15, dl / 2.0)))
	dock.add_child(B.box_shape(Vector3(hd.x, 0.3, hd.y), Vector3(0, -0.15, dl)))
	dock.add_child(B.box_shape(Vector3(fg.x, 0.3, fg.y), Vector3(pw / 2.0 + fg.x / 2.0, -0.15, fz)))
	# Luiska rannasta kannelle (maa on kantta korkeammalla).
	var rise := maxf(h(root.x, root.y) - dy, 0.0) + 0.06
	var run := maxf(1.4, rise * 2.2)
	var ramp := B.box_shape(Vector3(pw, 0.1, Vector2(run, rise).length()), Vector3.ZERO)
	ramp.transform = Transform3D(Basis(Vector3.RIGHT, atan2(rise, run)), Vector3(0, -0.05 + rise / 2.0, -run / 2.0))
	dock.add_child(ramp)
	B.mesh(dock, B.boxm(Vector3(pw, 0.08, Vector2(run, rise).length())), Vector3(0, -0.05 + rise / 2.0 - 0.03, -run / 2.0), wood.darkened(0.1)).rotation.x = atan2(rise, run)
	# Pukit pohjaan (pohjan korkeus h() kunkin pukin kohdalla); rannalla maan sisään jäävät jätetään pois.
	var piles: Array[Vector3] = []
	for k in int(dl / 2.4) + 1:
		for sx in [-1.0, 1.0]:
			piles.append(Vector3(sx * (pw / 2.0 - 0.1), 0, minf(1.6 + k * 2.4, dl)))
	for sx in [-1.0, 1.0]:
		piles.append(Vector3(sx * (hd.x / 2.0 - 0.15), 0, dl + hd.y / 2.0 - 0.15))
		piles.append(Vector3(sx * (hd.x / 2.0 - 0.15), 0, dl - hd.y / 2.0 + 0.15))
	for k in 3:
		piles.append(Vector3(pw / 2.0 + 1.2 + k * 2.0, 0, fz + fg.y / 2.0 - 0.1))
		piles.append(Vector3(pw / 2.0 + 1.2 + k * 2.0, 0, fz - fg.y / 2.0 + 0.1))
	for pl in piles:
		var gp := _sat_xf * pl
		var bottom := h(gp.x, gp.z)
		if bottom > dy - 0.4:
			continue
		var top := 0.3 if int(pl.z * 10.0) % 3 == 0 else -0.02
		var ph := top - (bottom - dy) + 0.1
		B.mesh(dock, B.cyl(0.1, 0.1, ph, 8), Vector3(pl.x, top - ph / 2.0, pl.z), pile_c)
	# Pollarit pääsillan reunoilla ja T-pään kulmissa.
	var bollards: Array[Vector3] = []
	for k in 4:
		for sx in [-1.0, 1.0]:
			bollards.append(Vector3(sx * (pw / 2.0 - 0.18), 0.0, 3.0 + k * 3.2))
	for sx in [-1.0, 1.0]:
		bollards.append(Vector3(sx * (hd.x / 2.0 - 0.3), 0.0, dl + hd.y / 2.0 - 0.25))
	for bp in bollards:
		B.mesh(dock, B.cyl(0.09, 0.11, 0.34, 10), bp + Vector3(0, 0.17, 0), Color(0.12, 0.2, 0.16))
		B.mesh(dock, B.cyl(0.13, 0.13, 0.06, 10), bp + Vector3(0, 0.36, 0), Color(0.16, 0.26, 0.2))
	# Lyhty T-päässä.
	B.mesh(dock, B.cyl(0.05, 0.06, 2.6, 8), Vector3(hd.x / 2.0 - 0.4, 1.3, dl + 0.2), Color(0.18, 0.18, 0.2))
	B.mesh(dock, B.boxm(Vector3(0.26, 0.3, 0.26)), Vector3(hd.x / 2.0 - 0.4, 2.7, dl + 0.2), Color(1.0, 0.92, 0.6))
	B.mesh(dock, B.boxm(Vector3(0.36, 0.06, 0.36)), Vector3(hd.x / 2.0 - 0.4, 2.89, dl + 0.2), Color(0.18, 0.18, 0.2))
	# Soutuveneet pääsillan toisella kyljellä köysissä pollareihin.
	var fish: Script = load("res://scripts/fish_game.gd")
	for k in 2:
		var bz := dl - 4.5 - k * 4.2
		var rb := Node3D.new()
		rb.transform = _sat_xf * Transform3D(Basis(Vector3.UP, PI + (0.06 if k == 0 else -0.05)), Vector3(-2.0, wy - dy, bz))
		add_child(rb)
		fish.build_boat(rb, true)
		B.tube(dock, Vector3(-pw / 2.0 + 0.18, 0.3, 3.0 + 3.2 * (2 - k) - 0.1), Vector3(-1.45, wy - dy + 0.35, bz + 0.6), 0.02, Color(0.75, 0.68, 0.5))
	# Muskelivene pääsillan kyljessä (peräpää sormilaituria vasten); main.gd käyttää satama_boat_tf:ää ajon alkuun ja loppuun.
	satama_boat_tf = _sat_xf * Transform3D(Basis(Vector3.UP, PI), Vector3(SATAMA_BOAT_X, wy - dy, dl - 4.9))
	satama_boat = Node3D.new()
	add_child(satama_boat)
	satama_boat.transform = satama_boat_tf
	Muskelivene.build(satama_boat)
	for bz in [dl - 7.0, dl - 3.5]:
		B.tube(dock, Vector3(pw / 2.0 - 0.18, 0.3, 3.0 + 3.2 * floorf((bz - 3.0) / 3.2)), Vector3(1.45, wy - dy + 0.9, bz), 0.02, Color(0.9, 0.9, 0.85))
	_sat_shore(d, root, wy)
	_sat_park(sd, d, side, yaw)
	# Kyltti kahdella tolpalla pihan ja laiturin rajalla.
	var sp := root - d * 4.0 + side * 5.6
	var sy := h(sp.x, sp.y)
	var plate := B.sign_plate(self, "VAALAN SATAMA\nSahanranta · Vierasvenepaikat", Color(0.1, 0.3, 0.5), Color(0.97, 0.97, 0.92), 0.34, 52, Color(0.95, 0.95, 0.9))
	var pwid: float = plate.get_meta("width")
	plate.position = Vector3(sp.x, sy + 2.3, sp.y)
	plate.rotation.y = yaw
	for sx in [-1.0, 1.0]:
		var pp: Vector2 = sp + side * sx * (pwid / 2.0 + 0.06)
		B.mesh(self, B.cyl(0.05, 0.06, 2.7, 8), Vector3(pp.x, h(pp.x, pp.y) + 1.35, pp.y), Color(0.3, 0.22, 0.15))
	doors.append({"id": "satama", "pos": satama_door, "out": Vector3(-d.x, 0, -d.y), "r": dl * 0.8, "walk": true,
		"text": "Muskeliveneellä Oulujärvelle"})


# --- Uiton sauna (Sahanranta, tools/vaala_sahanranta.py "uitto") ---------------------------------------------------
## Oulujoen uiton jäljiltä rannassa on hirsisauna, makasiini (nykyään kanoottitalli), laituri ja nuotiopaikka (Vaalan
## Sahanranta, Uitontie). Sauna on mitoiltaan savusaunan kaltainen (cutscene.gd SAUNA_SAVU: sisätila samoissa
## koordinaateissa), joten Cutscene.sauna_relax toimii sen rungon kehyksessä. Laiturin tikkailta uidaan Oulujärveen
## (Cutscene.swim_dive saunan viereiseltä rannalta). Ovet "uittosauna" ja "uittouinti" (main.gd _on_vaala_door).
const UITTO_W := 3.4          # sauna: leveys x syvyys (samat kuin mokki.gd SAUNA_SIZE)
const UITTO_D := 2.9
const UITTO_TER := 2.4        # terassi järven puolella
const UITTO_DOOR_X := -0.8
const UITTO_PIER_W := 1.7
var uitto_door := Vector3.ZERO       # saunan oven edusta terassilla
var uitto_pier_door := Vector3.ZERO  # laiturin päässä, tikkaiden luona
var uitto_dir := Vector2.ZERO        # rannalta järvelle
var uitto_wl := 0.0                  # vedenpinta laiturin kohdalla
var uitto_beach_tf := Transform3D()  # uimaranta saunan vieressä (vesiraja, +Z järvelle), Vaalan kehyksessä
var _uitto_body: StaticBody3D


func uitto_sauna_frame() -> Transform3D:
	return _uitto_body.global_transform


func uitto_beach_frame() -> Transform3D:
	return global_transform * uitto_beach_tf


func _build_uitto() -> void:
	if not data.has("uitto"):
		return
	var ud: Dictionary = data.uitto
	var d := Vector2(ud.dir[0], ud.dir[1])
	var side := Vector2(d.y, -d.x)
	var root := Vector2(ud.x, ud.z)
	var dl: float = ud.dock_len
	var yaw := atan2(d.x, d.y)
	var at := func(u: float, v: float) -> Vector2: return root + side * u + d * v  # rannan kehys: u sivulle, v järvelle
	var pc := Vector2(ud.park[0], ud.park[1])
	var gy := h(pc.x, pc.y)  # piha on tasoitettu
	uitto_dir = d
	uitto_wl = water_y(root.x + d.x * dl, root.y + d.y * dl)
	var wy := uitto_wl
	var dy := wy + 0.5
	var log_col := Color(0.4, 0.29, 0.18)
	var board := Color(0.5, 0.4, 0.28)
	var roof_col := Color(0.2, 0.19, 0.18)
	# --- Laituri: lankkukansi, reunapalkit, pukit, luiska, tikkaat, pelastusrengas ja penkki päässä. ---
	var pier_xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(root.x, dy, root.y))
	var dock := StaticBody3D.new()
	dock.set_meta("ground", true)
	dock.transform = pier_xf
	add_child(dock)
	var pw := UITTO_PIER_W
	var wood := Color(0.6, 0.45, 0.3)
	var dark := Color(0.33, 0.24, 0.16)
	B.mesh(dock, B.boxm(Vector3(pw, 0.1, dl)), Vector3(0, -0.05, dl / 2.0), wood)
	for k in int(dl / 0.5):
		B.mesh(dock, B.boxm(Vector3(pw, 0.012, 0.025)), Vector3(0, 0.002, 0.3 + k * 0.5), dark)
	for sx in [-1.0, 1.0]:
		B.mesh(dock, B.boxm(Vector3(0.12, 0.2, dl)), Vector3(sx * (pw / 2.0 - 0.06), -0.2, dl / 2.0), dark)
	dock.add_child(B.box_shape(Vector3(pw, 0.3, dl), Vector3(0, -0.15, dl / 2.0)))
	var prise := maxf(h(root.x, root.y) - dy, 0.0) + 0.06
	var prun := maxf(1.4, prise * 2.2)
	var pramp := B.box_shape(Vector3(pw, 0.1, Vector2(prun, prise).length()), Vector3.ZERO)
	pramp.transform = Transform3D(Basis(Vector3.RIGHT, atan2(prise, prun)), Vector3(0, -0.05 + prise / 2.0, -prun / 2.0))
	dock.add_child(pramp)
	B.mesh(dock, B.boxm(Vector3(pw, 0.08, Vector2(prun, prise).length())), Vector3(0, -0.05 + prise / 2.0 - 0.03, -prun / 2.0), wood.darkened(0.1)).rotation.x = atan2(prise, prun)
	for k in int(dl / 2.4) + 1:
		for sx in [-1.0, 1.0]:
			var pz := minf(1.4 + k * 2.4, dl - 0.1)
			var gp := pier_xf * Vector3(sx * (pw / 2.0 - 0.1), 0, pz)
			var bottom := h(gp.x, gp.z)
			if bottom > dy - 0.4:
				continue
			var ph := 0.12 - (bottom - dy) + 0.1
			B.mesh(dock, B.cyl(0.1, 0.1, ph, 8), Vector3(sx * (pw / 2.0 - 0.1), 0.12 - ph / 2.0, pz), Color(0.27, 0.2, 0.14))
	# Penkki laiturin päässä, pollarit ja pelastusrengas pylvään päällä.
	B.mesh(dock, B.boxm(Vector3(1.3, 0.06, 0.38)), Vector3(-0.1, 0.46, dl - 0.5), board)
	for bx in [-0.6, 0.4]:
		B.mesh(dock, B.boxm(Vector3(0.06, 0.4, 0.34)), Vector3(bx, 0.23, dl - 0.5), board.darkened(0.25))
	for bz in [2.0, dl - 1.3]:
		for sx in [-1.0, 1.0]:
			B.mesh(dock, B.cyl(0.08, 0.1, 0.3, 8), Vector3(sx * (pw / 2.0 - 0.14), 0.15, bz), Color(0.15, 0.2, 0.17))
	B.mesh(dock, B.cyl(0.04, 0.05, 1.5, 8), Vector3(-pw / 2.0 + 0.12, 0.75, dl - 2.4), Color(0.3, 0.22, 0.15))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.17
	ring.outer_radius = 0.3
	B.mesh(dock, ring, Vector3(-pw / 2.0 + 0.2, 1.3, dl - 2.4), Color(0.85, 0.15, 0.12), Vector3(90, 0, 0))
	# Uimatikkaat laiturin päässä (ruostumaton teräs): kaksi pystyputkea ja askelmat veden alle, kaari kannen yli.
	var lx := pw / 2.0 + 0.05
	var steel := Color(0.78, 0.8, 0.82)
	for sz in [-0.24, 0.24]:
		B.tube(dock, Vector3(lx - 0.28, 0.75, dl - 0.7 + sz), Vector3(lx, 0.9, dl - 0.7 + sz), 0.022, steel)
		B.tube(dock, Vector3(lx, 0.9, dl - 0.7 + sz), Vector3(lx, -0.95, dl - 0.7 + sz), 0.022, steel)
	for k in 5:
		B.tube(dock, Vector3(lx, 0.4 - k * 0.3, dl - 0.94), Vector3(lx, 0.4 - k * 0.3, dl - 0.46), 0.017, steel)
	# Soutuvene köydellä pollareihin laiturin toisella kyljellä.
	var fish: Script = load("res://scripts/fish_game.gd")
	var rb := Node3D.new()
	rb.transform = pier_xf * Transform3D(Basis(Vector3.UP, PI + 0.05), Vector3(-1.9, wy - dy, dl - 3.5))
	add_child(rb)
	fish.build_boat(rb, true)
	B.tube(dock, Vector3(-pw / 2.0 + 0.14, 0.3, 2.0), Vector3(-1.35, wy - dy + 0.35, dl - 2.9), 0.02, Color(0.75, 0.68, 0.5))
	var keep_park := satama_park
	_sat_park(ud, d, side, yaw)
	satama_park = keep_park
	uitto_pier_door = pier_xf * Vector3(0, 0, dl - 2.2)
	doors.append({"id": "uittouinti", "pos": uitto_pier_door, "out": Vector3(-d.x, 0, -d.y), "r": 6.0, "walk": true,
		"text": "Uimaan Oulujärveen Uiton laiturilta"})
	# Uimaranta laiturin vieressä: vesirajan kohta u = -5 (alkaa maalta, kahlaus, sukellus).
	var bq: Vector2 = at.call(-5.0, 0.0)
	for t in range(0, 24):
		var q: Vector2 = bq + d * float(t)
		if wet(q.x, q.y, 0.0):
			bq = q
			break
	uitto_beach_tf = Transform3D(Basis(Vector3.UP, yaw), Vector3(bq.x, h(bq.x, bq.y), bq.y))
	_sat_shore(d, root, wy, [[bq - d * 3.0, 11.0]])  # rantakivet pois uimarannan edestä
	# --- Hirsisauna (mitat ja sisätila kuten mokki.gd _build_savusauna, jotta sauna_relax sopii) ---
	var w := UITTO_W
	var dd := UITTO_D
	var fz := dd / 2.0
	var ter := UITTO_TER
	var wall_h := 2.0
	var rise := 1.0
	var sc: Vector2 = at.call(7.0, -6.2)
	var sbody := StaticBody3D.new()
	sbody.position = Vector3(sc.x, gy + 0.2, sc.y)
	sbody.rotation.y = yaw
	add_child(sbody)
	_uitto_body = sbody
	var dxs := UITTO_DOOR_X
	var dw := 0.8
	var door_top := 1.7
	var y := 0.14
	while y < wall_h:
		var col := log_col if int(y * 10) % 2 else log_col.darkened(0.12)
		B.mesh(sbody, B.cyl(0.09, 0.09, w + 0.18, 8), Vector3(0, y, -fz), col, Vector3(0, 0, 90))
		for sx in [-1.0, 1.0]:
			B.mesh(sbody, B.cyl(0.09, 0.09, dd + 0.18, 8), Vector3(sx * w / 2.0, y, 0), col, Vector3(90, 0, 0))
		if y < door_top:
			for seg in [[-w / 2.0 - 0.09, dxs - dw / 2.0], [dxs + dw / 2.0, w / 2.0 + 0.09]]:
				B.mesh(sbody, B.cyl(0.09, 0.09, seg[1] - seg[0], 8), Vector3((seg[0] + seg[1]) / 2.0, y, fz), col, Vector3(0, 0, 90))
		else:
			B.mesh(sbody, B.cyl(0.09, 0.09, w + 0.18, 8), Vector3(0, y, fz), col, Vector3(0, 0, 90))
		y += 0.17
	sbody.add_child(B.box_shape(Vector3(w + 0.2, wall_h, 0.2), Vector3(0, wall_h / 2.0, -fz)))
	for sx in [-1.0, 1.0]:
		sbody.add_child(B.box_shape(Vector3(0.2, wall_h, dd + 0.2), Vector3(sx * w / 2.0, wall_h / 2.0, 0)))
	var lw := dxs - dw / 2.0 + w / 2.0
	sbody.add_child(B.box_shape(Vector3(lw, wall_h, 0.2), Vector3(-w / 2.0 + lw / 2.0, wall_h / 2.0, fz)))
	var rw := w / 2.0 - dxs - dw / 2.0
	sbody.add_child(B.box_shape(Vector3(rw, wall_h, 0.2), Vector3(w / 2.0 - rw / 2.0, wall_h / 2.0, fz)))
	var roof := PrismMesh.new()
	roof.size = Vector3(w + 1.0, rise, dd + ter + 0.7)
	B.mesh(sbody, roof, Vector3(0, wall_h + rise / 2.0, ter / 2.0), roof_col)
	var gable := PrismMesh.new()
	gable.size = Vector3(w + 0.18, rise - 0.05, 0.14)
	B.mesh(sbody, gable, Vector3(0, wall_h + (rise - 0.05) / 2.0, fz), log_col.darkened(0.2))
	var gable2 := PrismMesh.new()
	gable2.size = Vector3(w + 0.3, rise - 0.05, 0.08)
	B.mesh(sbody, gable2, Vector3(0, wall_h + (rise - 0.05) / 2.0, fz + ter + 0.1), Color(0.3, 0.22, 0.14))
	B.mesh(sbody, B.boxm(Vector3(w + 0.4, 0.16, 0.16)), Vector3(0, wall_h - 0.06, fz + ter + 0.1), log_col.darkened(0.15))
	for sx in [-1.0, 1.0]:
		B.mesh(sbody, B.boxm(Vector3(0.14, 0.14, ter + 0.2)), Vector3(sx * w / 2.0, wall_h - 0.06, fz + ter / 2.0), log_col.darkened(0.15))
		B.mesh(sbody, B.cyl(0.08, 0.08, wall_h, 8), Vector3(sx * w / 2.0, wall_h / 2.0, fz + ter), log_col)
		sbody.add_child(B.box_shape(Vector3(0.18, wall_h, 0.18), Vector3(sx * w / 2.0, wall_h / 2.0, fz + ter)))
	# Ovi, ikkuna sivuseinässä ja nurkkahirsien päät.
	B.mesh(sbody, B.boxm(Vector3(dw - 0.06, door_top - 0.1, 0.06)), Vector3(dxs, 0.08 + (door_top - 0.1) / 2.0, fz + 0.04), Color(0.35, 0.24, 0.14))
	B.mesh(sbody, B.boxm(Vector3(0.04, 0.04, 0.08)), Vector3(dxs + 0.28, 1.0, fz + 0.09), Color(0.2, 0.2, 0.2))
	B.mesh(sbody, B.boxm(Vector3(0.04, 0.52, 0.62)), Vector3(-w / 2.0 - 0.1, 1.25, -0.3), Color(0.3, 0.22, 0.14))
	B.mesh(sbody, B.boxm(Vector3(0.03, 0.4, 0.5)), Vector3(-w / 2.0 - 0.12, 1.25, -0.3), Color(0.62, 0.7, 0.74))
	# Kivijalka, lattia, terassin kansi ja portaat; luiska portaille (CharacterBody ei nouse askelmia).
	var low := -0.55
	B.mesh(sbody, B.boxm(Vector3(w + 0.1, -low, dd + 0.1)), Vector3(0, low / 2.0, 0), Color(0.36, 0.35, 0.33))
	B.mesh(sbody, B.boxm(Vector3(w - 0.1, 0.06, dd - 0.1)), Vector3(0, 0.06, 0), Color(0.3, 0.24, 0.17))
	sbody.add_child(B.box_shape(Vector3(w, 0.4 - low, dd), Vector3(0, (low + 0.09) / 2.0 - 0.15, 0)))
	for k in int(ter / 0.15):
		B.mesh(sbody, B.boxm(Vector3(w + 0.3, 0.05, 0.13)), Vector3(0, 0.13, fz + 0.12 + k * 0.15), board.darkened(0.06 * (k % 3)))
	sbody.add_child(B.box_shape(Vector3(w + 0.3, 0.15 - low, ter + 0.1), Vector3(0, (0.15 + low) / 2.0, fz + ter / 2.0 + 0.05)))
	B.mesh(sbody, B.boxm(Vector3(w + 0.3, 0.1 - low, 0.04)), Vector3(0, (0.1 + low) / 2.0, fz + ter + 0.08), board.darkened(0.4))
	var steps := 2
	for i in steps:
		B.mesh(sbody, B.boxm(Vector3(1.4, 0.2, 0.3)), Vector3(0.4, 0.05 - i * 0.2, fz + ter + 0.28 + i * 0.3), board.darkened(0.08 * (i % 2)))
	var rr := B.box_shape(Vector3(1.4, 0.1, 1.1), Vector3.ZERO)
	rr.transform = Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0.4, -0.12, fz + ter + 0.4))
	sbody.add_child(rr)
	# Terassin penkki, kiulu ja vihtapata sekä pyyhe kaiteella.
	B.mesh(sbody, B.boxm(Vector3(1.3, 0.06, 0.4)), Vector3(0.85, 0.55, fz + 0.35), board)
	for bx in [0.35, 1.35]:
		B.mesh(sbody, B.boxm(Vector3(0.06, 0.42, 0.34)), Vector3(bx, 0.36, fz + 0.35), board.darkened(0.2))
	B.mesh(sbody, B.cyl(0.28, 0.3, 0.4, 16), Vector3(-1.1, 0.35, fz + ter - 0.5), Color(0.34, 0.24, 0.15))
	# Sisätila (cutscene.gd SAUNA_SAVU): lauteet takaseinällä, kivikiuas oven vieressä, kiulu.
	var lt := Color(0.5, 0.38, 0.24)
	B.mesh(sbody, B.boxm(Vector3(w - 0.25, 0.07, 0.95)), Vector3(0, 1.0, -fz + 0.6), lt)
	B.mesh(sbody, B.boxm(Vector3(w - 0.25, 0.06, 0.4)), Vector3(0, 0.5, -fz + 1.3), lt.darkened(0.08))
	for bx in [-1.2, 0.0, 1.2]:
		B.mesh(sbody, B.boxm(Vector3(0.08, 1.0, 0.08)), Vector3(bx, 0.5, -fz + 1.03), lt.darkened(0.3))
		B.mesh(sbody, B.boxm(Vector3(0.08, 0.5, 0.08)), Vector3(bx, 0.25, -fz + 1.45), lt.darkened(0.3))
	var kl := Vector3(0.9, 0.0, 0.5)
	var stone := Color(0.3, 0.29, 0.28)
	B.mesh(sbody, B.boxm(Vector3(0.95, 0.6, 0.18)), Vector3(kl.x, 0.3, kl.z - 0.36), stone)
	B.mesh(sbody, B.boxm(Vector3(0.95, 0.6, 0.18)), Vector3(kl.x, 0.3, kl.z + 0.36), stone)
	B.mesh(sbody, B.boxm(Vector3(0.18, 0.6, 0.9)), Vector3(kl.x + 0.38, 0.3, kl.z), stone)
	B.mesh(sbody, B.boxm(Vector3(0.95, 0.12, 0.9)), Vector3(kl.x, 0.66, kl.z), stone.darkened(0.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2811
	for k in 22:
		var r := rng.randf_range(0.09, 0.15)
		B.mesh(sbody, B.sphere(r, 8), Vector3(kl.x + rng.randf_range(-0.38, 0.38), 0.74 + r * 0.6 + (k / 9) * 0.07, kl.z + rng.randf_range(-0.36, 0.36)),
			Color(0.24, 0.23, 0.22).lerp(Color(0.42, 0.4, 0.38), rng.randf())).scale = Vector3(1.0, 0.75, 1.0)
	B.mesh(sbody, B.cyl(0.13, 0.1, 0.24, 10), Vector3(1.15, 0.65, -0.15), Color(0.55, 0.4, 0.25))
	B.mesh(sbody, B.boxm(Vector3(w - 0.1, 0.03, dd - 0.1)), Vector3(0, wall_h - 0.02, 0), Color(0.09, 0.08, 0.07))
	# Piippu katolla ja savu.
	B.mesh(sbody, B.cyl(0.17, 0.2, 1.4, 8), Vector3(0.9, wall_h + 0.75, -0.2), Color(0.3, 0.28, 0.27))
	var smoke := CPUParticles3D.new()
	smoke.position = sbody.position + Basis(Vector3.UP, yaw) * Vector3(0.9, wall_h + 1.5, -0.2)
	smoke.amount = 14
	smoke.lifetime = 3.2
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.9
	smoke.gravity = Vector3(0.25, 0.1, 0.0)
	smoke.scale_amount_min = 0.7
	smoke.scale_amount_max = 1.3
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.material = B.unshaded(Color(0.82, 0.82, 0.84, 0.5))
	smoke.mesh = sm
	add_child(smoke)
	# Kyltti saunan terassin päädyssä.
	var plate := B.sign_plate(sbody, "UITON SAUNA\nHirsisauna · uinti Oulujärveen", Color(0.2, 0.14, 0.09), Color(0.97, 0.9, 0.7), 0.3, 40, Color(0.8, 0.65, 0.3), "Georgia")
	plate.position = Vector3(0, wall_h + 0.42, fz + ter + 0.2)
	plate.rotation.x = deg_to_rad(-10.0)
	uitto_door = sbody.position + Basis(Vector3.UP, yaw) * Vector3(UITTO_DOOR_X + 0.4, 0, fz + ter + 1.3)
	uitto_door.y = h(uitto_door.x, uitto_door.z)
	doors.append({"id": "uittosauna", "pos": uitto_door, "out": Vector3(-d.x, 0, -d.y), "r": 6.0, "walk": true,
		"text": "Uiton saunan löylyt ja pulahdus Oulujärveen"})
	# --- Makasiini (entinen uiton venevaja, nykyään kanoottitalli) ja kanoottiteline ---
	var mc: Vector2 = at.call(-8.0, -9.0)
	var mk := Node3D.new()
	mk.position = Vector3(mc.x, gy, mc.y)
	mk.rotation.y = yaw
	add_child(mk)
	var mw := 8.0
	var md := 5.0
	var mh := 3.0
	var ochre := Color(0.52, 0.15, 0.1)
	B.box(mk, Vector3(mw, mh, md), Vector3(0, mh / 2.0, 0), ochre)
	for k in int(mw / 0.4):
		B.mesh(mk, B.boxm(Vector3(0.03, mh, 0.03)), Vector3(-mw / 2.0 + 0.2 + k * 0.4, mh / 2.0, md / 2.0 + 0.02), ochre.darkened(0.15))
	for sx in [-1.0, 1.0]:
		B.mesh(mk, B.boxm(Vector3(0.18, mh + 0.05, 0.18)), Vector3(sx * (mw / 2.0), mh / 2.0, md / 2.0), Color(0.92, 0.9, 0.84))
	var mroof := PrismMesh.new()
	mroof.size = Vector3(md + 0.8, 1.7, mw + 0.8)  # harja leveyssuunnassa (päätykolmio ei tielle), prisman harja on Z-akselilla
	B.mesh(mk, mroof, Vector3(0, mh + 0.85, 0), Color(0.22, 0.2, 0.19)).rotation.y = PI / 2.0
	B.mesh(mk, B.boxm(Vector3(3.0, 2.3, 0.08)), Vector3(0, 1.15, md / 2.0 + 0.05), Color(0.3, 0.2, 0.12))
	B.mesh(mk, B.boxm(Vector3(0.08, 2.3, 0.1)), Vector3(0, 1.15, md / 2.0 + 0.1), Color(0.14, 0.1, 0.07))
	B.mesh(mk, B.boxm(Vector3(3.2, 0.1, 0.12)), Vector3(0, 2.35, md / 2.0 + 0.1), Color(0.92, 0.9, 0.84))
	for sx in [-3.0, 3.0]:
		B.mesh(mk, B.boxm(Vector3(0.9, 0.7, 0.06)), Vector3(sx, 1.9, md / 2.0 + 0.04), Color(0.7, 0.78, 0.8))
	# Kanoottiteline makasiinin vieressä: kolme kajakkia telineellä.
	var rack := Node3D.new()
	var rc: Vector2 = at.call(-1.5, -9.0)
	rack.position = Vector3(rc.x, gy, rc.y)
	rack.rotation.y = yaw
	add_child(rack)
	for sx in [-1.8, 1.8]:
		B.mesh(rack, B.boxm(Vector3(0.1, 1.5, 0.1)), Vector3(sx, 0.75, 0), Color(0.4, 0.3, 0.2))
		B.mesh(rack, B.boxm(Vector3(0.1, 0.1, 1.6)), Vector3(sx, 0.8, 0), Color(0.4, 0.3, 0.2))
		B.mesh(rack, B.boxm(Vector3(0.1, 0.1, 1.6)), Vector3(sx, 1.4, 0), Color(0.4, 0.3, 0.2))
	var kcols := [Color(0.85, 0.2, 0.12), Color(0.95, 0.78, 0.15), Color(0.15, 0.45, 0.75)]
	for k in 3:
		var kz := -0.5 + k * 0.5
		var ky := 0.95 if k < 2 else 1.55
		var kx := -0.4 if k < 2 else 0.0
		var kc := B.mesh(rack, B.capsule(0.19, 3.8), Vector3(0, ky, kz if k < 2 else 0.0), kcols[k], Vector3(0, 0, 90))
		kc.scale = Vector3(1.0, 1.0, 0.8)
	# Tukkipino (uiton muisto) ja nuotiopaikka kivirenkaineen ja kantopenkkeineen.
	var lc: Vector2 = at.call(4.0, -13.5)
	var pile := Node3D.new()
	pile.position = Vector3(lc.x, gy, lc.y)
	pile.rotation.y = yaw
	add_child(pile)
	for row in 4:
		for k in 5 - row:
			B.mesh(pile, B.cyl(0.17, 0.17, 3.2, 8), Vector3((k - (4 - row) / 2.0) * 0.34, 0.17 + row * 0.3, 0), Color(0.55, 0.42, 0.28).darkened(0.06 * ((k + row) % 3)), Vector3(90, 0, 0))
	pile.add_child(B.box_shape(Vector3(1.9, 1.3, 3.2), Vector3(0, 0.65, 0)))
	var fc: Vector2 = at.call(-1.5, -13.5)
	var fire := Node3D.new()
	fire.position = Vector3(fc.x, gy, fc.y)
	fire.rotation.y = yaw
	add_child(fire)
	for k in 10:
		var a := TAU * k / 10.0
		B.mesh(fire, B.sphere(0.17, 8), Vector3(cos(a) * 0.62, 0.1, sin(a) * 0.62), Color(0.42, 0.4, 0.38).lerp(Color(0.3, 0.29, 0.28), (k % 3) / 3.0)).scale = Vector3(1.0, 0.7, 1.0)
	B.mesh(fire, B.cyl(0.55, 0.6, 0.04, 12), Vector3(0, 0.03, 0), Color(0.12, 0.1, 0.09))
	B.mesh(fire, B.cyl(0.07, 0.07, 0.8, 6), Vector3(0, 0.2, 0), Color(0.2, 0.13, 0.08), Vector3(0, 0, 70))
	B.mesh(fire, B.cyl(0.07, 0.07, 0.8, 6), Vector3(0, 0.2, 0), Color(0.2, 0.13, 0.08), Vector3(0, 90, 70))
	B.mesh(fire, B.sphere(0.26, 8), Vector3(0, 0.45, 0), Color(1.0, 0.55, 0.12)).scale = Vector3(0.8, 1.5, 0.8)
	for bx in [-1.7, 1.7]:
		B.mesh(fire, B.cyl(0.17, 0.17, 1.5, 8), Vector3(bx, 0.2, 0), Color(0.5, 0.38, 0.26), Vector3(90, 0, 0))
	print("VAALA uiton sauna ", sbody.global_position, " laituri ", uitto_pier_door)


# --- Lavan venelaituri (muskeliveneellä lavalle) --------------------------------------------------------------------

const LPIER_LEN := 16.0
var lava_boat: Node3D                  # lavan laiturissa odottava muskelivene (main.gd piilottaa ajon ajaksi)
var lava_boat_tf := Transform3D.IDENTITY
var lava_dock := Vector3.ZERO          # laiturin kärki kannen tasolla (kävelijän paikka veneestä noustessa)
var _lp_root := Vector2.ZERO           # laiturin juuri rannalla
var _lp_dir := Vector2.ZERO            # rannalta järvelle


## Laituri lavan pihan järvenpuoleiselle rannalle: lavan keskeltä lähin avovesi, jonne aidan linja ei kulje.
## Ovi "lavalaituri": E käynnistää veneajelun siitä (main.gd _start_boat_vaala).
func _build_lava_pier() -> void:
	var lv: Dictionary = data.get("lava", {})
	if lv.is_empty() or not data.has("satama"):
		return
	var c := Vector2(lv.x, lv.z)
	var fence: Array = lv.get("fence", [])
	var best := INF
	var bd := Vector2.ZERO
	var bs := Vector2.ZERO
	for k in 32:
		var d := Vector2.from_angle(TAU * k / 32)
		var shore := Vector2.INF
		var crosses := false
		for t in range(8, 90):
			var q := c + d * t
			for m in fence.size() - 1:
				if Geometry2D.segment_intersects_segment(c + d * (t - 1), q, Vector2(fence[m][0], fence[m][1]), Vector2(fence[m + 1][0], fence[m + 1][1])) != null:
					crosses = true
			if crosses:
				break
			if code_at(q.x, q.y) == WATER:
				shore = q - d * 1.5
				break
		if crosses or shore == Vector2.INF:
			continue
		var open := true
		for t in range(3, int(LPIER_LEN) + 8, 2):
			var q := shore + d * t
			if code_at(q.x, q.y) != WATER:
				open = false
		if open and shore.distance_to(c) < best:
			best = shore.distance_to(c)
			bd = d
			bs = shore
	if bd == Vector2.ZERO:
		return
	_lp_root = bs
	_lp_dir = bd
	var side := Vector2(bd.y, -bd.x)
	var dl := LPIER_LEN
	var wy := water_y(bs.x + bd.x * dl, bs.y + bd.y * dl)
	var dy := wy + SATAMA_DECK
	var yaw := atan2(bd.x, bd.y)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(bs.x, dy, bs.y))
	lava_dock = xf * Vector3(0, 0, dl)
	var door_pos: Vector3 = xf * Vector3(0, 0, 2.0)
	var wood := Color(0.6, 0.45, 0.3)
	var dark := Color(0.33, 0.24, 0.16)
	var dock := StaticBody3D.new()
	dock.set_meta("ground", true)
	dock.transform = xf
	add_child(dock)
	var pw := SATAMA_PIER_W
	var hd := SATAMA_HEAD
	B.mesh(dock, B.boxm(Vector3(pw, 0.1, dl)), Vector3(0, -0.05, dl / 2.0), wood)
	B.mesh(dock, B.boxm(Vector3(hd.x, 0.1, hd.y)), Vector3(0, -0.05, dl), wood)
	for k in int(dl / 0.8):
		B.mesh(dock, B.boxm(Vector3(pw, 0.012, 0.025)), Vector3(0, 0.002, 0.4 + k * 0.8), dark)
	for sx in [-1.0, 1.0]:
		B.mesh(dock, B.boxm(Vector3(0.14, 0.2, dl)), Vector3(sx * (pw / 2.0 - 0.07), -0.2, dl / 2.0), dark)
	B.mesh(dock, B.boxm(Vector3(hd.x, 0.2, 0.14)), Vector3(0, -0.2, dl + hd.y / 2.0 - 0.07), dark)
	dock.add_child(B.box_shape(Vector3(pw, 0.3, dl), Vector3(0, -0.15, dl / 2.0)))
	dock.add_child(B.box_shape(Vector3(hd.x, 0.3, hd.y), Vector3(0, -0.15, dl)))
	var rise := maxf(h(bs.x, bs.y) - dy, 0.0) + 0.06
	var run := maxf(1.4, rise * 2.2)
	var ramp := B.box_shape(Vector3(pw, 0.1, Vector2(run, rise).length()), Vector3.ZERO)
	ramp.transform = Transform3D(Basis(Vector3.RIGHT, atan2(rise, run)), Vector3(0, -0.05 + rise / 2.0, -run / 2.0))
	dock.add_child(ramp)
	B.mesh(dock, B.boxm(Vector3(pw, 0.08, Vector2(run, rise).length())), Vector3(0, -0.05 + rise / 2.0 - 0.03, -run / 2.0), wood.darkened(0.1)).rotation.x = atan2(rise, run)
	var piles: Array[Vector3] = []
	for k in int(dl / 2.4) + 1:
		for sx in [-1.0, 1.0]:
			piles.append(Vector3(sx * (pw / 2.0 - 0.1), 0, minf(1.6 + k * 2.4, dl)))
	for sx in [-1.0, 1.0]:
		piles.append(Vector3(sx * (hd.x / 2.0 - 0.15), 0, dl + hd.y / 2.0 - 0.15))
	for pl in piles:
		var gp := xf * pl
		var bottom := h(gp.x, gp.z)
		if bottom > dy - 0.4:
			continue
		var top := 0.3 if int(pl.z * 10.0) % 3 == 0 else -0.02
		var ph := top - (bottom - dy) + 0.1
		B.mesh(dock, B.cyl(0.1, 0.1, ph, 8), Vector3(pl.x, top - ph / 2.0, pl.z), Color(0.27, 0.2, 0.14))
	for k in 4:
		for sx in [-1.0, 1.0]:
			var bp := Vector3(sx * (pw / 2.0 - 0.18), 0.0, 3.0 + k * 3.2)
			B.mesh(dock, B.cyl(0.09, 0.11, 0.34, 10), bp + Vector3(0, 0.17, 0), Color(0.12, 0.2, 0.16))
			B.mesh(dock, B.cyl(0.13, 0.13, 0.06, 10), bp + Vector3(0, 0.36, 0), Color(0.16, 0.26, 0.2))
	B.mesh(dock, B.cyl(0.05, 0.06, 2.6, 8), Vector3(hd.x / 2.0 - 0.4, 1.3, dl + 0.2), Color(0.18, 0.18, 0.2))
	B.mesh(dock, B.boxm(Vector3(0.26, 0.3, 0.26)), Vector3(hd.x / 2.0 - 0.4, 2.7, dl + 0.2), Color(1.0, 0.92, 0.6))
	lava_boat_tf = xf * Transform3D(Basis(Vector3.UP, PI), Vector3(SATAMA_BOAT_X, wy - dy, dl - 4.9))
	lava_boat = Node3D.new()
	add_child(lava_boat)
	lava_boat.transform = lava_boat_tf
	Muskelivene.build(lava_boat)
	var sp := bs - bd * 4.0 + side * 3.6
	var plate := B.sign_plate(self, "OULUJÄRVEN LAVA\nVenelaituri", Color(0.1, 0.3, 0.5), Color(0.97, 0.97, 0.92), 0.34, 52, Color(0.95, 0.95, 0.9))
	var pwid: float = plate.get_meta("width")
	plate.position = Vector3(sp.x, h(sp.x, sp.y) + 2.3, sp.y)
	plate.rotation.y = yaw
	for sx in [-1.0, 1.0]:
		var pp: Vector2 = sp + side * sx * (pwid / 2.0 + 0.06)
		B.mesh(self, B.cyl(0.05, 0.06, 2.7, 8), Vector3(pp.x, h(pp.x, pp.y) + 1.35, pp.y), Color(0.3, 0.22, 0.15))
	doors.append({"id": "lavalaituri", "pos": door_pos, "out": Vector3(-bd.x, 0, -bd.y), "r": dl * 0.8, "walk": true,
		"text": "Muskeliveneellä Oulujärvelle"})


## Lavan laiturin suorakaiteet laiturin kehyksessä (x sivulle, y järvelle), veneen törmäyksiin.
func _lp_rects() -> Array:
	return [Rect2(-SATAMA_PIER_W / 2.0, -0.5, SATAMA_PIER_W, LPIER_LEN + 0.5),
		Rect2(-SATAMA_HEAD.x / 2.0, LPIER_LEN - SATAMA_HEAD.y / 2.0, SATAMA_HEAD.x, SATAMA_HEAD.y)]


## Rantakivetys: kiviä vesirajan kuivilla reunaruuduilla laiturin molemmin puolin (ei laiturin kohdalle).
func _sat_shore(d: Vector2, root: Vector2, wy: float, skip := []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7117
	var grey: Array[Transform3D] = []
	var warm: Array[Transform3D] = []
	var ci := int(roundf((root.x - _x0) / _cell))
	var cj := int(roundf((root.y - _z0) / _cell))
	var span := 14
	for j in range(cj - span, cj + span + 1):
		for i in range(ci - span, ci + span + 1):
			if i < 1 or j < 1 or i >= _nx - 1 or j >= _nz - 1 or _codes[j * _nx + i] == WATER:
				continue
			var toward := Vector2.ZERO
			for dj in [-1, 0, 1]:
				for di in [-1, 0, 1]:
					if _codes[(j + dj) * _nx + i + di] == WATER:
						toward += Vector2(di, dj)
			if toward == Vector2.ZERO:
				continue
			toward = toward.normalized()
			var c := Vector2(_x0 + i * _cell, _z0 + j * _cell)
			for n in 3:
				var p := c + toward * (_cell * 0.5 + rng.randf_range(-0.4, 1.2)) + Vector2(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8))
				var rel := p - root
				if skip.any(func(sk: Array) -> bool: return p.distance_to(sk[0]) < sk[1]):
					continue
				if absf(rel.dot(Vector2(d.y, -d.x))) < 2.6 and rel.dot(d) > -2.0 and rel.dot(d) < 20.0:
					continue
				var sc := rng.randf_range(0.35, 0.8)
				var y := maxf(h(p.x, p.y), wy) + 0.02
				var bs := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc * rng.randf_range(1.0, 1.5), sc * 0.55, sc * rng.randf_range(0.9, 1.3)))
				(grey if rng.randf() < 0.6 else warm).append(Transform3D(bs, Vector3(p.x, y, p.y)))
	_multimesh(B.sphere(1.0, 8), grey, Color(0.5, 0.5, 0.5))
	_multimesh(B.sphere(1.0, 8), warm, Color(0.43, 0.38, 0.33))


## Sataman asfalttiparkki (tasainen, tools/vaala_satama.py tasoittaa), auto ja pihan reunakivet.
func _sat_park(sd: Dictionary, d: Vector2, side: Vector2, yaw: float) -> void:
	var pc := Vector2(sd.park[0], sd.park[1])
	var pr := Vector2(sd.park_r[0], sd.park_r[1])
	var py := h(pc.x, pc.y)
	satama_park = Vector3(pc.x, py, pc.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var n := 24
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var p0 := pc + side * cos(a0) * pr.x * 0.97 + d * sin(a0) * pr.y * 0.97
		var p1 := pc + side * cos(a1) * pr.x * 0.97 + d * sin(a1) * pr.y * 0.97
		for p in [pc, p0, p1]:
			st.add_vertex(Vector3(p.x, py + 0.035, p.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _surf_mat("asphalt")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var car_p := pc + side * (pr.x * 0.62) - d * 1.0
	B.parked_car(self, Vector3(car_p.x, py, car_p.y), rad_to_deg(yaw) + 90.0, Color(0.22, 0.36, 0.5))
	# Pyöreitä reunakiviä parkin rannan puolella.
	for k in 7:
		var q := pc + side * (-pr.x * 0.9 + k * pr.x * 0.3) + d * pr.y * 1.02
		if wet(q.x, q.y, 0.3):
			continue
		B.mesh(self, B.sphere(0.28, 8), Vector3(q.x, h(q.x, q.y) + 0.05, q.y), Color(0.5, 0.5, 0.52)).scale = Vector3(1.2, 0.8, 1.0)


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
## Sivutien pinta ja puolileveys: [kind, half]. Piirto (_build_side_roads) ja ajoalue (_build_drive_mask_calc) käyttävät
## samaa, jotta mopo ajaa täsmälleen tien pinnalla. Asfaltti kuten Saloisten kaksikaistainen maantie (world.gd STYLES.road,
## leveys 8 m); sora kuten Keskimmäisentie ja Paapelin soratiet: 2,6 m (service 1,8 m).
func _side_style(r: Dictionary) -> Array:
	var hw: String = r.hw
	if r.kind == "rail":
		return ["rail", 1.6]
	if hw in ["footway", "cycleway", "path", "pedestrian", "steps"]:
		return ["path" if r.surface != "asphalt" else "asphalt", 1.3]
	if r.get("street", 0) == 1:  # kapea asfalttikatu kuten Saloisten "street" (world.gd STYLES): ei piennarta eikä keskiviivaa
		return ["street", STREET_HALF]
	if hw in ["secondary", "tertiary", "residential"] or r.surface in ["asphalt", "paved"]:
		return ["asphalt", ROAD_HALF]
	return ["gravel", 1.8 if hw == "service" else GRAVEL_HALF]


var _surf_mats := {}


func _st_empty(st: SurfaceTool) -> bool:
	var va = st.commit_to_arrays()[Mesh.ARRAY_VERTEX]  # tyhjällä SurfaceToolilla null
	return va == null or (va as PackedVector3Array).is_empty()


## Tienpintojen materiaalit kuten Saloisten SURFACES (world.gd); sora kuten Paapelin soratiet (mokki.gd).
func _surf_mat(kind: String) -> Material:
	if not _surf_mats.has(kind):
		_surf_mats[kind] = {
			"asphalt": func() -> Material: return _ground_mat(Color(0.17, 0.17, 0.18), Color(0.27, 0.27, 0.28), 0.05, 2.5, 0.25, 0.8),
			"shoulder": func() -> Material: return _ground_mat(Color(0.47, 0.46, 0.42), Color(0.56, 0.55, 0.5), 0.08, 1.1, 0.6, 1.0),
			"gravel": func() -> Material: return _ground_mat(Color(0.53, 0.47, 0.37), Color(0.64, 0.57, 0.45), 0.08, 1.1),
			"path": func() -> Material: return _ground_mat(Color(0.5, 0.45, 0.36), Color(0.6, 0.55, 0.45), 0.08, 1.1),
			"dash": func() -> Material: return B.mat(Color(0.9, 0.9, 0.84)),
			"rail": func() -> Material: return B.mat(Color(0.38, 0.35, 0.32)),
		}[kind].call()
	return _surf_mats[kind]


## Monikulmio (esim. parkki) maastoon sovitettuna pintana: kolmioitu ja leikattu maastoruudukolla kuten _ribbon.
func _poly_surface(st: SurfaceTool, poly: PackedVector2Array, lift: float) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	var out := PackedVector3Array()
	for t in range(0, idx.size() - 2, 3):
		_conform(Vector3(poly[idx[t]].x, 0, poly[idx[t]].y), Vector3(poly[idx[t + 1]].x, 0, poly[idx[t + 1]].y),
			Vector3(poly[idx[t + 2]].x, 0, poly[idx[t + 2]].y), out)
	st.set_normal(Vector3.UP)
	for v in out:
		st.add_vertex(Vector3(v.x, h(v.x, v.z) + lift, v.z))


const ROAD_HALF := 4.0  # asfaltin puolileveys (Saloisten road, 8 m)
const STREET_HALF := 2.75  # asfalttikadun puolileveys (Saloisten street, 5,5 m)
const GRAVEL_HALF := 2.6  # soratien puolileveys (Paapelin ja Keskimmäisentien sora)
const ROAD_SHOULDER := 1.2  # asfaltin piennar (Saloisten "shoulder") molemmin puolin
const LIFT_SHOULDER := 0.03
const LIFT_ASPHALT := 0.045
const LIFT_DASH := 0.06
const LIFT_GRAVEL := 0.04


func _build_side_roads() -> void:
	var sts := {}
	for kind in ["asphalt", "shoulder", "dash", "gravel", "path", "rail"]:
		sts[kind] = SurfaceTool.new()
		sts[kind].begin(Mesh.PRIMITIVE_TRIANGLES)
	var sleepers: Array[Transform3D] = []
	var rail_bridge: Array = []  # [a, b] kiskojen tasossa joen yli
	for r in data.side_roads:
		var pts: Array = r.pts
		if r.name == "Vaalan tori":
			continue  # kävelyalue, piirretään kivetyksenä (_build_tori)
		var style := _side_style(r)
		var kind: String = style[0]
		var half: float = style[1]
		if kind != "rail":
			var line := PackedVector2Array()
			for q in pts:
				line.append(Vector2(q[0], q[1]))
			match kind:
				"asphalt":
					_ribbon(sts.shoulder, line, half + ROAD_SHOULDER, LIFT_SHOULDER)
					_ribbon(sts.asphalt, line, half, LIFT_ASPHALT)
					_dashes(sts.dash, line, LIFT_DASH)
				"street":
					_ribbon(sts.asphalt, line, half, LIFT_ASPHALT)
				"gravel":
					_ribbon(sts.gravel, line, half, LIFT_GRAVEL)
				_:
					_ribbon(sts.path, line, half, LIFT_GRAVEL)
			continue
		var st: SurfaceTool = sts[kind]
		for j in pts.size() - 1:
			var a := Vector2(pts[j][0], pts[j][1])
			var b := Vector2(pts[j + 1][0], pts[j + 1][1])
			var n := (b - a).normalized().orthogonal() * half
			var lift := 0.05
			# Rata: leivottu korkeus (penger ja alikulun ratasilta), Oulujoen ratasillalla kiskot vähintään 3 m
			# vedenpinnan yläpuolella.
			var ya := h(a.x, a.y)
			var yb := h(b.x, b.y)
			if kind == "rail":
				ya = maxf(maxf(ya, pts[j][2] if pts[j].size() > 2 else ya), water_level + 3.0)
				yb = maxf(maxf(yb, pts[j + 1][2] if pts[j + 1].size() > 2 else yb), water_level + 3.0)
			var gy := func(p: Vector2) -> float:
				return lerpf(ya, yb, clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.01), 0.0, 1.0))
			var v := func(p: Vector2) -> Vector3: return Vector3(p.x, gy.call(p) + lift, p.y)
			_quad(st, v.call(a + n), v.call(b + n), v.call(b - n), v.call(a - n))
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
			var up2 = data.get("underpass2")
			var at_under: bool = (up != null and a.distance_to(Vector2(up.at[0], up.at[1])) < 60.0) \
				or (up2 != null and a.distance_to(Vector2(up2.at[0], up2.at[1])) < 60.0)
			# Joen yli (kiskot reilusti maan yläpuolella): teräsristikkosilta (_build_truss) koko jaksolle.
			if not at_under and minf(ya, yb) - maxf(h(a.x, a.y), h(b.x, b.y)) > 2.0:
				rail_bridge.append([Vector3(a.x, ya, a.y), Vector3(b.x, yb, b.y)])
	for kind in sts:
		var st: SurfaceTool = sts[kind]
		if _st_empty(st):
			continue
		if kind == "rail":
			st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _surf_mat(kind)
		if kind != "rail":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	if u != null:
		var i: int = u.i
		underpass_i = i
		var at := road_pos(i)
		at.y = float(u.road_y)
		var road_dist := func(q: Vector3) -> float:
			var best := INF
			for k in range(maxi(i - 40, 0), mini(i + 40, road.size() - 1)):
				var pa := road_pos(k)
				var pb := road_pos(k + 1)
				var c := Geometry2D.get_closest_point_to_segment(Vector2(q.x, q.z), Vector2(pa.x, pa.z), Vector2(pb.x, pb.z))
				best = minf(best, c.distance_to(Vector2(q.x, q.z)))
			return best
		_under_structure(u, at, road_dir(i), road_dist, DECK_W)
	# Satamantien alikulku (tools/vaala_alikulku.py): tie kulkee leikkauksessa asemaradan alla, kiskot kannen päällä.
	var u2 = data.get("underpass2")
	if u2 != null:
		var line := PackedVector2Array()
		for r in data.side_roads:
			if r.name == u2.road:
				for q in r.pts:
					line.append(Vector2(q[0], q[1]))
		var at2 := Vector3(u2.at[0], float(u2.road_y), u2.at[1])
		var fd2 := Vector3(u2.road_dir[0], 0, u2.road_dir[1]).normalized()
		var road_dist2 := func(q: Vector3) -> float:
			var best := INF
			for k in line.size() - 1:
				var c := Geometry2D.get_closest_point_to_segment(Vector2(q.x, q.z), line[k], line[k + 1])
				best = minf(best, c.distance_to(Vector2(q.x, q.z)))
			return best
		_under_structure(u2, at2, fd2, road_dist2, float(u2.deck_w))


## Alikulun rakenne: kansi radan suuntaan, reunapalkit ja kaiteet, pilaririvit tien molemmin puolin, maatuet ja kilvet.
## at = tien keskilinjan piste alikulun kohdalla (y = tien pinta), fd = tien suunta, deck_w = kannen leveys radan poikki.
func _under_structure(u: Dictionary, at: Vector3, fd: Vector3, road_dist: Callable, deck_w: float) -> void:
	var rd := Vector3(u.dir[0], 0, u.dir[1]).normalized()
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
	var slab := B.mesh(self, B.boxm(Vector3(deck_w - 0.6, 0.7, dl)), deck_c, under)
	slab.basis = basis
	# Reunapalkit: vaalea betoni kannen pinnan yläpuolelle, alareuna laatan alle.
	for e: float in [-1.0, 1.0]:
		var em := B.mesh(self, B.boxm(Vector3(0.36, 1.25, dl)), deck_c + basis.x * e * (deck_w / 2.0 - 0.18) + Vector3(0, 0.12, 0), conc)
		em.basis = basis
		# Kaide: tolpat 1,6 m välein, käsijohde ja välijohde.
		var gp := deck_c + basis.x * e * (deck_w / 2.0 - 0.18) + Vector3(0, 0.75, 0)
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
	var cols_x: Array[float] = [-(deck_w / 2.0 - 1.0), deck_w / 2.0 - 1.0]
	if deck_w > 9.0:
		cols_x = [-(deck_w / 2.0 - 1.0), 0.0, deck_w / 2.0 - 1.0]
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
		var bm := B.mesh(self, B.boxm(Vector3(deck_w - 0.4, 0.6, 1.1)), Vector3(row.x, deck - 1.15, row.z), conc)
		bm.basis = basis
	# Maatuet kannen päissä luiskan päällä (osin maan sisällä).
	for s: float in [-1.0, 1.0]:
		var ab := Vector3(at.x, deck - 1.5, at.z) + basis.z * s * (dl / 2.0 - 0.7)
		var am := B.mesh(self, B.boxm(Vector3(deck_w + 0.6, 2.2, 1.4)), ab, conc.darkened(0.08))
		am.basis = basis
	# Alikulkukorkeus kannen reunaan molempiin ajosuuntiin.
	for s: float in [-1.0, 1.0]:
		var plate := B.sign_plate(self, "4,6 m", Color(0.98, 0.98, 0.95), Color(0.05, 0.05, 0.05), 0.4, 60, Color(0.85, 0.1, 0.08), "Helvetica Neue")
		plate.position = at - fd * s * (deck_w / 2.0 / sin_a + 0.1) + Vector3(0, H - 1.05, 0)
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
var _shop_frames: Array[Transform3D] = []
var _garage_doors: Array[Transform3D] = []


func _build_buildings() -> void:
	_walls = SurfaceTool.new()
	_walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	_walls.set_uv(Vector2.ZERO)  # UV = (sokkelin korkeus, kerroskorkeus) julkisivun vyöhykkeille (facade.gdshader)
	var path_grid := _side_road_grid()
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
		if bd.kind == "shed" and _on_side_road(pts, path_grid):
			continue  # OSM:n vaja polun tai pihatien päällä (kartat eivät täsmää): tie jää ajettavaksi

		# Isot laatikot pienemmiksi: laajat yksiväriset seinät näyttävät pelin mittakaavassa autioilta.
		if not id in [HOTEL_ID, GASTHAUS_ID, TYOKKARI_ID] and not str(bd.name).contains("kirkko"):
			var area0 := absf(_poly_area(pts))
			if area0 > BIG_AREA:
				var f := clampf(pow(BIG_AREA / area0, 0.25), 0.72, 1.0)
				var cc := cen / pts.size()
				for k in pts.size():
					pts[k] = cc + (pts[k] - cc) * f
		# Tie tai polku kulkee pohjan läpi tai aivan seinän vierestä (aineistot eivät täsmää): rakennusta kutistetaan,
		# kunnes tielle jää tilaa, tai se jätetään pois.
		if not id in [HOTEL_ID, GASTHAUS_ID, TYOKKARI_ID] and not str(bd.name).contains("Market"):
			var cc2 := Vector2.ZERO
			for q in pts:
				cc2 += q
			cc2 /= pts.size()
			var fit := false
			for f2: float in [1.0, 0.9, 0.8, 0.7]:
				var test := PackedVector2Array()
				for q in pts:
					test.append(cc2 + (q - cc2) * f2)
				var grown := Geometry2D.offset_polygon(test, 1.8)
				if grown.is_empty() or not _crossed_by_road(grown[0], path_grid):
					pts = test
					fit = true
					break
			if not fit:
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
			wall_h = 6.2  # kaksi kerrosta (3,1 m kukin)
			flat = false
		elif id == GASTHAUS_ID:
			col = Color(0.93, 0.84, 0.6)  # keltainen rappaus, valkoiset nurkat kuin vanhassa majatalossa
			mat = PLASTER
		if flat and wall_h > 9.0 and not id in [HOTEL_ID, GASTHAUS_ID]:
			levels = mini(maxi(levels, 1), 3)
			wall_h = minf(wall_h, 2.9 * maxi(levels, 2) + 0.6)  # matalammiksi: Vaalan liikerakennukset ovat 1-3-kerroksisia
		var top := base + wall_h + 0.3
		_prism(pts, base, top, col, mat, wall_h / maxi(levels, 1) if kind != "shed" else 0.0)
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
		if kind == "shed" and area > 70.0:
			# Iso varasto tai halli: rivi ikkunoita ja nosto-ovi tien puolelle (muuten laaja umpiseinä).
			var pd := _door(obb, base + 0.3)
			var gay: Vector2 = obb.ay
			var gout := gay if gay.dot(pd - (obb.center as Vector2)) > 0.0 else -gay
			var gd: Vector2 = pd - (obb.ax as Vector2) * (obb.size as Vector2).x * 0.36  # nosto-ovi keskeltä toiselle puolelle
			_windows(pts, base + 0.3, 1, wall_h, false, gd, Vector2(1.1, 0.8), 2.6, pd)
			var gs := minf(1.0, (wall_h - 0.2) / 3.0)
			_garage_doors.append(Transform3D(Basis(Vector3.UP, atan2(gout.x, gout.y)) * Basis.from_scale(Vector3(1.0, gs, 1.0)),
				Vector3(gd.x, base + 0.3, gd.y) + Vector3(gout.x, 0, gout.y) * 0.05))
		if kind != "shed":
			var shop := type in ["retail", "commercial"] or name.contains("market") or name.contains("Market")
			var door := _hotel_door_q(obb, base + 0.3) if id == HOTEL_ID else (_door(obb, base + 0.3) if id != GASTHAUS_ID else \
				(obb.center as Vector2) + _gasthaus_side(obb) * ((obb.size as Vector2).y / 2.0 + 0.05))
			if (kind == "house" or type in ["terrace", "house", "detached", "residential"]) and not id in [HOTEL_ID, GASTHAUS_ID] \
					and not shop and not church and not station:
				var hay: Vector2 = obb.ay
				var hout := hay if hay.dot(door - (obb.center as Vector2)) > 0.0 else -hay
				house_doors.append({"pos": Vector3(door.x, h(door.x, door.y), door.y), "out": Vector3(hout.x, 0, hout.y), "type": type,
					"len": maxf((obb.size as Vector2).x, (obb.size as Vector2).y), "id": id})
			_windows(pts, base + 0.3, maxi(levels, 1) if id != HOTEL_ID else 2, wall_h, shop, door,
				Vector2(1.25, 1.2) if not flat else Vector2(1.5, 1.3))
			if type == "apartments":
				_balcony_rows(pts, base + 0.3, levels, obb)
		_bld_polys.append(pts)
		if area > 0.96 * obb.size.x * obb.size.y:  # suorakaide: yksi laatikko (muuten laatikko ulottuisi pohjan yli)
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
			# Hotellin ovi pysäköinnin puoleisessa päädyssä kuten ravintolan: vastaanotto ja huone 12, jossa Dingo
			# riehuu (main.gd "hotelli"). Kyltit _hotel_signs.
			var hd := _hotel_door_q(obb, base + 0.3, false)
			var hout := (hd - (obb.center as Vector2)).normalized()
			hotel_door = Vector3(hd.x, h(hd.x, hd.y), hd.y) + Vector3(hout.x, 0, hout.y) * 2.5
			_hotel_signs(obb, base, top, hd, hout)
			doors.append({"id": "hotelli", "pos": hotel_door, "out": Vector3(hout.x, 0, hout.y), "r": 4.0, "walk": true,
				"hint": "Hotelli Siitarin vastaanottoon"})
		if id == TYOKKARI_ID:
			name = "TYÖVOIMATOIMISTO"
			var td := _door(obb, base + 0.3)
			var tay: Vector2 = obb.ay
			var tout := tay if tay.dot(td - (obb.center as Vector2)) > 0.0 else -tay  # seinän normaali ulos
			tyokkari_door = Vector3(td.x, h(td.x, td.y), td.y)
			_build_tyokkari_queue(td, tout)
			doors.append({"id": "tyokkari", "pos": tyokkari_door + Vector3(tout.x, 0, tout.y) * 2.5,
				"out": Vector3(tout.x, 0, tout.y), "r": 6.0, "walk": true, "hint": "jonoon",
				"text": "Työvoimatoimiston jono: juttele"})
		elif name == "" and type in ["retail", "commercial"] and kind != "shed":
			var lap := B.sign_plate(self, LAMA_SIGNS[hsh % LAMA_SIGNS.size()], Color(0.97, 0.96, 0.92), Color(0.75, 0.08, 0.06),
				0.3, 40, Color(0.97, 0.96, 0.92))
			lap.position.y = base + 1.6
			_face_road(lap, obb)
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
	_hotel_yard()
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
	var shop_glass := StandardMaterial3D.new()
	shop_glass.albedo_color = Color(0.22, 0.32, 0.4)
	shop_glass.metallic = 0.5
	shop_glass.roughness = 0.05
	_multimesh(B.boxm(Vector3(3.1, 2.6, 0.05)), _shop_frames, Color(0.85, 0.86, 0.85))  # karmit ja välipuitteet
	_multimesh_mat(B.boxm(Vector3(2.7, 2.2, 0.07)), _shop_glass, shop_glass)
	_multimesh(_garage_door_mesh(), _garage_doors)
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


## Hallin nosto-ovi: valkoinen karmi, vaakalamellit ja tumma alalista.
func _garage_door_mesh() -> ArrayMesh:
	var parts := [[B.boxm(Vector3(3.4, 3.0, 0.08)), Vector3(0, 1.5, 0), Color(0.9, 0.9, 0.88)]]
	for k in 6:
		parts.append([B.boxm(Vector3(3.0, 0.42, 0.1)), Vector3(0, 0.27 + k * 0.45, 0.02), Color(0.62, 0.64, 0.66).lightened(0.04 * (k % 2))])
	parts.append([B.boxm(Vector3(3.0, 0.06, 0.12)), Vector3(0, 0.05, 0.03), Color(0.15, 0.15, 0.15)])
	return _parts_mesh(parts)


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
## Työvoimatoimiston jono oven edestä ulospäin: kuusi ihmistä tuulitakeissa ja verkkareissa odottaa, osa tupakalla.
func _build_tyokkari_queue(door: Vector2, out: Vector2) -> void:
	var side := Vector2(-out.y, out.x)
	var looks := [
		{"shirt": Color(0.3, 0.35, 0.3), "pants": Color(0.2, 0.22, 0.3), "hair": "Hair_Buzzed", "hair_color": Color(0.4, 0.35, 0.3),
			"height": 1.78, "belly": 0.3},
		{"model": "female", "shirt": Color(0.6, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "hair": "Hair_Long",
			"hair_color": Color(0.35, 0.25, 0.15), "height": 1.64},
		{"shirt": Color(0.15, 0.2, 0.45), "pants": Color(0.25, 0.25, 0.28), "hair": "Hair_SimpleParted",
			"hair_color": Color(0.15, 0.12, 0.1), "height": 1.82, "tracksuit": {"a": Color(0.15, 0.2, 0.55), "b": Color(0.9, 0.9, 0.9)}},
		{"shirt": Color(0.5, 0.45, 0.35), "pants": Color(0.3, 0.28, 0.22), "hair": "Hair_Buzzed", "beard": true, "hair_color": Color(0.55, 0.5, 0.45),
			"height": 1.72, "belly": 0.5},
		{"model": "female", "shirt": Color(0.75, 0.7, 0.55), "pants": Color(0.2, 0.25, 0.4), "hair": "Hair_Buns",
			"hair_color": Color(0.6, 0.58, 0.55), "height": 1.6, "belly": 0.2},
		{"shirt": Color(0.12, 0.12, 0.14), "pants": Color(0.3, 0.35, 0.5), "hair": "Hair_Buzzed", "hair_color": Color(0.8, 0.7, 0.45),
			"height": 1.76, "bulk": -0.5},
	]
	var anims := ["Idle", "Idle_Talking", "Idle", "Idle", "Idle_Talking", "Idle"]
	for i in looks.size():
		var q := door + out * (1.6 + i * 0.95) + side * (0.25 if i % 2 == 0 else -0.2)
		var ch := Looks.make(self, looks[i])
		ch.position = Vector3(q.x, h(q.x, q.y), q.y)
		ch.rotation.y = B.yaw_to(Vector3(-out.x, 0, -out.y)) + (0.6 if anims[i] == "Idle_Talking" else 0.0)  # kohti ovea, juttelijat sivuttain
		ch.play(anims[i], 0.0)
		if i == 2:
			Looks.add_cap(ch)
	# Ilmoitustaulu oven vieressä: tyhjä paikkalista.
	var board := B.sign_plate(self, "AVOIMET TYÖPAIKAT\n–", Color(0.95, 0.95, 0.9), Color(0.1, 0.1, 0.12), 0.35, 36,
		Color(0.4, 0.3, 0.2))
	var bp := door + side * 2.2 + out * 0.1
	board.position = Vector3(bp.x, h(bp.x, bp.y) + 1.5, bp.y)
	board.rotation.y = atan2(out.x, out.y)


## Gasthaus (OSM 534430535, huone yöksi kympillä, main.gd "gasthaus") on Siitaria vastapäätä tien toisella
## puolella ja Zabuki (baaritiski luukulla, olutta ja hampurilaisia, main.gd "zabuki") sen vieressä, molemmat
## julkisivu tielle. Tori ("Vaalan tori") on niiden takana, ja sinne vie asfalttitie Zabukin vierestä
## (tools/vaala_keskusta.py; paikat ja julkisivut tie.json:n "keskusta"-osassa). Tori kivetään ja sille tulee kojuja.
const GASTHAUS_ID := 534430535
## Lama (#58): työvoimatoimisto Siitarin lounaispuolella (OSM:n nimetön liikerakennus) jonoineen, ja muiden nimettömien
## liikerakennusten ikkunoissa lopettaneiden liikkeiden laput (main.gd: ovi "tyokkari").
const TYOKKARI_ID := 1555230428
const LAMA_SIGNS := ["LIIKE LOPETTAA\nKAIKKI -50 %", "LOPPUUNMYYNTI", "TILA VUOKRATTAVANA\npuh. 981-23 112", "SULJETTU\nKonkurssipesä"]
var tyokkari_door := Vector3.ZERO
var hotel_door := Vector3.ZERO  # Hotelli Siitarin oven edusta


## Hotelli Siitari omana rakennuksenaan suoraan ravintolan takana (OSM:n hotellisiipi on kauempana): sama suunta
## kuin ravintolalla, 5 m väli takaseinään, pituus 0,75 ravintolan pituudesta ja syvyys 10,5 m. grow kasvattaa
## pohjaa (hotellin alle jäävät OSM-talot jätetään pois).
func _hotel_pts(grow := 0.0) -> PackedVector2Array:
	var so := _siitari_obb()
	if so.is_empty():
		return PackedVector2Array()
	var front: Vector2 = so.front
	var ax: Vector2 = so.ax
	var depth := 10.5
	var c: Vector2 = (so.center as Vector2) - front * ((so.size as Vector2).y / 2.0 + 5.0 + depth / 2.0)
	var hx: float = (so.size as Vector2).x * 0.75 / 2.0 + grow
	var hy := depth / 2.0 + grow
	return PackedVector2Array([c - ax * hx - front * hy, c + ax * hx - front * hy, c + ax * hx + front * hy, c - ax * hx + front * hy])


## Ravintolan pohja (_build_siitari): keskipiste, koko, akselit ja front = tien puoleinen pitkä sivu.
var _siitari_obb_cache := {}


func _siitari_obb() -> Dictionary:
	if _siitari_obb_cache.is_empty():
		for bd in data.buildings:
			if bd.id == SIITARI_ID:
				var sp := PackedVector2Array()
				for q in bd.pts:
					sp.append(Vector2(q[0], q[1]))
				var obb := _obb(sp)
				var rp := road_pos(nearest(Vector3(obb.center.x, 0, obb.center.y))[0])
				var ay: Vector2 = obb.ay
				obb.front = ay if ay.dot(Vector2(rp.x, rp.z) - (obb.center as Vector2)) > 0.0 else -ay
				_siitari_obb_cache = obb
	return _siitari_obb_cache


## Hotellin ovi ravintolan vastakkaiseen (-ax) päätyyn: sisällä (siitari_interior.gd) vastaanotto ja ulko-ovi ovat
## vasemmassa päädyssä, ja ulkoa tiehen päin katsoen -ax on vasen (ravintolan ovi on +ax-päädyssä, oikealla).
func _hotel_door_q(obb: Dictionary, y0: float, mesh := true) -> Vector2:
	var ax: Vector2 = obb.ax
	var side := -ax if ax.dot(_siitari_obb().ax) > 0.0 else ax
	var q: Vector2 = (obb.center as Vector2) + side * ((obb.size as Vector2).x / 2.0 + 0.05)
	if mesh:
		var y := h(q.x, q.y) + 0.1
		_doors.append(Transform3D(Basis(Vector3.UP, atan2(side.x, side.y)), Vector3(q.x, maxf(y, y0 - 0.1), q.y)))
	return q


## HOTELLI SIITARI valomainoksena katon harjalle (näkyy tielle ravintolan katon yli) ja vastaanoton kyltti oven
## yläpuolelle.
func _hotel_signs(obb: Dictionary, base: float, top: float, door: Vector2, out: Vector2) -> void:
	var to_bar: Vector2 = _siitari_obb().front
	# Valomainos harjalla tolppien päällä (harja _gable: nousu 0,32 x syvyys, enintään 3,2 m).
	var ridge := top + clampf((obb.size as Vector2).y * 0.32, 0.8, 3.2)
	var big := B.sign_plate(self, "HOTELLI SIITARI", Color(0.55, 0.05, 0.06), Color(1.0, 0.92, 0.6), 2.0, 120,
		Color(0.3, 0.02, 0.03), "Helvetica Neue")
	var bq: Vector2 = (obb.center as Vector2) + to_bar * 0.3
	big.position = Vector3(bq.x, ridge + 1.3, bq.y)
	big.rotation.y = atan2(to_bar.x, to_bar.y)
	var ax: Vector2 = obb.ax
	for k in [-4.5, 4.5]:
		var pq: Vector2 = bq + ax * k - to_bar * 0.15
		B.mesh(self, B.cyl(0.08, 0.08, 1.4, 8), Vector3(pq.x, ridge + 0.1, pq.y), Color(0.2, 0.2, 0.22))
	var small := B.sign_plate(self, "HOTELLI SIITARI\nVASTAANOTTO", Color(0.12, 0.1, 0.08), Color(0.98, 0.95, 0.85), 0.55, 48,
		Color(0.55, 0.05, 0.06), "Helvetica Neue")
	small.position = Vector3(door.x, base + 2.95, door.y) + Vector3(out.x, 0, out.y) * 0.12  # oven ja ikkunan väliin
	small.rotation.y = atan2(out.x, out.y)


## Hotellin piha: puut pois pohjan ympäriltä ja ravintolan parkkipaikalta hotellin ovelle, ja väliin asfalttipolku
## (kutsutaan rakennusten jälkeen, kun siitari_park ja hotel_door tunnetaan).
func _hotel_yard() -> void:
	if hotel_door == Vector3.ZERO or siitari_park == Vector3.ZERO:
		return
	var a := Vector2(siitari_park.x, siitari_park.z)
	var b := Vector2(hotel_door.x, hotel_door.z)
	if not _tree_clear.is_empty():
		var keep := _drive
		_drive = _tree_clear  # piirtoapurit kirjoittavat _driveen
		_drive_poly(_hotel_pts(), 4.0)
		_drive_seg(a, b, 4.0)
		_tree_clear = _drive
		_drive = keep
	# Polku 2 m paloina maaston mukaan (pitkä laatta kelluisi rinteessä).
	var d := b - a
	var n := maxi(1, ceili(d.length() / 2.0))
	var yaw := rad_to_deg(atan2(d.x, d.y))
	for k in n:
		var q := a + d * ((k + 0.5) / n)
		B.mesh(self, B.boxm(Vector3(2.2, 0.1, d.length() / n + 0.05)), Vector3(q.x, h(q.x, q.y) + 0.03, q.y),
			Color(0.3, 0.3, 0.32), Vector3(0, yaw, 0))


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
var station_back := Vector3.ZERO  # odotussalin laiturin puoleisen oven edusta
var station_board := Vector3.ZERO  # laiturilla junaan nousun kohta
var cache_pos := Vector3.INF  # narkkarin rahakätkö radan varressa (odotussalin juopot kertovat paikan)
var veturitalli_banner: Node3D = null
var veturitalli_door := Vector3.ZERO
var station_id: int = -1  # keskusta.asema.id: tämän rakennuksen paikalle asema (yleinen piirto ohittaa)


func _build_roundabout(rb: Dictionary) -> void:
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
	rm.material_override = _surf_mat("asphalt")
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


func _build_station() -> void:
	var st = data.get("keskusta", {}).get("asema")
	if st == null:
		return
	# Liikenneympyrä (r = 0: tavallinen risteys, ei piirrettävää).
	var rb: Dictionary = st.roundabout
	if float(rb.r) > 0.0:
		_build_roundabout(rb)
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
	var sdoors: Dictionary = StationBuild.build(root, L, D, 4.0, "Vaala", 0.0, 0.0)
	var white := Color(0.95, 0.94, 0.9)
	var dp := Vector2(st.door[0], st.door[1])
	var dout := Vector3(st.out[0], 0, st.out[1])
	station_door = Vector3(dp.x, h(dp.x, dp.y), dp.y) + dout * 2.2
	doors.append({"id": "asema", "pos": station_door, "out": dout, "hint": "asemalle (odotussali)"})
	_build_veturitalli(c, along, -back, L, D)
	station_back = root.transform * (sdoors.plat_door as Vector3)
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
	# Junaan noustaan laiturilta: kohta aseman takaoven kohdalla laiturin keskiviivalla (main.gd päivittää tekstin).
	var pax := proot.basis.x
	var u := clampf(Vector2(station_back.x - pc.x, station_back.z - pc.y).dot(Vector2(pax.x, pax.z)), -PL / 2.0 + 3.0, PL / 2.0 - 3.0)
	var bp := Vector2(pc.x, pc.y) + Vector2(pax.x, pax.z) * u
	station_board = Vector3(bp.x, h(bp.x, bp.y) + 0.3, bp.y)
	doors.append({"id": "laituri", "pos": station_board, "out": -dout, "r": 7.0, "walk": true, "hint": "laiturille", "text": "Odota junaa Saloisiin"})
	# Narkkarin rahakätkö ratapölkkypinon alla radan varressa, kuivalla maalla (main.gd piilottaa oven, kunnes paikka
	# on kuultu odotussalissa).
	if train != null:
		cache_pos = StationBuild.pick_cache(train, station_t, func(q: Vector3) -> bool:
			return not wet(q.x, q.z, 1.5) and h(q.x, q.z) > water_level + 1.0 and Vector2(q.x - c.x, q.z - c.y).length() > 25.0 \
				and not _near_rail(Vector2(q.x, q.z), 4.0))
		if st.has("katko"):  # kätkö on tie.json:ssa (Kätkötie vie sinne; vaala_sahanranta.py)
			cache_pos = Vector3(st.katko[0], 0.0, st.katko[1])
		if cache_pos != Vector3.INF:
			cache_pos.y = h(cache_pos.x, cache_pos.z)
			var cd: Vector3 = train.dir_t(train.nearest_t(cache_pos))
			StationBuild.cache_prop(self, cache_pos, atan2(cd.x, cd.z))
			doors.append({"id": "katko", "pos": cache_pos, "out": Vector3.FORWARD, "r": 3.0, "walk": true, "hint": "kätkölle",
				"text": "Kaiva narkkarin rahakätkö ratapölkkyjen alta"})
	_build_makasiini(root, L, Vector2(c.x, c.y))
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


var makasiini_door := Vector3.ZERO  # rasvanappimakasiinin takaoven edusta (main.gd: ovi "makasiini")
var makasiini_root: Node3D
var klaffi_prop: Node3D  # taitettava klaffipöytä Zabukin takana (piiloon, kun poimittu)
var apteekki_back: Node3D  # apteekin takaovi (main.gd _taka_hatch liikuttaa luukkua)


## Rasvanappimakasiini (makasiini.gd) aseman viereen kuten Saloisissa: aseman kehyksessä (X radan suuntaan, -Z
## laiturille) radan suuntaan aseman päätyjen ohi, ensimmäiseen kuivaan ja tasaiseen kohtaan, jossa ei ole
## rakennuksia, teitä, raiteita eikä rahakätköä. Pihan puut raivataan ja pohja jää ajoalueen ulkopuolelle.
func _build_makasiini(station: Node3D, station_l: float, c: Vector2) -> void:
	var fp := Makasiini.FOOTPRINT
	var best := Transform3D()
	var best_base := INF
	if _memo.has("makasiini"):
		best = _memo.makasiini[0]
		best_base = _memo.makasiini[1]
	for gap in ([] if best_base != INF else [6.0, 10.0, 15.0, 22.0, 30.0, 40.0]):
		for side in [-1.0, 1.0]:
			for dz in [0.0, 3.0, 6.0, -3.0]:
				var x: float = side * (station_l / 2.0 + gap + Makasiini.L / 2.0 + 1.0)
				var xf := Transform3D(station.basis, Vector3(c.x, 0, c.y) + station.basis * Vector3(x, 0, dz))
				var lo := INF
				var hi := -INF
				var ok := true
				for i in 9:
					for j in 6:
						var q := xf * Vector3(fp.position.x + fp.size.x * i / 8.0, 0, fp.position.y + fp.size.y * j / 5.0)
						var p := Vector2(q.x, q.z)
						var near_road: Array = nearest(q)
						if wet(q.x, q.z, 1.5) or _near_rail(p, 4.5) or _in_building(p, 2.0) or _near_side_road(p, 3.0) \
								or (near_road[0] >= 0 and near_road[1] < float(road[near_road[0]][4]) + 3.0) \
								or (cache_pos != Vector3.INF and p.distance_to(Vector2(cache_pos.x, cache_pos.z)) < 6.0):
							ok = false
							break
						var y := h(q.x, q.z)
						lo = minf(lo, y)
						hi = maxf(hi, y)
					if not ok:
						break
				if ok and hi - lo < 1.0:
					best = xf
					best_base = lo
					break
			if best_base != INF:
				break
		if best_base != INF:
			break
	if best_base == INF:
		push_warning("Vaalan makasiinille ei löytynyt paikkaa aseman vierestä")
		return
	_memo.makasiini = [best, best_base]
	var root := Node3D.new()
	root.transform = Transform3D(best.basis, Vector3(best.origin.x, best_base + 0.05, best.origin.z))
	add_child(root)
	Makasiini.build(root)
	makasiini_root = root
	makasiini_door = root.transform * Makasiini.DOOR
	makasiini_door.y = h(makasiini_door.x, makasiini_door.z)
	doors.append({"id": "makasiini", "pos": makasiini_door, "out": -root.basis.x, "r": 2.2, "walk": true,
		"hint": "makasiinin takaovelle", "text": "Koputa takaoveen (punainen lamppu palaa)"})
	# Pohja ajoalueen ulkopuolelle (_clear_buildings) ja puut pois ympäriltä (raivaus tehty jo _plan_northissa).
	var poly := PackedVector2Array()
	for k in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var q := root.transform * Vector3(-Makasiini.L / 2.0 - 0.1 + k.x * (Makasiini.L + 0.2), 0, -Makasiini.D / 2.0 - 0.1 + k.y * (Makasiini.D + 0.2))
		poly.append(Vector2(q.x, q.z))
	_bld_polys.append(poly)
	if not _tree_clear.is_empty():
		var yard := PackedVector2Array()
		for k in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var q := root.transform * Vector3(fp.position.x + k.x * fp.size.x, 0, fp.position.y + k.y * fp.size.y)
			yard.append(Vector2(q.x, q.z))
		var keep := _drive
		_drive = _tree_clear  # piirtoapurit kirjoittavat _driveen
		_drive_poly(yard, 4.0)
		_tree_clear = _drive
		_drive = keep


## Vaalan poliisiasema Oulujoen sillan keskustan puoleisessa päässä, Vaalasta lähtiessä tien oikealla puolella:
## 70-luvun yksikerroksinen tiilitalo tasakatolla, nauhaikkunat, lasiovi katoksineen ja sininen POLIISI-kyltti,
## nimikyltti, lipputanko ja poliisiauto pihassa. Kohta haetaan vähintään POLIISI_FROM_BRIDGE metrin päästä sillan
## päästä keskustaan päin (heti sillan päässä oikealla lähtee tie narkkitaloille) ensimmäisestä vapaasta paikasta
## (ei OSM-taloa, sivutietä, rataa eikä vettä). Vastapäätä penkillä makaa Janttu (janttu.gd).
const POLIISI_SIZE := Vector2(16.0, 9.0)  # pituus tien suuntaan, syvyys
const POLIISI_YARD := 7.0  # piha tien reunasta julkisivuun
const POLIISI_FROM_BRIDGE := 100.0  # vähintään näin pitkä matka (m) sillan päästä tietä pitkin
var poliisi_front := Vector3.INF  # pääoven edusta
## Roivaisen paikat (main.gd _poliisi_*): pihalla auton vieressä ja tutkan kanssa tien reunassa; out = kohti tietä.
var poliisi_yard := Vector3.INF
var poliisi_roadside := Vector3.INF
var poliisi_out := Vector3.ZERO
var janttu: Node3D


func _build_poliisi() -> void:
	if data.bridges.size() < 2:
		return
	var i_end := int(data.bridges[1][1])
	var hl := POLIISI_SIZE.x / 2.0
	var hd := POLIISI_SIZE.y / 2.0
	var along := 0.0
	for i in range(i_end + 1, road.size() - 2):
		along += Vector2(road[i][0] - road[i - 1][0], road[i][2] - road[i - 1][2]).length()
		if along < POLIISI_FROM_BRIDGE:
			continue
		if along > POLIISI_FROM_BRIDGE + 250.0:
			break
		var p := road_pos(i)
		var n := road_dir(i).cross(Vector3.UP)
		var side := Vector2(-n.x, -n.z)  # Vaalasta pois ajettaessa (näytteet laskevat) oikea puoli
		var ax := Vector2(road_dir(i).x, road_dir(i).z)
		var hw: float = road[i][4]
		var c := Vector2(p.x, p.z) + side * (hw + POLIISI_YARD + hd)
		var ok := true
		for u in [-hl - 1.0, 0.0, hl + 1.0]:
			for v in [-hd - POLIISI_YARD + 1.5, 0.0, hd + 1.0]:
				var q: Vector2 = c + ax * u + side * v
				if _in_building(q, 1.5) or _near_side_road(q, 4.0) or _near_rail(q, 6.0) or wet(q.x, q.y):
					ok = false
		if not ok:
			continue
		var jp := _janttu_spot(Vector2(p.x, p.z), -side, ax, hw)
		_poliisi_building(c, -side, ax)
		janttu = Janttu.new()
		janttu.position = Vector3(jp.x, h(jp.x, jp.y), jp.y)
		janttu.rotation.y = B.yaw_to(Vector3(side.x, 0, side.y))  # penkin etupuoli tielle ja asemalle päin
		add_child(janttu)
		print("VAALA poliisiasema näytteen %d kohdalla (%.0f m sillalta)" % [i, along])
		return
	push_warning("Vaalan poliisiasemalle ei löytynyt paikkaa sillan päästä")


## Jantun penkki tien toisella puolella nurmella tien vieressä aseman kohdalla (ei talon, sivutien eikä parkkipaikan päällä).
func _janttu_spot(r: Vector2, out: Vector2, ax: Vector2, hw: float) -> Vector2:
	for du in [0.0, 3.0, -3.0, 6.0, -6.0, 9.0, -9.0, 12.0, -12.0]:
		for dv in [3.2, 4.5, 6.0]:
			var q: Vector2 = r + out * (hw + dv) + ax * du
			if not _on_parking(q) and not _in_building(q, 1.5) and not _near_side_road(q, 2.5) and not wet(q.x, q.y):
				return q
	return r + out * (hw + 3.2)


func _on_parking(p: Vector2) -> bool:
	for poly in data.parkings:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(Vector2(q[0], q[1]))
		if Geometry2D.is_point_in_polygon(p, pts):
			return true
	return false


## Rakennus: c = pohjan keskipiste, f = julkisivun suunta (tielle), ax = pituussuunta.
func _poliisi_building(c: Vector2, f: Vector2, ax: Vector2) -> void:
	var hl := POLIISI_SIZE.x / 2.0
	var hd := POLIISI_SIZE.y / 2.0
	# Lattia julkisivun maanpinnan tasolle (tien puoli); rinteen alapuolelle sokkeli jatkuu syvälle.
	var base := INF
	for u in [-hl, 0.0, hl]:
		var q: Vector2 = c + ax * u + f * (hd + 1.0)
		base = minf(base, h(q.x, q.y))
	base -= 0.15
	var yaw := atan2(f.x, f.y)
	var deg := rad_to_deg(yaw)
	ax = Vector2(-f.y, f.x)  # sama kätisyys kuin laatikoiden yaw-kierrossa
	var at := func(u: float, v: float, y: float) -> Vector3:
		var q := c + ax * u + f * v
		return Vector3(q.x, base + y, q.y)
	var box := func(size: Vector3, u: float, v: float, y: float, col: Color) -> MeshInstance3D:
		return B.mesh(self, B.boxm(size), at.call(u, v, y), col, Vector3(0, deg, 0))
	var brick := Color(0.6, 0.3, 0.22)
	var white := Color(0.92, 0.92, 0.89)
	var glass := Color(0.12, 0.16, 0.22)
	var blue := Color(0.05, 0.2, 0.58)
	var conc := Color(0.6, 0.6, 0.58)
	# Sokkeli, tiiliseinät, valkoinen räystäsnauha ja tumma katon reuna.
	box.call(Vector3(POLIISI_SIZE.x + 0.2, 4.8, POLIISI_SIZE.y + 0.2), 0.0, 0.0, -1.6, conc)
	box.call(Vector3(POLIISI_SIZE.x, 3.3, POLIISI_SIZE.y), 0.0, 0.0, 0.8 + 1.65, brick)
	for k2 in 10:  # tiilisaumat vaakaan julkisivussa
		box.call(Vector3(POLIISI_SIZE.x + 0.01, 0.02, 0.01), 0.0, hd + 0.005, 0.95 + k2 * 0.32, brick.lightened(0.18))
	box.call(Vector3(POLIISI_SIZE.x + 0.3, 0.6, POLIISI_SIZE.y + 0.3), 0.0, 0.0, 4.35, white)
	box.call(Vector3(POLIISI_SIZE.x + 0.4, 0.12, POLIISI_SIZE.y + 0.4), 0.0, 0.0, 4.7, Color(0.15, 0.15, 0.16))
	# Nauhaikkunat oven molemmin puolin: tumma lasi, valkoiset karmit ja välipuitteet, ikkunapellit.
	for su in [-1.0, 1.0]:
		var wu: float = su * 4.9
		box.call(Vector3(5.6, 1.15, 0.06), wu, hd + 0.03, 2.2, glass)
		box.call(Vector3(5.8, 0.08, 0.1), wu, hd + 0.05, 2.8, white)
		box.call(Vector3(5.8, 0.1, 0.22), wu, hd + 0.1, 1.6, white)
		for m in 5:
			box.call(Vector3(0.07, 1.15, 0.08), wu - 2.8 + m * 1.4, hd + 0.05, 2.2, white)
		for m in 4:  # sälekaihtimet puoliksi alhaalla
			box.call(Vector3(5.5, 0.03, 0.02), wu, hd + 0.065, 2.7 - m * 0.09, Color(0.85, 0.85, 0.82))
	# Sivuseinien ikkunat.
	for sv in [-1.0, 1.0]:
		for wv in [-2.0, 2.0]:
			var side_win: MeshInstance3D = box.call(Vector3(0.06, 1.15, 2.4), sv * (hl + 0.03), wv, 2.2, glass)
			side_win.position += Vector3.ZERO
	# Sisäänkäynti: lasiovi karmeineen, betoniporras ja katos kahdella tolpalla.
	box.call(Vector3(2.0, 2.4, 0.06), 0.0, hd + 0.03, 0.8 + 1.2, glass.lightened(0.15))
	box.call(Vector3(2.2, 0.1, 0.1), 0.0, hd + 0.06, 3.25, white)
	for du in [-1.05, 0.0, 1.05]:
		box.call(Vector3(0.08, 2.4, 0.1), du, hd + 0.06, 2.0, white)
	box.call(Vector3(0.04, 0.4, 0.06), 0.35, hd + 0.12, 2.0, Color(0.75, 0.76, 0.8))  # vetokahva
	box.call(Vector3(3.2, 0.3, 1.4), 0.0, hd + 0.7, 0.65, conc)
	box.call(Vector3(4.2, 0.28, 2.6), 0.0, hd + 1.3, 3.45, white)
	box.call(Vector3(4.25, 0.06, 2.65), 0.0, hd + 1.3, 3.62, Color(0.15, 0.15, 0.16))
	for pu in [-1.9, 1.9]:
		box.call(Vector3(0.14, 3.3, 0.14), pu, hd + 2.45, 1.95, Color(0.3, 0.3, 0.32))
	# Kyltit: POLIISI katoksen otsassa, nimikyltti ikkunanauhan yllä, aukioloajat oven vieressä.
	var pol := B.sign_plate(self, "POLIISI", blue, Color.WHITE, 0.3, 70, Color.WHITE, "Helvetica Neue")
	pol.position = at.call(0.0, hd + 2.64, 3.45)
	pol.rotation.y = yaw
	var nimi := B.sign_plate(self, "VAALAN POLIISIASEMA", white, blue, 0.32, 52, blue, "Helvetica Neue")
	nimi.position = at.call(-4.9, hd + 0.05, 3.45)
	nimi.rotation.y = yaw
	var auki := B.sign_plate(self, "Lupapalvelut\nma–pe 9–15", white, Color(0.1, 0.1, 0.12), 0.14, 22, blue)
	auki.position = at.call(1.75, hd + 0.05, 2.3)
	auki.rotation.y = yaw
	# Lipputanko ja Suomen lippu (valkoinen kangas, sininen risti).
	var fp: Vector3 = at.call(hl - 1.0, hd + POLIISI_YARD - 1.5, 0.0)
	fp.y = h(fp.x, fp.z)
	B.mesh(self, B.cyl(0.05, 0.07, 9.0, 8), fp + Vector3(0, 4.5, 0), white)
	B.mesh(self, B.sphere(0.1, 8), fp + Vector3(0, 9.05, 0), Color(0.85, 0.7, 0.3))
	var flag := Node3D.new()
	add_child(flag)
	flag.position = fp + Vector3(0, 8.3, 0)
	flag.rotation.y = yaw + PI / 2.0
	B.mesh(flag, B.boxm(Vector3(0.02, 1.1, 1.8)), Vector3(0, 0, -0.95), Color(0.97, 0.97, 0.97))
	B.mesh(flag, B.boxm(Vector3(0.03, 0.3, 1.8)), Vector3(0, 0, -0.95), Color(0.0, 0.21, 0.5))
	B.mesh(flag, B.boxm(Vector3(0.03, 1.1, 0.3)), Vector3(0, 0, -0.65), Color(0.0, 0.21, 0.5))
	# Poliisiauto pihassa nokka asemalle: valkoinen, sininen kylkiraita, POLIISI-teksti ja sininen valopaneeli.
	var car := Node3D.new()
	add_child(car)
	var cp: Vector3 = at.call(-5.5, hd + 4.2, 0.0)
	cp.y = h(cp.x, cp.z)
	car.position = cp
	car.rotation.y = yaw
	Vehicles.car(car, Color(0.95, 0.95, 0.95), "PSS-112")
	for sx in [-0.915, 0.915]:
		Vehicles.part(car, B.boxm(Vector3(0.02, 0.14, 4.2)), Vector3(sx, 0.62, 0), Vehicles.paint(blue))
		var l := Label3D.new()
		l.text = "POLIISI"
		l.font_size = 40
		l.pixel_size = 0.005
		l.modulate = blue
		l.outline_size = 0
		l.double_sided = false
		l.position = Vector3(sx * 1.01, 0.8, 0.2)
		l.rotation.y = PI / 2.0 if sx > 0.0 else -PI / 2.0
		car.add_child(l)
	Vehicles.part(car, B.boxm(Vector3(1.1, 0.12, 0.3)), Vector3(0, 1.55, 0.1), Vehicles.lamp(Color(0.2, 0.4, 1.0)))
	# Törmäys ja pohja ajoalueesta pois.
	var body := StaticBody3D.new()
	add_child(body)
	var cs := B.box_shape(Vector3(POLIISI_SIZE.x, 5.0, POLIISI_SIZE.y), Vector3.ZERO)
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), at.call(0.0, 0.0, 2.5))
	body.add_child(cs)
	var ccs := B.box_shape(Vector3(1.9, 1.5, 4.4), Vector3.ZERO)
	ccs.transform = Transform3D(Basis(Vector3.UP, yaw), cp + Vector3(0, 0.75, 0))
	body.add_child(ccs)
	var poly := PackedVector2Array()
	for cu in [[-hl, -hd], [hl, -hd], [hl, hd], [-hl, hd]]:
		poly.append(c + ax * cu[0] + f * cu[1])
	_bld_polys.append(poly)
	poliisi_front = at.call(0.0, hd + 2.0, 0.0)
	poliisi_front.y = h(poliisi_front.x, poliisi_front.z)
	poliisi_yard = at.call(-3.4, hd + 4.6, 0.0)
	poliisi_yard.y = h(poliisi_yard.x, poliisi_yard.z)
	poliisi_roadside = at.call(2.5, hd + POLIISI_YARD - 1.2, 0.0)
	poliisi_roadside.y = h(poliisi_roadside.x, poliisi_roadside.z)
	poliisi_out = Vector3(f.x, 0, f.y)

func _in_building(p: Vector2, margin: float) -> bool:
	for poly in _bld_polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
		for k in poly.size():
			if Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()]).distance_to(p) < margin:
				return true
	return false


func _near_side_road(p: Vector2, d: float) -> bool:
	for r in data.side_roads:
		if r.kind == "rail":
			continue
		for k in r.pts.size() - 1:
			var a := Vector2(r.pts[k][0], r.pts[k][1])
			var b := Vector2(r.pts[k + 1][0], r.pts[k + 1][1])
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < d:
				return true
	return false


## Onko kohta lähempänä kuin d mitä tahansa raidetta (asemalla rinnakkaisia raiteita ja pistoraide).
func _near_rail(p: Vector2, d: float) -> bool:
	for r in data.side_roads:
		if r.kind != "rail":
			continue
		for k in r.pts.size() - 1:
			var a := Vector2(r.pts[k][0], r.pts[k][1])
			var b := Vector2(r.pts[k + 1][0], r.pts[k + 1][1])
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < d:
				return true
	return false


func _build_tori() -> void:
	if _zabuki == Vector3.INF:
		return
	# Kiveys: harmaa noppakivi kävelyalueen muodossa.
	var tris := Geometry2D.triangulate_polygon(_tori)
	if tris.is_empty():
		push_warning("Vaalan torin monikulmio ei kolmioidu")
	else:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_surface(st, _tori, LIFT_ASPHALT + 0.015)  # parkkien ja tien yläpuolelle
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _surf_mat("asphalt")  # torin kenttä on asfalttia (Vaalan matkakeskuksen piha)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_build_stalls()
	_build_zabuki()
	_build_matkakeskus()


## Vaalan matkakeskus torin takana (tie.json keskusta.matkakeskus; tools/vaala_torisiirto.py): pitkä matala rakennus, jonka
## julkisivu on torille päin. Alaosa punatiiltä, yläosa vaalea rappaus, kattona tasakatto; sisäänkäynnin torni ("VAALA") ja
## sinitolppainen katos. Paikallinen kehys: +u = katsojasta torilta vasemmalle (Zabuki on tässä päässä), +v = torille päin.
func _build_matkakeskus() -> void:
	var mk = data.get("keskusta", {}).get("matkakeskus")
	if mk == null:
		return
	var f := Vector2(mk.face[0], mk.face[1]).normalized()
	var ax := Vector2(-f.y, f.x)
	var c := Vector2(mk.c[0], mk.c[1])
	var bl: float = mk.len
	var bd: float = mk.depth
	var base := INF
	for u in [-bl / 2.0, bl / 2.0]:
		for v in [-bd / 2.0, bd / 2.0]:
			var q: Vector2 = c + ax * u + f * v
			base = minf(base, h(q.x, q.y))
	base -= 0.1
	var yaw := atan2(f.x, f.y)
	var deg := rad_to_deg(yaw)
	var rot := Vector3(0, deg, 0)
	var at := func(u: float, v: float, y: float) -> Vector3:
		var q := c + ax * u + f * v
		return Vector3(q.x, base + y, q.y)
	var brick := Color(0.55, 0.26, 0.2)
	var cream := Color(0.9, 0.88, 0.82)
	var blue := Color(0.12, 0.26, 0.52)
	var glass := Color(0.17, 0.25, 0.32)
	var front := bd / 2.0
	# Runko: tiilisokkeli, vaalea yläosa, vaakareunus ja tasakatto.
	B.mesh(self, B.boxm(Vector3(bl, 2.3, bd)), at.call(0, 0, 1.15), brick, rot)
	B.mesh(self, B.boxm(Vector3(bl + 0.1, 1.8, bd + 0.1)), at.call(0, 0, 3.2), cream, rot)
	B.mesh(self, B.boxm(Vector3(bl + 0.14, 0.14, bd + 0.14)), at.call(0, 0, 2.32), Color(0.78, 0.76, 0.7), rot)
	B.mesh(self, B.boxm(Vector3(bl + 0.7, 0.3, bd + 0.7)), at.call(0, 0, 4.25), Color(0.36, 0.37, 0.4), rot)
	B.mesh(self, B.cyl(0.35, 0.35, 1.4, 10), at.call(-14.0, -2.0, 5.0), Color(0.62, 0.64, 0.66))
	# Ikkunat tiilisokkelissa (sininen karmi, tumma lasi, vaalea pielilauta) torilta katsoen oikeassa osassa.
	var wu := -20.0
	while wu <= 1.0:
		B.mesh(self, B.boxm(Vector3(2.0, 1.5, 0.06)), at.call(wu, front + 0.02, 1.35), blue, rot)
		B.mesh(self, B.boxm(Vector3(1.7, 1.2, 0.07)), at.call(wu, front + 0.03, 1.35), glass, rot)
		B.mesh(self, B.boxm(Vector3(0.06, 1.2, 0.08)), at.call(wu, front + 0.04, 1.35), blue, rot)
		B.mesh(self, B.boxm(Vector3(2.2, 0.06, 0.16)), at.call(wu, front + 0.07, 0.68), Color(0.8, 0.78, 0.72), rot)
		wu += 3.4
	# Sisäänkäyntitorni: lasiseinä ristikoineen, ovi ja VAALA-kyltti torin katolla.
	var tu := 5.0
	B.mesh(self, B.boxm(Vector3(5.2, 6.3, 3.0)), at.call(tu, front + 1.2, 3.15), cream, rot)
	B.mesh(self, B.boxm(Vector3(3.8, 4.6, 0.08)), at.call(tu, front + 2.72, 2.4), glass, rot)
	for k in 5:
		B.mesh(self, B.boxm(Vector3(0.07, 4.6, 0.1)), at.call(tu - 1.6 + k * 0.8, front + 2.76, 2.4), blue, rot)
	for y in [1.2, 2.4, 3.6]:
		B.mesh(self, B.boxm(Vector3(3.8, 0.07, 0.1)), at.call(tu, front + 2.76, y), blue, rot)
	B.mesh(self, B.boxm(Vector3(1.6, 2.3, 0.12)), at.call(tu, front + 2.8, 1.15), Color(0.1, 0.14, 0.2), rot)
	B.mesh(self, B.boxm(Vector3(5.6, 0.3, 3.4)), at.call(tu, front + 1.2, 6.45), Color(0.36, 0.37, 0.4), rot)
	var vaala := B.sign_plate(self, "VAALA", blue, Color.WHITE, 0.7, 90, Color(0.9, 0.9, 0.92), "Helvetica Neue")
	vaala.position = at.call(tu, front + 2.75, 5.2)
	vaala.rotation.y = yaw
	var mks := B.sign_plate(self, "MATKAKESKUS", blue, Color.WHITE, 0.45, 60, Color(0.9, 0.9, 0.92), "Helvetica Neue")
	mks.position = at.call(-12.0, front + 0.06, 3.65)
	mks.rotation.y = yaw
	# Katos tornista oikealle: valkoinen aaltopelti ja siniset tolpat.
	var cl := 24.5
	var cu := tu - 3.0 - cl / 2.0
	B.mesh(self, B.boxm(Vector3(cl, 0.14, 2.6)), at.call(cu, front + 1.3, 3.1), Color(0.88, 0.92, 0.96), rot)
	B.mesh(self, B.boxm(Vector3(cl, 0.22, 0.08)), at.call(cu, front + 2.6, 3.04), blue, rot)
	var pu := tu - 3.0
	while pu > tu - 3.0 - cl:
		B.mesh(self, B.cyl(0.07, 0.07, 3.1, 8), at.call(pu, front + 2.5, 1.55), blue)
		pu -= 4.2
	# Vasen pää: pieni katos Zabukin viereen ja valkoinen kaide (kuten kuvassa).
	B.mesh(self, B.boxm(Vector3(4.0, 0.12, 1.8)), at.call(bl / 2.0 - 1.0, front + 0.9, 3.0), Color(0.88, 0.92, 0.96), rot)
	var body := StaticBody3D.new()
	add_child(body)
	var cs := B.box_shape(Vector3(bl, 4.4, bd), Vector3.ZERO)
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), at.call(0, 0, 2.2))
	body.add_child(cs)
	var ct := B.box_shape(Vector3(5.2, 6.3, 3.0), Vector3.ZERO)
	ct.transform = Transform3D(Basis(Vector3.UP, yaw), at.call(tu, front + 1.2, 3.15))
	body.add_child(ct)
	# Pihan kalusteet: kivetty kävelyreitti tornin eteen, kukkapenkki, valaisin ja pysäköityjä autoja.
	var walk := B.mesh(self, B.boxm(Vector3(3.4, 0.03, 9.0)), at.call(tu, front + 2.9 + 4.5, 0.0), Color(0.64, 0.62, 0.58), rot)
	walk.position.y = h(walk.position.x, walk.position.z) + 0.07
	for side in [-1.7, 1.7]:
		var kb := B.mesh(self, B.boxm(Vector3(0.12, 0.06, 9.0)), at.call(tu + side, front + 2.9 + 4.5, 0.0), Color(0.78, 0.77, 0.74), rot)
		kb.position.y = h(kb.position.x, kb.position.z) + 0.09
	var bu := tu - 3.4
	var bed := B.mesh(self, B.boxm(Vector3(2.8, 0.3, 6.0)), at.call(bu, front + 6.5, 0.0), Color(0.3, 0.2, 0.12), rot)
	bed.position.y = h(bed.position.x, bed.position.z) + 0.15
	var rng := RandomNumberGenerator.new()
	rng.seed = 5309
	for k in 9:
		var bp: Vector3 = at.call(bu + rng.randf_range(-0.9, 0.9), front + 3.9 + k * 0.62, 0.0)
		bp.y = h(bp.x, bp.z) + 0.45
		B.mesh(self, B.sphere(0.55, 8), bp, Color(0.2, 0.42, 0.18)).scale = Vector3(1.3, 0.75, 1.1)
		var fp: Vector3 = bp + Vector3(rng.randf_range(-0.3, 0.3), 0.32, rng.randf_range(-0.3, 0.3))
		B.mesh(self, B.sphere(0.16, 6), fp, Color(0.85, 0.12, 0.1))
	var lp: Vector3 = at.call(tu + 2.6, front + 4.0, 0.0)
	lp.y = h(lp.x, lp.z)
	B.mesh(self, B.cyl(0.05, 0.06, 3.8, 8), lp + Vector3(0, 1.9, 0), Color(0.3, 0.32, 0.34))
	B.mesh(self, B.sphere(0.3, 10), lp + Vector3(0, 3.95, 0), Color(1, 1, 1)).material_override = B.unshaded(Color(1.0, 0.98, 0.9))
	for cu2 in [-5.0, -8.2, -11.4]:
		var cp: Vector3 = at.call(cu2, front + 6.0, 0.0)
		cp.y = h(cp.x, cp.z)
		B.parked_car(self, cp, deg + 90.0, [Color(0.15, 0.3, 0.7), Color(0.7, 0.12, 0.1), Color(0.75, 0.75, 0.78)][int(absf(cu2)) % 3])


## Vaalan kunnantalo (tie.json keskusta.kunnantalo; tools/vaala_kunnantalo.py): vasemmalla kaksikerroksinen vaalea siipi
## (pienet neliöikkunat, kunnanvaakuna, puuovi), oikealla keltainen siipi lasisine matalaosineen ja valkokatoksinen
## päätyovi, takana torni ja korkea vaalea osa. Edessä nurmikko, kivireunainen suihkulähde, reitti, valaisimet ja penkit.
## Paikallinen kehys: +u = katsojasta rakennukselle vasemmalle, +v = tielle päin (julkisivu).
func _build_kunnantalo() -> void:
	var kt = data.get("keskusta", {}).get("kunnantalo")
	if kt == null:
		return
	var f := Vector2(kt.face[0], kt.face[1]).normalized()
	var ax := Vector2(-f.y, f.x)
	var c := Vector2(kt.c[0], kt.c[1])
	var bl: float = kt.len
	var bd: float = kt.depth
	var base := INF
	for u in [-bl / 2.0, bl / 2.0]:
		for v in [-bd / 2.0, bd / 2.0]:
			var q: Vector2 = c + ax * u + f * v
			base = minf(base, h(q.x, q.y))
	base -= 0.1
	var yaw := atan2(f.x, f.y)
	var deg := rad_to_deg(yaw)
	var rot := Vector3(0, deg, 0)
	var rot_roof := Vector3(0, deg + 90.0, 0)  # harjan suunta u-akselille (PrismMesh: harja z-akselilla)
	var at := func(u: float, v: float, y: float) -> Vector3:
		var q := c + ax * u + f * v
		return Vector3(q.x, base + y, q.y)
	var ground := func(u: float, v: float, up: float) -> Vector3:
		var q := c + ax * u + f * v
		return Vector3(q.x, h(q.x, q.y) + up, q.y)
	var cream := Color(0.92, 0.88, 0.72)
	var yellow := Color(0.9, 0.75, 0.34)
	var tile := Color(0.56, 0.26, 0.19)
	var wood := Color(0.42, 0.28, 0.16)
	var glass := Color(0.62, 0.74, 0.8)
	var white := Color(0.95, 0.95, 0.93)
	var green := Color(0.16, 0.36, 0.26)
	var front := bd / 2.0
	var roof_sz := func(depth: float, rise: float, length: float) -> PrismMesh:
		var pm := PrismMesh.new()
		pm.size = Vector3(depth, rise, length)
		return pm
	# --- Vasen siipi: u 3..23, kaksi kerrosta (7 m), tiilikatto. ---
	var lu := 13.0
	B.mesh(self, B.boxm(Vector3(20.0, 7.0, bd)), at.call(lu, 0, 3.5), cream, rot)
	B.mesh(self, B.boxm(Vector3(20.0, 0.5, bd + 0.1)), at.call(lu, 0, 0.25), Color(0.7, 0.66, 0.55), rot)
	B.mesh(self, roof_sz.call(bd + 1.2, 2.4, 21.0), at.call(lu, 0, 8.2), tile, rot_roof)
	# Ikkunat: puukarmiset ikkunat vihreine ikkunaluukkuineen kahdessa kerroksessa, pieniä neliöikkunoita vasemmassa päässä.
	for k in 4:
		var wu := 8.0 + k * 3.4
		for wy in [2.4, 5.5]:
			B.mesh(self, B.boxm(Vector3(1.7, 1.3, 0.07)), at.call(wu, front + 0.03, wy), wood, rot)
			B.mesh(self, B.boxm(Vector3(1.4, 1.0, 0.08)), at.call(wu, front + 0.05, wy), glass, rot)
			B.mesh(self, B.boxm(Vector3(0.35, 1.2, 0.05)), at.call(wu + 1.0, front + 0.05, wy), green, rot)
	for k in 4:
		for wy in [2.0, 5.6]:
			B.mesh(self, B.boxm(Vector3(0.6, 0.6, 0.06)), at.call(15.5 + k * 1.7, front + 0.04, wy), Color(0.3, 0.25, 0.18), rot)
	# Pääovi (kaksoispuuovi katoksella ja portailla), vaakuna ja ilmoitustaulu.
	B.mesh(self, B.boxm(Vector3(2.2, 2.5, 0.12)), at.call(lu + 2.0, front + 0.05, 1.3), wood, rot)
	B.mesh(self, B.boxm(Vector3(0.06, 2.3, 0.14)), at.call(lu + 2.0, front + 0.08, 1.3), Color(0.25, 0.17, 0.1), rot)
	B.mesh(self, B.boxm(Vector3(3.4, 0.14, 1.2)), at.call(lu + 2.0, front + 0.6, 2.9), Color(0.55, 0.5, 0.4), rot)
	B.mesh(self, B.boxm(Vector3(2.6, 0.2, 0.7)), at.call(lu + 2.0, front + 0.5, 0.1), Color(0.55, 0.55, 0.55), rot)
	var crest := B.mesh(self, B.boxm(Vector3(0.9, 1.1, 0.06)), at.call(21.0, front + 0.05, 4.4), Color(0.75, 0.1, 0.12), rot)
	B.mesh(crest, B.boxm(Vector3(0.45, 0.5, 0.04)), Vector3(0, 0.1, 0.04), Color(0.92, 0.92, 0.9))
	var kt_sign := B.sign_plate(self, "KUNNANTALO", Color(0.14, 0.28, 0.5), Color.WHITE, 0.3, 48, Color(0.9, 0.9, 0.92), "Helvetica Neue")
	kt_sign.position = at.call(lu + 2.0, front + 0.62, 3.3)
	kt_sign.rotation.y = yaw
	B.mesh(self, B.boxm(Vector3(1.7, 1.1, 0.05)), at.call(21.4, front + 0.04, 1.6), Color(0.82, 0.82, 0.78), rot)
	# --- Oikea siipi: keltainen u -17..3, matala lasiosa edessä. ---
	var mu := -7.0
	B.mesh(self, B.boxm(Vector3(20.0, 6.2, bd)), at.call(mu, 0, 3.1), yellow, rot)
	B.mesh(self, roof_sz.call(bd + 1.2, 2.2, 21.0), at.call(mu, 0, 7.3), tile, rot_roof)
	B.mesh(self, B.boxm(Vector3(20.0, 0.5, bd + 0.1)), at.call(mu, 0, 0.25), Color(0.65, 0.58, 0.4), rot)
	for k in 5:
		B.mesh(self, B.boxm(Vector3(1.0, 1.1, 0.07)), at.call(-15.0 + k * 3.8, front + 0.04, 4.9), wood, rot)
		B.mesh(self, B.boxm(Vector3(0.8, 0.9, 0.08)), at.call(-15.0 + k * 3.8, front + 0.06, 4.9), glass, rot)
	# Lasiosa: valkoiset karmit, matala punakattoinen räystäs.
	var gu := -7.0
	B.mesh(self, B.boxm(Vector3(12.0, 3.3, 2.4)), at.call(gu, front + 1.2, 1.65), glass, rot)
	for k in 9:
		B.mesh(self, B.boxm(Vector3(0.12, 3.3, 0.1)), at.call(gu - 5.4 + k * 1.35, front + 2.44, 1.65), white, rot)
	for y in [0.1, 3.25]:
		B.mesh(self, B.boxm(Vector3(12.2, 0.14, 0.14)), at.call(gu, front + 2.44, y), white, rot)
	B.mesh(self, B.boxm(Vector3(13.0, 0.18, 3.4)), at.call(gu, front + 1.5, 3.6), tile, Vector3(-8.0, deg, 0))
	# --- Päätyosa: u -23..-17, vaalea katos ja punainen ovi, luiska kaiteineen. ---
	B.mesh(self, B.boxm(Vector3(6.0, 6.6, bd)), at.call(-20.0, 0, 3.3), yellow, rot)
	B.mesh(self, roof_sz.call(bd + 1.0, 2.0, 6.6), at.call(-20.0, 0, 7.6), tile, rot_roof)
	B.mesh(self, B.boxm(Vector3(1.6, 2.4, 0.1)), at.call(-20.5, front + 0.04, 1.25), Color(0.6, 0.12, 0.1), rot)
	B.mesh(self, B.boxm(Vector3(5.4, 0.16, 2.4)), at.call(-20.0, front + 1.2, 3.0), white, rot)
	for sx in [-22.6, -17.6]:
		B.mesh(self, B.cyl(0.07, 0.07, 3.0, 8), at.call(sx, front + 2.2, 1.5), white)
	B.mesh(self, B.boxm(Vector3(1.0, 1.2, 0.07)), at.call(-18.2, front + 0.04, 4.9), wood, rot)
	B.mesh(self, B.boxm(Vector3(3.0, 0.3, 2.0)), at.call(-20.0, front + 1.4, 0.15), Color(0.55, 0.55, 0.56), rot)
	# --- Takaosa: keltainen torni ja korkea vaalea osa harjakattoineen. ---
	B.mesh(self, B.boxm(Vector3(4.0, 13.0, 4.0)), at.call(3.5, -bd / 2.0 - 1.0, 6.5), Color(0.82, 0.68, 0.28), rot)
	B.mesh(self, B.boxm(Vector3(4.4, 0.4, 4.4)), at.call(3.5, -bd / 2.0 - 1.0, 13.2), Color(0.5, 0.36, 0.22), rot)
	B.mesh(self, B.boxm(Vector3(12.0, 9.0, 7.0)), at.call(-9.0, -bd / 2.0 - 3.0, 4.5), Color(0.93, 0.92, 0.88), rot)
	B.mesh(self, roof_sz.call(7.6, 2.4, 12.6), at.call(-9.0, -bd / 2.0 - 3.0, 10.2), tile, rot_roof)
	# Törmäys.
	var body := StaticBody3D.new()
	add_child(body)
	for part in [[Vector3(20.0, 8.0, bd), at.call(lu, 0, 4.0)], [Vector3(20.0, 6.5, bd), at.call(mu, 0, 3.25)],
			[Vector3(6.0, 7.0, bd), at.call(-20.0, 0, 3.5)], [Vector3(12.0, 3.4, 2.4), at.call(gu, front + 1.2, 1.7)],
			[Vector3(4.0, 13.0, 4.0), at.call(3.5, -bd / 2.0 - 1.0, 6.5)], [Vector3(12.0, 9.0, 7.0), at.call(-9.0, -bd / 2.0 - 3.0, 4.5)]]:
		var cs := B.box_shape(part[0], Vector3.ZERO)
		cs.transform = Transform3D(Basis(Vector3.UP, yaw), part[1])
		body.add_child(cs)
	# --- Piha: kivetty etureuna, reitti pääovelta tielle, suihkulähde, pensaat, valaisimet, penkit, lipputanko. ---
	var strip := B.mesh(self, B.boxm(Vector3(bl, 0.03, 3.2)), ground.call(0.0, front + 1.6, 0.06), Color(0.62, 0.6, 0.56), rot)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var path_len := 20.0
	var path := B.mesh(self, B.boxm(Vector3(2.4, 0.03, path_len)), ground.call(lu + 2.0, front + 3.2 + path_len / 2.0, 0.07), Color(0.34, 0.34, 0.36), rot)
	path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fc: Vector3 = ground.call(1.0, front + 9.0, 0.0)
	B.mesh(self, B.cyl(2.5, 2.5, 0.7, 20), fc + Vector3(0, 0.35, 0), Color(0.45, 0.42, 0.38))
	B.mesh(self, B.cyl(2.1, 2.1, 0.12, 20), fc + Vector3(0, 0.66, 0), Color(0.22, 0.38, 0.5))
	B.mesh(self, B.cyl(0.35, 0.45, 0.9, 8), fc + Vector3(0, 1.0, 0), Color(0.18, 0.15, 0.12))
	B.mesh(self, B.sphere(0.25, 8), fc + Vector3(0, 1.65, 0), Color(0.18, 0.15, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6112
	for k in 14:
		var bp: Vector3 = ground.call(-4.0 + k * 1.4, front + 0.9 + rng.randf_range(-0.2, 0.2), 0.0)
		B.mesh(self, B.sphere(0.5, 8), bp + Vector3(0, 0.4, 0), Color(0.18 + rng.randf() * 0.08, 0.4, 0.17)).scale = Vector3(1.2, 0.8, 1.0)
		if k % 3 == 0:
			B.mesh(self, B.sphere(0.13, 6), bp + Vector3(0, 0.85, 0), Color(0.85, 0.2, 0.3))
	for lu2 in [21.0, 11.0, -4.0, -14.0]:
		var lp: Vector3 = ground.call(lu2, front + 4.5, 0.0)
		B.mesh(self, B.cyl(0.05, 0.06, 3.6, 8), lp + Vector3(0, 1.8, 0), Color(0.62, 0.62, 0.64))
		B.mesh(self, B.sphere(0.32, 10), lp + Vector3(0, 3.7, 0), Color(1, 1, 1)).material_override = B.unshaded(Color(1.0, 0.97, 0.85))
	for bu in [lu - 4.0, lu + 7.5]:
		var bp: Vector3 = ground.call(bu, front + 6.5, 0.0)
		B.mesh(self, B.boxm(Vector3(2.0, 0.08, 0.5)), bp + Vector3(0, 0.5, 0), Color(0.75, 0.12, 0.1), rot)
		B.mesh(self, B.boxm(Vector3(2.0, 0.45, 0.06)), bp + Vector3(0, 0.78, -0.22), Color(0.75, 0.12, 0.1), rot)
		for lx in [-0.8, 0.8]:
			B.mesh(self, B.boxm(Vector3(0.06, 0.5, 0.4)), bp + Vector3(ax.x * lx, 0.25, ax.y * lx), Color(0.3, 0.3, 0.3), rot)
	var fp: Vector3 = ground.call(24.5, front + 1.5, 0.0)
	B.mesh(self, B.cyl(0.07, 0.1, 9.0, 8), fp + Vector3(0, 4.5, 0), Color(0.85, 0.85, 0.85))


## Apteekki Satamantien varressa radan alikulun jälkeen oikealla (tie.json keskusta.apteekki; tools/vaala_apteekki.py):
## matala vaalea liikerakennus, jonka julkisivu on lasia ja ovi katoksen alla. Vihreä APTEEKKI-kyltti ja vihreä risti,
## edessä asfalttiparkki (data.parkings) ruutuviivoin, P-kyltti ja autoja. Paikallinen kehys: +u = katsojasta vasemmalle,
## +v = tielle päin (julkisivu). Rakennuksessa ei ole sisätilaa.
func _build_apteekki() -> void:
	var ap = data.get("keskusta", {}).get("apteekki")
	if ap == null:
		return
	var f := Vector2(ap.face[0], ap.face[1]).normalized()
	var ax := Vector2(-f.y, f.x)
	var c := Vector2(ap.c[0], ap.c[1])
	var bl: float = ap.len
	var bd: float = ap.depth
	var pd: float = ap.park_depth
	var base := INF
	for u in [-bl / 2.0, bl / 2.0]:
		for v in [-bd / 2.0, bd / 2.0]:
			var q: Vector2 = c + ax * u + f * v
			base = minf(base, h(q.x, q.y))
	base -= 0.1
	var yaw := atan2(f.x, f.y)
	var deg := rad_to_deg(yaw)
	var rot := Vector3(0, deg, 0)
	var at := func(u: float, v: float, y: float) -> Vector3:
		var q := c + ax * u + f * v
		return Vector3(q.x, base + y, q.y)
	var ground := func(u: float, v: float, up: float) -> Vector3:
		var q := c + ax * u + f * v
		return Vector3(q.x, h(q.x, q.y) + up, q.y)
	var wall := Color(0.93, 0.93, 0.89)
	var green := Color(0.05, 0.5, 0.28)
	var frame := Color(0.3, 0.33, 0.34)
	var glass := Color(0.55, 0.72, 0.78)
	var front := bd / 2.0
	# Runko: vaalea seinä, tumma sokkeli, tasakatto ja kattoreunus.
	B.mesh(self, B.boxm(Vector3(bl, 4.2, bd)), at.call(0, 0, 2.1), wall, rot)
	B.mesh(self, B.boxm(Vector3(bl + 0.1, 0.5, bd + 0.1)), at.call(0, 0, 0.25), Color(0.35, 0.35, 0.37), rot)
	B.mesh(self, B.boxm(Vector3(bl + 0.5, 0.35, bd + 0.5)), at.call(0, 0, 4.35), Color(0.36, 0.37, 0.4), rot)
	B.mesh(self, B.boxm(Vector3(2.0, 0.9, 1.4)), at.call(-5.0, -2.5, 5.0), Color(0.62, 0.64, 0.66), rot)
	# Lasijulkisivu: kaksi näyteikkunaa ja lasiovi keskellä, tummat karmit.
	for wu in [-5.4, 5.4]:
		B.mesh(self, B.boxm(Vector3(6.2, 2.7, 0.08)), at.call(wu, front + 0.03, 1.8), frame, rot)
		B.mesh(self, B.boxm(Vector3(5.9, 2.4, 0.09)), at.call(wu, front + 0.04, 1.8), glass, rot)
		for k in 3:
			B.mesh(self, B.boxm(Vector3(0.07, 2.4, 0.1)), at.call(wu - 2.0 + k * 2.0, front + 0.06, 1.8), frame, rot)
	B.mesh(self, B.boxm(Vector3(2.4, 2.5, 0.09)), at.call(0, front + 0.04, 1.35), frame, rot)
	B.mesh(self, B.boxm(Vector3(2.1, 2.3, 0.1)), at.call(0, front + 0.05, 1.3), glass, rot)
	B.mesh(self, B.boxm(Vector3(0.06, 2.3, 0.11)), at.call(0, front + 0.06, 1.3), frame, rot)
	# Sisäänkäynnin katos ja kynnys.
	B.mesh(self, B.boxm(Vector3(5.0, 0.16, 1.8)), at.call(0, front + 0.9, 3.05), green, rot)
	B.mesh(self, B.boxm(Vector3(3.0, 0.12, 1.2)), at.call(0, front + 0.6, 0.06), Color(0.6, 0.6, 0.6), rot)
	# Kyltit: APTEEKKI kattoreunuksen yläpuolella ja vihreä risti seinässä.
	var sign_p := B.sign_plate(self, "APTEEKKI", green, Color.WHITE, 0.8, 100, Color(0.9, 0.95, 0.9), "Helvetica Neue")
	sign_p.position = at.call(0, front + 0.06, 3.72)
	sign_p.rotation.y = yaw
	for arm in [Vector3(0.95, 0.3, 0.1), Vector3(0.3, 0.95, 0.1)]:
		B.mesh(self, B.boxm(arm), at.call(-8.0, front + 0.08, 3.2), green, rot).material_override = B.unshaded(Color(0.1, 0.8, 0.4))
	var hours := B.sign_plate(self, "AVOINNA\nma-pe 9-18", Color(0.97, 0.97, 0.95), Color(0.1, 0.1, 0.1), 0.18, 28, Color(0.5, 0.5, 0.5), "Helvetica Neue")
	hours.position = at.call(2.0, front + 0.06, 1.35)
	hours.rotation.y = yaw
	var body := StaticBody3D.new()
	add_child(body)
	var cs := B.box_shape(Vector3(bl, 4.4, bd), Vector3.ZERO)
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), at.call(0, 0, 2.2))
	body.add_child(cs)
	# Parkki: ruutuviivat (6 ruutua), P-kyltti ja kaksi autoa; asfaltti piirtyy data.parkings-listasta.
	var pv := front + pd / 2.0 + 0.2
	for k in 7:
		var ln := B.mesh(self, B.boxm(Vector3(0.12, 0.012, pd - 1.0)), ground.call(-bl / 2.0 - 1.0 + k * 3.0, pv, 0.07), Color(0.95, 0.95, 0.95), rot)
		ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for pu in [-7.5, -1.5]:
		B.parked_car(self, ground.call(pu, pv, 0.0), deg, [Color(0.2, 0.32, 0.6), Color(0.78, 0.78, 0.8)][int(absf(pu)) % 2])
	var pp: Vector3 = ground.call(bl / 2.0 + 1.5, front + 1.0, 0.0)
	B.mesh(self, B.cyl(0.04, 0.04, 2.2, 8), pp + Vector3(0, 1.1, 0), Color(0.5, 0.5, 0.52))
	var pplate := B.sign_plate(self, "P", Color(0.1, 0.3, 0.7), Color.WHITE, 0.45, 70, Color.WHITE, "Helvetica Neue")
	pplate.position = pp + Vector3(0, 2.3, 0)
	pplate.rotation.y = yaw
	# Pensaita ja kukkaruukut seinän vierellä.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4421
	var door_at: Vector3 = ground.call(0.0, front + 2.2, 0.0)
	doors.append({"id": "apteekki", "pos": door_at, "out": Vector3(f.x, 0, f.y), "hint": "Apteekkiin (käsikauppa ja reseptilääkkeet)"})
	# Takaovi kurkistusluukkuineen (makasiini.gd _build_door, kuten rasvanapin ovi): rakennuksen takaseinässä (-v = taka),
	# betoniporras edessä. Farmaseutti myy luukulta ilman reseptiä (main.gd _apteekki_taka). Vihreä lamppu punaisen sijaan.
	var back := front + 0.05
	B.box(self, Vector3(1.8, 1.0, 0.9), at.call(0, -back - 0.45, 0.0), Color(0.55, 0.55, 0.53), true).rotation_degrees = rot
	var bdoor: Node3D = Makasiini._build_door()
	bdoor.position = at.call(0, -back, 0.5)
	bdoor.rotation.y = yaw + PI  # oven +Z = ulos = rakennuksen taakse (-f)
	add_child(bdoor)
	(bdoor.get_node("Lamppu") as OmniLight3D).light_color = Color(0.3, 1.0, 0.45)
	apteekki_back = bdoor
	var staff := B.sign_plate(self, "HENKILÖKUNTA", Color(0.88, 0.88, 0.84), Color(0.1, 0.35, 0.2), 0.14, 26, Color(0.4, 0.45, 0.42), "Helvetica Neue")
	staff.position = at.call(0, -back - 0.02, 3.55)
	staff.rotation.y = yaw + PI
	doors.append({"id": "apteekki_taka", "pos": ground.call(0.0, -front - 1.7, 0.0), "out": Vector3(-f.x, 0, -f.y), "r": 2.2, "walk": true,
		"hint": "apteekin takaovelle", "text": "Koputa apteekin takaoveen"})
	for k in 6:
		var bp: Vector3 = ground.call(bl / 2.0 - 1.0 - k * 0.9, front + 0.5, 0.0)
		B.mesh(self, B.sphere(0.4, 8), bp + Vector3(0, 0.3, 0), Color(0.2 + rng.randf() * 0.08, 0.42, 0.18)).scale = Vector3(1.2, 0.8, 1.0)


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
			for k in _tori.size():  # kojut irti torin reunasta (reunan ajoalue ei saa katketa kojuun)
				clear = clear and Geometry2D.get_closest_point_to_segment(c, _tori[k], _tori[(k + 1) % _tori.size()]).distance_to(c) > 4.5
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
	# Taitettava klaffipöytä nojaa Zabukin takaseinää vasten (main.gd _klaffi_found poimii; huumeiden jatkaminen, klaffipoyta.gd).
	var kq := c + ax * 3.0 + f * -3.3
	klaffi_prop = Node3D.new()
	klaffi_prop.position = Vector3(kq.x, h(kq.x, kq.y), kq.y)
	klaffi_prop.rotation.y = yaw
	add_child(klaffi_prop)
	var board := B.mesh(klaffi_prop, B.boxm(Vector3(0.75, 1.15, 0.05)), Vector3(0, 0.58, 0.05), Color(0.62, 0.45, 0.26))  # kasattu levy
	board.rotation_degrees.x = 10.0
	B.mesh(klaffi_prop, B.boxm(Vector3(0.75, 0.04, 0.06)), Vector3(0, 0.1, 0.0), Color(0.4, 0.28, 0.15))
	for lx in [-0.3, 0.3]:  # teräsjalat taitettuina levyn etupuolella
		var leg := B.mesh(klaffi_prop, B.boxm(Vector3(0.04, 1.05, 0.04)), Vector3(lx, 0.55, -0.0), Color(0.55, 0.57, 0.6))
		leg.rotation_degrees.x = 10.0
	B.mesh(klaffi_prop, B.boxm(Vector3(0.8, 0.07, 0.07)), Vector3(0, 0.62, -0.02), Color(0.9, 0.5, 0.1))  # kantohihna
	doors.append({"id": "klaffipoyta", "pos": Vector3(kq.x, h(kq.x, kq.y), kq.y) - Vector3(f.x, 0, f.y) * 1.4, "out": Vector3(-f.x, 0, -f.y), "r": 3.5,
		"walk": true, "hint": "klaffipöydälle", "text": "Poimi taitettava klaffipöytä Zabukin takaseinän vierestä"})
	doors.append({"id": "zabuki", "pos": front, "out": Vector3(f.x, 0, f.y), "hint": "Zabukin tiskille (olut ja hampurilaiset)"})
	_build_race_crew(front, Vector3(f.x, 0, f.y))


## Lavan portti: lippu ostetaan portilla (main.gd ovi "portti"), portsari kiertää pihaa (portsari.gd) ja portin
## aukossa on näkymätön este, joka avataan leimalla (open_gate). Pihan teinit ryyppäävät parkkipaikan laidalla.
var gate_out := Vector3.ZERO  # portin edusta ulkona (lipunosto, ulos heitetty)
var gate_in := Vector3.ZERO
var portsari_path: Array[Vector3] = []
var yard_teens_pos := Vector3.ZERO
var _gate_block: CollisionShape3D
var _yard_lines: Array = []  # [rajaviivan piste, sisäänpäin osoittava normaali] aidan pätkittäin


func _build_lava_gate(lv: Dictionary, side: float) -> void:
	var pts: Array = lv.get("fence", [])
	if pts.size() < 2 or lv.get("gate") == null:
		return
	var lc := Vector2(lv.x, lv.z)
	for k in pts.size() - 1:
		var a := Vector2(pts[k][0], pts[k][1])
		var b := Vector2(pts[k + 1][0], pts[k + 1][1])
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		if n.dot(lc - a) < 0.0:
			n = -n
		_yard_lines.append([a, n])
	var g := Vector2(lv.gate[0], lv.gate[1])
	var gd := (Vector2(pts[1][0], pts[1][1]) - Vector2(pts[0][0], pts[0][1])).normalized()
	var inward: Vector2 = _yard_lines[0][1]
	var go := g - inward * 3.0
	var gi := g + inward * 3.0
	gate_out = Vector3(go.x, h(go.x, go.y), go.y)
	gate_in = Vector3(gi.x, h(gi.x, gi.y), gi.y)
	var body := StaticBody3D.new()
	body.position = Vector3(g.x, h(g.x, g.y), g.y)
	body.rotation.y = atan2(gd.x, gd.y)
	add_child(body)
	_gate_block = B.box_shape(Vector3(0.4, 3.0, float(lv.get("gate_w", 6.0))), Vector3(0, 1.5, 0))
	body.add_child(_gate_block)
	doors.append({"id": "portti", "pos": gate_out, "out": Vector3(-inward.x, 0, -inward.y), "r": 5.5, "hint": "portille",
		"text": "Oulujärven lava: lippu portilla"})
	# Portsarin kierros: portilta lavan ovelle, oven eteen ja pihan nurkkaan.
	var w: float = lv.w
	var l: float = lv.l
	var door := Vector2(lava_door.x, lava_door.z)
	var route: Array[Vector2] = [gi + inward * 2.0, door + Vector2(side * 4.0, -l * 0.3), door + Vector2(side * 4.0, 0),
		door + Vector2(side * 4.0, l * 0.35), door + Vector2(side * 4.0, 0), lc + Vector2(side * (w / 2.0 + 6.0), -l / 2.0 - 6.0)]
	for q in route:
		if in_lava_yard(Vector3(q.x, 0, q.y)) and not wet(q.x, q.y, 0.3):
			portsari_path.append(Vector3(q.x, h(q.x, q.y), q.y))
	# Teinit parkkipaikan laidalla: mopot, pullot ja kasettisoitin, nojailevat ja istuvat kivellä.
	var tp := door + Vector2(side * 9.0, l * 0.3)
	if not in_lava_yard(Vector3(tp.x, 0, tp.y)) or wet(tp.x, tp.y, 0.5):
		tp = door + Vector2(side * 7.0, -l * 0.15)
	yard_teens_pos = Vector3(tp.x, h(tp.x, tp.y), tp.y)
	_build_yard_teens(tp, Vector2(-side, 0))
	doors.append({"id": "pihanuoret", "pos": yard_teens_pos, "out": Vector3(-side, 0, 0), "r": 5.0, "walk": true, "hint": "teineille",
		"text": "Teinit lavan pihalla: juttele"})


## Kokko: koivuhalkojen ja risujen pino kartioksi, liekit, valo ja kipinät sekä juhlaväki ympärillä (piilossa, kunnes
## main.gd sytyttää). face = kohti järveä.
func _build_kokko(c: Vector2, face: Vector2) -> void:
	kokko_pos = Vector3(c.x, h(c.x, c.y), c.y)
	_kokko = Node3D.new()
	_kokko.position = kokko_pos
	add_child(_kokko)
	_kokko.visible = false
	for k in 16:
		var a := TAU * k / 16.0
		var lg := B.mesh(_kokko, B.cyl(0.08, 0.1, 3.2, 6), Vector3(cos(a) * 0.9, 1.3, sin(a) * 0.9),
			Color(0.9, 0.88, 0.82) if k % 3 != 0 else Color(0.4, 0.28, 0.18))
		lg.rotation = Vector3(sin(a) * 0.45, 0, -cos(a) * 0.45)
	B.mesh(_kokko, B.cyl(0.0, 1.3, 2.4, 10), Vector3(0, 1.1, 0), Color(0.3, 0.22, 0.12))  # risut sisällä
	_kokko_fire = Node3D.new()
	_kokko.add_child(_kokko_fire)
	var glow := B.unshaded(Color(1.0, 0.5, 0.1))
	for k in 6:
		var f := MeshInstance3D.new()
		f.mesh = B.boxm(Vector3(1.4 - k * 0.15, 1.6 + k * 0.3, 0.1))
		f.material_override = glow
		f.position = Vector3(0, 1.4 + k * 0.25, 0)
		f.rotation.y = k * PI / 6.0
		_kokko_fire.add_child(f)
	var li := OmniLight3D.new()
	li.light_color = Color(1.0, 0.55, 0.2)
	li.light_energy = 4.0
	li.omni_range = 22.0
	li.position = Vector3(0, 3.0, 0)
	_kokko_fire.add_child(li)
	var sparks := CPUParticles3D.new()
	sparks.amount = 60
	sparks.lifetime = 2.5
	sparks.position = Vector3(0, 3.0, 0)
	sparks.direction = Vector3.UP
	sparks.spread = 25.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 4.5
	sparks.gravity = Vector3(0, 0.5, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	sm.material = B.unshaded(Color(1.0, 0.7, 0.2))
	sparks.mesh = sm
	_kokko_fire.add_child(sparks)
	_kokko_people = Node3D.new()
	_kokko.add_child(_kokko_people)
	var looks := [
		{"shirt": Color(0.9, 0.9, 0.85), "pants": Color(0.25, 0.3, 0.45), "hair": "Hair_SimpleParted", "hair_color": Color(0.5, 0.4, 0.3), "height": 1.8},
		{"model": "female", "shirt": Color(0.95, 0.85, 0.9), "pants": Color(0.3, 0.5, 0.35), "hair": "Hair_Long", "hair_color": Color(0.85, 0.7, 0.4),
			"height": 1.66},
		{"shirt": Color(0.2, 0.4, 0.25), "pants": Color(0.2, 0.2, 0.25), "hair": "Hair_Buzzed", "beard": true, "hair_color": Color(0.4, 0.3, 0.2),
			"height": 1.76, "belly": 0.4},
		{"model": "female", "shirt": Color(0.7, 0.2, 0.25), "pants": Color(0.15, 0.15, 0.2), "hair": "Hair_Buns", "hair_color": Color(0.6, 0.55, 0.5),
			"height": 1.62},
	]
	for i in looks.size():
		var a := PI * 0.25 + i * 0.5 + atan2(-face.y, -face.x)  # rannan puolelle, kasvot kokolle
		var ch := Looks.make(_kokko_people, looks[i])
		ch.position = Vector3(cos(a) * 4.2, 0, sin(a) * 4.2)
		ch.position.y = h(c.x + ch.position.x, c.y + ch.position.z) - kokko_pos.y
		ch.rotation.y = B.yaw_to(-Vector3(cos(a), 0, sin(a)))
		ch.play("Idle_Talking" if i % 2 == 0 else "Idle", 0.0)


## Kokko näkyviin juhannuksena (pile) ja tuleen (lit).
## Veturitallin elokuvapäivien banderolli näkyviin, kun Valentin Vaala -päivät ovat (main.gd _vvaala_paiva).
func set_festari(on: bool) -> void:
	if veturitalli_banner != null:
		veturitalli_banner.visible = on


func set_kokko(pile: bool, lit: bool) -> void:
	if _kokko == null:
		return
	_kokko.visible = pile
	_kokko_fire.visible = lit
	_kokko_people.visible = lit


## Saako kohdassa kahlata (lavan aidan vesipään ympäri pummilla).
func can_wade(x: float, z: float) -> bool:
	return _wade_c != Vector2.INF and Vector2(x, z).distance_to(_wade_c) < _wade_r


## Onko kohta lavan aidan sisäpuolella (kaikkien aidan pätkien lavan puolella).
func in_lava_yard(p: Vector3) -> bool:
	if _yard_lines.is_empty():
		return false
	for ln in _yard_lines:
		if (Vector2(p.x, p.z) - (ln[0] as Vector2)).dot(ln[1]) < 0.0:
			return false
	return true


## Portin este pois (leima tai pummi pihalla) tai takaisin (heitetty ulos, uusi päivä).
func open_gate(on: bool) -> void:
	if _gate_block != null:
		_gate_block.set_deferred("disabled", on)


func _build_yard_teens(c: Vector2, face: Vector2) -> void:
	var root := Node3D.new()
	root.position = Vector3(c.x, h(c.x, c.y), c.y)
	root.rotation.y = atan2(face.x, face.y)
	add_child(root)
	var Mopo := load("res://scripts/mopo.gd")
	for k in 2:
		var mp := Node3D.new()
		mp.position = Vector3(-1.6 + k * 3.4, 0, -1.4)
		mp.rotation.y = 0.4 - k * 0.9
		root.add_child(mp)
		Mopo.build_model(mp)
		if k == 0:
			for n in mp.find_children("*", "MeshInstance3D", true, false):
				if (n as MeshInstance3D).material_override == B.mat(Color(0.72, 0.08, 0.06)):
					(n as MeshInstance3D).material_override = B.mat(Color(0.15, 0.3, 0.75))
	B.mesh(root, B.sphere(0.45, 8), Vector3(0.4, 0.2, 0.6), Color(0.5, 0.5, 0.48))  # istumakivi
	var looks := [
		{"shirt": Color(0.75, 0.75, 0.78), "pants": Color(0.25, 0.32, 0.5), "shoes": Color(0.9, 0.9, 0.9), "hair": "Hair_Buzzed",
			"hair_color": Color(0.85, 0.75, 0.5), "height": 1.74, "bulk": -0.6, "tracksuit": {"a": Color(0.1, 0.5, 0.3), "b": Color(0.85, 0.85, 0.85)}},
		{"model": "female", "shirt": Color(0.9, 0.85, 0.3), "pants": Color(0.12, 0.12, 0.15), "shoes": Color(0.15, 0.15, 0.15), "hair": "Hair_Long",
			"hair_color": Color(0.3, 0.18, 0.1), "height": 1.63, "bulk": -0.6},
		{"shirt": Color(0.12, 0.12, 0.14), "pants": Color(0.3, 0.3, 0.33), "shoes": Color(0.2, 0.2, 0.2), "hair": "Hair_SimpleParted",
			"hair_color": Color(0.12, 0.1, 0.08), "height": 1.8, "bulk": -0.7},
	]
	var spots := [[Vector3(-0.9, 0, 0.3), "Idle_Talking", Vector3(1, 0, 0.2)], [Vector3(0.4, 0.42, 0.6), "Sitting_Talking", Vector3(-0.3, 0, -1)],
		[Vector3(1.4, 0, 0.0), "Idle", Vector3(-1, 0, 0.3)]]
	for i in looks.size():
		var ch := Looks.make(root, looks[i])
		ch.position = spots[i][0]
		ch.rotation.y = B.yaw_to(spots[i][2])
		ch.play(spots[i][1], 0.0)
		if i == 2:
			Looks.add_cap(ch)
		party_people.append(ch)
	for q in [Vector3(-0.5, 0.12, 1.0), Vector3(0.9, 0.12, 1.1), Vector3(1.8, 0.05, 0.7), Vector3(-1.3, 0.05, 0.9)]:
		B.mesh(root, B.cyl(0.04, 0.05, 0.25, 8), q, Color(0.25, 0.45, 0.25) if q.y > 0.1 else Color(0.85, 0.85, 0.9))
	var bb := B.mesh(root, B.boxm(Vector3(0.5, 0.22, 0.14)), Vector3(0.0, 0.11, 1.4), Color(0.12, 0.12, 0.14))  # kasettisoitin
	var mus := AudioStreamPlayer3D.new()
	var st90: AudioStream = load("res://scripts/headphones.gd").random_90s()
	if st90 != null:
		mus.stream = st90
		mus.bus = "Music"
		mus.volume_db = -14.0
		mus.unit_size = 3.0
		mus.max_distance = 28.0
		mus.autoplay = true
		bb.add_child(mus)
	var body := StaticBody3D.new()
	root.add_child(body)
	body.add_child(B.box_shape(Vector3(1.0, 0.5, 1.0), Vector3(0.4, 0.25, 0.6)))


## Mopopojat Zabukin pihassa (kiihdytyskisan haastajat, mopo_race.gd): kaksi mopoa ja kaksi poikaa nojailemassa.
var race_spot := Vector3.ZERO


func _build_race_crew(front: Vector3, out: Vector3) -> void:
	var side := out.cross(Vector3.UP)
	var c := front + side * 7.0 + out * 1.5
	c.y = h(c.x, c.z)
	race_spot = c
	var Mopo := load("res://scripts/mopo.gd")
	for k in 2:
		var mp := Node3D.new()
		mp.position = c + side * (k * 1.6 - 0.8) + out * 1.2
		mp.position.y = h(mp.position.x, mp.position.z)
		mp.rotation.y = atan2(-out.x, -out.z) + 0.25 - k * 0.5
		add_child(mp)
		Mopo.build_model(mp)
		if k == 1:
			for n in mp.find_children("*", "MeshInstance3D", true, false):
				if (n as MeshInstance3D).material_override == B.mat(Color(0.72, 0.08, 0.06)):
					(n as MeshInstance3D).material_override = B.mat(Color(0.85, 0.72, 0.08))
	var looks := [{"shirt": Color(0.1, 0.35, 0.6), "pants": Color(0.25, 0.32, 0.5), "shoes": Color(0.9, 0.9, 0.9), "hair": "Hair_Buzzed",
		"hair_color": Color(0.7, 0.55, 0.3), "height": 1.76, "bulk": -0.6, "shoulders": -0.5, "tracksuit": {"a": Color(0.9, 0.2, 0.3), "b": Color(0.1, 0.35, 0.6)}},
		{"shirt": Color(0.12, 0.12, 0.14), "pants": Color(0.2, 0.22, 0.3), "shoes": Color(0.15, 0.15, 0.15), "hair": "Hair_Long",
		"hair_color": Color(0.2, 0.15, 0.1), "height": 1.8, "bulk": -0.7}]
	for k in 2:
		var ch := Looks.make(self, looks[k])
		ch.position = c + side * (k * 2.4 - 1.2) - out * 0.4
		ch.position.y = h(ch.position.x, ch.position.z)
		ch.rotation.y = B.yaw_to(out + side * (0.4 - k * 0.8))
		ch.play("Idle_Talking" if k == 0 else "Idle", 0.0)
		if k == 1:
			Looks.add_cap(ch)
	doors.append({"id": "kiihdytys", "pos": c, "out": out, "r": 5.0, "hint": "kiihdytykseen",
		"text": "Mopopojat: kiihdytyskisa Vaalantiellä"})


## Kiihdytysrata: Vaalantien suorin 170 m pätkä Zabukin lähellä (ei siltaa eikä soraa), keskiviiva maastossa.
func race_track(length := 170.0) -> Array[Vector3]:
	var best: Array[Vector3] = []
	var best_dev := INF
	var near := Vector2(race_spot.x, race_spot.z)
	for i in range(1, road.size() - 2, 2):
		if Vector2(road[i][0], road[i][2]).distance_to(near) > 700.0:
			continue
		var pts: Array[Vector3] = [road_pos(i)]
		var dist := 0.0
		var ok := true
		var j := i
		while dist < length and j < road.size() - 1:
			j += 1
			if road[j][5] or road[j][6]:
				ok = false
				break
			dist += road_pos(j - 1).distance_to(road_pos(j))
			pts.append(road_pos(j))
		if not ok or dist < length:
			continue
		var a := Vector2(pts[0].x, pts[0].z)
		var b := Vector2(pts[-1].x, pts[-1].z)
		var dev := 0.0
		for q in pts:
			dev = maxf(dev, Geometry2D.get_closest_point_to_segment(Vector2(q.x, q.z), a, b).distance_to(Vector2(q.x, q.z)))
		dev += Vector2(pts[0].x, pts[0].z).distance_to(near) * 0.004  # lähempää parempi
		if dev < best_dev:
			best_dev = dev
			best = pts
	return best


## Gasthaus: kyltti ja ovi tien (Siitarin) puoleiselle pitkälle sivulle, "Huoneet 10 €" oven pieleen.
func _gasthaus_front(obb: Dictionary, base: float, top: float) -> void:
	var c: Vector2 = obb.center
	var side := _gasthaus_side(obb)
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
	# Kyltit oven pieleen: ovilehden kehys on 1,2 m leveä (_door_mesh), joten levyn sisäreuna 0,12 m kehyksen ulkopuolelle.
	# dx = oven paikallinen +X (Basis(UP, yaw).x); levyn keskipiste = 0,6 + 0,12 + leveys / 2.
	var dx := Vector2(cos(yaw), -sin(yaw))
	var pq := dq + dx * (0.72 + float(price.get_meta("width")) / 2.0) + side * 0.08
	price.position = Vector3(pq.x, y + 1.6, pq.y)
	price.rotation.y = yaw
	# Ruokalista HUONEET-kyltin alla (teksti main.gd GASTHAUS_MENU:stä, hinnat samat)
	var menu := B.sign_plate(self, "RUOKALISTA\nKalakeitto 9,50\nKukkoleipä 7,00\nTalkkuna 4,00\nRieska 3,50",
		Color(0.95, 0.93, 0.86), Color(0.16, 0.24, 0.16), 0.2, 30, Color(0.16, 0.24, 0.16), "Georgia")
	var mq := dq + dx * (0.72 + float(menu.get_meta("width")) / 2.0) + side * 0.08
	menu.position = Vector3(mq.x, y + 0.75, mq.y)
	menu.rotation.y = yaw
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


## storey > 0: julkisivuun sokkeli ja kerrosvälien listat (facade.gdshader UV:stä).
func _prism(pts: PackedVector2Array, y0: float, y1: float, col: Color, kind := WOOD, storey := 0.0) -> void:
	_walls.set_color(Color(col.r, col.g, col.b, kind))
	_walls.set_uv(Vector2(y0, storey))
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		_quad(_walls, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y))


const BIG_AREA := 450.0  # tätä suuremmat pohjat kutistetaan (_build_buildings)


## Sivuteiden ja polkujen janat 20 m ruudukossa (vajojen karsinta).
func _side_road_grid() -> Dictionary:
	var g := {}
	for r in data.side_roads:
		if r.kind == "rail" or r.pts.size() < 2:
			continue
		for k in r.pts.size() - 1:
			var a := Vector2(r.pts[k][0], r.pts[k][1])
			var b := Vector2(r.pts[k + 1][0], r.pts[k + 1][1])
			var lo := Vector2i(floori(minf(a.x, b.x) / 20.0), floori(minf(a.y, b.y) / 20.0))
			var hi := Vector2i(floori(maxf(a.x, b.x) / 20.0), floori(maxf(a.y, b.y) / 20.0))
			for j in range(lo.y, hi.y + 1):
				for i in range(lo.x, hi.x + 1):
					if not g.has(Vector2i(i, j)):
						g[Vector2i(i, j)] = []
					g[Vector2i(i, j)].append([a, b])
	return g


func _on_side_road(pts: PackedVector2Array, grid: Dictionary) -> bool:
	for q in pts:
		for sg in grid.get(Vector2i(floori(q.x / 20.0), floori(q.y / 20.0)), []):
			if Geometry2D.get_closest_point_to_segment(q, sg[0], sg[1]).distance_to(q) < 1.6:
				return true
	# Polku voi kulkea myös vajan läpi ilman kulmaa lähellä: keskipiste.
	var c := Vector2.ZERO
	for q in pts:
		c += q
	c /= pts.size()
	for sg in grid.get(Vector2i(floori(c.x / 20.0), floori(c.y / 20.0)), []):
		if Geometry2D.get_closest_point_to_segment(c, sg[0], sg[1]).distance_to(c) < 3.0:
			return true
	return false


## Kulkeeko jokin sivutie tai polku pohjan läpi (yli 3 m pohjan sisällä)?
func _crossed_by_road(pts: PackedVector2Array, grid: Dictionary) -> bool:
	var lo := pts[0]
	var hi := pts[0]
	for q in pts:
		lo = lo.min(q)
		hi = hi.max(q)
	var seen := {}
	for j in range(floori(lo.y / 20.0), floori(hi.y / 20.0) + 1):
		for i in range(floori(lo.x / 20.0), floori(hi.x / 20.0) + 1):
			for sg in grid.get(Vector2i(i, j), []):
				var key := str(sg)
				if seen.has(key):
					continue
				seen[key] = true
				var inside := 0.0
				for part in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([sg[0], sg[1]]), pts):
					for k in part.size() - 1:
						inside += part[k].distance_to(part[k + 1])
				if inside > 3.0:
					return true
	return false


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
## size = ikkunan koko suhteessa perusikkunaan (1,1 x 1,3 m): isot ikkunat rikkovat laajat seinäpinnat.
func _windows(pts: PackedVector2Array, y0: float, levels: int, wall_h := 3.2, shop := false, door := Vector2(INF, INF),
		size := Vector2.ONE, door_r := 1.4, door2 := Vector2(INF, INF)) -> void:
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
		var sy := minf(size.y, storey * 0.62 / 1.3)
		var basis := Basis(Vector3.UP, atan2(out.x, out.y)) * Basis.from_scale(Vector3(size.x, sy, 1.0))
		var n := int(L / (1.4 + 1.3 * size.x))
		for lv in levels:
			if shop and lv == 0 and L > 8.0:
				var m := int(L / 3.2)
				for w in m:
					var q := a + dir * (L * (w + 0.5) / m) + out * 0.04
					var sb := Basis(Vector3.UP, atan2(out.x, out.y))
					_shop_frames.append(Transform3D(sb, Vector3(q.x, y0 + 1.4, q.y)))
					_shop_glass.append(Transform3D(sb, Vector3(q.x, y0 + 1.4, q.y) + Vector3(out.x, 0, out.y) * 0.02))
				continue
			for w in n:
				var q := a + dir * (L * (w + 0.5) / n) + out * 0.04
				if lv == 0 and (q.distance_to(door) < door_r or q.distance_to(door2) < 1.4):
					continue
				var xf := Transform3D(basis, Vector3(q.x, y0 + minf(1.5, storey * 0.55) + lv * storey + 0.1 * (sy - 1.0), q.y))
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
	_prism(pts, base, base + wall_h, wood, WOOD, wall_h)
	_gable(obb, base + wall_h, 2.4, Color(0.2, 0.2, 0.22), wood, WOOD, SEAM_ROOF)
	var cs := B.box_shape(Vector3(obb.size.x, wall_h + 3.0, obb.size.y), Vector3.ZERO)
	cs.transform = Transform3D(Basis(Vector3.UP, -obb.angle), Vector3(obb.center.x, base + wall_h / 2.0, obb.center.y))
	body.add_child(cs)
	_bld_polys.append(pts)  # pohja ajoalueen ulkopuolelle (_clear_buildings)
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
	# Takasivulle (pysäköinti) keittiön ja salin ikkunat ja takapäätyyn kaksi: ei umpiseinää.
	var wb := Basis(Vector3.UP, atan2(-front.x, -front.y)) * Basis.from_scale(Vector3(1.4, 1.2, 1.0))
	var nu := int((hx * 2.0 - 3.0) / 3.4)
	for k in nu:
		var u := -hx + 1.5 + (k + 0.5) * (hx * 2.0 - 3.0) / nu
		var xf := Transform3D(wb, at.call(u, -hy - 0.04, 1.9))
		_win_frames.append(xf)
		_win_glass.append(xf.translated_local(Vector3(0, 0, 0.01)))
		_win_mull.append(xf.translated_local(Vector3(0, 0, 0.02)))
	var eb := Basis(Vector3.UP, atan2(-ax.x, -ax.y)) * Basis.from_scale(Vector3(1.3, 1.2, 1.0))
	for v in [-hy * 0.5, hy * 0.5]:
		var q2: Vector2 = c - ax * (hx + 0.04) + front * v
		var xf := Transform3D(eb, Vector3(q2.x, base + 1.9, q2.y))
		_win_frames.append(xf)
		_win_glass.append(xf.translated_local(Vector3(0, 0, 0.01)))
		_win_mull.append(xf.translated_local(Vector3(0, 0, 0.02)))
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
	_siitari_lot(c, ax, front, hx, hy)


## Parkkipaikka Siitarin eteen, terassin ja Vaalantien väliin: autopaikkarivi (nokka rakennukseen päin) ja ajokaista,
## valkoiset ruutuviivat, P-kyltti ja muutaman asiakkaan auto. Syvyys sovitetaan terassin ja tien väliin (nearest).
## Polygoni lisätään data.parkings-listaan, jotta ajoalue (mopo) kattaa sen; mopon paikka (siitari_park) on päädyssä.
const LOT_BAY_W := 2.6
const LOT_BAY_D := 5.0
const LOT_MAX_CARS := 3  # Siitarin ja K-Marketin pihoilla vain muutama auto


func _siitari_lot(c: Vector2, ax: Vector2, front: Vector2, hx: float, hy: float) -> void:
	var v0 := hy + 5.6  # terassin kaiteen takaa
	var fw := c + front * (hy + 8.0)
	var ni: Array = nearest(Vector3(fw.x, 0, fw.y))
	var road_hw: float = road[ni[0]][4]
	# ni[1] = etäisyys tien keskiviivaan pisteestä hy + 8; tilaa v0:sta tien reunaan:
	var avail: float = (ni[1] as float) - road_hw - 1.2 + (hy + 8.0 - v0)
	var aisle := clampf(avail - LOT_BAY_D, 0.0, 6.0)
	var ua := -hx - 1.0
	var nb := int((hx * 2.0 + 5.0) / LOT_BAY_W)
	_lot_build(c, ax, front, ua, nb, v0, aisle, [])


## Merkitty parkkipaikka: asfaltti, ruutuviivat, autot (ohita = paikat, jotka jätetään tyhjiksi, [Vector2]) ja P-kyltti.
## Paikallinen kehys: u = ax-suunta, v = front-suunta (rakennuksesta pois); rivi alkaa v0:sta ja ajokaista on rivin takana.
func _lot_build(c: Vector2, ax: Vector2, front: Vector2, ua: float, nb: int, v0: float, aisle: float, skip: Array,
		gravel := false) -> Array[Vector2]:
	var ub := ua + nb * LOT_BAY_W
	var v1 := v0 + LOT_BAY_D + aisle
	var q := func(u: float, v: float) -> Vector2: return c + ax * u + front * v
	var poly := PackedVector2Array([q.call(ua, v0), q.call(ub, v0), q.call(ub, v1), q.call(ua, v1)])
	var arr: Array = []
	for pt in poly:
		arr.append([pt.x, pt.y])
	data.parkings.append(arr)
	var asph := SurfaceTool.new()
	asph.begin(Mesh.PRIMITIVE_TRIANGLES)
	_poly_surface(asph, poly, LIFT_ASPHALT)
	var mi := MeshInstance3D.new()
	mi.mesh = asph.commit()
	mi.material_override = _surf_mat("gravel" if gravel else "asphalt")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := func(a: Vector2, b: Vector2) -> void: _ribbon(lines, PackedVector2Array([a, b]), 0.06, LIFT_DASH)
	for k in nb + 1:
		seg.call(q.call(ua + k * LOT_BAY_W, v0), q.call(ua + k * LOT_BAY_W, v0 + LOT_BAY_D))
	seg.call(q.call(ua, v0 + LOT_BAY_D), q.call(ub, v0 + LOT_BAY_D))
	if not gravel:  # soralla ei ruutuviivoja
		var lm := MeshInstance3D.new()
		lm.mesh = lines.commit()
		lm.material_override = _surf_mat("dash")
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lm)
	var cols := [Color(0.5, 0.12, 0.1), Color(0.2, 0.3, 0.45), Color(0.75, 0.75, 0.72), Color(0.18, 0.2, 0.2), Color(0.55, 0.5, 0.3)]
	var yaw := rad_to_deg(atan2(front.x, front.y))
	var n := 0
	var placed: Array[Vector2] = []
	for k in nb:
		if n >= LOT_MAX_CARS:
			break
		if (k * 7 + 3) % 5 < 2:
			continue  # jokin paikka vapaa
		var cp: Vector2 = q.call(ua + (k + 0.5) * LOT_BAY_W, v0 + LOT_BAY_D / 2.0)
		if skip.any(func(sp: Vector2) -> bool: return sp.distance_to(cp) < 2.0):
			continue
		B.parked_car(self, Vector3(cp.x, h(cp.x, cp.y) + 0.1, cp.y), yaw + 180.0 + (3.0 if k % 2 == 0 else -2.0), cols[n % cols.size()])
		placed.append(cp)
		n += 1
	var pp: Vector2 = q.call(ua - 0.8, v0 + 0.5)
	var pole := B.sign_pole(self, Vector3(pp.x, h(pp.x, pp.y), pp.y), 2.3)
	var plate := B.sign_plate(pole, "P", Color(0.0, 0.3, 0.6), Color.WHITE, 0.5, 70, Color(0.95, 0.95, 0.95), "Helvetica Neue")
	plate.position.y = 2.0
	plate.rotation.y = atan2(front.x, front.y)
	print("VAALA parkki: %d paikkaa, %d autoa, kaista %.1f m" % [nb, n, aisle])
	return placed


## K-Marketin piha (kuten Saloisissa): merkitty parkkipaikka kadun puolella, penkin mummot ja rollaattorimummo oven vieressä
## sekä taksitolppa parkin Siitarista kauimmaisessa päässä (kuski ratissa, radio). Ovi "vtaksi": taksivalikko (main.gd).
var vtaxi_pos := Vector3.ZERO
var mummot: Node3D


func _build_kmarket_yard() -> void:
	if kmarket_door == Vector3.ZERO:
		return
	var c := Vector2(kmarket_center.x, kmarket_center.z)
	var ax := Vector2(kmarket_along.x, kmarket_along.z)
	var front := Vector2(kmarket_face.x, kmarket_face.z)
	var hx := kmarket_half.x
	var hy := kmarket_half.y
	var to_siitari := siitari - c
	var side := 1.0 if ax.dot(to_siitari) >= 0.0 else -1.0  # Siitarin puoli (pankkiautomaatti)
	var v0 := hy + 2.4
	var probe := c + front * (hy + 8.0)
	var ni: Array = nearest(Vector3(probe.x, 0, probe.y))
	var avail: float = (ni[1] as float) - float(road[ni[0]][4]) - 1.2 + (hy + 8.0 - v0)
	var aisle := clampf(avail - LOT_BAY_D, 0.0, 6.0)
	var ua := -hx - 1.0
	var nb := int((hx * 2.0 + 2.0) / LOT_BAY_W)
	# Taksin paikka: rivin Siitarista kauimmainen pää.
	var tk: int = 0 if side > 0.0 else nb - 1
	var tu := ua + (tk + 0.5) * LOT_BAY_W
	var tp := c + ax * tu + front * (v0 + LOT_BAY_D / 2.0)
	_lot_build(c, ax, front, ua, nb, v0, aisle, [tp])
	var yaw := atan2(front.x, front.y)
	# Taksi paikallaan, tolppa ja TAKSI-kyltti (kuten world.gd _build_taxi).
	var tpos := Vector3(tp.x, h(tp.x, tp.y) + 0.1, tp.y)
	var pole := B.sign_pole(self, tpos + Vector3(ax.x, 0, ax.y) * (-side * 1.9) , 2.9)
	var plate := B.sign_plate(pole, "TAKSI", Color(1.0, 0.8, 0.1), Color(0.05, 0.05, 0.05), 0.34, 64, Color(0.05, 0.05, 0.05), "Helvetica Neue")
	plate.position = Vector3(plate.get_meta("width") / 2.0 + 0.04, 2.55, 0)
	plate.rotation.y = yaw
	var body := StaticBody3D.new()
	body.position = tpos
	body.rotation.y = yaw + PI
	add_child(body)
	body.add_child(B.box_shape(Vector3(1.8, 1.4, 4.2), Vector3(0, 0.8, 0)))
	load("res://scripts/vehicles.gd").taxi(body, "TXI-808")
	var driver := Looks.make(body, Looks.TAXI_DRIVER)
	driver.position = Vector3(-0.4, 0.05, 0.1)
	driver.play("Driving", 0.0)
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
	# Ovi taksin viereen (kuljettajan puolelle, parkin ajokaistalle päin).
	var dp := tp + front * (LOT_BAY_D / 2.0 + 1.2)
	vtaxi_pos = Vector3(dp.x, h(dp.x, dp.y), dp.y)
	doors.append({"id": "vtaksi", "pos": vtaxi_pos, "out": Vector3(-front.x, 0, -front.y), "r": 6.0, "walk": true,
		"text": "Taksille: Raahe, retket ja koti"})
	# Mummot penkillä ja rollaattorin kanssa seinustalla, oven toisella puolella kuin taksi.
	var door_u := (Vector2(kmarket_door.x, kmarket_door.z) - c).dot(ax)
	var mu := clampf(door_u + (-7.0 if door_u > 0.0 else 7.0), -hx + 4.0, hx - 4.0)
	var mq := c + ax * mu + front * (hy + 0.7)
	mummot = Mummot.new()
	mummot.position = Vector3(mq.x, h(mq.x, mq.y), mq.y)
	mummot.rotation.y = yaw
	add_child(mummot)


func _build_parkings() -> void:
	for poly in data.parkings:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(Vector2(q[0], q[1]))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_surface(st, pts, LIFT_ASPHALT)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _surf_mat("asphalt")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


## Vaalan keskusta harvemmaksi (Siitarin, torin, kunnanviraston ja kirkon seutu): laserkeilauksen pihapuut ja
## metsiköt peittivät taajaman, joten keskellä puista jää TOWN_THIN_KEEP ja reunaa kohti enemmän.
const TOWN_THIN_C := Vector2(800.0, -960.0)
const TOWN_THIN_R := 300.0
const TOWN_THIN_KEEP := 0.15
## Mäntymetsä metsäruuduille (ei tien, pihojen eikä radan viereen), koivuja pihoille; puille törmäys tien lähellä.
## Metsä oikeista puista: MML:n laserkeilaus (paikka, pituus, latvus) ja Luken VMI (laji) tien suhteen pelin
## kehykseen, tiivistetyllä välillä harvennettuna (tools/vaala_bake.py -> assets/vaala/puut.bin, forest.gd).
func _build_trees() -> void:
	var f := Forest.new()
	add_child(f)
	var clear := {"thin": {"c": TOWN_THIN_C, "r": TOWN_THIN_R, "keep": TOWN_THIN_KEEP}}
	if not _tree_clear.is_empty():
		clear.merge({"mask": _tree_clear, "x0": _x0, "z0": _z0, "cell": DRIVE_CELL, "nx": _dnx, "nz": _dnz})
	f.load_data(TREES, clear)


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
## Salmisentie: laavun ja tynnyrisaunan pihasta Taka-Salmisen pohjoisrantaa (tasaista metsää, 11-14 m järven pohjoispuolella)
## Nuojuankoskentien päähän uimarannan kohdalle: yhdessä Keskimmäisentien kanssa kierros Salmisen ympäri. Suora ja tasainen,
## ja soraa kuten Keskimmäisentie (testi `--scene=vaala_ajo --ajo=tiet --kohdat=-250,-445`).
const SALMINEN_ROAD := [Vector2(-135, -446), Vector2(-200, -448), Vector2(-270, -445), Vector2(-320, -443), Vector2(-345, -439)]
const LAAVU_ROAD := [Vector2(-22, -280), Vector2(-40, -320), Vector2(-62, -360), Vector2(-82, -395), Vector2(-95, -425)]
const NORTH_ASPHALT_HALF := 4.0
const NORTH_GRAVEL_HALF := 2.6
const NORTH_SPUR_HALF := 2.6
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
		# Salmisentie: pihan takaa länteen ja Nuojuankoskentien päähän (asfaltin viimeinen piste).
		var sg: Array = [end]
		sg.append_array(SALMINEN_ROAD)
		sg.append(asphalt[-1])
		north_roads.append({"pts": _smooth_line(sg), "half": NORTH_GRAVEL_HALF, "asphalt": false, "name": "Salmisentie"})
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


## Lisää puita Salmisten (Etu- ja Taka-Salminen sekä niiden lähin lampi) ympärille: rantaviivan jokaisesta ruudusta kasvaa
## ulospäin (poispäin järvestä) koivuja, mäntyjä, kuusia ja pensaita; rannassa matalampaa (pajua, koivua), kauempana
## havupuita. Teiden, raivattujen pihojen (_tree_clear) ja veden päälle ei istuteta. Siemen kiinteä: sama metsä joka kerta.
const SALMINEN_LAKES := ["Etu-Salminen", "Taka-Salminen", "Pyöriäinen"]
const SALMINEN_PER_SHORE := 9
const SALMINEN_REACH := Vector2(3.0, 48.0)  # etäisyys rannasta (m)


func _build_salminen_trees() -> void:
	var centres: Array = []
	for nl in data.get("north_lakes", []):
		if nl.name in SALMINEN_LAKES:
			centres.append(Vector2(nl.c[0], nl.c[1]))
	if centres.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5171
	var trees: Array = []
	for c: Vector2 in centres:
		# Rantaruudut: vesiruutu, jonka vieressä on maata, järven keskipisteen ympäriltä (kolme tiheää jaksoa).
		var shore: Array[Vector2] = []
		var r := 110.0
		for j in range(maxi(int((c.y - r - _z0) / _cell), 0), mini(int((c.y + r - _z0) / _cell), _nz - 1) + 1):
			for i in range(maxi(int((c.x - r - _x0) / _cell), 0), mini(int((c.x + r - _x0) / _cell), _nx - 1) + 1):
				var q := j * _nx + i
				if _codes[q] != WATER:
					continue
				var edge := false
				for o in [-1, 1]:
					if _codes[q + o] != WATER or _codes[q + o * _nx] != WATER:
						edge = true
				if edge:
					shore.append(Vector2(_x0 + i * _cell, _z0 + j * _cell))
		for sp: Vector2 in shore:
			var out := (sp - c).normalized()
			for k in SALMINEN_PER_SHORE:
				var d := out.rotated(rng.randf_range(-1.1, 1.1)) * rng.randf_range(SALMINEN_REACH.x, SALMINEN_REACH.y)
				var p := sp + d
				if code_at(p.x, p.y) in [WATER, ROAD, SHOULDER, RAIL, OUTSIDE] or wet(p.x, p.y, 0.15):
					continue
				var ci := _dcell(p)
				if ci >= 0 and not _tree_clear.is_empty() and _tree_clear[ci] == 1:
					continue
				var near_road := false
				for rd in north_roads:
					var pts: PackedVector2Array = rd.pts
					for m in range(0, pts.size() - 1):
						if Geometry2D.get_closest_point_to_segment(p, pts[m], pts[m + 1]).distance_to(p) < float(rd.half) + 4.0:
							near_road = true
							break
					if near_road:
						break
				if near_road:
					continue
				var shore_d := d.length()
				var roll := rng.randf()
				var kind: int
				if shore_d < 9.0:
					kind = Forest.BUSH if roll < 0.45 else Forest.BIRCH
				else:
					kind = Forest.BIRCH if roll < 0.3 else (Forest.PINE if roll < 0.65 else (Forest.SPRUCE if roll < 0.9 else Forest.BUSH))
				var hh := rng.randf_range(1.2, 2.6) if kind == Forest.BUSH else rng.randf_range(8.0, 15.0) * (0.75 if shore_d < 9.0 else 1.0)
				trees.append({"pos": Vector3(p.x, h(p.x, p.y), p.y), "h": hh, "sp": kind})
	if trees.is_empty():
		return
	var f := Forest.new()
	f.name = "SalmisenPuut"
	add_child(f)
	f.load_list(trees, 91)
	print("VAALA Salmisen puut: %d" % trees.size())


## Tienpinnat, opaste ja kohteet (mökin rakennusfunktioilla, ankkuroituna T:n kuvaamaan pisteeseen).
func _build_north() -> void:
	if north_roads.is_empty():
		return
	var M: GDScript = load(MOKKI_PATH)
	var sts := {}
	for kind in ["asphalt", "shoulder", "dash", "gravel"]:
		sts[kind] = SurfaceTool.new()
		sts[kind].begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in north_roads:
		var pts: PackedVector2Array = r.pts
		var half: float = r.half
		if r.asphalt:
			_ribbon(sts.shoulder, pts, half + ROAD_SHOULDER, LIFT_SHOULDER)
			_ribbon(sts.asphalt, pts, half, LIFT_ASPHALT)
			_dashes(sts.dash, pts, LIFT_DASH)
		else:
			_ribbon(sts.gravel, pts, half, LIFT_GRAVEL)
	for kind in sts:
		var st: SurfaceTool = sts[kind]
		if _st_empty(st):
			continue
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "JarviseudunTiet"
		mi.mesh = st.commit()
		mi.material_override = _surf_mat(kind)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	# Opaste soratien alkuun: laavu.
	var grs := north_roads.filter(func(r: Dictionary) -> bool: return r.name == "Keskimmäisentie")
	if not grs.is_empty() and grs[0].pts.size() > 6:
		var gr: Dictionary = grs[0]
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
	# Pihan läpi ja ohi kulkevat OSM-tiet ja polut (mopolla ajettavia): männyt eivät kasva niillä.
	var near_segs: Array = []
	var yc := c
	for r in data.side_roads:
		if r.kind == "rail" or r.pts.size() < 2:
			continue
		for k in r.pts.size() - 1:
			var a := Vector2(r.pts[k][0], r.pts[k][1])
			var b := Vector2(r.pts[k + 1][0], r.pts[k + 1][1])
			if Geometry2D.get_closest_point_to_segment(yc, a, b).distance_to(yc) < 160.0:
				near_segs.append([a, b])
	var on_path := func(g: Vector3) -> bool:
		var q := Vector2(g.x, g.z)
		for sg in near_segs:
			if Geometry2D.get_closest_point_to_segment(q, sg[0], sg[1]).distance_to(q) < 4.5:
				return true
		return false
	for tp in MokkiScript.YARD_PINES:
		var g: Vector3 = to_vaala.call(Vector3(tp.x, 0, tp.y))
		if on_path.call(g):
			continue
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
		if ni[0] >= 0 and ni[1] < float(road[ni[0]][4]) + 4.0 or on_path.call(g):
			continue
		trees.append({"pos": Vector3(lp.x, g.y, lp.z), "h": rng.randf_range(10.0, 17.0), "sp": Forest.PINE})
	var forest := Forest.new()
	forest.name = "PihanMannikko"
	yard.add_child(forest)
	forest.load_list(trees)
	# Mopon lähtöpaikka: sama kuin mökin parkkipaikka (mokki.gd _build_mopo: kierto PI * 0.9 mökin kehyksessä).
	mokki_mopo = to_vaala.call(MokkiScript.MOPO_LOCAL)
	mokki_mopo_yaw = PI * 0.9 + rot



## Vaalan Veturitalli (#250 P14): punatiilinen vaja aseman päädyssä tien puolella. Paikallinen +Z = vajan etupuoli (tielle),
## ovi etuseinässä. Harjakaton molemmat lappeet lasketaan samasta kaltevuudesta. Valentin Vaala -päivinä ovella banderolli.
func _build_veturitalli(station_c: Vector2, along: Vector2, out2: Vector2, L: float, D: float) -> void:
	# Ulos asti 6 m lisää: viereisen rakennuksen (n. 7 m syvä, tiedossa -3,3 m asti vajan keskeltä) ja räystään taakse jää tilaa.
	var q := station_c + along.normalized() * (L / 2.0 + 11.0) + out2 * (D / 2.0 + 8.0)
	var yaw := atan2(out2.x, out2.y)
	var root := Node3D.new()
	root.position = Vector3(q.x, h(q.x, q.y), q.y)
	root.rotation.y = yaw
	add_child(root)
	var W := 12.0
	var Dp := 8.0
	var wall := 4.8
	var brick := Color(0.55, 0.22, 0.16)
	var body := B.box(root, Vector3(W, wall, Dp), Vector3(0, wall / 2.0, 0), brick)
	body.name = "Veturitalli"
	# Katto: kaltevuus a, lappeen pituus hw / cos(a); +Z-lappeen ja -Z-lappeen kallistus samasta a:sta.
	var a := deg_to_rad(24.0)
	var hw := Dp / 2.0 + 0.6
	var slope := hw / cos(a)
	for s in [1.0, -1.0]:
		var r := B.mesh(root, B.boxm(Vector3(W + 1.0, 0.18, slope)), Vector3(0, wall + hw * tan(a) / 2.0 + 0.05, s * hw / 2.0),
			Color(0.2, 0.2, 0.22))
		r.rotation.x = a * s
	# Suuri vetoovi etuseinässä (kaksi lehteä) ja ovi-ikkunat.
	var front := Dp / 2.0 + 0.04
	B.mesh(root, B.boxm(Vector3(3.6, 3.2, 0.08)), Vector3(0, 1.6, front), Color(0.28, 0.2, 0.14))
	B.mesh(root, B.boxm(Vector3(0.1, 3.2, 0.1)), Vector3(0, 1.6, front + 0.05), Color(0.12, 0.1, 0.08))
	for sx in [-4.2, 4.2]:
		B.mesh(root, B.boxm(Vector3(1.5, 1.1, 0.08)), Vector3(sx, 2.2, front), Color(0.85, 0.8, 0.55))
	var plate := B.sign_plate(root, "VAALAN VETURITALLI", Color(0.16, 0.12, 0.1), Color(0.97, 0.9, 0.7), 1.1, 150,
		Color(0.8, 0.65, 0.3), "Georgia")
	plate.position = Vector3(0, wall - 0.65, front + 0.1)
	plate.rotation.x = deg_to_rad(-12.0)  # kallistus kameraan (pelikamera katsoo ylhäältä)
	var banner := B.sign_plate(root, "VALENTIN VAALA -ELOKUVAPÄIVÄT\nEsityksiä klo 13-17", Color(0.95, 0.93, 0.86), Color(0.5, 0.1, 0.1), 0.5, 60,
		Color(0.5, 0.1, 0.1), "Georgia")
	# Banderolli seisoo kahden tolpan välissä vajan vieressä, jottei ovi peity.
	var bw: float = banner.get_meta("width")
	banner.position = Vector3(W / 2.0 + 1.0 + bw / 2.0, 2.4, front + 1.5)
	for sx in [-1.0, 1.0]:
		B.mesh(banner, B.boxm(Vector3(0.12, 2.4, 0.12)), Vector3(sx * (bw / 2.0 - 0.1), -1.2, 0), Color(0.3, 0.22, 0.14))
	banner.visible = false
	veturitalli_banner = banner
	# Puut pois vajan edestä (kyltti ja ovi näkyvät pelikameralle 14 m päästä): piha vajasta 16 m ulospäin.
	if not _tree_clear.is_empty():
		var yard := PackedVector2Array()
		for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var yq := root.transform * Vector3(k.x * (W / 2.0 + 3.0), 0, -Dp / 2.0 if k.y < 0 else Dp / 2.0 + 16.0)
			yard.append(Vector2(yq.x, yq.z))
		var keep := _drive
		_drive = _tree_clear  # piirtoapurit kirjoittavat _driveen
		_drive_poly(yard, 2.0)
		_tree_clear = _drive
		_drive = keep
	var out := Vector3(out2.x, 0, out2.y)
	var dq := q + out2 * (Dp / 2.0 + 2.2)
	veturitalli_door = Vector3(dq.x, h(dq.x, dq.y), dq.y)
	doors.append({"id": "veturitalli", "pos": veturitalli_door, "out": out, "hint": "Veturitalliin", "text": "Veturitalli: elokuvaesitys"})
