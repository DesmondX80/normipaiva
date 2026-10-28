extends Control
## Matkaopas (näppäin B): taksikuskilta saatu pehmeäkantinen taskuopas retkikohteista, päiväkirjan (journal.gd) sisarvihko.
## Sivut tulevat suoraan retkirekisteristä (retket.gd LISTA), joten nimi, hinta ja kesto ovat samat luvut kuin taksivalikossa ja
## uusi kohde saa sivun itsestään. Nimi, hinta ja kesto näkyvät heti; kuvaus (opas, puuttuessa sub) vasta käynnin jälkeen tai
## kun kohteesta on kuultu (rekisterin kuultu-ehto, esim. taksikuskin legenda). Käydyllä sivulla on KÄYTY-leima.
## Aukeama: ensin kansilehti ja sisällys, sitten kohde sivua kohden. A/D, nuolet, rulla ja sivunkulmat selaavat, Esc / B sulkee.
## Tallennukseen ei tule mitään uutta: "matkaopas" ja "retki_<id>" ovat tilat.firsts-ensikertoja.

const MG := preload("res://scripts/mg_draw.gd")
const Retket := preload("res://scripts/retket.gd")
const Quests := preload("res://scripts/quests.gd")
const PAPER := Color(0.98, 0.96, 0.9)
const PAPER_LOW := Color(0.93, 0.89, 0.8)
const INK := Color(0.16, 0.16, 0.2)
const RED := Color(0.62, 0.14, 0.12)
const CLOTH := Color(0.7, 0.17, 0.14)  # pehmeä kangaskansi (päiväkirja on nahkaa)
const STAMP := Color(0.2, 0.28, 0.62)
const LAHTO := {"taksi": "Taksi, K-Marketin tolppa", "vaala_asema": "Juna, Vaalan asema"}

var game: Node
var _links: Array = []  # [Rect2, retken id] "taksitolppa kartalle" -linkit tällä aukeamalla
var _toc: Array = []  # [Rect2, sivun numero] sisällyksen rivit
var overflow: Array = []  # kohteet, joiden nimi tai kuvaus ei mahtunut sivulle (testi lukee)

var _pages: Array = []  # sivut(): yksi kohde per sivu
var _spread := 0  # aukeama: sivut 2 * _spread (vasen) ja +1 (oikea); sivu 0 on kansilehti
var _book := Rect2()
var _hand: SystemFont
var _hover := ""  # "prev" / "next" kulma hiiren alla
var _keys: Control  # näppäinohjeet hattuina alareunassa (hint_bar.gd)


## Oppaan sivut rekisterin järjestyksessä. Kuvaus tiedossa, jos kohteessa on käyty tai rekisterin kuultu-ehto täyttyy.
static func sivut(lista: Dictionary, firsts: Array, flag: Callable) -> Array:
	var out: Array = []
	for id in lista:
		var r: Dictionary = lista[id]
		var kayty: bool = ("retki_" + id) in firsts
		var ehto: String = "first:retki_" + id + ("|" + String(r.kuultu) if r.has("kuultu") else "")
		out.append({"id": id, "nimi": r.nimi, "lahto": r.lahto, "hop_min": r.hop_min, "hinta": r.hinta,
			"kuvaus": String(r.get("opas", r.get("sub", ""))), "tiedossa": Quests.check(ehto, firsts, flag), "kayty": kayty})
	return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hand = SystemFont.new()
	_hand.font_names = PackedStringArray(["Bradley Hand", "Segoe Print", "Comic Sans MS", "Chalkboard SE", "Marker Felt",
		"Noteworthy", "sans-serif"])
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)


func owned() -> bool:
	return game != null and "matkaopas" in game.tilat.firsts


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		size = get_viewport_rect().size
		refresh()
		Sfx.play("cloth", -8.0, 1.1)
	_keys.set_text("%s selaa   [Klikkaa kulmaa] käännä   %s sulje" % [Settings.pair("left", "right"), Settings.cap("guide", "Esc")] if visible else "")
	queue_redraw()


func refresh() -> void:
	_pages = sivut(Retket.LISTA, game.tilat.firsts, func(f: String) -> bool: return game.quest_flag(f)) if game != null else []
	_spread = clampi(_spread, 0, _last_spread())
	queue_redraw()


func _last_spread() -> int:
	return _pages.size() / 2  # sivuja kansilehti + n kohdetta, viimeinen aukeama alkaa sivulta 2 * (n / 2)


