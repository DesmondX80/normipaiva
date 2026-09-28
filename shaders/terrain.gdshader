shader_type spatial;
render_mode cull_disabled;
// Maasto: korkeusmallin mukainen verkko, pinnat pintakartasta (R metsä, G pelto, B räme, A hakkuuaukio,
// muualla niitty). Pehmeät reunat pintojen välissä; kukin pinta kuten ground.gdshader.

uniform sampler2D splat : filter_linear, repeat_disable;
uniform vec2 map_lo = vec2(0.0);
uniform vec2 map_size = vec2(1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// Pinnat: a, b, (scale, fine_scale, bump, roughness)
uniform vec3 meadow_a : source_color; uniform vec3 meadow_b : source_color; uniform vec4 meadow_p;
uniform vec3 forest_a : source_color; uniform vec3 forest_b : source_color; uniform vec4 forest_p;
uniform vec3 field_a : source_color; uniform vec3 field_b : source_color; uniform vec4 field_p;
uniform vec3 bog_a : source_color; uniform vec3 bog_b : source_color; uniform vec4 bog_p;
uniform vec3 cut_a : source_color; uniform vec3 cut_b : source_color; uniform vec4 cut_p;
uniform float field_stripes = 2.2;
uniform float stripe_angle = 0.35;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 surf(vec2 p, vec3 a, vec3 b, vec4 prm, out float fine) {
	float n = texture(noise_tex, p * prm.x * 0.15).r;
	float m = texture(noise_tex, p * prm.x).r;
	fine = texture(noise_tex, p * prm.y).r;
	float t = clamp(n * 0.6 + m * 0.4 + (fine - 0.5) * 0.3, 0.0, 1.0);
	return mix(a, b, smoothstep(0.2, 0.8, t));
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 suv = (p - map_lo) / map_size;
	vec4 w = texture(splat, suv);
	if (suv.x < 0.0 || suv.y < 0.0 || suv.x > 1.0 || suv.y > 1.0) {
		w = vec4(0.0);
	}
	// Rosoinen reuna pintojen väliin kohinalla.
	float edge_n = texture(noise_tex, p * 0.21).r - 0.5;
	w = clamp((w - 0.5) * 3.0 + 0.5 + edge_n * 0.9, 0.0, 1.0);
	float f0; float f1; float f2; float f3; float f4;
	vec3 col = surf(p, meadow_a, meadow_b, meadow_p, f0);
	vec4 prm = meadow_p;
	float fine = f0;
	vec3 c1 = surf(p, forest_a, forest_b, forest_p, f1);
	col = mix(col, c1, w.r); prm = mix(prm, forest_p, w.r); fine = mix(fine, f1, w.r);
	vec3 c2 = surf(p, field_a, field_b, field_p, f2);
	vec2 dir = vec2(cos(stripe_angle), sin(stripe_angle));
	c2 *= 0.88 + 0.12 * sin(dot(p, dir) * field_stripes);
	col = mix(col, c2, w.g); prm = mix(prm, field_p, w.g); fine = mix(fine, f2, w.g);
	vec3 c3 = surf(p, bog_a, bog_b, bog_p, f3);
	col = mix(col, c3, w.b); prm = mix(prm, bog_p, w.b); fine = mix(fine, f3, w.b);
	vec3 c4 = surf(p, cut_a, cut_b, cut_p, f4);
	col = mix(col, c4, w.a); prm = mix(prm, cut_p, w.a); fine = mix(fine, f4, w.a);
	ALBEDO = col;
	ROUGHNESS = prm.w;
	float e = 0.4;
	float fx = texture(noise_tex, (p + vec2(e, 0.0)) * prm.y).r - fine;
	float fz = texture(noise_tex, (p + vec2(0.0, e)) * prm.y).r - fine;
	vec3 nw = normalize(wnorm + vec3(-fx * prm.z * 6.0, 0.0, -fz * prm.z * 6.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
