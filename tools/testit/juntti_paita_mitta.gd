extends Node3D
## Mittaus: Juntin hihan raita-alueen (G=1, |x| > 0,26) lepo-z ja normaali y.
const Looks := preload("res://scripts/looks.gd")


func _ready() -> void:
	var c: Node3D = Looks.make(self, Looks.JUNTTI.duplicate())
	var arr: Array = c.body_mi.mesh.surface_get_arrays(0)
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var c0: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
	var rows := {}
	for v in uv2.size():
		if col[v].g < 0.5 or absf(uv2[v].x) < 0.26 or uv2[v].x < 0:
			continue
		var xb := snappedf(uv2[v].x, 0.1)
		var r: Array = rows.get(xb, [INF, -INF, INF, -INF, 0])
		r[0] = minf(r[0], c0[v * 4])
		r[1] = maxf(r[1], c0[v * 4])
		r[2] = minf(r[2], c0[v * 4 + 1])
		r[3] = maxf(r[3], c0[v * 4 + 1])
		r[4] += 1
		rows[xb] = r
	var ks := rows.keys()
	ks.sort()
	for k in ks:
		var r: Array = rows[k]
		print("HIHA x %.1f: z %.3f..%.3f  ny %.2f..%.2f  n=%d  yrange" % [k, r[0], r[1], r[2], r[3], r[4]])
	get_tree().quit()
