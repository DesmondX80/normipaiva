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
					var p := _area.position + Vector2(rng.randf_range(80, _area.size.x - 80), rng.randf_range(80, _area.size.y - 70))
					var ok := true
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
	_info.text = _status() + "   ·   F lopettaa"


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
				return "Savuluukku jumissa: A / D vuorotellen (%d / 14)" % _wiggle
			if _phase == "ovi":
				return "Ovi roikkuu: pidä W pohjassa nostaaksesi, E kiinnittää kun vihreällä"
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

func _draw_root() -> void:
	var font := ThemeDB.fallback_font
	_root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0, 0, 0, 0.55))
	match mode:
		"kivet":
			_box(_area, Color(0.55, 0.5, 0.4), 16)
			_root.draw_rect(Rect2(_area.position + Vector2(0, _area.size.y - 90), Vector2(_area.size.x, 90)), Color(0.35, 0.5, 0.6, 0.6))
			for s in _stones:
				if s.taken:
					continue
				if s.good:
					_ellipse(s.p, Vector2(s.r, s.r * 0.85), Color(0.32, 0.34, 0.36))
					_ellipse(s.p + Vector2(-s.r * 0.3, -s.r * 0.3), Vector2(s.r * 0.3, s.r * 0.2), Color(1, 1, 1, 0.12))
					for k in 5:
						_root.draw_circle(s.p + Vector2(cos(k * 1.7), sin(k * 2.3)) * s.r * 0.5, 2.0, Color(0.2, 0.25, 0.22))
				else:
					var pts := PackedVector2Array()
					for k in 6:
						pts.append(s.p + Vector2(cos(k * TAU / 6.0 + s.rot) * s.r * 1.3, sin(k * TAU / 6.0 + s.rot) * s.r * 0.5))
					_root.draw_colored_polygon(pts, Color(0.48, 0.47, 0.44))
					for k in 3:
						_root.draw_line(s.p + Vector2(-s.r, -6 + k * 6).rotated(s.rot * 0.1), s.p + Vector2(s.r, -6 + k * 6).rotated(s.rot * 0.1),
							Color(0.35, 0.34, 0.32), 2.0)
			_root.draw_string(font, _area.position + Vector2(20, 40), "Rannan kivikasa", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		"kiuas":
			_box(_area, Color(0.22, 0.2, 0.19), 16)
			_box(Rect2(_area.position + Vector2(220, 120), Vector2(440, 340)), Color(0.15, 0.15, 0.16), 10)  # kiuas
			_root.draw_rect(Rect2(_area.position + Vector2(300, 470), Vector2(280, 24)), Color(0.9, 0.4, 0.1, 0.4 + 0.2 * sin(_t * 6.0)))
			for s in _slots:
				var r: Rect2 = s.rect
				if s.old > 0:
					_ellipse(r.get_center(), r.size / 2.0, Color(0.5, 0.45, 0.4).darkened(0.2 * (2 - s.old)))
					_root.draw_line(r.position + Vector2(10, 20), r.end - Vector2(20, 15), Color(0.2, 0.18, 0.16), 2.0)
				elif s.stone != "":
					_ellipse(r.get_center(), r.size / 2.0 * (1.0 if s.stone == "iso" else 0.85), Color(0.3, 0.32, 0.34))
				else:
					_root.draw_rect(r, Color(1, 1, 1, 0.15), false, 2.0)
			for i in _bag.size():
				var br := _bag_rect(i)
				_ellipse(br.get_center(), br.size / 2.0, Color(0.33, 0.35, 0.37))
			_root.draw_string(font, _area.position + Vector2(40, 50), "Uudet kivet", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
			if _held != "":
				var hs := Vector2(110, 56) if _held == "iso" else Vector2(80, 44)
				_ellipse(_mouse, hs / 2.0, Color(0.35, 0.37, 0.4, 0.9))
		"lauteet":
			_box(_area, Color(0.2, 0.16, 0.12), 16)
			for i in _planks.size():
				var pl: Dictionary = _planks[i]
				var r := _plank_rect(i)
				match pl.s:
					"laho":
						_box(Rect2(r.position + Vector2(0, -pl.pry * 4.0), r.size), Color(0.36, 0.34, 0.27), 6)
						_root.draw_line(r.position + Vector2(100, 30), r.position + Vector2(420, 50), Color(0.15, 0.14, 0.1), 3.0)
					"tyhja":
						_root.draw_rect(r, Color(0.05, 0.04, 0.03))
						_root.draw_rect(r, Color(0.86, 0.72, 0.5, 0.25), false, 2.0)
					_:
						_box(r, Color(0.86, 0.72, 0.5), 6)
						for k in 2:
							var np := _nail_pos(i, k)
							if pl.bent[k]:
								_root.draw_line(np, np + Vector2(14, -10), Color(0.6, 0.6, 0.62), 4.0)
							else:
								var head: float = 9.0 - 3.0 * pl.nails[k]
								_root.draw_circle(np, head, Color(0.62, 0.62, 0.64) if pl.nails[k] < 1.0 else Color(0.45, 0.45, 0.47))
								if pl.nails[k] < 1.0:
									_ellipse(np + Vector2(0, 26), Vector2(14, 10), Color(0.95, 0.75, 0.65))  # peukalo pitelee naulaa
			_root.draw_line(_mouse + Vector2(-30, -30), _mouse + Vector2(0, 0), Color(0.5, 0.35, 0.2), 6.0)  # vasara
			_box(Rect2(_mouse + Vector2(-46, -48), Vector2(34, 18)), Color(0.35, 0.35, 0.38), 3)
		"terva":
			if _paint.size() < TW * TH:
				return  # seinä alustetaan ensimmäisen ruudun jälkeen (_setup)
			var w := _wall()
			_box(_area, Color(0.42, 0.55, 0.35), 16)
			var lh := w.size.y / TH
			for y in TH:
				_box(Rect2(w.position + Vector2(0, y * lh + 2), Vector2(w.size.x, lh - 4)), Color(0.6, 0.47, 0.3), int(lh / 2.0))
			var cw := w.size.x / TW
			for y in TH:
				for x in TW:
					var v := _paint[y * TW + x]
					if v > 0.0:
						_root.draw_rect(Rect2(w.position + Vector2(x * cw, y * lh + 3), Vector2(cw + 1, lh - 6)), Color(0.18, 0.11, 0.06, minf(v, 1.0) * 0.95))
			for d in _drips:
				_root.draw_line(d.p, d.p + Vector2(0, d.len), Color(0.15, 0.08, 0.03), 6.0)
				_root.draw_circle(d.p + Vector2(0, d.len), 5.0, Color(0.15, 0.08, 0.03))
			_root.draw_circle(_mouse, 14.0, Color(0.2, 0.12, 0.06, 0.8))  # tervasuti
			_root.draw_line(_mouse, _mouse + Vector2(30, 40), Color(0.6, 0.45, 0.25), 6.0)
		"luukku":
			_box(_area, Color(0.38, 0.3, 0.22), 16)
			var c := _area.position + Vector2(_area.size.x / 2.0, 260)
			if _phase == "luukku":
				_box(Rect2(c - Vector2(120, 140), Vector2(240, 180)), Color(0.3, 0.22, 0.14), 8)
				var open := _wiggle / 14.0
				_box(Rect2(c - Vector2(100, 120) + Vector2(sin(_t * 30.0) * 3.0 * float(Input.is_action_pressed("left") or Input.is_action_pressed("right")), -open * 60.0),
					Vector2(200, 140)), Color(0.45, 0.35, 0.22), 6)
				_root.draw_string(font, c + Vector2(-60, 80), "Räppänä", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
			elif _phase == "ovi":
				_root.draw_rect(Rect2(c + Vector2(-200, -200), Vector2(40, 380)), Color(0.3, 0.22, 0.14))
				var door := Transform2D(-0.25 + _lift * 0.35, c + Vector2(-160, -180 + (1.0 - _lift) * 30.0))
				_root.draw_set_transform_matrix(door)
				_box(Rect2(Vector2.ZERO, Vector2(200, 340)), Color(0.42, 0.3, 0.18), 6)
				_root.draw_set_transform_matrix(Transform2D.IDENTITY)
				var bar := Rect2(_area.position + Vector2(_area.size.x - 90, 100), Vector2(30, 300))
				_box(bar, Color(0.1, 0.1, 0.1), 6)
				_root.draw_rect(Rect2(bar.position + Vector2(0, bar.size.y * (1.0 - 0.82)), Vector2(30, bar.size.y * 0.2)), Color(0.3, 0.8, 0.4))
				_root.draw_rect(Rect2(bar.position + Vector2(-6, bar.size.y * (1.0 - _lift) - 3), Vector2(42, 6)), Color.WHITE)
			else:
				for i in 3:
					var sp := c + Vector2(-140 + i * 140, 0)
					_root.draw_circle(sp, 34.0, Color(0.55, 0.55, 0.58))
					var a: float = _screws[i] * TAU * 3.0
					_root.draw_line(sp + Vector2(-26, 0).rotated(a), sp + Vector2(26, 0).rotated(a), Color(0.2, 0.2, 0.22), 6.0)
					if i == _screw_i:
						_root.draw_arc(sp, 44.0, 0, TAU * _screws[i], 32, Color(0.3, 0.8, 0.4), 5.0)
				_root.draw_circle(_mouse, 8.0, Color(0.9, 0.85, 0.3))


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_root.draw_colored_polygon(pts, col)


func _box(r: Rect2, col: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	_root.draw_style_box(sb, r)
