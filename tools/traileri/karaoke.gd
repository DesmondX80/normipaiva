extends SceneTree
## Trailerin karaokeversio: valmiin traileri.avi:n (kokoa.gd) ruutujen alempaan mustaan palkkiin piirretään tunnarin
## sanat. Laulettava rivi täyttyy kullankeltaiseksi sana sanalta laulun tahdissa, seuraava rivi näkyy himmeänä sen
## alla, ja pitkän tauon jälkeen kolme pistettä laskee rivin sisään iskujen tahdissa. Ajoitus: karaoke.json
## (karaoke_ajoitus.py: sanat kohdistettu lauluraitaan). Ääni kopioidaan sellaisenaan.
## Tekstit piirretään näytönohjaimella, joten ajo ei voi olla --headless:
##   godot --path . -s res://tools/traileri/karaoke.gd -- --in=KANSIO [--tyyli=kuva]
## --tyyli=palkki (oletus): sanat alemmassa mustassa palkissa. --tyyli=kuva: traileri pyörii taustalla ja sanat ovat
## isompina kuvan päällä sen alaosassa (pehmeä tumma liukuväri tekstin takana), seuraava rivi palkissa.
## --soitto: ääneksi traileri_soitto.wav (kokoa.gd --soitto: tunnari ilman laulua, pelin äänet mukana), jolloin
## katsoja laulaa itse; tiedostonimiin _soitto.
## Tulos: KANSIO/traileri_karaoke[_kuva][_soitto].avi (JPEG-ruuduista ruudut_karaoke[_kuva][_soitto]/).
## MP4: tulostettu ffmpeg-komento.

const Leikkaus := preload("res://tools/traileri/leikkaus.gd")
const Kokoa := preload("res://tools/traileri/kokoa.gd")
const Teksti := preload("res://tools/traileri/teksti.gd")
const LYRICS := "res://tools/traileri/karaoke.json"

const SUNG := Color(1.0, 0.8, 0.22)
const UNSUNG := Color(1.0, 1.0, 1.0)
const NEXT_ALPHA := 0.5
const LEAD := 1.2   # rivi näkyy näin paljon ennen ensimmäistä sanaa (s)
const HOLD := 0.35  # laulettu rivi jää näkyviin viimeisen sanan jälkeen (s)
const COUNT_GAP := 4.0  # näin pitkän tauon jälkeen rivi lasketaan sisään pisteillä
const FADE := 0.25
const JPEG_Q := 0.92

