extends PanelContainer
## Esinevalikko (#29): lista pelaajan mukana olevista tavaroista. W/S valitsee, E antaa, Q peruuttaa.
## open(items, title): items = [[id, nimi], ...]; lopuksi chosen(id) tai cancelled.

signal chosen(id: String)
signal cancelled

var _items: Array = []
var _sel := 0
var _title: Label
var _list: VBoxContainer
var _open_frame := 0


func _ready() -> void:
	visible = false
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -220
	offset_right = 220
	offset_top = 10  # ruudun keskeltä alaspäin: viestit ja vihjeet jäävät näkyviin
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.88)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(16)
	bg.border_color = Color(1.0, 0.85, 0.2)
	bg.set_border_width_all(2)
	add_theme_stylebox_override("panel", bg)
	var box := VBoxContainer.new()
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	box.add_child(_title)
	_list = VBoxContainer.new()
	box.add_child(_list)
	var help := Label.new()
	help.text = "W/S tai rulla valitse · E tai vasen nappi anna · Q peruuta"
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	box.add_child(help)


func open(items: Array, title: String) -> void:
	_items = items
	_sel = 0
	_title.text = title
	_open_frame = Engine.get_process_frames()
	visible = true
	_refresh()


func is_open() -> bool:
	return visible


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for i in _items.size():
		var l := Label.new()
		l.text = ("▶ " if i == _sel else "   ") + _items[i][1]
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color.WHITE if i == _sel else Color(0.75, 0.75, 0.75))
		_list.add_child(l)


## Hiiren rulla selaa valikkoa (ei toimintona, ettei rulla liikuta hahmoa).
func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton) or not event.pressed or _items.is_empty():
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_sel = (_sel - 1 + _items.size()) % _items.size()
		_refresh()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_sel = (_sel + 1) % _items.size()
		_refresh()


func _process(_delta: float) -> void:
	if not visible or Engine.get_process_frames() == _open_frame:
		return  # avaava E-painallus ei saa heti valita
	if Input.is_action_just_pressed("forward"):
		_sel = (_sel - 1 + _items.size()) % _items.size()
		_refresh()
	elif Input.is_action_just_pressed("back"):
		_sel = (_sel + 1) % _items.size()
		_refresh()
	elif Input.is_action_just_pressed("interact"):
		visible = false
		chosen.emit(_items[_sel][0])
	elif Input.is_action_just_pressed("bell"):
		visible = false
		cancelled.emit()
