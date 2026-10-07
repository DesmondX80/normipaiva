extends Node3D
## Lavatanssit Oulujärven lavalla (vaala.gd _build_lava): 90-luvun lauantai-illan tanssit. Pohjoispäässä on
## tanssipuoli, jossa humppabändi soittaa lavalla ja seinän vieressä on baari; eteläpää väliseinän takana on
## diskopuoli, jossa nuorempi porukka hyppii DJ:n ja peilipallon alla. Pelaaja hakee parin jommallakummalla puolella
## ja tanssii: A ja D vuorotellen tahdissa (sykkivä tahtimerkki; diskossa tahti on nopeampi). Osumat tahtiin pitävät
## tanssin kauniina, hutit ja räpellys horjuttavat. Baarista saa tuopin (bar, main.gd hoitaa rahat). Kappaleen
## lopuksi finished(score 0..1); kutsuja antaa moraalit ja poistaa solmun. Solmu sijoitetaan lavan lattian keskelle
## (+z = etelään, lava 34 x 44 m, esiintymislava pohjoispäädyssä, ovi door_side-puolen kyljessä).

signal finished(score: float)

const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

const BPM := 104.0
const DISCO_BPM := 126.0
const SONG := 28.0       # s
const WINDOW := 0.16     # osuman sallittu poikkeama tahdista (s)
const COUPLES := 7
const YOUTH := 12
const BAND := "OULUJÄRVEN HUMPPAVEIKOT"
const SONGS := ["Humppa Oulujärven rannalla", "Letkajenkka", "Vaalan humppa", "Säkkijärven polkka humpaten",
	"Kesäillan valssi"]
const DISCO_SONGS := ["90-luvun eurodance-mix", "Teknohumppa (DJ-remix)", "Bilebiisi Oulusta", "Lavan disko-medley"]
const PARTNER_LINES := ["Tanssitaanko?", "Hyvin vie!", "Ootko käyny ennenki lavalla?", "Ihana ilta!", "Varo varpaita!"]
const DISCO_LINES := ["Tuu tanssiin!", "Ihan sika hyvä biisi!", "Ootko sää Vaalasta?", "Hyppää!", "Kova meininki!"]
const DISCO_Z := 8.0     # väliseinä: pohjoisessa tanssipuoli, etelässä disko
const W := 34.0
const L := 44.0

var courage := 0.0  # pontikkahuikka ennen lavaa (main.gd): leveämpi tahti-ikkuna, mutta kompastelee
## Seuralainen (Santtu tuli mopon takana): tanssii vieressä omalla parillaan. Tyhjä = yksin.
var buddy := {}
var _buddy: Node3D
var door_side := 1.0  # ovi itä- (1) vai länsikyljessä (-1); baari vastakkaiselle seinälle
## Baarin tilaus (main.gd): palauttaa [repliikki, tieto], rahat ja humala hoidetaan kutsujan puolella.
var bar := Callable()
var _mode := "humppa"  # humppa | disco
var _phase := "intro"  # intro | dance | result
var _t := 0.0
var _beat := 60.0 / BPM
var _next := "left"
var _hits := 0
var _misses := 0
var _last_press := -1.0
var _song := ""

var _cam: Camera3D
var _prev_cam: Camera3D
var _me: Node3D
var _partner: Node3D
var _dancers: Array[Node3D] = []
var _layer: CanvasLayer
var _title: Label
var _info: Label
var _pulse: Panel
var _score_bar: ProgressBar
var _bubble: Label3D
var _youth: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _ball: Node3D
var _bartender: Node3D


func _ready() -> void:
	_prev_cam = get_viewport().get_camera_3d()
	_song = SONGS.pick_random()
	_build_props()
	_spawn_people()
	_cam = Camera3D.new()
	_cam.fov = 60.0
	add_child(_cam)
	_cam.current = true
	_build_hud()
	_title.text = "OULUJÄRVEN LAVA"
	_intro_text()
	Sfx.music_play(1.0)


