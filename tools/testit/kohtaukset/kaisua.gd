extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "kaisua": Kaisuan tila (scripts/kaisua.gd). aja() palauttaa 0 = kohtaus ei
## ole tässä, 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin).
##
## mokkikaisua: pellot, piha ja koneet kuvina (yläkuva, piha, konevaja, lato, kuivuri, puimuri, isäntä, pellot).
## mokkikaisua_heina: traktori ja niittokone autopilotilla Kotipellon poikki (kuvat), loppu niitto simuloiden, karhous,
##   paalaus (paaleja putoaa), paalit latoon, maksut, legendaarinen hetki ja talkooruoka.
## mokkikaisua_vilja: puimuri Tienvarsipellolla (kuvat), purku kärryyn, kippaus kuivuriin, äestys ja kylvö Isopellolla,
##   kasvu päivä kerrallaan (oras, vihreä, kypsä).
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const Mokki := preload("res://scripts/mokki.gd")
const Kaisua := preload("res://scripts/kaisua.gd")
const Tila := preload("res://scripts/kaisua_tila.gd")
const Koneet := preload("res://scripts/kaisua_koneet.gd")
const Pose := preload("res://scripts/pose.gd")

const KOHTAUKSET := ["mokkikaisua", "mokkikaisua_heina", "mokkikaisua_vilja", "mokkikaisua_kivet"]

var main: Main
var _cam: Camera3D


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"mokkikaisua":
			await _yleiskuvat(path)
		"mokkikaisua_heina":
			await _heina(path)
		"mokkikaisua_vilja":
			await _vilja(path)
		"mokkikaisua_kivet":
			await _kivet(path)
		_:
			return 0
	return 1


# --- Apurit --------------------------------------------------------------------------------------------------------

func _k() -> Kaisua:
	return main.mokki.kaisua


func _g(local: Vector3) -> Vector3:
	return main.mokki.to_global(local)


## Paikallinen piste maan pinnalla (+ korkeus).
func _gl(x: float, z: float, up := 0.0) -> Vector3:
	return _g(Vector3(x, Mokki.mesh_h(x, z) + up, z))


func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame


func _shot(path: String, name: String) -> void:
	await Kuva.piirto()
	await Kuva.piirto()
	var p := path.replace(".png", "_%s.png" % name)
	Kuva.ruutu(main.get_viewport()).save_png(p)
	print("KAISUA kuva ", p)


## Paikallisen pisteen (esim. koneen paikka) viereinen kohta: x/z siirtymä, y = korkeus maasta (_look).
func _at(base: Vector3, off: Vector3) -> Vector3:
	return Vector3(base.x + off.x, off.y, base.z + off.z)


## Vapaa kamera paikallisesta pisteestä kohteeseen (y = korkeus maasta).
func _look(eye: Vector3, target: Vector3) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.far = 2500.0
		_cam.fov = 60.0
		main.add_child(_cam)
	_cam.current = true
	_cam.global_position = _gl(eye.x, eye.z, eye.y)
	_cam.look_at(_gl(target.x, target.z, target.y))


func _summary(tag: String) -> void:
	var k := _k()
	for p in k.pellot:
		var pe = p
		var c: Dictionary = pe.counts
		print("KAISUA %s %s: %.2f ha, tilat %s, seuraava %s" % [tag, pe.field_name(), pe.area / 10000.0, c, k._next_job(pe)])
	print("KAISUA %s rahaa %.2f, ansiot %.2f, paaleja %d (ladossa %d), säiliö %d kg, kärry %d kg, kuivuri %d kg, siemen %.2f, maksettu %s" % [tag,
		main.money, k.tila.earned, k.tila.bales.size(), k.tila.bales_in_lato(), roundi(k.puimuri.tank), roundi(k.tila.trailer),
		roundi(k.tila.dried), k.tila.seed, k.tila.paid])


## Pellon kaistat (paikallinen, kaistan suunta dir): palauttaa [[alku, loppu], ...] pellon sisällä, väli step.
func _lanes(pe, dir: Vector2, step: float, margin := 1.0) -> Array:
	var out := []
	var right := Vector2(-dir.y, dir.x)
	var c: Vector2 = pe.center
	var reach := int(maxf(pe.nx, pe.nz) * 0.5 * 0.5 / step) + 2  # puolet pellon suorakaiteen pidemmästä sivusta
	var tr := int(maxf(pe.nx, pe.nz) * 0.5) + 4  # 0,5 m askelin
	for s in range(-reach, reach + 1):
		var off := c + right * (s * step)
		var a := Vector2.INF
		var b := Vector2.INF
		for t in range(-tr, tr + 1):
			var q := off + dir * (t * 0.5)
			if pe.has_point(q):
				if a == Vector2.INF:
					a = q
				b = q
		if a != Vector2.INF and a.distance_to(b) > 2.0:
			out.append([a - dir * margin, b + dir * margin])
	return out


