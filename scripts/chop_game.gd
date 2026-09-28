extends "res://scripts/kota_minigame.gd"
## Halonhakkuu kodan pilkkomispölkyllä, FPS-minipeli. Nosta pölkky läjästä, käännä se oikein päin
## (tasainen pää alas, vino pää ylös) ja aseta keskelle halkaisupölliä: väärin päin tai reunalle asetettu
## pölkky pyörähtää pois. Sitten tähtää kirveellä hiirellä ja iske (hiiren vasen tai E). Kädet huojuvat
## ja tuulenpuuskat heittävät tähtäystä. Kodan vakiovieraat Raimo ja Veikko tulevat ulos kommentoimaan.
## kota.gd:n lapsi: paikallinen origo = pilkkomispölkyn keskipiste maan tasalla, pelaaja seisoo -Z-puolella.

signal split(halot: int)

const BLOCK_TOP := 0.52
const BLOCK_R := 0.29
const LOG_R := 0.14
const LOG_L := 0.36  # pölkyn pituus akselilla (vinon pään keskikohtaan)
const SLANT := 0.45  # vinon pään kaltevuus (rad)
const TANS := 0.483  # tan(SLANT)
const PILE := Vector3(-0.95, 0.0, 0.45)
const EYE := Vector3(0.0, 1.62, -0.95)
const CLEAN_R := 0.055  # tästä keskemmältä halki
const PERFECT_R := 0.022
const STUCK_R := 0.105  # tästä keskemmältä kirves jää kiinni, ulompaa pölkky lentää
const HALOT := 4

const BARK := Color(0.88, 0.86, 0.8)
const BARK_DARK := Color(0.22, 0.2, 0.18)
const WOOD_A := Color(0.86, 0.74, 0.54)
const WOOD_B := Color(0.77, 0.63, 0.43)
const HEART := Color(0.66, 0.5, 0.32)
const FRESH := Color(0.9, 0.8, 0.6)

## Kommentit: tilanne -> [[puhuja ("raimo"/"veikko"/"" = kumpi tahansa), repliikki]].
const LINES := {
	"start": [["raimo", "No niin, katotaan mitä kaupunkilainen osaa."],
		["veikko", "Tultiin ulos kattomaan. Tää on parempaa ku telkkari."],
		["raimo", "Tasainen pää alas, vino ylös. Muuten ei pysy."]],
	"placed": [["raimo", "No niin, vino pää ylös. Oppii se."], ["veikko", "Hyvin istuu."],
		["veikko", "Siinä se seisoo ku Pekka baaritiskillä."], ["raimo", "Suoraan keskelle. Mestarin merkki."],
		["", "Nyt se on pystyssä. Ei muuta ku kirves heilumaan."]],
	"wrong_end": [["raimo", "Väärin päin! Vino pää ylös, tasainen alas."], ["veikko", "Nyt se lähti rullaamaan."],
		["veikko", "Pölkky pyörii ku Veikko lauantaina. Siis minä."],
		["raimo", "Tästäkin pitäis tehdä kyltti: 'Väärinpäin asettaminen kielletty'."],
		["raimo", "Tasainen pää alas, sanoo jo järkikin."], ["veikko", "Käänny ite ympäri, ni näet kumpi pää on vino."]],
	"edge": [["raimo", "Keskelle, keskelle! Ei reunalle."], ["veikko", "Pölkky on isompi ku luulet."],
		["raimo", "Reunalla ei pysy mikään. Kysy vaikka Pekalta."]],
	"no_pile": [["", "Pölkyt on tuossa läjässä. Oikealla."], ["veikko", "Läjästä otetaan, ei ilmasta."]],
	"clean": [["raimo", "Kunnon isku! Halki ku Raahen karateklubi."], ["veikko", "Nyt tuli halkoja."],
		["raimo", "Siinä on miestä."], ["veikko", "Kuivaa koivua. Halkeaa ku ajatus."],
		["", "No nyt! Tuosta tulee hyvä tuli."]],
	"perfect": [["raimo", "Ristiin halki yhellä iskulla! Tuota ei oo nähty sitte -78."],
		["veikko", "Paras isku koko Saloisissa. Kerron tästä tarinan."],
		["raimo", "Täydellinen. Ihan ku minä nuorena."]],
	"stuck": [["raimo", "Jäi kiinni. Nykäise irti ja uusiks."], ["veikko", "Kirves jäi puuhun ku Pekka kyyhkyjahtiin."],
		["raimo", "Keskemmälle, keskemmälle."], ["veikko", "Sitkeä on. Ihan ku Raimo."]],
	"stuck_split": [["raimo", "Sitkeä oli, mutta periksi antoi."], ["veikko", "Kahella iskulla. Kelpaa."]],
	"knock": [["veikko", "Syrjään meni ja pölkky lensi. Nosta takasin."], ["raimo", "Kävi ku pöytätenniksessä."],
		["raimo", "Reunaan ku lyöt, ni pölkky lähtee lentoon. Fysiikkaa."]],
	"block": [["raimo", "Nyt pilkoit pilkkomispölkkyä. Sitä ei polteta."],
		["veikko", "Pölkky kiittää. Se on ollu siinä vuodesta -62."], ["raimo", "Ohi. Pölkky sai taas yhen arven."]],
	"ground": [["veikko", "Varo varpaita!"], ["raimo", "Ilmaa halkasit. Hyvä halko se ilmakin."],
		["raimo", "Kirves maahan ja melkein jalkaan. Kodassa kirveen käyttö on kielletty, täällä vasta ollaan."]],
	"gust": [["veikko", "Puuska! Pidä kirves."], ["raimo", "Tuulee. Oota että tyyntyy."],
		["veikko", "Tekojärveltä puhaltaa taas."]],
	"idle": [["raimo", "Ei se pölkky itestään halkea."], ["veikko", "Tähtäätkö vai nukutko?"]],
	"done": [["raimo", "Hyvät halot. Nyt kotaan ja tuli pesään!"], ["veikko", "Kanna ne tulisijalle, ni kerrotaan tarina."]],
}

