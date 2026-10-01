extends Node3D
## Pihapingis Santtua vastaan mökin nurmella, Street Fighter -tyyliin sivulta kuvattuna. Ei pöytää: isoilla
## puumailoilla lyödään palloa ilmassa pelaajalta toiselle, ja se, jonka puolelle pallo putoaa maahan,
## häviää erän (ROUND). Kaksi erävoittoa voittaa ottelun. Pallo kiihtyy rallin pidetessä.
## A/D liiku, W hyppy, J lyönti, K smash (kova ja matala, vain korkeasta pallosta), eteen/taakse lyödessä
## pitkä/lyhyt pallo. Ohi vastustajan ulottuvilta (ULOS!) lyönyt häviää erän itse.
## main.gd luo solmun kaukana kartan ulkopuolella ja kuuntelee finished(won, me, santtu); kutsuja poistaa solmun.

signal finished(won: bool, my_rounds: int, santtu_rounds: int)

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Mokki := preload("res://scripts/mokki.gd")

const R := 0.045  # pallo on näkyvyyden vuoksi vähän oikeaa isompi
const G := 9.0
const PADDLE_R := 0.2  # iso puumaila
const REACH := 0.8  # mailan ulottuma pallosta
const HIT_Y := 1.15  # mailan korkeus maassa seistessä
const SWING_FROM := 0.03
const SWING_TO := 0.26
const SWING_LEN := 0.45
const WALK := 3.6
const JUMP := 4.4
const X_MIN := 0.6  # kummankin pelaajan etäisyys keskilinjasta vähintään
const X_MAX := 6.0  # ja enintään (kauemmas lyöty pallo on ulkona)
const ROUNDS_TO_WIN := 2
const HIT_WORDS := ["PLOK!", "PONK!", "TÖK!", "PLÄK!", "KLONK!"]
const SANTTU_INTRO := ["Pihapingis on mun laji. Superhost mailassakin!", "Tällä nurmella ei oo vielä kukaan voittanu.",
	"Katotaan, mitä kaupunkilainen osaa.", "Häviäjä lämmittää saunan!"]
const SANTTU_ROUND_WIN := ["Heh, kotikenttäetu!", "Tuo oli Airbnb-tason palvelu.", "Viides vuosi Superhostina, eikä pihapeleissä hävitä.",
	"Mitäs nyt?"]
const SANTTU_ROUND_LOSE := ["Perkele!", "Tuuripallo.", "No huh.", "Aurinko paisto silmiin!", "Mäntyyn osu, eikö?"]
const SANTTU_WIN := ["Pihapingismestari Neittävältä!", "Tuu uuestaan, harjottelet vähän."]
const SANTTU_LOSE := ["Hyvä peli. Sää saat kahvit.", "Ensi kerralla mää voitan, oikeesti."]

var _phase := "intro"  # intro | serve | rally | point | over | done
var _t := 0.0
var _rounds := [0, 0]  # erävoitot [pelaaja, Santtu]
var _round := 1
var _server := 0  # 0 = pelaaja, 1 = Santtu (erän hävinnyt syöttää seuraavaksi)

## Pelaajat: 0 = pelaaja vasemmalla (katse +X), 1 = Santtu oikealla (katse -X).
var _pl: Array = []  # {body, x, y, vy, facing, swing_t, kind, aim, hit_done, moving, bubble, say_t}
var _ball := Vector2.ZERO
var _vel := Vector2.ZERO
var _held := true  # syöttäjä pitää palloa
var _last := -1  # viimeksi lyönyt
var _rally := 0
var _serve_ai_t := 0.0
var _ai_target := 2.6
var _ai_reaction := 0.0
var _ai_miss := false  # Santtu huitaisee tämän pallon ohi (päätetään kerran per pallo)
var _trail: Array[MeshInstance3D] = []
var _trail_i := 0

