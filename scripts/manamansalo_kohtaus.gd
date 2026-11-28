extends CanvasLayer
## Legendaarinen hetki "manamansalon_kirkko" (Manamansalon kivijalka): kun kivijalkaa tutkitaan ensimmäistä kertaa
## molempien vihjeiden jälkeen (main.gd _manamansalo_acted "jaanteet"), hetki lavastetaan Manamansalon hautausmaan mäellä
## (retki_manamansalo.gd, taskukohtaus). Legendan ydin: kivijalalla paloi kynttilä, ensimmäinen kirkko seisoi tässä
## (sanotaan), ja nimestä saa kiistellä. Vaiheet:
##   kynttila  pelaaja kyykistyy itäpäädyn alttarikiven luo, laskee kynttilän kivelle ja sytyttää sen tikulla.
##             Opas on nähnyt valon kirkolta ja tulee polkua lyhtykori kädessä.
##   kulmat    opas: "Jos kirkko oli tässä, alttari oli tuossa päässä." Opas kiertää kivijalan ja panee hautalyhdyn
##             kolmeen nurkkakiveen, pelaaja neljänteen. Kivijalan muoto piirtyy valoina.
##   kirkko    (huipennus) lyhtyjen välissä nousee hetkeksi kultainen hirsikirkko hirsi hirreltä: salvotut nurkat,
##             harjakatto ja risti päädyssä. Hiljainen soinnun humina. Opas laskee käden rinnalle. Kirkko haalistuu.
##   nimi      taksikuski tulee tieltä: "Näittekö te tuon?" – "Mitä?" – "...Ei mitään. Kuolemansaari tämä on."
##             Opas: toiset sanoo, että nimi on ihan muuta; kuskin mummo tiesi muttei kertonut. "Siitä saa kiistellä."
##   otsikko   MANAMANSALON KIVIJALKA: kolme kivijalan edessä, kynttilä ja lyhdyt palavat, Oulujärvi takana.
## Kehys: retki_manamansalo.gd:n paikallinen kehys: -Z Oulujärvi, +Z tie ja taksi, maa y 0 (kivijalan kumpu y 0,10,
## hautojen nurmilaatat y 0,04). Hahmojen etu -Z (Looks). Oikea pelaaja, opas ja kuski piiloon kohtauksen ajaksi (kopiot
## näyttelevät); retki_manamansalo.staged pitää kynttilän ja lyhdyt kohtauksen hallussa. Kynttilä ja lyhdyt jäävät
## palamaan, ja opas muistelee (MUISTO). Kirkon "näkeminen" jätetään auki: kukaan ei sano näkeneensä mitään varmaa.

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Room := preload("res://scripts/ilta_room.gd")
const Retki := preload("res://scripts/retki_manamansalo.gd")

const RATE := 22050.0
const DUR := {"kynttila": 9.5, "kulmat": 10.5, "kirkko": 10.5, "nimi": 12.5, "otsikko": 6.5}
const ORDER := ["kynttila", "kulmat", "kirkko", "nimi", "otsikko"]

const ME_ALTAR := Vector2(11.22, -2.2)  # itäpäädyn ulkopuolella, kasvot alttarikiveen (-X)
const ME_SE := Vector2(11.0, -0.62)  # kaakkoiskulman lyhdyn luona
const OPAS_FROM := Vector2(3.6, 2.4)  # kirkon polulta
const OPAS_AT := Vector2(6.4, 0.25)
## Oppaan kierros: [paikka, lyhdyn indeksi (-1 = ohikulku)]. Reitti kiertää kivirivin ja hautojen kivet.
const OPAS_ROUTE := [[Vector2(7.05, -0.62), 0], [Vector2(6.85, -2.2), -1], [Vector2(7.2, -3.88), 1], [Vector2(10.6, -4.0), 2]]
const KUSKI_FROM := Vector2(2.6, 2.4)
const KUSKI_AT := Vector2(7.55, 0.3)
const SPEED := 1.7  # oppaan kävelyvauhti m/s
const PLACE := 1.05  # lyhdyn lasku (kyykky, s)
const WALL := Rect2(7.5, -3.3, 3.0, 2.2)  # haamukirkon seinälinja kivirivin päällä (x, z)
const WALL_H := 2.0
const LOG_H := 0.25
const ROOF_RISE := 1.15
## Opas muistelee hetkeä myöhemmin (main.gd _manamansalo_acted "opas").
const MUISTO := ["Muistatko lyhdyt nurkissa? Ne palaa vieläkin. Joku käy vaihtamassa kynttilät. En tiedä kuka.",
	"Kuski ei vieläkään kerro, mitä se näki sinä päivänä. Minä en kysy.",
	"Kuolemansaari, Manalan saari, jonkun metsästäjän nimi... Joka kesä tulee uusi tulkinta. Hyvä niin.",
	"Sinä panit kynttilän alttarikivelle. Sanotaan, että siinä se kirkko seisoi. Minä ainakin uskon."]

