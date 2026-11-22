extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "kauppa". Siirretty main.gd:n _maybe_screenshot-matchista: koodi on
## ennallaan, pelin jäsenet main.-etuliitteellä ja vakiot Main.-etuliitteellä. aja() palauttaa 0 = kohtaus ei ole tässä,
## 1 = ajettu (main ottaa lopuksi yhteisen kuvan ja sulkee pelin), 2 = ajettu ja kohtaus lopetti itse.
const Kuva := preload("res://tools/testit/kuva.gd")

const Main := preload("res://scripts/main.gd")
const ShopInterior := preload("res://scripts/shop_interior.gd")
const M := preload("res://scripts/map_data.gd")
const Reseptit := preload("res://scripts/reseptit.gd")
const Retket := preload("res://scripts/retket.gd")
const HomeInterior := preload("res://scripts/home_interior.gd")
const EBike := preload("res://scripts/ebike.gd")
const AuctionGame := preload("res://scripts/auction_game.gd")
const KirppisMyynti := preload("res://scripts/kirppis_myynti_game.gd")
const KirppisInterior := preload("res://scripts/kirppis_interior.gd")
const Looks := preload("res://scripts/looks.gd")
const Endings := preload("res://scripts/endings.gd")
const Quests := preload("res://scripts/quests.gd")
const PiirakkaGame := preload("res://scripts/piirakka_game.gd")

const KOHTAUKSET := ["shop", "shoptest", "apteekki", "kmarket_vaala", "kirppismyynti", "pekanlaatikko", "slabarit", "reippari", "k18", "kirppis", "tarinamyynti", "maksamatta", "kauppapalautus", "kauppaovi", "shopfront", "shopsigns", "kauppalista"]

var main: Main