var _ball_node: MeshInstance3D
var _shadow: MeshInstance3D
var _cam: Camera3D
var _prev_cam: Camera3D
var _layer: CanvasLayer
var _stars: Array[Label] = []
var _round_label: Label
var _rally_label: Label
var _announce: Label
var _help: Label
var _effects: Array = []
var _shake := 0.0


func _ready() -> void:
	Touch.set_extra([[KEY_J, "Lyönti"], [KEY_K, "Smash"]])
	_build_stage()
	_pl.append(_make_player(Looks.PLAYER, -2.6, 1.0, true))
	_pl.append(_make_player(Mokki.SANTTU_LOOK, 2.6, -1.0, false))
	_ball_node = MeshInstance3D.new()
	_ball_node.mesh = B.sphere(R, 12)
	_ball_node.material_override = B.unshaded(Color(1.6, 1.25, 0.7))
	add_child(_ball_node)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = B.cyl(R * 1.3, R * 1.3, 0.002, 12)
	_shadow.material_override = B.unshaded(Color(0, 0, 0, 0.45))
	add_child(_shadow)
	for i in 6:
		var tr := MeshInstance3D.new()
		tr.mesh = B.sphere(R * (0.9 - i * 0.1), 8)
		tr.material_override = B.unshaded(Color(1.0, 0.75, 0.4, 0.35 - i * 0.05))
		tr.visible = false
		add_child(tr)
		_trail.append(tr)
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.position = Vector3(0, 1.9, 8.0)
	_cam.look_at(global_position + Vector3(0, 1.3, 0), Vector3.UP)
	_cam.current = true
	_build_hud()
	_start_round_intro()
	_say(1, SANTTU_INTRO.pick_random())


func _make_player(look: Dictionary, x: float, facing: float, cap: bool) -> Dictionary:
	var body := Looks.make(self, look)
	if cap:
		Looks.add_cap(body)
	body.rotation.y = B.yaw_to(Vector3(facing, 0, 0))
	body.play("Idle", 0.0)
	# Iso puumaila oikeaan käteen: vaneriläpä ja kahva.
	var paddle := Node3D.new()
	B.mesh(paddle, B.cyl(0.018, 0.018, 0.16, 6), Vector3(0, -0.08, 0), Color(0.5, 0.34, 0.18))
	B.mesh(paddle, B.cyl(PADDLE_R, PADDLE_R, 0.015, 20), Vector3(0, -0.16 - PADDLE_R, 0),
		Color(0.85, 0.72, 0.5) if facing > 0.0 else Color(0.2, 0.45, 0.75), Vector3(90, 0, 0))
	body.attach("hand_r", paddle, Vector3(0, -0.02, 0.02))
	var bubble := B.bubble(self, Vector3(x, 2.3, 0), Color.WHITE)
	return {"body": body, "x": x, "y": 0.0, "vy": 0.0, "facing": facing, "swing_t": -1.0, "kind": "", "aim": 0.0,
		"hit_done": false, "moving": false, "bubble": bubble, "say_t": 0.0}


# --- Kulku ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	match _phase:
		"intro":
			if _t > 1.3 and (_announce.text.begins_with("ROUND") or _announce.text.begins_with("FINAL")):
				_announce.text = "SERVE!"
				Sfx.play("alert", 0.0, 1.2)
			if _t > 2.0:
				_announce.text = ""
				_start_serve()
		"serve", "rally":
			_control_player(delta)
			_control_santtu(delta)
			if _phase == "rally":
				_step_ball(delta)
		"point":
			_step_ball(delta)
			if _t > 2.2:
				if _rounds.max() >= ROUNDS_TO_WIN:
					_end_game()
				else:
					_round += 1
					_start_round_intro()
		"over":
			if _t > 3.6:
				_phase = "done"
				if _prev_cam != null and is_instance_valid(_prev_cam):
					_prev_cam.current = true
				_layer.visible = false
				Touch.set_extra([])
				finished.emit(_rounds[0] > _rounds[1], _rounds[0], _rounds[1])
	for i in 2:
		_update_player(i, delta)
	if _held:
		var s: Dictionary = _pl[_server]
		_ball = Vector2(s.x + s.facing * 0.5, 1.5 + 0.1 * sin(_t * 5.0))
	_ball_node.position = Vector3(_ball.x, _ball.y, 0.15)
	_shadow.position = Vector3(_ball.x, 0.004, 0.15)
	_update_trail()
	_update_effects(delta)
	_update_camera(delta)


