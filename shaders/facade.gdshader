shader_type spatial;
render_mode cull_disabled;
// Vaalan talojen seinät yhdistettynä meshinä: väri verteksiväristä, materiaali verteksivärin alfasta.
// 1.0 vaakapaneeli (omakotitalot), 0.75 pystylaudoitus peiterimoin (vajat), 0.5 tiili, 0.25 rappaus,
// 0.0 betonielementit saumoineen. Koordinaatit maailmasta seinän suunnan mukaan: kuvio ei veny.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying flat vec3 wnrm;  // tahkon normaali vakiona: suunta ei saa vaihdella pikseleittäin (isot koordinaatit)

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));  // verteksivärit sRGB:nä
	float kind = COLOR.a;
	vec2 t = normalize(vec2(-wnrm.z, wnrm.x) + vec2(1e-4, 0.0));
	float u = dot(wpos.xz, t);
	float v = wpos.y;
	float grime = texture(noise_tex, vec2(u, v) * 0.05).r;
	vec3 col = base;
	float rough = 0.85;
	float fw = max(fwidth(u), fwidth(v));
	if (kind > 0.87) {
		// Vaakapaneeli: 15 cm laudat, alareunan limityksen varjo ja lautakohtainen sävy. Kaukaa raidat
		// häivytetään keskisävyyn (ei moiréa).
		float p = v / 0.15;
		float f = fract(p);
		float tone = hash(vec2(floor(p), floor(u / 4.3))) * 0.12 - 0.06;
		float shade = mix(0.55, 1.0, smoothstep(0.0, 0.3, f)) * (1.0 - 0.1 * smoothstep(0.75, 1.0, f));
		float detail = 1.0 - smoothstep(0.05, 0.14, fw);
		col = base * mix(0.86, shade * (1.0 + tone), detail);
	} else if (kind > 0.62) {
		// Pystylaudoitus: leveät laudat ja kapeat peiterimat.
		float p = u / 0.22;
		float f = fract(p);
		float batten = smoothstep(0.0, 0.04, f) * (1.0 - smoothstep(0.22, 0.28, f));
		float edge = smoothstep(0.28, 0.34, f) * (1.0 - smoothstep(0.34, 0.4, f));
		float tone = hash(vec2(floor(p), 3.0)) * 0.16 - 0.08;
		float detail = 1.0 - smoothstep(0.06, 0.16, fw);
		col = base * mix(0.9, (0.8 + 0.25 * batten - 0.25 * edge) * (1.0 + tone), detail);
		rough = 0.95;
	} else if (kind > 0.37) {
		// Tiili: limitetyt rivit, laastisaumat ja tiilikohtainen sävy.
		vec2 p = vec2(u / 0.26, v / 0.075);
		p.x += mod(floor(p.y), 2.0) * 0.5;
		vec2 f = fract(p);
		float joint = clamp(step(f.x, 0.06) + step(f.y, 0.16), 0.0, 1.0);
		float tone = hash(floor(p)) * 0.3 - 0.12;
		float detail = 1.0 - smoothstep(0.25, 0.7, max(fwidth(p.x), fwidth(p.y)));
		vec3 mortar = vec3(0.72, 0.7, 0.66);
		col = mix(mix(base, mortar, 0.18), mix(base * (1.0 + tone), mortar, joint), detail);
		rough = 0.9;
	} else if (kind > 0.12) {
		// Rappaus: hienoa rakeisuutta ja laikkuja.
		float g = texture(noise_tex, vec2(u, v) * 0.9).r;
		col = base * (0.9 + 0.16 * g);
	} else {
		// Betonielementit: 3,6 x 2,8 m, saumat ja pesubetonin rakeisuus.
		vec2 p = vec2(u / 3.6, (v + 0.3) / 2.8);
		vec2 f = fract(p);
		float seam = clamp(step(f.x, 0.02) + step(f.y, 0.025), 0.0, 1.0);
		float g = texture(noise_tex, vec2(u, v) * 1.7).r;
		float tone = hash(floor(p)) * 0.06 - 0.03;
		float detail = 1.0 - smoothstep(0.02, 0.06, fw * 0.3);
		col = base * (0.85 + 0.22 * g + tone) * mix(1.0, 1.0 - 0.5 * seam, detail);
		rough = 0.95;
	}
	// Likaa ja sävyvaihtelua koko seinälle.
	col *= 0.92 + 0.12 * grime;
	ALBEDO = col;
	ROUGHNESS = rough;
}
