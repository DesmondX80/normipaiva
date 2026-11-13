extends Node
## Luku 6 "Päivi epäilee" (#326): Kesäheila -96 -huipennus main.gd:ssä (_kesaheila_*, _kolmio_sal_site). Sytkärin
## mätsi (vain huipennus auki ja K-18 sallittu), kolmiomittaus kotiin (leikkausalueen keskipiste kodin ovesta),
## Päivin auto kotona mittauksen ajan, etuovi koputtaa eikä vie sisään, ovikohtaus, valinnat suuttua (poissa, tyhjä
## jääkaappi, ei lappua, paluu kukilla), tunnustaa (Avoin pelikortti, syntilistat) ja nauraa (epäluulo 0, Kulissit
## kunnossa, aamu keittiössä), viikon paluu ja tallennus. main.gd palauttaa tallennuksen.
## Ajo: tools/testit/aja.sh scene kolmiomittaus_koti
## Kuvat: _matsi, _kartta, _ovi_vihje, _ovi, _valinta, _suuttua, _suuttua_aamu, _kukat_valinta, _tunnustaa, _paluu_aamu,
## _nauraa, _aamu, _aamu_jalkeen.

const Kolmio := preload("res://scripts/kolmiomittaus.gd")
const Terrain := preload("res://scripts/terrain.gd")
const M := preload("res://scripts/map_data.gd")

var main: Node3D
var vikoja := 0


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + t)


