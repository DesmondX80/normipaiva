## Hahmojen asentojen apufunktiot: kämmenen asento (vasen ja oikea ovat peilikuvia) ja raajan sovitus vartalon,
## vaatteen tai toisen hahmon pintaan paistetusta verkosta. Säännöt: CLAUDE.md "Hahmojen asennot ja kalusteet".
## Käyttö: const Pose := preload("res://scripts/pose.gd"); Pose.palm_down(sormet, vasen).

const Seat := preload("res://scripts/seat.gd")
const Contact := preload("res://scripts/contact.gd")
const Elastic := preload("res://scripts/elastic.gd")

## Käden luun akselit (Quaternius): Y sormia kohti ja -X kämmenestä ulos oikeassa kädessä. Vasen käsi on peilikuva:
## sama asento kierrettynä sormiakselin ympäri 180°.


## Kämmen pintaa vasten: sormet suuntaan fingers, kämmen osoittaa suuntaan into (esim. alas reiteen tai vatsan
## sisään). Hahmon avaruudessa, set_ik_orient-kutsuun. left = vasen käsi.
static func palm_on(fingers: Vector3, into: Vector3, left: bool) -> Basis:
	var y := fingers.normalized()
	var x := (-into - y * y.dot(-into)).normalized()
	var b := Basis(x, y, x.cross(y)).orthonormalized()
	return b * Basis(Vector3.UP, PI) if left else b


## Kämmen tarkasti alas: sormet suuntaan fingers, jonka pystykomponentti litistyy pois (kämmen pysyy vaakatasossa).
static func palm_down(fingers: Vector3, left: bool) -> Basis:
	var y := fingers.normalized()
	var other := y.cross(Vector3.UP).normalized()
	var b := Basis(Vector3.UP, y, -other).orthonormalized()
	return b * Basis(Vector3.UP, PI) if left else b


## Hahmon pinnan pisteet (space-solmun avaruudessa), joiden pääluu on bones-listassa (esim. reisi ja sääri). Verkko
## lasketaan nykyasentoon (luiden asennosta, heti ajan tasalla), ja housujen pöyhennys (pants_puff, varjostin) lisätään, jotta käsi ja jalat
## sovitetaan näkyvään pintaan eikä luuhun kiinteällä välillä (tuulipuku on paksumpi kuin farkut).
## meshes: 0 = vartalo ja hiukset, 1 = vain vartalo (ja vaatteet), 2 = vain hiukset (painuvat kuten varjostimessa).
## Ilman näyttöä (headless) verkkoa ei paisteta: palauttaa tyhjän, ja kutsuja käyttää varalla luuta.
static func limb_points(ch: Node3D, space: Node3D, bones: Array, meshes := 0) -> PackedVector3Array:
	var out := PackedVector3Array()
	if DisplayServer.get_name() == "headless":
		return out
	var pp: Variant = ch.body_mat.get_shader_parameter("pants_puff")
	var puff: float = pp if pp != null else 0.014  # varjostimen oletus
	var bikini: bool = ch.body_mat.get_shader_parameter("string_bikini") == true  # lappubikinit: ei pöyhennystä
	var skel: Skeleton3D = ch.skeleton
	for mi in skel.get_children():
		if not mi is MeshInstance3D or (mi as MeshInstance3D).skin == null:
			continue
		var is_hair: bool = mi.has_meta("hair_press")
		if (meshes == 1 and is_hair) or (meshes == 2 and not is_hair):
			continue
		var src: Dictionary = _src_arrays(mi as MeshInstance3D)
		if src.is_empty():
			continue
		var rv: PackedVector3Array = src.vs
		var rn: PackedVector3Array = src.ns
		var bi: PackedInt32Array = src.bi
		var bw: PackedFloat32Array = src.bw
		var cs: PackedColorArray = src.cs
		var c0: PackedFloat32Array = src.c0 if ((mi == ch.body_mi or is_hair) and not ch.press_boxes.is_empty()) else PackedFloat32Array()  # painumaraja w (Elastic)
		var hair_org: Vector3 = ch._head_center() if is_hair else Vector3.ZERO
		var per: int = src.per
		var sk: Skin = (mi as MeshInstance3D).skin
		var want := {}
		for bind in sk.get_bind_count():
			var nm := str(sk.get_bind_name(bind))
			var bn: int = sk.get_bind_bone(bind) if nm == "" else skel.find_bone(nm)
			if nm == "":
				nm = skel.get_bone_name(bn)
			if nm in bones and bn >= 0:
				want[bind] = skel.get_bone_global_pose(bn) * sk.get_bind_pose(bind)
		# Ihon pinta lasketaan itse luiden nykyasennosta (ei bake_mesh: se päivittyy vasta seuraavassa ruudussa).
		var xf: Transform3D = skel.global_transform
		var tb: Transform3D = (mi as MeshInstance3D).global_transform.affine_inverse() * xf  # skeleton -> mesh-avaruus
		var tb_inv := tb.affine_inverse()
		for v in rv.size():
			var best := 0
			for k in per:
				if bw[v * per + k] > bw[v * per + best]:
					best = k
			if not want.has(bi[v * per + best]):
				continue
			var vp := Vector3.ZERO
			var np := Vector3.ZERO
			for k in per:
				var wk: float = bw[v * per + k]
				if wk <= 0.0:
					continue
				var b: int = bi[v * per + k]
				var m: Transform3D = want[b] if want.has(b) else _bind_mat(skel, sk, b)
				vp += (m * rv[v]) * wk
				np += (m.basis * rn[v]) * wk
			np = np.normalized()
			var pants := cs.size() == rv.size() and roundi(cs[v].r * 4.0) == 2 and not bikini
			var pf := puff if pants else 0.0
			vp += np * pf  # pöyhennys ensin, sitten painuma (kuten varjostin: vaate painuu mukana)
			if not c0.is_empty() and c0[v * 4 + 3] > 0.0:
				if is_hair:  # hiukset leviävät pois pään keskuksesta pinnan suuntaisesti (hair.gdshader)
					vp = tb_inv * Elastic.press(tb * vp, tb.basis * np, c0[v * 4 + 3], ch.press_boxes, Elastic.SPREAD, Elastic.HALO, 1.0, tb * hair_org)
				else:
					vp = tb_inv * Elastic.press(tb * vp, tb.basis * np, c0[v * 4 + 3] + pf, ch.press_boxes)  # mesh-avaruudessa
			out.append(space.to_local(xf * vp))
	return out


