extends Node3D
## Seuranmäen kaukalon iltateinit (huumekauppa Saloisissa, K5): kolme nuorta seisoo ringissä kaukalon itälaidan
## ulkopuolella klo 20–01, kaiutin soi maassa ja tölkkejä on ympärillä. Ostavat oksikodonia ja pervitiiniä samaan
## hintaan kuin luukulla; myyntivalinnat, paljastuminen ja tappelu ovat main.gd:n (_hs_teens_logic). Täällä myös
## laavun valtaajateinien Saloinen-repliikit (laavu_guard.gd peaceful) ja rauhanrepliikit PEACE.
## Paikka lasketaan kaukalon kehyksestä (world.gd _build_kinnapotti -> kaukalo: keskipiste M.KAUKALO, yaw 0.35,
## laita x = ±12, valotolpat x = ±13.5, z = ±16.7): ringin keskipiste kaukalon paikallisessa (15.5, 0, 0), eli itälaidan
## ja valotolppien ulkopuolella, polusta yli 5 m. Kaukalon paikallinen +X = ulos itälaidalta.

const B := preload("res://scripts/build.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")

const RINK_YAW := 0.35  # world.gd: rink.rotation.y
const RINK_SPOT := Vector3(15.5, 0, 0)  # ringin keskipiste kaukalon paikallisessa
const RING_R := 0.85  # teinien etäisyys ringin keskeltä (hartiat eivät osu toisiinsa)
const AIKA := [20 * 60, 25 * 60]  # 20:00–01:00 minuutteina vuorokauden alusta (yli puolenyön +24 h)
const FACE_R := 9.0  # tätä lähempänä teinit kääntyvät pelaajaan

## Omat lookit, eri kuin Looks.TEENS (laavun jengi) ja Vaalan pihan nuoret: tuulipuku, huppari ja lippis, college.
const LOOKS := [
	{"shirt": Color(0.2, 0.22, 0.26), "pants": Color(0.18, 0.18, 0.2), "shoes": Color(0.95, 0.95, 0.95),
		"hair": "Hair_Buzzed", "hair_color": Color(0.55, 0.4, 0.22), "height": 1.78, "bulk": -0.6, "shoulders": -0.5,
		"tracksuit": {"a": Color(0.12, 0.14, 0.4), "b": Color(0.95, 0.95, 0.95)}},
	{"model": "female", "shirt": Color(0.55, 0.62, 0.55), "pants": Color(0.22, 0.24, 0.32), "shoes": Color(0.15, 0.15, 0.16),
		"hair": "Hair_Long", "hair_color": Color(0.85, 0.72, 0.45), "height": 1.64, "bulk": -0.55, "shoulders": -0.4},
	{"shirt": Color(0.75, 0.2, 0.12), "pants": Color(0.4, 0.42, 0.45), "shoes": Color(0.1, 0.1, 0.1),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.1, 0.08, 0.06), "height": 1.72, "bulk": -0.7, "shoulders": -0.6,
		"cap": true},
]
const ANIMS := ["Idle_Talking", "Idle", "Idle_Talking"]
const ANGLES := [PI, 1.15, -1.15]  # ringissä (rad +X:stä), avoin puoli +X eli poispäin kaukalosta, tulijaa kohti

const NAME := "Kaukalon teinit"
const KAUKALO_HELLO := ["No moi. Mitä sää täällä kaukalolla pyörit?", "Ei täällä oo mitään nähtävää, setä.",
	"Seuranmäen illat on meiän."]
const KAUKALO_CHAT := ["Kesällä tää kaukalo on pelkkää asfalttia. Talvella sit lätkää.",
	"Kinnapottiin tuli joku uus apteekki. Sanotaan et takaovelta saa ilman reseptiä.",
	"Valot sammuu yhdeltä. Sit mennään laavulle tai kotiin.", "Kentällä on päivisin pikkuskidit, ilta on meiän vuoro."]
const KAUKALO_EI_KAMAA := ["Ei meil oo mitään sulle. Tuu takas ku sulla on jotain myytävää.",
	"Jos saat jostain sitä Kinnapotin kamaa, me ostetaan."]
const KAUKALO_HYVA := ["Hyvää kamaa! Ei kysytä mistä.", "Toi on aitoo. Seuranmäki kiittää."]
const KAUKALO_MIETO := ["Hmm, aika mietoa... mut ok.", "Vähän laimeeta, mut kelpaa.", "Joo joo, ota rahat."]
const KAUKALO_KIINNI := "Hetkinen... toi on jauhoa! Toi on JATKETTUA! Sää yritit kusettaa meitä Seuranmäellä?!"
const KAUKALO_PAKO := "Teinit pakenivat kaukalon taakse. Ne ei enää osta sulta tänään mitään."
const KAUKALO_EI_OSTA := ["Painu siitä. Ei me sulta enää mitään osteta.", "Sää oot se jatkajasetä. Häivy."]

