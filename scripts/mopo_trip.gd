extends Node3D
## Mopomatka Paapelista Vaalan Siitariin ja takaisin (main.gd:n lapsi, paikka = VAALA_POS). Rakentaa Vaalan
## maailman (vaala.gd) kerran ja ajaa mopoa (mopo.gd) sen tiellä. HUD: nopeus, tien nimi ja todellinen matka
## kohteeseen (tiivistetyllä välillä matkamittari juoksee K-kertaisesti). Kompassi näyttää kohteen suunnan.
## Signaalit: arrived (Siitarin ovella, mopo parkissa) ja finished("home"), kun mopo on ajettu takaisin Paapeliin.
## Moposta voi nousta jalan (main.gd, F kuten pyörällä): on_foot = kävelijä, jolloin ovet ja automaatti toimivat
## kävelijän kohdalta, mopo seisoo parkissa ja autot väistävät (ja töytäisevät) kävelijää.

const Vaala := preload("res://scripts/vaala.gd")
const Mopo := preload("res://scripts/mopo.gd")
const TrafficCar := preload("res://scripts/traffic_car.gd")
const CARS := 6

const ARRIVE_R := 7.0
const HOME_YARD_R := 12.0  # mökin parkkipaikasta: pihaan ajettaessa matka päättyy (vaala.gd mokki_mopo)

signal arrived
signal finished(result: String)
signal killed  # auto ajoi mopon päälle
signal atm     # pankkiautomaatilla E
signal door(id: String)  # keskustan ovella E (vaala.gd doors: kmarket, zabuki, gasthaus)
signal lava    # Oulujärven lavan ovella E (lavatanssit)

const LAVA_TICKET := 12.0
signal crashed(reason: String)  # kännissä kumoon: "ditch" tai "wall"; mopo nostetaan tielle

var vaala: Node3D
var mopo: CharacterBody3D
var target := "siitari"  # "siitari" tai "paapeli"
var hint := ""
var status := ""
var active := false
var _sample := 0
var _cars: Array = []
var _line: Array = []
var _down := 0.0  # kaatumisen jälkeen maassa (s)
var on_foot: CharacterBody3D = null  # jalan (main.gd:n kävelijä), mopo parkissa; null = mopon selässä


func _ready() -> void:
	vaala = Vaala.new()
	add_child(vaala)


func ensure_built() -> void:
	vaala.ensure_built()


## Matka alkaa: "siitari" = Paapelin päästä Vaalaan, "paapeli" = Siitarin pihasta takaisin.
## drunk = humala (0…1): omalla kylällä saa ajaa kännissä, mutta ohjaus on sen mukainen (mopo.gd).
func start(to: String, drunk := 0.0) -> void:
	ensure_built()
	target = to
	if mopo == null:
		mopo = Mopo.new()
		mopo.vaala = vaala
		mopo.crashed.connect(_on_crash)
		add_child(mopo)
	on_foot = null
	mopo.set_rider_visible(true)
	mopo.drunk = drunk
	mopo.reset_drunk()
	_down = 0.0
	var at: Vector3
	var dir: Vector3
	if to == "siitari":
		# Lähtö mökin takaa samasta paikasta, jossa mopo oli parkissa (vaala.gd _build_mokki_yard), nokka tielle
		# päin (parkissa se katsoo mökin seinään).
		at = vaala.mokki_mopo
		_sample = maxi(vaala.nearest(at)[0], 3)
		dir = vaala.road_pos(_sample + 4) - at
		dir.y = 0.0
		dir = dir.normalized()
		at += dir * 2.5  # kamera mahtuu mopon taakse (mökin takaseinä on muuten heti selän takana)
		at.y = vaala.h(at.x, at.z)
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
	_spawn_cars()


