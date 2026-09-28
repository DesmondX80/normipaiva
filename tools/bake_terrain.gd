extends SceneTree
## Leipoo maaston: korkeusmalli (assets/terrain/korkeus.json, Copernicus DEM ~90 m) -> 5 m ruudukko
## assets/terrain/korkeus.bin, järvet tasoitettuina; sekä pintakartta assets/terrain/pinnat.png
## (R metsä, G pelto, B räme, A hakkuuaukio; 2 m / pikseli). Ajo:
##   godot --headless --path . -s tools/bake_terrain.gd

const M := preload("res://scripts/map_data.gd")
const T := preload("res://scripts/terrain.gd")
const MARGIN := 300.0
const V_SCALE := 0.8  # kartta on vaakasuunnassa hieman tiivistetty (1 px ≈ 1.25 m): rinteet pysyvät luontevina
const SPLAT_PX := 2.0

var _d: Dictionary


func _init() -> void:
	_d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/terrain/korkeus.json"))
	var lo := M.w2(Vector2.ZERO) - Vector2(MARGIN, MARGIN)
	var hi := M.w2(M.SIZE) + Vector2(MARGIN, MARGIN)
	var nx := int(ceil((hi.x - lo.x) / T.CELL)) + 1
	var nz := int(ceil((hi.y - lo.y) / T.CELL)) + 1
	var base := _elev_px(M.HOME_BUILDING)
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			var w := lo + Vector2(i, j) * T.CELL
			hs[j * nx + i] = (_elev_px(w / M.SCALE + M.ORIGIN) - base) * V_SCALE
	hs = _blur(hs, nx, nz, 2)
	_flatten_site(hs, nx, nz, lo, M.w2(M.KOTA) + Vector2(3, 3), 13.0)  # kota, halkovaja ja lintutorni tasamaalle
	_flatten_water(hs, nx, nz, lo)  # vesi viimeisenä, ettei piha nosta järven pintaa
	var f := FileAccess.open(T.BIN, FileAccess.WRITE)
	f.store_32(nx)
	f.store_32(nz)
	f.store_float(lo.x)
	f.store_float(lo.y)
	f.store_buffer(hs.to_byte_array())
	f.close()
	var mn := INF
	var mx := -INF
	for v in hs:
		mn = minf(mn, v)
		mx = maxf(mx, v)
	print("korkeus.bin: %dx%d, korkeus %.1f..%.1f m (koti 0)" % [nx, nz, mn, mx])
	_bake_splat()
	quit()


## Catmull-Rom-interpolointi karkeasta ruudukosta (karttapikseleissä).
func _elev_px(p: Vector2) -> float:
	var gx: float = (p.x - float(_d.px0)) / float(_d.dx)
	var gy: float = (p.y - float(_d.py0)) / float(_d.dy)
	var ix := int(floor(gx))
	var iy := int(floor(gy))
	var tx: float = gx - ix
	var ty: float = gy - iy
	var rows := []
	for dj in range(-1, 3):
		var r := []
		for di in range(-1, 3):
			r.append(_at(ix + di, iy + dj))
		rows.append(_cr(r[0], r[1], r[2], r[3], tx))
	return _cr(rows[0], rows[1], rows[2], rows[3], ty)


func _at(i: int, j: int) -> float:
	i = clampi(i, 0, int(_d.nx) - 1)
	j = clampi(j, 0, int(_d.ny) - 1)
	return float(_d.elev[j * int(_d.nx) + i])


func _cr(a: float, b: float, c: float, d: float, t: float) -> float:
	return 0.5 * (2.0 * b + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)


func _blur(hs: PackedFloat32Array, nx: int, nz: int, passes: int) -> PackedFloat32Array:
	for p in passes:
		var out := hs.duplicate()
		for j in range(1, nz - 1):
			for i in range(1, nx - 1):
				var k := j * nx + i
				out[k] = (hs[k] * 4.0 + hs[k - 1] + hs[k + 1] + hs[k - nx] + hs[k + nx]) / 8.0
		hs = out
	return hs


