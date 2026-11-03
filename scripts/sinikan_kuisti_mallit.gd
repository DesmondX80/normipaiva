extends RefCounted
## Sinikan kuistin mallit (world.gd _build_neighbors): paperilappu ovessa, pajukori portaalla, korin mustikkatäyte ja
## piirakka vadilla. Juuren kehys on oven kohta talon kehyksessä: origo oven keskellä julkisivun tasossa talon
## pohjan korkeudella, -Z = ulos (kuistille päin), +X = talon x-akseli. Mitat (m) tulevat world.gd:n ovivakioista:
##   leaf_front: ovilehden etupinnan z, leaf_half: lehden puolileveys, leaf_y: lehden ala- ja yläreuna (Vector2),
##   step_top: portaan yläpinta, step_half: portaan puolileveys, step_z: portaan näkyvä etu- ja takareuna (Vector2).
## Palat ovat umpinaisia ja yhdistetään väreittäin (makasiini.gd Parts), joten jokainen malli on muutama piirtokutsu.

const B := preload("res://scripts/build.gd")
const Makasiini := preload("res://scripts/makasiini.gd")

const INK := Color(0.16, 0.18, 0.42)  # note.gd INK: sama kuulakärkikynä kuin Päivin lapussa
const PAPER := Color(0.9, 0.89, 0.83)
const TAPE := Color(0.92, 0.89, 0.74)
const PAPER_SIZE := Vector2(0.30, 0.21)  # A4:n puolikas vaakaan
const PAPER_T := 0.002
const PAPER_Y := 1.50  # lapun keskikohta lehdellä
const PAPER_TILT := -2.0  # asteina: käsin teipattu, ei aivan suorassa
const PAPER_MARGIN := 0.02
const TAPE_GAP := 0.0005  # teippi paperin edessä
const TAPE_T := 0.0005
const LABEL_GAP := 0.0015  # teksti paperin edessä
const LABEL_PX := 0.0005  # m per fonttipikseli
const FONT_MAX := 48
const FONT_MIN := 20
const BASKET_AT := Vector3(0.55, 0.0, -0.50)  # korin pohjan keskikohta (y = step_top)
const PIE_AT := Vector3(-0.55, 0.0, -0.50)
## Pajukori (esikuva Prisma House -pajukori 33 × 28 × 35 cm, korkea kahva): pitkä sivu X, kahva päädystä päätyyn.
## Runko on pyöristetty suorakaide (superellipsi), joka kapenee reunasta pohjaan.
const BASKET := Vector3(0.33, 0.19, 0.28)  # runko: leveys, seinän korkeus reunarullan keskelle, syvyys
const BASKET_BASE := Vector2(0.25, 0.20)  # pohjan leveys ja syvyys seinän keskilinjalla
const BASKET_ROUND := 4.0  # superellipsin eksponentti: 2 = ellipsi, suurempi = kulmikkaampi
const BASKET_HANDLE := 0.35  # kahvan laki pohjasta
const BASKET_FLOOR := 0.015
const BASKET_STAKES := 24  # pystykepit; parillinen, jotta punos sulkeutuu kierroksen jälkeen
const BASKET_STAKE_R := 0.0035
const BASKET_STRAND := 0.0028  # punosnauhan puolipaksuus seinän normaalin suuntaan
const BASKET_WEAVE := BASKET_STAKE_R + BASKET_STRAND  # nauha kiertää kepin edestä ja takaa: ±6,3 mm
const BASKET_LINER := BASKET_WEAVE + BASKET_STRAND + 0.001  # varjoseinä punoksen takana (sisään seinälinjasta)
const BASKET_RIM := 0.011  # reunarullan säde
const BASKET_ROWS := 10
const WILLOW := Color(0.74, 0.57, 0.33)
const WILLOW_DARK := Color(0.6, 0.43, 0.24)
const WILLOW_LINER := Color(0.36, 0.25, 0.14)  # punoksen takana näkyvä varjo
const BERRY := Color(0.17, 0.2, 0.42)
const BERRY_BLOOM := Color(0.36, 0.42, 0.62)  # mustikan vahakerroksen huurre
const BERRY_DEEP := Color(0.08, 0.09, 0.22)
const BERRY_R := 0.009
const PLATE_R := 0.15
const PLATE_H := 0.012
const PIE_R := 0.12
const PIE_H := 0.035
const CRUST := Color(0.83, 0.6, 0.3)
const CRUST_DARK := Color(0.62, 0.4, 0.18)
const CRUST_LIGHT := Color(0.93, 0.74, 0.44)


