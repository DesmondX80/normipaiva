extends CanvasLayer
## Löylykisa naisen saunassa (kolmiomittauksen iltakiva, K-18 ja vähän rivo): pelaaja ja kaksi kaveria istuvat
## ylälauteella pyyhkeet lanteilla, ja nainen heittää kiukaalle löylyä pitkävartisella kauhalla tasaisin välein.
## Viimeisenä lauteilla istuva voittaa. Paennut nousee, ja pyyhe jää lauteille (rivo): hän kävelee ovesta paljaana.
## Mekaniikka: tuska kasvaa löylyn mukaan. Hengitysrengas sykkii: haukku (interact) uloshengityksen kohdalla (vihreä
## kaari) laskee tuskaa, väärään aikaan tuska nousee (paniikki). Täysi tuska = pakenet.
## Saunahuone rakennetaan omaksi huoneekseen naisen talon yläpuolelle (kuten olohuone, rasvanappi_hall.gd:n kerros
## LAYER): paneeliseinät, kaksi laudetta, kiuas kivineen ja hehkuva luukku, ikkuna ja ovi. Lämpö näkyy höyrynä
## (hiukkaset) ja ympäristön sumuna, ei ruudun päälle piirrettynä. Ruudulla vain käyttöliittymä.

signal finished(result: Dictionary)

const Room := preload("res://scripts/ilta_room.gd")
const Hall := preload("res://scripts/rasvanappi_hall.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const Cutscene := preload("res://scripts/cutscene.gd")

## Saunan koordinaatit: lattia y = 0, takaseinä z = 0 (lauteet), ovi ja kamera +Z:n puolella. -Z on lauteen takaosa,
## istujien etu on +Z.
const ROOM := Vector3(2.8, 2.25, 2.4)  # leveys X, korkeus, syvyys Z
const BENCH_TOP := 1.0  # ylälauteen pinta
const BENCH_D := 0.62  # ylälauteen syvyys takaseinästä
const SEAT_X := [1.45, 0.82, 2.08]  # 0 pelaaja keskellä, 1 vasen, 2 oikea
const KIUAS := Vector3(0.42, 0.0, 1.55)
const PIPE := Vector3(0.26, 0.95, 1.55)  # piippu kiukaan seinänpuoleisessa reunassa (kauhan tieltä), alapää kivien tasolla
const PIPE_R := 0.07
const WOMAN_AT := Vector3(0.3, 0.0, 0.3)  # nainen istuu ylälauteen vasemmassa päässä (x)
const CENTER := Vector3(1.4, 0.0, 1.0)
const DOOR_Z := 1.85  # oviaukon keskikohta oikeassa seinässä
const DOOR_W := 0.75
const DOOR_H := 1.9
const THROW_EVERY := 6.5
const BREATH := 2.2  # hengityksen jakso (s)
const EXHALE := Vector2(0.55, 0.85)  # uloshengitys jakson osuutena (vihreä kaari)

var site := "saloinen"
var anchor: Node3D
var sun: DirectionalLight3D
var style := {}
var people: Array = []  # [pelaaja, vasen kaveri, oikea kaveri, nainen]
var lines := {}
var auto := false

var _room: Node3D
var _env: Environment
var _cam: Camera3D
var _cam_base: Transform3D
var _chars: Array = []
var _sitters: Array = []  # {"pain", "out", "sisu", "skill", "breath_t", "done_cycle", "nod"}
var _towels: Array = []  # lauteille jäävät pyyhkeet (näkyviin paetessa)
var _steam: CPUParticles3D
var _glow: OmniLight3D
var _ladle: Node3D  # löylykauha (-Z = varresta kuppiin, origo kädensijassa)
var _ladle_water: Node3D
var _ladle_cup: Node3D  # kuppi reunuksineen ja vesineen: pidetään pystyssä maailmassa (kallistus vain kaadettaessa)
var _ladle_rest := Vector3.ZERO
var _ladle_min_gap := 9.0  # pienin rako kauhan ja piipun välillä (m), testi tulostaa
var _throw_anim := 9.0  # heiton aika (s): kurotus kiukaalle, kallistus, paluu
var _bubbles: Array = ["", "", "", ""]
var _bubble_t := [0.0, 0.0, 0.0, 0.0]
var _phase := "alku"
var _t := 0.0
var _heat := 1  # löylyjen määrä
var _throw_t := 3.0
var _story := ""
var _ui: Control
var _keys: Node
var _shake := 0.0
var _flash := 0.0  # oma onnistunut / epäonnistunut hengitys (renkaan väri)
var _flash_ok := true
var _sun_mask := 0
var _rng := RandomNumberGenerator.new()
var _order: Array = []  # paenneet järjestyksessä
## Legendaarinen hetki "loylykunkku" (main.gd _kolmio_ilta: ensimmäinen voitto, lines.legenda): viimeinen kauha,
## kaverit ovella, pyyhe putoaa ja otsikko omina vaiheinaan. recall: hetki on jo koettu, joku muistelee illan alussa.
const LEG := ["kauha", "ovi", "pyyhe", "otsikko"]
var legend := false
var recall := false
var _door: Node3D
var _once := {}
var _big_steam: CPUParticles3D
var _door_light: OmniLight3D
var _friends: Array = []  # ovella kurkkivat kaverit [hahmo, pyyhe]
var _fall: Node3D  # putoava pyyhe
var _shot := ""  # pyyhe-vaiheen kuva: "a" kädet ylös, "b" jalat, "c" ovi, "d" kaksoiskuva
var _glow_boost := 0.0


func _ready() -> void:
	layer = 6
	add_to_group("esc_lopettaa")
	_rng.randomize()
	_build()
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
	_story = "Löylykisa! Viimeisenä lauteilla voittaa. Hengitä ulos, kun rengas on vihreällä: tuska laskee."
	if recall and lines.has("muisto"):
		var m: Array = (lines.muisto as Array).pick_random()
		_say(int(m[0]), String(m[1]))
		_bubble_t[int(m[0])] = 5.0
	else:
		_say(3, _line("alku", "Löylykisa! Pyyhkeet tiukalle."))


func _exit_tree() -> void:
	if sun != null and is_instance_valid(sun):
		sun.light_cull_mask = _sun_mask
	if is_instance_valid(_room):
		_room.queue_free()


# --- Sauna ja hahmot ----------------------------------------------------------------------------------------------

func _build() -> void:
	_room = Node3D.new()
	anchor.get_parent().add_child(_room)
	_room.top_level = true
	_room.global_transform = Transform3D(Basis(), anchor.global_position + Vector3(-1.4, 250, -6.0))
	if sun != null:
		_sun_mask = sun.light_cull_mask
		sun.light_cull_mask = _sun_mask & ~Hall.LAYER
	var panel := Color(0.78, 0.6, 0.38)
	var dark := Color(0.45, 0.3, 0.17)
	# Lattia (laudat), seinät paneelilaudoista ja katto.
	for i in 12:
		B.mesh(_room, B.boxm(Vector3(ROOM.x, 0.03, ROOM.z / 12.0 - 0.006)), Vector3(ROOM.x / 2.0, 0.0, (i + 0.5) * ROOM.z / 12.0),
			Color(0.5, 0.38, 0.26).lightened(0.05 * (i % 3)))
	_panel_wall(Vector3(ROOM.x / 2.0, ROOM.y / 2.0, -0.02), Vector3(ROOM.x, ROOM.y, 0.04), true, panel)  # takaseinä
	_panel_wall(Vector3(-0.02, ROOM.y / 2.0, ROOM.z / 2.0), Vector3(0.04, ROOM.y, ROOM.z), false, panel)
	_right_wall(panel)
	B.mesh(_room, B.boxm(Vector3(ROOM.x, 0.04, ROOM.z)), Vector3(ROOM.x / 2.0, ROOM.y, ROOM.z / 2.0), panel.darkened(0.25))
	# Ikkuna takaseinässä (kesäyön sininen) ja ovi oikealla seinällä.
	B.mesh(_room, B.boxm(Vector3(0.5, 0.3, 0.02)), Vector3(0.45, 1.85, 0.005), Color(0.35, 0.5, 0.75))
	B.mesh(_room, B.boxm(Vector3(0.56, 0.36, 0.015)), Vector3(0.45, 1.85, 0.0), dark)
	# Ovi saranassa (oviaukon +Z-reunassa), aukeaa ulos pukuhuoneeseen (legendaarinen hetki): -Z = saranasta lukolle.
	_door = Node3D.new()
	_door.position = Vector3(ROOM.x + 0.02, 0.0, DOOR_Z + DOOR_W / 2.0)
	_room.add_child(_door)
	B.mesh(_door, B.boxm(Vector3(0.035, DOOR_H - 0.01, DOOR_W - 0.01)), Vector3(0, DOOR_H / 2.0, -DOOR_W / 2.0), panel.darkened(0.1))
	for i in 5:  # oven pystypaneelit
		B.mesh(_door, B.boxm(Vector3(0.045, DOOR_H - 0.12, 0.008)), Vector3(0, DOOR_H / 2.0, -0.07 - i * 0.15), panel.darkened(0.3))
	B.mesh(_door, B.boxm(Vector3(0.11, 0.03, 0.14)), Vector3(0, 1.0, -DOOR_W + 0.12), dark)  # kahvat molemmin puolin
	for z: float in [DOOR_Z - DOOR_W / 2.0 - 0.03, DOOR_Z + DOOR_W / 2.0 + 0.03]:  # karmit
		B.mesh(_room, B.boxm(Vector3(0.05, DOOR_H + 0.06, 0.06)), Vector3(ROOM.x - 0.005, (DOOR_H + 0.06) / 2.0, z), dark)
	B.mesh(_room, B.boxm(Vector3(0.05, 0.06, DOOR_W + 0.12)), Vector3(ROOM.x - 0.005, DOOR_H + 0.03, DOOR_Z), dark)
	_build_pukuhuone()
	# Lauteet: ylälaude takaseinää vasten (rimat), alalaude jalkoja varten, tukipilarit.
	_bench(BENCH_TOP, 0.0, BENCH_D)
	var step_y := _seat_people()
	_bench(step_y, BENCH_D, 0.42)
	for x: float in [0.25, ROOM.x / 2.0, ROOM.x - 0.25]:
		B.mesh(_room, B.boxm(Vector3(0.06, BENCH_TOP - 0.03, 0.06)), Vector3(x, (BENCH_TOP - 0.03) / 2.0, BENCH_D - 0.06), dark)
		B.mesh(_room, B.boxm(Vector3(0.06, step_y - 0.03, 0.06)), Vector3(x, (step_y - 0.03) / 2.0, BENCH_D + 0.36), dark)
	_build_kiuas()
	# Nainen ylälauteen vasemmassa päässä kiukaan puolella, pitkävartinen kauha kädessä, bikineissä kuten Helena Uiton saunassa.
	var w := Looks.make(_room, _bikini_look(people[3].look))
	w.body_mat.set_shader_parameter("topless", true)  # kuten Helena Uiton saunassa: ilman bikinien yläosaa
	w.rotation.y = PI
	w.play("Sitting_Idle", 0.0)
	w.anim.advance(0.01)
	var wp: Vector3 = w.basis * w.bone_position("pelvis")
	w.position = Vector3(WOMAN_AT.x - wp.x, BENCH_TOP + 0.1 - wp.y, BENCH_D * 0.45 - wp.z)
	_chars.append(w)
	_ladle = _make_ladle()
	_ladle_rest = Vector3(WOMAN_AT.x + 0.2, step_y + 0.12, BENCH_D + 0.45)  # kuppi alalauteella naisen polven edessä
	# Kiulu lattialla naisen vieressä.
	var kiulu := Vector3(0.95, 0.0, 1.25)  # lattialla alalauteen edessä
	B.mesh(_room, B.cyl(0.13, 0.11, 0.2, 16), kiulu + Vector3(0, 0.1, 0), Color(0.62, 0.42, 0.22))
	B.mesh(_room, B.cyl(0.115, 0.115, 0.005, 16), kiulu + Vector3(0, 0.19, 0), Color(0.35, 0.5, 0.6))
	# Valot: kiukaan hehku ja lämmin kattovalo; ympäristö sumuinen (höyry).
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.5, 0.2)
	_glow.light_energy = 1.4
	_glow.omni_range = 2.6
	_glow.position = KIUAS + Vector3(0.2, 0.4, 0.2)
	_room.add_child(_glow)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.5
	lamp.omni_range = 4.5
	lamp.shadow_enabled = true
	lamp.position = Vector3(ROOM.x / 2.0, ROOM.y - 0.2, 1.4)
	_room.add_child(lamp)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.1, 0.07, 0.05)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.85, 0.6, 0.45)
	_env.ambient_light_energy = 0.35
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.95, 0.85, 0.75)
	_env.fog_density = 0.02
	_env.glow_enabled = true
	_env.glow_intensity = 0.3
	# Höyry kiukaalta.
	_steam = CPUParticles3D.new()
	_steam.amount = 60
	_steam.lifetime = 2.6
	_steam.emitting = false
	_steam.one_shot = true
	_steam.explosiveness = 0.7
	_steam.direction = Vector3(0.3, 1, -0.4)
	_steam.spread = 30.0
	_steam.initial_velocity_min = 0.4
	_steam.initial_velocity_max = 0.9
	_steam.gravity = Vector3(0, 0.15, 0)
	_steam.scale_amount_min = 1.0
	_steam.scale_amount_max = 2.0
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	_steam.mesh = sm
	var stm := StandardMaterial3D.new()
	stm.albedo_color = Color(1, 1, 1, 0.08)
	stm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_steam.material_override = stm
	_steam.position = KIUAS + Vector3(0, 0.85, 0)
	_room.add_child(_steam)
	_cam = Camera3D.new()
	_cam.fov = 58.0
	_cam.cull_mask = Hall.LAYER
	_cam.environment = _env
	_room.add_child(_cam)
	_frame_cam()
	_cam.current = true
	_set_layers(_room)


