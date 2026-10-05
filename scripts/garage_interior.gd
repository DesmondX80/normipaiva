extends Node3D
## Kodin autotallin sisätila: erillinen tasku kuten kodin sisätila (home_interior.gd). Nosturiovelta sisään
## (main.gd _enter_garage), kävely player_walker.gd:llä ylhäältä kuvattuna, katto pois. Vasemmalla vanha punainen
## auto SLN-73 konepelti auki (karburaattorin säätö, carb_game.gd), perällä työpöytä radioineen ja työkalutaulu,
## oikealla punainen työkalukaappi (autotallin kaljajemma, main.gd _stash_ui), vasemmalla perällä pakastearkku ja
## oven vieressä pyörän paikka. Toiminnot ilmoitetaan acted-signaalilla (main.gd _on_garage_acted); työkalukaapin
## jemman hoitaa main.gd suoraan (spot == "kaappi").
## Paikallinen +Z = nosturiovi (kameran puoli), -Z = takaseinä, -X = vasen.

const B := preload("res://scripts/build.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(4.2, 5.0)
const WALL_H := 2.6
const RED := Color(0.55, 0.12, 0.1)
const SPOTS := {
	"ovi": [Vector3(0.0, 0, 4.3), "[E] Ulos nosturiovesta"],
	"auto": [Vector3(-1.8, 0, 1.2), "[E] Säädä SLN-73:n karburaattoria"],
	"tyopoyta": [Vector3(1.4, 0, -3.6), "[E] Työpöytä"],
	"radio": [Vector3(3.0, 0, -3.6), "[E] Radio päälle"],
	"kaappi": [Vector3(3.2, 0, -0.6), ""],  # jemma: vihje ja näppäimet main.gd:stä
	"arkku": [Vector3(-3.0, 0, -3.4), "[E] Avaa pakastearkku"],
	"pyora": [Vector3(2.6, 0, 3.0), ""],
	"saavi": [Vector3(-3.0, 0, -2.2), ""],  # kotiviini: vihje main.gd:stä
}

signal exited
signal acted(kind: String)

var active := false
var busy := false  # minipeli auki (main.gd)
var walker: CharacterBody3D
var hint := ""
var spot := ""  # lähin toimintopiste
var radio_on := false
var bike_in := false
var _enter_frame := -1
var _bike: Node3D
var _radio: Node3D
var _radio_player: AudioStreamPlayer3D
var _notes: Array[Label3D] = []
var _hood: Node3D
var wine_stage := ""  # "" tyhjä, "kay" käymässä, "valmis"
var _wine_liquid: MeshInstance3D
var _wine_cover: Node3D
var _blubs: Array[Label3D] = []
var _blub_t := 0.0


func _ready() -> void:
	_build_room()
	_build_car()
	_build_bench()
	_build_cabinet_and_freezer()
	_build_bike()
	_build_vat()
	walker = Walker.new()
	add_child(walker)
	walker.position = SPOTS.ovi[0] + Vector3(0, 0, -1.2)


func enter(with_bike: bool) -> void:
	active = true
	set_bike(with_bike)
	_enter_frame = Engine.get_process_frames()
	walker.position = SPOTS.ovi[0] + Vector3(-0.8 if with_bike else 0.0, 0, -1.0)
	walker.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	walker.activate()
	_set_radio(radio_on)


func leave() -> void:
	active = false
	walker.controls_enabled = false
	_set_radio(false, false)


func set_bike(on: bool) -> void:
	bike_in = on
	_bike.visible = on


func toggle_radio() -> void:
	radio_on = not radio_on
	_set_radio(radio_on)


func _set_radio(on: bool, remember := true) -> void:
	if remember:
		radio_on = on
	if on and active:
		if _radio_player.stream == null:
			_radio_player.stream = Sfx.music_stream()
		if _radio_player.stream != null and not _radio_player.playing:
			_radio_player.play(randf() * 60.0)
	else:
		_radio_player.stop()
	for n in _notes:
		n.visible = on and active


## Viinisaavin tila: tyhjä, käymässä (kansi, vesilukko pulputtaa) tai valmis (kansi auki, viini kiiltää).
func set_wine(stage: String) -> void:
	wine_stage = stage
	_wine_liquid.visible = stage != ""
	_wine_cover.visible = stage == "kay"
	(_wine_liquid.material_override as StandardMaterial3D).albedo_color = Color(0.45, 0.05, 0.2) if stage == "valmis" \
		else Color(0.35, 0.12, 0.25)
	for bl in _blubs:
		bl.visible = false


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if wine_stage == "kay":
		_blub_t -= delta
		if _blub_t <= 0.0:
			_blub_t = randf_range(1.2, 2.6)
			for bl in _blubs:
				if not bl.visible:
					bl.visible = true
					bl.position = Vector3(-3.62, 1.05, -2.2)
					bl.modulate.a = 1.0
					if active:
						Sfx.play_on(self, "water", -22.0, 2.4, 0.3)
					break
		for bl in _blubs:
			if bl.visible:
				bl.position.y += delta * 0.4
				bl.modulate.a -= delta * 0.6
				if bl.modulate.a <= 0.0:
					bl.visible = false
	for i in _notes.size():
		var n := _notes[i]
		var ph := fmod(t * 0.5 + i * 0.33, 1.0)
		n.position = Vector3(3.0 + sin(ph * 6.0 + i) * 0.25, 1.35 + ph * 0.9, -4.35)
		n.modulate.a = 1.0 - ph
	if not active or busy:
		hint = ""
		spot = ""
		return
	var p := walker.position
	spot = ""
	var bd := 1.3
	for id in SPOTS:
		if id == "pyora" and not bike_in:
			continue
		var d := Vector2(p.x - SPOTS[id][0].x, p.z - SPOTS[id][0].z).length()
		if d < bd:
			bd = d
			spot = id
	hint = ""
	if spot == "":
		return
	hint = SPOTS[spot][1]
	if spot == "radio":
		hint = "[E] Radio pois" if radio_on else "[E] Radio päälle (Iskelmä)"
	elif spot == "pyora":
		hint = "[E] Ota pyörä ja aja ulos"
	if spot == "kaappi" or not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	match spot:
		"ovi":
			exited.emit()
		"radio":
			toggle_radio()
			acted.emit("radio")
		_:
			acted.emit(spot)


# --- Rakennus ---------------------------------------------------------------------

func _build_room() -> void:
	var conc := Color(0.56, 0.56, 0.54)
	var brick := Color(0.84, 0.72, 0.5)
	B.mesh(self, B.boxm(Vector3(60, 0.2, 60)), Vector3(0, -0.2, 0), Color(0.12, 0.12, 0.14))
	var floor_mi := B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), conc)
	(floor_mi.material_override as StandardMaterial3D).roughness = 0.9
	for k in 4:  # betonilaattojen saumat
		B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.005, 0.03)), Vector3(0, 0.003, -3.75 + k * 2.5), conc.darkened(0.15))
	B.mesh(self, B.cyl(0.9, 0.9, 0.01, 20), Vector3(-1.6, 0.006, -0.8), Color(0.13, 0.12, 0.11))  # öljytahra auton alla
	B.mesh(self, B.cyl(0.35, 0.35, 0.01, 14), Vector3(-0.4, 0.007, 0.9), Color(0.16, 0.14, 0.12))
	# Seinät: takaseinä ja sivut täyskorkeat, ovenpuoli matala (nosturiovi auki).
	B.box(self, Vector3(HALF.x * 2.0 + 0.4, WALL_H, 0.2), Vector3(0, WALL_H / 2.0, -HALF.y - 0.1), brick)
	for sx in [-1.0, 1.0]:
		B.box(self, Vector3(0.2, WALL_H, HALF.y * 2.0), Vector3(sx * (HALF.x + 0.1), WALL_H / 2.0, 0), brick)
	for sx in [-1.0, 1.0]:
		B.box(self, Vector3(HALF.x - 1.6, 0.6, 0.2), Vector3(sx * (HALF.x + 1.6) / 2.0, 0.3, HALF.y + 0.1), brick)
	# Nosturioven kiskot (ovi itse on nostettu katon rajaan, ei näy ylhäältä kuvattuna).
	for sx in [-1.0, 1.0]:
		B.mesh(self, B.boxm(Vector3(0.05, 0.05, 2.4)), Vector3(sx * 1.65, WALL_H - 0.1, HALF.y - 1.2), Color(0.5, 0.5, 0.52))
	# Loisteputket katossa.
	for z in [-2.5, 1.5]:
		B.mesh(self, B.boxm(Vector3(1.4, 0.06, 0.12)), Vector3(0, WALL_H - 0.05, z), Color(0.95, 0.97, 1.0))
		var l := OmniLight3D.new()
		l.position = Vector3(0, WALL_H - 0.2, z)
		l.light_color = Color(0.92, 0.96, 1.0)
		l.light_energy = 0.9
		l.omni_range = 7.0
		add_child(l)
	# Talvirenkaat pinossa ja öljykanisterit hyllyllä.
	for k in 4:
		var tire := TorusMesh.new()
		tire.inner_radius = 0.22
		tire.outer_radius = 0.36
		B.mesh(self, tire, Vector3(-3.5, 0.1 + k * 0.2, 3.9), Color(0.08, 0.08, 0.08))
	B.box(self, Vector3(0.45, 1.8, 2.0), Vector3(-3.95, 0.9, 1.2), Color(0.5, 0.4, 0.28))  # hylly vasemmalla seinällä
	for k in 5:
		B.mesh(self, B.boxm(Vector3(0.22, 0.3, 0.16)), Vector3(-3.75, 1.05 + (k % 2) * 0.55, 0.5 + k * 0.32),
			[Color(0.85, 0.65, 0.1), Color(0.2, 0.35, 0.7), Color(0.75, 0.15, 0.1)][k % 3])
	B.guide(self, "Kalenteri 1987", Vector3(-1.0, 1.9, -4.85), 22, Color(0.95, 0.95, 0.9), false)


