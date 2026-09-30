extends Node3D
## Haapajärven tekoaltaan kota (sijainti OpenStreetMapista): kahdeksankulmainen hirsikota tulisijoineen,
## täynnä kieltokylttejä. Vieressä halkovaja, tukkipino, sahapukki ja pilkkomispölkky sekä lintutorni
## järven rannalla. Kodan vakiovieraat Raimo ja Veikko kertovat tarinoita, kun tuli palaa.
## Paikallinen -Z = oviaukko (kohti polkua). Pelilogiikka (sahaus, pilkkominen, tuli, tarinat) main.gd:ssä.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Terrain := preload("res://scripts/terrain.gd")

const R := 3.1  # kodan säde (seinän nurkat)
const WALL_H := 1.9
const APEX := 5.0

const SIGNS_OUT := ["Tupakointi\nkielletty", "Koirat\nkytkettävä", "Moottoriajoneuvolla\najo kielletty",
	"Roskaaminen\nkielletty", "Yöpyminen kielletty\nklo 22–06", "Pyörällä ajo kodassa\nkielletty",
	"Lintujen häirintä\nkielletty"]
const SIGNS_IN := ["Märkien puiden\npoltto kielletty", "Kirveen käyttö\nkodassa kielletty",
	"Kiroilu kielletty\n(koskee myös Pekkaa)", "Makkaran tiputtaminen\ntuleen kielletty",
	"Tulitikkujen vieminen\nkielletty", "Kaljan juonti kielletty\n(paitsi lauantaisin)",
	"Tarinoiden liioittelu\nkielletty", "Kieltokylttien\nkieltäminen kielletty"]

const RAIMO := {
	"shirt": Color(0.2, 0.32, 0.2), "pants": Color(0.22, 0.2, 0.18), "shoes": Color(0.2, 0.15, 0.1),
	"hair": "Hair_Buzzed", "hair_color": Color(0.8, 0.8, 0.78), "beard": true, "height": 1.76,
	"skin": Color(1.0, 0.88, 0.82), "belly": 0.6, "bulk": 0.1,
}
const VEIKKO := {
	"shirt": Color(0.6, 0.12, 0.1), "pants": Color(0.18, 0.22, 0.32), "shoes": Color(0.15, 0.12, 0.1),
	"hair": "Hair_SimpleParted", "hair_color": Color(0.55, 0.5, 0.45), "height": 1.8,
	"skin": Color(1.0, 0.9, 0.84), "bulk": -0.4, "shoulders": -0.3,
}

# Tarinat: [kertoja ("raimo"/"veikko"), repliikki]
const STORIES := [
	[["raimo", "Talvella -78 oli niin kova pakkanen, että tekojärven jäällä ajettiin traktorilla Pattijoelle."],
		["raimo", "Jyväjemmarin isä se ajoi. Keväällä traktori upposi."],
		["veikko", "Se on siellä vieläkin. Kesällä näkee pakoputken."]],
	[["veikko", "Pekka ampui kerran kyyhkyn niin korkealta, että se putosi vasta seuraavana päivänä."],
		["veikko", "Maanantaina ammuttu, tiistaina tuli alas."],
		["raimo", "Ja Pekan mukaan se oli vielä lämmin."]],
	[["raimo", "Tässä kodassa on enemmän kieltokylttejä kuin halkoja."],
		["raimo", "Yhdistyksen puheenjohtaja teki niitä koko talven, kun ei ollut muuta tekemistä."],
		["veikko", "Viimeisin kieltää kieltokylttien kieltämisen. Siinä on logiikkaa."]],
	[["veikko", "Raahen karateklubin perustaja kävi täälläkin."],
		["veikko", "Yritti pilkkoa halon paljaalla kädellä. HAI-JAAH!"],
		["raimo", "Käsi oli kipsissä kuusi viikkoa. Halko on vieläkin ehjä. Tuolla vajassa muistona."]],
	[["raimo", "Anna-Liisa näki kerran tuolla järvellä joutsenen."],
		["raimo", "Puolen tunnin päästä koko Saloinen tiesi, että järvellä on hanhi, kaksi joutsenta ja mies ilman housuja."],
		["veikko", "Se mies olin minä. Uimassa, perkele."],
		["raimo", "Kiroilu kielletty, Veikko. Lue kylttiä."]],
	[["veikko", "Kerran joku unohti tänne paketin makkaraa."],
		["veikko", "Seuraavana aamuna se oli poissa. Sanotaan, että kettu vei."],
		["veikko", "Minä sanon, että Raimo."],
		["raimo", "Todista."]],
	[["raimo", "Ennen vanhaan tälle kodalle hiihdettiin Saloisista."],
		["raimo", "Nykyään tullaan pyörällä, kuutonen tarakalla."],
		["veikko", "Edistystä se on sekin."]],
	[["veikko", "Lintutornista näkee kirkkaalla säällä Hailuotoon asti."],
		["veikko", "Sumussa ei näe tornin juurelle."],
		["raimo", "Viime keskiviikkona siellä ylhäällä oli Pekka. Kyyhkyjä bongaamassa."],
		["veikko", "Haulikon kanssa."]],
	[["raimo", "Nuorena mää pilkoin tuossa pölkyllä kolme mottia päivässä."],
		["raimo", "Nykyään yhden halon, ja siihenkin menee koko päivä."],
		["veikko", "Mutta hyvä halko se on. Paras halko koko Saloisissa."]],
	[["veikko", "Kuusiluodon Sirkka etsi kerran miestään tältä kodalta."],
		["veikko", "Mies oli piilossa lintutornissa kolme päivää. Söi linnunruokaa."],
		["raimo", "Sanoi jälkeenpäin, että oli bongaamassa kaakkuria."],
		["veikko", "Kaakkuria ei näkynyt. Sirkka näkyi."]],
	[["raimo", "Kerran kodalle tuli poliisi kyselemään, mistä kylän miehet saa juomansa."],
		["veikko", "Minä sanoin, että kaupasta tietysti."],
		["raimo", "Eikä kukaan sanonut mitään Sulon pannusta Antinsuonkankaan kuusikossa, Ketunperäntien ja laavupolun puolivälissä."],
		["veikko", "...Raimo. Sinä sanoit sen just ääneen."],
		["raimo", "Kiroilu on kielletty, puhuminen ei. Lue kylttiä."]],
]

