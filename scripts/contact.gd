## Kontaktit: istujan kapselimalli (luukohtaiset kapselit ja jalkaterän laatikko) ja tunkeumien korjaus kalusteen
## muotoja (Seat) vastaan. Malli lasketaan paistetusta verkosta kerran hahmotyyppiä kohden ja tallennetaan välimuistiin,
## joten istuttaminen ei maksa ruutukohtaista työtä. Paistettu verkko (Pose.limb_points) on totuus vain testissä.
## Kaikki laskenta on maailman avaruudessa. Ei lataa pose.gd:tä (silmukka): limb_points annetaan profile-kutsulle.

const Seat := preload("res://scripts/seat.gd")
const Elastic := preload("res://scripts/elastic.gd")

## Kapselit: [luu a, luu b, avain]; kapseli kulkee luun a paikasta luun b paikkaan, säde luetaan verkosta.
const TORSO := [["pelvis", "spine_01"], ["spine_01", "spine_02"], ["spine_02", "spine_03"], ["spine_03", "neck_01"]]
const LIMBS := [["thigh", "calf"], ["calf", "foot"], ["upperarm", "lowerarm"], ["lowerarm", "hand"]]
## Varataulukko, kun verkkoa ei saada (headless): säteet 1,8 m hahmolle, mitattu profile-kutsulla (tulostus PROFIILI).
const FALLBACK_R := {"pelvis": 0.16, "spine_01": 0.15, "spine_02": 0.15, "spine_03": 0.17, "thigh": 0.12, "calf": 0.082,
	"upperarm": 0.045, "lowerarm": 0.04}
const FALLBACK_FOOT := {"heel": 0.044, "toe": 0.21, "sole": 0.094}
static var _cache := {}


## Kapselit ja jalkaterän laatikko hahmolle: {"caps": {luu a: [a, b, säde]}, "foot": {"_l": {heel, toe, sole}, "_r": ...}}.
## Säde = 90. persentiili verteksien etäisyydestä luujanaan (housun pöyhennys mukana), jalkaterä mitataan nilkan
## luun akseleissa (eteen = lepoasennon -Z, alas = lepoasennon -Y), ei arvata etumerkkejä. limb_points = Pose.limb_points.
static func profile(ch: Node3D, limb_points: Callable) -> Dictionary:
	var key: String = ch.profile_key
	if _cache.has(key):
		return _cache[key]
	var sc: float = ch.model.scale.x
	var caps := {}
	var foot := {}
	var measured := false
	var can_bake := DisplayServer.get_name() != "headless" and Engine.get_process_frames() >= int(ch.born_frame) + 3  # tuoreen hahmon luusto ei ole valmis heti
	for lr: String in ["_l", "_r"]:
		var segs := []
		if lr == "_l":
			segs.append_array(TORSO)
		for s in LIMBS:
			segs.append([s[0] + lr, s[1] + lr])
		for s in segs:
			var pts: PackedVector3Array = limb_points.call(ch, ch, [s[0]]) if can_bake else PackedVector3Array()
			var r: float = FALLBACK_R[str(s[0]).trim_suffix(lr)] * sc
			if not pts.is_empty():
				measured = true
				var a: Vector3 = ch.bone_position(s[0])
				var b: Vector3 = ch.bone_position(s[1])
				var ds := []
				for q in pts:
					ds.append(_seg_dist(q, a, b))
				ds.sort()
				r = clampf(ds[int(ds.size() * 0.9)], r * 0.6, r * 1.6)  # rajaa poikkeamat (kesken päivittyvä asento)
			caps[s[0]] = [s[0], s[1], r]
		foot[lr] = _foot_box(ch, lr, limb_points, can_bake)
	var prof := {"caps": caps, "foot": foot, "measured": measured}
	if measured:
		_cache[key] = prof
	return prof