## Simuloi työn kaistaa pitkin 0,4 m askelin (mover = kone, jonka paikka seuraa: paalaimen paalit putoavat kaistalle).
func _sim_lane(op: String, a: Vector2, b: Vector2, hw: float, hl: float, mover: Node3D = null, mover_back := 0.0) -> void:
	var k := _k()
	var d := b - a
	var n := maxi(1, int(d.length() / 0.4))
	var f := d.normalized()
	for i in n + 1:
		var c := a + d * (float(i) / n)
		if mover != null:
			var mp := c - f * mover_back
			mover.global_position = _gl(mp.x, mp.y)
			mover.global_rotation = Vector3(0, main.mokki.global_rotation.y + atan2(-f.x, -f.y), 0)
		k._apply_work(op, c, f, hw, hl)


## Ajaa koneen autopilotilla pisteeseen (paikallinen), ohjaus kohti 4 m edellä olevaa kohtaa. Palauttaa ajetun ajan.
func _drive(v: CharacterBody3D, a: Vector2, b: Vector2, throttle := 1.0, max_t := 90.0) -> float:
	var t := 0.0
	var f := (b - a).normalized()
	while t < max_t:
		await main.get_tree().physics_frame
		t += 1.0 / 60.0
		var lp: Vector3 = main.mokki.to_local(v.global_position)
		var p := Vector2(lp.x, lp.z)
		if (b - p).dot(f) < 1.0:
			break
		var along := (p - a).dot(f)
		var goal := a + f * (along + 5.0)
		var to := (goal - p).normalized()
		var fw3: Vector3 = main.mokki.global_transform.basis.inverse() * (-v.global_transform.basis.z)
		var fw := Vector2(fw3.x, fw3.z).normalized()
		var ang := fw.angle_to(to)  # + = vasemmalle (z etelään, x itään: angle_to myötäpäivään)
		v.autopilot = Vector2(throttle, clampf(-ang * 2.5, -1.0, 1.0))
		if int(t * 60.0) % 300 == 0:
			print("KAISUA ajo t=%.0f s paikka (%.1f, %.1f) vauhti %.2f m/s, kulma %.2f, seinä %s, lattia %s" % [t, p.x, p.y, v.speed, ang, v.is_on_wall(), v.is_on_floor()])
	v.autopilot = Vector2(0, 0)
	for i in 30:
		await main.get_tree().physics_frame
	return t


func _place_vehicle(v: CharacterBody3D, at: Vector2, dir: Vector2) -> void:
	v.global_position = _gl(at.x, at.y, 0.3)
	v.global_rotation = Vector3(0, main.mokki.global_rotation.y + atan2(-dir.x, -dir.y), 0)
	v.velocity = Vector3.ZERO
	v.speed = 0.0
	if v.driven:
		v.activate_camera()  # kamera kiinni koneeseen siirron jälkeen
	for i in 20:
		await main.get_tree().physics_frame


func _mount(v: CharacterBody3D) -> void:
	main._kaisua_logic()  # signaalit kytketään ensimmäisellä kutsulla
	_k()._mount(v)
	await _frames(3)


# --- Yleiskuvat ----------------------------------------------------------------------------------------------------

