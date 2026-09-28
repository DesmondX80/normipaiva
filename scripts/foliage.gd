extends RefCounted
## Puiden ja pensaiden lehvästö: tekstuurit piirretään koodista (lehdet, kuusen oksat, männyn tupsut)
## ja latvat rakennetaan läpikuultavista korteista. Tekstuurit ovat vaaleita, sävy tulee instanssiväristä.

static var _tex := {}


static func leaf_texture() -> ImageTexture:
	if _tex.has("leaf"):
		return _tex.leaf
	var n := 256
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.75, 0.5, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Lehtiä rykelminä; reunoilla harvemmin, jotta kortin muoto ei näy.
	for i in 900:
		var r := sqrt(rng.randf()) * 0.46
		var a := rng.randf() * TAU
		var c := Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * r
		_leaf(img, c * n, rng.randf_range(5.0, 9.0), rng.randf_range(2.8, 4.5), rng.randf() * TAU,
			Color(0.8, 0.95, 0.65).darkened(rng.randf_range(0.0, 0.35)))
	img.generate_mipmaps()
	_tex.leaf = ImageTexture.create_from_image(img)
	return _tex.leaf


## Pensasaidan pinta: lehtiä tasaisesti koko ruudulle, reunojen yli jatkuen (saumaton toisto).
static func hedge_texture() -> ImageTexture:
	if _tex.has("hedge"):
		return _tex.hedge
	var n := 256
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.18, 0.24, 0.14, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 1400:
		var c := Vector2(rng.randf() * n, rng.randf() * n)
		var a := rng.randf_range(5.0, 8.5)
		var b := rng.randf_range(2.8, 4.2)
		var rot := rng.randf() * TAU
		var col := Color(0.8, 0.95, 0.65).darkened(rng.randf_range(0.0, 0.45))
		for ox in [-n, 0, n]:
			for oy in [-n, 0, n]:
				if c.x + ox > -10 and c.x + ox < n + 10 and c.y + oy > -10 and c.y + oy < n + 10:
					_leaf(img, c + Vector2(ox, oy), a, b, rot, col)
	img.generate_mipmaps()
	_tex.hedge = ImageTexture.create_from_image(img)
	return _tex.hedge


## Kuusen oksa: varsi vasemmalta oikealle ja alaspäin taipuen, neulaset molemmin puolin.
static func spruce_texture() -> ImageTexture:
	if _tex.has("spruce"):
		return _tex.spruce
	var w := 256
	var h := 128
	var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.7, 0.5, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for side_branch in 5:
		var y0 := 40.0 + side_branch * 14.0
		var steps := 90
		for k in steps:
			var t := float(k) / steps
			var x := 6.0 + t * (w - 20.0)
			var y := y0 + t * t * 28.0 - side_branch * t * 6.0
			var width := lerpf(20.0, 6.0, t)
			for j in 3:
				var off := rng.randf_range(-width, width)
				var tip := Vector2(x + rng.randf_range(-3, 6), y + off)
				_line(img, Vector2(x, y), tip, Color(0.75, 0.95, 0.7).darkened(rng.randf_range(0.0, 0.4)))
		for k in steps:
			var t := float(k) / steps
			img.set_pixelv(Vector2i(int(6.0 + t * (w - 20.0)), clampi(int(y0 + t * t * 28.0 - side_branch * t * 6.0), 0, h - 1)),
				Color(0.45, 0.35, 0.25, 1.0))
	img.generate_mipmaps()
	_tex.spruce = ImageTexture.create_from_image(img)
	return _tex.spruce


## Männyn neulastupsut: säteittäisiä neulasviuhkoja.
static func pine_texture() -> ImageTexture:
	if _tex.has("pine"):
		return _tex.pine
	var n := 256
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.7, 0.5, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for tuft in 26:
		var r := sqrt(rng.randf()) * 0.38
		var a := rng.randf() * TAU
		var c := (Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * r) * n
		var size := rng.randf_range(16.0, 28.0)
		for k in 34:
			var ang := rng.randf() * TAU
			_line(img, c, c + Vector2(cos(ang), sin(ang)) * size * rng.randf_range(0.6, 1.0),
				Color(0.7, 0.9, 0.62).darkened(rng.randf_range(0.0, 0.35)))
	img.generate_mipmaps()
	_tex.pine = ImageTexture.create_from_image(img)
	return _tex.pine


