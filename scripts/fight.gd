extends Node3D
## Street Fighter -tyylinen kaksintaistelu: SÄÄ vs. Raahen karateklubin perustaja.
## Areena on kaukana kartan ulkopuolella; main.gd käynnistää start()-kutsulla ja kuuntelee finished-signaalia.

const B := preload("res://scripts/build.gd")
const Fighter := preload("res://scripts/fighter.gd")
const Looks := preload("res://scripts/looks.gd")

const ROUND_TIME := 45.0
const HIT_WORDS := ["POW!", "BAM!", "KRAK!", "TÖKS!", "PLÄTS!", "HUI!"]
## Vastustajat: ulkonäkö, nimi, ääni, repliikit, erikoisaallon teksti ja tekoälyn luonne.
const FOES := {
	"juntti": {
		"look": Looks.JUNTTI, "name": "JUNTTI – Raahen karateklubin perustaja", "short": "JUNTTI", "voice": "juntti",
		"intro": ["Mää perustin Raahen karateklubin!", "Nyt sää saat kyytiä!", "Tuu tänne ni puhutaan!"],
		"win": ["Tuosta sait, hienohelma!", "Raahen karateklubi, vuodesta -87!"],
		"wave": "HAI-JAAH!", "wave_cry": "HAI-JAAH-KEN!", "hp": 100.0, "dmg": 1.0, "aggr": 1.0,
	},
	"akka": {
		"look": Looks.AKKA, "name": "LAAVUN AKKA – Tää on MEIDÄN laavu!", "short": "AKKA", "voice": "akka",
		"intro": ["Tää on MEIDÄN laavu!", "Täällä ei kaljoitella!", "Mää varasin tän koko kesäks!"],
		"win": ["Ja pysy poissa!", "Mää soitan vielä poliisit!"],
		"wave": "HALOO!", "wave_cry": "MÄÄ SOITAN POLIISIT!", "hp": 110.0, "dmg": 0.9, "aggr": 0.8,
	},
	"jemmari": {
		"look": Looks.JEMMARI, "name": "JYVÄJEMMARI – Pois mun viljoista!", "short": "JEMMARI", "voice": "pekka",
		"intro": ["POIS MUN VILJOISTA!", "Ne on siemenohraa!", "Nyt tulee turpaan, viljanpolkija!"],
		"win": ["Tuosta sait, viljanpolkija!", "Ja pysy poissa mun pellolta!"],
		"wave": "HEINÄPAALI!", "wave_cry": "OTA PAALI!", "hp": 120.0, "dmg": 1.1, "aggr": 0.85,
	},
	"teens": {
		"look": Looks.TEENS[0], "name": "TEINIJENGIN POMO – Raahe 4ever", "short": "TEINI", "voice": "teini",
		"intro": ["Mitä sää tuijotat, setä?", "Tää on meiän mesta!", "Ok boomer."],
		"win": ["Hähää, boomer!", "Mene kotias setä!"],
		"wave": "TÖLKKI!", "wave_cry": "Ota energiajuomaa!", "hp": 90.0, "dmg": 0.8, "aggr": 1.25,
	},
}
const PLAYER_WIN := ["Takasin Raaheen siitä!", "Normipäivä jatkuu."]

signal finished(player_won: bool, bags_used: int, thrown: int)

var foe := {}

var active := false
var beers := 0

var _p: Node3D
var _j: Node3D
var _cam: Camera3D
var _layer: CanvasLayer
var _bar_p: ProgressBar
var _bar_j: ProgressBar
var _timer_label: Label
var _announce: Label
var _help: Label
var _phase := "intro"
var _phase_t := 0.0
var _time := ROUND_TIME
var _hitstop := 0.0
var _shake := 0.0
var _waves: Array = []
var _effects: Array = []
var _ai_t := 0.0
var _ai_cmd := {}
var _ai_block_t := 0.0
var _wave_cd := 2.0
var _bags_used := 0
var _thrown := 0  # heitetyt kaljat (eteen + L)
var _cans: Array = []  # lentävät tölkit: {node, vel: Vector2, owner, dodge}
var _bubble_p: Label3D
var _bubble_j: Label3D
var _foe_name: Label
var _flash: ColorRect
var _combo_label: Label
var _combo := 0
var _combo_owner: Node3D
var _combo_t := 0.0
var _punch := 0.0  # kameran zoomi-isku
var _slowmo_until := 0
var _stars: Node3D


