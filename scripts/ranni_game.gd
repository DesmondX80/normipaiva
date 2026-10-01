extends "res://scripts/kota_minigame.gd"
## Rännien putsaus (Santun homma), FPS-minipeli tikkailla mökin takaräystäällä. Lehtitukot kouraistaan
## rännistä (klikkaus) ja sammalet harjataan katolta (kaksi vetoa). Tikkaat heiluvat: kurottelu sivulle,
## tuulenpuuskat ja humala kallistavat, ja tasapaino pidetään A/D:llä. Liian kallellaan tikkaat kaatuvat.
## Oikea nappi siirtää tikkaat seuraavaan kohtaan. Santtu katsoo alhaalta ja kommentoi.
## mokki.gd:n lapsi: origo = tikkaiden juuren kohta maassa (x = 0 mökin kehyksessä), +Z mökkiä kohti.

signal fell

const Mokki := preload("res://scripts/mokki.gd")

const SECTIONS := [-3.2, 0.2, 3.4]  # tikkaiden paikat (mökin x)
const GUTTER_Z := 0.75  # ränni pelin kehyksessä
const ROOF_Z := 0.85  # räystään reuna
const ROOF_RISE := 0.4  # katon nousu metriä kohden
const REACH := 1.35
const HIT_R := 0.13

const LINES := {
	"start": [["santtu", "Mää pidän tikkaista kiinni. Tai en pidä, mutta katon."], ["santtu", "Älä kurottele liikaa!"],
		["santtu", "Lehdet maahan, ei mun päähän."]],
	"leaf": [["santtu", "Siinä on koko syksy yhessä tukossa."], ["santtu", "Hyvä! Seuraava."], ["santtu", "Varo, mää oon tässä alla!"]],
	"moss": [["santtu", "Sammal irti harjalla, ei sormilla."], ["santtu", "Vielä toinen veto."]],
	"moss_done": [["santtu", "Katto kiiltää ku uus."], ["santtu", "Sammal pois, ei vuoda katto."]],
	"wobble": [["santtu", "Tikkaat heiluu! Pidä tasapaino!"], ["santtu", "VAROVASTI siellä!"], ["santtu", "Ei kurotella! Siirrä tikkaita!"]],
	"reach": [["santtu", "Ei ylety. Siirrä tikkaat."], ["santtu", "Liian kaukana, ei kurotella."]],
	"move": [["santtu", "Tikkaat siirtoon. Jalat maahan ensin."], ["santtu", "Seuraava pätkä."]],
	"section_done": [["santtu", "Tää pätkä on puhdas. Siirrä tikkaat."], ["santtu", "Hyvä! Seuraava kohta."]],
	"done": [["santtu", "Rännit vetää taas! Hyvä ettet tippunu."]],
	"fall": [["santtu", "Ei se mitään, nurmikko on pehmeä."], ["santtu", "Tikkailta ei pudota, ku ollaan selvinpäin!"]],
	"gust": [["santtu", "Puuska! Pidä kiinni!"], ["santtu", "Tuulee, oota hetki."]],
	"idle": [["santtu", "Ei ne lehdet itestään lähe."], ["santtu", "Pelottaako? Ei se oo ku kolme metriä."]],
}

## Kohteet osioittain: [[{kind: "lehti" / "sammal", pos: Vector3, hp: int}, ...], ...] (jaettu main.gd:n kanssa).
var state: Array = []
## Mökin lattiatason maan ero tikkaiden juureen (rännin korkeus pelin kehyksessä = base_off + GUTTER_UP).
var base_off := 0.0
var gutter_up := 2.78
var drunk := 0.0
var all_done := false
var fell_off := false

var _sec := 0
var _bal := 0.0
var _bal_v := 0.0
var _bal_label: Label
var _targets: Array[Node3D] = []
var _move_t := -1.0
var _move_from := 0.0
var _fall_t := -1.0
var _ladder: Node3D
var _brush: Node3D
var _brush_t := -1.0
var _idle_t := 0.0
var _wobble_said := 0.0