const BIRD_LINES := ["Laulujoutsen! Kaksi! Ei kun kolme.", "Kurki kaakattaa kaislikossa.",
	"Telkkä. Tai sorsa. Tai muovipussi.", "Merikotka kaartelee järven yllä. Toivottavasti ei vie kaljaa.",
	"Harmaahaikara seisoo rannassa kuin harmaapää kassajonossa.", "Kyyhky. Pekka ei saa tietää.",
	"Varis nauraa sinulle.", "Kaakkuri! Tai sitten se oli Veikon yskä.", "Sinisorsa. Täysin tavallinen. Hyvä sorsa silti."]

var fire: Node3D
var fire_on := false
var fire_time := 0.0  # sekunteja jäljellä
var raimo: Node3D
var veikko: Node3D
var _bubbles := {}
var _bubble_t := {}
var _birds: Array[Node3D] = []
var _swans: Array[Node3D] = []
var _t := 0.0

# Toimintopisteet paikallisesti (main.gd muuntaa maailmaan to_global:lla).
const SAW_LOCAL := Vector3(-5.2, 0, 1.2)
const CHOP_LOCAL := Vector3(-5.4, 0, -1.8)
const FIRE_LOCAL := Vector3(0, 0, 0)
const TELL_LOCAL := Vector3(0.6, 0, -1.4)  # kuulijan paikka kodan sisällä oven puolella
const TOWER_LOCAL := Vector3(9.0, 0, 7.0)  # lintutornin keskipiste
const TOWER_TOP_Y := 5.4


func _ready() -> void:
	_build_kota()
	_build_signs()
	_build_woodwork()
	_build_tower()
	_build_people()
	_build_birds()


var _placed := false


func _process(delta: float) -> void:
	_t += delta
	if not _placed:
		# Maailma nostaa kodan maaston tasolle vasta rakennuksen jälkeen: joutsenet järven pintaan.
		_placed = true
		for sw in _swans:
			sw.global_position.y = Terrain.h(sw.global_position.x, sw.global_position.z) + 0.01
	if fire_on:
		fire_time -= delta
		if fire_time <= 0.0:
			set_fire(false)
		for k in 5:
			var fl: Node3D = fire.get_node("Flame%d" % k)
			fl.scale = Vector3(1.0, 0.8 + 0.35 * absf(sin(_t * (5.0 + k) + k)), 1.0)
		(fire.get_node("Glow") as OmniLight3D).light_energy = 2.6 + 0.7 * sin(_t * 13.0) * sin(_t * 7.3)
	for k in _bubbles:
		_bubble_t[k] -= delta
		if _bubble_t[k] <= 0.0:
			(_bubbles[k] as Label3D).text = ""
	var tc := TOWER_LOCAL + Vector3(26, 0, 18)
	for i in _birds.size():
		var b := _birds[i]
		var a := _t * 0.25 + i * 0.9
		var r := 30.0 + (i % 3) * 7.0
		b.position = tc + Vector3(cos(a) * r, 18.0 + sin(_t * 0.7 + i) * 2.0 + i * 0.6, sin(a) * r)
		b.rotation.y = -a
		var flap := sin(_t * 9.0 + i * 1.7) * 0.6
		(b.get_child(0) as Node3D).rotation.z = flap
		(b.get_child(1) as Node3D).rotation.z = -flap
	for i in _swans.size():
		var s := _swans[i]
		s.position.x += sin(_t * 0.2 + i) * 0.004
		s.rotation.y += sin(_t * 0.3 + i * 2.0) * 0.0015


