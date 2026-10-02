extends RefCounted
## Päivittäiset tilat (#18). Joka päivä arvotaan kolme tilaa kymmenestä. Tilat nollautuvat joka aamu, eikä eilinen
## vaikuta tähän päivään, paitsi humala: illalla yli HANGOVER_LIMIT tulee krapula-aamu (main.gd _end_day_stats).
## Kaikissa tiloissa suurempi on parempi: "negatiiviset" (stressi, nälkä, väsymys, kipu) alkavat -1:stä ja niitä
## yritetään nostaa, positiiviset alkavat 0:sta. Humalatila (0..1) säilyy yön yli ja laskee yössä 0,2.
## Vaikutukset pelin toiminnoista kirjataan main.gd:ssä (ks. README, "Päivittäiset tilat").
## Jokaisella tilalla on oma palkinto ja haitta (effect), jotka ovat päällä heti rajan ylittyessä.

const STATS := {
	"stressi": {"name": "Stressi", "neg": true},
	"nalka": {"name": "Nälkä", "neg": true},
	"vasymys": {"name": "Väsymys", "neg": true},
	"kipu": {"name": "Kipu", "neg": true},
	"stamina": {"name": "Stamina", "neg": false},
	"vireys": {"name": "Vireys", "neg": false},
	"moraali": {"name": "Moraali", "neg": false},
	"keskittyminen": {"name": "Keskittyminen", "neg": false},
	"kokemus": {"name": "Kokemus (XP)", "neg": false},
	"humala": {"name": "Humalatila", "neg": false},
}
const PICK := 3
const HANGOVER_LIMIT := 0.8  # illan humala tämän yli -> krapula-aamu
const HANGOVER := 0.2  # yö laskee humalatilaa
const REWARD := 0.5  # tästä ylöspäin tilan palkinto on päällä (effect)
const PENALTY := -0.5  # tästä alaspäin tilan haitta on päällä

var values := {}
var chosen: Array = []
## Ensikerrat, jotka on jo tehty (kokemus kasvaa vain ensimmäisellä kerralla). Tallentuu.
var firsts: Array = []


func _init() -> void:
	for k in STATS:
		values[k] = 0.0
	reset()


## Uusi päivä: humalatila laskee, muut nollautuvat, ja arvotaan päivän kolme tilaa.
func reset() -> void:
	for k in STATS:
		if k == "humala":
			values[k] = maxf(0.0, values[k] - HANGOVER)
		else:
			values[k] = -1.0 if STATS[k].neg else 0.0
	var keys: Array = STATS.keys()
	keys.shuffle()
	chosen = keys.slice(0, PICK)


## Tila mukaan päivän kolmen joukkoon (esim. mökillä humalatila aina): korvaa viimeisen, jos ei jo mukana.
func ensure(key: String) -> void:
	if key in chosen:
		return
	chosen[chosen.size() - 1] = key


func add(key: String, amount: float) -> void:
	values[key] = clampf(values[key] + amount, 0.0 if key == "humala" else -1.0, 1.0)


func value(key: String) -> float:
	return values[key]


## Ensimmäinen kerta: kokemus kasvaa. Palauttaa true, jos toiminto oli uusi.
func first(action: String, xp := 0.2) -> bool:
	if action in firsts:
		return false
	firsts.append(action)
	add("kokemus", xp)
	return true


## Tilan palkinto tai haitta (main.gd _stat_effects): 1 = palkinto (arvo >= REWARD), -1 = haitta (<= PENALTY),
## 0 = ei kumpaakaan. Vain päivän kolme tilaa vaikuttavat. Humalatila (0..1): palkinto 0,3–0,6, haitta yli 0,8.
func effect(key: String) -> int:
	if not key in chosen:
		return 0
	var v: float = values[key]
	if key == "humala":
		return 1 if v >= 0.3 and v <= 0.6 else (-1 if v > 0.8 else 0)
	return 1 if v >= REWARD else (-1 if v <= PENALTY else 0)


## Päivän kolmen tilan summa.
func score() -> float:
	var s := 0.0
	for k in chosen:
		s += values[k]
	return s


## Päivän yhteenveto: "Stressi +0,3 · Moraali -0,2 · ... = +0,1".
func summary() -> String:
	var parts: Array[String] = []
	for k in chosen:
		parts.append("%s %s" % [STATS[k].name, fmt(values[k])])
	return " · ".join(parts) + " = " + fmt(score())


static func fmt(v: float) -> String:
	return ("%+.1f" % v).replace(".", ",")


func save_to(cfg: ConfigFile) -> void:
	for k in STATS:
		cfg.set_value("tilat", k, values[k])
	cfg.set_value("tilat", "valitut", chosen)
	cfg.set_value("tilat", "ensikerrat", firsts)


func load_from(cfg: ConfigFile) -> void:
	for k in STATS:
		values[k] = cfg.get_value("tilat", k, values[k])
	var c: Array = cfg.get_value("tilat", "valitut", [])
	if c.size() == PICK:
		chosen = c
	firsts = cfg.get_value("tilat", "ensikerrat", [])
