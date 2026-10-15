extends Node3D
## Lavatanssit Oulujärven lavalla (vaala.gd _build_lava): 90-luvun lauantai-illan tanssit. Pohjoispäässä on
## tanssipuoli, jossa humppabändi soittaa lavalla ja seinän vieressä on baari; eteläpää väliseinän takana on
## diskopuoli, jossa nuorempi porukka hyppii DJ:n ja peilipallon alla. Pelaaja hakee parin jommallakummalla puolella
## ja tanssii: A ja D vuorotellen tahdissa (sykkivä tahtimerkki; diskossa tahti on nopeampi). Osumat tahtiin pitävät
## tanssin kauniina, hutit ja räpellys horjuttavat. Baarista saa tuopin (bar, main.gd hoitaa rahat). Kappaleen
## jälkeen danced(score, mode) ja takaisin saliin (uusi tanssi tai baaritiski); Q:lla lavalta ulos, jolloin
## finished(illan paras tanssi 0..1, -1 = ei tanssittu); kutsuja antaa moraalit ja poistaa solmun. Solmu sijoitetaan lavan lattian keskelle
## (+z = etelään, lava 34 x 44 m, esiintymislava pohjoispäädyssä, ovi door_side-puolen kyljessä).

signal finished(score: float)
signal danced(score: float, mode: String)
## TV-kuvaus (Kesäillan valssi): kesken tanssin TV-kamera ottaa kuvan parista (oma kamera, ei käyttöliittymää).
signal tv_shot(tex: Texture2D)

const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const Headphones := preload("res://scripts/headphones.gd")
const Synth := preload("res://scripts/humppa_synth.gd")

const BPM := 104.0
const DISCO_BPM := 126.0
const SONG := 28.0       # s
const WINDOW := 0.16     # osuman sallittu poikkeama tahdista (s)
const COUPLES := 11
const YOUTH := 12
const BAND := "OULUJÄRVEN HUMPPAVEIKOT"
## Esiintyjä (main.gd voi vaihtaa: juhannuksena isompi bändi).
var band := BAND
const JUHANNUS_BAND := "VAALAN TÄHTIORKESTERI"
## Juhannustanssit (main.gd): isompi bändi puhaltimineen ja taustalaulajineen, koivunoksat ja tupaten täysi lattia.
var juhannus := false
## TV-kuvaus: kameraryhmä tanssilattian laidalla, ja tanssista otetaan kuva lähetykseen (tv_shot).
var tv := false
var _tv_cam_pos := Vector3(7.5, 1.7, 7.0)
var _tv_taken := false
const SONGS := ["Humppa Oulujärven rannalla", "Letkajenkka", "Vaalan humppa", "Säkkijärven polkka humpaten",
	"Kesäillan valssi"]
const DISCO_SONGS := ["90-luvun eurodance-mix", "Teknohumppa (DJ-remix)", "Bilebiisi Oulusta", "Lavan disko-medley"]
const PARTNER_LINES := ["Tanssitaanko?", "Hyvin vie!", "Ootko käyny ennenki lavalla?", "Ihana ilta!", "Varo varpaita!"]
const DISCO_LINES := ["Tuu tanssiin!", "Ihan sika hyvä biisi!", "Ootko sää Vaalasta?", "Hyppää!", "Kova meininki!"]
const DISCO_Z := 8.0     # väliseinä: pohjoisessa tanssipuoli, etelässä disko
## Lavan mitat (main.gd asettaa vaala.gd:n datasta ennen add_childia: tie.json lava.w ja lava.l).
var W := 28.0
var L := 36.0

var courage := 0.0  # pontikkahuikka ennen lavaa (main.gd): leveämpi tahti-ikkuna, mutta kompastelee
## Seuralainen (Santtu tuli mopon takana): tanssii vieressä omalla parillaan. Tyhjä = yksin.
var buddy := {}
var _buddy: Node3D
var door_side := 1.0  # ovi itä- (1) vai länsikyljessä (-1); baari vastakkaiselle seinälle
## Baarin tilaus (main.gd): palauttaa [repliikki, tieto], rahat ja humala hoidetaan kutsujan puolella.
var bar := Callable()
var _mode := "humppa"  # humppa | disco
var _phase := "intro"  # intro | dance | result
var _t := 0.0
var _beat := 60.0 / BPM
var _next := "left"
var _hits := 0
var _misses := 0
var _last_press := -1.0
var _song := ""
var _best := -1.0  # illan paras tanssi

