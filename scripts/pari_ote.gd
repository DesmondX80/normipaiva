extends RefCounted
## Kahden hahmon ote (tanssi, halaus): kämmen toisen pinnalle, hartian yläpinta ja kosketus (Contact.pair_fit ->
## pair_contacts -> set_contacts). Esikuva tools/testit/hahmot_kontakti.gd (_right, _hand_to, _shoulder, _fit); kämmenen säde palm_r.

const Pose := preload("res://scripts/pose.gd")
const Contact := preload("res://scripts/contact.gd")

# Halausote (esikuva hahmot_kontakti.gd _hali): kädet eri korkeudelle, etteivät käsivarret risteä.
const KULMA := deg_to_rad(60.0)  # vyötäröllä pitävän kämmen selän keskeltä kylkeä kohti
const KULMA_YLA := deg_to_rad(40.0)  # hartioiden yli pitävän kämmenen normaali toisen hartian takana (selästä ylös)
const YLA := 0.35  # hartioiden yli pitävän kämmen olkanivelestä kaulaa kohti (osuus)
const TAKA := 0.02  # ja hartian yläpinnasta selkään päin (m)
const WAIST := [["spine_01", 0.5], ["spine_01", 0.8], ["spine_02", 0.3], ["spine_02", 0.6]]  # vyötäröltä ylöspäin (kapseli, osuus)
# Suljettu valssi- ja humppaote (valssi): viejän selkäkäsi selän keskeltä (lapaluun alta, jolloin seuraajan olkavarsi on
# viejän kyynärvarren yllä) ylös lapaluulle ja alas vyötärölle, [kapseli, osuus, kulma selästä seuraajan olkakäden puolen
# kylkeen], ensimmäinen, joka on ulottuvilla ja jossa ranne ei taitu.
const SELKA := [["spine_02", 0.8, deg_to_rad(65.0)], ["spine_02", 0.5, deg_to_rad(75.0)], ["spine_03", 0.4, deg_to_rad(60.0)],
	["spine_03", 0.6, deg_to_rad(50.0)], ["spine_01", 0.8, deg_to_rad(80.0)]]
# Paljon lyhyempi seuraaja (olkanivel yli ALA viejän alapuolella): selkäkäsi vyötärölle, ettei kyynärpää nouse seuraajan olan yli.
const ALA := 0.08
const VYO := [["spine_01", 0.8, deg_to_rad(75.0)], ["spine_01", 0.5, deg_to_rad(75.0)], ["spine_02", 0.3, deg_to_rad(75.0)]]
const OLKA := deg_to_rad(30.0)  # seuraajan olkakämmenen normaali pystystä viejän olan ulkosivulle
static var _sh_cache := {}  # shoulder(): avain -> piste spine_03-luun avaruudessa


## Hahmon oikea vaakasuunta (olkanivelestä toiseen, vaakaan projisoituna).
static func right(c: Node3D) -> Vector3:
	var r := c.to_global(c.bone_position("upperarm_r")) - c.to_global(c.bone_position("upperarm_l"))
	return Vector3(r.x, 0, r.z).normalized()


## Hahmon selän vaakasuunta (+Z vaakaan; etu on -Z).
static func back(c: Node3D) -> Vector3:
	return Vector3(c.global_basis.z.x, 0, c.global_basis.z.z).normalized()


## Jalat IK:lla animaation asennosta: jalkaterä ja polven taivutussuunta luetaan animaatiosta (IK-ketjut ensin pois), jolloin
## askeleet pysyvät samoina, mutta Contact.pair_fit voi väistää jalat toisen jaloista (_fit_chains) siirtämättä koko hahmoa.
## Kutsu joka ruutu animaation jälkeen (process_priority) ennen pair_fitiä. Kaikki hahmon avaruudessa.
static func legs_from_anim(c: Node3D) -> void:
	for lr in ["_l", "_r"]:
		c._ik.erase("leg" + lr)
	c.refresh_pose()
	for lr in ["_l", "_r"]:
		var f: Vector3 = c.bone_position("foot" + lr)
		var k: Vector3 = c.bone_position("calf" + lr)
		var h: Vector3 = c.bone_position("thigh" + lr)
		var out := k - (h + f) * 0.5  # polven taivutus
		if out.length() < 0.01:
			out = Vector3(0, 0, -1)
		c.set_ik("leg" + lr, "thigh" + lr, "calf" + lr, "foot" + lr, f, k + out.normalized() * 0.3)