func _start_round_intro() -> void:
	_phase = "intro"
	_t = 0.0
	_announce.text = "ROUND %d" % _round if _round < 3 else "FINAL ROUND"
	_round_label.text = "ERÄ %d" % _round
	_rally_label.text = ""
	_held = true
	_last = -1
	_pl[0].x = -2.6
	_pl[1].x = 2.6
	_ai_target = 2.6
	for i in 2:
		(_pl[i].body as Node3D).play("Idle", 0.3)
	Sfx.play("alert", -2.0, 0.8)


func _start_serve() -> void:
	_phase = "serve"
	_t = 0.0
	_rally = 0
	_serve_ai_t = randf_range(0.9, 1.6)
	_help.text = _help_text() + ("\n[J] Syötä" if _server == 0 else "")


func _help_text() -> String:
	return "A/D liiku · W hyppy · J lyönti · K smash (korkeasta pallosta) · eteen/taakse + lyönti: pitkä/lyhyt · älä pudota palloa!"


func _end_game() -> void:
	_phase = "over"
	_t = 0.0
	var won: bool = _rounds[0] > _rounds[1]
	_announce.text = "SÄÄ VOITTI!" if won else "SANTTU VOITTI!"
	_say(1, (SANTTU_LOSE if won else SANTTU_WIN).pick_random())
	(_pl[0 if won else 1].body as Node3D).play("Dance", 0.3)
	(_pl[1 if won else 0].body as Node3D).play("Idle_Talking", 0.3)
	Sfx.play("win" if won else "lose", -4.0)
	_help.text = ""


# --- Ohjaus ---------------------------------------------------------------------------

func _control_player(delta: float) -> void:
	var p: Dictionary = _pl[0]
	var move := Input.get_axis("left", "right")
	p.x = clampf(p.x + move * WALK * delta, -X_MAX, -X_MIN)
	p.moving = absf(move) > 0.1
	if Input.is_action_just_pressed("forward") and p.y <= 0.0:
		p.vy = JUMP
	if p.swing_t < 0.0:
		var kind := ""
		if Input.is_action_just_pressed("punch"):
			kind = "normal"
		elif Input.is_action_just_pressed("kick"):
			kind = "smash"
		if kind != "":
			if _phase == "serve" and _server == 0 and _held:
				_serve(0)
			elif _phase == "rally":
				_swing(0, kind, move)


## Santtu: laskee, mihin pallo laskeutuu mailan korkeudelle, juoksee sinne ja lyö (joskus huitaisten ohi).
## Syöttää itse vuorollaan.
func _control_santtu(delta: float) -> void:
	var s: Dictionary = _pl[1]
	if _phase == "serve" and _server == 1 and _held:
		_serve_ai_t -= delta
		if _serve_ai_t <= 0.0:
			_serve(1)
		return
	if _phase == "rally" and _last == 0:
		_ai_reaction -= delta
		if _ai_reaction <= 0.0:
			_ai_reaction = 0.12
			_ai_target = _land_x(HIT_Y) + 0.45
	elif _last == 1 or _phase != "rally":
		_ai_target = lerpf(_ai_target, 2.6, delta)
	var dx: float = _ai_target - s.x
	var speed := WALK * 0.92
	s.x = clampf(s.x + clampf(dx, -speed * delta, speed * delta), X_MIN, X_MAX)
	s.moving = absf(dx) > 0.05
	if _phase == "rally" and _last == 0 and s.swing_t < 0.0:
		var d := _ball.distance_to(_paddle(1))
		if d < REACH * 0.9:
			if _ai_miss:
				s.swing_t = 0.0  # huitaisu ohi
				s.hit_done = true
				(s.body as Node3D).play("Punch_Jab", 0.05, 1.6)
				_ai_miss = false
			else:
				var smash := _ball.y > HIT_Y + 0.6 and randf() < 0.6
				_swing(1, "smash" if smash else "normal", randf_range(-1.0, 1.0))


