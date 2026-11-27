extends CanvasLayer
## Legendaarinen hetki "karaoke" (Karaokekuningas): baarin karaoken ensimmäinen raikuva veto lavastetaan baarissa
## (Siitari tai Kapteenin Kellari). Vaiheet:
##   savel      pelaaja pitää viimeistä säveltä mikkitelineen takana käsi ylhäällä, kamera ajaa lähemmäs
##   hiljaisuus sävel loppuu, koko sali kääntyy katsomaan ja on hiljaista (olan yli lavalta saliin)
##   aplodit    sali nousee seisomaan ja taputtaa, pelaaja kumartaa, fani ja joku pöydästä huutavat
##   kello      baarimikko soittaa tiskin messinkikelloa: "talo tarjoaa"
##   tuoppi     tuoppi liukuu tiskiä pitkin tiskin päähän suoraan kuninkaan käteen
##   otsikko    kuningas nostaa tuopin, taustalla liitutaulu "ILLAN KUNINGAS" kirjoittuu, kultainen otsikko
## Paikka ja näyttelijät tulevat baarin sisätilasta (legend_cast(): siitari_interior.gd, raahe_interior.gd); taulu jää
## seinälle (show_board) ja baarimikko muistelee seuraavalla käynnillä (main.gd). Kaikki koordinaatit ovat sisätilan
## paikallisia. Pelaajan hahmon eteen on -Z (Looks/character.gd).

signal finished

const B := preload("res://scripts/build.gd")
const Pose := preload("res://scripts/pose.gd")
const Room := preload("res://scripts/ilta_room.gd")

const RATE := 22050.0
const T := {"savel": 3.3, "hiljaisuus": 2.4, "aplodit": 4.8, "kello": 3.0, "tuoppi": 3.4, "otsikko": 5.6}
const ORDER := ["savel", "hiljaisuus", "aplodit", "kello", "tuoppi", "otsikko"]

var interior: Node3D
var cast := {}

var phase := ""
var _t := 0.0  # vaiheen aika
var _tt := 0.0  # koko kohtauksen aika
var _cam: Camera3D
var _prev_cam: Camera3D
var _ui: Control
var _keys: Node
var _story := ""
var _bub := {}  # hahmo -> repliikki
var _once := {}
var _player: Node3D  # pelaajan hahmo (walker._body)
var _walker: Node3D
var _aud: Array = []  # [hahmo, istumapaikka, istumakulma, seisomapaikka, oli_istuva]
var _fan_orig := []
var _bt_orig := []
var _pint: Node3D
var _bell: Node3D
var _board: Node3D
var _sfx: AudioStreamPlayer
var _shake := 0.0
var _flash := 0.0
var _foam: Array = []  # vaahtoroiskeet [paikka, nopeus, ikä]
var _screen_orig := ""
var _room: Array[Node3D] = []  # väliaikainen katto ja täyskorkea etuseinä (kuvat salista)
var _fan_sat := false


func _ready() -> void:
	layer = 6
	_walker = cast.walker
	_player = _walker._body
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_keys.set_text("%s ohita" % Settings.cap("interact"))
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "SFX"
	add_child(_sfx)
	_walker.set_physics_process(false)  # ei maaston korkeutta eikä Idle-animaatiota joka ruutu (lava 0,35 m)
	_build_room()
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	interior.add_child(_cam)
	_cam.current = true
	for b: Label3D in (cast.bubbles as Dictionary).values():
		b.text = ""
	var scr: Label3D = cast.screen
	_screen_orig = scr.text
	# Sali: istuvat talteen ja seisomapaikka puoli metriä tuolin edestä lavan suuntaan.
	for c: Node3D in cast.audience:
		var to_stage := Vector3(cast.stage.x - c.position.x, 0, cast.stage.z - c.position.z).normalized()
		_aud.append([c, c.position, c.rotation.y, c.position + to_stage * 0.45, c.has_meta("sitting") or c.current().begins_with("Sitting")])
	var fan: Node3D = cast.get("fan")
	if fan != null:
		_fan_orig = [fan.position, fan.rotation.y]
		_fan_sat = fan.has_meta("sitting") or fan.current().begins_with("Sitting")
	var bt: Node3D = cast.bartender
	_bt_orig = [bt.position, bt.rotation.y]
	_build_props()
	_begin("savel")


func _exit_tree() -> void:
	if is_instance_valid(_cam):
		_cam.queue_free()
	for p in [_pint, _bell]:
		if is_instance_valid(p):
			p.queue_free()
	for r in _room:
		if is_instance_valid(r):
			r.queue_free()


