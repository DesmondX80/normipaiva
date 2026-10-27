## Kontaktit: istujan kapselimalli (luukohtaiset kapselit ja jalkaterän laatikko) ja tunkeumien korjaus kalusteen
## muotoja (Seat) vastaan. Malli lasketaan paistetusta verkosta kerran hahmotyyppiä kohden ja tallennetaan välimuistiin,
## joten istuttaminen ei maksa ruutukohtaista työtä. Paistettu verkko (Pose.limb_points) on totuus vain testissä.
## Kaikki laskenta on maailman avaruudessa. Ei lataa pose.gd:tä (silmukka): limb_points annetaan profile-kutsulle.

const Seat := preload("res://scripts/seat.gd")
const Elastic := preload("res://scripts/elastic.gd")
const Terrain := preload("res://scripts/terrain.gd")

## Kapselit: [luu a, luu b, avain]; kapseli kulkee luun a paikasta luun b paikkaan, säde luetaan verkosta.
const TORSO := [["pelvis", "spine_01"], ["spine_01", "spine_02"], ["spine_02", "spine_03"], ["spine_03", "neck_01"]]
const LIMBS := [["thigh", "calf"], ["calf", "foot"], ["upperarm", "lowerarm"], ["lowerarm", "hand"]]
## Lisäkapselit hahmo hahmoa vastaan: kämmen (ranteesta sormiin, "hand_l"/"hand_r") ja pää (pallo kallon keskellä).
## Tallennetaan muodossa [luu, "", säde, pituus, akseli/piste luun avaruudessa]; _caps_world ei osaa niitä, käytä caps_all.
const EXTRA := ["hand", "Head"]
## Varataulukko, kun verkkoa ei saada (headless): säteet 1,8 m hahmolle, mitattu profile-kutsulla (tulostus PROFIILI).
const FALLBACK_R := {"pelvis": 0.16, "spine_01": 0.15, "spine_02": 0.15, "spine_03": 0.17, "thigh": 0.12, "calf": 0.082,
	"upperarm": 0.045, "lowerarm": 0.04, "hand": 0.045, "Head": 0.11}
const FALLBACK_HAND_LEN := 0.1  # ranteesta kämmenkapselin päähän (säde jatkaa sormenpäihin)
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
		caps["hand" + lr] = _hand_cap(ch, lr, limb_points, can_bake)
	_shape_tables(ch, caps, limb_points, can_bake)
	if ch.skeleton.find_bone("Head") >= 0:
		caps["Head"] = _head_cap(ch, limb_points, can_bake)
		_neck_caps(ch, caps, limb_points, can_bake)
	var prof := {"caps": caps, "foot": foot, "measured": measured}
	if measured:
		_cache[key] = prof
	return prof


## Kämmenen kapseli: ranteesta sormien suuntaan (middle_01-luuhun tai pisteiden keskelle), akseli luun omassa avaruudessa.
## Pisteissä sormet mukana; mitataan kerran (profiilin asennossa, sormet Idle-animaation koukussa).
static func _hand_cap(ch: Node3D, lr: String, limb_points: Callable, can_bake: bool) -> Array:
	var sc: float = ch.model.scale.x
	var hand := "hand" + lr
	var sk: Skeleton3D = ch.skeleton
	var hi := sk.find_bone(hand)
	var xf := _bone_xf(ch, hand)
	var a := xf.origin
	var bones := [hand]
	for i in sk.get_bone_count():  # sormet: ranteen jälkeläiset
		var pa := sk.get_bone_parent(i)
		while pa >= 0 and pa != hi:
			pa = sk.get_bone_parent(pa)
		if pa == hi:
			bones.append(sk.get_bone_name(i))
	var pts: PackedVector3Array = limb_points.call(ch, ch, bones) if can_bake else PackedVector3Array()
	var ax := Vector3.ZERO
	if sk.find_bone("middle_01" + lr) >= 0:
		ax = ch.bone_position("middle_01" + lr) - a
	elif not pts.is_empty():
		var cen := Vector3.ZERO
		for q in pts:
			cen += q
		ax = cen / pts.size() - a
	if ax.length() < 0.001:
		ax = a - ch.bone_position("lowerarm" + lr)
	ax = ax.normalized()
	var r: float = FALLBACK_R["hand"] * sc
	var ln := FALLBACK_HAND_LEN * sc
	if not pts.is_empty():
		# Kämmen on litteä: säde = mediaani etäisyydestä akseliin (90. persentiili olisi kämmenen leveys ja nostaisi kämmenen
		# 3 cm irti pinnasta); pituus niin, että kapselin pää (pituus + säde) on sormenpäissä (98. persentiili projektiosta).
		var pr := []
		var ds := []
		for q in pts:
			var t := (q - a).dot(ax)
			pr.append(t)
			ds.append((q - a - ax * t).length())
		pr.sort()
		ds.sort()
		r = clampf(ds[int(ds.size() * 0.5)], r * 0.6, r * 1.6)
		ln = clampf(float(pr[int(pr.size() * 0.98)]) - r, ln * 0.3, ln * 1.6)
	return [hand, "", r, ln, (xf.basis.inverse() * ax).normalized()]


## Pään pallo: keskus Head-luun lepopaikasta 0,09 ylös (kuten Character._head_center), säde = 90. persentiili kallon
## (verkko ilman hiuksia) pisteiden etäisyydestä keskukseen.
static func _head_cap(ch: Node3D, limb_points: Callable, can_bake: bool) -> Array:
	var sk: Skeleton3D = ch.skeleton
	var rest := sk.get_bone_global_rest(sk.find_bone("Head"))
	var lp: Vector3 = rest.affine_inverse() * (rest.origin + Vector3(0.0, 0.09, 0.0))
	var r: float = FALLBACK_R["Head"] * ch.model.scale.x
	var pts: PackedVector3Array = limb_points.call(ch, ch, ["Head"], 1) if can_bake else PackedVector3Array()
	if not pts.is_empty():
		var c: Vector3 = _bone_xf(ch, "Head") * lp
		var ds := []
		for q in pts:
			ds.append(q.distance_to(c))
		ds.sort()
		r = clampf(ds[int(ds.size() * 0.9)], r * 0.6, r * 1.6)
	return ["Head", "", r, 0.0, lp]


