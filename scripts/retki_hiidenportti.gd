extends Node3D
## Hiidenportti, Sotkamo (retket.gd "hiidenportti"): taskukohtaus kuten retki_kuhmo.gd. Kävely player_walker.gd:llä.
## Takana kalliorotko jyrkkine seinineen ja puinen lepolava; sen vieressä [E] aloittaa kiipeilyn (rotko_game.gd). Retkeilijä kertoo rotkosta,
## infokyltti polun alussa. Paikka ja tiedot "sanotaan"-muodossa, tarkistettava; rotko on tyylitelty.
## Paikallinen -Z = rotko (takaseinä), +Z = polku ja kamera. Retkeilijä katsoo +Z:aan. Ei istuvia hahmoja.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Walker := preload("res://scripts/player_walker.gd")

const HALF := Vector2(8.0, 6.0)
const TILT := -25.0

signal exited
signal acted(kind: String)

var active := false
var busy := false
var walker: CharacterBody3D
var hint := ""
var spot := ""
var legenda: RefCounted
var spots := {
	"ovi": [Vector3(6.4, 0, 4.8), "[E] Ulos: taksille takaisin lähtöpaikkaan"],
	"opas": [Vector3(-3.6, 0, 1.0), "[E] Juttele retkeilijän kanssa"],
	"kyltti": [Vector3(3.6, 0, 3.4), "[E] Lue infokyltti"],
	"kiipea": [Vector3(0.0, 0, -2.2), "[E] Kiipeä rotkon seinää"],
}
var _enter_frame := -1
var _guide: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
const BUBBLE_AT := Vector3(-5.6, 0.4, 2.4)  # retkeilijän vasemmalla lattialla, ei hahmon päällä
const BUBBLE_FAR := 4.5
const GUIDE_LINES := ["Hiidenportti on rotkolaakso, sanotaan. Seinät nousevat jyrkkinä ja alhaalla on viileää.",
	"Kiipeä lavalta lavalle. Punertava ote on löysä, älä roiku siinä.",
	"Jos käsi lipeää, putoat vain edelliselle lavalle. Ei hätää, mutta nolottaa.",
	"Kunnolla ylös pääsee, kun muistaa levätä lavoilla. Kunto loppuu kesken, jos hosuu."]
var _line := 0


func _ready() -> void:
	_build()
	walker = Walker.new()
	walker.position = spots.ovi[0]
	walker.bounds = [Rect2(-HALF.x + 0.6, -HALF.y + 2.6, HALF.x * 2.0 - 1.2, HALF.y * 2.0 - 3.0)]
	add_child(walker)


func enter() -> void:
	active = true
	_enter_frame = Engine.get_process_frames()
	walker.position = spots.ovi[0] + Vector3(-2.6, 0, -0.9)
	walker.rotation.y = B.yaw_to(Vector3(-1, 0, -1))
	walker.visible = true
	walker.activate()


func leave() -> void:
	active = false
	walker.controls_enabled = false


func block_interact() -> void:
	_enter_frame = Engine.get_process_frames()


func say(text: String, t := 3.6) -> void:
	_bubble.text = text
	_bubble_t = t
	_guide.play("Idle_Talking", 0.2)


func next_line() -> String:
	_line = (_line + 1) % GUIDE_LINES.size()
	return GUIDE_LINES[_line]


func _process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble.text != "" and (_bubble_t <= 0.0 or (active and walker.position.distance_to(_guide.position) > BUBBLE_FAR)):
		_bubble.text = ""
		_guide.play("Idle", 0.3)
	if not active or busy or not walker.controls_enabled:
		hint = ""
		return
	var p := walker.position
	var best := ""
	var bd := 1.8
	for id in spots:
		var d := Vector2(p.x - spots[id][0].x, p.z - spots[id][0].z).length()
		if d < bd:
			bd = d
			best = id
	hint = ""
	spot = best
	if best == "":
		return
	hint = spots[best][1]
	if best == "kiipea" and legenda != null and legenda.nousuja > 0:
		hint = "[E] Kiipeä rotkon seinää (nousuja %d)" % legenda.nousuja
	if not Input.is_action_just_pressed("interact") or Engine.get_process_frames() == _enter_frame:
		return
	if best == "ovi":
		exited.emit()
	else:
		acted.emit(best)


