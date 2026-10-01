// Puun sijoitus datatekstuurista (forest.gd, ONP3): indeksi = lohkon alku (custom data x + y * 2048) + INSTANCE_ID.
// tree_a: x, y, z, pituus (solmun paikallinen kehys); tree_b: latvuksen säde x40, laji, kaksi satunnaislukua.
// Malli on viitepituudelle ref_h ja latvuksen säteelle ref_r. Tarkkuustaso puukohtaisesti: puu piirretään,
// kun sen etäisyys katsojasta (globaali lod_eye maailmassa) on välillä [lod_min, lod_max).

uniform sampler2D tree_a : filter_nearest, repeat_disable;
uniform sampler2D tree_b : filter_nearest, repeat_disable;
uniform float ref_h = 10.0;
uniform float ref_r = 2.0;
global uniform vec3 lod_eye;
uniform float lod_min = 0.0;
uniform float lod_max = 100000.0;
uniform bool trunk = false;

varying vec3 wpos;
varying float tint;

void place_tree(inout vec3 v, inout vec3 n, int iid, vec2 base, mat4 model, out float tn) {
	int w = textureSize(tree_a, 0).x;
	int i = int(base.x + 0.5) + int(base.y + 0.5) * 2048 + iid;
	ivec2 c = ivec2(i % w, i / w);
	vec4 a = texelFetch(tree_a, c, 0);
	vec4 b = texelFetch(tree_b, c, 0);
	float r = b.x * 255.0 / 40.0;
	float sy = a.w / ref_h;
	float sx = trunk ? sy * 0.85 : clamp(r / ref_r, sy * 0.55, sy * 1.6);
	vec3 world = (model * vec4(a.xyz, 1.0)).xyz;
	float d = distance(world.xz, lod_eye.xz);
	if (d < lod_min || d >= lod_max) {
		v = vec3(0.0);
		tn = 0.0;
		return;
	}
	float ang = b.z * 6.2831853;
	float ca = cos(ang);
	float sa = sin(ang);
	vec2 xz = vec2(ca * v.x - sa * v.z, sa * v.x + ca * v.z) * sx;
	v = vec3(xz.x, v.y * sy, xz.y) + a.xyz;
	vec2 nxz = vec2(ca * n.x - sa * n.z, sa * n.x + ca * n.z) / sx;
	n = normalize(vec3(nxz.x, n.y / sy, nxz.y));
	tn = b.w - 0.5;
}

// Kameran edessä (alle 3 m) lehvästö häivytetään rasterilla, ettei se peitä näkymää.
bool camera_fade(vec3 view_pos, vec2 frag) {
	float cam_d = length(view_pos);
	if (cam_d < 3.0) {
		float dither = fract(dot(frag, vec2(0.7548777, 0.5698403)));
		return dither > (cam_d - 0.8) / 2.2;
	}
	return false;
}
