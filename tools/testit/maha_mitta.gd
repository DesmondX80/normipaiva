extends Node3D
## Miesten mahan mittaus (06-maha-suunnitelma.md): jokaiselle miehelle, jolla belly > 0, MAHA-rivi lepoasennon (H 1,80) luvuista:
## napa_y (muotoiltu y lepo-y 1,085:n kohdalla, x = 0), huippu_y/z (etummainen piste, |x| < 3 cm, y 0,85..1,25), taite_y (alin lepo-y,
## jossa mahan siirtymä >= 5 mm, x = 0), ala09 (suurin mahan siirtymä lepo-y < 0,90) ja etuhelma (luokkaraja vs varjostimen käyrä).
## KULMA-rivi: verkon sivusiluetin kuperat kulmat mahan alueella (raja 30°, K9: monitahoinen siluetti; HEAD e644674 pelaaja 49°).
## Kuvat neljästä päämiehestä Idle-asennossa: edestä, sivulta (vaakaviivat napa punainen, vyö keltainen, haara sininen) ja vinosti.
## aja.sh tscn tools/testit/maha_mitta.tscn [--ennen]  (--ennen = mittaus ennen muutosta: vain luvut ja kuvat ennen_*, ei rajoja)
const Kuva := preload("res://tools/testit/kuva.gd")
const Looks := preload("res://scripts/looks.gd")
const Character := preload("res://scripts/character.gd")
const B := preload("res://scripts/build.gd")

const NAPA := 1.085
const VYO := 0.99
const HAARA := 0.9
## Etummaisen kohdan z ennen muutosta (lepo, H 1,80; --ennen-ajo 20.11.): syvyys pysyy +-10 mm (parikontaktit).
const Z_ENNEN := {"SIVIKKI_TIMO": 0.145, "HEVARI_TERO": 0.186, "ESA": 0.142, "JONI": 0.155, "PENTTI": 0.213, "SULO": 0.165,
	"REIJO": 0.175, "SEPPO": 0.230, "PEKKA": 0.198, "TERO": 0.200, "TAXI_DRIVER": 0.175, "JEMMARI": 0.223, "GRANDPAS[0]": 0.146,
	"GRANDPAS[1]": 0.117, "GRANDPAS[2]": 0.174, "KAUPPIAS": 0.149, "JUNTTI": 0.251, "HEDELMA_PELAAJAT[1]": 0.175,
	"RAAHEN_JATKAT[0]": 0.179, "RAAHEN_JATKAT[1]": 0.209, "PLAYER": 0.253}
const KUVAT := ["PLAYER", "JUNTTI", "JUNTTI_ORANSSI", "PENTTI", "SEPPO"]

var out := "user://maha_mitta"
var cam: Camera3D
var ennen := false
var viat := 0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and not a[0].begins_with("--"):
		out = a[0]
	ennen = "--ennen" in a
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -35, 0)
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(40, 0.1, 40)), Vector3(0, -0.05, 0), Color(0.6, 0.6, 0.6))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_run.call_deferred()


## Kaikki miesten looks.gd-vakiot (myös listojen sisällä), joilla belly > 0.
func _men() -> Array:
	var res := []
	var m: Dictionary = (Looks as Script).get_script_constant_map()
	var names := m.keys()
	names.sort()
	for n in names:
		var v = m[n]
		var lst: Array = v if v is Array else [v]
		for i in lst.size():
			var l = lst[i]
			if not (l is Dictionary) or not (l as Dictionary).has("belly") or str(l.get("model", "male")) == "female":
				continue
			if float(l.belly) <= 0.0:
				continue
			res.append([n if lst.size() == 1 and not (v is Array) else "%s[%d]" % [n, i], l])
	# Juntti vaalealla paidalla: mustasta ei näe etuhelmaa (sekstaaja K10).
	var jo: Dictionary = (Looks.JUNTTI as Dictionary).duplicate(true)
	jo["shirt"] = Color(0.95, 0.45, 0.08)
	jo.erase("stripes")
	res.append(["JUNTTI_ORANSSI", jo])
	return res


