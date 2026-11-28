extends Node3D
## Lavatanssit Oulujärven lavalla (vaala.gd _build_lava): 90-luvun lauantai-illan tanssit. Pohjoispäässä on
## tanssipuoli, jossa humppabändi soittaa lavalla ja seinän vieressä on baari; eteläpää väliseinän takana on
## diskopuoli, jossa nuorempi porukka hyppii DJ:n ja peilipallon alla. Pelaaja hakee parin jommallakummalla puolella
## ja tanssii: A ja D vuorotellen tahdissa (sykkivä tahtimerkki; diskossa tahti on nopeampi). Osumat tahtiin pitävät
## tanssin kauniina, hutit ja räpellys horjuttavat. Baarista saa tuopin (bar, main.gd hoitaa rahat). Kappaleen
## jälkeen danced(score, mode) ja takaisin saliin (uusi tanssi tai baaritiski); Q:lla lavalta ulos, jolloin
## finished(illan paras tanssi 0..1, -1 = ei tanssittu); kutsuja antaa moraalit ja poistaa solmun. Solmu sijoitetaan lavan lattian keskelle
## (+z = etelään, lava 34 x 44 m, esiintymislava pohjoispäädyssä, ovi door_side-puolen kyljessä).
## Toiveet: bändiltä voi toivoa iskelmän (humppa_band.gd repertoire, iskelmat.gd) ja DJ:ltä diskobiisin
## (headphones.gd disco_tracks); DJ:n toive alkaa heti diskotanssina.

signal finished(score: float)
signal danced(score: float, mode: String)
## TV-kuvaus (Kesäillan valssi): kesken tanssin TV-kamera ottaa kuvan parista (oma kamera, ei käyttöliittymää).
signal tv_shot(tex: Texture2D)

const Looks := preload("res://scripts/looks.gd")
const Shoes := preload("res://scripts/shoes.gd")
const B := preload("res://scripts/build.gd")
const Headphones := preload("res://scripts/headphones.gd")
const Band := preload("res://scripts/humppa_band.gd")
const MG := preload("res://scripts/mg_draw.gd")
const Pose := preload("res://scripts/pose.gd")
const Room := preload("res://scripts/ilta_room.gd")

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
var humppa_best := -1.0  # illan paras humppa (lavatanssit-hetki, main.gd _on_lava_finished)

var _cam: Camera3D
var _prev_cam: Camera3D
var _me: Node3D
var _partner: Node3D
var _dancers: Array[Node3D] = []
var _layer: CanvasLayer
var _title: Label
var _info: Label
var _pulse: Control  # tahtimerkki: kehä, johon lähestyvä rengas osuu iskulla, ja vuoronäppäimet
var _pops: Array = []  # palautetekstit: [teksti, väri, ikä]
var _hearts: Array = []  # sydän- ja kipinäpurskeet (MG.sparks_*)
var _flash := 0.0  # 1 = juuri osui, -1 = juuri huti (merkin väri)
var _shake := 0.0  # kameran tärähdys hutista
var _floor_tiles: Array[MeshInstance3D] = []  # diskon valolattia
var _floor_mats: Array[StandardMaterial3D] = []
var _floor_beat := -1
var _spots: Array[MeshInstance3D] = []  # pyörivät valotäplät diskon lattialla
var _score_bar: ProgressBar
var _bubble: Label3D
var _youth: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _ball: Node3D
var _bartender: Node3D
var _band: Node3D  # vaala.gd:n lavabändi (humppa_band.gd); null testeissä ilman Vaalaa
var _menu := -1  # toivelistan valinta (-1 = lista kiinni)
var _digit_prev := -1  # toivelistan numeronäppäin edellisellä ruudulla (vain painallus laukaisee)
var _menu_kind := "band"  # band = bändin iskelmät, dj = DJ:n diskobiisit
var _menu_items: Array = []  # bändi: kappaleet (repertoire), DJ: tiedostopolut
var _wish := ""  # pelaajan toivoma kappale (soi seuraavaksi)

# Legendaarinen hetki "lavatanssit" (endings.gd STAGED): illan ensimmäinen hyvä humppa (pisteet yli LEG_SCORE) ei pääty
# tavalliseen tulokseen, vaan laulaja pysäyttää lattian (kutsu), parit vetäytyvät piiriin taputtamaan (piiri), pari
# heittää jalkaa kuin nuorena ja vanha pari muistelee (potku), ja kultainen otsikko (otsikko). Toistoilla (recall)
# pari muistelee illan alussa. Kutsuja (main.gd _lava_start) asettaa legend ja recall endings-laskurista.
const LEG := ["kutsu", "piiri", "potku", "otsikko"]
const LEG_SCORE := 0.6  # sama raja kuin main.gd _on_lava_finished (lavatanssit-hetki)
const LEG_LINES := {
	"kutsu": "Seis, pojat! Vielä yks humppa, ja se soitetaan tuolle parille tuossa keskellä!",
	"pari": "Nyt näytetään niille, miten Oulujärvellä humpataan!",
	"ukko": "Kato äiti! Jalka nousee niinku meillä Vaalan lavalla -72!",
	"mummo": "Ei sulla noussu jalka -72, sulla nousi vaan tukka.",
	"kiitos": "Antakaa aplodit! Toi jalka nousi niinku nuorena!",
	"sub": "Humppaveikot soitti viimeisen humpan teille kahdelle. Parit taputtivat piirissä, ja jalka nousi kuin nuorena.",
}
const LEG_MUISTO := ["Hei, sä oot se, jolta jalka nousi viimeks! Humppaveikot puhuu sustä vieläki.",
	"Muistatko, ku koko lava teki meille piirin? Mää muistan joka askeleen."]