func set_fire(on: bool, seconds := 240.0) -> void:
	fire_on = on
	fire.visible = on
	if on:
		fire_time = seconds


func say(who: String, text: String, seconds := 3.2) -> void:
	var l: Label3D = _bubbles[who]
	l.text = "%s: %s" % [who.capitalize(), text] if text != "" else ""
	_bubble_t[who] = seconds


# --- Rakentaminen ---------------------------------------------------------------

func _build_kota() -> void:
	var log_a := Color(0.5, 0.35, 0.21)
	var log_b := Color(0.43, 0.29, 0.17)
	var roof_col := Color(0.2, 0.19, 0.18)
	var body := StaticBody3D.new()
	add_child(body)
	# Lattia ja kiviperustus.
	B.mesh(self, B.cyl(R + 0.15, R + 0.25, 0.22, 16), Vector3(0, 0.05, 0), Color(0.45, 0.44, 0.42))
	B.mesh(self, B.cyl(R - 0.05, R - 0.05, 0.06, 16), Vector3(0, 0.19, 0), Color(0.55, 0.42, 0.28))
	# Kahdeksan seinää vaakahirsistä, oviaukko -Z-suunnassa.
	var apo := R * cos(PI / 8.0)
	var seg := 2.0 * R * sin(PI / 8.0)
	for k in 8:
		var a := PI / 2.0 + k * PI / 4.0  # k = 0 -> seinän keskipiste -Z:ssä (ovi)
		var c := Vector3(cos(a) * apo, 0, -sin(a) * apo)
		var yaw := a - PI / 2.0
		var holder := Node3D.new()
		holder.position = c
		holder.rotation.y = yaw
		add_child(holder)
		var y := 0.28
		var r := 0.12
		while y < WALL_H:
			var col := log_a if int(y * 10) % 2 else log_b
			if k == 0:
				# Oviaukko keskellä: hirret vain sivuilla ja oven päällä.
				if y > 1.75:
					B.mesh(holder, B.cyl(r, r, seg + 0.2, 10), Vector3(0, y, 0), col, Vector3(0, 0, 90))
				else:
					for sx in [-1.0, 1.0]:
						B.mesh(holder, B.cyl(r, r, (seg - 0.95) / 2.0 + 0.1, 10), Vector3(sx * (seg + 0.95) / 4.0, y, 0), col, Vector3(0, 0, 90))
			else:
				B.mesh(holder, B.cyl(r, r, seg + 0.2, 10), Vector3(0, y, 0), col, Vector3(0, 0, 90))
			y += 2.0 * r * 0.92
		if k == 0:
			for sx in [-1.0, 1.0]:
				var cs2 := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3((seg - 0.95) / 2.0, WALL_H, 0.3)
				cs2.shape = bs
				cs2.transform = holder.transform * Transform3D(Basis(), Vector3(sx * (seg + 0.95) / 4.0, WALL_H / 2.0 + 0.2, 0))
				body.add_child(cs2)
			# Ovi auki sisäänpäin.
			var door := Node3D.new()
			door.position = Vector3(-0.47, 0.25, 0)
			door.rotation.y = -1.7
			holder.add_child(door)
			B.mesh(door, B.boxm(Vector3(0.92, 1.62, 0.06)), Vector3(0.46, 0.81, 0), Color(0.4, 0.26, 0.15))
			B.mesh(door, B.boxm(Vector3(0.05, 0.05, 0.1)), Vector3(0.82, 0.85, 0.06), Color(0.1, 0.1, 0.1))
			continue
		var cs := CollisionShape3D.new()
		var bs3 := BoxShape3D.new()
		bs3.size = Vector3(seg + 0.1, WALL_H, 0.3)
		cs.shape = bs3
		cs.transform = holder.transform * Transform3D(Basis(), Vector3(0, WALL_H / 2.0 + 0.2, 0))
		body.add_child(cs)
	# Kartiokatto (kahdeksan kolmiota) + savupiippu.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(roof_col)
	var ro := R + 0.45
	var base_y := WALL_H + 0.2
	var apex := Vector3(0, APEX, 0)
	for k in 8:
		var a0 := PI / 2.0 + (k - 0.5) * PI / 4.0
		var a1 := PI / 2.0 + (k + 0.5) * PI / 4.0
		var p0 := Vector3(cos(a0) * ro, base_y - 0.2, -sin(a0) * ro)
		var p1 := Vector3(cos(a1) * ro, base_y - 0.2, -sin(a1) * ro)
		var n := (p1 - p0).cross(apex - p0).normalized()
		if n.y < 0.0:
			n = -n
		for v in [p0, apex, p1]:
			st.set_normal(n)
			st.add_vertex(v)
		for v in [p0, p1, apex]:
			st.set_normal(-n)
			st.set_color(Color(0.3, 0.22, 0.14))
			st.add_vertex(v - n * 0.05)
		st.set_color(roof_col)
	var roof := MeshInstance3D.new()
	roof.mesh = st.commit()
	roof.material_override = B.vcol_mat()
	add_child(roof)
	B.mesh(self, B.cyl(0.14, 0.14, 1.2, 12), Vector3(0, APEX + 0.3, 0), Color(0.25, 0.25, 0.27))
	B.mesh(self, B.cyl(0.24, 0.2, 0.08, 12), Vector3(0, APEX + 0.92, 0), Color(0.2, 0.2, 0.22))
	# Tulisija: kivikehä, arina ja kattohormi.
	B.mesh(self, B.cyl(0.75, 0.85, 0.42, 12), Vector3(0, 0.4, 0), Color(0.42, 0.41, 0.4))
	B.mesh(self, B.cyl(0.55, 0.55, 0.05, 12), Vector3(0, 0.63, 0), Color(0.1, 0.09, 0.08))
	B.mesh(self, B.cyl(0.12, 0.35, 0.7, 12), Vector3(0, APEX - 0.75, 0), Color(0.22, 0.22, 0.24))
	for k in 3:
		var logp := B.mesh(self, B.cyl(0.06, 0.06, 0.6, 8), Vector3(0, 0.7, 0), Color(0.36, 0.24, 0.14))
		logp.rotation = Vector3(PI / 2.0, k * PI / 3.0, 0.25)
	var pitbody := StaticBody3D.new()
	pitbody.add_child(B.capsule_shape(0.8, 1.0))
	add_child(pitbody)
	# Kiertävä penkki seinien vieressä (ei oven kohdalla).
	for k in range(1, 8):
		var a := PI / 2.0 + k * PI / 4.0
		var c := Vector3(cos(a), 0, -sin(a)) * (apo - 0.45)
		var bench := B.mesh(self, B.boxm(Vector3(seg * 0.95, 0.07, 0.5)), c + Vector3(0, 0.62, 0), Color(0.62, 0.46, 0.28))
		bench.rotation.y = a - PI / 2.0
		var leg := B.mesh(self, B.boxm(Vector3(seg * 0.9, 0.4, 0.06)), c * 1.05 + Vector3(0, 0.4, 0), Color(0.5, 0.36, 0.22))
		leg.rotation.y = a - PI / 2.0
		if k % 3 == 1:
			var pelt := B.mesh(self, B.boxm(Vector3(0.6, 0.03, 0.45)), c + Vector3(0, 0.67, 0), Color(0.62, 0.55, 0.45))
			pelt.rotation.y = a - PI / 2.0 + 0.2
	# Nokipannu arinalla ja tulitikkulaatikko hyllyllä.
	B.mesh(self, B.cyl(0.1, 0.13, 0.2, 10), Vector3(0.3, 0.75, 0.2), Color(0.08, 0.08, 0.08))
	B.mesh(self, B.boxm(Vector3(0.9, 0.04, 0.25)), Vector3(-1.6, 1.3, -1.9), Color(0.55, 0.4, 0.25)).rotation.y = -0.78
	B.mesh(self, B.boxm(Vector3(0.1, 0.03, 0.06)), Vector3(-1.55, 1.34, -1.85), Color(0.9, 0.75, 0.2)).rotation.y = -0.78
	# Tuli (piilossa kunnes sytytetään).
	fire = Node3D.new()
	fire.position = Vector3(0, 0.62, 0)
	fire.visible = false
	add_child(fire)
	for k in 5:
		var fl := MeshInstance3D.new()
		fl.mesh = B.cyl(0.0, 0.18 - k * 0.02, 0.6 + k * 0.08, 6)
		fl.material_override = B.unshaded(Color(1.6, 0.6 + k * 0.1, 0.1))
		fl.position = Vector3(cos(k * 1.3) * 0.15, 0.3 + k * 0.03, sin(k * 1.3) * 0.15)
		fl.name = "Flame%d" % k
		fire.add_child(fl)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.2)
	glow.light_energy = 2.6
	glow.omni_range = 7.0
	glow.position.y = 0.8
	glow.name = "Glow"
	fire.add_child(glow)
	var smoke := CPUParticles3D.new()
	smoke.amount = 24
	smoke.lifetime = 3.5
	smoke.direction = Vector3.UP
	smoke.spread = 8.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.1
	smoke.scale_amount_min = 0.4
	smoke.scale_amount_max = 1.3
	smoke.position.y = APEX + 0.4
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	sm.material = B.unshaded(Color(0.6, 0.6, 0.62, 0.25))
	smoke.mesh = sm
	fire.add_child(smoke)
	# Nimikyltti oven yllä.
	var plate := B.sign_plate(self, "HAAPAJÄRVEN KOTA", Color(0.36, 0.2, 0.1), Color(0.98, 0.95, 0.86), 0.22, 40,
		Color(0.3, 0.18, 0.1), "Helvetica Neue")
	plate.position = Vector3(0, 2.25, -apo - 0.25)
	plate.rotation.y = PI


