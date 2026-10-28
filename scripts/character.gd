extends Node3D
## Realistinen hahmo: Quaternius Universal Base Characters (CC0) + Universal Animation Library (CC0).
## Vaatteet väritetään shaderilla luuston painojen perusteella, hiukset liitetään samaan luustoon.
## Kasvot -Z-suuntaan. Animaatiota edistetään käsin, jotta luiden ohitukset (polkeminen, potku,
## kumara) voidaan lisätä animaation päälle samassa ruudussa.

const MODELS := {
	"male": ["res://assets/characters/Superhero_Male_FullBody.gltf", "res://assets/characters/T_Superhero_Male_Light.png"],
	"female": ["res://assets/characters/Superhero_Female_FullBody.gltf", "res://assets/characters/T_Superhero_Female_Light.png"],
}
const ANIM_FILE := "res://assets/characters/UAL1_Standard.glb"
const HAIR_DIR := "res://assets/characters/hair/"
const SHADER := "res://shaders/character.gdshader"
const HAIR_SHADER := "res://shaders/hair.gdshader"
const REST_HEIGHT := 1.8
const DEFAULT_MUSCLE := -0.85  # pohjamalli on superhero: tavallisilla ihmisillä lihakset pienemmiksi
const Elastic := preload("res://scripts/elastic.gd")
const PRESS_MAX := 6  # kontaktilaatikoita enintään (varjostimen press_xf0..5)

static var _lib: AnimationLibrary
static var _meshes := {}

var skeleton: Skeleton3D
var anim: AnimationPlayer
var model: Node3D
var body_mat: ShaderMaterial
var born_frame := 0  # setup-kutsun ruutu: paistaminen onnistuu vasta myöhemmin (Contact.profile)
var profile_key := ""  # kontaktimallin välimuistiavain (malli, pituus, vartalo), Contact.profile
var body_mi: MeshInstance3D  # vartalon verkko (kontaktien painuma)
var body_shape := {}  # belly, bulk, bust (Elastic.sink)
var press_boxes: Array = []  # [[Transform3D verkko -> laatikko, puolikoko], ...] verkon avaruudessa (Elastic.press)
var hair_mats: Array = []  # hiusten ShaderMaterialit (hair.gdshader): samat painumalaatikot kuin vartalolla
var hair_mis: Array = []  # hiusverkot (meta "hair_press"; Pose.limb_points)

var _overrides := {}  # luu -> [akseli hahmon avaruudessa, kulma]
var _ik := {}  # nimi -> [luu a, luu b, luu c, kohde, polvi/kyynärpää-suunta, loppuluun lisäkierto] (hahmon avaruudessa)
var _current := ""
var _sway_x := Vector3.ZERO  # hiusten heilahdus (maailma, m), jousi Elastic.spring_step
var _sway_v := Vector3.ZERO
var _sway_p := Vector3.ZERO  # hiusmassan keskipiste maailmassa edellisellä ruudulla
var _sway_pv := Vector3.ZERO
var _sway_valid := false
var _sway_zero := true  # hair_sway-uniformi on jo nolla
var _sway_local := Vector3.ZERO  # hiusmassan keskipiste Head-luun avaruudessa
var _head_bone := -1
var _jig := []  # hyllyntä (Elastic.JIGGLE): [osa, luu, piste luun avaruudessa, voimakkuus, x, v, edell. paikka, edell. nopeus]
var _jig_valid := false
var _jig_zero := true  # jiggle_*-uniformit ovat jo nolla


## look: model, shirt, pants, shoes, skin, hair (tiedoston nimi ilman päätettä tai ""), hair_color,
## beard (bool), stripes (bool), height (m), shine (0..1).
## Vartalo: belly (0..1 kaljamaha), bulk (-1..1 hoikka..tukeva), shoulders (-1..1 kapeat..leveät hartiat),
## muscle (-1..0 lihakset pienemmiksi; oletus DEFAULT_MUSCLE).
func setup(look: Dictionary) -> void:
	var kind: String = look.get("model", "male")
	born_frame = Engine.get_process_frames()
	profile_key = "%s_%.3f_%.2f_%.2f_%.2f" % [kind, float(look.get("height", REST_HEIGHT)), float(look.get("belly", 0.0)),
		float(look.get("bulk", 0.0)), float(look.get("muscle", DEFAULT_MUSCLE))]
	model = load(MODELS[kind][0]).instantiate()
	add_child(model)
	model.rotation.y = PI
	model.scale = Vector3.ONE * (float(look.get("height", REST_HEIGHT)) / REST_HEIGHT)
	skeleton = model.get_node("Armature/Skeleton3D")

	var body: MeshInstance3D = null
	for mi in skeleton.get_children():
		if mi is MeshInstance3D and (body == null or mi.mesh.surface_get_array_len(0) > body.mesh.surface_get_array_len(0)):
			body = mi
	var src: StandardMaterial3D = body.mesh.surface_get_material(0)
	var body_src: Mesh = body.mesh  # vaatettamaton lähdeverkko (hiusten etäisyys kalloon)
	var shape := {"belly": float(look.get("belly", 0.0)), "bulk": float(look.get("bulk", 0.0)),
		"shoulders": float(look.get("shoulders", 0.0)), "muscle": float(look.get("muscle", DEFAULT_MUSCLE)),
		"curves": float(look.get("curves", 0.0)), "bust": float(look.get("bust", 0.0))}
	body_shape = shape
	body.mesh = _clothed_mesh(kind, body.mesh, body.skin, skeleton, bool(look.get("stripes", false)), shape)
	body_mat = ShaderMaterial.new()
	body_mat.shader = load(SHADER)
	body_mat.set_shader_parameter("albedo_tex", load(MODELS[kind][1]))
	body_mat.set_shader_parameter("normal_tex", src.normal_texture)
	body_mat.set_shader_parameter("rough_tex", src.roughness_texture)
	body_mat.set_shader_parameter("skin_tint", look.get("skin", Color(1.0, 0.95, 0.92)))
	body_mat.set_shader_parameter("shirt", look.get("shirt", Color(0.5, 0.5, 0.5)))
	body_mat.set_shader_parameter("pants", look.get("pants", Color(0.2, 0.25, 0.4)))
	body_mat.set_shader_parameter("shoes", look.get("shoes", Color(0.12, 0.1, 0.1)))
	body_mat.set_shader_parameter("fabric_shine", look.get("shine", 0.0))
	# Kaljamaha pehmentää superhero-lihakset kankaan alla.
	var mus := float(look.get("muscle", DEFAULT_MUSCLE))
	body_mat.set_shader_parameter("muscle_def", (1.0 - 0.8 * clampf(float(look.get("belly", 0.0)), 0.0, 1.0)) * (1.0 + 0.6 * mus))
	for k in ["shorts_y", "crop_y", "sleeve_x", "tube_y", "denim", "bare_skin", "jeans", "belt_y", "belt_col", "net_shirt",
			"suspenders", "strap_col", "workwear", "flannel", "tattoo", "shirt_puff", "pants_puff", "string_bikini", "ski_suit"]:
		if look.has(k):
			body_mat.set_shader_parameter(k, look[k])
	if look.has("stripe_color"):
		body_mat.set_shader_parameter("stripe_col", look.stripe_color)
	if look.has("tracksuit"):
		# Tuulipuku: kiiltävä nailon, 90-luvun vinot värikentät, vetoketju, väljä leikkaus.
		var ts: Dictionary = look.tracksuit
		body_mat.set_shader_parameter("tracksuit", true)
		body_mat.set_shader_parameter("panel_a", ts.get("a", Color(0.1, 0.65, 0.62)))
		body_mat.set_shader_parameter("panel_b", ts.get("b", Color(0.08, 0.08, 0.1)))
		body_mat.set_shader_parameter("shirt_puff", 0.034)
		body_mat.set_shader_parameter("pants_puff", 0.038)
	body.material_override = body_mat
	body_mi = body
	press_boxes.clear()

	var hair_color: Color = look.get("hair_color", Color(0.25, 0.18, 0.12))
	for mi in skeleton.get_children():
		if mi is MeshInstance3D and mi.name == "Eyebrows":
			_tint(mi, hair_color)
	var hair: String = look.get("hair", "Hair_SimpleParted")
	if hair != "":
		_attach_hair(HAIR_DIR + hair + ".gltf", hair_color, kind, body_src)
	if look.get("beard", false):
		_attach_hair(HAIR_DIR + "Hair_Beard.gltf", hair_color, kind, body_src)

	# Matalilla laatutasoilla kaukaiset hahmot jäävät piirtämättä (kylässä 130–190 hahmoa, jokaisella oma luusto).
	var q: int = Settings.get_v("quality")
	if q <= 1:
		for gi in model.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).visibility_range_end = [60.0, 90.0][q]
	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.add_animation_library("", _library())
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	play("Idle", 0.0)
	anim.seek(randf() * 2.0, true)