## Halausote painolla w: held_sh:n kämmenet held_waistin vyötärölle (spine_01:n pinta selän ja kyljen välissä,
## kyynärpäät alas-ulos), held_waistin kämmenet held_sh:n hartioiden yli yläselkään (kyynärpäät ylös-ulos).
## pw/ps = profiilit (Contact.profile), space = pystyssä oleva solmu hartiapinnan mittaukseen. Kutsu pair_fitin jälkeen.
static func hali(held_waist: Node3D, pw: Dictionary, held_sh: Node3D, ps: Dictionary, space: Node3D, w: float) -> void:
	var rs := right(held_sh)
	var bk := back(held_waist)
	for lr: String in ["_l", "_r"]:
		var s := 1.0 if lr == "_r" else -1.0
		var n := (bk * cos(KULMA) + rs * s * sin(KULMA)).normalized()
		var sh := held_sh.to_global(held_sh.bone_position("upperarm" + lr))
		# Vyötärö, tai pidempi pitäjä (pituusero) ylempää selästä: alin kohta, joka on käden ulottuvilla.
		var reach := arm_len(held_sh, lr) * 0.98
		var p := Vector3.ZERO
		for at: Array in WAIST:
			p = Contact.surface_point(held_waist, pw, at[0], n, at[1]) + n * palm_r(held_sh, ps, lr, n, -rs * s)
			if p.distance_to(sh) <= reach:
				break
		hand_to(held_sh, lr, p, n, -rs * s, sh + rs * s * 0.45 + Vector3(0, -0.35, 0), w)
	var rm := right(held_waist)
	var sback := back(held_sh)
	for lr: String in ["_l", "_r"]:
		var s := 1.0 if lr == "_r" else -1.0
		var sh := held_waist.to_global(held_waist.bone_position("upperarm" + lr))
		var olr := "_l" if lr == "_r" else "_r"
		# Hartiat ovat samalla korkeudella: kyynärvarsi kulkee olkanivelen päältä, kämmen hartian taka-yläpinnalle.
		var n := (sback * cos(KULMA_YLA) + Vector3.UP * sin(KULMA_YLA)).normalized()
		var p := shoulder(held_sh, space, olr, YLA) + sback * TAKA
		p += n * palm_r(held_waist, pw, lr, n, p - sh)
		# Sormet kyynärvarren jatkeena (olasta kohteeseen): lyhyempi pitäjä kurottaa ylös, eikä ranne taitu hartian yli.
		hand_to(held_waist, lr, p, n, p - sh, sh + rm * s * 0.4 + Vector3(0, 0.5, 0), w)


