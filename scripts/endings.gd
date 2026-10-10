extends RefCounted
## Onnellisten loppujen kokoelma (#132): erilaiset onnelliset loput, kerrat ja ensimmäisen kerran päivä.
## Päiväkirjassa (journal.gd) näkyy "Erilaisia onnellisia loppuja X / Y" (löytämättömät ???) ja kaikkien loppujen
## yhteismäärä. main.gd kirjaa lopun _ending(id):llä. Vanhat laskurit (jemma_endings, wine_endings) muunnetaan
## ensimmäisellä latauksella.

## Järjestyksessä: [id, nimi, kuvaus].
const ENDINGS := [
	["juhlat", "Juhlat autotallissa", "Kotijemmassa 24 kaljaa, ja kaverit kylään."],
	["viinibileet", "Viinibileet", "Kotiviini kypsyi saavissa: Pekka, Arto ja Sinikka autotalliin."],
	["laavu", "Laavulla kaljoilla", "Laavu vallattu, kalja auki Antinsuonkankaalla."],
	["legendaarinen", "Legendaarinen normipäivä", "Nuotio, makkara ja kalja laavulla auringonlaskussa."],
	["paapeli", "Paapeliin Pekan kyydillä", "Naapurin hommat tehty, avaimet löytyi, ja Volvo kaahaa mökille."],
	["savusauna", "Savusaunan löylyt", "Korjattu savusauna, pehmeät löylyt ja järvi perään."],
	["lavatanssit", "Lavatanssit Oulujärvellä", "Humppaveikot soitti, ja jalka nousi kuin nuorena."],
	["karaoke", "Karaokekuningas", "Yleisö taputti, ja baarimikko tarjosi."],
	["kiihdytys", "Kiihdytyksen voittaja", "Vaalantien suoralla mopopojat jäi toiseksi."],
	["sahkopyora", "Saloislainen sähköpyörä", "Ruuveilla, teipillä ja toivolla kasattu sähköpyörä kulkee."],
	["tanssit", "Seuraintalon tanssit", "Saapasjalat soitti, ja tanssi sujui."],
	["kinkku", "Bingon jättipotti", "Joulukinkku seuraintalon bingosta. Mummot ei anna ikinä anteeks."],
	["tokolan_aarre", "Tokolan kauppiaan aarre", "Legenda todistettu: Aaro oli oikeassa."],
	["sulon_pannu", "Vanhan Sulon pannu", "Kuparipannu nousi Pilkkarinnevalta, ja Sulo myönsi."],
	["piirakkakuningas", "Lihapiirakkakuningas", "Reipparin ennätystauluun uusi nimi. Juntti ei usko."],
]

var counts := {}  # id -> kerrat
var first_day := {}  # id -> päivä, jolloin saatu ensimmäisen kerran


static func name_of(id: String) -> String:
	for e in ENDINGS:
		if e[0] == id:
			return e[1]
	return id


## Kirjaa lopun; palauttaa true, jos se oli uusi (ensimmäinen kerta).
func record(id: String, day: int) -> bool:
	var new := not counts.has(id)
	counts[id] = int(counts.get(id, 0)) + 1
	if new:
		first_day[id] = day
	return new


func distinct() -> int:
	return counts.size()


func total() -> int:
	var n := 0
	for k in counts:
		n += int(counts[k])
	return n


static func max_count() -> int:
	return ENDINGS.size()


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("loput", "kerrat", counts)
	cfg.set_value("loput", "eka_paiva", first_day)


## Lataus; ilman tallennettua kokoelmaa vanhat laskurit muunnetaan (päivää ei tiedetä: 0).
func load_from(cfg: ConfigFile, jemma_endings: int, wine_endings: int) -> void:
	if cfg.has_section_key("loput", "kerrat"):
		counts = cfg.get_value("loput", "kerrat", {})
		first_day = cfg.get_value("loput", "eka_paiva", {})
		return
	counts = {}
	first_day = {}
	if jemma_endings > 0:
		counts["juhlat"] = jemma_endings
		first_day["juhlat"] = 0
	if wine_endings > 0:
		counts["viinibileet"] = wine_endings
		first_day["viinibileet"] = 0