## Pallon x, kun se laskeutuu korkeudelle y (laskevalla kaarella).
func _land_x(y: float) -> float:
	# by + vy t - G t² / 2 = y  ->  suurempi juuri
	var a := -0.5 * G
	var b := _vel.y
	var c := _ball.y - y
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return _ball.x
	var t := (-b - sqrt(disc)) / (2.0 * a)
	return _ball.x + _vel.x * maxf(t, 0.0)


func _paddle(i: int) -> Vector2:
	var p: Dictionary = _pl[i]
	return Vector2(p.x + p.facing * 0.45, HIT_Y + p.y)


func _swing(i: int, kind: String, aim: float) -> void:
	var p: Dictionary = _pl[i]
	p.swing_t = 0.0
	p.kind = kind
	p.aim = aim * p.facing  # eteen = +1 (pitkä), taakse = -1 (lyhyt)
	p.hit_done = false
	(p.body as Node3D).play("Punch_Cross" if kind == "smash" else "Punch_Jab", 0.05, 1.7)
	Sfx.play("whoosh", -10.0 if kind == "normal" else -4.0, 1.4 if kind == "normal" else 1.0)


func _serve(i: int) -> void:
	_held = false
	_phase = "rally"
	_t = 0.0
	var p: Dictionary = _pl[i]
	p.swing_t = SWING_FROM
	p.kind = "normal"
	p.hit_done = true
	(p.body as Node3D).play("Punch_Jab", 0.05, 1.7)
	_launch(i, randf_range(2.2, 3.4), 1.25, 0.05)
	_help.text = _help_text()


## Lyö pallon vastustajan puolelle etäisyydelle dist keskilinjasta, niin että se laskeutuu mailan korkeudelle
## ajassa flight; err heittää kohdetta ja kaarta.
func _launch(i: int, dist: float, flight: float, err: float) -> void:
	var dir: float = _pl[i].facing
	var target_x := dir * (dist + randf_range(-1.0, 1.0) * err * 2.5)
	_vel.x = (target_x - _ball.x) / flight
	_vel.y = (HIT_Y - _ball.y + 0.5 * G * flight * flight) / flight + randf_range(-1.0, 1.0) * err * 1.2
	_last = i
	_rally += 1
	# Santtu päättää heti, huitaiseeko ohi: pitkä ralli, smash ja pitkät juoksut lisäävät virheitä.
	if i == 0:
		var run := absf(target_x + 0.45 - _pl[1].x)
		_ai_miss = randf() < 0.05 + _rally * 0.012 + (0.25 if flight < 0.8 else 0.0) + maxf(0.0, run - 2.0) * 0.08
	_rally_label.text = "RALLI %d" % _rally if _rally >= 2 else ""
	Sfx.play("step_hard", -2.0, 2.0)


func _update_player(i: int, delta: float) -> void:
	var p: Dictionary = _pl[i]
	var body: Node3D = p.body
	p.vy -= G * 1.6 * delta
	p.y = maxf(0.0, p.y + p.vy * delta)
	if p.y <= 0.0:
		p.vy = 0.0
	body.position = Vector3(p.x, p.y, 0.0)
	(p.bubble as Label3D).position = Vector3(p.x, 2.3 + p.y, 0)
	if p.say_t > 0.0:
		p.say_t -= delta
		if p.say_t <= 0.0:
			(p.bubble as Label3D).text = ""
	if p.swing_t >= 0.0:
		p.swing_t += delta
		if not p.hit_done and p.swing_t >= SWING_FROM and p.swing_t <= SWING_TO and _phase == "rally":
			_try_hit(i)
		if p.swing_t > SWING_LEN:
			p.swing_t = -1.0
	elif _phase in ["serve", "rally"]:
		if p.y > 0.0:
			body.play("Jump", 0.1)
		elif p.moving:
			body.play("Walk", 0.15, 1.4)
		else:
			body.play("Idle", 0.2)


