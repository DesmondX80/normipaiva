extends CanvasLayer
## Savusaunan korjaus (Santun homma "saunakorjaus"), hiirellä pelattavat vaiheet piirrettyinä kuvina:
## "kivet"   – kiuaskivien keräys rannan kivikasasta: pyöreät kelpaavat, liuskekivi halkeaa kuumassa (ei kelpaa).
## "kiuas"   – rapautuneet kivet pois kiukaasta ja uudet tilalle: isot alariviin, pienet päälle (ilma kulkee).
## "lauteet" – lahot lauteiden laudat irti, uudet tilalle ja kaksi naulaa kumpaankin: osu naulan kantaan; vino isku
##             taivuttaa naulan (oikea nappi vetää pois), ohi lyönti osuu peukaloon.
## "terva"   – hirsiseinän tervaus: vedä hiirellä (vasen nappi pohjassa); liian nopea veto valuu (oikea nappi pyyhkii).
## "luukku"  – jumittunut savuluukku auki A/D vuorotellen, sitten vino ovi: nosta W:llä vihreälle ja E kiinnittää,
##             lopuksi kolme saranaruuvia kiinni pyörittämällä hiirtä ympyrää.
## F / Esc keskeyttää (vaiheen saa tehdä uudestaan). finished(ok) kertoo, valmistuiko vaihe.

signal finished(ok: bool)
signal comment(text: String)
signal thumb

const NEED_STONES := 6
const LINES := {
	"kivet": ["Pyöreitä ja tummia. Liuskekivi halkeaa kiukaassa.", "Oliviinidiabaasia ois paras, mutta rantakivikin käy."],
	"kiuas": ["Rapautuneet pois, ne murenee käsiin.", "Isot alas, pienet päälle. Ilman pitää kulkea."],
	"lauteet": ["Lahot laudat pois. Naulat on purkissa.", "Naula päähän, ei peukaloon."],
	"terva": ["Ohuelti ja tasaisesti. Terva valuu, jos hätäilee.", "Kunnon tervaus kestää kymmenen vuotta."],
	"luukku": ["Räppänä on ruostunu kiinni. Heiluta sitä.", "Ovi roikkuu. Nosta ja kiristä saranat."],
	"liuske": ["Liuskekivi! Se halkeaa kuumassa. Pois.", "Ei tuollaista, kato kerroksia."],
	"vaarin": ["Isot alas! Muuten ilma ei kulje.", "Alarivi ensin täyteen."],
	"peukalo": ["Peukalo ei oo naula!", "Ei sitä noin hakata!"],
	"vino": ["Naula meni vinoon. Pois ja uus.", "Banaani. Vedä pois."],
	"valuma": ["Valuu! Pyyhi pois.", "Ohuelti, ohuelti."],
}

var mode := "kivet"
var drunk := 0.0
var thumbs := 0

