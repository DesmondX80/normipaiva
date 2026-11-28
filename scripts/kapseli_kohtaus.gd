extends CanvasLayer
## Legendaarinen hetki "peruskiven_kapseli" (Peruskiven kapseli): kun laatta kiven edessä nostetaan ensimmäistä
## kertaa molempien vihjeiden jälkeen (main.gd _peruskivi_acted "laatta"), hetki lavastetaan Rautaruukin Rojuniemessä
## (retki_rojuniemi.gd, taskukohtaus). Legendan ydin: tarina, jonka vartija on kertonut kerran liikaa. Vaiheet:
##   laatta   pelaaja kyykyssä laatan reunalla; vartija huomaa kopilta ("Hei! Älä koske siihen!") ja hölkkää paikalle.
##            Laatan etureuna nousee takareunan varassa, kolosta pöllähtää pölyä, ja laatta työnnetään sivuun.
##            Kolossa on vihreäksi patinoitunut kuparikapseli. Vartija: "...Ai. Se liikkuu."
##   kapseli  pelaaja nostaa kapselin kolosta ja nousee. Vartija: "Kuuskymmentä vuotta mää oon kertonu tästä."
##            Kansi kierretään auki (pykälät rapisevat), kolikko kilahtaa maahan ja vartija vetää esiin paperirullan.
##   kirje    (huipennus) vartija lukee kirjeen ääneen olan yli kuvattuna: "Löytäjälle. Tämä kapseli on laatan alla.
##            Älä kerro vartijalle. Se kertoo kaikille. – Rojuniemen portinvartija 25.8.1962." Hiljaisuus, sitten:
##            "Ne tiesi jo silloin." Vartija nauraa.
##   radio    vartija nostaa radiopuhelimen: "Portti kaikille! Peruskiven kapseli LÖYTY!" Hallin katolla höyrypilli
##            viheltää ja höyry nousee. Taksikuski tulee katsomaan: "Mää oon kuullu tän tarinan sata kertaa."
##            Vartija: "Ja nyt se on totta."
##   otsikko  PERUSKIVEN KAPSELI: kuski, vartija (kapseli ylhäällä) ja pelaaja kiven edessä.
## Kehys: retki_rojuniemi.gd:n paikallinen kehys: -Z tehtaan aita ja hallit, +Z tie ja taksi, maa y 0. Hahmojen etu -Z
## (Looks). Oikea pelaaja, vartija ja taksikuski piiloon kohtauksen ajaksi (kopiot näyttelevät); retki_rojuniemi.staged
## pitää laatan kohtauksen hallussa. Kapseli jää vartijakopin ikkunalaudalle, ja vartija muistelee (MUISTO).

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const Retki := preload("res://scripts/retki_rojuniemi.gd")

const RATE := 22050.0
const DUR := {"laatta": 8.0, "kapseli": 9.0, "kirje": 10.0, "radio": 10.0, "otsikko": 6.5}
const ORDER := ["laatta", "kapseli", "kirje", "radio", "otsikko"]

const STONE := Vector3(5.5, 0, -3.8)  # retki_rojuniemi.gd: peruskivi (2,4 x 1,1 m, yläpinta y 1,4)
const SLAB_PIVOT := Vector3(6.5, 0.01, -1.9)  # laatan takareuna: etureuna nousee tämän varassa
const SLAB_HALF := 0.5
const HOLE := Vector3(6.5, 0.0, -1.4)
const ME_CROUCH := Vector2(6.5, -0.7)  # laatan etureunalla, kasvot kiveen (-Z)
const ME_STAND := Vector2(6.45, -0.72)
const GUARD_FROM := Vector2(-7.0, -3.0)
const GUARD_AT := Vector2(5.55, -0.5)
const KUSKI_FROM := Vector2(1.6, 3.6)
const KUSKI_AT := Vector2(4.35, 0.15)
const WHISTLE := Vector3(3.0, 7.25, -10.4)  # höyrypillin suu hallin katolla (retki_rojuniemi.gd)
const LETTER := "Löytäjälle.\n\nTämä kapseli on laatan alla.\nÄlä kerro vartijalle.\nSe kertoo kaikille.\n\n– Rojuniemen portinvartija,\n25.8.1962"
## Vartija muistelee hetkeä myöhemmin (main.gd _peruskivi_acted "vartija").
const MUISTO := ["Muistatko sen kirjeen? \"Älä kerro vartijalle.\" Mää oon kertonu sen jo kaikille. Ne tiesi.",
	"Kapseli on tuossa kopin ikkunalla. Joka vuoro mää näytän sen jollekin. Ei voi mitään.",
	"Koko tehdas kuuli radiosta. Höyrypilli vihelsi. En oo ikinä kuullu sen viheltävän päiväsaikaan.",
	"Kuski kysy, kerronko mää vieläkin sitä tarinaa. Kerron. Nyt se on vaan totta."]

var interior: Node3D  # retki_rojuniemi.gd
var _was_visible := {}

var phase := ""
var _t := 0.0
var _cam: Camera3D
var _ui: Control
var _keys: Node
var _story := ""
var _bub := {}
var _once := {}
var _props: Array[Node3D] = []
var me: Node3D
var guard: Node3D
var kuski: Node3D
var capsule: Node3D
var cap: Node3D
var coin: Node3D
var roll: Node3D
var letter: Node3D
var radio: Node3D
var pipe: Node3D
var _dust: CPUParticles3D
var _steam: CPUParticles3D
var _fill: OmniLight3D
var _slab_a := 0.0  # laatan nostokulma (rad)
var _coin_t := -1.0
var _coin_from := Vector3.ZERO
var _coin_at := Vector3.ZERO
var _whistle: AudioStreamWAV
var _crackle: AudioStreamWAV
var cap_off := false  # testi lukee
var letter_read := false
var whistled := false


