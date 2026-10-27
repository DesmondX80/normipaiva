extends Node3D
## Hahmo hahmoa vastaan (Contact.pair_fit, pair_contacts, overlap_pairs): halaus (päähahmo + Sinikka bikineissä), iskut Juntin
## vatsaan ja painiote Juntin kanssa. Joka ruutu pair_fit -> pair_contacts -> set_contacts -> overlap_pairs; tulostaa vaiheen
## pahimman kapseliparin (PARI, mm), kohteen raon pintaan (KOHDE), ranteen kulman (RANNE), suunnat (SUUNTA) ja painumat (PAINUMA).
## Raja 1 cm: yli -> "TESTI VIKA". Vaihe "vanha" (halaus vanhalla tavalla, kiinteät kohteet) todistaa mittarin (MITTARI).
## aja.sh tscn tools/testit/hahmot_kontakti.tscn [vanha|paini]   (vanha = halaus vanhalla tavalla mittarin alla -> VIKA-rivejä,
## paini = vain painivaihe)

const Pose := preload("res://scripts/pose.gd")
const Contact := preload("res://scripts/contact.gd")
const Asento := preload("res://tools/testit/asento.gd")
const Looks := preload("res://scripts/looks.gd")
const Elastic := preload("res://scripts/elastic.gd")
const B := preload("res://scripts/build.gd")

const RAJA := 0.01  # kapselien päällekkäisyys ja kohteen rako (m)
const DT := 1.0 / 30.0
const ISKU := 0.8  # iskun jakso (s)
const KULMA := deg_to_rad(60.0)  # halauksen kämmen selän keskeltä kylkeä kohti (Sinikka vyötäröllä)
const KULMA_YLA := deg_to_rad(40.0)  # päähahmon kämmenen normaali Sinikan hartian takana (selästä ylös)
const YLA := 0.35  # päähahmon kämmen olkanivelestä kaulaa kohti (osuus)
const TAKA := 0.02  # ja hartian yläpinnasta selkään päin (m)
const PAINI_LAHI := 0.52  # painissa rintakehien spine_03-luiden väli (m)
const PAINI_KYLKI := deg_to_rad(65.0)  # päähahmon kämmen Juntin kyljessä (edestä kylkeä kohti)
const PAINI_KYYNARVARSI := 0.4  # Juntin kämmen päähahmon kyynärvarren yläpinnalla (osuus kyynärpäästä)
const TORSO := ["pelvis", "spine_01", "spine_02", "spine_03"]

var out := "user://hahmot_kontakti"
var cam: Camera3D
var me: Node3D
var sinikka: Node3D
var juntti: Node3D
var prof := {}  # hahmo -> Contact.profile
var old_way := false  # argumentti vanha: halaus vanhalla tavalla mittarin alla
var worst := {}  # vaihe -> [a:kapseli, b:kapseli, m]
var pairs := {}  # vaihe -> {pari: suurin m}
var kohde := {}  # vaihe -> {ketju: suurin rako m}
var vikoja := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	old_way = "vanha" in args
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.88)
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(40, 0.1, 40)), Vector3(0, -0.05, 0), Color(0.86, 0.78, 0.55))
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	me = Looks.make(self, Looks.player())
	sinikka = Looks.make(self, Looks.sinikka_bikini())
	var jl: Dictionary = Looks.JUNTTI.duplicate()
	jl.shirt = Color(0.85, 0.35, 0.2)  # vaalea paita: musta ei näytä vatsan muotoa
	juntti = Looks.make(self, jl)
	for c in [me, sinikka, juntti]:
		c.restart("Idle", 0.0, 1.0)
	_run.call_deferred()


