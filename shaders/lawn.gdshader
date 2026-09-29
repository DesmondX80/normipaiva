shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;
// Kotipihan nurmikko (lawn.gd): tupsut tasavälein suorakaiteessa, korren pituus leikkuuruudukosta
// (R = pituus / max_len). Leikattu nurmi on vaaleampaa, joten leikkurin jälki erottuu.

uniform vec2 origin = vec2(0.0);
uniform vec2 size = vec2(1.0);
uniform int cols = 1;
uniform float spacing = 0.16;
uniform sampler2D cut : filter_nearest;
uniform float max_len = 0.8;
uniform vec3 base_col : source_color = vec3(0.14, 0.3, 0.08);
uniform vec3 tip_col : source_color = vec3(0.5, 0.7, 0.26);
uniform vec3 cut_col : source_color = vec3(0.52, 0.72, 0.3);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D terrain_h : filter_linear, repeat_disable;  // maaston korkeus (R, metriä)
uniform vec2 terrain_origin = vec2(0.0);
uniform vec2 terrain_cells = vec2(1.0);
uniform float terrain_cell = 5.0;

varying float v_h;
varying float v_len;
varying float v_tint;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	vec2 cell = vec2(float(INSTANCE_ID % cols), float(INSTANCE_ID / cols));
	vec2 wp = origin + (cell + vec2(hash(cell), hash(cell + 17.3))) * spacing;
	float len = textureLod(cut, (wp - origin) / size, 0.0).r * max_len;
	float h = len * (0.75 + hash(cell + 2.2) * 0.5);
	float ang = hash(cell + 9.7) * 6.2831;
	v_h = VERTEX.y;
	vec3 v = VERTEX;
	v.xz *= 0.7 + hash(cell + 3.3) * 0.6;
	float ca = cos(ang);
	float sa = sin(ang);
	v.xz = vec2(ca * v.x - sa * v.z, sa * v.x + ca * v.z);
	v.y *= h;
	float w = sin(TIME * 1.6 + wp.x * 0.25 + wp.y * 0.18) * 0.14 + sin(TIME * 3.3 + wp.x * 0.9) * 0.04;
	v.xz += vec2(w, w * 0.6) * v_h * h;
	vec2 tuv = ((wp - terrain_origin) / terrain_cell + 0.5) / terrain_cells;
	float gh = textureLod(terrain_h, tuv, 0.0).r;
	vec3 world = vec3(wp.x, gh, wp.y) + v;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	v_len = len;
	v_tint = textureLod(noise_tex, wp * 0.05, 0.0).r;
}

void fragment() {
	vec3 col = mix(base_col, tip_col, v_h);
	col = mix(col, cut_col, (1.0 - smoothstep(0.06, 0.3, v_len)) * 0.7);
	col *= 0.8 + v_tint * 0.4;
	ALBEDO = col;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.25, 0.3, 0.1);
}
