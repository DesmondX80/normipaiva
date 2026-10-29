extends Node3D
## Raahen satama ja Kruununmakasiini (retket.gd "vanhaherra"): taskukohtaus kuten retki_tietokonemuseo.gd. Kävely player_walker.gd:llä.
## Vasemmalla Kruununmakasiini ja sen edessä vitriini, jossa "Vanha herra" (sanotaan maailman vanhin säilynyt sukelluspuku, tarkistettava; puku on
## tyylitelty kuparikypäräpuku, ei tarkka kopio). Oikealla laiturin reuna: sukeltaja valmiina, letku ja ilmapumppu, jonka vivusta pumppaaja pitää
## molemmin käsin. Pumpun luona [E] käynnistää sukelluksen (sukellus_game.gd).
## Paikallinen -Z = takaseinä ja vesi, +Z = ovi ja kamera. Kaikki hahmot katsovat +Z:aan (kameraa kohti). Hahmon etu = -Z (basis * -Z), yaw_to-suunta.
## Pumppu: vipu on vaakasuora X-akselin suuntainen tanko, joka keinuu Z-akselin ympäri (_tilt); tangot, kädet ja vivun päät lasketaan samasta kulmasta.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")
const Pose := preload("res://scripts/pose.gd")

const HALF := Vector2(8.0, 6.0)
const TILT := -25.0  # kyltit kallistetaan kameraa kohti
const WATER_Y := -0.35
const EDGE_Z := -1.55  # laiturin reunan z
const PUMP := Vector3(4.2, 0.0, -0.43)  # pumpun keskipiste (pylvään juuri)
const BAR_Y := 1.12  # vivun kääntöpisteen korkeus
const GRIP := 0.3  # kahvojen etäisyys kääntöpisteestä
const BAR_HALF := 0.65
const PUMPER_AT := Vector3(4.2, 0.0, -0.85)
const DIVER_AT := Vector3(1.8, 0.0, -1.05)

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var spot := ""
var legenda: RefCounted
var spots := {
	"ovi": [Vector3(6.4, 0, 4.8), "[E] Ulos: taksille takaisin lähtöpaikkaan"],
	"vitriini": [Vector3(-4.5, 0, -0.7), "[E] Katso vitriiniä: Vanha herra"],
	"sukeltaja": [Vector3(1.8, 0, 0.3), "[E] Juttele sukeltajan kanssa"],
	"pumppu": [Vector3(4.2, 0, 0.5), "[E] Pumppaa ilmaa sukeltajalle (sukellus)"],
	"pumppaaja": [Vector3(5.5, 0, -0.55), "[E] Juttele pumppaajan kanssa"],
}
var _enter_frame := -1
var _pumper: Node3D
var _diver: Node3D
var _bub_p: Label3D
var _bub_d: Label3D
var _bub_p_t := 0.0
var _bub_d_t := 0.0
var _t := 0.0
var _tilt := 0.0  # vivun kulma (rad), + = vasen (X-) pää alas
var _bar: Node3D
var _rods: Array[MeshInstance3D] = []
var _gauge: Node3D
var _watch: Node3D
var _line_p := 0
var _line_d := 0
const BUBBLE_P := Vector3(6.2, 0.5, -0.7)  # pumppaajan oikealla lattialla
const BUBBLE_D := Vector3(0.0, 0.5, -0.9)  # sukeltajan vasemmalla puolella
const BUBBLE_FAR := 4.5
const PUMPER_LINES := ["Kapteeni pudotti taskukellonsa tästä laiturilta viime syksynä. Sukeltaja hakee sen, jos joku pumppaa ilmaa.",
	"Pumpataan vuorotellen, A ja D. Tasainen tahti, ei kiireellä. Liika paine nostaa sukeltajan pohjasta kuin korkin.",
	"Selkä ei kestä enää. Mene sinä vivulle, minä pidän letkua. Pumpun vieressä [E].",
	"Kello on kuulemma arkun alla, sanotaan. Muu pohjan roina on vanhaa kamaa."]
const DIVER_LINES := ["Vitriinin Vanha herra on mallia 1800-luku, sanotaan: kuparia, kangasta ja lyijyä. Tämä puku on uudempi ja painaa silti neljäkymmentä kiloa.",
	"Pohjassa on saapas, ämpäri, pullo ja pieni ankkuri. Kapteenin kello on puuarkun alla.",
	"Ilmaa, ilmaa! Pumppaa vuorotellen, sitten minä jaksan kävellä pohjalla."]