func _intro_text(extra := "") -> void:
	_info.text = "%sLauantain tanssit: %s soittaa \"%s\".\nVäliseinän takana diskopuoli nuorisolle.\nTanssi: vuorottele %s ja %s tahtimerkin tahdissa.\n\n%s Hae pari tanssipuolelta\n%s Diskopuolelle\n%s Baarista tuoppi (6,50 €)" % [
		extra, BAND.capitalize(), _song, Settings.action_key("left"), Settings.action_key("right"), Settings.cap("interact"),
		Settings.cap("mount"), Settings.cap("eat")]


## Tanssipuolen baari, väliseinä ja diskopuolen DJ-koppi, peilipallo ja värivalot (lava itse: vaala.gd _build_lava).
func _build_props() -> void:
	var dark := Color(0.12, 0.1, 0.12)
	var wood := Color(0.42, 0.26, 0.16)
	# Bändin banderolli lavan takaseinään.
	B.label(self, BAND, Vector3(0, 3.55, -L / 2.0 + 0.75), 64, Color(1.0, 0.85, 0.3))
	# Baari: tiski vastapäätä ovea tanssipuolen keskivaiheilla, hyllyt pulloineen seinällä.
	var bx := -door_side * (W / 2.0 - 1.6)
	B.mesh(self, B.boxm(Vector3(0.8, 1.1, 8.0)), Vector3(bx, 0.55, -4.0), wood)
	B.mesh(self, B.boxm(Vector3(1.0, 0.06, 8.2)), Vector3(bx, 1.13, -4.0), Color(0.25, 0.15, 0.1))
	var shelf_x := -door_side * (W / 2.0 - 0.35)
	for k in 2:
		B.mesh(self, B.boxm(Vector3(0.35, 0.05, 6.0)), Vector3(shelf_x, 1.5 + k * 0.55, -4.0), wood)
		for b in 14:
			var col: Color = [Color(0.2, 0.45, 0.15), Color(0.5, 0.3, 0.08), Color(0.85, 0.85, 0.9), Color(0.55, 0.1, 0.1)][(b + k) % 4]
			B.mesh(self, B.cyl(0.04, 0.045, 0.3, 8), Vector3(shelf_x, 1.68 + k * 0.55, -6.6 + b * 0.4), col)
	B.label(self, "BAARI", Vector3(shelf_x + door_side * 0.2, 2.75, -4.0), 48, Color(1.0, 0.95, 0.8)).rotation.y = door_side * PI / 2.0
	for k in 4:
		B.mesh(self, B.cyl(0.2, 0.2, 0.06, 12), Vector3(bx + door_side * 0.75, 0.75, -6.8 + k * 1.8), Color(0.6, 0.1, 0.1))
		B.mesh(self, B.cyl(0.04, 0.04, 0.72, 6), Vector3(bx + door_side * 0.75, 0.36, -6.8 + k * 1.8), Color(0.6, 0.6, 0.62))
	# Väliseinä, oviaukko keskellä ja neonkyltti.
	for sx in [-1.0, 1.0]:
		B.mesh(self, B.boxm(Vector3(W / 2.0 - 1.6, 3.0, 0.15)), Vector3(sx * (W / 4.0 + 0.8), 1.5, DISCO_Z), dark)
	B.mesh(self, B.boxm(Vector3(3.2, 0.6, 0.15)), Vector3(0, 2.75, DISCO_Z), dark)
	var neon := B.label(self, "DISKO", Vector3(0, 2.75, DISCO_Z - 0.12), 72, Color(1.0, 0.2, 0.8))
	neon.modulate = Color(1.0, 0.3, 0.9)
	neon.rotation.y = PI  # luetaan tanssipuolelta
	# Diskon lattia tummaksi, DJ-koppi eteläpäätyyn.
	B.mesh(self, B.boxm(Vector3(W - 0.6, 0.02, L / 2.0 - DISCO_Z - 0.4)), Vector3(0, 0.075, (DISCO_Z + L / 2.0) / 2.0), Color(0.16, 0.14, 0.2))
	var dj := Vector3(0, 0, L / 2.0 - 1.6)
	B.mesh(self, B.boxm(Vector3(4.0, 1.1, 1.2)), dj + Vector3(0, 0.55, 0), Color(0.1, 0.1, 0.12))
	for x in [-0.8, 0.8]:
		B.mesh(self, B.cyl(0.3, 0.3, 0.04, 16), dj + Vector3(x, 1.13, 0), Color(0.05, 0.05, 0.05))
	for x in [-2.6, 2.6]:
		B.mesh(self, B.boxm(Vector3(1.0, 1.8, 0.8)), dj + Vector3(x, 0.9, 0.1), Color(0.08, 0.08, 0.09))
	B.label(self, "DJ", dj + Vector3(0, 0.6, -0.62), 64, Color(0.3, 1.0, 1.0)).rotation.y = PI
	# Peilipallo ja pyörivät värivalot.
	_ball = Node3D.new()
	_ball.position = Vector3(0, 3.4, (DISCO_Z + L / 2.0) / 2.0)
	add_child(_ball)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.85, 0.85, 0.9)
	bm.metallic = 1.0
	bm.roughness = 0.15
	var sphere := MeshInstance3D.new()
	sphere.mesh = B.sphere(0.45, 10)
	sphere.material_override = bm
	_ball.add_child(sphere)
	for k in 4:
		var li := OmniLight3D.new()
		li.light_color = [Color(1, 0.1, 0.6), Color(0.2, 0.4, 1), Color(0.1, 1, 0.4), Color(1, 0.8, 0.1)][k]
		li.light_energy = 2.5
		li.omni_range = 9.0
		li.position = Vector3(-9.0 + k * 6.0, 3.0, (DISCO_Z + L / 2.0) / 2.0)
		add_child(li)
		_lights.append(li)


