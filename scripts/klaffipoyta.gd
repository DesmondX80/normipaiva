extends CanvasLayer
## Klaffipöytä (taitettava pöytä, jonka löytää Zabukin takaa): Minecraft-tyyppinen askartelu huumeiden jatkamiseen.
## Reppu vasemmalla, 3×3-ruudukko ja tulosruutu pöydällä. Klikkaa esine repusta kouraan, sitten ruudukon ruutuun; ruudun
## klikkaus ottaa esineen pois, oikea nappi tyhjentää kourassa olevan. Kun muoto täsmää reseptiin (reseptit.gd), tulos
## ilmestyy oikealle; sen klikkaus askartelee ja kuluttaa ainekset. Esc / F taittaa pöydän kasaan. finished-signaali.

signal finished

const Reseptit := preload("res://scripts/reseptit.gd")
const CELL := 92.0

var game: Node  # main.gd
var _root: Control
var _cells: Array = ["", "", "", "", "", "", "", "", ""]
var _held := ""
var _msg := ""
var _msg_t := 0.0
var _hits: Array = []  # [Rect2, "inv" | "cell" | "result", arvo]
var _mouse := Vector2.ZERO
var mouse_fixed := Vector2(-1, -1)  # testi: kiinteä kursorin paikka
var _t := 0.0
var _hand: SystemFont
var _done := false


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa: taukovalikko ei aukea (menu.gd)
	layer = 60
	CamCtl.free_mouse = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hand = SystemFont.new()
	_hand.font_names = PackedStringArray(["Bradley Hand", "Segoe Print", "Comic Sans MS", "Chalkboard SE", "Marker Felt", "sans-serif"])
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_all)
	_root.gui_input.connect(_input_ui)
	add_child(_root)
	game._craft_learn()
	Sfx.play("cloth", -6.0, 0.8)
	_say("Taita pöytä auki ja kokeile: muoto ratkaisee. Opitut reseptit kirjautuvat pöydän reseptikirjaan.", 6.0)


func _say(text: String, t := 3.5) -> void:
	_msg = text
	_msg_t = t


func _avail(key: String) -> int:
	return game._craft_stock(key) - _cells.count(key)


func _match() -> Dictionary:
	return Reseptit.find(_cells, game.LAAKE_JATKO_MAX)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	_mouse = _root.get_local_mouse_position() if mouse_fixed.x < 0.0 else mouse_fixed
	if Input.is_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_F):
		_close()
		return
	_root.queue_redraw()


func _close() -> void:
	if _done:
		return
	_done = true
	CamCtl.free_mouse = false
	Sfx.play("cloth", -8.0, 1.2)
	finished.emit()
	queue_free()


