extends "res://scripts/rikos/osa.gd"
## Luku 6 "Päivi epäilee" (#326): Päivin epäluulo 0–100 ja jäljet. Erillinen Irman mittarista (rikos/epaluulo.gd).
## Jälki syntyy, kun pelaaja tekee jotain epäilyttävää ensimmäistä kertaa (tilat.first -> main.gd "first"-tapahtuma),
## huumekaupan ensimmäisestä myynnistä ("myynti") ja joka Irman hälytyksestä ("irma_halytys"). Jälki nostaa epäluuloa
## heti ja jää jonoon odottamaan aamua; paivi_puhe.gd ottaa sen puheeksi (seuraava_jalki, kasittele). Muut osat
## (paivi_puhe, paivi_hyvitys, paivi_tutkii, main.gd kesäheila) muuttavat lukua vain lisaa()- ja nollaa()-funktioilla.
## K-18 pois (Settings k18_pois): vain korkkikansion ja Drakkarin jäljet syntyvät, Päivi ei tutki eikä huipennusta tule.

const MAX := 100.0
const TUTKII := 60.0  # tästä yli Päivi tutkii (paivi_tutkii.gd), ja huipennus aukeaa (yli60)
## Jälki: id -> ensikerrat, joista se syntyy, nousu, K-18-sisältö, viive (päiviä ennen puheeksiottoa) ja Päivin aamurepliikki.
## toistuu: jälki syntyy joka kerta (Irman hälytys), muut kerran. Nousut ovat arvioita (02-arkkitehtuuri.md).
const JALJET := {
	"kolmio": {"first": ["kolmio_saloinen", "kolmio_vaala"], "nousu": 20.0, "k18": true, "viive": 1,
		"aamu": "Sytkäri? Mikä ihmeen Sytkäri? Sun puhelimessa oli kartta ja kolme ympyrää. Kenen ovelle ne osoitti?"},
	"rasvanappi": {"first": ["rasvanappi"], "nousu": 15.0, "k18": true, "viive": 1,
		"aamu": "Sun paidassa oli jotain liukasta, ja makasiinilta kuulu eilen huutoa. Missä sää oikein olit?"},
	"bangbus": {"first": ["pentti_kyyti"], "nousu": 15.0, "k18": true, "viive": 2,  # Pentin oma aamulappu ensin
		"aamu": "Pentin BangBus. Koko kylä puhuu siitä vieläki. Ja sää istuit siinä. Selitäpä."},
	"korkki": {"first": ["korkki"], "nousu": 10.0, "k18": false, "viive": 1,
		"aamu": "Mikä tää korkkikansio on? Sää keräät korkkeja ku joku teini. Mistä ne korkit on peräisin?"},
	"rakaleima": {"first": ["rakaleima_kopio"], "nousu": 10.0, "k18": true, "viive": 1,
		"aamu": "Pöydällä oli perunanpuolikas ja leimasinmustetta. Mitä sää oikein leimailet?"},
	"drakkar": {"first": ["drakkar"], "nousu": 10.0, "k18": false, "viive": 1,
		"aamu": "Sää haiset Drakkar Noirilta. Kenelle sää sitä laitoit? Mulle et oo laittanu sitä sitten -96."},
	"huume": {"first": [], "nousu": 15.0, "k18": true, "viive": 1,
		"aamu": "Sun puhelin soi yöllä kolme kertaa samasta numerosta, ja takin taskussa oli rulla seteleitä. Mitä tää on?"},
	"irma": {"first": [], "nousu": 10.0, "k18": true, "viive": 1, "toistuu": true,
		"aamu": "Irma Kinnapotista soitti. Kylällä kävi poliisi, ja sun nimi mainittiin. Ootko sää sotkeutunu johonki?"},
}

var epaluulo := 0.0
var odottaa: Array = []  # [{"id", "day"}]: jäljet, joita Päivi ei ole vielä ottanut puheeksi (vanhin ensin)
var kasitelty := {}  # id -> tapa ("selitys", "tunnustus", "vastahyokkays" ...): kerran syntyvä jälki ei synny uudelleen
var tunnustetut: Array = []  # tunnustetut jäljet (paivi_puhe.gd): Päivi muistaa
var yli60 := false  # epäluulo on joskus ollut yli TUTKII (huipennus aukeaa)
var vastahyokkays := false
var poissa_asti := -1  # "Suuttua": Päivi äidillä tähän päivään asti (main.gd kesäheila)
var liput := {}  # osien omat liput, quest_flag("paivi_...") (esim. paivi_pentti_vihje)
var viime_syy := ""