var polkyt := 0
var halot_made := 0

var _phase := "pick"  # pick | hold | chop | swing | wait
var _wait_t := 0.0
var _after_wait := ""
var _flat_down := true
var _flip_a := 0.0  # 0 = tasainen pää alas, PI = vino pää alas
var _flip_to := 0.0
var _held: Node3D
var _held_mesh: MeshInstance3D
var _held_yaw := 0.0
var _standing: Node3D  # pölkyllä pystyssä oleva pölkky
var _log_pos := Vector3.ZERO
var _cracks := 0
var _swing_t := -1.0
var _swing_hit := false
var _swing_hold := 0.55  # kuinka kauan kirves on alhaalla iskun jälkeen (kiinni jäädessä pidempään)
var _axe_vm: Node3D
var _pile: Node3D
var _idle_t := 0.0


func _init() -> void:
	eye = EYE
	_pitch = -0.86
	lines = LINES
	watcher_spots = {"raimo": Vector3(1.75, 0, 2.2), "veikko": Vector3(0.95, 0, 3.05)}
	watch_at = Vector3(0, 0, 0.1)
	help_text = "Hiiri tähtää · Vasen nappi / E: nosta, aseta, iske · Oikea nappi / Q / rulla: käännä pölkky · F: lopeta"


func _start() -> void:
	_build_axe()
	_pile = Node3D.new()
	_pile.position = PILE
	add_child(_pile)
	_refresh_pile()
	var axe: Node3D = kota.find_child("Axe", true, false)
	if axe != null:
		axe.visible = false
	_say_kind("start")
	_update_task()


# --- Rakennus --------------------------------------------------------------------

static func _top_y(x: float) -> float:
	return LOG_L + TANS * x


static func _wood_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, n := Vector3.ZERO) -> void:
	if n == Vector3.ZERO:
		n = (b - a).cross(c - a).normalized()
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


