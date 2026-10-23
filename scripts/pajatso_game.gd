extends CanvasLayer
## Siitarin pajatso RAY:n 50 pennin pajatson (1966) mukaan (siitari_interior.gd "pajatso"): tiikkikehyksinen kaappi,
## lasin takana tummanpunainen lauta. Pelataan euron kolikoilla: taskussa on yleensä yksi, oikean kehyksen
## vaihtokone (D) vaihtaa kahden euron kolikon kahdeksi euroksi kahvaa vääntämällä, ja voittokourun kolikot käyvät
## suoraan peliin. Euro syötetään (E) yläkehyksen kiinnikkeen rakoon, josta se putoaa oikean reunan kanavaa alas
## lyöntipaikalle rakonauhan tasolle. Kolikkoa lyödään koneen kyljen laukaisimesta (rengaslenkki, prikkajono ja
## heittoliuska): lyönnin voima on ainoa, mitä pelaaja hallitsee, ja kolikko lähtee aina vasemmalle ja hieman ylös.
## Se lentää rakojen yli (laskettu lentorata, kimpoaa vasemmasta seinästä ja katosta) ja putoaa harmaalle nauhalle,
## jossa on yhdeksän rakoa: R (panos takaisin), 2, 3, 3, 14, 3, 3, 2, R euroa (oikean koneen 1:00, 1:50 ja 7:00
## viidenkymmenen pennin panoksella). Jokaisen raon portissa on kaksi jousitappia: hiljainen ja vino osuma kuoleutuu
## jouseen ja kolikko putoaa porttiin, kova osuma kimpoaa (seiskan jousi on jäykin). Ohi mennyt kolikko valuu
## suppiloa pitkin porttien kolikkoputkiin (näkyvä varanto, pot = putkien summa). Rakoon mennyt kolikko pinoutuu
## oman porttinsa putkeen ja vapauttaa sen lukituksen; maksuvipu (W) siirtää luistilevyä, joka pyyhkäisee voiton juuri
## siitä putkesta voittokouruun: tyhjästä putkesta kone maksaa tyhjää. Täysi putki valuu kassaan (TUBE_MAX).
## Laukaisin ei ole jousiase: sormi napsauttaa liipaisimen suoraan sisään, ja jousi vain palauttaa sen. Humala
## tärisyttää sormea.
## Siimahuijaus (Q, kerran päivässä, jos repussa on virveli tai onki): siima solmitaan kolikkoon, ja rakoon mennyt
## kolikko nykäistään (Q) takaisin ylös ja uudestaan raon läpi, kunnes siimaleikkuri katkaisee siiman tai isäntä
## näkee (caught: main.gd heittää ulos). Ohi mennyt siimakolikko vedetään takaisin käteen.
## Kone skaalautuu matalampaan ikkunaan. F / Esc lopettaa. finished(money, pot): rahat ja varanto pelin jälkeen.

signal finished(money: float, pot: int)
signal comment(text: String)

const MG := preload("res://scripts/mg_draw.gd")

const PRICE := 1.0
const G := 900.0           # painovoima, px/s²
const BW := 600.0          # lasin takainen lauta
const BH := 640.0
const COIN_R := 10.0
const PIN_R := 3.0
const LAUNCH := Vector2(589, 224)  # lyöntipaikka oikeassa reunassa rakonauhan tasolla, syöttökanavan pohjalla
const LAUNCH_ANG := 0.4    # lähtökulma vaakatasosta ylöspäin (rad)
const V_MIN := 60.0        # lyönnin nopeus voimalla 0 %..100 %
const V_MAX := 780.0       # täysi voima (pohjaanveto) lennättää vasemman laidan 2,00-porttiin
const TENSION_RATE := 0.55  # sormen jännitys (lyönnin voima) nousee E pohjassa, /s
const TENSION_THUMB := 0.32 # peukalotuella hitaammin
const TREMOR := 0.035      # jännittävän sormen tärinä (voimana)
const TREMOR_THUMB := 0.005
const FINGER := 0.04       # sormen lyönnin vaihtelu (nopeus ±), pohjaanvedossa 1 %
const SNAIF_STEP := 0.03   # snaiffaus: saatto jarruttaa lyöntiä
const TILT_CHANCE := 0.35  # tönäisy laukaisee tilt-hälyttimen
const BAND_Y := 250.0      # rakonauhan yläreuna
const GATE := 4.0          # kolikon keskikohdan suurin poikkeama raon keskeltä, jotta se menee tappien välistä
const GATE_SEVEN := 1.5    # seiskan portti on ahtaampi
const PIN_DX := 14.0       # tappiparin puoliväli
const SLOTS := [40.0, 105.0, 170.0, 235.0, 300.0, 365.0, 430.0, 495.0, 560.0]
## Raon voitto euroina: 0 = R (panos takaisin).
const PRIZES := [0, 2, 3, 3, 14, 3, 3, 2, 0]
## Porttien jousien jäykkyys 0..1 (RAY säätää): seiskassa jäykin, R-raoissa löysin.
const STIFF := [0.25, 0.25, 0.72, 0.7, 0.95, 0.75, 0.8, 0.8, 0.25]
## Kiinteät ohjaustapit nauhan yllä keskiraon molemmin puolin.
const GUIDES := [Vector2(202, 196), Vector2(398, 196), Vector2(137, 214), Vector2(463, 214)]
const TUBE_MAX := 22       # porttikohtaisen kolikkoputken koko: ylimenevä valuu kassaan
const TUBE_X := [96.0, 147.0, 198.0, 249.0, 300.0, 351.0, 402.0, 453.0, 504.0]  # putket portin järjestyksessä
const FRAME := 50.0        # kehyksen leveys vasemmalla
const FRAME_RIGHT := 84.0  # oikealla leveämpi: ikärajakyltti ja vaihtokone
const SLOT_IN := Vector2(589, -62)  # kolikkoaukko yläkehyksen kiinnikkeessä (laudan koordinaateissa), kanava suoraan alas
const INSERT_T := 0.4      # syötetty kolikko putoaa aukosta pidikkeeseen (s)
const CHANGER := Vector2(BW + FRAME_RIGHT / 2.0, 470)  # vaihtokoneen kahva oikeassa kehyksessä
const CHANGE_CUP_Y := 600.0  # vaihtorahojen kuppi kahvan alla
const CHANGE_T := 0.45     # kahvan vääntö ennen kuin kolikot kilahtavat kuppiin
const FRAME_TOP := 110.0
const FRAME_BOTTOM := 120.0
const CONTENT_H := BH + FRAME_TOP + FRAME_BOTTOM + 30.0
const MARGIN_TOP := 60.0   # ruudun pikseleinä: yläteksti
const MARGIN_BOTTOM := 100.0  # ja vihjeteksti ja näppäinrivi
const DIE_SOFT := 330.0    # jousi kuoleuttaa osuman, jonka normaalinopeus on alle DIE_SOFT·(1−jäykkyys)+DIE_MIN
const DIE_MIN := 80.0
const SIIMA_CUT := 0.3     # siimaleikkuri katkaisee siiman nykäisyssä
const SIIMA_SEEN := 0.15   # isäntä huomaa nykäisyn (kasvaa joka nykäisyllä ja humalassa)
const LINES := ["Kolikko pesään ja sormella liipaisimesta. Pajatso ei tykkää raakuudesta.",
	"Seiskan rako keskellä. Tapit on taivutettu niin, ettei sinne kukaan osu.",
	"Kuulemma Raahessa joku osui seiskaan kolme kertaa samana iltana."]

var money := 10.0
var coins := -1            # euron kolikot (tasku, voittokouru ja vaihtokoneen kuppi; osa rahoista); -1 = alussa rahoista
## Varanto porttien kolikkoputkissa; pot on niiden summa (main.gd antaa ja saa takaisin luvun, joka jaetaan tasan).
var tubes: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var pot: int:
	get:
		var n := 0
		for t in tubes:
			n += t
		return n
	set(v):
		v = clampi(v, 0, TUBE_MAX * tubes.size())
		for i in tubes.size():
			tubes[i] = v / tubes.size() + (1 if i < v % tubes.size() else 0)
var drunk := 0.0
## Siimahuijaus: main.gd antaa siima = true, jos repussa on virveli tai onki eikä siimaa ole tänään käytetty.
var siima := false
var siima_used := false    # siima solmittiin (main.gd: kerran päivässä)
var caught := false        # isäntä näki siiman: main.gd heittää ulos

