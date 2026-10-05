extends CharacterBody3D
## Naapuri pihallaan (Arto, Pekka, Sinikka): puuhailee pihalla (kävelee puuhapisteestä toiseen ja tekee niissä
## hetken jotain), kääntyy pelaajaa kohti ja juttelee, kun tämä on lähellä.
## Kaupankäynti ja muu toiminta hoidetaan main.gd:ssä (E-näppäin lähellä).

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Terrain := preload("res://scripts/terrain.gd")

const WALK_SPEED := 1.1
const NEAR := 14.0  # tätä lähempänä pelaaja: puuhailu keskeytyy ja naapuri kääntyy juttelemaan
const CLEAR := 0.7  # etäisyys, jolla kierretään seinät ja pihaesteet

var look := {}
var display_name := ""
var lines: Array = []
var voice := "mummo"
var target: Node3D
## Pihan puuhapisteet maailmassa (ensimmäinen = ulko-ovi, lähtöpaikka). Tyhjä = seisoo paikallaan.
var yard: Array[Vector3] = []
## Valinnainen: mihin kukin puuhapiste katsoo (esim. kukkapenkki), sama järjestys kuin yard.
var faces: Array[Vector3] = []
## Puuhailuanimaatiot (Universal Animation Library); arvotaan jokaiseen puuhapisteeseen.
var chores: Array[String] = ["Fixing_Kneeling", "PickUp_Table", "Interact", "Crouch_Idle"]
## Lähialueen rakennukset ja pihaesteet [keskipiste (x, z), puolikoko, yaw] (world.blockers); reitti kiertää ne.
var obstacles: Array = []

var _body: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _talk_t := 0.0
var _goal := -1  # yard-indeksi, jota kohti kävellään (-1 = puuhailee paikallaan)
var _spot := 0
var _chore_t := 0.0
var _chore := "Idle"
var _route: Array[Vector3] = []  # kulmapisteet matkalla kohti yard[_goal]


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(B.capsule_shape(0.35, 1.8))
	_body = Looks.make(self, look)
	B.guide(self, display_name, Vector3(0, 2.1, 0), 40, Color(0.9, 0.95, 1.0), true)
	_bubble = B.bubble(self, Vector3(0, 2.6, 0), Color.WHITE)
	_chore_t = randf_range(1.0, 4.0)  # hetki oven edessä ennen ensimmäistä puuhaa


func _physics_process(delta: float) -> void:
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""
	var d := INF
	var to_p := Vector3.ZERO
	if target != null:
		to_p = target.global_position - global_position
		to_p.y = 0.0
		d = to_p.length()
	if d < NEAR:
		rotation.y = lerp_angle(rotation.y, B.yaw_to(to_p), 1.0 - exp(-4.0 * delta))
		_talk_t -= delta
		if _talk_t <= 0.0 and d < 9.0:
			say(lines.pick_random())
			_talk_t = randf_range(4.5, 7.0)
		_body.play("Idle_Talking" if _bubble_t > 0.0 else "Idle", 0.3)
		return
	_putter(delta)


## Puuhailu pihalla: kävelee seuraavaan puuhapisteeseen ja tekee siinä hetken jotain.
func _putter(delta: float) -> void:
	if yard.size() < 2:
		_body.play("Idle", 0.3)
		return
	if _goal >= 0:
		var to_g := (_route[0] if not _route.is_empty() else yard[_goal]) - global_position
		to_g.y = 0.0
		if to_g.length() < 0.25 and not _route.is_empty():
			_route.remove_at(0)
			return
		if to_g.length() < 0.25:
			_spot = _goal
			_goal = -1
			_chore = chores.pick_random()
			_chore_t = randf_range(5.0, 11.0)
			return
		var step := to_g.normalized() * minf(WALK_SPEED * delta, to_g.length())
		var p := global_position + step
		global_position = Vector3(p.x, Terrain.h(p.x, p.z), p.z)
		rotation.y = lerp_angle(rotation.y, B.yaw_to(to_g), 1.0 - exp(-6.0 * delta))
		_body.play("Walk", 0.3)
		return
	if faces.size() == yard.size():
		var to_f := faces[_spot] - global_position
		to_f.y = 0.0
		if to_f.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, B.yaw_to(to_f), 1.0 - exp(-5.0 * delta))
	_body.play(_chore, 0.4)
	_chore_t -= delta
	if _chore_t <= 0.0:
		var nxt := randi() % (yard.size() - 1)
		_goal = nxt if nxt < _spot else nxt + 1  # eri piste kuin nykyinen
		_route = _plan(global_position, yard[_goal])