func _set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = Hall.LAYER
	if n is Light3D:
		(n as Light3D).light_cull_mask = Hall.LAYER
	for c in n.get_children():
		_set_layers(c)


## Paneeliseinä: pystylaudat (tai vaakalaudat sivuseinissä) ja tummat saumat.
func _panel_wall(at: Vector3, size: Vector3, back: bool, col: Color) -> void:
	B.mesh(_room, B.boxm(size), at, col)
	var n := 14
	for i in n:
		var t := (i + 0.5) / n - 0.5
		var p := at + (Vector3(0, t * size.y, 0))
		var s := Vector3(size.x, 0.008, 0.012) if back else Vector3(0.012, 0.008, size.z)
		var off := Vector3(0, 0, 0.02) if back else Vector3(0.02 * signf(ROOM.x / 2.0 - at.x), 0, 0)
		B.mesh(_room, B.boxm(s), p + off, col.darkened(0.3))


## Oikea seinä oviaukon ympäriltä (aukon takana pukuhuone): kolme paneelia ja rimat samoilla korkeuksilla kuin muualla.
func _right_wall(col: Color) -> void:
	var x := ROOM.x + 0.02
	var z0 := DOOR_Z - DOOR_W / 2.0
	var z1 := DOOR_Z + DOOR_W / 2.0
	var segs := [[0.0, z0, 0.0], [z1, ROOM.z, 0.0], [z0, z1, DOOR_H]]  # z alku, z loppu, y alku
	for sg: Array in segs:
		var w: float = sg[1] - sg[0]
		var y0: float = sg[2]
		B.mesh(_room, B.boxm(Vector3(0.04, ROOM.y - y0, w)), Vector3(x, (ROOM.y + y0) / 2.0, (sg[0] + sg[1]) / 2.0), col)
		for i in 14:
			var y := (i + 0.5) / 14.0 * ROOM.y
			if y > y0 + 0.01:
				B.mesh(_room, B.boxm(Vector3(0.012, 0.008, w)), Vector3(x - 0.02, y, (sg[0] + sg[1]) / 2.0), col.darkened(0.3))


