extends Node3D
## Maiseman täytetalot K1–K5 (scripts/rakennukset.gd) ilman pelimaailmaa: mittaa kattokulman, räystäskorkeuden,
## mitat (mahtuuko pohjaan) ja primitiivien määrän (budjetti), ja ottaa kuvat: jokainen tyyppi edestä, sivulta ja
## ylhäältä yhteen vertailukuvaan (vertailu.png), rivi K1–K5 samassa mittakaavassa (rivi.png) ja mustina siluetteina
## (siluetit.png). Rajojen ylitys: "TESTI VIKA".
## Ajo: tools/testit/aja.sh tscn tools/testit/rakennukset_kuvat.tscn

const B := preload("res://scripts/build.gd")
const R := preload("res://scripts/rakennukset.gd")
const Taytto := preload("res://scripts/taytto.gd")
const M := preload("res://scripts/map_data.gd")

const WHITE := Color(0.95, 0.95, 0.92)
## Testitalot: tyyppi, parametrit ja hyväksymiskriteerien rajat (01-suunnitelma.md 1–6; budjetti 02-arkkitehtuuri.md).
const CASES := [
	["K1", {"l": 9.0, "d": 9.2, "wall": Color(0.9, 0.8, 0.45), "roof": Color(0.32, 0.2, 0.15), "trim": WHITE, "seed": 11},
		{"kulma": [27.0, 34.0], "raystas": [4.0, 5.5], "prim": 90}],
	["K2", {"l": 13.0, "d": 9.0, "wall": Color(0.8, 0.74, 0.62), "roof": Color(0.13, 0.13, 0.14), "trim": Color(0.28, 0.18, 0.12), "seed": 12, "carport": 1, "rima": true},
		{"kulma": [15.0, 20.0], "raystas": [2.4, 3.3], "prim": 80}],
	["K3", {"l": 3.4, "d": 4.2, "wall": Color(0.6, 0.15, 0.11), "roof": Color(0.16, 0.16, 0.17), "trim": WHITE, "seed": 13},
		{"kulma": [25.0, 35.0], "raystas": [1.8, 2.9], "prim": 40}],
	["K4", {"l": 6.0, "d": 8.5, "wall": Color(0.6, 0.55, 0.46), "roof": Color(0.5, 0.28, 0.16), "trim": Color(0.5, 0.46, 0.38), "seed": 14},
		{"kulma": [20.0, 30.0], "raystas": [2.6, 4.0], "prim": 110}],
	["K5", {"l": 11.0, "d": 7.5, "wall": Color(0.9, 0.76, 0.36), "roof": Color(0.2, 0.2, 0.21), "trim": WHITE, "seed": 15, "gate_gap": 6.0},
		{"kulma": [25.0, 30.0], "raystas": [3.0, 4.2], "prim": 120}],
	# Muunnelmat: K2 tasakatto ja peiterima, K3 harmaa rantamökin kokoinen, K1 punainen.
	["K2", {"l": 12.0, "d": 8.5, "wall": Color(0.42, 0.28, 0.18), "roof": Color(0.16, 0.16, 0.17), "trim": Color(0.9, 0.9, 0.87), "seed": 22, "flat": true, "rima": true, "carport": -1},
		{"kulma": [0.0, 0.0], "raystas": [2.4, 3.3], "prim": 80}],
	["K3", {"l": 4.6, "d": 5.6, "wall": Color(0.55, 0.52, 0.47), "roof": Color(0.45, 0.46, 0.47), "trim": Color(0.47, 0.44, 0.4), "seed": 23},
		{"kulma": [25.0, 35.0], "raystas": [1.8, 2.9], "prim": 40}],
	["K1", {"l": 8.4, "d": 8.8, "wall": Color(0.6, 0.15, 0.11), "roof": Color(0.3, 0.31, 0.33), "trim": WHITE, "seed": 21},
		{"kulma": [27.0, 34.0], "raystas": [4.0, 5.5], "prim": 90}],
]
## Isot mallit (Korjaus 2): K6 rivitalo, K7 kerrostalo, K8 halli; lyhyt ja pitkä pohja (budjetti pienimmällä ja
## suurimmalla koolla). Rajat: runko = runko-erän primitiivit (02-arkkitehtuuri.md Korjaus 2), prim = kaikki.
const BIG := [
	["K6", {"l": 16.0, "d": 10.0, "n": 2, "krs": 1, "taka": 3.0, "wall": Color(0.84, 0.68, 0.4), "roof": Color(0.12, 0.12, 0.13), "trim": Color(0.28, 0.18, 0.12), "seed": 31},
		{"kulma": [14.0, 20.0], "raystas": [2.8, 3.1], "runko": 24 + 16 * 2, "prim": 24 + 40 * 2}],
	["K6", {"l": 64.0, "d": 10.5, "n": 8, "krs": 1, "taka": 4.0, "rima": true, "wall": Color(0.42, 0.28, 0.18), "roof": Color(0.16, 0.16, 0.17), "trim": Color(0.9, 0.9, 0.87), "seed": 32},
		{"kulma": [14.0, 20.0], "raystas": [2.8, 3.1], "runko": 24 + 16 * 8, "prim": 24 + 40 * 8}],
	["K6", {"l": 32.0, "d": 10.0, "n": 4, "krs": 2, "taka": 1.0, "flat": true, "wall": Color(0.62, 0.27, 0.2), "roof": Color(0.16, 0.16, 0.17), "trim": Color(0.28, 0.18, 0.12), "seed": 33},
		{"kulma": [0.0, 0.0], "raystas": [5.5, 5.8], "runko": 24 + 16 * 4, "prim": 24 + 40 * 4}],
	["K7", {"l": 15.0, "d": 11.5, "n": 1, "krs": 3, "flat": false, "wall": Color(0.62, 0.27, 0.2), "roof": Color(0.16, 0.16, 0.17), "trim": Color(0.3, 0.3, 0.31), "seed": 41},
		{"kulma": [10.0, 14.0], "raystas": [9.0, 10.0], "runko": 30 + 22 * 1 * 3, "prim": 30 + 40 * 1 * 3}],
	["K7", {"l": 54.0, "d": 12.0, "n": 3, "krs": 2, "flat": true, "wall": Color(0.84, 0.68, 0.4), "roof": Color(0.2, 0.2, 0.21), "trim": Color(0.3, 0.3, 0.31), "seed": 42},
		{"kulma": [0.0, 0.0], "raystas": [6.0, 7.0], "runko": 30 + 22 * 3 * 2, "prim": 30 + 40 * 3 * 2}],
	["K7", {"l": 36.0, "d": 11.0, "n": 2, "krs": 2, "flat": true, "liike": true, "wall": Color(0.82, 0.8, 0.74), "roof": Color(0.2, 0.2, 0.21), "trim": Color(0.35, 0.35, 0.36), "seed": 43},
		{"kulma": [0.0, 0.0], "raystas": [6.0, 7.0], "runko": 30 + 22 * 2 * 2, "prim": 30 + 40 * 2 * 2}],
	["K8", {"l": 20.0, "d": 14.0, "v": "kone", "wall": Color(0.6, 0.15, 0.11), "roof": Color(0.16, 0.16, 0.17), "trim": Color(0.93, 0.93, 0.9), "seed": 51},
		{"kulma": [17.0, 19.0], "raystas": [4.4, 4.6], "runko": 40 + 3 * 3, "prim": 40 + 3 * 3 + 260}],
	["K8", {"l": 110.0, "d": 40.0, "v": "teollisuus", "wall": Color(0.74, 0.74, 0.72), "roof": Color(0.4, 0.41, 0.42), "trim": Color(0.45, 0.46, 0.47), "seed": 52},
		{"kulma": [5.0, 7.0], "raystas": [5.0, 6.0], "runko": 40 + 3 * 18, "prim": 40 + 3 * 18 + 260}],
	["K8", {"l": 40.0, "d": 18.0, "v": "liike", "wall": Color(0.62, 0.27, 0.2), "roof": Color(0.2, 0.2, 0.21), "trim": Color(0.3, 0.3, 0.31), "seed": 53},
		{"kulma": [0.0, 0.0], "raystas": [4.2, 5.0], "runko": 40 + 3 * 7, "prim": 40 + 3 * 7 + 260}],
	["K8", {"l": 36.0, "d": 6.0, "v": "suoja", "wall": Color(0.55, 0.52, 0.47), "roof": Color(0.4, 0.41, 0.42), "trim": Color(0.45, 0.42, 0.38), "seed": 54},
		{"kulma": [8.0, 12.0], "raystas": [3.5, 4.3], "runko": 40 + 3 * 6, "prim": 40 + 3 * 6 + 260}],
	["K8", {"l": 30.0, "d": 16.0, "v": "teollisuus", "wall": Color(0.8, 0.72, 0.55), "roof": Color(0.35, 0.36, 0.37), "trim": Color(0.5, 0.48, 0.42), "seed": 55},
		{"kulma": [10.0, 14.0], "raystas": [5.0, 6.0], "runko": 40 + 3 * 5, "prim": 40 + 3 * 5 + 260}],
]
const GAP := 40.0  # talojen väli kuvissa (yksi talo kerrallaan rajattuna)

