extends RefCounted
## Legenda: Lapinraunion aarnivalkea (#139). Kansanperinteen aarnivalkea, sininen liekki aarteen päällä. Kylän
## vanhojen mukaan Lapinraunion luona palaa öisin aarnivalkea, koska Isonvihan aikaan talolliset kätkivät hopeansa
## raunion lähelle kasakoilta. Kylällä juttua pidetään satuna. Pelissä legenda on totta:
## Mummo Hilkka kertoo (heard) -> yöllä raunion luona sininen liekki: Pannu-Sulo kaasupolttimineen (sulo) ->
## Saloisten Pirtin vanha käräjäpöytäkirja (poytakirja) -> oikea liekki sammaloituneen kivikasan kohdalla yöllä
## (liekki) tai droonin yökuva (spotted) -> hopeat kivikasan alta (found) -> Pirttiin (todistus, loppu) tai Veksille
## (rahaa, poliisi). Rauniota ei kaiveta. Liekki, hopeat ja legenda ovat keksittyjä.

const NIGHT := Vector2(22 * 60, 4 * 60)
const KERAILIJA_HINTA := 180.0
const MUSEO_PALKKIO := 50.0
const MUSEO_MAINE := 12.0

var heard := false
var sulo := false  # Pannu-Sulo yllätetty raunion luona
var poytakirja := false
var liekki := false  # oikea aarnivalkea nähty
var spotted := false  # droonin yökuva
var found := false
var choice := ""  # "" / "museo" / "kerailija"
var poliisi := false


func proven() -> bool:
	return choice == "museo"


func save_to(cfg: ConfigFile) -> void:
	for k in ["heard", "sulo", "poytakirja", "liekki", "spotted", "found", "choice", "poliisi"]:
		cfg.set_value("aarnivalkea", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["heard", "sulo", "poytakirja", "liekki", "spotted", "found", "poliisi"]:
		set(k, cfg.get_value("aarnivalkea", k, false))
	choice = cfg.get_value("aarnivalkea", "choice", "")
