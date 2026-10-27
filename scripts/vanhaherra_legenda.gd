extends RefCounted
## Vanha herra (#250 P11): Raahen sataman laiturilla pumpataan ilmaa sukeltajalle, joka etsii pohjalta kapteenin kadonneen taskukellon (sukellus_game.gd).
## Vitriinissä on "Vanha herra", sanotaan maailman vanhin säilynyt sukelluspuku (tarkistettava). Palkkio kerran: mielihyvä ja maine.

const MIELIHYVA := 6.0
const MAINE := 1.0

var nahty := false  # vitriini katsottu
var puhuttu := false  # pumppaajan kanssa puhuttu (tehtävä alkaa)
var sukelluksia := 0
var loytyi := false  # taskukello löytynyt
var paras_roina := 0  # eniten roinaa yhdellä sukelluksella


func save_to(cfg: ConfigFile) -> void:
	for k in ["nahty", "puhuttu", "sukelluksia", "loytyi", "paras_roina"]:
		cfg.set_value("vanhaherra", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	nahty = cfg.get_value("vanhaherra", "nahty", false)
	puhuttu = cfg.get_value("vanhaherra", "puhuttu", false)
	sukelluksia = int(cfg.get_value("vanhaherra", "sukelluksia", 0))
	loytyi = cfg.get_value("vanhaherra", "loytyi", false)
	paras_roina = int(cfg.get_value("vanhaherra", "paras_roina", 0))
