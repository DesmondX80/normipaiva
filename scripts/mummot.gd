extends Node3D
## K-Marketin edustan mummot (#14): kaksi istuu penkillä, kolmas seisoo rollaattorinsa takana keppi kahvassa.
## Liian läheltä ja lujaa pyöräilevä tai kelloa soittava (anger) suututtaa penkin mummot: ne heittelevät
## kettukarkkeja kaaressa hetken ajan. Osuma horjauttaa (hit). Maahan jääneet karkit voi poimia jalan
## (candy_picked). Rollaattorimummon viereen ei kannata mennä: hän tarttuu keppiin ja huitaisee. Kepin varsi
## lasketaan joka ruutu kädestä kärkeen; osuma päähän tappaa (killed), kylkeen horjauttaa (hit).
## Paikallinen +Z = penkiltä parkkipaikalle päin, ja mummot katsovat sinne (hahmon malli katsoo -Z:aan).

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")

const ANGER_DIST := 4.0
const ANGER_SPEED := 5.0  # pyörän vauhti (m/s), jota lujempaa ohi kurvaava suututtaa
const ANGER_TIME := 6.0
const THROW_RANGE := 18.0
const FLIGHT := 0.9
const HIT_DIST := 1.1
const PICK_DIST := 0.9
const CANDY_LIFE := 40.0
const ANGRY_LINES := ["Hullu!", "Nuoriso nykyään!", "Katos pyörääs!", "Poliisi pittää kutsua!", "Senki pölijä!"]
const CALM_LINES := ["Kattokaa ny tuota.", "Ennen oli kaikki paremmin.", "Kallistunu taas maito.", "Onko se Päivin mies?"]
const SWING_LINES := ["Mitäs siinä notkut?!", "Hus siitä!", "Pois tieltä, nulikka!", "Älä tuu siihen!", "Kyllä mää sulle näytän!"]

# Penkki: istuimen yläpinta ja syvyys (z -SEAT_D/2 .. +SEAT_D/2), selkänoja takareunassa.
const SEAT_TOP := 0.44
const SEAT_D := 0.44
const BENCH_W := 2.0
const SITTERS := [-0.5, 0.5]  # istuvien mummojen x
const HIP_OVER_SEAT := 0.1  # lonkkaluun korkeus istuimen pinnasta (pakarat välissä)
const HIP_Z := -0.06  # lonkkaluun paikka istuimella (selkä nojaa taakse)
const FOOT_Y := 0.055  # jalkaterän luun korkeus maasta, kun jalka on lattialla
# Rollaattorimummo: seisoo penkin oikealla puolella, rollaattori edessään.
const STAND_POS := Vector3(2.05, 0, 0.2)
const ROLL_Z := 0.42  # rollaattorin takapyörien akseli mummon edessä
const GRIP := Vector3(0.25, 0.84, -0.16)  # oikean kahvan kädensija rollaattorin avaruudessa (vasen = -x)
const SWING_DIST := 1.5  # tätä lähempänä mummo tarttuu keppiin
const SWING_COOLDOWN := 2.2
const WIND := 0.6  # keppi nousee
const STRIKE := 0.22  # huitaisu
const BACK := 0.7  # käsi takaisin kahvalle
const CANE_LEN := 0.86  # kädestä kärkeen
const HEAD_R := 0.15  # pään säde + kepin paksuus
const BODY_R := 0.3

signal hit(direction: Vector3)
signal candy_picked
signal angered  # mummot suuttuivat (main.gd: moraali laskee)
signal killed  # keppi osui päähän

var target: Node3D
var anger_speed := ANGER_SPEED  # päivän tilat (#18) säätävät herkkyyttä

