shader_type spatial;
// Kengät (scripts/shoes.gd): päällinen ja pohja samassa skinnatussa verkossa. Yksityiskohdat piirretään lepoasennon
// koordinaateista: UV = (pituus 0 kanta .. 1 kärki, korkeus kuoren alapinnasta m), UV2 = (sivu -1..1, + = ulkosivu; osa:
// 0 päällinen (kumisaappaassa koko kuori kärjestä yläreunaan), 1 pohja, 2 varsi (2,2 = varren yläreunan levy ja
// sisäpinta). Varressa UV = (kulma: 0 = etu, -0,5..0,5; korkeus kuoren alapinnasta m). Väri: pisteväri sRGB (vertex_color_is_srgb-vastine), päällinen main_col.

uniform vec3 main_col : source_color = vec3(0.9);
uniform vec3 sole_col : source_color = vec3(0.95, 0.94, 0.9);
uniform float rough = 0.6;
uniform float sole_rough = 0.8;
uniform int style = 0;  // 0 lenkkari, 1 varattu nauhakengälle, 2 kävelykenkä, 3 työkenkä, 4 kumisaapas, 5 nahkasaapas, 6 sandaali, 7 kuukenkä (TYPES style)
uniform float sole_h = 0.02;  // pohjalaatan paksuus kuoren alapinnasta alas (TYPES sole)
uniform float rand_h = 0.0015;  // pohjan reunus kuoren kylkeä ylös (TYPES rand)
uniform float spec = 0.4;
uniform float clearcoat = 0.0;  // lakkakiilto (nahka)
uniform vec3 cord_col : source_color = vec3(0.9, 0.2, 0.15);
uniform float shaft_h = 0.133;  // varren yläreuna kuoren alapinnasta (TYPES shaft.top + lift - sole)

varying vec2 fu;
varying vec2 fu2;

void vertex() {
	fu = UV;
	fu2 = UV2;
}

float band(float x, float a, float b, float soft) {
	return smoothstep(a - soft, a + soft, x) * (1.0 - smoothstep(b - soft, b + soft, x));
}

