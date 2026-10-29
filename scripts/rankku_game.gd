extends Node3D
## Rankkarit kentällä (#116), pelataan oikealla kentällä oikeaa maalia kohti: viisi laukausta ja viisi torjuntaa
## poikia vastaan vuorotellen. Laukaus: kamera matalalla pallon takana olan yli (kuten TV:n "potkijan takaa" -kuva) ja
## ajaa hitaasti eteenpäin tähdätessä; tähtäin heiluu maalin suulla, välilyönti lukitsee suunnan, sitten korkeuden ja
## lopuksi voiman (eFootballin tapaan: heikko on helppo torjua, liian kova yläkulmaan nousee yli). Potkun jälkeen
## kamera seuraa palloa. Poikien maalivahti heittäytyy. Torjunta minäkuvakulmasta maalivahdin silmistä: poika juoksee
## pilkulle, ja hetkeä ennen potkua lantio kertoo suunnan ja selkä korkeuden (useimmiten). A / D heittäytyy
## vasemmalle tai oikealle (W pohjassa yläkulmaan, muuten alakulmaan), S jää keskelle. Maaliverkko heilahtaa
## osumasta (build_net, shaders/goal_net.gdshader). Muut pojat katsovat rangaistusalueen reunalla. F / Esc luovuttaa.
## Solmun kehys = maali (world.kentta_goal / hongan_goal): origo maaliviivan keskellä, +Z kentälle päin, size =
## (leveys, korkeus, pilkun etäisyys). finished(oma, pojat).

signal finished(mine: int, theirs: int)

const MG := preload("res://scripts/mg_draw.gd")
const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const ROUNDS := 5
const BALL_R := 0.11
const KID_COLS := [Color(0.9, 0.2, 0.15), Color(0.15, 0.4, 0.85), Color(0.95, 0.8, 0.15)]
const TAUNTS := ["\"Ei se ees osaa potkasta!\"", "\"Mun mummo potkas kovempaa!\"", "\"Kato nyt, äijä on ihan punanen.\"",
	"\"Viimenen mahollisuus, setä!\""]

var drunk := 0.0
var quit := false  # luovutettu kesken (ei voittoa, vaikka olisi johdossa)
var size := Vector3(5.0, 2.0, 7.0)  # maalin leveys, korkeus ja pilkun etäisyys

var _hud: CanvasLayer
var _ui: Control
var _info: Label
var _tip: Label
var _keys: Control
var _round := 0  # 0..9: parilliset laukauksia, parittomat torjuntoja
var _mine := 0
var _theirs := 0
var _phase := "intro"  # intro / aim_x / aim_y / power / flight / runup / dive / result / done
var _t := 0.0
var _aim := Vector2(0.0, 0.5)  # -1..1 vaaka, 0..1 korkeus (0 = maa)
var _ball_from := Vector3.ZERO
var _ball_to := Vector3.ZERO
var _ball_u := 0.0
var _keeper_dive := 0  # -1 / 0 / 1 (maalivahdin heittäytyminen, pelaajan näkökulmasta vasen / keski / oikea)
var _keeper_u := 0.0
var _kick_dir := 0  # torjunnassa pallon suunta
var _tell := 0  # potkijan lantion suunta
var _goal := false
var _power := 0.5  # laukauksen voima 0..1 (voimapalkki)
var _over := false  # liian kova yläkulmaan: yli
var _kick_high := false  # torjunnassa pallo yläkulmaan
var _tell_high := false  # potkijan selkä kertoo korkeuden
var _keeper_high := false  # pelaaja heittäytyi yläkulmaan
var _gk_x := 0.0  # poikien maalivahdin sivuttaispaikka viivalla
var _gk_t := 0.0
var _nets: Array = []  # tämän maalin verkot (build_net)
var _net_age := 100.0
var _shake := 0.0
var _results: Array = []  # [oma laukaus/torjunta, maali]

var _cam: Camera3D
var _ball: Node3D
var _player: Node3D
var _kids: Array[Node3D] = []  # 0 = poikien maalivahti, 1–2 potkijat
var _confetti: CPUParticles3D
var _cam_from := Transform3D()


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	_build()
	_cam = Camera3D.new()
	_cam.fov = 42.0
	add_child(_cam)
	_cam.current = true
	_build_hud()
	_tip.text = "Pojat: \"Viis rankkaria kumpikin. Sää aloitat, setä.\""
	_stage()


# --- Rakennus ------------------------------------------------------------------

const NET_GROUP := "maaliverkko"
const NET_SHADER := "res://shaders/goal_net.gdshader"


