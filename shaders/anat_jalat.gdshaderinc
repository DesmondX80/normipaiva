// Anatomia, osa B (jalat ja ranne). Paljas jalka (Anatomia.bare_foot_color, Character._attach_shoes): eksplisiittinen
// look.shoe = "paljas" antaa jalkaterälle ihonvärin (mode 1) tai look.foot_col-värin (mode 2), ei shoes-väriä.
// 0 = vanha käytös (luokan 3 väri = shoes). Raja nilkassa lasketaan fragmentissa lepoasennon y:stä (anat_ankle_y).
// Ranne: käden pisteillä on kyynärvarren luokka (anatomia_jalat.gd), ja raja käden (luokka 0) ja kyynärvarren välillä
// vedetään fragmentissa lepoasennon x:stä (anat_wrist_x = |hand.x|; 9 = pois), ei verteksien luokkien interpolaatiosta.
uniform int bare_foot_mode = 0;
uniform vec3 foot_col : source_color = vec3(0.42, 0.3, 0.16);
uniform float anat_ankle_y = 0.085;
uniform float anat_wrist_x = 9.0;
// Varpaankynnet (anatomia_jalat.gd toe_nails): lepopaikka (x, y, z) ja leveyssäde (m) * 10; säde 0 = ei kynttä.
uniform vec4 anat_toes[10];
uniform vec3 anat_nail_col : source_color = vec3(0.93, 0.68, 0.64);

float anat_class_jalat(float c, vec2 r) {
	if (bare_foot_mode > 0 && c > 1.5) {
		c = r.y < anat_ankle_y ? 3.0 : 2.0;
	}
	if (c > 0.5 && c < 1.5 && abs(r.x) > anat_wrist_x && r.y > 0.9) {
		c = 0.0;  // kämmen ja sormet: ranteen luun takana
	}
	return c;
}

// Paljaan jalkaterän yksityiskohdat (mode 1): varpaankynnet (vaalea ruusunpunainen, himmeä, kuten käden kynnet), varpaan kärjen
// puna ja nivelen poimu, kantapään ja jalkapohjan känsä. Kaikki lepoasennon koordinaateista (r, z = rzn.x), ei verteksimaskia.
void anat_foot(inout vec3 albedo, inout float rough, vec2 r, vec3 rzn) {
	vec3 rp = vec3(r, rzn.x);
	float top = smoothstep(0.1, 0.45, rzn.y);
	for (int i = 0; i < 10; i++) {
		vec4 nl = anat_toes[i];
		if (nl.w <= 0.0) {
			continue;
		}
		vec3 d = rp - nl.xyz;
		float rx = nl.w;
		float rz = rx * 1.12;
		// varpaan kärki hieman punertava, nivelen kohdalla (kynnen takana) hento poimu
		float tip = (1.0 - smoothstep(0.0, 2.2 * rz, nl.z + rz - rp.z + 0.0015)) * step(abs(d.x), 1.25 * rx) * step(-0.012, d.y);
		albedo = mix(albedo, albedo * vec3(1.04, 0.9, 0.9), 0.35 * tip * (1.0 - top * 0.4));
		float crease = (1.0 - smoothstep(0.0006, 0.0016, abs(rp.z - (nl.z - 2.3 * rz)))) * step(abs(d.x), 1.2 * rx) * top * step(-0.012, d.y);
		albedo *= 1.0 - 0.04 * crease;
		float dd = pow(abs(d.x / rx), 2.6) + pow(abs(d.z / rz), 2.6);
		float aa = clamp(fwidth(dd) * 0.8, 0.01, 0.4);
		float inside = (1.0 - smoothstep(1.0 - aa, 1.0 + aa, dd)) * top * step(-0.009, d.y);
		if (inside > 0.0) {
			vec3 nail = mix(albedo, anat_nail_col, 0.6);
			float tau = clamp(0.5 - 0.5 * d.z / rz, 0.0, 1.0);  // 0 vapaa reuna .. 1 tyvi (kärki on +z)
			nail = mix(nail, vec3(0.99, 0.94, 0.91), 0.22 * smoothstep(0.65, 1.0, tau) * (1.0 - d.x * d.x / (rx * rx)));  // kuutiopuoliskuu
			nail = mix(nail, albedo * 0.7, 0.7 * smoothstep(0.7, 1.0, dd));  // kynsivalli
			albedo = mix(albedo, nail, inside);
			rough = mix(rough, 0.42, inside);
		}
	}
	// kantapää ja jalkapohja: paksumpi, hieman kellertävä iho
	float sole = smoothstep(-0.35, -0.7, rzn.y);
	float heel = smoothstep(-0.045, -0.075, rp.z) * (1.0 - smoothstep(0.03, 0.06, r.y));
	albedo = mix(albedo, albedo * vec3(0.97, 0.9, 0.78), 0.45 * max(sole, heel));
	rough = mix(rough, 0.7, 0.5 * max(sole, heel));
}

// Pohje: paljaan sääriosan takapintaa kohotetaan korkeudella polven alla (r.y lepo-y, nz = lepoasennon normaalin z). Metrejä
// pinnan normaalin suunnassa; vain iholla (vaatteen alla ei näy), korkeintaan 5 mm, joten kontaktit ja kengät eivät muutu.
float anat_calf(float y, float nz) {
	float band = exp(-pow((y - 0.40) / 0.075, 2.0));
	return 0.005 * band * smoothstep(-0.1, -0.7, nz);
}
