extends Node
## Luku 6 (#326, erä E1): kodin ovikohtauksen (kolmio_kohtaus.gd, site "koti") ja Päivin keittiöaamun läpimenotarkistus
## pelin sisällä (Asento.solids): Päivi kerma- ja mansikkalaatikon kanssa kynnyksellä, Sinikka eteisessä, kolmikko
## portailla. Kohtauksen lavastus siirretään 300 m ylös, jotta pelimaailman kappaleet eivät osu tarkistukseen
## (lavastus on omassa 3D-maailmassaan samoissa koordinaateissa kuin pelimaailma).
## tools/testit/aja.sh scene asennot --asento=koti

const K := preload("res://scripts/kolmio_kohtaus.gd")
const Asento := preload("res://tools/testit/asento.gd")

var main: Node3D


func run() -> void:
	var out := "user://asennot_koti"
	DirAccess.make_dir_recursive_absolute(out)
	var bad := 0
	for v in [["ovi", 1], ["ovi", 2], ["aamu", 3]]:
		var ui = K.new()
		ui.mode = v[0]
		ui.site = "koti"
		ui.friends = ["Joni", "Esa"]
		ui.auto = false
		main.add_child(ui)
		ui._line = v[1]; ui._door = 1.0; ui._door_to = 1.0; ui._line_t = 9.0
		ui._stage.position.y = 300.0
		for i in 30:
			await main.get_tree().process_frame
		await RenderingServer.frame_post_draw
		ui._vp.get_texture().get_image().save_png(out.path_join("koti_%s_%d.png" % v))
		var list := []
		Asento._chars(ui._stage, list)
		var n := 0
		for c: Node3D in list:
			n += Asento.solids(c, ui._stage)
		print("ASENTO koti %s rivi %d: %d hahmoa, %d läpimenoa" % [v[0], v[1], list.size(), n])
		bad += n
		ui.queue_free()
		await main.get_tree().process_frame
	print("ASENTO yhteensä virheitä: ", bad, " kuvat: ", ProjectSettings.globalize_path(out))