## Liikenne: autoja molempiin suuntiin tien varrelle (ei aivan mopon viereen); tien päähän ajanut siirtyy
## mopon eteen uudelleen, joten vastaan tulee autoja koko matkan.
func _spawn_cars() -> void:
	if _line.is_empty():
		for i in vaala.road.size():
			_line.append(vaala.road_pos(i))
	if _cars.is_empty():
		for i in CARS:
			var car := TrafficCar.new()
			car.cruise = randf_range(15.0, 18.5)
			car.lane = 1.6
			car.target_fn = func() -> Node3D: return on_foot if on_foot != null else mopo
			car.line_ended = _respawn_car
			car.hit.connect(_on_hit)
			add_child(car)
			_cars.append(car)
	for i in _cars.size():
		var car: Node3D = _cars[i]
		car.process_mode = Node.PROCESS_MODE_INHERIT
		car.visible = true
		var t := float(_line.size()) * (i + 0.5) / _cars.size()
		if absf(t - _sample) < 60.0:
			t = fposmod(t + 120.0, _line.size() - 4.0) + 2.0
		car.setup_line(_line, t, 1 if i % 3 == 0 else -1)


func _respawn_car(car: Node3D) -> void:
	var toward := 1 if target == "siitari" else -1  # mopon ajosuunta näytteissä
	var ahead := _sample + toward * randi_range(110, 260)
	ahead = clampi(ahead, 3, _line.size() - 4)
	var dir := -toward if randf() < 0.7 else toward
	car.set_line_t(float(ahead), dir)


func _on_hit() -> void:
	if not active:
		return
	active = false
	mopo.controls_enabled = false
	mopo.speed = 0.0
	mopo.set_engine(false)
	Sfx.play("punch_heavy", 2.0)
	Sfx.play("bike_fall", 0.0)
	killed.emit()


## Kännissä kumoon: mopo kyljelleen hetkeksi, sitten nostetaan lähimmälle tielle ajosuuntaan.
func _on_crash(reason: String) -> void:
	if not active or _down > 0.0:
		return
	_down = 2.5
	mopo.controls_enabled = false
	mopo.speed = 0.0
	mopo.velocity = Vector3.ZERO
	mopo.fallen = true
	mopo.set_engine(false)
	Sfx.play("bike_fall", 0.0)
	crashed.emit(reason)


func _get_up() -> void:
	var ni: Array = vaala.nearest(mopo.position)
	var i: int = maxi(ni[0], 3)
	var dir: Vector3 = vaala.road_dir(i) * (1.0 if target == "siitari" else -1.0)
	var right := dir.cross(Vector3.UP)
	mopo.position = vaala.road_pos(i) + right * 1.6 + Vector3(0, 0.6, 0)
	mopo.rotation.y = atan2(-dir.x, -dir.z)
	mopo.reset_drunk()
	mopo.controls_enabled = true
	mopo.set_engine(true)


func stop() -> void:
	active = false
	if mopo != null:
		mopo.controls_enabled = false
		mopo.set_engine(false)
		mopo.process_mode = Node.PROCESS_MODE_DISABLED
	for car in _cars:
		car.process_mode = Node.PROCESS_MODE_DISABLED
		car.visible = false


## Jatkaa matkaa siitä, mihin jäätiin (esim. K-Market Tervaportista): mopo ja liikenne heräävät, paikka säilyy.
func resume() -> void:
	if mopo == null:
		return
	_resume_frame = Engine.get_process_frames()
	mopo.speed = 0.0
	mopo.velocity = Vector3.ZERO
	mopo.controls_enabled = on_foot == null  # jalan tultiin: mopo jää parkkiin (main.gd jatkaa kävelijällä)
	mopo.set_engine(on_foot == null)
	if on_foot == null:
		mopo.activate_camera()
	mopo.process_mode = Node.PROCESS_MODE_INHERIT
	for car in _cars:
		car.process_mode = Node.PROCESS_MODE_INHERIT
		car.visible = true
	active = true


## E ovilla ja automaatilla. Ei samassa ruudussa, jossa palattiin sisältä: ovesta ulos tullut painallus ei saa
## avata ovea heti uudelleen.
var _resume_frame := -1


var menu_open := false  # main.gd: eväsvalikko auki, sen E ei avaa ovia


func _interact() -> bool:
	return Input.is_action_just_pressed("interact") and Engine.get_process_frames() != _resume_frame and not menu_open


