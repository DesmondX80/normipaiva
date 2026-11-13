extends "res://scripts/rikos/osa.gd"
## Luku 6 "Päivi epäilee" (#326), aamun puheeksiotto: kun paivi.gd:n jonossa on jälki, Päivi ottaa sen puheeksi aamulla
## kotipihalla (ennen klo 11, alle 50 m kodista, aamulappu luettu) pelin keskusteluikkunalla ilman hahmoa (kuten Veksi).
## Valinnat: kolme selitystä, tunnustus ja vastahyökkäys. Selitys menee läpi vain, jos pelaaja on oikeasti tehnyt sen,
## mihin selitys vetoaa (ehto "nahty:<puhuja>" = jutellut hahmon kanssa jäljen päivänä, "first:<avain>" = ensikerta tehty).
## Väärä Pekka-selitys ei paljastu heti: Päivi kysyy Pekalta, ja Pekan seuraava tervehdys möläyttää (+10).
## Epäluuloa muutetaan vain paivi.lisaa()-kautta. Suljettu ikkuna ilman valintaa: jälki jää jonoon, kysytään huomenna.

const AAMU_ASTI := 11.0 * 60.0  # puheeksiotto vain aamulla
const KOTI_R := 50.0  # m kodista (home_zone)
const USKOO := -5.0  # selitys menee läpi
const EI_USKO := 10.0  # selitys ei pidä (myös Pekan möläytys)
const TUNNUSTUS := -15.0
const TUNNUSTUS_MORAALI := -0.05  # käyttäjän "moraali -5" asteikolla -1..1 (02-arkkitehtuuri.md, arvio)
const VASTAHYOKKAYS := 5.0
const NAHTY_PAIVAT := 14  # montako päivää taaksepäin nähdyt muistetaan

## Jälki -> lyhyt nimi (Päivi muistaa tunnustuksen) ja kolme selitystä [ehto, teksti]. Pekka on jokaisessa (möläytys).
const SELITYKSET := {
	"kolmio": {"nimi": "sen Sytkärin", "sel": [
		["nahty:pekka", "Pekka asenti sen mulle. Se ettii sillä kalapaikkoja ympyröillä."],
		["first:kirppis", "Se on kirppikseltä ostettu käytetty puhelin. Kartat on edellisen omistajan."],
		["nahty:arto", "Arto neuvo marjapaikkoja. Ympyrät on mustikkamättäitä."]]},
	"rasvanappi": {"nimi": "sen liukkaan paidan", "sel": [
		["nahty:pekka", "Mää autoin Pekkaa Volvon kanssa. Siitä tuli rasvaa."],
		["first:makkaranpaisto", "Makkaranpaistossa roiskahti. Huuto oli nuorison."],
		["first:karburaattori", "Mää säädin mopon kaasaria. Kaikki on ihan öljyssä."]]},
	"bangbus": {"nimi": "sen BangBusin", "sel": [
		["nahty:pekka", "Pekka oli kans kyydissä. Me käytiin vaan kattomassa sitä autoa."],
		["first:pullonkeraus", "Mää keräsin pulloja, ja Pentti tarjos kyydin palautukseen."],
		["first:keikkatyo", "Mää olin keikkahommissa, Pentti vaan heitti mut sinne."]]},
	"korkki": {"nimi": "sen korkkikansion", "sel": [
		["nahty:pekka", "Pekka anto ne. Se tyhjens vintiltään."],
		["first:kirppis", "Mää ostin kansion kirppikseltä. Korkit tuli kaupan päälle."],
		["first:pullonkeraus", "Mää keräsin pulloja, ja korkit jäi talteen."]]},
	"rakaleima": {"nimi": "sen perunaleimasimen", "sel": [
		["nahty:pekka", "Pekka opetti. Se merkkaa niillä sieniämpärit."],
		["first:kirppis", "Hilkka pyys tekemään hintaleimat kirppikselle."],
		["first:pojat", "Mää tein leikkipuiston pojille leimasimia."]]},
	"drakkar": {"nimi": "sen Drakkarin", "sel": [
		["nahty:pekka", "Pekka testas sitä mulle. Se on Pekan pullo."],
		["first:kirppis", "Mää löysin pullon kirppikseltä. Piti kokeilla, onko se aitoa."],
		["first:lava", "Mää laitoin sitä lavalle. Siellä haisee muuten hiki."]]},
	"huume": {"nimi": "ne setelit", "sel": [
		["nahty:pekka", "Pekka maksoi sienistä käteisellä."],
		["first:oma_kirppispoyta", "Mää myin kirppispöydässä vanhoja tavaroita."],
		["first:keikkatyo", "Keikkahommista. Ne maksaa pimeenä."]]},
	"irma": {"nimi": "sen poliisijutun", "sel": [
		["nahty:pekka", "Pekka oli siellä, kysy siltä. Poliisi kysy vaan Volvosta."],
		["first:ratsia", "Roivainen pysäytti mut puhallukseen. Ei mitään sen kummempaa."],
		["first:soitti_112", "Mää soitin itte hätänumeroon, ku joku oli loukkaantunu."]]},
}

