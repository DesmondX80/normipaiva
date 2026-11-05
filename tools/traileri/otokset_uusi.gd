extends RefCounted
## Rasvanappi-trailerin (leikkaus_rasvanappi.gd) uudet otokset: autovarkaus ja tähtijahti, huumekauppa, kolmiomittaus,
## Päivin motkotukset. Otokset.setup kutsuu tätä ensin; tyhjä palautus = tunnistamaton id (vanha lavastus).
## Apufunktiot (dolly, follow, _time...) haetaan otokset.gd:stä ajon aikana (load), ettei skriptien välille tule kehää.

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const M := preload("res://scripts/map_data.gd")


static func _o() -> GDScript:
	return load("res://tools/traileri/otokset.gd")


static func setup(main: Node3D, id: String, d: Node) -> Dictionary:
	match id:
		"a_kaappaus", "a_viisi_tahtea", "a_pako_saloinen", "a_poliisi_ilmestyy", "a_jahti_paivi", \
		"a_pako_onnistuu", "a_jahti_maali":
			return _auto(main, d, id)
		"h_takaovi_koputus", "h_luukku", "h_irma", "h_lamppu", "h_portsari":
			return _apteekki(main, d, id)
		"h_klaffipoyta", "h_teinit_kaukalo", "h_ambulanssi":
			return _kauppa(main, d, id)
		"a_pyora_eteen":
			return _pyora_eteen(main, d)
		"p_mummo":
			return _mummo(main, d)
		"h_makasiini", "h_lamppu_makasiini", "h_makasiini_koputus":
			return _makasiini_shot(main, d, id)
		"m_juna_vaalaan":
			return _juna_vaalaan(main, d)
		"v_ymparyra", "v_satama", "v_retki_rotko", "v_retki_karhu", "h_valeostaja", "a_jahti_roivainen":
			return _vaala_shot(main, d, id)
		"p_motkotus_koti", "p_motkotus_huume", "p_motkotus_pidatys":
			return _motkotus(main, d, id)
		"m_joni_esa", "m_sytkari", "m_kartta_harppi", "m_siviikki", "m_lahjat_ovella", "m_vaara_ovi", "m_ovi_aukeaa", "m_flirtti", \
		"m_ilta_vihje", "m_puhelu", "m_aamu":
			return _kolmio(main, d, id)
	return {}


# --- Autovarkaus ja tähtijahti ---------------------------------------------------------------------------------------

## Valmistelee kaappauksen: pelaaja jalan, liikenneauto seisoo tiellä (ketjun chain alku) pelaajan vieressä.
## Palauttaa {os, car, door, dir, end}; chain = tieverkon solmut (os._pisin_suora).
static func _stage_theft(main: Node3D, chain: Array, gap := 14.0) -> Dictionary:
	var os = main.rikos_osa("autovarkaus")
	if main.player != main.walker_out:
		main._toggle_mount()
	main.wife.grace = 1.0e6  # Päivi ei lähde ennen kaappausta
	var w: Node3D = main.world
	var a: int = chain[0]
	var b: int = chain[1]
	var pa: Vector3 = w.graph_nodes[a]
	var pb: Vector3 = w.graph_nodes[b]
	var dir := Vector3(pb.x - pa.x, 0, pb.z - pa.z).normalized()
	var cars: Array = os._liikenne()
	var car: Node3D = cars[0]
	for c in cars:  # pakettiauto kaapattavaksi (trailerin alku: hahmo varastaa pakettiauton)
		if c.van:
			car = c
			break
	for o in cars:
		if o != car:
			o.setup_graph(w.graph_nodes, w.graph_adj, main.wife.farthest_node_from(pa), w.graph_fast)
	os._aseta_auto(car, a, b, gap, 0.0)
	var door: Vector3 = car.global_transform * os._ovi(car)
	var wp := door + (door - car.global_position).normalized() * 0.4
	main.walker_out.global_position = Vector3(wp.x, T.h(wp.x, wp.z) + 0.3, wp.z)
	main.walker_out.rotation.y = B.yaw_to(car.global_position - wp)
	return {"os": os, "car": car, "door": door, "dir": dir, "end": w.graph_nodes[chain[-1]]}


## Kaapattu auto (main.bike) ajaa autopilotilla tieverkon pisteeseen to. Palauttaa tick-kutsun (ohjauspiste).
static func _drive(main: Node3D, to: Vector3, speed: float, dir: Vector3) -> Callable:
	var bike: Node3D = main.bike
	var rd: AStar3D = main.world.ride
	var route := Array(rd.get_point_path(rd.get_closest_point(bike.global_position), rd.get_closest_point(to)))
	bike.autopilot = true
	bike.auto_speed = speed
	return func(_t: float) -> void:
		if bike.speed < 12.0:  # liikenneauto tai muu kolari ei saa pysäyttää jahtia kesken otoksen
			bike.speed = 12.0
		var bp: Vector3 = bike.global_position
		# Reittipisteet auton takana tai aivan vieressä pois: ajetaan aina ajosuuntaan (dir).
		while route.size() > 1 and (Vector2(route[0].x - bp.x, route[0].z - bp.z).length() < 6.0 or (route[0] - bp).dot(dir) < 4.0):
			route.pop_front()
		if route.size() > 0:
			bike.auto_target = route[0]