func _init() -> void:
	_pitch = -0.25
	pitch_min = -1.0
	pitch_max = 0.5
	yaw_limit = 1.0
	lines = LINES
	# Pohja asettaa katsojan ennen _startia: Santtu siirretään _startissa oikean osion kohdalle.
	watcher_spots = {"santtu": Vector3(SECTIONS[0] + 1.5, 0, -1.4)}
	watch_at = Vector3(SECTIONS[0], 2.8, GUTTER_Z)
	help_text = "Hiiri tähtää · Vasen nappi / E: kouraise lehdet, harjaa sammal · A/D: pidä tasapaino · Oikea nappi / Q: siirrä tikkaat · F: alas"


static func new_state(base_off: float, gutter_up: float) -> Array:
	var gy := base_off + gutter_up
	var out := []
	for sx in SECTIONS:
		var sec := []
		for dx in [-0.85, 0.05, 0.9]:
			sec.append({"kind": "lehti", "pos": Vector3(sx + dx + randf_range(-0.12, 0.12), gy + 0.03, GUTTER_Z), "hp": 1})
		for dx in [-0.5, 0.55]:
			var dz := randf_range(0.3, 0.75)
			sec.append({"kind": "sammal", "pos": Vector3(sx + dx, gy + 0.08 + dz * ROOF_RISE, ROOF_Z + dz), "hp": 2})
		out.append(sec)
	return out


static func is_done(st: Array) -> bool:
	return not st.is_empty() and st.all(func(sec): return sec.all(func(t): return t.hp <= 0))


func _eye_for(sx: float) -> Vector3:
	return Vector3(sx, base_off + gutter_up + 0.22, 0.22)


func _start() -> void:
	if state.is_empty():
		state = new_state(base_off, gutter_up)
	_sec = 0
	for i in state.size():
		if state[i].any(func(t): return t.hp > 0):
			_sec = i
			break
	eye = _eye_for(SECTIONS[_sec])
	yaw_center = 0.0
	_yaw = 0.0
	var santtu: Node3D = _watcher("santtu")
	santtu.position = transform * Vector3(SECTIONS[_sec] + 1.5, 0, -1.4)
	santtu.rotation.y = B.yaw_to(transform * Vector3(SECTIONS[_sec], base_off + gutter_up, GUTTER_Z) - santtu.position)
	_ladder = Node3D.new()
	add_child(_ladder)
	Mokki.make_ladder(_ladder, 2.5)  # lyhyempi kuin pihan tikkaat: ylin askelma jää silmien alle
	_ladder.position = Vector3(SECTIONS[_sec], 0, -0.05)
	var world_ladder: Node3D = kota.find_child("Ladder", true, false)
	if world_ladder != null:
		world_ladder.visible = false
	_build_brush()
	_bal_label = _label(24, 0.0, 132, 166)
	_rebuild_targets()
	_say_kind("start")
	_update_task()


func _cleanup() -> void:
	var world_ladder: Node3D = kota.find_child("Ladder", true, false)
	if world_ladder != null:
		world_ladder.visible = true


func _build_brush() -> void:
	_brush = Node3D.new()
	_cam.add_child(_brush)
	B.mesh(_brush, B.cyl(0.015, 0.015, 0.45, 6), Vector3(0, 0.0, -0.2), Color(0.65, 0.5, 0.3), Vector3(90, 0, 0))
	B.mesh(_brush, B.boxm(Vector3(0.14, 0.05, 0.06)), Vector3(0, -0.02, -0.44), Color(0.45, 0.3, 0.15))
	B.mesh(_brush, B.boxm(Vector3(0.13, 0.04, 0.05)), Vector3(0, -0.06, -0.44), Color(0.85, 0.75, 0.45))
	_pose_brush(0.0)


func _pose_brush(s: float) -> void:
	_brush.position = Vector3(0.22, -0.2 + 0.05 * s, -0.25 - 0.15 * s)
	_brush.rotation = Vector3(-0.4 - 0.5 * s, 0.2, 0.0)


