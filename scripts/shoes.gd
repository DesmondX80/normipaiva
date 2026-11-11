extends RefCounted
## Kengät: oma skinnattu verkko, joka taipuu samoilla luilla kuin jalkaterä (painot lähimmistä vartaloverkon kärjistä).
## Kuori rakennetaan jalkaterän lepoverkon poikkileikkauksista (kantapäästä varpaisiin), joten jokainen malli ja vartalo
## saa sopivan kengän ilman käsin piirrettyä mallia. Vartalon jalkaterä (vaateluokka 3) painuu varjostimessa kengän sisään
## (character.gdshader shoe_on / shoe_cut), ja Pose.limb_points lukee kengän pinnan kuten muunkin vartalon.
## Mesh-avaruudessa +Z = etupuoli (varpaat), +Y = ylös; hahmon avaruudessa etu on -Z (model.rotation.y = PI).
## Käyttö: Character._attach_shoes. type_for(look) on puhdas funktio.

const SHADER := "res://shaders/shoe.gdshader"
const SLICES := 16  # poikkileikkauksia kannasta varpaisiin
const RING := 24  # pisteitä poikkileikkauksen ympäri
const DOME := 3  # pyöristysrenkaita kannassa
const TOE_RINGS := 8  # kärjen kapenevat renkaat (tiheämmin kärkeä kohti)
const TOE_N := 2.5  # kärjen superellipsin eksponentti oletuksena (2 = ellipsi, suurempi = leveämpi kärki; TYPES toe_n)
const TOE_LOW := 0.22  # kärkipisteen korkeus kuoren alimmasta kohdasta oletuksena (osuus kärkiosan korkeudesta; toe_low)
const SE_N := 3.0  # poikkileikkauksen superellipsin eksponentti (2 = ellipsi, suurempi = laatikkomaisempi)
const B_LOW := 0.006  # poikkileikkauksen alapuoliskon korkeus (kuori kaartuu pohjaan)
const HU_PAD := 1.04  # yläpuoliskon väljyys korkeimman kärjen yli
const PAD := 0.0  # lisärako tarpeeseen (tasoituksen kutistuman kattaa rako; hahmot_kontakti MALLI jalka p90 <= 12 mm)
const TOE_BLEND := 0.015  # kärkiosan painot: päkiästä +-15 mm sekoitus, edessä vain päkiän luu
const SHAFT_RINGS := 8  # varren vaakarenkaat alhaalta yläreunaan
const SHAFT_N := 2.6  # varren poikkileikkauksen superellipsin eksponentti

static var _nails := PackedFloat32Array()  # sandaali: varpaankynnet (x, y, z lepoavaruudessa, säde) * 10 (meta "kynnet")
static var _shaft_h := 0.0  # viimeksi rakennetun varren yläreuna kuoren alapinnasta (meta "varsi_h", varjostimen shaft_h)
static var _tip_h := 0.0  # viimeksi rakennetun kengän kärkipisteen korkeus lattiasta (meta "karki", testin profiili)

## Tyyppien parametrit (metrejä mallin mittakaavassa): lift = koko nosto (pohjan alapinta jalkapohjan alimman kärjen alla,
## sama kaikilla tyypeillä, ettei hahmon pituus muutu), sole = näkyvä pohjalaatta (kuoren alapinta lift - sole jalkapohjan
## alla), rand = pohjan reunus kuoren kylkeä ylös, waist = korko (pohjan alapinta nousee kannan ja päkiän välissä),
## top = matalan kengän suu jalkapohjan yläpuolella (enintään), margin = kuoren rako ihoon, flare = pohjan
## reunan ulottuma kuoren ohi, toe_room = kärjen tila varpaiden edessä, toe_round = kärjen pyöristyksen pituus
## (osuus kärjen puolileveydestä), toe_n = kärjen superellipsin eksponentti, toe_low = kärkipisteen korkeus (osuus),
## toe_h = kärkikuvun korkeuskerroin, collar = kengän suu lahkeen alimman kärjen alla, spring = kärjen nousu (pohjan
## alapinta kärjessä), sole_col = pohjan väri, rough = päällisen karheus, sole_rough = pohjan karheus, style = varjostimen
## tyyli (0 lenkkari, 1 varattu nauhakengälle (myöhempi issue), 2 kävelykenkä), spec = päällisen SPECULAR,
## clearcoat = lakkakiilto (0 = ei), shaft = varsi {join = jalkaosan suu, top = varren yläreuna (jalkapohjasta),
## pad = varren paksuus ihon ja raon päälle}.
## "paljas" = ei kenkää (vartalon jalkaterä värjätään kuten ennenkin).
const TYPES := {
	"lenkkari": {"lift": 0.023, "sole": 0.020, "rand": 0.0015, "margin": 0.003, "flare": 0.004, "toe_room": 0.015, "toe_round": 1.3,
		"collar": 0.012, "spring": 0.005, "sole_col": Color(0.95, 0.94, 0.9), "rough": 0.62, "sole_rough": 0.8, "style": 0,
		"spec": 0.4, "clearcoat": 0.0},
	"kavelykenka": {"lift": 0.023, "sole": 0.016, "rand": 0.006, "top": 0.07, "margin": 0.004, "flare": 0.004, "toe_room": 0.015,
		"toe_round": 1.0, "toe_n": 3.0, "collar": 0.012, "spring": 0.005, "sole_col": Color(0.72, 0.66, 0.56), "rough": 0.78,
		"sole_rough": 0.85, "style": 2, "spec": 0.3, "clearcoat": 0.0},
	"tyokenka": {"lift": 0.023, "sole": 0.020, "rand": 0.010, "margin": 0.004, "flare": 0.005, "toe_room": 0.016,
		"toe_round": 1.2, "toe_n": 3.0, "toe_h": 1.18, "toe_low": 0.32, "collar": 0.012, "spring": 0.006,
		"sole_col": Color(0.13, 0.12, 0.11), "rough": 0.72, "sole_rough": 0.9, "style": 3, "spec": 0.35, "clearcoat": 0.0,
		# Varsi (#279): kumisaappaan kaksiosainen jäykkä rakenne (vanha suun ääriviivasta noussut varsi jätti portaan
		# jalkaosan päälle). Matala nilkkavarsi säären luulla, alareuna jalkaosan suun sisällä.
		"shaft": {"join": 0.09, "top": 0.155, "pad": 0.017, "rigid": true, "lap": 0.045, "gap": 0.012, "flare": 0.004}},
	# Kumisaapas (#273): kaksi jäykkää osaa. Alaosa = matala kuori (suu tasan join), varsi = leveä kartioputki säären
	# luulla (rigid: painot 100 % sääreen), alareuna limittäin alaosan suun sisällä (lap = putken alareuna join:n alla).
	# flare = putken lisäväljyys yläreunassa (kartio), pad alareunassa, top_k = yläreuna osuutena nilkasta polveen (top ohitetaan).
	"kumisaapas": {"lift": 0.023, "sole": 0.020, "rand": 0.012, "margin": 0.004, "flare": 0.005, "toe_room": 0.016,
		"toe_round": 1.1, "toe_n": 2.8, "toe_h": 1.1, "toe_low": 0.3, "collar": 0.012, "spring": 0.006,
		"sole_col": Color(0.93, 0.9, 0.82), "rough": 0.3, "sole_rough": 0.85, "style": 4, "spec": 0.5, "clearcoat": 0.6,
		"shaft": {"join": 0.09, "top": 0.237, "top_k": 0.55, "pad": 0.014, "rigid": true, "lap": 0.045, "gap": 0.012,
			"flare": 0.022}},
	# Nauhakenkä (#279): oma lestimuoto, ei lenkkarin kuori: kenkä on 4,5 cm jalkaa pidempi (toe_room) ja kärki kapenee
	# vasta varpaiden edessä (toe_round 1,05: kavennus ei osu varpaisiin, joten kärkeä ei levennetä takaisin; toe_n < 2 = suippo),
	# matala kärkipiste, ohut nahkapohja ja korko (waist), matala suu, kiiltävä nahka (varjostin style 1: nauhat ja saumat).
	"nauhakenka": {"lift": 0.023, "sole": 0.012, "rand": 0.004, "top": 0.062, "margin": 0.003, "flare": 0.003, "toe_room": 0.045,
		"toe_round": 1.05, "toe_n": 1.9, "toe_low": 0.16, "collar": 0.012, "spring": 0.006, "waist": 0.008,
		"sole_col": Color(0.2, 0.13, 0.08), "rough": 0.3, "sole_rough": 0.7, "style": 1, "spec": 0.5, "clearcoat": 0.5},
	# Kuukenkä (#279, esikuva Moon Boot): pullea toppavarsi puoleen sääreen, iso paksu pohja joka nousee kyljille (rand),
	# leveä pyöreä kärki, nyöritys edessä ja kiristysnyöri stopparilla varren yläreunassa (varjostin style 7, cord_col).
	"kuukenka": {"lift": 0.023, "sole": 0.022, "rand": 0.022, "margin": 0.012, "flare": 0.008, "toe_room": 0.02,
		"toe_round": 1.0, "toe_n": 3.2, "toe_h": 1.15, "toe_low": 0.4, "collar": 0.012, "spring": 0.004,
		"sole_col": Color(0.74, 0.75, 0.8), "rough": 0.5, "sole_rough": 0.8, "style": 7, "spec": 0.4, "clearcoat": 0.0,
		"cord_col": Color(0.1, 0.72, 0.85),  # neonturkoosi nyöri (valkoinen ei erotu valkoisesta kengästä)
		"shaft": {"join": 0.1, "top": 0.26, "top_k": 0.62, "pad": 0.03, "rigid": true, "lap": 0.05, "gap": 0.014,
			"flare": 0.004}},
	# Pitkävartinen nahkasaapas (#273): kumisaappaan rakenne (kaksi jäykkää osaa), varsi lähelle polvea (top_k), istuvampi
	# (pad ja flare pienemmät), ohut tumma pohja ja pieni korko (waist), mattapintainen nahka.
	"saapas": {"lift": 0.023, "sole": 0.013, "rand": 0.004, "margin": 0.004, "flare": 0.003, "toe_room": 0.018,
		"toe_round": 1.25, "toe_n": 2.4, "toe_low": 0.26, "collar": 0.012, "spring": 0.005, "waist": 0.009,
		"sole_col": Color(0.09, 0.08, 0.075), "rough": 0.42, "sole_rough": 0.8, "style": 5, "spec": 0.45, "clearcoat": 0.12,
		"shaft": {"join": 0.09, "top": 0.4, "top_k": 0.84, "pad": 0.017, "rigid": true, "lap": 0.045, "gap": 0.012,
			"flare": 0.004}},  # pad ja gap kuten kumisaappaassa (alaosan suu jää varren sisään), kartio pienempi
	# Sandaali (#273, Sinikka): ei kuorta. Tasainen pohjalaatta (matala 2,3 cm korotus ilman jalkaterän kallistusta) ja
	# hihnat ihon pinnassa: varvashihna päkiän yli, nilkkahihna nilkan ympäri ja kantahihna kannan takaa. Jalka näkyy
	# ihona (character.gdshader foot_skin), varpaankynnet lakataan varjostimessa (nail_col).
	# sandal: toe = varvashihnan paikka päkiästä taakse (m), w = hihnan leveys, ankle = nilkkahihnan korkeus jalkapohjasta,
	# thick = hihnan paksuus.
	"sandaali": {"lift": 0.023, "sole": 0.021, "rand": 0.0, "margin": 0.002, "flare": 0.002, "toe_room": 0.004,
		"toe_round": 1.0, "toe_n": 2.3, "collar": 0.0, "spring": 0.0, "sole_col": Color(0.66, 0.5, 0.33), "rough": 0.45,
		"sole_rough": 0.75, "style": 6, "spec": 0.45, "clearcoat": 0.25,
		"sandal": {"toe": 0.04, "w": 0.022, "ankle": 0.082, "thick": 0.0028}},
	"paljas": {},
}


