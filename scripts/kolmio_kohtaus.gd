extends CanvasLayer
## Kolmiomittauksen (#255) kohtaukset 3D:nä (kolmiomittaus.gd): oma pieni lavastus omassa 3D-maailmassaan
## (SubViewport, own_world_3d, kuten minipelien lavat), hahmot Looks.make-hahmoja, repliikit tekstilaatikossa.
## E jatkaa, Esc ohittaa loppuun. finished(r) kertoo tuloksen main.gd:lle.
##   "ovi"    naisen ovi illalla: nainen ovella, kolmiomittaajat portaiden juurella lahjat molemmissa käsissä rinnan
##            edessä. Lahjat ojennetaan vuorotellen kuin itämaan tietäjät ja ne päätyvät kuistin pöydälle; jos pelaajan
##            lahja puuttuu, ovi paukahtaa kiinni (r.ok = false).
##   "vaara"  väärä ovi: joku muu avaa (mummo kepin kanssa, Pannu-Sulo kanisterin kanssa, ...) ja pelaaja perääntyy.
##   "aamu"   onnellinen loppu: aamukahvit naisen keittiössä, nainen kaataa kahvia, kaveri paistaa lettuja, mansikat,
##            kermavaahto ja ruusut maljakossa pöydällä.
## Luvun 6 kohde "koti" (#326, Kesäheila -96): ovi on pelaajan oma tiilitalo, ja ovella seisoo Päivi kerma- ja
## mansikkalaatikko käsissään (_box: mansikkarasia, kermavaahtopurkki pystyssä marjojen päällä). Sinikka nauraa
## eteisessä Päivin takana, Joni ja Esa portaiden juurella. Ei lahjojen ojentamista; valinta tulee main.gd:ltä
## kohtauksen jälkeen. Aamu on Päivin keittiössä (kerma ja mansikat syödään).
## Legendaarinen hetki "kesaheila" (legend, ensimmäinen kerta endings.counts mukaan): ovikohtaus lavastetaan.
##   kartta  Sytkärin kartalla kolme ympyrää piirtyy oikeista mittauksista (rings) ja leikkaa talon numero 1
##   kop     KOP KOP KOP, ovi tärähtää
##   ovi     ovi aukeaa: Päivi lavakuvan olkihattu päässä (sama hattu kuin profiilikuvassa), Sinikka nauraa takana
##   muisto  lähikuva Päivistä ja Sytkärin lavakuva -96 vieressä, sydän yhdistää kuvan hatun ja oikean hatun
##   kaverit vastakuva ovelta: Esa ja Joni portaiden juurella
##   kerma   Päivi ojentaa kerman ja mansikat, kermaa ja sydämiä pöllähtää
##   otsikko kultainen KESÄHEILA -96 ja tarina; sitten valinta (main.gd _kesaheila_valinta)
## Toistot (recall): tavallinen ovikohtaus, ja Päivi muistelee; hattu roikkuu eteisen naulassa.
## Lavastuksen koordinaatit: talon julkisivu z = 0 (+Z ulos pihalle), kynnys y = 0,5; keittiössä pöytä z = 0,75 ja
## hahmot sen takana kasvot +Z:aan (kamera edessä). Hahmo katsoo oletuksena -Z:aan, joten rotation.y = PI = kasvot ulos.

signal finished(r: Dictionary)

const MG := preload("res://scripts/mg_draw.gd")
const B := preload("res://scripts/build.gd")
const Pose := preload("res://scripts/pose.gd")
const Looks := preload("res://scripts/looks.gd")
const Gifts := preload("res://scripts/kolmio_lahjat_mallit.gd")
const Sytkari := preload("res://scripts/sytkari.gd")

var mode := "ovi"
var site := "saloinen"
var woman := "Minttu"
var friends: Array = ["Joni", "Esa"]
var gifts: Array = []  # [[antaja, lahja], ...]
var missing := ""  # pelaajan puuttuva lahja ("" = kaikki mukana)
var resident := {}  # väärä ovi: kolmiomittaus.gd WRONG_DOORS
var stats := ""  # aamun tilastorivi
var photo: Texture2D  # räsytupin legendan polaroid (tuppi_game.gd _snap_take): teipattu keittiön ikkunaan
var photo_new := false  # polaroid otettiin tänä yönä: kertoja mainitsee sen
var kiva := "rasvanappi"  # illan iltakiva (aamun repliikit): rasvanappi, tuppi, lettu, loyly, disko, karaoke
var lines: Array = []  # [puhuja, teksti]; rakennetaan _ready:ssä
var auto := true  # rivit etenevät itsestään 6,5 s välein (testi pysäyttää)
var legend := false  # koti: kesäheilan legenda lavastetaan (main.gd _kolmio_knock, ensimmäinen kerta)
var recall := false  # koti: legenda on jo nähty, Päivi muistelee
var rings: Array = []  # koti: kolmiomittauksen ympyrät ({c, m, lo, hi, who}, kolmiomittaus.gd) Sytkärin kartalle
var home := Vector2.ZERO  # koti: oma etuovi maailmassa (kartan keskipiste)

var _view: Control
var _vp: SubViewport
var _stage: Node3D
var _cam: Camera3D
var _cam_base: Transform3D
var _t := 0.0
var _line := 0
var _line_t := 0.0
var _given := 0  # ojennettuja lahjoja
var _door := 1.0  # oven aukeama (0 kiinni, 1 auki)
var _door_to := 1.0
var _shake := 0.0
var _sparks: Array = []
var _done := false
var _ok := true
var _leaf: Node3D  # ovilehti saranasta (x = -0,5)
var _people := {}  # nimi -> hahmo
var _holding := {}  # nimi -> lahjan kappale (pidellään rinnan edessä)
var _props := {}  # nimi -> lahjan kappale
var _table_top := Vector3.ZERO  # kuistin pöytä, jolle ojennetut lahjat lasketaan
var _cane: Node3D
const PALM := 0.071  # rannekeskeltä nyrkin sormien pintaan (Idle-käsi on nyrkissä) + 3 mm rako, kun käsi on lahjan kyljellä (kolmio_kuvat _rako)
const PALM_FWD := 0.07  # kämmenen keskikohta ranteen edessä
## Päivin laatikko kämmenillä alta (_hold_under): ranteen keskeltä kämmenpinnan ja 3 mm raon päähän (PALM_UP),
## kämmenen keskikohta ranteen edessä (PALM_UP_FWD) ja kämmenten keskikohdat rasian pohjan sivuilla (PALM_UP_X).
## Naisen mallin Idle-käsi on auki ja peukalo sojottaa kämmenpuolelle: kyljiltä pidellen peukalo meni Idle-asennossa
## rasian seinän läpi (-0,025 m) ja Idle_Talkingissa kämmen kellui (0,02 m), joten rasia lepää kämmenillä ja peukalot
## nousevat rasian kylkien ulkopuolelle.
## Mitattu (kolmio_koti_kuvat _rako_rasia): PALM_UP 0,03 jätti kämmenen 8 mm pohjan alle ja PALM_UP_X 0,04 vei Idlen
## peukalon 14 mm kyljen sisään, joten kämmenet 5 mm ylemmäs ja 22 mm ulommas (pohjan reunoille, peukalot kylkien ohi).
const PALM_UP := 0.025
const PALM_UP_FWD := 0.06
const PALM_UP_X := 0.062
const GIFT_FIST := 0.07  # nyrkin yläreuna otteen (ranteen) yläpuolella (mitattu): kaltevan lahjan levein kohta nyrkin kohdalla
var _pancake: Node3D
var _pan_at := Vector3.ZERO
var _box: Node3D  # koti: Päivin kerma- ja mansikkalaatikko (_koti_box)
var _hat: Node3D  # koti: lavakuvan olkihattu (legendassa Päivin päässä, toistoissa eteisen naulassa)
var _offer := 0.0  # legenda: Päivi ojentaa laatikkoa (0..1)
var _card_vp: SubViewport  # legenda: Sytkärin lavakuva -96 (sytkari.gd studio)
var _map: Control  # legenda: Sytkärin kartta (rajattu puhelimen näyttöön)
var _title_t := -1.0  # legenda: otsikon aika (>= 0, kun rivit on käyty)
var _cue := -1  # legenda: viimeisin rivi, jonka äänet ja hiukkaset on soitettu
var _cue_t := 0.0
var _rings_shown := 0  # legenda: kartalle piirtyneet ympyrät (ääni kunkin alussa)
var _pin_done := false
var _hearts: Array = []  # legenda: [paikka, nopeus, ikä] kerman ojennuksessa
var _heart_t := 0.0
## Legendan rivien kestot (s): kartta 2, kop, ovi 2, muisto, kaverit 2, kerma; otsikko LEG_TITLE.
const LEG_T := [3.6, 3.0, 2.4, 3.8, 3.8, 5.0, 3.4, 3.4, 4.4]
const LEG_TITLE := 5.5
const LEG_SUB := "Kolme ympyrää leikkasi oman kodin. Ovella seisoi Päivi kerman ja mansikoiden kanssa."
const RING_COL := [Color(1.0, 0.45, 0.2), Color(0.2, 0.7, 0.95), Color(0.85, 0.25, 0.75)]

