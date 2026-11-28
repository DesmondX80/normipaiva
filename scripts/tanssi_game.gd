extends Node3D
## Tanssit Saloisten seuraintalolla (#129), pelataan salin tanssilattialla: pelaaja ja tanssipari (salin oma Sinikka,
## Hilkka tai Anna-Liisa) tanssivat lattian keskellä, muut parit kiertävät ympärillä ja Saloisten Saapasjalat soittaa
## lavalla oikeaa biisiä (tanssibiisit.gd: "Pihalla tavataan", "Rasvanappi" tai "Normipäivä"). Kamera kiertää paria hitaasti. Askeleet A ja D
## vuorotellen biisin iskuilla: nuotit liukuvat ruudun alareunassa kohti osumarengasta, ja painallus osuman hetkellä vie
## paria eteenpäin. Alkusoitossa askel joka toisella iskulla, säkeistössä joka iskulla, kertosäkeessä tuplasteppejä,
## ja kertosäkeen huutoon (HEI!, HEP! tai NORMIPÄIVÄ!) painetaan hyppyä (välilyönti): kipinät, tärähdys ja pari huutaa mukana. Tahti
## otetaan soivasta musiikista (Sfx.music_pos), joten nuotit pysyvät biisissä; ilman ääntä (headless) aika kulkee
## kehyksillä. Väärä näppäin tai ohi tahdin: kompastus (horjahdus ja "Auts, varpaat!" puhekuplassa). Humala levittää
## ikkunaa mutta heiluttaa nuotteja. Tanssi loppuu biisin "end"-kohdassa (musiikki häipyy). F / Esc lopettaa kesken
## (tulos tähän asti). Solmu lisätään salin (kirppis_interior.gd) lapseksi.
## finished(score 0..1).
##
## Legendaarinen hetki "tanssit" (endings.gd STAGED): ensimmäinen hyvä tanssi (pisteet ja Drakkar-bonus vähintään
## LEG_SCORE) ei pääty, vaan Saapasjalat jatkaa suoraan illan viimeiseen valssiin: salin valot himmenevät, kohdevalo
## parin päälle ja muut parit pysähtyvät (valssi), viimeisellä soinnulla pelaaja taivuttaa parin lattian keskellä ja
## lattia narahtaa (taivutus), kattolamput syttyvät yksi kerrallaan ja Anna-Liisa lupaa kertoa koko kylälle (valot),
## ja kultainen otsikko viirien kanssa (otsikko). Kutsuja (main.gd _start_tanssi) asettaa legend ja bonus.

signal finished(score: float)

const MG := preload("res://scripts/mg_draw.gd")
const Looks := preload("res://scripts/looks.gd")
const Contact := preload("res://scripts/contact.gd")
const Pose := preload("res://scripts/pose.gd")
const PariOte := preload("res://scripts/pari_ote.gd")
const Biisit := preload("res://scripts/tanssibiisit.gd")
const Room := preload("res://scripts/ilta_room.gd")
const B := preload("res://scripts/build.gd")
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
var song_index := -1  # >= 0: tämä Biisit.SONGS-kappale arvonnan sijaan (testi, toistettava ajo)
var frame_clock := false  # true: aika kehyksistä eikä soivasta musiikista (testi, toistettava ajo)

const LEG := ["valssi", "taivutus", "valot", "otsikko"]
const LEG_SCORE := 0.65  # sama raja kuin main.gd _tanssi_done (hyvä tanssi)
const LEG_LINES := {
	"hilkka": {"valssi": "Viiskytluvulla mää tanssin tällä samalla lattialla viimesen valssin. Ja nyt taas.",
		"taivutus": "Lonkka kesti! Kuulitteko? Lonkka kesti!",
		"juoru": "Hilkka taivutettiin! Huomenna sen tietää koko kylä, ja ylihuomenna Päivi.",
		"sub": "Saapasjalat soitti viimeisen valssin, valot himmenivät ja Hilkka taivutettiin lattian keskellä kuin viiskytluvulla. Lonkka kesti."},
	"sinikka_seura": {"valssi": "Älä päästä irti ennen ku biisi loppuu. Tai vasta sitte.",
		"taivutus": "Ooh... mää nään tähtiä. Ai, ne on viirit.",
		"juoru": "Mää näin kaiken! Huomenna koko Saloinen tietää, kenet Järvikujan mies taivutti.",
		"sub": "Saapasjalat soitti viimeisen valssin, valot himmenivät ja Sinikka taivutettiin lattian keskellä niin, että viirit pyöri. Anna-Liisa näki."},
	"annaliisa": {"valssi": "Mää en oo ollu näin pitkään hiljaa sitte kuuskytluvun.",
		"taivutus": "Älä päästä! Tästä mää en kerro kenellekään... paitsi kaikille.",
		"juoru": "Anna-Liisa hiljaa koko valssin. Tätä muistellaan tässä kahviossa vielä pitkään.",
		"sub": "Saapasjalat soitti viimeisen valssin, valot himmenivät ja Anna-Liisa taivutettiin lattian keskellä. Hän oli hiljaa koko valssin."},
}
## Muisto seuraavissa tansseissa (main.gd _enter_kirppis): Anna-Liisa tervehtii.
const LEG_MUISTO := ["Kas, se taivuttaja! Mää oon kertonu siitä valssista jo koko kylälle.",
	"Muistatko viimesen valssin? Koko Saloinen muistaa, mää pidin siitä huolen."]
