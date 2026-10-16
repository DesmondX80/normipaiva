extends Node3D
## Kodin kadun puolen tuija-aita, jota voi leikata (hedge_game.gd). Talon kehyksessä: x aidan suuntaan, aidan keskilinja
## z = zc, syvyys DEPTH, pihan puoli +z. Aita on umpinaisista sarakkeista (COL m): jokaisella oma latvan korkeus ja
## tila (0 rehottava, 1 leikattu, 2 kolo narun alla), joten leikattu latva on oikea tasainen pinta eikä ontto kuori.
## Rehottavan latvan päällä pystyjä lehväkortteja ja ohuita versoja, pihan puolelle sojottaa kylkiversoja. Pala
## (CHUNK saraketta) rakennetaan uudelleen vain, kun sen sarakkeet muuttuvat. Aita rehottaa päivä päivältä (grow).

const B := preload("res://scripts/build.gd")
const Foliage := preload("res://scripts/foliage.gd")

const COL := 0.05
const CHUNK := 20
const TARGET := 1.5  # Päivin narun korkeus
const TOL := 0.05
const DEPTH := 1.0
const MAX_TOP := TARGET + 0.45
const BODY := Color(0.18, 0.34, 0.16)
const CUT := Color(0.62, 0.7, 0.34)  # tuore leikkuupinta: vaalea, kellertävä
const HOLE := Color(0.5, 0.36, 0.2)  # kolo: tuijan ruskea sisus

var segs: Array = [[-9.5, -4.5], [5.0, 9.5]]
var zc := 0.0
var tops := PackedFloat32Array()
var state := PackedByteArray()
var xs := PackedFloat32Array()  # sarakkeiden keskikohdat
var shoots: Array = []  # [sarake, latvan korkeus] ohut verso latvan yllä
var sides: Array = []  # [x, y, pituus, leikattu] pihan puolelle sojottava kylkiverso

var _body_mi: Array[MeshInstance3D] = []
var _card_mi: Array[MeshInstance3D] = []
var _dirty := {}
var _body_mat: ShaderMaterial
var _card_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_rng.seed = 7177
	_noise.seed = 51
	_noise.frequency = 0.9
	for sg in segs:
		var n := roundi((sg[1] - sg[0]) / COL)
		for k in n:
			xs.append(sg[0] + (k + 0.5) * COL)
	tops.resize(xs.size())
	state.resize(xs.size())
	state.fill(0)
	tops.fill(TARGET)
	_body_mat = B.shader_mat("res://shaders/hedge.gdshader", {"leaf_tex": Foliage.hedge_texture(), "noise_tex": B.noise_tex()})
	_card_mat = B.shader_mat("res://shaders/foliage_card.gdshader", {"leaf_tex": Foliage.spruce_texture(), "noise_tex": B.noise_tex(),
		"sway": 0.012})
	for c in ceili(xs.size() / float(CHUNK)):
		var bm := MeshInstance3D.new()
		bm.material_override = _body_mat
		add_child(bm)
		_body_mi.append(bm)
		var cm := MeshInstance3D.new()
		cm.material_override = _card_mat
		cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cm)
		_card_mi.append(cm)
	grow(0.2)


## Rehotus: latva nousee (vaihtelee kohdittain), kolot umpeutuvat hitaasti, uusia versoja latvaan ja kylkeen.
func grow(amount: float) -> void:
	for i in xs.size():
		var k := 0.7 + 0.6 * (_noise.get_noise_1d(xs[i] * 3.0) * 0.5 + 0.5)
		if state[i] == 2:
			tops[i] += amount * 0.5
			if tops[i] >= TARGET - TOL:
				state[i] = 0
		else:
			tops[i] = minf(MAX_TOP, tops[i] + amount * k)
			if tops[i] > TARGET + TOL:
				state[i] = 0
	shoots = shoots.filter(func(s: Array) -> bool: return s[1] > tops[s[0]] + 0.03)
	for k in int(amount * 120.0):
		var i := _rng.randi() % xs.size()
		shoots.append([i, tops[i] + _rng.randf_range(0.12, 0.35)])
	for k in int(amount * 30.0):
		if sides.filter(func(s: Array) -> bool: return not s[3]).size() >= 10:
			break
		var x := xs[_rng.randi() % xs.size()]
		sides.append([x, _rng.randf_range(0.55, TARGET - 0.35), _rng.randf_range(0.16, 0.28), false])  # niin alhaalla, ettei latva leikkaannu
	sides = sides.filter(func(s: Array) -> bool: return not s[3])
	for c in _body_mi.size():
		_dirty[c] = true


func front() -> float:
	return zc + DEPTH / 2.0


func back() -> float:
	return zc - DEPTH / 2.0