## Kenkätyyppi ulkonäöstä: look.shoe voittaa, muuten shoes-värin mukaan. Erä 1: vaaleat ja kirkkaanväriset = lenkkari,
## muut "paljas" (vanha värjätty jalkaterä), kunnes muut tyypit on tehty.
static func type_for(look: Dictionary) -> String:
	var t: String = look.get("shoe", "")
	if t != "":
		return t if TYPES.has(t) else "paljas"
	if not look.has("shoes"):
		return "paljas"
	var c: Color = look.shoes
	var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var sat := (maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))) / maxf(maxf(c.r, maxf(c.g, c.b)), 0.001)
	if lum > 0.75 and sat < 0.2:
		return "lenkkari"  # valkoinen tai vaalea (iho- tai beigesävyt, joissa on väriä, jäävät paljaiksi)
	if sat > 0.6 and c.v > 0.3:
		return "lenkkari"  # kirkas väri
	return "paljas"


## Kenkäverkko kummallekin jalalle (yksi pinta, limb_points lukee vain pinnan 0). arr = vaatetetun vartaloverkon pinnan 0
## taulukot (COLOR.r = vaateluokka / 4). meta "pohja" = kengän alin kohta jalkapohjan alimman kärjen alapuolella (m, malli).
static func build(kind: String, type: String, arr: Array, skin: Skin, skel: Skeleton3D, opts := {}) -> ArrayMesh:
	var p: Dictionary = TYPES[type]
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var bw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bi.size() / vs.size()
	var st := SurfaceTool.new()
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS if per <= 4 else SurfaceTool.SKIN_8_WEIGHTS)  # ennen beginiä (muuten "begun"-virhe)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pohja := 0.0
	_nails = PackedFloat32Array()
	var above := PackedInt32Array()  # jalkaterän kärjet kengän suun yläpuolella (lahkeen alla; skin_outside ohittaa)
	var varsi := Vector4.ZERO  # varren yläreuna (lepo-y, UV2), yläreuna ja jalkaosan suu (verkon y), UV2.y - y yläreunassa
	for side: float in [1.0, -1.0]:
		var foot := PackedInt32Array()  # jalkaterän kärjet (luokka 3)
		var cand := PackedInt32Array()  # painojen lähteet: jalkaterä ja säären alaosa
		var pant := PackedInt32Array()  # lahkeen alaosa (luokka 2): kengän suu jää sen alle
		for v in vs.size():
			if signf(vs[v].x) != side:
				continue
			var c := roundi(cs[v].r * 4.0)
			if c == 3:
				foot.append(v)
				cand.append(v)
			elif c == 2 and vs[v].y < 0.25:
				cand.append(v)
				pant.append(v)
		var mouth := PackedVector2Array()  # jalkaosan suun ääriviiva (t, s), varrellisella
		pohja = _build_side(st, p, vs, bi, bw, per, foot, cand, pant, side, skin, skel, above, mouth)
		if p.has("shaft"):
			varsi = _build_shaft(st, p, vs, arr[Mesh.ARRAY_TEX_UV2], cs, bi, bw, per, foot, side, skin, skel, mouth)
	st.index()
	st.generate_normals()
	var out := st.commit()
	out.set_meta("pohja", pohja)
	out.set_meta("suu", above)
	out.set_meta("karki", _tip_h)
	if p.has("sandal"):
		out.set_meta("kynnet", _nails)  # character.gd: varjostimen nails (kynsilakka)
	out.set_meta("varsi", varsi.x)  # 0 = ei vartta; character.gdshader shoe_top (lahje varren sisään)
	out.set_meta("varsi_v", Vector3(varsi.y, varsi.z, varsi.w))  # skin_outside ja testi
	if p.has("shaft") and p.shaft.has("top_k"):
		out.set_meta("varsi_h", _shaft_h)  # character.gd: varjostimen shaft_h (yläreuna lasketaan luista)
	return out