func _rebuild_targets() -> void:
	for n in _targets:
		n.queue_free()
	_targets.clear()
	for sec in state:
		for t in sec:
			var n := Node3D.new()
			n.position = t.pos
			add_child(n)
			_targets.append(n)
			if t.hp <= 0:
				n.visible = false
				continue
			if t.kind == "lehti":
				for k in 5:
					var m := B.mesh(n, B.sphere(0.05, 6), Vector3(randf_range(-0.07, 0.07), randf_range(0.0, 0.03), randf_range(-0.03, 0.03)),
						[Color(0.55, 0.32, 0.1), Color(0.7, 0.5, 0.15), Color(0.4, 0.28, 0.12)][k % 3])
					m.scale = Vector3(1.3, 0.5, 1.0)
			else:
				var r := 0.09 if t.hp >= 2 else 0.06
				for k in 3:
					var m := B.mesh(n, B.sphere(r, 8), Vector3(-0.06 + k * 0.06, 0.0, (k % 2) * 0.04), Color(0.25, 0.38, 0.12).lightened(0.05 * k))
					m.scale = Vector3(1.3, 0.3, 1.1)
				n.rotation.x = -atan(ROOF_RISE)


## Kohde tähtäimen alla: [osio, indeksi] tai [] (lähin säteen läheltä kulkeva).
func _pick() -> Array:
	var o := _cam.transform.origin
	var d := -_cam.transform.basis.z
	var best: Array = []
	var best_t := INF
	for si in state.size():
		for ti in state[si].size():
			var t: Dictionary = state[si][ti]
			if t.hp <= 0:
				continue
			var v: Vector3 = t.pos - o
			var along := v.dot(d)
			if along <= 0.0:
				continue
			if (v - d * along).length() < HIT_R and along < best_t:
				best_t = along
				best = [si, ti]
	return best


func _action() -> void:
	if _done or _move_t >= 0.0 or _fall_t >= 0.0:
		return
	_idle_t = 0.0
	_brush_t = 0.0
	_bal_v += randf_range(-0.18, 0.18)
	var pk := _pick()
	if pk.is_empty():
		Sfx.play("whoosh", -12.0, 1.4)
		return
	var t: Dictionary = state[pk[0]][pk[1]]
	if (t.pos as Vector3).distance_to(eye) > REACH:
		_say_kind("reach")
		_bal_v += 0.35 * signf(t.pos.x - eye.x)  # kurotus kallistaa
		return
	t.hp -= 1
	var node := _targets[_index(pk)]
	if t.kind == "lehti":
		Sfx.play("cloth", -4.0, 0.9)
		_drop(node)
		if randf() < 0.4:
			_say_kind("leaf")
	elif t.hp > 0:
		Sfx.play("whoosh", -6.0, 0.7)
		node.scale = Vector3(0.65, 1.0, 0.65)
		_say_kind("moss")
	else:
		Sfx.play("whoosh", -6.0, 0.6)
		_drop(node)
		_say_kind("moss_done")
	if is_done(state):
		all_done = true
		Sfx.play("win_small", -4.0)
		_say_kind("done")
	elif state[_sec].all(func(x): return x.hp <= 0):
		_say_kind("section_done")
	_update_task()


func _index(pk: Array) -> int:
	var n := 0
	for si in pk[0]:
		n += state[si].size()
	return n + pk[1]


## Kohde putoaa maahan.
func _drop(node: Node3D) -> void:
	var tw := create_tween()
	tw.tween_property(node, "position", node.position + Vector3(randf_range(-0.3, 0.3), -node.position.y, -0.9), 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: node.visible = false)


## Tikkaat seuraavaan kohtaan (seuraava osio, jossa on vielä putsattavaa).
func _alt_action() -> void:
	if _done or _move_t >= 0.0 or _fall_t >= 0.0 or all_done:
		return
	var next := _sec
	for k in range(1, state.size() + 1):
		var i := (_sec + k) % state.size()
		if state[i].any(func(t): return t.hp > 0):
			next = i
			break
	if next == _sec and state[_sec].any(func(t): return t.hp > 0):
		next = (_sec + 1) % state.size()
	_move_from = SECTIONS[_sec]
	_sec = next
	_move_t = 0.0
	_bal = 0.0
	_bal_v = 0.0
	Sfx.play("rattle", -6.0, 0.9)
	_say_kind("move")


