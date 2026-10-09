extends Node
## Uusi juliste koko pelistä: Saloinen, mökki Neittävällä ja Vaala. Kuvat ovat oikeita pelikuvia testikohtauksista
## (--scene=... --nohud), ja tämä sommittelee ne GTA-sarjakuvaksi. Puuttuvat kuvat otetaan ajon alussa pelistä
## (yksi kohtaus kerrallaan, n. minuutti kappale); valmiit kuvat käytetään uudelleen.
## Ajo: godot --path . tools/juliste.tscn -- --out=/polku/juliste.png [--shots=/polku/kuvat]

const SIZE := Vector2i(1600, 2400)
const YELLOW := Color(1.0, 0.8, 0.1)
const ORANGE := Color(1.0, 0.42, 0.0)
const RED := Color(0.85, 0.1, 0.08)
const GREEN := Color(0.2, 0.75, 0.25)
const INK := Color(0.1, 0.08, 0.05)
const SHOT_RES := "1920x1080"

## Rivien yläreunat ja paneelien x-paikat (4 paneelia rivissä).
const ROWS := [1080, 1395, 1710]
const COLS := [30, 420, 810, 1200]
const CELL := Vector2(370, 230)

## [kohtaus, tiedosto, polttopiste (0..1), zoom, rivi, sarake, kallistus, tarra, kuvateksti]
const PANELS := [
	["juntti", "shot.png", Vector2(0.5, 0.4), 1.15, 0, 0, -0.8, "STREET FIGHTER", "Juntti haastaa riitaa"],
	["shop", "shot.png", Vector2(0.52, 0.62), 1.8, 0, 1, 0.7, "KAUPPA", "Harmaapäät laskee kolikoita"],
	["laavufire", "shot.png", Vector2(0.45, 0.4), 1.2, 0, 2, -0.6, "LAAVU", "Makkara, nuotio ja kalja"],
	["tractor", "shot.png", Vector2(0.4, 0.55), 1.4, 0, 3, 0.9, "VAARA", "\"Mää ajan sut kumoon!\""],
	["mokkifish", "shot_1.png", Vector2(0.5, 0.55), 1.4, 1, 0, 0.6, "KALAAN", "Soutuveneellä virveliä"],
	["mokkipingis", "shot_rally.png", Vector2(0.45, 0.55), 1.3, 1, 1, -0.7, "PIHAPINGIS", "Santtu – pihapingismestari"],
	["mokkijahti", "shot_aim.png", Vector2(0.5, 0.58), 1.3, 1, 2, 0.8, "METSÄSTYS", "Hirveen ei oo lupaa!"],
	["mokkiuinti", "shot_10.png", Vector2(0.45, 0.42), 1.3, 1, 3, -0.5, "SALMINEN", "Sukellus simpukoiden sekaan"],
	["junamatka", "shot_vaala3.png", Vector2(0.5, 0.4), 1.35, 2, 0, -0.6, "JUNALLA", "Ravintolavaunussa Kossut"],
	["mokkikiihdytys", "shot_ajo1.png", Vector2(0.45, 0.6), 1.25, 2, 1, 0.7, "KIIHDYTYS", "Tunturi-Jani, 150 m"],
	["mokkinuoret", "shot_lava.png", Vector2(0.58, 0.62), 1.35, 2, 2, -0.8, "LAVA", "Oulujärven lavalle pummilla"],
	["mokkisiitari", "shot_3.png", Vector2(0.32, 0.5), 1.0, 2, 3, 0.6, "SIITARI", "\"Mopolla Vaalaan\" karaokessa"],
]
const SECTIONS := ["SALOINEN", "MÖKKI · NEITTÄVÄ", "VAALA"]
const HERO := ["bikeside", "shot.png", Vector2(0.45, 0.45), 1.0]
const ENDINGS := [
	["wasted", "shot_1.png", Vector2(0.5, 0.45), 1.12, Rect2(30, 1995, 700, 240), -0.6, "LOPPU A", RED, "Päivi nappasi kiinni"],
	["garage", "shot.png", Vector2(0.5, 0.45), 1.12, Rect2(870, 1995, 700, 240), 0.6, "LOPPU B", GREEN, "Jemmassa 26 – juhlan paikka!"],
]

