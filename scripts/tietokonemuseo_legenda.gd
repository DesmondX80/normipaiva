extends RefCounted
## Saloisten tietokonemuseo (#250 P10): intendentti kertoo koneista, Pong-kone on pelattavissa. Voitot ja ennätys säilyvät käyntien välillä.
## Faktat (Datasaab D22 1971, heinäkuun aukioloaika) "sanotaan"-muodossa, tarkistettava; museo avoinna aina pelissä.

const MIELIHYVA := 6.0  # ensimmäinen voitto

var intendentti := false  # puhuttu intendentin kanssa
var voitot := 0  # Pong-voitot
var parhaat := 0  # paras pistemäärä (omat pisteet ottelun voitossa tai tappiossa)


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("tietokonemuseo", "intendentti", intendentti)
	cfg.set_value("tietokonemuseo", "voitot", voitot)
	cfg.set_value("tietokonemuseo", "parhaat", parhaat)


func load_from(cfg: ConfigFile) -> void:
	intendentti = cfg.get_value("tietokonemuseo", "intendentti", false)
	voitot = int(cfg.get_value("tietokonemuseo", "voitot", 0))
	parhaat = int(cfg.get_value("tietokonemuseo", "parhaat", 0))
