extends Control
## Normipäiväkirja (#132, näppäin O): nahkakantinen vihko kolmella välilehdellä.
## "Tarina": luvut sitä mukaa kuin niihin päästään ja vaiheet sitä mukaa kuin niistä kuullaan (quests.gd).
## "Tehtävät": sivutehtävät, kun niistä on kuultu; tehdyt leimataan.
## "Loput": onnellisten loppujen kokoelma (endings.gd): erilaiset X / Y (löytämättömät ???) ja yhteismäärä.
## Mikään ei paljastu etukäteen. Peli on tauolla auki ollessa. Hiiri: välilehdet ja rulla, näppäimet 1–3, Esc / O sulkee.

const MG := preload("res://scripts/mg_draw.gd")
const PAPER := Color(0.97, 0.94, 0.85)
const LINE := Color(0.62, 0.72, 0.85, 0.55)
const MARGIN := Color(0.85, 0.35, 0.35, 0.6)
const INK := Color(0.14, 0.17, 0.4)
const LEATHER := Color(0.36, 0.2, 0.12)
const TABS := [["tarina", "Tarina", Color(0.85, 0.35, 0.25)], ["tehtavat", "Tehtävät", Color(0.25, 0.55, 0.75)],
	["loput", "Loput", Color(0.9, 0.7, 0.15)]]

var game: Node

var _tab := "tarina"
var _data := {}
var _book := Rect2()
var _scroll := 0.0
var _hand: SystemFont
var _hover_tab := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hand = SystemFont.new()
	_hand.font_names = PackedStringArray(["Bradley Hand", "Segoe Print", "Comic Sans MS", "Chalkboard SE", "Marker Felt",
		"Noteworthy", "sans-serif"])


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		size = get_viewport_rect().size
		_data = game.journal_data() if game != null else {}
		_scroll = 0.0
		Sfx.play("cloth", -8.0, 0.9)
	queue_redraw()


func _process(_d: float) -> void:
	if Input.is_action_just_pressed("journal") or (visible and Input.is_key_pressed(KEY_ESCAPE)):
		if visible or not get_tree().paused:
			toggle()
	if not visible:
		return
	for i in TABS.size():
		if Input.is_key_pressed(KEY_1 + i) and _tab != TABS[i][0]:
			_set_tab(TABS[i][0])
	var h := -1
	for i in TABS.size():
		if _tab_rect(i).has_point(get_local_mouse_position()):
			h = i
	if h != _hover_tab:
		_hover_tab = h
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				for i in TABS.size():
					if _tab_rect(i).has_point(event.position):
						_set_tab(TABS[i][0])
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll += 40.0
				queue_redraw()
			MOUSE_BUTTON_WHEEL_UP:
				_scroll = maxf(0.0, _scroll - 40.0)
				queue_redraw()
		accept_event()


func _set_tab(t: String) -> void:
	_tab = t
	_scroll = 0.0
	Sfx.play("cloth", -12.0, 1.4)
	queue_redraw()


func _tab_rect(i: int) -> Rect2:
	return Rect2(Vector2(_book.end.x - 6, _book.position.y + 40 + i * 92), Vector2(54, 84))