var _root: Control
var _info: Label
var _keys: Control
var _tip: Label
var _done := false
var _t := 0.0
var _mouse := Vector2.ZERO
var _area := Rect2()
# kivet
var _stones: Array = []  # {p, r, good, taken}
var _got := 0
# kiuas
var _slots: Array = []  # {rect, row, old: int (iskuja jäljellä), stone: "" / "iso" / "pieni"}
var _bag: Array = []  # "iso" / "pieni"
var _held := ""
# lauteet
var _planks: Array = []  # {s: laho/tyhja/uusi/valmis, pry, nails: [syvyys], bent: [bool]}
# terva
var _paint := PackedFloat32Array()
const TW := 48
const TH := 6
var _drips: Array = []  # {p, len}
var _last_paint := Vector2.INF
# luukku
var _phase := "luukku"
var _wiggle := 0
var _last_key := ""
var _lift := 0.0
var _screws: Array = [0.0, 0.0, 0.0]
var _screw_i := 0
var _last_ang := 0.0


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_root)
	_root.gui_input.connect(_gui)
	add_child(_root)
	_info = _label(24, 40.0, false)
	_keys = preload("res://scripts/hint_bar.gd").new()  # näppäinohjeet hattuina, näppäimet asetuksista
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_tip = _label(22, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	comment.connect(func(t: String) -> void: _tip.text = t)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup.call_deferred()


func _label(size: int, y: float, bottom: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.anchor_right = 1.0
	if bottom:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _setup() -> void:
	var sz := _root.size
	_area = Rect2(sz / 2.0 - Vector2(440, 250), Vector2(880, 500))
	match mode:
		"kivet":
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var goods := 9
			for i in 13:
				for tries in 40:
					var p := _area.position + Vector2(rng.randf_range(70, _area.size.x - 70), rng.randf_range(90, _area.size.y - 140))
					var ok := p.distance_to(_area.position + Vector2(_area.size.x - 75, 55)) > 110.0  # ei sangon alle
					for s in _stones:
						if p.distance_to(s.p) < 85.0:
							ok = false
					if ok:
						_stones.append({"p": p, "r": rng.randf_range(26, 38), "good": i < goods, "taken": false, "rot": rng.randf() * TAU})
						break
		"kiuas":
			var x0 := _area.position.x + 250.0
			for row in 2:
				for k in 3:
					var w := 120.0 if row == 0 else 90.0
					var rect := Rect2(Vector2(x0 + k * 130.0 + (0.0 if row == 0 else 15.0), _area.position.y + 340.0 - row * 110.0), Vector2(w, 90.0 if row == 0 else 70.0))
					_slots.append({"rect": rect, "row": row, "old": 2, "stone": ""})
			_bag = ["iso", "iso", "iso", "pieni", "pieni", "pieni"]
			_bag.shuffle()
		"lauteet":
			for i in 3:
				_planks.append({"s": "laho", "pry": 0, "nails": [0.0, 0.0], "bent": [false, false]})
		"terva":
			_paint.resize(TW * TH)
			_paint.fill(0.0)
	comment.emit((LINES[mode] as Array).pick_random())


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_mouse = _root.get_local_mouse_position() + Vector2(sin(_t * 5.0), cos(_t * 4.3)) * drunk * 18.0
	_root.queue_redraw()
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish(false)
		return
	match mode:
		"terva":
			_terva_tick(delta)
		"luukku":
			_luukku_tick(delta)
	_info.text = _status()
	_keys.set_text("%s lopeta" % Settings.cap("mount"))


func _status() -> String:
	match mode:
		"kivet":
			return "Kiuaskivet rannalta: %d / %d · klikkaa sopivia kiviä" % [_got, NEED_STONES]
		"kiuas":
			var old := _slots.filter(func(s): return s.old > 0).size()
			if old > 0:
				return "Rapautuneita kiviä pois: %d jäljellä · klikkaa" % old
			return "Uudet kivet kiukaaseen: %d / 6 · ota kivi ja klikkaa paikka" % _slots.filter(func(s): return s.stone != "").size()
		"lauteet":
			return "Lauteiden laudat: %d / 3 valmiina · vasen nappi lyö, oikea vetää vinon naulan" % _planks.filter(func(p): return p.s == "valmis").size()
		"terva":
			return "Tervaus: %d %% · valumia %d · vasen nappi pohjassa tervaa, oikea pyyhkii valuman" % [roundi(_coverage() * 100.0), _drips.size()]
		"luukku":
			if _phase == "luukku":
				return "Savuluukku jumissa: %s / %s vuorotellen (%d / 14)" % [Settings.action_key("left"), Settings.action_key("right"), _wiggle]
			if _phase == "ovi":
				return "Ovi roikkuu: pidä %s pohjassa nostaaksesi, %s kiinnittää kun vihreällä" % [Settings.action_key("forward"),
					Settings.action_key("interact")]
			return "Saranaruuvi %d / 3: pyöritä hiirtä myötäpäivään" % (_screw_i + 1)
	return ""


func _gui(ev: InputEvent) -> void:
	if _done or not (ev is InputEventMouseButton) or not ev.pressed:
		return
	var left: bool = ev.button_index == MOUSE_BUTTON_LEFT
	var right: bool = ev.button_index == MOUSE_BUTTON_RIGHT
	match mode:
		"kivet":
			if left:
				_click_stone()
		"kiuas":
			if left:
				_click_kiuas()
		"lauteet":
			if left:
				_hammer()
			elif right:
				_pull_nail()
		"terva":
			if right:
				_wipe()


func _finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(ok)
	queue_free()


# --- Kivet --------------------------------------------------------------------

func _click_stone() -> void:
	for s in _stones:
		if not s.taken and _mouse.distance_to(s.p) < s.r:
			s.taken = true
			if s.good:
				_got += 1
				Sfx.play("rattle", -6.0, 0.8)
				if _got >= NEED_STONES:
					comment.emit("Riittää! Kanna ne saunalle.")
					get_tree().create_timer(0.8).timeout.connect(_finish.bind(true))
			else:
				Sfx.play("rattle", -4.0, 1.4)
				comment.emit((LINES.liuske as Array).pick_random())
			return


# --- Kiuas --------------------------------------------------------------------

func _bag_rect(i: int) -> Rect2:
	var big: bool = _bag[i] == "iso"
	return Rect2(_area.position + Vector2(50, 70 + i * 68), Vector2(110 if big else 80, 56 if big else 44))


func _click_kiuas() -> void:
	var old_left := _slots.filter(func(s): return s.old > 0).size()
	for s in _slots:
		if (s.rect as Rect2).has_point(_mouse):
			if s.old > 0:
				s.old -= 1
				Sfx.play("rattle", -6.0, 0.6 if s.old > 0 else 0.5)
				if s.old == 0 and old_left == 1:
					comment.emit("Vanhat pois. Nyt uudet: isot alas, pienet päälle.")
				return
			if old_left > 0 or _held == "" or s.stone != "":
				return
			var bottom_full := _slots.filter(func(q): return q.row == 0 and q.stone == "").is_empty()
			if (_held == "iso" and s.row != 0) or (_held == "pieni" and (s.row == 0 or not bottom_full)):
				comment.emit((LINES.vaarin as Array).pick_random())
				Sfx.play("rattle", -8.0, 1.2)
				return
			s.stone = _held
			_held = ""
			Sfx.play("rattle", -4.0, 0.9)
			if _slots.filter(func(q): return q.stone == "").is_empty():
				comment.emit("Kiuas on kunnossa! Ilma kulkee kivien välistä.")
				get_tree().create_timer(0.8).timeout.connect(_finish.bind(true))
			return
	if old_left == 0 and _held == "":
		for i in _bag.size():
			if _bag_rect(i).has_point(_mouse):
				_held = _bag[i]
				_bag.remove_at(i)
				return


# --- Lauteet ------------------------------------------------------------------

func _plank_rect(i: int) -> Rect2:
	return Rect2(_area.position + Vector2(90, 90 + i * 120), Vector2(700, 80))


func _nail_pos(i: int, k: int) -> Vector2:
	var r := _plank_rect(i)
	return r.position + Vector2(60 if k == 0 else r.size.x - 60, r.size.y / 2.0)


func _hammer() -> void:
	for i in _planks.size():
		var pl: Dictionary = _planks[i]
		var r := _plank_rect(i)
		if pl.s == "laho" and r.has_point(_mouse):
			pl.pry += 1
			Sfx.play("rattle", -6.0, 0.5)
			if pl.pry >= 3:
				pl.s = "tyhja"
			return
		if pl.s == "tyhja" and r.has_point(_mouse):
			pl.s = "uusi"
			Sfx.play("pickup", -6.0, 0.8)
			return
		if pl.s == "uusi":
			for k in 2:
				var np := _nail_pos(i, k)
				var d := _mouse.distance_to(np)
				if pl.nails[k] >= 1.0 or pl.bent[k]:
					continue
				if d < 9.0:
					pl.nails[k] = minf(1.0, pl.nails[k] + 0.34)
					Sfx.play("punch", -6.0, 1.4)
					if pl.nails[0] >= 1.0 and pl.nails[1] >= 1.0:
						pl.s = "valmis"
						if _planks.filter(func(p): return p.s != "valmis").is_empty():
							comment.emit("Lauteet kunnossa! Istumaan kelpaa.")
							get_tree().create_timer(0.8).timeout.connect(_finish.bind(true))
					return
				if d < 20.0:
					pl.bent[k] = true
					Sfx.play("punch", -8.0, 0.9)
					comment.emit((LINES.vino as Array).pick_random())
					return
				if _mouse.distance_to(np + Vector2(0, 26)) < 16.0:
					thumbs += 1
					thumb.emit()
					Sfx.play("grunt", -2.0, 1.1)
					comment.emit((LINES.peukalo as Array).pick_random())
					return
	Sfx.play("punch", -12.0, 0.8)


func _pull_nail() -> void:
	for i in _planks.size():
		for k in 2:
			if _planks[i].bent[k] and _mouse.distance_to(_nail_pos(i, k)) < 26.0:
				_planks[i].bent[k] = false
				_planks[i].nails[k] = 0.0
				Sfx.play("rattle", -8.0, 1.5)
				return


# --- Terva --------------------------------------------------------------------

func _wall() -> Rect2:
	return Rect2(_area.position + Vector2(40, 60), Vector2(_area.size.x - 80, 360))


func _terva_tick(delta: float) -> void:
	var w := _wall()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and w.has_point(_mouse):
		var speed := 0.0 if _last_paint == Vector2.INF else _mouse.distance_to(_last_paint) / maxf(delta, 0.001)
		_last_paint = _mouse
		var cw := w.size.x / TW
		var ch := w.size.y / TH
		var cx := int((_mouse.x - w.position.x) / cw)
		var cy := int((_mouse.y - w.position.y) / ch)
		for dx in range(-1, 2):
			var x := cx + dx
			if x >= 0 and x < TW and cy >= 0 and cy < TH:
				_paint[cy * TW + x] = minf(1.0, _paint[cy * TW + x] + delta * 4.0)
		if speed > 1100.0 and randf() < delta * 6.0 and _drips.size() < 6:
			_drips.append({"p": _mouse, "len": 6.0})
			comment.emit((LINES.valuma as Array).pick_random())
	else:
		_last_paint = Vector2.INF
	for d in _drips:
		d.len = minf(60.0, d.len + delta * 12.0)
	if _coverage() >= 0.92 and _drips.is_empty():
		comment.emit("Seinä tervattu! Tuoksuu ihan oikealta saunalta.")
		_done = true
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			_done = false
			_finish(true))


func _coverage() -> float:
	if _paint.is_empty():
		return 0.0
	var n := 0
	for v in _paint:
		if v >= 0.6:
			n += 1
	return float(n) / _paint.size()


func _wipe() -> void:
	for i in _drips.size():
		var d: Dictionary = _drips[i]
		if Rect2(d.p - Vector2(12, 0), Vector2(24, d.len + 10)).has_point(_mouse):
			_drips.remove_at(i)
			Sfx.play("cloth", -8.0, 1.2)
			return


# --- Luukku ja ovi -------------------------------------------------------------

func _luukku_tick(delta: float) -> void:
	match _phase:
		"luukku":
			for key in ["left", "right"]:
				if Input.is_action_just_pressed(key):
					if key != _last_key:
						_wiggle += 1
						Sfx.play("rattle", -8.0, 0.6 + _wiggle * 0.03)
					_last_key = key
			if _wiggle >= 14:
				_phase = "ovi"
				comment.emit("Räppänä aukeaa! Nyt ovi: nosta ja kiinnitä.")
		"ovi":
			_lift = clampf(_lift + (0.55 if Input.is_action_pressed("forward") else -0.8) * delta, 0.0, 1.0)
			if Input.is_action_just_pressed("interact"):
				if _lift > 0.62 and _lift < 0.82:
					_phase = "ruuvit"
					Sfx.play("pickup", -6.0, 0.7)
					comment.emit("Ovi suorassa. Saranaruuvit kiinni.")
				else:
					comment.emit("Liian %s! Nosta vihreälle." % ("alhaalla" if _lift <= 0.62 else "ylhäällä"))
		"ruuvit":
			var c := _area.position + Vector2(_area.size.x / 2.0, 260)
			var a := (_mouse - c).angle()
			var da := wrapf(a - _last_ang, -PI, PI)
			_last_ang = a
			if da > 0.0 and da < 0.6 and _mouse.distance_to(c) > 30.0:
				_screws[_screw_i] += da / (TAU * 3.0)
				if _screws[_screw_i] >= 1.0:
					_screws[_screw_i] = 1.0
					Sfx.play("rattle", -6.0, 1.3)
					_screw_i += 1
					if _screw_i >= 3:
						comment.emit("Ovi ja luukku kunnossa! Savu menee nyt räppänästä.")
						_done = true
						get_tree().create_timer(0.8).timeout.connect(func() -> void:
							_done = false
							_finish(true))


# --- Piirto -------------------------------------------------------------------

const SOOT := Color(0.16, 0.12, 0.09)
const LOG := Color(0.55, 0.4, 0.25)
const IRON := Color(0.17, 0.17, 0.19)


func _draw_root() -> void:
	var font := ThemeDB.fallback_font
	_root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0, 0, 0, 0.55))
	match mode:
		"kivet":
			_draw_kivet(font)
		"kiuas":
			_draw_kiuas(font)
		"lauteet":
			_draw_lauteet(font)
		"terva":
			if _paint.size() < TW * TH:
				return  # seinä alustetaan ensimmäisen ruudun jälkeen (_setup)
			_draw_terva(font)
		"luukku":
			_draw_luukku(font)


