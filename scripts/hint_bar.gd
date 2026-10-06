extends Control
## Toimintovihjeet ruudun alaosassa keskellä, samaan tyyliin kuin puhevihje (talk_prompt.gd): näppäimet
## näppäinhattuina, toiminto valkoisella, hinnat ja lisätiedot harmaalla. Lukee vanhan vihjerivin tekstin muodossa
## "Tietoa   [E] Toiminto (lisä)   [Q] Toinen – selitys"; rivinvaihto tekee uuden rivin, ja liian leveä rivi
## jaetaan useammalle. main.gd antaa tekstin set_text:llä joka ruutu (näppäimet jo asetusten mukaisina).

const BOTTOM := 150.0  # keskikohdan etäisyys ruudun alareunasta (px), sama kuin puhevihjeellä
const GAP := 22.0  # toimintojen väli rivillä

var left := 0.0  # vasen raja (lappu auki: main.gd _avoid_note)
var _text := ""
var _shown := "-"
var _a := 0.0
var _pill: PanelContainer
var _rows: VBoxContainer
var _re := RegEx.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_re.compile(r"\[([^\]\n]{1,14})\]")
	_pill = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.86)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.set_border_width_all(1)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	_pill.add_theme_stylebox_override("panel", sb)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pill)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_pill.add_child(_rows)
	modulate.a = 0.0
	visible = false


func set_text(t: String) -> void:
	_text = t.strip_edges()


func _process(delta: float) -> void:
	if _text != _shown:
		_shown = _text
		if _text != "":
			_rebuild()
	_a = move_toward(_a, 1.0 if _text != "" else 0.0, delta * (8.0 if _text != "" else 12.0))
	visible = _a > 0.0
	if not visible:
		return
	var vs := get_viewport_rect().size
	_pill.reset_size()
	var sz := _pill.get_combined_minimum_size()
	var cx := (maxf(left, 0.0) + vs.x) / 2.0
	_pill.position = Vector2(clampf(cx - sz.x / 2.0, maxf(left, 12.0), maxf(vs.x - sz.x - 12.0, 12.0)),
		vs.y - BOTTOM - sz.y / 2.0 + (1.0 - _a) * 10.0)
	modulate.a = _a


## Rivit uusiksi: osat (tieto tai näppäin + toiminto + lisä) riveille niin, ettei laatta ylitä ruudun leveyttä.
func _rebuild() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var vs := get_viewport_rect().size
	var max_w := minf(vs.x - maxf(left, 0.0) - 80.0, 1400.0)
	for line in _text.split("\n"):
		if line.strip_edges() == "":
			continue
		var row := _new_row()
		var w := 0.0
		for part in _parse(line):
			var chunk := _chunk(part)
			row.add_child(chunk)  # mitataan puussa (pelin teeman fontti)
			var cw := chunk.get_combined_minimum_size().x
			if row.get_child_count() > 1 and w + GAP + cw > max_w:
				row.remove_child(chunk)
				row = _new_row()
				row.add_child(chunk)
				w = 0.0
			w += cw + (GAP if row.get_child_count() > 1 else 0.0)


func _new_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(GAP))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_rows.add_child(row)
	return row


## Rivi osiin: [näppäin, toiminto, lisä]. Ensimmäistä näppäintä edeltävä teksti on tieto (näppäin "").
func _parse(line: String) -> Array:
	var out: Array = []
	var ms := _re.search_all(line)
	var first := ms[0].get_start() if not ms.is_empty() else line.length()
	var info := _clean(line.substr(0, first))
	if info != "":
		out.append(["", info, ""])
	for i in ms.size():
		var m: RegExMatch = ms[i]
		var end := ms[i + 1].get_start() if i + 1 < ms.size() else line.length()
		var seg := _clean(line.substr(m.get_end(), end - m.get_end()))
		var main := seg
		var extra := ""
		var dash := seg.find(" – ")
		if dash > 0:
			main = seg.left(dash)
			extra = seg.substr(dash + 3)
		elif seg.ends_with(")") and seg.rfind(" (") > 0:
			main = seg.left(seg.rfind(" ("))
			extra = seg.substr(seg.rfind(" (") + 1)
		out.append([m.get_string(1), main, extra])
	return out


func _clean(s: String) -> String:
	s = s.strip_edges()
	while s.begins_with("·") or s.ends_with("·"):
		s = s.trim_prefix("·").trim_suffix("·").strip_edges()
	return s


func _chunk(part: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if part[0] != "":
		var cap := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.96, 0.94, 0.88)
		cs.set_corner_radius_all(6)
		cs.border_color = Color(0.62, 0.6, 0.55)
		cs.border_width_bottom = 4
		cs.content_margin_left = 8
		cs.content_margin_right = 8
		cs.content_margin_top = 0
		cs.content_margin_bottom = 1
		cap.add_theme_stylebox_override("panel", cs)
		cap.custom_minimum_size = Vector2(32, 32)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var k := _label(part[0], 19, Color(0.12, 0.12, 0.14), false)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(k)
		h.add_child(cap)
		if part[1] != "":
			h.add_child(_label(part[1], 22, Color.WHITE))
	elif part[1] != "":
		h.add_child(_label(part[1], 21, Color(0.86, 0.86, 0.88)))
	if part[2] != "":
		h.add_child(_label(part[2], 18, Color(0.7, 0.7, 0.74)))
	return h


func _label(t: String, size: int, c: Color, outline := true) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("outline_size", 3)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