func _input_ui(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_held = ""
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	for h in _hits:
		if not (h[0] as Rect2).has_point(event.position):
			continue
		match h[1]:
			"inv":
				if _avail(h[2]) > 0:
					_held = h[2]
					Sfx.play("pickup", -14.0, 1.3)
			"cell":
				var i: int = h[2]
				if _cells[i] != "":
					_cells[i] = ""
					Sfx.play("pickup", -14.0, 0.9)
				elif _held != "" and _avail(_held) > 0:
					_cells[i] = _held
					Sfx.play("pickup", -14.0, 1.1)
					if _avail(_held) <= 0:
						_held = ""
			"result":
				_craft()
		return


func _craft() -> void:
	var m := _match()
	if m.is_empty():
		return
	_say(_do_craft(m), 5.0)
	_cells = ["", "", "", "", "", "", "", "", ""]
	_held = ""
	game._craft_learn()
	Sfx.play("pickup", -4.0, 0.7)


## Askartelu itse (lääkelaukku ohittaa: laukulla jatkettu erä on puhdas).
func _do_craft(m: Dictionary) -> String:
	return game._craft_do(m.id, m.drug)


func _draw_all() -> void:
	var ci: Control = _root
	var font := ThemeDB.fallback_font
	var s := ci.size
	_hits.clear()
	var top := _draw_board(ci, s)
	# Ruudukko vasemmalla (3×3), nuoli, tulos.
	var g0 := top.position + Vector2(40, 110)
	var m := _match()
	for i in 9:
		var r := Rect2(g0 + Vector2(i % 3, i / 3) * (CELL + 8), Vector2(CELL, CELL))
		_cell_box(ci, r, _cells[i] != "")
		if _cells[i] != "":
			Reseptit.draw_item(ci, r, _cells[i], font)
		_hits.append([r, "cell", i])
	var ar := g0 + Vector2(3 * (CELL + 8) + 20, 1.5 * (CELL + 8) - 22)
	ci.draw_colored_polygon(PackedVector2Array([ar, ar + Vector2(50, 22), ar + Vector2(0, 44)]), Color(0.3, 0.17, 0.06) if not m.is_empty() else Color(0.55, 0.42, 0.25))
	var rr := Rect2(ar + Vector2(80, -26), Vector2(CELL + 24, CELL + 24))
	_cell_box(ci, rr, not m.is_empty())
	if not m.is_empty():
		var rc: Dictionary = Reseptit.RECIPES[m.id]
		var out := "%s~%d" % [Reseptit.base(m.drug), Reseptit.tier(m.drug) + int(rc.cuts)]
		Reseptit.draw_item(ci, rr, out, font)
		ci.draw_string(font, rr.position + Vector2(0, rr.size.y + 24), "× %d  (klikkaa)" % int(rc.yield), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 18, Color(0.2, 0.1, 0.03))
		ci.draw_string(_hand, rr.position + Vector2(-60, rr.size.y + 52), str(rc.name), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x + 120, 17, Color(0.2, 0.1, 0.03))
		_hits.append([rr, "result", 0])
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		ci.draw_rect(rr.grow(3), Color(1.0, 0.85, 0.3, 0.35 * pulse), false, 3.0)
	else:
		ci.draw_string(_hand, rr.position + Vector2(-40, rr.size.y + 30), "Ei reseptiä", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x + 80, 17, Color(0.4, 0.28, 0.14))
	_draw_recipe_book(ci, font, top)
	# Reppu oikealla: käytettävissä olevat ainekset.
	var ix := top.position.x + 620.0
	ci.draw_string(font, Vector2(ix, top.position.y + 70), "Reppu", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 0.17, 0.06))
	var items: Array = game._craft_items()
	if items.is_empty():
		ci.draw_string(_hand, Vector2(ix, top.position.y + 110), "Ei jatkettavaa eikä jatketta.", HORIZONTAL_ALIGNMENT_LEFT, 320, 18, Color(0.35, 0.22, 0.1))
	for n in items.size():
		var key: String = items[n]
		var r := Rect2(Vector2(ix + (n % 4) * (CELL * 0.82 + 6), top.position.y + 90 + (n / 4) * (CELL * 0.82 + 24)), Vector2(CELL * 0.82, CELL * 0.82))
		var av := _avail(key)
		_cell_box(ci, r, _held == key)
		Reseptit.draw_item(ci, r, key, font)
		if av <= 0:
			ci.draw_rect(r, Color(0.3, 0.2, 0.1, 0.55))
		ci.draw_string(font, r.position + Vector2(0, r.size.y + 16), "%s ×%d" % [_item_name(key), av], HORIZONTAL_ALIGNMENT_LEFT, r.size.x + 4, 12, Color(0.2, 0.1, 0.03))
		_hits.append([r, "inv", key])
	if _msg_t > 0.0 and _msg != "":
		var w := minf(s.x - 80, 820.0)
		var mr := Rect2(Vector2((s.x - w) / 2.0, top.end.y + 20), Vector2(w, 44))
		ci.draw_rect(mr, Color(0.1, 0.08, 0.05, 0.9))
		ci.draw_rect(mr, Color(0.85, 0.65, 0.2), false, 2.0)
		ci.draw_string(font, mr.position + Vector2(12, 29), _msg, HORIZONTAL_ALIGNMENT_LEFT, w - 24, 17, Color(1.0, 0.95, 0.8))
	ci.draw_string(font, Vector2(top.position.x, top.end.y + 90), "[Klikkaus] esine kouraan / ruutuun   [Oikea nappi] tyhjennä koura   [Esc / F] taita pöytä kasaan", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.8, 0.7))
	if _held != "":
		var hr := Rect2(_mouse - Vector2(34, 34), Vector2(68, 68))
		Reseptit.draw_item(ci, hr, _held, font)


