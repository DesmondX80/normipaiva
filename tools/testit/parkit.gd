extends Node
## Pysäköidyt autot eivät saa olla toistensa sisällä (#bugi Zabukin parkissa): B.parked_car-autojen pohjat (1,8 × 4,2 m,
## lepoasennon suorakaiteet xz-tasossa) tarkistetaan pareittain Saloisissa (main.world),
## Raahessa myös Pentin pakettiauton paikkaa (vaala.gd pentti_spot, 1,8 × 4,7 m) vasten. Päällekkäisyys (SAT, 5 cm
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
	print("PARKIT valmis, %d vikaa" % vikoja)
