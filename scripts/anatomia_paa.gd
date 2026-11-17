extends RefCounted
## Anatomia, moduuli "paa" (rekisteri: anatomia.gd): pehmeämpi kallo, poskipäät, leuka ja leukalinja, kaulan tyvi ja trapetsin kaari.
## deform(ctx): pisteiden siirto lepoasennossa + pään maski COLOR.r:n murto-osaan (koodi 10 pää, 11 kaula; varjostin maalaa
## huulet, silmäkuopat, poimut ja huokoset anat_paa.gdshaderincissä). attach(ctx): ei lisäverkkoja. pose(ch): ei muutoksia (ei leukaluuta).
## Koordinaatit: lepoasento, +Z = kasvojen etupuoli, +Y ylös. Pään kehys FRAME: alin y (leuka) ja korkeus; yn = (y - y0) / h,
## joten sama koodi sopii mies- ja naismalliin (nenä yn 0,34, silmät 0,52, suu 0,14 molemmilla).
## Kaikki siirrot ovat pelkkiä paikan funktioita (ei luukohtaisia ehtoja), jotta luusaumoissa ja UV-saumoissa kaksoispisteet liikkuvat yhdessä.
## Hiukset sovitetaan alkuperäiseen verkkoon (character.gd body_src): yläkallon siirrot pidetään <= 1,5 mm.

## Pään kehys: (alin y, korkeus) lepoasennossa (Head-luun pisteiden min/max, mitattu).
const FRAME := {"male": Vector2(1.5766, 0.2335), "female": Vector2(1.5381, 0.2285)}
## Silmien keskikohta (yn) ja puoliväli (x): Eyes-verkko ei siirry, joten silmien ympäristö jätetään paikalleen.
const EYE_YN := 0.52
const EYE_X := 0.031
const CODE_HEAD := 10
const CODE_NECK := 11


static func frame(kind: String) -> Vector2:
	return FRAME.get(kind, FRAME["male"])


## Siirto pisteelle p (lepoasento), p.x symmetrinen. k = sukupuolikerroin (leuka ja poskipäät).
static func _shift(p: Vector3, f: Vector2, female: bool) -> Vector3:
	var yn := (p.y - f.x) / f.y
	var ax := absf(p.x)
	var sx := signf(p.x) if ax > 1e-6 else 0.0
	var d := Vector3.ZERO
	# Silmien suoja: ei siirtoa silmäkuopan kohdalla (Eyes ja Eyebrows ovat omia verkkojaan).
	var ey := f.x + EYE_YN * f.y
	var eye_d := Vector2(ax - EYE_X, (p.y - ey) * 1.2).length()
	var protect := smoothstep(0.026, 0.05, eye_d)
	# 1) alaleuka leveämmäksi ja leuka pyöreämmäksi: x-skaala suurimmillaan leuan kohdalla, vain etu- ja sivupuolella (ei niskaa)
	var lower := (1.0 - smoothstep(0.0, 0.36, yn)) * smoothstep(-0.14, 0.0, yn)
	var side := smoothstep(-0.07, 0.02, p.z)
	var wide := (0.14 if female else 0.21) * lower * side
	d.x += p.x * wide
	# leuan kärki eteen ja alas: V-leuasta pyöreämpi
	var chin := (1.0 - smoothstep(0.0, 0.05, Vector2(ax, p.z - 0.075).length()) ) * (1.0 - smoothstep(0.0, 0.09, yn))
	d.z += 0.004 * chin
	# leukakulma (gonion): ulos ja alas korvan alla, jotta leukalinja erottuu kaulasta
	var gon := exp(-(pow((ax - 0.062) / 0.022, 2.0) + pow((yn - 0.08) / 0.07, 2.0) + pow((p.z + 0.03) / 0.04, 2.0)))
	d.x += sx * 0.004 * gon
	d.y -= 0.003 * gon
	# 2) poskipäät: ulos ja eteen silmän alla, poskionkalo sen alla (ei silmäkuoppien lähellä)
	var cb := exp(-(pow((ax - 0.064) / 0.022, 2.0) + pow((yn - 0.43) / 0.09, 2.0) + pow((p.z - 0.035) / 0.05, 2.0)))
	d.x += sx * 0.0035 * cb
	d.z += 0.002 * cb
	var hollow := exp(-(pow((ax - 0.05) / 0.02, 2.0) + pow((yn - 0.27) / 0.06, 2.0) + pow((p.z - 0.05) / 0.04, 2.0)))
	d.x -= sx * 0.001 * hollow  # korjauskierros: poskionkalo hillitty (väsynyt ilme)
	# 3) ohimot: otsa ja ohimo kapeammaksi (ylhäällä enintään 1,5 mm)
	var temple := smoothstep(0.55, 0.78, yn) * (1.0 - smoothstep(0.92, 1.0, yn))
	d.x -= sx * 0.0015 * temple
	return d * protect