var _root: Control
var _info: Label
var _keys: Control
var _tip: Label
var _board := Rect2()      # lauta virtuaalipikseleinä
var _scale := 1.0          # koneen skaalaus ruudulle
var _virt := Vector2.ZERO  # ruudun koko virtuaalipikseleinä
var _t := 0.0
var _done := false
var _end_t := -1.0         # kiinni jääneen pelin loppu (s)
var _power := 0.0          # lyönnin voima 0..1 (jännitys ja sormen tärinä)
var _tension := 0.0        # sormeen kerätty iskun voima
var _drawing := false
var _armed := false        # syöttävä E on päästetty
var _thumb := false        # peukalotuki
var _snaifs := 0
var _techs: Array = []     # tekniikat, joista on jo kerrottu
var _nudge_t := 0.0        # tönäisy vaimentaa portin jousta (s)
var _tilt_t := 0.0         # TILT-valo (s)
var _tilts := 0
var caught_reason := ""    # "siima" tai "tilt" (main.gd)
var _ring_t := 0.0         # lyöntirenkaan heilahdus (s jäljellä)
var _ready_frame := -1
## Kolikon tila: "" (ei kolikkoa), "ready" (pidikkeessä), "free" (lentää), "yank" (siimassa ylös raosta).
var _coin_state := ""
var _cp := Vector2.ZERO
var _cv := Vector2.ZERO
var _coin_t := 0.0
var _spin := 0.0
var _hit_cup := -1
var _hit_t := 0.0
var _shake := 0.0
var _sparks: Array = []
var _payout: Array = []    # putoavat kolikot: [paikka, nopeus, viive, "win" (voittokouruun) tai "change" (vaihtokupiin)]
var _tray := 0             # voittokourun kolikot (näkyvä kasa)
var _cup_coins := 0        # vaihtokoneen kupin kolikot
var _change_t := -1.0      # kahvan vääntö käynnissä (s), -1 = ei
var _change_paid := false
var _insert_t := 0.0
var _drops: Array = []     # suppiloa pitkin putkiin valuvat kolikot: [ikä, x, putki]
var _pending: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]  # porttien vapautetut voitot, maksetaan maksuvivulla
var _lever_t := 0.0        # maksuvivun ja luistilevyn liike (s)
var _last_power := 0.0
var _star := 0.0           # tähtipyörien kierto (maksu)
var _pop := ""
var _pop_t := 0.0
var _won := 0
var _shots := 0
var _clink_t := 0.0
var _tied := false         # pelissä oleva kolikko on siimassa
var _yanks := 0
var _yank_cup := -1        # siimakolikko raossa: Q nykäisee sen takaisin ylös
var _yank_t := 0.0
var _pin_hit := {}         # jousitapin joustoanimaatio: tappi -> [jäljellä s, siirtymä]


