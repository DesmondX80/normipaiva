extends RefCounted
## Suomalainen puinen rautatieasema (Saloinen ja Vaala, world.gd ja vaala.gd): keltainen pystylautaverhous
## valkoisine vyö- ja nurkkalistoineen, ristikkoikkunat valkoisin puittein, punainen saumattu peltikatto, tiiliset
## piiput ja kolme kolmiokattolyhtyä kadun puoleisella lappeella. Kadun puolella sisäänkäyntikatos portaineen ja
## pariovi, päädyssä pieni lippa, laiturin puolella pitkä katos pilareineen, ovi laiturille, kello ja penkki.
## Paikallinen kehys: -Z laiturin puoli, +Z kadun puoli, X radan suuntaan, y = 0 maan tasossa (sokkelin keskikohta).

const B := preload("res://scripts/build.gd")

const OCHRE := Color(0.88, 0.7, 0.32)
const OCHRE_DARK := Color(0.78, 0.6, 0.26)
const WHITE := Color(0.95, 0.94, 0.9)
const ROOF := Color(0.72, 0.27, 0.22)  # punainen peltikatto (haalistunut)
const ROOF_SEAM := Color(0.6, 0.2, 0.16)
const BRICK := Color(0.62, 0.22, 0.14)
const GLASS := Color(0.12, 0.16, 0.2)
const DOOR := Color(0.5, 0.28, 0.14)
const STONE := Color(0.55, 0.54, 0.5)


## Laatikot yhdistettyinä yhdeksi meshiksi väreittäin (satoja lautoja ja listoja ilman satoja solmuja).
class Batch:
	var _st := {}  # väri -> SurfaceTool

	func add(size: Vector3, pos: Vector3, color: Color, basis := Basis()) -> void:
		var key := color.to_html()
		if not _st.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_st[key] = [st, color]
		(_st[key][0] as SurfaceTool).append_from(B.boxm(size), 0, Transform3D(basis, pos))

	func commit(parent: Node3D) -> void:
		for key in _st:
			var mi := MeshInstance3D.new()
			mi.mesh = (_st[key][0] as SurfaceTool).commit()
			mi.material_override = B.mat(_st[key][1])
			parent.add_child(mi)


