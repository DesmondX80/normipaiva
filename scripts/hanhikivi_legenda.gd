extends RefCounted
## Legenda: Hanhikiven rajakivi (#250, P4). Oikea tausta (pyynnön mukaan, tarkistettava): Hanhikivi on Pyhäjoen kivi ja
## vaakunan aihe, ja Koskipuisto ja Hourunkosken kosket ovat samalla seudulla. Rajakiviteoria on epävarma: sanotaan,
## että kivi olisi ennen merkinnyt pitäjien rajaa ja jokin siirtänyt sen. Peli ei väitä sitä faktana: kaikki esitetään
## huhuna ("sanotaan", "kuulemma"), eikä kukaan tiedä, kuka kiven siirsi.
## Ketju: taksikuski kertoo (heard) -> Kapteenin Kulman kapteeni muistaa vanhan merimiesjutun (kapteeni) ->
## Koskipuiston kyltti kertoo kiven vanhasta paikasta (kyltti) -> kivellä, kun molemmat vihjeet on kuultu (found):
## loppu "Hanhikiven rajakivi", ei palkkiota rahana, vain maine ja mielihyvä (kerran).

const MAINE := 3.0

var heard := false
var kapteeni := false  # vihje 1: Kapteenin Kulman kapteeni
var kyltti := false  # vihje 2: Koskipuiston kyltti
var found := false


## Molemmat vihjeet kuultu: kivellä voi tehdä päätelmän.
func clues() -> bool:
	return kapteeni and kyltti


func save_to(cfg: ConfigFile) -> void:
	for k in ["heard", "kapteeni", "kyltti", "found"]:
		cfg.set_value("hanhikivi", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["heard", "kapteeni", "kyltti", "found"]:
		set(k, cfg.get_value("hanhikivi", k, false))
