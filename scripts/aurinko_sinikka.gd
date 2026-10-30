extends Node3D
## Sinikka ottaa aurinkoa Oravajärven uimarannalla iltapäivällä (world.gd _build_uimaranta, näkyvyys ja juttelu main.gd):
## selällään pyyhkeellä lappubikineissä aurinkolasit silmillä, pää rullatun pyyhkeen päällä, oikea käsi pään alla,
## vasen käsi vatsalla ja jalat suorina hieman auki. Olkihattu on hiekalla pään vieressä ja aurinkorasvapullo
## pyyhkeen vieressä. Kun pelaaja tulee lähelle (notice), lasit nousevat otsalle ja pää kääntyy pelaajaa kohti.
## Paikallinen -Z = järven puoli eli jalkojen pää, +Z = pään pää, kasvot +Y (Jantun malli, janttu.gd).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Pose := preload("res://scripts/pose.gd")  # kämmenen asento ja raajan sovitus vartalon pintaan

const POSE := "Death01"  # kaatumisen loppuasento: selällään
const TOWEL_TOP := 0.08  # pyyhkeen yläpinta (muiden rannan pyyhkeiden korkeus)
const TOWEL_W := 0.9
const TOWEL_COL := Color(0.98, 0.55, 0.15)
const SAND_Y := 0.065  # hiekan pinta pyyhkeen ympärillä (world.gd: hiekkalaikku y 0,05, paksuus 0,03)
const ROLL_R := 0.04  # rullatun pyyhkeen säde (litistyy 0,85:een)
const HEAD_TILT := 0.15  # pää hieman kallellaan levossa (along-akselin ympäri)
const SHADES_UP := Vector3(0, 0.075, -0.015)  # lasit otsalle hiusten päälle: ylös päälakea kohti ja otsatukan etupuolelle (lasien avaruus: kasvot -Z)
const SHADES_TILT := 0.4  # otsalla yläreuna kallistuu taakse otsan kaaren myötä

var body: Node3D
var placed := false
var _t := 0.0
var _bubble: Label3D
var _bubble_t := 0.0
var _notice_t := 0.0
var _turn := 0.0  # pään kierto pelaajaa kohti (-1...1, along-akselin ympäri)
var _turn_goal := 0.0
var _along := Vector3.BACK  # jaloista päähän hahmon (body) avaruudessa; tämän solmun avaruudessa +Z
var _side := Vector3.RIGHT  # hahmon avaruudessa: vaakasuora oikean käden puoli
var _shades: Node3D
var _shades_rest: Transform3D
var _lift := 0.0
var _nod := 0.0  # pään nosto rullan päälle (_place_head)
var _nod_axis := Vector3.RIGHT  # hahmon avaruudessa: kierto, joka nostaa päätä leuka rintaa kohti


func _ready() -> void:
	body = Looks.make(self, Looks.sinikka_aurinko())
	body.play(POSE, 0.0)
	body.anim.seek(body.anim_length(POSE), true)  # suoraan loppuasentoon ja siihen
	body.anim.speed_scale = 0.0
	_shades = body.find_child("Aurinkolasit", true, false) as Node3D
	if _shades != null:
		_shades_rest = _shades.transform
	_bubble = B.bubble(self, Vector3(0, 1.2, 0))
	visibility_changed.connect(_on_visibility)
	_on_visibility()


## Piilossa (muulloin kuin 12-17) ei ajeta mitään ruutukohtaista.
func _on_visibility() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	_t += delta
	if not placed:
		if _t > 0.1:
			_place()  # luiden paikat vasta, kun loppuasento on laskettu
		return
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""
	_notice_t -= delta
	if _notice_t <= 0.0:
		_turn_goal = 0.0
	_turn = move_toward(_turn, _turn_goal, delta * 2.0)
	_lift = move_toward(_lift, 1.0 if _notice_t > 0.0 else 0.0, delta * 3.0)
	if _shades != null:
		_shades.transform = _shades_rest.translated_local(SHADES_UP * _lift).rotated_local(Vector3.RIGHT, SHADES_TILT * _lift)
	# Hengitys: rintakehä nousee ja laskee hitaasti; pää kääntyy along-akselin ympäri pelaajaa kohti.
	body.set_override("spine_03", _side, sin(_t * 1.3) * 0.02)
	_set_neck(_nod, HEAD_TILT + _turn, false)