const USKOO_REPLIIKIT := ["No... jos sää noin sanot. Mutta mää pidän sua silmällä.",
	"Hm. Kuulostaa siltä, että se vois olla totta. Tällä kertaa.",
	"Okei. Ei siitä sitten enempää. Mutta muista, mää huomaan kaiken."]
const EI_USKO_REPLIIKIT := ["En usko sanaakaan. Sää et oo koko päivänä tehny mitään sellasta.",
	"Älä valehtele mulle. Mää tiedän, missä sää olit, ja siellä sää et ollu.",
	"Ihan kuin mää en tuntis sua. Toi on tekosyy, ja huono sellainen."]
const PEKKA_KYSYY := "Vai Pekka. No, mää kysyn Pekalta, ku nään sen."
const PEKKA_MOLAYS := "Hei! Päivi kysyi, oltiinko me yhessä. Mää sanoin, etten oo nähny sua koko päivänä. Ei kai se ollu väärin?"
const TUNNUSTUS_VASTAUS := "...Kiitos, että sanoit suoraan. Ei se kivaa ollu kuulla, mutta parempi näin. Mää muistan tän."
const VASTAHYOKKAYS_VASTAUS := "Zabukin tanssit -94?! Se oli ihan eri asia! ...Ja kuka sulle siitä kerto? Sinikka? Tää ei jää tähän."
const VASTAHYOKKAYS_TEKSTI := "Entäs sää ja Zabukin tanssit -94? Sinikka kerto."

var nahty := {}  # puhuja -> [päivät], jolloin pelaaja jutteli hahmon kanssa (tai kävi puhevihjeen päässä)
var molays := false  # väärä Pekka-selitys: Pekan seuraava tervehdys möläyttää
var kysytty_day := -1  # tänään jo puheeksi otettu (yksi jälki aamussa)
var _auki := {}  # puheeksi otettu jälki (paivi.seuraava_jalki), kunnes valittu tai ikkuna suljettu


func _init() -> void:
	talkers = ["paivi"]


func _paivi() -> Object:
	return game.rikos_osa("paivi")


func tick(_e: bool) -> void:
	var p: Object = _paivi()
	if p == null or p.odottaa.is_empty():  # halpa ehto ensin (K21)
		_auki = {}
		return
	if not _auki.is_empty():
		if not game._talk_box.is_open():
			_auki = {}  # suljettu ilman valintaa: jälki jää jonoon
		return
	if kysytty_day == game.day or game.clock_min >= AAMU_ASTI or game._in_vaala or game.state != "ulkona":
		return
	if game._talk_box.is_open() or game._note.visible or game.cutscene.busy:
		return
	if game._active_walker().global_position.distance_to(game.home_zone) > KOTI_R:
		return
	var j: Dictionary = p.seuraava_jalki()
	if j.is_empty():
		return
	avaa(j)


