extends Node3D
## Pakettiauto Toyota HiAce H100 (vehicles.gd hiace / van): matala katto, korotettu katto ja ambulanssi
## (yliannos.gd build_ambulance) rinnakkain edestä, sivulta, takaa ja vinosti ylhäältä sekä keula, perä, ohjaamo
## lasien läpi, peili, liukuovi ja pyöränkaari suurennettuina. Mittaa ulkomitat, akselivälin ja pyörät (blueprint:
## pituus 4,60 m puskureineen, leveys 1,69 m, korkeus 1,93 / 2,20 m, akseliväli 2,56 m).
## Ajo: tools/testit/aja.sh tscn tools/testit/hiace_kuvat.tscn

const Vehicles := preload("res://scripts/vehicles.gd")
const Yliannos := preload("res://scripts/rikos/yliannos.gd")
const B := preload("res://scripts/build.gd")
const KauppaAuto := preload("res://scripts/kauppa_auto.gd")

var out := "user://hiace"
var cam: Camera3D
var matala: Node3D
var korkea: Node3D
var ambu: Node3D
var wheels: Array[Node3D] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.88)
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 150, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(40, 0.1, 40)), Vector3(0, -0.05, 0), Color(0.4, 0.41, 0.43))  # asfaltti
	matala = Node3D.new()
	add_child(matala)
	wheels = Vehicles.hiace(matala, Color(0.92, 0.92, 0.9), "HIA-100")
	korkea = Node3D.new()
	add_child(korkea)
	Vehicles.hiace(korkea, Color(0.12, 0.2, 0.42), "LH-113", true)
	# Kauppa-auton myyntiluukku (kauppa_auto.gd _hatch_pos): kiinni matalan oikeassa kyljessä, auki korkean kyljessä.
	var ka = KauppaAuto.new()
	for k in 2:
		var h := B.mesh(korkea if k == 1 else matala, B.boxm(Vector3(0.03, KauppaAuto.HATCH_H, 1.6)), ka._hatch_pos(k == 1), Color(0.95, 0.6, 0.1))
		h.rotation.z = -PI / 2.6 if k == 1 else KauppaAuto.HATCH_TILT
		h.set_meta("luukku", true)  # ei kuulu korin mittoihin
	ka.free()
	ambu = Node3D.new()
	add_child(ambu)
	Yliannos.build_ambulance(ambu)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_run.call_deferred()


## Rinnakkain (edestä, takaa, ylhäältä) tai peräkkäin (sivukuva: autot eivät peitä toisiaan).
func _lineup(side: bool) -> void:
	matala.position = Vector3(0, 0, -5.5) if side else Vector3(-2.4, 0, 0)
	korkea.position = Vector3.ZERO if side else Vector3(0, 0, 0)
	ambu.position = Vector3(0, 0, 5.5) if side else Vector3(2.4, 0, 0)


func _shot(name: String, from: Vector3, to: Vector3, fov := 40.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, to)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("HIACE_KUVAT kuva " + out + "/" + name + ".png")


## Kori mitataan yhdistetyn verkon pisteistä; leveys peilien alta (y < 1,2: peilit eivät kuulu leveyteen).
func _measure(n: Node3D, nimi: String, korkeus: float) -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var half_w := 0.0
	for c in n.get_children():
		if not (c is MeshInstance3D) or c.has_meta("luukku"):
			continue
		var am: Mesh = (c as MeshInstance3D).mesh
		for s in am.get_surface_count():
			for v: Vector3 in am.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				lo = lo.min(v)
				hi = hi.max(v)
				if v.y < 1.2:
					half_w = maxf(half_w, absf(v.x))
	var size := Vector3(half_w * 2.0, hi.y - minf(lo.y, 0.0), hi.z - lo.z)
	print("HIACE %s mitat L×K×P %.2f × %.2f × %.2f (tavoite 1,69 × %.2f × 4,60 ±5 %%), peileineen %.2f, korin pohja y %.3f" % [
		nimi, size.x, size.y, size.z, korkeus, hi.x - lo.x, lo.y])
	if absf(size.x - 1.69) > 0.085 or absf(size.y - korkeus) > korkeus * 0.05 or absf(size.z - 4.60) > 0.23:
		print("TESTI VIKA Hiacen (%s) mitat yli 5 %% tavoitteesta" % nimi)
	if lo.y < -0.001:
		print("TESTI VIKA kori maan alla")


