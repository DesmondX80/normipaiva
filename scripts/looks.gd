extends RefCounted
## Hahmojen ulkonäöt character.gd:lle ja yhteiset apurit.

const Character := preload("res://scripts/character.gd")
const B := preload("res://scripts/build.gd")

## Pelaaja: 90-luvun tuulipuku (violetti, turkoosi ja musta) ja kaljamaha superhero-lihasten tilalla.
const PLAYER := {
	"shirt": Color(0.42, 0.18, 0.58), "pants": Color(0.42, 0.18, 0.58), "shoes": Color(0.9, 0.9, 0.88),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.22, 0.15, 0.1), "shine": 0.85, "height": 1.8,
	"tracksuit": {"a": Color(0.08, 0.66, 0.64), "b": Color(0.07, 0.07, 0.09)},
	"stripes": true, "stripe_color": Color(0.08, 0.66, 0.64),
	"belly": 0.75, "bulk": 0.1, "shoulders": -0.55,
}
const JUNTTI := {
	"shirt": Color(0.06, 0.06, 0.07), "pants": Color(0.06, 0.06, 0.07), "shoes": Color(0.95, 0.95, 0.95),
	"hair": "Hair_Long", "hair_color": Color(0.85, 0.72, 0.42), "stripes": true, "shine": 0.35, "height": 1.86, "belly": 1.0, "bulk": 0.35, "shoulders": 0.5, "muscle": -0.35,
}
const ANNA_LIISA := {
	"model": "female", "shirt": Color(0.28, 0.58, 0.54), "pants": Color(0.22, 0.22, 0.27),
	"hair": "Hair_Buns", "hair_color": Color(0.55, 0.22, 0.12), "height": 1.66,
}
const CASHIER := {
	"model": "female", "shirt": Color(1.0, 0.42, 0.0), "pants": Color(0.15, 0.15, 0.2),
	"hair": "Hair_Long", "hair_color": Color(0.9, 0.78, 0.45), "height": 1.68,
}
const GRANDPAS := [
	{"shirt": Color(0.6, 0.55, 0.45), "pants": Color(0.3, 0.3, 0.32), "hair": "Hair_Buzzed",
		"hair_color": Color(0.85, 0.85, 0.85), "beard": true, "height": 1.72, "skin": Color(1.0, 0.9, 0.86),
		"belly": 0.35, "bulk": -0.5, "shoulders": -0.5},
	{"shirt": Color(0.4, 0.42, 0.45), "pants": Color(0.25, 0.23, 0.2), "hair": "Hair_SimpleParted",
		"hair_color": Color(0.75, 0.75, 0.75), "height": 1.7, "skin": Color(1.0, 0.9, 0.86),
		"belly": 0.15, "bulk": -0.65, "shoulders": -0.6},
	{"shirt": Color(0.55, 0.35, 0.3), "pants": Color(0.3, 0.3, 0.32), "hair": "Hair_Buzzed",
		"hair_color": Color(0.9, 0.9, 0.9), "beard": true, "height": 1.74, "skin": Color(1.0, 0.9, 0.86),
		"belly": 0.55, "bulk": -0.4, "shoulders": -0.4},
]

const AKKA := {
	"model": "female", "shirt": Color(0.72, 0.1, 0.12), "pants": Color(0.18, 0.26, 0.2), "shoes": Color(0.25, 0.2, 0.15),
	"hair": "Hair_Buns", "hair_color": Color(0.7, 0.68, 0.66), "height": 1.62, "skin": Color(1.0, 0.9, 0.86), "shine": 0.4,
}
const TEENS := [
	{"shirt": Color(0.12, 0.12, 0.13), "pants": Color(0.45, 0.55, 0.7), "shoes": Color(0.95, 0.95, 0.95),
		"hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.2, 0.12), "height": 1.74, "bulk": -0.75, "shoulders": -0.6},
	{"shirt": Color(0.1, 0.35, 0.2), "pants": Color(0.2, 0.2, 0.22), "shoes": Color(0.9, 0.2, 0.2),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.8, 0.65, 0.35), "height": 1.7, "bulk": -0.85, "shoulders": -0.7},
	{"model": "female", "shirt": Color(0.85, 0.4, 0.7), "pants": Color(0.1, 0.1, 0.12), "shoes": Color(0.95, 0.95, 0.95),
		"hair": "Hair_Long", "hair_color": Color(0.12, 0.1, 0.1), "height": 1.65, "bulk": -0.6, "shoulders": -0.4},
]