## Maaliverkko tolppien taakse: takaseinä, katto ja kyljet läpinäkyvänä naruverkkona (world.gd kutsuu). z = maaliviiva,
## side = suunta, johon verkko jää (kentältä poispäin), w / h = maalin leveys ja korkeus, depth = verkon syvyys.
static func build_net(parent: Node3D, z: float, side: float, w: float, h: float, depth: float) -> void:
	var quad := func(sz: Vector2, orient: int, pos: Vector3, sub: Vector2i) -> void:
		var q := QuadMesh.new()
		q.size = sz
		q.orientation = orient
		q.subdivide_width = sub.x
		q.subdivide_depth = sub.y
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.position = pos
		mi.material_override = B.shader_mat(NET_SHADER, {"size": sz})
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_to_group(NET_GROUP)
		parent.add_child(mi)
	quad.call(Vector2(w, h), PlaneMesh.FACE_Z, Vector3(0, h / 2.0, z + side * depth), Vector2i(30, 12))
	quad.call(Vector2(w, depth), PlaneMesh.FACE_Y, Vector3(0, h, z + side * depth / 2.0), Vector2i(20, 6))
	for sx in [-1.0, 1.0]:
		quad.call(Vector2(depth, h), PlaneMesh.FACE_X, Vector3(sx * w / 2.0, h / 2.0, z + side * depth / 2.0), Vector2i(6, 10))


