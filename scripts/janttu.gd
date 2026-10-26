extends Node3D
## Janttu: Vaalan paikallinen, joka makaa kilipäissään puistonpenkin päällä poliisilaitosta vastapäätä (vaala.gd
## _build_poliisi). Maastotakki, pipo ja parransänki; selällään penkillä Alkon kassi tyynynä, käsi roikkuu, kossupullo
## ja kaljatölkit penkin alla. Rintakehä nousee ja laskee, ja ilmassa leijuu Zzz. Herää hetkeksi nostamaan päätään,
## kun hänelle tarjotaan (wake, main.gd _talk_janttu). Paikallinen -Z = penkin etupuoli (tielle ja asemalle päin).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Pose := preload("res://scripts/pose.gd")  # kämmenen asento ja raajan sovitus vartalon pintaan

const LOOK := {
	"shirt": Color(0.33, 0.36, 0.24), "pants": Color(0.2, 0.2, 0.24), "shoes": Color(0.12, 0.1, 0.08),
	"hair": "Hair_Buzzed", "hair_color": Color(0.42, 0.38, 0.33), "beard": true, "height": 1.76,
	"skin": Color(0.93, 0.76, 0.68), "belly": 0.55, "bulk": -0.1, "shoulders": -0.3,
}
const POSE := "Death01"  # kaatumisen loppuasento: selällään
const SEAT := 0.46  # istuinrimojen yläpinta
const BENCH_L := 2.1
const ZZZ := ["z", "zZ", "zZz"]

var body: Node3D
var awake_t := 0.0
var _zzz: Label3D
var _bubble: Label3D
var _bubble_t := 0.0
var _t := 0.0
var _props_placed := false
var _back := "_l"  # selän puoleinen (vatsalla lepäävä) käsi
var _curl_axis := Vector3.RIGHT  # sormien koukistusakseli hahmon avaruudessa: sormet × kämmenen normaali (alas vatsaan)


func _ready() -> void:
	_build_bench()
	body = Looks.make(self, LOOK)
	body.play(POSE, 0.0)
	body.anim.seek(body.anim_length(POSE), true)  # suoraan loppuasentoon ja siihen
	body.anim.speed_scale = 0.0
	_add_pipo()
	_zzz = Label3D.new()
	_zzz.font_size = 56
	_zzz.pixel_size = 0.005
	_zzz.modulate = Color(0.9, 0.95, 1.0)
	_zzz.outline_size = 10
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_zzz)
	_bubble = B.bubble(self, Vector3(0, 1.4, 0))


func _process(delta: float) -> void:
	_t += delta
	if not _props_placed and _t > 0.1:
		_place_props()  # luiden paikat vasta, kun loppuasento on laskettu
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""
	var head: Vector3 = body.transform * body.bone_position("Head")
	if awake_t > 0.0:
		awake_t -= delta
		_zzz.visible = false
		var up := clampf(minf(awake_t / 0.6, 1.0), 0.0, 1.0)  # nousee heti, painuu takaisin viimeisellä puolella sekunnilla
		body.set_override("neck_01", Vector3.RIGHT, -0.7 * up)
		body.set_override("Head", Vector3.RIGHT, -0.4 * up)
		if awake_t <= 0.0:
			body.clear_overrides()
			_curl_fingers()
		return
	# Uni: rintakehä nousee ja laskee, Zzz nousee pään yltä ja haalistuu.
	body.set_override("spine_03", Vector3.RIGHT, sin(_t * 1.6) * 0.05)
	_zzz.visible = true
	var ph := fmod(_t * 0.45, 1.0)
	_zzz.text = ZZZ[int(ph * 3.0)]
	_zzz.position = head + Vector3(ph * 0.15, 0.2 + ph * 0.35, 0)
	_zzz.modulate.a = 1.0 - ph * 0.7


## Herää hetkeksi nostamaan päätään ja sanomaan sanansa, sitten pää painuu takaisin kassille.
func wake(text: String, seconds := 5.0) -> void:
	awake_t = seconds
	var head: Vector3 = body.transform * body.bone_position("Head")
	_bubble.position = head + Vector3(0, 1.0, 0)
	_bubble.text = "Janttu: " + text
	_bubble_t = seconds


func _add_pipo() -> void:
	var pipo := Node3D.new()
	var col := Color(0.62, 0.12, 0.1)
	var cap := B.mesh(pipo, B.sphere(0.5, 14), Vector3(0, 0, 0), col)
	cap.scale = Vector3(0.21, 0.16, 0.22)
	B.mesh(pipo, B.cyl(0.108, 0.11, 0.05, 16), Vector3(0, -0.035, 0), col.darkened(0.25))  # käänne
	B.mesh(pipo, B.sphere(0.035, 8), Vector3(0, 0.085, 0), Color(0.9, 0.88, 0.8))  # tupsu
	body.attach("Head", pipo, Vector3(0, 0.13, -0.005))


