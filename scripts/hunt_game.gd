extends Node3D
## Metsästys mökin metsässä, FPS-minipeli: istutaan riistapolun metsästyslavalla haulikon kanssa ja tähdätään
## hiirellä aukealle tulevaa riistaa (jänis, riekko, metso, lentävä kyyhky). Vasen nappi / E ampuu, oikea nappi
## tähtää tarkemmin (zoom). Kaksi piippua, sitten lataus. Laukaus säikäyttää lähellä olevat eläimet pakoon.
## Hirveen ei ole lupaa: sen ampuminen lopettaa jahdin nolosti. F lopettaa.
## mokki.gd:n lapsi identiteettimuunnoksella: kaikki koordinaatit ovat mökin paikallisia (maasto Mokki.h()).
## finished(bag, moose): bag = saaliiden lajiavaimet (SPECIES), moose = ammuttiinko hirvi.

signal finished(bag: Array, moose: bool)

const B := preload("res://scripts/build.gd")
const Mokki := preload("res://scripts/mokki.gd")

const SENS := 0.0028
const TIME := 90.0
const SHELLS := 8
const RELOAD := 1.6
const SPREAD := 0.018  # haulikuvion säde / etäisyys
const MAX_RANGE := 45.0
## Eläimet ovat pelin vuoksi reilusti luonnollista kokoaan isompia, jotta ne erottuvat metsästä.
const SIZE := 1.5
## Aukea metsästyslavan edessä (lännessä); mokki.gd jättää sen ja näkölinjan puuttomaksi.
const GLADE := Mokki.HUNT_GLADE
const GLADE_R := Mokki.HUNT_GLADE_R
## Lajit: nimi, partitiivi, osumasäde, keskipisteen korkeus, kävely- ja pakonopeus, arvontapaino.
const SPECIES := {
	"janis": {"nom": "jänis", "part": "jäniksen", "r": 0.28, "cy": 0.25, "speed": 1.6, "flee": 6.5, "w": 3},
	"riekko": {"nom": "riekko", "part": "riekon", "r": 0.2, "cy": 0.2, "speed": 0.7, "flee": 5.0, "takeoff": true, "w": 3},
	"metso": {"nom": "metso", "part": "metson", "r": 0.36, "cy": 0.45, "speed": 0.6, "flee": 5.5, "takeoff": true, "w": 2},
	"kyyhky": {"nom": "kyyhky", "part": "kyyhkyn", "r": 0.24, "cy": 0.0, "speed": 7.5, "flee": 9.0, "air": true, "w": 2},
	"hirvi": {"nom": "hirvi", "part": "hirven", "r": 0.9, "cy": 1.45, "speed": 1.1, "flee": 4.0, "forbidden": true, "w": 0},
}
const HIT_LINES := ["Osui!", "Nappiin!", "Siinä se.", "Pekka ois ylpeä.", "Neljätoista kyyhkyä, sano Pekka. No, tässä yks."]
const MISS_LINES := ["Ohi.", "Hauleja metsään.", "Karkas.", "Liian kaukana.", "Vain oksat putosi."]

var bag: Array = []
var _moose := false
var _eye := Vector3.ZERO
var _yaw := 0.0  # 0 = +Z
var _yaw_center := 0.0
var _pitch := -0.05
var _t := 0.0
var _time := TIME
var _shells := SHELLS
var _loaded := 2
var _reload_t := 0.0
var _shake := 0.0
var _recoil := 0.0
var _zoom := 0.0
var _animals: Array = []
var _spawn_t := 1.2
var _moose_spawned := false
var _phase := "hunt"  # hunt | end
var _end_t := 0.0
var _saved_cam := []

var _cam: Camera3D
var _gun: Node3D
var _flash: Node3D
var _ambience: AudioStreamPlayer3D
var _layer: CanvasLayer
var _task: Label
var _ammo: Label
var _clock: Label
var _bag_label: Label
var _sub: Label
var _sub_t := 0.0