var out := "user://rakennukset"
var cam: Camera3D
var env: Environment
var ground: MeshInstance3D
var meshes: Array[MeshInstance3D] = []
var built: Array = []  # [tyyppi, keskipiste, p, tulos, [runko- ja pienet-mesh]]
var vikoja := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.88)
	# Valaistus kuten pelissä (main.gd: AgX, valotus 1,05, kylläisyys 1,12, lämmin aurinko 1,35).
	env.ambient_light_color = Color(0.62, 0.7, 0.82)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, 200, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	ground = B.mesh(self, B.boxm(Vector3(2400, 0.1, 2400)), Vector3(100, -0.05, 900), Color(0.36, 0.5, 0.26))  # nurmi
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40.0
	for i in CASES.size():
		_build_case(CASES[i], Vector3(i * GAP, 0, 0) if i < 5 else Vector3((i - 5) * GAP, 0, GAP * 1.5))
	for j in BIG.size():
		_build_case(BIG[j], Vector3(0, 0, 160.0 + j * 150.0))
	_classify_check()
	_fill_check()
	_run.call_deferred()


## Tyypitystaulun literaalirivit (02-arkkitehtuuri.md Korjaus 2, sekstaajan pohjat dump-csv:stä): [alue, id, b, ctx, odotus].
## Odotus on luokan alku (K8 = mikä tahansa K8-variantti).
const CLASSIFY := [
	["vaala", "472392144", {"l": 256.5, "d": 86.7, "t": "school", "lv": 1}, {"gap": 5.0}, "VANHA"],
	["vaala", "534430539", {"l": 57.5, "d": 38.9, "t": "yes", "lv": 3, "r": 0.47}, {"gap": 5.0}, "VANHA"],
	["vaala", "508285475", {"l": 39.8, "d": 12.3, "t": "apartments", "lv": 2}, {"gap": 5.0}, "K7"],
	["vaala", "508285476", {"l": 54.3, "d": 19.6, "t": "yes", "lv": 1}, {"gap": 5.0}, "K8_liike"],
	["vaala", "827456101", {"l": 31.4, "d": 13.5, "t": "yes", "lv": 1}, {"gap": 5.0}, "K6"],
	["vaala", "827456164", {"l": 36.2, "d": 11.9, "t": "yes", "lv": 1}, {"gap": 5.0}, "K6"],
	["vaala", "827456093", {"l": 29.6, "d": 12.3, "t": "yes", "lv": 1}, {"gap": 5.0}, "K6"],
	["vaala", "-100567", {"l": 10.4, "d": 8.6, "t": "cabin", "lv": 2}, {"gap": -1.0}, "K1"],
	["saloinen", "1304", {"l": 115.8, "d": 46.3, "t": "yes", "lv": 1}, {"gap": -1.0}, "K8"],
	["saloinen", "298", {"l": 74.2, "d": 46.2, "t": "yes", "lv": 1}, {"gap": -1.0}, "K8"],
	["saloinen", "36", {"l": 80.2, "d": 33.0, "t": "yes", "lv": 1}, {"gap": -1.0}, "K8"],
	["saloinen", "1299", {"l": 58.1, "d": 39.9, "t": "yes", "lv": 1}, {"gap": 6.6}, "K8"],
	["saloinen", "308", {"l": 57.9, "d": 21.3, "t": "yes", "lv": 1}, {"gap": -1.0}, "K8"],
	["saloinen", "311", {"l": 30.0, "d": 21.6, "t": "yes", "lv": 1}, {"gap": -1.0}, "K8"],
	["saloinen", "1300", {"l": 96.3, "d": 41.3, "t": "industrial", "lv": 1}, {"gap": -1.0}, "K8"],
	["saloinen", "1298", {"l": 57.3, "d": 26.9, "t": "industrial", "lv": 1}, {"gap": -1.0}, "K8"],
	["saloinen", "1305", {"l": 34.4, "d": 20.9, "t": "industrial", "lv": 1}, {"gap": -1.0}, "K8"],
	["saloinen", "307", {"l": 90.8, "d": 5.5, "t": "yes", "lv": 1}, {"gap": -1.0}, "K8_suoja"],
	["saloinen", "304", {"l": 41.3, "d": 6.5, "t": "yes", "lv": 1}, {"gap": -1.0}, "K8_suoja"],
	["saloinen", "1188", {"l": 37.4, "d": 8.4, "t": "terrace", "lv": 1}, {"gap": 13.2}, "K6"],
	["saloinen", "1191", {"l": 36.8, "d": 8.2, "t": "terrace", "lv": 1}, {"gap": 5.6}, "K6"],
	["saloinen", "303", {"l": 65.9, "d": 11.5, "t": "yes", "lv": 1}, {"gap": -1.0}, "K6"],
	["saloinen", "310", {"l": 42.1, "d": 11.7, "t": "yes", "lv": 1}, {"gap": -1.0}, "K6"],
	["saloinen", "51", {"l": 29.2, "d": 11.3, "t": "yes", "lv": 1}, {"gap": 7.4}, "K6"],
	["saloinen", "17x17", {"l": 17.0, "d": 17.0, "t": "yes", "lv": 1}, {"gap": 5.0}, "JAKO"],
]