func _build() -> void:
	_ball = Node3D.new()
	add_child(_ball)
	B.mesh(_ball, B.sphere(BALL_R, 14), Vector3.ZERO, Color(0.97, 0.97, 0.97))
	# Mustat laikut: kuusi pientä kiekkoa pallon pinnalla.
	for d in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var p := B.mesh(_ball, B.cyl(0.045, 0.045, 0.012, 5), d * (BALL_R - 0.004), Color(0.08, 0.08, 0.08))
		if absf(d.y) < 0.5:
			p.rotation = Vector3(PI / 2.0, 0, 0) if absf(d.z) > 0.5 else Vector3(0, 0, PI / 2.0)
	_player = Looks.make(self, Looks.player())
	Looks.add_cap(_player)
	for i in 3:
		var kid := Looks.make(self, {"model": "male", "shirt": KID_COLS[i] if i > 0 else Color(0.2, 0.2, 0.22), "pants": Color(0.15, 0.15, 0.2),
			"shoes": Color(0.9, 0.9, 0.9), "hair": "Hair_Buzzed", "hair_color": Color(0.6, 0.45, 0.2).darkened(i * 0.2),
			"height": 1.45 + i * 0.05, "skin": Color(0.95, 0.8, 0.7)})
		kid.play("Idle", 0.0)
		_kids.append(kid)
	_confetti = CPUParticles3D.new()
	_confetti.emitting = false
	_confetti.one_shot = true
	_confetti.amount = 50
	_confetti.lifetime = 1.2
	_confetti.explosiveness = 0.95
	_confetti.direction = Vector3(0, 1, 0.3)
	_confetti.spread = 60.0
	_confetti.initial_velocity_min = 2.0
	_confetti.initial_velocity_max = 4.5
	_confetti.gravity = Vector3(0, -6, 0)
	var cm := BoxMesh.new()
	cm.size = Vector3(0.05, 0.05, 0.01)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.material = mat
	_confetti.mesh = cm
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.3))
	grad.set_color(1, Color(0.3, 0.9, 1.0))
	_confetti.color_initial_ramp = grad
	add_child(_confetti)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	_hud.add_child(_ui)
	_info = _label(26, 18.0, false)
	_tip = _label(24, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	_hud.add_child(_keys)


func _label(fs: int, y: float, bottom: bool) -> Label:
	return B.hud_label(_hud, fs, y, bottom)


# --- Peli ----------------------------------------------------------------------

func _shooting() -> bool:
	return _round % 2 == 0


## Tähtäys (-1..1, 0..1) maalin suun pisteeksi. Pelaaja katsoo maalia kohti (-Z), joten oikea = +X.
func _goal_point(a: Vector2) -> Vector3:
	return Vector3(a.x * size.x / 2.0, a.y * size.y, 0.05)


func _spot() -> Vector3:
	return Vector3(0, BALL_R + 0.03, size.z)


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	_ui.queue_redraw()
	if _phase != "done":
		if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
			quit = true
			_finish("Luovutit. Pojat: \"Setä lähti itkemään!\"")
		else:
			_tick(delta)
	_animate(delta)
	_info.text = "Rankkarit  %d – %d  ·  kierros %d/%d" % [_mine, _theirs, mini(int(_round / 2.0) + 1, ROUNDS), ROUNDS]
	_keys.set_text(("%s lukitse %s" % [Settings.cap("jump"), {"aim_x": "suunta", "aim_y": "korkeus", "power": "voima"}.get(_phase, "tähtäin")]) if _shooting() else
		("%s / %s heittäydy (pidä %s: yläkulmaan) · %s keskelle" % [Settings.cap("left"), Settings.cap("right"), Settings.cap("forward"),
			Settings.cap("back")]))
	_net_tick(delta)


func _tick(delta: float) -> void:
	var sp := Input.is_action_just_pressed("jump")
	match _phase:
		"intro":
			if _t > 1.6:
				_start_round()
		"aim_x":
			var spd := 1.6 + drunk * 1.2
			_aim.x = sin(_t * spd) * 1.25 + sin(_t * 7.0) * drunk * 0.15
			if sp:
				_phase = "aim_y"
				_t = 0.0
		"aim_y":
			_aim.y = 0.55 + sin(_t * 2.2) * 0.62
			if sp:
				_phase = "power"
				_t = 0.0
		"power":
			# Voimapalkki nousee ja laskee; humalassa se nykii.
			_power = clampf(0.5 - 0.5 * cos(_t * (4.2 + drunk * 1.5)) + sin(_t * 19.0) * drunk * 0.05, 0.0, 1.0)
			if sp:
				_kick()
		"strike":
			if _t >= STRIKE_TIME:
				_phase = "flight"
				_t = 0.0
				Sfx.play("punch", -4.0, 1.2)
		"flight":
			_ball_u = minf(1.0, _ball_u + delta * lerpf(1.3, 3.3, _power))
			_keeper_u = minf(1.0, _keeper_u + delta * 3.0)
			if _ball_u >= 1.0:
				_resolve()
		"runup":
			if _t > 1.1 and _tell == 2:
				_tell = _kick_dir if randf() < 0.75 else [-1, 0, 1].pick_random()
				_tell_high = _kick_high if randf() < 0.7 else randf() < 0.5
			if _t > 1.9:
				_phase = "dive"
				_t = 0.0
				_ball_u = 0.0
				_ball_from = _spot()
				_ball_to = Vector3(_kick_dir * size.x * 0.33, size.y * (randf_range(0.68, 0.8) if _kick_high and _kick_dir != 0 else
					randf_range(0.12, 0.3)), 0.05)
				_keeper_dive = 2  # ei vielä heittäytynyt
				Sfx.play("punch", -6.0, 1.3)
			var early := _dive_input()
			if early != 2:
				_tip.text = "Liian aikaisin! Potkija näki sen."
				_keeper_dive = early
				_keeper_u = 0.0
				_kick_dir = [-1, 0, 1].filter(func(d): return d != early).pick_random()
		"dive":
			_ball_u = minf(1.0, _ball_u + delta * 1.9)
			if _keeper_dive == 2:
				var d := _dive_input()
				if d != 2:
					_keeper_dive = d
					_keeper_u = 0.0
			if _keeper_dive != 2:
				_keeper_u = minf(1.0, _keeper_u + delta * 4.0)
			if _ball_u >= 1.0:
				_resolve()
		"result":
			if _t > 1.9:
				_round += 1
				if _round >= ROUNDS * 2 or _decided():
					var txt := "VOITIT %d – %d! Pojat: \"Ens kerralla, setä...\"" % [_mine, _theirs] if _mine > _theirs else \
						("Tasapeli %d – %d. Pojat: \"Ensi kerralla ratkastaan.\"" % [_mine, _theirs] if _mine == _theirs else
						"Hävisit %d – %d. Pojat nauraa koko matkan kotiin." % [_mine, _theirs])
					_finish(txt)
				else:
					_start_round()


## Heittäytymisnäppäin tällä ruudulla: -1 / 0 / 1 tai 2 (ei painettu). W pohjassa sivulle = yläkulma (_keeper_high).
func _dive_input() -> int:
	for k in [["left", -1], ["back", 0], ["right", 1]]:
		if Input.is_action_just_pressed(k[0]):
			_keeper_high = k[1] != 0 and Input.is_action_pressed("forward")
			return k[1]
	return 2


## Ratkesiko ennen viidettä kierrosta (toinen ei voi enää kiriä)?
func _decided() -> bool:
	var shots_left := ROUNDS - int((_round + 1) / 2.0)
	var saves_left := ROUNDS - int(_round / 2.0)
	return _mine > _theirs + saves_left or _theirs > _mine + shots_left


func _start_round() -> void:
	_t = 0.0
	_ball_u = 0.0
	_keeper_u = 0.0
	_goal = false
	if _shooting():
		_phase = "aim_x"
		_aim = Vector2(0.0, 0.5)
		_keeper_dive = 0
		_tip.text = "Sinun laukauksesi. Kulmaan, mutta ei ohi. Voimaa sopivasti."
		_power = 0.5
		_over = false
	else:
		_phase = "runup"
		_kick_dir = [-1, 0, 1].pick_random()
		_kick_high = randf() < 0.45
		_keeper_high = false
		_tell = 2
		_keeper_dive = 2
		_tip.text = "Sinä maalissa. Lantio kertoo suunnan, selkä korkeuden..."
	_stage()


## Hahmot paikoilleen kierroksen alussa: laukauksessa pelaaja pallon takana ja poika maalissa, torjunnassa toisin päin.
func _stage() -> void:
	for c in [_player] + _kids:
		c.clear_ik()
		c.rotation = Vector3.ZERO
		c.play("Idle", 0.2)
	var shooter: Node3D = _kids[1 + int(_round / 2.0) % 2]
	var watcher: Node3D = _kids[2 - int(_round / 2.0) % 2]
	if _shooting():
		_kids[0].visible = true
		_kids[0].position = Vector3(0, 0.03, 0.4)
		_kids[0].rotation.y = PI  # kasvot kentälle
		_player.position = _spot() + WAIT_POS  # odottaa viistosti takana, ei peitä maalia
		_player.rotation.y = atan2(WAIT_POS.x, WAIT_POS.z)
		shooter.position = Vector3(-size.x * 0.9 - 1.5, 0.03, size.z + 1.0)
		shooter.rotation.y = -PI / 2.0
		watcher.position = Vector3(size.x * 0.9 + 1.5, 0.03, size.z + 2.0)
		watcher.rotation.y = PI / 2.0
	else:
		_kids[0].visible = false
		_player.position = Vector3(0, 0.03, 0.4)
		_player.rotation.y = PI
		shooter.position = _spot() + Vector3(-1.4, -BALL_R - 0.03, 2.4)
		shooter.rotation.y = 0.0
		watcher.position = Vector3(size.x * 0.9 + 1.5, 0.03, size.z + 1.0)
		watcher.rotation.y = PI / 2.0
	_ball.position = _spot()


## Potkijan paikat pallon suhteen: odotus viistosti takana oikealla, potku pallon vieressä (vauhdinotto välissä).
const WAIT_POS := Vector3(1.3, -BALL_R - 0.03, 2.0)
const KICK_POS := Vector3(0.25, -BALL_R - 0.03, 0.75)
const STRIKE_TIME := 0.38


func _kick() -> void:
	_phase = "strike"
	_t = 0.0
	_t = 0.0
	_ball_u = 0.0
	_ball_from = _spot()
	_ball_to = _goal_point(_aim)
	_over = _power > 0.88 and _aim.y > 0.55  # liian kova yläkulmaan nousee riman yli
	if _over:
		_ball_to.y = size.y + 0.4 + (_power - 0.88) * 4.0
	# Maalivahti arvaa: kulmiin tähdätty jää useammin kiinni ottamatta.
	var guess: int = [-1, 0, 1].pick_random()
	if randf() < 0.35:
		guess = signi(roundi(_aim.x * 1.4))
	_keeper_dive = guess
	_keeper_u = 0.0


func _resolve() -> void:
	_phase = "result"
	_t = 0.0
	if _shooting():
		var wide := absf(_aim.x) > 1.0 or _aim.y > 1.0 or _aim.y < 0.0 or _over
		var zone := 0 if absf(_aim.x) < 0.35 else signi(roundi(_aim.x * 10))
		var reach := 0.9 if zone == _keeper_dive else 0.0
		if zone == _keeper_dive and absf(_aim.x) > 0.75:
			reach = 0.35  # aivan kulmassa sormenpäät ei riitä
		reach = clampf(reach * lerpf(1.5, 0.65, _power), 0.0, 1.0)  # heikko laukaus ehtii kiinni, kova lipsahtaa läpi
		if _power < 0.25 and zone != _keeper_dive and absf(_aim.x) < 0.6:
			reach = 0.6  # rullaava pallo: maalivahti ehtii jaloillaan
		if wide:
			_goal = false
			if _over:
				_tip.text = ["YLI! Liian lujaa, pallo lensi riman yli.", "Taivaalle! Pojat: \"Rugbya, setä?\""].pick_random()
			else:
				_tip.text = ["OHI! Pallo lensi aidan yli.", "Tolppaan ja ulos! KLONK."][int(absf(_aim.x) < 1.08)]
			Sfx.play("punch_heavy", -6.0, 1.4)
		elif randf() < reach:
			_goal = false
			_tip.text = "TORJUTTU! " + TAUNTS.pick_random()
			Sfx.play("whoosh", -4.0)
		else:
			_goal = true
			_mine += 1
			_shake = 0.6
			_confetti.position = _ball_to
			_confetti.restart()
			_net_hit(_ball_to)
			_tip.text = ["MAALI!", "MAALI! Suoraan yläkulmaan!", "MAALI! Maalivahti meni väärään suuntaan."][randi() % 3]
			Sfx.play("win_small", -4.0)
	else:
		var saved := _keeper_dive == _kick_dir and (_kick_dir == 0 or _keeper_high == _kick_high)
		if saved:
			_goal = false
			_shake = 0.5
			_tip.text = ["TORJUIT! Pojat on hiljaa.", "TORJUNTA! Nyrkillä pois!", "Sormenpäillä! Ei mene!"][randi() % 3]
			Sfx.play("win_small", -4.0)
		else:
			_goal = true
			_theirs += 1
			_tip.text = ("Maali. Oikea suunta, mutta väärä korkeus! " if _keeper_dive == _kick_dir and _kick_dir != 0 else "Maali. ") + TAUNTS.pick_random()
			_net_hit(Vector3(-_ball_to.x, _ball_to.y, _ball_to.z))
			Sfx.play("punch", -6.0, 0.9)
	_results.append([_shooting(), _goal])


func _finish(text: String) -> void:
	_phase = "done"
	_tip.text = text
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		finished.emit(_mine, _theirs)
		queue_free())


