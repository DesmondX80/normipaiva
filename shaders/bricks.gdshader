shader_type spatial;
// Punatiiliseinä: tiilirivit limitettynä, laastisaumat ja tiilikohtainen sävyvaihtelu.
// Koordinaatit maailmasta seinän suunnan mukaan, joten tiilet eivät veny.

uniform vec3 brick : source_color = vec3(0.6, 0.26, 0.17);
uniform vec3 mortar : source_color = vec3(0.72, 0.7, 0.66);
uniform float brick_w = 0.26;
uniform float brick_h = 0.075;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float u = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
	vec2 p = vec2(u / brick_w, wpos.y / brick_h);
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float joint = clamp(step(f.x, 0.04) + step(f.y, 0.12), 0.0, 1.0);
	float tone = hash(cell) * 0.25 - 0.1;
	// Kaukaa katsottuna saumat ja sävyvaihtelu häivytetään keskiväriin (ei aaltoilevaa moiréa).
	float fw = max(fwidth(p.x), fwidth(p.y));
	float detail = 1.0 - smoothstep(0.25, 0.7, fw);
	vec3 avg = mix(brick, mortar, 0.18);
	vec3 col = mix(brick * (1.0 + tone), mortar, joint);
	ALBEDO = mix(avg, col, detail);
	ROUGHNESS = 0.9;
}
