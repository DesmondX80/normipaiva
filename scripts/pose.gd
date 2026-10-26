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