## Jahtaajat paikalleen kaapatun auton taakse: Päivi back_wife m ja poliisi back_pol m (0 = ei poliisia).
static func _chasers(main: Node3D, os, dir: Vector3, back_wife: float, back_pol: float) -> Callable:
	var bp: Vector3 = main.bike.global_position
	var yaw := B.yaw_to(dir)
	var wf: CharacterBody3D = main.wife
	var wpos := bp - dir * back_wife
	wf.global_position = Vector3(wpos.x, T.h(wpos.x, wpos.z) + 0.2, wpos.z)
	wf.rotation.y = yaw
	wf.mode = "chase"
	wf._speed = 18.0
	if back_pol > 0.0 and os._poliisi != null and is_instance_valid(os._poliisi):
		var pp := bp - dir * back_pol
		os._poliisi.global_position = Vector3(pp.x, T.h(pp.x, pp.z) + 0.2, pp.z)
		os._poliisi.rotation.y = yaw
	# Jahtaajat pysyvät vähintään 9 m päässä (muuten Päivi nappaa kiinni kesken otoksen: WASTED ja auto katoaa).
	return func() -> void:
		var bike: Node3D = main.bike
		var fwd := -bike.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		for ch in [wf, os._poliisi]:
			if ch != null and is_instance_valid(ch):
				var rel: Vector3 = ch.global_position - bike.global_position
				if rel.length() < 9.0:
					var np: Vector3 = bike.global_position - fwd * 9.0
					ch.global_position = Vector3(np.x, T.h(np.x, np.z) + 0.2, np.z)


static func _auto(main: Node3D, d: Node, id: String) -> Dictionary:
	var O := _o()
	O._time(main, 16, 20)
	var os0 = main.rikos_osa("autovarkaus")
	var chain: Array = os0._pisin_suora()
	var st := _stage_theft(main, chain)
	var os = st.os
	var car: Node3D = st.car
	var dir: Vector3 = st.dir
	var side: Vector3 = (st.door - car.global_position).normalized()  # kuljettajan puolen suunta
	var c0: Vector3 = car.global_position
	if id == "a_kaappaus":
		var state := {"done": false}
		var tick := func(t: float) -> void:
			if t >= 0.8 and not state.done:
				state.done = true
				os.kaappaa(car)
		# Kamera kuljettajan puolelta: pelaaja ovella, kuski hyppää ulos, kamera työntyy hitaasti sisään.
		return {"tick": tick, "cam": O.dolly(c0 + side * 8.0 + Vector3(0, 1.8, 3.5), c0 + side * 5.6 + Vector3(0, 1.5, 1.8),
			c0 + Vector3(0, 1.0, 0), c0 + Vector3(0, 1.1, -0.2), 3.6), "fov": 46.0, "warm": 12}
	# Muut: auto on jo kaapattu ja ajaa pitkää suoraa. Kuski ja hänen huutonsa ("HEI! MUN AUTO!") vain kaappauskuvassa.
	os.kaappaa(car)
	os._poista_kuski()
	Sfx.stop_speech()
	var drive := _drive(main, st.end, 1.0, dir)
	var bike: Node3D = main.bike
	bike.rotation.y = B.yaw_to(dir)  # ajosuunta tiellä, lähtövauhti (ei seisovaa autoa)
	bike.speed = 16.0
	match id:
		"a_viisi_tahtea":  # edestä taaksepäin: pakettiauto kameraa kohti, takana Päivin Hyundai ja poliisiauto jahtaamassa
			var keepv := _chasers(main, os, dir, 18.0, 28.0)
			var tk := func(t: float) -> void:
				drive.call(t)
				keepv.call()
			# Edestä oikealta taaksepäin: auto etualalla, sen takana Päivin Hyundai ja poliisiauto (kamera nousee esteiden yli)
			return {"tick": tk, "cam": O.follow(bike, Vector3(3.4, 1.5, -7.0), Vector3(2.8, 1.4, -6.0), Vector3(-1.0, 1.2, 11.0), 3.0, main), "fov": 54.0,
				"warm": 8}
		"a_pako_saloinen":  # sivulta seuraten, Päivin Hyundai nousee perässä kuvaan
			var keep := _chasers(main, os, dir, 30.0, 0.0)
			return {"tick": func(t: float) -> void:
				drive.call(t)
				keep.call(), "cam": O.follow(bike, Vector3(6.0, 1.5, 1.5), Vector3(5.0, 1.3, -2.5), Vector3(0, 1.0, 0.0), 3.6), "fov": 44.0,
				"warm": 24}
		"a_poliisi_ilmestyy":  # poliisiauto sinkoaa kameran ohi
			os._paivita_jahtaaja()
			var keep := _chasers(main, os, dir, 26.0, 18.0)
			return {"tick": func(t: float) -> void:
				drive.call(t)
				keep.call(), "cam": O.follow(bike, Vector3(2.4, 1.2, 8.0), Vector3(2.0, 1.3, 11.0), Vector3(0, 1.0, -4.0), 2.0), "fov": 46.0,
				"warm": 24}
		"a_jahti_paivi":  # edestä alhaalta: varastettu auto ja Päivin Hyundai kiinni perässä, tähdet
			var keep := _chasers(main, os, dir, 18.0, 28.0)
			return {"tick": func(t: float) -> void:
				drive.call(t)
				keep.call(), "cam": O.follow(bike, Vector3(-3.4, 1.2, -7.0), Vector3(-2.8, 1.3, -6.0), Vector3(1.0, 1.2, 11.0), 3.0, main), "fov": 54.0,
				"warm": 8}
		"a_pako_onnistuu", "a_jahti_maali":  # tähdet putoavat yksi kerrallaan, kamera kiertää autoa edestä
			var hud = os._hud
			var keep2 := _chasers(main, os, dir, 40.0, 0.0)
			var tk := func(t: float) -> void:
				drive.call(t)
				keep2.call()
				var n := maxi(0, 5 - int(t / 0.45))
				os.tahdet = n
				if hud != null:
					hud.tahdet = n
					hud.nakyy = false
			return {"tick": tk, "cam": O.follow(bike, Vector3(-3.0, 1.1, -5.5), Vector3(-2.2, 1.6, -4.0), Vector3(0, 1.0, 5.0), 3.0), "fov": 42.0,
				"warm": 24}
	return {}