## Sarake kohdassa x tai -1 (aukko, aidan pää).
func col_at(x: float) -> int:
	for sg in segs:
		if x >= sg[0] and x < sg[1]:
			var off := 0
			for s2 in segs:
				if s2 == sg:
					break
				off += roundi((s2[1] - s2[0]) / COL)
			return off + clampi(int((x - sg[0]) / COL), 0, roundi((sg[1] - sg[0]) / COL) - 1)
	return -1


func top_at(x: float) -> float:
	var i := col_at(x)
	return tops[i] if i >= 0 else 0.0


## Leikkaa sarakkeet väliltä [xa, xb] korkeuteen y, jos latva on enintään bite syvemmällä (terä haukkaa latvasta
## palan; syvemmällä se vain hipoo kylkeä). Palauttaa {removed, holes (uudet kolosarakkeet), at: leikatut x:t}.
func cut_range(xa: float, xb: float, y: float, bite: float, skip_x := INF) -> Dictionary:
	var out := {"removed": 0.0, "holes": 0, "at": []}
	for i in xs.size():
		var x := xs[i]
		if x < xa - COL / 2.0 or x > xb + COL / 2.0 or absf(x - skip_x) < 0.1:
			continue
		var t := tops[i]
		if t > y and t - y <= bite:
			out.removed += t - y
			out.at.append(x)
			tops[i] = y
			if y < TARGET - TOL:
				if state[i] != 2:
					out.holes += 1
				state[i] = 2
			elif state[i] == 0:
				state[i] = 1
			_dirty[i / CHUNK] = true
	for s in shoots:
		var x := xs[s[0]]
		if x >= xa - COL and x <= xb + COL and s[1] > y and y >= tops[s[0]] - bite:
			out.removed += (s[1] - y) * 0.3
			out.at.append(x)
			s[1] = y
			_dirty[s[0] / CHUNK] = true
	return out


## Kylkiverso poikki, jos terän piste osuu siihen. Palauttaa katkaistun verson [x, y, pituus] tai [].
func cut_side(p: Vector3) -> Array:
	for s in sides:
		if s[3]:
			continue
		if absf(p.x - s[0]) < 0.07 and absf(p.y - s[1]) < 0.08 and p.z > front() - 0.05 and p.z < front() + s[2] + 0.05:
			s[3] = true
			var i := col_at(s[0])
			if i >= 0:
				_dirty[i / CHUNK] = true
			return [s[0], s[1], s[2]]
	return []


## Osuus aidasta, jonka latva on narun tasalla tai alempana.
func level_share() -> float:
	var ok := 0
	for t in tops:
		if t <= TARGET + TOL:
			ok += 1
	return float(ok) / maxf(1.0, xs.size())


func shoots_ok() -> bool:
	return shoots.all(func(s: Array) -> bool: return s[1] <= TARGET + TOL + 0.03)


func sides_left() -> int:
	return sides.filter(func(s: Array) -> bool: return not s[3]).size()


## Keskimääräinen rehotus narun yli (m).
func overgrowth() -> float:
	var sum := 0.0
	for t in tops:
		sum += maxf(0.0, t - TARGET)
	return sum / maxf(1.0, xs.size())


func hole_count() -> int:
	var n := 0
	for i in state.size():
		if state[i] == 2 and (i == 0 or state[i - 1] != 2):
			n += 1
	return n


func save_state() -> Dictionary:
	return {"tops": tops, "state": state, "shoots": shoots, "sides": sides}


func load_state(d: Dictionary) -> void:
	var t: PackedFloat32Array = d.get("tops", PackedFloat32Array())
	if t.size() != xs.size():
		return  # uusi peli tai aidan mitat muuttuivat: oletusrehotus
	tops = t
	state = d.get("state", state)
	shoots = d.get("shoots", [])
	sides = d.get("sides", [])
	for c in _body_mi.size():
		_dirty[c] = true


func _process(_delta: float) -> void:
	for c in _dirty.keys():
		_build_chunk(c)
	_dirty.clear()


func _seg_end(i: int, dir: int) -> bool:
	var j := i + dir
	return j < 0 or j >= xs.size() or absf(xs[j] - xs[i]) > COL * 1.5