## 3D-hahmojen ulkonäöt (looks.gd). Väärien ovien asukkaat tässä.
const RESIDENTS := {
	"Mummo kepin kanssa": {"model": "female", "shirt": Color(0.56, 0.36, 0.55), "pants": Color(0.32, 0.24, 0.2),
		"shoes": Color(0.22, 0.14, 0.1), "shoe": "kavelykenka", "hair": "", "perm_col": Color(0.93, 0.92, 0.9), "round_glasses": true,
		"hair_color": Color(0.85, 0.85, 0.83), "height": 1.56,
		"skin": Color(1.0, 0.9, 0.86), "bulk": 0.35, "belly": 0.3, "shoulders": -0.4, "muscle": -1.0},
	"Pieni poika": {"shirt": Color(0.15, 0.35, 0.85), "pants": Color(0.2, 0.2, 0.25), "shoes": Color(0.2, 0.2, 0.2), "shoe": "lenkkari",
		"hair": "Hair_SimpleParted", "hair_color": Color(0.85, 0.72, 0.42), "height": 1.3, "bulk": -0.85, "shoulders": -0.8},
	"Verotoimiston Raimo": {"shirt": Color(0.85, 0.86, 0.9), "pants": Color(0.25, 0.27, 0.32), "shoes": Color(0.08, 0.08, 0.08), "shoe": "nauhakenka",
		"hair": "Hair_SimpleParted", "hair_color": Color(0.6, 0.58, 0.55), "height": 1.74, "belly": 0.55},
	"Unenpöpperöinen yövuorolainen": {"shirt": Color(0.6, 0.62, 0.66), "pants": Color(0.35, 0.36, 0.5),
		"shoes": Color(0.9, 0.9, 0.9), "shoe": "lenkkari", "hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.22, 0.15), "height": 1.8, "belly": 0.4},
}


func _look(nimi: String) -> Dictionary:
	match nimi:
		"Sinä":
			return Looks.player()
		"Minttu":
			return Looks.MINTTU
		"Katja":
			return Looks.KATJA
		"Joni":
			return Looks.JONI
		"Esa":
			return Looks.ESA
		"Hevari-Tero":
			return Looks.HEVARI_TERO
		"Sivikki-Timo":
			return Looks.SIVIKKI_TIMO
		"Pannu-Sulo":
			return Looks.SULO
		"Päivi", "Kesäheila -96":
			return Looks.PAIVI
		"Sinikka":
			return Looks.sinikka_seura()  # sisällä eteisessä ilman olkihattua
	return RESIDENTS.get(nimi, Looks.SULO)


func _ready() -> void:
	add_to_group("esc_lopettaa")
	layer = 7
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true  # oma maailma: pelin aurinko, sumu ja maasto eivät näy lavastuksessa
	_vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(_vp)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_all)
	add_child(_view)
	if site == "koti":
		woman = "Päivi"  # Kesäheila -96 on Päivi itse
	match "koti_ovi" if mode == "ovi" and site == "koti" else mode:
		"koti_ovi":
			_door = 0.0
			_door_to = 0.0
			if legend:
				lines = _koti_legend_lines()
			else:
				Sfx.play("punch", -6.0, 0.7)
				lines = _koti_lines()
				if recall:
					lines.insert(2, ["Päivi", "Taas sama kuva Sytkärissä? Se hattu roikkuu eteisen naulassa. Sää et vaan koskaan kato naulakkoa."])
			_build_porch()
			if legend or recall:
				_hat_setup()
			if legend:
				_leg_setup()
		"ovi":
			_door = 0.0
			_door_to = 0.0
			Sfx.play("punch", -6.0, 0.7)
			var smell := "Sandelsille" if site == "saloinen" else "bensalle ja Sivikin kytkimelle"
			lines = [["", "KOP KOP KOP"], [woman, "Kolme miestä, kolme lahjaa. Te ootte niinku itämaan tietäjät, paitsi että te haisette %s." % smell]]
			for g: Array in gifts:
				if g[0] == "Sinä" and missing != "":
					continue
				lines.append(["lahja", "%s ojentaa %s." % [g[0], g[1]]])
			if missing != "":
				_ok = false
				lines.append([woman, "Kaksi lahjaa. Missäs ne %s on?" % missing])
				lines.append([woman, "Tulkaa takasin, kun tietäjiä on kolme ja lahjoja kolme."])
			else:
				lines.append([woman, "Mää tunnistin sut profiilikuvasta. Ette te ois löytäny, jos mää en ois halunnu tulla löydetyksi."])
				lines.append([friends[0], _friend_intro(friends[0])])
				lines.append([friends[1], _friend_intro(friends[1])])
				lines.append([woman, "Tulkaa sisään. Pimennetään olohuone, mulla on parempi peli ku Sytkäri."])
			_build_porch()
		"vaara":
			_door = 0.0
			_door_to = 0.0
			Sfx.play("punch", -6.0, 0.7)
			lines = [["", "KOP KOP KOP"], [resident.who, resident.line], ["", resident.after]]
			_build_porch()
		"aamu":
			lines = _morning_lines()
			if photo_new:
				lines.insert(1, ["", "Yön polaroid on teipattu keittiön ikkunaan: kaverit kalsareissa, ja %s kikattaa sille kahvia kaataessaan." % woman])
			_build_kitchen()
	_line_t = 0.0
	_apply(0.0)


func _friend_intro(f: String) -> String:
	match f:
		"Joni":
			return "Joni, hcp kakskytkuus. Rinkassa on Sandelsia, jos tulee jano."
		"Esa":
			return "Esa. Erämies. Minä piirsin ne ympyrät."
		"Hevari-Tero":
			return "Tero. Valtio tietää jo, että me ollaan täällä."
		"Sivikki-Timo":
			return "Timo. Honda on tuossa. Se on lämmin vielä."
	return "Moi."


## Kodin ovi (luku 6): Päivi paljastaa olevansa Kesäheila -96, Sinikka nauraa takana.
func _koti_lines() -> Array:
	return [["", "KOP KOP KOP"],
		["Päivi", "No niin. Kolme miestä, harppi ja Sytkäri. Kesäheila -96 avaa oven."],
		["Sinikka", "HAHAHAHAA! Mää sanoin Päiville, että se pyyhkäsee oikealle eikä tunnista omaa vaimoaan!"],
		["Päivi", "Kuva on Saloisten lavalta, sinä kesänä ku me tavattiin. Sää et tunnistanu mua hatun alta."],
		[friends[1], "Ympyrät ei valehtele. Leikkauspiste oli koko ajan tässä."],
		[friends[0], "Tää on niinku ois lyöny pallon omaan ikkunaan."],
		["Sinikka", "Hihhih! Mää näin ikkunasta, ku te mittasitte meidän pihalla harpin kanssa!"],
		["Päivi", "Kerma ja mansikat on tässä. Nyt sää päätät, mitä tästä seuraa."]]


## Legendan rivit (rivi = vaihe, LEG_T): kartta, kop, ovi, muisto, kaverit, kerma.
func _koti_legend_lines() -> Array:
	return [["", "Sytkärin kartalla kolme ympyrää: Joni kaupalta, Esa kirkolta ja sinä kotikulmilta."],
		["", "Leikkauspiste: talo numero 1. Oma etuovi."],
		["", "KOP KOP KOP"],
		["Päivi", "No niin. Kolme miestä, harppi ja Sytkäri. Kesäheila -96 avaa oven."],
		["Sinikka", "HAHAHAHAA! Mää sanoin Päiville, että se pyyhkäsee oikealle eikä tunnista omaa vaimoaan!"],
		["Päivi", "Kuva on Saloisten lavalta, sinä kesänä ku me tavattiin. Sää et tunnistanu mua hatun alta."],
		[friends[1], "Ympyrät ei valehtele. Leikkauspiste oli koko ajan tässä."],
		[friends[0], "Tää on niinku ois lyöny pallon omaan ikkunaan."],
		["Päivi", "Kerma ja mansikat, niin ku silloin lavalla. Nyt sää päätät, mitä tästä seuraa."]]


## Aamun kaverirepliikit iltakivan mukaan (Rasvanapin rivit ovat _morning_lines-perusrivit): [kohde][kiva] = kaksi riviä.
const KIVA_AAMU := {
	"saloinen": {
		"tuppi": [["Esa", "Mää heräsin sohvalta kalsareissa. Tupessa nukkuu hyvin, se on vanha erämiesten tieto."],
			["Joni", "Rami ryöstettiin, ja housut lähti. Bogey, mutta tyylikäs bogey."]],
		"lettu": [["Esa", "Kakstoista lettua ja niin paljon kermaa, että Minttu joutu ravistaan purkkia kahella kädellä."],
			["Joni", "Mää otin kermat suoraan suuhun. Se on eagle, sitä ei hävetä."]],
		"loyly": [["Esa", "Pyyhe putos kolmannella heitolla, eikä kukaan ees kattonut. Se vähän harmitti."],
			["Joni", "Sadan asteen lauteilla mun putteri kutistu tiiksi asti."]],
		"karaoke": [["Esa", "Mää lauloin Mintulle rakkauslaulun hirven kiimasta. Ei kuulemma ollut romanttinen."],
			["Joni", "Mun falsetti kuulosti siltä, ku pallo ois osunu nivusiin."]]},
	"vaala": {
		"tuppi": [["Hevari-Tero", "Valtio ei saa tietää, kuka meni tuppeen. Kalsarit on yksityisasia."],
			["Sivikki-Timo", "Mun kalsarit on vieläki Katjan sohvalla. Sivikissä on lämmitys, ei haittaa."]],
		"lettu": [["Hevari-Tero", "Kilpaa syödyt letut on verottomia. Se lukee laissa, jos lukee tarpeeks tarkkaan."],
			["Sivikki-Timo", "Mää yrjösin vaan kerran, ja se oli Sivikin ulkopuolella. Ammattilainen."]],
		"loyly": [["Hevari-Tero", "Saunassa kaikki on samanarvoisia. Paitsi Timo, sillä oli sukat jalassa."],
			["Sivikki-Timo", "VTEC kesti sata kakskymmentä astetta. Mun munat ei."]],
		"disko": [["Hevari-Tero", "Pihadisko ilman lupaa. Valtio kuuli bassot Muhokselle asti."],
			["Sivikki-Timo", "Akku loppu kolmelta, mutta pyllistys jatku aamuun. Katja sano, että mää liikun ku hirvi."]],
		"karaoke": [["Hevari-Tero", "Mun laulun sanoissa oli viesti verottajalle. Se meni perille."],
			["Sivikki-Timo", "Katja lauloi mun kanssa duetton. Mää luulen, että se rakastaa mua."]]}}


func _morning_lines() -> Array:
	var base := _morning_base()
	var extra: Array = KIVA_AAMU.get(site, {}).get(kiva, [])
	if extra.size() == 2 and base.size() >= 3:
		base[1] = extra[0]
		base[2] = extra[1]
	return base


func _morning_base() -> Array:
	if site == "koti":
		return [["", "Aamulla Päivi keittää kahvit. Kerma ja mansikat on pöydässä, ja Esa paistaa lettuja."],
			["Esa", "Kolme ympyrää, ja leikkauspiste oli oma keittiö. Erämies ei eksy, se vaan kiertää."],
			["Joni", "Mansikkaletut kotona. Tää on ku hole-in-one omalle pihalle."],
			["Päivi", "Syökää. Ja sää: seuraavan kerran pyyhkäset oikealle vaan mua."],
			["", "Sytkäri poistettu puhelimesta. Kesäheilan kuva on jääkaapin ovessa."]]
	if site == "saloinen":
		return [["", "Aamulla Minttu keittää kahvit. Ruusut on maljakossa ikkunalla."],
			["Esa", "Rasvanapin jälkeen pitää syödä rasvasta. Se on luonnon kiertokulku."],
			["Joni", "Mansikkaletut ja kermavaahto. Tää on kuin birdie avausreiällä."],
			["Minttu", "Tulkaa uudestaan. Mutta ens kerralla ilman harppia."],
			["", "Puhelimessa vastaamaton puhelu: Päivi. Ja viesti: \"MAITOA.\""]]
	return [["", "Aamulla Katja keittää kahvit. Ruusut on maitopurkissa, koska maljakkoa ei löytynyt."],
		["Hevari-Tero", "Valtio ei saa näistä letuista senttiäkään. Ei senttiäkään."],
		["Sivikki-Timo", "Sivikki lämpiää pihassa. Kuka tarvii kyydin? VTEC on jo hereillä."],
		["Katja", "Tulkaa uudestaan. Mutta ens kerralla Timo parkkeeraa kauemmas."],
		["", "Puhelimessa vastaamaton puhelu: Päivi. Ja viesti: \"MAITOA.\""]]


