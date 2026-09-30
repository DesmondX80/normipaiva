shader_type spatial;
// Hahmon vartalo: iho tekstuurista, vaatteet väritetään verteksivärin luokasta
// (R = 0 iho, 0.25 paita, 0.5 housut, 0.75 kengät; G = verkkarin raita).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap;
uniform vec3 skin_tint : source_color = vec3(1.0);
uniform vec3 shirt : source_color = vec3(0.45, 0.2, 0.6);
uniform vec3 pants : source_color = vec3(0.2, 0.28, 0.5);
uniform vec3 shoes : source_color = vec3(0.12, 0.1, 0.1);
uniform vec3 stripe_col : source_color = vec3(0.95);
uniform float fabric_shine = 0.0;
uniform float muscle_def = 1.0;  // 0 = lihakset piiloon (kaljamaha), 1 = superhero
uniform bool tracksuit = false;
uniform vec3 panel_a : source_color = vec3(0.1, 0.65, 0.62);
uniform vec3 panel_b : source_color = vec3(0.08, 0.08, 0.1);

varying float cat;
varying float stripe;
varying vec3 lpos;
varying vec2 rest;
varying float front;
varying float rest_nx;

uniform float shirt_puff = 0.022;
uniform float pants_puff = 0.014;
// Paljastavammat vaatteet (lepoasennon korkeus/leveys, metrit; < 0 = pois käytöstä):
// shorts_y = housut loppuvat tähän (reisi), crop_y = paita loppuu tähän (napa näkyy), sleeve_x = hihan pää.
uniform float shorts_y = -1.0;
uniform float crop_y = -1.0;
uniform float sleeve_x = 9.0;
uniform float tube_y = -1.0;  // tuubitoppi: paita loppuu ylhäältä tähän (olkaimeton, olkapäät paljaina)
uniform bool denim = false;  // revityt farkkushortsit: toimikudos, hapsuinen lahje, repeämät reisissä
uniform vec3 bare_skin : source_color = vec3(0.93, 0.74, 0.62);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Hapsuinen reuna: korkeus vaihtelee lankamaisesti leveyden (x, z) mukaan.
float fray(vec3 lp) {
	return (hash21(floor(vec2(lp.x * 260.0, lp.z * 260.0))) - 0.5) * 0.02;
}

// Paljas iho vaatteen kohdalla? (c = luokka, r = lepoasento, lp = paikka)
bool bare(float c, vec2 r, vec3 lp) {
	if (c > 1.5 && c < 2.5 && shorts_y > 0.0 && r.y < shorts_y + (denim ? fray(lp) : 0.0)) {
		return true;
	}
	if (c > 0.5 && c < 1.5 && ((crop_y > 0.0 && r.y < crop_y && abs(r.x) < 0.26) || abs(r.x) > sleeve_x
			|| (tube_y > 0.0 && r.y > tube_y))) {
		return true;
	}
	return false;
}

