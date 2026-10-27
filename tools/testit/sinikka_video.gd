extends Node3D
## Sinikka (bikini) videotesti, noin 27 s: kävely kameraa kohti ja sivuttain (hyllyntä, hiusten heilahdus), juoksu, hyppy,
## pysähdys (vaimeneminen), kävely rantatuolille, istuutuminen (Sitting_Enter -> Pose.sit RENTO), nojaus ja nousu.
## Kuusi still-kuvaa eri vaiheista samaan kansioon. Video: aja.sh --video tscn tools/testit/sinikka_video.tscn

const Pose := preload("res://scripts/pose.gd")
const Seat := preload("res://scripts/seat.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

const CHAIR := Vector3(-8, 0, 0)
const T_END := 27.0
## Aikataulu (s): kävely kameraa kohti, sivuttain, juoksu, hyppy, lasku, pysähdys, kävely tuolille, käännös, istuutuminen, nojaus, nousu
const T_SIDE := 5.0
const T_RUN := 9.0
const T_JUMP := 12.0
const T_LAND := 13.3
const T_STOP := 13.8
const T_TOCHAIR := 16.0
const T_TURN := 19.2
const T_ENTER := 20.0
const T_LEAN := 22.4
const T_EXIT := 25.2

var out := "user://sinikka_video"
var cam: Camera3D
var ch: Node3D
var chair: Node3D
var t := 0.0
var phase := ""
var seat_pos := Vector3.ZERO
var enter_len := 1.5
var stills := {3.0: "1_kavely_edesta", 7.0: "2_kavely_sivulta", 10.6: "3_juoksu", 12.6: "4_hyppy", 21.4: "5_istuutuu", 24.0: "6_nojaa_lahikuva"}
var done_stills := {}
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
var ready_to_run := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.88)
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(60, 0.1, 40)), Vector3(-2, -0.05, 0), Color(0.86, 0.78, 0.55))  # hiekka
	# Rantatuoli kuten world.gd:n uimarannalla (sama geometria ja Seat.spot)
	chair = Node3D.new()
	chair.position = CHAIR
	add_child(chair)
	B.mesh(chair, B.boxm(Vector3(0.9, 0.02, 1.8)), Vector3(0, 0.07, 0), Color(0.9, 0.2, 0.2))
	var cc := Color(0.95, 0.85, 0.2)
	B.mesh(chair, B.boxm(Vector3(0.5, 0.04, 0.45)), Vector3(0, 0.42, -0.05), cc)
	var tilt := 0.5
	var lean := Vector3(0, cos(tilt), sin(tilt))
	var pivot := Vector3(0, 0.42, 0.2)
	B.mesh(chair, B.boxm(Vector3(0.5, 0.7, 0.04)), pivot + lean * 0.35, cc).rotation.x = tilt
	for lx in [-0.23, 0.23]:
		for lz in [-0.25, 0.15]:
			B.mesh(chair, B.cyl(0.015, 0.015, 0.44, 5), Vector3(lx, 0.21, lz), Color(0.7, 0.7, 0.72))
	var nn := Vector3(0, sin(tilt), -cos(tilt))
	Seat.spot(chair, {"seat": Vector3(0, 0.44, -0.04), "front": Vector3(0, 0, -1),
		"back": {"p": pivot + lean * 0.35 + nn * 0.02, "n": nn}})
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 38.0
	ch = Looks.make(self, Looks.sinikka_bikini())
	ch.position = Vector3(0, 0, 6)
	_face(Vector3(0, 0, -1))
	ch.play("Walk", 0.0)
	cam_pos = Vector3(1.5, 1.2, -4.0)
	cam_look = Vector3(0, 1.0, 2)
	for i in 4:
		await get_tree().process_frame
	ready_to_run = true


func _face(dir: Vector3) -> void:
	ch.rotation.y = atan2(-dir.x, -dir.z)


func _turn_to(dir: Vector3, rate: float, delta: float) -> void:
	ch.rotation.y = lerp_angle(ch.rotation.y, atan2(-dir.x, -dir.z), clampf(rate * delta, 0.0, 1.0))


func _anim(n: String, blend := 0.2, speed := 1.0) -> void:
	if ch.anim.has_animation(n):
		ch.play(n, blend, speed)
	else:
		push_warning("sinikka_video: animaatiota ei ole: " + n)


func _cam_to(pos: Vector3, look: Vector3, delta: float, k := 4.0) -> void:
	var a := clampf(k * delta, 0.0, 1.0)
	cam_pos = cam_pos.lerp(pos, a)
	cam_look = cam_look.lerp(look, a)
	cam.look_at_from_position(cam_pos, cam_look)