func _yleiskuvat(path: String) -> void:
	var k := _k()
	print("KAISUA peltoja %d, paaleja %d, rakennettu %d ms: %s" % [k.pellot.size(), k.tila.bales.size(), k.build_ms, k.build_laps])
	for p in k.pellot:
		print("KAISUA rakennus %s (%d x %d ruutua): %s" % [p.field_name(), p.nx, p.nz, p.laps])
	_summary("alku")
	main._hud.visible = false
	var y := Kaisua.YARD
	var shots := [
		["ylhaalta", Vector3(-213, 70, 175), Vector3(-213, 0, 122)],
		["piha", Vector3(-235, 6, 100), Vector3(-205, 1, 128)],
		["konevaja", Vector3(-214, 3.5, 120), Vector3(-194, 1, 127)],
		["lato_kuivuri", Vector3(-196, 4, 112), Vector3(-226, 2, 136)],
		["puimuri", Vector3(-218, 3, 102), Vector3(-226, 1.5, 109)],
		["kyltti", Vector3(-227, 2, 92), Vector3(-233.5, 1.3, 98.5)],
		["kotipelto", Vector3(-185, 8, 105), Vector3(-130, 0, 50)],
		["tienvarsi", Vector3(-245, 8, 120), Vector3(-300, 0, 160)],
		["isopelto", Vector3(-260, 25, 60), Vector3(-420, 0, 40)],
	]
	for s in shots:
		_look(s[1], s[2])
		await _frames(40)
		await _shot(path, s[0])
	# Lähikuvat: traktori, työkoneet, isäntä.
	var t: Vector3 = main.mokki.to_local(k.traktori.global_position)
	_look(_at(t, Vector3(-4.5, 1.8, -3.0)), _at(t, Vector3(0, 1.0, -0.8)))
	await _frames(20)
	await _shot(path, "traktori")
	_look(_at(t, Vector3(4.0, 1.6, 2.5)), _at(t, Vector3(0, 1.0, -0.5)))
	await _frames(10)
	await _shot(path, "traktori_taka")
	for id in ["niittokone", "karhotin", "aura", "aes", "kylvokone", "paalain", "perakarry"]:
		var r: Vector3 = main.mokki.to_local(k.koneet[id].root.global_position)
		var size: float = 3.5 if id in ["paalain", "perakarry", "karhotin"] else 3.0
		_look(_at(r, Vector3(-size * 1.6, size * 0.8, -size * 0.9)), _at(r, Vector3(size * 0.4, 0.6, size * 0.1)))
		await _frames(10)
		await _shot(path, "kone_" + id)
	# Kuski ratissa: jalat astinlaudoilla (edestä, sivulta ja ylhäältä), puimurin kuski tasanteella.
	await _mount(k.traktori)
	for v in [["kuski_edesta", Vector3(0.0, 1.6, -3.2)], ["kuski_sivulta", Vector3(-2.6, 1.5, -0.2)], ["kuski_ylhaalta", Vector3(-0.4, 3.4, 0.6)],
			["kuski_ratti", Vector3(-1.3, 1.75, 0.35)]]:
		var tb: Transform3D = k.traktori.global_transform
		_cam.current = true
		_cam.global_position = tb * v[1]
		_cam.look_at(tb * Vector3(0, 1.15, -0.1))
		await _frames(6)
		await _shot(path, v[0])
	await _steer_gap(k.traktori, "traktori", Koneet.T_WHEEL, Koneet.T_WHEEL_TILT, Koneet.T_COLUMN)
	var tb2: Transform3D = k.traktori.global_transform
	_cam.global_position = tb2 * (Koneet.T_WHEEL + Vector3(-1.5, 0.05, 0.05))
	_cam.look_at(tb2 * Koneet.T_WHEEL)
	await _frames(4)
	await _shot(path, "ratti_sivu_traktori")
	k._dismount(k.traktori)
	await _mount(k.puimuri)
	var cb2: Transform3D = k.puimuri.global_transform
	_cam.current = true
	_cam.global_position = cb2 * Vector3(-2.8, 3.4, -2.6)
	_cam.look_at(cb2 * Vector3(0, 2.6, -0.7))
	await _frames(6)
	await _shot(path, "puimurin_kuski")
	_cam.global_position = cb2 * (Koneet.C_WHEEL + Vector3(-1.6, 0.05, 0.05))
	_cam.look_at(cb2 * Koneet.C_WHEEL)
	await _frames(4)
	await _shot(path, "puimurin_ratti")
	# Ratin pinta kohtisuoraan ohjausakseliin ja kuljettajaa kohti (normaali +Z), molemmissa koneissa.
	for w in [["traktori", Koneet.T_COLUMN, Koneet.T_WHEEL, Koneet.T_WHEEL_TILT], ["puimuri", Koneet.C_COLUMN, Koneet.C_WHEEL, Koneet.C_WHEEL_TILT]]:
		var wn: Vector3 = Basis(Vector3.RIGHT, w[3]) * Vector3.UP
		var col: Vector3 = (w[2] - w[1]).normalized()
		print("KAISUA %s ratin normaali %s, akseli %s, pistetulo %.3f" % [w[0], wn, col, wn.dot(col)])
		if wn.dot(col) < 0.95 or wn.z <= 0.0:
			print("TESTI VIKA %s: ratti ei ole kohtisuorassa akseliin tai ei käänny kuljettajaa kohti" % w[0])
	await _steer_gap(k.puimuri, "puimuri", Koneet.C_WHEEL, Koneet.C_WHEEL_TILT, Koneet.C_COLUMN)
	# Pään laki (Head-luu + 0,24 m pää ja lippis) aurinkokatoksen alapinnan alla?
	var drv: Node3D = k.puimuri._driver
	var head_g: Vector3 = drv.to_global(drv.bone_position("Head"))
	var head_top: float = k.puimuri._visual.to_local(head_g).y + 0.24
	var rako := Koneet.C_ROOF_Y - head_top
	print("KAISUA puimurin kuskin pään laki %.2f m, katos %.2f m, rako %.2f m" % [head_top, Koneet.C_ROOF_Y, rako])
	if rako < 0.05:
		print("TESTI VIKA puimurin kuskin pää osuu aurinkokatokseen (rako %.2f m)" % rako)
	k._dismount(k.puimuri)
	var ip: Vector3 = k.isanta.position
	_look(_at(ip, Vector3(-2.4, 1.6, -1.2)), _at(ip, Vector3(0, 1.2, 0)))
	k.say("No terve! Santun mökiltä?", 5.0)
	await _frames(10)
	await _shot(path, "isanta")
	# Jalan isännän luo: vihje.
	_cam.current = false
	main.walker_out.global_position = _g(ip + Vector3(-1.5, 0.5, 0))
	main._set_avatar(main.walker_out)
	await _frames(20)
	print("KAISUA vihje isännällä: ", main._hint.text)
	await _shot(path, "jalan")


# --- Heinä ---------------------------------------------------------------------------------------------------------

