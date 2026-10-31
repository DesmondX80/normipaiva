extends "res://scripts/klaffipoyta.gd"
## Hoitajan lääkelaukku (Saloisten jatkamisbonus, huume_saloinen.gd): vanha ruskea nahkainen lääkärinlaukku, jonka
## Kinnapotin apteekin hoitaja jättää portaalle kolmannen oston jälkeen. Sama 3×3-askartelu ja samat reseptit kuin
## klaffipöydällä (perii klaffipoyta.gd:n), mutta laukulla jatkettu erä on "puhdas": sen paljastumisporras on yhtä
## alempi (main.gd _craft_do(..., true) -> huume_saloinen.gd lisaa_puhdas). Vain ulkoasu ja askartelu ohitetaan.

const Makasiini := preload("res://scripts/makasiini.gd")

const LEATHER := Color(0.42, 0.24, 0.12)
const LEATHER_DARK := Color(0.27, 0.15, 0.07)
const LEATHER_LIGHT := Color(0.58, 0.36, 0.19)
const STITCH := Color(0.86, 0.74, 0.5)
const BRASS := Color(0.8, 0.64, 0.28)
const BRASS_DARK := Color(0.45, 0.33, 0.12)
const LINING := Color(0.86, 0.8, 0.66)


func _ready() -> void:
	super._ready()
	Sfx.play("pickup", -10.0, 0.6)
	_say("Lukot auki. Laukulla jatkettu tavara on puhtaampaa: vähemmän kiinnijäämisiä.", 6.0)


func _do_craft(m: Dictionary) -> String:
	return game._craft_do(m.id, m.drug, true)