## K-18-sisältö pois (asetus): vain korkki ja drakkar.
func k18_pois() -> bool:
	return Settings.get_v("k18_pois")


## Ainoa tapa muuttaa epäluuloa (muut osat kutsuvat game.rikos_osa("paivi").lisaa(n, syy)).
func lisaa(n: float, syy := "") -> void:
	epaluulo = clampf(epaluulo + n, 0.0, MAX)
	viime_syy = syy
	if epaluulo > TUTKII:
		yli60 = true


func nollaa() -> void:
	epaluulo = 0.0


func on_event(ev: String, data: Dictionary) -> void:
	match ev:
		"first":
			var key := String(data.get("key", ""))
			for id in JALJET:
				if key in JALJET[id].first:
					_jalki(id)
		"myynti":
			_jalki("huume")
		"irma_halytys":
			_jalki("irma")


## Uusi jälki: kerran (paitsi toistuva), nostaa epäluuloa heti ja jää odottamaan aamua.
func _jalki(id: String) -> void:
	var j: Dictionary = JALJET[id]
	if k18_pois() and j.k18:
		return
	if not j.get("toistuu", false) and (kasitelty.has(id) or odottaa.any(func(o: Dictionary) -> bool: return o.id == id)):
		return
	odottaa.append({"id": id, "day": game.day})
	lisaa(j.nousu, "jalki:" + id)
	game.tilat.first("paivi_jalki", 0.0)


## Seuraava jälki, jonka Päivi voi ottaa puheeksi tänä aamuna: {"id", "day", "aamu", "nousu", "k18"} tai {}.
## K-18-jäljet ohitetaan hiljaa, kun asetus on pois päältä (jäävät jonoon).
func seuraava_jalki() -> Dictionary:
	if poissa():
		return {}
	for o: Dictionary in odottaa:
		var j: Dictionary = JALJET[o.id]
		if k18_pois() and j.k18:
			continue
		if game.day >= int(o.day) + int(j.viive):
			return {"id": o.id, "day": int(o.day), "aamu": j.aamu, "nousu": j.nousu, "k18": j.k18}
	return {}


## Jälki puheeksi otettu: pois jonosta (ensimmäinen samalla id:llä), tapa muistiin.
func kasittele(id: String, tapa: String) -> void:
	for i in odottaa.size():
		if odottaa[i].id == id:
			odottaa.remove_at(i)
			break
	kasitelty[id] = tapa


## Päivi tutkii (paivi_tutkii.gd): epäluulo yli 60, K-18 sallittu, Päivi kotona.
func tutkii() -> bool:
	return epaluulo > TUTKII and not k18_pois() and not poissa()


## Kesäheila -96 -huipennus auki (Sytkärin mätsi): epäluulo on ollut yli 60 tai vastahyökkäystä on käytetty.
func huipennus_auki() -> bool:
	return (yli60 or vastahyokkays) and not k18_pois()


## Päiväkirjan Päivi-piirros: 0 rauhallinen, 1 kulmat koholla, 2 kädet puuskassa, 3 laukku pakattu.
func ilme() -> int:
	if epaluulo < 25.0:
		return 0
	if epaluulo < 50.0:
		return 1
	if epaluulo < 75.0:
		return 2
	return 3


func poissa() -> bool:
	return game.day < poissa_asti


## main.gd quest_flag("paivi_..."): luvun 6 ehdot (quests.gd "flag:paivi_...").
func flag(n: String) -> bool:
	match n:
		"paivi_k18_pois":
			return k18_pois()
		"paivi_huipennus":
			return huipennus_auki()
		"paivi_tutkii":
			return tutkii()
		"paivi_yli60":
			return yli60
		"paivi_vastahyokkays":
			return vastahyokkays
		"paivi_poissa":
			return poissa()
	return bool(liput.get(n, false))