## Vanha punainen auto keula ovelle päin, konepelti auki, moottori ja karburaattori näkyvissä.
func _build_car() -> void:
	var car := Node3D.new()
	car.position = Vector3(-1.6, 0, -0.9)
	car.rotation.y = PI
	add_child(car)
	Vehicles.car(car, RED, "SLN-73")
	_hood = Vehicles.slab(car, Vector3(0, 0.95, -0.95), Vector3(0, 1.9, -1.4), 1.7, 0.06, Vehicles.paint(RED))
	B.box(car, Vector3(0.9, 0.3, 0.8), Vector3(0, 0.95, -1.5), Color(0.2, 0.2, 0.22), false)  # moottori
	B.mesh(car, B.cyl(0.14, 0.14, 0.18, 12), Vector3(0, 1.15, -1.5), Color(0.6, 0.6, 0.62))  # ilmanpuhdistin
	var body := StaticBody3D.new()
	body.add_child(B.box_shape(Vector3(1.9, 1.5, 4.4), Vector3(0, 0.75, 0)))
	car.add_child(body)
	# Työkalut lattialla auton vieressä.
	B.mesh(self, B.boxm(Vector3(0.5, 0.18, 0.28)), Vector3(-0.3, 0.09, 1.6), Color(0.75, 0.12, 0.1))  # työkalulaatikko
	B.mesh(self, B.boxm(Vector3(0.25, 0.02, 0.05)), Vector3(-0.2, 0.02, 2.0), Color(0.7, 0.7, 0.72), Vector3(0, 30, 0))