## Katto ja etuseinä täyskorkeaksi kohtauksen ajaksi: pelikamera katsoo ylhäältä, kohtauksen kamerat salin tasolta.
func _build_room() -> void:
	var rm: Dictionary = cast.room
	var c: Vector3 = rm.c
	var half: Vector2 = rm.half
	var h: float = rm.h
	var col: Color = rm.col
	var ceil := B.mesh(interior, B.boxm(Vector3(half.x * 2.0 + 0.4, 0.1, half.y * 2.0 + 0.4)), c + Vector3(0, h + 0.05, 0), col.darkened(0.25))
	var front := B.mesh(interior, B.boxm(Vector3(half.x * 2.0 + 0.4, h, 0.12)), c + Vector3(0, h / 2.0, half.y + 0.06), col)
	_room.append(ceil)
	_room.append(front)

# --- Rekvisiitta --------------------------------------------------------------------

## Tuoppi (lasi, olut, vaahtopäällinen ja korva) ja tiskin messinkikello telineessään.
func _build_props() -> void:
	_pint = Node3D.new()
	interior.add_child(_pint)
	_pint.position = cast.slide_from
	# Olut ensin (kullankeltainen, läpikuultava, hehkuu hieman, jotta näkyy myös tummassa Kellarissa), sitten ohut
	# kirkas lasi kiiltoineen ja kermainen vaahtokerros lasin reunan yli.
	var om := StandardMaterial3D.new()
	om.albedo_color = Color(0.95, 0.62, 0.08, 0.88)
	om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	om.roughness = 0.15
	om.emission_enabled = true
	om.emission = Color(0.85, 0.48, 0.05)
	om.emission_energy_multiplier = 0.55
	var beer := B.mesh(_pint, B.cyl(0.045, 0.04, 0.128, 18), Vector3(0, 0.072, 0), Color.WHITE)
	beer.material_override = om
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.92, 0.96, 1.0, 0.12)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.03
	gm.metallic = 0.2
	gm.metallic_specular = 1.0
	gm.rim_enabled = true
	gm.rim = 0.6
	gm.rim_tint = 0.2
	var glass := B.mesh(_pint, B.cyl(0.048, 0.042, 0.17, 18), Vector3(0, 0.085, 0), Color.WHITE)
	glass.material_override = gm
	var shine := B.mesh(_pint, B.boxm(Vector3(0.008, 0.12, 0.002)), Vector3(-0.022, 0.085, 0.042), Color.WHITE, Vector3(0, -25, 0))
	shine.material_override = B.unshaded(Color(1, 1, 1, 0.55))
	(shine.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.97, 0.88)
	fm.roughness = 0.9
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.95, 0.85)
	fm.emission_energy_multiplier = 0.25
	for f in [[B.cyl(0.05, 0.046, 0.032, 18), Vector3(0, 0.152, 0)], [B.sphere(0.03, 10), Vector3(0.014, 0.172, 0.006)],
			[B.sphere(0.024, 10), Vector3(-0.016, 0.17, -0.01)], [B.sphere(0.02, 10), Vector3(0.0, 0.17, 0.022)]]:
		var fo := B.mesh(_pint, f[0], f[1], Color.WHITE)
		fo.material_override = fm
	for k in 6:  # kuplia oluessa
		var bu := B.mesh(_pint, B.sphere(0.004, 6), Vector3(0.025 * cos(k * 1.9), 0.03 + k * 0.016, 0.025 * sin(k * 1.9)), Color.WHITE)
		bu.material_override = B.unshaded(Color(1.0, 0.92, 0.6))
	var handle := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.03
	tm.outer_radius = 0.045
	handle.mesh = tm
	handle.material_override = gm
	handle.rotation.x = PI / 2.0
	handle.position = Vector3(0, 0.09, 0.07)
	_pint.add_child(handle)
	_pint.set_meta("handle", Vector3(0, 0.09, 0.105))
	# Kello: pylväs tiskiltä, varsi ja riippuva messinkikello, narusta vedetään.
	_bell = Node3D.new()
	interior.add_child(_bell)
	_bell.position = cast.bell_at
	_bell.rotation.y = B.yaw_to(cast.counter_out)
	var brass := Color(0.86, 0.66, 0.26)
	var dark := Color(0.18, 0.12, 0.08)
	B.mesh(_bell, B.boxm(Vector3(0.16, 0.03, 0.16)), Vector3(0, 0.015, 0.22), dark)
	B.mesh(_bell, B.cyl(0.015, 0.015, 0.62, 8), Vector3(0, 0.31, 0.22), dark)
	B.mesh(_bell, B.boxm(Vector3(0.03, 0.03, 0.26)), Vector3(0, 0.62, 0.1), dark)
	var swing := Node3D.new()
	swing.name = "Swing"
	swing.position = Vector3(0, 0.6, 0.0)
	_bell.add_child(swing)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = brass
	bm.metallic = 0.85
	bm.roughness = 0.25
	var dome := B.mesh(swing, B.sphere(0.06, 16), Vector3(0, -0.06, 0), brass)
	dome.material_override = bm
	var body := B.mesh(swing, B.cyl(0.06, 0.085, 0.07, 18), Vector3(0, -0.095, 0), brass)
	body.material_override = bm
	var lip := B.mesh(swing, B.cyl(0.085, 0.095, 0.018, 18), Vector3(0, -0.138, 0), brass)
	lip.material_override = bm
	B.mesh(swing, B.cyl(0.075, 0.075, 0.004, 18), Vector3(0, -0.148, 0), brass.darkened(0.6))  # sisus
	B.mesh(swing, B.cyl(0.012, 0.012, 0.03, 8), Vector3(0, 0.0, 0), brass.darkened(0.2))
	B.tube(swing, Vector3(0, -0.15, 0), Vector3(0, -0.4, 0.0), 0.006, Color(0.85, 0.8, 0.65))
	B.mesh(swing, B.sphere(0.018, 8), Vector3(0, -0.41, 0), Color(0.85, 0.8, 0.65))