func _ready() -> void:
	layer = 6
	_cam = Camera3D.new()
	interior.add_child(_cam)
	_props.append(_cam)
	_cam.make_current()
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_keys.set_text("%s ohita" % Settings.cap("interact"))
	_whistle = _whistle_wav()
	_crackle = _crackle_wav()
	for nd in [interior.walker, interior._guard, interior.kuski]:
		if nd != null:
			_was_visible[nd] = (nd as Node3D).visible
			(nd as Node3D).visible = false
	interior._bubble.text = ""
	interior.staged = true
	interior._hole.visible = true
	interior.shelf_capsule.visible = false
	_build()
	_set_slab(0.0, 0.0)
	_begin("laatta")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	me = Looks.make(interior, Looks.player())
	Looks.add_cap(me)
	guard = Looks.make(interior, Retki.GUARD_LOOK)
	kuski = Looks.make(interior, Looks.TAXI_DRIVER)
	for c in [me, guard, kuski]:
		_props.append(c)
	capsule = Retki.build_capsule(interior)
	cap = capsule.get_meta("cap")
	_props.append(capsule)
	coin = Node3D.new()
	interior.add_child(coin)
	_props.append(coin)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.86, 0.72, 0.4)
	cm.metallic = 0.9
	cm.roughness = 0.25
	var cd := B.mesh(coin, B.cyl(0.024, 0.024, 0.004, 18), Vector3.ZERO, Color.WHITE)
	cd.material_override = cm
	B.mesh(coin, B.cyl(0.017, 0.017, 0.0045, 18), Vector3.ZERO, Color(0.7, 0.56, 0.3))  # kohokuvan reuna
	coin.visible = false
	roll = Node3D.new()
	interior.add_child(roll)
	_props.append(roll)
	B.mesh(roll, B.cyl(0.022, 0.022, 0.2, 12), Vector3.ZERO, Color(0.9, 0.86, 0.72))
	B.mesh(roll, B.cyl(0.023, 0.023, 0.03, 12), Vector3(0, 0.02, 0), Color(0.75, 0.3, 0.25))  # narunauha
	roll.visible = false
	letter = _build_letter()
	radio = _build_radio()
	pipe = Node3D.new()
	interior.add_child(pipe)
	_props.append(pipe)
	pipe.position = WHISTLE
	# Höyrypillin höyry: pehmeät kameraan kääntyvät hattarat (ei palloja).
	_steam = _puffs(Color(0.93, 0.93, 0.96, 0.95), 3.4, 180, 3.0)
	pipe.add_child(_steam)
	_steam.direction = Vector3.UP
	_steam.spread = 20.0
	_steam.initial_velocity_min = 6.0
	_steam.initial_velocity_max = 8.0
	_steam.gravity = Vector3(0.6, -0.2, 0)
	_steam.damping_min = 1.2
	_steam.damping_max = 1.8
	_steam.scale_amount_min = 0.6
	_steam.scale_amount_max = 1.6
	_steam.one_shot = false
	_steam.explosiveness = 0.0
	_dust = _puffs(Color(0.86, 0.8, 0.7, 0.42), 0.22, 80, 1.8)
	interior.add_child(_dust)
	_props.append(_dust)
	_dust.position = HOLE + Vector3(0, 0.05, 0)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.45, 0.02, 0.45)
	_dust.direction = Vector3.UP
	_dust.spread = 40.0
	_dust.initial_velocity_min = 0.4
	_dust.initial_velocity_max = 1.0
	_dust.gravity = Vector3(0, -0.08, 0)
	_fill = OmniLight3D.new()
	interior.add_child(_fill)
	_props.append(_fill)
	_fill.light_color = Color(1.0, 0.93, 0.8)
	_fill.light_energy = 0.8
	_fill.omni_range = 6.0


## Kirje: kellertävä paperi (A5), taitoksen jäljet ja käsin kirjoitettu teksti; etupinta +Z.
func _build_letter() -> Node3D:
	var l := Node3D.new()
	interior.add_child(l)
	_props.append(l)
	var q := QuadMesh.new()
	q.size = Vector2(0.17, 0.23)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.93, 0.88, 0.74)
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = pm
	var mi := MeshInstance3D.new()
	mi.mesh = q
	l.add_child(mi)
	for y in [-0.038, 0.038]:  # taitokset
		B.mesh(l, B.boxm(Vector3(0.17, 0.002, 0.001)), Vector3(0, y, 0.0006), Color(0.8, 0.74, 0.6))
	var tx := Label3D.new()
	tx.text = LETTER
	tx.font_size = 36
	tx.pixel_size = 0.00034
	tx.modulate = Color(0.14, 0.12, 0.3)
	tx.outline_size = 0
	tx.position = Vector3(0, 0.0, 0.0015)
	tx.line_spacing = -2.0
	tx.font = B.sys_font(PackedStringArray(["Bradley Hand", "Segoe Script", "Noteworthy", "Comic Sans MS"]), 500)
	l.add_child(tx)
	l.visible = false
	return l