func _ready() -> void:
	var hx := Mokki.HUNT_LOCAL.x
	var hz := Mokki.HUNT_LOCAL.z
	_eye = Vector3(hx, Mokki.h(hx, hz) + 1.1 + 1.25, hz)
	_yaw_center = atan2(GLADE.x - hx, GLADE.y - hz)
	_yaw = _yaw_center
	_cam = Camera3D.new()
	_cam.near = 0.05
	add_child(_cam)
	_cam.current = true
	_build_gun()
	_build_hud()
	_ambience = Sfx.loop_on(self, "amb_birds", -12.0)
	if _ambience != null:
		_ambience.position = _eye
	_saved_cam = [CamCtl.yaw, CamCtl.pitch]
	CamCtl.need_mouse = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_say("Istut metsästyslavalla. Aukealla liikkuu jotain...", 3.0)
	_update_camera(0.0)


func _exit_tree() -> void:
	CamCtl.need_mouse = false


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or _phase != "hunt":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = SENS * Settings.get_v("mouse_sens") * lerpf(1.0, 0.45, _zoom)
		var inv := -1.0 if Settings.get_v("invert_y") else 1.0
		_yaw = clampf(_yaw - event.relative.x * sens, _yaw_center - 1.1, _yaw_center + 1.1)
		_pitch = clampf(_pitch - event.relative.y * inv * sens, -0.6, 0.9)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_shoot()


func _process(delta: float) -> void:
	_t += delta
	if _phase == "hunt":
		_time -= delta
		if Input.is_action_just_pressed("mount"):
			_finish("Lopetit jahdin.")
		elif Input.is_action_just_pressed("interact"):
			_shoot()
		elif _time <= 0.0:
			_finish("Hämärtää. Jahti päättyi.")
		elif _shells <= 0 and _loaded <= 0:
			_finish("Patruunat loppuivat.")
	else:
		_end_t += delta
		if _end_t > 2.8:
			_quit()
			return
	var aiming := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _phase == "hunt"
	_zoom = move_toward(_zoom, 1.0 if aiming else 0.0, delta * 5.0)
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			_loaded = mini(2, _shells)
			_shells -= _loaded
			Sfx.play("rattle", -8.0, 1.3)
	_spawn(delta)
	_update_animals(delta)
	_update_camera(delta)
	_update_hud(delta)


# --- Ammunta ------------------------------------------------------------------------

func _shoot() -> void:
	if _phase != "hunt" or _reload_t > 0.0:
		return
	if _loaded <= 0:
		if _shells > 0:
			_reload_t = RELOAD
		else:
			Sfx.play("rattle", -8.0, 1.8)
		return
	_loaded -= 1
	if _loaded == 0 and _shells > 0:
		_reload_t = RELOAD
	Sfx.play("shotgun", -2.0, randf_range(0.95, 1.05))
	_shake = 1.0
	_recoil = 1.0
	_flash.visible = true
	get_tree().create_timer(0.06).timeout.connect(func() -> void:
		if is_instance_valid(_flash):
			_flash.visible = false)
	var o := _cam.global_position
	var fwd := -_cam.global_transform.basis.z
	var best: Dictionary = {}
	var best_d := INF
	for a in _animals:
		if a.state == "dead":
			continue
		var sp: Dictionary = SPECIES[a.kind]
		var c: Vector3 = to_global(a.pos + Vector3(0, sp.cy * SIZE, 0))
		var v := c - o
		var along := v.dot(fwd)
		if along <= 0.0 or along > MAX_RANGE:
			continue
		var perp := (v - fwd * along).length()
		if perp < sp.r * SIZE + SPREAD * along * 0.6 and along < best_d:
			best = a
			best_d = along
	if not best.is_empty():
		# Pitkältä matkalta haulikko vain haavoittaa: eläin pakenee.
		if best_d > 30.0 and randf() < 0.5:
			_say("Liian kaukana, %s pakeni." % SPECIES[best.kind].nom, 2.0)
		else:
			_kill(best)
	else:
		_say(MISS_LINES.pick_random(), 1.5)
	# Laukaus säikäyttää lähistön eläimet.
	for a in _animals:
		if a.state in ["walk", "pause"] and a.pos.distance_to(_eye) < 38.0:
			_scare(a)


