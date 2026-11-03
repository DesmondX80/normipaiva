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
const BASKET := Vector3(0.33, 0.19, 0.28)  # runko: leveys, seinän korkeus reunarullan keskelle, syvyys
const BASKET_HANDLE := 0.35  # kahvan laki pohjasta
const BASKET_FLOOR := 0.015
const BASKET_WALL := 0.01  # punosrivin paksuus
const BASKET_WEAVE := 0.003  # punos vuorotellen sisään ja ulos
const BASKET_RIM := 0.011  # reunarullan säde
const BASKET_ROWS := 6
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


## Pajukori: pohja, pystykepit, kuusi vaakapunosriviä (vuorotellen sisään ja ulos, kaksi sävyä, alarivit tummempia),
## reunarulla ja kaareva kahva päädystä päätyyn. Origo pohjan alapinnan keskellä.
static func _build_basket() -> Node3D:
	var kori := Node3D.new()
	kori.name = "Kori"
	var p := Makasiini.Parts.new()
	var hx := BASKET.x / 2.0 - BASKET_WALL / 2.0  # seinän keskilinja
	var hz := BASKET.z / 2.0 - BASKET_WALL / 2.0
	var top := BASKET.y
	p.box(Vector3(BASKET.x - 0.004, BASKET_FLOOR, BASKET.z - 0.004), Vector3(0, BASKET_FLOOR / 2.0, 0), WILLOW_DARK)
	for k in 5:  # pohjan punos näkyy sisältä vaaleina juovina
		var z := -hz + 0.03 + k * (2.0 * hz - 0.06) / 4.0
		p.box(Vector3(2.0 * hx - 0.02, 0.002, 0.012), Vector3(0, BASKET_FLOOR + 0.001, z), WILLOW)
	# Varjoseinä punoksen takana: punosrivien välistä ei näe läpi.
	var lin := BASKET_WALL + 0.004
	var lh := top - BASKET_FLOOR
	for sz in [-1.0, 1.0]:
		p.box(Vector3(2.0 * (hx - lin / 2.0), lh, 0.004), Vector3(0, BASKET_FLOOR + lh / 2.0, sz * (hz - lin / 2.0)), WILLOW_LINER)
	for sx in [-1.0, 1.0]:
		p.box(Vector3(0.004, lh, 2.0 * (hz - lin / 2.0)), Vector3(sx * (hx - lin / 2.0), BASKET_FLOOR + lh / 2.0, 0), WILLOW_LINER)
	# Pystykepit: kulmat ja välit, pitkällä sivulla 5, lyhyellä 4 (kulmat mukaan lukien), yhteensä 14.
	var xs: Array[float] = []
	var zs: Array[float] = []
	for i in 5:
		xs.append(-hx + i * 2.0 * hx / 4.0)
	for i in 4:
		zs.append(-hz + i * 2.0 * hz / 3.0)
	var stakes: Array[Vector2] = []
	for x in xs:
		stakes.append(Vector2(x, -hz))
		stakes.append(Vector2(x, hz))
	for i in range(1, 3):
		stakes.append(Vector2(-hx, zs[i]))
		stakes.append(Vector2(hx, zs[i]))
	for s in stakes:
		p.cyl(0.006, top - BASKET_FLOOR, Vector3(s.x, BASKET_FLOOR + (top - BASKET_FLOOR) / 2.0, s.y), WILLOW_DARK)
	# Vaakapunos: rivi kulkee vuorotellen kepin edestä ja takaa (sisään/ulos), joka toinen rivi aloittaa toisin päin.
	var rh := (top - BASKET_FLOOR) / BASKET_ROWS
	for r in BASKET_ROWS:
		var y := BASKET_FLOOR + (r + 0.5) * rh
		var shade := lerpf(0.82, 1.06, float(r) / (BASKET_ROWS - 1))  # tumma alareuna, vaalea yläreuna
		var col: Color = (WILLOW if r % 2 == 0 else WILLOW_DARK) * shade
		col.a = 1.0
		for side in 4:
			var along: Array[float] = xs if side < 2 else zs
			var fixed: float = (hz if side < 2 else hx) * (1.0 if side % 2 == 0 else -1.0)
			for i in along.size() - 1:
				var a := along[i]
				var b := along[i + 1]
				var out := BASKET_WEAVE * (1.0 if (r + i) % 2 == 0 else -1.0)
				var len := b - a + 0.004
				var mid := (a + b) / 2.0
				var size := Vector3(len, rh - 0.003, BASKET_WALL) if side < 2 else Vector3(BASKET_WALL, rh - 0.003, len)
				var pos := Vector3(mid, y, fixed + signf(fixed) * out) if side < 2 else Vector3(fixed + signf(fixed) * out, y, mid)
				p.box(size, pos, col)
	# Reunarulla: vaakalieriöt sivuilla ja pallot kulmissa.
	var rim_col := WILLOW * 1.12
	rim_col.a = 1.0
	for sz in [-1.0, 1.0]:
		p.cyl(BASKET_RIM, 2.0 * hx, Vector3(0, top, sz * hz), rim_col, Basis(Vector3(0, 0, 1), PI / 2.0))
	for sx in [-1.0, 1.0]:
		p.cyl(BASKET_RIM, 2.0 * hz, Vector3(sx * hx, top, 0), rim_col, Basis(Vector3(1, 0, 0), PI / 2.0))
		for sz in [-1.0, 1.0]:
			p.ball(BASKET_RIM, Vector3(sx * hx, top, sz * hz), rim_col)
	# Kahva: kaari päädystä päätyyn (XY-taso) lyhyistä lieriöistä yhdestä kaarifunktiosta, kääre kahdella sävyllä;
	# päissä pystyosa, joka laskeutuu päätyseinän punokseen.
	var arc := func(t: float) -> Vector3:
		var a := PI * t
		return Vector3(-cos(a) * hx, top + sin(a) * (BASKET_HANDLE - 0.01 - top), 0)
	var segs := 14
	var hr := 0.009
	for k in segs:
		var p0: Vector3 = arc.call(float(k) / segs)
		var p1: Vector3 = arc.call(float(k + 1) / segs)
		var d := p1 - p0
		var bas := Basis(Vector3(0, 0, 1), atan2(d.y, d.x) - PI / 2.0)
		p.cyl(hr, d.length() + 0.002, (p0 + p1) / 2.0, WILLOW if k % 2 == 0 else WILLOW_DARK, bas)
		if k > 0:
			p.ball(hr, p0, WILLOW)
	for sx in [-1.0, 1.0]:
		p.cyl(hr, 0.07, Vector3(sx * hx, top - 0.035, 0), WILLOW_DARK)
	p.commit(kori)
	return kori


