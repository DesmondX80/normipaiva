extends Node3D
## Kaisuan tila (Kaisuantie 38, Neittävä, noin 230 m mökiltä länteen): maatilan hommat Farming Simulatorin
## tapaan. Mökin lapsi (mokki.gd ensure_built) mökin paikallisessa kehyksessä origossa; pysyvä tila on main.gd:n
## kaisua_tila.gd-oliossa (Kaisua.mokki_tila; Altaan tilalla oma). Paikka (pellot, piha, isäntä, tekstit):
## maatila_paikka.gd (site).
##
## Piha talon (OSM) ympärillä: konevaja (työkoneet ja siemensäkit), lato (paalit), viljankuivuri vastaanotto-
## suppiloineen, KAISUA-kyltti tien varressa ja isäntä. Pellot (kaisua_pelto.gd): Kotipelto ja Ojanvarsi ovat
## nurmea, Tienvarsipelto ja Isopelto ohraa. Koneet (kaisua_ajoneuvo.gd, kaisua_koneet.gd): vanha traktori
## etukuormaimineen ja leikkuupuimuri; traktoriin kytketään niittokone, karhotin, paalain, äes, kylvökone tai viljakärry.
##
## Työketjut: heinä = niitto -> karhous -> paalaus -> paalit latoon; vilja = puinti -> vilja kuivuriin (puimurin
## purkuputkella kärryyn ja kärry kipataan suppiloon, tai puimuri suoraan suppilolle) ja kevättyöt = äestys ->
## kylvö (siemen konevajan säkeistä); oras kasvaa puintikypsäksi päivissä. Isäntä maksaa jokaisesta valmiista
## työstä (yli 92 % pellosta), kutsuu talkooruoalle ja koko ketjun jälkeen antaa saunakaljat; ketjut ovat
## legendaarisia hetkiä. main.gd kuuntelee signaalit ja vaihtaa pelaajan koneen rattiin ja pois.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Mokki := preload("res://scripts/mokki.gd")
const Tila := preload("res://scripts/kaisua_tila.gd")
const Pelto := preload("res://scripts/kaisua_pelto.gd")
const Koneet := preload("res://scripts/kaisua_koneet.gd")
const Ajoneuvo := preload("res://scripts/kaisua_ajoneuvo.gd")

static var mokki_tila: Tila  # Kaisuan pysyvä tila (main.gd asettaa ennen mökin rakentamista)
var tila: Tila  # tämän tilan pysyvä tila (build ottaa mokki_tila:n Kaisualle, muuten uusi tai annettu)
var site: RefCounted  # maatila_paikka.gd: pellot, piha, isäntä, tekstit (null = Kaisua)

signal message(text: String, secs: float)
signal paid(amount: float, why: String)
signal legend(id: String)
signal food_eaten
signal beers_given(n: int)
signal mount(vehicle: Node3D)
signal dismount(vehicle: Node3D, pos: Vector3)
signal helper_changed(on: bool)  # Santtu lähti mökiltä ajamaan (true) tai palasi (false): mökin Santtu piiloon

# --- Piha: paikka-asetukset (maatila_paikka.gd site) -------------------------------------------------------------
const Paikka := preload("res://scripts/maatila_paikka.gd")
const BALE_PRICE := 6.0
## Isännän ja Raijan vartalon mitat ovat samat kuin Saloisten jyväjemmarilla ja laavun akalla (Looks.JEMMARI ja AKKA):
## vartaloprofiili (character.gd profile_key) on silloin jo valmiina, eikä mökin rakennus kasva 2,4 s:lla.

## Palkat (€): hehtaarilta tai paalilta, vilja kilolta.
const PAY := {"niitto": 30.0, "karhous": 18.0, "paalaus": 2.5, "latoon": 2.0, "puinti": 55.0, "kuivuri": 0.012,
	"kynto": 35.0, "kivet": 0.0, "kivi": 0.6, "aestys": 28.0, "kylvo": 28.0}
const JOB_NAMES := {"niitto": "niitetty", "karhous": "karhottu", "paalaus": "paalattu", "latoon": "paalit ladossa",
	"puinti": "puitu", "kuivuri": "vilja kuivurissa", "kynto": "kynnetty", "kivet": "kivet kerätty", "aestys": "äestetty",
	"kylvo": "kylvetty"}
## Työ ja tilat, jotka sen jälkeen ovat tekemättä (osuus <= DONE = valmis, >= READY = työ on taas edessä).
const JOBS := {
	"heina": [["niitto", [1, 2, 3]], ["karhous", [4]], ["paalaus", [5]], ["latoon", []]],
	"vilja": [["puinti", [15]], ["kuivuri", []], ["kynto", [10, 16, 17]], ["kivet", []], ["aestys", [18]], ["kylvo", [11]]],
}
## Työn esiehto: edellinen työ maksettu (vilja: puinti -> kuivuri ja kyntö -> äestys -> kylvö ovat erilliset ketjut;
## kivien keruu kynnön jälkeen on oma työnsä, ei äestyksen ehto).
const PREREQ := {"karhous": "niitto", "paalaus": "karhous", "latoon": "paalaus", "kuivuri": "puinti", "kivet": "kynto",
	"aestys": "kynto", "kylvo": "aestys"}
const DONE := 0.08
const READY := 0.9
const SEED_KG := 300.0  # kylvökoneen säiliö
const TRAILER_MAX := 5000.0
const UNLOAD_RATE := 140.0  # kg/s purkuputkesta
const TIP_RATE := 420.0  # kg/s kärrystä suppiloon

var pellot: Array = []
var traktori: Ajoneuvo
var puimuri: Ajoneuvo
var koneet := {}  # id -> {"root": Node3D, "parts": Dictionary}
var bale_nodes: Array = []  # tila.bales-järjestyksessä
var isanta: Node3D
var built := false
var build_ms := 0  # rakennusaika (testit tulostavat)
var status := ""  # koneen tilarivi ratissa (main.gd näyttää mopon mittarin paikalla): nopeus, kone, pelto ja työ
var day := 0
var house_door := Vector3.ZERO  # talkooruoalle: kuistin portaiden edusta (_build_house)
var money := 0.0  # pelaajan rahat (main.gd asettaa): apumiehen palkkio
var helper_field := -1  # pelto, jota Santtu ajaa
var helper_rate_override := 0.0  # testit: Santun aikakerroin (0 = pelaajan etäisyyden mukaan)
var clock_min := 720.0  # kellonaika (main.gd asettaa): sade
var rain_amount := 0.0  # sateen voimakkuus 0…1 pehmeästi (main.gd tummentaa taivaan ja valon)
var rain_force := -1.0  # testit: sade päälle (1) tai pois (0) kellosta riippumatta
var _rain: GPUParticles3D
var _rain_snd: AudioStreamPlayer3D
var _wet := -1.0

var _lato: Dictionary
var _konevaja: Dictionary
var _kuivuri: Dictionary
var _bubble: Label3D
var _bubble_t := 0.0
var _check_t := 0.0
var _tipping := 0.0  # kärryn kippaus: lavan kulma (0 = alhaalla)
var _tip_on := false
var _gate_t := 0.0  # paalaimen luukku auki (s)
var _talk_i := 0
var _nag_t := 0
var stone_nodes: Array = []  # tila.stones-järjestyksessä
var _kasat := {}  # pellon indeksi -> kivikasan paikka (paikallinen)
var _carry := -1  # kannettavan kiven indeksi (jalan), -1 = tyhjät kädet
var _diesel: Node3D
var _kanister := false  # dieselkanisteri kädessä (jalan)
var _empty_told := {}  # kone -> diesel loppui -viesti näytetty


func _ready() -> void:
	set_meta("ground", true)  # mokki.gd ensure_built ei siirrä (kaikki on jo maassa)


## Rakentaa tilan (mokki.gd ensure_built). Pysyvä tila: annettu tila, Kaisualle Kaisua.mokki_tila, muuten tyhjä.
func build() -> void:
	if built:
		return
	built = true
	var t0 := Time.get_ticks_msec()
	_lap_t = Time.get_ticks_usec()
	if site == null:
		site = Paikka.kaisua()
	if tila == null:
		tila = mokki_tila if site.id == "kaisua" and mokki_tila != null else Tila.new()
	tila.defs = site.fields
	tila.section = site.section
	house_door = site.house_door
	for i in tila.defs.size():
		var p := Pelto.new()
		add_child(p)
		if p.setup(tila, i, site):
			pellot.append(p)
		else:
			p.queue_free()
		_lap("pelto%d" % i)
	_build_yard()
	_lap("piha")
	_build_machines()
	_lap("koneet")
	_build_bales()
	_build_stones()
	_lap("paalit_kivet")
	_build_isanta()
	_lap("isanta")
	_build_naapuri()
	_lap("naapuri")
	build_ms = Time.get_ticks_msec() - t0


var build_laps := {}  # vaihe -> ms (testit tulostavat)
var _lap_t := 0


func _lap(name: String) -> void:
	var now := Time.get_ticks_usec()
	if _lap_t > 0:
		build_laps[name] = (now - _lap_t) / 1000
	else:
		build_laps[name] = 0
	_lap_t = now


func _gy(x: float, z: float) -> float:
	return site.height.call(x, z)


func _place(n: Node3D, pos: Vector3, yaw: float) -> void:
	n.position = Vector3(pos.x, _gy(pos.x, pos.z) + pos.y, pos.z)
	n.rotation.y = yaw


func _build_yard() -> void:
	_build_gravel()
	_build_house()
	_lato = Koneet.lato(self)
	_place(_lato.root, site.lato[0], site.lato[1])
	_konevaja = Koneet.konevaja(self)
	_place(_konevaja.root, site.konevaja[0], site.konevaja[1])
	_kuivuri = Koneet.kuivuri(self)
	_place(_kuivuri.root, site.kuivuri[0], site.kuivuri[1])
	_diesel = Koneet.diesel_tank(self)
	_place(_diesel, site.diesel[0], site.diesel[1])
	# Kyltti tienvarressa: kaksi tolppaa ja lautakyltti.
	var sign_root := Node3D.new()
	add_child(sign_root)
	_place(sign_root, site.sign[0], site.sign[1])
	for sx in [-0.7, 0.7]:
		B.mesh(sign_root, B.boxm(Vector3(0.1, 1.9, 0.1)), Vector3(sx, 0.95, 0), Color(0.4, 0.3, 0.2))
	var plate := B.sign_plate(sign_root, site.sign_text, Color(0.16, 0.3, 0.18), Color(0.96, 0.94, 0.86), 0.36, 72, Color(0.9, 0.86, 0.75))
	plate.position = Vector3(0, 1.55, 0)
	var sub := B.sign_plate(sign_root, site.sign_sub, Color(0.95, 0.94, 0.9), Color(0.1, 0.1, 0.1), 0.16, 34, Color(0.3, 0.3, 0.3))
	sub.position = Vector3(0, 1.12, 0)
	# Postilaatikko tolpassa kyltin vieressä.
	B.mesh(sign_root, B.boxm(Vector3(0.08, 1.15, 0.08)), Vector3(1.4, 0.57, 0.1), Color(0.4, 0.3, 0.2))
	B.mesh(sign_root, B.boxm(Vector3(0.3, 0.26, 0.45)), Vector3(1.4, 1.25, 0.1), Color(0.85, 0.72, 0.15))