func _init() -> void:
	pot = 80


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_root)
	add_child(_root)
	_info = _label(24, 30.0, false)
	_keys = preload("res://scripts/hint_bar.gd").new()  # näppäinohjeet hattuina, näppäimet asetuksista
	_keys.compact = true
	_keys.centered = false
	add_child(_keys)
	_tip = _label(22, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	comment.connect(func(t: String) -> void: _tip.text = t)
	comment.emit(LINES.pick_random())
	if coins < 0:
		coins = mini(int(money), 1)  # taskussa yksi euron kolikko


func _label(size: int, y: float, bottom: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.anchor_right = 1.0
	if bottom:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var sz := _root.size
	_scale = minf(1.0, (sz.y - MARGIN_TOP - MARGIN_BOTTOM) / CONTENT_H)
	_virt = sz / _scale
	var spare := (sz.y - MARGIN_TOP - MARGIN_BOTTOM) / _scale - CONTENT_H
	_board = Rect2(Vector2(_virt.x / 2.0 - BW / 2.0 - 30.0, MARGIN_TOP / _scale + spare / 2.0 + FRAME_TOP), Vector2(BW, BH))
	_root.queue_redraw()
	_shake = maxf(0.0, _shake - delta * 3.0)
	_hit_t = maxf(0.0, _hit_t - delta)
	_pop_t = maxf(0.0, _pop_t - delta)
	_clink_t -= delta
	MG.sparks_step(_sparks, delta)
	_payout_step(delta)
	for k in _pin_hit.keys():
		_pin_hit[k][0] -= delta
		if _pin_hit[k][0] <= 0.0:
			_pin_hit.erase(k)
	if _end_t >= 0.0:
		_end_t -= delta
		if _end_t < 0.0:
			_finish()
		return
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish()
		return
	_striker(delta)
	for i in 4:
		_coin_step(delta / 4.0)
	_info.text = "PAJATSO · Rahaa %s € (euron kolikoita %d) · Varannossa %d kolikkoa" % [_eur(money), coins, pot]
	var q := Settings.cap("bell")
	var e := Settings.cap("interact")
	var tie := ("   %s siima kolikkoon" % q) if siima and not siima_used and not _tied else ""
	if _coin_state == "" and _yank_cup >= 0:
		_keys.set_text("%s nykäise siimasta   %s uusi kolikko (1 €)   %s lopeta" % [q, e, Settings.cap("mount")])
	elif _coin_state == "":
		var pay := ("%s MAKSUVIPU (%d)   " % [Settings.cap("forward"), _pending_total()]) if _pending_total() > 0 else ""
		_keys.set_text("%s%s syötä kolikko (1 €)   %s vaihtokone%s   %s lopeta" % [pay, e, Settings.cap("right"), tie,
			Settings.cap("mount")])
	elif _coin_state == "ready":
		_keys.set_text("%s pidä = kerää sormeen voimaa, päästä = napsauta laukaisinta   %s peukalotuki   %s saatto%s   %s lopeta" % [e,
			Settings.cap("jump"), Settings.cap("back"), tie, Settings.cap("mount")])
	elif _coin_state == "free":
		_keys.set_text("Kolikko lentää...   %s tönäise konetta (TILT!)   %s lopeta" % [Settings.cap("kick"), Settings.cap("mount")])
	else:
		_keys.set_text("Kolikko matkalla...   %s lopeta" % Settings.cap("mount"))


func _eur(v: float) -> String:
	return ("%.2f" % v).replace(".", ",").trim_suffix(",00")


## Lyönti kyljen laukaisimesta: ensimmäinen E syöttää kolikon kanavaan laukaisupesään (pystyssä). Laukaisinta ei
## viritetä: E pohjassa kerää sormeen voimaa (mitä pidempään, sitä kovempi isku) ja irrotus napsauttaa liipaisimen
## sisään; sen jousi vain palauttaa liipaisimen. Sormi tärisee (humalassa enemmän); peukalotuki (välilyönti pohjassa:
## peukalo kehyksen reunaan) poistaa tärinän, mutta voima kertyy hitaammin. Täysi voima lukittuu (pohjaanlyönti:
## liipaisin pohjaan, aina yhtä kova). S on snaiffaus: sormenpää saattaa liipaisinta ja jarruttaa iskua. Kolikon lennon
## aikana K tönäisee konetta: tärähdys vaimentaa portin jousta hetkeksi, mutta tilt-hälytin voi laueta. Q solmii
## siiman tai nykäisee siimakolikon. D vääntää vaihtokoneen kahvaa, W vetää maksuvipua.
func _striker(delta: float) -> void:
	_ring_t = maxf(0.0, _ring_t - delta)
	_nudge_t = maxf(0.0, _nudge_t - delta)
	_tilt_t = maxf(0.0, _tilt_t - delta)
	if Input.is_action_just_pressed("bell"):
		_siima_key()
	if Input.is_action_just_pressed("right"):
		_change()
	if Input.is_action_just_pressed("forward"):
		_collect()
	_lever_t = maxf(0.0, _lever_t - delta)
	_change_step(delta)
	if _coin_state == "free" and Input.is_action_just_pressed("kick"):
		_nudge()
	if _coin_state == "insert":
		# Kolikko putoaa kiinnikkeen raosta lasin taakse pidikkeeseen.
		_insert_t += delta
		if _insert_t >= INSERT_T:
			_coin_state = "ready"
			_ready_frame = Engine.get_process_frames()
			_cp = LAUNCH
			Sfx.play("glass", -14.0, 2.8)
		return
	if _coin_state == "ready":
		_thumb = Input.is_action_pressed("jump")
		var held := Input.is_action_pressed("interact")
		if not held:
			_armed = true  # syöttävä E päästetty: seuraava painallus jännittää
		if held and _armed:
			_drawing = true
			_tension = minf(1.0, _tension + delta * (TENSION_THUMB if _thumb else TENSION_RATE) * (1.0 + drunk * 0.3))
			if Input.is_action_just_pressed("back"):
				_tension = maxf(0.0, _tension - SNAIF_STEP)
				_snaifs += 1
				Sfx.play("cloth", -18.0, 2.4)
		var amp := 0.0 if _tension >= 1.0 else (TREMOR_THUMB + drunk * 0.03 if _thumb else TREMOR + drunk * 0.1)
		_power = clampf(_tension + (sin(_t * 13.0) + 0.6 * sin(_t * 7.1 + 1.3)) * amp / 1.6, 0.0, 1.0) if _drawing else 0.0
		if _drawing and not held:
			_flick()
		return
	if _coin_state != "" or not Input.is_action_just_pressed("interact"):
		return
	if coins < 1 or money < PRICE:
		if money - coins >= 2.0 - 0.001:
			comment.emit("Ei euron kolikoita. Kahden euron kolikko vaihtokoneeseen (%s) ja kahvasta väännetään." % Settings.cap("right"))
		elif money >= PRICE:
			comment.emit("Ei euron kolikkoa, ja vaihtokone ottaa vain kahden euron kolikoita.")
		else:
			comment.emit("Rahat loppu. Pajatso ei anna velaksi.")
		return
	_insert()


## Napautus: kyljen rengas iskee prikkajonon läpi heittoliuskaan ja liuska kolikkoon. Pohjaanveto on aina yhtä kova.
func _flick() -> void:
	var full := _tension >= 1.0
	_ring_t = 0.3
	_drawing = false
	Sfx.play("glass", -8.0, 2.2)
	if full:
		_tech("pohja", "Pohjaanlyönti! Laukaisin pohjaan asti: täysi voima, aina sama lento laitaporttiin.")
	elif _thumb:
		_tech("peukalo", "Peukalo kehyksen reunaan: käsi ei tärise, lyönti toistuu samanlaisena.")
	elif _snaifs > 0:
		_tech("snaiffi", "Snaiffaus: sormenpää saattoi rengasta ja jarrutti lyöntiä.")
	elif _tension < 0.4:
		_tech("pinta", "Pintalyönti: herkkä neppaus, kolikko lähti kevyesti.")
	_last_power = _power
	_launch(_power, 0.01 if full else FINGER)


func _tech(id: String, text: String) -> void:
	if not id in _techs:
		_techs.append(id)
		comment.emit(text)


## Vaihtokone: kahden euron kolikko rakoon ja kahvasta väännetään; kaksi euron kolikkoa kilahtaa kahvan alla olevaan
## kuppiin (rahat eivät muutu, vain kolikoiksi).
func _change() -> void:
	if _change_t >= 0.0:
		return
	if money - coins < 2.0 - 0.001:
		comment.emit("Kukkarossa ei ole kahden euron kolikkoa vaihdettavaksi.")
		return
	_change_t = 0.0
	_change_paid = false
	Sfx.play("coin", -8.0, 0.9)
	_tech("vaihto", "Kahden euron kolikko vaihtokoneeseen ja kahvasta väännetään: kaksi euron kolikkoa kuppiin.")


func _change_step(delta: float) -> void:
	if _change_t < 0.0:
		return
	_change_t += delta
	if not _change_paid and _change_t >= CHANGE_T:
		_change_paid = true
		Sfx.play("rattle", -10.0, 2.0)
		for k in 2:
			var at := _board.position + CHANGER + Vector2(randf_range(-4, 4), 64.0)
			_payout.append([at, Vector2(randf_range(-20, 20), randf_range(20, 60)), -k * 0.12, "change"])
	if _change_t > CHANGE_T + 0.5:
		_change_t = -1.0


## Tönäisy kylkeen kolikon lennon aikana: portin jousi vaimenee hetkeksi (osumaikkuna levenee), mutta tilt-hälytin
## laukeaa helposti; tiltissä kolikko menee, ja kolmannesta tiltistä isäntä heittää ulos.
func _nudge() -> void:
	_shake = 0.7
	Sfx.play("punch", -10.0, 1.3)
	if randf() < TILT_CHANCE + 0.1 * _tilts:
		_tilts += 1
		_tilt_t = 2.0
		_coin_state = ""
		_tied = false
		_to_tube(_cp.x)
		Sfx.play("alert", -6.0)
		_pop = "TILT"
		_pop_t = 1.6
		if _tilts >= 3:
			caught = true
			caught_reason = "tilt"
			_end_t = 2.2
			comment.emit("Isäntä: \"Kolmas tilt! Ei potkita pajatsoa. Ulos!\"")
		else:
			comment.emit("TILT! Tärinähälytin laukesi, kolikko meni. Isäntä katsoo pahasti tiskin takaa.")
		return
	_nudge_t = 0.4
	comment.emit("Tönäisy kylkeen: portin jousi vaimeni hetkeksi.")


## Euron kolikko voittokourusta, vaihtokupista tai taskusta kiinnikkeen rakoon.
func _insert() -> void:
	money -= PRICE
	if coins > 0:
		coins -= 1
		if _tray > 0:
			_tray -= 1
		elif _cup_coins > 0:
			_cup_coins -= 1
	_shots += 1
	_yank_cup = -1  # edellinen siimakolikko jää koneeseen
	_coin_state = "insert"
	_insert_t = 0.0
	_ready_frame = Engine.get_process_frames()
	_tension = 0.0
	_power = 0.0
	_drawing = false
	_armed = false
	_snaifs = 0
	_coin_t = 0.0
	_cp = SLOT_IN
	Sfx.play("coin", -10.0, 1.4)


## Lyönti voimalla p (0..1): kolikko lähtee vasemmalle ja hieman ylös. Sormi ei lyö koskaan täsmälleen samoin.
func _launch(p: float, spread := FINGER) -> void:
	_coin_state = "free"
	_cp = LAUNCH
	var v := lerpf(V_MIN, V_MAX, p) * randf_range(1.0 - spread, 1.0 + spread) * (1.0 + randf_range(-0.04, 0.04) * drunk)
	var ang := LAUNCH_ANG + randf_range(-0.03, 0.03)
	_cv = Vector2(-cos(ang), -sin(ang)) * v
	_coin_t = 0.0
	Sfx.play("whoosh", -12.0, 1.6)
	_shake = 0.25


## Q: siima kolikkoon (kerran päivässä) tai siimakolikon nykäisy raosta.
func _siima_key() -> void:
	if _yank_cup >= 0 and _coin_state == "":
		_yank()
		return
	if not (_coin_state in ["", "ready"]) or _tied:
		return
	if not siima or siima_used:
		comment.emit("Siimaa ei ole mukana. Virvelistä tai ongesta sen saisi." if not siima else "Siima on jo käytetty tänään.")
		return
	_tied = true
	siima_used = true
	Sfx.play("cloth", -8.0, 1.6)
	comment.emit("Siima solmittu kolikkoon. Kun se menee rakoon, nykäise se ylös ja uudestaan läpi. Isäntä katsoo tiskiltä...")


## Siimakolikko raon läpi uudestaan: isäntä voi nähdä (riski kasvaa), siimaleikkuri voi katkaista siiman, muuten
## kolikko nousee raosta ja putoaa samaan rakoon uudelleen (uusi voitto varannosta).
func _yank() -> void:
	_yanks += 1
	var seen := SIIMA_SEEN + 0.08 * (_yanks - 1) + drunk * 0.15
	var r := randf()
	if r < seen:
		caught = true
		caught_reason = "siima"
		_tied = false
		_yank_cup = -1
		_shake = 0.8
		_pop = "KIINNI!"
		_pop_t = 2.0
		_end_t = 2.2
		Sfx.play("lose", -4.0)
		comment.emit("Isäntä: \"Siima pajatsossa?! Ulos, ja heti!\"")
		return
	if r < seen + SIIMA_CUT:
		_tied = false
		_yank_cup = -1
		_shake = 0.3
		Sfx.play("rattle", -8.0, 2.6)
		comment.emit("Naps! Siimaleikkuri katkaisi siiman. Kolikko jäi koneeseen. Tämä temppu tunnetaan.")
		return
	tubes[_yank_cup] = maxi(0, tubes[_yank_cup] - 1)  # kolikko nousee raosta takaisin ylös
	_cp = Vector2(SLOTS[_yank_cup], BAND_Y + 14.0)
	_coin_state = "yank"
	_yank_t = 0.0
	_yank_cup = -1
	Sfx.play("whoosh", -14.0, 2.2)


func _coin_step(dt: float) -> void:
	if _coin_state in ["", "ready", "insert"]:
		return
	_coin_t += dt
	_spin += dt * _cv.length() * 0.05
	if _coin_state == "yank":
		# Siimassa ylös raosta ja takaisin alas tappien väliin.
		_yank_t += dt
		_cp.y -= 220.0 * dt
		if _yank_t >= 0.25:
			_coin_state = "free"
			_cv = Vector2(0, 30)
		return
	_cv.y += G * dt
	_cp += _cv * dt
	# Katto ja vasen seinä (lasin reunat); oikealla on lyöntipidikkeen seinä.
	if _cp.y < COIN_R:
		_cp.y = COIN_R
		_cv.y = absf(_cv.y) * 0.4
	if _cp.x < COIN_R:
		_cp.x = COIN_R
		_cv.x = absf(_cv.x) * 0.45
		_clink(absf(_cv.x) + 100.0)
	if _cp.x > BW - COIN_R:
		_cp.x = BW - COIN_R
		_cv.x = -absf(_cv.x) * 0.45
	# Porttien jousitapit: jousi ottaa osuman vastaan. Oikealla osumanopeudella kolikko kuoleentuu ja putoaa tapin
	# viereen; liian kova tai liian hiljainen osuma kimpoaa, ja jäykkä jousi ponnauttaa kovemmin (seiskassa jäykin).
	for i in SLOTS.size():
		var k: float = STIFF[i]
		for s in [-1.0, 1.0]:
			var pin := Vector2(SLOTS[i] + s * PIN_DX, BAND_Y - 12.0)
			var d := _cp - pin
			var dist := d.length()
			var md := COIN_R + PIN_R
			if dist < md and dist > 0.001:
				var nrm := d / dist
				_cp = pin + nrm * md
				var vn := _cv.dot(nrm)
				if vn < 0.0:
					# Jousi ottaa vastaan hiljaisen ja vinon osuman; jäykkä jousi (seiska) vain hyvin hiljaisen.
					var die := DIE_SOFT * (1.0 - k) + DIE_MIN
					if _nudge_t > 0.0:
						die *= 1.8  # tönäisy vaimensi jousen värähtelyn
					if absf(vn) < die:
						_cv = (_cv - nrm * vn) * 0.15 - nrm * vn * 0.05  # kuoleentuu: jousi söi vauhdin
					else:
						_cv = (_cv - nrm * vn) * 0.9 - nrm * vn * (0.55 + 0.4 * k)
					_pin_hit[i * 2 + (0 if s < 0.0 else 1)] = [0.25, -nrm * minf(absf(vn) / 120.0, 3.0)]
					_clink(absf(vn))
	# Kiinteät ohjaustapit: estävät suorat reitit reunoilta keskelle.
	for g in GUIDES:
		var d: Vector2 = _cp - g
		var dist := d.length()
		var md := COIN_R + PIN_R + 1.0
		if dist < md and dist > 0.001:
			var nrm := d / dist
			_cp = g + nrm * md
			var vn := _cv.dot(nrm)
			if vn < 0.0:
				_cv = (_cv - nrm * vn) * 0.9 - nrm * vn * 0.5
				_clink(absf(vn))
	# Rakonauha: tappien välistä rakoon, muuten nauhaan ja suppiloa pitkin varantoon.
	if _cp.y >= BAND_Y:
		for i in SLOTS.size():
			if absf(_cp.x - SLOTS[i]) < (GATE_SEVEN if PRIZES[i] >= 14 else GATE):
				_cup(i)
				return
		_lost()
	elif _coin_t > 8.0:
		_lost()


func _clink(speed: float) -> void:
	if speed > 60.0 and _clink_t <= 0.0:
		_clink_t = 0.05
		Sfx.play("glass", -26.0 + minf(speed / 60.0, 8.0), randf_range(2.6, 3.2))


## Kolikko rakoon: se pinoutuu portin omaan kolikkoputkeen ja vapauttaa putken lukituksen; voitto (R = panos takaisin)
## maksetaan maksuvivulla (_collect).
func _cup(i: int) -> void:
	_coin_state = ""
	_hit_cup = i
	_hit_t = 1.2
	_shake = 0.6
	var at := _board.position + Vector2(SLOTS[i], BAND_Y + 20.0)
	tubes[i] = mini(tubes[i] + 1, TUBE_MAX)
	_pending[i] += maxi(PRIZES[i], 1)
	MG.sparks_burst(_sparks, at, Color(1.0, 0.8, 0.3), 40 if PRIZES[i] >= 14 else 20)
	_pop = "R" if PRIZES[i] == 0 else "%d,00" % PRIZES[i]
	_pop_t = 1.6
	if PRIZES[i] == 0:
		Sfx.play("coin", -6.0, 1.1)
		comment.emit("R-portti aukesi: maksuvivusta (%s) panos takaisin." % Settings.cap("forward"))
	elif PRIZES[i] >= 14:
		Sfx.play("win", -4.0)
		comment.emit("SEISKA! Pääportti aukesi. Maksuvipua (%s), niin putki tyhjenee kouruun. Koko baari katsoo." %
			Settings.cap("forward"))
	else:
		Sfx.play("win_small", -6.0)
		comment.emit("Portti aukesi: maksuvipua (%s), niin luisti pyyhkäisee voiton kouruun." % Settings.cap("forward"))
	if _tied:
		_yank_cup = i
		comment.emit("Siima kolikossa! Nykäise se ylös ja uudestaan läpi, jos uskallat. Isäntä vilkuilee.")


func _pending_total() -> int:
	var n := 0
	for v in _pending:
		n += v
	return n


## Maksuvipu: luistilevy pyyhkäisee jokaisen vapautetun portin putken alapäästä voiton verran kolikoita kouruun.
## Tyhjästä putkesta tulee vähemmän tai ei mitään.
func _collect() -> void:
	if _pending_total() == 0:
		return
	_lever_t = 0.5
	Sfx.play("rattle", -8.0, 0.8)
	var paid := 0
	var short := false
	var k := 0
	for i in tubes.size():
		if _pending[i] == 0:
			continue
		var n := mini(_pending[i], tubes[i])
		short = short or n < _pending[i]
		tubes[i] -= n
		for j in n:
			var from := _board.position + Vector2(TUBE_X[i] + randf_range(-4, 4), BH - 56.0)
			_payout.append([from, Vector2(randf_range(-60, 60), randf_range(40, 120)), 0.12 - k * 0.07, "win"])
			k += 1
		paid += n
		_pending[i] = 0
	_won += paid
	_star = 0.0
	_pop = "+%d €" % paid if paid > 0 else "TYHJÄÄ!"
	_pop_t = 1.6
	if paid == 0:
		comment.emit("Putki oli tyhjä: kone maksoi tyhjää.")
	elif short:
		comment.emit("Putki loppui kesken: kone maksoi vain %d." % paid)


## Ohi mennyt kolikko suppilon jakotapin kautta vajaimpaan putkeen (täysi valuu kassaan).
func _to_tube(x: float) -> void:
	var best := 0
	for i in tubes.size():
		if tubes[i] < tubes[best]:
			best = i
	if tubes[best] < TUBE_MAX:
		tubes[best] += 1
	_drops.append([0.0, clampf(x, 20.0, BW - 20.0), best])


## Ohi: nauhaan ja suppiloa pitkin varantoon (täysi varanto valuu kassaan). Siimakolikko vedetään takaisin käteen.
func _lost() -> void:
	_coin_state = ""
	if _tied:
		money += PRICE
		coins += 1
		_shots -= 1
		Sfx.play("cloth", -10.0, 1.8)
		comment.emit("Ohi, mutta siimalla kolikko nousi takaisin käteen.")
		return
	_to_tube(_cp.x)
	Sfx.play("rattle", -16.0, 1.6)
	if randi() % 3 == 0:
		comment.emit(["Ohi. Varanto kasvaa, ja se kasvaa sulle.", "Tappi käänsi sen pois. Kolikko valui suppiloon.",
			"Melkein! Raon reuna kilautti sen nauhaan."].pick_random())


func _payout_step(delta: float) -> void:
	_star += delta * (8.0 if _lever_t > 0.0 else 0.0)
	var tray_y := _board.end.y + FRAME_BOTTOM - 40.0
	for p in _payout:
		p[2] += delta
		if p[2] < 0.0:
			continue
		p[1].y += G * delta
		p[0] += p[1] * delta
	var cup_y := _board.position.y + CHANGE_CUP_Y
	for i in range(_payout.size() - 1, -1, -1):
		var p: Array = _payout[i]
		if p[2] <= 0.0:
			continue
		if p[3] == "change" and p[0].y > cup_y:
			_payout.remove_at(i)
			_cup_coins += 1
			coins += 1
			Sfx.play("coin", -8.0, randf_range(1.2, 1.5))
		elif p[3] == "win" and p[0].y > tray_y:
			_payout.remove_at(i)
			_tray += 1
			coins += 1
			money += 1.0
			Sfx.play("coin", -10.0, randf_range(0.9, 1.3))
	for d in _drops:
		d[0] += delta
	_drops = _drops.filter(func(d): return d[0] < 0.7)


func _finish() -> void:
	for p in _payout:
		if p[3] == "win":
			money += 1.0  # kouruun matkalla olevat voitot taskuun
	_payout.clear()
	for i in tubes.size():  # maksamatta jääneet portit: pelaaja muistaa vetää vipua lähtiessään
		var n := mini(_pending[i], tubes[i])
		tubes[i] -= n
		money += n
		_pending[i] = 0
	if _coin_state == "ready" or _coin_state == "insert":
		money += PRICE  # lyömätön kolikko takaisin
	elif _coin_state != "":
		_to_tube(_cp.x)
	_done = true
	finished.emit(money, pot)
	queue_free()


# --- Piirto -------------------------------------------------------------------

func _draw_root() -> void:
	var font := ThemeDB.fallback_font
	_draw_bar_wall(_root.size)
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2(_scale, _scale))  # kone virtuaalipikseleinä
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 5.0
	var o := _board.position + shake
	var cab := Rect2(o - Vector2(FRAME, FRAME_TOP), Vector2(BW + FRAME + FRAME_RIGHT, BH + FRAME_TOP + FRAME_BOTTOM))
	_draw_cabinet(cab, o, font)
	_draw_board(o, font)
	_draw_reserve(o, font)
	_draw_band(o, font)
	_draw_guides(o)
	# Siima kolikosta kolikkoaukolle.
	if _tied and (_coin_state != "" or _yank_cup >= 0):
		var end: Vector2 = o + _cp
		if _coin_state == "" and _yank_cup >= 0:
			end = o + Vector2(SLOTS[_yank_cup], BAND_Y + 14.0)
		var line := PackedVector2Array()
		var a := o + SLOT_IN + Vector2(0, 26)  # siima kulkee kiinnikkeen raosta
		for k in 13:
			var t := k / 12.0
			line.append(a.lerp(end, t) + Vector2(0, sin(t * PI) * 22.0))
		_root.draw_polyline(line, Color(0.9, 0.95, 1.0, 0.75), 1.5, true)
	if _coin_state == "insert":
		_draw_inserting(o)
	elif _coin_state != "":
		_draw_coin(o + _cp, COIN_R)
	for d in _drops:
		_draw_coin(o + _drop_pos(d), COIN_R * 0.9)
	_draw_glass(o)
	_draw_striker(o, cab, font)
	_draw_tray(o, font)
	_draw_changer(o, font)
	for p in _payout:
		if p[2] >= 0.0:
			_draw_coin(p[0], COIN_R)
	MG.sparks_draw(_root, _sparks)
	_draw_meter(cab, o, font)
	if _pop_t > 0.0:
		var s := 64 if _pop.begins_with("+14") or _pop == "KIINNI!" else 48
		var al := clampf(_pop_t / 0.4, 0.0, 1.0)
		var py := o.y + 180.0 - (1.6 - _pop_t) * 40.0
		_root.draw_string_outline(font, Vector2(o.x, py), _pop, HORIZONTAL_ALIGNMENT_CENTER, BW, s, 10, Color(0.15, 0.05, 0.0, al))
		_root.draw_string(font, Vector2(o.x, py), _pop, HORIZONTAL_ALIGNMENT_CENTER, BW, s, Color(1.0, 0.85, 0.2, al))


## Ohi menneen kolikon reitti: nauhan alle, suppilon reunaa keskelle jakotapille ja siitä valitun putken päälle.
func _drop_pos(d: Array) -> Vector2:
	var t: float = d[0] / 0.7
	var x0: float = d[1]
	var f := clampf(t * 1.6, 0.0, 1.0)
	var funnel := Vector2(lerpf(x0, BW / 2.0, f), BAND_Y + 76.0 + 60.0 * f)
	if t < 0.6:
		return funnel
	var g := (t - 0.6) / 0.4
	return Vector2(lerpf(BW / 2.0, TUBE_X[d[2]], g), funnel.y + g * 30.0)


## Siitarin seinä pajatson takana: tumma puupaneeli, jukeboksin violetti hehku ja kattolampun valokeila.
func _draw_bar_wall(sz: Vector2) -> void:
	MG.wood(_root, Rect2(Vector2.ZERO, sz), Color(0.3, 0.18, 0.1), 90.0, 3, false)
	MG.grad_rect(_root, Rect2(Vector2(0, sz.y * 0.82), Vector2(sz.x, sz.y * 0.18)), Color(0.22, 0.14, 0.09), Color(0.12, 0.08, 0.05))
	_root.draw_line(Vector2(0, sz.y * 0.82), Vector2(sz.x, sz.y * 0.82), Color(0.1, 0.06, 0.03), 4.0)
	MG.glow(_root, Vector2(sz.x * 0.08, sz.y * 0.5), 260.0, Color(0.7, 0.3, 0.9, 0.7))
	MG.glow(_root, Vector2(sz.x * 0.5, -40), 520.0, Color(1.0, 0.85, 0.55, 0.5))
	var jb := Rect2(Vector2(sz.x * 0.02, sz.y * 0.3), Vector2(sz.x * 0.11, sz.y * 0.55))
	MG.box(_root, jb, Color(0.3, 0.12, 0.35), 40, 8, MG.OUTLINE, 3)
	MG.box(_root, jb.grow(-14), Color(0.75, 0.45, 0.85), 30)
	for k in 5:
		_root.draw_line(jb.position + Vector2(18, 30 + k * 26), jb.position + Vector2(jb.size.x - 18, 30 + k * 26), Color(1, 0.9, 0.5, 0.7), 3.0)
	_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.0, 0.0, 0.05, 0.25))


