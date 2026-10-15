extends Node
## Vaalan tiet ja kohteet mopolla oikeasti ajaen: autopilotti (mopo.gd autopilot) ajaa jokaisen tien päästä
## päähän täyttä 60 km/h (jarruttaa vain mutkiin, joista mopo ei muuten selviä) ja jokaiseen kohteeseen
## ajoalueen (vaala.gd drivable) lyhintä reittiä mökiltä. Kirjaa jumit, törmäykset, reunaan hankaamiset ja
## huippunopeuden. Ajetaan ilman ikkunaa nopeutettuna:
## godot --headless --path . -- --shot=x.png --scene=vaala_ajo [--ajo=tiet|kohteet|juna]

const TIME_SCALE := 6.0

var main: Node3D
var vl: Node3D
var mp: CharacterBody3D
var trip: Node3D
var problems: Array[String] = []


func run() -> void:
	for i in 10:
		await get_tree().process_frame
	main.mokki.ensure_built()
	main._start_mopo()
	trip = main.mopo_trip
	vl = trip.vaala
	mp = trip.mopo
	if main._ratsia != null and is_instance_valid(main._ratsia):
		main._ratsia.queue_free()
	for car in trip._cars:
		car.process_mode = Node.PROCESS_MODE_DISABLED
		car.visible = false
	var only := "kaikki"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ajo="):
			only = a.substr(6)
	if only.begins_with("kuva:"):
		# Kuvat kohdasta x,z (ikkunallinen ajo): ylhäältä ja viistosti.
		var q := only.substr(5).split(",")
		var at := Vector3(float(q[0]), 0, float(q[1]))
		at.y = vl.h(at.x, at.z)
		mp.position = at + Vector3(0, 0.6, 0)
		var cam := Camera3D.new()
		add_child(cam)
		cam.current = true
		var out := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shot="):
				out = a.substr(7)
		var sq := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 4.0
		sq.shape = sph
		sq.transform = Transform3D(Basis(), vl.to_global(at + Vector3(0, 1.0, 0)))
		sq.exclude = [mp.get_rid()]
		for r in mp.get_world_3d().direct_space_state.intersect_shape(sq, 16):
			var co: CollisionObject3D = r.collider
			var so: Object = co.shape_owner_get_owner(co.shape_find_owner(r.shape))
			var info := ""
			if so is CollisionShape3D:
				var cs := so as CollisionShape3D
				info = "%s @%s" % [cs.shape.get_class(), str(vl.to_local(cs.global_position).snapped(Vector3.ONE * 0.1))]
				if cs.shape is BoxShape3D:
					info += " koko %s" % str((cs.shape as BoxShape3D).size)
			print("KUVA este: %s/%s %s %s" % [co.get_parent().name, co.name, info, co.get_meta("what", "")])
		var n := 0
		for v in [Vector3(0.1, 40, 0.1), Vector3(-12, 7, 12), Vector3(12, 7, -12)]:
			cam.look_at_from_position(vl.to_global(at + v), vl.to_global(at))
			for i in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % n))
			n += 1
		return
	if only.begins_with("lava"):
		await _lava_shots(only)
		return
	if only == "juna":
		await _train_test()
		return
	main._lava_pass = "lippu"  # lippu ostettu: lavan portti on auki (ilman lippua portsari ja kiinni oleva portti)
	main._lava_pass_day = main.day
	if vl.train != null:
		vl.train.random = false
		vl.train._despawn()
	Engine.physics_ticks_per_second = int(60 * TIME_SCALE)
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = TIME_SCALE
	for i in 5:
		await get_tree().physics_frame
	if only in ["kaikki", "tiet"]:
		await _roads()
	if only in ["kaikki", "kohteet"]:
		await _targets()
	Engine.time_scale = 1.0
	print("AJO yhteenveto: %d ongelmaa" % problems.size())
	for p in problems:
		print("AJO  ✗ ", p)


# --- Tiet --------------------------------------------------------------------------------------------------------