## Hahmo hahmoa vastaan: rintakehän ylin kapseli (spine_03 -> neck_01) ulottuu täydellä säteellä 13-20 cm olkapäiden yli,
## jolloin hartioilla lepäävä käsi olisi aina "sisällä". caps.spine_03[3] = katkaisu (m): kapselin pää vedetään niskasta
## alas niin, että sen huippu on verkon ylimmän pisteen (spine_03 ja solisluut) kohdalla. Lisäksi kaula (neck_01 -> Head).
## Kalusteita vastaan (fit_body) spine_03 käytetään ennallaan (vain alkiot 0-2).
static func _neck_caps(ch: Node3D, caps: Dictionary, limb_points: Callable, can_bake: bool) -> void:
	var sc: float = ch.model.scale.x
	var c3: Array = caps["spine_03"]
	var a: Vector3 = ch.bone_position("spine_03")
	var b: Vector3 = ch.bone_position("neck_01")
	var ax := (b - a).normalized()
	var cut: float = float(c3[2]) * 0.85
	var rn := 0.055 * sc
	if can_bake:
		var pr := []
		for q in limb_points.call(ch, ch, ["spine_03", "clavicle_l", "clavicle_r"]) as PackedVector3Array:
			pr.append((q - b).dot(ax))
		if not pr.is_empty():
			pr.sort()
			cut = clampf(float(c3[2]) - float(pr[int(pr.size() * 0.98)]), 0.0, float(c3[2]))
		var ds := []
		var hb: Vector3 = ch.bone_position("Head")
		for q in limb_points.call(ch, ch, ["neck_01"]) as PackedVector3Array:
			ds.append(_seg_dist(q, b, hb))
		if not ds.is_empty():
			ds.sort()
			rn = clampf(ds[int(ds.size() * 0.9)], rn * 0.6, rn * 1.6)
	if c3.size() < 4:
		c3.resize(4)
	c3[3] = cut
	caps["neck_01"] = ["neck_01", "Head", rn]


## Vartalon kapselien muototaulut hahmo hahmoa vastaan: pyöreä kapseli on 90. persentiilin säde kaikkiin suuntiin, jolloin
## selän puolella se on 5-14 cm ihon ulkopuolella (vatsa määrää säteen) ja selkään laitettu käsi jäisi ilmaan. Pisteet ovat
## koko vartalo (lantio, selkäranka, solisluut; vatsan etuosa on usein lantion tai spine_02:n painoilla), ja kukin piste
## kuuluu lähimmälle vartalokapselille. Taulu = 3 asemaa luuta pitkin x 4 neljännestä (luun paikallinen +x, -x, +z, -z),
## kukin 95. persentiili etäisyydestä akseliin siihen suuntaan; tallennetaan caps[luu][4] ([3] = katkaisu, _neck_caps).
static func _shape_tables(ch: Node3D, caps: Dictionary, limb_points: Callable, can_bake: bool) -> void:
	var pts: PackedVector3Array = limb_points.call(ch, ch, ["pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"]) if can_bake else PackedVector3Array()
	if pts.is_empty():
		return
	var segs := []
	for s in TORSO:
		segs.append([ch.bone_position(s[0]), ch.bone_position(s[1]), _bone_xf(ch, s[0]).basis.orthonormalized().inverse(), []])
		for k in 12:
			(segs[-1][3] as Array).append([])
	for q in pts:
		var bi := 0
		var bd := INF
		for i in segs.size():
			var d := _seg_dist(q, segs[i][0], segs[i][1])
			if d < bd:
				bd = d
				bi = i
		var sg: Array = segs[bi]
		var t := minf(_t_on(q, sg[0], sg[1]), 0.999)
		var o: Vector3 = (sg[2] as Basis) * (q - (sg[0] as Vector3).lerp(sg[1], t))
		var bins: Array = sg[3]
		var st := int(t * 3.0)
		bins[st * 4 + (0 if o.x > 0.0 else 1)].append(absf(o.x))
		bins[st * 4 + (2 if o.z > 0.0 else 3)].append(absf(o.z))
	for i in TORSO.size():
		var c: Array = caps[TORSO[i][0]]
		var r: float = c[2]
		var tb := []
		for k in 12:
			var l: Array = segs[i][3][k]
			l.sort()
			tb.append(clampf(l[int(l.size() * 0.95)], r * 0.3, r * 1.5) if l.size() >= 5 else r)
		c.resize(5)
		c[3] = 0.0
		c[4] = tb


## Kapselin säde suuntaan dir (maailmassa, akselista ulos) kohdassa t (0 = a, 1 = b); cap = caps_all-alkio. Ilman
## muototaulua (raajat, kämmen, pää) pyöreä säde.
static func _rad(cap: Array, t: float, dir: Vector3) -> float:
	if cap.size() < 5 or cap[4] == null:
		return cap[3]
	var sh: Array = cap[4]
	var tb: Array = sh[1]
	var l: Vector3 = (sh[0] as Basis) * dir
	var st := clampf(t * 3.0 - 0.5, 0.0, 2.0)
	var i0 := int(st)
	var i1 := mini(i0 + 1, 2)
	var f := st - i0
	var rr := []
	for q in 4:
		rr.append(lerpf(tb[i0 * 4 + q], tb[i1 * 4 + q], f))
	var lat := Vector2(l.x, l.z)
	var ll := lat.length()
	var mean: float = (rr[0] + rr[1] + rr[2] + rr[3]) * 0.25
	if ll < 0.0001:
		return mean  # suoraan akselin suuntaan (kapselin pää)
	lat /= ll
	var rx: float = rr[0] if lat.x > 0.0 else rr[1]
	var rz: float = rr[2] if lat.y > 0.0 else rr[3]
	var re := 1.0 / sqrt((lat.x * lat.x) / (rx * rx) + (lat.y * lat.y) / (rz * rz))
	var w := ll * ll / maxf(l.length_squared(), 0.000001)  # sivusuunnan osuus
	return lerpf(mean, re, w)


## Pisteen p parametri janalla a-b (0...1).
static func _t_on(p: Vector3, a: Vector3, b: Vector3) -> float:
	return clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.000001), 0.0, 1.0)