## Radiopuhelin: musta runko, antenni, kaiutinritilä, punainen nappi ja vihreä valo; pystyakseli +Y, etupinta +Z.
func _build_radio() -> Node3D:
	var r := Node3D.new()
	interior.add_child(r)
	_props.append(r)
	B.mesh(r, B.boxm(Vector3(0.06, 0.15, 0.035)), Vector3.ZERO, Color(0.1, 0.1, 0.11))
	B.mesh(r, B.boxm(Vector3(0.062, 0.02, 0.037)), Vector3(0, -0.065, 0), Color(0.2, 0.2, 0.22))
	B.mesh(r, B.cyl(0.005, 0.007, 0.11, 6), Vector3(0.018, 0.13, 0), Color(0.08, 0.08, 0.08))
	for k in 4:
		B.mesh(r, B.boxm(Vector3(0.04, 0.004, 0.002)), Vector3(0, 0.03 - k * 0.01, 0.018), Color(0.3, 0.3, 0.32))
	B.mesh(r, B.boxm(Vector3(0.012, 0.025, 0.01)), Vector3(-0.034, 0.02, 0), Color(0.75, 0.15, 0.1))
	B.mesh(r, B.sphere(0.004, 6), Vector3(-0.015, 0.07, 0.018), Color(0.3, 1.0, 0.4))
	r.visible = false
	return r