func _run() -> void:
	for e in _men():
		await _measure(e[0], e[1])
	print("TULOS maha_mitta: %d vikaa" % viat if viat > 0 else "TULOS maha_mitta: OK")
	get_tree().quit()


func _measure(name: String, look: Dictionary) -> void:
	var l: Dictionary = look.duplicate(true)
	var c: Node3D = Looks.make(self, l)
	var shape := {"belly": float(l.belly), "sag": float(l.get("sag", 0.0))}
	for i in 8:
		await get_tree().process_frame  # varusteiden viivästetyt sovitukset (rinkka) ennen vapautusta
	var mesh: ArrayMesh = c.body_mi.mesh
	var col := []  # etukeskilinjan lepopisteet [y, z] (|x| < 1,5 cm)
	var top := Vector3(0, 0, -INF)  # verkon etummainen piste (sisältää bulkin ja anatomian)
	var low := 0.0
	var low_at := Vector3.ZERO
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
		var c0: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
		if uv2.is_empty() or c0.is_empty():
			continue
		for v in vs.size():
			var rp := Vector3(uv2[v].x, uv2[v].y, c0[v * 4])
			if rp.z <= 0.0:
				continue  # vain etupuoli
			var off: Vector3 = Character._shape_offset(rp, shape)
			if rp.y < HAARA and off.length() > low:
				low = off.length()
				low_at = rp
			if absf(rp.x) < 0.015 and rp.y > 0.75 and rp.y < 1.35:
				col.append([rp.y, rp.z])
			if absf(vs[v].x) < 0.03 and vs[v].y > 0.85 and vs[v].y < 1.25 and vs[v].z > top.z:
				top = vs[v]
	col.sort_custom(func(p, q): return p[0] < q[0])
	# Profiili 1 mm:n välein: lepopinnan z etukeskilinjalla (lineaarinen väli) + mahan siirtymä (vain belly/sag).
	var nav := 0.0
	var peak := Vector2(0, -INF)  # (y, z) muotoiltuna
	var prof := PackedVector2Array()  # analyyttinen profiili (muotoiltu y, z) 1 mm:n lepo-välein
	var fold := INF
	var fold_s := INF  # sama muotoiltuna (näkyvä alareuna)
	var j := 0
	for i in range(800, 1300):
		var y := i / 1000.0
		while j < col.size() - 2 and float(col[j + 1][0]) < y:
			j += 1
		var y0: float = col[j][0]
		var y1: float = col[j + 1][0]
		var z0 := lerpf(float(col[j][1]), float(col[j + 1][1]), clampf((y - y0) / maxf(y1 - y0, 0.0001), 0.0, 1.0))
		var off: Vector3 = Character._shape_offset(Vector3(0, y, z0), shape)
		if off.length() > 0.002:
			prof.append(Vector2(y + off.y, z0 + off.z))
		if i == roundi(NAPA * 1000.0):
			nav = y + off.y
		if y < 1.25 and z0 + off.z > peak.y:
			peak = Vector2(y + off.y, z0 + off.z)
		if y < 1.25 and off.length() >= 0.005:
			fold = minf(fold, y)
			fold_s = minf(fold_s, y + off.y)
	var hem := _hem_check(c, mesh)
	var kulma := _silhouette(mesh, fold_s - 0.01)
	# Muodon oma kaarevuus (ilman verkkoa): suunnan muutos 6 mm:n kaarenpituudella (sileä R 5 cm: 7°).
	var fbest := 0.0
	var fat := 0.0
	var acc := 0.0
	var last := Vector2.ZERO
	var j0 := 0
	var dirs := []  # [y, suunta]
	for i in range(1, prof.size()):
		acc += prof[i].distance_to(prof[j0])
		if acc >= 0.006:
			dirs.append([prof[i].x, (prof[i] - prof[j0]).angle()])
			j0 = i
			acc = 0.0
	for i in range(1, dirs.size()):
		var da := rad_to_deg(angle_difference(float(dirs[i - 1][1]), float(dirs[i][1])))
		if absf(da) > absf(fbest):
			fbest = da
			fat = dirs[i][0]
	print("MAHA %s belly %.2f sag %.1f: napa_y %.3f huippu_y %.3f huippu_z %.3f taite_y %.3f (muot %.3f) ala09 %.1f mm (y %.3f x %.3f) verkko_z %.3f (y %.3f) %s" % [
		name, shape.belly, shape.sag, nav, peak.x, peak.y, fold, fold_s, low * 1000.0, low_at.y, low_at.x, top.z, top.y, hem])
	print("KULMA %s: muoto max %.0f° (y %.3f); %s" % [name, fbest, fat, kulma[2]])
	if not ennen:
		var sag: bool = shape.sag > 0.0
		var fails := []
		if absf(nav - NAPA) > 0.01:
			fails.append("napa %.3f" % nav)
		if sag and (peak.x < 1.045 or peak.x > 1.075) or not sag and (peak.x < 1.065 or peak.x > 1.105):
			fails.append("huippu_y %.3f" % peak.x)
		if sag and (fold < 0.93 or fold > 0.95) or not sag and fold < 0.97:
			fails.append("taite_y %.3f" % fold)
		if low > 0.003:
			fails.append("ala09 %.1f mm" % (low * 1000.0))
		if float(kulma[0]) > 30.0:
			fails.append("siluetin kupera kulma %.0f° (y %.3f), raja 30°" % [kulma[0], kulma[1]])
		if Z_ENNEN.has(name) and absf(top.z - float(Z_ENNEN[name])) > 0.01:
			fails.append("verkko_z %.3f (ennen %.3f)" % [top.z, Z_ENNEN[name]])
		for f in fails:
			viat += 1
			print("TESTI VIKA maha %s: %s" % [name, f])
	if name in KUVAT:
		await _shots(c, name)
	c.queue_free()
	await get_tree().process_frame


