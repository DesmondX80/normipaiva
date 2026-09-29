extends CharacterBody3D
## Vieras koira metsänreunassa (#11): isompi ja tummempi kuin Väinö, kuljeskelee paikkansa ympärillä.
## Lähestyvälle pelaajalle se murisee (growled), ja liian lähelle tultaessa se puree (bit) ja perääntyy.
## Puremasta seuraava haitta ja hoito ovat main.gd:ssä.

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const MODEL := preload("res://assets/animals/ShibaInu.glb")
const MODEL_SCALE := 0.28
const MODEL_YAW := PI  # malli katsoo +Z:aan, peli -Z:aan

const WALK := 1.6
const GROWL_DIST := 10.0
const BITE_DIST := 2.3
const ROAM := 7.0  # kuljeskelualue paikan ympärillä
const LEASH := 16.0  # kauemmas paikastaan koira ei lähde
const COOLDOWN := 15.0

signal growled
signal bit(direction: Vector3)

var target: Node3D
var world: Node3D
var spot: Vector3

var _goal := Vector3.ZERO
var _wait := 0.0
var _cool := 0.0
var _growl_t := 0.0
var _growling := false
var _speed := 0.0
var _anim: AnimationPlayer


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 0
	add_child(B.box_shape(Vector3(0.45, 0.7, 1.1), Vector3(0, 0.45, 0)))
	var m: Node3D = MODEL.instantiate()
	m.scale = Vector3.ONE * MODEL_SCALE
	m.rotation.y = MODEL_YAW
	add_child(m)
	_darken(m)
	_anim = m.find_child("AnimationPlayer", true, false)
	for n in ["Idle", "Walk", "Idle_2_HeadLow"]:
		_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")
	_goal = spot


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var to_p := target.global_position - global_position
	to_p.y = 0.0
	var d := to_p.length()
	var from_spot := Vector2(target.global_position.x - spot.x, target.global_position.z - spot.z).length()
	_cool -= delta
	var want := 0.0
	var face := Vector3.ZERO
	if _cool <= 0.0 and d < BITE_DIST:
		_cool = COOLDOWN
		_growling = false
		_anim.play("Attack", 0.1)
		Sfx.play_on(self, "dog", 4.0, 0.7)
		bit.emit(to_p.normalized())
		_goal = spot + (global_position - target.global_position).normalized() * 3.0
		_wait = 0.0
	elif _cool <= 0.0 and d < GROWL_DIST and from_spot < LEASH:
		# Murisee ja tuijottaa; lähestyy hitaasti, jos pelaaja jää paikalleen.
		if not _growling:
			_growling = true
			growled.emit()
		face = to_p
		want = 0.6 if d > BITE_DIST + 1.0 else 0.0
		_growl_t -= delta
		if _growl_t <= 0.0:
			_growl_t = 1.3
			Sfx.play_on(self, "dog", 0.0, randf_range(0.5, 0.58))
	else:
		_growling = false
		var to_g := _goal - global_position
		to_g.y = 0.0
		if to_g.length() < 0.8:
			_wait -= delta
			if _wait <= 0.0:
				var a := randf() * TAU
				_goal = spot + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, ROAM)
				_wait = randf_range(2.0, 5.0)
		else:
			face = to_g
			want = WALK
	_speed = move_toward(_speed, want, 6.0 * delta)
	if face.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, B.yaw_to(face), 1.0 - exp(-5.0 * delta))
	velocity = -global_transform.basis.z * _speed
	move_and_slide()
	global_position.y = T.h(global_position.x, global_position.z)
	if _anim.current_animation != "Attack" or not _anim.is_playing():
		var anim := "Walk" if _speed > 0.3 else ("Idle" if _growling else "Idle_2_HeadLow")
		if _anim.current_animation != anim:
			_anim.play(anim, 0.25)


## Tumma turkki: mallin värit tummennetaan kopioihin (Väinön materiaalit pysyvät ennallaan).
func _darken(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i) as StandardMaterial3D
			if mat == null:
				continue
			var name := mat.resource_name
			if name == "Main" or name == "Main_Light":
				var dark := mat.duplicate() as StandardMaterial3D
				dark.albedo_color = Color(0.2, 0.18, 0.17) if name == "Main" else Color(0.42, 0.39, 0.35)
				m.set_surface_override_material(i, dark)
