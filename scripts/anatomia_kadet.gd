extends RefCounted
## Anatomia, moduuli "kadet" (rekisteri: anatomia.gd): hoikemmat sormet, peukalon tyvilihas, rystyset, kynnet ja rento lepoasento.
## deform(ctx): pisteiden siirto lepoasennossa + käsimaski COLOR.r:n murto-osaan (_code_r; kynsi ja jänteet maalataan varjostimessa). attach(ctx): ei lisäverkkoja (ks. alla). pose(ch): sormien lepoasento.
## Lepoasento (Quaternius): käsi ojennettuna sivulle, kämmen alas (-Y), kämmenselkä +Y, peukalo eteen (+Z), sormet -X (oikea)
## tai +X (vasen). Kaikki lasketaan luiden paikoista (joints), joten vasen ja oikea ovat peilikuvia samalla koodilla.

const FINGERS := ["thumb", "index", "middle", "ring", "pinky"]
## Sormen säde kohti luujanaa (mitattu: keskisormen tyven pinnan mediaani 13,5 mm = sormi 27 mm leveä, oikea n. 19 mm).
const THIN := {"thumb": 0.86, "index": 0.78, "middle": 0.77, "ring": 0.78, "pinky": 0.80}
## Rentoutus: osuus, jolla animaation sormikierto vedetään kohti lepoasentoa (suora sormi). Pikkusormi koukistuu eniten.
const RELAX := {"thumb": 0.3, "index": 0.6, "middle": 0.55, "ring": 0.5, "pinky": 0.45}
## Animaatiot, joissa käsi roikkuu tai lepää (ei otteita, iskuja, ohjaamista).
const RELAX_ANIMS := ["Idle", "Walk", "Sitting_Idle", "Sitting_Talking", "Idle_Talking", "Crouch_Idle", "Dance"]


## Sormiketju [01, 02, 03, kärki] luiden paikoista ja segmenttien pituudet.
static func chain(joints: Dictionary, f: String, lr: String) -> Array:
	return [joints[f + "_01" + lr], joints[f + "_02" + lr], joints[f + "_03" + lr], joints[f + "_04_leaf" + lr]]


## Lähin piste ketjulla (ensimmäisen segmentin jatke taaksepäin sallittu): [piste, s (m ketjua pitkin nivelestä 01), segmentti].
static func closest(ch: Array, p: Vector3) -> Array:
	var best := INF
	var out := [ch[0], 0.0, 0]
	var acc := 0.0
	for i in 3:
		var a: Vector3 = ch[i]
		var ab: Vector3 = (ch[i + 1] as Vector3) - a
		var l2 := ab.length_squared()
		var t := (p - a).dot(ab) / l2
		t = clampf(t, -10.0 if i == 0 else 0.0, 1.0)
		var q := a + ab * t
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
			out = [q, acc + t * sqrt(l2), i]
		acc += sqrt(l2)
	return out


static func chain_len(ch: Array) -> float:
	var l := 0.0
	for i in 3:
		l += ((ch[i + 1] as Vector3) - (ch[i] as Vector3)).length()
	return l