func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	_lineup(false)
	_measure(matala, "matala", Vehicles.HIACE_KATTO)
	_measure(korkea, "korkea", Vehicles.HIACE_KATTO_KORKEA)
	var zs: Array[float] = []
	var low := INF
	for w in wheels:
		zs.append(w.position.z)
		low = minf(low, w.position.y - 0.31)
	var wb: float = zs.max() - zs.min()
	print("HIACE akseliväli %.3f (2,56), pyörän alin piste %.3f (0 ± 0,01)" % [wb, low])
	if absf(wb - 2.56) > 0.01 or absf(low) > 0.01:
		print("TESTI VIKA pyörät väärin")
	await _shot("edesta", Vector3(0, 1.3, -13.0), Vector3(0, 1.0, 0))
	await _shot("takaa", Vector3(0, 1.3, 13.0), Vector3(0, 1.0, 0))
	await _shot("vino_ylhaalta", Vector3(-8.0, 7.0, -8.0), Vector3(0, 0.8, 0))
	await _shot("kolmeneljannes", Vector3(-7.5, 1.9, -7.5), Vector3(0, 0.9, 0))
	await _shot("kolmeneljannes_takaa", Vector3(7.5, 2.2, 7.5), Vector3(0, 0.9, 0))
	await _shot("pera", Vector3(-3.6, 1.4, 6.0), Vector3(-2.4, 0.9, 2.3), 35.0)  # matala takaa
	_lineup(true)
	await _shot("sivusta_vasen", Vector3(-17.0, 1.1, 0), Vector3(0, 1.0, 0))
	await _shot("sivusta_oikea", Vector3(17.0, 1.1, 0), Vector3(0, 1.0, 0))  # liukuovi +X
	await _shot("sivusta_matala", Vector3(-7.5, 1.0, -5.5), Vector3(0, 1.0, -5.5))
	await _shot("sivusta_matala_oikea", Vector3(7.5, 1.0, -5.5), Vector3(0, 1.0, -5.5))
	await _shot("sivusta_korkea", Vector3(-7.5, 1.1, 0), Vector3(0, 1.1, 0))
	await _shot("ambulanssi_sivu", Vector3(7.5, 1.1, 5.5), Vector3(0, 1.1, 5.5))
	await _shot("ambulanssi_taka", Vector3(3.5, 2.0, 12.0), Vector3(0, 1.2, 5.5))
	# Lähikuvat matalasta (z -5,5): keula, kaari, peili ja ohjaamo lasien läpi, liukuoven saumat.
	await _shot("keula", Vector3(-1.2, 1.2, -10.0), Vector3(0, 0.9, -7.7), 35.0)
	await _shot("keula_lahi", Vector3(-0.5, 0.9, -9.2), Vector3(-0.3, 0.75, -7.7), 30.0)
	await _shot("kaari", Vector3(-2.6, 0.7, -8.0), Vector3(-0.8, 0.45, -6.8), 35.0)
	await _shot("peili", Vector3(-2.2, 1.6, -8.4), Vector3(-0.9, 1.35, -7.15), 28.0)
	await _shot("ohjaamo", Vector3(-2.8, 1.7, -6.6), Vector3(0, 1.3, -6.7), 45.0)
	await _shot("ohjaamo_oikea", Vector3(2.8, 1.7, -6.6), Vector3(0, 1.3, -6.7), 45.0)
	await _shot("liukuovi", Vector3(3.2, 1.3, -4.6), Vector3(0.8, 1.1, -5.4), 35.0)
	await _shot("luukku_kiinni", Vector3(3.2, 1.5, -6.3), Vector3(0.8, 1.5, -4.8), 30.0)
	await _shot("luukku_kiinni_edesta", Vector3(0.9, 1.6, -9.5), Vector3(0.85, 1.5, -5.0), 12.0)
	await _shot("luukku_auki", Vector3(4.5, 1.6, -2.2), Vector3(0.9, 1.7, 0.7), 35.0)
	await _shot("luukku_auki_edesta", Vector3(1.1, 1.9, -6.0), Vector3(1.1, 1.85, 0.7), 18.0)
	await _shot("katto_ylhaalta", Vector3(0, 6.0, -5.0), Vector3(0, 1.9, -5.5), 45.0)
	await _shot("katto_korkea", Vector3(-3.0, 3.0, -3.0), Vector3(0, 2.0, -0.8), 35.0)
	get_tree().quit()
