extends "res://scripts/rikos/osa.gd"
## Luku 6 "Päivi epäilee" (#326), Päivi tutkii: kun paivi.gd tutkii() (epäluulo yli 60, K-18 sallittu, Päivi kotona),
## Päivi lähtee iltaisin klo 19–21 "jumppaan" seuraintalolle (main.gd _wife_rhythm -> wife_car.gd go_jumppa, ei jahtaa).
## Pelaaja voi seurata Hyundaita: liian lähellä (alle 25 m yli 3 s) Päivi huomaa (+10), kauempaa (25–80 m) näkee, mihin
## Päivi oikeasti menee (first:paivi_seurattu). Päivi kyselee kyläläisiltä: Pekan, Sinikan, Hilkan ja Pentin tervehdys
## kertoo, mitä Päivi kysyi ja mitä he vastasivat; vastaus riippuu pelaajan teoista (ensikerrat). Aamulla tutkiva Päivi
## etsii jemmat tarkemmin (main.gd _jemma_check: etsinta, loysi_jemman) ja löytää jemman ulkopuolella olevan
## korkkikansion (kansio_check). Epäluuloa muutetaan vain paivi.lisaa()-kautta.

const JUMPPA := Vector2(19.0 * 60.0, 21.0 * 60.0)  # pelimin.: Päivi "jumpassa"
const LAHELLA := 25.0  # m: tätä lähempänä Päivi huomaa seuraajan
const KAUKANA := 80.0  # m: tätä lähempänä pelaaja näkee, mihin Päivi menee
const HUOMAA_S := 3.0  # s yhtäjaksoisesti etäisyydellä
const HUOMASI := 10.0  # liian lähellä seurattu
const LOYTO := 10.0  # täysi kotijemma tai korkkikansio löytyi
const ETSINTA := 2.0  # tutkiva Päivi: jemman löytymisen kerroin
const KYSELY := 5.0  # kyläläisen vastaus: + paljastaa, - puolustaa
const KYSELY_VALI := 3  # päivää: Päivi kysyy samalta uudestaan vasta tämän jälkeen

const HUOMASI_REPLIIKKI := "Päivi kurkistaa Hyundain ikkunasta: \"Mitä sää mua seuraat? Mee kotiin! Ja tästä puhutaan vielä.\""
const SEURATTU_REPLIIKKI := "Seuraintalolta kuuluu humppaa. Päivi menee sisään jumppakassi olalla... Jumppaa vai tansseja?"

## Kyläläisen vastaus: [ehto ("first:<avain>" tai "" = muuten), epäluulon muutos, repliikki]. Ensimmäinen täyttyvä voittaa.
## Pekan rivit alkavat luku 6:n tarinavihjeellä (quests.gd p_tutkii), joka merkitään kuulluksi samalla.
const PEKKA_VIHJE := "Päivi kyseli musta eilen, mitä me oikein kalastettiin."
const VASTAUKSET := {
	"pekka": [
		["first:kalastus", -KYSELY, " Mää sanoin, että ahvenia, ja kerroin sen hauen, jonka sää sait. Ihan totta, ja sen se kuuli äänestä."],
		["", KYSELY, " Mää en osannu sanoa mitään. Ei me olla kalastettu yhessä koko kesänä. Se kirjotti jotain vihkoon."]],
	"sinikka": [
		["first:sinikka_taimet", -KYSELY, "Päivi kävi kysymässä susta. Mää sanoin, että autoit mua tomaatintaimien kanssa. Hyvä mies sää oot, sanoin."],
		["first:tanssit", KYSELY, "Päivi kävi kysymässä susta... ja mää vähän lipsautin niistä seuraintalon tansseista. Anteeks, kulta."],
		["", 0.0, "Päivi kävi kysymässä susta. Mitä mää muka tietäisin? Sanoin, ettei mulle kuulu."]],
	"hilkka": [
		["first:oma_kirppispoyta", -KYSELY, "Sun vaimo kysy, mitä sää kirppiksellä teet. Mää sanoin, että myyt rehellisesti tavaraa omasta pöydästä."],
		["first:kirppis", 0.0, "Sun vaimo kysy, mitä sää kirppiksellä teet. Mää sanoin, että kiertelet pöytiä niinku muutki."],
		["", KYSELY, "Sun vaimo kysy, ootko käyny kirppiksellä. Mää sanoin, etten oo nähny sua koko kesänä. Missä sää sitten oot?"]],
	"pentti": [
		["first:pentti_kyyti", KYSELY, "Päivi kävi kysymässä BangBusista. Mää sanoin, että kuski ei kerro matkustajista. Mutta se näki sun kuvan kiertuevihkosta."],
		["", -KYSELY, "Päivi kävi kysymässä, ootko istunu mun kyydissä. Mää sanoin, ettei oo koskaan. Totta se oli."]],
}
## Pentin vihje huipennukseen (lippu paivi_pentti_vihje): Päivi kysyi myös kesästä -96.
const PENTTI_VIHJE := " Ja yks juttu: se kysy, muistanko mää kesän -96 Saloisten lavalta. Outo kysymys, sanoin."