## Kieltomerkki: punainen ympyrä, valkoinen pohja, punainen vinoviiva ja teksti levyn alla.
func _no_sign(parent: Node3D, pos: Vector3, yaw: float, text: String) -> void:
	var s := Node3D.new()
	s.position = pos
	s.rotation.y = yaw
	parent.add_child(s)
	var red := Color(0.85, 0.08, 0.08)
	B.mesh(s, B.cyl(0.17, 0.17, 0.015, 24), Vector3.ZERO, red, Vector3(PI / 2.0, 0, 0))
	B.mesh(s, B.cyl(0.13, 0.13, 0.017, 24), Vector3(0, 0, 0.002), Color(0.97, 0.97, 0.95), Vector3(PI / 2.0, 0, 0))
	var bar := B.mesh(s, B.boxm(Vector3(0.27, 0.035, 0.02)), Vector3(0, 0, 0.004), red)
	bar.rotation.z = -PI / 4.0
	var plate := B.sign_plate(s, text, Color(0.97, 0.97, 0.95), Color(0.05, 0.05, 0.05), 0.07, 18, Color(0.85, 0.08, 0.08))
	var ph: float = plate.get_meta("height")
	plate.position = Vector3(0, -0.19 - ph / 2.0, -0.006)


func _build_signs() -> void:
	var apo := R * cos(PI / 8.0)
	# Ulkoseinät: kyltti joka seinässä (ei oven kohdalla), kaksi kerrosta.
	var n := 0
	for k in range(1, 8):
		var a := PI / 2.0 + k * PI / 4.0
		var dir := Vector3(cos(a), 0, -sin(a))
		if n < SIGNS_OUT.size():
			_no_sign(self, dir * (apo + 0.14) + Vector3(0, 1.35, 0), B.yaw_to(-dir), SIGNS_OUT[n])
			n += 1
	# Sisäseinät.
	n = 0
	for k in range(1, 8):
		var a := PI / 2.0 + k * PI / 4.0 + 0.001
		var dir := Vector3(cos(a), 0, -sin(a))
		if n < SIGNS_IN.size():
			_no_sign(self, dir * (apo - 0.16) + Vector3(0, 1.45, 0), B.yaw_to(dir), SIGNS_IN[n])
			n += 1
	# Loput oven pieleen sisäpuolelle.
	while n < SIGNS_IN.size():
		_no_sign(self, Vector3(0.75, 1.5, -apo + 0.2), 0.0, SIGNS_IN[n])
		n += 1
	# Kylttitolppa sisäänkäynnillä: vielä lisää kieltoja ja ilmoitustaulu.
	var post := Node3D.new()
	post.position = Vector3(-1.9, 0, -apo - 2.4)
	add_child(post)
	B.mesh(post, B.boxm(Vector3(0.12, 2.2, 0.12)), Vector3(0, 1.1, 0), Color(0.42, 0.27, 0.15))
	var extra := ["Uiminen omalla\nvastuulla", "Hiljaisuus\nklo 22–07", "Sahan lainaaminen\nkielletty"]
	for i in extra.size():
		_no_sign(post, Vector3(0, 1.95 - i * 0.6, -0.07), PI, extra[i])
	var board := B.sign_plate(self, "HAAPAJÄRVEN TEKOALTAAN KOTA\nTuli sytytetään vain tulisijaan.\nPolttopuut sahataan ja pilkotaan itse.\nNoudata kylttejä.",
		Color(0.36, 0.2, 0.1), Color(0.98, 0.95, 0.86), 0.12, 22, Color(0.3, 0.18, 0.1), "Helvetica Neue")
	board.position = Vector3(1.9, 1.35, -apo - 2.4)
	board.rotation.y = PI
	for sx in [-0.55, 0.55]:
		B.mesh(self, B.boxm(Vector3(0.1, 1.8, 0.1)), Vector3(1.9 + sx, 0.9, -apo - 2.35), Color(0.42, 0.27, 0.15))