## Rakentaa kaikki mallit taloon (house) oven kohdalle (door_base talon kehyksessä). Palauttaa
## {root, lappu, kori, marjat, piirakka}; lappu, marjat ja piirakka ovat aluksi piilossa.
static func build(house: Node3D, door_base: Vector3, m: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "SinikanKuisti"
	root.position = door_base
	house.add_child(root)
	var lappu := _build_lappu(m)
	root.add_child(lappu)
	lappu.visible = false
	var step_top: float = m.step_top
	var kori := _build_basket()
	kori.position = BASKET_AT + Vector3(0, step_top, 0)
	root.add_child(kori)
	var marjat := _build_berries()
	kori.add_child(marjat)
	marjat.visible = false
	var piirakka := _build_pie()
	piirakka.position = PIE_AT + Vector3(0, step_top, 0)
	root.add_child(piirakka)
	piirakka.visible = false
	return {"root": root, "lappu": lappu, "kori": kori, "marjat": marjat, "piirakka": piirakka}


## Lapun teksti paperiin: fonttikoko pienenee FONT_MAX:sta, kunnes rivitetty teksti mahtuu marginaalien sisään.
## Palauttaa false, jos ei mahdu pienimmälläkään (teksti jää silloin FONT_MIN-kokoon).
static func set_lappu_text(lappu: Node3D, text: String) -> bool:
	var label := lappu.get_node("Teksti") as Label3D
	label.text = text
	var room := (PAPER_SIZE - Vector2(PAPER_MARGIN, PAPER_MARGIN) * 2.0) / LABEL_PX
	var size := FONT_MAX
	while size >= FONT_MIN:
		if text_size(label, size).y <= room.y:
			label.font_size = size
			return true
		size -= 2
	label.font_size = FONT_MIN
	return false


## Rivitetyn tekstin koko pikseleinä annetulla fonttikoolla (sama rivitys kuin Label3D:llä).
static func text_size(label: Label3D, size: int) -> Vector2:
	return label.font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, label.width, size, -1,
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)


## Paperi takapinta lehden pinnassa, teipinpalat kulmissa ja käsialateksti paperin pinnalla. Origo paperin
## takapinnan keskellä; -Z ulos.
static func _build_lappu(m: Dictionary) -> Node3D:
	var lappu := Node3D.new()
	lappu.name = "Lappu"
	lappu.position = Vector3(0, PAPER_Y, m.leaf_front)
	lappu.rotation.z = deg_to_rad(PAPER_TILT)
	var p := Makasiini.Parts.new()
	p.box(Vector3(PAPER_SIZE.x, PAPER_SIZE.y, PAPER_T), Vector3(0, 0, -PAPER_T / 2.0), PAPER)
	# Teipinpalat kulmien yli 45°:n kulmassa (puolet paperilla, puolet ovessa ei näy, koska teippi on paperin tasossa).
	var tz := -PAPER_T - TAPE_GAP - TAPE_T / 2.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := Vector3(sx * (PAPER_SIZE.x / 2.0 - 0.012), sy * (PAPER_SIZE.y / 2.0 - 0.012), tz)
			p.box(Vector3(0.055, 0.018, TAPE_T), c, TAPE, Basis(Vector3(0, 0, 1), sx * sy * PI / 4.0))
	p.commit(lappu)
	var label := Label3D.new()
	label.name = "Teksti"
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bradley Hand", "Segoe Print", "Comic Sans MS", "Chalkboard SE", "Marker Felt",
		"Noteworthy", "sans-serif"])  # note.gd:27
	label.font = font
	label.font_size = FONT_MAX
	label.pixel_size = LABEL_PX
	label.modulate = INK
	label.outline_size = 0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = (PAPER_SIZE.x - 2.0 * PAPER_MARGIN) / LABEL_PX
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.offset = Vector2(-label.width / 2.0, 0)  # LEFT ankkuroi tekstin vasemman reunan origoon: siirto keskelle
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.shaded = true
	label.position = Vector3(0, 0, -PAPER_T - LABEL_GAP)
	label.rotation.y = PI  # Label3D katsoo +Z:aan, ulos on -Z
	lappu.add_child(label)
	return lappu


