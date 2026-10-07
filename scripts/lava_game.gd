extends Node3D
## Lavatanssit Oulujärven lavalla (vaala.gd _build_lava): 90-luvun lauantai-illan tanssit. Bändi soittaa lavalla,
## lattialla pyörii pareja, ja pelaaja hakee parin ja tanssii: A ja D vuorotellen tahdissa (sykkivä tahtimerkki).
## Osumat tahtiin pitävät tanssin kauniina, hutit ja räpellys horjuttavat. Kappaleen lopuksi finished(score 0..1);
## kutsuja (main.gd) antaa moraalit ja poistaa solmun. Solmu sijoitetaan lavan lattian keskelle (+z = etelään).

signal finished(score: float)

const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

const BPM := 104.0
const SONG := 28.0       # s
const WINDOW := 0.16     # osuman sallittu poikkeama tahdista (s)
const COUPLES := 9
const SONGS := ["Satumaa-tango", "Kesäillan valssi", "Humppa Oulujärven rannalla", "Lavan kuningas -foksi"]
const PARTNER_LINES := ["Tanssitaanko?", "Hyvin vie!", "Ootko käyny ennenki lavalla?", "Ihana ilta!", "Varo varpaita!"]

var courage := 0.0  # pontikkahuikka ennen lavaa (main.gd): leveämpi tahti-ikkuna, mutta kompastelee
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


func _ready() -> void:
	_prev_cam = get_viewport().get_camera_3d()
	_song = SONGS.pick_random()
	_spawn_people()
	_cam = Camera3D.new()
	_cam.fov = 60.0
	add_child(_cam)
	_cam.current = true
	_build_hud()
	_title.text = "OULUJÄRVEN LAVA"
	_info.text = "Lauantain tanssit, bändi soittaa: %s.\nHae pari ja tanssi: vuorottele %s ja %s tahtimerkin tahdissa.\n\n%s Hae pari" % [
		_song, Settings.action_key("left"), Settings.action_key("right"), Settings.cap("interact")]
	Sfx.music_play(1.0)


func _spawn_people() -> void:
	var shirts := [Color(0.85, 0.2, 0.3), Color(0.2, 0.35, 0.75), Color(0.95, 0.85, 0.3), Color(0.25, 0.55, 0.3),
		Color(0.95, 0.95, 0.95), Color(0.5, 0.2, 0.55), Color(0.15, 0.15, 0.17), Color(0.85, 0.5, 0.2)]
	var hairs := ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Long", "Hair_Buns"]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Bändi lavalla (laulaja, kitara, basso, rummut).
	for k in 4:
		var look := {"shirt": shirts[(k * 3) % shirts.size()], "pants": Color(0.12, 0.12, 0.14), "hair": hairs[k % 3],
			"hair_color": Color(0.3, 0.2, 0.12), "height": 1.8}
		var m := Looks.make(self, look)
		m.position = Vector3(-3.0 + k * 2.0, 1.0, -22.0 + 3.2 + (-0.6 if k == 3 else 0.6))
		m.play("Dance" if k == 0 else "Idle", 0.0, 0.8)
	# Parit lattialla.
	for k in COUPLES:
		var at := Vector3(rng.randf_range(-12.0, 12.0), 0.06, rng.randf_range(-12.0, 16.0))
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
	match _phase:
		"intro":
			if Input.is_action_just_pressed("interact"):
				_phase = "dance"
				_t = 0.0
				_partner.position = _me.position + Vector3(0, 0, -0.5)
				_partner.rotation.y = PI
				_me.rotation.y = 0.0
				_me.play("Dance", 0.2)
				_partner.play("Dance", 0.2)
				_say(PARTNER_LINES[0])
				_info.text = "%s ja %s vuorotellen, kun tahtimerkki sykähtää." % [Settings.action_key("left"), Settings.action_key("right")]
		"dance":
			_dance(delta)
		"result":
			if Input.is_action_just_pressed("interact"):
				Sfx.music_stop(1.0)
				if _prev_cam != null and is_instance_valid(_prev_cam):
					_prev_cam.current = true
				_layer.queue_free()
				finished.emit(_score())


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
				_say(PARTNER_LINES.pick_random())
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
	_me.position = Vector3(sin(turn) * 1.2, 0.06, 2.0 + cos(turn) * 1.2)
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
		_info.text = ("Tanssit kuin Kesäillan valssissa! Parisi hymyilee." if s > 0.75 else
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
