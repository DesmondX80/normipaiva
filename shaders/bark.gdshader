shader_type spatial;
// Koivun runko: valkoinen tuohi mustin vaakalaikuin.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 lp;
varying vec3 wpos;

void vertex() {
	lp = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise_tex, vec2(atan(lp.x, lp.z) * 0.08 + wpos.x * 0.05, lp.y * 0.35 + wpos.z * 0.05)).r;
	float mark = smoothstep(0.6, 0.66, n);
	float base = smoothstep(-3.0, -1.5, lp.y);
	vec3 col = mix(vec3(0.93, 0.92, 0.88), vec3(0.08), max(mark, (1.0 - base) * 0.6));
	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = 0.8;
}