# --- Animaatio ja kamera -------------------------------------------------------

func _animate(delta: float) -> void:
	var t := _t
	if _shooting():
		_animate_shot(t)
	else:
		_animate_save(t)
	_place_camera(delta)


## Pallo lentää kaaressa ja pyörii; torjuttu pallo kimpoaa takaisin kentälle, ohi mennyt jatkaa yli.
func _ball_pos(u: float) -> Vector3:
	var p := _ball_from.lerp(_ball_to, u)
	p.y += sin(u * PI) * 0.25
	return p


func _animate_shot(t: float) -> void:
	# Pelaaja: potkujalka heilahtaa taakse lukitessa ja läpi potkussa.
	var swing := 0.0  # -1 taakse .. 1 läpi
	# Vauhdinotto: odotuspaikalta pallolle, viimeisellä askeleella jalka taakse ja läpi.
	var run := 0.0 if _phase in ["intro", "aim_x", "aim_y", "power"] else (clampf(t / STRIKE_TIME, 0.0, 1.0) if _phase == "strike" else 1.0)
	_player.position = _spot() + WAIT_POS.lerp(KICK_POS, run)
	_player.rotation.y = lerp_angle(atan2(WAIT_POS.x, WAIT_POS.z), 0.0, run)
	_player.play("Jog_Fwd" if _phase == "strike" and run < 0.75 else "Idle", 0.1)
	if _phase == "strike":
		swing = -clampf((run - 0.55) / 0.3, 0.0, 1.0)
	elif _phase == "flight" or (_phase == "result" and t < 0.4):
		swing = 1.0
	var inv: Transform3D = _player.transform.affine_inverse()
	var hip := _player.position + Vector3(-0.1, 0.9, 0)
	var foot := _player.position + Vector3(-0.12, 0.12 + maxf(swing, 0.0) * 0.35 + maxf(-swing, 0.0) * 0.25,
		-0.05 - swing * 0.55)
	_player.set_ik("leg_r", "thigh_r", "calf_r", "foot_r", inv * foot, inv * (hip + Vector3(0, -0.3, -1.0)))
	_player.set_override("spine_01", Vector3.RIGHT, -0.15 - maxf(-swing, 0.0) * 0.15)
	# Pallo.
	if _phase in ["flight", "result"]:
		var u := _ball_u
		if _phase == "result":
			u = 1.0
		_ball.position = _ball_pos(u)
		if _phase == "result" and not _goal:
			var away := Vector3(_ball_to.x * 0.3, 0.0, 1.0) if absf(_aim.x) <= 1.0 and _aim.y <= 1.0 else Vector3(-signf(_aim.x), 0.3, -1.0)
			_ball.position = _ball_to + away * minf(t, 0.8) * 4.0
			_ball.position.y = maxf(BALL_R, _ball.position.y + sin(minf(t, 0.8) / 0.8 * PI) * 0.8)
		elif _phase == "result":
			_ball.position = _ball_to + Vector3(0, -minf(t, 0.5) * 1.5, -minf(t, 0.3) * 1.5)  # verkkoon
			_ball.position.y = maxf(BALL_R, _ball.position.y)
		_ball.rotation.x -= 0.4
	else:
		_ball.position = _spot()
	# Poikien maalivahti: ennen potkua viivalla kädet levällään, hytkyy päkiöillä ja liikkuu sivuttain häiritäkseen
	# potkijaa; vauhdinotossa asettuu ja ponnistaa pienesti juuri ennen osumaa (split step); sitten heittäytyy.
	var k0: Node3D = _kids[0]
	var waiting := _phase in ["intro", "aim_x", "aim_y", "power", "strike"]
	if waiting:
		var settle := clampf(t / STRIKE_TIME, 0.0, 1.0) if _phase == "strike" else 0.0
		if _phase != "strike":
			_gk_x = sin(_gk_t * 1.4) * 0.45 + sin(_gk_t * 3.1) * 0.12
		_gk_t += get_process_delta_time()
		var bounce := absf(sin(_gk_t * 6.0)) * 0.05 * (1.0 - settle)
		var hop := sin(clampf((settle - 0.6) / 0.4, 0.0, 1.0) * PI) * 0.12  # split step
		k0.position = Vector3(_gk_x, 0.03 - 0.13 + bounce + hop, 0.4)  # polvet koukussa (jalat IK:lla maassa)
		k0.rotation = Vector3(0, PI, 0)
		k0.play("Idle", 0.2)
		k0.set_override("spine_01", Vector3.RIGHT, -0.25)  # kumarassa, paino eteenpäin
		var inv0: Transform3D = k0.transform.affine_inverse()
		var wave := sin(_gk_t * 4.0) * 0.12 * (1.0 - settle)
		for side in [["_l", 1.0], ["_r", -1.0]]:  # kentälle päin katsovan vasen = +X
			var hand := k0.position + Vector3(side[1] * 0.62, 0.95 + wave * side[1], 0.28)
			k0.set_ik("arm" + side[0], "upperarm" + side[0], "lowerarm" + side[0], "hand" + side[0], inv0 * hand,
				inv0 * (hand + Vector3(side[1] * 0.2, -0.6, 0.3)))
			var gk_foot := Vector3(_gk_x + side[1] * 0.24, 0.07 + hop, 0.45)
			k0.set_ik("leg" + side[0], "thigh" + side[0], "calf" + side[0], "foot" + side[0], inv0 * gk_foot,
				inv0 * (gk_foot + Vector3(side[1] * 0.15, 0.5, 0.7)))
	else:
		k0.set_override("spine_01", Vector3.RIGHT, 0.0)
		_dive(k0, _keeper_dive, _keeper_u, Vector3(_gk_x, 0.03, 0.4), PI)


