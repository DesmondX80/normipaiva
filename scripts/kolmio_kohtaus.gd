extends CanvasLayer
## Kolmiomittauksen (#255) kohtaukset piirrettynä (kolmiomittaus.gd): sarjakuvamainen ruutu, repliikit vuorotellen,
## E jatkaa ja Esc ohittaa loppuun. finished(r) kertoo tuloksen main.gd:lle.
##   "ovi"    naisen ovi illalla: nainen ovella, kolmiomittaajat portailla lahjat käsissä. Lahjat ojennetaan
##            vuorotellen kuin itämaan tietäjät; jos pelaajan lahja puuttuu, ovi menee kiinni (r.ok = false).
##   "vaara"  väärä ovi: joku muu avaa (mummo kepin kanssa, Pannu-Sulo, ...) ja pelaaja perääntyy.
##   "aamu"   onnellinen loppu: aamukahvit naisen keittiössä, mansikkaletut, ruusut maljakossa.

signal finished(r: Dictionary)

const MG := preload("res://scripts/mg_draw.gd")

var mode := "ovi"
var site := "saloinen"
var woman := "Minttu"
var friends: Array = ["Joni", "Esa"]
var gifts: Array = []  # [[antaja, lahja], ...]
var missing := ""  # pelaajan puuttuva lahja ("" = kaikki mukana)
var resident := {}  # väärä ovi: kolmiomittaus.gd WRONG_DOORS
var stats := ""  # aamun tilastorivi
var lines: Array = []  # [puhuja, teksti]; rakennetaan _ready:ssä

var _view: Control
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

const HAIR_MINTTU := Color(0.8, 0.24, 0.09)
const HAIR_KATJA := Color(0.05, 0.04, 0.05)
## Piirretyt hahmot (mg_draw.gd MG.figure). Naiset vähintään yhtä hemaisevia kuin Sinikka (bust 2,7, curves 1,0).
const LOOKS := {
	"me": {"skin": Color(1.0, 0.9, 0.82), "hair": "parted", "hair_col": Color(0.82, 0.66, 0.4), "shirt": Color(0.42, 0.18, 0.58),
		"stripes": true, "cap": true, "beard": true, "pants": Color(0.42, 0.18, 0.58), "shoes": Color(0.9, 0.9, 0.88)},
	"Joni": {"skin": Color(0.98, 0.84, 0.74), "hair": "parted", "hair_col": Color(0.07, 0.05, 0.04), "shirt": Color(0.95, 0.95, 0.92),
		"short_sleeve": true, "pants": Color(0.82, 0.75, 0.58)},
	"Esa": {"skin": Color(0.95, 0.76, 0.64), "hair": "short", "hair_col": Color(0.42, 0.3, 0.18), "shirt": Color(0.24, 0.36, 0.2),
		"flannel": true, "beard": true, "pants": Color(0.33, 0.3, 0.2)},
	"Hevari-Tero": {"skin": Color(0.97, 0.84, 0.76), "hair": "metal", "hair_col": Color(0.2, 0.15, 0.12), "shirt": Color(0.06, 0.06, 0.07),
		"beard": true, "pants": Color(0.1, 0.1, 0.12)},
	"Siviikki-Timo": {"skin": Color(0.98, 0.84, 0.74), "hair": "short", "hair_col": Color(0.55, 0.42, 0.25), "shirt": Color(0.78, 0.07, 0.1),
		"cap": true, "cap_col": Color(0.85, 0.85, 0.88), "pants": Color(0.22, 0.3, 0.48)},
	"Minttu": {"skin": Color(1.0, 0.9, 0.84), "hair": "curls", "hair_col": HAIR_MINTTU, "shirt": Color(1.0, 0.82, 0.25), "woman": true,
		"bust": 2.7, "curves": 1.0, "dress": true, "freckles": true, "eyes": Color(0.25, 0.55, 0.35), "shoes": Color(0.95, 0.93, 0.88)},
	"Katja": {"skin": Color(0.98, 0.86, 0.78), "hair": "long", "hair_col": HAIR_KATJA, "shirt": Color(0.08, 0.07, 0.08), "woman": true,
		"bust": 2.7, "curves": 1.0, "jacket": true, "pants": Color(0.16, 0.2, 0.32), "shoes": Color(0.04, 0.04, 0.04)},
	"Mummo kepin kanssa": {"skin": Color(1.0, 0.9, 0.86), "hair": "buns", "hair_col": Color(0.9, 0.9, 0.88), "shirt": Color(0.56, 0.36, 0.55),
		"glasses": true, "woman": true, "pants": Color(0.32, 0.24, 0.2), "dress": false},
	"Pannu-Sulo": {"skin": Color(1.0, 0.84, 0.78), "hair": "short", "hair_col": Color(0.7, 0.7, 0.68), "shirt": Color(0.55, 0.12, 0.1),
		"flannel": true, "beard": true, "pants": Color(0.25, 0.3, 0.2)},
	"Pieni poika": {"skin": Color(1.0, 0.88, 0.8), "hair": "short", "hair_col": Color(0.85, 0.72, 0.42), "shirt": Color(0.2, 0.45, 0.85),
		"pants": Color(0.2, 0.2, 0.25), "short_sleeve": true},
	"Verotoimiston Raimo": {"skin": Color(0.96, 0.82, 0.74), "hair": "parted", "hair_col": Color(0.6, 0.58, 0.55), "shirt": Color(0.85, 0.86, 0.9),
		"glasses": true, "tie": true, "pants": Color(0.25, 0.27, 0.32)},
	"Unenpöpperöinen yövuorolainen": {"skin": Color(0.95, 0.8, 0.72), "hair": "short", "hair_col": Color(0.3, 0.22, 0.15),
		"shirt": Color(0.6, 0.62, 0.66), "pants": Color(0.35, 0.36, 0.5)},
}


