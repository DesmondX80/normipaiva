extends Node3D
## Päivin Hyundai Pony (vehicles.gd pony) ja vertailuksi car() rinnakkain edestä, sivulta, takaa ja vinosti
## ylhäältä sekä keula ja perä suurennettuina. Mittaa Ponyn ulkomitat, akselivälin ja pyörien alimman pisteen.
## Ajo: tools/testit/aja.sh tscn tools/testit/pony_kuvat.tscn

const Vehicles := preload("res://scripts/vehicles.gd")
const B := preload("res://scripts/build.gd")

var out := "user://pony"
var cam: Camera3D
var pony: Node3D
var car: Node3D
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
	pony = Node3D.new()
	add_child(pony)
	wheels = Vehicles.pony(pony, Color(0.78, 0.05, 0.05), "PÄI-V1")
	car = Node3D.new()
	add_child(car)
	Vehicles.car(car, Color(0.78, 0.05, 0.05), "ABC-123")
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40.0
	_run.call_deferred()


## Rinnakkain (edestä, takaa, ylhäältä) tai peräkkäin (sivukuva: car() ei peitä Ponya).
func _lineup(side: bool) -> void:
	pony.position = Vector3(0, 0, -2.6) if side else Vector3(-1.2, 0, 0)
	car.position = Vector3(0, 0, 2.6) if side else Vector3(1.4, 0, 0)


func _shot(name: String, from: Vector3, to: Vector3, fov := 40.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, to)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("PONY_KUVAT kuva " + out + "/" + name + ".png")


## Kori mitataan yhdistetyn verkon pisteistä; leveys vyötärölinjan alta (peilit eivät kuulu leveyteen, esikuva 1595 mm).
func _measure() -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var half_w := 0.0
	for c in pony.get_children():
		if not (c is MeshInstance3D):
			continue
		var am: Mesh = (c as MeshInstance3D).mesh
		for s in am.get_surface_count():
			for v: Vector3 in am.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				lo = lo.min(v)
				hi = hi.max(v)
				if v.y < 0.86:
					half_w = maxf(half_w, absf(v.x))
	var size := Vector3(half_w * 2.0, hi.y - minf(lo.y, 0.0), hi.z - lo.z)
	print("PONY mitat L×K×P %.2f × %.2f × %.2f (tavoite 1,60 × 1,38 × 4,0 ±5 %%), peileineen %.2f, korin pohja y %.3f" % [size.x, size.y, size.z, hi.x - lo.x, lo.y])
	if absf(size.x - 1.6) > 0.08 or absf(size.y - 1.38) > 0.07 or absf(size.z - 4.0) > 0.2:
		print("TESTI VIKA Ponyn mitat yli 5 % tavoitteesta")
	if lo.y < -0.001:
		print("TESTI VIKA kori maan alla")
	var zs: Array[float] = []
	var low := INF
	for w in wheels:
		zs.append(w.position.z)
		low = minf(low, w.position.y - 0.29)
	var wb: float = zs.max() - zs.min()
	print("PONY akseliväli %.3f (2,38), pyörän alin piste %.3f (0 ± 0,01)" % [wb, low])
	if absf(wb - 2.38) > 0.02 or absf(low) > 0.01:
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
	await _shot("sivusta_pony", Vector3(-6.0, 0.8, -2.6), Vector3(0, 0.7, -2.6))
	_lineup(false)
	await _shot("keula", Vector3(-1.2, 0.8, -4.2), Vector3(-1.2, 0.55, -2.0), 35.0)
	await _shot("keula_lahi", Vector3(-1.2, 0.8, -4.6), Vector3(-1.2, 0.62, -1.9), 30.0)
	await _shot("pera", Vector3(-1.2, 1.0, 4.2), Vector3(-1.2, 0.65, 2.0), 35.0)
	await _shot("pera_vino", Vector3(-3.6, 1.4, 4.4), Vector3(-1.2, 0.75, 1.4), 35.0)
	get_tree().quit()
