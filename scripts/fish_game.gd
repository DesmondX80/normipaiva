extends Node3D
## Kalastus soutuveneellä Likasella: laiturista vesille, soudetaan (W/S airot, A/D käännös) kalaparvien
## kohdalle (renkaat ja kuplat pinnalla), heitetään virveli (pidä E: heiton pituus, päästä: heitto), odotetaan
## nykäisyä (koho sukeltaa: E heti, muuten kala vie syötin) ja väsytetään kala: pidä E kelataksesi. Siiman
## kireys pidetään vihreällä: liian kireä katkeaa, liian löysä ja kala karkaa. Isot kalat (hauki) rimpuilevat
## rajummin ja ovat useammin kaukana rannasta ja parvien luona. F soutaa takaisin laiturille ja lopettaa.
## Humala tärisyttää kelauskättä ja veneen ohjausta.
## mokki.gd:n lapsi identiteettimuunnoksella: koordinaatit ovat mökin paikallisia (Mokki.h(), vesi Mokki.water_level()).
## finished(catch): [{"nom", "name", "kg"}, ...]

signal finished(catch: Array)

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Mokki := preload("res://scripts/mokki.gd")

const MAX_SPEED := 2.4
const ROW_ACCEL := 1.8
const DRAG := 0.45
const TURN := 0.9
const CAST_MIN := 4.0
const CAST_MAX := 17.0
## Lajit (Mokki.FISH:n nimet) ja voima: rimpuilun rajuus ja väsytyksen pituus.
const POWER := {"särki": 0.25, "ahven": 0.4, "lahna": 0.6, "made": 0.65, "hauki": 1.0}
const JUNK_CHANCE := 0.08

var drunk := 0.0
var catch: Array = []

var _wl := 0.0             # vedenpinta (mökin paikallinen y)
var _lake := -1
var _pos := Vector3.ZERO   # veneen paikka vedessä (y = pinta)
var _yaw := 0.0            # veneen keula -Z:n suuntaan kiertokulmalla
var _speed := 0.0
var _turn_v := 0.0
var _row_t := 0.0
var _state := "row"        # row | charge | wait | bite | reel | end
var _charge := 0.0
var _t := 0.0
var _bite_at := 0.0
var _fish := {}
var _dist := 0.0           # kalan etäisyys veneestä väsytyksessä
var _tension := 0.3
var _slack_t := 0.0
var _surge := 0.0
var _surge_t := 0.0
var _end_t := 0.0
var _shoals: Array[Vector3] = []
var _shoal_nodes: Array[Node3D] = []
var _bob := Vector3.ZERO
var _bob_v := Vector3.ZERO
var _msg_t := 0.0

var _boat: Node3D
var _oars: Array[Node3D] = []
var _rower: Node3D
var _rod: Node3D
var _bobber: Node3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _cam: Camera3D
var _ui: CanvasLayer
var _hint: Control  # näppäinohjeet hattuina (hint_bar.gd)
var _msg: Label
var _bag_label: Label
var _bar_bg: ColorRect
var _bar: ColorRect
var _green: ColorRect
var _needle: ColorRect
var _power: ColorRect
var _dist_label: Label


## Laiturin pää ja suunta järvelle (oletus Likasen laituri; Keskimmäisellä mokki.north_dock).
var dock := Mokki.DOCK_LOCAL
var dock_dir := Vector2(0, 1)