func _try_hit(i: int) -> void:
	var p: Dictionary = _pl[i]
	if _last == i:
		return  # oma lyönti: pallo on menossa vastustajalle
	var d := _ball.distance_to(_paddle(i))
	if d > REACH:
		return
	p.hit_done = true
	var q := d / REACH  # 0 = keskeltä mailaa, 1 = reunalta
	var dist: float = 2.9 + p.aim * 1.3
	# Pallo nopeutuu rallin pidetessä.
	var flight := maxf(0.75, 1.3 - _rally * 0.035)
	if p.kind == "smash":
		var high := _ball.y > HIT_Y + 0.5
		_launch(i, dist + 0.8, 0.5, (0.12 + q * 0.4) * (1.0 if high else 3.0))
		_effect("SMASH!", Vector3(_ball.x, _ball.y + 0.4, 0.3), Color(1.0, 0.45, 0.1), 1.3)
		Sfx.play("punch_heavy", -6.0, 1.5)
		_shake = 0.25
	else:
		_launch(i, dist, flight * randf_range(0.92, 1.05), 0.06 + q * q * 0.45)
		if randf() < 0.35:
			_effect(HIT_WORDS.pick_random(), Vector3(_ball.x, _ball.y + 0.35, 0.3), Color(1, 0.9, 0.3), 0.8)


# --- Pallo ja erät -------------------------------------------------------------------

func _step_ball(delta: float) -> void:
	_vel.y -= G * delta
	_ball += _vel * delta
	if _ball.y - R > 0.0:
		return
	# Maahan: pieni pomppu ja vieritys.
	_ball.y = R
	var first := absf(_vel.y) > 1.0
	_vel.y = -_vel.y * 0.35
	_vel.x *= 0.5
	if first:
		Sfx.play("step_grass", -2.0, 1.6)
	if _phase != "rally":
		return
	# Erän häviää se, jonka puolelle pallo putosi; ulos (kauas yli) tai omalle puolelle lyönyt häviää itse.
	var side := 0 if _ball.x < 0.0 else 1
	var why := "PUDOTUS!"
	var loser := side
	if absf(_ball.x) > X_MAX + 0.6 and side != _last:
		loser = _last
		why = "ULOS!"
	elif side == _last:
		why = "LYHYT!"
	_round_over(1 - loser, why)


func _round_over(winner: int, why: String) -> void:
	_rounds[winner] += 1
	_phase = "point"
	_t = 0.0
	_server = 1 - winner
	_stars[winner].text = "★".repeat(_rounds[winner])
	_effect(why, Vector3(_ball.x, 1.2, 0.3), Color(1.0, 0.5, 0.45), 1.2)
	_announce.text = "%s\n%s VOITTAA ERÄN" % [why, "SÄÄ" if winner == 0 else "SANTTU"]
	Sfx.play("punch_heavy", -4.0, 0.8)
	Sfx.play("win_small" if winner == 0 else "lose", -8.0)
	(_pl[winner].body as Node3D).play("Dance", 0.3)
	(_pl[1 - winner].body as Node3D).play("Idle_Talking", 0.3)
	_say(1, (SANTTU_ROUND_LOSE if winner == 0 else SANTTU_ROUND_WIN).pick_random())
	if _rally >= 8:
		_effect("%d LYÖNNIN RALLI!" % _rally, Vector3(0, 2.6, 0.3), Color(1.0, 0.8, 0.2), 1.2)