func _ready() -> void:
	_build_stage()
	_p = Fighter.new()
	add_child(_p)
	_p.setup(Looks.PLAYER)
	Looks.add_cap(_p.body)
	_p.display_name = "SÄÄ"
	_p.special = "bag"
	_p.fight = self
	_bubble_p = B.bubble(_p, Vector3(0, 2.3, 0), Color.WHITE)

	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_build_hud()
	_layer.visible = false
	set_process(false)


## Luo vastustajan profiilin mukaan (FOES) ja aloittaa erän.
func _make_foe(key: String) -> void:
	foe = FOES[key]
	if _j != null:
		_j.queue_free()
	_j = Fighter.new()
	add_child(_j)
	_j.setup(foe.look)
	_j.display_name = foe.short
	_j.special = "wave"
	_j.dmg_mult = foe.dmg
	_j.max_hp = foe.hp
	_j.fight = self
	_j.opponent = _p
	_p.opponent = _j
	_bubble_j = B.bubble(_j, Vector3(0, 2.3, 0), Color.WHITE)
	_foe_name.text = foe.name
	_bar_j.max_value = foe.hp


func start(beer_count: int, foe_key := "juntti") -> void:
	_make_foe(foe_key)
	beers = beer_count
	active = true
	_bags_used = 0
	_thrown = 0
	_p.reset(-2.5)
	_j.reset(2.5)
	_p.facing = 1.0
	_j.facing = -1.0
	_time = ROUND_TIME
	_phase = "intro"
	_phase_t = 0.0
	_wave_cd = 2.0
	_announce.text = "ROUND 1"
	_bar_j.value = foe.hp
	_bar_p.value = 100.0
	_say(_bubble_j, _j, foe.intro.pick_random())
	_update_help()
	_layer.visible = true
	Touch.set_extra([[KEY_J, "Lyö"], [KEY_K, "Potkaise"], [KEY_L, "Erikois"]])
	_cam.current = true
	set_process(true)
	Sfx.play("alert", -2.0, 0.8)


func _process(delta: float) -> void:
	_phase_t += delta
	match _phase:
		"intro":
			if _phase_t > 1.3 and _announce.text == "ROUND 1":
				_announce.text = "FIGHT!"
				Sfx.play("alert", 0.0, 1.2)
			if _phase_t > 2.0:
				_announce.text = ""
				_phase = "fight"
		"fight":
			_time -= delta
			if _p.hp <= 0.0 or _j.hp <= 0.0 or _time <= 0.0:
				_phase = "outro"
				_phase_t = 0.0
				_announce.text = "K.O.!" if (_p.hp <= 0.0 or _j.hp <= 0.0) else "AIKA LOPPUI!"
				if _time <= 0.0:
					# Aikaloppu: vähemmän energiaa jäänyt kaatuu.
					var loser: Node3D = _p if _p.hp <= _j.hp else _j
					loser.state = "ko"
		"outro":
			if _phase_t > 1.4 and _announce.text in ["K.O.!", "AIKA LOPPUI!"]:
				var won: bool = _p.state != "ko"
				(_p if won else _j).celebrate()
				_announce.text = "SÄÄ VOITTI!" if won else "%s VOITTI!" % foe.short
				_say(_bubble_p if won else _bubble_j, _p if won else _j, (PLAYER_WIN if won else foe.win).pick_random())
				Sfx.play("win" if won else "lose", -4.0)
			if _phase_t > 3.6:
				_end()
				return

	if _phase == "fight":
		_p.cmd = _player_cmd()
		_j.cmd = _ai(delta)
	else:
		_p.cmd = {"move": 0.0, "jump": false, "block": false, "attack": ""}
		_j.cmd = _p.cmd

	if _hitstop > 0.0:
		_hitstop -= delta
	else:
		_p.update(delta)
		_j.update(delta)
		_separate()
		_update_waves(delta)
		_update_cans(delta)
	_update_effects(delta)
	_update_camera(delta)
	_bar_p.value = lerpf(_bar_p.value, _p.hp, 1.0 - exp(-10.0 * delta))
	_bar_j.value = lerpf(_bar_j.value, _j.hp, 1.0 - exp(-10.0 * delta))
	_timer_label.text = str(ceili(maxf(_time, 0.0)))