## Puheeksiotto: Päivin repliikki (jos jotain on tunnustettu aiemmin, Päivi muistuttaa siitä ensin).
func avaa(j: Dictionary) -> void:
	kysytty_day = game.day
	_auki = j
	game._talk_open("paivi", null, repliikki(j))


func repliikki(j: Dictionary) -> String:
	var t := String(j.aamu)
	var p: Object = _paivi()
	if not p.tunnustetut.is_empty():
		var vanha: String = p.tunnustetut[-1]
		t = "Sää tunnustit jo %s. Luulin, että se jäi siihen. %s" % [SELITYKSET[vanha].nimi, t]
	return t


func hello(who: String) -> String:
	if who == "pekka" and molays:
		molays = false
		_paivi().lisaa(EI_USKO, "molays")
		return PEKKA_MOLAYS
	return ""


func options(who: String, o: Array) -> void:
	_nahty(who)
	if who != "paivi" or _auki.is_empty() or int(_auki.get("day", -1)) < 0:
		return
	var sel: Array = SELITYKSET[_auki.id].sel
	for i in sel.size():
		o.append(game._opt("paivi_puhe_sel%d" % i, "\"%s\" (selitä)" % sel[i][1]))
	o.append(game._opt("paivi_puhe_tunnusta", "\"Okei. Se olin minä.\" (tunnusta, moraali laskee)"))
	o.append(game._opt("paivi_puhe_vasta", "\"%s\" (vastahyökkäys)" % VASTAHYOKKAYS_TEKSTI))


## Lähellä käynti lasketaan näkemiseksi (_talk_hint kutsuu _talk_options -> options).
func _nahty(who: String) -> void:
	var d: Array = nahty.get(who, [])
	if not d.is_empty() and int(d[-1]) == game.day:
		return
	d.append(game.day)
	while d.size() > NAHTY_PAIVAT:
		d.pop_front()
	nahty[who] = d


## Selityksen ehto pelaajan oikeasta teosta: "nahty:<puhuja>" jäljen päivänä tai "first:<avain>" koska tahansa ennen.
func ehto(e: String, jalki_day: int) -> bool:
	var osat := e.split(":")
	match osat[0]:
		"nahty":
			return jalki_day in nahty.get(osat[1], []).map(func(x: Variant) -> int: return int(x))
		"first":
			return osat[1] in game.tilat.firsts
	return false


func choose(id: String) -> bool:
	if not id.begins_with("paivi_puhe_") or _auki.is_empty():
		return false
	var p: Object = _paivi()
	var j := _auki
	var e0: float = p.epaluulo
	var vastaus := ""
	var tapa := ""
	if id.begins_with("paivi_puhe_sel"):
		tapa = "selitys"
		var s: Array = SELITYKSET[j.id].sel[int(id.substr(14))]
		if ehto(s[0], int(j.day)):
			p.lisaa(USKOO, "selitys:" + j.id)
			vastaus = USKOO_REPLIIKIT.pick_random()
		elif String(s[0]) == "nahty:pekka":
			molays = true  # paljastuu, kun Pekka tervehtii seuraavan kerran
			vastaus = PEKKA_KYSYY
		else:
			p.lisaa(EI_USKO, "selitys:" + j.id)
			vastaus = EI_USKO_REPLIIKIT.pick_random()
	elif id == "paivi_puhe_tunnusta":
		tapa = "tunnustus"
		p.lisaa(TUNNUSTUS, "tunnustus:" + j.id)
		game.tilat.add("moraali", TUNNUSTUS_MORAALI)
		if not j.id in p.tunnustetut:
			p.tunnustetut.append(j.id)
		vastaus = TUNNUSTUS_VASTAUS
	else:
		tapa = "vastahyokkays"
		p.lisaa(VASTAHYOKKAYS, "vastahyokkays:" + j.id)
		p.vastahyokkays = true
		vastaus = VASTAHYOKKAYS_VASTAUS
	p.kasittele(j.id, tapa)
	game.tilat.first("paivi_selitys", 0.0)  # luvun 6 vaihe "selitys" (quests.gd)
	_auki = {}
	var d: float = p.epaluulo - e0
	game._talk_box.reply(vastaus, [game._opt("lopeta", "Lopeta")],
		"Päivi aikoo kysyä Pekalta." if vastaus == PEKKA_KYSYY else "Päivin epäluulo %+d" % roundi(d))
	return true


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("rikos_paivi_puhe", "nahty", nahty)
	cfg.set_value("rikos_paivi_puhe", "molays", molays)
	cfg.set_value("rikos_paivi_puhe", "kysytty_day", kysytty_day)


