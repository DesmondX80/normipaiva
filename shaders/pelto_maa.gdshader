shader_type spatial;
render_mode cull_disabled;
// Kaisuan pellon pinta (kaisua_pelto.gd): väri ruudun tilasta (kaisua_tila.gd), neljän lähimmän ruudun värit
// sekoitetaan, ettei 0,5 m ruudukko näy portaina. Työsuunta (B) antaa niittojäljen kaistat, äkeen viirut, kylvörivit
// ja orasrivit ajosuuntaan. Ruutu ilman peltoa (NONE) jätetään piirtämättä, jolloin alla näkyy maasto; raja kulkee
// ruutujen välissä peiton mukaan kohinalla rikottuna (ei portaita).

uniform sampler2D state_tex : filter_nearest;  // R8: tila (kaisua_tila.gd)
uniform sampler2D dir_tex : filter_nearest;  // R8: työsuunta (0–1 = 0–180°)
uniform vec2 origin = vec2(0.0);
uniform vec2 cells = vec2(1.0);
uniform float cell = 0.5;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float wet = 0.0;  // sade (kaisua.gd): tummempi ja kiiltävämpi

varying vec2 v_p;

void vertex() {
	v_p = VERTEX.xz;
}

int st_at(ivec2 c) {
	return int(texelFetch(state_tex, clamp(c, ivec2(0), ivec2(cells) - 1), 0).r * 255.0 + 0.5);
}

float dir_at(ivec2 c) {
	return texelFetch(dir_tex, clamp(c, ivec2(0), ivec2(cells) - 1), 0).r;
}

float stripes(float x, float period, float width) {
	float f = fract(x / period);
	return smoothstep(0.0, width, f) * (1.0 - smoothstep(1.0 - width, 1.0, f));
}

vec3 soil(vec2 p, float n, float fine) {
	vec3 c = mix(vec3(0.19, 0.13, 0.085), vec3(0.3, 0.21, 0.13), n);
	return c * (0.8 + fine * 0.4);
}

vec3 ground_col(int s, float dirv, vec2 p, float n, float fine) {
	float a = dirv * 3.14159265;
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
	if (s == 5) {  // karhon alla kuivaa heinää yhtenäisenä kaistana
		vec3 hay = mix(vec3(0.43, 0.48, 0.2), vec3(0.6, 0.62, 0.3), n);
		return hay * (0.78 + fine * 0.42);
	}
	if (s == 6) {  // sänki: niittokoneen kaistat ajosuuntaan
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
	if (s == 18) {  // kynnetty: auran kääntämät palteet ja vaot ajosuuntaan (35 cm välein), palteen harja vaalea
		vec3 c = soil(p, n, fine) * 0.95;
		float f = fract(across / 0.35 + fine * 0.15);
		float ridge = sin(f * 3.14159265);
		c *= 0.62 + 0.55 * ridge;
		return mix(c, vec3(0.42, 0.36, 0.24), smoothstep(0.85, 1.0, ridge) * 0.25);
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
	ivec2 cs[4] = {i0, i0 + ivec2(1, 0), i0 + ivec2(0, 1), i0 + ivec2(1, 1)};
	float n = texture(noise_tex, v_p * 0.035).r;
	float fine = texture(noise_tex, v_p * 0.8).r;
	// Reuna: neljän ruudun peltopeitto lineaarisesti ja kohinalla rikottuna (ei 0,5 m portaita, vaan rosoinen
	// pientareen raja). Peitto 0,5 on ruutujen välinen raja; kohina siirtää sitä ±15 cm.
	float m00 = st_at(cs[0]) != 0 ? 1.0 : 0.0;
	float m10 = st_at(cs[1]) != 0 ? 1.0 : 0.0;
	float m01 = st_at(cs[2]) != 0 ? 1.0 : 0.0;
	float m11 = st_at(cs[3]) != 0 ? 1.0 : 0.0;
	float cover = mix(mix(m00, m10, f.x), mix(m01, m11, f.x), f.y);
	float edge_n = texture(noise_tex, v_p * 0.37).r * 0.7 + fine * 0.3;
	if (cover < 0.5 + (edge_n - 0.5) * 0.6) {
		discard;
	}
	int sn = st_at(near);
	if (sn == 0) {  // reunan yli ulottuva kohta: lähin peltoruutu
		for (int k = 0; k < 4; k++) {
			int sk = st_at(cs[k]);
			if (sk != 0) {
				sn = sk;
				near = cs[k];
			}
		}
	}
	float dn = dir_at(near);
	vec3 col[4];
	for (int k = 0; k < 4; k++) {
		int sk = st_at(cs[k]);
		float dk = dir_at(cs[k]);
		if (sk == 0) {
			sk = sn;
			dk = dn;
		}
		col[k] = ground_col(sk, dk, v_p, n, fine);
	}
	vec2 w = smoothstep(0.15, 0.85, f);
	ALBEDO = mix(mix(col[0], col[1], w.x), mix(col[2], col[3], w.x), w.y) * (1.0 - 0.3 * wet);
	ROUGHNESS = mix(0.95, 0.55, wet);
	// Kynnetyn palteet ja äestetyn viirut valon mukaan: normaali kallistuu poikkisuunnassa (vaon rinteet).
	if (sn == 18 || sn == 11 || sn == 12) {
		float a = dn * 3.14159265;
		vec2 across_dir = vec2(-sin(a), cos(a));
		float across = dot(v_p, across_dir);
		float period = sn == 18 ? 0.35 : (sn == 11 ? 0.22 : 0.125);
		float amp = sn == 18 ? 0.9 : 0.25;
		float slope = cos(fract(across / period + (sn == 18 ? fine * 0.15 : 0.0)) * 6.2831853) * amp;
		vec3 nl = normalize(vec3(across_dir.x * slope, 1.0, across_dir.y * slope));
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nl, 0.0)).xyz);
	}
}