func aja(scene: String, path: String, nohud: bool) -> int:
	match scene:
		"shop":
			main._enter_shop()
			main.interior.has_beer = true
			main.interior.walker.set_carrying(true)
			main.interior.walker.position = main.interior.QUEUE_FRONT + main.interior.QUEUE_STEP * 3
			main.interior._neighbor_t = 0.01
		"shoptest":
			main._toggle_mount()
			main.walker_out.global_position = main.shop_zone + Vector3(1.5, 0.5, 0)
			for i in 30:
				await main.get_tree().physics_frame
			print("SHOP hint=", main._hint.text)
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			await main.get_tree().process_frame
			print("SHOP state=", main.state)
		"apteekki":
			# Vaalan apteekki: ulkokuva, sisälle, tiski ja valikko; ostot ilman reseptiä ja reseptillä.
			main._start_mopo()
			var ak: Node3D = main.mopo_trip.vaala
			main.mopo_trip.mopo.position = ak.door_pos("apteekki") + Vector3(0, 0.6, 0)
			main.mopo_trip.mopo.speed = 0.0
			for i in 30:
				await main.get_tree().process_frame
			print("APTEEKKI ovi ", ak.door_pos("apteekki"), " vihje: ", main.mopo_trip.hint)
			var aocc := Camera3D.new()
			main.add_child(aocc)
			aocc.look_at_from_position(main.mopo_trip.to_global(ak.door_pos("apteekki") + Vector3(6, 3.0, 14)), main.mopo_trip.to_global(ak.door_pos("apteekki") + Vector3(0, 1.5, 0)))
			aocc.current = true
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_ulko.png"))
			main.reseptit = 0
			main.money = 100.0
			main.clock_min = 10.0 * 60.0
			main._enter_apteekki()
			for i in 40:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_sisalla.png"))
			main.apteekki_int.walker.position = main.apteekki_int.spots.tiski[0]
			for i in 20:
				await main.get_tree().process_frame
			print("APTEEKKI tila ", main.state, " paikka ", main.apteekki_int.spot, " vihje ", main.apteekki_int.hint)
			main._talk_open("apteekki", null, "Mitäs saisi olla?")
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_valikko.png"))
			print("APTEEKKI valinnat ", main._talk_box._options.map(func(o): return "%s [%s]" % [o.text, o.enabled]))
			var ak1 := main._on_apteekki("tramal")
			print("APTEEKKI tramal ilman reseptiä: ", ak1[0], " | ", ak1[1], " | rahaa ", main.money)
			var kipu0: float = main.tilat.value("kipu")
			var ak2 := main._on_apteekki("panadol")
			print("APTEEKKI panadol reppuun: ", ak2[1], " | kipu %.2f (ei muutu ostaessa), laake %s, rahaa %.2f" % [main.tilat.value("kipu"), main.laake, main.money])
			main.use_item("panadol")
			print("APTEEKKI panadol otettu: kipu %.2f -> %.2f, laake %s" % [kipu0, main.tilat.value("kipu"), main.laake])
			main.reseptit = 3
			var ak3 := main._on_apteekki("tramal")
			print("APTEEKKI tramal reseptillä: ", ak3[1], " | reseptit ", main.reseptit, ", rahaa %.2f, laake %s" % [main.money, main.laake])
			main._on_apteekki("opiaatti")
			main._on_apteekki("perv")
			main.use_item("opiaatti")
			print("APTEEKKI opiaatti: humala %.2f (pitää olla 1.00), laake %s" % [main.tilat.value("humala"), main.laake])
			main.clock_min = 10.0 * 60.0
			main.use_item("perv")
			main._stat_effects()
			print("APTEEKKI perv: jalan x%.2f, mopo x%.2f, päättyy %.0f (nyt %.0f)" % [main.walker_out.speed_mult, main.mopo_trip.mopo.boost, main.perv_until, main.day * 1440.0 + main.clock_min])
			main.clock_min += Main.PERV_MIN + 1.0
			main._stat_effects()
			print("APTEEKKI perv loppui: jalan x%.2f, mopo x%.2f" % [main.walker_out.speed_mult, main.mopo_trip.mopo.boost])
			main.reseptit = 1
			main.asema_katkot["vaala"] = 1
			main._take_cache("vaala")
			print("APTEEKKI kätkön jälkeen reseptit ", main.reseptit, ", viesti: ", main._msg.text)
			# Jatkaminen: oksikodoni + Burana, pervitiini + Panadol; teho puolittuu, annokset tuplaantuvat.
			main.laake = {"opiaatti": 1, "burana": 2, "perv": 1, "panadol": 2}
			main._jatka_laake("opiaatti")
			main._jatka_laake("perv")
			print("APTEEKKI jatkettu: ", main.laake)
			main._jatka_laake("opiaatti~1")
			print("APTEEKKI jatkettu uudestaan: ", main.laake)
			main.tilat.add("humala", -1.0)
			var hum0: float = main.tilat.value("humala")
			main._take_laake("opiaatti~2")
			print("APTEEKKI jatkettu opiaatti~2: humala %.2f -> %.2f (odotus +0.25)" % [hum0, main.tilat.value("humala")])
			main.clock_min = 10.0 * 60.0
			main.perv_until = -1.0
			main._take_laake("perv~1")
			print("APTEEKKI jatkettu perv~1: kerroin %.2f (odotus 1.25)" % main.perv_mult)
			print("APTEEKKI T-valikon jatkorivit: ", main._laake_keys().filter(func(k): return main.laake.get(k, 0) > 0))
			# Teinikauppa: jatkamaton ja kahdesti jatkettu myydään samaan hintaan, tappelun päätökset molempiin suuntiin.
			main.laake = {"opiaatti": 1, "opiaatti~2": 1, "perv~3": 1}
			main.money = 0.0
			main._talk_who = "mopopojat"
			print("APTEEKKI teinivalinnat ", main._talk_options("mopopojat").filter(func(o): return o.id.begins_with("myy_")).map(func(o): return o.text))
			main._teini_myy("opiaatti", 0.99)
			main._teini_myy("opiaatti~2", 0.99)
			print("APTEEKKI teinimyynti: rahaa %.2f (odotus 498.00), laake %s" % [main.money, main.laake])
			main._fight_prev = main._vaala_state
			main.laake = {"opiaatti": 2, "perv~3": 1}
			main.money = 120.0
			main.state = "fight"
			main._teini_fight_end(false, 0, 0)
			print("APTEEKKI teini ryösti: rahaa %.2f laake %s (odotus 0 ja tyhjä)" % [main.money, main.laake])
			main.laake = {"perv~3": 1}
			main.money = 50.0
			main.state = "fight"
			main._teini_fight_end(true, 0, 0)
			print("APTEEKKI teini hävisi: rahaa %.2f laake %s (odotus 50 ja perv~3)" % [main.money, main.laake])
			# Klaffipöytä ja reseptit: muotojen tunnistus, jatkeet (sokeri, turbohiiva), kuvat pöydästä ja reseptikirjasta.
			main.klaffipoyta = true
			main.craft_known = {}
			main.laake = {"opiaatti": 2, "perv": 2, "burana": 1, "panadol": 1, "panacod": 1}
			main.has_sugar = true
			main.has_turbo = true
			var gr := func(a: Array) -> Array:
				var c := ["", "", "", "", "", "", "", "", ""]
				for e in a:
					c[e[0]] = e[1]
				return c
			print("KLAFFI muodot: pysty %s | vaaka %s | vaaka peilattu %s | vino %s | vastavino %s | vääräkuvio %s | väärä jatke %s" % [
				Reseptit.find(gr.call([[1, "opiaatti"], [4, "burana"]]), 4).get("id"), Reseptit.find(gr.call([[3, "perv"], [4, "panadol"]]), 4).get("id"),
				Reseptit.find(gr.call([[5, "perv"], [4, "panadol"]]), 4).get("id"), Reseptit.find(gr.call([[0, "perv"], [4, "sokeri"]]), 4).get("id"),
				Reseptit.find(gr.call([[1, "turbohiiva"], [3, "opiaatti"]]), 4).get("id"), Reseptit.find(gr.call([[0, "opiaatti"], [1, "burana"]]), 4).get("id"),
				Reseptit.find(gr.call([[1, "opiaatti"], [4, "panadol"]]), 4).get("id")])
			main._craft_learn()
			print("KLAFFI opitut ", main.craft_known.keys(), " (odotus: kaikki neljä)")
			print("KLAFFI sokeri: ", main._jatka_laake("perv", "perv_sokeri"), " laake ", main.laake, " sokeri ", main.has_sugar)
			print("KLAFFI turbo: ", main._jatka_laake("opiaatti", "oksi_turbo"), " laake ", main.laake, " turbo ", main.has_turbo)
			print("KLAFFI liian monta jatkoa: '", main._jatka_laake("perv~3", "perv_sokeri"), "'")
			if main._talk_box.is_open():
				main._talk_box.close()
			if main._journal.visible:
				main._journal.toggle()
			main.laake["burana"] = 1
			main._start_klaffipoyta()
			for i in 10:
				await main.get_tree().process_frame
			main._klaffi_game.set("_cells", ["", "opiaatti", "", "", "burana", "", "", "", ""])
			main._klaffi_game.set("_held", "perv")
			main._klaffi_game.set("mouse_fixed", Vector2(900, 300))
			for i in 6:
				await main.get_tree().process_frame
			print("KLAFFI ruudukko ", main._klaffi_game.get("_cells"), " osuma ", main._klaffi_game.call("_match"))
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_klaffipoyta.png"))
			main._klaffi_game._close()
			for i in 4:
				await main.get_tree().process_frame
			main._journal.open_at("reppu")
			for i in 6:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_reppu.png"))
			main._journal.toggle()
			var kp: Node3D = ak.klaffi_prop
			var kd: Dictionary = ak.doors.filter(func(d): return d.id == "klaffipoyta")[0]
			var kcam := Camera3D.new()
			main.add_child(kcam)
			kcam.current = true
			kcam.look_at_from_position(ak.to_global(kd.pos + kd.out * 2.2 + Vector3(0.0, 1.6, 0.0)), ak.to_global(kp.position + Vector3(0, 0.6, 0)))
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_klaffi_prop.png"))
			main.klaffipoyta = false
			main._klaffi_sync()
			print("KLAFFI prop näkyy ennen poimintaa: ", kp.visible, " ovi ", kd.pos)
			main._klaffi_found()
			print("KLAFFI prop näkyy poimittuna: ", kp.visible)
			# Teinin kiinnijäämisriski: huonoinkaan ei ole varma (roll 0.95 < 0.9 ei, mutta 0.5 < 0.9 kyllä).
			print("KLAFFI riskit ", Main.TEINI_KIINNI, " (suurin < 1: ", Main.TEINI_KIINNI.max() < 1.0, ")")
			# Takaovi: kuva kiinni, koputus (luukku auki), valikko, ostot x10 ilman reseptiä.
			var tp: Vector3 = ak.door_pos("apteekki_taka")
			var tdir: Vector3 = ak.doors.filter(func(d): return d.id == "apteekki_taka")[0].out
			var tcam := Camera3D.new()
			main.add_child(tcam)
			tcam.current = true
			var tlook := func() -> void:
				tcam.look_at_from_position(ak.to_global(tp + tdir * 3.2 + Vector3(0.6, 2.0, 0)), ak.to_global(ak.apteekki_back.global_position - ak.global_position + Vector3(0, 1.5, 0)))
			main.state = main._vaala_state
			tlook.call()
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_taka_kiinni.png"))
			main.reseptit = 0
			main.money = 500.0
			main.laake.clear()
			main._apteekki_taka()
			tcam.look_at_from_position(ak.to_global(tp + tdir * 1.3 + Vector3(0, 1.8, 0)), ak.apteekki_back.global_position + Vector3(0, 1.6, 0))
			for i in 60:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_taka_auki.png"))
			print("APTEEKKI taka valinnat ", main._talk_box._options.map(func(o): return "%s [%s]" % [o.text, o.enabled]))
			var t1 := main._on_apteekki("opiaatti", true)
			var t2 := main._on_apteekki("perv", true)
			print("APTEEKKI taka ostot: ", t1[1], " | ", t2[1], " | laake ", main.laake, " (rahaa pitää olla %.2f)" % (500.0 - 249.0 - 199.0))
			print("APTEEKKI panacod ilman reseptiä: ", main._on_apteekki("panacod")[1])
			main.get_tree().quit()
		"kmarket_vaala":
			# Vaalan K-Market: parkkipaikka, taksitolppa ja mummot; taksivalikon hinnat, retki Manamansaloon ja paluu tolpalle.
			main._start_mopo()
			var vl: Node3D = main.mopo_trip.vaala
			for car in main.mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var shot := func(tag: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_%s.png" % tag))
			var look := func(from: Vector3, to: Vector3, tag: String) -> void:
				var rc := Camera3D.new()
				main.add_child(rc)
				rc.current = true
				rc.look_at_from_position(vl.to_global(from), vl.to_global(to), Vector3.UP)
				for i in 8:
					await main.get_tree().process_frame
				await shot.call(tag)
				rc.queue_free()
			var tp: Vector3 = vl.vtaxi_pos
			var mp3: Vector3 = vl.mummot.position
			var kc: Vector3 = vl.kmarket_center
			kc.y = vl.h(kc.x, kc.z)  # kmarket_center on maan tasossa (y = 0), maasto on korkeammalla
			await look.call(kc + vl.kmarket_face * 22.0 + Vector3(0, 30, 0), kc + vl.kmarket_face * 8.0, "ylha")
			await look.call(mp3 + vl.kmarket_face * 6.0 + Vector3(2, 2.2, 0), mp3 + Vector3(0, 0.9, 0), "mummot")
			await look.call(tp + vl.kmarket_face * 7.0 + Vector3(0, 3.0, 0), tp - vl.kmarket_face * 2.0 + Vector3(0, 0.8, 0), "taksi")
			if main.mopo_trip.on_foot == null:
				main._mopo_dismount()
			main.walker_out.global_position = vl.to_global(tp + Vector3(0, 0.6, 0))
			for i in 20:
				await main.get_tree().process_frame
			print("KMV vihje '%s'" % main.mopo_trip.hint)
			for o in main._talk_options("taksi"):
				print("KMV valinta %s | %s | käytössä %s" % [o.id, o.text, o.enabled])
			main.money = 500.0
			for rid in ["manamansalo", "pyhakoski", "kajaani", "kalajoki", "hanhikivi"]:
				print("KMV hinta Vaalasta %s: %s, Saloisista %s" % [rid, Retket.tarjous(rid, true), Retket.tarjous(rid, false)])
			var t0 := main.clock_min
			var from := main.walker_out.global_position
			main._taxi_retki("manamansalo")
			var k := 0
			while main.state != "in_retki" and k < 60:
				await main.get_tree().create_timer(1.0).timeout
				k += 1
			print("KMV retkellä: tila %s, rahat %.0f, kello +%.0f min" % [main.state, main.money, main.clock_min - t0])
			await shot.call("retki")
			main.retki_int.exited.emit()
			k = 0
			while main.state != "ulkona" and k < 60:
				await main.get_tree().create_timer(1.0).timeout
				k += 1
			print("KMV paluu: tila %s, etäisyys lähtöpaikasta %.1f m, kello +%.0f min, mopo parkissa %s, HUD %s" % [main.state, main.walker_out.global_position.distance_to(from), main.clock_min - t0, main.mopo_trip.on_foot != null, main._hud.visible])
			# Mummot suuttuvat mopon ohituksesta.
			main._mopo_remount()
			main.mopo_trip.mopo.global_position = vl.to_global(mp3 + vl.kmarket_face * 3.0 + Vector3(0, 0.5, 0))
			main.mopo_trip.mopo.speed = 9.0
			for i in 12:
				await main.get_tree().physics_frame
			print("KMV mummot suuttuneet: %s" % vl.mummot.is_angry())
			await main.get_tree().create_timer(3.0).timeout
			await shot.call("karkit")
			main.get_tree().quit()
		"kirppismyynti":
			# Oma kirppispöytä (#128): pöytäpaikan vuokraus Hilkalta, tinkiminen (hyväksy, vastatarjous, liian kova hinta),
			# kaljakauppa tiskin alta (Anna-Liisa vahtii ja jää kiinni), yhteenveto ja tulosten käyttö. Tallennus palautetaan.
			var saved_my := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap_my := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var wait := func(sec: float) -> void:
				await main.get_tree().create_timer(sec).timeout
			main._note.visible = false
			main.money = 20.0
			main.maine = 40.0
			main.day = 3
			main.clock_min = 12 * 60
			main._myynti_day = -1
			main._myynti_ban = -1
			main.bucket = {}
			main.food = {}
			main.beers = 0
			main.pontikka = 0
			main._enter_kirppis("kirppis")
			await wait.call(0.5)
			main.kirppis_int.walker.position = Vector3(-3.4, 0, 3.4)
			await wait.call(0.6)
			print("MY salin pöytä, vihje: '%s'" % main.kirppis_int.hint)
			await snap_my.call("_myynti_sali.png")
			print("MY hilkka ilman tavaraa: %s" % [main._talk_options("hilkka").filter(func(o): return o.id.begins_with("poyta")).map(func(o): return "%s:%s" % [o.id, o.enabled])])
			main.bucket = {"puolukka": 5, "mustikka": 3, "kantarelli": 2, "herkkutatti": 2}
			main.food = {"savukala": 3, "savuriista": 2}
			main.beers = 4
			main.pontikka = 1
			print("MY hilkka tavaralla: %s" % [main._talk_options("hilkka").filter(func(o): return o.id.begins_with("poyta")).map(func(o): return "%s:%s" % [o.id, o.enabled])])
			print("MY pöytään kelpaa: %s" % [main._myynti_stock()])
			main._talk_open("hilkka", null)
			main._talk_box._pages.clear()
			main._talk_choose("poyta_vuokraa")
			var mg: Node = main.kirppis_int.get_children().filter(func(c): return c is KirppisMyynti).front()
			print("MY peli auki: %s, rahaa %s (paikka maksettu %s)" % [mg != null, main._eur(main.money), main._myynti_day == main.day])
			await wait.call(1.6)
			var force := func(type: String, item: String, qty: int, fair: float, limit: float, offer: float) -> void:
				mg._b = {"type": type, "item": item, "qty": qty, "fair": fair, "limit": limit, "offer": offer,
					"patience": 3, "under": type == "nuori", "side": 1.0}
				mg._counter = maxf(offer + 0.5, snappedf(fair * 1.15, 0.5))
				mg._phase = "talk"
				mg._bx = 640.0
				mg._mood = 0
				mg._open_line()
			# 1. Mummo: liian kova vastatarjous ajaa ostajan pois.
			force.call("mummo", "puolukka", 2, 12.0, 12.0, 6.0)
			await wait.call(0.3)
			await snap_my.call("_myynti_ostaja.png")
			mg._counter = 20.0
			mg._counter_offer()
			await wait.call(0.3)
			await snap_my.call("_myynti_pihi.png")
			print("MY liian kova: pihi %d, vaihe %s, rivi '%s'" % [mg._greedy, mg._phase, mg._line])
			# 2. Mökkiläinen: hyväksytään tarjous.
			force.call("mokki", "savukala", 1, 7.0, 9.0, 5.0)
			var inc0: float = mg._income
			mg._accept(5.0)
			await wait.call(0.3)
			await snap_my.call("_myynti_kauppa.png")
			print("MY hyväksytty tarjous: tulot %s -> %s, savukalaa jäljellä %d" % [main._eur(inc0), main._eur(mg._income), mg._left["savukala"]])
			# 3. Mummo: vastatarjous hieman yli enimmäishinnan, ostaja korottaa tarjousta, toinen vastatarjous käy.
			force.call("mummo", "mustikka", 1, 7.0, 7.5, 3.5)
			mg._counter = 8.5
			mg._counter_offer()
			print("MY vastatarjous 8,5 (raja 7,5): vaihe %s, uusi tarjous %s, kärsivällisyys %d, rivi '%s'" % [mg._phase, main._eur(mg._b.offer), mg._b.patience, mg._line])
			mg._counter = 7.5
			mg._counter_offer()
			print("MY vastatarjous 7,5: vaihe %s, tulot %s" % [mg._phase, main._eur(mg._income)])
			# 4. Tiskin alta: Anna-Liisa katsoo, sitten kääntyy pois.
			force.call("nuori", "kalja", 1, 15.0, 18.0, 12.0)
			mg._watch_t = 1.0
			await wait.call(0.3)
			await snap_my.call("_myynti_tiskin_alta_vahti.png")
			print("MY vahti katsoo: %s" % mg._watching())
			mg._watch_t = 6.0
			await wait.call(0.3)
			await snap_my.call("_myynti_tiskin_alta_turvassa.png")
			print("MY vahti muualla: %s" % mg._watching())
			mg._accept(12.0)
			print("MY kaljakauppa turvassa: vaihe %s, kaljaa jäljellä %d, kiinni %s" % [mg._phase, mg._left["kalja"], mg._caught])
			# 5. Toinen kaljakauppa Anna-Liisan katsoessa: kiinni.
			force.call("nuori", "kalja", 1, 15.0, 18.0, 12.0)
			mg._watch_t = 1.0
			mg._accept(12.0)
			await wait.call(0.5)
			await snap_my.call("_myynti_kiinni.png")
			print("MY kiinni jäi: %s, vaihe %s, kaljaa jäljellä %d" % [mg._caught, mg._phase, mg._left["kalja"]])
			var m0 := main.maine
			await wait.call(3.6)
			print("MY kiinni jäämisen jälkeen: maine %.0f -> %.0f, kielto huomiseen %s, viesti '%s'" % [m0, main.maine, main._myynti_ban >= main.day, main._msg.text])
			print("MY reppu: puolukka %s mustikka %s kantarelli %s kala %s kalja %d pontikka %d, rahaa %s" % [main.bucket.get("puolukka", 0), main.bucket.get("mustikka", 0),
				main.bucket.get("kantarelli", 0), main.food.get("savukala", 0), main.beers, main.pontikka, main._eur(main.money)])
			# Yhteenvetokuva uudella pelillä.
			main._myynti_ban = -1
			main._myynti_day = -1
			main.money = 10.0
			main._oma_poyta()
			print("MY oma pöytä salista: vuokra maksettu %s, rahaa %s" % [main._myynti_day == main.day, main._eur(main.money)])
			mg = main.kirppis_int.get_children().filter(func(c): return c is KirppisMyynti).front()
			await wait.call(0.3)
			mg._sold = {"puolukka": 3, "savukala": 2, "kantarelli": 1}
			mg._income = 41.5
			mg._served = 6
			mg._good = 4
			mg._summary()
			await wait.call(0.3)
			await snap_my.call("_myynti_yhteenveto.png")
			print("MY yhteenveto: '%s' maine %+d" % [mg._title, mg._rep])
			mg._end()
			await wait.call(0.5)
			print("MY ulos pelistä: pelin lapsia %d, kävelijä aktiivinen %s" % [main.kirppis_int.get_children().filter(func(c): return c is KirppisMyynti).size(), main.kirppis_int.walker.controls_enabled])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_my)
		"slabarit":
			# Släbärit ja villasukat (Looks.feet): Railin vaatetangosta kirppikseltä, vaatekaapista jalkaan ja pois,
			# hiihtohaalarissa kuukengät ja kumisaappaat edelle, tallennus. Kuvat: släbärit tangon juurella ja pelaajan
			# jalat. Rivit SL OK / TESTI VIKA. Pelaajan tallennus palautetaan.
			var saved_sl := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap_sl := func(name: String) -> void:
				for i in 4:
					await main.get_tree().process_frame
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var wait := func(sec: float) -> void:
				await main.get_tree().create_timer(sec).timeout
			var check := func(ok: bool, what: String) -> void:
				print(("SL OK %s" if ok else "TESTI VIKA släbärit: %s") % what)
			var body := func() -> Node3D:
				var bs: Array = main.get_tree().root.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool:
					return n.has_meta("player_body") and n.is_visible_in_tree())
				return bs[0] if not bs.is_empty() else null
			main._note.visible = false
			main.money = 10.0
			main.day = 3
			main.clock_min = 12 * 60
			main.has_slabarit = false
			main._set_feet("")
			main._set_boots("")
			main._set_outfit("tuulipuku")
			# 1. Kirppis: släbärit tangon juurella, Raili myy.
			main._enter_kirppis("kirppis")
			await wait.call(0.6)
			check.call(main.kirppis_int.slabarit.visible, "släbärit näkyvissä tangon juurella")
			var cam_sl := Camera3D.new()
			cam_sl.fov = 40.0
			main.kirppis_int.add_child(cam_sl)
			var rack: Vector3 = main.kirppis_int.to_global(KirppisInterior.RACK_AT + Vector3(0.35, 0.0, 0.42))
			cam_sl.look_at_from_position(rack + Vector3(0.5, 0.75, 1.1), rack + Vector3(0, 0.05, 0))
			cam_sl.current = true
			await snap_sl.call("_kirppis.png")
			cam_sl.current = false
			cam_sl.queue_free()
			var ro: Array = main._talk_options("raili").map(func(o: Dictionary) -> String: return "%s:%s" % [o.id, o.enabled])
			check.call("osta_slabarit:true" in ro, "Railin valikossa släbärit %s" % [ro])
			main._talk_open("raili", null)
			main._talk_box._pages.clear()
			main._talk_choose("osta_slabarit")
			await wait.call(0.3)
			check.call(main.has_slabarit and not main.kirppis_int.slabarit.visible and is_equal_approx(main.money, 7.0),
				"ostettu: rahaa %s, tangolta pois" % main._eur(main.money))
			main._talk_box.close()
			main.kirppis_int.leave()
			await wait.call(0.8)
			# 2. Vaatekaappi: släbärit jalkaan.
			main._open_wardrobe(["tuulipuku", "farkut", "hattu", "slabarit"], "testi")
			var items: Array = main._item_menu._items.map(func(x: Array) -> String: return "%s:%s" % [x[0], x[1]])
			check.call("slabarit:Släbärit ja villasukat jalkaan" in items, "vaatekaapissa %s" % [items])
			main._item_menu.visible = false
			main._on_wardrobe("slabarit")
			await wait.call(0.4)
			var pb: Node3D = body.call()
			check.call(Looks.feet == "slabarit" and pb != null and pb.shoe_type == "slabari" and pb.body_mat.get_shader_parameter("sock_on"),
				"jalassa släbärit ja villasukat (%s)" % (pb.shoe_type if pb != null else "ei mallia"))
			if main.player == main.bike:
				main._toggle_mount()
			await wait.call(0.3)
			var cam_p := Camera3D.new()
			cam_p.fov = 35.0
			main.add_child(cam_p)
			var w: Node3D = main.walker_out
			var fwd := -w.global_basis.z
			cam_p.look_at_from_position(w.global_position + fwd * 1.3 + w.global_basis.x * 0.5 + Vector3(0, 0.55, 0), w.global_position + Vector3(0, 0.25, 0))
			cam_p.current = true
			await snap_sl.call("_pelaaja.png")
			cam_p.current = false
			main.player.activate_camera()
			# 3. Hiihtohaalarissa kuukengät, kumisaappaat edelle.
			main._set_outfit("hiihtohaalari")
			await wait.call(0.3)
			pb = body.call()
			check.call(pb.shoe_type == "kuukenka", "hiihtohaalarissa kuukengät (%s)" % pb.shoe_type)
			main._set_outfit("tuulipuku")
			main._set_boots("jalassa")
			await wait.call(0.3)
			pb = body.call()
			check.call(pb.shoe_type == "kumisaapas", "kumisaappaat släbärien edelle (%s)" % pb.shoe_type)
			main._set_boots("")
			main._on_wardrobe("slabarit")  # pois
			await wait.call(0.3)
			pb = body.call()
			check.call(Looks.feet == "" and pb.shoe_type == "lenkkari" and not pb.body_mat.get_shader_parameter("sock_on"), "omat kengät takaisin (%s)" % pb.shoe_type)
			main._set_boots("jalassa")
			main._on_wardrobe("slabarit")
			check.call(Looks.feet == "" and String(main._msg.text).contains("Kumisaappaat"), "saappaat jalassa: ensin pois '%s'" % main._msg.text)
			main._set_boots("")
			main._set_outfit("hiihtohaalari")
			main._on_wardrobe("slabarit")
			check.call(Looks.feet == "" and String(main._msg.text).contains("kuukengät"), "haalarissa ei släbäreitä '%s'" % main._msg.text)
			main._set_outfit("tuulipuku")
			# 4. Tallennus.
			main._on_wardrobe("slabarit")
			main._save_game()
			var cfg := ConfigFile.new()
			cfg.load(Main.SAVE_PATH)
			check.call(cfg.get_value("pelaaja", "slabarit", false) == true and cfg.get_value("pelaaja", "jalkineet", "") == "slabarit", "tallennus")
			main._set_feet("")
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_sl)
		"pekanlaatikko":
			# Pekan vintin romut (pekan_laatikko.gd): Pekka tarjoaa laatikon vasta oman kirppispöydän jälkeen, romut pöydälle,
			# keräilijä, Anna-Liisa ja mummo ostavat, Pekan osuus, saman päivän tilitys (maine, ilmainen kyyti), myöhästynyt
			# tilitys (kyyti kiinni ja vihainen tervehdys) ja tallennus. Kuvat: Pekan puhe, pöytä ja lähikuva romuista,
			# ostajat ja yhteenveto. Pelaajan tallennus palautetaan.
			var saved_pl := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			var snap_pl := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var crop_pl := func(name: String, r: Rect2i, zoom: int) -> void:
				await Kuva.piirto()
				var img := Kuva.ruutu(main.get_viewport())
				var k := Vector2(img.get_size()) / Vector2(1280, 720)  # pelin piirto on 1280 x 720 -koordinaateissa
				var rr := Rect2i(Vector2i(Vector2(r.position) * k), Vector2i(Vector2(r.size) * k))
				var part := img.get_region(rr)
				part.resize(rr.size.x * zoom, rr.size.y * zoom, Image.INTERPOLATE_LANCZOS)
				part.save_png(path.replace(".png", name))
			var wait := func(sec: float) -> void:
				await main.get_tree().create_timer(sec).timeout
			var check := func(ok: bool, what: String) -> void:
				print(("PL OK %s" if ok else "TESTI VIKA Pekan laatikko: %s") % what)
			var pekka_opts := func() -> Array:
				return main._talk_options("pekka").map(func(o: Dictionary) -> String: return "%s:%s" % [o.id, o.enabled])
			main._note.visible = false
			main.money = 20.0
			main.maine = 40.0
			main.day = 3
			main.clock_min = 12 * 60
			main._myynti_day = -1
			main._myynti_ban = -1
			main.bucket = {"puolukka": 2}
			main.food = {}
			main.beers = 0
			main.pontikka = 0
			main.story.step = "valmis"  # kyyti mökille auki: tilityksen vaikutus kyytiin näkyy
			main.laatikko = Main.PekanLaatikko.new()
			main.tilat.firsts.erase("oma_kirppispoyta")
			main.tilat.firsts.erase("pekan_laatikko_tilitetty")
			# 1. Ennen omaa pöytää Pekka ei tarjoa laatikkoa; jälkeen tarjoaa.
			var o1: Array = pekka_opts.call()
			check.call(not o1.any(func(x: String) -> bool: return x.begins_with("laatikko")), "ennen omaa pöytää ei laatikkoa %s" % [o1])
			main.tilat.first("oma_kirppispoyta", 0.0)
			var o2: Array = pekka_opts.call()
			check.call("laatikko:true" in o2, "oman pöydän jälkeen laatikko tarjolla %s" % [o2])
			main._talk_open("pekka", null)
			main._talk_choose("laatikko")
			await wait.call(0.4)
			await snap_pl.call("_pekka_laatikko.png")
			check.call(main.laatikko.given and main.laatikko.count() == 8, "laatikko annettu, 8 tavaraa (%d)" % main.laatikko.count())
			var inv: Array = main.inventory_items().filter(func(it: Dictionary) -> bool: return it.icon == "laatikko")
			check.call(inv.size() == 1 and inv[0].count == 8, "repussa Pekan romulaatikko")
			check.call(not "laatikko:true" in pekka_opts.call(), "laatikko annetaan vain kerran")
			main._talk_box.close()
			# 2. Kirppiksen oma pöytä: romut ja puolukat pöydälle.
			var st: Dictionary = main._myynti_stock()
			check.call(st.get("lp", 0) == 3 and st.get("taulu", 0) == 1 and st.get("puolukka", 0) == 2, "pöytään kelpaa %s" % [st])
			main._enter_kirppis("kirppis")
			await wait.call(0.5)
			main.kirppis_int.walker.position = Vector3(-3.4, 0, 3.4)
			await wait.call(0.4)
			main._oma_poyta()
			var mg: Node = main.kirppis_int.get_children().filter(func(c): return c is KirppisMyynti).front()
			check.call(mg != null, "myyntipeli auki")
			await wait.call(1.6)
			var force := func(type: String, item: String, qty: int, fair: float, limit: float, offer: float) -> void:
				mg._b = {"type": type, "item": item, "qty": qty, "fair": fair, "limit": limit, "offer": offer,
					"patience": 3, "under": false, "side": 1.0}
				mg._counter = maxf(offer + 0.5, snappedf(fair * 1.15, 0.5))
				mg._phase = "talk"
				mg._bx = 640.0
				mg._mood = 0
				mg._open_line()
			# 3. Keräilijä: vieherasia vastatarjouksella.
			force.call("keraaja", "vieherasia", 1, 15.0, 22.0, 10.5)
			await wait.call(0.3)
			await snap_pl.call("_keraaja.png")
			await crop_pl.call("_poyta_lahi.png", Rect2i(250, 330, 800, 175), 2)
			check.call(mg._line.contains("Vanhoja uistimia") and mg._line.contains("keräilijähinta"), "keräilijän repliikki '%s'" % mg._line)
			mg._counter = 18.0
			mg._counter_offer()
			check.call(int(mg._sold.get("vieherasia", 0)) == 1, "vieherasia myyty 18 €")
			# 4. Anna-Liisa tunnistaa Pekan taulun.
			force.call("annaliisa", "taulu", 1, 18.0, 17.0, 8.0)
			await wait.call(0.3)
			await snap_pl.call("_annaliisa_taulu.png")
			check.call(mg._line.contains("Pekan tavaraa"), "Anna-Liisan repliikki '%s'" % mg._line)
			mg._accept(8.0)
			# 5. Mummo: kaksi LP-levyä.
			force.call("mummo", "lp", 2, 10.0, 11.0, 5.0)
			check.call(mg._line.contains("iskelmälevyjä"), "mummon repliikki '%s'" % mg._line)
			mg._accept(10.0)
			check.call(is_equal_approx(mg.pekka_share(), 18.0), "Pekan osuus pöydällä 18 € (%s)" % main._eur(mg.pekka_share()))
			mg._summary()
			await wait.call(0.3)
			await snap_pl.call("_yhteenveto.png")
			var money_before: float = main.money
			mg._end()
			await wait.call(0.6)
			check.call(is_equal_approx(main.laatikko.owed, 18.0) and main.laatikko.owed_day == main.day, "Pekalle velkaa 18 € tältä päivältä")
			check.call(main.laatikko.left.get("lp", 0) == 1 and not main.laatikko.left.has("vieherasia") and not main.laatikko.left.has("taulu"),
				"laatikossa jäljellä %s" % [main.laatikko.left])
			check.call(is_equal_approx(main.money, money_before + 36.0), "rahaa +36 € (koko myynti, Pekan osuus tilitetään erikseen)")
			check.call(main._msg.text.contains("Pekan osuus %s €" % main._eur(18.0)), "viesti '%s'" % main._msg.text)
			# 6. Saman päivän tilitys: maine +2 ja seuraava kyyti ilmainen.
			var o3: Array = pekka_opts.call()
			check.call("laatikko_tilita:true" in o3, "tilitys tarjolla %s" % [o3])
			var m0: float = main.money
			var r0: float = main.maine
			main._talk_open("pekka", null)
			main._talk_choose("laatikko_tilita")
			await wait.call(0.4)
			await snap_pl.call("_tilitys.png")
			check.call(is_equal_approx(main.money, m0 - 18.0) and is_equal_approx(main.maine, r0 + 2.0) and main.laatikko.free_ride,
				"tilitys: rahaa -18, maine +2, ilmainen kyyti")
			var kyyti: Array = main._talk_options("pekka").filter(func(o: Dictionary) -> bool: return o.id == "kyyti")
			check.call(not kyyti.is_empty() and kyyti[0].enabled and String(kyyti[0].text).contains("Pekan piikkiin"),
				"kyyti ilmaiseksi '%s'" % (kyyti[0].text if not kyyti.is_empty() else ""))
			check.call("pekan_laatikko_tilitetty" in main.tilat.firsts, "sivutehtävä merkitty tehdyksi")
			main._talk_box.close()
			# 7. Myöhästynyt tilitys: seuraavana päivänä kyyti kiinni ja vihainen tervehdys, maksu avaa kyydin.
			main.laatikko.free_ride = false
			main.laatikko.record_sale({"lp": 1}, {"lp": 6.0}, main.day)
			main.day += 2  # päivä 5: päivänä 4 Pekan Volvo ei lähde (day % 6 == 4), joten kyyti olisi kiinni muutenkin
			kyyti = main._talk_options("pekka").filter(func(o: Dictionary) -> bool: return o.id == "kyyti")
			check.call(main.laatikko.angry(main.day) and not kyyti.is_empty() and not kyyti[0].enabled
				and String(kyyti[0].reason).contains("kirppisrahojaan"), "myöhässä: kyyti kiinni (%s)" % (kyyti[0].reason if not kyyti.is_empty() else ""))
			check.call(main._talk_hello("pekka").contains("puolikas"), "vihainen tervehdys '%s'" % main._talk_hello("pekka"))
			main._talk_open("pekka", null)
			main._talk_choose("laatikko_tilita")
			await wait.call(0.3)
			await snap_pl.call("_myohassa.png")
			kyyti = main._talk_options("pekka").filter(func(o: Dictionary) -> bool: return o.id == "kyyti")
			check.call(not main.laatikko.free_ride and main.laatikko.late_count == 1 and kyyti[0].enabled,
				"myöhästynyt tilitys: ei palkkiota, kyyti auki (%s, myöhässä %d, kyyti '%s')" % [main.laatikko.free_ride, main.laatikko.late_count, kyyti[0].reason])
			main._talk_box.close()
			# 8. Tallennus ja lataus.
			var cfg := ConfigFile.new()
			main.laatikko.save_to(cfg)
			var l2: RefCounted = Main.PekanLaatikko.new()
			l2.load_from(cfg)
			check.call(l2.given and l2.left == main.laatikko.left and is_equal_approx(l2.paid_total, 21.0) and l2.late_count == 1,
				"tallennus: annettu, jäljellä %s, tilitetty %s €" % [l2.left, main._eur(l2.paid_total)])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved_pl)
		"reippari":
			# Saloisten Reippari (#115): luukku kiinni ja auki, ostos reppuun, ilmoitustaulu (Miisu), iltaporukan juoru,
			# Miisu syliin ja Aarolle, lihapiirakkahaaste ennätyksineen (uusi loppu). Kuvat kioskista ja haasteesta.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.quests = Quests.new()
			main.endings = Endings.new()
			main._miisu = {"spot": -1, "state": ""}
			main._piirakka_record = 7
			main._piirakka_holder = "Juntti"
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			var frames := func(n: int) -> void:
				for i in n:
					await main.get_tree().physics_frame
			var snap := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			main.money = 40.0
			var win: Vector3 = main.world.reippari_window
			main.clock_min = 9 * 60
			main.walker_out.global_position = win + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("RE kiinni: '%s'" % main._hint.text)
			main.clock_min = 12 * 60
			print("RE valikko: %s" % [main._talk_options("reippari").map(func(o): return o.id)])
			main._talk_open("reippari", null)
			main._talk_box._pages.clear()
			main._talk_choose("grilli_makkaraperunat")
			main._talk_box.close()
			print("RE ostettu: %s, rahaa %s" % [main.food, main._eur(main.money)])
			main.walker_out.global_position = main.world.reippari_board + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("RE taulu: '%s'" % main._hint.text)
			await press.call("interact")
			print("RE miisu: %s, viesti '%s'" % [main._miisu, main._msg.text.left(70)])
			main.clock_min = 19 * 60
			await frames.call(5)
			print("RE porukka näkyy: %s" % main.world.reippari_youth.visible)
			for i in 12:
				main._talk_who = "reippari_nuoret"
				main._talk_chat_line()
			print("RE juorut: pontikka %s, tokola %s" % ["juoru_pontikka" in main.tilat.firsts, "juoru_tokola" in main.tilat.firsts])
			var oc := Camera3D.new()
			main.add_child(oc)
			var kc := M.w(M.REIPPARI)
			oc.look_at_from_position(win + (win - kc).normalized() * 10.0 + Vector3(4, 3.5, 0), kc + Vector3(0, 1.5, 0))
			oc.current = true
			await frames.call(30)
			await snap.call("_kioski.png")
			oc.current = false
			main.player.activate_camera()
			main.walker_out.global_position = main._miisu_node.global_position + Vector3(1.0, 0.3, 0)
			await frames.call(10)
			print("RE kissa: '%s'" % main._hint.text)
			await press.call("interact")
			print("RE aaro: %s" % [main._talk_options("aaro").map(func(o): return o.id)])
			main._talk_open("aaro", main.aaro)
			main._talk_box._pages.clear()
			main._talk_choose("miisu")
			main._talk_box.close()
			print("RE miisu kotona: %s, rahaa %s" % [main._miisu.state, main._eur(main.money)])
			main._talk_who = "reippari"
			main._talk_reippari("haaste")
			var g: Node = main.world.get_children().filter(func(c): return c is PiirakkaGame).front()
			print("RE haaste auki: %s" % [g != null])
			await main.get_tree().create_timer(5.5).timeout
			for k in 2:  # kaksi haukkua piirakasta
				g._slices[k].visible = false
			g._bitten[2].visible = true
			g._chew = 2
			g._bite = 2
			g._pies = 3
			g._belly = 0.55
			g._event("doubt")
			await main.get_tree().create_timer(0.3).timeout
			await snap.call("_haaste.png")
			g._soda_t = g.SODA_T * 0.5
			await main.get_tree().process_frame
			await snap.call("_limu.png")
			g._soda_t = 0.0
			g._belly = 0.9
			g._event("full")
			await main.get_tree().create_timer(0.4).timeout
			await snap.call("_taysi.png")
			print("RE puhujat: %s" % [g._bubbles.keys()])
			# Syömisen vaiheet: koko piirakka ja haukut 1–4 (kuten _process haukatessa).
			g._belly = 0.2
			g._chew = 0
			g._jaw = 0.0
			for b in g.BITES:
				for k in g.BITES:
					g._slices[k].visible = k >= b
					g._bitten[k].visible = k == b and b > 0
				g._bite = b
				await main.get_tree().create_timer(0.2).timeout
				await snap.call("_vaihe_%d.png" % b)
			g._pies = 8
			g._finish("testi")
			await main.get_tree().create_timer(2.5).timeout
			print("RE ennätys: %s %d, viesti '%s', loput %d/%d" % [main._piirakka_holder, main._piirakka_record, main._msg.text.left(60), main.endings.distinct(), Endings.max_count()])
			var d := main.journal_data()
			print("RE tehtävät: %s" % [d.side.map(func(q): return "%s%s" % [q.title, "✔" if q.done else ""])])
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"k18":
			# K-18-sisältö pois (asetus k18_pois): Pentti ei ole paikalla pe 20, kolmiomittauksen kaverit piilossa,
			# makasiinin koputus ei tarjoudu, päiväkirjasta pois tehtävät ja loput; asetus pois -> kaikki takaisin.
			var vanha: bool = Settings.values.get("k18_pois", false)
			main.day = 5  # perjantai (_weekday 4)
			main.clock_min = 20 * 60.0
			for k in ["rasvanappi", "pentti_tavattu", "kolmio_saloinen"]:
				main.tilat.first(k)
			var pentti: RefCounted = null
			for r in main.rikos:
				if r.has_method("paikalla"):
					pentti = r
			var tulos := func(tag: String) -> Array:
				main._kolmio_logic()
				var dk := main.journal_data()
				var ids: Array = dk.side.map(func(q): return q.id)
				print("K18 %s: Pentti paikalla %s, Joni näkyy %s, päiväkirjassa %s, loppuja max %d" % [tag,
					pentti.paikalla() if pentti != null else "-", main._kolmio_joni.visible if is_instance_valid(main._kolmio_joni) else "-",
					Main.K18_SIDE.filter(func(i): return i in ids), dk.loput.max])
				return [pentti.paikalla() if pentti != null else false, main._kolmio_joni.visible if is_instance_valid(main._kolmio_joni) else false,
					Main.K18_SIDE.filter(func(i): return i in ids).size(), dk.loput.max]
			Settings.values["k18_pois"] = false
			var sallittu: Array = tulos.call("sallittu")
			Settings.values["k18_pois"] = true
			var pois: Array = tulos.call("pois")
			if pois[0] or pois[1] or pois[2] > 0 or pois[3] >= sallittu[3]:
				print("TESTI VIKA K-18-sisältö näkyy, vaikka asetus on päällä")
			Settings.values["k18_pois"] = false
			var takaisin: Array = tulos.call("takaisin")
			if not takaisin[0] or not takaisin[1] or takaisin[2] < 3:
				print("TESTI VIKA K-18-sisältö ei palannut, kun asetus otettiin pois")
			Settings.values["k18_pois"] = vanha
			main.get_tree().quit()
		"kirppis":
			# Seuraintalo ja kirpputori (#114): ulkokuva, ovi kiinni ja auki, sisätila, Taunon tinkiminen ja osto,
			# huutokauppa (kuva ja pakotettu voitto: napamoottori sähköpyörään) ja sulkemisaika. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.ebike = EBike.new()
			if main.player == main.bike:
				main._toggle_mount()
			main._note.visible = false
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			var frames := func(n: int) -> void:
				for i in n:
					await main.get_tree().physics_frame
			var snap := func(name: String) -> void:
				await Kuva.piirto()
				Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", name))
			var door: Vector3 = main.world.kirppis_door
			print("KP ovi: %s (px %s)" % [door, M.to_px(door)])
			var oc := Camera3D.new()
			oc.far = 2000.0
			main.add_child(oc)
			var away := door + (door - M.w(M.SEURAINTALO)).normalized() * 22.0
			oc.look_at_from_position(Vector3(away.x, door.y + 6.0, away.z), M.w(M.SEURAINTALO) + Vector3(0, 2.0, 0))
			oc.current = true
			await frames.call(30)
			await snap.call("_ulko.png")
			oc.current = false
			main.player.activate_camera()
			main.clock_min = 8 * 60
			main.walker_out.global_position = door + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("KP kiinni: '%s'" % main._hint.text)
			main.clock_min = 12 * 60
			await frames.call(5)
			print("KP auki: '%s'" % main._hint.text)
			await press.call("interact")
			print("KP sisällä: tila %s" % main.state)
			await frames.call(20)
			await snap.call("_sisa.png")
			main.money = 30.0
			main.maine = 0.0
			main._talk_open("tauno", null)
			print("KP tauno: %s" % [main._talk_options().map(func(o): return o.id)])
			for i in 4:
				main._talk_box._pages.clear()
				var o: Array = main._talk_options().map(func(o): return o.id)
				if "tingi_ruuvipurkki" in o:
					main._talk_choose("tingi_ruuvipurkki")
					print("KP tingi: pyyntö %s €" % main._eur(main._kirppis_ask("ruuvipurkki")))
			main._talk_box._pages.clear()
			main._talk_choose("osta_ruuvipurkki")
			main._talk_box._pages.clear()
			main._talk_choose("osta_rautalanka")
			print("KP ostettu: tarvikkeet %s, rahaa %s" % [main.ebike.supplies, main._eur(main.money)])
			await frames.call(10)
			await snap.call("_tinki.png")
			main._talk_box.close()
			await frames.call(5)
			main._talk_open("huutaja", null)
			print("KP huutaja: %s" % [main._talk_options().map(func(o): return o.text)])
			main._talk_box._pages.clear()
			main._talk_choose("huuto")
			var g: Node = main.kirppis_int.get_children().filter(func(c): return c is AuctionGame).front()
			print("KP huutokauppa auki: %s" % [g != null])
			await main.get_tree().create_timer(2.5).timeout
			await snap.call("_huuto.png")
			g._gaze = 0
			g._gaze_t = 5.0
			g._bid(0)
			await main.get_tree().create_timer(0.3).timeout
			await snap.call("_huuto_mummo.png")
			g._gaze = 1
			g._gaze_t = 5.0
			await main.get_tree().create_timer(0.5).timeout
			await snap.call("_huuto_katsoo.png")
			g._player_bid()
			await main.get_tree().create_timer(0.3).timeout
			await snap.call("_huuto_oma.png")
			print("KP huuto salissa: johtaja %d, hinta %s, Erkin katse %.2f" % [g._leader, g._eur(g._price), g._erkki.rotation.y])
			g.rivals = [["Mummo Elvi", 6.0], ["Ukko Veikkonen", 7.0]]
			for i in 40:
				if g._leader != 1:
					g._gaze = 1
					g._player_bid()
				await main.get_tree().create_timer(0.3).timeout
				if not is_instance_valid(g):
					break
			await main.get_tree().create_timer(2.0).timeout
			print("KP huutokauppa: moottori %s, rahaa %s, viesti '%s', kävelijä näkyy %s, pöydän moottori näkyy %s" % [main.ebike.parts.has("moottori"), main._eur(main.money), main._msg.text, main.kirppis_int.walker.visible, main.kirppis_int._lot.visible])
			print("KP huutaja uudestaan: %s" % [main._talk_options("huutaja").map(func(o): return o.id)])
			main.clock_min = 18 * 60 + 1
			await frames.call(10)
			print("KP sulkeminen: tila %s" % main.state)
			FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
			main.get_tree().quit()
		"tarinamyynti":
			# Tarinan tehtävät useasta myynnistä: sienet Pekalle 2 + 1 l, puolukat Artolle 3 + 2 l.
			if main.player == main.bike:
				main._toggle_mount()
			main.story.step = "tehtavat"
			main.story.done = {"sienet": false, "puolukat": false, "nurmikko": true}
			main.story.given = {"sienet": 0, "puolukat": 0}
			main.world.forage_revealed = true
			main.pekka.process_mode = Node.PROCESS_MODE_DISABLED
			main.arto.process_mode = Node.PROCESS_MODE_DISABLED
			var sell := func(v: CharacterBody3D, goods: Dictionary) -> void:
				main.bucket = goods
				main.walker_out.global_position = v.global_position + Vector3(1.5, 0.5, 0)
				for i in 10:
					await main.get_tree().physics_frame
				await main.get_tree().process_frame
				print("TMYYNTI hint '%s' bucket %s" % [main._hint.text, main.bucket])
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
				for i in 3:
					await main.get_tree().process_frame
				print("TMYYNTI ikkuna %s: %s" % [main._talk_box.is_open(), main._talk_box._options.map(func(o): return o.text)])
				main._talk_choose("myy")
				print("TMYYNTI info '%s'" % main._talk_box._info)
				main._talk_box.close()
				for i in 2:
					await main.get_tree().process_frame
			await sell.call(main.pekka, {"kantarelli": 2})
			await sell.call(main.pekka, {"herkkutatti": 1})
			await sell.call(main.arto, {"puolukka": 3, "mustikka": 1})
			await sell.call(main.arto, {"puolukka": 2})
			print("TMYYNTI: annettu %s, tehty %s, vaihe %s, jono %s" % [main.story.given, main.story.done, main.story.step,
				str(main._msg_queue.map(func(m): return m[0])).left(260)])
		"maksamatta":
			# Maksamatta ulos: rahaa on, mutta lähdetään ovesta. Kauppias perään; tappiolla tavarat takaisin, voitolla jää.
			if main.player == main.bike:
				main._toggle_mount()
			for win in [false, true]:
				main.money = 50.0
				main.has_sausage = false
				main.paivi_bag.clear()
				main._enter_shop()
				for g in main.interior._queue:
					g.queue_free()
				main.interior._queue.clear()
				main.interior.cart["makkara"] = 3.5
				main.interior.bag["maito"] = "sininen"
				main.interior.walker.set_carrying(true)
				main.interior.walker.position = ShopInterior.DOOR
				for i in 5:
					await main.get_tree().physics_frame
				await main.get_tree().process_frame
				print("MAKSAMATTA ovella: hint '%s'" % main._hint.text)
				await main.get_tree().process_frame
				Input.action_press("interact")
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release("interact")
				for i in 5:
					await main.get_tree().process_frame
				print("MAKSAMATTA ulos: tila %s, makkara %s, Päivin kassi %s, rahaa %.2f, kauppias perässä %s, viesti '%s'" % [main.state,
					main.has_sausage, main.paivi_bag, main.money, is_instance_valid(main._shop_chaser), main._msg.text.replace("
", " | ")])
				main._kauppias_fight_end(win, "")
				print("MAKSAMATTA tappelu %s: makkara %s, Päivin kassi %s, viesti '%s'" % ["voitto" if win else "tappio", main.has_sausage,
					main.paivi_bag, main._msg.text])
				await main.get_tree().create_timer(3.5).timeout
				print("MAKSAMATTA poliisi %s: %s, viesti '%s'" % ["voiton jälkeen" if win else "tappion jälkeen",
					main.police != null and is_instance_valid(main.police), main._msg.text.replace("\n", " | ")])
		"kauppapalautus":
			# Rahat ei riitä: kalja ja makkara palautetaan hyllyyn, sitten kassalla Q jättää ostokset tiskille.
			if main.player == main.bike:
				main._toggle_mount()
			main.money = 3.0
			main._enter_shop()
			for g in main.interior._queue:
				g.queue_free()
			main.interior._queue.clear()
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			var go := func(at: Vector3) -> void:
				main.interior.walker.position = at
				for i in 5:
					await main.get_tree().physics_frame
			await go.call(main.interior.COOLER_SPOT)
			await press.call("interact")
			print("PALAUTUS kylmiö: kalja=%s hint '%s'" % [main.interior.has_beer, main._hint.text])
			await go.call(main.interior.GRILL_SPOT)
			await press.call("interact")
			print("PALAUTUS grilli: kori=%s hint '%s'" % [main.interior.cart, main._hint.text])
			await go.call(main.interior.QUEUE_FRONT)
			print("PALAUTUS kassalla: hint '%s' kauppias '%s'" % [main._hint.text.replace("
", " | "), main.interior._cashier_bubble.text])
			await press.call("interact")
			print("PALAUTUS kauppias-ikkuna %s: %s" % [main._talk_box.is_open(), str(main._talk_box._options.map(func(o): return o.text + ("" if o.enabled else " [" + o.reason + "]")))])
			main._talk_box.close()
			print("PALAUTUS maksuyritys: maksettu=%s" % main.interior.has_paid)
			await go.call(main.interior.GRILL_SPOT)
			await press.call("bell")
			print("PALAUTUS grilliin Q: kori=%s" % [main.interior.cart])
			await go.call(main.interior.COOLER_SPOT)
			print("PALAUTUS kylmiöllä: hint '%s'" % main._hint.text)
			await press.call("interact")
			print("PALAUTUS kylmiöön E: kalja=%s" % main.interior.has_beer)
			await press.call("interact")
			await go.call(main.interior.QUEUE_FRONT)
			await press.call("interact")
			main._test_talk(["jata"])
			print("PALAUTUS kassalle jätetty: kalja=%s kori=%s kauppias '%s' hint '%s'" % [main.interior.has_beer, main.interior.cart,
				main.interior._cashier_bubble.text, main._hint.text])
			await go.call(main.interior.DOOR)
			print("PALAUTUS ovella: hint '%s'" % main._hint.text)
		"kauppaovi":
			# Kauppa hommana: ovelta sisään, ulos kuutosen kanssa, kalja kädessä kielto, tyhjin käsin uudestaan
			# sisään (ostamatta ulos: kuutonen pysyy ostettuna), lopuksi kotiovelta sisään (E).
			main._toggle_mount()
			var press := func(action: String) -> void:
				await main.get_tree().process_frame
				Input.action_press(action)
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				Input.action_release(action)
				await main.get_tree().process_frame
			main.walker_out.global_position = main.shop_zone + Vector3(0, 0.3, 0)
			for i in 10:
				await main.get_tree().physics_frame
			print("KAUPPAOVI parkkipaikalla: hint '%s'" % main._hint.text)
			main.walker_out.global_position = main.shop_door + Vector3(0, 0.3, 0.5)
			for i in 10:
				await main.get_tree().physics_frame
			print("KAUPPAOVI ovella: hint '%s'" % main._hint.text)
			await press.call("interact")
			print("KAUPPAOVI sisään: tila %s" % main.state)
			main._on_shop_exited(true)
			for i in 10:
				await main.get_tree().physics_frame
			print("KAUPPAOVI ulos: tila %s, kaljat %d, viesti '%s', hint '%s'" % [main.state, main.beers, main._msg.text.replace("\n", " "), main._hint.text])
			main.walker_out.global_position = main.shop_door + Vector3(0, 0.3, 0.5)
			for i in 10:
				await main.get_tree().physics_frame
			await press.call("interact")
			print("KAUPPAOVI kalja kädessä: tila %s, viesti '%s'" % [main.state, main._msg.text])
			main.beers = 0
			main.walker_out.set_carrying(false)
			await press.call("interact")
			print("KAUPPAOVI tyhjin käsin: tila %s" % main.state)
			print("KAUPPAOVI toinen käynti: kalja kädessä %s, maksettu %s, kori %s, kassi %s" % [main.interior.has_beer,
				main.interior.has_paid, main.interior.cart, main.interior.bag])
			var b0 := main.beers
			main.interior.exited.emit(main.interior.has_paid and main.interior.has_beer)  # ulos kassan ohi ostamatta mitään
			await main.get_tree().process_frame
			print("KAUPPAOVI ulos ostamatta: kaljat %d -> %d, tila %s" % [b0, main.beers, main.state])
			main._enter_shop()
			main._on_shop_exited(false)
			print("KAUPPAOVI ostamatta ulos: tila %s" % main.state)
			main.walker_out.global_position = main.home_door + Vector3(0, 0.3, 0)
			for i in 10:
				await main.get_tree().physics_frame
			print("KAUPPAOVI kotiovella: hint '%s'" % main._hint.text)
			var dc := Camera3D.new()
			main.add_child(dc)
			var hf := M.HOME_YAW_DIR.normalized()
			dc.look_at_from_position(main.home_door + Vector3(hf.x, 0, hf.y) * 7.0 + Vector3(0, 2.5, 0), main.home_door + Vector3(0, 1.0, 0))
			dc.current = true
			main._msg.text = ""
			main._note.visible = false
			for i in 20:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_kotiovi.png"))
			dc.queue_free()
			main.walker_out.activate_camera()
			var d0 := main.day
			print("KAUPPAOVI ennen: lista tehty %s, ostokset %s, listalla %d" % [main._list_done, main.paivi_bag, main.shopping_list.size()])
			await press.call("interact")
			main.home_int.walker.position = main.home_int.SPOTS.sanky[0]
			for i in 5:
				await main.get_tree().physics_frame
			await press.call("interact")
			print("KAUPPAOVI Päivi: %s" % str(main._msg_queue))
			for i in 30:
				await main.get_tree().process_frame
			print("KAUPPAOVI kotiin: päivä %d -> %d, tila %s" % [d0, main.day, main.state])
		"shopfront":
			main.player.position = main.shop_zone + Vector3(0, 0.3, 14)
		"shopsigns":
			# Kaupan kyltit (KASSA, OLUET, GRILLI, ULOS) yleiskuvana ilman leijuvia opasteita.
			main._enter_shop()
			var sc := Camera3D.new()
			main.add_child(sc)
			sc.global_position = Main.INTERIOR_POS + Vector3(2.0, 9.0, 14.0)
			sc.look_at(Main.INTERIOR_POS + Vector3(0, 1.0, 0), Vector3.UP)
			sc.current = true
		"kauppalista":
			# Päivin lista: 3 oikein, 1 väärä väri ja 1 ylimääräinen; kotona palaute. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
			main.shopping_list = [["tamponi", "vihreä"], ["maito", "punainen"], ["ristikkolehti", "sininen"], ["voi", "keltainen"]]
			print("LISTA reppu=", main.inventory_info().list)
			main._enter_shop()
			var iw: CharacterBody3D = main.interior.walker
			var picks := [["tamponi", "vihreä"], ["maito", "punainen"], ["ristikkolehti", "sininen"], ["voi", "sininen"], ["kahvi", "punainen"]]
			for pk in picks:
				var idx: int = ShopInterior.PRODUCTS.keys().find(pk[0])
				iw.position = Vector3(10.4, 0, ShopInterior.SHELF_Z0 + idx + 0.5)
				await main.get_tree().process_frame
				var ci: int = ShopInterior.COLORS.keys().find(pk[1])
				for k in ci:
					Input.action_press("bell")
					await main.get_tree().process_frame
					Input.action_release("bell")
					await main.get_tree().process_frame
				print("  at %s hint=%s" % [pk[0], main.interior.hint])
				Input.action_press("interact")
				await main.get_tree().process_frame
				Input.action_release("interact")
				await main.get_tree().process_frame
			print("LISTA bag=", main.interior.bag, " reppu=", main.inventory_info().list)
			for i in 5:
				await main.get_tree().process_frame
			await Kuva.piirto()
			Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_shelf.png"))
			main.interior.has_paid = true
			main.interior.exited.emit(false)
			await main.get_tree().process_frame
			if main.player == main.bike:
				main._toggle_mount()
			var to_yard: Vector3 = (main.home_zone - main.home_door) * Vector3(1, 0, 1)
			main.walker_out.global_position = main.home_door + to_yard.normalized() * 1.6 + Vector3(0, 0.5, 0)
			for i in 20:
				await main.get_tree().physics_frame
			await main.get_tree().process_frame
			print("LISTA kotiovella hint=", main._hint.text, " bag=", main.paivi_bag)
			Input.action_press("interact")
			await main.get_tree().process_frame
			Input.action_release("interact")
			for i in 5:
				await main.get_tree().process_frame
			print("LISTA sisällä: tila %s viesti '%s'" % [main.state, main._msg.text])
			# Ostokset paikoilleen: jokainen piste, jossa kassissa on vietävää.
			for id in Main.PUT_AWAY:
				if not main._put_away_hints().has(id):
					continue
				main.home_int.walker.position = HomeInterior.SPOTS[id][0]
				for i in 3:
					await main.get_tree().process_frame
				print("LISTA %s hint '%s'" % [id, main._hint.text])
				main._msg_queue.clear()
				Input.action_press("interact")
				await main.get_tree().process_frame
				Input.action_release("interact")
				for i in 3:
					await main.get_tree().process_frame
				print("LISTA %s viesti '%s' | jonossa %s" % [id, main._msg.text.replace("\n", " | "),
					str(main._msg_queue.map(func(m): return m[0])).left(200)])
				if id == "jaakaappi":
					await Kuva.piirto()
					Kuva.ruutu(main.get_viewport()).save_png(path.replace(".png", "_jaakaappi.png"))
			print("LISTA valmis %s, paikoillaan %s, kassi %s, kaljarauha %s" % [main._list_done, main.paivi_placed, main.paivi_bag, main._kaljarauha])
			# Päivä päättyy kesken: kaksi listan tuotetta paikoillaan, kaksi kassissa. Kassiin jääneet pilalla
			# päättymistavan mukaan, eikä Päivi hyväksy niitä.
			for how in ["koti", "auto", "ulko"]:
				main._roll_list()
				main.paivi_placed = {main.shopping_list[0][0]: main.shopping_list[0][1], main.shopping_list[1][0]: main.shopping_list[1][1]}
				main.paivi_bag = {main.shopping_list[2][0]: main.shopping_list[2][1], main.shopping_list[3][0]: main.shopping_list[3][1]}
				if how == "koti":
					print("LISTA päättyi %s: %s" % [how, " | ".join(main._end_day_shopping("koti"))])
					continue
				main._day_end = how
				main._new_day(main.home_zone + Vector3(0, 0, 4), false)
				var txt := " / ".join(main._note.find_children("*", "Label", true, false).map(func(c): return c.text))
				var at := txt.rfind("Päivin")
				print("LISTA päättyi %s: %s" % [how, txt.substr(at, 260) if at >= 0 else txt.right(260)])
			if not saved.is_empty():
				FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		_:
			return 0
	return 1