const ARTO := {
	"shirt": Color(0.62, 0.12, 0.1), "pants": Color(0.22, 0.3, 0.5), "shoes": Color(0.3, 0.22, 0.15),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.45, 0.38, 0.3), "beard": true, "height": 1.8,
}
const PAIVI := {
	"model": "female", "shirt": Color(0.75, 0.2, 0.35), "pants": Color(0.12, 0.12, 0.16), "shoes": Color(0.2, 0.15, 0.12),
	"hair": "Hair_Long", "hair_color": Color(0.45, 0.28, 0.16), "height": 1.68,
}
const JEMMARI := {
	"shirt": Color(0.2, 0.3, 0.55), "pants": Color(0.2, 0.3, 0.55), "shoes": Color(0.12, 0.1, 0.08),
	"hair": "Hair_Buzzed", "hair_color": Color(0.5, 0.4, 0.3), "beard": true, "height": 1.84, "skin": Color(1.0, 0.85, 0.78), "belly": 0.8, "bulk": 0.35, "shoulders": 0.3,
}
## Taksikuski ja Raahen baarin kädenvääntäjä (terästehtaan duunari).
const TAXI_DRIVER := {
	"shirt": Color(0.9, 0.9, 0.88), "pants": Color(0.12, 0.12, 0.14), "shoes": Color(0.08, 0.08, 0.08),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.6, 0.58, 0.55), "height": 1.76, "belly": 0.5,
}
const TERO := {
	"shirt": Color(0.95, 0.5, 0.05), "pants": Color(0.15, 0.2, 0.35), "shoes": Color(0.2, 0.15, 0.1),
	"hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.22, 0.15), "beard": true, "height": 1.88,
	"belly": 0.6, "bulk": 0.6, "shoulders": 0.6, "muscle": 0.3,
}
const PEKKA := {
	"shirt": Color(0.3, 0.36, 0.2), "pants": Color(0.35, 0.33, 0.22), "shoes": Color(0.15, 0.12, 0.1),
	"hair": "Hair_Buzzed", "hair_color": Color(0.35, 0.28, 0.2), "beard": true, "height": 1.78, "shine": 0.2, "belly": 0.65, "bulk": 0.1,
}

