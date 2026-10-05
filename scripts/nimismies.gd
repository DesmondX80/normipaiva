extends CharacterBody3D
## Nimismies jalan: ilmestyy metsätieltä ja juoksee pelaajan perään (main.gd _nimismies_raid). Pelaaja pääsee
## karkuun juoksemalla kauas (GIVE_UP_D) tai pitämällä etumatkan GIVE_UP_T sekuntia; kiinni (CATCH_D) = sakko ja
## pontikat takavarikkoon (caught). Maan korkeus säteellä (mökin maasto).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

signal caught
signal gave_up

const LOOK := {
	"shirt": Color(0.12, 0.16, 0.3), "pants": Color(0.1, 0.12, 0.22), "shoes": Color(0.05, 0.05, 0.05),
	"hair": "Hair_Buzzed", "hair_color": Color(0.35, 0.3, 0.25), "height": 1.84, "belly": 0.35,
}
const SPEED := 4.2  # pelaaja juoksee 4,9 m/s: juokseva pääsee karkuun, kävelevä tai ontuva ei
const CATCH_D := 1.5
const GIVE_UP_D := 35.0
const GIVE_UP_T := 16.0

var target: Node3D
var _t := 0.0
var _done := false
var _body: Node3D
var _shout_t := 0.0
var _bubble: Label3D


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 1  # puut ja kivet pysäyttävät kuten pelaajankin (runko maan yläpuolella: maasto ei)
	var cs := CollisionShape3D.new()
	var cap_shape := CapsuleShape3D.new()
	cap_shape.radius = 0.3
	cap_shape.height = 1.2
	cs.shape = cap_shape
	cs.position.y = 1.1
	add_child(cs)
	_body = Looks.make(self, LOOK)
	var cap := Node3D.new()
	B.mesh(cap, B.cyl(0.13, 0.12, 0.08, 14), Vector3(0, 0.04, 0), Color(0.1, 0.12, 0.22))
	B.mesh(cap, B.boxm(Vector3(0.2, 0.015, 0.1)), Vector3(0, 0.0, -0.1), Color(0.05, 0.05, 0.06))
	B.mesh(cap, B.sphere(0.025, 6), Vector3(0, 0.05, -0.13), Color(0.9, 0.75, 0.2))
	_body.attach("Head", cap, Vector3(0, 0.2, 0))
	_body.play("Sprint", 0.0)
	_bubble = B.bubble(self, Vector3(0, 2.3, 0))
	_bubble.text = "Nimismies: SEIS! Poliisi!"


func _physics_process(delta: float) -> void:
	if _done or target == null:
		return
	_t += delta
	var to_p := target.global_position - global_position
	to_p.y = 0.0
	var d := to_p.length()
	if d < CATCH_D:
		_done = true
		_body.play("Idle_Talking", 0.2)
		_bubble.text = "Nimismies: Pontikkaa, vai? Sakko ja pullot takavarikkoon."
		caught.emit()
		return
	if d > GIVE_UP_D or _t > GIVE_UP_T:
		_done = true
		_body.play("Idle", 0.2)
		_bubble.text = "Nimismies: Perkele... huomenna uudestaan."
		gave_up.emit()
		return
	_shout_t -= delta
	if _shout_t <= 0.0:
		_shout_t = 3.0
		_bubble.text = ["Nimismies: SEIS!", "Nimismies: Tiedän kyllä, kuka olet!", "Nimismies: Pysähdy lain nimessä!"].pick_random()
	rotation.y = B.yaw_to(to_p)
	velocity = to_p.normalized() * SPEED
	move_and_slide()
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 3.0, global_position + Vector3.DOWN * 8.0)
	if target is CollisionObject3D:
		q.exclude = [(target as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position.y = hit.position.y