func _shot_path(suffix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			return a.substr(7).replace(".png", suffix + ".png")
	return "user://kesaheila%s.png" % suffix


## Häiriöt pois heti alussa ja joka odotuksessa (uusi päivä luo uuden auton): kiinnijäänti, kello illassa.
func _eristys() -> void:
	if main.wife != null and is_instance_valid(main.wife):
		if main.wife.spotted.is_connected(main._on_wife_spotted):
			main.wife.spotted.disconnect(main._on_wife_spotted)
		if main.wife.caught.is_connected(main._on_wife_caught):
			main.wife.caught.disconnect(main._on_wife_caught)
	if main.state == "ulkona":
		main.clock_min = 18.0 * 60.0


func _frames(n := 4) -> void:
	for i in n:
		_eristys()
		await get_tree().process_frame


func _snap(suffix: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(_shot_path(suffix))
	print("KESA kuva " + _shot_path(suffix))


## E-painallus syötetapahtumana: Input käsittelee sen seuraavan ruudun alussa, joten main.gd näkee just_pressed-tilan
## riippumatta siitä, ajetaanko testisolmu ennen vai jälkeen mainin (action_press testin ruudussa jäi mainilta näkemättä).
func _press() -> void:
	var e := InputEventAction.new()
	e.action = "interact"
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame
	var r := InputEventAction.new()
	r.action = "interact"
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame


func _ids(o: Array) -> Array:
	return o.map(func(x: Dictionary) -> String: return x.id)


func _paivi() -> Object:
	return main.rikos_osa("paivi")


## Sytkäri kiinni E:llä (mätsi 2,8 s, matka 0,8 s pelin aikaa).
func _close_phone() -> void:
	for i in 600:
		var ui = main._kolmio_ui
		if ui == null:
			return
		if "_t" in ui and ui._t > (3.0 if ui.mode == "match" else 1.0):
			await _press()
		else:
			await _frames(1)
	_vika("Sytkäri ei sulkeutunut")


## Kohtausta eteenpäin E:llä; kuva rivillä shot_at.
func _advance_ui(shot_at := -1, suffix := "") -> void:
	for i in 30:
		if main._kolmio_ui == null:
			return
		print("KESA kohtaus %s rivi %d/%d" % [main._kolmio_ui.mode, main._kolmio_ui._line, main._kolmio_ui.lines.size()])
		await _frames(30)
		if i == shot_at:
			await _snap(suffix)
		await _press()


func _to_door() -> void:
	var w: Node3D = main.walker_out
	var hf: Vector2 = M.HOME_YAW_DIR.normalized()
	w.global_position = main.home_door + Vector3(hf.x, 0, hf.y) * 0.6 + Vector3(0, 0.3, 0)
	w.look_at(Vector3(main.home_door.x, w.global_position.y, main.home_door.z) - Vector3(hf.x, 0, hf.y), Vector3.UP)
	w.velocity = Vector3.ZERO
	await _frames(12)


func run() -> void:
	_eristys()
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("kulissit")
	main.endings.counts.erase("avoin_pelikortti")
	main.endings.counts.erase("kesaheila")
	for k in ["kesaheila_matsi", "kesaheila_valinta"]:
		main.tilat.firsts.erase(k)
	if main.player != main.walker_out:
		main._toggle_mount()
	main._msg.text = ""
	main._note.visible = false
	var p := _paivi()
	if p == null:
		_vika("rikos/paivi.gd puuttuu")
		return
	p.epaluulo = 40.0
	p.yli60 = false
	p.vastahyokkays = false
	p.poissa_asti = -1
	p.liput.clear()
	await _frames(10)
	await _matsi(p)
	await _mittaus()
	await _ovi()
	await _suuttua(p)
	await _tallennus(p)
	await _tunnustaa(p)
	await _nauraa(p)
	Settings.set_v("k18_pois", false)
	print("KESA valmis, %d vikaa" % vikoja)


## Mätsi vain, kun huipennus on auki ja K-18 sallittu; Sytkärin ilmoitus kerran.
func _matsi(p: Object) -> void:
	var joni: Node3D = main._kolmio_joni
	main._talk_who = "kolmio_saloinen"
	var o: Array = main._talk_options("kolmio_saloinen")
	print("KESA ennen huipennusta valinnat %s" % [_ids(o)])
	if "kolmio_kesaheila" in _ids(o):
		_vika("kesäheilan mätsi ennen huipennusta")
	p.lisaa(25.0, "testi")  # 65: yli 60 -> huipennus auki
	Settings.set_v("k18_pois", true)
	o = main._talk_options("kolmio_saloinen")
	print("KESA K-18 pois: auki %s, valinnat %s" % [main._kesaheila_auki(), _ids(o)])
	if main._kesaheila_auki() or "kolmio_kesaheila" in _ids(o):
		_vika("kesäheila näkyy K-18 pois")
	Settings.set_v("k18_pois", false)
	main._talk_who = ""
	main._kesaheila_notice()
	var viesti: bool = p.liput.get("kesaheila_viesti", false)
	print("KESA ilmoitus %s, jono %s" % [viesti, main._msg_queue.slice(-1) if "_msg_queue" in main else "-"])
	if not viesti:
		_vika("Sytkärin ilmoitus ei tullut")
	var w: Node3D = main.walker_out
	w.global_position = joni.global_position + joni.global_transform.basis.z * -1.5 + Vector3(0, 0.3, 0)
	await _frames(10)
	main._talk_open("kolmio_saloinen", joni)
	await _frames(5)
	o = main._talk_options()
	print("KESA Joni ja Esa: %s" % [o.map(func(x: Dictionary) -> String: return "%s(%s)" % [x.id, x.enabled])])
	if not "kolmio_kesaheila" in _ids(o):
		_vika("Jonilla ja Esalla ei kesäheilan mätsiä")
	main._talk_choose("kolmio_kesaheila")
	await _frames(150)
	await _snap("_matsi")
	print("KESA vaihe koti %s, saloinen %s, kohde %s, ensikerta %s" % [main.kolmio.stage("koti"), main.kolmio.stage("saloinen"),
		main._kolmio_sal_site(), "kesaheila_matsi" in main.tilat.firsts])
	if main.kolmio.stage("koti") != "mittaus" or not "kesaheila_matsi" in main.tilat.firsts:
		_vika("kesäheilan mittaus ei alkanut")
	await _close_phone()


## Kolme mittausta: Jonin kaupalta, Esan kirkolta ja pelaajan kodin läheltä. Leikkausalueen keskipiste kodin ovesta.
func _mittaus() -> void:
	var w: Node3D = main.walker_out
	main._wife_rhythm(main.clock_min)
	print("KESA Päivin auto mittauksessa: vaihe %s, pysäköity %s, näkyy %s" % [main._wife_phase, main.wife.parked, main.wife.visible])
	if main._wife_phase != "koti" or not main.wife.parked:
		_vika("Päivin auto ei ole kotona mittauksen aikana")
	main.kolmio.st("koti").remote_t = 0.05
	await _frames(20)
	var t: Vector2 = main._kolmio_target("koti")
	var home := Vector2(main.home_door.x, main.home_door.z)
	var me := t + Vector2(-70, 55)
	w.global_position = Vector3(me.x, Terrain.h(me.x, me.y) + 0.4, me.y)
	await _frames(10)
	print("KESA mittausvihje '%s'" % main._hint.text)
	main._kolmio_measure("koti", me)
	await _frames(40)
	await _close_phone()
	var rings: Array = main.kolmio.st("koti").rings
	for r: Dictionary in rings:
		print("KESA ympyrä %s: keskus %s, %.0f m (%.0f..%.0f), kotiin %.0f m" % [r.who, r.c, r.m, r.lo, r.hi, (r.c as Vector2).distance_to(home)])
	if rings.size() != 3:
		_vika("ympyröitä %d (pitäisi 3)" % rings.size())
	# Leikkausalue 1 m:n ruudukolla kodin ympäriltä (±200 m).
	var sum := Vector2.ZERO
	var n := 0
	for ix in range(-200, 201):
		for iz in range(-200, 201):
			var q := home + Vector2(ix, iz)
			if main.kolmio.inside("koti", q):
				sum += q
				n += 1
	var c := sum / maxf(1.0, n)
	var hb: Vector2 = M.w2(M.HOME_BUILDING)
	print("KESA leikkausalue %d m2, keskipiste %s: ovesta %.1f m, talon keskeltä %.1f m" % [n, c, c.distance_to(home), c.distance_to(hb)])
	# Kolmen renkaan leikkaus on kaari (lähimmän ympyrän nauha), joten sen keskipiste ei osu kotiin. Ehto: oma ovi on
	# leikkausalueen sisällä, eli kolmiomittaus johtaa omalle ovelle kuten Mintun ja Katjan mittauksessa.
	var ovi_sisalla: bool = main.kolmio.inside("koti", home)
	print("KESA oma ovi leikkausalueella: %s" % ovi_sisalla)
	if n == 0 or not ovi_sisalla:
		_vika("oma ovi ei ole leikkausalueella (alue %d m2)" % n)
	main._paper.toggle()
	await _frames(10)
	main._paper._vcenter = t
	main._paper._vzoom = 0.9
	await _snap("_kartta")
	main._paper.toggle()
	await _frames(5)


## Etuovi: koputusvihje, E ei vie sisään vaan ovikohtaukseen, jonka jälkeen Päivin valinta (3 valintaa, ei Lopeta).
func _ovi() -> void:
	await _to_door()
	print("KESA ovella vihje '%s', tila %s" % [main._hint.text, main.state])
	if not "Koputa" in main._hint.text:
		_vika("kodin ovella ei koputusvihjettä: '%s'" % main._hint.text)
	await _snap("_ovi_vihje")
	await _press()
	await _frames(5)
	print("KESA E:n jälkeen tila %s, kohtaus %s, talk %s, vihje '%s'" % [main.state, main._kolmio_ui, main._talk_box.is_open(), main._hint.text])
	if main.state == "in_home":
		_vika("kodin ovi vei sisään ennen koputusta")
	if main._kolmio_ui == null or main._kolmio_ui.site != "koti":
		_vika("ovikohtaus ei alkanut")
		return
	await _advance_ui(5, "_ovi")
	await _frames(10)
	var o: Array = main._talk_options()
	print("KESA valinta auki %s, puhuja %s, valinnat %s" % [main._talk_box.is_open(), main._talk_who, _ids(o)])
	if not main._talk_box.is_open() or _ids(o) != ["paivi_kesa_nauraa", "paivi_kesa_tunnustaa", "paivi_kesa_suuttua"]:
		_vika("Päivin valinta ei auennut kolmella valinnalla")
	await _snap("_valinta")


## Suuttua: Päivi äidille 7 päivää, auto pois, jääkaappi tyhjä, aamulla ei lappua eikä listaa. Paluu kukilla.
func _suuttua(p: Object) -> void:
	var day0: int = main.day
	main._talk_choose("paivi_kesa_suuttua")
	await _frames(10)
	await _snap("_suuttua")
	print("KESA suuttua: poissa %s asti %d (päivä %d), auto %s/%s, vaihe koti %s, valinta-ensikerta %s" % [p.poissa(), p.poissa_asti,
		main.day, main._wife_phase, main.wife.visible, main.kolmio.stage("koti"), "kesaheila_valinta" in main.tilat.firsts])
	if not p.poissa() or p.poissa_asti != day0 + 1 + main.KESA_POISSA or main.wife.visible:
		_vika("suuttua: Päivi ei lähtenyt viikoksi")
	if main.kolmio.stage("koti") != "valmis":
		_vika("kesäheilan mittaus ei päättynyt")
	main._talk_box.close()
	await _frames(5)
	main._on_home_acted("jaakaappi")
	print("KESA jääkaappi: '%s'" % main._msg.text)
	if not "tyhjä" in main._msg.text:
		_vika("jääkaappi ei ole tyhjä Päivin ollessa poissa")
	main._new_day(main.home_zone + Vector3(0, 0, 4), false)
	await _frames(30)
	print("KESA aamu poissa: lappu näkyy %s, lista %s, viesti '%s'" % [main._note.visible, main.shopping_list, main._msg.text])
	if main._note.visible or not main.shopping_list.is_empty():
		_vika("Päivin lappu tai lista Päivin ollessa poissa")
	await _snap("_suuttua_aamu")
	await _frames(5)
	# Kukat ovella: Päivi tulee kotiin ja valinta aukeaa uudestaan.
	main.has_flowers = true
	main._talk_end_frame = -1
	await _to_door()
	print("KESA kukat ovella vihje '%s'" % main._hint.text)
	if not "kukat" in main._hint.text:
		_vika("kukilla ei voi hakea Päiviä: '%s'" % main._hint.text)
	await _press()
	await _frames(10)
	main._wife_rhythm(main.clock_min)
	var o: Array = main._talk_options()
	print("KESA kukkien jälkeen: poissa %s, paluu %s, auto %s, valinnat %s" % [p.poissa(), p.liput.get("kesaheila_paluu", false),
		main.wife.visible, _ids(o)])
	if p.poissa() or not main.wife.visible or not "paivi_kesa_nauraa" in _ids(o):
		_vika("Päivi ei palannut kukilla")
	await _snap("_kukat_valinta")
	main._talk_box.close()  # suljettu ilman valintaa: paluu odottaa etuovella
	await _frames(5)


## Tallennus edestakaisin: Päivin paluu, kesäheilan vaihe ja epäluulo säilyvät.
func _tallennus(p: Object) -> void:
	var e0: float = p.epaluulo
	main._save_game()
	p.liput.clear()
	p.epaluulo = 0.0
	main.kolmio = Kolmio.new()
	main._load_game()
	await _frames(10)
	p = _paivi()
	print("KESA tallennus: paluu %s, epäluulo %.0f -> %.0f, koti %s, poissa_asti %d" % [p.liput.get("kesaheila_paluu", false), e0,
		p.epaluulo, main.kolmio.stage("koti"), p.poissa_asti])
	if not p.liput.get("kesaheila_paluu", false) or absf(p.epaluulo - e0) > 0.01 or main.kolmio.stage("koti") != "valmis":
		_vika("tallennus ei säilyttänyt kesäheilan tilaa")


## Tunnustaa: Avoin pelikortti, kesäheilan hetki, syntilistat pelaajan teoista.
func _tunnustaa(p: Object) -> void:
	main.tilat.first("drakkar", 0.0)
	main.tilat.first("korkki", 0.0)
	await _to_door()
	print("KESA paluun vihje '%s'" % main._hint.text)
	await _press()
	await _frames(10)
	if not main._talk_box.is_open():
		_vika("paluun valinta ei auennut etuovella")
		return
	main._talk_choose("paivi_kesa_tunnustaa")
	await _frames(10)
	await _snap("_tunnustaa")
	var synnit: Array = main._kesaheila_synnit()
	print("KESA tunnustus: synnit %s, epäluulo %.0f, loput %s" % [synnit, p.epaluulo, main.endings.counts])
	if not main.endings.counts.has("avoin_pelikortti") or not main.endings.counts.has("kesaheila"):
		_vika("Avoin pelikortti tai kesäheilan hetki puuttuu")
	if not "ostin Drakkar Noirin Railin kirppispöydältä" in synnit or not "keräsin korkkikansion" in synnit:
		_vika("syntilista ei perustu pelaajan tekoihin")
	if not "kesaheila_valinta" in main.tilat.firsts or p.liput.get("kesaheila_paluu", false):
		_vika("valinnan ensikerta puuttuu tai paluu jäi päälle")
	main._talk_box.close()
	await _frames(5)


## Nauraa (viikon paluun kautta): paluuaamun lappu, valinta ovella, epäluulo 0, Kulissit kunnossa ja aamu keittiössä.
func _nauraa(p: Object) -> void:
	p.epaluulo = 70.0
	p.poissa_asti = main.day + 1  # viimeinen poissaolopäivä: huomenna Päivi palaa
	main._new_day(main.home_zone + Vector3(0, 0, 4), false)
	await _frames(30)
	for i in 20:  # välianimaatio (esim. Päivi löysi jemman) näyttää lapun vasta lopuksi
		if main._note.visible or main.state == "ulkona" and not main.cutscene.busy:
			break
		await _frames(15)
	print("KESA paluuaamu: poissa %s, paluu %s, lappu %s, tila %s, jemma_found %s" % [p.poissa(), p.liput.get("kesaheila_paluu", false),
		main._note.visible, main.state, main._jemma_found])
	if p.poissa() or not p.liput.get("kesaheila_paluu", false) or not main._note.visible:
		_vika("viikon paluu ei toiminut")
	await _snap("_paluu_aamu")
	main._note.visible = false
	await _to_door()
	await _press()
	await _frames(10)
	if not main._talk_box.is_open():
		_vika("paluun valinta ei auennut")
		return
	var day0: int = main.day
	main._talk_choose("paivi_kesa_nauraa")
	await _frames(10)
	await _snap("_nauraa")
	print("KESA nauraa: epäluulo %.0f" % p.epaluulo)
	if p.epaluulo != 0.0:
		_vika("nauraa ei nollannut epäluuloa")
	main._talk_choose("paivi_kesa_jatka")
	await _frames(10)
	if main._kolmio_ui == null or main._kolmio_ui.mode != "aamu":
		_vika("aamukohtaus ei alkanut")
		return
	await _advance_ui(2, "_aamu")
	await _frames(30)
	print("KESA aamun jälkeen päivä %d -> %d, loput %s, tila %s" % [day0, main.day, main.endings.counts, main.state])
	if main.day != day0 + 1 or not main.endings.counts.has("kulissit") or int(main.endings.counts.get("kesaheila", 0)) != 2:
		_vika("Kulissit kunnossa tai kesäheilan hetki ei kirjautunut")
	await _snap("_aamu_jalkeen")
	main._save_game()
	p.epaluulo = 50.0
	main._load_game()
	await _frames(5)
	print("KESA lopun tallennus: epäluulo %.0f, kulissit %s" % [_paivi().epaluulo, main.endings.counts.has("kulissit")])
	if _paivi().epaluulo != 0.0:
		_vika("nollattu epäluulo ei säilynyt tallennuksessa")