## Liitutaulu seinälle: puukehys, musta liuskelevy, liidulla kirjoitettu teksti ja kruunu sekä liitukouru.
## Taulun etupuoli on +Z (yaw kääntää).
static func make_board(parent: Node3D, at: Vector3, yaw: float, text: String) -> Node3D:
	var n := Node3D.new()
	n.name = "KaraokeTaulu"
	parent.add_child(n)
	n.position = at
	n.rotation.y = yaw
	var wood := Color(0.68, 0.47, 0.24)
	B.mesh(n, B.boxm(Vector3(1.08, 1.28, 0.04)), Vector3(0, 0, 0), wood)
	for e in [[Vector3(1.08, 0.05, 0.02), Vector3(0, 0.615, 0.025)], [Vector3(1.08, 0.05, 0.02), Vector3(0, -0.615, 0.025)]]:
		B.mesh(n, B.boxm(e[0]), e[1], wood.lightened(0.18))  # kehyksen vaalea yläreuna ja alareuna
	B.mesh(n, B.boxm(Vector3(0.94, 1.14, 0.02)), Vector3(0, 0, 0.022), Color(0.13, 0.2, 0.17))
	B.mesh(n, B.boxm(Vector3(1.0, 0.03, 0.08)), Vector3(0, -0.655, 0.045), wood.darkened(0.25))
	B.mesh(n, B.boxm(Vector3(0.08, 0.016, 0.016)), Vector3(0.28, -0.632, 0.055), Color(0.96, 0.95, 0.9))
	B.mesh(n, B.boxm(Vector3(0.06, 0.016, 0.016)), Vector3(-0.3, -0.632, 0.055), Color(0.95, 0.75, 0.8))
	var chalk := Color(0.95, 0.95, 0.9, 0.92)
	# Kruunu viivoina: pohja ja viisi sakaraa.
	var crown := Node3D.new()
	crown.name = "Kruunu"
	crown.position = Vector3(0, 0.3, 0.034)
	n.add_child(crown)
	var pts := [Vector2(-0.17, 0.0), Vector2(-0.17, 0.13), Vector2(-0.085, 0.05), Vector2(0.0, 0.16), Vector2(0.085, 0.05),
		Vector2(0.17, 0.13), Vector2(0.17, 0.0), Vector2(-0.17, 0.0)]
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var m := B.mesh(crown, B.boxm(Vector3(a.distance_to(b) + 0.012, 0.012, 0.004)), Vector3((a.x + b.x) / 2.0, (a.y + b.y) / 2.0, 0),
			chalk, Vector3(0, 0, rad_to_deg((b - a).angle())))
		m.material_override = B.unshaded(chalk)
	var lab := B.label(n, text, Vector3(0, -0.1, 0.036), 12, chalk)
	lab.name = "Teksti"
	lab.width = 88.0
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD
	lab.outline_size = 0
	lab.line_spacing = 2.0
	lab.set_meta("full", text)
	return n


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_once.clear()
	_bub.clear()
	var L: Dictionary = cast.lines
	match p:
		"savel":
			_story = L.savel
			_walker.position = cast.stage
			_walker.rotation.y = B.yaw_to(cast.face)
			_player.play("Idle", 0.1)
			(cast.screen as Label3D).text = L.ruutu
			_play(_note_wav(), -4.0)
		"hiljaisuus":
			_story = L.hiljaisuus
			_player.clear_ik()
			_player.clear_overrides()
			_player.play("Idle", 0.2)
			_arm_mic(0.0)
			for a: Array in _aud:  # koko sali kääntyy lavaan päin
				var c: Node3D = a[0]
				c.rotation.y = B.yaw_to(_flat(cast.stage - c.position))
			var fan: Node3D = cast.get("fan")
			if fan != null:
				fan.position = _fan_at()
				fan.rotation.y = B.yaw_to(_flat(cast.stage - fan.position))
				fan.play("Idle", 0.2)
		"aplodit":
			_story = L.aplodit
			for a: Array in _aud:
				var c: Node3D = a[0]
				c.position = a[3]
				c.rotation.y = B.yaw_to(_flat(cast.stage - c.position))
				c.play("Idle", 0.15)
			_play(_applause_wav(), -3.0)
		"kello":
			_story = L.kello
			for a: Array in _aud:
				(a[0] as Node3D).clear_ik()
			var fan: Node3D = cast.get("fan")
			if fan != null:
				fan.clear_ik()
			_player.clear_ik()
			_player.clear_overrides()
			var bt: Node3D = cast.bartender
			bt.position = cast.bartender_at
			bt.rotation.y = B.yaw_to(cast.counter_out)
			bt.play("Idle", 0.1)
			_play(_bell_wav(), -2.0)
		"tuoppi":
			_story = L.tuoppi
			_walker.position = cast.catch_at
			var along: Vector3 = (cast.slide_to - cast.slide_from).normalized()
			_walker.rotation.y = B.yaw_to(-(cast.counter_out as Vector3) + along * 0.55)
			_player.play("Idle", 0.1)
			(cast.bartender as Node3D).clear_ik()
			Sfx.play("whoosh", -6.0, 0.7)
		"otsikko":
			_story = ""
			_walker.rotation.y = B.yaw_to(_flat(_otsikko_eye() - cast.catch_at))
			Sfx.play("win", -4.0)