static var _src_cache := {}


## Verkon lepoasennon taulukot (välimuistissa): vs, ns, bi, bw, cs, c0, per.
static func _src_arrays(mi: MeshInstance3D) -> Dictionary:
	var key := mi.mesh.get_instance_id()
	if _src_cache.has(key):
		return _src_cache[key]
	var a: Array = mi.mesh.surface_get_arrays(0)
	var out := {}
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bi: PackedInt32Array = a[Mesh.ARRAY_BONES] if a[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	if not vs.is_empty() and not bi.is_empty() and bi.size() % vs.size() == 0:
		out = {"vs": vs, "ns": a[Mesh.ARRAY_NORMAL], "bi": bi, "bw": a[Mesh.ARRAY_WEIGHTS], "per": bi.size() / vs.size(),
			"cs": a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray(),
			"c0": a[Mesh.ARRAY_CUSTOM0] if a[Mesh.ARRAY_CUSTOM0] != null else PackedFloat32Array()}
	_src_cache[key] = out
	return out


static func _bind_mat(skel: Skeleton3D, sk: Skin, bind: int) -> Transform3D:
	var nm := str(sk.get_bind_name(bind))
	var bn: int = sk.get_bind_bone(bind) if nm == "" else skel.find_bone(nm)
	return skel.get_bone_global_pose(bn) * sk.get_bind_pose(bind)

## Pinnan yläreuna (suurin y) kohdan p kohdalla: pisteet vaakasäteellä r ja enintään korkeudella max_y. r_above (jos >= 0) on
## vaakasäde p:n yläpuolisille pisteille: pinta, joka on sivulla ja ylempänä (kallistunut vartalo, reiden reuna), ei ole
## kohdan päällä; vain suoraan yläpuolella oleva pinta kertoo, että kohta on pinnan alla. -INF, jos kohdalla ei ole pintaa.
static func top_y(pts: PackedVector3Array, p: Vector3, r := 0.03, max_y := INF, r_above := -1.0) -> float:
	var top := -INF
	for q in pts:
		var rr := r if (q.y <= p.y or r_above < 0.0) else r_above
		if q.y <= max_y and Vector2(q.x - p.x, q.z - p.z).length() < rr:
			top = maxf(top, q.y)
	return top


## Raon tarkistus: luiden a -> b -> c (esim. olkavarsi, kyynärvarsi, käsi) keskilinjan korkeus pinnan pts
## yläpuolella näytepisteissä, space-solmun avaruudessa. Palauttaa [[luu, t, rako], ...]; negatiivinen rako = luu
## on pinnan alla. Testikohtauksiin ja toteuttajan omaan tarkistukseen (rako < raajan paksuus = läpi).
static func clearance(ch: Node3D, space: Node3D, chain: Array, pts: PackedVector3Array, steps := 4) -> Array:
	var out := []
	for i in chain.size() - 1:
		var a: Vector3 = space.to_local(ch.to_global(ch.bone_position(chain[i])))
		var b: Vector3 = space.to_local(ch.to_global(ch.bone_position(chain[i + 1])))
		for s in steps + 1:
			var t := float(s) / steps
			var p := a.lerp(b, t)
			var top := top_y(pts, p, 0.04, p.y + 0.06, 0.015)  # alla 4 cm, päällä vain suoraan yläpuolella (1,5 cm) oleva pinta
			if top > -INF:
				out.append([chain[i], t, p.y - top])
	return out


## Istuma-apu (yhteinen kaikille istujille). Lantioluu on lonkkanivelen kohdalla, noin näin paljon istuimen
## pinnan yläpuolella kun pakara koskettaa istuinta (tarkistetaan seat_report-rivillä).
const HIP_OVER_SEAT := 0.1
const FOOT_H := 0.08  # nilkkaluun korkeus jalkapohjasta


## Istuttaa hahmon: kasvot (paikallinen -Z) vaakasuuntaan front ja lantion pohja istuimen pisteeseen seat_pt
## (hahmon vanhemman avaruudessa, istuimen yläpinta). Hahmon sijainti vanhemmassa muuttuu, kalusteen ei.
static func seat(ch: Node3D, front: Vector3, seat_pt: Vector3) -> void:
	ch.rotation.y = atan2(-front.x, -front.z)  # = B.yaw_to
	ch.anim.advance(0.01)
	var pel: Vector3 = ch.basis * ch.bone_position("pelvis")
	ch.position = seat_pt - pel + Vector3(0, HIP_OVER_SEAT, 0)


## Jalat lattialle (floor_y vanhemman avaruudessa) kummankin lonkan kohdalle: sääri suoraan alas, polvi eteen
## suuntaan front. Kutsu seat:n jälkeen. Jalat eivät mene ristiin, koska kohde on oman lonkan sivulla.
static func feet_to_floor(ch: Node3D, floor_y: float, front: Vector3) -> void:
	front = Vector3(front.x, 0, front.z).normalized()
	var inv := ch.transform.affine_inverse()
	for lr: String in ["_l", "_r"]:
		var hip: Vector3 = ch.transform * ch.bone_position("thigh" + lr)
		var l1: float = ch.bone_position("thigh" + lr).distance_to(ch.bone_position("calf" + lr))
		var l2: float = ch.bone_position("calf" + lr).distance_to(ch.bone_position("foot" + lr))
		var dy := hip.y - (floor_y + FOOT_H)
		var fwd := minf(sqrt(maxf((l1 + l2) * (l1 + l2) * 0.92 - dy * dy, 0.0025)), l1 * 0.9)  # reisi lähes vaakaan, sääri alas
		var tgt := Vector3(hip.x, floor_y + FOOT_H, hip.z) + front * fwd
		var pole := (hip + tgt) / 2.0 + front * 0.3 + Vector3(0, 0.1, 0)
		ch.set_ik("leg" + lr, "thigh" + lr, "calf" + lr, "foot" + lr, inv * tgt, inv * pole)


## Kämmenet reisille (lap: sylissä keskellä) pinnasta laskien. Kutsu vasta, kun jalka-IK on ollut voimassa yhden ruudun (limb_points
## paistaa nykyasennon). space = solmu, jonka avaruudessa pinta luetaan. Headless: varalla reisiluu.
static func hands_on_thighs(ch: Node3D, space: Node3D, lap := false) -> void:
	var pts := limb_points(ch, space, ["thigh_l", "thigh_r"])
	var inv := ch.global_transform.affine_inverse()
	for lr: String in ["_l", "_r"]:
		var hip: Vector3 = space.to_local(ch.to_global(ch.bone_position("thigh" + lr)))
		var knee: Vector3 = space.to_local(ch.to_global(ch.bone_position("calf" + lr)))
		var sh: Vector3 = space.to_local(ch.to_global(ch.bone_position("upperarm" + lr)))
		var arm_len: float = sh.distance_to(space.to_local(ch.to_global(ch.bone_position("lowerarm" + lr)))) \
			+ space.to_local(ch.to_global(ch.bone_position("lowerarm" + lr))).distance_to(space.to_local(ch.to_global(ch.bone_position("hand" + lr))))
		var fwd0 := Vector3(knee.x - hip.x, 0, knee.z - hip.z).normalized()
		var p := hip.lerp(knee, 0.6)
		# Kohde on aina pinnalla, jonne käsi luontevasti laskeutuu (reisi, sylissä reisien yläpinta); jos käsi ei yllä (polvi korkealla,
		# pitkä askel), kohde siirretään lonkkaa kohti, kunnes olkapää yltää.
		var high: bool = knee.y - hip.y > 0.10  # polvi korkealla (matala askelma): kädet polven päälle
		for fr in ([1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2] if high else [0.6, 0.5, 0.4, 0.3, 0.2]):
			p = hip.lerp(knee, fr)
			if lap:  # sylissä: reisien yläpinnalla lähellä keskilinjaa, kädet vierekkäin
				var hip_o: Vector3 = space.to_local(ch.to_global(ch.bone_position("thigh" + ("_r" if lr == "_l" else "_l"))))
				var mid := (hip + hip_o) / 2.0
				var side := (hip - hip_o)
				side.y = 0
				p = mid + fwd0 * 0.17 * (fr / 0.6) + side.normalized() * 0.05
			var top := top_y(pts, p, 0.04)
			p.y = (top if top > -INF else p.y + 0.07) + 0.045
			if p.distance_to(sh) <= arm_len * 0.93:
				break
		var out_dir := (Vector3(sh.x, 0, sh.z) - Vector3(hip.x, 0, hip.z)).normalized()
		# Olkavarsi roikkuu kyljen vieressä: kyynärpää taakse-alas (ei eteen eikä sivulle), kyynärvarsi eteen reidelle
		var fwd := fwd0
		var elbow := (sh + p) / 2.0 - fwd * 0.3 + out_dir * 0.02 + Vector3(0, -0.15, 0)
		if lap:  # kyynärpäät sivulle ja eteen, ei selkänojan sisään
			elbow = (sh + p) / 2.0 + out_dir * 0.1 + fwd * 0.05 + Vector3(0, -0.05, 0)
		var fingers := (knee - hip)
		fingers.y = clampf(fingers.y, -0.15 * fingers.length(), 0.2 * fingers.length())  # kämmen alas, sormet reiden suuntaan (ei ylös)
		var gb := ch.global_transform.basis.inverse()
		var sp := space.global_transform
		ch.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, inv * (sp * p), inv * (sp * elbow))
		ch.set_ik_orient("arm" + lr, palm_on(gb * (sp.basis * fingers), gb * Vector3.DOWN, lr == "_l"), 1.0)