var legend := false
var recall := false
var _leg_t := 0.0
var _leg_c := Vector3(0, 0.06, 2.0)  # parin keskipiste legendan ajan
var _leg_once := {}
var _leg_story := ""
var _leg_bub := {}  # hahmo -> repliikki (puhekupla puhujaan, Room.bubble)
var _leg_walk: Array = []  # piiri: [hahmo, mistä, mihin]
var _leg_ring: Array[Node3D] = []  # piirissä taputtavat (ja kaukaiset parit paikallaan)
var _leg_singer: Node3D
var _ukko: Node3D
var _mummo: Node3D
var _leg_sparks: Array = []
var _ui: Control
var _keys: Node


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
	if recall:  # lavatanssien legenda koettu: pari muistelee illan alussa
		_leg_bub[_partner] = "Pari: " + LEG_MUISTO.pick_random()
		get_tree().create_timer(7.0).timeout.connect(func() -> void:
			if not _phase in LEG:
				_leg_bub.clear())
	if _band != null:
		if _band.current_song.is_empty():
			_band.request(Band.repertoire().pick_random())
		else:
			_on_band_song(_band.current_song, _band._player.stream)
	else:
		Sfx.music_play(1.0)


func _intro_text(extra := "") -> void:
	var head := "Juhannustanssit" if juhannus else "Illan tanssit"
	_info.text = "%s%s: %s soittaa \"%s\".%s\nVäliseinän takana diskopuoli nuorisolle.\nTanssi: vuorottele %s ja %s tahtimerkin tahdissa.\n\n%s Hae pari tanssipuolelta\n%s Diskopuolelle\n%s Baaritiskiltä tuoppi (6,50 €)\n%s Toivo bändiltä iskelmää\n%s Toivo DJ:ltä diskobiisi\n%s Lavalta ulos" % [
		extra, head, band.capitalize(), _song, "\nTV kuvaa: Kesäillan valssi! Hyvä tanssi pääsee lähetykseen." if tv else "",
		Settings.action_key("left"), Settings.action_key("right"), Settings.cap("interact"),
		Settings.cap("mount"), Settings.cap("eat"), Settings.cap("forward"), Settings.cap("back"), Settings.cap("bell")]


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
	var dj_sign := B.sign_plate(self, "DJ", Color(0.04, 0.06, 0.1), Color(0.3, 1.0, 1.0), 0.75, 140, Color(0.2, 0.9, 1.0))
	dj_sign.position = dj + Vector3(0, 0.58, -0.61)
	dj_sign.rotation.y = PI  # luetaan tanssilattialta
	_build_disco_floor()
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


## Diskon valolattia: ruudut vaihtavat väriä tahtiin, ja pyörivät värivalot heittävät täpliä lattiaan.
func _build_disco_floor() -> void:
	var palette := [Color(1.0, 0.15, 0.6), Color(0.2, 0.45, 1.0), Color(0.15, 1.0, 0.5), Color(1.0, 0.8, 0.15), Color(0.1, 0.09, 0.14)]
	for c in palette:
		var m := StandardMaterial3D.new()
		m.albedo_color = c.darkened(0.55) if c.v > 0.3 else c
		m.emission_enabled = c.v > 0.3
		m.emission = c
		m.emission_energy_multiplier = 0.6
		_floor_mats.append(m)
	var z0 := DISCO_Z + 0.4
	var depth := L / 2.0 - DISCO_Z - 0.8
	var tile := 1.2
	var nx := int((W - 1.0) / tile)
	var nz := int(depth / tile)
	for ix in nx:
		for iz in nz:
			var t := B.mesh(self, B.boxm(Vector3(tile - 0.06, 0.02, tile - 0.06)), Vector3(-nx * tile / 2.0 + (ix + 0.5) * tile, 0.09,
				z0 + (iz + 0.5) * tile), Color.BLACK)
			t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			t.material_override = _floor_mats[4]
			_floor_tiles.append(t)
	for k in 6:  # valotäplät
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(palette[k % 4], 0.45)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var sp := B.mesh(self, B.cyl(0.9, 0.9, 0.01, 20), Vector3(0, 0.11, (DISCO_Z + L / 2.0) / 2.0), Color.WHITE)
		sp.material_override = sm
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spots.append(sp)


## Valolattia vaihtaa kuviota joka iskulla (diskobiisin tahti), täplät kiertävät peilipallon alla.
func _update_disco_floor() -> void:
	var beat := int(_t / (60.0 / DISCO_BPM))
	if beat != _floor_beat:
		_floor_beat = beat
		for i in _floor_tiles.size():
			var lit := (i * 7 + beat * 3) % 5 < 2
			_floor_tiles[i].material_override = _floor_mats[(i + beat) % 4] if lit else _floor_mats[4]
	var mid := Vector3(0, 0.11, (DISCO_Z + L / 2.0) / 2.0)
	for k in _spots.size():
		var a := _t * (0.5 + k * 0.08) + k * TAU / _spots.size()
		_spots[k].position = mid + Vector3(cos(a) * (5.0 + k * 1.3), 0, sin(a * 1.3) * 3.2)


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
		"height": 1.8, "shoe": "tyokenka"}, {"shirt": Color(0.85, 0.85, 0.8), "pants": Color(0.2, 0.2, 0.25), "hair": "Hair_SimpleParted",
		"hair_color": Color(0.5, 0.4, 0.3), "height": 1.76, "shoe": "tyokenka"}]
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
		"hair_color": Color(0.2, 0.15, 0.1), "height": 1.78, "shoe": "nauhakenka"})
	_bartender.position = Vector3(-door_side * (W / 2.0 - 1.0), 0.06, -4.0)
	_bartender.rotation.y = door_side * PI / 2.0
	_bartender.play("Idle", 0.0)
	# Pari asiakasta tiskillä.
	for k in 2:
		var c := Looks.make(self, {"shirt": shirts[(k * 5 + 1) % shirts.size()], "pants": Color(0.2, 0.2, 0.3),
			"hair": hairs[(k + 1) % hairs.size()], "hair_color": Color(0.35, 0.25, 0.12), "height": 1.78, "shoe": "lenkkari"})
		c.position = Vector3(-door_side * (W / 2.0 - 2.6), 0.06, -6.0 + k * 3.2)
		c.rotation.y = -door_side * PI / 2.0
		c.play("Idle_Talking", 0.0)
	# Diskopuolen nuoret: kirkkaat värit, lippikset, hyppivät nopeammin.
	var neon := [Color(1.0, 0.2, 0.6), Color(0.1, 0.9, 0.9), Color(0.6, 1.0, 0.1), Color(1.0, 0.6, 0.0), Color(0.5, 0.2, 1.0),
		Color(0.95, 0.95, 0.95)]
	for k in YOUTH:
		var y := Looks.make(self, {"model": "female" if k % 2 == 1 else "male", "shirt": neon[rng.randi() % neon.size()],
			"pants": Color(0.15, 0.2, 0.45), "hair": hairs[rng.randi() % hairs.size()],
			"hair_color": Color(rng.randf_range(0.1, 0.9), rng.randf_range(0.08, 0.7), 0.1), "height": rng.randf_range(1.6, 1.8),
			"shoe": Shoes.random_type(rng, "nuori", k % 2 == 1)})
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
				"height": 1.8 if s == 0 else 1.66, "shoe": Shoes.random_type(rng, "aikuinen", s == 1)}
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
			"hair": "Hair_Long", "hair_color": Color(0.5, 0.3, 0.15), "height": 1.66, "shoe": "sandaali"})
		bp.position = _buddy.position + Vector3(0, 0, -0.5)
		bp.rotation.y = PI
		bp.play("Dance", 0.0, 0.95)
		B.label(self, "Santtu", _buddy.position + Vector3(0, 2.2, 0), 24, Color(0.45, 0.75, 1.0), true).pixel_size = 0.005
	_me = Looks.make(self, Looks.player())
	_me.position = Vector3(0, 0.06, 2.0)
	_me.play("Idle", 0.0)
	_partner = Looks.make(self, {"model": "female", "shirt": Color(0.9, 0.25, 0.4), "pants": Color(0.12, 0.12, 0.2),
		"hair": "Hair_Long", "hair_color": Color(0.8, 0.65, 0.35), "height": 1.66, "shoe": "sandaali"})
	_partner.position = Vector3(1.6, 0.06, 0.6)
	_partner.rotation.y = -0.8
	_partner.play("Idle", 0.0)
	_bubble = B.bubble(self, Vector3(1.6, 2.2, 0.6), Color(1, 1, 0.85))


