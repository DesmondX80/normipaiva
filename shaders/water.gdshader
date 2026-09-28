shader_type spatial;
render_mode cull_disabled;
// Lammet ja oja: liikkuvat aaltonormaalit, Fresnel-sävy, sileä heijastava pinta.

uniform vec3 deep : source_color = vec3(0.06, 0.16, 0.24);
uniform vec3 shallow : source_color = vec3(0.3, 0.46, 0.55);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float waves(vec2 p) {
	return texture(noise_tex, p * 0.06 + vec2(TIME * 0.012, TIME * 0.007)).r
		+ texture(noise_tex, p * 0.11 - vec2(TIME * 0.009, -TIME * 0.013)).r;
}

void fragment() {
	vec2 p = wpos.xz;
	float e = 0.15;
	float a = waves(p);
	float bx = waves(p + vec2(e, 0.0)) - a;
	float bz = waves(p + vec2(0.0, e)) - a;
	vec3 nw = normalize(vec3(-bx * 5.0, 1.0, -bz * 5.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep, shallow, fres);
	ROUGHNESS = 0.04;
	SPECULAR = 0.9;
}
