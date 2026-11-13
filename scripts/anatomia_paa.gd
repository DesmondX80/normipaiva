extends RefCounted
## Anatomia, moduuli "paa" (rekisteri: anatomia.gd). Osa 0: tyhjät pohjat, koukut ovat paikallaan mutta eivät muuta mitään.
## deform(ctx): pisteiden siirto lepoasennossa + maski ctx.mask (alue * 16 + voimakkuus). attach(ctx): lisäverkot
## (lista {"arrays": ...}). pose(ch): luiden pose-painot animaation jälkeen.


static func deform(_ctx: Dictionary) -> void:
	pass


static func attach(_ctx: Dictionary) -> Array:
	return []


static func pose(_ch: Node3D) -> void:
	pass