func _ready() -> void:
	_lake = Mokki.water_at(dock.x + dock_dir.x * 2.0, dock.z + dock_dir.y * 2.0)
	_wl = Mokki.water_level(_lake) if _lake >= 0 else Mokki.water_y()
	var sd := dock_dir.orthogonal()
	_pos = Vector3(dock.x + sd.x * 1.8 + dock_dir.x, _wl, dock.z + sd.y * 1.8 + dock_dir.y)
	_yaw = atan2(-dock_dir.x, -dock_dir.y)  # keula järvelle
	_boat = Node3D.new()
	add_child(_boat)
	_oars = build_boat(_boat)
	_rower = Looks.make(_boat, Looks.PLAYER)
	Looks.add_cap(_rower)
	_rower.play("Sitting_Idle", 0.0)
	_rower.position = Vector3(0, 0.05, 0.25)
	_rower.rotation.y = 0.0  # kasvot keulaan päin, jotta pelaaja näkee soutajan selän ja menosuunnan
	_rod = Node3D.new()
	_boat.add_child(_rod)
	B.mesh(_rod, B.cyl(0.012, 0.025, 2.6, 6), Vector3(0, 1.3, 0), Color(0.12, 0.12, 0.14))
	B.mesh(_rod, B.cyl(0.05, 0.05, 0.08, 10), Vector3(0.05, 0.35, 0), Color(0.7, 0.7, 0.72), Vector3(0, 0, 90))
	_rod.position = Vector3(0.5, 0.75, 0.6)
	_rod.rotation = Vector3(-0.9, 0, -0.5)  # kärki keulaan (-Z), heiton suuntaan
	_rod.visible = false
	_bobber = Node3D.new()
	add_child(_bobber)
	B.mesh(_bobber, B.sphere(0.07, 8), Vector3(0, 0.03, 0), Color(0.95, 0.15, 0.1))
	B.mesh(_bobber, B.sphere(0.05, 8), Vector3(0, 0.1, 0), Color(0.95, 0.95, 0.95))
	B.mesh(_bobber, B.cyl(0.008, 0.008, 0.12, 4), Vector3(0, 0.18, 0), Color(0.95, 0.9, 0.2))
	_bobber.visible = false
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.material_override = B.unshaded(Color(0.9, 0.9, 0.85, 0.8))
	add_child(_line)
	_cam = Camera3D.new()
	_cam.fov = 65.0
	_cam.far = 1500.0
	add_child(_cam)
	_cam.current = true
	_spawn_shoals()
	_build_ui()
	_say("Soutuvene Likasella. %s/%s airot, %s/%s käännös. Soutele kalaparven kohdalle (renkaat pinnalla)." % [
		Settings.action_key("forward"), Settings.action_key("back"), Settings.action_key("left"), Settings.action_key("right")], 4.5)


## Puinen soutuvene: pohja, laidat, keulan ja perän kaventuvat laudat, tuhdot, hankaimet ja airot.
## Palauttaa airojen kääntöpisteet [vasen, oikea]. Keula -Z:ssa, vesiraja y = 0. folded = airot veneen sisällä.
static func build_boat(parent: Node3D, folded := false) -> Array[Node3D]:
	var hull := Color(0.32, 0.4, 0.3)   # vihreäksi maalattu ulkopinta
	var wood := Color(0.62, 0.45, 0.26)
	var dark := Color(0.2, 0.15, 0.1)
	B.mesh(parent, B.boxm(Vector3(1.0, 0.08, 2.8)), Vector3(0, -0.12, 0.1), hull)
	for s: float in [-1.0, 1.0]:
		B.mesh(parent, B.boxm(Vector3(0.06, 0.42, 2.9)), Vector3(s * 0.58, 0.08, 0.1), hull, Vector3(0, 0, -s * 12.0))
		B.mesh(parent, B.boxm(Vector3(0.07, 0.05, 2.9)), Vector3(s * 0.63, 0.3, 0.1), wood)  # reunalista
		# Keulan kaventuva osa.
		B.mesh(parent, B.boxm(Vector3(0.06, 0.42, 1.05)), Vector3(s * 0.33, 0.1, -1.72), hull, Vector3(0, s * 26.0, -s * 12.0))
		B.mesh(parent, B.boxm(Vector3(0.07, 0.05, 1.05)), Vector3(s * 0.36, 0.32, -1.72), wood, Vector3(0, s * 26.0, 0))
	B.mesh(parent, B.boxm(Vector3(0.12, 0.5, 0.12)), Vector3(0, 0.12, -2.2), wood)  # keulapuu
	B.mesh(parent, B.boxm(Vector3(1.12, 0.42, 0.06)), Vector3(0, 0.1, 1.55), hull)  # peräpeili
	B.mesh(parent, B.boxm(Vector3(0.7, 0.06, 1.2)), Vector3(0, -0.07, -1.5), hull)
	for z in [-0.3, 0.9, -1.3]:
		B.mesh(parent, B.boxm(Vector3(1.1, 0.05, 0.3)), Vector3(0, 0.14, z), wood)  # tuhdot
	for i in 5:
		B.mesh(parent, B.boxm(Vector3(0.9, 0.02, 0.12)), Vector3(0, -0.07, -0.9 + i * 0.5), dark)  # pohjarimat
	var oars: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		B.mesh(parent, B.cyl(0.02, 0.02, 0.12, 6), Vector3(s * 0.64, 0.38, -0.3), Color(0.6, 0.6, 0.62))  # hankain
		var pivot := Node3D.new()
		pivot.position = Vector3(s * 0.64, 0.42, -0.3)
		parent.add_child(pivot)
		var oar := Node3D.new()
		oar.rotation = Vector3(0, 0, s * 0.35)
		pivot.add_child(oar)
		B.mesh(oar, B.cyl(0.025, 0.025, 2.6, 6), Vector3(s * 0.6, 0, 0), wood, Vector3(0, 0, 90))
		B.mesh(oar, B.boxm(Vector3(0.5, 0.02, 0.16)), Vector3(s * 1.75, 0, 0), wood)  # lapa
		if folded:
			pivot.rotation.y = -s * PI / 2.0
			oar.rotation = Vector3.ZERO
			pivot.position.y = 0.3
		oars.append(pivot)
	return oars