func _ready() -> void:
	add_to_group("esc_lopettaa")
	layer = 7
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
		"vaara":
			_door = 0.0
			_door_to = 0.0
			Sfx.play("punch", -6.0, 0.7)
			lines = [["", "KOP KOP KOP"], [resident.who, resident.line], ["", resident.after]]
		"aamu":
			lines = _morning_lines()
	_line_t = 0.0


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
	if _done:
		return
	if Input.is_key_pressed(KEY_ESCAPE):
		_finish()
		return
	var adv := Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")
	if (adv and _line_t > 0.4) or _line_t > 6.5:
		_next()
	_view.queue_redraw()


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
		Sfx.play("pickup", -4.0, 1.0 + _given * 0.15)
		MG.sparks_burst(_sparks, _woman_pos() + Vector2(-40, 20), Color(1.0, 0.85, 0.4), 14)
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


func _woman_pos() -> Vector2:
	var s := _size()
	return Vector2(s.x * 0.5, s.y * 0.44)


func _draw_all() -> void:
	var s := _size()
	var k := s.y / 720.0
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 10.0
	_view.draw_set_transform(off, 0, Vector2.ONE)
	if mode == "aamu":
		_draw_kitchen(s, k)
	else:
		_draw_porch(s, k)
	MG.sparks_draw(_view, _sparks)
	_view.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_draw_text(s, k)