var interior: Node3D  # retki_manamansalo.gd
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
var opas: Node3D
var kuski: Node3D
var candle: Node3D
var match_stick: Node3D
var lanterns: Array[Node3D] = []
var church: Node3D
var _logs: Array = []  # [korkeus 0..1, Node3D] haamukirkon osat nousujärjestyksessä
var _ghost_mat: StandardMaterial3D
var _fill_mat: StandardMaterial3D
var _motes: CPUParticles3D
var _fill: OmniLight3D
var _hum: AudioStreamWAV
var _hum_player: AudioStreamPlayer
var lit := false  # testi lukee
var placed := [false, false, false, false]
var ghost := 0.0  # haamukirkon nousu 0..1
var ghost_alpha := 0.0


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
	_hum = _hum_wav()
	for nd in [interior.walker, interior._guide, interior.kuski]:
		if nd != null:
			_was_visible[nd] = (nd as Node3D).visible
			(nd as Node3D).visible = false
	interior._bubble.text = ""
	interior.staged = true
	interior._candle.visible = false
	for l in interior.lanterns:
		l.visible = false
	_build()
	_begin("kynttila")


# --- Lavastus -----------------------------------------------------------------------

func _build() -> void:
	me = Looks.make(interior, Looks.player())
	Looks.add_cap(me)
	opas = Looks.make(interior, Retki.GUIDE_LOOK)
	kuski = Looks.make(interior, Looks.TAXI_DRIVER)
	for c in [me, opas, kuski]:
		_props.append(c)
	candle = Retki.build_candle(interior)
	_props.append(candle)
	_set_flame(candle, 0.0)
	for i in 4:
		var l := Retki.build_lantern(interior)
		_props.append(l)
		_set_flame(l, 0.0)
		l.visible = false
		lanterns.append(l)
	match_stick = _build_match()
	church = _build_church()
	_motes = _particles()
	interior.add_child(_motes)
	_props.append(_motes)
	_motes.position = Vector3(WALL.position.x + WALL.size.x / 2.0, 0.3, WALL.position.y + WALL.size.y / 2.0)
	_fill = OmniLight3D.new()
	interior.add_child(_fill)
	_props.append(_fill)
	_fill.light_color = Color(1.0, 0.92, 0.8)
	_fill.light_energy = 0.7
	_fill.omni_range = 6.0


## Tulitikku: puutikku, punainen pää ja liekki ("flame"-metatieto); pituusakseli +Y.
func _build_match() -> Node3D:
	var m := Node3D.new()
	interior.add_child(m)
	_props.append(m)
	B.mesh(m, B.boxm(Vector3(0.005, 0.09, 0.005)), Vector3(0, 0.045, 0), Color(0.86, 0.74, 0.5))
	B.mesh(m, B.sphere(0.006, 6), Vector3(0, 0.092, 0), Color(0.7, 0.12, 0.08))
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.5, 0.12)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.45, 0.1)
	fm.emission_energy_multiplier = 3.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var f := B.mesh(m, B.sphere(0.011, 8), Vector3(0, 0.106, 0), Color.WHITE)
	f.scale = Vector3(1.0, 1.9, 1.0)
	f.material_override = fm
	var ml := OmniLight3D.new()
	ml.position = Vector3(0, 0.11, 0)
	ml.light_color = Color(1.0, 0.7, 0.35)
	ml.light_energy = 0.0
	ml.omni_range = 1.5
	m.add_child(ml)
	m.set_meta("flame", f)
	m.set_meta("light", ml)
	f.visible = false
	m.visible = false
	return m


