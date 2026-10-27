// Kontaktipainuma (Elastic.displace on tämän peili GDScriptinä: pidä samoina). press_xf = verkko -> laatikko,
// press_h = laatikon puolikoko; laatikon +Y on aktiivinen pinta. Pehmeä verteksi (CUSTOM0.w = raja) painetaan pinnalle
// korkeintaan rajan verran ja levitetään sivulle; luinen (w = 0) ei liiku. Yhteinen vartalolle (character.gdshader) ja
// hiuksille (hair.gdshader).
// press_radial: 0 = vartalo (leviäminen laatikon x-akselin suuntaan, ulospäin keskeltä), 1 = hiukset (leviäminen pinnan
// suuntaisesti kaikkiin suuntiin pois press_origin-pisteestä (pään keskus); verteksin normaali ei käy: hiuskortit ovat kaksipuolisia ja normaalin etumerkki vaihtelee, joten leviäminen repeäisi).
uniform int press_n = 0;
uniform mat4 press_xf0;
uniform mat4 press_xf1;
uniform mat4 press_xf2;
uniform mat4 press_xf3;
uniform mat4 press_xf4;
uniform mat4 press_xf5;
uniform vec3 press_h0;
uniform vec3 press_h1;
uniform vec3 press_h2;
uniform vec3 press_h3;
uniform vec3 press_h4;
uniform vec3 press_h5;
uniform float press_spread = 1.0;  // = Elastic.SPREAD
uniform float press_halo = 0.9;  // = Elastic.HALO
uniform float press_radial = 0.0;
uniform vec3 press_origin = vec3(0.0);  // verkon avaruus: hiusten leviämisen keskus (pää)

// used = aiempien laatikoiden painuma: raja on kaikille laatikoille yhteinen (kutsuja lisää used += depth_out * lim).
// Palauttaa siirtymän verkon avaruudessa; nrm = verteksin normaali verkon avaruudessa (vain press_radial > 0),
// n_out = laatikon +Y verkon avaruudessa ja depth_out = painuman osuus rajasta.
vec3 press_disp(mat4 xf, vec3 h, vec3 v, float lim, float used, vec3 nrm, out vec3 n_out, out float depth_out) {
	vec3 q = (xf * vec4(v, 1.0)).xyz;
	float pen = h.y - q.y;
	float w = (1.0 - smoothstep(h.x, h.x + 0.02, abs(q.x))) * (1.0 - smoothstep(h.z, h.z + 0.02, abs(q.z))) * step(-h.y, q.y) * (1.0 - smoothstep(lim * 1.5 + 0.01, lim * 1.5 + 0.02, pen));  // = Elastic.deep_fade
	float d = clamp(pen, 0.0, max(lim - used, 0.0)) * w;
	vec3 t = vec3(q.x, 0.0, q.z);
	float tl = length(t);
	mat3 m = mat3(xf);
	vec3 sdir = vec3(sign(q.x), 0.0, 0.0);
	float sfac = smoothstep(0.0, 0.02, abs(q.x));
	if (press_radial > 0.0) {
		vec3 qo = (xf * vec4(press_origin, 1.0)).xyz;
		vec3 dr = vec3(q.x - qo.x, 0.0, q.z - qo.z);
		float dl = length(dr);
		dr = dl > 0.00001 ? dr / dl : vec3(0.0);
		sdir = mix(sdir, dr, press_radial);
		sfac = mix(sfac, smoothstep(0.0, 0.02, dl), press_radial);
	}
	vec3 sp = (tl > 0.0 || press_radial > 0.0) ? sdir * sfac * (press_spread * d + press_halo * lim * w * (1.0 - smoothstep(0.0, 0.08, max(-pen, 0.0)))) : vec3(0.0);  // = Elastic.HALO_H
	n_out = vec3(m[0][1], m[1][1], m[2][1]);
	depth_out = lim > 0.0 ? d / lim : 0.0;
	return transpose(m) * (vec3(0.0, d, 0.0) + sp);
}

mat4 press_xf(int i) {
	return i == 0 ? press_xf0 : (i == 1 ? press_xf1 : (i == 2 ? press_xf2 : (i == 3 ? press_xf3 : (i == 4 ? press_xf4 : press_xf5))));
}

vec3 press_half(int i) {
	return i == 0 ? press_h0 : (i == 1 ? press_h1 : (i == 2 ? press_h2 : (i == 3 ? press_h3 : (i == 4 ? press_h4 : press_h5))));
}