var _grans: Array[Node3D] = []  # 0–1 penkillä, 2 rollaattorin takana
var _bubbles: Array[Label3D] = []
var _bubble_t: Array[float] = [0.0, 0.0, 0.0]
var _throw_t: Array[float] = [0.0, 0.0]
var _angry := 0.0
var _chat_t := 6.0
var _flying: Array = []  # {node, from, to, t}
var _ground: Array = []  # {node, age}
var _stand: Node3D  # rollaattorimummo ja rollaattori, kääntyy kohti tulijaa
var _stand_yaw := 0.0
var _hooked_cane: Node3D  # keppi rollaattorin kahvassa
var _hand_cane: Node3D  # sama keppi kädessä (top_level)
var _swing_t := 0.0  # > 0: huitaisu käynnissä (aika alusta)
var _swing_cd := 0.0
var _swing_done := false  # tämän huitaisun osuma jo käsitelty
var _prev_seg: Array = []  # edellisen ruudun [käsi, kärki] (pyyhkäisy ruutujen välissä)
var _stars: Array = []  # {node, vel, age}
var _aim := Vector3(0, 0, -1)  # lyönnin vaakasuunta hahmon avaruudessa (kohti tulijan päätä), lukittuu lyönnin alkaessa
var _aim_e := 0.3  # pään korotuskulma olasta
var _strike_from := Vector3.ZERO  # käsi lyönnin lopussa (paluun alku)


func _ready() -> void:
	_build_bench()
	for i in 3:
		var g := Looks.make(self, Looks.MUMMOT[i])
		_grans.append(g)
		_dress(g, Looks.MUMMOT[i])
	for i in SITTERS.size():
		_seat(_grans[i], SITTERS[i])
	_build_stander(_grans[2])
	for i in 3:
		var head: Vector3 = _grans[i].global_transform * _grans[i].bone_position("Head")
		_bubbles.append(B.bubble(self, to_local(head) + Vector3(0, 0.5, 0.1), Color.WHITE))


# --- Rakennus ------------------------------------------------------------------

## Puinen säleistö valurautajaloilla ja käsinojilla: kolme istuinlautaa, kaksi selkälautaa.
func _build_bench() -> void:
	var wood := Color(0.55, 0.35, 0.18)
	var iron := Color(0.16, 0.17, 0.18)
	for k in 3:
		var z := -SEAT_D / 2.0 + 0.075 + k * (SEAT_D - 0.15) / 2.0
		B.mesh(self, B.boxm(Vector3(BENCH_W, 0.035, 0.13)), Vector3(0, SEAT_TOP - 0.018, z), wood.lightened(0.04 * k))
		B.mesh(self, B.boxm(Vector3(BENCH_W - 0.02, 0.012, 0.11)), Vector3(0, SEAT_TOP - 0.04, z), wood.darkened(0.35))
	for k in 2:
		var y := SEAT_TOP + 0.2 + k * 0.17
		B.mesh(self, B.boxm(Vector3(BENCH_W, 0.12, 0.03)), Vector3(0, y, -SEAT_D / 2.0 - 0.02 - k * 0.025), wood.lightened(0.03 * k),
			Vector3(-9, 0, 0))
	for x in [-BENCH_W / 2.0 + 0.1, BENCH_W / 2.0 - 0.1]:
		B.mesh(self, B.boxm(Vector3(0.05, SEAT_TOP, 0.05)), Vector3(x, SEAT_TOP / 2.0, SEAT_D / 2.0 - 0.05), iron)
		B.mesh(self, B.boxm(Vector3(0.05, SEAT_TOP + 0.45, 0.05)), Vector3(x, (SEAT_TOP + 0.45) / 2.0, -SEAT_D / 2.0 - 0.02), iron,
			Vector3(-5, 0, 0))
		B.mesh(self, B.boxm(Vector3(0.05, 0.04, SEAT_D)), Vector3(x, SEAT_TOP - 0.06, 0), iron)
		B.mesh(self, B.boxm(Vector3(0.06, 0.035, SEAT_D - 0.02)), Vector3(x, SEAT_TOP + 0.22, 0.0), wood.darkened(0.1))
		B.mesh(self, B.boxm(Vector3(0.04, 0.22, 0.04)), Vector3(x, SEAT_TOP + 0.11, SEAT_D / 2.0 - 0.05), iron)
	var body := StaticBody3D.new()
	add_child(body)
	body.add_child(B.box_shape(Vector3(BENCH_W, 1.0, 0.6), Vector3(0, 0.5, 0)))
	body.add_child(B.box_shape(Vector3(0.7, 1.0, 0.9), STAND_POS + Vector3(0, 0.5, 0.3)))