func _process(delta: float) -> void:
	if not ready_to_run:
		return
	t += delta
	var c := ch.position + Vector3(0, 1.0, 0)
	if t < T_SIDE:
		# kävely kameraa kohti (hahmo kävelee -Z, kamera edessä)
		ch.position.z = lerpf(6.0, -1.0, t / T_SIDE)
		_anim("Walk", 0.2, 0.95)
		_cam_to(Vector3(1.2, 1.25, -4.0), c + Vector3(0, 0.1, 0), delta, 8.0)
	elif t < T_RUN:
		_turn_to(Vector3(1, 0, 0), 8.0, delta)
		ch.position.x += 1.3 * delta
		_anim("Walk", 0.2, 0.95)
		_cam_to(ch.position + Vector3(0.6, 1.1, -4.2), c, delta, 5.0)
	elif t < T_JUMP:
		_turn_to(Vector3(-1, 0, 0), 10.0, delta)
		ch.position.x -= 3.2 * delta
		_anim("Jog_Fwd" if ch.anim.has_animation("Jog_Fwd") else "Sprint", 0.2, 1.0)
		_cam_to(ch.position + Vector3(-1.5, 1.2, -5.0), c, delta, 4.0)
	elif t < T_LAND:
		var u := (t - T_JUMP) / (T_LAND - T_JUMP)
		ch.position.x -= 2.2 * delta
		ch.position.y = 0.55 * 4.0 * u * (1.0 - u)
		_anim("Jump", 0.1, 1.0)
		_cam_to(ch.position + Vector3(-0.5, 0.9, -4.5), c + Vector3(0, 0.2, 0), delta, 6.0)
	elif t < T_STOP:
		ch.position.y = 0.0
		_anim("Jump_Land" if ch.anim.has_animation("Jump_Land") else "Idle", 0.1, 1.0)
		_cam_to(ch.position + Vector3(-0.5, 1.0, -4.0), c, delta, 6.0)
	elif t < T_TOCHAIR:
		# pysähdys: hiusten ja rintojen vaimeneminen; kamera lähemmäs, lopuksi takakulmasta
		_anim("Idle", 0.25, 1.0)
		var back := t > 15.0
		_cam_to(ch.position + (Vector3(1.0, 1.5, 1.0) if back else Vector3(1.6, 1.25, -1.6)), ch.position + Vector3(0, 1.3 if back else 1.15, 0), delta, 5.0)
	elif t < T_TURN:
		var d := CHAIR + Vector3(0.0, 0, -0.9) - ch.position
		d.y = 0
		if d.length() > 0.05:
			_turn_to(d, 7.0, delta)
			ch.position += d.normalized() * minf(1.15 * delta, d.length())
		_anim("Walk", 0.2, 0.85)
		_cam_to(ch.position + Vector3(2.8, 1.2, -3.0), ch.position + Vector3(-0.8, 0.95, 0), delta, 3.0)
	elif t < T_ENTER:
		# käännös selkä tuoliin (kasvot -Z)
		_turn_to(Vector3(0, 0, -1), 6.0, delta)
		_anim("Idle", 0.3, 1.0)
		_cam_to(CHAIR + Vector3(3.0, 1.1, -2.2), CHAIR + Vector3(0, 0.8, -0.3), delta, 3.0)
	elif t < T_LEAN:
		if phase == "":
			_start_enter()
		if phase == "enter":
			var u := clampf((t - T_ENTER) / enter_len, 0.0, 1.0)
			ch.position = seat_pos + Vector3(0, 0, -0.45) * (1.0 - smoothstep(0.0, 1.0, u))
			if u >= 1.0:
				_sit()
		_cam_to(CHAIR + Vector3(3.2, 1.0, -0.5), CHAIR + Vector3(0, 0.7, 0), delta, 4.0)
	elif t < T_EXIT:
		if phase == "enter":
			_sit()
		if t > 24.3:
			_cam_to(CHAIR + Vector3(1.4, 0.75, -0.5), CHAIR + Vector3(0, 0.55, 0.0), delta, 3.0)
		else:
			_cam_to(CHAIR + Vector3(2.2, 0.9, -1.0), CHAIR + Vector3(0, 0.7, 0.05), delta, 1.5)
	else:
		if phase != "exit":
			phase = "exit"
			ch.clear_ik()
			_anim("Sitting_Exit", 0.1, 1.0)
		if t > T_EXIT + 1.4:
			_anim("Idle", 0.3, 1.0)
		_cam_to(CHAIR + Vector3(3.0, 1.1, -1.6), CHAIR + Vector3(0, 0.9, -0.2), delta, 3.0)
	_stills.call_deferred()
	if t >= T_END:
		set_process(false)
		print("SINIKKA_VIDEO valmis ", ProjectSettings.globalize_path(out))
		get_tree().quit()


func _start_enter() -> void:
	phase = "enter"
	# Lopullinen paikka: istutaan kerran ja luetaan paikka, sitten takaisin seisomaan ja Sitting_Enter
	_anim("Sitting_Idle", 0.0)
	ch.refresh_pose()
	Pose.sit(ch, chair, Pose.RENTO, {"ristissa": true})
	seat_pos = ch.position
	var rot := ch.rotation.y
	ch.clear_ik()
	ch.rotation.y = rot
	ch.restart("Sitting_Enter" if ch.anim.has_animation("Sitting_Enter") else "Idle", 0.1, 1.0)
	enter_len = ch.anim_length("Sitting_Enter") if ch.anim.has_animation("Sitting_Enter") else 1.5
	print("sinikka_video: Sitting_Enter pituus %.2f s, istumapaikka %s" % [enter_len, seat_pos])


func _sit() -> void:
	phase = "sit"
	ch.position = seat_pos
	_anim("Sitting_Idle", 0.0)
	ch.refresh_pose()
	Pose.sit(ch, chair, Pose.RENTO, {"ristissa": true})
	print("sinikka_video: istuu, painumalaatikoita ", ch.press_boxes.size())


func _stills() -> void:
	for k: float in stills:
		if t >= k and not done_stills.has(k):
			done_stills[k] = true
			await RenderingServer.frame_post_draw
			var f: String = out.path_join("kuva_%s.png" % stills[k])
			cam.get_viewport().get_texture().get_image().save_png(f)
			print("kuva ", f)
