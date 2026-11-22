extends Node3D
## Kaisuan tilan yksi pelto (kaisua.gd): ruudukko pellon monikulmion rajaavassa suorakaiteessa (kaisua_tila.gd CELL),
## pellon pinta ja kasvusto. Solmu on mökin paikallisessa kehyksessä (Kaisuan solmu on mökin lapsi origossa).
##
## Piirto: pinta on maastoverkon päällä (sama kolmiointi kuin mokki.gd _ground_grid, mesh_h) ja varjostin
## (shaders/pelto_maa.gdshader) värittää sen ruutujen tilasta: nurmi, niitetty sarka, sänki, multa, kylvörivit, oras,
## kypsä ohra. Kasvusto on tupsuja (MultiMesh 16 m lohkoissa, yksi tupsu ruutua kohden) ristikkäisistä korsikorteista
## (shaders/pelto_kasvi.gdshader, korsikuva piirretään kerran _atlas()): pituus, kallistus (niitetty heinä makaa) ja
## väri ruudun tilasta, korkeus maastosta. Lohkot näkyvät 60 m:iin, kauempana pinnan väri kantaa kasvuston.
##
## Työ (work): suorakaide pellolla (keskipiste, ajosuunta, puolileveys ja -pituus) muuttaa ruutuja koneen mukaan ja
## palauttaa kerätyn heinän, viljan ja käytetyn siemenen. Tilojen määrät pidetään laskurissa (counts).

const Mokki := preload("res://scripts/mokki.gd")
const Tila := preload("res://scripts/kaisua_tila.gd")

const CHUNK := 32  # ruutua lohkon sivulla (16 m)
const H_STEP := 2.0  # korkeusruudukko (mokki.gd GRID_STEP: verkon kärkipisteet osuvat siihen tarkasti)
const LIFT := 0.05  # pinta maaston yllä
const CROP_RANGE := 80.0

var tila: Tila
var index := 0
var poly := PackedVector2Array()
var origin := Vector2.ZERO  # ruudukon kulma (paikallinen)
var nx := 0
var nz := 0
var area := 0.0  # m²
var counts := {}  # tila -> ruutuja
var center := Vector2.ZERO
var laps := ""  # rakennusvaiheiden ajat (testit tulostavat)

var _f: Dictionary  # tila.fields[id]
## Ruutujen kuvat varjostimille: tila (R8, arvo = tila), määrä (RF) ja työsuunta (R8, 0–255 = 0–180°). Tehdään
## suoraan tallennuksen tavutaulukoista (ei pikselisilmukkaa), päivitetään muuttuneet ruudut.
var _st_img: Image
var _amt_img: Image
var _dir_img: Image
var _st_tex: ImageTexture
var _amt_tex: ImageTexture
var _dir_tex: ImageTexture
var _dirty := false
var _dirty_t := 0.0
var _h_img: Image
var _h_origin := Vector2.ZERO
var _crop_mat: ShaderMaterial
var _ground_mat: ShaderMaterial

static var _atlas_tex: ImageTexture
static var _tuft_mesh: ArrayMesh


## Rakentaa pellon: ruudukko karttadatasta (OSM-tunniste), ruutujen tila tallennuksesta, pinta ja kasvusto.
func setup(t: Tila, i: int) -> bool:
	tila = t
	index = i
	var data := Mokki.map_data()
	var id: String = Tila.FIELDS[i].id
	var k: int = (data.get("field_ids", []) as Array).find(id)
	if k < 0:
		push_warning("Kaisuan peltoa %s ei löydy karttadatasta" % id)
		return false
	poly = data.fields[k]
	var bb := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bb = bb.expand(p)
	var c := Tila.CELL
	origin = (bb.position / c).floor() * c - Vector2.ONE * c
	nx = int(ceil(bb.size.x / c)) + 3
	nz = int(ceil(bb.size.y / c)) + 3
	center = bb.get_center()
	var old: Dictionary = tila.fields.get(id, {})
	var mask := PackedByteArray()
	if old.is_empty() or int(old.nx) != nx or int(old.nz) != nz:
		mask = _scan_mask()
	_f = tila.init_cells(i, nx, nz, mask)
	var t0 := Time.get_ticks_usec()
	_build_heights()
	var t1 := Time.get_ticks_usec()
	_build_state_image()
	var t2 := Time.get_ticks_usec()
	_build_ground()
	var t3 := Time.get_ticks_usec()
	_build_crops()
	var t4 := Time.get_ticks_usec()
	recount()
	laps = "korkeus %d, kuvat %d, pinta %d, kasvusto %d, laskurit %d ms" % [(t1 - t0) / 1000, (t2 - t1) / 1000,
		(t3 - t2) / 1000, (t4 - t3) / 1000, (Time.get_ticks_usec() - t4) / 1000]
	area = cells_total() * c * c
	return true


