extends Control
## Reppu (I tai Tab): Minecraft-tyylinen inventaarionäkymä. Harmaa paneeli, 9 x 3 ruudukko tavaroille ja alarivi
## eväille (T syö), esineet 16 x 16 pikselikuvakkeina pinoineen ja lukumäärineen. Hiiren alla olevasta ruudusta
## näytetään nimi ja kuvaus violettireunaisessa laatikossa. Vasemmalla rahat ja tilanne, oikealla kauppalista ja
## jemmat (vain Saloisissa, mökillä pääpelin tehtävät eivät näy). Peli pysähtyy, kun reppu on auki.
## Muotokuvaruudussa on pelaajan oma 3D-hahmo (looks.gd: tuulipuku ja lippis) omassa SubViewportissaan; hahmo
## kääntyy katsomaan hiirtä kuten Minecraftissa.
## Sisältö kysytään pelistä: game.inventory_items() -> [{icon, name, count, desc, tint?, food?}] ja
## game.inventory_info() -> {money, lines: [], list: [], stashes: []}.

const COLS := 9
const ROWS := 3
const SLOT := 54.0
const PAD := 18.0
const PANEL_BG := Color(0.776, 0.776, 0.776)
const SLOT_BG := Color(0.545, 0.545, 0.545)
const DARK := Color(0.216, 0.216, 0.216)
const LIGHT := Color(1, 1, 1)
const TEXT := Color(0.25, 0.25, 0.25)
const PORTRAIT := Vector2(150, 200)
const Looks := preload("res://scripts/looks.gd")

var game: Node

var _items: Array = []
var _food: Array = []
var _info := {}
var _panel := Rect2()
var _slots: Array[Rect2] = []  # 27 reppu + 9 eväät
var _hover := -1
var _icons := {}
var _pv: SubViewport  # hahmon muotokuva, rakennetaan ensimmäisellä avauksella
var _pchar: Node3D
var _ptex: TextureRect  # muotokuva omana lapsenaan: lineaarinen suodatus (muu reppu on pikseligrafiikkaa)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pikselikuvakkeet teräviksi
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if _pv != null:
		_pv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
		_pchar.process_mode = Node.PROCESS_MODE_ALWAYS if visible else Node.PROCESS_MODE_DISABLED
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		size = get_viewport_rect().size
		_ensure_portrait()
		_refresh()
		Sfx.play("cloth", -8.0, 1.2)
	queue_redraw()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory") or (visible and Input.is_key_pressed(KEY_ESCAPE)):
		if visible or not get_tree().paused:
			toggle()
	if visible:
		var h := -1
		var m := get_local_mouse_position()
		for i in _slots.size():
			if _slots[i].has_point(m):
				h = i
		_look_at_mouse(m, _delta)
		if h != _hover:
			_hover = h
			queue_redraw()


func _refresh() -> void:
	var all: Array = game.inventory_items() if game != null else []
	_items = all.filter(func(it): return not it.get("food", false))
	_food = all.filter(func(it): return it.get("food", false))
	_info = game.inventory_info() if game != null else {}
	var w := PAD * 2.0 + COLS * SLOT
	var h := 340.0 + ROWS * SLOT + SLOT + 60.0
	_panel = Rect2((size - Vector2(w, h)) / 2.0, Vector2(w, h))
	_slots.clear()
	var top := _panel.position + Vector2(PAD, 330.0)
	for r in ROWS:
		for c in COLS:
			_slots.append(Rect2(top + Vector2(c * SLOT, r * SLOT), Vector2(SLOT, SLOT)))
	var hot := top + Vector2(0, ROWS * SLOT + 40.0)
	for c in COLS:
		_slots.append(Rect2(hot + Vector2(c * SLOT, 0), Vector2(SLOT, SLOT)))


# --- Piirto -------------------------------------------------------------------------

