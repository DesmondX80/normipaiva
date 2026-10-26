## Hahmon asennon ja kalusteen tarkistus testikohtauksiin (CLAUDE.md "Hahmojen asennot ja kalusteet"):
## kuvat edestä, molemmista päädyistä, ylhäältä ja takaa koottuna yhdeksi kuvaksi sekä raajojen rako pintaan.
## Esimerkki: tools/testit/janttu_kuvat.gd.
##   const Asento := preload("res://tools/testit/asento.gd")
##   await Asento.views(cam, out, "uni", keskipiste, koko, etusuunta)
##   Asento.report(hahmo, self, [["upperarm_l", "lowerarm_l", "hand_l"]], ["pelvis", "spine_01", "spine_02", "spine_03"])

const Pose := preload("res://scripts/pose.gd")

const RAJA := 0.035  # luun keskilinjan pienin sallittu rako pintaan (raajan puolipaksuus hihan kanssa)


## Ottaa kuvat edestä, päädyistä, ylhäältä ja takaa ja kokoaa ne 3x2-ruudukoksi <out>/<prefix>_koottu.png
## (yksi kuva katsottavaksi). center = asetelman keskipiste, size = sen pituus metreinä, front = etusuunta
## (vaakataso, esim. Vector3(0, 0, -1) kun -Z on penkin etupuoli).
static func views(cam: Camera3D, out: String, prefix: String, center: Vector3, size: float, front: Vector3) -> void:
	front = Vector3(front.x, 0, front.z).normalized()
	solids_near(cam, center, size)
	var side := front.cross(Vector3.UP).normalized()
	var d := size * 1.6
	var kulmat := [
		["edesta", center + front * d + Vector3(0, size * 0.35, 0)],
		["vino", center + (front + side * 0.8).normalized() * d + Vector3(0, size * 0.5, 0)],
		["paaty_a", center + side * d + Vector3(0, size * 0.15, 0)],
		["paaty_b", center - side * d + Vector3(0, size * 0.15, 0)],
		["ylhaalta", center + Vector3(0, d * 1.2, 0) + front * 0.01],
		["takaa", center - front * d + Vector3(0, size * 0.45, 0)],
	]
	var imgs := []
	for k in kulmat:
		cam.look_at_from_position(k[1], center, Vector3.UP if k[0] != "ylhaalta" else -front)
		for i in 3:
			await cam.get_tree().process_frame
		await RenderingServer.frame_post_draw
		imgs.append(cam.get_viewport().get_texture().get_image())
	var w: int = imgs[0].get_width() / 2
	var h: int = imgs[0].get_height() / 2
	var sheet := Image.create(w * 3, h * 2, false, imgs[0].get_format())
	for i in imgs.size():
		var im: Image = imgs[i]
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
	sheet.save_png(out.path_join(prefix + "_koottu.png"))
	print("kuva ", prefix, "_koottu (", ", ".join(kulmat.map(func(k): return k[0])), ")")


## Tulostaa ketjujen (esim. olkavarsi -> kyynärvarsi -> käsi) raon pintaan, jonka muodostavat surface-luiden
## verkko (esim. vartalo). Rako alle RAJA = "LÄPI"; ensimmäisen luun alkupuolta ei lasketa (nivelen juuri).
## Palauttaa läpimenojen määrän (0 = kunnossa).
## Ilman näyttöä verkkoa ei paisteta, joten aja ikkunallisena.
static func report(ch: Node3D, space: Node3D, chains: Array, surface: Array) -> int:
	var pts := Pose.limb_points(ch, space, surface)
	if pts.is_empty():
		print("RAKO: ei pintaa (headless?), ei tarkistettu")
		return 0
	var bad := 0
	for chain in chains:
		var rows := Pose.clearance(ch, space, chain, pts)
		var low := INF
		for r in rows:
			if r[0] == chain[0] and r[1] < 0.5:
				continue  # nivelen juuri (olkapää, lonkka) on luonnostaan vartalon sisällä
			low = minf(low, r[2])
			if r[2] < RAJA:
				bad += 1
				print("RAKO LÄPI %s t=%.2f rako=%.3f m" % [r[0], r[1], r[2]])
		print("RAKO %s: pienin %.3f m (%d pistettä pinnan kohdalla)" % [chain[-1], low, rows.size()])
	return bad