## Jalkapalloa pelaavat pojat (#29): lyhyitä ja hoikkia.
const POJAT := [
	{"shirt": Color(0.85, 0.15, 0.15), "pants": Color(0.12, 0.12, 0.14), "shoes": Color(0.95, 0.95, 0.95),
		"hair": "Hair_Buzzed", "hair_color": Color(0.85, 0.72, 0.42), "height": 1.35, "bulk": -0.8, "shoulders": -0.8},
	{"shirt": Color(0.15, 0.35, 0.85), "pants": Color(0.2, 0.2, 0.25), "shoes": Color(0.2, 0.2, 0.2),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.35, 0.22, 0.12), "height": 1.4, "bulk": -0.85, "shoulders": -0.8},
	{"shirt": Color(0.95, 0.85, 0.15), "pants": Color(0.25, 0.3, 0.45), "shoes": Color(0.9, 0.3, 0.2),
		"hair": "Hair_Buzzed", "hair_color": Color(0.15, 0.1, 0.08), "height": 1.3, "bulk": -0.8, "shoulders": -0.85},
]
## Kaupan penkin mummot (kettukarkit taskussa).
const MUMMOT := [
	{"model": "female", "shirt": Color(0.55, 0.3, 0.45), "pants": Color(0.25, 0.22, 0.28), "shoes": Color(0.2, 0.15, 0.12),
		"hair": "Hair_Buns", "hair_color": Color(0.82, 0.82, 0.8), "height": 1.58, "skin": Color(1.0, 0.9, 0.86)},
	{"model": "female", "shirt": Color(0.3, 0.45, 0.6), "pants": Color(0.3, 0.3, 0.32), "shoes": Color(0.2, 0.15, 0.12),
		"hair": "Hair_Long", "hair_color": Color(0.9, 0.9, 0.88), "height": 1.6, "skin": Color(1.0, 0.9, 0.86)},
	{"model": "female", "shirt": Color(0.75, 0.6, 0.3), "pants": Color(0.35, 0.25, 0.2), "shoes": Color(0.2, 0.15, 0.12),
		"hair": "Hair_BuzzedFemale", "hair_color": Color(0.7, 0.68, 0.66), "height": 1.56, "skin": Color(1.0, 0.9, 0.86)},
]
## Pannu-Sulo, metsän pontikankeittäjä: ruutupaita, maastohousut, harmaa parta.
const SULO := {
	"shirt": Color(0.55, 0.12, 0.1), "pants": Color(0.25, 0.3, 0.2), "shoes": Color(0.12, 0.1, 0.08),
	"hair": "Hair_Buzzed", "hair_color": Color(0.7, 0.7, 0.68), "beard": true, "height": 1.72,
	"skin": Color(1.0, 0.84, 0.78), "belly": 0.45, "bulk": -0.2, "shoulders": -0.3,
}


static func make(parent: Node3D, look: Dictionary) -> Node3D:
	var c := Character.new()
	parent.add_child(c)
	c.setup(look)
	return c


## Pelaajan lippis päähän.
const CAP_NAVY := Color(0.035, 0.035, 0.04)  # musta kuten Karhu-lippiksissä
const CAP_PIPING := Color(1.0, 0.82, 0.1)  # keltainen kerrosraita lipan reunassa
const CAP_OFFSET := Vector3(0, 0.15, 0.005)  # lippiksen origo pääluun lepopaikasta (hahmon avaruudessa)
const CAP_C := Vector3(0, -0.035, -0.015)  # kallon keskipiste lippiksen avaruudessa
const CAP_RIM_FRONT := -0.004  # reunan korkeus otsalla
const CAP_RIM_BACK := -0.072  # ja niskassa (reuna kallistuu taaksepäin)
const CAP_MARGIN := 0.009  # kangas + väli kallon pintaan
const NT := 48
const NP := 18
const PSI_MIN := -60.0
static var _cap_cache := {}


## Karhu-lippis, joka mukailee kaljun pään muotoja: kupu mallinnetaan hahmon oman kallon pinnasta,
## tukka painetaan kuvun alle (näkyy vain reunan alta). Merkki painettuna etupaneeliin, kaareva lippa.
static func add_cap(c: Node3D) -> void:
	var sk: Skeleton3D = c.skeleton
	var rest := sk.get_bone_global_rest(sk.find_bone("Head"))
	var mb: Basis = (c.model.transform * sk.transform).basis
	var body: MeshInstance3D = null
	for mi in sk.get_children():
		if mi is MeshInstance3D and (body == null or mi.mesh.surface_get_array_len(0) > body.mesh.surface_get_array_len(0)):
			body = mi
	var key := str(body.mesh.get_rid())
	if not _cap_cache.has(key):
		var grid := _skull_grid(body.mesh, rest.origin, mb)
		_cap_cache[key] = {"grid": grid, "crown": _cap_crown(grid), "brim": _cap_brim(grid)}
	var data: Dictionary = _cap_cache[key]
	_tuck_hair(sk, body, data.grid, rest.origin, mb)
	var cap := Node3D.new()
	var crown := MeshInstance3D.new()
	crown.mesh = data.crown
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/cap.gdshader")
	cm.set_shader_parameter("cloth", CAP_NAVY)
	cm.set_shader_parameter("logo", load("res://assets/cap_logo.png"))
	crown.material_override = cm
	cap.add_child(crown)
	var brim := MeshInstance3D.new()
	brim.mesh = data.brim
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.vertex_color_is_srgb = true
	bm.roughness = 0.8
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	brim.material_override = bm
	cap.add_child(brim)
	var top := _cap_point(data.grid, 0.0, PI * 0.5)
	B.mesh(cap, B.sphere(0.009, 10), top + Vector3(0, 0.001, 0), CAP_NAVY).scale = Vector3(1, 0.55, 1)  # nappi
	c.attach("Head", cap, CAP_OFFSET)