var dir := ""
var style := "palkki"  # palkki | kuva
var soitto := false  # ääni ilman laulua (traileri_soitto.wav)
var region_h := 0.0  # piirtoalueen korkeus ruudun alareunasta (px)
var cur_y := 0.0     # laulettavan rivin yläreuna piirtoalueessa
var next_y := 0.0
var shade: TextureRect  # kuva-tyyli: tumma liukuväri tekstin takana
var status: Label  # ikkunassa: eteneminen ja viimeksi piirretty ruutu (ikkuna ei saa jäädä harmaaksi)
var preview: TextureRect
var lines: Array = []
var vp: SubViewport
var cur_base: Label
var cur_fill: Label
var cur_clip: Control
var next_lbl: Label
var dots: Label
var font: Font
var bar_h := 0.0
var w := 0
var h := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="):
			dir = a.substr(5)
		elif a.begins_with("--tyyli="):
			style = a.substr(8)
		elif a == "--soitto":
			soitto = true
	lines = JSON.parse_string(FileAccess.get_file_as_string(LYRICS)).lines
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var k: Object = Kokoa.new()  # AVI-luku ja -kirjoitus (kokoa.gd:n funktiot)
	k.dir = dir
	var src := dir.path_join("traileri.avi")
	var jpeg_dir := dir.path_join("ruudut")
	var from_avi := FileAccess.file_exists(src)
	var music_from: int = Leikkaus.timeline()[0].music_from
	var hdr := {}
	var frames: int
	var f: FileAccess
	if from_avi:
		hdr = k._read_avi(src)
		w = hdr.w
		h = hdr.h
		frames = hdr.video.size()
		f = FileAccess.open(src, FileAccess.READ)
	else:
		var names := Array(DirAccess.get_files_at(jpeg_dir)).filter(func(n: String) -> bool: return n.ends_with(".jpg"))
		names.sort()
		hdr.names = names
		frames = names.size()
		var first := Image.load_from_file(jpeg_dir.path_join(names[0]))
		w = first.get_width()
		h = first.get_height()
		DirAccess.make_dir_recursive_absolute(dir.path_join(_out_name("ruudut_karaoke")))
	if frames == 0:
		push_error("Karaoke: trailerin ruutuja ei löydy kansiosta " + dir)
		quit(1)
		return
	_build()
	_build_window()
	var song_pcm := PackedByteArray()  # --soitto: korvaava ääni (16-bit stereo 48 kHz, kokoa.gd:n wav)
	if soitto:
		var wp := dir.path_join("traileri_soitto.wav")
		if not FileAccess.file_exists(wp):
			push_error("Karaoke: %s puuttuu (aja ensin kokoa.gd --soitto)" % wp)
			quit(1)
			return
		song_pcm = FileAccess.get_file_as_bytes(wp).slice(44)
	var out: FileAccess
	var idx := StreamPeerBuffer.new()
	var movi_pos := 0
	if from_avi:
		out = FileAccess.open(dir.path_join(_out_name("traileri_karaoke") + ".avi"), FileAccess.WRITE)
		k._write_header(out, w, h, frames)
		movi_pos = out.get_position() - 4
	var drawn := 0
	var t0 := Time.get_ticks_msec()
	for fi in frames:
		var jpeg: PackedByteArray
		if from_avi:
			f.seek(hdr.video[fi][0])
			jpeg = f.get_buffer(hdr.video[fi][1])
		else:
			jpeg = FileAccess.get_file_as_bytes(jpeg_dir.path_join(hdr.names[fi]))
		var t := float(fi - music_from) / Leikkaus.FPS
		if _layout(t):
			await process_frame
			await RenderingServer.frame_post_draw
			var over := vp.get_texture().get_image()
			var img := Image.new()
			img.load_jpg_from_buffer(jpeg)
			img.convert(Image.FORMAT_RGBA8)
			over.convert(Image.FORMAT_RGBA8)
			img.blend_rect(over, Rect2i(Vector2i.ZERO, over.get_size()), Vector2i(0, h - over.get_height()))
			img.convert(Image.FORMAT_RGB8)
			jpeg = img.save_jpg_to_buffer(JPEG_Q)
			drawn += 1
		if from_avi:
			k._chunk(out, idx, movi_pos, "00db", jpeg)
			if soitto:
				k._chunk(out, idx, movi_pos, "01wb", song_pcm.slice(fi * Kokoa.SPF * 4, (fi + 1) * Kokoa.SPF * 4))
			elif fi < hdr.audio.size():
				f.seek(hdr.audio[fi][0])
				k._chunk(out, idx, movi_pos, "01wb", f.get_buffer(hdr.audio[fi][1]))
		else:
			var jf := FileAccess.open(dir.path_join(_out_name("ruudut_karaoke") + "/%05d.jpg" % fi), FileAccess.WRITE)
			jf.store_buffer(jpeg)
		if fi % 300 == 0:
			print("karaoke %d/%d ruutua (%d s)" % [fi, frames, (Time.get_ticks_msec() - t0) / 1000])
		if fi % 30 == 0:
			status.text = "Karaoke: ruutu %d / %d (%d %%)  ·  ikkuna sulkeutuu itse, kun video on valmis" % [
				fi, frames, 100 * fi / frames]
			if drawn > 0 and fi % 90 == 0:
				var shot := Image.new()
				shot.load_jpg_from_buffer(jpeg)
				preview.texture = ImageTexture.create_from_image(shot)
			await process_frame
	if from_avi:
		k._finish(out, idx, movi_pos, frames)
	print("Valmis: %d ruutua, sanat %d ruudussa" % [frames, drawn])
	var vin := ("-i %s.avi" % _out_name("traileri_karaoke")) if from_avi else ("-framerate 30 -i %s/%%05d.jpg" % _out_name("ruudut_karaoke"))
	print("MP4 (ffmpeg): cd \"%s\" && ffmpeg %s -i %s -map 0:v -map 1:a -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -c:a aac -b:a 320k -shortest %s.mp4"
		% [dir, vin, "traileri_soitto.wav" if soitto else "traileri.wav", _out_name("traileri_karaoke")])
	k.free()
	quit()