func _run() -> void:
	for i in 6:  # profiili paistetaan vasta 3 ruutua luonnin jälkeen
		await get_tree().process_frame
	for c in [me, sinikka, juntti]:
		prof[c] = Contact.profile(c, Pose.limb_points)
		print("PROFIILI %s mitattu %s käsi r %.3f pää r %.3f" % [c.profile_key, prof[c].measured,
			(prof[c].caps["hand_r"] as Array)[2], (prof[c].caps["Head"] as Array)[2]])
	await _yksin()
	if "paini" in OS.get_cmdline_user_args():
		await _phase("paini", juntti, 4.0, _paini, true)
	elif old_way:
		await _phase("hali", sinikka, 3.0, _vanha_hali, true)
	else:
		await _phase("hali", sinikka, 4.0, _hali, true)
		await _phase("iskut", juntti, ISKU * 3.0, _iskut, false)
		await _phase("paini", juntti, 4.0, _paini, true)
		await _phase("vanha", sinikka, 2.0, _vanha_hali, true)
		var w: Array = worst.get("vanha", ["-", "-", 0.0])
		print("MITTARI vanha halaus %s %s %.1f mm" % [w[0], w[1], w[2] * 1000])
		if w[2] <= RAJA:
			_vika("mittari ei havaitse (vanha halaus %.1f mm)" % (w[2] * 1000))
	print("HAHMOT_KONTAKTI valmis, vikoja %d, %s" % [vikoja, ProjectSettings.globalize_path(out)])
	get_tree().quit()


func _vika(s: String) -> void:
	vikoja += 1
	print("TESTI VIKA ", s)


## K14: yksinäinen hahmo (toinen 30 m päässä) ei muutu pair_fitissä: luiden paikat, sijainti ja IK-kohteet ennen ja jälkeen.
func _yksin() -> void:
	_place(me, Vector3.ZERO, PI)
	_place(juntti, Vector3(30, 0, 30), 0.0)
	var sh := me.to_global(me.bone_position("upperarm_r"))
	me.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", me.to_local(sh + Vector3(0.1, -0.3, 0.3)), me.to_local(sh + Vector3(0.4, -0.3, 0)))
	me.refresh_pose()
	var before := _bones(me)
	var pos := me.global_position
	var tgt: Vector3 = (me._ik["arm_r"] as Array)[3]
	var left := Contact.pair_fit(me, prof[me], juntti, prof[juntti], true)
	me.refresh_pose()
	var after := _bones(me)
	var diff := me.global_position.distance_to(pos) + ((me._ik["arm_r"] as Array)[3] as Vector3).distance_to(tgt)
	for i in before.size():
		diff = maxf(diff, before[i].distance_to(after[i]))
	print("YKSIN pair_fit jäännös %.1f mm, suurin muutos %.3f mm, päällekkäisiä pareja %d" % [left * 1000, diff * 1000,
		Contact.overlap_pairs(me, prof[me], juntti, prof[juntti]).size()])
	if diff > 0.0001:
		_vika("yksin hahmo muuttui %.3f mm" % (diff * 1000))
	me.clear_ik()
	for i in 2:
		await get_tree().process_frame


func _bones(c: Node3D) -> Array:
	var sk: Skeleton3D = c.skeleton
	var res := []
	for i in sk.get_bone_count():
		res.append(sk.global_transform * sk.get_bone_global_pose(i).origin)
	return res


func _place(c: Node3D, p: Vector3, rot_y: float) -> void:
	c.clear_ik()
	c.position = p
	c.rotation.y = rot_y
	c.visible = p.length() < 10.0