func _process(delta: float) -> void:
	_t += delta
	_ui.queue_redraw()
	if _phase in LEG:
		_leg_step(delta)
		_update_disco_floor()
		_ball.rotation.y += delta * 1.2
		return
	# Kamera kiertää hitaasti paria.
	var a := _t * 0.12
	var focus := (_me.position + _partner.position) / 2.0 + Vector3(0, 1.2, 0)
	var cp := focus + Vector3(sin(a) * 6.0, 2.2, cos(a) * 6.0)
	# Kamera pysyy salin sisällä (diskopuolella kierros kävi päätyseinän takana).
	cp.x = clampf(cp.x, -W / 2.0 + 1.0, W / 2.0 - 1.0)
	cp.z = clampf(cp.z, -L / 2.0 + 1.0, L / 2.0 - 1.0)
	_shake = maxf(0.0, _shake - delta * 3.0)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.12 * _shake
	_cam.look_at_from_position(to_global(cp + sh), to_global(focus))
	_update_disco_floor()
	_flash = move_toward(_flash, 0.0, delta * 1.6)
	MG.sparks_step(_hearts, delta)
	for p in _pops:
		p[2] += delta
	_pops = _pops.filter(func(p): return p[2] < 1.2)
	_pulse.visible = _phase == "dance"
	_pulse.queue_redraw()
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
				_open_menu("band")
			elif Input.is_action_just_pressed("back") and not Headphones.disco_tracks().is_empty():
				_open_menu("dj")
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
		var next: Dictionary = _wish_song() if _wish != "" else _band.next_song()
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
func _start_dance(mode: String, track := "") -> void:
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
			"hair": "Hair_Buns", "hair_color": Color(0.85, 0.7, 0.4), "height": 1.65, "shoe": "sandaali"})
		_title.text = "LAVAN DISKO"
		if track == "":
			track = Headphones.random_90s_path()  # DJ soittaa 90-luvun eurodancea, ellei toivottu muuta
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
	var songs := Band.repertoire()
	for sg in songs:
		if sg.title == _wish:
			return sg
	return songs[0]


## Toivelista auki: bändin iskelmät (band) tai DJ:n diskobiisit (dj).
func _open_menu(kind: String) -> void:
	_menu_kind = kind
	_menu_items = Band.repertoire() if kind == "band" else Headphones.disco_tracks()
	_menu = 0
	_show_menu()


func _show_menu() -> void:
	var lines: Array[String] = []
	for i in _menu_items.size():
		var it = _menu_items[i]
		var name: String = Headphones.song_title(it) if _menu_kind == "dj" else (
			"%s – %s (%d)" % [it.title, it.artist, it.year] if it.has("artist") else it.title)
		lines.append(("▶ " if i == _menu else "   ") + ("%d. " % ((i + 1) % 10) if i < 10 else "") + name)
	var head := "Laulaja kumartuu lavan reunalle: \"No, mitäs soitetaan?\"" if _menu_kind == "band" else \
		"DJ nostaa kuulokkeen korvalta: \"Mikä biisi? Huuda kovempaa!\""
	_info.text = "%s\n\n%s\n\nnumero tai %s valitse · %s toivo · %s peruuta" % [
		head, "\n".join(lines), Settings.pair("forward", "back"), Settings.cap("interact"), Settings.cap("bell")]


func _menu_input() -> void:
	var digit := -1
	for d in mini(_menu_items.size(), 10):
		if Input.is_physical_key_pressed(KEY_1 + d if d < 9 else KEY_0):
			digit = d
	if digit >= 0 and digit != _digit_prev:
		_digit_prev = digit
		_menu = digit
		if _menu_kind == "dj":
			request_disco(digit)
		else:
			request_song(digit)
		return
	_digit_prev = digit
	if Input.is_action_just_pressed("forward"):
		_menu = posmod(_menu - 1, _menu_items.size())
		_show_menu()
	elif Input.is_action_just_pressed("back"):
		_menu = posmod(_menu + 1, _menu_items.size())
		_show_menu()
	elif Input.is_action_just_pressed("interact"):
		if _menu_kind == "dj":
			request_disco(_menu)
		else:
			request_song(_menu)
	elif Input.is_action_just_pressed("bell"):
		_menu = -1
		_intro_text()


