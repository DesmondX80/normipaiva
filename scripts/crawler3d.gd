extends Node3D
## Rasvanapin pelaaja 3D:nä (rasvanappi_game.gd, rasvanappi_hall.gd): character.gd-hahmo pyyhe lanteilla.
## Asennot (stance): "stand" seisoo (esittely), "crawl" konttaa: hahmo kallistetaan lantion ympäri lähes vaakaan, kädet
## ja polvet IK:lla lattiaan, pää ylös; ristikkäinen käynti (oikea käsi ja vasen polvi yhtä aikaa).
## Solmun origo lattialla lantion alla, eteenpäin -Z (kuten hahmolla).

const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

const HIP_H := 0.5  # lantion korkeus polvillaan
const PITCH := -1.32  # vartalon kallistus konttaessa (rad), hartiat hieman lantiota alempana
const STRIDE := 0.11
const R := -1.0  # oikeanpuoleiset luut (_r) ovat solmun -X:ssä (malli käännetty)

var ch: Node3D
var stance := "crawl"
var reach := 0.0  # 0..1 oikea käsi kurottaa tökkäämään (eteen ja ylös)
var jolt := 0.0  # 0..1 säpsähdys tökättäessä (lantio pomppaa)
var _tilt: Node3D
var _pelvis := Vector3.ZERO
var _butter: MeshInstance3D
var _towel_mats: Array[StandardMaterial3D] = []
var _towel_col := Color.WHITE
var _towel_root: Node3D  # miehillä pyyhe lanteilla erillisenä
var _chest_tuck: Node3D
var _woman := false  # naisilla pyyhe maalataan vartaloon (myötäilee), kainaloista reiden puoliväliin
var _finger := Vector3.ZERO  # etusormen pää ranteesta (hahmon avaruudessa, lepoasento)
var _orig := {}  # alkuperäiset värit naamioinnin ajaksi


## look: character.gd-ulkonäkö; towel: pyyhkeen väri; woman: pyyhe kainaloista reisiin, muuten vyötäröltä.
## Pyyhe on päällä vain seistessä (esittely): pimeässä konttaillaan ilman (set_towel).
func setup(look: Dictionary, towel: Color, woman := false) -> void:
	_tilt = Node3D.new()
	add_child(_tilt)
	var lk := look.duplicate()
	var skin: Color = lk.get("skin", Color(1.0, 0.9, 0.85))
	lk["shirt"] = skin
	lk["pants"] = skin
	lk["shoes"] = skin
	lk["tube_y"] = 0.01  # paljas yläkroppa ja jalat, pyyhe erillisenä
	lk["sleeve_x"] = 0.0
	lk["shorts_y"] = 1.4
	ch = Looks.make(_tilt, lk)
	_pelvis = ch.bone_position("pelvis")
	ch.play("Idle")
	var sk: Skeleton3D = ch.skeleton
	var to_c: Transform3D = ch.model.transform * sk.transform
	var wrist: Vector3 = to_c * sk.get_bone_global_rest(sk.find_bone("hand_r")).origin
	var elbow: Vector3 = to_c * sk.get_bone_global_rest(sk.find_bone("lowerarm_r")).origin
	_finger = (wrist - elbow).normalized() * 0.09
	# Margariininokare oikean käden etusormessa.
	_butter = MeshInstance3D.new()
	_butter.mesh = B.sphere(0.022, 8)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.86, 0.3)
	bm.roughness = 0.3
	bm.emission_enabled = true  # erottuu pimeässä
	bm.emission = Color(0.25, 0.2, 0.05)
	_butter.material_override = bm
	_butter.scale = Vector3(1.0, 0.8, 1.0)
	_butter.visible = false
	ch.attach("hand_r", _butter, _finger)
	_woman = woman
	_towel_col = towel
	_build_towel(towel, float(look.get("bulk", 0.0)), float(look.get("belly", 0.0)), woman)
	set_stance("crawl")


## Pyyhe lanteilla: kartiomainen kangasputki, helmassa raidat ja kyljessä kiinnityskohdan taite. Miehillä pieni
## lannevaate; naisilla kireä helma lanteilta reiden puoliväliin (yläosa maalataan vartaloon, set_towel).
func _build_towel(col: Color, bulk: float, belly: float, woman: bool) -> void:
	var root := Node3D.new()
	var w := 1.0 + bulk * 0.12 + belly * 0.18
	var h := 0.36 if not woman else 0.34
	var top := 0.135 * w if not woman else 0.172 * w
	var flare := 1.2 if not woman else 0.98  # naisilla helma kapenee reisiä myötäillen
	var parts := [[top, top * flare, h, Vector3(0, -h / 2.0 + 0.06, 0), col]]
	for k in 2:  # raidat helmassa
		var y: float = -h + 0.06 + 0.05 + k * 0.035
		var r := top * flare - (top * flare - top) * ((y + h - 0.06) / h) + 0.003
		parts.append([r, r, 0.016, Vector3(0, y, 0), col.darkened(0.3)])
	for pr in parts:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = pr[0]
		cm.bottom_radius = pr[1]
		cm.height = pr[2]
		cm.radial_segments = 20
		cm.rings = 2
		cm.cap_top = false
		cm.cap_bottom = false
		mi.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = pr[4]
		m.roughness = 0.95
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		_towel_mats.append(m)
		mi.position = pr[3]
		mi.scale = Vector3(1.0, 1.0, 0.82 if not woman else 0.9)  # litteämpi edestä taakse
		root.add_child(mi)
	var tuck := MeshInstance3D.new()  # taite kyljessä
	tuck.mesh = B.boxm(Vector3(0.05, 0.1, 0.03) if not woman else Vector3(0.04, 0.12, 0.025))
	var tm := StandardMaterial3D.new()
	tm.albedo_color = col.darkened(0.12)
	tm.roughness = 0.95
	tuck.material_override = tm
	_towel_mats.append(tm)
	if woman:  # naisilla taite rinnan sivussa, vartaloon maalatun yläosan reunassa
		ch.attach("spine_03", tuck, Vector3(R * 0.12, 0.08, -0.08))
		_chest_tuck = tuck
	else:
		tuck.position = Vector3(top * 0.7, 0.0, -top * 0.55)
		root.add_child(tuck)
	ch.attach("pelvis", root, Vector3(0, 0.02, 0))
	_towel_root = root


