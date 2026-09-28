shader_type sky;
// Taivas: liukuväri, aurinko ja staattiset kumpupilvet (fbm-kohina).

uniform vec3 top_color : source_color = vec3(0.22, 0.42, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.8, 0.85, 0.9);
uniform vec3 ground_color : source_color = vec3(0.42, 0.48, 0.42);
uniform float cloud_coverage = 0.5;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 4.0, 0.0, 1.0));
	}
	float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += LIGHT0_COLOR * (pow(sd, 900.0) * 10.0 + pow(sd, 10.0) * 0.18);
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 1.3;
		float c = fbm(uv * 1.4);
		c = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.22, c);
		float shade = fbm(uv * 1.4 + vec2(0.35, 0.2));
		vec3 ccol = mix(vec3(1.0, 0.98, 0.95), vec3(0.66, 0.7, 0.78), shade * 0.7);
		ccol += LIGHT0_COLOR * pow(sd, 6.0) * 0.3;
		col = mix(col, ccol, c * smoothstep(0.0, 0.18, h));
	}
	COLOR = col;
}
