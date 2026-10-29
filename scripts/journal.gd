extends Control
## Normipäiväkirja (#132, näppäin O): nahkakantinen vihko neljällä välilehdellä.
## "Tarina": luvut sitä mukaa kuin niihin päästään ja vaiheet sitä mukaa kuin niistä kuullaan (quests.gd).
## "Tehtävät": sivutehtävät, kun niistä on kuultu; tehdyt leimataan.
## "Loput": onnelliset loput (päivä päättyy) vasemmalla ja legendaariset hetket (saavutukset) oikealla
## (endings.gd): erilaiset X / Y, löytämättömät ???.
## "Jemmat": löydetyt jemmapaikat, kaljat / tila ja riski, kotijemma tavoitteeseen nähden.
## "Reppu": viides välilehti, jonka sivut piirtää lapsi inventory.gd. R avaa vihkon reppusivulta, O päiväkirjan sivulta
## (viimeksi katsotulta); jo auki ollessa R / O vaihtaa sivua ja saman sivun näppäin sulkee. Vihko, tauko ja Esc ovat tässä.
## Mikään ei paljastu etukäteen. Peli on tauolla auki ollessa. Hiiri: välilehdet ja rulla, näppäimet 1–5, Esc / O sulkee.

const MG := preload("res://scripts/mg_draw.gd")
const INK := Color(0.14, 0.17, 0.4)
const TABS := [["tarina", "Tarina", Color(0.85, 0.35, 0.25)], ["tehtavat", "Tehtävät", Color(0.25, 0.55, 0.75)],
	["loput", "Loput", Color(0.9, 0.7, 0.15)], ["jemmat", "Jemmat", Color(0.3, 0.6, 0.3)],
	["reppu", "Reppu", Color(0.5, 0.3, 0.7)]]

var game: Node
var _links: Array = []  # [Rect2, tehtävän id] "Näytä kartalla" -linkit, piirretty tällä ruudulla

var _tab := "tarina"
var _last_tab := "tarina"  # viimeksi katsottu päiväkirjan (ei repun) sivu, jonka O avaa
var _data := {}
var _book := Rect2()
var _scroll := 0.0
var _hand: SystemFont
var _hover_tab := -1
var _keys: Control  # näppäinohjeet hattuina alareunassa (hint_bar.gd)


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


## Avaa vihkon valitulle välilehdelle (R: "reppu", O: viimeksi katsottu päiväkirjan sivu); pause pysyy päällä.
func open_at(tab: String) -> void:
	if not visible:
		toggle()
	_set_tab(tab)


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		size = get_viewport_rect().size
		_data = game.journal_data() if game != null else {}
		_scroll = 0.0
		Sfx.play("cloth", -8.0, 0.9)
	game._inventory.show_page(visible and _tab == "reppu")
	_update_keys()
	queue_redraw()


func _update_keys() -> void:
	if not visible:
		_keys.set_text("")
	elif _tab == "reppu":
		_keys.set_text("[Klikkaus] syö tai juo evästä (T)   [1–5] tai [←][→] välilehdet   %s päiväkirja   %s sulje"
			% [Settings.cap("journal"), Settings.cap("inventory", "Esc")])
	else:
		_keys.set_text("[1–5] tai [←][→] välilehdet   [Rulla] selaa   %s reppu   %s sulje"
			% [Settings.cap("inventory"), Settings.cap("journal", "Esc")])


func _process(_d: float) -> void:
	var open_ok := visible or not get_tree().paused
	if visible and Input.is_key_pressed(KEY_ESCAPE):
		toggle()
	elif Input.is_action_just_pressed("inventory") and open_ok:
		if visible and _tab == "reppu":
			toggle()
		else:
			open_at("reppu")
	elif Input.is_action_just_pressed("journal") and open_ok:
		if visible and _tab != "reppu":
			toggle()
		else:
			open_at(_last_tab)
	if not visible:
		return
	for i in TABS.size():
		if Input.is_key_pressed(KEY_1 + i) and _tab != TABS[i][0]:
			_set_tab(TABS[i][0])
			return
	var flip := int(Input.is_action_just_pressed("ui_right")) - int(Input.is_action_just_pressed("ui_left"))
	if flip != 0:
		var to := _tab_index() + flip
		if to >= 0 and to < TABS.size():
			_set_tab(TABS[to][0])
			return
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
						accept_event()
						return
				if _tab == "reppu":
					game._inventory._gui_input(event)
				if _tab == "tehtavat":
					for l in _links:
						if (l[0] as Rect2).has_point(event.position):
							Sfx.play("pickup", -10.0, 1.3)
							game.show_quest_on_map(l[1])
							break
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll += 40.0
				queue_redraw()
			MOUSE_BUTTON_WHEEL_UP:
				_scroll = maxf(0.0, _scroll - 40.0)
				queue_redraw()
		accept_event()


