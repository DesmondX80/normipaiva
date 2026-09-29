extends RefCounted
## Päivittäiset tilat (#18). Joka päivä arvotaan kolme tilaa kymmenestä, ja päivän lopussa niiden summa ratkaisee:
## alle 0 = huono päivä (seuraava hankalampi), vähintään GOOD_DAY = hyvä päivä (seuraava helpompi).
## Kaikissa tiloissa suurempi on parempi: "negatiiviset" (stressi, nälkä, väsymys, kipu) alkavat -1:stä ja niitä
## yritetään nostaa, positiiviset alkavat 0:sta. Humalatila (0..1) säilyy yön yli ja laskee yössä 0,2.
## Vaikutukset pelin toiminnoista kirjataan main.gd:ssä (ks. README, "Päivittäiset tilat").

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
const GOOD_DAY := 1.0
const HANGOVER := 0.2  # yö laskee humalatilaa

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
