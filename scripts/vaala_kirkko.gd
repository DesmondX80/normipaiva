extends RefCounted
## Vaalan kirkko Torintien päässä (tie.json keskusta.kirkko; tools/vaala_kirkkotie.py). Malli on Saloisten kirkko (world.gd _build_kirkko):
## valkoinen puukirkko, jyrkkä tumma harjakatto, korkeat kaarikattoiset ikkunat, kuparinvihreä tornin huippu kultaristeineen ja
## nimikyltti tien puolella. Lisäksi alttarin pääty (kuori), tornin kello, kivetty reitti tielle ja pieni hautausmaa laivan vieressä.
## Paikallinen kehys: +Z = julkisivu (torni ja pääovi, tielle päin), -Z = alttarin pääty, X = laivan leveys (juuri-solmun +X on
## data-akselin ax vastakohta). Rakennuksessa ei ole sisätilaa.

const B := preload("res://scripts/build.gd")

const WALL := Color(0.94, 0.93, 0.88)
const ROOF := Color(0.2, 0.21, 0.24)
const COPPER := Color(0.33, 0.56, 0.5)
const GOLD := Color(0.85, 0.7, 0.25)
const GLASS := Color(0.14, 0.2, 0.3)
const STONE := Color(0.5, 0.5, 0.5)

const WALL_H := 6.4     # laivan seinän korkeus
const TOWER_H := 11.5
const TOWER_W := 5.6    # torni X-suunnassa
const TOWER_D := 5.2    # torni Z-suunnassa


