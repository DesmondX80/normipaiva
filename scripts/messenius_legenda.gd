extends RefCounted
## Kajaanin linna ja Messenius (#250 P17-P18): rauniot, tervavene (kohtaus) ja Messeniuksen vankeus. Tiedot "sanotaan"-muodossa, tarkistettava.
## Palkkio kerran, kun kaikki kolme on koettu (mielihyvä ja maine).

const MIELIHYVA := 5.0
const MAINE := 1.0

var rauniot := false  # linnan rauniot katsottu
var tervavene := false  # tervavene-kohtaus nähty
var messenius := false  # Messeniuksen tarina kuultu
var valmis := false  # palkkio annettu


func kuultu() -> int:
	return int(rauniot) + int(tervavene) + int(messenius)


func save_to(cfg: ConfigFile) -> void:
	for k in ["rauniot", "tervavene", "messenius", "valmis"]:
		cfg.set_value("messenius", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	rauniot = cfg.get_value("messenius", "rauniot", false)
	tervavene = cfg.get_value("messenius", "tervavene", false)
	messenius = cfg.get_value("messenius", "messenius", false)
	valmis = cfg.get_value("messenius", "valmis", false)