var _cam: Camera3D
var _prev_cam: Camera3D
var _me: Node3D
var _partner: Node3D
var _dancers: Array[Node3D] = []
var _layer: CanvasLayer
var _title: Label
var _info: Label
var _pulse: Panel
var _score_bar: ProgressBar
var _bubble: Label3D
var _youth: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _ball: Node3D
var _bartender: Node3D
var _band: Node3D  # vaala.gd:n lavabändi (humppa_band.gd); null testeissä ilman Vaalaa
var _menu := -1  # toivelistan valinta (-1 = lista kiinni)
var _wish := ""  # pelaajan toivoma kappale (soi seuraavaksi)


func _ready() -> void:
	_prev_cam = get_viewport().get_camera_3d()
	_song = SONGS.pick_random()
	var vl := get_parent()
	if vl != null and vl.has_method("set_lava_live") and vl.lava_band != null:
		_band = vl.lava_band
		vl.set_lava_live(true, true)
		if _band.juhannus != juhannus or _band.band_name != band:
			_band.juhannus = juhannus
			_band.band_name = band
			_band.build()
		_band.song_started.connect(_on_band_song)
	_build_props()
	_spawn_people()
	_cam = Camera3D.new()
	_cam.fov = 60.0
	add_child(_cam)
	_cam.current = true
	_build_hud()
	_title.text = "OULUJÄRVEN LAVA"
	_intro_text()
	if _band != null:
		if _band.current_song.is_empty():
			_band.request(Synth.SONGS.pick_random())
		else:
			_on_band_song(_band.current_song, _band._player.stream)
	else:
		Sfx.music_play(1.0)


func _intro_text(extra := "") -> void:
	var head := "Juhannustanssit" if juhannus else "Lauantain tanssit"
	_info.text = "%s%s: %s soittaa \"%s\".%s\nVäliseinän takana diskopuoli nuorisolle.\nTanssi: vuorottele %s ja %s tahtimerkin tahdissa.\n\n%s Hae pari tanssipuolelta\n%s Diskopuolelle\n%s Baaritiskiltä tuoppi (6,50 €)\n%s Toivo bändiltä humppaa\n%s Lavalta ulos" % [
		extra, head, band.capitalize(), _song, "\nTV kuvaa: Kesäillan valssi! Hyvä tanssi pääsee lähetykseen." if tv else "",
		Settings.action_key("left"), Settings.action_key("right"), Settings.cap("interact"),
		Settings.cap("mount"), Settings.cap("eat"), Settings.cap("forward"), Settings.cap("bell")]