## Pölkky tai sen pala (kulmaväli a0..a1): tasainen pää y=0:ssa, vino pää ylhäällä (kallistus +X:n suuntaan).
## Päädyissä vuosirenkaat, kyljessä koivun kuori. Palauttaa [mesh, törmäyspisteet].
static func log_piece(a0: float, a1: float, seg: int) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	var full := a1 - a0 > TAU - 0.01
	var rings := [0.0, 0.22, 0.42, 0.6, 0.76, 0.9, 1.0]
	var ring_cols := [HEART, WOOD_B, WOOD_A, WOOD_B, WOOD_A, BARK_DARK]
	var top_n := Vector3(-TANS, 1.0, 0.0).normalized()
	for i in seg:
		var ta := lerpf(a0, a1, float(i) / seg)
		var tb := lerpf(a0, a1, float(i + 1) / seg)
		var da := Vector3(cos(ta), 0, sin(ta))
		var db := Vector3(cos(tb), 0, sin(tb))
		# Kylki: koivun valkoinen kuori tummin laikuin.
		var bark := BARK_DARK.lerp(BARK, 0.35) if (i * 7 + int(a0 * 3.0)) % 5 == 0 else BARK
		var pa := da * LOG_R
		var pb := db * LOG_R
		var pa_t := Vector3(pa.x, _top_y(pa.x), pa.z)
		var pb_t := Vector3(pb.x, _top_y(pb.x), pb.z)
		var sn := ((da + db) * 0.5).normalized()
		_tri(st, pa, pb, pb_t, bark, sn)
		_tri(st, pa, pb_t, pa_t, bark, sn)
		# Päädyt renkaina.
		for r in ring_cols.size():
			var r0: float = rings[r] * LOG_R
			var r1: float = rings[r + 1] * LOG_R
			var col: Color = ring_cols[r]
			for top in [false, true]:
				var q := [da * r0, db * r0, db * r1, da * r1]
				for k in 4:
					var v: Vector3 = q[k]
					q[k] = Vector3(v.x, _top_y(v.x) if top else 0.0, v.z)
				var n := top_n if top else Vector3.DOWN
				_tri(st, q[0], q[1], q[2], col, n)
				_tri(st, q[0], q[2], q[3], col, n)
		pts.append(pa)
		pts.append(pa_t)
	var pe := Vector3(cos(a1), 0, sin(a1)) * LOG_R
	pts.append(pe)
	pts.append(Vector3(pe.x, _top_y(pe.x), pe.z))
	if not full:
		# Halkaisupinnat: tuore vaalea puu.
		for a in [a0, a1]:
			var p := Vector3(cos(a), 0, sin(a)) * LOG_R
			var p_t := Vector3(p.x, _top_y(p.x), p.z)
			var c_t := Vector3(0, LOG_L, 0)
			_tri(st, Vector3.ZERO, p, p_t, FRESH)
			_tri(st, Vector3.ZERO, p_t, c_t, FRESH)
		pts.append(Vector3.ZERO)
		pts.append(Vector3(0, LOG_L, 0))
	var mesh := st.commit()
	mesh.surface_set_material(0, _wood_mat())
	return [mesh, pts]


func _log_mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = log_piece(0.0, TAU, 16)[0]
	return mi


## Pölkyn asento kääntökulmalla a: kierto Z-akselin ympäri pölkyn keskipisteen kautta.
## a = PI: vino pää alhaalla y=0:ssa, tasainen pää ylhäällä.
static func _flip_xf(a: float) -> Transform3D:
	var c := Vector3(0, (LOG_L + TANS * LOG_R) * 0.5, 0)
	var bs := Basis(Vector3.BACK, a)
	return Transform3D(bs, c - bs * c)


func _refresh_pile() -> void:
	for ch in _pile.get_children():
		ch.queue_free()
	var in_use := 1 if _held != null or _standing != null else 0
	var n := mini(polkyt - in_use, 7)
	var spots := [Vector3(0, 0, 0), Vector3(0.3, 0, 0.05), Vector3(-0.3, 0, -0.02), Vector3(0.12, 0.27, 0.02),
		Vector3(-0.17, 0.27, 0.0), Vector3(0.45, 0, 0.35), Vector3(-0.02, 0.0, 0.38)]
	for i in n:
		var holder := Node3D.new()
		holder.position = spots[i] + Vector3(0, LOG_R, 0)
		holder.rotation = Vector3(0, 0.3 * i, PI / 2.0 + (0.15 if i % 2 else -0.1))
		_pile.add_child(holder)
		var mi := _log_mesh()
		mi.position = Vector3(0, -LOG_L * 0.5, 0)
		holder.add_child(mi)