func _animate_save(t: float) -> void:
	var shooter: Node3D = _kids[1 + int(_round / 2.0) % 2]
	var spot := _spot()
	if _phase == "runup":
		var run := clampf(t / 1.9, 0.0, 1.0)
		var start := spot + Vector3(-1.4, -BALL_R - 0.03, 2.4)
		var end := spot + Vector3(-0.35, -BALL_R - 0.03, 0.45)
		shooter.position = start.lerp(end, run)
		shooter.play("Jog_Fwd" if run < 0.95 else "Idle", 0.15)
		var face := atan2(-(end.x - start.x), -(end.z - start.z))
		var lean := 0.0 if _tell == 2 else float(_tell)
		# Lantio kääntyy potkusuuntaan (pelaajan näkökulmasta vasen = +X, koska pelaaja katsoo kentälle).
		shooter.rotation.y = face + lean * 0.5 * clampf((t - 1.1) * 3.0, 0.0, 1.0)
		shooter.set_override("spine_01", Vector3.UP, -lean * 0.4 * clampf((t - 1.1) * 3.0, 0.0, 1.0))
		# Yläkulmaan potkaiseva nojaa taaksepäin (selkä kertoo korkeuden).
		shooter.set_override("spine_03", Vector3.RIGHT, (0.3 if _tell_high and _tell != 2 else -0.1) * clampf((t - 1.1) * 3.0, 0.0, 1.0))
		_ball.position = spot
	elif _phase in ["dive", "result"]:
		var u := 1.0 if _phase == "result" else _ball_u
		var target := Vector3(-_ball_to.x, _ball_to.y, _ball_to.z)  # pelaajan vasen = +X
		_ball.position = spot.lerp(target, u) + Vector3(0, sin(u * PI) * 0.2, 0)
		if _phase == "result" and not _goal:
			_ball.position = target + Vector3(0, 0, minf(t, 0.8) * 5.0)
			_ball.position.y = maxf(BALL_R, _ball.position.y + sin(minf(t, 0.8) / 0.8 * PI) * 0.6)
		elif _phase == "result":
			_ball.position = target + Vector3(0, 0, -minf(t, 0.3) * 1.5)
			_ball.position.y = maxf(BALL_R, _ball.position.y - minf(t, 0.5) * 1.5)
		_ball.rotation.x += 0.4
		shooter.set_override("spine_01", Vector3.UP, 0.0)
		shooter.set_override("spine_03", Vector3.RIGHT, 0.0)
	var d := 0 if _keeper_dive == 2 else _keeper_dive
	_dive(_player, -d, _keeper_u if _keeper_dive != 2 else 0.0, Vector3(0, 0.03, 0.4), PI, 1 if _keeper_high else (0 if d == 0 else -1))
	if _keeper_dive == 2 or _keeper_u < 0.05:
		# Valmiusasento: kädet edessä kämmenet kentälle päin (näkyvät minäkuvakulmassa).
		var inv: Transform3D = _player.transform.affine_inverse()
		for side in [["_l", 1.0], ["_r", -1.0]]:  # kentälle päin katsovan vasen = +X
			var hand := _player.position + Vector3(side[1] * 0.3, 1.42, 0.62)
			_player.set_ik("arm" + side[0], "upperarm" + side[0], "lowerarm" + side[0], "hand" + side[0], inv * hand,
				inv * (hand + Vector3(side[1] * 0.4, -0.5, -0.3)))