## Kallon säde suunnittain (θ = kiertokulma, 0 = eteen -Z; ψ = korotuskulma) ilman tukkaa.
static func _skull_grid(mesh: Mesh, origin: Vector3, mb: Basis) -> Array:
	var raw := []
	for i in NT:
		var row := []
		row.resize(NP)
		row.fill(0.0)
		raw.append(row)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for p in verts:
		var q: Vector3 = mb * (p - origin) - CAP_OFFSET
		var d := q - CAP_C
		var r := d.length()
		if r < 0.03 or r > 0.2 or q.y < -0.13:
			continue
		var ti := _t_index(atan2(d.x, -d.z))
		var pj := _p_index(asin(clampf(d.y / r, -1.0, 1.0)))
		if pj >= 0:
			raw[ti][pj] = maxf(raw[ti][pj], r)
	# Aukot täytetään naapureista, sitten laajennus (ettei kupu leikkaa kalloa) ja pehmennys.
	for it in 6:
		for i in NT:
			for j in NP:
				if raw[i][j] == 0.0:
					var sum := 0.0
					var n := 0
					for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
						var jj: int = j + o[1]
						if jj < 0 or jj >= NP:
							continue
						var v: float = raw[(i + o[0] + NT) % NT][jj]
						if v > 0.0:
							sum += v
							n += 1
					if n > 0:
						raw[i][j] = sum / n
	var dil := _grid_pass(raw, true)
	return _grid_pass(dil, false)


static func _grid_pass(g: Array, take_max: bool) -> Array:
	var out := []
	for i in NT:
		var row := []
		for j in NP:
			var acc := 0.0
			var n := 0
			for di in [-1, 0, 1]:
				for dj in [-1, 0, 1]:
					var jj: int = clampi(j + dj, 0, NP - 1)
					var v: float = g[(i + di + NT) % NT][jj]
					acc = maxf(acc, v) if take_max else acc + v
					n += 1
			row.append(acc if take_max else acc / n)
		out.append(row)
	return out


static func _t_index(th: float) -> int:
	return int(floorf(fposmod(th, TAU) / TAU * NT + 0.5)) % NT


static func _p_index(ps: float) -> int:
	var f := (rad_to_deg(ps) - PSI_MIN) / (90.0 - PSI_MIN) * (NP - 1)
	return int(round(f)) if f >= -0.5 and f <= NP - 0.5 else -1


## Kallon säde bilineaarisesti.
static func _skull_r(grid: Array, th: float, ps: float) -> float:
	var ft := fposmod(th, TAU) / TAU * NT
	var fp := clampf((rad_to_deg(ps) - PSI_MIN) / (90.0 - PSI_MIN) * (NP - 1), 0.0, NP - 1.001)
	var i0 := int(floorf(ft)) % NT
	var i1 := (i0 + 1) % NT
	var j0 := int(floorf(fp))
	var tt := ft - floorf(ft)
	var tp := fp - j0
	var a: float = lerpf(grid[i0][j0], grid[i1][j0], tt)
	var b: float = lerpf(grid[i0][j0 + 1], grid[i1][j0 + 1], tt)
	return lerpf(a, b, tp)