## Tanssipuolen baari, väliseinä ja diskopuolen DJ-koppi, peilipallo ja värivalot (lava itse: vaala.gd _build_lava).
func _build_props() -> void:
	var dark := Color(0.12, 0.1, 0.12)
	var wood := Color(0.42, 0.26, 0.16)
	# Bändin banderolli lavan takaseinään (kangas, ei irtotekstiä).
	var banner := B.sign_plate(self, band, Color(0.55, 0.06, 0.08), Color(1.0, 0.86, 0.35), 0.45, 64, Color(0.3, 0.03, 0.04))
	banner.position = Vector3(0, 3.95, -L / 2.0 + 0.75)
	# Baari: tiski vastapäätä ovea tanssipuolen keskivaiheilla, hyllyt pulloineen seinällä.
	var bx := -door_side * (W / 2.0 - 1.6)
	B.mesh(self, B.boxm(Vector3(0.8, 1.1, 8.0)), Vector3(bx, 0.55, -4.0), wood)
	B.mesh(self, B.boxm(Vector3(1.0, 0.06, 8.2)), Vector3(bx, 1.13, -4.0), Color(0.25, 0.15, 0.1))
	var shelf_x := -door_side * (W / 2.0 - 0.35)
	for k in 2:
		B.mesh(self, B.boxm(Vector3(0.35, 0.05, 6.0)), Vector3(shelf_x, 1.5 + k * 0.55, -4.0), wood)
		for b in 14:
			var col: Color = [Color(0.2, 0.45, 0.15), Color(0.5, 0.3, 0.08), Color(0.85, 0.85, 0.9), Color(0.55, 0.1, 0.1)][(b + k) % 4]
			B.mesh(self, B.cyl(0.04, 0.045, 0.3, 8), Vector3(shelf_x, 1.68 + k * 0.55, -6.6 + b * 0.4), col)
	var bar_sign := B.sign_plate(self, "BAARI", Color(0.25, 0.12, 0.06), Color(1.0, 0.92, 0.7), 0.45, 56, Color(0.12, 0.06, 0.03))
	bar_sign.position = Vector3(shelf_x + door_side * 0.12, 2.75, -4.0)
	bar_sign.rotation.y = door_side * PI / 2.0
	for k in 4:
		B.mesh(self, B.cyl(0.2, 0.2, 0.06, 12), Vector3(bx + door_side * 0.75, 0.75, -6.8 + k * 1.8), Color(0.6, 0.1, 0.1))
		B.mesh(self, B.cyl(0.04, 0.04, 0.72, 6), Vector3(bx + door_side * 0.75, 0.36, -6.8 + k * 1.8), Color(0.6, 0.6, 0.62))
	if juhannus:
		# Koivunoksat esiintymislavan kulmiin ja oven pieliin, juhannusbanderolli.
		for q in [Vector3(-6.5, 1.0, -L / 2.0 + 4.6), Vector3(6.5, 1.0, -L / 2.0 + 4.6), Vector3(door_side * (W / 2.0 - 0.8), 0.0, -1.5),
				Vector3(door_side * (W / 2.0 - 0.8), 0.0, 1.5)]:
			B.mesh(self, B.cyl(0.05, 0.08, 2.6, 6), q + Vector3(0, 1.3, 0), Color(0.92, 0.92, 0.88))
			for k in 6:
				B.mesh(self, B.sphere(0.45, 6), q + Vector3(sin(k * 1.7) * 0.3, 1.9 + k * 0.18, cos(k * 1.7) * 0.3),
					Color(0.35, 0.6, 0.2).lightened(0.05 * k))
		var jb := B.sign_plate(self, "HYVÄÄ JUHANNUSTA!", Color(0.95, 0.95, 0.9), Color(0.15, 0.45, 0.2), 0.4, 56, Color(0.2, 0.5, 0.25))
		jb.position = Vector3(0, 4.55, -L / 2.0 + 0.8)
	if tv:
		_build_tv_crew()
	# Väliseinä, oviaukko keskellä ja neonkyltti.
	for sx in [-1.0, 1.0]:
		B.mesh(self, B.boxm(Vector3(W / 2.0 - 1.6, 3.0, 0.15)), Vector3(sx * (W / 4.0 + 0.8), 1.5, DISCO_Z), dark)
	B.mesh(self, B.boxm(Vector3(3.2, 0.6, 0.15)), Vector3(0, 2.75, DISCO_Z), dark)
	var neon := B.sign_plate(self, "DISKO", Color(0.08, 0.04, 0.1), Color(1.0, 0.3, 0.9), 0.5, 72, Color(1.0, 0.2, 0.8))
	neon.position = Vector3(0, 2.75, DISCO_Z - 0.1)
	neon.rotation.y = PI  # luetaan tanssipuolelta
	# Diskon lattia tummaksi, DJ-koppi eteläpäätyyn.
	B.mesh(self, B.boxm(Vector3(W - 0.6, 0.02, L / 2.0 - DISCO_Z - 0.4)), Vector3(0, 0.075, (DISCO_Z + L / 2.0) / 2.0), Color(0.16, 0.14, 0.2))
	var dj := Vector3(0, 0, L / 2.0 - 1.6)
	B.mesh(self, B.boxm(Vector3(4.0, 1.1, 1.2)), dj + Vector3(0, 0.55, 0), Color(0.1, 0.1, 0.12))
	for x in [-0.8, 0.8]:
		B.mesh(self, B.cyl(0.3, 0.3, 0.04, 16), dj + Vector3(x, 1.13, 0), Color(0.05, 0.05, 0.05))
	for x in [-2.6, 2.6]:
		B.mesh(self, B.boxm(Vector3(1.0, 1.8, 0.8)), dj + Vector3(x, 0.9, 0.1), Color(0.08, 0.08, 0.09))
	B.label(self, "DJ", dj + Vector3(0, 0.6, -0.62), 64, Color(0.3, 1.0, 1.0)).rotation.y = PI
	# Peilipallo ja pyörivät värivalot.
	_ball = Node3D.new()
	_ball.position = Vector3(0, 3.4, (DISCO_Z + L / 2.0) / 2.0)
	add_child(_ball)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.85, 0.85, 0.9)
	bm.metallic = 1.0
	bm.roughness = 0.15
	var sphere := MeshInstance3D.new()
	sphere.mesh = B.sphere(0.45, 10)
	sphere.material_override = bm
	_ball.add_child(sphere)
	for k in 4:
		var li := OmniLight3D.new()
		li.light_color = [Color(1, 0.1, 0.6), Color(0.2, 0.4, 1), Color(0.1, 1, 0.4), Color(1, 0.8, 0.1)][k]
		li.light_energy = 2.5
		li.omni_range = 9.0
		li.position = Vector3(-9.0 + k * 6.0, 3.0, (DISCO_Z + L / 2.0) / 2.0)
		add_child(li)
		_lights.append(li)


