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
