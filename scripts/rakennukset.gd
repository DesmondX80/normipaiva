extends RefCounted
## Maiseman täytetalot (Saloinen ja Vaala): kahdeksan tunnistettavaa tyyppiä esikuvien mukaan
## (.claude/tyo/rakennukset-maisema/01-esikuvat.md ja 02-arkkitehtuuri.md Korjaus 2; docs/pelin-sisalto.md).
##   K1 rintamamiestalo, K2 matala 70–80-luvun omakotitalo, K3 aitta, K4 lato, K5 Raahen keltainen puutalo,
##   K6 rivitalo, K7 kerrostalo, K8 halli (kone, teollisuus, liike, suoja). K6–K8 venyvät pohjan pituuteen
##   toistamalla moduulia (asunto, porrashuone, kehäväli); harja X:n suuntainen ja -Z julkisivu kuten K2:ssa.
## Osat lisätään kutsujan lohkoeriin (B.Batch): runko = näkyy kauas (seinät, katto, ikkunalasit ja -puitteet, ovi),
## pienet = lähiyksityiskohdat (kattokannattajat, rimat, ikkunanpuitteiden välipuut), joille kutsuja antaa
## visibility_range_endin. Kaikki mitat lasketaan pohjasta (l, d) ja kattokulmasta, ei kiinteistä koordinaateista.
##
## Paikallinen kehys (xf): -Z = julkisivu (tie tai ranta), X = pituus l, Z = syvyys d, y = 0 pohjan korkein maanpinta.
## Talo mahtuu aina pohjan l x d sisään (myös porstua); vain K2:n autokatos (carport) ja K5:n aita (gate_gap) menevät
## pohjan yli, ja ne palautetaan foot-sanakirjassa erikseen, jotta kutsuja voi tarkistaa niiden tilan.
## K1, K2 ja K5: harja X:n suuntainen (pitkä räystässivu tielle). K3 ja K4: harja Z:n suuntainen, ovi -Z-päädyssä.
##
## build(tyyppi, p, runko, pienet, xf) -> {door, foot, shapes, h_top}
##   p: l, d, wall, roof, trim, seed (pakolliset); drop (sokkelin syvyys y = 0:n alle, rinnetontti; oletus 0,2);
##      K2: flat (bool), carport (-1 vasen, 0 ei, 1 oikea); K5: gate_gap (aidan pituus talon +X-päädystä julkisivun
##      linjassa, 0 = ei aitaa).
##   door: oven edusta (paikallinen Vector3, y = 0) tai Vector3.INF, jos ovea ei käytetä (K3, K4).
##   foot: {"runko": PackedVector2Array (x, z)[, "katos": ..., "aita": ...]} paikallisina pohjina.
##   shapes: törmäyslaatikot [koko: Vector3, keskipiste: Vector3] paikallisina.
##   h_top: korkein kohta (piippu tai harja).
##   mitat: {kulma (astetta), raystas (räystäskorkeus m), krs[, moduuli (K6–K8: asunnon, portaan tai kehävälin
##          leveys m)]} testikohtaukselle (tools/testit/rakennukset_kuvat).
##   doors (K6–K8): Array[Vector3] jokaisen asunnon (K6), porrashuoneen (K7) tai hallin oven edusta; door = keskimmäinen.
##   K6–K8:n p: n (moduuleja), krs, v (K8-variantti), liike (K7), taka (K6: pihaa rungon takana, aidat).

const B := preload("res://scripts/build.gd")

const GLASS := Color(0.12, 0.17, 0.24)
const STONE := Color(0.46, 0.46, 0.45)
const BRICK := Color(0.52, 0.24, 0.18)
const WHITE_FRAME := Color(0.92, 0.92, 0.89)  # kerrostalon ja hallin valkoiset ikkunanpuitteet


static func build(tyyppi: String, p: Dictionary, runko: B.Batch, pienet: B.Batch, xf: Transform3D) -> Dictionary:
	match tyyppi:
		"K1":
			return _k1(p, runko, pienet, xf)
		"K2":
			return _k2(p, runko, pienet, xf)
		"K3":
			return _k3(p, runko, pienet, xf)
		"K4":
			return _k4(p, runko, pienet, xf)
		"K5":
			return _k5(p, runko, pienet, xf)
		"K6":
			return _k6(p, runko, pienet, xf)
		"K7":
			return _k7(p, runko, pienet, xf)
		"K8":
			return _k8(p, runko, pienet, xf)
	push_error("rakennukset: tuntematon tyyppi " + tyyppi)
	return {}


static func _box(bt: B.Batch, xf: Transform3D, size: Vector3, pos: Vector3, col: Color, bs := Basis()) -> void:
	bt.add(B.boxm(size), xf * Transform3D(bs, pos), col)


static func _rect(cx: float, cz: float, hx: float, hz: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(cx - hx, cz - hz), Vector2(cx + hx, cz - hz), Vector2(cx + hx, cz + hz), Vector2(cx - hx, cz + hz)])


## Sokkeli: y = -drop (rinteen alin kulma) ... top.
static func _plinth(bt: B.Batch, xf: Transform3D, l: float, d: float, top: float, drop: float, col := STONE) -> void:
	_box(bt, xf, Vector3(l + 0.1, top + drop, d + 0.1), Vector3(0, (top - drop) / 2.0, 0), col)


## Harjakatto, harja kehyksen X-akselin suuntainen (räystäät z = ±d/2): ullakko päätykolmioineen (seinän väri),
## kaksi lapetta, harjalauta, päätylaudat ja valinnaisesti näkyvät kattokannattajat (avoräystäs) tai räystäslauta.
## Kaikki kallistuvat osat lasketaan yhdestä kaltevuusvektorista: lappeen suunta u (räystäältä harjalle) ja normaali n.
## Palauttaa harjan yläpinnan korkeuden.
static func _gable(r: B.Batch, sm: B.Batch, xf: Transform3D, l: float, d: float, h_e: float, a: float, ov: float,
		ovg: float, t: float, wall: Color, roof: Color, trim: Color, rafters: bool, fascia: bool) -> float:
	var rise := d / 2.0 * tan(a)
	var attic := PrismMesh.new()
	attic.size = Vector3(d, rise, l)
	r.add(attic, xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, h_e + rise / 2.0, 0)), wall)  # päätykolmiot
	# Lappeen pituus ulottuu harjan yli t·tan(a): lappeiden yläpinnat kohtaavat harjalla ilman uraa.
	var slab_l := (d / 2.0 + ov) / cos(a) + t * tan(a)
	for sg in [-1.0, 1.0]:
		var eave := Vector3(0, h_e - ov * tan(a), sg * (d / 2.0 + ov))  # lappeen alapinnan räystäsreuna
		var u := Vector3(0, sin(a), -sg * cos(a))
		var n := Vector3(0, cos(a), sg * sin(a))
		var bs := Basis(Vector3.RIGHT, n, Vector3.RIGHT.cross(n))
		var c := eave + u * slab_l / 2.0 + n * t / 2.0
		_box(r, xf, Vector3(l + 2.0 * ovg, t, slab_l), c, roof, bs)
		for sx in [-1.0, 1.0]:  # päätylaudat lappeen alareunassa
			_box(r, xf, Vector3(0.05, 0.2, slab_l), c + Vector3(sx * (l / 2.0 + ovg - 0.03), 0, 0) - n * (t / 2.0 + 0.08), trim, bs)
		if fascia:  # umpiräystään räystäslauta
			_box(r, xf, Vector3(l + 2.0 * ovg, 0.22, 0.04), eave + Vector3(0, 0.0, sg * 0.02) + n * t / 2.0, trim)
		if rafters:  # avoräystäs: kattokannattajien päät seinästä räystääseen (8 per lape, 12 x 22 cm, 6 m:stä näkyvät)
			var k := 8
			var run := ov / cos(a) + 0.15
			for i in k:
				var x := -l / 2.0 - ovg + 0.09 + (l + 2.0 * ovg - 0.18) * i / (k - 1)
				_box(sm, xf, Vector3(0.12, 0.22, run), eave + Vector3(x, 0, 0) + u * run / 2.0 - n * 0.11, trim.darkened(0.1), bs)
			# Päätyräystään orsi lappeen puolivälissä koko talon läpi: päät näkyvät molemmissa päädyissä räystään
			# alla ja pistävät 8 cm päätylaudan ohi (ullakon sisällä piilossa).
			var s := (ov + d / 4.0) / cos(a)
			_box(sm, xf, Vector3(l + 2.0 * ovg + 0.16, 0.22, 0.14), eave + u * s - n * 0.11, trim.darkened(0.1), bs)
	if rafters:  # harjaorsi lappeiden alapintojen kärjessä
		_box(sm, xf, Vector3(l + 2.0 * ovg + 0.16, 0.26, 0.16), Vector3(0, h_e + rise - 0.15, 0), trim.darkened(0.1))
	var top := h_e + rise + t / cos(a)
	_box(r, xf, Vector3(l + 2.0 * ovg, 0.08, 0.28), Vector3(0, top - 0.02, 0), roof.darkened(0.2))  # harjapelti
	return top


