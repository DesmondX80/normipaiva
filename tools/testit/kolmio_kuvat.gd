extends Node
## Kolmiomittauksen (#255) piirretyt kohtaukset ja Sytkäri kuvina ilman pelimaailmaa: ovi Saloisissa (lahjat
## ojennettu) ja Vaalassa, väärä ovi (mummo keppi ylhäällä, pieni poika), aamu kummassakin, Sytkärin kortti, mätsi ja
## mittaus kummallekin naiselle. Hahmot ovat 3D-hahmoja (Looks.make) kohtausten omissa lavastuksissa.
## tools/testit/aja.sh tscn tools/testit/kolmio_kuvat.tscn
const K := preload("res://scripts/kolmio_kohtaus.gd")
const S := preload("res://scripts/sytkari.gd")
const Kolmio := preload("res://scripts/kolmiomittaus.gd")
const Looks := preload("res://scripts/looks.gd")
const Hall := preload("res://scripts/rasvanappi_hall.gd")
const Rasva := preload("res://scripts/rasvanappi_game.gd")

var out := "user://kolmio_kuvat"
var root: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root = self
	_run.call_deferred()

func _shot(node: Node, nm: String, top := false) -> void:
	for i in 12:  # 3D-hahmot ja IK asettuvat
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("kuva_%s.png" % nm))
	if top and "_cam_base" in node:
		# Ylhäältä: oven aukeamissuunta, hahmojen paikat ja läpimenot (CLAUDE.md: asetelmasta kuva ylhäältä).
		node._cam_base = Transform3D(Basis.looking_at(Vector3(0, -1, -0.01), Vector3.UP), Vector3(0, 7.5, 0.8))
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("kuva_%s_ylhaalta.png" % nm))
	node.queue_free()
	await get_tree().process_frame

func _scene(mode: String, site: String, setup: Callable) -> Node:
	var ui = K.new()
	ui.mode = mode
	ui.site = site
	var info: Dictionary = Kolmio.SITES[site]
	ui.woman = info.woman
	ui.friends = info.friends
	ui.gifts = info.gifts
	setup.call(ui)
	ui.auto = false  # rivi pysyy, lavastus päivittyy (_apply)
	root.add_child(ui)
	return ui

func _run() -> void:
	await get_tree().process_frame
	var ui = _scene("ovi", "saloinen", func(u): pass)
	ui._line = 3; ui._given = 2; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
	await _shot(ui, "ovi_saloinen", true)
	ui = _scene("ovi", "vaala", func(u): pass)
	ui._line = 1; ui._given = 0; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
	await _shot(ui, "ovi_vaala")
	ui = _scene("vaara", "saloinen", func(u): u.resident = Kolmio.WRONG_DOORS.saloinen[0])
	ui._line = 2; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
	await _shot(ui, "vaara_mummo")
	ui = _scene("vaara", "saloinen", func(u): u.resident = Kolmio.WRONG_DOORS.saloinen[2])
	ui._line = 1; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
	await _shot(ui, "vaara_poika")
	ui = _scene("aamu", "saloinen", func(u): u.stats = "Kolme ympyrää ✔")
	ui._line = 1; ui._line_t = 9.0
	await _shot(ui, "aamu_saloinen")
	ui = _scene("aamu", "vaala", func(u): pass)
	ui._line = 2; ui._line_t = 9.0
	await _shot(ui, "aamu_vaala")
	for site in ["saloinen", "vaala"]:
		var info: Dictionary = Kolmio.SITES[site]
		for m in ["match", "matka"]:
			var sy = S.new()
			sy.mode = m
			sy.who = info.woman; sy.age = info.age; sy.job = info.job; sy.bio = info.bio; sy.dist = "250 m"
			sy.note_from = "Esa"; sy.note = "Hyvä. Merkkaan harpilla."
			root.add_child(sy)
			sy._t = 1.2 if m == "match" else 2.0
			sy._rise = 1.0
			sy.set_process(false)
			sy._view.queue_redraw()
			await _shot(sy, "syt_%s_%s" % [m, site])
			if m == "match":
				sy = S.new()
				sy.mode = m
				sy.who = info.woman; sy.age = info.age; sy.job = info.job; sy.bio = info.bio; sy.dist = "250 m"
				root.add_child(sy)
				sy._t = 4.0; sy._swiped = 1.0; sy._rise = 1.0
				sy.set_process(false)
				sy._view.queue_redraw()
				await _shot(sy, "syt_matsi_%s" % site)
	await _rinkka()
	for site in ["saloinen", "vaala"]:
		await _olohuone(site)
	get_tree().quit()