var alku := -1  # päivä, jona Päivi alkoi tutkia (kyläläiset kertovat kyselystä seuraavasta päivästä alkaen)
var kysytty := {}  # puhuja -> päivä, jona hän kertoi Päivin kyselystä
var huomasi_day := -1  # päivä, jona Päivi huomasi seuraajan (kerran päivässä)
var seurattu_day := -1  # päivä, jona pelaaja näki Päivin menevän seuraintalolle
var kansio_loydetty := false  # korkkikansio jemman ulkopuolella löytyy kerran
var _lahella_t := 0.0
var _kaukana_t := 0.0


func _init() -> void:
	talkers = []  # tervehdys vain (hello), ei omia valintoja


func _paivi() -> Object:
	return game.rikos_osa("paivi")


## main.gd _wife_rhythm: onko Päivi nyt "jumpassa" (t = kello pelimin.).
func jumppa_aika(t: float) -> bool:
	if t < JUMPPA.x or t >= JUMPPA.y:
		return false
	var p: Object = _paivi()
	return p != null and p.tutkii()


func tick(_e: bool) -> void:
	var w: Node3D = game.wife
	if w == null or not w.jumppa or game._in_vaala:  # halpa ehto ensin (K21): ei jumppaa = ei mitään
		_lahella_t = 0.0
		_kaukana_t = 0.0
		return
	_aloita()
	var dt: float = game.get_process_delta_time()
	var pp: Vector3 = game.player.global_position
	var d := Vector2(pp.x - w.global_position.x, pp.z - w.global_position.z).length()
	_lahella_t = _lahella_t + dt if d < LAHELLA else 0.0
	_kaukana_t = _kaukana_t + dt if d >= LAHELLA and d <= KAUKANA else 0.0
	if _lahella_t > HUOMAA_S and huomasi_day != game.day:
		huomasi_day = game.day
		_paivi().lisaa(HUOMASI, "seurattu")
		game._queue_message("%s\n(Päivin epäluulo %+d)" % [HUOMASI_REPLIIKKI, roundi(HUOMASI)], 5.0)
	elif _kaukana_t > HUOMAA_S and w.jumppa_perilla and seurattu_day != game.day and huomasi_day != game.day:
		seurattu_day = game.day
		game.tilat.first("paivi_seurattu", 0.3)
		game.tilat.first("paivi_tutkii", 0.0)
		game._queue_message(SEURATTU_REPLIIKKI, 5.0)


## Tutkinta alkoi (kyläläiset kertovat kyselystä vasta seuraavana päivänä: "kyseli eilen").
func _aloita() -> void:
	if alku < 0:
		alku = game.day


func aamu(_at_m: bool) -> String:
	var p: Object = _paivi()
	if p != null and p.tutkii():
		_aloita()
	return ""


