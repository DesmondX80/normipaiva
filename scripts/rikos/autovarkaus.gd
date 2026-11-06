extends "res://scripts/rikos/osa.gd"
## F: ohiajavan auton kaappaus ja GTA-tyylinen tähtijahti (käyttäjän toive). Pelimekaniikkaa: pelkkä valinta, ei keinoja.
## Liikenneauto pysähtyy jalankulkijan eteen (traffic_car.gd LOOK/BRAKE). Kun se seisoo ja pelaaja on jalan kuljettajan
## oven vieressä (vasen kylki, -X; -Z = keula), E kaappaa auton: kuski hyppää ulos huutaen ja soittaa, ja tähtiä tulee 1.
## Pelaajan pyöräsolmu (Saloinen, player_bike.gd set_car) tai mopo (Vaala, mopo.gd set_car) muuttuu autoksi, joten
## kaikki "player == bike" -vahdit (keskustelu, ovet, tanssi) toimivat sellaisinaan. Autosta noustaan F:llä (main.gd
## _toggle_mount / _mopo_mount_logic kutsuu nouse()): auto jää hylätyksi propiksi päivän loppuun, ja oma pyörä tai mopo
## palaa paikkaan, josta se kaapattaessa oli.
## Kaappaus alkaa heti viidellä tähdellä (superäkäinen jahtaaja); tähdet putoavat pakomatkalla. Lisäksi: +1 joka TAHTI_AJO s ajoa ja +1 kovasta törmäyksestä (seinä, puu tai toinen auto). Jahtaaja: Saloisissa
## Päivi (wife_car.gd heat_mult 1,0–1,5, ei parkissa, ignore_safe ≥ 4 tähdellä) ja 4–5 tähdellä myös poliisiauto
## (police_car.gd start_chase); Vaalassa konstaapeli Roivainen (roivainen_auto.gd). Pako: jahtaaja ei näe pelaajaa
## tähdet × PIILO_PER_TAHTI s, minkä jälkeen tähti putoaa PUDOTUS s välein. Kuminauha ≥ 4 tähdellä: yli KUMI_R m
## päässä oleva jahtaaja siirtyy näkymättömiin pelaajan lähelle. Kiinni: Päivi -> _lose (motkotus),
## Roivainen tai poliisi -> _rikos_loppu("pidatys"). Ei tallenneta: lataus ja uusi päivä nollaavat jahdin.

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const TrafficCar := preload("res://scripts/traffic_car.gd")
const WifeCar := preload("res://scripts/wife_car.gd")
const PoliceCar := preload("res://scripts/police_car.gd")
const RoivainenAuto := preload("res://scripts/rikos/roivainen_auto.gd")
const TahdetHud := preload("res://scripts/rikos/tahdet_hud.gd")

const OVI := Vector3(-1.25, 0.0, -0.1)  # kuljettajan ovi auton kehyksessä (vasen kylki, etuovi; Vehicles.car kahva z -0,1)
const OVI_VAN := Vector3(-1.3, 0.0, -1.3)  # pakettiauton (Hiace) ohjaamon ovi z -1,84…-0,76, keula -2,3
const OVI_R := 2.5
const KYLKI := Vector2(2.4, 2.6)  # kaapattava, kun pelaaja on auton kehyksessä tämän laatikon (x sivulle, z pituussuuntaan) sisällä
const KAAPPAUS_NOPEUS := 2.0  # m/s: tätä hitaampi auto kaapataan (pysähtyvä tai lähtevä auto ei karkaa käsistä)
const KIINNI_AUTOSSA := 6.0  # m: Päivi saa kiinni, kun autojen keskipisteet ovat näin lähellä (autot ovat kolme metriä leveitä, joten 3,3 m ei koskaan toteudu)
const PIDA_R := 9.0  # pysähtynyt auto odottaa, kun pelaaja on näin lähellä sitä (kuski jähmettyy)
const MAX_TAHDET := 5
const TAHTI_AJO := 25.0  # s ajoa jahdin aikana = +1 tähti
const TORMAYS_VALI := 1.5  # s: yksi kova törmäys kerrallaan
const KOLARI_NOPEUS := 8.0  # m/s suhteellinen nopeus liikenneautoon = kova törmäys
const NAKO_R := 45.0  # jahtaaja näkee näin kauas (näköyhteys)
const PIILO_PER_TAHTI := 4.0
const PUDOTUS := 8.0
const KUMI_R := 120.0
const KUMI_VALI := 6.0
const KUMI_ETAISYYS := Vector2(60.0, 100.0)  # siirto tieverkon solmuun tältä etäisyydeltä, kameran taakse
const POLIISI_TAHDET := 4
const HEAT := [1.0, 1.0, 1.125, 1.25, 1.375, 1.5]  # Päivin ja Roivaisen nopeuskerroin tähtien mukaan
const KUSKI_T := 9.0  # s kuski näkyy (juoksee ja soittaa)
const KUSKI_LOOK := {"shirt": Color(0.35, 0.45, 0.6), "pants": Color(0.2, 0.2, 0.25), "shoes": Color(0.3, 0.2, 0.12),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.45, 0.35, 0.25), "height": 1.78, "belly": 0.5}

var tahdet := 0
var autossa := false
var paikka := ""  # "saloinen" tai "vaala"
var kaappaukset := 0  # tänään (Riskit-sivu)
var pakoja := 0  # tänään onnistuneet pakomatkat

var _auto: CharacterBody3D  # pelaajan pyörä tai mopo autotilassa
var _koti := Transform3D()  # mopon paikka ennen kaappausta (Vaalan kehys); pyörällä bike.car_home
var _tallissa := false
var _vari := Color.WHITE
var _van := false
var _malli := "saab"
var _ajo_t := 0.0
var _piilo_t := 0.0
var _pudotus_t := 0.0
var _tormays_t := 0.0
var _kumi_t := 0.0
var _hylatyt: Array[Node3D] = []
var _kuski: Node3D
var _kuski_kupla: Label3D
var _kuski_t := 0.0
var _kuski_dir := Vector3.ZERO
var _pidetty: Node3D  # liikenneauto, joka odottaa pelaajaa (ei lähde ovelta)
var _roivainen: CharacterBody3D
var _poliisi: CharacterBody3D
var _hud: CanvasLayer
var _paivi_kytketty: CharacterBody3D  # Päivin auto, jonka caught-signaali ohjataan tähän osaan jahdin ajaksi
var nakyy := false  # jahtaaja näkee pelaajan (testi ja HUD)
var _delta_ms := 0


func setup() -> void:
	_hud = TahdetHud.new()
	_hud.game = game
	game.add_child(_hud)


# --- Kaappaus --------------------------------------------------------------------------------------------------

func _vaala() -> bool:
	return game._in_vaala and game.mopo_trip != null and game.mopo_trip.active


func _jalan() -> bool:
	if _vaala():
		return game.mopo_trip.on_foot != null
	return game.player == game.walker_out


func _liikenne() -> Array:
	if _vaala():
		return game.mopo_trip._cars.filter(func(c: Node) -> bool: return c.visible)
	if game._hazards == null:
		return []
	return game._hazards.get_children().filter(func(c: Node) -> bool: return c is TrafficCar)


## Pysähtynyt liikenneauto, jonka kuljettajan oven vieressä pelaaja seisoo; null = ei mitään.
func _ovi(c: Node3D) -> Vector3:
	return OVI_VAN if c.van else OVI


func kaapattava() -> Node3D:
	if autossa or not _jalan() or game.state != "ulkona" or game.cutscene.busy:
		return null
	if not _vaala() and not game._thief.is_empty():
		return null  # teini ajaa pyörällä: pyöräsolmu on varkaalla
	var p: Vector3 = game.player.global_position
	var best: Node3D = null
	var best_d := INF
	for c in _liikenne():
		if absf(c._speed) >= KAAPPAUS_NOPEUS:
			continue
		# Mikä tahansa kylki käy (ei vain kuljettajan ovi): "aina voi varastaa", kun auto seisoo vierellä.
		var q: Vector3 = c.global_transform.affine_inverse() * p
		var door: Vector3 = c.global_transform * _ovi(c)
		var d := Vector2(p.x - door.x, p.z - door.z).length()
		if (absf(q.x) < KYLKI.x and absf(q.z) < KYLKI.y) or d < OVI_R:
			if d < best_d:
				best_d = d
				best = c
	return best


