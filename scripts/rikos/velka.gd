extends "res://scripts/rikos/osa.gd"
## V1 Velka (Vaala): torin mopopojat antavat annoksen myyntiin luotolla (annos nyt, raha myöhemmin). Velka kasvaa
## korolla joka aamu ja näkyy päiväkirjan Riskit-sivulla. Kolmannen aamun jälkeen mopopojat perivät seuraavalla
## Vaalan-käynnillä: diilitappelu (main.gd _start_teini_fight, game._rikos_fight = self). Voitto kuittaa velan, häviö vie
## rahaa velan verran. Velan voi maksaa milloin vain mopopojille, jos rahat riittävät. Luvut ovat pelin euroja.

const LUOTTO := ["opiaatti", "perv"]  # annokset, joita mopopojat antavat luotolla (main.gd APTEEKKI_MENU)
const LUOTTO_MAX := 2  # annosta saman velan aikana
const LUOTTO_KERROIN := 0.8  # luottohinta suhteessa teinien myyntihintaan (_teini_hinta)
const KATTO := 1000  # velkakatto (€): uutta luottoa ei anneta yli tämän
const KORKO := 0.15  # päivässä, pyöristys tasaeuroihin
const ERA := 3  # aamuja ottamisesta perintään
const PERINTA_VIIVE := 3.0  # s Vaalassa ennen kuin mopopojat kaartavat viereen
const MAINE_VOITTO := 2.0
const MAINE_HAVIO := 5.0

var velka := 0  # €
var paivat := 0  # aamuja velan ottamisesta (tai edellisestä perinnästä)
var otettu := 0  # luotolla otetut annokset tämän velan aikana
var _vaalassa_ms := -1  # perinnän ajastin: Vaalaan tulon hetki (Time.get_ticks_msec), -1 = ei käynnissä
var _tulossa := false  # perintäviesti näytetty, tappelu alkaa ajastimesta


func _init() -> void:
	talkers = []  # mopopojat ovat pelin omia puhujia: osa lisää vain rivit, "Mitä kuuluu?" ja kisat säilyvät


func hinta(base: String) -> int:
	return roundi(LUOTTO_KERROIN * game._teini_hinta(base))


func eraantynyt() -> bool:
	return velka > 0 and paivat >= ERA


func options(who: String, o: Array) -> void:
	if who != "mopopojat":
		return
	for base in LUOTTO:
		var h := hinta(base)
		var syy := ""
		if otettu >= LUOTTO_MAX:
			syy = "luotolla jo %d annosta, maksa ensin velka" % otettu
		elif velka + h > KATTO:
			syy = "velkakatto %d € tulee vastaan" % KATTO
		o.append(game._opt("velka_luotto_" + base, "Ota luotolla: %s (velkaa +%d €, korko %d %% päivässä)" %
			[game._laake_label(base).trim_suffix(" ▲"), h, roundi(KORKO * 100.0)], syy == "", syy))
	if velka > 0:
		o.append(game._opt("velka_maksa", "Maksa velka (%d €)" % velka, game.money >= velka,
			"rahat ei riitä: velka %d €, rahaa %s €" % [velka, game._eur(game.money)]))


func choose(id: String) -> bool:
	if id.begins_with("velka_luotto_"):
		var base := id.trim_prefix("velka_luotto_")
		var h := hinta(base)
		if otettu >= LUOTTO_MAX or velka + h > KATTO:
			game._talk_box.reply("Ei enää. Maksa eka se mitä oot velkaa.", game._talk_options(), "Velka %d €." % velka)
			return true
		if velka == 0:
			paivat = 0
		velka += h
		otettu += 1
		game.laake[base] = int(game.laake.get(base, 0)) + 1
		game.tilat.first("velka_luotto", 0.2)
		game._save_game()
		game._talk_box.reply("Tässä. Kolmen päivän päästä maksat korkoineen, tai tullaan hakemaan.", game._talk_options(),
			"Velka %d €, korko %d %% päivässä. Riskit-sivu (7) päiväkirjassa." % [velka, roundi(KORKO * 100.0)])
		return true
	if id == "velka_maksa":
		if velka <= 0:
			game._talk_box.reply("Ei sulla oo velkaa.", game._talk_options())
		elif game.money < velka:
			game._talk_box.reply("Toi ei riitä. %d € ja velka on kuitattu." % velka, game._talk_options(),
				"Rahaa %s €." % game._eur(game.money))
		else:
			var maksu := velka
			game.money -= maksu
			_kuittaa()
			Sfx.play("coin", -4.0)
			game._save_game()
			game._talk_box.reply("Hyvä. Velka on kuitattu.", game._talk_options(),
				"−%d €. Rahaa %s €." % [maksu, game._eur(game.money)])
		return true
	return false


