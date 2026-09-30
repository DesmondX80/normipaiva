shader_type spatial;
render_mode cull_disabled;
// Vaalan talojen katot yhdistettynä meshinä: väri verteksiväristä, tyyppi alfasta.
// 1.0 saumapelti (saumat lappeen suuntaan), 0.5 betonitiili (aaltoilevat rivit), 0.0 huopa tasakatolle.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying flat vec3 wnrm;  // tahkon normaali vakiona: suunta ei saa vaihdella pikseleittäin (isot koordinaatit)

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));  // verteksivärit sRGB:nä
	float kind = COLOR.a;
	vec2 slope = wnrm.xz;
	float sl = length(slope);
	vec2 down = sl > 0.05 ? slope / sl : vec2(1.0, 0.0);
	vec2 across = vec2(-down.y, down.x);
	float u = dot(wpos.xz, across);
	float w = dot(wpos.xz, down) + wpos.y * 0.0;
	float g = texture(noise_tex, wpos.xz * 0.08).r;
	vec3 col = base;
	float metal = 0.0;
	float rough = 0.9;
	if (kind > 0.75) {
		// Saumapelti: 0,5 m välein pystysaumat (korotettu harja kirkkaampi, vieressä varjo).
		float f = fract(u / 0.5);
		float seam = smoothstep(0.0, 0.03, f) * (1.0 - smoothstep(0.03, 0.06, f));
		float shadow = smoothstep(0.06, 0.12, f);
		float detail = 1.0 - smoothstep(0.04, 0.12, fwidth(u / 0.5));
		col = base * mix(0.95, (0.7 + 0.3 * shadow) + seam * 0.45, detail);
		metal = 0.3;
		rough = 0.5;
	} else if (kind > 0.25) {
		// Betonitiili: rivit 0,34 m ja aaltoprofiili 0,3 m.
		float r = fract(w / 0.34);
		float wave = 0.5 + 0.5 * sin(u / 0.3 * 6.2831);
		float detail = 1.0 - smoothstep(0.05, 0.14, max(fwidth(w / 0.34), fwidth(u / 0.3)));
		col = base * mix(0.9, (0.78 + 0.22 * smoothstep(0.0, 0.2, r)) * (0.88 + 0.12 * wave), detail);
		rough = 0.85;
	} else {
		// Huopakatto: tumma ja rakeinen, sauma-alueet 1 m välein.
		float f = fract(u / 1.0);
		col = base * (0.85 + 0.2 * texture(noise_tex, wpos.xz * 1.3).r) * (1.0 - 0.1 * step(f, 0.03));
		rough = 0.95;
	}
	col *= 0.9 + 0.15 * g;
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
}
