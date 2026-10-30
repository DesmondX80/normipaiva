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
## Lavastuksen koordinaatit: talon julkisivu z = 0 (+Z ulos pihalle), kynnys y = 0,5; keittiössä pöytä z = 0,75 ja
## hahmot sen takana kasvot +Z:aan (kamera edessä). Hahmo katsoo oletuksena -Z:aan, joten rotation.y = PI = kasvot ulos.

signal finished(r: Dictionary)

const MG := preload("res://scripts/mg_draw.gd")
const B := preload("res://scripts/build.gd")
const Pose := preload("res://scripts/pose.gd")
const Looks := preload("res://scripts/looks.gd")

var mode := "ovi"
var site := "saloinen"
var woman := "Minttu"
var friends: Array = ["Joni", "Esa"]
var gifts: Array = []  # [[antaja, lahja], ...]
var missing := ""  # pelaajan puuttuva lahja ("" = kaikki mukana)
var resident := {}  # väärä ovi: kolmiomittaus.gd WRONG_DOORS
var stats := ""  # aamun tilastorivi
var lines: Array = []  # [puhuja, teksti]; rakennetaan _ready:ssä
var auto := true  # rivit etenevät itsestään 6,5 s välein (testi pysäyttää)

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
const PALM := 0.06  # rannekeskeltä nyrkin sormien pintaan (Idle-käsi on nyrkissä), kun käsi on lahjan kyljellä (Asento.solids)
const PALM_FWD := 0.07  # kämmenen keskikohta ranteen edessä
var _pancake: Node3D
var _pan_at := Vector3.ZERO