## Yhden jalan kuori ja pohja. Palauttaa pohjan alimman kohdan etäisyyden jalkapohjan alimmasta kärjestä.
static func _build_side(st: SurfaceTool, p: Dictionary, vs: PackedVector3Array, bi: PackedInt32Array, bw: PackedFloat32Array,
		per: int, foot: PackedInt32Array, cand: PackedInt32Array, pant: PackedInt32Array, side: float, skin: Skin,
		skel: Skeleton3D, above: PackedInt32Array, mouth: PackedVector2Array) -> float:
	# Jalan pituusakseli: kannan (foot-luu) ja päkiän (ball-luu) kärkien keskipisteiden erotus vaakatasossa.
	var heel := Vector3.ZERO
	var ball := Vector3.ZERO
	var nh := 0
	var nb := 0
	var ymin := INF
	var ball_bind := -1  # päkiän luu (Skin-sidonnan indeksi): kärkiosan painot
	for v in foot:
		ymin = minf(ymin, vs[v].y)
		if _bone_of(v, bi, bw, per, skin, skel).begins_with("ball"):
			ball += vs[v]
			nb += 1
			ball_bind = _bind_of(v, bi, bw, per)
		else:
			heel += vs[v]
			nh += 1
	heel /= maxf(nh, 1)
	ball /= maxf(nb, 1)
	var fwd := Vector3(ball.x - heel.x, 0.0, ball.z - heel.z).normalized()  # +Z-suuntainen (mesh-avaruuden etu)
	var lat := Vector3.UP.cross(fwd)  # +X-suuntainen
	var org := Vector3(heel.x, 0.0, heel.z)
	var margin: float = p.margin
	var y_bot: float = ymin - float(p.lift)  # pohjan alapinta: nosto sama kaikilla tyypeillä
	var y_welt: float = y_bot + float(p.sole)  # kuoren tasainen alapinta (pohjalaatan yläpinta)
	# Kärjet jalan koordinaateissa: t (pituus), s (sivu), y.
	var pts := PackedVector3Array()
	var tmin := INF
	var tmax := -INF
	for v in foot:
		var d := vs[v] - org
		var q := Vector3(d.dot(fwd), d.dot(lat), vs[v].y)
		pts.append(q)
		tmin = minf(tmin, q.x)
		tmax = maxf(tmax, q.x)
	var step := (tmax - tmin) / float(SLICES)
	var win := step * 0.75 + 0.006
	# Kengän suu: kuoren yläreuna lahkeen alimman kärjen alapuolella (collar) kussakin poikkileikkauksessa, jolloin
	# lahkeen ja jalkaterän välinen vino kaista ei leikkaa kuorta, vaan jalkaterä (lahkeen värinen) nousee suusta.
	var collar: float = p.get("collar", 0.0)
	var pq := PackedVector3Array()
	for v in pant:
		var d := vs[v] - org
		pq.append(Vector3(d.dot(fwd), d.dot(lat), vs[v].y))
	var caps := PackedFloat32Array()  # poikkileikkauksittain
	for i in SLICES:
		var lo := INF
		for q in pq:
			if absf(q.x - (tmin + step * (i + 0.5))) <= win:
				lo = minf(lo, q.z)
		caps.append(lo - collar)
	var cmax := -INF
	for c in caps:
		if c < INF:
			cmax = maxf(cmax, c)
	for i in caps.size():
		caps[i] = -(caps[i] if caps[i] < INF else cmax)  # peilattuna; ei lahjetta ikkunassa = korkein suu
	# Suu tasaisena käyränä lahkeen alapuolella (_envelope peilattuna), ennen kuin kärjet jaetaan suun ylä- ja alapuolelle.
	caps = _envelope(caps)
	var top: float = ymin + float(p.get("top", INF))  # matala kenkä: suu enintään top jalkapohjan yläpuolella
	if p.has("shaft"):
		top = ymin + float(p.shaft.join)  # varrellinen: jalkaosan suu tasan join, varsi peittää lahkeen
	for i in caps.size():
		caps[i] = top if p.has("shaft") else minf(-caps[i], top)
	# Suun yläpuolella oleva kärki: yli matalimman suun niistä poikkileikkauksista, joiden ikkunassa se on (kuori on
	# niiden välissä suora), joten yksikään kuoren sisään jäävä kärki ei jää leikatun yläreunan yläpuolelle.
	var is_above := PackedByteArray()
	for i in pts.size():
		var cmin := INF
		for k in SLICES:
			if absf(pts[i].x - (tmin + step * (k + 0.5))) <= win:
				cmin = minf(cmin, caps[k])
		is_above.append(1 if pts[i].z > cmin - margin else 0)
		if is_above[i] == 1:
			above.append(foot[i])
	# Kuori kaavasta: jalasta mitataan asemittain vain mittakäyrät (keskiviiva sc, puolileveys w, yläpuoliskon puoliakseli
	# hu, suun yläraja cap), jotka tasoitetaan pituuden suunnassa (_envelope), ja jokainen poikkileikkaus on sama superellipsi
	# (_ring_at) eri mitoissa. Mitään ei litistetä lattiaan eikä skaalata renkaittain, joten kehän kulmat ovat joka renkaassa
	# samalla indeksillä (renkaittain leikattu kuori rypisti pohjan yläreunan ja kärjen).
	var tb := (ball - org).dot(fwd)  # päkiä
	var yc := y_welt + B_LOW  # poikkileikkauksen keskikorkeus: alapuolisko B_LOW, alin piste tasan y_welt
	var at := PackedFloat32Array()  # asemat (t)
	var sels := []
	var sc := PackedFloat32Array()
	var cap := PackedFloat32Array()
	var hn := PackedFloat32Array()  # yläpuoliskon tarve
	for i in SLICES:
		var t := tmin + step * (i + 0.5)
		var sel := PackedVector2Array()
		for j in pts.size():
			if absf(pts[j].x - t) <= win and is_above[j] == 0:
				sel.append(Vector2(pts[j].y, pts[j].z))
		if sel.size() < 3:
			continue
		var lo := Vector2(INF, INF)
		var hi := -lo
		for q in sel:
			lo = lo.min(q)
			hi = hi.max(q)
		at.append(t)
		sels.append(sel)
		sc.append((lo.x + hi.x) / 2.0)
		cap.append(caps[i])
		hn.append((hi.y + margin + PAD - yc) * HU_PAD)  # väljyys: superellipsin kulma ei leikkaa ylänurkan kärkiä
	for it in 3:
		sc = _smooth(sc)
	var hu := _envelope(hn)
	var wn := PackedFloat32Array()
	for i in at.size():
		var need := 0.0
		for q: Vector2 in sels[i]:
			var dy := q.y - yc
			var r := clampf(absf(dy) / (hu[i] if dy > 0.0 else B_LOW), 0.0, 0.95)
			need = maxf(need, absf(q.x - sc[i]) / pow(1.0 - pow(r, SE_N), 1.0 / SE_N))
		wn.append(need + margin + PAD)
	var wd := _envelope(wn)
	# Pyöreä kärki: kohdasta ta kärkeen tend (toe_room varpaiden edessä) rengas kutistuu kärkipisteen (tip_s, y_tip)
	# ympäri kertoimella f = superellipsi (_toe_f): ylhäältä puoliellipsi, sivulta kaareva nokka. Kärkipiste on keskiviivan
	# ja isovarpaiden kärjen puolivälissä ja matalalla (TOE_LOW kärjen korkeudesta).
	var tend := tmax + margin + float(p.get("toe_room", 0.0))
	var ta := tend - wd[wd.size() - 1] * float(p.get("toe_round", 1.0))
	var sc_a := _at(at, sc, ta)
	var w_a := _at(at, wd, ta)
	var hu_a := _at(at, hu, ta)
	var cap_a := _at(at, cap, ta)
	var tip_s := 0.0
	var ntip := 0
	for q in pts:
		if q.x >= tmax - 0.004:
			tip_s += q.y
			ntip += 1
	tip_s = lerpf(sc_a, tip_s / maxf(ntip, 1), 0.5)
	var toe_n: float = p.get("toe_n", TOE_N)
	var tipc := Vector2(tip_s, y_welt + (B_LOW + hu_a) * float(p.get("toe_low", TOE_LOW)))
	if side > 0.0:
		_tip_h = tipc.y - y_bot  # testin profiili-rivi (kärkipisteen korkeus lattiasta)
	# Varpaat kärkiosan sisään: kutistettu rengas vastaa ta:n rengasta kärkipisteestä 1/f-kertaisesti, joten kärjen tarve
	# on varpaiden superellipsinormi siellä (raon kanssa). Yli 1 => ta:n renkaan leveys ja korkeus kasvavat.
	var grow := 1.0
	for i in pts.size():
		var q := pts[i]
		if q.x <= ta or is_above[i] == 1:
			continue
		var f := maxf(_toe_f(q.x, ta, tend, toe_n), 0.05)
		var d := tipc + (Vector2(q.y, q.z) - tipc) / f - Vector2(sc_a, yc)
		var ex := (absf(d.x) + margin / f) / w_a
		var ey := (absf(d.y) + margin / f) / (hu_a if d.y > 0.0 else B_LOW)
		if d.y > 0.0:
			grow = maxf(grow, pow(pow(ex, SE_N) + pow(ey, SE_N), 1.0 / SE_N))
		else:
			grow = maxf(grow, ex)
	w_a *= grow
	hu_a *= grow * float(p.get("toe_h", 1.0))  # toe_h: korkeampi kärkikupu (turvakärki)
	var ring_a := _ring_at(sc_a, yc, w_a, hu_a, maxf(cap_a, y_welt))
	var rings := []  # [t, keskipiste Vector2(s, y), PackedVector2Array (s, y), leveyden kerroin pohjalle]
	for i in at.size():
		if at[i] < ta - step * 0.3:
			rings.append([at[i], Vector2(sc[i], yc), _ring_at(sc[i], yc, wd[i], hu[i], maxf(cap[i], y_welt)), 1.0])
	var toe := []
	for j in TOE_RINGS:
		var t := ta + (tend - ta) * sin(PI / 2.0 * j / TOE_RINGS)
		var f := _toe_f(t, ta, tend, toe_n)
		var ring := PackedVector2Array()
		for q: Vector2 in ring_a:
			ring.append(tipc + (q - tipc) * f)
		toe.append([t, tipc + (Vector2(sc_a, yc) - tipc) * f, ring, f])
	var tip1 := tipc
	# Pyöristys kantaan: renkaat kutistuvat keskipisteeseen neljännesympyrän mukaan.
	var full := []
	var e: Array = rings[0]
	var ext: float = float(e[0]) - tmin + margin
	for j in range(DOME, 0, -1):
		var phi := PI / 2.0 * j / (DOME + 1)
		var sk := cos(phi)
		var ring := PackedVector2Array()
		for r: Vector2 in e[2]:
			var q: Vector2 = e[1] + (r - e[1]) * sk
			q.y = lerpf(q.y, r.y, clampf(1.0 - (r.y - y_welt) / 0.01, 0.0, 1.0))  # alapinta pysyy pohjan päällä
			if top < INF:  # matala kenkä: kantakappaleen yläosa pystysuora (kantapää jää sisään), alaosa pyöristyy kuten ennen
				q.y = lerpf(q.y, r.y, clampf((r.y - e[1].y - 0.005) / 0.015, 0.0, 1.0))
			ring.append(q)
		full.append([float(e[0]) - ext * sin(phi), e[1], ring, sk])
	full.append_array(rings)
	full.append_array(toe)
	if p.has("shaft"):  # suun reunan pisteet (leikattu tasolle top): varren alin rengas liittyy niihin
		for r in full:
			for q: Vector2 in r[2]:
				if q.y >= top - 1e-5:
					mouth.append(Vector2(float(r[0]), q.x))
	var t0: float = float(rings[0][0]) - (float(rings[0][0]) - tmin + margin)
	var t1: float = tend
	var tip0: Vector2 = rings[0][1]
	var to3 := func(t: float, q: Vector2) -> Vector3:
		return org + fwd * t + lat * q.x + Vector3.UP * q.y
	var span := t1 - t0
	# Päällinen: renkaat vierekkäin, päät viuhkana.
	var up := []  # [Vector3 paikka, Vector2 (s, y)] renkaittain
	for r in full:
		var row := []
		for q: Vector2 in r[2]:
			row.append(to3.call(r[0], q))
		up.append(row)
	var add := func(a: Vector3, uv: Vector2, uv2: Vector2) -> void:
		st.set_uv(uv)
		st.set_uv2(uv2)
		st.set_color(Color(1, 1, 1, 1))
		# Kärkiosa kokonaan päkiän luulle (jäykkä, ei rypisty), päkiän ympärillä TOE_BLEND-mitan sekoitus.
		var tw := clampf(((a - org).dot(fwd) - tb + TOE_BLEND) / (2.0 * TOE_BLEND), 0.0, 1.0) if ball_bind >= 0 else 0.0
		_set_weights(st, a, vs, bi, bw, per, cand, ball_bind, tw)
		st.add_vertex(a)
	var uv_of := func(a: Vector3, part: float, c: Vector2) -> Array:
		var d := a - org
		var s := d.dot(lat)
		var w := 0.06
		return [Vector2((d.dot(fwd) - t0) / span, a.y - y_welt), Vector2(clampf((s - c.x) / w, -1.0, 1.0) * side, part)]
	var tri := func(a: Vector3, b: Vector3, c: Vector3, out: Vector3, part: float, ca: Vector2, cb: Vector2, cc: Vector2) -> void:
		if (c - a).cross(b - a).dot(out) < 0.0:
			var tmp := b
			b = c
			c = tmp
			var tc := cb
			cb = cc
			cc = tc
		for pr in [[a, ca], [b, cb], [c, cc]]:
			var u: Array = uv_of.call(pr[0], part, pr[1])
			add.call(pr[0], u[0], u[1])
	var sandal: bool = p.has("sandal")
	for i in (0 if sandal else full.size() - 1):
		var ca: Vector2 = full[i][1]
		var cb: Vector2 = full[i + 1][1]
		var ctr: Vector3 = (to3.call(full[i][0], ca) + to3.call(full[i + 1][0], cb)) / 2.0
		for k in RING:
			var k2 := (k + 1) % RING
			var a: Vector3 = up[i][k]
			var b: Vector3 = up[i][k2]
			var c: Vector3 = up[i + 1][k]
			var d: Vector3 = up[i + 1][k2]
			var o := (a + b + c + d) / 4.0 - ctr
			o -= fwd * o.dot(fwd)
			tri.call(a, b, c, o, 0.0, ca, ca, cb)
			tri.call(b, d, c, o, 0.0, ca, cb, cb)
	for end in ([] if sandal else [0, 1]):
		var i := 0 if end == 0 else full.size() - 1
		var c2: Vector2 = full[i][1]
		var tip: Vector3 = to3.call(t0 if end == 0 else t1, tip0 if end == 0 else tip1)
		var o := fwd * (-1.0 if end == 0 else 1.0)
		for k in RING:
			tri.call(up[i][k], up[i][(k + 1) % RING], tip, o, 0.0, c2, c2, c2)
	# Pohja: pyöristetty laatta kuoren ääriviivan (sc ± w + flare) mukaan, yläreuna kuoren alapinnan tasalla, alapinta
	# tasainen. Kärjessä sama puoliellipsi kuin kuoressa, flaren verran edempänä (tend + flare), ei kutistettua päätyä.
	var flare: float = p.flare
	# Kärjen nousu (toe spring): pohjan alapinta nousee päkiän edestä (tb:n ja kärjen välin 35 %) smoothstepillä kärkeen
	# spring-mitan verran; kanta ja päkiä pysyvät lattiassa.
	var ts0 := lerpf(tb, t1, 0.35)
	var spring: float = p.get("spring", 0.0)
	# Korko (waist): pohjan alapinta nousee kannan etureunasta (th, jyrkkä +-2 mm) ja laskee päkiän alkuun (tf) mennessä.
	var waist: float = p.get("waist", 0.0)
	var th := t0 + (t1 - t0) * 0.24
	var tf := t0 + (t1 - t0) * 0.58
	var rand: float = p.rand
	var slab := func(t: float, mid: float, hw: float) -> Array:
		var yt := y_welt + rand  # reunus kuoren kylkeä ylös (lenkkari: pieni limitys), myös päissä
		var yb := y_bot + spring * smoothstep(ts0, t1, t)
		if waist > 0.0:
			yb += waist * smoothstep(th - 0.002, th + 0.002, t) * (1.0 - smoothstep(th + 0.002, tf, t))
		var bv := minf(0.004, (yt - yb) / 3.0)
		var pr := PackedVector2Array([Vector2(mid + hw - flare * 0.5, yt), Vector2(mid + hw, yt - bv),
			Vector2(mid + hw, yb + bv), Vector2(mid + hw - bv, yb), Vector2(mid - hw + bv, yb),
			Vector2(mid - hw, yb + bv), Vector2(mid - hw, yt - bv), Vector2(mid - hw + flare * 0.5, yt)])
		return [t, Vector2(mid, (yt + yb) / 2.0), pr]
	var prof := []  # renkaittain [t, keskipiste, 8 pistettä (s, y)]
	var st_t := PackedFloat32Array()  # pohjan asemat: kuoren renkaat (ja korollisella kannan reunan katkokset)
	var st_m := PackedFloat32Array()
	var st_w := PackedFloat32Array()
	for r in full.slice(0, full.size() - TOE_RINGS):
		var lo := INF
		var hi := -INF
		for q: Vector2 in r[2]:
			lo = minf(lo, q.x)
			hi = maxf(hi, q.x)
		st_t.append(float(r[0]))
		st_m.append((lo + hi) / 2.0)
		st_w.append((hi - lo) / 2.0 + flare * float(r[3]))
	var extra := [th - 0.002, th + 0.002] if waist > 0.0 else []
	for i in st_t.size():
		for t: float in extra:
			if t < st_t[i] and (i == 0 or t > st_t[i - 1]):
				prof.append(slab.call(t, _at(st_t, st_m, t), _at(st_t, st_w, t)))
		prof.append(slab.call(st_t[i], st_m[i], st_w[i]))
	for j in TOE_RINGS:
		var t := ta + (t1 + flare - ta) * sin(PI / 2.0 * j / TOE_RINGS)
		var f := _toe_f(t, ta, t1 + flare, toe_n)
		prof.append(slab.call(t, tip_s + (sc_a - tip_s) * f, (w_a + flare) * f))
	# Kanta: pohja jatkuu kuoren pään alle kapenevana.
	var e0: Array = prof[0]
	var pr0 := PackedVector2Array()
	for q: Vector2 in e0[2]:
		pr0.append(Vector2(e0[1].x + (q.x - e0[1].x) * 0.55, q.y))
	prof.push_front([t0 - flare * 0.5, e0[1], pr0])
	var np := 8
	for i in prof.size() - 1:
		var ca: Vector2 = prof[i][1]
		var cb: Vector2 = prof[i + 1][1]
		var ctr: Vector3 = (to3.call(prof[i][0], ca) + to3.call(prof[i + 1][0], cb)) / 2.0
		for k in np:
			var k2 := (k + 1) % np
			var a: Vector3 = to3.call(prof[i][0], prof[i][2][k])
			var b: Vector3 = to3.call(prof[i][0], prof[i][2][k2])
			var c: Vector3 = to3.call(prof[i + 1][0], prof[i + 1][2][k])
			var d: Vector3 = to3.call(prof[i + 1][0], prof[i + 1][2][k2])
			var o := (a + b + c + d) / 4.0 - ctr
			o -= fwd * o.dot(fwd)
			tri.call(a, b, c, o, 1.0, ca, ca, cb)
			tri.call(b, d, c, o, 1.0, ca, cb, cb)
	for end in [0, 1]:
		var i := 0 if end == 0 else prof.size() - 1
		var c2: Vector2 = prof[i][1]
		var cen: Vector3 = to3.call(prof[i][0] if end == 0 else t1 + flare, c2)  # kärki suppenee pisteeseen
		var o := fwd * (-1.0 if end == 0 else 1.0)
		for k in np:
			tri.call(to3.call(prof[i][0], prof[i][2][k]), to3.call(prof[i][0], prof[i][2][(k + 1) % np]), cen, o, 1.0, c2, c2, c2)
	if sandal:
		_build_straps(p, pts, cand, vs, org, fwd, lat, side, tb, y_welt, ymin, _at(st_t, st_m, tb), _at(st_t, st_w, tb), to3, tri)
	return ymin - y_bot