## Talon kuisti illalla: lautaseinä, ovi ikkunoineen, kuistin lamppu, portaat; ovella avaaja ja portailla kolmikko.
func _draw_porch(s: Vector2, k: float) -> void:
	MG.grad_rect(_view, Rect2(Vector2.ZERO, s), Color(0.1, 0.12, 0.26), Color(0.32, 0.22, 0.32))  # iltataivas
	var wall_col := Color(0.86, 0.78, 0.55) if site == "saloinen" else Color(0.55, 0.38, 0.3)
	var wall := Rect2(s.x * 0.12, s.y * 0.08, s.x * 0.76, s.y * 0.7)
	MG.solid(_view, wall, wall_col)
	for i in int(wall.size.y / (16 * k)):  # vaakapanelointi
		var y := wall.position.y + i * 16 * k
		_view.draw_line(Vector2(wall.position.x, y), Vector2(wall.end.x, y), wall_col.darkened(0.18), 1.5)
	# Ikkunat valaistuina.
	for wx in [0.2, 0.68]:
		var wr := Rect2(s.x * wx, s.y * 0.2, s.x * 0.12, s.y * 0.2)
		MG.box(_view, wr.grow(6 * k), Color(0.95, 0.95, 0.92), int(3 * k))
		MG.grad_rect(_view, wr, Color(1.0, 0.86, 0.5), Color(0.95, 0.65, 0.3))
		_view.draw_line(Vector2(wr.get_center().x, wr.position.y), Vector2(wr.get_center().x, wr.end.y), Color(0.95, 0.95, 0.92), 4 * k)
		_view.draw_line(Vector2(wr.position.x, wr.get_center().y), Vector2(wr.end.x, wr.get_center().y), Color(0.95, 0.95, 0.92), 4 * k)
	# Ovi: karmi, aukko (sisältä lämmin valo) ja ovilehti, joka kiertyy auki.
	var dr := Rect2(s.x * 0.43, s.y * 0.18, s.x * 0.14, s.y * 0.52)
	MG.box(_view, dr.grow(8 * k), Color(0.95, 0.95, 0.92), int(3 * k), int(4 * k))
	MG.grad_rect(_view, dr, Color(1.0, 0.85, 0.55), Color(0.85, 0.55, 0.3))
	MG.glow(_view, dr.get_center(), dr.size.y * 0.6 * _door, Color(1.0, 0.8, 0.45, 0.5))
	if _door > 0.15:
		_draw_opener(dr, k)
	var leaf_w := dr.size.x * (1.0 - 0.82 * _door)
	var leaf := Rect2(dr.position, Vector2(leaf_w, dr.size.y))
	var door_col := Color(0.55, 0.2, 0.12) if site == "saloinen" else Color(0.15, 0.3, 0.25)
	MG.solid(_view, leaf, door_col)
	if leaf_w > 20 * k:
		MG.grad_rect(_view, Rect2(leaf.position + Vector2(leaf_w * 0.25, dr.size.y * 0.1), Vector2(leaf_w * 0.5, dr.size.y * 0.25)),
			Color(0.7, 0.8, 0.9), Color(0.45, 0.55, 0.7))
		MG.ball(_view, Vector2(leaf.end.x - 10 * k, dr.get_center().y), 5 * k, Color(0.85, 0.75, 0.4), 0.6)
	# Kuistin lamppu ja yöperhoset.
	var lamp := Vector2(dr.end.x + 34 * k, dr.position.y + 20 * k)
	MG.glow(_view, lamp, 140 * k, Color(1.0, 0.9, 0.6, 0.6))
	MG.box(_view, Rect2(lamp - Vector2(10, 14) * k, Vector2(20, 28) * k), Color(1.0, 0.95, 0.75), int(6 * k), 0, MG.OUTLINE, 2)
	for i in 3:
		var mp := lamp + Vector2(sin(_t * 5.0 + i * 2.0) * 30, cos(_t * 4.0 + i) * 22) * k
		_view.draw_circle(mp, 2.5 * k, Color(0.9, 0.85, 0.75))
	# Talon numero kylttinä oven vieressä.
	MG.sign(_view, Rect2(dr.position.x - 60 * k, dr.position.y + 20 * k, 40 * k, 30 * k), "7" if site == "saloinen" else "B 3",
		Color(0.1, 0.25, 0.5), Color.WHITE, int(16 * k))
	# Portaat ja maa.
	MG.grad_rect(_view, Rect2(0, s.y * 0.78, s.x, s.y * 0.22), Color(0.25, 0.32, 0.2), Color(0.12, 0.16, 0.1))
	for i in 3:
		var st := Rect2(dr.position.x - (40 + i * 30) * k, dr.end.y + i * 18 * k, dr.size.x + (80 + i * 60) * k, 18 * k)
		MG.solid(_view, st, Color(0.62, 0.62, 0.6))
	if mode == "ovi":
		_draw_trio(s, k)
	else:
		# Vain pelaaja portailla, lahja selän takana.
		MG.figure(_view, Vector2(s.x * 0.5, s.y * 0.8), 1.0 * k, LOOKS.me, {"eye": Vector2(0, -0.6), "blink": _line >= 2})


