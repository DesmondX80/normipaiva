shader_type spatial;
render_mode cull_disabled;
// Rasvaletti (looks.gd _add_letti): taakse kammattu geelitukka. Kamman urat kulkevat otsalta niskaan (UV.y),
// suortuvat vaihtelevat sävyltään, ja geeli kiiltää.

uniform vec3 hair : source_color = vec3(0.82, 0.66, 0.4);

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5);
}

void fragment() {
	float strand = UV.x * 260.0;
	float groove = 0.75 + 0.25 * abs(sin(strand * 3.14159));
	float tone = 0.85 + 0.3 * hash(floor(strand * 0.25));
	vec3 col = hair * groove * tone;
	// Juuret tummempia, letin kärki vaaleampi.
	col *= mix(0.8, 1.0, smoothstep(0.0, 0.4, UV.y));
	col = mix(col, hair * 1.15, 0.3 * smoothstep(1.4, 2.0, UV.y));
	ALBEDO = col;
	ROUGHNESS = 0.22;
	SPECULAR = 0.7;
}
