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
// Pelaajan asut (looks.gd OUTFITS): pitkät farkut vyöllä, verkkopaita (string-paita) henkseleillä, työhousut ja
// flanellipaita. Kaikki piirretään pikseleinä lepoasennon koordinaateista (rest = UV2, metrit).
uniform bool jeans = false;      // pitkät vaaleat farkut: toimikudos, kuluneet reidet ja polvet, sivusaumat
uniform float belt_y = -1.0;     // vyön yläreuna (lepoasennon korkeus); < 0 = ei vyötä
uniform vec3 belt_col : source_color = vec3(0.05, 0.045, 0.04);
uniform bool net_shirt = false;  // verkkopaita: reikäinen neulos, iho näkyy silmukoista, isoja repeämiä
uniform bool suspenders = false; // henkselit verkkopaidan päällä
uniform vec3 strap_col : source_color = vec3(0.55, 0.42, 0.25);
uniform bool workwear = false;   // työhousut: vahvikkeet polvissa, riipputaskut, heijastinraita säären ympäri
uniform bool flannel = false;    // flanellipaita: ruudutus
uniform bool tattoo = false;     // tatuointi vasemmassa olkavarressa (näkyy paljaalta iholta ja verkon läpi)
uniform bool string_bikini = false;  // pienet lappubikinit: kolmiot rintojen päällä, pieni alaosa, ohuet nauhat

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Hapsuinen reuna: korkeus vaihtelee lankamaisesti leveyden (x, z) mukaan.
float fray(vec3 lp) {
	return (hash21(floor(vec2(lp.x * 260.0, lp.z * 260.0))) - 0.5) * 0.02;
}

// Tatuointi vasemman olkavarren ulkosyrjässä: tummanvihreä heimokuvio (terävät kaaret) lepoasennon koordinaateissa.
float tattoo_ink(vec2 r, vec3 lp) {
	if (!tattoo || r.x < 0.3 || r.x > 0.43 || r.y < 1.37 || r.y > 1.47 || lp.y < 0.0) {
		return 0.0;
	}
	vec2 q = vec2((r.x - 0.365) / 0.06, (r.y - 1.42) / 0.045);
	float ring = abs(length(q) - 0.62) < 0.12 ? 1.0 : 0.0;
	float spike = abs(q.y - 0.5 * sin(q.x * 3.2)) < 0.11 * (1.0 - abs(q.x)) ? 1.0 : 0.0;
	return max(ring, spike) * step(length(q), 1.0);
}

vec3 skin_with_ink(vec3 skin, vec2 r, vec3 lp) {
	return mix(skin, vec3(0.08, 0.16, 0.14), 0.85 * tattoo_ink(r, lp));
}

// Verkkopaidan silmukka: 1 = lanka, 0 = reikä (iho näkyy). Isot repeämät satunnaisissa ruuduissa.
float net_thread(vec2 r, vec3 lp) {
	vec2 g = vec2(r.x * 42.0 + (lp.z > 0.0 ? 0.0 : 0.5), r.y * 42.0);
	vec2 f = abs(fract(g) - 0.5);
	float hole = step(max(f.x, f.y), 0.34);
	float tear = step(0.965, hash21(floor(vec2(r.x * 22.0 + (lp.z > 0.0 ? 0.0 : 3.0), r.y * 16.0))));
	return 1.0 - max(hole, tear);
}

// Janan ab etäisyys pisteestä p.
float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - (a + ab * t));
}

