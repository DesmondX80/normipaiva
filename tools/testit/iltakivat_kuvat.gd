extends Node
## Kolmiomittauksen iltakivat kuvina (lettukisa, löylykisa, Sivikki-disko, karaoke; räsytuppi: tuppi_kuvat.gd).
## Tekoäly pelaa pelaajankin puolesta (auto). Jokaisesta kivasta kuvat: alku, toiminta, toiminnan kohde suurennettuna
## (kuva_<kiva>_lahi), loppu; asetelma Asento.views-kulmista (läpimenot "LÄPI … -> …" = VIKA) ja toiminnan kohteen koko
## pelikameralta (vähintään noin 40 px). Lopuksi tarkistetaan, että finished-tulos tuli.
## tools/testit/aja.sh tscn tools/testit/iltakivat_kuvat.tscn [ajokansio] [kiva,kiva]

const Rasva := preload("res://scripts/rasvanappi_game.gd")
const Looks := preload("res://scripts/looks.gd")
const Kolmio := preload("res://scripts/kolmiomittaus.gd")
const Asento := preload("res://tools/testit/asento.gd")
const KIVAT := {
	"lettu": ["res://scripts/lettu_game.gd", Kolmio.LETTU_LINES],
	"loyly": ["res://scripts/loyly_game.gd", Kolmio.LOYLY_LINES],
	"karaoke": ["res://scripts/ilta_karaoke.gd", Kolmio.KARAOKE_LINES],
}

var out := "user://iltakivat_kuvat"
var vikoja := 0
var _result := {}
var _only: Array = []


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + t)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		_only = Array(args[1].split(","))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(nm: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("kuva_%s.png" % nm))
	print("ILTA kuva %s" % nm)


func _make(kiva: String, site: String) -> Node:
	var anchor := Node3D.new()
	add_child(anchor)
	var g = load(KIVAT[kiva][0]).new()
	g.anchor = anchor
	g.auto = true
	g.site = site
	g.style = Kolmio.RASVA_RULES[site].style
	var k: Array = [["joni", "Joni"], ["esa", "Esa"], ["minttu", "Minttu"]] if site == "saloinen" else \
		[["tero", "Tero"], ["timo", "Timo"], ["katja", "Katja"]]
	g.people = [{"id": "pelaaja", "name": "Sinä", "look": Looks.player()}]
	for e: Array in k:
		g.people.append({"id": e[0], "name": e[1], "look": Rasva.real_look(e[0])})
	g.lines = KIVAT[kiva][1][site]
	_result = {}
	g.finished.connect(func(r: Dictionary) -> void: _result = r)
	add_child(g)
	return g


## Toiminnan kohteen koko pelikameralta: kiva kertoo kohteen keskipisteen ja säteen (test_target -> [Vector3, m]).
func _check_size(g: Node, kiva: String) -> void:
	if not g.has_method("test_target"):
		return
	var t: Array = g.test_target()
	var cam: Camera3D = g._cam
	var c := cam.unproject_position(t[0])
	var r := cam.unproject_position(t[0] + cam.global_basis.x * float(t[1]))
	var px := c.distance_to(r) * 2.0
	print("ILTA %s kohde %.0f px" % [kiva, px])
	if px < 40.0:
		_vika("%s: toiminnan kohde alle 40 px (%.0f)" % [kiva, px])


func _run() -> void:
	await get_tree().process_frame
	for kiva: String in KIVAT:
		if not _only.is_empty() and not kiva in _only:
			continue
		if not ResourceLoader.exists(KIVAT[kiva][0]):
			continue
		for site: String in (["vaala"] if kiva == "disko" else ["saloinen", "vaala"]):
			var tag := "%s_%s" % [kiva, site]
			var g := _make(kiva, site)
			await _shot(tag + "_alku")
			for i in 4000:
				await get_tree().process_frame
				if g._phase != "alku" and g._t > 6.0 or not is_instance_valid(g):
					break
			await _shot(tag + "_toiminta")
			_check_size(g, kiva)
			if g.has_method("test_closeup"):
				var keep: Transform3D = g._cam.transform
				g.test_closeup()
				await _shot(tag + "_lahi")
				if g.has_method("test_closeup2"):
					g.test_closeup2()
					await _shot(tag + "_lahi2")
				g._cam.transform = keep
				if "_cam_base" in g:
					g._cam_base = keep
			if site == "saloinen" or kiva == "disko":
				var t: Array = g.test_target() if g.has_method("test_target") else [g._hall.to_global(g.CENTER), 1.0]
				g.set_process(false)  # kiva palauttaa kameransa joka ruudussa: pysäytetään kulmakuvien ajaksi
				await Asento.views(g._cam, out, "%s_asetelma" % tag, t[0] + Vector3(0, 0.4, 0), 2.6, Vector3(0, 0, 1))
				g._cam.transform = g._cam_base
				g.set_process(true)
			var shot_end := false
			var gap := 9.0
			for i in 30000:
				await get_tree().process_frame
				if not _result.is_empty() or not is_instance_valid(g):
					break
				if "_ladle_min_gap" in g:
					gap = minf(gap, g._ladle_min_gap)
				if g._phase == "loppu" and g._t > 0.4 and not shot_end:
					shot_end = true
					await _shot(tag + "_loppu")
			print("ILTA %s tulos %s" % [tag, _result])
			if gap < 9.0:
				print("ILTA %s kauhan rako piippuun %.3f m" % [tag, gap])
				if gap < 0.0:
					_vika("%s: kauha menee piipun sisään (%.3f m)" % [tag, gap])
			if _result.is_empty() or _result.get("kiva", "") != kiva:
				_vika("%s: ei tulosta" % tag)
			if is_instance_valid(g):
				g.queue_free()
			await get_tree().process_frame
	print("ILTA kuvat valmis, vikoja %d" % vikoja)
	get_tree().quit()