## TV-ryhmä tanssilattian laidalla: kamera jalustalla, kuvaaja, äänimies puomimikin kanssa, valo ja kyltti.
func _build_tv_crew() -> void:
	var c := _tv_cam_pos
	for k in 3:  # jalusta
		var a := TAU * k / 3.0
		B.mesh(self, B.cyl(0.02, 0.02, 1.4, 6), Vector3(c.x + cos(a) * 0.25, 0.65, c.z + sin(a) * 0.25), Color(0.15, 0.15, 0.15))
	var cam := Node3D.new()
	cam.position = c
	add_child(cam)
	B.mesh(cam, B.boxm(Vector3(0.3, 0.32, 0.7)), Vector3.ZERO, Color(0.12, 0.12, 0.13))
	B.mesh(cam, B.cyl(0.1, 0.12, 0.3, 12), Vector3(0, 0, -0.45), Color(0.05, 0.05, 0.06)).rotation.x = PI / 2.0
	B.mesh(cam, B.boxm(Vector3(0.05, 0.05, 0.05)), Vector3(0.1, 0.2, 0.25), Color(1, 0.1, 0.1))  # REC-valo
	cam.look_at(to_global(Vector3(0, 1.2, 2.0)), Vector3.UP)
	var looks := [{"shirt": Color(0.2, 0.2, 0.22), "pants": Color(0.3, 0.3, 0.35), "hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.25, 0.2),
		"height": 1.8}, {"shirt": Color(0.85, 0.85, 0.8), "pants": Color(0.2, 0.2, 0.25), "hair": "Hair_SimpleParted",
		"hair_color": Color(0.5, 0.4, 0.3), "height": 1.76}]
	var crew := Looks.make(self, looks[0])
	crew.position = c + Vector3(0.6, -1.7, 0.6)
	crew.look_at(to_global(Vector3(0, crew.position.y, 2.0)), Vector3.UP)
	crew.play("Idle", 0.0)
	var sound := Looks.make(self, looks[1])
	sound.position = c + Vector3(-1.4, -1.7, -0.6)
	sound.look_at(to_global(Vector3(0, sound.position.y, 2.0)), Vector3.UP)
	sound.play("Idle", 0.0)
	B.mesh(self, B.cyl(0.015, 0.015, 2.6, 6), c + Vector3(-2.0, 0.6, -1.2), Color(0.3, 0.3, 0.3)).rotation.z = 1.0  # puomi
	B.mesh(self, B.cyl(0.03, 0.03, 2.6, 6), c + Vector3(1.6, -0.4, -1.0), Color(0.2, 0.2, 0.2))  # valojalka
	var spot := SpotLight3D.new()
	spot.position = c + Vector3(1.6, 1.0, -1.0)
	spot.light_energy = 3.0
	spot.spot_range = 16.0
	spot.light_color = Color(1.0, 0.95, 0.85)
	add_child(spot)
	spot.look_at(to_global(Vector3(0, 0.5, 2.0)), Vector3.UP)
	var tvs := B.sign_plate(self, "KESÄILLAN VALSSI · TV", Color(0.1, 0.15, 0.35), Color(1.0, 1.0, 0.7), 0.3, 40, Color(0.9, 0.9, 0.5))
	tvs.position = c + Vector3(0, 0.45, 0.0)
	tvs.look_at(to_global(Vector3(0, tvs.position.y, 2.0)), Vector3.UP)
	tvs.rotate_y(PI)


## Tanssin keskellä TV-kameran kuva parista: oma näkymä samaan maailmaan (ilman käyttöliittymää) kuvaksi.
func _capture_tv() -> void:
	_tv_taken = true
	var sv := SubViewport.new()
	sv.size = Vector2i(640, 400)
	sv.world_3d = get_viewport().world_3d
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var cam := Camera3D.new()
	cam.fov = 38.0
	sv.add_child(cam)
	var focus := to_global((_me.position + _partner.position) / 2.0 + Vector3(0, 1.1, 0))
	var eye := to_global(_tv_cam_pos)
	cam.look_at_from_position(eye + (focus - eye).normalized() * 1.0, focus)  # linssin edestä, ei oman kameran läpi
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	sv.queue_free()
	if img != null:
		tv_shot.emit(ImageTexture.create_from_image(img))