var legend := false
var bonus := 0.0  # Drakkar Noir (main.gd _drakkar_dance): hyvän tanssin raja lasketaan samoin kuin tuloksessa
var staged := false  # legenda nähtiin: main.gd ei näytä tavallista tulosviestiä
var _phase := ""
var _leg_t := 0.0
var _leg_once := {}
var _leg_story := ""
var _leg_bub := {}  # hahmo -> repliikki (puhekupla puhujaan, Room.bubble)
var _spot: SpotLight3D
var _dip_ax := Vector3.FORWARD  # taivutuksen akseli pelaajalta parille
var _dip_mid := Vector3.ZERO
var _juoru: Node3D  # Anna-Liisa (tai Raili, kun Anna-Liisa on itse pari)
var _juoru_rot := 0.0
var _dancer_rot := {}  # taustatanssija -> alkuperäinen rotation.y
var _leg_dust: Array = []  # lattian pöly taivutuksessa: [maailman piste, liike, ikä]
var _walk: Array = []  # valssi: taustapari sivuun [juuri, mistä, mihin]

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
	_song = Biisit.SONGS[song_index] if song_index >= 0 else Biisit.SONGS.pick_random()
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
	if _phase in LEG:
		_leg_step(delta)
		_ui.queue_redraw()
		return
	var pos := Sfx.music_pos()
	# Headless (äänilaite ei soita) ja pysäytetty aika (time_scale 0, testien kuvat): aika kehyksistä.
	_t = pos if pos > 0.0 and Engine.time_scale > 0.0 and not frame_clock else _t + delta
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
		if not _leg_good():  # legenda: biisi soi suoraan viimeiseen valssiin
			Sfx.music_stop(float(_song.fade))
	if _t > float(_song.end):
		if _leg_good():
			_leg_begin()
			return
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
	_clear_thighs(pm, ph, mfront)
	PariOte.valssi(_me, pm, _her, ph, self, w)
	t0 = _perf("valssi", t0)
	PariOte.fit(_me, pm, _her, ph, false, ["arm_l", "arm_r"], 8, ["hand_l", "hand_r"])
	_perf("fit_arms", t0)  # sisältää pair_contactsin (noin 0,6 ms)


## Parin reisi (IK-ketju, pair_fit ei siirrä sen juurta) pelaajan mahan sisältä: pari vaakasuunnassa pelaajan etusuuntaan (mfront) syvimmän
## päällekkäisyyden verran miinus 6 mm (PARI-raja 10 mm; täysi erotus venyttäisi parin käden ulottumattomiin). Pelaajan löllerömaha (sag) työntyy reisien kohdalle, jolloin vartalokapselit erottava pair_fit jätti 26-29 mm.
func _clear_thighs(pm: Dictionary, ph: Dictionary, mfront: Vector3) -> void:
	for i in 3:
		var depth := 0.0
		for o: Array in Contact.overlap_pairs(_me, pm, _her, ph, 0.008):
			if str(o[1]).begins_with("thigh") and not str(o[0]).begins_with("thigh") and not str(o[0]).begins_with("calf"):
				depth = float(o[2])
				break
		if depth <= 0.008:
			return
		_her.global_position += Vector3(mfront.x, 0.0, mfront.z).normalized() * (depth - 0.006)
		_her.refresh_pose()


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
	if staged:
		_leg_restore()
	finished.emit(_score())
	queue_free()


## Tulos 0..1: osumat suhteessa osumiin ja hutiin, vähintään 60 % biisin nuoteista.
func _score() -> float:
	var total := float(maxi(1, _hits + _misses))
	return clampf(_hits / maxf(total, float(_beats.size()) * 0.6), 0.0, 1.0)