## Toive DJ:lle: biisi alkaa heti, ja diskopuolelta haetaan pari sen tahtiin.
func request_disco(i: int) -> void:
	var tracks := Headphones.disco_tracks()
	_menu = -1
	if tracks.is_empty():
		return
	var track: String = tracks[clampi(i, 0, tracks.size() - 1)]
	_start_dance("disco", track)
	_info.text = "DJ: \"%s, tulee!\"\n%s" % [Headphones.song_title(track).get_slice(" – ", 0), _info.text]


## Toive bändille: kappale alkaa heti (bändi vaihtaa lennosta), ja sen tahtiin tanssitaan.
func request_song(i: int) -> void:
	var songs := Band.repertoire()
	var sg: Dictionary = songs[clampi(i, 0, songs.size() - 1)]
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
		Sfx.music_play(0.6, 0.0, "humppa:" + Band.song_id(song), stream)
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
			_flash = 1.0
			Sfx.play("step_wood", -6.0, 1.3 if _next == "left" else 1.1)  # askel lattiaan
			if _hits % 4 == 0:
				Sfx.play("pickup", -14.0, 1.4)
			var good := near < WINDOW * 0.45
			_pops.append(["TAHTIIN!" if good else "HYVÄ", Color(0.4, 1.0, 0.5) if good else Color(1.0, 0.9, 0.4), 0.0])
			MG.sparks_burst(_hearts, Vector2(_pulse.size.x / 2.0, 62.0), Color(1.0, 0.35, 0.6) if _mode == "humppa" else Color(0.3, 1.0, 1.0), 10)
			if _hits % 12 == 0:
				_say((DISCO_LINES if _mode == "disco" else PARTNER_LINES).pick_random())
		else:
			_misses += 1
			_flash = -1.0
			_shake = 1.0 if stumble else 0.6
			Sfx.play("step_hard", -4.0, 0.7)  # kompastus
			_pops.append(["HUPS!" if stumble else ("VÄÄRÄ JALKA" if not ok else ("LIIAN AIKAISIN" if hasty else "OHI TAHDIN")),
				Color(1.0, 0.35, 0.3), 0.0])
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
		if _mode == "humppa":
			humppa_best = maxf(humppa_best, s)
		danced.emit(s, _mode)
		if legend and _mode == "humppa" and s > LEG_SCORE:
			legend = false
			_leg_begin()
			return
		_show_result(s)


## Kappaleen tulos: pari kiittää ja valikko (takaisin saliin tai ulos).
func _show_result(s: float) -> void:
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
	_pulse = Control.new()
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pulse.anchor_left = 0.5
	_pulse.anchor_right = 0.5
	_pulse.anchor_top = 1.0
	_pulse.anchor_bottom = 1.0
	_pulse.offset_left = -220
	_pulse.offset_right = 220
	_pulse.offset_top = -240
	_pulse.offset_bottom = -76
	_pulse.draw.connect(_draw_pulse)
	_pulse.visible = false
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
	_score_bar.visible = false  # tanssin onnistuminen piirretään tahtimerkin alle (_draw_pulse)
	_layer.add_child(_score_bar)
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_legend)
	_layer.add_child(_ui)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	_layer.add_child(_keys)



## Tahtimerkki: keskellä sydän kehässä, johon pienenevä rengas osuu iskulla; vasemmalla ja oikealla vuoronäppäimet
## (seuraava hehkuu). Osuma välähtää vihreänä ja sydämet lentävät, huti punaisena. Alla tanssin onnistuminen.
func _draw_pulse() -> void:
	var c := Vector2(_pulse.size.x / 2.0, 62)
	var phase := fmod(_t, _beat) / _beat
	var hot := Color(1.0, 0.35, 0.6) if _mode == "humppa" else Color(0.3, 1.0, 1.0)
	var tint := Color(0.25, 0.6, 0.3) if _flash > 0.0 else Color(0.7, 0.12, 0.1)
	MG.box(_pulse, Rect2(Vector2(40, 0), Vector2(_pulse.size.x - 80, 128)), Color(0.05, 0.04, 0.08, 0.72).lerp(Color(tint, 0.85), absf(_flash) * 0.6), 22, 6)
	# Lähestyvä rengas: iso tahdin alussa, osuu kehään iskun kohdalla (phase 0/1).
	var r := lerpf(96.0, 40.0, phase)
	_pulse.draw_arc(c, r, 0, TAU, 48, Color(hot, 0.35 + 0.65 * phase), 4.0, true)
	# Kehä ja sydän; iskulla sydän sykähtää.
	var beat_k := clampf(1.0 - phase * 4.0, 0.0, 1.0)
	var ring_col := Color(0.4, 1.0, 0.5) if _flash > 0.0 else (Color(1.0, 0.3, 0.25) if _flash < 0.0 else Color(1, 1, 1))
	_pulse.draw_arc(c, 40.0, 0, TAU, 48, MG.OUTLINE, 9.0, true)
	_pulse.draw_arc(c, 40.0, 0, TAU, 48, ring_col.lerp(Color(1, 1, 1), 1.0 - absf(_flash)), 5.0, true)
	_heart(c + Vector2(0, 2), 22.0 * (1.0 + 0.25 * beat_k), hot)
	# Vuoronäppäimet.
	for side in [-1.0, 1.0]:
		var key: String = Settings.action_key("left" if side < 0.0 else "right")
		var is_next: bool = (_next == "left") == (side < 0.0)
		var kr := Rect2(c + Vector2(side * 118.0 - 30.0, -28.0), Vector2(60, 56))
		if is_next:
			MG.glow(_pulse, kr.get_center(), 46.0, Color(hot, 0.6 + 0.4 * beat_k))
		MG.box(_pulse, kr, Color(0.96, 0.93, 0.85) if is_next else Color(0.45, 0.43, 0.4), 10, 4, MG.OUTLINE, 2)
		MG.box(_pulse, Rect2(kr.position + Vector2(4, 4), Vector2(kr.size.x - 8, 14)), Color(1, 1, 1, 0.35), 6)
		_pulse.draw_string(ThemeDB.fallback_font, kr.position + Vector2(0, 38), key, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, 28,
			Color(0.12, 0.1, 0.08) if is_next else Color(0.2, 0.2, 0.2))
		_foot(kr.get_center() + Vector2(side * 58.0, 0), side, Color(1, 1, 1, 0.85 if is_next else 0.3))
	MG.sparks_draw(_pulse, _hearts)
	# Palautetekstit nousevat ja haalistuvat.
	for p in _pops:
		var a: float = clampf(1.0 - (p[2] - 0.6) / 0.6, 0.0, 1.0)  # pysyy kirkkaana 0,6 s
		var pos := c + Vector2(-140, -74 - p[2] * 30.0)
		MG.box(_pulse, Rect2(pos + Vector2(20, -30), Vector2(240, 40)), Color(0.05, 0.04, 0.06, 0.75 * a), 12)
		_pulse.draw_string(ThemeDB.fallback_font, pos + Vector2(2, 2), p[0], HORIZONTAL_ALIGNMENT_CENTER, 280, 30, Color(0, 0, 0, a * 0.8))
		_pulse.draw_string(ThemeDB.fallback_font, pos, p[0], HORIZONTAL_ALIGNMENT_CENTER, 280, 30, Color(p[1], a))
	# Tanssin onnistuminen.
	var bar := Rect2(Vector2(_pulse.size.x / 2.0 - 140, 136), Vector2(280, 16))
	MG.box(_pulse, bar.grow(3.0), Color(0.05, 0.05, 0.06, 0.9), 8, 3)
	MG.box(_pulse, Rect2(bar.position, Vector2(bar.size.x * _score(), bar.size.y)), Color(0.3, 0.8, 0.45).lerp(Color(1.0, 0.85, 0.3), _score()), 6)