func _ready() -> void:
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF.x + 0.6, EDGE_Z + 0.35, HALF.x * 2.0 - 1.2, HALF.y - EDGE_Z - 0.4)]
	add_child(walker)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(-2.6, 0, -1.2)
	walker.rotation.y = B.yaw_to(Vector3(-1, 0, -1))
	walker.visible = true
	walker.activate()
	refresh()


func leave() -> void:
	active = false
	walker.controls_enabled = false


func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


## Pumppaaja (who "p") tai sukeltaja ("d") puhuu: kupla hahmon vieressä lattialla.
func say(text: String, who := "p", t := 4.2) -> void:
	if who == "p":
		_bub_p.text = text
		_bub_p_t = t
		_pumper.play("Idle_Talking", 0.2)
	else:
		_bub_d.text = text
		_bub_d_t = t
		_diver.play("Idle_Talking", 0.2)


func next_line(who := "p") -> String:
	if who == "p":
		_line_p = (_line_p + 1) % PUMPER_LINES.size()
		return PUMPER_LINES[_line_p]
	_line_d = (_line_d + 1) % DIVER_LINES.size()
	return DIVER_LINES[_line_d]


## Löydetty taskukello vitriinin hyllylle (kutsutaan sisääntulossa ja löydön jälkeen).
func refresh() -> void:
	if _watch != null:
		_watch.visible = legenda != null and legenda.loytyi


func _pump_tilt() -> float:
	return sin(_t * 2.1) * 0.17  # pumppaaja pumppaa hitaasti tahdissa


func _process(delta: float) -> void:
	_t += delta
	_bub_p_t -= delta
	_bub_d_t -= delta
	if _bub_p.text != "" and (_bub_p_t <= 0.0 or (active and walker.position.distance_to(PUMPER_AT) > BUBBLE_FAR)):
		_bub_p.text = ""
		_pumper.play("Idle", 0.3)
	if _bub_d.text != "" and (_bub_d_t <= 0.0 or (active and walker.position.distance_to(DIVER_AT) > BUBBLE_FAR)):
		_bub_d.text = ""
		_diver.play("Idle", 0.3)
	_tilt = _pump_tilt()
	_update_pump()
	_grip_arms()
	_diver.set_override("spine_03", Vector3.RIGHT, sin(_t * 1.4) * 0.03)  # hengitys
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	var p := walker.position
	var best := ""
	var bd := 1.8
	for id in spots:
		var d := Vector2(p.x - spots[id][0].x, p.z - spots[id][0].z).length()
		if d < bd:
			bd = d
			best = id
	hint = ""
	spot = best
	if best == "":
		return
	hint = spots[best][1]
	if best == "pumppu" and legenda != null and legenda.loytyi:
		hint = "[E] Pumppaa ilmaa sukeltajalle (kello löytynyt, voit sukeltaa uudestaan)"
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	if best == "ovi":
		exited.emit()
	else:
		acted.emit(best)


# --- Pumppu ja käsien sovitus -------------------------------------------------------------------

func _bar_point(s: float) -> Vector3:
	return PUMP + Vector3(0, BAR_Y, 0) + Vector3(cos(_tilt), sin(_tilt), 0) * s


## Vipu, männänvarret ja painemittari samasta kulmasta (_tilt).
func _update_pump() -> void:
	_bar.rotation.z = _tilt
	for i in _rods.size():
		var s := -0.5 if i == 0 else 0.5
		var top := _bar_point(s)
		var bot := PUMP + Vector3(s, 0.95, 0)
		var mid := (top + bot) / 2.0
		_rods[i].position = mid
		_rods[i].scale = Vector3(1, maxf(top.distance_to(bot), 0.01), 1)
	_gauge.rotation.z = lerpf(-1.2, 1.2, 0.5 + 0.5 * sin(_t * 2.1 + 0.6))


## Kädet vivun kahvoilla yläotteella: kämmen vivun päällä (palm_on, vasen = peilikuva), sormet +Z:aan vivun etupuolelle koukussa.
## Ranteen paikka vivun pinnasta (kallistus mukana), kyynärpäät alas ja ulos. Kaikki samasta kulmasta (_tilt).
func _grip_arms() -> void:
	var ch := _pumper
	var inv := ch.transform.affine_inverse()
	var to_local := ch.basis.inverse()
	var bar_dir := Vector3(cos(_tilt), sin(_tilt), 0.0)
	var into := Vector3(sin(_tilt), -cos(_tilt), 0.0)  # kämmen osoittaa vipuun päin (alas vivun normaalia pitkin)
	for lr: String in ["_l", "_r"]:
		var sh: Vector3 = ch.transform * ch.bone_position("upperarm" + lr)
		var out := signf(sh.x - ch.position.x)
		var hp := _bar_point(out * GRIP) - into * 0.06 + Vector3(0, 0, -0.07)
		var pole := sh + Vector3(out * 0.3, -0.4, -0.25)
		ch.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, inv * hp, inv * pole)
		var fingers := to_local * Vector3(0, 0, 1)
		var n := to_local * into
		ch.set_ik_orient("arm" + lr, Pose.palm_on(fingers, n, lr == "_l"), 1.0)
		var axis := fingers.cross(n).normalized()
		for f: String in ["index", "middle", "ring", "pinky"]:
			ch.set_override(f + "_01" + lr, axis, 0.5)
			ch.set_override(f + "_02" + lr, axis, 0.7)
			ch.set_override(f + "_03" + lr, axis, 0.5)
		ch.set_override("thumb_01" + lr, axis, 0.2)