## Rakentaa kirkon ja palauttaa pääoven edustan (maan tasossa).
static func build(v: Node3D, kd: Dictionary) -> Vector3:
	var f := Vector2(kd.face[0], kd.face[1]).normalized()
	var c := Vector2(kd.c[0], kd.c[1])
	var l: float = kd.len
	var w: float = kd.depth
	var yaw := atan2(f.x, f.y)
	var tz := l / 2.0 + 2.0                  # tornin keskipiste (Z)
	var front := tz + TOWER_D / 2.0          # tornin etuseinä (Z)
	var ax := Vector2(-f.y, f.x)
	var base := INF
	for z in [-l / 2.0 - 4.0, front]:
		for x in [-w / 2.0, w / 2.0]:
			var q: Vector2 = c + f * z + ax * x
			base = minf(base, v.h(q.x, q.y))
	base -= 0.05
	var root := Node3D.new()
	root.position = Vector3(c.x, base, c.y)
	root.rotation.y = yaw
	v.add_child(root)
	var body := StaticBody3D.new()
	root.add_child(body)

	# Laiva: kivijalka, valkoiset lautaseinät kulmalaudoin, räystäs ja jyrkkä tumma katto.
	B.mesh(root, B.boxm(Vector3(w + 0.4, 0.7, l + 0.4)), Vector3(0, 0.35, 0), STONE)
	B.mesh(root, B.boxm(Vector3(w, WALL_H - 0.7, l)), Vector3(0, 0.7 + (WALL_H - 0.7) / 2.0, 0), WALL)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.mesh(root, B.boxm(Vector3(0.34, WALL_H - 0.7, 0.34)), Vector3(sx * (w / 2.0 - 0.1), 0.7 + (WALL_H - 0.7) / 2.0, sz * (l / 2.0 - 0.1)), WALL.darkened(0.08))
	B.mesh(root, B.boxm(Vector3(w + 1.8, 0.2, l + 1.8)), Vector3(0, WALL_H + 0.05, 0), WALL.darkened(0.25))
	var prism := PrismMesh.new()
	prism.size = Vector3(w + 1.8, 5.4, l + 1.8)
	B.mesh(root, prism, Vector3(0, WALL_H + 2.7, 0), ROOF)
	body.add_child(B.box_shape(Vector3(w, WALL_H, l), Vector3(0, WALL_H / 2.0, 0)))
	# Korkeat ikkunat pitkillä sivuilla (kuten Saloisten kirkossa: valkoinen karmi, tumma lasi, kaarimainen yläosa).
	for z in [-7.5, -3.5, 0.5, 4.5]:
		_window(root, Vector3(w / 2.0, 0, z), 90.0)
		_window(root, Vector3(-w / 2.0, 0, z), -90.0)
	# Alttarin pääty: matala kuori omalla katollaan ja ikkunalla, laivan päätyharjalla kulta-risti.
	var cz := -l / 2.0 - 1.8
	B.mesh(root, B.boxm(Vector3(7.0, 5.0, 4.6)), Vector3(0, 2.5, cz), WALL)
	B.mesh(root, B.boxm(Vector3(7.4, 0.5, 5.0)), Vector3(0, 0.25, cz), STONE)
	var cprism := PrismMesh.new()
	cprism.size = Vector3(8.0, 2.6, 5.6)
	B.mesh(root, cprism, Vector3(0, 5.0 + 1.3, cz), ROOF)
	B.mesh(root, B.boxm(Vector3(1.3, 2.4, 0.1)), Vector3(0, 2.9, cz - 2.33), Color.WHITE)
	B.mesh(root, B.boxm(Vector3(1.0, 2.1, 0.12)), Vector3(0, 2.9, cz - 2.35), GLASS)
	body.add_child(B.box_shape(Vector3(7.0, 5.0, 4.6), Vector3(0, 2.5, cz)))
	B.mesh(root, B.boxm(Vector3(0.14, 1.4, 0.14)), Vector3(0, WALL_H + 5.4 + 0.5, -l / 2.0 - 0.1), GOLD)
	B.mesh(root, B.boxm(Vector3(0.8, 0.14, 0.14)), Vector3(0, WALL_H + 5.4 + 0.8, -l / 2.0 - 0.1), GOLD)

	# Torni julkisivupäässä: valkoinen runko, äänirei'illä varustettu yläosa, kello, kuparinvihreä huippu, pallo ja risti.
	var th := TOWER_H
	B.mesh(root, B.boxm(Vector3(TOWER_W, th, TOWER_D)), Vector3(0, th / 2.0, tz), WALL)
	body.add_child(B.box_shape(Vector3(TOWER_W, th, TOWER_D), Vector3(0, th / 2.0, tz)))
	B.mesh(root, B.boxm(Vector3(TOWER_W + 0.3, 0.35, TOWER_D + 0.3)), Vector3(0, th, tz), WALL.darkened(0.25))
	for sgn in [-1.0, 1.0]:
		B.mesh(root, B.boxm(Vector3(0.1, 2.6, 1.0)), Vector3(sgn * (TOWER_W / 2.0 + 0.05), th - 2.0, tz), GLASS)
	B.mesh(root, B.boxm(Vector3(1.0, 2.6, 0.1)), Vector3(0, th - 2.0, tz + TOWER_D / 2.0 + 0.05), GLASS)
	B.mesh(root, B.boxm(Vector3(TOWER_W + 0.04, 0.12, TOWER_D + 0.04)), Vector3(0, 4.3, tz), WALL.darkened(0.18))  # vyölauta
	var spire := B.mesh(root, B.cyl(0.0, 3.9, 9.5, 4), Vector3(0, th + 4.75, tz), COPPER, Vector3(0, 45, 0))
	spire.scale = Vector3(1.0, 1.0, 1.0)
	B.mesh(root, B.sphere(0.35, 8), Vector3(0, th + 9.6, tz), GOLD)
	B.mesh(root, B.boxm(Vector3(0.14, 1.8, 0.14)), Vector3(0, th + 10.6, tz), GOLD)
	B.mesh(root, B.boxm(Vector3(0.9, 0.14, 0.14)), Vector3(0, th + 10.9, tz), GOLD)
	# Kello tornin etuseinässä ovan yläpuolella: valkoinen kehä, tumma kehys ja viisarit.
	var cy := 7.8
	var cfz := tz + TOWER_D / 2.0
	B.mesh(root, B.cyl(0.95, 0.95, 0.12, 24), Vector3(0, cy, cfz + 0.06), Color(0.15, 0.15, 0.17), Vector3(90, 0, 0))
	B.mesh(root, B.cyl(0.82, 0.82, 0.14, 24), Vector3(0, cy, cfz + 0.07), Color(0.97, 0.96, 0.92), Vector3(90, 0, 0))
	B.mesh(root, B.boxm(Vector3(0.07, 0.6, 0.05)), Vector3(0.0, cy + 0.26, cfz + 0.16), Color(0.1, 0.1, 0.12))
	B.mesh(root, B.boxm(Vector3(0.5, 0.07, 0.05)), Vector3(0.2, cy - 0.04, cfz + 0.16), Color(0.1, 0.1, 0.12))

	# Pääovi tornin etuseinässä: valkoiset karmit, kaksi ruskeaa ovenlehteä, katos ja portaat.
	B.mesh(root, B.boxm(Vector3(2.8, 3.5, 0.14)), Vector3(0, 1.95, front + 0.02), Color.WHITE)
	B.mesh(root, B.boxm(Vector3(1.2, 3.2, 0.16)), Vector3(-0.62, 1.8, front + 0.04), Color(0.4, 0.22, 0.1))
	B.mesh(root, B.boxm(Vector3(1.2, 3.2, 0.16)), Vector3(0.62, 1.8, front + 0.04), Color(0.4, 0.22, 0.1))
	B.mesh(root, B.boxm(Vector3(3.4, 0.14, 1.2)), Vector3(0, 3.85, front + 0.55), WALL.darkened(0.3))
	B.mesh(root, B.boxm(Vector3(3.4, 0.3, 1.4)), Vector3(0, 0.15, front + 0.7), STONE.lightened(0.1))
	body.add_child(B.box_shape(Vector3(3.4, 0.3, 1.4), Vector3(0, 0.15, front + 0.7)))

	# Nimikyltti tien puolella tolpissa.
	var stand := Node3D.new()
	stand.position = Vector3(6.2, 0, front + 6.0)
	root.add_child(stand)
	for x in [-0.8, 0.8]:
		B.mesh(stand, B.boxm(Vector3(0.08, 1.5, 0.08)), Vector3(x, 0.75, 0), Color(0.3, 0.3, 0.32))
	var plate := B.sign_plate(stand, "VAALAN KIRKKO", Color(0.96, 0.94, 0.88), Color(0.2, 0.15, 0.1), 0.3, 40,
		Color(0.2, 0.15, 0.1), "Helvetica Neue")
	plate.position = Vector3(0, 1.25, 0)

	# Piha: kivetty reitti ovelta tien päähän (maastoon sovitettuna), valaisimet ja kukkapenkit oven eteen.
	var piece := 2.0
	var n := 5
	for k in n:
		var q := _at(c, f, ax, 0.0, front + 1.4 + piece * (k + 0.5))
		var m := B.mesh(v, B.boxm(Vector3(2.6, 0.05, piece + 0.05)), Vector3(q.x, v.h(q.x, q.y) + 0.04, q.y), Color(0.64, 0.62, 0.58),
			Vector3(0, rad_to_deg(yaw), 0))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sx in [-3.0, 3.0]:
		var lq := _at(c, f, ax, sx, front + 3.0)
		var lp := Vector3(lq.x, v.h(lq.x, lq.y), lq.y)
		B.mesh(v, B.cyl(0.05, 0.06, 3.4, 8), lp + Vector3(0, 1.7, 0), Color(0.3, 0.32, 0.34))
		B.mesh(v, B.sphere(0.3, 10), lp + Vector3(0, 3.5, 0), Color.WHITE).material_override = B.unshaded(Color(1.0, 0.97, 0.85))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6208
	for sx in [-1.0, 1.0]:
		for k in 5:
			var bq := _at(c, f, ax, sx * (2.1 + rng.randf_range(0.0, 0.5)), front + 0.6 + k * 0.6)
			var bp := Vector3(bq.x, v.h(bq.x, bq.y), bq.y)
			B.mesh(v, B.sphere(0.45, 8), bp + Vector3(0, 0.35, 0), Color(0.18 + rng.randf() * 0.08, 0.4, 0.17)).scale = Vector3(1.2, 0.8, 1.0)
			if k % 2 == 0:
				B.mesh(v, B.sphere(0.12, 6), bp + Vector3(0, 0.75, 0), Color(0.88, 0.85, 0.9))

	# Hautausmaa laivan itäpuolella (+X): matala valkoinen aita ja hautakivirivit, osassa puuristi.
	_graveyard(v, root, c, f, ax, w, l)
	return Vector3(c.x + f.x * (front + 2.4), v.h(c.x + f.x * (front + 2.4), c.y + f.y * (front + 2.4)), c.y + f.y * (front + 2.4))