## Istuvan hahmon tarkistus: lantion rako istuimeen (seat_y, K8: -0,03...0,03), jalkaterien korkeus lattiasta
## (floor_y, K5), jalkojen risteys, polvet edessä ja kasvojen suunta (K6). front = kalusteen etusuunta (vaakataso).
## space = solmu, jonka avaruudessa seat_y/floor_y ovat. Palauttaa virheiden määrän.
static func seat_report(ch: Node3D, space: Node3D, seat_y: float, floor_y: float, front: Vector3, cross_ok := false) -> int:
	front = Vector3(front.x, 0, front.z).normalized()
	var bad := 0
	var bp := func(b: String) -> Vector3: return space.to_local(ch.to_global(ch.bone_position(b)))
	var pel: Vector3 = bp.call("pelvis")
	var pts := Pose.limb_points(ch, space, ["pelvis", "thigh_l", "thigh_r"])
	var low := INF
	for q in pts:
		if Vector2(q.x - pel.x, q.z - pel.z).length() < 0.15:
			low = minf(low, q.y)
	if low == INF:
		low = pel.y - Pose.HIP_OVER_SEAT  # ei pintaa (headless): arvio luusta
	var gap := low - seat_y
	var ok := gap >= -0.03 and gap <= 0.03
	print("ASENTO lantion rako istuimeen %.3f m %s" % [gap, "OK" if ok else "VIRHE"])
	bad += 0 if ok else 1
	var side := front.cross(Vector3.UP).normalized()
	for lr in ["_l", "_r"]:
		var ft: Vector3 = bp.call("foot" + lr)
		print("ASENTO foot%s korkeus lattiasta %.3f m (nilkkaluu)" % [lr, ft.y - floor_y])
	var cross: float = ((bp.call("foot_l") - bp.call("foot_r")) as Vector3).dot(side) * ((bp.call("thigh_l") - bp.call("thigh_r")) as Vector3).dot(side)
	if cross_ok:
		print("ASENTO jalat: nilkat saa olla ristissä (%s)" % ("ristissä" if cross <= 0.0 else "eivät ristissä"))
		for lr in ["_l", "_r"]:  # polvet pysyvät oman lonkan puolella
			var kn: float = ((bp.call("calf" + lr) as Vector3) - pel).dot(side) * ((bp.call("thigh" + lr) as Vector3) - pel).dot(side)
			print("ASENTO polvi%s oman lonkan puolella %s" % [lr, "OK" if kn > 0.0 else "VIRHE"])
			bad += 0 if kn > 0.0 else 1
	else:
		print("ASENTO jalat %s" % ("ei ristissä" if cross > 0.0 else "RISTISSÄ"))
		bad += 0 if cross > 0.0 else 1
	for lr in ["_l", "_r"]:
		var d: float = ((bp.call("calf" + lr) - bp.call("thigh" + lr)) as Vector3).dot(front)
		print("ASENTO polvi%s lonkan edessä %.3f m %s" % [lr, d, "OK" if d > 0.0 else "VIRHE"])
		bad += 0 if d > 0.0 else 1
	var face: float = (-ch.global_transform.basis.z).dot(front)
	print("ASENTO kasvot vs etu: %.3f %s" % [face, "OK" if face > 0.9 else "VIRHE"])
	bad += 0 if face > 0.9 else 1
	return bad


## Kalusteen kallistuvien osien (tolpat, laudat) Y-akselit ovat yhdensuuntaiset (K7). Palauttaa virheiden määrän.
static func bench_report(parts: Array) -> int:
	var bad := 0
	for i in range(1, parts.size()):
		var d: float = (parts[0] as Node3D).global_transform.basis.y.normalized().dot((parts[i] as Node3D).global_transform.basis.y.normalized())
		if d < 0.999:
			bad += 1
			print("ASENTO kaluste: osa %s ei ole yhdensuuntainen (%.4f)" % [(parts[i] as Node3D).name, d])
	print("ASENTO kaluste: %d osaa, %d virhettä" % [parts.size(), bad])
	return bad