## Pukuhuone oven takana: lattia, vaaleat paneeliseinät, naulakko ja pyyhe. Näkyy vain, kun ovi on auki.
func _build_pukuhuone() -> void:
	var x0 := ROOM.x + 0.04
	var d := 1.5
	var col := Color(0.9, 0.82, 0.64)
	B.mesh(_room, B.boxm(Vector3(d, 0.03, 2.2)), Vector3(x0 + d / 2.0, 0.0, DOOR_Z), Color(0.55, 0.5, 0.46))
	B.mesh(_room, B.boxm(Vector3(0.04, ROOM.y, 2.2)), Vector3(x0 + d, ROOM.y / 2.0, DOOR_Z), col)
	for z: float in [DOOR_Z - 1.1, DOOR_Z + 1.1]:
		B.mesh(_room, B.boxm(Vector3(d, ROOM.y, 0.04)), Vector3(x0 + d / 2.0, ROOM.y / 2.0, z), col.darkened(0.05))
	B.mesh(_room, B.boxm(Vector3(d, 0.04, 2.2)), Vector3(x0 + d / 2.0, ROOM.y, DOOR_Z), col.darkened(0.2))
	B.mesh(_room, B.boxm(Vector3(0.03, 0.08, 1.4)), Vector3(x0 + d - 0.035, 1.62, DOOR_Z), Color(0.5, 0.34, 0.2))  # naulakko
	for i in 4:
		B.mesh(_room, B.boxm(Vector3(0.08, 0.02, 0.02)), Vector3(x0 + d - 0.08, 1.6, DOOR_Z - 0.5 + i * 0.33), Color(0.3, 0.3, 0.32))
	B.mesh(_room, B.boxm(Vector3(0.04, 0.6, 0.34)), Vector3(x0 + d - 0.1, 1.3, DOOR_Z + 0.33), Color(0.95, 0.75, 0.2))  # pyyhe naulassa


## Laude: rimat (6 cm, 1 cm raot) syvyyssuunnassa z0..z0+depth korkeudella y.
func _bench(y: float, z0: float, depth: float) -> void:
	var n := floori(depth / 0.07)
	for i in n:
		B.mesh(_room, B.boxm(Vector3(ROOM.x - 0.08, 0.035, 0.06)), Vector3(ROOM.x / 2.0, y - 0.018, z0 + 0.035 + i * 0.07),
			Color(0.86, 0.7, 0.48).darkened(0.04 * (i % 2)))
	B.mesh(_room, B.boxm(Vector3(ROOM.x - 0.08, 0.08, 0.03)), Vector3(ROOM.x / 2.0, y - 0.07, z0 + depth - 0.02),
		Color(0.7, 0.52, 0.32))


## Kiuas: musta teräspesä, hehkuva luukku, kivikori ja kivet päällä, piippu kattoon.
func _build_kiuas() -> void:
	B.mesh(_room, B.boxm(Vector3(0.48, 0.62, 0.48)), KIUAS + Vector3(0, 0.31, 0), Color(0.12, 0.12, 0.13))
	var hatch := B.mesh(_room, B.boxm(Vector3(0.22, 0.14, 0.01)), KIUAS + Vector3(0, 0.22, 0.245), Color(1.0, 0.45, 0.1))
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1.0, 0.45, 0.1)
	hm.emission_enabled = true
	hm.emission = Color(1.0, 0.4, 0.05)
	hm.emission_energy_multiplier = 2.5
	hatch.material_override = hm
	for i in 4:  # kivikorin pinnat
		var a := TAU * i / 4.0
		B.mesh(_room, B.boxm(Vector3(0.5 if i % 2 == 0 else 0.02, 0.25, 0.02 if i % 2 == 0 else 0.5)),
			KIUAS + Vector3(sin(a) * 0.24, 0.75, cos(a) * 0.24), Color(0.2, 0.2, 0.22))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var p := Vector3(rng.randf_range(-0.19, 0.19), 0.66 + rng.randf() * 0.26, rng.randf_range(-0.19, 0.19))
		var st := MeshInstance3D.new()
		st.mesh = B.sphere(rng.randf_range(0.045, 0.07), 10)
		st.material_override = B.mat(Color(0.42, 0.4, 0.38).darkened(rng.randf() * 0.4))
		st.scale = Vector3(1.0, 0.7, 0.85)
		st.position = KIUAS + p
		_room.add_child(st)
	B.mesh(_room, B.cyl(PIPE_R, PIPE_R, ROOM.y - PIPE.y, 10), PIPE + Vector3(0, (ROOM.y - PIPE.y) / 2.0, 0),
		Color(0.15, 0.15, 0.16))


const LADLE_LEN := 0.74  # kädensijasta kupin keskelle


## Löylykauha: sorvattu puuvarsi nupilla, messinkiholkki ja alaspäin taipuva kaula, kupera messinkikuppi reunuksineen
## ja vesi kupissa. -Z = varresta kuppiin; kuppi roikkuu kaulan päässä aukko ylöspäin.
func _make_ladle() -> Node3D:
	var l := Node3D.new()
	_room.add_child(l)
	var wood := Color(0.62, 0.42, 0.24)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.55, 0.28)
	brass.metallic = 0.8
	brass.roughness = 0.35
	B.mesh(l, B.sphere(0.022, 10), Vector3(0, 0, 0.1), wood.darkened(0.15))  # nuppi varren päässä
	var handle := MeshInstance3D.new()  # kapeneva varsi kädensijasta holkkiin
	var hm := CylinderMesh.new()
	hm.top_radius = 0.0175
	hm.bottom_radius = 0.012
	hm.height = 0.7
	hm.radial_segments = 10
	handle.mesh = hm
	handle.material_override = B.mat(wood)
	handle.rotation.x = -PI / 2.0  # sylinterin y -> -Z
	handle.position = Vector3(0, 0, 0.1 - 0.35)
	l.add_child(handle)
	for z: float in [0.04, -0.02]:  # tummat syyrenkaat kädensijassa
		B.mesh(l, B.cyl(0.0182, 0.0182, 0.006, 10), Vector3(0, 0, z), wood.darkened(0.35), Vector3(PI / 2.0, 0, 0))
	var ferrule := MeshInstance3D.new()
	ferrule.mesh = B.cyl(0.014, 0.013, 0.05, 10)
	ferrule.material_override = brass
	ferrule.rotation.x = PI / 2.0
	ferrule.position = Vector3(0, 0, -0.62)
	l.add_child(ferrule)
	var neck := B.tube(l, Vector3(0, 0, -0.64), Vector3(0, -0.035, -LADLE_LEN + 0.04), 0.006, Color.WHITE)
	neck.material_override = brass
	var cup := MeshInstance3D.new()  # avoin kuppi: kylki ja pohja, sisäpinta näkyy (cull pois)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.052
	cm.bottom_radius = 0.036
	cm.height = 0.055
	cm.radial_segments = 18
	cm.cap_top = false
	cup.mesh = cm
	var cup_mat: StandardMaterial3D = brass.duplicate()
	cup_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cup.material_override = cup_mat
	var grp := Node3D.new()
	grp.position = Vector3(0, -0.06, -LADLE_LEN)
	l.add_child(grp)
	_ladle_cup = grp
	grp.add_child(cup)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.048
	tm.outer_radius = 0.057
	tm.rings = 18
	tm.ring_segments = 6
	rim.mesh = tm
	rim.material_override = brass
	rim.position = Vector3(0, 0.0275, 0)
	grp.add_child(rim)
	var water := MeshInstance3D.new()
	water.mesh = B.cyl(0.046, 0.046, 0.004, 16)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.45, 0.62, 0.75, 0.8)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.05
	water.material_override = wm
	water.position = Vector3(0, 0.015, 0)
	grp.add_child(water)
	_ladle_water = water
	return l


