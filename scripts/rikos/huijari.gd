extends "res://scripts/rikos/osa.gd"
## S3 Huijariostaja (Saloinen): K-Marketin itäpäädyn seinällä on Postin pakettiautomaatti, ja sen vieressä seisoo kerran
## viikossa päiväaikaan aikuinen ostaja, joka tarjoaa liian hyvää hintaa. Hän on aina huijari: joko maksaa väärennetyillä
## seteleillä (vaara_raha paljastuu seuraavalla luukkuostolla, kun Raili tarkistaa rahat) tai nappaa kaman ja juoksee.
## Kumpi on tänään, sen kertoo vihje tervehdyksessä: uudet setelit kuoressa tai "näytä kama ensin, mennään mun autolle".
## Valinnat: myy (huijaus), "Rahat ensin" (huijari lähtee, maine +1, vihje Riskit-sivulle) tai kieltäydy.
## Pelimekaniikkaa: ei aineiden nimiä, määriä eikä ohjeita.
## Automaatin kehys: origo seinän juuressa automaatin keskellä, +Z = automaatin etupuoli (ulos seinästä), +X = katsojan
## oikea, kun katsotaan automaattia edestä. Kaupan itäpääty (world.gd _build_shop: laatikko 30 × 18, julkisivu +Z 9).

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const M := preload("res://scripts/map_data.gd")
const Looks := preload("res://scripts/looks.gd")

const VIIKKOPAIVA := 2  # paikalla päivinä, joille day % 7 == 2 (päivä 2, 9, 16, …)
const AUKI := Vector2(10 * 60, 18 * 60)  # päiväaikaan
const HINTA := 1.5  # × _teini_hinta: liian hyvä hinta (vihje sekin)
const MAINE_TARKISTUS := 1.0
const PUHE_R := 2.6
const NAKYY_R := 160.0
const PAKO_V := 6.0  # m/s, kun huijari juoksee kaman kanssa
const PAKO_T := 3.2  # s, sitten piiloon
## Automaatti kaupan kehyksessä (kaupan keskeltä): itäpääty x = +15, julkisivun kulmasta 5,5 m taaemmas.
const PAIKKA := Vector3(15.0, 0.0, 3.5)
const LEVEYS := 2.4
const KORKEUS := 2.0
const SYVYYS := 0.6
## Huijarin paikka automaatin kehyksessä: etuvasemmalla (julkisivun puolella), ei peitä näyttöä.
const SEISOO := Vector3(-1.75, 0.0, 1.15)

const POSTI := Color(0.97, 0.5, 0.06)  # Postin oranssi (K-Marketin oranssia keltaisempi)
const LUUKKU := Color(0.88, 0.89, 0.9)

## Huijari: nahkatakki, farkut, siistit kengät, viikset ja sänki. Aikuinen, ei uhkaava; ei mopopoikien tuulipukua.
const LOOK := {"shirt": Color(0.3, 0.19, 0.11), "shine": 0.35, "pants": Color(0.2, 0.24, 0.34), "jeans": true, "belt_y": 0.99,
	"belt_col": Color(0.08, 0.06, 0.05), "shoes": Color(0.12, 0.1, 0.09), "shoe": "nauhakenka", "hair": "Hair_SimpleParted",
	"hair_color": Color(0.12, 0.1, 0.09), "beard": true, "height": 1.78, "belly": 0.15, "bulk": 0.1}

const TAPA_VAARA := 0  # väärennetyt setelit
const TAPA_RYOSTO := 1  # nappaa ja juoksee
const VIHJEET := ["Kuoressa uudet setelit, kaikissa sama sarjanumero: väärennöksiä.",
	"\"Näytä kama ensin, mennään mun autolle\": aikoo napata ja juosta."]