func _spawn_people() -> void:
	var shirts := [Color(0.85, 0.2, 0.3), Color(0.2, 0.35, 0.75), Color(0.95, 0.85, 0.3), Color(0.25, 0.55, 0.3),
		Color(0.95, 0.95, 0.95), Color(0.5, 0.2, 0.55), Color(0.15, 0.15, 0.17), Color(0.85, 0.5, 0.2)]
	var hairs := ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Long", "Hair_Buns"]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Baarimikko tiskin takana.
	_bartender = Looks.make(self, {"shirt": Color(0.95, 0.95, 0.95), "pants": Color(0.1, 0.1, 0.12), "hair": "Hair_Buzzed",
		"hair_color": Color(0.2, 0.15, 0.1), "height": 1.78})
	_bartender.position = Vector3(-door_side * (W / 2.0 - 1.0), 0.06, -4.0)
	_bartender.rotation.y = door_side * PI / 2.0
	_bartender.play("Idle", 0.0)
	# Pari asiakasta tiskillä.
	for k in 2:
		var c := Looks.make(self, {"shirt": shirts[(k * 5 + 1) % shirts.size()], "pants": Color(0.2, 0.2, 0.3),
			"hair": hairs[(k + 1) % hairs.size()], "hair_color": Color(0.35, 0.25, 0.12), "height": 1.78})
		c.position = Vector3(-door_side * (W / 2.0 - 2.6), 0.06, -6.0 + k * 3.2)
		c.rotation.y = -door_side * PI / 2.0
		c.play("Idle_Talking", 0.0)
	# Diskopuolen nuoret: kirkkaat värit, lippikset, hyppivät nopeammin.
	var neon := [Color(1.0, 0.2, 0.6), Color(0.1, 0.9, 0.9), Color(0.6, 1.0, 0.1), Color(1.0, 0.6, 0.0), Color(0.5, 0.2, 1.0),
		Color(0.95, 0.95, 0.95)]
	for k in YOUTH:
		var y := Looks.make(self, {"model": "female" if k % 2 == 1 else "male", "shirt": neon[rng.randi() % neon.size()],
			"pants": Color(0.15, 0.2, 0.45), "hair": hairs[rng.randi() % hairs.size()],
			"hair_color": Color(rng.randf_range(0.1, 0.9), rng.randf_range(0.08, 0.7), 0.1), "height": rng.randf_range(1.6, 1.8)})
		if k % 3 == 0:
			Looks.add_cap(y)
		y.position = Vector3(rng.randf_range(-13.0, 13.0), 0.08, rng.randf_range(DISCO_Z + 2.5, L / 2.0 - 3.5))
		y.rotation.y = rng.randf_range(-PI, PI)
		y.play("Dance", 0.0, rng.randf_range(1.2, 1.5))
		_youth.append(y)
	# Parit tanssipuolella.
	for k in (COUPLES * 2 if juhannus else COUPLES):
		var at := Vector3(rng.randf_range(-11.0, 11.0), 0.06, rng.randf_range(-13.0, DISCO_Z - 2.0))
		if at.length() < 4.0:
			at += at.normalized() * 4.0
		for s in 2:
			var look := {"model": "female" if s == 1 else "male", "shirt": shirts[rng.randi() % shirts.size()],
				"pants": Color(0.15, 0.15, 0.25) if s == 0 else shirts[rng.randi() % shirts.size()],
				"hair": hairs[rng.randi() % hairs.size()], "hair_color": Color(rng.randf_range(0.1, 0.8), rng.randf_range(0.08, 0.6), 0.1),
				"height": 1.8 if s == 0 else 1.66}
			var d := Looks.make(self, look)
			d.position = at + Vector3(0, 0, 0.45 if s == 0 else -0.45)
			d.rotation.y = 0.0 if s == 0 else PI
			d.play("Dance", 0.0, rng.randf_range(0.8, 1.1))
			_dancers.append(d)
	if not buddy.is_empty():
		_buddy = Looks.make(self, buddy)
		_buddy.position = Vector3(-2.5, 0.06, 2.6)
		_buddy.play("Dance", 0.0, 0.95)
		var bp := Looks.make(self, {"model": "female", "shirt": Color(0.95, 0.8, 0.3), "pants": Color(0.2, 0.2, 0.3),
			"hair": "Hair_Long", "hair_color": Color(0.5, 0.3, 0.15), "height": 1.66})
		bp.position = _buddy.position + Vector3(0, 0, -0.5)
		bp.rotation.y = PI
		bp.play("Dance", 0.0, 0.95)
		B.label(self, "Santtu", _buddy.position + Vector3(0, 2.2, 0), 24, Color(0.45, 0.75, 1.0), true).pixel_size = 0.005
	_me = Looks.make(self, Looks.PLAYER)
	_me.position = Vector3(0, 0.06, 2.0)
	_me.play("Idle", 0.0)
	_partner = Looks.make(self, {"model": "female", "shirt": Color(0.9, 0.25, 0.4), "pants": Color(0.12, 0.12, 0.2),
		"hair": "Hair_Long", "hair_color": Color(0.8, 0.65, 0.35), "height": 1.66})
	_partner.position = Vector3(1.6, 0.06, 0.6)
	_partner.rotation.y = -0.8
	_partner.play("Idle", 0.0)
	_bubble = B.bubble(self, Vector3(1.6, 2.2, 0.6), Color(1, 1, 0.85))