func _process(delta: float) -> void:
	_t += delta
	_line_t += delta
	_shake = maxf(0.0, _shake - delta * 2.5)
	_door = move_toward(_door, _door_to, delta * (5.0 if _door_to == 0.0 else 1.8))
	MG.sparks_step(_sparks, delta)
	_apply(delta)
	_view.queue_redraw()
	if _done:
		return
	if Input.is_key_pressed(KEY_ESCAPE):
		_finish()
		return
	var adv := Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")
	if _title_t >= 0.0:
		_title_t += delta
		_leg_step(delta)
		if (adv and _title_t > 0.6) or (auto and _title_t > LEG_TITLE):
			_finish()
		return
	if legend:
		_leg_step(delta)
	var dur: float = LEG_T[_line] if legend and _line < LEG_T.size() else 6.5
	if (adv and _line_t > 0.4) or (auto and _line_t > dur):
		_next()


func _next() -> void:
	_line += 1
	_line_t = 0.0
	if _line >= lines.size():
		if legend:
			_title_t = 0.0  # otsikko ennen valintaa
			Sfx.play("win", -4.0)
			return
		_finish()
		return
	var l: Array = lines[_line]
	if mode in ["ovi", "vaara"] and _line == (3 if legend else 1):
		_door_to = 1.0
		Sfx.play("door", -4.0, 1.0)
	if l[0] == "lahja":
		_given += 1
		var giver: String = gifts[_given - 1][0]
		var ch: Node3D = _people.get(_full(giver))
		if ch != null:
			ch.play("Interact", 0.2)
		Sfx.play("pickup", -4.0, 1.0 + _given * 0.15)
		MG.sparks_burst(_sparks, _cam.unproject_position(_table_top) if _cam != null else Vector2(640, 360), Color(1.0, 0.85, 0.4), 14)
	if site == "koti" and l[0] == "Sinikka":
		Sfx.play("grunt", -6.0, 1.9)  # kikatus (kuten Mintun tunnusääni)
	if mode == "ovi" and not _ok and _line == lines.size() - 1:
		_door_to = 0.0
		_shake = 0.8
		Sfx.play("punch_heavy", -4.0, 0.8)
	if mode == "vaara" and _line == lines.size() - 1:
		_door_to = 0.0
		_shake = 0.6
		Sfx.play("door_close", -2.0, 1.1)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit({"ok": _ok, "mode": mode})
	queue_free()


func _size() -> Vector2:
	return _view.size if _view.size.x > 10.0 else Vector2(1280, 720)


func _draw_all() -> void:
	var s := _size()
	var k := s.y / 720.0
	MG.sparks_draw(_view, _sparks)
	if legend:
		_draw_legend(s, k)
	_draw_text(s, k)
	if legend and _title_t >= 0.0:
		_draw_title(s, k)


## Lahjan antajan koko nimi hahmolistassa ("Tero" -> "Hevari-Tero").
func _full(short: String) -> String:
	if short == "Sinä":
		return short
	for f: String in friends:
		if f == short or f.get_slice("-", 1) == short:
			return f
	return short


# --- Tila joka ruutu -------------------------------------------------------------------------------------------

## Lavastus nykyisen rivin mukaan (testi voi asettaa _line, _given ja _door suoraan): ovilehti, puhujan animaatio,
## lahjat käsissä tai kuistin pöydällä, mummon keppi ja kameran tärähdys.
func _apply(delta: float) -> void:
	if _cam == null:
		return
	var o := _door * _door * (3.0 - 2.0 * _door)
	if _leaf != null:
		_leaf.rotation.y = o * 1.55
	var speaker: String = lines[_line][0] if _line < lines.size() else ""
	for nimi: String in _people:
		var ch: Node3D = _people[nimi]
		var talking := nimi == speaker
		if ch.get_meta("busy_until", 0.0) > _t:
			continue
		ch.play("Idle_Talking" if talking else "Idle", 0.3)
	# Lahjat: annetut pöydälle riviin, antamattomat antajan käsiin.
	for i in gifts.size():
		var g: Array = gifts[i]
		var nimi := _full(g[0])
		if not _props.has(nimi):
			continue
		var prop: Node3D = _props[nimi]
		var ch: Node3D = _people.get(nimi)
		if i < _given:
			var want: Vector3 = _table_top + Vector3(-0.22 + i * 0.22, 0, 0) + prop.get_meta("table_at", Vector3.ZERO)
			if prop.has_meta("table_rot"):
				prop.global_rotation = prop.get_meta("table_rot")
			prop.global_position = prop.global_position.lerp(want, 1.0 - exp(-8.0 * delta)) if delta > 0.0 else want
			if _holding.has(nimi):
				_holding.erase(nimi)
				ch.clear_ik()
				ch.set_meta("busy_until", _t + 1.2)
		elif ch != null:
			_hold(ch, prop)
			_holding[nimi] = prop
	if _box != null:
		# Päivin (naisen malli) Idle-käsi on auki: sormet suoriksi ja kämmen tasaisena rasian kylkeä vasten.
		var pv: Node3D = _people["Päivi"]
		_hold_under(pv, _box)
		pv.set_open_hand("_l", 1.0)
		pv.set_open_hand("_r", 1.0)
	if _cane != null:
		var mummo: Node3D = _people.get("Mummo kepin kanssa")
		var up := _line >= 2
		var pel: Vector3 = mummo.get_meta("pelvis")
		var tgt := pel + (Vector3(0.18, 0.75, -0.25) if up else Vector3(0.24, -0.02, -0.22))
		mummo.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", tgt, pel + Vector3(0.5, 0.2, 0.1))
		var hand: Vector3 = mummo.to_global(tgt)
		# Varsi nyrkin kämmenpuolelle ja kahva sen alle, ei sormien läpi (Asento.solids; mummon +X = ulospäin).
		_cane.global_position = hand + (mummo.global_basis * Vector3(0.035, -0.035, 0) if up else Vector3(0, -0.02, 0))
		_cane.rotation = Vector3(0, 0, 0.35) if up else Vector3.ZERO  # ylhäällä keppi heiluu uhkaavasti
	if _pancake != null:
		_pancake.position.y = 0.04 + absf(sin(_t * 3.0)) * 0.35
		_pancake.rotation.x = fmod(_t * 3.0, PI) * 2.0
	var jolt := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.03
	_cam.transform = _cam_base.translated_local(jolt)


## Lahja molemmissa käsissä rinnan alla vatsan edessä: kämmenet lahjan kyljillä (Pose.palm_on, sormet eteen -Z),
## ranteet lahjan puolileveyden (meta "half") ja kämmenen paksuuden päähän keskeltä, ote lahjan korkeudella "grip".
## Lahjan keskikohta on kämmenen keskellä, PALM_FWD ranteen edessä.
func _hold(ch: Node3D, prop: Node3D) -> void:
	var pel: Vector3 = ch.get_meta("pelvis")
	var mid := pel + Vector3(0, 0.3, -0.34)
	var half: float = prop.get_meta("half", 0.06) + PALM
	for sd in [1.0, -1.0]:
		var sfx := "_r" if sd > 0.0 else "_l"
		ch.set_ik("arm" + sfx, "upperarm" + sfx, "lowerarm" + sfx, "hand" + sfx, mid + Vector3(sd * half, 0, 0),
			pel + Vector3(sd * 0.5, 0.15, 0.05))
		# Kämmen lahjan kylkeä vasten; kaltevassa kyljessä (meta "slope" = dx/dy) kämmen kallistuu kyljen suuntaiseksi.
		var face := Vector3(-sd, prop.get_meta("slope", 0.0), 0).normalized()
		ch.set_ik_orient("arm" + sfx, Pose.palm_on(Vector3(0, 0, -1), face, sd < 0.0), 1.0)
	prop.global_position = ch.to_global(mid + Vector3(0, -prop.get_meta("grip", 0.04), -PALM_FWD))
	prop.global_rotation = Vector3(0, ch.global_rotation.y, 0)


## Laatikko kämmenillä alta vatsan edessä (Päivi, koti): sormet eteen (-Z), kämmenet ylös (Pose.palm_on, vasen
## peilikuva), kämmenpinnat rasian pohjan alla PALM_UP_X keskeltä sivuille. Rasian pohja samassa kohdassa kuin
## _holdin otteessa (lantio + 0,265 ylös ja 0,41 eteen; alempana 0,2 olkavarsi painui lähemmäs vartaloa), ranteet siitä.
func _hold_under(ch: Node3D, prop: Node3D) -> void:
	var pel: Vector3 = ch.get_meta("pelvis")
	var bottom := pel + Vector3(0, 0.265 + 0.12 * _offer, -0.41 - 0.1 * _offer)  # legenda: ojennus ylös ja eteen
	for sd in [1.0, -1.0]:
		var sfx := "_r" if sd > 0.0 else "_l"
		var wrist := bottom + Vector3(sd * PALM_UP_X, -PALM_UP, PALM_UP_FWD)
		# Kyynärpää ulos ja taakse (pole): 0,5 sivulle jätti oikean olkavarren 21 mm vartalon pintaan (_kasi_vartaloon).
		ch.set_ik("arm" + sfx, "upperarm" + sfx, "lowerarm" + sfx, "hand" + sfx, wrist, pel + Vector3(sd * 0.7, 0.1, 0.15))
		ch.set_ik_orient("arm" + sfx, Pose.palm_on(Vector3(0, 0, -1), Vector3.UP, sd < 0.0), 1.0)
	prop.global_position = ch.to_global(bottom)
	prop.global_rotation = Vector3(0, ch.global_rotation.y, 0)


# --- Lavastukset ---------------------------------------------------------------------------------------------

func _person(nimi: String, at: Vector3, yaw: float) -> Node3D:
	var ch: Node3D = Looks.make(_stage, _look(nimi))
	ch.position = at
	ch.rotation.y = yaw
	ch.set_meta("pelvis", ch.bone_position("pelvis"))
	ch.play("Idle", 0.0)
	_people[nimi] = ch
	return ch


func _env(bg: Color, ambient: Color, energy: float) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.3
	return env


func _camera(eye: Vector3, look: Vector3, fov: float, env: Environment) -> void:
	_cam = Camera3D.new()
	_cam.fov = fov
	_cam.environment = env
	_stage.add_child(_cam)
	_cam_base = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
	_cam.transform = _cam_base
	_cam.current = true
	var we := WorldEnvironment.new()  # oman maailman ympäristö (tausta ja ympäristövalo myös ilman kameran ympäristöä)
	we.environment = env
	_stage.add_child(we)