## Maalivahdin heittäytyminen: sivulle liuku, nousu ja kallistus kyljelleen, kädet ojennettuina heittäytymissuuntaan.
## dir maailman X-suunnassa (+1 = +X). height: 1 yläkulma, -1 alakulma, 0 tavallinen (poikien maalivahti, keskelle).
func _dive(k: Node3D, dir: int, u: float, base: Vector3, yaw: float, height := 0) -> void:
	var x := float(dir) * u * size.x * 0.32
	var up := sin(u * PI) * (0.35 if dir != 0 else 0.5) * (1.6 if height > 0 else (0.4 if height < 0 else 1.0))
	k.position = base + Vector3(x, up, 0)
	k.rotation = Vector3(0, yaw, -float(dir) * u * 1.15 * (-1.0 if yaw > 1.0 else 1.0))
	if u > 0.05:
		k.play("Jump", 0.1)
		var inv: Transform3D = k.transform.affine_inverse()
		for side in [["_l", 1.0], ["_r", -1.0]]:  # kentälle päin katsovan vasen = +X
			var hand := k.position + Vector3(float(dir) * 0.9 + side[1] * 0.2, 1.7 if dir == 0 else (1.75 if height > 0 else (0.55 if height < 0 else 1.2)), 0)
			k.set_ik("arm" + side[0], "upperarm" + side[0], "lowerarm" + side[0], "hand" + side[0], inv * hand,
				inv * (hand + Vector3(0, -0.5, 0.5)))
	else:
		k.clear_ik()