## Istumatyylit (Pose.sit): JAYKKA = mummot, pysty selkä, polvet 90°, kädet reisillä; SUORA = jakkara, portaat, penkki
## ilman selkänojaa, sama asento; RENTO = selkä selkänojan kulmassa ja kiinni siinä, jalat ojossa (opts.ristissa:
## nilkat ristissä), kädet reisillä tai opts.hands = kalusteen kohteen nimi (Seat: hands).
const JAYKKA := 0
const SUORA := 1
const RENTO := 2


## Istuttaa hahmon kalusteen istumapaikkaan (Seat.spot) ja ratkaisee kontaktit: lantio pinnalle, selkä selkänojaan
## (RENTO), vartalo pois pöydän sisältä, jalkapohjat tukipinnalle (korkein tuki kantapään ja päkiän alla) ja kädet
## pinnan päälle. Hahmon pitää olla puussa. Tuloste "KONTAKTI JÄÄ ..." kertoo, jos tunkeuma jäi yli 1 cm.
static func sit(ch: Node3D, node: Node3D, style := SUORA, opts := {}) -> void:
	var d: Dictionary = Seat.of(node)
	if d.is_empty() or not ch.is_inside_tree() or not node.is_inside_tree():
		push_warning("Pose.sit: ei istumapaikkaa tai ei puussa: %s" % node.name)
		return
	var par := ch.get_parent() as Node3D
	var front: Vector3 = node.global_transform.basis * (d.front as Vector3)
	front = Vector3(front.x, 0, front.z).normalized()
	var seat_g: Vector3 = node.to_global(d.seat)
	var baked := DisplayServer.get_name() != "headless" and Engine.get_process_frames() >= int(ch.born_frame) + 3
	ch.clear_contacts()
	seat(ch, par.global_transform.basis.inverse() * front, par.to_local(seat_g))
	var tilt := 0.0
	if style == RENTO and d.has("back"):
		tilt = asin(clampf((node.global_transform.basis * (d.back.n as Vector3)).normalized().y, 0.0, 0.9))
		Contact.lean_spine(ch, tilt)
		if ch.has_meta("selka_kulmat"):
			ch.remove_meta("selka_kulmat")  # uusi istutus: Contact.fit_back aloittaa tasaisesta kallistuksesta
	ch.refresh_pose()
	var prof := Contact.profile(ch, limb_points)
	var left := Contact.fit_body(ch, node, prof, seat_g.y, style == RENTO and not baked)
	if baked:
		Contact.settle_seat(ch, node, seat_g.y, limb_points)
		if style == RENTO and d.has("back"):
			var fb := Contact.fit_back(ch, node, limb_points, tilt)
			tilt += fb[0]
			print("KONTAKTI selkä %s: kallistus +%.1f astetta, yläselän rako %.3f, lantion rako %.3f, kallo/hiukset/hattu %s" % [node.name, rad_to_deg(fb[0]), fb[1], fb[2], fb[4]])
	# Jalat: vaakapaikka lonkan edessä (rento: ojossa), korkeus ja pohjan asento Contact.place_foot. Pakara painuu
	# istuimeen, joten jalat sijoitetaan uudelleen, kun lantion korkeus on tarkentunut.
	var right := front.cross(Vector3.UP).normalized()
	var rento_back: bool = style == RENTO and d.has("back")
	var slide := 0.0  # lantion liuku eteen nojasta (pohje istuimen reunan yli)
	var table_shift := 0.0  # vartalon siirto pöytää kohti yhteensä
	for pass_i in 4:
		_place_legs(ch, node, prof, style, opts, front, right, seat_g)
		if not baked:
			break
		var dy := Contact.settle_seat(ch, node, seat_g.y, limb_points)
		var moved := false
		if style != RENTO:
			# Pöytä sovitetaan istuimen jälkeen: pakaran painuma siirtää y:tä, joten vatsan kohta pöydän kaistalla muuttuu
			var tt := Contact.settle_table(ch, node, seat_g.y, limb_points)
			if absf(tt) > 0.002:
				moved = true
				table_shift += tt
		if rento_back:
			var sl := Contact.clear_seat_edge(ch, node, seat_g.y, front, limb_points, 0.12 - slide)
			slide += sl
			if sl > 0.0:
				moved = true
				_place_legs(ch, node, prof, style, opts, front, right, seat_g)
			var fb := Contact.fit_back(ch, node, limb_points, tilt, slide)
			tilt += fb[0]
			moved = moved or fb[3]
		if absf(dy) < 0.002 and not moved:
			break
		if pass_i == 3:
			_place_legs(ch, node, prof, style, opts, front, right, seat_g)
	if absf(table_shift) > 0.002:
		print("KONTAKTI pöytä %s: vartalo siirtyi %.3f pöytää kohti" % [node.name, table_shift])
	if baked and style != RENTO:
		var lg := Contact.clear_legs(ch, node, prof, seat_g.y)
		if lg > 0.01:
			print("KONTAKTI jalat %s: tunkeuma %.3f korjattu" % [node.name, lg])
	if baked:
		var kr := _knees_down(ch, node, prof, front, seat_g.y)
		if kr > 0.10:
			print("KONTAKTI polvet %s: polvi %.3f lonkan yläpuolella (jalat eivät yllä pidemmälle ilman kappaleisiin menoa)" % [node.name, kr])
	ch.refresh_pose()
	var hands: String = str(opts.get("hands", ""))
	var worst := 0.0
	if hands != "" and (d.get("hands", {}) as Dictionary).has(hands):
		_hands_on_spot(ch, node, d.hands[hands], front)
	else:
		hands_on_thighs(ch, par, rento_back)
		worst = Contact.clear_arms(ch, prof)
		if baked:
			var hg := _fit_hands(ch)
			if hg > 0.01:
				print("KONTAKTI kädet %s: rako reiteen %.3f" % [node.name, hg])
	if hands != "" and (d.get("hands", {}) as Dictionary).has(hands):
		worst = Contact.clear_arms(ch, prof)
	if baked:
		ch.set_contacts(Contact.contacts(node, seat_g.y))
	if left > 0.01:
		print("KONTAKTI JÄÄ %s vartalo %.3f" % [node.name, left])
	if worst > 0.01:
		print("KONTAKTI korjattu %s käsivarsi %.3f" % [node.name, worst])