const LAAVU_NAME := "Teinijengin pomo"
const LAAVU_HELLO := ["No mitä? Onks sulla jotain vai tuutko vaan tuijottaan?", "Tää on meiän laavu. Mut puhutaan."]
const LAAVU_CHAT := ["Kaukalolla on illalla meiän kavereita. Ne ostaa kanssa.",
	"Sanotaan, et Kinnapotissa on joku mummo, joka myy takaovelta.", "Antinsuonkankaalla ei käy poliisi koskaan."]
const LAAVU_HYVA := ["Hyvää kamaa! Laavu kiittää.", "Okei, tää kelpaa. Saat istua nuotiolla."]
const LAAVU_MIETO := ["Laimeeta, mut otetaan.", "Vähän jauhosta, mut ok."]
const LAAVU_KIINNI := "Jätkät! Toi on jatkettua! Se luulee et laavulla ei tajuta mitään!"
const LAAVU_PAKO := "Teinijengi pakeni laavulta metsään. Ne ei enää osta sulta tänään mitään."
const LAAVU_EI_OSTA := ["Sää huijasit meitä. Ei kauppoja.", "Häivy laavulta, jatkaja."]

## Laavun pomo, kun repussa on myytävää (laavu_guard.peaceful): ei hyökkää, vaan tulee juttelemaan.
const PEACE := ["Hei, odota. Onks sulla sitä Kinnapotin kamaa?", "Rauhassa, setä. Puhutaan bisneksiä.",
	"Ei tapella. Mitä sulla on myytävänä?"]

var target: Node3D  # pelaaja: teinit kääntyvät häneen FACE_R:n sisällä
var teens: Array[Node3D] = []

var _ring := Vector3.ZERO  # ringin keskipiste (maailma, maaston korkeudella)
var _bubble: Label3D
var _bubble_t := 0.0
var _talk_t := 2.0


func _ready() -> void:
	if position == Vector3.ZERO:
		var kc := M.w2(M.KAUKALO)
		var p := Vector3(kc.x, 0, kc.y) + RINK_SPOT.rotated(Vector3.UP, RINK_YAW)
		position = Vector3(p.x, Terrain.h(p.x, p.z), p.z)
		rotation.y = RINK_YAW
	_ring = position
	_build_teens()
	_build_props()
	_bubble = B.bubble(teens[0], Vector3(0, 2.3, 0), Color.WHITE)
	B.guide(self, NAME, Vector3(0, 2.4, 0), 40, Color(0.85, 0.9, 1.0), true)


func _build_teens() -> void:
	for i in LOOKS.size():
		var look: Dictionary = LOOKS[i]
		var ch := Looks.make(self, look)
		var a: float = ANGLES[i]
		var lp := Vector3(cos(a), 0, sin(a)) * RING_R
		ch.position = Vector3(lp.x, _gy(lp), lp.z)
		ch.rotation.y = B.yaw_to(-lp)  # kasvot ringin keskelle
		ch.play(ANIMS[i], 0.0)
		if look.get("cap", false):
			Looks.add_cap(ch)
		var body := StaticBody3D.new()
		body.add_child(B.capsule_shape(0.3, 1.7))
		body.position = Vector3(0, 0.85, 0)
		ch.add_child(body)
		teens.append(ch)


