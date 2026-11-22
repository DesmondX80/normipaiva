shader_type spatial;
render_mode cull_disabled;
// Kaisuan pellon pinta (kaisua_pelto.gd): väri ruudun tilasta (kaisua_tila.gd), neljän lähimmän ruudun värit
// sekoitetaan, ettei 0,5 m ruudukko näy portaina. Työsuunta (B) antaa niittojäljen kaistat, äkeen viirut, kylvörivit
// ja orasrivit ajosuuntaan. Ruutu ilman peltoa (NONE) jätetään piirtämättä, jolloin alla näkyy maasto.

uniform sampler2D state_tex : filter_nearest;  // R = tila * 8, G = määrä * 8, B = työsuunta (0–255 = 0–180°)
uniform vec2 origin = vec2(0.0);
uniform vec2 cells = vec2(1.0);
uniform float cell = 0.5;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec2 v_p;

void vertex() {
	v_p = VERTEX.xz;
}

int sid(vec4 t) {
	return int(t.r * 255.0 / 8.0 + 0.5);
}

vec4 st_at(ivec2 c) {
	return texelFetch(state_tex, clamp(c, ivec2(0), ivec2(cells) - 1), 0);
}

float stripes(float x, float period, float width) {
	float f = fract(x / period);
	return smoothstep(0.0, width, f) * (1.0 - smoothstep(1.0 - width, 1.0, f));
}

vec3 soil(vec2 p, float n, float fine) {
	vec3 c = mix(vec3(0.19, 0.13, 0.085), vec3(0.3, 0.21, 0.13), n);
	return c * (0.8 + fine * 0.4);
}

vec3 ground_col(vec4 t, vec2 p, float n, float fine) {
	int s = sid(t);
	float a = t.b * 3.14159265;
	vec2 dv = vec2(cos(a), sin(a));
	float across = dot(p, vec2(-dv.y, dv.x));
	float along = dot(p, dv);
	if (s >= 1 && s <= 3) {
		vec3 g = mix(vec3(0.13, 0.27, 0.07), vec3(0.24, 0.4, 0.11), n);
		return g * (0.85 + fine * 0.3) * (1.0 - 0.1 * float(s - 1));
	}
	if (s == 4) {  // niitetty sarka: kuivuvaa heinää sängen päällä
		vec3 hay = mix(vec3(0.33, 0.45, 0.15), vec3(0.45, 0.55, 0.22), n);
		return hay * (0.85 + fine * 0.3);
	}
	if (s == 5 || s == 6) {  // sänki: niittokoneen kaistat ajosuuntaan
		vec3 st = mix(vec3(0.42, 0.5, 0.22), vec3(0.56, 0.6, 0.31), n);
		st *= 0.92 + 0.08 * stripes(across, 7.2, 0.5);
		return st * (0.85 + fine * 0.3);
	}
	if (s == 10) {  // vanha sänki ja multaa välissä
		vec3 st = mix(vec3(0.5, 0.45, 0.31), vec3(0.62, 0.56, 0.38), fine);
		return mix(st, soil(p, n, fine), smoothstep(0.45, 0.75, n) * 0.6);
	}
	if (s == 11) {  // äestetty: tuore multa, piikkien viirut
		vec3 c = soil(p, n, fine) * 0.9;
		return c * (0.88 + 0.12 * stripes(across, 0.22, 0.35));
	}
	if (s == 12) {  // kylvetty: tasainen multa, kylvövantaiden rivit 12,5 cm välein
		vec3 c = soil(p, n, fine) * 1.08;
		return c * (0.86 + 0.14 * stripes(across, 0.125, 0.3));
	}
	if (s == 13) {  // oras: vihreät rivit mullassa
		vec3 c = soil(p, n, fine);
		float row = 1.0 - stripes(across + 0.03, 0.125, 0.4);
		return mix(c, vec3(0.28, 0.5, 0.13) * (0.85 + fine * 0.3), row * 0.75);
	}
	if (s == 14) {
		return mix(vec3(0.17, 0.32, 0.09), vec3(0.26, 0.42, 0.12), n) * (0.85 + fine * 0.3);
	}
	if (s == 15) {  // kypsä ohra
		return mix(vec3(0.62, 0.5, 0.24), vec3(0.78, 0.65, 0.33), n) * (0.85 + fine * 0.3);
	}
	if (s == 16 || s == 17) {  // puitu sänki: leikkuupöydän kaistat
		vec3 st = mix(vec3(0.6, 0.53, 0.33), vec3(0.74, 0.65, 0.41), n);
		st *= 0.93 + 0.07 * stripes(across, 8.4, 0.5);
		return st * (0.85 + fine * 0.3);
	}
	return vec3(0.3, 0.35, 0.2);
}

void fragment() {
	vec2 g = (v_p - origin) / cell - 0.5;
	ivec2 i0 = ivec2(floor(g));
	vec2 f = fract(g);
	ivec2 near = ivec2(floor(g + 0.5));
	vec4 tn = st_at(near);
	if (sid(tn) == 0) {
		discard;
	}
	vec4 t00 = st_at(i0);
	vec4 t10 = st_at(i0 + ivec2(1, 0));
	vec4 t01 = st_at(i0 + ivec2(0, 1));
	vec4 t11 = st_at(i0 + ivec2(1, 1));
	t00 = sid(t00) == 0 ? tn : t00;
	t10 = sid(t10) == 0 ? tn : t10;
	t01 = sid(t01) == 0 ? tn : t01;
	t11 = sid(t11) == 0 ? tn : t11;
	float n = texture(noise_tex, v_p * 0.035).r;
	float fine = texture(noise_tex, v_p * 0.8).r;
	vec3 c00 = ground_col(t00, v_p, n, fine);
	vec3 c10 = ground_col(t10, v_p, n, fine);
	vec3 c01 = ground_col(t01, v_p, n, fine);
	vec3 c11 = ground_col(t11, v_p, n, fine);
	vec2 w = smoothstep(0.15, 0.85, f);
	ALBEDO = mix(mix(c00, c10, w.x), mix(c01, c11, w.x), w.y);
	ROUGHNESS = 0.95;
}
