shader_type spatial;
// Pensasaidan runko: lehtitekstuuri kolmitasoprojektiona maailmakoordinaateista, tummat kolot,
// verteksiväri sävyttää lajin (havupensas / lehtipensas).

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float scale = 1.1;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 tri(vec3 p, vec3 n) {
	vec3 w = abs(n);
	w /= (w.x + w.y + w.z);
	return texture(leaf_tex, p.zy * scale) * w.x + texture(leaf_tex, p.xz * scale) * w.y + texture(leaf_tex, p.xy * scale) * w.z;
}

void fragment() {
	vec4 t = tri(wpos, wnrm);
	float n = texture(noise_tex, wpos.xz * 0.3 + vec2(wpos.y * 0.2)).r;
	ALBEDO = t.rgb * COLOR.rgb * 1.35 * (0.8 + n * 0.4);
	ROUGHNESS = 0.9;
	BACKLIGHT = COLOR.rgb * 0.2;
}