## Pelaaja tulee lähelle: lasit otsalle, pää kääntyy pelaajaa (kameraa) kohti ja puhekupla.
func notice(text: String, seconds := 4.0) -> void:
	_notice_t = seconds
	var cam := get_viewport().get_camera_3d()
	if cam != null and placed:
		var to: Vector3 = body.global_transform.affine_inverse() * cam.global_position
		# Positiivinen kierto along-akselin ympäri vie kasvot vasemmalle (-_side): oikealla oleva pelaaja = negatiivinen.
		# Tarkistettu kuvasta aurinko_sinikka_kuvat huomaa_kasvot (kamera +X:ssä, oikealla puolella, kasvot kameraan).
		_turn_goal = clampf(-to.dot(_side) * 0.5, -1.0, 1.0)
	if text != "":
		var head: Vector3 = body.transform * body.bone_position("Head")
		_bubble.rest = head + Vector3(0, 0.9, 0)
		_bubble.position = _bubble.rest
		_bubble.text = "Sinikka: " + text
		_bubble_t = seconds


## Lasit takaisin silmille ja pää lepoon.
func relax() -> void:
	_notice_t = 0.0
	_bubble_t = 0.0


## Luiden bones paistetun verkon (vain vartalo) alin korkeus tämän solmun avaruudessa; INF ilman näyttöä.
func _low(bones: Array) -> float:
	var low := INF
	for q in Pose.limb_points(body, self, bones, 1):
		low = minf(low, q.y)
	return low


## Takaraivon alin kohta: pääluun verkon pisteet pääluun päälaen puolella (niskan iho jää pois, se pysyy hartioilla).
func _occiput() -> float:
	var hz := _bw("Head").z
	var low := INF
	for q in Pose.limb_points(body, self, ["Head"], 1):
		if q.z > hz + 0.02:
			low = minf(low, q.y)
	return low


func _bw(bn: String) -> Vector3:
	return body.transform * body.bone_position(bn)


## Asento pyyhkeelle laskemalla: pää +Z:aan, selkä pyyhkeen pintaan, jalat suoriksi, oikea käsi rullalle pään alle
## ja vasen vatsalle. Sitten pyyhe, rulla, hattu ja rasvapullo hahmon mittojen mukaan. Paistetaan vain kerran.
func _place() -> void:
	placed = true
	# Pää +Z:aan (h0/f0 -> along): kierto -a vie suunnan (sin a, cos a) +Z-akselille.
	var h0: Vector3 = body.bone_position("Head")
	var f0: Vector3 = (body.bone_position("foot_l") + body.bone_position("foot_r")) / 2.0
	var a := atan2(h0.x - f0.x, h0.z - f0.z)
	body.rotation.y = -a
	var mid: Vector3 = Basis(Vector3.UP, body.rotation.y) * ((h0 + f0) / 2.0)
	body.position = Vector3(-mid.x, 0.0, -mid.z)
	var along := Vector3(0, 0, 1)  # tämän solmun avaruudessa: jaloista päähän
	# Kaikki sivusuunnat tästä: side_r = oikean olan puoli (kasvot ylös ja pää +Z, joten oikea on -X).
	var side_r := Vector3(signf((_bw("upperarm_r") - _bw("upperarm_l")).x), 0, 0)
	# Death01:n selkä on kaarella (rintakehä lantiota korkeammalla): koko vartalo kallistetaan sivuakselin ympäri niin,
	# että pakarat ja lapaluut ovat samalla korkeudella. X-kierto +th laskee +Z-pään (rintakehän) alas.
	for k in 3:
		body.refresh_pose()
		var pel := _low(["pelvis"])
		var chest := _low(["spine_03"])
		if pel == INF or chest == INF:
			break
		var th := atan2(chest - pel, (_bw("spine_03") - _bw("pelvis")).z)
		body.transform = Transform3D(Basis(Vector3.RIGHT, th), Vector3.ZERO) * body.transform
	body.refresh_pose()
	var low := _low(["pelvis", "spine_01", "spine_02", "spine_03"])
	if low < INF:
		body.position.y += TOWEL_TOP + 0.005 - low
	body.refresh_pose()
	_side = body.basis.inverse() * side_r
	_along = body.basis.inverse() * along
	_place_legs(along, side_r)
	var roll := _place_head(along, side_r)
	_place_right_hand(along, side_r, roll)
	_place_left_hand(along, side_r)
	body.refresh_pose()
	_build_props(along, side_r, roll)


