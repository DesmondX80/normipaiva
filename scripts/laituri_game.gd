extends "res://scripts/kota_minigame.gd"
## Laiturin korjaus (Santun homma), FPS-minipeli polvillaan laiturin kannella. Lahot laudat irti sorkkaraudalla
## (klikkaa lautaa, kunnes se irtoaa), uusi lauta paikalleen (klikkaa tyhjää kohtaa) ja kaksi naulaa kumpaankin
## päähän: tähtää naulan kantaan ja lyö. Vino isku taivuttaa naulan (oikea nappi vetää sen pois), ja ohi lyönti
## osuu helposti peukaloon, joka pitelee naulaa. Santtu katsoo vieressä ja kommentoi.
## mokki.gd:n laiturin (dock_body) lapsi: origo = paikkalautojen alku kannen pinnalla, +Z järvelle päin.

const Mokki := preload("res://scripts/mokki.gd")

signal fixed_plank
signal thumb

const SLOTS := 3
const PITCH := 0.55  # lautojen jako laiturissa
const DECK_Y := 0.27  # kannen pinta laiturin kehyksessä
const NAIL_X := 0.58
const NAIL_HIT := 0.022  # tätä lähempää kantaan naula uppoaa
const NAIL_GLANCE := 0.05  # tätä lähempää isku menee vinoon
const THUMB_R := 0.065
const PRY_CLICKS := 3
const EYE := Vector3(0.0, 1.0, -0.9)

const LAHO := Color(0.42, 0.41, 0.36)  # harmaantunut, laho
const FRESH := Color(0.78, 0.74, 0.5)  # painekyllästetty, vihertävä
const NAIL := Color(0.62, 0.62, 0.64)
const SKIN := Color(0.93, 0.74, 0.6)
const SLEEVE := Color(0.05, 0.55, 0.58)  # tuulipuku
const STEEL := Color(0.3, 0.31, 0.34)

const LINES := {
	"start": [["santtu", "Lahot pois, uudet tilalle. Naulat on purkissa."], ["santtu", "Polvillaan ollaan, ei kumarrella. Selkä kiittää."],
		["santtu", "Naula päähän, ei peukaloon."]],
	"pry": [["santtu", "Väännä, väännä! Se on lahonnu kiinni."], ["santtu", "Sorkkarauta on tehty tähän."]],
	"pried": [["santtu", "Irti on! Tuo menee saunan pesään."], ["santtu", "Kato miten laho. Hyvä ettei kukaan tippunu."]],
	"placed": [["santtu", "Uus lauta paikalleen. Sydänpuoli alas."], ["santtu", "Hyvää painekyllästettyä. Kestää lapsenlapsille."]],
	"nail": [["santtu", "Hyvä isku!"], ["santtu", "Noin se uppoaa."]],
	"nail_done": [["santtu", "Kanta pintaan. Kunnon naula."], ["santtu", "Siinä se on."]],
	"bent": [["santtu", "Naula meni vinoon! Pois ja uus."], ["santtu", "Ei sitä noin hakata!"], ["santtu", "Banaani. Vedä pois."]],
	"glance": [["santtu", "Lipsahti. Suoraan päälle."], ["santtu", "Kanta on keskellä, ei vieressä."]],
	"pull": [["santtu", "Uus naula purkista. Niitä on."], ["santtu", "Vasaran takaosalla saa irti."]],
	"thumb": [["santtu", "Peukalo ei oo naula!"], ["santtu", "No voi... laita kylmää järvivettä."],
		["santtu", "Ei sitä noin hakata! Kato mihin lyöt."], ["santtu", "Kiroilu on sallittua, mutta naapurit kuulee."]],
	"miss": [["santtu", "Ohi. Lauta ei oo vihollinen."], ["santtu", "Tähtää naulaan."]],
	"plank_done": [["santtu", "Lauta valmis! Seuraava."], ["santtu", "Hyvin kantaa."]],
	"done": [["santtu", "Laituri kantaa taas! Nyt voi vieraat kävellä huoletta."]],
	"gust": [["santtu", "Järveltä puhaltaa. Odota hetki."], ["santtu", "Puuska! Vasara pois naaman edestä."]],
	"idle": [["santtu", "Ei se laituri itestään korjaannu."], ["santtu", "Joko kahvitauko?"]],
}
const CURSES := ["AIIIII PERKELE!", "VOI SAA... PEUKALO!", "SAATANAN SAATANA!", "AU AU AU!", "HELVETIN HELVETTI!"]