func _puffs(col: Color, size: float, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.albedo_texture = _soft_tex()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	q.material = m
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.8
	p.emitting = false
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	return p


func _soft_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


## Laatta: nostokulma a (etureuna ylös takareunan varassa) ja siirto k (0 = kolon päällä, 1 = auki-asento
## retki_rojuniemi.SLAB_OPEN, laskettuna vaakaan).
func _set_slab(a: float, k: float) -> void:
	_slab_a = a
	var s: Node3D = interior._slab
	var hinged := Transform3D(Basis(Vector3.RIGHT, -a), SLAB_PIVOT) * Transform3D(Basis(), Vector3(0, 0.03, SLAB_HALF))
	var open := Transform3D(Basis(Vector3.UP, deg_to_rad(Retki.SLAB_OPEN_YAW)), Retki.SLAB_OPEN)
	s.transform = hinged.interpolate_with(open, k)


## Laatan etureunan piste (paikallinen kehys), x-siirtymä reunaa pitkin.
func _slab_edge(dx: float) -> Vector3:
	var s: Node3D = interior._slab
	return s.transform * Vector3(dx, 0.03, SLAB_HALF)


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	for c in [me, guard, kuski]:
		c.clear_ik()
		_lean(c, 0.0)
		Room.nod(c, 0.0)
	kuski.visible = p == "radio" or p == "otsikko"
	match p:
		"laatta":
			_story = ""
			_stand(me, ME_CROUCH.x, ME_CROUCH.y)
			_face(me, Vector3(ME_CROUCH.x, 0, -3.0))
			me.play("Crouch_Idle", 0.0)
			_stand(guard, GUARD_FROM.x, GUARD_FROM.y)
			guard.rotation.y = B.yaw_to(Vector3(0, 0, 1))
			guard.play("Idle", 0.0)
			capsule.position = HOLE + Vector3(-0.05, 0.068, 0.12)
			capsule.rotation = Vector3(0, deg_to_rad(20.0), PI / 2.0)
		"kapseli":
			_story = ""
			_set_slab(0.0, 1.0)
			_stand(me, ME_CROUCH.x - 0.05, ME_CROUCH.y - 0.1)
			_face(me, Vector3(ME_CROUCH.x, 0, -3.0))
			me.play("Crouch_Idle", 0.0)
			_stand(guard, 5.95, -0.58)  # lähempänä: vetää rullan kapselista
			_face(guard, HOLE)
			guard.play("Idle", 0.2)
			capsule.position = HOLE + Vector3(-0.05, 0.068, 0.12)
			capsule.rotation = Vector3(0, deg_to_rad(20.0), PI / 2.0)
		"kirje":
			_story = ""
			_stand(me, 6.35, -0.62)
			_stand(guard, GUARD_AT.x, GUARD_AT.y - 0.15)
			guard.rotation.y = B.yaw_to(Vector3(0, 0, -1))
			_face(me, Vector3(GUARD_AT.x, 0, GUARD_AT.y - 0.5))
			me.play("Idle", 0.2)
			guard.play("Idle", 0.2)
			roll.visible = false
			coin.visible = true
			_place_coin_ground()
		"radio":
			_story = ""
			_stand(me, 6.35, -0.62)
			_stand(guard, GUARD_AT.x, GUARD_AT.y - 0.15)
			guard.rotation.y = B.yaw_to(Vector3(0.3, 0, 1))
			_face(me, guard.position)
			me.play("Idle", 0.2)
			guard.play("Idle", 0.2)
			letter.visible = false
			_stand(kuski, KUSKI_FROM.x, KUSKI_FROM.y)
			kuski.play("Idle", 0.0)
		"otsikko":
			_story = ""
			_steam.emitting = false
			radio.visible = false
			letter.visible = false
			cap.visible = false
			_stand(kuski, 3.95, -2.55)
			_stand(guard, 4.9, -2.45)
			_stand(me, 7.15, -2.45)
			for c in [me, guard, kuski]:
				c.play("Idle", 0.2)
				_face(c, Vector3(5.6, 0, 4.0))
			Sfx.play("win", -7.0, 0.92)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa laatan E-painalluksesta: sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "laatta" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"laatta":
			_step_laatta()
		"kapseli":
			_step_kapseli()
		"kirje":
			_step_kirje()
		"radio":
			_step_radio()
		"otsikko":
			_step_otsikko()
	_step_coin(delta)
	_ui.queue_redraw()
	if phase != "" and _t >= DUR[phase]:
		var i := ORDER.find(phase)
		if i == ORDER.size() - 1:
			_finish()
		else:
			_begin(ORDER[i + 1])


func _finish() -> void:
	if phase == "":
		return
	phase = ""
	interior.staged = false
	interior._opened = -1  # _refresh asettaa laatan auki-asentoon, kolon tyhjäksi ja kapselin ikkunalaudalle
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	for nd in _was_visible:
		if is_instance_valid(nd):
			(nd as Node3D).visible = _was_visible[nd]
	finished.emit()
	queue_free()


func _step_laatta() -> void:
	# Kädet laatan etureunalle (0-0,6 s); vartija huomaa (0,8) ja hölkkää paikalle (1,2-4,6); laatan etureuna nousee
	# (2,4-4,0), pöly (2,8), laatta työnnetään sivuun (4,0-5,4); kolossa kapseli.
	var lift := _ease(clampf((_t - 2.4) / 1.6, 0.0, 1.0))
	var slide := _ease(clampf((_t - 4.0) / 1.4, 0.0, 1.0))
	_set_slab(0.55 * lift * (1.0 - slide), slide)
	var grip := _ease(clampf(_t / 0.6, 0.0, 1.0)) * (1.0 - _ease(clampf((_t - 5.3) / 0.5, 0.0, 1.0)))
	_reach(me, _g(_slab_edge(0.24) + Vector3(0, 0.02, 0.02)), grip, 0.5 * grip, "_r")
	_reach(me, _g(_slab_edge(-0.24) + Vector3(0, 0.02, 0.02)), grip, 0.5 * grip, "_l")
	if _t > 2.4 and not _once.has("nosto"):
		_once["nosto"] = true
		Sfx.play("grunt", -6.0)
		Sfx.play("rattle_hard", -8.0, 0.6)
	if _t > 2.9 and not _once.has("poly"):
		_once["poly"] = true
		_dust.restart()
		_dust.emitting = true
	if _t > 4.0 and not _once.has("liuku"):
		_once["liuku"] = true
		Sfx.play("rattle", -6.0, 0.55)
	if _t > 5.6 and not _once.has("ylos"):
		_once["ylos"] = true
		me.clear_ik()
		_lean(me, 0.0)
	# Vartija: huomaa ja hölkkää.
	if _t > 0.8:
		if _t < 1.2:
			_face(guard, me.position)
		_bub[guard] = "Hei! Älä koske siihen!" if _t < 2.6 else ""
	var gk := clampf((_t - 1.2) / 3.4, 0.0, 1.0)
	if _t > 1.2:
		if gk < 1.0:
			if not _once.has("jog"):
				_once["jog"] = true
				guard.play("Jog", 0.15)
			var gp := GUARD_FROM.lerp(GUARD_AT, gk)
			_stand(guard, gp.x, gp.y)
			_face(guard, Vector3(GUARD_AT.x, 0, GUARD_AT.y))
		else:
			if not _once.has("perilla"):
				_once["perilla"] = true
				guard.play("Idle", 0.25)
			_face(guard, HOLE)
			Room.nod(guard, 0.3 * _ease(clampf((_t - 5.0) / 0.6, 0.0, 1.0)))
	if _t > 5.8:
		_bub[guard] = "...Ai. Se liikkuu."
	if _t < 2.4:
		_story = "Vartija näkee kopilta, kuka on laatan kimpussa." if _t > 0.9 else ""
		_fit(Vector3(-0.2, 2.4, 6.8), [_head(guard) + Vector3(0, 0.3, 0), _head(me) + Vector3(0, 0.3, 0), _g(Vector3(-9.6, 0.0, -3.9)),
			_g(Vector3(7.3, 0, -1.4)), _g(Vector3(-9.6, 2.4, -4.5))], 1.08)
	else:
		_story = "Laatan alla on kolo. Kolossa on jotain vihreää." if _t > 5.0 else ""
		_fit(Vector3(8.75, 1.3, -3.0), [_g(SLAB_PIVOT + Vector3(-0.6, 0, 0)), _g(Vector3(8.0, 0, -0.7)), _head(me) + Vector3(0, 0.25, 0),
			_g(Vector3(GUARD_AT.x, 1.95, GUARD_AT.y)), _g(Vector3(6.0, 0, -0.2))], 1.06)
	_fill.position = Vector3(7.6, 1.6, -2.4)


func _step_kapseli() -> void:
	# Kapseli kolosta (0,3-1,6 s), pelaaja nousee (2,0); kapseli rinnan edessä kahdessa kädessä; kansi kierretään
	# (3,4-5,0) ja ponnahtaa irti (5,0); kolikko kilahtaa maahan (5,8); vartija vetää paperirullan (6,6-7,6).
	if _t < 2.0:
		var at := capsule.global_position
		var reach := _ease(clampf((_t - 0.3) / 1.0, 0.0, 1.0))
		if _t < 1.6:
			_reach(me, at, reach, 0.55 * reach, "_r")
		else:
			var k := _ease(clampf((_t - 1.6) / 0.4, 0.0, 1.0))
			_reach(me, _g(HOLE + Vector3(0, 0.068 + 0.35 * k, 0.35)), 1.0, 0.55 * (1.0 - k), "_r")
			capsule.global_position = hand(me, "_r")
		if _t > 1.3 and not _once.has("tarttuu"):
			_once["tarttuu"] = true
			Sfx.play("pickup", -6.0, 0.8)
	else:
		if not _once.has("nousu"):
			_once["nousu"] = true
			me.play("Idle", 0.3)
			_stand(me, ME_STAND.x, ME_STAND.y)
			_face(me, Vector3(ME_STAND.x, 0, -3.0))  # kasvot kiveen: kapselin akseli poikittain kameraan nähden
		var twist := clampf((_t - 3.4) / 1.6, 0.0, 1.0)
		var tilt := _ease(clampf((_t - 5.5) / 0.4, 0.0, 1.0)) * (1.0 - _ease(clampf((_t - 6.4) / 0.4, 0.0, 1.0)))
		_hold_capsule(me, twist, tilt)
		if _t > 3.4 and _t < 5.0 and int(_t * 6.0) != int((_t - get_process_delta_time()) * 6.0):
			Sfx.play("rattle", -14.0, 1.6)
		if _t > 5.0 and not cap_off:
			cap_off = true
			Sfx.play("pickup", -3.0, 1.4)
		if _t > 5.8 and not _once.has("kolikko"):
			_once["kolikko"] = true
			_coin_from = capsule.global_position + _axis(me) * 0.16
			_coin_at = _g(Vector3(6.75, 0.035, -0.95))
			_coin_t = 0.0
			coin.visible = true
		# Vartija vetää rullan kapselista.
		var pull := _ease(clampf((_t - 6.6) / 1.0, 0.0, 1.0))
		if _t > 6.4:
			var open_end := capsule.global_position + _axis(me) * 0.15
			_reach(guard, open_end + _axis(me) * (0.08 + 0.3 * pull) + Vector3(0, -0.06, 0), _ease(clampf((_t - 6.4) / 0.3, 0.0, 1.0)), 0.0, "_r")
			roll.visible = true
			roll.global_position = open_end + _axis(me) * (0.22 * pull - 0.02)
			roll.global_basis = _axis_basis(_axis(me))
			if pull > 0.95:
				roll.global_position = hand(guard, "_r")
	if _t > 2.0:
		_face(guard, interior.to_local(capsule.global_position))
	if _t > 3.0:
		_bub[guard] = "Kuuskymmentä vuotta mää oon kertonu tästä kapselista." if _t < 5.6 else ""
	if _t > 6.0:
		_story = "Kolikko kilahtaa laatoitukselle: markka, 1962."
	if _t > 7.8:
		_bub[guard] = "Ja kirje."
	if _t < 2.6:
		_fit(Vector3(8.4, 1.45, -2.7), [_g(HOLE + Vector3(-0.3, 0, 0.1)), _head(me) + Vector3(0, 0.3, 0), _head(guard) + Vector3(0, 0.3, 0),
			_g(HOLE + Vector3(0.4, 0, 0.5))], 1.08)
	else:
		_fit(Vector3(6.15, 1.5, -2.7), [capsule.global_position + Vector3(0, -0.2, 0), _head(me) + Vector3(0, 0.22, 0),
			_head(guard) + Vector3(0, 0.22, 0), capsule.global_position + _axis(me) * 0.3, capsule.global_position - _axis(me) * 0.3], 1.1)
	_fill.position = Vector3(7.2, 1.8, -1.9)


func _step_kirje() -> void:
	# Olan yli: vartija lukee kirjeen ääneen (0-3,8 s); kasvot edestä: hiljaisuus, kysymys, "Ne tiesi jo silloin." ja nauru.
	var lower := _ease(clampf((_t - 7.4) / 0.6, 0.0, 1.0))
	_hold_letter(guard, lower)
	_hold_capsule(me, 1.0, 0.0)
	if _t > 0.5:
		_story = "Vartija lukee kirjeen ääneen. Sitten toisen kerran."
	if _t > 3.9:
		_bub[guard] = ""
		letter_read = true
		_story = "Allekirjoitus: Rojuniemen portinvartija, 25.8.1962."
	if _t > 5.0:
		_bub[me] = "Kuka sen kirjotti?" if _t < 6.4 else ""
	if _t > 6.5:
		_bub[guard] = "Portinvartija. Kuuskytkaks."
	if _t > 8.0:
		_bub[guard] = "Ne tiesi jo silloin. Että vartija kertoo kaikille."
		Room.nod(guard, 0.15 + 0.12 * sin(_t * 18.0) * (1.0 - clampf((_t - 9.3) / 0.5, 0.0, 1.0)))  # nauru
		if not _once.has("nauru"):
			_once["nauru"] = true
			Sfx.play("win_small", -12.0, 0.8)
	if _t < 3.9:
		# Vartijan silmin: kamera kirjeen normaalin suunnassa, kirje täyttää kuvan (teksti luettavissa).
		var eye := letter.global_position + letter.global_basis.z * 0.42
		_cam.look_at_from_position(eye, letter.global_position, letter.global_basis.y)
		_cam.fov = rad_to_deg(2.0 * atan(0.25 / 2.0 / 0.42))
	else:
		_fit(Vector3(6.05, 1.5, -2.85), [_head(guard) + Vector3(0, 0.25, 0), _head(me) + Vector3(0, 0.25, 0), letter.global_position,
			capsule.global_position + Vector3(0, -0.1, 0)], 1.25)
	_fill.position = Vector3(6.0, 1.9, -1.9)


func _step_radio() -> void:
	# Radiopuhelin suulle (0,4-1,0 s): "Portti kaikille!" (1,0) ja "LÖYTY!" (2,6); höyrypilli (3,4-6,0); kuski tulee
	# tieltä (5,0-8,0): "sata kertaa" (6,2) – "Ja nyt se on totta." (8,2).
	var up := _ease(clampf((_t - 0.4) / 0.6, 0.0, 1.0)) * (1.0 - _ease(clampf((_t - 7.6) / 0.5, 0.0, 1.0)))
	_hold_radio(guard, up)
	_hold_capsule(me, 1.0, 0.0)
	if _t > 1.0 and not _once.has("r1"):
		_once["r1"] = true
		_play(_crackle, -8.0, 1.0)
	if _t > 2.6 and not _once.has("r2"):
		_once["r2"] = true
		_play(_crackle, -8.0, 0.9)
	_bub[guard] = ""
	if _t > 1.0:
		_bub[guard] = "Portti kaikille! Peruskiven kapseli LÖYTY!" if _t < 2.6 else ("Toistan: LÖYTY!" if _t < 4.4 else "")
	if _t > 3.4 and not whistled:
		whistled = true
		_steam.restart()
		_steam.emitting = true
		_play(_whistle, -4.0, 1.0)
	if _t > 6.2:
		_steam.emitting = false
	if _t > 3.6:
		_story = "Hallin katolla höyrypilli viheltää. Päiväsaikaan." if _t < 6.4 else ""
		_look_up(me, 0.35 * _ease(clampf((_t - 3.6) / 0.6, 0.0, 1.0)) * (1.0 - _ease(clampf((_t - 6.0) / 0.6, 0.0, 1.0))))
		if _t < 6.0:
			_face(me, Vector3(WHISTLE.x, 0, WHISTLE.z))
		else:
			_face(me, kuski.position)
	var kk := clampf((_t - 5.0) / 3.0, 0.0, 1.0)
	if _t > 5.0:
		if kk < 1.0:
			if not _once.has("kuski_kavelee"):
				_once["kuski_kavelee"] = true
				kuski.play("Walk", 0.2)
			var kp := KUSKI_FROM.lerp(KUSKI_AT, kk)
			_stand(kuski, kp.x, kp.y)
			_face(kuski, Vector3(KUSKI_AT.x, 0, KUSKI_AT.y))
		else:
			if not _once.has("kuski_seis"):
				_once["kuski_seis"] = true
				kuski.play("Idle", 0.25)
			_face(kuski, guard.position)
	if _t > 6.2:
		_bub[kuski] = "Mää oon kuullu tän tarinan sata kertaa." if _t < 8.0 else ""
	if _t > 7.8:
		_face(guard, kuski.position)
	if _t > 8.2:
		_bub[guard] = "Ja nyt se on totta."
	if _t < 5.0:
		_fit(Vector3(6.9, 0.75, 2.4), [_head(guard) + Vector3(0, 0.3, 0), _head(me) + Vector3(0, 0.3, 0), _g(WHISTLE + Vector3(0, 2.6, 0)),
			_g(WHISTLE + Vector3(-1.0, 0, 0)), capsule.global_position + Vector3(0, -0.6, 0)], 1.08)
	else:
		_fit(Vector3(5.7, 1.6, 2.9), [_head(guard) + Vector3(0, 0.3, 0), _head(me) + Vector3(0, 0.3, 0), _head(kuski) + Vector3(0, 0.3, 0),
			_g(Vector3(KUSKI_AT.x, 0, KUSKI_AT.y)), capsule.global_position], 1.1)
	_fill.position = Vector3(6.4, 2.2, 1.0)


func _step_otsikko() -> void:
	# Kuski, vartija (kapseli ylhäällä) ja pelaaja kiven edessä; laatta ei peitä kiven kylttiä.
	var raise := _ease(clampf((_t - 0.5) / 0.7, 0.0, 1.0))
	var sh: Vector3 = guard.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	guard.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", sh + Vector3(s * 0.12, -0.35 + 0.75 * raise, -0.2 + 0.05 * raise),
		sh + Vector3(s * 0.45, -0.3, 0.2))
	capsule.global_position = hand(guard, "_r") + Vector3(0, 0.12, 0)
	capsule.global_basis = Basis()
	_fit(Vector3(5.55, 1.7, 3.2), [_g(Vector3(4.2, 1.45, -3.8)), _g(Vector3(6.8, 1.45, -3.8)), _head(kuski) + Vector3(0, 0.3, 0),
		_head(me) + Vector3(0, 0.3, 0), capsule.global_position + Vector3(0, 0.25, 0), _g(Vector3(5.5, 0, -2.0))], 1.15)
	_fill.position = Vector3(5.5, 2.4, -0.8)