## Makaava asento penkin suuntaiseksi (pää +X-päähän) ja istuimen päälle; sitten Alkon kassi pään alle tyynyksi
## ja pullo ja tölkit penkin alle maahan.
func _place_props() -> void:
	_props_placed = true
	var h0: Vector3 = body.bone_position("Head")
	var f0: Vector3 = (body.bone_position("foot_l") + body.bone_position("foot_r")) / 2.0
	var a := atan2(h0.x - f0.x, h0.z - f0.z)
	body.rotation.y = PI / 2.0 - a
	var mid: Vector3 = Basis(Vector3.UP, body.rotation.y) * ((h0 + f0) / 2.0)
	body.position = Vector3(0.1 - mid.x, SEAT, -0.1 - mid.z)
	var head: Vector3 = body.transform * body.bone_position("Head")
	# Selän puoleinen käsi vatsan päälle, ettei se kulje selkänojan läpi (+Z = selkänoja).
	var back := "_l" if (body.transform * body.bone_position("hand_l")).z > (body.transform * body.bone_position("hand_r")).z else "_r"
	var front := "_r" if back == "_l" else "_l"
	_back = back
	var to_local := body.basis.inverse()
	# Koko käsi lötköttää vatsan päällä: kyynärpää kyljen päällä selkänojan puolella, kyynärvarsi veltosti vatsan
	# poikki ja kämmen valahtanut vatsan etukaarelle hieman jalkoihin päin (pää on +X:ssä). Korkeudet ja kämmenen
	# kallistus lasketaan paistetun vartaloverkon pinnasta (vatsan koko tulee LOOK:sta), ei kiinteillä luvuilla.
	# Paistettu verkko puuttuu ilman näyttöä (headless, tyhjä lista), silloin pinta arvioidaan selkärangasta.
	var torso := Pose.limb_points(body, self, ["pelvis", "spine_01", "spine_02", "spine_03"])
	var sp: Vector3 = body.transform * body.bone_position("spine_02")
	var top := func(p: Vector3) -> float:
		var y := Pose.top_y(torso, p, 0.04)
		return y if y > -INF else sp.y + 0.15
	# Nivelet ratkaistaan suoraan: kyynärpää olkavarren mitan päässä olkapäästä ja kämmen kyynärvarren mitan päässä
	# kyynärpäästä, kumpikin hihan paksuuden verran pinnan yläpuolella. Puolitushaku pitkin vaakasuuntaa.
	var bp := func(bn: String) -> Vector3: return body.transform * body.bone_position(bn + back)
	var s: Vector3 = bp.call("upperarm")
	var l1: float = s.distance_to(bp.call("lowerarm"))
	var l2: float = (bp.call("lowerarm") as Vector3).distance_to(bp.call("hand"))
	var on_surface := func(from: Vector3, dir: Vector3, length: float, r: float) -> Vector3:
		var lo := 0.0
		var hi := length
		var p := from
		for i in 24:
			var d := (lo + hi) / 2.0
			p = from + dir * d
			p.y = top.call(p) + r
			if p.distance_to(from) > length:
				hi = d
			else:
				lo = d
		return p
	var e := Vector3.ZERO
	var hp := Vector3.ZERO
	var lift := 0.0
	for k in 4:  # kyynärvarren keskikohtakin pinnan yläpuolelle (vatsan kaari voi nousta suoran yli)
		e = on_surface.call(s, Vector3(-1.0, 0, 0.05).normalized(), l1, 0.05 + lift)  # kyljen päälle, ei rinnan poikki
		hp = on_surface.call(e, Vector3(-0.35, 0, -1.0).normalized(), l2, 0.03 + lift)
		var m := (e + hp) / 2.0
		var need: float = top.call(m) + 0.045 - m.y
		if need <= 0.002:
			break
		lift += need
	var dydx: float = (top.call(hp + Vector3(0.04, 0, 0)) - top.call(hp - Vector3(0.04, 0, 0))) / 0.08
	var dydz: float = (top.call(hp + Vector3(0, 0, 0.04)) - top.call(hp - Vector3(0, 0, 0.04))) / 0.08
	var up_n := Vector3(-dydx, 1.0, -dydz).normalized()  # vatsan pinnan normaali kämmenen kohdalla
	var inv := body.transform.affine_inverse()
	body.set_ik("arm" + back, "upperarm" + back, "lowerarm" + back, "hand" + back, inv * hp, inv * e)
	# Kämmen vatsaa vasten (normaali n vatsan sisään), sormet pinnan suuntaisesti kaarta alas tien puolelle (-Z).
	var fd := Vector3(-0.3, 0.0, -1.0)
	var fingers := to_local * (fd - up_n * fd.dot(up_n) - up_n * 0.25).normalized()
	var n := to_local * -up_n
	body.set_ik_orient("arm" + back, Pose.palm_on(fingers, n, back == "_l"), 1.0)
	# Positiivinen kierto akselin sormet × n ympäri taivuttaa sormet kämmenen puolelle vatsaa vasten.
	_curl_axis = fingers.cross(n).normalized()
	_curl_fingers()
	# Etukäsi roikkumaan penkin etureunan yli kohti maata.
	var sh: Vector3 = body.transform * body.bone_position("upperarm" + front)
	body.set_ik("arm" + front, "upperarm" + front, "lowerarm" + front, "hand" + front,
		inv * Vector3(sh.x, SEAT - 0.4, -0.3), inv * Vector3(sh.x, SEAT - 0.15, -0.3))
	var hand: Vector3 = body.transform * body.bone_position("hand" + front)
	var feet: Vector3 = body.transform * ((body.bone_position("foot_l") + body.bone_position("foot_r")) / 2.0)
	var along := Vector3(head.x - feet.x, 0, head.z - feet.z).normalized()
	# Jalat lähes yhdensuuntaisiksi ja hieman auki (animaation V-asento pois), polvet kevyesti koukussa ylös.
	var side := Vector3(-along.z, 0, along.x)
	var mid_hip: Vector3 = body.transform * ((body.bone_position("thigh_l") + body.bone_position("thigh_r")) / 2.0)
	for lr: String in ["_l", "_r"]:
		var hip: Vector3 = body.transform * body.bone_position("thigh" + lr)
		var reach: float = (body.bone_position("thigh" + lr).distance_to(body.bone_position("calf" + lr))
			+ body.bone_position("calf" + lr).distance_to(body.bone_position("foot" + lr))) * 0.96
		var out := side * signf((hip - mid_hip).dot(side)) * 0.05
		var foot_y: float = (body.transform * body.bone_position("foot" + lr)).y
		var tgt: Vector3 = Vector3(hip.x, foot_y, hip.z) - along * reach + out
		var knee: Vector3 = (hip + tgt) / 2.0 + Vector3(0, 0.3, 0)
		body.set_ik("leg" + lr, "thigh" + lr, "calf" + lr, "foot" + lr, inv * tgt, inv * knee)
	_add_bag(Vector3(head.x, SEAT, head.z) + along * 0.05, atan2(along.x, along.z))
	var glass := B.mat(Color(0.85, 0.92, 0.95)).duplicate() as StandardMaterial3D
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.55
	glass.roughness = 0.1
	var bottle := Node3D.new()
	add_child(bottle)
	bottle.position = Vector3(hand.x, 0.04, -0.35)  # maassa roikkuvan käden alla
	bottle.rotation = Vector3(0, 0.7, PI / 2.0)  # kaatunut kyljelleen
	B.mesh(bottle, B.cyl(0.04, 0.04, 0.2, 12), Vector3.ZERO, Color.WHITE).material_override = glass
	B.mesh(bottle, B.cyl(0.014, 0.04, 0.08, 12), Vector3(0, 0.14, 0), Color.WHITE).material_override = glass
	B.mesh(bottle, B.cyl(0.041, 0.041, 0.07, 12), Vector3.ZERO, Color(0.95, 0.95, 0.93))  # etiketti
	B.mesh(bottle, B.cyl(0.042, 0.042, 0.015, 12), Vector3.ZERO, Color(0.15, 0.3, 0.7))
	for k in 3:
		var p := Vector3(-0.6 + k * 0.45, 0, -0.3 - (k % 2) * 0.25)  # penkin edessä maassa
		var can := B.mesh(self, B.cyl(0.033, 0.033, 0.12, 12), Vector3(p.x, 0.034, p.z),
			[Color(0.85, 0.75, 0.2), Color(0.15, 0.35, 0.7), Color(0.85, 0.75, 0.2)][k])
		can.rotation = Vector3(0, k * 1.1, PI / 2.0)


