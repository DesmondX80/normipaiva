extends RefCounted
## Legenda: Rautaruukin peruskivi (#250, P6). Oikea tausta (pyynnön mukaan, tarkistettava): Rautaruukin Raahen terästehtaan
## Rojuniemen peruskiven sanotaan paljastetun 25.8.1962 (Kekkonen), ja ensimmäinen lähetys on sanotaan 5.9.1964.
## Kätkö on keksitty (kuten Tokolan aarre, tokola.gd): peli ei väitä, että kiven alla olisi mitään. Kaikki "sanotaan"-muodossa.
## Ketju: taksikuski kertoo (heard) -> ruukin vartija muistaa, että kiven edessä laatta on joskus ollut löysällä (vartija) ->
## Rojuniemen opaskyltti kertoo vuosiluvut ja kapselin paikan (kyltti) -> laatta kiven edessä, kun molemmat on kuultu:
## kätkö aukeaa (found), löytäjänpalkkio ja maine. Palkkio vain kerran: `found`-lippu.

const MAINE := 3.0
const RAHA := 30.0

var heard := false
var vartija := false  # vihje 1: ruukin vartija
var kyltti := false  # vihje 2: opaskyltti
var found := false


func clues() -> bool:
	return vartija and kyltti


func save_to(cfg: ConfigFile) -> void:
	for k in ["heard", "vartija", "kyltti", "found"]:
		cfg.set_value("peruskivi", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["heard", "vartija", "kyltti", "found"]:
		set(k, cfg.get_value("peruskivi", k, false))