## Suljettu valssi- ja humppaote painolla w: viejän (lead) selkäkäsi seuraajan (fol) selkään lapaluun alle, seuraajan olkakäsi viejän
## olkavarren yläosaan (kyynärvarsi viejän käsivarren päällä) ja vapaat kädet yhdessä sivulla kämmenet vastakkain. Kädet
## valitaan sivusiirron puolen mukaan, ei nimen: seuraaja viejän oikealla -> viejän oikea ja seuraajan vasen pitävät.
## pl/pf = profiilit, space = pystyssä oleva solmu hartiapinnan mittaukseen. Kutsu pair_fitin jälkeen.
static func valssi(lead: Node3D, pl: Dictionary, fol: Node3D, pf: Dictionary, space: Node3D, w: float) -> void:
	var rl := right(lead)
	var sd := signf((fol.to_global(fol.bone_position("spine_03")) - lead.to_global(lead.bone_position("spine_03"))).dot(rl))
	if sd == 0.0:
		sd = 1.0
	var lb := "_r" if sd > 0.0 else "_l"  # viejän selkäkäsi
	var fa := "_l" if sd > 0.0 else "_r"  # seuraajan olkakäsi (samalla maailman puolella)
	var lf := "_l" if lb == "_r" else "_r"
	var ff := "_r" if fa == "_l" else "_l"
	var sf := -1.0 if fa == "_l" else 1.0
	# (1) Selkäkäsi: ensimmäinen kohta selässä seuraajan fa-kyljen puolella, joka on ulottuvilla ja jossa ranne ei taitu
	# (kyynärpää kiertää kyljen ulkopuolelta); jos mikään ei ulotu, lähin. Suora linja olasta kulkisi aina seuraajan läpi.
	var sh := lead.to_global(lead.bone_position("upperarm" + lb))
	var reach := arm_len(lead, lb) * 0.98
	var bk := back(fol)
	var rf := right(fol)
	var p := Vector3.ZERO
	var n := Vector3.ZERO
	var over := INF
	var low := lead.to_global(lead.bone_position("upperarm" + lb)).y - fol.to_global(fol.bone_position("upperarm" + fa)).y > ALA
	for at: Array in (VYO if low else SELKA):
		var nn := (bk * cos(at[2]) + rf * sf * sin(at[2])).normalized()
		var pp := Contact.surface_point(fol, pf, at[0], nn, at[1])
		pp += nn * palm_r(lead, pl, lb, nn, pp - sh)
		var wrist := rad_to_deg(asin(clampf(absf((pp - sh).normalized().dot(nn)), 0.0, 1.0)))
		var o := maxf(pp.distance_to(sh) - reach, 0.0) + (0.0 if wrist <= 60.0 else 1.0)
		if o < over:
			p = pp
			n = nn
			over = o
		if o == 0.0:
			break
	hand_to(lead, lb, p, n, p - sh, sh + rl * sd * 0.4 + Vector3.UP * 0.1, w)
	# (2) Vapaat kädet yhdessä: kohta olkien puolivälissä hieman olan alapuolella ja sivulla (suurin sivu, joka ulottuu).
	# Kyynärpäät ulos ja alas samalle syvyydelle kuin kädet, jolloin kyynärvarret ovat kämmenten tasossa (ranne suorana).
	var d := -back(lead)
	var out := -rl * sd
	var sl := lead.to_global(lead.bone_position("upperarm" + lf))
	var sfo := fol.to_global(fol.bone_position("upperarm" + ff))
	var c := (sl + sfo) * 0.5
	c.y = (sl.y + sfo.y) * 0.5 - 0.10
	var lim := minf(arm_len(lead, lf), arm_len(fol, ff)) * 0.85
	var cc := c + out * 0.05
	for k in range(6, 0, -1):
		var q := c + out * (k * 0.05)
		if q.distance_to(sl) <= lim and q.distance_to(sfo) <= lim:
			cc = q
			break
	var free := [[lead, lf, cc - d * palm_r(lead, pl, lf, -d, Vector3.UP), -d], [fol, ff, cc + d * palm_r(fol, pf, ff, d, Vector3.UP), d]]
	for f: Array in free:
		hand_to(f[0], f[1], f[2], f[3], Vector3.UP, cc + out * 0.3 + Vector3.DOWN * 0.3, w)
	# (3) Asennot ajan tasalle: vapaiden käsien sormet kyynärvarren jatkeena kämmenten tasossa (kyynärpäästä käteen).
	lead.refresh_pose()
	fol.refresh_pose()
	for f: Array in free:
		var ch: Node3D = f[0]
		var fa_dir: Vector3 = (f[2] as Vector3) - ch.to_global(ch.bone_position("lowerarm" + f[1]))
		hand_to(ch, f[1], f[2], f[3], fa_dir, cc + out * 0.3 + Vector3.DOWN * 0.3, w)
	# (4) Seuraajan olkakäsi viejän olan päälle: pienin nosto kapseleista ulos (kapselin ja verkon ero), kun ulottuma
	# riittää; kyynärvarsi viejän käsivarren päällä (pole viejän kyynärpään yllä).
	var fsh := fol.to_global(fol.bone_position("upperarm" + fa))
	var freach := arm_len(fol, fa)
	var lcaps := Contact.caps_all(lead, pl)
	var on := (Vector3.UP * cos(OLKA) + rl * sd * sin(OLKA)).normalized()
	var best := Vector3.ZERO
	var lift := INF  # nosto (+1, jos ei ulotu)
	for inner: float in [0.0, 0.1, 0.2, 0.25, 0.3, 0.35]:
		var q := shoulder(lead, space, lb, inner)
		var hr := palm_r(fol, pf, fa, on, q - fsh)
		q += on * hr
		var g := Contact._clearance(q, lcaps, hr)
		var up := maxf(-float(g[0]), 0.0)
		q += (g[1] as Vector3) * up
		var score := up + (0.0 if q.distance_to(fsh) <= freach else 1.0)  # ulottuvilla oleva ensin
		if score < lift:
			best = q
			lift = score
	var el := lead.to_global(lead.bone_position("lowerarm" + lb))
	var pole := el + Vector3.UP * (float((pl.caps["upperarm" + lb] as Array)[2]) + float((pf.caps["lowerarm" + fa] as Array)[2]) + 0.05)
	hand_to(fol, fa, best, on, best - fsh, pole, w)