func _heina(path: String) -> void:
	var k := _k()
	var pe = k._pelto(0)  # Kotipelto
	var start_money: float = main.money
	print("KAISUA rakennettu %d ms: %s" % [k.build_ms, k.build_laps])
	for p in k.pellot:
		print("KAISUA rakennus %s (%d x %d ruutua): %s" % [p.field_name(), p.nx, p.nz, p.laps])
	await _mount(k.traktori)
	print("KAISUA ratissa: %s" % (main.player == k.traktori))
	k._hitch_now("niittokone")
	var lanes := _lanes(pe, Vector2(1, 0), 3.4)
	print("KAISUA Kotipelto kaistoja %d" % lanes.size())
	var mid: Array = lanes[lanes.size() / 2]
	await _place_vehicle(k.traktori, mid[0] + Vector2(2, 0), Vector2(1, 0))
	k.traktori.set_working(true)
	var tt := await _drive(k.traktori, mid[0] + Vector2(2, 0), (mid[0] + mid[1]) / 2.0)
	print("KAISUA niitto ajettu %.1f s, niitetty %d ruutua" % [tt, int(pe.counts.get(Tila.H_NIITETTY, 0))])
	main._hud.visible = true
	await _shot(path, "niitto_ajo")
	main._hud.visible = false
	var tp: Vector3 = main.mokki.to_local(k.traktori.global_position)
	_look(_at(tp, Vector3(-3, 2.2, 6)), _at(tp, Vector3(1.5, 0.3, -1)))
	await _frames(5)
	await _shot(path, "niitto_lahi")
	_look(_at(tp, Vector3(-12, 7, 10)), _at(tp, Vector3(8, 0, -2)))
	await _frames(5)
	await _shot(path, "niitto_jalki")
	# Loppu niitto simuloiden.
	for l in lanes:
		_sim_lane("niitto", l[0], l[1], 1.75, 0.35)
	k._check_jobs()
	_summary("niitetty")
	# Karhous: karhotin perään, yksi kaista ajaen, loput simuloiden 6 m välein.
	k.traktori.set_working(false)
	k._unhitch()
	k._hitch_now("karhotin")
	var rl := _lanes(pe, Vector2(0, 1), 6.0)
	var r_mid: Array = rl[rl.size() / 2]
	await _place_vehicle(k.traktori, r_mid[0] + Vector2(0, 2), Vector2(0, 1))
	k.traktori.set_working(true)
	await _drive(k.traktori, r_mid[0] + Vector2(0, 2), (r_mid[0] + r_mid[1]) / 2.0)
	await _shot(path, "karhous_ajo")
	for l in rl:
		_sim_lane("karhous", l[0], l[1], 3.0, 1.2)
	k._check_jobs()
	_summary("karhottu")
	tp = main.mokki.to_local(k.traktori.global_position)
	_look(_at(tp, Vector3(-14, 9, 8)), _at(tp, Vector3(0, 0, -8)))
	await _frames(5)
	await _shot(path, "karhot")
	# Paalaus: paalain perään, kammio lähes täynnä, yksi karho ajaen (paali putoaa), loput simuloiden.
	k.traktori.set_working(false)
	k._unhitch()
	await _place_vehicle(k.traktori, r_mid[0] + Vector2(0, 1), Vector2(0, 1))
	k._hitch_now("paalain")
	k.tila.baler_hay = Tila.BALE_HAY - 300.0
	k.traktori.set_working(true)
	await _drive(k.traktori, r_mid[0] + Vector2(0, 1), (r_mid[0] + r_mid[1]) / 2.0 + Vector2(0, 10))
	await _frames(40)
	print("KAISUA paaleja ajon jälkeen %d" % k.tila.bales.size())
	await _shot(path, "paalaus_ajo")
	k.traktori.set_working(false)
	k._unhitch()
	var baler: Node3D = k.koneet.paalain.root
	for l in rl:
		_sim_lane("paalaus", l[0], l[1], 0.95, 0.35, baler, -1.95)
	await _frames(60)
	k._check_jobs()
	_summary("paalattu")
	_look(Vector3(pe.center.x - 30, 22, pe.center.y + 40), Vector3(pe.center.x, 0, pe.center.y))
	await _frames(20)
	await _shot(path, "paalit_pellolla")
	# Paalit latoon piikillä: yksi ajaen ladon ovelle, loput suoraan.
	var free: Array = []
	for i in k.tila.bales.size():
		if not k.tila.bales[i].lato:
			free.append(i)
	if not free.is_empty():
		var bn: Node3D = k.bale_nodes[free[0]]
		var blp: Vector3 = main.mokki.to_local(bn.global_position)
		await _place_vehicle(k.traktori, Vector2(blp.x, blp.z) + Vector2(0, 5), Vector2(0, -1))
		print("KAISUA piikki paalin luona: %s" % (k._bale_near(k.traktori.spear_point(), 2.5) >= 0))
		k.traktori.take_bale(bn)
		await _frames(30)
		tp = main.mokki.to_local(k.traktori.global_position)
		_look(_at(tp, Vector3(5, 2.5, -2)), _at(tp, Vector3(0, 1.0, -2.5)))
		await _frames(5)
		await _shot(path, "paali_piikissa")
		var door: Vector3 = main.mokki.to_local(k._lato.root.to_global(k._lato.door))
		await _place_vehicle(k.traktori, Vector2(door.x, door.z) + Vector2(0, -6), Vector2(0, 1))
		print("KAISUA ladon ovella vihje: %s" % k._tractor_logic(false, false, false).replace("\n", " | "))
		k._bale_to_lato()
		await _frames(30)
	for i in free.slice(1):
		k.traktori.take_bale(k.bale_nodes[i])
		await _frames(2)
		k._bale_to_lato()
		await _frames(2)
	await _frames(60)
	k._check_jobs()
	_summary("latoon")
	var lr: Vector3 = main.mokki.to_local(k._lato.root.global_position)
	_look(_at(lr, Vector3(-3, 3.5, -12)), _at(lr, Vector3(0, 1.5, 0)))
	await _frames(10)
	await _shot(path, "lato_paalit")
	# Naapurin paalitilaus: isäntä välittää, paalit ladosta piikillä paalipaikalle.
	k.day = main.day
	k._talk()
	print("KAISUA tilaus %d paalia, isäntä: %s" % [k.tila.order_total, k._bubble.text])
	var drop2 := Vector2(Kaisua.DROP.x, Kaisua.DROP.z)
	for d in k.tila.order_total:
		var door3: Vector3 = main.mokki.to_local(k._lato.root.to_global(k._lato.door))
		await _place_vehicle(k.traktori, Vector2(door3.x, door3.z) + Vector2(0, -6), Vector2(0, 1))
		if d == 0:
			print("KAISUA ladon ovella ilman paalia: %s" % k._tractor_logic(false, false, false))
		k._bale_from_lato()
		await _frames(20)
		await _place_vehicle(k.traktori, drop2 + Vector2(0, 5.5), Vector2(0, -1))
		if d == 0:
			print("KAISUA paalipaikalla: %s" % k._tractor_logic(false, false, false))
		k._deliver_bale()
		await _frames(30)
	_look(Vector3(Kaisua.DROP.x - 7, 3, Kaisua.DROP.z + 7), Vector3(Kaisua.DROP.x, 0.8, Kaisua.DROP.z - 1))
	await _frames(10)
	await _shot(path, "paalit_raijalle")
	print("KAISUA tilaus jäljellä %d, ladossa %d, rahaa %.2f" % [k.tila.order_left, k.tila.bales_in_lato(), main.money])
	# Diesel loppuu: moottori sammuu, kanisteri säiliöltä ja kaato tankkiin, tankkaus säiliöllä.
	k.traktori.fuel = 0.0
	print("KAISUA diesel loppu: %s" % k._tractor_logic(false, false, false))
	k._dismount(k.traktori)
	var dl: Vector3 = k._diesel.position
	main.walker_out.global_position = _gl(dl.x - 1.2, dl.z - 1.0, 0.5)
	await _frames(5)
	print("KAISUA säiliöllä: %s" % k._diesel_walk_logic(main.walker_out, main.mokki.to_local(main.walker_out.global_position), false))
	k._diesel_walk_logic(main.walker_out, main.mokki.to_local(main.walker_out.global_position), true)
	var tside: Vector3 = k.traktori.global_transform.basis.x * -2.6
	main.walker_out.global_position = k.traktori.global_position + tside + Vector3.UP * 0.5
	await _frames(5)
	var wl: Vector3 = main.mokki.to_local(main.walker_out.global_position)
	var away: Vector3 = main.mokki.global_transform.basis.inverse() * tside.normalized()
	_look(_at(wl, Vector3(away.x * 3.0 + 1.0, 1.7, away.z * 3.0 + 1.0)), _at(wl, Vector3(0, 0.8, 0)))
	await _frames(5)
	await _shot(path, "kanisteri")
	k._diesel_walk_logic(main.walker_out, main.mokki.to_local(main.walker_out.global_position), true)
	print("KAISUA kanisterin jälkeen diesel %d %%" % roundi(k.traktori.fuel * 100.0))
	_look(Vector3(dl.x - 4, 2.2, dl.z - 3.5), Vector3(dl.x, 1.0, dl.z))
	await _frames(5)
	await _shot(path, "dieselsailio")
	# Talkooruoka ja saunakaljat.
	var beers0: int = main.beers
	k.day = main.day
	k._eat()
	print("KAISUA ruoka: kaljoja %d -> %d, rahaa %.2f -> %.2f, legendat %s" % [beers0, main.beers, start_money, main.money, k.tila.legends])
	# Päivä vaihtuu: nurmi kasvaa takaisin ja kierros alkaa alusta.
	for d in 3:
		k.advance_day(main.day + 1 + d)
		k._check_jobs()
	_summary("kasvanut")