## Korin sisämitat laskettuna seinän ja varjoseinän paksuudesta: puolileveys x, puolisyvyys z (sisäpinnat).
static func basket_inner() -> Vector2:
	var lin := BASKET_WALL + 0.004
	return Vector2(BASKET.x / 2.0 - BASKET_WALL / 2.0 - lin, BASKET.z / 2.0 - BASKET_WALL / 2.0 - lin)


## Reunarullan yläpinta korin pohjasta.
static func basket_rim_top() -> float:
	return BASKET.y + BASKET_RIM


## Mustikkatäyte korin sisällä: tumma täyttö pohjasta, litistetty keko ja tiivis marjakerros sen pinnalla. Mitat korin
## sisämitoista: täyte ei kosketa seiniä ja ylin marja jää 1 cm reunarullan yläpinnan alle.
static func _build_berries() -> Node3D:
	var n := Node3D.new()
	n.name = "Marjat"
	var p := Makasiini.Parts.new()
	var inner := basket_inner() - Vector2(0.004, 0.004)
	var crown := basket_rim_top() - 0.01 - BERRY_R  # marjojen keskipisteiden ylin korkeus
	var cap_h := 0.025
	var y_f := crown - cap_h  # keon kanta = täytön yläpinta
	var fill_h := y_f - BASKET_FLOOR
	p.box(Vector3(inner.x * 2.0, fill_h, inner.y * 2.0), Vector3(0, BASKET_FLOOR + fill_h / 2.0, 0), BERRY_DEEP)
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