## Lyhin reitti esteiden ohi: näkyvyysverkko esteiden (laajennettujen) kulmien kautta, Dijkstra.
func _plan(from: Vector3, to: Vector3) -> Array[Vector3]:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var out: Array[Vector3] = []
	if not _blocked(a, b):
		return out
	var nodes: Array[Vector2] = [a, b]
	for o in obstacles:
		var h: Vector2 = o[1] + Vector2(CLEAR + 0.15, CLEAR + 0.15)
		for c in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
			var w: Vector2 = c.rotated(-o[2]) + o[0]
			if not _inside(w):
				nodes.append(w)
	var dist: Array[float] = []
	var prev: Array[int] = []
	var done: Array[bool] = []
	for i in nodes.size():
		dist.append(INF)
		prev.append(-1)
		done.append(false)
	dist[0] = 0.0
	while true:
		var u := -1
		for i in nodes.size():
			if not done[i] and dist[i] < INF and (u < 0 or dist[i] < dist[u]):
				u = i
		if u < 0 or u == 1:
			break
		done[u] = true
		for v in nodes.size():
			if done[v] or v == u:
				continue
			var nd := dist[u] + nodes[u].distance_to(nodes[v])
			if nd < dist[v] and not _blocked(nodes[u], nodes[v]):
				dist[v] = nd
				prev[v] = u
	if prev[1] < 0:
		return out  # ei reittiä: kävellään suoraan
	var k := prev[1]
	while k > 0:
		out.push_front(Vector3(nodes[k].x, 0.0, nodes[k].y))
		k = prev[k]
	return out


## Leikkaako jana a-b jonkin esteen (laajennettuna CLEAR:llä)?
func _blocked(a: Vector2, b: Vector2) -> bool:
	for o in obstacles:
		var h: Vector2 = o[1] + Vector2(CLEAR, CLEAR)
		var p: Vector2 = (a - o[0]).rotated(o[2])
		var q: Vector2 = (b - o[0]).rotated(o[2])
		var d := q - p
		var t0 := 0.0
		var t1 := 1.0
		var hit := true
		for ax in 2:
			if absf(d[ax]) < 1e-6:
				if absf(p[ax]) > h[ax]:
					hit = false
					break
				continue
			var ta := (-h[ax] - p[ax]) / d[ax]
			var tb := (h[ax] - p[ax]) / d[ax]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				hit = false
				break
		if hit:
			return true
	return false


func _inside(w: Vector2) -> bool:
	for o in obstacles:
		var p: Vector2 = (w - o[0]).rotated(o[2])
		var h: Vector2 = o[1] + Vector2(CLEAR, CLEAR)
		if absf(p.x) < h.x and absf(p.y) < h.y:
			return true
	return false


func say(text: String) -> void:
	_bubble.text = "%s: %s" % [display_name.trim_prefix("Naapurin "), text] if text != "" else ""
	_bubble_t = 3.0
	Sfx.babble(self, voice, text)


func distance_to_player() -> float:
	if target == null or not visible:
		return INF  # yöllä sisällä (main.gd _day_rhythm)
	var d := target.global_position - global_position
	return Vector2(d.x, d.z).length()