## Avoin laukku ylhäältä: nahkareunat tikkauksineen, messinkinen suukehys ja lukot, kahva, vaalea kangasvuori
## (ruudukko ja reppu piirretään vuorin päälle), keskellä nahkainen väliseinätasku. Sama levyn koko kuin klaffipöydällä.
func _draw_board(ci: Control, s: Vector2) -> Rect2:
	var font := ThemeDB.fallback_font
	ci.draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.03, 0.02, 0.82))
	var top := Rect2((s - Vector2(980, 620)) / 2.0, Vector2(980, 620))
	var outer := top.grow(22)
	# Varjo pöydälle oikealle alas.
	ci.draw_rect(Rect2(outer.position + Vector2(14, 16), outer.size), Color(0, 0, 0, 0.45))
	# Nahkakuori: vaalea yläreuna, tumma alareuna (vaakasuorat sävykaistat).
	var bands := 10
	for k in bands:
		var f := float(k) / float(bands - 1)
		var c := LEATHER_LIGHT.lerp(LEATHER, minf(1.0, f * 2.0)) if f < 0.5 else LEATHER.lerp(LEATHER_DARK, (f - 0.5) * 2.0)
		ci.draw_rect(Rect2(outer.position.x, outer.position.y + k * outer.size.y / bands, outer.size.x, outer.size.y / bands + 1.0), c)
	# Nahan kulumat ja syyt (siemenluku kiinteä: sama kuvio joka ruudussa).
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in 70:
		var p := outer.position + Vector2(rng.randf() * outer.size.x, rng.randf() * outer.size.y)
		ci.draw_line(p, p + Vector2(rng.randf_range(8, 30), rng.randf_range(-2, 2)), Color(0.2, 0.1, 0.04, 0.25), 1.0)
	for sx in [0.0, 1.0]:
		for sy in [0.0, 1.0]:  # kuluneet kulmat: tummempi neljännes kulman sisäpuolella
			var corner := outer.position + outer.size * Vector2(sx, sy)
			ci.draw_rect(Rect2(corner - Vector2(sx, sy) * 34.0, Vector2(34, 34)), Color(0.2, 0.1, 0.04, 0.3))
	ci.draw_rect(outer, Color(0.14, 0.07, 0.03), false, 3.0)
	# Tikkaus kuoren reunassa.
	_stitch_rect(ci, outer.grow(-9))
	# Vuori: vaalea kangas, varjo kehyksen alla ja kudoksen raidat.
	ci.draw_rect(top, LINING)
	for k in 62:
		var y := top.position.y + k * 10.0
		ci.draw_line(Vector2(top.position.x, y), Vector2(top.end.x, y), LINING.darkened(0.06), 1.0)
	ci.draw_rect(Rect2(top.position, Vector2(top.size.x, 18)), Color(0.25, 0.15, 0.06, 0.35))
	ci.draw_rect(Rect2(top.position, Vector2(14, top.size.y)), Color(0.25, 0.15, 0.06, 0.25))
	# Messinkinen suukehys vuorin ympärillä (kiilto yläreunassa).
	ci.draw_rect(top.grow(6), BRASS_DARK, false, 6.0)
	ci.draw_line(top.position + Vector2(-3, -5), Vector2(top.end.x + 3, top.position.y - 5), BRASS, 2.0)
	# Väliseinätasku keskellä (ruudukon ja repun välissä), tikattu reuna.
	var cx := top.position.x + 604.0  # tuloksen nimen (enintään ~600) ja repun (620) välissä
	var pocket := Rect2(cx, top.position.y + 6, 14, top.size.y - 12)
	ci.draw_rect(pocket, LEATHER)
	ci.draw_rect(Rect2(pocket.position, Vector2(4, pocket.size.y)), LEATHER_LIGHT)
	ci.draw_rect(Rect2(pocket.end.x - 4, pocket.position.y, 4, pocket.size.y), LEATHER_DARK)
	for k in int(pocket.size.y / 14.0):
		var y := pocket.position.y + 7 + k * 14.0
		ci.draw_line(Vector2(cx + 7, y), Vector2(cx + 7, y + 7), STITCH, 2.0)
	# Messinkilukot yläreunassa: levy, kieli ja niitit.
	for lx in [top.get_center().x - 170.0, top.get_center().x + 170.0]:
		var lr := Rect2(lx - 26, outer.position.y - 4, 52, 34)
		ci.draw_rect(lr.grow(2), BRASS_DARK)
		ci.draw_rect(lr, BRASS)
		ci.draw_rect(Rect2(lr.position, Vector2(lr.size.x, 7)), BRASS.lightened(0.35))
		ci.draw_rect(Rect2(lr.position.x, lr.end.y - 6, lr.size.x, 6), BRASS_DARK)
		ci.draw_rect(Rect2(lx - 8, lr.end.y - 2, 16, 14), BRASS_DARK)
		ci.draw_rect(Rect2(lx - 6, lr.end.y - 2, 12, 11), BRASS)
		for rx in [-18.0, 18.0]:
			ci.draw_circle(Vector2(lx + rx, lr.position.y + 17), 3.0, BRASS_DARK)
			ci.draw_circle(Vector2(lx + rx - 1, lr.position.y + 16), 1.2, BRASS.lightened(0.5))
	# Kahva lepää kaatuneena kehyksen päällä lukkojen välissä: nahkaremmi tikkauksineen, päissä messinkirenkaat.
	var hy := top.position.y - 6.0
	var hx0 := top.get_center().x - 110.0
	var hx1 := top.get_center().x + 110.0
	ci.draw_rect(Rect2(hx0 + 4, hy - 8, hx1 - hx0, 22), Color(0, 0, 0, 0.35))
	ci.draw_rect(Rect2(hx0, hy - 12, hx1 - hx0, 22), LEATHER_DARK)
	ci.draw_rect(Rect2(hx0 + 2, hy - 10, hx1 - hx0 - 4, 9), LEATHER_LIGHT)
	ci.draw_rect(Rect2(hx0 + 2, hy - 1, hx1 - hx0 - 4, 9), LEATHER)
	for k in int((hx1 - hx0 - 30) / 12.0):
		var x := hx0 + 15 + k * 12.0
		ci.draw_line(Vector2(x, hy - 7), Vector2(x + 6, hy - 7), STITCH, 1.5)
		ci.draw_line(Vector2(x, hy + 5), Vector2(x + 6, hy + 5), STITCH.darkened(0.3), 1.5)
	for x in [hx0, hx1]:
		ci.draw_arc(Vector2(x, hy - 1), 11.0, 0.0, TAU, 18, BRASS_DARK, 6.0)
		ci.draw_arc(Vector2(x, hy - 1), 11.0, PI, TAU, 12, BRASS.lightened(0.2), 2.5)
	# Nimilaatta:messinkilevy, painettu teksti ja pieni punainen risti.
	var tag := Rect2(top.position + Vector2(20, 18), Vector2(330, 46))
	ci.draw_rect(Rect2(tag.position + Vector2(3, 4), tag.size), Color(0, 0, 0, 0.3))
	ci.draw_rect(tag, BRASS)
	ci.draw_rect(Rect2(tag.position, Vector2(tag.size.x, 8)), BRASS.lightened(0.3))
	ci.draw_rect(tag, BRASS_DARK, false, 2.0)
	var rc := tag.position + Vector2(26, 23)
	ci.draw_rect(Rect2(rc - Vector2(11, 4), Vector2(22, 8)), Color(0.75, 0.1, 0.1))
	ci.draw_rect(Rect2(rc - Vector2(4, 11), Vector2(8, 22)), Color(0.75, 0.1, 0.1))
	ci.draw_string(font, tag.position + Vector2(48, 32), "LÄÄKELAUKKU", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.25, 0.15, 0.04))
	return top