void fragment() {
	float t = fu.x;
	float h = fu.y;
	float s = fu2.x;
	float lum = dot(main_col, vec3(0.299, 0.587, 0.114));
	vec3 accent = lum > 0.5 ? vec3(0.08, 0.14, 0.38) : vec3(0.9, 0.9, 0.88);
	if (fu2.y > 1.5) {
		// Työkengän varsi: etuaukossa kieli ja ristiin kulkevat nauhat, sivuilla metalliset koukut, takana kantakappale,
		// yläreunassa tumma pehmuste ja tikkaus. Levy ja sisäpinta (osa 2,2) tummaa vuorta.
		float u = t;
		float au = abs(u);
		vec3 c = main_col;
		if (fu2.y > 2.1 && style == 4) {
			// Kumisaappaan suu: tumma sisäkumi, yläreunan huuli kauluksen väristä.
			c = mix(main_col * 0.32, sole_col * vec3(0.8, 0.78, 0.74), smoothstep(shaft_h - 0.006, shaft_h - 0.002, h));
		} else if (fu2.y > 2.1) {
			c = main_col * 0.32;
		} else if (style == 7) {
			// Kuukengän toppavarsi: nylonpinta vaakatikkauksin (toppaus), edessä ristiin kulkeva nyöritys lenkeissä,
			// yläreunassa kiristyskuja, nyöri ja stoppari.
			float quilt = band(fract(h * 22.0), 0.0, 0.06, 0.02);
			c *= 1.0 - 0.22 * quilt;
			c *= 0.9 + 0.1 * smoothstep(0.0, 0.5, fract(h * 22.0)) ;  // toppauksen pullistuma: vaalea yläreuna
			float row = 0.026;
			float hr = h - 0.1;
			float zig = 0.07 * abs(fract(hr / row) * 2.0 - 1.0);
			float lace = (1.0 - smoothstep(0.004, 0.007, abs(au - zig))) * step(0.0, hr) * step(h, shaft_h - 0.03) * step(au, 0.075);
			float eye = (1.0 - smoothstep(0.006, 0.009, length(vec2((au - 0.07) * 0.6, fract(hr / row + 0.5) * row - row * 0.5)))) * step(0.0, hr) * step(h, shaft_h - 0.03);
			c = mix(c, c * 0.45, eye);
			c = mix(c, cord_col, lace);
			c = mix(c, c * 0.8, band(h, shaft_h - 0.024, shaft_h, 0.001));  // kiristyskuja
			c = mix(c, cord_col, band(h, shaft_h - 0.013, shaft_h - 0.009, 0.0006) * step(0.03, au));  // nyöri
			c = mix(c, vec3(0.12, 0.12, 0.14), band(au, 0.0, 0.016, 0.001) * band(h, shaft_h - 0.02, shaft_h - 0.002, 0.001));  // stoppari
		} else if (style == 5) {
			// Nahkasaappaan varsi: sileä nahka, yläreunassa käännetty päärme tikkeineen, takana pystysauma, nilkassa rypyt.
			c *= 0.86 + 0.14 * smoothstep(0.05, shaft_h, h);
			c = mix(c, c * 0.6, 1.0 - smoothstep(0.003, 0.006, 0.5 - au));  // takasauma
			c = mix(c, c * 0.78, band(h, shaft_h - 0.016, shaft_h, 0.0008));  // päärme
			c = mix(c, c * 1.5 + 0.04, band(h, shaft_h - 0.0185, shaft_h - 0.0172, 0.0003) * step(0.5, fract(u * 150.0)));  // tikki
			c *= 1.0 - 0.1 * band(fract((h - 0.09) * 55.0), 0.0, 0.3, 0.08) * (1.0 - smoothstep(0.09, 0.15, h));  // nilkan rypyt
		} else if (style == 4) {
			// Kumisaappaan varsi (jäykkä putki): kuten kuori, vaalea kaulusraita ja ura sen alla yläreunassa.
			c *= 0.9 + 0.1 * smoothstep(0.05, shaft_h, h);
			c = mix(c, c * 0.45, band(h, shaft_h - 0.0215, shaft_h - 0.0185, 0.0006));
			c = mix(c, sole_col * vec3(0.84, 0.82, 0.78) * (0.9 + 0.1 * smoothstep(shaft_h - 0.018, shaft_h, h)),
				smoothstep(shaft_h - 0.0185, shaft_h - 0.0175, h));
		} else {
			float row = 0.0155;  // nauharivien väli (m)
			float hr = h - 0.07;  // ensimmäinen koukkurivi
			float open_ = 1.0 - smoothstep(0.072, 0.08, au);
			c = mix(c, c * 0.62, open_);  // kieli
			float zig = 0.06 * abs(fract(hr / row) * 2.0 - 1.0);
			float lace = open_ * (1.0 - smoothstep(0.0035, 0.0065, abs(au - zig))) * step(-0.004, hr) * step(h, shaft_h - 0.008);
			c = mix(c, vec3(0.16, 0.1, 0.06) * (0.8 + 0.4 * step(0.5, fract((h + u) * 260.0))), lace);
			// Koukut ja niittiaukot nauharivien päissä.
			float hk = (fract(hr / row + 0.5) - 0.5) * row;
			float dk = length(vec2((au - 0.088) * 0.3, hk));
			float hook = (1.0 - smoothstep(0.0028, 0.0034, dk)) * step(-0.004, hr) * step(h, shaft_h - 0.01);
			c = mix(c, vec3(0.62, 0.6, 0.56) * (0.7 + 0.5 * smoothstep(0.0, 0.003, hk)), hook);
			c = mix(c, vec3(0.05), hook * (1.0 - smoothstep(0.0012, 0.0017, dk)));
			// Nahan reunat aukon vieressä ja tikki.
			c = mix(c, c * 0.7, band(au, 0.078, 0.082, 0.002) * (1.0 - open_));
			float st = band(au, 0.103, 0.107, 0.001) * step(0.5, fract(h * 220.0));
			c = mix(c, vec3(0.85, 0.7, 0.4), st * 0.7);
			// Pehmustettu yläreuna.
			float pad = smoothstep(shaft_h - 0.014, shaft_h - 0.011, h);
			c = mix(c, c * 0.5, pad);
			c = mix(c, vec3(0.85, 0.7, 0.4), band(h, shaft_h - 0.017, shaft_h - 0.0155, 0.0004) * step(0.5, fract(u * 160.0)) * 0.7);
			c *= 0.85 + 0.15 * smoothstep(0.03, shaft_h, h);
		}
		ALBEDO = c;
		ROUGHNESS = rough;
		SPECULAR = spec;
		if (style >= 4) {
			CLEARCOAT = clearcoat;
			CLEARCOAT_ROUGHNESS = style == 4 ? 0.2 : 0.35;
		}
	} else if (fu2.y > 0.5) {
		vec3 c = sole_col;
		float bottom = 1.0 - smoothstep(-sole_h + 0.0025, -sole_h + 0.0035, h);
		if (style == 0) {
			// Pohja: välipohja vaalea, ohut tumma raita reunassa, alapinnassa poikittaiset urat (pito).
			c = mix(c, c * 0.55, band(h, -0.0075, -0.0055, 0.0005));
			c = mix(c, vec3(0.32, 0.3, 0.28), bottom);
			c *= 1.0 - 0.35 * bottom * step(0.5, fract(t * 38.0));
		} else if (style == 1) {
			// Nahkapohja: reunuksessa (rand) pistetikki, alapinta tummempi, korko kumia.
			float welt = band(h, rand_h - 0.0016, rand_h - 0.0004, 0.0002);
			c = mix(c, c * 0.55, welt * step(0.5, fract(t * 90.0)));
			c = mix(c, c * 0.6, bottom);
			// Korko (t < 0,24, shoes.gd th): tumma nahkapino kerroksina, kumilappu alimpana.
			float heel = (1.0 - smoothstep(0.235, 0.245, t)) * (1.0 - smoothstep(-0.0005, 0.0005, h));
			vec3 hc = vec3(0.13, 0.08, 0.05) * (0.85 + 0.3 * step(0.5, fract(h * 380.0)));
			c = mix(c, hc, heel);
			c = mix(c, vec3(0.06, 0.055, 0.05), bottom * (1.0 - smoothstep(0.235, 0.245, t)));
		} else if (style == 3) {
			// Työkengän nastapohja: keltainen rantatikki reunuksessa, kyljessä pystyurat, alapinnassa syvät palat.
			c = mix(c, vec3(0.8, 0.62, 0.3), band(h, rand_h - 0.0045, rand_h - 0.003, 0.0003) * step(0.45, fract(t * 80.0)));
			c = mix(c, c * 1.35, band(h, -0.0015, 0.0005, 0.0005));  // reunuksen ja pohjan välinen kumiraita
			float groove = band(h, -sole_h + 0.004, -0.004, 0.0006) * band(fract(t * 34.0), 0.0, 0.22, 0.03);
			c = mix(c, c * 0.45, groove);
			c = mix(c, c * 0.6, bottom);
			c *= 1.0 - 0.35 * bottom * step(0.5, fract(t * 26.0));
		} else if (style == 7) {
			// Kuukengän pohja: paksu vaalea kumi nousee kyljille, vaakaurat kyljessä, tumma kuviopohja.
			c = mix(c, c * 0.8, band(fract((h + sole_h) * 95.0), 0.0, 0.16, 0.04) * step(h, rand_h - 0.004));
			c = mix(c, c * 0.7, band(h, rand_h - 0.003, rand_h, 0.0006));
			c = mix(c, vec3(0.2, 0.2, 0.22), bottom);
			c *= 1.0 - 0.3 * bottom * step(0.5, fract(t * 22.0));
		} else if (style == 6) {
			// Sandaalin pohjalaatta: korkkikylki (rakeinen), ohut tumma kumi alla ja nahkainen sisäpohja päällä.
			float grain = fract(sin(dot(floor(vec2(t * 420.0, h * 900.0)), vec2(12.9898, 78.233))) * 43758.5453);
			c *= 0.86 + 0.22 * grain;
			c = mix(c, vec3(0.1, 0.09, 0.08), 1.0 - smoothstep(-sole_h + 0.004, -sole_h + 0.005, h));  // kumipohja
			c = mix(c, vec3(0.5, 0.35, 0.23), smoothstep(-0.0015, -0.0005, h));  // nahkainen sisäpohja
		} else if (style == 5) {
			// Nahkasaappaan pohja: ohut tumma nahkapohja, reunassa tikki, korko kerroksina.
			c = mix(c, c * 2.2 + 0.05, band(h, rand_h - 0.0022, rand_h - 0.0012, 0.0003) * step(0.5, fract(t * 90.0)));
			float heel = (1.0 - smoothstep(0.235, 0.245, t)) * (1.0 - smoothstep(-0.0005, 0.0005, h));
			c = mix(c, c * (0.8 + 0.5 * step(0.5, fract(h * 330.0))), heel);
		} else if (style == 4) {
			// Kumisaappaan pohja: vaalea reunus ilman tikkiä (kiiltävä raita yläreunassa), kyljessä pystyurat,
			// alapinnassa tumma nastapohja. Kermanvaalea (sole_col sellaisenaan palaa valkoiseksi kiiltävän kumin vieressä).
			c *= vec3(0.86, 0.84, 0.8);
			c = mix(c, c * 1.12, band(h, rand_h - 0.004, rand_h - 0.0015, 0.0006));
			c = mix(c, c * 0.8, band(h, -0.0015, 0.0005, 0.0005));
			float groove = band(h, -sole_h + 0.004, -0.004, 0.0006) * band(fract(t * 34.0), 0.0, 0.22, 0.03);
			c = mix(c, c * 0.6, groove);
			c = mix(c, vec3(0.1, 0.095, 0.09), bottom);
			c *= 1.0 - 0.4 * bottom * step(0.5, fract(t * 26.0));
		} else {
			// Kävelykengän kumipohja: tikkaus reunuksessa, sivussa matala ura, alapinnassa tiheä kuvio.
			c = mix(c, c * 0.7, band(h, rand_h - 0.0022, rand_h - 0.0014, 0.0003) * step(0.45, fract(t * 70.0)));
			c = mix(c, c * 0.78, band(h, -sole_h * 0.45, -sole_h * 0.38, 0.0004));
			c = mix(c, c * 0.62, bottom);
			c *= 1.0 - 0.3 * bottom * step(0.5, fract(t * 52.0));
		}
		c *= 0.9 + 0.1 * smoothstep(-sole_h, 0.0, h);  // tumma alareuna
		ALBEDO = c;
		ROUGHNESS = sole_rough;
		SPECULAR = 0.3;
	} else if (style == 1) {
		// Nauhakenkä (oxford): kiiltävä nahka, kärkiosan sauma t 0,78 ja suljettu nauhoitus jalan päällä.
		vec3 c = main_col;
		float top_ = smoothstep(0.03, 0.04, h);
		float cap_seam = band(t, 0.775, 0.785, 0.002) * (1.0 - smoothstep(0.035, 0.05, h - 0.01));
		float brogue = band(t, 0.792, 0.8, 0.0015) * step(0.5, fract(s * 9.0)) * (1.0 - smoothstep(0.03, 0.05, h));
		c = mix(c, c * 0.45, max(cap_seam, brogue * 0.6));
		// Nauhoituksen V: kaksi nauhakappaletta kohtaavat keskiviivalla, 4 poikittaista ohutta nauhaa.
		// Lestin mukaan (#279: kenkä on jalkaa pidempi): nauhoitus t 0,46–0,70, leveys ±18 mm, 5 nauhaa.
		float zone = band(t, 0.46, 0.7, 0.006) * top_;
		float vamp = 1.0 - smoothstep(0.32, 0.38, abs(s) - (0.7 - t) * 0.5);
		float edge = zone * band(abs(s) - (0.7 - t) * 0.5, 0.3, 0.36, 0.012);
		c = mix(c, c * 0.5, edge);
		float lace = zone * vamp * band(fract((t - 0.46) * 21.0), 0.3, 0.62, 0.04);
		c = mix(c, vec3(0.05, 0.04, 0.035), lace * (1.0 - smoothstep(0.26, 0.32, abs(s))));
		// Reunatikki suun ympärillä ja kantalappu (vasta).
		float heel = (1.0 - smoothstep(0.17, 0.19, t)) * smoothstep(0.012, 0.016, h);
		c = mix(c, c * 0.8, heel);
		c *= 0.8 + 0.2 * smoothstep(0.0, 0.05, h);
		ALBEDO = c;
		ROUGHNESS = rough;
		SPECULAR = spec;
		CLEARCOAT = clearcoat;
		CLEARCOAT_ROUGHNESS = 0.15;
	} else if (style == 7) {
		// Kuukengän jalkaosa: toppanylon vaakatikein, nyöritys jatkuu jalan päällä.
		vec3 c = main_col;
		c *= 1.0 - 0.2 * band(fract(h * 22.0), 0.0, 0.06, 0.02);
		float lace = (1.0 - smoothstep(0.1, 0.13, abs(s))) * band(t, 0.5, 0.74, 0.01) * step(0.045, h);
		c = mix(c, cord_col, lace * (1.0 - smoothstep(0.1, 0.25, abs(fract(t * 22.0) - 0.5))));
		c *= 0.82 + 0.18 * smoothstep(0.0, 0.1, h);
		ALBEDO = c;
		ROUGHNESS = rough;
		SPECULAR = spec;
	} else if (style == 6) {
		// Sandaalin hihnat: kiiltävä nahka, reunoissa tummempi kantti.
		ALBEDO = main_col;
		ROUGHNESS = rough;
		SPECULAR = spec;
		CLEARCOAT = clearcoat;
		CLEARCOAT_ROUGHNESS = 0.25;
	} else if (style == 5) {
		// Nahkasaappaan jalkaosa: sileä nahka, kärjen ja kannan saumat, tumma alareuna.
		vec3 c = main_col;
		c = mix(c, c * 0.62, band(t, 0.795, 0.805, 0.002) * (1.0 - smoothstep(0.045, 0.05, h)));  // kärkisauma
		c = mix(c, c * 0.62, band(t, 0.2, 0.208, 0.002) * (1.0 - smoothstep(0.06, 0.065, h)));  // kantakappaleen sauma
		c *= 0.78 + 0.22 * smoothstep(0.0, 0.1, h);
		ALBEDO = c;
		ROUGHNESS = rough;
		SPECULAR = spec;
		CLEARCOAT = clearcoat;
		CLEARCOAT_ROUGHNESS = 0.35;
	} else if (style == 4) {
		// Kumisaapas: sileä kiiltävä kumi, vaalea kaulusraita yläreunassa (ohut tumma ura alla), kannassa tummempi
		// vahvikeraita poikittaisin urin ja kärjessä vahvistettu kärkikumi.
		vec3 c = main_col;
		vec3 collar_col = sole_col * vec3(0.84, 0.82, 0.78);  // kermanvaalea, ei valkoinen
		float collar = smoothstep(shaft_h - 0.0185, shaft_h - 0.0175, h);
		float heel = (1.0 - smoothstep(0.19, 0.21, t)) * (1.0 - smoothstep(0.045, 0.055, h));
		c = mix(c, c * 0.72, heel);
		c = mix(c, c * 0.75, heel * band(fract(h * 110.0), 0.0, 0.25, 0.04) * smoothstep(0.008, 0.012, h));
		c = mix(c, c * 0.6, band(h, 0.05, 0.053, 0.001) * (1.0 - smoothstep(0.19, 0.21, t)));  // vahvikkeen reuna
		float toe = smoothstep(0.86, 0.88, t) * (1.0 - smoothstep(0.03, 0.035, h));
		c = mix(c, c * 0.8, toe);
		c *= 0.78 + 0.22 * smoothstep(0.0, 0.12, h);  // tumma alareuna, vaalea yläosa
		c = mix(c, c * 0.45, band(h, shaft_h - 0.0215, shaft_h - 0.0185, 0.0006));  // ura kauluksen alla
		c = mix(c, collar_col * (0.9 + 0.1 * smoothstep(shaft_h - 0.018, shaft_h, h)), collar);
		ALBEDO = c;
		ROUGHNESS = rough;
		SPECULAR = spec;
		CLEARCOAT = clearcoat;
		CLEARCOAT_ROUGHNESS = 0.2;
	} else if (style == 3) {
		// Työkenkä: tumma kumitettu turvakärki, nauhoitus jalan päällä (varressa jatkuu), sivulla saumat ja tikit.
		vec3 c = main_col;
		float cap_ = smoothstep(0.785, 0.8, t);
		c = mix(c, vec3(0.11, 0.095, 0.085), cap_ * 0.92);
		c = mix(c, vec3(0.85, 0.7, 0.4), band(t, 0.773, 0.778, 0.001) * step(0.5, fract(s * 14.0)) * 0.7);
		float lace_zone = band(t, 0.46, 0.7, 0.006) * smoothstep(0.04, 0.05, h);
		float tongue = lace_zone * (1.0 - smoothstep(0.2, 0.24, abs(s)));
		c = mix(c, c * 0.62, tongue);
		float zig = 0.17 * abs(fract((t - 0.46) * 16.0) * 2.0 - 1.0);
		float lace = tongue * (1.0 - smoothstep(0.03, 0.06, abs(abs(s) - zig)));
		c = mix(c, vec3(0.16, 0.1, 0.06), lace);
		float eyelet = lace_zone * (1.0 - smoothstep(0.035, 0.05, length(vec2((abs(s) - 0.29) * 0.4, (fract((t - 0.46) * 16.0) - 0.5) * 0.4))));
		c = mix(c, vec3(0.62, 0.6, 0.56), eyelet);
		// Sivusauma kärkiosan ja varren välillä.
		c = mix(c, c * 0.7, band(t, 0.4, 0.41, 0.003) * smoothstep(0.02, 0.03, h));
		c = mix(c, vec3(0.85, 0.7, 0.4), band(t, 0.418, 0.422, 0.001) * step(0.5, fract(h * 220.0)) * smoothstep(0.02, 0.03, h) * 0.7);
		c *= 0.78 + 0.22 * smoothstep(0.0, 0.06, h);
		ALBEDO = c;
		ROUGHNESS = mix(rough, 0.45, cap_);
		SPECULAR = spec;
	} else if (style == 2) {
		// Kävelykenkä: himmeä nahka tai mokka, U-sauma jalan päällä (mokkasiinimainen kärkiosa), ei kieltä.
		vec3 c = main_col;
		float u = length(vec2((t - 0.7) / 0.2, s / 0.55));
		float useam = band(u, 0.96, 1.0, 0.02) * smoothstep(0.02, 0.03, h) * step(t, 0.92);
		c = mix(c, c * 0.55, useam);
		float stitch = band(u, 1.04, 1.07, 0.01) * step(0.5, fract(atan(s / 0.55, (t - 0.7) / 0.2) * 14.0)) * smoothstep(0.02, 0.03, h) * step(t, 0.9);
		c = mix(c, c * 1.25, stitch);
		// Sivulla kaksi nauhanreikää ja leveä nauha suun edessä.
		float lace = band(t, 0.5, 0.53, 0.004) * smoothstep(0.045, 0.05, h) * (1.0 - smoothstep(0.3, 0.34, abs(s)));
		c = mix(c, c * 0.5, lace);
		c *= 0.82 + 0.18 * smoothstep(0.0, 0.06, h);
		ALBEDO = c;
		ROUGHNESS = rough;
		SPECULAR = spec;
	} else {
		vec3 c = main_col;
		// Nauhoitusalue jalan päällä: kieli, rei'itetyt reunakappaleet ja poikittaiset nauhat.
		float lace_zone = band(t, 0.36, 0.72, 0.01) * smoothstep(0.035, 0.045, h);
		float tongue = lace_zone * (1.0 - smoothstep(0.26, 0.3, abs(s)));
		c = mix(c, c * 0.88, tongue);
		float lace = tongue * step(0.55, fract(t * 34.0)) * (1.0 - smoothstep(0.2, 0.24, abs(s)));
		c = mix(c, mix(main_col * 1.05, vec3(0.96), 0.5), lace);
		c = mix(c, c * 0.6, tongue * (1.0 - lace) * step(0.55, fract(t * 34.0 + 0.12)) * (1.0 - step(0.24, abs(s))));
		float eyelet = lace_zone * band(abs(s), 0.3, 0.36, 0.008);
		c = mix(c, accent * 0.9 + c * 0.1, eyelet * 0.85);
		// Sivuraita: vino kaari keskiosassa molemmin puolin.
		float side = smoothstep(0.55, 0.7, abs(s));
		float stripe_y = 0.018 + (t - 0.3) * 0.07;
		float stripe = side * band(t, 0.3, 0.72, 0.01) * band(h, stripe_y, stripe_y + 0.012, 0.0015);
		c = mix(c, accent, stripe);
		// Kantalappu ja kärjen suojus.
		float heel = (1.0 - smoothstep(0.1, 0.12, t)) * smoothstep(0.02, 0.025, h);
		c = mix(c, accent, heel);
		float toe = smoothstep(0.88, 0.9, t) * (1.0 - smoothstep(0.02, 0.025, h));
		c = mix(c, c * 0.9, toe);
		// Vaalea yläreuna, tumma alareuna.
		c *= 0.86 + 0.14 * smoothstep(0.0, 0.06, h);
		ALBEDO = c;
		ROUGHNESS = rough;
		SPECULAR = spec;
	}
}
