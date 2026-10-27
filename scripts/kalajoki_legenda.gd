extends RefCounted
## Kalajoen juhannus Hiekkasärkillä (#250 P19): rantajalkapallo. Turnausta pelataan juhannuksena; muulloin kentällä voi harjoitella.
## Tiedot "sanotaan"-muodossa, tarkistettava. Palkkio kerran, kun turnaus on voitettu juhannuksena.

const MIELIHYVA := 6.0
const MAINE := 1.0

var sarkat := false  # Hiekkasärkät-kyltti luettu
var jarjestaja := false  # turnauksen järjestäjä puhunut
var harjoitus := 0  # voitetut harjoituspelit (ei juhannus)
var voitot := 0  # voitetut turnaukset (juhannus)
var valmis := false  # palkkio annettu


func save_to(cfg: ConfigFile) -> void:
	for k in ["sarkat", "jarjestaja", "harjoitus", "voitot", "valmis"]:
		cfg.set_value("kalajoki", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	sarkat = cfg.get_value("kalajoki", "sarkat", false)
	jarjestaja = cfg.get_value("kalajoki", "jarjestaja", false)
	harjoitus = cfg.get_value("kalajoki", "harjoitus", 0)
	voitot = cfg.get_value("kalajoki", "voitot", 0)
	valmis = cfg.get_value("kalajoki", "valmis", false)
