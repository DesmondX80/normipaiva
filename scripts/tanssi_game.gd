extends Node3D
## Tanssit Saloisten seuraintalolla (#129), pelataan salin tanssilattialla: pelaaja ja tanssipari (salin oma Sinikka,
## Hilkka tai Anna-Liisa) tanssivat lattian keskellä, muut parit kiertävät ympärillä ja Saloisten Saapasjalat soittaa
## lavalla oikeaa biisiä (tanssibiisit.gd: "Pihalla tavataan" tai "Rasvanappi"). Kamera kiertää paria hitaasti. Askeleet A ja D
## vuorotellen biisin iskuilla: nuotit liukuvat ruudun alareunassa kohti osumarengasta, ja painallus osuman hetkellä vie
## paria eteenpäin. Alkusoitossa askel joka toisella iskulla, säkeistössä joka iskulla, kertosäkeessä tuplasteppejä,
## ja kertosäkeen lopun HEI!- tai HEP!-huutoon painetaan hyppyä (välilyönti): kipinät, tärähdys ja pari huutaa mukana. Tahti
## otetaan soivasta musiikista (Sfx.music_pos), joten nuotit pysyvät biisissä; ilman ääntä (headless) aika kulkee
## kehyksillä. Väärä näppäin tai ohi tahdin: kompastus (horjahdus ja "Auts, varpaat!" puhekuplassa). Humala levittää
## ikkunaa mutta heiluttaa nuotteja. Tanssi loppuu biisin "end"-kohdassa (musiikki häipyy). F / Esc lopettaa kesken
## (tulos tähän asti). Solmu lisätään salin (kirppis_interior.gd) lapseksi.
## finished(score 0..1).

signal finished(score: float)

const MG := preload("res://scripts/mg_draw.gd")
const Looks := preload("res://scripts/looks.gd")
const Contact := preload("res://scripts/contact.gd")
const Pose := preload("res://scripts/pose.gd")
const PariOte := preload("res://scripts/pari_ote.gd")
const Biisit := preload("res://scripts/tanssibiisit.gd")
const WINDOW := 0.15
const HEI_WINDOW := 0.3  # huudon ikkuna on väljempi: huuto ei osu iskuun yhtä tarkasti kuin askel
const LEAD := 1.6  # sekuntia, jonka nuotti näkyy ennen osumaa
const PARTNER := {
	"sinikka_seura": {"name": "Sinikka", "hit": ["Hyvin viet!", "Ooh, sää osaat!", "Lähemmäs vaan..."], "miss": ["Auts, varpaat!", "Hups!"]},
	"hilkka": {"name": "Hilkka", "hit": ["Niin sitä ennen tanssittiin!", "Kevyt jalka!"], "miss": ["Varovasti, nuori mies!", "Lonkka, lonkka!"]},
	"annaliisa": {"name": "Anna-Liisa", "hit": ["Päivi ei kyllä tanssi näin hyvin.", "No kappas."],
		"miss": ["Tästä mää kerron Päiville!", "Auts! Kömpelö."]},
}
# Tanssiote (Contact.pair_fit, PariOte.valssi): suljettu ote, pelaajan käsi parin lapaluulla, parin käsi pelaajan olkavarrella, vapaat kädet yhdessä.
const HOLD_LAHI := 0.25  # rintakehien spine_03-luiden väli ennen pair_fitiä (m): pienempi kuin kosketus, pair_fit erottaa

var partner := "hilkka"
var drunk := 0.0
var quit := false  # lopetettiin kesken (ei kuittaa tansseja)
var interior  # kirppis_interior.gd: salin pari piiloon tanssin ajaksi ja sen ulkonäkö
var contacts := true  # tanssiote kontaktilla (false: vanha, kädet animaation mukaan; kehysaikavertailu)
var look_override := {}  # parin ulkonäkö ilman salia (testi)
var perf := {}  # _holdin vaiheiden ajat: nimi -> [summa us, max us, kerrat] (kehysajan mittaus, tanssi_kontakti)
var prof := {}  # hahmo -> Contact.profile (paistetaan, kun luusto on valmis; headless: ei kontaktia)