func _out_name(base: String) -> String:
	return base + ("_kuva" if style == "kuva" else "") + ("_soitto" if soitto else "")


## Ikkunassa näkyy eteneminen ja välillä valmis ruutu, ettei ikkuna näytä jumittuneelta harmaalta.
func _build_window() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	preview = TextureRect.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.offset_bottom = -48
	root.add_child(preview)
	status = Label.new()
	status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_top = -44
	status.add_theme_font_size_override("font_size", 20)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.text = "Karaoke: luetaan traileria..."
	root.add_child(status)


## Piirtoalusta ruudun alareunassa läpinäkyvänä SubViewportina: palkki-tyylissä alempi musta palkki (kuva-ala
## ASPECT:n mukaan), kuva-tyylissä myös kuvan alaosa palkin yläpuolelta.
func _build() -> void:
	bar_h = (h - w / Leikkaus.ASPECT) / 2.0
	if bar_h < h * 0.06:
		bar_h = h * 0.12  # ei palkkeja (muu kuvasuhde): sanat ruudun alareunaan
	var cs: int
	var ns: int
	if style == "kuva":
		region_h = bar_h + h * 0.2
		cs = roundi(h * 0.062)
		ns = roundi(h * 0.036)
		cur_y = region_h - bar_h - cs * 1.45  # rivi kuvan alaosassa juuri palkin yläpuolella
		next_y = region_h - bar_h + (bar_h - ns * 1.3) / 2.0  # seuraava rivi palkin keskellä
	else:
		region_h = bar_h
		cs = roundi(bar_h * 0.4)
		ns = roundi(bar_h * 0.24)
		cur_y = bar_h * 0.06
		next_y = bar_h * 0.6
	vp = SubViewport.new()
	vp.size = Vector2i(w, ceili(region_h))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	font = Teksti.font(true)
	if style == "kuva":
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0, 0, 0, 0.6))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		gt.width = 4
		gt.height = 64
		shade = TextureRect.new()
		shade.texture = gt
		shade.stretch_mode = TextureRect.STRETCH_SCALE
		shade.position = Vector2(0, 0)
		shade.size = Vector2(w, region_h - bar_h)
		vp.add_child(shade)
	cur_base = _label(cs, UNSUNG)
	cur_clip = Control.new()
	cur_clip.clip_contents = true
	vp.add_child(cur_clip)
	cur_fill = _label(cs, SUNG)
	cur_fill.reparent(cur_clip)
	next_lbl = _label(ns, Color(1, 1, 1, NEXT_ALPHA if style != "kuva" else 0.65))
	dots = _label(cs, SUNG)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", maxi(4, size / 7))
	vp.add_child(l)
	return l