## Kauha naisen oikeassa kädessä: levossa kuppi alalauteella polven edessä, heitossa käsi kurottaa ja kuppi nousee
## kiukaan kivien ylle, kallistuu (vesi kaatuu, höyry) ja palaa. Käsi IK:lla kädensijaan.
func _place_ladle(delta: float) -> void:
	var w: Node3D = _chars[3]
	_throw_anim += delta
	var t := _throw_anim
	var reach := smoothstep(0.0, 0.55, t) * (1.0 - smoothstep(1.3, 1.9, t))
	var pour := smoothstep(0.6, 0.85, t) * (1.0 - smoothstep(1.05, 1.35, t))
	var sh := _room.to_local(w.to_global(w.bone_position("upperarm_r")))
	var over := KIUAS + Vector3(0.1, 0.98, 0.1)  # kivien etuosan yllä (piippu on kiukaan takareunassa)
	var cup := _ladle_rest.lerp(over, reach)
	var dir := (cup - sh)
	var dist := dir.length()
	dir = dir / maxf(dist, 0.001)
	var hand := sh + dir * clampf(dist - LADLE_LEN, 0.22, 0.5)
	cup = hand + dir * LADLE_LEN
	var inv := w.transform.affine_inverse()
	w.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * hand, inv * (hand + Vector3(0.25, -0.35, -0.1)))
	# Kauha kämmenen keskelle sen mukaan, mihin käsi IK:lla oikeasti päätyi (ranne + kämmen kyynärvarren jatkeena).
	var wr := _room.to_local(w.to_global(w.bone_position("hand_r")))
	var el := _room.to_local(w.to_global(w.bone_position("lowerarm_r")))
	var grip := wr + (wr - el).normalized() * 0.075
	dir = (cup - grip).normalized()
	cup = grip + dir * LADLE_LEN
	_ladle.position = grip
	_ladle.look_at(_room.to_global(cup), Vector3.UP)
	for i in 11:  # rako piippuun pitkin vartta ja kuppia (piippu pystysuora PIPE.y:stä ylös)
		var q := grip.lerp(cup + Vector3(0, -0.05, 0), i / 10.0)
		if q.y > PIPE.y - 0.03:
			var r := 0.06 if i == 10 else 0.02
			_ladle_min_gap = minf(_ladle_min_gap, Vector2(q.x - PIPE.x, q.z - PIPE.z).length() - PIPE_R - r)
	# Kuppi roikkuu kaulan päässä aukko ylöspäin; kaadettaessa se kallistuu varren suunnassa poispäin naisesta.
	var fwd := Vector3(dir.x, 0, dir.z).normalized()
	var tilt := Basis(fwd.cross(Vector3.UP).normalized(), -pour * 1.7)
	_ladle_cup.global_basis = _room.global_basis * tilt
	_ladle_cup.global_position = _room.to_global(cup + Vector3(0, -0.05, 0))
	_ladle_water.visible = t < 0.8 or t > 2.2
	Room.set_layers(_ladle)


## Ulkonäkö saunassa: sama kuin Uiton ja mökin saunassa (cutscene.gd sauna_look: paljas, löylystä punertava iho, ei
## kenkiä), pyyhkeen väri lanteille. Naiset: _bikini_look. towel = false: pyyhe jäi lauteille (paljas).
static func _towel_look(base: Dictionary, towel: bool, col: Color) -> Dictionary:
	var lk: Dictionary = Cutscene.sauna_look(base)
	for key in ["net_shirt", "chain", "vest_open", "ski_suit", "glam", "crop_y", "denim", "skirt", "gown", "cap", "sandels",
			"stripe_color", "lap_skirt", "coat_hem"]:
		lk.erase(key)
	lk["sleeve_x"] = 0.0
	var bare: Color = lk.bare_skin
	if String(lk.get("model", "male")) == "female":
		lk["pants"] = bare
		lk["shorts_y"] = 1.4
	else:
		lk["pants"] = col if towel else bare
		lk["shorts_y"] = 0.72 if towel else 1.4  # kuten sauna_look: pyyhe lanteilta reisiin
	return lk


## Naisen saunavaatteet kuten Helenalla Uiton saunassa (cutscene.gd helena_bikini): punaiset lappubikinit, paljaat
## jalat; yläosa pois varjostimella (topless).
static func _bikini_look(base: Dictionary) -> Dictionary:
	var look: Dictionary = base.duplicate()
	look.merge({"shirt": Color(0.9, 0.05, 0.12), "pants": Color(0.9, 0.05, 0.12), "shoes": Color(0.95, 0.75, 0.62), "shine": 0.7,
		"string_bikini": true, "shoe": "paljas", "denim": false}, true)
	for k in ["crop_y", "tube_y", "sleeve_x", "shorts_y", "skirt", "gown", "belt_y", "shoe_rough"]:
		look.erase(k)
	return look


## Istujat ylälauteelle: lantio laudepinnan yläpuolelle. Palauttaa alalauteen korkeuden jalkapohjien alle (mitattu
## matalimman jalkaterän luusta, jotta jalat lepäävät eivätkä mene laudetta läpi).
func _seat_people() -> float:
	var towel_cols := [Color(0.95, 0.95, 0.92), Color(0.25, 0.45, 0.75), Color(0.85, 0.3, 0.2)]
	var low := 9.0
	for s in 3:
		var c := Looks.make(_room, _towel_look(people[s].look, true, towel_cols[s]))
		c.rotation.y = PI  # etu +Z
		c.play("Sitting_Idle", 0.0)
		c.anim.advance(0.01)
		var pel: Vector3 = c.basis * c.bone_position("pelvis")
		c.position = Vector3(SEAT_X[s] - pel.x, BENCH_TOP + 0.1 - pel.y, BENCH_D * 0.45 - pel.z)
		_chars.insert(s, c)
		for f in ["ball_l", "ball_r", "foot_l", "foot_r"]:
			low = minf(low, c.to_global(c.bone_position(f)).y - _room.global_position.y)
		_sitters.append({"pain": 0.0, "out": false, "sisu": 1.0, "skill": 0.75, "breath_t": _rng.randf() * BREATH,
			"done_cycle": -1, "nod": 0.0})
		# Pyyhe, joka jää lauteille paetessa (taiteltu kangas istuimella), aluksi piilossa.
		var tw := MeshInstance3D.new()
		tw.mesh = B.boxm(Vector3(0.36, 0.03, 0.3))
		tw.material_override = B.mat(towel_cols[s])
		tw.position = Vector3(SEAT_X[s], BENCH_TOP + 0.015, BENCH_D * 0.5)
		tw.rotation.y = _rng.randf_range(-0.3, 0.3)
		tw.visible = false
		_room.add_child(tw)
		_towels.append(tw)
	# Luonteet: Esa ja Tero sisukkaita, Timolla sukat jalassa (tuskaisempi), Joni tasainen.
	for s in [1, 2]:
		match String(people[s].id):
			"esa":
				_sitters[s].sisu = 0.85
				_sitters[s].skill = 0.8
			"tero":
				_sitters[s].sisu = 0.9
				_sitters[s].skill = 0.72
			"timo":
				_sitters[s].sisu = 1.1
				_sitters[s].skill = 0.7
			_:
				_sitters[s].skill = 0.68
	return clampf(low - 0.03, 0.35, BENCH_TOP - 0.3)


## Kamera oven puolelta: kolme istujaa ja kiuas ruudulle, istujien päät yläosaan (projisoitu, ei arvata).
func _frame_cam() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aim := Vector3(1.2, 1.15, 0.6)
	for i in 40:
		var d := 0.0 + i * 0.06
		var eye := Vector3(1.85, 1.6 + d * 0.15, ROOM.z - 0.15 + d)
		_cam.transform = Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye)
		var l := _cam.unproject_position(_room.to_global(Vector3(SEAT_X[1] - 0.3, BENCH_TOP + 0.6, 0.3)))
		var r := _cam.unproject_position(_room.to_global(Vector3(SEAT_X[2] + 0.3, BENCH_TOP + 0.6, 0.3)))
		var k := _cam.unproject_position(_room.to_global(KIUAS + Vector3(-0.2, 0.7, 0)))
		var w := _cam.unproject_position(_room.to_global(Vector3(WOMAN_AT.x - 0.2, BENCH_TOP + 0.8, 0.3)))
		if l.x >= vs.x * 0.05 and r.x <= vs.x * 0.97 and k.x >= 0.0 and w.x >= vs.x * 0.02 and w.y >= vs.y * 0.08:
			break
	_cam_base = _cam.transform


# --- Kisa ---------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_place_ladle(delta)
	for s in 4:
		if _bubble_t[s] > 0.0:
			_bubble_t[s] -= delta
			if _bubble_t[s] <= 0.0:
				_bubbles[s] = ""
	if _phase in LEG:
		if Input.is_action_just_pressed("mount"):
			_finish(_leg_result())
			return
		_leg_step(delta)
		_update_keys()
		_ui.queue_redraw()
		return
	if Input.is_action_just_pressed("mount") and _phase != "loppu" and _phase != "valmis":
		_finish({"luovutti": true, "kiva": "loyly"})
		return
	match _phase:
		"alku":
			if _t > 3.0:
				_phase = "kisa"
				_t = 0.0
				_story = ""
		"kisa":
			_race(delta)
		"loppu":
			if _pressed() or (auto and _t > 2.0):
				var won := _winner() == 0
				if won and legend and lines.has("legenda"):
					_leg_begin()
				else:
					_finish({"voitto": won, "loylyt": _heat, "kiva": "loyly"})
	for s in 3:
		var e: Dictionary = _sitters[s]
		e.nod = move_toward(e.nod, 0.0, delta * 1.5)
		if not e.out:
			var c: Node3D = _chars[s]
			# Hengitys näkyy rinnassa ja päässä; tuska painaa päätä alas.
			c.set_override("spine_03", Vector3.RIGHT, sin((_t + e.breath_t) / BREATH * TAU) * 0.04 - e.pain * 0.12)
			c.set_override("neck_01", Vector3.RIGHT, e.pain * 0.35 + e.nod)
	_flash = maxf(0.0, _flash - delta * 2.0)
	_shake = maxf(0.0, _shake - delta * 2.5)
	_cam.transform = _cam_base.translated_local(Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.02)
	_env.fog_density = lerpf(_env.fog_density, minf(0.02 + 0.005 * _heat, 0.06), delta)
	_glow.light_energy = 1.3 + sin(_t * 7.0) * 0.12 + 0.05 * _heat
	_update_keys()
	_ui.queue_redraw()