## Istuva mummo penkille: lantio istuimelle ja jalat maahan lasketaan istuma-animaation luista.
func _seat(g: Node3D, x: float) -> void:
	g.rotation.y = PI
	g.position = Vector3(x, 0, 0)
	g.play("Sitting_Idle", 0.0)
	g.anim.seek(randf() * 2.0, true)
	var pel: Vector3 = g.transform * g.bone_position("pelvis")
	g.position += Vector3(0, SEAT_TOP + HIP_OVER_SEAT - pel.y, HIP_Z - pel.z)
	# Jalkaterät lattiaan siihen kohtaan, mihin animaatio ne vie (hahmon avaruudessa).
	for side in ["_l", "_r"]:
		var f: Vector3 = g.bone_position("foot" + side)
		var foot := Vector3(f.x, FOOT_Y - g.position.y, f.z - 0.06)
		g.set_ik("leg" + side, "thigh" + side, "calf" + side, "foot" + side, foot, foot + Vector3(0, 0.5, -0.6))
	_lap_skirt(g)


## Rollaattorimummo: rollaattori edessä, kädet kahvoilla (IK), selkä kumarassa, keppi oikeassa kahvassa.
func _build_stander(g: Node3D) -> void:
	_stand = Node3D.new()
	_stand.position = STAND_POS
	add_child(_stand)
	remove_child(g)
	_stand.add_child(g)
	g.rotation.y = PI
	g.play("Idle", 0.0)
	g.set_override("spine_01", Vector3.RIGHT, -0.22)
	g.set_override("spine_02", Vector3.RIGHT, -0.12)
	g.set_override("neck_01", Vector3.RIGHT, 0.2)
	var roll := _rollator()
	roll.position = Vector3(0, 0, ROLL_Z)
	_stand.add_child(roll)
	_hooked_cane = _cane()
	_hooked_cane.position = Vector3(-GRIP.x - 0.05, GRIP.y + 0.012, GRIP.z + 0.05)
	_hooked_cane.rotation.y = -PI / 2.0
	roll.add_child(_hooked_cane)
	_hand_cane = _cane()
	_hand_cane.top_level = true
	_hand_cane.visible = false
	add_child(_hand_cane)
	_grip_hands(1.0)


## Kädet kahvoille: right_w = 1 oikea käsi kahvassa, 0 kädessä keppi (IK-kohde annetaan erikseen).
func _grip_hands(right_w: float) -> void:
	var g := _grans[2]
	for s in [[-1.0, "_l"], [1.0, "_r"]]:
		if s[1] == "_r" and right_w < 1.0:
			continue
		# Mummon oikea käsi on rollaattorin -x-puolella (mummo ja rollaattori katsovat +Z:aan).
		var gp := Vector3(-s[0] * GRIP.x, GRIP.y, ROLL_Z + GRIP.z)
		var h: Vector3 = g.transform.affine_inverse() * gp
		g.set_ik("arm" + s[1], "upperarm" + s[1], "lowerarm" + s[1], "hand" + s[1], h, h + Vector3(s[0] * 0.5, -0.2, 0.4))