func _tab_index() -> int:
	for i in TABS.size():
		if TABS[i][0] == _tab:
			return i
	return 0


func _set_tab(t: String) -> void:
	_tab = t
	if t != "reppu":
		_last_tab = t
	game._inventory.show_page(visible and t == "reppu")
	_update_keys()
	_scroll = 0.0
	Sfx.play("cloth", -12.0, 1.4)
	queue_redraw()


func _tab_rect(i: int) -> Rect2:
	return MG.notebook_tab_rect(_book, i)


func _page(right: bool) -> Rect2:
	return MG.notebook_page(_book, right)


func _draw() -> void:
	if not visible:
		return
	_book = MG.notebook_rect(size)
	MG.notebook(self, _book)
	# Välilehdet oikeassa reunassa.
	for i in TABS.size():
		MG.notebook_tab(self, _tab_rect(i), TABS[i][2], str(TABS[i][1]), TABS[i][0] == _tab, i == _hover_tab)
	# Otsikkokyltti kannessa.
	if _tab == "reppu":
		MG.sign(self, MG.notebook_title_rect(_book, 240.0), "REPPU", MG.TITLE_BG, MG.TITLE_FG, 22, MG.TITLE_BORDER)
	else:
		MG.sign(self, MG.notebook_title_rect(_book), "NORMIPÄIVÄKIRJA", MG.TITLE_BG, MG.TITLE_FG, 22, MG.TITLE_BORDER)
	match _tab:
		"tarina":
			_draw_story()
		"tehtavat":
			_draw_side()
		"loput":
			_draw_endings()
		"jemmat":
			_draw_stashes()


## Kirjoittaa rivejä sivuille: vasen sivu ensin, sitten oikea. Palauttaa false, kun tila loppui.
class Writer:
	var j: Control
	var pages: Array
	var pi := 0
	var y := 0.0
	var skip := 0.0
	var last := Rect2()  # viimeksi piirretyn rivin alue (tyhjä, jos rivi jäi vierityksen alle)

	func _init(journal: Control, p: Array, scroll: float) -> void:
		j = journal
		pages = p
		y = pages[0].position.y + 52
		skip = scroll

	func line(text: String, size: int, col: Color, indent := 0.0, lh := 30.0, font: Font = null) -> bool:
		last = Rect2()
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
		last = Rect2(Vector2(pg.position.x + 54 + indent, y), Vector2(pg.size.x - 70 - indent, lh))
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
			var day_note := ("  (päivä %d)" % row[2]) if row.size() > 2 and row[2] > 0 else ""
			var lines := _wrap(String(row[0]) + day_note, 19, width - 30, _hand)
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
	_links.clear()
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
		var title: String = q.title + ((("  ✔ tehty päivänä %d" % q.done_day) if q.done_day > 0 else "  ✔ tehty") if q.done else "") + ("  (%s)" % q.progress if q.progress != "" else "")
		if not wr.line(title, 20, Color(0.2, 0.45, 0.2) if q.done else Color(0.45, 0.12, 0.08), 0.0, 32.0):
			return
		for l in _wrap(String(q.text), 17, width - 20, _hand):
			if not wr.line(l, 17, INK, 14.0, 26.0, _hand):
				return
		if q.get("spot", false):
			# Lyijykynällä tekstin alle: klikkaus asettaa kompassin (main.gd show_quest_on_map).
			if not wr.line("", 16, INK, 14.0, 26.0):
				return
			if wr.last.size.x > 0.0:
				var lt := "→ näytä kartalla"
				var lw := _hand.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				var lr := Rect2(wr.last.position + Vector2(-4, 2), Vector2(lw + 8, wr.last.size.y - 2))
				draw_string(_hand, Vector2(wr.last.position.x, wr.last.end.y - 8), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.18, 0.12))
				draw_line(Vector2(wr.last.position.x, wr.last.end.y - 5), Vector2(wr.last.position.x + lw, wr.last.end.y - 5), Color(0.6, 0.18, 0.12, 0.6), 1.0)
				_links.append([lr, q.id])
		wr.line("", 10, INK, 0.0, 10.0)