func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	_bevel(_panel, PANEL_BG, LIGHT, Color(0.33, 0.33, 0.33), 4.0)
	var font := ThemeDB.fallback_font
	var p := _panel.position
	# Yläosa: hahmon "muotokuvaruutu" ja tilanne vasemmalla, kauppalista ja jemmat oikealla.
	var port := _portrait_rect()
	_inset(port, Color(0.08, 0.08, 0.1))
	_draw_portrait(port)
	var y := p.y + PAD + 22.0
	var x := port.end.x + 18.0
	_text(Vector2(x, y), "Rahaa: %s €" % _info.get("money", "0,00"), 20, TEXT)
	for l in _info.get("lines", []):
		y += 26.0
		_text(Vector2(x, y), l, 17, TEXT)
	# Kauppalista ja jemmat tietojen alla rinnakkain.
	var rx := x
	var ry := y + 16.0
	var list: Array = _info.get("list", [])
	if not list.is_empty():
		var paper := Rect2(Vector2(rx, ry), Vector2(170, 26 + list.size() * 22))
		draw_rect(paper, Color(0.96, 0.94, 0.85))
		draw_rect(paper, Color(0.55, 0.5, 0.4), false, 2.0)
		_text(paper.position + Vector2(10, 20), _info.get("list_title", "Kauppalista"), 16, Color(0.2, 0.2, 0.45))
		for i in list.size():
			_text(paper.position + Vector2(14, 42 + i * 22), list[i], 15, Color(0.15, 0.15, 0.3))
		rx = paper.end.x + 16.0
	var stashes: Array = _info.get("stashes", [])
	if not stashes.is_empty():
		_text(Vector2(rx, ry + 16), "Jemmat", 16, TEXT)
		for i in stashes.size():
			_text(Vector2(rx + 6, ry + 38 + i * 20), stashes[i], 14, Color(0.3, 0.2, 0.05))
	_text(p + Vector2(PAD, 322.0), "Reppu", 18, TEXT)
	_text(_slots[ROWS * COLS].position + Vector2(0, -8), "Eväät (T syö)", 18, TEXT)
	for i in _slots.size():
		var it = _slot_item(i)
		_draw_slot(_slots[i], it, i == _hover)
	if _items.size() > ROWS * COLS:
		_text(_slots[ROWS * COLS - 1].end + Vector2(-80, 18), "+%d muuta" % (_items.size() - ROWS * COLS), 14, TEXT)
	_text(Vector2(p.x + PAD, _panel.end.y - 16.0), "I / Tab / Esc sulkee", 14, Color(0.4, 0.4, 0.4))
	if _hover >= 0 and _slot_item(_hover) != null:
		_tooltip(get_local_mouse_position() + Vector2(18, -10), _slot_item(_hover))


func _slot_item(i: int) -> Variant:
	if i < ROWS * COLS:
		return _items[i] if i < _items.size() else null
	var k := i - ROWS * COLS
	return _food[k] if k < _food.size() else null


func _draw_slot(r: Rect2, it: Variant, hover: bool) -> void:
	var inner := r.grow(-3.0)
	_inset(inner, SLOT_BG)
	if it != null:
		var tex := _icon(it.icon, it.get("tint", Color.WHITE))
		draw_texture_rect(tex, inner.grow(-5.0), false)
		var n: int = it.get("count", 1)
		if n > 1:
			var font := ThemeDB.fallback_font
			var s := str(n)
			var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var at := inner.end - Vector2(tw + 2.0, 3.0)
			draw_string(font, at + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.24, 0.24, 0.24))
			draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if hover:
		draw_rect(inner, Color(1, 1, 1, 0.45))