## Kehys: tumma puukehys ja varjo kaikille näkymille.
func _frame(inner: Color) -> void:
	_box(_area.grow(14.0), Color(0.12, 0.09, 0.07), 22, Color(0, 0, 0, 0.5), 18)
	_box(_area, inner, 16)


func _draw_kivet(font: Font) -> void:
	_frame(Color(0.72, 0.64, 0.48))
	var shore := _area.position.y + _area.size.y - 100.0
	# Hiekka: vaaleampi yläreuna, pikkukivet ja heinätupsut.
	for k in 6:
		_root.draw_rect(Rect2(Vector2(_area.position.x, _area.position.y + k * 24), Vector2(_area.size.x, 24)),
			Color(0.75, 0.68, 0.52).darkened(0.02 * k))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 160:
		var p := _area.position + Vector2(rng.randf() * _area.size.x, rng.randf() * (shore - _area.position.y))
		_root.draw_circle(p, rng.randf_range(1.2, 3.2), Color(0.55, 0.5, 0.42, 0.7))
	for k in 9:
		var g := _area.position + Vector2(rng.randf() * _area.size.x, rng.randf() * 60.0 + 10.0)
		for b in 5:
			_root.draw_line(g, g + Vector2(-8 + b * 4, -14 - rng.randf() * 10), Color(0.42, 0.55, 0.25), 2.0)
	# Järvi laineineen ja kimalluksineen.
	var water := Rect2(Vector2(_area.position.x, shore), Vector2(_area.size.x, _area.end.y - shore))
	_box(water, Color(0.32, 0.47, 0.58), 0)
	_root.draw_rect(Rect2(water.position, Vector2(water.size.x, 10)), Color(0.85, 0.9, 0.95, 0.35))
	for k in 5:
		var y := shore + 22 + k * 16
		var pts := PackedVector2Array()
		for i in 40:
			var x := _area.position.x + i * _area.size.x / 39.0
			pts.append(Vector2(x, y + sin(x * 0.04 + _t * 1.6 + k) * 3.0))
		_root.draw_polyline(pts, Color(0.75, 0.85, 0.95, 0.35), 2.0)
	# Kivet: varjo, kiven perusmuoto, alapuolen tummuus, kiilto ja täplät.
	for s in _stones:
		if s.taken:
			continue
		var p: Vector2 = s.p
		var r: float = s.r
		_ellipse(p + Vector2(4, r * 0.6), Vector2(r * 1.1, r * 0.35), Color(0, 0, 0, 0.25))
		if s.good:
			_ellipse(p, Vector2(r, r * 0.85), Color(0.26, 0.28, 0.3))
			_ellipse(p + Vector2(0, r * 0.25), Vector2(r * 0.9, r * 0.55), Color(0.2, 0.21, 0.23))
			_ellipse(p + Vector2(-r * 0.15, -r * 0.15), Vector2(r * 0.75, r * 0.55), Color(0.34, 0.36, 0.38))
			_ellipse(p + Vector2(-r * 0.35, -r * 0.35), Vector2(r * 0.25, r * 0.15), Color(1, 1, 1, 0.25))
			for k in 6:
				_root.draw_circle(p + Vector2(cos(k * 1.9 + s.rot), sin(k * 2.7 + s.rot)) * r * 0.55, 1.8, Color(0.45, 0.55, 0.42, 0.7))
		else:
			for layer in 3:
				var pts := PackedVector2Array()
				for k in 6:
					var a: float = k * TAU / 6.0 + s.rot
					pts.append(p + Vector2(0, -layer * 4.0) + Vector2(cos(a) * r * (1.3 - layer * 0.12), sin(a) * r * 0.45))
				_root.draw_colored_polygon(pts, Color(0.5, 0.49, 0.45).darkened(0.12 * (2 - layer)))
			for k in 3:
				_root.draw_line(p + Vector2(-r * 0.9, -8 + k * 5), p + Vector2(r * 0.9, -6 + k * 5), Color(0.36, 0.35, 0.32), 1.5)
	# Kerätyt kivet sankossa oikeassa yläkulmassa.
	var bucket := _area.position + Vector2(_area.size.x - 120, 26)
	_box(Rect2(bucket, Vector2(90, 56)), Color(0.6, 0.62, 0.64), 8)
	for k in _got:
		_ellipse(bucket + Vector2(18 + (k % 3) * 26, 18 + (k / 3) * 18), Vector2(12, 9), Color(0.28, 0.3, 0.32))
	_root.draw_string(font, bucket + Vector2(0, 76), "%d / %d" % [_got, NEED_STONES], HORIZONTAL_ALIGNMENT_CENTER, 90, 18, Color(0.15, 0.12, 0.08))
	_root.draw_string(font, _area.position + Vector2(24, 40), "Rannan kivikasa", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.25, 0.2, 0.12))