func turn(d: int) -> void:
	var s := clampi(_spread + d, 0, _last_spread())
	if s == _spread:
		return
	_spread = s
	Sfx.play("cloth", -12.0, 1.6)
	queue_redraw()


func _process(_d: float) -> void:
	if Input.is_action_just_pressed("guide") or (visible and Input.is_key_pressed(KEY_ESCAPE)):
		if visible or (not get_tree().paused and owned()):
			toggle()
	if not visible:
		return
	var m := get_local_mouse_position()
	var h := "prev" if _corner(false).has_point(m) and _spread > 0 else ("next" if _corner(true).has_point(m) and _spread < _last_spread() else "")
	if h != _hover:
		_hover = h
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_A, KEY_LEFT:
			turn(-1)
		KEY_D, KEY_RIGHT:
			turn(1)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _corner(false).has_point(event.position):
					turn(-1)
				elif _corner(true).has_point(event.position):
					turn(1)
				else:
					for t in _toc:
						if (t[0] as Rect2).has_point(event.position):
							Sfx.play("cloth", -12.0, 1.6)
							_spread = int(t[1]) / 2
							queue_redraw()
					for l in _links:
						if (l[0] as Rect2).has_point(event.position):
							Sfx.play("pickup", -10.0, 1.3)
							game.show_retki_on_map(l[1])
							break
			MOUSE_BUTTON_WHEEL_DOWN:
				turn(1)
			MOUSE_BUTTON_WHEEL_UP:
				turn(-1)
		accept_event()


func _page(right: bool) -> Rect2:
	var half := (_book.size.x - 28) / 2.0
	return Rect2(_book.position + Vector2(14 + (half if right else 0.0), 12), Vector2(half, _book.size.y - 24))


## Sivun ulkokulma (taitos), jota klikkaamalla käännetään.
func _corner(right: bool) -> Rect2:
	var pg := _page(right)
	return Rect2(Vector2(pg.end.x - 52 if right else pg.position.x, pg.end.y - 52), Vector2(52, 52))


func _draw() -> void:
	_links.clear()
	_toc.clear()
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	var w := minf(1000.0, size.x - 80.0)
	var h := minf(640.0, size.y - 120.0)
	_book = Rect2((size - Vector2(w, h)) / 2.0 + Vector2(0, 8), Vector2(w, h))
	_cover()
	for right in [false, true]:
		var n: int = _spread * 2 + (1 if right else 0)
		_paper(right, n)
		if n == 0:
			_title_page(_page(false))
		elif n - 1 < _pages.size():
			_dest_page(_page(right), _pages[n - 1], n)
		else:
			_end_page(_page(right))
	_gutter()
	for right in [false, true]:
		if (right and _spread < _last_spread()) or (not right and _spread > 0):
			_dog_ear(right)
	MG.sign(self, Rect2(Vector2(_book.get_center().x - 150, _book.position.y - 46), Vector2(300, 42)), "MATKAOPAS",
		Color(0.97, 0.9, 0.62), Color(0.5, 0.1, 0.08), 24, Color(0.45, 0.1, 0.08))


## Kangaskansi: pehmeä punainen kangas, kudoksen raidat ja kulunut reuna; sivupino paksunee sillä puolella, jolla on luettu.
func _cover() -> void:
	var c := _book.grow(12)
	MG.box(self, c, CLOTH, 16, 14, CLOTH.darkened(0.45), 3)
	for y in range(int(c.position.y) + 6, int(c.end.y) - 6, 4):
		draw_line(Vector2(c.position.x + 8, y), Vector2(c.end.x - 8, y), Color(1, 0.85, 0.8, 0.05), 1.0)
	for x in range(int(c.position.x) + 8, int(c.end.x) - 8, 5):
		draw_line(Vector2(x, c.position.y + 6), Vector2(x, c.end.y - 6), Color(0.3, 0.02, 0.02, 0.05), 1.0)
	draw_rect(Rect2(c.position + Vector2(10, 8), Vector2(c.size.x - 20, 6)), Color(1, 0.8, 0.75, 0.18))  # yläreunan valo
	draw_rect(Rect2(Vector2(c.position.x + 10, c.end.y - 14), Vector2(c.size.x - 20, 6)), Color(0.2, 0.0, 0.0, 0.25))
	# Sivupino: luettu vasemmalle, lukematon oikealle.
	var frac := float(_spread) / maxf(_last_spread(), 1)
	for side in [false, true]:
		var n := int(round((frac if not side else 1.0 - frac) * 5.0)) + 1
		var pg := _page(side)
		for k in n:
			var o := float(n - k) * 1.6
			var r := Rect2(pg.position + Vector2(-o if not side else o, o), pg.size)
			draw_rect(r, PAPER_LOW.darkened(0.08 + k * 0.03))


