extends "res://scripts/kota_minigame.gd"
## Ampiaispesän hävitys (Santun homma), FPS-minipeli saunan terassin kulmalla. Pidä vasen nappi (tai E)
## pohjassa ja suihkuta myrkkyä pesän suuaukkoon: pesä kestää PESA_DOSE sekuntia osumaa. Suihkutus suututtaa
## ampiaiset, ne parveilevat ja pistävät (tähtäys heittää). Kolmas pisto: paniikki ja juoksu järveen. Purkissa
## on myrkkyä CAN_S sekuntia. Santtu katsoo turvallisen matkan päästä ja neuvoo.
## mokki.gd:n lapsi: origo = seisomapaikka (Mokki.WASP_STAND_LOCAL) maan tasalla.

const EYE := Vector3(0.0, 1.62, 0.0)
const PESA_DOSE := 3.2
const CAN_S := 7.0
const HIT_R := 0.11  # suihku osuu suuaukkoon tätä lähempää
const STINGS_MAX := 3
const WASPS := 16

const LINES := {
	"start": [["santtu", "Rauhallisesti. Ne haistaa pelon."], ["santtu", "Mää kattelen tästä vähän kauempaa."],
		["santtu", "Suihkuta suoraan suuaukkoon, alhaalta."]],
	"hit": [["santtu", "Noin! Suoraan pesään!"], ["santtu", "Lisää, lisää!"]],
	"miss": [["santtu", "Ohi! Suuaukko on alhaalla!"], ["santtu", "Sää suihkutat kattoa."]],
	"angry": [["santtu", "Ne on vihasia, kato taaksesi!"], ["santtu", "Älä huido, ne suuttuu!"], ["santtu", "Mää en tuu yhtään lähemmäs."]],
	"sting": [["santtu", "Pisti! Ei se mitään, kylmää päälle."], ["santtu", "Ai ai. Älä huuda, ne kuulee."]],
	"empty": [["santtu", "Purkki tyhjä! Toinen on saunan penkillä."]],
	"done": [["santtu", "Pesä alas! Nyt voi saunoa ilman pistoja."]],
	"panic": [["santtu", "JÄRVEEN! Juokse järveen!"]],
	"gust": [["santtu", "Tuuli kääntää suihkun! Odota."]],
	"idle": [["santtu", "Ei ne lähe katsomalla."], ["santtu", "Suihkuta jo!"]],
}

## Lopputulos: "ok" (pesä tuhottu), "pako" (paniikki järveen), "tyhja" (myrkky loppui), "" (lopetti itse).
var result := ""
var stings := 0
var drunk := 0.0
## Pesä (mokki.gd wasp_nest) pelin kehyksessä.
var nest_local := Vector3(1.8, 1.95, 1.2)

var _dose := 0.0
var _can := CAN_S
var _anger := 0.0
var _wasps: Array[Node3D] = []
var _spray: CPUParticles3D
var _canm: Node3D
var _buzz: AudioStreamPlayer3D
var _hiss: AudioStreamPlayer3D
var _sting_cd := 1.5
var _angry_said := 0.0
var _hit_said := 0.0
var _end_t := -1.0
var _flash: ColorRect
var _idle_t := 0.0
var _nest_vis: Node3D


func _init() -> void:
	eye = EYE
	lines = LINES
	watcher_spots = {"santtu": Vector3(0.6, 0, -2.8)}
	help_text = "Hiiri tähtää · Pidä vasen nappi / E pohjassa: suihkuta myrkkyä · F: lopeta"