func _say(i: int, text: String) -> void:
	var p: Dictionary = _pl[i]
	(p.bubble as Label3D).text = text
	p.say_t = 2.4
	if i == 1:
		Sfx.babble(p.body, "kassa", text)


# --- Efektit ja kamera --------------------------------------------------------------------

func _update_trail() -> void:
	var fast := _vel.length() > 7.0 and not _held
	_trail_i = (_trail_i + 1) % 2
	if _trail_i == 0:
		for k in range(_trail.size() - 1, 0, -1):
			_trail[k].position = _trail[k - 1].position
			_trail[k].visible = _trail[k - 1].visible
		_trail[0].position = _ball_node.position
		_trail[0].visible = fast


func _effect(text: String, pos: Vector3, col: Color, size: float) -> void:
	var l := B.label(self, text, pos, int(80 * size), col, true)
	l.outline_size = 20
	_effects.append([l, 0.0])


func _update_effects(delta: float) -> void:
	for e in _effects.duplicate():
		var l: Label3D = e[0]
		e[1] += delta
		var t: float = e[1]
		l.position.y += delta * 1.0
		l.scale = Vector3.ONE * (1.0 + t * 1.2)
		l.modulate.a = 1.0 - t / 0.8
		l.outline_modulate.a = l.modulate.a
		if t > 0.8:
			l.queue_free()
			_effects.erase(e)


## Kamera sivulta kuten tappelussa: seuraa pelaajien väliä ja loitontaa, kun he ovat kaukana toisistaan.
func _update_camera(delta: float) -> void:
	var a: float = _pl[0].x
	var b: float = _pl[1].x
	var mid := (a + b) / 2.0
	var target := Vector3(mid, 2.0, 7.0 + clampf(b - a - 5.0, 0.0, 7.0) * 0.6)
	_cam.position = _cam.position.lerp(target, 1.0 - exp(-3.0 * delta))
	_shake = maxf(0.0, _shake - delta)
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.15
	_cam.position += off
	_cam.look_at(global_position + Vector3(_cam.position.x, 1.35, 0) + off, Vector3.UP)


# --- Näyttämö ja HUD ------------------------------------------------------------------------