func _roads() -> void:
	vl.open_gate(true)  # lavan portti on kiinni ilman lippua (portsari): tie ajetaan portin läpi
	var lines: Array = []  # [nimi, PackedVector2Array]
	var main_pts := PackedVector2Array()
	for i in range(6, vl.road.size()):
		var p: Vector3 = vl.road_pos(i) + vl.road_dir(i).cross(Vector3.UP) * 1.6  # oikea kaista
		main_pts.append(Vector2(p.x, p.z))
	lines.append(["reitti Siitarille", main_pts])
	var back := PackedVector2Array()
	for i in range(vl.road.size() - 1, 5, -1):
		var p: Vector3 = vl.road_pos(i) - vl.road_dir(i).cross(Vector3.UP) * 1.6
		back.append(Vector2(p.x, p.z))
	lines.append(["reitti mökille", back])
	for b in vl.data.branches:
		var bp := PackedVector2Array()
		for k in b.pts.size() - 3:  # umpitien puomi lopussa
			bp.append(Vector2(b.pts[k][0], b.pts[k][2]))
		lines.append(["haara " + b.name, bp])
	for r in vl.data.side_roads:
		if r.kind == "rail" or r.hw == "steps" or r.pts.size() < 2:
			continue
		var sp := PackedVector2Array()
		for q in r.pts:
			sp.append(Vector2(q[0], q[1]))
		lines.append(["%s (%s)" % [r.name if r.name != "" else "nimetön", r.hw], sp])
	if vl.data.has("lava"):
		var lp := PackedVector2Array()
		for q in vl.data.lava.road:
			lp.append(Vector2(q[0], q[1]))
		lines.append(["lavan tie", lp])
	for r in vl.north_roads:
		lines.append(["järviseutu " + str(r.name), r.pts])
	var total := 0.0
	# --kohdat=x,z;x,z: vain viivat, jotka kulkevat 25 m:n sisällä jostain kohdasta (korjausten tarkistus).
	var spots: Array[Vector2] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kohdat="):
			for q in a.substr(9).split(";"):
				spots.append(Vector2(float(q.get_slice(",", 0)), float(q.get_slice(",", 1))))
	for ln in lines:
		var pts: PackedVector2Array = _resample(ln[1], 2.0)
		if pts.size() < 3:
			continue
		if not spots.is_empty() and not spots.any(func(sp: Vector2) -> bool:
				return Array(pts).any(func(q: Vector2) -> bool: return q.distance_to(sp) < 25.0)):
			continue
		var res: Dictionary = await _drive(pts, ln[0])
		total += res.len
		print("AJO %-48s %6.0f m  huippu %3d km/h  aika %5.1f s  %s" % [ln[0], res.len, roundi(res.top * 3.6), res.t,
			"OK" if res.issues.is_empty() else ", ".join(res.issues)])
	print("AJO tiet: %d viivaa, %.1f km" % [lines.size(), total / 1000.0])


# --- Kohteet -----------------------------------------------------------------------------------------------------

func _targets() -> void:
	var goals: Array = [["siitari", vl.siitari_park, false], ["lava", vl.lava_door, false], ["atm", vl.atm_pos, false]]
	for d in vl.doors:
		goals.append([d.id, d.pos, d.get("walk", false)])
	var dist := _dijkstra(Vector2(vl.mokki_mopo.x, vl.mokki_mopo.z))
	for g in goals:
		var at: Vector3 = g[1]
		if at == Vector3.ZERO or at == Vector3.INF:
			continue
		var walk: bool = g[2]
		var cell := _nearest_reached(dist, Vector2(at.x, at.z), 16.0 if walk else 7.0)
		if cell < 0:
			var far := _nearest_reached(dist, Vector2(at.x, at.z), 80.0)
			var fd := _cell_pos(far).distance_to(Vector2(at.x, at.z)) if far >= 0 else INF
			if walk and fd < 80.0:
				print("AJO kohde %-14s jalan: mopo pääsee %.0f m päähän (kävelykohde)" % [g[0], fd])
				continue
			_bad("kohde %s (%.0f, %.0f): ajoalueelta ei pääse %s m päähän (lähin %.0f m, kohde ajettava %s)" % [g[0], at.x, at.z,
				"16" if walk else "7", fd, vl.drivable(at.x, at.z)])
			continue
		var path := _path_to(dist, cell)
		# Ajetaan viimeiset 300 m (pitkä matka on ajettu jo teiden testissä).
		var cut := _resample(path, 2.0)
		var keep := mini(cut.size(), 150)
		var tail := cut.slice(cut.size() - keep)
		var res: Dictionary = await _drive(tail, "kohde " + g[0], true)
		var end := Vector2(mp.position.x, mp.position.z)
		var miss := end.distance_to(Vector2(at.x, at.z))
		var ok: bool = res.issues.is_empty() and miss < (16.0 if walk else 7.5)
		print("AJO kohde %-14s %5.0f m  huippu %3d km/h  perillä %4.1f m  %s" % [g[0], res.len, roundi(res.top * 3.6), miss,
			"OK" if ok else ", ".join(res.issues + (["jäi %.1f m päähän" % miss] if miss >= (16.0 if walk else 7.5) else []))])
		if miss >= (16.0 if walk else 7.5):
			_bad("kohde %s: mopo jäi %.1f m päähän" % [g[0], miss])