## Vaihe: päähahmo origossa kasvot +Z:aan, toinen kasvot -Z:aan. step(t) asettaa asennon ja palauttaa kuvattavan hetken
## nimen (tai ""); joka ruudulla mitataan. hug = kummankin kädet IK:lla (KOHDE, RANNE, SUUNTA molemmille).
func _phase(nm: String, other: Node3D, dur: float, step: Callable, hug: bool) -> void:
	for c in [me, sinikka, juntti]:
		_place(c, Vector3(30, 0, 30), 0.0)
	_place(me, Vector3.ZERO, PI)
	_place(other, Vector3(0, 0, 0.9), 0.0)
	for c in [me, other]:
		c.restart("Idle", 0.0, 1.0)
	worst[nm] = ["-", "-", 0.0, 0.0]
	pairs[nm] = {}
	kohde[nm] = {}
	var t := 0.0
	var shots_done := {}
	while t < dur:
		var shot: String = step.call(t, other)
		_measure(nm, other, t)
		if shot != "" and not shots_done.has(shot):
			shots_done[shot] = true
			await _views(nm + "_" + shot, other)
			_measure_shot(nm, other, hug)
		await get_tree().process_frame
		t += DT
	var w: Array = worst[nm]
	print("PARI %s %s %s %.1f mm (t %.2f s)" % [nm, w[0], w[1], w[2] * 1000, w[3]])
	var top: Array = (pairs[nm] as Dictionary).keys()
	top.sort_custom(func(x: String, y: String) -> bool: return pairs[nm][x] > pairs[nm][y])
	print("PARIT %s %s" % [nm, ", ".join(top.slice(0, 6).map(func(k: String) -> String: return "%s %.1f" % [k, pairs[nm][k] * 1000]))])
	if w[2] > RAJA and (nm != "vanha" or old_way):
		_vika("%s %s %s %.1f mm" % [nm, w[0], w[1], w[2] * 1000])
	for ch: String in kohde[nm]:
		var g: float = kohde[nm][ch][0]
		var mg: float = kohde[nm][ch][2] if kohde[nm][ch].size() > 2 else INF
		print("KOHDE %s %s rako %.1f mm (lähin %s:%s), kämmenen verkko toisen verkkoon %s" % [nm, ch, g * 1000,
			_who(other) if ch.begins_with("me") else "me", kohde[nm][ch][1], "%.1f mm" % (mg * 1000) if mg < INF else "-"])
		if mg < INF:
			g = mg  # näkyvä pinta ratkaisee: kapselimalli on hartialla 2-6 cm verkon alla (MALLI)
		if g > RAJA:
			_vika("%s kohde %s rako %.1f mm" % [nm, ch, g * 1000])


## Kapseliparit joka ruudulla: vaiheen pahin pari ja jokaisen parin suurin syvyys.
func _measure(nm: String, other: Node3D, t: float) -> void:
	for p in Contact.overlap_pairs(me, prof[me], other, prof[other]):
		var key := "%s:%s %s:%s" % [_who(me), p[0], _who(other), p[1]]
		pairs[nm][key] = maxf(pairs[nm].get(key, 0.0), p[2])
		if p[2] > (worst[nm] as Array)[2]:
			worst[nm] = ["%s:%s" % [_who(me), p[0]], "%s:%s" % [_who(other), p[1]], p[2], t]


func _who(c: Node3D) -> String:
	return "me" if c == me else ("sinikka" if c == sinikka else "juntti")


## Kosketus joka ruutu: vartalot ja IK-ketjut ulos toisesta, painumalaatikot molemmille.
func _fit(other: Node3D, move_b: bool) -> void:
	Contact.pair_fit(me, prof[me], other, prof[other], move_b)
	var bx := Contact.pair_contacts(me, prof[me], other, prof[other])
	me.set_contacts(bx[0])
	other.set_contacts(bx[1])
	me.refresh_pose()
	other.refresh_pose()


func _right(c: Node3D) -> Vector3:
	var r := c.to_global(c.bone_position("upperarm_r")) - c.to_global(c.bone_position("upperarm_l"))
	return Vector3(r.x, 0, r.z).normalized()


func _hand_r(c: Node3D) -> float:
	return (prof[c].caps["hand_r"] as Array)[2]


## Rintakehät lähelle (pair_fit työntää toisen ulos), sitten kädet pinnoille ja toinen pair_fit käsille.
func _approach(other: Node3D, w: float, close: float) -> void:
	var a := me.to_global(me.bone_position("spine_03"))
	other.position = Vector3(0, 0, 0.9)
	other.refresh_pose()
	var b := other.to_global(other.bone_position("spine_03"))
	other.position.z += lerpf(0.9, close, w) - (b.z - a.z)
	other.refresh_pose()
	Contact.pair_fit(me, prof[me], other, prof[other], true)


