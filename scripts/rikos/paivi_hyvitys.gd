extends "res://scripts/rikos/osa.gd"
## Luku 6 "Päivi epäilee" (#326), erä C: hyvitykset. main.gd lähettää "paivi_hyvitys" {why}, kun pelaaja tekee Päiville
## jotain hyvää; tämä osa laskee Päivin epäluuloa (rikos/paivi.gd lisaa). Hyvitys toimii vain jäljen jälkeen (epäluulo > 0
## ja first:paivi_jalki), eikä sama hyvitys toimi kahtena päivänä peräkkäin (eikä kahdesti samana päivänä).
## Käyttäjän rajaus (00-ohjeet.md): seuraintalon tanssit ("tanssit") ja Kymppiuutiset ("uutiset") EIVÄT ole hyvityksiä,
## vaikka main.gd lähettää niistäkin tapahtuman; ne ohitetaan, koska ne puuttuvat HYVITYS-taulusta.

## why -> epäluulon lasku. Arvioita: isot eleet (kukat, ovikuva, taimet) 10, kotihommat 5.
const HYVITYS := {
	"kukat": 10.0,  # _flowers_morning (_paivi_credit_add)
	"ovikuva": 10.0,  # _give_ovikuva (Wanhan Raahen ovikuva)
	"taimet": 10.0,  # Sinikan tomaatintaimet
	"kauppalista": 5.0,
	"nurmikko": 5.0,
	"pensasaita": 5.0,
}

var viimeksi := {}  # why -> päivä, jolloin hyvitys viimeksi laski epäluuloa


func on_event(ev: String, data: Dictionary) -> void:
	if ev == "paivi_hyvitys":
		hyvita(String(data.get("why", "")))


## Palauttaa epäluulon muutoksen (0 = ei vaikutusta).
func hyvita(why: String) -> float:
	var p: Object = game.rikos_osa("paivi")
	if p == null or not HYVITYS.has(why):
		return 0.0
	if p.epaluulo <= 0.0 or not "paivi_jalki" in game.tilat.firsts:
		return 0.0
	var v := int(viimeksi.get(why, -99))
	if v == game.day or v == game.day - 1:
		return 0.0
	var e0: float = p.epaluulo
	p.lisaa(-HYVITYS[why], "hyvitys:" + why)
	viimeksi[why] = game.day
	game.tilat.first("paivi_hyvitys", 0.0)
	return p.epaluulo - e0


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("rikos_paivi_hyvitys", "viimeksi", viimeksi)


func load_from(cfg: ConfigFile) -> void:
	viimeksi = _ints(cfg.get_value("rikos_paivi_hyvitys", "viimeksi", {}))


# --- Testi: aja.sh scene riskit --riski=paivi_hyvitys -------------------------------------------------------------

var _vikoja := 0


func _vika(t: String) -> void:
	_vikoja += 1
	print("TESTI VIKA paivi_hyvitys: " + t)


## Tapahtuma kuten pelissä (main.gd _rikos_event); palauttaa epäluulon muutoksen.
func _koe(p: Object, why: String) -> float:
	var e0: float = p.epaluulo
	game._rikos_event("paivi_hyvitys", {"why": why})
	return p.epaluulo - e0