static func _place_legs(ch: Node3D, node: Node3D, prof: Dictionary, style: int, opts: Dictionary, front: Vector3,
		right: Vector3, seat_g: Vector3) -> void:
	ch.refresh_pose()
	var solids := Contact.world_solids(node)
	var cross_xz := Vector3.ZERO
	var order: Array = ["_r", "_l"] if opts.get("ristissa", false) else ["_l", "_r"]
	for lr: String in order:
		var hip: Vector3 = ch.to_global(ch.bone_position("thigh" + lr))
		var l1: float = ch.bone_position("thigh" + lr).distance_to(ch.bone_position("calf" + lr))
		var l2: float = ch.bone_position("calf" + lr).distance_to(ch.bone_position("foot" + lr))
		var guess := Contact.support_y(solids, hip.x + front.x * 0.4, hip.z + front.z * 0.4, seat_g.y - 0.1)
		guess = maxf(guess, Contact.ground_y(node, hip.x + front.x * 0.4, hip.z + front.z * 0.4, seat_g.y - 0.1))
		if guess == -INF:
			guess = seat_g.y - 0.45
		var dy := hip.y - (guess + float((prof.foot[lr] as Dictionary).sole))
		var reach := (l1 + l2) * (0.88 if style == RENTO else 0.96)
		var fwd := sqrt(maxf(reach * reach * (1.0 if style == RENTO else 0.92) - dy * dy, 0.0025))
		if style != RENTO:
			fwd = minf(fwd, l1 * float(opts.get("jalat_ulos", 0.9)))
		var xz := Vector3(hip.x, 0, hip.z) + front * fwd
		var lift := 0.0
		if style == RENTO and opts.get("ristissa", false):
			# Nilkat ristissä: oikea jalka lepää maassa, vasen nilkka on sen päällä (kapseli- ja nilkkasäteet + 5 mm)
			if lr == "_r":
				xz += right * -0.01
				cross_xz = xz
			else:
				xz = cross_xz
				lift = float((prof.caps["calf_l"] as Array)[2]) * 0.55 + float((prof.caps["calf_r"] as Array)[2]) * 0.55 + 0.005
		Contact.place_foot(ch, node, prof, lr, xz, front, seat_g.y - 0.1, lift, 0.25 if style == RENTO else 0.1)
	ch.refresh_pose()