const HELLO := [
	"Moi. Kuulin, et sulta saa. Mä maksan hyvin, rahat on valmiina tässä kuoressa.\n(Kuori pullottaa. Setelit näyttää rapeilta, " \
		+ "kuin suoraan painosta.)",
	"Moi. Kuulin, et sulta saa. Näytä kama ensin, mennään vaikka mun autolle tohon parkkikselle.\n(Hän vilkuilee parkkipaikalle, " \
		+ "jossa vanha farmari käy tyhjäkäynnillä ovi auki.)"]

var viikko_ohi := -1  # viikko, jona huijari on jo käynyt ja lähtenyt
var tapa_paiva := -1  # päivä, jolle tapa on arvottu
var tapa := TAPA_VAARA
var vaara_raha := 0.0  # väärennetyt eurot rahoissa (pelaaja ei tiedä)
var vihjeet := 0  # opitut VIHJEET bitteinä
var huijattu := 0
var tunnistettu := 0
var tavattu := false  # huijari on tavattu joskus (Riskit-sivun rivi)

var automaatti: Node3D
var node: Node3D
var _pako_t := 0.0
var _pako_dir := Vector3.ZERO


func _init() -> void:
	talkers = ["huijari"]


func setup() -> void:
	if game.world == null:
		return
	var c := M.w(M.SHOP_BUILDING)
	var p := c + PAIKKA
	p.y = T.h(p.x, p.z)
	automaatti = build_automaatti(game.world)
	automaatti.position = p
	automaatti.rotation.y = PI / 2.0  # +Z kaupan itään (+X)


