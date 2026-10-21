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
	if "--ajo=runko" in OS.get_cmdline_user_args():
		await _trunk_test()
		return
	if "--ajo=kuolema_saloinen" in OS.get_cmdline_user_args():
		# Kuolema kaukana kotoa (laavulla): herätys kotona ja Päivi motkottaa pihalla.
		var M := preload("res://scripts/map_data.gd")
		var w2: Vector2 = M.w2(M.LAAVU)
		main.laavu_conquered = true
		main.player.global_position = Vector3(w2.x, 2.0, w2.y)
		for i in 10:
			await get_tree().process_frame
		main._lose("Rollaattorimummo huitaisi kepillä päähän.", "mummo")
		var t := 0.0
		var k := 0
		while main.state == "cutscene" and t < 40.0:
			await get_tree().process_frame
			t += get_process_delta_time()
			if t > 7.0 + k * 2.0 and k < 2:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(_shot_path("_s%d" % k))
				k += 1
		print("KUOLEMA saloinen: tila %s, kotiin %.0f m" % [main.state, main.player.global_position.distance_to(main.home_zone)])
		return
	if "--ajo=kuolema" in OS.get_cmdline_user_args():
		await _death_test()
		return
	if "--ajo=muistivuoto" in OS.get_cmdline_user_args():
		await _leak_test()
		get_tree().quit()
		return
	if "--ajo=vapautus" in OS.get_cmdline_user_args():
		await _unload_test()
		return
	if "--ajo=muisti" in OS.get_cmdline_user_args():
		await _memory_parts()
		return
	if "--ajo=kylakuvat" in OS.get_cmdline_user_args():
		await _village_shots()
		return
	if "--ajo=meshit" in OS.get_cmdline_user_args():
		_world_meshes()
		return
	if "--ajo=metsa" in OS.get_cmdline_user_args():
		await _forest_probe()
		return
	if "--ajo=mittaa" in OS.get_cmdline_user_args():
		await _measure()
		return
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


# --- Saloisten puunrungot (world.gd lähilohkot) -------------------------------------------------------------------

## Kävelijä lähimmän rungon viereen ja kävellen sitä päin: rungon pitää pysäyttää.
func _trunk_test() -> void:
	var w: Node3D = main.world
	var pl: Node3D = main.player
	var c := Vector2i(floori(pl.global_position.x / w.TRUNK_CELL), floori(pl.global_position.z / w.TRUNK_CELL))
	var best := Vector3.INF
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			for p in w._trunk_grid.get(c + Vector2i(dx, dz), PackedVector3Array()):
				if best == Vector3.INF or p.distance_to(pl.global_position) < best.distance_to(pl.global_position):
					best = p
	print("RUNKO lähin %s, kappaleita %d" % [best, w._trunk_bodies.size()])
	if best == Vector3.INF:
		return
	var space := pl.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(best + Vector3(-3, -0.5, 0), best + Vector3(3, -0.5, 0))
	var hit := space.intersect_ray(q)
	print("RUNKO säde osui: %s %s" % [not hit.is_empty(), hit.get("collider")])


# --- Ajonaikaiset kustannukset paikoittain ------------------------------------------------------------------------