func _kill(a: Dictionary) -> void:
	var sp: Dictionary = SPECIES[a.kind]
	a.state = "dead"
	a.t = 0.0
	if sp.get("forbidden", false):
		_moose = true
		Sfx.play("lose", -4.0)
		_finish("HIRVI!? Ei meillä oo hirvilupaa! Santtu ei tykkää tästä yhtään.")
		return
	bag.append(a.kind)
	Sfx.play("win_small", -8.0)
	_say("%s – %s" % [sp.nom.capitalize(), HIT_LINES.pick_random()], 2.2)


func _scare(a: Dictionary) -> void:
	var sp: Dictionary = SPECIES[a.kind]
	var away: Vector3 = a.pos - _eye
	away.y = 0.0
	a.dir = (away.normalized() + a.dir * 0.5).normalized()
	a.speed = sp.flee
	a.state = "fly" if sp.get("takeoff", false) else "flee"
	a.vy = 3.5 if a.state == "fly" else 0.0


# --- Eläimet ------------------------------------------------------------------------

func _spawn(delta: float) -> void:
	if _phase != "hunt":
		return
	_spawn_t -= delta
	var alive := _animals.filter(func(a): return a.state != "dead").size()
	if _spawn_t > 0.0 or alive >= 3:
		return
	_spawn_t = randf_range(2.5, 5.5)
	var kind := _pick_kind()
	var sp: Dictionary = SPECIES[kind]
	var side := 1.0 if randf() < 0.5 else -1.0
	var start := GLADE + Vector2(randf_range(-8.0, 4.0), side * (GLADE_R + 3.0))
	var end := GLADE + Vector2(randf_range(-8.0, 4.0), -side * (GLADE_R + 3.0))
	var pos := Vector3(start.x, Mokki.h(start.x, start.y), start.y)
	if sp.get("air", false):
		start = GLADE + Vector2(randf_range(-6.0, 8.0), side * 32.0)
		end = GLADE + Vector2(randf_range(-6.0, 8.0), -side * 32.0)
		pos = Vector3(start.x, _eye.y + randf_range(5.0, 9.0), start.y)
	var dir := Vector3(end.x - start.x, 0, end.y - start.y).normalized()
	var node := _model(kind)
	node.scale = Vector3.ONE * SIZE
	add_child(node)
	_animals.append({"kind": kind, "node": node, "pos": pos, "dir": dir, "speed": sp.speed, "state": "walk",
		"t": randf() * 5.0, "pause_t": randf_range(2.0, 5.0), "vy": 0.0})


func _pick_kind() -> String:
	if not _moose_spawned and _t > 20.0 and randf() < 0.12:
		_moose_spawned = true
		return "hirvi"
	var total := 0
	for k in SPECIES:
		total += SPECIES[k].w
	var r := randi() % total
	for k in SPECIES:
		r -= SPECIES[k].w
		if r < 0:
			return k
	return "janis"