# --- Rakennus -------------------------------------------------------------------------------

func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	return B.solid(self, size, pos, col)


func _alpha(mi: MeshInstance3D, col: Color) -> void:
	var m := B.mat(col).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	mi.material_override = m


## Vanha herra: tyylitelty kuparikypäräpuku telineessä (umpinaiset palat): kangaspuku, rintalevy, kypärä kolmella lasilla, lyijykengät, ilmaletku.
func _diving_suit(parent: Node3D, base: Vector3) -> void:
	var s := Node3D.new()
	s.position = base
	s.scale = Vector3.ONE * 1.15  # täyttää vitriinin
	parent.add_child(s)
	var cloth := Color(0.5, 0.4, 0.24)
	var copper := Color(0.78, 0.46, 0.24)
	var lead := Color(0.32, 0.33, 0.36)
	B.mesh(s, B.cyl(0.32, 0.36, 0.05, 20), Vector3(0, 0.025, 0), Color(0.25, 0.17, 0.1))  # jalusta
	B.mesh(s, B.cyl(0.02, 0.02, 1.1, 8), Vector3(0, 0.6, -0.12), Color(0.3, 0.3, 0.32))  # tuki selän takana
	for sx in [-0.11, 0.11]:  # lyijykengät ja lahkeet (jalat erillään)
		B.mesh(s, B.boxm(Vector3(0.15, 0.12, 0.34)), Vector3(sx, 0.11, 0.03), lead)
		B.mesh(s, B.boxm(Vector3(0.16, 0.03, 0.35)), Vector3(sx, 0.045, 0.03), lead.darkened(0.3))
		B.mesh(s, B.cyl(0.08, 0.085, 0.52, 12), Vector3(sx, 0.44, 0), cloth)
		B.mesh(s, B.sphere(0.085, 10), Vector3(sx, 0.2, 0.0), cloth.darkened(0.15))  # nilkka
	B.mesh(s, B.cyl(0.23, 0.2, 0.5, 16), Vector3(0, 0.95, 0), cloth)  # vartalo
	B.mesh(s, B.cyl(0.235, 0.235, 0.04, 16), Vector3(0, 0.76, 0), Color(0.3, 0.2, 0.12))  # vyö
	for sx in [-1.0, 1.0]:  # kädet: hihat olkapäästä ulos ja alas, kumikintaat hihan päässä
		var sh := Vector3(sx * 0.27, 1.12, 0.0)
		var ar := Vector3(sx * 0.1, -0.45, 0.0)  # hihan suunta ja pituus (yksi vektori: hihan kallistus ja kintaan paikka)
		B.mesh(s, B.sphere(0.075, 10), sh, cloth.darkened(0.1))
		B.tube(s, sh, sh + ar, 0.06, cloth.darkened(0.1))
		B.mesh(s, B.sphere(0.075, 10), sh + ar + Vector3(sx * 0.01, -0.05, 0), Color(0.18, 0.15, 0.12))
	B.mesh(s, B.boxm(Vector3(0.1, 0.1, 0.05)), Vector3(-0.1, 0.9, 0.23), lead)  # rintapainot
	B.mesh(s, B.boxm(Vector3(0.1, 0.1, 0.05)), Vector3(0.1, 0.9, 0.23), lead)
	B.mesh(s, B.cyl(0.24, 0.2, 0.08, 18), Vector3(0, 1.2, 0), copper.darkened(0.15))  # rintalevy
	for k in 8:
		var a := TAU * k / 8.0
		B.mesh(s, B.sphere(0.014, 6), Vector3(cos(a) * 0.225, 1.235, sin(a) * 0.225), copper.lightened(0.45))  # niitit
	var helmet := B.mesh(s, B.sphere(0.5, 18), Vector3(0, 1.4, 0), copper)
	helmet.scale = Vector3(0.44, 0.44, 0.44)
	B.mesh(s, B.cyl(0.16, 0.2, 0.06, 16), Vector3(0, 1.26, 0), copper.darkened(0.25))  # kypärän kaulus
	var glass := Color(0.12, 0.24, 0.3)
	B.mesh(s, B.cyl(0.075, 0.075, 0.04, 14), Vector3(0, 1.4, 0.21), copper.darkened(0.3), Vector3(90, 0, 0))  # etulasi + kehys
	B.mesh(s, B.cyl(0.058, 0.058, 0.05, 14), Vector3(0, 1.4, 0.215), glass, Vector3(90, 0, 0))
	for sx in [-1.0, 1.0]:  # sivulasit
		B.mesh(s, B.cyl(0.062, 0.062, 0.04, 12), Vector3(sx * 0.19, 1.4, 0.07), copper.darkened(0.3), Vector3(0, 0, 90))
		B.mesh(s, B.cyl(0.046, 0.046, 0.05, 12), Vector3(sx * 0.195, 1.4, 0.07), glass, Vector3(0, 0, 90))
	B.mesh(s, B.cyl(0.04, 0.04, 0.05, 12), Vector3(0, 1.59, 0.08), copper.darkened(0.2))  # yläkansi
	B.mesh(s, B.cyl(0.05, 0.05, 0.05, 12), Vector3(0, 1.4, -0.21), copper.darkened(0.2), Vector3(90, 0, 0))  # letkun liitin takana
	B.tube(s, Vector3(0, 1.4, -0.23), Vector3(0.0, 0.9, -0.3), 0.025, Color(0.12, 0.15, 0.12))
	B.tube(s, Vector3(0, 0.9, -0.3), Vector3(0.0, 0.06, -0.34), 0.025, Color(0.12, 0.15, 0.12))