func _spawn_people() -> void:
	var shirts := [Color(0.85, 0.2, 0.3), Color(0.2, 0.35, 0.75), Color(0.95, 0.85, 0.3), Color(0.25, 0.55, 0.3),
		Color(0.95, 0.95, 0.95), Color(0.5, 0.2, 0.55), Color(0.15, 0.15, 0.17), Color(0.85, 0.5, 0.2)]
	var hairs := ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Long", "Hair_Buns"]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Humppabändi lavalla samoissa punaisissa liiveissä: laulaja, harmonikka, basso ja rummut.
	for k in 4:
		var look := {"shirt": Color(0.75, 0.1, 0.12), "pants": Color(0.1, 0.1, 0.12), "hair": hairs[k % 3],
			"hair_color": Color(0.3, 0.2, 0.12), "height": 1.8, "belly": 0.5}
		var m := Looks.make(self, look)
		var at_band := Vector3(-3.0 + k * 2.0, 1.0, -L / 2.0 + 3.2 + (-0.6 if k == 3 else 0.6))
		m.position = at_band
		m.play("Dance" if k < 2 else "Idle", 0.0, 0.9)
		if k == 1:  # harmonikka rinnalla
			B.mesh(m, B.boxm(Vector3(0.45, 0.35, 0.22)), Vector3(0, 1.15, -0.25), Color(0.7, 0.05, 0.08))
			B.mesh(m, B.boxm(Vector3(0.47, 0.3, 0.05)), Vector3(0, 1.15, -0.37), Color(0.95, 0.95, 0.9))
		elif k == 2:  # basso
			B.mesh(m, B.boxm(Vector3(0.3, 0.9, 0.08)), Vector3(0.1, 1.0, -0.2), Color(0.45, 0.25, 0.1)).rotation.z = 0.5
		elif k == 0:  # mikrofoniteline
			B.mesh(self, B.cyl(0.015, 0.015, 1.5, 6), at_band + Vector3(0, 0.75, -0.5), Color(0.2, 0.2, 0.2))
	# Baarimikko tiskin takana.
	_bartender = Looks.make(self, {"shirt": Color(0.95, 0.95, 0.95), "pants": Color(0.1, 0.1, 0.12), "hair": "Hair_Buzzed",
		"hair_color": Color(0.2, 0.15, 0.1), "height": 1.78})
	_bartender.position = Vector3(-door_side * (W / 2.0 - 1.0), 0.06, -4.0)
	_bartender.rotation.y = door_side * PI / 2.0
	_bartender.play("Idle", 0.0)
	# Pari asiakasta tiskillä.
	for k in 2:
		var c := Looks.make(self, {"shirt": shirts[(k * 5 + 1) % shirts.size()], "pants": Color(0.2, 0.2, 0.3),
			"hair": hairs[(k + 1) % hairs.size()], "hair_color": Color(0.35, 0.25, 0.12), "height": 1.78})
		c.position = Vector3(-door_side * (W / 2.0 - 2.6), 0.06, -6.0 + k * 3.2)
		c.rotation.y = -door_side * PI / 2.0
		c.play("Idle_Talking", 0.0)
	# Diskopuolen nuoret: kirkkaat värit, lippikset, hyppivät nopeammin.
	var neon := [Color(1.0, 0.2, 0.6), Color(0.1, 0.9, 0.9), Color(0.6, 1.0, 0.1), Color(1.0, 0.6, 0.0), Color(0.5, 0.2, 1.0),
		Color(0.95, 0.95, 0.95)]
	for k in YOUTH:
		var y := Looks.make(self, {"model": "female" if k % 2 == 1 else "male", "shirt": neon[rng.randi() % neon.size()],
			"pants": Color(0.15, 0.2, 0.45), "hair": hairs[rng.randi() % hairs.size()],
			"hair_color": Color(rng.randf_range(0.1, 0.9), rng.randf_range(0.08, 0.7), 0.1), "height": rng.randf_range(1.6, 1.8)})
		if k % 3 == 0:
			Looks.add_cap(y)
		y.position = Vector3(rng.randf_range(-13.0, 13.0), 0.08, rng.randf_range(DISCO_Z + 2.5, L / 2.0 - 3.5))
		y.rotation.y = rng.randf_range(-PI, PI)
		y.play("Dance", 0.0, rng.randf_range(1.2, 1.5))
		_youth.append(y)
	# Parit tanssipuolella.
	for k in COUPLES:
		var at := Vector3(rng.randf_range(-11.0, 11.0), 0.06, rng.randf_range(-13.0, DISCO_Z - 2.0))
		if at.length() < 4.0:
			at += at.normalized() * 4.0
		for s in 2:
			var look := {"model": "female" if s == 1 else "male", "shirt": shirts[rng.randi() % shirts.size()],
				"pants": Color(0.15, 0.15, 0.25) if s == 0 else shirts[rng.randi() % shirts.size()],
				"hair": hairs[rng.randi() % hairs.size()], "hair_color": Color(rng.randf_range(0.1, 0.8), rng.randf_range(0.08, 0.6), 0.1),
				"height": 1.8 if s == 0 else 1.66}
			var d := Looks.make(self, look)
			d.position = at + Vector3(0, 0, 0.45 if s == 0 else -0.45)
			d.rotation.y = 0.0 if s == 0 else PI
			d.play("Dance", 0.0, rng.randf_range(0.8, 1.1))
			_dancers.append(d)
	if not buddy.is_empty():
		_buddy = Looks.make(self, buddy)
		_buddy.position = Vector3(-2.5, 0.06, 2.6)
		_buddy.play("Dance", 0.0, 0.95)
		var bp := Looks.make(self, {"model": "female", "shirt": Color(0.95, 0.8, 0.3), "pants": Color(0.2, 0.2, 0.3),
			"hair": "Hair_Long", "hair_color": Color(0.5, 0.3, 0.15), "height": 1.66})
		bp.position = _buddy.position + Vector3(0, 0, -0.5)
		bp.rotation.y = PI
		bp.play("Dance", 0.0, 0.95)
		B.label(self, "Santtu", _buddy.position + Vector3(0, 2.2, 0), 24, Color(0.45, 0.75, 1.0), true).pixel_size = 0.005
	_me = Looks.make(self, Looks.PLAYER)
	_me.position = Vector3(0, 0.06, 2.0)
	_me.play("Idle", 0.0)
	_partner = Looks.make(self, {"model": "female", "shirt": Color(0.9, 0.25, 0.4), "pants": Color(0.12, 0.12, 0.2),
		"hair": "Hair_Long", "hair_color": Color(0.8, 0.65, 0.35), "height": 1.66})
	_partner.position = Vector3(1.6, 0.06, 0.6)
	_partner.rotation.y = -0.8
	_partner.play("Idle", 0.0)
	_bubble = B.bubble(self, Vector3(1.6, 2.2, 0.6), Color(1, 1, 0.85))


