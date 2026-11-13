// Anatomia, osa B (jalat). Paljas jalka (Anatomia.bare_foot_color, Character._attach_shoes): eksplisiittinen
// look.shoe = "paljas" antaa jalkaterälle ihonvärin (mode 1) tai look.foot_col-värin (mode 2), ei shoes-väriä.
// 0 = vanha käytös (luokan 3 väri = shoes). Raja nilkassa lasketaan fragmentissa lepoasennon y:stä (anat_ankle_y).
uniform int bare_foot_mode = 0;
uniform vec3 foot_col : source_color = vec3(0.42, 0.3, 0.16);
uniform float anat_ankle_y = 0.085;

float anat_class_jalat(float c, vec2 r) {
	if (bare_foot_mode > 0 && c > 1.5) {
		return r.y < anat_ankle_y ? 3.0 : 2.0;
	}
	return c;
}
