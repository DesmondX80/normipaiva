extends Node3D
## Pelaajan hahmon lähikuvat ilman pelin latausta: yksi kohta (oletus vasen olkapää) viidestä suunnasta.
## Käyttö: tools/testit/aja.sh tscn tools/testit/hahmo_lahikuva.tscn keho=hintela asu=nahkaliivi [kohde=x,y,z] [etaisyys=0.9]
## [vari=1] [nimi=<lisä tiedostonimeen>] [l.<avain>=<luku> suora ulkonäköarvo, esim. l.muscle=0] (muut argumentit avain=arvo menevät Looks.customiin, esim. maha=hoikka tukka=kalju).
## Kuvat: <kansio>/lahi_<keho>_<suunta>.png (edesta, viisto, sivu, takaa, ylhaalta, takaviisto).
## vari=1: vartalo yksivärisenä harmaana ilman vaatteita peittämässä muotoa (kolot ja taitteet näkyvät varjoista).

const Kuva := preload("res://tools/testit/kuva.gd")
const Looks := preload("res://scripts/looks.gd")


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://"
	var kohde := Vector3(0.19, 1.46, 0.0)
	var d := 0.9
	var harmaa := false
	var suorat := {}
	var nimi_lisa := ""
	Looks.custom = {"tukka": "kalju", "maha": "hoikka", "lasit": "ei"}
	Looks.outfit = "nahkaliivi"
	for i in range(1, a.size()):
		var kv := a[i].split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"asu":
				Looks.outfit = kv[1]
			"kohde":
				var f := kv[1].split_floats(",")
				kohde = Vector3(f[0], f[1], f[2])
			"etaisyys":
				d = float(kv[1])
			"vari":
				harmaa = kv[1] == "1"
			"nimi":
				nimi_lisa = "_" + kv[1]
			_:
				if kv[0].begins_with("l."):  # suora ulkonäköarvo, esim. l.muscle=0 l.delt_keep=0.5 (muodon kokeiluun)
					suorat[kv[0].substr(2)] = float(kv[1])
				else:
					Looks.custom[kv[0]] = kv[1]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.36, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()  # sivuvalo ylhäältä: kolot ja taitteet jäävät varjoon
	key.rotation_degrees = Vector3(-35, -50, 0)
	key.light_energy = 1.3
	add_child(key)
	var fill := DirectionalLight3D.new()  # vastavalo takaa oikealta: varjopuolen muodot erottuvat
	fill.rotation_degrees = Vector3(-20, 130, 0)
	fill.light_energy = 0.6
	fill.light_color = Color(0.75, 0.85, 1.0)
	add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.current = true
	var look := Looks.player()
	look.merge(suorat, true)
	var c := Looks.make(self, look)
	c.rotation.y = PI  # kasvot +Z:aan
	c.play("Idle", 0.0)
	c.anim.seek(0.0, true)
	if harmaa:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.75, 0.75, 0.75)
		m.roughness = 0.9
		c.body_mi.material_override = m
	for f in 6:
		await get_tree().process_frame
	c.process_mode = Node.PROCESS_MODE_DISABLED  # sama asento joka kuvaan
	var keho: String = Looks.custom.get("keho", "tavallinen")
	# Suunnat kohteesta kameraan (hahmon vasen olkapää on +X:ssä, kun kasvot ovat +Z:aan).
	var suunnat := {"edesta": Vector3(0, 0.1, 1), "viisto": Vector3(0.8, 0.25, 0.8), "sivu": Vector3(1, 0.1, 0),
		"takaviisto": Vector3(0.8, 0.25, -0.8), "takaa": Vector3(0, 0.1, -1), "ylhaalta": Vector3(0.15, 1, 0.3)}
	for nimi: String in suunnat:
		cam.position = kohde + (suunnat[nimi] as Vector3).normalized() * d
		cam.look_at(kohde, Vector3.UP)
		await get_tree().process_frame
		await Kuva.piirto()
		await Kuva.piirto()
		Kuva.ruutu(get_viewport()).save_png(out.path_join("lahi_%s%s%s_%s.png" % [keho, nimi_lisa, "_harmaa" if harmaa else "", nimi]))
	get_tree().quit()