## Savuinen hirsiseinä (saunan sisällä).
func _soot_logs(r: Rect2, col: Color) -> void:
	var lh := 46.0
	var y := r.position.y
	var i := 0
	while y < r.end.y:
		var h := minf(lh, r.end.y - y)
		var band := Rect2(Vector2(r.position.x, y), Vector2(r.size.x, h))
		_root.draw_rect(band, col.darkened(0.08 * (i % 2)))
		_root.draw_rect(Rect2(band.position, Vector2(band.size.x, 6)), Color(1, 1, 1, 0.05))
		_root.draw_rect(Rect2(Vector2(band.position.x, band.end.y - 5), Vector2(band.size.x, 5)), Color(0, 0, 0, 0.3))
		y += lh
		i += 1


func _stone(c: Vector2, r: Vector2, base: Color) -> void:
	_ellipse(c + Vector2(3, r.y * 0.4), r * Vector2(1.0, 0.5), Color(0, 0, 0, 0.3))
	_ellipse(c, r, base)
	_ellipse(c + Vector2(0, r.y * 0.3), r * Vector2(0.9, 0.55), base.darkened(0.2))
	_ellipse(c - r * 0.18, r * 0.7, base.lightened(0.08))
	_ellipse(c - r * 0.4, r * Vector2(0.25, 0.18), Color(1, 1, 1, 0.22))