## Sydän (kaksi ympyrää ja kärki) ääriviivoineen.
func _heart(c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var t := i / 40.0 * TAU
		pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * s / 17.0)
	_pulse.draw_colored_polygon(pts, col)
	_pulse.draw_polyline(pts, MG.OUTLINE, 2.5, true)
	_pulse.draw_circle(c + Vector2(-s * 0.35, -s * 0.35), s * 0.18, Color(1, 1, 1, 0.6))


## Kengänpohja vuoronäppäimen vieressä (vasen tai oikea jalka).
func _foot(c: Vector2, side: float, col: Color) -> void:
	_pulse.draw_set_transform(c, side * 0.25, Vector2(side, 1.0))
	_pulse.draw_circle(Vector2(0, -10), 12.0, col)  # päkiä
	_pulse.draw_circle(Vector2(1, 13), 8.5, col)  # kanta
	_pulse.draw_set_transform(Vector2.ZERO)


# --- Legendaarinen hetki: lavatanssit ------------------------------------------------------------------------------

var _leg_score := 0.0
var _leg_r := 3.3  # piirin säde
const LEG_GAP := 62.0  # piirin aukko etelään (+Z) asteina keskeltä kumpaankin suuntaan: kamerat kuvaavat aukosta
const LEG_KAMERA := 28.0  # potkun kameran suunta keskeltä (astetta +Z:sta itään), aukon sisällä
const LEG_OLD := [165.0, 178.0]  # ukon ja mummon paikka piirissä (potkukuvan taustalla parin vieressä)


## Suunta (rotation.y), jolla hahmo katsoo kohti pistettä (hahmon etu on -Z).
static func _face(from: Vector3, to: Vector3) -> float:
	var f := to - from
	return atan2(-f.x, -f.z)


## Kamera lavan avaruuden pisteestä toiseen (tärähdys mukaan).
func _leg_cam(eye: Vector3, look: Vector3, fov := 50.0) -> void:
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.06 * _shake
	_cam.fov = fov
	_cam.look_at_from_position(to_global(eye + sh), to_global(look))


## Laulajan pää lavan avaruudessa (bändi on vaala.gd:n esiintymislavalla; testissä ilman bändiä kuvitteellinen paikka).
func _singer_head() -> Vector3:
	if _leg_singer != null:
		return to_local(_leg_singer.to_global(_leg_singer.bone_position("Head")))
	return Vector3(0, 2.7, -L / 2.0 + 4.9)


## Olan yli -kuvan rajaus lasketaan: kamera laulajan takana, katse parin keskelle; fov niin, että pari on noin
## 230 px korkea, ja sivusiirto niin, että laulajan pää osuu kuvan vasempaan reunaan (x 9-17 % leveydestä).
## Palauttaa [silmä, katse, fov].
func _olka_cam(h: Vector3, d: Vector3, side: Vector3) -> Array:
	var vs := get_viewport().get_visible_rect().size
	var look := _leg_c + Vector3(0, 0.9, 0)
	var best := []
	for k in 30:
		var sd := 0.2 + k * 0.04
		var eye := h - d * 1.7 + side * sd + Vector3(0, 0.32, 0)
		var dist := eye.distance_to(look)
		var fov := rad_to_deg(2.0 * atan(1.8 / (2.0 * dist) * vs.y / 230.0))
		_leg_cam(eye, look, fov)
		var hx := _cam.unproject_position(to_global(h)).x / vs.x
		best = [eye, look, fov]
		if not _cam.is_position_behind(to_global(h)) and hx > 0.09 and hx < 0.17:
			break
	return best