## Avaaja ovella koko hahmona (pää karmin yläosassa, jalat kynnyksellä): nainen tai väärän oven asukas.
func _draw_opener(dr: Rect2, k: float) -> void:
	var sc := dr.size.y / 320.0
	var c := Vector2(dr.get_center().x + dr.size.x * 0.06, dr.end.y - 280.0 * sc)
	if mode == "ovi":
		_woman(c, sc, _line_t < 1.0 or _line % 2 == 1, true)
		return
	var who: String = resident.get("who", "")
	var look: Dictionary = LOOKS.get(who, LOOKS["Pannu-Sulo"])
	var talk := _line == 1 and fmod(_t * 3.0, 1.0) < 0.6
	if who == "Pieni poika":
		sc *= 0.62
		c = Vector2(c.x, dr.end.y - 280.0 * sc)
	var up := who == "Mummo kepin kanssa" and _line >= 2  # keppi nousee viimeisellä repliikillä
	if who == "Pannu-Sulo":
		_canister(c + Vector2(-58, 150) * sc, sc)
	MG.figure(_view, c, sc, look, {"talk": talk, "eye": Vector2(0, 0.3), "legs": true, "arms": "wave" if up else "down"})
	if who == "Mummo kepin kanssa":
		var hand := c + (Vector2(62, -12) if up else Vector2(42, 136)) * sc
		var tip := hand + (Vector2(14, -110) if up else Vector2(10, 140)) * sc
		_view.draw_line(hand, tip, MG.OUTLINE, 9 * sc)
		_view.draw_line(hand, tip, Color(0.45, 0.3, 0.15), 6 * sc)
		_view.draw_arc(hand + Vector2(-8, 0) * sc, 9 * sc, PI, TAU, 8, Color(0.45, 0.3, 0.15), 6 * sc)
		if up:
			_view.draw_string(ThemeDB.fallback_font, tip + Vector2(10, 0) * sc, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(40 * sc),
				Color(0.85, 0.1, 0.1))


## Nainen (Minttu tai Katja) ovella tai keittiössä. Ojennetut lahjat sylissä, kädet niiden alla.
func _woman(c: Vector2, sc: float, talk: bool, legs := false) -> void:
	var holding := mode == "ovi" and _given > 0
	MG.figure(_view, c, sc, LOOKS[woman], {"talk": talk, "eye": Vector2(-0.2, 0.4), "legs": legs, "arms": "hold" if holding else "down"})
	var got := 0
	for g: Array in gifts:
		if got >= _given or mode != "ovi":
			break
		_gift(c + Vector2(-24 + got * 24, 100) * sc, sc * 0.8, g[1])
		got += 1