func _draw_kiuas(font: Font) -> void:
	_frame(SOOT)
	_soot_logs(_area.grow(-6.0), Color(0.22, 0.16, 0.11))
	# Rautakiuas: kivitila, niitit, tulipesän luukku ja hehkuva tuli.
	var body := Rect2(_area.position + Vector2(220, 120), Vector2(440, 340))
	_box(Rect2(body.position + Vector2(8, 10), body.size), Color(0, 0, 0, 0.4), 12)
	_box(body, IRON, 12)
	_box(body.grow(-12.0), Color(0.1, 0.1, 0.11), 8)  # kivitila
	for k in 9:
		for edge in [body.position.y + 6.0, body.end.y - 6.0]:
			_root.draw_circle(Vector2(body.position.x + 20 + k * 50, edge), 3.0, Color(0.32, 0.32, 0.35))
	var door := Rect2(Vector2(body.position.x + 140, body.end.y + 4), Vector2(160, 46))
	_box(door, Color(0.2, 0.2, 0.22), 6)
	var flick := 0.6 + 0.4 * sin(_t * 9.0) * sin(_t * 5.3)
	for k in 4:
		_root.draw_rect(Rect2(door.position + Vector2(14 + k * 36, 10), Vector2(24, 26)), Color(1.0, 0.45 + 0.2 * flick, 0.1, 0.55 + 0.4 * flick))
	_root.draw_rect(Rect2(door.position + Vector2(0, -4), Vector2(door.size.x, 4)), Color(1.0, 0.5, 0.15, 0.25 * flick))
	# Kivipaikat: rapautuneet murenevat, uudet kivet varjostettuina, tyhjät katkoviivalla.
	for s in _slots:
		var r: Rect2 = s.rect
		var c := r.get_center()
		if s.old > 0:
			_stone(c, r.size / 2.0, Color(0.55, 0.5, 0.44).darkened(0.18 * (2 - s.old)))
			_root.draw_line(c + Vector2(-r.size.x * 0.35, -r.size.y * 0.2), c + Vector2(r.size.x * 0.1, r.size.y * 0.25), SOOT, 2.0)
			_root.draw_line(c + Vector2(r.size.x * 0.1, r.size.y * 0.25), c + Vector2(r.size.x * 0.3, r.size.y * 0.05), SOOT, 2.0)
			for k in 4:
				_root.draw_circle(c + Vector2(-20 + k * 13, r.size.y * 0.45), 2.5, Color(0.5, 0.45, 0.4))
		elif s.stone != "":
			_stone(c, r.size / 2.0 * (1.0 if s.stone == "iso" else 0.85), Color(0.3, 0.32, 0.34))
		else:
			for k in 12:
				var a := k * TAU / 12.0
				_root.draw_arc(c, minf(r.size.x, r.size.y) * 0.45, a, a + 0.3, 4, Color(1, 1, 1, 0.25), 2.0)
	# Uudet kivet puusankossa.
	_box(Rect2(_area.position + Vector2(30, 40), Vector2(160, 440)), Color(0.42, 0.3, 0.18), 14, Color(0, 0, 0, 0.4), 8)
	for k in 3:
		_root.draw_rect(Rect2(_area.position + Vector2(30, 80 + k * 150), Vector2(160, 6)), Color(0.3, 0.3, 0.32))
	for i in _bag.size():
		var br := _bag_rect(i)
		_stone(br.get_center(), br.size / 2.0, Color(0.3, 0.32, 0.35))
	_root.draw_string(font, _area.position + Vector2(30, 32), "Uudet kivet", HORIZONTAL_ALIGNMENT_CENTER, 160, 18, Color(0.95, 0.9, 0.8))
	if _held != "":
		var hs := Vector2(110, 56) if _held == "iso" else Vector2(80, 44)
		_stone(_mouse, hs / 2.0, Color(0.33, 0.35, 0.38))