# --- Huumekauppa: Saloisten apteekin takaovi (apteekki_saloinen.gd), Irma ja makasiinin portsari ------------------------

## Pelaaja jalan koputuspisteessä katsoen ovea. Palauttaa {door, kp, out, side}.
static func _at_door(main: Node3D, door: Node3D, kp: Vector3, out: Vector3) -> Dictionary:
	if main.player != main.walker_out:
		main._toggle_mount()
	main.walker_out.global_position = Vector3(kp.x, T.h(kp.x, kp.z) + 0.3, kp.z)
	main.walker_out.rotation.y = B.yaw_to(door.global_position - kp)
	var o := Vector3(out.x, 0, out.z).normalized()
	return {"door": door, "kp": kp, "out": o, "side": o.cross(Vector3.UP)}


static func _apteekki(main: Node3D, d: Node, id: String) -> Dictionary:
	var O := _o()
	if id == "h_portsari":
		return _portsari(main, O)
	var ap: Dictionary = main.world.apteekki_s
	var door: Node3D = ap.back
	var st := _at_door(main, door, ap.knock, ap.out)
	var dg := door.global_transform
	var hatch: Node3D = door.get_node("Ovi/Luukku")
	var fill: OmniLight3D = ap.fill
	var travel: float = load("res://scripts/makasiini.gd").HATCH_TRAVEL
	var up := Vector3.UP
	match id:
		"h_takaovi_koputus":  # hämärä: kolme koputusta iskuilla, luukku aukeaa viimeisen jälkeen
			O._time(main, 20, 40)
			var state := {"n": 0}
			var tick := func(t: float) -> void:
				var beats := [0.0, 0.47, 0.93]  # koputukset iskuun (1 isku = 0,465 s)
				if state.n < 3 and t >= beats[state.n]:
					state.n += 1
					Sfx.play("punch", -6.0, 0.6)
				if state.n >= 3 and t >= 1.25 and not state.get("open", false):
					state.open = true
					fill.visible = true
					Sfx.play("door_open", -10.0, 1.6)
					var tw := main.create_tween()
					tw.tween_property(hatch, "position:x", -0.5 + travel, 0.3)
			var kp: Vector3 = st.kp
			return {"tick": tick, "cam": O.dolly(kp + st.out * 3.6 + st.side * 2.4 + up * 1.7, kp + st.out * 2.6 + st.side * 1.8 + up * 1.6,
				dg.origin + up * 1.4, dg.origin + up * 1.5, 1.9), "fov": 44.0, "warm": 12}
		"h_luukku":  # luukku auki, hoitaja Raili ja valo: lähikuva luukusta
			O._time(main, 20, 50)
			fill.visible = true
			hatch.position.x = -0.5 + travel
			var mk: Script = load("res://scripts/makasiini.gd")
			return {"cam": O.dolly(dg * Vector3(0.9, mk.HATCH_Y + 0.15, 1.7), dg * Vector3(0.25, mk.HATCH_Y + 0.05, 0.9),
				dg * Vector3(-0.15, mk.HATCH_Y, 0), dg * Vector3(-0.15, mk.HATCH_Y, 0), 3.0), "fov": 40.0, "warm": 14}
		"h_lamppu":  # hämärä: takaoven vihreä lamppu, ovi ja pimenevä piha
			O._time(main, 21, 10)
			var kp: Vector3 = st.kp
			main.walker_out.visible = false
			return {"cam": O.dolly(dg * Vector3(1.8, 1.5, 4.5), dg * Vector3(1.0, 1.9, 3.2), dg * Vector3(0, 1.8, 0), dg * Vector3(0, 2.1, 0), 3.5),
				"fov": 42.0, "warm": 14}
		"h_irma":  # Irma tuijottaa takaovea ja nostaa kännykän korvalle
			O._time(main, 20, 30)
			var os = main.rikos_osa("epaluulo")
			os.halytys = true
			os._soitto_t = os.SOITTO
			main.walker_out.global_position = Vector3(st.kp.x, T.h(st.kp.x, st.kp.z) + 0.3, st.kp.z) + st.out * 5.0
			var cam := func(_t: float) -> Array:
				var n: Node3D = os.node
				if n == null or not is_instance_valid(n):
					return [dg.origin + st.out * 6.0 + up * 1.8, dg.origin + up * 1.2]
				var f := -n.global_transform.basis.z
				return [n.global_position + f * 2.6 + n.global_transform.basis.x * 0.8 + up * 1.6, n.global_position + up * 1.5]
			return {"cam": cam, "fov": 40.0, "warm": 40}
	return {}