func _update_animals(delta: float) -> void:
	for a in _animals.duplicate():
		var sp: Dictionary = SPECIES[a.kind]
		var node: Node3D = a.node
		a.t += delta
		match a.state:
			"walk", "flee":
				if sp.get("air", false):
					a.pos += a.dir * a.speed * delta
				else:
					a.pos += a.dir * a.speed * delta
					a.pos.y = Mokki.h(a.pos.x, a.pos.z)
					# Välillä pysähdytään syömään (paitsi paossa).
					if a.state == "walk" and a.kind != "hirvi":
						a.pause_t -= delta
						if a.pause_t <= 0.0:
							a.state = "pause"
							a.pause_t = randf_range(1.0, 2.5)
			"pause":
				a.pos.y = Mokki.h(a.pos.x, a.pos.z)
				a.pause_t -= delta
				if a.pause_t <= 0.0:
					a.state = "walk"
					a.pause_t = randf_range(2.0, 5.0)
			"fly":
				a.vy = move_toward(a.vy, 1.2, delta * 2.0)
				a.pos += a.dir * a.speed * delta + Vector3(0, a.vy * delta, 0)
			"dead":
				var ground := Mokki.h(a.pos.x, a.pos.z)
				if a.pos.y > ground:
					a.vy -= 12.0 * delta
					a.pos.y = maxf(ground, a.pos.y + a.vy * delta)
				node.rotation.z = move_toward(node.rotation.z, PI / 2.0, delta * 6.0)
		node.position = a.pos
		if a.state != "dead":
			node.rotation.y = atan2(a.dir.x, a.dir.z)
			var hop := 0.0
			if a.kind == "janis" and a.state in ["walk", "flee"]:
				hop = absf(sin(a.t * (7.0 if a.state == "walk" else 12.0))) * (0.12 if a.state == "walk" else 0.3)
			var body: Node3D = node.get_node("Body")
			body.position.y = hop
			if a.state == "pause":
				body.rotation.x = 0.25 + 0.05 * sin(a.t * 6.0)  # nokka maassa
			else:
				body.rotation.x = 0.0
			for w in ["WingL", "WingR"]:
				var wing: Node3D = body.get_node_or_null(w)
				if wing != null:
					var flap := sin(a.t * 18.0) * 0.9 if (sp.get("air", false) or a.state == "fly") else 0.0
					wing.rotation.z = flap * (1.0 if w == "WingL" else -1.0)
		# Kaukana tai korkealla olevat poistuvat.
		var d2 := Vector2(a.pos.x - GLADE.x, a.pos.z - GLADE.y).length()
		if a.state != "dead" and (d2 > 40.0 or a.pos.y > _eye.y + 25.0):
			node.queue_free()
			_animals.erase(a)


## Yksinkertaiset primitiivimallit, katse +Z. "Body"-lapsi hyppii ja nokkii, siivet "WingL"/"WingR".
func _model(kind: String) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	match kind:
		"janis":
			var fur := Color(0.55, 0.47, 0.38)
			B.mesh(body, B.sphere(0.2, 10), Vector3(0, 0.22, 0), fur).scale = Vector3(0.8, 0.85, 1.35)
			B.mesh(body, B.sphere(0.1, 10), Vector3(0, 0.36, 0.26), fur)
			for s in [-1.0, 1.0]:
				B.mesh(body, B.boxm(Vector3(0.04, 0.2, 0.02)), Vector3(s * 0.04, 0.52, 0.22), fur.darkened(0.1), Vector3(-20, 0, s * 8))
			B.mesh(body, B.sphere(0.05, 8), Vector3(0, 0.25, -0.27), Color(0.95, 0.95, 0.92))
		"riekko":
			var col := Color(0.6, 0.48, 0.34)
			B.mesh(body, B.sphere(0.15, 10), Vector3(0, 0.18, 0), col).scale = Vector3(0.9, 0.85, 1.2)
			B.mesh(body, B.sphere(0.07, 8), Vector3(0, 0.3, 0.16), col.darkened(0.1))
			B.mesh(body, B.boxm(Vector3(0.05, 0.02, 0.04)), Vector3(0, 0.36, 0.17), Color(0.8, 0.1, 0.1))
			_wings(body, 0.17, 0.2, Color(0.92, 0.9, 0.86))
		"metso":
			var col := Color(0.12, 0.12, 0.13)
			B.mesh(body, B.sphere(0.26, 12), Vector3(0, 0.42, 0), col).scale = Vector3(0.85, 0.9, 1.3)
			B.mesh(body, B.cyl(0.06, 0.08, 0.28, 8), Vector3(0, 0.66, 0.2), col, Vector3(20, 0, 0))
			B.mesh(body, B.sphere(0.09, 8), Vector3(0, 0.8, 0.26), col)
			B.mesh(body, B.boxm(Vector3(0.04, 0.03, 0.07)), Vector3(0, 0.79, 0.36), Color(0.9, 0.88, 0.75))
			B.mesh(body, B.boxm(Vector3(0.1, 0.02, 0.03)), Vector3(0, 0.85, 0.3), Color(0.85, 0.1, 0.1))
			B.mesh(body, B.boxm(Vector3(0.45, 0.4, 0.03)), Vector3(0, 0.62, -0.36), col.lightened(0.05), Vector3(-25, 0, 0))
			_wings(body, 0.45, 0.35, col.lightened(0.1))
		"kyyhky":
			var col := Color(0.55, 0.57, 0.62)
			B.mesh(body, B.sphere(0.12, 10), Vector3.ZERO, col).scale = Vector3(0.9, 0.85, 1.4)
			B.mesh(body, B.sphere(0.065, 8), Vector3(0, 0.05, 0.17), col.darkened(0.15))
			_wings(body, 0.0, 0.32, col.lightened(0.1))
		"hirvi":
			var col := Color(0.3, 0.22, 0.15)
			B.mesh(body, B.capsule(0.45, 2.0), Vector3(0, 1.45, 0), col, Vector3(90, 0, 0))
			for lx in [-0.22, 0.22]:
				for lz in [-0.65, 0.65]:
					B.mesh(body, B.cyl(0.06, 0.05, 1.2, 6), Vector3(lx, 0.6, lz), col.darkened(0.2))
			B.mesh(body, B.cyl(0.14, 0.18, 0.7, 8), Vector3(0, 1.85, 0.95), col, Vector3(45, 0, 0))
			B.mesh(body, B.boxm(Vector3(0.24, 0.3, 0.6)), Vector3(0, 2.05, 1.3), col.darkened(0.1))
			for s in [-1.0, 1.0]:
				B.mesh(body, B.boxm(Vector3(0.55, 0.04, 0.3)), Vector3(s * 0.35, 2.35, 1.15), Color(0.82, 0.76, 0.6), Vector3(0, 0, s * 20))
	return root


