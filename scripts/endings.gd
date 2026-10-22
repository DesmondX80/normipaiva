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
	["mokkibileet", "Mökkibileet", "Paapelin kotiviini, Santtu, Sinikka ja Korpi-Kalle. Herätys jostain krapulassa."],
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
	["eramaan_laavu", "Erämaan laavu", "Viitajärven laavulla nuotio, makkara ja kalja. Kukaan ei tiedä, missä oot."],
	["uutiset", "Kymppiuutiset nauhalta", "Video ajastettu, kalja eteisen kaapista ja sohvalle. Päivi nukkuu jo."],
	["aarnivalkea", "Isonvihan hopeat", "Lapinraunion aarnivalkea paloi oikean aarteen päällä. Hilkka oli oikeassa."],
	["kertun_rauta", "Viimeisen sepän kirves", "Kertunkankaan legenda todistettu: Raimo oli oikeassa, ja Veikko tarjosi."],
	["tekojarven_ukko", "Tekojärven Ukko", "18,4 kilon hauki täytettynä Saloisten Pirtissä. Tauno itki vähän."],
	["drakkar", "Drakkar Noir", "Ysärin legendaarinen tuoksu Railin kirppispöydältä. Puolikas pullo, ja koko Saloinen haistaa."],
	["palon_pyhimys", "Palon yön pyhimys", "Pieni puinen pyhimys palasi kirkkoon 1930-luvun palon jälkeen. Suvun nimi pysyi salassa, ja kynttilä sammui."],
	["olavinmarkkinat", "Olavinmarkkinat palasivat", "Kauppias Skytän hopea löytyi 1616 vuoden taalereina. Olavi-pappa avasi markkinat, ja Pekka osti tervatuopin."],
	["kuninkaan_tapuli", "Kuninkaan tapuli", "Kustaa III:n sinetöity piirustus löytyi tapulin palkista. Raahen museo vahvisti, ja Pekka tarjosi kierroksen."],
	["kanttorin_virsi", "Kanttorin virsi", "Kanttorilan yösävel löysi nuottinsa: Sinikan kuoro lauloi virren seuraintalolla, ja urut vaikenivat."],
	["ukko_vapaa", "Ukko vapaaksi", "Tekojärven Ukko ui takaisin ladon raunioille. Tauno tarjosi kahvit."],
]

## Oikeat onnelliset loput: päivä päättyy loppukohtaukseen (juhlat tallissa, viinibileet, laavu). Muut ovat
## legendaarisia hetkiä: saavutuksia, joiden jälkeen peli jatkuu.
const LOPUT := ["juhlat", "viinibileet", "laavu", "legendaarinen", "mokkibileet", "eramaan_laavu", "uutiset"]

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


static func is_loppu(id: String) -> bool:
	return id in LOPUT


## kind: "" = kaikki, "loppu" = onnelliset loput, "hetki" = legendaariset hetket.
static func _kind_ok(id: String, kind: String) -> bool:
	return kind == "" or (kind == "loppu") == is_loppu(id)


func distinct(kind := "") -> int:
	return counts.keys().filter(func(k): return _kind_ok(k, kind)).size()


func total(kind := "") -> int:
	var n := 0
	for k in counts:
		if _kind_ok(k, kind):
			n += int(counts[k])
	return n


static func max_count(kind := "") -> int:
	return ENDINGS.filter(func(e): return _kind_ok(e[0], kind)).size()


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
