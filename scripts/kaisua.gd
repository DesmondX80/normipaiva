extends Node3D
## Kaisuan tila (Kaisuantie 38, Neittävä, noin 230 m mökiltä länteen): maatilan hommat Farming Simulatorin
## tapaan. Mökin lapsi (mokki.gd ensure_built) mökin paikallisessa kehyksessä origossa; pysyvä tila on main.gd:n
## kaisua_tila.gd-oliossa (Kaisua.tila).
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

static var tila: Tila  # main.gd asettaa ennen mökin rakentamista

signal message(text: String, secs: float)
signal paid(amount: float, why: String)
signal legend(id: String)
signal food_eaten
signal beers_given(n: int)
signal mount(vehicle: Node3D)
signal dismount(vehicle: Node3D, pos: Vector3)

# --- Piha (mökin paikallinen kehys; yaw = rotation.y, -Z eteen) ----------------------------------------------------
const YARD := Vector3(-213.0, 0, 121.0)
const HOUSE_DOOR := Vector3(-207.5, 0, 110.2)  # pirtin ovi pihan puolella (OSM-talo 1074444651)
const KONEVAJA := [Vector3(-192.5, 0, 126.0), PI / 2.0]  # avoin sivu länteen
const LATO := [Vector3(-214.0, 0, 141.8), 0.0]  # ovet pohjoiseen pihalle
const KUIVURI := [Vector3(-237.0, 0, 125.0), 0.0]  # suppilo itään pihalle
const SIGN_POS := Vector3(-233.5, 0, 98.5)
const ISANTA := [Vector3(-207.0, 0, 117.5), PI / 2.0]
## Koneiden kotipaikat [paikka, yaw]: työkoneet konevajan suulla kytkentä länteen, ajoneuvot pihalla.
const HOME := {
	"traktori": [Vector3(-207.0, 0, 125.0), PI / 2.0],
	"puimuri": [Vector3(-226.0, 0, 108.0), PI * 0.15],
	"niittokone": [Vector3(-197.5, 0, 131.8), PI / 2.0],
	"karhotin": [Vector3(-197.5, 0, 125.5), PI / 2.0],
	"aes": [Vector3(-197.5, 0, 120.0), PI / 2.0],
	"kylvokone": [Vector3(-203.5, 0, 136.5), PI / 2.0],
	"paalain": [Vector3(-226.0, 0, 134.0), PI / 2.0],
	"perakarry": [Vector3(-229.0, 0, 116.5), PI / 2.0],
}
const ISANTA_LOOK := {
	"shirt": Color(0.22, 0.32, 0.24), "flannel": true, "pants": Color(0.2, 0.24, 0.32), "workwear": true,
	"suspenders": true, "shoes": Color(0.1, 0.1, 0.09), "shoe": "kumisaapas", "hair": "Hair_Buzzed",
	"hair_color": Color(0.62, 0.6, 0.56), "beard": true, "height": 1.8, "skin": Color(0.95, 0.78, 0.68),
	"belly": 0.7, "bulk": 0.3, "shoulders": 0.25,
}

## Palkat (€): hehtaarilta tai paalilta, vilja kilolta.
const PAY := {"niitto": 30.0, "karhous": 18.0, "paalaus": 2.5, "latoon": 2.0, "puinti": 55.0, "kuivuri": 0.012,
	"aestys": 28.0, "kylvo": 28.0}
const JOB_NAMES := {"niitto": "niitetty", "karhous": "karhottu", "paalaus": "paalattu", "latoon": "paalit ladossa",
	"puinti": "puitu", "kuivuri": "vilja kuivurissa", "aestys": "äestetty", "kylvo": "kylvetty"}
## Työ ja tilat, jotka sen jälkeen ovat tekemättä (osuus <= DONE = valmis, >= READY = työ on taas edessä).
const JOBS := {
	"heina": [["niitto", [1, 2, 3]], ["karhous", [4]], ["paalaus", [5]], ["latoon", []]],
	"vilja": [["puinti", [15]], ["kuivuri", []], ["aestys", [10, 16, 17]], ["kylvo", [11]]],
}
## Työn esiehto: edellinen työ maksettu (vilja: puinti -> kuivuri ja äestys -> kylvö ovat erilliset parit).
const PREREQ := {"karhous": "niitto", "paalaus": "karhous", "latoon": "paalaus", "kuivuri": "puinti", "kylvo": "aestys"}
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


func _ready() -> void:
	set_meta("ground", true)  # mokki.gd ensure_built ei siirrä (kaikki on jo maassa)