## Pellon ruudut (aloitustila = ruudun keskipiste monikulmion sisällä, muuten NONE) riveittäin: rivin keskilinjan ja reunojen leikkaukset.
func _scan_mask() -> PackedByteArray:
	var st: int = Tila.FIELDS[index].start
	var mask := PackedByteArray()
	mask.resize(nx * nz)
	var c := Tila.CELL
	var n := poly.size()
	for j in nz:
		var y := origin.y + (j + 0.5) * c
		var xs: Array[float] = []
		for k in n:
			var a := poly[k]
			var b := poly[(k + 1) % n]
			if (a.y > y) != (b.y > y):
				xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for q in range(0, xs.size() - 1, 2):
			var i0 := maxi(0, ceili((xs[q] - origin.x) / c - 0.5))
			var i1 := mini(nx - 1, floori((xs[q + 1] - origin.x) / c - 0.5))
			for i in range(i0, i1 + 1):
				mask[j * nx + i] = st
	return mask


func field_name() -> String:
	return Tila.FIELDS[index].name


func kind() -> String:
	return Tila.FIELDS[index].kind


func cells_total() -> int:
	var n := 0
	for s in counts:
		n += int(counts[s])
	return n


## Osuus pellon ruuduista, jotka ovat jossakin tiloista states.
func share(states: Array) -> float:
	var tot := cells_total()
	if tot == 0:
		return 0.0
	var n := 0
	for s in states:
		n += int(counts.get(s, 0))
	return float(n) / tot


func recount() -> void:
	counts = {}
	var cells: PackedByteArray = _f.cells
	for st in [Tila.H_LYHYT, Tila.H_PUOLI, Tila.H_VALMIS, Tila.H_NIITETTY, Tila.H_KARHO, Tila.H_SANKI, Tila.V_SANKI,
			Tila.V_AESTETTY, Tila.V_KYLVETTY, Tila.V_ORAS, Tila.V_VIHREA, Tila.V_KYPSA, Tila.V_PUITU, Tila.V_OLKI, Tila.V_KYNNETTY]:
		var n := cells.count(st)
		if n > 0:
			counts[st] = n


## Onko paikallinen piste pellolla (ruutu ei ole NONE).
func has_point(p: Vector2) -> bool:
	var k := cell_index(p)
	return k >= 0 and (_f.cells as PackedByteArray)[k] != Tila.NONE


func cell_index(p: Vector2) -> int:
	var i := floori((p.x - origin.x) / Tila.CELL)
	var j := floori((p.y - origin.y) / Tila.CELL)
	if i < 0 or j < 0 or i >= nx or j >= nz:
		return -1
	return j * nx + i


func state_at(p: Vector2) -> int:
	var k := cell_index(p)
	return Tila.NONE if k < 0 else int((_f.cells as PackedByteArray)[k])


## Maastoverkon korkeus paikallisessa pisteessä (sama kuin pinta ja kasvusto).
func ground_y(p: Vector2) -> float:
	return Mokki.mesh_h(p.x, p.y)


# --- Työ -----------------------------------------------------------------------------------------------------------