## Päärakennus OSM-pohjan (mokki.gd KAISUA_HOUSE) mukaan: pisin sivu pituudeksi, pihan puoli -Z:ksi, harja
## laserkeilauksesta, lattia 45 cm ylimmän nurkan yllä ja kuisti paikan house_door-kohdalle. house_door = portaiden edusta.
func _build_house() -> void:
	if (site.house as Dictionary).is_empty():
		return
	var ridge: float = site.house.ridge
	var poly: PackedVector2Array = site.house.poly
	var e1 := poly[1] - poly[0]
	var e2 := poly[2] - poly[1]
	var ax := (e1 if e1.length() > e2.length() else e2).normalized()
	var az := ax.orthogonal()
	var mn := Vector2(INF, INF)
	var mx := -mn
	var lo := INF
	var hi := -INF
	for p in poly:
		var q := Vector2((p - poly[0]).dot(ax), (p - poly[0]).dot(az))
		mn = mn.min(q)
		mx = mx.max(q)
		var gh := _gy(p.x, p.y)
		lo = minf(lo, gh)
		hi = maxf(hi, gh)
	var cen := poly[0] + ax * ((mn.x + mx.x) / 2.0) + az * ((mn.y + mx.y) / 2.0)
	var hd: Vector3 = site.house_door
	var n := az if az.dot(Vector2(hd.x, hd.z) - cen) > 0.0 else -az  # kuistin puoli (ovi)
	var yaw := atan2(-n.x, -n.y)  # mallin -Z -> n
	var xa := Vector2(cos(yaw), -sin(yaw))  # mallin +X
	var L := mx.x - mn.x
	var W := mx.y - mn.y
	var door_x := clampf((Vector2(hd.x, hd.z) - cen).dot(xa), -L / 2.0 + 2.2, L / 2.0 - 2.2)
	var floor_y := hi + 0.45
	var front := cen + xa * door_x + n * (W / 2.0 + 3.0)
	var step_drop := maxf(0.18, floor_y - _gy(front.x, front.y))
	var d := Koneet.paarakennus(self, L, W, ridge, door_x, floor_y - lo, step_drop)
	var root: Node3D = d.root
	root.position = Vector3(cen.x, floor_y, cen.y)
	root.rotation.y = yaw
	house_door = root.transform * (d.door as Vector3)
	house_door.y = 0.0


## Pihan sora (paikan yard_circles): maastoverkon ruudukko pinnassa, reuna rikkonainen (varjostin karsii
## ympyröiden ulkopuolen kohinan mukaan), joten sora vaihtuu nurmeen luonnollisesti.
func _build_gravel() -> void:
	var lo := Vector2(INF, INF)
	var hi := -lo
	var circles := PackedVector3Array()
	for y in site.yard_circles:
		var c: Vector2 = y[0]
		var r: float = y[1]
		lo = lo.min(c - Vector2.ONE * (r + 6.0))
		hi = hi.max(c + Vector2.ONE * (r + 6.0))
		circles.append(Vector3(c.x, c.y, r))
	# Maastoverkon ruudukossa (paikan kärkiväli, origo ja lävistäjä), jolloin sora on tarkasti maan pinnassa.
	var gs: float = site.grid_step
	var go: Vector2 = site.grid_origin
	lo = go + ((lo - go) / gs).floor() * gs
	var nx := int((hi.x - lo.x) / gs) + 1
	var nz := int((hi.y - lo.y) / gs) + 1
	var hs := PackedFloat32Array()
	hs.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			hs[j * (nx + 1) + i] = _gy(lo.x + i * gs, lo.y + j * gs) + 0.03
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for j in nz:
		for i in nx:
			var cc := lo + Vector2(i + 0.5, j + 0.5) * gs
			var inside := false
			for c in circles:
				if cc.distance_to(Vector2(c.x, c.y)) < c.z + 5.0:  # varjostimen reuna enintään +3 m
					inside = true
			if not inside:
				continue
			var v := func(di: int, dj: int) -> Vector3:
				return Vector3(lo.x + (i + di) * gs, hs[(j + dj) * (nx + 1) + i + di], lo.y + (j + dj) * gs)
			var corners: Array = [v.call(0, 0), v.call(1, 0), v.call(1, 1), v.call(0, 0), v.call(1, 1), v.call(0, 1)] if site.diag_main \
				else [v.call(0, 0), v.call(1, 0), v.call(0, 1), v.call(1, 0), v.call(1, 1), v.call(0, 1)]
			for corner in corners:
				st.add_vertex(corner)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/kaisua_piha.gdshader")
	var cv: Array[Vector3] = []
	for c in circles:
		cv.append(c)
	var count := cv.size()
	while cv.size() < 8:
		cv.append(Vector3(0, 0, -1))
	m.set_shader_parameter("circles", cv)
	m.set_shader_parameter("circle_count", count)
	m.set_shader_parameter("noise_tex", Pelto._noise())
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Traktori, puimuri ja työkoneet tallennetuille paikoille (tai kotipaikoille), kytketty kone traktorin perään.
func _build_machines() -> void:
	traktori = Ajoneuvo.new()
	traktori.kind = "traktori"
	add_child(traktori)
	puimuri = Ajoneuvo.new()
	puimuri.kind = "puimuri"
	add_child(puimuri)
	for v in [traktori, puimuri]:
		var veh: Node3D = v
		veh.work_fn = _apply_work
		veh.to_local_fn = to_local
		_restore(veh, veh.kind)
	for id in Koneet.IMPLEMENTS:
		var k := Koneet.implement(self, id)
		koneet[id] = k
		_restore(k.root, id)
	if tila.hitched != "" and koneet.has(tila.hitched):
		_hitch_now(tila.hitched)
	puimuri.tank = tila.tank
	traktori.fuel = float(tila.fuel.get("traktori", 1.0))
	puimuri.fuel = float(tila.fuel.get("puimuri", 1.0))


func _restore(n: Node3D, id: String) -> void:
	var m: Dictionary = tila.machines.get(id, {})
	if m.is_empty():
		_place(n, site.home[id][0], site.home[id][1])
	else:
		var p: Vector3 = m.pos
		n.position = Vector3(p.x, _gy(p.x, p.z), p.z)
		n.rotation.y = float(m.yaw)


## Koneiden paikat talteen (main.gd tallentaa).
func sync_state() -> void:
	if not built:
		return
	for v in [traktori, puimuri]:
		var veh: Node3D = v
		tila.machines[veh.kind] = {"pos": veh.position, "yaw": veh.rotation.y}
	for id in koneet:
		var r: Node3D = koneet[id].root
		if id == tila.hitched:
			continue
		tila.machines[id] = {"pos": r.position, "yaw": r.rotation.y}
	for i in bale_nodes.size():
		var bn: Node3D = bale_nodes[i]
		if is_instance_valid(bn) and bn.get_parent() == self:
			tila.bales[i].pos = bn.position
			tila.bales[i].yaw = bn.rotation.y
	tila.tank = puimuri.tank
	tila.fuel = {"traktori": traktori.fuel, "puimuri": puimuri.fuel}


func _build_bales() -> void:
	var slot := 0
	for i in tila.bales.size():
		var b: Dictionary = tila.bales[i]
		var n := Koneet.paali(self)
		if b.lato:
			n.transform = _stack_xf(slot)
			slot += 1
		else:
			var p: Vector3 = b.pos
			_place(n, p, float(b.yaw))
		bale_nodes.append(n)


## Paalin paikka ladon pinossa (järjestysnumero): 7 riviä x 4 syvyyttä x 2 kerrosta, akseli syvyyssuunnassa.
func _stack_xf(slot: int) -> Transform3D:
	var layer := slot / 28
	var r := slot % 28
	var col := r % 7
	var row := r / 7
	var lr: Node3D = _lato.root
	var local := Vector3(-3.75 + col * 1.25, 0.05 + layer * 1.22, 2.4 - row * 1.3)
	return lr.transform * Transform3D(Basis(Vector3.UP, PI / 2.0), local)


func _build_isanta() -> void:
	isanta = Looks.make(self, site.isanta_look)
	_place(isanta, site.isanta[0], site.isanta[1])
	isanta.play("Idle", 0.0)
	_bubble = B.bubble(self, isanta.position + Vector3(0, 2.05, 0), Color.WHITE)
	B.guide(self, site.isanta_name, isanta.position + Vector3(0, 2.25, 0), 34, Color(1, 0.9, 0.6), true)


func say(text: String, secs := 3.5) -> void:
	if _bubble != null:
		_bubble.text = text
		_bubble_t = secs


func _process(delta: float) -> void:
	if not built:
		return
	_helper_tick()
	_rain_tick(delta)
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.text = ""
	if _naapuri_t > 0.0:
		_naapuri_t -= delta
		if _naapuri_t <= 0.0:
			_naapuri_bubble.text = ""
	if _gate_t > 0.0 and koneet.has("paalain"):
		_gate_t -= delta
		var gate: Node3D = koneet.paalain.parts.gate
		gate.rotation.x = -1.4 * clampf(minf(_gate_t, 1.6 - _gate_t) * 3.0, 0.0, 1.0)


## Päivä vaihtui: kasvu ja pellot uudelleen.
func advance_day(d: int) -> void:
	day = d
	if tila.last_day == d:
		return
	tila.advance_to(d)
	for p in pellot:
		(p as Pelto).refresh_all()


# --- Sää ----------------------------------------------------------------------------------------------------------

func raining() -> bool:
	if rain_force >= 0.0:
		return rain_force > 0.5
	var w := Tila.rain_window(day, site.rain_offset)
	return w.x >= 0.0 and clock_min >= w.x and clock_min < w.y


## Poutaa odotellessa: sateen loppuminen tekstinä ("klo 15").
func rain_end_text() -> String:
	var w := Tila.rain_window(day, site.rain_offset)
	return "klo %d" % ceili(w.y / 60.0) if w.x >= 0.0 else "pian"


## Sade näkyviin kameran ympärille (pisarat, ääni) ja pellot märiksi; voimakkuus nousee ja laskee pehmeästi.
func _rain_tick(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and to_local(cam.global_position).distance_to(site.yard) < float(site.rain_radius)
	rain_amount = move_toward(rain_amount, 1.0 if raining() and near else 0.0, delta / 8.0)
	if rain_amount > 0.0 and _rain == null:
		_rain = GPUParticles3D.new()
		_rain.top_level = true
		_rain.amount = 2400
		_rain.lifetime = 1.1
		_rain.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 30, 40))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(18, 0.5, 18)
		pm.direction = Vector3(0.08, -1, 0.03)
		pm.spread = 2.0
		pm.initial_velocity_min = 13.0
		pm.initial_velocity_max = 16.0
		pm.gravity = Vector3.ZERO
		_rain.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.012, 0.45)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.78, 0.82, 0.88, 0.32)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material = m
		_rain.draw_pass_1 = q
		add_child(_rain)
		_rain_snd = Sfx.loop_on(_rain, "sade", -60.0)
	if _rain != null:
		_rain.emitting = rain_amount > 0.05
		_rain.amount_ratio = rain_amount
		if cam != null:
			_rain.global_position = cam.global_position + Vector3(0, 9.0, 0) - cam.global_basis.z * 6.0
		_rain_snd.stream_paused = rain_amount <= 0.01
		_rain_snd.volume_db = linear_to_db(maxf(rain_amount, 0.001)) - 6.0
	var wet := snappedf(rain_amount, 0.05)
	if wet != _wet:
		_wet = wet
		for p in pellot:
			(p as Pelto).set_wet(wet)


# --- Apumies ---------------------------------------------------------------------------------------------------------

