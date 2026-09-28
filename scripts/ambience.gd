extends Node
## Ympäristöäänet pelaajan sijainnin mukaan: metsän humina, lintukuoro kylässä, tuuli aukeilla,
## puro ja lammet, nuotion rätinä laavulla, satunnaiset varikset pelloilla, koirat pihoilla ja
## (hyttyset poistettu: ei CC0-äänitettä). Taustasilmukat häivytetään pehmeästi.

const M := preload("res://scripts/map_data.gd")

var world: Node3D
var player_ref: Callable  # palauttaa nykyisen pelaajasolmun (pyörä tai jalan)

var _loops := {}  # nimi -> AudioStreamPlayer
var _fire: AudioStreamPlayer3D
var _crow_t := 8.0
var _dog_t := 12.0
var _mix := {"forest": 0.0, "birds": 0.0, "wind": 0.0, "water": 0.0}
var _probe_t := 0.0


func _ready() -> void:
	for key in [["forest", "amb_forest"], ["birds", "amb_birds"], ["wind", "wind"], ["water", "water"]]:
		var p := AudioStreamPlayer.new()
		p.bus = "Ambience"
		p.stream = Sfx.stream(key[1])
		p.volume_db = -80.0
		add_child(p)
		p.play(randf() * 5.0)
		_loops[key[0]] = p


func _process(delta: float) -> void:
	if world == null or not player_ref.is_valid():
		return
	var player: Node3D = player_ref.call()
	if player == null or not player.visible:
		_fade_all(delta)
		return
	var p := player.global_position
	_probe_t -= delta
	if _probe_t <= 0.0:
		_probe_t = 0.4
		_probe(p, player)
	# Tasot desibeleiksi. Metsäsilmukka on hiljainen äänite, joten sitä vahvistetaan.
	var gains := {"forest": 14.0, "birds": -4.0, "wind": -8.0, "water": 2.0}
	for k in _loops:
		var target: float = linear_to_db(maxf(_mix[k], 0.0001)) + gains[k]
		var pl: AudioStreamPlayer = _loops[k]
		pl.volume_db = lerpf(pl.volume_db, target, 1.0 - exp(-1.5 * delta))
	_one_shots(delta, p)
	_update_fire()


## Näytteet ympäriltä: kuinka paljon metsää, taloja, peltoa ja vettä on lähellä.
func _probe(p: Vector3, player: Node3D) -> void:
	var forest := 0.0
	var open := 0.0
	var wet := 0.0
	var n := 0
	for r in [0.0, 25.0, 60.0]:
		for k in (1 if r == 0.0 else 8):
			var a := TAU * k / 8.0
			var s: String = world.surface_at(p + Vector3(cos(a) * r, 0, sin(a) * r))
			n += 1
			if s == "forest":
				forest += 1.0
			elif s in ["field", "meadow"]:
				open += 1.0
			elif s in ["water", "bog"]:
				wet += 1.0
	forest /= n
	open /= n
	var houses := 0
	for h in world._houses:
		if h.distance_squared_to(Vector2(p.x, p.z)) < 70.0 * 70.0:
			houses += 1
	var water_near := 0.0
	for poly in world._water:
		for q in poly:
			water_near = maxf(water_near, 1.0 - clampf(Vector2(p.x, p.z).distance_to(q) / 45.0, 0.0, 1.0))
	for srow in M.STREAMS:
		for q in srow:
			water_near = maxf(water_near, 1.0 - clampf(Vector2(p.x, p.z).distance_to(M.w2(q)) / 35.0, 0.0, 1.0))
	var spd: float = player.get("speed") if player.get("speed") != null else 0.0
	var still := 1.0 - clampf(absf(spd) / 3.0, 0.0, 1.0)
	_mix.forest = clampf(forest * 1.3, 0.0, 1.0)
	_mix.birds = clampf(0.25 + houses * 0.08, 0.0, 0.9) * (1.0 - _mix.forest * 0.5)
	_mix.wind = clampf(0.15 + open * 0.9 - houses * 0.03, 0.1, 1.0)
	_mix.water = water_near
	if OS.get_cmdline_user_args().has("--amb-debug"):
		print("AMB ", world.surface_at(p), " ", _mix)


func _one_shots(delta: float, p: Vector3) -> void:
	# Varikset raakkuvat pelloilla ja aukeilla.
	_crow_t -= delta
	if _crow_t <= 0.0:
		_crow_t = randf_range(9.0, 22.0)
		if _mix.wind > 0.5:
			var a := randf() * TAU
			Sfx.play_at(p + Vector3(cos(a) * 45.0, 12.0, sin(a) * 45.0), "crow", 4.0, randf_range(0.9, 1.1))
	# Koira haukkuu jonkun pihalla, kun taloja on lähellä.
	_dog_t -= delta
	if _dog_t <= 0.0:
		_dog_t = randf_range(18.0, 40.0)
		var best := Vector2.ZERO
		var bd := INF
		for h in world._houses:
			var d: float = h.distance_to(Vector2(p.x, p.z))
			if d > 25.0 and d < bd:
				bd = d
				best = h
		if bd < 120.0:
			Sfx.play_at(Vector3(best.x, 1.0, best.y), "dog", 2.0, randf_range(0.9, 1.1))


func _update_fire() -> void:
	if world.fire == null:
		return
	if _fire == null:
		_fire = AudioStreamPlayer3D.new()
		_fire.bus = "Ambience"
		_fire.stream = Sfx.stream("fire")
		_fire.unit_size = 6.0
		_fire.max_distance = 60.0
		_fire.volume_db = 8.0
		world.fire.add_child(_fire)
	if world.fire.visible and not _fire.playing:
		_fire.play()
	elif not world.fire.visible and _fire.playing:
		_fire.stop()


func _fade_all(delta: float) -> void:
	for k in _loops:
		var pl: AudioStreamPlayer = _loops[k]
		pl.volume_db = lerpf(pl.volume_db, -60.0, 1.0 - exp(-3.0 * delta))