## Järvet vaakasuoriksi: vesi pinnan tasolle, rannat viettävät loivasti veteen.
func _flatten_water(hs: PackedFloat32Array, nx: int, nz: int, lo: Vector2) -> void:
	for wp in M.WATER:
		var poly := PackedVector2Array()
		for p in wp:
			poly.append(M.w2(p))
		var level := INF
		for p in poly:
			level = minf(level, _sample(hs, nx, nz, lo, p))
		level -= 0.5
		# Kodan rannalla vesi pihan tason alle (karkea korkeusmalli antaisi liian jyrkän rannan).
		if _poly_dist(poly, M.w2(M.KOTA)) < 60.0:
			level = maxf(level, _sample(hs, nx, nz, lo, M.w2(M.KOTA)) - 1.4)
		var bmin := Vector2(INF, INF)
		var bmax := -bmin
		for p in poly:
			bmin = bmin.min(p)
			bmax = bmax.max(p)
		bmin -= Vector2(25, 25)
		bmax += Vector2(25, 25)
		for j in range(maxi(0, int((bmin.y - lo.y) / T.CELL)), mini(nz, int((bmax.y - lo.y) / T.CELL) + 2)):
			for i in range(maxi(0, int((bmin.x - lo.x) / T.CELL)), mini(nx, int((bmax.x - lo.x) / T.CELL) + 2)):
				var w := lo + Vector2(i, j) * T.CELL
				var d := _poly_dist(poly, w)
				var k := j * nx + i
				if Geometry2D.is_point_in_polygon(w, poly) or d < 3.0:
					hs[k] = level
				elif w.distance_to(M.w2(M.KOTA) + Vector2(3, 3)) < 25.0:
					pass  # kodan piha säilyy tasaisena rantatörmään asti
				elif d < 22.0:
					hs[k] = lerpf(level, hs[k], smoothstep(3.0, 22.0, d))
		print("järvi: taso %.2f m" % level)


## Tasainen piha: keskipisteen korkeus säteellä r, reunoilla pehmeä liitos.
func _flatten_site(hs: PackedFloat32Array, nx: int, nz: int, lo: Vector2, c: Vector2, r: float) -> void:
	var level := _sample(hs, nx, nz, lo, c)
	for j in nz:
		for i in nx:
			var w := lo + Vector2(i, j) * T.CELL
			var d := w.distance_to(c)
			if d < r + 12.0:
				var k := j * nx + i
				hs[k] = lerpf(level, hs[k], smoothstep(r, r + 12.0, d))
	print("piha: taso %.2f m" % level)


func _sample(hs: PackedFloat32Array, nx: int, nz: int, lo: Vector2, p: Vector2) -> float:
	var i := clampi(int(round((p.x - lo.x) / T.CELL)), 0, nx - 1)
	var j := clampi(int(round((p.y - lo.y) / T.CELL)), 0, nz - 1)
	return hs[j * nx + i]


func _poly_dist(poly: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


func _bake_splat() -> void:
	var lo := M.w2(Vector2.ZERO)
	var hi := M.w2(M.SIZE)
	var w := int(ceil((hi.x - lo.x) / SPLAT_PX))
	var hgt := int(ceil((hi.y - lo.y) / SPLAT_PX))
	var img := Image.create(w, hgt, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var layers := [[M.FORESTS, 0], [M.FIELDS, 1], [M.BOGS, 2], [M.CLEARCUTS, 3]]
	for layer in layers:
		for src in layer[0]:
			var poly := PackedVector2Array()
			for p in src:
				poly.append(M.w2(p))
			var bmin := Vector2(INF, INF)
			var bmax := -bmin
			for p in poly:
				bmin = bmin.min(p)
				bmax = bmax.max(p)
			for y in range(maxi(0, int((bmin.y - lo.y) / SPLAT_PX)), mini(hgt, int((bmax.y - lo.y) / SPLAT_PX) + 1)):
				for x in range(maxi(0, int((bmin.x - lo.x) / SPLAT_PX)), mini(w, int((bmax.x - lo.x) / SPLAT_PX) + 1)):
					var c := lo + (Vector2(x, y) + Vector2(0.5, 0.5)) * SPLAT_PX
					if Geometry2D.is_point_in_polygon(c, poly):
						var col := img.get_pixel(x, y)
						col[layer[1]] = 1.0
						img.set_pixel(x, y, col)
	img.save_png(ProjectSettings.globalize_path(T.SPLAT))
	print("pinnat.png: %dx%d" % [w, hgt])