## Pyyhe päälle tai pois. Naisilla vartalon varjostin: paita- ja housualue pyyhkeen värisenä kainaloista reiden
## puoliväliin (myötäilee vartaloa), pois = kaikki paljasta.
func set_towel(on: bool) -> void:
	if _towel_root != null:
		_towel_root.visible = on
	if _chest_tuck != null:
		_chest_tuck.visible = on
	if _woman:
		var bm: ShaderMaterial = ch.body_mat
		bm.set_shader_parameter("shirt", _towel_col)
		bm.set_shader_parameter("pants", _towel_col)
		bm.set_shader_parameter("tube_y", 1.42 if on else 0.01)
		bm.set_shader_parameter("sleeve_x", 0.15 if on else 0.0)
		bm.set_shader_parameter("shorts_y", 0.88 if on else 1.4)


func set_butter(on: bool) -> void:
	_butter.visible = on


func set_stance(s: String) -> void:
	stance = s
	ch.clear_ik()
	ch.clear_overrides()
	set_towel(s == "stand")
	match s:
		"stand":
			_tilt.position = Vector3.ZERO
			_tilt.rotation = Vector3.ZERO
			ch.position = Vector3.ZERO
		_:
			_tilt.position = Vector3(0, HIP_H, 0)
			_tilt.rotation = Vector3(PITCH, 0, 0)
			ch.position = -_pelvis
			ch.set_override("neck_01", Vector3.RIGHT, 0.7)  # pää ylös katsomaan eteen
			ch.set_override("Head", Vector3.RIGHT, 0.4)
	pose(0.0, 0.0)


## Raajat asennon mukaan: phase kulkee liikkuessa, moving 0..1 (askeleen pituus ja nosto).
func pose(phase: float, moving: float) -> void:
	if stance == "stand":
		return
	var sh_z: float = to_local(ch.to_global(ch.bone_position("upperarm_r"))).z
	for side in [1.0, -1.0]:
		var sfx := "_r" if side > 0.0 else "_l"
		var s := sin(phase + (0.0 if side > 0.0 else PI))  # oikea käsi ja vasen polvi samaan tahtiin
		var lift := maxf(0.0, cos(phase + (0.0 if side > 0.0 else PI))) * 0.05 * moving
		var hand := Vector3(R * side * 0.19, 0.03 + lift, sh_z - 0.04 - s * STRIDE * moving)
		var elbow := Vector3(R * side * 0.45, 0.6, sh_z + 0.5)
		if side > 0.0 and reach > 0.0:  # tökkäys: käsi eteen lantion korkeudelle
			hand = hand.lerp(Vector3(R * 0.1, 0.5, sh_z - 0.5), reach)
			elbow = elbow.lerp(Vector3(R * 0.5, 0.3, sh_z), reach)
		ch.set_ik("arm" + sfx, "upperarm" + sfx, "lowerarm" + sfx, "hand" + sfx, _ch(hand), _ch(elbow))
		var ks := -s  # polvi vastavaiheessa samanpuoleiseen käteen
		var klift := maxf(0.0, -cos(phase + (0.0 if side > 0.0 else PI))) * 0.04 * moving
		var foot := Vector3(R * side * 0.14, 0.07 + klift, 0.42 - ks * STRIDE * moving)
		var knee := Vector3(R * side * 0.12, -0.6, -0.4)
		ch.set_ik("leg" + sfx, "thigh" + sfx, "calf" + sfx, "foot" + sfx, _ch(foot), _ch(knee))
	_tilt.position.y = HIP_H + sin(jolt * PI) * 0.12
	_tilt.rotation.x = PITCH + sin(jolt * PI) * 0.15


func _ch(p: Vector3) -> Vector3:
	return ch.to_local(to_global(p))


## Pimeässä kaikki näyttävät samalta (iho, pyyhe ja hiukset samaa sävyä); off palauttaa omat värit.
func disguise(on: bool, skin := Color(0.82, 0.68, 0.6), towel := Color(0.35, 0.33, 0.3), hair := Color(0.12, 0.1, 0.09)) -> void:
	var bm: ShaderMaterial = ch.body_mat
	if _orig.is_empty():
		for k in ["skin_tint", "bare_skin"]:
			_orig[k] = bm.get_shader_parameter(k)
		for mi in ch.skeleton.get_children():
			if mi is MeshInstance3D and mi.material_override is StandardMaterial3D:
				_orig[mi] = (mi.material_override as StandardMaterial3D).albedo_color
		for m in _towel_mats:
			_orig[m] = m.albedo_color
	for k in _orig:
		if k is String:
			bm.set_shader_parameter(k, _orig[k] if not on else (Color.WHITE if k == "skin_tint" else skin))
		elif k is StandardMaterial3D:
			(k as StandardMaterial3D).albedo_color = _orig[k] if not on else towel
		elif is_instance_valid(k):
			(k.material_override as StandardMaterial3D).albedo_color = _orig[k] if not on else hair * 1.6