## Työpöytä takaseinällä: työkalutaulu, ruuvipenkki, radio ja kuutosen tyhjät.
func _build_bench() -> void:
	var wood := Color(0.48, 0.33, 0.2)
	B.box(self, Vector3(3.6, 0.9, 0.8), Vector3(1.8, 0.45, -4.5), wood)
	B.mesh(self, B.boxm(Vector3(3.7, 0.06, 0.85)), Vector3(1.8, 0.92, -4.5), wood.lightened(0.15))
	B.mesh(self, B.boxm(Vector3(3.2, 1.1, 0.04)), Vector3(1.6, 1.75, -4.88), Color(0.75, 0.65, 0.48))  # reikälevy
	for i in 9:
		var col: Color = [Color(0.3, 0.3, 0.32), Color(0.75, 0.12, 0.1), Color(0.85, 0.65, 0.1)][i % 3]
		B.mesh(self, B.boxm(Vector3(0.05, 0.3 + (i % 3) * 0.08, 0.03)), Vector3(0.3 + i * 0.32, 1.75, -4.84), col)
	B.mesh(self, B.boxm(Vector3(0.25, 0.18, 0.3)), Vector3(0.4, 1.04, -4.45), Color(0.25, 0.35, 0.55))  # ruuvipenkki
	for i in 4:
		B.mesh(self, B.cyl(0.033, 0.033, 0.12, 10), Vector3(1.3 + i * 0.1, 1.01, -4.35), Color(0.8, 0.75, 0.2))
	# Radio: kotelo, kaiutinritilä ja antenni.
	_radio = Node3D.new()
	_radio.position = Vector3(3.0, 0.95, -4.5)
	add_child(_radio)
	B.mesh(_radio, B.boxm(Vector3(0.5, 0.28, 0.18)), Vector3(0, 0.14, 0), Color(0.2, 0.18, 0.16))
	B.mesh(_radio, B.cyl(0.08, 0.08, 0.02, 14), Vector3(-0.12, 0.14, 0.095), Color(0.55, 0.55, 0.55), Vector3(90, 0, 0))
	B.mesh(_radio, B.boxm(Vector3(0.18, 0.06, 0.02)), Vector3(0.12, 0.18, 0.095), Color(0.9, 0.7, 0.3))
	B.mesh(_radio, B.cyl(0.006, 0.006, 0.6, 4), Vector3(0.2, 0.55, 0), Color(0.75, 0.75, 0.78), Vector3(0, 0, -20))
	_radio_player = AudioStreamPlayer3D.new()
	_radio_player.bus = "Music"
	_radio_player.unit_size = 4.0
	_radio_player.volume_db = -6.0
	_radio.add_child(_radio_player)
	for i in 3:
		var n := B.guide(self, ["♪", "♫", "♪"][i], Vector3(3.0, 1.4, -4.35), 48, Color(1.0, 0.9, 0.4), true)
		n.visible = false
		_notes.append(n)