void vertex() {
	cat = COLOR.r * 4.0;
	stripe = COLOR.g;
	lpos = VERTEX;
	rest = UV2;
	front = COLOR.b;
	rest_nx = COLOR.a * 2.0 - 1.0;
	// Vaatteet vähän irti ihosta, ettei näytä maalatulta trikoolta.
	float c = floor(cat + 0.5);
	float puff = c > 0.5 && c < 1.5 ? shirt_puff : (c > 1.5 && c < 2.5 ? pants_puff : (c > 2.5 ? 0.01 : 0.0));
	if (bare(c, UV2, VERTEX)) {
		puff = 0.0;
	}
	VERTEX += NORMAL * puff;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float c = floor(cat + 0.5);
	vec3 n = texture(normal_tex, UV).rgb;
	if (c > 0.5 && c < 2.5 && bare(c, rest, lpos)) {
		// Vaatteen alta paljas iho: tasainen ihonsävy (pohjatekstuurissa näillä kohdin on puku).
		ALBEDO = bare_skin * skin_tint * (0.82 + 0.25 * lum);
		ROUGHNESS = 0.55;
		SSS_STRENGTH = 0.35;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else if (c < 0.5) {
		ALBEDO = t.rgb * skin_tint;
		ROUGHNESS = texture(rough_tex, UV).r;
		NORMAL_MAP = n;
		SSS_STRENGTH = 0.35;
	} else {
		vec3 cloth = c < 1.5 ? shirt : (c < 2.5 ? pants : shoes);
		if (tracksuit && c > 0.5 && c < 1.5) {
			// Takki: vino värikenttä rinnan yli, tumma olkakaista ja kaulus, vetoketju edessä.
			float ax = abs(rest.x);
			float diag = rest.y - (1.27 + 0.32 * rest.x);
			float torso = 1.0 - step(0.26, ax);
			cloth = mix(cloth, panel_a, step(0.0, diag) * torso);
			cloth = mix(cloth, panel_b, step(0.0, diag - 0.035) * step(diag, 0.075) * torso);
			// Hihat: kyynärpään yläpuolella värikenttä, ranteessa tumma resori.
			float arm = step(0.26, ax);
			cloth = mix(cloth, panel_a, arm * step(0.3, ax) * step(ax, 0.46));
			cloth = mix(cloth, panel_b, arm * step(0.6, ax));
			cloth = mix(cloth, panel_b, step(1.47, rest.y) * torso);  // kaulus
			float zip = (1.0 - smoothstep(0.004, 0.007, abs(rest.x))) * step(0.5, front) * torso;
			cloth = mix(cloth, vec3(0.05), zip);
		}
		float stripe_on = step(0.5, stripe);
		if (tracksuit) {
			// Tuulipuvussa raidat vain housujen ulkosivuilla, terävinä lepoasennon normaalista.
			stripe_on = (c > 1.5 && c < 2.5 && rest.y > 0.12) ? step(0.97, abs(rest_nx)) * step(0.0, rest_nx * rest.x) : 0.0;
		}
		cloth = mix(cloth, stripe_col, stripe_on);
		if (tube_y > 0.0 && c > 0.5 && c < 1.5) {
			// Ysärin tuubitoppi: ribbineulos vaakaraidoin, reunoissa tiukka kaitale.
			float rib = 0.88 + 0.12 * step(0.5, fract(rest.y * 140.0));
			float edge = 1.0 - step(0.012, min(abs(rest.y - tube_y), abs(rest.y - crop_y)));
			cloth *= rib * (1.0 - 0.18 * edge);
		}
		if (denim && c > 1.5 && c < 2.5) {
			// Farkku: vino toimikudos, kulunut vaalea etureisi, valkoiset hapsut lahkeen suussa ja repeämät.
			float twill = 0.9 + 0.1 * step(0.5, fract((lpos.y + lpos.x) * 180.0));
			float worn = smoothstep(0.0, 0.08, lpos.z) * smoothstep(shorts_y + 0.12, shorts_y + 0.02, rest.y);
			cloth = mix(cloth, vec3(0.72, 0.8, 0.9), 0.35 * worn) * twill;
			float hem = smoothstep(shorts_y + 0.025, shorts_y + 0.005, rest.y);
			cloth = mix(cloth, vec3(0.9, 0.9, 0.86), hem * step(0.5, hash21(floor(vec2(lpos.x * 400.0, lpos.y * 60.0)))));
			// Repeämät: vaakasuorat raot etureisissä, lankoja poikki ja iho välistä.
			vec2 rc = vec2(abs(rest.x) * 40.0, rest.y * 55.0);
			float rip = step(0.8, hash21(floor(rc))) * smoothstep(0.0, 0.05, lpos.z) * step(rest.y, shorts_y + 0.1);
			float slit = step(0.3, fract(rc.y)) * step(fract(rc.y), 0.7);
			cloth = mix(cloth, mix(bare_skin * skin_tint, vec3(0.92), step(0.6, fract(lpos.x * 300.0))), rip * slit);
		}
		// Kankaan kude: hienot raidat + tekstuurin varjostus säilyy.
		float weave = 0.94 + 0.06 * sin(lpos.y * 900.0) * sin(lpos.x * 700.0 + lpos.z * 700.0);
		ALBEDO = cloth * mix(0.96, 0.72 + 0.5 * lum, muscle_def) * weave;
		ROUGHNESS = c > 2.5 ? 0.45 : mix(0.9, 0.5, fabric_shine);
		SPECULAR = mix(0.25, 0.45, fabric_shine);
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), n, 0.18 * muscle_def);
	}
}