func tick(e: bool) -> void:
	var delta: float = game.get_process_delta_time()
	_kuski_tick(delta)
	if game.state != "ulkona":
		return
	if autossa and _jalan():
		# Auto jäi päälle, vaikka pelaaja on jalan (jokin muu polku nosti ulos ilman nouse()-kutsua): siivotaan, jottei
		# autossa-lippu lukitse kaikkia seuraavia kaappauksia.
		nouse(true, false)
	_pida_auto()
	var c := kaapattava()
	# Vain toinen [E]-vihje (ovi, juttelu) vie vuoron: esim. [F] Nouse pyörän selkään pyörän luona ei saa estää kaappausta.
	if c != null and not game._hint.text.contains("[E]") and not game._talk_box.is_open():
		game._hint.text = "[E] Kaappaa auto"
		if e:
			kaappaa(c)
			return
	if autossa:
		_kolarit(delta)
		if tahdet > 0 and _kuuma() and absf(_auto.speed) > 3.0:  # ajo jahtaajan tietäessä (ei piilossa seisten)
			_ajo_t += delta
			if _ajo_t >= TAHTI_AJO:
				_ajo_t = 0.0
				_lisaa(1, "")
	if tahdet > 0:
		_jahti(delta)
	_hud.tahdet = tahdet
	_hud.nakyy = nakyy
	_hud.otsikko = ("ROIVAINEN" if paikka == "vaala" else "PÄIVI") if tahdet > 0 else ""


## Pysähtynyt auto odottaa, kun pelaaja on lähellä kuljettajan ovea (muuten se lähtisi heti, kun pelaaja ei ole
## enää keulan edessä).
func _pida_auto() -> void:
	if autossa or not _jalan():
		_pidetty = null
		return
	var p: Vector3 = game.player.global_position
	if _pidetty != null and is_instance_valid(_pidetty):
		if _lahella(_pidetty, p):
			_pidetty._speed = 0.0
			return
		_pidetty = null
	for c in _liikenne():
		if absf(c._speed) < 1.0 and _lahella(c, p):
			_pidetty = c
			return


## Pelaaja on auton ovella tai sen vieressä (PIDA_R): auto ei lähde.
func _lahella(c: Node3D, p: Vector3) -> bool:
	var door: Vector3 = c.global_transform * _ovi(c)
	return Vector2(p.x - door.x, p.z - door.z).length() < PIDA_R or c.global_position.distance_to(p) < PIDA_R


func kaappaa(c: Node3D) -> void:
	_vari = c.color
	_van = c.van
	_malli = c.malli if c.malli != "" else "saab"
	var tr: Transform3D = c.global_transform
	_ovi_kuski = _ovi(c)
	_kuski_ulos(tr)
	kaappaukset += 1
	_pidetty = null
	if _vaala():
		paikka = "vaala"
		var mt: Node3D = game.mopo_trip
		var mp: CharacterBody3D = mt.mopo
		_koti = mp.transform
		var lt: Transform3D = mt.global_transform.affine_inverse() * tr
		mt._respawn_car(c)  # liikenneauto siirtyy muualle tielle (sama solmu jatkaa liikenteenä)
		mp.transform = Transform3D(lt.basis, lt.origin + Vector3(0, 0.1, 0))
		mp.velocity = Vector3.ZERO
		mp.set_car(true, _vari, _van, _malli)
		if not mp.car_crashed.is_connected(_on_kolari):
			mp.car_crashed.connect(_on_kolari)
		game._mopo_remount()
		_auto = mp
	else:
		paikka = "saloinen"
		var bike: CharacterBody3D = game.bike
		_tallissa = game.bike_in_garage
		if _tallissa:
			game._store_bike(false)
		bike.car_home = bike.global_transform
		_siirra_pois(c)
		bike.global_transform = Transform3D(tr.basis, tr.origin + Vector3(0, 0.1, 0))
		bike.velocity = Vector3.ZERO
		bike.set_car(true, _vari, _van, _malli)
		if not bike.crashed.is_connected(_on_kolari):
			bike.crashed.connect(_on_kolari)
		var w: CharacterBody3D = game.walker_out
		w.visible = false
		w.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		bike.set_rider_visible(true)
		bike.controls_enabled = true
		game._set_avatar(bike)
		_auto = bike
	autossa = true
	_ajo_t = 0.0
	Sfx.play("horn", 0.0, 0.9)
	_aloita_jahti()


## Saloisten liikenneauto siirretään kauas tieverkkoon (kuten main.gd _traffic_tick), joten liikennettä on yhtä paljon.
func _siirra_pois(c: Node3D) -> void:
	var w: Node3D = game.world
	var p: Vector3 = game.player.global_position
	var far: Array[int] = []
	for i in w.graph_nodes.size():
		var d: float = w.graph_nodes[i].distance_to(p)
		if d > 150.0 and d < 260.0 and not w.graph_adj[i].is_empty():
			far.append(i)
	if far.is_empty():
		c.queue_free()
		return
	c.setup_graph(w.graph_nodes, w.graph_adj, far.pick_random(), w.graph_fast)


## Autosta jalan (F): auto jää hylätyksi propiksi, oma pyörä tai mopo palaa paikalleen. Jahti jatkuu jalan.
## pakko = vauhdista välittämättä (kiinnijäänti, uusi päivä); jalkaan = false: main.gd on jo siirtänyt pelaajan.
func nouse(pakko := false, jalkaan := true) -> void:
	if not autossa or _auto == null:
		return
	if not pakko and absf(_auto.speed) > 3.0:
		game._show_message("Hidasta ensin!", 1.2)
		return
	autossa = false
	var tr: Transform3D = _auto.global_transform
	var ulos: Vector3 = tr * Vector3(-1.7, 0.3, -0.1)
	if paikka == "vaala":
		var mt: Node3D = game.mopo_trip
		var lt: Transform3D = mt.global_transform.affine_inverse() * tr
		_hylkaa(mt, lt, Callable(mt.vaala, "h"))
		_auto.set_car(false)
		_auto.transform = _koti
		_auto.velocity = Vector3.ZERO
		if jalkaan:
			_jalkaan_vaala(ulos, tr.basis.get_euler().y)
	else:
		_hylkaa(game, tr, func(x: float, z: float) -> float: return T.h(x, z))
		var bike: CharacterBody3D = game.bike
		bike.set_car(false)
		bike.global_transform = bike.car_home
		bike.velocity = Vector3.ZERO
		if jalkaan:
			game._place_on_foot(ulos)
			game.walker_out.rotation.y = tr.basis.get_euler().y  # auton suuntaan: kamera ei jää auton sisään
		else:
			bike.controls_enabled = false
			bike.set_rider_visible(false)
		if _tallissa:
			game._store_bike(true)
		_tallissa = false
	_auto = null
	if tahdet > 0 and not pakko:
		game._show_message("Jalan karkuun! %s on yhä perässä." % ("Roivainen" if paikka == "vaala" else "Päivi"), 2.5)


func _jalkaan_vaala(at: Vector3, yaw: float) -> void:
	var w: CharacterBody3D = game.walker_out
	w.global_position = at
	w.global_rotation.y = yaw
	w.velocity = Vector3.ZERO
	w.speed = 0.0
	w.visible = true
	w.process_mode = Node.PROCESS_MODE_INHERIT
	w.controls_enabled = true
	w.set_carrying(game.beers > 0)
	game.mopo_trip.set_on_foot(w)
	game._mopo_follow(w)
	game._mopo_dry = w.global_position