func _process(delta: float) -> void:
	_t += delta
	_tt += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	_flash = maxf(0.0, _flash - delta * 2.5)
	_ui.queue_redraw()
	if Input.is_action_just_pressed("interact"):
		if phase != "otsikko":
			_skip_to_title()
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"savel":
			_step_savel()
		"hiljaisuus":
			_step_hiljaisuus()
		"aplodit":
			_step_aplodit()
		"kello":
			_step_kello()
		"tuoppi":
			_step_tuoppi()
		"otsikko":
			_step_otsikko()
	for f: Array in _foam:
		f[2] += delta
		f[1] += Vector3(0, -3.5, 0) * delta
		f[0] += (f[1] as Vector3) * delta
	_foam = _foam.filter(func(f: Array) -> bool: return f[2] < 0.8)
	if phase != "" and _t >= T[phase]:
		var i := ORDER.find(phase)
		if i == ORDER.size() - 1:
			_finish()
		else:
			_begin(ORDER[i + 1])


func _skip_to_title() -> void:
	_sfx.stop()
	for a: Array in _aud:
		var c: Node3D = a[0]
		c.clear_ik()
		c.position = a[3]
		c.rotation.y = B.yaw_to(_flat(cast.stage - c.position))
		c.play("Idle", 0.1)
	_pint.position = cast.slide_to
	_walker.position = cast.catch_at
	_begin("otsikko")


## Lopetus: sali takaisin paikoilleen, rekvisiitta pois, taulu jää seinälle, kamera pelaajalle.
func _finish() -> void:
	if phase == "":
		return
	phase = ""
	_sfx.stop()
	for a: Array in _aud:
		var c: Node3D = a[0]
		c.clear_ik()
		c.clear_overrides()
		c.position = a[1]
		c.rotation.y = a[2]
		c.play("Sitting_Idle" if a[4] else "Idle", 0.2)
	var fan: Node3D = cast.get("fan")
	if fan != null:
		fan.clear_ik()
		fan.position = _fan_orig[0]
		fan.rotation.y = _fan_orig[1]
		fan.play("Sitting_Idle" if _fan_sat else "Idle", 0.2)
	var bt: Node3D = cast.bartender
	bt.clear_ik()
	bt.position = _bt_orig[0]
	bt.rotation.y = _bt_orig[1]
	bt.play("Idle", 0.2)
	_player.clear_ik()
	_player.clear_overrides()
	_walker.set_physics_process(true)
	for r in _room:
		r.queue_free()
	_room.clear()
	(cast.screen as Label3D).text = _screen_orig
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	finished.emit()
	queue_free()


# --- Vaiheiden liike ----------------------------------------------------------------

func _step_savel() -> void:
	var k := clampf(_t / T.savel, 0.0, 1.0)
	_arm_mic(1.0)
	_arm_up(minf(_t / 0.6, 1.0))
	_player.set_override("neck_01", Vector3.RIGHT, -0.22 * minf(_t / 0.8, 1.0))
	# Matala kuva tanssilattialta, ajo lähemmäs (polvista ylös -> vyötäröstä ylös).
	var head := _bone_w(_player, "Head")
	var f: Vector3 = cast.face
	var side := f.cross(Vector3.UP).normalized()
	var eye: Vector3 = cast.stage + f * lerpf(3.4, 2.2, _ease(k)) + side * 0.9 + Vector3(0, 0.95, 0)
	var look := head + Vector3(0, -0.45 + 0.2 * k, 0)
	_cam_at(eye, look, _fov_for(eye.distance_to(look), lerpf(1.55, 1.0, _ease(k)), 0.86))


