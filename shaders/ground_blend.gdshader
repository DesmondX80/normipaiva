shader_type spatial;
render_mode cull_disabled;
// Vaalan maasto yhtenä meshinä: maankäytön värit verteksiväreinä (COLOR = väri a, CUSTOM0.rgb = väri b,
// CUSTOM0.a = sorapintaisuus), joten pellon, pihan, metsänpohjan ja pientareen rajat liukuvat ruudun matkalla
// eivätkä näy 4 m portaina. Kuvio kuten ground.gdshaderissa (maailmankoordinaattien kohina + kuoppaisuus).

uniform float scale = 0.04;
uniform float roughness_v = 0.95;
uniform float bump = 0.7;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnorm;
varying vec3 col_a;
varying vec4 col_b;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	col_a = COLOR.rgb;
	col_b = CUSTOM0;
}

void fragment() {
	vec2 p = wpos.xz;
	float n = texture(noise_tex, p * scale * 0.15).r;
	float m = texture(noise_tex, p * scale).r;
	// Hieno kuvio kahdella taajuudella (nurmi/metsänpohja ja sora): sekoitetaan, ei venytetä taajuutta.
	float fine = col_b.a;
	float f = mix(texture(noise_tex, p * 0.7).r, texture(noise_tex, p * 1.4).r, fine);
	float t = clamp(n * 0.6 + m * 0.4 + (f - 0.5) * 0.3, 0.0, 1.0);
	ALBEDO = mix(col_a, col_b.rgb, smoothstep(0.2, 0.8, t));
	ROUGHNESS = roughness_v;
	float fs = mix(0.7, 1.4, fine);
	float e = 0.4;
	float fx = texture(noise_tex, (p + vec2(e, 0.0)) * fs).r - texture(noise_tex, p * fs).r;
	float fz = texture(noise_tex, (p + vec2(0.0, e)) * fs).r - texture(noise_tex, p * fs).r;
	vec3 nw = normalize(wnorm + vec3(-fx * bump * 6.0, 0.0, -fz * bump * 6.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
