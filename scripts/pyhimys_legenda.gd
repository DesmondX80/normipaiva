extends RefCounted
## Legenda: Palon yön pyhimys (#125). Oikea tausta (Wikipedia, Saloisten kirkko): vanha puukirkko paloi loppiaisaamun
## jumalanpalveluksen aikana 1930 (issuen "1908" ei löydy lähteestä), nykyinen kirkko valmistui 1932, ja palosta
## pelastettiin mm. Pyhän Olavin ja Neitsyt Marian veistokset ja alttarikaapit, jotka ovat yhä tallessa.
## Legenda on keksitty ja pelissä totta: palon yönä yksi pieni puinen pyhimys katosi, kun talollinen vei sen kotiinsa
## "turvaan" eikä uskaltanut palauttaa. Hautausmaan hoitaja kertoo (heard) -> suntio näyttää seurakunnan luettelon,
## jossa yliviivattu rivi "pieni pyhimyskuva, puuta" (luettelo) -> palon vuosipäivän illalla hautausmaalla palaa
## kynttilä, jonka sytyttää talollisen lapsenlapsi (kynttila) -> hän kertoo, kun lupaa pitää suvun nimen salassa
## (lupaus): suku asui Tokolassa -> Aaro muistaa mummon aitan pyhän nuken (aitta) -> pyhimys Tokolan varaston orsilta
## (found) -> suntiolle kirkkoon (returned). Palon vuosipäivä pelissä on joka kuudes päivä (6. = loppiainen).

const VUOSIPAIVA_VALI := 6
const KYNTTILA := Vector2(18 * 60, 23 * 60)
const MAINE := 10.0

var heard := false
var luettelo := false
var kynttila := false  # nainen tavattu kynttilän luona
var lupaus := false
var aitta := false  # Aaro muistaa aitan
var found := false
var returned := false


func vuosipaiva(day: int) -> bool:
	return day % VUOSIPAIVA_VALI == 0


func proven() -> bool:
	return returned


func save_to(cfg: ConfigFile) -> void:
	for k in ["heard", "luettelo", "kynttila", "lupaus", "aitta", "found", "returned"]:
		cfg.set_value("pyhimys", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["heard", "luettelo", "kynttila", "lupaus", "aitta", "found", "returned"]:
		set(k, cfg.get_value("pyhimys", k, false))