func _pressed() -> bool:
	return Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")


## Hengityksen vaihe 0..1 istujalle s (pelaajalla pelin kello, tekoälyllä oma vaihe).
func _phase_of(s: int) -> float:
	var e: Dictionary = _sitters[s]
	return fmod(_t + (0.0 if s == 0 else float(e.breath_t)), BREATH) / BREATH


func _race(delta: float) -> void:
	# Löylyä tasaisin välein: höyry, sihahdus, tärähdys.
	_throw_t -= delta
	if _throw_t <= 0.0:
		_throw_t = THROW_EVERY
		_heat += 1
		_throw_anim = 0.0
		get_tree().create_timer(0.75).timeout.connect(func() -> void:
			if not is_instance_valid(_steam):
				return
			_steam.restart()
			Sfx.play("fire", -6.0, 1.6, 0.9)
			_shake = 0.6)
		if _rng.randf() < 0.6:
			_say(3, _line("heitto", "Lisää löylyä!"))
	var rate := 0.008 + 0.0065 * _heat
	for s in 3:
		var e: Dictionary = _sitters[s]
		if e.out:
			continue
		e.pain += rate * float(e.sisu) * delta
		var cyc := floori((_t + (0.0 if s == 0 else float(e.breath_t))) / BREATH)
		var ph := _phase_of(s)
		if s == 0 and not auto:
			if _pressed():
				_breathe(s, ph >= EXHALE.x and ph <= EXHALE.y and cyc != int(e.done_cycle), cyc)
		elif ph > (EXHALE.x + EXHALE.y) / 2.0 and cyc != int(e.done_cycle):
			var skill: float = 0.92 if s == 0 else float(e.skill)
			_breathe(s, _rng.randf() < skill, cyc)
		if e.pain >= 1.0:
			_flee(s)
	var left := _sitting()
	if left.size() == 1 or _sitters[0].out:
		_end()


func _breathe(s: int, ok: bool, cyc: int) -> void:
	var e: Dictionary = _sitters[s]
	e.done_cycle = cyc
	e.pain = clampf(e.pain + (-0.12 if ok else 0.06), 0.0, 1.0)
	e.nod = -0.15 if ok else 0.2
	if s == 0:
		_flash = 1.0
		_flash_ok = ok
		Sfx.play("breath" if ok else "pant", -8.0, 1.0)


func _sitting() -> Array:
	var out: Array = []
	for s in 3:
		if not _sitters[s].out:
			out.append(s)
	return out


## Pako: nousee lauteilta, pyyhe jää laudetta pitkin (rivo), ja kävelee ovesta ulos paljaana.
func _flee(s: int) -> void:
	var e: Dictionary = _sitters[s]
	e.out = true
	_order.append(s)
	var old: Node3D = _chars[s]
	var at := old.position
	old.queue_free()
	var c := Looks.make(_room, _towel_look(people[s].look, false, Color.WHITE))
	c.position = Vector3(SEAT_X[s], 0.0, BENCH_D + 0.55)  # alalauteen eteen lattialle
	c.rotation.y = -PI / 2.0  # oikealle kohti ovea (+X), alalauteen edestä (ei kameran editse)
	c.play("Walk", 0.0, 1.4)
	_chars[s] = c
	_set_layers(c)
	(_towels[s] as Node3D).visible = true
	var tw := c.create_tween()
	tw.tween_property(c, "position", Vector3(ROOM.x + 0.3, 0.0, BENCH_D + 0.55), 1.6)
	tw.tween_callback(func() -> void: c.visible = false)
	Sfx.play("door", -8.0)
	Sfx.play("step_wood", -10.0)
	_shake = 0.5
	if s == 0:
		_say(3, _line("pakenee_sina", "Pyyhe jäi lauteille!"))
	else:
		var own: Array = lines.get("pakenee", {}).get(String(people[s].id), [])
		_say(s, own.pick_random() if not own.is_empty() else "Mää lähen!")
	var _unused := at


func _winner() -> int:
	var left := _sitting()
	if left.size() == 1:
		return left[0]
	# Pelaaja pakeni, ja muita on vielä lauteilla: vähiten tuskainen voittaa.
	var best := -1
	for s: int in left:
		if best < 0 or _sitters[s].pain < _sitters[best].pain:
			best = s
	return best if best >= 0 else 1


func _end() -> void:
	_phase = "loppu"
	_t = 0.0
	var w := _winner()
	Sfx.play("win" if w == 0 else "lose", -4.0)
	if w == 0:
		_story = "Voitit! %d löylyä, ja kaverit pakenivat pyyhkeet lauteille. %s heittää vielä yhden sulle." % [_heat,
			people[3].name]
		_say(3, _line("voitto", "Sää kestit."))
	else:
		_story = "%s voitti %d löylyllä. Sun pyyhe jäi lauteille, ja kaikki näki." % [people[w].name, _heat]
		var t: String = _line("havio", "%s voitti!")
		_say(3, t % people[w].name if "%s" in t else t)


func _finish(r: Dictionary) -> void:
	if _phase == "valmis":
		return
	_phase = "valmis"
	finished.emit(r)
	queue_free()


# --- Puhe ja käyttöliittymä ---------------------------------------------------------------------------------------

func _line(key: String, fallback: String) -> String:
	var l: Variant = lines.get(key, [])
	return (l as Array).pick_random() if l is Array and not (l as Array).is_empty() else fallback


func _say(s: int, text: String) -> void:
	_bubbles[s] = "%s: %s" % [people[s].name, text] if s != 0 else text
	_bubble_t[s] = 3.4


func _update_keys() -> void:
	match _phase:
		"kisa":
			_keys.set_text("%s hengitä ulos (vihreällä)   %s lopeta" % [Settings.cap("interact"), Settings.cap("mount")])
		"loppu":
			_keys.set_text("%s jatka" % Settings.cap("interact"))
		"kauha", "ovi", "pyyhe", "otsikko":
			_keys.set_text("%s ohita" % Settings.cap("mount"))
		_:
			_keys.set_text("%s lopeta" % Settings.cap("mount"))