func _paper(right: bool, n: int) -> void:
	var pg := _page(right)
	MG.grad_rect(self, pg, PAPER, PAPER_LOW)
	draw_rect(pg, Color(0.55, 0.45, 0.3, 0.5), false, 1.0)
	# Kellastunut reuna ja muutama kuitupilkku kiinteästä siemenestä.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + n
	for k in 3:
		var e := Rect2(pg.position + Vector2(k, k), pg.size - Vector2(k, k) * 2)
		draw_rect(e, Color(0.8, 0.65, 0.35, 0.12 - k * 0.035), false, 1.0)
	for k in 14:
		draw_circle(pg.position + Vector2(rng.randf() * pg.size.x, rng.randf() * pg.size.y), rng.randf_range(0.6, 1.4), Color(0.5, 0.4, 0.25, 0.18))
	if n > 0:
		draw_string(ThemeDB.fallback_font, Vector2(pg.position.x, pg.end.y - 14), str(n), HORIZONTAL_ALIGNMENT_CENTER, pg.size.x, 14,
			Color(0.45, 0.4, 0.35))


## Saumavarjo keskellä: kaksi liukuvaa varjoa ja ommel.
func _gutter() -> void:
	var mid := _book.position.x + 14 + _page(false).size.x
	var top := _book.position.y + 12
	var hh := _book.size.y - 24
	for k in 16:
		var a := 0.2 * pow(1.0 - k / 16.0, 2.0)
		draw_rect(Rect2(Vector2(mid - 1 - k * 1.5, top), Vector2(1.5, hh)), Color(0.25, 0.15, 0.05, a))
		draw_rect(Rect2(Vector2(mid + k * 1.5, top), Vector2(1.5, hh)), Color(0.25, 0.15, 0.05, a))
	for y in range(int(top) + 20, int(top + hh) - 10, 38):
		draw_line(Vector2(mid, y), Vector2(mid, y + 14), Color(0.55, 0.15, 0.1, 0.55), 2.0)


## Taitettu kulma: kulman kolmio taitetaan sivulle, taitteen alla varjo. Hiiren alla taitos isompi.
func _dog_ear(right: bool) -> void:
	var pg := _page(right)
	var s := 34.0 if _hover == ("next" if right else "prev") else 24.0
	var cx := pg.end.x if right else pg.position.x
	var dx := -1.0 if right else 1.0
	var tip := Vector2(cx, pg.end.y)
	var a := Vector2(cx + dx * s, pg.end.y)
	var b := Vector2(cx, pg.end.y - s)
	draw_colored_polygon(PackedVector2Array([tip, a, b]), CLOTH.darkened(0.2))  # kansi näkyy taitoksen alta
	var f := Vector2(cx + dx * s, pg.end.y - s)
	draw_colored_polygon(PackedVector2Array([a + Vector2(dx * 2, 2), b + Vector2(dx * 2, 2), f + Vector2(dx * 3, 3)]), Color(0, 0, 0, 0.2))
	draw_colored_polygon(PackedVector2Array([a, b, f]), PAPER_LOW.darkened(0.06))
	draw_polyline(PackedVector2Array([a, f, b]), Color(0.55, 0.45, 0.3, 0.7), 1.0)
	draw_line(a, b, Color(1, 1, 1, 0.5), 1.0)


