extends RefCounted
## Legenda: Tekojärven Ukko. Haapajärven tekojärvi padottiin 1970-luvulla, ja veden alle jäi vanhoja peltoja ja
## latoja. Kirppiksen Taunon mukaan hänen isänsä kalasti paikalla jo ennen patoa, ja tekojärven pohjalla, vanhan
## ladon raunioilla, elää valtava hauki: Ukko. Se vie uistimet ja kerran kiskoi soutuveneen kaislikkoon. Kylällä
## juttua pidetään kaljapuheena. Pelissä legenda on totta:
## Tauno kertoo (heard) -> virvelillä tekojärvellä jokin valtava katkaisee siiman (siimat, vihje) ja/tai droonin
## iltakuvassa vedessä on suuri varjo (spotted) -> Tauno myy isänsä vanhan kuparilusikan (lusikka) -> illalla
## Kaitasaaren kärjestä Ukko koukkuun (caught) -> Saloisten Pirttiin täytettäväksi (museo, loppu), Veksille
## (rahaa, Puskaradio) tai takaisin järveen (vapaa, loppu: Tauno kiittää). Tekojärvi on oikea paikka (Raahen
## kyläkortti: kalastus- ja ulkoilumahdollisuudet); Ukko, Taunon isä ja lusikka ovat keksittyjä.

const ILTA := Vector2(19 * 60, 23 * 60)
const LUSIKKA_HINTA := 8.0
const KERAILIJA_HINTA := 150.0
const MUSEO_PALKKIO := 40.0
const MUSEO_MAINE := 10.0

var heard := false
var siimat := 0  # Ukon katkaisemat siimat
var spotted := false  # droonin iltakuva: valtava varjo
var lusikka := false
var caught := false
var choice := ""  # "" / "museo" / "kerailija" / "vapaa"


## Vihjeitä tarpeeksi, että Tauno uskoo ja myy lusikan.
func clues() -> bool:
	return siimat >= 2 or spotted  # kaksi katkennutta siimaa tai droonin varjokuva


func proven() -> bool:
	return choice in ["museo", "vapaa"]


func save_to(cfg: ConfigFile) -> void:
	for k in ["heard", "siimat", "spotted", "lusikka", "caught", "choice"]:
		cfg.set_value("ukko", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["heard", "spotted", "lusikka", "caught"]:
		set(k, cfg.get_value("ukko", k, false))
	siimat = cfg.get_value("ukko", "siimat", 0)
	choice = cfg.get_value("ukko", "choice", "")