## Ensimmäinen hyvä tanssi lavastetaan (sama raja kuin main.gd _tanssi_done, Drakkar-bonus mukaan).
func _leg_good() -> bool:
	var s := _score()
	return legend and not staged and s > 0.0 and minf(1.0, s + bonus) >= LEG_SCORE


# --- HUD: nuottirata -----------------------------------------------------------

func _hit_pos() -> Vector2:
	return Vector2(_ui.size.x * 0.5, _ui.size.y * 0.84)


func _draw_ui() -> void:
	if _phase in LEG:
		_draw_legend()
		return
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
	var long := (_song.huuto as String).length() > 5  # pitkä huuto (NORMIPÄIVÄ!): isompi pallo, pienempi teksti
	var r := (56.0 if long else 34.0) + (6.0 * sin(_t * 18.0) if b[2] == 0 else 0.0)
	MG.ball(_ui, p, r, col, 0.5)
	var fs := 20 if long else 30
	_ui.draw_string_outline(font, Vector2(p.x - 120, p.y + fs * 0.33), _song.huuto, HORIZONTAL_ALIGNMENT_CENTER, 240, fs, 6, Color(0.25, 0.1, 0.0))
	_ui.draw_string(font, Vector2(p.x - 120, p.y + fs * 0.33), _song.huuto, HORIZONTAL_ALIGNMENT_CENTER, 240, fs, Color(1.0, 0.98, 0.9))
	_ui.draw_string_outline(font, Vector2(p.x - 80, p.y + r + 24), Settings.cap("jump"), HORIZONTAL_ALIGNMENT_CENTER, 160, 20, 6, Color.BLACK)
	_ui.draw_string(font, Vector2(p.x - 80, p.y + r + 24), Settings.cap("jump"), HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color(1.0, 0.9, 0.5))


# --- Legendaarinen hetki: tanssit ------------------------------------------------------------------------------

const DIP_TILT := 0.1  # parin kallistus taakse jalkojen ympäri (rad) syvimmillään; lantio siirtyy, joten DIP_IN kompensoi
const DIP_STEP := 0.12  # pelaajan askel parin luo (m)
const DIP_IN := 0.3  # pari lähemmäs (m)
const DIP_SIDE := 0.36  # pari pelaajan oikealle sivulle (taivutus tehdään viejän oikealla puolella, ei vatsaa vasten)
const DIP_ME_TURN := 0.4  # pelaaja kääntyy vasemmalle: oikea olka tulee eteen parin luo ja vatsa väistää
const DIP_BACK := 0.0  # käden kohta selkärangan (spine_02) takana (m): vyötärön kylki
const DIP_FLANK := 0.15  # ja kyljen pinnassa parin vasemmalla (m)


## Suunta (rotation.y), jolla hahmo katsoo kohti pistettä (hahmon etu on -Z).
static func _face(from: Vector3, to: Vector3) -> float:
	var f := to - from
	return atan2(-f.x, -f.z)


## Kamera salin avaruuden pisteestä toiseen (tärähdys mukaan).
func _leg_cam(eye: Vector3, look: Vector3, fov: float) -> void:
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.05 * _shake
	_cam.fov = fov
	_cam.look_at_from_position(to_global(eye + sh), to_global(look))


## Kattolamput (lamp), värivalot (party) ja kohdevalon energia (spot).
func _lights(lamp: float, party: float, spot: float) -> void:
	if interior != null:
		for i in interior.lamp_count():
			interior.set_lamp(i, lamp)
		interior.set_party(party)
	if _spot != null:
		_spot.light_energy = spot


