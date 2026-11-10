extends RefCounted
## Pullonkorkkien keräily (#290): merkit, harvinaisuudet ja kerätyt korkit (tallennus). Merkit ovat pelin omia
## parodiamerkkejä. Korkki = "merkki:taso", taso tavallinen / juhla (kesäkorkki, n. 1/15) / virhe (virhepainos, n. 1/150).
## Osa 1: korkki jokaisesta avatusta kaljasta (main.gd _drink). Kansio, vaihto, korkkiläpsy ja legenda tulevat myöhemmin.

const BRANDS := {
	"kontio": {"nimi": "Kontio", "laji": "kalja", "vari": Color(0.15, 0.35, 0.2)},
	"lapin_kuuma": {"nimi": "Lapin Kuuma", "laji": "kalja", "vari": Color(0.75, 0.15, 0.12)},
	"koffi": {"nimi": "Koffi", "laji": "kalja", "vari": Color(0.12, 0.2, 0.55)},
	"jaffis": {"nimi": "Jaffis", "laji": "limu", "vari": Color(0.95, 0.55, 0.1)},
	"kolaa": {"nimi": "Kolaa", "laji": "limu", "vari": Color(0.55, 0.1, 0.1)},
	"pantteri": {"nimi": "Pantteri-limu", "laji": "limu", "vari": Color(0.2, 0.2, 0.22)},
}
const TASOT := ["tavallinen", "juhla", "virhe"]
const TASO_NIMI := {"tavallinen": "korkki", "juhla": "juhannuskorkki", "virhe": "virhepainos"}
const VOITTO_P := 1.0 / 25.0  # kaljakorkin alla "VOITIT PULLON" (90-luvun kampanja)
const JUHLA_P := 1.0 / 15.0
const VIRHE_P := 1.0 / 150.0

var owned := {}  # "merkki:taso" -> kpl
var palkitut: Array = []
var piilossa := false  # kansio kotijemmassa: Päivi ei näe sitä (main.gd _paivi_korkit)  # merkit, joiden täysi aukeama on jo palkittu (kerran)


## Arpoo korkin lajista ("kalja" / "limu"): palauttaa avaimen "merkki:taso".
## juhla_ok: juhannuskorkkeja saa vain juhannuksena (main.gd _juhannus); muulloin arpa antaa tavallisen.
static func roll(laji: String, rng: RandomNumberGenerator, juhla_ok := true) -> String:
	var ids: Array = BRANDS.keys().filter(func(k): return BRANDS[k].laji == laji)
	var b: String = ids[rng.randi() % ids.size()]
	var r := rng.randf()
	var taso := "virhe" if r < VIRHE_P else ("juhla" if r < VIRHE_P + JUHLA_P and juhla_ok else "tavallinen")
	return "%s:%s" % [b, taso]


## Lisää korkin; palauttaa true, jos se on kansiossa uusi.
func add(key: String) -> bool:
	var uusi := not owned.has(key)
	owned[key] = int(owned.get(key, 0)) + 1
	return uusi


static func nimi(key: String) -> String:
	var p := key.split(":")
	return "%s %s" % [BRANDS[p[0]].nimi, TASO_NIMI[p[1]]]


## Erilaisia korkkeja / kaikki mahdolliset (kansion täyttö).
func distinct() -> int:
	return owned.keys().filter(func(k): return k != "mmkorkki").size()  # kultainen MM-korkki on kansilehdessä


static func total_slots() -> int:
	return BRANDS.size() * TASOT.size()


func tuplat() -> int:
	var n := 0
	for k in owned:
		n += maxi(0, int(owned[k]) - 1)
	return n


## Puuttuvat korkit (Korkki-Raimon vaihto: virhepainoksia hän ei vaihda).
func missing(with_virhe := false) -> Array:
	var out: Array = []
	for b in BRANDS:
		for t in TASOT:
			if (with_virhe or t != "virhe") and not owned.has("%s:%s" % [b, t]):
				out.append("%s:%s" % [b, t])
	return out


## Ottaa n tuplaa pois ja palauttaa niiden avaimet (korkkiläpsyn panos); tyhjä, jos ei riitä.
func take_tuplat_keys(n: int) -> Array:
	if tuplat() < n:
		return []
	var out: Array = []
	while out.size() < n:
		var best := ""
		for k in owned:
			if int(owned[k]) > 1 and (best == "" or int(owned[k]) > int(owned[best])):
				best = k
		owned[best] = int(owned[best]) - 1
		out.append(best)
	return out


## Ottaa n tuplaa pois (eniten tuplia ensin). Kansion korkkeja (1 kpl) ei koskaan oteta. Palauttaa false, jos ei riitä.
func take_tuplat(n: int, only_taso := "") -> bool:
	var keys: Array = owned.keys().filter(func(k): return int(owned[k]) > 1 and (only_taso == "" or k.ends_with(":" + only_taso)))
	var have := 0
	for k in keys:
		have += int(owned[k]) - 1
	if have < n:
		return false
	keys.sort_custom(func(a, b): return int(owned[a]) > int(owned[b]))
	while n > 0:
		for k in keys:
			if n > 0 and int(owned[k]) > 1:
				owned[k] = int(owned[k]) - 1
				n -= 1
	return true


## Merkki, jonka kaikki tasot ovat nyt kansiossa ensimmäistä kertaa (palkinto kerran), tai "".
func new_full(brand: String) -> bool:
	if brand in palkitut:
		return false
	for t in TASOT:
		if not owned.has("%s:%s" % [brand, t]):
			return false
	palkitut.append(brand)
	return true


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("korkit", "owned", owned)
	cfg.set_value("korkit", "palkitut", palkitut)
	cfg.set_value("korkit", "piilossa", piilossa)


func load_from(cfg: ConfigFile) -> void:
	owned = cfg.get_value("korkit", "owned", {})
	palkitut = cfg.get_value("korkit", "palkitut", [])
	piilossa = cfg.get_value("korkit", "piilossa", false)