func _end() -> void:
	Engine.time_scale = 1.0
	_slowmo_until = 0
	if _stars != null:
		_stars.queue_free()
		_stars = null
	_combo_label.text = ""
	active = false
	set_process(false)
	_layer.visible = false
	Touch.set_extra([])
	for w in _waves:
		w[0].queue_free()
	_waves.clear()
	for c in _cans:
		c.node.queue_free()
	_cans.clear()
	finished.emit(_p.state != "ko", _bags_used, _thrown)


# --- Ohjaus ------------------------------------------------------------------

func _player_cmd() -> Dictionary:
	var c := {
		"move": Input.get_axis("left", "right"),
		"jump": Input.is_action_just_pressed("forward"),
		"block": Input.is_action_pressed("back"),
		"attack": "",
	}
	if Input.is_action_just_pressed("punch"):
		c.attack = "punch"
	elif Input.is_action_just_pressed("kick"):
		c.attack = "kick"
	elif Input.is_action_just_pressed("special") and _beers_left() > 0 and _p.state in ["idle", "walk", "block"]:
		# Eteen + L heittää kaljan (maasta), pelkkä L lyö kassilla. Kumpikin vie yhden kaljan.
		if _p.on_ground() and signf(c.move) == _p.facing and absf(c.move) > 0.3:
			c.attack = "throw"
			_thrown += 1
		else:
			c.attack = "bag"
			_bags_used += 1
		_update_help()
	return c


## Juntin tekoäly: lähestyy, lyö ja potkii, torjuu välillä, heittää HAI-JAAH-KEN-aallon kaukaa.
func _ai(delta: float) -> Dictionary:
	_ai_t -= delta
	_wave_cd -= delta
	_ai_block_t -= delta
	var dist := absf(_p.position.x - _j.position.x)
	var toward := signf(_p.position.x - _j.position.x)
	var c := {"move": 0.0, "jump": false, "block": _ai_block_t > 0.0, "attack": ""}
	# Lähestyvä tölkki: joskus hyppää yli tai torjuu (päätetään kerran per tölkki).
	for can in _cans:
		if can.owner == _p and can.dodge == "" and absf(can.node.position.x - _j.position.x) < 4.0:
			var r := randf()
			can.dodge = "jump" if r < 0.2 else ("block" if r < 0.45 else "none")
			if can.dodge == "jump" and _j.on_ground() and _j.state in ["idle", "walk", "block"]:
				c.jump = true
				return c
			elif can.dodge == "block":
				_ai_block_t = 0.6
				c.block = true
	# Reagoi pelaajan hyökkäykseen joskus torjumalla.
	if _p.state == "attack" and dist < 2.0 and _ai_block_t <= 0.0 and randf() < 2.5 * delta:
		_ai_block_t = 0.5
	if _ai_block_t > 0.0:
		return c
	if _ai_t > 0.0:
		c.move = _ai_cmd.get("move", 0.0)
		return c
	var aggr: float = foe.get("aggr", 1.0)
	_ai_t = randf_range(0.18, 0.45) / aggr
	_ai_cmd = {"move": 0.0}
	if dist > 3.2 and _wave_cd <= 0.0 and randf() < 0.45:
		c.attack = "wave"
		_wave_cd = randf_range(3.5, 6.0)
		_say(_bubble_j, _j, foe.wave_cry)
	elif dist > 1.5:
		_ai_cmd.move = toward if randf() < 0.85 else -toward
		if randf() < 0.08:
			c.jump = true
	else:
		var r := randf()
		if r < 0.1:
			c.attack = "punch"
			c.block = true  # pystykoukku
		elif r < 0.2:
			c.attack = "kick"
			c.block = true  # jalkapyyhkäisy
		elif r < 0.3:
			c.attack = "kick"
			_ai_cmd.move = toward  # kiertopotku
		elif r < 0.52:
			c.attack = "punch"
		elif r < 0.75:
			c.attack = "kick"
		elif r < 0.88:
			_ai_block_t = 0.6
		else:
			_ai_cmd.move = -toward
	c.move = _ai_cmd.move
	return c


func _separate() -> void:
	var dx := _j.position.x - _p.position.x
	if absf(dx) < 0.75 and absf(_j.position.y - _p.position.y) < 1.2:
		var push := (0.75 - absf(dx)) / 2.0 * (signf(dx) if dx != 0.0 else 1.0)
		_p.position.x = clampf(_p.position.x - push, -Fighter.STAGE, Fighter.STAGE)
		_j.position.x = clampf(_j.position.x + push, -Fighter.STAGE, Fighter.STAGE)


