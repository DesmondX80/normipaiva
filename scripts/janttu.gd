extends Node3D
## Janttu: Vaalan paikallinen, joka nukkuu kilipäissään penkillä poliisilaitosta vastapäätä (vaala.gd _build_poliisi).
## Maastotakki, pipo ja parransänki, jalkojen juuressa kossupullo, kaljatölkkejä ja Alkon kassi. Pää retkahtaa
## rinnalle ja ilmassa leijuu Zzz. Herää hetkeksi, kun hänelle tarjotaan (wake, main.gd _talk_janttu).
## Paikallinen -Z = penkin etupuoli (kohti tietä ja poliisilaitosta).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const LOOK := {
	"shirt": Color(0.33, 0.36, 0.24), "pants": Color(0.2, 0.2, 0.24), "shoes": Color(0.12, 0.1, 0.08),
	"hair": "Hair_Long", "hair_color": Color(0.42, 0.38, 0.33), "beard": true, "height": 1.76,
	"skin": Color(0.98, 0.72, 0.62), "belly": 0.55, "bulk": -0.1, "shoulders": -0.3,
}

var body: Node3D
var awake_t := 0.0
var _zzz: Label3D
var _bubble: Label3D
var _bubble_t := 0.0
var _t := 0.0


func _ready() -> void:
	_build_bench()
	body = Looks.make(self, LOOK)
	body.position = Vector3(0.25, 0.12, -0.05)
	# Character katsoo valmiiksi -Z eli penkin etupuolelle.
	body.play("Sitting_Idle", 0.0)
	_add_pipo()
	_zzz = Label3D.new()
	_zzz.font_size = 56
	_zzz.pixel_size = 0.005
	_zzz.modulate = Color(0.9, 0.95, 1.0)
	_zzz.outline_size = 10
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_zzz)
	_bubble = B.bubble(self, Vector3(0.25, 2.1, 0))
	_slump(true)


func _process(delta: float) -> void:
	_t += delta
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""
	if awake_t > 0.0:
		awake_t -= delta
		if awake_t <= 0.0:
			_slump(true)
		return
	# Zzz nousee ja haalistuu kolmessa vaiheessa.
	var ph := fmod(_t * 0.45, 1.0)
	_zzz.text = ["z", "zZ", "zZz"][int(ph * 3.0)]
	_zzz.position = Vector3(0.45 + ph * 0.25, 1.35 + ph * 0.45, -0.1)
	_zzz.modulate.a = 1.0 - ph * 0.7


## Herää hetkeksi sanomaan sanansa, sitten pää retkahtaa taas.
func wake(text: String, seconds := 5.0) -> void:
	awake_t = seconds
	_slump(false)
	_bubble.text = "Janttu: " + text
	_bubble_t = seconds


func _slump(on: bool) -> void:
	_zzz.visible = on
	if on:
		body.play("Sitting_Idle", 0.4)
		body.set_override("Head", Vector3.RIGHT, -0.55)  # leuka rintaan
		body.set_override("spine_03", Vector3.RIGHT, -0.25)
		body.set_override("neck_01", Vector3.FORWARD, 0.2)  # pää kallellaan
	else:
		body.clear_overrides()
		body.play("Sitting_Talking", 0.3)


func _add_pipo() -> void:
	var pipo := Node3D.new()
	var col := Color(0.62, 0.12, 0.1)
	var cap := B.mesh(pipo, B.sphere(0.5, 14), Vector3(0, 0, 0), col)
	cap.scale = Vector3(0.21, 0.16, 0.22)
	B.mesh(pipo, B.cyl(0.108, 0.11, 0.05, 16), Vector3(0, -0.035, 0), col.darkened(0.25))  # käänne
	B.mesh(pipo, B.sphere(0.035, 8), Vector3(0, 0.085, 0), Color(0.9, 0.88, 0.8))  # tupsu
	body.attach("Head", pipo, Vector3(0, 0.13, -0.005))


## Puistonpenkki: valurautajalat, kolme istuinrimaa ja kaksi selkänojarimaa; jalkojen juuressa pullot ja kassi.
func _build_bench() -> void:
	var wood := Color(0.55, 0.36, 0.2)
	var iron := Color(0.12, 0.12, 0.13)
	for x in [-0.8, 0.8]:
		B.mesh(self, B.boxm(Vector3(0.06, 0.45, 0.45)), Vector3(x, 0.22, 0.0), iron)
		B.mesh(self, B.boxm(Vector3(0.06, 0.5, 0.06)), Vector3(x, 0.7, 0.22), iron, Vector3(-12, 0, 0))
	for k in 3:
		B.mesh(self, B.boxm(Vector3(1.9, 0.04, 0.12)), Vector3(0, 0.46, -0.16 + k * 0.15), wood.darkened(0.05 * k))
	for k in 2:
		B.mesh(self, B.boxm(Vector3(1.9, 0.11, 0.035)), Vector3(0, 0.66 + k * 0.17, 0.24 + k * 0.035), wood, Vector3(-12, 0, 0))
	var body_s := StaticBody3D.new()
	add_child(body_s)
	body_s.add_child(B.box_shape(Vector3(1.9, 0.9, 0.55), Vector3(0, 0.45, 0.02)))
	# Kossupullo (kirkas lasi, valkoinen etiketti sinisellä tekstillä), kaatunut kaljatölkki ja Alkon kassi.
	var glass := B.mat(Color(0.85, 0.92, 0.95)).duplicate() as StandardMaterial3D
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.55
	glass.roughness = 0.1
	var bottle := Node3D.new()
	add_child(bottle)
	bottle.position = Vector3(-0.35, 0, -0.45)
	var bm := B.mesh(bottle, B.cyl(0.04, 0.04, 0.2, 12), Vector3(0, 0.1, 0), Color.WHITE)
	bm.material_override = glass
	var neck := B.mesh(bottle, B.cyl(0.014, 0.04, 0.08, 12), Vector3(0, 0.24, 0), Color.WHITE)
	neck.material_override = glass
	B.mesh(bottle, B.cyl(0.016, 0.016, 0.02, 10), Vector3(0, 0.29, 0), Color(0.2, 0.3, 0.6))  # korkki
	B.mesh(bottle, B.cyl(0.041, 0.041, 0.07, 12), Vector3(0, 0.1, 0), Color(0.95, 0.95, 0.93))  # etiketti
	B.mesh(bottle, B.cyl(0.042, 0.042, 0.015, 12), Vector3(0, 0.1, 0), Color(0.15, 0.3, 0.7))
	for k in 3:
		var can := B.mesh(self, B.cyl(0.033, 0.033, 0.12, 12), Vector3(0.1 + k * 0.22, 0.034, -0.55 + (k % 2) * 0.12),
			[Color(0.85, 0.75, 0.2), Color(0.15, 0.35, 0.7), Color(0.85, 0.75, 0.2)][k])
		can.rotation = Vector3(0, k * 1.1, PI / 2.0)  # kaatuneet tölkit
	var bag := B.mesh(self, B.boxm(Vector3(0.3, 0.32, 0.14)), Vector3(-0.75, 0.16, -0.35), Color(0.92, 0.92, 0.9))
	bag.rotation.y = 0.3
	var logo := B.mesh(self, B.boxm(Vector3(0.16, 0.1, 0.005)), Vector3(-0.73, 0.2, -0.43), Color(0.85, 0.1, 0.12))
	logo.rotation.y = 0.3
