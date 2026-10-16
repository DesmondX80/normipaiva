shader_type spatial;
render_mode cull_disabled;
// Maaliverkko: vinoruutuinen naruverkko alfaleikkauksella (läpi näkyy), ja pallon osuessa aalto leviää
// osumakohdasta (hit_local mallin avaruudessa, hit_age sekunteja osumasta; rankku_game.gd päivittää).

uniform vec2 size = vec2(5.0, 2.0);  // pinnan koko metreinä (silmäkoko pysyy samana)
uniform float cell = 0.12;
uniform float thick = 0.09;  // narun paksuus silmän osuutena
uniform vec3 hit_local = vec3(0.0, 0.0, 0.0);
uniform float hit_age = 100.0;

void vertex() {
	float d = distance(VERTEX, hit_local);
	float a = hit_age;
	if (a < 1.6) {
		float w = sin(d * 11.0 - a * 16.0) * exp(-a * 2.6) * exp(-d * 1.4);
		VERTEX += NORMAL * w * 0.12;
	}
}

void fragment() {
	vec2 p = UV * size / cell;
	vec2 g = vec2(fract(p.x + p.y), fract(p.x - p.y));
	float line = min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y));
	ALBEDO = vec3(0.94, 0.94, 0.92);
	ROUGHNESS = 0.9;
	ALPHA = line < thick ? 1.0 : 0.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