# --- Vilja ---------------------------------------------------------------------------------------------------------

func _vilja(path: String) -> void:
	var k := _k()
	var tv = k._pelto(1)  # Tienvarsipelto
	var iso = k._pelto(2)  # Isopelto
	await _mount(k.puimuri)
	var lanes := _lanes(tv, Vector2(0, 1), 4.0)
	print("KAISUA Tienvarsi kaistoja %d" % lanes.size())
	var mid: Array = lanes[lanes.size() / 2]
	await _place_vehicle(k.puimuri, mid[0] + Vector2(0, 3), Vector2(0, 1))
	k.puimuri.set_working(true)
	var tt := await _drive(k.puimuri, mid[0] + Vector2(0, 3), (mid[0] + mid[1]) / 2.0)
	print("KAISUA puinti ajettu %.1f s, säiliö %d kg" % [tt, roundi(k.puimuri.tank)])
	main._hud.visible = true
	await _shot(path, "puinti_ajo")
	main._hud.visible = false
	var cp: Vector3 = main.mokki.to_local(k.puimuri.global_position)
	_look(_at(cp, Vector3(-9, 4, -9)), _at(cp, Vector3(0, 1.2, -1)))
	await _frames(5)
	await _shot(path, "puinti_edesta")
	_look(_at(cp, Vector3(5, 5, 14)), _at(cp, Vector3(0, 0.5, 0)))
	await _frames(5)
	await _shot(path, "puinti_jalki")
	# Purku kärryyn: kärry puimurin vasemmalle puolelle.
	var kr: Node3D = k.koneet.perakarry.root
	var cb := k.puimuri.global_transform.basis
	kr.global_position = k.puimuri.global_position + cb * Vector3(-4.3, 0, -1.6)
	kr.global_rotation = k.puimuri.global_rotation
	kr.global_position.y = _gl(main.mokki.to_local(kr.global_position).x, main.mokki.to_local(kr.global_position).z).y
	k.puimuri.tank = maxf(k.puimuri.tank, 900.0)
	print("KAISUA purkukohde: %s" % k._unload_target())
	k.puimuri.unloading = true
	await _frames(150)
	_look(_at(cp, Vector3(-9, 6, 8)), _at(cp, Vector3(-3, 1.5, 1)))
	await _frames(3)
	await _shot(path, "purku_karryyn")
	print("KAISUA kärryssä %d kg, säiliö %d kg" % [roundi(k.tila.trailer), roundi(k.puimuri.tank)])
	# Loppu puinti simuloiden (säiliö tyhjennetään kuivuriin aina täyttyessä).
	k.puimuri.unloading = false
	k.puimuri.set_working(false)
	for l in lanes:
		_sim_lane("puinti", l[0], l[1], 2.1, 0.35)
		if k.puimuri.tank > 1800.0:
			k._to_dryer(k.puimuri.tank)
			k.puimuri.tank = 0.0
	k._to_dryer(k.puimuri.tank)
	k.puimuri.tank = 0.0
	k.tila.tank = 0.0
	k._check_jobs()
	_summary("puitu")
	# Kärry kuivurin suppilolle ja kippaus.
	var pit: Vector3 = k._kuivuri.root.to_global(k._kuivuri.pit)
	var pl: Vector3 = main.mokki.to_local(pit)
	# Kärry peruutettu suppilolle: aisa itään (kohti pihaa), lava länteen, takaluukku suppilon päällä.
	kr.global_rotation = Vector3(0, main.mokki.global_rotation.y + atan2(-1.0, 0.0), 0)
	var hitch := Vector2(pl.x, pl.z) + Vector2(6.2, 0)
	kr.global_position = _gl(hitch.x, hitch.y)
	print("KAISUA kärry suppilolla: %s" % k._trailer_at_pit())
	k._tip_on = true
	await _frames(120)
	_look(_at(pl, Vector3(6, 4, -8)), _at(pl, Vector3(3, 1.0, 0)))
	await _frames(3)
	await _shot(path, "kippaus")
	await _frames(240)
	k._check_jobs()
	_summary("kuivurissa")
	# Isopelto: kyntö auralla, kivien keruu, äestys ja kylvö traktorilla.
	main._kaisua_dismount(k.puimuri, main.walker_out.global_position)
	k.puimuri.set_driven(false)
	await _mount(k.traktori)
	var il := _lanes(iso, Vector2(1, 0), 4.4)
	print("KAISUA Isopelto kaistoja %d" % il.size())
	var im: Array = il[il.size() / 2]
	k._hitch_now("aura")
	# Äes sänkeen ennen kyntöä: ei pure (viesti).
	print("KAISUA äes sänkeen: %s" % k._apply_work("aestys", im[0] + Vector2(10, 0), Vector2(1, 0), 2.25, 0.8))
	await _place_vehicle(k.traktori, im[0] + Vector2(2, 0), Vector2(1, 0))
	k.traktori.set_working(true)
	await _drive(k.traktori, im[0] + Vector2(2, 0), im[0] + Vector2(30, 0))
	main._hud.visible = true
	await _shot(path, "kynto_ajo")
	main._hud.visible = false
	var kp: Vector3 = main.mokki.to_local(k.traktori.global_position)
	_look(_at(kp, Vector3(-3.5, 1.6, 3.5)), _at(kp, Vector3(0.5, 0.2, 1.8)))
	await _frames(5)
	await _shot(path, "kynto_lahi")
	var kl := _lanes(iso, Vector2(1, 0), 3.0)
	for l in kl:
		_sim_lane("kynto", l[0], l[1], 1.5, 0.6)
	k.traktori.set_working(false)
	k._check_jobs()
	_summary("kynnetty")
	print("KAISUA kiviä pellolla %d" % k.tila.stones_left(iso.index))
	# Kivet: jalan yksi kivi syliin ja kärryyn, kärry kivikasalle ja kippaus, loput suoraan kasaan.
	k._unhitch()
	main._kaisua_dismount(k.traktori, main.walker_out.global_position)
	k.traktori.set_driven(false)
	var si := -1
	for i in k.tila.stones.size():
		if int(k.tila.stones[i].field) == iso.index and k.tila.stones[i].where == "pelto":
			si = i
			break
	if si >= 0:
		var sp: Vector3 = k.tila.stones[si].pos
		_look(Vector3(sp.x - 8, 5, sp.z + 6), Vector3(sp.x, 0, sp.z))
		await _frames(10)
		await _shot(path, "kivet_pellolla")
		main.walker_out.global_position = _gl(sp.x + 0.8, sp.z, 0.5)
		_cam.current = false
		main._set_avatar(main.walker_out)
		await _frames(10)
		print("KAISUA kiven luona: %s" % k._stone_logic(main.walker_out, main.mokki.to_local(main.walker_out.global_position), false))
		k._stone_logic(main.walker_out, main.mokki.to_local(main.walker_out.global_position), true)
		await _frames(10)
		var wp: Vector3 = main.mokki.to_local(main.walker_out.global_position)
		_look(_at(wp, Vector3(-2.2, 1.5, -1.6)), _at(wp, Vector3(0, 1.0, 0)))
		await _frames(5)
		await _shot(path, "kivi_sylissa")
		kr.global_rotation = Vector3(0, main.mokki.global_rotation.y, 0)
		kr.global_position = _gl(wp.x + 1.6, wp.z - 3.8)
		await _frames(3)
		print("KAISUA kärryn luona: %s" % k._stone_logic(main.walker_out, wp, false))
		k._stone_logic(main.walker_out, wp, true)
		await _frames(20)
		print("KAISUA kärryssä kiviä %d" % k._trailer_stones())
		# Loput saman alueen kivet kärryyn ja kärry kasalle kipattavaksi.
		var moved := 0
		for i in k.tila.stones.size():
			if moved >= 9:
				break
			if int(k.tila.stones[i].field) == iso.index and k.tila.stones[i].where == "pelto":
				k.tila.stones[i].where = "karry"
				k._place_stone(i, k.stone_nodes[i])
				moved += 1
		_look(_at(wp, Vector3(-4, 3, -1)), _at(wp, Vector3(1.6, 0.8, -1.5)))
		await _frames(5)
		await _shot(path, "kivet_karryssa")
		var kasa: Vector3 = k._kasa_pos(iso.index)
		kr.global_rotation = Vector3(0, main.mokki.global_rotation.y, 0)
		kr.global_position = _gl(kasa.x, kasa.z - 7.0)
		await _frames(3)
		print("KAISUA kärry kasalla: %d" % k._trailer_at_kasa())
		k._tip_stones(k._trailer_at_kasa())
		await _frames(90)
		_look(Vector3(kasa.x - 6, 3.5, kasa.z - 6), Vector3(kasa.x, 0.3, kasa.z))
		await _frames(5)
		await _shot(path, "kivikasa")
	for i in k.tila.stones.size():
		if int(k.tila.stones[i].field) == iso.index and k.tila.stones[i].where == "pelto":
			k.tila.stones[i].where = "kasa"
	k._check_jobs()
	_summary("kivet")
	await _mount(k.traktori)
	k._hitch_now("aes")
	await _place_vehicle(k.traktori, im[0] + Vector2(2, 0), Vector2(1, 0))
	k.traktori.set_working(true)
	await _drive(k.traktori, im[0] + Vector2(2, 0), im[0] + Vector2(30, 0))
	main._hud.visible = true
	await _shot(path, "aestys_ajo")
	main._hud.visible = false
	for l in il:
		_sim_lane("aestys", l[0], l[1], 2.25, 0.8)
	k._check_jobs()
	k.traktori.set_working(false)
	k._unhitch()
	k._hitch_now("kylvokone")
	await _place_vehicle(k.traktori, im[0] + Vector2(2, -4), Vector2(1, 0))
	k.traktori.set_working(true)
	await _drive(k.traktori, im[0] + Vector2(2, -4), im[0] + Vector2(30, -4))
	var ip: Vector3 = main.mokki.to_local(k.traktori.global_position)
	_look(_at(ip, Vector3(-10, 4, 7)), _at(ip, Vector3(0, 0.5, 0)))
	await _frames(5)
	await _shot(path, "kylvo_ajo")
	for l in _lanes(iso, Vector2(1, 0), 3.9):  # 4 m kylvökone, kaistat limittäin
		_sim_lane("kylvo", l[0], l[1], 2.0, 0.45)
		if k.tila.seed < 0.2:
			k.tila.seed = 1.0  # täyttö säkeistä
	k._check_jobs()
	_summary("kylvetty")
	k.traktori.set_working(false)
	var view_e := Vector3(iso.center.x + 60, 14, iso.center.y + 20)
	var view_t := Vector3(iso.center.x + 20, 0, iso.center.y)
	_look(view_e, view_t)
	await _frames(30)
	await _shot(path, "isopelto_kylvetty")
	var names := ["oras", "vihrea", "kypsa"]
	for d in 3:
		k.advance_day(main.day + 1 + d)
		await _frames(10)
		_look(Vector3(ip.x - 6, 1.6, ip.z + 6), Vector3(ip.x + 4, 0.2, ip.z - 2))
		await _frames(10)
		await _shot(path, "kasvu_" + names[d])
	k._check_jobs()
	_summary("kasvanut")


