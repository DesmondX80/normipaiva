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


func _solid_box(size: Vector3, pos: Vector3) -> void:  # näkymätön törmäys kalliolle
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(B.box_shape(size))
	add_child(body)


## Kallio umpinaisista laatoista: joka 0,5 m kerros on oma laatikkonsa (tumma alhaalla, vaalea ylhäällä), kerroksen reuna pistää
## vaalealla huulella ulos, pinnalla on kuhmuja, halkeamia ja sammalta. Paikallinen +X = rotkoa kohti, +Z = kamera, -X = kallion sisus.
## sx = +1 vasen kallio (rotko on sen +X-puolella), -1 oikea (peilattu), takaseinä +1; pos = sisäpinnan sijainti, yaw = kääntö (takaseinä -90).
func _cliff(sx: float, pos: Vector3, yaw: Vector3, height: float, width: float, rock: Color, seed_: int, zhalf := 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var h := Node3D.new()
	h.position = pos
	h.rotation_degrees = yaw
	add_child(h)
	var back := -7.0 - pos.z if yaw == Vector3.ZERO else -zhalf
	var front_z := 0.0 if yaw == Vector3.ZERO else zhalf
	var n := int(height / 0.5)
	var dark := rock.darkened(0.35)
	var light := rock.lightened(0.25)
	var moss := Color(0.24, 0.4, 0.15)
	for i in n:
		var t := float(i) / float(n - 1)
		var y := (i + 0.5) * 0.5
		var off := rng.randf_range(-0.15, 0.6) * (1.0 if i > 1 else 0.0)  # alimmat kerrokset leveimpiä: porrastus ylöspäin
		var zf := front_z - rng.randf_range(0.0, 0.75)
		var col := dark.lerp(light, t * 0.8)
		col = Color(col.r + rng.randf_range(-0.03, 0.03), col.g + rng.randf_range(-0.03, 0.03), col.b + rng.randf_range(-0.03, 0.03))
		var face := off + 0.0
		var depth := zf - back
		var cz := (zf + back) / 2.0
		B.mesh(h, B.boxm(Vector3(width, 0.5, depth)), Vector3(sx * (-width / 2.0 + face), y, cz), col)
		# vaalea huuli kerroksen yläreunassa, työntyy pinnasta ulos
		B.mesh(h, B.boxm(Vector3(width + 0.2, 0.1, depth + 0.1)), Vector3(sx * (-width / 2.0 + face + 0.1), y + 0.2, cz + 0.05), col.lightened(0.14))
		# tumma varjo alareunassa
		B.mesh(h, B.boxm(Vector3(width + 0.04, 0.08, depth + 0.02)), Vector3(sx * (-width / 2.0 + face + 0.02), y - 0.21, cz + 0.01), col.darkened(0.3))
		# kuhmuja sisäpinnalla ja kameran puoleisella otsapinnalla
		for k in 2:
			var cl := rng.randf_range(0.35, 1.0)
			var cp := rng.randf_range(0.15, 0.4)
			var czp := rng.randf_range(back + cl, zf - cl) if zf - back > cl * 2.0 + 0.2 else cz
			B.mesh(h, B.boxm(Vector3(cp * 2.0, 0.34, cl)), Vector3(sx * (face), y - 0.02, czp), col.lightened(rng.randf_range(-0.05, 0.1)), Vector3(0, sx * rng.randf_range(-10, 10), 0))
		var fw := rng.randf_range(0.5, 1.2)
		B.mesh(h, B.boxm(Vector3(fw, 0.34, 0.3)), Vector3(sx * (-width * rng.randf_range(0.1, 0.9) + face), y - 0.02, zf), col.lightened(rng.randf_range(-0.04, 0.1)), Vector3(0, rng.randf_range(-8, 8), 0))
		# sammalta huulen päällä
		if rng.randf() < 0.45 or i < 3:
			var mw := rng.randf_range(0.5, 1.3)
			var mm := B.mesh(h, B.boxm(Vector3(0.5, 0.07, mw)), Vector3(sx * (face + 0.1), y + 0.27, rng.randf_range(back + 0.4, zf - 0.4)), moss.lerp(Color(0.35, 0.5, 0.2), rng.randf()))
			mm.rotation_degrees.y = sx * rng.randf_range(-15, 15)
		# halkeamat: ohuet tumma raidat kerroksen omalla pinnalla (eivät ylitä kerrosta, joten eivät pistä ulos)
		for k in 2:
			if rng.randf() < 0.55:
				B.mesh(h, B.boxm(Vector3(0.05, 0.4, 0.04)), Vector3(sx * (face + 0.03), y - 0.02, rng.randf_range(back + 0.3, zf - 0.3)), Color(0.06, 0.06, 0.07), Vector3(0, 0, sx * rng.randf_range(-20, 20)))
				B.mesh(h, B.boxm(Vector3(0.04, 0.34, 0.05)), Vector3(sx * rng.randf_range(-width * 0.8, -0.2), y - 0.02, zf + 0.16), Color(0.06, 0.06, 0.07), Vector3(0, 0, rng.randf_range(-20, 20)))
	# metsäinen kansi ja sammalmättäitä
	B.mesh(h, B.boxm(Vector3(width, 0.18, front_z - back)), Vector3(sx * (-width / 2.0 + 0.2), height + 0.05, (front_z + back) / 2.0), Color(0.2, 0.32, 0.14))
	for k in 6:
		var bump := B.mesh(h, B.sphere(0.4), Vector3(sx * rng.randf_range(-width + 0.4, 0.0), height + 0.1, rng.randf_range(back + 0.4, front_z - 0.3)), moss.lerp(Color(0.18, 0.3, 0.12), rng.randf()))
		bump.scale = Vector3(1.0, 0.45, 1.0) * rng.randf_range(0.8, 1.4)
	# lohkareita ja sammalta kallion juurella
	for k in 4:
		var r := rng.randf_range(0.25, 0.5)
		var st := B.mesh(h, B.sphere(r), Vector3(sx * rng.randf_range(0.1, 0.45), r * 0.5, rng.randf_range(back + 0.5, front_z - 0.2)), rock.lightened(rng.randf_range(-0.05, 0.1)))
		st.scale = Vector3(1.0, 0.7, 1.1)


## Puro rotkon pohjalla: mutkitteleva sininen kaista takaseinän alta ulos vasemmalle, kiviä ja vaahtoa.
func _creek() -> void:
	var pts := [Vector3(-1.2, 0, -6.0), Vector3(-1.4, 0, -4.6), Vector3(-1.3, 0, -3.2), Vector3(-1.7, 0, -2.0), Vector3(-3.0, 0, -1.2),
		Vector3(-5.0, 0, -1.4), Vector3(-7.2, 0, -0.6)]
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := b - a
		var w := 0.55 + 0.12 * (i % 2)
		var mi := B.mesh(self, B.boxm(Vector3(w, 0.03, d.length() + 0.25)), (a + b) / 2.0 + Vector3(0, 0.015, 0), Color(0.28, 0.5, 0.65))
		mi.rotation.y = atan2(d.x, d.z)
		var fo := B.mesh(self, B.boxm(Vector3(0.06, 0.035, d.length() * 0.5)), (a + b) / 2.0 + Vector3(0.12 * (1 if i % 2 == 0 else -1), 0.02, 0), Color(0.85, 0.93, 0.97))
		fo.rotation.y = mi.rotation.y
		for k in 2:
			var c := a.lerp(b, 0.3 + 0.4 * k) + Vector3(0.3 * (1 if (i + k) % 2 == 0 else -1), 0.05, 0)
			var st := B.mesh(self, B.sphere(0.15), c, Color(0.5, 0.5, 0.52))
			st.scale = Vector3(1.0, 0.6, 1.0)


func _build() -> void:
	var rock := Color(0.42, 0.42, 0.44)
	B.mesh(self, B.boxm(Vector3(140, 0.2, 80)), Vector3(0, -0.4, 0), Color(0.15, 0.2, 0.12))
	B.mesh(self, B.boxm(Vector3(HALF.x * 2.0, 0.1, HALF.y * 2.0)), Vector3(0, -0.05, 0), Color(0.3, 0.38, 0.22))
	B.mesh(self, B.boxm(Vector3(2.4, 0.006, HALF.y * 2.0)), Vector3(0, 0.002, 0), Color(0.45, 0.4, 0.3))  # polku rotkolle
	# Rotko: kolme kerroksittain porrastettua kalliota (vasen, oikea, takaseinä), puro pohjalla, puita reunalla.
	_cliff(1.0, Vector3(-1.7, 0, -2.6), Vector3.ZERO, 7.0, 5.0, rock, 11)
	_cliff(-1.0, Vector3(1.7, 0, -2.6), Vector3.ZERO, 8.0, 5.0, rock.darkened(0.08), 23)
	_cliff(1.0, Vector3(0, 0, -6.1), Vector3(0, -90, 0), 9.0, 1.0, rock.darkened(0.2), 37, 5.2)
	_solid_box(Vector3(5.0, 7.0, 4.4), Vector3(-4.2, 3.5, -4.8))
	_solid_box(Vector3(5.0, 8.0, 4.4), Vector3(4.2, 4.0, -4.8))
	_solid_box(Vector3(3.6, 9.0, 0.6), Vector3(0, 4.5, -6.4))
	_creek()
	B.mesh(self, B.boxm(Vector3(2.0, 0.3, 1.4)), Vector3(0, 0.15, -3.4), Color(0.5, 0.36, 0.22))  # alin lepolava
	B.mesh(self, B.boxm(Vector3(2.0, 0.3, 1.0)), Vector3(0, 2.4, -5.4), Color(0.5, 0.36, 0.22))  # ylälava
	for i in 4:  # portaat lavojen välillä
		B.mesh(self, B.boxm(Vector3(1.2, 0.12, 0.4)), Vector3(0.5, 0.5 + i * 0.5, -3.9 - i * 0.35), Color(0.45, 0.32, 0.2))
	for i in 7:
		_pine(Vector3(-12.0 + i * 4.0, 0, -9.5 - (i % 2) * 2.0), 6.0 + (i % 3) * 0.7)
	for i in 5:  # havupuita rotkon reunalla
		_pine(Vector3(-2.6 - i * 1.0, 7.1, -3.6 - (i % 3) * 1.1), 2.6 + (i % 3) * 0.5)
		_pine(Vector3(2.6 + i * 1.0, 8.1, -3.8 - ((i + 1) % 3) * 1.1), 2.8 + (i % 2) * 0.6)
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
