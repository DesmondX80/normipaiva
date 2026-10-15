extends Node
## Rasvanappi-minipelin vaiheet kuvina: luukku kiinni ja auki, vastaus, esittely, pimeä halli (myös valot päällä
## tarkistusta varten), tökkäys, nimivalikko, nuolu ja loppu.
## godot --path . --resolution 1280x720 tools/testit/rasvanappi_kuvat.tscn -- <kansio>

const Game := preload("res://scripts/rasvanappi_game.gd")

var out := "user://rasvanappi"
var g: CanvasLayer


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	g = Game.new()
	add_child(g)
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("KUVA ", name, " tila ", g._mode)


func _run() -> void:
	await _wait(0.5)
	await _shot("01_koputus")
	await _wait(2.4)
	await _shot("02_luukku")
	g._sel = g._opts.find(2)
	g._answer()
	await _wait(0.6)
	await _shot("03_poliisi")
	# Uusi yritys oikealla salasanalla.
	g._answered = -1
	g._eyes = "epaily"
	g._sel = g._opts.find(0)
	g._answer()
	await _wait(1.0)
	await _shot("04_oikein")
	await _wait(3.2)
	await _shot("05_esittely")
	g._lights_out()
	await _wait(0.15)
	await _shot("06_naks")
	await _wait(1.6)
	await _shot("07_pimea")
	# Valot päälle tarkistusta varten.
	g._dmat.set_shader_parameter("dark", 0.0)
	g.set_process(false)
	g._dark.visible = false
	g._root.queue_redraw()
	g._top.queue_redraw()
	await get_tree().process_frame
	await _shot("08_valot")
	g.set_process(true)
	# Pelaaja jonkun taakse.
	var n: Dictionary = g.npcs[1]
	n.pos = Vector2(5.5, 3.5)
	n.ang = 0.0
	n.goal = 0.0
	g.me.pos = Vector2(4.75, 3.5)
	g.me.ang = 0.0
	n.pause_t = 5.0
	n.turn_t = 5.0
	await _wait(0.2)
	await _shot("09_takana")
	g._begin_poke(-1, 1)
	await _wait(0.3)
	await _shot("10_nimi")
	g._name_pick(3)
	await _wait(1.0)
	await _shot("11_vastaus")
	await _wait(2.3)
	await _shot("12_nuolu")
	await _wait(3.5)
	print("NAPPI ", g.nappi, " tila ", g._mode, " tökkäykset ", g.pokes)
	await _wait(1.0)
	await _shot("13_jahti")
	# Nappi tökkää pelaajaa.
	g._new_nappi(2, -1)
	await _wait(0.5)
	if g.nappi >= 0:
		g._begin_poke(g.nappi, -1)
		await _wait(1.0)
		await _shot("14_tokattiin")
		await _wait(2.0)
		await _shot("15_nuolu2")
	await _wait(4.0)
	g._end()
	await _wait(1.5)
	await _shot("16_loppu")
	get_tree().quit()
