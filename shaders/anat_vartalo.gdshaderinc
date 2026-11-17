// Anatomia, osa vartalo (scripts/anatomia_vartalo.gd): paljaan ihon vartalodetaljit varjostimessa. Ei maskia: lasketaan lepoasennon
// koordinaateista (r = x, y; rzn.x = z, rzn.yz = pinnan normaalin y ja z), joten sama funktio sopii mies- ja naismalliin.
// Kutsutaan paljailta ihoalueilta (vaatteen alta paljas iho, lappubikinin iho): solisluun kuoppa, rintalastan ura, linea alba,
// napa, selkäranka, lantiokuopat, kyynärpään ja polven sävy. Kaikki heikkoja (<= 6 %), jotta iho pysyy yhtenäisenä.

float anat_vb(float x, float c, float w) {
	float d = (x - c) / w;
	return exp(-d * d);
}

vec3 anat_vartalo_alb(vec3 albedo, vec2 r, vec3 rzn, float fem) {
	float x = abs(r.x);
	float z = rzn.x;
	float ny = rzn.y;
	float nz = rzn.z;
	float frn = smoothstep(0.0, 0.04, z) * smoothstep(-0.1, 0.4, nz);
	float back = (1.0 - smoothstep(-0.06, -0.01, z)) * smoothstep(-0.1, 0.4, -nz);
	float torso = 1.0 - smoothstep(0.2, 0.26, x);
	// solisluun yläpuolinen kuoppa ja rintalastan yläkulma
	albedo *= 1.0 - 0.05 * anat_vb(r.y, 1.49, 0.014) * smoothstep(0.02, 0.05, x) * (1.0 - smoothstep(0.1, 0.15, x)) * frn;
	albedo *= 1.0 - 0.04 * anat_vb(x, 0.0, 0.007) * smoothstep(1.3, 1.4, r.y) * (1.0 - smoothstep(1.43, 1.48, r.y)) * frn * (1.0 - 0.5 * fem);
	// linea alba (hento pystyviiva navan yläpuolella) ja napa
	float nav_y = 1.085 - 0.02 * fem;
	albedo *= 1.0 - 0.035 * anat_vb(x, 0.0, 0.0035) * smoothstep(nav_y, nav_y + 0.03, r.y) * (1.0 - smoothstep(1.2, 1.27, r.y)) * frn * (1.0 - 0.5 * fem);
	vec2 nv = vec2(x / 0.0065, (r.y - nav_y) / 0.0095);
	float nav = (1.0 - smoothstep(0.55, 1.0, length(nv))) * frn;
	albedo *= 1.0 - 0.18 * nav;
	albedo *= 1.0 + 0.05 * (smoothstep(0.85, 1.25, length(nv)) * (1.0 - smoothstep(1.25, 1.9, length(nv)))) * frn;
	// selkäranka ja lantiokuopat
	albedo *= 1.0 - 0.04 * anat_vb(x, 0.0, 0.004) * smoothstep(1.0, 1.15, r.y) * (1.0 - smoothstep(1.43, 1.48, r.y)) * back;
	albedo *= 1.0 - 0.07 * anat_vb(length(vec2(x - 0.052, (r.y - 1.0) * 1.2)), 0.0, 0.011) * back;
	// kyynärpää (taka) ja polvi (etu): hieman tummempi ja punaisempi iho
	float elbow = anat_vb(length(vec2(x - 0.455 + 0.05 * fem, (r.y - 1.46))), 0.0, 0.05) * (1.0 - smoothstep(-0.02, 0.02, z)) * step(0.3, x);
	albedo = mix(albedo, albedo * vec3(0.95, 0.87, 0.85), 0.5 * elbow);
	float knee = anat_vb(length(vec2(r.y - 0.50, x - 0.09)), 0.0, 0.045) * smoothstep(0.0, 0.04, z) * step(r.y, 0.62) * step(0.35, r.y);
	albedo = mix(albedo, albedo * vec3(0.95, 0.88, 0.86), 0.45 * knee);
	return albedo;
}

// Kauluksen raja: kaulan (luokka 0) ja paidan (luokka 1) rajan verteksivärin interpolaatio antaa sahalaidan. Raja vedetään suorana
// lepo-y:stä, etupuolella (z > 0) matalammalla kuin takana (mitattu ANATD kaulus -riveistä, UV2.y: mies taka 1,554 / etu 1,533 (luokan 1 ylin + 2 mm),
// nainen taka 1,489 / etu 1,492). Vain luokat 0 ja 1 kaulan alueella.
float anat_class_vartalo(float c, vec2 r, float fem) {
	if (fem > 0.5 && c > 0.5 && c < 2.5 && abs(r.x) < 0.26 && r.y > 1.0 && r.y < 1.12) {
		// helma: paidan (1) ja housujen (2) raja suorana (naismalli, mitattu ANATD helma -riveistä: taka 1,068 / etu 1,056)
		return r.y > mix(1.068, 1.056, smoothstep(-0.03, 0.03, rest_zn.x)) ? 1.0 : 2.0;
	}
	if (c > 1.5 || abs(r.x) > 0.12 || r.y < 1.4) {
		return c;
	}
	float f = smoothstep(-0.03, 0.03, rest_zn.x);
	float yc = fem > 0.5 ? mix(1.489, 1.492, f) : mix(1.554, 1.533, f);
	yc += 0.45 * max(abs(r.x) - 0.05, 0.0);  // kaulan sivuilla raja nousee (trapetsi laskee kaulasta pois)
	return r.y > yc ? 0.0 : 1.0;
}