var _hud: CanvasLayer
var _ui: Control
var _info: Label
var _keys: Control
var _done := false
var _t := 0.0  # biisin kohta (s)
var _bpm := 112.0
var _beats: Array = []  # [aika, "A"/"D"/"HEI", tila: 0 tulossa, 1 osui, 2 ohi]
var _hits := 0
var _misses := 0
var _stumble := 0.0
var _song: Dictionary = {}
var _fading := false
var _shake := 0.0  # HEI!-tärähdys (s)
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
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	process_priority = 1  # hahmojen animaation jälkeen: ote lasketaan ruudun lopulliseen asentoon
	var look: Dictionary = {"model": "female"}
	if interior == null and not look_override.is_empty():
		look = look_override
	if interior != null:
		_center = interior.DANCE_C
		var i: int = interior.person_index(partner)
		if i >= 0:
			var p: Dictionary = interior.PEOPLE[i]
			look = p.look if p.has("look") else (Looks.sinikka_seura() if p.look_ref == "SINIKKA" else Looks.player())  # kuten salissa
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
	_song = Biisit.SONGS.pick_random()
	_bpm = float(_song.bpm)
	_beats = Biisit.chart(_song)
	Sfx.music_play(0.3, 0.0, _song.file)
	seek(0.0)  # sama biisi voi vielä häipyä edellisestä tanssista: alusta
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
	var pos := Sfx.music_pos()
	# Headless (äänilaite ei soita) ja pysäytetty aika (time_scale 0, testien kuvat): aika kehyksistä.
	_t = pos if pos > 0.0 and Engine.time_scale > 0.0 else _t + delta
	_shake = maxf(0.0, _shake - delta)
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
	if _me.current() != "Dance":
		_me.play("Dance", 0.3, _bpm / 104.0)
		_her.play("Dance", 0.3, _bpm / 104.0)
	var win := WINDOW * (1.0 + drunk * 0.5)
	for key in [["left", "A"], ["right", "D"], ["jump", "HEI"]]:
		if Input.is_action_just_pressed(key[0]):
			_press(key[1], win)
	for b in _beats:  # ohi menneet
		if b[2] == 0 and _t - b[0] > _win(b, win):
			b[2] = 2
			_miss()
	if _t > 0.0:
		_turn += delta * (0.7 if _stumble <= 0.0 else -0.4)
	if contacts and prof.is_empty() and DisplayServer.get_name() != "headless" \
			and Engine.get_process_frames() >= int(_her.born_frame) + 3:
		var pm := Contact.profile(_me, Pose.limb_points)
		var ph := Contact.profile(_her, Pose.limb_points)
		if pm.measured and ph.measured:
			prof = {_me: pm, _her: ph}
	_place(delta)
	if not _fading and _t > float(_song.end) - float(_song.fade):
		_fading = true
		Sfx.music_stop(float(_song.fade))
	if _t > float(_song.end):
		_finish()
	_info.text = "%s · %s · %s · osumat %d, kompastukset %d" % [PARTNER[partner].name, _song.title, Biisit.osa(_song, _t), _hits, _misses]
	_keys.set_text("%s / %s askel tahdissa   %s %s   %s lopeta" % [Settings.cap("left"), Settings.cap("right"), Settings.cap("jump"), _song.huuto, Settings.cap("mount")])