func _leg_begin() -> void:
	_phase = "kutsu"
	_leg_t = 0.0
	_leg_score = _score()
	_leg_once.clear()
	_leg_bub.clear()
	_leg_walk.clear()
	_leg_ring.clear()
	_bubble.text = ""
	_pulse.visible = false
	_title.visible = false
	_info.visible = false
	_keys.set_text("%s ohita" % Settings.cap("interact"))
	_leg_c = Vector3(0, 0.06, 2.0)
	_me.position = _leg_c + Vector3(-0.42, 0, 0)
	_partner.position = _leg_c + Vector3(0.42, 0, 0)
	for c: Node3D in [_me, _partner]:
		c.rotation.y = 0.0  # kasvot bändiin (-Z)
		c.play("Idle", 0.3)
	for d in _dancers:
		d.play("Idle", 0.5)
		d.rotation.y = _face(d.position, Vector3(d.position.x * 0.5, 0, -L / 2.0))
	if _buddy != null:
		_buddy.play("Idle", 0.5)
	_leg_singer = null
	if _band != null:
		for m: Dictionary in _band._members:
			if m.role == "laulu":
				_leg_singer = m.ch
	_leg_story = "Kappale loppuu, mutta Humppaveikkojen laulaja ei päästä lattiaa tyhjäksi."
	if _leg_singer != null:
		_leg_singer.play("Idle_Talking", 0.2)
		_leg_bub[_leg_singer] = "Laulaja: " + LEG_LINES.kutsu
	else:
		_leg_story = "Laulaja mikkiin: \"%s\"" % LEG_LINES.kutsu
	Sfx.play("whoosh", -10.0, 0.8)


func _leg_piiri() -> void:
	_phase = "piiri"
	_leg_t = 0.0
	_leg_bub.clear()
	_leg_story = "Parit vetäytyvät piiriin ja taputtavat tahtia. Lattia on teidän kahden."
	if _leg_singer != null:
		_leg_singer.play("Idle", 0.3)
	_me.position = _leg_c + Vector3(-0.28, 0, 0)
	_me.rotation.y = -PI / 2.0  # kasvot +X:ään, pariin
	_partner.position = _leg_c + Vector3(0.28, 0, 0)
	_partner.rotation.y = PI / 2.0
	_me.play("Dance", 0.3, 1.15)
	_partner.play("Dance", 0.3, 1.15)
	# Piirin paikat: aukko etelään (+Z), josta potkun kamera kuvaa. Vanha pari takaoikealle (potkukuvan taustalle).
	var spots: Array[Vector3] = []
	var n := 16
	for k in n:
		var th := deg_to_rad(lerpf(LEG_GAP, 360.0 - LEG_GAP, k / float(n - 1)))
		spots.append(_leg_c + Vector3(sin(th), 0, cos(th)) * _leg_r)
	var old_at: Array[Vector3] = []
	for th_deg: float in LEG_OLD:
		var th := deg_to_rad(th_deg)
		old_at.append(_leg_c + Vector3(sin(th), 0, cos(th)) * _leg_r)
	spots = spots.filter(func(p: Vector3) -> bool: return p.distance_to(old_at[0]) > 0.7 and p.distance_to(old_at[1]) > 0.7)
	if _ukko == null:
		_ukko = Looks.make(self, {"shirt": Color(0.52, 0.42, 0.3), "pants": Color(0.28, 0.28, 0.3), "hair": "Hair_Buzzed",
			"hair_color": Color(0.85, 0.85, 0.83), "beard": true, "height": 1.74, "belly": 0.55, "shoe": "nauhakenka", "stripes": false})
		_mummo = Looks.make(self, {"model": "female", "shirt": Color(0.6, 0.22, 0.42), "pants": Color(0.32, 0.28, 0.42),
			"hair": "Hair_Buns", "hair_color": Color(0.88, 0.88, 0.9), "height": 1.6, "shoe": "sandaali", "stripes": false})
	for k in 2:
		var o: Node3D = [_ukko, _mummo][k]
		var out := (old_at[k] - _leg_c).normalized()
		o.position = old_at[k] + out * 2.0
		_leg_walk.append([o, o.position, old_at[k]])
	# Lähimmät parit kävelevät piiriin, kaukaisemmat kääntyvät paikoillaan ja taputtavat.
	var free: Array[Node3D] = _dancers.duplicate()
	for p in spots:
		var best: Node3D = null
		for d in free:
			if best == null or d.position.distance_to(p) < best.position.distance_to(p):
				best = d
		if best == null:
			break
		free.erase(best)
		_leg_walk.append([best, best.position, p])
	for d in free:
		d.rotation.y = _face(d.position, _leg_c)
		_leg_ring.append(d)
	if _buddy != null:
		_buddy.rotation.y = _face(_buddy.position, _leg_c)
		_leg_ring.append(_buddy)
	for w: Array in _leg_walk:
		var c: Node3D = w[0]
		c.play("Walk", 0.2, 1.1)
		c.rotation.y = _face(w[1], w[2])
	Sfx.play("win_small", -12.0, 0.9)


func _leg_potku() -> void:
	_phase = "potku"
	_leg_t = 0.0
	_leg_bub.clear()
	_leg_story = "Rinta rinnan, kädet ilmaan, ja jalka nousee tahtiin."
	# Rinta rinnan kameran poikittaissuunnassa, kasvot kolme neljäsosaa kameraan päin (potku näkyy sivuttain).
	var u := Vector3(sin(deg_to_rad(LEG_KAMERA)), 0, cos(deg_to_rad(LEG_KAMERA)))
	var p := Vector3(u.z, 0, -u.x)  # kuvan oikealle
	var f := u.rotated(Vector3.UP, deg_to_rad(-40.0))
	_me.position = _leg_c - p * 0.45
	_partner.position = _leg_c + p * 0.45
	for c: Node3D in [_me, _partner]:
		c.rotation.y = atan2(-f.x, -f.z)
		c.play("Idle", 0.2)
	for w: Array in _leg_walk:  # kesken jääneet kävelyt perille
		_leg_arrive(w)
	_leg_walk.clear()


func _leg_otsikko() -> void:
	_phase = "otsikko"
	_leg_t = 0.0
	_leg_bub.clear()
	_leg_story = "Laulaja: \"%s\"" % LEG_LINES.kiitos
	for c: Node3D in [_me, _partner]:
		c.clear_ik()
	_me.position = _leg_c + Vector3(-0.28, 0, 0)
	_me.rotation.y = -PI / 2.0
	_partner.position = _leg_c + Vector3(0.28, 0, 0)
	_partner.rotation.y = PI / 2.0
	_me.play("Dance", 0.3, 0.9)
	_partner.play("Dance", 0.3, 0.9)
	Sfx.play("win", -4.0)


