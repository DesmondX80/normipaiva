extends Node3D
## Mercedes-Benz W123 (vehicles.gd mercedes) ja taksi (taxi: kermanvärinen, TAXI-kupu) rinnakkain edestä, sivulta,
## takaa ja vinosti ylhäältä sekä keula, perä ja katon kulmat suurennettuina. Mittaa W123:n ulkomitat, akselivälin ja pyörät.
## Ajo: tools/testit/aja.sh tscn tools/testit/taksi_kuvat.tscn

const Vehicles := preload("res://scripts/vehicles.gd")
const B := preload("res://scripts/build.gd")

var out := "user://taksi"
var cam: Camera3D
var saab: Node3D
var poliisi: Node3D
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
	B.mesh(self, B.boxm(Vector3(30, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.4, 0.41, 0.43))  # asfaltti
	saab = Node3D.new()
	add_child(saab)
	wheels = Vehicles.mercedes(saab, Color(0.15, 0.2, 0.35), "MB-123")
	poliisi = Node3D.new()
	add_child(poliisi)
	Vehicles.taxi(poliisi, "TXI-808")
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40.0
	_run.call_deferred()


## Rinnakkain (edestä, takaa, ylhäältä) tai peräkkäin (sivukuva: taksi ei peitä toista).
func _lineup(side: bool) -> void:
	saab.position = Vector3(0, 0, -2.8) if side else Vector3(-1.2, 0, 0)
	poliisi.position = Vector3(0, 0, 2.8) if side else Vector3(1.4, 0, 0)


func _shot(name: String, from: Vector3, to: Vector3, fov := 40.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, to)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("TAKSI_KUVAT kuva " + out + "/" + name + ".png")


## Kori mitataan yhdistetyn verkon pisteistä; leveys vyötärölinjan alta (peilit eivät kuulu leveyteen, esikuva 1690 mm).
func _measure() -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var half_w := 0.0
	for c in saab.get_children():
		if not (c is MeshInstance3D):
			continue
		var am: Mesh = (c as MeshInstance3D).mesh
		for s in am.get_surface_count():
			for v: Vector3 in am.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				lo = lo.min(v)
				hi = hi.max(v)
				if v.y < 0.95:
					half_w = maxf(half_w, absf(v.x))
	var size := Vector3(half_w * 2.0, hi.y - minf(lo.y, 0.0), hi.z - lo.z)
	print("MERCEDES mitat L×K×P %.2f × %.2f × %.2f (tavoite 1,786 × 1,438 × 4,725 ±5 %%), peileineen %.2f, korin pohja y %.3f" % [size.x, size.y, size.z, hi.x - lo.x, lo.y])
	if absf(size.x - 1.786) > 0.09 or absf(size.y - 1.438) > 0.072 or absf(size.z - 4.725) > 0.236:
		print("TESTI VIKA Mercedeksen mitat yli 5 % tavoitteesta")
	if lo.y < -0.001:
		print("TESTI VIKA kori maan alla")
	var zs: Array[float] = []
	var low := INF
	for w in wheels:
		zs.append(w.position.z)
		low = minf(low, w.position.y - 0.321)
	var wb: float = zs.max() - zs.min()
	print("MERCEDES akseliväli %.3f (2,795), pyörän alin piste %.3f (0 ± 0,01)" % [wb, low])
	if absf(wb - 2.795) > 0.01 or absf(low) > 0.01:
		print("TESTI VIKA pyörät väärin")


func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	_lineup(false)
	_measure()
	await _shot("edesta", Vector3(0.1, 1.1, -9.5), Vector3(0.1, 0.7, 0))
	await _shot("takaa", Vector3(0.1, 1.1, 9.5), Vector3(0.1, 0.7, 0))
	await _shot("vino_ylhaalta", Vector3(-6.5, 5.5, -6.5), Vector3(0, 0.5, 0))
	await _shot("kolmeneljannes", Vector3(-6.0, 1.6, -6.0), Vector3(0, 0.6, 0))
	_lineup(true)
	await _shot("sivusta", Vector3(-11.0, 0.9, 0), Vector3(0, 0.7, 0))
	await _shot("sivusta_mercedes", Vector3(-6.0, 0.8, -2.6), Vector3(0, 0.7, -2.6))
	await _shot("sivusta_taksi", Vector3(-6.5, 0.8, 2.8), Vector3(0, 0.7, 2.8))
	await _shot("kaari", Vector3(-2.4, 0.6, -3.3), Vector3(-0.8, 0.4, -3.86), 35.0)  # etupyöränkaari vinosti edestä
	await _shot("sisus", Vector3(-2.6, 1.45, -2.2), Vector3(0, 0.95, -2.6), 45.0)  # sivulasien läpi
	_lineup(false)
	await _shot("keula", Vector3(-1.2, 0.8, -4.2), Vector3(-1.2, 0.55, -2.0), 35.0)
	await _shot("keula_lahi", Vector3(-1.2, 0.8, -4.6), Vector3(-1.2, 0.62, -1.9), 30.0)
	await _shot("pera", Vector3(-1.2, 1.0, 4.2), Vector3(-1.2, 0.65, 2.0), 35.0)
	await _shot("pera_vino", Vector3(-3.6, 1.4, 4.4), Vector3(-1.2, 0.75, 1.4), 35.0)
	await _shot("taksi_pera", Vector3(3.6, 1.4, 5.0), Vector3(1.4, 0.8, 1.8), 35.0)
	# Katon liitokset (siviili-Saab x = -1,2): A-pilari ja tuulilasin yläkulma, C-pilari ja takalasin yläkulma, ylhäältä.
	await _shot("katto_etu", Vector3(-2.6, 1.9, -1.4), Vector3(-1.6, 1.35, -0.4), 28.0)
	await _shot("katto_taka", Vector3(-2.6, 1.9, 2.2), Vector3(-1.6, 1.3, 1.1), 28.0)
	await _shot("katto_ylhaalta", Vector3(-1.2, 4.2, 0.4), Vector3(-1.2, 1.3, 0.3), 45.0)
	await _shot("katto_c_kulma", Vector3(-2.5, 1.75, 1.5), Vector3(-1.85, 1.33, 1.0), 22.0)  # C-pilarin ja katon takakulman liitos
	await _shot("katto_a_kulma", Vector3(-2.6, 1.7, -0.9), Vector3(-1.85, 1.33, -0.4), 22.0)  # A-pilarin ja katon etukulman liitos
	await _shot("katto_sivu", Vector3(-3.6, 1.45, 0.3), Vector3(-1.2, 1.3, 0.3), 30.0)
	get_tree().quit()