## Kämmen pinnalle: kohde = kapselin pinta suuntaan n + kämmenen säde, kämmen sisään (-n), sormet suuntaan fingers.
func _hand_to(c: Node3D, lr: String, p: Vector3, n: Vector3, fingers: Vector3, pole: Vector3, w: float) -> void:
	var s := 1.0 if lr == "_r" else -1.0
	var sh := c.to_global(c.bone_position("upperarm" + lr))
	var rest := sh + Vector3(0, -0.55, 0) + _right(c) * s * 0.12
	var gb := c.global_transform.basis.inverse()
	var f := (fingers - n * fingers.dot(n)).normalized()
	c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, c.to_local(rest.lerp(p, w)), c.to_local(pole))
	c.set_ik_orient("arm" + lr, Pose.palm_on(gb * f, gb * -n, lr == "_l"), w)


func _hali(t: float, other: Node3D) -> String:
	var w := smoothstep(0.0, 1.2, t)
	_approach(other, w, 0.27)
	# Kädet eri korkeudelle, etteivät käsivarret risteä: Sinikan kädet päähahmon vyötärölle (spine_01-kapselin pinta selän
	# ja kyljen välissä, kyynärpäät alas-ulos), päähahmon kädet Sinikan hartioiden yli yläselkään (kyynärpäät ylös-ulos).
	var rs := _right(other)
	var back := Vector3(me.global_basis.z.x, 0, me.global_basis.z.z).normalized()
	for lr: String in ["_l", "_r"]:
		var s := 1.0 if lr == "_r" else -1.0
		var n := (back * cos(KULMA) + rs * s * sin(KULMA)).normalized()
		var p := Contact.surface_point(me, prof[me], "spine_01", n, 0.5) + n * _hand_r(other)
		var sh := other.to_global(other.bone_position("upperarm" + lr))
		_hand_to(other, lr, p, n, -rs * s, sh + rs * s * 0.45 + Vector3(0, -0.35, 0), w)
	var rm := _right(me)
	var sback := Vector3(other.global_basis.z.x, 0, other.global_basis.z.z).normalized()
	for lr: String in ["_l", "_r"]:
		var s := 1.0 if lr == "_r" else -1.0
		# Hartiat ovat samalla korkeudella: kyynärvarsi kulkee olkanivelen päältä, kämmen hartian taka-yläpinnalle.
		var sh := me.to_global(me.bone_position("upperarm" + lr))
		var olr := _nearest(other, sh, ["upperarm_l", "upperarm_r"]).trim_prefix("upperarm")
		var n := (sback * cos(KULMA_YLA) + Vector3.UP * sin(KULMA_YLA)).normalized()
		var p := _shoulder(other, olr, YLA) + sback * TAKA + n * _hand_r(me)
		_hand_to(me, lr, p, n, sback - Vector3.UP * 0.5, sh + rm * s * 0.4 + Vector3(0, 0.5, 0), w)
	_fit(other, true)
	if t >= 2.0 and t < 2.0 + DT:
		return "kiinni"
	return ""