## Halkovaja, tukkipino, sahapukki pokasahoineen ja pilkkomispölkky kirveineen kodan länsipuolella.
func _build_woodwork() -> void:
	var wood := Color(0.55, 0.4, 0.25)
	var dark := Color(0.4, 0.28, 0.17)
	var shed := StaticBody3D.new()
	shed.position = Vector3(-6.5, 0, 4.2)
	shed.rotation.y = PI * 0.5
	add_child(shed)
	shed.add_child(B.box_shape(Vector3(3.2, 2.0, 1.4), Vector3(0, 1.0, 0.1)))
	for x in [-1.5, 1.5]:
		for z in [-0.6, 0.7]:
			B.mesh(shed, B.boxm(Vector3(0.1, 2.1, 0.1)), Vector3(x, 1.05, z), dark)
	B.mesh(shed, B.boxm(Vector3(3.4, 0.08, 1.8)), Vector3(0, 2.15, 0.05), Color(0.2, 0.19, 0.18)).rotation.x = 0.15
	B.mesh(shed, B.boxm(Vector3(3.1, 1.9, 0.05)), Vector3(0, 1.0, 0.72), wood)
	# Halkopino (pilkotut halot päätyjä näkyviin).
	for row in 7:
		for col in 11:
			var h := B.mesh(shed, B.cyl(0.07, 0.07, 0.4, 5), Vector3(-1.35 + col * 0.26 + (row % 2) * 0.1, 0.12 + row * 0.2, 0.3), Color(0.72, 0.58, 0.38) if (row + col) % 3 else Color(0.62, 0.48, 0.3))
			h.rotation.x = PI / 2.0
	var shed_sign := B.sign_plate(shed, "POLTTOPUUT – SAHAA JA PILKO ITSE", Color(0.36, 0.2, 0.1), Color(0.98, 0.95, 0.86), 0.16, 26,
		Color(0.3, 0.18, 0.1), "Helvetica Neue")
	shed_sign.position = Vector3(0, 1.95, -0.66)
	shed_sign.rotation.y = PI
	# Tukkipino: pitkiä koivurunkoja.
	for i in 5:
		var l := B.mesh(self, B.cyl(0.14, 0.16, 3.2, 10), Vector3(-7.8, 0.16 + (i / 3) * 0.26, -0.3 + (i % 3) * 0.3 + (i / 3) * 0.15), Color(0.85, 0.83, 0.78))
		l.rotation.z = PI / 2.0
		l.rotation.y = PI / 2.0
	var logs := StaticBody3D.new()
	logs.position = Vector3(-7.8, 0.3, 0.0)
	logs.add_child(B.box_shape(Vector3(0.9, 0.6, 3.2)))
	add_child(logs)
	# Sahapukki (X-jalat) ja tukki päällä, pokasaha.
	var saw := Node3D.new()
	saw.position = SAW_LOCAL
	saw.rotation.y = 0.3
	add_child(saw)
	for z in [-0.4, 0.4]:
		for s in [-1.0, 1.0]:
			var leg := B.mesh(saw, B.boxm(Vector3(0.07, 1.0, 0.07)), Vector3(0, 0.45, z), dark)
			leg.rotation.x = 0.0
			leg.rotation.z = s * 0.5
	B.mesh(saw, B.boxm(Vector3(0.08, 0.08, 1.0)), Vector3(0, 0.45, 0), dark)
	var sawlog := B.mesh(saw, B.cyl(0.13, 0.14, 1.6, 10), Vector3(0, 0.88, 0), Color(0.85, 0.83, 0.78))
	sawlog.rotation.x = PI / 2.0
	sawlog.name = "SawLog"
	var bow := Node3D.new()
	bow.position = Vector3(0.05, 1.18, 0.35)
	bow.name = "Saw"
	saw.add_child(bow)
	B.mesh(bow, B.cyl(0.02, 0.02, 0.8, 8), Vector3(0, 0.25, 0), Color(0.95, 0.45, 0.05), Vector3(0, 0, PI / 2.0))
	B.mesh(bow, B.boxm(Vector3(0.78, 0.035, 0.005)), Vector3(0, -0.05, 0), Color(0.75, 0.76, 0.78))
	for sx in [-0.39, 0.39]:
		B.mesh(bow, B.cyl(0.018, 0.018, 0.32, 8), Vector3(sx, 0.1, 0), Color(0.95, 0.45, 0.05))
	var sb := StaticBody3D.new()
	sb.position = SAW_LOCAL + Vector3(0, 0.5, 0)
	sb.add_child(B.box_shape(Vector3(0.6, 1.0, 1.4)))
	add_child(sb)
	# Pilkkomispölkky ja kirves.
	var chop := Node3D.new()
	chop.position = CHOP_LOCAL
	add_child(chop)
	B.mesh(chop, B.cyl(0.3, 0.34, 0.5, 12), Vector3(0, 0.25, 0), Color(0.5, 0.36, 0.22))
	B.mesh(chop, B.cyl(0.29, 0.29, 0.02, 12), Vector3(0, 0.51, 0), Color(0.8, 0.68, 0.48))
	var axe := Node3D.new()
	axe.position = Vector3(0.05, 0.52, 0)
	axe.rotation.z = -0.45
	axe.name = "Axe"
	chop.add_child(axe)
	B.mesh(axe, B.cyl(0.02, 0.025, 0.7, 8), Vector3(0, 0.35, 0), Color(0.75, 0.6, 0.35))
	B.mesh(axe, B.boxm(Vector3(0.16, 0.1, 0.03)), Vector3(0.05, 0.02, 0), Color(0.3, 0.3, 0.32))
	# Halkoja pölkyn vieressä.
	for i in 4:
		var h := B.mesh(self, B.cyl(0.07, 0.07, 0.38, 5), CHOP_LOCAL + Vector3(0.6 + i * 0.1, 0.07, 0.3 - i * 0.18), Color(0.72, 0.58, 0.38))
		h.rotation = Vector3(PI / 2.0, i * 0.7, 0)
	var cb := StaticBody3D.new()
	cb.position = CHOP_LOCAL + Vector3(0, 0.25, 0)
	cb.add_child(B.box_shape(Vector3(0.6, 0.5, 0.6)))
	add_child(cb)