## Luun kehys hahmon avaruudessa nykyasennossa (sama avaruus kuin bone_position).
static func _bone_xf(ch: Node3D, bone: String) -> Transform3D:
	return ch.model.transform * ch.skeleton.transform * ch.skeleton.get_bone_global_pose(ch.skeleton.find_bone(bone))


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


## Maan korkeus pisteen (x, z) alla: fysiikkasäde maastokerrokseen (Terrain.COLLISION_LAYER) korkeudelta from_y + 0,5 alas
## 2 m. -INF, jos ei osu tai puussa ei ole fysiikkaa. Kalusteen kappaleet eivät sisällä maastoa, joten tuki on max(kappaleet, maa).
static func ground_y(node: Node3D, x: float, z: float, from_y: float) -> float:
	if node == null or not node.is_inside_tree():
		return -INF
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y + 0.5, z), Vector3(x, from_y - 1.5, z), Terrain.COLLISION_LAYER)
	var hit := node.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else -INF


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
		sup = maxf(sup, ground_y(node, p.x, p.z, ref_y))
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


## Jalat pois kalusteen sisältä (pöytä, portaat): reiden ja säären kapselin pisteet kappaleiden sisältä. Vain istuinkappale
## (yläpinta seat_y:n tasolla, +-3 cm) ohitetaan, joten matalampi askelma, jonka läpi sääri menisi, näkyy. Kun lähin pinta on
## sivupinta, jalkaa työnnetään sen normaalia pitkin; kun lähin pinta on yläpinta, jalkaa työnnetään front-suuntaan kappaleen
## etupinnan yli (etäisyys + kapselisäde + 3 mm). Enintään 2 kierrosta; työnnetyn jalan jalkaterä sijoitetaan uudelleen
## (place_foot liu'uttaa sen tasaiselle tuelle). Palauttaa suurimman tunkeuman ennen korjausta (m).
static func clear_legs(ch: Node3D, node: Node3D, prof: Dictionary, seat_y: float) -> float:
	var solids := world_solids(node)
	var worst := 0.0
	var d := Seat.of(node)
	var front: Vector3 = node.global_transform.basis * (d.front as Vector3)
	front = Vector3(front.x, 0, front.z).normalized()
	for rd in 2:
		ch.refresh_pose()
		var moved := false
		for lr: String in ["_l", "_r"]:
			if not ch._ik.has("leg" + lr):
				continue
			var push := Vector3.ZERO
			var pen_max := 0.0
			for c in _caps_world(ch, prof, ["thigh" + lr, "calf" + lr]):
				for k in 6:
					var p: Vector3 = (c[0] as Vector3).lerp(c[1], k / 5.0)
					for s in solids:
						if absf(_top_y(s) - seat_y) < 0.03:
							continue  # istuinkappale
						var dp := depth(s, p)
						var dd := dp + (c[2] as float)
						# Matala kappale (askelma): kapselin pinta voi läpäistä yläpinnan, vaikka akseli on vielä ulkopuolella
						var low := _top_y(s) < seat_y and k < 5
						if (dp > 0.0 or (low and dp > -(c[2] as float) + 0.005)) and dd > pen_max:
							pen_max = dd
							var sxf: Transform3D = s[0]
							var q: Vector3 = sxf.affine_inverse() * p
							var h: Vector3 = (s[2] as Vector3) * 0.5 if s[1] == "box" else Vector3(s[2].x, s[2].y * 0.5, s[2].x)
							var ax := 0
							var bst := INF
							for a in 3:
								var m: float = h[a] - absf(q[a])
								if m < bst:
									bst = m
									ax = a
							var nl := Vector3.ZERO
							nl[ax] = signf(q[ax])
							var nw: Vector3 = (sxf.basis * nl).normalized()
							if absf(nw.y) > 0.7:
								# Yläpinta: ulos etupinnan kautta (front kappaleen avaruudessa)
								var fl: Vector3 = sxf.basis.inverse() * front
								var t := INF
								for a in [0, 2]:
									if absf(fl[a]) > 0.001:
										t = minf(t, (h[a] - signf(fl[a]) * q[a]) / absf(fl[a]))
								t = maxf(t if t < INF else 0.0, 0.0)
								if _top_y(s) < seat_y:
									# Matala askelma: jalka ei yletä sen yli (polvi putoaisi säären alle), joten jalkaterä vedetään
									# takaisin lepäämään askelmalle: kärki etureunan tällä puolen
									var cur: float = (ch.global_transform * ((ch._ik["leg" + lr] as Array)[3] as Vector3)).dot(front)
									var toe_len: float = (prof.foot[lr] as Dictionary).toe
									push = front * ((p.dot(front) + t - toe_len - 0.03) - cur)
								else:
									push = front * (t + (c[2] as float) + 0.003)
							elif Vector2(nw.x, nw.z).length() > 0.1:
								push = Vector3(nw.x, 0, nw.z).normalized() * (pen_max + 0.003)
							else:
								push = Vector3.ZERO
			if rd == 0:
				worst = maxf(worst, pen_max)
			if pen_max > 0.003 and push.length() > 0.001:
				var e: Array = ch._ik["leg" + lr]
				var tg: Vector3 = ch.global_transform * (e[3] as Vector3) + push
				place_foot(ch, node, prof, lr, tg, front, seat_y - 0.1, 0.0, 0.1)
				moved = true
		if not moved:
			break
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
static func world_points(ch: Node3D, limb_points: Callable, bones: Array, meshes := 0) -> PackedVector3Array:
	var out := PackedVector3Array()
	for q in limb_points.call(ch, ch, bones, meshes) as PackedVector3Array:
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