func _kuittaa() -> void:
	velka = 0
	paivat = 0
	otettu = 0


## Korko ja eräpäivän laskuri kerran päivässä; Päivin lappuun ei mitään (Päivi ei tiedä velasta).
func aamu(_at_m: bool) -> String:
	if velka > 0:
		velka = roundi(velka * (1.0 + KORKO))
		paivat += 1
	_vaalassa_ms = -1
	_tulossa = false
	return ""


## Perintä: erääntynyt velka ja pelaaja Vaalassa ulkona PERINTA_VIIVE s, ei kisaa, ratsiaa eikä välianimaatiota.
func tick(_e: bool) -> void:
	if _tulossa:
		return
	if not game._in_vaala or not eraantynyt():
		_vaalassa_ms = -1
		return
	if game.state != "ulkona" or game.cutscene.busy or game._race != null or game._ratsia_stage != "" and game._ratsia_stage != "done":
		return
	if _vaalassa_ms < 0:
		_vaalassa_ms = Time.get_ticks_msec()
		return
	if Time.get_ticks_msec() - _vaalassa_ms < int(PERINTA_VIIVE * 1000.0):
		return
	_tulossa = true
	game._show_message("Mopopojat kaartaa viereen: \"Velka on erääntynyt. %d €. Me tultiin hakemaan.\"" % velka, 2.5)
	game.get_tree().create_timer(1.6).timeout.connect(_perinta)


func _perinta() -> void:
	_tulossa = false
	_vaalassa_ms = -1
	if game.state != "ulkona" or game.cutscene.busy or not eraantynyt():
		return
	game._rikos_fight = self
	game._start_teini_fight()
	if game.state != "fight":
		game._rikos_fight = null


## Perinnän tappelu: voitto kuittaa velan, häviö vie rahaa velan verran (velka vähenee saman verran).
## Seuraava perintä aikaisintaan ERA aamun päästä, jos velkaa jäi.
func fight_end(won: bool) -> String:
	var t: String
	if won:
		_kuittaa()
		game.maine = clampf(game.maine + MAINE_VOITTO, 0.0, 100.0)
		Sfx.play("win_small", -4.0)
		t = "K.O.! Mopopojat painui tiehensä: \"Unohda koko velka, hullu!\" Velka on kuitattu. Maine +%d." % roundi(MAINE_VOITTO)
	else:
		var vie := mini(floori(game.money), velka)
		game.money -= vie
		velka -= vie
		paivat = 0
		if velka == 0:
			otettu = 0
		game.maine = clampf(game.maine - MAINE_HAVIO, 0.0, 100.0)
		Sfx.play("glass", -6.0, 0.8)
		t = "Hävisit! Mopopojat otti %d € velan lyhennykseksi. %s Maine −%d." % [vie,
			"Velka on kuitattu." if velka == 0 else "Velkaa jäi %d €." % velka, roundi(MAINE_HAVIO)]
	game._save_game()
	return t


func riskit() -> Dictionary:
	if velka <= 0:
		return {}
	var era := "Perintä seuraavalla Vaalan-käynnillä!" if eraantynyt() else \
		"Eräpäivään %d %s." % [ERA - paivat, "päivä" if ERA - paivat == 1 else "päivää"]
	return {"otsikko": "Velka (mopopojat, Vaala)", "mittari": float(velka) / float(KATTO), "rivit": [
		"Velkaa %d € (korko %d %% päivässä, katto %d €)." % [velka, roundi(KORKO * 100.0), KATTO],
		era,
		"Luotolla %d/%d annosta. Maksu mopopojille torilla." % [otettu, LUOTTO_MAX]]}


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("rikos_velka", "tila", {"velka": velka, "paivat": paivat, "otettu": otettu})