const HELPER_FEE := 15.0
const HELPER_R := 3.2  # traktorin ja työkoneen käännössäde reitillä (m)
const HELPER_STEP := 0.4


## Traktorin vieressä jalan: Santtu ajaa koneen työn pellolla, jonka seuraava työ se on (Q), tai Santun ajon tila ja
## keskeytys.
func _helper_logic(walker: Node3D, q: bool) -> String:
	if (site.helper as Dictionary).is_empty():
		return ""
	var t := traktori
	var seat := t.to_global(Vector3(-1.3, 0, 0.3))
	if Vector2(walker.global_position.x - seat.x, walker.global_position.z - seat.z).length() > 3.0:
		return ""
	if t.helper_active():
		if q:
			_stop_helper(site.helper.stop)
			return ""
		return "%s ajaa: %s, %d %%  ·  %s Keskeytä" % [site.helper.name, _pelto(helper_field).field_name(), roundi(t.helper_progress() * 100.0),
			Settings.cap("bell")]
	if t.implement == null:
		return ""
	var info: Dictionary = Koneet.IMPLEMENTS[t.implement_id]
	if info.work == "":
		return ""
	var fi := _helper_field_for(info.work)
	if fi < 0:
		return ""
	var pe := _pelto(fi)
	if money < HELPER_FEE:
		return "%s ajaisi %s (%d €), mutta rahat ei riitä" % [site.helper.name, pe.field_name(), roundi(HELPER_FEE)]
	if q:
		_start_helper(fi, info)
		return ""
	return "%s Pyydä %s ajamaan: %s, %s (%d €)" % [Settings.cap("bell"), site.helper.name, pe.field_name(), _job_label(info.work).to_lower(),
		roundi(HELPER_FEE)]


## Pelto traktorin kohdalla tai enintään 25 m päässä, jonka seuraava työ on op.
func _helper_field_for(op: String) -> int:
	var lp := to_local(traktori.global_position)
	var p := Vector2(lp.x, lp.z)
	for r in [0.0, 8.0, 16.0, 25.0]:
		for k in (1 if r == 0.0 else 12):
			var q: Vector2 = p + Vector2(cos(k * TAU / 12.0), sin(k * TAU / 12.0)) * r
			var fi := _field_at(q)
			if fi >= 0 and String(_next_job(_pelto(fi)).get("id", "")) == op:
				return fi
	return -1


func _start_helper(fi: int, info: Dictionary) -> void:
	var pe := _pelto(fi)
	var path := helper_path(pe, info, to_local(traktori.global_position), traktori.rotation.y)
	if path.size() < 2:
		message.emit(site.helper.none, 2.5)
		return
	paid.emit(-HELPER_FEE, "")
	helper_field = fi
	traktori.start_helper(path, site.helper.look)
	if site.helper.get("away", false):
		helper_changed.emit(true)
	# Dieselin tarve: reitin pituus työnopeudella ja kuormalla (moottori töissä noin 0,85).
	var need := path.size() * HELPER_STEP / float(info.speed) * (Ajoneuvo.FUEL_IDLE + Ajoneuvo.FUEL_LOAD * 0.85)
	var fuel_note := ""
	if need > traktori.fuel:
		fuel_note = " Diesel riittää noin %d %%:iin pellosta, tankkaa välillä." % roundi(traktori.fuel / need * 100.0)
	message.emit((site.helper.start as String) % [roundi(HELPER_FEE), pe.field_name()] + fuel_note, 4.5)


func _stop_helper(msg: String) -> void:
	traktori.stop_helper()
	if site.helper.get("away", false):
		helper_changed.emit(false)
	sync_state()
	_check_jobs()
	if msg != "":
		message.emit(msg, 3.5)


## Santun ajo: aikakerroin pelaajan etäisyydestä (kaukana 4×, ettei kokonaista peltoa tarvitse odottaa vieressä) ja
## lopetus, kun reitti on ajettu tai diesel loppui.
func _helper_tick() -> void:
	var t := traktori
	if not t.helper_active():
		return
	var cam := get_viewport().get_camera_3d()
	var far := cam != null and cam.global_position.distance_to(t.global_position) > 120.0
	t.helper_rate = helper_rate_override if helper_rate_override > 0.0 else (4.0 if far else 1.0)
	if t.helper_done:
		var fname := _pelto(helper_field).field_name()
		if t.fuel <= 0.0:
			_stop_helper(site.helper.fuel_out % fname)
		else:
			_stop_helper(site.helper.done % fname)


## Santun reitti pellolle (Kaisuan kehys): kaistat koneen työleveyden välein pellon pituussuuntaan (paalaimella karhoja
## pitkin), sivuun asennetun koneen (niittokone, aura) siirtymä huomioiden. Kaistat ajetaan reunasta reunaan
## edestakaisin; jos kaistaväli on alle kaksi kääntösädettä, joka toinen kaista ensin (puoliympyräkäännös) ja paluu väliin
## jääneitä pitkin; vierekkäisen kaistan käännös Ω:na. Käännökset pellon sisällä peruuttaen (_turn). Alkuun kaari
## traktorin kohdalta lähimmän kaistan päähän. [[Vector2, työssä, peruutus], ...] 0,4 m välein.
func helper_path(pe: Pelto, info: Dictionary, from: Vector3, from_yaw: float) -> Array:
	var op: String = info.work
	var cx: float = (info.c as Vector3).x
	# Työalueen takareunan etäisyys traktorin takana: kone kiinni nostimessa (T_LINK) tai aisassa (T_HITCH).
	var rear: float = (info.c as Vector3).z + float(info.hl) + (Koneet.T_HITCH.z if info.mount == "aisa" else Koneet.T_LINK.z)
	var spacing: float = float(info.hw) * 2.0 * 0.92
	# Päisteet: kierrokset reunaa myöten (karhotin ja paalain karhottimen kierrosten kohdalta, jotta reunakarhot
	# kerätään), sisäosa kaistoina päisteen sisäreunaan asti.
	var lap_sp := spacing
	var laps := ceili(7.0 / spacing)
	var rake_sp: float = float(Koneet.IMPLEMENTS.karhotin.hw) * 2.0 * 0.92
	if op == "karhous":
		lap_sp = rake_sp
		laps = 2
	elif op == "paalaus":
		# Noukin kiertää koko karhottimen päisteen (2 kierrosta) leveydeltä: reunakarhot ja päisteeseen ulottuvat
		# karhojen päät kerätään, karhottiinpa pelto miten tahansa.
		laps = ceili(2.0 * rake_sp / spacing)
	var head := laps * lap_sp
	var todo: Array = []  # tilat, joissa työtä on jäljellä (kesken jäänyt työ: tehdyt kaistat ja kierrokset ohitetaan)
	for j in JOBS[pe.kind()]:
		if j[0] == op:
			todo = j[1]
	var poly: PackedVector2Array = pe.poly
	var inner: Array = Geometry2D.offset_polygon(poly, -head)
	# Kapea tai käyrä sisäosa (leveys 2 × ala / piiri alle kolme kierrosväliä): suorat kaistat eivät kata sitä, joten
	# kierroksia jatketaan spiraalina keskelle asti eikä kaistoja ajeta.
	var in_area := 0.0
	var in_perim := 0.0
	for ip: PackedVector2Array in inner:
		in_area += _poly_area(ip)
		for i in ip.size():
			in_perim += ip[i].distance_to(ip[(i + 1) % ip.size()])
	if not inner.is_empty() and in_perim > 0.0 and 2.0 * in_area / in_perim < 3.0 * lap_sp:
		while laps < 40 and not _round_offset(poly, (laps + 0.5) * lap_sp).is_empty():
			laps += 1
		inner = []
	var dir: Vector2
	var offsets: Array = []
	var c: Vector2 = pe.center
	if op == "paalaus":
		var wr := _windrows(pe)
		dir = wr[0]
		offsets = wr[1]
	else:
		dir = _field_axis(pe)
		# Kaistat päisteen sisäosan leveydeltä (ei pellon keskipisteestä): kapeaankin sisäosaan osuu kaista.
		var rt := Vector2(-dir.y, dir.x)
		var omin := INF
		var omax := -INF
		for ip: PackedVector2Array in inner:
			for q in ip:
				omin = minf(omin, (q - c).dot(rt))
				omax = maxf(omax, (q - c).dot(rt))
		if omax > omin:
			var n_l := maxi(1, ceili((omax - omin) / spacing))
			var sp2 := (omax - omin) / n_l
			for k in n_l:
				offsets.append(omin + sp2 * (k + 0.5))
	var right := Vector2(-dir.y, dir.x)
	var lanes: Array = []  # [poikittainen, alku, loppu] (alku < loppu dir-suunnassa), päisteen sisällä
	var tr := int(maxf(pe.nx, pe.nz) * 0.5) + 4
	for off: float in offsets:
		var lo := INF
		var hi := -INF
		for k in range(-tr, tr + 1):
			var q: Vector2 = c + right * off + dir * (k * 0.5)
			if pe.has_point(q) and _in_any(q, inner):
				lo = minf(lo, k * 0.5)
				hi = maxf(hi, k * 0.5)
		if hi - lo > 2.0 and _has_todo(pe, c + right * off + dir * lo, c + right * off + dir * hi, float(info.hw), todo):
			lanes.append([off, lo, hi])
	var pts: Array = []  # [Vector2, työssä, peruutus]
	var cur := Vector2(from.x, from.z)
	var cur_f := Vector2(-sin(from_yaw), -cos(from_yaw))
	# Kierrokset ulkoa sisään: kulmat pyöristetty kääntösäteellä, sisäpuoli vasemmalla (sivukone ulkoreunan puolella).
	for k in laps:
		var d := (k + 0.5) * lap_sp
		for loop: PackedVector2Array in _round_offset(poly, d):
			if loop.size() < 3:
				continue
			if not todo.is_empty():
				var cnt := Vector2i.ZERO
				for i in loop.size():
					cnt += _todo_count(pe, loop[i], loop[(i + 1) % loop.size()], float(info.hw), todo)
				if cnt.y == 0 or float(cnt.x) / cnt.y <= 0.03:
					continue  # kierros jo ajettu (kulmissa voi jäädä yksittäisiä ruutuja)
			var start := 0
			var best := INF
			for i in loop.size():
				if loop[i].distance_to(cur) < best:
					best = loop[i].distance_to(cur)
					start = i
			var lp: Array = []
			for i in loop.size() + 1:
				lp.append(loop[(start + i) % loop.size()])
			var f1: Vector2 = ((lp[1] as Vector2) - (lp[0] as Vector2)).normalized()
			# Sivukoneen siirtymä sisäänpäin: traktori kulkee kierroksella cx sisempänä (vasemmalla).
			var shifted: Array = []
			for i in lp.size():
				var fa: Vector2 = ((lp[mini(i + 1, lp.size() - 1)] as Vector2) - (lp[maxi(i - 1, 0)] as Vector2)).normalized()
				shifted.append((lp[i] as Vector2) - Vector2(-fa.y, fa.x) * cx)
			_bezier(pts, cur, cur_f, shifted[0], f1)
			for i in range(1, shifted.size()):
				_line(pts, shifted[i - 1], shifted[i], true)
			cur = shifted[-1]
			cur_f = ((shifted[-1] as Vector2) - (shifted[-2] as Vector2)).normalized()
	if lanes.is_empty():
		return _resample(pts) if pts.size() > 1 else []
	var order: Array = []
	var min_gap := INF
	for i in range(1, lanes.size()):
		min_gap = minf(min_gap, float(lanes[i][0]) - float(lanes[i - 1][0]))
	if min_gap >= HELPER_R * 2.0 or lanes.size() < 3:
		order = range(lanes.size())
	else:
		for i in range(0, lanes.size(), 2):
			order.append(i)
		var odd := range(1, lanes.size(), 2)
		odd.reverse()
		order.append_array(odd)
	if (c + right * float(lanes[order[-1]][0])).distance_to(cur) < (c + right * float(lanes[order[0]][0])).distance_to(cur):
		order.reverse()
	# Ensimmäisen kaistan suunta: aloitetaan lähempää päästä.
	var l0: Array = lanes[order[0]]
	var fwd := (c + right * float(l0[0]) + dir * float(l0[1])).distance_to(cur) < (c + right * float(l0[0]) + dir * float(l0[2])).distance_to(cur)
	var first := true
	for idx in order.size():
		var ln: Array = lanes[order[idx]]
		var f := dir if fwd else -dir
		var side := Vector2(-f.y, f.x)  # traktorin oikea kylki ajosuunnassa
		var base := c + right * float(ln[0]) - side * cx
		# Päisteen sisäreunasta toiseen; loppuun koneen takaulottuma, jotta kone ehtii reunaan asti (keula päisteellä).
		var a := base + dir * (float(ln[1]) if fwd else float(ln[2]))
		var b := base + dir * (float(ln[2]) if fwd else float(ln[1])) + f * rear
		if first:
			_bezier(pts, cur, cur_f, a, f)
			first = false
		else:
			_turn(pts, pts[-1][0], a, -f)
		_line(pts, a, b, true)
		fwd = not fwd
	return _resample(pts)


