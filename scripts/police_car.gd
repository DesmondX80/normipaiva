extends "res://scripts/wife_car.gd"
## Poliisi tulee siilin yliajosta (eläinsuojelurikos). Tietää aluksi, missä pelaaja on, ja ajaa suoraan
## perään. Sen jälkeen ajo jatkuu vain näköyhteydellä: kun poliisi kadottaa pelaajan, se luovuttaa
## (escaped) ja ajaa pois. Kiinni jääminen hoidetaan kuten Päivillä (caught).

signal escaped

const TIP_TIME := 4.0  # sekuntia lähellä, jotka poliisi vielä tietää pelaajan paikan (naapuri soitti)
const LEAVE_TIME := 15.0

var _tip := TIP_TIME
var _leaving := -1.0
var _lights: Array[MeshInstance3D] = []
var _siren_t := 0.0
var _siren_hi := false


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(B.box_shape(Vector3(1.8, 1.4, 4.2), Vector3(0, 0.85, 0)))
	B.car(self, Color(0.93, 0.94, 0.96))
	var blue := Color(0.05, 0.2, 0.75)
	for sx in [-0.92, 0.92]:
		B.mesh(self, B.boxm(Vector3(0.02, 0.16, 3.6)), Vector3(sx, 0.62, 0.0), blue)
	B.mesh(self, B.boxm(Vector3(1.1, 0.08, 0.3)), Vector3(0, 1.5, 0.2), Color(0.2, 0.2, 0.22))
	for sx in [-0.3, 0.3]:
		var l := MeshInstance3D.new()
		l.mesh = B.boxm(Vector3(0.45, 0.12, 0.26))
		l.material_override = B.unshaded(Color(0.2, 0.4, 1.0))
		l.position = Vector3(sx, 1.58, 0.2)
		add_child(l)
		_lights.append(l)
	B.guide(self, "POLIISI", Vector3(0, 2.4, 0), 56, Color(0.7, 0.8, 1.0), true)
	_engine = Sfx.loop_on(self, "engine", -4.0)


## Lähtee jahtiin heti: tietää alussa, missä pelaaja on.
func start_chase() -> void:
	alerted = true
	mode = "chase"
	_tip = TIP_TIME
	spotted.emit()


func is_leaving() -> bool:
	return _leaving >= 0.0


func _physics_process(delta: float) -> void:
	_siren(delta)
	if _leaving >= 0.0:
		# Luovutti: ajaa tieverkkoa pois ja katoaa.
		_leaving += delta
		if _flat_dist(_goal) < 3.0:
			_advance()
		_drive(delta, PATROL_SPEED)
		if _leaving > LEAVE_TIME:
			queue_free()
		return
	if alerted and target != null:
		# Vihje pätee perille asti: aika alkaa kulua vasta, kun poliisi on lähellä (tai jos se jumittaa).
		var near := global_position.distance_to(target.global_position) < SIGHT * 0.8
		_tip -= delta * (1.0 if near else 0.1)
		if _tip <= 0.0:
			alerted = false
	super(delta)
	if mode == "return":
		# Kadotti pelaajan: pako onnistui.
		_leaving = 0.0
		_cur = _nearest_node()
		_goal = _nodes[_cur]
		escaped.emit()


## Vilkkuvat siniset valot ja kaksisävyinen hälytys.
func _siren(delta: float) -> void:
	_siren_t -= delta
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25
	_lights[0].visible = blink
	_lights[1].visible = not blink
	if _siren_t <= 0.0 and _leaving < 0.0:
		_siren_t = 0.55
		_siren_hi = not _siren_hi
		Sfx.play_on(self, "horn", -2.0, 1.35 if _siren_hi else 1.0)
