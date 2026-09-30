extends RefCounted
## Maaston korkeus: todellinen korkeusmalli (Maanmittauslaitoksen 2 m -malli, ks. assets/terrain/korkeus.json)
## leivottuna 5 m ruudukoksi (tools/bake_terrain.gd -> assets/terrain/korkeus.bin).
## h(x, z) antaa korkeuden maailmankoordinaateissa; kolmiointi vastaa maastoverkkoa, joten
## maan pinnalle nostetut asiat ovat täsmälleen samassa tasossa kuin maa.
## Ruudukon ulkopuolella (sisätilat, tappelu, autotalli kaukana kartasta) korkeus on 0.

const BIN := "res://assets/terrain/korkeus.bin"
const SPLAT := "res://assets/terrain/pinnat.png"
const CELL := 5.0
const COLLISION_LAYER := 16  # maaston törmäyskerros (bitti 5)

static var origin := Vector2.ZERO  # ruudukon [0, 0] maailmassa (x, z)
static var nx := 0
static var nz := 0
static var heights := PackedFloat32Array()
static var _loaded := false
static var _tex: ImageTexture
static var _normals := PackedVector3Array()


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(BIN, FileAccess.READ)
	if f == null:
		push_warning("Maaston korkeusmallia ei löydy (%s): maasto on tasainen." % BIN)
		return
	nx = f.get_32()
	nz = f.get_32()
	origin = Vector2(f.get_float(), f.get_float())
	heights = f.get_buffer(nx * nz * 4).to_float32_array()


static func available() -> bool:
	ensure()
	return nx > 1


## Korkeus kohdassa (x, z). Kolmiointi kuten maastoverkossa: jako lävistäjällä (1,0)-(0,1).
static func h(x: float, z: float) -> float:
	ensure()
	if nx < 2:
		return 0.0
	var fx := (x - origin.x) / CELL
	var fz := (z - origin.y) / CELL
	if fx < 0.0 or fz < 0.0 or fx > nx - 1 or fz > nz - 1:
		return 0.0
	var i := mini(int(fx), nx - 2)
	var j := mini(int(fz), nz - 2)
	var u := fx - i
	var v := fz - j
	var k := j * nx + i
	var h00 := heights[k]
	var h10 := heights[k + 1]
	var h01 := heights[k + nx]
	var h11 := heights[k + nx + 1]
	if u + v <= 1.0:
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)


## Pinnan normaali (maailmassa) kohdassa (x, z).
static func normal(x: float, z: float) -> Vector3:
	var e := CELL * 0.5
	var dx := h(x + e, z) - h(x - e, z)
	var dz := h(x, z + e) - h(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## Ruudukon normaali lähimmästä pisteestä (nopea; maakerrosten verkoille).
static func grid_normal(x: float, z: float) -> Vector3:
	ensure()
	if nx < 2:
		return Vector3.UP
	if _normals.is_empty():
		_normals.resize(nx * nz)
		for j in nz:
			for i in nx:
				var k := j * nx + i
				var hl := heights[k - 1] if i > 0 else heights[k]
				var hr := heights[k + 1] if i < nx - 1 else heights[k]
				var hu := heights[k - nx] if j > 0 else heights[k]
				var hd := heights[k + nx] if j < nz - 1 else heights[k]
				_normals[k] = Vector3(hl - hr, 2.0 * CELL, hu - hd).normalized()
	var i := clampi(int(round((x - origin.x) / CELL)), 0, nx - 1)
	var j := clampi(int(round((z - origin.y) / CELL)), 0, nz - 1)
	return _normals[j * nx + i]


## Korkeudet tekstuurina shadereille (ruoho): R = korkeus metreinä.
static func texture() -> ImageTexture:
	ensure()
	if _tex == null and nx > 1:
		var img := Image.create_from_data(nx, nz, false, Image.FORMAT_RF, heights.to_byte_array())
		_tex = ImageTexture.create_from_image(img)
	return _tex


static func size() -> Vector2:
	ensure()
	return Vector2((nx - 1) * CELL, (nz - 1) * CELL)