## Reseptikirja ruudukon alla: opitun reseptin kuvio (D = huume, A = jatke) ja tulos, avaamaton ???.
func _draw_recipe_book(ci: Control, font: Font, top: Rect2) -> void:
	var known: Dictionary = game.craft_known
	var y0 := top.position.y + 440.0
	ci.draw_string(font, Vector2(top.position.x + 40, y0 - 8), "Reseptikirja  %d / %d" % [known.size(), Reseptit.IDS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.3, 0.17, 0.06))
	var cw := 222.0
	for n in Reseptit.IDS.size():
		var id: String = Reseptit.IDS[n]
		var rc: Dictionary = Reseptit.RECIPES[id]
		var r := Rect2(Vector2(top.position.x + 30 + n * (cw + 10.0), y0), Vector2(cw, 150))
		var ok := known.has(id)
		ci.draw_rect(r, Color(0.96, 0.9, 0.72) if ok else Color(0.62, 0.5, 0.33))
		ci.draw_rect(r, Color(0.35, 0.24, 0.12), false, 2.0)
		if not ok:
			ci.draw_string(font, r.position + Vector2(0, 80), "???", HORIZONTAL_ALIGNMENT_CENTER, cw, 30, Color(0.4, 0.3, 0.18))
			continue
		ci.draw_string(font, r.position + Vector2(6, 17), String(rc.name), HORIZONTAL_ALIGNMENT_LEFT, cw - 8, 14, Color(0.3, 0.12, 0.04))
		var cell := 30.0
		var g0 := r.position + Vector2(10, 30)
		var pat: Array = rc.pattern
		for rr in 3:
			for cc in 3:
				var cr := Rect2(g0 + Vector2(cc, rr) * (cell + 2), Vector2(cell, cell))
				ci.draw_rect(cr, Color(0.9, 0.84, 0.7))
				ci.draw_rect(cr, Color(0.5, 0.38, 0.2), false, 1.0)
				if rr < pat.size() and cc < pat[0].size() and pat[rr][cc] != ".":
					Reseptit.draw_item(ci, cr, String(rc.drug) if pat[rr][cc] == "D" else String(rc.agent), font, false)
		var orc := Rect2(g0 + Vector2(3 * (cell + 2) + 22, cell + 2), Vector2(cell, cell))
		ci.draw_string(font, orc.position + Vector2(-16, 22), "→", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.25, 0.1))
		ci.draw_rect(orc.grow(0), Color(0.9, 0.84, 0.7))
		Reseptit.draw_item(ci, orc, "%s~%d" % [rc.drug, int(rc.cuts)], font, false)
		ci.draw_string(font, g0 + Vector2(0, 3 * (cell + 2) + 16), "× %d annosta, teho %d %%" % [int(rc.yield), roundi(100.0 * pow(0.5, int(rc.cuts)))], HORIZONTAL_ALIGNMENT_LEFT, cw - 16, 13, Color(0.2, 0.45, 0.2))


## Tausta ja työtaso; palauttaa levyn, jolle ruudukko ja reppu piirretään (lääkelaukku ohittaa).
func _draw_board(ci: Control, s: Vector2) -> Rect2:
	var font := ThemeDB.fallback_font
	ci.draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.03, 0.02, 0.82))
	# Pöytälevy: puulankut, taitoskoloissa teräsrunko ja saranat.
	var top := Rect2((s - Vector2(980, 620)) / 2.0, Vector2(980, 620))
	ci.draw_rect(top.grow(8), Color(0.2, 0.2, 0.22))
	ci.draw_rect(top, Color(0.72, 0.55, 0.32))
	for k in 12:
		var y := top.position.y + k * top.size.y / 12.0
		ci.draw_rect(Rect2(top.position.x, y, top.size.x, top.size.y / 12.0), Color(0.72, 0.55, 0.32).darkened(0.05 * (k % 3)))
		ci.draw_line(Vector2(top.position.x, y), Vector2(top.end.x, y), Color(0.45, 0.32, 0.18), 2.0)
	ci.draw_line(Vector2(top.get_center().x, top.position.y), Vector2(top.get_center().x, top.end.y), Color(0.3, 0.3, 0.33), 5.0)  # taitto
	for hy in [top.position.y + 70, top.end.y - 70]:
		ci.draw_rect(Rect2(top.get_center().x - 22, hy - 12, 44, 24), Color(0.6, 0.62, 0.66))
		ci.draw_circle(Vector2(top.get_center().x - 12, hy), 3.0, Color(0.25, 0.25, 0.28))
		ci.draw_circle(Vector2(top.get_center().x + 12, hy), 3.0, Color(0.25, 0.25, 0.28))
	ci.draw_string(font, top.position + Vector2(24, 40), "KLAFFIPÖYTÄ", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.3, 0.17, 0.06))
	return top


func _item_name(key: String) -> String:
	var n: String = Reseptit.NAMES.get(Reseptit.base(key), key)
	return n + (" %d%%" % roundi(100.0 * pow(0.5, Reseptit.tier(key))) if Reseptit.tier(key) > 0 else "")


func _cell_box(ci: Control, r: Rect2, lit: bool) -> void:
	ci.draw_rect(r, Color(0.35, 0.24, 0.12))
	ci.draw_rect(r.grow(-4), Color(0.5, 0.37, 0.2) if lit else Color(0.42, 0.3, 0.16))
	ci.draw_rect(r, Color(1.0, 0.85, 0.35) if lit else Color(0.22, 0.14, 0.06), false, 3.0)