## Rollaattori +Z:aan: punainen alumiinirunko, mustat kahvat jarrukahvoineen, istuinlauta, ostoskori
## edessä (K-kassi ja ruisleipä) ja neljä pyörää, edessä kääntyvät haarukat. Origo takapyörien välissä maassa.
func _rollator() -> Node3D:
	var r := Node3D.new()
	var red := Color(0.72, 0.08, 0.1)
	var black := Color(0.06, 0.06, 0.07)
	var steel := Color(0.72, 0.73, 0.75)
	for s in [-1.0, 1.0]:
		var x: float = s * GRIP.x
		var top := Vector3(x, GRIP.y - 0.03, GRIP.z + 0.1)
		var join := Vector3(x, 0.58, 0.04)
		B.tube(r, Vector3(x, 0.11, 0.0), top, 0.014, red)
		B.tube(r, Vector3(x, 0.15, 0.58), join, 0.014, red)
		B.tube(r, top, Vector3(x, GRIP.y, GRIP.z + 0.06), 0.014, red)
		# Kahva: musta vaahtomuovi, pää pyöristetty; jarrukahva sen alla ja vaijeri alas takapyörälle.
		B.tube(r, Vector3(x, GRIP.y, GRIP.z + 0.07), Vector3(x, GRIP.y, GRIP.z - 0.06), 0.02, black)
		B.mesh(r, B.sphere(0.021, 10), Vector3(x, GRIP.y, GRIP.z - 0.06), black)
		B.tube(r, Vector3(x, GRIP.y - 0.025, GRIP.z + 0.06), Vector3(x, GRIP.y - 0.04, GRIP.z - 0.05), 0.006, steel)
		B.tube(r, Vector3(x + s * 0.02, GRIP.y - 0.03, GRIP.z + 0.07), Vector3(x + s * 0.03, 0.5, 0.0), 0.004, black)
		B.tube(r, Vector3(x + s * 0.03, 0.5, 0.0), Vector3(x + s * 0.025, 0.14, 0.01), 0.004, black)
		# Pyörät: takana kiinteät, edessä kääntyvä haarukka.
		_wheel(r, Vector3(x, 0.1, 0.0), black, steel)
		B.tube(r, Vector3(x, 0.15, 0.58), Vector3(x, 0.1, 0.62), 0.012, steel)
		_wheel(r, Vector3(x, 0.1, 0.62), black, steel)
	# Poikkiputket, istuinlauta ja selkänojahihna.
	B.tube(r, Vector3(-GRIP.x, 0.56, 0.06), Vector3(GRIP.x, 0.56, 0.06), 0.012, red)
	B.tube(r, Vector3(-GRIP.x, 0.3, 0.5), Vector3(GRIP.x, 0.3, 0.5), 0.011, red)
	B.mesh(r, B.boxm(Vector3(GRIP.x * 2.0 - 0.02, 0.025, 0.28)), Vector3(0, 0.6, 0.2), Color(0.18, 0.22, 0.35))
	B.mesh(r, B.boxm(Vector3(GRIP.x * 2.0 - 0.06, 0.012, 0.25)), Vector3(0, 0.617, 0.2), Color(0.25, 0.3, 0.45))
	B.mesh(r, B.boxm(Vector3(GRIP.x * 2.0, 0.07, 0.015)), Vector3(0, 0.72, -0.02), Color(0.15, 0.15, 0.17))
	# Ostoskori istuimen alla edessä: verkkokori, jossa K-kassi ja ruisleipä.
	var basket := Color(0.12, 0.14, 0.2)
	B.mesh(r, B.boxm(Vector3(0.36, 0.2, 0.012)), Vector3(0, 0.42, 0.42), basket)
	B.mesh(r, B.boxm(Vector3(0.36, 0.012, 0.22)), Vector3(0, 0.32, 0.31), basket)
	for s in [-1.0, 1.0]:
		B.mesh(r, B.boxm(Vector3(0.012, 0.2, 0.22)), Vector3(s * 0.18, 0.42, 0.31), basket)
	B.mesh(r, B.boxm(Vector3(0.3, 0.2, 0.16)), Vector3(0, 0.44, 0.31), Color(1.0, 0.45, 0.0))
	var k := B.label(r, "K", Vector3(0, 0.45, 0.394), 14, Color.WHITE)
	k.double_sided = false
	B.mesh(r, B.boxm(Vector3(0.16, 0.08, 0.1)), Vector3(0.05, 0.57, 0.3), Color(0.24, 0.14, 0.08), Vector3(0, 17, 11))
	B.mesh(r, B.boxm(Vector3(0.15, 0.01, 0.09)), Vector3(0.05, 0.612, 0.3), Color(0.38, 0.24, 0.14), Vector3(0, 17, 11))
	return r


func _wheel(r: Node3D, at: Vector3, tire: Color, hub: Color) -> void:
	B.mesh(r, B.cyl(0.1, 0.1, 0.04, 20), at, tire, Vector3(0, 0, 90))
	B.mesh(r, B.cyl(0.055, 0.055, 0.045, 14), at, hub, Vector3(0, 0, 90))
	B.mesh(r, B.cyl(0.015, 0.015, 0.05, 8), at, tire.lightened(0.2), Vector3(0, 0, 90))


