extends SceneTree
## Trailerin mustat kortit ja loppulogo ilman peliä (leikkaus.gd: g = "kortit").
## Ajo (renderoi.gd hoitaa): godot --path . [--write-movie x.avi --fixed-fps 30] -s tools/traileri/kortti.gd --
##   --trailer=id1,id2 --out=kansio [--trailer-preview]
## Kuten ohjaaja.gd: magenta erotinruudut ennen ja jälkeen jokaisen kortin, esikatselussa kuvat.

const Leikkaus := preload("res://tools/traileri/leikkaus.gd")
const Teksti := preload("res://tools/traileri/teksti.gd")

const SEP_FRAMES := 4
const SUNSET := [Color(1.0, 0.86, 0.3), Color(1.0, 0.5, 0.25), Color(0.96, 0.3, 0.55), Color(0.55, 0.3, 0.75)]

var ids: PackedStringArray
var out := "user://traileri"
var preview := false
var root_c: Control
var sep: ColorRect


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trailer="):
			ids = a.substr(10).split(",")
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--trailer-preview":
			preview = true
	DirAccess.make_dir_recursive_absolute(out)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	root_c = Control.new()
	root_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root_c)
	sep = ColorRect.new()
	sep.color = Color(1, 0, 1)
	sep.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(sep)
	_run.call_deferred()


func _run() -> void:
	for i in 10:
		await process_frame
	await _separator()
	var log := []
	for id in ids:
		var shot := Leikkaus.shot(id)
		var frames := Leikkaus.frames_of(id)
		var size := root.get_visible_rect().size
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		root_c.add_child(bg)
		var anims := _build(shot, size)
		var snaps := [0, frames / 2, frames - 1]
		for i in frames:
			var t := float(i) / Leikkaus.FPS
			for a in anims:
				a.call(t, float(frames) / Leikkaus.FPS)
			await process_frame
			if preview and i in snaps:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(out.path_join("%s_%d.png" % [id, snaps.find(i)]))
		for c in root_c.get_children():
			c.queue_free()
		await _separator()
		log.append({"id": id, "frames": frames})
	var f := FileAccess.open(out.path_join("ryhma_%s.json" % ids[0]), FileAccess.WRITE)
	f.store_string(JSON.stringify(log, "\t"))
	f.close()
	quit()


func _separator() -> void:
	sep.visible = true
	for i in SEP_FRAMES:
		await process_frame
	sep.visible = false


