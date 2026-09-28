shader_type spatial;
// Tiilikuviopeltikatto: tummat pellit, pystyuurat ja porrastetut vaakarivit.

uniform vec3 color : source_color = vec3(0.07, 0.07, 0.08);
uniform float row = 0.35;
uniform float groove = 0.18;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float r = fract(lpos.z / row);
	float g = fract(lpos.x / groove);
	float step_shade = smoothstep(0.0, 0.12, r) * 0.25 + 0.75;
	float groove_shade = 0.85 + 0.15 * sin(g * 6.2831);
	ALBEDO = color * step_shade * groove_shade;
	METALLIC = 0.35;
	ROUGHNESS = 0.45;
}