## Keskimääräinen ruutuaika, skriptien ja fysiikan aika, piirtokutsut, kolmiot ja solmut 180 ruudun ajalta.
func _sample(name: String) -> void:
	for i in 240:  # metsän lähilohkot rakentuvat vähitellen (8 ruudussa): mitataan vasta valmiista näkymästä
		await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # asetukset palauttavat sen: pois joka mittauksella
	Engine.max_fps = 0
	for i in 20:
		await get_tree().process_frame
	var n := 180
	var acc := {"ms": 0.0, "proc": 0.0, "phys": 0.0, "draw": 0.0, "obj": 0.0, "prim": 0.0, "rcpu": 0.0, "gpu": 0.0, "setup": 0.0}
	var vrid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vrid, true)
	var worst := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		worst = maxf(worst, ms)
		acc.ms += ms
		acc.proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		acc.phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		acc.draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		acc.obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		acc.prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		acc.rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vrid)
		acc.gpu += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
		acc.setup += RenderingServer.get_frame_setup_time_cpu()
	var chars := 0
	var chars_on := 0
	for c in get_tree().root.find_children("*", "Node3D", true, false):
		if c.get_script() != null and (c.get_script() as Script).resource_path.ends_with("character.gd"):
			chars += 1
			if c.can_process() and c.is_visible_in_tree():
				chars_on += 1
	print("MITTA %-16s fysiikka: aktiivisia %d, pareja %d · hahmoja %d (päivittyy näkyvinä %d)" % [name,
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), chars, chars_on])
	if not "--ei-erittelya" in OS.get_cmdline_user_args():
		await _attribute(name)
	if "--mitta-kuvat" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot_path("_" + name.split(" ")[0] + ".png"))
	print("MITTA %-16s renderöinti: suoritin %5.2f ms (valmistelu %5.2f ms) · näytönohjain %5.2f ms" % [name,
		acc.rcpu / n, acc.setup / n, acc.gpu / n])
	print("MITTA %-16s ruutu %5.1f ms (pahin %5.1f) · koko ruutu (TIME_PROCESS) %5.2f ms · fysiikka %5.2f ms · piirtoja %5d · objekteja %5d · kolmioita %6.0f k · solmuja %d · muisti %d Mt" % [
		name, acc.ms / n, worst, acc.proc / n, acc.phys / n, roundi(acc.draw / n), roundi(acc.obj / n), acc.prim / n / 1000.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576])


func _measure() -> void:
	main._note.visible = false
	# Todellinen ruutuaika ilman pystytahdistusta; --mitta-skaala=0.5 puolittaa 3D-resoluution (näytönohjainraja?).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mitta-laatu="):
			# Laatutaso (0–3) kuten asetuksista, tallentamatta asetuksia.
			Settings.values.quality = int(a.substr(14))
			Settings.apply()
			main._apply_settings()
		elif a.begins_with("--mitta-skaala="):
			get_viewport().scaling_3d_scale = float(a.substr(15))
		elif a.begins_with("--mitta-varjo="):
			# Kokeilu: suodatin:N (pehmeiden varjojen laatu 0–5), jaot:2|4 (kaskadit), koko:N (atlas), matka:N (m)
			for kv in a.substr(14).split(","):
				var p := kv.split(":")
				match p[0]:
					"suodatin":
						RenderingServer.directional_soft_shadow_filter_set_quality(int(p[1]))
					"jaot":
						main._sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if p[1] == "2" else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
					"koko":
						RenderingServer.directional_shadow_atlas_set_size(int(p[1]), true)
					"matka":
						main._sun.directional_shadow_max_distance = float(p[1])
					"sumeus":
						main._sun.shadow_blur = float(p[1])
	var M := preload("res://scripts/map_data.gd")
	var T := preload("res://scripts/terrain.gd")
	var pl: Node3D = main.player
	await _sample("koti")
	for spot in [["kauppa", M.SHOP_BUILDING + Vector2(0, 30)], ["laavu (metsä)", M.LAAVU + Vector2(10, 10)]]:
		var w: Vector2 = M.w2(spot[1])
		pl.global_position = Vector3(w.x, T.h(w.x, w.y) + 0.5, w.y)
		await _sample(spot[0])
	main.mokki.ensure_built()
	main._start_mopo()
	trip = main.mopo_trip
	vl = trip.vaala
	mp = trip.mopo
	await _sample("mökki (mopo)")
	var sc: Vector3 = vl.siitari_park
	mp.position = sc + Vector3(0, 0.6, 0)
	await _sample("Vaala keskusta")
	main.clock_min = 21.0 * 60.0
	mp.position = vl.lava_door + Vector3(0, 0.6, 0) + vl.lava_out * 10.0
	await _sample("Vaala lava")