## Ajoalueen ruudukossa lyhin reitti lähtöruudusta kaikkialle (Dialin algoritmi). Reunan lähellä on kalliimpaa,
## jottei reitti hankaa reunaa. Palauttaa [etäisyys, edeltäjä] -taulukot.
func _dijkstra(from: Vector2) -> Array:
	var nx: int = vl._dnx
	var nz: int = vl._dnz
	var drive: PackedByteArray = vl._drive
	var n := nx * nz
	var cost := PackedByteArray()
	cost.resize(n)
	for j in range(2, nz - 2):
		for i in range(2, nx - 2):
			var id := j * nx + i
			if drive[id] == 0:
				continue
			var edge := 0
			for dj in range(-2, 3):
				for di in range(-2, 3):
					if drive[id + dj * nx + di] == 0:
						edge = maxi(edge, 3 - maxi(absi(di), absi(dj)))
			cost[id] = 1 + edge * 3
	var d := PackedInt32Array()
	d.resize(n)
	d.fill(0x7fffffff)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var c := DRIVE_cell(from)
	if c < 0 or drive[c] == 0:
		_bad("mökin parkki ei ole ajoalueella")
		return [d, prev]
	var buckets := {}
	d[c] = 0
	buckets[0] = [c]
	var cur := 0
	var left := 1
	var nbr := [[1, 0, 10], [-1, 0, 10], [0, 1, 10], [0, -1, 10], [1, 1, 14], [1, -1, 14], [-1, 1, 14], [-1, -1, 14]]
	while left > 0:
		if not buckets.has(cur):
			cur += 1
			continue
		var b: Array = buckets[cur]
		buckets.erase(cur)
		for id in b:
			left -= 1
			if d[id] != cur:
				continue
			var i: int = id % nx
			var j: int = id / nx
			for o in nbr:
				var ii: int = i + o[0]
				var jj: int = j + o[1]
				if ii < 0 or jj < 0 or ii >= nx or jj >= nz:
					continue
				var nid := jj * nx + ii
				if cost[nid] == 0:
					continue
				var nd: int = cur + o[2] * cost[nid]
				if nd < d[nid]:
					d[nid] = nd
					prev[nid] = id
					if not buckets.has(nd):
						buckets[nd] = []
					buckets[nd].append(nid)
					left += 1
		cur += 1
	return [d, prev]


func DRIVE_cell(p: Vector2) -> int:
	var i := int((p.x - vl._x0) / vl.DRIVE_CELL)
	var j := int((p.y - vl._z0) / vl.DRIVE_CELL)
	if i < 0 or j < 0 or i >= vl._dnx or j >= vl._dnz:
		return -1
	return j * vl._dnx + i


func _cell_pos(id: int) -> Vector2:
	return Vector2(vl._x0 + (id % vl._dnx + 0.5) * vl.DRIVE_CELL, vl._z0 + (id / vl._dnx + 0.5) * vl.DRIVE_CELL)


func _nearest_reached(dist: Array, p: Vector2, r: float) -> int:
	var d: PackedInt32Array = dist[0]
	var best := -1
	var bd := INF
	var steps := int(r / vl.DRIVE_CELL) + 1
	var c := DRIVE_cell(p)
	if c < 0:
		return -1
	for dj in range(-steps, steps + 1):
		for di in range(-steps, steps + 1):
			var id: int = c + dj * vl._dnx + di
			if id < 0 or id >= d.size() or d[id] == 0x7fffffff:
				continue
			var q := _cell_pos(id).distance_to(p)
			if q < r and q < bd:
				bd = q
				best = id
	return best


func _path_to(dist: Array, cell: int) -> PackedVector2Array:
	var prev: PackedInt32Array = dist[1]
	var out := PackedVector2Array()
	var id := cell
	while id >= 0:
		out.append(_cell_pos(id))
		id = prev[id]
	out.reverse()
	# Porrastus pois: liukuva keskiarvo.
	var sm := PackedVector2Array()
	for k in out.size():
		var acc := Vector2.ZERO
		var cnt := 0
		for o in range(-1, 2):
			var q := clampi(k + o, 0, out.size() - 1)
			acc += out[q]
			cnt += 1
		sm.append(acc / cnt)
	return sm


