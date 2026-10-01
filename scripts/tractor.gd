extends CharacterBody3D
## Vihainen jyväjemmari traktorilla: kun pelaaja ajaa viljapellolle, traktori syöksyy perään.
## Kiinni jääminen -> challenge-signaali -> tappelu. Pelto ei hidasta traktoria, metsä ja räme kyllä.

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")

const SPEED := 8.5
const TURN_RATE := 1.8
const CATCH := 3.4
const RANGE := 260.0  # reagoi vain lähipelloille
const GIVE_UP := 5.0  # s pois pellolta
const LINES := ["POIS MUN VILJOISTA!", "Ne on siemenohraa!", "Mää ajan sut kumoon!", "Tää on mun pelto!",
	"Kuka sulle antoi luvan ajaa täällä?!", "Mää soitan MTK:lle!"]
## Traktorin nopeuskerroin alustoittain.
const GROUND := {"asphalt": 1.0, "gravel": 1.0, "lawn": 1.0, "meadow": 0.95, "field": 1.0, "forest": 0.35, "bog": 0.25, "water": 0.15}

signal challenge(foe_key: String, direction: Vector3)

var target: Node3D
var world: Node3D
var home := Vector3.ZERO
var mode := "idle"  # idle, chase, return, cooldown, defeated

var _speed := 0.0
var _off_field := 0.0
var _cool := 0.0
var _engine: AudioStreamPlayer3D
var _bubble: Label3D
var _bubble_t := 0.0
var _talk_t := 0.0
var _farmer: Node3D
var _rear: Array[Node3D] = []
var _front: Array[Node3D] = []


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(B.box_shape(Vector3(2.2, 2.6, 4.2), Vector3(0, 1.3, 0.2)))
	_build()
	home = position
	_engine = Sfx.loop_on(self, "tractor_engine", -2.0)
	_engine.pitch_scale = 0.8
	_bubble = B.bubble(self, Vector3(0, 3.6, 0), Color.WHITE)
	B.guide(self, "Jyväjemmari", Vector3(0, 3.15, 0), 42, Color(1, 0.9, 0.6), true)


## Punainen moderni traktori (vehicles.gd) ja kuski ohjaamossa.
func _build() -> void:
	var w: Dictionary = load("res://scripts/vehicles.gd").tractor(self, Color(0.72, 0.08, 0.06), "modern")
	for n in w.rear:
		_rear.append(n)
	for n in w.front:
		_front.append(n)
	_farmer = Looks.make(self, Looks.JEMMARI)
	_farmer.play("Driving", 0.0)
	_farmer.position = Vector3(0, 0.72, 0.82)
	# Istuma-asento: reidet eteen, sääret alas.
	for side in ["_l", "_r"]:
		_farmer.set_override("thigh" + side, Vector3.RIGHT, 1.45)
		_farmer.set_override("calf" + side, Vector3.RIGHT, -1.35)


func _physics_process(delta: float) -> void:
	if target == null or world == null:
		return
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""
	var tp := target.global_position
	var to_p := tp - global_position
	to_p.y = 0.0
	var d := to_p.length()
	var on_field: bool = world.surface_at(tp) == "field" and tp.distance_to(home) < RANGE
	var goal := home
	var want := 0.0
	match mode:
		"idle":
			if on_field:
				mode = "chase"
				_off_field = 0.0
				_say()
				Sfx.play_on(self, "horn", 4.0, 0.7)
		"chase":
			goal = tp
			want = SPEED
			_off_field = 0.0 if on_field else _off_field + delta
			_talk_t -= delta
			if _talk_t <= 0.0:
				_say()
			if _off_field > GIVE_UP:
				mode = "return"
				_bubble.text = "Jyväjemmari: Ja pysy poissa!"
				_bubble_t = 2.0
			elif d < CATCH:
				mode = "cooldown"
				_cool = 4.0
				challenge.emit("jemmari", to_p.normalized())
		"return", "defeated":
			want = SPEED * 0.6
			if global_position.distance_to(home) < 2.5:
				want = 0.0
				if mode == "return":
					mode = "idle"
		"cooldown":
			_cool -= delta
			if _cool <= 0.0:
				mode = "return"
	_drive(delta, goal, want)
	_farmer.play("Driving", 0.3)


func _drive(delta: float, goal: Vector3, want: float) -> void:
	var to_g := goal - global_position
	to_g.y = 0.0
	var diff := wrapf(B.yaw_to(to_g) - rotation.y, -PI, PI) if to_g.length() > 0.5 else 0.0
	var ground: float = GROUND.get(world.surface_at(global_position), 1.0)
	_speed = move_toward(_speed, want * ground * clampf(1.0 - absf(diff) / PI, 0.4, 1.0), 6.0 * delta)
	rotation.y += clampf(diff, -TURN_RATE * delta, TURN_RATE * delta) * clampf(_speed / 2.0, 0.2, 1.0)
	velocity = -global_transform.basis.z * _speed
	move_and_slide()
	global_position.y = Terrain.h(global_position.x, global_position.z)  # maaston pinnalla (sisätiloissa 0)
	for w in _rear:
		w.rotation.x -= _speed * delta / 0.82
	for w in _front:
		w.rotation.x -= _speed * delta / 0.5
	_engine.pitch_scale = 0.8 + _speed / SPEED * 0.35


## Pelaaja voitti: jemmari ajaa kotiin murjottamaan eikä enää jahtaa.
func defeat() -> void:
	mode = "defeated"
	_bubble.text = "Jyväjemmari: No ajakaa sitte mun pellolla..."
	_bubble_t = 3.0
	Sfx.babble(self, "pekka", _bubble.text)


func gloat() -> void:
	mode = "cooldown"
	_cool = 4.0
	_bubble.text = "Jyväjemmari: Tuosta sait, viljanpolkija!"
	_bubble_t = 2.5
	Sfx.babble(self, "pekka", _bubble.text)


func _say() -> void:
	_bubble.text = "Jyväjemmari: " + LINES.pick_random()
	_bubble_t = 2.4
	_talk_t = 3.0
	Sfx.babble(self, "pekka", _bubble.text)
