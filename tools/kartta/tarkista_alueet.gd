extends SceneTree
## Tarkistaa, että kaikki kartan aluemonikulmiot (map_data.gd) kolmioituvat: itseään leikkaava tai
## surkastunut monikulmio ei piirry minikarttaan eikä paperikarttaan. Ajo:
##   godot --headless --path . -s tools/kartta/tarkista_alueet.gd

const M := preload("res://scripts/map_data.gd")


func _init() -> void:
	var bad := 0
	for layer in [["FORESTS", M.FORESTS], ["FIELDS", M.FIELDS], ["BOGS", M.BOGS], ["WATER", M.WATER],
			["CLEARCUTS", M.CLEARCUTS]]:
		for i in layer[1].size():
			var poly := PackedVector2Array(layer[1][i])
			if Geometry2D.triangulate_polygon(poly).is_empty():
				bad += 1
				print("VIRHE %s[%d]: %d pistettä, alkaa %s" % [layer[0], i, poly.size(), poly[0]])
	print("kolmioimattomia alueita: %d" % bad)
	quit()