static func _dir(th: float, ps: float) -> Vector3:
	return Vector3(sin(th) * cos(ps), sin(ps), -cos(th) * cos(ps))


static func _cap_point(grid: Array, th: float, ps: float) -> Vector3:
	return CAP_C + _dir(th, ps) * (_skull_r(grid, th, ps) + CAP_MARGIN)


## Reunan korotuskulma: reuna kulkee otsalta niskaan kallistuvaa tasoa pitkin.
static func _rim_psi(grid: Array, th: float) -> float:
	var y := lerpf(CAP_RIM_FRONT, CAP_RIM_BACK, (1.0 - cos(th)) * 0.5) - CAP_C.y
	var ps := 0.0
	for it in 4:
		ps = asin(clampf(y / (_skull_r(grid, th, ps) + CAP_MARGIN), -0.95, 0.95))
	return ps


static func _cap_crown(grid: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nv := 16
	var pt := func(i: int, j: int) -> Vector3:
		var th := TAU * i / NT
		var ps := lerpf(_rim_psi(grid, th), PI * 0.5, float(j) / nv)
		return _cap_point(grid, th, ps)
	for i in NT:
		for j in nv:
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
				var p: Vector3 = pt.call(q[0], q[1])
				var du: Vector3 = pt.call(q[0] + 1, q[1]) - pt.call(q[0] - 1, q[1])
				var dv: Vector3 = pt.call(q[0], mini(q[1] + 1, nv)) - pt.call(q[0], maxi(q[1] - 1, 0))
				var n := du.cross(dv).normalized()
				if q[1] == nv or n.length() < 0.5:
					n = Vector3.UP
				if n.dot(p - CAP_C) < 0.0:
					n = -n
				st.set_normal(n)
				st.set_uv(Vector2(float(q[0]) / NT, float(q[1]) / nv))
				st.add_vertex(p)
	return st.commit()


static func _cap_brim(grid: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_col := CAP_NAVY
	var under_col := Color(0.03, 0.03, 0.035)
	var n := 24
	var thick := 0.006
	var inner := []
	var outer := []
	var tips := []
	# Kuvun leveys reunan kohdalla (sivuilla, θ = ±90°).
	var half_w := 0.0
	for th in [PI * 0.5, -PI * 0.5]:
		half_w = maxf(half_w, absf(_cap_point(grid, th, _rim_psi(grid, th)).x))
	half_w *= 0.97
	var front_z := _cap_point(grid, 0.0, _rim_psi(grid, 0.0)).z
	for k in n + 1:
		# Pitkä, pyöreä D-lippa, joka kaartuu voimakkaasti sivuilta alas (esikaareva) ja laskee kärkeä kohti.
		var a := deg_to_rad(lerpf(-80.0, 80.0, float(k) / n))
		var p_in := _cap_point(grid, a, _rim_psi(grid, a)) + Vector3(0, 0.003, 0)
		var d := Vector3(sin(a), 0, -cos(a))
		var reach := 0.088 * pow(maxf(cos(a * 1.1), 0.0), 0.5) + 0.004
		# Ääriviiva ylhäältä: sivut suoraan eteen pään leveydellä (yli menevä osa leikattu pois),
		# etureuna kaartuu pyöreästi sivuihin.
		var p_out := p_in + d * reach
		p_out.x = clampf(p_in.x + d.x * reach * 0.25, -half_w, half_w)
		var u := clampf(absf(p_out.x) / half_w, 0.0, 1.0)
		var outline := front_z - 0.088 * sqrt(maxf(1.0 - pow(u, 2.4), 0.0))
		p_out.z = minf(p_in.z - 0.004, outline)
		var side := pow(sin(a), 2.0)
		p_out.y = p_in.y - 0.022 - 0.05 * side * (reach / 0.09 + 0.3)
		inner.append(p_in)
		outer.append(p_out)
		tips.append(reach)
	# Kolme riviä pituussuunnassa: lippa kaartuu myös pituussuunnassa alaspäin.
	var rows := 3
	var grid_pts := []
	for r in rows + 1:
		var t := float(r) / rows
		var row := []
		for k in n + 1:
			var a_in: Vector3 = inner[k]
			var b_out: Vector3 = outer[k]
			var p := a_in.lerp(b_out, t)
			p.y -= sin(t * PI) * 0.004 * (1.0 - pow(sin(deg_to_rad(lerpf(-80.0, 80.0, float(k) / n))), 2.0))
			row.append(p)
		grid_pts.append(row)
	var dn := Vector3.DOWN * thick
	for r in rows:
		for k in n:
			var a0: Vector3 = grid_pts[r][k]
			var a1: Vector3 = grid_pts[r][k + 1]
			var b0: Vector3 = grid_pts[r + 1][k]
			var b1: Vector3 = grid_pts[r + 1][k + 1]
			var up := (b0 - a0).cross(a1 - a0).normalized()
			if up.y < 0.0:
				up = -up
			for tri in [[a0, b0, b1], [a0, b1, a1]]:
				for v in tri:
					st.set_color(top_col)
					st.set_normal(up)
					st.add_vertex(v)
				for v in [tri[0], tri[2], tri[1]]:
					st.set_color(under_col)
					st.set_normal(-up)
					st.add_vertex(v + dn)
	# Etureunan paksuus: keltainen kerrosraita (sandwich) mustien pintojen välissä.
	for k in n:
		var b0: Vector3 = grid_pts[rows][k]
		var b1: Vector3 = grid_pts[rows][k + 1]
		var prev: Vector3 = grid_pts[rows - 1][k]
		var fwd := (b0 - prev).normalized()
		var mid := dn * 0.5
		for v in [b0, b0 + mid, b1 + mid, b0, b1 + mid, b1]:
			st.set_color(top_col)
			st.set_normal(fwd)
			st.add_vertex(v)
		for v in [b0 + mid, b0 + dn, b1 + dn, b0 + mid, b1 + dn, b1 + mid]:
			st.set_color(CAP_PIPING)
			st.set_normal(fwd)
			st.add_vertex(v)
	return st.commit()


## Tukka kuvun alle: reunan yläpuoliset tukan pisteet painetaan kallon pinnan sisäpuolelle.
static func _tuck_hair(sk: Skeleton3D, body: MeshInstance3D, grid: Array, origin: Vector3, mb: Basis) -> void:
	var inv := mb.inverse()
	for mi in sk.get_children():
		if not (mi is MeshInstance3D) or mi == body or mi.name in ["Eyes", "Eyebrows"]:
			continue
		var src: Mesh = mi.mesh
		var out := ArrayMesh.new()
		for si in src.get_surface_count():
			var arr := src.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts.size():
				var q: Vector3 = mb * (verts[v] - origin) - CAP_OFFSET
				var d := q - CAP_C
				var r := d.length()
				if r < 0.001:
					continue
				var th := atan2(d.x, -d.z)
				var ps := asin(clampf(d.y / r, -1.0, 1.0))
				if ps < _rim_psi(grid, th) + 0.05:
					continue  # reunan alapuolinen tukka näkyy
				var lim := _skull_r(grid, th, ps) + CAP_MARGIN * 0.4
				if r > lim:
					q = CAP_C + d / r * lim
					verts[v] = origin + inv * (q + CAP_OFFSET)
			arr[Mesh.ARRAY_VERTEX] = verts
			var fmt: int = (src as ArrayMesh).surface_get_format(si)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			out.surface_set_material(si, src.surface_get_material(si))
		mi.mesh = out


## Harmaapään kumara selkä.
static func hunch(c: Node3D, amount := 0.3) -> void:
	c.set_override("spine_01", Vector3.RIGHT, -amount * 0.5)
	c.set_override("spine_03", Vector3.RIGHT, -amount * 0.5)
	c.set_override("neck_01", Vector3.RIGHT, amount * 0.6)
