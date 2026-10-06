extends Control
## Puhevihje ruudun alaosassa keskellä (vanhan vihjerivin paikalla, ei peitä hahmon puhekuplaa): näppäinhattu
## (asetuksissa valittu näppäin), toiminto ("Puhu"), nimi hahmon värillä ja pieni rivi siitä, mitä hahmon kanssa voi
## nyt tehdä. Liukuu näkyviin ja häipyy, kun show_for-kutsuja ei enää tule (main.gd kutsuu joka ruutu lähellä).

const BOTTOM := 150.0  # keskikohdan etäisyys ruudun alareunasta (px)

var _target: Node3D
var _seen := -10
var _a := 0.0
var _pill: PanelContainer
var _key: Label
var _action: Label
var _name: Label
var _sub: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_pill = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.86)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	sb.content_margin_right = 16
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	_pill.add_theme_stylebox_override("panel", sb)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_pill.add_child(row)
	# Näppäinhattu: vaalea, pyöristetty, alareunassa tummempi "reuna" kuin oikeassa näppäimessä.
	var cap := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.96, 0.94, 0.88)
	cs.set_corner_radius_all(7)
	cs.border_color = Color(0.62, 0.6, 0.55)
	cs.border_width_bottom = 4
	cs.content_margin_left = 10
	cs.content_margin_right = 10
	cs.content_margin_top = 1
	cs.content_margin_bottom = 1
	cap.add_theme_stylebox_override("panel", cs)
	cap.custom_minimum_size = Vector2(38, 38)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	_key = Label.new()
	_key.add_theme_font_size_override("font_size", 22)
	_key.add_theme_color_override("font_color", Color(0.12, 0.12, 0.14))
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(_key)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	_action = _mk(22, Color.WHITE)
	top.add_child(_action)
	_name = _mk(22, Color.WHITE)
	top.add_child(_name)
	_sub = _mk(15, Color(0.78, 0.78, 0.8))
	col.add_child(_sub)
	modulate.a = 0.0
	visible = false


func _mk(size: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 3)
	return l


## Näytä vihje hahmolle tällä ruudulla. sub = mitä voi tehdä (tyhjä = ei riviä), hot = rivi korostettuna (tarina).
func show_for(target: Node3D, key: String, action: String, who: String, color: Color, sub := "", hot := false) -> void:
	if target != _target:
		_a = 0.0
	_target = target
	_seen = Engine.get_process_frames()
	_key.text = key
	_action.text = action
	_name.text = who
	_name.add_theme_color_override("font_color", color)
	_sub.text = sub
	_sub.visible = sub != ""
	_sub.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if hot else Color(0.78, 0.78, 0.8))


func _process(delta: float) -> void:
	var on := Engine.get_process_frames() - _seen <= 1
	_a = move_toward(_a, 1.0 if on else 0.0, delta * (7.0 if on else 10.0))
	visible = _a > 0.0
	if not visible:
		return
	var vs := get_viewport_rect().size
	_pill.reset_size()
	var sz := _pill.get_combined_minimum_size()
	var pop := 0.9 + 0.1 * ease(_a, 0.4)  # pieni ponnahdus
	_pill.pivot_offset = sz / 2.0
	_pill.scale = Vector2(pop, pop)
	_pill.position = Vector2((vs.x - sz.x) / 2.0, vs.y - BOTTOM - sz.y / 2.0 + (1.0 - _a) * 12.0)
	modulate.a = _a
