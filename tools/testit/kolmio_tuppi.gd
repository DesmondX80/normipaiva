extends Node
## Räsytuppi pelimaailmassa (main.gd _kolmio_tuppi): Saloisten kohde on jo kerran tehty (done_day), joten ovelta
## lahjojen kanssa alkaa räsytuppi Rasvanapin sijaan. Tekoäly pelaa illan loppuun (tuppi_game.gd auto), sitten aamu
## naisen keittiössä, kolmiomittauksen loppu ja voitosta legendaarinen hetki "rasytuppi". K-18 pois: ei koko tuppia.
## Ajo: tools/testit/aja.sh scene kolmio_tuppi
## Kuvat: _tuppi (pelikamera olohuoneessa), _tuppi_jako, _aamu.

const Kolmio := preload("res://scripts/kolmiomittaus.gd")
const TuppiGame := preload("res://scripts/tuppi_game.gd")

var main: Node3D
var vikoja := 0


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + t)


func _shot_path(suffix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			return a.substr(7).replace(".png", suffix + ".png")
	return "user://kolmio_tuppi%s.png" % suffix


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
	print("TUPPI kuva " + _shot_path(suffix))


func run() -> void:
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("rasytuppi")
	await _frames(10)
	var s: Dictionary = main.kolmio.st("saloinen")
	s.done_day = maxi(0, main.day - 1)  # kohde tehty kerran aiemmin: iltakiva on tuppi
	s.illat = 1
	if main.kolmio.next_kiva("saloinen") != "tuppi":
		_vika("toinen ilta ei ole tuppi: %s" % main.kolmio.next_kiva("saloinen"))
	main._kolmio_kiva("saloinen", main.kolmio.next_kiva("saloinen"))
	await _frames(20)
	var g = main._rasva_game
	if g == null or g.get_script() != TuppiGame:
		_vika("räsytuppi ei alkanut (%s)" % g)
		return
	print("TUPPI istujat %s" % [g.seats.map(func(x: Dictionary) -> String: return x.name)])
	await _snap("_tuppi")
	g.auto = true
	g.game.rng.seed = 3
	var shot_jako := false
	for i in 30000:
		await _frames(1)
		if not is_instance_valid(g) or main._rasva_game == null:
			break
		if not shot_jako and g._phase == "jako":
			shot_jako = true
			await _snap("_tuppi_jako")
	for i in 300:
		await _frames(1)
		if main._kolmio_ui != null:
			break
	print("TUPPI aamu %s, loput %s, kolmio %s" % [main._kolmio_ui, main.endings.counts, main.kolmio.st("saloinen")])
	if main._kolmio_ui == null:
		_vika("aamu ei alkanut tupin jälkeen")
	else:
		await _frames(60)
		await _snap("_aamu")
	if not main.endings.counts.has("minttu"):
		_vika("kolmiomittauksen loppu (minttu) puuttuu")
	print("TUPPI valmis, %d vikaa" % vikoja)