## Pajukori: pohja jalkarenkaineen ja punottuine renkaineen, 24 pystykeppiä, kymmenen punosnauhaa, jotka kiertävät
## keppejä vuorotellen edestä ja takaa (joka toinen rivi päinvastoin), kierretty reunarulla ja kaareva kahva päädystä
## päätyyn kääreineen. Yksi verkko pistevärein: nauhan yläpinta vaaleampi, alapinta tummempi, alarivit tummempia.
## Origo pohjan alapinnan keskellä.
static func _build_basket() -> Node3D:
	var kori := Node3D.new()
	kori.name = "Kori"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := BASKET.y
	var ring := 96
	# Pohjalevy ja varjoseinä punoksen takana (kumpaankin suuntaan näkyvä), ettei punosrivien välistä näe läpi.
	_disc(st, BASKET_FLOOR, -BASKET_LINER, Vector3.UP, WILLOW_DARK, ring)
	_disc(st, 0.0, 0.0, Vector3.DOWN, WILLOW_DARK, ring)
	for side in [-1.0, 1.0]:
		_band(st, BASKET_FLOOR, top, -BASKET_LINER, side, WILLOW_LINER, ring)
	# Pohjan punos ylhäältä: sisäkkäiset nauharenkaat. Jalkarengas pohjan ulkoreunalla (alapinta y = 0).
	for k in 3:
		var f := 0.3 + 0.25 * k
		var pts: Array[Vector3] = []
		var outs: Array[Vector3] = []
		for i in ring:
			var w := _wall(float(i) / ring, BASKET_FLOOR, -BASKET_LINER)
			pts.append(Vector3(w.x * f, BASKET_FLOOR + 0.001, w.z * f))
			outs.append(Vector3.UP)
		_tube(st, pts, outs, 0.002, 0.005, WILLOW, true)
	var foot_r := 0.0075
	_tube_ring(st, foot_r, foot_r * 0.4, foot_r, WILLOW_DARK, ring)
	# Pystykepit seinälinjalla pohjasta reunarullaan.
	for k in BASKET_STAKES:
		var s := float(k) / BASKET_STAKES
		var pts: Array[Vector3] = [_wall(s, foot_r, 0.0), _wall(s, top, 0.0)]
		var o := _wall_out(s, top)
		_tube(st, pts, [o, o] as Array[Vector3], BASKET_STAKE_R, BASKET_STAKE_R, WILLOW_DARK, false, 6)
	# Punosnauhat: rivin r siirtymä seinän normaalin suuntaan cos(π N s + π r) * BASKET_WEAVE, eli kepin k kohdalla
	# vuorotellen +WEAVE (kepin edessä) ja -WEAVE (takana).
	var rh := (top - BASKET_RIM - BASKET_FLOOR) / BASKET_ROWS
	var tones: Array[Color] = [WILLOW, WILLOW_DARK.lerp(WILLOW, 0.4), WILLOW.lerp(Color(0.8, 0.66, 0.42), 0.5)]
	var samples := BASKET_STAKES * 6
	for r in BASKET_ROWS:
		var y := BASKET_FLOOR + (r + 0.5) * rh
		var shade := lerpf(0.84, 1.06, float(r) / (BASKET_ROWS - 1))  # tumma alareuna, vaalea yläreuna
		var col: Color = tones[r % 3] * shade
		col.a = 1.0
		var pts: Array[Vector3] = []
		var outs: Array[Vector3] = []
		for i in samples:
			var s := float(i) / samples
			var off := cos(PI * BASKET_STAKES * s + PI * r) * BASKET_WEAVE
			pts.append(_wall(s, y, off))
			outs.append(_wall_out(s, y))
		_tube(st, pts, outs, BASKET_STRAND, rh * 0.47, col, true, 6)
	# Reunarulla ja sen ympäri kiertyvät kaksi pajua.
	var rim_col := WILLOW * 1.1
	rim_col.a = 1.0
	_tube_ring(st, top, 0.0, BASKET_RIM, rim_col, samples)
	var rim_pts: Array[Vector3] = []
	var rim_outs: Array[Vector3] = []
	for i in samples + 1:
		var s := float(i) / samples
		rim_pts.append(_wall(s, top, 0.0))
		rim_outs.append(_wall_out(s, top))
	_wrap(st, rim_pts, rim_outs, BASKET_RIM, 0.0035, 0.03, WILLOW, true)
	# Kahva: jalat päätyjen keppien (s = 0 ja 0,5) kohdalla seinässä, kaari XY-tasossa yhdestä kaarifunktiosta,
	# kaksi kiertyvää kääreoksaa. Laki (kääre mukaan lukien) = BASKET_HANDLE.
	var hr := 0.008
	var wr := 0.0035
	var hx := _wall(0.0, top, 0.0).x
	var crown := BASKET_HANDLE - hr - wr
	var hp: Array[Vector3] = []
	for k in 5:
		hp.append(_wall(0.5, top - 0.08 + 0.02 * k, 0.0))
	for k in range(1, 40):
		var a := PI * k / 40.0
		hp.append(Vector3(-cos(a) * hx, top + sin(a) * (crown - top), 0))
	for k in 5:
		hp.append(_wall(0.0, top - 0.02 * k, 0.0))
	var ho: Array[Vector3] = []
	for q in hp:
		ho.append(Vector3(0, 0, 1))
	_tube(st, hp, ho, hr, hr, WILLOW_DARK * 1.05, false)
	# Kääre vain kaaressa: seinän sisällä se pistäisi varjoseinän läpi.
	_wrap(st, hp.slice(4, hp.size() - 4), ho.slice(4, ho.size() - 4), hr, wr, 0.04, WILLOW * 1.08, false)
	st.index()  # samat kärkipisteet yhteen: verkko kevyempi piirtää
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = B.vcol_srgb_mat()
	kori.add_child(mi)
	print_verbose("KORI kärkipisteitä %d" % (mi.mesh as ArrayMesh).surface_get_array_len(0))
	return kori