## Vitriini: lasi- ja puukehys seinän edessä, Vanha herra sisällä, hyllyllä taskukello (kun löytynyt) ja kyltti.
func _vitrine(c: Vector3) -> void:
	var wood := Color(0.34, 0.22, 0.13)
	B.mesh(self, B.boxm(Vector3(1.9, 0.18, 1.1)), c + Vector3(0, 0.09, 0), wood)
	for sx in [-0.92, 0.92]:
		for sz in [-0.5, 0.5]:
			B.mesh(self, B.boxm(Vector3(0.06, 2.0, 0.06)), c + Vector3(sx, 1.18, sz), wood)
	B.mesh(self, B.boxm(Vector3(1.94, 0.1, 1.14)), c + Vector3(0, 2.22, 0), wood)
	var body := StaticBody3D.new()
	body.position = c + Vector3(0, 1.1, 0)
	body.add_child(B.box_shape(Vector3(1.9, 2.2, 1.1)))
	add_child(body)
	_diving_suit(self, c + Vector3(0, 0.18, 0))
	# Taskukello hyllyllä (näkyy vasta löydettyä): kultakotelo, valkoinen kellotaulu, ketju.
	_watch = Node3D.new()
	_watch.position = c + Vector3(0.62, 0.18, 0.28)
	add_child(_watch)
	B.mesh(_watch, B.boxm(Vector3(0.3, 0.05, 0.22)), Vector3(0, 0.025, 0), Color(0.3, 0.1, 0.12))
	B.mesh(_watch, B.cyl(0.085, 0.085, 0.03, 18), Vector3(0, 0.075, 0), Color(0.96, 0.78, 0.22))
	B.mesh(_watch, B.cyl(0.07, 0.07, 0.032, 18), Vector3(0, 0.077, 0), Color(0.97, 0.95, 0.88))
	B.mesh(_watch, B.boxm(Vector3(0.006, 0.004, 0.05)), Vector3(0, 0.095, -0.02), Color(0.1, 0.1, 0.1))
	B.mesh(_watch, B.boxm(Vector3(0.004, 0.004, 0.04)), Vector3(0.015, 0.095, 0.0), Color(0.1, 0.1, 0.1), Vector3(0, 60, 0))
	B.mesh(_watch, B.sphere(0.02, 8), Vector3(0, 0.1, -0.09), Color(0.96, 0.78, 0.22))
	B.tube(_watch, Vector3(0, 0.1, -0.09), Vector3(0.1, 0.06, -0.06), 0.006, Color(0.9, 0.72, 0.2))
	B.tube(_watch, Vector3(0.1, 0.06, -0.06), Vector3(0.16, 0.052, 0.04), 0.006, Color(0.9, 0.72, 0.2))
	_watch.visible = false
	# Lasi: läpikuultavat paneelit edessä ja sivuilla.
	var gl := B.mesh(self, B.boxm(Vector3(1.8, 1.95, 0.02)), c + Vector3(0, 1.18, 0.55), Color.WHITE)
	_alpha(gl, Color(0.8, 0.9, 0.95, 0.14))
	for sx in [-0.93, 0.93]:
		var gs := B.mesh(self, B.boxm(Vector3(0.02, 1.95, 1.0)), c + Vector3(sx, 1.18, 0), Color.WHITE)
		_alpha(gs, Color(0.8, 0.9, 0.95, 0.14))
	var pl := B.sign_plate(self, "VANHA HERRA\nsukelluspuku, sanotaan", Color(0.14, 0.17, 0.22), Color(0.95, 0.95, 0.85), 0.3, 60, Color(0.78, 0.6, 0.2))
	pl.position = c + Vector3(2.4, 1.0, 1.0)  # vitriinin sivulla pylvään päällä, ei puvun edessä
	pl.rotation_degrees.x = -40.0
	B.sign_pole(self, c + Vector3(2.4, 0, 1.0), 0.7)


