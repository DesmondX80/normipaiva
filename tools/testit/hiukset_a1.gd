extends Node3D
## Hiusten A1-kokeilu: Sinikka (pitkät hiukset) seisoo, ja pään taakse tuodaan seinä (kontaktilaatikko), joka leikkaa hiukset
## eri syvyyksiltä. Kuvat: ilman seinää, seinä (hiukset litistyvät), seinä + debug-värit (magenta = painuu, syaani = heiluu).
## Lopuksi kävely -> pysähdys: heilahduksen suuruus ruuduittain ja kolme kuvaa (kävely, pysähdys, lepo).
## aja.sh tscn tools/testit/hiukset_a1.tscn

const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

var out := "user://hiukset_a1"
var cam: Camera3D
var ch: Node3D


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
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(30, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.36, 0.5, 0.28))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 25.0
	_run.call_deferred()


func _wall(z: float, head_y: float) -> Array:
	# Laatikon +Y osoittaa maailman -Z (kohti kasvoja); pinta on tasossa z.
	var xb := Vector3.RIGHT
	var yb := Vector3(0, 0, -1)
	var h := Vector3(0.4, 0.02, 0.5)
	return [[Transform3D(Basis(xb, yb, xb.cross(yb)), Vector3(0, head_y, z + h.y)), h]]


func _shot(tag: String, view: String) -> void:
	var hp: Vector3 = ch.to_global(ch.bone_position("Head")) + Vector3(0, 0.08, 0)
	var pos := hp + (Vector3(1.2, 0.05, 0.0) if view == "sivu" else (Vector3(0.0, 0.1, 1.2) if view == "takaa" else Vector3(0.0, 0.1, -1.4)))
	cam.look_at_from_position(pos, hp)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	cam.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [tag, view]))


func _debug(on: bool) -> void:
	for m in ch.hair_mats:
		m.set_shader_parameter("hair_debug", on)


func _run() -> void:
	ch = Looks.make(self, Looks.sinikka_bikini())
	ch.play("Idle", 0.0)
	for i in 6:
		await get_tree().process_frame
	print("hiukset: %d verkkoa, hair_press=%s" % [ch.hair_mis.size(), ch.hair_mis[0].has_meta("hair_press") if ch.hair_mis.size() > 0 else "ei"])
	if ch.hair_mis.is_empty():
		print("TESTI VIKA hiusverkkoa ei liitetty")
		get_tree().quit()
		return
	var hm: MeshInstance3D = ch.hair_mis[0]
	var c0: PackedFloat32Array = hm.mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]
	var nw := 0
	var nx := 0
	var wmax := 0.0
	for i in c0.size() / 4:
		nw += 1 if c0[i * 4 + 3] > 0.0 else 0
		nx += 1 if c0[i * 4] > 0.0 else 0
		wmax = maxf(wmax, c0[i * 4 + 3])
	print("hiukset: verteksejä %d, w>0 %d (max %.1f mm), heilahduspaino>0 %d, keskipiste %s" % [c0.size() / 4, nw, wmax * 1000.0, nx, hm.get_meta("hair_center")])
	var hp: Vector3 = ch.to_global(ch.bone_position("Head"))
	await _shot("0_ilman", "sivu")
	for dz in [0.1, 0.13]:
		ch.set_contacts(_wall(hp.z + dz, hp.y))
		for i in 3:
			await get_tree().process_frame
		await _shot("1_seina%d" % int(dz * 100), "sivu")
		await _shot("1_seina%d" % int(dz * 100), "takaa")
		_debug(true)
		await _shot("2_debug%d" % int(dz * 100), "sivu")
		_debug(false)
	ch.clear_contacts()
	# Kävely -> pysähdys: heilahdus.
	var shots := {}
	var peak := 0.0
	for f in 120:
		var d := get_process_delta_time()
		if f < 40:
			ch.position.z -= 2.5 * d
		await get_tree().process_frame
		var s: float = ch._sway_x.length()
		peak = maxf(peak, s)
		if f % 10 == 0:
			print("hiukset: ruutu %d sway %.1f mm" % [f, s * 1000.0])
		if f == 38 or f == 50 or f == 119:
			await _shot("3_heilahdus_%d" % f, "sivu")
	print("hiukset: heilahduksen huippu %.1f mm (raja 50)" % (peak * 1000.0))
	if peak < 0.002:
		print("TESTI VIKA hiukset eivät heiluneet (huippu < 2 mm)")
	if peak > 0.0501:
		print("TESTI VIKA heilahdus yli rajan")
	print("kuvat: ", out)
	get_tree().quit()