## Kansilehti ja sisällys (sivu 0). Sisällyksen rivi vie kohdesivulle.
func _title_page(pg: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var x0 := pg.position.x + 34
	var tw := pg.size.x - 68
	_compass(Vector2(pg.end.x - 70, pg.position.y + 70), 36.0)
	draw_string(font, Vector2(x0, pg.position.y + 62), "Retkiä Saloisista", HORIZONTAL_ALIGNMENT_LEFT, tw - 80, 28, RED)
	# kaksi riviä: yhdelle riville kompassin vasemmalle puolelle ei mahdu
	draw_string(_hand, Vector2(x0, pg.position.y + 90), "Taksikuskin oma kappale.", HORIZONTAL_ALIGNMENT_LEFT, tw - 80, 16,
		Color(0.4, 0.35, 0.3))
	draw_string(_hand, Vector2(x0, pg.position.y + 110), "Hinnat meno-paluu.", HORIZONTAL_ALIGNMENT_LEFT, tw - 80, 16,
		Color(0.4, 0.35, 0.3))
	var seen := _pages.filter(func(p): return p.kayty).size()
	draw_string(font, Vector2(x0, pg.position.y + 134), "Sisällys", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	draw_string(_hand, Vector2(x0, pg.position.y + 134), "käyty %d / %d" % [seen, _pages.size()], HORIZONTAL_ALIGNMENT_RIGHT, tw, 16, STAMP)
	draw_line(Vector2(x0, pg.position.y + 144), Vector2(x0 + tw, pg.position.y + 144), Color(0.55, 0.15, 0.1, 0.6), 1.5)
	var lh := minf(26.0, (pg.end.y - 44 - (pg.position.y + 152)) / maxf(_pages.size(), 1))
	var fs := int(clampf(lh * 0.62, 11.0, 16.0))
	for i in _pages.size():
		var p: Dictionary = _pages[i]
		var y := pg.position.y + 152 + i * lh
		var r := Rect2(Vector2(x0 - 4, y), Vector2(tw + 8, lh))
		var nfs := fs
		while nfs > 11 and font.get_string_size(_short(p.nimi), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > tw - 60:
			nfs -= 1  # pitkä nimi pienemmällä, ettei mene sivunumeron päälle
		draw_string(font, Vector2(x0, y + lh * 0.72), _short(p.nimi), HORIZONTAL_ALIGNMENT_LEFT, tw - 60, nfs, INK)
		draw_string(font, Vector2(x0, y + lh * 0.72), str(i + 1), HORIZONTAL_ALIGNMENT_RIGHT, tw, fs, Color(0.4, 0.35, 0.3))
		if p.kayty:
			_check(Vector2(x0 + tw - 38, y + lh * 0.5), STAMP)
		draw_line(Vector2(x0, y + lh - 1), Vector2(x0 + tw, y + lh - 1), Color(0.6, 0.55, 0.45, 0.25), 1.0)
		_toc.append([r, i + 1])


## Taksivalikon nimi on suuntamuodossa ("Kuhmon karhukätköön"); sisällyksessä se mahtuu riville, pitkä katkaistaan.
func _short(nimi: String) -> String:
	return nimi if nimi.length() <= 44 else nimi.left(42) + "…"


func _end_page(pg: Rect2) -> void:
	draw_string(_hand, Vector2(pg.position.x + 34, pg.position.y + 90), "Muistiinpanoja", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.45, 0.4, 0.35))
	for y in range(int(pg.position.y) + 120, int(pg.end.y) - 50, 30):
		draw_line(Vector2(pg.position.x + 34, y), Vector2(pg.end.x - 34, y), Color(0.6, 0.6, 0.65, 0.3), 1.0)
	_compass(pg.get_center() + Vector2(0, 60), 50.0, 0.25)


## Kohdesivu: numero, nimi, faktarivit kuvakkein, kuvaus (tai ???), leima ja linkki taksitolpalle.
func _dest_page(pg: Rect2, p: Dictionary, n: int) -> void:
	var font := ThemeDB.fallback_font
	var x0 := pg.position.x + 34
	var tw := pg.size.x - 68
	# Yläreunan nauha kuin taskuoppaan luvun alussa.
	draw_rect(Rect2(pg.position + Vector2(0, 18), Vector2(pg.size.x, 30)), Color(0.62, 0.14, 0.12, 0.88))
	draw_rect(Rect2(pg.position + Vector2(0, 18), Vector2(pg.size.x, 3)), Color(1, 0.6, 0.55, 0.35))
	draw_string(font, Vector2(x0, pg.position.y + 40), "RETKIKOHDE %d / %d" % [n, _pages.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(1, 0.94, 0.85))
	var y := pg.position.y + 62
	var fs := 26
	var name_lines := _wrap(p.nimi, fs, tw, font)
	while name_lines.size() > 2 and fs > 18:
		fs -= 1
		name_lines = _wrap(p.nimi, fs, tw, font)
	if name_lines.size() > 2 and not p.id in overflow:
		overflow.append(p.id)
	for l in name_lines:
		y += fs + 8
		draw_string(font, Vector2(x0, y), l, HORIZONTAL_ALIGNMENT_LEFT, tw, fs, Color(0.2, 0.12, 0.08))
	y += 16
	var facts := [["taksi", LAHTO.get(p.lahto, String(p.lahto))], ["kello", "%d min suuntaansa" % int(p.hop_min)],
		["kolikko", "%s € meno-paluu" % _eur(p.hinta)]]
	if Retket.LISTA.has(String(p.id)):
		var vo: Dictionary = Retket.tarjous(String(p.id), true)
		facts.append(["taksi", "Vaalasta: %d min, %s € meno-paluu" % [int(vo.hop_min), _eur(vo.hinta)]])
	for f in facts:
		_icon(f[0], Vector2(x0 + 11, y + 10))
		draw_string(font, Vector2(x0 + 30, y + 16), f[1], HORIZONTAL_ALIGNMENT_LEFT, tw - 30, 17, INK)
		y += 28
	y += 6
	draw_line(Vector2(x0, y), Vector2(x0 + tw, y), Color(0.55, 0.15, 0.1, 0.5), 1.5)
	y += 10
	if p.tiedossa:
		for l in _wrap(p.kuvaus, 18, tw, _hand):
			if y + 28 > pg.end.y - 120:
				if not p.id in overflow:
					overflow.append(p.id)
				break
			y += 28
			draw_string(_hand, Vector2(x0, y), l, HORIZONTAL_ALIGNMENT_LEFT, tw, 18, INK)
	else:
		draw_string(font, Vector2(x0, y + 52), "???", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.62, 0.58, 0.52))
		draw_string(_hand, Vector2(x0, y + 84), "Lisää tietoa, kun olet käynyt paikan päällä.", HORIZONTAL_ALIGNMENT_LEFT, tw, 15,
			Color(0.5, 0.46, 0.4))
	if p.kayty:
		_stamp(Vector2(pg.end.x - 96, pg.end.y - 96), p.id)
	if p.lahto == "taksi" and game != null and game.has_method("show_retki_on_map"):
		var lt := "→ taksitolppa kartalle"
		var lw := _hand.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var ly := pg.end.y - 44
		draw_string(_hand, Vector2(x0, ly), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, RED)
		draw_line(Vector2(x0, ly + 4), Vector2(x0 + lw, ly + 4), Color(0.6, 0.18, 0.12, 0.6), 1.0)
		_links.append([Rect2(Vector2(x0 - 4, ly - 20), Vector2(lw + 8, 28)), p.id])


func _eur(v: float) -> String:
	return game._eur(v) if game != null else "%.2f" % v


## Pienet piirretyt kuvakkeet faktariville (taksi, kello, kolikko), keskipiste c, noin 20 px.
func _icon(kind: String, c: Vector2) -> void:
	var dark := Color(0.15, 0.12, 0.1)
	match kind:
		"taksi":
			MG.box(self, Rect2(c + Vector2(-6, -8), Vector2(12, 6)), Color(0.95, 0.78, 0.15), 2, 0, dark, 1)
			MG.box(self, Rect2(c + Vector2(-10, -3), Vector2(20, 8)), Color(0.98, 0.82, 0.2), 3, 0, dark, 1)
			draw_rect(Rect2(c + Vector2(-3, -11), Vector2(6, 3)), dark)
			draw_rect(Rect2(c + Vector2(-4, -7), Vector2(3, 3)), Color(0.6, 0.8, 0.95))
			draw_rect(Rect2(c + Vector2(1, -7), Vector2(3, 3)), Color(0.6, 0.8, 0.95))
			for wx in [-6.0, 6.0]:
				draw_circle(c + Vector2(wx, 6), 3.2, dark)
				draw_circle(c + Vector2(wx, 6), 1.2, Color(0.7, 0.7, 0.72))
		"kello":
			draw_circle(c, 9.0, dark)
			draw_circle(c, 7.6, Color(0.98, 0.97, 0.92))
			draw_arc(c, 7.6, PI * 0.9, PI * 1.6, 8, Color(1, 1, 1), 1.5)
			for k in 4:
				draw_circle(c + Vector2.from_angle(k * PI / 2) * 6.0, 0.8, dark)
			draw_line(c, c + Vector2(0, -5.5), dark, 1.6)
			draw_line(c, c + Vector2(4, 1), dark, 1.6)
		"kolikko":
			draw_circle(c + Vector2(1, 1), 9.0, Color(0, 0, 0, 0.25))
			draw_circle(c, 9.0, Color(0.6, 0.45, 0.1))
			draw_circle(c, 7.4, Color(0.95, 0.78, 0.25))
			draw_arc(c, 5.5, PI * 1.05, PI * 1.55, 6, Color(1, 0.97, 0.7), 1.5)
			draw_string(ThemeDB.fallback_font, c + Vector2(-5, 4.5), "€", HORIZONTAL_ALIGNMENT_CENTER, 10, 12, Color(0.5, 0.35, 0.05))


## Pyöreä kumileima "KÄYTY": vino, kaksi rengasta, muste epätasainen (katkoja, ohuempia kohtia ja täpliä kiinteästä siemenestä).
func _stamp(c: Vector2, id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var rot := rng.randf_range(-0.38, -0.12)
	draw_set_transform(c, rot)
	var r := 58.0
	for ring in [[r, 4.5], [r - 9.0, 2.0]]:
		var seg := 36
		for k in seg:
			if rng.randf() < 0.08:
				continue  # muste ei tarttunut
			var a0 := k * TAU / seg
			draw_arc(Vector2.ZERO, ring[0], a0, a0 + TAU / seg + 0.01, 4, Color(STAMP, rng.randf_range(0.55, 0.85)), ring[1] * rng.randf_range(0.7, 1.15))
	# Tähdet renkaiden välissä ja vaakaviivat tekstin ympärillä.
	for a in [PI, 0.0]:
		_star_small(Vector2.from_angle(a) * (r - 22.0), 5.0, Color(STAMP, 0.75))
	draw_line(Vector2(-34, -16), Vector2(34, -16), Color(STAMP, 0.7), 2.0)
	draw_line(Vector2(-34, 15), Vector2(34, 15), Color(STAMP, 0.7), 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-r, 9), "KÄYTY", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 24, Color(STAMP, 0.82))
	draw_string(font, Vector2(-r, -24), "MATKAOPAS", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 9, Color(STAMP, 0.7))
	draw_string(font, Vector2(-r, 31), "SALOINEN", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 9, Color(STAMP, 0.7))
	# Kulunut kumi: paperinvärisiä pilkkuja musteen päällä ja muutama roiske reunan yli.
	for k in 26:
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, r)
		draw_circle(p, rng.randf_range(0.6, 1.8), Color(PAPER, 0.75))
	for k in 5:
		draw_circle(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(r + 2.0, r + 7.0), rng.randf_range(0.6, 1.5), Color(STAMP, 0.4))
	draw_set_transform(Vector2.ZERO)


## Kompassiruusu kansilehdelle: neljä kärkeä vuorotellen tumma ja vaalea puolisko, rengas ja N.
func _compass(c: Vector2, r: float, alpha := 1.0) -> void:
	draw_arc(c, r * 0.72, 0, TAU, 32, Color(0.55, 0.15, 0.1, 0.6 * alpha), 1.5)
	for k in 8:
		var a := k * PI / 4.0 - PI / 2.0
		var ln := r if k % 2 == 0 else r * 0.55
		var tip := c + Vector2.from_angle(a) * ln
		var l := c + Vector2.from_angle(a - PI / 2.0) * r * 0.14
		var rr := c + Vector2.from_angle(a + PI / 2.0) * r * 0.14
		draw_colored_polygon(PackedVector2Array([c, l, tip]), Color(0.85, 0.7, 0.3, alpha) if k % 2 == 0 else Color(0.7, 0.6, 0.45, alpha))
		draw_colored_polygon(PackedVector2Array([c, tip, rr]), Color(0.55, 0.15, 0.1, alpha) if k % 2 == 0 else Color(0.45, 0.38, 0.3, alpha))
	draw_circle(c, r * 0.1, Color(0.3, 0.1, 0.05, alpha))
	draw_string(ThemeDB.fallback_font, c + Vector2(-10, -r - 4), "N", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.4, 0.1, 0.05, alpha))


func _check(c: Vector2, col: Color) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-2, 5), c + Vector2(7, -6)]), col, 2.5, true)


func _star_small(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


func _wrap(text: String, size: int, width: float, font: Font) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in text.split(" "):
		var t := word if cur == "" else cur + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out