# --- Rakennus -------------------------------------------------------------------------------

func _solid(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := B.mesh(self, B.boxm(size), pos, col)
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	add_child(body)
	return mi


func _pine(pos: Vector3, h: float) -> void:
	B.mesh(self, B.cyl(0.14, 0.2, h * 0.4, 8), pos + Vector3(0, h * 0.2, 0), Color(0.3, 0.2, 0.12))
	for k in 3:
		B.mesh(self, B.cyl(0.02, 1.0 - k * 0.25, h * 0.4, 8), pos + Vector3(0, h * (0.5 + k * 0.2), 0), Color(0.1, 0.27 + k * 0.03, 0.15))


func _build() -> void:
	var rock := Color(0.42, 0.42, 0.44)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.15, 0.2, 0.12))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), Color(0.3, 0.38, 0.22))
	B.mesh(self, B.boxm(Vector3(2.4, 0.006, HALF.y * 2.0)), Vector3(0, 0.002, 0), Color(0.45, 0.4, 0.3))  # polku rotkolle
	# Rotko: kaksi jyrkkää kalliota ja takaseinä (raot vasten toisiaan).
	_solid(Vector3(5.0, 7.0, 4.0), Vector3(-4.2, 3.5, -4.6), rock)
	_solid(Vector3(5.0, 8.0, 4.0), Vector3(4.2, 4.0, -4.6), rock.darkened(0.1))
	_solid(Vector3(3.6, 9.0, 0.6), Vector3(0, 4.5, -6.4), rock.darkened(0.25))
	B.mesh(self, B.boxm(Vector3(2.0, 0.3, 1.4)), Vector3(0, 0.15, -3.4), Color(0.5, 0.36, 0.22))  # alin lepolava
	B.mesh(self, B.boxm(Vector3(2.0, 0.3, 1.0)), Vector3(0, 2.4, -5.4), Color(0.5, 0.36, 0.22))  # ylälava
	for i in 4:  # portaat lavojen välillä
		B.mesh(self, B.boxm(Vector3(1.2, 0.12, 0.4)), Vector3(0.5, 0.5 + i * 0.5, -3.9 - i * 0.35), Color(0.45, 0.32, 0.2))
	for i in 7:
		_pine(Vector3(-12.0 + i * 4.0, 0, -8.0 + (i % 2) * 3.0), 6.0 + (i % 3) * 0.7)
	# Kyltit (kallistettu kameraa kohti, iso fontti).
	var bg := Color(0.2, 0.14, 0.09)
	var fg := Color(0.98, 0.92, 0.75)
	var edge := Color(0.7, 0.55, 0.35)
	var t1 := B.sign_plate(self, "HIIDENPORTTI", bg, fg, 0.34, 72, edge)
	t1.position = Vector3(0, 3.4, -2.8)
	t1.rotation_degrees.x = TILT
	B.sign_pole(self, Vector3(3.6, 0, 4.3), 1.3)
	var info := B.sign_plate(self, "SOTKAMO\nRotkolaakso\njyrkät seinät, sanotaan", bg, fg, 0.34, 62, edge)
	info.position = Vector3(3.6, 1.5, 4.2)
	info.rotation_degrees.x = -35.0
	# Retkeilijä (katsoo +Z:aan).
	_guide = Looks.make(self, {"shirt": Color(0.75, 0.3, 0.2), "pants": Color(0.22, 0.25, 0.35),
		"shoes": Color(0.12, 0.1, 0.08), "hair": "Hair_SimpleParted", "hair_color": Color(0.55, 0.4, 0.2), "height": 1.74})
	_guide.position = Vector3(-3.6, 0, -0.2)
	_guide.rotation.y = B.yaw_to(Vector3(0, 0, 1))
	_guide.play("Idle", 0.0)
	_bubble = B.bubble(self, BUBBLE_AT, Color.WHITE, 0.9)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 4.0, 1.0)
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.light_energy = 1.0
	lamp.omni_range = 12.0
	add_child(lamp)
