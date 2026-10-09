extends Node3D
## Mopojen kiihdytyskisa (90-luvun Vaala): Zabukin pihan mopopojat haastavat 150 metrin kiihdytykseen Vaalantien
## suoralla. Valot: kolme punaista, sitten vihreä -> [W] kaasu pohjaan (liian aikaisin = vilppilähtö, hävitty).
## Kierrosmittari nousee vaihteella; [välilyönti] vaihtaa ylös. Vihreällä alueella vaihdettu = täysi veto, liian
## aikaisin = moottori tukehtuu hetkeksi, rajoittimella = aikaa kuluu turhaan. Neljä vaihdetta, huippu 60 km/h
## (pelaajan mopo build_model) ja vastustajalla viritetty Tunturi, joka vaihtaa omaan tahtiinsa. Humala heiluttaa
## vihreää aluetta. Lopuksi finished(voitto, oma aika, vastustajan aika); kutsuja hoitaa panokset.
## Solmu sijoitetaan Vaalan kehykseen (vaala.gd) ja track on tien keskiviiva (lähtöviivasta maaliin, y maastossa).

signal finished(won: bool, my_time: float, opp_time: float)

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Mopo := preload("res://scripts/mopo.gd")

const DIST := 150.0
const LANE := 1.4
const TOPS := [5.0, 9.0, 13.0, 16.7]   # vaihteiden huippunopeudet (m/s)
const ACC := [3.6, 2.7, 1.9, 1.25]      # kiihtyvyys vaihteella (m/s²)
const SHIFT_T := 0.22                   # vaihtoon kuluva aika ilman vetoa
const ZONE := Vector2(0.8, 0.96)        # vaihtoikkuna kierroksina (0..1)
const OPP_NAMES := ["Tunturi-Jani", "Pakoputki-Pete", "Kuskin Kimmo"]

var track: Array[Vector3] = []
var drunk := 0.0
var opp_skill := 0.5  # 0 aloittelija .. 1 viritetyn mopon kuningas
var opp_name := "Tunturi-Jani"

var _cum: Array[float] = []
var _phase := "lights"  # lights | race | done
var _t := 0.0
var _green_at := 0.0
var _me := {"s": 0.0, "v": 0.0, "gear": 0, "shift": 0.0, "bog": 0.0, "go": false, "time": -1.0}
var _opp := {"s": 0.0, "v": 0.0, "gear": 0, "shift": 0.0, "bog": 0.0, "go": false, "time": -1.0}
var _opp_react := 0.3
var _opp_shift_at := 0.9
var _my_model: Node3D
var _opp_model: Node3D
var _cam: Camera3D
var _prev_cam: Camera3D
var _layer: CanvasLayer
var _lights: Array[Panel] = []
var _rev: ProgressBar
var _zone_rect: ColorRect
var _info: Label
var _big: Label
var _engine: AudioStreamPlayer
var _note := ""  # viimeisimmän vaihdon arvio
var _note_t := 0.0
var _wob := 0.0