func _classify_check() -> void:
	for c: Array in CLASSIFY:
		var got := Taytto.classify(c[0], c[2], c[3])
		var exp: String = c[4]
		var ok := got.begins_with(exp)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(c[1])
		var plan: Array = Taytto.plan(c[0], c[2], c[3], rng) if got != "VANHA" else []
		var kinds: Array[String] = []
		for o: Dictionary in plan:
			kinds.append("%s%s %.1fx%.1f%s" % [o.tyyppi, ("_" + o.v) if o.v != "" else "", o.l, o.d, " piha" if o.piha else ""])
		print("RAKENNUKSET tyypitys %s %s %.1f x %.1f %s lv %d: %s (odotus %s) -> %s" % [c[0], c[1], c[2].l, c[2].d, c[2].t, c[2].lv, got, exp, ", ".join(kinds)])
		if not ok:
			_fail("tyypitys %s %s: %s, odotus %s" % [c[0], c[1], got, exp])
		if exp == "JAKO" and (plan.size() != 1 or not plan[0].piha):
			_fail("tyypitys %s %s: JAKO k = 1 ja piha odotettu, saatiin %d taloa" % [c[0], c[1], plan.size()])


## Taytto.plan kaikille Saloisten OSM-pohjille (ilman pelimaailmaa: etupiha 5 m, ei peltoa tai rantaa; keep_old-pohjat
## VANHA): jakauma K1–K8 ja VANHA, K5-osuus (2–5 %), K1/K2:n täyttöaste (ala / pohja, autokatos mukana, jos se on
## pohjassa; >= 0,80, VIKA < 0,78), jaetuissa pohjissa enintään 3 taloa ja väli >= 5,0 m, ja jokainen runko (myös
## autokatos) pohjassa local_xf:llä (+0,3 m). Oikean jakauman mittaa maisema_kuvat (D) pelimaailmassa.
func _fill_check() -> void:
	var n := {}
	var bad := 0
	var total := 0
	var close := 0
	var many := 0
	var min_gap := INF
	var fill := {"K1": [0.0, 0], "K2": [0.0, 0]}
	for b: Dictionary in M.Osm.BUILDINGS:
		var fl: float = b.l * M.SCALE
		var fd: float = b.d * M.SCALE
		var bb := {"l": fl, "d": fd, "t": b.t, "lv": b.lv}
		var ctx := {"gap": 5.0}
		if Taytto.keep_old(bb):
			n["VANHA"] = n.get("VANHA", 0) + 1
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(b.c)
		var plan: Array = Taytto.plan("saloinen", bb, ctx, rng)
		if plan.size() > Taytto.SPLIT_MAX:
			many += 1
		var xs: Array = []  # jaetun pohjan talojen [vasen, oikea] X-reuna maailmassa (kierrettynä)
		for o: Dictionary in plan:
			total += 1
			n[o.tyyppi] = n.get(o.tyyppi, 0) + 1
			if not o.tyyppi in Taytto.TYPES:
				_fail("täyte tyyppiä %s" % o.tyyppi)
				continue
			var res: Dictionary = R.build(o.tyyppi, o, B.Batch.new(), B.Batch.new(), Transform3D())
			var tx := Taytto.local_xf(o)
			var lo := INF
			var hi := -INF
			var over := false
			for k in res.foot:
				if k == "aita":
					continue  # K5:n aita menee tarkoituksella pohjan yli (kutsuja tarkistaa tilan)
				for q: Vector2 in res.foot[k]:
					var w := tx * Vector3(q.x, 0, q.y)
					lo = minf(lo, w.x)
					hi = maxf(hi, w.x)
					if absf(w.x) > fl / 2.0 + 0.3 or absf(w.z) > fd / 2.0 + 0.3:
						over = true
			xs.append([lo, hi])
			if over and k_ok(o, plan.size()):
				bad += 1
				if bad <= 5:
					print("RAKENNUKSET pohja yli: %s %s pohja %.1f x %.1f, malli %.1f x %.1f rot %.2f dx %.2f dz %.2f" % [o.tyyppi, b.c, fl, fd, o.l, o.d, o.rot, o.dx, o.dz])
			if plan.size() == 1 and o.tyyppi in fill:
				var area: float = o.l * o.d
				if fl >= 16.0 and o.carport != 0 and o.tyyppi == "K2":
					area += 3.6 * minf(o.d, 6.0)
				fill[o.tyyppi][0] += area / (fl * fd)
				fill[o.tyyppi][1] += 1
		xs.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		for i in range(1, xs.size()):
			var g: float = xs[i][0] - xs[i - 1][1]
			min_gap = minf(min_gap, g)
			if g < Taytto.SPLIT_GAP - 0.01:
				close += 1
				if close <= 5:
					print("RAKENNUKSET tontti: talojen väli %.2f m (< 5 m) %s pohja %.1f x %.1f" % [g, b.c, fl, fd])
	var parts: Array[String] = []
	for t in Taytto.TYPES + ["VANHA"]:
		parts.append("%s %d (%.1f %%)" % [t, n.get(t, 0), 100.0 * n.get(t, 0) / maxi(total, 1)])
	var f1: float = fill.K1[0] / maxi(fill.K1[1], 1)
	var f2: float = fill.K2[0] / maxi(fill.K2[1], 1)
	var f12: float = (fill.K1[0] + fill.K2[0]) / maxi(fill.K1[1] + fill.K2[1], 1)
	var k5: float = 100.0 * n.get("K5", 0) / maxi(total, 1)
	print("RAKENNUKSET täyte Saloisten OSM-pohjille: %d taloa: %s; pohjan yli %d; yli 3 taloa %d; jaettujen pohjien pienin väli %.2f m, alle 5 m %d; täyttöaste K1 %.2f K2 %.2f yhteensä %.2f; K5 %.1f %%" % [
		total, ", ".join(parts), bad, many, min_gap, close, f1, f2, f12, k5])
	if close > 0:
		_fail("%d jaetun pohjan talojen väliä alle 5 m" % close)
	if many > 0:
		_fail("%d pohjaa yli %d taloksi" % [many, Taytto.SPLIT_MAX])
	if bad > 0:
		_fail("%d täytetalon runko ei mahdu OSM-pohjaan" % bad)
	if f12 < 0.78:
		_fail("K1/K2 täyttöaste %.2f < 0,78" % f12)
	if k5 < 2.0 or k5 > 5.0:
		_fail("K5-osuus %.1f %% ei välillä 2–5 %%" % k5)