func load_from(cfg: ConfigFile) -> void:
	nahty = cfg.get_value("rikos_paivi_puhe", "nahty", {})
	molays = cfg.get_value("rikos_paivi_puhe", "molays", false)
	kysytty_day = int(cfg.get_value("rikos_paivi_puhe", "kysytty_day", -1))
	_auki = {}


# --- Testi: aja.sh scene riskit --riski=paivi_puhe [--arg=aamu|selitys|tunnustus|vasta|k18|tallennus] (tyhjä = kaikki) --

var _vikoja := 0


func _vika(t: String) -> void:
	_vikoja += 1
	print("TESTI VIKA paivi_puhe: " + t)


func _frames(n: int) -> void:
	for i in n:
		await game.get_tree().process_frame


func _kuva(suffix: String) -> void:
	var path := "user://riskit_paivi_puhe%s.png" % suffix
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7).replace(".png", "_paivi_puhe%s.png" % suffix)
	await _frames(4)
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
	print("PAIVI_PUHE kuva " + path)


func _alusta() -> void:
	_paivi()._tyhjaksi()
	nahty = {}
	molays = false
	kysytty_day = -1
	_auki = {}
	game._talk_box.close()


## Jälki jonoon eilen ja aamu tänään: palauttaa jäljen päivän.
func _jalki_eilen(id: String) -> int:
	var p: Object = _paivi()
	p.odottaa.append({"id": id, "day": game.day - 1})
	return game.day - 1


## Puheeksiotto (avaa) ja valinta kuten pelissä: palauttaa epäluulon muutoksen.
func _valitse(id: String) -> float:
	var p: Object = _paivi()
	var j: Dictionary = p.seuraava_jalki()
	if j.is_empty():
		_vika("%s: ei jälkeä puheeksi" % id)
		return 0.0
	avaa(j)
	var e0: float = p.epaluulo
	game._talk_choose(id)
	return p.epaluulo - e0


func testi(arg: String) -> void:
	_vikoja = 0
	var vanha_k18: bool = Settings.values.get("k18_pois", false)
	Settings.values["k18_pois"] = false
	var firsts0: Array = game.tilat.firsts.duplicate()
	var moraali0: float = game.tilat.values.moraali
	if arg in ["", "aamu"]:
		await _testi_aamu()
	if arg in ["", "selitys"]:
		_testi_selitys()
	if arg in ["", "tunnustus"]:
		_testi_tunnustus()
	if arg in ["", "vasta"]:
		_testi_vasta()
	if arg in ["", "k18"]:
		_testi_k18()
	if arg in ["", "tallennus"]:
		_testi_tallennus()
	game._talk_box.close()
	_alusta()
	game.tilat.firsts = firsts0
	game.tilat.values.moraali = moraali0
	Settings.values["k18_pois"] = vanha_k18
	print("PAIVI_PUHE testi valmis, %d vikaa" % _vikoja)


