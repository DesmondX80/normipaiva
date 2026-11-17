extends RefCounted
## Anatomia, moduuli "vartalo" (rekisteri: anatomia.gd), osa D: hartiat, rintakehä, selkä, lantio, nivelet ja raajojen lihasrajat.
## deform(ctx): pisteiden siirto lepoasennossa (T-asento, +Z = etu, +Y ylös) ennen Character._reshapea; ei uusia luita eikä
## lisäverkkoja. attach(ctx): ei lisäosia. pose(ch): ei muutoksia. Kaikki siirrot ovat pelkkiä paikan funktioita (ei luukohtaisia
## ehtoja; luiden paikat tulevat vain vakioina), jotta luusaumoissa ja UV-saumoissa kaksoispisteet liikkuvat yhdessä. Normaalit
## korjataan siirtokentän Jacobin matriisilla kuten Character._reshape. Maskia ei tarvita: varjostimen vartalodetaljit
## (anat_vartalo.gdshaderinc) lasketaan lepoasennon koordinaateista (UV2 = x, y; CUSTOM0.x = z) ihoalueilla.
## Mittasuhteet (male/female, mitattu ANATD-riveistä): kaikki amplitudit ovat millimetrejä ja mitoitettu pehmeiksi (<= 6 mm),
## koska verkko on harva (vartalolla n. 1-2 cm) ja Character._shape_offset (belly, muscle, shoulders, bust) tulee päälle.

const WRIST_FRAC := 0.8  ## kyynärvarren osuus, jonka jälkeen ranne (anatomia_kadet.gd) hoitaa kavennuksen


## Lähin piste akselilla a-b: (t 0..1, etäisyys, säteen suunta akselista pisteeseen).
static func _axis(p: Vector3, a: Vector3, b: Vector3) -> Array:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var r := p - (a + ab * t)
	return [t, r.length(), r.normalized() if r.length() > 1e-6 else Vector3.UP]


static func _bump(x: float, c: float, w: float) -> float:
	var d := (x - c) / w
	return exp(-d * d)


## Siirtokenttä pisteelle p (lepoasento, p.x symmetrinen). j = nivelet (joints), f = sukupuoli, belly = vatsan voimakkuus.
static func _shift(p: Vector3, j: Dictionary, female: bool, belly: float, bare: float) -> Vector3:
	var d := Vector3.ZERO
	var ax := absf(p.x)
	var sx := signf(p.x) if ax > 1e-6 else 0.0
	var g := 0.6 if female else 1.0  # naisella lihasrajat pehmeämpiä
	var torso_x := 1.0 - smoothstep(0.2, 0.28, ax)
	var front := smoothstep(0.0, 0.05, p.z)
	var back := 1.0 - smoothstep(-0.07, -0.02, p.z)
	# --- Solisluu: harjanne etuyläpinnalla ja kuoppa sen yläpuolella (kaulan ja rinnan välinen pehmeä rajapinta).
	var clav_y := 1.455 + 0.012 * smoothstep(0.03, 0.14, ax) - 0.0 * ax
	var clav := _bump(p.y, clav_y, 0.011) * smoothstep(0.025, 0.05, ax) * (1.0 - smoothstep(0.13, 0.19, ax)) * front
	d.z += (0.0032 if not female else 0.0022) * clav
	var hollow := _bump(p.y, clav_y + 0.034, 0.014) * smoothstep(0.02, 0.05, ax) * (1.0 - smoothstep(0.1, 0.15, ax)) * front
	d.z -= 0.0025 * hollow
	# --- Rintalihakset (miehellä): ulkoreuna ja alareuna erottuvat, rintalastan kohdalla matala ura. Naisella vain
	# yläosan pehmeä täyttö solisluun ja rinnan välillä (rinnan mitat ja muoto tulevat _bust:sta ennallaan).
	if not female:
		var pec := _bump(p.y, 1.375, 0.05) * smoothstep(0.015, 0.05, ax) * (1.0 - smoothstep(0.14, 0.2, ax)) * front * torso_x
		var low := smoothstep(1.3, 1.345, p.y)  # alareunan jyrkkyys: lihas loppuu terävämmin kuin alkaa
		d.z += 0.007 * pec * (0.6 + 0.4 * low) * (1.0 - 0.6 * clampf(belly, 0.0, 1.0))
		var groove := _bump(ax, 0.0, 0.012) * smoothstep(1.27, 1.33, p.y) * (1.0 - smoothstep(1.4, 1.44, p.y)) * front
		d.z -= 0.0025 * groove
	else:
		var upper := _bump(p.y, 1.405, 0.035) * smoothstep(0.02, 0.05, ax) * (1.0 - smoothstep(0.1, 0.16, ax)) * front
		d.z += 0.0035 * upper
	# --- Selkä: lapaluut (kärki alas ja sisään), selkäranka-ura, alaselän lantiokuopat; vain selkäpinta.
	for sgn in [-1.0, 1.0]:
		var sc := Vector2((p.x - sgn * 0.105) / 0.055, (p.y - 1.385) / 0.07)
		var blade := exp(-(sc.x * sc.x + sc.y * sc.y)) * back * torso_x
		d.z -= 0.0045 * g * blade
	var spine_g := _bump(ax, 0.0, 0.013) * smoothstep(1.05, 1.2, p.y) * (1.0 - smoothstep(1.44, 1.5, p.y)) * back
	d.z += 0.0035 * g * spine_g
	var lat := _bump(p.y, 1.27, 0.07) * smoothstep(0.1, 0.17, ax) * (1.0 - smoothstep(0.22, 0.28, ax)) * back
	d.z -= 0.003 * g * lat
	# --- Lantio: suoliluun harjanne ja iso sarvennoinen (reisiluun yläpää) sivuilla, pakaran alareunan taive.
	var iliac := _bump(p.y, 1.015, 0.035) * smoothstep(0.1, 0.16, ax) * (1.0 - smoothstep(0.2, 0.26, ax))
	d.x += sx * 0.0035 * iliac * (0.7 if female else 1.0)
	var troch := _bump(p.y, 0.92, 0.045) * smoothstep(0.12, 0.17, ax) * (1.0 - smoothstep(0.2, 0.26, ax))
	d.x += sx * 0.003 * troch * (1.4 if female else 1.0)
	var glute := _bump(p.y, 0.88, 0.05) * back * (1.0 - smoothstep(0.15, 0.22, ax))
	d.z -= 0.004 * (1.3 if female else 1.0) * glute
	# --- Raajat: lihasrajat akselin suhteen (säde), nivelmuodot.
	d += _limb_shift(p, j, female, bare)
	return d