## Pohjan ylitys lasketaan kaikille paitsi K2:n autokatokselle yksittäisessä talossa (katos saa mennä pohjan yli,
## kutsuja tarkistaa tilan) ja K6:n aidoille (foot.aidat taka-alueella, taka = (fd - d) / 2).
func k_ok(o: Dictionary, k: int) -> bool:
	return not (o.tyyppi == "K2" and o.carport != 0 and k == 1 and o.dx == 0.0)


func _fail(msg: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + msg)


func _build_case(c: Array, at: Vector3) -> void:
	var t: String = c[0]
	var p: Dictionary = c[1]
	var rajat: Dictionary = c[2]
	var r := B.Batch.new()
	var sm := B.Batch.new()
	var res: Dictionary = R.build(t, p, r, sm, Transform3D(Basis(), at))
	if res.is_empty():
		print("RAKENNUKSET %s puuttuu (ei toteutettu)" % t)
		return
	var prim := r._ops.size() + sm._ops.size()
	for bt: B.Batch in [r, sm]:
		var mi := MeshInstance3D.new()
		mi.mesh = bt.commit()
		mi.material_override = B.vcol_mat()
		add_child(mi)
		meshes.append(mi)
	built.append([t, at, p, res, [meshes[meshes.size() - 2], meshes[meshes.size() - 1]]])
	# Mitat verkosta: rungon (runko-erä) ulottuvuus pohjaan nähden.
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for v: Vector3 in meshes[meshes.size() - 2].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		lo = lo.min(v - at)
		hi = hi.max(v - at)
	var m: Dictionary = res.mitat
	print("RAKENNUKSET %s: kulma %.1f° (%s), räystäs %.2f m (%s), krs %.1f, pohja %.1f x %.1f, verkko x %.2f..%.2f z %.2f..%.2f y ..%.2f, h_top %.2f, primitiivejä %d (runko %d, pienet %d; budjetti %d)" % [
		t, m.kulma, rajat.kulma, m.raystas, rajat.raystas, m.krs, p.l, p.d, lo.x, hi.x, lo.z, hi.z, hi.y, res.h_top,
		prim, r._ops.size(), sm._ops.size(), rajat.prim])
	if m.kulma < rajat.kulma[0] or m.kulma > rajat.kulma[1]:
		_fail("%s kattokulma %.1f yli rajojen %s" % [t, m.kulma, rajat.kulma])
	if m.raystas < rajat.raystas[0] or m.raystas > rajat.raystas[1]:
		_fail("%s räystäskorkeus %.2f yli rajojen %s" % [t, m.raystas, rajat.raystas])
	if rajat.has("runko") and r._ops.size() > rajat.runko:
		_fail("%s runko %d primitiiviä yli budjetin %d" % [t, r._ops.size(), rajat.runko])
	if prim > rajat.prim:
		_fail("%s primitiivejä %d yli budjetin %d" % [t, prim, rajat.prim])
	# Seinät pohjan sisään; räystäs ja oven porras saavat ulottua enintään 1,0 m yli (katos ja aita omissa pohjissaan).
	var foot: Dictionary = res.foot
	var ext := Rect2()
	var first := true
	for k in foot:
		for q: Vector2 in foot[k]:
			if first:
				ext = Rect2(q, Vector2.ZERO)
				first = false
			ext = ext.expand(q)
	if lo.y < -p.get("drop", 0.2) - 0.25:
		_fail("%s verkko %.2f m maan alla" % [t, -lo.y])
	if lo.x < ext.position.x - 1.0 or hi.x > ext.end.x + 1.0 or lo.z < ext.position.y - 1.0 or hi.z > ext.end.y + 1.0:
		_fail("%s verkko yli 1,0 m pohjan %s ulkopuolella" % [t, ext])
	var rb: PackedVector2Array = foot.runko
	var rl := rb[1].x - rb[0].x
	var rd := rb[2].y - rb[1].y
	if rl > p.l + 0.01 or rd > p.d + 0.01:
		_fail("%s runko %.2f x %.2f ei mahdu pohjaan %.2f x %.2f" % [t, rl, rd, p.l, p.d])