var _out := "user://juliste.png"
var _shots := "user://juliste_kuvat"
var _poster: SubViewport
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--shots="):
			_shots = a.substr(8)
	_shots = ProjectSettings.globalize_path(_shots)
	_capture_missing()
	_poster = SubViewport.new()
	_poster.size = SIZE
	_poster.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_poster)
	_layout()


func _process(_d: float) -> void:
	_frames += 1
	if _frames == 6:
		_poster.get_texture().get_image().save_png(_out)
		print("Juliste tallennettu: ", ProjectSettings.globalize_path(_out))
		get_tree().quit()


## Ottaa puuttuvat pelikuvat: peli käynnistetään testikohtaukseen ilman HUDia.
func _capture_missing() -> void:
	var scenes := {}
	for p in PANELS + ENDINGS + [HERO]:
		if not FileAccess.file_exists(_shot_path(p[0], p[1])):
			scenes[p[0]] = true
	for sc in scenes:
		DirAccess.make_dir_recursive_absolute(_shots.path_join(sc))
		print("Kuvataan --scene=%s ..." % sc)
		var args := ["--path", ProjectSettings.globalize_path("res://"), "--resolution", SHOT_RES, "--",
			"--shot=" + _shots.path_join(sc).path_join("shot.png"), "--scene=" + sc, "--nohud"]
		OS.execute(OS.get_executable_path(), args)


func _shot_path(scene: String, file: String) -> String:
	return _shots.path_join(scene).path_join(file)


## Kuvasta rajataan kohteen kuvasuhteen mukainen pala polttopisteen ympäriltä (zoom > 1 rajaa tiukemmin).
func _crop(scene: String, file: String, focus: Vector2, zoom: float, aspect: float) -> Texture2D:
	var img := Image.load_from_file(_shot_path(scene, file))
	if img == null:
		push_error("Kuva puuttuu: " + _shot_path(scene, file))
		return null
	var s := Vector2(img.get_size())
	var c := Vector2(s.y * aspect, s.y) if s.x / s.y > aspect else Vector2(s.x, s.x / aspect)
	c /= zoom
	var pos := (focus * s - c / 2.0).clamp(Vector2.ZERO, s - c)
	var at := AtlasTexture.new()
	at.atlas = ImageTexture.create_from_image(img)
	at.region = Rect2(pos, c)
	return at


# --- Sommittelu --------------------------------------------------------------

func _layout() -> void:
	var root := Control.new()
	root.size = Vector2(SIZE)
	_poster.add_child(root)

	var bg := ColorRect.new()
	bg.size = Vector2(SIZE)
	bg.color = Color(0.08, 0.07, 0.09)
	root.add_child(bg)
	for i in 12:
		var stripe := ColorRect.new()
		stripe.size = Vector2(3600, 80)
		stripe.position = Vector2(-1000, 160 + i * 230)
		stripe.rotation = -0.35
		stripe.color = Color(ORANGE, 0.08 + 0.02 * (i % 2))
		root.add_child(stripe)

	# Otsikko.
	var title := _text(root, "NORMIPÄIVÄ", 250, YELLOW, 32)
	title.position = Vector2(0, -16)
	title.size = Vector2(SIZE.x, 260)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _text(root, "S A L O I S I S S A", 74, Color.WHITE, 16)
	sub.position = Vector2(0, 222)
	sub.size = Vector2(SIZE.x, 90)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sticker(root, "+ MÖKKI JA VAALA!", 34, RED, Color.WHITE, Vector2(1170, 238), -0.1)

	# Pääkuva.
	var hero := Rect2(30, 330, 1540, 650)
	_frame(root, _crop(HERO[0], HERO[1], HERO[2], HERO[3], hero.size.x / hero.size.y), hero, -0.5)
	_sticker(root, "UUTTA: TARINA · MÖKKI · MOPO · JUNA", 30, ORANGE, Color.WHITE, Vector2(62, 360), -0.07)
	_sticker(root, "PAAPELIIN PÄÄSEE, KUNHAN…", 34, YELLOW, INK, Vector2(1010, 900), -0.04)

	for p in PANELS:
		var r := Rect2(Vector2(COLS[p[5]], ROWS[p[4]]), CELL)
		_panel(root, _crop(p[0], p[1], p[2], p[3], CELL.x / CELL.y), r, p[6], p[7], YELLOW, INK, p[8])

	# Osiot: otsikko ja viiva rivin yläpuolelle (paneelien jälkeen, ettei ylärivin kehys peitä ääkkösiä).
	for i in SECTIONS.size():
		var y: float = ROWS[i] - 72
		var h := _text(root, SECTIONS[i], 42, YELLOW, 10)
		h.position = Vector2(30, y - 10)
		var line := ColorRect.new()
		line.color = ORANGE
		line.position = Vector2(30 + h.get_minimum_size().x + 20, y + 22)
		line.size = Vector2(SIZE.x - 60 - h.get_minimum_size().x - 20, 6)
		root.add_child(line)

	# Kaksi loppua ja "TAI" väliin.
	for e in ENDINGS:
		var r: Rect2 = e[4]
		_panel(root, _crop(e[0], e[1], e[2], e[3], r.size.x / r.size.y), r, e[5], e[6], e[7], Color.WHITE, e[8])
	var tai := _text(root, "TAI", 52, YELLOW, 12)
	tai.position = Vector2(730, 2080)
	tai.size = Vector2(140, 70)
	tai.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tag := _text(root, "Kuutonen jemmaan. Naapureille hommat. Paapeliin ennen Päiviä.", 50, Color.WHITE, 12)
	tag.position = Vector2(0, 2262)
	tag.size = Vector2(SIZE.x, 80)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var credit := _text(root, "Saloinen · Raahe · Neittävä · Vaala  ·  Tehty Godotilla  ·  Hahmot: Quaternius (CC0)", 26, Color(0.75, 0.72, 0.68), 5)
	credit.position = Vector2(0, 2342)
	credit.size = Vector2(SIZE.x, 44)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Kuvapaneeli, tarra vasempaan yläkulmaan ja kuvateksti alareunaan.