func _process(delta: float) -> void:
	_t += delta
	# Kamera kiertää hitaasti paria.
	var a := _t * 0.12
	var focus := (_me.position + _partner.position) / 2.0 + Vector3(0, 1.2, 0)
	_cam.look_at_from_position(to_global(focus + Vector3(sin(a) * 6.0, 2.2, cos(a) * 6.0)), to_global(focus))
	# Disko: peilipallo pyörii, värivalot sykkivät ja kiertävät.
	_ball.rotation.y += delta * 1.2
	for k in _lights.size():
		var li := _lights[k]
		li.light_energy = 1.5 + 2.0 * absf(sin(_t * 4.2 + k * 1.3))
		li.position.x = sin(_t * 0.8 + k * 1.6) * 11.0
	match _phase:
		"intro":
			if Input.is_action_just_pressed("interact"):
				_start_dance("humppa")
			elif Input.is_action_just_pressed("mount"):
				_start_dance("disco")
			elif Input.is_action_just_pressed("eat"):
				_order()
		"dance":
			_dance(delta)
		"result":
			if Input.is_action_just_pressed("interact"):
				Sfx.music_stop(1.0)
				if _prev_cam != null and is_instance_valid(_prev_cam):
					_prev_cam.current = true
				_layer.queue_free()
				finished.emit(_score())