## Selän rako selkänojaan (K8): ylä- ja keskiselän takapinnan pienin etäisyys tasosta (back_pt, back_n = normaali
## istujaa kohti, space-avaruus). OK, kun -0,03...0,03. Palauttaa virheiden määrän.
static func back_report(ch: Node3D, space: Node3D, back_pt: Vector3, back_n: Vector3) -> int:
	var n := back_n.normalized()
	var pts := Pose.limb_points(ch, space, ["spine_02", "spine_03"])
	if pts.is_empty():
		print("ASENTO selkä: ei pintaa (headless?), ei tarkistettu")
		return 0
	var low := INF
	for q in pts:
		low = minf(low, (q - back_pt).dot(n))
	var ok := low >= -0.03 and low <= 0.03
	print("ASENTO selän rako selkänojaan %.3f m %s" % [low, "OK" if ok else "VIRHE"])
	return 0 if ok else 1


const SOLID_MIN_PTS := 8  # läpimenoksi kutsutaan, kun kappaleen sisällä on vähintään näin monta pistettä
const SOLID_DEPTH := 0.01  # pistettä pidetään sisällä, kun se on näin syvällä pinnan alla
const SOLID_TOP := 0.03  # ylöspäin osoittavalle pinnalle (istuin, pöytä, maa) 2 cm:n sietoraja lisäksi


## Kaikki hahmot (solmu, jolla on bone_position ja skeleton) puun alla.
static func _chars(n: Node, out: Array) -> void:
	if n is Node3D and n.has_method("bone_position") and n.get("skeleton") != null:
		out.append(n)
	for c in n.get_children():
		_chars(c, out)


static func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)


## Pisteen syvyys primitiivin sisällä paikallisessa avaruudessa (<= 0: ulkona). upl = ylös paikallisessa avaruudessa, tol = ylöspäin osoittavan pinnan sietoraja.
static func _depth_local(m: Mesh, p: Vector3, upl: Vector3, tol: float) -> float:
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


## Hahmon (ch) läpimenotarkistus: paistaa koko verkon, etsii radius-säteeltä kiinteät kappaleet (kalusteet, muiden
## hahmojen paistetut pinnat, maa ja lattia) ja ilmoittaa jokaisen, jonka sisällä on vähintään SOLID_MIN_PTS pistettä
## (SOLID_DEPTH sisempänä pintaa; ylöspäin osoittava pinta +SOLID_TOP). Hahmon omat lapset (pipo, kassi) ohitetaan.
## Palauttaa läpimenevien kappaleiden määrän. Ilman näyttöä (headless) ei paisteta eikä tarkisteta.
static func solids(ch: Node3D, space: Node3D, radius := 2.0) -> int:
	var skel: Skeleton3D = ch.skeleton
	var bones := []
	for i in skel.get_bone_count():
		bones.append(skel.get_bone_name(i))
	var pts := Pose.limb_points(ch, space, bones)
	if pts.is_empty():
		print("LÄPI ", ch.name, ": ei pintaa (headless?), ei tarkistettu")
		return 0
	var gp := PackedVector3Array()
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for q in pts:
		var g := space.to_global(q)
		gp.append(g)
		lo = lo.min(g)
		hi = hi.max(g)
	var box := AABB(lo, hi - lo).grow(radius)
	var root := ch.get_tree().current_scene
	var all := []
	_meshes(root, all)
	var found := 0
	var tested := 0
	for mi: MeshInstance3D in all:
		if ch.is_ancestor_of(mi) or mi.has_meta("pehmea"):
			continue  # oma kiinnitys (pipo, kassi), oma iho ja pehmeät kappaleet (meta "pehmea": tyyny, kassi)
		var m: Mesh = mi.mesh
		var xf: Transform3D = mi.global_transform
		var tri: TriangleMesh = null
		var lbox := xf * m.get_aabb()
		if mi.skin != null:
			continue  # hahmojen iho käsitellään erikseen (_chars_touch)
		if not lbox.intersects(box):
			continue
		var prim := m is BoxMesh or m is CylinderMesh or m is SphereMesh or m is CapsuleMesh
		if not prim:
			if m is PlaneMesh or m is QuadMesh:
				continue
			tri = m.generate_triangle_mesh()
			if tri == null:
				continue
		tested += 1
		var inv := xf.affine_inverse()
		var scl := xf.basis.get_scale().abs().min_axis_index()
		var k: float = xf.basis.get_scale().abs()[scl]
		var upl := (inv.basis * Vector3.UP).normalized()
		var n := 0
		var deepest := 0.0
		for g in gp:
			if not lbox.has_point(g):
				continue
			var lp := inv * g
			var dep := 0.0
			if prim:
				dep = _depth_local(m, lp, upl, SOLID_TOP / k) * k
			else:
				var hits := 0
				var dir := Vector3.UP
				var o := lp
				var first := INF
				var first_up := false
				for _i in 8:
					var h := tri.intersect_ray(o, inv.basis * dir)
					if h.is_empty():
						break
					hits += 1
					var dist: float = (h["position"] - o).length() if hits > 1 else (h["position"] - lp).length()
					if hits == 1:
						first = dist * k
						first_up = (xf.basis * (h["normal"] as Vector3)).normalized().y > 0.7
					o = h["position"] + inv.basis * dir * 0.0005
				if hits % 2 == 1:
					dep = first - (SOLID_TOP if first_up else 0.0)
			if dep > SOLID_DEPTH:
				n += 1
				deepest = maxf(deepest, dep + (SOLID_TOP if prim and _depth_local(m, lp, upl, 0.0) * k > dep + 0.001 else 0.0))
		if n >= SOLID_MIN_PTS:
			found += 1
			print("LÄPI %s %s -> %s [%s %s] pisteitä %d syvin %.3f m" % [ch.name, ch.global_position.snapped(Vector3.ONE * 0.01), str(root.get_path_to(mi)), m.get_class(), lbox, n, deepest])
	found += _chars_touch(ch, space, gp, bones, root)
	print("LÄPI %s: %d kappaletta tarkistettu, %d läpimenoa" % [ch.name, tested, found])
	return found