# --- Kivet lähikuvissa -------------------------------------------------------------------------------------------

## Kiviä Tienvarsipellon reunaan eri kokoina, vanha kivikasa ja kivi pelaajan kädessä (nopea kuvatarkistus).
func _kivet(path: String) -> void:
	var k := _k()
	var tv = k._pelto(1)
	var c: Vector2 = tv.center
	for z in range(-6, 8, 2):  # kynnetty kaista: kivet nousevat vain kynnetylle
		tv.work("puinti", c + Vector2(0, z), Vector2(1, 0), 1.5, 8.0)
		tv.work("kynto", c + Vector2(0, z), Vector2(1, 0), 1.5, 8.0)
	for i in 8:
		k._add_stone(c + Vector2(-3.0 + i * 0.9, (i % 3) * 0.7), tv.index)
	main._hud.visible = false
	_look(Vector3(c.x - 1.0, 1.6, c.y + 3.5), Vector3(c.x, 0.1, c.y + 0.5))
	await _frames(30)
	await _shot(path, "kivet_lahi")
	var kasa: Vector3 = k._kasa_pos(tv.index)
	_look(Vector3(kasa.x - 4, 2.4, kasa.z - 3), Vector3(kasa.x, 0.3, kasa.z))
	await _frames(10)
	await _shot(path, "vanha_kasa")
	main.walker_out.global_position = _gl(c.x - 3.0 + 0.6, c.y, 0.5)
	main.walker_out.visible = true  # kohtaus alkaa mökin sisältä: kävelijä näkyviin
	_cam.current = false
	main._set_avatar(main.walker_out)
	await _frames(10)
	var wp: Vector3 = main.mokki.to_local(main.walker_out.global_position)
	k._stone_logic(main.walker_out, wp, true)
	await _frames(10)
	_look(_at(wp, Vector3(1.6, 1.5, -1.8)), _at(wp, Vector3(0, 1.0, 0)))
	await _frames(5)
	await _shot(path, "kivi_kadessa")
	print("KAISUA kivi kädessä: %s" % k._stone_logic(main.walker_out, wp, false))