## Pohkeet istuimen etureunan yli: calf-pisteet, jotka ovat istuinlaatikon jalanjäljessä yli Elastic.sink("pohje") pinnan
## alla, siirretään ulos koko hahmoa eteen (front) reunan yli. Siirto korkeintaan cap (0,12 m). Palauttaa siirron (m), 0 jos
## ei tarvetta tai ei mitattavaa (headless). Jos katto ylittyy, tulostaa KONTAKTI JÄÄ.
static func clear_seat_edge(ch: Node3D, node: Node3D, seat_y: float, front: Vector3, limb_points: Callable, cap := 0.12) -> float:
	var pts := world_points(ch, limb_points, ["calf_l", "calf_r"])
	if pts.is_empty():
		return 0.0
	front = Vector3(front.x, 0, front.z).normalized()
	var up: Vector3 = (node.global_transform.basis * (Seat.of(node).n as Vector3)).normalized()
	var lim: float = Elastic.sink("pohje", ch.body_shape)
	var need := 0.0
	for s in world_solids(node):
		if s[1] != "box":
			continue
		var fb := face_box(s, up)
		var xf: Transform3D = fb[0]
		var h: Vector3 = fb[1]
		if xf.basis.y.dot(up) < 0.7 or absf(xf.origin.y + xf.basis.y.y * h.y - seat_y) > 0.03:
			continue
		var edge: float = xf.origin.dot(front) + absf(front.dot(xf.basis.x)) * h.x + absf(front.dot(xf.basis.z)) * h.z
		var inv := xf.affine_inverse()
		for p in pts:
			var q: Vector3 = inv * p
			if absf(q.x) < h.x and absf(q.z) < h.z and q.y >= -h.y and h.y - q.y > lim:
				need = maxf(need, edge - p.dot(front) + 0.01)
	if need <= 0.0:
		return 0.0
	var d := minf(need, cap)
	_shift(ch, front * d)
	ch.refresh_pose()
	if need > cap:
		print("KONTAKTI JÄÄ %s istuin syvempi kuin reisi (pohje %.3f m reunan sisällä)" % [node.name, need - cap])
	return d


## Selkä selkänojaan mitatusta verkosta: (1) lantion ja alaselän (pelvis, spine_01) takimmainen piste selkänojan pinnalle
## sisään Elastic.sink("pakara"), (2) yläselän (spine_02, spine_03) rako selkänojaan 0...sink("selka") kallistamalla
## selkärankaa lisää (tai vähemmän) samasta akselista, jolla Pose.sit kallisti sen. Kierros kerrallaan, koska
## kallistus siirtää yläselkää ja siirto lantiota. slide (m) = lantion liuku eteen nojasta: selkä kallistuu lisää. Palauttaa [kallistuksen lisäys (rad), yläselän rako (m), lantion rako (m)].
static func fit_back(ch: Node3D, node: Node3D, limb_points: Callable, tilt: float, slide := 0.0) -> Array:
	# Koko selkä nojaa suorana selkänojaa vasten: lantio siirtyy nojaan, sitten jokainen nikama alhaalta ylös
	# (alaselkä, keskiselkä, yläselkä) kääntyy niin, että sen takapinta on nojassa (animaation pyöreä selkä
	# suoristuu). Sen jälkeen niska ja takaraivo nojaan, ja lopuksi lierihattu kallistuu eteen, jos se ei mahdu
	# nojan yläreunan yli. Kulmat (hahmon x-akseli, + = taakse) säilyvät hahmossa kutsukerrasta toiseen
	# (meta "selka_kulmat"; Pose.sit nollaa ne istutuksen alussa).
	var d := Seat.of(node)
	var bp: Vector3 = node.to_global(d.back.p)
	var bn: Vector3 = (node.global_transform.basis * (d.back.n as Vector3)).normalized()
	var nh := Vector3(bn.x, 0, bn.z)
	var lo_t: float = -Elastic.sink("pakara", ch.body_shape) + slide * nh.length()  # slide: lantio liukunut eteen (clear_seat_edge)
	var up_t: float = -Elastic.sink("selka", ch.body_shape)
	var bb := _back_box(node)
	reset_hats(ch)  # hatun kallistus ei kerry kutsukerrasta toiseen
	var ang: Dictionary = ch.get_meta("selka_kulmat") if ch.has_meta("selka_kulmat") else {
		"pelvis": tilt * 0.2, "spine_01": tilt * 0.25, "spine_02": tilt * 0.3, "spine_03": tilt * 0.25, "neck_01": 0.0, "Head": 0.0}
	var ang0 := {"spine_01": tilt * 0.25, "spine_02": tilt * 0.3, "spine_03": tilt * 0.25, "neck_01": 0.0}  # korjaus enintään 0,3 rad tästä
	# [säädettävä luu (sen alue mitataan), vipuvarsi nivelestä alueen keskelle m, tavoiterako]
	var chain := [["spine_01", 0.1, up_t], ["spine_02", 0.12, up_t], ["spine_03", 0.12, up_t], ["neck_01", 0.07, 0.004]]
	var apply := func() -> void:
		for b: String in ang:
			ch.set_override(b, Vector3.RIGHT, ang[b])
	apply.call()
	var gl := INF
	var gu := INF
	var moved := false
	var hat_rot := 0.0
	var hat_sign := 0.0
	var head_g := [INF, INF, INF]  # kallon, hiusten ja hatun rako selkänojaan
	for rd in 24:
		ch.refresh_pose()
		gl = INF
		for p in world_points(ch, limb_points, ["pelvis"]):
			gl = minf(gl, (p - bp).dot(bn))
		if gl == INF:
			return [0.0, 0.0, 0.0, false, head_g]
		if absf(gl - lo_t) > 0.003 and nh.length() > 0.2:
			_shift(ch, -nh * (gl - lo_t) / nh.length_squared())
			moved = true
			continue
		# Nikamat alhaalta ylös: korjataan alin, joka ei ole nojassa (ylempien rako riippuu alempien kulmasta).
		var fixed := false
		gu = INF
		for c: Array in chain:
			var g := _foot_min(world_points(ch, limb_points, [c[0]]), bp, bn, bb, 0.15 if c[0] == "neck_01" else 0.02)
			if c[0] != "neck_01":
				gu = minf(gu, g)
			if g == INF:
				continue  # alue on nojan yläreunan yli: ei kosketusta
			if absf(g - c[2]) > 0.003:
				ang[c[0]] = clampf(ang[c[0]] + atan2(g - c[2], c[1]) * 0.7, ang0[c[0]] - 0.3, ang0[c[0]] + 0.3)
				fixed = true
				break
		if fixed:
			apply.call()
			moved = true
			continue
		# Takaraivo nojaan (litistynyt tukka 10 % paksuudestaan välissä); pää kääntyy niskan päällä kumpaan suuntaan tahansa.
		var gs := _foot_min(world_points(ch, limb_points, ["Head"], 1), bp, bn, bb, 0.15)
		var gh := _foot_min(world_points(ch, limb_points, ["Head"], 2), bp, bn, bb, 0.15)
		head_g = [gs, gh, INF]
		if gs < INF:
			var gs_t := 0.001 if gh == INF else 0.1 * maxf(gs - gh, 0.0) + 0.001
			if absf(gs - gs_t) > 0.003 and absf(ang["Head"]) < 0.4:
				ang["Head"] = clampf(ang["Head"] + atan2(gs - gs_t, 0.1) * 0.7, -0.4, 0.4)
				apply.call()
				moved = true
				continue
		# Hattu: jos lieri ei mahdu nojan yläreunan yli, se kallistuu päässä hieman eteen.
		var gx := _foot_min(head_extras(ch), bp, bn, bb)
		head_g[2] = gx
		if gx < 0.002 and hat_rot < 0.5:
			var st := _tilt_hat(ch, bp, bn, bb, minf(0.1, 0.5 - hat_rot), hat_sign)
			hat_rot += absf(st[0])
			hat_sign = st[1]
			moved = true
			continue
		break
	ch.set_meta("selka_kulmat", ang)
	ch.refresh_pose()
	return [0.0, gu, gl, moved, head_g]


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
	ch.set_override("neck_01", Vector3.RIGHT, 0.0)  # niska selkärangan linjassa, ei eteentaivutusta


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
		for p in world_points(ch, limb_points, ["pelvis", "spine_01", "spine_02", "spine_03"]):
			for tb in boxes:
				var q: Vector3 = (tb[0] as Transform3D).affine_inverse() * p
				var h: Vector3 = tb[1]
				if absf(q.x) < h.x + 0.02 and absf(q.z) < h.z + 0.02 and q.y < h.y:
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


