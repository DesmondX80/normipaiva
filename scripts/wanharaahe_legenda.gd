extends RefCounted
## Wanha Raahe -kävelykierros (#250 P8): viisi pysähdystä järjestyksessä, jokaisesta otetaan valokuva (retki_wanharaahe.gd).
## Ovikuva (pysähdys 2) viedään Päiville kotiin: kerran, mielihyvä. Koko kierroksesta maine. Nimet ja vuodet "sanotaan"-muodossa, tarkistettava.

const MAINE := 2.0
const OVIKUVA_MIELIHYVA := 8.0
const STOPS := ["patsas", "ovet", "kauppiaantalo", "kuja", "makasiini"]  # kiertojärjestys

var kuvat: Array = []  # otetut pysähdykset (id:t)
var ovikuva := false  # ovikuva taskussa (ei vielä annettu Päiville)
var annettu := false  # ovikuva annettu Päiville
var valmis := false  # kaikki viisi kuvattu, palkkio annettu


func next_id() -> String:
	for id in STOPS:
		if not kuvat.has(id):
			return id
	return ""


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("wanharaahe", "kuvat", kuvat)
	for k in ["ovikuva", "annettu", "valmis"]:
		cfg.set_value("wanharaahe", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	kuvat = Array(cfg.get_value("wanharaahe", "kuvat", []))
	for k in ["ovikuva", "annettu", "valmis"]:
		set(k, cfg.get_value("wanharaahe", k, false))
