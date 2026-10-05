extends Node3D
## Korpi-Kalle: Neittävän korpikeittäjä mökin metsässä (paikka Mokki.still_position). Vanha maitotonkka pannuna
## kivien päällä tulella, kuparikierukka puroveden jäähdyttämään saaviin, tisle lasipulloihin, risuista ja
## pressusta tehty suoja ja savu, joka nousee kuusikosta. Myy pontikkaa (main.gd _kalle_logic); nimismiehen
## ratsian jälkeen Kalle piiloutuu loppupäiväksi (set_hiding). Paikallinen -Z = kohti mökkiä.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const KALLE := {
	"shirt": Color(0.3, 0.32, 0.22), "pants": Color(0.2, 0.2, 0.24), "shoes": Color(0.1, 0.08, 0.06),
	"hair": "Hair_Long", "hair_color": Color(0.6, 0.58, 0.55), "beard": true, "height": 1.7,
	"skin": Color(0.95, 0.8, 0.72), "belly": 0.2, "bulk": -0.3, "shoulders": -0.2,
}
const LINES := ["Kuka sut tänne lähetti? Santtu, vai?", "Tonkasta tulee parempaa kuin Alkon hyllystä.",
	"Kahdestoista kesä samalla pannulla. Nimismies ei ole vielä löytänyt.", "Hiljaa! Kuulitko auton?",
	"Puolukasta saa makua, mutta sokeri sen tekee.", "Pelson vangit osti multa aikoinaan. Hyviä asiakkaita."]

var kalle: Node3D
var hiding := false
var _bubble: Label3D
var _bubble_t := 0.0


func _ready() -> void:
	_build_still()
	kalle = Looks.make(self, KALLE)
	kalle.position = Vector3(-0.9, 0, -0.9)
	kalle.rotation.y = PI * 0.85
	kalle.play("Crouch_Idle", 0.0)
	_bubble = B.bubble(self, Vector3(-0.9, 2.3, -0.9))


func say(text: String, seconds := 3.2) -> void:
	if hiding:
		return
	_bubble.text = "Korpi-Kalle: " + text
	_bubble_t = seconds
	kalle.play("Idle_Talking", 0.3)


func set_hiding(on: bool) -> void:
	hiding = on
	kalle.visible = not on
	if on:
		_bubble.text = ""


