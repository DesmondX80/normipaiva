extends RefCounted
## Pekan vintin romulaatikko kirppikselle. Kun pelaaja on kerran myynyt omalla kirppispöydällä, Pekka tarjoaa
## laatikollisen vanhaa tavaraa ("Vie kirppikselle, puolet mulle"). Tavarat myydään kuten marjat omalla pöydällä
## (kirppis_myynti_game.gd, romu-tuotteet), ja puolet tuloista on Pekan. Saman päivän tilitys ilahduttaa Pekkaa
## (maine +2 ja seuraava kyyti ilmainen). Jos Pekan osuus jää yön yli maksamatta, Pekka on suuttunut: ei kyytiä
## Raaheen, ennen kuin rahat tulevat. Myymättömät tavarat jäävät laatikkoon seuraaville päiville.

## Laatikon sisältö: tuote -> määrä (hinnat ja nimet kirppis_myynti_game.gd GOODS).
const START := {"lp": 3, "pokaali": 1, "karvalakki": 1, "vieherasia": 1, "taulu": 1, "kahvimylly": 1}
const SHARE := 0.5  # Pekan osuus myynnistä
const ON_TIME_REP := 2.0  # saman päivän tilitys: maine

var given := false
var left := {}  # laatikossa jäljellä: tuote -> määrä
var owed := 0.0  # Pekan osuus myydyistä, tilittämättä
var owed_day := -1  # päivä, jona tilittämätön myynti alkoi
var free_ride := false  # saman päivän tilityksen palkka: seuraava kyyti Raaheen ilmainen
var paid_total := 0.0
var late_count := 0  # myöhästyneet tilitykset


func give() -> void:
	given = true
	left = START.duplicate()


func count() -> int:
	var n := 0
	for k in left:
		n += int(left[k])
	return n


func is_item(id: String) -> bool:
	return START.has(id)


## Myynti kirppispöydältä: sold = {tuote: määrä}, income_by = {tuote: €}. Palauttaa Pekan osuuden tästä myynnistä.
func record_sale(sold: Dictionary, income_by: Dictionary, day: int) -> float:
	var share := 0.0
	for k in sold:
		if not is_item(k):
			continue
		left[k] = maxi(0, int(left.get(k, 0)) - int(sold[k]))
		if int(left[k]) <= 0:
			left.erase(k)
		share += float(income_by.get(k, 0.0)) * SHARE
	share = snappedf(share, 0.5)
	if share > 0.0:
		if owed <= 0.0:
			owed_day = day
		owed += share
	return share


## Pekka on suuttunut: osuus on ollut maksamatta yön yli.
func angry(day: int) -> bool:
	return owed > 0.0 and day > owed_day


## Tilitys: palauttaa {"amount": €, "on_time": bool}. Saman päivän tilitys antaa ilmaisen kyydin.
func pay(day: int) -> Dictionary:
	var on_time := not angry(day)
	var amount := owed
	paid_total += amount
	owed = 0.0
	owed_day = -1
	if on_time:
		free_ride = true
	else:
		late_count += 1
	return {"amount": amount, "on_time": on_time}


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("pekan_laatikko", "annettu", given)
	cfg.set_value("pekan_laatikko", "jaljella", left)
	cfg.set_value("pekan_laatikko", "velka", owed)
	cfg.set_value("pekan_laatikko", "velka_paiva", owed_day)
	cfg.set_value("pekan_laatikko", "ilmainen_kyyti", free_ride)
	cfg.set_value("pekan_laatikko", "tilitetty", paid_total)
	cfg.set_value("pekan_laatikko", "myohassa", late_count)


func load_from(cfg: ConfigFile) -> void:
	given = cfg.get_value("pekan_laatikko", "annettu", false)
	left = cfg.get_value("pekan_laatikko", "jaljella", {})
	owed = cfg.get_value("pekan_laatikko", "velka", 0.0)
	owed_day = cfg.get_value("pekan_laatikko", "velka_paiva", -1)
	free_ride = cfg.get_value("pekan_laatikko", "ilmainen_kyyti", false)
	paid_total = cfg.get_value("pekan_laatikko", "tilitetty", 0.0)
	late_count = cfg.get_value("pekan_laatikko", "myohassa", 0)