func _leg_end() -> void:
	for w: Array in _leg_walk:
		_leg_arrive(w)
	_leg_walk.clear()
	for c: Node3D in _leg_ring:
		c.clear_ik()
	_me.clear_ik()
	_partner.clear_ik()
	for c: Node3D in _leg_ring:
		c.play("Dance", 0.4, 0.9)
	_leg_bub.clear()
	_leg_story = ""
	_keys.set_text("")
	_title.visible = true
	_info.visible = true
	_cam.fov = 60.0
	_phase = "result"
	_show_result(_leg_score)


## Kävelijä perille: kasvot piirin keskelle ja taputtamaan.
func _leg_arrive(w: Array) -> void:
	var c: Node3D = w[0]
	c.position = w[2]
	c.rotation.y = _face(c.position, _leg_c)
	c.play("Idle", 0.25)
	if not c in _leg_ring:
		_leg_ring.append(c)


## Taputus käsien IK:lla: kämmenet vastakkain rinnan edessä, väli sykkii (rate taputusta sekunnissa, off vaihe).
func _clap(c: Node3D, t: float, off: float) -> void:
	var rx := signf((c.bone_position("upperarm_r") as Vector3).x)
	if rx == 0.0:
		rx = 1.0
	var chest: Vector3 = c.bone_position("spine_03")
	var mid: Vector3 = chest + Vector3(0, 0.02, -0.34)
	var sep := 0.035 + 0.085 * absf(sin(PI * (t * 1.75 + off)))
	for lr in ["_l", "_r"]:
		var s := rx if lr == "_r" else -rx
		var sh: Vector3 = c.bone_position("upperarm" + lr)
		c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, mid + Vector3(s * sep, 0, 0),
			sh + Vector3(s * 0.35, -0.45, 0.05))
		c.set_ik_orient("arm" + lr, Pose.palm_on(Vector3(0, 0.75, -0.65), Vector3(-s, 0, 0), lr == "_l"), 1.0)


## Kädet ilmaan V:ksi.
func _arms_up(c: Node3D) -> void:
	var rx := signf((c.bone_position("upperarm_r") as Vector3).x)
	if rx == 0.0:
		rx = 1.0
	for lr in ["_l", "_r"]:
		var s := rx if lr == "_r" else -rx
		var sh: Vector3 = c.bone_position("upperarm" + lr)
		c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, sh + Vector3(s * 0.3, 0.5, -0.12),
			sh + Vector3(s * 0.5, 0.1, 0.3))
		c.set_ik_orient("arm" + lr, Pose.palm_on(Vector3(s * 0.35, 1.0, 0), Vector3(0, 0, -1), lr == "_l"), 1.0)


## Oikean jalan potku eteen: k 0 = jalka lattialla, 1 = suora jalka vaakaa vähän alempana.
func _kick(c: Node3D, k: float) -> void:
	if k <= 0.001:
		c._ik.erase("leg_r")
		return
	var hip: Vector3 = c.bone_position("thigh_r")
	var rest := Vector3(hip.x, 0.09, hip.z + 0.02)
	var top: Vector3 = hip + Vector3(0.0, -0.32, -0.8)
	var pole: Vector3 = hip + Vector3(0, 0.25, -1.0)
	c.set_ik("leg_r", "thigh_r", "calf_r", "foot_r", rest.lerp(top, k), pole)