## Jalat suoriksi ja hieman auki: sama out-vektori kohteeseen, polven poleen ja varpaiden suuntaan. Nilkan korkeus
## haetaan niin, että pohje lepää pyyhkeellä (paistetusta verkosta); kantapää saa painua pyyhkeeseen enintään 1 cm.
## Varpaat käännetään loppuluun lisäkierrolla (twist) ylös ja hieman ulos: nilkkojen rento asento makuulla.
func _place_legs(along: Vector3, side_r: Vector3) -> void:
	var inv := body.transform.affine_inverse()
	var to_local := body.basis.inverse()
	var mid_hip: Vector3 = (_bw("thigh_l") + _bw("thigh_r")) / 2.0
	for lr: String in ["_l", "_r"]:
		var hip := _bw("thigh" + lr)
		var reach: float = (body.bone_position("thigh" + lr).distance_to(body.bone_position("calf" + lr))
			+ body.bone_position("calf" + lr).distance_to(body.bone_position("foot" + lr))) * 0.98
		var out := side_r * signf((hip - mid_hip).dot(side_r)) * 0.06
		var toes := (Vector3.UP * 0.8 - along * 0.45 + out.normalized() * 0.3).normalized()
		var ty := TOWEL_TOP + 0.07
		var tw := Basis()
		for k in 5:
			var run := sqrt(maxf(reach * reach - out.length_squared() - pow(hip.y - ty, 2.0), 0.01))
			var tgt: Vector3 = Vector3(hip.x, ty, hip.z) - along * run + out
			var knee: Vector3 = (hip + tgt) / 2.0 + Vector3(0, 0.3, 0) + out
			body.set_ik("leg" + lr, "thigh" + lr, "calf" + lr, "foot" + lr, inv * tgt, inv * knee, Basis())
			body.refresh_pose()
			var cur: Vector3 = (body.bone_position("ball" + lr) - body.bone_position("foot" + lr)).normalized()
			tw = Basis(Quaternion(cur, to_local * toes))
			body.set_ik("leg" + lr, "thigh" + lr, "calf" + lr, "foot" + lr, inv * tgt, inv * knee, tw)
			body.refresh_pose()
			var calf := _low(["calf" + lr])
			var heel := _low(["foot" + lr, "ball" + lr])
			if calf == INF:
				break
			var dy := TOWEL_TOP + 0.01 - calf
			if heel < INF:
				dy = maxf(dy, TOWEL_TOP - 0.01 - heel)  # kantapää ei painu syvemmälle kuin 1 cm
			ty += dy
		print("AURINKO jalka%s nilkka y=%.3f pohje %.3f kantapää %.3f" % [lr, ty, _low(["calf" + lr]) - TOWEL_TOP, _low(["foot" + lr, "ball" + lr]) - TOWEL_TOP])


## Rulla pään alle takaraivon kohdalle poikittain. Death01:n pää on taipunut taakse (leuka ylhäällä): niskaa ja päätä
## taivutetaan (puoliksi kumpaakin) leuka rintaa kohti, kunnes takaraivon alin kohta on rullan pinnassa.
## Kiinnitykset (lasit, korut) jätetään pois: BoneAttachment päivittyy vasta ruudun lopussa. Palauttaa rullan keskipisteen.
func _place_head(along: Vector3, side_r: Vector3) -> Vector3:
	var head := _bw("Head")
	var roll := Vector3(head.x, TOWEL_TOP + ROLL_R * 0.85, head.z + 0.04)
	var rest_y := TOWEL_TOP + ROLL_R * 1.7
	# Kierto side_r-akselin ympäri: kumpi etumerkki nostaa päätä, kokeillaan kerran.
	_nod_axis = body.basis.inverse() * side_r
	_set_neck(0.2, 0.0)
	var up_a := _occiput()
	_set_neck(-0.2, 0.0)
	if _occiput() > up_a:
		_nod_axis = -_nod_axis
	var lo_a := -0.4
	var hi_a := 0.8
	for k in 16:
		_nod = (lo_a + hi_a) / 2.0
		_set_neck(_nod, 0.0)
		if _occiput() < rest_y:
			lo_a = _nod
		else:
			hi_a = _nod
	print("AURINKO niska+pää %.2f rad kumpikin, takaraivo %.3f (tavoite %.3f)" % [_nod, _occiput(), rest_y])
	return roll