## Aamu kotipihalla: tick avaa puheeksioton itse kerran; ilman jälkeä, iltapäivällä tai kaukana ei avaa.
func _testi_aamu() -> void:
	_alusta()
	var w: Node3D = game._active_walker()
	w.global_position = game.home_zone + Vector3(0, 0.3, 4)
	game._note.visible = false
	game.clock_min = 9.0 * 60.0
	await _frames(6)
	print("PAIVI_PUHE ilman jälkeä: auki %s" % game._talk_box.is_open())
	if game._talk_box.is_open():
		_vika("puheeksiotto ilman jälkeä")
	_jalki_eilen("korkki")
	game.clock_min = 13.0 * 60.0
	await _frames(6)
	if game._talk_box.is_open():
		_vika("puheeksiotto iltapäivällä")
	game.clock_min = 9.0 * 60.0
	await _frames(6)
	var ids: Array = game._talk_box._options.map(func(o: Dictionary) -> String: return o.id) if game._talk_box.is_open() else []
	print("PAIVI_PUHE aamu 9:00 %.0f m kodista: auki %s, puhuja %s, jälki %s, valinnat %s" % [
		w.global_position.distance_to(game.home_zone), game._talk_box.is_open(), game._talk_who, _auki.get("id", "-"), ids])
	if not game._talk_box.is_open() or game._talk_who != "paivi" or _auki.get("id", "") != "korkki":
		_vika("aamulla ei puheeksiottoa jäljestä korkki")
	for v in ["paivi_puhe_sel0", "paivi_puhe_sel1", "paivi_puhe_sel2", "paivi_puhe_tunnusta", "paivi_puhe_vasta"]:
		if not v in ids:
			_vika("valinta %s puuttuu" % v)
	await _kuva("_valinta")
	# Suljettu ilman valintaa: ei uudestaan samana aamuna, jälki jää jonoon.
	game._talk_box.close()
	await _frames(6)
	print("PAIVI_PUHE suljettu: auki %s, jonossa %d" % [game._talk_box.is_open(), _paivi().odottaa.size()])
	if game._talk_box.is_open() or _paivi().odottaa.size() != 1:
		_vika("suljetun jälkeen uusi puheeksiotto samana aamuna tai jälki hävisi")
	# Valinta ja vastaus kuvaksi.
	kysytty_day = -1
	await _frames(6)
	game.tilat.firsts.erase("paivi_selitys")
	nahty["pekka"] = [game.day - 1]
	var e0: float = _paivi().epaluulo
	game._talk_choose("paivi_puhe_sel0")
	await _kuva("_vastaus")
	print("PAIVI_PUHE aamu: Pekka-selitys (nähty) %+.0f, first:paivi_selitys %s" % [_paivi().epaluulo - e0,
		"paivi_selitys" in game.tilat.firsts])
	if not "paivi_selitys" in game.tilat.firsts:
		_vika("first:paivi_selitys ei kirjautunut")
	game._talk_box.close()
	await _frames(4)


func _testi_selitys() -> void:
	_alusta()
	var p: Object = _paivi()
	p.epaluulo = 40.0
	# Pekka nähty jäljen päivänä: uskoo (-5).
	var jd := _jalki_eilen("drakkar")
	nahty["pekka"] = [jd]
	var d1 := _valitse("paivi_puhe_sel0")
	# Pekka nähty, mutta eri päivänä: valhe, Pekka möläyttää myöhemmin (+0 nyt, +10 Pekan tervehdyksessä).
	kysytty_day = -1
	jd = _jalki_eilen("korkki")
	nahty["pekka"] = [jd - 3]
	var d2 := _valitse("paivi_puhe_sel0")
	var e0: float = p.epaluulo
	var hello: String = game._talk_hello("pekka")
	var d3: float = p.epaluulo - e0
	var hello2: String = game._talk_hello("pekka")
	# first-ehto: kirppis tehty (-5), ei tehty (+10).
	kysytty_day = -1
	_jalki_eilen("rakaleima")
	if not "kirppis" in game.tilat.firsts:
		game.tilat.firsts.append("kirppis")
	var d4 := _valitse("paivi_puhe_sel1")
	kysytty_day = -1
	_jalki_eilen("kolmio")
	game.tilat.firsts.erase("kirppis")
	var d5 := _valitse("paivi_puhe_sel1")
	print("PAIVI_PUHE selitys: Pekka nähty %+.0f, Pekka ei nähty %+.0f (möläytys %+.0f '%s', toinen tervehdys '%s'), kirppis tehty %+.0f, ei tehty %+.0f, käsitelty %s" % [
		d1, d2, d3, hello, hello2.left(30), d4, d5, p.kasitelty])
	if absf(d1 - USKOO) > 0.01 or absf(d4 - USKOO) > 0.01:
		_vika("tosi selitys ei antanut %+.0f (%+.0f, %+.0f)" % [USKOO, d1, d4])
	if absf(d5 - EI_USKO) > 0.01:
		_vika("epätosi selitys ei antanut %+.0f (%+.0f)" % [EI_USKO, d5])
	if absf(d2) > 0.01 or absf(d3 - EI_USKO) > 0.01 or hello != PEKKA_MOLAYS or hello2 == PEKKA_MOLAYS:
		_vika("Pekan möläytys: heti %+.0f, tervehdyksessä %+.0f, '%s', toinen '%s'" % [d2, d3, hello, hello2])
	for id in ["drakkar", "korkki", "rakaleima", "kolmio"]:
		if p.kasitelty.get(id, "") != "selitys":
			_vika("jälki %s ei käsitelty selityksenä" % id)
	game._talk_box.close()