func hello(who: String) -> String:
	if not VASTAUKSET.has(who):
		return ""
	var p: Object = _paivi()
	if p == null or not p.tutkii() or alku < 0 or game.day <= alku:
		return ""
	if kysytty.has(who) and game.day - int(kysytty[who]) < KYSELY_VALI:
		return ""
	kysytty[who] = game.day
	var v: Array = vastaus(who)
	var n: float = v[1]
	var t: String = v[2]
	if who == "pekka":
		game._story_hint("pekka", true)  # vihje kuulluksi (päiväkirja), repliikki tulee tästä
		t = PEKKA_VIHJE + t
	elif who == "pentti":
		t += PENTTI_VIHJE
		p.liput["paivi_pentti_vihje"] = true  # paivi.gd flag -> quest_flag("paivi_pentti_vihje")
	if absf(n) > 0.01:
		p.lisaa(n, "kysely:" + who)
		t += "\n(Päivin epäluulo %+d)" % roundi(n)
	game.tilat.first("paivi_tutkii", 0.0)
	return t


## Kyläläisen vastaus pelaajan tekojen mukaan: [ehto, muutos, repliikki].
func vastaus(who: String) -> Array:
	for v: Array in VASTAUKSET[who]:
		var ehto: String = v[0]
		if ehto == "" or (ehto.begins_with("first:") and ehto.substr(6) in game.tilat.firsts):
			return v
	return VASTAUKSET[who][-1]


## main.gd _jemma_check: jemman löytymisen kerroin (tutkiva Päivi etsii tarkemmin).
func etsinta() -> float:
	var p: Object = _paivi()
	return ETSINTA if p != null and p.tutkii() else 1.0


## main.gd _jemma_check: Päivi löysi täyden kotijemman.
func loysi_jemman() -> void:
	var p: Object = _paivi()
	if p == null or not p.tutkii():
		return
	p.lisaa(LOYTO, "jemma")
	game.tilat.first("paivi_tutkii", 0.0)


## main.gd _jemma_check: korkkikansio jemman ulkopuolella (korkit.piilossa false) löytyy kerran. Palauttaa aamulapun rivin.
func kansio_check() -> String:
	var p: Object = _paivi()
	if kansio_loydetty or p == null or not p.tutkii():
		return ""
	var k: Object = game.korkit
	if k == null or k.piilossa or k.owned.is_empty():
		return ""
	kansio_loydetty = true
	p.lisaa(LOYTO, "korkkikansio")
	game.tilat.first("paivi_tutkii", 0.0)
	return "\nKävin läpi sun tavarat. Korkkikansio oli lipaston päällä, ja mää laskin jokaisen korkin. Kenen kanssa sää ne joit?"


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("rikos_paivi_tutkii", "alku", alku)
	cfg.set_value("rikos_paivi_tutkii", "kysytty", kysytty)
	cfg.set_value("rikos_paivi_tutkii", "huomasi_day", huomasi_day)
	cfg.set_value("rikos_paivi_tutkii", "seurattu_day", seurattu_day)
	cfg.set_value("rikos_paivi_tutkii", "kansio_loydetty", kansio_loydetty)


## Vanha tallennus: oletusarvot.
func load_from(cfg: ConfigFile) -> void:
	alku = int(cfg.get_value("rikos_paivi_tutkii", "alku", -1))
	kysytty = _ints(cfg.get_value("rikos_paivi_tutkii", "kysytty", {}))
	huomasi_day = int(cfg.get_value("rikos_paivi_tutkii", "huomasi_day", -1))
	seurattu_day = int(cfg.get_value("rikos_paivi_tutkii", "seurattu_day", -1))
	kansio_loydetty = bool(cfg.get_value("rikos_paivi_tutkii", "kansio_loydetty", false))


# --- Testi: aja.sh scene riskit --riski=paivi_tutkii [--arg=jumppa|kysely|jemma|k18|tallennus] (tyhjä = kaikki) -----

var _vikoja := 0


func _vika(t: String) -> void:
	_vikoja += 1
	print("TESTI VIKA paivi_tutkii: " + t)


func _alusta() -> void:
	_paivi()._tyhjaksi()
	alku = -1
	kysytty = {}
	huomasi_day = -1
	seurattu_day = -1
	kansio_loydetty = false
	_lahella_t = 0.0
	_kaukana_t = 0.0