func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _phase in LEG:
		_draw_legend(vs)
		return
	var names: Array = []
	for s: int in _sitting():
		names.append("Sinä" if s == 0 else String(people[s].name))
	var top := "LÖYLYKISA   Löylyjä %d   Lauteilla: %s" % [_heat, ", ".join(names)]
	Room.box(_ui, Rect2(vs.x / 2.0 - 380, 14, 760, 40), Color(0, 0, 0, 0.55))
	_ui.draw_string(font, Vector2(vs.x / 2.0 - 370, 42), top, HORIZONTAL_ALIGNMENT_CENTER, 740, 20, Color.WHITE)
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 400, 62, 800, 60)
		Room.box(_ui, r)
		_ui.draw_multiline_string(font, r.position + Vector2(16, 25), _story, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 18, 2,
			Color(1.0, 0.92, 0.75))
	if _phase == "alku":
		_ui.draw_string(font, Vector2(0, vs.y * 0.45), str(maxi(1, 3 - floori(_t))), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 96,
			Color(1, 0.95, 0.8))
	for s in 4:
		if s < 3 and _sitters[s].out:
			continue
		Room.bubble(_ui, _cam, _chars[s], _bubbles[s], 130.0 if _story != "" else 64.0, 170.0)
	if _sitters[0].out:
		return
	# Hengitysrengas: vihreä kaari = uloshengitys, osoitin kiertää; keskellä oma tuska.
	var c := Vector2(vs.x / 2.0, vs.y - 118)
	var rad := 46.0
	_ui.draw_circle(c, rad + 10, Color(0, 0, 0, 0.55))
	_ui.draw_arc(c, rad, 0, TAU, 48, Color(1, 1, 1, 0.25), 8.0)
	_ui.draw_arc(c, rad, -PI / 2.0 + EXHALE.x * TAU, -PI / 2.0 + EXHALE.y * TAU, 24, Color(0.3, 0.9, 0.4), 10.0)
	var a := -PI / 2.0 + _phase_of(0) * TAU
	_ui.draw_line(c, c + Vector2(cos(a), sin(a)) * (rad + 6), Color.WHITE, 4.0)
	var pain: float = _sitters[0].pain
	var col := Color(0.3, 0.9, 0.4) if _flash_ok else Color(1, 0.3, 0.2)
	_ui.draw_circle(c, 26.0 + 4.0 * _flash, Color(1.0, 0.35, 0.2).lerp(Color(0.95, 0.85, 0.7), 1.0 - pain).lerp(col, _flash * 0.6))
	_ui.draw_string(font, c + Vector2(-60, 8), "%d %%" % roundi(pain * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 120, 20,
		Color(0.1, 0.05, 0.03))
	_ui.draw_string(font, c + Vector2(-100, -rad - 18), "TUSKA", HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color.WHITE)


# --- Legendaarinen hetki ------------------------------------------------------------------------------------------
# Ensimmäinen voitto (main.gd _kolmio_ilta legend): kaverit ovat paenneet, ja nainen heittää kunkulle viimeisen
# kauhallisen: valtava höyrypilvi, kunkku ei hievahda (kauha). Pukuhuoneen ovi raottuu, ja kaverit kurkkivat ovelta
# pyyhkeet kourassa (ovi). Kunkku nousee lattialle kädet ylhäällä, pyyhe putoaa nilkkoihin (kuvataan polvista alas),
# kaverit peittävät silmänsä ja nainen nauraa (pyyhe), ja otsikko (otsikko). Kamera pysyy siveänä: pyyhkeen
# pudottua kunkku kuvataan rinnasta ylös (lantio rajataan laskemalla pois kuvasta).
# Istujien etu on +Z, ovi oikealla seinällä (+X), kaverit seisovat pukuhuoneessa katse -X:ään.

const P_STAND := Vector3(1.45, 0.0, 1.32)  # kunkku seisoo alalauteen edessä lattialla
const F_AT := [Vector3(ROOM.x + 0.34, 0.0, DOOR_Z - 0.12), Vector3(ROOM.x + 0.58, 0.0, DOOR_Z + 0.26)]
const F_TOWEL := [Color(0.95, 0.75, 0.2), Color(0.3, 0.7, 0.45)]  # pukuhuoneen naulasta siepatut pyyhkeet


func _leg_result() -> Dictionary:
	return {"voitto": true, "loylyt": _heat, "kiva": "loyly"}


func _first(key: String) -> bool:
	if _once.has(key):
		return false
	_once[key] = true
	return true


func _leg_say(i: int, sec := 3.0) -> void:
	var r: Array = lines.legenda.rivit[i]
	for s in 4:
		_bubbles[s] = ""  # yksi kupla kerrallaan
	_say(int(r[0]), String(r[1]))
	_bubble_t[int(r[0])] = sec


func _bone(c: Node3D, b: String) -> Vector3:
	return _room.to_local(c.to_global(c.bone_position(b)))


func _set_cam(eye: Vector3, look: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam_base = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
	_cam.transform = _cam_base


## Kamera suunnasta dir kohti pistettä look: lähin etäisyys, jolla kaikki pisteet osuvat ruutuun reunuksen sisään.
## Silmä pysyy saunan sisällä (etuseinä legendassa z = ROOM.z); jos ei mahdu, kuvakulma levenee.
func _fit_cam(look: Vector3, dir: Vector3, fov: float, pts: Array, margin := 0.08) -> void:
	var vs := get_viewport().get_visible_rect().size
	var d := dir.normalized()
	for f in 6:
		var fv := fov + f * 4.0
		for i in 80:
			var eye := look + d * (0.5 + i * 0.04)
			if eye.z > ROOM.z - 0.08 or eye.x > ROOM.x - 0.08 or eye.x < 0.08 or eye.y > ROOM.y - 0.08:
				break
			_set_cam(eye, look, fv)
			var ok := true
			for p: Vector3 in pts:
				var g := _room.to_global(p)
				var q := _cam.unproject_position(g)
				if _cam.is_position_behind(g) or q.x < vs.x * margin or q.x > vs.x * (1.0 - margin) or q.y < vs.y * margin \
						or q.y > vs.y * (1.0 - margin):
					ok = false
					break
			if ok:
				return


func _leg_begin() -> void:
	_phase = "kauha"
	_t = 0.0
	_story = String(lines.legenda.kauha)
	for s in 4:
		_bubbles[s] = ""
	_sitters[0].pain = 0.0
	# Etuseinä ja ovi auki -valo: lähikuvissa ei mustaa tyhjää, pukuhuone valaistu.
	_panel_wall(Vector3(ROOM.x / 2.0, ROOM.y / 2.0, ROOM.z + 0.02), Vector3(ROOM.x, ROOM.y, 0.04), true,
		Color(0.78, 0.6, 0.38))
	_door_light = OmniLight3D.new()
	_door_light.light_color = Color(0.85, 0.92, 1.0)
	_door_light.light_energy = 1.3
	_door_light.omni_range = 2.2
	_door_light.shadow_enabled = true
	_door_light.position = Vector3(ROOM.x + 0.8, 2.0, DOOR_Z)
	_room.add_child(_door_light)
	# Iso höyrypilvi viimeisestä kauhallisesta: rullaa kiukaalta kunkun ylle.
	_big_steam = CPUParticles3D.new()
	_big_steam.amount = 220
	_big_steam.lifetime = 3.0
	_big_steam.emitting = false
	_big_steam.one_shot = true
	_big_steam.explosiveness = 0.85
	_big_steam.direction = Vector3(1.0, 0.9, -0.5)
	_big_steam.spread = 40.0
	_big_steam.initial_velocity_min = 0.8
	_big_steam.initial_velocity_max = 1.8
	_big_steam.damping_min = 0.3
	_big_steam.damping_max = 0.6
	_big_steam.gravity = Vector3(0, 0.12, 0)
	_big_steam.scale_amount_min = 0.8
	_big_steam.scale_amount_max = 2.0
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	_big_steam.mesh = sm
	var stm := StandardMaterial3D.new()
	stm.albedo_color = Color(1, 0.97, 0.92, 0.07)
	stm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_big_steam.material_override = stm
	_big_steam.position = KIUAS + Vector3(0.05, 0.95, 0.05)
	_room.add_child(_big_steam)
	_set_layers(_room)
	# Kunkku yksin lauteilla kavereiden jättämien pyyhkeiden välissä, nainen kauhoineen ja kiuas vasemmalla.
	var p: Node3D = _chars[0]
	var head := _bone(p, "Head")
	_fit_cam(Vector3(1.15, 1.3, 0.75), Vector3(0.3, 0.12, 1.0), 50.0, [head + Vector3(0, 0.2, 0),
		(_towels[1] as Node3D).position, (_towels[2] as Node3D).position + Vector3(0.2, 0, 0), _bone(_chars[3], "Head") + Vector3(-0.1, 0.2, 0),
		KIUAS + Vector3(0, 0.3, 0.25)], 0.05)


## Kaveri ovelle pyyhe kourassa (paljaana, pyyhe peittää edestä): hahmo ja pyyhe, kädet IK:lla pyyhkeen yläkulmiin.
func _make_friend(i: int) -> void:
	var s := i + 1
	var c := Looks.make(_room, _towel_look(people[s].look, false, Color.WHITE))
	var f := Vector3(-1.0, 0.0, -0.3 if i == 0 else -0.45).normalized()
	c.rotation.y = atan2(-f.x, -f.z)
	c.position = F_AT[i]
	c.play("Idle", 0.0)
	c.anim.advance(0.01)
	var t := Node3D.new()  # rypistetty pyyhe: kaksi taitosta ja raidat, -Z = poispäin hahmosta
	_room.add_child(t)
	var col: Color = F_TOWEL[i]
	B.mesh(t, B.boxm(Vector3(0.36, 0.44, 0.045)), Vector3(0, -0.04, 0), col)
	var fold := B.mesh(t, B.boxm(Vector3(0.38, 0.12, 0.06)), Vector3(0, 0.15, -0.012), col.lightened(0.12))
	fold.rotation.x = 0.25
	for y: float in [-0.18, -0.12]:
		B.mesh(t, B.boxm(Vector3(0.362, 0.022, 0.047)), Vector3(0, y, 0), Color(0.95, 0.95, 0.92))
	_chars[s].visible = false
	_friends.append([c, t, f])
	_set_layers(c)
	_set_layers(t)
	_friend_pose(i, 0.0)


## Kaverin asento: pyyhe lantion edessä kahdella kädellä; cover > 0: oikea käsi silmille (pyyhe vasemmassa).
func _friend_pose(i: int, cover: float) -> void:
	var fr: Array = _friends[i]
	var c: Node3D = fr[0]
	var t: Node3D = fr[1]
	var f: Vector3 = fr[2]
	var right := f.cross(Vector3.UP).normalized()
	var pel := _bone(c, "pelvis")
	var tp := pel + f * 0.2 + Vector3(0, -0.06, 0)
	t.position = tp
	t.basis = Basis.looking_at(-f, Vector3.UP).rotated(f, 0.08 if i == 0 else -0.1)
	var inv := c.transform.affine_inverse()
	var hl := tp + Vector3(0, 0.14, 0) - right * 0.13 + f * 0.03
	var hr := tp + Vector3(0, 0.14, 0) + right * 0.13 + f * 0.03
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", inv * hl, inv * (hl - right * 0.35 - f * 0.1 + Vector3(0, -0.1, 0)))
	if cover > 0.0:
		var head := _bone(c, "Head")
		var eyes := head + f * 0.13 + Vector3(0, 0.02, 0)
		hr = hr.lerp(eyes, cover)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * hr, inv * (hr + right * 0.35 - f * 0.1 + Vector3(0, -0.25, 0)))


## Kunkku nousee lattialle pyyhe lanteilla (towel) tai ilman.
func _stand_king(towel: bool) -> void:
	var old: Node3D = _chars[0]
	var c := Looks.make(_room, _towel_look(people[0].look, towel, Color(0.95, 0.95, 0.92)))
	c.rotation.y = PI  # etu +Z
	c.position = P_STAND
	c.play("Idle", 0.0)
	c.anim.advance(0.01)
	_chars[0] = c
	_set_layers(c)
	old.queue_free()


## Kunkun kädet: up 1 = nyrkit ylhäällä, 0 = kädet lanteilla.
func _king_arms(up: float) -> void:
	var c: Node3D = _chars[0]
	var f := Vector3(0, 0, 1)
	var right := f.cross(Vector3.UP)
	var inv := c.transform.affine_inverse()
	var head := _bone(c, "Head")
	var pel := _bone(c, "pelvis")
	for sd: float in [-1.0, 1.0]:
		var hip := pel + right * sd * 0.2 + Vector3(0, 0.12, 0) + f * 0.02
		var top := head + right * sd * 0.26 + Vector3(0, 0.3, 0) + f * 0.04
		top.y = minf(top.y, ROOM.y - 0.12)
		var h := hip.lerp(top, up)
		var pole := h + right * sd * 0.4 + (Vector3(0, -0.2, 0) if up > 0.5 else -f * 0.3)
		var lr := "_r" if sd > 0.0 else "_l"
		c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, inv * h, inv * pole)