## Punainen työkalukaappi oikealla seinällä ja pakastearkku vasemmalla perällä.
func _build_cabinet_and_freezer() -> void:
	var red := Color(0.72, 0.1, 0.08)
	B.box(self, Vector3(0.6, 1.3, 1.1), Vector3(3.85, 0.65, -0.6), red)
	for k in 5:
		B.mesh(self, B.boxm(Vector3(0.02, 0.2, 1.0)), Vector3(3.54, 0.25 + k * 0.24, -0.6), red.darkened(0.2))
		B.mesh(self, B.boxm(Vector3(0.03, 0.03, 0.4)), Vector3(3.52, 0.3 + k * 0.24, -0.6), Color(0.8, 0.8, 0.82))
	B.guide(self, "Työkalukaappi", Vector3(3.6, 1.55, -0.6), 22, Color(1, 1, 1), true)
	B.box(self, Vector3(1.3, 0.85, 0.7), Vector3(-3.3, 0.425, -4.4), Color(0.95, 0.95, 0.94))  # pakastearkku
	B.mesh(self, B.boxm(Vector3(1.32, 0.05, 0.72)), Vector3(-3.3, 0.87, -4.4), Color(0.88, 0.88, 0.9))
	B.mesh(self, B.boxm(Vector3(0.3, 0.04, 0.04)), Vector3(-3.3, 0.8, -4.04), Color(0.6, 0.6, 0.62))
	B.mesh(self, B.sphere(0.02, 6), Vector3(-2.75, 0.7, -4.04), Color(0.2, 0.9, 0.3))  # merkkivalo