# --- Osumat & efektit --------------------------------------------------------

func on_hit(attacker: Node3D, target: Node3D, blocked: bool, kind: String) -> void:
	var pos: Vector3 = target.position + Vector3(0, 1.4, 0.3)
	if blocked:
		_effect("TORJUTTU", pos, Color(0.6, 0.85, 1.0), 0.8)
		Sfx.play("cloth", 0.0, 0.8)
		Sfx.play("punch", -10.0, 0.7)
		_hitstop = 0.04
		return
	var big := kind in ["bag", "kick", "spin", "uppercut", "flykick", "throw"]
	var word: String = {"bag": "KASSI-ISKU!", "spin": "KIERTOPOTKU!", "uppercut": "PYSTYKOUKKU!", "sweep": "PYYHKÄISY!",
		"flykick": "LENTOPOTKU!", "throw": "TÖLKKI PÄIN NAAMAA!"}.get(kind, HIT_WORDS.pick_random())
	_effect(word, pos, Color(1, 0.85, 0.1), 1.3 if big else 1.0)
	Sfx.play("punch_heavy" if big else "punch", 0.0 if big else -2.0, randf_range(0.92, 1.08))
	if target.state == "ko":
		Sfx.play("body_fall", 0.0)
	if kind == "bag":
		Sfx.play("glass", -6.0)
	elif kind == "throw":
		Sfx.play("rattle_hard", 0.0, 0.9)  # tölkki kolahtaa
	_hitstop = 0.09 if big else 0.05
	_shake = 0.35 if big else 0.15
	_punch = 1.0 if big else 0.5
	_spark(pos + Vector3(-attacker.facing * 0.2, 0, 0), big)
	_flash.color.a = 0.45 if big else 0.18
	# Kombot: osumat alle 0,9 s välein samalta lyöjältä.
	if _combo_owner == attacker and _combo_t > 0.0:
		_combo += 1
	else:
		_combo = 1
		_combo_owner = attacker
	_combo_t = 0.9
	if _combo >= 2:
		_combo_label.text = "%d HIT COMBO!" % _combo
		var left := attacker == _p
		_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		_combo_label.pivot_offset = Vector2(0.0 if left else _combo_label.size.x, 35)
		_combo_label.scale = Vector2.ONE * 1.35
	if target.state == "ko":
		_hitstop = 0.25
		_shake = 0.7
		_punch = 1.6
		_flash.color.a = 0.7
		_slowmo_until = Time.get_ticks_msec() + 900
		Engine.time_scale = 0.3
		_dizzy(target)