func _page(right: bool) -> Rect2:
	var half := (_book.size.x - 40) / 2.0
	return Rect2(_book.position + Vector2(20 + (half if right else 0.0), 18), Vector2(half, _book.size.y - 36))


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	var w := minf(1080.0, size.x - 80.0)
	var h := minf(660.0, size.y - 120.0)
	_book = Rect2((size - Vector2(w, h)) / 2.0, Vector2(w, h))
	# Kansi, sivut ja kierrerengas.
	MG.box(self, _book.grow(14), LEATHER, 18, 16)
	MG.box(self, _book.grow(6), LEATHER.darkened(0.25), 14)
	draw_arc(_book.position + Vector2(_book.size.x - 60, _book.size.y - 4), 30.0, PI * 1.1, PI * 1.9, 24, Color(0.15, 0.08, 0.04, 0.5), 3.0)
	for side in [false, true]:
		var pg := _page(side)
		MG.box(self, pg, PAPER, 6)
		for y in range(int(pg.position.y) + 70, int(pg.end.y) - 10, 30):
			draw_line(Vector2(pg.position.x + 10, y), Vector2(pg.end.x - 10, y), LINE, 1.0)
		draw_line(Vector2(pg.position.x + 46, pg.position.y + 6), Vector2(pg.position.x + 46, pg.end.y - 6), MARGIN, 1.5)
		_stains(pg, 7 if side else 3)
	var mid := _book.position.x + _book.size.x / 2.0
	for y in range(int(_book.position.y) + 30, int(_book.end.y) - 20, 34):
		MG.ball(self, Vector2(mid, y), 8.0, Color(0.7, 0.7, 0.74), 0.6)
	# Välilehdet oikeassa reunassa.
	for i in TABS.size():
		var r := _tab_rect(i)
		var on: bool = TABS[i][0] == _tab
		var col: Color = TABS[i][2]
		MG.box(self, r.grow(2.0 if on or i == _hover_tab else 0.0), col if on else col.darkened(0.25), 8, 4)
		draw_set_transform(r.get_center(), PI / 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-40, 6), str(TABS[i][1]).left(9), HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	# Otsikkokyltti kannessa.
	MG.sign(self, Rect2(Vector2(_book.get_center().x - 170, _book.position.y - 34), Vector2(340, 40)), "NORMIPÄIVÄKIRJA",
		Color(0.92, 0.85, 0.65), Color(0.35, 0.18, 0.08), 22, Color(0.55, 0.4, 0.2))
	match _tab:
		"tarina":
			_draw_story()
		"tehtavat":
			_draw_side()
		"loput":
			_draw_endings()
	draw_string(ThemeDB.fallback_font, Vector2(0, _book.end.y + 32), "1–3 välilehdet · rulla selaa · %s / Esc sulje" % Settings.cap("journal"),
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(0.85, 0.85, 0.85))


## Kirjoittaa rivejä sivuille: vasen sivu ensin, sitten oikea. Palauttaa false, kun tila loppui.
class Writer:
	var j: Control
	var pages: Array
	var pi := 0
	var y := 0.0
	var skip := 0.0

	func _init(journal: Control, p: Array, scroll: float) -> void:
		j = journal
		pages = p
		y = pages[0].position.y + 52
		skip = scroll

	func line(text: String, size: int, col: Color, indent := 0.0, lh := 30.0, font: Font = null) -> bool:
		if skip >= lh:
			skip -= lh
			return true
		while pi < pages.size() and y + lh > pages[pi].end.y - 8:
			pi += 1
			if pi < pages.size():
				y = pages[pi].position.y + 52
		if pi >= pages.size():
			return false
		var pg: Rect2 = pages[pi]
		var f: Font = font if font != null else ThemeDB.fallback_font
		j.draw_string(f, Vector2(pg.position.x + 54 + indent, y + lh - 9), text, HORIZONTAL_ALIGNMENT_LEFT,
			pg.size.x - 70 - indent, size, col)
		y += lh
		return true


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


func _draw_story() -> void:
	var wr := Writer.new(self, [_page(false), _page(true)], _scroll)
	var width := _page(false).size.x - 90
	for ch in _data.get("chapters", []):
		if not wr.line(ch.title + ("  ✔" if ch.done else ""), 22, Color(0.45, 0.12, 0.08), 0.0, 36.0):
			return
		for row in ch.rows:
			var lines := _wrap(String(row[0]), 19, width - 30, _hand)
			for k in lines.size():
				var mark := ("✔ " if row[1] else "• ") if k == 0 else "   "
				if not wr.line(mark + lines[k], 19, Color(0.2, 0.45, 0.2) if row[1] else INK, 16.0, 30.0, _hand):
					return
		wr.line("", 10, INK, 0.0, 12.0)
	if _data.get("more", false):
		wr.line("Tarina jatkuu…", 20, Color(0.5, 0.4, 0.3), 0.0, 34.0, _hand)
	elif _data.get("chapters", []).size() > 0:
		wr.line("…mitähän seuraavaksi?", 18, Color(0.5, 0.45, 0.4), 16.0, 34.0, _hand)


