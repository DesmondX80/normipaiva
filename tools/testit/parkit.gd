extends Node
## Pysäköidyt autot eivät saa olla toistensa sisällä (#bugi Zabukin parkissa): B.parked_car-autojen pohjat (1,8 × 4,2 m,
## lepoasennon suorakaiteet xz-tasossa) tarkistetaan pareittain Saloisissa (main.world) ja Vaalassa (mopo_trip.vaala),
## Vaalassa myös Pentin pakettiauton paikkaa (vaala.gd pentti_spot, 1,8 × 4,7 m) vasten. Päällekkäisyys (SAT, 5 cm
## toleranssi) = TESTI VIKA. Kuvat Zabukin parkista. Ajo: tools/testit/aja.sh scene parkit

var main: Node3D
var vikoja := 0


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA parkit: " + t)


## Pysäköityjen autojen pohjat: [keskipiste xz, yaw, puolikoko, nimi] kaikista parked_car-rungoista solmun alta.
func _autot(root: Node, tag: String) -> Array:
	var out: Array = []
	for b in root.find_children("*", "StaticBody3D", true, false):
		for c in b.get_children():
			if c is CollisionShape3D and c.shape is BoxShape3D and (c.shape as BoxShape3D).size.is_equal_approx(Vector3(1.8, 1.4, 4.2)):
				var g: Transform3D = (b as Node3D).global_transform
				var fw: Vector3 = -g.basis.z
				out.append([Vector2(g.origin.x, g.origin.z), atan2(-fw.x, -fw.z), Vector2(0.9, 2.1), "%s auto %s" % [tag, Vector2(g.origin.x, g.origin.z).round()]])
	return out


static func _kulmat(r: Array) -> Array[Vector2]:
	var c: Vector2 = r[0]
	var yaw: float = r[1]
	var hs: Vector2 = r[2]
	var ax := Vector2(cos(yaw), -sin(yaw))  # paikallinen x maailmassa (rotation.y = yaw)
	var az := Vector2(sin(yaw), cos(yaw))   # paikallinen z
	var out: Array[Vector2] = []
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		out.append(c + ax * hs.x * s.x + az * hs.y * s.y)
	return out


## Erotteleva akseli: true, jos suorakaiteet menevät päällekkäin yli tol metriä.
static func _paalla(a: Array, b: Array, tol := 0.05) -> bool:
	var pa := _kulmat(a)
	var pb := _kulmat(b)
	for poly in [pa, pb]:
		for i in 2:
			var e: Vector2 = (poly[i + 1] - poly[i]).normalized()
			var n := Vector2(-e.y, e.x)
			var amin := INF
			var amax := -INF
			var bmin := INF
			var bmax := -INF
			for p in pa:
				amin = minf(amin, p.dot(n))
				amax = maxf(amax, p.dot(n))
			for p in pb:
				bmin = minf(bmin, p.dot(n))
				bmax = maxf(bmax, p.dot(n))
			if amax - tol <= bmin or bmax - tol <= amin:
				return false
	return true


func _tarkista(autot: Array, nimi: String) -> void:
	var n := 0
	for i in autot.size():
		for j in range(i + 1, autot.size()):
			if _paalla(autot[i], autot[j]):
				n += 1
				_vika("%s: %s ja %s päällekkäin" % [nimi, autot[i][3], autot[j][3]])
	print("PARKIT %s: %d pysäköityä autoa, päällekkäin %d paria" % [nimi, autot.size(), n])


func run() -> void:
	for i in 20:
		await get_tree().process_frame
	_tarkista(_autot(main.world, "Saloinen"), "Saloinen")
	main._start_mopo()
	for i in 40:
		await get_tree().process_frame
	var vl: Node3D = main.mopo_trip.vaala
	var autot := _autot(vl, "Vaala")
	if vl.pentti_spot != Vector3.INF:
		var ps: Vector3 = vl.to_global(vl.pentti_spot)
		var g := Transform3D(vl.global_basis * Basis(Vector3.UP, vl.pentti_yaw), ps)
		var fw: Vector3 = -g.basis.z
		autot.append([Vector2(ps.x, ps.z), atan2(-fw.x, -fw.z), Vector2(0.9, 2.35), "Pentin paikka %s" % Vector2(ps.x, ps.z).round()])
	_tarkista(autot, "Vaala")
	# Kuva Zabukin parkista ylhäältä viistosti.
	if vl._zabuki != Vector3.INF:
		var f: Vector2 = vl._zabuki_face
		var c: Vector3 = vl.to_global(vl._zabuki + Vector3(f.x, 0, f.y) * 12.0)
		var cam := Camera3D.new()
		add_child(cam)
		cam.fov = 60.0
		cam.look_at_from_position(c + Vector3(f.x, 0, f.y) * 22.0 + Vector3(0, 18, 0), c)
		cam.make_current()
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "user://parkit_zabuki.png"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shot="):
				path = a.substr(7).replace(".png", "_zabuki.png")
		get_viewport().get_texture().get_image().save_png(path)
		print("PARKIT kuva " + path)
	# Zabuki joka suunnasta perjantai-iltana (Pentin auto parkissa): kuvat _zabuki_<suunta>.
	if vl._zabuki != Vector3.INF:
		while main._weekday() != 4:
			main.day += 1
		main.clock_min = 20 * 60
		var pt: Object = main.rikos_osa("pentti")
		for i in 10:
			if pt != null:
				pt.tick(false)
			await get_tree().process_frame
		var z: Vector3 = vl.to_global(vl._zabuki)
		var f3 := Vector3(vl._zabuki_face.x, 0, vl._zabuki_face.y)
		var s3 := f3.cross(Vector3.UP)
		var cam3 := Camera3D.new()
		add_child(cam3)
		cam3.fov = 62.0
		for v: Array in [["edesta", f3], ["takaa", -f3], ["vasen", s3], ["oikea", -s3]]:
			var dirv: Vector3 = v[1]
			cam3.look_at_from_position(z + dirv * 38.0 + Vector3(0, 16, 0), z + dirv * 8.0)
			cam3.make_current()
			if pt != null:
				pt.tick(false)
			for i in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path3 := "user://parkit_zabuki_%s.png" % v[0]
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--shot="):
					path3 = a.substr(7).replace(".png", "_zabuki_%s.png" % v[0])
			get_viewport().get_texture().get_image().save_png(path3)
			print("PARKIT kuva " + path3)
	print("PARKIT valmis, %d vikaa" % vikoja)