static func _leaf(img: Image, c: Vector2, a: float, b: float, rot: float, col: Color) -> void:
	var cr := cos(rot)
	var sr := sin(rot)
	var ext := int(a) + 1
	for dy in range(-ext, ext + 1):
		for dx in range(-ext, ext + 1):
			var lx := dx * cr + dy * sr
			var ly := -dx * sr + dy * cr
			var e := (lx * lx) / (a * a) + (ly * ly) / (b * b)
			if e <= 1.0:
				var px := int(c.x) + dx
				var py := int(c.y) + dy
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					var vein := 0.85 if absf(ly) < 0.6 else 1.0
					img.set_pixel(px, py, Color(col.r * vein * (1.0 - e * 0.2), col.g * vein * (1.0 - e * 0.15), col.b * vein, 1.0))


static func _line(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var steps := int(a.distance_to(b)) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var px := int(p.x)
		var py := int(p.y)
		if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
			img.set_pixel(px, py, col)


# --- Korttimeshit -------------------------------------------------------------

static func _card(st: SurfaceTool, center: Vector3, right: Vector3, up: Vector3, normal: Vector3, uv0 := Vector2.ZERO, uv1 := Vector2.ONE) -> void:
	var corners := [center - right - up, center + right - up, center + right + up, center - right + up]
	var uvs := [Vector2(uv0.x, uv1.y), Vector2(uv1.x, uv1.y), Vector2(uv1.x, uv0.y), Vector2(uv0.x, uv0.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])


## Koivun latvus: kortit ellipsoidin pinnalla, osa riippuvia.
static func birch_crown(seed_val: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cen := Vector3(0, 5.8, 0)
	for i in 30:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.8, 1), rng.randf_range(-1, 1)).normalized()
		var p := cen + Vector3(d.x * 1.9, d.y * 2.3, d.z * 1.9) * rng.randf_range(0.45, 1.0)
		var size := rng.randf_range(0.9, 1.3)
		var right := d.cross(Vector3.UP).normalized()
		if right.length() < 0.1:
			right = Vector3.RIGHT
		right = right.rotated(d, rng.randf_range(-0.6, 0.6))
		var up := d.cross(right).normalized().lerp(Vector3.DOWN, 0.25).normalized()
		_card(st, p, right * size, up * size * 1.15, d)
	return st.commit()


## Kuusi: oksakerrokset tyvestä latvaan, jokaisessa oksakortit säteittäin, kärjet roikkuvat.
static func spruce_crown(seed_val: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := 1.0
	var top := 8.4
	while y < top:
		var t := (y - 1.0) / (top - 1.0)
		var length := lerpf(2.3, 0.35, t)
		var count := 7 if t < 0.7 else 5
		var off := rng.randf() * TAU
		for k in count:
			var a := off + TAU * k / count + rng.randf_range(-0.2, 0.2)
			var rad := Vector3(cos(a), 0, sin(a))
			var droop := Vector3(0, -0.35, 0)
			var dir := (rad + droop).normalized()
			var center := Vector3(0, y, 0) + dir * length * 0.5
			var side := Vector3.UP.cross(rad).normalized()
			# Oksakortti pystytasossa (näkyy sivulta) ja toinen lähes vaakatasossa (näkyy ylhäältä).
			_card(st, center, dir * length * 0.55, Vector3.UP.lerp(side, 0.2).normalized() * length * 0.3, side)
			_card(st, center + Vector3(0, 0.05, 0), dir * length * 0.55, side * length * 0.32, Vector3.UP)
		y += lerpf(0.42, 0.3, t)
	return st.commit()


## Mänty: latvassa neulastupsuja ristikkäisinä kortteina.
static func pine_crown(seed_val: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.2, 1.5)
		var c := Vector3(cos(a) * r, rng.randf_range(7.9, 10.1), sin(a) * r)
		var size := rng.randf_range(0.9, 1.4)
		for k in 3:
			var ang := k * PI / 3.0 + rng.randf() * 0.5
			var right := Vector3(cos(ang), 0, sin(ang))
			_card(st, c, right * size, Vector3(0, size * 0.6, 0).rotated(right, rng.randf_range(-0.4, 0.4)), right.cross(Vector3.UP))
		_card(st, c + Vector3(0, 0.2, 0), Vector3(size, 0, 0), Vector3(0, 0, size), Vector3.UP)
	return st.commit()