func _leg_step(delta: float) -> void:
	_leg_t += delta
	var t := _leg_t
	_shake = maxf(0.0, _shake - delta * 2.5)
	for pf: Array in _leg_sparks:  # pöly: [maailman piste, liike, ikä, koko]
		pf[2] += delta
	_leg_sparks = _leg_sparks.filter(func(pf: Array) -> bool: return pf[2] < 1.1)
	if Input.is_action_just_pressed("interact"):
		_leg_end()
		return
	# Piiri taputtaa koko ajan.
	for i in _leg_ring.size():
		_clap(_leg_ring[i], _t, i * 0.13)
	match _phase:
		"kutsu":
			var h := _singer_head()
			var d := Vector3(_leg_c.x - h.x, 0, _leg_c.z - h.z).normalized()
			var side := d.cross(Vector3.UP)
			if t < 2.8:
				_leg_cam(h + d * 2.4 + side * 0.7 + Vector3(0, -0.3, 0), h + Vector3(0, -0.3, 0), 45.0)
			else:
				# Laulajan olan yli lattialle: koko lava kääntyy katsomaan paria (rajaus _olka_cam).
				if not _leg_once.has("olka"):
					_leg_once.olka = _olka_cam(h, d, side)
				var oc: Array = _leg_once.olka
				_leg_cam(oc[0], oc[1], oc[2])
				if not _leg_once.has("katse"):
					_leg_once.katse = true
					for dd in _dancers:
						dd.rotation.y = _face(dd.position, _leg_c)
			if t > 5.2:
				_leg_piiri()
		"piiri":
			var u := clampf(t / 6.0, 0.0, 1.0)
			_leg_cam((_leg_c + Vector3(2.4, 4.4, 6.2)).lerp(_leg_c + Vector3(1.8, 4.0, 5.0), u), _leg_c + Vector3(0, 0.2, -0.8), 55.0)
			var turn := t * 1.1
			_me.position = _leg_c + Vector3(-cos(turn), 0, sin(turn)) * 0.28
			_partner.position = _leg_c + Vector3(cos(turn), 0, -sin(turn)) * 0.28
			_me.rotation.y = _face(_me.position, _partner.position)
			_partner.rotation.y = _face(_partner.position, _me.position)
			var arrived: Array = []
			for w: Array in _leg_walk:
				var dur: float = clampf((w[1] as Vector3).distance_to(w[2]) / 2.2, 1.0, 3.2)
				var k := clampf(t / dur, 0.0, 1.0)
				(w[0] as Node3D).position = (w[1] as Vector3).lerp(w[2], k)
				if k >= 1.0:
					arrived.append(w)
			for w: Array in arrived:
				_leg_arrive(w)
				_leg_walk.erase(w)
			if t > 1.4 and not _leg_once.has("pari"):
				_leg_once.pari = true
				_leg_bub[_partner] = "Pari: " + LEG_LINES.pari
			if t > 4.4:
				_leg_bub.erase(_partner)
			if t > 6.2:
				_leg_potku()
		"potku":
			var u := Vector3(sin(deg_to_rad(LEG_KAMERA)), 0, cos(deg_to_rad(LEG_KAMERA)))
			_leg_cam(_leg_c + u * 4.4 + Vector3(0, 1.2, 0), _leg_c + Vector3(0, 0.95, 0), 50.0)
			var k := 0.0
			for i in 3:
				var t0: float = [0.5, 1.45, 2.4][i]
				var amp: float = [0.7, 0.85, 1.0][i]
				var x := clampf((t - t0) / 0.8, 0.0, 1.0)
				k = maxf(k, amp * sin(PI * x))
			for c: Node3D in [_me, _partner]:
				_arms_up(c)
				_kick(c, k)
			for i in 3:
				var peak: float = [0.9, 1.85, 2.8][i]
				if t >= peak and not _leg_once.has("isku%d" % i):
					_leg_once["isku%d" % i] = true
					Sfx.play("step_wood", -2.0 + i * 2.0, 0.8)
					if i == 2:
						_shake = 1.0
						Sfx.play("win_small", -6.0, 1.2)
						for c: Node3D in [_me, _partner]:  # pölypöllähdys lattiasta tukijalan ympäriltä
							var st: Vector3 = c.to_global(c.bone_position("foot_l"))
							st.y = global_position.y + 0.06
							for j in 9:
								var a := TAU * j / 9.0 + randf() * 0.4
								_leg_sparks.append([st, Vector3(cos(a), 0, sin(a)) * randf_range(0.25, 0.55), 0.0, randf_range(0.7, 1.2)])
			if t > 3.1 and not _leg_once.has("ukko"):
				_leg_once.ukko = true
				_leg_bub[_ukko] = "Ukko: " + LEG_LINES.ukko
				_ukko.play("Idle_Talking", 0.2)
			if t > 5.6 and not _leg_once.has("mummo"):
				_leg_once.mummo = true
				_leg_bub.erase(_ukko)
				_ukko.play("Idle", 0.3)
				_leg_bub[_mummo] = "Mummo: " + LEG_LINES.mummo
				_mummo.play("Idle_Talking", 0.2)
			if t > 8.2:
				_mummo.play("Idle", 0.3)
				_leg_otsikko()
		"otsikko":
			var u := smoothstep(0.0, 1.0, clampf(t / 5.0, 0.0, 1.0))
			_leg_cam((_leg_c + Vector3(0.5, 1.4, 4.4)).lerp(_leg_c + Vector3(2.2, 2.9, 5.4), u),
				(_leg_c + Vector3(0, 1.0, 0)).lerp(_leg_c + Vector3(0, 2.0, -1.0), u), 52.0)
			var turn := t * 0.9
			_me.position = _leg_c + Vector3(-cos(turn), 0, sin(turn)) * 0.28
			_partner.position = _leg_c + Vector3(cos(turn), 0, -sin(turn)) * 0.28
			_me.rotation.y = _face(_me.position, _partner.position)
			_partner.rotation.y = _face(_partner.position, _me.position)
			if t > 6.4:
				_leg_end()


func _draw_legend() -> void:
	if not _phase in LEG and _leg_bub.is_empty():
		return
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _leg_story != "" and _phase in LEG and not (_phase == "otsikko" and _leg_t > 0.9):
		var r := Rect2(vs.x / 2.0 - 440, 24, 880, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _leg_story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19,
			Color(1.0, 0.92, 0.75))
	for c: Node3D in _leg_bub:
		if is_instance_valid(c):
			Room.bubble(_ui, _cam, c, _leg_bub[c], 90.0, 120.0)
	for pf: Array in _leg_sparks:
		var age: float = pf[2]
		var wp: Vector3 = pf[0] + (pf[1] as Vector3) * (1.0 - exp(-age * 3.0)) + Vector3(0, 0.12 * age, 0)
		if _cam.is_position_behind(wp):
			continue
		var sp := _cam.unproject_position(wp)
		var rr := (10.0 + 26.0 * age) * float(pf[3])
		var al := 0.4 * clampf(1.0 - age / 1.1, 0.0, 1.0)
		_ui.draw_circle(sp, rr, Color(0.72, 0.62, 0.5, al))
		_ui.draw_circle(sp + Vector2(-rr * 0.25, -rr * 0.3), rr * 0.6, Color(0.85, 0.77, 0.66, al * 0.7))
	if _phase != "otsikko":
		return
	var a := clampf((_leg_t - 0.8) / 0.8, 0.0, 1.0)
	_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.05, 0.35 * a))
	var y := vs.y * 0.17
	var title := "LAVATANSSIT"
	# Nuotit nousevat otsikon takaa.
	for i in 7:
		var f := fmod(_leg_t * 0.35 + i * 0.37, 1.0)
		var nx := vs.x * (0.24 + 0.085 * i)
		var ny := y - 40.0 - f * 120.0
		var col := Color(1.0, 0.85, 0.4, a * (1.0 - f))
		_ui.draw_circle(Vector2(nx, ny), 7.0, col)
		_ui.draw_line(Vector2(nx + 6, ny), Vector2(nx + 6, ny - 26), col, 2.5)
		_ui.draw_line(Vector2(nx + 6, ny - 26), Vector2(nx + 15, ny - 19), col, 2.5)
	_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 82, 12, Color(0.12, 0.04, 0.02, a))
	_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 82, Color(1.0, 0.82, 0.35, a))
	var sr := Rect2(vs.x / 2.0 - 380, y + 36.0, 760, 74)
	_ui.draw_rect(sr, Color(0.05, 0.04, 0.03, 0.75 * a))
	_ui.draw_multiline_string(font, sr.position + Vector2(18, 30), LEG_LINES.sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 36, 19, 3,
		Color(1.0, 0.94, 0.8, a))