## Putoava pyyhe: avoin kangasrengas lanteilta nilkkoihin, raidat; laskeutuu ja rypistyy kasaksi jalkojen ympärille.
func _make_fall() -> void:
	_fall = Node3D.new()
	_room.add_child(_fall)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.23
	cm.height = 0.34
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	var m: StandardMaterial3D = B.mat(Color(0.95, 0.95, 0.92)).duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	_fall.add_child(mi)
	for y: float in [-0.11, -0.07]:
		var r := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.2 + (y + 0.17) / 0.34 * 0.03 + 0.003
		rm.bottom_radius = rm.top_radius + 0.002
		rm.height = 0.02
		rm.cap_top = false
		rm.cap_bottom = false
		rm.radial_segments = 20
		r.mesh = rm
		var bm: StandardMaterial3D = B.mat(Color(0.25, 0.45, 0.75)).duplicate()
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		r.material_override = bm
		r.position.y = y
		_fall.add_child(r)
	_fall.position = Vector3(P_STAND.x, 0.82, P_STAND.z)
	_set_layers(_fall)


## Pyyhekasa nilkkojen ympärillä: litistettyjä poimuja renkaana ja kasana kantapäiden takana, raita näkyy.
func _make_heap() -> void:
	var c: Node3D = _chars[0]
	var fl := _bone(c, "foot_l")
	var fr := _bone(c, "foot_r")
	var ctr := Vector3((fl.x + fr.x) / 2.0, 0.0, (fl.z + fr.z) / 2.0 - 0.03)
	var h := Node3D.new()
	_room.add_child(h)
	var white := Color(0.95, 0.95, 0.92)
	for i in 11:
		var a := TAU * i / 11.0 + 0.3
		var r := 0.17 + 0.03 * sin(i * 2.7)
		var lump := MeshInstance3D.new()
		lump.mesh = B.sphere(0.075, 10)
		lump.material_override = B.mat(white.darkened(0.06 * (i % 3)) if i != 4 else Color(0.25, 0.45, 0.75))
		lump.scale = Vector3(1.3, 0.38 + 0.12 * fmod(i * 0.618, 1.0), 0.8)
		lump.position = ctr + Vector3(sin(a) * r, 0.025, cos(a) * r * 0.85)
		lump.rotation.y = a
		h.add_child(lump)
	for i in 3:  # taittunut kangas kantapäiden takana (korkeampi poimu)
		var lump := MeshInstance3D.new()
		lump.mesh = B.sphere(0.08, 10)
		lump.material_override = B.mat(white.darkened(0.04 * i))
		lump.scale = Vector3(1.4, 0.7, 0.9)
		lump.position = ctr + Vector3(-0.08 + i * 0.08, 0.05, -0.15)
		h.add_child(lump)
	_set_layers(h)


func _leg_step(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 2.0)
	_glow_boost = maxf(0.0, _glow_boost - delta * 1.2)
	_glow.light_energy = 1.4 + _glow_boost * 4.0 + sin(_t * 7.0) * 0.1
	_cam.transform = _cam_base.translated_local(Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.025)
	match _phase:
		"kauha":
			_env.fog_density = lerpf(_env.fog_density, 0.035 if _t > 2.2 else 0.02, delta * 1.5)
			if _t > 0.3 and _first("k0"):
				_leg_say(0, 2.6)
			if _t > 1.3 and _first("heitto"):
				_throw_anim = 0.0
			if _t > 2.05 and _first("pilvi"):
				_big_steam.restart()
				_steam.restart()
				_glow_boost = 1.0
				_shake = 1.0
				Sfx.play("fire", -2.0, 0.8, 1.2)
				Sfx.play("water", -4.0, 0.6, 1.4)
			if _t > 3.7 and _first("k1"):
				_leg_say(1, 2.4)
				Room.nod(_chars[0], -0.12)  # leuka pystyyn
			if _t > 6.4:
				_leg_ovi()
		"ovi":
			if _door.rotation.y > -deg_to_rad(100.0):
				_door.rotation.y = maxf(-deg_to_rad(100.0), _door.rotation.y - delta * 3.0)
			for i in _friends.size():
				_friend_pose(i, 0.0)
			if _t > 0.8 and _first("o0"):
				_leg_say(2, 2.1)
			if _t > 3.0 and _first("o1"):
				_leg_say(3, 2.2)
			if _t > 5.4:
				_leg_pyyhe()
		"pyyhe":
			_leg_pyyhe_step(delta)
		"otsikko":
			_king_arms(0.0)
			for i in _friends.size():
				_friend_pose(i, 1.0)
			if _t > 5.5:
				_finish(_leg_result())


func _leg_ovi() -> void:
	_phase = "ovi"
	_t = 0.0
	_story = String(lines.legenda.ovi)
	Sfx.play("door", -6.0, 0.9)
	_big_steam.visible = false  # pilvi on jo haihtunut: ovikuvan etualalla ei höyrypalloja
	_steam.visible = false
	_make_friend(0)
	_make_friend(1)
	# Kunkun silmin lauteilta: ovi ja kurkkivat kaverit, höyry valuu ovesta ulos.
	_set_cam(Vector3(1.2, 1.5, 1.2), Vector3(ROOM.x + 0.4, 1.38, DOOR_Z + 0.05), 44.0)