## Hylätty auto: staattinen kappale samalla värillä ja muodolla, maassa kiinni.
func _hylkaa(parent: Node3D, tr: Transform3D, ground: Callable) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	var p := tr.origin
	body.transform = Transform3D(Basis(Vector3.UP, tr.basis.get_euler().y), Vector3(p.x, ground.call(p.x, p.z), p.z))
	body.add_child(B.box_shape(Vector3(1.8, 1.4, 4.2), Vector3(0, 0.85, 0)))
	if _van:
		Vehicles.van(body, _vari)
	else:
		Vehicles.henkiloauto(body, _malli, _vari)
	body.set_meta("hylatty_auto", true)
	_hylatyt.append(body)


# --- Kuski ----------------------------------------------------------------------------------------------------

const KUSKI_HUUDOT := ["HEI! MUN AUTO!", "Haloo?! Mun auto vietiin! Joo, ihan just!"]


var _ovi_kuski := OVI


func _kuski_ulos(tr: Transform3D) -> void:
	_poista_kuski()
	var parent: Node3D = game.mopo_trip if _vaala() else game
	_kuski = Looks.make(parent, KUSKI_LOOK)
	var door: Vector3 = tr * (_ovi_kuski + Vector3(-0.15, 0, 0))
	_kuski_dir = (tr.basis * Vector3(-1, 0, 0.6)).normalized()
	_kuski_dir.y = 0.0
	_kuski.global_position = door
	_kuski.rotation.y = B.yaw_to(_kuski_dir)
	_kuski.play("Sprint", 0.1)
	_kuski_kupla = B.bubble(_kuski, Vector3(0, 2.05, 0), Color(1.0, 0.95, 0.85))
	_kuski_kupla.text = KUSKI_HUUDOT[0]
	_kuski_t = KUSKI_T
	_maahan(_kuski)


func _kuski_tick(delta: float) -> void:
	if _kuski == null or not is_instance_valid(_kuski):
		return
	_kuski_t -= delta
	if _kuski_t <= 0.0:
		_poista_kuski()
		return
	if _kuski_t > KUSKI_T - 3.0:
		_kuski.global_position += _kuski_dir * 4.5 * delta  # juoksee kauemmas
		_maahan(_kuski)
	elif _kuski_kupla.text == KUSKI_HUUDOT[0]:
		_kuski_kupla.text = KUSKI_HUUDOT[1]
		_kuski.play("Idle_Talking", 0.3)
		var to: Vector3 = game.player.global_position - _kuski.global_position
		_kuski.rotation.y = B.yaw_to(Vector3(to.x, 0, to.z))


func _maahan(n: Node3D) -> void:
	if _vaala():
		var l: Vector3 = n.position
		n.position.y = game.mopo_trip.vaala.h(l.x, l.z)
	else:
		n.global_position.y = T.h(n.global_position.x, n.global_position.z)


func _poista_kuski() -> void:
	if _kuski != null and is_instance_valid(_kuski):
		_kuski.queue_free()
	_kuski = null
	_kuski_kupla = null


# --- Tähdet ja jahti -------------------------------------------------------------------------------------------

func _lisaa(n: int, syy: String) -> void:
	var ennen := tahdet
	tahdet = clampi(tahdet + n, 0, MAX_TAHDET)
	_piilo_t = 0.0
	_pudotus_t = 0.0
	if tahdet > ennen:
		Sfx.play("alert", -2.0, 0.9 + 0.05 * tahdet)
		if syy != "":
			game._show_message(syy, 2.0)
	_paivita_jahtaaja()


func _aloita_jahti() -> void:
	var kuka := "Roivainen" if paikka == "vaala" else "Päivi"
	tahdet = MAX_TAHDET  # superäkäinen jahtaaja: viisi tähteä heti (Päivi 1,5 × nopeudella, poliisi mukaan; Roivainen 1,5 ×)
	_piilo_t = 0.0
	_pudotus_t = 0.0
	_kumi_t = 0.0
	if paikka == "vaala":
		_luo_roivainen()
		game._show_message("AUTO KAAPATTU! Kuski soitti poliisille.\nRoivainen on SUPERÄKÄINEN ja lähti perään viidellä tähdellä. Pakoon!", 3.5)
	else:
		game._show_message("AUTO KAAPATTU! Kuski soitti, ja koko kylä soitti Päiville.\n%s on SUPERÄKÄINEN ja lähti perään viidellä tähdellä. Pakoon!" % kuka, 3.5)
	_paivita_jahtaaja()


## Kova törmäys (pelaajan auto päin seinää): +1 tähti.
func _on_kolari() -> void:
	if not autossa or tahdet <= 0 or _tormays_t > 0.0:
		return
	_tormays_t = TORMAYS_VALI
	_lisaa(1, "RYSÄYS! Lisää tähtiä.")


## Liikenneautot: ne eivät ole fysiikassa pelaajan kanssa (collision_layer 0), joten kolari tarkistetaan tässä.
## Päällekkäin = liikenneauto pysähtyy ja pelaajan vauhti katkeaa; kova vauhtiero = kova törmäys.
func _kolarit(delta: float) -> void:
	_tormays_t = maxf(0.0, _tormays_t - delta)
	if _auto == null:
		return
	var inv: Transform3D = _auto.global_transform.affine_inverse()
	var fwd: Vector3 = -_auto.global_transform.basis.z
	for c in _liikenne():
		var l: Vector3 = inv * c.global_position
		if absf(l.x) > 1.9 or absf(l.z) > 4.3:
			continue
		var cf: Vector3 = -c.global_transform.basis.z
		var rel: float = (fwd * _auto.speed - cf * c._speed).length()
		c._speed = 0.0
		if rel > KOLARI_NOPEUS and absf(_auto.speed) > 4.0:  # pelaaja ajoi päin (ei, kun liikenne tönäisee seisovaa)
			Sfx.play("punch_heavy", 0.0, 0.6)
			Sfx.play("glass", -6.0, 0.9)
			_auto.speed *= 0.3
			if tahdet > 0 and _tormays_t <= 0.0:
				_tormays_t = TORMAYS_VALI
				_lisaa(1, "KOLARI! Lisää tähtiä.")
		elif l.z * signf(_auto.speed) < 0.0:
			_auto.speed = clampf(_auto.speed, -2.0, 2.0)  # puskee toista autoa: ei ajeta läpi


## Jahtaajat (Päivi tai Roivainen, 4–5 tähdellä myös poliisi) seuraavat tähtiä: vauhti, näkyvyys, kuminauha ja pako.
func _jahti(delta: float) -> void:
	var ajajat := _jahtaajat()
	nakyy = false
	for a in ajajat:
		if _nakee(a):
			nakyy = true
	if nakyy:
		_piilo_t = 0.0
		_pudotus_t = 0.0
	else:
		_piilo_t += delta
		if _piilo_t >= tahdet * PIILO_PER_TAHTI:
			_pudotus_t += delta
			if _pudotus_t >= PUDOTUS:
				_pudotus_t = 0.0
				tahdet -= 1
				if tahdet <= 0:
					_lopeta_jahti(true)
					return
	_paivita_jahtaaja()
	_kumi_t -= delta
	if tahdet >= POLIISI_TAHDET and _kumi_t <= 0.0:
		for a in ajajat:
			if a.global_position.distance_to(game.player.global_position) > KUMI_R:
				_kumilla(a)
				_kumi_t = KUMI_VALI


func _jahtaajat() -> Array:
	var out: Array = []
	if paikka == "vaala":
		if _roivainen != null and is_instance_valid(_roivainen):
			out.append(_roivainen)
	else:
		if game.wife != null and is_instance_valid(game.wife):
			out.append(game.wife)
		if _poliisi != null and is_instance_valid(_poliisi):
			out.append(_poliisi)
	return out


