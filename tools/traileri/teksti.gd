extends RefCounted
## Trailerin tekstit (ohjaaja.gd ja kortti.gd): fontit, häivytykset, iso teksti, hahmoesittelyn nimi ja Puskaradio-
## puhelinkehys. Ei riipu pelin skripteistä, joten kortti.gd toimii ilman peliä (-s, ei autoloadeja).

const YELLOW := Color(1.0, 0.8, 0.1)
const PINK := Color(1.0, 0.45, 0.62)
const ORANGE := Color(1.0, 0.55, 0.2)


static func font(bold := true, script := false) -> Font:
	var f := SystemFont.new()
	if script:
		f.font_names = PackedStringArray(["Brush Script MT", "Segoe Script", "Ink Free"])
	else:
		f.font_names = PackedStringArray(["Impact", "Bahnschrift", "Arial Black", "Arial"])
	f.font_weight = 800 if bold else 400
	return f


static func label(root: Control, text: String, size: int, color: Color, font: Font, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)
	root.add_child(l)
	return l


## Häivytys sisään ja ulos (sekunteina) ajan t mukaan.
static func fade(c: CanvasItem, t: float, length: float, a := 0.35, b := 0.35) -> void:
	c.modulate.a = clampf(t / a, 0.0, 1.0) * clampf((length - t) / b, 0.0, 1.0)


static func build_texts(root: Control, shot: Dictionary, size: Vector2) -> void:
	var u := size.y / 1080.0  # mitat 1080p:n mukaan
	if shot.get("teksti", "") != "":
		var l := label(root, shot.teksti, int(78 * u), Color.WHITE, font(), int(6 * u))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(size.x, 120 * u)
		l.position = Vector2(0, size.y * 0.72)
		l.set_meta("anim", func(c: Control, t: float, length: float) -> void:
			fade(c, t - 0.25, length - 0.25, 0.5, 0.4)
			c.position.y = size.y * 0.72 + (1.0 - clampf((t - 0.25) / 0.6, 0.0, 1.0)) * 18.0 * u)
	if shot.has("nimi"):
		# GTA VI -tyyli: iso käsialanimi vasemmalla alhaalla, rooli pienellä alla. Kuva pysähtyy (ohjaaja: freeze).
		var n := label(root, shot.nimi, int(150 * u), Color.WHITE, font(true, true), int(4 * u))
		n.position = Vector2(110 * u, size.y * 0.56)
		var line := ColorRect.new()
		line.color = PINK
		line.size = Vector2(0, 6 * u)
		line.position = Vector2(118 * u, size.y * 0.56 + 178 * u)
		root.add_child(line)
		var r := label(root, shot.get("rooli", "").to_upper(), int(34 * u), Color(1, 0.93, 0.85), font(), int(3 * u))
		r.position = Vector2(118 * u, size.y * 0.56 + 196 * u)
		n.set_meta("anim", func(c: Control, t: float, length: float) -> void:
			fade(c, t - 0.15, length - 0.15, 0.25, 0.3)
			c.position.x = 110 * u - (1.0 - clampf((t - 0.15) / 0.5, 0.0, 1.0)) * 40.0 * u)
		line.set_meta("anim", func(c: Control, t: float, length: float) -> void:
			c.size.x = clampf((t - 0.3) / 0.45, 0.0, 1.0) * 520.0 * u
			fade(c, t, length, 0.01, 0.3))
		r.set_meta("anim", func(c: Control, t: float, length: float) -> void:
			fade(c, t - 0.45, length - 0.45, 0.3, 0.3))
	if shot.has("puhelin"):
		_phone(root, shot.puhelin, size, u)


## Puskaradio (GTA VI:n somevideot): pystyvideo keskellä puhelimen kehyksessä, sivuilla sama kuva suurennettuna ja
## sumeana, ryhmän nimi ylhäällä ja julkaisu tykkäyksineen alhaalla. Ohjaaja piilottaa mustat palkit tämän ajaksi.
static func _phone(root: Control, p: Dictionary, size: Vector2, u: float) -> void:
	var h := size.y * 0.94
	var w := h * 9.0 / 16.0
	var x0 := (size.x - w) / 2.0
	var y0 := (size.y - h) / 2.0
	var blur := ColorRect.new()
	blur.size = size
	blur.material = shader_mat("""shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec4 phone;  // x0, y0, x1, y1 (0..1)
void fragment() {
	vec2 uv = SCREEN_UV;
	if (uv.x > phone.x && uv.x < phone.z && uv.y > phone.y && uv.y < phone.w) {
		discard;
	}
	vec2 z = vec2(0.5) + (uv - vec2(0.5)) * 0.45;
	vec3 c = textureLod(screen, z, 4.5).rgb;
	COLOR = vec4(c * 0.42, 1.0);
}""")
	blur.material.set_shader_parameter("phone", Vector4(x0 / size.x, y0 / size.y, (x0 + w) / size.x, (y0 + h) / size.y))
	root.add_child(blur)
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(int(7 * u))
	sb.border_color = Color(0.05, 0.05, 0.06)
	sb.set_corner_radius_all(int(30 * u))
	frame.add_theme_stylebox_override("panel", sb)
	frame.position = Vector2(x0 - 6 * u, y0 - 6 * u)
	frame.size = Vector2(w + 12 * u, h + 12 * u)
	root.add_child(frame)
	var top := ColorRect.new()
	top.color = Color(0.09, 0.2, 0.42, 0.92)
	top.position = Vector2(x0, y0 + 40 * u)
	top.size = Vector2(w, 78 * u)
	root.add_child(top)
	var g := label(root, "  " + p.ryhma, int(34 * u), Color.WHITE, font(false))
	g.position = top.position + Vector2(8 * u, 16 * u)
	var bottom := ColorRect.new()
	bottom.color = Color(0, 0, 0, 0.62)
	bottom.position = Vector2(x0, y0 + h - 250 * u)
	bottom.size = Vector2(w, 250 * u)
	root.add_child(bottom)
	var who := label(root, p.nimi, int(34 * u), YELLOW, font())
	who.position = bottom.position + Vector2(24 * u, 14 * u)
	var txt := label(root, p.teksti, int(31 * u), Color.WHITE, font(false))
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size = Vector2(w - 48 * u, 130 * u)
	txt.position = bottom.position + Vector2(24 * u, 62 * u)
	var likes := label(root, "", int(30 * u), Color(1, 0.6, 0.65), font(false))
	likes.position = bottom.position + Vector2(24 * u, 196 * u)
	likes.set_meta("anim", func(c: Label, t: float, _l: float) -> void:
		var k := clampf(t / 2.5, 0.2, 1.0)
		c.text = "♥ %d    💬 %d    ↗ %d" % [int(p.tyk * k), int(p.tyk / 7 * k), int(p.tyk / 12 * k)])
	var rec := label(root, "● REC", int(28 * u), Color(1, 0.2, 0.2), font())
	rec.position = Vector2(x0 + w - 130 * u, top.position.y + 96 * u)
	rec.set_meta("anim", func(c: Control, t: float, _l: float) -> void: c.visible = fmod(t, 1.0) < 0.6)


## Varjostinmateriaali koodista. Koodi asetetaan ennen kuin Shader liitetään materiaaliin: jälkikäteen asetettu
## koodi ei päivity (pinta jää valkoiseksi).
static func shader_mat(code: String) -> ShaderMaterial:
	var s := Shader.new()
	s.code = code
	var m := ShaderMaterial.new()
	m.shader = s
	return m