## Kämmenet reiden pinnalle mitatusta verkosta: kämmenen (käsi ja sormet) alin rako reiden ja sääriluun pintaan (pystysuunnassa)
## kutistetaan 3 mm:iin siirtämällä käden kohdetta. Palauttaa suurimman raon ennen korjausta (m).
static func _fit_hands(ch: Node3D) -> float:
	var worst := 0.0
	for rd in 5:
		ch.refresh_pose()
		var leg := limb_points(ch, ch, ["thigh_l", "thigh_r", "calf_l", "calf_r"])
		var moved := false
		for lr: String in ["_l", "_r"]:
			if not ch._ik.has("arm" + lr):
				continue
			var names := []
			for i in ch.skeleton.get_bone_count():
				var bn: String = ch.skeleton.get_bone_name(i)
				if bn.ends_with(lr) and (bn.begins_with("hand") or bn.begins_with("thumb") or bn.begins_with("index")
						or bn.begins_with("middle") or bn.begins_with("ring") or bn.begins_with("pinky")):
					names.append(bn)
			var gap := INF
			for q in limb_points(ch, ch, names):
				var top := top_y(leg, q, 0.03)
				if top > -INF:
					gap = minf(gap, q.y - top)
			if gap == INF:
				continue
			worst = maxf(worst, gap if rd == 0 else 0.0)
			if absf(gap - 0.003) > 0.004:
				var e: Array = ch._ik["arm" + lr]
				e[3] = (e[3] as Vector3) + Vector3(0, 0.003 - gap, 0)
				moved = true
		if not moved:
			break
	ch.refresh_pose()
	return worst