func _step_hiljaisuus() -> void:
	var f: Vector3 = cast.face
	var side := f.cross(Vector3.UP).normalized()
	var aud := _aud_center()
	var eye: Vector3 = cast.stage - f * 0.85 - side * 0.55 + Vector3(0, 1.85, 0)
	var look := aud + Vector3(0, 0.8, 0)
	_cam_at(eye, look, 40.0)
	if _t > 0.5 and not _once.has("hush"):
		_once.hush = true
		_say(cast.lines.hush[0], cast.lines.hush[1])


func _step_aplodit() -> void:
	for i in _aud.size():
		_clap(_aud[i][0], _t, i * 0.17)
	var fan: Node3D = cast.get("fan")
	if fan != null:
		_clap(fan, _t, 0.4)
	_arm_mic(0.0)
	var f: Vector3 = cast.face
	var side := f.cross(Vector3.UP).normalized()
	var aud := _aud_center()
	if _t < 2.3:
		# Sali seisoo ja taputtaa: kamera tanssilattialta saliin.
		var eye: Vector3 = cast.stage.lerp(aud, 0.42) + Vector3(0, 1.25, 0) - side * 0.4
		_cam_at(eye, aud + Vector3(0, 1.1, 0), 50.0)
	else:
		# Kumarrus: matala kuva lavan edestä, fani etualan reunassa.
		var bow := clampf(sin(clampf((_t - 2.45) / 1.6, 0.0, 1.0) * PI), 0.0, 1.0)
		_player.set_override("spine_01", Vector3.RIGHT, -0.5 * bow)
		_player.set_override("spine_02", Vector3.RIGHT, -0.45 * bow)
		_player.set_override("neck_01", Vector3.RIGHT, 0.3 * bow)
		var eye: Vector3 = cast.stage + f * 3.6 + side * 1.3 + Vector3(0, 0.95, 0)
		var look: Vector3 = cast.stage + f * 0.9 + Vector3(0, 1.1, 0)
		_cam_at(eye, look, 54.0)
	var cheers: Array = cast.lines.cheers
	if _t > 0.35 and not _once.has("c0"):
		_once.c0 = true
		_say(cheers[0][0], cheers[0][1])
	if _t > 2.5 and not _once.has("c1"):
		_once.c1 = true
		_bub.clear()
		_say(cheers[1][0], cheers[1][1])


func _step_kello() -> void:
	var bt: Node3D = cast.bartender
	var swing: Node3D = _bell.get_node("Swing")
	# Kolme vetoa: 0,25 / 0,7 / 1,15 s, kello heilahtaa ja vaimenee.
	var amp := 0.0
	for s in [0.25, 0.7, 1.15]:
		var d: float = _t - s
		if d > 0.0:
			amp += 0.55 * exp(-d * 2.2) * sin(d * 18.0)
	swing.rotation.x = amp
	var cord := _bell.to_global(Vector3(0, 0.6, 0) + Basis(Vector3.RIGHT, amp) * Vector3(0, -0.41, 0))
	var pull := 0.0
	for s in [0.25, 0.7, 1.15]:
		pull = maxf(pull, clampf(1.0 - absf(_t - s) / 0.18, 0.0, 1.0))
	_hand_to(bt, "_r", cord + Vector3(0, -0.06 * pull, 0), Vector3(0.35, -0.5, 0.1))
	if _t > 0.3 and not _once.has("bt"):
		_once.bt = true
		_say("bartender", cast.lines.bartender)
	var out: Vector3 = cast.counter_out
	var head := _bone_w(bt, "Head")
	var along: Vector3 = (cast.slide_to - cast.slide_from).normalized()
	var eye := head + out * 2.2 - along * 0.6 + Vector3(0, -0.2, 0)
	var look := head.lerp(interior.to_local(_bell.global_position) + Vector3(0, 0.45, 0), 0.4) + Vector3(0, -0.2, 0)
	_cam_at(eye, look, 46.0)


