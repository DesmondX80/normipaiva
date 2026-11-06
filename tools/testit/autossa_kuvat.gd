extends Node3D
## Auton istujat (Vehicles.istuta): Pekka ratissa ja sankari lippiksineen Pekan Volvo-farmarissa kuten Pekan kyydissä
## sekä taksikuski Mercedes-taksissa (x = 4).
## Mittaa paistetusta verkosta pään (ja lippiksen) korkeimman pisteen katon alapintaan, jalkojen alimman pisteen
## helmaan ja vartalon etäisyyden rattiin; kuvat sivulta, edestä ja ylhäältä katto poistettuna (leikkaus).
## Ajo: tools/testit/aja.sh tscn tools/testit/autossa_kuvat.tscn

const Vehicles := preload("res://scripts/vehicles.gd")
const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Pose := preload("res://scripts/pose.gd")

const KATTO_ALA := 1.39  # Volvon ja Mercedeksen katon alapinta (ROOF - ROOF_T)
const HELMA := 0.22  # alakorin alapinta (SILL)

var out := "user://autossa"
var cam: Camera3D
var car: Node3D
var hahmot: Array[Node3D] = []
var autot: Array[Node3D] = []  # hahmon auto (sama indeksi)
var ratit: Array = []  # hahmon auton ratin napa tai null (matkustaja)
var taksi: Node3D


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
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 150, 0)
	sun.shadow_enabled = true
	add_child(sun)
	B.mesh(self, B.boxm(Vector3(20, 0.1, 20)), Vector3(0, -0.05, 0), Color(0.4, 0.41, 0.43))
	car = Node3D.new()
	add_child(car)
	Vehicles.volvo(car, Color(0.22, 0.3, 0.18), "PEK-14", true)
	var pekka := Looks.make(car, Looks.PEKKA)
	pekka.play("Driving", 0.0)
	Vehicles.istuta(pekka, "volvo", "kuski")
	var hero := Looks.make(car, Looks.player())
	Looks.add_cap(hero)
	hero.play("Sitting_Idle", 0.0)
	Vehicles.istuta(hero, "volvo", "etu")
	taksi = Node3D.new()
	taksi.position = Vector3(4.0, 0, 0)
	add_child(taksi)
	Vehicles.taxi(taksi, "TXI-808")
	var kuski := Looks.make(taksi, Looks.TAXI_DRIVER)
	kuski.play("Driving", 0.0)
	Vehicles.istuta(kuski, "mercedes", "kuski")
	hahmot = [pekka, hero, kuski]
	autot = [car, car, taksi]
	ratit = [Vehicles.ISTUIMET.volvo.ratti, null, Vehicles.ISTUIMET.mercedes.ratti]
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_run.call_deferred()


func _shot(name: String, from: Vector3, to: Vector3, fov := 40.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, to)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("AUTOSSA kuva " + out + "/" + name + ".png")


## Lippis ja muut luurangon ulkopuoliset verkot (ei skinattuja): niiden korkein piste auton avaruudessa.
func _irtoverkot_max_y(ch: Node3D, auto: Node3D) -> float:
	var y := -INF
	for n in ch.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin != null or not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var xf := auto.global_transform.affine_inverse() * mi.global_transform
		for sf in mi.mesh.get_surface_count():  # verkon pisteet, ei rajauslaatikko (se on muotoa suurempi)
			for v: Vector3 in mi.mesh.surface_get_arrays(sf)[Mesh.ARRAY_VERTEX]:
				y = maxf(y, (xf * v).y)
	return y


func _mittaa() -> void:
	var nimet := ["Pekka", "sankari", "taksikuski"]
	for i in hahmot.size():
		var ch := hahmot[i]
		var auto := autot[i]
		var paa := Pose.limb_points(ch, auto, ["Head", "neck_01"])  # luu on "Head" (Quaternius), ei "head"
		var jalat := Pose.limb_points(ch, auto, ["foot_l", "foot_r", "calf_l", "calf_r", "ball_l", "ball_r"])
		if paa.is_empty():
			print("AUTOSSA ei tarkistettu (headless)")
			return
		var top := -INF
		for p in paa:
			top = maxf(top, p.y)
		top = maxf(top, _irtoverkot_max_y(ch, auto))
		var low := INF
		for p in jalat:
			low = minf(low, p.y)
		var rivi := "AUTOSSA %s pää %.3f, katon ala %.3f, rako %.3f; jalat alin %.3f (helma %.3f)" % [nimet[i], top, KATTO_ALA, KATTO_ALA - top, low, HELMA]
		if top > KATTO_ALA - 0.02:
			print("TESTI VIKA %s: pää katon läpi tai kiinni (rako %.3f)" % [nimet[i], KATTO_ALA - top])
		if low < HELMA + 0.01:
			print("TESTI VIKA %s: jalat pohjan läpi (%.3f)" % [nimet[i], low])
		if ratit[i] != null:
			var hub: Vector3 = ratit[i]
			var ratti := INF
			var akseli := Vector3(0, 0.5, 0.866)  # _cabin: ratti kierretty 60° X:n ympäri
			for p in Pose.limb_points(ch, auto, ["spine_01", "spine_02", "spine_03", "thigh_l", "thigh_r"]):
				var v := p - hub  # etäisyys ratin kehästä (rengas, säde Vehicles.RATTI_R), ei navasta
				var h := v.dot(akseli)
				ratti = minf(ratti, Vector2((v - akseli * h).length() - Vehicles.RATTI_R, h).length())
			var kl: Vector3 = auto.to_local(ch.to_global(ch.bone_position("hand_l")))
			var kr: Vector3 = auto.to_local(ch.to_global(ch.bone_position("hand_r")))
			var kasi := maxf(absf(kl.distance_to(hub) - Vehicles.RATTI_R), absf(kr.distance_to(hub) - Vehicles.RATTI_R))
			rivi += "; vartalo ja reidet ratin kehästä %.3f, kädet kehältä %.3f" % [ratti, kasi]
			if ratti < 0.04:
				print("TESTI VIKA %s: ratin kehä vartalossa tai reisissä (%.3f)" % [nimet[i], ratti])
			if kasi > 0.06:
				print("TESTI VIKA %s: kädet eivät ole ratilla (%.3f)" % [nimet[i], kasi])
		print(rivi)


func _run() -> void:
	for i in 12:
		await get_tree().process_frame
	_mittaa()
	await _shot("sivu", Vector3(-3.2, 1.25, 0.0), Vector3(0, 1.1, -0.1), 35.0)
	await _shot("edesta", Vector3(0, 1.5, -4.0), Vector3(0, 1.15, 0), 32.0)
	await _shot("vino", Vector3(-2.6, 1.9, -2.6), Vector3(0, 1.1, -0.1), 35.0)
	await _shot("taksi_sivu", Vector3(0.8, 1.25, 0.0), Vector3(4.0, 1.1, -0.1), 35.0)
	await _shot("taksi_vino", Vector3(1.4, 1.9, -2.8), Vector3(4.0, 1.1, -0.1), 35.0)
	get_tree().quit()
