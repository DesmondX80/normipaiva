extends Node
## Rasvanappi-minipelin vaiheet kuvina: koputus, luukku auki, vastaukset (pelko, hyväksyntä, ovi aukeaa), esittely,
## pimeä halli (myös valot päällä tarkistusta varten), tökkäys, nimivalikko, nuolu ja loppu; lopuksi väärä salasana
## (viha ja luukun paukahdus). Ovikohtaus on 3D:nä: makasiini rakennetaan tähän yöhön (makasiini.gd).
## godot --path . --resolution 1280x720 tools/testit/rasvanappi_kuvat.tscn -- <kansio>

const Game := preload("res://scripts/rasvanappi_game.gd")
const Makasiini := preload("res://scripts/makasiini.gd")
const B := preload("res://scripts/build.gd")

var out := "user://rasvanappi"
var g: CanvasLayer
var door: Node3D
var moon: DirectionalLight3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_build_night()
	g = Game.new()
	g.door = door
	g.sun = moon
	add_child(g)
	_run.call_deferred()


## Kesäyö: hämärä taivas, kuunvalo, sorapiha ja makasiini (takaovi -X-päädyssä).
func _build_night() -> void:
	var w := Node3D.new()
	add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.1, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.5)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.68, 0.9)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.rotation = Vector3(deg_to_rad(-35), deg_to_rad(-120), 0)
	w.add_child(moon)
	B.box(w, Vector3(60, 0.2, 60), Vector3(0, -0.1, 0), Color(0.3, 0.28, 0.25), false)
	var root := Node3D.new()
	w.add_child(root)
	Makasiini.build(root)
	door = root.get_node("Takaovi")


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("KUVA ", name, " tila ", g._mode if is_instance_valid(g) else "valmis", " a ", g._t - g._answer_t if is_instance_valid(g) else -1.0)


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
	await _wait(1.3)
	await _shot("04b_luukku_kiinni")
	await _wait(1.0)
	await _shot("04c_ovi_aukeaa")
	await _wait(0.9)
	await _shot("04d_ovi_auki")
	await _wait(1.8)
	await _shot("05_esittely")
	g._lights_out()
	await _wait(0.15)
	await _shot("06_naks")
	await _wait(1.6)
	await _shot("07_pimea")
	# Valot päälle tarkistusta varten.
	g.set_process(false)
	g._hall.set_lit(1.0)
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
	g._done(true)
	await _wait(0.3)
	# Väärä salasana: portsari suuttuu ja luukku paukahtaa kiinni.
	g = Game.new()
	g.door = door
	g.sun = moon
	add_child(g)
	await _wait(2.6)
	g._sel = g._opts.find(1)
	g._answer()
	await _wait(0.8)
	await _shot("17_viha")
	while is_instance_valid(g) and g._hatch_to > 0.0:
		await get_tree().process_frame
	await _wait(0.12)
	await _shot("18_paukahdus")
	await _wait(2.0)
	get_tree().quit()
