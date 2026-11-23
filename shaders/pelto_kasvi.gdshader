shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;
// Kaisuan pellon kasvusto (kaisua_pelto.gd): yksi tupsu (kolme ristikkäistä korsikorttia) ruutua kohden. Lohko
// (MultiMesh) piirtää CHUNK × CHUNK ruutua alkaen ruudusta, joka on lohkon solmun siirto (x, z). Tila (kaisua_tila.gd) antaa pituuden, värin,
// korsikuvan (nurmi tai ohra) ja asennon: niitetty heinä ja olki makaavat työsuuntaan, karho on harjanne.
// Korkeus maastoverkon kolmioista (mokki.gd mesh_h, 2 m kärkipisteet), joten tyvet ovat maan pinnassa.

uniform sampler2D state_tex : filter_nearest;  // R8: tila
uniform sampler2D amt_tex : filter_nearest;  // RF: heinää tai olkea (yksikköä)
uniform sampler2D dir_tex : filter_nearest;  // R8: työsuunta (0–1 = 0–180°)
uniform sampler2D height_tex : filter_nearest;  // R = maaston korkeus 2 m kärkipisteissä
uniform sampler2D atlas : filter_linear;  // R = sävy, G = tähkä, A = peitto; vasen puolisko nurmi, oikea ohra
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 origin = vec2(0.0);
uniform vec2 cells = vec2(1.0);
uniform float cell = 0.5;
uniform vec2 h_origin = vec2(0.0);
uniform float h_step = 2.0;
uniform bool diag_main = true;  // maastoverkon kolmion lävistäjä (kaisua_pelto.gd)
uniform mat4 to_world = mat4(1.0);
uniform mat4 from_world = mat4(1.0);  // to_world käänteisenä: lohkon alkuruutu solmun siirrosta
uniform int chunk_cols = 32;
// Kasvusto painuu maahan kaukana tupsu kerrallaan (ei lohkon kovaa reunaa): täysi korkeus fade_near asti, nolla
// fade_far:ssa. Lohko piilotetaan vasta, kun sen lähin tupsu on fade_far:n takana (kaisua_pelto.gd CROP_RANGE).
uniform float fade_near = 46.0;
uniform float fade_far = 66.0;

varying vec3 v_base;
varying vec3 v_head;
varying float v_kind;
varying float v_heads;
varying float v_y;
varying float v_lying;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float th(vec2 p) {
	vec2 g = (p - h_origin) / h_step;
	vec2 i = floor(g);
	vec2 f = g - i;
	ivec2 ii = ivec2(i);
	float h00 = texelFetch(height_tex, ii, 0).r;
	float h11 = texelFetch(height_tex, ii + ivec2(1, 1), 0).r;
	float h10 = texelFetch(height_tex, ii + ivec2(1, 0), 0).r;
	float h01 = texelFetch(height_tex, ii + ivec2(0, 1), 0).r;
	if (diag_main) {  // lävistäjä (0,0)-(1,1) (mökin maastoverkko)
		if (f.x >= f.y) {
			return h00 + (h10 - h00) * f.x + (h11 - h10) * f.y;
		}
		return h00 + (h11 - h01) * f.x + (h01 - h00) * f.y;
	}
	// lävistäjä (1,0)-(0,1) (Saloisten terrain.gd)
	if (f.x + f.y <= 1.0) {
		return h00 + (h10 - h00) * f.x + (h01 - h00) * f.y;
	}
	return h11 + (h01 - h11) * (1.0 - f.x) + (h10 - h11) * (1.0 - f.y);
}