## Kävelykeppi: tumma puuvarsi, käyrä koukkukahva ja kumitulppa. Origo kahvan kaaren päällä (kämmen),
## varsi -Y:hen, koukku +Z:aan.
func _cane() -> Node3D:
	var c := Node3D.new()
	var wood := Color(0.3, 0.17, 0.08)
	var r := 0.045
	var prev := Vector3(0, -0.02, 0)
	for k in range(1, 9):
		var a := PI * k / 8.0
		var p := Vector3(0, r * sin(a) - 0.02, r - r * cos(a))
		B.tube(c, prev, p, 0.013, wood.lightened(0.1))
		B.mesh(c, B.sphere(0.013, 8), p, wood.lightened(0.1))
		prev = p
	B.tube(c, prev, prev + Vector3(0, -0.035, 0), 0.012, wood.lightened(0.1))
	B.tube(c, Vector3(0, -0.02, 0), Vector3(0, -CANE_LEN + 0.03, 0), 0.012, wood)
	B.mesh(c, B.cyl(0.013, 0.014, 0.012, 10), Vector3(0, -0.12, 0), Color(0.75, 0.65, 0.35))
	B.mesh(c, B.cyl(0.015, 0.016, 0.04, 10), Vector3(0, -CANE_LEN + 0.02, 0), Color(0.05, 0.05, 0.05))
	return c


## Mummon asusteet: permanenttikiharat, silmälasit, huivi tai huopahattu, käsilaukku tai kaulahuivi.
func _dress(g: Node3D, look: Dictionary) -> void:
	var k := float(look.get("height", 1.8)) / 1.8
	if look.has("perm"):
		Looks.add_perm(g, look.perm, k, look.has("hat"))
	if look.get("glasses", false):
		Looks.add_round_glasses(g, k)
	if look.has("hat"):
		var hat := Node3D.new()
		var col: Color = look.hat
		# Huopahattu: matala pyöreä kupu, kapea alaspäin taipuva lieri ja nauha rusetteineen.
		B.mesh(hat, B.cyl(0.098, 0.122, 0.016, 28), Vector3(0, -0.006, 0), col.darkened(0.15))
		B.mesh(hat, B.cyl(0.09, 0.1, 0.055, 24), Vector3(0, 0.026, 0), col)
		B.mesh(hat, B.sphere(0.09, 18), Vector3(0, 0.052, 0), col.lightened(0.04)).scale = Vector3(1.0, 0.45, 1.0)
		B.mesh(hat, B.cyl(0.101, 0.102, 0.02, 24), Vector3(0, 0.012, 0), Color(0.14, 0.1, 0.1))
		B.mesh(hat, B.sphere(0.022, 8), Vector3(0.085, 0.014, 0.04), Color(0.14, 0.1, 0.1)).scale = Vector3(0.5, 0.8, 1.2)
		hat.scale = Vector3.ONE * k * 1.05
		hat.rotation.x = deg_to_rad(-6)
		g.attach("Head", hat, Vector3(0, 0.15, -0.005) * k)
	if look.has("skirt"):
		var sk := Node3D.new()
		var col: Color = look.skirt
		var cone := B.mesh(sk, B.cyl(0.155, 0.235, 0.46, 24), Vector3(0, -0.23, 0), col)
		cone.scale = Vector3(1.0, 1.0, 0.85)
		B.mesh(sk, B.cyl(0.157, 0.157, 0.04, 24), Vector3(0, -0.015, 0), col.darkened(0.25)).scale = Vector3(1.0, 1.0, 0.85)
		for a in range(0, 360, 30):
			var f := B.mesh(sk, B.boxm(Vector3(0.012, 0.4, 0.012)), Vector3(cos(deg_to_rad(a)) * 0.19, -0.25,
				sin(deg_to_rad(a)) * 0.16), col.darkened(0.12))
			f.rotation = Vector3(sin(deg_to_rad(a)) * -0.17, 0, cos(deg_to_rad(a)) * 0.17)
		# Kävelytakin helma hameen päällä (peittää paidan ja hameen rajan).
		if look.has("coat_hem"):
			var hem := B.mesh(sk, B.cyl(0.17, 0.2, 0.12, 24), Vector3(0, 0.02, 0), look.shirt)
			hem.scale = Vector3(1.0, 1.0, 0.85)
			for b in 3:
				B.mesh(sk, B.sphere(0.008, 6), Vector3(0, 0.06 - b * 0.05, 0.172 + b * 0.008), look.shirt.darkened(0.5))
		sk.scale = Vector3.ONE * k
		g.attach("pelvis", sk, Vector3(0, 0.08, -0.01) * k)


## Hameen helmaa ei lisätä polvien eteen: levy näytti irralliselta tummalta laudalta (säärien väri tulee hahmon mallista).
func _lap_skirt(_g: Node3D) -> void:
	return


