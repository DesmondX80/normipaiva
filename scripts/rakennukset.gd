extends RefCounted
## Maiseman täytetalot (Saloinen ja Vaala): viisi tunnistettavaa tyyppiä esikuvien mukaan
## (.claude/tyo/rakennukset-maisema/01-esikuvat.md; docs/pelin-sisalto.md "Maiseman talot (K1–K5)").
##   K1 rintamamiestalo, K2 matala 70–80-luvun omakotitalo, K3 aitta, K4 lato, K5 Raahen keltainen puutalo.
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
##   mitat: {kulma (astetta), raystas (räystäskorkeus m), krs} testikohtaukselle (tools/testit/rakennukset_kuvat).

const B := preload("res://scripts/build.gd")

const GLASS := Color(0.12, 0.17, 0.24)
const STONE := Color(0.46, 0.46, 0.45)
const BRICK := Color(0.52, 0.24, 0.18)


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