func _process(delta: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.text = ""
			kalle.play("Crouch_Idle", 0.3)


func _build_still() -> void:
	var stone := Color(0.45, 0.44, 0.42)
	var steel := Color(0.72, 0.73, 0.75)
	var copper := Color(0.72, 0.4, 0.2)
	var body := StaticBody3D.new()
	add_child(body)
	for k in 8:  # tulisija kivistä
		var a := TAU * k / 8.0
		B.mesh(self, B.sphere(0.14, 8), Vector3(cos(a) * 0.45, 0.1, sin(a) * 0.45), stone.lightened(0.08 * sin(k * 2.3)))
	var glow := B.unshaded(Color(1.0, 0.45, 0.08))
	for k in 3:
		var f := MeshInstance3D.new()
		f.mesh = B.boxm(Vector3(0.3, 0.18, 0.06))
		f.material_override = glow
		f.position = Vector3(0, 0.2, 0)
		f.rotation.y = k * PI / 3.0
		add_child(f)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 0.8
	light.omni_range = 4.0
	light.position = Vector3(0, 0.4, 0)
	add_child(light)
	# Maitotonkka pannuna: runko, olka, kaula ja kansi, kansi tiivistetty taikinalla.
	B.mesh(self, B.cyl(0.24, 0.26, 0.55, 16), Vector3(0, 0.62, 0), steel)
	B.mesh(self, B.cyl(0.12, 0.24, 0.16, 16), Vector3(0, 0.97, 0), steel)
	B.mesh(self, B.cyl(0.12, 0.12, 0.12, 14), Vector3(0, 1.11, 0), steel)
	B.mesh(self, B.cyl(0.14, 0.14, 0.03, 14), Vector3(0, 1.18, 0), Color(0.85, 0.8, 0.65))  # taikinatiiviste
	# Kuparikierukka jäähdytyssaaviin ja tisle pulloon.
	B.tube(self, Vector3(0, 1.2, 0), Vector3(0.7, 1.25, 0.1), 0.02, copper)
	B.tube(self, Vector3(0.7, 1.25, 0.1), Vector3(1.2, 0.85, 0.15), 0.02, copper)
	B.mesh(self, B.cyl(0.32, 0.28, 0.6, 14), Vector3(1.35, 0.3, 0.15), Color(0.48, 0.32, 0.18))  # puusaavi
	B.mesh(self, B.cyl(0.3, 0.3, 0.02, 14), Vector3(1.35, 0.58, 0.15), Color(0.35, 0.45, 0.5))  # vesi
	for k in 4:
		B.mesh(self, B.cyl(0.1, 0.1, 0.02, 10), Vector3(1.35, 0.35 + k * 0.06, 0.15), copper)  # kierukka
	B.tube(self, Vector3(1.6, 0.15, 0.2), Vector3(1.85, 0.14, 0.35), 0.012, copper)
	for k in 5:  # pullot
		var bt := B.mesh(self, B.cyl(0.04, 0.045, 0.28, 8), Vector3(1.75 + (k % 3) * 0.12, 0.14, 0.55 + (k / 3) * 0.12),
			Color(0.85, 0.92, 0.95, 0.75))
		B.mesh(bt, B.cyl(0.015, 0.015, 0.05, 6), Vector3(0, 0.16, 0), Color(0.4, 0.3, 0.2))
	# Sokerisäkit, puupino ja risu-pressu-suoja.
	for k in 3:
		B.mesh(self, B.boxm(Vector3(0.45, 0.2, 0.3)), Vector3(-1.5, 0.1 + k * 0.2, 0.5), Color(0.93, 0.92, 0.86))
	for k in 6:
		B.mesh(self, B.cyl(0.07, 0.07, 0.7, 8), Vector3(-1.4, 0.07 + (k % 3) * 0.14, -0.2 + (k / 3) * 0.15),
			Color(0.55, 0.4, 0.25), Vector3(0, 0, 90))
	for x in [-2.2, -0.2]:
		B.mesh(self, B.cyl(0.04, 0.05, 1.9, 6), Vector3(x, 0.95, -1.7), Color(0.35, 0.26, 0.17))
	var tarp := B.mesh(self, B.boxm(Vector3(2.4, 0.02, 1.8)), Vector3(-1.2, 1.55, -1.1), Color(0.3, 0.32, 0.22))
	tarp.rotation.x = -0.5
	for k in 10:  # kuusenhavut pressun päällä
		var br := B.mesh(self, B.boxm(Vector3(0.6, 0.04, 0.2)), Vector3(-2.2 + k * 0.22, 1.6 + sin(k) * 0.05, -1.1 + cos(k * 1.7) * 0.4),
			Color(0.16, 0.3, 0.16))
		br.rotation = Vector3(-0.5, k * 0.7, 0.1)
	B.mesh(self, B.cyl(0.2, 0.22, 0.42, 10), Vector3(-0.9, 0.21, -0.4), Color(0.5, 0.38, 0.25))  # istumapölkky
	body.add_child(B.box_shape(Vector3(0.7, 1.2, 0.7), Vector3(0, 0.6, 0)))
	body.add_child(B.box_shape(Vector3(0.7, 0.6, 0.7), Vector3(1.35, 0.3, 0.15)))
	# Savu nousee kuusikosta: näkyy kauas (ja droonilla).
	var smoke := CPUParticles3D.new()
	smoke.position = Vector3(0, 1.3, 0)
	smoke.amount = 26
	smoke.lifetime = 6.0
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.3, 0.6, 0)
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.0
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.6
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.75, 0.78, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	smoke.mesh = sm
	add_child(smoke)
	Sfx.loop_on(self, "fire", -16.0)