## Rakentaa aseman rootin alle. door_x: kadun puoleisen oven kohta, plat_door_x: laiturin puoleisen.
## Palauttaa {"street_door", "plat_door"} paikallisina (oven edusta maan tasossa).
static func build(root: Node3D, L: float, D: float, wall_h: float, town: String, door_x: float, plat_door_x: float) -> Dictionary:
	var bt := Batch.new()
	var y0 := 0.25  # sokkelin yläpinta
	var top := y0 + wall_h
	bt.add(Vector3(L + 0.4, 0.5, D + 0.4), Vector3.ZERO, STONE)
	bt.add(Vector3(L, wall_h, D), Vector3(0, y0 + wall_h / 2.0, 0), OCHRE)
	var body := StaticBody3D.new()
	root.add_child(body)
	body.add_child(B.box_shape(Vector3(L, wall_h, D), Vector3(0, y0 + wall_h / 2.0, 0)))
	# Pystylaudoitus: rimat 0,5 m välein pitkillä sivuilla ja päädyissä, vyölista ja alalauta valkoisina.
	var n_l := int(L / 0.5)
	for sz: float in [-1.0, 1.0]:
		for k in n_l:
			var x := -L / 2.0 + 0.25 + k * L / n_l
			bt.add(Vector3(0.05, wall_h - 0.1, 0.03), Vector3(x, y0 + wall_h / 2.0, sz * (D / 2.0 + 0.015)), OCHRE_DARK)
		bt.add(Vector3(L + 0.02, 0.12, 0.05), Vector3(0, y0 + 1.05, sz * (D / 2.0 + 0.03)), WHITE)
		bt.add(Vector3(L + 0.02, 0.18, 0.05), Vector3(0, y0 + 0.09, sz * (D / 2.0 + 0.03)), WHITE)
	var n_d := int(D / 0.5)
	for sx: float in [-1.0, 1.0]:
		for k in n_d:
			var z := -D / 2.0 + 0.25 + k * D / n_d
			bt.add(Vector3(0.03, wall_h - 0.1, 0.05), Vector3(sx * (L / 2.0 + 0.015), y0 + wall_h / 2.0, z), OCHRE_DARK)
		bt.add(Vector3(0.05, 0.12, D + 0.02), Vector3(sx * (L / 2.0 + 0.03), y0 + 1.05, 0), WHITE)
		bt.add(Vector3(0.05, 0.18, D + 0.02), Vector3(sx * (L / 2.0 + 0.03), y0 + 0.09, 0), WHITE)
	for cx: float in [-L / 2.0, L / 2.0]:
		for cz: float in [-D / 2.0, D / 2.0]:
			bt.add(Vector3(0.24, wall_h, 0.24), Vector3(cx, y0 + wall_h / 2.0, cz), WHITE)
	bt.add(Vector3(L + 0.14, 0.3, D + 0.14), Vector3(0, top - 0.1, 0), WHITE)  # räystäslista
	# Ikkunat pitkille sivuille tasavälein; ovien kohdalta pois.
	var n_win := maxi(int(L / 2.3), 3)
	for sz: float in [-1.0, 1.0]:
		var dx := door_x if sz > 0.0 else plat_door_x
		for k in n_win:
			var wx := -L / 2.0 + L / n_win * (k + 0.5)
			if absf(wx - dx) < 1.3:
				continue
			_window(bt, Vector3(wx, y0 + 1.95, sz * (D / 2.0 + 0.04)), sz, false)
	for sx: float in [-1.0, 1.0]:
		_window(bt, Vector3(sx * (L / 2.0 + 0.04), y0 + 1.95, -D / 4.0), sx, true)
	# Ovet: kadulle pariovi lasiruutuineen ja yläikkuna, laiturille sama; päädyssä (+X) palveluovi.
	for sz: float in [-1.0, 1.0]:
		var dx := door_x if sz > 0.0 else plat_door_x
		var zf := sz * (D / 2.0 + 0.05)
		bt.add(Vector3(1.7, 2.85, 0.08), Vector3(dx, y0 + 1.42, zf), WHITE)
		for e: float in [-0.36, 0.36]:
			bt.add(Vector3(0.66, 2.2, 0.06), Vector3(dx + e, y0 + 1.1, zf + sz * 0.03), DOOR)
			bt.add(Vector3(0.42, 0.9, 0.05), Vector3(dx + e, y0 + 1.55, zf + sz * 0.05), GLASS)
			bt.add(Vector3(0.05, 0.08, 0.06), Vector3(dx + e - sign(e) * 0.24, y0 + 1.05, zf + sz * 0.07), Color(0.8, 0.7, 0.3))
		bt.add(Vector3(1.4, 0.4, 0.05), Vector3(dx, y0 + 2.5, zf + sz * 0.03), GLASS)
		bt.add(Vector3(0.05, 0.4, 0.06), Vector3(dx, y0 + 2.5, zf + sz * 0.04), WHITE)
	bt.add(Vector3(0.08, 2.3, 1.1), Vector3(L / 2.0 + 0.05, y0 + 1.15, D / 4.0), DOOR)
	bt.add(Vector3(0.1, 2.45, 1.3), Vector3(L / 2.0 + 0.03, y0 + 1.2, D / 4.0), WHITE)
	# Sisäänkäyntikatos kadun puolella: kolme betoniporrasta, valkoiset pilarit ja pieni harjakatto.
	var pz := D / 2.0
	for s in 3:
		bt.add(Vector3(2.6 - s * 0.2, 0.17, 1.6 - s * 0.35), Vector3(door_x, 0.08 + s * 0.17 - 0.17, pz + 0.8 - s * 0.17), STONE)
	for px: float in [-1.15, 1.15]:
		bt.add(Vector3(0.14, 2.75, 0.14), Vector3(door_x + px, y0 + 1.37, pz + 1.45), WHITE)
		bt.add(Vector3(0.08, 0.08, 1.45), Vector3(door_x + px, y0 + 2.75, pz + 0.72), WHITE)
	var p_pitch := 0.6
	for sx: float in [-1.0, 1.0]:
		var pr := Node3D.new()
		pr.position = Vector3(door_x + sx * 0.7, y0 + 3.0, pz + 0.8)
		pr.rotation.z = -sx * p_pitch
		root.add_child(pr)
		var pb := Batch.new()
		pb.add(Vector3(1.75, 0.08, 2.0), Vector3.ZERO, ROOF)
		for k in 4:
			pb.add(Vector3(1.75, 0.04, 0.04), Vector3(0, 0.05, -0.85 + k * 0.57), ROOF_SEAM)
		pb.commit(pr)
	_gable(root, Vector3(door_x, y0 + 2.8, pz + 1.78), 2.5, 0.85, WHITE, Basis())
	# Päädyn pieni lippa ovea suojaamaan.
	var lip := Node3D.new()
	lip.position = Vector3(L / 2.0 + 0.6, y0 + 2.7, D / 4.0)
	lip.rotation.z = -0.3
	root.add_child(lip)
	var lb := Batch.new()
	lb.add(Vector3(1.3, 0.07, 1.8), Vector3.ZERO, ROOF)
	lb.commit(lip)
	# Harjakatto: lappeet saumoineen, harjapelti, valkoiset tuulilaudat ja päätykolmiot.
	var pitch := 0.5
	var span := D / 2.0 + 0.8
	var ridge := top + span * tan(pitch) + 0.1
	for sz: float in [-1.0, 1.0]:
		var lappe := Node3D.new()
		lappe.position = Vector3(0, ridge - span * tan(pitch) / 2.0, sz * span / 2.0)
		lappe.rotation.x = sz * pitch
		root.add_child(lappe)
		var rb := Batch.new()
		var slope := span / cos(pitch)
		rb.add(Vector3(L + 1.2, 0.12, slope), Vector3.ZERO, ROOF)
		var seams := int((L + 1.2) / 0.55)
		for k in seams + 1:
			rb.add(Vector3(0.035, 0.05, slope), Vector3(-(L + 1.2) / 2.0 + k * (L + 1.2) / seams, 0.08, 0), ROOF_SEAM)
		rb.add(Vector3(L + 1.25, 0.1, 0.08), Vector3(0, -0.02, sz * slope / 2.0), ROOF_SEAM)  # räystään otsapelti
		for ex: float in [-1.0, 1.0]:
			rb.add(Vector3(0.08, 0.26, slope + 0.05), Vector3(ex * (L / 2.0 + 0.62), -0.05, 0), WHITE)
		rb.commit(lappe)
	bt.add(Vector3(L + 1.25, 0.16, 0.36), Vector3(0, ridge + 0.04, 0), ROOF_SEAM)
	for gx: float in [-L / 2.0, L / 2.0]:
		var tri := SurfaceTool.new()
		tri.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3(gx, top, -D / 2.0), Vector3(gx, top, D / 2.0), Vector3(gx, top + (D / 2.0) * tan(pitch), 0)]:
			tri.add_vertex(v)
		tri.generate_normals()
		var tm := MeshInstance3D.new()
		tm.mesh = tri.commit()
		var gm := B.mat(OCHRE).duplicate() as StandardMaterial3D
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		tm.material_override = gm
		root.add_child(tm)
		# Päätykolmion pieni ullakkoikkuna.
		var sx := signf(gx)
		bt.add(Vector3(0.05, 0.75, 0.6), Vector3(gx + sx * 0.03, top + 0.75, 0), WHITE)
		bt.add(Vector3(0.05, 0.6, 0.46), Vector3(gx + sx * 0.05, top + 0.75, 0), GLASS)
	# Piiput: kolme tiilipiippua harjan tuntumassa, pellitetty hattu.
	for cx: float in [-L * 0.32, 0.0, L * 0.32]:
		var ch := ridge + 0.75
		var base := ridge - 0.9
		bt.add(Vector3(0.62, ch - base, 0.62), Vector3(cx + 0.4, (ch + base) / 2.0, 0.55), BRICK)
		bt.add(Vector3(0.72, 0.1, 0.72), Vector3(cx + 0.4, ch, 0.55), Color(0.3, 0.3, 0.3))
		for k in 3:
			bt.add(Vector3(0.64, 0.02, 0.64), Vector3(cx + 0.4, base + 0.6 + k * 0.35, 0.55), BRICK.darkened(0.25))
	# Kolme kolmiokattolyhtyä kadun puoleisella lappeella.
	var s_at := span * 0.42
	var dy := ridge - 0.1 - s_at * tan(pitch)
	for k in 3:
		var lx := L * 0.12 + k * 1.15
		_gable(root, Vector3(lx, dy - 0.05, s_at + 0.05), 0.8, 0.5, WHITE, Basis())
		_gable(root, Vector3(lx, dy + 0.02, s_at + 0.08), 0.5, 0.3, GLASS, Basis())
		for sx: float in [-1.0, 1.0]:
			var dr := Node3D.new()
			dr.position = Vector3(lx + sx * 0.22, dy + 0.2, s_at - 0.15)
			dr.rotation.z = -sx * 0.9
			root.add_child(dr)
			var db := Batch.new()
			db.add(Vector3(0.55, 0.05, 0.5), Vector3.ZERO, ROOF)
			db.commit(dr)
	# Laiturikatos: loiva lippa seinästä pilareille, alla kello ja penkki.
	var cb := Batch.new()
	var canopy := Node3D.new()
	canopy.position = Vector3(0, top - 0.25, -D / 2.0 - 2.2)
	canopy.rotation.x = -0.08
	root.add_child(canopy)
	cb.add(Vector3(L + 0.4, 0.12, 4.4), Vector3.ZERO, ROOF)
	for k in int((L + 0.4) / 0.55) + 1:
		cb.add(Vector3(0.035, 0.05, 4.4), Vector3(-(L + 0.4) / 2.0 + k * 0.55, 0.07, 0), ROOF_SEAM)
	cb.add(Vector3(L + 0.4, 0.2, 0.06), Vector3(0, -0.12, -2.2), WHITE)
	cb.commit(canopy)
	for k in 5:
		var px := -L / 2.0 + 1.0 + k * (L - 2.0) / 4.0
		bt.add(Vector3(0.16, wall_h - 0.4, 0.16), Vector3(px, y0 + (wall_h - 0.4) / 2.0, -D / 2.0 - 3.6), WHITE)
		bt.add(Vector3(0.06, 0.6, 0.6), Vector3(px, top - 0.75, -D / 2.0 - 3.3), WHITE, Basis(Vector3.RIGHT, PI / 4.0))
	var clock_x := plat_door_x + 2.4 if plat_door_x < L / 2.0 - 3.0 else plat_door_x - 2.4
	var clock := B.mesh(root, B.cyl(0.3, 0.3, 0.06, 20), Vector3(clock_x, y0 + 3.15, -D / 2.0 - 0.06), WHITE, Vector3(90, 0, 0))
	clock.material_override = B.unshaded(Color(0.97, 0.97, 0.94))
	bt.add(Vector3(0.03, 0.22, 0.02), Vector3(clock_x, y0 + 3.23, -D / 2.0 - 0.1), Color(0.05, 0.05, 0.05))
	bt.add(Vector3(0.16, 0.03, 0.02), Vector3(clock_x + 0.07, y0 + 3.15, -D / 2.0 - 0.1), Color(0.05, 0.05, 0.05))
	var bx := plat_door_x - 2.6 if plat_door_x > -L / 2.0 + 3.5 else plat_door_x + 2.6
	bt.add(Vector3(1.8, 0.06, 0.42), Vector3(bx, y0 + 0.45, -D / 2.0 - 0.4), DOOR)
	bt.add(Vector3(1.8, 0.4, 0.05), Vector3(bx, y0 + 0.7, -D / 2.0 - 0.15), DOOR)
	for e: float in [-0.8, 0.8]:
		bt.add(Vector3(0.06, 0.45, 0.4), Vector3(bx + e, y0 + 0.22, -D / 2.0 - 0.38), Color(0.2, 0.2, 0.22))
	# Seinävalaisimet ovien vierelle.
	for e: float in [-1.15, 1.15]:  # kadun puolella valo on katoksessa
		var lamp := B.mesh(root, B.boxm(Vector3(0.18, 0.26, 0.16)), Vector3(plat_door_x + e, y0 + 2.45, -D / 2.0 - 0.12), Color(1.0, 0.92, 0.7))
		lamp.material_override = B.unshaded(Color(1.0, 0.92, 0.7))
	var porch_lamp := B.mesh(root, B.sphere(0.12, 10), Vector3(door_x, y0 + 2.8, pz + 0.9), Color(1.0, 0.92, 0.7))
	porch_lamp.material_override = B.unshaded(Color(1.0, 0.92, 0.7))
	# Nimikyltit: laiturin puolella katoksen alla, kadun puolella oven vieressä.
	var name := town.to_upper()
	var sign_x := 0.0 if absf(door_x) > 2.6 else L * 0.3
	var sp := B.sign_plate(root, name, Color(0.97, 0.97, 0.97), Color(0.08, 0.08, 0.1), 0.6, 80, Color(0.1, 0.25, 0.55), "Helvetica Neue")
	sp.position = Vector3(sign_x, top - 0.55, D / 2.0 + 0.1)
	var sp2 := B.sign_plate(root, name, Color(0.97, 0.97, 0.97), Color(0.08, 0.08, 0.1), 0.6, 80, Color(0.1, 0.25, 0.55), "Helvetica Neue")
	sp2.position = Vector3(0, top - 0.85, -D / 2.0 - 3.75)
	sp2.rotation.y = PI
	bt.commit(root)
	return {"street_door": Vector3(door_x, 0, D / 2.0 + 2.2), "plat_door": Vector3(plat_door_x, 0, -D / 2.0 - 1.4)}