## main.gd quest_progress("paivi_..."): "paivi_ilme" -> "0".."3", "paivi_epaluulo" -> "epäluulo 37 / 100".
func progress(n: String) -> String:
	match n:
		"paivi_ilme":
			return str(ilme())
		"paivi_epaluulo":
			return "epäluulo %d / %d" % [roundi(epaluulo), roundi(MAX)]
	return ""


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("rikos_paivi", "epaluulo", epaluulo)
	cfg.set_value("rikos_paivi", "odottaa", odottaa)
	cfg.set_value("rikos_paivi", "kasitelty", kasitelty)
	cfg.set_value("rikos_paivi", "tunnustetut", tunnustetut)
	cfg.set_value("rikos_paivi", "yli60", yli60)
	cfg.set_value("rikos_paivi", "vastahyokkays", vastahyokkays)
	cfg.set_value("rikos_paivi", "poissa_asti", poissa_asti)
	cfg.set_value("rikos_paivi", "liput", liput)


## Vanha tallennus: oletusarvot (jälkiä ei lasketa takautuvasti).
func load_from(cfg: ConfigFile) -> void:
	epaluulo = float(cfg.get_value("rikos_paivi", "epaluulo", 0.0))
	odottaa = cfg.get_value("rikos_paivi", "odottaa", [])
	kasitelty = cfg.get_value("rikos_paivi", "kasitelty", {})
	tunnustetut = cfg.get_value("rikos_paivi", "tunnustetut", [])
	yli60 = cfg.get_value("rikos_paivi", "yli60", false)
	vastahyokkays = cfg.get_value("rikos_paivi", "vastahyokkays", false)
	poissa_asti = int(cfg.get_value("rikos_paivi", "poissa_asti", -1))
	liput = cfg.get_value("rikos_paivi", "liput", {})


# --- Testi: aja.sh scene riskit --riski=paivi [--arg=jalki|irma|k18|tutkii|tallennus] (tyhjä = kaikki) ---------------

var _vikoja := 0


func _vika(t: String) -> void:
	_vikoja += 1
	print("TESTI VIKA paivi: " + t)


func _tyhjaksi() -> void:
	epaluulo = 0.0
	odottaa = []
	kasitelty = {}
	tunnustetut = []
	yli60 = false
	vastahyokkays = false
	poissa_asti = -1
	liput = {}


## Ensikerta uudestaan (testi): avain pois tilat.firstsistä ja tilat.first kuten pelissä. Palauttaa epäluulon muutoksen.
func _koe_first(key: String, poista := true) -> float:
	if poista:
		game.tilat.firsts.erase(key)
	var e0 := epaluulo
	game.tilat.first(key, 0.0)
	return epaluulo - e0


func testi(arg: String) -> void:
	_vikoja = 0
	var vanha_k18: bool = Settings.values.get("k18_pois", false)
	Settings.values["k18_pois"] = false
	if arg in ["", "jalki"]:
		_testi_jalki()
	if arg in ["", "irma"]:
		_testi_irma()
	if arg in ["", "k18"]:
		_testi_k18()
	Settings.values["k18_pois"] = false
	if arg in ["", "tutkii"]:
		_testi_tutkii()
	if arg in ["", "tallennus"]:
		_testi_tallennus()
	Settings.values["k18_pois"] = vanha_k18
	print("PAIVI testi valmis, %d vikaa" % _vikoja)


