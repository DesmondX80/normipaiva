// Hahmojen anatomia (scripts/anatomia.gd): yhteinen sisällytys character.gdshaderiin. Neljä osakohtaista tiedostoa
// (omistaja: A kädet, B jalat, C pää, D vartalo); kukin määrittelee omat uniformit ja funktiot, tämä tiedosto kokoaa ne.
// Maski tulee pisteestä CUSTOM1.a (tavu = alue * 16 + voimakkuus): alue (flat, ei interpoloidu rajalla) ja voimakkuus 0..1.
// Alueet: 1 kädet, 2 jalat, 3 pää, 4 vartalo.
varying flat float anat_area;
varying float anat_amt;

// Varyingia ei saa asettaa aputoiminnossa, joten purku on makro (kutsutaan vertex()-funktiosta: ANAT_UNPACK(CUSTOM1.a)).
#define ANAT_UNPACK(a) { float anat_b = floor((a) * 255.0 + 0.5); anat_area = floor(anat_b / 16.0); anat_amt = (anat_b - anat_area * 16.0) / 15.0; }

#include "res://shaders/anat_kadet.gdshaderinc"
#include "res://shaders/anat_jalat.gdshaderinc"
#include "res://shaders/anat_paa.gdshaderinc"
#include "res://shaders/anat_vartalo.gdshaderinc"

// Luokka (0 iho, 1 paita, 2 housut, 3 jalkaterä) fragmentissa: osat korjaavat sahalaitaiset rajat lepoasennon
// koordinaateista (rest, metrit) verteksivärin interpolaation sijaan.
float anat_class(float c, vec2 r) {
	c = anat_class_jalat(c, r);
	return c;
}

// Ihon pienet yksityiskohdat (nivelpoimut, huulet, huokoset): osat muokkaavat albedoa, roughnessia ja normaalikarttaa.
void anat_skin(inout vec3 albedo, inout float rough, inout vec3 nrm, vec2 r, vec3 rzn, float lum) {
	if (anat_area < 0.5 || anat_amt <= 0.0) {
		return;
	}
}