## Postin pakettiautomaatti (kehys yllä). Kolme moduulia: luukkupylväät reunoilla, keskellä näyttö, lukija ja palautusrako.
static func build_automaatti(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Pakettiautomaatti"
	parent.add_child(root)
	var dark := Color(0.16, 0.16, 0.17)
	var body := StaticBody3D.new()
	root.add_child(body)
	body.add_child(B.box_shape(Vector3(LEVEYS, KORKEUS, SYVYYS), Vector3(0, KORKEUS / 2.0, SYVYYS / 2.0)))
	B.mesh(root, B.boxm(Vector3(LEVEYS - 0.04, 0.1, SYVYYS - 0.06)), Vector3(0, 0.05, SYVYYS / 2.0 - 0.02), dark)  # sokkeli
	B.mesh(root, B.boxm(Vector3(LEVEYS, KORKEUS - 0.1, SYVYYS)), Vector3(0, 0.1 + (KORKEUS - 0.1) / 2.0, SYVYYS / 2.0), POSTI)
	B.mesh(root, B.boxm(Vector3(LEVEYS + 0.08, 0.06, SYVYYS + 0.06)), Vector3(0, KORKEUS + 0.03, SYVYYS / 2.0), POSTI.darkened(0.35))
	B.mesh(root, B.boxm(Vector3(LEVEYS + 0.02, 0.02, SYVYYS + 0.02)), Vector3(0, KORKEUS - 0.01, SYVYYS / 2.0), POSTI.lightened(0.3))
	var zf := SYVYYS + 0.006
	# Luukkupylväät: tumma tausta näkyy saumoina, luukuissa vaalea yläreuna, tumma alareuna, kahva ja lukon valo.
	var rivit := [0.42, 0.42, 0.36, 0.3, 0.3]  # alhaalta ylös (isot luukut alas)
	for sx in [-1.0, 1.0]:
		var cx: float = sx * (LEVEYS / 2.0 - 0.42)
		B.mesh(root, B.boxm(Vector3(0.8, 1.84, 0.012)), Vector3(cx, 0.12 + 0.92, zf), dark)
		var y := 0.12
		for i in rivit.size():
			var hh: float = rivit[i]
			var col := LUUKKU.darkened(0.04 * float(i % 2))
			var dc := Vector3(cx, y + hh / 2.0, zf + 0.012)
			B.mesh(root, B.boxm(Vector3(0.775, hh - 0.022, 0.014)), dc, col)
			B.mesh(root, B.boxm(Vector3(0.775, 0.012, 0.016)), dc + Vector3(0, hh / 2.0 - 0.017, 0.001), col.lightened(0.5))
			B.mesh(root, B.boxm(Vector3(0.775, 0.01, 0.016)), dc + Vector3(0, -hh / 2.0 + 0.016, 0.001), col.darkened(0.25))
			var hx: float = dc.x - sx * 0.33  # kahva keskimoduulin puolella
			B.mesh(root, B.boxm(Vector3(0.018, minf(0.12, hh * 0.4), 0.02)), Vector3(hx, dc.y, dc.z + 0.012), dark)
			B.mesh(root, B.boxm(Vector3(0.016, 0.016, 0.008)), Vector3(hx, dc.y + minf(0.1, hh * 0.32), dc.z + 0.01),
				Color(0.2, 0.75, 0.3))
			y += hh
	# Keskimoduuli: näyttö kehyksineen, viivakoodinlukija, maksupääte ja palautusrako.
	B.mesh(root, B.boxm(Vector3(0.44, 0.36, 0.03)), Vector3(0, 1.38, zf + 0.012), dark)
	var screen := MeshInstance3D.new()
	screen.mesh = B.boxm(Vector3(0.36, 0.28, 0.012))
	screen.material_override = B.unshaded(Color(0.86, 0.93, 0.98))
	screen.position = Vector3(0, 1.38, zf + 0.03)
	root.add_child(screen)
	B.mesh(root, B.boxm(Vector3(0.3, 0.035, 0.004)), Vector3(0, 1.48, zf + 0.037), POSTI)  # näytön otsikkopalkki
	for k in 3:
		B.mesh(root, B.boxm(Vector3(0.24 - k * 0.04, 0.022, 0.004)), Vector3(-0.02 * k, 1.4 - k * 0.05, zf + 0.037),
			Color(0.55, 0.62, 0.7))
	B.mesh(root, B.boxm(Vector3(0.16, 0.1, 0.07)), Vector3(-0.1, 1.08, zf + 0.035), dark, Vector3(-20, 0, 0))  # lukija
	B.mesh(root, B.boxm(Vector3(0.11, 0.05, 0.004)), Vector3(-0.1, 1.08, zf + 0.073), Color(0.85, 0.12, 0.08), Vector3(-20, 0, 0))
	B.mesh(root, B.boxm(Vector3(0.1, 0.14, 0.05)), Vector3(0.14, 1.07, zf + 0.025), Color(0.3, 0.31, 0.33))  # maksupääte
	for r in 3:
		for k in 3:
			B.mesh(root, B.boxm(Vector3(0.022, 0.016, 0.006)), Vector3(0.115 + k * 0.026, 1.04 + r * 0.022, zf + 0.052), LUUKKU)
	B.mesh(root, B.boxm(Vector3(0.5, 0.05, 0.02)), Vector3(0, 0.78, zf + 0.01), Color(0.05, 0.05, 0.05))  # palautusrako
	B.mesh(root, B.boxm(Vector3(0.56, 0.015, 0.05)), Vector3(0, 0.815, zf + 0.025), POSTI.darkened(0.2))  # rakoräystäs
	# Kyltti seinässä automaatin yllä (teksti +Z:aan, ulos seinästä).
	var kyltti := B.sign_plate(root, "Posti", POSTI, Color.WHITE, 0.4, 90, POSTI.darkened(0.45))
	kyltti.position = Vector3(0, KORKEUS + 0.12 + float(kyltti.get_meta("height")) / 2.0, 0.04)
	return root


static func build_model(parent: Node3D) -> Node3D:
	return Looks.make(parent, LOOK)


func _viikko() -> int:
	return floori((game.day - 1) / 7.0)


func paikalla() -> bool:
	return game.day % 7 == VIIKKOPAIVA and viikko_ohi != _viikko() and game._between(game.clock_min, AUKI) \
		and not game._in_vaala


func _seisoo() -> Vector3:
	var p: Vector3 = automaatti.global_transform * SEISOO
	p.y = T.h(p.x, p.z)
	return p


func tick(_e: bool) -> void:
	if automaatti == null or not is_instance_valid(automaatti):
		return
	if _pako_t > 0.0:
		_pakene()
		return
	var on := paikalla()
	if on and tapa_paiva != game.day:
		tapa_paiva = game.day
		tapa = TAPA_VAARA if randf() < 0.5 else TAPA_RYOSTO
	var walk: Node3D = game.player
	var d := Vector2(walk.global_position.x - automaatti.global_position.x,
		walk.global_position.z - automaatti.global_position.z).length()
	var nakyy := on and d < NAKYY_R
	if nakyy and node == null:
		node = build_model(game.world)
		node.global_position = _seisoo()
		node.rotation.y = automaatti.rotation.y  # katse automaatin etusuuntaan
		node.play("Idle", 0.0)
	if node == null:
		return
	if game._talk_box.is_open() and game._talk_who == "huijari":
		return
	node.visible = nakyy
	node.process_mode = Node.PROCESS_MODE_INHERIT if nakyy else Node.PROCESS_MODE_DISABLED
	if not nakyy or game._talk_box.is_open() or game._hint.text != "":
		return
	var to := walk.global_position - node.global_position
	to.y = 0.0
	if to.length() < 10.0:
		node.rotation.y = lerp_angle(node.rotation.y, B.yaw_to(to), 0.08)
	if to.length() < PUHE_R:
		game._talk_hint("huijari", node, game.player != game.bike)


## Kaman kanssa karkuun: juoksee parkkipaikan yli autolleen ja katoaa.
func _pakene() -> void:
	var dt: float = game.get_process_delta_time()
	_pako_t -= dt
	if node == null:
		return
	var p := node.global_position + _pako_dir * PAKO_V * dt
	p.y = T.h(p.x, p.z)
	node.global_position = p
	node.rotation.y = B.yaw_to(_pako_dir)
	if _pako_t <= 0.0:
		node.visible = false
		node.play("Idle", 0.0)
		node.global_position = _seisoo()


# --- Puhe -----------------------------------------------------------------------------------------------------

func hello(who: String) -> String:
	if who != "huijari":
		return ""
	tavattu = true
	if node != null and is_instance_valid(node):
		node.play("Idle_Talking", 0.3)
	return HELLO[tapa]


func _hinta(key: String) -> float:
	return roundf(game._teini_hinta(key) * HINTA)


func options(who: String, o: Array) -> void:
	if who != "huijari":
		return
	var rivit: Array = []
	game._teini_myynti_valinnat(rivit)
	for r in rivit:
		var k: String = String(r.id).trim_prefix("myy_")
		o.append(game._opt("huijari_myy_" + k, "Myy %s (%s €)" % [game._laake_label(k), game._eur(_hinta(k))]))
	o.append(game._opt("huijari_tarkista", "Rahat ensin. Näytä setelit."))
	o.append(game._opt("huijari_ei", "Ei kiinnosta."))


func choose(id: String) -> bool:
	if not id.begins_with("huijari_"):
		return false
	if id.begins_with("huijari_myy_"):
		_myy(id.trim_prefix("huijari_myy_"))
	elif id == "huijari_tarkista":
		_tarkista()
	else:
		viikko_ohi = _viikko()
		game._talk_box.reply("No, ei sitten. Kyllä mä muualta löydän. (Hän lähtee kävelemään parkkipaikalle.)",
			[game._opt("lopeta", "Lopeta")], "Ei maksanut mitään.")
	return true


func _myy(key: String) -> void:
	if game.laake.get(key, 0) <= 0:
		return
	viikko_ohi = _viikko()
	huijattu += 1
	game.hs.myyty(key)
	game.laake[key] -= 1
	if game.laake[key] <= 0:
		game.laake.erase(key)
	if tapa == TAPA_RYOSTO:
		# Nappaa ja juoksee: ei rahaa, kama meni.
		game._talk_box.close()
		Sfx.play("alert", -4.0, 1.2)
		game._show_message("Hän nappaa kaman kädestä ja juoksee parkkipaikan yli autolleen! Rahat jäi saamatta.", 3.5)
		if node != null:
			_pako_dir = (automaatti.global_basis * Vector3(-1.0, 0, 0.35)).normalized()  # julkisivun puolelle parkkipaikan itälaitaan
			_pako_dir.y = 0.0
			_pako_t = PAKO_T
			node.play("Sprint", 0.15)
		game._save_game()
		return
	# Väärennetyt setelit: rahat näyttää oikeilta, paljastuvat seuraavalla luukkuostolla.
	var price := _hinta(key)
	game.money += price
	vaara_raha += price
	Sfx.play("coin", -4.0)
	game._talk_box.reply("Kiitti. Hyvää päivänjatkoa. (Hän ojentaa kuoren, jossa on rapeita uusia seteleitä.)",
		[game._opt("lopeta", "Lopeta")], "+%s €. Rahaa %s €." % [game._eur(price), game._eur(game.money)])
	game._save_game()


func _tarkista() -> void:
	viikko_ohi = _viikko()
	tunnistettu += 1
	vihjeet |= 1 << tapa
	game.maine = clampf(game.maine + MAINE_TARKISTUS, 0.0, 100.0)
	var t := "Tässä, kato vaan. ...Mitä sää niitä numeroita tuijotat? (Kaikissa seteleissä on sama sarjanumero. Hän sulkee " \
		+ "kuoren äkkiä ja lähtee.)"
	if tapa == TAPA_RYOSTO:
		t = "Rahat? Ne on autossa. Näytä nyt ensin se kama... Ei vai? No pidä sitten. (Hän lähtee, ja farmari kaasuttaa pois.)"
	game._talk_box.reply(t, [game._opt("lopeta", "Lopeta")],
		"Huijari paljastui. Maine +%d. Vihje päiväkirjaan (Riskit)." % int(MAINE_TARKISTUS))
	game._save_game()


## Väärä raha paljastuu seuraavassa kaupassa: Raili tarkistaa setelit luukulla.
func on_event(ev: String, _data: Dictionary) -> void:
	if ev != "luukkuosto" or vaara_raha <= 0.0:
		return
	var pois := minf(vaara_raha, maxf(game.money, 0.0))
	game.money -= pois
	vaara_raha = 0.0
	vihjeet |= 1 << TAPA_VAARA
	Sfx.play("alert", -6.0)
	game._show_message(("Raili kääntelee seteleitä luukulla: \"Näissä kaikissa on sama numero! Väärennöksiä.\"\n" +
		"Pakettiautomaatin ostajan rahat oli väärennettyjä: −%s €.") % game._eur(pois), 4.5)


func riskit() -> Dictionary:
	var rivit: Array = []
	for i in VIHJEET.size():
		if vihjeet & (1 << i):
			rivit.append("Huijari: " + VIHJEET[i])
	if tavattu:
		rivit.append("K-Marketin pakettiautomaatilla käy ostaja kerran viikossa päivällä. Hinta liian hyvä.")
	if huijattu > 0 or tunnistettu > 0:
		rivit.append("Huijattu %d kertaa, huijari paljastettu %d kertaa." % [huijattu, tunnistettu])
	if rivit.is_empty():
		return {}
	return {"otsikko": "Huijarit (Saloinen)", "rivit": rivit}


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("rikos_huijari", "tila", {"viikko_ohi": viikko_ohi, "tapa_paiva": tapa_paiva, "tapa": tapa,
		"vaara_raha": roundi(vaara_raha), "vihjeet": vihjeet, "huijattu": huijattu, "tunnistettu": tunnistettu,
		"tavattu": 1 if tavattu else 0})


func load_from(cfg: ConfigFile) -> void:
	var d := _ints(cfg.get_value("rikos_huijari", "tila", {}))
	viikko_ohi = d.get("viikko_ohi", -1)
	tapa_paiva = d.get("tapa_paiva", -1)
	tapa = clampi(d.get("tapa", TAPA_VAARA), TAPA_VAARA, TAPA_RYOSTO)
	vaara_raha = float(d.get("vaara_raha", 0))
	vihjeet = d.get("vihjeet", 0)
	huijattu = d.get("huijattu", 0)
	tunnistettu = d.get("tunnistettu", 0)
	tavattu = d.get("tavattu", 0) == 1
	_pako_t = 0.0


# --- Testi: aja.sh scene riskit --riski=huijari -----------------------------------------------------------------

var _vikoja := 0


func _vika(t: String) -> void:
	_vikoja += 1
	print("TESTI VIKA huijari: " + t)


func _frames(n: int) -> void:
	for i in n:
		if game.state != "cutscene":
			game.clock_min = 12.0 * 60.0
		await game.get_tree().process_frame


func _kuva(suffix: String) -> void:
	var path := "user://riskit_huijari%s.png" % suffix
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7).replace(".png", "_huijari%s.png" % suffix)
	await _frames(4)
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
	print("HUIJARI kuva " + path)