## Käsivarren pituus olkanivelestä ranteeseen (IK:n suurin ulottuma).
static func arm_len(c: Node3D, lr: String) -> float:
	return c.bone_position("upperarm" + lr).distance_to(c.bone_position("lowerarm" + lr)) \
		+ c.bone_position("lowerarm" + lr).distance_to(c.bone_position("hand" + lr))


## Kämmenen säde kämmenpuolelle (suuntaan -n), kun käsi on kohdeasennossa (hand_to: Pose.palm_on sormet suuntaan fingers):
## muototaulun keskeltä (Contact._hand_cap [5]; ilman taulua pyöreä säde). Kohde = pinta + n * palm_r. Täällä eikä contact.gd:ssä,
## koska contact.gd ei voi ladata pose.gd:tä (silmukka). Vasemman käden peilaus tulee palm_onista.
static func palm_r(c: Node3D, prof: Dictionary, lr: String, n: Vector3, fingers: Vector3) -> float:
	var cap: Array = prof.caps["hand" + lr]
	if cap.size() < 6:
		return cap[2]
	var gb := c.global_transform.basis.inverse()
	var f := fingers - n * fingers.dot(n)
	if f.length() < 0.001:
		f = n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.UP)
	var bw := (c.global_transform.basis * Pose.palm_on(gb * f.normalized(), gb * -n, lr == "_l")).orthonormalized()
	return Contact._rad(["hand" + lr, Vector3.ZERO, Vector3.ZERO, float(cap[2]), [bw.transposed(), cap[5]]], 0.5, -n)


## Kämmen pinnalle: kohde = kapselin pinta suuntaan n + kämmenen säde, kämmen sisään (-n), sormet suuntaan fingers.
## w 0 = käsi alhaalla, 1 = kohteessa.
static func hand_to(c: Node3D, lr: String, p: Vector3, n: Vector3, fingers: Vector3, pole: Vector3, w: float) -> void:
	var s := 1.0 if lr == "_r" else -1.0
	var sh := c.to_global(c.bone_position("upperarm" + lr))
	var rest := sh + Vector3(0, -0.55, 0) + right(c) * s * 0.12
	var gb := c.global_transform.basis.inverse()
	var f := (fingers - n * fingers.dot(n)).normalized()
	c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, c.to_local(rest.lerp(p, w)), c.to_local(pole))
	c.set_ik_orient("arm" + lr, Pose.palm_on(gb * f, gb * -n, lr == "_l"), w)


## Hartian yläpinta (paistettu verkko): olkanivelestä kaulaa kohti osuudella inner, korkeus = verkon yläreuna siinä kohdassa.
## space = pystyssä oleva solmu, jonka avaruudessa pinta mitataan; palautus maailmassa. Verkko käydään läpi kerran per hahmo,
## puoli ja inner: piste talletetaan spine_03-luun avaruuteen ja luetaan sen jälkeen luusta (clear_cache otteen lopussa).
static func shoulder(o: Node3D, space: Node3D, lr: String, inner: float) -> Vector3:
	var key := "%d%s%.3f" % [o.get_instance_id(), lr, inner]
	if not _sh_cache.has(key):
		var j := o.to_global(o.bone_position("upperarm" + lr))
		var p := space.to_local(j.lerp(o.to_global(o.bone_position("neck_01")), inner))
		var top := Pose.top_y(Pose.limb_points(o, space, ["clavicle" + lr, "upperarm" + lr, "spine_03"], 1), p, 0.04)
		var wp := space.to_global(Vector3(p.x, top if top > -INF else p.y + 0.06, p.z))
		_sh_cache[key] = Contact._bone_xf(o, "spine_03").affine_inverse() * o.to_local(wp)
	return o.to_global(Contact._bone_xf(o, "spine_03") * (_sh_cache[key] as Vector3))


## Tyhjentää hartiapintojen välimuistin (ote päättyy; uusi hahmo mitataan uudelleen).
static func clear_cache() -> void:
	_sh_cache.clear()


## Kosketus: IK-ketjut chains (ja move_b: vartalot, b siirtyy) ulos toisesta enintään rounds kierroksella, painumalaatikot molemmille.
static func fit(a: Node3D, pa: Dictionary, b: Node3D, pb: Dictionary, move_b := true, chains: Array = Contact.CHAINS,
		rounds := Contact.PAIR_ROUNDS) -> void:
	Contact.pair_fit(a, pa, b, pb, move_b, chains, rounds, false)
	var bx := Contact.pair_contacts(a, pa, b, pb)
	a.set_contacts(bx[0])
	b.set_contacts(bx[1])
	a.refresh_pose()
	b.refresh_pose()