func _build_axe() -> void:
	_axe_vm = Node3D.new()
	_cam.add_child(_axe_vm)
	var handle := Color(0.72, 0.55, 0.32)
	B.mesh(_axe_vm, B.cyl(0.017, 0.022, 0.66, 10), Vector3(0, 0.33, 0), handle)
	B.mesh(_axe_vm, B.cyl(0.024, 0.024, 0.05, 10), Vector3(0, 0.02, 0), handle.darkened(0.2))
	var head := Color(0.25, 0.26, 0.28)
	B.mesh(_axe_vm, B.boxm(Vector3(0.035, 0.11, 0.07)), Vector3(0, 0.63, 0.0), head)
	B.mesh(_axe_vm, B.boxm(Vector3(0.022, 0.12, 0.09)), Vector3(0, 0.63, -0.075), head)
	B.mesh(_axe_vm, B.boxm(Vector3(0.012, 0.15, 0.02)), Vector3(0, 0.63, -0.125), Color(0.78, 0.8, 0.83))
	# Käsi kahvassa (hihansuu ja rukkanen).
	B.mesh(_axe_vm, B.sphere(0.045, 10), Vector3(0, 0.06, 0), Color(0.35, 0.22, 0.12))
	B.mesh(_axe_vm, B.cyl(0.055, 0.06, 0.25, 10), Vector3(0.02, -0.08, 0.06), Color(0.2, 0.3, 0.22), Vector3(-30, 0, 0))
	for mi in _axe_vm.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_axe_vm.visible = false


# --- Syöte ja kulku ----------------------------------------------------------------

func _tick(delta: float) -> void:
	_flip_a = move_toward(_flip_a, _flip_to, delta * 11.0)
	if _held != null:
		_update_held()
	if _swing_t >= 0.0:
		_update_swing(delta)
	if _phase == "wait":
		_wait_t -= delta
		if _wait_t <= 0.0:
			_phase = _after_wait
			if _phase == "end":
				_quit()
				return
			_update_task()
	if _phase == "chop":
		_idle_t += delta
		if _idle_t > 14.0:
			_idle_t = 0.0
			_say_kind("idle")
	_axe_vm.visible = _phase in ["chop", "swing"] or (_phase == "wait" and _standing != null)
	if _swing_t < 0.0:
		_pose_axe(0.0)
	_count.text = "Pölkkyjä %d · Halottu %d halkoa" % [polkyt, halot_made]


func _can_quit() -> bool:
	return true


func _gust_comment_ok() -> bool:
	return _phase in ["hold", "chop"]


func _update_task() -> void:
	match _phase:
		"pick":
			_task.text = "Nosta pölkky läjästä (oikealla)" if polkyt > 0 else ""
		"hold":
			_task.text = "Käännä tasainen pää alas ja aseta pölkky keskelle halkaisupölliä"
		"chop":
			_task.text = "Tähtää pölkyn keskelle ja iske!"
		_:
			_task.text = ""


func _action() -> void:
	match _phase:
		"pick":
			var hit := _ray_plane(0.18)
			if hit.distance_to(PILE + Vector3(0, 0.18, 0)) < 0.75:
				_pick_up()
			else:
				_say_kind("no_pile")
		"hold":
			_place()
		"chop":
			_swing_t = 0.0
			_swing_hit = false
			_swing_hold = 0.55
			_phase = "swing"
			_idle_t = 0.0
			Sfx.play("whoosh", -4.0, randf_range(0.7, 0.85))


func _alt_action() -> void:
	if _phase != "hold":
		return
	_flat_down = not _flat_down
	_flip_to = 0.0 if _flat_down else PI
	Sfx.play("cloth", -8.0, 1.3)


## Kesken jäänyt pölkky palaa läjään: polkyt vähenee vasta halkaistaessa.
func _cleanup() -> void:
	var axe: Node3D = kota.find_child("Axe", true, false)
	if axe != null:
		axe.visible = true


# --- Pölkyn asettaminen ---------------------------------------------------------------

func _pick_up() -> void:
	_held = Node3D.new()
	add_child(_held)
	_held_mesh = _log_mesh()
	_held.add_child(_held_mesh)
	_held_yaw = randf() * TAU
	_flat_down = randf() < 0.5
	_flip_to = 0.0 if _flat_down else PI
	_flip_a = _flip_to
	_phase = "hold"
	_refresh_pile()
	Sfx.play("pickup", -6.0, 0.8)
	_update_task()


