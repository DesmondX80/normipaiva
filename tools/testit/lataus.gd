extends Node
## Latausaika: Saloinen (main.tscn -> mokki valmis) ja Vaala (_start_mopo), vaihekohtaiset luvut tulevat
## --ajastus-tulosteista (AJASTUS main/maailma, VAALA vaiheet). Tulostaa rivit "LATAUS Saloinen N ms" ja "LATAUS Vaala N ms".
## tools/testit/aja.sh --kiintea tscn tools/testit/lataus.tscn <kansio> -- --ajastus
## Tuottaa yhden kuvan (lataus.png tulostekansioon); logiikkaa varten myös `aja.sh --ei-kuvia tscn ...` käy.
## Kylmä aloitus: poista $HOME/.local/share/godot/app_userdata/Normipäivä/cache ennen ajoa (aja.sh:n HOME on eristetty).
var main: Node3D


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	load("res://scripts/main.gd").skip_menu = true
	main = load("res://main.tscn").instantiate()
	add_child(main)
	_run.call_deferred(t0)


func _run(t0: int) -> void:
	while main.get("mokki") == null and Time.get_ticks_msec() - t0 < 400000:
		await get_tree().process_frame
	print("LATAUS Saloinen %d ms" % (Time.get_ticks_msec() - t0))
	for i in 30:
		await get_tree().process_frame
	main.clock_min = 12 * 60
	var tl := Time.get_ticks_msec()
	main._ensure_mopo_trip()
	print("LATAUS Vaala _ensure_mopo_trip %d ms" % (Time.get_ticks_msec() - tl))
	var ts := Time.get_ticks_msec()
	main._start_mopo()
	print("LATAUS Vaala _start_mopo (ensure_built ym.) %d ms" % (Time.get_ticks_msec() - ts))
	ts = Time.get_ticks_msec()
	for n in 5:
		await get_tree().process_frame
	print("LATAUS Vaala 5 ruutua %d ms" % (Time.get_ticks_msec() - ts))
	if "--avaintesti" in OS.get_cmdline_user_args():
		_key_test(main.mopo_trip.vaala)
	print("LATAUS Vaala %d ms" % (Time.get_ticks_msec() - tl))
	# Yksi kuva Vaalan ensiruudusta: aja.sh vaatii kuvan (tai --ei-kuvia), ja kuva paljastaa rikkinäisen latauksen.
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(a + "/lataus.png")
			break
	get_tree().quit()


func _mask(vl: Node3D) -> int:
	vl._build_drive_mask_calc()
	return hash([hash(vl._drive), hash(vl._surf)])


## Ajomaskin välimuistiavain kattaa syötteet: muuta syötettä niin, että laskettu maski muuttuu, ja vaadi, että avain muuttuu.
## Muutokset palautetaan; lopuksi maski lasketaan uudelleen ja sen pitää olla alkuperäinen.
func _key_test(vl: Node3D) -> void:
	var key0: String = vl._drive_key()
	var mask0 := _mask(vl)
	if vl._drive_key() != key0:
		print("TESTI VIKA avain ei ole vakaa (sama syöte, eri avain)")
	var mid: Array = vl.road[vl.road.size() / 2]
	var c := Vector2(mid[0], mid[2])
	var far := c + Vector2(60, 0)
	var nbefore: Array = vl._bld_polys.duplicate()
	# [nimi, muutos, palautus]
	var tests: Array = []
	tests.append(["rakennuksen pohja tiellä", func(): vl._bld_polys.append(PackedVector2Array([c + Vector2(-8, -8), c + Vector2(8, -8), c + Vector2(8, 8), c + Vector2(-8, 8)])),
		func(): vl._bld_polys.assign(nbefore)])
	var w0: float = vl.road[vl.road.size() / 3][4]
	tests.append(["tien leveys", func(): vl.road[vl.road.size() / 3][4] = w0 + 6.0, func(): vl.road[vl.road.size() / 3][4] = w0])
	var d0: Array = vl.doors.duplicate()
	tests.append(["ovi ajettavassa paikassa", func(): vl.doors.append({"pos": Vector3(far.x, 0, far.y), "walk": false}), func(): vl.doors.assign(d0)])
	var nr0: Array = vl.north_roads.duplicate()
	if not nr0.is_empty():
		var r0: Dictionary = nr0[0]
		var half0: float = r0.half
		tests.append(["järviseudun tien leveys", func(): r0.half = half0 + 5.0, func(): r0.half = half0])
	var na0: Array = vl.north_areas.duplicate()
	tests.append(["järviseudun piha", func(): vl.north_areas.append(PackedVector2Array([far, far + Vector2(20, 0), far + Vector2(20, 20)])), func(): vl.north_areas.assign(na0)])
	var sr: Array = vl.data.side_roads
	var sdi := 0
	for i in sr.size():
		if sr[i].kind != "rail" and sr[i].pts.size() >= 2 and sr[i].name != "Vaalan tori":
			sdi = i
			break
	var sp0: Array = (sr[sdi].pts[0] as Array).duplicate()
	tests.append(["sivutien piste", func(): sr[sdi].pts[0] = [sp0[0] + 25.0, sp0[1] + 25.0], func(): sr[sdi].pts[0] = sp0])
	for nm in ["siitari_park", "kmarket_door", "atm_pos", "lava_park", "mokki_mopo", "siitari_door"]:
		var v0: Vector3 = vl.get(nm)
		tests.append(["pysäkki " + nm, func(): vl.set(nm, Vector3(far.x + 40, 0, far.y + 40)), func(): vl.set(nm, v0)])
	var y0: Array = vl._yard_lines.duplicate()
	tests.append(["pihan viivat", func(): vl._yard_lines = [[Vector2(c.x, c.y), Vector2(0, 1)]], func(): vl._yard_lines = y0])
	var pk0: Array = vl.data.parkings
	tests.append(["parkki", func(): vl.data.parkings = pk0 + [[[far.x, far.y], [far.x + 15, far.y], [far.x + 15, far.y + 15], [far.x, far.y + 15]]], func(): vl.data.parkings = pk0])
	var obs := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6, 3, 6)
	cs.shape = bs
	obs.add_child(cs)
	tests.append(["laatikkoeste tiellä", func():
			vl.add_child(obs)
			obs.position = Vector3(c.x, vl.h(c.x, c.y) + 1.0, c.y),
		func(): vl.remove_child(obs)])
	var fails := 0
	for t: Array in tests:
		(t[1] as Callable).call()
		var m := _mask(vl)
		var k: String = vl._drive_key()
		(t[2] as Callable).call()
		var changed := m != mask0
		var kchanged := k != key0
		print("AVAINTESTI %-28s maski %s, avain %s" % [t[0], "muuttui" if changed else "ei muuttunut", "muuttui" if kchanged else "ei muuttunut"])
		if changed and not kchanged:
			print("TESTI VIKA avain ei kata syötettä: " + t[0])
			fails += 1
		if not changed:
			print("  (ei vaikutusta maskiin: ei voi päätellä)")
	if vl._drive_key() != key0 or _mask(vl) != mask0:
		print("TESTI VIKA syötteiden palautus epäonnistui (avain tai maski eri kuin alussa)")
	print("AVAINTESTI valmis, vikoja %d" % fails)
