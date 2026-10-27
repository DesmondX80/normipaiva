shader_type spatial;
render_mode cull_disabled;
// Hiukset: sama ulkonäkö kuin gltf:n StandardMaterial3D (tekstuuri x väri x 1,6, roughness, normaalikartta), mutta
// verteksit painuvat kontaktilaatikoita vasten ja heiluvat. Kaikki Hair_*.gltf ovat kaksipuolisia (doubleSided).
// CUSTOM0.x = heilahduspaino, CUSTOM0.w = painumaraja (Character._hair_mesh): 0 = jäykkä (kallo, lippis).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 hair_col : source_color = vec3(1.0);
uniform float hair_rough = 0.7;
uniform vec3 hair_sway = vec3(0.0);  // heilahdussiirto verkon avaruudessa (Character._update_hair_sway)
uniform bool hair_debug = false;  // magenta = painuu (w > 0), syaani = heiluu (x > 0)

#include "res://shaders/press.gdshaderinc"

varying vec2 dbg;

void vertex() {
	dbg = vec2(CUSTOM0.w > 0.0 ? 1.0 : 0.0, CUSTOM0.x > 0.0 ? 1.0 : 0.0);
	VERTEX += hair_sway * CUSTOM0.x;
	if (press_n > 0 && CUSTOM0.w > 0.0) {
		vec3 pn;
		float pd;
		vec3 pv = VERTEX;
		float used = 0.0;  // raja on kaikille laatikoille yhteinen
		for (int i = 0; i < 6; i++) {
			if (i >= press_n) {
				break;
			}
			pv += press_disp(press_xf(i), press_half(i), pv, CUSTOM0.w, used, NORMAL, pn, pd);
			used += pd * CUSTOM0.w;
		}
		VERTEX = pv;
	}
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * hair_col;
	ROUGHNESS = hair_rough;
	METALLIC = 0.0;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	if (hair_debug) {
		ALBEDO = dbg.x > 0.5 ? (dbg.y > 0.5 ? vec3(0.0, 1.0, 1.0) : vec3(1.0, 0.0, 1.0)) : vec3(0.2);
	}
}