## Kädessä oleva pölkky leijuu tähtäimen kohdalla pölkyn yläpuolella, hieman kallellaan kohti katsojaa,
## jotta yläpää näkyy. Kädet ja tuuli huojuttavat sitä kameran mukana.
func _update_held() -> void:
	var p := _ray_plane(BLOCK_TOP)
	var off := Vector2(p.x, p.z)
	if off.length() > 0.8:
		off = off.normalized() * 0.8
	_held.position = Vector3(off.x, BLOCK_TOP + 0.16, off.y)
	_held.basis = Basis(Vector3.RIGHT, -0.35) * Basis(Vector3.UP, _held_yaw)
	_held_mesh.transform = _flip_xf(_flip_a)


func _place() -> void:
	var p := Vector3(_held.position.x, BLOCK_TOP, _held.position.z)
	var yaw := _held_yaw
	var d := Vector2(p.x, p.z).length()
	var flat := _flat_down
	_held.queue_free()
	_held = null
	Sfx.play("step_wood", -2.0, 0.7)
	if not flat or d > BLOCK_R - 0.07:
		# Väärä pää alas tai liian reunalle: pölkky kaatuu ja pyörähtää pois pölliltä.
		var out := Vector3(p.x, 0, p.z).normalized() if d > 0.03 else Vector3(cos(yaw), 0, -sin(yaw))
		if not flat and d <= BLOCK_R - 0.07:
			out = (Basis(Vector3.UP, yaw) * Vector3.RIGHT)  # kaatuu vinon pään matalammalle puolelle
			out = Vector3(-out.x, 0, -out.z).normalized()
		var body := _spawn_body(0.0, TAU, Transform3D(Basis(Vector3.UP, yaw) * _flip_xf(0.0 if flat else PI).basis,
			p + Basis(Vector3.UP, yaw) * _flip_xf(0.0 if flat else PI).origin + Vector3(0, 0.005, 0)), 3.0)
		body.linear_velocity = out * 0.9 + Vector3(0, 0.3, 0)
		body.angular_velocity = Vector3.UP.cross(out) * 5.5
		Sfx.play("rattle_hard", -4.0, 0.8)
		_say_kind("wrong_end" if not flat else "edge")
		_wait("pick", 1.2)
		_refresh_pile()
		return
	_standing = Node3D.new()
	_standing.position = p
	_standing.rotation.y = yaw
	add_child(_standing)
	_standing.add_child(_log_mesh())
	_log_pos = p
	_cracks = 0
	_idle_t = 0.0
	_say_kind("placed")
	_wait("chop", 0.4)


func _wait(next: String, t: float) -> void:
	_phase = "wait"
	_after_wait = next
	_wait_t = t
	_update_task()


# --- Kirveen isku ---------------------------------------------------------------------

## Kirveen asento: 0 = lepo, 1 = nostettu olan yli, 2 = isku alas tähtäimeen.
func _pose_axe(s: float) -> void:
	var rest := [Vector3(0.3, -0.42, -0.5), Vector3(-0.35, 0.0, 0.2)]
	var up := [Vector3(0.2, -0.18, -0.3), Vector3(1.25, 0.1, 0.35)]
	var down := [Vector3(0.03, -0.16, -0.55), Vector3(-1.5, 0.0, 0.05)]
	var a: Array
	var b: Array
	var f: float
	if s <= 1.0:
		a = rest
		b = up
		f = s
	else:
		a = up
		b = down
		f = s - 1.0
	var bob := Vector3(0.006 * sin(_t * 1.3), 0.008 * sin(_t * 2.1), 0) if s == 0.0 else Vector3.ZERO
	_axe_vm.position = (a[0] as Vector3).lerp(b[0], f) + bob
	_axe_vm.rotation = (a[1] as Vector3).lerp(b[1], f)