func _can_quit() -> bool:
	return _fall_t < 0.0


func _gust_comment_ok() -> bool:
	return not all_done


func _tick(delta: float) -> void:
	_wobble_said -= delta
	if _brush_t >= 0.0:
		_brush_t += delta
		_pose_brush(sin(clampf(_brush_t / 0.25, 0.0, 1.0) * PI))
		if _brush_t > 0.25:
			_brush_t = -1.0
	if _fall_t >= 0.0:
		_fall_t += delta
		var k := clampf(_fall_t / 0.9, 0.0, 1.0)
		eye = eye.lerp(Vector3(eye.x + 0.8, 0.5, -1.2), k * 0.2)
		_pitch = lerpf(_pitch, 0.9, k * 0.1)
		_shake = 0.6
		if _fall_t > 1.4:
			_quit()
		return
	if _move_t >= 0.0:
		_move_t += delta
		var k := clampf(_move_t / 1.2, 0.0, 1.0)
		var x := lerpf(_move_from, SECTIONS[_sec], k)
		eye = _eye_for(x) - Vector3(0, sin(k * PI) * 1.6, 0)
		_ladder.position.x = x
		var santtu: Node3D = _watcher("santtu")
		santtu.position = transform * Vector3(x + 1.5, 0, -1.4)
		if k >= 1.0:
			_move_t = -1.0
			_update_task()
		return
	# Tasapaino: tikkaat ovat epävakaat (pieni kallistus kasvaa itsestään), kurotus, puuskat ja humala
	# kallistavat, ja A/D vastaa.
	var lean := (_yaw - yaw_center) / yaw_limit
	var noise := sin(_t * 1.7) * 0.18 + sin(_t * 3.9 + 1.0) * 0.1
	var g := _gust_offset()
	var push := noise * (1.0 + drunk * 2.5) - g.x * 9.0 - lean * 0.35 + _bal * 0.9
	var input := Input.get_axis("left", "right")
	_bal_v += (push + input * 2.2) * delta
	_bal_v *= 1.0 - minf(1.0, 1.6 * delta)
	_bal += _bal_v * delta
	if absf(_bal) > 0.6 and _wobble_said <= 0.0:
		_wobble_said = 7.0
		_say_kind("wobble")
	if absf(_bal) >= 1.0:
		_fall()
		return
	_yaw += _bal_v * delta * 0.15
	_shake = maxf(_shake, absf(_bal) * 0.08)
	_draw_balance()
	_idle_t += delta
	if _idle_t > 15.0 and not all_done:
		_idle_t = 0.0
		_say_kind("idle")


func _fall() -> void:
	fell_off = true
	_fall_t = 0.0
	Sfx.play("rattle_hard", -2.0, 0.8)
	get_tree().create_timer(0.8).timeout.connect(func() -> void: Sfx.play("body_fall", -2.0))
	_task.text = "TIKKAAT KAATUU!"
	_say_kind("fall")
	fell.emit()


func _draw_balance() -> void:
	var n := 9
	var i := clampi(roundi((_bal + 1.0) / 2.0 * (n - 1)), 0, n - 1)
	var bar := ""
	for k in n:
		bar += "●" if k == i else "━"
	_bal_label.text = "Tasapaino  ◀ %s ▶" % bar
	_bal_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if absf(_bal) > 0.6 else Color(0.9, 0.95, 1.0))


func _update_task() -> void:
	var left := 0
	var total := 0
	for sec in state:
		for t in sec:
			total += 1
			if t.hp <= 0:
				pass
			else:
				left += 1
	_count.text = "Putsattu %d / %d · kohta %d / %d" % [total - left, total, _sec + 1, state.size()]
	if all_done:
		_task.text = "Rännit ja katto puhtaat! F laskeutuu alas."
	elif state[_sec].all(func(t): return t.hp <= 0):
		_task.text = "Tämä kohta on puhdas: siirrä tikkaat (oikea nappi)"
	else:
		_task.text = "Kouraise lehtitukot rännistä ja harjaa sammalet katolta"
