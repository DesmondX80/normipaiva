shader_type spatial;
render_mode cull_disabled;
// Maanpinta: kaksi väriä sekoitettuna maailmankoordinaattien kohinalla + pieni kuoppaisuus.

uniform vec3 color_a : source_color = vec3(0.35, 0.5, 0.22);
uniform vec3 color_b : source_color = vec3(0.5, 0.62, 0.3);
uniform float scale = 0.02;
uniform float fine_scale = 0.35;
uniform float stripes = 0.0;
uniform float stripe_angle = 0.0;
uniform float roughness_v = 0.95;
uniform float bump = 0.4;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	float n = texture(noise_tex, p * scale * 0.15).r;
	float m = texture(noise_tex, p * scale).r;
	float f = texture(noise_tex, p * fine_scale).r;
	float t = clamp(n * 0.6 + m * 0.4 + (f - 0.5) * 0.3, 0.0, 1.0);
	vec3 col = mix(color_a, color_b, smoothstep(0.2, 0.8, t));
	if (stripes > 0.0) {
		vec2 dir = vec2(cos(stripe_angle), sin(stripe_angle));
		col *= 0.88 + 0.12 * sin(dot(p, dir) * stripes);
	}
	ALBEDO = col;
	ROUGHNESS = roughness_v;
	float e = 0.4;
	float fx = texture(noise_tex, (p + vec2(e, 0.0)) * fine_scale).r - f;
	float fz = texture(noise_tex, (p + vec2(0.0, e)) * fine_scale).r - f;
	vec3 nw = normalize(wnorm + vec3(-fx * bump * 6.0, 0.0, -fz * bump * 6.0));  // rinteen normaali + kuoppaisuus
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
