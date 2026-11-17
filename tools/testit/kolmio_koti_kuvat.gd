extends "res://tools/testit/kolmio_kuvat.gd"
## Luku 6 "Päivi epäilee" (#326, erä E1) kuvina: Sytkärin mätsi "Kesäheila -96, Saloinen" (kortti, mätsi, matka ja
## profiilikuva täysikokoisena), kodin ovikohtaus (Päivi kerma- ja mansikkalaatikko kädessä, Sinikka nauraa eteisessä)
## edestä, sivulta ja ylhäältä, laatikon pitely lähikuvina sekä aamu Päivin keittiössä. Otteen rako (_rako), kädet
## vartalosta (_kasi_vartaloon) ja läpimenot (Asento.solids, "LÄPI … -> …" = VIKA) kuten kolmio_kuvat.gd.
## tools/testit/aja.sh tscn tools/testit/kolmio_koti_kuvat.tscn


func _run() -> void:
	out = out.replace("kolmio_kuvat", "kolmio_koti_kuvat")
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().process_frame
	await _sytkari()
	await _ovi()
	var ui = _scene("aamu", "koti", func(u): u.stats = "Kulissit kunnossa")
	ui._line = 3; ui._line_t = 9.0
	await _shot(ui, "aamu_koti")
	print("KOLMIO kuvat valmis, vikoja %d" % vikoja)
	get_tree().quit()


func _sytkari() -> void:
	var info: Dictionary = Kolmio.SITES.koti
	for m in ["match", "matsi", "matka"]:
		var sy = S.new()
		sy.mode = "matka" if m == "matka" else "match"
		sy.who = info.woman; sy.age = info.age; sy.job = info.job; sy.bio = info.bio; sy.dist = "150 m"
		sy.note_from = "Esa"; sy.note = Kolmio.MEASURE_LINES.koti[0]
		root.add_child(sy)
		sy._t = 1.2 if m == "match" else 4.0
		if m == "matsi":
			sy._swiped = 1.0
		sy._rise = 1.0
		sy.set_process(false)
		sy._view.queue_redraw()
		if m == "match":
			for i in 12:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var vp: SubViewport = sy._photos[info.woman]
			vp.get_texture().get_image().save_png(out.path_join("kuva_syt_profiilikuva_koti.png"))
			print("KOLMIO otsikko: %s / %s" % [sy._title(), sy._sub()])
			if sy._title() != "Kesäheila -96, Saloinen":
				_vika("Sytkärin otsikko %s" % sy._title())
		await _shot(sy, "syt_%s_koti" % m)


## Kodin ovi: pelikamera (Päivi puhuu, Sinikka nauraa), laatikon rako ja kädet, läpimenot, sitten lähikuvat
## laatikosta edestä, sivulta ja ylhäältä sekä koko asetelma sivulta ja ylhäältä.
func _ovi() -> void:
	for li in [1, 2]:
		var ui = _scene("ovi", "koti", func(u): pass)
		ui._line = li; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
		await _shot(ui, "ovi_koti_%d" % li, li == 1)
	# Ote pitää koko ajan, kun Päivi puhuu (Idle_Talking) ja kuuntelee (Idle): rako ja läpimenot kolmessa
	# animaation vaiheessa kummallakin rivillä.
	for li in [2, 1]:
		var u2 = _scene("ovi", "koti", func(u): pass)
		u2._line = li; u2._door = 1.0; u2._door_to = 1.0; u2._line_t = 9.0
		for f in [20, 45, 70]:
			for i in (f - (0 if f == 20 else 25)):
				await get_tree().process_frame
			print("KOLMIO rivi %d ruutu %d (%s)" % [li, f, u2._people["Päivi"].get_meta("anim", "")])
			_rako_rasia(u2._people["Päivi"], u2._box)
			_lapi(u2, "koti_rivi%d_ruutu%d" % [li, f])
		u2.queue_free()
		await get_tree().process_frame
	var ui = _scene("ovi", "koti", func(u): pass)
	ui._line = 1; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
	for i in 12:
		await get_tree().process_frame
	var paivi: Node3D = ui._people["Päivi"]
	_rako_rasia(paivi, ui._box)
	_kasi_pinta(paivi)
	print("KOLMIO kermapurkin pohja marjojen päällä y %.3f, purkin alin kohta %.3f" % [ui._box.get_meta("can_floor"),
		ui._box.get_child(ui._box.get_child_count() - 1).position.y])
	_lapi(ui, "koti_pitely")
	var c: Vector3 = ui._box.global_position + Vector3(0, 0.08, 0)
	var fwd := -paivi.global_basis.z
	for v in [["edesta", fwd * 0.75 + Vector3(0, 0.12, 0)], ["sivulta", paivi.global_basis.x * 0.6 + fwd * 0.2 + Vector3(0, 0.25, 0)],
			["vasen", -paivi.global_basis.x * 0.6 + fwd * 0.2 + Vector3(0, 0.25, 0)], ["ylhaalta", fwd * 0.2 + Vector3(0, 0.55, 0)]]:
		var eye: Vector3 = c + v[1]
		ui._cam_base = Transform3D(Basis.looking_at(c - eye, Vector3.UP if v[0] != "ylhaalta" else fwd), eye)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("kuva_koti_laatikko_%s.png" % v[0]))
	# Koko asetelma sivulta (oven suunta näkyy: Päivi kynnyksellä, Sinikka eteisessä takana).
	var mid := Vector3(0.0, 1.4, -0.9)
	for v in [["sivulta", Vector3(4.2, 0.6, 0.6)], ["edesta", Vector3(0.1, 0.2, 4.2)]]:
		var eye: Vector3 = mid + v[1]
		ui._cam_base = Transform3D(Basis.looking_at(mid - eye, Vector3.UP), eye)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("kuva_koti_asetelma_%s.png" % v[0]))
	ui.queue_free()
	await get_tree().process_frame