func _process(delta: float) -> void:
	_t += delta
	# Kamera kiertää hitaasti paria.
	var a := _t * 0.12
	var focus := (_me.position + _partner.position) / 2.0 + Vector3(0, 1.2, 0)
	_cam.look_at_from_position(to_global(focus + Vector3(sin(a) * 6.0, 2.2, cos(a) * 6.0)), to_global(focus))
	# Disko: peilipallo pyörii, värivalot sykkivät ja kiertävät.
	_ball.rotation.y += delta * 1.2
	for k in _lights.size():
		var li := _lights[k]
		li.light_energy = 1.5 + 2.0 * absf(sin(_t * 4.2 + k * 1.3))
		li.position.x = sin(_t * 0.8 + k * 1.6) * 11.0
	match _phase:
		"intro":
			if _menu >= 0:
				_menu_input()
			elif Input.is_action_just_pressed("forward") and _band != null:
				_menu = 0
				_show_menu()
			elif Input.is_action_just_pressed("interact"):
				_start_dance("humppa")
			elif Input.is_action_just_pressed("mount"):
				_start_dance("disco")
			elif Input.is_action_just_pressed("eat"):
				_order()
			elif Input.is_action_just_pressed("bell"):
				_leave()
		"dance":
			_dance(delta)
		"result":
			if Input.is_action_just_pressed("interact"):
				_back_to_hall()
			elif Input.is_action_just_pressed("bell"):
				_leave()


func _leave() -> void:
	Sfx.music_stop(1.0)
	var vl := get_parent()
	if _band != null and vl != null and vl.has_method("set_lava_live"):
		_band.song_started.disconnect(_on_band_song)
		vl.set_lava_live(true)  # bändi jatkaa, humppa kuuluu taas pihalle
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.current = true
	_layer.queue_free()
	finished.emit(_best)


## Kappaleen jälkeen takaisin saliin: pari jää lattialle, pelaaja kävelee baaritiskin suuntaan, ja valikossa on
## uusi tanssi, diskopuoli, baari tai lähtö.
func _back_to_hall() -> void:
	_phase = "intro"
	_tv_taken = false
	_t = 0.0
	_hits = 0
	_misses = 0
	_next = "left"
	_score_bar.value = 0.0
	_title.text = "OULUJÄRVEN LAVA"
	if _mode == "disco":
		_mode = "humppa"
		_beat = 60.0 / BPM
		if _band == null:
			Sfx.music_play(1.0)
	if _band != null:
		# Bändi soittaa seuraavan: toive, jos sellainen on, muuten jokin muu listalta.
		var next: Dictionary = _wish_song() if _wish != "" else Synth.SONGS.filter(func(sg: Dictionary) -> bool:
			return sg.title != _band.current_song.get("title", "")).pick_random()
		_wish = ""
		_band.request(next)
	else:
		_song = SONGS.pick_random()
	_me.position = Vector3(-door_side * (W / 2.0 - 3.2), 0.06, -4.0)  # tiskin edessä
	_me.rotation.y = -door_side * PI / 2.0 + PI
	_me.play("Idle", 0.3)
	_partner.position = Vector3(1.6, 0.06, 0.6)
	_partner.play("Idle", 0.3)
	_intro_text("Tanssi on tanssittu. Baaritiski on tuossa, ja bändi soittaa jo seuraavaa.\n")


