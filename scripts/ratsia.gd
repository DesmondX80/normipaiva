extends Node3D
## Poliisin moporatsia Vaalan mopotien varressa (main.gd _ratsia_*): valkoinen poliisi-Saab sinisine raitoineen ja
## vilkkuvalot, kaksi konstaapelia (toinen viittoo mopoja sivuun, toinen tarkastaa) ja jo pysäytetty mopopoika,
## jonka Tunturista löytyy porattu sylinteri ja puuttuvat takajarrut. Konstaapelien ja pojan puheet kuplina.
## Solmu Vaalan kehyksessä; stop_pos = pysähtymiskohta tien reunassa, wave() kun pelaajan mopo lähestyy.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Mopo := preload("res://scripts/mopo.gd")

const COP := {"shirt": Color(0.12, 0.16, 0.3), "pants": Color(0.1, 0.12, 0.22), "shoes": Color(0.05, 0.05, 0.05),
	"hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.22, 0.15), "height": 1.84, "belly": 0.3}
const COP2 := {"shirt": Color(0.12, 0.16, 0.3), "pants": Color(0.1, 0.12, 0.22), "shoes": Color(0.05, 0.05, 0.05),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.55, 0.5, 0.45), "beard": true, "height": 1.78, "belly": 0.6}
const TEEN := {"shirt": Color(0.12, 0.12, 0.14), "pants": Color(0.3, 0.38, 0.55), "shoes": Color(0.9, 0.9, 0.9),
	"hair": "Hair_Long", "hair_color": Color(0.2, 0.15, 0.1), "height": 1.74, "bulk": -0.7, "shoulders": -0.6}
const TEEN_LINES := [
	["Tää on porattu seiskytkuutoseks, poika.", "Ei se oo! Se on ihan vakio!"],
	["Missäs takajarrut on?", "Ne... lähti viime viikolla. Ihan itestään."],
	["Paljonko tällä pääsee?", "Neljäkymppiä. Alamäkeen. Kun tuulee takaa."],
	["Mopo jää tähän, isä hakee sen huomenna.", "Äh! Iskä tappaa mut."],
	["Kypärä puuttuu ja pakoputki on avattu.", "Se oli jo valmiiks avattu ku mä ostin sen."],
]

var stop_pos := Vector3.ZERO  # pysähtymiskohta (Vaalan kehys)
var _lights: Array[MeshInstance3D] = []
var _cop_wave: Node3D
var _cop_check: Node3D
var _teen: Node3D
var _bubbles := {}
var _t := 0.0
var _line_t := 2.0
var _line_i := 0
var _waving := 0.0


