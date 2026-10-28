shader_type canvas_item;
// Vaalan paperikartan maanpeite Saloisten kartan tyyliin (paper_map.gd): litteät värit ilman rinnevarjostusta, pellolle
// ruskea ääriviiva, vedelle sininen ääriviiva ja suolle sinisiä vinoviivoja. TEXTURE = maankäyttökoodit (R8, yksi pikseli
// per maastoruutu: 0 metsä, 1 pelto, 2 suo, 3 vesi, 4-7 piha, piennar, tie ja rata); rajat tasoitetaan koodien bilineaarisilla
// painoilla, joten reunat ovat pehmeitä viivoja eivätkä ruutuporrastusta.

uniform vec2 grid_size;       // maastoruudukon koko (ruutuja)
uniform float px_per_cell;    // ruudun koko kuvapisteinä (cell x zoom)
uniform vec4 forest_col : source_color = vec4(0.66, 0.76, 0.52, 0.9);
uniform vec4 clearing_col : source_color = vec4(0.9, 0.88, 0.74, 0.9);
uniform vec4 field_col : source_color = vec4(0.93, 0.82, 0.5, 1.0);
uniform vec4 field_edge : source_color = vec4(0.7, 0.55, 0.25, 1.0);
uniform vec4 bog_col : source_color = vec4(0.78, 0.84, 0.82, 1.0);
uniform vec4 bog_line : source_color = vec4(0.3, 0.5, 0.7, 0.8);
uniform vec4 water_col : source_color = vec4(0.55, 0.72, 0.86, 1.0);
uniform vec4 water_edge : source_color = vec4(0.2, 0.4, 0.65, 1.0);


vec4 group_color(int g) {
	if (g == 0) return forest_col;
	if (g == 1) return field_col;
	if (g == 2) return bog_col;
	if (g == 3) return water_col;
	return clearing_col;
}


void fragment() {
	vec2 gf = UV * grid_size - 0.5;
	ivec2 i0 = ivec2(floor(gf));
	vec2 f = fract(gf);
	float w[5] = float[5](0.0, 0.0, 0.0, 0.0, 0.0);
	for (int dy = 0; dy < 2; dy++) {
		for (int dx = 0; dx < 2; dx++) {
			ivec2 ij = clamp(i0 + ivec2(dx, dy), ivec2(0), ivec2(grid_size) - ivec2(1));
			int k = int(texelFetch(TEXTURE, ij, 0).r * 255.0 + 0.5);
			int g = k >= 4 ? 4 : k;
			float wt = (dx == 0 ? 1.0 - f.x : f.x) * (dy == 0 ? 1.0 - f.y : f.y);
			w[g] += wt;
		}
	}
	int best = 0;
	for (int g = 1; g < 5; g++) {
		if (w[g] > w[best]) best = g;
	}
	int second = best == 0 ? 1 : 0;
	for (int g = 0; g < 5; g++) {
		if (g != best && w[g] > w[second]) second = g;
	}
	float margin = w[best] - w[second];
	float d = margin / max(fwidth(margin), 0.0001);  // etäisyys rajaan kuvapisteinä
	vec4 col = group_color(best);
	if (best == 2) {
		// Suon vinoviivat kuten Saloisissa: 6 px rivit, 6 px viivat 14 px välein.
		vec2 p = UV * grid_size * px_per_cell;
		float row = floor(p.y / 6.0);
		float on_line = step(fract(p.y / 6.0), 1.0 / 6.0 + 0.04);
		float dash = step(mod(p.x + mod(row * 42.0, 11.0), 14.0), 6.0);
		col = mix(col, bog_line, on_line * dash * bog_line.a);
	}
	float edge_w = 1.0;
	if ((best == 3 || second == 3) && w[3] > 0.0) {
		col = mix(col, water_edge, 1.0 - smoothstep(0.4, 1.6, d));
		col.a = water_col.a;
	} else if (best == 1 || second == 1) {
		col = mix(col, field_edge, 1.0 - smoothstep(0.3, 1.2, d));
	}
	COLOR = col;
}