## Pari haetaan tanssipuolelta (humppa) tai diskosta (nuorempi pari, nopeampi tahti).
func _start_dance(mode: String) -> void:
	_mode = mode
	_phase = "dance"
	_t = 0.0
	if mode == "disco":
		_beat = 60.0 / DISCO_BPM
		_song = DISCO_SONGS.pick_random()
		_me.position = Vector3(0, 0.08, (DISCO_Z + L / 2.0) / 2.0)
		_partner.queue_free()
		_partner = Looks.make(self, {"model": "female", "shirt": Color(0.1, 0.9, 0.9), "pants": Color(0.15, 0.2, 0.45),
			"hair": "Hair_Buns", "hair_color": Color(0.85, 0.7, 0.4), "height": 1.65})
		_title.text = "LAVAN DISKO"
	_partner.position = _me.position + Vector3(0, 0, -0.5)
	_partner.rotation.y = PI
	_me.rotation.y = 0.0
	_me.play("Dance", 0.2, 1.3 if mode == "disco" else 1.0)
	_partner.play("Dance", 0.2, 1.3 if mode == "disco" else 1.0)
	_say((DISCO_LINES if mode == "disco" else PARTNER_LINES)[0])
	_info.text = "%s ja %s vuorotellen, kun tahtimerkki sykähtää." % [Settings.action_key("left"), Settings.action_key("right")]


## Baari: tuoppi tiskiltä (rahat ja humala main.gd:ssä), baarimikko kuittaa.
func _order() -> void:
	if not bar.is_valid():
		return
	var r: Array = bar.call()
	_bartender.play("Idle_Talking", 0.2)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func() -> void: _bartender.play("Idle", 0.3))
	_intro_text("Baarimikko: \"%s\" %s\n" % [r[0], r[1]])