## Selkänojan laatikko (face_box), jonka etupinnalla back.p on, tai tyhjä.
static func _back_box(node: Node3D) -> Array:
	if not Seat.of(node).has("back"):
		return []
	var bn: Vector3 = (node.global_transform.basis * (Seat.of(node).back.n as Vector3)).normalized()
	for b in contacts(node, 0.0):
		if (b[0] as Transform3D).basis.y.dot(bn) > 0.9:
			return b
	return []


## Hattu pois nojan sisältä: päähän kiinnitettyjen esineiden solmut kiertyvät etureunan (suurin p·bn) kautta kulkevan, nojan
## suuntaa vastaan kohtisuoran vaaka-akselin ympäri niin, että takareuna nousee nojasta. step = enintään tämän verran (rad);
## sign = tunnettu kiertosuunta (0 = selvitetään kokeilemalla). Palauttaa [kierto rad, kiertosuunta].
static func _tilt_hat(ch: Node3D, bp: Vector3, bn: Vector3, bb: Array, step: float, sign: float) -> Array:
	var nodes := []
	for ba in ch.skeleton.get_children():
		if ba is BoneAttachment3D and (ba as BoneAttachment3D).bone_name == "Head":
			for c in ba.get_children():
				if c is Node3D and c.has_meta("hattu"):
					nodes.append(c)
	if nodes.is_empty():
		return [0.0, sign]
	var lean_dir := Vector3.UP - bn * Vector3.UP.dot(bn)  # nojan pinnan yläsuunta
	var axis := bn.cross(lean_dir).normalized()
	var worst := func() -> float: return _foot_min(head_extras(ch), bp, bn, bb)
	var pivot := Vector3.ZERO
	var best := -INF
	for p in head_extras(ch):
		if (p - bp).dot(bn) > best:
			best = (p - bp).dot(bn)
			pivot = p
	var g0: float = worst.call()
	for sg in ([sign] if sign != 0.0 else [1.0, -1.0]):
		var bs := Basis(axis, step * sg)
		var t := Transform3D(bs, pivot - bs * pivot)
		var olds := []
		for n in nodes:
			olds.append((n as Node3D).global_transform)
			(n as Node3D).global_transform = t * (n as Node3D).global_transform
		if sign != 0.0 or float(worst.call()) > g0:
			return [step * sg, sg]
		for i in nodes.size():
			(nodes[i] as Node3D).global_transform = olds[i]
	return [0.0, sign]


## Jalan (reisi ja sääri) suurin tunkeuma muihin kuin istuinkappaleisiin (m), kuten clear_legs mittaa; 0 jos ei tunkeudu.
static func leg_pen(ch: Node3D, node: Node3D, prof: Dictionary, seat_y: float, lr: String) -> float:
	var solids := world_solids(node)
	var pen_max := 0.0
	for c in _caps_world(ch, prof, ["thigh" + lr, "calf" + lr]):
		for k in 6:
			var p: Vector3 = (c[0] as Vector3).lerp(c[1], k / 5.0)
			for s in solids:
				if absf(_top_y(s) - seat_y) < 0.03:
					continue
				var dp := depth(s, p)
				var low := _top_y(s) < seat_y and k < 5
				if dp > 0.0 or (low and dp > -(c[2] as float) + 0.005):
					pen_max = maxf(pen_max, dp + (c[2] as float))
	return pen_max


## Pisteiden pienin etäisyys nojan pinnasta (pinnan normaalia pitkin) niistä pisteistä, jotka ovat nojalaatikon jalanjäljen
## kohdalla (2 cm:n marginaali); ilman laatikkoa kaikista. INF, jos yksikään ei ole jalanjäljellä.
static func _foot_min(pts: PackedVector3Array, bp: Vector3, bn: Vector3, bb: Array, top_margin := 0.02) -> float:
	var g := INF
	var inv := Transform3D()
	if not bb.is_empty():
		inv = (bb[0] as Transform3D).affine_inverse()
	for p in pts:
		if not bb.is_empty():
			var q: Vector3 = inv * p
			var h: Vector3 = bb[1]
			if absf(q.x) > h.x + 0.02 or absf(q.z) > h.z + top_margin:
				continue
		g = minf(g, (p - bp).dot(bn))
	return g