## Uusi ulkonäkö paikallaan (pelaajan asun vaihto, looks.gd restyle_player): malli vaihdetaan, mutta tämä solmu,
## sen lapset (kassit) ja luiden ohitukset ja IK-ketjut säilyvät, joten viittaukset hahmoon pysyvät voimassa.
## Luihin kiinnitetyt (attach) lähtevät mallin mukana; kutsuja lisää ne uudelleen.
func restyle(look: Dictionary) -> void:
	var cur := _current
	var spd := anim.speed_scale if anim != null else 1.0
	var pos := anim.current_animation_position if anim != null and anim.is_playing() else 0.0
	var layers := 0
	for mi in model.find_children("*", "VisualInstance3D", true, false):
		layers = (mi as VisualInstance3D).layers
		break
	remove_child(model)
	model.free()
	_current = ""
	setup(look)
	if layers != 0 and layers != 1:
		for mi in model.find_children("*", "VisualInstance3D", true, false):
			(mi as VisualInstance3D).layers = layers
	if cur != "":
		play(cur, 0.0, spd)
		anim.seek(pos, true)


func play(anim_name: String, blend := 0.2, speed := 1.0) -> void:
	if _current == anim_name:
		anim.speed_scale = speed
		return
	_current = anim_name
	anim.speed_scale = speed
	anim.play(anim_name, blend)


## Sama animaatio alusta (esim. kirveen isku uudestaan).
func restart(anim_name: String, blend := 0.1, speed := 1.0) -> void:
	_current = anim_name
	anim.speed_scale = speed
	anim.play(anim_name, blend)
	anim.seek(0.0, true)


func current() -> String:
	return _current


func anim_length(anim_name: String) -> float:
	return anim.get_animation(anim_name).length


## Kiertää luuta hahmon omassa avaruudessa (esim. Vector3.RIGHT = eteen/taakse heilautus) animaation päälle.
func set_override(bone: String, axis: Vector3, angle: float) -> void:
	_overrides[bone] = [axis, angle]


func clear_overrides() -> void:
	_overrides.clear()


## Kaksiniveinen IK: ketju a -> b -> c (esim. reisi, sääri, jalkaterä) kurottaa c:n kohteeseen,
## taipuen pole-pisteen suuntaan. Kohde ja pole hahmon avaruudessa; päivitetään joka ruutu.
## twist: loppuluun (käsi, jalkaterä) lisäkierto hahmon avaruudessa ratkaisun jälkeen (esim. kämmen reiden suuntaan).
func set_ik(chain: String, a: String, b: String, c: String, target: Vector3, pole: Vector3, twist := Basis()) -> void:
	_ik[chain] = [a, b, c, target, pole, twist]


## Loppuluun (käsi, jalkaterä) asento suoraan hahmon avaruudessa painolla w (0 = IK:n tulos, 1 = orient), kun
## suhteellinen kierto (twist) vaihtelisi kyynärvarren asennon mukana. Kutsu set_ik:n jälkeen.
func set_ik_orient(chain: String, orient: Basis, w: float) -> void:
	if _ik.has(chain):
		var c: Array = _ik[chain]
		c.resize(8)
		c[6] = orient
		c[7] = w


func clear_ik() -> void:
	_ik.clear()
	_reset_sway()
	_reset_jiggle()
	clear_contacts()


## Kontaktilaatikot painumaa varten: [[Transform3D maailmassa, puolikoko Vector3], ...] (enintään PRESS_MAX), laatikon
## paikallinen +Y on aktiivinen pinta, jota vasten pehmeät osat painuvat (Elastic, varjostin vertex()). Muunnetaan
## vartalon verkon avaruuteen kerran; ei ruutukohtaista työtä. Kutsu asennon valmistuttua (Pose.sit viimeisenä).
func set_contacts(world_boxes: Array) -> void:
	press_boxes.clear()
	if body_mi == null:
		return
	var inv := body_mi.global_transform.affine_inverse()
	for wb in world_boxes:
		if press_boxes.size() >= PRESS_MAX:
			break
		var xf: Transform3D = inv * (wb[0] as Transform3D)
		var sc := xf.basis.x.length()
		var local := Transform3D(xf.basis.orthonormalized(), xf.origin)
		press_boxes.append([local.affine_inverse(), (wb[1] as Vector3) * sc])
	_upload_contacts()


## Poistaa painumat (hahmo nousee tai vaihtaa asentoa): lepoverkko takaisin.
func clear_contacts() -> void:
	if press_boxes.is_empty():
		return
	press_boxes.clear()
	_upload_contacts()


func _upload_contacts() -> void:
	_upload_press(body_mat)
	var org := _head_center()
	for m in hair_mats:
		_upload_press(m)
		m.set_shader_parameter("press_origin", org)


## Pään keskus (kallon keskipiste) verkon avaruudessa nykyisessä asennossa: hiusten leviämisen keskus.
func _head_center() -> Vector3:
	var hi := skeleton.find_bone("Head")
	if hi < 0:
		return Vector3.ZERO
	var rest := skeleton.get_bone_global_rest(hi)
	return skeleton.get_bone_global_pose(hi) * (rest.affine_inverse() * (rest.origin + Vector3(0.0, 0.09, 0.0)))


