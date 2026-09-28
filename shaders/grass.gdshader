shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;
// Ruoho pelaajan ympärillä: ruudukko seuraa pelaajaa, sijainnit tiivisteestä -> pysyvät paikallaan.
// Maskikuva (R = ruohon tiheys, G = viljapelto) estää ruohon teillä, vedessä ja talojen alla.

uniform vec3 center = vec3(0.0);
uniform float spacing = 0.6;
uniform int grid = 160;
uniform sampler2D mask : filter_nearest;
uniform vec2 map_origin = vec2(0.0);
uniform vec2 map_size = vec2(1.0);
uniform vec3 base_col : source_color = vec3(0.16, 0.3, 0.09);
uniform vec3 tip_col : source_color = vec3(0.55, 0.7, 0.28);
uniform vec3 crop_col : source_color = vec3(0.85, 0.76, 0.42);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D terrain_h : filter_linear, repeat_disable;  // maaston korkeus (R, metriä)
uniform vec2 terrain_origin = vec2(0.0);
uniform vec2 terrain_cells = vec2(1.0);  // ruutuja x, z
uniform float terrain_cell = 5.0;

varying float v_h;
varying float v_crop;
varying float v_tint;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	int gx = INSTANCE_ID % grid;
	int gz = INSTANCE_ID / grid;
	vec2 cell = floor(center.xz / spacing) + vec2(float(gx - grid / 2), float(gz - grid / 2));
	vec2 wp = (cell + vec2(hash(cell), hash(cell + 17.3))) * spacing;
	vec2 muv = (wp - map_origin) / map_size;
	vec4 m = textureLod(mask, muv, 0.0);
	float inside = step(0.0, muv.x) * step(muv.x, 1.0) * step(0.0, muv.y) * step(muv.y, 1.0);
	float keep = (m.r < 0.05) ? 0.0 : step(hash(cell + 5.1), m.r) * inside;
	float d = length(wp - center.xz);
	float radius = float(grid) * spacing * 0.5;
	float fade = 1.0 - smoothstep(radius * 0.6, radius * 0.95, d);
	float crop = m.g;
	float h = mix(0.3 + hash(cell + 2.2) * 0.4, 0.95 + hash(cell + 4.4) * 0.2, crop) * keep * fade;
	float ang = hash(cell + 9.7) * 6.2831;
	v_h = VERTEX.y;
	vec3 v = VERTEX;
	v.xz *= (0.7 + hash(cell + 3.3) * 0.6) * step(0.001, h);
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
	v_crop = crop;
	v_tint = textureLod(noise_tex, wp * 0.015, 0.0).r;
}

void fragment() {
	vec3 col = mix(base_col, tip_col, v_h);
	col = mix(col, crop_col * mix(0.65, 1.1, v_h), v_crop);
	col *= 0.75 + v_tint * 0.5;
	ALBEDO = col;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.25, 0.3, 0.1);
}