func _tooltip(at: Vector2, it: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var lines := [it.name]
	if it.get("desc", "") != "":
		lines.append(it.desc)
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
	var r := Rect2(at, Vector2(w + 20.0, 12.0 + lines.size() * 22.0))
	if r.end.x > size.x:
		r.position.x = at.x - r.size.x - 36.0
	draw_rect(r, Color(0.06, 0.0, 0.1, 0.94))
	draw_rect(r.grow(-2.0), Color(0.25, 0.0, 0.62), false, 2.0)
	for i in lines.size():
		draw_string(font, r.position + Vector2(10, 24 + i * 22), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
			Color.WHITE if i == 0 else Color(0.66, 0.66, 0.66))


## Minecraft-paneelin kohokuvio: vaalea ylä- ja vasen reuna, tumma ala- ja oikea reuna.
func _bevel(r: Rect2, fill: Color, hi: Color, lo: Color, t: float) -> void:
	draw_rect(r, fill)
	draw_rect(Rect2(r.position, Vector2(r.size.x, t)), hi)
	draw_rect(Rect2(r.position, Vector2(t, r.size.y)), hi)
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - t), Vector2(r.size.x, t)), lo)
	draw_rect(Rect2(Vector2(r.end.x - t, r.position.y), Vector2(t, r.size.y)), lo)
	draw_rect(Rect2(r.position - Vector2(2, 2), r.size + Vector2(4, 4)), Color.BLACK, false, 2.0)


## Upotettu ruutu: tumma ylä- ja vasen reuna, vaalea ala- ja oikea.
func _inset(r: Rect2, fill: Color) -> void:
	draw_rect(r, fill)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), DARK)
	draw_rect(Rect2(r.position, Vector2(2, r.size.y)), DARK)
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - 2), Vector2(r.size.x, 2)), LIGHT)
	draw_rect(Rect2(Vector2(r.end.x - 2, r.position.y), Vector2(2, r.size.y)), LIGHT)


func _portrait_rect() -> Rect2:
	return Rect2(_panel.position + Vector2(PAD, PAD), PORTRAIT)


## Pelaajan hahmo samasta mallista kuin pelissä: oma 3D-maailma, kamera, valot ja lepoanimaatio.
func _ensure_portrait() -> void:
	if _pv != null:
		return
	_pv = SubViewport.new()
	_pv.own_world_3d = true
	_pv.msaa_3d = Viewport.MSAA_4X
	_pv.size = Vector2i(PORTRAIT * 2.0)  # tarkempi kuva, piirretään puoleen kokoon
	_pv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_pv)
	var root := Node3D.new()
	_pv.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.11, 0.14)  # ruudun tumma tausta (läpinäkyvä tausta estäisi ihon SSS:n)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.3
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.7, 0.85, 1.0)
	root.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 0.95, 3.75)
	cam.rotation_degrees = Vector3(-2, 0, 0)
	root.add_child(cam)
	cam.current = true
	_pchar = Looks.make(root, Looks.PLAYER)
	Looks.add_cap(_pchar)
	_pchar.rotation.y = PI  # kasvot -Z:aan: käännetään kameraa kohti
	_pchar.play("Idle")
	_ptex = TextureRect.new()
	_ptex.texture = _pv.get_texture()
	_ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ptex.stretch_mode = TextureRect.STRETCH_SCALE
	_ptex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ptex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ptex)


## Hahmo kääntää vartaloa ja päätä hiiren suuntaan (Minecraftin inventaarion tapaan).
func _look_at_mouse(m: Vector2, delta: float) -> void:
	if _pchar == null:
		return
	var r := _portrait_rect()
	var c := r.get_center() + Vector2(0, -r.size.y * 0.3)
	var yaw := clampf((m.x - c.x) / 400.0, -0.7, 0.7)
	var pitch := clampf((m.y - c.y) / 500.0, -0.4, 0.4)
	_pchar.rotation.y = lerp_angle(_pchar.rotation.y, PI + yaw * 0.6, 1.0 - exp(-8.0 * delta))
	_pchar.set_override("Head", Vector3.UP, yaw * 0.7)
	_pchar.set_override("neck_01", Vector3.RIGHT, pitch)


func _draw_portrait(r: Rect2) -> void:
	if _ptex != null:
		_ptex.position = r.position + Vector2(2, 2)
		_ptex.size = r.size - Vector2(4, 4)