## Makasiinin takaovi (rasvanappi): portsarin luukku ja koputus, pelin oma luukkukohtaus (vain alku).
static func _portsari(main: Node3D, O: GDScript) -> Dictionary:
	O._time(main, 21, 20)
	var w: Node3D = main.world
	var door_p: Vector3 = w.makasiini_door
	var mr: Node3D = w.makasiini_root
	var door: Node3D = mr.get_node("Takaovi")
	if main.player != main.walker_out:
		main._toggle_mount()
	var dg := door.global_transform
	var fwd := dg.basis.z  # oven etusuunta ulos
	var p: Vector3 = door_p
	main.walker_out.global_position = Vector3(p.x, T.h(p.x, p.z) + 0.3, p.z)
	main.walker_out.rotation.y = B.yaw_to(dg.origin - p)
	main._start_rasvanappi()  # pelin oma luukkukohtaus käynnistyy heti; valmisteluruudut (warm) odottavat, että luukku aukeaa
	var mk: Script = load("res://scripts/makasiini.gd")
	# Pelin salasanavalikko ilmestyy ajasta 2,4 s: aika pysäytetään ennen sitä (portsari ja "Salasana." -kupla jäävät kuvaan).
	var freeze := func(_t: float) -> void:
		var rg = main._rasva_game
		if rg != null and is_instance_valid(rg) and rg._t > 2.3:
			rg._t = 2.3
	return {"tick": freeze, "cam": O.dolly(dg * Vector3(0.6, mk.HATCH_Y + 0.2, 2.4), dg * Vector3(0.2, mk.HATCH_Y + 0.05, 1.5), dg * Vector3(0, mk.HATCH_Y, 0),
		dg * Vector3(0, mk.HATCH_Y, 0), 2.0),
		"fov": 40.0, "warm": 50, "hud": false}


# --- Huumekauppa: jatkaminen klaffipöydällä, kaukalon teinit ja ambulanssi -------------------------------------------------

static func _kauppa(main: Node3D, d: Node, id: String) -> Dictionary:
	var O := _o()
	if main.player != main.walker_out:
		main._toggle_mount()
	match id:
		"h_klaffipoyta":
			# Pelin oma askarteluruudukko (klaffipoyta.gd): pervitiini + sokeri vinoon -> neljä annosta. Ruudukko täytetään
			# tikillä esineet kerrallaan, ja tulos syttyy kultaiseksi.
			O._time(main, 14, 20)
			main.klaffipoyta = true
			main.laake = {"perv": 2, "opiaatti": 1, "burana": 2, "panadol": 1}
			main.has_sugar = true
			main._start_klaffipoyta()
			var g = main._klaffi_game
			var tick := func(t: float) -> void:
				if g == null or not is_instance_valid(g):
					return
				g._cells[0] = "perv" if t >= 0.35 else ""
				g._cells[4] = "sokeri" if t >= 0.95 else ""
			var p: Vector3 = main.walker_out.global_position
			return {"tick": tick, "cam": O.dolly(p + Vector3(0, 1.6, 3.0), p + Vector3(0, 1.6, 2.6), p + Vector3(0, 1.4, 0), p + Vector3(0, 1.4, 0)),
				"fov": 50.0, "warm": 10, "hud": false}
		"h_teinit_kaukalo":
			# Illalla kaukalon itälaidalla kolme teiniä ringissä, kaiutin soi: pelaaja tulee kauppaamaan.
			O._time(main, 21, 30)
			var th: Node3D = main.hs_teens
			th.set_on(true)
			th.target = main.walker_out
			var c: Vector3 = th.center()
			var out := Vector3(1, 0, 0).rotated(Vector3.UP, 0.35)
			var hp := c + out * 3.4
			main.walker_out.global_position = Vector3(hp.x, T.h(hp.x, hp.z) + 0.3, hp.z)
			main.walker_out.rotation.y = B.yaw_to(c - hp)
			var side := out.cross(Vector3.UP)
			# Sivusta: pelaaja ja teinit profiilissa ringin kahta puolta
			return {"cam": O.dolly(c + out * 1.7 + side * 6.4 + Vector3(0, 1.5, 0), c + out * 1.7 + side * 4.8 + Vector3(0, 1.5, 0),
				c + out * 1.7 + Vector3(0, 1.25, 0), c + out * 1.7 + Vector3(0, 1.25, 0), 2.0), "fov": 42.0, "warm": 24}
		"h_ambulanssi":
			# Ambulanssi kaukalon vieressä, ensihoitajat ja makaava teini (yliannos.gd tapaus + saapuminen)
			O._time(main, 22, 10)
			var y = main.rikos_osa("yliannos")
			y.aloita()
			y._soita()
			y._ambulanssi_tulee()
			var tp: Vector3 = y.teini.global_position
			main.walker_out.global_position = tp + Vector3(0, 0, 6.0)
			main.walker_out.rotation.y = B.yaw_to(tp - main.walker_out.global_position)
			var tickv := func(_t: float) -> void:
				y._vilkku()
			var camv := func(t: float) -> Array:
				var am: Node3D = y.ambu
				if am == null or not is_instance_valid(am):
					return [tp + Vector3(7.0, 2.2, 5.0), tp + Vector3(0, 1.0, 0)]
				var mid := am.global_position.lerp(tp, 0.5)
				var ab := am.global_transform.basis
				var k := clampf(t / 3.0, 0.0, 1.0)
				return [mid + ab.x * lerpf(11.0, 8.5, k) + Vector3(0, lerpf(3.4, 2.8, k), 0) - ab.z * 3.0, mid + Vector3(0, 1.1, 0)]
			return {"tick": tickv, "cam": camv, "fov": 48.0, "warm": 30}
	return {}


