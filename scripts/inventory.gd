extends Control
## Reppu (I tai Tab): pelaajan tuulipuvun värinen reppu (violetti, turkoosi ja musta raita, hihnat, kantolenkki ja
## soljet), jonka etutaskussa on yksi rivi taskuja: reppuun mahtuu SLOTS tavaraa, eväät mukaan lukien (T syö).
## Ylimenevät näkyvät viimeisessä taskussa "+N" (tavarat pursuavat reppua). Esineet 16 x 16 pikselikuvakkeina
## lukumäärineen; hiiren alla olevasta taskusta nimi ja kuvaus vihjerivin tummassa pillerissä. Repun päällä
## polaroid pelaajan 3D-hahmosta (kääntyy katsomaan hiirtä) ja heippalaput kuten Päivin lappu: rahat ja
## tilanne, kauppalista ja jemmat, tarinan tehtävät. Peli pysähtyy, kun reppu on auki.
## Sisältö kysytään pelistä: game.inventory_items() -> [{icon, name, count, desc, tint?, food?, use?}] ja
## game.inventory_info() -> {money, lines: [], list: [], stashes: [], tasks?: []}.

const SLOTS := 9
const SLOT := 70.0
const VIOLET := Color(0.42, 0.18, 0.58)
const TURQ := Color(0.08, 0.66, 0.64)
const BLACK := Color(0.07, 0.07, 0.09)
const POCKET := Color(0.34, 0.13, 0.48)
const STITCH := Color(0.85, 0.8, 0.95, 0.55)
const PAPER := Color(1.0, 0.95, 0.55)  # note.gd: Päivin heippalappu
const PAPER_W := Color(0.97, 0.95, 0.88)
const INK := Color(0.16, 0.18, 0.42)
const PORTRAIT := Vector2(150, 190)
const Looks := preload("res://scripts/looks.gd")

var game: Node

var _items: Array = []  # tavarat ja eväät yhdessä rivissä
var _info := {}
var _panel := Rect2()  # koko näkymä
var _bag := Rect2()  # repun runko
var _slots: Array[Rect2] = []
var _hover := -1
var _icons := {}
var _pv: SubViewport  # hahmon muotokuva, rakennetaan ensimmäisellä avauksella
var _pchar: Node3D
var _ptex: TextureRect  # muotokuva omana lapsenaan: lineaarinen suodatus (muu reppu on pikseligrafiikkaa)
var _hand: SystemFont  # lappujen käsiala (sama kuin note.gd)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pikselikuvakkeet teräviksi
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hand = SystemFont.new()
	_hand.font_names = PackedStringArray(["Bradley Hand", "Segoe Print", "Comic Sans MS", "Chalkboard SE", "Marker Felt",
		"Noteworthy", "sans-serif"])


## Klikkaus käytettävään tarvikkeeseen (it.use): syö tai juo (main.gd use_item).
func _gui_input(event: InputEvent) -> void:
	if not visible or game == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hover >= 0:
		var it = _slot_item(_hover)
		if it != null and it.get("use", "") != "":
			game.use_item(it.use)
			_refresh()
			queue_redraw()
			accept_event()


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
	# Tavarat ensin, eväät perään: sama yksi rivi.
	_items = all.filter(func(it): return not it.get("food", false)) + all.filter(func(it): return it.get("food", false))
	_info = game.inventory_info() if game != null else {}
	var w := minf(1000.0, size.x - 40.0)
	var h := 640.0
	_panel = Rect2((size - Vector2(w, h)) / 2.0, Vector2(w, h))
	var bw := SLOTS * SLOT + 120.0
	_bag = Rect2(Vector2(_panel.get_center().x - bw / 2.0, _panel.end.y - 300.0), Vector2(bw, 290.0))
	_slots.clear()
	var row := Vector2(_bag.get_center().x - SLOTS * SLOT / 2.0, _bag.position.y + 160.0)
	for c in SLOTS:
		_slots.append(Rect2(row + Vector2(c * SLOT, 0), Vector2(SLOT, SLOT)))


# --- Piirto -------------------------------------------------------------------------