func _ready() -> void:
	_cum.append(0.0)
	for i in range(1, track.size()):
		_cum.append(_cum[i - 1] + track[i - 1].distance_to(track[i]))
	_prev_cam = get_viewport().get_camera_3d()
	_my_model = _make_mopo(Looks.PLAYER, Color(0.72, 0.08, 0.06), true)
	_opp_model = _make_mopo({"shirt": Color(0.1, 0.35, 0.6), "pants": Color(0.25, 0.32, 0.5), "shoes": Color(0.9, 0.9, 0.9),
		"hair": "Hair_Buzzed", "hair_color": Color(0.7, 0.55, 0.3), "height": 1.76, "bulk": -0.6, "shoulders": -0.5,
		"tracksuit": {"a": Color(0.9, 0.2, 0.3), "b": Color(0.1, 0.35, 0.6)}}, Color(0.85, 0.72, 0.08), false)
	# Lähtö- ja maaliviiva tiehen, sekä kaverit tien varressa.
	for at: float in [0.0, DIST]:
		var p := _at(at)
		var d := _dir(at)
		var line := B.mesh(self, B.boxm(Vector3(LANE * 2.0 + 1.6, 0.03, 0.3)), p + Vector3(0, 0.05, 0), Color(0.95, 0.95, 0.95))
		line.rotation.y = atan2(d.x, d.z)
	var fl := _at(DIST) + _side(DIST) * (LANE + 2.2)
	var flagger := Looks.make(self, {"model": "female", "shirt": Color(0.12, 0.12, 0.14), "pants": Color(0.3, 0.38, 0.55),
		"hair": "Hair_Long", "hair_color": Color(0.85, 0.75, 0.5), "height": 1.66, "bulk": -0.5})
	flagger.position = fl
	flagger.rotation.y = B.yaw_to(-_side(DIST))
	flagger.play("Idle", 0.0)
	var st := _at(0) - _side(0) * (LANE + 2.0) + _dir(0) * 2.0
	var starter := Looks.make(self, {"shirt": Color(0.2, 0.45, 0.2), "pants": Color(0.15, 0.15, 0.17), "hair": "Hair_Long",
		"hair_color": Color(0.15, 0.1, 0.08), "height": 1.82, "bulk": -0.7})
	Looks.add_cap(starter)
	starter.position = st
	starter.rotation.y = B.yaw_to(_side(0))
	starter.play("Idle_Talking", 0.0)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 1500.0
	add_child(_cam)
	_cam.current = true
	_engine = AudioStreamPlayer.new()
	_engine.stream = Sfx.stream("engine")
	_engine.bus = "SFX"
	_engine.volume_db = -8.0
	add_child(_engine)
	_engine.play()
	_opp_react = lerpf(0.45, 0.17, opp_skill) + randf_range(-0.04, 0.06)
	_opp_shift_at = clampf(lerpf(0.7, 0.92, opp_skill) + randf_range(-0.06, 0.06), 0.6, 1.0)
	_build_hud()
	_place()


func _make_mopo(look: Dictionary, col: Color, me: bool) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	Mopo.build_model(root)
	if col != Color(0.72, 0.08, 0.06):
		for n in root.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).material_override == B.mat(Color(0.72, 0.08, 0.06)):
				(n as MeshInstance3D).material_override = B.mat(col)
	var r := Looks.make(root, look)
	if me:
		Looks.add_cap(r)
	r.play("Driving", 0.0)
	r.anim.advance(0.01)
	r.position = Vector3(0, 0.92, 0.25) - r.bone_position("pelvis")
	r.set_override("spine_01", Vector3.RIGHT, -0.35)  # kumarassa tankin päällä
	return root


# --- Rata ---------------------------------------------------------------------------

func _at(s: float) -> Vector3:
	s = clampf(s, 0.0, _cum[-1])
	for i in range(1, _cum.size()):
		if _cum[i] >= s:
			var u := (s - _cum[i - 1]) / maxf(_cum[i] - _cum[i - 1], 0.001)
			return track[i - 1].lerp(track[i], u)
	return track[-1]


func _dir(s: float) -> Vector3:
	var a := _at(s - 2.0)
	var b := _at(s + 2.0)
	return Vector3(b.x - a.x, 0, b.z - a.z).normalized()


func _side(s: float) -> Vector3:
	return _dir(s).cross(Vector3.UP)


func _place() -> void:
	for pair in [[_my_model, _me, -1.0], [_opp_model, _opp, 1.0]]:
		var m: Node3D = pair[0]
		var st: Dictionary = pair[1]
		var s: float = st.s
		m.position = _at(s) + _side(s) * LANE * pair[2] + Vector3(0, 0.02, 0)
		var d := _dir(s)
		m.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
		m.rotation.z = 0.0
		if st.v > 0.1 and st.gear == 0 and st.v < 3.0:
			m.rotation.x = 0.06  # keula nousee lähdössä
	var lead: float = maxf(_me.s, _opp.s)
	var c := _at(lead - 9.0) + Vector3(0, 3.4, 0)
	_cam.global_transform = Transform3D(Basis(), to_global(c))
	_cam.look_at(to_global(_at(lead + 14.0) + Vector3(0, 0.8, 0)))


