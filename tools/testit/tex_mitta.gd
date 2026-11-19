extends Node3D
## Pohjatekstuurin keskisävy alueittain (kasvo, kaula, käsivarsi class 0; paita-alueen lum), miehen ja naisen malli.
const Looks := preload("res://scripts/looks.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for n in ["JUNTTI", "SINIKKA"]:
		var c: Node3D = Looks.make(self, Looks.JUNTTI.duplicate() if n == "JUNTTI" else Looks.SINIKKA.duplicate())
		for i in 4:
			await get_tree().process_frame
		var tex: Texture2D = c.body_mat.get_shader_parameter("albedo_tex")
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var arr: Array = c.body_mi.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var r2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var acc := {}
		var sats := {}
		for v in uv.size():
			var k := roundi(cols[v].r * 4.0)
			var y := r2[v].y
			var reg := ""
			if k == 0 and y > 1.56:
				reg = "kasvo(y>1.56)"
			elif k == 0 and y > 1.46:
				reg = "kaula(1.46-1.56)"
			elif k == 0:
				reg = "kasi/kyynarvarsi"
			elif k == 1 and y > 1.1 and absf(r2[v].x) < 0.2:
				reg = "paita-torso"
			else:
				continue
			var p := img.get_pixel(clampi(int(uv[v].x * img.get_width()), 0, img.get_width() - 1), clampi(int(uv[v].y * img.get_height()), 0, img.get_height() - 1))
			if not acc.has(reg):
				acc[reg] = [Color(0, 0, 0), 0, 0.0]
			acc[reg][0] += p
			acc[reg][1] += 1
			acc[reg][2] += p.get_luminance()
			if reg.begins_with("kasvo") or reg.begins_with("kaula"):
				var lin := p.srgb_to_linear()
				var lm := lin.r * 0.299 + lin.g * 0.587 + lin.b * 0.114
				if not sats.has(reg):
					sats[reg] = []
				sats[reg].append([(lin.r - lin.b) / maxf(lm, 0.001), lm])
		for reg in acc:
			var a: Array = acc[reg]
			var m: Color = a[0] / float(a[1])
			print("TEX %s %s n=%d rgb %.3f %.3f %.3f lum %.3f" % [n, reg, a[1], m.r, m.g, m.b, a[2] / a[1]])
		for reg in sats:
			var a: Array = sats[reg]
			a.sort_custom(func(x, y): return x[0] < y[0])
			var q := []
			for f in [0.02, 0.1, 0.25, 0.5, 0.75, 0.9, 0.98]:
				q.append("%.2f" % a[int(f * (a.size() - 1))][0])
			var ls := []
			a.sort_custom(func(x, y): return x[1] < y[1])
			for f in [0.02, 0.1, 0.25, 0.5, 0.75, 0.9, 0.98]:
				ls.append("%.3f" % a[int(f * (a.size() - 1))][1])
			print("SAT %s %s sat %s lum %s" % [n, reg, q, ls])
		c.queue_free()
	get_tree().quit()
