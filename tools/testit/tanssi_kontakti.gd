extends "res://tools/testit/hahmot_kontakti.gd"
## Tanssin suljettu ote (scripts/pari_ote.gd PariOte.valssi, tanssi_game.gd _hold): kolme paria (Sinikka, Hilkka, Anna-Liisa) x
## alku, nuottirata, horjahdus ja loppu. Mittarit kuten hahmot_kontakti: PARI (kapselit, raja 1 cm), KOHDE (selkä- ja olkakäsi,
## kämmenen verkko toisen verkkoon ±1 cm), KÄSI KÄDESSÄ (vapaat kädet: kapselirako ja kämmenet vastakkain ≤ -0,7), RANNE ≤ 70°,
## SUUNTA (jalat eivät ristissä, rinnat vastakkain ≥ 0,7), PAINUMA (luiset 0, pehmeät ≤ 5 cm), RUUTU (ka < 16,7 ms) ja JÄÄNTEET (0
## lopetuksen jälkeen). Yli rajan -> "TESTI VIKA".
## aja.sh tscn tools/testit/tanssi_kontakti.tscn [sinikka_seura|hilkka|annaliisa] [pois]   (pois = ilman kontakteja, vertailu)

const TanssiGame := preload("res://scripts/tanssi_game.gd")
const KI := preload("res://scripts/kirppis_interior.gd")
const PariOte := preload("res://scripts/pari_ote.gd")
const RUUTU := 1000.0 / 60.0  # kehysaikaraja tanssin aikana (ms)

var g: Node3D
var her: Node3D


func _ready() -> void:
	process_priority = 2
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
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
	_go.call_deferred()


func _go() -> void:
	var only := Array(OS.get_cmdline_user_args().slice(1)).filter(func(a: String) -> bool: return a != "pois")
	var pois := "pois" in OS.get_cmdline_user_args()
	for id in ["sinikka_seura", "hilkka", "annaliisa"]:
		if not only.is_empty() and not id in only:
			continue
		var look: Dictionary = {}
		for p in KI.PEOPLE:
			if p.id == id and "tanssit" in p.modes:
				look = p.look if p.has("look") else Looks.sinikka_seura()
		g = TanssiGame.new()
		g.partner = id
		g.look_override = look
		g.contacts = not pois
		add_child(g)
		cam.current = true
		for i in 8:
			await get_tree().process_frame
		me = g._me
		her = g._her
		if pois:
			prof = {me: Contact.profile(me, Pose.limb_points), her: Contact.profile(her, Pose.limb_points)}
		elif g.prof.is_empty():
			_vika("profiili puuttuu")
			break
		else:
			prof = g.prof
		for b in g._beats:  # kaikki tahdit osutuiksi: kappale ei katkea eikä horjahda kesken
			b[2] = 1
		await _vaihe(id + "_alku", 0.9, 20, false)
		await _vaihe(id + "_rata", 6.0, 30, false)
		if not pois:
			await _ruutu(id)
		await _vaihe(id + "_horja", -1.0, 5, true)
		await _vaihe(id + "_loppu", float(g._song.end) - 2.0, 15, false)
		g._finish()
		var left := 0
		for c in [me, her]:
			left += c._ik.size() + c.press_boxes.size()
		print("JÄÄNTEET %s %d" % [id, left])
		if left > 0:
			_vika("%s jäänteitä %d (IK-ketjut ja painumalaatikot tanssin jälkeen)" % [id, left])
		await get_tree().process_frame
	print("TANSSI_KONTAKTI valmis, vikoja %d" % vikoja)
	get_tree().quit()