static func deform(ctx: Dictionary) -> void:
	var joints: Dictionary = ctx.joints
	if not joints.has("hand_r") or not joints.has("index_01_r"):
		return
	var arr: Array = ctx.arr
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var vbone: PackedStringArray = ctx.vbone
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var fmap := {}  # luun nimi -> [ketju, sormi]
	var chains := {}
	for lr in ["_l", "_r"]:
		for f in FINGERS:
			var ch := chain(joints, f, lr)
			chains[f + lr] = ch
			for k in ["_01", "_02", "_03", "_04_leaf"]:
				fmap[f + k + lr] = [ch, f]
	for v in vs.size():
		var bn := vbone[v]
		if fmap.has(bn):
			var m: Array = fmap[bn]
			var ch: Array = m[0]
			var f: String = m[1]
			var p := vs[v]
			var cl := closest(ch, p)
			var s: float = cl[1]
			var total := chain_len(ch)
			var k := 1.0
			if f == "thumb":
				var l1 := ((ch[1] as Vector3) - (ch[0] as Vector3)).length()
				k = lerpf(1.0, THIN[f], smoothstep(l1 * 0.8, l1 * 1.3, s))
			else:
				k = lerpf(1.0, THIN[f], smoothstep(-0.010, 0.012, s)) * (1.0 - 0.07 * clampf(s / total, 0.0, 1.0))
			var c: Vector3 = cl[0]
			vs[v] = c + (p - c) * k
	# Kynnen koordinaatit jokaiselle sormen pisteelle (sormi = 15/15, peukalo 14/15; varjostin maalaa kynnen)
	for lr in ["_l", "_r"]:
		for f in FINGERS:
			_nail_coords(f, lr, chains[f + lr], fmap, vs, vbone, cols)
	# Kämmen: rystyset kämmenselällä ja peukalon tyvilihas kämmenen puolella (verkon normaalin suuntaan).
	for lr in ["_l", "_r"]:
		var hp: Vector3 = joints["hand" + lr]
		var fdir: Vector3 = ((joints["middle_01" + lr] as Vector3) - hp)
		var mcp := fdir.length()
		fdir /= mcp
		var th: Vector3 = joints["thumb_01" + lr]
		var th2: Vector3 = joints["thumb_02" + lr]
		var thc := th.lerp(th2, 0.3)
		var fz := [(joints["index_01" + lr] as Vector3).z, (joints["middle_01" + lr] as Vector3).z,
			(joints["ring_01" + lr] as Vector3).z, (joints["pinky_01" + lr] as Vector3).z]  # sormien tyvien z: jänteet niiden kohdalla
		for v in vs.size():
			var bn := vbone[v]
			if bn != "hand" + lr and bn != "thumb_01" + lr:
				continue
			var p := vs[v]
			var n := ns[v]
			var along := (p - hp).dot(fdir) / mcp
			# Jänteiden maski kaikille kämmenen pisteille (ei vain selkäpuolelle), jotta koodi ja sijainti interpoloituvat sileästi;
			# selkäpuolen rajaus tehdään varjostimessa normaalista. Voimakkuus kasvaa ranteesta rystysiin.
			var c := cols[v]
			c.r = _code_r(c.r, 1 + roundi(4.0 * clampf(along, 0.0, 1.0)))
			c.g = clampf(_tendon_u(p.z, fz) / 4.0, 0.0, 1.0)  # COLOR.g (stripe) ei käytetä iholuokassa: jänteen sijainti / 4
			cols[v] = c
			if n.y > 0.25 and bn == "hand" + lr:
				# kämmenselkä: rystyset (tyviniveleiden kohta)
				var bump := 1.0 - smoothstep(0.0, 0.22, absf(along - 0.97))
				vs[v] = p + n * 0.0013 * bump * n.y
			elif n.y < -0.3:
				var d := p.distance_to(thc)
				var w := 1.0 - smoothstep(0.012, 0.040, d)
				vs[v] = p + n * 0.0035 * w * w
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_COLOR] = cols


## z-koordinaatti -> sormen järjestysluku (0 etusormi .. 3 pikkusormi), paloittain lineaarisesti sormien tyvien välillä.
static func _tendon_u(z: float, fz: Array) -> float:
	for i in 3:
		var a: float = fz[i]
		var b: float = fz[i + 1]
		if (z - a) * (z - b) <= 0.0 or i == 2:
			return float(i) + (z - a) / (b - a)
	return 0.0


## Kynnet maalataan varjostimessa (anat_kadet.gdshaderinc), ei lisäverkkona: sormen pinta on karkea monikulmio (n. 8 pistettä
## kehällä), joten säteillä pintaan sovitettu kynsiverkko hyppi sen särmissä (kolme yritystä: pinnan yli, pehmennetty, maksimisuodatettu;
## kuvat scratchpadissa) ja jäi irti sormen kärjestä. deform antaa jokaiselle sormen pisteelle kynnen paikalliset koordinaatit
## (COLOR.g = paikka kynnellä, COLOR.b = sivusuuntainen paikka), jotka interpoloituvat lineaarisesti kolmion yli, joten reuna on
## sileä pinnan karkeudesta riippumatta (kuten sandaalin varpaankynnet). Ei lisäverkkoa = ei Anatomia-solmua kontaktimittaan.
## Käsimaski COLOR.r:ään (CUSTOM1.a ei saavuta varjostinta Compatibility-renderöijässä: lukuarvo oli aina 1,0): COLOR.r = (luokka + 0,04 koodi) / 4.
## Varjostin purkaa luokan floor(cat + 0,5):llä ja koodin murto-osasta, joten vaateluokka ei muutu (koodi <= 9 -> osuus <= 0,36).
## Koodi 1..5 = kämmenselkä (jänteen voimakkuus), 8 = sormi (kynsi maalataan), 9 = peukalo.
static func _code_r(r: float, code: int) -> float:
	return (roundf(r * 4.0) + 0.04 * float(code)) / 4.0