func _draw_lauteet(_font: Font) -> void:
	_frame(SOOT)
	_soot_logs(_area.grow(-6.0), Color(0.24, 0.18, 0.12))
	# Laudetta kantavat palkit.
	for x in [_area.position.x + 150, _area.position.x + _area.size.x - 150]:
		_box(Rect2(Vector2(x - 22, _area.position.y + 70), Vector2(44, _area.size.y - 120)), Color(0.32, 0.22, 0.13), 6)
	for i in _planks.size():
		var pl: Dictionary = _planks[i]
		var r := _plank_rect(i)
		match pl.s:
			"laho":
				var lr := Rect2(r.position + Vector2(0, -pl.pry * 4.0), r.size)
				_plank(lr, Color(0.4, 0.37, 0.29), i)
				var rng := RandomNumberGenerator.new()
				rng.seed = 31 + i * 7
				for k in 6:  # lahot laikut, sammal ja madonreiät
					var mp := lr.position + Vector2(rng.randf_range(40, lr.size.x - 40), rng.randf_range(18, lr.size.y - 18))
					_ellipse(mp, Vector2(rng.randf_range(20, 44), rng.randf_range(8, 14)), Color(0.22, 0.27, 0.14, 0.7))
				for k in 4:
					var hp := lr.position + Vector2(rng.randf_range(40, lr.size.x - 40), rng.randf_range(20, lr.size.y - 20))
					_ellipse(hp, Vector2(rng.randf_range(8, 18), rng.randf_range(5, 9)), Color(0.12, 0.1, 0.07, 0.85))
				var c0 := lr.position + Vector2(rng.randf_range(60, 200), rng.randf_range(15, 30))
				_root.draw_polyline(PackedVector2Array([c0, c0 + Vector2(160, 18), c0 + Vector2(260, 12), c0 + Vector2(420, 34)]),
					Color(0.1, 0.08, 0.06), 3.0)
			"tyhja":
				_root.draw_rect(r, Color(0.05, 0.04, 0.03))
				for k in 4:
					_root.draw_rect(Rect2(r.position + Vector2(k * r.size.x / 4.0 + 10, 10), Vector2(r.size.x / 4.0 - 20, r.size.y - 20)),
						Color(0.86, 0.72, 0.5, 0.06))
			_:
				_plank(r, Color(0.88, 0.74, 0.52), i)
				for k in 2:
					var np := _nail_pos(i, k)
					if pl.bent[k]:
						_root.draw_line(np, np + Vector2(10, -6), Color(0.55, 0.55, 0.58), 4.0)
						_root.draw_line(np + Vector2(10, -6), np + Vector2(22, -4), Color(0.65, 0.65, 0.68), 4.0)
					else:
						var head: float = 9.0 - 3.0 * pl.nails[k]
						_root.draw_circle(np + Vector2(1, 2), head, Color(0, 0, 0, 0.3))
						_root.draw_circle(np, head, Color(0.6, 0.6, 0.63) if pl.nails[k] < 1.0 else Color(0.42, 0.42, 0.45))
						_root.draw_circle(np - Vector2(head * 0.3, head * 0.3), head * 0.35, Color(1, 1, 1, 0.35))
						if pl.nails[k] < 1.0:  # peukalo pitelee naulaa
							_ellipse(np + Vector2(0, 28), Vector2(15, 11), Color(0.93, 0.74, 0.63))
							_ellipse(np + Vector2(0, 21), Vector2(8, 6), Color(0.98, 0.88, 0.84))
	# Naulapurkki.
	var jar := _area.position + Vector2(_area.size.x - 90, _area.size.y - 70)
	_box(Rect2(jar, Vector2(56, 52)), Color(0.55, 0.6, 0.62), 8)
	for k in 5:
		_root.draw_line(jar + Vector2(10 + k * 9, 4), jar + Vector2(14 + k * 8, -10), Color(0.7, 0.7, 0.72), 2.0)
	# Vasara: puuvarsi ja teräspää kiiltoineen.
	var hv := _mouse
	_root.draw_line(hv + Vector2(-4, -4), hv + Vector2(-46, -46), Color(0.55, 0.38, 0.2), 9.0)
	_root.draw_line(hv + Vector2(-6, -8), hv + Vector2(-44, -48), Color(0.7, 0.52, 0.3), 3.0)
	var head_r := Rect2(hv + Vector2(-64, -70), Vector2(46, 22))
	_box(head_r, Color(0.3, 0.3, 0.33), 4)
	_root.draw_rect(Rect2(head_r.position + Vector2(4, 3), Vector2(head_r.size.x - 8, 5)), Color(1, 1, 1, 0.25))


## Lauta syineen ja oksankohtineen.
func _plank(r: Rect2, col: Color, seed_i: int) -> void:
	_box(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.35), 6)
	_box(r, col, 6)
	_root.draw_rect(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, 5)), Color(1, 1, 1, 0.12))
	for k in 5:
		var y := r.position.y + 14 + k * 13
		var pts := PackedVector2Array()
		for i in 30:
			var x := r.position.x + 8 + i * (r.size.x - 16) / 29.0
			pts.append(Vector2(x, y + sin(x * 0.02 + k + seed_i) * 3.0))
		_root.draw_polyline(pts, col.darkened(0.18), 1.5)
	_ellipse(r.position + Vector2(r.size.x * 0.62, r.size.y * 0.45), Vector2(10, 6), col.darkened(0.35))


