// Anatomia, osa paa (scripts/anatomia_paa.gd): pään ja kaulan ihon yksityiskohdat varjostimessa. Koodi (COLOR.r:n murto-osa):
// 10 = pää, 11 = kaula, väliarvot kaulan ja vartalon rajalla (pehmeä reuna). Koordinaatit lepoasennosta (UV2 = x, y; z = rzn.x).
// Silmät, kulmakarvat ja hampaat ovat omia verkkojaan tai puuttuvat; tässä vain iho: silmäkuopat ja luomet, nenä ja sieraimet,
// nenä-huulipoimu, huulet, leuka, korva, kaulan jänteet ja ihon huokoset.
uniform vec2 anat_head = vec2(1.5766, 0.2335);  // pään alin y ja korkeus lepoasennossa (Anatomia.Paa.FRAME, sukupuolen mukaan)
uniform float anat_female = 0.0;  // 1 naismalli: pehmeämmät poimut
uniform int anat_debug = 0;

float anat_h(vec2 p) {
	return fract(sin(dot(mod(p, vec2(4096.0)), vec2(127.1, 311.7))) * 43758.5453);
}

float anat_vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(anat_h(i), anat_h(i + vec2(1, 0)), f.x), mix(anat_h(i + vec2(0, 1)), anat_h(i + vec2(1, 1)), f.x), f.y);
}

// Pehmeä viiva: 1 viivan keskellä, 0 leveydellä w (m) sivussa.
float anat_line(float d, float w) {
	return 1.0 - smoothstep(0.0, w, abs(d));
}