## Sivusiluetti (K9: monitahoinen maha): etupuolen (lepo-z > 0, |x| < 0,2) kolmioiden särmien leikkaus vaakatasoilla
## 2 mm:n välein, suurin muotoiltu z = siluetti sivulta katsottuna. Kulma = siluetin suunnan muutos 6 mm:n askelilla
## (sileä kaari R 5 cm: noin 7°; verkon kulma näkyy yksittäisenä hyppynä). Palauttaa [suurin kulma, y, kuvaus].
func _silhouette(mesh: ArrayMesh, y_from: float) -> Array:
	const Y0 := 0.85
	const N := 250  # 2 mm:n tasot 0,85..1,35
	var zmax := PackedFloat32Array()
	zmax.resize(N)
	zmax.fill(-INF)
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
		var c0: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if uv2.is_empty() or c0.is_empty() or idx.is_empty():
			continue
		for t in range(0, idx.size(), 3):
			var ok := true
			for k in 3:
				var v := idx[t + k]
				if c0[v * 4] <= 0.0 or absf(uv2[v].x) > 0.2:
					ok = false
			if not ok:
				continue
			for k in 3:
				var p: Vector3 = vs[idx[t + k]]
				var q: Vector3 = vs[idx[t + (k + 1) % 3]]
				if p.y > q.y:
					var tmp := p
					p = q
					q = tmp
				var i0 := maxi(ceili((p.y - Y0) / 0.002), 0)
				var i1 := mini(floori((q.y - Y0) / 0.002), N - 1)
				for i in range(i0, i1 + 1):
					var y := Y0 + i * 0.002
					var z := lerpf(p.z, q.z, (y - p.y) / maxf(q.y - p.y, 1e-6))
					zmax[i] = maxf(zmax[i], z)
	var best := 0.0
	var at := 0.0
	var big := []
	for i in range(3, N - 3, 3):
		if zmax[i - 3] == -INF or zmax[i + 3] == -INF or Y0 + i * 0.002 < y_from:
			continue  # vain mahan alue (muotoillun taitteen yläpuolella; alempana vartalon oma haara)
		var a := Vector2(0.006, zmax[i] - zmax[i - 3])
		var b := Vector2(0.006, zmax[i + 3] - zmax[i])
		var ang := -rad_to_deg(a.angle_to(b))  # > 0 kupera (mahan pinta), < 0 kovera (mahan ja vartalon välinen poimu)
		if absf(ang) > 15.0:
			big.append("%.3f:%.0f" % [Y0 + i * 0.002, ang])
		if ang > best:
			best = ang
			at = Y0 + i * 0.002
	return [best, at, "siluetti kupera max %.0f° (y %.3f), |kulma| > 15°: [%s]" % [best, at, " ".join(big)]]


