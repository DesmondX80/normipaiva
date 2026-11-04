extends CharacterBody3D
## Konstaapeli Roivaisen poliisi-Saab Vaalan tähtijahdissa (rikos/autovarkaus.gd). Ulkoasu kuten ratsian auto
## (ratsia.gd: valkoinen, siniset raidat, valopalkki). Solmu on mopo_trip.gd:n kehyksessä (Vaalan paikallinen).
## Ajo: kaukana tien näytteitä pitkin (traffic_car.gd _place_on_line -tapaan) kohti pelaajan näytettä, alle
## NEAR metrin päässä suoraan pelaajaa kohti (move_and_slide, maasto vaala.h). -Z = keula.

const B := preload("res://scripts/build.gd")

const SPEED := 12.5  # perusnopeus (m/s), kuten Päivin HUNT_SPEED; kerrotaan heat_mult:lla
const NEAR := 40.0
const CATCH_DIST := 4.8  # keskipisteiden väli: auto (4,2 m) ei mene pelaajan auton sisään (ei törmäysmuotoa pelaajaan)
const STOP_DIST := 4.5
const TURN := 2.4
const LANE := 1.6

signal caught

var target: Node3D  # pelaaja (mopo_trip:n lapsi: mopo tai kävelijä)
var vaala: Node3D
var line: Array = []  # tien näytteet (mopo_trip._line)
var heat_mult := 1.0
var active := true

var _t := 0.0  # paikka viivalla (näyteindeksi)
var _speed := 0.0
var _lights: Array[MeshInstance3D] = []
var _siren_t := 0.0
var _siren_hi := false
var _engine: AudioStreamPlayer3D


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 0  # ei tönäise pelaajaa: kiinniotto tarkistetaan etäisyydestä
	add_child(B.box_shape(Vector3(1.8, 1.4, 4.2), Vector3(0, 0.85, 0)))
	B.car(self, Color(0.93, 0.94, 0.96))
	var blue := Color(0.05, 0.2, 0.75)
	for sx: float in [-0.92, 0.92]:
		B.mesh(self, B.boxm(Vector3(0.02, 0.16, 3.6)), Vector3(sx, 0.62, 0.0), blue)
	B.mesh(self, B.boxm(Vector3(1.1, 0.08, 0.3)), Vector3(0, 1.5, 0.2), Color(0.2, 0.2, 0.22))
	for sx: float in [-0.3, 0.3]:
		var l := MeshInstance3D.new()
		l.mesh = B.boxm(Vector3(0.45, 0.12, 0.26))
		l.material_override = B.unshaded(Color(0.2, 0.4, 1.0))
		l.position = Vector3(sx, 1.58, 0.2)
		add_child(l)
		_lights.append(l)
	for sx: float in [-1.0, 1.0]:
		var lab := B.label(self, "POLIISI", Vector3(sx * 0.93, 0.95, 0.0), 40, Color(0.05, 0.2, 0.75))
		lab.rotation.y = sx * PI / 2.0
		lab.outline_size = 0
	_engine = Sfx.loop_on(self, "engine", -4.0)


## Alkuun tien näytteeseen i (suunta dir = +1/-1 näyteindeksin kasvusuuntaan).
func place_at(i: float, dir: int) -> void:
	_t = clampf(i, 1.0, line.size() - 2.0)
	_speed = 0.0
	for k in 20:
		_put_on_line(0.0, dir)  # suunta kääntyy lerpillä: toistetaan, kunnes nokka on tien suuntaan


func _physics_process(delta: float) -> void:
	_siren(delta)
	if target == null or not active or line.is_empty():
		return
	var tp := target.global_position
	var to := tp - global_position
	to.y = 0.0
	var want := SPEED * heat_mult
	_speed = move_toward(_speed, want, 8.0 * delta)
	var lp: Vector3 = get_parent().to_local(tp) if get_parent() is Node3D else tp
	var goal: int = vaala.nearest(lp)[0] if vaala != null else -1
	if to.length() < NEAR or goal < 0 or absf(goal - _t) < 3.0:
		# Lähellä (tai pelaaja sivutiellä): suoraan kohti, maaston pinnalla.
		var yaw := B.yaw_to(to)
		rotation.y = rotate_toward(rotation.y, yaw, TURN * delta)
		var slow := clampf(1.0 - absf(wrapf(yaw - rotation.y, -PI, PI)) / PI, 0.4, 1.0)
		velocity = -global_transform.basis.z * _speed * slow * (0.0 if to.length() < STOP_DIST else 1.0)
		move_and_slide()
		if vaala != null:
			var ni: Array = vaala.nearest(position)
			if ni[0] >= 0:
				_t = float(ni[0])
			position.y = _maa(position.x, position.z)
			_kallista()
	else:
		# Kaukana: tietä pitkin pelaajan näytettä kohti.
		_put_on_line(_speed * delta, 1 if goal > _t else -1)
	_engine.pitch_scale = 0.75 + absf(_speed) / SPEED * 0.45
	if to.length() < CATCH_DIST:
		caught.emit()


func _put_on_line(dist: float, dir: int) -> void:
	_t = clampf(_t + dir * dist / 2.0, 1.0, line.size() - 2.0)  # näytteiden väli 2 m (vaala.gd STEP)
	var i := int(_t)
	var u := _t - i
	var a: Vector3 = line[i]
	var b: Vector3 = line[i + 1]
	var d := (b - a)
	d.y = 0.0
	d = d.normalized() * dir
	var want := a.lerp(b, u) + d.cross(Vector3.UP) * LANE
	position = want
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 0.25)
	if vaala != null:
		position.y = _maa(position.x, position.z)
		_kallista()


## Ajopinnan korkeus: tiellä (alle 4 m näytteestä) tien pinta, muuten maasto.
func _maa(x: float, z: float) -> float:
	var ni: Array = vaala.nearest(Vector3(x, 0, z))
	if ni[0] >= 0 and ni[1] < 4.0:
		var i: int = ni[0]
		var a: Vector3 = vaala.road_pos(i)
		return maxf(a.y, vaala.h(x, z))
	return vaala.h(x, z)


## Auto maaston kaltevuuden mukaan: nokka ja kyljet neljästä pyörän kohdasta (sama korkeusfunktio kuin ajossa).
func _kallista() -> void:
	var yaw := rotation.y
	var f := Vector3(-sin(yaw), 0, -cos(yaw))
	var r := Vector3(cos(yaw), 0, -sin(yaw))
	var p := position
	var hf := _maa(p.x + f.x * 1.35, p.z + f.z * 1.35)
	var hb := _maa(p.x - f.x * 1.35, p.z - f.z * 1.35)
	var hr := _maa(p.x + r.x * 0.84, p.z + r.z * 0.84)
	var hl := _maa(p.x - r.x * 0.84, p.z - r.z * 0.84)
	position.y = maxf(position.y, (hf + hb) / 2.0)
	rotation.x = atan2(hf - hb, 2.7)
	rotation.z = atan2(hr - hl, 1.68)  # +Z-kierto nostaa oikean (+X) kyljen


## Vilkkuvat siniset valot ja kaksisävyinen hälytys (police_car.gd).
func _siren(delta: float) -> void:
	_siren_t -= delta
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25
	_lights[0].visible = blink
	_lights[1].visible = not blink
	if _siren_t <= 0.0 and active:
		_siren_t = 0.55
		_siren_hi = not _siren_hi
		Sfx.play_on(self, "horn", -2.0, 1.35 if _siren_hi else 1.0)
