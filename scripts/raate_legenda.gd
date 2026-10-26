extends RefCounted
## Raatteen Portti (#250 P20): Suomussalmen Raatteentie, talvisodan muistopaikka. Kolme hiljaista kohtaa. Tiedot "sanotaan"-muodossa, tarkistettava.
## Palkkio kerran, kun kaikki kolme kohtaa on käyty läpi (mielihyvä ja maine).

const MIELIHYVA := 3.0
const MAINE := 1.0

var portti := false  # Raatteen Portti -muistomerkki
var tie := false  # Raatteentie ja tienvarsi
var kivi := false  # muistokivi
var valmis := false  # palkkio annettu


func kuultu() -> int:
	return int(portti) + int(tie) + int(kivi)


func save_to(cfg: ConfigFile) -> void:
	for k in ["portti", "tie", "kivi", "valmis"]:
		cfg.set_value("raate", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	portti = cfg.get_value("raate", "portti", false)
	tie = cfg.get_value("raate", "tie", false)
	kivi = cfg.get_value("raate", "kivi", false)
	valmis = cfg.get_value("raate", "valmis", false)