## Tekemättömät näytteet janalla a–b (työleveys ±hw): [tekemättä, peltoa]. Työleveyden reunaruudut jäävät usein osin
## tekemättä, joten reunasta 40 cm jätetään pois.
func _todo_count(pe: Pelto, a: Vector2, b: Vector2, hw: float, todo: Array) -> Vector2i:
	var f := (b - a).normalized() if a.distance_to(b) > 0.01 else Vector2.RIGHT
	var side := Vector2(-f.y, f.x)
	var n := maxi(1, ceili(a.distance_to(b) / 0.8))
	var lim := maxf(0.25, hw - 0.4)
	var out := Vector2i.ZERO
	for i in n + 1:
		var q := a.lerp(b, float(i) / n)
		var o := -lim
		while o <= lim + 0.01:
			var st := pe.state_at(q + side * o)
			if st != Tila.NONE:
				out.y += 1
				if st in todo:
					out.x += 1
			o += 0.5
	return out


## Onko janalla (kaista) työtä jäljellä: yli 3 % näytteistä tekemättä (kesken jääneen työn jatko ohittaa tehdyt).
func _has_todo(pe: Pelto, a: Vector2, b: Vector2, hw: float, todo: Array) -> bool:
	if todo.is_empty():
		return true
	var cnt := _todo_count(pe, a, b, hw, todo)
	return cnt.y > 0 and float(cnt.x) / cnt.y > 0.03


func _in_any(q: Vector2, polys: Array) -> bool:
	for pl: PackedVector2Array in polys:
		if Geometry2D.is_point_in_polygon(q, pl):
			return true
	return false


## Reunasta d:n verran sisään, kulmat pyöristetty kääntösäteellä (ensin d + R sisään terävin kulmin, sitten R ulos
## pyöreästi).
func _round_offset(poly: PackedVector2Array, d: float) -> Array:
	var out: Array = []
	var src: Array = []
	for p1: PackedVector2Array in Geometry2D.offset_polygon(poly, -(d + HELPER_R), Geometry2D.JOIN_MITER):
		src.append_array(Geometry2D.offset_polygon(p1, HELPER_R, Geometry2D.JOIN_ROUND))
	# Pyöristys ei mahdu (keskimmäinen kierros) tai se katkaisee kapean kaulan (kierros jakautuu tai menettää ison osan
	# alasta): kierros ajetaan terävin kulmin, jotta kapeakin kohta tulee ajettua (traktori oikaisee kulmat).
	var plain: Array = Geometry2D.offset_polygon(poly, -d)
	var a_src := 0.0
	var a_plain := 0.0
	for q: PackedVector2Array in src:
		a_src += _poly_area(q)
	for q: PackedVector2Array in plain:
		a_plain += _poly_area(q)
	if src.is_empty() or src.size() > plain.size() or a_src < 0.8 * a_plain:
		src = plain
	for p2: PackedVector2Array in src:
		if p2.size() < 3:
			continue
		var loop := p2
		# Sisäpuoli vasemmalla: ajosuunnan oikea kylki (sivukone) ulkoreunaa kohti.
		var e0 := loop[1] - loop[0]
		var mid := (loop[0] + loop[1]) / 2.0
		var left := -Vector2(-e0.y, e0.x).normalized()
		if not Geometry2D.is_point_in_polygon(mid + left * 0.5, loop):
			loop = loop.duplicate()
			loop.reverse()
		out.append(loop)
	return out


func _poly_area(q: PackedVector2Array) -> float:
	var a := 0.0
	for i in q.size():
		var b := q[(i + 1) % q.size()]
		a += q[i].x * b.y - b.x * q[i].y
	return absf(a) / 2.0


## Pellon pääsuunta: pisin reunan sivu (kulma 0…π).
func _field_axis(pe: Pelto) -> Vector2:
	var poly: PackedVector2Array = pe.poly
	var best := Vector2.RIGHT
	var bl := 0.0
	for i in poly.size():
		var e := poly[(i + 1) % poly.size()] - poly[i]
		if e.length() > bl:
			bl = e.length()
			best = e.normalized()
	return best


## Karhojen suunta (työsuuntien keskiarvo kaksinkertaisella kulmalla) ja keskilinjat poikittain pellon keskipisteestä
## (0,5 m lokerot, vierekkäiset lokerot samaa karhoa).
func _windrows(pe: Pelto) -> Array:
	var cells: PackedByteArray = pe._f.cells
	var dirs: PackedByteArray = pe._f.dir
	var sc := 0.0
	var ss := 0.0
	var idx: Array[int] = []
	for k in cells.size():
		if cells[k] == Tila.H_KARHO:
			idx.append(k)
			var a := dirs[k] / 255.0 * PI
			sc += cos(2.0 * a)
			ss += sin(2.0 * a)
	var ang := atan2(ss, sc) / 2.0
	var dir := Vector2(cos(ang), sin(ang))
	var right := Vector2(-dir.y, dir.x)
	var bins := {}
	for k in idx:
		var q := pe.origin + (Vector2(k % pe.nx, k / pe.nx) + Vector2(0.5, 0.5)) * Tila.CELL
		var bi := roundi((q - pe.center).dot(right) / 0.5)
		bins[bi] = int(bins.get(bi, 0)) + 1
	var keys := bins.keys()
	keys.sort()
	var offs: Array = []
	var run: Array = []
	for bk: int in keys:
		if not run.is_empty() and bk - int(run[-1]) > 2:
			offs.append(_run_center(run, bins))
			run = []
		run.append(bk)
	if not run.is_empty():
		offs.append(_run_center(run, bins))
	return [dir, offs]


func _run_center(run: Array, bins: Dictionary) -> float:
	var s := 0.0
	var w := 0.0
	for bk: int in run:
		s += bk * 0.5 * float(bins[bk])
		w += float(bins[bk])
	return s / w


## Suora reitin osa; rev = peruutus (kone osoittaa kulkusuuntaa vastaan).
func _line(pts: Array, a: Vector2, b: Vector2, work: bool, rev := false) -> void:
	var n := maxi(1, ceili(a.distance_to(b) / HELPER_STEP))
	for i in n + 1:
		pts.append([a.lerp(b, float(i) / n), work, rev])


## Päisteen käännös pellon sisällä: kaistan päästä (b, ajosuunta f) peruutetaan nostetuin konein käännösviivalle, joka
## on kummankin kaistan reunasta käännöksen mitan verran sisempänä, käännytään seuraavalle kaistalle puoliympyränä
## (kaistaväli >= 2R) tai Ω:na (ensin poispäin α, ympäri π + 2α, takaisin α; sivusiirto 4R cos α - 2R) ja peruutetaan
## seuraavan kaistan alkuun pellon reunaan; kone laskeutuu peruutuksessa. Näin traktori ei aja pientareelle eikä puihin.
func _turn(pts: Array, b: Vector2, a_next: Vector2, f: Vector2) -> void:
	var n := Vector2(-f.y, f.x)
	var lat := (a_next - b).dot(n)
	var sg := signf(lat) if absf(lat) > 0.01 else 1.0
	var arcs: Array = []
	var extent := 0.0  # käännöksen ulottuma ajosuuntaan
	if absf(lat) >= HELPER_R * 2.0:
		arcs = [[sg, absf(lat) / 2.0, PI]]
		extent = absf(lat) / 2.0
	else:
		var al := acos(clampf((absf(lat) + 2.0 * HELPER_R) / (4.0 * HELPER_R), -1.0, 1.0))
		arcs = [[-sg, HELPER_R, al], [sg, HELPER_R, PI + 2.0 * al], [-sg, HELPER_R, al]]
		extent = 2.0 * HELPER_R * sin(al) + HELPER_R
	var line_at := minf(b.dot(f), a_next.dot(f)) - extent - 0.6
	var e := b + f * (line_at - b.dot(f))
	var s2 := a_next + f * (line_at - a_next.dot(f))
	_line(pts, b, e, false, true)
	var p := e
	var h := atan2(f.y, f.x)
	for arc in arcs:
		var r: float = arc[1]
		var n_steps := maxi(2, ceili(r * float(arc[2]) / HELPER_STEP))
		var dh: float = float(arc[0]) * float(arc[2]) / n_steps
		for i in n_steps:
			h += dh / 2.0
			p += Vector2(cos(h), sin(h)) * r * absf(dh)
			h += dh / 2.0
			pts.append([p, false, false])
	_line(pts, p, s2, false)
	_line(pts, s2, a_next, true, true)


## Alkukaari traktorin kohdalta ja suunnasta kaistan alkuun (kuutiollinen Bézier).
func _bezier(pts: Array, p0: Vector2, f0: Vector2, p3: Vector2, f3: Vector2) -> void:
	var k := maxf(4.0, p0.distance_to(p3) / 3.0)
	var p1 := p0 + f0 * k
	var p2 := p3 - f3 * k
	var n := maxi(8, ceili(p0.distance_to(p3) / 0.1))
	var first := pts.size()
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		pts.append([p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t, false, false])
	# Viimeiset 3,5 m kone laskettuna: ehtii laskeutua ennen pellon reunaa.
	var d := 0.0
	for i in range(pts.size() - 1, first, -1):
		d += (pts[i][0] as Vector2).distance_to(pts[i - 1][0])
		if d > 3.5:
			break
		pts[i][1] = true


## Tasavälinen reitti (HELPER_STEP): pisteet kaarenpituuden mukaan, työlippu lähimmästä alkuperäisestä pisteestä.
func _resample(pts: Array) -> Array:
	var out: Array = [[pts[0][0], pts[0][1], pts[0][2]]]
	var carry := 0.0
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1][0]
		var b: Vector2 = pts[i][0]
		var d := a.distance_to(b)
		var t := HELPER_STEP - carry
		while t <= d:
			out.append([a.lerp(b, t / d), pts[i][1], pts[i][2]])
			t += HELPER_STEP
		carry = d - (t - HELPER_STEP)
	return out