## Iskun kohtaan kipinäsuihku ja välähtävä tähti.
func _spark(pos: Vector3, big: bool) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 30 if big else 16
	p.lifetime = 0.45
	p.direction = Vector3(0, 0.3, 1)
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0 if big else 5.0
	p.gravity = Vector3(0, -7, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := B.unshaded(Color(1.8, 1.4, 0.4))
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	p.mesh = q
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0, true, false, true).timeout.connect(p.queue_free)
	# Tähti: kahdeksansakarainen välähdys.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 16:
		var a0 := TAU * k / 16.0
		var a1 := TAU * (k + 1) / 16.0
		var r0 := 0.7 if k % 2 == 0 else 0.25
		var r1 := 0.25 if k % 2 == 0 else 0.7
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0), sin(a0), 0) * r0)
		st.add_vertex(Vector3(cos(a1), sin(a1), 0) * r1)
	var star := MeshInstance3D.new()
	star.mesh = st.commit()
	var sm := B.unshaded(Color(1.6, 1.3, 0.5, 0.9))
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	star.material_override = sm
	star.position = pos + Vector3(0, 0, 0.3)
	star.rotation.z = randf() * TAU
	add_child(star)
	var size := 1.3 if big else 0.8
	var tw := create_tween().set_ignore_time_scale(true)
	star.scale = Vector3.ONE * 0.2
	tw.tween_property(star, "scale", Vector3.ONE * size, 0.08)
	tw.tween_property(star, "scale", Vector3.ONE * size * 1.3, 0.12)
	tw.parallel().tween_property(sm, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(star.queue_free)


## Lyönnin/potkun kaari: puolikuun muotoinen välähdys hyökkääjän edessä.
func spawn_swoosh(owner: Node3D, kind: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	var inner := 0.45
	var outer := 0.8 if kind != "punch" else 0.65
	for i in steps:
		var a0 := lerpf(-1.1, 1.1, float(i) / steps)
		var a1 := lerpf(-1.1, 1.1, float(i + 1) / steps)
		var w0 := sin(PI * float(i) / steps)
		var w1 := sin(PI * float(i + 1) / steps)
		var o0 := inner + (outer - inner) * w0
		var o1 := inner + (outer - inner) * w1
		for v in [Vector3(cos(a0) * inner, sin(a0) * inner, 0), Vector3(cos(a0) * o0, sin(a0) * o0, 0), Vector3(cos(a1) * o1, sin(a1) * o1, 0),
				Vector3(cos(a0) * inner, sin(a0) * inner, 0), Vector3(cos(a1) * o1, sin(a1) * o1, 0), Vector3(cos(a1) * inner, sin(a1) * inner, 0)]:
			st.add_vertex(v)
	var arc := MeshInstance3D.new()
	arc.mesh = st.commit()
	var col := Color(1.0, 1.0, 1.0, 0.7) if kind == "punch" else (Color(1.0, 0.6, 0.2, 0.8) if kind == "kick" else Color(1.0, 0.5, 0.0, 0.85))
	var m := B.unshaded(col)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc.material_override = m
	var h: float = {"punch": 1.45, "airpunch": 1.45, "kick": 0.95, "bag": 1.25, "uppercut": 1.2, "sweep": 0.25,
		"spin": 1.0, "flykick": 0.8}.get(kind, 1.2)
	arc.position = owner.position + Vector3(owner.facing * 0.35, h, 0.25)
	arc.scale = Vector3(owner.facing, 1, 1)
	arc.rotation.z = {"kick": -0.4, "uppercut": 1.2, "sweep": -0.1, "flykick": -0.7}.get(kind, 0.0) * owner.facing
	if kind == "spin":
		arc.scale = Vector3(owner.facing * 1.4, 1.4, 1)
	add_child(arc)
	var tw := create_tween()
	tw.tween_property(arc, "scale", Vector3(owner.facing * 1.35, 1.35, 1), 0.18)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(arc.queue_free)


## Pölypilvi laskeutumisesta tai kaatumisesta.
func spawn_dust(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 14
	p.lifetime = 0.8
	p.direction = Vector3(0, 0.4, 0)
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	sm.material = B.unshaded(Color(0.7, 0.68, 0.62, 0.4))
	p.mesh = sm
	p.position = pos + Vector3(0, 0.1, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5, true, false, true).timeout.connect(p.queue_free)


## Tähdet pyörivät kaatuneen yllä.
func _dizzy(target: Node3D) -> void:
	if _stars != null:
		_stars.queue_free()
	_stars = Node3D.new()
	add_child(_stars)
	_stars.position = target.position + Vector3(target.facing * -0.8, 0.7, 0)
	for k in 4:
		var s := MeshInstance3D.new()
		s.mesh = B.sphere(0.07, 8)
		s.material_override = B.unshaded(Color(1.5, 1.3, 0.3))
		s.position = Vector3(cos(TAU * k / 4.0) * 0.35, 0, sin(TAU * k / 4.0) * 0.35)
		_stars.add_child(s)


func spawn_wave(owner: Node3D) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = owner.position + Vector3(owner.facing * 0.8, 1.3, 0)
	var orb := MeshInstance3D.new()
	orb.mesh = B.sphere(0.35)
	var m := B.unshaded(Color(1.4, 0.8, 0.2))
	orb.material_override = m
	node.add_child(orb)
	var halo := MeshInstance3D.new()
	halo.mesh = B.sphere(0.55)
	halo.material_override = B.unshaded(Color(1.0, 0.5, 0.1, 0.35))
	node.add_child(halo)
	B.label(node, foe.get("wave", "HAI-JAAH!"), Vector3(0, 0.7, 0), 48, Color(1, 0.9, 0.3), true)
	_waves.append([node, owner.facing, owner])
	Sfx.play("whoosh", 0.0, 0.6)


func _beers_left() -> int:
	return beers - _bags_used - _thrown


## Kaljatölkki lähtee heittäjän kädestä kaaressa kohti vastustajaa.
func spawn_can(owner: Node3D) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = owner.position + Vector3(owner.facing * 0.6, 1.6, 0)
	B.mesh(node, B.cyl(0.05, 0.05, 0.18, 12), Vector3.ZERO, Color(0.85, 0.78, 0.2))
	B.mesh(node, B.cyl(0.05, 0.05, 0.02, 12), Vector3(0, 0.09, 0), Color(0.75, 0.75, 0.78))
	_cans.append({"node": node, "vel": Vector2(owner.facing * 9.0, 2.0), "owner": owner, "dodge": "", "spent": false})
	Sfx.play("whoosh", -2.0, 1.3)


## Tölkit lentävät painovoiman alla. Osuma: vahinko, kaatuminen ja vaahto. Hyppy väistää (tölkki menee alta),
## torjunta kimmottaa sen hukkaan. Maahan pudonnut tölkki kolahtaa ja katoaa.
func _update_cans(delta: float) -> void:
	for c in _cans.duplicate():
		var node: Node3D = c.node
		var owner: Node3D = c.owner
		var target: Node3D = owner.opponent
		c.vel.y -= 12.0 * delta
		node.position += Vector3(c.vel.x, c.vel.y, 0) * delta
		node.rotation.z -= signf(c.vel.x) * 14.0 * delta
		var dx := node.position.x - target.position.x
		var rel_y := node.position.y - target.position.y
		# Ilmassa oleva väistää: tölkki menee alta.
		if not c.spent and absf(dx) < 0.45 and rel_y > 0.2 and rel_y < 1.9 and target.state != "ko" \
				and target.position.y < 0.4:
			var dir := signf(c.vel.x)
			var a: Dictionary = Fighter.ATTACKS.throw
			var blocked: bool = target.take_hit(a.dmg * owner.dmg_mult, dir, a.push, a.launch, a.stun)
			on_hit(owner, target, blocked, "throw")
			if blocked:
				c.vel = Vector2(-dir * 2.5, 4.0)  # kimpoaa hukkaan
				c.spent = true
				Sfx.play("rattle_hard", -4.0, 1.3)
			else:
				_foam(node.position)
				node.queue_free()
				_cans.erase(c)
			continue
		if node.position.y <= 0.05:
			Sfx.play("rattle", -6.0, 1.2)
			node.queue_free()
			_cans.erase(c)
		elif absf(node.position.x) > Fighter.STAGE + 3.0:
			node.queue_free()
			_cans.erase(c)


## Vaahtosuihku tölkin osuessa, ja sihinä.
func _foam(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 40
	p.lifetime = 0.8
	p.direction = Vector3(0, 1, 0.3)
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.material = B.unshaded(Color(1.0, 0.97, 0.85, 0.85))
	p.mesh = sm
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5, true, false, true).timeout.connect(p.queue_free)
	Sfx.play("whoosh", -4.0, 0.45)


func _update_waves(delta: float) -> void:
	for w in _waves.duplicate():
		var node: Node3D = w[0]
		var dir: float = w[1]
		var owner: Node3D = w[2]
		node.position.x += dir * 7.5 * delta
		node.rotation.z += delta * 8.0
		var target: Node3D = owner.opponent
		if absf(node.position.x - target.position.x) < 0.5 and target.position.y < 0.9 and target.state != "ko":
			var blocked: bool = target.take_hit(Fighter.ATTACKS.wave.dmg * owner.dmg_mult, dir, Fighter.ATTACKS.wave.push)
			on_hit(owner, target, blocked, "wave")
			node.queue_free()
			_waves.erase(w)
		elif absf(node.position.x) > Fighter.STAGE + 3.0:
			node.queue_free()
			_waves.erase(w)


func _effect(text: String, pos: Vector3, col: Color, size: float) -> void:
	var l := B.label(self, text, pos, int(96 * size), col, true)
	l.outline_size = 24
	_effects.append([l, 0.0])


func _update_effects(delta: float) -> void:
	for e in _effects.duplicate():
		var l: Label3D = e[0]
		e[1] += delta
		var t: float = e[1]
		l.position.y += delta * 1.2
		l.scale = Vector3.ONE * (1.0 + t * 1.5)
		l.modulate.a = 1.0 - t / 0.7
		l.outline_modulate.a = l.modulate.a
		if t > 0.7:
			l.queue_free()
			_effects.erase(e)
	for b in [[_bubble_p, _p], [_bubble_j, _j]]:
		var lbl: Label3D = b[0]
		if lbl.has_meta("t"):
			lbl.set_meta("t", lbl.get_meta("t") - delta)
			if lbl.get_meta("t") <= 0.0:
				lbl.text = ""


func _say(lbl: Label3D, who: Node3D, text: String) -> void:
	lbl.text = text
	lbl.set_meta("t", 2.2)
	Sfx.babble(who, foe.get("voice", "juntti") if who == _j else "kassa", text)


func _update_camera(delta: float) -> void:
	# Hidastus K.O.:ssa (reaaliajassa mitattuna), zoomi-isku ja komboteksti.
	if _slowmo_until > 0 and Time.get_ticks_msec() > _slowmo_until:
		Engine.time_scale = 1.0
		_slowmo_until = 0
	var real := delta / maxf(Engine.time_scale, 0.01)
	_punch = maxf(0.0, _punch - real * 3.0)
	_cam.fov = 50.0 - _punch * 7.0
	_flash.color.a = maxf(0.0, _flash.color.a - real * 3.0)
	_combo_t -= real
	if _combo_t <= 0.0:
		_combo_label.text = ""
	_combo_label.scale = _combo_label.scale.lerp(Vector2.ONE, 1.0 - exp(-10.0 * real))
	if _stars != null:
		_stars.rotation.y += real * 5.0
	var mid := (_p.position.x + _j.position.x) / 2.0
	var dist := absf(_p.position.x - _j.position.x)
	var target := Vector3(mid, 1.9, 6.5 + clampf(dist - 3.0, 0.0, 6.0) * 0.55)
	_cam.position = _cam.position.lerp(target, 1.0 - exp(-5.0 * delta))
	_shake = maxf(0.0, _shake - delta)
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.3
	_cam.position += off
	_cam.look_at(global_position + Vector3(mid, 1.15, 0) + off, Vector3.UP)


# --- Areena & HUD ------------------------------------------------------------

## Pieni katunäyttämö: asfaltti, talorivi taustalla, koivuja, katsojina harmaapäät ja Anna-Liisa.
func _build_stage() -> void:
	var asphalt := B.shader_mat("res://shaders/ground.gdshader", {
		"color_a": Color(0.2, 0.2, 0.21), "color_b": Color(0.3, 0.3, 0.31), "scale": 0.05, "fine_scale": 2.5, "bump": 0.3})
	var grass := B.shader_mat("res://shaders/ground.gdshader", {
		"color_a": Color(0.3, 0.45, 0.18), "color_b": Color(0.46, 0.58, 0.25)})
	var street := B.box(self, Vector3(40, 0.2, 8), Vector3(0, -0.1, 0), Color.WHITE, false) as MeshInstance3D
	street.material_override = asphalt
	var lawn := B.box(self, Vector3(200, 0.2, 200), Vector3(0, -0.12, -40), Color.WHITE, false) as MeshInstance3D
	lawn.material_override = grass
	for x in range(-18, 19, 4):
		B.box(self, Vector3(2.2, 0.02, 0.15), Vector3(x, 0.01, 0), Color(0.9, 0.9, 0.85), false)
	B.box(self, Vector3(40, 0.18, 0.3), Vector3(0, 0.09, -4.1), Color(0.6, 0.6, 0.58), false)
	var cols := [Color(0.6, 0.15, 0.11), Color(0.88, 0.78, 0.44), Color(0.92, 0.91, 0.87), Color(0.58, 0.7, 0.78)]
	for i in 6:
		var x := -20.0 + i * 8.0
		var c: Color = cols[i % cols.size()]
		B.box(self, Vector3(6.5, 3.3, 5), Vector3(x, 1.65, -14), c, false)
		var roof := PrismMesh.new()
		roof.size = Vector3(6.0, 2.0, 7.2)
		B.mesh(self, roof, Vector3(x, 4.3, -14), Color(0.2, 0.2, 0.22), Vector3(0, 90, 0))
		for wx in [-1.6, 1.6]:
			B.box(self, Vector3(1.3, 1.1, 0.1), Vector3(x + wx, 1.8, -11.45), Color(0.12, 0.17, 0.24), false)
		B.box(self, Vector3(1.0, 2.1, 0.1), Vector3(x, 1.05, -11.45), Color(0.35, 0.22, 0.14), false)
	# K-Marketin kyltti taustalla.
	B.box(self, Vector3(9, 4, 4), Vector3(26, 2, -12), Color(0.95, 0.95, 0.93), false)
	B.box(self, Vector3(9.2, 1.0, 4.2), Vector3(26, 3.6, -12), Color(1.0, 0.42, 0.0), false)
	B.label(self, "K-Market", Vector3(26, 3.6, -9.85), 110, Color.WHITE)
	for x in [-14.0, -6.0, 4.0, 12.0, 20.0]:
		B.mesh(self, B.cyl(0.11, 0.2, 6.0, 7), Vector3(x, 3.0, -9), Color(0.92, 0.92, 0.88))
		B.mesh(self, B.sphere(1.7, 8), Vector3(x, 6.0, -9), Color(0.36, 0.58, 0.22))
		B.mesh(self, B.sphere(1.3, 8), Vector3(x + 0.9, 5.2, -8.7), Color(0.4, 0.6, 0.24))
	# Katsojat.
	var crowd := [[Looks.GRANDPAS[0], -5.0], [Looks.GRANDPAS[1], -3.5], [Looks.ANNA_LIISA, 3.8], [Looks.GRANDPAS[2], 5.2]]
	for c in crowd:
		var person := Looks.make(self, c[0])
		person.position = Vector3(c[1], 0, -5.5)
		person.rotation.y = PI
		person.play("Idle_Talking" if c[0] != Looks.ANNA_LIISA else "Idle", 0.0)
		if c[0] != Looks.ANNA_LIISA:
			Looks.hunch(person, 0.3)
	var annaliisa := B.guide(self, "Naapurin Anna-Liisa", Vector3(3.8, 2.1, -5.5), 32, Color(0.8, 1, 0.95), true)
	annaliisa.no_depth_test = false


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)

	_bar_p = _health_bar(root, true)
	_bar_j = _health_bar(root, false)
	_name(root, "SÄÄ", true)
	_foe_name = _name(root, "JUNTTI – Raahen karateklubin perustaja", false)

	_timer_label = _big_label(root, 54)
	_timer_label.anchor_left = 0.5
	_timer_label.anchor_right = 0.5
	_timer_label.offset_left = -50
	_timer_label.offset_right = 50
	_timer_label.offset_top = 10
	_timer_label.offset_bottom = 80

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	_combo_label = _big_label(root, 52)
	_combo_label.anchor_left = 0.0
	_combo_label.anchor_right = 1.0
	_combo_label.offset_left = 40
	_combo_label.offset_right = -40
	_combo_label.offset_top = 110
	_combo_label.offset_bottom = 180
	_combo_label.pivot_offset = Vector2(600, 35)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1))
	_combo_label.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.0))
	_combo_label.add_theme_constant_override("outline_size", 14)
	_announce = _big_label(root, 110)
	_announce.anchor_left = 0.0
	_announce.anchor_right = 1.0
	_announce.anchor_top = 0.35
	_announce.anchor_bottom = 0.35
	_announce.offset_top = -80
	_announce.offset_bottom = 80
	_announce.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	_announce.add_theme_color_override("font_outline_color", Color(0.5, 0.05, 0.0))
	_announce.add_theme_constant_override("outline_size", 22)

	_help = _big_label(root, 15)
	_help.anchor_left = 0.0
	_help.anchor_right = 1.0
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_top = -40
	_help.offset_bottom = -12