func _leg_begin() -> void:
	_phase = "valssi"
	_leg_t = 0.0
	staged = true
	_leg_once.clear()
	_leg_bub.clear()
	_bubble.text = ""
	_sparks.clear()
	_info.visible = false
	_keys.set_text("%s ohita" % Settings.cap("interact"))
	_leg_story = "Saapasjalat jatkaa suoraan viimeiseen valssiin. Valot himmenevät, muut parit pysähtyvät."
	_spot = SpotLight3D.new()
	_spot.light_color = Color(1.0, 0.86, 0.62)
	_spot.spot_range = 7.0
	_spot.spot_angle = 22.0
	_spot.shadow_enabled = true
	_spot.light_energy = 0.0
	add_child(_spot)
	_spot.position = _center + Vector3(0, 3.5, 0)
	_spot.rotation = Vector3(-PI / 2.0, 0, 0)
	if interior != null:
		# Salin etuseinä on matala (kävelykamera kuvaa ylhäältä sen yli): kohtauksen ajaksi täysi seinä oven ympärille,
		# ettei taivas näy salin sisältä kuvattaessa. Lapsi tälle solmulle, joten se lähtee pelin mukana.
		var hy: float = interior.HALF.y
		var hx: float = interior.HALF.x
		var wh: float = interior.WALL_H
		for b: Array in [[Vector3(hx - 1.2, wh - 0.8, 0.12), Vector3(-(hx + 1.2) / 2.0, 0.8 + (wh - 0.8) / 2.0, hy)],
				[Vector3(hx - 1.2, wh - 0.8, 0.12), Vector3((hx + 1.2) / 2.0, 0.8 + (wh - 0.8) / 2.0, hy)],
				[Vector3(2.4, wh - 2.2, 0.12), Vector3(0, 2.2 + (wh - 2.2) / 2.0, hy)]]:
			B.mesh(self, B.boxm(b[0]), b[1], interior.PANEL)
		interior.hold_dancers = true
		var cg := to_global(_center)
		# Lattia tyhjenee: taustaparit kävelevät salin sivuille (kamerat kuvaavat edestä ja takaa).
		var slots := {-1: 0, 1: 0}
		for d: Node3D in interior._dancers:
			var sd := -1 if d.position.x < _center.x else 1
			var to := Vector3(sd * 4.4, 0, -0.9 + 1.5 * int(slots[sd]))
			slots[sd] = int(slots[sd]) + 1
			_walk.append([d, d.position, to])
			for k: Node3D in d.get_children():
				_dancer_rot[k] = k.rotation.y
				k.play("Walk", 0.3)
				k.rotation.y = _face(d.position, to) - d.rotation.y
		var i: int = interior.person_index("raili" if partner == "annaliisa" else "annaliisa")
		if i >= 0:
			_juoru = interior._people[i]
			_juoru_rot = _juoru.rotation.y
			_juoru.rotation.y = _face(_juoru.global_position, cg) - (_juoru.get_parent() as Node3D).global_rotation.y
	_me.play("Dance", 0.6, 0.7)
	_her.play("Dance", 0.6, 0.7)
	Sfx.play("whoosh", -12.0, 0.7)


func _leg_taivutus() -> void:
	_phase = "taivutus"
	_leg_t = 0.0
	_leg_bub.clear()
	_leg_story = "Viimeinen sointu. Lattian keskellä taivutetaan, ja vanha lattia narahtaa."
	# Kuva leikkaa sivukuvaan salin edestä (bändi taustalla): akseli lähimpään X-suuntaan ja pari lattian keskelle.
	# Etumerkki niin, että pari on pelaajan oikealla kameran puolella (+Z): taivutuksen kaari näkyy edessä.
	var rx0 := signf((_me.bone_position("upperarm_r") as Vector3).x)
	_dip_ax = Vector3(1, 0, 0)
	if (Basis(Vector3.UP, atan2(-1.0, 0.0)) * Vector3(1.0 if rx0 == 0.0 else rx0, 0, 0)).z < 0.0:
		_dip_ax = Vector3(-1, 0, 0)
	_dip_mid = _center
	for wk: Array in _walk:  # kesken jääneet kävelyt perille
		(wk[0] as Node3D).position = wk[2]
	for c: Node3D in [_me, _her]:
		c.clear_ik()
		c.play("Idle", 0.25)
	PariOte.clear_cache()
	Sfx.play("whoosh", -6.0, 0.9)


func _leg_valot() -> void:
	_phase = "valot"
	_leg_t = 0.0
	_leg_bub.clear()
	_leg_story = "Valot syttyvät yksi kerrallaan, ja sali herää."


func _leg_otsikko() -> void:
	_phase = "otsikko"
	_leg_t = 0.0
	_leg_bub.clear()
	_leg_story = ""
	if _juoru != null:
		_juoru.play("Idle", 0.3)
	for c: Node3D in [_me, _her]:
		c.clear_ik()
		c.clear_overrides()
		c.play("Dance", 0.4, 0.8)
	_lights(1.0, 1.0, 0.0)
	Sfx.play("win", -4.0)