# --- Autopilotti -------------------------------------------------------------------------------------------------

func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return out
	out.append(pts[0])
	var carry := 0.0
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var seg := a.distance_to(b)
		var s := step - carry
		while s <= seg:
			out.append(a.lerp(b, s / seg))
			s += step
		carry = seg - (s - step)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > 0.5:
		out.append(pts[pts.size() - 1])
	return out


func _ground_y(x: float, z: float, above: float) -> float:
	var space := mp.get_world_3d().direct_space_state
	var top: Vector3 = vl.to_global(Vector3(x, above + 3.0, z))
	var ray := PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 12, 0), mp.collision_mask, [mp.get_rid()])
	var hit := space.intersect_ray(ray)
	return vl.to_local(hit.position).y if not hit.is_empty() else vl.h(x, z)


func _place(p: Vector2, dir: Vector2) -> void:
	var y := _ground_y(p.x, p.y, vl.h(p.x, p.y) + 8.0)
	mp.position = Vector3(p.x, y + 0.5, p.y)
	mp.rotation.y = atan2(-dir.x, -dir.y)
	mp.velocity = Vector3.ZERO
	mp.speed = 0.0


## Ajaa viivan päästä päähän. Palauttaa {len, top, t, issues}.
func _drive(pts: PackedVector2Array, name: String, to_end := false) -> Dictionary:
	var cum := PackedFloat32Array([0.0])
	for k in range(1, pts.size()):
		cum.append(cum[k - 1] + pts[k].distance_to(pts[k - 1]))
	var total := cum[cum.size() - 1]
	_place(pts[0], pts[1] - pts[0])
	for i in 3:
		await get_tree().physics_frame
	var idx := 0
	var top := 0.0
	var t := 0.0
	var best_s := 0.0
	var stall_t := 0.0
	var issues: Array[String] = []
	var noted := {}
	var limit := total / 4.0 + 30.0
	while t < limit:
		await get_tree().physics_frame
		var dt := 1.0 / 60.0
		t += dt
		var p := Vector2(mp.position.x, mp.position.z)
		# Edistyminen: lähin piste eteenpäin ikkunasta.
		var bd := INF
		for k in range(idx, mini(idx + 30, pts.size())):
			var dd := pts[k].distance_squared_to(p)
			if dd < bd:
				bd = dd
				idx = k
		var s := cum[idx]
		var lateral := sqrt(bd)
		if s > best_s + 2.0:
			best_s = s
			stall_t = 0.0
		else:
			stall_t += dt
		if idx >= pts.size() - 2:
			break
		var sp := absf(mp.speed)
		top = maxf(top, sp)
		# Tavoitenopeus: mutkat edessä (kaarresäde) ja jarrutusmatka niihin.
		var v_target: float = mp.MAX_SPEED
		var k2 := idx
		while k2 + 4 < pts.size() and cum[k2] - s < 45.0:
			var a1 := (pts[k2 + 2] - pts[k2]).angle_to(pts[k2 + 4] - pts[k2 + 2])
			if absf(a1) > 0.01:
				var r := 4.0 / absf(a1)
				var v_ok := r * 1.15
				v_target = minf(v_target, sqrt(v_ok * v_ok + 2.0 * 6.0 * maxf(cum[k2] - s, 0.0)))
			k2 += 2
		var look := clampf(4.0 + sp * 0.45, 4.0, 11.0)
		var li := idx
		while li < pts.size() - 1 and cum[li] - s < look:
			li += 1
		var aim := pts[li] - p
		var fwd := Vector2(-sin(mp.rotation.y), -cos(mp.rotation.y))
		var err := fwd.angle_to(aim)
		var steer := clampf(-err * 2.5, -1.0, 1.0)
		var thr := 1.0
		if sp > v_target + 0.6:
			thr = -1.0
		elif sp > v_target:
			thr = 0.0
		mp.autopilot = Vector2(thr, steer)
		# Havainnot (kukin kerran 30 m:n välein).
		var cell := "%d,%d" % [int(p.x / 30.0) * 30, int(p.y / 30.0) * 30]
		if sp > 4.0:
			for c in mp.get_slide_collision_count():
				var col := mp.get_slide_collision(c)
				if col.get_normal().y < 0.6 and not noted.has("hit" + cell):
					var who: Object = col.get_collider()
					var nm := "%s/%s" % [(who as Node).get_parent().name if who is Node and (who as Node).get_parent() != null else "?",
						(who as Node).name if who is Node else "?"]
					noted["hit" + cell] = true
					var cp := col.get_position()
					var lp: Vector3 = vl.to_local(cp)
					var shp := ""
					var sh_id := col.get_collider_shape_index()
					if who is CollisionObject3D:
						var owner_id: int = (who as CollisionObject3D).shape_find_owner(sh_id)
						var so: Object = (who as CollisionObject3D).shape_owner_get_owner(owner_id)
						if so is CollisionShape3D:
							shp = "%s %s" % [(so as CollisionShape3D).shape.get_class(), str((so as CollisionShape3D).global_position.snapped(Vector3.ONE * 0.1))]
							if (so as CollisionShape3D).shape is BoxShape3D:
								shp += " koko %s" % str(((so as CollisionShape3D).shape as BoxShape3D).size.snapped(Vector3.ONE * 0.1))
					issues.append("törmäys %s (%.1f, %.1f, %.1f) %s" % [nm, lp.x, lp.y, lp.z, shp])
		if mp._curb > 0.6 and sp > 6.0 and not noted.has("curb" + cell):
			noted["curb" + cell] = true
			issues.append("reuna @%s" % cell)
		if lateral > 9.0 and not noted.has("lat" + cell):
			noted["lat" + cell] = true
			issues.append("eksyi %.0f m @%s" % [lateral, cell])
		if stall_t > 4.0:
			var ahead := p + fwd * 2.0
			issues.append("JUMI (%.1f, %.1f) %.0f/%.0f m, edessä ajettava %s, koodi %d, kaltevuus %.2f" % [p.x, p.y, s, total,
				vl.drivable(ahead.x, ahead.y), vl.drive_code(Vector3(ahead.x, 0, ahead.y)),
				(vl.h(ahead.x, ahead.y) - vl.h(p.x, p.y)) / 2.0])
			# Jatketaan 12 m edempää.
			var nk := idx
			while nk < pts.size() - 2 and cum[nk] - s < 12.0:
				nk += 1
			_place(pts[nk], pts[mini(nk + 1, pts.size() - 1)] - pts[nk])
			idx = nk
			best_s = cum[nk]
			stall_t = 0.0
	if t >= limit:
		issues.append("aika loppui %.0f/%.0f m" % [best_s, total])
	mp.autopilot = Vector2(-1, 0)
	for i in 30:
		await get_tree().physics_frame
	mp.autopilot = Vector2.INF
	for it in issues:
		_bad("%s: %s" % [name, it])
	return {"len": total, "top": top, "t": t, "issues": issues}


