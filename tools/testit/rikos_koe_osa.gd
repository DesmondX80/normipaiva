extends "res://scripts/rikos/osa.gd"
## Testin oma riskiosa (tools/testit/riskit.gd --riski=perus): kirjaa, mitä main.gd:n koukut kutsuivat, ja vastaa
## jokaiseen koukkuun tunnistettavalla arvolla. Ei pelissä (ei RIKOS_OSAT-listassa).

var kutsut: Array = []  # [koukku, lisätieto]
var arvo := 7  # tallennettava luku
var kiinni := false


func _init() -> void:
	talkers = ["kaukalo_poika"]


func tick(e: bool) -> void:
	if kutsut.is_empty() or kutsut[-1][0] != "tick":
		kutsut.append(["tick", e])


func hello(who: String) -> String:
	return "KOE terve" if who == "kaukalo_poika" else ""


func options(who: String, o: Array) -> void:
	if who == "kaukalo_poika":
		o.append(game._opt("koe_valinta", "KOE valinta"))


func choose(id: String) -> bool:
	if id == "koe_valinta":
		kutsut.append(["choose", id])
		return true
	return false


func on_event(ev: String, data: Dictionary) -> void:
	kutsut.append([ev, data])


func aamu(at_m: bool) -> String:
	kutsut.append(["aamu", at_m])
	return "KOE aamu"


func riskit() -> Dictionary:
	return {"otsikko": "Koe", "mittari": 0.6, "rivit": ["KOE rivi yksi, joka on niin pitkä, että se rivittyy sivun leveydessä kahdelle riville.", "KOE rivi kaksi"]}


func luukku_kiinni() -> String:
	return "KOE luukku kiinni" if kiinni else ""


func fight_end(won: bool) -> String:
	kutsut.append(["fight_end", won])
	return "KOE tappelu ohi"


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("rikos_koe", "arvo", arvo)


func load_from(cfg: ConfigFile) -> void:
	arvo = int(cfg.get_value("rikos_koe", "arvo", 0))


func oli(koukku: String) -> bool:
	for k in kutsut:
		if k[0] == koukku:
			return true
	return false