## Hetken t (musiikin kohta, s) karaokerivit; false = ei mitään piirrettävää.
func _layout(t: float) -> bool:
	var i := _current(t)
	if i < 0:
		return false
	var line: Dictionary = lines[i]
	var gap_before: float = line.start - (lines[i - 1].end if i > 0 else -100.0)
	var show_from: float = line.start - (maxf(LEAD, 3.0 * Leikkaus.BEAT + 0.4) if gap_before >= COUNT_GAP else LEAD)
	if t < show_from:
		return false
	# Peräkkäiset rivit vaihtuvat suoraan; tauon jälkeen rivi häivytetään sisään ja ennen taukoa ulos.
	var a := 1.0
	var prev_switch := _switch(i - 1) if i > 0 else -100.0
	if gap_before > 1.0:
		a = clampf((t - maxf(show_from, prev_switch)) / FADE, 0.0, 1.0)
	var follows: bool = i + 1 < lines.size() and lines[i + 1].start - line.end < COUNT_GAP
	if not follows:
		a *= clampf((_switch(i) - t) / FADE, 0.0, 1.0)
	var size := cur_base.get_theme_font_size("font_size")
	var text: String = line.text
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x0 := (w - tw) / 2.0
	var y0 := cur_y
	for l in [cur_base, cur_fill]:
		l.text = text
		l.position = Vector2(0, 0)
		l.size = Vector2(tw + size, size * 1.4)
	cur_base.position = Vector2(x0, y0)
	cur_clip.position = Vector2(x0 - size * 0.2, y0)
	cur_fill.position = Vector2(size * 0.2, 0)
	cur_clip.size = Vector2(size * 0.2 + _sung_px(line, t, size), size * 1.4)
	cur_base.modulate.a = a
	cur_clip.modulate.a = a
	if shade != null:
		shade.modulate.a = a
	# Seuraava rivi himmeänä alla, jos se tulee pian.
	next_lbl.visible = false
	if i + 1 < lines.size() and lines[i + 1].start - line.end < COUNT_GAP:
		var ns := next_lbl.get_theme_font_size("font_size")
		next_lbl.text = lines[i + 1].text
		var nw := font.get_string_size(next_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
		next_lbl.position = Vector2((w - nw) / 2.0, next_y)
		next_lbl.modulate.a = a
		next_lbl.visible = true
	# Sisäänlaskenta: kolme pistettä sammuu yksi kerrallaan viimeisinä iskuina ennen riviä.
	dots.visible = false
	if gap_before >= COUNT_GAP and t < line.start:
		var left: int = ceili((line.start - t) / Leikkaus.BEAT)
		if left <= 3:
			dots.text = "● ".repeat(left).strip_edges()
			dots.position = Vector2(x0 - font.get_string_size("● ● ●  ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, y0)
			dots.modulate.a = a
			dots.visible = true
	return true


## Rivi, joka on vuorossa hetkellä t (-1 = ei mikään): ensimmäinen, jonka vaihtohetki ei ole vielä mennyt.
func _current(t: float) -> int:
	for i in lines.size():
		if t < _switch(i):
			return i
	return -1


## Hetki, jolloin rivi i väistyy: vähän viimeisen sanan jälkeen, mutta viimeistään puolivälissä seuraavaa riviä kohti.
func _switch(i: int) -> float:
	var end: float = lines[i].end
	if i + 1 < lines.size():
		return minf(end + HOLD, (end + lines[i + 1].start) / 2.0) if lines[i + 1].start - end < COUNT_GAP else end + HOLD
	return end + HOLD


## Laulettu osuus pikseleinä: kunkin sanan sisällä täyttö etenee kirjain kirjaimelta sanan keston mukaan.
func _sung_px(line: Dictionary, t: float, size: int) -> float:
	var text: String = line.text
	var pos := 0  # sanan alku merkkijonossa
	var chars := 0.0
	for wd in line.words:
		var word: String = wd[0]
		var at := text.find(word, pos)
		if at < 0:
			at = pos
		if t < wd[1]:
			break
		var frac := clampf((t - wd[1]) / maxf(wd[2] - wd[1], 0.05), 0.0, 1.0)
		chars = at + word.length() * frac
		pos = at + word.length()
	var whole := int(chars)
	var px := font.get_string_size(text.substr(0, whole), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if whole < text.length():
		px += font.get_string_size(text.substr(whole, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * (chars - whole)
	return px
