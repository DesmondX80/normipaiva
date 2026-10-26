## Hahmojen asentojen apufunktiot: kämmenen asento (vasen ja oikea ovat peilikuvia) ja raajan sovitus vartalon,
## vaatteen tai toisen hahmon pintaan paistetusta verkosta. Säännöt: CLAUDE.md "Hahmojen asennot ja kalusteet".
## Käyttö: const Pose := preload("res://scripts/pose.gd"); Pose.palm_down(sormet, vasen).

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
## paistetaan nykyasentoon, ja housujen pöyhennys (pants_puff, varjostin) lisätään, jotta käsi ja jalat
## sovitetaan näkyvään pintaan eikä luuhun kiinteällä välillä (tuulipuku on paksumpi kuin farkut).
## Ilman näyttöä (headless) verkkoa ei paisteta: palauttaa tyhjän, ja kutsuja käyttää varalla luuta.
static func limb_points(ch: Node3D, space: Node3D, bones: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	if DisplayServer.get_name() == "headless":
		return out
	var pp: Variant = ch.body_mat.get_shader_parameter("pants_puff")
	var puff: float = pp if pp != null else 0.014  # varjostimen oletus
	var skel: Skeleton3D = ch.skeleton
	for mi in skel.get_children():
		if not mi is MeshInstance3D or (mi as MeshInstance3D).skin == null:
			continue
		var baked := (mi as MeshInstance3D).bake_mesh_from_current_skeleton_pose()
		if baked == null:
			continue
		var src: Array = (mi as MeshInstance3D).mesh.surface_get_arrays(0)
		var arr: Array = baked.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bi: PackedInt32Array = src[Mesh.ARRAY_BONES]
		var bw: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
		var cs: PackedColorArray = src[Mesh.ARRAY_COLOR] if src[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		if vs.is_empty() or bi.size() % vs.size() != 0:
			continue
		var per := bi.size() / vs.size()
		var sk: Skin = (mi as MeshInstance3D).skin
		var want := {}
		for bind in sk.get_bind_count():
			var nm := str(sk.get_bind_name(bind))
			if nm == "":
				nm = skel.get_bone_name(sk.get_bind_bone(bind))
			if nm in bones:
				want[bind] = true
		var xf: Transform3D = mi.global_transform
		for v in vs.size():
			var best := 0
			for k in per:
				if bw[v * per + k] > bw[v * per + best]:
					best = k
			if not want.has(bi[v * per + best]):
				continue
			var pants := cs.size() == vs.size() and roundi(cs[v].r * 4.0) == 2
			out.append(space.to_local(xf * (vs[v] + ns[v] * (puff if pants else 0.0))))
	return out


## Pinnan yläreuna (suurin y) kohdan p kohdalla: pisteet vaakasäteellä r. -INF, jos kohdalla ei ole pintaa.
static func top_y(pts: PackedVector3Array, p: Vector3, r := 0.03) -> float:
	var top := -INF
	for q in pts:
		if Vector2(q.x - p.x, q.z - p.z).length() < r:
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
			var top := top_y(pts, p, 0.04)
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


## Kämmenet reisille pinnasta laskien. Kutsu vasta, kun jalka-IK on ollut voimassa yhden ruudun (limb_points
## paistaa nykyasennon). space = solmu, jonka avaruudessa pinta luetaan. Headless: varalla reisiluu.
static func hands_on_thighs(ch: Node3D, space: Node3D) -> void:
	var pts := limb_points(ch, space, ["thigh_l", "thigh_r"])
	var inv := ch.global_transform.affine_inverse()
	for lr: String in ["_l", "_r"]:
		var hip: Vector3 = space.to_local(ch.to_global(ch.bone_position("thigh" + lr)))
		var knee: Vector3 = space.to_local(ch.to_global(ch.bone_position("calf" + lr)))
		var sh: Vector3 = space.to_local(ch.to_global(ch.bone_position("upperarm" + lr)))
		var p := hip.lerp(knee, 0.6)
		var top := top_y(pts, p, 0.04)
		p.y = (top if top > -INF else p.y + 0.07) + 0.045
		var out_dir := (Vector3(sh.x, 0, sh.z) - Vector3(hip.x, 0, hip.z)).normalized()
		# Olkavarsi roikkuu kyljen vieressä: kyynärpää taakse-alas (ei eteen eikä sivulle), kyynärvarsi eteen reidelle
		var fwd := Vector3(knee.x - hip.x, 0, knee.z - hip.z).normalized()
		var elbow := (sh + p) / 2.0 - fwd * 0.3 + out_dir * 0.02 + Vector3(0, -0.15, 0)
		var fingers := (knee - hip)
		var gb := ch.global_transform.basis.inverse()
		var sp := space.global_transform
		ch.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, inv * (sp * p), inv * (sp * elbow))
		ch.set_ik_orient("arm" + lr, palm_on(gb * (sp.basis * fingers), gb * Vector3.DOWN, lr == "_l"), 1.0)


## Jalat roikkumaan istuimen reunan yli (laituri): reisi eteen lähes vaakaan, sääri suoraan alas polvesta. Kutsu seat:n
## jälkeen; front = suunta reunan yli. Lantion pitää olla reunan takana vähintään reiden mitan verran.
static func legs_hang(ch: Node3D, front: Vector3) -> void:
	front = Vector3(front.x, 0, front.z).normalized()
	var inv := ch.transform.affine_inverse()
	for lr: String in ["_l", "_r"]:
		var hip: Vector3 = ch.transform * ch.bone_position("thigh" + lr)
		var l1: float = ch.bone_position("thigh" + lr).distance_to(ch.bone_position("calf" + lr))
		var l2: float = ch.bone_position("calf" + lr).distance_to(ch.bone_position("foot" + lr))
		var knee := hip + front * l1 * 0.97 + Vector3(0, -l1 * 0.2, 0)
		var tgt := knee + Vector3(0, -l2 * 0.98, 0) + front * 0.04
		ch.set_ik("leg" + lr, "thigh" + lr, "calf" + lr, "foot" + lr, inv * tgt, inv * (knee + front * 0.3 + Vector3(0, 0.15, 0)))