func _bad(s: String) -> void:
	problems.append(s)


# --- Juna --------------------------------------------------------------------------------------------------------

## Mopo radalle, juna ajaa päälle: pitää kuolla (mopo_trip killed). Lisäksi seisovan junan läpi ei aja.
func _train_test() -> void:
	var tr: Node3D = vl.train
	if tr == null:
		print("JUNA: ei junaa")
		return
	tr.random = false
	var died := [""]
	trip.killed.connect(func() -> void: died[0] = "auto")
	if trip.has_signal("train_hit"):
		trip.train_hit.connect(func() -> void: died[0] = "juna")
	var t_mid: float = tr.length() * 0.5
	var at: Vector3 = tr.to_global(tr.point_t(t_mid))
	var lat: Vector3 = tr.dir_t(t_mid).cross(Vector3.UP)
	var local: Vector3 = trip.to_local(at)
	mp.position = local + Vector3(0, 0.6, 0)
	mp.rotation.y = atan2(-lat.x, -lat.z)
	mp.speed = 0.0
	mp.autopilot = Vector2(0, 0)
	tr.spawn_now(true, 0)
	var t := 0.0
	while t < 60.0 and died[0] == "":
		await get_tree().physics_frame
		t += 1.0 / 60.0
	print("JUNA: mopo radalla, kuolinsyy '%s' %.1f s" % [died[0], t])
	if DisplayServer.get_name() != "headless":
		for k in 4:
			for i in 150:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_shot_path("_juna%d" % k))
	await get_tree().process_frame


# --- Lava: kuvat sisältä ja ulkoa ----------------------------------------------------------------------------------