# --- Käytös --------------------------------------------------------------------

## Kello tai muu kiusanteko: suuttuvat varmasti.
func anger() -> void:
	if _angry <= 0.0:
		angered.emit()
		for i in 3:
			_say(i, "Mummo: " + ANGRY_LINES.pick_random())
		for i in _throw_t.size():
			_throw_t[i] = randf_range(0.2, 0.8)
	_angry = ANGER_TIME


func is_angry() -> bool:
	return _angry > 0.0


func distance_to_target() -> float:
	if target == null:
		return INF
	var d := target.global_position - global_position
	return Vector2(d.x, d.z).length()


func _process(delta: float) -> void:
	for i in 3:
		_bubble_t[i] -= delta
		if _bubble_t[i] <= 0.0:
			_bubbles[i].text = ""
	_update_candies(delta)
	_update_stars(delta)
	_update_stander(delta)
	if target == null:
		return
	var d := distance_to_target()
	var on_bike := target.has_method("set_rider_visible")
	if on_bike and d < ANGER_DIST and absf(float(target.get("speed"))) > anger_speed:
		anger()
	if _angry > 0.0:
		_angry -= delta
		if d > THROW_RANGE * 1.4:
			_angry = 0.0  # poistui: rauhoittuvat
		for i in _throw_t.size():
			_grans[i].play("Sitting_Talking", 0.2)
			_throw_t[i] -= delta
			if _throw_t[i] <= 0.0 and d < THROW_RANGE:
				_throw_t[i] = randf_range(1.2, 2.0)
				_throw(i)
		if _angry <= 0.0:
			_say(randi() % 3, "Mummo: No niin. Mennään kattomaan Salkkareita.")
		return
	for i in _throw_t.size():
		_grans[i].play("Sitting_Idle", 0.3)
	_chat_t -= delta
	if _chat_t <= 0.0 and d < 12.0:
		_chat_t = randf_range(7.0, 12.0)
		_say(randi() % 3, "Mummo: " + CALM_LINES.pick_random())


func _say(i: int, text: String) -> void:
	_bubbles[i].text = text
	_bubble_t[i] = 2.2


# --- Rollaattorimummon keppi ---------------------------------------------------

func _update_stander(delta: float) -> void:
	var g := _grans[2]
	_swing_cd -= delta
	var near := INF
	if target != null:
		var to := _stand.to_local(target.global_position)
		near = Vector2(to.x, to.z - 0.3).length()
		# Kääntyy rollaattoreineen tulijaa kohti (enintään ~55° kumpaankin suuntaan).
		if near < 5.0 and _swing_t < WIND:
			var want := clampf(atan2(to.x, to.z), -0.95, 0.95) + _stand_yaw
			want = clampf(want, -0.95, 0.95)
			_stand_yaw = move_toward(_stand_yaw, want, 1.6 * delta)
			_stand.rotation.y = _stand_yaw
		if _swing_t <= 0.0 and _swing_cd <= 0.0 and near < SWING_DIST:
			_swing_t = 0.001
			_swing_done = false
			_prev_seg = []
			_hooked_cane.visible = false
			_hand_cane.visible = true
			_say(2, "Mummo: " + SWING_LINES.pick_random())
			Sfx.play_at(g.global_position, "grunt", -8.0, 1.6)
	if _swing_t <= 0.0:
		return
	_swing_t += delta
	var grip_r: Vector3 = g.transform.affine_inverse() * Vector3(-GRIP.x, GRIP.y, ROLL_Z + GRIP.z)
	var sh: Vector3 = g.bone_position("upperarm_r")
	var t := _swing_t
	if t < WIND and target != null:
		# Tähtää nostovaiheen ajan; lyönti kulkee olan kautta pystytasossa kohti päätä.
		var d: Vector3 = g.to_local(_head_pos()) - (sh + Vector3(0, 0.3, 0))
		var flat := Vector2(d.x, d.z)
		if flat.length() > 0.05:
			_aim = Vector3(d.x, 0, d.z).normalized()
			_aim_e = atan2(d.y, flat.length())
	var hand: Vector3
	if t < WIND:
		hand = grip_r.lerp(sh + Vector3(0, 0.42, 0) - _aim * 0.1, smoothstep(0.0, 1.0, t / WIND))
	elif t < WIND + STRIKE:
		hand = sh + _arc_dir(_strike_phi(t)) * 0.5
		_strike_from = hand
		if _prev_seg.is_empty():
			Sfx.play_at(g.global_position + Vector3(0, 1.4, 0), "whoosh", -2.0, 0.8)
	elif t < WIND + STRIKE + BACK:
		hand = _strike_from.lerp(grip_r, smoothstep(0.0, 1.0, (t - WIND - STRIKE) / BACK))
	else:
		_swing_t = 0.0
		_swing_cd = SWING_COOLDOWN
		_hand_cane.visible = false
		_hooked_cane.visible = true
		_grip_hands(1.0)
		return
	g.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", hand, hand + Vector3(0.6, -0.3, 0.2))
	_place_cane(g, t)