## Sandaalin hihnat (osa 0, varjostin style 6). Hihna kulkee kireänä ihon päällä: poikkileikkauksen kärkien kupera
## kuori (Geometry2D.convex_hull) on kiristetyn hihnan muoto, joten hihna ei uppoa ihoon eikä jää irti kuin koverissa
## kohdissa (kuten oikea hihna). Ulkopinta thick verran ihon päällä, reunat suljettu ihon tasoon.
## Varvashihna: pystyleikkaus (s, y) kohdassa tb - toe, päät pohjalaatan reunoissa. Nilkkahihna: vaakaleikkaus (t, s)
## korkeudella ankle. Kantahihna: kannan takaa pohjasta nilkkahihnaan.
static func _build_straps(p: Dictionary, pts: PackedVector3Array, cand: PackedInt32Array, vs: PackedVector3Array, org: Vector3,
		fwd: Vector3, lat: Vector3, side: float, tb: float, y_welt: float, ymin: float, mid: float, hw: float, to3: Callable,
		tri: Callable) -> void:
	var sd: Dictionary = p.sandal
	var w: float = sd.w
	var thick: float = sd.thick
	# Kupera ketju pisteiden yli: hull = suljettu monikulmio, palautetaan avoin ketju a -> b sitä kautta, jonka keskiarvo
	# on suunnassa up korkeammalla (yläkautta), tasavälein n pisteeksi.
	var chain := func(pts2: PackedVector2Array, a: Vector2, b: Vector2, up: Vector2, n: int) -> PackedVector2Array:
		var all := pts2.duplicate()
		all.append(a)
		all.append(b)
		var hull := Geometry2D.convex_hull(all)
		hull.remove_at(hull.size() - 1)
		var ia := 0
		var ib := 0
		for i in hull.size():
			if hull[i].distance_to(a) < hull[ia].distance_to(a):
				ia = i
			if hull[i].distance_to(b) < hull[ib].distance_to(b):
				ib = i
		var paths := []
		for dir: int in [1, -1]:
			var path := PackedVector2Array()
			var i := ia
			while true:
				path.append(hull[i])
				if i == ib:
					break
				i = posmod(i + dir, hull.size())
			paths.append(path)
		var mean := func(path: PackedVector2Array) -> float:
			var m := 0.0
			for q in path:
				m += q.dot(up)
			return m / path.size()
		var path: PackedVector2Array = paths[0] if mean.call(paths[0]) >= mean.call(paths[1]) else paths[1]
		var total := 0.0
		for i in path.size() - 1:
			total += path[i].distance_to(path[i + 1])
		var out := PackedVector2Array()
		for k in n:
			var d := total * k / (n - 1)
			for i in path.size() - 1:
				var seg := path[i].distance_to(path[i + 1])
				if d <= seg or i == path.size() - 2:
					out.append(path[i].lerp(path[i + 1], clampf(d / maxf(seg, 1e-6), 0.0, 1.0)))
					break
				d -= seg
		return out
	# Nauha ketjusta: ulkopinta (off = thick) kahden reunan välillä ja reunakaistat ihon tasoon. at3(q, e) = ketjun piste q
	# reunalla e (-1 / +1) 3D:nä; ulkonormaali ketjun tasossa nrm2 -> out3(n2).
	var band := func(ch: PackedVector2Array, closed: bool, at3: Callable, out3: Callable) -> void:
		var n := ch.size()
		var nrm := PackedVector2Array()
		var cen := Vector2.ZERO
		for q in ch:
			cen += q / n
		for i in n:
			var a: Vector2 = ch[posmod(i - 1, n)] if (closed or i > 0) else ch[i]
			var b: Vector2 = ch[(i + 1) % n] if (closed or i < n - 1) else ch[i]
			var e := (b - a).normalized()
			var nn := Vector2(e.y, -e.x)
			if nn.dot(ch[i] - cen) < 0.0:
				nn = -nn
			nrm.append(nn)
		for i in (n if closed else n - 1):
			var j := (i + 1) % n
			var o3: Vector3 = out3.call((nrm[i] + nrm[j]).normalized())
			var a0: Vector3 = at3.call(ch[i] + nrm[i] * thick, -1.0)
			var a1: Vector3 = at3.call(ch[i] + nrm[i] * thick, 1.0)
			var b0: Vector3 = at3.call(ch[j] + nrm[j] * thick, -1.0)
			var b1: Vector3 = at3.call(ch[j] + nrm[j] * thick, 1.0)
			var z := Vector2.ZERO
			tri.call(a0, a1, b1, o3, 0.0, z, z, z)
			tri.call(a0, b1, b0, o3, 0.0, z, z, z)
			for e: float in [-1.0, 1.0]:  # reunat: ulkopinnasta ihon tasoon
				var ua: Vector3 = at3.call(ch[i] + nrm[i] * thick, e)
				var ub: Vector3 = at3.call(ch[j] + nrm[j] * thick, e)
				var la: Vector3 = at3.call(ch[i] - nrm[i] * 0.001, e)
				var lb: Vector3 = at3.call(ch[j] - nrm[j] * 0.001, e)
				var eo: Vector3 = (at3.call(ch[i], e) - at3.call(ch[i], 0.0)).normalized()
				tri.call(ua, ub, lb, eo, 0.0, z, z, z)
				tri.call(ua, lb, la, eo, 0.0, z, z, z)
	# Varpaankynnet: varpaat erotetaan sivusuunnassa (k-means, 5 ryhmää) jalan etuosan kärjistä; kynsi on varpaan kärjen
	# takana yläpinnalla. Varjostin lakkaa ne (character.gdshader nails).
	var tmax := -INF
	for q in pts:
		tmax = maxf(tmax, q.x)
	var front: Array[Vector3] = []
	var smin := INF
	var smax := -INF
	for q in pts:
		if q.x > tmax - 0.04:
			front.append(q)
			smin = minf(smin, q.y)
			smax = maxf(smax, q.y)
	var cen := PackedFloat32Array()
	for k in 5:
		cen.append(lerpf(smin, smax, (k + 0.5) / 5.0))
	var grp: Array = []
	for it in 12:
		grp = [[], [], [], [], []]
		for q in front:
			var bk := 0
			for k in 5:
				if absf(q.y - cen[k]) < absf(q.y - cen[bk]):
					bk = k
			grp[bk].append(q)
		for k in 5:
			if not grp[k].is_empty():
				var m := 0.0
				for q: Vector3 in grp[k]:
					m += q.y
				cen[k] = m / grp[k].size()
	for k in 5:
		if grp[k].is_empty():
			continue
		var tip := -INF
		for q: Vector3 in grp[k]:
			tip = maxf(tip, q.x)
		var ms := 0.0
		var top := -INF
		var lo := INF
		var hi := -INF
		var n := 0
		for q: Vector3 in grp[k]:
			if q.x > tip - 0.014:
				ms += q.y
				top = maxf(top, q.z)
				lo = minf(lo, q.y)
				hi = maxf(hi, q.y)
				n += 1
		var c3: Vector3 = to3.call(tip - 0.008, Vector2(ms / n, top))
		_nails.append_array([c3.x, c3.y, c3.z, clampf((hi - lo) * 0.42, 0.0035, 0.008)])
	# Varvashihna: pisteet (s, y) leikkauksessa ts ± (w/2 + 4 mm).
	var ts: float = tb - float(sd.toe)
	var sel := PackedVector2Array()
	for q in pts:
		if absf(q.x - ts) <= w / 2.0 + 0.004:
			sel.append(Vector2(q.y, q.z))
	if sel.size() >= 3:
		var ch: PackedVector2Array = chain.call(sel, Vector2(mid - hw + 0.003, y_welt), Vector2(mid + hw - 0.003, y_welt), Vector2(0, 1), 18)
		band.call(ch, false, func(q: Vector2, e: float) -> Vector3: return to3.call(ts + e * w / 2.0, q),
			func(n2: Vector2) -> Vector3: return lat * n2.x + Vector3.UP * n2.y)
	# Nilkkahihna: vaakaleikkaus (t, s) korkeudella ya ± (w/2 + 3 mm) jalkaterän ja säären kärjistä.
	var ya: float = ymin + float(sd.ankle)
	var wa: float = w * 0.8
	var ank := PackedVector2Array()
	var tback := INF
	for v in cand:
		if absf(vs[v].y - ya) <= wa / 2.0 + 0.003:
			var d := vs[v] - org
			ank.append(Vector2(d.dot(fwd), d.dot(lat)))
			tback = minf(tback, d.dot(fwd))
	if ank.size() >= 3:
		var hull := Geometry2D.convex_hull(ank)
		hull.remove_at(hull.size() - 1)
		# Tasavälein 28 pistettä kehää pitkin.
		var per := 0.0
		for i in hull.size():
			per += hull[i].distance_to(hull[(i + 1) % hull.size()])
		var loop := PackedVector2Array()
		for k in 28:
			var d := per * k / 28.0
			for i in hull.size():
				var seg := hull[i].distance_to(hull[(i + 1) % hull.size()])
				if d <= seg or i == hull.size() - 1:
					loop.append(hull[i].lerp(hull[(i + 1) % hull.size()], clampf(d / maxf(seg, 1e-6), 0.0, 1.0)))
					break
				d -= seg
		band.call(loop, true, func(q: Vector2, e: float) -> Vector3: return org + fwd * q.x + lat * q.y + Vector3.UP * (ya + e * wa / 2.0),
			func(n2: Vector2) -> Vector3: return fwd * n2.x + lat * n2.y)
	# Kantahihna: pystyleikkaus (t, y) kannan keskiviivalla (|s - kannan keskikohta| < 12 mm), pohjasta nilkkahihnaan.
	var sc_h := 0.0
	var nh := 0
	for q in pts:
		if q.x < tback + 0.03:
			sc_h += q.y
			nh += 1
	sc_h /= maxf(nh, 1)
	var back := PackedVector2Array()
	for v in cand:
		var d := vs[v] - org
		if absf(d.dot(lat) - sc_h) < 0.012 and vs[v].y < ya + 0.004 and d.dot(fwd) < tback + 0.05:
			back.append(Vector2(d.dot(fwd), vs[v].y))
	if back.size() >= 3:
		var lo_t := INF
		for q in back:
			lo_t = minf(lo_t, q.x)
		var top_t := INF
		for q in back:
			if q.y > ya - 0.008:
				top_t = minf(top_t, q.x)
		if top_t == INF:
			top_t = lo_t
		var chb: PackedVector2Array = chain.call(back, Vector2(lo_t + 0.004, y_welt), Vector2(top_t, ya), Vector2(-1, 0), 10)
		band.call(chb, false, func(q: Vector2, e: float) -> Vector3: return org + fwd * q.x + lat * (sc_h + e * w * 0.5) + Vector3.UP * q.y,
			func(n2: Vector2) -> Vector3: return fwd * n2.x + Vector3.UP * n2.y)


