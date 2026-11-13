extends RefCounted
## Hahmojen anatomia (.claude/tyo/hahmot-anatomia): tarkennukset samaan Quaternius-luurankoon ja pohjamalliin, joten
## asennot, animaatiot ja kontaktit säilyvät. Rekisteri kutsuu moduuleja (anatomia_kadet|jalat|paa|vartalo.gd) kolmesta
## koukusta, jotka Character kutsuu:
##   deform(ctx)  pisteiden siirto lepoasennossa ennen Character._reshapea (laskenta kerran, tulos levyvälimuistiin).
##                ctx: kind, arr (pinnan taulukot, VERTEX/NORMAL muokattavissa), vbone, joints, shape, mask.
##                mask[v] = CUSTOM1.a: alue * 16 + voimakkuus (0..15), alue ALUE_*; varjostin lukee anat_m-varyingin.
##   build(ctx)   lisäverkko (kynnet ym.): ArrayMesh tai null. ctx: kind, shape, look, shoe_type, body (arrays), skin, skeleton.
##                Character luo yhden skinnatun "Anatomia"-solmun ja välimuistittaa verkon.
##   pose(ch)     luiden pose-painojen rentous animaation jälkeen (vain osa A: sormet), ennen ohituksia ja IK:ta.
## Moduulit ovat pelkkiä staattisia funktioita; osa 0 toimittaa tyhjät pohjat, osat A-D täyttävät ne.
## Käytössä oletuksena aikuisilla (pituus >= 1,5 m, kuten nännit); look.anat = false vain ennen/jälkeen-vertailuun.

const Kadet := preload("res://scripts/anatomia_kadet.gd")
const Jalat := preload("res://scripts/anatomia_jalat.gd")
const Paa := preload("res://scripts/anatomia_paa.gd")
const Vartalo := preload("res://scripts/anatomia_vartalo.gd")

## Tiedostot, joiden sisältö kuuluu verkkovälimuistin tiivisteeseen (Character._cache_path).
const FILES := ["anatomia.gd", "anatomia_kadet.gd", "anatomia_jalat.gd", "anatomia_paa.gd", "anatomia_vartalo.gd"]

## Maskin alueet (omistaja): kädet A, jalat B, pää C, vartalo D.
const ALUE_KADET := 1
const ALUE_JALAT := 2
const ALUE_PAA := 3
const ALUE_VARTALO := 4

## Raja-arvot, joita useampi osa käyttää: nilkan lepo-y (anat_class: luokka 3 jos rest.y < nilkka). Mitattu
## anatomia_kuvat.gd:n ANAT luokka3 -rivistä: jalkaterän (3) ylin ja housujen (2) alin piste menevät päällekkäin
## (mies 0,073..0,104, nainen 0,052..0,091), raja on välin keskikohta.
const CLASS_Y := {"nilkka_male": 0.088, "nilkka_female": 0.072}


static func enabled(look: Dictionary) -> bool:
	return bool(look.get("anat", float(look.get("height", 1.8)) >= 1.5))


## Maski: alue ja voimakkuus (0..1) yhteen tavuun. Suurempi voimakkuus voittaa samassa pisteessä.
static func mask_byte(area: int, strength: float) -> int:
	return area * 16 + clampi(roundi(strength * 15.0), 0, 15)


static func deform(ctx: Dictionary) -> void:
	Kadet.deform(ctx)
	Jalat.deform(ctx)
	Paa.deform(ctx)
	Vartalo.deform(ctx)


## Lisäverkot yhdeksi ArrayMeshiksi (yksi pinta, yksi piirtokutsu). Moduuli palauttaa taulukon-sanakirjoja
## {"arrays": [...pinnan taulukot, skinnattu: ARRAY_BONES/WEIGHTS]} tai tyhjän listan.
static func build(ctx: Dictionary) -> ArrayMesh:
	var parts: Array = []
	parts.append_array(Kadet.attach(ctx))
	parts.append_array(Jalat.attach(ctx))
	parts.append_array(Paa.attach(ctx))
	parts.append_array(Vartalo.attach(ctx))
	if parts.is_empty():
		return null
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uv2 := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedByteArray()
	for p in parts:
		var a: Array = p.arrays
		var base := verts.size()
		verts.append_array(a[Mesh.ARRAY_VERTEX])
		norms.append_array(a[Mesh.ARRAY_NORMAL])
		cols.append_array(a[Mesh.ARRAY_COLOR])
		uv2.append_array(a[Mesh.ARRAY_TEX_UV2])
		bones.append_array(a[Mesh.ARRAY_BONES])
		weights.append_array(a[Mesh.ARRAY_WEIGHTS])
		c0.append_array(a[Mesh.ARRAY_CUSTOM0])
		c1.append_array(a[Mesh.ARRAY_CUSTOM1])
		for i in a[Mesh.ARRAY_INDEX]:
			idx.append(base + i)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = norms
	out[Mesh.ARRAY_COLOR] = cols
	out[Mesh.ARRAY_TEX_UV2] = uv2
	out[Mesh.ARRAY_BONES] = bones
	out[Mesh.ARRAY_WEIGHTS] = weights
	out[Mesh.ARRAY_CUSTOM0] = c0
	out[Mesh.ARRAY_CUSTOM1] = c1
	out[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	# Sama muoto kuin vartaloverkolla (Character._clothed_mesh): CUSTOM0 float RGBA, CUSTOM1 RGBA8; painot 4 per piste.
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {},
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
	return mesh


static func pose(ch: Node3D) -> void:
	Kadet.pose(ch)
	Jalat.pose(ch)
	Paa.pose(ch)
	Vartalo.pose(ch)


## Paljas jalka: eksplisiittinen look.shoe = "paljas" antaa ihonvärin (ei shoes-värin kiertotietä). look.foot_col ohittaa
## (esim. pronssipatsas). Palauttaa värin tai alpha 0, jos jalka noudattaa vanhaa käytöstä (shoes-väri).
static func bare_foot_color(look: Dictionary) -> Color:
	if look.get("shoe", "") != "paljas":
		return Color(0, 0, 0, 0)
	if look.has("foot_col"):
		return look.foot_col
	var skin: Color = look.get("bare_skin", Color(0.93, 0.74, 0.62))
	var tint: Color = look.get("skin", Color(1.0, 0.95, 0.92))
	return Color(skin.r * tint.r, skin.g * tint.g, skin.b * tint.b, 1.0)