# --- Työt pellolla -------------------------------------------------------------------------------------------------

## Koneen työ (kaisua_ajoneuvo.gd work_fn): pelloille, joiden alueella työalue on; heinä paalaimeen, vilja säiliöön,
## siemen säiliöstä.
func _apply_work(op: String, c: Vector2, f: Vector2, hw: float, hl: float) -> Dictionary:
	var tot := {"cells": 0, "hay": 0.0, "grain": 0.0, "seed": 0.0, "stones": []}
	if op == "puinti" and puimuri.tank >= Ajoneuvo.TANK_MAX:
		return tot
	if (op == "paalaus" or op == "puinti") and raining():
		if Time.get_ticks_msec() > _nag_t and _field_at(c) >= 0:
			_nag_t = Time.get_ticks_msec() + 15000
			message.emit("%s on märkää: %s odottaa poutaa (sade loppuu %s)." % ["Heinä" if op == "paalaus" else "Vilja",
				"paalaus" if op == "paalaus" else "puinti", rain_end_text()], 4.0)
		return tot
	if op == "kylvo" and tila.seed <= 0.0:
		return tot
	var r := hw + hl + 1.0
	for p in pellot:
		var pe: Pelto = p
		var bb := Rect2(pe.origin, Vector2(pe.nx, pe.nz) * Tila.CELL).grow(r)
		if not bb.has_point(c):
			continue
		var res := pe.work(op, c, f, hw, hl, tila.seed * SEED_KG)
		if int(res.cells) > 0:
			var bk := tila.book(pe.index)
			bk[op] = true
		for k in ["cells", "hay", "grain", "seed"]:
			tot[k] += res[k]
		for sp: Vector2 in res.stones:
			_add_stone(sp, pe.index)
		if op == "aestys" and int(res.cells) == 0 and pe.share([Tila.V_SANKI, Tila.V_PUITU, Tila.V_OLKI]) > 0.3 \
				and pe.has_point(c) and Time.get_ticks_msec() > _nag_t:
			_nag_t = Time.get_ticks_msec() + 15000
			message.emit("Äes ei pure sänkeen: %s pitää kyntää ensin (aura konevajan suulla)." % pe.field_name(), 4.0)
	if op == "paalaus" and tot.hay > 0.0:
		tila.baler_hay += tot.hay
		if tila.baler_hay >= Tila.BALE_HAY:
			tila.baler_hay -= Tila.BALE_HAY
			_eject_bale(_field_at(c))
	elif op == "puinti" and tot.grain > 0.0:
		puimuri.tank = minf(Ajoneuvo.TANK_MAX, puimuri.tank + tot.grain)
		tila.tank = puimuri.tank
		var fi := _field_at(c)
		if fi >= 0:
			tila.book(fi).harvested = float(tila.book(fi).get("harvested", 0.0)) + tot.grain
		if puimuri.tank >= Ajoneuvo.TANK_MAX:
			puimuri.set_working(false)
			message.emit("Viljasäiliö täynnä (%d kg)! Pura kärryyn tai suoraan kuivurin suppilolle." % roundi(puimuri.tank), 4.0)
	elif op == "kylvo" and tot.seed > 0.0:
		tila.seed = maxf(0.0, tila.seed - tot.seed / SEED_KG)
		if tila.seed <= 0.0:
			traktori.set_working(false)
			message.emit("Kylvökoneesta loppui siemen. Täytä säiliö konevajan siemensäkeistä.", 4.0)
	return tot


func _field_at(c: Vector2) -> int:
	for p in pellot:
		var pe: Pelto = p
		if pe.has_point(c):
			return pe.index
	return -1


func _pelto(i: int) -> Pelto:
	for p in pellot:
		if (p as Pelto).index == i:
			return p
	return null


## Paalain pudottaa käärityn paalin perästään (luukku aukeaa).
func _eject_bale(field: int) -> void:
	var pr: Node3D = koneet.paalain.root
	var n := Koneet.paali(self)
	n.global_position = pr.to_global(Vector3(0, 0, 3.7))
	n.global_rotation = Vector3(0, pr.global_rotation.y, 0)
	n.position.y = _gy(n.position.x, n.position.z)
	bale_nodes.append(n)
	tila.bales.append({"pos": n.position, "yaw": n.rotation.y, "field": field, "lato": false, "kind": "sailo"})
	if field >= 0:
		var bk := tila.book(field)
		bk.baled = int(bk.get("baled", 0)) + 1
	_gate_t = 1.6
	Sfx.play_on(pr, "whoosh", -4.0, 0.6)
	var tw := create_tween()
	var end := n.position + n.basis.z * 1.2
	end.y = _gy(end.x, end.z)
	tw.tween_property(n, "position", end, 0.6).set_delay(0.5)


# --- Pelaajan toiminnot ---------------------------------------------------------------------------------------------

## Kehyksen pelaajalogiikka (main.gd _kaisua_logic): palauttaa vihjetekstin ("" = ei mitään täällä).
func logic(player: Node3D, walker: Node3D, e: bool, f: bool, q: bool, delta: float) -> String:
	if not built:
		return ""
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.5
		_check_jobs()
	_unload_tick(delta)
	if player == traktori:
		return _tractor_logic(e, f, q)
	if player == puimuri:
		return _combine_logic(e, f)
	if player != walker:
		return ""
	var p := to_local(walker.global_position)
	var near := func(lp: Vector3, r: float) -> bool:
		return Vector2(p.x - lp.x, p.z - lp.z).length() < r
	if near.call(isanta.position, 2.6):
		if e:
			_talk()
		return "%s Juttele isännän kanssa%s" % [Settings.cap("interact"), "  ·  talkooruoka odottaa pirtissä" if tila.food_due else ""]
	if tila.food_due and tila.food_day != day and near.call(house_door, 2.0):
		if e:
			_eat()
		return "%s Talkooruoalle pirttiin" % Settings.cap("interact")
	var dh := _diesel_walk_logic(walker, p, e)
	if dh != "":
		return dh
	var sh := _stone_logic(walker, p, e)
	if sh != "":
		return sh
	var hh := _helper_logic(walker, q)  # Santun pyyntö tai ajon tila traktorin vieressä
	for v in [traktori, puimuri]:
		var veh: Node3D = v
		if veh == traktori and traktori.helper_active():
			continue
		var seat := veh.to_global(Vector3(-1.3, 0, 0.3 if veh == traktori else -0.8))
		if Vector2(walker.global_position.x - seat.x, walker.global_position.z - seat.z).length() < 2.0:
			if f or e:
				_mount(veh)
			var line := "%s %s" % [Settings.cap("mount"), "Traktorin rattiin" if veh == traktori else "Puimurin ohjaamoon"]
			return line if veh != traktori or hh == "" else line + "  ·  " + hh
	return hh


func _mount(veh: Node3D) -> void:
	(veh as Ajoneuvo).set_driven(true)
	mount.emit(veh)
	if veh == traktori and not tila.talked:
		say("Traktori käy ku junan vessa! Kytke kone perään peruuttamalla, ja töihin.", 4.0)


func _dismount(veh: Node3D) -> void:
	(veh as Ajoneuvo).set_driven(false)
	var side := veh.global_transform.basis.x * -1.0
	var pos := veh.global_position + side * (1.5 if veh == traktori else 2.0) + Vector3.UP * 0.5
	if veh == puimuri:
		pos += veh.global_transform.basis.z * -0.8
	sync_state()
	dismount.emit(veh, pos)


func _tractor_logic(e: bool, f: bool, q: bool) -> String:
	var t: Ajoneuvo = traktori
	var keys := "%s ajo  ·  %s ohjaus" % [Settings.pair("forward", "back"), Settings.pair("left", "right")]
	if f:
		if absf(t.speed) > 1.0:
			message.emit("Pysäytä ensin!", 1.2)
		else:
			_dismount(t)
			return ""
	var lines: Array[String] = []
	var st: Array[String] = ["Traktori %d km/h  ·  diesel %d %%" % [roundi(absf(t.speed) * 3.6), roundi(t.fuel * 100.0)]]
	var action := ""
	var fa := _fuel_action(t, e)
	if fa != "":
		action = fa
		e = false
	# Paalipiikki: paali ladoon tai maahan, vapaa paali piikkiin.
	var sp := t.spear_point()
	var drop: Vector3 = site.naapuri.get("drop", Vector3.INF)
	var drop_g := to_global(Vector3(drop.x, _gy(drop.x, drop.z), drop.z)) if drop != Vector3.INF else Vector3.INF
	if t.bale != null and tila.order_left > 0 and Vector2(sp.x - drop_g.x, sp.z - drop_g.z).length() < 5.0:
		action = "%s Toimita paali naapurin Raijalle (%d / %d)" % [Settings.cap("interact"), tila.order_total - tila.order_left + 1, tila.order_total]
		if e:
			_deliver_bale()
			e = false
	elif t.bale != null:
		var door: Vector3 = _lato.root.to_global(_lato.door)
		if Vector2(sp.x - door.x, sp.z - door.z).length() < 5.0:
			action = "%s Paali latoon" % Settings.cap("interact")
			if e:
				_bale_to_lato()
				e = false
		else:
			action = "%s Laske paali maahan" % Settings.cap("interact")
			if e:
				_bale_drop()
				e = false
	else:
		var bi := _bale_near(sp, 1.3)
		var door2: Vector3 = _lato.root.to_global(_lato.door)
		if bi >= 0:
			action = "%s Paali piikkiin" % Settings.cap("interact")
			if e:
				t.take_bale(bale_nodes[bi])
				e = false
		elif tila.order_left > 0 and tila.bales_in_lato() > 0 and Vector2(sp.x - door2.x, sp.z - door2.z).length() < 5.0:
			action = "%s Ota paali ladosta (Raijan tilaus %d paalia)" % [Settings.cap("interact"), tila.order_left]
			if e:
				_bale_from_lato()
				e = false
	# Takana kytketty kone.
	if t.implement != null:
		var info: Dictionary = Koneet.IMPLEMENTS[t.implement_id]
		var istat: String = info.name
		if t.implement_id == "kylvokone":
			istat += " (siementä %d kg)" % roundi(tila.seed * SEED_KG)
			var sd: Vector3 = _konevaja.root.to_global(_konevaja.seed)
			if action == "" and tila.seed < 0.98 and t.implement.global_position.distance_to(sd) < 6.0:
				action = "%s Täytä siemensäiliö säkeistä" % Settings.cap("interact")
				if e:
					tila.seed = 1.0
					Sfx.play_on(t, "water", -6.0, 0.5)
					message.emit("Siemensäiliö täynnä: 300 kg ohraa.", 2.5)
					e = false
		elif t.implement_id == "paalain":
			istat += " (kammio %d %%)" % roundi(tila.baler_hay / Tila.BALE_HAY * 100.0)
		elif t.implement_id == "perakarry":
			var ks := _trailer_stones()
			istat += " (%s)" % ("%d kiveä" % ks if ks > 0 else "%d kg" % roundi(tila.trailer))
			if action == "" and tila.trailer > 0.0 and not _tip_on and _trailer_at_pit():
				action = "%s Kippaa vilja kuivurin suppiloon" % Settings.cap("interact")
				if e:
					_tip_on = true
					e = false
			var kasa := _trailer_at_kasa()
			if action == "" and ks > 0 and not _tip_on and kasa >= 0:
				action = "%s Kippaa kivet kivikasaan" % Settings.cap("interact")
				if e:
					_tip_stones(kasa)
					e = false
		if info.work != "":
			istat += "  ·  " + ("TYÖSSÄ" if t.working else "nostettu")
			if action == "":
				action = "%s %s" % [Settings.cap("interact"), "Nosta kone" if t.working else "Laske kone töihin"]
				if e:
					t.set_working(not t.working)
		st.append(istat)
		if absf(t.speed) < 0.5 and not t.working:
			lines.append("%s Irrota %s" % [Settings.cap("bell"), String(info.name).to_lower()])
			if q:
				_unhitch()
	else:
		var hid := _hitchable()
		if hid != "":
			lines.append("%s Kytke %s" % [Settings.cap("bell"), String(Koneet.IMPLEMENTS[hid].name).to_lower()])
			if q:
				_hitch_now(hid)
	var fl := _field_status(to_local(t.global_position))
	if fl != "":
		st.append(fl)
	if raining():
		st.append("sataa (poutaa %s)" % rain_end_text())
	status = "  ·  ".join(st)
	if action != "":
		lines.insert(0, action)
	lines.append(keys + "  ·  %s pois" % Settings.cap("mount"))
	return "  ·  ".join(lines)