## Etuhelma: verteksiluokan (paita 1 / housut 2) ja varjostimen käyrän (hem_front + hem_front_k x^2) erimielisyys etupuolella.
func _hem_check(c: Node3D, mesh: ArrayMesh) -> String:
	var mat: ShaderMaterial = c.body_mat
	if mat == null or mat.get_shader_parameter("hem_front") == null or float(mat.get_shader_parameter("hem_front")) <= 0.0:
		return "etuhelma -"
	var a := float(mat.get_shader_parameter("hem_front"))
	var k := float(mat.get_shader_parameter("hem_front_k"))
	var bad := 0
	var worst := 0.0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
		var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var c0: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
		for v in uv2.size():
			var cat := roundi(col[v].r * 4.0)
			if c0[v * 4] < 0.02 or absf(uv2[v].x) > 0.24 or uv2[v].y < 0.85 or uv2[v].y > 1.2 or (cat != 1 and cat != 2):
				continue
			var hy := a + k * uv2[v].x * uv2[v].x
			if (uv2[v].y > hy) != (cat == 1):
				bad += 1
				worst = maxf(worst, absf(uv2[v].y - hy))
	return "etuhelma %.3f k %.2f eri %d (max %.1f mm)" % [a, k, bad, worst * 1000.0]


func _line(y: float, col: Color, x: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.003, 0.003, 0.9)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.no_depth_test = true  # näkyy vartalon päällä (viiva keskitasossa x = 0, ei perspektiivivirhettä)
	mi.material_override = m
	add_child(mi)
	mi.global_position = Vector3(x, y, 0.0)
	return mi


func _shots(c: Node3D, name: String) -> void:
	var hs: float = c.model.scale.y
	var tag := "ennen" if ennen else "jalkeen"
	# Idle (pelin asento) edestä, sivulta ja vinosti; lepo (T-asento, sama kuin mittaus) sivulta viivoineen.
	for v in [["etu", 0.0, 0.0, 2.8], ["sivu", 90.0, 0.0, 2.8], ["vino", 40.0, 10.0, 2.8], ["lepo_sivu", 90.0, 0.0, 2.8]]:
		if v[0] == "lepo_sivu":
			c.anim.stop()
			c.skeleton.reset_bone_poses()
		else:
			c.restart("Idle", 0.0, 0.0)
			c.anim.seek(0.25, true)
		for i in 6:
			await get_tree().process_frame
		var lines := []
		if v[0].ends_with("sivu"):
			for ln in [[NAPA, Color(1, 0, 0)], [VYO, Color(1, 0.9, 0)], [HAARA, Color(0, 0.3, 1)]]:
				lines.append(_line(c.model.global_position.y + ln[0] * hs, ln[1], 0.0))  # malli on kengänpohjan verran koholla
		cam.fov = 22
		var d := Vector3(0, 0, -1)  # hahmo katsoo -Z:aan (model.rotation.y = PI)
		d = d.rotated(Vector3.UP, deg_to_rad(v[1]))
		d = d.rotated(d.cross(Vector3.UP).normalized(), deg_to_rad(v[2])) if v[2] != 0.0 else d
		var aim := Vector3(0, c.model.global_position.y + 1.06 * hs, 0)
		cam.global_position = aim + d * v[3]
		cam.look_at(aim, Vector3.UP)
		await Kuva.piirto()
		Kuva.ruutu(get_viewport()).save_png("%s/%s_%s_%s.png" % [out, tag, name, v[0]])
		for ln in lines:
			ln.queue_free()