func _draw_terva(font: Font) -> void:
	_frame(Color(0.5, 0.62, 0.42))
	var w := _wall()
	# Taustalla kuusikko ja taivas.
	_box(Rect2(_area.position, Vector2(_area.size.x, 60)), Color(0.62, 0.74, 0.82), 16)
	for k in 14:
		var x := _area.position.x + 20 + k * 64.0
		_root.draw_colored_polygon(PackedVector2Array([Vector2(x, _area.position.y + 70), Vector2(x - 26, _area.position.y + 70),
			Vector2(x - 13, _area.position.y + 14 + (k % 3) * 8)]), Color(0.2, 0.34, 0.2))
	var lh := w.size.y / TH
	var cw := w.size.x / TW
	for y in TH:
		var lr := Rect2(w.position + Vector2(0, y * lh + 2), Vector2(w.size.x, lh - 4))
		_box(Rect2(lr.position + Vector2(0, 4), lr.size), Color(0, 0, 0, 0.3), int(lh / 2.0))
		_box(lr, LOG, int(lh / 2.0))
		_root.draw_rect(Rect2(lr.position + Vector2(lh / 2.0, 5), Vector2(lr.size.x - lh, 6)), Color(1, 1, 1, 0.12))
		_root.draw_rect(Rect2(lr.position + Vector2(lh / 2.0, lr.size.y - 10), Vector2(lr.size.x - lh, 7)), Color(0, 0, 0, 0.18))
		for k in 3:  # hirren syyt
			_root.draw_line(lr.position + Vector2(lh, 16 + k * 9), lr.position + Vector2(lr.size.x - lh, 18 + k * 9), LOG.darkened(0.15), 1.0)
		for side in [lr.position.x + lh * 0.45, lr.end.x - lh * 0.45]:  # päätyrenkaat
			_root.draw_circle(Vector2(side, lr.get_center().y), lh * 0.42, Color(0.72, 0.58, 0.4))
			for ring in 3:
				_root.draw_arc(Vector2(side, lr.get_center().y), lh * (0.12 + ring * 0.1), 0, TAU, 20, Color(0.55, 0.42, 0.28), 1.5)
		# Terva: tumma, kiiltävä, peittää vähitellen.
		for x in TW:
			var v := _paint[y * TW + x]
			if v > 0.0:
				var cell := Rect2(w.position + Vector2(x * cw, y * lh + 4), Vector2(cw + 1, lh - 8))
				_root.draw_rect(cell, Color(0.17, 0.1, 0.05, minf(v, 1.0) * 0.95))
				if v > 0.6:
					_root.draw_rect(Rect2(cell.position + Vector2(0, 5), Vector2(cell.size.x, 3)), Color(1.0, 0.85, 0.6, 0.18))
	for d in _drips:
		_root.draw_line(d.p, d.p + Vector2(0, d.len), Color(0.14, 0.07, 0.03), 7.0)
		_root.draw_circle(d.p + Vector2(0, d.len), 6.0, Color(0.14, 0.07, 0.03))
		_root.draw_circle(d.p + Vector2(-2, d.len - 2), 2.0, Color(1, 0.9, 0.7, 0.4))
	# Tervasanko.
	var b := _area.position + Vector2(_area.size.x - 110, _area.size.y - 92)
	_box(Rect2(b, Vector2(70, 62)), Color(0.45, 0.47, 0.5), 8)
	_ellipse(b + Vector2(35, 4), Vector2(35, 8), Color(0.12, 0.07, 0.03))
	_root.draw_arc(b + Vector2(35, 4), 38.0, PI, TAU, 16, Color(0.3, 0.3, 0.32), 3.0)
	_root.draw_string(font, b + Vector2(0, 40), "TERVA", HORIZONTAL_ALIGNMENT_CENTER, 70, 14, Color(0.15, 0.1, 0.05))
	# Sivellin: varsi, metallihela ja tervainen harjas.
	_root.draw_line(_mouse + Vector2(10, 14), _mouse + Vector2(46, 64), Color(0.62, 0.46, 0.28), 8.0)
	_box(Rect2(_mouse + Vector2(-2, 2), Vector2(22, 16)), Color(0.7, 0.7, 0.72), 3)
	for k in 6:
		_root.draw_line(_mouse + Vector2(-4 + k * 5, 2), _mouse + Vector2(-6 + k * 5, -14), Color(0.15, 0.09, 0.04), 3.0)