## Kepin suunta hahmon avaruudessa (eteen -Z, oikealle +X): roikkuu kahvasta, nousee sivun kautta olan taakse
## ja lyö ylhäältä tähtäystasossa (_aim) pään läpi eteen alas, sitten laskeutuu takaisin. Huitaisun aikana varsi
## pyyhkäistään edellisen ruudun asennosta tähän ja tarkistetaan osumat.
const CANE_DOWN := Vector3(0, -1, 0)
const CANE_SIDE := Vector3(0.1, -0.8, 0.6)  # nousee selän takaa kärki alhaalla (ei penkin mummojen päiden yli)
const PHI_UP := 115.0  # kulma tähtäyssuunnasta ylöspäin lyönnin alussa (yli olan taakse)
const PHI_END := -40.0  # ja lopussa pään korotuskulman alapuolella


## Suunta tähtäystasossa: phi asteina vaakasuunnasta ylöspäin.
func _arc_dir(phi: float) -> Vector3:
	var r := deg_to_rad(phi)
	return _aim * cos(r) + Vector3.UP * sin(r)


func _strike_phi(t: float) -> float:
	return lerpf(PHI_UP, rad_to_deg(_aim_e) + PHI_END, pow(clampf((t - WIND) / STRIKE, 0.0, 1.0), 1.4))


func _cane_dir(t: float) -> Vector3:
	var down := CANE_DOWN.normalized()
	var side := CANE_SIDE.normalized()
	if t < WIND * 0.5:
		return down.slerp(side, smoothstep(0.0, 1.0, t / (WIND * 0.5)))
	if t < WIND:
		return side.slerp(_arc_dir(PHI_UP), smoothstep(0.0, 1.0, t / (WIND * 0.5) - 1.0))
	if t < WIND + STRIKE:
		return _arc_dir(_strike_phi(t))
	var end := _arc_dir(_strike_phi(WIND + STRIKE))
	return end.slerp(down, smoothstep(0.0, 1.0, (t - WIND - STRIKE) / BACK))


func _place_cane(g: Node3D, t: float) -> void:
	var hd: Vector3 = g.global_transform * g.bone_position("hand_r")
	var dir := (g.global_basis * _cane_dir(t)).normalized()
	var grip := hd + dir * 0.07
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.1:
		side = g.global_basis.x
	var xb := side.normalized()
	var yb := -dir
	_hand_cane.global_transform = Transform3D(Basis(xb, yb, xb.cross(yb)), grip)
	var tip := grip + dir * CANE_LEN
	if t >= WIND and t < WIND + STRIKE + 0.05 and not _swing_done and target != null:
		var seg := [grip, tip]
		var prev: Array = seg if _prev_seg.is_empty() else _prev_seg
		_prev_seg = seg
		var head := _head_pos()
		var body := target.global_position + Vector3(0, 1.1, 0)
		for k in 5:
			var u := k / 4.0
			var a: Vector3 = prev[0].lerp(seg[0], u)
			var b: Vector3 = prev[1].lerp(seg[1], u)
			if _seg_dist(head, a, b) < HEAD_R:
				_on_head_hit(head)
				return
			if _seg_dist(body, a, b) < BODY_R:
				_swing_done = true
				var push := target.global_position - _stand.global_position
				push.y = 0.0
				Sfx.play_at(body, "punch", -2.0, 0.9)
				hit.emit(push.normalized())
				_say(2, "Mummo: Ja seuraava osuu päähän!")
				return


