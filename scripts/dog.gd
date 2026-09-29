extends CharacterBody3D
## Pekan koira Väinö karkuteillä (main.gd: _vaino_logic). Juoksee ensin pitkän pätkän karkuun, sitten
## vuorottelee nuuhkimista ja kuljeskelua. Lähestyvä pelaaja säikyttää sen pakoon: juoksu ja pyörä kuuluvat
## kauas, kävellen pääsee nuuhkivan koiran viereen. Grillimakkara (lure) houkuttelee sen luo istumaan.
## Kiinni otettuna (catch) Väinö seuraa pelaajaa.

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")

const RUN := 6.4
const TROT := 2.0
const TURN := 5.0
const NOTICE_WALK := 2.2  # nuuhkiva koira huomaa kävelijän vasta näin läheltä
const NOTICE_LOUD := 9.0  # juoksija tai pyöräilijä kuuluu kauas
const SPOOK_WALK := 5.0  # kuljeskeleva koira säikähtää kävelijää
const SPOOK_LOUD := 12.0
const LURE_DIST := 16.0
const MODEL := preload("res://assets/animals/ShibaInu.glb")
const MODEL_SCALE := 0.2
const MODEL_YAW := PI  # malli katsoo +Z:aan, peli -Z:aan

var target: Node3D
var world: Node3D
var home: Vector3  # Pekan piha: tänne päin käännytään kartan reunalta
var lure := false  # pelaajalla on grillimakkara (ja jalan)
var mode := "bolt"  # bolt, sniff, wander, flee, lured, follow

var _dir := Vector3.FORWARD
var _t := 6.0
var _speed := 0.0
var _notice := 0.0
var _bark_t := 3.0
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _anim: AnimationPlayer


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(B.box_shape(Vector3(0.35, 0.5, 0.8), Vector3(0, 0.35, 0)))
	collision_layer = 0  # ei tönäise pelaajaa eikä autoja
	_build()


## Karkaa: pitkä pyrähdys annettuun suuntaan.
func bolt(dir: Vector3, seconds: float) -> void:
	mode = "bolt"
	_dir = Vector3(dir.x, 0, dir.z).normalized()
	_t = seconds
	Sfx.play_on(self, "dog", 2.0)


func is_catchable() -> bool:
	return mode in ["sniff", "lured"]


func catch() -> void:
	mode = "follow"
	Sfx.play_on(self, "dog", -2.0, 1.2)


func distance_to_target() -> float:
	if target == null:
		return INF
	var d := target.global_position - global_position
	return Vector2(d.x, d.z).length()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var to_p := target.global_position - global_position
	to_p.y = 0.0
	var d := to_p.length()
	var loud := absf(float(target.get("speed"))) > 2.6  # juoksee tai ajaa pyörällä
	var want := 0.0
	_t -= delta
	if lure and not (mode in ["follow", "lured"]) and d < LURE_DIST:
		mode = "lured"
		Sfx.play_on(self, "dog", -4.0, 1.3)
	match mode:
		"bolt":
			want = RUN
			if _t <= 0.0:
				_sniff()
		"sniff":
			if d < (NOTICE_LOUD if loud else NOTICE_WALK):
				_notice += delta
			else:
				_notice = maxf(0.0, _notice - delta)
			if _notice > 0.45:
				_flee(to_p)
			elif _t <= 0.0:
				mode = "wander"
				_t = randf_range(4.0, 8.0)
				_dir = _dir.rotated(Vector3.UP, randf_range(-1.5, 1.5))
		"wander":
			want = TROT
			_dir = _dir.rotated(Vector3.UP, randf_range(-0.8, 0.8) * delta)
			if d < (SPOOK_LOUD if loud else SPOOK_WALK):
				_flee(to_p)
			elif _t <= 0.0:
				_sniff()
		"flee":
			want = RUN
			var away := -to_p.normalized()
			_dir = _dir.lerp(away, 1.0 - exp(-2.0 * delta)).normalized()
			if _t <= 0.0 and d > 24.0:
				_sniff()
		"lured":
			if not lure:
				_sniff()
			elif d > 1.4:
				want = RUN * 0.6
				_dir = to_p.normalized()
		"follow":
			var behind := target.global_position + target.global_transform.basis.z * 1.6
			var to_b := behind - global_position
			to_b.y = 0.0
			if to_b.length() > 0.6:
				_dir = to_b.normalized()
				want = clampf(to_b.length() * 2.5, 0.0, 11.0)
	_avoid_edges()
	_move(delta, want)
	_animate()
	_bark_t -= delta
	if _bark_t <= 0.0 and mode != "follow":
		_bark_t = randf_range(4.0, 8.0)
		Sfx.play_on(self, "dog", -3.0, randf_range(0.9, 1.1))


func _sniff() -> void:
	mode = "sniff"
	_t = randf_range(3.0, 6.0)
	_notice = 0.0


func _flee(to_p: Vector3) -> void:
	mode = "flee"
	_t = randf_range(3.0, 5.0)
	_dir = (-to_p.normalized()).rotated(Vector3.UP, randf_range(-0.6, 0.6))
	Sfx.play_on(self, "dog", 0.0, 1.15)


## Kartan reunalla ja vedessä käännytään kotia kohti.
func _avoid_edges() -> void:
	if world == null or mode == "follow":
		return
	var ahead := global_position + _dir * 4.0
	if world._play_edge_dist(Vector2(ahead.x, ahead.z)) < 12.0 or world.surface_at(ahead) == "water":
		var to_home := home - global_position
		to_home.y = 0.0
		_dir = to_home.normalized().rotated(Vector3.UP, randf_range(-0.5, 0.5))


func _move(delta: float, want: float) -> void:
	var ground: float = world.speed_factor(global_position, "runner") if world != null else 1.0
	_speed = move_toward(_speed, want * ground, 14.0 * delta)
	if _speed > 0.1:
		rotation.y = lerp_angle(rotation.y, B.yaw_to(_dir), 1.0 - exp(-TURN * delta))
	velocity = -global_transform.basis.z * _speed
	move_and_slide()
	global_position.y = T.h(global_position.x, global_position.z)
	# Jumissa (talo, aita): uusi suunta.
	_stuck_t += delta
	if _stuck_t > 1.0:
		if _speed > 1.0 and global_position.distance_to(_stuck_pos) < 0.5:
			_dir = _dir.rotated(Vector3.UP, randf_range(1.5, 3.0))
		_stuck_t = 0.0
		_stuck_pos = global_position


## Animaatio tilan ja vauhdin mukaan: laukka, kävely, nuuhkiminen pää maassa tai seisoskelu.
func _animate() -> void:
	var anim := "Idle"
	if _speed > 3.2:
		anim = "Gallop"
	elif _speed > 0.3:
		anim = "Walk"
	elif mode == "sniff":
		anim = "Idle_2_HeadLow"
	elif mode == "lured":
		anim = "Eating"
	if _anim.current_animation != anim:
		_anim.play(anim, 0.25)
	_anim.speed_scale = clampf(_speed / (RUN if anim == "Gallop" else TROT), 0.6, 1.6) if _speed > 0.3 else 1.0


## Quaterniuksen Shiba Inu (CC0, assets/animals): muistuttaa suomenpystykorvaa.
func _build() -> void:
	var m: Node3D = MODEL.instantiate()
	m.scale = Vector3.ONE * MODEL_SCALE
	m.rotation.y = MODEL_YAW
	add_child(m)
	_anim = m.find_child("AnimationPlayer", true, false)
	for n in ["Idle", "Idle_2_HeadLow", "Walk", "Gallop", "Eating"]:
		_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")