## at = tien keskiviivan piste, dir = tien suunta, side = poliisiauton puoli (tien reunan suunta), half_w = tien puolileveys.
func setup(at: Vector3, dir: Vector3, side: Vector3, half_w: float, ground: Callable) -> void:
	var yaw := atan2(-dir.x, -dir.z)
	var shoulder := at + side * (half_w + 2.4)
	var car := Node3D.new()
	car.position = Vector3(shoulder.x, ground.call(shoulder.x, shoulder.z), shoulder.z)
	car.rotation.y = yaw
	add_child(car)
	B.car(car, Color(0.93, 0.94, 0.96))
	var blue := Color(0.05, 0.2, 0.75)
	for sx: float in [-0.92, 0.92]:
		B.mesh(car, B.boxm(Vector3(0.02, 0.16, 3.6)), Vector3(sx, 0.62, 0.0), blue)
	B.mesh(car, B.boxm(Vector3(1.1, 0.08, 0.3)), Vector3(0, 1.5, 0.2), Color(0.2, 0.2, 0.22))
	for sx: float in [-0.3, 0.3]:
		var l := MeshInstance3D.new()
		l.mesh = B.boxm(Vector3(0.45, 0.12, 0.26))
		l.material_override = B.unshaded(Color(0.2, 0.4, 1.0))
		l.position = Vector3(sx, 1.58, 0.2)
		car.add_child(l)
		_lights.append(l)
	for sx: float in [-1.0, 1.0]:
		var lab := B.label(car, "POLIISI", Vector3(sx * 0.93, 0.95, 0.0), 40, Color(0.05, 0.2, 0.75))
		lab.rotation.y = sx * PI / 2.0
		lab.outline_size = 0
	var body := StaticBody3D.new()
	car.add_child(body)
	body.add_child(B.box_shape(Vector3(1.8, 1.4, 4.2), Vector3(0, 0.7, 0)))
	# Pysähtymiskohta auton eteen tien reunaan; viittova konstaapeli tien laidassa.
	var sp := at + side * (half_w - 0.6) + dir * 7.0
	stop_pos = Vector3(sp.x, ground.call(sp.x, sp.z), sp.z)
	var cw := at + side * (half_w + 0.6) + dir * 9.5
	_cop_wave = Looks.make(self, COP)
	_cop_wave.position = Vector3(cw.x, ground.call(cw.x, cw.z), cw.z)
	_cop_wave.rotation.y = B.yaw_to(-dir)
	_cop_wave.play("Idle", 0.0)
	Looks.add_cap(_cop_wave)
	# Pysäytetty mopopoika auton takana: mopo, poika ja tarkastava konstaapeli.
	var mb := at + side * (half_w + 2.4) - dir * 5.5
	var mp := Node3D.new()
	mp.position = Vector3(mb.x, ground.call(mb.x, mb.z), mb.z)
	mp.rotation.y = yaw + 0.3
	add_child(mp)
	Mopo.build_model(mp)
	for n in mp.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).material_override == B.mat(Color(0.72, 0.08, 0.06)):
			(n as MeshInstance3D).material_override = B.mat(Color(0.1, 0.45, 0.2))
	var tp := mb + side * 1.4 + dir * 0.4
	_teen = Looks.make(self, TEEN)
	_teen.position = Vector3(tp.x, ground.call(tp.x, tp.z), tp.z)
	_teen.rotation.y = B.yaw_to(-side)
	_teen.play("Idle_Talking", 0.0)
	var cp := mb - side * 1.3 + dir * 0.2
	_cop_check = Looks.make(self, COP2)
	_cop_check.position = Vector3(cp.x, ground.call(cp.x, cp.z), cp.z)
	_cop_check.rotation.y = B.yaw_to(side)
	_cop_check.play("Idle_Talking", 0.0)
	Looks.add_cap(_cop_check)
	for who in [_cop_wave, _cop_check, _teen]:
		_bubbles[who] = B.bubble(who, Vector3(0, 2.0, 0), Color.WHITE, 1.0)


func say_wave(text: String) -> void:
	_say(_cop_wave, text, 3.0)


## Pelaajan mopo lähestyy: konstaapeli viittoo sivuun.
func wave() -> void:
	_waving = 3.0
	_cop_wave.play("Idle_Talking", 0.2)


func _say(who: Node3D, text: String, t: float) -> void:
	var b: Label3D = _bubbles[who]
	b.text = text
	b.set_meta("t", t)


func _process(delta: float) -> void:
	_t += delta
	var on := fmod(_t, 0.5) < 0.25
	for i in _lights.size():
		_lights[i].material_override = B.unshaded(Color(0.2, 0.4, 1.0) if (i == 0) == on else Color(0.05, 0.08, 0.2))
	for who in _bubbles:
		var b: Label3D = _bubbles[who]
		if b.text != "":
			b.set_meta("t", b.get_meta("t") - delta)
			if b.get_meta("t") <= 0.0:
				b.text = ""
	if _waving > 0.0:
		_waving -= delta
		_cop_wave.rotation.y += sin(_t * 8.0) * delta * 0.6
	# Tarkastus pojan kanssa: konstaapeli ja poika vuorottelevat.
	_line_t -= delta
	if _line_t <= 0.0:
		var pair: Array = TEEN_LINES[_line_i % TEEN_LINES.size()]
		if _bubbles[_cop_check].text == "":
			_say(_cop_check, pair[0], 3.0)
			get_tree().create_timer(2.2).timeout.connect(func() -> void:
				if is_instance_valid(_teen):
					_say(_teen, pair[1], 3.0))
			_line_i += 1
		_line_t = randf_range(7.0, 10.0)