## Painiote yksinkertaisesti (kontaktijärjestelmän testi, ei otteen uskottavuus): päähahmon kämmenet Juntin kyljille
## (spine_01, pehmeä vatsa, kyynärpäät alas-ulos), Juntti tarttuu päälle päähahmon kyynärvarsista (kämmen kyynärvarren
## yläpinnalla, kyynärpäät ulos). Kädet eri korkeuksilla, kyynärvarret päällekkäin, joten käsivarret eivät risteä.
func _paini(t: float, other: Node3D) -> String:
	var w := smoothstep(0.0, 1.2, t)
	_approach(other, w, PAINI_LAHI)
	var rm := _right(me)
	var ro := _right(other)
	var ofront := -Vector3(other.global_basis.z.x, 0, other.global_basis.z.z).normalized()
	for lr: String in ["_l", "_r"]:
		var s := 1.0 if lr == "_r" else -1.0
		var sh := me.to_global(me.bone_position("upperarm" + lr))
		var so := -s  # päähahmon oikea käsi Juntin vasemmalle kyljelle
		var n := (ofront * cos(PAINI_KYLKI) + ro * so * sin(PAINI_KYLKI)).normalized()
		var p := Contact.surface_point(other, prof[other], "spine_01", n, 0.6) + n * _hand_r(me)
		_hand_to(me, lr, p, n, p - sh, sh + rm * s * 0.45 + Vector3(0, -0.4, 0), w)
	me.refresh_pose()
	for lr: String in ["_l", "_r"]:
		var s := 1.0 if lr == "_r" else -1.0
		var sh2 := other.to_global(other.bone_position("upperarm" + lr))
		var mlr := "_r" if lr == "_l" else "_l"  # Juntin vasen käsi päähahmon oikeaan kyynärvarteen
		var p2 := Contact.surface_point(me, prof[me], "lowerarm" + mlr, Vector3.UP, PAINI_KYYNARVARSI) + Vector3.UP * _hand_r(other)
		_hand_to(other, lr, p2, Vector3.UP, p2 - sh2, sh2 + ro * s * 0.5 + Vector3(0, -0.2, 0), w)
	_fit(other, true)
	if t >= 2.0 and t < 2.0 + DT:
		return "ote"
	return ""


## Hartian yläpinta (paistettu verkko): olkanivelestä kaulaa kohti osuudella inner, korkeus = verkon yläreuna siinä kohdassa.
func _shoulder(o: Node3D, lr: String, inner: float) -> Vector3:
	var j := o.to_global(o.bone_position("upperarm" + lr))
	var p := j.lerp(o.to_global(o.bone_position("neck_01")), inner)
	var top := Pose.top_y(Pose.limb_points(o, self, ["clavicle" + lr, "upperarm" + lr, "spine_03"], 1), p, 0.04)
	return Vector3(p.x, top if top > -INF else p.y + 0.06, p.z)


func _nearest(c: Node3D, p: Vector3, caps: Array) -> String:
	var best := ""
	var bd := INF
	for cp: String in caps:
		var d := c.to_global(c.bone_position(cp)).distance_to(p)
		if d < bd:
			bd = d
			best = cp
	return best


## Iskut Juntin vatsaan (Juntti ei liiku): nyrkin kohde = spine_01-kapselin pinta minua kohti + käden pituus ja säde.
func _iskut(t: float, other: Node3D) -> String:
	other.position = Vector3(0, 0, 0.5)
	var k := int(t / ISKU)
	var cyc := fmod(t, ISKU) / ISKU
	var e := pow(sin(PI * clampf(cyc * 1.4, 0.0, 1.0)), 2.0)
	var lr := "_r" if k % 2 == 0 else "_l"
	var lo := "_l" if lr == "_r" else "_r"
	var s := 1.0 if lr == "_r" else -1.0
	var rm := _right(me)
	var fwd := -Vector3(me.global_basis.z.x, 0, me.global_basis.z.z).normalized()
	var n := -fwd
	var hand: Array = prof[me].caps["hand" + lr]
	var p := Contact.surface_point(other, prof[other], "spine_01", n, 0.6) + n * (float(hand[2]) + float(hand[3]))
	var sh := me.to_global(me.bone_position("upperarm" + lr))
	var guard := sh + Vector3(0, -0.12, 0) + fwd * 0.22 - rm * s * 0.08
	var gb := me.global_transform.basis.inverse()
	me.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, me.to_local(guard.lerp(p, e)),
		me.to_local(sh + rm * s * 0.3 + Vector3(0, -0.4, 0)))
	me.set_ik_orient("arm" + lr, Pose.palm_on(gb * fwd, gb * Vector3.DOWN, lr == "_l"), e)
	var sh2 := me.to_global(me.bone_position("upperarm" + lo))
	me.set_ik("arm" + lo, "upperarm" + lo, "lowerarm" + lo, "hand" + lo, me.to_local(sh2 + Vector3(0, -0.1, 0) + fwd * 0.24 + rm * s * 0.08),
		me.to_local(sh2 - rm * s * 0.3 + Vector3(0, -0.4, 0)))
	_fit(other, false)
	if e > 0.985:
		_gap("iskut", "arm" + lr, me, other)
	if k == 1:  # toinen isku kuvataan: ennen osumaa, osuma ja palautuminen
		if cyc >= 0.18 and cyc < 0.18 + DT / ISKU:
			return "ennen"
		if cyc >= 0.357 and cyc < 0.357 + DT / ISKU:
			return "osuma"
		if cyc >= 0.62 and cyc < 0.62 + DT / ISKU:
			return "palautuu"
	return ""