## Kamera: laukauksessa matalalla pallon takana olan yli, ajaa tähdätessä hitaasti eteenpäin ja potkun jälkeen
## seuraa palloa. Torjunnassa maalivahdin silmistä (oma pää piilossa), heittäytyessä kamera lähtee mukaan ja kallistuu.
func _place_camera(delta: float) -> void:
	var from: Vector3
	var at: Vector3
	var roll := 0.0
	var hi: int = _player.skeleton.find_bone("Head")
	if _shooting():
		var push := 1.0 if _phase not in ["intro", "aim_x", "aim_y", "power", "strike"] else clampf(_t / 3.0, 0.0, 1.0)
		if _phase == "strike":
			push = 1.0
		if _phase == "aim_x":
			push *= 0.5
		from = _spot() + Vector3(-0.95, 1.35, lerpf(3.9, 3.1, push))
		at = Vector3(0.1, size.y * 0.42, 0)
		if _phase in ["flight", "result"]:
			var f := clampf(_ball_u if _phase == "flight" else 1.0, 0.0, 1.0)
			from = from.lerp(_spot() + Vector3(-1.1, 1.3, 0.7), f * 0.75)  # pelaajan vasemmalta ohi, ei olan läpi
			at = at.lerp(_ball.position, 0.35)
		_cam.fov = 40.0
		if hi >= 0:
			_player.skeleton.set_bone_pose_scale(hi, Vector3.ONE)
	else:
		var d := 0 if _keeper_dive == 2 else -_keeper_dive
		var u := _keeper_u if _keeper_dive != 2 else 0.0
		var drop := (0.2 if _keeper_high else (0.95 if d != 0 else 0.6)) * sin(minf(u, 1.0) * PI * 0.5)
		from = Vector3(float(d) * u * size.x * 0.32, 1.62 - drop + (0.3 * u if _keeper_high else 0.0), 0.55)
		at = _spot() + Vector3(from.x * 0.6, 0.35, 0)
		roll = -float(d) * u * 0.4
		_cam.fov = 70.0
		if hi >= 0:
			_player.skeleton.set_bone_pose_scale(hi, Vector3.ONE * 0.01)  # pää ei peitä kameraa
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.05
	var want := Transform3D(Basis(), from).looking_at(at, Vector3.UP)
	want.basis = want.basis * Basis(Vector3.BACK, roll)
	_cam_from = want if _phase == "intro" or _cam_from == Transform3D() else _cam_from.interpolate_with(want, 1.0 - exp(-6.0 * delta))
	_cam.transform = _cam_from
	_cam.position += sh