## Ristikkoikkuna: valkoinen karmi, tumma lasi, pystypuite ja kaksi vaakapuitetta (6 ruutua), ikkunalauta.
## side: kumpaan suuntaan seinästä (±Z tai päädyissä ±X, endwall = true).
static func _window(bt: Batch, at: Vector3, side: float, endwall: bool) -> void:
	var w := 1.05
	var h := 1.6
	var t := Vector3(0.06, h + 0.16, w + 0.16) if endwall else Vector3(w + 0.16, h + 0.16, 0.06)
	var o := Vector3(side * 0.01, 0, 0) if endwall else Vector3(0, 0, side * 0.01)
	bt.add(t, at, WHITE)
	bt.add(Vector3(0.05, h, w) if endwall else Vector3(w, h, 0.05), at + o, GLASS)
	bt.add(Vector3(0.06, h, 0.06) if endwall else Vector3(0.06, h, 0.06), at + o * 2.0, WHITE)
	for fy: float in [-h / 6.0, h / 6.0]:
		bt.add(Vector3(0.06, 0.05, w) if endwall else Vector3(w, 0.05, 0.06), at + o * 2.0 + Vector3(0, fy, 0), WHITE)
	var sill_o := Vector3(side * 0.08, 0, 0) if endwall else Vector3(0, 0, side * 0.08)
	bt.add(Vector3(0.16, 0.06, w + 0.3) if endwall else Vector3(w + 0.3, 0.06, 0.16), at + sill_o - Vector3(0, h / 2.0 + 0.1, 0), WHITE)