## Rungon poikkileikkaus korkeudella y: superellipsin puoliakselit seinän keskilinjalla, pohjasta reunaan lineaarisesti.
static func _half_at(y: float) -> Vector2:
	var t := clampf(y / BASKET.y, 0.0, 1.0)
	return (BASKET_BASE / 2.0).lerp(Vector2(BASKET.x, BASKET.z) / 2.0 - Vector2(0.009, 0.009), t)


static func _rim_xz(th: float, half: Vector2) -> Vector2:
	var e := 2.0 / BASKET_ROUND
	var c := cos(th)
	var s := sin(th)
	return Vector2(half.x * signf(c) * pow(absf(c), e), half.y * signf(s) * pow(absf(s), e))


static var _theta_lut := PackedFloat32Array()


## Superellipsin kulma kierroksen osuudelle s (0..1, +X-päädystä alkaen), tasaisella kaarenpituudella: kepit ja
## punoksen aalto jakautuvat tasaisesti myös kulmissa.
static func _theta(s: float) -> float:
	if _theta_lut.is_empty():
		var hv := _half_at(BASKET.y)
		var n := 2048
		var cum := PackedFloat32Array([0.0])
		var prev := _rim_xz(0.0, hv)
		for i in range(1, n + 1):
			var q := _rim_xz(TAU * i / n, hv)
			cum.append(cum[i - 1] + prev.distance_to(q))
			prev = q
		var j := 0
		for k in 513:
			var target := cum[n] * k / 512.0
			while j < n - 1 and cum[j + 1] < target:
				j += 1
			var f := clampf((target - cum[j]) / maxf(cum[j + 1] - cum[j], 1e-9), 0.0, 1.0)
			_theta_lut.append(TAU * (j + f) / n)
	var x := fposmod(s, 1.0) * 512.0
	var i := mini(int(x), 511)
	return lerpf(_theta_lut[i], _theta_lut[i + 1], x - i)