## Pään nyökkäys (nod, leuka rintaa kohti, puoliksi niskasta ja päästä) ja kääntö (turn, along-akselin ympäri) yhtenä
## kiertona kummallekin luulle: set_override pitää yhden akselin luuta kohden.
func _set_neck(nod: float, turn: float, refresh := true) -> void:
	var q := Quaternion(_along.normalized(), turn * 0.5) * Quaternion(_nod_axis.normalized(), nod)
	for bn in ["neck_01", "Head"]:
		body.set_override(bn, q.get_axis(), q.get_angle())
	if refresh:
		body.refresh_pose()


## Oikea käsi pään taakse: ranne rullan päällä pään oikealla puolella, kämmen alas rullaan ja sormet vinosti
## takaraivon taakse päälaen puolelle (hiukset painuvat kämmenen alle). Kyynärpää ulos sivulle, ylös ja hieman pään suuntaan.
func _place_right_hand(along: Vector3, side_r: Vector3, roll: Vector3) -> void:
	var inv := body.transform.affine_inverse()
	var top := roll.y + ROLL_R * 0.85
	var wrist := Vector3(roll.x, top + 0.026, roll.z) + side_r * 0.11
	var pole := wrist + side_r * 0.3 + Vector3(0, 0.25, 0) + along * 0.1
	body.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * wrist, inv * pole)
	var to_local := body.basis.inverse()
	var fingers := (-side_r * 0.6 + along * 0.8).normalized()
	body.set_ik_orient("arm_r", Pose.palm_on(to_local * fingers, to_local * Vector3.DOWN, false), 1.0)
	_curl("_r", (to_local * fingers).cross(to_local * Vector3.DOWN).normalized())


## Vasen käsi vatsalle (janttu.gd _place_props): kämmen vatsan pinnalla napaa kohti (spine_01:n kohdalla), kyynärpää
## kyljen vieressä pyyhkeellä rinnan alapuolella, kyynärvarsi nousee kyljeltä vatsan päälle. Korkeudet paistetusta
## verkosta: kämmen hihan verran vatsan pinnan yllä, ja jos käsivarsi painuu vartaloon, kämmentä nostetaan.
func _place_left_hand(along: Vector3, side_r: Vector3) -> void:
	var torso := Pose.limb_points(body, self, ["pelvis", "spine_01", "spine_02", "spine_03"], 1)
	var top := func(p: Vector3) -> float:
		var y := Pose.top_y(torso, p, 0.04)
		return y if y > -INF else TOWEL_TOP
	var side_l := -side_r
	var inv := body.transform.affine_inverse()
	var to_local := body.basis.inverse()
	var s := _bw("upperarm_l")
	# Kämmenen tyvi navan yläpuolelle (spine_01): kyynärpää on rinnan alapuolella vain, jos kämmen on näin alhaalla.
	var belly := _bw("spine_01")
	var hp := Vector3(belly.x, 0, belly.z) + side_l * 0.04 + along * 0.04
	var out := 0.25  # kyynärpään suunta (pole): kyljen vieressä pyyhkeellä, rinnan alapuolella
	var lift := 0.0
	for k in 10:
		var e := s - along * 0.22 + side_l * out
		e.y = TOWEL_TOP
		hp.y = top.call(hp) + 0.035 + lift
		body.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", inv * hp, inv * e)
		body.refresh_pose()
		# Olkavarsi rinnan sisällä: kyynärpää kauemmas sivulle; kyynärvarsi tai kämmen vatsan sisällä: kämmen ylemmäs.
		var need_u := 0.0
		var need_l := 0.0
		for r in Pose.clearance(body, self, ["upperarm_l", "lowerarm_l", "hand_l"], torso, 6):
			if r[0] == "upperarm_l":
				if r[1] >= 0.5:
					need_u = maxf(need_u, 0.045 - r[2])
			else:
				need_l = maxf(need_l, 0.042 - r[2])
		if need_u <= 0.002 and need_l <= 0.002:
			break
		out += maxf(need_u, 0.0) * 2.0
		lift += maxf(need_l, 0.0)
	var d := 0.04
	var dydx: float = (top.call(hp + Vector3(d, 0, 0)) - top.call(hp - Vector3(d, 0, 0))) / (2.0 * d)
	var dydz: float = (top.call(hp + Vector3(0, 0, d)) - top.call(hp - Vector3(0, 0, d))) / (2.0 * d)
	var up_n := Vector3(-dydx, 1.0, -dydz).normalized()  # vatsan pinnan normaali kämmenen kohdalla
	# Sormet kyynärvarren jatkeena vatsan pinnan suuntaisesti, ranne hieman taittuneena vatsan poikki (kohti oikeaa
	# kylkeä), jotta sormet jäävät navan korkeudelle eivätkä valu bikinien alaosalle.
	var fa := hp - _bw("lowerarm_l")
	fa.y = 0.0
	var fd := fa.normalized() + side_r * 0.8
	var fingers := to_local * (fd - up_n * fd.dot(up_n)).normalized()
	body.set_ik_orient("arm_l", Pose.palm_on(fingers, to_local * -up_n, true), 1.0)
	_curl("_l", fingers.cross(to_local * -up_n).normalized())
	body.refresh_pose()
	print("AURINKO vasen kyynärpää %s, kämmen %s, nosto %.3f, pole sivulle %.2f" % [_bw("lowerarm_l"), hp, lift, out])