static func _foot_box(ch: Node3D, lr: String, limb_points: Callable, can_bake: bool) -> Dictionary:
	var sc: float = ch.model.scale.x
	var out := {"heel": FALLBACK_FOOT.heel * sc, "toe": FALLBACK_FOOT.toe * sc, "sole": FALLBACK_FOOT.sole * sc}
	var pts: PackedVector3Array = limb_points.call(ch, ch, ["foot" + lr, "ball" + lr]) if can_bake else PackedVector3Array()
	if pts.is_empty():
		return out
	var fx := []
	var sy := []
	var ankle: Vector3 = ch.bone_position("foot" + lr)
	var bc := foot_basis(ch, lr, false)
	var br := foot_basis(ch, lr, true)
	var f_loc: Vector3 = br.inverse() * Vector3(0, 0, -1)
	var d_loc: Vector3 = br.inverse() * Vector3(0, -1, 0)
	var inv := bc.inverse()
	for q in pts:
		var l: Vector3 = inv * (q - ankle)
		fx.append(l.dot(f_loc))
		sy.append(l.dot(d_loc))
	fx.sort()
	sy.sort()
	out.heel = -fx[int(fx.size() * 0.02)]
	out.toe = fx[int(fx.size() * 0.98)]
	out.sole = sy[int(sy.size() * 0.99)]
	return out


## Jalkaterän luun kantana hahmon avaruudessa (nykyasennossa tai lepoasennossa).
static func foot_basis(ch: Node3D, lr: String, rest: bool) -> Basis:
	var i: int = ch.skeleton.find_bone("foot" + lr)
	var g: Basis = ch.skeleton.get_bone_global_rest(i).basis if rest else ch.skeleton.get_bone_global_pose(i).basis
	return ((ch.model.transform * ch.skeleton.transform).basis * g).orthonormalized()


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _seg_closest(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	return a + ab * clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)


# --- Kiinteät kappaleet -----------------------------------------------------------------------------------------

## Kalusteen kappaleet maailman avaruudessa: [Transform3D, laji, koko].
static func world_solids(node: Node3D) -> Array:
	var out := []
	for s in Seat.of(node).get("solids", []):
		out.append([node.global_transform * (s[0] as Transform3D), s[1], s[2]])
	return out


## Pisteen syvyys kappaleen sisällä (> 0 sisällä, < 0 ulkona); p ja kappale samassa avaruudessa.
static func depth(solid: Array, p: Vector3) -> float:
	var q: Vector3 = (solid[0] as Transform3D).affine_inverse() * p
	var sz: Vector3 = solid[2]
	if solid[1] == "box":
		var h := sz * 0.5
		return minf(h.x - absf(q.x), minf(h.y - absf(q.y), h.z - absf(q.z)))
	return minf(sz.x - Vector2(q.x, q.z).length(), sz.y * 0.5 - absf(q.y))


## Pisteen syvyys primitiivin sisällä paikallisessa avaruudessa (<= 0: ulkona). upl = ylös paikallisessa avaruudessa,
## tol = ylöspäin osoittavan pinnan sietoraja. (Siirretty tools/testit/asento.gd:stä.)
static func depth_local(m: Mesh, p: Vector3, upl: Vector3, tol: float) -> float:
	if m is BoxMesh:
		var h: Vector3 = (m as BoxMesh).size * 0.5
		var best := INF
		for ax in 3:
			for sg in [-1.0, 1.0]:
				var dd: float = h[ax] - sg * p[ax]
				if upl[ax] * sg > 0.7:
					dd -= tol
				best = minf(best, dd)
		return best
	if m is CylinderMesh:
		var c := m as CylinderMesh
		var t := clampf(p.y / c.height + 0.5, 0.0, 1.0)
		var rad := lerpf(c.bottom_radius, c.top_radius, t)
		var dtop: float = c.height * 0.5 - p.y - (tol if upl.y > 0.7 else 0.0)
		var dbot: float = c.height * 0.5 + p.y - (tol if upl.y < -0.7 else 0.0)
		return minf(minf(dtop, dbot), rad - Vector2(p.x, p.z).length())
	if m is SphereMesh:
		return (m as SphereMesh).radius - p.length() - (tol if p.normalized().dot(upl) > 0.7 else 0.0)
	if m is CapsuleMesh:
		var cm := m as CapsuleMesh
		var seg := maxf(cm.height * 0.5 - cm.radius, 0.0)
		var q := Vector3(p.x, p.y - clampf(p.y, -seg, seg), p.z)
		return cm.radius - q.length() - (tol if q.normalized().dot(upl) > 0.7 else 0.0)
	return -1.0