## Lierihatut (meta "hattu") takaisin päähän alkuperäiseen asentoonsa: _tilt_hat kallistaa niitä nojaa vasten, ja ilman
## palautusta kallistus kertyisi jokaisella istutuskerralla. Ensimmäisellä kutsulla talletetaan lepoasento.
static func reset_hats(ch: Node3D) -> void:
	for ba in ch.skeleton.get_children():
		if not ba is BoneAttachment3D or (ba as BoneAttachment3D).bone_name != "Head":
			continue
		for c in ba.get_children():
			if c is Node3D and c.has_meta("hattu"):
				if c.has_meta("hattu_lepo"):
					(c as Node3D).transform = c.get_meta("hattu_lepo")
				else:
					c.set_meta("hattu_lepo", (c as Node3D).transform)


# --- Hahmo hahmoa vastaan -------------------------------------------------------------------------------------------
# Toinen hahmo kuvataan samoilla kapseleilla (profile) kuin kalusteita vastaan: kahden kapselin päällekkäisyys on yksi
# janasta janaan -etäisyys. Kutsuja ajaa joka ruutu pair_fit -> pair_contacts -> Character.set_contacts.

## Vartalon kapselit, joiden päällekkäisyys siirtää liikkuvaa hahmoa (raajojen IK-ketjut korjataan erikseen).
const PAIR_BODY := ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "thigh_l", "calf_l", "thigh_r", "calf_r"]
const PAIR_ROUNDS := 16


## Kapselin päät maailmassa: [a, b] (pään pallolla a = b).
static func _cap_ends(ch: Node3D, c: Array) -> Array:
	if c[1] != "":
		var a: Vector3 = ch.bone_position(c[0])
		var b: Vector3 = ch.bone_position(c[1])
		if c.size() > 3:  # katkaistu (spine_03, _neck_caps)
			b -= (b - a).normalized() * minf(float(c[3]), a.distance_to(b))
		return [ch.to_global(a), ch.to_global(b)]
	var xf := _bone_xf(ch, c[0])
	if c[0] == "Head":
		var p := ch.to_global(xf * (c[4] as Vector3))
		return [p, p]
	return [ch.to_global(xf.origin), ch.to_global(xf.origin + (xf.basis * (c[4] as Vector3)).normalized() * float(c[3]))]


## Kaikki kapselit (vartalo, raajat, kämmenet, pää) maailmassa: [[nimi, a, b, säde, muoto, keskus, rajasäde], ...].
## Säde on pyöreä säde; muoto = null tai [maailma -> luu -kanta, muototaulu] (vartalo), josta _rad antaa säteen suuntaan.
static func caps_all(ch: Node3D, prof: Dictionary) -> Array:
	var out := []
	for n: String in prof.caps:
		out.append(_cap_world(ch, prof.caps[n], n))
	return out


static func _cap_world(ch: Node3D, c: Array, n: String) -> Array:
	var e := _cap_ends(ch, c)
	var shape: Variant = null
	if c.size() > 4 and c[1] != "":
		shape = [(ch.global_transform.basis * _bone_xf(ch, c[0]).basis).orthonormalized().transposed(), c[4]]  # maailma -> luu
	var bound: float = (e[0] as Vector3).distance_to(e[1]) * 0.5 + float(c[2]) * 1.5  # rajapallo: muototaulu <= 1,5 r
	return [n, e[0], e[1], float(c[2]), shape, ((e[0] as Vector3) + e[1]) * 0.5, bound]


## Kahden kapselin (caps_all-alkiot) päällekkäisyys: [syvyys m (> 0 päällekkäin), normaali x:stä y:hyn, lähin x:llä,
## lähin y:llä, säde x, säde y]; säteet suuntaan (muototaulu).
static func _pair_depth(x: Array, y: Array) -> Array:
	var cl := _seg_seg_closest(x[1], x[2], y[1], y[2])
	var c0: Vector3 = cl[0]
	var c1: Vector3 = cl[1]
	var d := c0.distance_to(c1)
	var n := (c1 - c0) / d if d > 0.0001 else Vector3.ZERO
	var ra: float = _rad(x, _t_on(c0, x[1], x[2]), n) if d > 0.0001 else float(x[3])
	var rb: float = _rad(y, _t_on(c1, y[1], y[2]), -n) if d > 0.0001 else float(y[3])
	return [ra + rb - d, n, c0, c1, ra, rb]


## Pisteen p (pallo, säde rp) syvyys kapselissa c: [syvyys, normaali ulos kapselista, d].
static func _pt_depth(p: Vector3, rp: float, c: Array) -> Array:
	var q := _seg_closest(p, c[1], c[2])
	var d := p.distance_to(q)
	if d < 0.0001:
		return [rp + float(c[3]), Vector3.ZERO, d]
	var n := (p - q) / d
	return [rp + _rad(c, _t_on(q, c[1], c[2]), n) - d, n, d]