func _shot_path(suffix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			return a.substr(7).replace(".png", suffix + ".png")
	return "user://lava" + suffix + ".png"


func _snap(cam: Camera3D, from: Vector3, to: Vector3, suffix: String, frames := 30) -> void:
	cam.look_at_from_position(vl.to_global(from), vl.to_global(to))
	cam.current = true
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_path(suffix))


## lava = ulkoa ja sisältä ennen sisäänmenoa, lava_sisa = lavatanssien näkymä (lava_game.gd) ja kappaletoive.
func _lava_shots(mode: String) -> void:
	var c: Vector3 = vl.lava_center
	var cam := Camera3D.new()
	cam.far = 2000.0
	add_child(cam)
	main._hud.visible = false
	var lv: Dictionary = vl.data.lava
	var side: float = lv.get("door_side", 1.0)
	if mode == "lava":
		main.clock_min = 21.0 * 60.0
		vl.set_lava_live(true)
		for i in 30:
			await get_tree().process_frame
		await _snap(cam, c + Vector3(side * 45.0, 12.0, 30.0), c, "_ulko")
		await _snap(cam, c + Vector3(-60, 120, 60), c, "_yla")
		await _snap(cam, c + Vector3(side * 16.0, 2.6, 0.0), c + Vector3(0, 1.5, -float(lv.l) / 2.0), "_ikkuna")
		await _snap(cam, c + Vector3(0, 3.0, 6.0), c + Vector3(0, 1.8, -float(lv.l) / 2.0), "_sisa_lava")
		await _snap(cam, c + Vector3(-1.5, 2.6, -float(lv.l) / 2.0 + 9.0), c + Vector3(0, 1.6, -float(lv.l) / 2.0 + 2.0), "_bandi", 10)
		await _snap(cam, c + Vector3(side * 30.0, 5.0, -30.0), c + Vector3(side * 10.0, 0, 0), "_piha")
		if vl.lava_kiosk != Vector3.INF:
			var kq: Vector3 = vl.lava_kiosk
			await _snap(cam, kq + Vector3(-side * 7.0, 3.0, 5.0), kq + Vector3(0, 1.2, 0), "_kioski")
		return
	main._enter_lava(true)
	for i in 60:
		await get_tree().process_frame
	var lg: Node3D = main._lava_game
	if "--lahi" in OS.get_cmdline_user_args():
		lg._layer.visible = false
		var bd: Node3D = vl.lava_band
		var shots := [["_l_laulu", Vector3(0, 1.6, -1.7)], ["_l_harmonikka", Vector3(-2.3, 1.3, -0.9)], ["_l_kitara", Vector3(2.3, 1.2, -0.9)],
			["_l_basso", Vector3(3.9, 1.2, 0.5)], ["_l_rummut", Vector3(0, 0.9, 1.3)]]
		for sh in shots:
			var tgt: Vector3 = vl.to_local(bd.to_global(sh[1]))
			var eye: Vector3 = vl.to_local(bd.to_global(sh[1] + Vector3(0.5, 0.25, -2.2)))
			await _snap(cam, eye, tgt, sh[0], 8)
		return
	await _snap(get_viewport().get_camera_3d(), lg._cam.global_position, lg._cam.global_position + -lg._cam.global_basis.z, "_peli", 5)
	await _snap(cam, c + Vector3(-1.5, 2.6, -float(lv.l) / 2.0 + 9.0), c + Vector3(0, 1.6, -float(lv.l) / 2.0 + 2.0), "_peli_bandi", 10)
	print("LAVA kappale '%s', bändi %s bpm %.0f, tahti %.3f s, musiikki %s" % [lg._song, vl.lava_band.current_song.get("title", "-"),
		vl.lava_band.bpm, lg._beat, Sfx._music_file])
	if lg.has_method("request_song"):
		lg.request_song(1)
		for i in 120:
			await get_tree().process_frame
		print("LAVA toive: kappale '%s', bändi %s bpm %.0f, tahti %.3f s, musiikki %s, soi %s" % [lg._song,
			vl.lava_band.current_song.get("title", "-"), vl.lava_band.bpm, lg._beat, Sfx._music_file,
			Sfx._music.playing if Sfx._music != null else false])
		await _snap(cam, c + Vector3(-1.5, 2.6, -float(lv.l) / 2.0 + 9.0), c + Vector3(0, 1.6, -float(lv.l) / 2.0 + 2.0), "_toive", 10)