func _shot(name: String, from: Vector3, to: Vector3, fov := 40.0) -> Image:
	cam.fov = fov
	cam.look_at_from_position(from, to)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if name != "":
		img.save_png(out + "/" + name + ".png")
		print("RAKENNUKSET kuva " + out + "/" + name + ".png")
	return img


## Kuvat koottuna ruudukoksi (sarakkeet cols), jokainen pienennettynä 640 x 360:ksi.
func _sheet(name: String, imgs: Array, cols: int) -> void:
	var w := 640
	var h := 360
	var rows := ceili(imgs.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		var im: Image = imgs[i]
		im.convert(Image.FORMAT_RGB8)
		im.resize(w, h)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(out + "/" + name + ".png")
	print("RAKENNUKSET kuva " + out + "/" + name + ".png")


func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	var grid: Array = []
	var muunnelmat: Array = []
	var names := {}
	var iso: Array = []  # K6–K8 edestä, sivulta ja ylhäältä
	var variantit: Array = []  # K8 8 m ja 40 m
	var b_i := -1
	for b in built:
		b_i += 1
		var at: Vector3 = b[1]
		var res: Dictionary = b[3]
		var p: Dictionary = b[2]
		var nm: String = b[0]
		var seen: int = names.get(nm, 0)
		names[nm] = seen + 1
		if seen > 0:
			nm += "bcdefgh"[seen - 1]
		var s := maxf(maxf(p.l, p.d), res.h_top) + 2.0
		var mid := at + Vector3(0, res.h_top * 0.45, 0)
		var shots := [await _shot("%s_edesta" % nm, at + Vector3(s * 0.25, 2.0, -s * 2.3), mid),
			await _shot("%s_sivulta" % nm, at + Vector3(s * 2.3, 2.0, 0.01), mid),
			await _shot("%s_ylhaalta" % nm, at + Vector3(0, s * 2.6, 0.01), at)]
		if names.size() <= 5 and seen == 0:
			grid.append_array(shots)
		var vino := await _shot("%s_vino" % nm, at + Vector3(-s * 1.3, s * 0.8, -s * 1.6), mid)
		if nm.ends_with("b") and b[0] in Taytto.TYPES.slice(0, 5):
			muunnelmat.append(vino)
		if nm.begins_with("K1"):
			# Avoräystäät jalankulkijan silmin 6 m:n päästä (silmä 1,7 m): kulmasta ja päädystä (04-testi-A.md K1).
			var c := at + Vector3(p.l / 2.0, 0, 0)
			await _shot("%s_6m_kulma" % nm, c + Vector3(4.2, 1.7, -p.d / 2.0 - 4.2), c + Vector3(0, 4.6, -p.d / 4.0))
			await _shot("%s_6m_paaty" % nm, c + Vector3(6.0, 1.7, -1.5), c + Vector3(0, 5.2, 0))
		if nm.substr(0, 2) in ["K6", "K7", "K8"]:
			iso.append_array(shots)
		if nm.begins_with("K8"):
			# Variantit 8 m:n ja 40 m:n päästä julkisivun kulmasta (02-arkkitehtuuri.md Korjaus 2, testi d).
			for dist: float in [8.0, 40.0]:
				var e := at + Vector3(-p.l / 2.0, 0, -p.d / 2.0)
				variantit.append(await _shot("", e + Vector3(-dist * 0.5, 1.7 + dist * 0.15, -dist * 0.87), e + Vector3(p.l * 0.3, 2.5, p.d * 0.2)))
		if nm.begins_with("K8") and p.get("v", "kone") in ["kone", "teollisuus"]:
			# Hallin katto ja seinä kaukaa ilman pieniä (sm-erä näkyy pelissä vain alle 200 m: K8 viimeistely).
			built[b_i][4][1].visible = false
			for dist: float in [40.0, 150.0]:
				var e2 := at + Vector3(p.l * 0.3, 0, -p.d / 2.0)
				await _shot("%s_kauko_%d" % [nm, int(dist)], e2 + Vector3(-dist * 0.5, 1.7 + dist * 0.08, -dist * 0.87), at + Vector3(0, 3.0, 0), 30.0 if dist > 100.0 else 40.0)
			built[b_i][4][1].visible = true
		if nm.substr(0, 2) in ["K6", "K7", "K8"]:
			# Jalankulkijan silmin (1,7 m) 6 m:n päästä julkisivun kulmasta ja takapihan puolelta.
			var c := at + Vector3(p.l / 2.0, 0, 0)
			await _shot("%s_6m_kulma" % nm, c + Vector3(4.2, 1.7, -p.d / 2.0 - 4.2), c + Vector3(-4.0, 2.4, -p.d / 2.0))
			await _shot("%s_6m_taka" % nm, at + Vector3(p.l / 4.0, 1.7, p.d / 2.0 + 6.0), at + Vector3(p.l / 4.0 - 3.0, 1.6, p.d / 2.0))
	_sheet("vertailu", grid, 3)
	_sheet("muunnelmat", muunnelmat, 3)
	_sheet("vertailu_iso", iso, 3)
	_sheet("K8_variantit", variantit, 2)
	# Rivi K1–K5 samassa mittakaavassa: verkot siirretään hetkeksi 16 m välein riviin (muunnelmat piiloon).
	var row := mini(5, built.size())
	for i in built.size():
		for mi: MeshInstance3D in built[i][4]:
			if i < row:
				mi.position = Vector3(-built[i][1].x + i * 16.0, 0, 0)
			else:
				mi.visible = false
	var cx := (row - 1) * 8.0 + 3.0  # K5:n aita ulottuu +X:ään
	await _shot("rivi", Vector3(cx, 5.0, -74.0), Vector3(cx, 3.0, 0), 40.0)
	# Siluetit: mustat talot valkoista taivasta vasten, kamera maan tasossa (kattokulma + runko); edestä ja
	# 90° käännettyinä (jokainen talo käännetty 90° oman keskipisteensä ympäri).
	var old_bg := env.background_color
	env.background_color = Color.WHITE
	var black := B.unshaded(Color.BLACK)
	for mi in meshes:
		mi.material_override = black
	ground.visible = false
	await _shot("siluetit", Vector3(cx, 3.0, -74.0), Vector3(cx, 3.0, 0), 40.0)
	for i in row:
		for mi: MeshInstance3D in built[i][4]:
			mi.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(i * 16.0, 0, 0)) * Transform3D(Basis(), -built[i][1])
	await _shot("siluetit_90", Vector3(cx, 3.0, -74.0), Vector3(cx, 3.0, 0), 40.0)
	ground.visible = true
	env.background_color = old_bg
	for mi in meshes:
		mi.material_override = B.vcol_mat()
		mi.transform = Transform3D()
		mi.visible = true
	print("RAKENNUKSET valmis, vikoja %d" % vikoja)
	get_tree().quit()