## Korkein yläpinta pisteen (x, z) alapuolella, alkaen korkeudelta from_y alaspäin; muut kappaleet kuin ne, joiden
## sisällä lähtöpiste on. -INF, jos ei osu mihinkään.
static func support_y(solids: Array, x: float, z: float, from_y: float) -> float:
	var best := -INF
	for s in solids:
		var xf: Transform3D = s[0]
		var inv := xf.affine_inverse()
		var o: Vector3 = inv * Vector3(x, from_y, z)
		var dir: Vector3 = inv.basis * Vector3.DOWN
		var t := INF
		if s[1] == "box":
			var h: Vector3 = (s[2] as Vector3) * 0.5
			var t0 := -INF
			var t1 := INF
			for ax in 3:
				if absf(dir[ax]) < 0.00001:
					if absf(o[ax]) > h[ax]:
						t0 = INF
					continue
				var ta: float = (-h[ax] - o[ax]) / dir[ax]
				var tb: float = (h[ax] - o[ax]) / dir[ax]
				t0 = maxf(t0, minf(ta, tb))
				t1 = minf(t1, maxf(ta, tb))
			if t0 <= t1 and t0 >= 0.0:
				t = t0
		else:
			var sz: Vector3 = s[2]
			if absf(dir.y) > 0.00001:
				var tc: float = (sz.y * 0.5 - o.y) / dir.y
				if tc >= 0.0 and Vector2(o.x + dir.x * tc, o.z + dir.z * tc).length() <= sz.x:
					t = tc
		if t < INF:
			best = maxf(best, (xf * (o + dir * t)).y)
	return best


static func _top_y(s: Array) -> float:
	var xf: Transform3D = s[0]
	var h: Vector3 = (s[2] as Vector3) * 0.5 if s[1] == "box" else Vector3(s[2].x, s[2].y * 0.5, s[2].x)
	var top := -INF
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				top = maxf(top, (xf * (h * Vector3(sx, sy, sz))).y)
	return top


# --- Korjaukset -------------------------------------------------------------------------------------------------

static func _caps_world(ch: Node3D, prof: Dictionary, names: Array) -> Array:
	var out := []
	for n in names:
		var c: Array = prof.caps[n]
		out.append([ch.to_global(ch.bone_position(c[0])), ch.to_global(ch.bone_position(c[1])), c[2]])
	return out


static func _shift(ch: Node3D, world_delta: Vector3) -> void:
	var par := ch.get_parent() as Node3D
	ch.position += par.global_transform.basis.inverse() * world_delta


## Vartalo (lantio ja selkäranka) pois pöydän ja muiden edessä olevien kappaleiden sisältä sekä selkä kiinni
## selkänojaan (back_contact). Siirtää koko hahmoa vaakasuunnassa; istuin ja selkänoja eivät liiku. Palauttaa
## jäljelle jäävän tunkeuman (m).
static func fit_body(ch: Node3D, node: Node3D, prof: Dictionary, seat_y: float, back_contact := false) -> float:
	var d := Seat.of(node)
	var front: Vector3 = node.global_transform.basis * (d.front as Vector3)
	front = Vector3(front.x, 0, front.z).normalized()
	var solids := world_solids(node)
	var left := 0.0
	for rd in 3:
		ch.refresh_pose()
		var caps := _caps_world(ch, prof, ["pelvis", "spine_01", "spine_02", "spine_03"])
		var hip: Vector3 = ch.to_global(ch.bone_position("pelvis"))
		var pen := 0.0
		for s in solids:
			if _top_y(s) < seat_y + 0.03 or (s[0].origin - hip).dot(front) <= 0.0:
				continue  # istuin, askelmat ja maa eivät ole esteitä; takana oleva ei työnnä eteenpäin
			for c in caps:
				for k in 5:
					var p: Vector3 = (c[0] as Vector3).lerp(c[1], k / 4.0)
					if p.y < seat_y + 0.04:
						continue
					pen = maxf(pen, depth(s, p) + (c[2] as float))
		if pen > 0.003:
			_shift(ch, -front * (pen + 0.003))
		left = maxf(pen - 0.003, 0.0) if rd == 2 else 0.0
		if back_contact and d.has("back"):
			var bp: Vector3 = node.to_global(d.back.p)
			var bn: Vector3 = (node.global_transform.basis * (d.back.n as Vector3)).normalized()
			var gap := INF
			for c in _caps_world(ch, prof, ["spine_01", "spine_02", "spine_03"]):
				for k in 3:
					var p: Vector3 = (c[0] as Vector3).lerp(c[1], k / 2.0)
					gap = minf(gap, (p - bp).dot(bn) - (c[2] as float))
			var nh := Vector3(bn.x, 0, bn.z)
			gap -= 0.008  # tavoite: 0-1 cm rako (kapseli on likiarvo)
			if absf(gap) > 0.004 and nh.length() > 0.2:
				_shift(ch, -nh * clampf(gap, -0.15, 0.15) / nh.length_squared())
		if pen <= 0.003 and not back_contact:
			break
	ch.refresh_pose()
	return left


