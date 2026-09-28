shader_type spatial;
// Puiden latvat MultiMeshissä: instanssiväri + kohinavaihtelu, latva huojuu tuulessa.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float sway = 0.07;

varying vec3 wpos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float s = sin(TIME * 1.2 + wp.x * 0.13 + wp.z * 0.09) * sway * max(VERTEX.y + 1.0, 0.0);
	VERTEX.x += s;
	VERTEX.z += s * 0.5;
	wpos = wp;
}

void fragment() {
	float n = texture(noise_tex, wpos.xz * 0.2 + vec2(wpos.y * 0.15)).r;
	ALBEDO = COLOR.rgb * (0.7 + n * 0.6);
	ROUGHNESS = 0.9;
	BACKLIGHT = COLOR.rgb * 0.3;
}