void anat_paa(inout vec3 albedo, inout float rough, inout vec3 nrm, float code, vec2 r, vec3 rzn, float lum) {
	float on = smoothstep(2.0, 9.5, code);  // 0 vartalolla, 1 päässä ja kaulassa
	float x = abs(r.x);
	float z = rzn.x;
	float h = anat_head.y;
	float yn = (r.y - anat_head.x) / h;
	float s = h / 0.2335;  // mittakaava: lähes 1 molemmilla malleilla
	float fem = anat_female;
	vec3 base = albedo;
	float fr = smoothstep(0.02, 0.07, z);  // kasvojen etupuoli
	float face = fr * smoothstep(-0.02, 0.0, yn) * (1.0 - smoothstep(0.62, 0.72, yn));
	vec3 n3 = vec3(rest_nx, rzn.y, rzn.z);

	// Silmäkuopat: pehmeä varjo silmän ympärillä ja alapuolella, yläluomen poimu, alaluomen pussi
	float ey = anat_head.x + 0.52 * h;
	vec2 e = vec2((x - 0.031) / (0.034 * s), (r.y - ey) / (0.026 * s));
	float socket = 1.0 - smoothstep(0.55, 1.7, length(e));
	float lower = smoothstep(0.1, -0.9, e.y) * (1.0 - smoothstep(0.5, 1.5, abs(e.x)));
	albedo *= 1.0 - (0.10 - 0.04 * fem) * socket * fr;
	albedo = mix(albedo, albedo * vec3(0.93, 0.84, 0.9), (0.3 - 0.12 * fem) * lower * fr);  // alaluomen sinertävä sävy
	float crease_y = ey + (0.0185 - 0.004 * clamp(e.x, -1.0, 1.0) * clamp(e.x, -1.0, 1.0)) * s;
	float crease = anat_line(r.y - crease_y, 0.0022 * s) * (1.0 - smoothstep(0.9, 1.35, abs(e.x))) * smoothstep(0.013, 0.02, x) * fr;
	albedo *= 1.0 - 0.28 * crease;
	float lid = anat_line(r.y - (ey - 0.0125 * s), 0.0018 * s) * (1.0 - smoothstep(0.7, 1.1, abs(e.x + 0.1))) * smoothstep(0.013, 0.02, x) * fr;
	albedo *= 1.0 - 0.12 * lid;

	// Nenä: nenänselän valo, sieraimet ja nenäsiipien poimu
	float nose_y = anat_head.x + 0.335 * h;
	float nb = (1.0 - smoothstep(0.0, 0.007 * s, x)) * smoothstep(0.26, 0.4, yn) * (1.0 - smoothstep(0.52, 0.6, yn));
	albedo *= 1.0 + 0.05 * nb * fr * smoothstep(0.1, 0.5, n3.z);
	vec2 nn = vec2((x - 0.0115 * s) / (0.0065 * s), (r.y - (nose_y - 0.012 * s)) / (0.0042 * s));
	float nostril = (1.0 - smoothstep(0.55, 1.0, length(nn))) * smoothstep(0.0, -0.35, n3.y);
	albedo *= 1.0 - 0.5 * nostril;
	float ala = anat_line(x - (0.027 + 0.012 * (0.335 - yn) / 0.1) * s, 0.0035 * s) * smoothstep(0.24, 0.3, yn) * (1.0 - smoothstep(0.34, 0.4, yn)) * fr;
	albedo *= 1.0 - 0.07 * ala;

	// Nenä-huulipoimu (nasolabiaali): nenäsiivestä suupielen ohi alas, hento naisilla
	float fx = (0.033 + 0.017 * clamp((0.32 - yn) / 0.2, 0.0, 1.0)) * s;
	float nl = anat_line(x - fx, 0.0045 * s) * smoothstep(0.1, 0.17, yn) * (1.0 - smoothstep(0.28, 0.33, yn)) * fr;
	albedo *= 1.0 - mix(0.09, 0.05, fem) * nl;

	// Huulet: suulinja, huulten sävy ja kiilto (pohjatekstuurissa on jo huulten väri; tässä korostus)
	float mouth_y = anat_head.x + 0.145 * h;
	float lipx = 1.0 - smoothstep(0.026 * s, 0.036 * s, x);
	float ml = anat_line(r.y - mouth_y + 0.0015 * s * (1.0 - clamp(x / (0.03 * s), 0.0, 1.0) * 2.0) * 0.0, 0.0016 * s);
	float mline = ml * lipx * fr;
	albedo *= 1.0 - 0.32 * mline;
	float lipband = (1.0 - smoothstep(0.006 * s, 0.011 * s, abs(r.y - mouth_y - 0.0005))) * lipx * fr;
	albedo = mix(albedo, albedo * vec3(1.05, 0.86, 0.88), 0.28 * lipband);
	rough = mix(rough, 0.36, 0.65 * lipband);
	// leuan ja alahuulen välinen kuoppa ja leuan valo
	float groove = anat_line(r.y - (anat_head.x + 0.1 * h), 0.003 * s) * (1.0 - smoothstep(0.0, 0.018 * s, x)) * fr;
	albedo *= 1.0 - 0.04 * groove;

	// Poskipäiden puna ja ohimot
	float blush = (1.0 - smoothstep(0.0, 0.03 * s, length(vec2(x - 0.052 * s, r.y - (anat_head.x + 0.36 * h))))) * fr;
	albedo = mix(albedo, albedo * vec3(1.05, 0.9, 0.9), 0.35 * blush * (1.0 - 0.3 * fem));

	// Korva: reuna punertava, korvakäytävän varjo
	float ear = smoothstep(0.066, 0.075, x) * (1.0 - smoothstep(0.045, 0.075, abs(z + 0.012))) * smoothstep(0.22, 0.4, yn) * (1.0 - smoothstep(0.6, 0.7, yn));
	albedo = mix(albedo, albedo * vec3(1.05, 0.88, 0.85), 0.3 * ear);
	float concha = (1.0 - smoothstep(0.0, 0.014 * s, length(vec2(x - 0.082 * s, z + 0.012) * vec2(1.0, 1.4) + vec2(0.0, (yn - 0.44) * h * 0.9)))) * ear;
	albedo *= 1.0 - 0.14 * concha;

	// Alaleuan varjo: leuan alla kaulaan päin tummenee (ihon varjo kaulan ja leuan välissä)
	float under = smoothstep(-0.2, -0.8, n3.y) * smoothstep(0.08, -0.04, yn) * smoothstep(-0.2, 0.05, yn + 0.14);
	albedo *= 1.0 - 0.16 * under * on;
	// Kaula: kaulajänteet (kallon takaa solisluuhun) ja aatamin omena
	float neck = smoothstep(0.0, 0.1, -yn) * smoothstep(-0.55, -0.05, yn);
	float scm_x = (0.026 + 0.03 * clamp(-yn / 0.4, 0.0, 1.0)) * s;
	float scm = anat_line(x - scm_x, 0.008 * s) * smoothstep(0.1, 0.5, n3.z + 0.35) * neck;
	albedo *= 1.0 - 0.06 * scm * (1.0 - 0.5 * fem);
	float adam = (1.0 - smoothstep(0.0, 0.012 * s, length(vec2(x, (r.y - (anat_head.x - 0.032 * h)) * 0.8)))) * smoothstep(0.2, 0.7, n3.z) * (1.0 - fem);
	albedo *= 1.0 + 0.04 * adam;

	// Iho: hienojakoinen huokoskuvio ja pieni epätasaisuus (häipyy, kun pikseli on huokosta isompi)
	float fw = fwidth(r.x) + fwidth(r.y);
	float pk = 1.0 - smoothstep(0.0007, 0.0018, fw);
	vec2 pp = vec2(r.x + z * 1.7, r.y + z * 0.8) * 650.0;
	float pore = anat_vn(pp) * 0.65 + anat_vn(pp * 2.3 + 11.0) * 0.35;
	float dot_ = smoothstep(0.66, 0.9, pore);
	albedo *= 1.0 - (0.016 * dot_ + 0.006 * (pore - 0.5)) * pk * on;
	nrm.xy += (vec2(anat_vn(pp * 0.9 + 3.0), anat_vn(pp * 0.9 + 7.0)) - 0.5) * 0.018 * pk * on;
	float blotch = anat_vn(vec2(r.x + z, r.y) * 45.0) - 0.5;  // hennot sävyn vaihtelut
	albedo *= 1.0 + 0.012 * blotch * on;
	albedo = mix(base, albedo, on);
	if (anat_debug == 1) {
		albedo = mix(albedo, vec3(1, 0, 1), 0.6 * (mline + lipband));
	}
}