## Piirtokutsujen ja kolmioiden jakautuma: piilotetaan solmuryhmä kerrallaan ja katsotaan, paljonko lukemat putoavat.
func _attribute(name: String) -> void:
	var groups := {}
	for c in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var gi := c as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var owner_name := "?"
		var n: Node = gi
		while n != null:
			if n.get_script() != null:
				owner_name = (n.get_script() as Script).resource_path.get_file()
				break
			n = n.get_parent()
		var kind := gi.get_class()
		if gi is MultiMeshInstance3D:
			kind = "MultiMesh"
		var key := "%s / %s" % [owner_name, kind]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(gi)
	var base := await _frame_stats()
	var rows: Array = []
	for key in groups:
		for gi in groups[key]:
			gi.visible = false
		var st := await _frame_stats()
		for gi in groups[key]:
			gi.visible = true
		rows.append([key, base[0] - st[0], base[1] - st[1], groups[key].size()])
	rows.sort_custom(func(a, b) -> bool: return a[1] > b[1])
	for r in rows.slice(0, 10):
		print("MITTA %-16s   %-40s piirtoja %5d · kolmioita %7.0f k · solmuja %d" % [name, r[0], r[1], r[2] / 1000.0, r[3]])
	rows.sort_custom(func(a, b) -> bool: return a[2] > b[2])
	for r in rows.slice(0, 5):
		print("MITTA %-16s   kolmiot: %-31s %7.0f k" % [name, r[0], r[2] / 1000.0])


func _frame_stats() -> Array:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)]



## Metsän (forest.gd) kolmiot tasoittain mökillä: lähi-, keski- ja kaukotaso sekä varjojen osuus.
func _forest_probe() -> void:
	main._note.visible = false
	main.mokki.ensure_built()
	main._start_mopo()
	for i in 240:  # lähilohkoja rakennetaan 8 ruudussa: odotetaan, että kaikki ovat valmiina
		await get_tree().process_frame
	var forests := get_tree().root.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool:
		return n.get_script() != null and (n.get_script() as Script).resource_path.ends_with("forest.gd"))
	var groups := {"lähi": [], "keski": [], "kauko": []}
	var tris := {}
	for f in forests:
		for c in f.get_children():
			if c is MultiMeshInstance3D:
				var mmi := c as MultiMeshInstance3D
				var g := "kauko" if mmi.multimesh.mesh in f._meshes.far else ("lähi" if mmi.multimesh.mesh in f._meshes.near else "keski")
				groups[g].append(mmi)
	for sp in 5:
		var f0: Node = forests[0]
		var t := 0
		for lvl in ["near", "mid", "far"]:
			var m: ArrayMesh = f0._meshes[lvl][sp]
			var n := 0
			for si in m.get_surface_count():
				n += m.surface_get_array_index_len(si) / 3 if m.surface_get_array_index_len(si) > 0 else m.surface_get_array_len(si) / 3
			tris["%d %s" % [sp, lvl]] = n
	print("METSÄ mallien kolmiot: ", tris)
	var base := await _frame_stats()
	print("METSÄ kaikki: piirtoja %d, kolmioita %.0f k" % [base[0], base[1] / 1000.0])
	for g in groups:
		var inst := 0
		for mmi in groups[g]:
			inst += (mmi as MultiMeshInstance3D).multimesh.instance_count
			mmi.visible = false
		var st := await _frame_stats()
		for mmi in groups[g]:
			mmi.visible = true
		print("METSÄ %-6s solmuja %4d, instansseja %6d: piirtoja %5d, kolmioita %7.0f k" % [g, groups[g].size(), inst, base[0] - st[0], (base[1] - st[1]) / 1000.0])
	for mmi in groups["lähi"]:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ns := await _frame_stats()
	print("METSÄ lähitaso ilman varjoja: piirtoja -%d, kolmioita -%.0f k" % [base[0] - ns[0], (base[1] - ns[1]) / 1000.0])
	for mmi in groups["lähi"]:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mmi in groups["keski"]:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ms := await _frame_stats()
	print("METSÄ keskitaso ilman varjoja: piirtoja -%d, kolmioita -%.0f k" % [base[0] - ms[0], (base[1] - ms[1]) / 1000.0])


