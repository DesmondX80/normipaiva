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
varying vec3 rest_zn;  // lepoasennon z sekä normaalin y ja z (CUSTOM0)
// Hyllyntä (Character._update_jiggle): osakohtaisen jousen siirto verkon avaruudessa, paino CUSTOM1 (r rinta, g vatsa,
// b pakara ja reiden yläosa). Lisätään ennen painumaa, joten kontaktilaatikko pitää hyllyvän pinnan ulkona.
uniform vec3 jiggle_rinta = vec3(0.0);
uniform vec3 jiggle_vatsa = vec3(0.0);
uniform vec3 jiggle_pakara = vec3(0.0);
uniform bool jiggle_debug = false;  // painot väreinä: magenta rinta, syaani vatsa, vihreä pakara
varying vec3 jig_w;

#include "res://shaders/press.gdshaderinc"

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
uniform float grime = 0.0;       // rähjäisyys: noki- ja multatahroja iholla (kasvot, kädet, rinta), 0..1
uniform vec3 strap_col : source_color = vec3(0.55, 0.42, 0.25);
uniform bool workwear = false;   // työhousut: vahvikkeet polvissa, riipputaskut, heijastinraita säären ympäri
uniform bool flannel = false;    // flanellipaita: ruudutus
uniform bool tattoo = false;     // tatuointi vasemmassa olkavarressa (näkyy paljaalta iholta ja verkon läpi)
uniform bool string_bikini = false;  // pienet lappubikinit: kolmiot rintojen päällä, pieni alaosa, ohuet nauhat
// Kasarin hiihtohaalari (paita ja housut samaa kangasta, pohjaväri shirt): valkoinen olkakaarroke, jonka alareuna on
// vuoristosahalaita, sen alla keltainen ja turkoosi raita, tikkauskanavat, vetoketju, vyötärökuminauha, ribbiresorit
// ja kuukengät.
uniform bool ski_suit = false;
uniform vec3 ski_yoke : source_color = vec3(0.95, 0.95, 0.97);
uniform vec3 ski_line1 : source_color = vec3(1.0, 0.9, 0.05);
uniform vec3 ski_line2 : source_color = vec3(0.0, 0.78, 0.82);

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

// Arvokohina (pehmeä): tahrojen muoto.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

vec3 skin_with_ink(vec3 skin, vec2 r, vec3 lp) {
	vec3 col = mix(skin, vec3(0.08, 0.16, 0.14), 0.85 * tattoo_ink(r, lp));
	if (grime > 0.0) {
		// Nokisia ja mullanruskeita tahroja: isoja läikkiä ja pieniä roiskeita, hieman enemmän alhaalla (kädet, vyötärö).
		float blot = smoothstep(0.55, 0.8, vnoise(r * 38.0 + vec2(lp.z * 9.0, 3.0)));
		float fleck = smoothstep(0.72, 0.9, vnoise(r * 150.0));
		col = mix(col, vec3(0.2, 0.14, 0.1), grime * clamp(0.85 * blot + 0.6 * fleck, 0.0, 1.0));
	}
	return col;
}

// Verkkopaidan silmukka: 1 = lanka, 0 = reikä (iho näkyy). Isot repeämät satunnaisissa ruuduissa.
float net_thread(vec2 r, vec3 lp) {
	vec2 g = vec2(r.x * 42.0 + (lp.z > 0.0 ? 0.0 : 0.5), r.y * 42.0);
	vec2 f = abs(fract(g) - 0.5);
	float hole = step(max(f.x, f.y), 0.34);
	float tear = step(0.94, hash21(floor(vec2(r.x * 22.0 + (lp.z > 0.0 ? 0.0 : 3.0), r.y * 16.0))));
	// Isot repeämät edessä (rinta, vatsa, olkapää): epäsäännölliset soikiot, joiden reunat ovat rispaantuneet.
	float rip = 0.0;
	if (lp.z > 0.0) {
		vec2 ra = (r - vec2(-0.075, 1.34)) / vec2(0.05, 0.065);
		vec2 rb = (r - vec2(0.04, 1.14)) / vec2(0.075, 0.055);
		vec2 rc = (r - vec2(0.175, 1.47)) / vec2(0.04, 0.05);
		float wob = (hash21(floor(r * 120.0)) - 0.5) * 0.35;
		rip = max(step(length(ra) + wob, 1.0), max(step(length(rb) + wob, 1.0), step(length(rc) + wob, 1.0)));
	}
	return 1.0 - max(max(hole, tear), rip);
}