func _start() -> void:
	var aim := _aim_to(nest_local + Vector3(0, -0.2, 0))
	yaw_center = aim.x
	_yaw = aim.x
	_pitch = aim.y
	pitch_max = 1.1
	watch_at = nest_local
	# Peli on terassin tasossa: Santtu seisoo maassa.
	var santtu: Node3D = _watcher("santtu")
	santtu.position.y = kota.h(santtu.position.x, santtu.position.z)
	_nest_vis = Node3D.new()
	_nest_vis.position = nest_local
	add_child(_nest_vis)
	for k in WASPS:
		var w := Node3D.new()
		add_child(w)
		B.mesh(w, B.sphere(0.012, 6), Vector3.ZERO, Color(0.95, 0.75, 0.05))
		B.mesh(w, B.sphere(0.009, 6), Vector3(0, 0, 0.016), Color(0.05, 0.05, 0.05))
		var wing := B.mesh(w, B.boxm(Vector3(0.03, 0.002, 0.012)), Vector3(0, 0.01, 0), Color.WHITE)
		wing.material_override = B.unshaded(Color(1, 1, 1, 0.5))
		_wasps.append(w)
	_canm = Node3D.new()
	_cam.add_child(_canm)
	_canm.position = Vector3(0.2, -0.18, -0.4)
	B.mesh(_canm, B.cyl(0.03, 0.03, 0.17, 10), Vector3.ZERO, Color(0.85, 0.85, 0.1))
	B.mesh(_canm, B.cyl(0.02, 0.025, 0.03, 8), Vector3(0, 0.1, 0), Color(0.9, 0.1, 0.1))
	_spray = CPUParticles3D.new()
	_spray.position = Vector3(0, 0.11, -0.02)
	_spray.emitting = false
	_spray.amount = 60
	_spray.lifetime = 0.5
	_spray.local_coords = false
	_spray.direction = Vector3(0, 0.2, -1)
	_spray.spread = 6.0
	_spray.initial_velocity_min = 4.0
	_spray.initial_velocity_max = 5.0
	_spray.gravity = Vector3(0, -1.5, 0)
	var mist := SphereMesh.new()
	mist.radius = 0.02
	mist.height = 0.04
	mist.material = B.unshaded(Color(0.9, 0.95, 1.0, 0.35))
	_spray.mesh = mist
	_canm.add_child(_spray)
	_buzz = Sfx.loop_on(self, "tractor_engine", -40.0)
	if _buzz != null:
		_buzz.position = nest_local
		_buzz.pitch_scale = 3.2
	_hiss = Sfx.loop_on(_canm, "wind", -40.0)
	if _hiss != null:
		_hiss.pitch_scale = 2.5
	_flash = ColorRect.new()
	_flash.color = Color(0.95, 0.85, 0.1, 0.0)
	_flash.anchor_right = 1.0
	_flash.anchor_bottom = 1.0
	_layer.add_child(_flash)
	_say_kind("start")