## Omakotitalon kuisti illalla: lautavuorattu julkisivu, valaistut ikkunat, valkoinen ovenkarmi ja ovilehti
## saranoineen, lämmin eteinen oven takana, kuistin lamppu, portaat, talon numero kylttinä, nurmikko ja laatoitettu
## polku. Avaaja ovella, kolmiomittaajat (tai vain pelaaja) portaiden juurella, lahjoille pöytä kuistin vieressä.
func _build_porch() -> void:
	var wall := Color(0.86, 0.76, 0.5) if site == "saloinen" else Color(0.55, 0.3, 0.24)
	var koti := site == "koti"  # pelaajan oma talo (world.gd _build_home): punatiili, ruskea ovi, numero 1
	var white := Color(0.95, 0.95, 0.92)
	# Maa: nurmikko ja polku portaille.
	B.mesh(_stage, B.boxm(Vector3(16, 0.1, 12)), Vector3(0, -0.05, 4), Color(0.22, 0.36, 0.16))
	for k in 6:
		B.mesh(_stage, B.boxm(Vector3(1.0, 0.04, 0.5)), Vector3(0, 0.0, 1.4 + k * 0.62), Color(0.55, 0.53, 0.5))
	# Julkisivu oven ympärillä (oviaukko x -0,55..0,55, y 0,5..2,6), sokkeli ja lautavuoraus.
	for part in [[Vector3(3.45, 3.6, 0.15), Vector3(-2.275, 1.8, -0.075)], [Vector3(3.45, 3.6, 0.15), Vector3(2.275, 1.8, -0.075)],
			[Vector3(1.1, 1.0, 0.15), Vector3(0, 3.1, -0.075)]]:
		var wm := B.mesh(_stage, B.boxm(part[0]), part[1], wall)
		if koti:
			wm.material_override = B.shader_mat("res://shaders/bricks.gdshader")
	B.mesh(_stage, B.boxm(Vector3(8.0, 0.5, 0.2)), Vector3(0, 0.25, -0.05), Color(0.5, 0.5, 0.48))
	for i in (0 if koti else 17):  # lautavuoraus (tiiliseinässä ei)
		var y := 0.6 + i * 0.18
		for sx in [-1.0, 1.0]:
			B.mesh(_stage, B.boxm(Vector3(3.45, 0.02, 0.02)), Vector3(sx * 2.275, y, 0.01), wall.darkened(0.2))
		if y > 2.6:
			B.mesh(_stage, B.boxm(Vector3(1.1, 0.02, 0.02)), Vector3(0, y, 0.01), wall.darkened(0.2))
	for sx in [-1.0, 1.0]:  # nurkkalaudat
		B.mesh(_stage, B.boxm(Vector3(0.14, 3.6, 0.04)), Vector3(sx * 3.93, 1.8, 0.02), white)
	# Ikkunat: valkoiset karmit, ristipuitteet, lämmin valo sisältä.
	for sx in [-1.0, 1.0]:
		var c := Vector3(sx * 2.3, 1.75, 0.0)
		B.mesh(_stage, B.boxm(Vector3(1.3, 1.25, 0.06)), c + Vector3(0, 0, 0.02), white)
		var glass := B.mesh(_stage, B.boxm(Vector3(1.12, 1.07, 0.04)), c + Vector3(0, 0, 0.04), Color(1.0, 0.78, 0.45))
		var gm := glass.material_override as StandardMaterial3D
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.72, 0.38)
		gm.emission_energy_multiplier = 1.2
		B.mesh(_stage, B.boxm(Vector3(0.05, 1.07, 0.06)), c + Vector3(0, 0, 0.06), white)
		B.mesh(_stage, B.boxm(Vector3(1.12, 0.05, 0.06)), c + Vector3(0, 0, 0.06), white)
		B.mesh(_stage, B.boxm(Vector3(1.4, 0.06, 0.16)), c + Vector3(0, -0.66, 0.08), white)  # vesipelti
	# Ovenkarmi, eteinen ja ovilehti (sarana vasemmalla, aukeaa sisään).
	B.mesh(_stage, B.boxm(Vector3(0.1, 2.15, 0.2)), Vector3(-0.6, 1.575, 0), white)
	B.mesh(_stage, B.boxm(Vector3(0.1, 2.15, 0.2)), Vector3(0.6, 1.575, 0), white)
	B.mesh(_stage, B.boxm(Vector3(1.3, 0.12, 0.2)), Vector3(0, 2.66, 0), white)
	B.mesh(_stage, B.boxm(Vector3(2.4, 0.05, 2.6)), Vector3(0, 0.5, -1.4), Color(0.55, 0.38, 0.22))  # eteisen lattia
	for part in [[Vector3(0.1, 2.6, 2.6), Vector3(-1.2, 1.8, -1.4)], [Vector3(0.1, 2.6, 2.6), Vector3(1.2, 1.8, -1.4)],
			[Vector3(2.4, 2.6, 0.1), Vector3(0, 1.8, -2.7)], [Vector3(2.4, 0.1, 2.6), Vector3(0, 3.0, -1.4)]]:
		B.mesh(_stage, B.boxm(part[0]), part[1], Color(0.9, 0.82, 0.66))
	B.mesh(_stage, B.boxm(Vector3(0.9, 1.4, 0.04)), Vector3(0.55, 1.6, -2.62), Color(0.4, 0.28, 0.18))  # vaatekaappi eteisessä
	var inside := OmniLight3D.new()
	inside.light_color = Color(1.0, 0.82, 0.55)
	inside.light_energy = 1.6
	inside.omni_range = 4.0
	inside.position = Vector3(0, 2.6, -1.4)
	_stage.add_child(inside)
	if koti:
		# Etuvalo kuistilta: Päivin kasvot eivät jää eteisen lampun vastavaloon.
		var face := OmniLight3D.new()
		face.light_color = Color(1.0, 0.9, 0.75)
		face.light_energy = 2.2
		face.omni_range = 3.5
		face.position = Vector3(0.25, 1.9, 1.3)
		_stage.add_child(face)
	var hinge := Node3D.new()
	hinge.position = Vector3(-0.53, 0.52, 0.0)
	_stage.add_child(hinge)
	_leaf = hinge
	var door_col := Color(0.55, 0.2, 0.12) if site == "saloinen" else Color(0.15, 0.32, 0.26)
	if koti:
		door_col = Color(0.55, 0.38, 0.22)
	B.mesh(hinge, B.boxm(Vector3(1.04, 2.06, 0.06)), Vector3(0.52, 1.03, 0), door_col)
	B.mesh(hinge, B.boxm(Vector3(0.36, 0.7, 0.07)), Vector3(0.52, 1.5, 0), Color(0.55, 0.68, 0.8))  # ovi-ikkuna
	for py in [0.35, 0.8]:
		B.mesh(hinge, B.boxm(Vector3(0.8, 0.36, 0.075)), Vector3(0.52, py, 0), door_col.darkened(0.12))  # peilit
	B.mesh(hinge, B.sphere(0.035, 10), Vector3(0.94, 1.0, 0.05), Color(0.85, 0.72, 0.35))  # kahva
	# Kuistin lamppu ja talon numero kylttinä.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.6)
	lamp.light_energy = 2.4
	lamp.omni_range = 6.5
	lamp.shadow_enabled = true
	lamp.position = Vector3(0.95, 2.45, 0.35)
	_stage.add_child(lamp)
	var bulb := B.mesh(_stage, B.cyl(0.07, 0.09, 0.22, 12), Vector3(0.95, 2.45, 0.12), Color(1.0, 0.95, 0.75))
	var bm := bulb.material_override as StandardMaterial3D
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.85, 0.55)
	bm.emission_energy_multiplier = 3.0
	var plate := B.sign_plate(_stage, {"saloinen": "7", "koti": "1"}.get(site, "B 3"), Color(0.1, 0.25, 0.5), Color.WHITE, 0.22, 60)
	plate.position = Vector3(-0.95, 2.3, 0.04)
	# Portaat ja kuistin taso.
	for i in 3:
		var top := 0.5 - i * 0.167
		B.mesh(_stage, B.boxm(Vector3(1.8 + i * 0.3, top, 0.36)), Vector3(0, top / 2.0, 0.18 + i * 0.36), Color(0.62, 0.62, 0.6))
	# Pöytä kuistin vieressä lahjoille.
	var tc := Vector3(-1.45, 0, 0.75)
	B.mesh(_stage, B.boxm(Vector3(0.7, 0.04, 0.5)), tc + Vector3(0, 0.74, 0), Color(0.6, 0.42, 0.25))
	for lx in [-0.3, 0.3]:
		for lz in [-0.2, 0.2]:
			B.mesh(_stage, B.boxm(Vector3(0.04, 0.72, 0.04)), tc + Vector3(lx, 0.36, lz), Color(0.5, 0.34, 0.2))
	_table_top = tc + Vector3(0, 0.76, 0)
	# Ilta: tumma taivas, kuunvalo, sinertävä hämärä.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.68, 0.95)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-35, 35, 0)
	_stage.add_child(moon)
	if koti and mode == "ovi":
		# Vasemmalta etuviistosta: Päivi oviaukon oikealla puolella ja Sinikka eteisessä hänen vasemmalla puolellaan
		# näkyvät molemmat oviaukon läpi (oikealta kuvattuna Sinikka jäisi Päivin taakse).
		_camera(Vector3(-0.6, 1.95, 3.3), Vector3(0.0, 1.55, -0.8), 44.0, _env(Color(0.05, 0.06, 0.13), Color(0.4, 0.45, 0.65), 0.22))
	else:
		_camera(Vector3(2.0, 1.95, 5.2), Vector3(-0.1, 1.35, 0.2), 44.0, _env(Color(0.05, 0.06, 0.13), Color(0.4, 0.45, 0.65), 0.22))
	# Avaaja ovella kasvot pihalle; kolmiomittaajat portaiden juurella kasvot ovelle.
	if koti and mode == "ovi":
		# Päivi kynnyksellä oviaukon oikealla puolella (ovilehti aukeaa vasemmalle sisään), laatikko molemmissa käsissä.
		# Sinikka eteisessä takana vasemmalla, ovilehden ja vaatekaapin välissä. Hahmon -Z on etu; PI = kasvot pihalle.
		# Legendassa olkihatun lieri (säde 0,3) ei osu karmiin (oviaukko x -0,55..0,55): Päivi 5 cm vasemmalle.
		_person("Päivi", Vector3(0.2 if legend else 0.25, 0.52, -0.45), PI)
		_person("Sinikka", Vector3(-0.2, 0.52, -1.8), PI - 0.15)
		_box = _koti_box()
		for sp: Array in [[friends[0], Vector3(-1.45, 0, 1.75), 0.4], ["Sinä", Vector3(0.6, 0, 2.0), -0.2],
				[friends[1], Vector3(1.6, 0, 1.6), -0.45]]:
			_person(sp[0], sp[1], sp[2])
	elif mode == "ovi":
		_person(woman, Vector3(0.05, 0.52, -0.45), PI)
		# Kolmikko kameran ja oven välisen näkölinjan sivuille, jotta nainen ovella näkyy.
		var spots := [[friends[0], Vector3(-1.2, 0, 1.65), 0.3], ["Sinä", Vector3(-0.35, 0, 2.0), 0.1], [friends[1], Vector3(1.5, 0, 1.7), -0.45]]
		for sp: Array in spots:
			_person(sp[0], sp[1], sp[2])
		for g: Array in gifts:
			if g[0] == "Sinä" and missing != "":
				continue
			_props[_full(g[0])] = _gift_prop(g[1])
	else:
		var who: String = resident.get("who", "")
		_person(who, Vector3(0.05, 0.52, -0.45), PI)
		_person("Sinä", Vector3(-0.35, 0, 1.9), 0.1)
		if who == "Mummo kepin kanssa":
			_cane = Node3D.new()
			_stage.add_child(_cane)
			B.tube(_cane, Vector3.ZERO, Vector3(0, -0.85, 0), 0.014, Color(0.42, 0.28, 0.14))
			B.mesh(_cane, B.cyl(0.016, 0.018, 0.04, 10), Vector3(0, -0.85, 0), Color(0.05, 0.05, 0.05))
			B.tube(_cane, Vector3.ZERO, Vector3(0.0, 0.05, 0.08), 0.014, Color(0.42, 0.28, 0.14))  # kahva
		elif who == "Pannu-Sulo":
			var can := B.mesh(_stage, B.boxm(Vector3(0.26, 0.4, 0.16)), Vector3(-0.45, 0.72, -0.35), Color(0.88, 0.84, 0.74))
			B.mesh(can, B.cyl(0.03, 0.03, 0.06, 8), Vector3(0.06, 0.22, 0), Color(0.8, 0.1, 0.1))