func _nakee(a: Node3D) -> bool:
	var p: Vector3 = game.player.global_position
	if a.global_position.distance_to(p) > NAKO_R:
		return false
	var ex: Array[RID] = [(a as CollisionObject3D).get_rid(), (game.player as CollisionObject3D).get_rid()]
	return B.line_of_sight(a, a.global_position + Vector3.UP * 1.3, p + Vector3.UP, ex)


## Kuuma vaihe (ei vielä piilossa tarpeeksi kauan): jahtaaja tietää, missä pelaaja on (kuten radiolla).
func _kuuma() -> bool:
	return tahdet > 0 and _piilo_t < tahdet * PIILO_PER_TAHTI


func _paivita_jahtaaja() -> void:
	var heat: float = HEAT[clampi(tahdet, 0, MAX_TAHDET)]
	if paikka == "vaala":
		if _roivainen != null and is_instance_valid(_roivainen):
			_roivainen.heat_mult = heat
			_roivainen.active = _kuuma() or nakyy
			_roivainen.target = game.player
		return
	var w: CharacterBody3D = game.wife
	if w == null or not is_instance_valid(w):
		return
	_kytke_paivi(w)
	w.heat_mult = heat
	w.ignore_safe = tahdet >= POLIISI_TAHDET
	w.catch_dist = KIINNI_AUTOSSA if autossa else WifeCar.CATCH_DIST
	w.parked = false
	w.grace = 0.0
	w.visible = true
	w.process_mode = Node.PROCESS_MODE_INHERIT
	w.alerted = _kuuma()
	if w.alerted and w.mode != "chase":
		w.mode = "chase"
	if tahdet >= POLIISI_TAHDET and (_poliisi == null or not is_instance_valid(_poliisi)):
		_luo_poliisi()
	if _poliisi != null and is_instance_valid(_poliisi) and _poliisi.is_leaving() and _kuuma():
		_poliisi.queue_free()  # luovutti, mutta jahti kuumenee taas: uusi partio radiolla perään
		_poliisi = null
	if _poliisi != null and is_instance_valid(_poliisi):
		_poliisi.heat_mult = heat
		_poliisi.ignore_safe = true
		_poliisi.target = game.player
		if _kuuma() and not _poliisi.is_leaving():
			_poliisi._tip = PoliceCar.TIP_TIME  # radio kertoo paikan, kunnes pelaaja on ollut piilossa
			_poliisi.alerted = true
			_poliisi.mode = "chase"


## Päivin caught ohjataan jahdin ajaksi tähän osaan (ei kotihommien hyvitystä varastetulla autolla).
func _kytke_paivi(w: CharacterBody3D) -> void:
	if _paivi_kytketty == w:
		return
	_irrota_paivi()
	if w.caught.is_connected(game._on_wife_caught):
		w.caught.disconnect(game._on_wife_caught)
	w.caught.connect(_on_kiinni_paivi)
	_paivi_kytketty = w


func _irrota_paivi() -> void:
	var w := _paivi_kytketty
	_paivi_kytketty = null
	if w == null or not is_instance_valid(w):
		return
	if w.caught.is_connected(_on_kiinni_paivi):
		w.caught.disconnect(_on_kiinni_paivi)
	if not w.caught.is_connected(game._on_wife_caught):
		w.caught.connect(game._on_wife_caught)
	w.heat_mult = 1.0
	w.ignore_safe = false
	w.catch_dist = WifeCar.CATCH_DIST
	w.alerted = false
	if w.mode == "chase":
		w.forgive(6.0)


func _on_kiinni_paivi() -> void:
	if game.state != "ulkona" or tahdet <= 0:
		return
	var why := "Päivi sai sut kiinni varastetulla autolla!" if autossa else "Päivi sai sut kiinni autovarkauden jälkeen!"
	_lopeta_jahti(false)
	nouse(true)  # pyörä takaisin paikalleen ennen motkotusta (aamun pyörälappu)
	game._lose(why, "wife")


func _on_kiinni_poliisi() -> void:
	if game.state != "ulkona" or tahdet <= 0:
		return
	_lopeta_jahti(false)
	nouse(true)
	game._rikos_loppu("pidatys", "Autovarkaus: %s pysäytti varastetun auton." % ("Roivainen" if paikka == "vaala" else "poliisi"))


func _luo_poliisi() -> void:
	var w: Node3D = game.world
	var i := _solmu_lahella(game.player.global_position, Vector2(90.0, 160.0))
	_poliisi = PoliceCar.new()
	game._hazards.add_child(_poliisi)
	_poliisi.setup(w.graph_nodes, w.graph_adj, i, game.player)
	_poliisi.world = w
	_poliisi.ignore_safe = true
	_poliisi.caught.connect(_on_kiinni_poliisi)
	_poliisi.start_chase()
	game._show_message("POLIISI MUKANA JAHDISSA!", 2.5)


func _luo_roivainen() -> void:
	_poista_roivainen()
	var mt: Node3D = game.mopo_trip
	_roivainen = RoivainenAuto.new()
	_roivainen.vaala = mt.vaala
	_roivainen.line = mt._line
	_roivainen.target = game.player
	mt.add_child(_roivainen)
	_roivainen.caught.connect(_on_kiinni_poliisi)
	var lp: Vector3 = mt.to_local(game.player.global_position)
	var ni: Array = mt.vaala.nearest(lp)
	var i: int = ni[0] if ni[0] >= 0 else mt._sample
	# 70 näytettä (140 m) taaksepäin tai eteenpäin, kumpi mahtuu tielle.
	var back := i - 70 if i - 70 > 2 else i + 70
	_roivainen.place_at(float(back), 1 if back < i else -1)


func _poista_roivainen() -> void:
	if _roivainen != null and is_instance_valid(_roivainen):
		_roivainen.queue_free()
	_roivainen = null


## Kuminauha: kaukana oleva jahtaaja näkymättömiin pelaajan lähelle (tieverkon solmu, mieluiten kameran takana).
func _kumilla(a: Node3D) -> void:
	if a == _roivainen:
		var mt: Node3D = game.mopo_trip
		var ni: Array = mt.vaala.nearest(mt.to_local(game.player.global_position))
		if ni[0] < 0:
			return
		var i: int = ni[0]
		var back := i - 40 if i - 40 > 2 else i + 40
		_roivainen.place_at(float(back), 1 if back < i else -1)
		return
	var p: Vector3 = game.player.global_position
	var i := _solmu_lahella(p, KUMI_ETAISYYS)
	if game.world.graph_nodes[i].distance_to(p) >= a.global_position.distance_to(p) - 20.0:
		return  # ei lähempää solmua: jahtaaja jatkaa omaa reittiään
	a.reset_to(i)
	a.alerted = true
	a.mode = "chase"


func _solmu_lahella(p: Vector3, r: Vector2) -> int:
	var w: Node3D = game.world
	var cam := game.get_viewport().get_camera_3d()
	var fwd: Vector3 = -cam.global_transform.basis.z if cam != null else Vector3.FORWARD
	var best := -1
	var cand := -1
	for i in w.graph_nodes.size():
		var to: Vector3 = w.graph_nodes[i] - p
		var d := to.length()
		if d < r.x or d > r.y or w.graph_adj[i].is_empty():
			continue
		cand = i
		if to.normalized().dot(fwd) < 0.2:
			best = i
			break
	if best < 0:
		best = cand
	if best < 0:
		# Tieverkon solmut ovat suorilla harvassa: lähin solmu vähintään r.x päässä (ei silmien eteen).
		var bd := INF
		for i in w.graph_nodes.size():
			var d: float = w.graph_nodes[i].distance_to(p)
			if d >= r.x and d < bd and not w.graph_adj[i].is_empty():
				bd = d
				best = i
	if best < 0:
		best = w.nearest_node(p)
	return best