## Kuskin vartalon, reisien ja säärten pinnan (paistettu verkko, paidan pöyhennys mukana) etäisyys ratin kehään ja
## ohjausakseliin koneen kehyksessä. Kädet ja kyynärvarret saavat koskea rattia, joten ne eivät ole mukana.
func _steer_gap(v: CharacterBody3D, name: String, wc: Vector3, tilt: float, col: Vector3) -> void:
	await _frames(3)
	var drv: Node3D = v._driver
	var vis: Node3D = v._visual
	var pts := Pose.limb_points(drv, vis, ["pelvis", "spine_01", "spine_02", "spine_03", "thigh_l", "thigh_r", "calf_l", "calf_r"], 1, null, null, true)
	if pts.is_empty():
		print("KAISUA %s ratin rako: ei tarkistettu (ei näyttöä)" % name)
		return
	var b := Basis(Vector3.RIGHT, tilt)
	var nrm := b * Vector3.UP
	var best := INF
	var where := ""
	var worst := Vector3.ZERO
	for p in pts:
		# Kehä: ympyrä (säde 0,185) ratin tasossa, putken säde 0,015.
		var rel := p - wc
		var inplane := rel - nrm * rel.dot(nrm)
		var on_ring := wc + inplane.normalized() * 0.185 if inplane.length() > 0.001 else wc + b * Vector3(0.185, 0, 0)
		var d := p.distance_to(on_ring) - 0.015
		if d < best:
			best = d
			where = "kehä"
			worst = p
		var q := Geometry3D.get_closest_point_to_segment(p, col, wc)
		var d2 := p.distance_to(q) - 0.025
		if d2 < best:
			best = d2
			where = "akseli"
			worst = p
	print("KAISUA %s ratin rako kuskiin %.3f m (%s, lähin kuskin piste %s, %d pistettä)" % [name, best, where, worst, pts.size()])
	# Puimurin loivan ratin lähireuna hipaisee kuskin mahaa alle sentin: hyväksytty (käyttäjän päätös), raja 1,5 cm.
	var allow := 0.015 if name == "puimuri" else 0.0
	if best < -allow:
		print("TESTI VIKA %s: kuski menee ratin %s läpi (%.3f m)" % [name, where, best])
