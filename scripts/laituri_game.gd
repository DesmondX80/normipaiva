extends "res://scripts/kota_minigame.gd"
## Laiturin korjaus (Santun homma), FPS-minipeli polvillaan laiturin kannella. Lahot laudat irti sorkkaraudalla
## (klikkaa lautaa, kunnes se irtoaa), uusi lauta paikalleen (klikkaa tyhjää kohtaa) ja kaksi naulaa kumpaankin
## päähän: tähtää naulan kantaan ja lyö. Vino isku taivuttaa naulan (oikea nappi vetää sen pois), ja ohi lyönti
## osuu helposti peukaloon, joka pitelee naulaa. Santtu katsoo vieressä ja kommentoi.
## mokki.gd:n laiturin (dock_body) lapsi: origo = paikkalautojen alku kannen pinnalla, +Z järvelle päin.

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

const LAHO := Color(0.3, 0.3, 0.24)
const FRESH := Color(0.86, 0.72, 0.5)
const NAIL := Color(0.62, 0.62, 0.64)

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


## Paikkalaudat (lahot, tyhjät kohdat ja uudet naulattuine lautoineen) laiturin kehykseen kohtaan z0.
static func build_patch(parent: Node3D, st: Array, z0: float) -> void:
	for c in parent.get_children():
		c.free()
	for i in st.size():
		var sl: Dictionary = st[i]
		var z := z0 + i * PITCH
		match sl.s:
			"laho":
				var p := Node3D.new()
				p.position = Vector3(0, DECK_Y + 0.016, z)
				p.rotation.x = -0.06 * sl.pry
				p.position.y += 0.025 * sl.pry
				parent.add_child(p)
				B.mesh(p, B.boxm(Vector3(1.48, 0.03, 0.44)), Vector3.ZERO, LAHO)
				B.mesh(p, B.boxm(Vector3(0.9, 0.005, 0.015)), Vector3(0.1, 0.017, 0.05), Color(0.12, 0.12, 0.1))  # halkeama
				for k in 4:
					var m := B.mesh(p, B.sphere(0.05, 6), Vector3(-0.6 + k * 0.37, 0.012, -0.12 + (k % 2) * 0.22), Color(0.22, 0.3, 0.12))
					m.scale = Vector3(1.4, 0.25, 1.0)
			"tyhja":
				B.mesh(parent, B.boxm(Vector3(1.48, 0.01, 0.44)), Vector3(0, DECK_Y - 0.12, z), Color(0.05, 0.08, 0.09))
			_:
				B.mesh(parent, B.boxm(Vector3(1.48, 0.03, 0.44)), Vector3(0, DECK_Y + 0.016, z), FRESH)
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
	_hammer = Node3D.new()
	_cam.add_child(_hammer)
	B.mesh(_hammer, B.cyl(0.014, 0.017, 0.32, 8), Vector3(0, 0.16, 0), Color(0.72, 0.55, 0.32))
	B.mesh(_hammer, B.boxm(Vector3(0.11, 0.035, 0.035)), Vector3(0.0, 0.33, 0), Color(0.25, 0.25, 0.27))
	B.mesh(_hammer, B.boxm(Vector3(0.04, 0.03, 0.03)), Vector3(-0.06, 0.34, 0), Color(0.2, 0.2, 0.22))
	_pose_hammer(0.0)


## s = 0 lepo (kohollaan), 1 = isku alhaalla.
func _pose_hammer(s: float) -> void:
	_hammer.position = Vector3(0.24, -0.22 - 0.08 * s, -0.42)
	_hammer.rotation = Vector3(-0.3 - 1.3 * s, 0.25, 0.1)


func _tick(delta: float) -> void:
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
	var m := B.mesh(self, B.boxm(Vector3(1.48, 0.03, 0.44)), Vector3(0, 0.05, i * PITCH), LAHO)
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