func _lopeta_jahti(pako: bool) -> void:
	tahdet = 0
	nakyy = false
	_piilo_t = 0.0
	_pudotus_t = 0.0
	_irrota_paivi()
	_poista_roivainen()
	if _poliisi != null and is_instance_valid(_poliisi):
		_poliisi.queue_free()
	_poliisi = null
	if pako:
		pakoja += 1
		game.tilat.add("stressi", 0.15)
		game._show_message("PÄÄSIT KARKUUN! Tähdet sammuivat.", 3.0)


## Kaikki pois: auto, jahti, kuski ja hylätyt autot (uusi päivä ja lataus).
func nollaa() -> void:
	if autossa:
		nouse(true, false)
	autossa = false
	_lopeta_jahti(false)
	_poista_kuski()
	for h in _hylatyt:
		if is_instance_valid(h):
			h.queue_free()
	_hylatyt.clear()
	_pidetty = null
	paikka = ""
	if _hud != null:
		_hud.tahdet = 0


func aamu(_at_m: bool) -> String:
	nollaa()
	kaappaukset = 0
	pakoja = 0
	return ""


func load_from(_cfg: ConfigFile) -> void:
	nollaa()


func riskit() -> Dictionary:
	if kaappaukset == 0 and tahdet == 0:
		return {}
	var rivit: Array = []
	if tahdet > 0:
		rivit.append("Jahti päällä: %d/5 tähteä, perässä %s." % [tahdet, "Roivainen" if paikka == "vaala" else "Päivi"])
	rivit.append("Kaapattuja autoja tänään: %d. Karkuun päästy: %d." % [kaappaukset, pakoja])
	rivit.append("Tähti tulee 25 s ajosta ja kolarista. Piiloon (ei näköyhteyttä), niin tähdet sammuvat.")
	return {"otsikko": "Takaa-ajo", "rivit": rivit}


# --- Testi: aja.sh scene riskit --riski=autovarkaus --arg=saloinen|vaala ----------------------------------------

var _vikoja := 0
var _aika := 0.0  # pelin aika testissä (s)


func _vika(t: String) -> void:
	_vikoja += 1
	print("TESTI VIKA autovarkaus: " + t)


func _tf(n: int) -> void:
	for i in n:
		if game.state != "cutscene":
			game.clock_min = 12.0 * 60.0
		await game.get_tree().process_frame
		_aika += game.get_process_delta_time()


## Odottaa pelin aikaa s sekuntia (tai kunnes ehto täyttyy); palauttaa kuluneen ajan.
func _odota(s: float, ehto := Callable()) -> float:
	var t0 := _aika
	while _aika - t0 < s:
		await _tf(1)
		if ehto.is_valid() and ehto.call():
			break
	return _aika - t0


func _kuva(suffix: String) -> void:
	var path := "user://riskit_autovarkaus%s.png" % suffix
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7).replace(".png", "_autovarkaus%s.png" % suffix)
	await _tf(3)
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
	print("AUTOVARKAUS kuva " + path)


## Lähikuva omalla kameralla kohteesta at suunnasta dir (maailman kehys), etäisyys dist.
func _lahikuva(suffix: String, at: Vector3, dir: Vector3, dist: float) -> void:
	var prev: Camera3D = game.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	game.add_child(cam)
	cam.fov = 45.0
	cam.global_position = at + dir.normalized() * dist
	cam.look_at(at, Vector3.FORWARD if absf(dir.normalized().y) > 0.9 else Vector3.UP)
	cam.make_current()
	await _kuva(suffix)
	cam.queue_free()
	if prev != null:
		prev.make_current()


func _paina(action: String) -> void:
	# Tapahtumana (ei action_press): painallus näkyy seuraavan ruudun is_action_just_pressed-tarkistuksissa.
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await game.get_tree().process_frame


func _tila(t: String) -> void:
	var w: CharacterBody3D = game.wife
	print("AUTOVARKAUS %s: autossa %s tähdet %d näkyy %s piilo %.1f, pelaaja %s, Päivi heat %.3f alerted %s mode %s parked %s safe %s, poliisi %s, roivainen %s" % [
		t, autossa, tahdet, nakyy, _piilo_t, "pyörä/auto" if game.player == game.bike else ("mopo/auto" if _vaala() and game.player == game.mopo_trip.mopo else "jalan"),
		w.heat_mult, w.alerted, w.mode, w.parked, w.ignore_safe, _poliisi != null and is_instance_valid(_poliisi),
		_roivainen != null and is_instance_valid(_roivainen)])


func testi(arg: String) -> void:
	_vikoja = 0
	if arg == "vaala":
		await _testi_vaala()
	else:
		await _testi_saloinen()
	print("AUTOVARKAUS testi valmis, %d vikaa" % _vikoja)


## Pitkä suora tieverkon väli lähellä p:tä: [a, b].
func _suora(p: Vector3) -> Array:
	var w: Node3D = game.world
	var best: Array = []
	var bd := INF
	for a in w.graph_nodes.size():
		for b: int in w.graph_adj[a]:
			var len: float = w.graph_nodes[a].distance_to(w.graph_nodes[b])
			if len < 40.0:
				continue
			var d: float = w.graph_nodes[a].distance_to(p)
			if d < bd:
				bd = d
				best = [a, b]
	return best


## Pisin lähes suora ketju tieverkossa (käännös alle 0,12 rad solmussa): solmuindeksit.
func _pisin_suora() -> Array:
	var w: Node3D = game.world
	var best: Array = []
	var best_len := 0.0
	for a in w.graph_nodes.size():
		for b0: int in w.graph_adj[a]:
			var chain: Array = [a, b0]
			var len: float = w.graph_nodes[a].distance_to(w.graph_nodes[b0])
			while chain.size() < 40:
				var p: int = chain[-2]
				var c: int = chain[-1]
				var d0: Vector3 = (w.graph_nodes[c] - w.graph_nodes[p]).normalized()
				var nxt := -1
				for n: int in w.graph_adj[c]:
					if n == p or n in chain:
						continue
					if d0.angle_to((w.graph_nodes[n] - w.graph_nodes[c]).normalized()) < 0.12:
						nxt = n
						break
				if nxt < 0:
					break
				len += w.graph_nodes[c].distance_to(w.graph_nodes[nxt])
				chain.append(nxt)
			if len > best_len:
				best_len = len
				best = chain
	return best


## Liikenneauto välin a -> b alkuun oikealle kaistalle vauhdissa (setup_graph ja suunta käsin).
func _aseta_auto(c: Node3D, a: int, b: int, t: float, v: float) -> void:
	var w: Node3D = game.world
	var pa: Vector3 = w.graph_nodes[a]
	var pb: Vector3 = w.graph_nodes[b]
	var dir := Vector3(pb.x - pa.x, 0, pb.z - pa.z).normalized()
	c.setup_graph(w.graph_nodes, w.graph_adj, a, w.graph_fast)
	c._prev = a
	c._cur = b
	var p: Vector3 = pa + dir * t + dir.cross(Vector3.UP) * c.lane
	c.global_position = Vector3(p.x, T.h(p.x, p.z), p.z)
	c.rotation.y = B.yaw_to(dir)
	c._speed = v