void vertex() {
	// Lohkon alkuruutu on MultiMeshInstancen siirto pellon kehyksessä (kaisua_pelto.gd): ei instanssimuuttujaa, joita
	// GLES3 sallii koko pelissä vain 4096 (lohkoja on satoja).
	vec3 c0 = (from_world * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	ivec2 c = ivec2(round(c0.xz)) + ivec2(INSTANCE_ID % chunk_cols, INSTANCE_ID / chunk_cols);
	bool inside = c.x < int(cells.x) && c.y < int(cells.y);
	ivec2 cc = clamp(c, ivec2(0), ivec2(cells) - 1);
	int s = int(texelFetch(state_tex, cc, 0).r * 255.0 + 0.5);
	float amt = texelFetch(amt_tex, cc, 0).r;
	float dirv = texelFetch(dir_tex, cc, 0).r;
	float H = 0.0;
	float tilt = 0.0;
	float W = 1.0;
	float kind = 0.0;
	float heads = 0.0;
	float ridge = 0.0;
	float stretch = 1.0;  // tupsun venytys työsuuntaan (karho on yhtenäinen harjanne, ei erillisiä kasoja)
	vec3 base = vec3(0.3);
	vec3 head = vec3(0.3);
	if (s == 1) {
		H = 0.22; base = vec3(0.2, 0.42, 0.1);
	} else if (s == 2) {
		H = 0.42; base = vec3(0.22, 0.45, 0.11);
	} else if (s == 3) {
		H = 0.66; base = vec3(0.23, 0.45, 0.12); head = vec3(0.42, 0.4, 0.24); heads = 1.0;
	} else if (s == 4) {  // niitetty: kuivuva heinä makaa ajosuuntaan
		H = 0.42; tilt = 1.38; W = 1.15; stretch = 1.3; base = vec3(0.44, 0.54, 0.21);
	} else if (s == 5) {  // karho: pöyheä harjanne, korret pitkin karhoa ja osin pystyssä
		H = 0.5 + clamp(amt * 0.012, 0.0, 0.35); tilt = 1.0; W = 1.2; stretch = 2.1;
		ridge = clamp(0.05 + amt * 0.004, 0.05, 0.18);
		base = vec3(0.56, 0.6, 0.29);
	} else if (s == 6) {
		H = 0.09; base = vec3(0.55, 0.62, 0.3);
	} else if (s == 10) {
		H = 0.12; kind = 1.0; base = vec3(0.58, 0.53, 0.37);
	} else if (s == 13) {
		H = 0.1; W = 0.6; base = vec3(0.3, 0.58, 0.15);
	} else if (s == 14) {
		H = 0.55; kind = 1.0; base = vec3(0.24, 0.44, 0.12); head = vec3(0.34, 0.54, 0.17); heads = 1.0;
	} else if (s == 15) {
		H = 0.8; kind = 1.0; base = vec3(0.74, 0.62, 0.31); head = vec3(0.86, 0.73, 0.4); heads = 1.0;
	} else if (s == 16) {
		H = 0.15; kind = 1.0; base = vec3(0.74, 0.65, 0.4);
	} else if (s == 17) {
		H = 0.4; tilt = 1.3; W = 1.2; kind = 1.0; ridge = 0.06; base = vec3(0.82, 0.72, 0.46);
	}
	vec2 cf = vec2(c);
	float r1 = hash(cf);
	float r2 = hash(cf + 17.3);
	float r3 = hash(cf + 5.1);
	float r4 = hash(cf + 9.7);
	vec2 lp = origin + (cf + 0.5 + (vec2(r1, r2) - 0.5) * 0.7) * cell;
	float ground_y = th(lp);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float dist = distance(cam, (to_world * vec4(lp.x, ground_y, lp.y, 1.0)).xyz);
	float fade = 1.0 - smoothstep(fade_near, fade_far, dist + (r3 - 0.5) * 4.0);
	H *= fade;
	ridge *= fade;
	if (!inside || H <= 0.01) {
		VERTEX = vec3(0.0);
		NORMAL = vec3(0.0, 0.0, 1.0);
		v_base = base; v_head = head; v_kind = kind; v_heads = heads; v_y = 0.0; v_lying = 0.0;
	} else {
		H *= 0.8 + r3 * 0.4;
		vec3 v = VERTEX;
		float ang = r4 * 6.2831;
		v.xz = vec2(cos(ang) * v.x - sin(ang) * v.z, sin(ang) * v.x + cos(ang) * v.z);
		v.xz *= cell * 1.6 * W;
		float da = dirv * 3.14159265;
		vec2 D = vec2(cos(da), sin(da));
		vec2 Dp = vec2(-D.y, D.x);
		v.xz = D * dot(v.xz, D) * stretch + Dp * dot(v.xz, Dp);
		float y = v.y * H;
		float la = da + (r1 - 0.5) * (stretch > 1.5 ? 0.5 : 0.9);
		vec2 L = vec2(cos(la), sin(la)) * (r2 > 0.5 ? 1.0 : -1.0);
		vec3 pos = vec3(v.x, 0.0, v.z) + vec3(L.x, 0.0, L.y) * sin(tilt) * y + vec3(0.0, cos(tilt) * y, 0.0);
		pos.y += ridge * (0.55 + 0.45 * r3);
		// Pellon pinta on LIFT (5 cm) maaston yllä: makaavat korret ja sänki sen päälle, etteivät ne jää pinnan alle.
		pos.y += tilt > 0.5 ? 0.08 : (H < 0.2 ? 0.035 : 0.0);
		float wv = sin(TIME * 1.3 + lp.x * 0.21 + lp.y * 0.17) * 0.06 + sin(TIME * 2.9 + lp.x * 0.7) * 0.02;
		pos.xz += vec2(wv, wv * 0.5) * v.y * v.y * H * (1.0 - tilt / 1.5);
		vec3 local = vec3(lp.x, ground_y, lp.y) + pos;
		VERTEX = (VIEW_MATRIX * (to_world * vec4(local, 1.0))).xyz;
		NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		float tint = textureLod(noise_tex, lp * 0.04, 0.0).r;
		v_base = base * (0.82 + tint * 0.36);
		v_head = head * (0.85 + tint * 0.3);
		v_kind = kind;
		v_heads = heads;
		v_y = v.y;
		v_lying = tilt > 0.5 ? 1.0 : 0.0;
	}
}

void fragment() {
	vec4 a = texture(atlas, vec2(UV.x * 0.5 + v_kind * 0.5, 1.0 - UV.y));
	if (a.a < 0.5 || (a.g > 0.5 && v_heads < 0.5)) {
		discard;
	}
	float hm = step(0.5, a.g) * v_heads;
	vec3 col = mix(v_base * (0.55 + 0.6 * a.r), v_head * (0.8 + 0.3 * a.r), hm);
	col *= mix(0.62 + 0.38 * v_y, 0.8 + 0.22 * v_y, v_lying);  // makaavan heinän tyvi ei tummu laikuiksi
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = col * 0.45;
}