## Salin tila takaisin legendan jälkeen: taustaparit tanssimaan, valot ja Anna-Liisan (tai Railin) katse.
func _leg_restore() -> void:
	if interior == null:
		return
	interior.hold_dancers = false
	for k: Node3D in _dancer_rot:
		if is_instance_valid(k):
			k.rotation.y = _dancer_rot[k]
			k.play("Dance", 0.3)
	for i in interior.lamp_count():
		interior.set_lamp(i, 1.0)
	interior.set_party(1.0)
	if _juoru != null:
		_juoru.rotation.y = _juoru_rot
		_juoru.play(_juoru.get_meta("pose"), 0.3)


## Taivutus painolla d (0 = seisten, 1 = syvin). Pari on pelaajan oikealla puolella (ei vatsaa vasten): pelaaja astuu,
## kääntyy vähän vasemmalle (oikea olka eteen) ja kumartuu parin ylle, pari kaartuu taakse (selkä ja
## kaula taipuvat, juuri kallistuu ja lantio pysyy pelaajan vieressä). Pelaajan oikea käsi parin selällä, parin oikea käsi pitää kiinni
## pelaajan oikeasta olkavarresta, parin vasen käsi kaartuu taakse alas ja pelaajan vasen käsi nousee sivulle. Hahmon etu
## on -Z, joten parin paikallinen +X-kierto kallistaa sen taakse (pelaajasta poispäin).
func _dip(d: float) -> void:
	var ax := _dip_ax
	var yaw := atan2(-ax.x, -ax.z)
	var rx0 := signf((_me.bone_position("upperarm_r") as Vector3).x)
	var side_r := Basis(Vector3.UP, yaw) * Vector3(1.0 if rx0 == 0.0 else rx0, 0, 0)  # pelaajan oikea salin avaruudessa
	var me_stand := _dip_mid - ax * (0.27 - DIP_STEP * d)
	var her_stand := _dip_mid + ax * (0.27 - DIP_IN * d) + side_r * DIP_SIDE * d
	_me.position = me_stand
	_her.position = her_stand
	_me.rotation = Vector3(0, yaw + DIP_ME_TURN * d * signf(rx0 if rx0 != 0.0 else 1.0), 0)
	_her.rotation = Vector3(DIP_TILT * d, yaw + PI, 0)
	# Luun kierto hahmon avaruudessa: tässä luurangossa +RIGHT taivuttaa selkää taakse ja -RIGHT eteen (kuvasta
	# tarkistettu: väärä etumerkki kumarsi parin pelaajan rintaan).
	_her.set_override("spine_01", Vector3.RIGHT, 0.22 * d)
	_her.set_override("spine_02", Vector3.RIGHT, 0.38 * d)
	_her.set_override("spine_03", Vector3.RIGHT, 0.32 * d)
	_her.set_override("neck_01", Vector3.RIGHT, 0.4 * d)
	_me.set_override("spine_01", Vector3.RIGHT, -0.18 * d)
	_me.set_override("spine_02", Vector3.RIGHT, -0.28 * d)
	_me.set_override("spine_03", Vector3.RIGHT, -0.18 * d)
	_me.set_override("neck_01", Vector3.RIGHT, -0.25 * d)
	var rxh := signf((_her.bone_position("upperarm_r") as Vector3).x)
	rxh = 1.0 if rxh == 0.0 else rxh
	var me_r := (global_basis * side_r).normalized()
	var her_back := (_her.global_basis * Vector3(0, 0, 1)).normalized()
	var her_l := (_her.global_basis * Vector3(-rxh, 0, 0)).normalized()
	var axg := (global_basis * ax).normalized()
	var down := Vector3.DOWN
	var mi := _me.global_basis.inverse()
	var hi := _her.global_basis.inverse()
	# Pelaajan oikea käsi parin vasemmalle vyötärölle, sormet kohti selkää.
	var blade := dip_target()
	var rsm: Vector3 = _me.to_global(_me.bone_position("upperarm_r"))
	_me.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", _me.to_local(blade), _me.to_local(rsm + me_r * 0.8 + axg * 0.35 + down * 0.2))
	_me.set_ik_orient("arm_r", Pose.palm_on(mi * _dip_fingers(her_back, her_l), mi * (-her_l), false), 1.0)
	# Parin oikea käsi pitää kiinni pelaajan oikeasta olkavarresta.
	var rsh: Vector3 = _her.to_global(_her.bone_position("upperarm_r"))
	var grip := dip_grip()
	_her.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", _her.to_local(grip), _her.to_local(rsh + down * 0.4 - her_l * 0.25))
	_her.set_ik_orient("arm_r", Pose.palm_on(hi * (-me_r * 0.3 + Vector3.UP * 0.2 + axg), hi * down, false), 1.0)
	# Pelaajan vasen käsi nousee sivulle (ta-daa), parin vasen käsi kaartuu taakse alas (taivutuksen kaari).
	var lsm: Vector3 = _me.to_global(_me.bone_position("upperarm_l"))
	var flourish := lsm - me_r * 0.42 + Vector3.UP * 0.3 + axg * 0.12
	_me.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", _me.to_local(flourish), _me.to_local(lsm - me_r * 0.3 + down * 0.3 - axg * 0.1))
	_me.set_ik_orient("arm_l", Pose.palm_on(mi * (flourish - lsm), mi * axg, true), 1.0)
	var lsh: Vector3 = _her.to_global(_her.bone_position("upperarm_l"))
	var fling := lsh + her_l * 0.2 + her_back * 0.4 + down * (0.2 + 0.12 * d)
	_her.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", _her.to_local(fling), _her.to_local(lsh + her_l * 0.3 + her_back * 0.1 + Vector3.UP * 0.25))
	_her.set_ik_orient("arm_l", Pose.palm_on(hi * (fling - lsh), hi * down, true), 1.0)