## Jalkaterä tukipinnalle: nilkka vaakapaikkaan xz (maailman avaruus, y ohitetaan), pohja vaakatasoon etusuuntaan front
## päin ja korkeus = korkein tuki kantapään ja päkiän alla + lift + pohjan etäisyys nilkasta. Jalka ratkaistaan IK:lla
## (polvi pole-suuntaan). ref_y = korkeus, jonka alapuolelta tukea haetaan (istuimen pinta). Palauttaa tuen korkeuden.
static func place_foot(ch: Node3D, node: Node3D, prof: Dictionary, lr: String, xz: Vector3, front: Vector3, ref_y: float,
		lift := 0.0, pole_up := 0.1, pole_side := 0.0) -> float:
	var ft: Dictionary = prof.foot[lr]
	var solids := world_solids(node)
	var heel: Vector3 = xz - front * float(ft.heel)
	var toe: Vector3 = xz + front * float(ft.toe)
	if lift == 0.0 and _span(solids, heel, toe, ref_y) > 0.01:
		# Liu'utus: jalkaterä on askelman reunan yli -> siirretään lähimpään kohtaan, jossa koko pohja on samalla tasolla
		var done := false
		for k in range(1, 9):
			for sg in [-1.0, 1.0]:
				var sh: Vector3 = front * (0.02 * k * sg)
				if _span(solids, heel + sh, toe + sh, ref_y) <= 0.005:
					xz += sh
					heel += sh
					toe += sh
					done = true
					break
			if done:
				break
	var sup := -INF
	for p in [heel, xz, toe]:
		sup = maxf(sup, support_y(solids, p.x, p.z, ref_y))
	if sup == -INF:
		var d := Seat.of(node)
		sup = node.to_global(Vector3(0, d.ground, 0)).y if d.has("ground") else ref_y - 0.35  # ei tukea: maa tai arvio
	var tgt := Vector3(xz.x, sup + lift + float(ft.sole), xz.z)
	var hip: Vector3 = ch.to_global(ch.bone_position("thigh" + lr))
	var side := front.cross(Vector3.UP).normalized()
	var pole := (hip + tgt) / 2.0 + front * 0.3 + Vector3(0, pole_up, 0) + side * pole_side
	var inv := ch.global_transform.affine_inverse()
	ch.set_ik("leg" + lr, "thigh" + lr, "calf" + lr, "foot" + lr, inv * tgt, inv * pole)
	# Pohja vaakaan: lepoasennon jalkaterä (pohja alas, kärki -Z) kierretään kohdesuuntaan (kärki front, pohja alas).
	var zc := Vector3(-front.x, 0, -front.z).normalized()
	var gb := ch.global_transform.basis.orthonormalized()
	var want := Basis(Vector3.UP.cross(zc).normalized(), Vector3.UP, zc)
	var rc: Basis = gb.inverse() * want
	ch.set_ik_orient("leg" + lr, rc * foot_basis(ch, lr, true), 1.0)
	return sup