## Varsi (työkenkä, kuukenkä): pystyputki säären ympärillä jalkaosan suusta (join; alin rengas on suun ääriviiva, joten
## pinta jatkuu kuoresta ilman porrasta) varren yläreunaan (top).
## Vaakarenkaat ovat neljän puoliakselin superellipsejä (etu +t, taka, sivut ±s) säären keskipisteestä; puoliakselit
## mitataan kärjistä (kaikki paitsi paita, join - margin:n yläpuolella, joten alin rengas peittää jalkaosan suun) ja
## tasoitetaan _envelope:lla. Yläreunassa pehmustettu reuna ja rengaslevy sääreen, sisäpinta hieman alas; pohja viuhkana.
## UV = (kulma: 0 = etu, -0,5..0,5, saumaton takana; korkeus y_weltistä), UV2 = (sivu -1..1, + = ulkosivu; osa 2).
## Palauttaa Vector4(yläreuna UV2-avaruudessa, yläreuna verkossa, jalkaosan suu verkossa, UV2.y - y yläreunassa).
static func _build_shaft(st: SurfaceTool, p: Dictionary, vs: PackedVector3Array, uv2: PackedVector2Array, cs: PackedColorArray,
		bi: PackedInt32Array, bw: PackedFloat32Array, per: int, foot: PackedInt32Array, side: float, skin: Skin,
		skel: Skeleton3D, mouth: PackedVector2Array) -> Vector4:
	# Jalan kehys kuten _build_side: kannan ja päkiän luiden kärkien keskipisteet.
	var heel := Vector3.ZERO
	var ball := Vector3.ZERO
	var nh := 0
	var nb := 0
	var ymin := INF
	for v in foot:
		ymin = minf(ymin, vs[v].y)
		if _bone_of(v, bi, bw, per, skin, skel).begins_with("ball"):
			ball += vs[v]
			nb += 1
		else:
			heel += vs[v]
			nh += 1
	heel /= maxf(nh, 1)
	ball /= maxf(nb, 1)
	var fwd := Vector3(ball.x - heel.x, 0.0, ball.z - heel.z).normalized()
	var lat := Vector3.UP.cross(fwd)
	var org := Vector3(heel.x, 0.0, heel.z)
	var sh: Dictionary = p.shaft
	var rigid: bool = sh.get("rigid", false)
	var calf := -1  # jäykän varren luu (Skin-sidonta): saman puolen sääri
	if rigid:
		var nm := _bone_of(foot[0], bi, bw, per, skin, skel)
		var want := "calf" + nm.right(2)
		for b in skin.get_bind_count():
			var bn := str(skin.get_bind_name(b))
			if (bn if bn != "" else skel.get_bone_name(skin.get_bind_bone(b))) == want:
				calf = b
		if calf < 0:
			push_error("kumisaapas: luuta %s ei löydy, varsi painotetaan iholta" % want)
	var margin: float = p.margin
	var pad: float = sh.pad
	var y_welt: float = ymin - float(p.lift) + float(p.sole)
	var yj: float = ymin + float(sh.join)
	var y0 := yj + 0.012  # alin mitattu rengas; sen alla rengas jalkaosan suun ääriviivalla (yj)
	var y1: float = ymin + float(sh.top)
	if sh.has("top_k"):  # yläreuna osuutena nilkasta polveen (säären luun alku), ei kiinteänä mittana: puoleen sääreen
		var ank := skel.get_bone_global_rest(skel.find_bone("foot" + _bone_of(foot[0], bi, bw, per, skin, skel).right(2))).origin.y
		var knee := skel.get_bone_global_rest(skel.find_bone("calf" + _bone_of(foot[0], bi, bw, per, skin, skel).right(2))).origin.y
		y1 = lerpf(ank, knee, float(sh.top_k))
	_shaft_h = y1 - y_welt
	var win := (y1 - y0) / float(SHAFT_RINGS - 1) * 0.75 + 0.004
	# Kärjet (t, s, y) säären alaosasta; paita (luokka 1) pois. leg = painojen lähteet.
	var leg := PackedInt32Array()
	var pts := PackedVector3Array()
	var dy_top := 0.0  # UV2.y - y yläreunan kohdalla (lepopaikka ennen vartalon muotoa)
	var ntop := 0
	for v in vs.size():
		if signf(vs[v].x) != side or roundi(cs[v].r * 4.0) == 1 or vs[v].y > y1 + 0.06:
			continue
		leg.append(v)
		if vs[v].y < yj - margin:
			continue
		var d := vs[v] - org
		pts.append(Vector3(d.dot(fwd), d.dot(lat), vs[v].y))
		if absf(vs[v].y - y1) < 0.01:
			dy_top += uv2[v].y - vs[v].y
			ntop += 1
	dy_top /= maxf(ntop, 1)
	var hs := PackedFloat32Array()
	var ct := PackedFloat32Array()  # säären keskipiste (t, s) renkaittain
	var cl := PackedFloat32Array()
	for i in SHAFT_RINGS:
		var h := lerpf(y0, y1, float(i) / float(SHAFT_RINGS - 1))
		hs.append(h)
		var hc := maxf(h, yj + 0.025)  # alarenkaiden keskipiste nilkasta (jalan päällinen ei vedä sitä eteen)
		var c := Vector2.ZERO
		var n := 0
		for q in pts:
			if absf(q.z - hc) <= win:
				c += Vector2(q.x, q.y)
				n += 1
		c /= maxf(n, 1)
		ct.append(c.x)
		cl.append(c.y)
	for it in 2:
		ct = _smooth(ct)
		cl = _smooth(cl)
	var ax := [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]  # etu, taka, +s, -s
	var raw := [0.0, 0.0, 0.0, 0.0]  # yläreunan iho (rengaslevyn sisäreuna)
	for i in SHAFT_RINGS:
		var e := [0.002, 0.002, 0.002, 0.002]
		var sel := PackedVector2Array()
		for q in pts:
			if absf(q.z - maxf(hs[i], yj)) <= win:
				var d := Vector2(q.x - ct[i], q.y - cl[i])
				sel.append(d)
				e[0] = maxf(e[0], d.x)
				e[1] = maxf(e[1], -d.x)
				e[2] = maxf(e[2], d.y)
				e[3] = maxf(e[3], -d.y)
		var g := 1.0  # superellipsin kulma: kasvata, kunnes jokainen kärki on sisällä
		for d in sel:
			var a0: float = e[0] if d.x > 0.0 else e[1]
			var a1: float = e[2] if d.y > 0.0 else e[3]
			g = maxf(g, pow(pow(absf(d.x) / a0, SHAFT_N) + pow(absf(d.y) / a1, SHAFT_N), 1.0 / SHAFT_N))
		for k in 4:
			ax[k].append(e[k] * g + margin + pad + float(sh.get("flare", 0.0)) * float(i) / float(SHAFT_RINGS - 1))
			if i == SHAFT_RINGS - 1:
				raw[k] = e[k] * g
	for k in 4:
		ax[k] = _envelope(ax[k])
	var ring := func(c: Vector2, a: Array) -> PackedVector2Array:  # superellipsi (t, s); k = 0 takana, RING / 2 edessä
		var out := PackedVector2Array()
		for k in RING:
			var ang := PI + TAU * k / RING
			var x := signf(cos(ang)) * pow(absf(cos(ang)), 2.0 / SHAFT_N)
			var y := signf(sin(ang)) * pow(absf(sin(ang)), 2.0 / SHAFT_N)
			out.append(Vector2(c.x + x * float(a[0] if x > 0.0 else a[1]), c.y + y * float(a[2] if y > 0.0 else a[3])))
		return out
	# Renkaat [korkeus, keskipiste, pisteet (t, s), ulospäin: 0 säteittäin, 1 ylös, 2 sisään].
	var rows := []
	for i in SHAFT_RINGS:
		rows.append([hs[i], Vector2(ct[i], cl[i]), ring.call(Vector2(ct[i], cl[i]), [ax[0][i], ax[1][i], ax[2][i], ax[3][i]]), 0])
	# Alin rengas: jalkaosan suun ääriviiva kunkin pisteen suunnassa keskipisteestä (lähin sektori), tasoitettuna kehää pitkin.
	var c0 := Vector2(ct[0], cl[0])
	var se0: PackedVector2Array = rows[0][2]
	var rad := PackedFloat32Array()
	for k in RING:
		var d := (se0[k] - c0).normalized()
		var r := -1.0
		for m in mouth:
			var dm := m - c0
			if absf(d.angle_to(dm)) < TAU / RING:
				r = maxf(r, dm.dot(d))
		rad.append(maxf(r + float(sh.get("gap", 0.0005)), (se0[k] - c0).length()))  # ei kapeampi kuin säären tarve (iho pysyy sisällä)
	var rs := PackedFloat32Array()
	for k in RING:
		rs.append((rad[(k + RING - 1) % RING] + rad[k] * 2.0 + rad[(k + 1) % RING]) / 4.0)
	var r0p := PackedVector2Array()
	for k in RING:
		r0p.append(c0 + (se0[k] - c0).normalized() * rs[k])
	# Alarenkaat liukuvat suun ääriviivasta säären mittoihin (ei olkaa suun ja varren välissä): säde vähintään sekoitus.
	for i in SHAFT_RINGS:
		var w := smoothstep(yj, yj + 0.04, float(rows[i][0]))
		if rigid:  # leveä varsi: suun ääriviivasta yläreunan mittoihin koko korkeudella (ei olkaa nilkassa)
			w = clampf((float(rows[i][0]) - yj) / (y1 - yj), 0.0, 1.0)
		var ci: Vector2 = rows[i][1]
		var pi: PackedVector2Array = rows[i][2]
		for k in RING:
			var rse := (pi[k] - ci).length()
			pi[k] = ci + (pi[k] - ci).normalized() * maxf(rse, lerpf(rs[k], rse, w))
		rows[i][2] = pi
	rows.push_front([yj, c0, r0p, 0])
	var yb := yj  # putken alin rengas (pohjaviuhka)
	var rb := r0p
	if rigid:  # jäykkä varsi: alareuna lap verran alaosan suun alla, kavennettuna kuoren sisään (limitys nilkassa)
		yb = yj - float(sh.lap)
		rb = PackedVector2Array()
		for k in RING:
			rb.append(c0 + (r0p[k] - c0).normalized() * maxf(rs[k] - margin - 0.004, 0.01))
		var rw := PackedVector2Array()  # suun levyinen rengas 15 mm suun alla: alaosan suu jää varren sisään asennoissakin
		for k in RING:
			rw.append(c0 + (r0p[k] - c0).normalized() * (rs[k] + 0.008))
		rows.push_front([yj - 0.015, c0, rw, 0])
		rows.push_front([yb, c0, rb, 0])
	var c1 := Vector2(ct[SHAFT_RINGS - 1], cl[SHAFT_RINGS - 1])
	var a1 := [ax[0][SHAFT_RINGS - 1], ax[1][SHAFT_RINGS - 1], ax[2][SHAFT_RINGS - 1], ax[3][SHAFT_RINGS - 1]]
	var lip := []
	var inner := []
	for k in 4:
		lip.append(lerpf(float(a1[k]), raw[k] + margin, 0.45))  # pyöristetty pehmustettu yläreuna
		inner.append(raw[k] + 0.001)
	rows.append([y1 + 0.005, c1, ring.call(c1, lip), 0])
	rows.append([y1 + 0.003, c1, ring.call(c1, inner), 1])
	rows.append([y1 - 0.015, c1, ring.call(c1, inner), 2])
	var to3 := func(q: Vector2, h: float) -> Vector3:
		return org + fwd * q.x + lat * q.y + Vector3.UP * h
	var add := func(a: Vector3, k: float, h: float, part: float) -> void:
		var ang := PI + TAU * k / RING
		st.set_uv(Vector2(k / RING - 0.5, h - y_welt))
		st.set_uv2(Vector2(sin(ang) * side, part))
		st.set_color(Color(1, 1, 1, 1))
		_set_weights(st, a, vs, bi, bw, per, leg, calf, 1.0 if calf >= 0 else 0.0)
		st.add_vertex(a)
	# Osa 2,0 = varren ulkopinta, 2,2 = yläreunan levy ja sisäpinta (skin_outside ohittaa, varjostimessa sama osa 2).
	var tri := func(pa: Array, pb: Array, pc: Array, out: Vector3, part: float) -> void:  # [paikka, k, h]
		if (pc[0] - pa[0]).cross(pb[0] - pa[0]).dot(out) < 0.0:
			var tmp := pb
			pb = pc
			pc = tmp
		for q in [pa, pb, pc]:
			add.call(q[0], float(q[1]), q[2], part)
	for i in rows.size() - 1:
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		var mode: int = r1[3]
		var p0: PackedVector2Array = r0[2]
		var p1: PackedVector2Array = r1[2]
		var h0: float = r0[0]
		var h1: float = r1[0]
		for k in RING:
			var k2 := (k + 1) % RING
			var a: Vector3 = to3.call(p0[k], h0)
			var b: Vector3 = to3.call(p0[k2], h0)
			var c: Vector3 = to3.call(p1[k], h1)
			var d: Vector3 = to3.call(p1[k2], h1)
			var mid := (a + b + c + d) / 4.0
			var cm: Vector2 = (r0[1] + r1[1]) / 2.0
			var o: Vector3 = mid - to3.call(cm, mid.y)
			o.y = 0.0
			if mode == 1:
				o = Vector3.UP
			elif mode == 2:
				o = -o
			var part := 2.0 if mode == 0 else 2.2
			tri.call([a, k, h0], [b, k + 1, h0], [c, k, h1], o, part)
			tri.call([b, k + 1, h0], [d, k + 1, h1], [c, k, h1], o, part)
	# Pohja viuhkana (jalkaosan suun kohdalla, ulospäin alas).
	var cen: Vector3 = to3.call(c0, yb - 0.002)
	for k in RING:
		tri.call([to3.call(rb[k], yb), k, yb], [to3.call(rb[(k + 1) % RING], yb), k + 1, yb], [cen, k + 0.5, yb], Vector3.DOWN, 2.0)
	return Vector4(y1 + dy_top, y1, yj, dy_top)