## Kylän (world.gd) erilliset MeshInstance3D-solmut maailman suorien lasten mukaan: mistä rakenteesta niitä tulee.
func _world_meshes() -> void:
	var w: Node3D = main.world
	var rows: Array = []
	var total := 0
	var direct := 0
	for c in w.get_children():
		if c is MeshInstance3D:
			direct += 1
			continue
		var n := c.find_children("*", "MeshInstance3D", true, false).size()
		total += n
		if n > 0:
			rows.append([n, c.get_class(), str((c as Node3D).global_position.round()) if c is Node3D else "", c.name])
	rows.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	print("MESHIT suoraan maailmassa %d, alisolmuissa %d (%d alisolmua)" % [direct, total, rows.size()])
	for r in rows.slice(0, 25):
		print("MESHIT %5d  %-14s %-22s %s" % r)


## Kiinteät kuvat kylästä (sama kellonaika): rakennusten yhdistämisen ja metsän muutosten vertailuun.
func _village_shots() -> void:
	var M := preload("res://scripts/map_data.gd")
	var T := preload("res://scripts/terrain.gd")
	main.clock_min = 12.0 * 60.0
	main._hud.visible = false
	var cam := Camera3D.new()
	cam.far = 2000.0
	main.add_child(cam)
	var spots := [["koti", M.HOME_BUILDING], ["kauppa", M.SHOP_BUILDING], ["laavu", M.LAAVU], ["kota", M.KOTA]]
	for sp in spots:
		var w: Vector2 = M.w2(sp[1])
		var g := Vector3(w.x, T.h(w.x, w.y), w.y)
		for v in [[Vector3(18, 9, 22), "a"], [Vector3(-25, 14, -20), "b"]]:
			cam.look_at_from_position(g + v[0], g + Vector3(0, 1.5, 0))
			cam.current = true
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_shot_path("_%s_%s" % [sp[0], v[1]]))