## Kolmio (päätykolmio tai kattolyhdyn otsa) +Z:aan päin: leveys w, korkeus h, alareuna at:ssa.
static func _gable(root: Node3D, at: Vector3, w: float, h: float, col: Color, basis: Basis) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-w / 2.0, 0, 0), Vector3(w / 2.0, 0, 0), Vector3(0, h, 0)]:
		st.add_vertex(basis * v + at)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := B.mat(col).duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	root.add_child(mi)


## Rahakätkön paikka radan varressa 100–220 m asemalta (ok: kelpaako kohta, esim. kuiva maa eikä talon vieressä).
static func pick_cache(train: Node3D, station_t: float, ok: Callable) -> Vector3:
	for off: float in [150.0, -150.0, 190.0, -190.0, 120.0, -120.0, 220.0, -220.0]:
		var t := station_t + off
		if t < 5.0 or t > train.length() - 5.0:
			continue
		var p: Vector3 = train.point_t(t)
		var side: Vector3 = train.dir_t(t).cross(Vector3.UP)
		for s: float in [1.0, -1.0]:
			var q := p + side * s * 5.5
			if ok.call(q):
				return q
	return Vector3.INF


## Rahakätkö: vanhojen ratapölkkyjen pino radan vieressä (heinikon yläpuolelle), alla pilkottaa muovikassi.
static func cache_prop(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.rotation.y = yaw
	parent.add_child(n)
	var bt := Batch.new()
	var tie := Color(0.24, 0.17, 0.12)
	for layer in 5:
		for k in 6 - layer:
			var x := (k - (5 - layer) / 2.0) * 0.26
			bt.add(Vector3(0.24, 0.18, 2.6), Vector3(x, 0.09 + layer * 0.18, 0), tie.lightened(0.06 * ((layer + k) % 3)))
	bt.add(Vector3(0.4, 0.22, 0.32), Vector3(0.95, 0.11, 1.05), Color(0.92, 0.92, 0.9), Basis(Vector3.UP, 0.4))  # muovikassi
	bt.add(Vector3(0.14, 0.09, 0.05), Vector3(1.02, 0.24, 1.12), Color(0.85, 0.15, 0.1), Basis(Vector3.UP, 0.4))
	bt.commit(n)
	var body := StaticBody3D.new()
	n.add_child(body)
	body.add_child(B.box_shape(Vector3(1.6, 0.9, 2.6), Vector3(0, 0.45, 0)))
	return n