func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))
	_draw_bag()
	var p := _panel.position
	# Polaroid pelaajasta vasemmassa yläkulmassa, teippi päällä.
	var port := _portrait_rect()
	draw_rect(Rect2(port.position + Vector2(-4, -2), port.size + Vector2(20, 54)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(port.position - Vector2(10, 10), port.size + Vector2(20, 54)), PAPER_W)
	draw_rect(port, Color(0.1, 0.11, 0.14))
	_draw_portrait(port)
	draw_string(_hand, Vector2(port.position.x + 4, port.end.y + 32), "Minä", HORIZONTAL_ALIGNMENT_LEFT, port.size.x, 20, INK)
	_tape(Vector2(port.get_center().x, port.position.y - 10), -4.0)
	# Heippalaput: tilanne, kauppalista ja jemmat, tehtävät.
	var lines: Array = ["Rahaa %s €" % _info.get("money", "0,00")]
	lines.append_array(_info.get("lines", []))
	var x := _note(Vector2(port.end.x + 40.0, p.y + 8.0), "", lines, 1.5) + 24.0
	var col: Array = []
	var list: Array = _info.get("list", [])
	if not list.is_empty():
		col.append(_info.get("list_title", "Kauppalista") + ":")
		col.append_array(list)
	var stashes: Array = _info.get("stashes", [])
	if not stashes.is_empty():
		if not col.is_empty():
			col.append("")
		col.append("Jemmat:")
		col.append_array(stashes)
	if not col.is_empty():
		x = _note(Vector2(x, p.y + 20.0), "", col, -2.0) + 24.0
	var tasks: Array = _info.get("tasks", [])
	if not tasks.is_empty():
		var tl: Array = []
		for t in tasks:
			tl.append(("✔ " if t[1] else "• ") + t[0])
		_note(Vector2(x, p.y + 4.0), "Tehtävät", tl, 1.0, PAPER_W)
	# Taskut.
	var n := _items.size()
	for i in _slots.size():
		_draw_slot(_slots[i], _slot_item(i), i == _hover)
	if n > SLOTS:
		var r := _slots[SLOTS - 1]
		draw_rect(r.grow(-6.0), Color(0, 0, 0, 0.5))
		_outlined(r.position + Vector2(16, 44), "+%d" % (n - SLOTS + 1), 24, Color.WHITE)
	var pk := _pocket_rect()
	_outlined(Vector2(pk.position.x + 24.0, pk.position.y + 60.0), "Reppu %d / %d" % [mini(n, SLOTS), SLOTS], 17, Color.WHITE)
	if n > SLOTS:
		_outlined(Vector2(pk.end.x - 300.0, pk.position.y + 60.0), "Reppu pullottaa, kaikki ei mahdu!", 15, Color(1.0, 0.85, 0.4))
	_outlined(Vector2(pk.position.x + 24.0, pk.end.y - 12.0), "Klikkaa evästä (T): syö tai juo   ·   I / Tab / Esc sulkee", 14, Color(0.85, 0.85, 0.85))
	if _hover >= 0 and _slot_item(_hover) != null:
		_tooltip(get_local_mouse_position() + Vector2(18, -10), _slot_item(_hover))


func _pocket_rect() -> Rect2:
	return Rect2(_bag.position + Vector2(36, 104), Vector2(_bag.size.x - 72, _bag.size.y - 118))


## Reppu: kantolenkki, olkahihnat, pyöristetty runko tuulipuvun raidoin, läppä soljin ja vetoketjullinen etutasku.
func _draw_bag() -> void:
	var b := _bag
	draw_arc(Vector2(b.get_center().x, b.position.y - 4.0), 36.0, PI, TAU, 24, BLACK, 11.0)
	for sx: float in [-1.0, 1.0]:
		var hx := b.get_center().x + sx * b.size.x * 0.3
		draw_colored_polygon(PackedVector2Array([Vector2(hx - 18, b.position.y - 34), Vector2(hx + 18, b.position.y - 34),
			Vector2(hx + 22, b.position.y + 20), Vector2(hx - 22, b.position.y + 20)]), BLACK)
	var body := _round_poly(b, 48.0)
	draw_colored_polygon(_offset(body, Vector2(8, 10)), Color(0, 0, 0, 0.4))
	draw_colored_polygon(body, VIOLET)
	# Tuulipuvun vinoraidat (turkoosi ja musta) leikattuna rungon muotoon.
	for band in [[0.12, 0.3, TURQ], [0.3, 0.38, BLACK], [0.76, 0.86, TURQ]]:
		var x0: float = b.position.x + b.size.x * band[0]
		var x1: float = b.position.x + b.size.x * band[1]
		var stripe := PackedVector2Array([Vector2(x0, b.end.y + 10), Vector2(x1, b.end.y + 10),
			Vector2(x1 + 170, b.position.y - 10), Vector2(x0 + 170, b.position.y - 10)])
		for poly in Geometry2D.intersect_polygons(stripe, body):
			draw_colored_polygon(poly, band[2])
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, Color(0, 0, 0, 0.6), 3.0)
	# Läppä yläosassa, NORMI-merkki ja kaksi solkea.
	var flap := Rect2(b.position + Vector2(30, 0), Vector2(b.size.x - 60, 88))
	var fp := _round_poly(flap, 30.0)
	draw_colored_polygon(fp, VIOLET.darkened(0.2))
	_dashed(fp, STITCH)
	draw_string(_hand, flap.position + Vector2(flap.size.x / 2.0 - 52, 50), "NORMI", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TURQ.lightened(0.35))
	for sx: float in [0.22, 0.78]:
		var bx := flap.position.x + flap.size.x * sx
		draw_rect(Rect2(bx - 10, flap.end.y - 30, 20, 50), BLACK)
		draw_rect(Rect2(bx - 15, flap.end.y - 4, 30, 22), Color(0.18, 0.18, 0.2))
		draw_rect(Rect2(bx - 9, flap.end.y + 1, 18, 12), Color(0.4, 0.4, 0.44))
	# Etutasku vetoketjuineen: taskut tämän sisällä.
	var pk := _pocket_rect()
	var pp := _round_poly(pk, 26.0)
	draw_colored_polygon(pp, POCKET)
	_dashed(pp, STITCH)
	var zy := pk.position.y + 26.0
	draw_line(Vector2(pk.position.x + 22, zy), Vector2(pk.end.x - 22, zy), Color(0.1, 0.1, 0.1), 5.0)
	for k in int((pk.size.x - 44) / 8.0):
		var zx := pk.position.x + 24 + k * 8.0
		draw_line(Vector2(zx, zy - 4), Vector2(zx, zy + 4), Color(0.75, 0.75, 0.78), 2.0)
	draw_rect(Rect2(pk.end.x - 70, zy - 8, 16, 24), Color(0.8, 0.8, 0.82))
	draw_rect(Rect2(pk.end.x - 67, zy + 14, 10, 18), BLACK)