## Halaus vanhalla tavalla (paahahmo_liikkeet.gd): rintakehät 0,27 m, kiinteät kohteet selkään, ei pair_fitiä.
func _vanha_hali(t: float, other: Node3D) -> String:
	var w := smoothstep(0.0, 1.2, t)
	var a := me.to_global(me.bone_position("spine_03"))
	other.position = Vector3(0, 0, 0.9)
	other.refresh_pose()
	var b := other.to_global(other.bone_position("spine_03"))
	other.position.z += lerpf(0.9, 0.27, w) - (b.z - a.z)
	for pr in [[other, me, false], [me, other, true]]:
		var c: Node3D = pr[0]
		var o: Node3D = pr[1]
		var high: bool = pr[2]
		var right := _right(c)
		var o_back := o.global_basis.z.normalized()
		for lr in ["r", "l"]:
			var s := 1.0 if lr == "r" else -1.0
			var tgt := o.to_global(o.bone_position("neck_01" if high else "spine_01")) + o_back * (0.06 if high else 0.1) \
				+ right * s * (0.12 if high else 0.1)
			var sh := c.to_global(c.bone_position("upperarm_" + lr))
			var rest := sh + Vector3(0, -0.55, 0) + right * s * 0.12
			var pole := sh + right * s * 0.45 + Vector3(0, 0.1 if high else -0.25, 0)
			c.set_ik("arm_" + lr, "upperarm_" + lr, "lowerarm_" + lr, "hand_" + lr, c.to_local(rest.lerp(tgt, w)), c.to_local(pole))
	me.refresh_pose()
	other.refresh_pose()
	if t >= 1.6 and t < 1.6 + DT:
		return "kiinni"
	return ""


## Kohteen rako: kämmenkapselin lyhin etäisyys toisen hahmon kapselien pintaan suuntaan (Contact._pt_depth, muototaulu;
## negatiivinen = sisällä, PARI mittaa). mesh: lisäksi kämmenen verkon etäisyys toisen verkkoon (kuvahetkellä, raskas).
func _gap(nm: String, chain: String, c: Node3D, o: Node3D, mesh := false) -> void:
	var caps := Contact.caps_all(c, prof[c])
	var hand: Array = []
	for cp in caps:
		if cp[0] == "hand" + chain.trim_prefix("arm"):
			hand = cp
	if hand.is_empty():
		return
	var g := INF
	var at := ""
	for oc in Contact.caps_all(o, prof[o]):
		for i in 9:
			var q: Vector3 = (hand[1] as Vector3).lerp(hand[2], i / 8.0)
			var d: float = -float(Contact._pt_depth(q, hand[3], oc)[0])
			if d < g:
				g = d
				at = oc[0]
	var key := "%s %s" % [_who(c), chain]
	if g > (kohde[nm].get(key, [-INF, ""]) as Array)[0]:
		kohde[nm][key] = [g, at]
	if mesh:
		var mg := _mesh_gap(c, o, "hand" + chain.trim_prefix("arm"))
		if mg < INF:
			kohde[nm][key] = [kohde[nm][key][0], kohde[nm][key][1], maxf(mg, kohde[nm][key][2] if kohde[nm][key].size() > 2 else -INF)]