# --- Kulku --------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_note_t -= delta
	_wob += delta * (1.5 + drunk * 4.0)
	match _phase:
		"lights":
			var lit := int(_t / 0.8)
			for i in 3:
				_lights[i].modulate = Color(1, 0.15, 0.1) if i < lit and lit < 4 else Color(0.25, 0.25, 0.25)
			if lit >= 4 and _green_at == 0.0:
				_green_at = _t
				for l in _lights:
					l.modulate = Color(0.2, 1.0, 0.3)
				Sfx.play("whoosh", -10.0, 1.4)
			_big.text = "VALMIINA..." if lit < 4 else "NYT!"
			if Input.is_action_just_pressed("forward"):
				if _green_at == 0.0:
					_finish(false, "VILPPILÄHTÖ! Kaasu pohjaan ennen vihreää.")
					return
				_me.go = true
				_phase = "race"
				_note = "Reaktio %.2f s" % (_t - _green_at)
				_note_t = 1.5
			if _green_at > 0.0 and _t - _green_at > 2.5 and not _me.go:
				_me.go = true  # nukahti lähtöön
				_phase = "race"
				_note = "Nukuit lähdössä!"
				_note_t = 1.5
			if _green_at > 0.0 and _t - _green_at > _opp_react:
				_opp.go = true
			if _phase == "race" or _opp.go:
				_step(_opp, delta, true)
		"race":
			_big.text = ""
			if _green_at > 0.0 and _t - _green_at > _opp_react:
				_opp.go = true
			if Input.is_action_just_pressed("jump"):
				_shift(_me, true)
			_step(_me, delta, false)
			_step(_opp, delta, true)
			if _me.time >= 0.0 and _opp.time >= 0.0:
				_finish(_me.time <= _opp.time, "")
		"done":
			pass
	if _phase != "done":
		_update_hud()
		_place()


func _rpm(st: Dictionary) -> float:
	var lo: float = 0.0 if st.gear == 0 else TOPS[st.gear - 1] * 0.55
	return clampf((st.v - lo) / maxf(TOPS[st.gear] - lo, 0.1), 0.0, 1.0)


func _step(st: Dictionary, delta: float, ai: bool) -> void:
	if not st.go or st.time >= 0.0:
		if st.time >= 0.0:
			st.v = maxf(st.v - 4.0 * delta, 0.0)
			st.s += st.v * delta
		return
	if ai and st.gear < TOPS.size() - 1 and _rpm(st) >= _opp_shift_at and st.shift <= 0.0:
		_shift(st, false)
	if st.shift > 0.0:
		st.shift -= delta
	else:
		var a: float = ACC[st.gear] * (0.45 if st.bog > 0.0 else 1.0)
		if ai:
			a *= lerpf(0.94, 1.04, opp_skill)
		st.v = minf(st.v + a * delta, TOPS[st.gear])
	st.bog = maxf(st.bog - delta, 0.0)
	st.s += st.v * delta
	if st.s >= DIST:
		st.time = _t - _green_at
		if not ai:
			Sfx.play("whoosh", -6.0)


func _zone() -> Vector2:
	var w := sin(_wob) * drunk * 0.12  # kännissä vihreä alue heiluu
	return ZONE + Vector2(w, w)


func _shift(st: Dictionary, me: bool) -> void:
	if st.gear >= TOPS.size() - 1 or st.shift > 0.0 or not st.go:
		return
	var r := _rpm(st)
	var z := _zone() if me else ZONE
	st.gear += 1
	st.shift = SHIFT_T
	if r < z.x - 0.15:
		st.bog = 0.9
		if me:
			_note = "Liian aikaisin, moottori tukehtui!"
	elif r < z.x:
		st.bog = 0.35
		if me:
			_note = "Vähän aikaisin."
	elif r <= z.y:
		if me:
			_note = "TÄYDELLINEN VAIHTO!"
	else:
		st.shift += 0.08
		if me:
			_note = "Rajoittimella, myöhään."
	if me:
		_note_t = 1.2
		Sfx.play("rattle", -12.0, 1.6)