## Seinän vaakasuora ulkonormaali kohdassa s korkeudella y.
static func _wall_out(s: float, y: float) -> Vector3:
	var h := _half_at(y)
	var p := _rim_xz(_theta(s), h)
	var g := Vector2(signf(p.x) * pow(absf(p.x / h.x), BASKET_ROUND - 1.0) / h.x,
		signf(p.y) * pow(absf(p.y / h.y), BASKET_ROUND - 1.0) / h.y).normalized()
	return Vector3(g.x, 0, g.y)


## Seinän piste kohdassa s korkeudella y, off metriä seinälinjasta ulospäin (negatiivinen = sisään).
static func _wall(s: float, y: float, off: float) -> Vector3:
	var p := _rim_xz(_theta(s), _half_at(y))
	return Vector3(p.x, y, p.y) + _wall_out(s, y) * off


## Kolmio, kiertosuunta normaalin mukaan (Godot: myötäpäivään edestä katsottuna = etupinta).
static func _tri(st: SurfaceTool, v: Array[Vector3], nr: Array[Vector3], c: Array[Color]) -> void:
	var order := [0, 1, 2]
	if (v[1] - v[0]).cross(v[2] - v[0]).dot(nr[0] + nr[1] + nr[2]) > 0.0:
		order = [0, 2, 1]
	for i in order:
		st.set_color(c[i])
		st.set_normal(nr[i])
		st.add_vertex(v[i])


## Pistevärin sävytys normaalin mukaan: yläpinta vaalea, alapinta tumma.
static func _lit(col: Color, nrm: Vector3) -> Color:
	var c := col * lerpf(0.72, 1.14, nrm.y * 0.5 + 0.5)
	c.a = 1.0
	return c


## Putki pisteiden läpi, poikkileikkaus ellipsi: r_out pisteen outs-suuntaan, r_up sitä ja putkea vastaan kohtisuoraan.
static func _tube(st: SurfaceTool, pts: Array[Vector3], outs: Array[Vector3], r_out: float, r_up: float, col: Color,
		closed: bool, sides := 8) -> void:
	var n := pts.size()
	var vs: Array = []
	var ns: Array = []
	for i in n:
		var a := pts[(i - 1 + n) % n] if closed or i > 0 else pts[i]
		var b := pts[(i + 1) % n] if closed or i < n - 1 else pts[i]
		var t := (b - a).normalized()
		var o := (outs[i] - t * outs[i].dot(t)).normalized()
		var u := t.cross(o)
		var rv: Array[Vector3] = []
		var rn: Array[Vector3] = []
		for k in sides:
			var f := TAU * k / sides
			rv.append(pts[i] + o * cos(f) * r_out + u * sin(f) * r_up)
			rn.append((o * cos(f) / r_out + u * sin(f) / r_up).normalized())
		vs.append(rv)
		ns.append(rn)
	for i in (n if closed else n - 1):
		var j := (i + 1) % n
		for k in sides:
			var k2 := (k + 1) % sides
			var qv: Array[Vector3] = [vs[i][k], vs[j][k], vs[j][k2], vs[i][k2]]
			var qn: Array[Vector3] = [ns[i][k], ns[j][k], ns[j][k2], ns[i][k2]]
			var qc: Array[Color] = []
			for q in qn:
				qc.append(_lit(col, q))
			_tri(st, [qv[0], qv[1], qv[2]], [qn[0], qn[1], qn[2]], [qc[0], qc[1], qc[2]])
			_tri(st, [qv[0], qv[2], qv[3]], [qn[0], qn[2], qn[3]], [qc[0], qc[2], qc[3]])


## Seinälinjaa kiertävä rengasputki korkeudella y, off ulospäin.
static func _tube_ring(st: SurfaceTool, y: float, off: float, r: float, col: Color, count: int) -> void:
	var pts: Array[Vector3] = []
	var outs: Array[Vector3] = []
	for i in count:
		var s := float(i) / count
		pts.append(_wall(s, y, off))
		outs.append(_wall_out(s, y))
	_tube(st, pts, outs, r, r, col, true)