// Janan ab etäisyys pisteestä p.
float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - (a + ab * t));
}

// Kolmion etäisyys (negatiivinen sisällä), Inigo Quilezin sdTriangle.
float sd_tri(vec2 p, vec2 a, vec2 b, vec2 c) {
	vec2 e0 = b - a, e1 = c - b, e2 = a - c;
	vec2 v0 = p - a, v1 = p - b, v2 = p - c;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
		vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
		vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

// Lappubikinit vartalon pinnalla lepoasennon koordinaateissa (p = paikka, n = normaali). Palauttaa etäisyyden
// kankaan reunaan metreinä (negatiivinen = kangasta). Kappaleet:
//  - yläosa: kaksi kolmiota rintojen päällä (edestä katsottuna), kärjistä nauhat niskaan, rintojen alla kiertävä nauha
//  - alaosa edessä: kolmio, jonka kärki on haarassa
//  - alaosa takana: kolmio vaon yläpäässä ja siitä ohut kaistale vakoa pitkin haaraan
//  - haarakappale: kapea kaistale haaran alapinnalla (yhdistää etu- ja takakappaleen)
//  - sivunauhat: kolmioiden yläkulmista vinosti korkealle lantiolle; lasketaan kulmana vartalon ympäri (a = kaari),
//    jotta nauha kiertää lantion sivun oikein
float bikini_sd(vec3 p, vec3 n) {
	float d = 1.0;
	float ax = abs(p.x);
	bool fr = p.z > -0.025;  // lantion ja rintakehän keskikohta syvyydessä
	// Yläosa: pienet kolmiot vain rintojen keskellä. Täyteläisen rinnan (bust) etupinta kattaa lepoasennossa
	// y ≈ 1,21–1,40, ja näkyvä keskikohta on ≈ (0,082, 1,32) (luettu 1 cm koordinaattiruudukosta, testikohtaus bikini).
	// Kolmion kulmista nauha kiertää vartalon ympäri ja kärjestä nousee niskanauha.
	if (p.y > 1.2 && p.y < 1.6 && ax < 0.2) {
		if (p.z > -0.02) {
			d = min(d, sd_tri(vec2(ax, p.y), vec2(0.036, 1.288), vec2(0.117, 1.288), vec2(0.078, 1.372)));
			// Niskanauha kolmion kärjestä kaulan ympäri.
			d = min(d, seg_dist(vec2(ax, p.y), vec2(0.078, 1.368), vec2(0.05, 1.56)) - 0.004);
		}
		d = min(d, abs(p.y - 1.288) - 0.004);
	}
	// Alaosa.
	if (p.y > 0.83 && p.y < 1.08 && ax < 0.21) {
		if (fr) {
			// Idle-asennossa reidet vetävät haaraa sivulle: näkyvä haarakohta on lepoasennon x = +0,016:ssa (mitattu
			// värijuovin edestä). Kärki on siellä, yläreuna vatsan keskilinjalla.
			float tri = sd_tri(vec2(p.x, p.y), vec2(-0.078, 0.966), vec2(0.078, 0.966), vec2(0.016, 0.868));
			d = min(d, tri);
		} else {
			// Idle-asennon painonsiirto vetää pakaroita eri tavoin: näkyvä vako on lepoasennon x = -0,012:ssa
			// (mitattu värijuovin, testikohtaus bikini). Takakolmion kärki ja kaistale seuraavat vakoa.
			float dx = -0.012;
			d = min(d, sd_tri(vec2(p.x, p.y), vec2(-0.075, 0.986), vec2(0.075, 0.986), vec2(dx, 0.928)));
			d = min(d, seg_dist(vec2(p.x, p.y), vec2(dx, 0.93), vec2(dx, 0.87)) - 0.006);
		}
		// Haarakappale: alaspäin osoittava pinta haarassa, etukolmion kärjestä (x +0,016) takakaistaleeseen (x -0,012).
		if (p.y < 0.89 && n.y < -0.25 && p.z > -0.05) {
			d = min(d, abs(p.x - mix(-0.012, 0.016, smoothstep(-0.05, 0.02, p.z))) - 0.012);
		}
		// Sivunauhat: kaari a = kulma vartalon ympäri * säde (edessä 0, sivulla R*pi/2, takana R*pi).
		float R = 0.16;
		float a = abs(atan(p.x, p.z + 0.025)) * R;
		vec2 q = vec2(a, p.y);
		vec2 side = vec2(R * 1.5708, 1.03);
		// Nauhat jatkuvat hieman kolmioiden sisään, jotta ne liittyvät kulmiin (kolmio peittää jatkeen).
		d = min(d, seg_dist(q, vec2(R * 0.6, 0.957), side) - 0.0045);
		d = min(d, seg_dist(q, side, vec2(R * 2.9, 0.972)) - 0.0045);
	}
	return d;
}

// Paljas iho vaatteen kohdalla? (c = luokka, r = lepoasento, lp = paikka)
bool bare(float c, vec2 r, vec3 lp, float fr, float nx) {
	if (c > 1.5 && c < 2.5 && shorts_y > 0.0 && r.y < shorts_y + (denim ? fray(lp) : 0.0)) {
		return true;
	}
	if (c > 0.5 && c < 1.5 && ((crop_y > 0.0 && r.y < crop_y && abs(r.x) < 0.26) || abs(r.x) > sleeve_x
			|| (tube_y > 0.0 && r.y > tube_y))) {
		return true;
	}
	return false;
}

// Hiihtohaalarin vetoketju: edessä keskellä haarasta kaulukseen (1 = hammas tai vetimen läppä).
float ski_zip(float c, vec2 r, vec3 lp) {
	if (c < 0.5 || c > 1.5 || abs(r.x) > 0.03 || lp.z < 0.0 || r.y < 1.03 || r.y > 1.52) {
		return 0.0;
	}
	float teeth = (1.0 - step(0.005, abs(r.x))) * step(0.5, fract(r.y * 260.0));
	float tab = step(abs(r.x - 0.01), 0.008) * step(abs(r.y - 1.44), 0.022);
	return max(teeth, tab);
}

// Hiihtohaalarin kangas (c = luokka, cloth = pohjaväri): kuviot lepoasennon koordinaateista.
vec3 ski_cloth(float c, vec3 cloth, vec2 r, vec3 lp, float nx) {
	float ax = abs(r.x);
	bool torso = ax < 0.26;
	if (c > 2.5) {
		// Kuukengät: paksut vaakatikkaukset, tumma kumipohja.
		float rib = 0.82 + 0.18 * smoothstep(0.0, 0.35, abs(fract(r.y * 45.0) - 0.5));
		return mix(cloth * rib, vec3(0.08, 0.08, 0.09), step(r.y, 0.022));
	}
	if (c > 0.5 && c < 1.5) {
		if (torso) {
			// Olkakaarroke: sahalaitainen alareuna kuin vuorenhuiput, raidat sen alla.
			float zig = 1.24 + 0.09 * abs(fract(r.x * 8.0 + 0.5) - 0.5) * 2.0;
			float d = r.y - zig;
			cloth = d > 0.0 ? ski_yoke : cloth;
			cloth = mix(cloth, ski_line1, step(-0.032, d) * step(d, 0.0));
			cloth = mix(cloth, ski_line2, step(-0.054, d) * step(d, -0.032));
			// Pystykaulus mustaa ribbiä, turkoosi reunus.
			float col = step(1.475 + 0.5 * max(ax - 0.07, 0.0), r.y) * step(ax, 0.11);
			cloth = mix(cloth, vec3(0.05, 0.05, 0.06) * (0.85 + 0.15 * step(0.5, fract(r.x * 160.0))), col);
			cloth = mix(cloth, ski_line2, step(abs(r.y - 1.475 - 0.5 * max(ax - 0.07, 0.0)), 0.004) * step(ax, 0.11));
		} else {
			// Hihat: valkoinen olkavarsi, raidat, pinkki kyynärvarsi ja musta ranneresori.
			cloth = ax < 0.4 ? ski_yoke : cloth;
			cloth = mix(cloth, ski_line1, step(0.4, ax) * step(ax, 0.428));
			cloth = mix(cloth, ski_line2, step(0.428, ax) * step(ax, 0.446));
			cloth = mix(cloth, vec3(0.05, 0.05, 0.06) * (0.85 + 0.15 * step(0.5, fract(r.y * 160.0))), step(0.645, ax));
		}
	} else {
		// Lahkeet: keltainen ja turkoosi sivuraita, vyötärön kuminauha ja nilkkaresori.
		float side = step(0.0, nx * r.x) * step(r.y, 0.97) * step(0.1, r.y);
		cloth = mix(cloth, ski_line2, side * step(0.86, abs(nx)) * step(abs(nx), 0.93));
		cloth = mix(cloth, ski_line1, side * step(0.93, abs(nx)));
		float waist = step(abs(r.y - 1.0), 0.02);
		cloth = mix(cloth, cloth * (0.72 + 0.2 * step(0.5, fract(r.x * 110.0))), waist);
		cloth = mix(cloth, vec3(0.05, 0.05, 0.06) * (0.85 + 0.15 * step(0.5, fract(r.x * 160.0))), step(r.y, 0.1));
	}
	// Tikkauskanavat: pullea toppaus ja tumma tikkisauma (hihoissa poikittain kädenvarteen).
	float u = (c > 0.5 && c < 1.5 && !torso) ? ax * 16.0 : r.y * 14.0;
	float puffq = 0.86 + 0.14 * sin(fract(u) * 3.14159);
	bool cuff = (c > 0.5 && c < 1.5 && ((r.y > 1.475 && ax < 0.11) || ax > 0.645)) || (c > 1.5 && r.y < 0.1);
	cloth *= cuff ? 1.0 : puffq;
	// Vetoketju: musta nauha, hopeiset hampaat ja vetimen läppä.
	if (c > 0.5 && c < 1.5 && torso && lp.z > 0.0 && r.y > 1.03 && r.y < 1.52) {
		cloth = mix(cloth, vec3(0.04), 1.0 - step(0.011, ax));
		cloth = mix(cloth, vec3(0.8, 0.81, 0.85), ski_zip(c, r, lp));
	}
	return cloth;
}

void vertex() {
	cat = COLOR.r * 4.0;
	stripe = COLOR.g;
	lpos = VERTEX;
	rest = UV2;
	front = COLOR.b;
	rest_nx = COLOR.a * 2.0 - 1.0;
	rest_zn = CUSTOM0.xyz;
	jig_w = CUSTOM1.rgb;
	VERTEX += jiggle_rinta * CUSTOM1.r + jiggle_vatsa * CUSTOM1.g + jiggle_pakara * CUSTOM1.b;
	// Vaatteet vähän irti ihosta, ettei näytä maalatulta trikoolta.
	float c = floor(cat + 0.5);
	float puff = c > 0.5 && c < 1.5 ? shirt_puff : (c > 1.5 && c < 2.5 ? pants_puff : (c > 2.5 ? 0.01 : 0.0));
	if (bare(c, UV2, VERTEX, COLOR.b, COLOR.a * 2.0 - 1.0) || string_bikini) {
		puff = 0.0;  // lappubikinit ovat iholla kiinni (väri lasketaan fragmentissa)
	}
	VERTEX += NORMAL * puff;
	if (press_n > 0 && CUSTOM0.w > 0.0) {
		// Kontaktipainuma laatikko kerrallaan (Elastic.press): pehmeä verteksi painuu pinnalle ja levenee sivulle.
		vec3 pn;
		float pd;
		vec3 pv = VERTEX;
		float lim = CUSTOM0.w + puff;  // vaate painuu mukana: raja + pöyhennys
		float used = 0.0;  // raja on kaikille laatikoille yhteinen
		for (int i = 0; i < 6; i++) {
			if (i >= press_n) {
				break;
			}
			pv += press_disp(press_xf(i), press_half(i), pv, lim, used, NORMAL, pn, pd);
			used += pd * lim;
		}
		VERTEX = pv;
	}
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float c = floor(cat + 0.5);
	vec3 n = texture(normal_tex, UV).rgb;
	bool net_hole = net_shirt && c > 0.5 && c < 1.5 && net_thread(rest, lpos) < 0.5
		&& !(suspenders && abs(abs(rest.x) - 0.1) < 0.014 && rest.y > 0.98 && rest.y < 1.52);
	if (string_bikini && c > 0.5 && c < 2.5) {
		// Lappubikinit: kankaan peitto etäisyysfunktiosta, pehmeä reuna (ruudun kokoinen) ja kanttinauha reunoissa.
		float d = bikini_sd(vec3(rest, rest_zn.x), vec3(rest_nx, rest_zn.y, rest_zn.z));
		float aa = clamp(fwidth(d) * 0.75, 0.0002, 0.004);  // raja: laskenta-alueen reunalla d hyppää
		float cov = 1.0 - smoothstep(-aa, aa, d);
		vec3 skin = skin_with_ink(bare_skin * skin_tint * (0.82 + 0.25 * lum), rest, lpos);
		vec3 cloth = rest.y < 1.12 ? pants : shirt;
		cloth *= 1.0 - 0.2 * (1.0 - smoothstep(0.002, 0.0045, -d));  // kanttinauha
		cloth *= 0.82 + 0.25 * lum;
		ALBEDO = mix(skin, cloth, cov);
		ROUGHNESS = mix(0.55, mix(0.9, 0.45, fabric_shine), cov);
		SPECULAR = mix(0.5, mix(0.25, 0.5, fabric_shine), cov);
		SSS_STRENGTH = 0.35 * (1.0 - cov);
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else if (net_hole) {
		// Verkon silmukasta näkyy iho (ja tatuointi).
		ALBEDO = skin_with_ink(bare_skin * skin_tint * (0.82 + 0.25 * lum), rest, lpos);
		ROUGHNESS = 0.55;
		SSS_STRENGTH = 0.35;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else if (c > 0.5 && c < 2.5 && bare(c, rest, lpos, front, rest_nx)) {
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
		if (ski_suit) {
			cloth = ski_cloth(c, cloth, rest, lpos, rest_nx);
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
		if (ski_suit && ski_zip(c, rest, lpos) > 0.5) {
			ROUGHNESS = 0.25;
			METALLIC = 0.8;
		}
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), n, 0.18 * muscle_def);
	}
	if (jiggle_debug) {
		ALBEDO = mix(vec3(0.5), vec3(1.0, 0.0, 1.0), jig_w.r) * (1.0 - jig_w.g) + vec3(0.0, 1.0, 1.0) * jig_w.g;
		ALBEDO = mix(ALBEDO, vec3(0.0, 1.0, 0.0), jig_w.b);
	}
}
