extends Node3D
## Pelaajan maha ja tuulipuvun raidat: kuvat <asento>_<kuva>.png. --ennen = vanha asu (ei löllerömahaa, turkoosi raita).
## aja.sh tscn tools/testit/pelaaja_maha_kuvat.tscn <kansio> [--ennen]
const Kuva := preload("res://tools/testit/kuva.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

var out := "user://pelaaja_maha"
var cam: Camera3D
var ennen := false


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
	sun.rotation_degrees = Vector3(-40, -30, 0)
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(40, 0.1, 40)), Vector3(0, -0.05, 0), Color(0.6, 0.6, 0.6))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_run.call_deferred()


func _run() -> void:
	var l: Dictionary = Looks.PLAYER.duplicate(true)
	if ennen:
		l.erase("sag")
		l.erase("triple_stripe")
		l["shirt"] = Color(0.42, 0.18, 0.58)
		l["pants"] = Color(0.42, 0.18, 0.58)
		l["tracksuit"] = {"a": Color(0.08, 0.66, 0.64), "b": Color(0.07, 0.07, 0.09)}
		l["stripe_color"] = Color(0.08, 0.66, 0.64)
	var c: Node3D = Looks.make(self, l)
	for an in ["Idle", "Walk"]:
		c.restart(an, 0.0, 0.0)
		c.anim.seek(0.25, true)
		for i in 6:
			await get_tree().process_frame
		var fwd: Vector3 = c.global_transform.basis.z
		var hip: Vector3 = c.to_global(c.bone_position("spine_01"))
		var chest: Vector3 = c.to_global(c.bone_position("spine_03"))
		var knee: Vector3 = c.to_global(c.bone_position("calf_l")) if c.skeleton.find_bone("calf_l") >= 0 else hip - Vector3(0, 0.5, 0)
		# [nimi, kulma vaaka, kulma pysty, etäisyys, kohde]
		for v in [["etu", 0.0, 0.0, 4.0, hip + Vector3(0, 0.25, 0)], ["sivu", 90.0, 0.0, 4.0, hip + Vector3(0, 0.25, 0)],
				["taka", 180.0, 0.0, 4.0, hip + Vector3(0, 0.25, 0)], ["ylhaalta", 0.0, 65.0, 3.0, hip + Vector3(0, 0.25, 0)],
				["maha_sivu", 90.0, 0.0, 1.8, hip], ["maha_vino", 40.0, 10.0, 1.8, hip],
				["hiha", 60.0, 20.0, 1.8, chest + Vector3(0.35, 0, 0)], ["lahje", 90.0, 0.0, 1.8, hip - Vector3(0, 0.55, 0)], ["koko_sivu", 90.0, 0.0, 5.5, hip + Vector3(0, 0.1, 0)]]:
			cam.fov = 22
			var d := fwd.rotated(Vector3.UP, deg_to_rad(v[1]))
			d = d.rotated(d.cross(Vector3.UP).normalized(), deg_to_rad(v[2])) if v[2] != 0.0 else d
			cam.global_position = v[4] + d * v[3]
			cam.look_at(v[4], Vector3.UP)
			await Kuva.piirto()
			Kuva.ruutu(get_viewport()).save_png("%s/%s_%s.png" % [out, an, v[0]])
	print("valmis ", out)
	get_tree().quit()