## Pelaajan oikean käden kohde parin vyötäröllä (maailmassa): vasen kylki keskiselän (spine_02) kohdalla.
## Selkärangan taakse asti pelaajan käsi ei yllä oman vatsansa ja parin vartalon yli.
func dip_target() -> Vector3:
	var rxh := signf((_her.bone_position("upperarm_r") as Vector3).x)
	var her_l := (_her.global_basis * Vector3(-(1.0 if rxh == 0.0 else rxh), 0, 0)).normalized()
	var back := (_her.global_basis * Vector3(0, 0, 1)).normalized()
	var p: Vector3 = _her.to_global(_her.bone_position("spine_02")) + back * DIP_BACK + her_l * DIP_FLANK
	if prof.has(_her):  # pinnalle: ranne ja sormenpäät parin vartalon kapselien ulkopuolelle (kämmen koskettaa)
		var caps := Contact.caps_all(_her, prof[_her])
		var tip := _dip_fingers(back, her_l) * 0.13
		for i in 4:
			var push := 0.0
			var n := Vector3.ZERO
			for q: Vector3 in [p, p + tip]:
				var cl: Array = Contact._clearance(q, caps, 0.065)
				if -float(cl[0]) > push:
					push = -float(cl[0])
					n = cl[1]
			if push <= 0.002:
				break
			p += n * (push + 0.003)
	return p


## Pelaajan oikean käden sormien suunta parin vyötäröllä: kylkeä pitkin ylös ja vähän selkään päin (pinnan suuntaisesti,
## ei vartalon sisään).
func _dip_fingers(back: Vector3, her_l: Vector3) -> Vector3:
	var f := Vector3.UP * 0.8 + back * 0.5
	return (f - her_l * f.dot(her_l)).normalized()


## Parin oikean käden kohde pelaajan oikeassa olkavarressa (maailmassa): hauiksen yläpinta.
func dip_grip() -> Vector3:
	var sh: Vector3 = _me.to_global(_me.bone_position("upperarm_r"))
	var el: Vector3 = _me.to_global(_me.bone_position("lowerarm_r"))
	return sh.lerp(el, 0.55) + Vector3.UP * 0.06


## Kameran rajaus valoihin (juoruaja puhuu): lavan edestä kohti salin etuosaa, jolloin juoruaja (Anna-Liisa tai Raili)
## katsoo paria ja samalla kameraan päin ja pari on keskellä; kuvakulma niin pieni, että kummankin pää ja jalat mahtuvat
## reunojen sisään. Palauttaa [silmä, katse, fov].
func _valot_cam() -> Array:
	var vs := get_viewport().get_visible_rect().size
	var m := _dip_mid
	var j := to_local(_juoru.global_position) if _juoru != null else m + Vector3(3, 0, 3)
	var eye := Vector3(m.x - (j.x - m.x) * 0.3, 2.2, m.z - 3.0)
	var look := m.lerp(j, 0.5) + Vector3(0, 0.9, 0)
	var pts: Array = [m + Vector3(0, 1.9, 0), m, j + Vector3(0, 2.0, 0), j]
	for fov in range(36, 82, 2):
		_leg_cam(eye, look, float(fov))
		var ok := true
		for p: Vector3 in pts:
			var sp := _cam.unproject_position(to_global(p))
			if _cam.is_position_behind(to_global(p)) or sp.x < vs.x * 0.06 or sp.x > vs.x * 0.94 or sp.y < vs.y * 0.2 or sp.y > vs.y * 0.94:
				ok = false
		if ok:
			return [eye, look, float(fov)]
	return [eye, look, 80.0]


