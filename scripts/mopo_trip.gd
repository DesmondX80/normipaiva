extends Node3D
## Mopomatka Paapelista Vaalan Siitariin ja takaisin (main.gd:n lapsi, paikka = VAALA_POS). Rakentaa Vaalan
## maailman (vaala.gd) kerran ja ajaa mopoa (mopo.gd) sen tiellä. HUD: nopeus, tien nimi ja todellinen matka
## kohteeseen (tiivistetyllä välillä matkamittari juoksee K-kertaisesti). Kompassi näyttää kohteen suunnan.
## Signaalit: arrived (Siitarin ovella, mopo parkissa) ja finished("home"), kun mopo on ajettu takaisin Paapeliin.

const Vaala := preload("res://scripts/vaala.gd")
const Mopo := preload("res://scripts/mopo.gd")

const ARRIVE_R := 7.0
const HOME_S := 70.0  # todellinen matka tien alusta: tätä lähempänä ollaan Paapelin tiellä

signal arrived
signal finished(result: String)

var vaala: Node3D
var mopo: CharacterBody3D
var target := "siitari"  # "siitari" tai "paapeli"
var hint := ""
var status := ""
var active := false
var _sample := 0


func _ready() -> void:
	vaala = Vaala.new()
	add_child(vaala)


func ensure_built() -> void:
	vaala.ensure_built()


## Matka alkaa: "siitari" = Paapelin päästä Vaalaan, "paapeli" = Siitarin pihasta takaisin.
func start(to: String) -> void:
	ensure_built()
	target = to
	if mopo == null:
		mopo = Mopo.new()
		mopo.vaala = vaala
		add_child(mopo)
	var at: Vector3
	var dir: Vector3
	if to == "siitari":
		_sample = 3
		at = vaala.road_pos(_sample)
		dir = vaala.road_dir(_sample)
	else:
		at = vaala.siitari_park
		var ni: Array = vaala.nearest(at)
		_sample = ni[0]
		dir = (vaala.road_pos(_sample) - at).normalized()
		dir.y = 0.0
	mopo.position = at + Vector3(0, 0.6, 0)
	mopo.rotation.y = atan2(-dir.x, -dir.z)
	mopo.speed = 0.0
	mopo.velocity = Vector3.ZERO
	mopo.controls_enabled = true
	mopo.set_engine(true)
	mopo.activate_camera()
	mopo.process_mode = Node.PROCESS_MODE_INHERIT
	active = true


func stop() -> void:
	active = false
	if mopo != null:
		mopo.controls_enabled = false
		mopo.set_engine(false)
		mopo.process_mode = Node.PROCESS_MODE_DISABLED


## Kohteen paikka maailmassa (kompassia varten).
func target_global() -> Vector3:
	return to_global(vaala.siitari_door if target == "siitari" else vaala.road_pos(0))


## Todellinen matka kohteeseen metreinä mopon kohdalta tietä pitkin.
func real_left() -> float:
	var s: float = vaala.real_s(_sample)
	return (vaala.real_total - s) if target == "siitari" else s


func _process(_delta: float) -> void:
	if not active or mopo == null:
		return
	var ni: Array = vaala.nearest(mopo.position)
	if ni[0] >= 0:
		_sample = ni[0]
	var kmh := absf(mopo.speed) * 3.6
	var left := real_left()
	var name: String = vaala.road_names[_sample] if ni[0] >= 0 and ni[1] < 12.0 else "maastossa"
	status = "Mopo %d km/h\n%s · %s %s" % [roundi(kmh), name, "Siitari" if target == "siitari" else "Paapeli",
		("%.1f km" % (left / 1000.0)).replace(".", ",") if left > 150.0 else "%d m" % roundi(left)]
	hint = ""
	if target == "siitari":
		if mopo.position.distance_to(vaala.siitari_park) < ARRIVE_R + 6.0 or \
				Vector2(mopo.position.x - vaala.siitari_door.x, mopo.position.z - vaala.siitari_door.z).length() < ARRIVE_R:
			hint = "[E] Parkkeeraa mopo ja mene Siitariin"
			if Input.is_action_just_pressed("interact"):
				mopo.position = vaala.siitari_park + Vector3(0, 0.3, 0)
				mopo.speed = 0.0
				stop()
				arrived.emit()
	elif vaala.real_s(_sample) < HOME_S and ni[1] < 15.0:
		hint = "[E] Parkkeeraa mopo Paapelin pihaan"
		if Input.is_action_just_pressed("interact"):
			stop()
			finished.emit("home")