## Pelin osien koko: solmut ja muisti, kun osa vapautetaan (mökki ja Vaala rakennettuina kuten matkan jälkeen).
func _memory_parts() -> void:
	main.mokki.ensure_built()
	main._start_mopo()
	for i in 30:
		await get_tree().process_frame
	var rows: Array = []
	for c in main.get_children():
		var n := c.find_children("*", "", true, false).size() + 1
		if n > 200:
			rows.append([n, c.name, (c.get_script() as Script).resource_path.get_file() if c.get_script() != null else c.get_class()])
	rows.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	for r in rows:
		print("MUISTI %6d solmua  %-28s %s" % r)
	for target in ["mopo_trip", "raahe_int", "mokki", "siitari_int", "kirppis_int", "asema_int", "varasto_int", "garage_int", "home_int", "mokki_int"]:
		var node: Node = main.get(target)
		if node == null:
			continue
		var m0 := Performance.get_monitor(Performance.MEMORY_STATIC)
		var o0 := Performance.get_monitor(Performance.OBJECT_COUNT)
		var copy_parent := node.get_parent()
		copy_parent.remove_child(node)
		node.free()
		for i in 5:
			await get_tree().process_frame
		print("MUISTI vapautus %-12s  -%4d Mt  -%6d objektia" % [target, (m0 - Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576,
			o0 - Performance.get_monitor(Performance.OBJECT_COUNT)])
		main.set(target, null)


## Kaukaisten paikkojen vapautus (main.gd _unload_far_places): Vaalaan, kuolema ja koti, junalla takaisin, Raaheen.
## Muistivuodot: mopomatka Vaalaan ja junalla takaisin Saloisiin (Vaala vapautuu) useita kertoja peräkkäin.
## Joka kierroksen jälkeen muisti, oliot, solmut, resurssit ja orvot solmut: kasvu kierros kierrokselta = vuoto.
func _leak_test() -> void:
	var stats := func(label: String) -> void:
		for i in 60:
			await get_tree().process_frame
		print("VUOTO %-22s muisti %4d Mt · olioita %6d · solmuja %6d · resursseja %5d · orpoja %4d · video %4d Mt" % [label,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576, Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576])
		var B := preload("res://scripts/build.gd")
		var Ch := preload("res://scripts/character.gd")
		var L := preload("res://scripts/looks.gd")
		var V := preload("res://scripts/vehicles.gd")
		print("VUOTO   säiliöt: erät disk %d used %d cache %d · prims %d · mats %d · shaders %d · vaatemeshit %d · lippikset %d · ajoneuvot %d/%d" % [
			B.Batch.disk.size(), B.Batch.used.size(), B.Batch._cache.size(), B._prims.values().filter(func(w): return w.get_ref() != null).size(), B._mats.size(), B._shaders.size(),
			Ch._meshes.size(), L._cap_cache.size(), V._mats.size(), V._merged.size()])
	main.mokki.ensure_built()
	await stats.call("alussa")
	var rounds := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kierroksia="):
			rounds = int(a.substr(13))
	for k in rounds:
		main._start_mopo()
		for i in 30:
			await get_tree().process_frame
		await stats.call("kierros %d Vaalassa" % (k + 1))
		main.money = 100.0
		main._train_trip("saloinen")
		var t := 0.0
		while main.mopo_trip != null and t < 120.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		await stats.call("kierros %d Saloisissa" % (k + 1))
		var Bp := preload("res://scripts/build.gd")
		if k == 0:
			set_meta("prims0", Bp._prims.keys())
		elif k == 1:
			var before: Array = get_meta("prims0")
			var seen := {}
			for kk in before:
				seen[kk] = true
			var fresh := Bp._prims.keys().filter(func(kk): return not seen.has(kk))
			print("VUOTO   uudet primitiivit kierroksella 2: %d, esim. %s" % [fresh.size(), fresh.slice(0, 12)])
	if "--orvot" in OS.get_cmdline_user_args():
		Node.print_orphan_nodes()


func _unload_test() -> void:
	var mem := func() -> String:
		return "%d Mt, %d oliota" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576, Performance.get_monitor(Performance.OBJECT_COUNT)]
	print("VAPAUTUS alussa: Vaala %s, Raahe %s, %s" % [main.mopo_trip != null, main.raahe_int != null, mem.call()])
	main.mokki.ensure_built()
	main._start_mopo()
	for i in 10:
		await get_tree().process_frame
	print("VAPAUTUS Vaalassa: Vaala %s, Raahe %s, %s" % [main.mopo_trip != null, main.raahe_int != null, mem.call()])
	main.money = 100.0
	main._train_trip("saloinen")  # junalla takaisin Saloisiin (välianimaatio ravintolavaunussa)
	var t := 0.0
	while main.mopo_trip != null and t < 90.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	print("VAPAUTUS Saloisissa %.0f s: Vaala %s, tila %s, %s" % [t, main.mopo_trip != null, main.state, mem.call()])
	main._enter_raahe()
	for i in 30:
		await get_tree().process_frame
	print("VAPAUTUS Raaheen: tila %s, Raahe %s, vihje '%s'" % [main.state, main.raahe_int != null, main._hint.text])
	main.raahe_int.leave()
	main.state = "ulkona"
	main._arrive_vaala_by_train()
	for i in 60:
		await get_tree().process_frame
	print("VAPAUTUS junalla Vaalaan: Vaala %s, rakennettu %s, Vaalassa %s, Raahe %s" % [main.mopo_trip != null,
		main.mopo_trip.vaala.built if main.mopo_trip != null else false, main._in_vaala, main.raahe_int != null])


## Kuolema Vaalassa (--kohta=gasthaus tai mokki): WASTED, puhelinkohtaus ja herätys. Kuvat kohtauksen aikana.
func _death_test() -> void:
	var where := "gasthaus"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kohta="):
			where = a.substr(8)
	main.mokki.ensure_built()
	main._start_mopo()
	var vl2: Node3D = main.mopo_trip.vaala
	var mp2: CharacterBody3D = main.mopo_trip.mopo
	mp2.position = (vl2.door_pos("gasthaus") + Vector3(8, 0.6, 0)) if where == "gasthaus" else (vl2.mokki_mopo + Vector3(0, 0.6, 30))
	for i in 20:
		await get_tree().process_frame
	main.mopo_trip._on_hit()
	var k := 0
	var t := 0.0
	while main.state == "cutscene" and t < 60.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 9.3 + k * 1.8 and k < 9:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_shot_path("_%s%d" % [where, k]))
			k += 1
	print("KUOLEMA %s: tila %s, Vaalassa %s, mökillä %s, pelaaja %s, viesti '%s'" % [where, main.state, main._in_vaala,
		main._at_mokki(), main.player.global_position.round(), main._msg.text.replace("\n", " ")])