func _testi_jalki() -> void:
	_tyhjaksi()
	game.tilat.firsts.erase("paivi_jalki")
	for id in JALJET:
		var j: Dictionary = JALJET[id]
		if j.first.is_empty():
			continue
		var d := _koe_first(j.first[0])
		var d2 := _koe_first(j.first[0], false)  # sama ensikerta toiseen kertaan: tilat.first ei kirjaa uutta
		var d3 := _koe_first(j.first[0])  # vaikka ensikerta tulisi uudestaan, jälki jo jonossa
		print("PAIVI jälki %s (%s): %+.0f, toinen kerta %+.0f, uudelleen %+.0f, epäluulo %.0f" % [id, j.first[0], d, d2, d3, epaluulo])
		if absf(d - j.nousu) > 0.01:
			_vika("jälki %s nosti %.1f, piti %.1f" % [id, d, j.nousu])
		if absf(d2) > 0.01 or absf(d3) > 0.01:
			_vika("jälki %s laskettiin kahdesti (%+.1f, %+.1f)" % [id, d2, d3])
	var dv := _koe_first("kolmio_vaala")
	print("PAIVI kolmio_vaala Saloisten jälkeen %+.0f" % dv)
	if absf(dv) > 0.01:
		_vika("kolmio_vaala nosti uudelleen (sama jälki kolmio)")
	if not "paivi_jalki" in game.tilat.firsts:
		_vika("first:paivi_jalki ei kirjautunut")
	var e0 := epaluulo
	game._rikos_event("myynti", {"key": "opiaatti", "paikka": "saloinen"})
	var dm := epaluulo - e0
	game._rikos_event("myynti", {"key": "opiaatti", "paikka": "vaala"})
	print("PAIVI myynti %+.0f, toinen myynti %+.0f" % [dm, epaluulo - e0 - dm])
	if absf(dm - JALJET.huume.nousu) > 0.01 or absf(epaluulo - e0 - dm) > 0.01:
		_vika("huumejälki ei noussut kerran")
	# Aamua odotetaan: samana päivänä ei puheeksi, seuraavana vanhin; BangBus vasta toisena aamuna.
	var ids: Array = odottaa.map(func(o: Dictionary) -> String: return o.id)
	print("PAIVI jonossa %s, epäluulo %.0f" % [ids, epaluulo])
	if ids.size() != JALJET.size() - 1:
		_vika("jonossa %d jälkeä, piti %d" % [ids.size(), JALJET.size() - 1])
	if not seuraava_jalki().is_empty():
		_vika("jälki puheeksi samana päivänä: %s" % seuraava_jalki())
	game.day += 1
	var s := seuraava_jalki()
	print("PAIVI seuraava aamu: %s" % s.get("id", "-"))
	if s.get("id", "") != "kolmio":
		_vika("seuraavana aamuna ei vanhinta jälkeä: %s" % s)
	kasittele("kolmio", "selitys")
	var muut: Array = []
	while not seuraava_jalki().is_empty():
		var o := seuraava_jalki()
		muut.append(o.id)
		kasittele(o.id, "selitys")
	print("PAIVI samana aamuna käsiteltävissä %s, odottaa %s" % [muut, odottaa.map(func(o: Dictionary) -> String: return o.id)])
	if "bangbus" in muut:
		_vika("BangBus-jälki samana aamuna kuin Pentin lappu")
	game.day += 1
	if seuraava_jalki().get("id", "") != "bangbus":
		_vika("BangBus-jälki ei tullut toisena aamuna")
	kasittele("bangbus", "tunnustus")
	var dk := _koe_first("korkki")
	if absf(dk) > 0.01:
		_vika("käsitelty jälki korkki syntyi uudelleen (%+.1f)" % dk)
	game.day -= 2


func _testi_irma() -> void:
	_tyhjaksi()
	var irma: Object = game.rikos_osa("epaluulo")
	if irma == null:
		_vika("Irman osa (epaluulo) puuttuu")
		return
	var i0: float = irma.epaluulo
	irma.halyta()
	var e1 := epaluulo
	game._rikos_event("irma_halytys", {})
	print("PAIVI Irman hälytys: Irma %.0f -> %.0f, Päivi 0 -> %.0f -> %.0f, jonossa %d" % [i0, irma.epaluulo, e1, epaluulo, odottaa.size()])
	if absf(e1 - JALJET.irma.nousu) > 0.01:
		_vika("Irman hälytys ei nostanut Päivin mittaria (%.1f)" % e1)
	if absf(epaluulo - 2.0 * JALJET.irma.nousu) > 0.01 or odottaa.size() != 2:
		_vika("toinen hälytys ei nostanut uudelleen")
	if absf(irma.epaluulo - irma.MAX) > 0.01:
		_vika("Irman oma mittari ei täynnä hälytyksen jälkeen (%.1f)" % irma.epaluulo)
	irma.halytys = false
	irma.epaluulo = i0