## Tuen korkeuden vaihtelu kantapään ja kärjen välillä (m); kohdat ilman tukea ohitetaan.
static func _span(solids: Array, a: Vector3, b: Vector3, ref_y: float) -> float:
	var lo := INF
	var hi := -INF
	for k in 5:
		var p := a.lerp(b, k / 4.0)
		var y := support_y(solids, p.x, p.z, ref_y)
		if y != -INF:
			lo = minf(lo, y)
			hi = maxf(hi, y)
	return hi - lo if hi > -INF else 0.0


## Jalat pois kalusteen sisältä (pöytä): reiden ja säären kapselin pisteet istuinta ylemmäs nousevien kappaleiden
## sisältä. Työntää jalkojen kohteita kappaleen pinnan normaalia pitkin vaakasuunnassa. Palauttaa suurimman
## tunkeuman ennen korjausta (m).
static func clear_legs(ch: Node3D, node: Node3D, prof: Dictionary, seat_y: float) -> float:
	var solids := world_solids(node)
	var worst := 0.0
	var inv := ch.global_transform.affine_inverse()
	for lr: String in ["_l", "_r"]:
		if not ch._ik.has("leg" + lr):
			continue
		var push := Vector3.ZERO
		var pen_max := 0.0
		for c in _caps_world(ch, prof, ["thigh" + lr, "calf" + lr]):
			for k in 6:
				var p: Vector3 = (c[0] as Vector3).lerp(c[1], k / 5.0)
				if p.y < seat_y + 0.03:
					continue
				for s in solids:
					if _top_y(s) < seat_y + 0.03:
						continue
					var dp := depth(s, p)
					var dd := dp + (c[2] as float)
					if dp > 0.0 and dd > pen_max:
						pen_max = dd
						var q: Vector3 = (s[0] as Transform3D).affine_inverse() * p
						var h: Vector3 = (s[2] as Vector3) * 0.5
						var ax := 0
						var bst := INF
						for a in 3:
							var m: float = h[a] - absf(q[a])
							if m < bst:
								bst = m
								ax = a
						var nl := Vector3.ZERO
						nl[ax] = signf(q[ax])
						var nw: Vector3 = ((s[0] as Transform3D).basis * nl).normalized()
						push = Vector3(nw.x, 0, nw.z)
		worst = maxf(worst, pen_max)
		if pen_max > 0.003 and push.length() > 0.1:
			var e: Array = ch._ik["leg" + lr]
			e[3] = (e[3] as Vector3) + inv.basis * (push.normalized() * (pen_max + 0.003))
	ch.refresh_pose()
	return worst


