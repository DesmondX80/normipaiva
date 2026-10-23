shader_type spatial;
render_mode cull_disabled;
// Karhu-kutosen pahvikoppa pelaajan päässä (looks.gd add_koppa): ulkopinnassa painatus (assets/karhu_koppa.png,
// pullonkaulojen reiät läpinäkyvinä), sisäpinta harmaanruskeaa kartonkia. Painopinta on lakattu ja kiiltää hieman.

uniform sampler2D art : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 kraft : source_color = vec3(0.55, 0.47, 0.38);

void fragment() {
	vec4 t = texture(art, UV);
	if (t.a < 0.5) {
		discard;
	}
	if (FRONT_FACING) {
		ALBEDO = t.rgb;
		ROUGHNESS = 0.45;
		SPECULAR = 0.5;
	} else {
		// Kartongin kuitu: hienot pystyraidat.
		float fiber = 0.92 + 0.08 * sin(UV.x * 2400.0 + sin(UV.y * 40.0) * 3.0);
		ALBEDO = kraft * fiber;
		ROUGHNESS = 0.95;
	}
}