func _leg_step(delta: float) -> void:
	_leg_t += delta
	_t += delta
	var t := _leg_t
	_shake = maxf(0.0, _shake - delta * 2.5)
	for pf: Array in _leg_dust:
		pf[2] += delta
	_leg_dust = _leg_dust.filter(func(pf: Array) -> bool: return pf[2] < 1.2)
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish()
		return
	var nm: String = PARTNER[partner].name
	match _phase:
		"valssi":
			var w := clampf((t - 0.3) / 2.4, 0.0, 1.0)
			for wk: Array in _walk:
				var dr: Node3D = wk[0]
				dr.position = (wk[1] as Vector3).lerp(wk[2], w)
				if w >= 1.0 and not _leg_once.has("perilla"):
					dr.rotation.y = 0.0
					for kc: Node3D in dr.get_children():
						kc.play("Idle", 0.3)
						kc.rotation.y = _face(kc.global_position, to_global(_center))
			if w >= 1.0:
				_leg_once.perilla = true
			var k := smoothstep(0.0, 1.6, t)
			_lights(1.0 - 0.82 * k, 1.0 - 0.9 * k, 7.0 * k)
			_turn += delta * 0.45
			_place(delta)
			var mid := (_me.position + _her.position) * 0.5
			_spot.position = mid + Vector3(0, 3.5, 0)
			var a := 0.5 + t * 0.12
			_leg_cam(mid + Vector3(sin(a) * 3.2, 1.45, cos(a) * 3.2), mid + Vector3(0, 1.0, 0), 40.0)
			if t > 2.2 and not _leg_once.has("rep"):
				_leg_once.rep = true
				_leg_bub[_her] = "%s: %s" % [nm, LEG_LINES[partner].valssi]
			if t > 6.6:
				_leg_taivutus()
		"taivutus":
			_dip(smoothstep(0.05, 0.95, t))
			_spot.position = _dip_mid + Vector3(0, 3.5, 0)
			if t > 0.95 and not _leg_once.has("sointu"):
				_leg_once.sointu = true
				Sfx.music_stop(0.35)
				Sfx.play("win", -4.0, 0.9)
				Sfx.play("step_wood", 0.0, 0.45)  # vanha lattia narahtaa
				_shake = 0.6
				for c: Node3D in [_me, _her]:  # pölypöllähdys lattiasta jalkojen ympäriltä
					for foot in ["foot_l", "foot_r"]:
						var st: Vector3 = c.to_global(c.bone_position(foot))
						st.y = global_position.y + 0.05
						for j in 4:
							var aa := TAU * j / 4.0 + randf() * 0.6
							_leg_dust.append([st, Vector3(cos(aa), 0, sin(aa)) * randf_range(0.2, 0.45), 0.0])
			if t > 1.5 and not _leg_once.has("rep"):
				_leg_once.rep = true
				_leg_bub[_her] = "%s: %s" % [nm, LEG_LINES[partner].taivutus]
			var push := smoothstep(0.0, 4.5, t)
			_leg_cam(_dip_mid + Vector3(0, 0.95, lerpf(3.4, 2.9, push)), _dip_mid + Vector3(0, 0.9, 0), 44.0)
			if t > 5.2:
				_leg_valot()
		"valot":
			if not _leg_once.has("ylos"):
				var d := 1.0 - smoothstep(0.4, 1.5, t)
				_dip(d)
				if d <= 0.0:
					_leg_once.ylos = true
					for c: Node3D in [_me, _her]:
						c.clear_ik()
						c.clear_overrides()
						c.rotation.x = 0.0
						c.play("Idle", 0.3)
			if interior != null:
				for i in interior.lamp_count():
					var on: bool = t >= 0.6 + 0.5 * i
					if on and not _leg_once.has("lamppu%d" % i):
						_leg_once["lamppu%d" % i] = true
						Sfx.play("step_hard", -2.0, 1.8)  # katkaisija naksahtaa
					interior.set_lamp(i, 1.0 if on else 0.18)
				interior.set_party(0.1 + 0.9 * smoothstep(2.6, 3.2, t))
			_spot.light_energy = 7.0 * (1.0 - smoothstep(0.6, 2.8, t))
			if t < 2.8:  # parin takaa ylös kattoon: lamput syttyvät rivissä, pari suoristuu kuvan alaosassa
				_leg_cam(_dip_mid + Vector3(0, 0.8, 3.1), _dip_mid + Vector3(0, 2.3, -0.6), 62.0)
			else:
				if not _leg_once.has("cam"):
					_leg_once.cam = _valot_cam()
				var vc: Array = _leg_once.cam
				_leg_cam(vc[0], vc[1], vc[2])
			if t > 2.9 and not _leg_once.has("juoru") and _juoru != null:
				_leg_once.juoru = true
				_leg_bub[_juoru] = "%s: %s" % ["Raili" if partner == "annaliisa" else "Anna-Liisa", LEG_LINES[partner].juoru]
				_juoru.play("Idle_Talking", 0.2)
			if t > 7.0:
				_leg_otsikko()
		"otsikko":
			_turn += delta * 0.5
			_place(delta)
			var mid := (_me.position + _her.position) * 0.5
			var u := smoothstep(0.0, 1.0, clampf(t / 5.0, 0.0, 1.0))
			var a := 0.9 + t * 0.1
			_leg_cam(mid + Vector3(sin(a) * lerpf(2.9, 3.6, u), lerpf(1.3, 2.4, u), cos(a) * lerpf(2.9, 3.6, u)),
				mid + Vector3(0, lerpf(1.0, 1.5, u), 0), 48.0)
			if t > 6.5:
				_finish()