func _panel(root: Control, tex: Texture2D, r: Rect2, deg: float, label: String, label_bg: Color, label_fg: Color,
		caption: String) -> void:
	var holder := _frame(root, tex, r, deg)
	# Tumma liuku alareunaan, jotta kuvateksti erottuu kirkkaastakin kuvasta.
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0, 0, 0, 0))
	grad.gradient.set_color(1, Color(0, 0, 0, 0.65))
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	shade.texture = grad
	shade.position = Vector2(0, r.size.y * 0.5)
	shade.size = Vector2(r.size.x, r.size.y * 0.5)
	holder.add_child(shade)
	var cap := _text(holder, caption, 30 if r.size.x < 500 else 36, Color.WHITE, 9)
	cap.position = Vector2(8, r.size.y - 60)
	cap.size = Vector2(r.size.x - 16, 54)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sticker(root, label, 28, label_bg, label_fg, r.position + Vector2(-10, -16), -0.05)


## Vino tarra: värillinen laatta ja teksti.
func _sticker(root: Control, text: String, size: int, bg: Color, fg: Color, pos: Vector2, rot: float) -> void:
	var box := ColorRect.new()
	box.color = bg
	box.position = pos
	box.rotation = rot
	root.add_child(box)
	var l := _text(box, text, size, fg, 0)
	l.remove_theme_constant_override("shadow_offset_x")
	l.remove_theme_constant_override("shadow_offset_y")
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var m := l.get_minimum_size()
	box.size = Vector2(m.x + 28, m.y + 6)
	l.position = Vector2(14, 3)
	l.size = m


## Kuva mustalla ja valkoisella kehyksellä, hieman vinossa.
func _frame(root: Control, tex: Texture2D, r: Rect2, deg: float) -> Control:
	var holder := Control.new()
	holder.position = r.position
	holder.size = r.size
	holder.pivot_offset = r.size / 2.0
	holder.rotation_degrees = deg
	root.add_child(holder)
	var border := ColorRect.new()
	border.color = Color.BLACK
	border.position = Vector2(-10, -10)
	border.size = r.size + Vector2(20, 20)
	holder.add_child(border)
	var white := ColorRect.new()
	white.color = Color(0.95, 0.93, 0.88)
	white.position = Vector2(-5, -5)
	white.size = r.size + Vector2(10, 10)
	holder.add_child(white)
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # ennen kokoa, muuten koko jää tekstuurin kokoiseksi
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = r.size
	holder.add_child(t)
	return holder


func _text(root: Control, text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Impact", "Arial Black", "Helvetica Neue"])
	font.font_weight = 900
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 5)
	l.add_theme_constant_override("shadow_offset_y", 6)
	root.add_child(l)
	return l
