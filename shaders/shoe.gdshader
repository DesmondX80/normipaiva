shader_type spatial;
// Kengät (scripts/shoes.gd): päällinen ja pohja samassa skinnatussa verkossa. Yksityiskohdat piirretään lepoasennon
// koordinaateista: UV = (pituus 0 kanta .. 1 kärki, korkeus kuoren alapinnasta m), UV2 = (sivu -1..1, + = ulkosivu; osa:
// 0 päällinen, 1 pohja). Väri: pisteväri sRGB (vertex_color_is_srgb-vastine), päällinen main_col.

uniform vec3 main_col : source_color = vec3(0.9);
uniform vec3 sole_col : source_color = vec3(0.95, 0.94, 0.9);
uniform float rough = 0.6;
uniform float sole_rough = 0.8;

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
	if (fu2.y > 0.5) {
		// Pohja: välipohja vaalea, ohut tumma raita reunassa, alapinnassa poikittaiset urat (pito).
		vec3 c = sole_col;
		c = mix(c, c * 0.55, band(h, -0.0075, -0.0055, 0.0005));
		float bottom = 1.0 - smoothstep(-0.0175, -0.0165, h);
		c = mix(c, vec3(0.32, 0.3, 0.28), bottom);
		c *= 1.0 - 0.35 * bottom * step(0.5, fract(t * 38.0));
		c *= 0.9 + 0.1 * smoothstep(-0.02, 0.0, h);  // tumma alareuna
		ALBEDO = c;
		ROUGHNESS = sole_rough;
		SPECULAR = 0.3;
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
		SPECULAR = 0.4;
	}
}