## Haamukirkko: kullanhohtoiset hirsilinjat kivirivin päällä. Seinät hirsikerroksina (LOG_H) ja salvotut nurkat (hirren
## päät 0,14 m nurkan yli), harjakatto (räystäät, harja, kattoruoteet; päätyjen ruoteet piirtävät päätykolmion), ovi länsipäädyssä
## ja risti länsipäädyn harjalla. Osat nousevat korkeusjärjestyksessä (_logs), ja yksi materiaali haalistaa kaiken.
func _build_church() -> Node3D:
	var c := Node3D.new()
	interior.add_child(c)
	_props.append(c)
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(1.0, 0.86, 0.5, 0.0)
	_ghost_mat.emission_enabled = true
	_ghost_mat.emission = Color(1.0, 0.78, 0.38)
	_ghost_mat.emission_energy_multiplier = 2.2
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fill_mat = _ghost_mat.duplicate()
	_fill_mat.emission_energy_multiplier = 0.6
	var x0 := WALL.position.x
	var x1 := WALL.position.x + WALL.size.x
	var z0 := WALL.position.y
	var z1 := WALL.position.y + WALL.size.y
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	var base := 0.32  # kivirivin yläpinta
	var t := 0.045
	var over := 0.14
	var n := int(WALL_H / LOG_H)
	for k in n:
		var y := base + (k + 0.5) * LOG_H
		var lv := Node3D.new()
		c.add_child(lv)
		_bar(lv, Vector3(cx, y, z0), Vector3(x1 - x0 + 2.0 * over, t, t))
		_bar(lv, Vector3(cx, y, z1), Vector3(x1 - x0 + 2.0 * over, t, t))
		var door := k < 6
		for ex in [x0, x1]:
			var yz := y
			if ex == x0 and door:
				# Ovi länsipäädyssä: hirret katkeavat oviaukon kohdalla (aukko 0,8 m).
				_bar(lv, Vector3(ex, yz, (z0 + cz - 0.4) / 2.0), Vector3(t, t, (cz - 0.4) - z0 + over))
				_bar(lv, Vector3(ex, yz, (z1 + cz + 0.4) / 2.0), Vector3(t, t, z1 - (cz + 0.4) + over))
			else:
				_bar(lv, Vector3(ex, yz, cz), Vector3(t, t, z1 - z0 + 2.0 * over))
		_logs.append([float(k) / (n + 2), lv])
	# Oven karmit ja ylähirsi.
	var dr := Node3D.new()
	c.add_child(dr)
	for s in [-0.4, 0.4]:
		_bar(dr, Vector3(x0, base + 0.75, cz + s), Vector3(t * 1.4, 1.5, t * 1.4))
	_bar(dr, Vector3(x0, base + 1.5, cz), Vector3(t * 1.4, t * 1.4, 0.86))
	_logs.append([0.15, dr])
	var top := base + WALL_H
	var half := (z1 - z0) / 2.0
	# Harjakatto: räystäslinjat, harja ja ruoteet (lappeen kulma yhdestä luvusta).
	var roof := Node3D.new()
	c.add_child(roof)
	var a := atan2(ROOF_RISE, half)
	var slope := Vector2(half + 0.25, 0.0).length() / cos(a)
	var rl := (x1 - x0) + 0.5
	for s in [-1.0, 1.0]:
		var eave := Vector3(cx, top - 0.25 * tan(a), cz + s * (half + 0.25))
		_bar(roof, eave, Vector3(rl, t, t))
		var xr := x0 - 0.2
		while xr <= x1 + 0.21:
			var mid := Vector3(xr, top + (ROOF_RISE - 0.25 * tan(a)) / 2.0, cz + s * (half + 0.25) / 2.0)
			var bar := _bar(roof, mid, Vector3(t, t, slope))
			bar.rotation.x = s * a
			xr += 0.5
	_bar(roof, Vector3(cx, top + ROOF_RISE, cz), Vector3(rl, t * 1.3, t * 1.3))
	_logs.append([0.86, roof])
	# Risti länsipäädyn harjalla.
	var cr := Node3D.new()
	c.add_child(cr)
	_bar(cr, Vector3(x0 - 0.05, top + ROOF_RISE + 0.38, cz), Vector3(t * 1.6, 0.76, t * 1.6))
	_bar(cr, Vector3(x0 - 0.05, top + ROOF_RISE + 0.52, cz), Vector3(t * 1.6, t * 1.6, 0.4))
	_logs.append([0.97, cr])
	# Himmeät seinäpinnat antavat kirkolle tilavuuden (näkyvät vasta, kun seinät ovat ylhäällä).
	var fill := Node3D.new()
	c.add_child(fill)
	for p in [[Vector3(cx, base + WALL_H / 2.0, z0), Vector3(x1 - x0, WALL_H, 0.01)], [Vector3(cx, base + WALL_H / 2.0, z1), Vector3(x1 - x0, WALL_H, 0.01)],
			[Vector3(x1, base + WALL_H / 2.0, cz), Vector3(0.01, WALL_H, z1 - z0)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[1]
		mi.mesh = bm
		mi.position = p[0]
		mi.material_override = _fill_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fill.add_child(mi)
	_logs.append([0.72, fill])
	for e in _logs:
		(e[1] as Node3D).visible = false
	return c


func _bar(parent: Node3D, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _ghost_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Kultaiset hiukkaset, jotka nousevat kivirivistä kirkon noustessa (pehmeät kameraan kääntyvät täplät).
func _particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.45, 0.9)
	m.albedo_texture = _soft_tex()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	p.mesh = q
	p.amount = 90
	p.lifetime = 2.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(WALL.size.x / 2.0, 0.05, WALL.size.y / 2.0)
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, 0.05, 0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.emitting = false
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


## Liekin koko ja valo 0..1 (kynttilä, lyhty, tikku); lepatus lisätään päälle.
func _set_flame(n: Node3D, k: float) -> void:
	var f: Node3D = n.get_meta("flame")
	var l: OmniLight3D = n.get_meta("light")
	f.visible = k > 0.02
	var fl := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.023 + n.get_instance_id() % 7) * k
	f.scale = Vector3(1.0, 2.0 * fl, 1.0) * maxf(k, 0.02)
	l.light_energy = 1.1 * k * fl


# --- Vaiheet ------------------------------------------------------------------------

func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	for c in [me, opas, kuski]:
		c.clear_ik()
		_lean(c, 0.0)
		_look_up(c, 0.0)
		Room.nod(c, 0.0)
	kuski.visible = p == "nimi" or p == "otsikko"
	match p:
		"kynttila":
			_story = ""
			_stand(me, ME_ALTAR.x, ME_ALTAR.y)
			_face(me, Vector3(Retki.ALTAR.x, 0, ME_ALTAR.y))
			me.play("Crouch_Idle", 0.0)
			_stand(opas, OPAS_FROM.x, OPAS_FROM.y)
			opas.play("Idle", 0.0)
			opas.visible = false
		"kulmat":
			_story = ""
			_place_candle()
			_set_flame(candle, 1.0)
			match_stick.visible = false
			opas.visible = true
			_stand(opas, OPAS_AT.x, OPAS_AT.y)
			_face(opas, Vector3(Retki.ALTAR.x, 0, Retki.ALTAR.z))
			opas.play("Idle", 0.2)
			_stand(me, ME_ALTAR.x - 0.05, ME_ALTAR.y + 0.45)
			_face(me, opas.position)
			me.play("Idle", 0.2)
			for i in 4:
				lanterns[i].visible = false
		"kirkko":
			_story = ""
			_place_candle()
			for i in 4:
				_put_lantern(i)
			_stand(me, 8.55, 0.05)
			_stand(opas, 9.55, 0.0)
			for c in [me, opas]:
				_face(c, Vector3(c.position.x, 0, -2.2))
				c.play("Idle", 0.2)
			ghost = 0.0
		"nimi":
			_story = ""
			_ghost_off()
			_stand(me, 8.55, 0.05)
			_stand(opas, 9.55, 0.0)
			_face(me, Vector3(8.55, 0, -2.2))
			_face(opas, Vector3(9.55, 0, -2.2))
			_stand(kuski, KUSKI_FROM.x, KUSKI_FROM.y)
			kuski.play("Idle", 0.0)
		"otsikko":
			_story = ""
			_ghost_off()
			_stand(me, 7.3, -0.3)
			_stand(opas, 8.55, -0.15)
			_stand(kuski, 9.8, -0.2)
			for c in [me, opas, kuski]:
				c.play("Idle", 0.2)
				_face(c, Vector3(8.8, 0, 5.0))
			Sfx.play("win", -7.0, 0.92)


func _process(delta: float) -> void:
	_t += delta
	# Kohtaus alkaa kivijalan E-painalluksesta: sama painallus ei saa ohittaa sitä heti.
	if Input.is_action_just_pressed("interact") and (phase != "kynttila" or _t > 0.5):
		if phase != "otsikko":
			_begin("otsikko")
			lit = true
			_place_candle()
			for i in 4:
				_put_lantern(i)
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"kynttila":
			_step_kynttila()
		"kulmat":
			_step_kulmat()
		"kirkko":
			_step_kirkko()
		"nimi":
			_step_nimi()
		"otsikko":
			_step_otsikko()
	if lit and phase != "kynttila":
		_set_flame(candle, 1.0)
	for i in 4:
		if placed[i]:
			_set_flame(lanterns[i], 1.0)
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
	interior.staged = false  # _process näyttää kynttilän ja lyhdyt (legenda.found)
	if is_instance_valid(_hum_player):
		_hum_player.stop()
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	for nd in _was_visible:
		if is_instance_valid(nd):
			(nd as Node3D).visible = _was_visible[nd]
	finished.emit()
	queue_free()


func _step_kynttila() -> void:
	# Kynttilä kädessä (0-0,6 s), kivelle (0,6-1,8); tikku esiin (2,2), raapaisu ja leimahdus (2,7); tikku sydämelle
	# (3,1-4,0), kynttilä syttyy (4,0); tikku sammutetaan (4,8) ja pelaaja nousee (5,6). Opas tulee polkua (5,4-9,5).
	var rest := me.to_global(me.bone_position("upperarm_r") + Vector3(0, -0.35, -0.3))
	var cand := _g(Retki.CANDLE_AT)
	if _t < 1.8:
		var k := _ease(clampf((_t - 0.4) / 1.2, 0.0, 1.0))
		_reach(me, rest.lerp(cand + Vector3(0, 0.12, 0), k), 1.0, 0.25 * k, "_r")
		candle.global_position = hand(me, "_r") + Vector3(0, -0.12, 0)
		candle.global_basis = Basis()
		if k >= 1.0:
			_place_candle()
	else:
		_place_candle()
		if not _once.has("kivelle"):
			_once["kivelle"] = true
			Sfx.play("pickup", -9.0, 0.7)
	if _t >= 1.8 and _t < 5.4:
		var wick := _g(Retki.CANDLE_AT + Vector3(0, 0.29, 0))
		var strike := _ease(clampf((_t - 2.0) / 0.5, 0.0, 1.0))
		var to_wick := _ease(clampf((_t - 3.1) / 0.9, 0.0, 1.0)) * (1.0 - _ease(clampf((_t - 4.6) / 0.6, 0.0, 1.0)))
		var near := me.to_global(me.bone_position("upperarm_r") + Vector3(0.05, -0.3, -0.32))
		var tgt := near.lerp(wick + (me.global_position - wick).normalized() * Vector3(1, 0, 1) * 0.13 + Vector3(0, 0.03, 0), to_wick)
		_reach(me, tgt, maxf(strike, 0.6), 0.25, "_r")
		match_stick.visible = _t > 2.1 and _t < 5.0
		# Tikku sormista eteenpäin: pää osoittaa ylös-eteen ja sytyttäessä kynttilän sydäntä kohti.
		var hp := hand(me, "_r")
		var fwd := me.global_basis.z * -1.0
		var dir := (fwd * 0.6 + Vector3.UP * 0.8).normalized().lerp((wick - hp).normalized(), to_wick).normalized()
		match_stick.global_basis = _axis_basis(dir)
		match_stick.global_position = hp + dir * 0.03
		var mf := clampf((_t - 2.7) / 0.15, 0.0, 1.0) * (1.0 - clampf((_t - 4.8) / 0.15, 0.0, 1.0))
		(match_stick.get_meta("flame") as Node3D).visible = mf > 0.05
		(match_stick.get_meta("flame") as Node3D).scale = Vector3(1.0, 1.9, 1.0) * maxf(mf * (1.3 - 0.3 * clampf((_t - 2.7) / 0.4, 0.0, 1.0)), 0.02)
		(match_stick.get_meta("light") as OmniLight3D).light_energy = 0.9 * mf
		if _t > 2.7 and not _once.has("raapaisu"):
			_once["raapaisu"] = true
			Sfx.play("fire", -6.0, 1.6)
	if _t > 4.0:
		if not lit:
			lit = true
			Sfx.play("fire", -12.0, 1.1)
		_set_flame(candle, _ease(clampf((_t - 4.0) / 0.8, 0.0, 1.0)))
	else:
		_set_flame(candle, 0.0)
	if _t > 5.6 and not _once.has("ylos"):
		_once["ylos"] = true
		me.clear_ik()
		_lean(me, 0.0)
		me.play("Idle", 0.4)
	if _t > 0.6:
		_story = "Itäpäädyn kivi on laakea kuin alttari." if _t < 3.0 else ("" if _t < 4.2 else "Kynttilä palaa kivijalalla, jonka sanotaan olleen Kainuun ensimmäisen kirkon.")
	# Opas on nähnyt valon kirkolta ja tulee polkua lyhty kädessä.
	var ok := clampf((_t - 5.4) / 3.6, 0.0, 1.0)
	if _t > 5.4:
		opas.visible = true
		if ok < 1.0:
			if not _once.has("opas_kavelee"):
				_once["opas_kavelee"] = true
				opas.play("Walk", 0.2)
			var op := OPAS_FROM.lerp(OPAS_AT, ok)
			_stand(opas, op.x, op.y)
			_face(opas, Vector3(OPAS_AT.x, 0, OPAS_AT.y))
		else:
			if not _once.has("opas_perilla"):
				_once["opas_perilla"] = true
				opas.play("Idle", 0.25)
			_face(opas, candle.position)
		_carry(opas, lanterns[0])
	if _t > 7.6:
		_bub[opas] = "Näin valon kirkolta asti."
	if _t < 5.4:
		_fit(Vector3(11.75, 0.85, -0.55), [cand + Vector3(0, -0.1, 0), cand + Vector3(0, 0.45, 0), _head(me) + Vector3(0, 0.22, 0),
			_g(Vector3(Retki.ALTAR.x - 0.35, 0.0, -2.75)), _g(Vector3(Retki.ALTAR.x - 0.3, 0.0, -1.6))], 1.1)
	else:
		_fit(Vector3(12.6, 2.0, 3.0), [cand, _head(me) + Vector3(0, 0.3, 0), _head(opas) + Vector3(0, 0.3, 0),
			_g(Vector3(OPAS_FROM.x + 1.5, 0, OPAS_FROM.y)), _g(Vector3(7.4, 0, -3.3))], 1.06)
	_fill.position = Vector3(11.8, 1.4, -1.0)


func _step_kulmat() -> void:
	# Opas: "Jos kirkko oli tässä, alttari oli tuossa päässä." (0,2-2,6 s); kierros kolmeen nurkkaan (1,2-); pelaaja panee
	# kaakkoisnurkan lyhdyn (2,6-5,6). Kivijalan muoto piirtyy valoina.
	if _t > 0.2:
		_bub[opas] = "Jos kirkko oli tässä, alttari oli tuossa päässä." if _t < 2.6 else ""
	if _t > 2.7:
		_bub[opas] = "Ota sinä tuo yksi." if _t < 4.0 else ""
	if _t < 1.2:
		_face(opas, Vector3(Retki.ALTAR.x, 0, Retki.ALTAR.z))
		_carry(opas, lanterns[0])
	else:
		_walk_route(_t - 1.2)
	# Pelaaja: kaakkoisnurkka.
	var mk := clampf((_t - 2.6) / 1.0, 0.0, 1.0)
	var from := Vector2(ME_ALTAR.x - 0.05, ME_ALTAR.y + 0.45)
	if _t < 2.6:
		_face(me, opas.position)
	elif mk < 1.0:
		if not _once.has("me_kavelee"):
			_once["me_kavelee"] = true
			me.play("Walk", 0.2)
		var mp := from.lerp(ME_SE, mk)
		_stand(me, mp.x, mp.y)
		_face(me, Vector3(ME_SE.x, 0, ME_SE.y))
		_carry(me, lanterns[3])
	else:
		_place_step(me, 3, _t - 3.6)
	if _t < 2.6 and _t > 2.0:
		_carry(me, lanterns[3])
	var lp: Array = interior.LANTERNS
	_story = "Opas kiertää kivijalan ja panee hautalyhdyn nurkkakiville." if _t > 3.0 else ""
	if placed.count(true) >= 3:
		_story = "Kivijalan muoto piirtyy valoina. Ei tämä iso kirkko ollut."
	_fit(Vector3(9.0, 4.6, 4.6), [_g(Vector3(lp[0].x, 0, lp[0].z)), _g(Vector3(lp[1].x, 0.3, lp[1].z)), _g(Vector3(lp[2].x, 0.3, lp[2].z)),
		_g(Vector3(lp[3].x + 0.6, 0, lp[3].z + 0.6)), _head(opas) + Vector3(0, 0.3, 0), _head(me) + Vector3(0, 0.3, 0), _g(Vector3(6.4, 0, 0.6))], 1.05)
	_fill.position = Vector3(9.0, 2.0, 0.6)


func _step_kirkko() -> void:
	# Huipennus: humina (0,6 s); hirret nousevat (1,0-5,2), katto ja risti (5,2-6,0); opas laskee käden rinnalle (6,2);
	# pysähdys; kirkko haalistuu (8,2-10,2).
	if _t > 0.6 and not _once.has("hum"):
		_once["hum"] = true
		_hum_player = _play(_hum, -9.0, 1.0)
		_motes.emitting = true
	ghost = _ease(clampf((_t - 1.0) / 5.0, 0.0, 1.0))
	ghost_alpha = clampf((_t - 0.9) / 0.4, 0.0, 1.0) * (1.0 - _ease(clampf((_t - 8.2) / 2.0, 0.0, 1.0)))
	_apply_ghost()
	if _t > 7.6:
		_motes.emitting = false
	if _t > 5.9 and not _once.has("risti"):
		_once["risti"] = true
		Sfx.play("glass", -16.0, 0.6)
	# Katse ylös kirkon noustessa; opas laskee kämmenen rinnalle.
	var up := _ease(clampf((_t - 2.0) / 1.2, 0.0, 1.0)) * (1.0 - _ease(clampf((_t - 8.6) / 1.0, 0.0, 1.0)))
	_look_up(me, 0.45 * up)
	_look_up(opas, 0.3 * up)
	if _t > 6.2:
		_hand_on_chest(opas, _ease(clampf((_t - 6.2) / 0.8, 0.0, 1.0)))
	if _t > 1.6:
		_story = "Lyhtyjen välissä sen melkein näkee." if _t < 5.8 else "Pieni hirsikirkko. Sanotaan, että 1559."
	if _t > 9.0:
		_story = ""
	# Kamera väen takaa ja yläviistosta: koko kirkko ja kaksi selkää; hidas lähestyminen.
	var push := _ease(clampf(_t / DUR.kirkko, 0.0, 1.0))
	var eye := Vector3(9.0, 3.0 - 0.4 * push, 5.6 - 0.8 * push)
	var top := 0.32 + WALL_H + ROOF_RISE + 1.3
	_fit(eye, [_g(Vector3(WALL.position.x - 0.3, 0.0, WALL.position.y + WALL.size.y)), _g(Vector3(WALL.position.x + WALL.size.x + 0.3, 0.0, WALL.position.y + WALL.size.y)),
		_g(Vector3(WALL.position.x, top, -2.2)), _g(Vector3(WALL.position.x + WALL.size.x, top - 1.3, -2.2)), _head(me), _head(opas)], 1.06)
	_fill.position = Vector3(9.0, 1.6, 1.0)


func _step_nimi() -> void:
	# Kuski tulee tieltä (0-3,4 s). Repliikit vuorotellen; nimestä kiistellään (3,7-12).
	var kk := clampf(_t / 3.4, 0.0, 1.0)
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
		_face(kuski, Vector3(9.0, 0, -2.2) if _t < 4.0 else opas.position)
	if _t > 1.6:
		_face(opas, kuski.position)
		_face(me, kuski.position if _t < 7.2 else opas.position)
	var lines := [[0.8, 2.6, kuski, "Näittekö te tuon?"], [2.7, 3.6, opas, "Mitä?"],
		[3.7, 6.2, kuski, "...Ei mitään. Kuolemansaari tämä on. Siks mää en aja tänne pimeellä."],
		[6.3, 7.2, me, "Kuolemansaari?"], [7.3, 9.4, opas, "Yksi tulkinta. Toiset sanoo, että nimi on ihan muuta."],
		[9.5, 11.0, kuski, "Mun mummo tiesi, mitä se tarkottaa. Ei koskaan kertonu."], [11.1, 12.5, opas, "Siitä saa kiistellä."]]
	for c in [me, opas, kuski]:
		_bub[c] = ""
	for l: Array in lines:
		if _t > l[0] and _t < l[1]:
			_bub[l[2]] = l[3]
	if _t > 11.1:
		Room.nod(opas, 0.12 + 0.1 * sin(_t * 16.0) * (1.0 - clampf((_t - 12.0) / 0.4, 0.0, 1.0)))  # naurahdus
		_story = "Nimestä saa kiistellä."
	_fit(Vector3(9.2, 1.75, 3.6), [_head(me) + Vector3(0, 0.3, 0), _head(opas) + Vector3(0, 0.3, 0), _head(kuski) + Vector3(0, 0.3, 0),
		_g(Vector3(KUSKI_AT.x, 0, KUSKI_AT.y)), _g(Retki.CANDLE_AT), _g(interior.LANTERNS[1]), _g(Vector3(9.0, 0, 0.3))], 1.12)
	_fill.position = Vector3(9.0, 2.0, 1.4)


func _step_otsikko() -> void:
	var lp: Array = interior.LANTERNS
	# Yläviistosta: kivijalka, kynttilä ja lyhdyt näkyvät väen takaa (kynttilä kuskin oikealla puolella).
	_fit(Vector3(9.2, 3.4, 4.8), [_head(me) + Vector3(0, 0.3, 0), _head(opas) + Vector3(0, 0.3, 0), _head(kuski) + Vector3(0, 0.3, 0),
		_g(Retki.CANDLE_AT + Vector3(0.4, 0, 0)), _g(lp[1]), _g(lp[2]), _g(Vector3(8.8, 0, 0.5)), _g(Vector3(9.0, 1.6, -5.6))], 1.1)
	_fill.position = Vector3(9.2, 2.2, 1.6)


# --- Oppaan kierros ja lyhdyt -------------------------------------------------------

## Oppaan reitti: kävely pisteestä toiseen vakiovauhdilla, lyhdyn lasku pysähdyksissä (PLACE s).
func _walk_route(t: float) -> void:
	var pos := OPAS_AT
	var acc := 0.0
	for i in OPAS_ROUTE.size():
		var tgt: Vector2 = OPAS_ROUTE[i][0]
		var li: int = OPAS_ROUTE[i][1]
		var d := pos.distance_to(tgt)
		var wt := d / SPEED
		if t < acc + wt:
			var k := (t - acc) / wt
			var p := pos.lerp(tgt, k)
			if opas.get_meta("anim", "") != "Walk":
				opas.set_meta("anim", "Walk")
				opas.play("Walk", 0.15)
			_stand(opas, p.x, p.y)
			_face(opas, Vector3(tgt.x, 0, tgt.y))
			_carry(opas, lanterns[_next_lantern(i)])
			return
		acc += wt
		pos = tgt
		if li >= 0:
			if t < acc + PLACE:
				_stand(opas, tgt.x, tgt.y)
				_place_step(opas, li, t - acc)
				return
			acc += PLACE
			if not placed[li]:
				_put_lantern(li)
	if opas.get_meta("anim", "") != "Idle":
		opas.set_meta("anim", "Idle")
		opas.play("Idle", 0.25)
		opas.clear_ik()
		_lean(opas, 0.0)
	_stand(opas, pos.x, pos.y)
	_face(opas, me.position)


func _next_lantern(route_i: int) -> int:
	for j in range(route_i, OPAS_ROUTE.size()):
		if OPAS_ROUTE[j][1] >= 0:
			return OPAS_ROUTE[j][1]
	return 2


## Lyhdyn lasku nurkkakivelle: kyykky (0-0,25 s), käsi lyhdyn kahvasta kiven päälle (0,25-0,75), irti ja ylös (1,0).
func _place_step(c: Node3D, li: int, t: float) -> void:
	var at: Vector3 = interior.LANTERNS[li]
	_face(c, Vector3(at.x, 0, at.z))
	if t < 0.92:
		if c.get_meta("anim", "") != "Crouch":
			c.set_meta("anim", "Crouch")
			c.play("Crouch_Idle", 0.15)
		var k := _ease(clampf((t - 0.2) / 0.55, 0.0, 1.0))
		var handle := _g(at + Vector3(0, 0.36, 0))
		var start := c.to_global(c.bone_position("upperarm_r") + Vector3(0, -0.3, -0.35))
		_reach(c, start.lerp(handle, k), 1.0, 0.3 * k, "_r")
		if k < 1.0:
			lanterns[li].visible = true
			lanterns[li].global_position = hand(c, "_r") + Vector3(0, -0.36, 0)
			lanterns[li].global_basis = Basis()
		else:
			_put_lantern(li)
	else:
		_put_lantern(li)
		if c.get_meta("anim", "") != "Idle":
			c.set_meta("anim", "Idle")
			c.play("Idle", 0.2)
			c.clear_ik()
			_lean(c, 0.0)


func _put_lantern(li: int) -> void:
	lanterns[li].visible = true
	lanterns[li].position = interior.LANTERNS[li]
	lanterns[li].rotation = Vector3.ZERO
	if not placed[li]:
		placed[li] = true
		Sfx.play("step_hard", -12.0, 1.5)


## Lyhty oikeassa kädessä kahvasta, käsi alhaalla vartalon sivulla.
func _carry(c: Node3D, l: Node3D) -> void:
	if placed[lanterns.find(l)]:
		return
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", sh + Vector3(s * 0.1, -0.52, -0.1), sh + Vector3(s * 0.45, -0.3, 0.2))
	l.visible = true
	l.global_position = hand(c, "_r") + Vector3(0, -0.37, 0)
	l.global_basis = c.global_basis
	_set_flame(l, 1.0)  # opas sytytti lyhdyt jo kirkolla


## Kanta, jonka +Y on dir (tikun akseli).
func _axis_basis(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized())


func _place_candle() -> void:
	candle.position = Retki.CANDLE_AT
	candle.rotation = Vector3.ZERO


func _apply_ghost() -> void:
	_ghost_mat.albedo_color.a = 0.85 * ghost_alpha
	_ghost_mat.emission_energy_multiplier = 2.2 * ghost_alpha
	_fill_mat.albedo_color.a = 0.07 * ghost_alpha
	_fill_mat.emission_energy_multiplier = 0.5 * ghost_alpha
	for e in _logs:
		(e[1] as Node3D).visible = ghost >= e[0] and ghost_alpha > 0.01


func _ghost_off() -> void:
	ghost = 0.0
	ghost_alpha = 0.0
	_apply_ghost()
	_motes.emitting = false


## Avoin kämmen rinnalla (vasen käsi): sormet kyynärvarren jatkeena, ranne rinnan edessä.
func _hand_on_chest(c: Node3D, w: float) -> void:
	var shl: Vector3 = c.bone_position("upperarm_l")
	var shr: Vector3 = c.bone_position("upperarm_r")
	var s := signf(shr.x) if shr.x != 0.0 else 1.0
	var chest := (shl + shr) / 2.0 + Vector3(s * 0.04, -0.2, -0.17)
	var rest := shl + Vector3(-s * 0.1, -0.5, -0.05)
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", rest.lerp(chest, w), shl + Vector3(-s * 0.4, -0.35, 0.05))


# --- Apufunktiot --------------------------------------------------------------------

func _g(v: Vector3) -> Vector3:
	return interior.to_global(v)


func _head(c: Node3D) -> Vector3:
	return c.to_global(c.bone_position("Head"))


func hand(c: Node3D, lr := "_r") -> Vector3:
	return c.to_global((c.bone_position("hand" + lr) + c.bone_position("index_01" + lr)) / 2.0)


## Kamera pisteestä eye (paikallinen) niin, että kaikki pisteet (globaalit) mahtuvat kuvaan (kapseli_kohtaus.gd _fit).
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


## Maan korkeus: kivijalan kumpu (y 0,10) ja hautojen nurmilaatat (y 0,04) retki_manamansalo.gd:n mukaan.
func _ground(x: float, z: float) -> float:
	if x > 7.2 and x < 10.8 and z > -3.5 and z < -0.9:
		return 0.1
	for g in [Vector2(7.0, -3.4), Vector2(11.4, -3.4)]:
		if absf(x - g.x) < 0.35 and absf(z - g.y) < 0.7:
			return 0.04
	return 0.0


func _stand(c: Node3D, x: float, z: float) -> void:
	c.position = Vector3(x, _ground(x, z), z)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


# --- Ääni ---------------------------------------------------------------------------

func _play(w: AudioStreamWAV, db: float, pitch: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = w
	p.volume_db = db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Hiljainen soinnun humina: A-duurin sävelet (110, 165, 220, 277 Hz), hidas vibrato ja pehmeä nousu ja lasku (n. 9 s).
func _hum_wav() -> AudioStreamWAV:
	var dur := 9.0
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	for i in s.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 2.0) * minf(1.0, (dur - t) / 2.5)
		var v := 1.0 + 0.003 * sin(TAU * 4.6 * t)
		var x := sin(TAU * 110.0 * v * t) * 0.45 + sin(TAU * 165.0 * v * t) * 0.3 + sin(TAU * 220.0 * v * t) * 0.25 \
			+ sin(TAU * 277.2 * v * t) * 0.18 * minf(1.0, maxf(0.0, t - 2.0) / 2.0) + sin(TAU * 330.0 * v * t) * 0.08
		s[i] = x * env * 0.45
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
		var y := vs.y * 0.22
		_draw_icon(Vector2(vs.x / 2.0, y - 104.0), a)
		var title := "MANAMANSALON KIVIJALKA"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, 12, Color(0.05, 0.08, 0.1, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 60, Color(1.0, 0.84, 0.42, a))
		var sr := Rect2(vs.x / 2.0 - 420, vs.y - 158.0, 840, 84)
		_ui.draw_rect(sr, Color(0.03, 0.05, 0.06, 0.75 * a))
		_ui.draw_string(font, sr.position + Vector2(0, 30), "Kivijalalla palaa kynttilä. Ensimmäinen kirkko seisoi tässä, sanotaan.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(0.95, 0.8, 0.5, a))
		_ui.draw_string(font, sr.position + Vector2(0, 60), "Nimestä saa kiistellä.",
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color(1.0, 0.94, 0.8, a))


## Otsikon kuvake: kivirivi, kynttilä liekkeineen ja sen yllä katkoviivainen kirkon ääriviiva.
func _draw_icon(c: Vector2, a: float) -> void:
	var dark := Color(0.05, 0.08, 0.1, a)
	var gold := Color(1.0, 0.82, 0.42, a)
	# Kirkon ääriviiva katkoviivana: seinät ja harjakatto, risti.
	var pts := [c + Vector2(-44, 22), c + Vector2(-44, -6), c + Vector2(0, -34), c + Vector2(44, -6), c + Vector2(44, 22)]
	for i in pts.size() - 1:
		_ui.draw_dashed_line(pts[i], pts[i + 1], gold, 2.5, 6.0)
	_ui.draw_line(c + Vector2(0, -34), c + Vector2(0, -50), gold, 2.5)
	_ui.draw_line(c + Vector2(-6, -44), c + Vector2(6, -44), gold, 2.5)
	# Kivirivi.
	for i in 6:
		var p := c + Vector2(-50 + i * 20, 28)
		_ui.draw_circle(p, 9.0, Color(0.6, 0.6, 0.63, a))
		_ui.draw_arc(p, 9.0, 0.0, TAU, 14, dark, 2.0)
	# Kynttilä.
	var body := Rect2(c + Vector2(-5, 2), Vector2(10, 22))
	_ui.draw_rect(body, Color(0.97, 0.95, 0.88, a))
	_ui.draw_rect(body, dark, false, 2.0)
	_ui.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(5, -2), c + Vector2(0, 1), c + Vector2(-5, -2)]), Color(1.0, 0.65, 0.2, a))
