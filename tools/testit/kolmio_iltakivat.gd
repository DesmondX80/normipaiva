extends Node
## Iltakivat pelimaailmassa (main.gd _kolmio_kiva): lettukisa, löylykisa, Sivikki-disko ja karaoke peräkkäin Saloisten
## kohteessa, tekoäly pelaa (auto). Jokaisesta: kiva alkaa, päättyy, aamu tulee, koettu kiva kirjautuu sivutehtävään
## ("kiva_<nimi>") ja kolmiomittaus merkitään tehdyksi. Lopuksi sivutehtävän edistyminen.
## Ajo: tools/testit/aja.sh scene kolmio_iltakivat
## Kuvat: _<kiva> (kesken illan), _<kiva>_aamu.

const Kolmio := preload("res://scripts/kolmiomittaus.gd")

var main: Node3D
var vikoja := 0


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + t)


func _shot_path(suffix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			return a.substr(7).replace(".png", suffix + ".png")
	return "user://kolmio_iltakivat%s.png" % suffix


func _frames(n := 4) -> void:
	for i in n:
		if main.state == "ulkona":
			main.clock_min = 19.0 * 60.0
		await get_tree().process_frame


func _snap(suffix: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(_shot_path(suffix))
	print("ILTAKIVA kuva " + _shot_path(suffix))


func run() -> void:
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	await _frames(10)
	for kiva: String in ["lettu", "loyly", "disko", "karaoke"]:
		var s: Dictionary = main.kolmio.st("saloinen")
		s.done_day = maxi(0, main.day - 1)
		s.stage = "mittaus"
		var illat0: int = s.get("illat", 1)
		main._kolmio_kiva("saloinen", kiva)
		await _frames(30)
		var g = main._rasva_game
		if g == null:
			_vika("%s ei alkanut" % kiva)
			continue
		g.auto = true
		print("ILTAKIVA %s alkoi: %s" % [kiva, g.get_script().resource_path])
		var shot := false
		for i in 40000:
			await _frames(1)
			if not is_instance_valid(g) or main._rasva_game == null:
				break
			if not shot and g._t > 8.0 and g._phase not in ["alku", "valmis"]:
				shot = true
				await _snap("_" + kiva)
		if main._rasva_game != null:
			_vika("%s ei päättynyt" % kiva)
			continue
		for i in 300:
			await _frames(1)
			if main._kolmio_ui != null:
				break
		if main._kolmio_ui == null:
			_vika("%s: aamu ei alkanut" % kiva)
		else:
			await _frames(40)
			await _snap("_%s_aamu" % kiva)
			print("ILTAKIVA %s aamu: %s" % [kiva, main._kolmio_ui.get("stats")])
			var ui: Node = main._kolmio_ui
			ui.finished.emit({})  # kuten pelaaja jatkaisi: uusi päivä
			ui.queue_free()
			await _frames(60)
		if not ("kiva_" + kiva) in main.tilat.firsts:
			_vika("%s: kiva_%s ei kirjautunut" % [kiva, kiva])
		if int(main.kolmio.st("saloinen").get("illat", 0)) != illat0 + 1:
			_vika("%s: illat ei kasvanut" % kiva)
	var side: Array = main.journal_data().side.filter(func(q: Dictionary) -> bool: return q.id == "iltakivat")
	print("ILTAKIVA sivutehtävä %s" % [side[0].progress if not side.is_empty() else "puuttuu"])
	if side.is_empty():
		_vika("sivutehtävä iltakivat puuttuu")
	print("ILTAKIVA valmis, %d vikaa" % vikoja)