func _draw_luukku(font: Font) -> void:
	_frame(SOOT)
	_soot_logs(_area.grow(-6.0), Color(0.3, 0.22, 0.14))
	var c := _area.position + Vector2(_area.size.x / 2.0, 260)
	if _phase == "luukku":
		# Räppänä: karmi, lautaluukku, ruosteiset saranat ja kahva; heiluttaessa savua pöllähtää.
		_box(Rect2(c - Vector2(130, 150), Vector2(260, 200)), Color(0.14, 0.1, 0.07), 6)
		var open := _wiggle / 14.0
		var shake := sin(_t * 30.0) * 3.0 * float(Input.is_action_pressed("left") or Input.is_action_pressed("right"))
		var hr := Rect2(c - Vector2(110, 130) + Vector2(shake, -open * 70.0), Vector2(220, 160))
		_box(Rect2(hr.position + Vector2(5, 6), hr.size), Color(0, 0, 0, 0.35), 6)
		_box(hr, Color(0.46, 0.34, 0.2), 6)
		for k in 4:
			_root.draw_line(hr.position + Vector2(k * 55 + 5, 6), hr.position + Vector2(k * 55 + 5, hr.size.y - 6), Color(0.3, 0.2, 0.12), 2.0)
		for side in [hr.position.x + 20, hr.end.x - 70]:
			_box(Rect2(Vector2(side, hr.position.y + 12), Vector2(50, 12)), Color(0.45, 0.25, 0.12), 3)  # ruosteinen sarana
		_box(Rect2(hr.get_center() + Vector2(-25, 40), Vector2(50, 14)), IRON, 6)  # kahva
		if open > 0.0:
			for k in 4:
				var sp := c + Vector2(-60 + k * 40, -170 - open * 40.0 - fmod(_t * 30.0 + k * 20.0, 60.0))
				_root.draw_circle(sp, 14.0 + k * 3.0, Color(0.7, 0.7, 0.72, 0.25 * open))
		_root.draw_string(font, c + Vector2(-100, 90), "Räppänä", HORIZONTAL_ALIGNMENT_CENTER, 200, 22, Color(0.95, 0.9, 0.8))
	elif _phase == "ovi":
		_box(Rect2(c + Vector2(-215, -205), Vector2(250, 400)), Color(0.12, 0.09, 0.06), 4)  # oviaukko
		var door := Transform2D(-0.25 + _lift * 0.35, c + Vector2(-190, -185 + (1.0 - _lift) * 30.0))
		_root.draw_set_transform_matrix(door)
		_box(Rect2(Vector2(4, 6), Vector2(200, 340)), Color(0, 0, 0, 0.35), 6)
		_box(Rect2(Vector2.ZERO, Vector2(200, 340)), Color(0.46, 0.33, 0.2), 6)
		for k in 4:
			_root.draw_line(Vector2(k * 50, 4), Vector2(k * 50, 336), Color(0.3, 0.2, 0.12), 2.0)
		for y in [40.0, 300.0]:
			_box(Rect2(Vector2(6, y - 10), Vector2(188, 20)), Color(0.4, 0.28, 0.16), 4)  # vaakatuet
		_root.draw_line(Vector2(20, 290), Vector2(180, 50), Color(0.4, 0.28, 0.16), 18.0)  # Z-tuki
		for y in [40.0, 300.0]:
			_box(Rect2(Vector2(-6, y - 8), Vector2(70, 16)), IRON, 3)  # saranat
		_root.draw_set_transform_matrix(Transform2D.IDENTITY)
		var bar := Rect2(_area.position + Vector2(_area.size.x - 100, 100), Vector2(34, 300))
		_box(bar, Color(0.08, 0.08, 0.08), 8)
		_box(Rect2(bar.position + Vector2(0, bar.size.y * (1.0 - 0.82)), Vector2(34, bar.size.y * 0.2)), Color(0.3, 0.8, 0.4), 4)
		_box(Rect2(bar.position + Vector2(-8, bar.size.y * (1.0 - _lift) - 4), Vector2(50, 8)), Color.WHITE, 3)
		_root.draw_string(font, bar.position + Vector2(-30, -14), "Nosto", HORIZONTAL_ALIGNMENT_CENTER, 94, 18, Color(0.95, 0.9, 0.8))
	else:
		# Saranalevy ja kolme uraruuvia; kierretty osuus kaarena.
		_box(Rect2(c - Vector2(220, 60), Vector2(440, 120)), Color(0.24, 0.24, 0.27), 10, Color(0, 0, 0, 0.4), 8)
		_root.draw_rect(Rect2(c - Vector2(210, 52), Vector2(420, 6)), Color(1, 1, 1, 0.1))
		for i in 3:
			var sp := c + Vector2(-140 + i * 140, 0)
			_root.draw_circle(sp + Vector2(2, 3), 34.0, Color(0, 0, 0, 0.35))
			_root.draw_circle(sp, 34.0, Color(0.6, 0.6, 0.63))
			_root.draw_circle(sp - Vector2(8, 8), 14.0, Color(1, 1, 1, 0.2))
			var a: float = _screws[i] * TAU * 3.0
			_root.draw_line(sp + Vector2(-26, 0).rotated(a), sp + Vector2(26, 0).rotated(a), Color(0.18, 0.18, 0.2), 7.0)
			if i == _screw_i:
				_root.draw_arc(sp, 46.0, -PI / 2.0, -PI / 2.0 + TAU * _screws[i], 32, Color(0.3, 0.8, 0.4), 6.0)
			elif i < _screw_i:
				_root.draw_arc(sp, 46.0, 0, TAU, 32, Color(0.3, 0.8, 0.4, 0.5), 3.0)
		# Ruuvimeisseli kursorina.
		_root.draw_line(_mouse, _mouse + Vector2(40, 40), Color(0.7, 0.7, 0.72), 5.0)
		_box(Rect2(_mouse + Vector2(36, 36), Vector2(26, 50)), Color(0.85, 0.2, 0.15), 8)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_root.draw_colored_polygon(pts, col)


func _box(r: Rect2, col: Color, radius: int, shadow := Color(0, 0, 0, 0), shadow_size := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.shadow_color = shadow
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(4, 6)
	sb.anti_aliasing = true
	_root.draw_style_box(sb, r)