## Kolmiomittaajat portailla: kaverit sivuilla, pelaaja keskellä edessä. Antamattomat lahjat käsissä.
func _draw_trio(s: Vector2, k: float) -> void:
	var y := s.y * 0.8
	var pos := {friends[0]: Vector2(s.x * 0.3, y - 10 * k), friends[1]: Vector2(s.x * 0.7, y - 10 * k), "Sinä": Vector2(s.x * 0.5, y + 30 * k)}
	var given_by: Array = []
	for i in mini(_given, gifts.size()):
		given_by.append(gifts[i][0])
	for who in [friends[0], friends[1], "Sinä"]:
		var c: Vector2 = pos.get(who, Vector2(s.x * 0.5, y))
		var key: String = "me" if who == "Sinä" else String(who)
		var talk := false
		if _line < lines.size() and lines[_line][0] == who:
			talk = fmod(_t * 3.0, 1.0) < 0.6
		var gift := ""
		for g: Array in gifts:
			if (g[0] == who or g[0] == _short(who)) and not g[0] in given_by and not (who == "Sinä" and missing != ""):
				gift = g[1]
		if key == "Joni":
			_sandels_pack(c + Vector2(44, 52) * k, k)  # rinkka olan takana
		MG.figure(_view, c, 1.0 * k, LOOKS.get(key, LOOKS.me), {"talk": talk, "eye": Vector2(0, -0.7), "arms": "hold" if gift != "" else "down"})
		if gift != "":
			_gift(c + Vector2(0, 100) * k, k, gift)


func _short(full: String) -> String:
	return full.get_slice("-", 1) if "-" in full else full


## Lahjat: mansikkarasia, kermavaahtospray ja ruusukimppu.
func _gift(c: Vector2, sc: float, what: String) -> void:
	if what.begins_with("mansik"):
		MG.box(_view, Rect2(c + Vector2(-26, -8) * sc, Vector2(52, 26) * sc), Color(0.45, 0.62, 0.3), int(4 * sc), 0, MG.OUTLINE, 2)
		for i in 9:
			var p := c + Vector2(-20 + (i % 5) * 10 + (i / 5) * 5, -10 - (i / 5) * 8) * sc
			_view.draw_circle(p, 6 * sc, Color(0.85, 0.08, 0.12))
			_view.draw_circle(p + Vector2(-2, -2) * sc, 1.6 * sc, Color(1.0, 0.6, 0.6))
			_view.draw_line(p + Vector2(0, -6) * sc, p + Vector2(2, -9) * sc, Color(0.2, 0.55, 0.2), 2 * sc)
	elif what.begins_with("kerma"):
		var r := Rect2(c + Vector2(-10, -40) * sc, Vector2(20, 54) * sc)
		MG.grad_rect(_view, r, Color(0.98, 0.98, 1.0), Color(0.75, 0.78, 0.85))
		_view.draw_rect(r, MG.OUTLINE, false, 2.0)
		_view.draw_rect(Rect2(r.position + Vector2(0, 18 * sc), Vector2(r.size.x, 12 * sc)), Color(0.2, 0.4, 0.8))
		MG.box(_view, Rect2(r.position + Vector2(3, -10) * sc, Vector2(14, 10) * sc), Color(0.85, 0.1, 0.15), int(3 * sc), 0, MG.OUTLINE, 1)
		_view.draw_line(r.position + Vector2(10, -10) * sc, r.position + Vector2(16, -16) * sc, Color(0.85, 0.1, 0.15), 3 * sc)
	else:
		# Ruusut: paperikartio, varret ja kukat.
		_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -24) * sc, c + Vector2(20, -24) * sc, c + Vector2(0, 26) * sc]),
			Color(0.95, 0.92, 0.85))
		_view.draw_polyline(PackedVector2Array([c + Vector2(-20, -24) * sc, c + Vector2(0, 26) * sc, c + Vector2(20, -24) * sc]),
			MG.OUTLINE, 2.0)
		for i in 5:
			var p := c + Vector2(-16 + i * 8, -30 - (i % 2) * 8) * sc
			_view.draw_circle(p + Vector2(0, 6) * sc, 4 * sc, Color(0.2, 0.5, 0.2))
			_view.draw_circle(p, 7 * sc, Color(0.7, 0.04, 0.1))
			_view.draw_arc(p, 4 * sc, 0, PI * 1.5, 8, Color(0.45, 0.02, 0.06), 1.5 * sc)