## Lahjat 3D:nä (kolmio_lahjat_mallit.gd): litran mansikkarasia (kaltevat pahviseinät, umpinaiset marjat kekona),
## kermavaahtospray (valkoinen purkki, sininen etiketti, kaareva suutin) ja ruusukimppu voimapaperikääreessä.
func _gift_prop(what: String) -> Node3D:
	var n: Node3D
	# half = lahjan puolileveys otteen kohdalla, grip = otteen korkeus mallin origosta (_hold). Nyrkki ulottuu noin
	# GIFT_FIST otteen yläpuolelle, joten kaltevassa rasiassa ja kääreessä puolileveys luetaan sieltä (nyrkki ei uppoa).
	if what.begins_with("mansik"):
		n = Gifts.mansikat()
		n.set_meta("grip", 0.035)
		# Rasian leveällä kyljellä nyrkin koukistuneet sormet ulottuvat 1,2 cm syvemmälle kuin purkin ja kääreen kyljellä
		# (kolmio_kuvat _rako).
		n.set_meta("slope", (Gifts.RASIA_YLA.x - Gifts.RASIA_ALA.x) / Gifts.RASIA_H)
		n.set_meta("half", Gifts.rasia_half(0.035 + GIFT_FIST / 2.0) + 0.012)
	elif what.begins_with("kerma"):
		n = Gifts.kermavaahto()
		n.set_meta("grip", Gifts.PURKKI_H / 2.0)
		n.set_meta("half", Gifts.PURKKI_R)
	else:
		n = Gifts.ruusut()  # origo kääreen kapeimmassa kohdassa
		n.set_meta("grip", 0.1)
		n.set_meta("slope", (Gifts.KAARE_R1 - Gifts.KAARE_R0) / (Gifts.KAARE_Y1 - Gifts.KAARE_Y0))  # nyrkki kääreen kyljen suuntaan
		n.set_meta("half", Gifts.kaare_r(0.1 + GIFT_FIST / 2.0))  # kallistetun nyrkin keskikohta on ranteen yläpuolella
		# Pöydällä kimppu lepää kyljellään kukat kohti pihaa (+Z) ja rusetti ylös (mallin -Z). Kartion alin sivuviiva on
		# vaakasuorassa, kun akseli nousee kukkia kohti kartion kyljen kulman (atan(slope) = 0,28 rad): kääre koskee pöytään
		# koko matkalta. Varsien päät ovat alin kohta (0,048 origon alla), joten origo 0,05 pöydän yläpuolelle ja
		# taaksepäin, jotta kukat jäävät pöydän päälle.
		n.set_meta("table_rot", Vector3(PI / 2.0 - atan(n.get_meta("slope")), 0, 0))
		n.set_meta("table_at", Vector3(0, 0.05, -0.1))
	_stage.add_child(n)
	return n


## Päivin kerma- ja mansikkalaatikko: litran mansikkarasia (pidellään alta, _hold_under) ja kermavaahtopurkki
## pystyssä marjakeon päällä. Purkin korkeus lasketaan marjojen pinnasta (Pose.top_y) purkin pituudelta, ei arvata.
func _koti_box() -> Node3D:
	var box := _gift_prop("mansikat")
	var pts := PackedVector3Array()  # rasia ja marjat (nimet eivät ole yksilöllisiä), ennen purkkia
	for n in box.get_children():
		if n is Node3D:
			_mesh_pts(n, (n as Node3D).transform, pts)
	var can := Gifts.kermavaahto()
	box.add_child(can)
	# Purkki seisoo pystyssä rasian päällä: pohja lepää marjakeon päällä. Paikka valitaan marjakeon matalimmasta
	# kohdasta ja pohjan korkeus lasketaan marjojen pinnasta (Pose.top_y) pohjan säteellä, ei arvata.
	var floor_y := 1e9
	var at := Vector2.ZERO
	for xi in 7:
		for zi in 3:
			var cand := Vector2(-0.045 + xi * 0.015, -0.02 + zi * 0.02)
			var ty := Pose.top_y(pts, Vector3(cand.x, 1.0, cand.y), Gifts.PURKKI_R)
			if ty < floor_y:
				floor_y = ty
				at = cand
	can.position = Vector3(at.x, floor_y + 0.002, at.y)
	box.set_meta("can_floor", floor_y)
	return box


