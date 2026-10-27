extends RefCounted
## Hiidenportti (#250 P13): Sotkamon rotkolaakso, kiipeily rotko_game.gd:llä. Paikka ja tiedot "sanotaan"-muodossa, tarkistettava.
## Palkkio kerran: ensimmäinen nousu ylälavalle (mielihyvä ja maine).

const MIELIHYVA := 6.0
const MAINE := 1.0

var kyltti := false  # infotaulu luettu (tehtävä alkaa)
var nousuja := 0
var putoamisia := 0
var ylhaalla := false  # päästy ylös


func save_to(cfg: ConfigFile) -> void:
	for k in ["kyltti", "nousuja", "putoamisia", "ylhaalla"]:
		cfg.set_value("hiidenportti", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	kyltti = cfg.get_value("hiidenportti", "kyltti", false)
	nousuja = int(cfg.get_value("hiidenportti", "nousuja", 0))
	putoamisia = int(cfg.get_value("hiidenportti", "putoamisia", 0))
	ylhaalla = cfg.get_value("hiidenportti", "ylhaalla", false)