func testi(_arg: String) -> void:
	_vikoja = 0
	var p: Object = game.rikos_osa("paivi")
	if p == null:
		_vika("osa paivi puuttuu")
		return
	var d0: int = game.day
	var e_alku: float = p.epaluulo
	var oli_jalki: bool = "paivi_jalki" in game.tilat.firsts
	var oli_hyv: bool = "paivi_hyvitys" in game.tilat.firsts
	viimeksi = {}
	# Ilman jälkeä: ei vaikutusta.
	game.tilat.firsts.erase("paivi_jalki")
	game.tilat.firsts.erase("paivi_hyvitys")
	p.epaluulo = 0.0
	var d := _koe(p, "kukat")
	print("PAIVI_HYVITYS ilman jälkeä: kukat %+.0f" % d)
	if absf(d) > 0.01 or "paivi_hyvitys" in game.tilat.firsts:
		_vika("hyvitys toimi ilman jälkeä (%+.1f)" % d)
	# Jälki syntynyt (epäluulo 80): jokainen hyväksytty hyvitys laskee kerran.
	game.tilat.firsts.append("paivi_jalki")
	p.epaluulo = 80.0
	var rivit: Array = []
	for why in HYVITYS:
		d = _koe(p, why)
		rivit.append("%s %+.0f" % [why, d])
		if absf(d + HYVITYS[why]) > 0.01:
			_vika("%s laski %.1f, piti %.1f" % [why, d, -HYVITYS[why]])
	print("PAIVI_HYVITYS päivä %d: %s, epäluulo %.0f" % [game.day, rivit, p.epaluulo])
	if not "paivi_hyvitys" in game.tilat.firsts:
		_vika("first:paivi_hyvitys ei kirjautunut")
	# Tanssit ja Kymppiuutiset eivät ole hyvityksiä (käyttäjän ohje).
	for why in ["tanssit", "uutiset", "tuntematon"]:
		d = _koe(p, why)
		print("PAIVI_HYVITYS ei hyvitys %s %+.0f" % [why, d])
		if absf(d) > 0.01:
			_vika("%s laski epäluuloa (%+.1f)" % [why, d])
	# Sama päivä uudelleen ja seuraava päivä: 0; kahden päivän päästä taas toimii.
	var d_sama := _koe(p, "kukat")
	game.day += 1
	var d_huomenna := _koe(p, "kukat")
	var d_nurmi := _koe(p, "nurmikko")
	game.day += 1
	var d_ylihuomenna := _koe(p, "kukat")
	print("PAIVI_HYVITYS kukat sama päivä %+.0f, seuraava päivä %+.0f (nurmikko %+.0f), kahden päivän päästä %+.0f, epäluulo %.0f" % [
		d_sama, d_huomenna, d_nurmi, d_ylihuomenna, p.epaluulo])
	if absf(d_sama) > 0.01 or absf(d_huomenna) > 0.01 or absf(d_nurmi) > 0.01:
		_vika("sama hyvitys toimi samana tai seuraavana päivänä")
	if absf(d_ylihuomenna + HYVITYS.kukat) > 0.01:
		_vika("kukat ei toiminut kahden päivän päästä (%+.1f)" % d_ylihuomenna)
	# Epäluulo ei mene alle nollan.
	p.epaluulo = 3.0
	game.day += 2
	d = _koe(p, "kukat")
	print("PAIVI_HYVITYS epäluulo 3 - kukat -> %.0f" % p.epaluulo)
	if p.epaluulo < 0.0 or absf(d + 3.0) > 0.01:
		_vika("epäluulo alle nollan tai väärä lasku (%.1f)" % p.epaluulo)
	# Tallennus: viimeksi säilyy (kukat eilen -> ei toimi tänään ladatun jälkeen).
	p.epaluulo = 50.0
	game._save_game()
	viimeksi = {}
	game._load_game()
	var h: Object = game.rikos_osa("paivi_hyvitys")
	print("PAIVI_HYVITYS tallennus viimeksi %s" % [h.viimeksi])
	if int(h.viimeksi.get("kukat", -1)) != game.day:
		_vika("tallennus ei palauttanut viimeksi-päiviä")
	var cfg := ConfigFile.new()
	h.load_from(cfg)
	if not h.viimeksi.is_empty():
		_vika("vanha tallennus ei antanut oletusarvoja")
	# Palautus.
	game.day = d0
	p.epaluulo = e_alku
	viimeksi = {}
	if not oli_jalki:
		game.tilat.firsts.erase("paivi_jalki")
	if not oli_hyv:
		game.tilat.firsts.erase("paivi_hyvitys")
	print("PAIVI_HYVITYS testi valmis, %d vikaa" % _vikoja)