## Janojen p1-q1 ja p2-q2 lähimmät pisteet [c1, c2] (Ericson, Real-Time Collision Detection 5.1.9).
static func _seg_seg_closest(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 0.000001 and e <= 0.000001:
		return [p1, p2]
	if a <= 0.000001:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 0.000001:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 0.000001 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return [p1 + d1 * s, p2 + d2 * t]


## Hahmojen a ja b päällekkäiset kapseliparit: [[nimi a, nimi b, syvyys m], ...] syvin ensin; syvyys = säteiden summa -
## janojen lyhin etäisyys. Mukana parit, joiden syvyys > min_d.
static func overlap_pairs(a: Node3D, pa: Dictionary, b: Node3D, pb: Dictionary, min_d := 0.0) -> Array:
	var out := []
	var cb := caps_all(b, pb)
	for x in caps_all(a, pa):
		for y in cb:
			if (x[5] as Vector3).distance_to(y[5]) > float(x[6]) + float(y[6]) - min_d:
				continue
			var dd: float = _pair_depth(x, y)[0]
			if dd > min_d:
				out.append([x[0], y[0], dd])
	out.sort_custom(func(p: Array, q: Array) -> bool: return float(p[2]) > float(q[2]))
	return out


## Pisteen (pallo, säde r) rako kapseleihin caps (caps_all-muoto): [rako m (< 0 sisällä), normaali ulos lähimmästä].
static func _clearance(p: Vector3, caps: Array, r: float) -> Array:
	var best := INF
	var n := Vector3.ZERO
	for c in caps:
		var pd := _pt_depth(p, r, c)
		if -float(pd[0]) < best:
			best = -float(pd[0])
			n = pd[1]
	return [best, n]


## Kahden hahmon kapselit erilleen enintään PAIR_ROUNDS kierroksella: (1) vartalot (torso, kaula, pää ja jalat): b siirtyy vaakasuunnassa irti a:sta
## (vain move_b); (2) kummankin IK-ketjut (arm_*, leg_*): ketjun syvin piste toisen kapseleista ulos. Ketjun loppupää
## (s >= 0,75 olasta kämmenen päähän) siirtää kohdetta: kämmen suoraan ulos, kyynärvarsi liu'uttaa kohdetta pinnan
## tangenttia pitkin samalla raolla (käsi pysyy pinnalla); alkupää siirtää polea (kyynärpää/polvi kiertää ohi), paitsi
## suoralla kädellä (kohde ulottumattomissa), jolloin pole ei auta ja kohde liukuu kuten kyynärvarrella.
## Muokkaa _ik-kohteita: kutsuja asettaa ne joka ruutu uudelleen. Palauttaa jäljelle jääneen syvimmän päällekkäisyyden (m).
static func pair_fit(a: Node3D, pa: Dictionary, b: Node3D, pb: Dictionary, move_b := true) -> float:
	for rd in PAIR_ROUNDS:
		a.refresh_pose()
		b.refresh_pose()
		var moved := false
		if move_b:
			var pen := 0.0
			var n := Vector3.ZERO
			var cb := []
			for nm in PAIR_BODY:
				if pb.caps.has(nm):
					cb.append(_cap_world(b, pb.caps[nm], nm))
			for nm in PAIR_BODY:
				if not pa.caps.has(nm):
					continue
				var x := _cap_world(a, pa.caps[nm], nm)
				for y in cb:
					if (x[5] as Vector3).distance_to(y[5]) > float(x[6]) + float(y[6]):
						continue
					var pd := _pair_depth(x, y)
					if float(pd[0]) > pen and pd[1] != Vector3.ZERO:
						pen = pd[0]
						n = pd[1]
			var nh := Vector3(n.x, 0, n.z)
			if pen > 0.003 and nh.length() > 0.2:
				_shift(b, nh.normalized() * minf((pen + 0.003) / nh.length(), 0.2))
				b.refresh_pose()
				moved = true
		if _fit_chains(a, pa, b, pb):
			moved = true
		if _fit_chains(b, pb, a, pa):
			moved = true
		if not moved:
			break
	a.refresh_pose()
	b.refresh_pose()
	var left := overlap_pairs(a, pa, b, pb)
	return float(left[0][2]) if not left.is_empty() else 0.0


## Hahmon ch IK-ketjut ulos toisen hahmon kapseleista (pair_fit, kierros 2). Palauttaa, siirtyikö jokin kohde tai pole.
static func _fit_chains(ch: Node3D, prof: Dictionary, other: Node3D, oprof: Dictionary) -> bool:
	var oc := caps_all(other, oprof)
	var inv := ch.global_transform.affine_inverse()
	var any := false
	for chain: String in ["arm_l", "arm_r", "leg_l", "leg_r"]:
		if not ch._ik.has(chain):
			continue
		var lr := chain.right(2)
		var arm := chain.begins_with("arm")
		var names := ["upperarm" + lr, "lowerarm" + lr, "hand" + lr] if arm else ["thigh" + lr, "calf" + lr]
		var parts := []
		var total := 0.0
		for nm in names:
			var ce := _cap_ends(ch, prof.caps[nm])
			parts.append([ce[0], ce[1], float((prof.caps[nm] as Array)[2])])
			total += (ce[0] as Vector3).distance_to(ce[1])
		var wrist_s: float = 1.0
		if arm:
			wrist_s = ((parts[0][0] as Vector3).distance_to(parts[0][1]) + (parts[1][0] as Vector3).distance_to(parts[1][1])) / maxf(total, 0.001)
		# Syvin kohta jokaista toisen kapselia vasten: [syvyys, normaali ulos, s]
		var per := {}
		var acc := 0.0
		for pt in parts:
			var ln: float = (pt[0] as Vector3).distance_to(pt[1])
			for k in 6:
				var p: Vector3 = (pt[0] as Vector3).lerp(pt[1], k / 5.0)
				for c in oc:
					if p.distance_to(c[5]) > float(c[6]) + float(pt[2]):
						continue
					var pd := _pt_depth(p, pt[2], c)
					var pen: float = pd[0]
					if pen > 0.003 and pd[1] != Vector3.ZERO and pen > float((per.get(c[0], [0.0]) as Array)[0]):
						per[c[0]] = [pen, pd[1], (acc + ln * k / 5.0) / maxf(total, 0.001)]
			acc += ln
		if per.is_empty():
			continue
		var e: Array = ch._ik[chain]
		# Siirto lasketaan ranteen (nilkan) todellisesta paikasta: jos kohde on ulottumattomissa, käsi on suorana kohti sitä,
		# eikä kohteen siirto kohti olkaa tai pole liikuttaisi kättä lainkaan.
		var tw: Vector3 = ch.to_global(ch.bone_position(("hand" if arm else "foot") + lr))
		var stretched := tw.distance_to(ch.global_transform * (e[3] as Vector3)) > 0.005
		var items: Array = per.values()
		items.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
		var t_push := Vector3.ZERO
		var p_push := Vector3.ZERO
		var t_s := 0.0  # syvimmän kohdetta siirtävän kohdan s
		# Nivelen taivutussuunta (kohtisuoraan olka-kohde-akselia): jos työntö on jo sen suuntainen, pole ei voi viedä
		# niveltä kauemmas, ja työntö siirtää kohdetta.
		var sh0: Vector3 = ch.to_global(ch.bone_position(names[0]))
		var ax0 := (tw - sh0).normalized()
		var j0: Vector3 = ch.to_global(ch.bone_position(names[1])) - sh0
		var bend := (j0 - ax0 * j0.dot(ax0)).normalized()
		for it in items:
			var push: Vector3 = (it[1] as Vector3) * (float(it[0]) + 0.003)
			for nm: String in per:
				if per[nm] == it and _ik_cap(other, nm):
					push *= 0.5  # toinenkin raaja väistää
			if float(it[2]) < 0.75 and not stretched and bend.dot(it[1]) < 0.8:
				p_push = _merge_push(p_push, push)
			else:
				if t_push == Vector3.ZERO:
					t_s = it[2]
				t_push = _merge_push(t_push, push)
		if p_push != Vector3.ZERO:
			# Kyynärpää tai polvi kiertää ohi. Pole on kauempana ketjun akselista kuin nivel, joten sitä siirretään
			# suhteessa enemmän, jotta nivel liikkuu noin push * 2.
			var sh: Vector3 = ch.to_global(ch.bone_position(names[0]))
			var ax := (ch.global_transform * (e[3] as Vector3) - sh).normalized()
			var pw: Vector3 = ch.global_transform * (e[4] as Vector3)
			var jw: Vector3 = ch.to_global(ch.bone_position(names[1]))
			var h_p := ((pw - sh) - ax * (pw - sh).dot(ax)).length()
			var h_j := ((jw - sh) - ax * (jw - sh).dot(ax)).length()
			e[4] = (e[4] as Vector3) + inv.basis * p_push * 2.0 * clampf(h_p / maxf(h_j, 0.05), 1.0, 10.0)
		if t_push == Vector3.ZERO:
			pass
		elif not arm:
			e[3] = inv * (tw + Vector3(t_push.x, 0, t_push.z))  # jalkaterä vaakasuunnassa (maa pysyy alla)
		else:
			var hr: float = (prof.caps["hand" + lr] as Array)[2]
			var g0 := _clearance(tw, oc, hr)
			var nt: Vector3 = g0[1]
			var slide := t_push - nt * t_push.dot(nt)
			var nw := tw + t_push
			if (t_s <= wrist_s or stretched) and float(g0[0]) < 0.05 and slide.length() > t_push.length() * 0.3:
				# Kyynärvarsi kyljessä: kohde liukuu pinnan suuntaisesti ja pysyy samalla raolla (ei hylkää pintaa).
				nw = tw + slide
				var g1 := _clearance(nw, oc, hr)
				nw += (g1[1] as Vector3) * (maxf(float(g0[0]), 0.003) - float(g1[0]))
			e[3] = inv * nw
		any = true
	return any


## Työnnöt yhteen ilman tuplalaskentaa: uudesta työnnöstä lisätään vain osa, jota nykyinen ei jo kata sen suunnassa.
## Vastakkainen (raaja puristuksissa kahden kapselin välissä) ohitetaan: syvempi (ensin tullut) voittaa.
static func _merge_push(total: Vector3, push: Vector3) -> Vector3:
	var l := push.length()
	if l < 0.000001 or total.dot(push) < 0.0:
		return total
	var u := push / l
	return total + u * maxf(l - total.dot(u), 0.0)


## Onko kapseli nm hahmon IK-ketjussa (raaja, joka voi itse väistää)?
static func _ik_cap(ch: Node3D, nm: String) -> bool:
	for pre in ["upperarm", "lowerarm", "hand"]:
		if nm.begins_with(pre):
			return ch._ik.has("arm" + nm.right(2))
	for pre in ["thigh", "calf"]:
		if nm.begins_with(pre):
			return ch._ik.has("leg" + nm.right(2))
	return false


## Painuman laatikot hahmopariin: jokaisesta kapseliparista, jonka rako < gap, yhteinen taso kapselipintojen puolivälissä;
## kummallekin laatikko toisen puolelle tasoa, +Y omaa hahmoa kohti, puolikoko toisen kapselin säteestä. Syvin ensin,
## enintään Character.PRESS_MAX (6) per hahmo. Palauttaa [laatikot a, laatikot b] (Character.set_contacts-muoto).
static func pair_contacts(a: Node3D, pa: Dictionary, b: Node3D, pb: Dictionary, gap := 0.01) -> Array:
	var found := []
	var cb := caps_all(b, pb)
	var ab: Vector3 = b.global_position - a.global_position
	for x in caps_all(a, pa):
		for y in cb:
			if (x[5] as Vector3).distance_to(y[5]) > float(x[6]) + float(y[6]) + gap:
				continue
			var pd := _pair_depth(x, y)
			if -float(pd[0]) >= gap:
				continue
			var n: Vector3 = pd[1] if pd[1] != Vector3.ZERO else Vector3(ab.x, 0, ab.z).normalized()
			var ra: float = pd[4]
			var rb: float = pd[5]
			var mid: Vector3 = ((pd[2] as Vector3) + n * ra + (pd[3] as Vector3) - n * rb) * 0.5
			found.append([pd[0], n, mid, ra, rb])
	found.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) > float(q[0]))
	var out_a := []
	var out_b := []
	for f in found:
		var n: Vector3 = f[1]
		if out_a.size() < 6:
			out_a.append([_plane_xf(-n, f[2] + n * float(f[4])), Vector3.ONE * float(f[4])])
		if out_b.size() < 6:
			out_b.append([_plane_xf(n, f[2] - n * float(f[3])), Vector3.ONE * float(f[3])])
	return [out_a, out_b]