## Sormet rennosti koukkuun (animaation levitetyt sormet pois), janttu.gd _curl_fingers. axis = sormet × kämmenen
## normaali (pintaan päin) hahmon avaruudessa: positiivinen kierto taivuttaa sormet kämmenen puolelle.
func _curl(lr: String, axis: Vector3) -> void:
	for f: String in ["index", "middle", "ring", "pinky"]:
		body.set_override(f + "_01" + lr, axis, 0.2)
		body.set_override(f + "_02" + lr, axis, 0.3)
		body.set_override(f + "_03" + lr, axis, 0.2)


## Pyyhe (pituus hahmosta: päälaki-varpaat + 0,3 m), rullattu pyyhe pään alla, olkihattu hiekalla pään vasemmalla
## puolella ja aurinkorasvapullo pyyhkeen oikealla puolella lantion kohdalla. Hiukset painuvat rullaa ja pyyhettä vasten.
func _build_props(along: Vector3, side_r: Vector3, roll: Vector3) -> void:
	var head := _bw("Head")
	var toes := minf(_bw("ball_l").z, _bw("ball_r").z) - 0.08
	var crown := head.z + 0.22
	var length := crown - toes + 0.3
	var zc := (crown + toes) / 2.0
	var towel := Node3D.new()
	towel.name = "Pyyhe"
	add_child(towel)
	B.mesh(towel, B.boxm(Vector3(TOWEL_W, 0.02, length)), Vector3(0, TOWEL_TOP - 0.01, zc), TOWEL_COL)
	for e in [-1.0, 1.0]:  # päätyjen raidat ja hapsut
		var z: float = zc + e * (length / 2.0 - 0.12)
		B.mesh(towel, B.boxm(Vector3(TOWEL_W, 0.021, 0.07)), Vector3(0, TOWEL_TOP - 0.01, z), Color(0.98, 0.95, 0.88))
		B.mesh(towel, B.boxm(Vector3(TOWEL_W, 0.021, 0.025)), Vector3(0, TOWEL_TOP - 0.01, z - e * 0.07), Color(0.85, 0.2, 0.3))
		for i in 12:
			var x := -TOWEL_W / 2.0 + 0.04 + i * (TOWEL_W - 0.08) / 11.0
			B.mesh(towel, B.boxm(Vector3(0.012, 0.004, 0.05)), Vector3(x, SAND_Y + 0.002, zc + e * (length / 2.0 + 0.025)), TOWEL_COL.darkened(0.1))
	# Rulla: pehmeä (hiukset painuvat siihen, asentotarkistus ohittaa), poikittain sivuakselin suuntaan, litistynyt.
	var rc := Color(0.2, 0.55, 0.85)
	var r := B.mesh(self, B.cyl(ROLL_R, ROLL_R, 0.5, 18), roll, rc, Vector3(0, 0, 90))
	r.scale = Vector3(0.85, 1, 1)  # paikallinen X = pysty kierron jälkeen
	r.set_meta("pehmea", true)  # pää ja käsi painuvat pyyhkerullaan
	for e in [-1.0, 1.0]:  # rullan päädyissä kierre: vaaleampi ja tummempi rengas
		var c1 := B.mesh(self, B.cyl(ROLL_R * 0.7, ROLL_R * 0.7, 0.004, 16), roll + side_r * e * 0.25, rc.lightened(0.25), Vector3(0, 0, 90))
		c1.scale = Vector3(0.85, 1, 1)
		c1.set_meta("pehmea", true)
		var c2 := B.mesh(self, B.cyl(ROLL_R * 0.35, ROLL_R * 0.35, 0.006, 12), roll + side_r * e * 0.25, rc.darkened(0.3), Vector3(0, 0, 90))
		c2.scale = Vector3(0.85, 1, 1)
		c2.set_meta("pehmea", true)
	var top := roll.y + ROLL_R * 0.85
	body.set_contacts([
		[Transform3D(Basis(), Vector3(roll.x, top - 0.02, roll.z)), Vector3(0.25, 0.02, ROLL_R)],
		[Transform3D(Basis(), Vector3(0, TOWEL_TOP - 0.02, head.z + 0.2)), Vector3(TOWEL_W / 2.0, 0.02, 0.25)],
	].map(func(b: Array) -> Array: return [global_transform * (b[0] as Transform3D), b[1]]))
	# Olkihattu hiekalla (looks.gd add_glam: sama hattu), lieri maassa ja kupu ylöspäin.
	var straw := Color(0.93, 0.85, 0.62)
	var hat := Node3D.new()
	hat.name = "Olkihattu"
	add_child(hat)
	hat.position = Vector3(0, SAND_Y + 0.006, head.z + 0.05) - side_r * (TOWEL_W / 2.0 + 0.33)
	hat.rotation = Vector3(0, 0.6, deg_to_rad(3))
	B.mesh(hat, B.cyl(0.3, 0.3, 0.012, 32), Vector3.ZERO, straw)
	B.mesh(hat, B.cyl(0.1, 0.115, 0.11, 24), Vector3(0, 0.055, 0), straw)
	B.mesh(hat, B.cyl(0.117, 0.117, 0.035, 24), Vector3(0, 0.02, 0), Color(0.8, 0.03, 0.1))
	# Aurinkorasvapullo pystyssä hiekalla: oranssi pullo, valkoinen korkki ja nokka, etiketissä aurinko.
	var pel := _bw("pelvis")
	var bottle := Node3D.new()
	bottle.name = "Aurinkorasva"
	add_child(bottle)
	bottle.position = Vector3(0, SAND_Y, pel.z) + side_r * (TOWEL_W / 2.0 + 0.12)
	bottle.rotation.y = 0.4
	B.mesh(bottle, B.cyl(0.032, 0.036, 0.15, 16), Vector3(0, 0.075, 0), Color(0.98, 0.55, 0.1))
	B.mesh(bottle, B.cyl(0.026, 0.032, 0.02, 16), Vector3(0, 0.16, 0), Color(0.98, 0.55, 0.1).darkened(0.1))  # olka
	B.mesh(bottle, B.cyl(0.02, 0.022, 0.035, 12), Vector3(0, 0.187, 0), Color(0.96, 0.96, 0.94))  # korkki
	B.mesh(bottle, B.cyl(0.005, 0.007, 0.015, 8), Vector3(0, 0.211, 0), Color(0.96, 0.96, 0.94))  # nokka
	B.mesh(bottle, B.cyl(0.0365, 0.0365, 0.06, 16), Vector3(0, 0.07, 0), Color(0.98, 0.95, 0.85))  # etiketti
	var sun := B.mesh(bottle, B.sphere(0.5, 10), Vector3(0, 0.078, -0.035), Color(1.0, 0.8, 0.1))
	sun.scale = Vector3(0.03, 0.03, 0.008)
	var band := B.mesh(bottle, B.boxm(Vector3(0.05, 0.008, 0.004)), Vector3(0, 0.055, -0.036), Color(0.9, 0.3, 0.1))