# --- Kolmiomittaus: kaverit, Sytkäri, kartta, ovikohtaukset ----------------------------------------------------------------

## Kolmiomittauksen 3D-kohtaus (kolmio_kohtaus.gd) pelin omilla tiedoilla; rivit etenevät tikissä (auto pois).
static func _kolmio_scene(main: Node3D, mode: String, site: String, setup := Callable()) -> CanvasLayer:
	var K: Script = load("res://scripts/kolmio_kohtaus.gd")
	var Kol: Script = load("res://scripts/kolmiomittaus.gd")
	var ui: CanvasLayer = K.new()
	ui.mode = mode
	ui.site = site
	var info: Dictionary = Kol.SITES[site]
	ui.woman = info.woman
	ui.friends = info.friends
	ui.gifts = info.gifts
	if setup.is_valid():
		setup.call(ui)
	ui.auto = false
	main.add_child(ui)
	# Tekstilaatikko ruudun ylälaidassa jäisi leikkauksen mustan palkin alle: näkymä palkkien väliin, ja ohjeteksti
	# ("[E] jatka") alapalkin taakse (näkymä jatkuu 40 px palkin alle ja leikkautuu piiloon).
	var sz: Vector2 = main.get_viewport().get_visible_rect().size
	var bar := maxf(0.0, (sz.y - sz.x / 2.2) / 2.0)
	ui._view.offset_top = bar
	ui._view.offset_bottom = -bar + 40.0
	return ui