## Lintutorni: neljä pylvästä, tasanne kaiteineen, kattokatos ja suorat portaat maasta ylös.
func _build_tower() -> void:
	var wood := Color(0.5, 0.36, 0.22)
	var t := StaticBody3D.new()
	t.position = TOWER_LOCAL
	t.rotation.y = -0.5
	add_child(t)
	var h := TOWER_TOP_Y
	var s := 3.2
	for x in [-s / 2.0, s / 2.0]:
		for z in [-s / 2.0, s / 2.0]:
			B.mesh(t, B.boxm(Vector3(0.22, h + 2.4, 0.22)), Vector3(x, (h + 2.4) / 2.0, z), wood)
	# Vinotuet.
	for side in 4:
		var brace := B.mesh(t, B.boxm(Vector3(0.08, 4.4, 0.08)), Vector3(0, h / 2.0, 0), wood.darkened(0.15))
		var ang := side * PI / 2.0
		brace.position = Vector3(cos(ang), 0, sin(ang)) * (s / 2.0) + Vector3(0, h / 2.0, 0)
		brace.rotation = Vector3(0, -ang + PI / 2.0, 0.62)
	# Tasanne ja kaide.
	B.mesh(t, B.boxm(Vector3(s + 0.3, 0.12, s + 0.3)), Vector3(0, h, 0), wood.lightened(0.1))
	t.add_child(B.box_shape(Vector3(s + 0.3, 0.12, s + 0.3), Vector3(0, h, 0)))
	var rail_h := 1.05
	for side in 4:
		var ang := side * PI / 2.0
		var n := Vector3(cos(ang), 0, sin(ang))
		var along := Vector3(-n.z, 0, n.x)
		var len := s + 0.3
		if side == 3:
			# Portaiden aukko (-Z-puolella) kaiteessa.
			for sx in [-1.0, 1.0]:
				var seglen := (len - 1.0) / 2.0
				var c: Vector3 = n * (len / 2.0) + along * sx * (0.5 + seglen / 2.0)
				var rr := B.mesh(t, B.boxm(Vector3(seglen, 0.08, 0.06)), c + Vector3(0, h + rail_h, 0), wood)
				rr.rotation.y = -atan2(along.z, along.x)
				t.add_child(_rot_box_shape(Vector3(seglen, rail_h, 0.1), c + Vector3(0, h + rail_h / 2.0, 0), -atan2(along.z, along.x)))
			continue
		var rail := B.mesh(t, B.boxm(Vector3(len, 0.08, 0.06)), n * (len / 2.0) + Vector3(0, h + rail_h, 0), wood)
		rail.rotation.y = -atan2(along.z, along.x)
		var mid := B.mesh(t, B.boxm(Vector3(len, 0.06, 0.04)), n * (len / 2.0) + Vector3(0, h + rail_h * 0.5, 0), wood)
		mid.rotation.y = -atan2(along.z, along.x)
		t.add_child(_rot_box_shape(Vector3(len, rail_h, 0.1), n * (len / 2.0) + Vector3(0, h + rail_h / 2.0, 0), -atan2(along.z, along.x)))
	# Katos.
	var roof := PrismMesh.new()
	roof.size = Vector3(s + 0.9, 1.0, s + 0.9)
	B.mesh(t, roof, Vector3(0, h + 2.9, 0), Color(0.22, 0.2, 0.19))
	# Portaat: -Z-suuntaan, nousu h, kallistus n. 33°.
	var run := h / tan(deg_to_rad(33.0))
	var steps := int(h / 0.2)
	var stair := Node3D.new()
	stair.position = Vector3(0, 0, -(s + 0.3) / 2.0)
	t.add_child(stair)
	for i in steps:
		var f := (i + 0.5) / steps
		B.mesh(stair, B.boxm(Vector3(0.95, 0.05, run / steps + 0.04)), Vector3(0, f * h, -run * (1.0 - f)), wood.lightened(0.05))
	for sx in [-0.5, 0.5]:
		var sl := B.mesh(stair, B.boxm(Vector3(0.06, 0.25, sqrt(run * run + h * h))), Vector3(sx, h / 2.0, -run / 2.0), wood)
		sl.rotation.x = -atan2(h, run)
		var hr := B.mesh(stair, B.boxm(Vector3(0.05, 0.05, sqrt(run * run + h * h))), Vector3(sx, h / 2.0 + 0.95, -run / 2.0), wood)
		hr.rotation.x = -atan2(h, run)
		t.add_child(_rot_box_shape(Vector3(0.08, 1.2, sqrt(run * run + h * h)), stair.position + Vector3(sx + signf(sx) * 0.05, h / 2.0 + 0.5, -run / 2.0), 0.0, -atan2(h, run)))
	# Kävelyramppi portaiden alle (törmäys), jotta jalan pääsee ylös.
	var ramp := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	# Alapää upotettu maahan (ei porrasta), -Z-pää alhaalla.
	var ext := 1.2
	var slope := atan2(h, run)
	rs.size = Vector3(0.95, 0.1, sqrt(run * run + h * h) + ext)
	ramp.shape = rs
	ramp.transform = Transform3D(Basis(Vector3.RIGHT, -slope),
		stair.position + Vector3(0, h / 2.0 - 0.06 - sin(slope) * ext / 2.0, -run / 2.0 - cos(slope) * ext / 2.0))
	t.add_child(ramp)
	var tag := B.sign_plate(t, "LINTUTORNI", Color(0.36, 0.2, 0.1), Color(0.98, 0.95, 0.86), 0.2, 32, Color(0.3, 0.18, 0.1), "Helvetica Neue")
	tag.position = Vector3(0, 1.8, -s / 2.0 - 0.12)
	tag.rotation.y = PI
	_no_sign(t, Vector3(0.9, 1.4, -s / 2.0 - 0.12), PI, "Yli 5 hengen\noleskelu kielletty")


