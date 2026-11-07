extends Node3D
## Puhekuplien vuorottelu (bubble.gd): kolme lähekkäistä hahmoa sanoo repliikkinsä yhtä aikaa. Lähekkäin (alle
## VUORO_R) saa näkyä vain yksi kupla kerrallaan (TESTI VIKA, jos kaksi), ja jokainen repliikki näytetään vuorollaan.
## Kaukana oleva neljäs hahmo puhuu samaan aikaan (saa näkyä yhtä aikaa). Puhujan tyhjennys poistaa kuplan heti.
## Kuvat _kupla_<n>. Ajo: tools/testit/aja.sh tscn tools/testit/kuplat.tscn

const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const Bubble := preload("res://scripts/bubble.gd")

var out := "user://kuplat"
var cam: Camera3D
var vikoja := 0


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA kuplat: " + t)


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
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 150, 0)
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(30, 0.1, 30)), Vector3(0, -0.05, 0), Color(0.4, 0.5, 0.35))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(1.5, 2.2, 7.5), Vector3(1.5, 1.6, 0))
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("KUPLAT kuva " + out + "/" + name + ".png")


func _run() -> void:
	var looks := [Looks.PEKKA, Looks.ARTO, Looks.SINIKKA, Looks.TAXI_DRIVER]
	var xs := [0.0, 1.1, 2.2, 14.0]  # kolme lähekkäin, neljäs kaukana
	var kuplat: Array = []
	for i in 4:
		var c := Looks.make(self, looks[i])
		c.position = Vector3(xs[i], 0, 0)
		c.play("Idle", 0.0)
		kuplat.append(B.bubble(c, Vector3(0, 2.1, 0)))
	for i in 10:
		await get_tree().process_frame
	var lines := ["Perkele, kuka vei mun kahvit?", "Hmm-hmm, mää vaan hyräilen tässä.", "Hihii! Mää en ainakaan!",
		"Taksi odottaa kulmalla."]
	for i in 4:
		kuplat[i].text = lines[i]
	var nahty := [false, false, false, false]
	var t0 := Time.get_ticks_msec()
	var kuva := 0
	var next_shot := 0.0
	while Time.get_ticks_msec() - t0 < 16000:
		await get_tree().process_frame
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		var naky: Array = []
		for i in 4:
			if kuplat[i].text != "":
				naky.append(i)
				nahty[i] = true
		var lahi := naky.filter(func(i: int) -> bool: return i < 3)
		if lahi.size() > 1:
			_vika("lähekkäin näkyy %d kuplaa yhtä aikaa (%.1f s): %s" % [lahi.size(), t, lahi])
			break
		if t >= next_shot and kuva < 4:
			await _shot("kupla_%d" % kuva)
			kuva += 1
			next_shot += 3.5
	for i in 4:
		if not nahty[i]:
			_vika("repliikki %d ei näkynyt koskaan" % i)
	print("KUPLAT kaikki näkyivät: %s" % [nahty])
	# Kaukainen kupla saa näkyä samaan aikaan: asetetaan uudet repliikit ja katsotaan heti.
	kuplat[0].text = "Vielä yks juttu."
	kuplat[3].text = "Mittari raksuttaa."
	for i in 3:
		await get_tree().process_frame
	if kuplat[0].text == "" or kuplat[3].text == "":
		_vika("kaukaiset kuplat eivät näkyneet yhtä aikaa")
	# Puhujan tyhjennys poistaa kuplan heti (ei vuoroaan odottanut).
	kuplat[0].text = ""
	for i in 2:
		await get_tree().process_frame
	if kuplat[0].text != "":
		_vika("tyhjennys ei poistanut kuplaa")
	print("KUPLAT valmis, %d vikaa" % vikoja)
	get_tree().quit()