## Paikkalautojen tila (jaettu mokki.gd:n kanssa, jää näkyviin pelin jälkeen): SLOTS kpl
## {s: "laho" / "tyhja" / "uusi" / "valmis", pry: int, nails: [syvyys, syvyys], bent: [bool, bool]}.
var state: Array = []
var patch: Node3D
var patch_z := 0.0  # paikkalautojen alku laiturin kehyksessä
var drunk := 0.0
var all_done := false
var thumbs := 0

var _hammer: Node3D
var _bar: Node3D  # sorkkarauta: kädessä, kun tähtäin on lahossa laudassa
var _nail_hand: Node3D  # vasen käsi pitelee naulaa (siinä on se peukalo)
var _nail_arm: Node3D  # vasemman käden kyynärvarsi ja hiha olkapäähän (-Z kohti olkapäätä, scale.z = pituus)
var _swing_t := -1.0
var _idle_t := 0.0
var _flash: ColorRect


func _init() -> void:
	eye = EYE
	_pitch = -0.95
	pitch_min = -1.4
	pitch_max = 0.1
	yaw_limit = 0.9
	lines = LINES
	watcher_spots = {"santtu": Vector3(0.35, 0, 2.7)}  # laiturilla korjauskohdan takana, katse pelaajaan
	watch_at = Vector3(0, 0, 0.55)
	help_text = "%s väännä, aseta lauta, lyö naulaa   %s vedä vino naula pois   %s lopeta" % [
		Settings.cap("interact", "Hiiri vasen"), Settings.cap("bell", "Hiiri oikea"), Settings.cap("mount")]


## Uusi korjauspäivä: SLOTS lahoa lautaa.
static func new_state() -> Array:
	var out := []
	for i in SLOTS:
		out.append({"s": "laho", "pry": 0, "nails": [0.0, 0.0], "bent": [false, false]})
	return out


static func is_done(st: Array) -> bool:
	return not st.is_empty() and st.all(func(sl): return sl.s == "valmis")


## Paikkalaudat (lahot, tyhjät kohdat ja uudet naulattuine lautoineen) laiturin kehykseen kohtaan z0. Tyhjä tila
## (ei laiturihommaa) = tavalliset laiturin lankut, sillä mokki.gd jättää korjauskohdan lankut tämän piirrettäviksi.
## Paikkalauta on paksumpi (5 cm), joten se nousee palkeista hieman muiden yläpuolelle.
static func build_patch(parent: Node3D, st: Array, z0: float) -> void:
	for c in parent.get_children():
		c.free()
	if st.is_empty():
		for i in SLOTS:
			var k := roundi(z0 / PITCH) + i
			Mokki.deck_plank(parent, Vector3(0, 0.26, z0 + i * PITCH), Mokki.DOCK_WOOD.lightened(0.06 * ((k * 7) % 3) - 0.03), k)
		return
	var size := Vector3(1.48, 0.05, 0.44)
	for i in st.size():
		var sl: Dictionary = st[i]
		var z := z0 + i * PITCH
		match sl.s:
			"laho":
				var p := Mokki.deck_plank(parent, Vector3(0, DECK_Y + 0.006, z), LAHO, 100 + i, size)
				p.rotation.x = -0.06 * sl.pry
				p.position.y += 0.025 * sl.pry
				B.mesh(p, B.boxm(Vector3(0.9, 0.004, 0.012)), Vector3(0.1, 0.025, 0.05), Color(0.12, 0.12, 0.1))  # halkeama
				B.mesh(p, B.boxm(Vector3(0.35, 0.004, 0.01)), Vector3(-0.45, 0.025, -0.08), Color(0.12, 0.12, 0.1))
				for k in 5:  # tummat lahokohdat
					var lp := B.mesh(p, B.cyl(0.07, 0.07, 0.002, 10), Vector3(-0.6 + k * 0.3, 0.026, -0.1 + (k % 3) * 0.1), LAHO.darkened(0.3))
					lp.scale = Vector3(1.4, 1.0, 0.6)
				for k in 4:  # sammalmättäät: epäsäännöllisiä kumpareita kahdessa vihreässä
					var mc := Vector3(-0.6 + k * 0.37, 0.026, -0.15 + (k % 2) * 0.28)
					for b in 6:
						var a := b * 1.7 + k
						var bm := B.mesh(p, B.sphere(0.022 + (b % 3) * 0.008, 6), mc + Vector3(cos(a) * 0.035 * (b % 3), 0.0, sin(a) * 0.03 * ((b + 1) % 3)),
							Color(0.26, 0.38, 0.14) if b % 2 == 0 else Color(0.36, 0.48, 0.18))
						bm.scale = Vector3(1.2, 0.45, 1.0)
			"tyhja":
				pass  # aukko: palkit ja järvi näkyvät
			_:
				Mokki.deck_plank(parent, Vector3(0, DECK_Y + 0.006, z), FRESH, 200 + i, size)
				for k in 2:
					var nail := Node3D.new()
					nail.position = Vector3((-1 if k == 0 else 1) * NAIL_X, DECK_Y + 0.031, z)
					parent.add_child(nail)
					var up: float = (1.0 - sl.nails[k]) * 0.055
					if sl.bent[k]:
						nail.rotation.z = 1.1 * (-1 if k == 0 else 1)
					B.mesh(nail, B.cyl(0.004, 0.004, up + 0.002, 6), Vector3(0, up / 2.0, 0), NAIL)
					B.mesh(nail, B.cyl(0.011, 0.011, 0.004, 10), Vector3(0, up + 0.002, 0), NAIL.lightened(0.15))