## Lähikuva omalla kameralla automaatin kehyksessä (+Z = etu): from ja to automaatin paikallisina pisteinä.
func _lahikuva(suffix: String, from: Vector3, to: Vector3, fov := 45.0) -> void:
	var prev: Camera3D = game.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	game.add_child(cam)
	var a: Vector3 = automaatti.global_transform * from
	var b: Vector3 = automaatti.global_transform * to
	cam.look_at_from_position(a, b, Vector3.FORWARD if absf((b - a).normalized().y) > 0.9 else Vector3.UP)
	cam.fov = fov
	cam.make_current()
	await _kuva(suffix)
	cam.queue_free()
	if prev != null:
		prev.make_current()


func _tila(t: String) -> void:
	print("HUIJARI %s: päivä %d paikalla %s tapa %d näkyy %s, laake %s, rahat %.0f, väärää %.0f, maine %.0f, vihjeet %d" % [t,
		game.day, paikalla(), tapa, node != null and node.visible, game.laake, game.money, vaara_raha, game.maine, vihjeet])


func _alusta(t: int) -> void:
	viikko_ohi = -1
	tapa_paiva = game.day
	tapa = t
	game.laake = {"opiaatti": 2}
	game.money = 100.0
	game.maine = 50.0
	_pako_t = 0.0
	if node != null:
		node.global_position = _seisoo()
		node.rotation.y = automaatti.rotation.y