# --- Esineet käsissä ----------------------------------------------------------------

## Kapselin akseli (globaali): hahmon vasemmalle, kansi vasemman käden puolella (vartija seisoo pelaajan vasemmalla
## ja vetää rullan avoimesta päästä).
func _axis(c: Node3D) -> Vector3:
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	return (c.global_basis.x * -s).normalized()


## Kanta, jonka +Y on dir (kapselin ja rullan akseli).
func _axis_basis(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Kapseli rinnan edessä vaakasuorassa: oikea käsi rungolla, vasen kannella; twist 0..1 kiertää kannen auki
## (irtoaa lopussa vasempaan käteen), tilt kallistaa avoimen pään alas (kolikko).
func _hold_capsule(c: Node3D, twist: float, tilt: float) -> void:
	var shr: Vector3 = c.bone_position("upperarm_r")
	var shl: Vector3 = c.bone_position("upperarm_l")
	var chest := (shr + shl) / 2.0
	var s := signf(shr.x) if shr.x != 0.0 else 1.0
	var center_l := chest + Vector3(0, -0.3 - 0.06 * tilt, -0.34)
	var ax := _axis(c)
	var dir := (ax + Vector3(0, -0.55 * tilt, 0)).normalized()
	capsule.global_position = c.to_global(center_l)
	capsule.global_basis = _axis_basis(dir)
	cap.visible = true
	var off := 0.0
	if twist >= 1.0:
		off = 0.12
	cap.rotation.y = twist * 4.0 * TAU / 4.0
	var cap_g := capsule.global_position + dir * (0.12 + off)
	if twist >= 1.0 and phase != "kapseli":
		cap.visible = false  # kansi taskussa
	elif twist >= 1.0:
		cap.global_position = hand(c, "_l") + dir * 0.02
	else:
		cap.position = Vector3(0, 0.12, 0)
	# Ranteet kauemmas kuin otekohta: sormet osoittavat kapselin keskustaan päin (käsi = ranne + sormet).
	var body_g := capsule.global_position - dir * 0.15
	var grip_l := cap_g + dir * 0.075
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", c.to_local(body_g) + Vector3(0, -0.04, 0.02), shr + Vector3(s * 0.45, -0.35, 0.15))
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", c.to_local(grip_l) + Vector3(0, -0.04, 0.02), shl + Vector3(-s * 0.45, -0.35, 0.15))


## Kirje kahdessa kädessä rinnan edessä, etupinta lukijaan päin; lower laskee kirjettä (lukemisen jälkeen).
func _hold_letter(c: Node3D, lower: float) -> void:
	letter.visible = true
	var shr: Vector3 = c.bone_position("upperarm_r")
	var shl: Vector3 = c.bone_position("upperarm_l")
	var chest := (shr + shl) / 2.0
	var s := signf(shr.x) if shr.x != 0.0 else 1.0
	var dy := -0.2 - 0.22 * lower
	var dz := -0.36 + 0.08 * lower
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", chest + Vector3(s * 0.15, dy - 0.1, dz + 0.03), shr + Vector3(s * 0.45, -0.35, 0.15))
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", chest + Vector3(-s * 0.15, dy - 0.1, dz + 0.03), shl + Vector3(-s * 0.45, -0.35, 0.15))
	letter.global_position = c.to_global(chest + Vector3(0, dy + 0.03, dz - 0.015))
	letter.global_basis = c.global_basis * Basis(Vector3.RIGHT, -0.35 - 0.6 * lower)


## Radiopuhelin oikeassa kädessä suun edessä (up 1) tai rinnan alla (up 0).
func _hold_radio(c: Node3D, up: float) -> void:
	radio.visible = true
	var sh: Vector3 = c.bone_position("upperarm_r")
	var head: Vector3 = c.bone_position("Head")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var low := sh + Vector3(s * 0.12, -0.42, -0.12)
	var mouth := head + Vector3(s * 0.06, -0.14, -0.16)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", low.lerp(mouth, up), sh + Vector3(s * 0.45, -0.4, 0.1))
	radio.global_position = hand(c, "_r") + Vector3(0, 0.06, 0)
	radio.global_basis = c.global_basis * Basis(Vector3.UP, PI)


func _step_coin(delta: float) -> void:
	if _coin_t < 0.0:
		return
	_coin_t += delta
	var k := clampf(_coin_t / 0.45, 0.0, 1.0)
	var p := _coin_from.lerp(_coin_at, k)
	p.y = lerpf(_coin_from.y, _coin_at.y, k * k)
	if k >= 1.0:
		var b := _coin_t - 0.45  # pomppu ja pyörähdys kyljellään
		p = _coin_at + Vector3(0, absf(sin(b * 14.0)) * 0.03 * maxf(0.0, 1.0 - b * 2.5), 0)
		if not _once.has("kilahdus"):
			_once["kilahdus"] = true
			Sfx.play("coin", -3.0, 0.9)
		if b > 0.6:
			_coin_t = -1.0
			_place_coin_ground()
			return
	coin.global_position = p
	coin.rotation = Vector3(_coin_t * 9.0, 0.0, _coin_t * 5.0)


func _place_coin_ground() -> void:
	coin.global_position = _g(Vector3(6.75, 0.035, -0.95))
	coin.rotation = Vector3(0, 0.4, 0)


# --- Apufunktiot --------------------------------------------------------------------

func _g(v: Vector3) -> Vector3:
	return interior.to_global(v)


func _head(c: Node3D) -> Vector3:
	return c.to_global(c.bone_position("Head"))


func hand(c: Node3D, lr := "_r") -> Vector3:
	return c.to_global((c.bone_position("hand" + lr) + c.bone_position("index_01" + lr)) / 2.0)


## Kamera pisteestä eye (paikallinen) niin, että kaikki pisteet (globaalit) mahtuvat kuvaan (hanhikivi_kohtaus.gd _fit).
func _fit(eye: Vector3, pts: Array, pad := 1.1) -> void:
	var ge := interior.to_global(eye)
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	_cam.look_at_from_position(ge, c)
	var vs := get_viewport().get_visible_rect().size
	var asp := vs.x / vs.y
	var inv := _cam.global_transform.basis.inverse()
	var need := 0.0
	for p in pts:
		var l: Vector3 = inv * ((p as Vector3) - ge)
		var z := maxf(-l.z, 0.1)
		need = maxf(need, maxf(atan(absf(l.y) / z), atan(absf(l.x) / z / asp)))
	_cam.fov = clampf(rad_to_deg(2.0 * need) * pad, 8.0, 90.0)


## Käsi kohti pistettä (w 0..1); lean kumartaa selkää samassa suhteessa.
func _reach(c: Node3D, at: Vector3, w: float, lean := 0.0, lr := "_r") -> void:
	if lean != 0.0 or lr == "_r":
		_lean(c, lean)
	var sh: Vector3 = c.bone_position("upperarm" + lr)
	var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
	var rest := sh + Vector3(s * 0.12, -0.42, -0.08)
	var tgt := rest.lerp(c.to_local(at), w)
	c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, tgt, sh + Vector3(s * 0.45, -0.25, 0.25))