func _rot_box_shape(size: Vector3, pos: Vector3, yaw: float, pitch := 0.0) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch), pos)
	return cs


func _build_people() -> void:
	var apo := R * cos(PI / 8.0)
	var spots := [[RAIMO, "raimo", 3, "Kodan vakiovieras Raimo"], [VEIKKO, "veikko", 5, "Kodan vakiovieras Veikko"]]
	for sp in spots:
		var k: int = sp[2]
		var a := PI / 2.0 + k * PI / 4.0
		var dir := Vector3(cos(a), 0, -sin(a))
		var c := Looks.make(self, sp[0])
		c.position = dir * (apo - 0.62) + Vector3(0, 0.2, 0)
		c.rotation.y = B.yaw_to(-dir)  # kasvot tulta kohti
		c.play("Sitting_Idle", 0.0)
		if sp[1] == "raimo":
			raimo = c
		else:
			veikko = c
		var bubble := B.label(self, "", c.position + Vector3(0, 1.65, 0), 16, Color.WHITE, true)
		bubble.outline_size = 6
		bubble.width = 700.0
		bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubbles[sp[1]] = bubble
		_bubble_t[sp[1]] = 0.0
		var name := B.guide(self, sp[3], c.position + Vector3(0, 1.3, 0), 12, Color(1, 0.9, 0.6), true)
		name.no_depth_test = false


