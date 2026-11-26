extends Node3D
## Juntin paidan hihat ja olkapäät eri asennoissa (valkoiset sirpaleet): kuvat <asento>_<vari>.png.
## aja.sh tscn tools/testit/juntti_paita_kuvat.tscn <kansio> [--raidat=0] [--anat=0] [--t=0.25]
const Kuva := preload("res://tools/testit/kuva.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")

var out := "user://juntti_paita"
var cam: Camera3D
var raidat := true
var anat := true
var t := 0.25


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and not a[0].begins_with("--"):
		out = a[0]
	for s in a:
		if s == "--raidat=0":
			raidat = false
		elif s == "--anat=0":
			anat = false
		elif s.begins_with("--t="):
			t = float(s.substr(4))
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
	var l: Dictionary = Looks.JUNTTI.duplicate()
	l["shoe"] = "paljas"
	l["anat"] = anat
	l["stripes"] = raidat
	var c: Node3D = Looks.make(self, l)
	for an in ["Sprint", "Crouch_Fwd", "Crouch_Idle", "Driving", "Swim_Fwd", "Swim_Idle"]:
		if not c.anim.has_animation(an):
			print("EI ANIMAATIOTA ", an)
			continue
		c.restart(an, 0.0, 0.0)
		c.anim.seek(t, true)
		for i in 6:
			await get_tree().process_frame
		var ctr: Vector3 = c.to_global(c.bone_position("spine_03"))
		var fwd: Vector3 = c.global_transform.basis.z
		for v in [["etu", 0.0, 0.0, 3.2], ["sivu", 90.0, 0.0, 3.2], ["ylhaalta", 0.0, 60.0, 3.2], ["lahi", 35.0, 15.0, 1.6]]:
			cam.fov = 22
			var d := fwd.rotated(Vector3.UP, deg_to_rad(v[1]))
			d = d.rotated(d.cross(Vector3.UP).normalized(), deg_to_rad(v[2])) if v[2] != 0.0 else d
			cam.global_position = ctr + d * v[3]
			cam.look_at(ctr, Vector3.UP)
			await Kuva.piirto()
			Kuva.ruutu(get_viewport()).save_png("%s/%s_%s.png" % [out, an, v[0]])
	print("valmis ", out)
	get_tree().quit()