func _testi_k18() -> void:
	_tyhjaksi()
	Settings.values["k18_pois"] = true
	for id in JALJET:
		for k in JALJET[id].first:
			_koe_first(k)
	game._rikos_event("myynti", {"key": "opiaatti", "paikka": "saloinen"})
	game._rikos_event("irma_halytys", {})
	var ids: Array = odottaa.map(func(o: Dictionary) -> String: return o.id)
	print("PAIVI K-18 pois: jonossa %s, epäluulo %.0f" % [ids, epaluulo])
	if ids != ["korkki", "drakkar"]:
		_vika("K-18 pois: jonossa %s, piti [korkki, drakkar]" % [ids])
	if absf(epaluulo - JALJET.korkki.nousu - JALJET.drakkar.nousu) > 0.01:
		_vika("K-18 pois: epäluulo %.1f" % epaluulo)
	# Päälle jäänyt K-18-jälki (asetus vaihdettu kesken) ohitetaan, mittari säilyy, ei tutkintaa eikä huipennusta.
	odottaa.push_front({"id": "rasvanappi", "day": game.day - 3})
	epaluulo = 80.0
	yli60 = true
	game.day += 1
	var s := seuraava_jalki()
	print("PAIVI K-18 pois, seuraava %s, tutkii %s, huipennus %s, flag %s" % [s.get("id", "-"), tutkii(), huipennus_auki(),
		game.quest_flag("paivi_k18_pois")])
	if s.get("id", "") != "korkki":
		_vika("K-18 pois: seuraava jälki %s, piti korkki" % s)
	if tutkii() or huipennus_auki():
		_vika("K-18 pois: Päivi tutkii tai huipennus auki")
	if not game.quest_flag("paivi_k18_pois"):
		_vika("quest_flag(paivi_k18_pois) ei välity")
	game.day -= 1
	Settings.values["k18_pois"] = false


func _testi_tutkii() -> void:
	_tyhjaksi()
	var rivit: Array = []
	for n in [0.0, 30.0, 25.0, 6.0, 1.0, 40.0]:
		lisaa(n, "testi")
		rivit.append("%.0f:%s/%d/%s" % [epaluulo, tutkii(), ilme(), game.quest_progress("paivi_ilme")])
	print("PAIVI epäluulo:tutkii/ilme/progress %s" % [rivit])
	if rivit != ["0:false/0/0", "30:false/1/1", "55:false/2/2", "61:true/2/2", "62:true/2/2", "100:true/3/3"]:
		_vika("tutkii/ilme rajat: %s" % [rivit])
	if not huipennus_auki() or not game.quest_flag("paivi_huipennus"):
		_vika("huipennus ei auki yli 60:n jälkeen")
	lisaa(-80.0)
	if tutkii() or not huipennus_auki():
		_vika("alle 60: tutkii %s, huipennus %s (yli60 pysyy)" % [tutkii(), huipennus_auki()])
	poissa_asti = game.day + 7
	lisaa(60.0)
	if tutkii() or not seuraava_jalki().is_empty():
		_vika("poissa: Päivi tutkii tai ottaa puheeksi")
	poissa_asti = -1


func _testi_tallennus() -> void:
	_tyhjaksi()
	epaluulo = 37.0
	odottaa = [{"id": "korkki", "day": game.day}]
	kasitelty = {"drakkar": "tunnustus"}
	tunnustetut = ["drakkar"]
	vastahyokkays = true
	liput = {"paivi_pentti_vihje": true}
	game._save_game()
	_tyhjaksi()
	game._load_game()
	var p: Object = game.rikos_osa("paivi")
	print("PAIVI tallennus 37 -> %.0f, jonossa %s, käsitelty %s, tunnustetut %s, vastahyökkäys %s, lippu %s" % [
		p.epaluulo, p.odottaa, p.kasitelty, p.tunnustetut, p.vastahyokkays, game.quest_flag("paivi_pentti_vihje")])
	if absf(p.epaluulo - 37.0) > 0.01:
		_vika("tallennus: epäluulo %.1f, piti 37" % p.epaluulo)
	if p.odottaa.size() != 1 or p.kasitelty.get("drakkar", "") != "tunnustus" or not "drakkar" in p.tunnustetut \
			or not p.vastahyokkays or not game.quest_flag("paivi_pentti_vihje"):
		_vika("tallennus ei palauttanut jäljet/liput")
	# Vanha tallennus ilman osiota: oletusarvot.
	var cfg := ConfigFile.new()
	load_from(cfg)
	if epaluulo != 0.0 or not odottaa.is_empty() or poissa_asti != -1:
		_vika("vanha tallennus ei antanut oletusarvoja")
