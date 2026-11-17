extends Node
## Räsytuppi kuvina (scripts/tuppi_game.gd): tekoäly pelaa kaikkien puolesta. Kuvat: ilmoitus, peli (kortteja
## pöydällä), jaon tulos (riisuminen), riisumisvaiheet 0–3 rinnakkain ja asetelma Asento.views-kulmista
## (läpimenot: "LÄPI … -> …" = VIKA). Lopuksi ilta pelataan loppuun (pantu tuppeen) ja tulos tarkistetaan.
## tools/testit/aja.sh tscn tools/testit/tuppi_kuvat.tscn

const TuppiGame := preload("res://scripts/tuppi_game.gd")
const Rasva := preload("res://scripts/rasvanappi_game.gd")
const Looks := preload("res://scripts/looks.gd")
const Kolmio := preload("res://scripts/kolmiomittaus.gd")
const Asento := preload("res://tools/testit/asento.gd")

var out := "user://tuppi_kuvat"
var vikoja := 0
var _result := {}


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + t)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]  # aja.sh antaa ajokansion (kuten kolmio_kuvat.gd)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(nm: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("kuva_%s.png" % nm))
	print("TUPPI kuva %s" % nm)


func _make(rasy: Array) -> Node:
	var anchor := Node3D.new()
	add_child(anchor)
	var g = TuppiGame.new()
	g.anchor = anchor
	g.auto = true
	g.site = "saloinen"
	g.style = Kolmio.RASVA_RULES.saloinen.style
	g.seats = [{"id": "pelaaja", "name": "Sinä", "look": Looks.player()},
		{"id": "joni", "name": "Joni", "look": Rasva.real_look("joni")},
		{"id": "minttu", "name": "Minttu", "look": Rasva.real_look("minttu")},
		{"id": "esa", "name": "Esa", "look": Rasva.real_look("esa")}]
	g.lines = Kolmio.TUPPI_LINES.saloinen
	g.game.rasy = rasy.duplicate()
	g.finished.connect(func(r: Dictionary) -> void: _result = r)
	add_child(g)
	return g


func _run() -> void:
	await get_tree().process_frame
	var g = _make([0, 0])
	await _shot("ilmoitus")
	# Pelivaihe: odota, että pöydällä on 2–3 korttia.
	for i in 900:
		await get_tree().process_frame
		if g._phase == "peli" and g._table_cards.size() >= 2:
			break
	await _shot("peli")
	# Pöydän kortin koko pelikameralta (CLAUDE.md: pieni esine vähintään noin 40 px).
	var cam: Camera3D = g._cam
	if not g._table_cards.is_empty():
		var m: Node3D = g._table_cards[0][0]
		var a := cam.unproject_position(m.global_position + Vector3(-0.05, 0, 0))
		var b := cam.unproject_position(m.global_position + Vector3(0.05, 0, 0))
		print("TUPPI pöydän kortti %.0f px leveä" % a.distance_to(b))
		if a.distance_to(b) < 40.0:
			_vika("pöydän kortti alle 40 px (%.0f)" % a.distance_to(b))
	# Asetelma kaikista kulmista ja läpimenot.
	await Asento.views(cam, out, "tuppi_asetelma", g._hall.to_global(g.CENTER + Vector3(0, 0.6, 0)), 2.0, Vector3(0, 0, 1))
	g.queue_free()
	await get_tree().process_frame
	# Riisumisvaiheet: kaverit vaiheissa 1..3 rinnakkain (pari 1), pelaajapari vaiheessa 2.
	for st in [1, 2, 3]:
		var g2 = _make([2, st])
		g2.set_process(false)
		await _shot("rasy_%d" % st)
		if st == 3:
			await Asento.views(g2._cam, out, "tuppi_kalsarit", g2._hall.to_global(g2.CENTER + Vector3(0, 0.6, 0)), 2.0, Vector3(0, 0, 1))
		g2.queue_free()
		await get_tree().process_frame
	# Koko ilta tekoälyllä: päättyy tuppeen ja finished-signaaliin.
	var g3 = _make([0, 0])
	g3.game.rng.seed = 5
	for i in 20000:
		await get_tree().process_frame
		if not _result.is_empty():
			break
		if g3._phase == "jako" and g3._t < 0.05:
			await _shot("jako")
	print("TUPPI tulos %s" % _result)
	if _result.is_empty() or not _result.has("voitto"):
		_vika("ilta ei päättynyt tulokseen")
	print("TUPPI kuvat valmis, vikoja %d" % vikoja)
	get_tree().quit()