## Vatsalla lepäävän käden sormet rennosti koukkuun (animaation levitetyt sormet pois); ohitukset nollautuvat heräämisen jälkeen.
func _curl_fingers() -> void:
	for f: String in ["index", "middle", "ring", "pinky"]:
		body.set_override(f + "_01" + _back, _curl_axis, 0.25)
		body.set_override(f + "_02" + _back, _curl_axis, 0.35)
		body.set_override(f + "_03" + _back, _curl_axis, 0.25)


## Alkon valkoinen muovikassi: rypyttynä kasaan (litistetyt pallot), kahvalenkit pään takana penkin päätyyn päin ja punainen logo
## tielle päin olevalla kyljellä. Pää lepää päällä (yläpinta SEAT + 0.12).
func _add_bag(pos: Vector3, yaw: float) -> void:
	var bag := Node3D.new()
	bag.position = pos
	bag.rotation.y = yaw
	add_child(bag)
	var white := Color(0.93, 0.93, 0.9)
	for l in [[Vector3(0, 0.055, 0), Vector3(0.17, 0.065, 0.13)], [Vector3(-0.07, 0.05, -0.06), Vector3(0.1, 0.07, 0.09)],
			[Vector3(0.06, 0.058, 0.05), Vector3(0.1, 0.062, 0.08)], [Vector3(0.0, 0.04, -0.12), Vector3(0.12, 0.04, 0.06)]]:
		var m := B.mesh(bag, B.sphere(0.5, 12), l[0], white.darkened(randf() * 0.06))
		m.scale = l[1] * 2.0
	var side := -signf(bag.basis.x.z) if bag.basis.x.z != 0.0 else 1.0
	var logo := B.mesh(bag, B.boxm(Vector3(0.01, 0.045, 0.075)), Vector3(side * 0.163, 0.058, 0.0), Color(0.85, 0.1, 0.12))
	logo.rotation_degrees.z = side * 8.0
	B.mesh(bag, B.boxm(Vector3(0.011, 0.012, 0.05)), Vector3(side * 0.165, 0.058, 0.0), white)  # logon valkoinen raita
	# Kahvat ovat pehmeää muovia: lenkki on lyyhistynyt kassin suulta penkin rimalle, ei pystyssä.
	var pts := [Vector3(-0.06, 0.06, 0.1), Vector3(-0.065, 0.03, 0.15), Vector3(-0.04, 0.014, 0.19), Vector3(0.0, 0.012, 0.2),
		Vector3(0.04, 0.014, 0.19), Vector3(0.065, 0.03, 0.15), Vector3(0.06, 0.06, 0.1)]
	for k in pts.size() - 1:
		B.tube(bag, pts[k], pts[k + 1], 0.01, white.darkened(0.04))