func _pump_unit() -> void:
	var wood := Color(0.5, 0.34, 0.2)
	var brass := Color(0.9, 0.7, 0.26)
	_solid(Vector3(1.4, 0.5, 0.44), PUMP + Vector3(0, 0.25, 0), wood)
	B.mesh(self, B.boxm(Vector3(1.46, 0.05, 0.5)), PUMP + Vector3(0, 0.52, 0), wood.darkened(0.25))
	for s in [-0.5, 0.5]:  # messinkisylinterit
		B.mesh(self, B.cyl(0.1, 0.1, 0.45, 16), PUMP + Vector3(s, 0.76, 0), brass)
		B.mesh(self, B.cyl(0.115, 0.115, 0.04, 16), PUMP + Vector3(s, 0.99, 0), brass.darkened(0.3))
		B.mesh(self, B.cyl(0.115, 0.115, 0.04, 16), PUMP + Vector3(s, 0.55, 0), brass.darkened(0.3))
		var rod := B.mesh(self, B.cyl(0.014, 0.014, 1.0, 8), PUMP + Vector3(s, 1.05, 0), Color(0.78, 0.8, 0.82))
		_rods.append(rod)
	B.mesh(self, B.cyl(0.04, 0.05, BAR_Y - 0.5, 10), PUMP + Vector3(0, 0.5 + (BAR_Y - 0.5) / 2.0, 0), Color(0.28, 0.2, 0.13))  # pylväs
	B.mesh(self, B.sphere(0.07, 10), PUMP + Vector3(0, BAR_Y, 0), brass.darkened(0.15))  # kääntöpiste
	_bar = Node3D.new()
	_bar.position = PUMP + Vector3(0, BAR_Y, 0)
	add_child(_bar)
	B.mesh(_bar, B.boxm(Vector3(BAR_HALF * 2.0, 0.05, 0.05)), Vector3.ZERO, Color(0.45, 0.3, 0.18))
	for s in [-1.0, 1.0]:  # kahvat: sylinterit tangon päällä (kädet tarttuvat näihin)
		B.mesh(_bar, B.cyl(0.027, 0.027, 0.2, 10), Vector3(s * GRIP, 0.0, 0.0), Color(0.62, 0.45, 0.26), Vector3(0, 0, 90))
	# Painemittari etusivulla ja letkun ulostulo vasemmalla.
	B.mesh(self, B.cyl(0.11, 0.11, 0.03, 18), PUMP + Vector3(0.45, 0.32, 0.235), brass.darkened(0.2), Vector3(90, 0, 0))
	B.mesh(self, B.cyl(0.09, 0.09, 0.034, 18), PUMP + Vector3(0.45, 0.32, 0.24), Color(0.96, 0.93, 0.84), Vector3(90, 0, 0))
	_gauge = Node3D.new()  # viisari pyörii mittarin keskellä
	_gauge.position = PUMP + Vector3(0.45, 0.32, 0.262)
	add_child(_gauge)
	B.mesh(_gauge, B.boxm(Vector3(0.012, 0.075, 0.008)), Vector3(0, 0.035, 0), Color(0.75, 0.08, 0.06))
	B.mesh(self, B.cyl(0.04, 0.04, 0.12, 10), PUMP + Vector3(-0.78, 0.16, 0), brass.darkened(0.3), Vector3(0, 0, 90))
	var sp := B.sign_plate(self, "ILMAPUMPPU", Color(0.14, 0.17, 0.22), Color(0.95, 0.95, 0.85), 0.3, 60, Color(0.78, 0.6, 0.2))
	sp.position = PUMP + Vector3(1.9, 1.5, 0.3)
	sp.rotation_degrees.x = TILT
	B.sign_pole(self, PUMP + Vector3(1.9, 0, 0.3), 1.2)