## Verkon pisteet (MeshInstance3D-jälkeläiset) solmun n alla, xf = n:n muunnos kohdekehykseen.
func _mesh_pts(n: Node, xf: Transform3D, out: PackedVector3Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		for si in m.get_surface_count():
			for v: Vector3 in m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				out.append(xf * v)
	for c in n.get_children():
		if c is Node3D:
			_mesh_pts(c, xf * (c as Node3D).transform, out)


## Naisen keittiö aamulla: aurinkoinen ikkuna, tapetti, puulattia, pöytä kahvikuppeineen, lettupino mansikoineen ja
## kermavaahtoineen, ruusut maljakossa. Nainen kaataa kahvia, toinen kaveri paistaa lettuja pannulla.
func _build_kitchen() -> void:
	var paper := Color(0.95, 0.88, 0.7) if site == "saloinen" else Color(0.72, 0.78, 0.82)
	B.mesh(_stage, B.boxm(Vector3(7, 0.1, 6)), Vector3(0, -0.05, 1.0), Color(0.62, 0.45, 0.28))
	for i in 12:
		B.mesh(_stage, B.boxm(Vector3(7, 0.005, 0.01)), Vector3(0, 0.002, -1.6 + i * 0.5), Color(0.45, 0.32, 0.2))
	for part in [[Vector3(2.6, 3.0, 0.1), Vector3(-2.2, 1.5, -1.6)], [Vector3(2.6, 3.0, 0.1), Vector3(2.2, 1.5, -1.6)],
			[Vector3(1.8, 1.0, 0.1), Vector3(0, 0.5, -1.6)], [Vector3(1.8, 0.8, 0.1), Vector3(0, 2.6, -1.6)]]:
		B.mesh(_stage, B.boxm(part[0]), part[1], paper)
	for i in 20:  # tapetin raidat
		var x := -3.4 + i * 0.36
		if absf(x) > 0.95:
			B.mesh(_stage, B.boxm(Vector3(0.1, 3.0, 0.01)), Vector3(x, 1.5, -1.54), paper.darkened(0.08))
	var sky := B.mesh(_stage, B.boxm(Vector3(1.8, 1.2, 0.02)), Vector3(0, 1.6, -1.7), Color(0.65, 0.85, 1.0))
	var skm := sky.material_override as StandardMaterial3D
	skm.emission_enabled = true
	skm.emission = Color(0.75, 0.9, 1.0)
	skm.emission_energy_multiplier = 1.5
	var white := Color(0.97, 0.97, 0.95)
	for part in [[Vector3(1.9, 0.08, 0.14), Vector3(0, 2.2, -1.55)], [Vector3(1.9, 0.08, 0.2), Vector3(0, 1.0, -1.52)],
			[Vector3(0.08, 1.2, 0.14), Vector3(-0.9, 1.6, -1.55)], [Vector3(0.08, 1.2, 0.14), Vector3(0.9, 1.6, -1.55)],
			[Vector3(0.05, 1.2, 0.1), Vector3(0, 1.6, -1.55)]]:
		B.mesh(_stage, B.boxm(part[0]), part[1], white)
	if photo != null:
		_window_photo()
	# Pöytä ja kattaus.
	var top := Vector3(0, 0.76, 0.75)
	B.mesh(_stage, B.boxm(Vector3(2.6, 0.05, 0.9)), top, Color(0.7, 0.5, 0.3))
	B.mesh(_stage, B.boxm(Vector3(2.62, 0.005, 0.92)), top + Vector3(0, 0.028, 0), Color(0.95, 0.95, 0.98))  # liina
	for lx in [-1.2, 1.2]:
		for lz in [-0.38, 0.38]:
			B.mesh(_stage, B.boxm(Vector3(0.06, 0.74, 0.06)), top + Vector3(lx, -0.38, lz), Color(0.55, 0.38, 0.22))
	var t := top + Vector3(0, 0.03, 0)
	for i in 7:  # lettupino
		B.mesh(_stage, B.cyl(0.13, 0.13, 0.014, 20), t + Vector3(0, 0.03 + i * 0.016, 0.05), Color(0.92, 0.7, 0.35).darkened(0.05 * (i % 2)))
	B.mesh(_stage, B.cyl(0.17, 0.17, 0.01, 20), t + Vector3(0, 0.02, 0.05), white)  # lautanen
	B.mesh(_stage, B.sphere(0.06, 12), t + Vector3(-0.03, 0.17, 0.05), Color(1.0, 0.99, 0.95)).scale = Vector3(1.2, 0.7, 1.2)
	for i in 5:
		B.mesh(_stage, B.sphere(0.022, 8), t + Vector3(0.05 + (i % 3) * 0.025, 0.16 + (i / 3) * 0.02, 0.0 + (i % 2) * 0.05),
			Color(0.82, 0.06, 0.1))
	for cx in [-0.85, -0.35, 0.45, 0.9]:  # kahvikupit ja asetit
		B.mesh(_stage, B.cyl(0.06, 0.06, 0.006, 16), t + Vector3(cx, 0.005, 0.25), white)
		B.mesh(_stage, B.cyl(0.042, 0.035, 0.07, 14), t + Vector3(cx, 0.04, 0.25), white)
		B.mesh(_stage, B.cyl(0.038, 0.038, 0.004, 14), t + Vector3(cx, 0.074, 0.25), Color(0.25, 0.14, 0.07))
	# Ruusut maljakossa (Katjalla maitopurkissa).
	var vase := t + Vector3(-1.05, 0, -0.15)
	if site == "koti":
		pass  # Päivin kotona ei ole lahjakukkia (gifts []): ei maljakkoa eikä ruusuja
	elif site == "saloinen":
		B.mesh(_stage, B.cyl(0.05, 0.07, 0.22, 14), vase + Vector3(0, 0.11, 0), Color(0.45, 0.7, 0.85))
	else:
		B.mesh(_stage, B.boxm(Vector3(0.09, 0.22, 0.09)), vase + Vector3(0, 0.11, 0), Color(0.95, 0.95, 0.95))
		B.mesh(_stage, B.boxm(Vector3(0.092, 0.08, 0.092)), vase + Vector3(0, 0.09, 0), Color(0.2, 0.4, 0.8))
	for i in (0 if site == "koti" else 5):
		var a := i * TAU / 5.0
		var p := vase + Vector3(cos(a) * 0.06, 0.38, sin(a) * 0.06)
		B.tube(_stage, vase + Vector3(0, 0.2, 0), p, 0.004, Color(0.2, 0.5, 0.2))
		B.mesh(_stage, B.sphere(0.035, 10), p, Color(0.72, 0.03, 0.1))
	# Valot: aamuaurinko ikkunasta ja lämmin täyttövalo.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.78)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, 160, 0)
	_stage.add_child(sun)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.9, 0.75)
	fill.light_energy = 1.2
	fill.omni_range = 7.0
	fill.position = Vector3(0, 2.6, 2.0)
	_stage.add_child(fill)
	_camera(Vector3(0, 1.5, 2.9), Vector3(0, 1.15, 0.1), 50.0, _env(Color(0.85, 0.9, 1.0), Color(0.95, 0.88, 0.8), 0.7))
	# Hahmot pöydän takana kasvot kameraan: kaveri, nainen kahvipannun kanssa ja kaveri lettupannun kanssa.
	_person(friends[0], Vector3(-1.0, 0, -0.1), PI - 0.15)
	var w := _person(woman, Vector3(0.0, 0, -0.15), PI)
	var cook := _person(friends[1], Vector3(1.0, 0, -0.1), PI + 0.15)
	var wp: Vector3 = w.get_meta("pelvis")
	var pot_at := wp + Vector3(0.14, 0.32, -0.42)
	w.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", pot_at, wp + Vector3(0.5, 0.1, 0.0))
	var pot := Node3D.new()
	_stage.add_child(pot)
	pot.global_position = w.to_global(pot_at)
	B.mesh(pot, B.cyl(0.06, 0.08, 0.2, 14), Vector3(0, -0.12, 0), Color(0.78, 0.78, 0.8))
	B.mesh(pot, B.cyl(0.04, 0.06, 0.04, 14), Vector3(0, -0.005, 0), Color(0.15, 0.15, 0.16))
	B.tube(pot, Vector3(0.05, -0.08, 0), Vector3(0.14, -0.04, 0), 0.012, Color(0.78, 0.78, 0.8))  # nokka
	var cp: Vector3 = cook.get_meta("pelvis")
	var pan_at := cp + Vector3(0.16, 0.35, -0.42)
	cook.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", pan_at, cp + Vector3(0.5, 0.1, 0.0))
	var pan := Node3D.new()
	_stage.add_child(pan)
	pan.global_position = cook.to_global(pan_at)
	pan.rotation.y = cook.rotation.y
	B.tube(pan, Vector3.ZERO, Vector3(0, 0.02, -0.2), 0.012, Color(0.12, 0.1, 0.08))  # varsi kädestä pannulle
	B.mesh(pan, B.cyl(0.13, 0.11, 0.035, 20), Vector3(0, 0.03, -0.32), Color(0.18, 0.18, 0.2))
	_pancake = Node3D.new()
	_pancake.position = Vector3(0, 0.05, -0.32)
	pan.add_child(_pancake)
	B.mesh(_pancake, B.cyl(0.1, 0.1, 0.012, 18), Vector3.ZERO, Color(0.95, 0.72, 0.38))


## Räsytupin polaroid teipattuna ikkunalasiin naisen pään oikealle puolelle (lasi z = -1,69, kehys edessä).
func _window_photo() -> void:
	var pol := Node3D.new()
	_stage.add_child(pol)
	pol.position = Vector3(0.48, 1.86, -1.68)
	pol.rotation.z = 0.06
	B.mesh(pol, B.boxm(Vector3(0.26, 0.31, 0.004)), Vector3.ZERO, Color(0.97, 0.96, 0.92))
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.225, 0.225)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = photo
	m.emission_enabled = true  # ikkunan vastavalossa kuva näkyy silti
	m.emission_texture = photo
	m.emission_energy_multiplier = 0.35
	q.material_override = m
	q.position = Vector3(0, 0.025, 0.003)
	pol.add_child(q)
	for sx in [-1.0, 1.0]:  # teipinpalat yläkulmissa
		var t := B.mesh(pol, B.boxm(Vector3(0.08, 0.025, 0.002)), Vector3(sx * 0.11, 0.15, 0.004), Color(0.95, 0.92, 0.75))
		t.rotation.z = sx * -0.6


# --- Kesäheilan legenda (koti, legend) --------------------------------------------------------------------------

## Lavakuvan olkihattu (sama kuin Sytkärin profiilikuvassa: Looks.add_glam, punainen nauha). Legendassa Päivin
## päässä ilman aurinkolaseja (kasvot näkyvät, hattu on tuntomerkki); toistoissa eteisen takaseinän naulassa
## vaatekaapin yläpuolella, näkölinjalla oviaukon läpi Sinikan ja Päivin päiden yli.
func _hat_setup() -> void:
	if legend:
		var pv: Node3D = _people["Päivi"]
		Looks.add_glam(pv, true)
		for n in pv.find_children("Aurinkolasit", "", true, false):
			n.queue_free()
		for n in pv.find_children("*", "Node3D", true, false):
			if n.has_meta("hattu"):
				_hat = n
		return
	_hat = Node3D.new()
	_stage.add_child(_hat)
	var straw := Color(0.93, 0.85, 0.62)
	B.mesh(_hat, B.cyl(0.3, 0.3, 0.012, 32), Vector3.ZERO, straw)
	B.mesh(_hat, B.cyl(0.1, 0.115, 0.11, 24), Vector3(0, 0.055, 0), straw)
	B.mesh(_hat, B.cyl(0.117, 0.117, 0.035, 24), Vector3(0, 0.02, 0), Color(0.8, 0.03, 0.1))
	# Naulassa lieri seinää vasten (kiekko pystyssä, +X-kierto 90°: kupu +Z eli huoneeseen). Vaatekaapin etupinta
	# z = -2,60 ja lieri ulottuu kaapin yläreunan (y 2,3) alle, joten lieri 1,5 cm kaapin eteen.
	_hat.position = Vector3(0.15, 2.42, -2.585)
	_hat.rotation.x = PI / 2.0


## Legendan valmistelu: Sytkärin lavakuva -96 (sama studio kuin puhelimessa), kartan rajaus ja kamera ensimmäiseen
## kuvaan. Ilman mittausdataa (testit) kolme ympyrää kodin ympärille.
func _leg_setup() -> void:
	_card_vp = Sytkari.studio(self, Sytkari.kesaheila_look(), Color(0.3, 0.42, 0.62), Color(0.55, 0.4, 0.26), "lava")
	_map = Control.new()
	_map.clip_contents = true
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_map)
	_view.add_child(_map)
	if rings.size() < 3:
		rings = []
		for q: Array in [[Vector2(-0.8, 0.6), 220.0, "Joni"], [Vector2(0.9, 0.35), 300.0, "Esa"], [Vector2(0.1, -1.0), 120.0, "Sinä"]]:
			var dir: Vector2 = (q[0] as Vector2).normalized()
			rings.append({"c": home + dir * float(q[1]), "m": q[1], "lo": float(q[1]) - 25.0, "hi": float(q[1]) + 25.0, "who": q[2]})
	_leg_street()
	var sh: Array = _leg_shot()
	_cam.fov = sh[2]
	_cam_base = Transform3D(Basis.looking_at(sh[1] - sh[0], Vector3.UP), sh[0])