func _finish(won: bool, why: String) -> void:
	_phase = "done"
	_engine.stop()
	var my_t: float = _me.time if _me.time >= 0.0 else 99.0
	var opp_t: float = _opp.time if _opp.time >= 0.0 else 99.0
	_big.text = why if why != "" else ("VOITIT!" if won else "HÄVISIT!")
	_info.text = "Sinä %s · %s %s" % ["%.2f s" % my_t if my_t < 90.0 else "–", opp_name, "%.2f s" % opp_t if opp_t < 90.0 else "–"]
	Sfx.play("win" if won else "lose", -4.0)
	await get_tree().create_timer(2.5).timeout
	_layer.queue_free()
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	finished.emit(won, my_t, opp_t)


# --- HUD ----------------------------------------------------------------------------

func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	var title := Label.new()
	title.text = "KIIHDYTYS 150 m · %s" % opp_name
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.position = Vector2(40, 24)
	_layer.add_child(title)
	for i in 3:
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(30)
		sb.border_color = Color.BLACK
		sb.set_border_width_all(4)
		p.add_theme_stylebox_override("panel", sb)
		p.size = Vector2(60, 60)
		p.anchor_left = 0.5
		p.anchor_right = 0.5
		p.offset_left = -110 + i * 80
		p.offset_right = p.offset_left + 60
		p.offset_top = 30
		p.offset_bottom = 90
		p.modulate = Color(0.25, 0.25, 0.25)
		_layer.add_child(p)
		_lights.append(p)
	_big = Label.new()
	_big.add_theme_font_size_override("font_size", 56)
	_big.add_theme_constant_override("outline_size", 14)
	_big.add_theme_color_override("font_outline_color", Color.BLACK)
	_big.anchor_left = 0.5
	_big.anchor_right = 0.5
	_big.offset_left = -400
	_big.offset_right = 400
	_big.offset_top = 110
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(_big)
	# Kierrosmittari alhaalla: palkki ja vihreä vaihtoalue.
	var box := Control.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -260
	box.offset_right = 260
	box.offset_top = -120
	box.offset_bottom = -90
	_layer.add_child(box)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09, 0.85)
	bg.size = Vector2(520, 30)
	box.add_child(bg)
	_zone_rect = ColorRect.new()
	_zone_rect.color = Color(0.2, 0.85, 0.3, 0.55)
	box.add_child(_zone_rect)
	_rev = ProgressBar.new()
	_rev.show_percentage = false
	_rev.max_value = 1.0
	_rev.size = Vector2(520, 30)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.55, 0.15, 0.85)
	_rev.add_theme_stylebox_override("fill", fill)
	_rev.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	box.add_child(_rev)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 22)
	_info.add_theme_constant_override("outline_size", 8)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.anchor_left = 0.5
	_info.anchor_right = 0.5
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_left = -420
	_info.offset_right = 420
	_info.offset_top = -82
	_info.offset_bottom = -20
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(_info)


func _update_hud() -> void:
	var z := _zone()
	_zone_rect.position = Vector2(520.0 * z.x, 0)
	_zone_rect.size = Vector2(520.0 * (z.y - z.x), 30)
	_rev.value = _rpm(_me) if _me.go else 0.15 + 0.1 * sin(_t * 18.0)
	var kmh := roundi(_me.v * 3.6)
	var lead := "johdat" if _me.s >= _opp.s else "%s edellä %d m" % [opp_name, roundi(_opp.s - _me.s)]
	var keys := "[%s] kaasu lähtövaloissa · [%s] vaihda ylös vihreällä" % [Settings.action_key("forward"), Settings.action_key("jump")]
	_info.text = "Vaihde %d · %d km/h · %d / %d m · %s\n%s" % [_me.gear + 1, kmh, mini(roundi(_me.s), int(DIST)), int(DIST), lead,
		_note if _note_t > 0.0 else keys]
	_engine.pitch_scale = 0.7 + _rpm(_me) * 1.1 if _me.go else 0.8