## Ilmaletku sukeltajan kypärän selästä laiturin pintaa pitkin pumpun ulostuloon.
func _hose() -> void:
	var col := Color(0.14, 0.2, 0.15)
	var pts := [Vector3(DIVER_AT.x, 1.52, DIVER_AT.z - 0.3), Vector3(DIVER_AT.x, 0.7, DIVER_AT.z - 0.4), Vector3(DIVER_AT.x + 0.05, 0.05, DIVER_AT.z - 0.3),
		Vector3(2.6, 0.04, -0.9), Vector3(3.3, 0.04, -0.45), Vector3(PUMP.x - 0.82, 0.16, PUMP.z)]
	for i in pts.size() - 1:
		B.tube(self, pts[i], pts[i + 1], 0.028, col)
		B.mesh(self, B.sphere(0.03, 8), pts[i + 1], col)


func _build_boat(c: Vector3, yaw: float) -> void:
	var boat := Node3D.new()
	boat.position = c
	boat.rotation_degrees.y = yaw
	add_child(boat)
	var hull := Color(0.18, 0.3, 0.5)
	B.mesh(boat, B.boxm(Vector3(2.6, 0.08, 0.8)), Vector3(0, 0.0, 0), hull.darkened(0.2))
	for sz in [-1.0, 1.0]:
		B.mesh(boat, B.boxm(Vector3(2.8, 0.45, 0.06)), Vector3(0, 0.2, sz * 0.46), hull, Vector3(sz * 14.0, 0, 0))
		B.mesh(boat, B.boxm(Vector3(2.82, 0.06, 0.08)), Vector3(0, 0.44, sz * 0.5), Color(0.9, 0.88, 0.8))
	B.mesh(boat, B.boxm(Vector3(0.06, 0.45, 0.9)), Vector3(-1.4, 0.2, 0), hull.lightened(0.05))
	B.mesh(boat, B.boxm(Vector3(0.06, 0.45, 0.9)), Vector3(1.4, 0.2, 0), hull.lightened(0.05))
	for sx in [-0.5, 0.5]:
		B.mesh(boat, B.boxm(Vector3(0.22, 0.04, 0.9)), Vector3(sx, 0.18, 0), Color(0.55, 0.38, 0.22))
	B.mesh(boat, B.boxm(Vector3(1.9, 0.04, 0.05)), Vector3(0, 0.3, 0.2), Color(0.6, 0.45, 0.28), Vector3(0, 12, 8))  # airo