func _leg_pyyhe() -> void:
	_phase = "pyyhe"
	_t = 0.0
	_story = String(lines.legenda.pyyhe)
	for s in 4:
		_bubbles[s] = ""
	_stand_king(true)
	_shot = ""


func _leg_pyyhe_step(delta: float) -> void:
	var c: Node3D = _chars[0]
	if _t < 2.4:
		if _shot != "a":
			_shot = "a"
			_king_arms(0.0)
			var head := _bone(c, "Head")
			_fit_cam(head + Vector3(0, -0.15, 0), Vector3(0.5, 0.05, 1.0), 44.0, [head + Vector3(0.3, 0.45, 0),
				head + Vector3(-0.3, 0.45, 0), _bone(c, "pelvis") + Vector3(0, -0.28, 0)], 0.06)
		_king_arms(smoothstep(0.2, 0.9, _t))
		if _t > 0.5 and _first("p0"):
			_leg_say(4, 1.9)
		for i in _friends.size():
			_friend_pose(i, 0.0)
	elif _t < 3.8:
		if _shot != "b":
			_shot = "b"
			for s in 4:
				_bubbles[s] = ""
			# Pyyhe putoaa: kuva polvista alas (yläreuna sääriluun puolivälissä), kunkku on jo paljas.
			c.call("restyle", _towel_look(people[0].look, false, Color.WHITE))
			_king_arms(1.0)
			_make_fall()
			_set_cam(P_STAND + Vector3(0.68, 0.25, 0.76), P_STAND + Vector3(0, 0.2, 0), 34.0)  # vinosti: jalkaterät sivulta
			Sfx.play("cloth", -2.0, 0.8)
		_king_arms(1.0)
		var k := clampf((_t - 2.45) / 0.5, 0.0, 1.0)
		var fall := k * k  # painovoima: kiihtyy
		_fall.position.y = lerpf(0.82, 0.03, fall)
		_fall.scale = Vector3(1.0, lerpf(1.0, 0.7, k), 1.0)
		if k >= 1.0 and _first("tomps"):
			_fall.visible = false
			_make_heap()
			Sfx.play("body_fall", -14.0, 1.6)
			_shake = 0.3
	elif _t < 5.8:
		if _shot != "c":
			_shot = "c"
			# Kunkun oikealta (kunkku jää kuvan ulkopuolelle vasemmalle taakse), ovi ja kaverit keskellä.
			_set_cam(Vector3(1.95, 1.5, 0.95), Vector3(ROOM.x + 0.4, 1.4, DOOR_Z + 0.05), 42.0)
		var cover := smoothstep(3.85, 4.3, _t)
		_friend_pose(0, cover)
		_friend_pose(1, cover)
		(_friends[1][0] as Node3D).call("set_override", "neck_01", Vector3.UP, 0.7 * cover)
		if _t > 4.0 and _first("p1"):
			_leg_say(5, 2.0)
	else:
		if _shot != "d":
			_shot = "d"
			_leg_frame_d()
			_chars[3].call("play", "Sitting_Talking", 0.2)
		_king_arms(0.0)
		if _t > 6.0 and _first("p2"):
			_leg_say(6, 2.6)
		if _t > 8.8:
			_phase = "otsikko"
			_t = 0.0
			_story = ""
			for s in 4:
				_bubbles[s] = ""
			_chars[3].call("play", "Sitting_Idle", 0.3)
			Sfx.play("win", -4.0)


## Kaksoiskuva: kunkku rinnasta ylös etualalla, nainen lauteella taustalla. Lantio rajataan laskemalla kuvan alle.
func _leg_frame_d() -> void:
	var c: Node3D = _chars[0]
	_king_arms(0.0)
	var vs := get_viewport().get_visible_rect().size
	var head := _bone(c, "Head")
	var wh := _bone(_chars[3], "Head")
	var pel := _bone(c, "pelvis")
	var look := head.lerp(wh, 0.45) + Vector3(0, -0.12, 0)
	var sl := _bone(c, "upperarm_l")
	var sr := _bone(c, "upperarm_r")
	for i in 12:
		# Päiden yllä tilaa otsikolle; kunkun olkapäät mukaan (ei pelkkää naamaa).
		_fit_cam(look, Vector3(0.55, 0.0, 1.0), 46.0, [head + Vector3(0, 0.55, 0), wh + Vector3(0, 0.55, 0),
			sl + Vector3(0.12, 0, 0), sr + Vector3(-0.12, 0, 0), wh + Vector3(-0.25, 0, 0)], 0.06)
		var q := _cam.unproject_position(_room.to_global(pel + Vector3(0, 0.22, 0)))
		if q.y > vs.y + 10.0:
			break
		look.y += 0.04


func _draw_legend(vs: Vector2) -> void:
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 420, 24, 840, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for s in 4:
		var who: Node3D = _chars[s]
		if s in [1, 2] and _friends.size() == 2:
			who = _friends[s - 1][0]
		Room.bubble(_ui, _cam, who, _bubbles[s], 90.0, 120.0)
	if _phase != "otsikko":
		return
	_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.01, 0.4 * clampf(_t / 0.8, 0.0, 1.0)))
	var a := clampf((_t - 0.5) / 0.8, 0.0, 1.0)
	var x0 := vs.x * 0.2
	var w := vs.x * 0.6
	var y := vs.y * 0.2
	var title := "LÖYLYKUNKKU"
	# Höyry nousee kirjaimista: läpikuultavat kiehkurat kohoavat ja haihtuvat.
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 78).x
	var tx := x0 + (w - tw) / 2.0
	for i in 14:
		var ph := fmod(_t * 0.45 + i * 0.37, 1.0)
		var px := tx + tw * fmod(i * 0.618, 1.0) + sin(_t * 1.7 + i) * 10.0
		var py := y - 50.0 - ph * 90.0
		_ui.draw_circle(Vector2(px, py), 10.0 + ph * 18.0, Color(1, 1, 1, 0.16 * (1.0 - ph) * a))
	_ui.draw_string_outline(font, Vector2(x0, y), title, HORIZONTAL_ALIGNMENT_CENTER, w, 78, 10, Color(0.1, 0.05, 0.0, a))
	_ui.draw_string(font, Vector2(x0, y), title, HORIZONTAL_ALIGNMENT_CENTER, w, 78, Color(1.0, 0.82, 0.35, a))
	var sr := Rect2(x0, vs.y - 170.0, w, 96)  # alareunaan: kasvot jäävät otsikon ja laatikon väliin
	_ui.draw_rect(sr, Color(0.05, 0.04, 0.03, 0.75 * a))
	var sub := "%d löylyä. %s" % [_heat, String(lines.legenda.sub)]
	_ui.draw_multiline_string(font, sr.position + Vector2(18, 34), sub, HORIZONTAL_ALIGNMENT_CENTER, w - 36, 20, 4,
		Color(1.0, 0.94, 0.8, a))


# --- Testi (tools/testit/iltakivat_kuvat.gd) ----------------------------------------------------------------------

func test_target() -> Array:
	var c: Node3D = _chars[0]
	return [c.to_global(c.bone_position("Head")), 0.11]


func test_closeup() -> void:
	var p := Vector3(SEAT_X[0], BENCH_TOP + 0.55, 0.3)
	var eye := p + Vector3(0.25, 0.1, 1.2)
	_cam_base = Transform3D(Basis.looking_at(p - eye, Vector3.UP), eye)
	_cam.transform = _cam_base


## Läpimenotarkistuksen keskipiste (iltakivat_kuvat.gd käyttää CENTERiä, jos test_target puuttuu).
func _hall_center() -> Vector3:
	return _room.to_global(CENTER)


## Lähikuva naisesta ja kauhasta kesken heiton (kuppi kiukaan yllä kallistumassa): saunavaatteet ja kauha.
func test_closeup2() -> void:
	_throw_anim = 0.82
	var p := Vector3(0.45, 1.25, 0.9)
	var eye := p + Vector3(0.75, 0.25, 1.25)
	_cam_base = Transform3D(Basis.looking_at(p - eye, Vector3.UP), eye)
	_cam.transform = _cam_base
