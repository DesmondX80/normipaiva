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
	VERTEX += NORMAL * puff;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float c = floor(cat + 0.5);
	vec3 n = texture(normal_tex, UV).rgb;
	if (c < 0.5) {
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
		// Kankaan kude: hienot raidat + tekstuurin varjostus säilyy.
		float weave = 0.94 + 0.06 * sin(lpos.y * 900.0) * sin(lpos.x * 700.0 + lpos.z * 700.0);
		ALBEDO = cloth * mix(0.96, 0.72 + 0.5 * lum, muscle_def) * weave;
		ROUGHNESS = c > 2.5 ? 0.45 : mix(0.9, 0.5, fabric_shine);
		SPECULAR = mix(0.25, 0.45, fabric_shine);
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), n, 0.18 * muscle_def);
	}
}