func _update_help() -> void:
	var left := _beers_left()
	_help.text = "A/D liiku · W hyppy · S torju · J lyönti · K potku · S+J pystykoukku · S+K pyyhkäisy · eteen+K kiertopotku · ilmassa K lentopotku · L kassi-isku · eteen+L heitä kalja (%s)" % (
		"%d kaljaa" % left if left > 0 else "ei kaljoja")


func _health_bar(root: Control, left: bool) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if left else ProgressBar.FILL_END_TO_BEGIN
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.8, 0.1)
	fill.border_color = Color(0.9, 0.3, 0.0)
	fill.set_border_width_all(2)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.5, 0.05, 0.05, 0.9)
	bg.border_color = Color.WHITE
	bg.set_border_width_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	bar.anchor_left = 0.0 if left else 0.5
	bar.anchor_right = 0.5 if left else 1.0
	bar.offset_left = 30 if left else 60
	bar.offset_right = -60 if left else -30
	bar.offset_top = 24
	bar.offset_bottom = 56
	root.add_child(bar)
	return bar


func _name(root: Control, text: String, left: bool) -> Label:
	var l := _big_label(root, 24)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	l.anchor_left = 0.0 if left else 0.5
	l.anchor_right = 0.5 if left else 1.0
	l.offset_left = 34 if left else 60
	l.offset_right = -60 if left else -34
	l.offset_top = 58
	l.offset_bottom = 90
	return l


func _big_label(root: Control, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l