## Koneen työ suorakaiteella: c = keskipiste, fwd = ajosuunta (yksikkö), hw = puolileveys, hl = puolipituus.
## op: "niitto", "karhous", "paalaus", "aestys", "kylvo", "puinti". Palauttaa {"cells": muuttuneita, "hay": heinää,
## "grain": kg, "seed": kg}. Kylvö käyttää siementä enintään seed_left kg.
func work(op: String, c: Vector2, fwd: Vector2, hw: float, hl: float, seed_left := INF) -> Dictionary:
	var out := {"cells": 0, "hay": 0.0, "grain": 0.0, "seed": 0.0, "stones": []}
	var right := Vector2(-fwd.y, fwd.x)
	var ext := Vector2(absf(fwd.x) * hl + absf(right.x) * hw, absf(fwd.y) * hl + absf(right.y) * hw)
	var cs := Tila.CELL
	var i0 := maxi(0, floori((c.x - ext.x - origin.x) / cs))
	var i1 := mini(nx - 1, floori((c.x + ext.x - origin.x) / cs))
	var j0 := maxi(0, floori((c.y - ext.y - origin.y) / cs))
	var j1 := mini(nz - 1, floori((c.y + ext.y - origin.y) / cs))
	if i0 > i1 or j0 > j1:
		return out
	var cells: PackedByteArray = _f.cells
	var amt: PackedFloat32Array = _f.amt
	var dirs: PackedByteArray = _f.dir
	var dir_b := int(fposmod(atan2(fwd.y, fwd.x), PI) / PI * 255.0)
	var area_c := cs * cs
	var deposit := {}  # karhous: kohderuutu -> heinää
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var k := j * nx + i
			var s := cells[k]
			if s == Tila.NONE:
				continue
			var d := origin + (Vector2(i, j) + Vector2(0.5, 0.5)) * cs - c
			var along := d.dot(fwd)
			var perp := d.dot(right)
			if absf(along) > hl or absf(perp) > hw:
				continue
			var ns := s
			match op:
				"niitto":
					if s == Tila.H_LYHYT or s == Tila.H_PUOLI or s == Tila.H_VALMIS:
						ns = Tila.H_NIITETTY
						amt[k] = float(Tila.HAY_PER_M2[s]) * area_c
				"karhous":
					if (s == Tila.H_NIITETTY or s == Tila.H_KARHO) and absf(perp) >= 0.55:
						var q := c + fwd * along + right * (0.25 if perp > 0.0 else -0.25)
						var tk := cell_index(q)
						if tk >= 0 and cells[tk] != Tila.NONE:
							deposit[tk] = float(deposit.get(tk, 0.0)) + amt[k]
						amt[k] = 0.0
						ns = Tila.H_SANKI
					elif s == Tila.H_NIITETTY and absf(perp) < 0.55:
						ns = Tila.H_KARHO
				"paalaus":
					if s == Tila.H_KARHO:
						out.hay += amt[k]
						amt[k] = 0.0
						ns = Tila.H_SANKI
				"kynto":
					if s == Tila.V_SANKI or s == Tila.V_PUITU or s == Tila.V_OLKI or s == Tila.V_AESTETTY:
						ns = Tila.V_KYNNETTY
						amt[k] = 0.0
						if randf() < Tila.STONE_PER_M2 * area_c:
							out.stones.append(origin + (Vector2(i, j) + Vector2(0.5, 0.5)) * cs)
				"aestys":
					# Äes muokkaa kynnetyn (tai uudelleen äestettävän) mullan; sänkeen se ei pure.
					if s == Tila.V_KYNNETTY or s == Tila.V_AESTETTY:
						ns = Tila.V_AESTETTY
						amt[k] = 0.0
				"kylvo":
					if s == Tila.V_AESTETTY and out.seed + Tila.SEED_PER_M2 * area_c <= seed_left:
						ns = Tila.V_KYLVETTY
						out.seed += Tila.SEED_PER_M2 * area_c
				"puinti":
					if s == Tila.V_KYPSA:
						out.grain += Tila.GRAIN_PER_M2 * area_c
						if absf(perp) < 0.6:
							ns = Tila.V_OLKI
							amt[k] = 1.0
						else:
							ns = Tila.V_PUITU
			if ns != s or (op == "aestys" and ns == Tila.V_AESTETTY):
				if ns != s:
					counts[s] = int(counts.get(s, 0)) - 1
					counts[ns] = int(counts.get(ns, 0)) + 1
					out.cells += 1
				cells[k] = ns
				if op != "karhous" and op != "paalaus":
					dirs[k] = dir_b
				_set_px(i, j, ns, amt[k], dirs[k])
	for tk in deposit:
		var s2 := cells[tk]
		if s2 != Tila.H_KARHO:
			counts[s2] = int(counts.get(s2, 0)) - 1
			counts[Tila.H_KARHO] = int(counts.get(Tila.H_KARHO, 0)) + 1
			cells[tk] = Tila.H_KARHO
		amt[tk] += float(deposit[tk])
		dirs[tk] = dir_b
		_set_px(tk % nx, tk / nx, Tila.H_KARHO, amt[tk], dir_b)
	_f.cells = cells
	_f.amt = amt
	_f.dir = dirs
	return out