func _combine_logic(e: bool, f: bool) -> String:
	var c: Ajoneuvo = puimuri
	if f:
		if absf(c.speed) > 1.0:
			message.emit("Pysäytä ensin!", 1.2)
		else:
			c.unloading = false
			_dismount(c)
			return ""
	var lines: Array[String] = []
	var st: Array[String] = ["Puimuri %d km/h  ·  säiliö %d / %d kg  ·  diesel %d %%" % [roundi(absf(c.speed) * 3.6), roundi(c.tank),
		roundi(Ajoneuvo.TANK_MAX), roundi(c.fuel * 100.0)]]
	var fa := _fuel_action(c, e)
	if fa != "":
		lines.append(fa)
		e = false
	if c.working:
		st.append("PUIMASSA")
	var target := _unload_target()
	if c.unloading:
		lines.append("%s Lopeta purku" % Settings.cap("interact"))
		if e:
			c.unloading = false
	elif target != "" and c.tank > 0.0:
		lines.append("%s Pura vilja %s" % [Settings.cap("interact"), "kärryyn" if target == "karry" else "kuivurin suppiloon"])
		if e:
			c.unloading = true
			c.set_working(false)
	else:
		lines.append("%s %s" % [Settings.cap("interact"), "Nosta leikkuupöytä" if c.working else "Laske leikkuupöytä ja puimaan"])
		if e:
			c.set_working(not c.working)
	var fl := _field_status(to_local(c.global_position))
	if fl != "":
		st.append(fl)
	if raining():
		st.append("sataa: vilja märkää (poutaa %s)" % rain_end_text())
	status = "  ·  ".join(st)
	lines.append("%s ajo  ·  %s ohjaus  ·  %s pois" % [Settings.pair("forward", "back"), Settings.pair("left", "right"), Settings.cap("mount")])
	return "  ·  ".join(lines)


## Pellon nimi ja seuraavan työn eteneminen koneen kohdalla.
func _field_status(lp: Vector3) -> String:
	var fi := _field_at(Vector2(lp.x, lp.z))
	if fi < 0:
		return ""
	var pe := _pelto(fi)
	var job := _next_job(pe)
	if job.is_empty():
		return "%s (%.2f ha)" % [pe.field_name(), pe.area / 10000.0]
	return "%s (%.2f ha): %s %d %%" % [pe.field_name(), pe.area / 10000.0, job.name, roundi(job.progress * 100.0)]


## Pellon seuraava maksamaton työ, joka on nyt tehtävissä: {"id", "name", "progress"} (tyhjä = ei mitään).
## Esiehdollinen työ (karhous, paalaus, kuivuri, kylvö) on tehtävissä heti edellisen jälkeen; ketjun ensimmäinen,
## kun pelto on sen vaiheessa (vähintään 30 % ruuduista) tai työ on aloitettu.
func _next_job(pe: Pelto) -> Dictionary:
	var bk := tila.book(pe.index)
	for j in JOBS[pe.kind()]:
		var id: String = j[0]
		if tila.is_paid(pe.index, id):
			continue
		if PREREQ.has(id) and not tila.is_paid(pe.index, PREREQ[id]):
			continue
		var todo: Array = j[1]
		if todo.is_empty():
			return {"id": id, "name": _job_label(id), "progress": 0.0}
		if not PREREQ.has(id) and not bk.has(id) and pe.share(todo) < 0.3:
			continue  # pelto ei ole tämän työn vaiheessa
		return {"id": id, "name": _job_label(id), "progress": _progress(pe, id, todo)}
	return {}


## Työn eteneminen: tekemättömät ruudut suhteessa suurimpaan nähtyyn määrään (karhot ovat vain kuudesosa pellosta,
## joten osuus koko pellosta ei kelpaa).
func _progress(pe: Pelto, id: String, todo: Array) -> float:
	var bk := tila.book(pe.index)
	var cnt := 0
	for st in todo:
		cnt += int(pe.counts.get(st, 0))
	var mx := maxi(int(bk.get("max_" + id, 0)), cnt)
	bk["max_" + id] = mx
	if mx == 0:
		return 0.0
	return clampf(1.0 - float(cnt) / mx, 0.0, 1.0)


func _job_label(id: String) -> String:
	return {"niitto": "niitto", "karhous": "karhous", "paalaus": "paalaus", "latoon": "paalit latoon", "puinti": "puinti",
		"kuivuri": "vilja kuivuriin", "kynto": "kyntö", "kivet": "kivien keruu", "aestys": "äestys", "kylvo": "kylvö"}[id]


func _bale_near(p: Vector3, r: float) -> int:
	var best := -1
	var bd := r
	for i in bale_nodes.size():
		var n: Node3D = bale_nodes[i]
		if not is_instance_valid(n) or n.get_parent() != self or tila.bales[i].lato or tila.bales[i].get("sold", false):
			continue
		var c := n.global_position + Vector3.UP * 0.62
		var d := c.distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


func _bale_drop() -> void:
	var n := traktori.drop_bale(self)
	if n == null:
		return
	var i := bale_nodes.find(n)
	if i >= 0:
		tila.bales[i].pos = n.position
		tila.bales[i].yaw = n.rotation.y
	Sfx.play_on(traktori, "body_fall", -6.0, 0.6)


func _bale_to_lato() -> void:
	var n := traktori.drop_bale(self)
	if n == null:
		return
	var i := bale_nodes.find(n)
	if i < 0:
		return
	var slot := tila.bales_in_lato()
	tila.bales[i].lato = true
	var xf := _stack_xf(slot)
	var tw := create_tween()
	tw.tween_property(n, "transform", xf, 0.7)
	Sfx.play_on(traktori, "body_fall", -4.0, 0.5)
	var fi: int = tila.bales[i].field
	var pay := PAY.latoon
	_pay(pay, "Paali latoon")
	if fi >= 0:
		var bk := tila.book(fi)
		bk.stored = int(bk.get("stored", 0)) + 1


func _hitchable() -> String:
	var lp := traktori.link_point()
	var hp := traktori.hitch_point()
	var ty := traktori.global_rotation.y
	for id in koneet:
		if id == tila.hitched:
			continue
		var r: Node3D = koneet[id].root
		var info: Dictionary = Koneet.IMPLEMENTS[id]
		var target := lp if info.mount == "nostin" else hp
		var d := Vector2(r.global_position.x - target.x, r.global_position.z - target.z).length()
		var dy := absf(wrapf(r.global_rotation.y - ty, -PI, PI))
		if d < 1.3 and (dy < 0.6 or info.mount == "aisa" and dy < 1.2):
			return id
	return ""


func _hitch_now(id: String) -> void:
	tila.hitched = id
	var k: Dictionary = koneet[id]
	(k.root as Node3D).global_rotation = Vector3(0, traktori.global_rotation.y, 0)
	if Koneet.IMPLEMENTS[id].mount == "aisa":
		var hp := traktori.hitch_point()
		(k.root as Node3D).global_position = Vector3(hp.x, (k.root as Node3D).global_position.y, hp.z)
	traktori.hitch(id, k.root, k.parts)
	if not tila.talked:
		tila.talked = true


func _unhitch() -> void:
	var id := traktori.implement_id
	var n := traktori.unhitch(self)
	if n == null:
		return
	if koneet[id].parts.has("bar"):
		(koneet[id].parts.bar as Node3D).rotation.z = 0.0  # parkissa palkki maassa
	tila.hitched = ""
	tila.machines[id] = {"pos": n.position, "yaw": n.rotation.y}


## Puimurin purkukohde: kärry (purkuputken pää lavan päällä) tai kuivurin suppilo putken alla.
func _unload_target() -> String:
	var c := puimuri
	var tip: Vector3 = c._model.spout_tip.global_position
	# Ulos käännetyn putken pää (kehyksessä): arvioidaan ulkoasennosta, ettei putkea tarvitse kääntää ensin.
	var out := c.to_global(Vector3(-0.95, 3.85, 1.8) + Vector3(-3.2, 0, 0.2))
	if c.unloading:
		out = tip
	var kr: Node3D = koneet.perakarry.root
	var bed_c := kr.to_global(Vector3(0, 1.2, 3.8))
	if Vector2(out.x - bed_c.x, out.z - bed_c.z).length() < 2.6:
		return "karry"
	var pit: Vector3 = _kuivuri.root.to_global(_kuivuri.pit)
	if Vector2(out.x - pit.x, out.z - pit.z).length() < 2.0:
		return "suppilo"
	return ""


func _trailer_at_pit() -> bool:
	var kr: Node3D = koneet.perakarry.root
	var tail := kr.to_global(Vector3(0, 0, 6.2))
	var pit: Vector3 = _kuivuri.root.to_global(_kuivuri.pit)
	return Vector2(tail.x - pit.x, tail.z - pit.z).length() < 2.2


## Purku ja kippaus ruutu kerrallaan: puimurista kärryyn tai suppiloon, kärrystä suppiloon.
func _unload_tick(delta: float) -> void:
	var c := puimuri
	if c.unloading:
		var target := _unload_target()
		if target == "" or c.tank <= 0.0:
			if c.tank <= 0.0:
				message.emit("Viljasäiliö tyhjä.", 2.0)
			elif absf(c._model.spout.rotation.y + 1.45) < 0.05:
				message.emit("Purkuputki ei osu kärryyn eikä suppiloon.", 2.0)
				c.unloading = false
			if c.tank <= 0.0:
				c.unloading = false
		elif absf(c._model.spout.rotation.y + 1.45) < 0.05:
			var amount := minf(c.tank, UNLOAD_RATE * delta)
			if target == "karry":
				amount = minf(amount, TRAILER_MAX - tila.trailer)
				tila.trailer += amount
				if tila.trailer >= TRAILER_MAX:
					c.unloading = false
					message.emit("Kärry on täynnä (%d kg)." % roundi(tila.trailer), 2.5)
			else:
				_to_dryer(amount)
			c.tank -= amount
			tila.tank = c.tank
	_update_trailer_visual(delta)


func _to_dryer(kg: float) -> void:
	tila.dried += kg
	_pay(kg * PAY.kuivuri, "")