// Lappubikinien kangas lepoasennon koordinaateissa (fr = etupuoli). Yläosa: kaksi kolmiota rintojen päällä, kärjistä
// nauha niskaan ja rintojen alla kiertävä nauha. Alaosa matalavyötäröinen kuten sivusolmittavissa bikineissä: kapea
// ja korkea V edessä (kulmat ylhäällä lantiolla), takana kapea V (leveä suora yläreuna, kapenee ohueksi kaistaleeksi), ja paneelien
// yläkulmista nauhat lantion sivulle solmuun (solmut 3D-mallina, looks.gd add_bikini_ties).
bool bikini_cloth(float c, vec2 r, bool fr) {
	if (c > 0.5 && c < 1.5) {
		if (abs(r.y - 1.245) < 0.007 && abs(r.x) < 0.19) {
			return true;  // nauha rintojen alla
		}
		for (float sx = -1.0; sx < 1.5; sx += 2.0) {
			float u = (r.y - 1.245) / 0.125;  // 0 = kolmion kanta, 1 = kärki
			if (fr && u > 0.0 && u < 1.0 && abs(r.x - sx * 0.085) < 0.058 * (1.0 - u)) {
				return true;
			}
			if (fr && seg_dist(r, vec2(sx * 0.085, 1.37), vec2(sx * 0.05, 1.5)) < 0.005) {
				return true;  // niskanauha
			}
		}
		return false;
	}
	if (c > 1.5 && c < 2.5) {
		vec2 q = vec2(abs(r.x), r.y);
		vec2 corner = fr ? vec2(0.092, 0.985) : vec2(0.12, 0.962);
		if (seg_dist(q, corner, vec2(0.175, 0.99)) < 0.0055) {
			return true;  // sivunauha yläkulmasta lantion sivulle
		}
		float top = fr ? 0.985 : 0.962;
		float bottom = fr ? 0.84 : 0.83;
		float u = (r.y - bottom) / (top - bottom);  // 0 = haara, 1 = yläreuna
		if (u <= 0.0 || u >= 1.0) {
			return false;
		}
		// Takana kapea V: leveä suora yläreuna, joka kapenee nopeasti ohueksi kaistaleeksi pakaroiden väliin.
		float w = fr ? mix(0.024, 0.092, pow(u, 1.25)) : mix(0.008, 0.12, pow(u, 3.0));
		return q.x < w;
	}
	return true;
}

