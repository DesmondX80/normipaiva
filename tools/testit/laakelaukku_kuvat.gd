extends Node3D
## Hoitajan lääkelaukku (erä C): tilan säännöt (huume_saloinen.gd), 3D-laukku portaalla edestä, päädystä, ylhäältä ja
## viistosta suurennettuna, reppuikoni, sekä laukun ja klaffipöydän minipelit rinnakkain (sama valekeittiö-game).
## tools/testit/aja.sh tscn tools/testit/laakelaukku_kuvat.tscn

const B := preload("res://scripts/build.gd")
const HuumeSaloinen := preload("res://scripts/huume_saloinen.gd")
const Laakelaukku := preload("res://scripts/laakelaukku.gd")
const Klaffipoyta := preload("res://scripts/klaffipoyta.gd")
const Inventory := preload("res://scripts/inventory.gd")

const TEINI_KIINNI := [0.0, 0.1, 0.3, 0.6, 0.9]  # main.gd

var out := "user://laakelaukku"
var cam: Camera3D
var vikoja := 0


## main.gd:n korvike minipeleille: kolme lääkettä ja jatkeet; kirjaa _craft_do-kutsun puhdas-parametrin.
class FakeGame extends Node:
	var LAAKE_JATKO_MAX := 4
	var stock := {"opiaatti": 2, "burana": 1, "panadol": 1, "perv": 1, "perv~2": 1, "sokeri": 1}
	var last_puhdas := -1

	func _craft_learn() -> void:
		pass

	func _craft_stock(key: String) -> int:
		return int(stock.get(key, 0))

	func _craft_items() -> Array:
		return stock.keys()

	func _craft_do(id: String, drug: String, puhdas := false) -> String:
		last_puhdas = 1 if puhdas else 0
		return "%s (%s) puhdas=%s" % [id, drug, puhdas]


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA ", t)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_rules()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.88)
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = 0.35
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(20, 0.1, 20)), Vector3(0, -0.05, 0), Color(0.35, 0.36, 0.3))
	# Betoniporras (STOOP 1.8 × 0.5 × 0.9) ja taustaseinä.
	B.mesh(self, B.boxm(Vector3(1.8, 0.5, 0.9)), Vector3(0, 0.25, 0), Color(0.62, 0.61, 0.58))
	B.mesh(self, B.boxm(Vector3(4, 3, 0.2)), Vector3(0, 1.5, -0.55), Color(0.82, 0.8, 0.74))
	var bag := Laakelaukku.build_prop()
	bag.position = Vector3(-(0.9 - Laakelaukku.PROP_L / 2.0 - 0.05), 0.5, 0.15)
	add_child(bag)
	var aabb := _aabb(bag)
	print("LAUKKU koko %s pohja_y %.3f (porras 0.5) yla_y %.3f" % [aabb.size, aabb.position.y, aabb.end.y])
	if absf(aabb.position.y - 0.5) > 0.002:
		_vika("laukun pohja ei portaan pinnalla: %.3f" % aabb.position.y)
	cam = Camera3D.new()
	add_child(cam)
	_run.call_deferred(bag.position)