func _upload_press(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("press_n", press_boxes.size())
	for i in press_boxes.size():
		mat.set_shader_parameter("press_xf%d" % i, Projection(press_boxes[i][0]))
		mat.set_shader_parameter("press_h%d" % i, press_boxes[i][1])


## Luun paikka tämän solmun avaruudessa.
func bone_position(bone: String) -> Vector3:
	var p := skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
	return (model.transform * skeleton.transform * p)


## Luun nykyinen kierto lepoasennosta hahmon avaruudessa (esim. päänkallistus: kierrä sillä lepoasennon siirtymä).
func bone_delta(bone: String) -> Basis:
	var i := skeleton.find_bone(bone)
	var m := (model.transform * skeleton.transform).basis
	return m * (skeleton.get_bone_global_pose(i).basis * skeleton.get_bone_global_rest(i).basis.inverse()) * m.inverse()


## Kiinnittää solmun luuhun; offset hahmon avaruudessa lepoasennosta, pysyy pystyssä lepoasennossa.
func attach(bone: String, node: Node3D, offset: Vector3) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	var inv_model := (model.transform * skeleton.transform).affine_inverse()
	var target := rest.origin + (inv_model.basis * offset)
	node.transform = Transform3D(rest.basis.inverse() * inv_model.basis, rest.basis.inverse() * (target - rest.origin))
	ba.add_child(node)
	return ba


## Kaukana tai piilossa olevat hahmot päivittyvät harvemmin (luuston animaatio ja IK ovat kalliita: kylässä on
## 130-190 hahmoa): kertynyt aika ajetaan kerralla, joten animaatio ei hidastu. Lähellä joka ruutu.
const LOD_STEPS := [[35.0, 1], [80.0, 2], [160.0, 4], [INF, 8]]
static var _cam_frame := -1
static var _cam_pos := Vector3.INF
var _pending := 0.0
var _phase := -1


func _lod_interval() -> int:
	var f := Engine.get_process_frames()
	if f != _cam_frame:
		_cam_frame = f
		var cam := get_viewport().get_camera_3d()
		_cam_pos = cam.global_position if cam != null else Vector3.INF
	if _cam_pos == Vector3.INF:
		return 1
	var d := global_position.distance_to(_cam_pos)
	for st in LOD_STEPS:
		if d < st[0]:
			return st[1]
	return 8


func _process(delta: float) -> void:
	if anim == null:
		return
	_pending += delta
	if not is_visible_in_tree():
		_pending = minf(_pending, 2.0)  # piilossa ei päivitetä; näkyviin tullessa animaatio jatkuu luontevasti
		_reset_jiggle()
		return
	var every := _lod_interval()
	if every > 1:
		if _phase < 0:
			_phase = get_instance_id() % 8
		if (Engine.get_process_frames() + _phase) % every != 0:
			return
	delta = _pending
	_pending = 0.0
	_update_pose(delta)


## Laskee asennon heti (lepo, animaatio, ohitukset ja IK), jotta paistettu verkko ja luiden paikat ovat ajan tasalla
## ilman ruudun odotusta (Contact.resolve, Pose.sit).
func refresh_pose() -> void:
	if anim != null:
		_update_pose(0.0)


func _update_pose(delta: float) -> void:
	# Luut, joilla ei ole animaatioraitaa, eivät nollaudu itsestään: palautetaan lepoon ennen animaatiota.
	for bone in _overrides:
		var bi := skeleton.find_bone(bone)
		skeleton.set_bone_pose_rotation(bi, skeleton.get_bone_rest(bi).basis.get_rotation_quaternion())
	# IK-ketjujen luiden paikat lepoon: animaatiossa ei ole niille paikkaraitoja, joten virhe ei saa kertyä.
	for chain in _ik:
		for bn in _ik[chain].slice(0, 3):
			var bj := skeleton.find_bone(bn)
			skeleton.set_bone_pose_position(bj, skeleton.get_bone_rest(bj).origin)
			skeleton.set_bone_pose_scale(bj, Vector3.ONE)
	anim.advance(delta)
	var to_skel := (model.transform * skeleton.transform).basis.inverse()
	for bone in _overrides:
		var o: Array = _overrides[bone]
		if is_zero_approx(o[1]):
			continue
		var i := skeleton.find_bone(bone)
		var parent := skeleton.get_bone_parent(i)
		var parent_rot := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		var axis: Vector3 = (to_skel * o[0]).normalized()
		var q := Quaternion(axis, o[1])
		skeleton.set_bone_pose_rotation(i, parent_rot.inverse() * q * parent_rot * skeleton.get_bone_pose_rotation(i))
	_apply_ik()
	_update_hair_sway(delta)
	_update_jiggle(delta)


func _apply_ik() -> void:
	if _ik.is_empty():
		return
	var to_skel := (model.transform * skeleton.transform).affine_inverse()
	for chain in _ik:
		var c: Array = _ik[chain]
		var ia := skeleton.find_bone(c[0])
		var ib := skeleton.find_bone(c[1])
		var ic := skeleton.find_bone(c[2])
		var ga := skeleton.get_bone_global_pose(ia)
		var gb := skeleton.get_bone_global_pose(ib)
		var gc := skeleton.get_bone_global_pose(ic)
		var t: Vector3 = to_skel * c[3]
		var pole: Vector3 = to_skel * c[4]
		var a := ga.origin
		var l1 := a.distance_to(gb.origin)
		var l2 := gb.origin.distance_to(gc.origin)
		var to_t := t - a
		var d := clampf(to_t.length(), 0.01, (l1 + l2) * 0.999)
		var dir := to_t.normalized()
		var bend := (pole - a) - dir * (pole - a).dot(dir)
		if bend.length() < 0.001:
			bend = (gb.origin - a) - dir * (gb.origin - a).dot(dir)
		bend = bend.normalized()
		var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
		var knee := a + dir * cos_a * l1 + bend * sqrt(1.0 - cos_a * cos_a) * l1
		# Kierretään a niin, että b osuu polveen, sitten b niin, että c osuu kohteeseen.
		var q1 := _arc(gb.origin - a, knee - a)
		_set_global_rot(ia, Basis(q1) * ga.basis)
		gb = skeleton.get_bone_global_pose(ib)
		gc = skeleton.get_bone_global_pose(ic)
		var q2 := _arc(gc.origin - gb.origin, (a + dir * d) - gb.origin)
		_set_global_rot(ib, Basis(q2) * gb.basis)
		var tw: Basis = c[5]
		if tw != Basis():
			var ts := to_skel.basis.orthonormalized()
			gc = skeleton.get_bone_global_pose(ic)
			_set_global_rot(ic, (ts * tw * ts.inverse()) * gc.basis)
		if c.size() > 7 and c[6] != null and float(c[7]) > 0.0:
			gc = skeleton.get_bone_global_pose(ic)
			var want: Basis = to_skel.basis.orthonormalized() * (c[6] as Basis)
			var q := gc.basis.orthonormalized().get_rotation_quaternion().slerp(want.get_rotation_quaternion(), clampf(float(c[7]), 0.0, 1.0))
			_set_global_rot(ic, Basis(q))


## Asettaa luun globaalin kierron muuttamalla vain paikallista kiertoa (paikka ja mittakaava ennallaan).
func _set_global_rot(i: int, gbasis: Basis) -> void:
	var parent := skeleton.get_bone_parent(i)
	var pg := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	skeleton.set_bone_pose_rotation(i, (pg.orthonormalized().inverse() * gbasis.orthonormalized()).get_rotation_quaternion())


static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	var f := from.normalized()
	var t := to.normalized()
	var axis := f.cross(t)
	if axis.length() < 0.00001:
		return Quaternion.IDENTITY
	return Quaternion(axis.normalized(), f.angle_to(t))


# --- Lataus ------------------------------------------------------------------

func _attach_hair(path: String, color: Color, kind: String, body_src: Mesh) -> void:
	var scene: Node = load(path).instantiate()
	var head := skeleton.find_bone("Head")
	var y_ref := skeleton.get_bone_global_rest(head).origin.y + 0.08
	for mi in scene.find_children("*", "MeshInstance3D"):
		mi.owner = null
		mi.get_parent().remove_child(mi)
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		var m: Material = mi.mesh.surface_get_material(0)
		if m is StandardMaterial3D and body_src != null:
			# Oma varjostin: hiukset painuvat ja heiluvat (hair.gdshader), ulkonäkö kuin gltf:n materiaalissa.
			var hm := _hair_mesh(path.get_file() + "/" + str(mi.name), kind, mi.mesh, body_src, y_ref)
			var sm := ShaderMaterial.new()
			sm.shader = load(HAIR_SHADER)
			sm.set_shader_parameter("albedo_tex", (m as StandardMaterial3D).albedo_texture)
			sm.set_shader_parameter("normal_tex", (m as StandardMaterial3D).normal_texture)
			sm.set_shader_parameter("hair_col", color * 1.6)
			sm.set_shader_parameter("hair_rough", (m as StandardMaterial3D).roughness)
			sm.set_shader_parameter("press_radial", 1.0)
			mi.mesh = hm
			mi.material_override = sm
			mi.set_meta("hair_press", true)
			mi.set_meta("hair_center", hm.get_meta("hair_center"))
			mi.set_meta("hair_cw", hm.get_meta("hair_cw"))
			hair_mats.append(sm)
			hair_mis.append(mi)
		else:
			_tint(mi, color)
	scene.free()


## Hiusverkko, jossa CUSTOM0.w = painumaraja ja CUSTOM0.x = heilahduspaino. Raja = 0,9 x etäisyys lähimpään vartaloverkon
## pisteeseen (kallon pinta; max 6 cm), joten hiukset litistyvät lähes paksuutensa verran ja kallo pysyy jäykkänä.
## Heilahduspaino: pitkät latvat (alle pään) heiluvat, päälaki ja siilitukka eivät. Verteksien järjestys säilyy (looks.gd
## _tuck_hair). meta "hair_center"/"hair_cw": heilahduspainolla painotettu keskipiste ja painojen summa (verkon avaruus).
static func _hair_mesh(hname: String, kind: String, src: Mesh, body_src: Mesh, y_ref: float) -> ArrayMesh:
	var key := "hair/%s/%s" % [hname, kind]
	var live: ArrayMesh = (_meshes[key] as WeakRef).get_ref() if _meshes.has(key) else null
	if live != null:
		return live
	var cell := 0.02
	var ymin := INF
	for s in src.get_surface_count():
		for v in (src.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			ymin = minf(ymin, v.y)
	var grid := {}  # ruutu -> pisteet
	for s in body_src.get_surface_count():
		for v in (body_src.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if v.y < ymin - 0.1:
				continue
			var c := Vector3i((v / cell).floor())
			if not grid.has(c):
				grid[c] = PackedVector3Array()
			(grid[c] as PackedVector3Array).append(v)
	var out := ArrayMesh.new()
	var csum := Vector3.ZERO
	var wsum := 0.0
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var fmt: int = (src as ArrayMesh).surface_get_format(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var c0 := PackedFloat32Array()
		c0.resize(verts.size() * 4)
		for i in verts.size():
			var p := verts[i]
			var d := _grid_dist(grid, cell, p)
			var wl := minf(0.9 * maxf(d - 0.002, 0.0), 0.06)
			var sw := smoothstep(0.0, 0.3, y_ref - p.y) * smoothstep(0.005, 0.03, d)
			c0[i * 4] = sw
			c0[i * 4 + 3] = wl
			csum += p * sw
			wsum += sw
		arr[Mesh.ARRAY_CUSTOM0] = c0
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
			(fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT))
		out.surface_set_material(s, src.surface_get_material(s))
	out.set_meta("hair_center", csum / wsum if wsum > 0.0 else Vector3.ZERO)
	out.set_meta("hair_cw", wsum)
	_meshes[key] = weakref(out)
	return out


## Etäisyys lähimpään ruutuhajautetun pistejoukon pisteeseen (kuorihaku; 4 ruudun yli palauttaa 0,08).
static func _grid_dist(grid: Dictionary, cell: float, p: Vector3) -> float:
	var c := Vector3i((p / cell).floor())
	var best := INF
	for r in 5:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if maxi(maxi(absi(dx), absi(dy)), absi(dz)) != r:
						continue
					var pts = grid.get(c + Vector3i(dx, dy, dz))
					if pts == null:
						continue
					for q in (pts as PackedVector3Array):
						best = minf(best, p.distance_squared_to(q))
		if best <= (r * cell) * (r * cell):
			break
	return sqrt(best) if best < INF else cell * 4.0


## Hiusten heilahdus: jousi (Elastic.spring_step) hiusmassan keskipisteen kiihtyvyydestä, uniformina hair_sway. Vain
## lähellä (LOD-väli 1); kauempana nollataan. Painuma tehdään heilahduksen jälkeen, joten noja pitää hiukset pois sisältä.
const SWAY_K := 101.0  # (2 pi x 1,6 Hz)^2
const SWAY_C := 4.0  # vaimennussuhde 0,2: 2 x 0,2 x sqrt(k)
const SWAY_MAX := 0.05
const SWAY_STEP := 1.0 / 120.0


func _update_hair_sway(delta: float) -> void:
	if hair_mis.is_empty() or delta <= 0.0:
		return
	if _lod_interval() > 1:
		_reset_sway()
		return
	if _head_bone < 0:
		_head_bone = skeleton.find_bone("Head")
		var csum := Vector3.ZERO
		var wsum := 0.0
		for mi in hair_mis:
			var w: float = mi.get_meta("hair_cw")
			csum += (mi.get_meta("hair_center") as Vector3) * w
			wsum += w
		_sway_local = skeleton.get_bone_global_rest(_head_bone).affine_inverse() * (csum / wsum if wsum > 0.0 else Vector3.ZERO)
	var p := skeleton.global_transform * (skeleton.get_bone_global_pose(_head_bone) * _sway_local)
	if not _sway_valid or p.distance_to(_sway_p) > 1.0:
		_sway_p = p
		_sway_pv = Vector3.ZERO
		_sway_valid = true
		_sway_x = Vector3.ZERO
		_sway_v = Vector3.ZERO
		return
	var vel := (p - _sway_p) / delta
	var acc := ((vel - _sway_pv) / delta).limit_length(80.0)
	_sway_p = p
	_sway_pv = vel
	var steps := clampi(ceili(delta / SWAY_STEP), 1, 8)
	for i in steps:
		var r := Elastic.spring_step(_sway_x, _sway_v, acc, SWAY_K, SWAY_C, delta / steps)
		_sway_x = r[0]
		_sway_v = r[1]
		if _sway_x.length() > SWAY_MAX:
			_sway_x = _sway_x.limit_length(SWAY_MAX)
			_sway_v = Vector3.ZERO
	if _sway_x.length() < 1e-4 and _sway_v.length() < 1e-3:
		_sway_x = Vector3.ZERO
		_sway_v = Vector3.ZERO
	if _sway_x == Vector3.ZERO and _sway_zero:
		return
	_sway_zero = _sway_x == Vector3.ZERO
	var local := body_mi.global_basis.inverse() * _sway_x
	for m in hair_mats:
		m.set_shader_parameter("hair_sway", local)


func _reset_sway() -> void:
	_sway_x = Vector3.ZERO
	_sway_v = Vector3.ZERO
	_sway_valid = false
	if _sway_zero:
		return
	_sway_zero = true
	for m in hair_mats:
		m.set_shader_parameter("hair_sway", Vector3.ZERO)


## Rintojen, vatsan ja pakaroiden hyllyntä: jokaisella osalla oma jousi (Elastic.JIGGLE: taajuus, vaimennus, suunta,
## suurin siirto), jota ajaa osan luun pisteen kiihtyvyys; voimakkuus vartalosta (Elastic.jiggle_gain). Siirto pehmeästi
## rajattu (tanh) ja uniformeina jiggle_*, paino verkon CUSTOM1:ssä. Vain lähellä (LOD-väli 1); kauempana nollataan.
const JIGGLE_STEP := 1.0 / 240.0


func _update_jiggle(delta: float) -> void:
	if body_mat == null or delta <= 0.0:
		return
	if _lod_interval() > 1:
		_reset_jiggle()
		return
	if _jig.is_empty():
		for part in Elastic.JIGGLE:
			var g := Elastic.jiggle_gain(part, body_shape)
			var bi := skeleton.find_bone(Elastic.JIGGLE[part].bone)
			if g > 0.0 and bi >= 0:
				var local: Vector3 = skeleton.get_bone_global_rest(bi).affine_inverse() * (Elastic.JIGGLE[part].center as Vector3)
				_jig.append([part, bi, local, g, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	var pts := []
	var jump := not _jig_valid
	for j in _jig:
		var p: Vector3 = skeleton.global_transform * (skeleton.get_bone_global_pose(j[1]) * (j[2] as Vector3))
		pts.append(p)
		jump = jump or p.distance_to(j[6]) > 1.0
	if jump:  # ensimmäinen ruutu tai teleportti: jousi lepoon
		for i in _jig.size():
			_jig[i][4] = Vector3.ZERO
			_jig[i][5] = Vector3.ZERO
			_jig[i][6] = pts[i]
			_jig[i][7] = Vector3.ZERO
		_jig_valid = true
		return
	var to_mesh := body_mi.global_basis.inverse()
	var any := false
	var steps := clampi(ceili(delta / JIGGLE_STEP), 1, 16)
	for i in _jig.size():
		var j: Array = _jig[i]
		var prm: Dictionary = Elastic.JIGGLE[j[0]]
		var vel: Vector3 = (pts[i] - j[6]) / delta
		var acc: Vector3 = ((vel - j[7]) / delta).limit_length(150.0)
		j[6] = pts[i]
		j[7] = vel
		var side: float = prm.side
		acc = Vector3(acc.x * side, acc.y, acc.z * side)  # pääosin pystysuunta
		var k := pow(TAU * float(prm.hz), 2.0)
		var c := 2.0 * float(prm.zeta) * sqrt(k)
		var m: float = float(prm.max) * float(j[3])
		var x: Vector3 = j[4]
		var v: Vector3 = j[5]
		for s in steps:
			var r := Elastic.spring_step(x, v, acc, k, c, delta / steps)
			x = r[0]
			v = r[1]
		if x.length() > 3.0 * m:
			x = x.limit_length(3.0 * m)
			v = Vector3.ZERO
		if x.length() < 1e-4 and v.length() < 1e-3:
			x = Vector3.ZERO
			v = Vector3.ZERO
		j[4] = x
		j[5] = v
		any = any or x != Vector3.ZERO
		var xl := x.length()
		var shown := x * (m * tanh(xl / m) / xl) if xl > 0.0 else Vector3.ZERO  # pehmeä raja: suurin siirto m
		if x != Vector3.ZERO or not _jig_zero:
			body_mat.set_shader_parameter("jiggle_" + j[0], to_mesh * shown)
	_jig_zero = not any


## Hyllyntä lepoon (LOD, teleportti, asennon vaihto): uniformit nollaan ja jousi alkaa alusta.
func _reset_jiggle() -> void:
	_jig_valid = false
	if _jig_zero:
		return
	_jig_zero = true
	for part in Elastic.JIGGLE:
		body_mat.set_shader_parameter("jiggle_" + part, Vector3.ZERO)


func _tint(mi: MeshInstance3D, color: Color) -> void:
	var m := mi.mesh.surface_get_material(0)
	if m is StandardMaterial3D:
		var d: StandardMaterial3D = m.duplicate()
		d.albedo_color = color * 1.6
		mi.material_override = d


## Animaatiot kerran: vain kierrot (ja lantion paikka), jotta mittasuhteet eivät vääristy.
## Godot poistaa tuonnissa nimistä _Loop-päätteen ja asettaa silmukan itse (esim. "Walk").
static func _library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	var scene: Node = load(ANIM_FILE).instantiate()
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer")[0]
	var src := ap.get_animation_library("")
	_lib = AnimationLibrary.new()
	for n in src.get_animation_list():
		var a: Animation = src.get_animation(n).duplicate(true)
		for t in range(a.get_track_count() - 1, -1, -1):
			var ty := a.track_get_type(t)
			var path := str(a.track_get_path(t))
			if ty == Animation.TYPE_SCALE_3D or (ty == Animation.TYPE_POSITION_3D and not path.ends_with(":pelvis")):
				a.remove_track(t)
		_lib.add_animation(n, a)
	scene.free()
	return _lib


## Vartalomesh, jonka verteksiväri kertoo vaateluokan (painavimman luun mukaan).
static func _clothed_mesh(kind: String, mesh: Mesh, skin: Skin, skel: Skeleton3D, stripes: bool,
		shape := {}) -> ArrayMesh:
	var key := "%s/%s/%s" % [kind, stripes, shape]
	var shaped := false
	for k in shape:
		shaped = shaped or absf(shape[k]) > 0.001
	var live: ArrayMesh = (_meshes[key] as WeakRef).get_ref() if _meshes.has(key) else null
	if live != null:
		return live
	var cache := _cache_path(key)
	if FileAccess.file_exists(cache):
		var cached := ResourceLoader.load(cache, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if cached != null and cached.get_surface_count() == mesh.get_surface_count():
			_meshes[key] = weakref(cached)
			return cached
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var fmt: int = (mesh as ArrayMesh).surface_get_format(s)
		var src_count: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()  # LOD-indeksien muoto
		if kind == "female" and shape.get("bust", 0.0) > 1.4:
			_subdivide_bust(arr, shape.bust)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / verts.size()
		var cols := PackedColorArray()
		cols.resize(verts.size())
		var vbone := PackedStringArray()
		vbone.resize(verts.size())
		for v in verts.size():
			var best := 0
			for k in per:
				if weights[v * per + k] > weights[v * per + best]:
					best = k
			var bind := bones[v * per + best]
			var bone := str(skin.get_bind_name(bind))
			if bone == "":
				bone = skel.get_bone_name(skin.get_bind_bone(bind))
			vbone[v] = bone
			var cat := _category(bone)
			if cat == 2 and shape.get("belly", 0.0) > 0.0 and verts[v].y > 0.88:
				# Maha roikkuu vyön yli: pullistuva osa on paitaa, ei housuja.
				if _shape_offset(verts[v], {"belly": shape.belly}).length() > 0.012:
					cat = 1
			var stripe := 0.0
			if stripes:
				var p := verts[v]
				var nrm := norms[v]
				if bone.begins_with("thigh") or bone.begins_with("calf"):
					stripe = 1.0 if absf(nrm.x) > 0.9 and signf(nrm.x) == signf(p.x) else 0.0
				elif bone.begins_with("upperarm") or bone.begins_with("lowerarm"):
					stripe = 1.0 if nrm.y > 0.9 else 0.0
			# B = etupuoli (vetoketju vain edessä).
			# A = lepoasennon normaalin x (tuulipuvun terävät sivuraidat).
			cols[v] = Color(cat / 4.0, stripe, 1.0 if verts[v].z > 0.0 else 0.0, 0.5 + 0.5 * norms[v].x)
		arr[Mesh.ARRAY_COLOR] = cols
		# UV2 = lepoasennon paikka (x, y): tuulipuvun kuviot pikselintarkasti, vartalon muodosta riippumatta.
		var rest := PackedVector2Array()
		rest.resize(verts.size())
		for v in verts.size():
			rest[v] = Vector2(verts[v].x, verts[v].y)
		arr[Mesh.ARRAY_TEX_UV2] = rest
		if kind == "female":
			_chest_weights(arr, skin, skel, per)
		# CUSTOM0 = lepoasennon syvyys z ja normaalin y ja z (UV2:n ja värin A:n lisäksi): lappubikinit lasketaan
		# vartalon pinnalla (kulma vartalon ympäri, pinnan suunta), ks. character.gdshader bikini_sd.
		var joints := {}
		for i in skin.get_bind_count():
			var jn := str(skin.get_bind_name(i))
			if jn == "":
				jn = skel.get_bone_name(skin.get_bind_bone(i))
			joints[jn] = skin.get_bind_pose(i).affine_inverse().origin
		var rest3 := PackedFloat32Array()
		rest3.resize(verts.size() * 4)
		# CUSTOM1 = hyllyntäpainot (Elastic.jiggle_weights): r rinta, g vatsa, b pakara ja reiden yläosa.
		var jig := PackedByteArray()
		jig.resize(verts.size() * 4)
		for v in verts.size():
			rest3[v * 4] = verts[v].z
			rest3[v * 4 + 1] = norms[v].y
			rest3[v * 4 + 2] = norms[v].z
			var bw: float = _bust(verts[v], shape.get("bust", 0.0)).weight if kind == "female" else 0.0
			# w = painumaraja (Elastic): pehmeä osa painuu kontaktissa korkeintaan tämän verran, luinen ei lainkaan.
			rest3[v * 4 + 3] = Elastic.limit(vbone[v], verts[v], norms[v], shape, joints, bw)
			var jw := Elastic.jiggle_weights(verts[v], bw)
			jig[v * 4] = roundi(jw.x * 255.0)
			jig[v * 4 + 1] = roundi(jw.y * 255.0)
			jig[v * 4 + 2] = roundi(jw.z * 255.0)
		if shaped:
			_reshape(arr, shape)
		for c in [Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[c] = null  # muita lisäkanavia ei tarvita
		arr[Mesh.ARRAY_CUSTOM0] = rest3
		arr[Mesh.ARRAY_CUSTOM1] = jig
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], _source_lods(kind, mesh, s, src_count),
			(fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
			| (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
	_meshes[key] = weakref(out)  # heikko: Vaalan hahmojen vartalot vapautuvat Vaalan mukana (levyvälimuisti lataa)
	DirAccess.make_dir_recursive_absolute(MESH_CACHE)
	ResourceSaver.save(out, cache)
	return out


## Naismallin rinnat: alaosa seuraa mallissa nikamaa spine_02 ja yläosa spine_03, ja raja kulkee rintojen poikki, joten
## asennon selkä puristaa rintoihin poimun. Rintojen alue sidotaan rintakehään (spine_03) niin, että painojen vaihto
## tapahtuu rinnan alapuolella tasaisella kylkikaarella (y 1,17–1,25).
static func _chest_weights(arr: Array, skin: Skin, skel: Skeleton3D, per: int) -> void:
	var chest := -1
	for b in skin.get_bind_count():
		var bn := str(skin.get_bind_name(b))
		if bn == "":
			bn = skel.get_bone_name(skin.get_bind_bone(b))
		if bn == "spine_03":
			chest = b
	if chest < 0:
		return
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	for v in verts.size():
		var p := verts[v]
		var t := smoothstep(1.17, 1.25, p.y) * (1.0 - smoothstep(1.4, 1.46, p.y)) * smoothstep(-0.02, 0.05, p.z)
		t *= 1.0 - smoothstep(0.15, 0.2, absf(p.x))
		if t <= 0.0:
			continue
		var acc := {}
		for k in per:
			var wk := weights[v * per + k] * (1.0 - t)
			if wk > 0.0:
				acc[bones[v * per + k]] = acc.get(bones[v * per + k], 0.0) + wk
		acc[chest] = acc.get(chest, 0.0) + t
		var keys: Array = acc.keys()
		keys.sort_custom(func(x, y): return acc[x] > acc[y])
		var total := 0.0
		for k in mini(per, keys.size()):
			total += acc[keys[k]]
		for k in per:
			bones[v * per + k] = keys[k] if k < keys.size() else 0
			weights[v * per + k] = acc[keys[k]] / total if k < keys.size() else 0.0
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = weights


## Vaatemeshien levyvälimuisti: laskenta (vartalon muoto verteksi kerrallaan GDScriptillä) vei käynnistyksestä 2,7 s
## 36 vartalolle. Tiedostonimessä on tämän skriptin lähdekoodin tiiviste (muutettu laskenta = uudet tiedostot) ja
## CACHE_VERSION: nosta sitä, jos vartalon laskenta muuttuu vientipaketissa, jossa lähdekoodia ei ole luettavissa.
const MESH_CACHE := "user://hahmot"
const CACHE_VERSION := 13
static var _cache_tag := ""


static func _cache_path(key: String) -> String:
	if _cache_tag == "":
		var src := FileAccess.get_file_as_string("res://scripts/character.gd")
		src += FileAccess.get_file_as_string("res://scripts/elastic.gd")  # rajat tulevat sieltä
		_cache_tag = "v%d_%x" % [CACHE_VERSION, src.hash() & 0xffffffff]
		# Vanhan version tiedostot pois.
		if DirAccess.dir_exists_absolute(MESH_CACHE):
			for f in DirAccess.get_files_at(MESH_CACHE):
				if not f.begins_with(_cache_tag + "_"):
					DirAccess.remove_absolute(MESH_CACHE.path_join(f))
	return MESH_CACHE.path_join("%s_%x.res" % [_cache_tag, key.hash() & 0xffffffff])


## Tuonnissa luodut LOD-tasot (generate_lods) alkuperäisestä pinnasta: vaatemesh pitää verteksien järjestyksen,
## joten samat indeksilistat kelpaavat. Ilman niitä jokainen hahmo piirtyi täysin kolmioin joka etäisyydellä ja
## jokaiseen varjokaskadiin (lavalla 2,6 M kolmiota).
## Topologia on sama kaikilla saman mallin vartaloilla, joten indeksit puretaan kerran mallia ja pintaa kohden.
static var _lods := {}


static func _source_lods(kind: String, mesh: Mesh, surface: int, vert_count: int) -> Dictionary:
	var key := "%s/%d" % [kind, surface]
	if _lods.has(key):
		return _lods[key]
	var out := {}
	var sd: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
	for lod in sd.get("lods", []):
		var data: PackedByteArray = lod.index_data
		var idx := PackedInt32Array()
		if vert_count <= 65535:
			idx.resize(data.size() / 2)
			for i in idx.size():
				idx[i] = data.decode_u16(i * 2)
		else:
			idx = data.to_int32_array()
		out[float(lod.edge_length)] = idx
	_lods[key] = out
	return out


## Muokkaa vartaloa lepoasennossa (T-asento, metrit, kasvot +Z). Pisteet siirtyvät pehmeästi,
## ja normaalit/tangentit käännetään siirtymän Jacobin matriisilla, jotta valaistus pysyy oikeana.
static func _reshape(arr: Array, shape: Dictionary) -> void:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var tans: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT] if arr[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var h := 0.004
	for v in verts.size():
		var p := verts[v]
		var d := _shape_offset(p, shape)
		if d.length_squared() < 1e-10:
			continue
		# Jacobin matriisi eteenpäin erotuksin (d on jo laskettu): 4 _shape_offset-kutsua 7:n sijaan.
		var jx := (_shape_offset(p + Vector3(h, 0, 0), shape) - d) / h
		var jy := (_shape_offset(p + Vector3(0, h, 0), shape) - d) / h
		var jz := (_shape_offset(p + Vector3(0, 0, h), shape) - d) / h
		var m := Basis(Vector3(1, 0, 0) + jx, Vector3(0, 1, 0) + jy, Vector3(0, 0, 1) + jz)
		verts[v] = p + d
		if m.determinant() < 0.02:
			# Lähes litistyvä kohta: alkuperäinen normaali, paitsi rinnan pinnalla ellipsoidin normaali.
			var bu0: float = shape.get("bust", 0.0)
			if bu0 > 0.0:
				var b0 := _bust(p, bu0)
				if b0.weight > 0.0:
					norms[v] = norms[v].lerp(b0.normal, b0.weight).normalized()
			continue
		norms[v] = (m.inverse().transposed() * norms[v]).normalized()
		var bu: float = shape.get("bust", 0.0)
		if bu > 0.0:
			var b := _bust(p, bu)
			if b.weight > 0.0:
				norms[v] = norms[v].lerp(b.normal, b.weight).normalized()
		if tans.size() >= (v + 1) * 4:
			var t := (m * Vector3(tans[v * 4], tans[v * 4 + 1], tans[v * 4 + 2])).normalized()
			tans[v * 4] = t.x
			tans[v * 4 + 1] = t.y
			tans[v * 4 + 2] = t.z
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	if tans.size() > 0:
		arr[Mesh.ARRAY_TANGENT] = tans


## Isot rinnat (bust > 1,4): pohjamallin harva verkko tihennetään rinnan alueella ennen muotoilua, muuten iso
## ellipsoidi näkyy särmikkäänä ja lappubikinien reuna porrastuu. Kolmiot, joiden jokin kärki siirtyy rintamuodossa,
## jaetaan keskipisteistä neljään (kahdesti); naapurikolmiot jaetaan jaettujen särmien mukaan, jottei saumaan jää rakoa.
## Uusien pisteiden attribuutit ovat särmän päiden keskiarvoja (luupainoista vahvimmat).
static func _subdivide_bust(arr: Array, bu: float) -> void:
	for _pass in 2:
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var moved := PackedByteArray()
		moved.resize(verts.size())
		for v in verts.size():
			moved[v] = 1 if _bust(verts[v], bu).offset.length() > 0.002 else 0
		var mid := {}  # särmä (pienempi, suurempi indeksi) -> uuden pisteen indeksi
		var pairs := []
		for t in range(0, idx.size(), 3):
			if moved[idx[t]] + moved[idx[t + 1]] + moved[idx[t + 2]] == 0:
				continue
			for e in 3:
				var a := idx[t + e]
				var b := idx[t + (e + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not mid.has(key):
					mid[key] = verts.size() + pairs.size()
					pairs.append(key)
		if pairs.is_empty():
			return
		_append_midpoints(arr, pairs)
		var out := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var c := [idx[t], idx[t + 1], idx[t + 2]]
			var m := []
			var n := 0
			for e in 3:
				var key := Vector2i(mini(c[e], c[(e + 1) % 3]), maxi(c[e], c[(e + 1) % 3]))
				m.append(mid.get(key, -1))
				n += 1 if mid.has(key) else 0
			if n == 0:
				out.append_array(PackedInt32Array(c))
			elif n == 3:
				out.append_array(PackedInt32Array([c[0], m[0], m[2], m[0], c[1], m[1], m[2], m[1], c[2], m[0], m[1], m[2]]))
			else:
				# Kierretään niin, että ensimmäinen jaettu särmä on c0 -> c1 (kiertosuunta säilyy).
				var r := 0
				while m[r] < 0:
					r += 1
				var c0: int = c[r]
				var c1: int = c[(r + 1) % 3]
				var c2: int = c[(r + 2) % 3]
				var m0: int = m[r]
				var m1: int = m[(r + 1) % 3]
				var m2: int = m[(r + 2) % 3]
				if n == 1:
					out.append_array(PackedInt32Array([c0, m0, c2, m0, c1, c2]))
				elif m1 >= 0:
					out.append_array(PackedInt32Array([c0, m0, c2, m0, c1, m1, m0, m1, c2]))
				else:  # jaetut särmät c2 -> c0 ja c0 -> c1
					out.append_array(PackedInt32Array([c0, m0, m2, m0, c1, c2, m0, c2, m2]))
		arr[Mesh.ARRAY_INDEX] = out


static func _append_midpoints(arr: Array, pairs: Array) -> void:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n0 := verts.size()
	var per := 0
	if arr[Mesh.ARRAY_BONES] != null:
		per = (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() / n0
	for ai in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR, Mesh.ARRAY_TANGENT]:
		if arr[ai] == null:
			continue
		var a: Variant = arr[ai]
		var w := 4 if ai == Mesh.ARRAY_TANGENT else 1
		for pr: Vector2i in pairs:
			for k in w:
				if ai == Mesh.ARRAY_TANGENT:
					a.append((a[pr.x * 4 + k] + a[pr.y * 4 + k]) * 0.5)
				elif ai == Mesh.ARRAY_NORMAL:
					a.append(((a[pr.x] + a[pr.y]) as Vector3).normalized())
				else:
					a.append((a[pr.x] + a[pr.y]) * 0.5)
		arr[ai] = a
	if per > 0:
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for pr: Vector2i in pairs:
			var sum := {}
			for v in [pr.x, pr.y]:
				for k in per:
					var wk: float = wts[v * per + k]
					if wk > 0.0:
						sum[bones[v * per + k]] = sum.get(bones[v * per + k], 0.0) + wk * 0.5
			var keys := sum.keys()
			keys.sort_custom(func(x, y): return sum[x] > sum[y])
			var tot := 0.0
			for k in mini(per, keys.size()):
				tot += sum[keys[k]]
			for k in per:
				bones.append(keys[k] if k < keys.size() else 0)
				wts.append(sum[keys[k]] / tot if k < keys.size() else 0.0)
		arr[Mesh.ARRAY_BONES] = bones
		arr[Mesh.ARRAY_WEIGHTS] = wts
	for ai in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		if arr[ai] != null:
			arr[ai] = null  # _clothed_mesh laskee omat kanavansa uudelleen


## Rintamus (naismalli): pohjamallin pieni rinta ja sen alapuolinen poimu tasoitetaan ensin sileäksi rintakehäksi
## (muuten poimun ääriviiva näkyy uuden muodon läpi; vain rinnan alaosassa, yläpuolella tasoitus painaisi ryppyyn), ja sen jälkeen kummankin rinnan pinta pullistetaan ellipsoidin
## pinnalle pehmeällä maksimilla kuten maha: pyöreä ja täyteläinen muoto. Keskilinjalla puolet sulautetaan (paino
## sivun mukaan), jolloin väliin muodostuu sileä uurre. Rintakehän etupinta mitattu pohjamallista (z ≈ 0,105 rintojen
## alla, kaartuu taakse ylöspäin ja sivuille). Palauttaa siirtymän sekä ellipsoidin normaalin ja sen painon:
## tasoitus litistää pinnan, joten Jacobin muunnos ei anna sille käyttökelpoista normaalia (_reshape).
static func _bust(p: Vector3, bu: float) -> Dictionary:
	var out := {"offset": Vector3.ZERO, "normal": Vector3.ZERO, "weight": 0.0}
	var ax := absf(p.x)
	var flat_w := smoothstep(1.16, 1.22, p.y) * (1.0 - smoothstep(1.33, 1.38, p.y)) * (1.0 - smoothstep(0.14, 0.18, ax)) \
		* smoothstep(0.0, 0.04, p.z)
	var chest := 0.108 - 3.5 * pow(maxf(0.0, p.y - 1.3), 2.0) - 12.0 * pow(maxf(0.0, ax - 0.06), 2.0)
	var pf := p
	pf.z = lerpf(p.z, minf(p.z, chest), flat_w)
	for sx in [-1.0, 1.0]:
		var side := smoothstep(-0.025, 0.025, sx * p.x)
		if side <= 0.0:
			continue
		# Yli 1,4:n osa (e) kasvattaa ulkonemaa eteen eikä leveyttä: hoikalla isot rinnat (DD) ovat rintakehän levyiset
		# ja pyöreät, eivät leviä kylkien yli. Keskipiste siirtyy hieman eteen ja alas (paino), alareunan rajaus mukana.
		var e := maxf(bu - 1.4, 0.0)
		var b1 := bu - e
		var c := Vector3(sx * (0.085 - 0.006 * e), 1.295, 0.015 + 0.025 * e)
		var r := Vector3(0.075 + 0.012 * b1 - 0.008 * e, 0.068 + 0.01 * b1 + 0.002 * e, 0.06 + 0.045 * bu)
		var q := (pf - c) / r
		var ln := q.length()
		if ln > 0.001 and ln < 1.4:
			var k := 0.14  # pehmeä siirtymä ellipsoidin pinnalta ympäröivään ihoon (terävämpi teki reunaan piikkejä)
			var target := ln + 0.8 * k * log(1.0 + exp((1.0 - ln) / k))
			# Etupuoli vaakasuunnassa (ei pystykomponenttia): rinnan yläreunalla q osoittaa ylös, ja pelkkä q.z / ln
			# puolittaisi pullistuksen ja painaisi yläreunaan rypyn.
			var face := smoothstep(-0.3, 0.3, q.z / maxf(Vector2(q.x, q.z).length(), 0.001))
			var ymask := smoothstep(1.16, 1.22, p.y) * (1.0 - smoothstep(1.42, 1.48, p.y))
			var inflated := c + q * (target / ln) * r
			out.offset += (inflated - p) * face * ymask * side
			# Pinnalle päätyvä kohta (ln < 1): normaali ellipsoidin gradientista.
			var on_surf := face * ymask * side * (1.0 - smoothstep(0.9, 1.3, ln))
			if on_surf > 0.0:
				out.normal += (q / r).normalized() * on_surf
				out.weight += on_surf
	if out.weight > 0.0:
		out.normal = (out.normal as Vector3).normalized()
		out.weight = minf(out.weight, 1.0)
	return out


static func _shape_offset(p: Vector3, shape: Dictionary) -> Vector3:
	var off := Vector3.ZERO
	var ax := absf(p.x)
	var torso := (1.0 - smoothstep(0.2, 0.3, ax)) * smoothstep(0.85, 0.95, p.y) * (1.0 - smoothstep(1.5, 1.6, p.y))
	var belly: float = shape.get("belly", 0.0)
	if belly > 0.0:
		# Pyöreä ja pullea maha: vatsan pinta pullistetaan ellipsoidin pinnalle (pehmeä maksimi),
		# edestä ja sivuilta täysin, selästä ei lainkaan. Painopiste hieman alhaalla: maha roikkuu.
		var c := Vector3(0.0, 1.16 - 0.02 * belly, -0.02)
		var r := Vector3(0.16 + 0.08 * belly, 0.2 + 0.05 * belly, 0.13 + 0.17 * belly)
		var q := (p - c) / r
		var ln := q.length()
		if ln > 0.001 and ln < 1.3:
			# Pehmeä, aidosti kasvava kuvaus (kulmakerroin 0.2..1), ettei pinta litisty eikä käänny.
			var k := 0.1
			var target := ln + 0.8 * k * log(1.0 + exp((1.0 - ln) / k))
			var face := smoothstep(-0.7, 0.1, q.z / ln)
			var ymask := smoothstep(0.92, 1.03, p.y) * (1.0 - smoothstep(1.4, 1.5, p.y))
			var wgt := face * ymask * (1.0 - smoothstep(0.24, 0.32, ax))
			var inflated := c + q * (target / ln) * r
			off += (inflated - p) * wgt
	var bulk: float = shape.get("bulk", 0.0)
	if bulk != 0.0:
		off.x += p.x * 0.2 * bulk * torso
		off.z += (p.z + 0.02) * 0.16 * bulk * torso
		var arm := smoothstep(0.2, 0.3, ax) * smoothstep(1.25, 1.35, p.y)
		var arm_in := 1.0 - smoothstep(0.52, 0.64, ax)  # ranteet ja kädet ennallaan
		off.y += (p.y - 1.45) * 0.4 * bulk * arm * arm_in
		off.z += (p.z + 0.06) * 0.4 * bulk * arm * arm_in
		var leg := (1.0 - smoothstep(0.88, 0.98, p.y)) * smoothstep(0.12, 0.22, p.y) * smoothstep(0.0, 0.06, ax)
		var cx := signf(p.x) * 0.11
		off.x += (p.x - cx) * 0.24 * bulk * leg
		off.z += (p.z + 0.04) * 0.24 * bulk * leg
	var mu: float = shape.get("muscle", 0.0)
	if mu < 0.0:
		var m := -mu
		var torso_x := 1.0 - smoothstep(0.24, 0.32, ax)
		# Olkapäät (hartialihas): käsivarren tyvi kohti käsivarren akselia ja sisemmäs.
		var delt := exp(-pow((ax - 0.2) / 0.1, 2.0)) * exp(-pow((p.y - 1.48) / 0.11, 2.0))
		off.y += (1.45 - p.y) * 0.75 * m * delt
		off.z += (-0.06 - p.z) * 0.55 * m * delt
		off.x -= signf(p.x) * 0.045 * m * delt
		# Niskan ja hartioiden väliset epäkäslihakset alemmas.
		var trap := smoothstep(0.04, 0.1, ax) * (1.0 - smoothstep(0.16, 0.24, ax)) * exp(-pow((p.y - 1.54) / 0.06, 2.0))
		off.y -= 0.035 * m * trap
		# Rintalihakset litteämmiksi.
		var pec := smoothstep(0.02, 0.08, p.z) * exp(-pow((p.y - 1.36) / 0.08, 2.0)) * torso_x
		off.z -= (p.z - 0.02) * 0.6 * m * pec
		# Selkälihakset ja kyljet.
		var lat := exp(-pow((p.y - 1.3) / 0.13, 2.0)) * torso_x * smoothstep(0.06, 0.16, ax)
		off.x -= p.x * 0.14 * m * lat
		off.z -= (p.z + 0.02) * 0.2 * m * lat * (1.0 - smoothstep(-0.05, 0.02, p.z))
		# Käsivarret ohuemmiksi (ranteet ja kädet ennallaan).
		var arm := smoothstep(0.2, 0.3, ax) * smoothstep(1.3, 1.36, p.y) * (1.0 - smoothstep(0.52, 0.64, ax))
		off.y += (1.45 - p.y) * 0.45 * m * arm
		off.z += (-0.065 - p.z) * 0.45 * m * arm
		# Yläselkä (takaolkapäät ja lapojen seutu) litteämmäksi: ei kyttyrää.
		var upper_back := (1.0 - smoothstep(-0.08, -0.03, p.z)) * exp(-pow((p.y - 1.4) / 0.12, 2.0)) * (1.0 - smoothstep(0.26, 0.34, ax))
		off.z += (-0.06 - p.z) * 0.5 * m * upper_back
		# Pakarat ja reidet.
		var glute := (1.0 - smoothstep(-0.1, -0.04, p.z)) * exp(-pow((p.y - 0.9) / 0.1, 2.0)) * (1.0 - smoothstep(0.2, 0.26, ax))
		off.z += (-0.07 - p.z) * 0.4 * m * glute
		var leg := (1.0 - smoothstep(0.86, 0.96, p.y)) * smoothstep(0.14, 0.24, p.y) * smoothstep(0.0, 0.06, ax)
		var lcx := signf(p.x) * 0.11
		off.x += (lcx - p.x) * 0.16 * m * leg
		off.z += (-0.04 - p.z) * 0.16 * m * leg
	var cu: float = shape.get("curves", 0.0)
	if cu > 0.0:
		# Tiimalasi: kapea vyötärö, leveämmät lantiot ja pyöreämmät pakarat, hieman täyteläisempi rintamus.
		var tx := 1.0 - smoothstep(0.22, 0.3, ax)
		var waist := exp(-pow((p.y - 1.1) / 0.07, 2.0)) * tx
		off.x -= p.x * 0.16 * cu * waist
		off.z -= (p.z + 0.01) * 0.1 * cu * waist
		var hips := exp(-pow((p.y - 0.93) / 0.08, 2.0)) * (1.0 - smoothstep(0.26, 0.34, ax))
		off.x += p.x * 0.16 * cu * hips
		var seat := (1.0 - smoothstep(-0.08, -0.02, p.z)) * exp(-pow((p.y - 0.9) / 0.08, 2.0)) * (1.0 - smoothstep(0.2, 0.26, ax))
		off.z -= 0.03 * cu * seat
		var bust := smoothstep(0.0, 0.06, p.z) * exp(-pow((p.y - 1.34) / 0.07, 2.0)) * (1.0 - smoothstep(0.16, 0.22, ax))
		off.z += 0.025 * cu * bust
	var bu: float = shape.get("bust", 0.0)
	if bu > 0.0:
		# Rintamus (naismalli): ks. _bust.
		off += _bust(p, bu).offset
	var sh: float = shape.get("shoulders", 0.0)
	if sh != 0.0:
		var band := exp(-pow((p.y - 1.44) / 0.1, 2.0))
		off.x += p.x * 0.13 * sh * band * (1.0 - smoothstep(0.25, 0.35, ax))
		off.x += signf(p.x) * 0.035 * sh * smoothstep(0.25, 0.35, ax) * smoothstep(1.3, 1.38, p.y)
		off.z += (p.z + 0.02) * 0.1 * sh * band * (1.0 - smoothstep(0.25, 0.35, ax))
		# Leveät selkälihakset (V-muoto) kylkien yläosassa.
		var lats := exp(-pow((p.y - 1.3) / 0.12, 2.0)) * (1.0 - smoothstep(0.24, 0.32, ax)) * smoothstep(0.06, 0.16, ax)
		off.x += p.x * 0.2 * sh * lats
		off.z += (p.z + 0.02) * 0.15 * sh * lats * (1.0 - smoothstep(-0.05, 0.02, p.z))
	return off


static func _category(bone: String) -> int:
	if bone.begins_with("spine") or bone.begins_with("clavicle") or bone.begins_with("upperarm") or bone.begins_with("lowerarm"):
		return 1
	if bone == "pelvis" or bone.begins_with("thigh") or bone.begins_with("calf") or bone == "root":
		return 2
	if bone.begins_with("foot") or bone.begins_with("ball"):
		return 3
	return 0