## Kaiutin ja tölkit maan pinnalla (paikallinen y = maasto - juuren korkeus).
func _build_props() -> void:
	# Bluetooth-kaiutin kyljellään ringin keskellä: lieriö, kumipäädyt, kangasritilä ja kantolenkki.
	var spk := Node3D.new()
	var sp := Vector3(-0.1, 0, 0.05)
	spk.position = Vector3(sp.x, _gy(sp) + 0.085, sp.z)
	spk.rotation = Vector3(0, 0.4, PI / 2.0)
	add_child(spk)
	B.mesh(spk, B.cyl(0.085, 0.085, 0.24, 20), Vector3.ZERO, Color(0.1, 0.1, 0.12))
	for e in [-1.0, 1.0]:
		B.mesh(spk, B.cyl(0.09, 0.09, 0.025, 20), Vector3(0, e * 0.125, 0), Color(0.85, 0.2, 0.15))
	B.mesh(spk, B.cyl(0.088, 0.088, 0.16, 20), Vector3(0, 0, 0), Color(0.2, 0.2, 0.24))  # kangasritilä
	B.mesh(spk, B.boxm(Vector3(0.02, 0.1, 0.03)), Vector3(0.09, 0, 0), Color(0.85, 0.2, 0.15))  # nappirivi
	var ring := B.mesh(spk, B.cyl(0.012, 0.012, 0.06, 6), Vector3(0, 0.15, 0), Color(0.15, 0.15, 0.15))
	ring.rotation.x = PI / 2.0
	var mus := AudioStreamPlayer3D.new()
	var st: AudioStream = load("res://scripts/headphones.gd").random_90s()
	if st != null:
		mus.stream = st
		mus.bus = "Music"
		mus.volume_db = -16.0
		mus.unit_size = 3.0
		mus.max_distance = 26.0
		mus.autoplay = true
		spk.add_child(mus)
	# Tölkit: kaksi pystyssä, kaksi kyljellään (litistetty), kaikki yli 0,45 m teinien jaloista (ANGLES, RING_R).
	# Tölkki on lieriö, jolla on hopeinen kansi.
	var cans := [[Vector3(0.3, 0, -0.25), false, Color(0.15, 0.35, 0.75)], [Vector3(1.3, 0, 0.9), false, Color(0.85, 0.75, 0.15)],
		[Vector3(1.5, 0, -0.6), true, Color(0.15, 0.35, 0.75)], [Vector3(-0.3, 0, 1.35), true, Color(0.75, 0.1, 0.1)]]
	for c in cans:
		var cp: Vector3 = c[0]
		var can := Node3D.new()
		var lying: bool = c[1]
		can.position = Vector3(cp.x, _gy(cp) + (0.033 if lying else 0.06), cp.z)
		if lying:
			can.rotation = Vector3(PI / 2.0, cp.x * 2.0, 0)
			can.scale = Vector3(1, 0.8, 1)
		add_child(can)
		B.mesh(can, B.cyl(0.033, 0.033, 0.12, 12), Vector3.ZERO, c[2])
		B.mesh(can, B.cyl(0.03, 0.033, 0.008, 12), Vector3(0, 0.063, 0), Color(0.82, 0.82, 0.85))
		B.mesh(can, B.cyl(0.033, 0.03, 0.008, 12), Vector3(0, -0.063, 0), Color(0.7, 0.7, 0.72))


## Maaston korkeus paikallisessa pisteessä juuren suhteen (juuri on maaston korkeudella keskellä).
func _gy(lp: Vector3) -> float:
	var w := global_transform * lp if is_inside_tree() else position + lp.rotated(Vector3.UP, rotation.y)
	return Terrain.h(w.x, w.z) - position.y


func center() -> Vector3:
	return _ring


## Onko porukka kaukalolla kellonaikana (minuutit vuorokauden alusta, 0–1440).
static func on_time(minutes: float) -> bool:
	var m := minutes if minutes >= 12 * 60 else minutes + 24 * 60
	return m >= AIKA[0] and m < AIKA[1]


func set_on(on: bool) -> void:
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Kaikki kääntyvät katsomaan pistettä p (pelaaja).
func face(p: Vector3) -> void:
	for ch in teens:
		var d := p - ch.global_position
		d.y = 0.0
		if d.length() > 0.2:
			ch.rotation.y = lerp_angle(ch.rotation.y, B.yaw_to(d) - rotation.y, 0.15)


## Takaisin ringin keskelle päin.
func face_ring() -> void:
	for i in teens.size():
		var lp := teens[i].position
		lp.y = 0.0
		teens[i].rotation.y = lerp_angle(teens[i].rotation.y, B.yaw_to(-lp), 0.08)


## Puhekupla ensimmäisen teinin päälle (main.gd voi kutsua myynnin yhteydessä).
func say(text: String, t := 2.6) -> void:
	_bubble.text = NAME + ": " + text
	_bubble_t = t
	Sfx.babble(teens[0], "teini", text)


func _process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble_t <= 0.0 and _bubble.text != "":
		_bubble.text = ""
	if target == null:
		return
	var d := target.global_position - _ring
	d.y = 0.0
	if d.length() < FACE_R:
		face(target.global_position)
		_talk_t -= delta
		if _talk_t <= 0.0:
			_talk_t = 7.0
			say(KAUKALO_HELLO.pick_random())
	else:
		face_ring()
		_talk_t = 1.5