func _update_trailer_visual(delta: float) -> void:
	if not koneet.has("perakarry"):
		return
	var parts: Dictionary = koneet.perakarry.parts
	if _tip_on:
		_tipping = move_toward(_tipping, 0.75, 0.4 * delta)
		(parts.gate as Node3D).rotation.x = -_tipping * 1.2
		if _tipping > 0.5 and tila.trailer > 0.0:
			var amount := minf(tila.trailer, TIP_RATE * delta)
			tila.trailer -= amount
			_to_dryer(amount)
		if tila.trailer <= 0.0:
			_tip_on = false
			message.emit("Vilja kipattu kuivuriin. Kuivurissa yhteensä %d kg." % roundi(tila.dried), 3.0)
	else:
		_tipping = move_toward(_tipping, 0.0, 0.5 * delta)
		(parts.gate as Node3D).rotation.x = -_tipping * 1.2
	(parts.bed as Node3D).rotation.x = _tipping
	var fill := clampf(tila.trailer / TRAILER_MAX, 0.0, 1.0)
	(parts.heap as Node3D).scale.y = maxf(0.01, fill * 0.6)
	(parts.heap as Node3D).position.y = 0.03 + fill * 0.3
	(parts.mound as Node3D).scale = Vector3(0.9, maxf(0.01, fill * 0.35), 2.0)
	(parts.mound as Node3D).position.y = 0.03 + fill * 0.6


# --- Paalikauppa ----------------------------------------------------------------------------------------------------

var naapuri: Node3D
var _naapuri_bubble: Label3D
var _naapuri_t := 0.0


## Naapurin Raija paalipaikalla: tolppakyltti "PAALIT TÄHÄN" ja vanha paali, myydyt paalit tämän päivän ajan.
var naapuri_laps := ""  # testit tulostavat


func _build_naapuri() -> void:
	if (site.naapuri as Dictionary).is_empty():
		return  # ei paalikauppaa tällä tilalla
	var t0 := Time.get_ticks_usec()
	naapuri = Looks.make(self, site.naapuri.look)
	var t1 := Time.get_ticks_usec()
	_place(naapuri, site.naapuri.pos[0], site.naapuri.pos[1])
	naapuri.play("Idle", 0.0)
	_naapuri_bubble = B.bubble(self, naapuri.position + Vector3(0, 1.9, 0), Color.WHITE)
	B.guide(self, "Naapurin Raija", naapuri.position + Vector3(0, 2.1, 0), 34, Color(1, 0.9, 0.6), true)
	var post := Node3D.new()
	add_child(post)
	_place(post, (site.naapuri.drop as Vector3) + Vector3(-2.2, 0, -2.0), PI * 0.6)
	B.mesh(post, B.boxm(Vector3(0.1, 1.5, 0.1)), Vector3(0, 0.75, 0), Color(0.4, 0.3, 0.2))
	var plate := B.sign_plate(post, "PAALIT TÄHÄN", Color(0.88, 0.84, 0.74), Color(0.25, 0.12, 0.08), 0.2, 36, Color(0.45, 0.35, 0.25))
	plate.position = Vector3(0, 1.3, 0.06)
	var t2 := Time.get_ticks_usec()
	var old := Koneet.paali(self)
	_place(old, (site.naapuri.drop as Vector3) + Vector3(1.8, 0, 2.2), 0.4)
	old.scale = Vector3(1.0, 0.97, 1.0)
	naapuri_laps = "hahmo %d, kupla ja kyltti %d, paali %d ms" % [(t1 - t0) / 1000, (t2 - t1) / 1000, (Time.get_ticks_usec() - t2) / 1000]
	# Edellisten päivien myydyt paalit on syötetty: pois tallennuksesta.
	for i in range(tila.bales.size() - 1, -1, -1):
		if tila.bales[i].get("sold", false) and int(tila.bales[i].get("sold_day", -1)) != day:
			tila.bales.remove_at(i)
			(bale_nodes[i] as Node3D).queue_free()
			bale_nodes.remove_at(i)


func naapuri_say(text: String, secs := 4.0) -> void:
	_naapuri_bubble.text = text
	_naapuri_t = secs


## Ladon pinon päällimmäinen paali piikkiin (tilausta varten).
func _bale_from_lato() -> void:
	var last := -1
	for i in tila.bales.size():
		if tila.bales[i].lato:
			last = i
	if last < 0:
		return
	tila.bales[last].lato = false
	traktori.take_bale(bale_nodes[last])


func _deliver_bale() -> void:
	var n := traktori.drop_bale(self)
	if n == null:
		return
	var i := bale_nodes.find(n)
	var k := tila.order_total - tila.order_left
	var slot: Vector3 = (site.naapuri.drop as Vector3) + Vector3((k % 2) * 1.35 - 0.7, 0, -(k / 2) * 1.3)
	var tw := create_tween()
	tw.tween_property(n, "position", Vector3(slot.x, _gy(slot.x, slot.z), slot.z), 0.5)
	tw.parallel().tween_property(n, "rotation", Vector3(0, PI * 0.6, 0), 0.5)
	Sfx.play_on(traktori, "body_fall", -4.0, 0.5)
	if i >= 0:
		tila.bales[i].sold = true
		tila.bales[i].sold_day = day
		tila.bales[i].pos = slot
	tila.order_left -= 1
	_pay(BALE_PRICE, "Paali Raijalle")
	if tila.order_left <= 0:
		naapuri_say(["Kiitos! Lehmät kiittää, ja tässä vielä pullaa isännälle.", "Hyvät paalit, tuoksuu kesältä!", "No nyt riittää rehua viikoksi. Kiitos!"][randi() % 3], 5.0)
		message.emit("Raijan tilaus toimitettu: %d paalia, %d € taskuun." % [tila.order_total, roundi(BALE_PRICE * tila.order_total)], 4.0)
	else:
		naapuri_say(["Sinne vaan!", "Hyvä, vielä %d." % tila.order_left, "Varo aitaa!"][randi() % 3], 2.5)


# --- Diesel ----------------------------------------------------------------------------------------------------------

## Koneella säiliön vieressä: tankkaus täyteen. Tyhjä tankki: ohje kanisterista (kerran).
func _fuel_action(v: Ajoneuvo, e: bool) -> String:
	var tg := _diesel.global_position
	var vp := v.global_position
	if Vector2(vp.x - tg.x, vp.z - tg.z).length() < (6.5 if v == puimuri else 4.5) and v.fuel < 0.97:
		if e:
			v.fuel = 1.0
			Sfx.play_on(v, "water", -4.0, 0.45)
			message.emit("Tankki täynnä dieseliä. Isäntä kirjaa litrat vihkoon.", 2.5)
		return "%s Tankkaa diesel täyteen" % Settings.cap("interact")
	if v.fuel <= 0.0:
		if not _empty_told.get(v.kind, false):
			_empty_told[v.kind] = true
			message.emit("Diesel loppui, moottori sammui! Hae kanisterilla dieseliä pihan säiliöltä.", 5.0)
			say("No voi nyt... Kanisteri on säiliön vieressä!", 4.0)
		return "Diesel loppui: nouse pois (%s) ja hae kanisterilla pihan säiliöltä" % Settings.cap("mount")
	_empty_told[v.kind] = false
	return ""


## Jalan: kanisteri säiliöltä, kanisterista koneen tankkiin (35 %).
func _diesel_walk_logic(walker: Node3D, p: Vector3, e: bool) -> String:
	if _carry >= 0:
		return ""
	var tl := _diesel.position
	if _kanister:
		for v in [traktori, puimuri]:
			var veh: Ajoneuvo = v
			var vp := to_local(veh.global_position)
			if Vector2(p.x - vp.x, p.z - vp.z).length() < 3.2 and veh.fuel < 0.97:
				if e:
					veh.fuel = minf(1.0, veh.fuel + 0.35)
					_kanister = false
					walker.set_kanister(false)
					Sfx.play_on(veh, "water", -4.0, 0.6)
					message.emit("Kanisterillinen tankkiin: diesel %d %%." % roundi(veh.fuel * 100.0), 2.5)
				return "%s Kaada kanisteri %s tankkiin" % [Settings.cap("interact"), "traktorin" if veh == traktori else "puimurin"]
		if Vector2(p.x - tl.x, p.z - tl.z).length() < 2.5:
			if e:
				_kanister = false
				walker.set_kanister(false)
			return "%s Laske kanisteri säiliön viereen" % Settings.cap("interact")
		return ""
	if Vector2(p.x - tl.x, p.z - tl.z).length() < 2.3:
		if walker.has_method("kanister_on") and walker.kanister_on():
			return "Kädessä on jo kanisteri (toinen homma): vie se ensin perille."
		if e:
			_kanister = true
			walker.set_kanister(true)
			Sfx.play_on(_diesel, "water", -6.0, 0.7)
			return ""
		return "%s Täytä dieselkanisteri (20 l)" % Settings.cap("interact")
	return ""


# --- Kivet --------------------------------------------------------------------------------------------------------

## Kivikasa pellon kulmassa lähimpänä pihaa (viljapellot): vanha raunio, johon kerätyt kivet kasataan.
func _kasa_pos(field: int) -> Vector3:
	if _kasat.has(field):
		return _kasat[field]
	var pe := _pelto(field)
	var best := Vector2.ZERO
	var bd := INF
	for q in pe.poly:
		var d := q.distance_to(Vector2(site.yard.x, site.yard.z))
		if d < bd:
			bd = d
			best = q
	var dir := (best - pe.center).normalized()
	var at := best + dir * 2.5  # pellon reunan ulkopuolelle
	_kasat[field] = Vector3(at.x, 0, at.y)
	return _kasat[field]


func _build_stones() -> void:
	# Vanhat kivikasat viljapeltojen kulmiin.
	for p in pellot:
		var pe: Pelto = p
		if pe.kind() != "vilja":
			continue
		var c := _kasa_pos(pe.index)
		for k in 14:
			var a := k * 2.4
			var r := 0.25 + 0.12 * k
			var sz := 0.3 - 0.008 * k
			var n := Koneet.kivi(self, sz, pe.index * 100 + k)
			n.position = Vector3(c.x + cos(a) * r * 0.6, 0, c.z + sin(a) * r * 0.6)
			n.position.y = _gy(n.position.x, n.position.z) + maxf(0.0, 0.45 - r * 0.25)
	var in_kasa := {}
	for i in tila.stones.size():
		var st: Dictionary = tila.stones[i]
		if st.where == "kasi":
			st.where = "pelto"
		var n := Koneet.kivi(self, float(st.size), i)
		stone_nodes.append(n)
		_place_stone(i, n, in_kasa)


## Kivi paikalleen tilansa mukaan: pellolle, kärryn lavalle tai kasaan (järjestysnumeron mukaan kekoon).
func _place_stone(i: int, n: Node3D, in_kasa := {}) -> void:
	var st: Dictionary = tila.stones[i]
	match st.where:
		"pelto":
			var p: Vector3 = st.pos
			n.position = Vector3(p.x, _gy(p.x, p.z), p.z)
		"karry":
			var bed: Node3D = koneet.perakarry.parts.bed
			if n.get_parent() != bed:
				n.get_parent().remove_child(n)
				bed.add_child(n)
			var k := 0  # monesko kivi lavalla (kivet ennen tätä)
			for q in i:
				if tila.stones[q].where == "karry":
					k += 1
			n.position = Vector3(-0.7 + (k % 5) * 0.35, 0.05, -0.5 - (k / 5) * 0.45)
			n.rotation = Vector3.ZERO
		"kasa":
			var f := int(st.field)
			var k: int = in_kasa.get(f, 0)
			in_kasa[f] = k + 1
			n.position = _kasa_slot(f, k)