func _dance(_delta: float) -> void:
	var phase := fmod(_t, _beat) / _beat
	var near := minf(phase, 1.0 - phase) * _beat  # etäisyys lähimpään iskuun (s)
	_pulse.modulate.a = clampf(1.0 - phase * 2.5, 0.15, 1.0)
	_pulse.scale = Vector2.ONE * (1.0 + (1.0 - phase) * 0.35)
	var left := Input.is_action_just_pressed("left")
	var right := Input.is_action_just_pressed("right")
	if left or right:
		var ok := (left and _next == "left") or (right and _next == "right")
		var hasty := _t - _last_press < _beat * 0.5
		_last_press = _t
		var stumble := courage > 0.0 and randf() < 0.12 * courage
		if ok and near < WINDOW + 0.06 * courage and not hasty and not stumble:
			_hits += 1
			_next = "right" if _next == "left" else "left"
			if _hits % 12 == 0:
				_say((DISCO_LINES if _mode == "disco" else PARTNER_LINES).pick_random())
		else:
			_misses += 1
			_me.rotation.y += randf_range(-0.3, 0.3) * (2.0 if stumble else 1.0)
			if stumble:
				_say("Hups! Pontikka vie jalat.")
			if _misses % 5 == 0:
				_say("Auts! Varpaat!")
				Sfx.play("grunt", -6.0)
	_me.rotation.y = lerp_angle(_me.rotation.y, 0.0, 0.05)
	# Pari pyörii hitaasti lattialla.
	var turn := _t * 0.35
	var base := Vector3(0, 0.08, (DISCO_Z + L / 2.0) / 2.0) if _mode == "disco" else Vector3(0, 0.06, 2.0)
	_me.position = base + Vector3(sin(turn) * 1.2, 0, cos(turn) * 1.2)
	_partner.position = _me.position + Vector3(0, 0, -0.5).rotated(Vector3.UP, _me.rotation.y)
	_score_bar.value = _score() * 100.0
	_info.text = "%s · tahtiin %d, hutia %d · seuraavaksi %s" % [_song, _hits, _misses, Settings.action_key(_next)]
	if _t >= SONG:
		_phase = "result"
		var s := _score()
		_me.play("Idle", 0.4)
		_partner.play("Idle", 0.4)
		_say("Kiitos tanssista!" if s > 0.5 else "No... kiitos.")
		_title.text = "KAPPALE PÄÄTTYI"
		if _buddy != null:
			_say("Santtu: \"Kyllä kannatti tulla!\"" if s > 0.45 else "Santtu: \"Hyvin se meni. Melkein.\"")
		_info.text = (("Diskon kunkku! Nuoret hurraa." if _mode == "disco" else "Humppasit kuin Humppaveikot itse! Parisi hymyilee.") if s > 0.75 else
			("Ihan kelpo tanssi." if s > 0.45 else "Varpaat kärsivät, mutta ilta oli hauska.")) + "\n\n%s Lavalta ulos" % Settings.cap("interact")


func _score() -> float:
	var expected := maxf(_t / _beat * 0.8, 1.0)
	return clampf((_hits - _misses * 0.6) / expected, 0.0, 1.0)


func _say(text: String) -> void:
	_bubble.text = text
	_bubble.position = _partner.position + Vector3(0, 2.15, 0)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func() -> void: _bubble.text = "")


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 15
	add_child(_layer)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 10)
	_title.position = Vector2(40, 30)
	_layer.add_child(_title)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 22)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 7)
	_info.position = Vector2(40, 95)
	_layer.add_child(_info)
	_pulse = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.8, 0.2)
	sb.set_corner_radius_all(40)
	_pulse.add_theme_stylebox_override("panel", sb)
	_pulse.size = Vector2(80, 80)
	_pulse.pivot_offset = Vector2(40, 40)
	_pulse.anchor_left = 0.5
	_pulse.anchor_right = 0.5
	_pulse.anchor_top = 1.0
	_pulse.anchor_bottom = 1.0
	_pulse.offset_left = -40
	_pulse.offset_right = 40
	_pulse.offset_top = -170
	_pulse.offset_bottom = -90
	_layer.add_child(_pulse)
	_score_bar = ProgressBar.new()
	_score_bar.show_percentage = false
	_score_bar.anchor_left = 0.5
	_score_bar.anchor_right = 0.5
	_score_bar.anchor_top = 1.0
	_score_bar.anchor_bottom = 1.0
	_score_bar.offset_left = -160
	_score_bar.offset_right = 160
	_score_bar.offset_top = -70
	_score_bar.offset_bottom = -54
	_layer.add_child(_score_bar)