func _start() -> void:
	if state.is_empty():
		state = new_state()
	_build_hammer()
	_flash = ColorRect.new()
	_flash.color = Color(0.9, 0.05, 0.02, 0.0)
	_flash.anchor_right = 1.0
	_flash.anchor_bottom = 1.0
	_layer.add_child(_flash)
	_refresh()
	_say_kind("start")


func _build_hammer() -> void:
	# Kirvesmiehen vasara: puuvarsi kumikahvalla, teräspää lyöntipintoineen ja naulanvetokynsi.
	_hammer = Node3D.new()
	_cam.add_child(_hammer)
	B.mesh(_hammer, B.cyl(0.013, 0.017, 0.32, 10), Vector3(0, 0.16, 0), Color(0.78, 0.6, 0.36))
	B.mesh(_hammer, B.cyl(0.019, 0.019, 0.11, 10), Vector3(0, 0.07, 0), Color(0.12, 0.12, 0.13))  # kahva
	B.mesh(_hammer, B.boxm(Vector3(0.07, 0.032, 0.03)), Vector3(0.0, 0.33, 0), STEEL)
	B.mesh(_hammer, B.cyl(0.018, 0.018, 0.03, 12), Vector3(0.045, 0.33, 0), STEEL.lightened(0.35), Vector3(0, 0, 90))  # lyöntipinta
	for side in [-1.0, 1.0]:  # kynnen piikit taipuvat alas
		B.mesh(_hammer, B.boxm(Vector3(0.06, 0.012, 0.009)), Vector3(-0.055, 0.322, side * 0.008), STEEL.darkened(0.2), Vector3(0, 0, -25))
	B.mesh(_hammer, B.boxm(Vector3(0.05, 0.004, 0.031)), Vector3(0.0, 0.347, 0), STEEL.lightened(0.5))  # kiilto
	_fist(_hammer, Vector3(0, 0.07, 0))
	# Sorkkarauta: punainen kuusikulmainen varsi, kaareva kynsipää ja taltta.
	_bar = Node3D.new()
	_cam.add_child(_bar)
	B.mesh(_bar, B.cyl(0.012, 0.012, 0.5, 6), Vector3(0, 0.22, 0), Color(0.75, 0.12, 0.1))
	B.mesh(_bar, B.cyl(0.011, 0.008, 0.07, 6), Vector3(0.0, 0.49, 0.02), STEEL, Vector3(35, 0, 0))
	B.mesh(_bar, B.cyl(0.010, 0.006, 0.06, 6), Vector3(0.0, 0.52, 0.06), STEEL, Vector3(80, 0, 0))
	for side in [-1.0, 1.0]:
		B.mesh(_bar, B.boxm(Vector3(0.007, 0.004, 0.03)), Vector3(side * 0.005, 0.522, 0.092), STEEL.lightened(0.3))
	B.mesh(_bar, B.boxm(Vector3(0.022, 0.03, 0.006)), Vector3(0, -0.04, 0), STEEL.lightened(0.2))  # taltta
	_fist(_bar, Vector3(0, 0.04, 0))
	_bar.visible = false
	# Vasen käsi naulan vieressä: kämmen kannella, peukalo ja etusormi pitelevät naulaa.
	_nail_hand = Node3D.new()
	add_child(_nail_hand)
	var palm := B.mesh(_nail_hand, B.boxm(Vector3(0.085, 0.028, 0.09)), Vector3(0.0, 0.018, -0.05), SKIN)
	palm.rotation.y = 0.3
	B.mesh(_nail_hand, B.cyl(0.011, 0.011, 0.06, 8), Vector3(-0.005, 0.02, -0.005), SKIN.darkened(0.05), Vector3(90, 0, 15))  # peukalo
	B.mesh(_nail_hand, B.cyl(0.0105, 0.0105, 0.075, 8), Vector3(0.04, 0.022, 0.03), SKIN.darkened(0.05), Vector3(90, 0, -20))  # etusormi
	for k in 3:  # muut sormet koukussa
		B.mesh(_nail_hand, B.sphere(0.014, 8), Vector3(0.05 + k * 0.012, 0.02, -0.01 - k * 0.018), SKIN.darkened(0.08))
	_nail_hand.visible = false
	_nail_arm = Node3D.new()
	add_child(_nail_arm)
	B.mesh(_nail_arm, B.cyl(0.028, 0.034, 0.22, 10), Vector3(0, 0, -0.11), SKIN, Vector3(90, 0, 0))  # ranne ja kyynärvarsi
	B.mesh(_nail_arm, B.cyl(0.045, 0.052, 0.8, 10), Vector3(0, 0, -0.6), SLEEVE, Vector3(90, 0, 0))
	B.mesh(_nail_arm, B.cyl(0.047, 0.047, 0.04, 10), Vector3(0, 0, -0.21), SLEEVE.darkened(0.25), Vector3(90, 0, 0))  # resori
	_nail_arm.visible = false
	_pose_hammer(0.0)