## Kirkon paikallinen piste (x sivulle, z julkisivun suuntaan) maailman xz-tasossa.
static func _at(c: Vector2, f: Vector2, ax: Vector2, x: float, z: float) -> Vector2:
	return c + f * z + ax * x


## Korkea ikkuna seinässä: solmun +Z osoittaa ulospäin (yaw 90 = +X-seinä, -90 = -X-seinä, 180 = takaseinä).
static func _window(root: Node3D, at: Vector3, yaw_deg: float) -> void:
	var win := Node3D.new()
	win.position = at
	win.rotation_degrees.y = yaw_deg
	root.add_child(win)
	B.mesh(win, B.boxm(Vector3(1.6, 3.8, 0.1)), Vector3(0, 3.7, 0.03), Color.WHITE)
	B.mesh(win, B.boxm(Vector3(1.25, 3.4, 0.12)), Vector3(0, 3.7, 0.05), GLASS)
	var arch := B.mesh(win, PrismMesh.new(), Vector3(0, 5.7, 0.04), GLASS)
	arch.scale = Vector3(1.25, 0.6, 0.1)
	B.mesh(win, B.boxm(Vector3(0.07, 3.4, 0.14)), Vector3(0, 3.7, 0.06), Color.WHITE)


static func _graveyard(v: Node3D, root: Node3D, c: Vector2, f: Vector2, ax: Vector2, w: float, l: float) -> void:
	var x0 := w / 2.0 + 3.0
	var x1 := x0 + 8.0
	var z0 := -l / 2.0 - 1.0
	var z1 := l / 2.0 - 2.0
	var fence := Color(0.88, 0.87, 0.82)
	# Aita: neljä sivua, aukko laivan puoleisessa reunassa kulkua varten jää avoimeksi (portti etelässä).
	for seg in [[Vector2(x1, z0), Vector2(x1, z1)], [Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x0, z1), Vector2(x1, z1)]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var d := b - a
		var m := (a + b) / 2.0
		var mq := _at(c, f, ax, m.x, m.y)
		var bar := B.mesh(v, B.boxm(Vector3(0.08, 0.08, d.length())), Vector3(mq.x, v.h(mq.x, mq.y) + 0.8, mq.y), fence,
			Vector3(0, rad_to_deg(atan2(f.x * d.y + ax.x * d.x, f.y * d.y + ax.y * d.x)), 0))
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var posts := maxi(2, int(d.length() / 2.5))
		for k in posts + 1:
			var pp := a + d * (float(k) / posts)
			var pq := _at(c, f, ax, pp.x, pp.y)
			B.mesh(v, B.boxm(Vector3(0.1, 1.0, 0.1)), Vector3(pq.x, v.h(pq.x, pq.y) + 0.5, pq.y), fence)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1962
	var rows := 5
	for r in rows:
		var cols := 3
		for k in cols:
			var gx := x0 + 1.8 + r * 1.55
			var gz := z0 + 2.0 + k * 4.4 + rng.randf_range(-0.3, 0.3)
			var gq := _at(c, f, ax, gx, gz)
			var gp := Vector3(gq.x, v.h(gq.x, gq.y), gq.y)
			var rot := Vector3(0, rad_to_deg(atan2(f.x, f.y)), 0)  # kivet katsovat tielle (+Z)
			if (r + k) % 4 == 3:
				B.mesh(v, B.boxm(Vector3(0.1, 1.1, 0.1)), gp + Vector3(0, 0.55, 0), Color(0.4, 0.28, 0.16), rot)
				B.mesh(v, B.boxm(Vector3(0.6, 0.1, 0.1)), gp + Vector3(0, 0.85, 0), Color(0.4, 0.28, 0.16), rot)
			else:
				var gh := 0.7 + rng.randf() * 0.3
				B.mesh(v, B.boxm(Vector3(0.55, gh, 0.14)), gp + Vector3(0, gh / 2.0, 0), Color(0.36, 0.37, 0.4).lightened(rng.randf() * 0.12), rot)
			B.mesh(v, B.boxm(Vector3(0.7, 0.06, 1.7)), gp + Vector3(0, 0.03, 0) - Vector3(f.x, 0, f.y) * 0.9, Color(0.42, 0.38, 0.32), rot)  # kumpu kiven takana