## Musta peitto otoksen loppuun (valo sammuu): CanvasLayer, joka poistetaan otoksen jälkeen.
static func _dim(main: Node3D, from_t: float, to_t: float, max_a := 0.92) -> Array:
	var layer := CanvasLayer.new()
	layer.layer = 90
	var r := ColorRect.new()
	r.color = Color(0.02, 0.01, 0.04, 0.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(r)
	main.add_child(layer)
	var f := func(t: float) -> void:
		r.color.a = clampf((t - from_t) / maxf(to_t - from_t, 0.01), 0.0, 1.0) * max_a
	return [layer, f]


static func _kolmio(main: Node3D, d: Node, id: String) -> Dictionary:
	var O := _o()
	match id:
		"m_joni_esa":  # päivä: Joni päkkirinkka selässä ja Esa harppi taskussa kaupan pihalla
			O._time(main, 12, 0)
			var joni: Node3D = main._kolmio_joni
			var esa: Node3D = main._kolmio_esa
			esa.visible = true
			var jp := joni.global_position
			var fwd := -joni.global_transform.basis.z
			main.walker_out.global_position = jp + fwd * 3.0 + Vector3(0, 0.3, 0)
			main.walker_out.rotation.y = B.yaw_to(-fwd)
			var side := fwd.cross(Vector3.UP)
			# Kamera Jonin takakulmasta: rinkka (Sandels-pakkaus, golfpallot) näkyy, Esa ja pelaaja taustalla.
			return {"cam": O.dolly(jp - fwd * 4.4 + side * 2.4 + Vector3(0, 1.7, 0), jp - fwd * 3.6 + side * 2.8 + Vector3(0, 1.7, 0),
				jp + Vector3(0, 1.3, 0) + fwd * 0.8, jp + Vector3(0, 1.3, 0) + fwd * 1.0, 3.0), "fov": 40.0, "warm": 20}
		"m_sytkari":  # Sytkäri: Mintun profiilikortti liukuu ja mätsi syttyy
			O._time(main, 12, 0)
			var S: Script = load("res://scripts/sytkari.gd")
			var Kol: Script = load("res://scripts/kolmiomittaus.gd")
			var info: Dictionary = Kol.SITES["saloinen"]
			var sy: CanvasLayer = S.new()
			sy.mode = "match"
			sy.who = info.woman
			sy.age = info.age
			sy.job = info.job
			sy.bio = info.bio
			sy.dist = "250 m"
			sy.note_from = "Esa"
			sy.note = "Hyvä. Merkkaan harpilla."
			main.add_child(sy)
			var tk := func(t: float) -> void:
				sy._t = 1.0 + t * 1.6  # nopeammin: kortti nousee ja lentää oikealle ennen otoksen loppua
			return {"tick": tk, "warm": 6, "hud": false,
				"cam": O.dolly(main.walker_out.global_position + Vector3(0, 1.6, 3.0), main.walker_out.global_position + Vector3(0, 1.6, 3.0),
					main.walker_out.global_position + Vector3(0, 1.4, 0), main.walker_out.global_position + Vector3(0, 1.4, 0))}
		"m_kartta_harppi":  # paperikartta: harpilla piirretyt ympyrät leikkaavat naisen talon kohdalla
			O._time(main, 12, 0)
			var kol = main.kolmio
			var target: Vector2 = main._kolmio_target("saloinen")
			kol.start("saloinen", target + Vector2(-210, 40), target, "Joni")
			kol.measure("saloinen", target + Vector2(150, 190), target, "Esa")
			kol.measure("saloinen", target + Vector2(180, -60), target, "x")
			main._paper.toggle()
			main._paper._vcenter = target
			main._paper._vzoom = 0.35
			var tk := func(t: float) -> void:
				main._paper._vzoom = lerpf(0.45, 1.3, clampf(t / 3.0, 0.0, 1.0))
			return {"tick": tk, "warm": 10, "hud": false}
		"m_siviikki":  # Vaala: Timon punainen Siviikki, VTEC kytkeytyy (pelin oma ajo)
			O._time(main, 15, 30)
			O._vaala(main)
			main._mopo_dismount()  # ajo alkaa jalan seisovasta pelaajasta (mopo_trip.on_foot)
			var st := {"on": false}
			var tk := func(t: float) -> void:
				if not st.on and t >= 0.05:
					st.on = true
					main._kolmio_drive_start()
			return {"tick": tk, "warm": 10, "hud": false}
		"m_lahjat_ovella", "m_vaara_ovi", "m_ovi_aukeaa", "m_flirtti", "m_ilta_vihje", "m_puhelu", "m_aamu":
			return _kolmio_ovi(main, O, id)
	return {}


static func _kolmio_ovi(main: Node3D, O: GDScript, id: String) -> Dictionary:
	O._time(main, 20, 0)
	var Kol: Script = load("res://scripts/kolmiomittaus.gd")
	var spec := {"warm": 6, "hud": false}
	match id:
		"m_lahjat_ovella":  # KOP KOP KOP, ovi aukeaa, kolme tietäjää ojentavat lahjat
			var ui := _kolmio_scene(main, "ovi", "saloinen")
			var steps := [0.9, 1.9, 2.5, 3.1]
			var st := {"i": 0}
			spec.tick = func(t: float) -> void:
				while st.i < steps.size() and t >= steps[st.i]:
					st.i += 1
					ui._next()
		"m_vaara_ovi":  # väärä ovi: mummo kepin kanssa
			var ui := _kolmio_scene(main, "vaara", "saloinen", func(u) -> void: u.resident = Kol.WRONG_DOORS.saloinen[0])
			var steps := [0.8, 2.3]
			var st := {"i": 0}
			spec.tick = func(t: float) -> void:
				while st.i < steps.size() and t >= steps[st.i]:
					st.i += 1
					ui._next()
		"m_ovi_aukeaa", "m_flirtti", "m_ilta_vihje":  # oikea ovi auki, lahjat pöydällä, nainen hymyilee
			var ui := _kolmio_scene(main, "ovi", "saloinen")
			ui._given = 3
			ui._door = 1.0
			ui._door_to = 1.0
			ui._line = ui.lines.size() - 1
			if id != "m_ovi_aukeaa":
				ui.lines = ui.lines.duplicate()
				ui.lines[ui._line] = [ui.woman, "Kiitos kukista. Ja mansikoista. Ja... ootko sää vapaa koko illan? ;)" if id == "m_flirtti"
					else "Tulkaa sisään. Hyvää iltapuuhaa."]
			if id == "m_ilta_vihje":
				var dim := _dim(main, 0.4, 1.6)
				spec.tick = func(t: float) -> void:
					dim[1].call(t)
					if t >= 0.5 and ui._door_to > 0.0:
						ui._door_to = 0.0
						Sfx.play("door_close", -2.0, 1.1)
				spec.done = func() -> void:
					dim[0].queue_free()
		"m_puhelu", "m_aamu":  # aamu: kahvit ja mansikkaletut; Päivin vastaamaton puhelu ja "MAITOA."
			var ui := _kolmio_scene(main, "aamu", "saloinen")
			if id == "m_puhelu":
				ui._line = ui.lines.size() - 1
	return spec


# --- Päivin motkotukset (pelin omat WASTED-välianimaatiot kotipihalla) -----------------------------------------------------

static func _motkotus(main: Node3D, d: Node, id: String) -> Dictionary:
	var O := _o()
	O._time(main, 22, 30)
	var home := M.w(M.HOME_BUILDING)
	var tick := func(t: float) -> void:
		if absf(t - 0.25) < 0.02:
			match id:
				"p_motkotus_koti":
					main._lose("Päivi nappasi kiinni!", "wife")
				"p_motkotus_huume":
					main._rikos_loppu("yliannos", "Otit liikaa. Hengitys katkesi.")
				"p_motkotus_pidatys":
					main._rikos_loppu("pidatys", "Teit kauppaa väärälle ostajalle.")
	return {"lose": true, "tick": tick, "settle": false, "cs_bubbles": true}


# --- Vaala: uudet paikat, retket, valeostaja ja Roivaisen jahti ---------------------------------------------------------------

static func _vaala_shot(main: Node3D, d: Node, id: String) -> Dictionary:
	var O := _o()
	if id in ["v_retki_rotko", "v_retki_karhu"]:
		O._time(main, 12, 0)
		if main.player != main.walker_out:
			main._toggle_mount()
		main.money = 80.0
		if id == "v_retki_rotko":
			main._enter_retki("hiidenportti")
			main._start_hiidenportti()
		else:
			main._enter_retki("kuhmo")
			main._start_karhut()
		return {"warm": 60 if id == "v_retki_rotko" else 150, "hud": false}
	var mt: Node3D = O._vaala(main)
	var vl: Node3D = mt.vaala
	for car in mt._cars:  # liikenne pois kuvasta (ei törmäilyä)
		car.process_mode = Node.PROCESS_MODE_DISABLED
		car.visible = false
	var up := Vector3.UP
	match id:
		"v_ymparyra":  # uusi K-Market ja liikenneympyrä ylhäältä
			O._time(main, 11, 30)
			var kc: Vector3 = mt.to_global(Vector3(vl.kmarket_center.x, vl.h(vl.kmarket_center.x, vl.kmarket_center.z), vl.kmarket_center.z))
			print("TRAILER kmarket center %s face %s out %s" % [vl.kmarket_center, vl.kmarket_face, vl.kmarket_out])
			var ko: Vector3 = mt.global_basis * (vl.kmarket_face if vl.kmarket_face.length() > 0.1 else vl.kmarket_out)
			ko.y = 0.0
			ko = ko.normalized() if ko.length() > 0.1 else Vector3(1, 0, 1).normalized()
			var side := ko.cross(up)
			return {"cam": O.dolly(kc + ko * 55.0 + side * 25.0 + up * 32.0, kc + ko * 42.0 + side * 14.0 + up * 22.0, kc + up * 3.0, kc + ko * 8.0 + up * 2.0, 4.0),
				"fov": 52.0, "warm": 24}
		"v_satama":  # Venesatama: muskelivene parkissa, laituri ja järvi
			O._time(main, 18, 40)
			var dk: Vector3 = mt.to_global(vl.satama_dock)
			var dr: Vector3 = mt.to_global(vl.satama_door)
			var bt: Vector3 = mt.to_global(vl.satama_boat_tf.origin)
			var ft := (dk - dr)
			ft.y = 0.0
			ft = ft.normalized()
			var sd := ft.cross(up)
			return {"cam": O.dolly(bt + sd * 9.0 - ft * 3.0 + up * 2.2, bt + sd * 6.0 - ft * 1.0 + up * 1.8, bt + up * 1.0, dk + up * 0.8, 4.0),
				"fov": 48.0, "warm": 24}
		"h_valeostaja":  # torilla: siviilipoliisi korvanappi ja kierrejohto, "Mä otan kaikki"
			O._time(main, 13, 0)
			var os = main.rikos_osa("valeostaja")
			os.paiva = main.day
			os.on = true
			os.vale = true
			os._ensure_node(vl)
			var n: Node3D = os.node
			var np: Vector3 = n.global_position
			var f := -n.global_transform.basis.z
			f.y = 0.0
			var hp := np + f * 2.6
			main._mopo_dismount()
			main.walker_out.global_position = hp
			main.walker_out.rotation.y = B.yaw_to(np - hp)
			var sdv := f.cross(up)
			return {"cam": O.dolly(np + f * 3.4 + sdv * 1.5 + up * 1.6, np + f * 2.6 + sdv * 1.1 + up * 1.6, np + up * 1.45, np + up * 1.5, 3.0),
				"fov": 38.0, "warm": 24}
		"a_jahti_roivainen":  # varastettu auto ja Roivaisen poliisi-Saab Vaalan tiellä, viisi tähteä
			O._time(main, 16, 0)
			var os = main.rikos_osa("autovarkaus")
			os.paikka = "vaala"
			os.tahdet = 5
			var mp: CharacterBody3D = mt.mopo
			var si := 60
			var dr: Vector3 = vl.road_dir(si)
			mp.position = vl.road_pos(si) + Vector3(0, 0.6, 0) + dr.cross(up) * 0.9
			mp.rotation.y = atan2(-dr.x, -dr.z)
			mp.set_car(true, Color(0.3, 0.5, 0.35), false)
			mp.speed = 16.0
			os._luo_roivainen()
			var rv: CharacterBody3D = os._roivainen
			rv.heat_mult = 1.0
			rv.active = true
			rv.target = mp
			rv.place_at(float(si - 9), 1)
			var ms := {"i": si}
			var hud = os._hud
			var tick := func(_t: float) -> void:
				while vl.road_pos(ms.i + 1).distance_to(mp.position) < vl.road_pos(ms.i).distance_to(mp.position):
					ms.i += 1
				var tgt: Vector3 = vl.road_pos(ms.i + 4) + vl.road_dir(ms.i + 4).cross(up) * 0.9
				var v := tgt - mp.position
				mp.rotation.y = lerp_angle(mp.rotation.y, atan2(-v.x, -v.z), 0.2)
				if hud != null:
					hud.tahdet = 5
					hud.nakyy = true
			return {"tick": tick, "keys": [[0.0, "forward", 99.0]], "warm": 12,
				"cam": O.follow(rv, Vector3(4.6, 1.7, 5.5), Vector3(3.6, 1.5, 4.0), Vector3(0, 1.0, -8.0), 3.0), "fov": 48.0}
	return {}


# --- Saloisten makasiini (aseman takana): punainen lamppu ja takaovi ----------------------------------------------------------

static func _makasiini_shot(main: Node3D, d: Node, id: String) -> Dictionary:
	var O := _o()
	O._time(main, 21, 20)
	var w: Node3D = main.world
	var door: Node3D = w.makasiini_root.get_node("Takaovi")
	var dg := door.global_transform
	var up := Vector3.UP
	if main.player != main.walker_out:
		main._toggle_mount()
	var p: Vector3 = w.makasiini_door
	main.walker_out.global_position = Vector3(p.x, T.h(p.x, p.z) + 0.3, p.z)
	main.walker_out.rotation.y = B.yaw_to(dg.origin - p)
	match id:
		"h_makasiini":  # makasiini ja takaovi hämärässä: punainen lamppu palaa
			main.walker_out.visible = false
			return {"cam": O.dolly(dg * Vector3(9.0, 3.2, 14.0), dg * Vector3(5.5, 2.6, 8.5), dg * Vector3(-1.0, 2.0, 0.0), dg * Vector3(0, 2.1, 0), 4.0),
				"fov": 46.0, "warm": 20}
		"h_lamppu_makasiini":  # lähikuva punaisesta lampusta häkissä oven yllä
			main.walker_out.visible = false
			var lamp: Node3D = door.get_node("Lamppu")
			var lp := lamp.global_position
			return {"cam": O.dolly(lp + dg.basis.z * 2.6 + dg.basis.x * 1.2 + up * 0.2, lp + dg.basis.z * 1.7 + dg.basis.x * 0.7 + up * 0.1, lp, lp, 2.0),
				"fov": 40.0, "warm": 20}
		"h_makasiini_koputus":  # pelaaja koputtaa kolme kertaa ja luukku alkaa avautua (pelin oma luukkukohtaus alusta)
			main._start_rasvanappi()
			var frz := func(_t: float) -> void:  # salasanavalikko ilmestyy ajasta 2,4 s: aika pysäytetään ennen sitä
				var rg = main._rasva_game
				if rg != null and is_instance_valid(rg) and rg._t > 2.3:
					rg._t = 2.3
			return {"tick": frz, "cam": O.dolly(dg * Vector3(2.2, 1.7, 3.2), dg * Vector3(1.4, 1.6, 2.2), dg * Vector3(0.1, 1.5, 0.5), dg * Vector3(0, 1.55, 0.2), 2.0),
				"fov": 44.0, "warm": 1, "hud": false}
	return {}


# --- Junamatka Vaalaan: verkkopaita ja 40 € taskussa (pelin erikoiskohtaus) ---------------------------------------------------------

static func _juna_vaalaan(main: Node3D, d: Node) -> Dictionary:
	var O := _o()
	O._time(main, 18, 30)
	load("res://scripts/looks.gd").outfit = "farkut"  # verkkopaita, henkselit ja työhousut
	if main.player != main.walker_out:
		main._toggle_mount()
	main.money = 40.0  # matka 10 € + kossut naisille 16 € = erikoiskohtaus
	main._train_trip("vaala")
	return {"warm": 400, "hud": false}


# --- Alku: pyöräilijä polkee pakettiauton eteen ----------------------------------------------------------------------------------

static func _pyora_eteen(main: Node3D, d: Node) -> Dictionary:
	var O := _o()
	O._time(main, 16, 20)
	var os0 = main.rikos_osa("autovarkaus")
	var chain: Array = os0._pisin_suora()
	var st := _stage_theft(main, chain, 30.0)
	var car: Node3D = st.car
	var dir: Vector3 = st.dir
	car.process_mode = Node.PROCESS_MODE_DISABLED  # pakettiauto seisoo tiellä
	var vp: Vector3 = car.global_position
	var left := -dir.cross(Vector3.UP)
	var bike: Node3D = main.bike
	main.walker_out.visible = false
	main.bike.global_position = vp - dir * 11.0 + left * 2.4 + Vector3(0, 0.4, 0)
	main.bike.rotation.y = B.yaw_to(dir)
	main._toggle_mount()  # pelaaja pyörän selkään
	bike.speed = 8.0
	var pts := [vp - dir * 3.0 + left * 2.2, vp + dir * 4.0 + left * 1.4, vp + dir * 7.5]
	bike.autopilot = true
	bike.auto_speed = 0.85
	var tick := func(_t: float) -> void:
		var bp: Vector3 = bike.global_position
		while pts.size() > 1 and Vector2(pts[0].x - bp.x, pts[0].z - bp.z).length() < 3.0:
			pts.pop_front()
		bike.auto_target = pts[0]
		if pts.size() == 1 and Vector2(pts[0].x - bp.x, pts[0].z - bp.z).length() < 2.2:  # pysähtyy auton eteen
			bike.auto_speed = 0.0
			bike.speed = 0.0
	var right := -left  # kamera auton oikealta puolelta (vasemman puolen lehvistö ei peitä kuvaa)
	var cam: Callable = O.dolly(vp + right * 8.5 - dir * 7.0 + Vector3(0, 2.3, 0), vp + right * 7.0 - dir * 2.0 + Vector3(0, 2.0, 0),
		vp + dir * 2.0 + Vector3(0, 0.9, 0), vp + dir * 6.0 + Vector3(0, 0.9, 0), 3.0)
	return {"tick": tick, "cam": cam, "fov": 46.0, "warm": 6}


# --- Kuolema mummon keppiin ja Päivin motkotus (pelin oma kohtaus, ääni mukana) -------------------------------------------

static func _mummo(main: Node3D, d: Node) -> Dictionary:
	var O := _o()
	O._time(main, 13, 30)
	if main.player != main.walker_out:
		main._toggle_mount()
	var st: Node3D = main.mummot._stand
	var front: Vector3 = st.global_transform * Vector3(0.1, 0, 1.25)
	main.walker_out.global_position = front + Vector3(0, 0.3, 0)
	main.walker_out.rotation.y = B.yaw_to(st.global_position - front)
	var e0: Vector3 = st.global_transform * Vector3(-3.2, 1.6, 0.8)
	var e1: Vector3 = st.global_transform * Vector3(-2.4, 1.5, 0.9)
	var l0: Vector3 = st.global_transform * Vector3(0, 1.2, 0.7)
	var dl: Callable = O.dolly(e0, e1, l0, l0, 3.0)
	# Iskun jälkeen (välianimaatio alkaa) ohjaaja päästää kameran: nollavektorit = ei päivitystä, välianimaation kamera jää.
	var cam := func(t: float) -> Array:
		if main.state == "cutscene":
			return [Vector3.ZERO, Vector3.ZERO]
		return dl.call(t)
	return {"lose": true, "settle": false, "cs_bubbles": true, "cam": cam, "fov": 46.0, "warm": 6}
