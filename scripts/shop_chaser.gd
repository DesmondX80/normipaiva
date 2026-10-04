extends CharacterBody3D
## K-Marketin kauppias juoksukaljojen perässä (main.gd _start_shop_chase). Seisoo ensin ovella huutamassa (delay:
## etumatka, jolla taksille ehtii juuri ja juuri), sitten juoksee pelaajan perään nopeammin kuin pyörä kulkee.
## Kiinni saatuaan aloittaa tappelun (caught); tappelussa nyrkit ja potkut eivät tehoa, vain kaljojen heitto.

const B := preload("res://scripts/build.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")

const SPEED := 21.0  # pyörän huippu spurtilla 14 * 1,4 = 19,6 m/s
const CATCH_DIST := 1.5
const WAIT_LINES := ["SEIS! JUOKSUKALJAT!", "Hei! Ne on maksamatta!", "Nyt sää et pääse karkuun!"]
const RUN_LINES := ["Mää oon juossu Raahen maratonin!", "Seis tai tulee kung fuuta!", "Kaljat takasin!",
	"Ei mun kaupasta varastella!"]

signal caught(direction: Vector3)

var target_fn: Callable  # palauttaa pelaajan solmun
var ground_fn: Callable  # (x, z) -> y maailmassa; oletuksena Saloisten maasto (Vaalassa Vaalan maasto)
var delay := 3.0  # etumatka sekunteina
var mode := "wait"  # wait, chase, done

var _body: Node3D
var _bubble: Label3D
var _talk_t := 0.0
var _bubble_t := 0.0
var _anim := ""


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 0  # juoksee esteiden läpi: ei jää autoihin tai aitoihin jumiin
	collision_mask = 0
	_body = Looks.make(self, Looks.KAUPPIAS)
	_bubble = B.bubble(self, Vector3(0, 2.4, 0), Color.WHITE)
	_say(WAIT_LINES.pick_random())
	_play("Idle_Talking")


func _physics_process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""
	var t: Node3D = target_fn.call() if target_fn.is_valid() else null
	if t == null or mode == "done":
		return
	var to := t.global_position - global_position
	to.y = 0.0
	if to.length() > 0.1:
		look_at(global_position - to, Vector3.UP)  # malli katsoo +Z:aan
	if mode == "wait":
		delay -= delta
		if delay <= 0.0:
			mode = "chase"
			_play("Sprint")
			Sfx.play_on(self, "alert", -2.0, 0.9)
		return
	if to.length() < CATCH_DIST:
		mode = "done"
		_play("Idle")
		caught.emit(to.normalized())
		return
	var step := minf(SPEED * delta, to.length())
	global_position += to.normalized() * step
	global_position.y = ground_fn.call(global_position.x, global_position.z) if ground_fn.is_valid() \
		else Terrain.h(global_position.x, global_position.z)
	_talk_t -= delta
	if _talk_t <= 0.0:
		_talk_t = randf_range(2.5, 4.0)
		_say(RUN_LINES.pick_random())


func is_chasing() -> bool:
	return mode in ["wait", "chase"]


## Pelaaja ehti taksiin: kauppias jää huutamaan ja palaa kauppaan.
func give_up() -> void:
	mode = "done"
	_play("Idle")
	_say(["Pelkuri! Taksilla karkuun!", "Mää muistan sun naaman!"].pick_random())
	_leave(2.5)


## Hävisi tappelun: laahustaa kassalle.
func defeat() -> void:
	mode = "done"
	_say("Pidä sitte kaljas... ens kerralla maksetaan.")
	_leave(2.5)


## Voitti tappelun: kaljat takaisin hyllyyn.
func gloat() -> void:
	mode = "done"
	_say("Kaljat takasin hyllyyn! Ja ens kerralla maksetaan!")
	_leave(3.0)


func _leave(after: float) -> void:
	var tw := create_tween()
	tw.tween_interval(after)
	tw.tween_callback(queue_free)


func _say(text: String) -> void:
	_bubble.text = "Kauppias: " + text
	_bubble_t = 2.5


func _play(anim: String) -> void:
	if anim != _anim:
		_anim = anim
		_body.play(anim, 0.2)