func load_from(cfg: ConfigFile) -> void:
	var d := _ints(cfg.get_value("rikos_velka", "tila", {}))
	velka = d.get("velka", 0)
	paivat = d.get("paivat", 0)
	otettu = d.get("otettu", 0)
	_vaalassa_ms = -1
	_tulossa = false


# --- Testi: aja.sh scene riskit --riski=velka -------------------------------------------------------------------

var _vikoja := 0


func _vika(t: String) -> void:
	_vikoja += 1
	print("TESTI VIKA velka: " + t)


func _valinta(id: String) -> Dictionary:
	game._talk_who = "mopopojat"
	for o in game._talk_options("mopopojat"):
		if o.id == id:
			return o
	return {}


func _frames(n: int) -> void:
	for i in n:
		await game.get_tree().process_frame


func _kuva(suffix: String) -> void:
	var path := "user://riskit_velka%s.png" % suffix
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7).replace(".png", "_velka%s.png" % suffix)
	await _frames(4)
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
	print("VELKA kuva " + path)


## Perinnän tappelu Vaalassa: odotetaan, että tick aloittaa sen, ja lopetetaan won-tuloksella kuten tappelu.
func _perinta_testi(won: bool) -> void:
	var t0 := Time.get_ticks_msec()
	while game.state != "fight" and Time.get_ticks_msec() - t0 < 30000:
		if game.wife != null and game.state != "cutscene":
			game.clock_min = 12.0 * 60.0
		await game.get_tree().process_frame
	print("VELKA perintä: tila %s, _rikos_fight on tämä %s, %.1f s" % [game.state, game._rikos_fight == self, (Time.get_ticks_msec() - t0) / 1000.0])
	if game.state != "fight" or game._rikos_fight != self:
		_vika("perintä ei alkanut (tila %s)" % game.state)
		return
	await _kuva("_tappelu" if won else "_tappelu2")
	if not won:
		game.fight._p.state = "ko"
	game.fight._end()  # finished-signaali: _on_fight_finished -> _teini_fight_end -> fight_end
	await _frames(4)
	print("VELKA perintä %s: viesti '%s', tila %s" % ["voitto" if won else "häviö", game._msg.text, game.state])
	if game._rikos_fight != null or game.state == "fight":
		_vika("tappelu ei päättynyt")