func _kasa_slot(field: int, k: int) -> Vector3:
	var c := _kasa_pos(field)
	var a := k * 2.39996 + 0.7
	var r := 0.9 + 0.08 * (k % 25)
	var x := c.x + cos(a) * r
	var z := c.z + sin(a) * r
	return Vector3(x, _gy(x, z) + 0.12 + 0.04 * (k / 25), z)


func _add_stone(p2: Vector2, field: int) -> void:
	var sz := randf_range(0.12, 0.26)
	tila.stones.append({"pos": Vector3(p2.x, 0, p2.y), "field": field, "size": sz, "where": "pelto"})
	var n := Koneet.kivi(self, sz, tila.stones.size() - 1)
	n.position = Vector3(p2.x, _gy(p2.x, p2.y), p2.y)
	stone_nodes.append(n)


func _trailer_stones() -> int:
	return tila.stones.filter(func(st: Dictionary) -> bool: return st.where == "karry").size()


## Jalan: kivi syliin, kärryyn tai kasaan. Palauttaa vihjeen ("" = ei kiviä lähellä).
func _stone_logic(walker: Node3D, p: Vector3, e: bool) -> String:
	if _carry >= 0:
		var kr: Node3D = koneet.perakarry.root
		var bed := kr.to_global(Vector3(0, 0, 3.8))
		var wg := walker.global_position
		var st: Dictionary = tila.stones[_carry]
		var kasa := _kasa_pos(int(st.field))
		if Vector2(wg.x - bed.x, wg.z - bed.z).length() < 3.0:
			if tila.trailer > 0.0:
				return "Kärryssä on viljaa: kiviä ei sekaan. Kanna kivi kivikasaan."
			if e:
				_drop_carry(walker, "karry")
			return "%s Heitä kivi kärryyn" % Settings.cap("interact")
		if Vector2(p.x - kasa.x, p.z - kasa.z).length() < 3.5:
			if e:
				_drop_carry(walker, "kasa")
			return "%s Heitä kivi kivikasaan" % Settings.cap("interact")
		if e:
			_drop_carry(walker, "pelto")
		return "%s Laske kivi maahan  ·  kivikasa pellon kulmassa, tai tuo viljakärry viereen" % Settings.cap("interact")
	var best := -1
	var bd := 1.5
	for i in tila.stones.size():
		var st: Dictionary = tila.stones[i]
		if st.where != "pelto":
			continue
		var sp: Vector3 = st.pos
		var d := Vector2(p.x - sp.x, p.z - sp.z).length()
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return ""
	if e:
		_carry = best
		(stone_nodes[best] as Node3D).visible = false
		var held := Koneet.kivi(null, float(tila.stones[best].size) * 0.8, best)
		held.position = Vector3.ZERO
		walker.set_held(held)
		walker.no_run = true
		Sfx.play("grunt", -6.0, randf_range(0.9, 1.1))
		return ""
	var left := tila.stones_left(int(tila.stones[best].field))
	return "%s Nosta kivi (pellolla %d)" % [Settings.cap("interact"), left]


func _drop_carry(walker: Node3D, where: String) -> void:
	var i := _carry
	_carry = -1
	walker.set_held(null)
	walker.no_run = false
	var st: Dictionary = tila.stones[i]
	var n: Node3D = stone_nodes[i]
	n.visible = true
	if where == "pelto":
		var lp := to_local(walker.global_position + walker.global_transform.basis.z * -0.6)
		st.pos = Vector3(lp.x, 0, lp.z)
	st.where = where
	var from := walker.global_position + Vector3.UP * 1.0
	_place_stone(i, n, _kasa_counts())
	if where != "pelto":
		var end := n.global_position
		n.global_position = from
		var tw := create_tween()
		tw.tween_property(n, "global_position", end, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		Sfx.play_on(n, "rattle_hard", -4.0, randf_range(0.5, 0.7))
	if where == "kasa":
		_pay(PAY.kivi, "Kivi kasaan")


## Kasoissa jo olevien kivien määrät (seuraavan kiven paikka).
func _kasa_counts() -> Dictionary:
	var out := {}
	for st in tila.stones:
		if st.where == "kasa":
			out[int(st.field)] = int(out.get(int(st.field), 0)) + 1
	# Viimeksi kasaan merkitty lasketaan jo mukaan: paikka on sen oma.
	for f in out:
		out[f] = int(out[f]) - 1
	return out


func _trailer_at_kasa() -> int:
	var kr: Node3D = koneet.perakarry.root
	var tail := to_local(kr.to_global(Vector3(0, 0, 6.2)))
	for f in _kasat:
		var c: Vector3 = _kasat[f]
		if Vector2(tail.x - c.x, tail.z - c.z).length() < 5.0:
			return f
	return -1


## Kärryn kivet kasaan: lava nousee, kivet vierivät kekoon (palkka kiveltä).
func _tip_stones(field: int) -> void:
	var bed: Node3D = koneet.perakarry.parts.bed
	var n_st := 0
	var counts := _kasa_counts()
	for f in counts:
		counts[f] = int(counts[f]) + 1
	for i in tila.stones.size():
		var st: Dictionary = tila.stones[i]
		if st.where != "karry":
			continue
		st.field = field
		st.where = "kasa"
		var n: Node3D = stone_nodes[i]
		var keep := n.global_transform
		bed.remove_child(n)
		add_child(n)
		n.global_transform = keep
		var k: int = counts.get(field, 0)
		counts[field] = k + 1
		var tw := create_tween()
		tw.tween_property(n, "position", _kasa_slot(field, k), 0.6).set_delay(0.6 + n_st * 0.05)
		n_st += 1
	var tw2 := create_tween()
	tw2.tween_property(bed, "rotation:x", 0.7, 0.6)
	tw2.tween_property(bed, "rotation:x", 0.0, 0.8).set_delay(0.8)
	Sfx.play_on(bed, "rattle_hard", -2.0, 0.5)
	_pay(PAY.kivi * n_st, "%d kiveä kasaan" % n_st)


# --- Työt valmiiksi, maksut ja talkoopalkka ------------------------------------------------------------------------

func _check_jobs() -> void:
	for p in pellot:
		var pe: Pelto = p
		var bk := tila.book(pe.index)
		var jobs: Array = JOBS[pe.kind()]
		var reset := false
		for j in jobs:
			var todo: Array = j[1]
			if not todo.is_empty() and pe.share(todo) >= READY and tila.is_paid(pe.index, j[0]):
				reset = true  # työ on taas edessä (nurmi kasvoi, ohra kypsyi tai pelto puitiin): uusi kierros
		if reset:
			tila.new_cycle(pe.index)
			continue
		for j in jobs:
			var id: String = j[0]
			var todo: Array = j[1]
			if tila.is_paid(pe.index, id) or PREREQ.has(id) and not tila.is_paid(pe.index, PREREQ[id]):
				continue
			var done := false
			match id:
				"latoon":
					var out := 0
					for b in tila.bales:
						if int(b.field) == pe.index and not b.lato:
							out += 1
					done = int(bk.get("baled", 0)) > 0 and out == 0
				"kuivuri":
					done = float(bk.get("harvested", 0.0)) > 0.0 and puimuri.tank <= 0.0 and tila.trailer <= 0.0
				"kivet":
					var mine := tila.stones.filter(func(st: Dictionary) -> bool: return int(st.field) == pe.index and st.where != "kasa")
					done = mine.is_empty() and _carry < 0
				_:
					# _progress ensin: se kirjaa työn lähtömäärän (max_*) myös ennen kuin työ on aloitettu.
					done = _progress(pe, id, todo) >= 1.0 - DONE and bk.has(id)
			if done:
				_job_done(pe, id, bk)


func _job_done(pe: Pelto, id: String, bk: Dictionary) -> void:
	tila.set_paid(pe.index, id)
	if id == "paalaus" and tila.baler_hay > Tila.BALE_HAY * 0.2:
		_eject_bale(pe.index)  # viimeinen, vajaa paali kammiosta
	if id == "paalaus":
		tila.baler_hay = 0.0
	var amount := 0.0
	match id:
		"paalaus":
			amount = PAY.paalaus * int(bk.get("baled", 0))
		"latoon", "kuivuri", "kivet":
			amount = 0.0  # paalit maksettiin latoon vietäessä, vilja kiloina suppilolle ja kivet kasaan heitettäessä
		_:
			amount = float(PAY[id]) * pe.area / 10000.0
	_pay(amount, "")
	tila.food_due = true
	var msg := "%s %s!" % [pe.field_name(), JOB_NAMES[id]]
	if amount > 0.0:
		msg += " Isäntä maksoi %s €." % _eur(amount)
	if id == "latoon" or id == "kuivuri" or id == "kylvo":
		var lid: String = site.legends[id]
		tila.legends[lid] = int(tila.legends.get(lid, 0)) + 1
		tila.beer_due += 3
		msg += " Koko ketju tehty: isäntä lupasi saunakaljat ja talkooruoan."
		legend.emit(lid)
		say(["Siinä se! Ei tullu ees sadetta.", "No nyt on talvirehut kunnossa!", "Kyllä sää oot ihan pellon mies."][randi() % 3], 4.0)
	else:
		say(["Hyvä! Sitte seuraavaan.", "Nyt joutuu. Kahvit pirtissä, ku kerkiät.", "Ei hassumpi jälki!"][randi() % 3], 3.0)
	message.emit(msg, 4.5)


func _pay(amount: float, why: String) -> void:
	if amount <= 0.0:
		return
	tila.earned += amount
	paid.emit(amount, why)


static func _eur(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")


## Isännän juttu: ensin esittely, sitten peltojen tilanne ja seuraava työ.
func _talk() -> void:
	if not tila.talked:
		tila.talked = true
		say(site.texts.hello, 7.0)
		message.emit(site.texts.intro % [Settings.cap("mount"), Settings.cap("bell")], 7.0)
		return
	if not (site.naapuri as Dictionary).is_empty() and tila.order_left <= 0 and tila.order_day != day and tila.bales_in_lato() >= 2:
		tila.order_total = mini(4, tila.bales_in_lato())
		tila.order_left = tila.order_total
		tila.order_day = day
		say("Naapurin Raija soitti: tarvitsee %d paalia lehmille. Vie piikillä ladosta, paalipaikka on tien toisella puolella vajan vieressä. Raija maksaa %d € paalilta." % [tila.order_total, roundi(BALE_PRICE)], 7.0)
		return
	var parts: Array[String] = []
	if raining():
		parts.append("sataa, paalaus ja puinti odottaa poutaa (%s), kyntää ja äestää voi" % rain_end_text())
	if tila.order_left > 0:
		parts.append("Raijalle %d paalia" % tila.order_left)
	for p in pellot:
		var pe: Pelto = p
		var job := _next_job(pe)
		if not job.is_empty():
			parts.append("%s: %s" % [pe.field_name(), job.name])
	_talk_i += 1
	var lines := ["Hommia riittää: ", "Tänään vois: ", "Kattoppa: "]
	say(lines[_talk_i % lines.size()] + (", ".join(parts) if not parts.is_empty() else "kaikki tehty, istu ja juo kahvia!"), 6.0)


func _eat() -> void:
	tila.food_day = day
	tila.food_due = false
	food_eaten.emit()
	var txt := "Talkooruoka pirtissä: emäntä nosti pöytään lihakeittoa, ruisleipää ja voita, ja perään kahvit ja pullat."
	if tila.beer_due > 0:
		var n := tila.beer_due
		tila.beer_due = 0
		beers_given.emit(n)
		txt += " Isäntä kantoi saunakaljat (%d) eteisestä: \"Ne on ansaittu.\"" % n
	message.emit(txt, 6.0)