## Jalan: mopo parkkiin paikalleen (moottori sammuu), matka jatkuu kävelijän kohdalta. null = takaisin selkään.
func set_on_foot(walker: CharacterBody3D) -> void:
	on_foot = walker
	mopo.speed = 0.0
	mopo.velocity = Vector3.ZERO
	mopo.controls_enabled = walker == null
	mopo.set_engine(walker == null)
	mopo.set_rider_visible(walker == null)
	if walker == null:
		mopo.activate_camera()


## Pelaajan paikka tämän solmun kehyksessä (mopo tai kävelijä) ja seisooko hän (ovet avautuvat vain pysähtyneelle).
func _actor_pos() -> Vector3:
	return to_local(on_foot.global_position) if on_foot != null else mopo.position


func _actor_still() -> bool:
	return absf(on_foot.speed if on_foot != null else mopo.speed) < 2.0


## Kohteen paikka maailmassa (kompassia varten).
func target_global() -> Vector3:
	return to_global(vaala.siitari_door if target == "siitari" else vaala.road_pos(0))


## Todellinen matka kohteeseen metreinä mopon kohdalta tietä pitkin.
func real_left() -> float:
	var s: float = vaala.real_s(_sample)
	return (vaala.real_total - s) if target == "siitari" else s


func _process(delta: float) -> void:
	if not active or mopo == null:
		return
	if _down > 0.0:
		_down -= delta
		if _down <= 0.0:
			_get_up()
		hint = ""
		return
	var pos := _actor_pos()
	var ni: Array = vaala.nearest(pos)
	if ni[0] >= 0:
		_sample = ni[0]
	var kmh := absf(mopo.speed) * 3.6
	var left := real_left()
	var name: String = vaala.road_names[_sample] if ni[0] >= 0 and ni[1] < 12.0 else "maastossa"
	status = "%s\n%s · %s %s" % ["Jalan" if on_foot != null else "Mopo %d km/h" % roundi(kmh), name, "Siitari" if target == "siitari" else "Paapeli",
		("%.1f km" % (left / 1000.0)).replace(".", ",") if left > 150.0 else "%d m" % roundi(left)]
	hint = ""
	var near_door := {}
	var d_shop := INF
	for d in vaala.doors:
		var dd: float = pos.distance_to(d.pos)
		if dd < d_shop:
			d_shop = dd
			near_door = d
	var d_atm: float = pos.distance_to(vaala.atm_pos)
	if d_atm < 4.5 and d_atm <= d_shop and _actor_still():
		hint = "[E] Nosta rahaa pankkiautomaatista (20 € kerran päivässä)"
		if _interact():
			atm.emit()
		return
	if vaala.lava_door != Vector3.ZERO and pos.distance_to(vaala.lava_door) < 6.0 and _actor_still():
		hint = "[E] Oulujärven lava: lavatanssit (lippu %s €)" % ("%.2f" % LAVA_TICKET).replace(".", ",")
		if _interact():
			mopo.speed = 0.0
			lava.emit()
		return
	if d_shop < 5.0 and _actor_still():
		hint = "[E] %s%s" % ["Mene " if on_foot != null else "Parkkeeraa mopo ja mene ", near_door.hint]
		if _interact():
			mopo.speed = 0.0
			door.emit(near_door.id)
		return
	if target == "siitari":
		if pos.distance_to(vaala.siitari_park) < ARRIVE_R + 6.0 or \
				Vector2(pos.x - vaala.siitari_door.x, pos.z - vaala.siitari_door.z).length() < ARRIVE_R:
			hint = "[E] %s Siitariin" % ("Mene" if on_foot != null else "Parkkeeraa mopo ja mene")
			if _interact():
				mopo.position = vaala.siitari_park + Vector3(0, 0.3, 0)
				mopo.speed = 0.0
				stop()
				arrived.emit()
	elif on_foot == null and pos.distance_to(vaala.mokki_mopo) < HOME_YARD_R:
		# Mökin pihaan ajettaessa kartta vaihtuu mökille itsestään (mopo parkkiin kuten lähtiessä).
		stop()
		finished.emit("home")