## Linnut järven yllä ja joutsenet vedessä.
func _build_birds() -> void:
	for i in 7:
		var b := Node3D.new()
		add_child(b)
		for sx in [-1.0, 1.0]:
			var wing := Node3D.new()
			b.add_child(wing)
			B.mesh(wing, B.boxm(Vector3(0.55, 0.03, 0.18)), Vector3(sx * 0.3, 0, 0), Color(0.15, 0.15, 0.17))
		B.mesh(b, B.capsule(0.07, 0.4), Vector3.ZERO, Color(0.2, 0.2, 0.22), Vector3(PI / 2.0, 0, 0))
		_birds.append(b)
	for i in 3:
		var s := Node3D.new()
		s.position = TOWER_LOCAL + Vector3(16.0 + i * 3.5, 0.0, 12.0 + i * 2.2)
		s.rotation.y = i * 1.3
		add_child(s)
		var white := Color(0.97, 0.97, 0.95)
		var body := B.mesh(s, B.sphere(0.35, 12), Vector3(0, 0.15, 0), white)
		body.scale = Vector3(1.0, 0.6, 1.5)
		var neck := B.mesh(s, B.cyl(0.05, 0.06, 0.6, 8), Vector3(0, 0.45, -0.4), white)
		neck.rotation.x = -0.2
		B.mesh(s, B.sphere(0.08, 8), Vector3(0, 0.76, -0.47), white)
		B.mesh(s, B.cyl(0.02, 0.035, 0.12, 6), Vector3(0, 0.74, -0.58), Color(0.95, 0.8, 0.1), Vector3(PI / 2.0, 0, 0))
		_swans.append(s)