## Ikkuna seinään: paikka p seinän pinnassa, nrm ulospäin (±X tai ±Z). Puite (frame) ja lasi rungossa, välipuut
## (cols x rows ruutua) lähiosissa.
static func _window(r: B.Batch, sm: B.Batch, xf: Transform3D, p: Vector3, nrm: Vector3, w: float, h: float,
		frame: Color, cols: int, rows: int) -> void:
	var bs := Basis(Vector3.UP, atan2(nrm.x, nrm.z))  # paikallinen Z -> nrm
	var f := 0.09  # puitteen leveys
	_box(r, xf, Vector3(w + 2.0 * f, h + 2.0 * f, 0.05), p + nrm * 0.02, frame, bs)
	_box(r, xf, Vector3(w, h, 0.05), p + nrm * 0.035, GLASS, bs)
	for i in range(1, cols):
		_box(sm, xf, Vector3(0.06, h, 0.07), p + nrm * 0.045 + bs * Vector3(-w / 2.0 + w * i / cols, 0, 0), frame, bs)
	for j in range(1, rows):
		_box(sm, xf, Vector3(w, 0.05, 0.07), p + nrm * 0.045 + Vector3(0, -h / 2.0 + h * j / rows, 0), frame, bs)


## Ovi: karmi, lehti ja porras. p = oviaukon alareunan keskikohta seinän pinnassa (y = kynnys).
static func _door(r: B.Batch, sm: B.Batch, xf: Transform3D, p: Vector3, nrm: Vector3, w: float, h: float, frame: Color,
		leaf: Color, step_y: float) -> void:
	var bs := Basis(Vector3.UP, atan2(nrm.x, nrm.z))
	_box(r, xf, Vector3(w + 0.24, h + 0.12, 0.05), p + nrm * 0.02 + Vector3(0, h / 2.0 + 0.06, 0), frame, bs)
	_box(r, xf, Vector3(w, h, 0.07), p + nrm * 0.04 + Vector3(0, h / 2.0, 0), leaf, bs)
	_box(sm, xf, Vector3(0.05, 0.05, 0.06), p + nrm * 0.1 + bs * Vector3(w / 2.0 - 0.12, h * 0.47, 0), Color(0.75, 0.7, 0.55), bs)  # kahva
	if step_y > 0.05:
		_box(r, xf, Vector3(w + 0.6, step_y + 0.2, 0.9), Vector3(p.x, (step_y - 0.2) / 2.0, p.z) + nrm * 0.45, STONE.lightened(0.1), bs)


## K1 rintamamiestalo: 1½ krs, lähes neliö, jyrkkä harjakatto (29–33°), avoräystäät näkyvine kattokannattajineen,
## piippu harjalla, valkoiset nurkkalaudat ja kaksipuitteiset ikkunat, ullakon päätyikkunat, pieni porstua julkisivun
## keskellä omalla harjakatollaan (harja Z:n suuntainen). Imatran rintamamiestalo-ohje 14/08 (01-esikuvat.md 1).
static func _k1(p: Dictionary, r: B.Batch, sm: B.Batch, xf: Transform3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed
	var l: float = p.l
	var d: float = p.d
	var wall: Color = p.wall
	var roof: Color = p.roof
	var trim: Color = p.trim
	var drop: float = p.get("drop", 0.2)
	var a := deg_to_rad(rng.randf_range(29.0, 33.0))
	var h_e := rng.randf_range(4.3, 4.7)  # räystäskorkeus (seinän yläreuna) maasta
	var plinth := 0.55
	var pd := clampf(d * 0.2, 1.5, 1.9)  # porstuan syvyys, porstua mahtuu pohjaan
	var pw := 2.5
	var bd := d - pd  # rungon syvyys
	var bz := pd / 2.0  # rungon keskikohta
	var xb := xf * Transform3D(Basis(), Vector3(0, 0, bz))
	_plinth(r, xb, l, bd, plinth, drop)
	_box(r, xb, Vector3(l, h_e - plinth, bd), Vector3(0, (h_e + plinth) / 2.0, 0), wall)
	var ridge := _gable(r, sm, xb, l, bd, h_e, a, 0.7, 0.7, 0.14, wall, roof, trim, true, false)
	for sx in [-1.0, 1.0]:  # nurkkalaudat
		for sz in [-1.0, 1.0]:
			_box(r, xb, Vector3(0.16, h_e - plinth, 0.16), Vector3(sx * l / 2.0, (h_e + plinth) / 2.0, sz * bd / 2.0), trim)
	# Tiilipiippu harjalla keskellä, pellitetty hattu.
	var cx := rng.randf_range(-0.1, 0.1) * l
	var ch_top := ridge + 0.9
	_box(r, xb, Vector3(0.62, ch_top - ridge + 1.2, 0.62), Vector3(cx, (ch_top + ridge - 1.2) / 2.0, 0), BRICK)
	_box(r, xb, Vector3(0.78, 0.1, 0.78), Vector3(cx, ch_top + 0.05, 0), Color(0.18, 0.18, 0.19))
	# Ikkunat: alakerta pitkillä sivuilla int(l / 3.6), porstuan kohta jää väliin; päädyissä alakerta ja ullakko.
	var win_y := plinth + 1.2
	var n := maxi(2, int(l / 3.6))
	for i in n:
		var x := -l / 2.0 + l * (i + 0.5) / n
		for sz in [-1.0, 1.0]:
			if sz < 0.0 and absf(x) < pw / 2.0 + 0.8:
				continue
			_window(r, sm, xb, Vector3(x, win_y, sz * bd / 2.0), Vector3(0, 0, sz), 1.0, 1.25, trim, 2, 1)
	for sx in [-1.0, 1.0]:
		_window(r, sm, xb, Vector3(sx * l / 2.0, win_y, -bd * 0.22), Vector3(sx, 0, 0), 1.0, 1.25, trim, 2, 1)
		_window(r, sm, xb, Vector3(sx * l / 2.0, win_y, bd * 0.25), Vector3(sx, 0, 0), 0.7, 0.9, trim, 1, 2)
		_window(r, sm, xb, Vector3(sx * l / 2.0, h_e + 0.35, 0), Vector3(sx, 0, 0), 0.8, 1.0, trim, 2, 1)
	# Porstua: pieni umpikuisti julkisivun keskellä, harja Z:n suuntainen (kehys käännetty 90° Y:n ympäri, X -> -Z).
	var ph := 2.6
	var pz := -d / 2.0 + pd / 2.0
	_plinth(r, xf * Transform3D(Basis(), Vector3(0, 0, pz + 0.05)), pw, pd + 0.1, plinth, drop)
	_box(r, xf, Vector3(pw, ph - plinth, pd + 0.1), Vector3(0, (ph + plinth) / 2.0, pz + 0.05), wall)
	var xp := xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, 0, pz + 0.1))
	_gable(r, sm, xp, pd + 0.2, pw, ph, a, 0.25, 0.3, 0.1, wall, roof, trim, false, true)
	for sx in [-1.0, 1.0]:
		_box(r, xf, Vector3(0.14, ph - plinth, 0.14), Vector3(sx * pw / 2.0, (ph + plinth) / 2.0, -d / 2.0), trim)
		_window(r, sm, xf, Vector3(sx * pw / 2.0, plinth + 1.3, pz), Vector3(sx, 0, 0), 0.5, 0.8, trim, 1, 2)
	_door(r, sm, xf, Vector3(0, plinth, -d / 2.0), Vector3(0, 0, -1), 0.9, 1.95, trim, p.get("door", Color(0.35, 0.22, 0.14)), plinth)
	return {
		"door": Vector3(0, 0, -d / 2.0 - 1.2),
		"foot": {"runko": _rect(0, 0, l / 2.0, d / 2.0)},
		"shapes": [[Vector3(l, ridge, bd), Vector3(0, ridge / 2.0, bz)], [Vector3(pw, ph, pd), Vector3(0, ph / 2.0, pz)]],
		"h_top": ch_top,
		"mitat": {"kulma": rad_to_deg(a), "raystas": h_e, "krs": 1.5},
	}


## Lappeen pinnan piste ja kanta (_gable-kehyksessä): sivu sg (-1 = -Z-lape), osuus f räystäältä harjalle, x.
static func _on_roof(d: float, h_e: float, a: float, ov: float, t: float, sg: float, f: float, x: float) -> Transform3D:
	var slab_l := (d / 2.0 + ov) / cos(a)
	var u := Vector3(0, sin(a), -sg * cos(a))
	var n := Vector3(0, cos(a), sg * sin(a))
	var eave := Vector3(x, h_e - ov * tan(a), sg * (d / 2.0 + ov))
	return Transform3D(Basis(Vector3.RIGHT, n, Vector3.RIGHT.cross(n)), eave + u * slab_l * f + n * (t + 0.01))