func _step_tuoppi() -> void:
	var k := _ease(clampf((_t - 0.15) / 1.8, 0.0, 1.0))
	var from: Vector3 = cast.slide_from
	var to: Vector3 = cast.slide_to
	var prev := _pint.position
	_pint.position = from.lerp(to, k)
	_pint.rotation.y = 0.6 * k
	if prev.distance_to(_pint.position) > 0.0005 and randf() < 0.5:
		_foam.append([_pint.position + Vector3(0, 0.17, 0), Vector3(randf_range(-0.3, 0.3), randf_range(0.4, 0.9), randf_range(-0.3, 0.3)), 0.0])
	if k >= 0.999 and not _once.has("stop"):
		_once.stop = true
		Sfx.play("glass", -6.0, 1.1)
		for i in 8:
			_foam.append([_pint.position + Vector3(0, 0.17, 0), Vector3(randf_range(-0.5, 0.5), randf_range(0.6, 1.2), randf_range(-0.5, 0.5)), 0.0])
	# Käsi tuopin korvaan, kun se pysähtyy.
	var grab := clampf((_t - 1.75) / 0.35, 0.0, 1.0)
	if grab > 0.0:
		var hw := _pint.to_global(_pint.get_meta("handle"))
		var rest := _player.to_global(_player.bone_position("upperarm_r") + Vector3(0.1, -0.5, -0.1))
		_hand_to(_player, "_r", rest.lerp(hw, grab), Vector3(0.4, -0.6, 0.3))
	if _t > 2.45 and not _once.has("lift"):
		_once.lift = true
	if _once.has("lift"):
		var lift := clampf((_t - 2.45) / 0.5, 0.0, 1.0)
		_pint.position = to + Vector3(0, 0.25 * lift, 0.0) - (cast.counter_out as Vector3) * -0.12 * lift
		_hand_to(_player, "_r", _pint.to_global(_pint.get_meta("handle")), Vector3(0.4, -0.6, 0.3))
	# Kamera tiskin päässä tiskin tasolla: tuoppi liukuu kohti, kuningas oikealla. Lopuksi tiskin päästä sivulta:
	# kuninkaan kasvot ja tuoppi kädessä.
	var out: Vector3 = cast.counter_out
	var along := (to - from).normalized()
	var p := _pint.position
	var eye := to + along * 0.7 + out * 0.05 + Vector3(0, 0.3, 0)
	var look := p + Vector3(0, 0.1, 0)
	if _t > 1.9:
		var e := _ease(clampf((_t - 1.9) / 0.9, 0.0, 1.0))
		var head := _bone_w(_player, "Head")
		eye = eye.lerp(to + along * 0.85 + out * 0.6 + Vector3(0, 0.55, 0), e)
		look = look.lerp(p.lerp(head, 0.55), e)
	_cam_at(eye, look, 50.0)


func _step_otsikko() -> void:
	# Kuningas nostaa tuopin ylös ("skool"), liitutaulu kirjoittuu taustalla.
	var up := _ease(clampf(_t / 0.7, 0.0, 1.0))
	var sh := _player.to_global(_player.bone_position("upperarm_r"))
	var top := sh + Vector3(0, 0.55, 0) + (_flat(_otsikko_eye() - cast.catch_at).normalized() * 0.15)
	var start := _player.to_global(_player.bone_position("upperarm_r") + Vector3(0.12, -0.25, -0.35))
	var hand := start.lerp(top, up)
	_pint.global_position = hand - (_pint.global_basis * (_pint.get_meta("handle") as Vector3))
	_hand_to(_player, "_r", hand, Vector3(0.6, -0.1, 0.3))
	_arm_free_l()
	if _board == null:
		_board = interior.show_board(true)
	var lab: Label3D = _board.get_node("Teksti")
	var full: String = lab.get_meta("full")
	var n := int(clampf(_t / 1.6, 0.0, 1.0) * full.length())
	lab.text = full.substr(0, n)
	(_board.get_node("Kruunu") as Node3D).visible = _t > 1.6
	if n > 0 and n < full.length() and int(_t * 9.0) != int((_t - get_process_delta_time()) * 9.0):
		Sfx.play("cloth", -18.0, 2.2)
	_cam_at(_otsikko_eye(), _otsikko_look(), 50.0)


## Fani lavan eteen vasemmalle: kumarruskuvassa etualan reunassa, ei pelaajan edessä.
func _fan_at() -> Vector3:
	var f: Vector3 = cast.face
	var side := f.cross(Vector3.UP).normalized()
	var p: Vector3 = cast.stage + f * 2.0 - side * 1.0
	return Vector3(p.x, 0, p.z)


func _otsikko_eye() -> Vector3:
	return cast.title_eye


## Katse kuninkaan ja taulun väliin; kamera on niiden välisen suoran sivulla (title_eye), joten molemmat näkyvät.
func _otsikko_look() -> Vector3:
	var b: Vector3 = cast.board_at
	return (cast.catch_at + Vector3(0, 1.5, 0)).lerp(b, 0.5)


# --- Asennot ----------------------------------------------------------------------

## Oikea käsi mikkitelineen kaulaan (w 1) tai alas (w 0, IK pois).
func _arm_mic(w: float) -> void:
	if w <= 0.0:
		return
	_hand_to(_player, "_r", interior.to_global(cast.mic), Vector3(0.45, -0.55, 0.15))


## Vasen käsi ylös kohti kattoa (sävelen pito).
func _arm_up(w: float) -> void:
	var c := _player
	var sh: Vector3 = c.bone_position("upperarm_l")
	var s := signf(sh.x) if sh.x != 0.0 else -1.0
	var rest := sh + Vector3(s * 0.15, -0.55, 0.0)
	var up := sh + Vector3(s * 0.32, 0.5, -0.2)
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", rest.lerp(up, w), sh + Vector3(s * 0.55, 0.0, 0.3))
	c.set_ik_orient("arm_l", Pose.palm_on(Vector3(s * 0.3, 1.0, -0.2), Vector3(0, 0, -1), true), w)