## Kumarrus koko selällä (rad yhteensä), niska kompensoi katseen.
func _lean(c: Node3D, a: float) -> void:
	c.set_override("spine_01", Vector3.RIGHT, -a * 0.45)
	c.set_override("spine_02", Vector3.RIGHT, -a * 0.35)
	c.set_override("spine_03", Vector3.RIGHT, -a * 0.2)
	c.set_override("neck_01", Vector3.RIGHT, a * 0.35)


func _look_up(c: Node3D, a: float) -> void:
	c.set_override("neck_01", Vector3.RIGHT, a * 0.55)
	c.set_override("Head", Vector3.RIGHT, a * 0.45)


func _stand(c: Node3D, x: float, z: float) -> void:
	c.position = Vector3(x, 0, z)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


# --- Ääni ---------------------------------------------------------------------------

func _play(w: AudioStreamWAV, db: float, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = w
	p.volume_db = db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	p.play()


## Höyrypilli: kaksi hieman riitasointuista siniääntä (n. 300 ja 378 Hz) ja höyryn kohina, pehmeä alku ja loppu.
func _whistle_wav() -> AudioStreamWAV:
	var dur := 2.6
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var env := minf(1.0, t * 5.0) * minf(1.0, (dur - t) * 2.5)
		var wob := 1.0 + 0.004 * sin(t * 31.0)
		var tone := sin(TAU * 300.0 * wob * t) * 0.5 + sin(TAU * 378.0 * wob * t) * 0.4 + sin(TAU * 600.0 * t) * 0.12
		lp = lp * 0.7 + (randf() * 2.0 - 1.0) * 0.3
		s[i] = (tone * 0.7 + lp * 0.35) * env * 0.6
	return _wav(s)


## Radiopuhelimen rätinä: suodatettua kohinaa katkoina ja lopun "piip".
func _crackle_wav() -> AudioStreamWAV:
	var dur := 0.7
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	var st := [0.0, 0.0]
	for i in s.size():
		var t := float(i) / RATE
		var gate := 1.0 if fposmod(t * 23.0, 1.0) < 0.7 else 0.25
		var x := (randf() * 2.0 - 1.0) * gate
		var y := _reso(x, 1800.0, 0.9, st)
		var beep := sin(TAU * 1400.0 * t) * 0.3 if t > 0.58 else 0.0
		s[i] = (y * 0.35 + beep) * minf(1.0, (dur - t) * 20.0)
	return _wav(s)


func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.data = data
	return w


func _reso(x: float, f: float, r: float, st: Array) -> float:
	var c := 2.0 * r * cos(TAU * f / RATE)
	var y := (1.0 - r) * x + c * float(st[0]) - r * r * float(st[1])
	st[1] = st[0]
	st[0] = y
	return y * 4.0


# --- Piirto -------------------------------------------------------------------------

func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 460, 24, 920, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for c: Node3D in _bub:
		if is_instance_valid(c) and c.visible and _bub[c] != "":
			Room.bubble(_ui, _cam, c, _bub[c], 90.0, 120.0)
	if phase == "otsikko":
		var a := clampf((_t - 0.9) / 0.9, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.05, 0.06, 0.22 * a))
		var y := vs.y * 0.17
		_draw_capsule_icon(Vector2(vs.x / 2.0, y - 70.0), a)
		var title := "PERUSKIVEN KAPSELI"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.05, 0.08, 0.1, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(1.0, 0.84, 0.42, a))
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 158.0, 840, 84)
		_ui.draw_rect(sr, Color(0.03, 0.05, 0.06, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Rojuniemi: kapseli oli laatan alla, ja kirje tunsi vartijan",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.95, 0.8, 0.5, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Sanotaan, että vartija kertoi tarinan kerran liikaa.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Kuparikapseli otsikon yllä: vaakasuora putki, kierrekansi pykälineen ja patinaläikkä.
func _draw_capsule_icon(c: Vector2, a: float) -> void:
	var dark := Color(0.05, 0.08, 0.1, a)
	var body := Rect2(c + Vector2(-46, -14), Vector2(78, 28))
	_ui.draw_rect(body, Color(0.78, 0.48, 0.28, a))
	_ui.draw_rect(Rect2(body.position, Vector2(78, 8)), Color(0.9, 0.62, 0.4, a))
	_ui.draw_circle(c + Vector2(-20, 4), 6.0, Color(0.45, 0.66, 0.55, a))
	_ui.draw_rect(body, dark, false, 2.5)
	var capr := Rect2(c + Vector2(32, -17), Vector2(16, 34))
	_ui.draw_rect(capr, Color(0.66, 0.4, 0.22, a))
	for k in 4:
		_ui.draw_line(capr.position + Vector2(4 + k * 3, 2), capr.position + Vector2(4 + k * 3, 32), dark, 1.2)
	_ui.draw_rect(capr, dark, false, 2.5)
