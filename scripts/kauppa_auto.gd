extends Node3D
## Kauppa-auto Paapelin mökillä: Neittävän kyläkauppa lopetti laman alla, joten kerran päivässä Kaisuantietä
## tulee vanha kauppa-auto (pakettiauto, katolla KAUPPA-AUTO-kyltti). Auto ajaa lännestä mökin pihatien päähän
## (STOP_LOCAL, Pekan auton itäpuolelle), tööttää ja odottaa WAIT s, avaa myyntiluukun kyljestä ja myy
## tavallisia tarvikkeita (main.gd _kauppa_auto_logic, MENU). Pihalta katsottuna auto tulee vasemmalta ja jatkaa
## oikealle: Kaisuantien päähän ja siitä naapurin pihaan (NEXT_LOCAL) seuraavalle asiakkaalle.
## Kaikki mökin paikallisessa kehyksessä (mokki.gd): lapsi mökin solmulle.

const B := preload("res://scripts/build.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const Looks := preload("res://scripts/looks.gd")
const Mokki := preload("res://scripts/mokki.gd")

const SPEED := 9.0          # m/s soratiellä
const WAIT := 150.0         # s pihatien päässä (odottaa niin kauan kuin asiakas on luukulla)
const NEXT_LOCAL := Vector3(58.0, 0, -63.0)  # naapurin piha Kaisuantien itäpään takana: tänne auto häviää
const STOP_LOCAL := Vector3(4.0, 0, -39.0)  # Kaisuantiellä n. 13 m Pekan auton itäpuolella
## Myytävät: avain -> [nimi, hinta]. Hinnat vähän kauppaa kalliimmat: bensa ja kuljetus.
const MENU := {
	"kalja": ["Kuutonen keskiolutta", 14.50],
	"makkara": ["Grillimakkara", 3.90],
	"tikut": ["Tulitikut", 1.30],
	"pulla": ["Korvapuusti", 1.80],
	"piirakka": ["Lihapiirakka", 2.50],
	"sokeri": ["Sokeri 1 kg (kotiviiniin)", 1.90],
	"turbohiiva": ["Turbohiiva (kotiviiniin)", 5.50],
	"lehti": ["Iltalehti", 1.50],
}
const LINES := [
	"Neittävän kauppa lopetti keväällä. Nyt mää kierrän nää kylät kahesti viikossa.",
	"Kortilla ei, pelkkä käteinen. Puolet korteista on nykyään hylättyjä.",
	"Pankki ei antanu lisää lainaa, ni tällä autolla mennään vielä pari kesää.",
	"Uutelanperällä on jo kolme taloa tyhjänä. Ei oo enää ketä palvella.",
	"Velaksi en anna. Viime talvena annoin, ja puolet muutti etelään.",
	"Santulle tuon aina suodatinkahvia. Se juo sitä kuin vettä.",
	"Kunta lopettaa kohta Pelson koulunki. Mihin ne lapset sitte?",
	"EU:sta ne puhuu, että kaikki halpenee. Mää uskon ku nään.",
]
const HELLO := ["No niin, kauppa-auto! Mitäs tänään?", "Päivää! Käteisellä, kiitos.", "Kas, Santun vieras. Mitä laitetaan?"]
## Iltalehden lööpit (lama ja 90-luku).
const HEADLINES := ["SKOP KAATUI – säästäjät jonossa", "TYÖTTÖMIÄ JO 450 000", "Markka devalvoitiin: ulkomaanmatkat kallistuu",
	"Konkurssiaalto jatkuu: kyläkauppoja suljetaan", "EU-KANSANÄÄNESTYS: Kyllä vai ei?", "Pankkituki nielee miljardit",
	"Maatilat velkakierteessä", "Lama hellittää? Ekonomisti uskoo käänteeseen"]

signal arrived  # tööttää pihatien päässä
signal left     # ajoi pois näkyvistä

var state := "away"  # away, coming, parked, leaving
var seller: Node3D
var wait_t := 0.0
var _route: Array[Vector3] = []   # tulomatka lännestä pysähdyspaikalle
var _onward: Array[Vector3] = []  # jatko pysähdyspaikalta tien päähän ja naapuriin
var _path: Array[Vector3] = []    # ajettava reitti
var _i := 0
var _model: Node3D
var _wheels: Array[Node3D] = []
var _engine: AudioStreamPlayer3D
var _body: StaticBody3D
var _hatch: MeshInstance3D
var _bubble: Label3D
var _bubble_t := 0.0


func _ready() -> void:
	_route = _build_route()
	_model = Node3D.new()
	add_child(_model)
	_wheels = Vehicles.van(_model, Color(0.92, 0.9, 0.82), "KAU-412")
	# Sininen raita kylkiin ja katolle KAUPPA-AUTO-kyltti.
	for sx in [-0.99, 0.99]:
		B.mesh(_model, B.boxm(Vector3(0.02, 0.22, 3.9)), Vector3(sx, 1.0, 0.45), Color(0.1, 0.3, 0.7))
	var sign := B.sign_plate(_model, "KAUPPA-AUTO", Color(0.1, 0.3, 0.7), Color(1.0, 0.95, 0.4), 0.42, 60)
	sign.position = Vector3(0, 2.55, 0.4)
	sign.rotation.y = PI / 2.0  # teksti kylkiin päin
	B.mesh(_model, B.boxm(Vector3(0.08, 0.3, 0.08)), Vector3(0, 2.33, 0.4), Color(0.3, 0.3, 0.32))
	# Myyntiluukku oikeassa kyljessä: kiinni ajaessa, auki (nostettu katokseksi) pysähtyneenä. Hyllyt sisällä.
	_hatch = B.mesh(_model, B.boxm(Vector3(0.04, 0.9, 1.6)), Vector3(1.0, 1.55, 0.7), Color(0.92, 0.9, 0.82))
	for k in 3:
		B.mesh(_model, B.boxm(Vector3(0.05, 0.04, 1.5)), Vector3(0.94, 1.2 + k * 0.32, 0.7), Color(0.55, 0.45, 0.3))
		for j in 5:
			var c: Color = [Color(0.85, 0.2, 0.15), Color(0.95, 0.85, 0.2), Color(0.2, 0.5, 0.85), Color(0.95, 0.95, 0.9),
				Color(0.3, 0.65, 0.3)][(j + k) % 5]
			B.mesh(_model, B.boxm(Vector3(0.1, 0.18, 0.2)), Vector3(0.9, 1.31 + k * 0.32, 0.15 + j * 0.28), c)
	seller = Looks.make(_model, {"model": "female", "shirt": Color(0.2, 0.35, 0.7), "pants": Color(0.2, 0.2, 0.25),
		"shoes": Color(0.15, 0.12, 0.1), "hair": "Hair_Buns", "hair_color": Color(0.55, 0.5, 0.48), "height": 1.62, "belly": 0.3})
	seller.position = Vector3(1.75, 0, 0.7)
	seller.rotation.y = PI / 2.0  # kasvot ulos kyljestä (+X)
	seller.visible = false
	_bubble = B.bubble(_model, Vector3(1.75, 2.5, 0.7))
	_body = StaticBody3D.new()
	_model.add_child(_body)
	_body.add_child(B.box_shape(Vector3(2.0, 2.2, 5.0), Vector3(0, 1.1, 0)))
	_set_solid(false)
	_engine = Sfx.loop_on(self, "engine", -12.0)
	_engine.stream_paused = true
	visible = false


## Tulomatka: Kaisuantie lännestä (n. 350 m) ja mökin kohdan pätkä pysähdyspaikalle asti.
func _build_route() -> Array[Vector3]:
	var west: Array[Vector3] = []
	var near: Array[Vector3] = []
	for r in Mokki.map_data().roads:
		if r.name != "Kaisuantie":
			continue
		var pts: PackedVector2Array = r.pts
		var to: Array[Vector3] = west if pts.size() > 15 else near
		for p in pts:
			to.append(Vector3(p.x, 0, p.y))
	var out: Array[Vector3] = []
	for p in west:
		if p.x > -330.0:  # lännen pätkän loppuosa (ei koko 600 m)
			out.append(p)
	var stop := STOP_LOCAL
	for k in range(1, near.size()):
		var p: Vector3 = near[k]
		if p.x < stop.x:
			out.append(p)
		else:
			_onward.append(p)
	out.append(stop)
	_onward.append(NEXT_LOCAL)
	return out


## Tulee pihatien päähän (kerran päivässä, main.gd).
func come() -> void:
	_path = _route.duplicate()
	_i = 1
	_place(_path[0], (_path[1] - _path[0]).normalized())
	state = "coming"
	visible = true
	_open(false)
	_engine.stream_paused = false


## Ajaa pois: jatkaa oikealle Kaisuantien päähän ja naapurin pihaan.
func leave() -> void:
	if state != "parked":
		return
	_path = _onward.duplicate()
	_i = 0
	state = "leaving"
	_open(false)
	_set_solid(false)
	_engine.stream_paused = false


func say(text: String, seconds := 3.5) -> void:
	_bubble.text = "Kauppa-auto: " + text
	_bubble_t = seconds


## Myyntiluukun etupuoli (paikallinen mökin kehys): tästä asioidaan.
func hatch_pos() -> Vector3:
	return transform * Vector3(2.6, 0, 0.7)


func _place(p: Vector3, dir: Vector3) -> void:
	position = Vector3(p.x, Mokki.h(p.x, p.z) + 0.05, p.z)
	if dir.length() > 0.01:
		rotation.y = B.yaw_to(dir)


func _open(on: bool) -> void:
	seller.visible = on
	# Luukku nostetaan ylös katokseksi.
	_hatch.position = Vector3(1.35, 2.05, 0.7) if on else Vector3(1.0, 1.55, 0.7)
	_hatch.rotation.z = -PI / 2.6 if on else 0.0
	if on:
		seller.play("Idle", 0.0)


func _set_solid(on: bool) -> void:
	for c in _body.get_children():
		(c as CollisionShape3D).disabled = not on


func _process(delta: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.text = ""
	if state != "coming" and state != "leaving":
		return
	var step := SPEED * delta
	if state == "coming" and _i == _path.size() - 1:
		step *= clampf(position.distance_to(_path[_i]) / 12.0, 0.25, 1.0)  # jarruttaa pysähdyspaikalle
	while step > 0.0 and _i < _path.size():
		var target := _path[_i]
		var flat := Vector3(target.x - position.x, 0, target.z - position.z)
		var d := flat.length()
		if d <= step:
			step -= d
			_place(target, flat)
			_i += 1
		else:
			_place(position + flat / d * step, flat)
			step = 0.0
	for w in _wheels:
		w.rotation.x -= SPEED * delta / 0.36
	if _i >= _path.size():
		_engine.stream_paused = true
		if state == "coming":
			state = "parked"
			wait_t = WAIT
			if _path.size() >= 2:
				_place(position, _path[-1] - _path[-2])
			_open(true)
			_set_solid(true)
			Sfx.play_on(self, "horn", 2.0, 0.85)
			arrived.emit()
		else:
			state = "away"
			visible = false
			left.emit()