## Rakentaa tilan (mokki.gd ensure_built). Pysyvä tila Kaisua.tila:sta; ilman sitä tyhjä tila (testit).
func build() -> void:
	if built:
		return
	built = true
	var t0 := Time.get_ticks_msec()
	if tila == null:
		tila = Tila.new()
	for i in Tila.FIELDS.size():
		var p := Pelto.new()
		add_child(p)
		if p.setup(tila, i):
			pellot.append(p)
		else:
			p.queue_free()
	_build_yard()
	_build_machines()
	_build_bales()
	_build_isanta()
	build_ms = Time.get_ticks_msec() - t0


func _gy(x: float, z: float) -> float:
	return Mokki.mesh_h(x, z)


func _place(n: Node3D, pos: Vector3, yaw: float) -> void:
	n.position = Vector3(pos.x, _gy(pos.x, pos.z) + pos.y, pos.z)
	n.rotation.y = yaw


func _build_yard() -> void:
	_build_gravel()
	_lato = Koneet.lato(self)
	_place(_lato.root, LATO[0], LATO[1])
	_konevaja = Koneet.konevaja(self)
	_place(_konevaja.root, KONEVAJA[0], KONEVAJA[1])
	_kuivuri = Koneet.kuivuri(self)
	_place(_kuivuri.root, KUIVURI[0], KUIVURI[1])
	# Kyltti tienvarressa: kaksi tolppaa ja lautakyltti.
	var sign_root := Node3D.new()
	add_child(sign_root)
	_place(sign_root, SIGN_POS, PI * 0.1)
	for sx in [-0.7, 0.7]:
		B.mesh(sign_root, B.boxm(Vector3(0.1, 1.9, 0.1)), Vector3(sx, 0.95, 0), Color(0.4, 0.3, 0.2))
	var plate := B.sign_plate(sign_root, "KAISUA", Color(0.16, 0.3, 0.18), Color(0.96, 0.94, 0.86), 0.36, 72, Color(0.9, 0.86, 0.75))
	plate.position = Vector3(0, 1.55, 0)
	var sub := B.sign_plate(sign_root, "Kaisuantie 38", Color(0.95, 0.94, 0.9), Color(0.1, 0.1, 0.1), 0.16, 34, Color(0.3, 0.3, 0.3))
	sub.position = Vector3(0, 1.12, 0)
	# Postilaatikko tolpassa kyltin vieressä.
	B.mesh(sign_root, B.boxm(Vector3(0.08, 1.15, 0.08)), Vector3(1.4, 0.57, 0.1), Color(0.4, 0.3, 0.2))
	B.mesh(sign_root, B.boxm(Vector3(0.3, 0.26, 0.45)), Vector3(1.4, 1.25, 0.1), Color(0.85, 0.72, 0.15))


## Pihan sora (mokki.gd KAISUA_YARD): 2 m ruudukko maastoverkon pinnassa, reuna rikkonainen (varjostin karsii
## ympyröiden ulkopuolen kohinan mukaan), joten sora vaihtuu nurmeen luonnollisesti.
func _build_gravel() -> void:
	var lo := Vector2(INF, INF)
	var hi := -lo
	var circles := PackedVector3Array()
	for y in Mokki.KAISUA_YARD:
		var c: Vector2 = y[0]
		var r: float = y[1]
		lo = lo.min(c - Vector2.ONE * (r + 6.0))
		hi = hi.max(c + Vector2.ONE * (r + 6.0))
		circles.append(Vector3(c.x, c.y, r))
	lo = (lo / 2.0).floor() * 2.0
	var nx := int((hi.x - lo.x) / 2.0) + 1
	var nz := int((hi.y - lo.y) / 2.0) + 1
	var hs := PackedFloat32Array()
	hs.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			hs[j * (nx + 1) + i] = Mokki.mesh_h(lo.x + i * 2.0, lo.y + j * 2.0) + 0.03
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for j in nz:
		for i in nx:
			var cc := lo + Vector2(i + 0.5, j + 0.5) * 2.0
			var inside := false
			for c in circles:
				if cc.distance_to(Vector2(c.x, c.y)) < c.z + 5.0:  # varjostimen reuna enintään +3 m
					inside = true
			if not inside:
				continue
			var v := func(di: int, dj: int) -> Vector3:
				return Vector3(lo.x + (i + di) * 2.0, hs[(j + dj) * (nx + 1) + i + di], lo.y + (j + dj) * 2.0)
			for corner in [v.call(0, 0), v.call(1, 0), v.call(1, 1), v.call(0, 0), v.call(1, 1), v.call(0, 1)]:
				st.add_vertex(corner)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/kaisua_piha.gdshader")
	var cv: Array[Vector3] = []
	for c in circles:
		cv.append(c)
	var count := cv.size()
	while cv.size() < 4:
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