## Mökin nurmi iltapäivällä: keskiraja köytenä maassa, mäntyjä, tumma pystylautamökki ja järvi taustalla.
func _build_stage() -> void:
	var grass := B.shader_mat("res://shaders/ground.gdshader", {
		"color_a": Color(0.3, 0.42, 0.18), "color_b": Color(0.45, 0.52, 0.26)})
	var lawn := B.box(self, Vector3(120, 0.2, 120), Vector3(0, -0.1, -30), Color.WHITE, false) as MeshInstance3D
	lawn.material_override = grass
	# Keskiraja: valkoinen köysi maassa ja reunatapit.
	B.box(self, Vector3(0.04, 0.02, 3.0), Vector3(0, 0.01, 0), Color(0.95, 0.95, 0.9), false)
	for sx in [-X_MAX - 0.6, X_MAX + 0.6]:
		B.mesh(self, B.cyl(0.03, 0.03, 0.35, 6), Vector3(sx, 0.17, -0.8), Color(0.9, 0.5, 0.1))
	# Mökki taustalla: tumma pystylauta, peltikatto ja ikkunat.
	var wall := Color(0.24, 0.15, 0.09)
	B.box(self, Vector3(9.4, 2.6, 5.0), Vector3(-3.0, 1.3, -12.0), wall, false)
	for i in 20:
		B.box(self, Vector3(0.03, 2.6, 0.02), Vector3(-7.5 + i * 0.47, 1.3, -9.49), wall.lightened(0.14), false)
	var roof := PrismMesh.new()
	roof.size = Vector3(6.0, 1.2, 10.4)
	B.mesh(self, roof, Vector3(-3.0, 3.2, -12.0), Color(0.2, 0.2, 0.22), Vector3(0, 90, 0))
	for wx in [-5.5, -2.0, 0.8]:
		B.box(self, Vector3(1.2, 1.0, 0.05), Vector3(wx, 1.5, -9.47), Color(0.75, 0.82, 0.85), false)
		B.box(self, Vector3(1.3, 1.1, 0.04), Vector3(wx, 1.5, -9.48), Color(0.94, 0.94, 0.9), false)
	# Järvi ja vastaranta.
	B.box(self, Vector3(120, 0.05, 30), Vector3(0, 0.02, -40), Color(0.25, 0.38, 0.45), false)
	for i in 30:
		var x := -40.0 + i * 2.8 + randf_range(-0.8, 0.8)
		var s := randf_range(0.8, 1.3)
		B.mesh(self, B.cyl(0.05, 0.12, 3.0 * s, 6), Vector3(x, 1.5 * s, -56), Color(0.35, 0.25, 0.16))
		B.mesh(self, B.cyl(0.02, 1.1 * s, 3.4 * s, 7), Vector3(x, 4.2 * s, -56), Color(0.14, 0.25, 0.13))
	# Männyt pihan reunoilla.
	for tp in [Vector2(-9.5, -5.0), Vector2(8.5, -6.0), Vector2(11.0, -2.5), Vector2(-12.0, -1.5), Vector2(4.5, -14.0)]:
		B.mesh(self, B.cyl(0.18, 0.28, 7.0, 8), Vector3(tp.x, 3.5, tp.y), Color(0.4, 0.27, 0.16))
		for k in 3:
			B.mesh(self, B.cyl(0.03, 1.4 - k * 0.3, 2.0, 8), Vector3(tp.x, 5.2 + k * 1.2, tp.y), Color(0.15, 0.27, 0.14))


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	for left in [true, false]:
		var l := _big_label(root, 30)
		l.text = "SÄÄ" if left else "SANTTU – pihapingismestari"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		l.anchor_left = 0.0 if left else 0.5
		l.anchor_right = 0.5 if left else 1.0
		l.offset_left = 34 if left else 90
		l.offset_right = -90 if left else -34
		l.offset_top = 20
		l.offset_bottom = 60
		# Erävoitot tähtinä nimen alla kuten Street Fighterissa.
		var st := _big_label(root, 34)
		st.add_theme_color_override("font_color", Color(1.0, 0.8, 0.1))
		st.horizontal_alignment = l.horizontal_alignment
		st.anchor_left = l.anchor_left
		st.anchor_right = l.anchor_right
		st.offset_left = l.offset_left
		st.offset_right = l.offset_right
		st.offset_top = 60
		st.offset_bottom = 100
		_stars.append(st)
	_round_label = _big_label(root, 40)
	_round_label.anchor_left = 0.5
	_round_label.anchor_right = 0.5
	_round_label.offset_left = -110
	_round_label.offset_right = 110
	_round_label.offset_top = 14
	_round_label.offset_bottom = 66
	_rally_label = _big_label(root, 26)
	_rally_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_rally_label.anchor_left = 0.5
	_rally_label.anchor_right = 0.5
	_rally_label.offset_left = -110
	_rally_label.offset_right = 110
	_rally_label.offset_top = 66
	_rally_label.offset_bottom = 100
	_announce = _big_label(root, 84)
	_announce.anchor_right = 1.0
	_announce.anchor_top = 0.35
	_announce.anchor_bottom = 0.35
	_announce.offset_top = -110
	_announce.offset_bottom = 110
	_announce.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	_announce.add_theme_color_override("font_outline_color", Color(0.5, 0.05, 0.0))
	_announce.add_theme_constant_override("outline_size", 20)
	_help = _big_label(root, 16)
	_help.anchor_right = 1.0
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_top = -64
	_help.offset_bottom = -12


func _big_label(root: Control, size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(6, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l
