// Anatomia, osa kadet (scripts/anatomia_kadet.gd). Koodi (COLOR.r:n murto-osa): 1..5 kämmenselkä (jänteet; stripe = sijainti sormien
// tyvien välillä / 4, koodi = voimakkuus), 8 sormi ja 9 peukalo (kynsi maalataan: stripe = 0,5 + 0,2 (tau - 0,5), front = 0,5 + 0,2 q;
// tau 0 kynnen tyvi .. 1 vapaa reuna, q -1..1 sivusuunnassa; kynsi vain kämmenselän puolella).
void anat_kadet(inout vec3 albedo, inout float rough, inout vec3 nrm, float code, vec3 rzn) {
	if (code > 7.5) {
		float tau = (stripe - 0.5) / 0.2 + 0.5;
		float q = (front - 0.5) / 0.2;
		// kämmenselän puoli: sormilla normaali +Y, peukalolla vinosti eteen ylös (lepoasento)
		float dors = code < 8.5 ? rzn.y : dot(rzn.yz, vec2(0.55, 0.85));
		dors = smoothstep(0.3, 0.6, dors);
		float dd = pow(abs(2.0 * tau - 1.0), 2.6) + pow(abs(q), 2.6);
		float aa = clamp(fwidth(dd) * 0.8, 0.01, 0.4);
		float inside = (1.0 - smoothstep(1.0 - aa, 1.0 + aa, dd)) * dors;
		if (inside > 0.0) {
			vec3 nail = mix(albedo, vec3(0.93, 0.68, 0.64), 0.6);
			nail = mix(nail, vec3(0.99, 0.94, 0.91), 0.25 * (1.0 - smoothstep(0.02, 0.3, tau)) * (1.0 - q * q));  // kuutiopuoliskuu
				nail = mix(nail, albedo * 0.68, 0.7 * smoothstep(0.7, 1.0, dd));  // kynsivalli: tumma reuna
			albedo = mix(albedo, nail, inside);
			rough = mix(rough, 0.42, inside);
		}
	} else {
		// jänteet vain kämmenselällä (normaali +Y lepoasennossa), ranteesta rystysten tuntumaan; sormen tyven koodit (>= 6) pois
		float k = smoothstep(0.5, 3.0, code) * (1.0 - smoothstep(4.6, 5.6, code)) * smoothstep(0.3, 0.8, rzn.y);
		float ridge = 0.5 + 0.5 * cos(stripe * 4.0 * 6.2831853);
		albedo *= 1.0 - 0.07 * k * (1.0 - ridge);  // jänteiden välit hieman tummemmat
		albedo *= 1.0 + 0.03 * k * ridge;
	}
}