## Kämmenet kalusteen kohteeseen (käsinoja, ratti): origin = ote, basis.y = pinnan normaali; sormet suuntaan front.
static func _hands_on_spot(ch: Node3D, node: Node3D, t: Transform3D, front: Vector3) -> void:
	var g := node.global_transform * t
	var n := g.basis.y.normalized()
	var inv := ch.global_transform.affine_inverse()
	var gb := ch.global_transform.basis.inverse()
	var right := front.cross(Vector3.UP).normalized()
	for lr: String in ["_l", "_r"]:
		var sgn := -1.0 if lr == "_l" else 1.0
		var p := g.origin + n * 0.03 + right * sgn * 0.0
		var sh: Vector3 = ch.to_global(ch.bone_position("upperarm" + lr))
		var elbow := (sh + p) / 2.0 + Vector3(0, -0.15, 0) - front * 0.2 + right * sgn * 0.08
		ch.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, inv * p, inv * elbow)
		ch.set_ik_orient("arm" + lr, palm_on(gb * front, gb * -n, lr == "_l"), 1.0)


## Polvet eivät nouse lonkan yläpuolelle yli 10 cm ilman syytä: jos polvi on korkealla, jalkaterää siirretään eteen 5 cm kerrallaan
## (place_foot hakee tasaisen pohjan ja tuen), kunnes polvi on alas eikä jalka mene kappaleisiin. Ellei sellaista löydy,
## alkuperäinen asento palautetaan (korkea polvi on silloin perusteltu: jalkaterät ovat lähellä, esim. matala askelma). Palauttaa korkeimman polven nousun lonkasta (m) lopussa.
static func _knees_down(ch: Node3D, node: Node3D, prof: Dictionary, front: Vector3, seat_y: float) -> float:
	var worst := 0.0
	for lr: String in ["_l", "_r"]:
		if not ch._ik.has("leg" + lr):
			continue
		var rise := _knee_rise(ch, lr)
		if rise > 0.10:
			var old: Array = (ch._ik["leg" + lr] as Array).duplicate(true)
			var tg0: Vector3 = ch.global_transform * (old[3] as Vector3)
			var ok := false
			for k in range(1, 9):
				Contact.place_foot(ch, node, prof, lr, tg0 + front * 0.05 * k, front, seat_y - 0.1, 0.0, 0.1)
				ch.refresh_pose()
				if _knee_rise(ch, lr) <= 0.10 and Contact.leg_pen(ch, node, prof, seat_y, lr) < 0.005:
					ok = true
					break
			if not ok:
				ch._ik["leg" + lr] = old
				ch.refresh_pose()
		worst = maxf(worst, _knee_rise(ch, lr))
	return worst


static func _knee_rise(ch: Node3D, lr: String) -> float:
	return ch.bone_position("calf" + lr).y - ch.bone_position("thigh" + lr).y