func _frames(n: int) -> void:
	for i in n:
		await game.get_tree().process_frame


## Odottaa s sekuntia; joka ruutu f() (esim. pelaajan paikka auton mukaan).
func _odota(s: float, f := Callable()) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		if f.is_valid():
			f.call()
		await game.get_tree().process_frame


func _kuva(suffix: String) -> void:
	var path := "user://riskit_paivi_tutkii%s.png" % suffix
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7).replace(".png", "_paivi_tutkii%s.png" % suffix)
	await _frames(3)
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
	print("PAIVI_TUTKII kuva " + path)


## Lähikuva omalla kameralla from -> at.
func _lahikuva(suffix: String, from: Vector3, at: Vector3, fov := 45.0) -> void:
	var prev: Camera3D = game.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	game.add_child(cam)
	cam.fov = fov
	cam.look_at_from_position(from, at)
	cam.make_current()
	await _kuva(suffix)
	cam.queue_free()
	if prev != null:
		prev.make_current()


func testi(arg: String) -> void:
	_vikoja = 0
	var vanha_k18: bool = Settings.values.get("k18_pois", false)
	Settings.values["k18_pois"] = false
	var firsts0: Array = game.tilat.firsts.duplicate()
	if arg in ["", "kysely"]:
		_testi_kysely()
	if arg in ["", "jemma"]:
		_testi_jemma()
	if arg in ["", "k18"]:
		_testi_k18()
	if arg in ["", "tallennus"]:
		_testi_tallennus()
	if arg in ["", "jumppa"]:
		await _testi_jumppa()
	_alusta()
	game.tilat.firsts = firsts0
	Settings.values["k18_pois"] = vanha_k18
	print("PAIVI_TUTKII testi valmis, %d vikaa" % _vikoja)


## Kyläläisten vastaukset: teko tehty vs. ei tehty antaa eri repliikin ja eri muutoksen; kerran KYSELY_VALI:ssä.
func _testi_kysely() -> void:
	_alusta()
	var p: Object = _paivi()
	var tapaukset := {"pekka": ["kalastus"], "sinikka": ["sinikka_taimet", "tanssit"], "hilkka": ["oma_kirppispoyta", "kirppis"],
		"pentti": ["pentti_kyyti"]}
	p.epaluulo = 70.0
	if hello("pekka") != "":
		_vika("kysely ennen tutkinnan alkua (alku -1)")
	alku = game.day
	if hello("pekka") != "":
		_vika("kysely samana päivänä, kun tutkinta alkoi")
	alku = game.day - 1
	for who in tapaukset:
		var rivit: Array = []
		var keys: Array = tapaukset[who]
		# Teot yksi kerrallaan (ensimmäinen ehto voittaa), lopuksi ei mitään tehty.
		for i in keys.size() + 1:
			for k in keys:
				game.tilat.firsts.erase(k)
			if i < keys.size():
				game.tilat.firsts.append(keys[i])
			kysytty.erase(who)
			p.epaluulo = 70.0
			var t: String = game._talk_hello(who)
			var d: float = p.epaluulo - 70.0
			rivit.append([keys[i] if i < keys.size() else "-", d, t])
			print("PAIVI_TUTKII %s teko %s: %+.0f \"%s\"" % [who, rivit[-1][0], d, t.replace("\n", " / ")])
			if t == "" or not (t.begins_with(PEKKA_VIHJE) if who == "pekka" else true):
				_vika("%s: ei kyselyvastausta (teko %s)" % [who, rivit[-1][0]])
		var tekstit := {}
		for r in rivit:
			tekstit[r[2]] = true
		if tekstit.size() != rivit.size():
			_vika("%s: sama vastaus eri teoille" % who)
		if absf(rivit[0][1] - rivit[-1][1]) < 0.01:
			_vika("%s: teko ei muuta epäluulon muutosta (%+.0f / %+.0f)" % [who, rivit[0][1], rivit[-1][1]])
		# Toinen kysely samana tai seuraavana päivänä: pelin oma tervehdys (ei uutta muutosta).
		var e0: float = p.epaluulo
		if hello(who) != "" or absf(p.epaluulo - e0) > 0.01:
			_vika("%s: kysely toistui samana päivänä" % who)
		for k in keys:
			game.tilat.firsts.erase(k)
	if not p.flag("paivi_pentti_vihje") or not game.quest_flag("paivi_pentti_vihje"):
		_vika("Pentin vihje ei asettanut lippua paivi_pentti_vihje")
	if not "paivi_tutkii" in game.tilat.firsts:
		_vika("first:paivi_tutkii ei kirjautunut kyselystä")
	# Epäluulo alle rajan: ei kyselyä.
	kysytty = {}
	p.epaluulo = 50.0
	if hello("sinikka") != "":
		_vika("kysely, vaikka Päivi ei tutki (50)")
	print("PAIVI_TUTKII pentin vihje %s, first:paivi_tutkii %s" % [game.quest_flag("paivi_pentti_vihje"), "paivi_tutkii" in game.tilat.firsts])