## Raajojen lihasrajat ja nivelet. Käsivarsi: hartialihas, hauis/ojentaja, kyynärpää, kyynärvarren paksu yläosa; jalka: etureisi,
## polvilumpio ja polvitaive, pohje. Amplitudit nollaan segmentin päissä (jatkuva siirto nivelen yli).
static func _limb_shift(p: Vector3, j: Dictionary, female: bool, bare: float) -> Vector3:
	var d := Vector3.ZERO
	var ax := absf(p.x)
	var sx := signf(p.x) if ax > 1e-6 else 1.0
	var sfx := "_l" if sx > 0.0 else "_r"
	var g := 0.65 if female else 1.0
	# Käsivarsi (vain vartalon ulkopuolella)
	if ax > 0.2 and j.has("upperarm" + sfx) and j.has("lowerarm" + sfx) and j.has("hand" + sfx):
		var sh: Vector3 = j["upperarm" + sfx]
		var el: Vector3 = j["lowerarm" + sfx]
		var wr: Vector3 = j["hand" + sfx]
		var u := _axis(p, sh, el)
		var w_in := 1.0 - smoothstep(0.065, 0.1, u[1] as float)
		var tu: float = u[0]
		var prof_u := 0.004 * _bump(tu, 0.2, 0.14) + 0.0032 * _bump(tu, 0.55, 0.16) - 0.0025 * smoothstep(0.8, 1.0, tu) * 1.0
		# jatkuvuus: nivelessä 0 (alla elbow-profiili 0 loppu), liukuva alku olkapäällä
		prof_u *= smoothstep(0.02, 0.12, tu) * (1.0 - smoothstep(0.92, 1.0, tu))
		d += (u[2] as Vector3) * prof_u * g * w_in * smoothstep(0.2, 0.26, ax)
		var l := _axis(p, el, wr)
		var tl: float = l[0]
		var wl := 1.0 - smoothstep(0.055, 0.085, l[1] as float)
		var prof_l := 0.0045 * _bump(tl, 0.22, 0.17) - 0.0025 * smoothstep(0.55, WRIST_FRAC, tl)
		prof_l *= smoothstep(0.0, 0.06, tl) * (1.0 - smoothstep(0.9, 1.0, tl))
		d += (l[2] as Vector3) * prof_l * g * wl
		# Kyynärpää: olecranon taakse (-Z), kyynärtaive (etupuolella lievä kuoppa)
		var ec := el + Vector3(0, 0, -0.03)
		var ge := _bump((p - ec).length(), 0.0, 0.04)
		d.z -= 0.0045 * ge * smoothstep(0.01, -0.01, p.z - el.z)
		var gf := _bump((p - (el + Vector3(0, 0, 0.035))).length(), 0.0, 0.035)
		d.z += 0.0015 * gf * smoothstep(-0.01, 0.01, p.z - el.z)
	# Jalka
	if ax > 0.02 and j.has("thigh" + sfx) and j.has("calf" + sfx) and j.has("foot" + sfx):
		var hp: Vector3 = j["thigh" + sfx]
		var kn: Vector3 = j["calf" + sfx]
		var an: Vector3 = j["foot" + sfx]
		var tg := _axis(p, hp, kn)
		var wt := 1.0 - smoothstep(0.11, 0.16, tg[1] as float)
		var tt: float = tg[0]
		var prof_t := 0.0045 * _bump(tt, 0.42, 0.2) - 0.0035 * smoothstep(0.8, 1.0, tt)
		prof_t *= smoothstep(0.12, 0.3, tt) * (1.0 - smoothstep(0.93, 1.0, tt))
		# etureisi (ulos eteen) painottuu etupuolelle, takareisi tasaisempi
		var rd := tg[2] as Vector3
		d += rd * prof_t * g * wt * (0.6 + 0.4 * smoothstep(-0.3, 0.5, rd.z))
		var cg := _axis(p, kn, an)
		var tc: float = cg[0]
		var wc := 1.0 - smoothstep(0.08, 0.12, cg[1] as float)
		var rc := cg[2] as Vector3
		# pohje: takana kaksoiskantalihas (t 0,1..0,5), edessä säären harjanne ohut; nilkan yläosa kapenee
		var calf := (0.006 * _bump(tc, 0.2, 0.12) * smoothstep(-0.2, 0.6, -rc.z) + 0.0012 * _bump(tc, 0.3, 0.15) * smoothstep(0.3, 0.9, rc.z)
			- 0.0025 * smoothstep(0.7, 0.95, tc))
		calf *= smoothstep(0.0, 0.08, tc) * (1.0 - smoothstep(0.93, 1.0, tc))
		# Kengät rakennetaan paistetusta jalkaverkosta (Shoes.build): varsi ja jalkaterän iho eivät saa liikkua, joten säären alaosa
		# (t > 0,3: kengän varren ja nilkan alue) muuttuu vain paljaalla jalalla (shape.anat_arch)
		calf *= 1.0 - (1.0 - bare) * smoothstep(0.18, 0.3, tc)
		d += rc * calf * g * wc * (1.15 if not female else 0.8)
		# Polvilumpio (eteen) ja polvitaive (taakse)
		var pc := kn + Vector3(0, 0.012, 0.045)
		var gp := _bump((p - pc).length(), 0.0, 0.038)
		d.z += 0.006 * gp * smoothstep(-0.005, 0.02, p.z - kn.z)
		var pop := _bump((p - (kn + Vector3(0, 0.0, -0.05))).length(), 0.0, 0.04)
		d.z += 0.0025 * pop * smoothstep(0.005, -0.02, p.z - kn.z)
	return d