func _puhu() -> void:
	game._talk_open("huijari", node)
	await _frames(3)


func testi(_arg: String) -> void:
	vaara_raha = 0.0
	vihjeet = 0
	huijattu = 0
	tunnistettu = 0
	tavattu = false
	if automaatti == null:
		_vika("automaattia ei rakennettu")
		return
	game.day = 2 + 7  # viikkopäivä (day % 7 == VIIKKOPAIVA)
	_alusta(TAPA_VAARA)
	# Automaatti seinässä: kaupan itäpääty x = +15 kaupan keskeltä.
	var c := M.w(M.SHOP_BUILDING)
	var ap := automaatti.global_position
	var front: Vector3 = automaatti.global_basis.z
	print("HUIJARI automaatti %s, seinästä %.3f m, maa %.2f (kauppa y 0), etu %s" % [ap.snapped(Vector3.ONE * 0.01),
		ap.x - (c.x + 15.0), ap.y, front.snapped(Vector3.ONE * 0.01)])
	if absf(ap.x - (c.x + 15.0)) > 0.01 or front.x < 0.99:
		_vika("automaatti ei ole itäpäädyn seinässä ulospäin")
	# Pelaaja jalan automaatin eteen 6 m: huijari näkyy, pelikameran kuva.
	var seisoo := _seisoo()
	game._place_on_foot(automaatti.global_transform * Vector3(-3.5, 0.3, 6.5))
	var kohti: Vector3 = automaatti.global_transform * Vector3(-0.6, 0, 0) - game.player.global_position
	game.player.rotation.y = B.yaw_to(Vector3(kohti.x, 0, kohti.z))
	await _frames(20)
	_tila("saapuminen")
	if node == null or not node.visible:
		_vika("huijari ei näy viikkopäivänä")
		return
	await _kuva("_pelikamera")
	# Läpimenot: huijarin ympäriltä ei törmäysmuotoja (automaatti, seinä); etäisyys automaatin etupinnasta.
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.3
	sh.height = 1.7
	q.shape = sh
	q.transform = Transform3D(Basis(), seisoo + Vector3(0, 0.95, 0))
	var osumat := space.intersect_shape(q, 4).filter(func(r: Dictionary) -> bool: return r.collider is StaticBody3D)
	var lp: Vector3 = automaatti.global_transform.affine_inverse() * node.global_position
	print("HUIJARI paikka %s, automaatin kehyksessä %s, etupinnasta %.2f m, sivusta %.2f m, esteitä %d, maa %.3f vs jalat %.3f" % [
		seisoo.snapped(Vector3.ONE * 0.01), lp.snapped(Vector3.ONE * 0.01), lp.z - SYVYYS, absf(lp.x) - LEVEYS / 2.0, osumat.size(),
		T.h(seisoo.x, seisoo.z), node.global_position.y])
	if not osumat.is_empty():
		_vika("huijari törmäysmuodon sisällä: %s" % [osumat.map(func(r: Dictionary) -> String: return str(r.collider.name))])
	# Lähikuvat: automaatti edestä, päädystä ja ylhäältä, huijari edestä.
	await _lahikuva("_automaatti_edesta", Vector3(0.3, 1.3, 4.2), Vector3(0, 1.1, 0.3))
	await _lahikuva("_automaatti_paadysta", Vector3(3.6, 1.4, 1.6), Vector3(0, 1.1, 0.3))
	await _lahikuva("_automaatti_ylha", Vector3(-0.5, 5.5, 2.2), Vector3(-0.5, 0.0, 0.6))
	await _lahikuva("_naytto", Vector3(0.0, 1.35, 1.3), Vector3(0, 1.2, 0.6), 40.0)
	# Puhevihje 2 m:n päästä.
	var fwd: Vector3 = -node.global_basis.z
	fwd.y = 0.0
	game._place_on_foot(node.global_position + fwd.normalized() * 2.0 + Vector3(0, 0.3, 0))
	await _frames(20)
	print("HUIJARI puhevihje näkyy %s, %.1f m" % [game._talk_prompt.visible, game.player.global_position.distance_to(node.global_position)])
	if not game._talk_prompt.visible:
		_vika("puhevihje ei näy huijarin edessä")
	await _lahikuva("_huijari", Vector3(-1.75, 1.5, 3.8), Vector3(-1.4, 1.1, 0.8))
	# Väärennetyt setelit: myynti, paljastus seuraavalla luukkuostolla.
	await _puhu()
	var h: String = hello("huijari")
	var ids: Array = game._talk_options("huijari").map(func(o: Dictionary) -> String: return o.id)
	print("HUIJARI valinnat %s, tervehdys '%s'" % [ids, h])
	if not "huijari_myy_opiaatti" in ids or not "huijari_tarkista" in ids or not "huijari_ei" in ids or "myy_opiaatti" in ids:
		_vika("valinnat %s" % [ids])
	if not "kuoressa" in h:
		_vika("väärän rahan vihje puuttuu tervehdyksestä")
	await _kuva("_keskustelu")
	game._talk_choose("huijari_myy_opiaatti")
	_tila("myynti, väärä raha")
	var hinta := _hinta("opiaatti")
	if game.money != 100.0 + hinta or vaara_raha != hinta or game.laake.get("opiaatti", 0) != 1 or paikalla():
		_vika("väärä raha: rahat %.0f väärää %.0f" % [game.money, vaara_raha])
	game._talk_box.close()
	await _frames(5)
	if node.visible:
		_vika("huijari jäi paikalle myynnin jälkeen")
	var tallessa := [viikko_ohi, roundi(vaara_raha), vihjeet, huijattu]
	game._save_game()
	vaara_raha = 0.0
	viikko_ohi = -1
	huijattu = 0
	game._load_game()
	print("HUIJARI tallennus %s -> %s" % [tallessa, [viikko_ohi, roundi(vaara_raha), vihjeet, huijattu]])
	if [viikko_ohi, roundi(vaara_raha), vihjeet, huijattu] != tallessa:
		_vika("tallennus/lataus")
	var m0: float = game.money
	game._hs_ostettu()  # luukkuosto: Raili tarkistaa setelit
	print("HUIJARI luukkuosto: rahat %.0f -> %.0f, väärää %.0f, vihjeet %d, viesti '%s'" % [m0, game.money, vaara_raha, vihjeet,
		game._msg.text if "_msg" in game else "?"])
	if game.money != m0 - hinta or vaara_raha != 0.0 or not vihjeet & (1 << TAPA_VAARA):
		_vika("väärä raha ei paljastunut luukulla")
	# Nappaa ja juoksee.
	game.day = 2 + 14
	_alusta(TAPA_RYOSTO)
	await _frames(5)
	await _puhu()
	h = hello("huijari")
	if not "autolle" in h:
		_vika("ryöstön vihje puuttuu tervehdyksestä")
	game._talk_choose("huijari_myy_opiaatti")
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var kp := "user://riskit_huijari_pako.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			kp = a.substr(7).replace(".png", "_huijari_pako.png")
	game.get_viewport().get_texture().get_image().save_png(kp)  # heti: hitaalla koneella juoksu on ohi muutamassa ruudussa
	print("HUIJARI kuva " + kp)
	_tila("myynti, ryöstö")
	if game.money != 100.0 or game.laake.get("opiaatti", 0) != 1 or _pako_t <= 0.0:
		_vika("ryöstö: rahat %.0f laake %s" % [game.money, game.laake])
	for i in 200:
		if _pako_t <= 0.0:
			break
		await _frames(1)
	await _frames(3)
	print("HUIJARI pako ohi: näkyy %s" % node.visible)
	if node.visible:
		_vika("juoksija ei kadonnut")
	# Rahat ensin: huijari lähtee, maine +1, vihje.
	game.day = 2 + 21
	_alusta(TAPA_RYOSTO)
	vihjeet = 0
	await _frames(5)
	await _puhu()
	game._talk_choose("huijari_tarkista")
	_tila("rahat ensin")
	if game.maine != 51.0 or not vihjeet & (1 << TAPA_RYOSTO) or paikalla() or game.money != 100.0:
		_vika("tarkistus: maine %.0f vihjeet %d" % [game.maine, vihjeet])
	game._talk_box.close()
	# Kieltäytyminen ei maksa.
	game.day = 2 + 28
	_alusta(TAPA_VAARA)
	await _frames(5)
	await _puhu()
	game._talk_choose("huijari_ei")
	_tila("kieltäytyminen")
	if game.maine != 50.0 or game.money != 100.0 or game.laake.get("opiaatti", 0) != 2 or paikalla():
		_vika("kieltäytyminen muutti tilaa")
	game._talk_box.close()
	# Muuna päivänä ei paikalla.
	game.day = 3 + 35
	viikko_ohi = -1
	await _frames(5)
	_tila("muu päivä")
	if paikalla() or node.visible:
		_vika("huijari paikalla vääränä päivänä")
	# Riskit-sivu.
	var rs: Array = game.journal_data().get("riskit", [])
	print("HUIJARI riskit %s" % [rs.filter(func(d: Dictionary) -> bool: return str(d.otsikko).begins_with("Huijarit"))])
	game._journal.open_at("riskit")
	await _frames(10)
	await _kuva("_riskit")
	game._journal.toggle()
	await _frames(4)
	print("HUIJARI testi valmis, %d vikaa" % _vikoja)