func _spraying() -> bool:
	return (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("interact")) and _can > 0.0 \
		and _end_t < 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _tick(delta: float) -> void:
	_angry_said -= delta
	_hit_said -= delta
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.5)
	if _end_t >= 0.0:
		_end_t += delta
		_spray.emitting = false
		if result == "pako":
			eye = eye.lerp(Vector3(-2.0, 1.4, -8.0), delta * 1.5)
			_yaw = lerpf(_yaw, PI, delta * 3.0)
			_shake = 0.5
		if _end_t > (2.6 if result == "pako" else 2.0):
			_quit()
		_animate_wasps(delta)
		return
	var on := _spraying()
	_spray.emitting = on
	if _hiss != null:
		_hiss.volume_db = -6.0 if on else -40.0
	if on:
		_idle_t = 0.0
		_can -= delta
		_anger = minf(1.0, _anger + delta * 0.32)
		# Osuuko suihku suuaukkoon (pesän alaosa): säteen etäisyys aukosta.
		var o := _cam.transform.origin
		var d := -_cam.transform.basis.z
		var mouth := nest_local + Vector3(0, -0.27, 0)
		var v := mouth - o
		var miss := (v - d * v.dot(d)).length()
		if miss < HIT_R:
			_dose += delta
			if _hit_said <= 0.0:
				_hit_said = 5.0
				_say_kind("hit")
			if _dose >= PESA_DOSE:
				_kill_nest()
				return
		elif _hit_said <= 0.0:
			_hit_said = 4.0
			_say_kind("miss")
		if _can <= 0.0:
			result = "tyhja"
			_end_t = 0.0
			_say_kind("empty")
			return
	else:
		_anger = maxf(0.0, _anger - delta * 0.06)
		_idle_t += delta
		if _idle_t > 9.0:
			_idle_t = 0.0
			_say_kind("idle")
	if _anger > 0.5 and _angry_said <= 0.0:
		_angry_said = 6.0
		_say_kind("angry")
	# Pistot: vihaiset ampiaiset pistävät, ja tähtäys heittää.
	_sting_cd -= delta
	if _sting_cd <= 0.0 and randf() < _anger * _anger * delta * (1.2 + drunk):
		_sting()
	# Hermostuttaa: ampiaiset pään ympärillä heiluttavat tähtäystä.
	_yaw += sin(_t * 7.0) * _anger * 0.004 + sin(_t * 1.3) * drunk * 0.003
	_pitch += cos(_t * 6.1) * _anger * 0.003
	_animate_wasps(delta)
	if _buzz != null:
		_buzz.volume_db = lerpf(-24.0, -6.0, _anger)
	_task.text = "Suihkuta pesän suuaukkoon (alhaalla)"
	_count.text = "Pesä %d %% · myrkkyä %d %% · pistoja %d / %d" % [roundi(_dose / PESA_DOSE * 100.0),
		roundi(maxf(_can, 0.0) / CAN_S * 100.0), stings, STINGS_MAX]


func _sting() -> void:
	stings += 1
	_sting_cd = 1.2
	_shake = 1.0
	_flash.color.a = 0.4
	_yaw += randf_range(-0.25, 0.25)
	_pitch += randf_range(-0.15, 0.15)
	Sfx.play("grunt", -2.0, 1.2)
	_sub.text = "Sinä: \"%s\"" % ["AI! Pisti!", "AU! Niskaan!", "AIJAI! Korvaan!"][mini(stings - 1, 2)]
	_sub_t = 2.0
	if stings >= STINGS_MAX:
		result = "pako"
		_end_t = 0.0
		Sfx.play("alert", -4.0, 1.4)
		_task.text = "PANIIKKI! JÄRVEEN!"
		_say_kind("panic")
	else:
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if not _done:
				_say_kind("sting"))


func _kill_nest() -> void:
	result = "ok"
	_end_t = 0.0
	_anger = 0.0
	Sfx.play("win_small", -4.0)
	_task.text = "Pesä tuhottu! F lopettaa."
	_say_kind("done")
	var nest: Node3D = kota.wasp_nest
	if nest != null:
		var tw := nest.create_tween()
		tw.tween_property(nest, "position", nest.position - Vector3(0, nest.position.y, 0) + Vector3(0, 0.1, 0), 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for w in _wasps:
		w.set_meta("dead", true)


func _animate_wasps(delta: float) -> void:
	for i in _wasps.size():
		var w := _wasps[i]
		if w.get_meta("dead", false):
			if w.position.y > 0.02:
				w.position.y = maxf(0.02, w.position.y - delta * 1.5)
			continue
		var a := _t * (2.0 + i * 0.13) + i * 1.7
		var r := 0.2 + _anger * (0.6 + (i % 4) * 0.25)
		var c := nest_local.lerp(eye, _anger * 0.55 * float(i % 3 == 0))
		w.position = c + Vector3(cos(a) * r, sin(a * 1.7) * r * 0.5, sin(a) * r)
		w.rotation.y = -a


func _can_quit() -> bool:
	return result != "pako" or _end_t > 2.6


func _gust_comment_ok() -> bool:
	return _end_t < 0.0


func _action() -> void:
	pass  # suihkutus pidetään pohjassa (_spraying)


func _cleanup() -> void:
	if _buzz != null:
		_buzz.stop()
	if _hiss != null:
		_hiss.stop()