func _on_head_hit(head: Vector3) -> void:
	_swing_done = true
	Sfx.play_at(head, "punch_heavy", 2.0, 0.8)
	Sfx.play_at(head, "axe", -6.0, 1.4)
	_say(2, "Mummo: Nuoriso ei kestä mittään.")
	for i in 10:
		var st := MeshInstance3D.new()
		st.mesh = B.sphere(0.03, 6)
		st.material_override = B.mat(Color(1.0, 0.9, 0.2)).duplicate()
		(st.material_override as StandardMaterial3D).emission_enabled = true
		(st.material_override as StandardMaterial3D).emission = Color(1.0, 0.8, 0.1)
		add_child(st)
		st.global_position = head
		var a := TAU * i / 10.0
		_stars.append({"node": st, "vel": Vector3(cos(a) * 1.2, randf_range(0.8, 1.8), sin(a) * 1.2), "age": 0.0})
	killed.emit()


func _update_stars(delta: float) -> void:
	for s in _stars.duplicate():
		s.age += delta
		s.vel.y -= 4.0 * delta
		var n: Node3D = s.node
		n.global_position += s.vel * delta
		n.scale = Vector3.ONE * maxf(0.0, 1.0 - s.age / 1.2)
		if s.age > 1.2:
			n.queue_free()
			_stars.erase(s)


## Pelaajan pään keskipiste: hahmon pääluusta (jalan _body, pyörällä _rider), muuten 1.68 m maasta.
func _head_pos() -> Vector3:
	for n in ["_body", "_rider"]:
		var c = target.get(n)
		if c is Node3D and c.has_method("bone_position") and c.is_visible_in_tree():
			return c.global_transform * c.bone_position("Head") + Vector3(0, 0.08, 0)
	return target.global_position + Vector3(0, 1.68, 0)


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * u)


# --- Kettukarkit -----------------------------------------------------------------

## Kettukarkki kaaressa kohti pelaajan ennakoitua paikkaa.
func _throw(i: int) -> void:
	var from: Vector3 = _grans[i].global_position + Vector3(0, 0.75, 0.3)
	var v: Vector3 = target.get("velocity") if target.get("velocity") != null else Vector3.ZERO
	var to := target.global_position + Vector3(v.x, 0, v.z) * FLIGHT + Vector3(randf_range(-1.3, 1.3), 0, randf_range(-1.3, 1.3))
	to.y = T.h(to.x, to.z) + 0.05
	var c := Node3D.new()
	var col: Color = [Color(0.95, 0.45, 0.05), Color(0.85, 0.1, 0.1), Color(0.95, 0.8, 0.1)].pick_random()
	B.mesh(c, B.boxm(Vector3(0.06, 0.04, 0.09)), Vector3.ZERO, col)
	get_tree().current_scene.add_child(c)
	c.global_position = from
	_flying.append({"node": c, "from": from, "to": to, "t": 0.0})
	Sfx.play_at(from, "whoosh", -10.0, 1.8)


func _update_candies(delta: float) -> void:
	for f in _flying.duplicate():
		f.t += delta / FLIGHT
		var u: float = minf(f.t, 1.0)
		var p: Vector3 = f.from.lerp(f.to, u)
		p.y += sin(u * PI) * 2.2
		f.node.global_position = p
		f.node.rotation += Vector3(9.0, 7.0, 0.0) * delta
		if u >= 1.0:
			_flying.erase(f)
			_ground.append({"node": f.node, "age": 0.0})
			if target != null and _flat(target.global_position, f.to) < HIT_DIST:
				var dir: Vector3 = (f.to - f.from)
				dir.y = 0.0
				Sfx.play_at(f.to, "punch", -6.0, 1.6)
				hit.emit(dir.normalized())
	for g in _ground.duplicate():
		g.age += delta
		var node: Node3D = g.node
		if g.age > CANDY_LIFE:
			node.queue_free()
			_ground.erase(g)
		elif target != null and not target.has_method("set_rider_visible") and g.age > 0.5 \
				and _flat(target.global_position, node.global_position) < PICK_DIST:
			node.queue_free()
			_ground.erase(g)
			Sfx.play("pickup", -8.0, 1.5)
			candy_picked.emit()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _exit_tree() -> void:
	for f in _flying:
		f.node.queue_free()
	for g in _ground:
		g.node.queue_free()