## Puistonpenkki: valurautajalat, kolme istuinrimaa ja kaksi selkänojarimaa, törmäys koko penkille.
func _build_bench() -> void:
	var wood := Color(0.55, 0.36, 0.2)
	var iron := Color(0.12, 0.12, 0.13)
	# Selkänojan tolppa nousee istuimen takareunasta taaksepäin kallellaan (+Z = selkänoja; X-kierto +12° kallistaa
	# yläpään +Z:aan), ja rimat ovat tolpan etupinnalla sen suuntaisina.
	var tilt := 12.0
	var lean := Vector3(0, cos(deg_to_rad(tilt)), sin(deg_to_rad(tilt)))
	var face := Vector3(0, sin(deg_to_rad(tilt)), -cos(deg_to_rad(tilt)))  # tolpan etupinnan normaali
	var base := Vector3(0, SEAT - 0.04, 0.2)
	for x in [-BENCH_L / 2.0 + 0.15, BENCH_L / 2.0 - 0.15]:
		B.mesh(self, B.boxm(Vector3(0.06, 0.45, 0.45)), Vector3(x, 0.22, 0.0), iron)
		B.mesh(self, B.boxm(Vector3(0.06, 0.5, 0.06)), base + Vector3(x, 0, 0) + lean * 0.25, iron, Vector3(tilt, 0, 0))
	for k in 3:
		B.mesh(self, B.boxm(Vector3(BENCH_L, 0.04, 0.12)), Vector3(0, SEAT - 0.02, -0.16 + k * 0.15), wood.darkened(0.05 * k))
	for k in 2:
		B.mesh(self, B.boxm(Vector3(BENCH_L, 0.11, 0.035)), base + lean * (0.2 + k * 0.17) + face * (0.03 + 0.0175), wood, Vector3(tilt, 0, 0))
	var sb := StaticBody3D.new()
	add_child(sb)
	sb.add_child(B.box_shape(Vector3(BENCH_L, 0.9, 0.55), Vector3(0, 0.45, 0.02)))
