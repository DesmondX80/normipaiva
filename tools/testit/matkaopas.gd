extends Node
## Matkaopas (B, scripts/matkaopas.gd): kaikki tilat kuvina ja mittauksina. main.gd palauttaa tallennuksen.
## Ajo: tools/testit/aja.sh scene matkaopas
## 1 ei opasta (B ei avaa, taksivalikossa valinta), 2 saaminen (kerran, tallentuu), 3 tyhjä opas (nimi, hinta ja kesto
## näkyvät, kuvaus ???), 4 osa kuultu (legenda + yksi käynti), 5 kaikki käyty (hinnat = taksivalikko, 15 leimaa, tallentuu),
## 6 uusi rekisteririvi ilman opas/kuultu, 7 Esc ja muut näkymät (päiväkirja O, kartta M), 8 vertailukuva ja rajaus.

const Retket := preload("res://scripts/retket.gd")
const Matkaopas := preload("res://scripts/matkaopas.gd")
const DayStats := preload("res://scripts/day_stats.gd")

var main: Node3D
var vikoja := 0


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + t)


func _shot_path(suffix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			return a.substr(7).replace(".png", suffix + ".png")
	return "user://matkaopas" + suffix + ".png"


func _frames(n := 4) -> void:
	for i in n:
		await get_tree().process_frame


func _snap(suffix: String) -> Image:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path(suffix))
	return img


func _press(action: String) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _esc() -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_ESCAPE
	e.keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(3)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(2)


func _reload_firsts() -> Array:
	main._save_game()
	var cfg := ConfigFile.new()
	cfg.load(main.SAVE_PATH)
	var ds := DayStats.new()
	ds.load_from(cfg)
	return ds.firsts


func _flag() -> Callable:
	return func(f: String) -> bool: return main.quest_flag(f)


func _spreads(prefix: String, which: Array) -> Dictionary:
	var out := {}
	var mo: Control = main._matkaopas
	for s in which:
		mo._spread = s
		mo.queue_redraw()
		out[s] = await _snap("_%s_%d" % [prefix, s])
	return out