func _text(at: Vector2, s: String, fs: int, col: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# --- Pikselikuvakkeet (16 x 16) ------------------------------------------------------

func _icon(id: String, tint: Color) -> Texture2D:
	var key := "%s:%s" % [id, tint.to_html()]
	if _icons.has(key):
		return _icons[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_paint(img, id, tint)
	_outline(img)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


static func _r(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < 16 and yy < 16:
				img.set_pixel(xx, yy, c)


static func _c(img: Image, cx: float, cy: float, rad: float, c: Color) -> void:
	for yy in 16:
		for xx in 16:
			if Vector2(xx + 0.5 - cx, yy + 0.5 - cy).length() <= rad:
				img.set_pixel(xx, yy, c)


## Tumma ääriviiva läpinäkyviin naapureihin ja varjostus oikeaan alareunaan (Minecraft-tyyli).
static func _outline(img: Image) -> void:
	var src := img.duplicate() as Image
	for y in 16:
		for x in 16:
			var c := src.get_pixel(x, y)
			if c.a > 0.0:
				var rn := x < 15 and src.get_pixel(x + 1, y).a == 0.0
				var bn := y < 15 and src.get_pixel(x, y + 1).a == 0.0
				if rn or bn:
					img.set_pixel(x, y, c.darkened(0.35))
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < 16 and n.y < 16 and src.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, Color(0.1, 0.08, 0.06, 0.9))
					break


static func _paint(img: Image, id: String, tint: Color) -> void:
	match id:
		"kalja":
			_r(img, 7, 1, 2, 1, Color(0.9, 0.75, 0.2))
			_r(img, 7, 2, 2, 3, Color(0.42, 0.22, 0.06))
			_r(img, 6, 5, 4, 1, Color(0.42, 0.22, 0.06))
			_r(img, 5, 6, 6, 9, Color(0.42, 0.22, 0.06))
			_r(img, 5, 8, 6, 3, Color(0.95, 0.85, 0.3))
			_r(img, 7, 9, 2, 1, Color(0.7, 0.1, 0.1))
			_r(img, 6, 6, 1, 2, Color(0.75, 0.5, 0.25))
			_r(img, 6, 11, 1, 3, Color(0.75, 0.5, 0.25))
		"viina":
			_r(img, 7, 1, 2, 1, Color(0.85, 0.1, 0.1))
			_r(img, 7, 2, 2, 3, Color(0.8, 0.88, 0.9))
			_r(img, 6, 5, 4, 1, Color(0.8, 0.88, 0.9))
			_r(img, 5, 6, 6, 9, Color(0.8, 0.88, 0.9))
			_r(img, 5, 8, 6, 4, Color(0.95, 0.95, 0.88))
			_r(img, 6, 9, 4, 1, Color(0.1, 0.25, 0.6))
			_r(img, 6, 6, 1, 2, Color(1, 1, 1))
			_r(img, 6, 12, 1, 2, Color(1, 1, 1))
		"kanisteri":
			_r(img, 3, 5, 10, 10, Color(0.9, 0.9, 0.85))
			_r(img, 4, 2, 5, 1, Color(0.6, 0.6, 0.6))
			_r(img, 4, 3, 1, 2, Color(0.6, 0.6, 0.6))
			_r(img, 8, 3, 1, 2, Color(0.6, 0.6, 0.6))
			_r(img, 10, 3, 2, 2, Color(0.8, 0.15, 0.1))
			_r(img, 4, 8, 8, 5, Color(0.85, 0.88, 0.9))
			_r(img, 5, 9, 6, 1, Color(0.1, 0.1, 0.1))
			_r(img, 5, 11, 4, 1, Color(0.1, 0.1, 0.1))
			_r(img, 4, 6, 1, 8, Color(1, 1, 1))
		"makkara", "makkara_valmis":
			var col := Color(0.88, 0.45, 0.42) if id == "makkara" else Color(0.5, 0.26, 0.12)
			for i in 8:
				_c(img, 3.5 + i * 1.3, 12.5 - i * 1.3, 2.2, col)
			_c(img, 5.5, 10.0, 0.8, col.lightened(0.3))
			if id == "makkara_valmis":
				for i in 3:
					_r(img, 5 + i * 3, 10 - i * 3, 2, 1, Color(0.2, 0.1, 0.05))
		"tulitikut":
			_r(img, 2, 6, 12, 7, Color(0.15, 0.3, 0.7))
			_r(img, 2, 6, 12, 2, Color(0.95, 0.8, 0.2))
			for i in 4:
				_r(img, 4 + i * 2, 3, 1, 3, Color(0.9, 0.8, 0.55))
				_r(img, 4 + i * 2, 2, 1, 1, Color(0.85, 0.1, 0.1))
		"suklaa":
			_r(img, 2, 4, 12, 9, Color(0.1, 0.2, 0.65))
			_r(img, 2, 8, 12, 1, Color(0.9, 0.75, 0.3))
			_r(img, 10, 4, 4, 4, Color(0.4, 0.2, 0.1))
			_r(img, 11, 5, 1, 1, Color(0.55, 0.3, 0.15))
			_r(img, 3, 5, 5, 1, Color(0.95, 0.95, 0.95))
		"varaosa":
			_r(img, 1, 7, 14, 2, Color(0.72, 0.72, 0.76))
			_r(img, 1, 6, 3, 1, Color(0.85, 0.85, 0.9))
			_r(img, 12, 9, 3, 1, Color(0.85, 0.85, 0.9))
			_c(img, 8, 8, 2.2, Color(0.3, 0.3, 0.32))
		"jalkapallo":
			_c(img, 8, 8, 6.3, Color(0.96, 0.96, 0.96))
			_r(img, 7, 6, 2, 2, Color(0.1, 0.1, 0.1))
			_r(img, 3, 8, 2, 2, Color(0.1, 0.1, 0.1))
			_r(img, 11, 8, 2, 2, Color(0.1, 0.1, 0.1))
			_r(img, 5, 12, 2, 1, Color(0.1, 0.1, 0.1))
			_r(img, 9, 12, 2, 1, Color(0.1, 0.1, 0.1))
			_r(img, 7, 2, 2, 1, Color(0.1, 0.1, 0.1))
		"pulla":
			_c(img, 8, 9, 5.5, Color(0.8, 0.52, 0.22))
			_c(img, 8, 9, 3.2, Color(0.62, 0.36, 0.14))
			_c(img, 8, 9, 1.6, Color(0.8, 0.52, 0.22))
			for d in [Vector2i(5, 6), Vector2i(10, 7), Vector2i(7, 12), Vector2i(11, 11), Vector2i(4, 10)]:
				_r(img, d.x, d.y, 1, 1, Color(1, 1, 1))
		"piirakka":
			_r(img, 3, 6, 10, 6, Color(0.78, 0.52, 0.2))
			_r(img, 2, 7, 12, 4, Color(0.78, 0.52, 0.2))
			_r(img, 4, 6, 8, 1, Color(0.9, 0.68, 0.32))
			_r(img, 5, 8, 1, 1, Color(0.55, 0.32, 0.1))
			_r(img, 9, 9, 1, 1, Color(0.55, 0.32, 0.1))
		"puolukka", "mustikka":
			var bc := Color(0.82, 0.08, 0.1) if id == "puolukka" else Color(0.18, 0.2, 0.55)
			_r(img, 7, 2, 2, 3, Color(0.2, 0.5, 0.15))
			_r(img, 9, 3, 3, 2, Color(0.25, 0.6, 0.2))
			for c in [Vector2(5.5, 8.5), Vector2(10.5, 8.5), Vector2(8, 12), Vector2(4.5, 12.5), Vector2(11.5, 12.5)]:
				_c(img, c.x, c.y, 2.2, bc)
				_r(img, int(c.x) - 1, int(c.y) - 1, 1, 1, bc.lightened(0.5))
		"kantarelli":
			_r(img, 7, 9, 3, 5, Color(0.95, 0.72, 0.2))
			_r(img, 3, 5, 10, 2, Color(0.98, 0.68, 0.12))
			_r(img, 4, 7, 8, 2, Color(0.95, 0.72, 0.2))
			_r(img, 5, 4, 6, 1, Color(1.0, 0.8, 0.3))
		"herkkutatti":
			_r(img, 6, 8, 5, 6, Color(0.92, 0.88, 0.78))
			_c(img, 8.5, 7, 5.5, Color(0.5, 0.3, 0.15))
			_r(img, 2, 8, 13, 8, Color(0, 0, 0, 0))
			_r(img, 6, 8, 5, 6, Color(0.92, 0.88, 0.78))
			_r(img, 5, 3, 2, 1, Color(0.65, 0.42, 0.22))
		"kala", "savukala", "karrella":
			var fc := Color(0.45, 0.55, 0.45)
			if id == "savukala":
				fc = Color(0.8, 0.55, 0.2)
			elif id == "karrella":
				fc = Color(0.15, 0.12, 0.1)
			_r(img, 3, 6, 9, 5, fc)
			_r(img, 4, 5, 7, 7, fc)
			_r(img, 12, 5, 1, 7, fc.darkened(0.2))
			_r(img, 13, 4, 2, 2, fc.darkened(0.2))
			_r(img, 13, 11, 2, 2, fc.darkened(0.2))
			_r(img, 5, 7, 1, 1, Color(0.05, 0.05, 0.05))
			_r(img, 4, 9, 7, 1, fc.lightened(0.3))
		"lintu":
			_c(img, 8.5, 9.5, 4.5, tint)
			_c(img, 4.5, 5.5, 2.3, tint)
			_r(img, 1, 5, 2, 1, Color(0.85, 0.6, 0.1))
			_r(img, 4, 5, 1, 1, Color(0.05, 0.05, 0.05))
			_r(img, 11, 7, 4, 2, tint.darkened(0.3))
			_r(img, 7, 14, 1, 2, Color(0.7, 0.5, 0.2))
			_r(img, 10, 14, 1, 2, Color(0.7, 0.5, 0.2))
		"janis":
			_c(img, 9, 10.5, 4.5, Color(0.6, 0.5, 0.38))
			_c(img, 5, 8, 2.8, Color(0.6, 0.5, 0.38))
			_r(img, 4, 1, 1, 6, Color(0.55, 0.45, 0.34))
			_r(img, 6, 2, 1, 5, Color(0.55, 0.45, 0.34))
			_r(img, 4, 7, 1, 1, Color(0.05, 0.05, 0.05))
			_c(img, 13.5, 9.5, 1.5, Color(0.95, 0.95, 0.95))
		"savuriista":
			_c(img, 6, 6, 4.5, Color(0.6, 0.32, 0.12))
			_r(img, 9, 9, 2, 4, Color(0.92, 0.9, 0.82))
			_c(img, 11, 13.5, 1.6, Color(0.92, 0.9, 0.82))
			_c(img, 13, 12, 1.6, Color(0.92, 0.9, 0.82))
			_r(img, 4, 4, 2, 1, Color(0.78, 0.48, 0.2))
		"polkky":
			_c(img, 8, 8, 6.5, Color(0.42, 0.28, 0.14))
			_c(img, 8, 8, 5.3, Color(0.86, 0.72, 0.48))
			_c(img, 8, 8, 3.4, Color(0.78, 0.62, 0.38))
			_c(img, 8, 8, 2.3, Color(0.86, 0.72, 0.48))
			_r(img, 8, 8, 1, 1, Color(0.6, 0.45, 0.25))
		"halko":
			for i in 10:
				_r(img, 2 + i, 12 - i, 3, 3, Color(0.86, 0.72, 0.48))
				_r(img, 2 + i, 11 - i, 2, 1, Color(0.42, 0.28, 0.14))
		"tuote":
			_r(img, 4, 2, 8, 12, tint)
			_r(img, 5, 5, 6, 4, Color(0.97, 0.97, 0.95))
			_r(img, 6, 6, 4, 1, tint.darkened(0.4))
			_r(img, 6, 8, 3, 1, Color(0.4, 0.4, 0.4))
			_r(img, 4, 2, 8, 1, tint.lightened(0.35))
		_:
			_r(img, 4, 4, 8, 8, Color(0.6, 0.2, 0.7))
			_r(img, 4, 4, 4, 4, Color(0.1, 0.1, 0.1))
			_r(img, 8, 8, 4, 4, Color(0.1, 0.1, 0.1))