## Jonin Sandels-päkkirinkka sivulta: pahvilaatikko, jesariteipit, kyljessä termos ja tölkki.
func _sandels_pack(c: Vector2, k: float) -> void:
	var r := Rect2(c + Vector2(-14, -40) * k, Vector2(30, 70) * k)
	MG.solid(_view, r, Color(0.12, 0.3, 0.62))
	_view.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 40 * k), "S", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(20 * k),
		Color(1.0, 0.95, 0.85))
	for yy in [12.0, 52.0]:
		_view.draw_rect(Rect2(r.position + Vector2(-2, yy) * k, Vector2(34, 6) * k), Color(0.62, 0.64, 0.66))
	MG.box(_view, Rect2(r.end.x, r.position.y + 10 * k, 9 * k, 30 * k), Color(0.7, 0.1, 0.1), int(3 * k), 0, MG.OUTLINE, 1)


func _canister(c: Vector2, sc: float) -> void:
	MG.box(_view, Rect2(c + Vector2(-18, -26) * sc, Vector2(36, 46) * sc), Color(0.9, 0.85, 0.75), int(5 * sc), 0, MG.OUTLINE, 2)
	MG.box(_view, Rect2(c + Vector2(-6, -34) * sc, Vector2(12, 9) * sc), Color(0.85, 0.1, 0.1), int(2 * sc), 0, MG.OUTLINE, 1)