func run() -> void:
	await _frames(10)
	var mo: Control = main._matkaopas
	var firsts: Array = main.tilat.firsts
	if main.player == main.bike:
		main.bike.speed = 0.0
		main._toggle_mount()
	main.money = 80.0
	main.clock_min = 12 * 60.0
	# Puhdas lähtö: ei opasta, ei käyntejä, ei legendoja.
	for f in firsts.duplicate():
		if f == "matkaopas" or String(f).begins_with("retki_") or String(f).ends_with("_legenda"):
			firsts.erase(f)
	for k in ["hanhikivi", "pakkahuone", "peruskivi", "manamansalo"]:
		main.get(k).heard = false

	# 1. Ei opasta: B ei avaa, taksivalikossa valinta.
	await _press("guide")
	print("MO 1 ei opasta: B avasi %s, tauko %s" % [mo.visible, get_tree().paused])
	if mo.visible:
		_vika("1: opas aukesi ilman opasta")
		mo.toggle()
	var opts: Array = main._talk_options("taksi")
	var has_opt := opts.any(func(o): return o.id == "matkaopas")
	print("MO 1 taksivalikossa matkaopas-valinta: %s" % has_opt)
	if not has_opt:
		_vika("1: taksivalikossa ei matkaopas-valintaa")
	main._talk_open("taksi", null, "Kyytiä?")
	var img_ei: Image = await _snap("_ei_opasta")

	# 2. Saaminen: valinta -> first, valinta katoaa, tallentuu.
	main._talk_choose("matkaopas")
	await _frames(3)
	await _snap("_saatu")
	main._talk_box.close()
	var gone: bool = not main._talk_options("taksi").any(func(o): return o.id == "matkaopas")
	var saved_ok := "matkaopas" in _reload_firsts()
	var inv: bool = main.inventory_items().any(func(it): return it.icon == "matkaopas")
	print("MO 2 saatu %s, valinta pois %s, tallennuksessa %s, repussa %s" % ["matkaopas" in firsts, gone, saved_ok, inv])
	if not ("matkaopas" in firsts and gone and saved_ok and inv):
		_vika("2: opas ei tallentunut tai valinta jäi")
	await _frames(3)

	# 3. Tyhjä opas: nimi, hinta ja kesto heti, kuvaus ja leima eivät.
	await _press("guide")
	print("MO 3 B avasi %s, tauko %s" % [mo.visible, get_tree().paused])
	if not mo.visible or not get_tree().paused:
		_vika("3: B ei avannut opasta tai peli ei pysähtynyt")
		mo.toggle()
	var pages: Array = mo._pages
	var known := pages.filter(func(p): return p.tiedossa).size()
	var stamps := pages.filter(func(p): return p.kayty).size()
	print("MO 3 tyhjä: sivuja %d, kuvaus tiedossa %d, leimoja %d" % [pages.size(), known, stamps])
	if pages.size() != Retket.LISTA.size() or known != 0 or stamps != 0:
		_vika("3: tyhjässä oppaassa kuvaus tai leima")
	var tyhja: Dictionary = await _spreads("tyhja", [0, 1])

	# 4. Osa kuultu: Hanhikiven legenda ja käynti kalalammella -> 2 kuvausta, 1 leima.
	firsts.append("hanhikivi_legenda")
	firsts.append("retki_lampi")
	mo.refresh()
	pages = mo._pages
	known = pages.filter(func(p): return p.tiedossa).size()
	stamps = pages.filter(func(p): return p.kayty).size()
	print("MO 4 osa: kuvaus tiedossa %d (%s), leimoja %d" % [known, pages.filter(func(p): return p.tiedossa).map(func(p): return p.id), stamps])
	if known != 2 or stamps != 1:
		_vika("4: odotettiin 2 kuvausta ja 1 leima")
	var osa: Dictionary = await _spreads("osa", [0, 1])

	# 5. Kaikki käyty: sivu jokaisesta, hinta sama kuin taksivalikossa, 15 leimaa, tallentuu.
	for id in Retket.LISTA:
		if not ("retki_" + id) in firsts:
			firsts.append("retki_" + id)
	mo.refresh()
	pages = mo._pages
	opts = main._talk_options("taksi")
	var bad_price: Array = []
	for p in pages:
		var o: Array = opts.filter(func(x): return x.id == "retki_" + p.id)
		var price: String = "%s €" % main._eur(p.hinta)
		if Retket.LISTA[p.id].lahto == "taksi" and (o.is_empty() or not price in String(o[0].text) or not String(p.nimi) in String(o[0].text)):
			bad_price.append(p.id)
		if p.hop_min != Retket.LISTA[p.id].hop_min:
			bad_price.append(p.id + " kesto")
	stamps = pages.filter(func(p): return p.kayty).size()
	var loaded := Matkaopas.sivut(Retket.LISTA, _reload_firsts(), _flag())
	var loaded_stamps := loaded.filter(func(p): return p.kayty).size()
	print("MO 5 kaikki: sivuja %d / %d, leimoja %d, latauksen jälkeen %d, hinta/nimi eri kuin taksivalikossa %s" % [pages.size(),
		Retket.LISTA.size(), stamps, loaded_stamps, bad_price])
	if pages.size() != Retket.LISTA.size() or stamps != Retket.LISTA.size() or loaded_stamps != stamps or not bad_price.is_empty():
		_vika("5: sivut, leimat tai hinnat eivät täsmää")
	mo.overflow.clear()
	var all_spreads: Array = range(mo._last_spread() + 1)
	var kaikki: Dictionary = await _spreads("kaikki", all_spreads)
	print("MO 5 aukeamia %d, ylivuoto %s" % [all_spreads.size(), mo.overflow])
	if not mo.overflow.is_empty():
		_vika("5: teksti ei mahdu sivulle: %s" % [mo.overflow])

	# 6. K8: uusi rivi ilman opas/kuultu -> sivu tulee, kuvaus = sub, näkyy vasta käynnin jälkeen.
	var lista: Dictionary = Retket.LISTA.duplicate()
	lista["testi"] = {"nimi": "Testikohteeseen", "lahto": "taksi", "sub": "Testin alaotsikko.", "hop_min": 10.0, "hinta": 5.0}
	var t0: Array = Matkaopas.sivut(lista, [], _flag())
	var t1: Array = Matkaopas.sivut(lista, ["retki_testi"], _flag())
	print("MO 6 uusi rivi: sivuja %d, viimeinen %s, kuvaus '%s', tiedossa ennen %s, jälkeen %s" % [t0.size(), t0[-1].id, t0[-1].kuvaus,
		t0[-1].tiedossa, t1[-1].tiedossa])
	if t0.size() != lista.size() or t0[-1].id != "testi" or t0[-1].kuvaus != "Testin alaotsikko." or t0[-1].tiedossa or not t1[-1].tiedossa:
		_vika("6: uusi rekisteririvi ei tuonut oikeaa sivua")

	# 7. Esc sulkee oppaan eikä avaa taukovalikkoa; päiväkirja ja kartta toimivat, B ei avaa niiden päälle.
	await _esc()
	print("MO 7 esc: opas auki %s, valikko auki %s, tauko %s" % [mo.visible, main.menu.visible, get_tree().paused])
	if mo.visible or main.menu.visible or get_tree().paused:
		_vika("7: Esc ei sulkenut opasta siististi")
		if mo.visible:
			mo.toggle()
		if main.menu.visible:
			main.menu.close()
	await _frames(3)
	for pair in [["journal", main._journal], ["map", main._paper]]:
		await _press(pair[0])
		var open: bool = pair[1].visible
		await _press("guide")
		var over: bool = mo.visible
		await _press(pair[0])
		print("MO 7 %s: aukesi %s, B oppaan päälle %s, sulkeutui %s, tauko %s" % [pair[0], open, over, not pair[1].visible, get_tree().paused])
		if not open or over or pair[1].visible:
			_vika("7: %s ei toimi oppaan kanssa" % pair[0])
		if mo.visible:
			mo.toggle()
		if pair[1].visible:
			pair[1].toggle()
		await _frames(3)
	await _press("guide")
	var reopened: bool = mo.visible
	await _press("guide")
	print("MO 7 B uudelleen: aukesi %s, sulkeutui %s, tauko %s" % [reopened, not mo.visible, get_tree().paused])
	if not reopened or mo.visible or get_tree().paused:
		_vika("7: B ei avaa ja sulje uudelleen")

	# 8. Vertailukuva (ei opasta, tyhjä, osa, kaikki) 2 x 2 ja suurennettu rajaus sivusta ja leimasta.
	var cells: Array = [img_ei, tyhja[1], osa[0], kaikki[1]]
	var cw := 640
	var ch := 360
	var comp := Image.create(cw * 2, ch * 2, false, Image.FORMAT_RGBA8)
	for i in cells.size():
		var im: Image = (cells[i] as Image).duplicate()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
		comp.blit_rect(im, Rect2i(0, 0, cw, ch), Vector2i((i % 2) * cw, (i / 2) * ch))
	comp.save_png(_shot_path("_vertailu"))
	mo._spread = 0
	mo.toggle()
	await _frames(3)
	var pg: Rect2 = mo._page(true)
	var crop: Image = (kaikki[0] as Image).get_region(Rect2i(pg))
	crop.resize(int(pg.size.x * 1.6), int(pg.size.y * 1.6), Image.INTERPOLATE_BILINEAR)
	crop.save_png(_shot_path("_rajaus_sivu"))
	var st: Image = (kaikki[0] as Image).get_region(Rect2i(Vector2i(pg.end) - Vector2i(170, 170), Vector2i(170, 170)))
	st.resize(510, 510, Image.INTERPOLATE_BILINEAR)
	st.save_png(_shot_path("_rajaus_leima"))
	var toc: Image = (kaikki[0] as Image).get_region(Rect2i(mo._page(false)))
	toc.resize(int(pg.size.x * 1.6), int(pg.size.y * 1.6), Image.INTERPOLATE_BILINEAR)
	toc.save_png(_shot_path("_rajaus_sisallys"))
	mo.toggle()
	print("MO valmis, vikoja %d" % vikoja)