## Vastakuvan tausta (ovelta pihalle): nurmikko jatkuu, pensasaita, katu, katulamppu, Päivin Hyundai pihassa ja
## naapuritalo valaistuin ikkunoin. Tähtitaivas tummaa taustaa vasten.
func _leg_street() -> void:
	B.mesh(_stage, B.boxm(Vector3(30, 0.1, 10)), Vector3(0, -0.06, 14), Color(0.2, 0.33, 0.15))
	for i in 13:  # pensasaita
		B.mesh(_stage, B.sphere(0.65, 10), Vector3(-6.0 + i * 1.0, 0.55, 8.2), Color(0.12, 0.26, 0.1).lightened(0.05 * (i % 3)))
	B.mesh(_stage, B.boxm(Vector3(30, 0.04, 3.0)), Vector3(0, 0.0, 10.5), Color(0.18, 0.18, 0.2))  # katu
	for i in 8:
		B.mesh(_stage, B.boxm(Vector3(1.0, 0.045, 0.12)), Vector3(-7.0 + i * 2.0, 0.0, 10.5), Color(0.85, 0.85, 0.8))
	var pole := Vector3(3.2, 0, 9.3)
	B.mesh(_stage, B.cyl(0.06, 0.08, 4.2, 10), pole + Vector3(0, 2.1, 0), Color(0.35, 0.36, 0.38))
	var bulb := B.mesh(_stage, B.sphere(0.18, 12), pole + Vector3(0, 4.2, 0), Color(1.0, 0.88, 0.6))
	var bm := bulb.material_override as StandardMaterial3D
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.8, 0.5)
	bm.emission_energy_multiplier = 4.0
	var sl := OmniLight3D.new()
	sl.light_color = Color(1.0, 0.82, 0.55)
	sl.light_energy = 1.4
	sl.omni_range = 7.0
	sl.position = pole + Vector3(0, 4.0, 0)
	_stage.add_child(sl)
	# Naapurin talo kadun toisella puolella.
	var nh := Vector3(-1.5, 0, 14.0)
	B.mesh(_stage, B.boxm(Vector3(8.0, 3.2, 5.0)), nh + Vector3(0, 1.6, 0), Color(0.78, 0.7, 0.5))
	var roof := B.mesh(_stage, B.boxm(Vector3(8.4, 0.2, 3.4)), nh + Vector3(0, 3.7, -1.2), Color(0.3, 0.16, 0.12))
	roof.rotation.x = 0.55
	var roof2 := B.mesh(_stage, B.boxm(Vector3(8.4, 0.2, 3.4)), nh + Vector3(0, 3.7, 1.2), Color(0.3, 0.16, 0.12))
	roof2.rotation.x = -0.55
	for wx in [-2.5, 0.0, 2.5]:
		var w := B.mesh(_stage, B.boxm(Vector3(1.1, 1.0, 0.05)), nh + Vector3(wx, 1.6, -2.52), Color(1.0, 0.8, 0.45))
		var wm := w.material_override as StandardMaterial3D
		wm.emission_enabled = true
		wm.emission = Color(1.0, 0.72, 0.38)
		wm.emission_energy_multiplier = 1.0
	# Päivin auto pihassa (punainen Hyundai, laatikkomuoto ja renkaat).
	var car := Vector3(-3.4, 0, 5.2)
	B.mesh(_stage, B.boxm(Vector3(1.7, 0.6, 3.9)), car + Vector3(0, 0.55, 0), Color(0.62, 0.08, 0.1))
	B.mesh(_stage, B.boxm(Vector3(1.5, 0.5, 2.0)), car + Vector3(0, 1.08, -0.2), Color(0.2, 0.24, 0.3))
	for wx in [-0.8, 0.8]:
		for wz in [-1.25, 1.25]:
			B.mesh(_stage, B.cyl(0.32, 0.32, 0.22, 14), car + Vector3(wx, 0.32, wz), Color(0.06, 0.06, 0.06)).rotation.z = PI / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1996
	for i in 60:  # tähdet
		var st := B.mesh(_stage, B.sphere(0.04, 6), Vector3(rng.randf_range(-15, 15), rng.randf_range(5, 12), 22.0), Color.WHITE)
		var stm := st.material_override as StandardMaterial3D
		stm.emission_enabled = true
		stm.emission = Color(0.9, 0.92, 1.0)
		stm.emission_energy_multiplier = 2.0


## Kuva rivin mukaan: [silmä, katse, fov]. Lavastus: julkisivu z = 0, Päivi (0,2; 0,52; -0,45) kasvot +Z,
## kolmikko portailla z 1,6..2,0 kasvot ovelle.
func _leg_shot() -> Array:
	if _title_t >= 0.0 or _line >= 8:
		return [Vector3(-1.2, 1.75, 3.5), Vector3(0.35, 1.45, 0.2), 44.0]  # kerma ja otsikko: Päivi ojentaa, pelaaja etualalla
	match _line:
		0, 1, 2:
			return [Vector3(0.3, 2.2, 5.6), Vector3(0.0, 1.35, 0.0), 46.0]  # talo, ovi ja kolmikko selin
		5:
			# Päivi lähikuvassa oikealla (hattu kokonaan tekstilaatikon alla), kortti vasemmalla.
			return [Vector3(-0.5, 1.8, 1.25), Vector3(-0.2, 2.02, -0.45), 42.0]  # hieman alta: silmät lierin alla näkyvät
		6, 7:
			return [Vector3(-0.35, 1.7, 0.15), Vector3(0.1, 1.35, 1.9), 56.0]  # vastakuva ovelta portaille (taustana katu, _leg_street)
	return [Vector3(-0.6, 1.95, 3.3), Vector3(0.0, 1.55, -0.8), 44.0]  # ovi: Päivi ja Sinikka oviaukossa


func _leg_step(delta: float) -> void:
	var sh: Array = _leg_shot()
	var want := Transform3D(Basis.looking_at(sh[1] - sh[0], Vector3.UP), sh[0])
	var cut := _cue != _line and _line in [0, 3, 5, 6, 8]  # leikkaus uuteen kuvaan, ei liukua seinän läpi
	var a := 1.0 if cut else 1.0 - exp(-3.0 * delta)
	_cam_base = _cam_base.interpolate_with(want, a)
	_cam.fov = lerpf(_cam.fov, sh[2], a)
	_offer = move_toward(_offer, 1.0 if _line >= 8 else 0.0, delta * 1.5)
	if _line >= 3:  # ovi auki: kaverit kääntyvät katsomaan ovelle (hahmon etu -Z, rotation.y = atan2(-dx, -dz))
		for f: String in friends:
			var ch: Node3D = _people.get(f)
			if ch != null:
				var d := Vector3(0.2, 0, -0.2) - ch.position
				ch.rotation.y = lerp_angle(ch.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-4.0 * delta))
	if _line >= 8 and _box != null:  # sydämiä nousee laatikosta
		_heart_t += delta
		if _heart_t > 0.22:
			_heart_t = 0.0
			_hearts.append([_cam.unproject_position(_box.global_position + Vector3(0, 0.12, 0)), Vector2(randf_range(-40, 40), -110), 0.0])
	for h: Array in _hearts:
		h[0] += h[1] * delta
		h[2] += delta
	_hearts = _hearts.filter(func(h: Array) -> bool: return h[2] < 1.6)
	var t := _line_t + (LEG_T[0] if _line == 1 else 0.0)  # kartta: rivit 0 ja 1 yhtä animaatiota
	if _line <= 1:
		var n := clampi(int(t / 0.9) + 1, 0, rings.size())
		while _rings_shown < n:
			_rings_shown += 1
			Sfx.play("bell", -8.0, 1.6 + _rings_shown * 0.3)
		if t > 3.4 and not _pin_done:
			_pin_done = true
			Sfx.play("win_small", -5.0)
	if _cue == _line:
		_cue_t += delta
		if _line == 2:  # kolme koputusta
			var k0 := int((_cue_t - delta) / 0.32)
			var k1 := int(_cue_t / 0.32)
			if k1 != k0 and k1 < 3:
				Sfx.play("punch", -6.0, 0.7)
				_shake = 0.35
		return
	_cue = _line
	_cue_t = 0.0
	match _line:
		2:
			Sfx.play("punch", -6.0, 0.7)
			_shake = 0.35
		3:
			_shake = 0.2
		5:
			Sfx.play("bell", -10.0, 2.4)
		8:
			Sfx.play("pickup", -4.0, 1.3)
			if _box != null:
				var at := _cam.unproject_position(_box.global_position + Vector3(0, 0.1, 0))
				MG.sparks_burst(_sparks, at, Color(1.0, 1.0, 0.96), 22)
				MG.sparks_burst(_sparks, at, Color(0.9, 0.12, 0.2), 14)


## Legendan ruudun päälle: Sytkäri-puhelin kartalla (rivit 0..2) ja lavakuva -96 sydämineen (rivi 5).
func _draw_legend(s: Vector2, k: float) -> void:
	var font := ThemeDB.fallback_font
	for h: Array in _hearts:
		var a := 1.0 - float(h[2]) / 1.6
		_heart_at(h[0], (9.0 + 6.0 * float(h[2])) * k, Color(1.0, 0.3, 0.45, a))
	# Puhelin nousee alhaalta oikealle ja laskee pois koputuksessa.
	var up := 0.0
	if _line <= 1 and _title_t < 0.0:
		up = clampf((_line_t + (LEG_T[0] if _line == 1 else 0.0)) / 0.5, 0.0, 1.0)
	elif _line == 2:
		up = 1.0 - clampf(_line_t / 0.4, 0.0, 1.0)
	_map.visible = up > 0.0
	if up > 0.0:
		var ph := Rect2(s.x * 0.6, s.y * 0.17 + (1.0 - up) * s.y, 330 * k, 560 * k)
		MG.box(_view, ph.grow(6 * k), Color(0.08, 0.08, 0.1), int(34 * k), int(10 * k), Color(0.3, 0.3, 0.34), 2)
		var scr := Rect2(ph.position + Vector2(10, 46) * k, Vector2(ph.size.x - 20 * k, ph.size.y - 74 * k))
		_view.draw_rect(Rect2(ph.position + Vector2(10, 10) * k, Vector2(ph.size.x - 20 * k, 36 * k)), Color(1.0, 0.97, 0.95))
		Sytkari.flame(_view, ph.position + Vector2(34, 30) * k, 11 * k, _t)
		_view.draw_string(font, ph.position + Vector2(52, 36) * k, "Sytkäri  ·  Kesäheila -96", HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(17 * k), Color(0.15, 0.12, 0.14))
		_map.position = scr.position
		_map.size = scr.size
		_map.queue_redraw()
		var cap := "Leikkauspiste: 0 m" if _pin_done else "Ympyröitä %d / 3" % _rings_shown
		_view.draw_string(font, Vector2(ph.position.x, ph.end.y - 10 * k), cap, HORIZONTAL_ALIGNMENT_CENTER, ph.size.x, int(17 * k),
			Color(1.0, 0.85, 0.5) if _pin_done else Color(0.85, 0.85, 0.9))
	# Lavakuva -96 vasemmalle ja sydänviiva kuvan hatusta Päivin hattuun.
	if _line == 5 and _title_t < 0.0 and _card_vp != null:
		var slide := clampf(_line_t / 0.5, 0.0, 1.0)
		var card := Rect2(s.x * 0.05 - (1.0 - slide) * 420 * k, s.y * 0.2, 300 * k, 440 * k)
		MG.box(_view, card, Color(1.0, 0.98, 0.96), int(16 * k), int(10 * k), Color(0.85, 0.75, 0.72), 1)
		var pr := Rect2(card.position + Vector2(12, 12) * k, Vector2(card.size.x - 24 * k, 330 * k))
		var src := Vector2(_card_vp.size)
		var sc := maxf(pr.size.x / src.x, pr.size.y / src.y)
		var crop := pr.size / sc
		_view.draw_texture_rect_region(_card_vp.get_texture(), pr, Rect2((src - crop) / 2.0, crop))
		_view.draw_rect(pr, MG.OUTLINE, false, 2.0)
		Sytkari.flame(_view, card.position + Vector2(28, card.size.y - 58 * k), 10 * k, _t)
		_view.draw_string(font, card.position + Vector2(44, card.size.y - 52 * k), "Kesäheila -96, Saloinen", HORIZONTAL_ALIGNMENT_LEFT,
			card.size.x - 54 * k, int(19 * k), Color(0.15, 0.12, 0.14))
		_view.draw_string(font, card.position + Vector2(18, card.size.y - 22 * k), "Lavakuva, kesä -96", HORIZONTAL_ALIGNMENT_LEFT,
			-1, int(15 * k), Color(0.45, 0.4, 0.42))
		if _line_t > 1.2 and _hat != null:
			var hat := _cam.unproject_position(_hat.global_position + Vector3(0, 0.08, 0))
			var from := Vector2(card.end.x - 30 * k, pr.position.y + 70 * k)
			var p := clampf((_line_t - 1.2) / 0.6, 0.0, 1.0)
			var to := from.lerp(hat, p)
			var n := int(from.distance_to(to) / (14 * k))
			for i in n:
				if i % 2 == 0:
					_view.draw_line(from.lerp(to, float(i) / n), from.lerp(to, float(i + 1) / n), Color(1.0, 0.35, 0.45), 3.0 * k)
			if p >= 1.0:
				var beat := 1.0 + 0.12 * sin(_line_t * 9.0)
				_heart_at(from.lerp(hat, 0.5), 20 * k * beat, Color(1.0, 0.3, 0.42))
				_view.draw_string_outline(font, from.lerp(hat, 0.5) + Vector2(-60, -30) * k, "SAMA HATTU", HORIZONTAL_ALIGNMENT_CENTER,
					120 * k, int(18 * k), 5, Color(0.3, 0.02, 0.06))
				_view.draw_string(font, from.lerp(hat, 0.5) + Vector2(-60, -30) * k, "SAMA HATTU", HORIZONTAL_ALIGNMENT_CENTER,
					120 * k, int(18 * k), Color(1.0, 0.92, 0.6))


