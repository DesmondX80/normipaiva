shader_type spatial;
render_mode cull_disabled;
// Lippiksen kupu: kangas, kuusipaneelin saumat, tuuletusreiät, lipan yläpuolinen tikkaus ja
// etupaneeliin heijastettu merkki (myötäilee kupua). Sisäpuoli tummempi.

uniform vec3 cloth : source_color = vec3(0.05, 0.08, 0.2);
uniform sampler2D logo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 logo_center = vec2(0.0, 0.036);  // lippiksen paikallisissa koordinaateissa (x, y)
uniform float logo_width = 0.098;
uniform float logo_aspect = 0.75;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 col = cloth;
	// Kankaan kude.
	float weave = 0.93 + 0.07 * sin(UV.x * 1400.0) * sin(UV.y * 700.0);
	col *= weave;
	// Paneelisaumat (etupaneeli yhtenäinen) ja tikkausrivit saumojen vieressä.
	float th = UV.x * 6.0 + 0.5;
	float fs = abs(fract(th) - 0.5) * 2.0;  // 1 sauman kohdalla, 0 paneelin keskellä
	float dist_seam = (1.0 - fs) * 0.52 * cos(UV.y * 1.5708);  // likimain metreinä
	col *= mix(0.55, 1.0, smoothstep(0.0015, 0.004, dist_seam));
	float stitch = step(0.5, fract(UV.y * 90.0)) * (1.0 - smoothstep(0.0, 0.0012, abs(dist_seam - 0.007)));
	col = mix(col, vec3(0.1), stitch * 0.7);
	// Tuuletusreiät paneelien keskellä.
	float pc = fract(th + 0.5);
	vec2 ey = vec2((pc - 0.5) * 0.52 * cos(UV.y * 1.5708), (UV.y - 0.66) * 0.2);
	float eyelet = 1.0 - smoothstep(0.0028, 0.0038, length(ey));
	col = mix(col, vec3(0.02), eyelet * step(0.25, abs(UV.x - 0.5) * 2.0 + 0.0));
	// Tikkausrivi reunassa.
	float edge = step(0.5, fract(UV.x * 260.0)) * (1.0 - smoothstep(0.0, 0.012, abs(UV.y - 0.05)));
	col = mix(col, vec3(0.1), edge * 0.6);
	// Merkki etupaneeliin: tasoprojektio edestä (-Z), vain etupuolelle.
	vec2 luv = vec2(0.5 - (lp.x - logo_center.x) / logo_width,
		0.5 - (lp.y - logo_center.y) / (logo_width * logo_aspect));
	if (lp.z < 0.0 && ln.z < -0.2 && luv.x > 0.0 && luv.x < 1.0 && luv.y > 0.0 && luv.y < 1.0) {
		vec4 lg = texture(logo, luv);
		col = mix(col, lg.rgb, lg.a);
	}
	if (!FRONT_FACING) {
		col = cloth * 0.35;
	}
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
}