## Jemmat: tutkiva Päivi etsii kahdella kertoimella, täysi kotijemma +10, korkkikansio jemman ulkopuolella +10 kerran.
func _testi_jemma() -> void:
	_alusta()
	var p: Object = _paivi()
	p.epaluulo = 50.0
	var et0 := etsinta()
	p.epaluulo = 70.0
	var et1 := etsinta()
	print("PAIVI_TUTKII etsintäkerroin 50: %.1f, 70: %.1f" % [et0, et1])
	if et0 != 1.0 or et1 != ETSINTA:
		_vika("etsintäkerroin %.1f / %.1f" % [et0, et1])
	# Koko _jemma_check: eteisen kaappi täynnä (löytyy varmasti: 0,5 * 2), kansio lipaston päällä.
	var st0: Dictionary = game.stash.duplicate()
	var k: Object = game.korkit
	var owned0: Dictionary = k.owned.duplicate()
	var piilossa0: bool = k.piilossa
	var choco0: bool = game.has_chocolate
	game.has_chocolate = false
	for id in game.STASHES:
		if game.STASHES[id].home:
			game.stash[id] = 0
	game.stash["koti"] = game.STASHES.koti.cap
	k.owned = {"koff:1": 3}
	k.piilossa = false
	game.tilat.firsts.erase("paivi_tutkii")
	var e0: float = p.epaluulo
	var note: String = game._jemma_check(true)
	var d: float = p.epaluulo - e0
	print("PAIVI_TUTKII jemma+kansio: %+.0f, eteinen %d -> %d, lappu \"%s\"" % [d, game.STASHES.koti.cap, game.stash.koti,
		note.replace("\n", " / ")])
	if absf(d - 2.0 * LOYTO) > 0.01 or not "Korkkikansio" in note or game.stash.koti >= game.STASHES.koti.cap:
		_vika("jemma ja kansio eivät nostaneet 2 x %.0f (%+.1f)" % [LOYTO, d])
	if not "paivi_tutkii" in game.tilat.firsts:
		_vika("first:paivi_tutkii ei kirjautunut löydöstä")
	# Kansio vain kerran; jemmassa olevaa ei löydy; Päivi ei tutki -> ei mitään.
	e0 = p.epaluulo
	var n2 := kansio_check()
	kansio_loydetty = false
	k.piilossa = true
	var n3 := kansio_check()
	k.piilossa = false
	p.epaluulo = 40.0
	var n4 := kansio_check()
	print("PAIVI_TUTKII kansio toinen kerta \"%s\", jemmassa \"%s\", ei tutki \"%s\"" % [n2, n3, n4])
	if n2 != "" or n3 != "" or n4 != "":
		_vika("korkkikansio löytyi uudelleen, jemmasta tai ilman tutkintaa")
	var e1: float = p.epaluulo
	loysi_jemman()
	if absf(p.epaluulo - e1) > 0.01:
		_vika("jemmalöytö nosti, vaikka Päivi ei tutki")
	game.stash = st0
	k.owned = owned0
	k.piilossa = piilossa0
	game.has_chocolate = choco0