## Jonin Sandels-päkkirinkka, Mintun kiharat ja väärän oven mummon kampaus 3D:nä: takaa, sivulta, ylhäältä ja rajattuna lähikuvana (logo, muotokuva, jesarit).
func _rinkka() -> void:
	var w := Node3D.new()
	add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 150, 0)
	w.add_child(sun)
	var joni: Node3D = Looks.make(w, Looks.JONI)
	joni.play("Idle", 0.0)
	var minttu: Node3D = Looks.make(w, Looks.MINTTU)  # kiharat: kuvat kolmesta suunnasta ja kasvot
	minttu.position = Vector3(4, 0, 0)
	minttu.play("Idle", 0.0)
	var mummo: Node3D = Looks.make(w, K.RESIDENTS["Mummo kepin kanssa"])  # väärän oven mummo: permanentti ja lasit
	mummo.position = Vector3(-4, 0, 0)
	mummo.play("Idle", 0.0)
	var cam := Camera3D.new()
	cam.fov = 40.0
	w.add_child(cam)
	cam.current = true
	for v in [["rinkka_takaa", Vector3(0.3, 1.5, 1.8), Vector3(0, 1.2, 0)], ["rinkka_sivulta", Vector3(1.6, 1.4, 0.4), Vector3(0, 1.25, 0.1)],
			["rinkka_ylhaalta", Vector3(0.0, 3.0, 0.35), Vector3(0, 1.2, 0.15)], ["rinkka_lahelta", Vector3(0.05, 1.3, 0.75), Vector3(0, 1.22, 0.2)],
			["minttu_edesta", Vector3(4.1, 1.55, -1.1), Vector3(4, 1.45, 0)], ["minttu_kasvot", Vector3(4.05, 1.58, -0.6), Vector3(4, 1.53, 0)],
			["minttu_sivulta", Vector3(5.1, 1.55, 0.0), Vector3(4, 1.45, 0)], ["minttu_takaa", Vector3(4.1, 1.6, 1.1), Vector3(4, 1.45, 0)],
			["mummo_kasvot", Vector3(-3.95, 1.4, -0.6), Vector3(-4, 1.36, 0)], ["mummo_sivulta", Vector3(-3.0, 1.35, 0.0), Vector3(-4, 1.3, 0)],
			["mummo_takaa", Vector3(-3.9, 1.45, 0.9), Vector3(-4, 1.3, 0)]]:
		cam.look_at_from_position(v[1], v[2])
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("kuva_%s.png" % v[0]))
	w.queue_free()


## Naisen olohuone (rasvanappi_hall.gd _build_living) valot päällä: pelikamera, esittelykamera ja ylhäältä.
func _olohuone(site: String) -> void:
	var h = Hall.new()
	h.room = Rasva.ROOM
	h.door_y = Rasva.DOOR_Y
	h.style = Kolmio.RASVA_RULES[site].style
	add_child(h)
	h.build(Rasva.OBST, [], {}, null)
	h.set_lit(1.0)
	h.set_sight(Vector2(1.5, Rasva.DOOR_Y), 2.0)
	var top := Camera3D.new()
	top.fov = 50.0
	top.cull_mask = Hall.LAYER
	top.environment = h.cam.environment
	h.add_child(top)
	var eye := Vector3(6.0, 11.0, 3.6)
	top.transform = Transform3D(Basis.looking_at(Vector3(0, -1, -0.001), Vector3.UP), eye)
	var near := Camera3D.new()  # lähikuva: televisio, piano ja ikkuna
	near.fov = 50.0
	near.cull_mask = Hall.LAYER
	near.environment = h.cam.environment
	h.add_child(near)
	near.transform = Transform3D(Basis.looking_at(Vector3(4.0, 0.8, 0.2) - Vector3(2.6, 1.7, 3.0), Vector3.UP), Vector3(2.6, 1.7, 3.0))
	var near2 := Camera3D.new()  # lähikuva: ruokapöytä, takka ja kirjahylly
	near2.fov = 50.0
	near2.cull_mask = Hall.LAYER
	near2.environment = h.cam.environment
	h.add_child(near2)
	near2.transform = Transform3D(Basis.looking_at(Vector3(10.0, 0.7, 2.5) - Vector3(6.0, 2.2, 6.5), Vector3.UP), Vector3(6.0, 2.2, 6.5))
	for v in [[h.cam, "peli"], [h.line_cam, "edesta"], [top, "ylhaalta"], [near, "tv"], [near2, "takka"]]:
		(v[0] as Camera3D).current = true
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("kuva_olohuone_%s_%s.png" % [site, v[1]]))
	h.queue_free()
	await get_tree().process_frame