## Tikkausrivi suorakulmion reunoille (lyhyet vaaleat viivat ja aukot).
func _stitch_rect(ci: Control, r: Rect2) -> void:
	var step := 14.0
	for k in int(r.size.x / step):
		var x := r.position.x + k * step
		ci.draw_line(Vector2(x, r.position.y), Vector2(x + 8, r.position.y), STITCH, 2.0)
		ci.draw_line(Vector2(x, r.end.y), Vector2(x + 8, r.end.y), STITCH.darkened(0.25), 2.0)
	for k in int(r.size.y / step):
		var y := r.position.y + k * step
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.position.x, y + 8), STITCH, 2.0)
		ci.draw_line(Vector2(r.end.x, y), Vector2(r.end.x, y + 8), STITCH.darkened(0.15), 2.0)


## 3D-laukku portaalle (umpinaiset palat, makasiini.gd Parts). Origo pohjan keskellä, pituus X, leveys Z, korkeus Y.
## Runko: suorakulmainen alaosa, jonka sivut kapenevat messinkiseen suukehykseen; kahva kehyksen päällä.
const PROP_L := 0.42
const PROP_W := 0.2
const PROP_H := 0.3  # kahvan lakeen

static func build_prop() -> Node3D:
	var root := Node3D.new()
	root.name = "Laakelaukku"
	var lea := Makasiini.Parts.new()
	var met := Makasiini.Parts.new()
	var l := PROP_L
	var hw := PROP_W / 2.0
	var foot := 0.012
	var y0 := foot  # rungon pohja
	var y1 := 0.17  # suora sivu loppuu, kapeneva yläosa alkaa
	var y2 := 0.25  # suukehys
	var tw := 0.03  # kehyksen puolileveys
	# Messinkijalat pohjan kulmissa.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			met.cyl(0.012, foot, Vector3(sx * (l / 2.0 - 0.04), foot / 2.0, sz * (hw - 0.03)), BRASS)
	# Pohja (tumma), suora runko ja vaaleampi yläreuna.
	lea.box(Vector3(l, 0.02, PROP_W), Vector3(0, y0 + 0.01, 0), LEATHER_DARK)
	lea.box(Vector3(l, y1 - y0 - 0.02, PROP_W), Vector3(0, (y0 + 0.02 + y1) / 2.0, 0), LEATHER)
	# Kapenevat etu- ja takapaneelit: laatta kahden pisteen välissä YZ-tasossa.
	for sz in [-1.0, 1.0]:
		var a := Vector3(0, y1, sz * hw)
		var b := Vector3(0, y2, sz * tw)
		_slab(lea, a, b, l, 0.014, sz, LEATHER_LIGHT)
		# Saumarulla (tumma nahkapaspeli) kapenevan osan alareunassa.
		lea.box(Vector3(l + 0.004, 0.008, 0.008), Vector3(0, y1, sz * hw), LEATHER_DARK)
	# Päätykappaleet: kapeneva yläosa täytetään porrastetuilla laatoilla (umpinainen, ei aukkoa).
	var steps := 4
	for k in steps:
		var t0 := float(k) / steps
		var t1 := float(k + 1) / steps
		var w := lerpf(hw, tw, (t0 + t1) / 2.0) * 2.0 - 0.02
		lea.box(Vector3(l - 0.01, (y2 - y1) / steps, w), Vector3(0, y1 + (y2 - y1) * (t0 + t1) / 2.0, 0), LEATHER)
	# Kulmasuojat päädyissä (tumma nahka).
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			lea.box(Vector3(0.04, 0.05, 0.04), Vector3(sx * (l / 2.0 - 0.018), y0 + 0.025, sz * (hw - 0.018)), LEATHER_DARK)
	# Messinkinen suukehys ja kaksi lukkoa edessä (+Z).
	met.box(Vector3(l + 0.01, 0.014, 0.012), Vector3(0, y2, tw), BRASS)
	met.box(Vector3(l + 0.01, 0.014, 0.012), Vector3(0, y2, -tw), BRASS)
	met.box(Vector3(0.012, 0.02, tw * 2.0 + 0.012), Vector3(-(l / 2.0 + 0.004), y2, 0), BRASS_DARK)
	met.box(Vector3(0.012, 0.02, tw * 2.0 + 0.012), Vector3(l / 2.0 + 0.004, y2, 0), BRASS_DARK)
	var lb := Basis(Vector3(1, 0, 0), -atan2(hw - tw, y2 - y1))  # etupaneelin kehys: y ylös pitkin paneelia, z ulos
	var slant := Vector2(y2 - y1, hw - tw).length()
	for lx in [-0.09, 0.09]:
		var lp := Vector3(lx, lerpf(y1, y2, 0.75), lerpf(hw, tw, 0.75)) + lb.z * 0.004
		met.box(Vector3(0.04, 0.03, 0.008), lp, BRASS, lb)
		# Remmi rungon kyljestä lukolle: pystyosa etusivulla ja kapenevan paneelin osa (tumma nahka).
		lea.box(Vector3(0.026, y1 - y0 - 0.03, 0.006), Vector3(lx, (y0 + 0.03 + y1) / 2.0, hw + 0.003), LEATHER_DARK)
		var sp := Vector3(lx, lerpf(y1, y2, 0.33), lerpf(hw, tw, 0.33)) + lb.z * 0.003
		lea.box(Vector3(0.026, slant * 0.66, 0.006), sp, LEATHER_DARK, lb)
	# Kahva: kaareva nahkaremmi kehyksen päällä, päissä messinkiset kiinnikkeet.
	var hr := 0.075
	var segs := 7
	for k in segs:
		var a0 := PI * float(k) / segs
		var a1 := PI * float(k + 1) / segs
		var p0 := Vector3(cos(a0) * hr, y2 + 0.005 + sin(a0) * (PROP_H - y2 - 0.01), 0)
		var p1 := Vector3(cos(a1) * hr, y2 + 0.005 + sin(a1) * (PROP_H - y2 - 0.01), 0)
		var mid := (p0 + p1) / 2.0
		var d := p1 - p0
		lea.box(Vector3(d.length() + 0.006, 0.014, 0.026), mid, LEATHER_DARK, Basis(Vector3(0, 0, 1), atan2(d.y, d.x)))
	for sx in [-1.0, 1.0]:
		met.box(Vector3(0.02, 0.016, 0.03), Vector3(sx * hr, y2 + 0.008, 0), BRASS_DARK)
	lea.commit(root)
	met.commit(root, 0.7)
	return root


## Laatta pisteestä a pisteeseen b (YZ-tasossa, pituus l X:n suunnassa), paksuus sisäänpäin rungon keskeltä poispäin.
static func _slab(p: Makasiini.Parts, a: Vector3, b: Vector3, l: float, th: float, side: float, color: Color) -> void:
	var d := b - a
	var ang := atan2(d.z, d.y)  # kallistus X-akselin ympäri
	var bas := Basis(Vector3(1, 0, 0), ang)
	var mid := (a + b) / 2.0 - bas.z * th / 2.0 * side
	p.box(Vector3(l, d.length(), th), mid, color, bas)