## Kaksi oksaa kiertää keskiputken (pts, säde r) ympäri kerran per pitch metriä.
static func _wrap(st: SurfaceTool, pts: Array[Vector3], outs: Array[Vector3], r: float, wr: float, pitch: float,
		col: Color, closed: bool) -> void:
	var dense := 12
	for strand in 2:
		var hp: Array[Vector3] = []
		var ho: Array[Vector3] = []
		var dist := 0.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var t := (b - a).normalized()
			var seg := a.distance_to(b)
			var steps := maxi(1, int(ceil(seg / pitch * dense)))
			for k in steps:
				var f := float(k) / steps
				var c := a.lerp(b, f)
				var o := outs[i].lerp(outs[i + 1], f)
				o = (o - t * o.dot(t)).normalized()
				var u := t.cross(o)
				var ang := TAU * (dist + seg * f) / pitch + PI * strand
				hp.append(c + (o * cos(ang) + u * sin(ang)) * r)
				ho.append(o * cos(ang) + u * sin(ang))
			dist += seg
		_tube(st, hp, ho, wr, wr, col, closed, 6)


## Vaakasuora levy rungon muodossa korkeudella y (off seinälinjasta), normaali nrm.
static func _disc(st: SurfaceTool, y: float, off: float, nrm: Vector3, col: Color, count: int) -> void:
	var c := _lit(col, nrm)
	for i in count:
		var a := _wall(float(i) / count, y, off)
		var b := _wall(float(i + 1) / count, y, off)
		_tri(st, [Vector3(0, y, 0), a, b], [nrm, nrm, nrm], [c, c, c])


## Pystynauha seinälinjan suuntaisena (off) korkeudelta y0 korkeudelle y1; side +1 = normaali ulos, -1 = sisään.
static func _band(st: SurfaceTool, y0: float, y1: float, off: float, side: float, col: Color, count: int) -> void:
	for i in count:
		var s0 := float(i) / count
		var s1 := float(i + 1) / count
		var v: Array[Vector3] = [_wall(s0, y0, off), _wall(s1, y0, off), _wall(s1, y1, off), _wall(s0, y1, off)]
		var n0 := _wall_out(s0, y0) * side
		var n1 := _wall_out(s1, y0) * side
		var c0 := _lit(col, n0)
		_tri(st, [v[0], v[1], v[2]], [n0, n1, n1], [c0, c0, c0])
		_tri(st, [v[0], v[2], v[3]], [n0, n1, n0], [c0, c0, c0])


## Korin sisämitat varjoseinän sisäpintaan korkeudella y: puolileveys x, puolisyvyys z (superellipsin puoliakselit).
static func basket_inner_at(y: float) -> Vector2:
	return _half_at(y) - Vector2(BASKET_LINER, BASKET_LINER)


## Sisämitat reunan korkeudella (suurimmat; runko kapenee alaspäin).
static func basket_inner() -> Vector2:
	return basket_inner_at(BASKET.y)


## Reunarullan yläpinta korin pohjasta.
static func basket_rim_top() -> float:
	return BASKET.y + BASKET_RIM


## Mustikkatäyte korin sisällä: tumma täyttö pohjasta (kapenee rungon mukana), litistetty keko ja tiivis marjakerros sen pinnalla. Mitat korin
## sisämitoista: täyte ei kosketa seiniä ja ylin marja jää 1 cm reunarullan yläpinnan alle.
static func _build_berries() -> Node3D:
	var n := Node3D.new()
	n.name = "Marjat"
	var p := Makasiini.Parts.new()
	var crown := basket_rim_top() - 0.01 - BERRY_R  # marjojen keskipisteiden ylin korkeus
	var cap_h := 0.025
	var y_f := crown - cap_h  # keon kanta = täytön yläpinta
	var inner := basket_inner_at(y_f) - Vector2(0.004, 0.004)
	# Täyttö seuraa kapenevaa runkoa 4 mm varjoseinän sisäpuolella.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_band(st, BASKET_FLOOR, y_f, -BASKET_LINER - 0.004, 1.0, BERRY_DEEP, 64)
	_disc(st, y_f, -BASKET_LINER - 0.004, Vector3.UP, BERRY_DEEP, 64)
	var fill := MeshInstance3D.new()
	fill.mesh = st.commit()
	fill.material_override = B.vcol_srgb_mat()
	n.add_child(fill)
	p.add(B.sphere(1.0, 16), Transform3D(Basis.from_scale(Vector3(inner.x, cap_h, inner.y)), Vector3(0, y_f, 0)),
		BERRY_DEEP)
	# Marjat tiiviisti keon pinnalle (auringonkukkakierre ellipsiin), puoliksi upoksissa; kolme sävyä.
	var count := 140
	var dark := BERRY.darkened(0.25)
	for k in count:
		var t := sqrt((k + 0.5) / count) * 0.97
		var a := k * 2.39996
		var u := cos(a) * t
		var v := sin(a) * t
		var x := u * (inner.x - BERRY_R)
		var z := v * (inner.y - BERRY_R)
		var y := y_f + cap_h * sqrt(maxf(1.0 - u * u - v * v, 0.0)) - BERRY_R * 0.3
		p.ball(BERRY_R, Vector3(x, minf(y, crown), z), BERRY_BLOOM if k % 4 == 0 else (dark if k % 3 == 0 else BERRY))
	p.commit(n)
	return n