## 3D-hahmojen ulkonäöt (looks.gd). Väärien ovien asukkaat tässä.
const RESIDENTS := {
	"Mummo kepin kanssa": {"model": "female", "shirt": Color(0.56, 0.36, 0.55), "pants": Color(0.32, 0.24, 0.2),
		"shoes": Color(0.22, 0.14, 0.1), "hair": "", "perm_col": Color(0.93, 0.92, 0.9), "round_glasses": true,
		"hair_color": Color(0.85, 0.85, 0.83), "height": 1.56,
		"skin": Color(1.0, 0.9, 0.86), "bulk": 0.35, "belly": 0.3, "shoulders": -0.4, "muscle": -1.0},
	"Pieni poika": {"shirt": Color(0.15, 0.35, 0.85), "pants": Color(0.2, 0.2, 0.25), "shoes": Color(0.2, 0.2, 0.2),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.85, 0.72, 0.42), "height": 1.3, "bulk": -0.85, "shoulders": -0.8},
	"Verotoimiston Raimo": {"shirt": Color(0.85, 0.86, 0.9), "pants": Color(0.25, 0.27, 0.32), "shoes": Color(0.08, 0.08, 0.08),
		"hair": "Hair_SimpleParted", "hair_color": Color(0.6, 0.58, 0.55), "height": 1.74, "belly": 0.55},
	"Unenpöpperöinen yövuorolainen": {"shirt": Color(0.6, 0.62, 0.66), "pants": Color(0.35, 0.36, 0.5),
		"shoes": Color(0.9, 0.9, 0.9), "hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.22, 0.15), "height": 1.8, "belly": 0.4},
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
		"Siviikki-Timo":
			return Looks.SIVIIKKI_TIMO
		"Pannu-Sulo":
			return Looks.SULO
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
	match mode:
		"ovi":
			_door = 0.0
			_door_to = 0.0
			Sfx.play("punch", -6.0, 0.7)
			var smell := "Sandelsille" if site == "saloinen" else "bensalle ja Siviikin kytkimelle"
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
		"Siviikki-Timo":
			return "Timo. Honda on tuossa. Se on lämmin vielä."
	return "Moi."


func _morning_lines() -> Array:
	if site == "saloinen":
		return [["", "Aamulla Minttu keittää kahvit. Ruusut on maljakossa ikkunalla."],
			["Esa", "Rasvanapin jälkeen pitää syödä rasvasta. Se on luonnon kiertokulku."],
			["Joni", "Mansikkaletut ja kermavaahto. Tää on kuin birdie avausreiällä."],
			["Minttu", "Tulkaa uudestaan. Mutta ens kerralla ilman harppia."],
			["", "Puhelimessa vastaamaton puhelu: Päivi. Ja viesti: \"MAITOA.\""]]
	return [["", "Aamulla Katja keittää kahvit. Ruusut on maitopurkissa, koska maljakkoa ei löytynyt."],
		["Hevari-Tero", "Valtio ei saa näistä letuista senttiäkään. Ei senttiäkään."],
		["Siviikki-Timo", "Siviikki lämpiää pihassa. Kuka tarvii kyydin? VTEC on jo hereillä."],
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
	if (adv and _line_t > 0.4) or (auto and _line_t > 6.5):
		_next()


func _next() -> void:
	_line += 1
	_line_t = 0.0
	if _line >= lines.size():
		_finish()
		return
	var l: Array = lines[_line]
	if mode in ["ovi", "vaara"] and _line == 1:
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
	_draw_text(s, k)


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
			var want := _table_top + Vector3(-0.22 + i * 0.22, 0, 0)
			prop.global_position = prop.global_position.lerp(want, 1.0 - exp(-8.0 * delta)) if delta > 0.0 else want
			if _holding.has(nimi):
				_holding.erase(nimi)
				ch.clear_ik()
				ch.set_meta("busy_until", _t + 1.2)
		elif ch != null:
			_hold(ch, prop)
			_holding[nimi] = prop
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
		ch.set_ik_orient("arm" + sfx, Pose.palm_on(Vector3(0, 0, -1), Vector3(-sd, 0, 0), sd < 0.0), 1.0)
	prop.global_position = ch.to_global(mid + Vector3(0, -prop.get_meta("grip", 0.04), -PALM_FWD))
	prop.global_rotation = Vector3(0, ch.global_rotation.y, 0)


# --- Lavastukset ---------------------------------------------------------------------------------------------

## Idle-asennossa kengänpohjat ovat 4,5-5,4 cm mallin origon alapuolella (mitattu paistetusta verkosta,
## Pose.limb_points): hahmo nostetaan, ettei jalkaterä uppoa lattiaan (Asento.solids, kolmio_kuvat.gd).
const SOLE := 0.05


func _person(nimi: String, at: Vector3, yaw: float) -> Node3D:
	var ch: Node3D = Looks.make(_stage, _look(nimi))
	ch.position = at + Vector3(0, SOLE, 0)
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
	var white := Color(0.95, 0.95, 0.92)
	# Maa: nurmikko ja polku portaille.
	B.mesh(_stage, B.boxm(Vector3(16, 0.1, 12)), Vector3(0, -0.05, 4), Color(0.22, 0.36, 0.16))
	for k in 6:
		B.mesh(_stage, B.boxm(Vector3(1.0, 0.04, 0.5)), Vector3(0, 0.0, 1.4 + k * 0.62), Color(0.55, 0.53, 0.5))
	# Julkisivu oven ympärillä (oviaukko x -0,55..0,55, y 0,5..2,6), sokkeli ja lautavuoraus.
	for part in [[Vector3(3.45, 3.6, 0.15), Vector3(-2.275, 1.8, -0.075)], [Vector3(3.45, 3.6, 0.15), Vector3(2.275, 1.8, -0.075)],
			[Vector3(1.1, 1.0, 0.15), Vector3(0, 3.1, -0.075)]]:
		B.mesh(_stage, B.boxm(part[0]), part[1], wall)
	B.mesh(_stage, B.boxm(Vector3(8.0, 0.5, 0.2)), Vector3(0, 0.25, -0.05), Color(0.5, 0.5, 0.48))
	for i in 17:
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
	var hinge := Node3D.new()
	hinge.position = Vector3(-0.53, 0.52, 0.0)
	_stage.add_child(hinge)
	_leaf = hinge
	var door_col := Color(0.55, 0.2, 0.12) if site == "saloinen" else Color(0.15, 0.32, 0.26)
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
	var plate := B.sign_plate(_stage, "7" if site == "saloinen" else "B 3", Color(0.1, 0.25, 0.5), Color.WHITE, 0.22, 60)
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
	_camera(Vector3(2.0, 1.95, 5.2), Vector3(-0.1, 1.35, 0.2), 44.0, _env(Color(0.05, 0.06, 0.13), Color(0.4, 0.45, 0.65), 0.22))
	# Avaaja ovella kasvot pihalle; kolmiomittaajat portaiden juurella kasvot ovelle.
	if mode == "ovi":
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


## Lahjat 3D:nä: mansikkarasia (puurasia ja marjat lehtineen), kermavaahtospray (tölkki, sininen etiketti, punainen
## korkki ja suutin) ja ruusukimppu (paperikartio, varret ja kukat).
func _gift_prop(what: String) -> Node3D:
	var n := Node3D.new()
	_stage.add_child(n)
	# half = lahjan puolileveys otteen kohdalla, grip = otteen korkeus lahjan pohjasta (_hold).
	if what.begins_with("mansik"):
		n.set_meta("half", 0.1)
		n.set_meta("grip", 0.035)
		B.mesh(n, B.boxm(Vector3(0.2, 0.07, 0.14)), Vector3(0, 0.035, 0), Color(0.72, 0.56, 0.34))
		for i in 12:
			var p := Vector3(-0.075 + (i % 4) * 0.05, 0.08 + (i / 4) * 0.012, -0.045 + (i / 4) * 0.045)
			B.mesh(n, B.sphere(0.022, 8), p, Color(0.82, 0.06, 0.1)).scale = Vector3(1.0, 1.15, 1.0)
			B.mesh(n, B.cyl(0.012, 0.004, 0.01, 6), p + Vector3(0, 0.025, 0), Color(0.2, 0.55, 0.2))
	elif what.begins_with("kerma"):
		n.set_meta("half", 0.0355)
		n.set_meta("grip", 0.1)
		B.mesh(n, B.cyl(0.035, 0.035, 0.2, 14), Vector3(0, 0.1, 0), Color(0.92, 0.93, 0.96))
		B.mesh(n, B.cyl(0.0355, 0.0355, 0.07, 14), Vector3(0, 0.1, 0), Color(0.2, 0.4, 0.8))
		B.mesh(n, B.cyl(0.03, 0.035, 0.03, 14), Vector3(0, 0.215, 0), Color(0.85, 0.1, 0.15))
		B.mesh(n, B.cyl(0.006, 0.01, 0.04, 8), Vector3(0, 0.25, 0.01), Color(0.85, 0.1, 0.15), Vector3(25, 0, 0))
	else:
		n.set_meta("half", 0.07)  # kartio 0,015 -> 0,07: nyrkki ulottuu lähes yläreunaan, joten levein säde
		n.set_meta("grip", 0.14)
		B.mesh(n, B.cyl(0.07, 0.015, 0.22, 12), Vector3(0, 0.11, 0), Color(0.95, 0.92, 0.84))
		for i in 6:
			var a := i * TAU / 6.0
			var p := Vector3(cos(a) * 0.04, 0.27, sin(a) * 0.04)
			B.tube(n, Vector3(0, 0.15, 0), p, 0.004, Color(0.2, 0.5, 0.2))
			B.mesh(n, B.sphere(0.03, 10), p, Color(0.72, 0.03, 0.1))
		B.mesh(n, B.sphere(0.03, 10), Vector3(0, 0.29, 0), Color(0.75, 0.04, 0.12))
	return n


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
	if site == "saloinen":
		B.mesh(_stage, B.cyl(0.05, 0.07, 0.22, 14), vase + Vector3(0, 0.11, 0), Color(0.45, 0.7, 0.85))
	else:
		B.mesh(_stage, B.boxm(Vector3(0.09, 0.22, 0.09)), vase + Vector3(0, 0.11, 0), Color(0.95, 0.95, 0.95))
		B.mesh(_stage, B.boxm(Vector3(0.092, 0.08, 0.092)), vase + Vector3(0, 0.09, 0), Color(0.2, 0.4, 0.8))
	for i in 5:
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