func _draw_endings() -> void:
	var font := ThemeDB.fallback_font
	var red := Color(0.45, 0.12, 0.08)
	# Vasen sivu: onnelliset loput (päivä päättyy loppukohtaukseen), isot kortit allekkain.
	var lo: Dictionary = _data.get("loput", {})
	var lp := _page(false)
	var x0 := lp.position.x + 54
	draw_string(font, Vector2(x0, lp.position.y + 70), "Onnelliset loput", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, red)
	draw_string(font, Vector2(x0, lp.position.y + 124), "%d / %d" % [lo.get("distinct", 0), lo.get("max", 0)], HORIZONTAL_ALIGNMENT_LEFT,
		-1, 48, Color(0.85, 0.55, 0.05))
	draw_string(_hand, Vector2(x0 + 140, lp.position.y + 118), "kertaa yhteensä %d" % lo.get("total", 0), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 20, Color(0.2, 0.45, 0.2))
	var cw := lp.size.x - 100
	var list: Array = lo.get("list", [])
	var ch := minf(76.0, (lp.end.y - 16 - (lp.position.y + 142)) / maxf(list.size(), 1) - 8)
	for i in list.size():
		_ending_card(Rect2(Vector2(x0 - 4, lp.position.y + 142 + i * (ch + 8)), Vector2(cw, ch)), list[i])
	# Oikea sivu: legendaariset hetket (saavutukset, peli jatkuu), tähtirivi ja kortit kahdessa sarakkeessa.
	var he: Dictionary = _data.get("hetket", {})
	var rp := _page(true)
	var rx := rp.position.x + 54
	draw_string(font, Vector2(rx, rp.position.y + 70 - _scroll), "Legendaariset hetket  %d / %d" % [he.get("distinct", 0), he.get("max", 0)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, red)
	var mx: int = he.get("max", 0)
	for i in mx:
		var c := Vector2(rx + 10 + (i % 10) * 30, rp.position.y + 92 + (i / 10) * 28 - _scroll)
		if c.y > rp.position.y + 10:
			_star(c, 10.0, Color(1.0, 0.8, 0.15) if i < he.get("distinct", 0) else Color(0.8, 0.78, 0.72))
	var hl: Array = he.get("list", [])
	var hw := (rp.size.x - 80) / 2.0
	var top := rp.position.y + 150 - _scroll
	for i in hl.size():
		var r := Rect2(Vector2(rp.position.x + 52 + (i % 2) * (hw + 10), top + (i / 2) * 86), Vector2(hw, 78))
		if r.end.y > rp.end.y - 6 or r.position.y < rp.position.y:
			continue
		_ending_card(r, hl[i])


## Loppu- tai hetkikortti: löydetty nimellä, kerroilla, päivällä ja kuvauksella; löytämätön ???.
func _ending_card(r: Rect2, it) -> void:
	var font := ThemeDB.fallback_font
	if it == null:
		MG.box(self, r, Color(0.86, 0.84, 0.78), 8, 0, Color(0.7, 0.68, 0.62), 2)
		draw_string(font, r.position + Vector2(0, r.size.y * 0.6), "???", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, Color(0.6, 0.58, 0.52))
		return
	MG.box(self, r, Color(1.0, 0.95, 0.75), 8, 3, Color(0.85, 0.6, 0.1), 2)
	if r.size.y < 62.0:
		# Matala kortti (monta onnellista loppua sivulla): tähti, nimi ja kerrat yhdellä rivillä, kuvaus vain kun mahtuu.
		var cy := r.position.y + minf(r.size.y * 0.5, 20.0)
		_star(Vector2(r.position.x + 16, cy), 8.0, Color(1.0, 0.8, 0.15))
		var cfs := 15
		while cfs > 11 and font.get_string_size(it.name, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x > r.size.x - 90:
			cfs -= 1
		draw_string(font, Vector2(r.position.x + 30, cy + 5), it.name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 90, cfs, Color(0.35, 0.15, 0.05))
		draw_string(_hand, Vector2(r.end.x - 52, cy + 5), "× %d" % it.count, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.2, 0.45, 0.2))
		if r.size.y >= 44.0:
			draw_string(_hand, Vector2(r.position.x + 12, cy + 22), it.desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 11, INK)
		return
	_star(r.position + Vector2(18, 20), 10.0, Color(1.0, 0.8, 0.15))
	var fs := 16
	while fs > 11 and font.get_string_size(it.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 40:
		fs -= 1  # pitkä nimi pienemmällä, ettei katkea
	draw_string(font, r.position + Vector2(34, 26), it.name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, fs, Color(0.35, 0.15, 0.05))
	draw_string(_hand, r.position + Vector2(12, 50), "× %d" % it.count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.2, 0.45, 0.2))
	draw_string(_hand, r.position + Vector2(70, 50), ("ekan kerran päivänä %d" % it.day) if it.day > 0 else "", HORIZONTAL_ALIGNMENT_LEFT,
		r.size.x - 76, 14, Color(0.45, 0.4, 0.35))
	draw_string(_hand, r.position + Vector2(12, 68), it.desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 12, INK)


## Jemmat: kotijemma tavoitteeseen nähden, ulkojemmat ja yhteensä vasemmalla, löydetyt jemmapaikat palkkeineen
## oikealla (kalja / tila ja riski: Päivi kotijemmoissa, teinit ulkojemmoissa).
func _draw_stashes() -> void:
	var s: Dictionary = _data.get("stashes", {})
	var lp := _page(false)
	var font := ThemeDB.fallback_font
	var x0 := lp.position.x + 54
	var red := Color(0.45, 0.12, 0.08)
	draw_string(font, Vector2(x0, lp.position.y + 70), "Kotijemma", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, red)
	var home: int = s.get("home", 0)
	var goal: int = s.get("goal", 24)
	draw_string(font, Vector2(x0, lp.position.y + 128), "%d / %d" % [home, goal], HORIZONTAL_ALIGNMENT_LEFT, -1, 50,
		Color(0.2, 0.45, 0.2) if home >= goal else Color(0.85, 0.55, 0.05))
	for i in goal:  # tölkkirivi: täynnä = kalja
		var c := Vector2(x0 + 6 + (i % 12) * 26, lp.position.y + 152 + (i / 12) * 40)
		var got := i < home
		MG.box(self, Rect2(c, Vector2(18, 32)), Color(0.85, 0.7, 0.15) if got else Color(0.85, 0.83, 0.78), 5, 0,
			Color(0.55, 0.4, 0.1) if got else Color(0.7, 0.68, 0.62), 1)
		if got:
			draw_rect(Rect2(c + Vector2(2, 9), Vector2(14, 8)), Color(0.15, 0.3, 0.6))
	var y := lp.position.y + 262
	draw_string(font, Vector2(x0, y), "Ulkojemmoissa %d" % s.get("out", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, red)
	y += 34
	draw_string(font, Vector2(x0, y), "Jemmoissa yhteensä %d kaljaa" % (home + int(s.get("out", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, red)
	y += 34
	draw_string(_hand, Vector2(x0, y), "Jemmapaikkoja löydetty %d / %d" % [s.get("found", 0), s.get("all", 0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, INK)
	y += 40
	for l in s.get("extra", []):
		draw_string(_hand, Vector2(x0, y), "• " + str(l), HORIZONTAL_ALIGNMENT_LEFT, lp.size.x - 90, 18, INK)
		y += 30
	var note := "Kotijemma täyteen, niin kaverit tulee juhlimaan. Liian täysi kaappi on kuitenkin riski: Päivi siivoaa."
	for l in _wrap(note, 16, lp.size.x - 90, _hand):
		if y > lp.end.y - 20:
			break
		draw_string(_hand, Vector2(x0, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.35, 0.3))
		y += 24
	# Oikea sivu: jemmapaikat.
	var rp := _page(true)
	var rows: Array = s.get("rows", [])
	if rows.is_empty():
		draw_string(_hand, rp.position + Vector2(54, 80), "Ei vielä yhtään jemmaa. Piilota kalja jonnekin!", HORIZONTAL_ALIGNMENT_LEFT,
			rp.size.x - 80, 18, INK)
		return
	var ry := rp.position.y + 40 - _scroll
	for r in rows:
		if ry > rp.end.y - 70:
			break
		if ry >= rp.position.y + 10:
			var title: String = str(r.name)
			draw_string(font, Vector2(rp.position.x + 54, ry + 20), title, HORIZONTAL_ALIGNMENT_LEFT, rp.size.x - 150, 18,
				red if r.home else Color(0.2, 0.35, 0.15))
			draw_string(font, Vector2(rp.position.x + 54, ry + 20), "%d / %d" % [r.n, r.cap], HORIZONTAL_ALIGNMENT_RIGHT, rp.size.x - 80, 18, INK)
			var bar := Rect2(Vector2(rp.position.x + 54, ry + 28), Vector2(rp.size.x - 80, 12))
			MG.box(self, bar, Color(0.85, 0.83, 0.78), 6)
			var f := clampf(float(r.n) / maxf(r.cap, 1.0), 0.0, 1.0)
			if f > 0.0:
				MG.box(self, Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), Color(0.85, 0.3, 0.2) if r.warn else Color(0.85, 0.65, 0.15), 6)
			draw_string(_hand, Vector2(rp.position.x + 54, ry + 60), ("Koti · " if r.home else "Ulkona · ") + str(r.note), HORIZONTAL_ALIGNMENT_LEFT,
				rp.size.x - 80, 15, Color(0.75, 0.2, 0.15) if r.warn else Color(0.4, 0.38, 0.33))
		ry += 76


## Tahrat pelin tapaan: kahvikupin renkaat, oluttahrat roiskeineen, makkaran rasvatäplä ja sinappi. Paikat
## kiinteästä siemenestä, jotta tahrat pysyvät paikallaan; piirretään tekstin alle, ettei luettavuus kärsi.
func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, col.darkened(0.4), 1.5)