func _build() -> void:
	var stone := Color(0.52, 0.5, 0.47)
	var wall_c := Color(0.86, 0.8, 0.64)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -2.4, 0), Color(0.62, 0.55, 0.38))  # meren pohja
	# Laituri: koko alue paitsi vesi taka-oikealla (x > -0.5, z < EDGE_Z); ympärillä vesi.
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.8, HALF.y - EDGE_Z)), Vector3(0, -0.4, (HALF.y + EDGE_Z) / 2.0), stone)
	B.mesh(self, B.boxm(Vector3(HALF.x - 0.5, 0.8, HALF.y + EDGE_Z)), Vector3(-0.5 - (HALF.x - 0.5) / 2.0, -0.4, (EDGE_Z - HALF.y) / 2.0), stone)
	for i in 14:  # kiveyksen saumat
		B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.004, 0.03)), Vector3(0, 0.001, EDGE_Z + 0.6 + i * 0.6), stone.darkened(0.25))
	for i in 18:
		B.mesh(self, B.boxm(Vector3(0.03, 0.004, HALF.y - EDGE_Z)), Vector3(-7.6 + i * 0.9, 0.001, (HALF.y + EDGE_Z) / 2.0), stone.darkened(0.2))
	var water := B.mesh(self, B.boxm(Vector3(140, 0.04, 80)), Vector3(0, WATER_Y, 0), Color.WHITE)
	_alpha(water, Color(0.14, 0.45, 0.55, 0.82))
	B.mesh(self, B.boxm(Vector3(HALF.x + 0.5, 0.1, 0.4)), Vector3(-0.5 + (HALF.x + 0.5) / 2.0, 0.05, EDGE_Z + 0.1), stone.lightened(0.15))  # reunakivi
	var curb := StaticBody3D.new()
	curb.position = Vector3(-0.5 + (HALF.x + 0.5) / 2.0, 0.5, EDGE_Z)
	curb.add_child(B.box_shape(Vector3(HALF.x + 0.5, 1.0, 0.4)))
	add_child(curb)
	# Kruununmakasiini: vaalea rapattu kivitalo, aumakatto, ikkunat ja ovi; kyltti pääty-ikkunan yllä.
	_solid(Vector3(7.0, 4.0, 3.2), Vector3(-4.0, 2.0, -4.3), wall_c)
	B.mesh(self, B.boxm(Vector3(7.1, 0.15, 3.3)), Vector3(-4.0, 0.075, -4.3), wall_c.darkened(0.4))
	var roof := B.mesh(self, B.boxm(Vector3(7.4, 0.2, 3.9)), Vector3(-4.0, 4.55, -4.5), Color(0.4, 0.2, 0.16), Vector3(-12, 0, 0))
	roof.position.z = -4.5
	B.mesh(self, B.boxm(Vector3(7.4, 0.2, 2.3)), Vector3(-4.0, 4.5, -5.3), Color(0.38, 0.19, 0.15), Vector3(25, 0, 0))
	for k in 4:  # ikkunat
		var wx := -6.4 + k * 1.6
		B.mesh(self, B.boxm(Vector3(0.9, 1.1, 0.06)), Vector3(wx, 2.4, -2.68), Color(0.25, 0.3, 0.36))
		B.mesh(self, B.boxm(Vector3(1.0, 0.08, 0.1)), Vector3(wx, 1.82, -2.66), Color(0.95, 0.93, 0.88))
		B.mesh(self, B.boxm(Vector3(0.06, 1.1, 0.08)), Vector3(wx, 2.4, -2.66), Color(0.95, 0.93, 0.88))
		B.mesh(self, B.boxm(Vector3(0.9, 0.06, 0.08)), Vector3(wx, 2.4, -2.66), Color(0.95, 0.93, 0.88))
	B.mesh(self, B.boxm(Vector3(1.2, 2.1, 0.08)), Vector3(-3.0, 1.05, -2.66), Color(0.36, 0.22, 0.14))  # ovi
	B.mesh(self, B.boxm(Vector3(1.4, 0.12, 0.14)), Vector3(-3.0, 2.15, -2.64), Color(0.9, 0.88, 0.8))
	B.mesh(self, B.sphere(0.05, 8), Vector3(-2.65, 1.0, -2.6), Color(0.85, 0.7, 0.3))
	var plate_bg := Color(0.14, 0.17, 0.22)
	var plate_fg := Color(0.95, 0.95, 0.85)
	var plate_edge := Color(0.78, 0.6, 0.2)
	var t1 := B.sign_plate(self, "RAAHEN MUSEO\nKRUUNUNMAKASIINI", plate_bg, plate_fg, 0.3, 64, plate_edge)
	t1.position = Vector3(-4.7, 3.55, -2.45)
	t1.rotation_degrees.x = TILT
	var t2 := B.sign_plate(self, "RAAHEN SATAMA", plate_bg, plate_fg, 0.3, 60, plate_edge)
	t2.position = Vector3(3.5, 2.35, EDGE_Z - 0.05)
	t2.rotation_degrees.x = TILT
	B.sign_pole(self, Vector3(3.5, 0, EDGE_Z - 0.05), 2.1)
	# Oven infokyltti.
	B.sign_pole(self, Vector3(5.9, 0, 5.3), 1.3)
	var info := B.sign_plate(self, "VANHA HERRA\nSukellus laiturilla\nPumppu vuorotellen A ja D", plate_bg, plate_fg, 0.34, 60, plate_edge)
	info.position = Vector3(5.9, 1.5, 5.2)
	info.rotation_degrees.x = -35.0
	_vitrine(Vector3(-4.5, 0, -1.9))
	_pump_unit()
	_hose()
	# Pollareita, laatikkopino ja köysikerä.
	for bx in [0.6, 6.2]:
		B.mesh(self, B.cyl(0.14, 0.18, 0.5, 12), Vector3(bx, 0.25, EDGE_Z + 0.3), Color(0.2, 0.2, 0.22))
		B.mesh(self, B.sphere(0.17, 10), Vector3(bx, 0.52, EDGE_Z + 0.3), Color(0.24, 0.24, 0.27))
	for k in 3:
		B.mesh(self, B.boxm(Vector3(0.7, 0.4, 0.5)), Vector3(7.0, 0.2 + floorf(k / 2.0) * 0.4, -0.2 + (k % 2) * 0.1 + floorf(k / 2.0) * 0.1), Color(0.6, 0.45, 0.28).darkened(0.1 * k))
	B.mesh(self, B.cyl(0.25, 0.25, 0.14, 14), Vector3(0.4, 0.07, 0.8), Color(0.72, 0.62, 0.42))
	B.mesh(self, B.cyl(0.1, 0.1, 0.16, 12), Vector3(0.4, 0.08, 0.8), stone)
	_build_boat(Vector3(5.8, WATER_Y + 0.1, -3.7), 14.0)
	# Sukeltaja valmiina reunalla (katsoo +Z:aan): kangaspuku, kuparikypärä, lyijyvyö.
	_diver = Looks.make(self, {"shirt": Color(0.5, 0.4, 0.24), "pants": Color(0.46, 0.37, 0.22), "shoes": Color(0.25, 0.26, 0.29),
		"hair": "", "skin": Color(0.9, 0.72, 0.62), "height": 1.78, "bulk": 0.2})
	_diver.position = DIVER_AT
	_diver.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_diver.play("Idle", 0.0)
	_add_helmet(_diver)
	# Pumppaaja: sininen työpaita, lippalakki ja parta.
	_pumper = Looks.make(self, {"shirt": Color(0.28, 0.4, 0.58), "pants": Color(0.28, 0.27, 0.32), "shoes": Color(0.15, 0.1, 0.08),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.7, 0.7, 0.68), "beard": true, "height": 1.74, "skin": Color(0.9, 0.72, 0.62)})
	_pumper.position = PUMPER_AT
	_pumper.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_pumper.play("Idle", 0.0)
	_add_cap(_pumper)
	_bub_p = B.bubble(self, BUBBLE_P, Color.WHITE, 0.9)
	_bub_d = B.bubble(self, BUBBLE_D, Color.WHITE, 0.9)
	for lx in [-3.5, 3.5]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(lx, 3.6, 1.0)
		lamp.light_color = Color(1.0, 0.97, 0.9)
		lamp.light_energy = 1.0
		lamp.omni_range = 11.0
		add_child(lamp)