## Vaihe: t (s kappaleen alusta; -1 = jatka), frames ruutua mittausta, miss = horjahdus. Lopuksi kuvat ja mittarit.
func _vaihe(nm: String, t: float, frames: int, miss: bool) -> void:
	if t > -0.9:
		g.seek(t)
	worst[nm] = ["-", "-", 0.0, 0.0]
	pairs[nm] = {}
	kohde[nm] = {}
	if miss:
		g._miss()
	for i in frames:
		await get_tree().process_frame
		_measure(nm, her, i)
		for c: Node3D in [me, her]:
			for lr in ["_l", "_r"]:
				_gap(nm, "arm" + lr, c, her if c == me else me)
	var c := (me.to_global(me.bone_position("spine_02")) + her.to_global(her.bone_position("spine_02"))) * 0.5
	var ax := her.global_position - me.global_position
	var front := Vector3(ax.z, 0, -ax.x)
	Engine.time_scale = 0.0
	await Asento.views(cam, out, nm, c, 1.3, front, false)
	var lc := (me.to_global(me.bone_position("calf_l")) + her.to_global(her.bone_position("calf_l"))) * 0.5
	await Asento.views(cam, out, nm + "_jalat", lc, 0.8, front, false)
	var lf := _free_hand()
	var hc := (me.to_global(me.bone_position("hand" + lf[0])) + her.to_global(her.bone_position("hand" + lf[1]))) * 0.5
	await Asento.views(cam, out, nm + "_kadet", hc, 0.35, front, false)
	if nm.begins_with("sinikka"):
		await Asento.views(cam, out, nm + "_rinta", her.to_global(her.bone_position("spine_03")), 0.45, front, false)
	Engine.time_scale = 1.0
	_measure_shot(nm, her, true)
	var w: Array = worst[nm]
	print("PARI %s %s %s %.1f mm" % [nm, w[0], w[1], w[2] * 1000])
	var top: Array = (pairs[nm] as Dictionary).keys()
	top.sort_custom(func(x: String, y: String) -> bool: return pairs[nm][x] > pairs[nm][y])
	print("PARIT %s %s" % [nm, ", ".join(top.slice(0, 6).map(func(k: String) -> String: return "%s %.1f" % [k, pairs[nm][k] * 1000]))])
	if w[2] > RAJA:
		_vika("%s pari %.1f mm" % [nm, w[2] * 1000])
	_kasi_kadessa(nm, lf[0], lf[1])
	# Pitävät kädet (viejän selkäkäsi, seuraajan olkakäsi) koskettavat pintaa; vapaat kädet mitataan KÄSI KÄDESSÄ -rivillä.
	var lb := "_l" if lf[0] == "_r" else "_r"
	var fa := "_l" if lf[1] == "_r" else "_r"
	for ch: String in kohde[nm]:
		if ch != "me arm" + lb and ch != "pari arm" + fa:
			continue
		var gg: float = kohde[nm][ch][0]
		var mg: float = kohde[nm][ch][2] if kohde[nm][ch].size() > 2 else INF
		print("KOHDE %s %s rako %.1f mm (lähin %s), verkko %s" % [nm, ch, gg * 1000, kohde[nm][ch][1], "%.1f mm" % (mg * 1000) if mg < INF else "-"])
		if mg < INF:
			gg = mg
		if absf(gg) > RAJA:
			_vika("%s kohde %s rako %.1f mm" % [nm, ch, gg * 1000])
	for p in Contact.overlap_pairs(me, prof[me], her, prof[her]):
		if "arm" in str(p[0]) and "arm" in str(p[1]) and p[2] > RAJA:
			_vika("%s käsivarret ristissä %s %s %.1f mm" % [nm, p[0], p[1], p[2] * 1000])


## Vapaat kädet [viejän, seuraajan]: seuraaja on viejän oikealla -> viejän vasen ja seuraajan oikea (kuten PariOte.valssi).
func _free_hand() -> Array:
	var sd := (her.to_global(her.bone_position("spine_03")) - me.to_global(me.bone_position("spine_03"))).dot(PariOte.right(me))
	return ["_l", "_r"] if sd >= 0.0 else ["_r", "_l"]


