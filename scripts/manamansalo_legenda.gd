extends RefCounted
## Legenda: Manamansalon muistokirkko ja "kuolemansaari" (#250, P7). Oikea tausta (pyynnön mukaan, tarkistettava): Manamansalo on
## Oulujärven suurin saari Vaalassa, ja sen sanotaan olleen metsästäjien hautausmaasaari. Kainuun ensimmäisen kirkon sanotaan
## rakennetun saarelle 1559. Nimen "kuolemansaari" tulkinta on epävarma: peli esittää sen vain oppaan tulkintana.
## Ketju: taksikuski kertoo (heard) -> opas kirkolla kertoo 1559-tarinan (opas) -> infotaulu hautausmaalla (kyltti) -> kirkon
## kivijalan jäänteet mäellä, kun molemmat on kuultu: legendan loppu (found), maine. Ei rahaa, tarina on palkkio.

const MAINE := 3.0

var heard := false
var opas := false  # vihje 1: opas kirkolla
var kyltti := false  # vihje 2: infotaulu
var found := false


func clues() -> bool:
	return opas and kyltti


func save_to(cfg: ConfigFile) -> void:
	for k in ["heard", "opas", "kyltti", "found"]:
		cfg.set_value("manamansalo", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["heard", "opas", "kyltti", "found"]:
		set(k, cfg.get_value("manamansalo", k, false))
