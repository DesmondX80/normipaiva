extends Node3D
## Janttu: Vaalan paikallinen, joka makaa kilipäissään puistonpenkin päällä poliisilaitosta vastapäätä (vaala.gd
## _build_poliisi). Maastotakki, pipo ja parransänki; selällään penkillä Alkon kassi tyynynä, käsi roikkuu, kossupullo
## ja kaljatölkit penkin alla. Rintakehä nousee ja laskee, ja ilmassa leijuu Zzz. Herää hetkeksi nostamaan päätään,
## kun hänelle tarjotaan (wake, main.gd _talk_janttu). Paikallinen -Z = penkin etupuoli (tielle ja asemalle päin).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const LOOK := {
	"shirt": Color(0.33, 0.36, 0.24), "pants": Color(0.2, 0.2, 0.24), "shoes": Color(0.12, 0.1, 0.08),
	"hair": "Hair_Long", "hair_color": Color(0.42, 0.38, 0.33), "beard": true, "height": 1.76,
	"skin": Color(0.98, 0.72, 0.62), "belly": 0.55, "bulk": -0.1, "shoulders": -0.3,
}
const POSE := "Death01"  # kaatumisen loppuasento: selällään
const SEAT := 0.46  # istuinrimojen yläpinta
const BENCH_L := 2.1

var body: Node3D
var awake_t := 0.0
var _zzz: Label3D
var _bubble: Label3D
var _bubble_t := 0.0
var _t := 0.0
var _props_placed := false


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
		return
	# Uni: rintakehä nousee ja laskee, Zzz nousee pään yltä ja haalistuu.
	body.set_override("spine_03", Vector3.RIGHT, sin(_t * 1.6) * 0.05)
	_zzz.visible = true
	var ph := fmod(_t * 0.45, 1.0)
	_zzz.text = ["z", "zZ", "zZz"][int(ph * 3.0)]
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
	body.position = Vector3(-mid.x, SEAT, -0.04 - mid.z)
	var head: Vector3 = body.transform * body.bone_position("Head")
	var hand: Vector3 = body.transform * body.bone_position("hand_r")
	var feet: Vector3 = body.transform * ((body.bone_position("foot_l") + body.bone_position("foot_r")) / 2.0)
	var along := Vector3(head.x - feet.x, 0, head.z - feet.z).normalized()
	var bag := B.mesh(self, B.boxm(Vector3(0.34, 0.12, 0.26)), Vector3(head.x, SEAT + 0.06, head.z) + along * 0.05, Color(0.92, 0.92, 0.9))
	bag.rotation.y = atan2(along.x, along.z)
	var logo := B.mesh(self, B.boxm(Vector3(0.1, 0.005, 0.16)), Vector3(head.x, SEAT + 0.125, head.z) + along * 0.12, Color(0.85, 0.1, 0.12))
	logo.rotation.y = bag.rotation.y
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


## Puistonpenkki: valurautajalat, kolme istuinrimaa ja kaksi selkänojarimaa, törmäys koko penkille.
func _build_bench() -> void:
	var wood := Color(0.55, 0.36, 0.2)
	var iron := Color(0.12, 0.12, 0.13)
	for x in [-BENCH_L / 2.0 + 0.15, BENCH_L / 2.0 - 0.15]:
		B.mesh(self, B.boxm(Vector3(0.06, 0.45, 0.45)), Vector3(x, 0.22, 0.0), iron)
		B.mesh(self, B.boxm(Vector3(0.06, 0.5, 0.06)), Vector3(x, 0.7, 0.22), iron, Vector3(-12, 0, 0))
	for k in 3:
		B.mesh(self, B.boxm(Vector3(BENCH_L, 0.04, 0.12)), Vector3(0, SEAT - 0.02, -0.16 + k * 0.15), wood.darkened(0.05 * k))
	for k in 2:
		B.mesh(self, B.boxm(Vector3(BENCH_L, 0.11, 0.035)), Vector3(0, 0.66 + k * 0.17, 0.24 + k * 0.035), wood, Vector3(-12, 0, 0))
	var sb := StaticBody3D.new()
	add_child(sb)
	sb.add_child(B.box_shape(Vector3(BENCH_L, 0.9, 0.55), Vector3(0, 0.45, 0.02)))