func _testi_tunnustus() -> void:
	_alusta()
	var p: Object = _paivi()
	p.epaluulo = 50.0
	var m0: float = game.tilat.values.moraali
	_jalki_eilen("drakkar")
	var d := _valitse("paivi_puhe_tunnusta")
	var dm: float = game.tilat.values.moraali - m0
	kysytty_day = -1
	_jalki_eilen("korkki")
	var r := repliikki(p.seuraava_jalki())
	print("PAIVI_PUHE tunnustus %+.0f, moraali %+.2f, tunnustetut %s, seuraava: '%s'" % [d, dm, p.tunnustetut, r])
	if absf(d - TUNNUSTUS) > 0.01 or absf(dm - TUNNUSTUS_MORAALI) > 0.001 or not "drakkar" in p.tunnustetut:
		_vika("tunnustus: %+.1f, moraali %+.3f, tunnustetut %s" % [d, dm, p.tunnustetut])
	if not SELITYKSET.drakkar.nimi in r:
		_vika("Päivi ei muista tunnustusta seuraavalla kerralla")
	game._talk_box.close()


func _testi_vasta() -> void:
	_alusta()
	var p: Object = _paivi()
	p.epaluulo = 50.0
	_jalki_eilen("kolmio")
	var d := _valitse("paivi_puhe_vasta")
	print("PAIVI_PUHE vastahyökkäys %+.0f, vastahyokkays %s, huipennus %s (epäluulo %.0f)" % [d, p.vastahyokkays,
		p.huipennus_auki(), p.epaluulo])
	if absf(d - VASTAHYOKKAYS) > 0.01 or not p.vastahyokkays:
		_vika("vastahyökkäys: %+.1f, lippu %s" % [d, p.vastahyokkays])
	game._talk_box.close()


func _testi_k18() -> void:
	_alusta()
	Settings.values["k18_pois"] = true
	_jalki_eilen("rasvanappi")
	var j: Dictionary = _paivi().seuraava_jalki()
	_jalki_eilen("drakkar")
	var j2: Dictionary = _paivi().seuraava_jalki()
	print("PAIVI_PUHE K-18 pois: rasvanappi -> %s, drakkar -> %s" % [j.get("id", "-"), j2.get("id", "-")])
	if not j.is_empty() or j2.get("id", "") != "drakkar":
		_vika("K-18 pois: K-18-jälki puheeksi tai drakkar puuttuu")
	Settings.values["k18_pois"] = false


func _testi_tallennus() -> void:
	_alusta()
	nahty = {"pekka": [3, 4]}
	molays = true
	kysytty_day = 7
	var cfg := ConfigFile.new()
	save_to(cfg)
	_alusta()
	load_from(cfg)
	print("PAIVI_PUHE tallennus: nahty %s, molays %s, kysytty %d" % [nahty, molays, kysytty_day])
	if nahty.get("pekka", []) != [3, 4] or not molays or kysytty_day != 7:
		_vika("tallennus ei palauttanut tilaa")
	load_from(ConfigFile.new())
	if not nahty.is_empty() or molays or kysytty_day != -1:
		_vika("vanha tallennus ei antanut oletusarvoja")