func _arm_free_l() -> void:
	var c := _player
	var sh: Vector3 = c.bone_position("upperarm_l")
	var s := signf(sh.x) if sh.x != 0.0 else -1.0
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", sh + Vector3(s * 0.32, 0.5, -0.2), sh + Vector3(s * 0.55, 0.0, 0.3))
	c.set_ik_orient("arm_l", Pose.palm_on(Vector3(s * 0.3, 1.0, -0.2), Vector3(0, 0, -1), true), 1.0)


## Käsi maailman pisteeseen (pole hahmon paikallisessa avaruudessa olkapäästä).
func _hand_to(c: Node3D, lr: String, p_global: Vector3, pole_off: Vector3) -> void:
	var local := c.to_local(p_global)
	var sh: Vector3 = c.bone_position("upperarm" + lr)
	var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
	var pole := sh + Vector3(s * absf(pole_off.x), pole_off.y, pole_off.z)
	c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, local, pole)


## Taputus käsien IK:lla (kuten lava_game.gd): kämmenet vastakkain rinnan edessä, väli sykkii.
func _clap(c: Node3D, t: float, off: float) -> void:
	var rx := signf((c.bone_position("upperarm_r") as Vector3).x)
	if rx == 0.0:
		rx = 1.0
	var chest: Vector3 = c.bone_position("spine_03")
	var mid: Vector3 = chest + Vector3(0, 0.05, -0.34)
	var sep := 0.035 + 0.085 * absf(sin(PI * (t * 2.1 + off)))
	for lr in ["_l", "_r"]:
		var s := rx if lr == "_r" else -rx
		var sh: Vector3 = c.bone_position("upperarm" + lr)
		c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, mid + Vector3(s * sep, 0, 0),
			sh + Vector3(s * 0.35, -0.45, 0.05))
		c.set_ik_orient("arm" + lr, Pose.palm_on(Vector3(0, 0.75, -0.65), Vector3(-s, 0, 0), lr == "_l"), 1.0)


# --- Kamera ja apu ------------------------------------------------------------------

func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.05 * _shake
	_cam.fov = fov
	_cam.look_at_from_position(interior.to_global(eye + sh), interior.to_global(look))


## Kuvakulma, jolla korkeus h etäisyydellä d täyttää osuuden frac kuvan korkeudesta.
func _fov_for(d: float, h: float, frac: float) -> float:
	return rad_to_deg(2.0 * atan(h / (2.0 * d * frac)))


func _bone_w(c: Node3D, bone: String) -> Vector3:
	return interior.to_local(c.to_global(c.bone_position(bone)))