## Rasia kämmenillä alta: käden ja sormien pinnan pisteet (Pose.limb_points) rasian kehyksessä, etumerkillinen
## etäisyys rasian umpinaiseen kappaleeseen (pohja, kaltevat kyljet). Negatiivinen = sisällä. Luittain, jotta näkyy,
## mikä osa (peukalo, sormet, kämmen) koskee tai menee läpi. Pienin rako alle RAKO_KELLUU = rasia lepää kämmenillä.
func _rako_rasia(ch: Node3D, prop: Node3D) -> void:
	for lr in ["_l", "_r"]:
		var txt := ""
		var mind := INF
		var inside := 0
		for g in ["hand", "thumb", "index", "middle", "ring", "pinky"]:
			var bones := []
			for i in ch.skeleton.get_bone_count():
				var bn: String = ch.skeleton.get_bone_name(i)
				if bn.begins_with(g) and bn.ends_with(lr):
					bones.append(bn)
			var pts := Pose.limb_points(ch, prop, bones, 1)
			if pts.is_empty():
				print("KOLMIO rako Päivi ei tarkistettu (headless)")
				return
			var gmin := INF
			for q in pts:
				var hx := Gifts.rasia_half(q.y)
				var hz := lerpf(Gifts.RASIA_ALA.y, Gifts.RASIA_YLA.y, clampf(q.y / Gifts.RASIA_H, 0.0, 1.0))
				var dx := absf(q.x) - hx
				var dz := absf(q.z) - hz
				var dy := maxf(-q.y, q.y - Gifts.RASIA_H)
				var d := 0.0
				if dx < 0.0 and dz < 0.0 and dy < 0.0:
					d = maxf(dx, maxf(dz, dy))
				else:
					d = Vector3(maxf(dx, 0.0), maxf(dy, 0.0), maxf(dz, 0.0)).length()
				gmin = minf(gmin, d)
				if d < -RAKO_SISALLA:
					inside += 1
			mind = minf(mind, gmin)
			txt += "%s %.3f  " % [g, gmin]
		print("KOLMIO rako Päivi %s: lähin %.4f m, sisällä %d pistettä; luittain %s" % [lr, mind, inside, txt])
		if inside > 0:
			_vika("Päivi %s: käsi rasian sisällä (%d pistettä, syvin %.3f m)" % [lr, inside, mind])
		elif mind > RAKO_KELLUU:
			_vika("Päivi %s: rasia ei lepää kämmenellä (lähin %.3f m)" % [lr, mind])



## Käsi vartaloon pinnasta (CLAUDE.md "Mittaa pinnasta, ei luista"): olka- ja kyynärvarren paistetun pinnan pienin
## etäisyys vartalon pintaan (pelvis..spine_03). Kolmio_kuvat.gd:n KASI_RAJA (keskilinja 25 mm) on mitoitettu miesten
## paksuille hihoille; Päivin olkavarren säde on mitattuna 18 mm, joten keskilinjan raja antaisi väärän hälytyksen.
## Pinnat erillään (yli 3 mm) = ei läpimenoa. Olkanivelen juuri (olkavarren alin 40 %) ohitetaan kuten _kasi_vartaloon.
func _kasi_pinta(ch: Node3D) -> void:
	var body := Pose.limb_points(ch, ch, ["pelvis", "spine_01", "spine_02", "spine_03"], 1)
	for lr in ["l", "r"]:
		var a0: Vector3 = ch.bone_position("upperarm_" + lr)
		var a1: Vector3 = ch.bone_position("lowerarm_" + lr)
		var ax := (a1 - a0).normalized()
		var arm := Pose.limb_points(ch, ch, ["upperarm_" + lr, "lowerarm_" + lr, "hand_" + lr], 1)
		var radii := []
		var surf := INF
		for q in arm:
			var along := (q - a0).dot(ax)
			if absf(along - 0.5 * a0.distance_to(a1)) < 0.02:
				radii.append((q - a0 - ax * along).length())
			if along < 0.4 * a0.distance_to(a1):
				continue
			for w in body:
				surf = minf(surf, q.distance_to(w))
		radii.sort()
		var rad: float = radii[radii.size() / 2] if radii.size() > 0 else 0.0
		var cl := INF  # keskilinja (vertailuksi kolmio_kuvat-rajaan)
		for st in 9:
			var p := a0.lerp(a1, 0.5 + st / 16.0)
			for w in body:
				cl = minf(cl, p.distance_to(w))
		print("KOLMIO käsi Päivi %s: pintojen pienin väli %.3f m, olkavarren säde %.3f m, keskilinja %.3f m" % [lr, surf, rad, cl])
		if surf < RAKO_SISALLA:
			_vika("Päivi %s: käsi vartalon pinnassa tai sisällä (%.3f m)" % [lr, surf])