## Kaulan tyvi ja trapetsin kaari: kaula levenee alaspäin, olan ja kaulan välinen kaari nousee. y-alue kaulan tyvestä rintaan.
static func _neck_shift(p: Vector3, f: Vector2, female: bool) -> Vector3:
	var yn := (p.y - f.x) / f.y
	var ax := absf(p.x)
	var d := Vector3.ZERO
	var base := 1.0 - smoothstep(-0.45, -0.08, yn)  # 1 kaulan tyvellä, 0 leuan alla
	if ax < 0.115 and yn > -0.75 and yn < 0.0:
		# kaulan sivut levenevät hitaasti alaspäin (sileä kulku hartiaan), vain keskellä
		var core := 1.0 - smoothstep(0.075, 0.115, ax)
		d.x += p.x * 0.10 * base * base * core
		# trapetsi: olan yläreuna nousee kaulan vierestä (x 0,05..0,2), huippu x 0,10
		var trap := smoothstep(0.045, 0.085, ax) * (1.0 - smoothstep(0.11, 0.115, ax))
		d.y += 0.003 * trap * base  # D: 11 mm nosti hartian yläreunaa 4-10 mm (raja 2 mm): kaari tehdään pääosin sivusuunnassa (kaulan tyven levennys)
	# trapetsin ulompi osa (olkaan päin): pehmeä nousu x 0,10..0,22
	var tr2 := smoothstep(0.085, 0.12, ax) * (1.0 - smoothstep(0.15, 0.23, ax))
	var yb := smoothstep(-0.62, -0.42, yn) * (1.0 - smoothstep(-0.2, 0.0, yn))
	d.y += 0.003 * tr2 * yb
	return d


static func _weld_key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 10000.0), roundi(p.y * 10000.0), roundi(p.z * 10000.0))


## Pehmennyspaino (0..1) pään pisteelle: kallo, ohimot, poski ja leuka pehmenevät; silmät, nenä, suu ja korvat pidetään.
static func _smooth_weight(p: Vector3, f: Vector2) -> float:
	var yn := (p.y - f.x) / f.y
	var ax := absf(p.x)
	var w := 1.0
	var ey := f.x + EYE_YN * f.y
	w *= smoothstep(0.03, 0.06, Vector2(ax - EYE_X, (p.y - ey) * 1.2).length())
	# nenä
	w *= 1.0 - (1.0 - smoothstep(0.02, 0.04, ax)) * smoothstep(0.2, 0.26, yn) * (1.0 - smoothstep(0.42, 0.5, yn)) * smoothstep(0.05, 0.08, p.z)
	# suu
	w *= 1.0 - (1.0 - smoothstep(0.035, 0.06, ax)) * smoothstep(0.04, 0.09, yn) * (1.0 - smoothstep(0.21, 0.26, yn)) * smoothstep(0.03, 0.06, p.z)
	# korvat
	w *= 1.0 - smoothstep(0.065, 0.075, ax) * (1.0 - smoothstep(0.04, 0.07, absf(p.z + 0.01))) * smoothstep(0.25, 0.4, yn) * (1.0 - smoothstep(0.62, 0.72, yn))
	return w