func _spawn_shoals() -> void:
	var tries := 0
	while _shoals.size() < 5 and tries < 400:
		tries += 1
		var p := _pos + Vector3(randf_range(-70, 70), 0, randf_range(0, 110))
		if Mokki.water_at(p.x, p.z) != _lake or _shore_dist(p) < 8.0:
			continue
		p.y = _wl
		_shoals.append(p)
		var n := Node3D.new()
		n.position = p
		add_child(n)
		for r in 3:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.9 + r * 0.9
			tm.outer_radius = 1.0 + r * 0.9
			tm.rings = 24
			tm.ring_segments = 4
			ring.mesh = tm
			ring.scale = Vector3(1, 0.05, 1)
			ring.material_override = B.unshaded(Color(0.85, 0.92, 0.95, 0.35))
			ring.position.y = 0.02
			n.add_child(ring)
		_shoal_nodes.append(n)


## Etäisyys rantaan (karkea: säteittäinen haku 8 suuntaan).
func _shore_dist(p: Vector3) -> float:
	for r in [2.0, 4.0, 8.0, 14.0, 20.0, 30.0]:
		for k in 8:
			var a := k * TAU / 8.0
			if Mokki.water_at(p.x + cos(a) * r, p.z + sin(a) * r) != _lake:
				return r
	return 40.0


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 15
	add_child(_ui)
	_hint = preload("res://scripts/hint_bar.gd").new()  # näppäinohjeet hattuina, näppäimet asetuksista
	_hint.compact = true
	_hint.centered = true
	_ui.add_child(_hint)
	_msg = _mk_label(Vector2(0, 90), 32, HORIZONTAL_ALIGNMENT_CENTER)
	_bag_label = _mk_label(Vector2(20, 14), 24, HORIZONTAL_ALIGNMENT_LEFT)
	_dist_label = _mk_label(Vector2(0, 470), 24, HORIZONTAL_ALIGNMENT_CENTER)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0, 0, 0, 0.6)
	_bar_bg.position = Vector2(390, 510)
	_bar_bg.size = Vector2(500, 36)
	_ui.add_child(_bar_bg)
	_green = ColorRect.new()
	_green.color = Color(0.2, 0.7, 0.3, 0.8)
	_green.position = Vector2(390 + 500 * 0.35, 510)
	_green.size = Vector2(500 * 0.45, 36)
	_ui.add_child(_green)
	_bar = ColorRect.new()
	_bar.color = Color(0.9, 0.2, 0.15, 0.8)
	_bar.position = Vector2(390 + 500 * 0.9, 510)
	_bar.size = Vector2(50, 36)
	_ui.add_child(_bar)
	_needle = ColorRect.new()
	_needle.color = Color(1, 1, 1)
	_needle.size = Vector2(6, 48)
	_ui.add_child(_needle)
	_power = ColorRect.new()
	_power.color = Color(1.0, 0.8, 0.2)
	_power.position = Vector2(390, 560)
	_power.size = Vector2(0, 14)
	_ui.add_child(_power)
	_show_bar(false)