## Päivän kasvun (kaisua_tila.gd advance_to) jälkeen: kuva ja laskurit uudelleen.
func refresh_all() -> void:
	_build_state_image()
	_common_textures(_ground_mat)
	_common_textures(_crop_mat)
	recount()


func _set_px(i: int, j: int, s: int, a: float, d: int) -> void:
	_st_img.set_pixel(i, j, Color(s / 255.0, 0, 0))
	_amt_img.set_pixel(i, j, Color(a, 0, 0))
	_dir_img.set_pixel(i, j, Color(d / 255.0, 0, 0))
	_dirty = true


func _process(delta: float) -> void:
	_dirty_t -= delta
	if _dirty and _dirty_t <= 0.0:
		_dirty = false
		_dirty_t = 0.08
		_st_tex.update(_st_img)
		_amt_tex.update(_amt_img)
		_dir_tex.update(_dir_img)


# --- Piirto --------------------------------------------------------------------------------------------------------

## Korkeudet 2 m kärkipisteistä (mokki.gd mesh_h): varjostimet ja pinnan verkko interpoloivat kolmioittain samoin
## kuin maastoverkko.
func _build_heights() -> void:
	_h_origin = (origin / H_STEP).floor() * H_STEP
	var w := int(ceil((origin.x + nx * Tila.CELL - _h_origin.x) / H_STEP)) + 2
	var h := int(ceil((origin.y + nz * Tila.CELL - _h_origin.y) / H_STEP)) + 2
	_h_img = Image.create(w, h, false, Image.FORMAT_RF)
	for j in h:
		for i in w:
			var p := _h_origin + Vector2(i, j) * H_STEP
			_h_img.set_pixel(i, j, Color(Mokki.mesh_h(p.x, p.y), 0, 0))


func _vh(i: int, j: int) -> float:
	return _h_img.get_pixel(i, j).r


func _build_state_image() -> void:
	_st_img = Image.create_from_data(nx, nz, false, Image.FORMAT_R8, _f.cells)
	_amt_img = Image.create_from_data(nx, nz, false, Image.FORMAT_RF, (_f.amt as PackedFloat32Array).to_byte_array())
	_dir_img = Image.create_from_data(nx, nz, false, Image.FORMAT_R8, _f.dir)
	_st_tex = ImageTexture.create_from_image(_st_img)
	_amt_tex = ImageTexture.create_from_image(_amt_img)
	_dir_tex = ImageTexture.create_from_image(_dir_img)


func _common_textures(m: ShaderMaterial) -> void:
	if m == null:
		return
	m.set_shader_parameter("state_tex", _st_tex)
	m.set_shader_parameter("amt_tex", _amt_tex)
	m.set_shader_parameter("dir_tex", _dir_tex)


func _common_params(m: ShaderMaterial) -> void:
	_common_textures(m)
	m.set_shader_parameter("origin", origin)
	m.set_shader_parameter("cells", Vector2(nx, nz))
	m.set_shader_parameter("cell", Tila.CELL)
	m.set_shader_parameter("height_tex", ImageTexture.create_from_image(_h_img))
	m.set_shader_parameter("h_origin", _h_origin)
	m.set_shader_parameter("h_step", H_STEP)