func _testi_k18() -> void:
	_alusta()
	var p: Object = _paivi()
	p.epaluulo = 90.0
	alku = game.day - 1
	Settings.values["k18_pois"] = true
	var ok := jumppa_aika(19.5 * 60.0)
	var h: String = hello("pentti")
	var et := etsinta()
	var kn := kansio_check()
	print("PAIVI_TUTKII K-18 pois: jumppa %s, kysely \"%s\", etsintä %.1f, kansio \"%s\"" % [ok, h, et, kn])
	if ok or h != "" or et != 1.0 or kn != "":
		_vika("K-18 pois: Päivi tutkii silti")
	Settings.values["k18_pois"] = false


func _testi_tallennus() -> void:
	_alusta()
	alku = 3
	kysytty = {"pekka": 4, "hilkka": 5}
	huomasi_day = 6
	seurattu_day = 7
	kansio_loydetty = true
	var cfg := ConfigFile.new()
	save_to(cfg)
	_alusta()
	load_from(cfg)
	print("PAIVI_TUTKII tallennus alku %d, kysytty %s, huomasi %d, seurattu %d, kansio %s" % [alku, kysytty, huomasi_day,
		seurattu_day, kansio_loydetty])
	if alku != 3 or kysytty.get("hilkka", -1) != 5 or huomasi_day != 6 or seurattu_day != 7 or not kansio_loydetty:
		_vika("tallennus ei palauttanut tilaa")
	load_from(ConfigFile.new())
	if alku != -1 or not kysytty.is_empty() or kansio_loydetty:
		_vika("vanha tallennus ei antanut oletusarvoja")