## Kuparikypärä sukeltajan päähän (kasvot -Z hahmon avaruudessa): pallo, kolme lasia, kaulus ja letkun liitin selässä.
func _add_helmet(ch: Node3D) -> void:
	var copper := Color(0.78, 0.46, 0.24)
	var glass := Color(0.12, 0.24, 0.3)
	var h := Node3D.new()
	var dome := B.mesh(h, B.sphere(0.5, 20), Vector3(0, 0.02, 0), copper)
	dome.scale = Vector3(0.5, 0.5, 0.5)
	B.mesh(h, B.cyl(0.16, 0.19, 0.07, 16), Vector3(0, -0.2, 0), copper.darkened(0.25))  # kaulus
	B.mesh(h, B.cyl(0.075, 0.075, 0.04, 14), Vector3(0, 0.02, -0.235), copper.darkened(0.3), Vector3(90, 0, 0))
	B.mesh(h, B.cyl(0.058, 0.058, 0.05, 14), Vector3(0, 0.02, -0.24), glass, Vector3(90, 0, 0))
	for sx in [-1.0, 1.0]:
		B.mesh(h, B.cyl(0.062, 0.062, 0.04, 12), Vector3(sx * 0.215, 0.02, -0.08), copper.darkened(0.3), Vector3(0, 0, 90))
		B.mesh(h, B.cyl(0.046, 0.046, 0.05, 12), Vector3(sx * 0.22, 0.02, -0.08), glass, Vector3(0, 0, 90))
	B.mesh(h, B.cyl(0.05, 0.05, 0.05, 12), Vector3(0, 0.02, 0.24), copper.darkened(0.2), Vector3(90, 0, 0))  # letkun liitin
	B.mesh(h, B.cyl(0.04, 0.04, 0.05, 12), Vector3(0, 0.26, -0.05), copper.darkened(0.2))
	ch.attach("Head", h, Vector3(0, 0.1, 0))


func _add_cap(ch: Node3D) -> void:
	var cap := Node3D.new()
	var col := Color(0.14, 0.16, 0.24)
	var dome := B.mesh(cap, B.sphere(0.5, 14), Vector3(0, 0, 0), col)
	dome.scale = Vector3(0.23, 0.14, 0.25)
	B.mesh(cap, B.boxm(Vector3(0.2, 0.014, 0.1)), Vector3(0, -0.03, -0.15), col.darkened(0.3))  # lippa (kasvot -Z)
	B.mesh(cap, B.cyl(0.118, 0.118, 0.02, 16), Vector3(0, -0.055, 0), col.lightened(0.1))
	ch.attach("Head", cap, Vector3(0, 0.14, 0.0))
