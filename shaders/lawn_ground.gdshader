shader_type spatial;
render_mode cull_disabled;
// Kotipihan nurmikon pohja (lawn.gd): pitkä ruoho tummaa ja rehevää, leikattu vaaleaa, joten leikkurin
// jälki erottuu. Pituus samasta leikkuuruudukosta kuin korsilla.

uniform vec2 origin = vec2(0.0);
uniform vec2 size = vec2(1.0);
uniform sampler2D cut : filter_linear;
uniform float max_len = 0.8;
uniform vec3 long_col : source_color = vec3(0.17, 0.33, 0.1);
uniform vec3 cut_col : source_color = vec3(0.42, 0.62, 0.24);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec2 v_wp;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float len = texture(cut, (v_wp - origin) / size).r * max_len;
	float n = texture(noise_tex, v_wp * 0.08).r;
	float fine = texture(noise_tex, v_wp * 0.9).r;
	vec3 col = mix(cut_col, long_col, smoothstep(0.05, 0.3, len));
	col *= 0.82 + n * 0.25 + fine * 0.12;
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