func _wings(body: Node3D, y: float, span: float, col: Color) -> void:
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "WingL" if s < 0.0 else "WingR"
		pivot.position = Vector3(s * 0.08, y + 0.02, 0)
		body.add_child(pivot)
		B.mesh(pivot, B.boxm(Vector3(span, 0.02, 0.16)), Vector3(s * span / 2.0, 0, 0), col)


# --- Loppu -----------------------------------------------------------------------------

func _finish(why: String) -> void:
	if _phase != "hunt":
		return
	_phase = "end"
	_end_t = 0.0
	var names := bag.map(func(k): return SPECIES[k].nom)
	_task.text = why
	_say("Saalis: %s" % (", ".join(names) if not names.is_empty() else "ei mitään"), 3.0)


func _quit() -> void:
	CamCtl.yaw = _saved_cam[0]
	CamCtl.pitch = _saved_cam[1]
	set_process(false)
	finished.emit(bag, _moose)
	queue_free()


# --- Kamera, ase ja HUD ------------------------------------------------------------------

func _update_camera(delta: float) -> void:
	# Hengitys ja käsien huojunta, tähdätessä (zoom) rauhallisempi.
	var calm := lerpf(1.0, 0.35, _zoom)
	var sway_y := (0.008 * sin(_t * 1.1) + 0.004 * sin(_t * 2.9 + 1.3)) * calm
	var sway_p := (0.006 * sin(_t * 1.6 + 0.4) + 0.003 * sin(_t * 0.7)) * calm
	_shake = maxf(0.0, _shake - delta * 5.0)
	_recoil = maxf(0.0, _recoil - delta * 4.0)
	var kick := _recoil * _recoil * 0.06
	var yaw := _yaw + sway_y + randf_range(-1, 1) * _shake * 0.006
	var pitch := _pitch + sway_p + kick
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _eye)
	_cam.fov = lerpf(Settings.get_v("fov") * 0.8, 24.0, _zoom)  # haulikon jyvän yli katsotaan vähän kapeammin
	_gun.position = Vector3(lerpf(0.16, 0.0, _zoom), lerpf(-0.2, -0.13, _zoom), -0.45 + _recoil * 0.08)
	_gun.rotation.x = _recoil * 0.12