func _update_swing(delta: float) -> void:
	_swing_t += delta
	const UP_T := 0.24
	const DOWN_T := 0.1
	var hold := _swing_hold
	if _swing_t < UP_T:
		_pose_axe(ease(_swing_t / UP_T, 0.6))
	elif _swing_t < UP_T + DOWN_T:
		_pose_axe(1.0 + ease((_swing_t - UP_T) / DOWN_T, 2.2))
	elif not _swing_hit:
		_swing_hit = true
		_pose_axe(2.0)
		_resolve_hit()
	elif _swing_t < UP_T + DOWN_T + hold:
		_pose_axe(2.0)
	elif _swing_t < UP_T + DOWN_T + hold + 0.3:
		_pose_axe(2.0 - 2.0 * (_swing_t - UP_T - DOWN_T - hold) / 0.3)
	else:
		_swing_t = -1.0
		if _phase == "swing":
			_phase = "chop"
			_update_task()


func _resolve_hit() -> void:
	var top := _ray_plane(_log_pos.y + LOG_L)
	var d := Vector2(top.x - _log_pos.x, top.z - _log_pos.z).length()
	_shake = 1.0
	if d > LOG_R + 0.01:
		var low := _ray_plane(BLOCK_TOP)
		if Vector2(low.x, low.z).length() < BLOCK_R:
			Sfx.play("axe", -2.0, 0.6)
			_say_kind("block")
		else:
			Sfx.play("step_grass", 0.0, 0.5)
			Sfx.play("body_fall", -12.0, 1.6)
			_say_kind("ground")
		return
	Sfx.play("axe", 0.0, randf_range(0.95, 1.1))
	if d < CLEAN_R or (d < STUCK_R and _cracks >= 1):
		_split(d < PERFECT_R, _cracks >= 1 and d >= CLEAN_R)
	elif d < STUCK_R:
		_cracks += 1
		_swing_hold = 0.9  # kirves jää hetkeksi kiinni
		_say_kind("stuck")
	else:
		# Syrjäisku: pölkky lentää pölliltä, nostetaan uudestaan.
		var away := Vector3(_log_pos.x - top.x, 0, _log_pos.z - top.z).normalized()
		var body := _spawn_body(0.0, TAU, _standing.transform, 3.0)
		body.linear_velocity = away * 1.8 + Vector3(0, 0.8, 0)
		body.angular_velocity = Vector3.UP.cross(away) * 7.0
		_standing.queue_free()
		_standing = null
		Sfx.play("rattle_hard", -3.0, 0.9)
		_say_kind("knock")
		_wait("pick", 1.0)
		_refresh_pile()


## Pölkky halkeaa ristiin neljäksi haloksi, jotka kaatuvat pölliltä ulospäin.
func _split(perfect: bool, after_stuck: bool) -> void:
	var xf := _standing.transform
	var base := randf() * TAU
	for i in 4:
		var a0 := base + i * PI / 2.0
		var body := _spawn_body(a0, a0 + PI / 2.0, xf, -1.0)
		var mid := a0 + PI / 4.0
		var out := xf.basis * Vector3(cos(mid), 0, sin(mid))
		out.y = 0.0
		out = out.normalized()
		body.linear_velocity = out * randf_range(1.0, 1.7) + Vector3(0, randf_range(0.6, 1.2), 0)
		body.angular_velocity = Vector3.UP.cross(out) * randf_range(4.0, 7.0)
	_standing.queue_free()
	_standing = null
	polkyt -= 1
	halot_made += HALOT
	split.emit(HALOT)
	Sfx.play("rattle", -2.0, 1.1)
	_say_kind("perfect" if perfect else ("stuck_split" if after_stuck else "clean"))
	_refresh_pile()
	if polkyt > 0:
		_wait("pick", 1.1)
	else:
		_wait("end", 3.2)
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_say_kind("done"))


## Fysiikkakappale pölkystä tai sen palasta. ttl < 0: jää maahan pelin loppuun asti.
func _spawn_body(a0: float, a1: float, xf: Transform3D, ttl: float) -> RigidBody3D:
	var piece := log_piece(a0, a1, 12 if a1 - a0 < TAU - 0.01 else 16)
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1 | 16
	body.mass = 2.0 if a1 - a0 < TAU - 0.01 else 6.0
	body.continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	pm.bounce = 0.15
	body.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = piece[1]
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = piece[0]
	body.add_child(mi)
	body.transform = xf
	add_child(body)
	_add_debris(body, ttl)
	return body