## Toistotesti (headless): auto ajaa oikeasti, jalankulkija pysäyttää sen, kävelee ovelle kuten pelaaja ja kaappaa; sitten
## F ja sama uudestaan. Jokaisella kierroksella pitää voida kaapata (kaapattava() != null ovella).
func testi_kahdesti(kierroksia := 3) -> void:
	_vikoja = 0
	if game.player != game.walker_out:
		game._toggle_mount()
	game.wife.grace = 1.0e6
	await _tf(10)
	var w: Node3D = game.world
	var ab := _suora(game.walker_out.global_position)
	var a: int = ab[0]
	var b: int = ab[1]
	var pa: Vector3 = w.graph_nodes[a]
	var pb: Vector3 = w.graph_nodes[b]
	var dir := Vector3(pb.x - pa.x, 0, pb.z - pa.z).normalized()
	var right := dir.cross(Vector3.UP)
	for kierros in kierroksia:
		var cars := _liikenne()
		var c: Node3D = cars[kierros % cars.size()]
		for o in cars:
			if o != c:
				o.setup_graph(w.graph_nodes, w.graph_adj, game.wife.farthest_node_from(pa), w.graph_fast)
		var wp := pa + dir * 24.0 + right * 1.7
		game.walker_out.global_position = Vector3(wp.x, T.h(wp.x, wp.z) + 0.3, wp.z)
		game.walker_out.rotation.y = B.yaw_to(-dir)
		_aseta_auto(c, a, b, 0.0, 10.0)
		var t_stop := await _odota(8.0, func() -> bool: return absf(c._speed) < 0.1)
		# Kävely ovelle 4 m/s vauhdilla ruutu kerrallaan (auton eteen jäämisen jälkeen auto saa lähteä, jos se haluaa).
		var door: Vector3 = c.global_transform * _ovi(c)
		var goal := Vector3(door.x, T.h(door.x, door.z) + 0.3, door.z)
		var n := 0
		while game.walker_out.global_position.distance_to(goal) > 0.15 and n < 600:
			var step: Vector3 = (goal - game.walker_out.global_position)
			game.walker_out.global_position += step.normalized() * minf(step.length(), 4.0 * game.get_process_delta_time())
			await _tf(1)
			door = c.global_transform * _ovi(c)  # auto voi liikkua: tavoite seuraa ovea
			goal = Vector3(door.x, T.h(door.x, door.z) + 0.3, door.z)
			n += 1
		if kierros >= 1:  # oma pyörä palaa autosta noustessa kotipaikkaansa: nyt se on oven vieressä ([F] Nouse pyörän selkään -vihje)
			game.bike.global_position = goal - right * 1.2
		await _tf(3)
		var k := kaapattava()
		print("AUTOVARKAUS kierros %d: pysähtyi %.1f s, kävely %d ruutua, auto %.2f m/s, kaapattava %s, vihje '%s', tila %s" % [
			kierros + 1, t_stop, n, c._speed, k != null, game._hint.text, game.state])
		if k == null:
			_vika("kierros %d: ei kaapattavaa ovella (auto %.2f m/s, tila %s)" % [kierros + 1, c._speed, game.state])
			return
		if game._hint.text != "[E] Kaappaa auto":
			_vika("kierros %d: vihje '%s' (odotettiin kaappausvihjettä)" % [kierros + 1, game._hint.text])
		await _paina("interact")  # oikea E-painallus (tick)
		await _tf(3)
		if not autossa or game.player != game.bike:
			_vika("kierros %d: E ei kaapannut autoa (vihje '%s')" % [kierros + 1, game._hint.text])
			return
		await _tf(3)
		var jahtaaja_ok: bool = tahdet == MAX_TAHDET and absf(game.wife.heat_mult - HEAT[MAX_TAHDET]) < 0.001 and game.wife.ignore_safe
		print("AUTOVARKAUS kierros %d: tähdet %d, Päivi heat %.2f ignore_safe %s, poliisi %s" % [kierros + 1, tahdet, game.wife.heat_mult,
			game.wife.ignore_safe, _poliisi != null])
		if not jahtaaja_ok or _poliisi == null:
			_vika("kierros %d: jahti ei alkanut viidellä tähdellä (tähdet %d)" % [kierros + 1, tahdet])
		await _tf(30)
		if kierros == 1:
			# Pelaaja siirtyy jalan ilman F:ää (jokin muu polku): seuraavan kaappauksen on silti onnistuttava.
			var ut: Vector3 = game.bike.global_position + game.bike.global_basis.x * -1.7
			game._place_on_foot(ut)
			await _tf(3)
		else:
			game._toggle_mount()
			await _tf(3)
		if autossa or game.player != game.walker_out:
			_vika("kierros %d: autosta nousu ei onnistunut (autossa %s)" % [kierros + 1, autossa])
			return
		_lopeta_jahti(false)
	print("AUTOVARKAUS toistotesti valmis, %d vikaa" % _vikoja)