## Nyrkki työkalun varren ympärillä ja tuulipuvun hiha kohti ruudun alareunaa (työkalun kehyksessä, varsi = +Y).
func _fist(tool: Node3D, at: Vector3) -> void:
	B.mesh(tool, B.boxm(Vector3(0.05, 0.075, 0.06)), at + Vector3(0.012, 0, 0.0), SKIN)
	for k in 4:  # rystyset
		B.mesh(tool, B.sphere(0.012, 6), at + Vector3(-0.012, 0.028 - k * 0.019, 0.026), SKIN.darkened(0.08))
	B.mesh(tool, B.cyl(0.011, 0.011, 0.045, 8), at + Vector3(-0.01, 0.03, -0.028), SKIN.darkened(0.04), Vector3(0, 0, 70))  # peukalo
	B.mesh(tool, B.cyl(0.045, 0.055, 0.4, 10), at + Vector3(0.06, -0.21, 0.0), SLEEVE, Vector3(0, 0, 18))
	B.mesh(tool, B.cyl(0.047, 0.047, 0.03, 10), at + Vector3(0.02, -0.05, 0.0), SLEEVE.darkened(0.25), Vector3(0, 0, 18))  # resori


## s = 0 lepo (kohollaan), 1 = isku alhaalla. Sorkkarauta: s vääntää vartta taaksepäin (vipu).
func _pose_hammer(s: float) -> void:
	_hammer.position = Vector3(0.24, -0.22 - 0.08 * s, -0.42)
	_hammer.rotation = Vector3(-0.3 - 1.3 * s, 0.25, 0.1)
	_bar.position = Vector3(0.2, -0.26 + 0.03 * s, -0.46)
	_bar.rotation = Vector3(-0.9 + 0.5 * s, 0.2, 0.15)