func testi(_arg: String) -> void:
	_kuittaa()
	game.money = 0.0
	game.laake = {}
	game.maine = 50.0
	# V1.1 luotto: kaksi annosta, kolmas estetty syyn kanssa.
	var o := _valinta("velka_luotto_opiaatti")
	print("VELKA valinta: %s" % [o])
	if o.is_empty() or not o.enabled:
		_vika("luottovalinta puuttuu tai estetty: %s" % [o])
	if not _valinta("velka_maksa").is_empty():
		_vika("maksuvalinta näkyy ilman velkaa")
	var h := hinta("opiaatti")
	game._talk_choose("velka_luotto_opiaatti")
	game._talk_choose("velka_luotto_opiaatti")
	print("VELKA luotto 2 × %d €: velka %d, otettu %d, laake %s" % [h, velka, otettu, game.laake])
	if velka != 2 * h or otettu != 2 or game.laake.get("opiaatti", 0) != 2:
		_vika("luotto: velka %d (odotettiin %d), laake %s" % [velka, 2 * h, game.laake])
	o = _valinta("velka_luotto_perv")
	print("VELKA kolmas luotto: enabled %s, syy '%s'" % [o.get("enabled"), o.get("reason")])
	if o.get("enabled", true) or str(o.get("reason", "")) == "":
		_vika("kolmas luotto ei estynyt syyn kanssa")
	game._talk_choose("velka_luotto_perv")
	if velka != 2 * h:
		_vika("estetty luotto lisäsi velkaa")
	# V1.4 maksu ilman rahaa: valinta estetty syyn kanssa, valinta ei muuta mitään eikä jumita.
	game.money = 100.0
	o = _valinta("velka_maksa")
	print("VELKA maksu 100 €:lla: enabled %s, syy '%s'" % [o.get("enabled"), o.get("reason")])
	if o.is_empty() or o.enabled or not "rahat" in str(o.reason):
		_vika("maksu ilman rahaa: %s" % [o])
	game._talk_choose("velka_maksa")
	if velka != 2 * h or game.money != 100.0:
		_vika("maksu ilman rahaa muutti tilaa: velka %d rahat %s" % [velka, game.money])
	# Riskit-sivun data.
	var rs: Array = game.journal_data().get("riskit", [])
	print("VELKA riskit %s" % [rs])
	if rs.filter(func(d: Dictionary) -> bool: return str(d.otsikko).begins_with("Velka")).is_empty():
		_vika("velka ei näy Riskit-sivulla")
	# V1.2 korko: 15 % aamussa tasaeuroihin; tallennus ja lataus edestakaisin.
	var ennen := velka
	aamu(false)
	print("VELKA korko %d -> %d (päivät %d)" % [ennen, velka, paivat])
	if velka != roundi(ennen * 1.15) or paivat != 1:
		_vika("korko %d -> %d" % [ennen, velka])
	var tallessa := [velka, paivat, otettu]
	game._save_game()
	_kuittaa()
	game._load_game()
	print("VELKA tallennus %s -> %s" % [tallessa, [velka, paivat, otettu]])
	if [velka, paivat, otettu] != tallessa:
		_vika("tallennus/lataus %s -> %s" % [tallessa, [velka, paivat, otettu]])
	# Maksu, kun rahat riittävät.
	game.money = float(velka) + 20.0
	game._talk_choose("velka_maksa")
	print("VELKA maksu: velka %d rahat %s" % [velka, game.money])
	if velka != 0 or game.money != 20.0:
		_vika("maksu: velka %d rahat %s" % [velka, game.money])
	# Riskit-sivun kuva velan kanssa.
	velka = 458
	paivat = 2
	otettu = 2
	game._talk_box.close()
	game._journal.open_at("riskit")
	await _frames(10)
	await _kuva("_riskit")
	game._journal.toggle()
	await _frames(4)
	# Ei perintää ennen eräpäivää eikä Saloisissa.
	paivat = 3
	await _frames(10)
	if game.state == "fight":
		_vika("perintä alkoi Saloisissa")
	# V1.3 perintä Vaalassa: voitto.
	game._start_mopo()
	await _frames(30)
	game.maine = 50.0
	game.money = 300.0
	await _perinta_testi(true)
	print("VELKA voiton jälkeen: velka %d maine %.0f rahat %s" % [velka, game.maine, game.money])
	if velka != 0 or game.maine != 52.0 or game.money != 300.0:
		_vika("voitto: velka %d maine %.0f rahat %s" % [velka, game.maine, game.money])
	# Häviö: rahat 300 < velka 500, velka vähenee 200:aan ja perintä odottaa taas ERA aamua.
	velka = 500
	paivat = 3
	otettu = 2
	await _frames(10)
	await _perinta_testi(false)
	print("VELKA häviön jälkeen: velka %d maine %.0f rahat %s päivät %d" % [velka, game.maine, game.money, paivat])
	if velka != 200 or game.maine != 47.0 or game.money != 0.0 or paivat != 0:
		_vika("häviö: velka %d maine %.0f rahat %s" % [velka, game.maine, game.money])
	await _frames(10)
	if game.state == "fight":
		_vika("perintä alkoi uudestaan heti häviön jälkeen")
	# Häviö, kun rahaa on enemmän kuin velkaa: vain velan verran.
	game.money = 800.0
	velka = 500
	fight_end(false)
	print("VELKA häviö 800 €:lla: velka %d rahat %s" % [velka, game.money])
	if velka != 0 or game.money != 300.0 or otettu != 0:
		_vika("häviö rahalla: velka %d rahat %s" % [velka, game.money])
	print("VELKA testi valmis, %d vikaa" % _vikoja)