## Kämmenen ja sormien paistetun verkon lyhin etäisyys toisen hahmon paistettuun verkkoon (vartalo ja vaatteet); INF ilman näyttöä.
func _mesh_gap(c: Node3D, o: Node3D, hand: String) -> float:
	var lr := hand.right(2)
	var bones := [hand]
	for f in ["thumb", "index", "middle", "ring", "pinky"]:
		for k in ["_01", "_02", "_03"]:
			bones.append(f + k + lr)
	var hp := Pose.limb_points(c, self, bones, 1)
	if hp.is_empty():
		return INF
	var ctr := Vector3.ZERO
	for q in hp:
		ctr += q
	ctr /= hp.size()
	var near := PackedVector3Array()
	for q in Pose.limb_points(o, self, ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r",
			"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "Head"], 1):
		if q.distance_to(ctr) < 0.3:
			near.append(q)
	var g := INF
	for q in hp:
		for r in near:
			g = minf(g, q.distance_squared_to(r))
	return sqrt(g)


## Kuvahetkellä: kohteen rako (K12), ranne (K9), jalat ja suunnat (K10), painumat (K7, K11) ja käsivarren pinta (PINTA).
func _measure_shot(nm: String, other: Node3D, hug: bool) -> void:
	for c: Node3D in [me, other]:
		var o: Node3D = other if c == me else me
		for lr: String in ["_l", "_r"]:
			if hug and nm != "vanha":
				_gap(nm, "arm" + lr, c, o, true)
			var la := c.to_global(c.bone_position("lowerarm" + lr))
			var hd := c.to_global(c.bone_position("hand" + lr))
			var md := c.to_global(c.bone_position("middle_01" + lr))
			var ang := rad_to_deg((hd - la).angle_to(md - hd))
			print("RANNE %s %s%s %.0f astetta" % [nm, _who(c), lr, ang])
			if ang > 70.0 and nm != "vanha":
				_vika("%s ranne %s%s %.0f astetta" % [nm, _who(c), lr, ang])
		var right := _right(c)
		var pel := c.to_global(c.bone_position("pelvis"))
		var fl := (c.to_global(c.bone_position("foot_l")) - pel).dot(right)
		var fr := (c.to_global(c.bone_position("foot_r")) - pel).dot(right)
		var fwd := -Vector3(c.global_basis.z.x, 0, c.global_basis.z.z).normalized()
		var to_o := o.global_position - c.global_position
		var facing := fwd.dot(Vector3(to_o.x, 0, to_o.z).normalized())
		print("SUUNTA %s %s vasen jalka %.2f oikea %.2f, rinta kohti toista %.2f" % [nm, _who(c), fl, fr, facing])
		if fl >= 0.0 or fr <= 0.0 or facing < 0.7:
			_vika("%s suunta %s (jalat ristissä tai selkä toiseen päin)" % [nm, _who(c)])
		_painuma(nm, c)
	_malli(nm, other if nm != "iskut" else juntti)
	if nm == "hali" or nm == "vanha":
		var torso := []
		for cp in Contact.caps_all(me, prof[me]):
			if cp[0] in TORSO:
				torso.append(cp)
		var deep := 0.0
		for q in Pose.limb_points(other, self, ["lowerarm_l", "lowerarm_r", "hand_l", "hand_r"], 1):
			for cp in torso:
				deep = maxf(deep, cp[3] - Contact._seg_dist(q, cp[1], cp[2]))
		print("PINTA %s Sinikan käsivarren pisteet päähahmon torsokapselin sisällä %.1f mm (tiedoksi)" % [nm, deep * 1000])


## Kapselimalli vs paistettu verkko (tiedoksi): hartian yläpinta (kapselin yläreuna - verkon yläreuna samassa kohdassa)
## ja vatsan etupinta päähahmoa kohti (verkko - kapseli). Positiivinen = kapseli ulottuu yli / verkko ulottuu yli.
func _malli(nm: String, o: Node3D) -> void:
	var torso := Contact.caps_all(o, prof[o]).filter(func(cp: Array) -> bool: return cp[0] in TORSO)
	var inside := func(q: Vector3) -> bool:
		for cp in torso:
			if Contact._seg_dist(q, cp[1], cp[2]) <= cp[3]:
				return true
		return false
	for inner in [0.15, 0.55]:
		var p := _shoulder(o, "_l", inner)
		var y := p.y + 0.4
		while y > p.y - 0.2 and not inside.call(Vector3(p.x, y, p.z)):
			y -= 0.002
		print("MALLI %s %s hartia (osuus kaulaan %.2f): kapselin yläreuna - verkon yläreuna %.1f mm" % [nm, _who(o), inner, (y - p.y) * 1000])
	var b := o.to_global(o.bone_position("spine_01")) + Vector3(0, 0.03, 0)
	var n := (me.global_position - o.global_position) if o != me else -Vector3(me.global_basis.z.x, 0, me.global_basis.z.z)
	n = Vector3(n.x, 0, n.z).normalized()
	var front := -INF
	for q in Pose.limb_points(o, self, ["spine_01", "spine_02", "pelvis"], 1):
		var d := (q - b).dot(n)
		if (q - b - n * d).length() < 0.05:
			front = maxf(front, d)
	var cf := 0.0
	while cf < 0.6 and inside.call(b + n * cf):
		cf += 0.002
	print("MALLI %s %s vatsa: verkon etupinta - kapselin etupinta %.1f mm" % [nm, _who(o), (front - cf) * 1000])


## Painuma luuttain pinnan normaalia pitkin (Elastic.press ilman leviämistä): luiset (raja 0: pää, kylkiluut) 0, pehmeät enintään 5 cm.
func _painuma(nm: String, c: Node3D) -> void:
	var mi: MeshInstance3D = c.body_mi
	if mi == null or DisplayServer.get_name() == "headless" or c.press_boxes.is_empty():
		return
	var src: Array = mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = mi.bake_mesh_from_current_skeleton_pose().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var bi: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var bw: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var c0: PackedFloat32Array = src[Mesh.ARRAY_CUSTOM0]
	var per := bi.size() / vs.size()
	var sk: Skin = mi.skin
	var by := {}
	var bony := 0.0
	for v in vs.size():
		var best := 0
		for k in per:
			if bw[v * per + k] > bw[v * per + best]:
				best = k
		var lim := c0[v * 4 + 3]
		var disp := Elastic.press(vs[v], ns[v], lim, c.press_boxes, 0.0, 0.0).distance_to(vs[v])  # ilman leviämistä
		var key := str(sk.get_bind_name(bi[v * per + best]))
		by[key] = maxf(by.get(key, 0.0), disp)
		if lim <= 0.0:
			bony = maxf(bony, disp)
	var keys: Array = by.keys().filter(func(k: String) -> bool: return by[k] > 0.0005)
	print("PAINUMA %s %s laatikoita %d: %s; luiset %.1f mm" % [nm, _who(c), c.press_boxes.size(),
		", ".join(keys.map(func(k: String) -> String: return "%s %.1f" % [k, by[k] * 1000])), bony * 1000])
	if bony > 0.0005:
		_vika("%s %s luinen kohta painuu %.1f mm" % [nm, _who(c), bony * 1000])
	for k: String in keys:
		if by[k] > Elastic.MAX_LIMIT + 0.0001:  # raja 5 cm saa täyttyä (MAX_LIMIT), pyöristysvara 0,1 mm
			_vika("%s %s painuma %s %.1f mm yli 5 cm" % [nm, _who(c), k, by[k] * 1000])


## Kuvat edestä (sivuprofiili), päädyistä (toisen selän takaa), ylhäältä; aika pysähtyy kuvien ajaksi.
func _views(prefix: String, other: Node3D) -> void:
	var c := (me.to_global(me.bone_position("spine_02")) + other.to_global(other.bone_position("spine_02"))) * 0.5
	Engine.time_scale = 0.0
	await Asento.views(cam, out, prefix, c, 1.3, Vector3(1, 0, 0), false)
	Engine.time_scale = 1.0