## Laatikon kehys, jonka +Y = y ja keskus = c (x vaakaan, jos mahdollista).
static func _plane_xf(y: Vector3, c: Vector3) -> Transform3D:
	var x := Vector3.UP.cross(y)
	if x.length() < 0.1:
		x = Vector3.RIGHT.cross(y)
	x = x.normalized()
	return Transform3D(Basis(x, y, x.cross(y)), c)


## Kohta kapselin cap pinnalla suuntaan dir (akselia vastaan kohtisuora osa) parametrilla along (0 = a, 1 = b); pään
## pallolla suoraan dir-suuntaan. IK-kohteiden laskuun (lisää kämmenen säde, niin kämmen on pinnalla).
static func surface_point(ch: Node3D, prof: Dictionary, cap: String, dir: Vector3, along := 0.5) -> Vector3:
	var cw := _cap_world(ch, prof.caps[cap], cap)
	var p: Vector3 = (cw[1] as Vector3).lerp(cw[2], along)
	var ax: Vector3 = (cw[2] as Vector3) - cw[1]
	var d := dir
	if ax.length() > 0.0001:
		d = dir - ax.normalized() * dir.dot(ax.normalized())
	if d.length() < 0.0001:
		d = dir
	d = d.normalized()
	return p + d * _rad(cw, along, d)