## Pari pyörii lattian keskellä kasvokkain; kompastuessa pelaaja horjahtaa. Kamera kiertää hitaasti.
func _place(_delta: float) -> void:
	var sway := sin(_t * 1.3) * 0.35
	var jolt := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.06 * (_stumble / 0.4)
	var ax := Vector3(sin(_turn), 0, cos(_turn))
	var mid := _center + Vector3(sway, 0, 0)
	_me.position = mid - ax * 0.27 + jolt
	_her.position = mid + ax * 0.27 - jolt * 0.5
	# Kasvokkain: hahmo katsoo -Z:aan, joten pelaajan -Z = ax (kohti paria) ja parin -Z = -ax.
	_me.rotation = Vector3(0, atan2(-ax.x, -ax.z), (_stumble / 0.4) * 0.25)
	_her.rotation = Vector3(0, atan2(-ax.x, -ax.z) + PI, 0)
	if contacts and not prof.is_empty():
		_hold(smoothstep(0.0, 1.2, _t))
	_bubble.position = _her.position + Vector3(0, 2.05, 0)
	var a := _t * 0.18 + 0.4
	var focus := mid + Vector3(0, 1.15, 0) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.08 * (_shake / 0.5)
	# Kiertorata taustaparien radan ulkopuolella ja korkealla: muut parit kulkevat katseen alta.
	_cam.look_at_from_position(to_global(focus + Vector3(sin(a) * 5.0, 1.65, cos(a) * 3.8)), to_global(focus))


## Tanssiote painolla w (suljettu ote): jalat IK:lla animaatiosta (PariOte.legs_from_anim, väistävät itse), rintakehät
## lähelle ja pair_fit erottaa vartalot kosketukseen (pehmeät kohdat painuvat toisiaan vasten), sitten suljettu valssiote
## (PariOte.valssi: pelaajan käsi parin lapaluulla, parin käsi pelaajan olkavarrella, vapaat kädet yhdessä) ja pair_fit käsille.
func _hold(w: float) -> void:
	var pm: Dictionary = prof[_me]
	var ph: Dictionary = prof[_her]
	var t0 := Time.get_ticks_usec()
	PariOte.legs_from_anim(_me)
	PariOte.legs_from_anim(_her)
	t0 = _perf("legs", t0)
	# Pari lähelle ja puoli lantion leveyttä pelaajan oikealle (suljettu ote: kummankin oikea jalka toisen jalkojen välissä).
	var rm := PariOte.right(_me)
	var mfront := -PariOte.back(_me)
	var hip := _me.to_global(_me.bone_position("thigh_r")).distance_to(_me.to_global(_me.bone_position("thigh_l")))
	var ab := _her.to_global(_her.bone_position("spine_03")) - _me.to_global(_me.bone_position("spine_03"))
	_her.global_position += (mfront * (HOLD_LAHI - ab.dot(mfront)) + rm * (hip * 0.5 - ab.dot(rm))) * w
	var left := Contact.pair_fit(_me, pm, _her, ph, true, ["leg_l", "leg_r"], 4, false)
	t0 = _perf("fit_body", t0)
	if left > 0.006:
		Contact.pair_fit(_me, pm, _her, ph, true, ["leg_l", "leg_r"], 4, false)  # jäännös: vielä yksi kierrosjakso jaloille
		t0 = _perf("fit_legs2", t0)
	PariOte.valssi(_me, pm, _her, ph, self, w)
	t0 = _perf("valssi", t0)
	PariOte.fit(_me, pm, _her, ph, false, ["arm_l", "arm_r"], 8)
	_perf("fit_arms", t0)  # sisältää pair_contactsin (noin 0,6 ms)


## Kehysajan mittaus: vaiheen nm aika t0:sta perf-sanakirjaan; palauttaa nykyhetken (seuraavan vaiheen alku).
func _perf(nm: String, t0: int) -> int:
	var t := Time.get_ticks_usec()
	var e: Array = perf.get(nm, [0, 0, 0])
	perf[nm] = [e[0] + t - t0, maxi(e[1], t - t0), e[2] + 1]
	return t


func _say(text: String, t := 2.0) -> void:
	_bubble.text = "%s: \"%s\"" % [PARTNER[partner].name, text]
	_bubble_t = t


## Siirtää tanssin ja musiikin kohtaan t (s biisin alusta; testit). Ohitetut nuotit merkitään osutuiksi.
func seek(t: float) -> void:
	for b in _beats:
		if b[2] == 0 and b[0] < t - 0.2:
			b[2] = 1
	_t = t
	if Sfx.music_pos() >= 0.0:
		Sfx._music.seek(maxf(0.0, t))