func _testi_saloinen() -> void:
	if game.player != game.walker_out:
		game._toggle_mount()
	game.wife.grace = 1.0e6  # ei häiritse ennen kaappausta
	await _tf(10)
	var w: Node3D = game.world
	var p0: Vector3 = game.walker_out.global_position
	var ab := _suora(p0)
	if ab.is_empty():
		_vika("ei suoraa tietä")
		return
	var a: int = ab[0]
	var b: int = ab[1]
	var pa: Vector3 = w.graph_nodes[a]
	var pb: Vector3 = w.graph_nodes[b]
	var dir := Vector3(pb.x - pa.x, 0, pb.z - pa.z).normalized()
	var right := dir.cross(Vector3.UP)
	var cars := _liikenne()
	var c: Node3D = cars[0]
	for o in cars:
		if o != c:
			o.setup_graph(w.graph_nodes, w.graph_adj, game.wife.farthest_node_from(pa), w.graph_fast)
	# F.1 Pysähtyy jalankulkijan eteen.
	var wp := pa + dir * 24.0 + right * 1.7
	game.walker_out.global_position = Vector3(wp.x, T.h(wp.x, wp.z) + 0.3, wp.z)
	game.walker_out.rotation.y = B.yaw_to(-dir)
	_aseta_auto(c, a, b, 0.0, 10.0)
	var t_stop := await _odota(8.0, func() -> bool: return absf(c._speed) < 0.1)
	var gap: float = c.global_position.distance_to(game.walker_out.global_position)
	print("AUTOVARKAUS pysähtyi %.1f s:ssa, %.1f m jalankulkijasta (vauhti %.2f)" % [t_stop, gap, c._speed])
	if absf(c._speed) >= 1.0:
		_vika("liikenneauto ei pysähtynyt jalankulkijan eteen")
	await _kuva("_pysahtyi")
	# F.2 Ovelle: vihje ja auto odottaa.
	var door: Vector3 = c.global_transform * _ovi(c)
	game.walker_out.global_position = Vector3(door.x, T.h(door.x, door.z) + 0.3, door.z)
	game.walker_out.rotation.y = B.yaw_to(c.global_position - door)
	await _odota(1.5)
	print("AUTOVARKAUS ovella: vihje '%s', auto %.2f m/s, siirtyi %.2f m" % [game._hint.text, c._speed,
		c.global_transform.origin.distance_to(c.global_transform.origin)])
	if game._hint.text != "[E] Kaappaa auto" or absf(c._speed) >= 1.0:
		_vika("vihje tai pysähdys ovella: '%s' %.2f" % [game._hint.text, c._speed])
	await _kuva("_ovella")
	var koti: Transform3D = game.bike.global_transform
	var car_at: Vector3 = c.global_position
	await _paina("interact")
	await _tf(3)
	_tila("kaappaus")
	if not autossa or game.player != game.bike or not game.bike.car or tahdet != MAX_TAHDET:
		_vika("kaappaus ei onnistunut")
	if game.bike.car_home.origin.distance_to(koti.origin) > 0.01:
		_vika("pyörän kotipaikka ei tallentunut")
	if c.global_position.distance_to(car_at) < 50.0:
		_vika("liikenneauto jäi paikalleen (%.1f m)" % c.global_position.distance_to(car_at))
	if _kuski == null or _kuski_kupla.text == "":
		_vika("kuski ei hypännyt ulos")
	await _kuva("_kaappaus")
	await _odota(3.5)
	print("AUTOVARKAUS kuski: kupla '%s', %.1f m autosta" % [_kuski_kupla.text if _kuski_kupla != null else "",
		_kuski.global_position.distance_to(game.bike.global_position) if _kuski != null else -1.0])
	await _kuva("_kuski_soittaa")
	# Auton malli lähikuvina (ei pyörän osia, pyörät maassa).
	var bp: Vector3 = game.bike.global_position + Vector3(0, 0.8, 0)
	var bb: Basis = game.bike.global_basis
	await _lahikuva("_auto_edesta", bp, bb * Vector3(0.3, 0.25, -1), 7.0)
	await _lahikuva("_auto_sivulta", bp, bb * Vector3(-1, 0.2, 0), 7.0)
	await _lahikuva("_auto_ylhaalta", bp, Vector3(0.01, 1, 0), 9.0)
	# F.3 Nopeus: autopilotti pisintä suoraa pitkin, Päivi ja liikenne kaukana.
	var far: int = game.wife.farthest_node_from(game.bike.global_position)
	game.wife.reset_to(far)
	for o in cars:
		o.setup_graph(w.graph_nodes, w.graph_adj, far, w.graph_fast)
	var suora := _pisin_suora()
	var s0: Vector3 = w.graph_nodes[suora[0]]
	var s1: Vector3 = w.graph_nodes[suora[-1]]
	var sd := Vector3(s1.x - s0.x, 0, s1.z - s0.z).normalized()
	var sp: Vector3 = s0 + sd.cross(Vector3.UP) * 1.7
	game.bike.global_position = Vector3(sp.x, T.h(sp.x, sp.z) + 0.2, sp.z)
	game.bike.rotation.y = B.yaw_to(sd)
	game.bike.speed = 0.0
	await _tf(2)
	var t_ennen := tahdet
	game.bike.autopilot = true
	game.bike.auto_speed = 3.0
	game.bike.auto_target = s1 + sd.cross(Vector3.UP) * 1.7
	var vmax := 0.0
	var t25 := -1.0
	var t0 := _aika
	while _aika - t0 < 15.0 and game.bike.global_position.distance_to(s1) > 8.0:
		game.wife.reset_to(far)
		await _tf(1)
		vmax = maxf(vmax, absf(game.bike.speed))
		if t25 < 0.0 and vmax > game.bike.car_max * 0.95:
			t25 = _aika - t0
	game.bike.autopilot = false
	game.bike.speed = 0.0
	var hunt: float = game.wife.HUNT_SPEED * game.wife.speed_mult
	print("AUTOVARKAUS nopeus: suora %.0f m, auto huippu %.1f m/s (car_max %.1f, 95 %% %.1f s:ssa), Päivin jahtinopeus %.1f m/s, 5 tähdellä × 1,5 = %.1f m/s; tähdet ajon aikana %d -> %d" % [
		s0.distance_to(s1), vmax, game.bike.car_max, t25, hunt, hunt * 1.5, t_ennen, tahdet])
	if vmax < hunt * 1.5:
		_vika("auto ei ole nopeampi kuin Päivi 5 tähdellä")
	# F.4 Tähdet: ajo, seinäkolari ja liikennekolari.
	tahdet = 1
	_piilo_t = 0.0
	_ajo_t = TAHTI_AJO - 0.01
	game.bike.global_position = Vector3(sp.x, T.h(sp.x, sp.z) + 0.2, sp.z)
	game.bike.rotation.y = B.yaw_to(sd)
	game.bike.autopilot = true
	game.bike.auto_target = s1
	await _odota(4.0, func() -> bool: return tahdet >= 2)
	game.bike.autopilot = false
	game.bike.speed = 0.0
	await _tf(2)
	_tila("25 s ajoa")
	if tahdet != 2:
		_vika("ajosta ei tullut tähteä (%d)" % tahdet)
	_tormays_t = 0.0
	_on_kolari()
	if tahdet != 3:
		_vika("seinäkolarista ei tullut tähteä (%d)" % tahdet)
	_on_kolari()
	if tahdet != 3:
		_vika("kolari tuplana (%d)" % tahdet)
	_tormays_t = 0.0
	var o: Node3D = cars[1]
	var fwd: Vector3 = -game.bike.global_basis.z
	o.global_position = game.bike.global_position + fwd * 3.0
	o.rotation.y = game.bike.rotation.y + PI
	o._speed = 8.0
	game.bike.speed = 10.0
	_tormays_t = 0.0
	await _tf(2)
	_tila("liikennekolari")
	if tahdet != 4:
		_vika("liikennekolarista ei tullut tähteä (%d)" % tahdet)
	o.setup_graph(w.graph_nodes, w.graph_adj, far, w.graph_fast)
	# F.5 Neljä tähteä: Päivi turvapaikkojen ohi, poliisi mukana, kuminauha.
	tahdet = 4
	game.wife.reset_to(game.wife.farthest_node_from(game.bike.global_position))
	var d0: float = game.wife.global_position.distance_to(game.bike.global_position)
	_kumi_t = 0.0
	await _tf(3)
	var d1: float = game.wife.global_position.distance_to(game.bike.global_position)
	var ki := _solmu_lahella(game.bike.global_position, KUMI_ETAISYYS)
	print("AUTOVARKAUS kuminauhan solmu %d: %.0f m pelaajasta (vaaka %.0f m), Päivi tila %s" % [ki, w.graph_nodes[ki].distance_to(game.bike.global_position),
		Vector2(w.graph_nodes[ki].x - game.bike.global_position.x, w.graph_nodes[ki].z - game.bike.global_position.z).length(), game.wife.mode])
	_tila("4 tähteä")
	print("AUTOVARKAUS kuminauha: Päivi %.0f m -> %.0f m" % [d0, d1])
	if not game.wife.ignore_safe or absf(game.wife.heat_mult - HEAT[4]) > 0.001 or game.wife.parked:
		_vika("Päivi 4 tähdellä")
	if d1 > maxf(KUMI_R, game.world.graph_nodes[ki].distance_to(game.bike.global_position) + 5.0) or d1 >= d0:
		_vika("kuminauha ei tuonut Päiviä lähelle")
	if _poliisi == null:
		_vika("poliisi ei tullut 4 tähdellä")
	# Kuva: Päivi auton takana pitkällä suoralla, tähdet HUDissa.
	var mid: Vector3 = sp + sd * 40.0
	game.bike.global_position = Vector3(mid.x, T.h(mid.x, mid.z) + 0.2, mid.z)
	game.bike.rotation.y = B.yaw_to(sd)
	game.bike.speed = 0.0
	fwd = sd
	await _tf(3)
	var back: Vector3 = game.bike.global_position - fwd * 14.0 + game.bike.global_basis.x * 0.4
	game.wife.global_position = Vector3(back.x, T.h(back.x, back.z), back.z)
	game.wife.rotation.y = game.bike.rotation.y
	await _tf(2)
	await _kuva("_jahti")
	if _poliisi != null:
		var pp: Vector3 = game.bike.global_position - fwd * 13.0 - game.bike.global_basis.x * 3.6
		_poliisi.global_position = Vector3(pp.x, T.h(pp.x, pp.z), pp.z)
		await _tf(2)
		await _kuva("_poliisi")
	# Päivin jahtinopeus 4 tähdellä (mitattu ajosta).
	game.wife.reset_to(_solmu_lahella(game.bike.global_position, Vector2(60.0, 90.0)))
	var wm := 0.0
	t0 = _aika
	while _aika - t0 < 4.0:
		await _tf(1)
		wm = maxf(wm, absf(game.wife._speed))
		if game.state != "ulkona":
			break
	print("AUTOVARKAUS Päivi 4 tähdellä: %.1f m/s (odotus enintään %.1f)" % [wm, hunt * HEAT[4]])
	if game.state != "ulkona":
		_vika("jäi kiinni nopeusmittauksessa")
		return
	# F.6 Pako: jahtaajat kaukana (ei näköyhteyttä); 2 tähteä = 2 × 4 s piilossa + 2 × 8 s pudotusta = 24 s.
	tahdet = 2
	_piilo_t = 0.0
	_pudotus_t = 0.0
	if _poliisi != null:
		_poliisi.queue_free()
		_poliisi = null
	t0 = _aika
	var nahty := 0
	while tahdet > 0 and _aika - t0 < 40.0:
		game.wife.reset_to(game.wife.farthest_node_from(game.bike.global_position))
		for oc in cars:
			if oc.global_position.distance_to(game.bike.global_position) < 40.0:
				oc.setup_graph(w.graph_nodes, w.graph_adj, far, w.graph_fast)
		await _tf(1)
		nahty += int(nakyy)
	var pako := _aika - t0
	_tila("pako")
	print("AUTOVARKAUS pako 2 tähdestä %.1f s (odotus %.0f s), nähty %d ruutua; Päivin caught takaisin mainille %s" % [
		pako, 2 * PIILO_PER_TAHTI + 2 * PUDOTUS, nahty, game.wife.caught.is_connected(game._on_wife_caught)])
	if tahdet != 0 or absf(pako - 24.0) > 3.0 or game.wife.heat_mult != 1.0 or not game.wife.caught.is_connected(game._on_wife_caught):
		_vika("pako")
	# F.7 Autosta jalan: hylätty auto, pyörä kotiin.
	var at: Vector3 = game.bike.global_position
	game._toggle_mount()
	await _tf(3)
	_tila("nousi")
	var prop_ok := not _hylatyt.is_empty() and _hylatyt[-1].global_position.distance_to(at) < 0.6
	print("AUTOVARKAUS nousu: hylätty auto %s (%.2f m), pyörä kotona %.2f m, pyörä car %s" % [prop_ok,
		_hylatyt[-1].global_position.distance_to(at) if not _hylatyt.is_empty() else -1.0,
		game.bike.global_position.distance_to(koti.origin), game.bike.car])
	if autossa or game.player != game.walker_out or not prop_ok or game.bike.car or game.bike.global_position.distance_to(koti.origin) > 0.3:
		_vika("autosta nousu")
	await _kuva("_hylatty")
	# F.8 Uusi kaappaus ja kiinnijäänti: Päivi saa kiinni autossa -> motkotus, pyörä kotona.
	var c2: Node3D = cars[2] if cars.size() > 2 else cars[1]
	_aseta_auto(c2, a, b, 5.0, 0.0)
	await _tf(2)
	var d2: Vector3 = c2.global_transform * _ovi(c2)
	game.walker_out.global_position = Vector3(d2.x, T.h(d2.x, d2.z) + 0.3, d2.z)
	await _tf(3)
	if kaapattava() != c2:
		_vika("toinen kaappaus ei tarjolla")
	kaappaa(c2)
	await _tf(3)
	var fw2: Vector3 = -game.bike.global_basis.z
	var wq: Vector3 = game.bike.global_position + fw2 * 2.5
	game.wife.global_position = Vector3(wq.x, T.h(wq.x, wq.z), wq.z)
	await _odota(3.0, func() -> bool: return game.state == "cutscene")
	_tila("kiinni")
	print("AUTOVARKAUS kiinni: tila %s, syy %s, pyörä kotona %.2f m, pelaaja jalan %s" % [game.state, game._day_end,
		game.bike.global_position.distance_to(koti.origin), game.player == game.walker_out])
	if game.state != "cutscene" or game._day_end != "paivi" or game.bike.car or game.bike.global_position.distance_to(koti.origin) > 0.3:
		_vika("Päivin kiinniotto")
	await _odota(2.0)
	await _kuva("_kiinni")
	# Uusi päivä nollaa (aamu): hylätyt pois.
	aamu(false)
	if not _hylatyt.is_empty() or tahdet != 0 or autossa:
		_vika("aamu ei nollannut")
	var rs := riskit()
	print("AUTOVARKAUS riskit aamulla %s" % [rs])