## Poikkileikkaus: superellipsi (eksponentti SE_N) keskipisteestä (sc, yc), puolileveys w, yläpuolisko hu ja alapuolisko
## B_LOW (alin piste tasan yc - B_LOW). Kiinteät kulmat: piste k on joka renkaassa samassa kohdassa kehää. Yläreuna
## enintään cap (kengän suu lahkeen alla, ei näy).
static func _ring_at(sc: float, yc: float, w: float, hu: float, cap: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in RING:
		var a := TAU * k / RING
		var x := signf(cos(a)) * pow(absf(cos(a)), 2.0 / SE_N)
		var y := signf(sin(a)) * pow(absf(sin(a)), 2.0 / SE_N)
		out.append(Vector2(sc + w * x, minf(yc + (hu if y > 0.0 else B_LOW) * y, cap)))
	return out


## Kärjen kavennus kohdassa t: 1 ennen ta:ta, superellipsi (eksponentti n) nollaan kärjessä tend.
static func _toe_f(t: float, ta: float, tend: float, n: float) -> float:
	var u := clampf((t - ta) / (tend - ta), 0.0, 1.0)
	return pow(1.0 - pow(u, n), 1.0 / n)


## Käyrän arvo kohdassa t (asemien at välillä lineaarisesti, päiden ulkopuolella päätyarvo).
static func _at(at: PackedFloat32Array, v: PackedFloat32Array, t: float) -> float:
	if t <= at[0]:
		return v[0]
	for i in at.size() - 1:
		if t <= at[i + 1]:
			return lerpf(v[i], v[i + 1], (t - at[i]) / (at[i + 1] - at[i]))
	return v[v.size() - 1]


## Käyrä 1-2-1 (päissä päätyarvo toistuu).
static func _smooth(v: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := v.size()
	for i in n:
		out.append((v[maxi(i - 1, 0)] + v[i] * 2.0 + v[mini(i + 1, n - 1)]) / 4.0)
	return out


## Sileä käyrä tarpeen need yläpuolelle: harvan vartaloverkon (noin 400 kärkeä jalassa) mitat hyppivät asemasta toiseen.
## Kolme kertaa max(tarve, tasoitus), sitten kaksi tasoitusta; huippujen kutistuman kattaa rako (testi: skin_outside).
static func _envelope(need: PackedFloat32Array) -> PackedFloat32Array:
	var a := need
	for it in 3:
		var sm := _smooth(a)
		for i in sm.size():
			sm[i] = maxf(sm[i], need[i])
		a = sm
	return _smooth(_smooth(a))


static func _bone_of(v: int, bi: PackedInt32Array, bw: PackedFloat32Array, per: int, skin: Skin, skel: Skeleton3D) -> String:
	var b := _bind_of(v, bi, bw, per)
	var nm := str(skin.get_bind_name(b))
	return nm if nm != "" else skel.get_bone_name(skin.get_bind_bone(b))


## Kärjen v painavin luu (Skin-sidonnan indeksi).
static func _bind_of(v: int, bi: PackedInt32Array, bw: PackedFloat32Array, per: int) -> int:
	var best := 0
	for k in per:
		if bw[v * per + k] > bw[v * per + best]:
			best = k
	return bi[v * per + best]


## Painot kolmesta lähimmästä vartalon kärjestä etäisyydellä painottaen (kenkä taipuu päkiästä kuten iho). tw > 0:
## sekoitetaan osuus tw jäykästi luulle fixed (kärkiosa päkiän luulla).
static func _set_weights(st: SurfaceTool, a: Vector3, vs: PackedVector3Array, bi: PackedInt32Array, bw: PackedFloat32Array,
		per: int, cand: PackedInt32Array, fixed := -1, tw := 0.0) -> void:
	var near := [[INF, -1], [INF, -1], [INF, -1]]
	for v in cand:
		var d := a.distance_squared_to(vs[v])
		if d < near[2][0]:
			near[2] = [d, v]
			near.sort_custom(func(x, y): return x[0] < y[0])
	var acc := {}
	for n in near:
		if n[1] < 0:
			continue
		var w := 1.0 / (sqrt(n[0]) + 0.004)
		for k in per:
			var wk: float = bw[n[1] * per + k]
			if wk > 0.0:
				acc[bi[n[1] * per + k]] = float(acc.get(bi[n[1] * per + k], 0.0)) + wk * w
	if tw > 0.0:
		var sum := 0.0
		for k in acc:
			sum += acc[k]
		for k in acc:
			acc[k] = acc[k] / sum * (1.0 - tw)
		acc[fixed] = float(acc.get(fixed, 0.0)) + tw
	var keys: Array = acc.keys()
	keys.sort_custom(func(x, y): return acc[x] > acc[y])
	var n4 := 4 if per <= 4 else 8
	var total := 0.0
	for k in mini(n4, keys.size()):
		total += acc[keys[k]]
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	for k in n4:
		bones.append(keys[k] if k < keys.size() else 0)
		wts.append(acc[keys[k]] / total if k < keys.size() else 0.0)
	st.set_bones(bones)
	st.set_weights(wts)


## Jalkaterän ihon pahin ulkonema kuoren ulkopuolelle lepoasennossa (m; < 0 = kaikki sisällä). Testikohtaukselle:
## säde jokaisen kärjen suunnassa verrattuna kuoren säteeseen samassa poikkileikkauksessa (lähin rengas).
static func skin_outside(shoe: ArrayMesh, arr: Array) -> float:
	var sa := shoe.surface_get_arrays(0)
	var sv: PackedVector3Array = sa[Mesh.ARRAY_VERTEX]
	var su2: PackedVector2Array = sa[Mesh.ARRAY_TEX_UV2]
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var worst := -INF
	var above: PackedInt32Array = shoe.get_meta("suu", PackedInt32Array())
	var vv: Vector3 = shoe.get_meta("varsi_v", Vector3.ZERO)  # (yläreuna, jalkaosan suu, -); 0 = ei vartta
	for v in vs.size():
		var c := roundi(cs[v].r * 4.0)
		# Varsi: jalkaosan suun yläpuolinen jalkaterä sekä sääri ja lahje varren yläreunaan asti mitataan varren ulkopintaa vastaan.
		var in_shaft := vv.x > 0.0 and c != 1 and ((c == 3 and v in above) or (c != 3 and vs[v].y >= vv.y and vs[v].y <= vv.x))
		if not in_shaft and (c != 3 or v in above):
			continue
		# Lähin päällisen piste (osa 0) ja sen normaali: ihon kärki on ulkona, jos se on pinnan ulkopuolella. Pohja (osa 1)
		# ohitetaan: sen reunuksen sisäpuolen yläreuna osoittaa ylös ja mittasi korkeutta, ei ulkonemaa (A2 M0a).
		var best := INF
		var bj := -1
		for j in sv.size():
			if (su2[j].y > 0.5) if not in_shaft else (su2[j].y < 1.5 or su2[j].y > 2.1):
				continue
			var d := vs[v].distance_squared_to(sv[j])
			if d < best:
				best = d
				bj = j
		var n: Vector3 = (sa[Mesh.ARRAY_NORMAL] as PackedVector3Array)[bj]
		worst = maxf(worst, (vs[v] - sv[bj]).dot(n))
	return worst
