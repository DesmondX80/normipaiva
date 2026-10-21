extends Node3D
## Tanssit Saloisten seuraintalolla (#129), pelataan salin tanssilattialla: pelaaja ja tanssipari (salin oma Sinikka,
## Hilkka tai Anna-Liisa) tanssivat lattian keskellä, muut parit kiertävät ympärillä ja Saloisten Saapasjalat soittaa
## lavalla. Kamera kiertää paria hitaasti. Askeleet A ja D vuorotellen tahdissa: nuotit liukuvat ruudun alareunassa
## kohti osumarengasta, ja painallus osuman hetkellä vie paria eteenpäin. Väärä näppäin tai ohi tahdin: kompastus
## (horjahdus ja "Auts, varpaat!" puhekuplassa). Humala levittää ikkunaa mutta heiluttaa nuotteja. Kappale kestää SONG
## sekuntia. F / Esc lopettaa kesken (tulos tähän asti). Solmu lisätään salin (kirppis_interior.gd) lapseksi.
## finished(score 0..1).

signal finished(score: float)

const MG := preload("res://scripts/mg_draw.gd")
const Looks := preload("res://scripts/looks.gd")
const BPM := 112.0
const SONG := 24.0
const WINDOW := 0.15
const LEAD := 1.6  # sekuntia, jonka nuotti näkyy ennen osumaa
const SONGS := ["Saapasjalkavalssi", "Seuraintalon humppa", "Tokolan tango", "Saloisten letkajenkka"]
const PARTNER := {
	"sinikka_seura": {"name": "Sinikka", "hit": ["Hyvin viet!", "Ooh, sää osaat!", "Lähemmäs vaan..."], "miss": ["Auts, varpaat!", "Hups!"]},
	"hilkka": {"name": "Hilkka", "hit": ["Niin sitä ennen tanssittiin!", "Kevyt jalka!"], "miss": ["Varovasti, nuori mies!", "Lonkka, lonkka!"]},
	"annaliisa": {"name": "Anna-Liisa", "hit": ["Päivi ei kyllä tanssi näin hyvin.", "No kappas."],
		"miss": ["Tästä mää kerron Päiville!", "Auts! Kömpelö."]},
}

var partner := "hilkka"
var drunk := 0.0
var quit := false  # lopetettiin kesken (ei kuittaa tansseja)
var interior  # kirppis_interior.gd: salin pari piiloon tanssin ajaksi ja sen ulkonäkö

var _hud: CanvasLayer
var _ui: Control
var _info: Label
var _keys: Control
var _done := false
var _t := -1.5  # alkulaskenta
var _beat := 60.0 / BPM
var _beats: Array = []  # [aika, "A"/"D", tila: 0 tulossa, 1 osui, 2 ohi]
var _hits := 0
var _misses := 0
var _stumble := 0.0
var _song := ""
var _sparks: Array = []
var _turn := 0.0

var _me: Node3D
var _her: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _hidden: Node3D  # salin oma pari piilossa
var _cam: Camera3D
var _center := Vector3(0, 0, 0.6)


func _ready() -> void:
	var look: Dictionary = {"model": "female"}
	if interior != null:
		_center = interior.DANCE_C
		var i: int = interior.person_index(partner)
		if i >= 0:
			var p: Dictionary = interior.PEOPLE[i]
			look = p.look if p.has("look") else (Looks.SINIKKA if p.look_ref == "SINIKKA" else Looks.player())  # kuten salissa
			_hidden = interior._holders[i]
			_hidden.visible = false
		if interior.walker != null:
			interior.walker.visible = false
	_me = Looks.make(self, Looks.player())
	Looks.add_cap(_me)
	_her = Looks.make(self, look)
	for c in [_me, _her]:
		c.play("Idle", 0.0)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 44
	_bubble.pixel_size = 0.004
	_bubble.outline_size = 12
	_bubble.modulate = Color(1.0, 0.95, 0.85)
	_bubble.no_depth_test = true
	add_child(_bubble)
	_cam = Camera3D.new()
	_cam.fov = 48.0
	add_child(_cam)
	_cam.current = true
	_build_hud()
	_song = SONGS.pick_random()
	var n := int(SONG / _beat)
	for i in n:
		_beats.append([1.0 + i * _beat, "A" if i % 2 == 0 else "D", 0])
	_say(["Tanssitaanko?", "No niin, viepä sitten."].pick_random(), 2.5)
	_place(0.0)


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
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 24)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 7)
	_info.anchor_right = 1.0
	_info.offset_top = 24.0
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_info)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	_hud.add_child(_keys)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_stumble = maxf(0.0, _stumble - delta)
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.text = ""
	MG.sparks_step(_sparks, delta)
	_ui.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		quit = not _done
		_finish()
		return
	if _t >= 0.0 and _me.current() != "Dance":
		_me.play("Dance", 0.3, BPM / 104.0)
		_her.play("Dance", 0.3, BPM / 104.0)
	var win := WINDOW * (1.0 + drunk * 0.5)
	for key in [["left", "A"], ["right", "D"]]:
		if Input.is_action_just_pressed(key[0]):
			_press(key[1], win)
	for b in _beats:  # ohi menneet
		if b[2] == 0 and _t - b[0] > win:
			b[2] = 2
			_miss()
	if _t > 0.0:
		_turn += delta * (0.7 if _stumble <= 0.0 else -0.4)
	_place(delta)
	if _t > SONG + 1.5:
		_finish()
	_info.text = "%s · %s · osumat %d, kompastukset %d" % [PARTNER[partner].name, _song, _hits, _misses]
	_keys.set_text("%s / %s askel tahdissa   %s lopeta" % [Settings.cap("left"), Settings.cap("right"), Settings.cap("mount")])