## Pari haetaan tanssipuolelta (humppa) tai diskosta (nuorempi pari, nopeampi tahti).
func _start_dance(mode: String) -> void:
	_mode = mode
	_phase = "dance"
	_t = 0.0
	if mode == "humppa" and _band != null:
		_beat = 60.0 / _band.bpm  # tahti bändin soittamasta kappaleesta
	if mode == "disco":
		_beat = 60.0 / DISCO_BPM
		_song = DISCO_SONGS.pick_random()
		_me.position = Vector3(0, 0.08, (DISCO_Z + L / 2.0) / 2.0)
		_partner.queue_free()
		_partner = Looks.make(self, {"model": "female", "shirt": Color(0.1, 0.9, 0.9), "pants": Color(0.15, 0.2, 0.45),
			"hair": "Hair_Buns", "hair_color": Color(0.85, 0.7, 0.4), "height": 1.65})
		_title.text = "LAVAN DISKO"
		var track := Headphones.random_90s_path()  # DJ soittaa 90-luvun eurodancea
		if track != "":
			Sfx.music_play(0.8, 0.0, track)
			_song = Headphones.song_title(track)
	_partner.position = _me.position + Vector3(0, 0, -0.5)
	_partner.rotation.y = PI
	_me.rotation.y = 0.0
	_me.play("Dance", 0.2, 1.3 if mode == "disco" else 1.0)
	_partner.play("Dance", 0.2, 1.3 if mode == "disco" else 1.0)
	_say((DISCO_LINES if mode == "disco" else PARTNER_LINES)[0])
	_info.text = "%s ja %s vuorotellen, kun tahtimerkki sykähtää." % [Settings.action_key("left"), Settings.action_key("right")]


# --- Toivekappaleet -----------------------------------------------------------------------------------------------

func _wish_song() -> Dictionary:
	for sg in Synth.SONGS:
		if sg.title == _wish:
			return sg
	return Synth.SONGS[0]


func _show_menu() -> void:
	var lines: Array[String] = []
	for i in Synth.SONGS.size():
		lines.append(("▶ " if i == _menu else "   ") + Synth.SONGS[i].title)
	_info.text = "Laulaja kumartuu lavan reunalle: \"No, mitäs soitetaan?\"\n\n%s\n\n%s valitse · %s toivo · %s peruuta" % [
		"\n".join(lines), Settings.pair("forward", "back"), Settings.cap("interact"), Settings.cap("bell")]


func _menu_input() -> void:
	if Input.is_action_just_pressed("forward"):
		_menu = posmod(_menu - 1, Synth.SONGS.size())
		_show_menu()
	elif Input.is_action_just_pressed("back"):
		_menu = posmod(_menu + 1, Synth.SONGS.size())
		_show_menu()
	elif Input.is_action_just_pressed("interact"):
		request_song(_menu)
	elif Input.is_action_just_pressed("bell"):
		_menu = -1
		_intro_text()


## Toive bändille: kappale alkaa heti (bändi vaihtaa lennosta), ja sen tahtiin tanssitaan.
func request_song(i: int) -> void:
	var sg: Dictionary = Synth.SONGS[clampi(i, 0, Synth.SONGS.size() - 1)]
	_menu = -1
	if _band == null:
		return
	_wish = ""
	_song = sg.title
	_intro_text("Laulaja: \"%s! Tämä on teille, Paapelin suunnalta tullut ystävä!\"\n" % sg.title)
	_band.request(sg)


## Bändi aloitti kappaleen: sama ääni musiikkina sisällä, tanssin tahti kappaleen tempoon.
func _on_band_song(song: Dictionary, stream: AudioStream) -> void:
	_song = song.title
	if _mode == "humppa" and _phase != "dance":
		_beat = 60.0 / float(song.bpm)
	if not (_mode == "disco" and _phase == "dance") and stream != null:
		Sfx.music_play(0.6, 0.0, "humppa:" + Synth.song_key(song), stream)
	if _phase == "intro" and _menu < 0:
		_intro_text()


## Baari: tuoppi tiskiltä (rahat ja humala main.gd:ssä), baarimikko kuittaa.
func _order() -> void:
	if not bar.is_valid():
		return
	var r: Array = bar.call()
	_bartender.play("Idle_Talking", 0.2)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func() -> void: _bartender.play("Idle", 0.3))
	_intro_text("Baarimikko: \"%s\" %s\n" % [r[0], r[1]])