func _mk_label(pos: Vector2, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(1280 if align == HORIZONTAL_ALIGNMENT_CENTER else 800, 60)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	_ui.add_child(l)
	return l


func _show_bar(on: bool) -> void:
	for c in [_bar_bg, _green, _bar, _needle]:
		c.visible = on


func _say(text: String, t := 2.5) -> void:
	_msg.text = text
	_msg_t = t


func _process(delta: float) -> void:
	_t += delta
	_msg_t -= delta
	if _msg_t <= 0.0:
		_msg.text = ""
	for n in _shoal_nodes:
		for i in n.get_child_count():
			var r := n.get_child(i) as Node3D
			var k := fmod(_t * 0.4 + i / 3.0, 1.0)
			r.scale = Vector3(0.5 + k, 0.05, 0.5 + k)
	_row(delta)
	match _state:
		"row":
			_hint.set_text("%s soutu   %s käännös   %s heitä virveli (pidä pohjassa)   %s takaisin laiturille" % [
				Settings.pair("forward", "back"), Settings.pair("left", "right"), Settings.cap("interact"), Settings.cap("mount")])
			if Input.is_action_pressed("interact") and absf(_speed) < 0.6:
				_state = "charge"
				_charge = 0.0
				_rod.visible = true
			elif Input.is_action_just_pressed("interact"):
				_say("Pysäytä vene ennen heittoa.", 1.5)
		"charge":
			_charge = minf(_charge + delta * 0.8, 1.0)
			_power.size.x = 500.0 * _charge
			_hint.set_text("%s päästä irti: heitto (%d m)" % [Settings.cap("interact"), roundi(lerpf(CAST_MIN, CAST_MAX, _charge))])
			if not Input.is_action_pressed("interact"):
				_cast()
		"wait":
			_hint.set_text("Odota nykäisyä... (soutaminen kelaa siiman sisään)")
			_bobber.position = _bob + Vector3(0, sin(_t * 2.0) * 0.02, 0)
			if absf(_speed) > 0.8:
				_reel_in("Kelasit siiman sisään.")
			elif _t >= _bite_at:
				_state = "bite"
				_bite_at = _t + lerpf(0.9, 0.6, drunk)
				Sfx.play("water", -2.0, 1.6)
				_say("NYKÄISY! %s nyt!" % Settings.action_key("interact"), 1.0)
			elif fmod(_t, 3.0) < delta and randf() < 0.35:
				_bobber.position.y -= 0.05  # pikku nypläys
		"bite":
			_bobber.position = _bob + Vector3(0, -0.12 + sin(_t * 30.0) * 0.04, 0)
			_hint.set_text("%s tartu!" % Settings.cap("interact"))
			if Input.is_action_just_pressed("interact"):
				_hook()
			elif _t > _bite_at:
				_reel_in(["Kala vei syötin.", "Liian myöhään. Mato meni.", "Koho pomppasi takaisin tyhjänä."].pick_random())
		"reel":
			_reel(delta)
		"end":
			_end_t -= delta
			if _end_t <= 0.0:
				finished.emit(catch)
				queue_free()
				return
	if _state in ["row", "wait"] and Input.is_action_just_pressed("mount"):
		_state = "end"
		_end_t = 1.2
		_rod.visible = false
		_bobber.visible = false
		_say("Soudat takaisin laiturille." if not catch.is_empty() else "Soudat tyhjin käsin laiturille.", 1.5)
	_update_line()
	var names := []
	for c in catch:
		names.append("%s %s kg" % [c.nom, ("%.1f" % c.kg).replace(".", ",")])
	_bag_label.text = "Saalis: " + (", ".join(names) if not names.is_empty() else "–")
	if _state != "charge":
		_power.size.x = 0.0


## Soutu: W/S airoilla, A/D kääntää (toinen airo vetää). Ranta pysäyttää. Kamera veneen takaa.
func _row(delta: float) -> void:
	var fwd_in := 0.0
	var turn_in := 0.0
	if _state in ["row", "wait"]:
		fwd_in = Input.get_axis("back", "forward")
		turn_in = Input.get_axis("right", "left")
	var wob := sin(_t * 0.8) * 0.35 * drunk
	_speed = move_toward(_speed, fwd_in * MAX_SPEED, (ROW_ACCEL if absf(fwd_in) > 0.1 else DRAG) * delta)
	_turn_v = lerpf(_turn_v, (turn_in + wob) * TURN, 1.0 - exp(-3.0 * delta))
	_yaw += _turn_v * delta
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var next := _pos + fwd * _speed * delta
	if Mokki.water_at(next.x, next.z) != _lake or Mokki.water_at(next.x + fwd.x * 1.8, next.z + fwd.z * 1.8) != _lake:
		if absf(_speed) > 1.0:
			Sfx.play("body_fall", -10.0, 1.4)
			_say("Kolahti rantaan.", 1.2)
		_speed = -_speed * 0.3
	else:
		_pos = next
	var rowing := absf(fwd_in) > 0.1 or absf(turn_in) > 0.1
	if rowing:
		_row_t += delta * 2.4
	for i in _oars.size():
		var s := -1.0 if i == 0 else 1.0
		var pull := sin(_row_t * TAU / 2.4)
		var active := rowing and (absf(turn_in) < 0.1 or (turn_in > 0.0) == (s > 0.0) or absf(fwd_in) > 0.1)
		_oars[i].rotation.y = s * (pull * 0.5 if active else 0.1)
		_oars[i].rotation.z = s * (0.12 * maxf(pull, 0.0) if active else 0.0)
	if rowing and fmod(_row_t, 2.4) < delta * 2.4:
		Sfx.play("water", -12.0, randf_range(1.2, 1.5))
	_boat.position = _pos + Vector3(0, 0.12 + sin(_t * 1.3) * 0.03, 0)
	_boat.rotation = Vector3(sin(_t * 0.9) * 0.02, _yaw, sin(_t * 1.1) * 0.03 + _turn_v * 0.04)
	# Soutajan kädet airojen kahvoille.
	var inv := _rower.transform.affine_inverse()
	for side in [["_l", -1.0, 0], ["_r", 1.0, 1]]:
		var pv: Node3D = _oars[side[2]]
		var grip := pv.position + Vector3(-side[1] * 0.5, -0.1, 0).rotated(Vector3.UP, pv.rotation.y)
		if _state in ["charge", "wait", "bite", "reel"]:
			grip = Vector3(0.35 * side[1], 0.75, 0.6)
		_rower.set_ik("arm" + side[0], "upperarm" + side[0], "lowerarm" + side[0], "hand" + side[0],
			inv * grip, inv * Vector3(0.6 * side[1], 0.6, 0.2))
	var back := -fwd
	var cam_to := _pos + fwd * 3.0 + Vector3(0, 0.6, 0)
	var want := _pos + back * 6.5 + Vector3(0, 3.4, 0)
	if _state in ["wait", "bite", "reel"]:
		cam_to = (_pos + _bob) / 2.0
		want = _pos - (_bob - _pos).normalized() * 5.0 + Vector3(0, 3.0, 0)
	_cam.position = _cam.position.lerp(want, 1.0 - exp(-3.0 * delta)) if _t > 0.1 else want
	_cam.look_at(to_global(cam_to), Vector3.UP)


func _cast() -> void:
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var side := fwd.cross(Vector3.UP)
	var d := lerpf(CAST_MIN, CAST_MAX, _charge) * randf_range(0.9, 1.05)
	var dir := (fwd + side * randf_range(-0.25, 0.25) * (1.0 + drunk)).normalized()
	_bob = _pos + dir * d
	if Mokki.water_at(_bob.x, _bob.z) != _lake:
		_say("Heitto meni rantaruovikkoon! Kelaa ja yritä uudestaan.", 2.0)
		_rod.visible = false
		_state = "row"
		return
	_bob.y = _wl
	_bobber.position = _bob
	_bobber.visible = true
	Sfx.play("whoosh", -6.0, 0.8)
	Sfx.play("water", -8.0, 1.8)
	# Kalaparven lähellä nappaa nopeasti, muualla odotellaan.
	var near := 99.0
	for sh in _shoals:
		near = minf(near, Vector2(sh.x - _bob.x, sh.z - _bob.z).length())
	_bite_at = _t + (randf_range(1.5, 4.5) if near < 5.0 else randf_range(7.0, 16.0))
	_state = "wait"
	_fish = _pick_fish(near < 5.0, _shore_dist(_bob))


func _pick_fish(shoal: bool, shore: float) -> Dictionary:
	if randf() < JUNK_CHANCE:
		return {"junk": true, "power": 0.2}
	# Painotus: rannan lähellä pikkukalaa, ulompana ja parvella isompaa (hauki).
	var weights := {"särki": 3.0, "ahven": 3.0, "lahna": 1.0 + shore / 20.0, "made": 0.6 + shore / 30.0,
		"hauki": 0.3 + shore / 15.0 + (1.2 if shoal else 0.0)}
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := randf() * total
	var nom := "särki"
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			nom = k
			break
	for f in Mokki.FISH:
		if f.nom == nom:
			var kg: float = f.kg * randf_range(0.6, 1.7) * (1.25 if shoal else 1.0)
			return {"nom": nom, "name": f.name, "kg": kg, "power": minf(POWER[nom] * clampf(kg / f.kg, 0.7, 1.3), 1.15)}
	return {"junk": true, "power": 0.2}


func _hook() -> void:
	_state = "reel"
	_dist = Vector2(_bob.x - _pos.x, _bob.z - _pos.z).length()
	_tension = 0.5
	_slack_t = 0.0
	_surge_t = 0.8
	_show_bar(true)
	Sfx.play("alert", -6.0, 1.5)
	_say("Tärppi! Pidä %s: kelaa. Kireys vihreällä!" % Settings.action_key("interact"), 2.0)


## Väsytys: E kelaa (kireys nousee, kala lähestyy vihreällä), irti päästäminen löysää. Kala rimpuilee
## satunnaisin syöksyin (vetää siimaa ulos ja kiristää). Katkeaa punaisella, karkaa löysällä.
func _reel(delta: float) -> void:
	var p: float = _fish.power
	var reeling := Input.is_action_pressed("interact")
	_surge_t -= delta
	if _surge_t <= 0.0:
		_surge_t = randf_range(0.6, 2.2) / (0.5 + p)
		_surge = randf_range(0.4, 1.0) * p
		Sfx.play("water", -10.0, randf_range(1.0, 1.4))
	_surge = move_toward(_surge, 0.0, delta * 1.2)
	var shake := (sin(_t * 17.0) * 0.5 + sin(_t * 7.3)) * 0.04 * drunk
	_tension += ((0.55 if reeling else -0.7) + _surge * 0.9 + shake * 10.0) * delta
	_tension = clampf(_tension, 0.0, 1.05)
	var green := _tension >= 0.35 and _tension <= 0.8
	if reeling and green:
		_dist -= (3.6 - p * 1.3) * delta
	_dist += _surge * 0.9 * delta
	_slack_t = _slack_t + delta if _tension < 0.15 else 0.0
	# Koho ja kala lähestyvät venettä.
	var to_boat := Vector3(_pos.x - _bob.x, 0, _pos.z - _bob.z)
	var cur := to_boat.length()
	if cur > 0.01:
		_bob += to_boat / cur * (cur - maxf(_dist, 0.8))
	_bob.y = _wl
	_bobber.position = _bob + Vector3(sin(_t * 9.0) * 0.1 * p, -0.05, cos(_t * 11.0) * 0.1 * p)
	_needle.position = Vector2(390 + 500 * clampf(_tension, 0.0, 1.0) - 3, 504)
	_dist_label.text = "%.1f m" % maxf(_dist, 0.0)
	_hint.set_text("%s kelaa (pidä pohjassa, päästä: löysää) – pidä neula vihreällä" % Settings.cap("interact"))
	if _tension >= 1.0:
		Sfx.play("rattle", -4.0, 1.4)
		_end_reel("PAM! Siima katkesi. " + ("Se oli iso..." if p > 0.7 else "Liian kireällä."))
	elif _slack_t > 1.6:
		_end_reel("Siima löystyi ja kala karkasi.")
	elif _dist <= 0.9:
		_land()


func _land() -> void:
	if _fish.get("junk", false):
		Sfx.play("rattle", -4.0, 0.9)
		_end_reel("Vedit ylös %s. Ei syötävää." % Mokki.FISH_JUNK.pick_random())
		return
	Sfx.play("win_small", -4.0)
	catch.append({"nom": _fish.nom, "name": _fish.name, "kg": _fish.kg})
	var big := " Komea!" if _fish.nom == "hauki" or _fish.kg > 1.5 else ""
	_end_reel("Sait %s! %s kg.%s" % [_fish.name, ("%.1f" % _fish.kg).replace(".", ","), big])


func _end_reel(text: String) -> void:
	_say(text, 2.8)
	_reel_in("")


func _reel_in(text: String) -> void:
	if text != "":
		_say(text, 2.0)
	_state = "row"
	_bobber.visible = false
	_rod.visible = false
	_show_bar(false)
	_dist_label.text = ""


## Siima vavan kärjestä kohoon (taipuu keskeltä alas).
func _update_line() -> void:
	_line_mesh.clear_surfaces()
	if not _bobber.visible or not _rod.visible:
		return
	var tip := _rod.to_global(Vector3(0, 2.6, 0))
	tip = to_local(tip)
	var end := _bobber.position + Vector3(0, 0.2, 0)
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var sag := 0.6 if _state != "reel" else 0.1 + (1.0 - _tension) * 0.3
	var prev := tip
	for i in range(1, 11):
		var t := i / 10.0
		var q := tip.lerp(end, t) - Vector3(0, sin(t * PI) * sag, 0)
		_line_mesh.surface_add_vertex(prev)
		_line_mesh.surface_add_vertex(q)
		prev = q
	_line_mesh.surface_end()