func _heart_at(c: Vector2, r: float, col: Color) -> void:
	_view.draw_circle(c + Vector2(-r * 0.5, -r * 0.2), r * 0.55, col)
	_view.draw_circle(c + Vector2(r * 0.5, -r * 0.2), r * 0.55, col)
	_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.02, -r * 0.05), c + Vector2(r * 1.02, -r * 0.05), c + Vector2(0, r * 1.0)]), col)


## Sytkärin kartta: oma koti keskellä, kortteleita ja teitä, mittausten ympyränauhat (lo..hi) piirtyvät kuin harpilla
## yksi kerrallaan (0,9 s välein) ja leikkaavat kodin; lopuksi neula putoaa kotiin ja leikkausalue sykkii.
func _draw_map() -> void:
	var sz := _map.size
	var mid := sz / 2.0
	var k := _size().y / 720.0
	_map.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.88, 0.91, 0.82))
	# Mittakaava toiseksi kaukaisimman keskipisteen mukaan: kaukaisimman ympyrän kaari kulkee kodin kautta, vaikka sen
	# keskipiste jää kartan ulkopuolelle (yksi kilometrin ympyrä ei kutista kahta muuta pisteiksi).
	var ds: Array = rings.map(func(r: Dictionary) -> float: return ((r.c as Vector2) - home).length())
	ds.sort()
	var far := maxf(120.0, float(ds[ds.size() - 2]) if ds.size() >= 2 else 120.0)
	var sc := (minf(sz.x, sz.y) * 0.46) / (far * 1.08)
	# Tiet ja korttelit (kiinteä siemen: sama kartta joka kerta).
	var rng := RandomNumberGenerator.new()
	rng.seed = 96
	for i in 7:
		var y := sz.y * (0.08 + 0.14 * i) + rng.randf_range(-8, 8) * k
		_map.draw_line(Vector2(0, y), Vector2(sz.x, y + rng.randf_range(-20, 20) * k), Color(1, 1, 1, 0.9), 6.0 * k)
	for i in 4:
		var x := sz.x * (0.12 + 0.26 * i) + rng.randf_range(-10, 10) * k
		_map.draw_line(Vector2(x, 0), Vector2(x + rng.randf_range(-25, 25) * k, sz.y), Color(1, 1, 1, 0.9), 6.0 * k)
	for i in 40:
		var q := Vector2(rng.randf() * sz.x, rng.randf() * sz.y)
		if q.distance_to(mid) > 22 * k:
			_map.draw_rect(Rect2(q, Vector2(9, 7) * k), Color(0.72, 0.68, 0.62))
	_map.draw_circle(Vector2(sz.x * 0.85, sz.y * 0.12), 40 * k, Color(0.55, 0.75, 0.9))  # lampi
	var t := _line_t + (LEG_T[0] if _line == 1 else 0.0)
	if _line >= 2:
		t = 99.0
	for i in rings.size():
		var r: Dictionary = rings[i]
		var p := clampf((t - i * 0.9) / 0.8, 0.0, 1.0)
		if p <= 0.0:
			continue
		var c := mid + ((r.c as Vector2) - home) * sc
		var col: Color = RING_COL[i % RING_COL.size()]
		var rad := (float(r.lo) + float(r.hi)) / 2.0 * sc
		var w := maxf(5.0 * k, (float(r.hi) - float(r.lo)) * sc)
		_map.draw_arc(c, rad, -PI / 2.0, -PI / 2.0 + TAU * p, 160, Color(col, 0.42), w)
		_map.draw_arc(c, rad, -PI / 2.0, -PI / 2.0 + TAU * p, 160, col.darkened(0.2), 1.5 * k)
		_map.draw_circle(c, 5 * k, col.darkened(0.3))
		var lbl := String(r.get("who", ""))
		var lp := c + Vector2(8, -6) * k
		if lp.distance_to(mid) < 40 * k:  # nimi ei kodin päälle
			lp = c + (c - mid).normalized() * 30 * k + Vector2(-10, 0) * k
		_map.draw_string(ThemeDB.fallback_font, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), col.darkened(0.45))
	# Koti: talo numero 1; leikkauksen hehku ja neula, kun kaikki ympyrät on piirretty.
	if _pin_done:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		_map.draw_circle(mid, (18.0 + 8.0 * pulse) * k, Color(1.0, 0.85, 0.3, 0.35 + 0.25 * pulse))
	_map.draw_rect(Rect2(mid - Vector2(9, 7) * k, Vector2(18, 14) * k), Color(0.75, 0.25, 0.18))
	_map.draw_colored_polygon(PackedVector2Array([mid + Vector2(-11, -7) * k, mid + Vector2(11, -7) * k, mid + Vector2(0, -16) * k]),
		Color(0.45, 0.15, 0.1))
	_map.draw_string(ThemeDB.fallback_font, mid + Vector2(-4, 6) * k, "1", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k), Color.WHITE)
	if _pin_done:
		var drop := clampf((t - 3.4) / 0.35, 0.0, 1.0)
		var bounce := absf(sin(drop * PI * 1.5)) * (1.0 - drop) * 14.0
		var tip := mid + Vector2(0, -16) * k - Vector2(0, (1.0 - drop) * 160.0 + bounce) * k
		_map.draw_circle(tip + Vector2(0, -26) * k, 13 * k, Color(1.0, 0.36, 0.2))
		_map.draw_colored_polygon(PackedVector2Array([tip + Vector2(-11, -20) * k, tip + Vector2(11, -20) * k, tip]), Color(1.0, 0.36, 0.2))
		_map.draw_circle(tip + Vector2(0, -26) * k, 5 * k, Color.WHITE)


## Otsikko: ruutu himmenee, kultainen KESÄHEILA -96 ja tarina laatikossa alhaalla.
func _draw_title(s: Vector2, k: float) -> void:
	var a := clampf(_title_t / 0.6, 0.0, 1.0)
	_view.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.01, 0.03, 0.42 * a))
	var font := ThemeDB.fallback_font
	var size := int(78 * k * (1.25 - 0.25 * a))
	var y := 118 * k  # Päivin hatun yläpuolelle
	_view.draw_string_outline(font, Vector2(0, y), "KESÄHEILA -96", HORIZONTAL_ALIGNMENT_CENTER, s.x, size, int(12 * k),
		Color(0.25, 0.08, 0.02, a))
	_view.draw_string(font, Vector2(0, y), "KESÄHEILA -96", HORIZONTAL_ALIGNMENT_CENTER, s.x, size, Color(1.0, 0.82, 0.3, a))
	var br := Rect2(s.x * 0.16, s.y - 150 * k, s.x * 0.68, 80 * k)
	MG.box(_view, br, Color(0.06, 0.05, 0.05, 0.86 * a), int(14 * k), int(6 * k), Color(0.95, 0.8, 0.35, a), 2)
	_wrap(br.position + Vector2(20, 34) * k, LEG_SUB, br.size.x - 40 * k, int(21 * k), Color(0.98, 0.95, 0.88, a))


func _draw_text(s: Vector2, k: float) -> void:
	if _line >= lines.size():
		return
	var l: Array = lines[_line]
	var who: String = l[0]
	var text: String = l[1]
	var font := ThemeDB.fallback_font
	var r := Rect2(s.x * 0.1, s.y * 0.04, s.x * 0.8, 96 * k)
	if mode != "aamu":
		r.position.y = s.y * 0.04
	MG.box(_view, r, Color(0.06, 0.05, 0.05, 0.86), int(14 * k), int(6 * k), Color(0.95, 0.8, 0.35), 2)
	var shown := text.substr(0, int(_line_t * 60.0))
	var label := "" if who in ["", "lahja"] else who + ":"
	if label != "":
		_view.draw_string(font, r.position + Vector2(18, 30) * k, label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * k), Color(1.0, 0.75, 0.45))
	_wrap(r.position + Vector2(18, 58 if label != "" else 40) * k, shown, r.size.x - 36 * k, int(20 * k) if who != "" else int(24 * k),
		Color(0.98, 0.95, 0.88))
	if mode == "aamu" and stats != "":
		var sr := Rect2(s.x * 0.1, s.y - 64 * k, s.x * 0.8, 44 * k)
		MG.box(_view, sr, Color(0.06, 0.05, 0.05, 0.8), int(10 * k), 0)
		_view.draw_string(font, sr.position + Vector2(0, 29 * k), stats, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(16 * k),
			Color(1.0, 0.9, 0.55))
	var hint := "[%s] jatka   [Esc] ohita" % Settings.action_key("interact")
	var hy := s.y - (76.0 if mode == "aamu" and stats != "" else 14.0) * k  # ruudun alalaitaan, ei oven tai hahmojen päälle
	_view.draw_string_outline(font, Vector2(0, hy), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x, int(16 * k), 5, Color.BLACK)
	_view.draw_string(font, Vector2(0, hy), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x, int(16 * k), Color(0.95, 0.9, 0.8))


func _wrap(at: Vector2, text: String, w: float, size: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var line := ""
	var y := 0.0
	for word in text.split(" "):
		var t := word if line == "" else line + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w and line != "":
			_view.draw_string(font, at + Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += size * 1.3
			line = word
		else:
			line = t
	_view.draw_string(font, at + Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