## Puunlastuja ja pölyä iskukohdasta (pelin kehyksessä).
func _chips(at: Vector3, col: Color, n: int) -> void:
	for k in n:
		var m := B.mesh(self, B.boxm(Vector3(randf_range(0.01, 0.03), 0.004, randf_range(0.006, 0.012))), at + Vector3(0, 0.02, 0),
			col.darkened(randf_range(0.0, 0.25)))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_debris(m, 0.9)
		var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 0.4)).normalized()
		var peak := at + dir * randf_range(0.06, 0.18) + Vector3(0, randf_range(0.08, 0.2), 0)
		var tw := create_tween().set_parallel()
		tw.tween_property(m, "position", peak, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.6)
		tw.chain().tween_property(m, "position", peak + dir * 0.08 - Vector3(0, peak.y - at.y - 0.01, 0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _tick(delta: float) -> void:
	_update_tools()
	if drunk > 0.0:
		_yaw += sin(_t * 1.3) * drunk * 0.003
		_pitch += sin(_t * 0.9 + 1.0) * drunk * 0.002
	if _swing_t >= 0.0:
		_swing_t += delta
		var k := _swing_t / 0.18
		_pose_hammer(sin(clampf(k, 0.0, 1.0) * PI))
		if k >= 1.0:
			_swing_t = -1.0
			_pose_hammer(0.0)
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.2)
	_idle_t += delta
	if _idle_t > 14.0 and not all_done:
		_idle_t = 0.0
		_say_kind("idle")


## Sorkkarauta lahon laudan kohdalla, muuten vasara. Vasen käsi pitelee naulaa, kunnes se pysyy itse.
func _update_tools() -> void:
	var a := _aim()
	var i: int = a[1]
	var on_laho: bool = i >= 0 and state[i].s == "laho"
	if _swing_t < 0.0:
		_bar.visible = on_laho
		_hammer.visible = not on_laho
	_nail_hand.visible = false
	_nail_arm.visible = false
	if i >= 0 and state[i].s == "uusi":
		var p: Vector3 = a[0]
		var k := 0 if p.distance_to(_nail_pos(i, 0)) < p.distance_to(_nail_pos(i, 1)) else 1
		if state[i].nails[k] >= 1.0:
			k = 1 - k
		if state[i].nails[k] < 0.5 and not state[i].bent[k]:
			_nail_hand.visible = true
			_nail_hand.position = _nail_pos(i, k) + Vector3(0, 0.0, -0.07)
			# Kyynärvarsi ranteesta kohti pelaajan vasenta olkapäätä (silmän alla ja vasemmalla).
			var wrist := _nail_hand.position + Vector3(0.0, 0.02, -0.09)
			var shoulder := eye + Vector3(-0.22, -0.5, 0.15)
			_nail_arm.visible = true
			_nail_arm.position = wrist
			_nail_arm.look_at(to_global(shoulder), Vector3.UP)
			_nail_arm.scale = Vector3(1, 1, minf(1.0, wrist.distance_to(shoulder) / 0.8))


func _gust_comment_ok() -> bool:
	return not all_done


## Tähtäimen kohta kannella (pelin kehys) ja sen kohdalla oleva lauta (-1 = ei mikään).
func _aim() -> Array:
	var p := _ray_plane(0.03)
	var i := roundi(p.z / PITCH)
	if i < 0 or i >= SLOTS or absf(p.x) > 0.78 or absf(p.z - i * PITCH) > 0.24:
		return [p, -1]
	return [p, i]


func _nail_pos(i: int, k: int) -> Vector3:
	return Vector3((-1 if k == 0 else 1) * NAIL_X, 0.03, i * PITCH)


func _action() -> void:
	if _done or _swing_t >= 0.0:
		return
	_idle_t = 0.0
	var a := _aim()
	var p: Vector3 = a[0]
	var i: int = a[1]
	if i < 0:
		_swing()
		Sfx.play("step_wood", -6.0, 1.3)
		return
	var sl: Dictionary = state[i]
	match sl.s:
		"laho":
			sl.pry += 1
			_shake = 0.35
			_swing()
			_chips(p, LAHO, 6)
			Sfx.play("rattle_hard", -4.0, 0.8 + 0.1 * sl.pry)
			if sl.pry >= PRY_CLICKS:
				sl.s = "tyhja"
				_fly_plank(i)
				_say_kind("pried")
			elif randf() < 0.5:
				_say_kind("pry")
		"tyhja":
			sl.s = "uusi"
			sl.nails = [0.0, 0.0]
			sl.bent = [false, false]
			Sfx.play("step_wood", -2.0, 0.8)
			_say_kind("placed")
		"uusi":
			_swing()
			_hammer_hit(i, p)
		_:
			_swing()
			Sfx.play("step_wood", -6.0, 1.3)
	_refresh()


func _swing() -> void:
	_swing_t = 0.0


func _hammer_hit(i: int, p: Vector3) -> void:
	var sl: Dictionary = state[i]
	var k := 0 if p.distance_to(_nail_pos(i, 0)) < p.distance_to(_nail_pos(i, 1)) else 1
	if sl.nails[k] >= 1.0:
		k = 1 - k  # valmis naula: lähempi keskeneräinen
	var np := _nail_pos(i, k)
	var d := Vector2(p.x - np.x, p.z - np.z).length()
	if sl.bent[k] and d < NAIL_GLANCE * 1.4:
		Sfx.play("rattle", -6.0, 1.4)
		_show_sub("Naula on vinossa: oikea nappi vetää sen pois.")
		return
	if d < NAIL_HIT:
		sl.nails[k] = minf(1.0, sl.nails[k] + 0.34)
		Sfx.play("punch_heavy", -6.0, 1.6)
		_shake = 0.15
		_chips(np, FRESH, 3)
		if sl.nails[k] >= 1.0:
			if sl.nails[1 - k] >= 1.0:
				sl.s = "valmis"
				fixed_plank.emit()
				if is_done(state):
					all_done = true
					Sfx.play("win_small", -4.0)
					_say_kind("done")
				else:
					_say_kind("plank_done")
			else:
				_say_kind("nail_done")
		elif randf() < 0.25:
			_say_kind("nail")
		return
	if d < NAIL_GLANCE:
		if randf() < 0.45:
			sl.bent[k] = true
			Sfx.play("rattle", -4.0, 1.6)
			_say_kind("bent")
		else:
			Sfx.play("punch", -8.0, 1.8)
			_say_kind("glance")
		return
	# Ohi: naulaa pitelevä peukalo on naulan vieressä pelaajan puolella, kunnes naula pysyy itse.
	var thumb_at := np + Vector3(0.0, 0, -0.07)
	if sl.nails[k] < 0.5 and Vector2(p.x - thumb_at.x, p.z - thumb_at.z).length() < THUMB_R:
		thumbs += 1
		thumb.emit()
		_shake = 1.2
		_flash.color.a = 0.45
		Sfx.play("punch", 0.0, 0.7)
		Sfx.play("grunt", -2.0)
		_show_sub("Sinä: \"%s\"" % CURSES.pick_random())
		get_tree().create_timer(1.6).timeout.connect(func() -> void:
			if not _done:
				_say_kind("thumb"))
	else:
		Sfx.play("step_wood", -4.0, 1.5)
		_chips(p, FRESH, 4)  # vasara jättää jäljen ja lastuja
		if randf() < 0.4:
			_say_kind("miss")


func _alt_action() -> void:
	if _done:
		return
	var a := _aim()
	var i: int = a[1]
	if i < 0 or state[i].s != "uusi":
		return
	var p: Vector3 = a[0]
	for k in 2:
		var np := _nail_pos(i, k)
		if state[i].bent[k] and Vector2(p.x - np.x, p.z - np.z).length() < NAIL_GLANCE * 1.6:
			state[i].bent[k] = false
			state[i].nails[k] = 0.0
			Sfx.play("rattle", -4.0, 1.2)
			_say_kind("pull")
			_refresh()
			return


## Lahon laudan kappale lentää sivuun.
func _fly_plank(i: int) -> void:
	var m := Mokki.deck_plank(self, Vector3(0, 0.05, i * PITCH), LAHO, 100 + i, Vector3(1.48, 0.05, 0.44))
	_add_debris(m, 1.4)
	var tw := create_tween().set_parallel()
	tw.tween_property(m, "position", Vector3(1.6, 0.9, i * PITCH + 0.3), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "rotation", Vector3(0.8, 0.4, 1.6), 0.6)
	tw.chain().tween_property(m, "position", Vector3(2.2, -0.6, i * PITCH + 0.5), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _show_sub(t: String) -> void:
	_sub.text = t
	_sub_t = 2.5


func _refresh() -> void:
	build_patch(patch, state, patch_z)
	var ready := state.filter(func(sl): return sl.s == "valmis").size()
	_count.text = "Laudat %d / %d%s" % [ready, SLOTS, "   · peukalo %d" % thumbs if thumbs > 0 else ""]
	_refresh_task()


func _process(delta: float) -> void:
	super._process(delta)
	if not _done and Engine.get_process_frames() % 6 == 0:
		_refresh_task()


func _refresh_task() -> void:
	if all_done:
		_task.text = "Laituri korjattu! %s lopettaa." % Settings.action_key("mount")
		return
	var a := _aim()
	var i: int = a[1]
	if i < 0:
		_task.text = "Tähtää laiturin lautaan"
		return
	var sl: Dictionary = state[i]
	match sl.s:
		"laho":
			_task.text = "Laho lauta: väännä irti (%d / %d)" % [sl.pry, PRY_CLICKS]
		"tyhja":
			_task.text = "Tyhjä kohta: aseta uusi lauta"
		"uusi":
			_task.text = "Naulaa lauta: naulat %d / 2 · tähtää kantaan" % [int(sl.nails[0] >= 1.0) + int(sl.nails[1] >= 1.0)]
		_:
			_task.text = "Valmis lauta"