## Säännöt: porras, laukku 3. ostosta kerran, puhtaiden laskenta ja tallennus.
func _rules() -> void:
	var hs := HuumeSaloinen.new()
	var rivi := []
	for tier in 5:
		var key := "opiaatti~%d" % tier
		hs.laukku_erat = {key: 1}
		var p := hs.porras(tier, key, 1)
		var q := hs.porras(tier, key, 0)  # puhtaat myyty: tavallinen porras
		rivi.append("%d->%d (%.0f%%->%.0f%%)" % [tier, p, TEINI_KIINNI[tier] * 100.0, TEINI_KIINNI[p] * 100.0])
		if p != maxi(0, tier - 1) or q != tier:
			_vika("porras tier %d: %d / %d" % [tier, p, q])
	print("LAUKKU porras ", ", ".join(rivi))
	hs = HuumeSaloinen.new()
	var annettu := []
	for i in 5:
		annettu.append(hs.osto())
	print("LAUKKU ostot ", annettu, " tila ", hs.laukku)
	if annettu != [false, false, true, false, false] or hs.laukku != "portaalla":
		_vika("laukku ei tule 3. ostosta kerran")
	hs.laukku = "repussa"
	hs.lisaa_puhdas("perv~1", 2)
	hs.lisaa_puhdas("perv~1", 2)
	hs.myyty("perv~1")
	if hs.puhtaat("perv~1", 10) != 3 or hs.puhtaat("perv~1", 1) != 1:
		_vika("puhtaat laskenta")
	hs.sovita({"perv~1": 2})
	hs.ei_osta = {"kaukalo": 3}
	var cfg := ConfigFile.new()
	hs.save_to(cfg)
	var hs2 := HuumeSaloinen.new()
	hs2.load_from(cfg)
	print("LAUKKU tallennus ostot %d laukku %s erat %s ei_osta %s" % [hs2.ostot, hs2.laukku, hs2.laukku_erat, hs2.ei_osta])
	if hs2.ostot != 5 or hs2.laukku != "repussa" or hs2.laukku_erat != {"perv~1": 2} or hs2.ei_osta != {"kaukalo": 3}:
		_vika("tallennus/lataus")
	var hs3 := HuumeSaloinen.new()
	hs3.load_from(ConfigFile.new())
	if hs3.ostot != 0 or hs3.laukku != "" or not hs3.laukku_erat.is_empty():
		_vika("tyhjä lataus")


func _aabb(n: Node) -> AABB:
	var a := AABB()
	var first := true
	for c in n.get_children():
		if c is MeshInstance3D:
			var b: AABB = (c as MeshInstance3D).global_transform * (c as MeshInstance3D).get_aabb()
			a = b if first else a.merge(b)
			first = false
	return a


func _run(bp: Vector3) -> void:
	for i in 10:
		await get_tree().process_frame
	var c := bp + Vector3(0, 0.14, 0)
	await _shot("prop_edesta", c + Vector3(0, 0.12, 1.3), c, 30.0)
	await _shot("prop_paadysta", c + Vector3(1.3, 0.12, 0), c, 30.0)
	await _shot("prop_ylhaalta", c + Vector3(0.001, 1.3, 0.05), c, 30.0)
	await _shot("prop_viisto", c + Vector3(0.9, 0.6, 0.9), c, 30.0)
	await _shot("prop_porras", Vector3(1.5, 1.6, 3.0), Vector3(0, 0.4, 0), 50.0)
	# Reppuikoni suurennettuna (16 px -> 256 px).
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	Inventory._paint(img, "laakelaukku", Color.WHITE)
	Inventory._outline(img)
	img.resize(256, 256, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join("ikoni.png"))
	# Minipelit: laukku ja vertailuksi klaffipöytä, sama ruudukko.
	for sc in [Laakelaukku, Klaffipoyta]:
		var g := FakeGame.new()
		add_child(g)
		var mg: CanvasLayer = sc.new()
		mg.game = g
		add_child(mg)
		mg.set("_cells", ["", "opiaatti", "", "", "burana", "", "", "", ""])
		mg.set("_held", "perv")
		mg.set("mouse_fixed", Vector2(900, 300))
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var nimi := "minipeli_laukku" if sc == Laakelaukku else "minipeli_klaffi"
		get_viewport().get_texture().get_image().save_png(out.path_join(nimi + ".png"))
		mg.call("_craft")
		print("MINIPELI %s osuma %s puhdas=%d viesti '%s'" % [nimi, mg.get("_cells"), g.last_puhdas, mg.get("_msg")])
		if g.last_puhdas != (1 if sc == Laakelaukku else 0):
			_vika("%s _craft_do puhdas=%d" % [nimi, g.last_puhdas])
		mg.call("_close")
		g.queue_free()
		for i in 3:
			await get_tree().process_frame
	print("LAUKKU valmis vikoja %d kuvat: %s" % [vikoja, out])
	get_tree().quit()


func _shot(name: String, from: Vector3, to: Vector3, fov := 50.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, to)
	cam.current = true
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
