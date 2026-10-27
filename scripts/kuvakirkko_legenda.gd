extends RefCounted
## Paltaniemen kuvakirkko (#250 P9): kuusi piilokuvaa kirkon maalauksissa (kuvakirkko_game.gd). Löydöt säilyvät käyntien välillä;
## kun kaikki on löydetty, tulee palkinto kerran (maine). Faktat "sanotaan"-muodossa, tarkistettava.

const MAINE := 2.0
const TOTAL := 6  # kuvakirkko_game.gd ITEMS

var found: Array = []  # löydetyt piilokuvat (id:t)
var valmis := false  # kaikki löydetty, palkinto annettu
var suntio := false  # puhuttu suntion kanssa


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("kuvakirkko", "found", found)
	for k in ["valmis", "suntio"]:
		cfg.set_value("kuvakirkko", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	found = Array(cfg.get_value("kuvakirkko", "found", []))
	for k in ["valmis", "suntio"]:
		set(k, cfg.get_value("kuvakirkko", k, false))
