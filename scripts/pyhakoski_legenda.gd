extends RefCounted
## Pyhäkoski (#250 P16): Oulujoen voimalaitoskylä, kolme tarinaa kylän ihmisiltä ja paikoilta. Tiedot "sanotaan"-muodossa, tarkistettava.
## Palkkio kerran, kun kaikki kolme tarinaa on kuultu (mielihyvä ja maine).

const MIELIHYVA := 4.0
const MAINE := 1.0

var voimala := false  # vahtimestarin tarina voimalaitoksesta
var kioski := false  # kioskin tarina
var portaat := false  # tanssipaikan portaiden tarina
var valmis := false  # palkkio annettu


func kuultu() -> int:
	return int(voimala) + int(kioski) + int(portaat)


func save_to(cfg: ConfigFile) -> void:
	for k in ["voimala", "kioski", "portaat", "valmis"]:
		cfg.set_value("pyhakoski", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	voimala = cfg.get_value("pyhakoski", "voimala", false)
	kioski = cfg.get_value("pyhakoski", "kioski", false)
	portaat = cfg.get_value("pyhakoski", "portaat", false)
	valmis = cfg.get_value("pyhakoski", "valmis", false)