## Pellon pinta: 2 m ruudut maastoverkon mukaan (kolmiot samoin kuin maastossa), jos ruudussa on peltoa.
func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var w := _h_img.get_width()
	var h := _h_img.get_height()
	# 2 m ruutu mukaan, jos sen keskipiste on 2 m levennetyn monikulmion sisällä (natiivi tarkistus, ei ruutusilmukkaa).
	var wide := Geometry2D.offset_polygon(poly, 2.0)
	for j in h - 1:
		for i in w - 1:
			var cpt := _h_origin + (Vector2(i, j) + Vector2(0.5, 0.5)) * H_STEP
			var any := false
			for wp in wide:
				if Geometry2D.is_point_in_polygon(cpt, wp):
					any = true
			if not any:
				continue
			var v := func(di: int, dj: int) -> Vector3:
				var p := _h_origin + Vector2(i + di, j + dj) * H_STEP
				return Vector3(p.x, _vh(i + di, j + dj) + LIFT, p.y)
			for corner in [v.call(0, 0), v.call(1, 0), v.call(1, 1), v.call(0, 0), v.call(1, 1), v.call(0, 1)]:
				st.add_vertex(corner)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = load("res://shaders/pelto_maa.gdshader")
	_common_params(_ground_mat)
	_ground_mat.set_shader_parameter("noise_tex", _noise())
	mi.material_override = _ground_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("ground", true)
	add_child(mi)


## Kasvusto lohkoittain: lohko piirtää ruutunsa tupsut (INSTANCE_ID -> ruutu), tyhjät lohkot ohitetaan.
func _build_crops() -> void:
	_crop_mat = ShaderMaterial.new()
	_crop_mat.shader = load("res://shaders/pelto_kasvi.gdshader")
	_common_params(_crop_mat)
	_crop_mat.set_shader_parameter("atlas", atlas())
	_crop_mat.set_shader_parameter("chunk_cols", CHUNK)
	_crop_mat.set_shader_parameter("noise_tex", _noise())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tuft_mesh()
	mm.instance_count = CHUNK * CHUNK
	var cells: PackedByteArray = _f.cells
	for cj in range(0, nz, CHUNK):
		for ci in range(0, nx, CHUNK):
			var any := false
			var lo := 1e9
			var hi := -1e9
			for j in range(cj, mini(cj + CHUNK, nz), 4):
				for i in range(ci, mini(ci + CHUNK, nx), 4):
					if cells[j * nx + i] != Tila.NONE:
						any = true
			if not any:
				continue
			var p0 := origin + Vector2(ci, cj) * Tila.CELL
			var size := CHUNK * Tila.CELL
			for q in [p0, p0 + Vector2(size, 0), p0 + Vector2(0, size), p0 + Vector2(size, size), p0 + Vector2(size, size) * 0.5]:
				var y := Mokki.mesh_h(q.x, q.y)
				lo = minf(lo, y)
				hi = maxf(hi, y)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = _crop_mat
			mmi.set_instance_shader_parameter("chunk0", Vector2(ci, cj))
			mmi.custom_aabb = AABB(Vector3(p0.x, lo - 1.0, p0.y), Vector3(size, hi - lo + 3.0, size))
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = CROP_RANGE
			mmi.visibility_range_end_margin = 8.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mmi)


func _ready() -> void:
	# Kasvuston varjostin laskee paikan itse (skip_vertex_transform): solmun maailmamuunnos uniformina.
	_sync_xform.call_deferred()


func _sync_xform() -> void:
	if _crop_mat != null and is_inside_tree():
		_crop_mat.set_shader_parameter("to_world", global_transform)


static var _noise_tex: Texture2D


static func _noise() -> Texture2D:
	if _noise_tex == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.05
		var nt := NoiseTexture2D.new()
		nt.noise = n
		nt.seamless = true
		nt.width = 256
		nt.height = 256
		nt.generate_mipmaps = true
		_noise_tex = nt
	return _noise_tex