func _draw_side() -> void:
	var wr := Writer.new(self, [_page(false), _page(true)], _scroll)
	var width := _page(false).size.x - 90
	var side: Array = _data.get("side", [])
	if side.is_empty():
		wr.line("Ei vielä mitään. Kuuntele, mitä kylällä puhutaan.", 18, INK, 0.0, 30.0, _hand)
		return
	var done := side.filter(func(q): return q.done).size()
	wr.line("Tiedossa %d tehtävää · tehty %d" % [side.size(), done], 18, Color(0.45, 0.12, 0.08), 0.0, 34.0)
	var open := side.filter(func(q): return not q.done)
	var finished := side.filter(func(q): return q.done)
	for q in open + finished:
		var title: String = q.title + ("  ✔ tehty" if q.done else "") + ("  (%s)" % q.progress if q.progress != "" else "")
		if not wr.line(title, 20, Color(0.2, 0.45, 0.2) if q.done else Color(0.45, 0.12, 0.08), 0.0, 32.0):
			return
		for l in _wrap(String(q.text), 17, width - 20, _hand):
			if not wr.line(l, 17, INK, 14.0, 26.0, _hand):
				return
		wr.line("", 10, INK, 0.0, 10.0)


func _draw_endings() -> void:
	var e: Dictionary = _data.get("endings", {})
	var lp := _page(false)
	var font := ThemeDB.fallback_font
	var x0 := lp.position.x + 54
	draw_string(font, Vector2(x0, lp.position.y + 70), "Erilaisia onnellisia loppuja", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.45, 0.12, 0.08))
	draw_string(font, Vector2(x0, lp.position.y + 130), "%d / %d" % [e.get("distinct", 0), e.get("max", 0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 54,
		Color(0.85, 0.55, 0.05))
	# Edistymispalkki tähtinä.
	var mx: int = max(1, e.get("max", 1))
	for i in mx:
		var c := Vector2(x0 + 12 + (i % 7) * 46, lp.position.y + 170 + (i / 7) * 44)
		var got: bool = i < e.get("distinct", 0)
		_star(c, 16.0, Color(1.0, 0.8, 0.15) if got else Color(0.8, 0.78, 0.72))
	draw_string(font, Vector2(x0, lp.position.y + 300), "Onnellisia loppuja yhteensä", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.45, 0.12, 0.08))
	draw_string(font, Vector2(x0, lp.position.y + 356), str(e.get("total", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(0.2, 0.45, 0.2))
	var note := "Jokainen erilainen onnellinen loppu on uusi tähti. Mitä kaikkea normipäivästä voikaan tulla?"
	var y := lp.position.y + 410
	for l in _wrap(note, 18, lp.size.x - 90, _hand):
		draw_string(_hand, Vector2(x0, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
		y += 28
	# Oikea sivu: kortit (löydetyt nimellä, muut ???).
	var rp := _page(true)
	var list: Array = e.get("list", [])
	var cw := (rp.size.x - 80) / 2.0
	var chh := 78.0
	for i in list.size():
		var r := Rect2(rp.position + Vector2(52 + (i % 2) * (cw + 10), 30 + (i / 2) * (chh + 8) - _scroll), Vector2(cw, chh))
		if r.end.y > rp.end.y - 6 or r.position.y < rp.position.y:
			continue
		var it = list[i]
		if it == null:
			MG.box(self, r, Color(0.86, 0.84, 0.78), 8, 0, Color(0.7, 0.68, 0.62), 2)
			draw_string(font, r.position + Vector2(0, 46), "???", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, Color(0.6, 0.58, 0.52))
		else:
			MG.box(self, r, Color(1.0, 0.95, 0.75), 8, 3, Color(0.85, 0.6, 0.1), 2)
			_star(r.position + Vector2(18, 20), 10.0, Color(1.0, 0.8, 0.15))
			var fs := 16
			while fs > 11 and font.get_string_size(it.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 40:
				fs -= 1  # pitkä nimi pienemmällä, ettei katkea
			draw_string(font, r.position + Vector2(34, 26), it.name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, fs, Color(0.35, 0.15, 0.05))
			draw_string(_hand, r.position + Vector2(12, 50), "× %d" % it.count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.2, 0.45, 0.2))
			draw_string(_hand, r.position + Vector2(70, 50), ("ekan kerran päivänä %d" % it.day) if it.day > 0 else "", HORIZONTAL_ALIGNMENT_LEFT,
				r.size.x - 76, 14, Color(0.45, 0.4, 0.35))
			draw_string(_hand, r.position + Vector2(12, 68), it.desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 12, INK)


## Tahrat pelin tapaan: kahvikupin renkaat, oluttahrat roiskeineen, makkaran rasvatäplä ja sinappi. Paikat
## kiinteästä siemenestä, jotta tahrat pysyvät paikallaan; piirretään tekstin alle, ettei luettavuus kärsi.
func _stains(pg: Rect2, seed_i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var at := func(fx: float, fy: float) -> Vector2:
		return pg.position + Vector2(pg.size.x * fx, pg.size.y * fy)
	# Kahvikupin rengas: epätasainen ruskea kehä, sisältä vaaleampi, yksi valuma.
	for k in 2 if seed_i == 3 else 1:
		var c: Vector2 = at.call(rng.randf_range(0.55, 0.85), rng.randf_range(0.15, 0.75))
		var r := rng.randf_range(38.0, 50.0)
		draw_circle(c, r, Color(0.55, 0.35, 0.15, 0.06))
		for ring in 3:
			var a0 := rng.randf() * TAU
			draw_arc(c, r - ring * 1.8, a0, a0 + TAU * rng.randf_range(0.7, 1.0), 48,
				Color(0.45, 0.27, 0.1, 0.28 - ring * 0.07), 3.0 - ring * 0.6, true)
		var drip := c + Vector2(cos(1.1), sin(1.1)) * r
		draw_line(drip, drip + Vector2(rng.randf_range(-4, 4), rng.randf_range(10, 22)), Color(0.45, 0.27, 0.1, 0.22), 3.0)
	# Oluttahra: kellertävä läikkä tummemmin reunoin ja pieniä roiskeita.
	var bc: Vector2 = at.call(rng.randf_range(0.2, 0.5), rng.randf_range(0.55, 0.85))
	var blob := PackedVector2Array()
	var radii: Array = []
	for k in 18:
		radii.append(rng.randf_range(26.0, 44.0))
	for k in 18:
		var a := k * TAU / 18.0
		blob.append(bc + Vector2(cos(a), sin(a) * 0.75) * radii[k])
	draw_colored_polygon(blob, Color(0.85, 0.62, 0.15, 0.13))
	blob.append(blob[0])
	draw_polyline(blob, Color(0.7, 0.45, 0.1, 0.25), 2.0, true)
	for k in 7:
		var a := rng.randf() * TAU
		draw_circle(bc + Vector2(cos(a), sin(a)) * rng.randf_range(50.0, 85.0), rng.randf_range(2.0, 5.0), Color(0.8, 0.55, 0.12, 0.2))
	# Makkaran rasvatäplä: läpikuultava tumma täplä paperissa.
	if seed_i == 7:
		var gc: Vector2 = at.call(0.3, 0.2)
		draw_circle(gc, 18.0, Color(0.6, 0.5, 0.3, 0.12))
		draw_circle(gc + Vector2(6, 4), 10.0, Color(0.55, 0.45, 0.25, 0.1))
	# Sinappiroiske sivun kulmassa.
	if seed_i == 3:
		var mc: Vector2 = at.call(0.88, 0.9)
		draw_circle(mc, 7.0, Color(0.85, 0.7, 0.1, 0.35))
		draw_line(mc, mc + Vector2(-18, -6), Color(0.85, 0.7, 0.1, 0.3), 3.0)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, col.darkened(0.4), 1.5)