static func deform(ctx: Dictionary) -> void:
	var arr: Array = ctx.arr
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var j: Dictionary = ctx.joints
	var shape: Dictionary = ctx.shape
	var female: bool = ctx.kind == "female"
	var belly: float = shape.get("belly", 0.0)
	var bare: float = shape.get("anat_arch", 0.0)
	var h := 0.004
	for v in vs.size():
		var p := vs[v]
		if p.y > 1.52 and absf(p.x) < 0.12:
			continue  # kaula ja pää: anatomia_paa.gd
		var d := _shift(p, j, female, belly, bare)
		if d.length_squared() < 1e-10:
			continue
		var jx := (_shift(p + Vector3(h, 0, 0), j, female, belly, bare) - d) / h
		var jy := (_shift(p + Vector3(0, h, 0), j, female, belly, bare) - d) / h
		var jz := (_shift(p + Vector3(0, 0, h), j, female, belly, bare) - d) / h
		var m := Basis(Vector3(1, 0, 0) + jx, Vector3(0, 1, 0) + jy, Vector3(0, 0, 1) + jz)
		vs[v] = p + d
		if m.determinant() > 0.2:
			ns[v] = (m.inverse().transposed() * ns[v]).normalized()
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns


static func attach(_ctx: Dictionary) -> Array:
	return []


static func pose(_ch: Node3D) -> void:
	pass