func _restore(n: Node3D, id: String) -> void:
	var m: Dictionary = tila.machines.get(id, {})
	if m.is_empty():
		_place(n, HOME[id][0], HOME[id][1])
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
	isanta = Looks.make(self, ISANTA_LOOK)
	_place(isanta, ISANTA[0], ISANTA[1])
	isanta.play("Idle", 0.0)
	_bubble = B.bubble(self, isanta.position + Vector3(0, 2.05, 0), Color.WHITE)
	B.guide(self, "Kaisuan isäntä", isanta.position + Vector3(0, 2.25, 0), 34, Color(1, 0.9, 0.6), true)


func say(text: String, secs := 3.5) -> void:
	if _bubble != null:
		_bubble.text = text
		_bubble_t = secs


func _process(delta: float) -> void:
	if not built:
		return
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.text = ""
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


# --- Työt pellolla -------------------------------------------------------------------------------------------------

## Koneen työ (kaisua_ajoneuvo.gd work_fn): pelloille, joiden alueella työalue on; heinä paalaimeen, vilja säiliöön,
## siemen säiliöstä.
func _apply_work(op: String, c: Vector2, f: Vector2, hw: float, hl: float) -> Dictionary:
	var tot := {"cells": 0, "hay": 0.0, "grain": 0.0, "seed": 0.0}
	if op == "puinti" and puimuri.tank >= Ajoneuvo.TANK_MAX:
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
	if tila.food_due and tila.food_day != day and near.call(HOUSE_DOOR, 2.0):
		if e:
			_eat()
		return "%s Talkooruoalle pirttiin" % Settings.cap("interact")
	for v in [traktori, puimuri]:
		var veh: Node3D = v
		var seat := veh.to_global(Vector3(-1.3, 0, 0.3 if veh == traktori else -0.8))
		if Vector2(walker.global_position.x - seat.x, walker.global_position.z - seat.z).length() < 2.0:
			if f or e:
				_mount(veh)
			return "%s %s" % [Settings.cap("mount"), "Traktorin rattiin" if veh == traktori else "Puimurin ohjaamoon"]
	return ""


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
	var st: Array[String] = ["Traktori %d km/h" % roundi(absf(t.speed) * 3.6)]
	var action := ""
	# Paalipiikki: paali ladoon tai maahan, vapaa paali piikkiin.
	var sp := t.spear_point()
	if t.bale != null:
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
		if bi >= 0:
			action = "%s Paali piikkiin" % Settings.cap("interact")
			if e:
				t.take_bale(bale_nodes[bi])
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
			istat += " (%d kg)" % roundi(tila.trailer)
			if action == "" and tila.trailer > 0.0 and not _tip_on and _trailer_at_pit():
				action = "%s Kippaa vilja kuivurin suppiloon" % Settings.cap("interact")
				if e:
					_tip_on = true
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
	var st: Array[String] = ["Puimuri %d km/h  ·  säiliö %d / %d kg" % [roundi(absf(c.speed) * 3.6), roundi(c.tank), roundi(Ajoneuvo.TANK_MAX)]]
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
		"kuivuri": "vilja kuivuriin", "aestys": "äestys", "kylvo": "kylvö"}[id]


func _bale_near(p: Vector3, r: float) -> int:
	var best := -1
	var bd := r
	for i in bale_nodes.size():
		var n: Node3D = bale_nodes[i]
		if not is_instance_valid(n) or n.get_parent() != self or tila.bales[i].lato:
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
				_:
					done = bk.has(id) and _progress(pe, id, todo) >= 1.0 - DONE
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
		"latoon", "kuivuri":
			amount = 0.0  # paalit maksettiin latoon vietäessä ja vilja kiloina suppilolle
		_:
			amount = float(PAY[id]) * pe.area / 10000.0
	_pay(amount, "")
	tila.food_due = true
	var msg := "%s %s!" % [pe.field_name(), JOB_NAMES[id]]
	if amount > 0.0:
		msg += " Isäntä maksoi %s €." % _eur(amount)
	if id == "latoon" or id == "kuivuri" or id == "kylvo":
		var lid: String = {"latoon": "kaisuan_heinatalkoot", "kuivuri": "kaisuan_sato", "kylvo": "kaisuan_kylvot"}[id]
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
		say("No terve! Santun mökiltä? Traktori on konevajan edessä ja koneet vajassa. Kotipelto on niittokunnossa ja Tienvarsipelto puintikypsä. Maksan joka hommasta, ja emäntä laittaa talkooruoat.", 7.0)
		message.emit("Kaisuan hommat: traktorilla (%s) niittokone, karhotin, paalain, äes, kylvökone ja viljakärry konevajan suulta (%s kytkee peruuttamalla). Puimuri on talon vieressä." % [Settings.cap("mount"), Settings.cap("bell")], 7.0)
		return
	var parts: Array[String] = []
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