## Kynnen paikallinen koordinaatistossa: akseli = kärkiluun suunta, u = kämmenselkä (sormet +Y; peukalo vinosti eteen ylös,
## kynsi osoittaa poispäin kämmenestä), w = sivu. tau 0 tyvi .. 1 vapaa reuna, q -1..1 sivusuunnassa. COLOR.g = 0,5 + 0,2 (tau - 0,5),
## COLOR.b = 0,5 + 0,2 q (8-bittinen väri: alue tau -2..3, q -2,5..2,5). Pituus 0,6 x kärkiluun todellinen pituus (verkon kärki ei ole
## leaf-pisteessä: keskisormella 10 mm sen edessä), enintään 15 mm; leveys 0,66 x sormen puolileveys.
static func _nail_coords(f: String, lr: String, ch: Array, fmap: Dictionary, vs: PackedVector3Array, vbone: PackedStringArray,
		cols: PackedColorArray) -> void:
	var a: Vector3 = ch[2]
	var b: Vector3 = ch[3]
	var ax := (b - a).normalized()
	var up := Vector3(0.0, 0.55, 0.85) if f == "thumb" else Vector3.UP
	var u := (up - ax * up.dot(ax)).normalized()
	var w := u.cross(ax).normalized()
	var mine := PackedInt32Array()
	var tip := 0.0
	for v in vs.size():
		if fmap.has(vbone[v]) and (fmap[vbone[v]] as Array)[1] == f and (fmap[vbone[v]] as Array)[0] == ch:
			mine.append(v)
			if vbone[v] == f + "_03" + lr or vbone[v] == f + "_04_leaf" + lr:
				tip = maxf(tip, (vs[v] - a).dot(ax))
	var hw_f := 0.0
	for v in mine:
		var d := vs[v] - a
		var al := d.dot(ax)
		if (vbone[v] == f + "_03" + lr or vbone[v] == f + "_04_leaf" + lr) and al > 0.1 * tip and al < 0.9 * tip:
			hw_f = maxf(hw_f, absf((d - ax * al).dot(w)))
	if tip <= 0.0 or hw_f <= 0.0:
		return
	var hw := 0.66 * hw_f
	var length := minf(0.6 * tip, 0.015)
	var t1 := tip - 0.0015
	var t0 := t1 - length
	var code := 9 if f == "thumb" else 8
	for v in mine:
		var d := vs[v] - a
		var tau := (d.dot(ax) - t0) / length
		var q := d.dot(w) / hw
		var c := cols[v]
		c.g = clampf(0.5 + 0.2 * (tau - 0.5), 0.0, 1.0)
		c.b = clampf(0.5 + 0.2 * q, 0.0, 1.0)
		c.r = _code_r(c.r, code)
		cols[v] = c


static func attach(_ctx: Dictionary) -> Array:
	return []


## Sormien lepoasento: animaation sormikierto vedetään kohti lepoasentoa (suorat sormet), joten Idle-nyrkki muuttuu löyhästi
## koukussa oleviksi sormiksi. Sama kaava molemmille käsille (paikallinen kierto kohti lepoa, peilikuvasta turvallinen).
static func pose(ch: Node3D) -> void:
	var cur: String = ch.current()
	var ok := false
	for a in RELAX_ANIMS:
		if cur.begins_with(a):
			ok = true
			break
	if not ok:
		return
	var skel: Skeleton3D = ch.skeleton
	for lr in ["_l", "_r"]:
		if ch._ik.has("arm" + lr):
			continue  # käsi kontaktissa (PariOte.hand_to, ote): sormet jäävät animaation koukkuun, kapselit mitattu niillä
		for f in FINGERS:
			var w: float = RELAX[f]
			for k in ["01", "02", "03"]:
				var i := skel.find_bone("%s_%s%s" % [f, k, lr])
				if i < 0:
					continue
				var rest := skel.get_bone_rest(i).basis.get_rotation_quaternion()
				skel.set_bone_pose_rotation(i, skel.get_bone_pose_rotation(i).slerp(rest, w))