## K2 matala 1970–80-luvun omakotitalo: yksikerroksinen suorakaide, loiva tumma harjakatto (16–19°) umpiräystäin ja
## tummanruskein räystäslaudoin (tiilitalon päätykolmio tummaa puuta) tai (flat) 70-luvun tasakatto paksuin
## otsalaudoin; vaalea, keltainen tai punainen tiili tai peiterima (rima, pystyrimat), leveät matalat ruutuikkunat ja
## autokatos kyljessä (carport -1/1: -X/+X, pohjan ulkopuolella). Yle 3-9279540 ja 3-9288016 (01-esikuvat.md 2).
static func _k2(p: Dictionary, r: B.Batch, sm: B.Batch, xf: Transform3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed
	var l: float = p.l
	var d: float = p.d
	var wall: Color = p.wall
	var roof: Color = p.roof
	var trim: Color = p.trim
	var drop: float = p.get("drop", 0.2)
	var flat: bool = p.get("flat", false)
	var rima: bool = p.get("rima", false)
	var cp: int = p.get("carport", 0)
	var a := deg_to_rad(rng.randf_range(16.0, 19.0))
	var plinth := 0.25  # piilosokkeli
	var h_e := rng.randf_range(2.8, 3.0)
	_plinth(r, xf, l, d, plinth, drop, STONE.darkened(0.15))
	_box(r, xf, Vector3(l, h_e - plinth, d), Vector3(0, (h_e + plinth) / 2.0, 0), wall)
	var top := h_e + 0.47
	if flat:
		_box(r, xf, Vector3(l + 1.0, 0.45, d + 1.0), Vector3(0, h_e + 0.2, 0), trim)  # otsalauta
		_box(r, xf, Vector3(l + 0.8, 0.06, d + 0.8), Vector3(0, h_e + 0.44, 0), roof)  # bitumikate
	else:
		top = _gable(r, sm, xf, l, d, h_e, a, 0.6, 0.4, 0.12, wall if rima else trim, roof, trim, false, true)
	# Ikkunat: leveät matalat koristeruutuikkunat (3 x 2), etuseinän keskimmäisen paikalla ovi.
	var frame := trim
	var win_y := plinth + 1.35
	var n := maxi(2, int(l / 3.6))
	var door_i := n / 2
	var door_x := 0.0
	var open_x: Array[float] = []  # aukkojen keskikohdat etu- ja takaseinällä (rimat väistävät)
	for i in n:
		var x := -l / 2.0 + l * (i + 0.5) / n
		open_x.append(x)
		for sz in [-1.0, 1.0]:
			if sz < 0.0 and i == door_i:
				door_x = x
				_door(r, sm, xf, Vector3(x, plinth, -d / 2.0), Vector3(0, 0, -1), 1.0, 2.05, frame, p.get("door", Color(0.5, 0.33, 0.2)), plinth)
				continue
			_window(r, sm, xf, Vector3(x, win_y, sz * d / 2.0), Vector3(0, 0, sz), 1.7, 1.05, frame, 3, 2)
	for sx in [-1.0, 1.0]:
		if int(sx) != cp:
			_window(r, sm, xf, Vector3(sx * l / 2.0, win_y, 0), Vector3(sx, 0, 0), 1.2, 1.05, frame, 2, 2)
	if not rima:  # tiilitalon vaakapalkki (lapetiilet) ikkunoiden yläpuolella etu- ja takaseinällä
		for sz in [-1.0, 1.0]:
			_box(r, xf, Vector3(l + 0.04, 0.14, 0.04), Vector3(0, win_y + 0.72, sz * (d / 2.0 + 0.01)), wall.darkened(0.14))
	if rima:  # peiterima: pystyrimat kaikilla seinillä noin 1,2 m välein, aukkojen kohdalta pois
		var rc := wall.darkened(0.3)
		var rh := h_e - plinth - 0.05
		var k := int(l / 1.2)
		for i in range(1, k):
			var x := -l / 2.0 + l * i / k
			var free := true
			for ox in open_x:
				if absf(x - ox) < 1.05:
					free = false
			if not free:
				continue
			for sz in [-1.0, 1.0]:
				_box(sm, xf, Vector3(0.08, rh, 0.04), Vector3(x, (h_e + plinth) / 2.0, sz * (d / 2.0 + 0.02)), rc)
		var kd := int(d / 1.2)
		for sx in [-1.0, 1.0]:  # päädyt: ikkuna keskellä (ei autokatoksen puolella)
			for i in range(1, kd):
				var z := -d / 2.0 + d * i / kd
				if int(sx) != cp and absf(z) < 0.85:
					continue
				_box(sm, xf, Vector3(0.04, rh, 0.08), Vector3(sx * (l / 2.0 + 0.02), (h_e + plinth) / 2.0, z), rc)
	var foot := {"runko": _rect(0, 0, l / 2.0, d / 2.0)}
	var shapes: Array = [[Vector3(l, top, d), Vector3(0, top / 2.0, 0)]]
	if cp != 0:
		# Autokatos päädyssä: tasakatto otsalautoineen, kaksi tolppaa ulkoreunassa, sisäreuna seinässä, rimasäleikkö.
		var cw := 3.6
		var cd := minf(d, 6.0)
		var cx := cp * (l / 2.0 + cw / 2.0)
		var cz := -d / 2.0 + cd / 2.0
		var ch := minf(2.5, h_e - 0.25)
		for sz in [-1.0, 1.0]:
			_box(r, xf, Vector3(0.14, ch, 0.14), Vector3(cx + cp * (cw / 2.0 - 0.1), ch / 2.0, cz + sz * (cd / 2.0 - 0.1)), trim)
			shapes.append([Vector3(0.14, ch, 0.14), Vector3(cx + cp * (cw / 2.0 - 0.1), ch / 2.0, cz + sz * (cd / 2.0 - 0.1))])
		_box(r, xf, Vector3(cw + 0.1, 0.24, cd + 0.2), Vector3(cx, ch + 0.12, cz), trim)
		_box(r, xf, Vector3(cw - 0.1, 0.04, cd), Vector3(cx, ch + 0.25, cz), roof)
		for i in 5:
			var z := cz + cd * 0.1 + i * cd * 0.09
			_box(sm, xf, Vector3(0.05, ch - 0.6, 0.08), Vector3(cx + cp * (cw / 2.0 - 0.1), 0.3 + (ch - 0.6) / 2.0, z), trim)
		foot.katos = _rect(cx, cz, cw / 2.0 + 0.05, cd / 2.0 + 0.1)
	return {
		"door": Vector3(door_x, 0, -d / 2.0 - 1.2),
		"foot": foot,
		"shapes": shapes,
		"h_top": top,
		"mitat": {"kulma": 0.0 if flat else rad_to_deg(a), "raystas": h_e, "krs": 1.0},
	}


## Kulmakivet: pääty- ja kulmakivet rungon alle (aitta ja lato seisovat kivien päällä, ilmaa alla).
static func _stones(r: B.Batch, xf: Transform3D, ln: float, w: float, top: float, drop: float) -> void:
	for x in [-ln / 2.0 + 0.2, 0.0, ln / 2.0 - 0.2]:
		for sz in [-1.0, 1.0]:
			if x == 0.0 and ln < 4.5:
				continue
			_box(r, xf, Vector3(0.48, top + drop, 0.48), Vector3(x, (top - drop) / 2.0, sz * (w / 2.0 - 0.2)), STONE.darkened(0.05))


## K3 aitta (myös rantamökki/sauna suurempana): harja Z:n suuntainen, ovi -Z-päädyssä, ei ikkunoita, kulmakivien
## päällä (alin hirsikerros ja ilmaa alla), harja 28–33°, pystyrimat, punamulta valkoisin nurkkalaudoin tai
## harmaantunut lauta. Paltamon rantayleiskaava ja Vaalan Alilan aitta (01-esikuvat.md 3). Ei piippua (arkkitehti).
static func _k3(p: Dictionary, r: B.Batch, sm: B.Batch, xf: Transform3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed
	var w: float = p.l  # päädyn leveys (paikallinen X)
	var ln: float = p.d  # harjan suuntainen pituus (paikallinen Z)
	var wall: Color = p.wall
	var roof: Color = p.roof
	var trim: Color = p.trim
	var drop: float = p.get("drop", 0.2)
	# Kehys: X = harja, +X = ovipääty = paikallinen -Z (kierto 90° Y:n ympäri vie X:n -Z:ksi).
	var xr := xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO)
	var a := deg_to_rad(rng.randf_range(28.0, 33.0))
	var base := 0.35
	var h_e := base + rng.randf_range(2.0, 2.2) + (0.2 if w > 3.9 else 0.0)
	_stones(r, xr, ln, w, base, drop)
	_box(r, xr, Vector3(ln + 0.08, 0.2, w + 0.08), Vector3(0, base + 0.1, 0), wall.darkened(0.3))  # alin hirsikerros
	_box(r, xr, Vector3(ln, h_e - base - 0.2, w), Vector3(0, (h_e + base + 0.2) / 2.0, 0), wall)
	var top := _gable(r, sm, xr, ln, w, h_e, a, 0.3, 0.35, 0.08, wall, roof, trim, false, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(r, xr, Vector3(0.13, h_e - base, 0.13), Vector3(sx * ln / 2.0, (h_e + base) / 2.0, sz * w / 2.0), trim)
	var k := mini(int(ln / 0.5), 8)
	for i in range(1, k):
		var x := -ln / 2.0 + ln * i / k
		for sz in [-1.0, 1.0]:
			_box(sm, xr, Vector3(0.06, h_e - base - 0.3, 0.04), Vector3(x, (h_e + base + 0.2) / 2.0, sz * (w / 2.0 + 0.02)), wall.darkened(0.2))
	_door(r, sm, xr, Vector3(ln / 2.0, base + 0.2, 0), Vector3(1, 0, 0), 0.85, 1.75, trim, wall.darkened(0.35), base + 0.2)
	return {
		"door": Vector3(0, 0, -ln / 2.0 - 1.2),
		"foot": {"runko": _rect(0, 0, w / 2.0, ln / 2.0)},
		"shapes": [[Vector3(w, top, ln), Vector3(0, top / 2.0, 0)]],
		"h_top": top,
		"mitat": {"kulma": rad_to_deg(a), "raystas": h_e, "krs": 1.0},
	}


## K4 lato: harja Z:n suuntainen, iso pariovi -Z-päädyssä vinotukineen, pitkät seinät levenevät ylöspäin (4–6°),
## harmaantunut pystylauta rimoineen, kivijalka, peltikatto 22–27° ruosteläiskineen. Kaikki kallistuvat seinäosat
## (sivuseinät, päätyjen reunakappaleet, rimat) lasketaan samasta nousuvektorista lean; katto _gable. Wikipedia Lato,
## Paltamon kaava, world.gd _barn (01-esikuvat.md 4).
static func _k4(p: Dictionary, r: B.Batch, sm: B.Batch, xf: Transform3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed
	var t := 0.12  # sivuseinän paksuus
	var w0: float = p.l - 2.0 * t  # rungon leveys alhaalla (paikallinen X); sivuseinineen p.l
	var ln: float = p.d  # harjan suuntainen pituus (paikallinen Z)
	var wall: Color = p.wall
	var roof: Color = p.roof
	var trim: Color = p.trim
	var drop: float = p.get("drop", 0.2)
	var xr := xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO)  # X = harja, +X = ovipääty (-Z)
	var a := deg_to_rad(rng.randf_range(22.0, 27.0))
	var flare := deg_to_rad(rng.randf_range(4.0, 6.0))
	var base := 0.4
	var hw := rng.randf_range(3.0, 3.4)  # seinän korkeus kivijalasta
	var h_e := base + hw
	var hl := hw / cos(flare)  # kallistuneen seinän pituus
	var spread := hw * tan(flare)  # leveneminen sivua kohti yläreunassa
	var w1 := w0 + 2.0 * (spread + t)  # ulkoleveys räystäällä
	# Kivijalka pohjan sisään: päädyn leveys alhaalla w0 + 2t.
	_box(r, xr, Vector3(ln + 0.15, base + drop, w0 + 2.0 * t + 0.15), Vector3(0, (base - drop) / 2.0, 0), STONE)
	_box(r, xr, Vector3(ln, hw, w0), Vector3(0, base + hw / 2.0, 0), wall)
	var top := _gable(r, sm, xr, ln + 0.02, w1, h_e, a, 0.35, 0.4, 0.1, wall, roof, trim, false, false)
	var kb := mini(int(ln / 0.5), 17)
	for sg in [-1.0, 1.0]:
		var lean := Vector3(0, cos(flare), sg * sin(flare))  # seinän nousuvektori (ylös ja ulos)
		var nn := Vector3(0, -sin(flare), sg * cos(flare))  # seinän ulkonormaali
		var bs := Basis(Vector3.RIGHT, lean, Vector3.RIGHT.cross(lean))
		var c := Vector3(0, base, sg * w0 / 2.0) + lean * hl / 2.0 + nn * t / 2.0
		_box(r, xr, Vector3(ln, hl, t), c, wall, bs)
		for sx in [-1.0, 1.0]:  # päädyn reunakappale peittää rungon ja kallistuneen seinän välisen kiilan
			var bw := spread + t + 0.3
			_box(r, xr, Vector3(0.1, hl, bw), c + nn * (t - bw) / 2.0 + Vector3(sx * (ln / 2.0 - 0.045), 0, 0), wall, bs)
		for i in range(1, kb):
			var x := -ln / 2.0 + ln * i / kb
			_box(sm, xr, Vector3(0.07, hl - 0.15, 0.05), c + nn * (t / 2.0 + 0.025) + Vector3(x, 0, 0),
				wall.darkened(0.12 + 0.08 * (i % 3) / 2.0), bs)
	# Päätyjen rimat: seinäosa ja päätykolmio (korkeus kolmiossa lappeen alapinnasta), ovi väistetään.
	var dw := minf(w0 - 1.2, 3.2)
	var dh := minf(hw - 0.35, 2.8)
	var rise := w1 / 2.0 * tan(a)
	var ke := int(w1 / 0.6)
	for sx in [-1.0, 1.0]:
		for i in range(1, ke):
			var z := -w1 / 2.0 + w1 * i / ke
			var y0 := base + 0.1
			if absf(z) > w0 / 2.0 - 0.1:
				y0 = h_e - 0.05  # kiilan kohdalla vain kolmio
			elif sx > 0.0 and absf(z) < dw / 2.0 + 0.12:
				y0 = base + dh + 0.25
			var y1 := h_e + rise * (1.0 - absf(z) / (w1 / 2.0)) - 0.1
			if y1 - y0 < 0.3:
				continue
			_box(sm, xr, Vector3(0.05, y1 - y0, 0.07), Vector3(sx * (ln / 2.0 + 0.03), (y0 + y1) / 2.0, z), wall.darkened(0.15))
	# Iso pariovi vinotukineen ja yläpuu.
	var door_col := wall.darkened(0.28)
	var dy := base + dh / 2.0
	var lw := dw / 2.0 - 0.03
	var brace := atan2(lw - 0.2, dh - 0.2)
	for sz in [-1.0, 1.0]:
		var zc: float = sz * dw / 4.0
		_box(r, xr, Vector3(0.08, dh, lw), Vector3(ln / 2.0 + 0.06, dy, zc), door_col)
		_box(sm, xr, Vector3(0.05, (dh - 0.2) / cos(brace), 0.14), Vector3(ln / 2.0 + 0.11, dy, zc),
			door_col.darkened(0.25), Basis(Vector3.RIGHT, sz * brace))
	_box(r, xr, Vector3(0.12, 0.18, dw + 0.4), Vector3(ln / 2.0 + 0.06, base + dh + 0.09, 0), trim.darkened(0.2))
	_box(r, xr, Vector3(0.9, 0.12, dw + 0.2), Vector3(ln / 2.0 + 0.45, base - 0.06, 0), STONE.lightened(0.05))  # luiska
	# Ruosteläiskät peltikatossa (world.gd _barn): lappeen pinnassa _on_roof-kannalla.
	var rust := roof.lerp(Color(0.62, 0.32, 0.14), 0.7)
	for i in 8:
		var sg := -1.0 if i % 2 == 0 else 1.0
		var x := -ln / 2.0 + 0.5 + i * (ln - 1.0) / 7.0
		var at := _on_roof(w1, h_e, a, 0.35, 0.1, sg, rng.randf_range(0.2, 0.7), x)
		_box(sm, xr, Vector3(0.28, 0.02, rng.randf_range(0.6, 1.1)), at.origin, rust, at.basis)
	return {
		"door": Vector3(0, 0, -ln / 2.0 - 1.5),
		"foot": {"runko": _rect(0, 0, w0 / 2.0 + t, ln / 2.0)},
		"shapes": [[Vector3(w0 + 2.0 * t, top, ln), Vector3(0, top / 2.0, 0)]],
		"h_top": top,
		"mitat": {"kulma": rad_to_deg(a), "raystas": h_e, "krs": 1.0, "levenema": rad_to_deg(flare)},
	}


## K5 Raahen vanha puutalo: yksikerroksinen, harja kadun suuntainen (X), keltamulta vaakalaudoitus, valkoiset
## nurkkalaudat, otsalaudat ja friisit, kuusiruutuiset pystyikkunat (2 x 3), matala kivijalka, ja umpilankkuaita
## ajoportteineen julkisivun linjassa +X-päädystä (gate_gap m, pohjan ulkopuolella). matkailuoppaat.fi Old Raahe
## (01-esikuvat.md 5).
static func _k5(p: Dictionary, r: B.Batch, sm: B.Batch, xf: Transform3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed
	var l: float = p.l
	var d: float = p.d
	var wall: Color = p.wall
	var roof: Color = p.roof
	var trim: Color = p.trim
	var drop: float = p.get("drop", 0.2)
	var gg: float = p.get("gate_gap", 0.0)
	var a := deg_to_rad(rng.randf_range(26.0, 29.0))
	var plinth := 0.45
	var h_e := plinth + rng.randf_range(2.9, 3.1)
	_plinth(r, xf, l, d, plinth, drop, STONE.lightened(0.08))
	_box(r, xf, Vector3(l, h_e - plinth, d), Vector3(0, (h_e + plinth) / 2.0, 0), wall)
	var top := _gable(r, sm, xf, l, d, h_e, a, 0.45, 0.35, 0.1, wall, roof, trim, false, true)
	for sz in [-1.0, 1.0]:  # friisilauta räystään alla
		_box(r, xf, Vector3(l + 0.06, 0.3, 0.04), Vector3(0, h_e - 0.15, sz * (d / 2.0 + 0.02)), trim)
	for sx in [-1.0, 1.0]:  # päätyjen vaakalista ullakon alareunassa
		_box(r, xf, Vector3(0.05, 0.16, d + 0.06), Vector3(sx * (l / 2.0 + 0.025), h_e, 0), trim)
		for sz in [-1.0, 1.0]:
			_box(r, xf, Vector3(0.22, h_e - plinth, 0.22), Vector3(sx * l / 2.0, (h_e + plinth) / 2.0, sz * d / 2.0), trim)
	# Vaakalaudoituksen saumat julkisivussa (ikkunoiden puitteet peittävät ne).
	var seam := wall.darkened(0.14)
	var ks := int((h_e - plinth - 0.5) / 0.3)
	for j in ks:
		_box(sm, xf, Vector3(l - 0.1, 0.025, 0.02), Vector3(0, plinth + 0.3 + j * 0.3, -d / 2.0 - 0.012), seam)
	# Kuusiruutuiset pystyikkunat tiheässä rivissä; ovi +X-päädyn puoleisessa paikassa (portin puolella).
	var n := maxi(3, int(l / 2.4))
	var win_y := plinth + 1.45
	var door_x := 0.0
	for i in n:
		var x := -l / 2.0 + l * (i + 0.5) / n
		for sz in [-1.0, 1.0]:
			if sz < 0.0 and i == n - 1:
				door_x = x
				_door(r, sm, xf, Vector3(x, plinth, -d / 2.0), Vector3(0, 0, -1), 1.0, 2.1, trim, Color(0.42, 0.26, 0.16), plinth)
				continue
			if sz > 0.0 and i == 0:
				continue
			_window(r, sm, xf, Vector3(x, win_y, sz * d / 2.0), Vector3(0, 0, sz), 0.85, 1.45, trim, 2, 3)
	for sx in [-1.0, 1.0]:
		_window(r, sm, xf, Vector3(sx * l / 2.0, win_y, -d * 0.1), Vector3(sx, 0, 0), 0.85, 1.45, trim, 2, 3)
	var foot := {"runko": _rect(0, 0, l / 2.0, d / 2.0)}
	var shapes: Array = [[Vector3(l, top, d), Vector3(0, top / 2.0, 0)]]
	if gg >= 3.4:
		# Umpilankkuaita ja ajoportti julkisivun linjassa: aidanosat, kansilauta, porttitolpat, lehdet ja yläpuu.
		var fh := 2.0
		var fz := -d / 2.0 + 0.1
		var x0 := l / 2.0
		var x1 := l / 2.0 + gg
		var gw := minf(3.0, gg - 0.8)
		var gc := x1 - 0.4 - gw / 2.0
		var fence := wall.darkened(0.06)
		for seg in [[x0, gc - gw / 2.0 - 0.1], [gc + gw / 2.0 + 0.1, x1]]:
			var sl: float = seg[1] - seg[0]
			if sl < 0.1:
				continue
			var sc: float = (seg[0] + seg[1]) / 2.0
			_box(r, xf, Vector3(sl, fh, 0.08), Vector3(sc, fh / 2.0 - 0.1, fz), fence)
			_box(r, xf, Vector3(sl, 0.06, 0.16), Vector3(sc, fh - 0.07, fz), trim)
		for sx in [-1.0, 1.0]:
			_box(r, xf, Vector3(0.2, fh + 0.35, 0.2), Vector3(gc + sx * (gw / 2.0 + 0.1), (fh + 0.35) / 2.0 - 0.1, fz), trim)
			_box(r, xf, Vector3(gw / 2.0 - 0.04, fh - 0.25, 0.07), Vector3(gc + sx * gw / 4.0, (fh - 0.25) / 2.0 + 0.1, fz), fence.darkened(0.1))
		_box(r, xf, Vector3(gw + 0.6, 0.2, 0.22), Vector3(gc, fh + 0.35, fz), trim)
		foot.aita = _rect((x0 + x1) / 2.0, fz, gg / 2.0, 0.12)
		shapes.append([Vector3(gg, fh, 0.12), Vector3((x0 + x1) / 2.0, fh / 2.0, fz)])
	return {
		"door": Vector3(door_x, 0, -d / 2.0 - 1.2),
		"foot": foot,
		"shapes": shapes,
		"h_top": top,
		"mitat": {"kulma": rad_to_deg(a), "raystas": h_e, "krs": 1.0},
	}


## K6 rivitalo (1970–90): pitkä matala massa, jossa sama asuntomoduuli (leveys l / n) toistuu peilaten (naapurien
## ovet pareittain). Jokaisella asunnolla julkisivussa (-Z) ovi, katos tuulensuojineen ja keittiön ikkuna, takana (+Z)
## olohuoneen iso ikkuna ja terassin lasiovi, ja asuntopihojen välissä 1,6 m:n lauta-aita (vain jos pohjaa jää
## rungon taakse p.taka >= 1,5 m; aita ei mene sen yli). Loiva harjakatto 14–20° umpiräystäin tai (flat) tasakatto.
## Tiilitalo: alaosa tiiltä, ikkunoiden yläpuolinen vyöhyke ja päätykolmiot vaaleaa lautaa; peiterimatalo (rima):
## koko talo pystyrimoin. krs 1 (räystäs 2,9 m) tai 2 (5,6 m). Vantaan kaupunginmuseo, Vantaan 1980–1990-lukujen
## rakennuskannan inventointi: Rivitalot (2024) (02-arkkitehtuuri.md Korjaus 2).
## p: l, d, wall, roof, trim, seed; n (asuntoja), krs, flat, rima, taka (pihan syvyys rungon takana), drop.
static func _k6(p: Dictionary, r: B.Batch, sm: B.Batch, xf: Transform3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed
	var l: float = p.l
	var d: float = p.d
	var n: int = maxi(p.get("n", 2), 1)
	var w := l / n  # asuntomoduulin leveys
	var krs: int = clampi(p.get("krs", 1), 1, 2)
	var wall: Color = p.wall
	var roof: Color = p.roof
	var trim: Color = p.trim
	var drop: float = p.get("drop", 0.2)
	var flat: bool = p.get("flat", false)
	var rima: bool = p.get("rima", false)
	var taka: float = p.get("taka", 0.0)
	var a := deg_to_rad(rng.randf_range(14.0, 20.0))
	var plinth := 0.3
	var h_e := 2.9 + 2.7 * (krs - 1) + rng.randf_range(0.0, 0.1)
	var panel := Color(0.88, 0.82, 0.66)  # tiilitalon vaalea lautavyöhyke ja päätykolmiot
	var win_y := plinth + 1.3  # ikkunan keskikohta (1. krs)
	_plinth(r, xf, l, d, plinth, drop, STONE.darkened(0.15))
	_box(r, xf, Vector3(l, h_e - plinth, d), Vector3(0, (h_e + plinth) / 2.0, 0), wall)
	if not rima:  # lautavyöhyke ikkunoiden yläpuolella räystääseen (ylimmän kerroksen ikkunoista)
		var yb := win_y + 2.7 * (krs - 1) + 0.85
		for sz in [-1.0, 1.0]:
			_box(r, xf, Vector3(l + 0.04, h_e - yb, 0.04), Vector3(0, (h_e + yb) / 2.0, sz * (d / 2.0 + 0.02)), panel)
	var top := h_e + 0.47
	if flat:
		_box(r, xf, Vector3(l + 1.0, 0.45, d + 1.0), Vector3(0, h_e + 0.2, 0), trim)  # otsalauta
		_box(r, xf, Vector3(l + 0.8, 0.06, d + 0.8), Vector3(0, h_e + 0.44, 0), roof)  # bitumikate
	else:
		top = _gable(r, sm, xf, l, d, h_e, a, 0.6, 0.4, 0.12, wall if rima else panel, roof, trim, false, true)
	for sx in [-1.0, 1.0]:  # nurkkalaudat ja päätyjen ikkunat
		for sz in [-1.0, 1.0]:
			_box(r, xf, Vector3(0.14, h_e - plinth, 0.14), Vector3(sx * l / 2.0, (h_e + plinth) / 2.0, sz * d / 2.0), trim)
		_window(r, sm, xf, Vector3(sx * l / 2.0, win_y, 0), Vector3(sx, 0, 0), 1.2, 1.1, trim, 2, 1)
	# Asuntomoduulit: aukot [x, puolileveys] etu- ja takaseinällä (rimat väistävät).
	var open_f: Array = []
	var open_b: Array = []
	var doors: Array[Vector3] = []
	var door_col := Color(0.42, 0.27, 0.16) if rima else trim.lightened(0.1)
	var fence_col := wall.darkened(0.12) if rima else Color(0.5, 0.37, 0.24)
	var fl := minf(taka - 0.1, 4.5)  # aidan pituus rungon takana
	for i in n:
		var xm := -l / 2.0 + w * (i + 0.5)
		var sg := 1.0 if i % 2 == 0 else -1.0  # peilaus: naapurien ovet vierekkäin
		var dx := xm + sg * w * 0.25
		var kx := xm - sg * w * 0.2
		_door(r, sm, xf, Vector3(dx, plinth, -d / 2.0), Vector3(0, 0, -1), 1.0, 2.05, trim, door_col, plinth)
		doors.append(Vector3(dx, 0, -d / 2.0 - 1.2))
		_box(r, xf, Vector3(1.8, 0.12, 0.95), Vector3(dx, plinth + 2.45, -d / 2.0 - 0.475), roof.darkened(0.1))  # katos
		if krs == 1:  # tuulensuoja katoksen alla naapurin oven puolella
			_box(r, xf, Vector3(0.08, 2.3, 0.9), Vector3(dx + sg * 0.86, plinth + 1.15, -d / 2.0 - 0.45), fence_col)
		_window(r, sm, xf, Vector3(kx, win_y, -d / 2.0), Vector3(0, 0, -1), 1.4, 1.1, trim, 2, 1)
		var lx := xm - sg * w * 0.18
		var tx := xm + sg * w * 0.27
		_window(r, sm, xf, Vector3(lx, win_y - 0.15, d / 2.0), Vector3(0, 0, 1), 2.4, 1.4, trim, 3, 1)
		_window(r, sm, xf, Vector3(tx, plinth + 1.05, d / 2.0), Vector3(0, 0, 1), 0.9, 2.0, trim, 1, 1)  # terassiovi
		open_f.append_array([[dx, 0.75], [kx, 0.8]])
		open_b.append_array([[lx, 1.3], [tx, 0.55]])
		if krs == 2:
			var uy := win_y + 2.7
			_window(r, sm, xf, Vector3(xm, uy, -d / 2.0), Vector3(0, 0, -1), 1.2, 1.1, trim, 2, 1)
			_window(r, sm, xf, Vector3(lx, uy, d / 2.0), Vector3(0, 0, 1), 1.6, 1.1, trim, 2, 1)
			open_f.append([xm, 0.7])
			open_b.append([lx, 0.9])
		if i == 0:
			continue
		var xb := -l / 2.0 + w * i  # asuntojen raja: lista julkisivussa (ja takana) ja pihojen välinen aita
		_box(r, xf, Vector3(0.12, h_e - plinth, 0.05), Vector3(xb, (h_e + plinth) / 2.0, -d / 2.0 - 0.025), trim)
		if krs == 1:
			_box(r, xf, Vector3(0.12, h_e - plinth, 0.05), Vector3(xb, (h_e + plinth) / 2.0, d / 2.0 + 0.025), trim)
		open_f.append([xb, 0.1])
		open_b.append([xb, 0.1])
		if taka >= 1.5:
			_box(r, xf, Vector3(0.05, 1.8, fl), Vector3(xb, 0.7, d / 2.0 + fl / 2.0), fence_col)  # y -0,2 ... 1,6
			_box(sm, xf, Vector3(0.1, 0.07, fl), Vector3(xb, 1.62, d / 2.0 + fl / 2.0), fence_col.darkened(0.2))
			_box(sm, xf, Vector3(0.11, 1.75, 0.11), Vector3(xb, 0.78, d / 2.0 + fl - 0.06), fence_col.darkened(0.2))
			for j in range(1, int(fl / 0.6)):  # lautojen saumat (läpi aidan, näkyvät molemmin puolin)
				_box(sm, xf, Vector3(0.07, 1.7, 0.03), Vector3(xb, 0.7, d / 2.0 + j * 0.6), fence_col.darkened(0.25))
	if rima:  # peiterima: pystyrimat 1,2 m välein, aukkojen kohdalta pois
		var rc := wall.darkened(0.3)
		var rh := h_e - plinth - 0.05
		var k := int(l / 1.2)
		for i in range(1, k):
			var x := -l / 2.0 + l * i / k
			for sz in [-1.0, 1.0]:
				var free := true
				for o: Array in (open_f if sz < 0.0 else open_b):
					if absf(x - o[0]) < o[1] + 0.2:
						free = false
				if free:
					_box(sm, xf, Vector3(0.08, rh, 0.04), Vector3(x, (h_e + plinth) / 2.0, sz * (d / 2.0 + 0.02)), rc)
		var kd := int(d / 1.2)
		for sx in [-1.0, 1.0]:
			for i in range(1, kd):
				var z := -d / 2.0 + d * i / kd
				if absf(z) > 0.85:
					_box(sm, xf, Vector3(0.04, rh, 0.08), Vector3(sx * (l / 2.0 + 0.02), (h_e + plinth) / 2.0, z), rc)
	var foot := {"runko": _rect(0, 0, l / 2.0, d / 2.0)}
	var shapes: Array = [[Vector3(l, top, d), Vector3(0, top / 2.0, 0)]]
	if taka >= 1.5 and n > 1:
		foot.aidat = _rect(0, d / 2.0 + fl / 2.0, l / 2.0 - w + 0.05, fl / 2.0)
		for i in range(1, n):
			shapes.append([Vector3(0.05, 1.6, fl), Vector3(-l / 2.0 + w * i, 0.8, d / 2.0 + fl / 2.0)])
	return {
		"door": doors[n / 2],
		"doors": doors,
		"foot": foot,
		"shapes": shapes,
		"h_top": top,
		"mitat": {"kulma": 0.0 if flat else rad_to_deg(a), "raystas": h_e, "krs": float(krs), "moduuli": w},
	}


## K7 kerrostalo (1960–70-luvun lamelli): suorakaide, 2–3 kerrosta (krs) ja n porrashuonetta (moduuli l / n).
## Julkisivussa (-Z) porrashuoneen ovi katoksineen ja pystysuora ikkunanauha, asuntojen ikkunat kerroksittain
## ja kellarin ikkunat korkeassa sokkelissa; takana (+Z) kaksi parveketta porrasta ja kerrosta kohden (laatta,
## umpikaide ja parvekeovi). Parvekkeet kuuluvat pohjaan: rungon syvyys d - 1,4. Tasakatto otsalautoineen tai
## (flat = false) loiva harjakatto 10–14°. liike: pohjakerroksen julkisivussa näyteikkunat. Kahri ja Pyykönen 1984
## (runkosyvyys), Vaalan 534430539 ja Vaalantien liike- ja asuinrakennukset (02-arkkitehtuuri.md Korjaus 2).
## p: l, d, wall, roof, trim, seed; n, krs, flat, liike, drop.
static func _k7(p: Dictionary, r: B.Batch, sm: B.Batch, xf: Transform3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed
	var l: float = p.l
	var d: float = p.d
	var n: int = maxi(p.get("n", 1), 1)
	var w := l / n  # porrasmoduulin leveys
	var krs: int = clampi(p.get("krs", 2), 2, 3)
	var wall: Color = p.wall
	var roof: Color = p.roof
	var trim: Color = p.trim
	var drop: float = p.get("drop", 0.2)
	var flat: bool = p.get("flat", true)
	var liike: bool = p.get("liike", false)
	var bdp := 1.4  # parvekkeen syvyys
	var bd := d - bdp  # rungon syvyys
	var xb := xf * Transform3D(Basis(), Vector3(0, 0, -bdp / 2.0))  # runko julkisivun puolelle, parvekkeet taakse
	var plinth := 0.6
	var fh := 3.0  # kerroskorkeus
	var h_e := plinth + fh * krs
	var a := deg_to_rad(rng.randf_range(10.0, 14.0))
	var concrete := Color(0.6, 0.59, 0.56)
	var frame := WHITE_FRAME if wall.get_luminance() < 0.6 else trim
	_plinth(r, xb, l, bd, plinth, drop, concrete)
	_box(r, xb, Vector3(l, h_e - plinth, bd), Vector3(0, (h_e + plinth) / 2.0, 0), wall)
	var top := h_e + 0.6
	if flat:  # tasakatto: otsalauta (pelti) ja huopakate
		_box(r, xb, Vector3(l + 0.3, 0.6, bd + 0.3), Vector3(0, h_e + 0.3, 0), trim)
		_box(r, xb, Vector3(l + 0.1, 0.04, bd + 0.1), Vector3(0, h_e + 0.6, 0), roof)
	else:
		top = _gable(r, sm, xb, l, bd, h_e, a, 0.5, 0.4, 0.14, wall, roof, trim, false, true)
	var fz := -bd / 2.0  # julkisivun z (xb-kehyksessä)
	var bz := bd / 2.0  # takaseinän z
	for sx in [-1.0, 1.0]:  # päätyjen ikkunat kerroksittain
		for f in krs:
			_window(r, sm, xb, Vector3(sx * l / 2.0, plinth + fh * f + 1.5, -bd * 0.2), Vector3(sx, 0, 0), 1.2, 1.4, frame, 2, 1)
	var doors: Array[Vector3] = []
	var glass_col := GLASS.lightened(0.08)
	for i in n:
		var xm := -l / 2.0 + w * (i + 0.5)
		# Porrashuone: ovi katoksineen ja ikkunanauha välitasanteiden korkeudella koko talon korkeudelta.
		_door(r, sm, xb, Vector3(xm, plinth, fz), Vector3(0, 0, -1), 1.2, 2.1, frame, Color(0.35, 0.24, 0.15), plinth)
		doors.append(Vector3(xm, 0, -d / 2.0 - 1.2))
		_box(r, xb, Vector3(2.4, 0.18, 0.95), Vector3(xm, plinth + 2.55, fz - 0.475), trim)
		var sy0 := plinth + 3.0
		var sy1 := h_e - 0.5
		_window(r, sm, xb, Vector3(xm, (sy0 + sy1) / 2.0, fz), Vector3(0, 0, -1), 1.1, sy1 - sy0, frame, 1, krs - 1 if krs > 2 else 2)
		for sx: float in [-1.0, 1.0]:
			for k: float in [0.18, 0.36]:  # kellarin ikkunat sokkelissa
				_box(sm, xb, Vector3(0.9, 0.3, 0.04), Vector3(xm + sx * w * k, plinth * 0.55, fz - 0.06), GLASS)
			_box(sm, xb, Vector3(0.9, 0.3, 0.04), Vector3(xm + sx * w * 0.3, plinth * 0.55, bz + 0.06), GLASS)
			for f in krs:
				var wy := plinth + fh * f + 1.5
				if f == 0 and liike:  # näyteikkuna
					_window(r, sm, xb, Vector3(xm + sx * w * 0.27, plinth + 1.45, fz), Vector3(0, 0, -1), w * 0.3, 2.1, frame, 3, 1)
				else:
					for k: float in [0.17, 0.36]:
						_window(r, sm, xb, Vector3(xm + sx * w * k, wy, fz), Vector3(0, 0, -1), 1.5, 1.4, frame, 2, 1)
				# Takana: parveke (laatta, umpikaide, sivukaiteet) ja parvekeovi, uloimpana ikkuna.
				var px := xm + sx * w * 0.2
				var bw := minf(3.4, w * 0.3)
				_box(r, xb, Vector3(bw, 0.16, bdp), Vector3(px, plinth + fh * f - 0.08, bz + bdp / 2.0), concrete)
				_box(r, xb, Vector3(bw, 1.0, 0.08), Vector3(px, plinth + fh * f + 0.5, bz + bdp - 0.04), wall.lerp(concrete, 0.6))
				for sg: float in [-1.0, 1.0]:
					_box(sm, xb, Vector3(0.06, 1.0, bdp - 0.08), Vector3(px + sg * (bw / 2.0 - 0.03), plinth + fh * f + 0.5, bz + bdp / 2.0 - 0.04), wall.lerp(concrete, 0.6).darkened(0.1))
				_window(r, sm, xb, Vector3(px - sx * 0.6, plinth + fh * f + 1.1, bz), Vector3(0, 0, 1), 0.9, 2.1, frame, 1, 1)
				_window(r, sm, xb, Vector3(xm + sx * w * 0.42, wy, bz), Vector3(0, 0, 1), 1.3, 1.4, frame, 2, 1)
		_box(sm, xb, Vector3(1.4, 0.05, 0.12), Vector3(xm, plinth + 2.66, fz - 0.06), glass_col)  # katoksen valolista
	# Kerrosten välinen vaakalista julkisivussa (näkyy kauas tiilen ja rappauksen saumana).
	for f in range(1, krs):
		for sz in [-1.0, 1.0]:
			_box(sm, xb, Vector3(l + 0.04, 0.12, 0.04), Vector3(0, plinth + fh * f, sz * (bd / 2.0 + 0.02)), wall.darkened(0.12))
	return {
		"door": doors[n / 2],
		"doors": doors,
		"foot": {"runko": _rect(0, 0, l / 2.0, d / 2.0)},
		"shapes": [[Vector3(l, top, bd), Vector3(0, top / 2.0, -bdp / 2.0)], [Vector3(l, h_e, bdp), Vector3(0, h_e / 2.0, d / 2.0 - bdp / 2.0)]],
		"h_top": top,
		"mitat": {"kulma": 0.0 if flat else rad_to_deg(a), "raystas": h_e, "krs": float(krs), "moduuli": w},
	}


## K8 halli: pitkä suorakaide, harja X:n suuntainen, kehäpilarilistat kehävälein (l / k, k = round(l / 6)) ja
## profiilipellin urat 1 m välein (pienet osat). Variantit (p.v):
##   kone: seinä 4,5 m, harjakatto 18°, 2–3 liukuovea julkisivussa (-Z), valkoiset nurkkalistat (Rapko Konehalli 14 x 20).
##   teollisuus: seinä 5–6 m, katto 10–14° (5–7°, jos d > 20 m), +X-päädyssä nosto-ovi ja henkilöovi.
##   liike: tasakatto 0,6 m:n otsapellein, seinä 4,2–5 m, näyteikkunanauha ja lasiovi katoksineen julkisivussa.
##   suoja: pulpettikatto 8–12° (korkea reuna julkisivussa), avoin julkisivu, pilari joka kehävälillä.
## Kaikki katon kallistuvat osat (lappeet, pulpetin laatta, päätykolmio ja pilarien korkeus) samasta
## kaltevuusvektorista. Seinän alaosa sokkelia, ikkunanauha ylhäällä (kone, teollisuus).
## p: l, d, wall, roof, trim, seed, v; drop.
static func _k8(p: Dictionary, r: B.Batch, sm: B.Batch, xf: Transform3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed
	var l: float = p.l
	var d: float = p.d
	var v: String = p.get("v", "kone")
	var wall: Color = p.wall
	var roof: Color = p.roof
	var trim: Color = p.trim
	var drop: float = p.get("drop", 0.2)
	var k := maxi(2, roundi(l / 6.0))
	var bay := l / k  # kehäväli
	var plinth := 0.3
	var hw := 4.5  # räystäskorkeus
	var a := deg_to_rad(18.0)
	match v:
		"teollisuus":
			hw = rng.randf_range(5.0, 6.0)
			a = deg_to_rad(rng.randf_range(5.0, 7.0) if d > 20.0 else rng.randf_range(10.0, 14.0))
		"liike":
			hw = rng.randf_range(4.2, 5.0)
			a = 0.0
		"suoja":
			hw = rng.randf_range(3.6, 4.2)  # matala takaseinä
			a = deg_to_rad(rng.randf_range(8.0, 12.0))
	var concrete := Color(0.6, 0.59, 0.56)
	var pil := trim  # kehäpilarilistat ja nurkkalistat
	var ura := wall.darkened(0.18)
	var top := hw
	var doors: Array[Vector3] = []
	var door := Vector3(0, 0, -d / 2.0 - 1.2)
	var shapes: Array = []
	if v == "suoja":
		# Pulpetti: lappeen suunta u takaräystäältä (+Z) etureunaan (-Z) ylös, normaali n; korkeus z:ssä y(z).
		var u := Vector3(0, sin(a), -cos(a))
		var nn := Vector3(0, cos(a), sin(a))
		var ov := 0.4
		var t := 0.12
		var rise := d * tan(a)
		var back := Vector3(0, hw - ov * tan(a), d / 2.0 + ov)  # laatan alapinnan takareuna
		var slab_l := (d + 2.0 * ov) / cos(a)
		var bs := Basis(Vector3.RIGHT, nn, Vector3.RIGHT.cross(nn))
		_box(r, xf, Vector3(l + 0.6, t, slab_l), back + u * slab_l / 2.0 + nn * t / 2.0, roof, bs)
		_box(r, xf, Vector3(l + 0.6, 0.25, 0.05), back + u * slab_l + Vector3(0, -0.05, -0.02), trim)  # otsalauta edessä
		_plinth(r, xf * Transform3D(Basis(), Vector3(0, 0, d / 2.0 - 0.1)), l, 0.2, plinth, drop, concrete)
		_box(r, xf, Vector3(l, hw - plinth, 0.15), Vector3(0, (hw + plinth) / 2.0, d / 2.0 - 0.075), wall)  # takaseinä
		for sx in [-1.0, 1.0]:  # päätyseinät: suorakaide räystääseen ja kolmio lappeen alle (apex edessä)
			_box(r, xf, Vector3(0.15, hw, d), Vector3(sx * (l / 2.0 - 0.075), hw / 2.0, 0), wall)
			var tri := PrismMesh.new()
			tri.left_to_right = 0.0
			tri.size = Vector3(d, rise, 0.15)
			r.add(tri, xf * Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(sx * (l / 2.0 - 0.075), hw + rise / 2.0, 0)), wall)
		for i in range(1, k):  # pilarit etureunassa kehävälein (päissä päätyseinä), korkeus lappeen alapintaan
			var x := -l / 2.0 + bay * i
			var z := -d / 2.0 + 0.1
			var y := hw + (d / 2.0 - z) * tan(a)
			_box(r, xf, Vector3(0.2, y, 0.2), Vector3(x, y / 2.0, z), pil)
			shapes.append([Vector3(0.2, y, 0.2), Vector3(x, y / 2.0, z)])
		_box(r, xf, Vector3(l, 0.3, 0.2), Vector3(0, hw + rise - 0.15 - 0.2 * tan(a), -d / 2.0 + 0.1), pil)  # etupalkki
		var kl := mini(int(l), 80)
		for i in range(1, kl):  # takaseinän urat
			_box(sm, xf, Vector3(0.05, hw - plinth - 0.1, 0.03), Vector3(-l / 2.0 + l * i / kl, (hw + plinth) / 2.0, d / 2.0 + 0.01), ura)
		top = hw + rise + t
		shapes.append([Vector3(l, hw, 0.15), Vector3(0, hw / 2.0, d / 2.0 - 0.075)])
		for sx in [-1.0, 1.0]:
			shapes.append([Vector3(0.15, hw, d), Vector3(sx * (l / 2.0 - 0.075), hw / 2.0, 0)])
		door = Vector3(0, 0, -d / 2.0 - 1.2)
	else:
		_plinth(r, xf, l, d, plinth, drop, concrete)
		_box(r, xf, Vector3(l, hw - plinth, d), Vector3(0, (hw + plinth) / 2.0, 0), wall)
		if v == "liike":
			_box(r, xf, Vector3(l + 0.2, 0.6, d + 0.2), Vector3(0, hw + 0.3, 0), trim)  # otsapelti
			_box(r, xf, Vector3(l, 0.04, d), Vector3(0, hw + 0.58, 0), roof)
			top = hw + 0.6
		else:
			top = _gable(r, sm, xf, l, d, hw, a, 0.4, 0.3, 0.12, wall, roof, trim, false, true)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box(r, xf, Vector3(0.2, hw - plinth, 0.2), Vector3(sx * l / 2.0, (hw + plinth) / 2.0, sz * d / 2.0), WHITE_FRAME if v == "kone" else pil)
		# Ovet: kone liukuovet julkisivun kehäväleissä, liike lasiovi keskellä, teollisuus +X-päädyssä.
		var door_bays: Array[int] = []
		if v == "kone":
			var nd := mini(clampi((k + 1) / 2, 2, 3), k)
			for j in nd:
				door_bays.append(int(round((j + 0.5) * k / nd - 0.5)))
		var open_f: Array = []  # julkisivun aukot [x, puolileveys] (urat väistävät)
		for bi in door_bays:
			var xc := -l / 2.0 + bay * (bi + 0.5)
			var dw := minf(5.0, bay - 0.8)
			var dh := minf(4.0, hw - 0.5)
			_box(r, xf, Vector3(dw, dh, 0.1), Vector3(xc, dh / 2.0 + 0.02, -d / 2.0 - 0.06), wall.darkened(0.08))
			_box(r, xf, Vector3(dw + 0.4, 0.18, 0.16), Vector3(xc, dh + 0.12, -d / 2.0 - 0.1), pil)  # kisko
			_box(sm, xf, Vector3(0.1, dh, 0.04), Vector3(xc - dw / 2.0 + 0.05, dh / 2.0, -d / 2.0 - 0.12), WHITE_FRAME)
			_box(sm, xf, Vector3(0.1, dh, 0.04), Vector3(xc + dw / 2.0 - 0.05, dh / 2.0, -d / 2.0 - 0.12), WHITE_FRAME)
			_box(sm, xf, Vector3(dw, 0.08, 0.04), Vector3(xc, dh * 0.5, -d / 2.0 - 0.12), WHITE_FRAME)
			for sg in [-1.0, 1.0]:  # vinotuet (X-ristikko)
				var ang := atan2(dh * 0.45, dw - 0.2)
				_box(sm, xf, Vector3(sqrt(pow(dw - 0.2, 2.0) + pow(dh * 0.45, 2.0)), 0.08, 0.04),
					Vector3(xc, dh * 0.25 + 0.02, -d / 2.0 - 0.13), WHITE_FRAME, Basis(Vector3.BACK, sg * ang))
			open_f.append([xc, dw / 2.0])
			doors.append(Vector3(xc, 0, -d / 2.0 - 1.5))
		if v == "liike":
			var gw := minf(3.0, l * 0.12)
			_door(r, sm, xf, Vector3(0, plinth, -d / 2.0), Vector3(0, 0, -1), 1.8, 2.2, WHITE_FRAME, GLASS.lightened(0.15), plinth)
			_box(r, xf, Vector3(gw + 2.0, 0.3, 0.95), Vector3(0, plinth + 2.75, -d / 2.0 - 0.475), trim)  # katos
			open_f.append([0.0, gw / 2.0 + 1.0])
			doors.append(Vector3(0, 0, -d / 2.0 - 1.2))
		elif v == "teollisuus":
			var dw := minf(4.5, d * 0.35)
			var dh := minf(4.2, hw - 0.6)
			var zc := d * 0.12
			_box(r, xf, Vector3(0.1, dh, dw), Vector3(l / 2.0 + 0.05, dh / 2.0, zc), Color(0.82, 0.82, 0.8))  # nosto-ovi
			_box(r, xf, Vector3(0.14, 0.3, dw + 0.5), Vector3(l / 2.0 + 0.07, dh + 0.15, zc), pil)
			for j in range(1, int(dh / 0.6)):
				_box(sm, xf, Vector3(0.04, 0.04, dw), Vector3(l / 2.0 + 0.11, j * 0.6, zc), Color(0.62, 0.62, 0.6))
			var pz := zc - dw / 2.0 - 1.6
			_door(r, sm, xf, Vector3(l / 2.0, plinth, pz), Vector3(1, 0, 0), 1.0, 2.1, pil, Color(0.5, 0.5, 0.52), plinth)
			door = Vector3(l / 2.0 + 1.2, 0, pz)
			doors.append(door)
		if not doors.is_empty():
			door = doors[0]
		# Kehäpilarilistat ja ikkunanauha (liikkeellä näyteikkunat alhaalla) kehäväleittäin.
		for i in k:
			var x0 := -l / 2.0 + bay * i
			if i > 0:
				for sz in [-1.0, 1.0]:
					_box(r, xf, Vector3(0.22, hw - plinth, 0.08), Vector3(x0, (hw + plinth) / 2.0, sz * (d / 2.0 + 0.04)), pil)
			var xc := x0 + bay / 2.0
			if i in door_bays:
				continue
			if v == "liike":
				var ww := bay - 1.0
				if absf(xc) < ww / 2.0 + 1.2:
					continue  # oven kohta
				_box(r, xf, Vector3(ww, 2.4, 0.06), Vector3(xc, plinth + 1.6, -d / 2.0 - 0.03), GLASS)
				_box(sm, xf, Vector3(ww + 0.12, 0.08, 0.08), Vector3(xc, plinth + 2.84, -d / 2.0 - 0.04), WHITE_FRAME)
				open_f.append([xc, ww / 2.0 + 0.1])
			else:
				var ww := bay - 1.2
				_box(r, xf, Vector3(ww, 0.7, 0.06), Vector3(xc, hw - 0.75, -d / 2.0 - 0.03), GLASS)
				_box(sm, xf, Vector3(ww + 0.1, 0.06, 0.08), Vector3(xc, hw - 1.12, -d / 2.0 - 0.04), WHITE_FRAME)
		# Profiilipellin urat 1 m välein (liike: tiili tai pelti ilman uria), enintään 80 sivua kohti.
		if v != "liike":
			var kl := mini(int(l), 80)
			var uh := hw - plinth - 0.1
			for i in range(1, kl):
				var x := -l / 2.0 + l * i / kl
				for sz in [-1.0, 1.0]:
					var free := true
					if sz < 0.0:
						for o: Array in open_f:
							if absf(x - o[0]) < o[1] + 0.15:
								free = false
					if free:
						_box(sm, xf, Vector3(0.05, uh, 0.03), Vector3(x, (hw + plinth) / 2.0, sz * (d / 2.0 + 0.015)), ura)
			var kd := mini(int(d), 30)
			for i in range(1, kd):
				var z := -d / 2.0 + d * i / kd
				for sx in [-1.0, 1.0]:
					_box(sm, xf, Vector3(0.03, uh, 0.05), Vector3(sx * (l / 2.0 + 0.015), (hw + plinth) / 2.0, z), ura)
		shapes.append([Vector3(l, top, d), Vector3(0, top / 2.0, 0)])
	return {
		"door": door,
		"doors": doors,
		"foot": {"runko": _rect(0, 0, l / 2.0, d / 2.0)},
		"shapes": shapes,
		"h_top": top,
		"mitat": {"kulma": rad_to_deg(a), "raystas": hw, "krs": 1.0, "moduuli": bay},
	}