# --- HUD -----------------------------------------------------------------------

func _draw_ui() -> void:
	var sz := _ui.size
	var font := ThemeDB.fallback_font
	# Tähtäin maalin suulla (3D-piste ruudulle).
	if _phase in ["aim_x", "aim_y", "power"]:
		var ap3 := to_global(_goal_point(Vector2(_aim.x, _aim.y if _phase != "aim_x" else 0.5)))
		if not _cam.is_position_behind(ap3):
			var ap := _cam.unproject_position(ap3)
			var col := Color(1.0, 0.3, 0.2) if absf(_aim.x) > 1.0 or _aim.y > 1.0 or _aim.y < 0.0 else Color(1.0, 0.95, 0.3)
			_ui.draw_arc(ap, 18.0, 0, TAU, 24, Color(0, 0, 0, 0.6), 7.0)
			_ui.draw_arc(ap, 18.0, 0, TAU, 24, col, 4.0)
			_ui.draw_line(ap - Vector2(26, 0), ap + Vector2(26, 0), col, 2.0)
			_ui.draw_line(ap - Vector2(0, 26), ap + Vector2(0, 26), col, 2.0)
	# Voimapalkki tähtäimen vieressä: vihreä alue sopiva, punainen yläpää nousee yläkulmasta yli.
	if _phase == "power":
		var ap3 := to_global(_goal_point(_aim))
		if not _cam.is_position_behind(ap3):
			var ap := _cam.unproject_position(ap3) + Vector2(44, -60)
			var bar := Rect2(ap, Vector2(18, 120))
			MG.box(_ui, bar.grow(4), Color(0, 0, 0, 0.6), 4)
			_ui.draw_rect(Rect2(bar.position + Vector2(0, bar.size.y * 0.12), Vector2(bar.size.x, bar.size.y * 0.33)), Color(0.25, 0.75, 0.3, 0.6))
			_ui.draw_rect(Rect2(bar.position, Vector2(bar.size.x, bar.size.y * 0.12)), Color(0.85, 0.2, 0.15, 0.7))
			var fill := Rect2(Vector2(bar.position.x, bar.end.y - bar.size.y * _power), Vector2(bar.size.x, bar.size.y * _power))
			_ui.draw_rect(fill, Color(1.0, 0.95, 0.4, 0.85))
			_ui.draw_rect(bar, Color(1, 1, 1, 0.8), false, 2.0)
	# Tulostaulu.
	var board := Rect2(Vector2(sz.x - 300, 70), Vector2(270, 96))
	MG.box(_ui, board, Color(0.08, 0.08, 0.1, 0.9), 8, 6, Color(0.6, 0.6, 0.6), 2)
	_ui.draw_string(font, board.position + Vector2(14, 34), "SINÄ", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.3))
	_ui.draw_string(font, board.position + Vector2(14, 76), "POJAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.3))
	var mi := 0
	var ti := 0
	for r in _results:
		var col := mi if r[0] else ti
		if r[0]:
			mi += 1
		else:
			ti += 1
		var good: bool = r[1] if r[0] else not r[1]  # oma maali tai oma torjunta
		_ui.draw_circle(board.position + Vector2(110 + col * 30, 26.0 if r[0] else 68.0), 10.0,
			Color(0.3, 0.9, 0.3) if good else Color(0.9, 0.25, 0.2))


## Verkko heilahtaa: osumakohta (pelin kehyksessä) lähimmälle verkon pinnalle, aalto leviää (goal_net.gdshader).
func _net_hit(at: Vector3) -> void:
	_net_age = 0.0
	for n in _nets:
		var mi := n as MeshInstance3D
		(mi.material_override as ShaderMaterial).set_shader_parameter("hit_local", mi.to_local(to_global(at)))


func _net_tick(delta: float) -> void:
	if _nets.is_empty() and _t > 0.0:  # haetaan vasta, kun peli on siirretty maalin kohdalle
		for n in get_tree().get_nodes_in_group(NET_GROUP):
			if (n as Node3D).global_position.distance_to(global_position) < 4.0:
				_nets.append(n)
	if _net_age > 2.0:
		return
	_net_age += delta
	for n in _nets:
		((n as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("hit_age", _net_age)