func _aud_center() -> Vector3:
	var s := Vector3.ZERO
	for a: Array in _aud:
		s += (a[0] as Node3D).position
	return s / maxf(_aud.size(), 1.0)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _ease(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


func _who(w: Variant) -> Node3D:
	if w is String:
		match w:
			"fan":
				return cast.get("fan")
			"bartender":
				return cast.bartender
	return (cast.audience as Array)[int(w)]


func _say(w: Variant, text: String) -> void:
	var c := _who(w)
	if c != null:
		_bub[c] = text


# --- Ääni (syntetisoitu) ------------------------------------------------------------

func _play(wav: AudioStreamWAV, db: float) -> void:
	_sfx.stream = wav
	_sfx.volume_db = db
	_sfx.play()


func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = bytes
	return w


## Pitkä viimeinen sävel: laulava ääni (perussävel ja yläsävelet), vibrato kasvaa, loppu häipyy.
func _note_wav() -> AudioStreamWAV:
	var dur := 2.7
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	var ph := 0.0
	for i in s.size():
		var t := i / RATE
		var vib := 1.0 + 0.012 * minf(t / 1.2, 1.0) * sin(TAU * 5.6 * t)
		ph += TAU * 392.0 * vib / RATE
		var env := minf(t / 0.06, 1.0) * clampf((dur - t) / 0.35, 0.0, 1.0)
		s[i] = env * 0.42 * (sin(ph) + 0.45 * sin(2.0 * ph) + 0.22 * sin(3.0 * ph) + 0.1 * sin(5.0 * ph))
	return _wav(s)


## Aplodit: satoja lyhyitä kohinapurskeita, tiheys nousee ja laskee; välissä vihellys.
func _applause_wav() -> AudioStreamWAV:
	var dur := 4.6
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 96
	var t := 0.0
	while t < dur:
		var dens := 14.0 + 70.0 * clampf(t / 0.8, 0.0, 1.0) * clampf((dur - t) / 1.2, 0.0, 1.0)
		t += rng.randf() * 2.0 / dens
		var start := int(t * RATE)
		var amp := rng.randf_range(0.15, 0.4)
		var lp := 0.0
		for j in int(0.03 * RATE):
			if start + j >= s.size():
				break
			var n := rng.randf_range(-1.0, 1.0)
			lp += (n - lp) * 0.55
			s[start + j] += (n - lp * 0.6) * amp * exp(-j / (0.005 * RATE))
	# Vihellys (liukuva sävel) 1,2 s kohdalla.
	var ph := 0.0
	for i in int(0.7 * RATE):
		var tt := i / RATE
		ph += TAU * (1500.0 + 900.0 * sin(PI * tt / 0.7)) / RATE
		var idx := int(1.2 * RATE) + i
		if idx < s.size():
			s[idx] += 0.12 * sin(ph) * sin(PI * tt / 0.7)
	return _wav(s)


## Messinkikello: kolme lyöntiä, epäharmoniset osasävelet vaimenevat.
func _bell_wav() -> AudioStreamWAV:
	var dur := 2.8
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	var parts := [[1.0, 1.0, 1.6], [2.0, 0.55, 2.4], [2.76, 0.4, 3.2], [5.4, 0.25, 5.0], [8.93, 0.12, 7.0]]
	for hit in [0.25, 0.7, 1.15]:
		var st := int(hit * RATE)
		for i in range(st, s.size()):
			var t := (i - st) / RATE
			var v := 0.0
			for p: Array in parts:
				v += float(p[1]) * exp(-t * float(p[2])) * sin(TAU * 1046.0 * float(p[0]) * t)
			s[i] += v * 0.16
	return _wav(s)


# --- Piirto -------------------------------------------------------------------------

func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 440, 24, 880, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for c: Node3D in _bub:
		if is_instance_valid(c):
			Room.bubble(_ui, _cam, c, _bub[c], 90.0, 120.0)
	for f: Array in _foam:
		var wp := interior.to_global(f[0])
		if _cam.is_position_behind(wp):
			continue
		var sp := _cam.unproject_position(wp)
		var al := clampf(1.0 - float(f[2]) / 0.8, 0.0, 1.0)
		_ui.draw_circle(sp, 3.0 + 3.0 * float(f[2]), Color(1.0, 0.98, 0.9, 0.85 * al))
	# Sävelen nuotit nousevat pelaajasta.
	if phase == "savel":
		var head := _cam.unproject_position(interior.to_global(_bone_w(_player, "Head")))
		for i in 5:
			var fr := fmod(_t * 0.6 + i * 0.21, 1.0)
			var np := head + Vector2(110.0 + 40.0 * sin(i * 1.7 + _t), -10.0 - fr * 200.0)
			var col := Color(1.0, 0.86, 0.35, 0.9 * (1.0 - fr))
			_ui.draw_circle(np, 8.0, col)
			_ui.draw_line(np + Vector2(7, 0), np + Vector2(7, -28), col, 3.0)
			_ui.draw_line(np + Vector2(7, -28), np + Vector2(17, -20), col, 3.0)
	if phase == "otsikko":
		var a := clampf((_t - 0.9) / 0.8, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.05, 0.3 * a))
		var y := vs.y * 0.17
		var title := "KARAOKEKUNINGAS"
		_draw_crown(Vector2(vs.x / 2.0, y - 92.0), a)
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 76, 12, Color(0.12, 0.04, 0.02, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 76, Color(1.0, 0.82, 0.35, a))
		var sr := Rect2(vs.x / 2.0 - 380, vs.y - 150.0, 760, 74)
		_ui.draw_rect(sr, Color(0.05, 0.04, 0.03, 0.75 * a))
		_ui.draw_multiline_string(font, sr.position + Vector2(18, 30), cast.lines.sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 36, 19, 3,
			Color(1.0, 0.94, 0.8, a))
	if _flash > 0.0:
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, _flash))


## Kultainen kruunu otsikon yllä: viisi sakaraa, helmet kärjissä.
func _draw_crown(c: Vector2, a: float) -> void:
	var w := 120.0
	var h := 56.0
	var pts := PackedVector2Array([c + Vector2(-w / 2, h / 2), c + Vector2(-w / 2, -h / 2), c + Vector2(-w / 4, h / 8),
		c + Vector2(0, -h / 2 - 8), c + Vector2(w / 4, h / 8), c + Vector2(w / 2, -h / 2), c + Vector2(w / 2, h / 2)])
	_ui.draw_colored_polygon(pts, Color(1.0, 0.78, 0.25, a))
	var outline := pts.duplicate()
	outline.append(pts[0])
	_ui.draw_polyline(outline, Color(0.35, 0.18, 0.03, a), 3.0)
	_ui.draw_rect(Rect2(c + Vector2(-w / 2, h / 2 - 12), Vector2(w, 12)), Color(0.85, 0.55, 0.12, a))
	for p in [pts[1], pts[3], pts[5]]:
		_ui.draw_circle(p, 7.0, Color(1.0, 0.95, 0.75, a))
	for i in 3:
		_ui.draw_circle(c + Vector2(-30 + i * 30, h / 2 - 6), 5.0, [Color(0.85, 0.1, 0.15, a), Color(0.15, 0.4, 0.9, a), Color(0.1, 0.65, 0.3, a)][i])