## Jumppa ja seuranta pelimaailmassa: _wife_rhythm vie Hyundain seuraintalolle, pelaaja seuraa kaukaa ja liian läheltä.
func _testi_jumppa() -> void:
	_alusta()
	var p: Object = _paivi()
	var w: Node3D = game.wife
	var pl: Node3D = game._active_walker()
	var talo: Vector3 = game.M.w(game.M.SEURAINTALO)
	# Ei tutki: klo 19.30 tavallinen partio.
	p.epaluulo = 40.0
	game._wife_phase = ""
	game.clock_min = 19.5 * 60.0
	game._wife_rhythm(game.clock_min)
	print("PAIVI_TUTKII epäluulo 40 klo 19.30: vaihe %s, jumppa %s" % [game._wife_phase, w.jumppa])
	if w.jumppa or game._wife_phase == "jumppa":
		_vika("jumppa, vaikka Päivi ei tutki")
	# Tutkii: Hyundai noin 150 m päähän tielle, jumppa alkaa.
	p.epaluulo = 70.0
	var start: int = game.world.nearest_node(talo + Vector3(150, 0, 60))
	w.reset_to(start)
	game.clock_min = 19.0 * 60.0 + 1.0
	game._wife_rhythm(game.clock_min)
	print("PAIVI_TUTKII epäluulo 70 klo 19.01: vaihe %s, jumppa %s, kohde %s, auto %.0f m talolta" % [game._wife_phase,
		w.jumppa, w.dest, Vector2(w.global_position.x - talo.x, w.global_position.z - talo.z).length()])
	if not w.jumppa or game._wife_phase != "jumppa":
		_vika("jumppa ei alkanut klo 19")
	# Seuranta matkalla 45 m takana: ei huomaa, ei jahtaa.
	var takana := func() -> void:
		var f: Vector3 = -w.global_transform.basis.z
		var q: Vector3 = w.global_position - f * 45.0
		pl.global_position = Vector3(q.x, game.Terrain.h(q.x, q.z) + 0.2, q.z)
		pl.velocity = Vector3.ZERO
		game.clock_min = 19.0 * 60.0 + 5.0
	await _odota(4.0, takana)
	await _kuva("_seuranta")  # pelikamera pelaajan takaa
	var cpos: Vector3 = w.global_position + w.global_transform.basis.x * 5.0 + Vector3(0, 2.2, 0) - w.global_transform.basis.z * 3.0
	await _lahikuva("_kuski", cpos, w.global_position + Vector3(0, 1.0, 0), 50.0)
	var t0 := Time.get_ticks_msec()
	while not w.jumppa_perilla and Time.get_ticks_msec() - t0 < 60000:
		takana.call()
		await game.get_tree().process_frame
	var dt := Vector2(w.global_position.x - talo.x, w.global_position.z - talo.z).length()
	print("PAIVI_TUTKII perillä %s (%.1f s), auto %.0f m seuraintalosta, kuski näkyy %s, tila %s, epäluulo %.0f" % [
		w.jumppa_perilla, (Time.get_ticks_msec() - t0) / 1000.0, dt, w._kuski.visible, w.mode, p.epaluulo])
	if not w.jumppa_perilla or dt > 40.0 or w._kuski.visible or w.mode == "chase":
		_vika("Hyundai ei pysähtynyt seuraintalolle tai jahtaa")
	if absf(p.epaluulo - 70.0) > 0.01:
		_vika("seuranta 45 m päästä nosti epäluuloa")
	# Kaukaa (50 m) 3,5 s: näkee, mihin Päivi meni.
	var park: Vector3 = w.global_position
	var suunta: Vector3 = (Vector3(park.x - talo.x, 0, park.z - talo.z)).normalized()
	if suunta.length() < 0.5:
		suunta = Vector3(1, 0, 0)
	var kauas := func() -> void:
		var q: Vector3 = park + suunta * 50.0
		pl.global_position = Vector3(q.x, game.Terrain.h(q.x, q.z) + 0.2, q.z)
		pl.velocity = Vector3.ZERO
		game.clock_min = 19.0 * 60.0 + 30.0
	await _odota(HUOMAA_S + 0.7, kauas)
	print("PAIVI_TUTKII 50 m %.1f s: first:paivi_seurattu %s, first:paivi_tutkii %s, epäluulo %.0f" % [HUOMAA_S + 0.7,
		"paivi_seurattu" in game.tilat.firsts, "paivi_tutkii" in game.tilat.firsts, p.epaluulo])
	if not "paivi_seurattu" in game.tilat.firsts or absf(p.epaluulo - 70.0) > 0.01:
		_vika("kaukaa seuraaminen ei kirjannut paivi_seurattu tai muutti epäluuloa")
	await _kuva("_perilla")
	await _lahikuva("_parkki", park + suunta * 14.0 + Vector3(0, 6.0, 0), park + Vector3(0, 0.8, 0), 55.0)
	# Liian lähelle (15 m) 3,5 s: Päivi huomaa, +10 kerran.
	var lahelle := func() -> void:
		var q: Vector3 = park + suunta * 15.0
		pl.global_position = Vector3(q.x, game.Terrain.h(q.x, q.z) + 0.2, q.z)
		pl.velocity = Vector3.ZERO
		game.clock_min = 19.0 * 60.0 + 40.0
	await _odota(HUOMAA_S + 0.7, lahelle)
	var d1: float = p.epaluulo - 70.0
	await _odota(HUOMAA_S + 0.7, lahelle)
	print("PAIVI_TUTKII 15 m: %+.0f, toinen kerta samana päivänä %+.0f, jahti %s" % [d1, p.epaluulo - 70.0 - d1, w.mode])
	if absf(d1 - HUOMASI) > 0.01 or absf(p.epaluulo - 70.0 - d1) > 0.01 or w.mode == "chase":
		_vika("liian läheltä seuraaminen ei antanut %+.0f kerran (tai jahti alkoi)" % HUOMASI)
	await _kuva("_huomasi")
	# Klo 21: jumppa ohi, Päivi rattiin ja partioon.
	game.clock_min = 21.0 * 60.0 + 1.0
	game._wife_rhythm(game.clock_min)
	print("PAIVI_TUTKII klo 21.01: vaihe %s, jumppa %s, kuski näkyy %s" % [game._wife_phase, w.jumppa, w._kuski.visible])
	if w.jumppa or game._wife_phase != "partio" or not w._kuski.visible:
		_vika("jumppa ei päättynyt klo 21")
	game.clock_min = 12.0 * 60.0
	game._wife_rhythm(game.clock_min)