// Paljas iho vaatteen kohdalla? (c = luokka, r = lepoasento, lp = paikka)
bool bare(float c, vec2 r, vec3 lp, float fr) {
	if (string_bikini && c > 0.5 && c < 2.5) {
		return !bikini_cloth(c, r, fr > 0.5);
	}
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
	if (bare(c, UV2, VERTEX, COLOR.b)) {
		puff = 0.0;
	}
	VERTEX += NORMAL * puff;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float c = floor(cat + 0.5);
	vec3 n = texture(normal_tex, UV).rgb;
	bool net_hole = net_shirt && c > 0.5 && c < 1.5 && net_thread(rest, lpos) < 0.5
		&& !(suspenders && abs(abs(rest.x) - 0.1) < 0.014 && rest.y > 0.98 && rest.y < 1.52);
	if (net_hole) {
		// Verkon silmukasta näkyy iho (ja tatuointi).
		ALBEDO = skin_with_ink(bare_skin * skin_tint * (0.82 + 0.25 * lum), rest, lpos);
		ROUGHNESS = 0.55;
		SSS_STRENGTH = 0.35;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else if (c > 0.5 && c < 2.5 && bare(c, rest, lpos, front)) {
		// Vaatteen alta paljas iho: tasainen ihonsävy (pohjatekstuurissa näillä kohdin on puku).
		ALBEDO = skin_with_ink(bare_skin * skin_tint * (0.82 + 0.25 * lum), rest, lpos);
		ROUGHNESS = 0.55;
		SSS_STRENGTH = 0.35;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else if (c < 0.5) {
		ALBEDO = skin_with_ink(t.rgb * skin_tint, rest, lpos);
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
		if (jeans && c > 1.5 && c < 2.5) {
			// Pitkät farkut: vino toimikudos, vaaleammiksi kuluneet reidet ja polvet edessä, sivusauma oranssilla langalla.
			float twill = 0.9 + 0.1 * step(0.5, fract((lpos.y + lpos.x) * 180.0));
			float thigh = smoothstep(0.0, 0.07, lpos.z) * (smoothstep(0.45, 0.6, rest.y) * smoothstep(0.92, 0.75, rest.y)
				+ 0.6 * smoothstep(0.1, 0.0, abs(rest.y - 0.5)));
			cloth = mix(cloth, vec3(0.78, 0.86, 0.94), 0.45 * clamp(thigh, 0.0, 1.0)) * twill;
			float seam = step(0.96, abs(rest_nx)) * step(0.0, rest_nx * rest.x);
			cloth = mix(cloth, vec3(0.75, 0.5, 0.25), 0.5 * seam * step(0.5, fract(rest.y * 120.0)));
			cloth = mix(cloth, cloth * 0.7, smoothstep(0.06, 0.0, rest.y));  // lahkeen suu
		}
		if (workwear && c > 1.5 && c < 2.5) {
			// Työhousut: tummat vahvikkeet polvissa ja riipputaskut lantiolla, heijastinraita säären ympäri.
			float knee = smoothstep(0.02, 0.05, lpos.z) * step(abs(rest.y - 0.5), 0.07);
			cloth = mix(cloth, vec3(0.05, 0.05, 0.055), knee);
			float holster = step(abs(rest.y - 0.88), 0.06) * step(0.0, lpos.z) * step(0.12, abs(rest.x));
			cloth = mix(cloth, vec3(0.06, 0.06, 0.065), holster);
			float reflect = step(abs(rest.y - 0.29), 0.018);
			cloth = mix(cloth, vec3(0.85, 0.86, 0.82), reflect);
		}
		if (flannel && c > 0.5 && c < 1.5) {
			// Flanelli: leveät tummat ruudut ja ohuet vaaleat viivat.
			// Tartan: tummat raidat kumpaankin suuntaan, risteyksissä tummempi, ohut keltainen viiva harvakseltaan.
			vec2 ck = vec2(rest.x * (lpos.z > 0.0 ? 1.0 : -1.0), rest.y) * 11.0;
			float bx = smoothstep(0.52, 0.56, fract(ck.x)) * smoothstep(0.92, 0.88, fract(ck.x));
			float by = smoothstep(0.52, 0.56, fract(ck.y)) * smoothstep(0.92, 0.88, fract(ck.y));
			cloth *= 1.0 - 0.35 * bx - 0.35 * by;
			float fine = max(step(abs(fract(ck.x) - 0.25), 0.015), step(abs(fract(ck.y) - 0.25), 0.015));
			cloth = mix(cloth, vec3(0.75, 0.6, 0.25), fine * 0.35);
		}
		if (net_shirt && c > 0.5 && c < 1.5) {
			cloth *= 0.85 + 0.15 * hash21(floor(rest * 140.0));  // lanka kulunut ja epätasainen
			if (suspenders && abs(abs(rest.x) - 0.1) < 0.014 && rest.y > 0.98 && rest.y < 1.52) {
				cloth = strap_col * (0.85 + 0.15 * step(0.5, fract(rest.y * 90.0)));
			}
		}
		if (belt_y > 0.0 && c > 1.5 && c < 2.5 && rest.y > belt_y - 0.04 && rest.y < belt_y) {
			// Vyö: musta nahka, ommel reunoissa, hopeinen solki edessä.
			cloth = belt_col * (1.0 - 0.4 * step(abs(rest.y - (belt_y - 0.02)), 0.017) * 0.0);
			float stitchb = step(abs(abs(rest.y - (belt_y - 0.02)) - 0.016), 0.002) * step(0.5, fract(rest.x * 200.0));
			cloth = mix(cloth, vec3(0.35), stitchb);
			if (lpos.z > 0.0 && abs(rest.x) < 0.035) {
				float rim = step(0.026, abs(rest.x)) + step(abs(rest.y - (belt_y - 0.02)), 0.02) * step(0.0, -abs(rest.x) + 0.035);
				cloth = mix(vec3(0.62, 0.63, 0.65), vec3(0.85, 0.86, 0.88), step(0.5, rim));
			}
		}
		// Kankaan kude: hienot raidat + tekstuurin varjostus säilyy.
		float weave = 0.94 + 0.06 * sin(lpos.y * 900.0) * sin(lpos.x * 700.0 + lpos.z * 700.0);
		ALBEDO = cloth * mix(0.96, 0.72 + 0.5 * lum, muscle_def) * weave;
		ROUGHNESS = c > 2.5 ? 0.45 : mix(0.9, 0.5, fabric_shine);
		if (belt_y > 0.0 && c > 1.5 && c < 2.5 && rest.y > belt_y - 0.04 && rest.y < belt_y) {
			ROUGHNESS = lpos.z > 0.0 && abs(rest.x) < 0.035 ? 0.2 : 0.45;
			METALLIC = lpos.z > 0.0 && abs(rest.x) < 0.035 ? 0.9 : 0.0;
		}
		if (workwear && c > 1.5 && c < 2.5 && abs(rest.y - 0.29) < 0.018) {
			ROUGHNESS = 0.2;
			SPECULAR = 0.9;
		}
		SPECULAR = mix(0.25, 0.45, fabric_shine);
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), n, 0.18 * muscle_def);
	}
}