## Mustikkapiirakka vadilla: valkoinen vati sinisellä reunalla, kullanruskea pohja, sininen täyte, ristikkorimat
## ja painettu reunus. Origo vadin alapinnan keskellä.
static func _build_pie() -> Node3D:
	var n := Node3D.new()
	n.name = "Piirakka"
	var p := Makasiini.Parts.new()
	# Jalka ja levenevä runko valkoisina, päällä sininen reunalautanen ja sen sisällä 1 mm korkeampi valkoinen
	# pohja (ei samassa tasossa, ettei pinta värise).
	p.cyl(PLATE_R - 0.01, PLATE_H * 0.5, Vector3(0, PLATE_H * 0.25, 0), Color(0.86, 0.86, 0.84))
	p.add(B.cyl(PLATE_R, PLATE_R - 0.012, PLATE_H * 0.3, 24), Transform3D(Basis(), Vector3(0, PLATE_H * 0.65, 0)),
		Color(0.96, 0.96, 0.94))
	p.add(B.cyl(PLATE_R + 0.001, PLATE_R + 0.001, 0.003, 24), Transform3D(Basis(), Vector3(0, PLATE_H - 0.0025, 0)),
		Color(0.25, 0.4, 0.75))
	p.add(B.cyl(PLATE_R - 0.018, PLATE_R - 0.018, 0.002, 24), Transform3D(Basis(), Vector3(0, PLATE_H - 0.001, 0)),
		Color(0.96, 0.96, 0.94))
	var y0 := PLATE_H
	var crust_h := PIE_H - 0.008
	p.add(B.cyl(PIE_R, PIE_R - 0.006, crust_h * 0.5, 24), Transform3D(Basis(), Vector3(0, y0 + crust_h * 0.25, 0)),
		CRUST_DARK)
	p.add(B.cyl(PIE_R, PIE_R, crust_h * 0.5, 24), Transform3D(Basis(), Vector3(0, y0 + crust_h * 0.75, 0)), CRUST)
	var ftop := y0 + crust_h
	p.add(B.cyl(PIE_R - 0.012, PIE_R - 0.012, 0.004, 24), Transform3D(Basis(), Vector3(0, ftop + 0.002, 0)), BERRY)
	# Ristikkorimat: kolme kumpaankin suuntaan, pituus jänteen mukaan, ettei rima ylitä reunusta.
	var strip := Vector2(0.014, 0.005)
	for dir in 2:
		for k in 3:
			var off := (k - 1) * 0.055
			var half := sqrt(maxf((PIE_R - 0.012) * (PIE_R - 0.012) - off * off, 0.0))
			var size := Vector3(2.0 * half, strip.y, strip.x) if dir == 0 else Vector3(strip.x, strip.y, 2.0 * half)
			var pos := Vector3(0, ftop + 0.004 + strip.y / 2.0 + dir * 0.001, off) if dir == 0 \
				else Vector3(off, ftop + 0.004 + strip.y / 2.0 + dir * 0.001, 0)
			p.box(size, pos, CRUST_LIGHT)
	# Painettu reunus: litistettyjä palloja kehällä.
	for k in 22:
		var a := TAU * k / 22.0
		p.ball(0.013, Vector3(cos(a) * (PIE_R - 0.008), ftop + 0.002, sin(a) * (PIE_R - 0.008)),
			CRUST_LIGHT if k % 2 == 0 else CRUST, Vector3(1.0, 0.55, 1.0))
	p.commit(n)
	return n