## Päähän kiinnitettyjen esineiden (hattu, lasit) verkon pisteet maailman avaruudessa.
static func head_extras(ch: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for ba in ch.skeleton.get_children():
		if not ba is BoneAttachment3D or (ba as BoneAttachment3D).bone_name != "Head":
			continue
		for mi in ba.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			if m == null:
				continue
			var xf := (mi as MeshInstance3D).global_transform
			var arr := m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var step := maxi(1, arr.size() / 80)
			for i in range(0, arr.size(), step):
				out.append(xf * arr[i])
	return out


## Käsivarret pois jalkojen kapseleista: kyynärvarren ja käden pisteet työnnetään reiden ja sääriluun kapselin
## ulkopuolelle, työntö kohdistuu käden kohteeseen. Palauttaa suurimman tunkeuman ennen korjausta.
static func clear_arms(ch: Node3D, prof: Dictionary) -> float:
	var worst := 0.0
	var legs := _caps_world(ch, prof, ["thigh_l", "calf_l", "thigh_r", "calf_r"])
	var inv := ch.global_transform.affine_inverse()
	for lr: String in ["_l", "_r"]:
		if not ch._ik.has("arm" + lr):
			continue
		for rd in 3:
			ch.refresh_pose()
			var a: Vector3 = ch.to_global(ch.bone_position("lowerarm" + lr))
			var b: Vector3 = ch.to_global(ch.bone_position("hand" + lr))
			var push := Vector3.ZERO
			var rr: float = (prof.caps["lowerarm" + lr] as Array)[2]
			for k in 5:
				var p := a.lerp(b, k / 4.0)
				for c in legs:
					var q := _seg_closest(p, c[0], c[1])
					var dd := p.distance_to(q)
					var pen: float = (c[2] as float) + rr - dd
					if pen > 0.002 and dd > 0.0001:
						worst = maxf(worst, pen)
						if pen > push.length():
							push = (p - q) / dd * pen
			if push.length() < 0.003:
				break
			var e: Array = ch._ik["arm" + lr]
			e[3] = (e[3] as Vector3) + inv.basis * (push + push.normalized() * 0.003)
	ch.refresh_pose()
	return worst


# --- Mitattu sovitus (paistettu verkko, ei headlessissa) ----------------------------------------------------------

## Hahmon pisteet luiden bones maailman avaruudessa (limb_points = Pose.limb_points). Tyhjä headlessissa.
static func world_points(ch: Node3D, limb_points: Callable, bones: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for q in limb_points.call(ch, ch, bones) as PackedVector3Array:
		out.append(ch.to_global(q))
	return out


## Lantio istuimelle: lantion ja reisien pisteistä, jotka ovat istuimen kohdalla, syvin tunkeuma = Elastic.sink("pakara"),
## eli pakara painuu istuinta vasten sallitun painuman verran eikä ole ilmassa. Siirtää hahmoa pystysuunnassa; palauttaa
## siirron (m, + ylös), 0 jos mitattavaa ei ole (headless) tai istuinta ei löydy pisteiden alta.
static func settle_seat(ch: Node3D, node: Node3D, seat_y: float, limb_points: Callable) -> float:
	var pts := world_points(ch, limb_points, ["pelvis", "thigh_l", "thigh_r"])
	var solids := world_solids(node)
	var worst := -INF
	for p in pts:
		var sy := support_y(solids, p.x, p.z, p.y + 0.06)
		if sy == -INF or absf(sy - seat_y) > 0.03:
			continue  # selkänoja, pyyhe ja ilma eivät ole istuin
		worst = maxf(worst, sy - p.y)
	if worst == -INF:
		return 0.0
	var dy := worst - Elastic.sink("pakara", ch.body_shape)
	_shift(ch, Vector3(0, dy, 0))
	ch.refresh_pose()
	return dy


## Selkä selkänojaan mitatusta verkosta: (1) lantion ja alaselän (pelvis, spine_01) takimmainen piste selkänojan pinnalle
## sisään Elastic.sink("pakara"), (2) yläselän (spine_02, spine_03) rako selkänojaan 0...sink("selka") kallistamalla
## selkärankaa lisää (tai vähemmän) samasta akselista, jolla Pose.sit kallisti sen. Kierros kerrallaan, koska
## kallistus siirtää yläselkää ja siirto lantiota. Palauttaa [kallistuksen lisäys (rad), yläselän rako (m), lantion rako (m)].
static func fit_back(ch: Node3D, node: Node3D, limb_points: Callable, tilt: float) -> Array:
	var d := Seat.of(node)
	var bp: Vector3 = node.to_global(d.back.p)
	var bn: Vector3 = (node.global_transform.basis * (d.back.n as Vector3)).normalized()
	var nh := Vector3(bn.x, 0, bn.z)
	var lo_t: float = -Elastic.sink("pakara", ch.body_shape)
	var up_t: float = -Elastic.sink("selka", ch.body_shape)
	var gl := 0.0
	var gu := 0.0
	var lean := tilt
	var moved := false
	var neck_x: float = (ch._overrides["neck_01"][1] + tilt * 0.85) if ch._overrides.has("neck_01") else 0.0
	for rd in 8:
		ch.refresh_pose()
		gl = INF
		gu = INF
		for p in world_points(ch, limb_points, ["pelvis", "spine_01"]):
			gl = minf(gl, (p - bp).dot(bn))
		for p in world_points(ch, limb_points, ["spine_02", "spine_03"]):
			gu = minf(gu, (p - bp).dot(bn))
		if gl == INF or gu == INF:
			return [0.0, 0.0, 0.0, false]
		var done := true
		if absf(gl - lo_t) > 0.003 and nh.length() > 0.2:
			_shift(ch, -nh * (gl - lo_t) / nh.length_squared())
			done = false
			moved = true
		if absf(gu - gl - (up_t - lo_t)) > 0.004:
			# Yläselän rako lantioon verrattuna: kallista (rako kasvaa -> lisää taakse), kiertokeskiö lantiolla ~0,4 m alempana
			lean += atan2(gu - gl - (up_t - lo_t), 0.4)
			lean = clampf(lean, tilt - 0.6, tilt + 1.0)
			lean_spine(ch, lean)
			ch.set_override("neck_01", Vector3.RIGHT, -lean * 0.85 + neck_x)
			done = false
			moved = true
		# Pää: kaula kääntää päätä eteen, kunnes pää ja hiukset eivät mene selkänojan sisään (selkänojan yli ei ylitetä)
		var gh := INF
		for p in world_points(ch, limb_points, ["Head", "neck_01"]):
			gh = minf(gh, (p - bp).dot(bn))
		for p in head_extras(ch):  # hattu ja muut päähän kiinnitetyt esineet
			gh = minf(gh, (p - bp).dot(bn))
		if gh < INF and gh < -0.002 and neck_x > -0.8:
			neck_x -= minf(-gh / 0.25, 0.3)
			ch.set_override("neck_01", Vector3.RIGHT, -lean * 0.85 + neck_x)
			done = false
			moved = true
		if done:
			break
	ch.refresh_pose()
	return [lean - tilt, gu, gl, moved]


# --- Painuman kontaktilaatikot ------------------------------------------------------------------------------------

## Laatikkokappaleen kehys, jonka +Y on pinta suuntaan dir (kappaleen akseli, joka on lähinnä dir:iä): [Transform3D, puolikoko].
static func face_box(s: Array, dir: Vector3) -> Array:
	var xf: Transform3D = s[0]
	var sz: Vector3 = s[2]
	var ya := 0
	var bd := 0.0
	for ax in 3:
		var dd: float = xf.basis[ax].normalized().dot(dir)
		if absf(dd) > absf(bd):
			ya = ax
			bd = dd
	var xa := (ya + 1) % 3
	var za := (ya + 2) % 3
	var x: Vector3 = xf.basis[xa].normalized()
	var y: Vector3 = xf.basis[ya].normalized() * signf(bd)
	var half := Vector3(sz[xa] * xf.basis[xa].length(), sz[ya] * xf.basis[ya].length(), sz[za] * xf.basis[za].length()) * 0.5
	return [Transform3D(Basis(x, y, x.cross(y)), xf.origin), Vector3(half.x, half.y, half.z)]


## Painuvat kontaktipinnat istujalle (Character.set_contacts): istuin (laatikko, jonka yläpinta on seat_y istuinpisteen
## kohdalla) ja selkänoja (laatikko, jonka etupinnalla back.p on). Maailman avaruudessa: [[Transform3D, puolikoko], ...].
static func contacts(node: Node3D, seat_y: float) -> Array:
	var d := Seat.of(node)
	var out := []
	var up: Vector3 = (node.global_transform.basis * (d.n as Vector3)).normalized()
	var sp: Vector3 = node.to_global(d.seat)
	var best := INF
	var seat_box := []
	for s in world_solids(node):
		if s[1] != "box":
			continue
		var fb := face_box(s, up)
		var q: Vector3 = (fb[0] as Transform3D).affine_inverse() * sp
		var h: Vector3 = fb[1]
		var dy := absf(q.y - h.y)
		if (fb[0] as Transform3D).basis.y.dot(up) > 0.7 and dy < 0.03 and absf(q.x) <= h.x and absf(q.z) <= h.z and dy < best:
			best = dy
			seat_box = fb
	if not seat_box.is_empty():
		out.append(seat_box)
	out.append_array(table_boxes(node, seat_y))  # pöydän reuna: vatsa ja rinta painuvat sitä vasten
	if d.has("back"):
		var bp: Vector3 = node.to_global(d.back.p)
		var bn: Vector3 = (node.global_transform.basis * (d.back.n as Vector3)).normalized()
		best = INF
		var back_box := []
		for s in world_solids(node):
			if s[1] != "box":
				continue
			var fb := face_box(s, bn)
			var q: Vector3 = (fb[0] as Transform3D).affine_inverse() * bp
			var h: Vector3 = fb[1]
			var dy := absf(q.y - h.y)
			if (fb[0] as Transform3D).basis.y.dot(bn) > 0.9 and dy < 0.03 and absf(q.x) <= h.x + 0.05 and absf(q.z) <= h.z + 0.05 and dy < best:
				best = dy
				back_box = fb
		if not back_box.is_empty():
			out.append(back_box)
	return out


## Selkäranka ja lantio kallistettuna taakse kulman a verran samasta akselista (hahmon x), jaettuna lantiolle ja kolmelle
## nikamalle; pää kääntyy takaisin vaakaan puoliksi (kaula ja pää seuraavat selkää, ei tuijoteta kattoon).
static func lean_spine(ch: Node3D, a: float) -> void:
	ch.set_override("pelvis", Vector3.RIGHT, a * 0.2)
	ch.set_override("spine_01", Vector3.RIGHT, a * 0.25)
	ch.set_override("spine_02", Vector3.RIGHT, a * 0.3)
	ch.set_override("spine_03", Vector3.RIGHT, a * 0.25)
	ch.set_override("neck_01", Vector3.RIGHT, -a * 0.85)


## Pöydän reunan istujaa kohti oleva pinta (face_box, +Y istujaa kohti), jota vasten vatsa ja rinta painuvat.
static func table_boxes(node: Node3D, seat_y: float) -> Array:
	var d := Seat.of(node)
	var sp: Vector3 = node.to_global(d.seat)
	var fr: Vector3 = node.global_transform.basis * (d.front as Vector3)
	fr = Vector3(fr.x, 0, fr.z).normalized()
	var out := []
	for s in world_solids(node):
		if s[1] != "box" or _top_y(s) < seat_y + 0.2:
			continue
		var tb := face_box(s, -fr)
		var fxf: Transform3D = tb[0]
		if fxf.basis.y.dot(-fr) < 0.9:
			continue
		var q: Vector3 = fxf.affine_inverse() * sp
		if q.y > (tb[1] as Vector3).y and q.y - (tb[1] as Vector3).y < 0.6 and absf(q.x) < (tb[1] as Vector3).x + 0.3:
			out.append(tb)
	return out


## Vartalo pöydän reunaa vasten mitatusta verkosta: vatsan ja rinnan (spine_01...03, painumaton pinta) syvin piste pöydän
## etupinnan sisällä asetetaan pienimpään suunniteltuun upotukseen (vatsa tai rinta), jolloin painuma näkyy ja vartalo
## on kiinni pöydässä eikä sen edessä ilmassa. Siirtää hahmoa vaakasuunnassa front-suuntaan; palauttaa siirron (m, + pöytää kohti),
## 0 jos mitattavaa ei ole (headless, ei pöytää tai vartalo ei ylety pöydän kohdalle).
static func settle_table(ch: Node3D, node: Node3D, seat_y: float, limb_points: Callable) -> float:
	var boxes := table_boxes(node, seat_y)
	if boxes.is_empty():
		return 0.0
	var d := Seat.of(node)
	var front: Vector3 = node.global_transform.basis * (d.front as Vector3)
	front = Vector3(front.x, 0, front.z).normalized()
	var want := minf(Elastic.sink("vatsa", ch.body_shape), Elastic.sink("rinta", ch.body_shape))
	var total := 0.0
	for rd in 2:
		var worst := 0.0
		for p in world_points(ch, limb_points, ["spine_01", "spine_02", "spine_03"]):
			for tb in boxes:
				var q: Vector3 = (tb[0] as Transform3D).affine_inverse() * p
				var h: Vector3 = tb[1]
				if absf(q.x) < h.x and absf(q.z) < h.z and q.y < h.y:
					worst = maxf(worst, h.y - q.y)
		if worst <= 0.0:
			break
		var delta := clampf(want - worst, -0.1, 0.05)
		if absf(delta) < 0.002:
			break
		_shift(ch, front * delta)
		ch.refresh_pose()
		total += delta
	return total