func _build(shot: Dictionary, size: Vector2) -> Array:
	var u := size.y / 1080.0
	var anims := []
	if shot.get("logo", false):
		return _logo(size, u)
	if shot.has("lappu"):
		return _lappu(shot.lappu, size, u)
	if shot.get("kortti", "") == "":
		return anims
	var title := Teksti.label(root_c, shot.kortti, int(118 * u), Color.WHITE, Teksti.font(), 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(size.x, 160 * u)
	title.position = Vector2(0, size.y * 0.5 - 120 * u)
	title.material = _gradient_mat(title, 160 * u)
	var sub := Teksti.label(root_c, shot.get("ala", ""), int(46 * u), Color(0.95, 0.93, 0.88), Teksti.font(false), 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(size.x, 80 * u)
	sub.position = Vector2(0, size.y * 0.5 + 50 * u)
	anims.append(func(t: float, l: float) -> void:
		Teksti.fade(title, t, l, 0.3, 0.3)
		title.scale = Vector2.ONE * (1.0 + 0.03 * t / l)
		title.pivot_offset = title.size / 2.0)
	anims.append(func(t: float, l: float) -> void: Teksti.fade(sub, t - 0.35, l - 0.35, 0.4, 0.3))
	return anims


## Loppulogo: NORMIPÄIVÄ auringonlaskun liukuvärillä, SALOISISSA harvennettuna alla, sitten "+ MÖKKI JA VAALA" ja PIAN.
func _logo(size: Vector2, u: float) -> Array:
	var glow := ColorRect.new()
	glow.size = size
	glow.material = Teksti.shader_mat("""shader_type canvas_item;
uniform float k = 0.0;
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.48)) * vec2(1.6, 1.0);
	float g = exp(-dot(d, d) * 9.0) * k;
	COLOR = vec4(mix(vec3(0.0), vec3(0.55, 0.16, 0.32), g), 1.0);
}""")
	root_c.add_child(glow)
	var title := Teksti.label(root_c, "NORMIPÄIVÄ", int(230 * u), Color.WHITE, Teksti.font(), 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(size.x, 290 * u)
	title.position = Vector2(0, size.y * 0.5 - 250 * u)
	title.pivot_offset = title.size / 2.0
	title.material = _gradient_mat(title, 290 * u)
	var sub := Teksti.label(root_c, "S  A  L  O  I  S  I  S  S  A", int(58 * u), Color.WHITE, Teksti.font(false), 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(size.x, 80 * u)
	sub.position = Vector2(0, size.y * 0.5 + 40 * u)
	var plus := Teksti.label(root_c, "+ MÖKKI JA VAALA", int(36 * u), Teksti.YELLOW, Teksti.font(), 0)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.size = Vector2(size.x, 60 * u)
	plus.position = Vector2(0, size.y * 0.5 + 130 * u)
	var soon := Teksti.label(root_c, "PIAN", int(44 * u), Color(1, 1, 1, 0.9), Teksti.font(), 0)
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soon.size = Vector2(size.x, 60 * u)
	soon.position = Vector2(0, size.y * 0.86)
	return [
		func(t: float, l: float) -> void:
			glow.material.set_shader_parameter("k", clampf(t / 1.5, 0.0, 1.0) * clampf((l - t) / 0.8, 0.0, 1.0)),
		func(t: float, l: float) -> void:
			Teksti.fade(title, t, l, 0.15, 0.8)
			title.scale = Vector2.ONE * (1.12 - 0.12 * clampf(t / 0.5, 0.0, 1.0) * (2.0 - clampf(t / 0.5, 0.0, 1.0)) + 0.02 * t / l),
		func(t: float, l: float) -> void: Teksti.fade(sub, t - 0.6, l - 0.6, 0.5, 0.8),
		func(t: float, l: float) -> void: Teksti.fade(plus, t - 1.4, l - 1.4, 0.5, 0.8),
		func(t: float, l: float) -> void: Teksti.fade(soon, t - 2.6, l - 2.6, 0.6, 0.8),
	]


## Päivin heippalappu keittiön pöydällä: rivit [teksti, väri] käsialalla, teippi yläreunassa, hidas zoomaus.
func _lappu(lines: Array, size: Vector2, u: float) -> Array:
	var table := ColorRect.new()
	table.size = size
	table.material = Teksti.shader_mat("""shader_type canvas_item;
float n(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float grain = sin(UV.y * 90.0 + sin(UV.x * 7.0) * 3.0 + n(floor(UV * vec2(4.0, 60.0))) * 2.0) * 0.5 + 0.5;
	vec3 wood = mix(vec3(0.36, 0.22, 0.12), vec3(0.47, 0.31, 0.17), grain);
	float plank = step(0.985, fract(UV.y * 5.0));
	wood *= 1.0 - plank * 0.45;
	float vig = smoothstep(1.1, 0.35, length(UV - 0.5) * 1.4);
	COLOR = vec4(wood * (0.45 + 0.55 * vig), 1.0);
}""")
	root_c.add_child(table)
	var paper := Control.new()
	var pw := 760.0 * u
	var ph := (150.0 + 74.0 * lines.size()) * u
	paper.size = Vector2(pw, ph)
	paper.pivot_offset = paper.size / 2.0
	paper.position = (size - paper.size) / 2.0
	paper.rotation = deg_to_rad(-2.5)
	root_c.add_child(paper)
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.size = paper.size
	shadow.position = Vector2(14, 18) * u
	paper.add_child(shadow)
	var sheet := ColorRect.new()
	sheet.color = Color(1.0, 0.97, 0.82)
	sheet.size = paper.size
	paper.add_child(sheet)
	for i in lines.size() + 1:
		var rule := ColorRect.new()
		rule.color = Color(0.55, 0.7, 0.9, 0.45)
		rule.size = Vector2(pw - 60 * u, 2 * u)
		rule.position = Vector2(30 * u, (128 + 74 * i) * u)
		paper.add_child(rule)
	var tape := ColorRect.new()
	tape.color = Color(0.95, 0.95, 0.85, 0.55)
	tape.size = Vector2(220 * u, 52 * u)
	tape.position = Vector2(pw / 2.0 - 110 * u, -26 * u)
	tape.rotation = deg_to_rad(3.0)
	paper.add_child(tape)
	var hand := SystemFont.new()
	hand.font_names = PackedStringArray(["Ink Free", "Segoe Print", "Comic Sans MS"])
	var labels := []
	for i in lines.size():
		var l := Label.new()
		l.text = lines[i][0]
		l.add_theme_font_override("font", hand)
		l.add_theme_font_size_override("font_size", int(56 * u))
		l.add_theme_color_override("font_color", lines[i][1])
		l.position = Vector2(48 * u, (52 + 74 * i) * u)
		l.rotation = deg_to_rad(randf_range(-1.5, 1.0))
		paper.add_child(l)
		labels.append(l)
	return [
		func(t: float, l: float) -> void:
			paper.scale = Vector2.ONE * lerpf(0.92, 1.08, t / l)
			paper.modulate.a = clampf(t / 0.4, 0.0, 1.0) * clampf((l - t) / 0.3, 0.0, 1.0),
		func(t: float, _l: float) -> void:
			for i in labels.size():  # rivit "kirjoitetaan" yksi kerrallaan
				labels[i].visible_ratio = clampf((t - 0.3 - i * 0.45) / 0.4, 0.0, 1.0),
	]


## Pystysuuntainen auringonlaskuliukuväri tekstille (kirjainten alfa säilyy).
func _gradient_mat(l: Label, h: float) -> ShaderMaterial:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))  # varjostin värjäisi varjon: haamukopio
	var m := Teksti.shader_mat("""shader_type canvas_item;
uniform vec4 c0 : source_color;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform float top;
uniform float height;
varying float y;
void vertex() { y = VERTEX.y; }
void fragment() {
	float k = clamp((y - top) / height, 0.0, 1.0);
	vec3 c = k < 0.33 ? mix(c0.rgb, c1.rgb, k / 0.33) : (k < 0.66 ? mix(c1.rgb, c2.rgb, (k - 0.33) / 0.33) : mix(c2.rgb, c3.rgb, (k - 0.66) / 0.34));
	COLOR = vec4(c, COLOR.a);
}""")
	for i in 4:
		m.set_shader_parameter("c%d" % i, SUNSET[i])
	m.set_shader_parameter("top", h * 0.18)
	m.set_shader_parameter("height", h * 0.62)
	return m