## Käsi kädessä: kämmenkapselien rako (PARI-mittari), kämmenten ja sormien verkkojen lyhin väli ja kämmenten normaalit vastakkain.
func _kasi_kadessa(nm: String, lf: String, ff: String) -> void:
	var hm: Array = Contact.caps_all(me, prof[me]).filter(func(cp: Array) -> bool: return cp[0] == "hand" + lf)[0]
	var hh: Array = Contact.caps_all(her, prof[her]).filter(func(cp: Array) -> bool: return cp[0] == "hand" + ff)[0]
	var gap: float = -float(Contact._pair_depth(hm, hh)[0])
	var dot := _palm(me, lf).dot(_palm(her, ff))
	var hg := INF
	for q in _hand_pts(me, lf):
		for r in _hand_pts(her, ff):
			hg = minf(hg, q.distance_squared_to(r))
	print("KÄSI KÄDESSÄ %s me%s-pari%s kapselirako %.1f mm, verkko %.1f mm, kämmenet %.2f" % [nm, lf, ff, gap * 1000, sqrt(hg) * 1000, dot])
	if absf(gap) > RAJA or sqrt(hg) > RAJA or dot > -0.7:
		_vika("%s käsi kädessä rako %.1f mm verkko %.1f mm kämmenet %.2f" % [nm, gap * 1000, sqrt(hg) * 1000, dot])


## Kuvahetkellä: kohteen verkkorako, RANNE ja PAINUMA kuten hahmot_kontakti; SUUNTA hartialinjoista (rinnat vastakkain), koska
## suljetussa otteessa parit ovat sivuttain toisistaan eikä suunta toisen juureen tai rintaan ole suoraan edessä.
func _measure_shot(nm: String, other: Node3D, hug: bool) -> void:
	for c: Node3D in [me, other]:
		var o: Node3D = other if c == me else me
		for lr: String in ["_l", "_r"]:
			if hug:
				_gap(nm, "arm" + lr, c, o, true)
			var la := c.to_global(c.bone_position("lowerarm" + lr))
			var hd := c.to_global(c.bone_position("hand" + lr))
			var md := c.to_global(c.bone_position("middle_01" + lr))
			var ang := rad_to_deg((hd - la).angle_to(md - hd))
			print("RANNE %s %s%s %.0f astetta" % [nm, _who(c), lr, ang])
			if ang > 70.0:
				_vika("%s ranne %s%s %.0f astetta" % [nm, _who(c), lr, ang])
		var right := _right(c)
		var pel := c.to_global(c.bone_position("pelvis"))
		var fl := (c.to_global(c.bone_position("foot_l")) - pel).dot(right)
		var fr := (c.to_global(c.bone_position("foot_r")) - pel).dot(right)
		var facing := -Vector3.UP.cross(right).dot(Vector3.UP.cross(_right(o)))
		print("SUUNTA %s %s vasen jalka %.2f oikea %.2f, rinnat vastakkain %.2f" % [nm, _who(c), fl, fr, facing])
		if fl >= 0.0 or fr <= 0.0 or facing < 0.7:
			_vika("%s suunta %s (jalat ristissä tai selkä toiseen päin)" % [nm, _who(c)])
		_painuma(nm, c)


## RUUTU: 60 ruudun keskimääräinen kehysaika nuottiradan jatkona ilman testin omaa mittaustyötä.
func _ruutu(id: String) -> void:
	for i in 10:
		await get_tree().process_frame
	var sum := 0.0
	var mx := 0.0
	var t0 := Time.get_ticks_usec()
	for i in 60:
		await get_tree().process_frame
		var t := Time.get_ticks_usec()
		sum += (t - t0) / 1000.0
		mx = maxf(mx, (t - t0) / 1000.0)
		t0 = t
	print("RUUTU %s ka %.2f ms max %.2f ms" % [id, sum / 60.0, mx])
	if sum / 60.0 >= RUUTU:
		_vika("%s ruutu %.2f ms (raja %.1f)" % [id, sum / 60.0, RUUTU])


func _who(c: Node3D) -> String:
	return "me" if c == me else "pari"


## Kämmenen sisäpinnan suunta maailmassa (Pose.palm_on: oikealla -x, vasemmalla +x käden luun kehyksessä).
func _palm(c: Node3D, lr: String) -> Vector3:
	var x: Vector3 = c.global_basis * Contact._bone_xf(c, "hand" + lr).basis.x
	return (x if lr == "_l" else -x).normalized()


func _hand_pts(c: Node3D, lr: String) -> PackedVector3Array:
	var bones := ["hand" + lr]
	for f in ["thumb", "index", "middle", "ring", "pinky"]:
		for k in ["_01", "_02", "_03"]:
			bones.append(f + k + lr)
	return Pose.limb_points(c, self, bones, 1)
