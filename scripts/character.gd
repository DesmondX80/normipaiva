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
const REST_HEIGHT := 1.8
const DEFAULT_MUSCLE := -0.85  # pohjamalli on superhero: tavallisilla ihmisillä lihakset pienemmiksi

static var _lib: AnimationLibrary
static var _meshes := {}

var skeleton: Skeleton3D
var anim: AnimationPlayer
var model: Node3D
var body_mat: ShaderMaterial

var _overrides := {}  # luu -> [akseli hahmon avaruudessa, kulma]
var _ik := {}  # nimi -> [luu a, luu b, luu c, kohde, polvi/kyynärpää-suunta] (hahmon avaruudessa)
var _current := ""


## look: model, shirt, pants, shoes, skin, hair (tiedoston nimi ilman päätettä tai ""), hair_color,
## beard (bool), stripes (bool), height (m), shine (0..1).
## Vartalo: belly (0..1 kaljamaha), bulk (-1..1 hoikka..tukeva), shoulders (-1..1 kapeat..leveät hartiat),
## muscle (-1..0 lihakset pienemmiksi; oletus DEFAULT_MUSCLE).
func setup(look: Dictionary) -> void:
	var kind: String = look.get("model", "male")
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
	var shape := {"belly": float(look.get("belly", 0.0)), "bulk": float(look.get("bulk", 0.0)),
		"shoulders": float(look.get("shoulders", 0.0)), "muscle": float(look.get("muscle", DEFAULT_MUSCLE)),
		"curves": float(look.get("curves", 0.0))}
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
	for k in ["shorts_y", "crop_y", "sleeve_x", "tube_y", "denim", "bare_skin"]:
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

	var hair_color: Color = look.get("hair_color", Color(0.25, 0.18, 0.12))
	for mi in skeleton.get_children():
		if mi is MeshInstance3D and mi.name == "Eyebrows":
			_tint(mi, hair_color)
	var hair: String = look.get("hair", "Hair_SimpleParted")
	if hair != "":
		_attach_hair(HAIR_DIR + hair + ".gltf", hair_color)
	if look.get("beard", false):
		_attach_hair(HAIR_DIR + "Hair_Beard.gltf", hair_color)

	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.add_animation_library("", _library())
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	play("Idle", 0.0)
	anim.seek(randf() * 2.0, true)


func play(anim_name: String, blend := 0.2, speed := 1.0) -> void:
	if _current == anim_name:
		anim.speed_scale = speed
		return
	_current = anim_name
	anim.speed_scale = speed
	anim.play(anim_name, blend)


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
func set_ik(chain: String, a: String, b: String, c: String, target: Vector3, pole: Vector3) -> void:
	_ik[chain] = [a, b, c, target, pole]


func clear_ik() -> void:
	_ik.clear()


## Luun paikka tämän solmun avaruudessa.
func bone_position(bone: String) -> Vector3:
	var p := skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
	return (model.transform * skeleton.transform * p)


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


func _process(delta: float) -> void:
	if anim == null:
		return
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

func _attach_hair(path: String, color: Color) -> void:
	var scene: Node = load(path).instantiate()
	for mi in scene.find_children("*", "MeshInstance3D"):
		mi.owner = null
		mi.get_parent().remove_child(mi)
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		_tint(mi, color)
	scene.free()


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
	if _meshes.has(key):
		return _meshes[key]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var fmt: int = (mesh as ArrayMesh).surface_get_format(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / verts.size()
		var cols := PackedColorArray()
		cols.resize(verts.size())
		for v in verts.size():
			var best := 0
			for k in per:
				if weights[v * per + k] > weights[v * per + best]:
					best = k
			var bind := bones[v * per + best]
			var bone := str(skin.get_bind_name(bind))
			if bone == "":
				bone = skel.get_bone_name(skin.get_bind_bone(bind))
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
		if shaped:
			_reshape(arr, shape)
		for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[c] = null  # lisäkanavia ei tarvita
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	_meshes[key] = out
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
		var jx := (_shape_offset(p + Vector3(h, 0, 0), shape) - _shape_offset(p - Vector3(h, 0, 0), shape)) / (2.0 * h)
		var jy := (_shape_offset(p + Vector3(0, h, 0), shape) - _shape_offset(p - Vector3(0, h, 0), shape)) / (2.0 * h)
		var jz := (_shape_offset(p + Vector3(0, 0, h), shape) - _shape_offset(p - Vector3(0, 0, h), shape)) / (2.0 * h)
		var m := Basis(Vector3(1, 0, 0) + jx, Vector3(0, 1, 0) + jy, Vector3(0, 0, 1) + jz)
		verts[v] = p + d
		if m.determinant() < 0.02:
			continue  # lähes litistyvä kohta: pidetään alkuperäinen normaali
		norms[v] = (m.inverse().transposed() * norms[v]).normalized()
		if tans.size() >= (v + 1) * 4:
			var t := (m * Vector3(tans[v * 4], tans[v * 4 + 1], tans[v * 4 + 2])).normalized()
			tans[v * 4] = t.x
			tans[v * 4 + 1] = t.y
			tans[v * 4 + 2] = t.z
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	if tans.size() > 0:
		arr[Mesh.ARRAY_TANGENT] = tans


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
