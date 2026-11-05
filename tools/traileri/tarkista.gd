extends Node
## Kääntää trailerin skriptit pelin autoloadien kanssa (ilman pelin latausta) ja tulostaa virheet:
## godot --path . --headless tools/traileri/tarkista.tscn


func _ready() -> void:
	for f in ["otokset", "otokset_uusi", "ohjaaja", "teksti", "leikkaus", "leikkaus_rasvanappi"]:
		var s: GDScript = load("res://tools/traileri/%s.gd" % f)
		print("%s: %s" % [f, "OK" if s != null and s.can_instantiate() else "VIRHE"])
	get_tree().quit()