## Nuotin osumaikkuna: HEI! on väljempi.
func _win(b: Array, win: float) -> float:
	return win * HEI_WINDOW / WINDOW if b[1] == "HEI" else win


func _press(key: String, win: float) -> void:
	var best: Array = []
	var bd := 1e9
	for b in _beats:
		if b[2] == 0 and absf(b[0] - _t) < bd:
			bd = absf(b[0] - _t)
			best = b
	if best.is_empty() or bd > _win(best, win) * 2.0:
		_miss()
		return
	if bd <= _win(best, win) and best[1] == key:
		best[2] = 1
		_hits += 1
		if key == "HEI":
			_hei()
			return
		MG.sparks_burst(_sparks, _hit_pos(), Color(1.0, 0.85, 0.3), 10)
		Sfx.play("pickup", -14.0, 1.6 if key == "A" else 1.8)
		if randf() < 0.18:
			_say((PARTNER[partner].hit as Array).pick_random())
	else:
		best[2] = 2
		_miss()


## HEI! osui: kipinäsade kolmella värillä, tärähdys ja pari huutaa mukana.
func _hei() -> void:
	for c in [Color(1.0, 0.85, 0.3), Color(1.0, 0.45, 0.3), Color(0.5, 0.9, 1.0)]:
		MG.sparks_burst(_sparks, _hit_pos(), c, 18)
	_shake = 0.5
	Sfx.play("win_small", -8.0)
	_say(_song.huuto, 1.5)


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
	Sfx.music_stop(1.0)
	for c in [_me, _her]:
		c.clear_ik()
	PariOte.clear_cache()
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
		if b[1] == "HEI":
			_draw_hei(b, dt, hp, sz, font)
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
	var wait: float = (_beats[0][0] - _t) if not _beats.is_empty() else 0.0  # alkusoitto: laskenta ensimmäiseen askeleeseen
	if wait > 0.0 and wait < 3.0:
		_ui.draw_string_outline(font, Vector2(0, sz.y * 0.45), str(ceili(wait)), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 80, 10, Color.BLACK)
		_ui.draw_string(font, Vector2(0, sz.y * 0.45), str(ceili(wait)), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 80, Color(1.0, 0.9, 0.3))
	MG.sparks_draw(_ui, _sparks)


## HEI!-nuotti putoaa ylhäältä renkaaseen: iso kultainen pallo, jossa huuto ja hyppynäppäin.
func _draw_hei(b: Array, dt: float, hp: Vector2, sz: Vector2, font: Font) -> void:
	var p := Vector2(hp.x, hp.y - dt / LEAD * sz.y * 0.42)
	var col := Color(1.0, 0.78, 0.2)
	if b[2] == 1:
		col = Color(0.4, 1.0, 0.5, 0.6)
	elif b[2] == 2:
		col = Color(1.0, 0.25, 0.2, 0.5)
	var r := 34.0 + (6.0 * sin(_t * 18.0) if b[2] == 0 else 0.0)
	MG.ball(_ui, p, r, col, 0.5)
	_ui.draw_string_outline(font, Vector2(p.x - 60, p.y + 10), _song.huuto, HORIZONTAL_ALIGNMENT_CENTER, 120, 30, 6, Color(0.25, 0.1, 0.0))
	_ui.draw_string(font, Vector2(p.x - 60, p.y + 10), _song.huuto, HORIZONTAL_ALIGNMENT_CENTER, 120, 30, Color(1.0, 0.98, 0.9))
	_ui.draw_string_outline(font, Vector2(p.x - 80, p.y + r + 24), Settings.cap("jump"), HORIZONTAL_ALIGNMENT_CENTER, 160, 20, 6, Color.BLACK)
	_ui.draw_string(font, Vector2(p.x - 80, p.y + r + 24), Settings.cap("jump"), HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color(1.0, 0.9, 0.5))