## Tarkistaa kaikki hahmot, jotka ovat center-pisteen lähellä (size/2 + 0.5 m). Kutsutaan views-kuvauksen yhteydessä.
static func solids_near(cam: Camera3D, center: Vector3, size: float, radius := 2.0) -> int:
	var root := cam.get_tree().current_scene
	var list := []
	_chars(root, list)
	var bad := 0
	for c: Node3D in list:
		if not c.is_visible_in_tree() or c.global_position.distance_to(center) > size * 0.5 + 0.5:
			continue
		var space: Node3D = root if root is Node3D else c.get_parent() as Node3D
		bad += solids(c, space, radius)
	return bad


## Hahmo toisen hahmon pinnan läpi/kiinni: A:n pisteet (ei kädet ja sormet, jotka saavat koskettaa) alle 5 mm päässä B:n
## paistetuista pisteistä. Paistettu verkko ei ole umpinainen, joten mitataan etäisyyttä, ei sisäpuolisuutta.
static func _chars_touch(ch: Node3D, space: Node3D, gp: PackedVector3Array, bones: Array, root: Node) -> int:
	var others := []
	_chars(root, others)
	var found := 0
	var mine := []
	for b: String in bones:
		if not (b.contains("hand") or b.contains("thumb") or b.contains("index") or b.contains("middle") or b.contains("ring") or b.contains("pinky")):
			mine.append(b)
	var mp := Pose.limb_points(ch, space, mine)
	for o: Node3D in others:
		if o == ch or not o.is_visible_in_tree() or o.global_position.distance_to(ch.global_position) > 3.0:
			continue
		var ob := []
		for i in (o.get("skeleton") as Skeleton3D).get_bone_count():
			ob.append((o.get("skeleton") as Skeleton3D).get_bone_name(i))
		var cell := {}
		for q in Pose.limb_points(o, space, ob):
			cell[Vector3i((q / 0.01).floor())] = q
		var n := 0
		var near := INF
		for q in mp:
			var c := Vector3i((q / 0.01).floor())
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for dz in range(-1, 2):
						var key := c + Vector3i(dx, dy, dz)
						if cell.has(key):
							var d: float = (cell[key] as Vector3).distance_to(q)
							if d < 0.005:
								near = minf(near, d)
								n += 1
		if n >= SOLID_MIN_PTS:
			found += 1
			print("LÄPI %s -> %s (hahmo) pisteitä %d lähin %.3f m" % [ch.name, o.name, n, near])
	return found
