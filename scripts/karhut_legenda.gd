extends RefCounted
## Kuhmon karhut (#250 P12): karhukätkössä odotetaan hämärässä ja kuvataan karhua (karhu_game.gd). Humala heiluttaa kameraa.
## Paikka ja aukioloajat "sanotaan"-muodossa, tarkistettava. Palkkio kerran: ensimmäinen hyvä kuva (mielihyvä ja maine).

const MIELIHYVA := 6.0
const MAINE := 1.0
const GOOD := 60  # hyvän kuvan pisterajä

var opas := false  # kätkön oppaan kanssa puhuttu (tehtävä alkaa)
var yrityksia := 0
var paras := 0  # paras kuva (0-100)
var hyva := false  # hyvä kuva otettu


func save_to(cfg: ConfigFile) -> void:
	for k in ["opas", "yrityksia", "paras", "hyva"]:
		cfg.set_value("karhut", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	opas = cfg.get_value("karhut", "opas", false)
	yrityksia = int(cfg.get_value("karhut", "yrityksia", 0))
	paras = int(cfg.get_value("karhut", "paras", 0))
	hyva = cfg.get_value("karhut", "hyva", false)