func _testi_vaala() -> void:
	if game.player != game.walker_out:
		game._toggle_mount()
	game._start_mopo()
	var mt: Node3D = game.mopo_trip
	await _tf(20)
	var vl: Node3D = mt.vaala
	var mp: CharacterBody3D = mt.mopo
	# Mopo tielle mökiltä (näyte 60), jalan viereen.
	var i0 := 60
	var rd: Vector3 = vl.road_dir(i0)
	mp.position = vl.road_pos(i0) + rd.cross(Vector3.UP) * 1.6 + Vector3(0, 0.6, 0)
	mp.rotation.y = atan2(-rd.x, -rd.z)
	await _tf(5)
	game._mopo_dismount()
	await _tf(5)
	var koti: Transform3D = mp.transform
	var c: Node3D = mt._cars[0]
	for o in mt._cars:
		if o != c:
			o.set_line_t(float(mt._line.size() - 10), 1)
	c.set_line_t(float(i0 + 12), -1)
	c._speed = 0.0
	c._place_on_line(0.0)
	await _tf(3)
	var door: Vector3 = c.global_transform * _ovi(c)
	var lw: Vector3 = mt.to_local(door)
	game.walker_out.global_position = mt.to_global(Vector3(lw.x, vl.h(lw.x, lw.z) + 0.3, lw.z))
	await _odota(1.0)
	print("AUTOVARKAUS Vaala ovella: vihje '%s', auto %.2f m/s" % [game._hint.text, c._speed])
	if game._hint.text != "[E] Kaappaa auto":
		_vika("Vaala: vihje '%s'" % game._hint.text)
	await _kuva("_vaala_ovella")
	await _paina("interact")
	await _tf(3)
	_tila("Vaala kaappaus")
	if not autossa or not mp.car or game.player != mp or _roivainen == null:
		_vika("Vaala: kaappaus")
	await _kuva("_vaala_kaappaus")
	# Roivaisen lähestyminen ja nopeus.
	var d0: float = _roivainen.global_position.distance_to(mp.global_position)
	var rmax := 0.0
	var t0 := _aika
	while _aika - t0 < 6.0:
		await _tf(1)
		rmax = maxf(rmax, _roivainen._speed)
	var d1: float = _roivainen.global_position.distance_to(mp.global_position)
	print("AUTOVARKAUS Roivainen %.0f m -> %.0f m (6 s), nopeus %.1f m/s (%.1f × %.3f)" % [d0, d1, rmax, RoivainenAuto.SPEED, _roivainen.heat_mult])
	if d1 >= d0:
		_vika("Roivainen ei lähesty")
	var fwd: Vector3 = -mp.global_basis.z
	_roivainen.process_mode = Node.PROCESS_MODE_DISABLED  # paikallaan kuvan ajan
	var ci: int = vl.nearest(mp.position)[0]
	var cdir: int = 1 if vl.road_dir(ci).dot(-mp.global_basis.z) > 0.0 else -1
	_roivainen.place_at(float(ci - cdir * 12), cdir)  # 24 m takana tiellä, kaistalla ja maaston kallistuksella
	await _tf(6)
	await _kuva("_vaala_roivainen_peli")
	# Kamera kaapatun auton edessä katsoo taaksepäin: auto ja perässä tuleva Roivainen samassa kuvassa.
	await _lahikuva("_vaala_roivainen", mp.global_position - fwd * 11.0 + Vector3.UP, fwd * 1.0 + mp.global_basis.x * 0.3 + Vector3.UP * 0.3, 20.0)
	var rp: Vector3 = _roivainen.global_position + Vector3(0, 0.8, 0)
	await _lahikuva("_roivainen_sivulta", rp, _roivainen.global_basis * Vector3(1, 0.25, -0.5), 7.0)
	_roivainen.process_mode = Node.PROCESS_MODE_INHERIT
	# Kiinni: pidätys, mopo takaisin paikalleen.
	_roivainen.position = mt.to_local(mp.global_position + fwd * 2.0)
	await _odota(3.0, func() -> bool: return game.state == "cutscene")
	print("AUTOVARKAUS Vaala kiinni: tila %s, mopo kotona %.2f m, car %s" % [game.state, mp.transform.origin.distance_to(koti.origin), mp.car])
	if game.state != "cutscene" or mp.car or mp.transform.origin.distance_to(koti.origin) > 0.3:
		_vika("Vaala: Roivaisen kiinniotto")
	await _odota(2.0)
	await _kuva("_vaala_kiinni")
