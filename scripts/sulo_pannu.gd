extends RefCounted
## Legenda: Sulon isän kadonnut pannu (#130). Pannu-Sulon isä, Vanha Sulo, oli pitäjän paras keittäjä. Kun poliisi
## teki ratsian 1960-luvulla, hän upotti kuparisen pannunsa Pilkkarinnevan rämeeseen, eikä sitä koskaan löydetty.
## Kylällä juttua pidetään kaljapuheena, ja Sulo itse kiistää kaiken. Pelissä legenda on totta:
## Aaro kertoo (heard) -> drooni näkee rämeellä kuparin vihreän läikän (spotted, merkki karttaan) -> kahlataan ja
## kaivetaan (found) -> valinta: pannu Sululle (isän resepti: parempi kanisteri), Saloisten Pirtin museoon (maine,
## Sulo suuttuu) tai Taunolle romuksi (rahaa, Sulo ja Aaro suuttuvat).

## Pannun paikka Pilkkarinnevalla (map_osm.gd BOGS, rämeen sisällä).
const SPOT := Vector2(395, 1118)
const RESEPTI_BEERS := 32  # isän reseptillä keitetty kanisteri vastaa näin montaa kaljaa (tavallinen 24)
const ANGRY_PRICE := 10.0  # suuttunut Sulo nostaa kanisterin hintaa

var heard := false
var spotted := false
var found := false
var choice := ""  # "" / "sulo" / "museo" / "romu"


## Sulo suuttui (pannu meni muualle kuin hänelle).
func sulo_angry() -> bool:
	return choice in ["museo", "romu"]


## Legenda todistettu kylälle (Sulo myöntää): pannu löytyi eikä mennyt romuksi.
func proven() -> bool:
	return choice in ["sulo", "museo"]


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("sulon_pannu", "kuultu", heard)
	cfg.set_value("sulon_pannu", "nahty", spotted)
	cfg.set_value("sulon_pannu", "loytynyt", found)
	cfg.set_value("sulon_pannu", "valinta", choice)


func load_from(cfg: ConfigFile) -> void:
	heard = cfg.get_value("sulon_pannu", "kuultu", false)
	spotted = cfg.get_value("sulon_pannu", "nahty", false)
	found = cfg.get_value("sulon_pannu", "loytynyt", false)
	choice = cfg.get_value("sulon_pannu", "valinta", "")