func _build_gun() -> void:
	_gun = Node3D.new()
	_cam.add_child(_gun)
	var steel := Color(0.12, 0.12, 0.13)
	for s in [-0.018, 0.018]:
		B.mesh(_gun, B.cyl(0.013, 0.013, 0.7, 10), Vector3(s, 0, -0.35), steel, Vector3(90, 0, 0))
	B.mesh(_gun, B.boxm(Vector3(0.06, 0.05, 0.14)), Vector3(0, -0.01, 0.02), steel.lightened(0.1))
	B.mesh(_gun, B.boxm(Vector3(0.05, 0.08, 0.34)), Vector3(0, -0.05, 0.24), Color(0.4, 0.24, 0.12), Vector3(-8, 0, 0))
	B.mesh(_gun, B.boxm(Vector3(0.05, 0.03, 0.3)), Vector3(0, -0.03, -0.2), Color(0.42, 0.26, 0.13))
	B.mesh(_gun, B.sphere(0.006, 6), Vector3(0, 0.017, -0.69), Color(0.9, 0.9, 0.85))  # jyvä
	_flash = Node3D.new()
	_flash.position = Vector3(0, 0, -0.75)
	_flash.visible = false
	_gun.add_child(_flash)
	var fm := MeshInstance3D.new()
	fm.mesh = B.sphere(0.07, 8)
	fm.material_override = B.unshaded(Color(2.0, 1.4, 0.5))
	_flash.add_child(fm)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.7, 0.3)
	fl.light_energy = 4.0
	fl.omni_range = 6.0
	_flash.add_child(fl)


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	for spec in [[Vector2(22, 2), Vector2(-17, 0)], [Vector2(22, 2), Vector2(17, 0)], [Vector2(2, 22), Vector2(0, -17)],
			[Vector2(2, 22), Vector2(0, 17)], [Vector2(3, 3), Vector2.ZERO]]:
		var r := ColorRect.new()
		var sz: Vector2 = spec[0]
		var off: Vector2 = spec[1]
		r.color = Color(1, 0.3, 0.2, 0.9) if off == Vector2.ZERO else Color(1, 1, 1, 0.85)
		r.anchor_left = 0.5
		r.anchor_right = 0.5
		r.anchor_top = 0.5
		r.anchor_bottom = 0.5
		r.offset_left = off.x - sz.x / 2.0
		r.offset_right = off.x + sz.x / 2.0
		r.offset_top = off.y - sz.y / 2.0
		r.offset_bottom = off.y + sz.y / 2.0
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(r)
	_task = _label(26, 0.0, 44, 84, HORIZONTAL_ALIGNMENT_CENTER)
	_task.text = "METSÄSTYS – tähtää hiirellä, ammu vasemmalla napilla (E)"
	_ammo = _label(24, 1.0, -110, -76, HORIZONTAL_ALIGNMENT_LEFT)
	_clock = _label(24, 0.0, 12, 44, HORIZONTAL_ALIGNMENT_RIGHT)
	_bag_label = _label(22, 0.0, 12, 44, HORIZONTAL_ALIGNMENT_LEFT)
	_sub = _label(28, 1.0, -170, -120, HORIZONTAL_ALIGNMENT_CENTER)
	_sub.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	var help := _label(16, 1.0, -36, -12, HORIZONTAL_ALIGNMENT_CENTER)
	help.text = "Hiiri tähtää · vasen nappi / E ampuu · oikea nappi pohjassa: tarkka tähtäys · F lopeta · hirveen ei ole lupaa!"


func _label(size: int, anchor_y: float, top: float, bottom: float, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.anchor_right = 1.0
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_left = 24
	l.offset_right = -24
	l.offset_top = top
	l.offset_bottom = bottom
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(l)
	return l


func _say(text: String, seconds: float) -> void:
	_sub.text = text
	_sub_t = seconds


func _update_hud(delta: float) -> void:
	var barrels := "●".repeat(_loaded) + "○".repeat(2 - _loaded)
	_ammo.text = "Piiput %s   Patruunoita %d%s" % [barrels, _shells, "   LATAA..." if _reload_t > 0.0 else ""]
	_clock.text = "%d s" % ceili(maxf(_time, 0.0))
	var names := bag.map(func(k): return SPECIES[k].nom)
	_bag_label.text = "Saalis: %s" % (", ".join(names) if not names.is_empty() else "–")
	if _sub_t > 0.0:
		_sub_t -= delta
		if _sub_t <= 0.0:
			_sub.text = ""
