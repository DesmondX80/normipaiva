shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Lehvästökortti: lehti/neulastekstuuri alfaleikkauksella, instanssiväri, kohinavaihtelu,
// tuulihuojunta ja läpikuultava valo (backlight). Käytetään puissa ja pensasaidoissa.

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float sway = 0.06;
uniform float cutoff = 0.45;

varying vec3 wpos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float s = sin(TIME * 1.3 + wp.x * 0.13 + wp.z * 0.09) * sway * h * 0.12
		+ sin(TIME * 3.7 + wp.x * 1.3 + wp.y) * sway * 0.15;
	VERTEX.x += s;
	VERTEX.z += s * 0.6;
	wpos = wp;
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	float n = texture(noise_tex, wpos.xz * 0.15 + vec2(wpos.y * 0.1)).r;
	ALBEDO = t.rgb * COLOR.rgb * (0.75 + n * 0.5);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = cutoff;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = t.rgb * COLOR.rgb * 0.55;
}