func _draw_legend() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _leg_story != "":
		var r := Rect2(vs.x / 2.0 - 440, 24, 880, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _leg_story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19,
			Color(1.0, 0.92, 0.75))
	for c: Node3D in _leg_bub:
		if is_instance_valid(c):
			Room.bubble(_ui, _cam, c, _leg_bub[c], 90.0, 120.0)
	for pf: Array in _leg_dust:
		var age: float = pf[2]
		var wp: Vector3 = pf[0] + (pf[1] as Vector3) * (1.0 - exp(-age * 3.0)) + Vector3(0, 0.1 * age, 0)
		if _cam.is_position_behind(wp):
			continue
		var sp := _cam.unproject_position(wp)
		var rr := 8.0 + 22.0 * age
		var al := 0.4 * clampf(1.0 - age / 1.2, 0.0, 1.0)
		_ui.draw_circle(sp, rr, Color(0.72, 0.62, 0.5, al))
		_ui.draw_circle(sp + Vector2(-rr * 0.25, -rr * 0.3), rr * 0.6, Color(0.85, 0.77, 0.66, al * 0.7))
	if _phase != "otsikko":
		return
	var a := clampf((_leg_t - 0.6) / 0.8, 0.0, 1.0)
	_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.05, 0.3 * a))
	var y := vs.y * 0.2
	# Viirinauha otsikon yllä kuten salin katossa: kolmiot heiluvat.
	var x0 := vs.x * 0.16
	var x1 := vs.x * 0.84
	var line := PackedVector2Array()
	for i in 25:
		var u := i / 24.0
		line.append(Vector2(lerpf(x0, x1, u), y - 104.0 + sin(PI * u) * 26.0))
	_ui.draw_polyline(line, Color(0.95, 0.9, 0.8, a), 2.5, true)
	var cols := [Color(0.9, 0.15, 0.12), Color(1.0, 0.85, 0.2), Color(0.2, 0.5, 1.0), Color(0.97, 0.97, 0.95)]
	for i in 16:
		var u := (i + 0.5) / 16.0
		var p := Vector2(lerpf(x0, x1, u), y - 104.0 + sin(PI * u) * 26.0)
		var sw := sin(_leg_t * 2.2 + i * 0.8) * 5.0
		var tri := PackedVector2Array([p + Vector2(-13, 0), p + Vector2(13, 0), p + Vector2(sw, 30)])
		_ui.draw_colored_polygon(tri, Color(cols[i % 4], a))
		var ol := tri.duplicate()
		ol.append(tri[0])
		_ui.draw_polyline(ol, Color(0.15, 0.08, 0.04, a), 1.5, true)
	var title := "SEURAINTALON TANSSIT"
	_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 72, 12, Color(0.12, 0.04, 0.02, a))
	_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 72, Color(1.0, 0.82, 0.35, a))
	var sr := Rect2(vs.x / 2.0 - 400, y + 30.0, 800, 74)
	_ui.draw_rect(sr, Color(0.05, 0.04, 0.03, 0.75 * a))
	_ui.draw_multiline_string(font, sr.position + Vector2(18, 30), LEG_LINES[partner].sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 36, 19, 3,
		Color(1.0, 0.94, 0.8, a))