## Kaappi: tiikkijäljitelmäkehys (hieno syykuvio), harmaa metallikylki oikealla, RAY:n apilakyltti vasemmalla ylhäällä,
## ikärajakyltti ja kolikkoaukko oikeassa kehyksessä.
func _draw_cabinet(cab: Rect2, o: Vector2, font: Font) -> void:
	_root.draw_rect(Rect2(cab.position + Vector2(14, 16), cab.size), Color(0, 0, 0, 0.45))  # varjo seinällä
	# Suoraan edestä kylki ei näy: kyljen kahva työntyy kaapin oikean reunan yli (laukaisin, _draw_striker).
	# Maksuvipu (kyljen kahva) painuu alas, kun voitto maksetaan.
	var hy := o.y + 505.0 + sin(clampf(_lever_t / 0.5, 0.0, 1.0) * PI) * 12.0
	MG.box(_root, Rect2(Vector2(cab.end.x - 4, hy - 7), Vector2(30, 14)), Color(0.85, 0.86, 0.9), 6, 1, MG.OUTLINE, 1)
	_root.draw_line(Vector2(cab.end.x, hy - 3), Vector2(cab.end.x + 22, hy - 3), Color(1, 1, 1, 0.7), 1.5)
	if _pending_total() > 0 and int(_t * 3.0) % 2 == 0:
		_root.draw_string(font, Vector2(cab.end.x + 30, hy + 5), "◀ %s" % Settings.cap("forward"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(1.0, 0.85, 0.3))
	var teak := Color(0.62, 0.38, 0.2)
	_root.draw_rect(cab, teak)
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	for k in 120:  # tiikin syyt: pitkät aaltoilevat viivat pystyyn sivuilla ja vaakaan ylhäällä ja alhaalla
		var vertical := k < 60
		var col := teak.darkened(rng.randf_range(0.05, 0.3))
		var pts := PackedVector2Array()
		if vertical:
			var x := (cab.position.x + rng.randf_range(0, FRAME - 2)) if k % 2 == 0 \
				else (cab.end.x - FRAME_RIGHT + rng.randf_range(0, FRAME_RIGHT - 2))
			for s in 12:
				pts.append(Vector2(x + sin(s * 0.7 + k) * 2.5, cab.position.y + cab.size.y * s / 11.0))
		else:
			var top := k % 2 == 0
			var y := (cab.position.y + rng.randf_range(0, FRAME_TOP - 2)) if top else (o.y + BH + rng.randf_range(0, FRAME_BOTTOM - 2))
			for s in 12:
				pts.append(Vector2(cab.position.x + cab.size.x * s / 11.0, y + sin(s * 0.6 + k) * 2.0))
		_root.draw_polyline(pts, col, rng.randf_range(1.0, 2.5))
	_root.draw_rect(cab, MG.OUTLINE, false, 3.0)
	# Lasin upotus: tumma rako.
	_root.draw_rect(Rect2(o - Vector2(6, 6), Vector2(BW + 12, BH + 12)), Color(0.08, 0.06, 0.05))
	# RAY:n kyltti: musta laatta, valkoinen apila ja teksti.
	var plate := Rect2(cab.position + Vector2(60, 24), Vector2(214, 46))
	MG.box(_root, plate, Color(0.06, 0.06, 0.07), 3, 0, Color(0.7, 0.7, 0.72), 2)
	var cl := plate.position + Vector2(24, 23)
	for a in [-PI / 2.0, PI / 6.0, PI * 5.0 / 6.0]:
		_root.draw_circle(cl + Vector2(cos(a), sin(a)) * 7.0, 6.5, Color(0.95, 0.95, 0.95))
	_root.draw_line(cl, cl + Vector2(3, 14), Color(0.95, 0.95, 0.95), 2.5)
	_root.draw_string(font, plate.position + Vector2(46, 20), "RAHA-AUTOMAATTIYHDISTYS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.92, 0.92, 0.92))
	_root.draw_string(font, plate.position + Vector2(46, 36), "PENNINGAUTOMATFÖRENINGEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.92, 0.92, 0.92))
	# Kolikkoaukon kiinnike yläkehyksessä: kromilevy, pystyrako ja euron merkki.
	var bracket := Rect2(o + SLOT_IN - Vector2(17, 30), Vector2(34, 72))
	MG.box(_root, bracket, Color(0.8, 0.81, 0.85), 4, 2, MG.OUTLINE, 2)
	_root.draw_line(bracket.position + Vector2(4, 4), bracket.position + Vector2(4, bracket.size.y - 4), Color(1, 1, 1, 0.7), 2.0)
	_root.draw_rect(Rect2(o + SLOT_IN - Vector2(2.5, 18), Vector2(5, 30)), Color(0.04, 0.04, 0.05))
	for yy in [-24.0, 36.0]:
		_root.draw_circle(o + SLOT_IN + Vector2(0, yy), 2.5, Color(0.4, 0.4, 0.42))
	_root.draw_string(font, o + SLOT_IN + Vector2(-17, 28), "1 €", HORIZONTAL_ALIGNMENT_CENTER, 34, 12, Color(0.15, 0.15, 0.17))


## Lauta: tummanpunainen yläosa (kolikon lentoalue), pieni ohjelaatta oikealla ylhäällä, nauhan alla harmaa suppilo,
## mustat ohjauslistat ja T-tangot, sivuilla tähtipyörät.
func _draw_board(o: Vector2, font: Font) -> void:
	var red := Color(0.5, 0.09, 0.07)
	MG.grad_rect(_root, Rect2(o, Vector2(BW, BH)), red.lightened(0.05), red.darkened(0.15))
	_root.draw_colored_polygon(PackedVector2Array([o, o + Vector2(BW * 0.55, 0), o + Vector2(BW * 0.4, 14), o + Vector2(0, 14)]),
		Color(0.2, 0.03, 0.02, 0.6))  # yläreunan varjo
	var plate := Rect2(o + Vector2(BW - 150, 10), Vector2(110, 60))  # ohjelaatta
	_root.draw_rect(plate, Color(0.05, 0.05, 0.06))
	for k in 7:
		_root.draw_line(plate.position + Vector2(6, 9 + k * 7), plate.position + Vector2(plate.size.x - 6 - (k % 2) * 20, 9 + k * 7),
			Color(0.85, 0.85, 0.85, 0.7), 1.0)
	# Syöttökanava oikeassa reunassa: kiinnikkeestä suoraan alas laukaisupesään (kromikiskot), jossa kolikko odottaa
	# pystyssä; kyljen laukaisimen iskuri lyö sen vasemmalle kiskon alapään alta.
	var lp := o + LAUNCH
	var chrome := Color(0.75, 0.76, 0.8)
	_root.draw_rect(Rect2(Vector2(lp.x - COIN_R - 4, o.y), Vector2(3, LAUNCH.y - 26)), chrome)
	_root.draw_rect(Rect2(Vector2(o.x + BW - 3, o.y), Vector2(3, LAUNCH.y + COIN_R + 4)), chrome)
	_root.draw_rect(Rect2(lp + Vector2(-COIN_R - 6, COIN_R + 1), Vector2(COIN_R * 2 + 12, 5)), chrome)
	_root.draw_rect(Rect2(lp + Vector2(-COIN_R - 6, COIN_R + 1), Vector2(COIN_R * 2 + 12, 5)), MG.OUTLINE, false, 1.0)
	# Suppilo nauhan alla: harmaa V keskelle, mustat ohjauslistat, T-tangot.
	var gray := Color(0.66, 0.67, 0.7)
	_root.draw_colored_polygon(PackedVector2Array([o + Vector2(60, BAND_Y + 70), o + Vector2(BW - 60, BAND_Y + 70),
		o + Vector2(BW / 2.0 + 14, BAND_Y + 140), o + Vector2(BW / 2.0 - 14, BAND_Y + 140)]), gray)
	_root.draw_line(o + Vector2(60, BAND_Y + 70), o + Vector2(BW / 2.0 - 14, BAND_Y + 140), Color(0.4, 0.4, 0.42), 2.0)
	_root.draw_line(o + Vector2(BW - 60, BAND_Y + 70), o + Vector2(BW / 2.0 + 14, BAND_Y + 140), Color(0.4, 0.4, 0.42), 2.0)
	_root.draw_line(o + Vector2(BW / 2.0, BAND_Y + 140), o + Vector2(BW / 2.0, BAND_Y + 160), Color(0.08, 0.08, 0.08), 3.0)  # jakotappi
	for s in [-1.0, 1.0]:
		var c := o.x + BW / 2.0
		_root.draw_line(Vector2(c + s * 70, o.y + BAND_Y + 120), Vector2(c + s * 200, o.y + BAND_Y + 96), Color(0.06, 0.06, 0.06), 6.0)
		_root.draw_line(Vector2(c + s * 222, o.y + BAND_Y + 118), Vector2(c + s * 296, o.y + BAND_Y + 104), Color(0.06, 0.06, 0.06), 5.0)
		_root.draw_line(Vector2(c + s * 262, o.y + BAND_Y + 112), Vector2(c + s * 262, o.y + BAND_Y + 200), Color(0.06, 0.06, 0.06), 3.0)
		# Tähtipyörä ja vipu (maksukoneisto): pyörii maksaessa.
		var sc := Vector2(c + s * 262, o.y + BAND_Y + 222)
		var star := PackedVector2Array()
		for k in 10:
			var a: float = _star * s + TAU * k / 10.0
			star.append(sc + Vector2(cos(a), sin(a)) * (16.0 if k % 2 == 0 else 7.0))
		_root.draw_colored_polygon(star, Color(0.06, 0.06, 0.07))
		MG.ball(_root, sc + Vector2(s * -6, -22), 7.0, Color(0.75, 0.76, 0.8), 0.6)
		_root.draw_rect(Rect2(Vector2(sc.x - 16, sc.y + 40), Vector2(32, 40)), Color(0.05, 0.05, 0.06))
	# Alaosa: tummat pohjalevyt ja punaiset kulmalevyt.
	_root.draw_rect(Rect2(o + Vector2(0, BH - 60), Vector2(BW, 60)), Color(0.06, 0.05, 0.05))
	for s in [0.0, 1.0]:
		var dir: float = 1.0 - 2.0 * s
		_root.draw_colored_polygon(PackedVector2Array([o + Vector2(s * BW, BH - 46), o + Vector2(s * BW + dir * 230, BH - 30),
			o + Vector2(s * BW + dir * 230, BH), o + Vector2(s * BW, BH)]), red.darkened(0.1))
	for x in [70.0, 160.0, BW - 160.0, BW - 70.0]:
		_root.draw_circle(o + Vector2(x, BH - 18), 3.0, Color(0.85, 0.85, 0.88))


## Kolikkovaranto: jokaisella portilla oma pystysuora kolikkoputki (alumiininen aaltokouru), kolikot kasvot eteenpäin,
## putken alla portin voittokilpi; pohjalla luistilevy, joka liikkuu maksuvivusta. Auki oleva portti vilkkuu.
func _draw_reserve(o: Vector2, font: Font) -> void:
	var top := BAND_Y + 160.0
	var bottom := BH - 64.0
	for i in tubes.size():
		var x: float = o.x + TUBE_X[i]
		MG.grad_rect(_root, Rect2(Vector2(x - 16, o.y + top), Vector2(32, bottom - top)), Color(0.74, 0.76, 0.8), Color(0.55, 0.57, 0.6))
		for g in 3:  # aallot
			_root.draw_line(Vector2(x - 10 + g * 10, o.y + top), Vector2(x - 10 + g * 10, o.y + bottom), Color(0.62, 0.64, 0.68), 1.5)
		_root.draw_line(Vector2(x - 16, o.y + top), Vector2(x - 16, o.y + bottom), Color(0.4, 0.42, 0.45), 2.0)
		var n := mini(tubes[i], int((bottom - top - 10.0) / 15.0))
		for k in n:
			_draw_coin(Vector2(x, o.y + bottom - 12.0 - k * 15.0), 12.0, false)
		var open := _pending[i] > 0 and int(_t * 4.0) % 2 == 0
		var lr := Rect2(Vector2(x - 17, o.y + bottom + 4), Vector2(34, 14))
		_root.draw_rect(lr, Color(1.0, 0.85, 0.3) if open else Color(0.05, 0.05, 0.06))
		_root.draw_string(font, lr.position + Vector2(0, 11), "R" if PRIZES[i] == 0 else str(PRIZES[i]),
			HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 11, Color(0.1, 0.05, 0.0) if open else Color(0.9, 0.9, 0.9))
	# Luistilevy putkien alla: liukuu vivusta.
	var slide := sin(clampf(_lever_t / 0.5, 0.0, 1.0) * PI) * 26.0
	MG.box(_root, Rect2(Vector2(o.x + TUBE_X[0] - 24 + slide, o.y + bottom), Vector2(TUBE_X[8] - TUBE_X[0] + 48, 4)),
		Color(0.6, 0.61, 0.64), 1, 0, MG.OUTLINE, 1)


## Rakonauha: harmaa metallinauha, yhdeksän mustaa rakoa voittokilpineen ja niiden yllä tappiparit (ressut).
func _draw_band(o: Vector2, font: Font) -> void:
	var gray := Color(0.7, 0.71, 0.74)
	var band := Rect2(o + Vector2(0, BAND_Y), Vector2(BW, 70))
	MG.grad_rect(_root, band, gray.lightened(0.1), gray.darkened(0.08))
	_root.draw_line(band.position, band.position + Vector2(BW, 0), Color(0.95, 0.95, 0.97), 2.0)
	_root.draw_line(band.position + Vector2(0, 70), band.position + Vector2(BW, 70), Color(0.35, 0.36, 0.38), 2.0)
	for i in SLOTS.size():
		var sx: float = o.x + SLOTS[i]
		var lit := i == _hit_cup and _hit_t > 0.0 and int(_hit_t * 10.0) % 2 == 0
		var hole := Rect2(Vector2(sx - 16, o.y + BAND_Y + 6), Vector2(32, 26))  # rako
		_root.draw_rect(hole, Color(0.03, 0.03, 0.03))
		_root.draw_rect(Rect2(hole.position, Vector2(hole.size.x, 4)), Color(0.18, 0.18, 0.2))
		# Voittokilpi: musta, valkoiset numerot; seiska punaisella.
		var label := "R" if PRIZES[i] == 0 else "%d,00" % PRIZES[i]
		var lr := Rect2(Vector2(sx - 22, o.y + BAND_Y + 38), Vector2(44, 22))
		var bg := Color(0.75, 0.08, 0.08) if PRIZES[i] >= 14 else Color(0.05, 0.05, 0.06)
		_root.draw_rect(lr, bg.lightened(0.4) if lit else bg)
		_root.draw_rect(lr, Color(0.25, 0.25, 0.27), false, 1.5)
		_root.draw_string(font, lr.position + Vector2(0, 17), label, HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 15, Color(1, 1, 1))
		if lit:
			MG.glow(_root, Vector2(sx, o.y + BAND_Y + 20), 46.0, Color(1.0, 0.9, 0.4, 0.8))
		# Portin jousitapit: tapin takana kierrejousi ja säätöruuvi, tappi joustaa osumasta.
		for s in [-1.0, 1.0]:
			var base := o + Vector2(SLOTS[i] + s * PIN_DX, BAND_Y - 12.0)
			var hit: Array = _pin_hit.get(i * 2 + (0 if s < 0.0 else 1), [])
			var pin := base
			if not hit.is_empty():
				pin += hit[1] * sin(hit[0] / 0.25 * PI * 3.0) * (hit[0] / 0.25)
			var coil := PackedVector2Array()
			for k in 9:  # jousi tapista ylös säätöruuviin
				coil.append(base.lerp(pin, 1.0 - k / 8.0) + Vector2(2.0 if k % 2 == 0 else -2.0, -4.0 - k * 2.2))
			_root.draw_polyline(coil, Color(0.25, 0.25, 0.27), 1.2)
			_root.draw_circle(base + Vector2(0, -24), 2.4, Color(0.55, 0.56, 0.6))  # säätöruuvi
			_root.draw_line(base + Vector2(-1.5, -24), base + Vector2(1.5, -24), Color(0.2, 0.2, 0.22), 1.0)
			_root.draw_circle(pin + Vector2(1, 2), PIN_R, Color(0, 0, 0, 0.35))
			_root.draw_circle(pin, PIN_R, Color(0.72, 0.73, 0.76))
			_root.draw_circle(pin - Vector2(0.8, 0.8), PIN_R * 0.5, Color(1, 1, 1))


## Kiinteät ohjaustapit: mustat tapit pienellä messinkikannalla.
func _draw_guides(o: Vector2) -> void:
	for g in GUIDES:
		_root.draw_circle(o + g + Vector2(1, 2), PIN_R + 1.0, Color(0, 0, 0, 0.35))
		_root.draw_circle(o + g, PIN_R + 1.0, Color(0.08, 0.08, 0.09))
		_root.draw_circle(o + g - Vector2(0.8, 0.8), 1.4, Color(0.8, 0.65, 0.3))


## Lasi: hienot heijastusviirut ja kehyksen reuna.
func _draw_glass(o: Vector2) -> void:
	for k in 3:
		var x := 80.0 + k * 190.0
		_root.draw_colored_polygon(PackedVector2Array([o + Vector2(x, 0), o + Vector2(x + 36 + k * 10, 0),
			o + Vector2(x - 130 + k * 10, BH), o + Vector2(x - 170, BH)]), Color(1, 1, 1, 0.05))
	_root.draw_rect(Rect2(o, Vector2(BW, BH)), Color(0.15, 0.15, 0.17), false, 3.0)


## Laukaisin koneen kyljessä (kuten oikeassa koneessa) ja yläkehyksen TILT-valo.
func _draw_striker(o: Vector2, cab: Rect2, font: Font) -> void:
	# Laukaisin koneen kyljessä lyöntipaikan kohdalla: edestä näkyy vain kyljen yli työntyvä kiinnike ja syrjästä
	# rengaslenkki (liipaisin), jota sormi napsauttaa sisään.
	var y := o.y + LAUNCH.y
	var x := cab.end.x
	# Ei viritystä: liipaisin on ulkoasennossa, isku painaa sen sisään (sitä syvemmälle, mitä kovempi), jousi palauttaa.
	var snap := clampf(_ring_t / 0.3, 0.0, 1.0)
	var off := -sin(snap * PI) * (3.0 + _last_power * 11.0)
	MG.box(_root, Rect2(Vector2(x - 2, y - 20), Vector2(8, 40)), Color(0.8, 0.81, 0.85), 2, 1, MG.OUTLINE, 1)  # lista
	var block := Rect2(Vector2(x + 5 + off, y - 9), Vector2(14, 18))
	MG.box(_root, block, Color(0.84, 0.85, 0.89), 3, 0, MG.OUTLINE, 1)
	# Lenkki syrjästä: pyöreäpäinen kromitanko.
	var rc := Vector2(block.end.x + 13, y)
	MG.box(_root, Rect2(Vector2(block.end.x - 2, y - 4), Vector2(29, 8)), Color(0.86, 0.87, 0.91), 4, 0, MG.OUTLINE, 1)
	_root.draw_line(Vector2(block.end.x, y - 2), Vector2(rc.x + 10, y - 2), Color(1, 1, 1, 0.8), 1.5)
	if snap > 0.0:
		for k in 3:  # napautuksen viivat
			var a := -0.5 + k * 0.5
			_root.draw_line(rc + Vector2(cos(a), sin(a)) * 18.0, rc + Vector2(cos(a), sin(a)) * (18.0 + 12.0 * snap),
				Color(1, 1, 0.8, snap), 2.0)
	# TILT-valo yläkehyksessä.
	var lamp := Vector2(o.x + BW - 150, cab.position.y + 46)
	var lit := _tilt_t > 0.0 and int(_tilt_t * 6.0) % 2 == 0
	MG.box(_root, Rect2(lamp - Vector2(30, 14), Vector2(60, 28)), Color(0.06, 0.06, 0.07), 3, 0, Color(0.6, 0.6, 0.62), 1)
	_root.draw_string(font, lamp + Vector2(-30, 7), "TILT", HORIZONTAL_ALIGNMENT_CENTER, 60, 18,
		Color(1.0, 0.25, 0.2) if lit else Color(0.35, 0.1, 0.1))
	if lit:
		MG.glow(_root, lamp, 40.0, Color(1.0, 0.2, 0.15, 0.7))


## Syötetty kolikko: ensin kyljellään kiinnikkeen rakoon (näkyy kapeana), sitten lasin takana putoamassa pidikkeeseen.
func _draw_inserting(o: Vector2) -> void:
	var t := _insert_t
	if t < 0.12:
		var p := o + SLOT_IN + Vector2(0, -14 + t / 0.12 * 16.0)
		_root.draw_rect(Rect2(p - Vector2(2.5, COIN_R), Vector2(5, COIN_R * 2.0)), Color(0.86, 0.74, 0.38))
		_root.draw_rect(Rect2(p - Vector2(2.5, COIN_R), Vector2(5, COIN_R * 2.0)), MG.OUTLINE, false, 1.0)
		return
	var f := pow(clampf((t - 0.12) / (INSERT_T - 0.12), 0.0, 1.0), 2.0)
	_draw_coin(o + Vector2(LAUNCH.x, lerpf(-COIN_R, LAUNCH.y, f)), COIN_R)


## Oikean kehyksen kyltti kuten oikeassa koneessa: ikärajateksti ja vaihtokone (2 € → 2 × 1 €), sen alla musta
## väännettävä kahva ja kuppi, johon vaihtorahat kilahtavat.
func _draw_changer(o: Vector2, font: Font) -> void:
	var lab := Rect2(o + Vector2(BW + 12, 190), Vector2(FRAME_RIGHT - 24, 240))
	MG.box(_root, lab, Color(0.06, 0.06, 0.07), 2, 0, Color(0.6, 0.6, 0.62), 1)
	var white := Color(0.92, 0.92, 0.92)
	for k in 7:  # ikärajateksti pienellä
		_root.draw_line(lab.position + Vector2(6, 12 + k * 8), lab.position + Vector2(lab.size.x - 6 - (k % 3) * 5, 12 + k * 8),
			Color(0.85, 0.85, 0.85, 0.75), 1.2)
	_root.draw_line(lab.position + Vector2(6, 74), lab.position + Vector2(lab.size.x - 6, 74), white, 1.0)
	var slot := lab.position + Vector2(lab.size.x / 2.0, 100)
	MG.box(_root, Rect2(slot - Vector2(14, 18), Vector2(28, 36)), Color(0.8, 0.81, 0.85), 3, 0, MG.OUTLINE, 1)
	_root.draw_rect(Rect2(slot - Vector2(2, 12), Vector2(4, 22)), Color(0.04, 0.04, 0.04))
	var cx := lab.position.x
	var w := lab.size.x
	_root.draw_polyline(PackedVector2Array([Vector2(cx + 10, lab.position.y + 136), Vector2(cx + w / 2.0, lab.position.y + 128),
		Vector2(cx + w - 10, lab.position.y + 136)]), white, 2.0)
	_root.draw_string(font, Vector2(cx, lab.position.y + 158), "2 €", HORIZONTAL_ALIGNMENT_CENTER, w, 20, white)
	_root.draw_string(font, Vector2(cx, lab.position.y + 176), "VAIHTO-", HORIZONTAL_ALIGNMENT_CENTER, w, 10, white)
	_root.draw_string(font, Vector2(cx, lab.position.y + 188), "KONE", HORIZONTAL_ALIGNMENT_CENTER, w, 10, white)
	_root.draw_string(font, Vector2(cx, lab.position.y + 201), "väännä kahvasta", HORIZONTAL_ALIGNMENT_CENTER, w, 8, white)
	_root.draw_string(font, Vector2(cx, lab.position.y + 220), "2 × 1 €", HORIZONTAL_ALIGNMENT_CENTER, w, 12, white)
	_root.draw_polyline(PackedVector2Array([Vector2(cx + 10, lab.position.y + 226), Vector2(cx + w / 2.0, lab.position.y + 234),
		Vector2(cx + w - 10, lab.position.y + 226)]), white, 2.0)
	# Kahva: musta nuppi ja poikkikahva, joka kääntyy väännettäessä.
	var knob := o + CHANGER
	var turn := sin(clampf(_change_t / CHANGE_T, 0.0, 1.0) * PI) * PI * 0.5 if _change_t >= 0.0 else 0.0
	MG.box(_root, Rect2(knob - Vector2(24, 26), Vector2(48, 52)), Color(0.8, 0.81, 0.85), 4, 2, MG.OUTLINE, 1)
	for yy in [-20.0, 20.0]:
		_root.draw_circle(knob + Vector2(-18, yy), 2.0, Color(0.4, 0.4, 0.42))
	var dir := Vector2(cos(turn), sin(turn))
	_root.draw_line(knob - dir * 20.0, knob + dir * 20.0, MG.OUTLINE, 14.0)
	_root.draw_line(knob - dir * 20.0, knob + dir * 20.0, Color(0.1, 0.1, 0.11), 11.0)
	_root.draw_line(knob - dir * 18.0 + Vector2(0, -3), knob + dir * 18.0 + Vector2(0, -3), Color(0.35, 0.35, 0.38), 2.0)
	MG.ball(_root, knob, 12.0, Color(0.12, 0.12, 0.13), 0.5)
	# Kuppi: kromattu kouru, jossa vaihtorahat.
	var cup := Rect2(o + Vector2(CHANGER.x - 26, CHANGE_CUP_Y - 10), Vector2(52, 26))
	MG.grad_rect(_root, cup, Color(0.15, 0.15, 0.16), Color(0.05, 0.05, 0.06))
	for k in mini(_cup_coins, 8):
		_coin_flat(cup.position + Vector2(14 + (k % 3) * 12, cup.size.y - 7 - (k / 3) * 4))
	MG.box(_root, Rect2(cup.position + Vector2(-4, cup.size.y - 8), Vector2(cup.size.x + 8, 12)), Color(0.82, 0.83, 0.87), 3, 0,
		MG.OUTLINE, 1)


## Voittokouru kehyksen alareunassa: kromikahva edessä ja kolikot kourussa.
func _draw_tray(o: Vector2, font: Font) -> void:
	var r := Rect2(Vector2(o.x + BW / 2.0 - 120, o.y + BH + FRAME_BOTTOM - 54), Vector2(240, 34))
	MG.grad_rect(_root, r, Color(0.12, 0.12, 0.13), Color(0.04, 0.04, 0.05))
	for k in mini(_tray, 40):
		_coin_flat(r.position + Vector2(r.size.x / 2.0 + ((k * 37) % 150 - 75) * 1.2, r.size.y - 8 - (k / 10) * 4))
	var handle := Rect2(r.position + Vector2(-10, r.size.y - 6), Vector2(r.size.x + 20, 18))
	MG.box(_root, handle, Color(0.82, 0.83, 0.87), 4, 3, MG.OUTLINE, 2)
	_root.draw_line(handle.position + Vector2(8, 5), handle.position + Vector2(handle.size.x - 8, 5), Color(1, 1, 1, 0.8), 2.0)
	for s in [0.0, 1.0]:
		_root.draw_rect(Rect2(handle.position + Vector2(s * (handle.size.x - 16), -10), Vector2(16, 28)), Color(0.08, 0.08, 0.09))
	if _tray > 0:
		_root.draw_string(font, r.position + Vector2(0, -8), "Voitot kourussa: %d €" % _tray, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18,
			Color(1, 0.92, 0.6))


## Sormen jännitys (lyönnin voima) kaapin oikealla puolella: tärinä näkyy viivan heilumisena, pohjassa lukittu.
func _draw_meter(cab: Rect2, o: Vector2, font: Font) -> void:
	var bar := Rect2(Vector2(cab.end.x + 100, o.y + 320), Vector2(22, 220))
	MG.box(_root, bar.grow(4), Color(0.05, 0.05, 0.05, 0.8), 6)
	var p := _power if _coin_state == "ready" else 0.0
	var h := bar.size.y * p
	MG.grad_rect(_root, Rect2(Vector2(bar.position.x, bar.end.y - h), Vector2(bar.size.x, h)), Color(1.0, 0.3, 0.2), Color(0.3, 0.8, 0.3))
	for k in 5:
		var yy := bar.end.y - bar.size.y * k / 4.0
		_root.draw_line(Vector2(bar.position.x - 6, yy), Vector2(bar.position.x, yy), Color(1, 1, 1, 0.6), 2.0)
	_root.draw_string(font, bar.position + Vector2(-40, -12), "VOIMA", HORIZONTAL_ALIGNMENT_CENTER, 102, 18, Color.WHITE)
	if _coin_state == "ready" and _tension >= 1.0:
		_root.draw_string(font, bar.position + Vector2(-40, bar.size.y + 26), "POHJASSA", HORIZONTAL_ALIGNMENT_CENTER, 102, 16,
			Color(1.0, 0.85, 0.3))
	elif _coin_state == "ready" and _thumb:
		_root.draw_string(font, bar.position + Vector2(-40, bar.size.y + 26), "PEUKALO", HORIZONTAL_ALIGNMENT_CENTER, 102, 16,
			Color(0.7, 0.95, 0.7))


## Kolikko edestä: messinkinen reuna, kohokuvio ja kiilto (pyörivä, kun kolikko lentää).
func _draw_coin(p: Vector2, r: float, spin := true) -> void:
	_root.draw_circle(p + Vector2(1.5, 2.5), r, Color(0, 0, 0, 0.35))
	_root.draw_circle(p, r, Color(0.66, 0.54, 0.22))
	_root.draw_circle(p, r - 1.5, Color(0.86, 0.74, 0.38))
	_root.draw_arc(p, r * 0.7, 0, TAU, 16, Color(0.66, 0.54, 0.22), 1.0)
	_root.draw_string(ThemeDB.fallback_font, p + Vector2(-r * 0.45, r * 0.4), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.1),
		Color(0.55, 0.44, 0.16))
	var a := _spin if spin else 0.8
	_root.draw_line(p + Vector2(cos(a), sin(a)) * r * 0.3, p + Vector2(cos(a), sin(a)) * r * 0.8, Color(1, 1, 0.9, 0.7), 1.5)
	_root.draw_arc(p, r, 0, TAU, 20, MG.OUTLINE, 1.2, true)


## Kolikko kyljellään kourussa: litteä ellipsi.
func _coin_flat(p: Vector2) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		pts.append(p + Vector2(cos(a) * 10.0, sin(a) * 3.5))
	_root.draw_colored_polygon(pts, Color(0.88, 0.74, 0.32))
	pts.append(pts[0])
	_root.draw_polyline(pts, Color(0.45, 0.35, 0.1), 1.0)
	_root.draw_line(p + Vector2(-6, -1), p + Vector2(2, -2), Color(1, 0.95, 0.7), 1.5)