## Heippalappu tekstiriveineen (vinossa, teippi yläreunassa); palauttaa lapun oikean reunan x:n.
func _note(at: Vector2, title: String, lines: Array, tilt_deg: float, paper := PAPER) -> float:
	var fs := 17
	var w := 0.0
	for l in lines:
		w = maxf(w, _hand.get_string_size(str(l), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	if title != "":
		w = maxf(w, _hand.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
	w = clampf(w + 34.0, 150.0, 320.0)
	var rows := lines.size() + (1 if title != "" else 0)
	var h := minf(26.0 + rows * 23.0, _bag.position.y - _panel.position.y - 70.0)
	var r := Rect2(at, Vector2(w, h))
	draw_set_transform(r.get_center(), deg_to_rad(tilt_deg), Vector2.ONE)
	var lr := Rect2(-r.size / 2.0, r.size)
	draw_rect(Rect2(lr.position + Vector2(5, 7), lr.size), Color(0, 0, 0, 0.35))
	draw_rect(lr, paper)
	var y := lr.position.y + 28.0
	if title != "":
		draw_string(_hand, Vector2(lr.position.x + 16, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
		y += 25.0
	for l in lines:
		if y > lr.end.y - 6.0:
			break
		draw_string(_hand, Vector2(lr.position.x + 16, y), str(l), HORIZONTAL_ALIGNMENT_LEFT, lr.size.x - 24.0, fs,
			INK.lightened(0.45) if str(l).begins_with("✔") else INK)
		y += 23.0
	draw_rect(Rect2(Vector2(-40, lr.position.y - 12), Vector2(80, 22)), Color(0.95, 0.95, 0.9, 0.7))  # teippi
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return r.end.x


func _tape(c: Vector2, tilt_deg: float) -> void:
	draw_set_transform(c, deg_to_rad(tilt_deg), Vector2.ONE)
	draw_rect(Rect2(-45, -11, 90, 22), Color(0.95, 0.95, 0.9, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Viimeinen tasku täyden repun kohdalla: "pohjalla" olevat tavarat nimeltä (eväät saa silti T-valikosta).
func _slot_item(i: int) -> Variant:
	if i == SLOTS - 1 and _items.size() > SLOTS:
		var names: Array[String] = []
		for k in range(SLOTS - 1, _items.size()):
			names.append("%s%s" % [_items[k].name, (" ×%d" % _items[k].count) if _items[k].get("count", 1) > 1 else ""])
		var rows: Array[String] = []
		for k in range(0, names.size(), 4):
			rows.append(", ".join(names.slice(k, k + 4)))
		return {"icon": _items[i].icon, "name": "Repun pohjalla %d tavaraa" % names.size(), "desc": "\n".join(rows),
			"count": 1}
	return _items[i] if i < _items.size() else null


## Tasku: tumma kangastasku tikkauksineen; esine pikselikuvakkeena, määrä oikeassa alakulmassa, eväillä pieni T.
func _draw_slot(r: Rect2, it: Variant, hover: bool) -> void:
	var inner := r.grow(-5.0)
	var pp := _round_poly(inner, 10.0)
	draw_colored_polygon(pp, Color(0.3, 0.16, 0.42) if hover else Color(0.16, 0.06, 0.24))
	_dashed(pp, Color(1.0, 0.85, 0.4) if hover else STITCH)
	if it == null:
		return
	draw_texture_rect(_icon(it.icon, it.get("tint", Color.WHITE)), inner.grow(-9.0), false)
	var n: int = it.get("count", 1)
	if n > 1:
		var s := str(n)
		var tw := ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_outlined(inner.end - Vector2(tw + 5.0, 5.0), s, 18, Color.WHITE)
	if it.get("food", false):
		_outlined(inner.position + Vector2(6, 18), "T", 13, TURQ.lightened(0.4))


## Vihjerivin tyylinen tumma pilleri: nimi valkoisella, kuvaus ja käyttö harmaalla.
func _tooltip(at: Vector2, it: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var lines := [it.name]
	if it.get("desc", "") != "":
		lines.append_array(it.desc.split("\n"))
	if it.get("use", "") != "":
		lines.append("Klikkaa: %s" % it.get("use_label", "käytä"))
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
	var r := Rect2(at, Vector2(w + 28.0, 14.0 + lines.size() * 23.0))
	if r.end.x > size.x:
		r.position.x = at.x - r.size.x - 36.0
	if r.end.y > size.y:
		r.position.y = size.y - r.size.y - 8.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.92)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.set_border_width_all(1)
	draw_style_box(sb, r)
	for i in lines.size():
		draw_string(font, r.position + Vector2(14, 26 + i * 23), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
			Color.WHITE if i == 0 else Color(0.72, 0.72, 0.72))


## Pyöristetty suorakulmio monikulmiona (piirto ja raitojen leikkaus).
func _round_poly(r: Rect2, rad: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) / 2.0)
	var cs := [[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI / 2.0],
		[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5]]
	for c in cs:
		for k in 7:
			out.append(c[0] + Vector2.from_angle(c[1] + k * (PI / 2.0) / 6.0) * rad)
	return out


func _offset(poly: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		out.append(q + d)
	return out


## Tikkaus: katkoviiva monikulmion reunan sisäpuolella.
func _dashed(poly: PackedVector2Array, col: Color) -> void:
	var c := Vector2.ZERO
	for q in poly:
		c += q
	c /= poly.size()
	var inner := PackedVector2Array()
	for q in poly:
		inner.append(q + (c - q).normalized() * 6.0)
	for i in inner.size():
		draw_dashed_line(inner[i], inner[(i + 1) % inner.size()], col, 1.5, 6.0)


func _outlined(at: Vector2, s: String, fs: int, col: Color) -> void:
	draw_string_outline(ThemeDB.fallback_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color.BLACK)
	draw_string(ThemeDB.fallback_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _portrait_rect() -> Rect2:
	return Rect2(_panel.position + Vector2(24, 24), PORTRAIT)


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
		_ptex.position = r.position
		_ptex.size = r.size


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
		"kuulokkeet":  # Valcon kuulokkeet: musta panta ja punaiset kupit
			_r(img, 4, 2, 8, 1, Color(0.12, 0.12, 0.14))
			_r(img, 3, 3, 1, 2, Color(0.12, 0.12, 0.14))
			_r(img, 12, 3, 1, 2, Color(0.12, 0.12, 0.14))
			_r(img, 2, 5, 2, 5, Color(0.12, 0.12, 0.14))
			_r(img, 12, 5, 2, 5, Color(0.12, 0.12, 0.14))
			_r(img, 1, 8, 4, 6, Color(0.75, 0.1, 0.1))
			_r(img, 11, 8, 4, 6, Color(0.75, 0.1, 0.1))
			_r(img, 2, 9, 1, 3, Color(0.95, 0.5, 0.45))
			_r(img, 12, 9, 1, 3, Color(0.95, 0.5, 0.45))
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
		"hiiva", "turbohiiva":
			var col := Color(0.15, 0.25, 0.6) if id == "turbohiiva" else Color(0.85, 0.75, 0.35)
			_r(img, 3, 5, 10, 8, col)
			_r(img, 3, 5, 10, 2, col.lightened(0.3))
			_r(img, 5, 8, 6, 3, Color(0.95, 0.95, 0.9))
			if id == "turbohiiva":
				_r(img, 6, 9, 4, 1, Color(0.9, 0.2, 0.15))
		"pontikka":
			_r(img, 7, 1, 2, 2, Color(0.45, 0.32, 0.2))
			_r(img, 6, 3, 4, 2, Color(0.8, 0.88, 0.92))
			_r(img, 5, 5, 6, 10, Color(0.8, 0.88, 0.92))
			_r(img, 6, 8, 4, 6, Color(0.92, 0.95, 0.98))
		"sokeri":
			_r(img, 4, 3, 8, 11, Color(0.96, 0.96, 0.94))
			_r(img, 4, 3, 8, 2, Color(0.2, 0.45, 0.8))
			_r(img, 5, 7, 6, 3, Color(0.2, 0.45, 0.8))
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
		"makkaraperunat":  # pahvivuoka, ranskalaiset ja makkaranpalat ketsupilla
			_r(img, 2, 8, 12, 6, Color(0.95, 0.93, 0.88))
			for k in 5:
				_r(img, 3 + k * 2, 4 + (k % 2), 1, 5, Color(0.95, 0.8, 0.25))
			_c(img, 6, 8, 1.6, Color(0.6, 0.25, 0.15))
			_c(img, 10, 8, 1.6, Color(0.6, 0.25, 0.15))
			_r(img, 4, 7, 8, 1, Color(0.85, 0.1, 0.08))
		"hampurilainen":
			_r(img, 3, 4, 10, 3, Color(0.85, 0.55, 0.2))
			_r(img, 3, 7, 10, 1, Color(0.3, 0.65, 0.2))
			_r(img, 3, 8, 10, 2, Color(0.45, 0.22, 0.12))
			_r(img, 3, 10, 10, 1, Color(0.95, 0.8, 0.15))
			_r(img, 3, 11, 10, 2, Color(0.85, 0.55, 0.2))
		"kuparipannu":  # vihertynyt kuparinen pontikkapannu
			_c(img, 8, 9, 5.5, Color(0.72, 0.42, 0.2))
			_c(img, 6.5, 7.5, 2.0, Color(0.85, 0.55, 0.3))
			_c(img, 10, 11, 1.8, Color(0.35, 0.6, 0.45))
			_r(img, 7, 2, 2, 3, Color(0.6, 0.35, 0.15))
			_r(img, 9, 2, 5, 1, Color(0.6, 0.35, 0.15))
		"kaasu":  # sininen kaasupullo
			_r(img, 5, 4, 6, 10, Color(0.15, 0.35, 0.75))
			_r(img, 6, 2, 4, 2, Color(0.6, 0.6, 0.62))
			_r(img, 6, 5, 1, 8, Color(0.35, 0.55, 0.9))
		"valokuva":  # mustavalkoinen valokuva valkoisin reunuksin
			_r(img, 3, 3, 10, 10, Color(0.95, 0.93, 0.88))
			_r(img, 4, 4, 8, 7, Color(0.45, 0.45, 0.45))
			_r(img, 5, 6, 4, 4, Color(0.25, 0.25, 0.25))
			_r(img, 6, 5, 2, 1, Color(0.3, 0.3, 0.3))
			_r(img, 9, 8, 2, 2, Color(0.7, 0.7, 0.7))
		"kukat":  # ruusukimppu paperissa
			_r(img, 7, 7, 2, 8, Color(0.2, 0.55, 0.2))
			_c(img, 5, 5, 2.2, Color(0.9, 0.15, 0.25))
			_c(img, 10, 5, 2.2, Color(0.95, 0.3, 0.45))
			_c(img, 7.5, 3, 2.2, Color(0.85, 0.1, 0.2))
			_r(img, 5, 10, 6, 4, Color(0.95, 0.92, 0.8))
		"taimet":  # tomaatintaimi ruukussa
			_r(img, 5, 10, 6, 5, Color(0.65, 0.35, 0.2))
			_r(img, 7, 4, 2, 6, Color(0.25, 0.55, 0.2))
			_c(img, 5, 6, 2.0, Color(0.3, 0.6, 0.25))
			_c(img, 11, 5, 2.0, Color(0.3, 0.6, 0.25))
		"kekkonen":  # rintamerkki
			_c(img, 8, 8, 5.5, Color(0.85, 0.7, 0.2))
			_c(img, 8, 8, 4.0, Color(0.15, 0.25, 0.55))
			_c(img, 8, 7, 1.8, Color(0.95, 0.85, 0.7))
		"hopeat":  # mustuneita hopearahoja ja lusikka
			_c(img, 6, 9, 3.2, Color(0.6, 0.6, 0.62))
			_c(img, 10, 10, 3.2, Color(0.5, 0.5, 0.52))
			_c(img, 8, 6, 3.0, Color(0.72, 0.72, 0.74))
			_c(img, 7, 5, 1.0, Color(0.9, 0.9, 0.92))
			_r(img, 11, 2, 1, 6, Color(0.65, 0.65, 0.68))
			_c(img, 11.5, 2, 1.6, Color(0.65, 0.65, 0.68))
		"kirves":  # ruosteinen rautakautinen kirves: puuton terä ja hela
			for i in 9:
				_r(img, 3 + i, 12 - i, 2, 2, Color(0.45, 0.28, 0.15))
			_r(img, 9, 2, 5, 6, Color(0.52, 0.3, 0.16))
			_r(img, 12, 2, 2, 8, Color(0.62, 0.38, 0.2))
			_r(img, 10, 4, 2, 2, Color(0.35, 0.2, 0.1))
		"suomalmi":  # ruosteenruskea möykky
			_c(img, 8, 9, 5.0, Color(0.5, 0.25, 0.1))
			_c(img, 6.5, 7.5, 2.0, Color(0.68, 0.36, 0.14))
			_c(img, 10, 11, 1.5, Color(0.32, 0.15, 0.07))
		"kuona":  # musta, kuplainen kuona
			_c(img, 8, 9, 5.0, Color(0.16, 0.14, 0.13))
			for o in [Vector2(6, 7), Vector2(10, 8), Vector2(8, 11), Vector2(11, 11)]:
				_c(img, o.x, o.y, 1.0, Color(0.05, 0.05, 0.05))
			_c(img, 6, 10, 1.0, Color(0.45, 0.22, 0.1))
		"avain":  # ruosteinen vanha avain
			_c(img, 4.5, 8, 3.2, Color(0.55, 0.32, 0.18))
			_c(img, 4.5, 8, 1.4, Color(0, 0, 0, 0))
			_r(img, 7, 7, 8, 2, Color(0.55, 0.32, 0.18))
			_r(img, 12, 9, 1, 2, Color(0.55, 0.32, 0.18))
			_r(img, 14, 9, 1, 3, Color(0.55, 0.32, 0.18))
		"kirja":  # tilikirja: punaruskeat kannet ja kellastuneet sivut
			_r(img, 3, 2, 10, 12, Color(0.4, 0.13, 0.1))
			_r(img, 4, 3, 8, 10, Color(0.92, 0.86, 0.68))
			_r(img, 5, 5, 6, 1, Color(0.4, 0.35, 0.3))
			_r(img, 5, 7, 5, 1, Color(0.4, 0.35, 0.3))
			_r(img, 5, 9, 6, 1, Color(0.4, 0.35, 0.3))
		"lipas":  # ruosteinen rahalipas
			_r(img, 2, 5, 12, 8, Color(0.45, 0.3, 0.2))
			_r(img, 2, 5, 12, 2, Color(0.55, 0.38, 0.25))
			_r(img, 7, 8, 2, 2, Color(0.85, 0.7, 0.2))
		"markat":  # setelinippu
			_r(img, 2, 4, 12, 7, Color(0.55, 0.62, 0.45))
			_r(img, 3, 6, 10, 7, Color(0.65, 0.72, 0.55))
			_c(img, 8, 9.5, 2.0, Color(0.4, 0.48, 0.35))
			_r(img, 7, 4, 2, 9, Color(0.8, 0.2, 0.15))
		"sp_moottori":  # napamoottori: musta napa ja pinnojen reiät
			_c(img, 8, 8, 6.5, Color(0.14, 0.14, 0.15))
			_c(img, 8, 8, 4.0, Color(0.3, 0.3, 0.32))
			_c(img, 8, 8, 1.6, Color(0.7, 0.7, 0.72))
			for k in 8:
				var a := k * TAU / 8.0
				_r(img, int(8 + cos(a) * 5.3), int(8 + sin(a) * 5.3), 1, 1, Color(0.7, 0.7, 0.72))
		"sp_akku":  # Makitan turkoosi akku
			_r(img, 2, 5, 12, 8, Color(0.0, 0.55, 0.55))
			_r(img, 2, 5, 4, 8, Color(0.12, 0.12, 0.13))
			_r(img, 8, 3, 4, 2, Color(0.12, 0.12, 0.13))
			_r(img, 7, 8, 5, 1, Color(0.9, 0.95, 0.95))
		"sp_ohjain":  # ohjainkotelo ja keltainen kaasukahva
			_r(img, 2, 7, 9, 6, Color(0.14, 0.14, 0.15))
			_r(img, 3, 8, 3, 1, Color(0.7, 0.7, 0.7))
			_r(img, 9, 2, 6, 3, Color(0.85, 0.75, 0.1))
			_r(img, 11, 5, 1, 3, Color(0.05, 0.05, 0.05))
		"sp_johdot":  # johtonippu
			for i in 4:
				var col: Color = [Color(0.85, 0.1, 0.1), Color(0.05, 0.05, 0.05), Color(0.1, 0.25, 0.8), Color(0.9, 0.8, 0.1)][i]
				for x in 12:
					_r(img, 2 + x, 4 + i * 2 + int(sin(x * 0.7 + i) * 1.2), 1, 1, col)
			_r(img, 13, 3, 2, 10, Color(0.75, 0.55, 0.2))
		"sp_ruuvit":
			for p in [Vector2i(3, 3), Vector2i(9, 5), Vector2i(5, 10)]:
				_r(img, p.x, p.y, 4, 2, Color(0.75, 0.75, 0.78))
				_r(img, p.x + 1, p.y + 2, 2, 3, Color(0.6, 0.6, 0.63))
		"sp_teippi", "sp_sahkoteippi":  # teippirulla: harmaa jeesusteippi tai sininen sähköteippi
			var col := Color(0.62, 0.63, 0.6) if id == "sp_teippi" else Color(0.1, 0.2, 0.75)
			_c(img, 8, 8, 6.0, col)
			_c(img, 8, 8, 2.8, Color(0.85, 0.75, 0.55))
			_c(img, 8, 8, 1.8, Color(0, 0, 0, 0))
			_r(img, 13, 9, 2, 5, col.darkened(0.2))
		"sp_nippu":  # nippusiteitä nipussa
			for i in 4:
				_r(img, 3 + i * 3, 2, 1, 12, Color(0.95, 0.95, 0.92))
				_r(img, 2 + i * 3, 2, 3, 2, Color(0.85, 0.85, 0.82))
		"sp_rautalanka":  # rautalankakerä
			for k in 3:
				_c(img, 8, 8, 6.0 - k * 1.6, Color(0.55, 0.55, 0.58))
				_c(img, 8, 8, 5.3 - k * 1.6, Color(0, 0, 0, 0))
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