## Aamu naisen keittiössä: aurinkoinen ikkuna, pöytä, kahvipannu, lettupino mansikoineen ja kermavaahtoineen,
## ruusut maljakossa. Nainen kaataa kahvia, kaveri lettupannun kanssa liedellä.
func _draw_kitchen(s: Vector2, k: float) -> void:
	MG.grad_rect(_view, Rect2(Vector2.ZERO, s), Color(0.98, 0.93, 0.8), Color(0.9, 0.82, 0.68))
	for i in int(s.x / (40 * k)) + 1:  # tapetin raidat
		_view.draw_rect(Rect2(i * 40 * k, 0, 14 * k, s.y * 0.62), Color(0.95, 0.85, 0.7, 0.6))
	var win := Rect2(s.x * 0.36, s.y * 0.08, s.x * 0.28, s.y * 0.3)
	MG.box(_view, win.grow(10 * k), Color(0.97, 0.97, 0.95), int(4 * k), int(4 * k))
	MG.grad_rect(_view, win, Color(0.6, 0.82, 1.0), Color(0.85, 0.95, 1.0))
	_view.draw_circle(win.position + Vector2(win.size.x * 0.75, win.size.y * 0.35), 26 * k, Color(1.0, 0.92, 0.5))
	MG.glow(_view, win.get_center(), win.size.x * 0.9, Color(1.0, 0.95, 0.75, 0.35))
	_view.draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color(0.97, 0.97, 0.95), 6 * k)
	# Kaverit ja nainen pöydän takana.
	var f0: String = friends[0]
	var f1: String = friends[1]
	var talk_who: String = lines[_line][0] if _line < lines.size() else ""
	_woman(Vector2(s.x * 0.5, s.y * 0.38), 1.3 * k, talk_who == woman and fmod(_t * 3.0, 1.0) < 0.6)
	MG.figure(_view, Vector2(s.x * 0.2, s.y * 0.4), 1.3 * k, LOOKS.get(f0, LOOKS.me), {"eye": Vector2(0.5, 0.3),
		"talk": talk_who == f0 and fmod(_t * 3.0, 1.0) < 0.6, "blink": fmod(_t, 4.0) < 0.12})
	MG.figure(_view, Vector2(s.x * 0.8, s.y * 0.4), 1.3 * k, LOOKS.get(f1, LOOKS.me), {"eye": Vector2(-0.5, 0.3),
		"talk": talk_who == f1 and fmod(_t * 3.0, 1.0) < 0.6, "arms": "wave"})
	# Lettupannu kaverin ylös nostetussa kädessä, letut hyppivät.
	var pan := Vector2(s.x * 0.8, s.y * 0.4) + Vector2(68, -16) * 1.3 * k
	_view.draw_line(pan + Vector2(10, 4) * k, pan + Vector2(60, 14) * k, Color(0.15, 0.12, 0.1), 7 * k)
	MG.box(_view, Rect2(pan + Vector2(-34, -4) * k, Vector2(48, 12) * k), Color(0.2, 0.2, 0.22), int(5 * k), 0, MG.OUTLINE, 2)
	var hop := absf(sin(_t * 3.0)) * 40.0 * k
	MG.box(_view, Rect2(pan + Vector2(-30, -10) * k - Vector2(0, hop), Vector2(40, 8) * k), Color(0.95, 0.75, 0.4), int(4 * k), 0, MG.OUTLINE, 1)
	# Pöytä: puupinta, kahvikupit, pannu, lettupino ja ruusut.
	var tr := Rect2(0, s.y * 0.62, s.x, s.y * 0.38)
	MG.wood(_view, tr, Color(0.72, 0.52, 0.3), 46 * k, 11, true)
	_view.draw_line(tr.position, Vector2(tr.end.x, tr.position.y), Color(0.45, 0.3, 0.15), 4 * k)
	var stack := Vector2(s.x * 0.5, tr.position.y + 70 * k)
	for i in 6:
		MG.box(_view, Rect2(stack + Vector2(-60, -i * 9) * k, Vector2(120, 10) * k), Color(0.95, 0.75, 0.4).darkened(0.04 * (i % 2)),
			int(5 * k), 0, MG.OUTLINE, 1)
	_view.draw_circle(stack + Vector2(0, -62) * k, 26 * k, Color(1.0, 1.0, 0.98))  # kermavaahto
	_view.draw_circle(stack + Vector2(-10, -78) * k, 14 * k, Color(1.0, 1.0, 0.98))
	_gift(stack + Vector2(30, -66) * k, k * 0.9, "mansikat")
	var vase := Vector2(s.x * 0.18, tr.position.y + 20 * k)
	MG.box(_view, Rect2(vase + Vector2(-18, -30) * k, Vector2(36, 50) * k), Color(0.5, 0.75, 0.85, 0.85), int(10 * k), 0, MG.OUTLINE, 2)
	_gift(vase + Vector2(0, -60) * k, k * 1.1, "ruusut")
	for cx in [0.32, 0.68, 0.84]:
		var cup := Vector2(s.x * cx, tr.position.y + 60 * k)
		MG.box(_view, Rect2(cup + Vector2(-16, -18) * k, Vector2(32, 26) * k), Color(0.97, 0.97, 0.95), int(6 * k), 0, MG.OUTLINE, 2)
		_view.draw_arc(cup + Vector2(18, -6) * k, 7 * k, -PI / 2.0, PI / 2.0, 8, MG.OUTLINE, 2.5 * k)
		for j in 2:  # höyry
			var sx := sin(_t * 2.0 + cx * 10.0 + j) * 5.0 * k
			_view.draw_line(cup + Vector2(-4 + j * 8, -22) * k + Vector2(sx, 0), cup + Vector2(-4 + j * 8, -40) * k - Vector2(sx, 0),
				Color(1, 1, 1, 0.6), 2.5 * k)
	var pot := Vector2(s.x * 0.6, tr.position.y + 10 * k)
	MG.box(_view, Rect2(pot + Vector2(-22, -40) * k, Vector2(44, 50) * k), Color(0.75, 0.75, 0.78), int(8 * k), 3, MG.OUTLINE, 2)
	_view.draw_line(pot + Vector2(-22, -30) * k, pot + Vector2(-40, -42) * k, Color(0.75, 0.75, 0.78), 6 * k)


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