static func deform(ctx: Dictionary) -> void:
	var arr: Array = ctx.arr
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var vb: PackedStringArray = ctx.vbone
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var kind: String = ctx.kind
	var female := kind == "female"
	var f := frame(kind)
	var n := vs.size()
	# Hitsatut pisteryhmät (sama paikka = sama ryhmä), jotta siirrot ja pehmennys eivät revi UV- ja luusaumoja.
	var gid := PackedInt32Array()
	gid.resize(n)
	var key2g := {}
	var gpos := PackedVector3Array()
	var ghead := PackedByteArray()  # 1 jos kaikki ryhmän pisteet ovat Head-luussa
	for v in n:
		var k := _weld_key(vs[v])
		if not key2g.has(k):
			key2g[k] = gpos.size()
			gpos.append(vs[v])
			ghead.append(1)
		var g: int = key2g[k]
		gid[v] = g
		if vb[v] != "Head":
			ghead[g] = 0
	var gn_before := _group_normals(gpos, gid, idx)
	var gc := gpos.size()
	# Pehmennys (Taubin: lambda 0,5 / mu -0,53, 2 kierrosta): vain pään omat ryhmät, naapurit samasta kolmiosta.
	var nbr: Array = []
	nbr.resize(gc)
	var gw := PackedFloat32Array()
	gw.resize(gc)
	for g in gc:
		nbr[g] = []
		gw[g] = _smooth_weight(gpos[g], f) if ghead[g] == 1 else 0.0
	var t := 0
	while t + 2 < idx.size():
		var a := gid[idx[t]]
		var b := gid[idx[t + 1]]
		var c := gid[idx[t + 2]]
		for pr in [[a, b], [b, c], [c, a]]:
			var x: int = pr[0]
			var y: int = pr[1]
			if x != y and gw[x] > 0.0 and not (nbr[x] as Array).has(y):
				(nbr[x] as Array).append(y)
			if x != y and gw[y] > 0.0 and not (nbr[y] as Array).has(x):
				(nbr[y] as Array).append(x)
		t += 3
	var cur := gpos.duplicate()
	for it in 4:
		var lam := 0.5 if it % 2 == 0 else -0.53
		var nxt := cur.duplicate()
		for g in gc:
			var nb: Array = nbr[g]
			if gw[g] <= 0.0 or nb.is_empty():
				continue
			var avg := Vector3.ZERO
			for o in nb:
				avg += cur[o]
			avg /= float(nb.size())
			nxt[g] = cur[g] + (avg - cur[g]) * lam * gw[g]
		cur = nxt
	# Muotosiirrot (kaikille pisteille paikan mukaan) pehmennetyn päälle; yläkallon siirto rajoitetaan pehmennyksessä.
	for g in gc:
		var p: Vector3 = cur[g]
		var q := p + _shift(p, f, female) + _neck_shift(p, f, female)
		# yläkallo: kokonaissiirto enintään 1,5 mm alkuperäisestä (hiukset ja lippis sovitettu alkuperäiseen)
		var yn := (gpos[g].y - f.x) / f.y
		var top := smoothstep(0.58, 0.7, yn)
		var dd := q - gpos[g]
		var lim := lerpf(1.0, 0.0015 / maxf(dd.length(), 0.0015), top)
		cur[g] = gpos[g] + dd * minf(lim, 1.0)
	var gn_after := _group_normals(cur, gid, idx)
	for v in n:
		var g := gid[v]
		var dv: Vector3 = cur[g] - gpos[g]
		if dv.length_squared() > 1e-12:
			vs[v] = vs[v] + dv
			ns[v] = (ns[v] + gn_after[g] - gn_before[g]).normalized()
	# Maski: pää 10, kaula 11 (COLOR.r:n murto-osa, kuten kädet; luokka säilyy).
	for v in n:
		var code := 0
		if vb[v] == "Head":
			code = CODE_HEAD
		elif vb[v] == "neck_01":
			code = CODE_NECK
		if code > 0:
			var c := cols[v]
			c.r = (roundf(c.r * 4.0) + 0.04 * float(code)) / 4.0
			cols[v] = c
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_COLOR] = cols