## Pari pyörii lattian keskellä kasvokkain; kompastuessa pelaaja horjahtaa. Kamera kiertää hitaasti.
func _place(_delta: float) -> void:
	var sway := sin(_t * 1.3) * 0.35
	var jolt := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.06 * (_stumble / 0.4)
	var ax := Vector3(sin(_turn), 0, cos(_turn))
	var mid := _center + Vector3(sway, 0, 0)
	_me.position = mid - ax * 0.27 + jolt
	_her.position = mid + ax * 0.27 - jolt * 0.5
	# Kasvokkain: hahmo katsoo -Z:aan, joten käännös kohti toista.
	_me.rotation = Vector3(0, atan2(-ax.x, -ax.z) + PI, (_stumble / 0.4) * 0.25)
	_her.rotation = Vector3(0, atan2(-ax.x, -ax.z), 0)
	_bubble.position = _her.position + Vector3(0, 2.05, 0)
	var a := _t * 0.18 + 0.4
	var focus := mid + Vector3(0, 1.15, 0)
	# Kiertorata taustaparien radan ulkopuolella ja korkealla: muut parit kulkevat katseen alta.
	_cam.look_at_from_position(to_global(focus + Vector3(sin(a) * 5.0, 1.65, cos(a) * 3.8)), to_global(focus))


func _say(text: String, t := 2.0) -> void:
	_bubble.text = "%s: \"%s\"" % [PARTNER[partner].name, text]
	_bubble_t = t


func _press(key: String, win: float) -> void:
	var best: Array = []
	var bd := 1e9
	for b in _beats:
		if b[2] == 0 and absf(b[0] - _t) < bd:
			bd = absf(b[0] - _t)
			best = b
	if best.is_empty() or bd > win * 2.0:
		_miss()
		return
	if bd <= win and best[1] == key:
		best[2] = 1
		_hits += 1
		MG.sparks_burst(_sparks, _hit_pos(), Color(1.0, 0.85, 0.3), 10)
		Sfx.play("pickup", -14.0, 1.6 if key == "A" else 1.8)
		if randf() < 0.18:
			_say((PARTNER[partner].hit as Array).pick_random())
	else:
		best[2] = 2
		_miss()


func _miss() -> void:
	_misses += 1
	_stumble = 0.4
	Sfx.play("body_fall", -18.0, 1.6)
	if randf() < 0.35:
		_say((PARTNER[partner].miss as Array).pick_random())


func _finish() -> void:
	if _done:
		return
	_done = true
	if _hidden != null:
		_hidden.visible = true
	if interior != null and interior.walker != null:
		interior.walker.visible = true
	var total := float(maxi(1, _hits + _misses))
	finished.emit(clampf(_hits / maxf(total, float(_beats.size()) * 0.6), 0.0, 1.0))
	queue_free()


# --- HUD: nuottirata -----------------------------------------------------------

func _hit_pos() -> Vector2:
	return Vector2(_ui.size.x * 0.5, _ui.size.y * 0.84)


func _draw_ui() -> void:
	var sz := _ui.size
	var font := ThemeDB.fallback_font
	var hp := _hit_pos()
	MG.box(_ui, Rect2(Vector2(sz.x * 0.1, hp.y - 34), Vector2(sz.x * 0.8, 68)), Color(0, 0, 0, 0.55), 30)
	_ui.draw_arc(hp, 30.0, 0, TAU, 32, Color(1, 1, 1, 0.9), 4.0)
	for b in _beats:
		var dt: float = b[0] - _t
		if dt < -0.3 or dt > LEAD:
			continue
		var x := hp.x + dt / LEAD * sz.x * 0.38 * (-1.0 if b[1] == "A" else 1.0)
		var y := hp.y + sin(_t * 5.0 + b[0]) * drunk * 14.0
		var col := Color(0.35, 0.85, 1.0) if b[1] == "A" else Color(1.0, 0.6, 0.3)
		if b[2] == 1:
			col = Color(0.4, 1.0, 0.5, 0.5)
		elif b[2] == 2:
			col = Color(1.0, 0.25, 0.2, 0.5)
		MG.ball(_ui, Vector2(x, y), 22.0, col, 0.5)
		_ui.draw_string(font, Vector2(x - 12, y + 9), b[1], HORIZONTAL_ALIGNMENT_CENTER, 24, 24, Color(0.1, 0.1, 0.1))
	if _t < 0.0:
		_ui.draw_string_outline(font, Vector2(0, sz.y * 0.45), str(ceili(-_t)), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 80, 10, Color.BLACK)
		_ui.draw_string(font, Vector2(0, sz.y * 0.45), str(ceili(-_t)), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 80, Color(1.0, 0.9, 0.3))
	MG.sparks_draw(_ui, _sparks)