func _dance(_delta: float) -> void:
	var phase := fmod(_t, _beat) / _beat
	var near := minf(phase, 1.0 - phase) * _beat  # etäisyys lähimpään iskuun (s)
	_pulse.modulate.a = clampf(1.0 - phase * 2.5, 0.15, 1.0)
	_pulse.scale = Vector2.ONE * (1.0 + (1.0 - phase) * 0.35)
	var left := Input.is_action_just_pressed("left")
	var right := Input.is_action_just_pressed("right")
	if left or right:
		var ok := (left and _next == "left") or (right and _next == "right")
		var hasty := _t - _last_press < _beat * 0.5
		_last_press = _t
		var stumble := courage > 0.0 and randf() < 0.12 * courage
		if ok and near < WINDOW + 0.06 * courage and not hasty and not stumble:
			_hits += 1
			_next = "right" if _next == "left" else "left"
			if _hits % 12 == 0:
				_say((DISCO_LINES if _mode == "disco" else PARTNER_LINES).pick_random())
		else:
			_misses += 1
			_me.rotation.y += randf_range(-0.3, 0.3) * (2.0 if stumble else 1.0)
			if stumble:
				_say("Hups! Pontikka vie jalat.")
			if _misses % 5 == 0:
				_say("Auts! Varpaat!")
				Sfx.play("grunt", -6.0)
	_me.rotation.y = lerp_angle(_me.rotation.y, 0.0, 0.05)
	if tv and not _tv_taken and _mode == "humppa" and _t > SONG * 0.5:
		_capture_tv()
	# Pari pyörii hitaasti lattialla.
	var turn := _t * 0.35
	var base := Vector3(0, 0.08, (DISCO_Z + L / 2.0) / 2.0) if _mode == "disco" else Vector3(0, 0.06, 2.0)
	_me.position = base + Vector3(sin(turn) * 1.2, 0, cos(turn) * 1.2)
	_partner.position = _me.position + Vector3(0, 0, -0.5).rotated(Vector3.UP, _me.rotation.y)
	_score_bar.value = _score() * 100.0
	_info.text = "%s · tahtiin %d, hutia %d · seuraavaksi %s" % [_song, _hits, _misses, Settings.action_key(_next)]
	if _t >= SONG:
		_phase = "result"
		var s := _score()
		_best = maxf(_best, s)
		danced.emit(s, _mode)
		_me.play("Idle", 0.4)
		_partner.play("Idle", 0.4)
		_say("Kiitos tanssista!" if s > 0.5 else "No... kiitos.")
		_title.text = "KAPPALE PÄÄTTYI"
		if _buddy != null:
			_say("Santtu: \"Kyllä kannatti tulla!\"" if s > 0.45 else "Santtu: \"Hyvin se meni. Melkein.\"")
		_info.text = (("Diskon kunkku! Nuoret hurraa." if _mode == "disco" else "Humppasit kuin Humppaveikot itse! Parisi hymyilee.") if s > 0.75 else
			("Ihan kelpo tanssi." if s > 0.45 else "Varpaat kärsivät, mutta ilta oli hauska.")) + \
			"\n\n%s Takaisin saliin (tanssi, baaritiski)\n%s Lavalta ulos" % [Settings.cap("interact"), Settings.cap("bell")]


func _score() -> float:
	var expected := maxf(_t / _beat * 0.8, 1.0)
	return clampf((_hits - _misses * 0.6) / expected, 0.0, 1.0)


func _say(text: String) -> void:
	_bubble.text = text
	_bubble.position = _partner.position + Vector3(0, 2.15, 0)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func() -> void: _bubble.text = "")


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 15
	add_child(_layer)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 10)
	_title.position = Vector2(40, 30)
	_layer.add_child(_title)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 22)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 7)
	_info.position = Vector2(40, 95)
	_layer.add_child(_info)
	_pulse = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.8, 0.2)
	sb.set_corner_radius_all(40)
	_pulse.add_theme_stylebox_override("panel", sb)
	_pulse.size = Vector2(80, 80)
	_pulse.pivot_offset = Vector2(40, 40)
	_pulse.anchor_left = 0.5
	_pulse.anchor_right = 0.5
	_pulse.anchor_top = 1.0
	_pulse.anchor_bottom = 1.0
	_pulse.offset_left = -40
	_pulse.offset_right = 40
	_pulse.offset_top = -170
	_pulse.offset_bottom = -90
	_layer.add_child(_pulse)
	_score_bar = ProgressBar.new()
	_score_bar.show_percentage = false
	_score_bar.anchor_left = 0.5
	_score_bar.anchor_right = 0.5
	_score_bar.anchor_top = 1.0
	_score_bar.anchor_bottom = 1.0
	_score_bar.offset_left = -160
	_score_bar.offset_right = 160
	_score_bar.offset_top = -70
	_score_bar.offset_bottom = -54
	_layer.add_child(_score_bar)