## Tupsu: kolme pystykorttia 60 asteen välein (leveys 1, korkeus 1; varjostin skaalaa). UV.y 0 = tyvi, 1 = latva.
static func tuft_mesh() -> ArrayMesh:
	if _tuft_mesh != null:
		return _tuft_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := PI * k / 3.0 + 0.2
		var dx := Vector3(cos(a), 0, sin(a)) * 0.5
		var quad := [[-dx, Vector2(0, 0)], [dx, Vector2(1, 0)], [dx + Vector3.UP, Vector2(1, 1)], [-dx + Vector3.UP, Vector2(0, 1)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[idx][1])
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[idx][0])
	_tuft_mesh = st.commit()
	return _tuft_mesh


## Korsikuva (128 × 128): vasen puolisko nurmi (lehdet ja timotein tähkät), oikea ohra (korret, tähkät ja vihneet).
## R = sävy (tyvi tumma, latva vaalea), G = tähkä, A = peitto. Piirretään kerran.
static func atlas() -> ImageTexture:
	if _atlas_tex != null:
		return _atlas_tex
	var w := 128
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var plot := func(x: float, y: float, r: float, g: float, x_lo: int, x_hi: int) -> void:
		var xi := int(x)
		var yi := int(y)
		if xi < x_lo or xi >= x_hi or yi < 0 or yi >= h:
			return
		var old := img.get_pixel(xi, yi)
		img.set_pixel(xi, yi, Color(maxf(old.r, r), maxf(old.g, g), 0, 1))
	# Nurmi: 18 lehteä tyvestä kaartuen, leveys kapenee; joka neljännen latvassa timotein tähkä.
	for b in 18:
		var x0 := rng.randf_range(6.0, 58.0)
		var top := rng.randf_range(0.45, 0.98)
		var lean := rng.randf_range(-14.0, 14.0)
		var wid := rng.randf_range(1.6, 2.6)
		var steps := int(top * h)
		for s in steps:
			var t := float(s) / steps
			var x := x0 + lean * t * t
			var y := h - 1 - s
			var ww := wid * (1.0 - t * 0.85)
			var shade := 0.45 + 0.55 * t
			for o in range(-int(ww), int(ww) + 1):
				plot.call(x + o, y, shade * (0.85 + 0.15 * absf(o) / maxf(ww, 1.0)), 0.0, 0, 64)
		if b % 4 == 0:
			var hx := x0 + lean
			var hy := h - 1 - steps
			for s in 16:
				for o in [-1, 0, 1]:
					plot.call(hx + o + lean * 0.02 * s, hy - s, 0.8, 1.0, 0, 64)
	# Ohra: 16 kortta, ohut korsi, tähkä (jyväparit) ja pitkät vihneet ylös.
	for b in 16:
		var x0 := rng.randf_range(68.0, 124.0)
		var top := rng.randf_range(0.62, 0.8)
		var lean := rng.randf_range(-8.0, 8.0)
		var steps := int(top * h)
		for s in steps:
			var t := float(s) / steps
			var x := x0 + lean * t
			for o in [0, 1]:
				plot.call(x + o, h - 1 - s, 0.5 + 0.4 * t, 0.0, 64, 128)
			if s % 23 == 11:  # lehti korren sivulla
				for q in 10:
					plot.call(x + 1 + q * (1 if b % 2 == 0 else -1), h - 1 - s + q / 3, 0.7, 0.0, 64, 128)
		var ex := x0 + lean
		var ey := h - 1 - steps
		for s in 18:
			var wdt := 2 if s < 14 else 1
			for o in range(-wdt, wdt + 1):
				plot.call(ex + o + lean * 0.03 * s, ey - s, 0.85, 1.0, 64, 128)
			if s % 3 == 0:  # vihneet
				for q in 12:
					plot.call(ex - wdt - q * 0.25 + lean * 0.03 * s, ey - s - q, 0.9, 1.0, 64, 128)
					plot.call(ex + wdt + q * 0.25 + lean * 0.03 * s, ey - s - q, 0.9, 1.0, 64, 128)
	_atlas_tex = ImageTexture.create_from_image(img)
	return _atlas_tex