## Viinisaavi vasemmalla perällä: puinen saavi vanteineen, viini, liinakansi ja vesilukko.
func _build_vat() -> void:
	var c := Vector3(-3.62, 0, -2.2)
	var wood := Color(0.52, 0.34, 0.18)
	B.box(self, Vector3(0.8, 0.12, 0.8), c + Vector3(0, 0.06, 0), Color(0.35, 0.25, 0.15))  # jalusta
	B.mesh(self, B.cyl(0.36, 0.31, 0.65, 18), c + Vector3(0, 0.45, 0), wood)
	for y in [0.22, 0.68]:
		B.mesh(self, B.cyl(0.355 if y > 0.5 else 0.325, 0.355 if y > 0.5 else 0.325, 0.04, 18), c + Vector3(0, y, 0), Color(0.3, 0.3, 0.32))
	for k in 10:  # laudoitus
		var a := k * TAU / 10.0
		B.mesh(self, B.boxm(Vector3(0.012, 0.64, 0.02)), c + Vector3(cos(a) * 0.335, 0.45, sin(a) * 0.335), wood.darkened(0.25),
			Vector3(0, -rad_to_deg(a), 0))
	var body := StaticBody3D.new()
	body.position = c + Vector3(0, 0.4, 0)
	body.add_child(B.box_shape(Vector3(0.75, 0.8, 0.75)))
	add_child(body)
	_wine_liquid = B.mesh(self, B.cyl(0.33, 0.33, 0.02, 18), c + Vector3(0, 0.74, 0), Color(0.35, 0.12, 0.25))
	_wine_cover = Node3D.new()
	_wine_cover.position = c + Vector3(0, 0.79, 0)
	add_child(_wine_cover)
	B.mesh(_wine_cover, B.cyl(0.38, 0.38, 0.015, 18), Vector3.ZERO, Color(0.9, 0.88, 0.82))  # liina
	B.mesh(_wine_cover, B.cyl(0.03, 0.03, 0.18, 8), Vector3(0, 0.1, 0), Color(0.85, 0.9, 0.92, 0.8))  # vesilukko
	B.mesh(_wine_cover, B.sphere(0.045, 8), Vector3(0, 0.2, 0), Color(0.8, 0.9, 0.95))
	for i in 3:
		var bl := B.guide(self, "blub", c + Vector3(0, 1.0, 0), 26, Color(0.9, 0.7, 0.85), true)
		bl.visible = false
		_blubs.append(bl)
	B.guide(self, "Viinisaavi", c + Vector3(0, 1.3, 0), 22, Color(1, 1, 1), true)
	set_wine("")


## Pyörä telineessä oven vieressä (näkyy, kun se on tuotu talliin).
func _build_bike() -> void:
	_bike = Node3D.new()
	_bike.position = Vector3(3.2, 0, 3.0)
	add_child(_bike)
	var frame := Color(0.78, 0.08, 0.08)
	for z in [-0.55, 0.55]:
		var tire := TorusMesh.new()
		tire.inner_radius = 0.3
		tire.outer_radius = 0.36
		B.mesh(_bike, tire, Vector3(0, 0.36, z), Color(0.06, 0.06, 0.06), Vector3(0, 0, 90))
	B.tube(_bike, Vector3(0, 0.36, 0.55), Vector3(0, 0.75, 0.05), 0.025, frame)
	B.tube(_bike, Vector3(0, 0.75, 0.05), Vector3(0, 0.8, -0.45), 0.025, frame)
	B.tube(_bike, Vector3(0, 0.36, 0.0), Vector3(0, 0.75, 0.05), 0.025, frame)
	B.tube(_bike, Vector3(0, 0.36, 0.0), Vector3(0, 0.8, -0.45), 0.025, frame)
	B.tube(_bike, Vector3(0, 0.8, -0.45), Vector3(0, 0.36, -0.55), 0.022, frame)
	B.tube(_bike, Vector3(-0.28, 1.0, -0.45), Vector3(0.28, 1.0, -0.45), 0.02, Color(0.7, 0.7, 0.72))
	B.tube(_bike, Vector3(0, 0.8, -0.45), Vector3(0, 1.0, -0.45), 0.02, Color(0.7, 0.7, 0.72))
	B.mesh(_bike, B.boxm(Vector3(0.14, 0.05, 0.26)), Vector3(0, 0.82, 0.1), Color(0.08, 0.08, 0.08))
	_bike.visible = false