## Palan runko (umpinaiset sarakkeet) ja lehväkortit uudelleen.
func _build_chunk(c: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cs := SurfaceTool.new()
	cs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z0 := back()
	var z1 := front()
	var y0 := -0.15
	var i0 := c * CHUNK
	var i1 := mini(xs.size(), i0 + CHUNK)
	for i in range(i0, i1):
		var x0 := xs[i] - COL / 2.0
		var x1 := xs[i] + COL / 2.0
		var t := tops[i]
		var tc := BODY.lightened(0.08) if state[i] == 0 else (CUT if state[i] == 1 else HOLE)
		var rim := BODY.lerp(tc, 0.45)
		_quad(st, Vector3(x0, t, z1), Vector3(x1, t, z1), Vector3(x1, t, z0), Vector3(x0, t, z0), Vector3.UP, tc, tc)
		_quad(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, t, z1), Vector3(x0, t, z1), Vector3.BACK, BODY.darkened(0.35), rim)
		_quad(st, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, t, z0), Vector3(x1, t, z0), Vector3.FORWARD, BODY.darkened(0.35), rim)
		var lo_l := y0 if _seg_end(i, -1) else minf(t, tops[i - 1])
		if lo_l < t:
			_quad(st, Vector3(x0, lo_l, z0), Vector3(x0, lo_l, z1), Vector3(x0, t, z1), Vector3(x0, t, z0), Vector3.LEFT, BODY.darkened(0.2), rim)
		var lo_r := y0 if _seg_end(i, 1) else minf(t, tops[i + 1])
		if lo_r < t:
			_quad(st, Vector3(x1, lo_r, z1), Vector3(x1, lo_r, z0), Vector3(x1, t, z0), Vector3(x1, t, z1), Vector3.RIGHT, BODY.darkened(0.2), rim)
		# Lehväkortit: rehottavan latvan päällä pystyssä (pörröinen siluetti), kyljissä vinosti ulos.
		var h := hash(i * 7919) % 1000 / 1000.0
		if state[i] == 0 and t > TARGET + 0.02:
			for k in 2:
				var hk := fmod(h * (5.1 + k * 3.7), 1.0)
				_card(cs, Vector3(xs[i], t - 0.06, lerpf(z0, z1, 0.1 + hk * 0.8)), hk * TAU, 0.16, 0.1 + hk * 0.14, BODY.lightened(0.1 + hk * 0.15), 0.0)
		if i % 2 == 0:
			for side in [z1, z0]:
				var yy := lerpf(0.15, t - 0.12, fmod(h * 7.3, 1.0))
				var out := 0.03 if side == z1 else -0.03
				_card(cs, Vector3(xs[i], yy, side + out), h * TAU, 0.22, 0.2, BODY.lightened(h * 0.12), 0.0, side == z1)
	for s in shoots:
		var i: int = s[0]
		if i < i0 or i >= i1 or s[1] <= tops[i] + 0.02:
			continue
		var h := hash(i * 131) % 1000 / 1000.0
		_card(cs, Vector3(xs[i], tops[i] - 0.04, lerpf(z0, z1, 0.3 + h * 0.5)), h * TAU, 0.12, s[1] - tops[i] + 0.06, BODY.lightened(0.28), 0.0)
	for s in sides:
		var i := col_at(s[0])
		if s[3] or i < i0 or i >= i1:
			continue
		var p := Vector3(s[0], s[1], z1 - 0.04)
		for k in 3:
			_card(cs, p, (k - 1) * 0.6, 0.14, s[2] + 0.06, BODY.lightened(0.25 + k * 0.04), 1.25)
	st.generate_tangents()
	_body_mi[c].mesh = st.commit()
	_card_mi[c].mesh = cs.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, lo: Color, hi: Color) -> void:
	# Godotissa etupinta kiertää myötäpäivään (normaalin puolelta katsottuna): a, c, b ja a, d, c.
	for p in [[a, lo, Vector2(0, 1)], [c, hi, Vector2(1, 0)], [b, lo, Vector2(1, 1)], [a, lo, Vector2(0, 1)], [d, hi, Vector2(0, 0)], [c, hi, Vector2(1, 0)]]:
		st.set_normal(n)
		st.set_color(p[1])
		st.set_uv(p[2])
		st.add_vertex(p[0])


## Lehväkortti: risti kahdesta pystyneliöstä (näkyy joka suunnasta). tilt kallistaa kortin pihalle päin (+z),
## outward = kyljen kortti nojaa pihalle.
func _card(cs: SurfaceTool, base: Vector3, yaw: float, w: float, h: float, col: Color, tilt: float, outward := false) -> void:
	var up := Vector3.UP.rotated(Vector3.RIGHT, tilt)
	if outward:
		up = Vector3(0, 0.8, 0.6).normalized()
	for k in 2:
		var r := Vector3.RIGHT.rotated(Vector3.UP, yaw + k * PI / 2.0) * w / 2.0
		var a := base - r
		var b := base + r
		var c := b + up * h
		var d := a + up * h
		var n := r.cross(up).normalized()
		for p in [[a, Vector2(0, 1)], [b, Vector2(1, 1)], [c, Vector2(1, 0)], [a, Vector2(0, 1)], [c, Vector2(1, 0)], [d, Vector2(0, 0)]]:
			cs.set_normal(n)
			cs.set_color(col)
			cs.set_uv(p[1])
			cs.add_vertex(p[0])