## Ryhmäkohtaiset pintanormaalit (pinta-alalla painotettu summa kaikista kolmioista, joissa ryhmä on kärkenä).
static func _group_normals(gp: PackedVector3Array, gid: PackedInt32Array, idx: PackedInt32Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(gp.size())
	var t := 0
	while t + 2 < idx.size():
		var a := gid[idx[t]]
		var b := gid[idx[t + 1]]
		var c := gid[idx[t + 2]]
		var fn := (gp[c] - gp[a]).cross(gp[b] - gp[a])  # Godotin kiertosuunta on myötäpäivään: ulospäin
		out[a] += fn
		out[b] += fn
		out[c] += fn
		t += 3
	for g in out.size():
		out[g] = out[g].normalized()
	return out


## Kulmakarvat (Eyebrows-solmu, oma verkko): ohuemmat ja luonnollisempi kaari. Sisäpää nousee (alkuperäinen kulma on tuima),
## kaari huipentuu ulkoreunan kolmanneksessa ja häntä laskee; paksuus pienenee keskilinjan ympäri. Verkko rakennetaan kerran
## sukupuolta kohden (vain y muuttuu, enintään 3 mm; ihon pinta pysyy paikallaan, z ennallaan).
static var _brow_cache := {}

static func brows(mi: MeshInstance3D, kind: String) -> void:
	var src := mi.mesh as ArrayMesh
	if src == null or src.get_surface_count() == 0 or src.has_meta("anat_brows"):
		return
	if not _brow_cache.has(kind):
		var arr := src.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		# keskilinja: kunkin x-lokeron (4 mm) keskimääräinen y
		var sum := {}
		var cnt := {}
		for v in vs.size():
			var k := roundi(absf(vs[v].x) / 0.004)
			sum[k] = float(sum.get(k, 0.0)) + vs[v].y
			cnt[k] = int(cnt.get(k, 0)) + 1
		for v in vs.size():
			var p := vs[v]
			var ax := absf(p.x)
			var k := roundi(ax / 0.004)
			var yc: float = float(sum[k]) / float(cnt[k])
			var tn := clampf((ax - 0.012) / 0.05, 0.0, 1.0)  # 0 sisäpää .. 1 ulkopää
			var lift := 0.0028 * (1.0 - tn) - 0.0008 * tn * tn + 0.0022 * sin(minf(tn * 1.3, 1.0) * PI)  # sisäpää ylös, kaari, häntä alas
			p.y = yc + (p.y - yc) * 0.74 + lift
			vs[v] = p
		arr[Mesh.ARRAY_VERTEX] = vs
		var nm := ArrayMesh.new()
		nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, _flags(src.surface_get_format(0)))
		nm.surface_set_material(0, src.surface_get_material(0))
		nm.set_meta("anat_brows", true)
		_brow_cache[kind] = nm
	mi.mesh = _brow_cache[kind]


## Pinnan lisämuodon liput (kustomkanavien tyypit ja 8 luupainoa), jotta verkko voidaan luoda uudelleen samoista taulukoista.
static func _flags(fmt: int) -> int:
	var fl := fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	for sh in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]:
		fl |= fmt & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << sh)
	return fl


static func attach(_ctx: Dictionary) -> Array:
	return []


static func pose(_ch: Node3D) -> void:
	pass
