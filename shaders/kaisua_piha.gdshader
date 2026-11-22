shader_type spatial;
render_mode cull_disabled;
// Kaisuan pihan sora (kaisua.gd _build_gravel): harmaanruskea sora pikkukivineen, renkaanjäljet ja reunalla
// nurmen ja soran sekoitus. Ympyröiden (x, z, säde) ulkopuoli karsitaan kohinan mukaan rikkonaiseksi reunaksi.

uniform vec3 circles[4];
uniform int circle_count = 0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec2 v_p;

void vertex() {
	v_p = VERTEX.xz;
}

void fragment() {
	float d = 1e6;
	for (int i = 0; i < circle_count; i++) {
		d = min(d, length(v_p - circles[i].xy) - circles[i].z);
	}
	float n = texture(noise_tex, v_p * 0.09).r;
	float edge = d + (n - 0.5) * 6.0;
	if (edge > 0.0) {
		discard;
	}
	float fine = texture(noise_tex, v_p * 1.7).r;
	float stones = texture(noise_tex, v_p * 4.3 + vec2(13.1, 7.7)).r;
	vec3 gravel = mix(vec3(0.4, 0.36, 0.3), vec3(0.55, 0.5, 0.42), n);
	gravel *= 0.8 + fine * 0.4;
	// Ajourat: kaksi tummempaa, kulunutta uraa pihan halki (koneiden tavallinen reitti).
	float rut = texture(noise_tex, v_p * vec2(0.02, 0.35)).r;
	gravel *= 1.0 - 0.12 * smoothstep(0.55, 0.7, rut);
	gravel = mix(gravel, vec3(0.66, 0.63, 0.58), smoothstep(0.68, 0.74, stones) * 0.6);
	gravel = mix(gravel, vec3(0.24, 0.21, 0.18), smoothstep(0.3, 0.24, stones) * 0.35);
	// Reunalla nurmitupsuja ja multaa soran seassa.
	float grass = smoothstep(-5.0, 0.0, edge) * smoothstep(0.45, 0.6, fine);
	vec3 col = mix(gravel, vec3(0.25, 0.36, 0.14) * (0.8 + n * 0.4), grass);
	ALBEDO = col;
	ROUGHNESS = 0.96;
}
