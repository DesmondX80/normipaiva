extends "res://scripts/rikos/osa.gd"
## S2 Yliannos (Saloinen ja Vaala). Kaksi puolta, molemmat vakavia eikä kumpikaan vitsi:
## 1) Pelaajan oma olo: jokainen lääkkeen otto (tapahtuma "otto") lisää pelin "kuormaa" lääkkeen mukaan (KUORMA, kerrottuna
##    jatkamisen teholla), muu humala kertoo sen kaksinkertaiseksi ja kuorma laskee ajan myötä. VAROITUS-rajalla tulee
##    varoitus, RAJA-rajalla pelaaja lyyhistyy: game._rikos_loppu("yliannos") (ELVYTETTY, Päivi: "HUUMEET ON VAARALLISIA.
##    OIKEASTI."). Luvut ovat pelin yksiköitä, eivät annoksia.
## 2) Kaukalo (S2b): myyntiä kaukalon teineille seuraavana iltana yksi teini voi lyyhistyä maahan (enintään kerran
##    VALI päivässä). Valinnat: soita 112 (ambulanssi AMBU_MIN peliminuutin päästä), jää auttamaan (naloksonilla teini herää)
##    tai häivy (maine −, epäluulo tapahtumalla "hylkasi"; aamulla tieto, että joku muu soitti ja poika selvisi).
##    Naloksonisuihke saadaan kerran Railin luukulta. Ensiapu on tekstiä ja häivytys, ei hoito-ohjetta yli "soita 112".
## Makaava teini: Death01-loppuasento selällään (kuten aurinko_sinikka.gd), paikallinen +Z = pää, -Z = jalat, kasvot +Y.

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")
const Pose := preload("res://scripts/pose.gd")
const Vehicles := preload("res://scripts/vehicles.gd")

# Oma olo (pelin kuorma 0–RAJA).
const KUORMA := {"opiaatti": 45.0, "tramal": 15.0, "panacod": 6.0, "perv": 25.0}  # per otto, × teho (jatkettu = puolet)
const HUMALA_KERROIN := 2.0  # muu humala (yli HUMALA_RAJA) kertoo kuorman: alkoholi ja lääkkeet yhdessä
const HUMALA_RAJA := 0.3
const LASKU := 0.25  # kuormaa pois per peliminuutti (15 tunnissa)
const VAROITUS := 60.0
const RAJA := 100.0
# Kaukalo.
const P_TAPAUS := 0.5  # myyntiä seuraavana iltana: todennäköisyys, että joku lyyhistyy
const VALI := 3  # päivää tapausten välillä vähintään
const LAUKAISU_R := 30.0  # pelaaja näin lähellä ringistä, kun tapaus alkaa
const PAIKKA := Vector3(6.2, 0, 1.2)  # makaavan teinin paikka ringin paikallisessa (+X = ulos kaukalolta), yli HS_TALK_R + PUHE_R
const PUHE_R := 2.4
const POIS_R := 45.0  # kauempana ilman valintaa = häipyi
const AMBU_MIN := 20.0  # peliminuuttia soitosta
const AMBU_HOITO := 14.0  # s: ensihoitajat pojan luona, sitten ambulanssi lähtee
const MAINE_SOITTO := 3.0
const MAINE_NALOKSONI := 5.0
const MAINE_AUTTOI := 2.0
const MAINE_HAIPYI := 5.0
const SUIHKE_R := 0.0135  # kyljellään olevan suihkeen akselin korkeus maasta (painimen säde + 1 mm)
const MEDIC_RAKO := 0.45  # ensihoitajan rako teinin ihosta (arkkitehtuuri: vähintään 0,4 m)
const MEDIC_R := 0.25  # seisovan hahmon puolileveys jalkojen ja vartalon kohdalla

const TEINI_LOOK := {"shirt": Color(0.38, 0.4, 0.44), "pants": Color(0.2, 0.24, 0.34), "jeans": true,
	"shoes": Color(0.92, 0.92, 0.9), "hair": "Hair_Buzzed", "hair_color": Color(0.45, 0.32, 0.18), "height": 1.74,
	"bulk": -0.65, "shoulders": -0.55}
const ENSIHOITAJA_LOOKS := [
	{"shirt": Color(0.72, 0.86, 0.12), "pants": Color(0.1, 0.2, 0.17), "shoes": Color(0.08, 0.08, 0.08),
		"hair": "Hair_Buzzed", "hair_color": Color(0.3, 0.22, 0.14), "height": 1.82},
	{"model": "female", "shirt": Color(0.72, 0.86, 0.12), "pants": Color(0.1, 0.2, 0.17), "shoes": Color(0.08, 0.08, 0.08),
		"hair": "Hair_Long", "hair_color": Color(0.7, 0.5, 0.3), "height": 1.68},
]
const AMBU_KELTA := Color(0.8, 0.9, 0.1)  # suomalainen ensihoitoyksikkö: keltavihreä, oranssi ruudutus (esikuva Commons)
const AMBU_ORANSSI := Color(1.0, 0.38, 0.08)

var kuorma := 0.0
var _kuorma_t := -1.0  # kuorman aikaleima: day * 1440 + clock_min
var varoitettu := false
var naloksoni := false  # suihke repussa (Railin luukulta)
var naloksoni_saatu := false  # pyydetty jo kerran
var myynti_paiva := -99  # viimeisin myynti kaukalon teineille
var tapaus_paiva := -99  # viimeisin lyyhistyminen
var arvottu_paiva := -99  # ilta, jolle tapaus on arvottu
var hylatty := false  # pelaaja häipyi: aamulla tieto
var auttanut := 0  # tapaukset, joissa pelaaja auttoi (päiväkirja)
## Tapauksen tila: "" (ei mitään), "maassa" (valitsematta), "soitettu" (ambulanssi tulossa), "hoito" (ensihoitajat paikalla),
## "herasi" (naloksoni), "haipyi".
var tila := ""
var ambu_t := 0.0  # peliminuutti (day * 1440 + clock_min), jolloin ambulanssi saapuu
var _hoito_ms := 0
var holder: Node3D  # makaava teini ja tapahtuman propit (game.world:n alla)
var teini: Node3D
var ambu: Node3D
var _valot: Array = []
var _seuraus: Array = []  # tunnisteet testiä varten


func _init() -> void:
	talkers = ["kaukalo_poika"]


func _nyt() -> float:
	return game.day * 1440.0 + game.clock_min


## Kuorma nyt (laskettu ajasta, ei muuta tilaa).
func kuorma_nyt() -> float:
	if _kuorma_t < 0.0:
		return kuorma
	return maxf(0.0, kuorma - LASKU * maxf(0.0, _nyt() - _kuorma_t))


func on_event(ev: String, data: Dictionary) -> void:
	match ev:
		"otto":
			_otto(String(data.get("key", "")), float(data.get("pot", 1.0)))
		"myynti":
			if data.get("paikka", "") == "saloinen" and game._talk_who == "kaukalo_teinit":
				myynti_paiva = game.day


func _otto(key: String, pot: float) -> void:
	var base: String = game._laake_base(key)
	var lisa: float = KUORMA.get(base, 0.0) * pot
	if lisa <= 0.0:
		return
	# Lääkkeen oma humala on jo lisätty (_take_laake): muu humala = arvo − lääkkeen osuus.
	var oma: float = float(game.APTEEKKI_MENU[base][4]) * pot
	var muu: float = game.tilat.value("humala") - oma
	var tupla := muu >= HUMALA_RAJA
	if tupla:
		lisa *= HUMALA_KERROIN
	kuorma = kuorma_nyt() + lisa
	_kuorma_t = _nyt()
	print("YLIANNOS otto %s teho %.2f: +%.0f%s -> kuorma %.0f" % [key, pot, lisa, " (humala ×2)" if tupla else "", kuorma])
	if kuorma >= RAJA:
		game.get_tree().create_timer(3.2).timeout.connect(_lyyhistyy.bind(tupla))
	elif kuorma >= VAROITUS and not varoitettu:
		varoitettu = true
		game.get_tree().create_timer(3.2).timeout.connect(_varoita.bind(tupla))


func _varoita(tupla: bool) -> void:
	if game.state == "cutscene":
		return
	game._show_message("Olo on outo: hengitys hidastuu ja silmät painaa. Nyt ei enää yhtään mitään.%s" %
		(" Viina ja lääkkeet yhdessä on huono yhdistelmä." if tupla else ""), 4.5)
	Sfx.play("glass", -12.0, 0.6)


func _lyyhistyy(tupla: bool) -> void:
	if game.state == "cutscene" or kuorma_nyt() < RAJA:
		return
	game._show_message("Maailma pimenee...", 2.0)
	game.get_tree().create_timer(1.8).timeout.connect(func() -> void:
		kuorma = 0.0
		varoitettu = false
		game._rikos_loppu("yliannos", "Otit liikaa%s. Hengitys katkesi." % (", ja vielä viinan päälle" if tupla else "")))


# --- Naloksoni Railin luukulta ---------------------------------------------------------------------------------

func options(who: String, o: Array) -> void:
	if who == "apteekki_hoitaja" and not naloksoni_saatu:
		o.append(game._opt("yliannos_naloksoni", "Pyydä naloksonisuihke (ilmainen)"))
	elif who == "kaukalo_poika" and tila == "maassa":
		o.append(game._opt("yliannos_soita", "Soita 112"))
		o.append(game._opt("yliannos_auta", "Jää auttamaan%s" % (" (naloksonisuihke repussa)" if naloksoni else "")))
		o.append(game._opt("yliannos_haivy", "Häivy paikalta"))
	elif who == "kaukalo_poika" and tila == "soitettu":
		o.append(game._opt("yliannos_odota", "Odota ambulanssia vieressä"))


func hello(who: String) -> String:
	if who != "kaukalo_poika":
		return ""
	match tila:
		"maassa":
			return "(Teini makaa selällään nurmella eikä vastaa. Huulet sinertää, hengitys on hidasta ja korisevaa.)\n" \
				+ "Kaveri: \"Se ei herää! Me ei uskalleta soittaa, meille tulee ongelmia...\""
		"soitettu":
			return "(Hengittää hitaasti. Ambulanssi on tulossa.)"
		"herasi":
			return "(Istuu jo, kalpeana.) \"Mitä... mitä tapahtu? Kiitti, äijä. Oikeesti.\""
	return "(Ensihoitajat ovat pojan luona.)"


func choose(id: String) -> bool:
	if not id.begins_with("yliannos_"):
		return false
	match id:
		"yliannos_naloksoni":
			naloksoni_saatu = true
			naloksoni = true
			game.tilat.first("naloksoni", 0.2)
			game._save_game()
			game._talk_box.reply("Tässä. Toivottavasti et koskaan tarvitse. Jos joku ei herää: soita 112 ja käytä tätä.",
				game._talk_options(), "Naloksonisuihke reppuun. Näkyy päiväkirjan Riskit-sivulla (7).")
		"yliannos_soita":
			_soita()
			_seuraus.append("soitto")
			game._talk_box.reply("Hätäkeskus: \"Ambulanssi on matkalla. Pysy hänen luonaan ja seuraa, että hän hengittää.\"",
				game._talk_options(), "Ambulanssi tulee noin %d minuutissa. Maine +%d." % [roundi(AMBU_MIN), roundi(MAINE_SOITTO)])
		"yliannos_auta":
			_auta()
		"yliannos_haivy":
			game._talk_box.close()
			_haivy()
		"yliannos_odota":
			game._talk_box.reply("Istut vieressä ja seuraat hengitystä. Kaukaa kuuluu jo sireeni.", game._talk_options())
	return true


func _soita() -> void:
	tila = "soitettu"
	ambu_t = _nyt() + AMBU_MIN
	game.maine = clampf(game.maine + MAINE_SOITTO, 0.0, 100.0)
	game.tilat.first("soitti_112", 0.3)
	Sfx.play("pickup", -6.0, 1.3)
	game._save_game()


func _auta() -> void:
	_soita()
	var nalo := naloksoni
	if nalo:
		naloksoni = false
		game.maine = clampf(game.maine + MAINE_NALOKSONI - MAINE_SOITTO, 0.0, 100.0)
	else:
		game.maine = clampf(game.maine + MAINE_AUTTOI, 0.0, 100.0)
	auttanut += 1
	_seuraus.append("naloksoni" if nalo else "auttoi")
	_hairio()
	var rivi: String
	if nalo:
		tila = "herasi"
		_spray_maahan()
		rivi = "Soitat 112, suihkautat naloksonin ja käännät hänet kylkiasentoon. Hetken päästä hän vetää henkeä ja avaa silmät."
	else:
		rivi = "Soitat 112, käännät hänet kylkiasentoon ja pysyt vieressä. Hengitys kulkee, hitaasti. Ambulanssi on tulossa."
	var maine_yht := MAINE_NALOKSONI if nalo else MAINE_SOITTO + MAINE_AUTTOI
	game._save_game()
	game._talk_box.reply(rivi, game._talk_options(), "Maine +%d.%s" % [roundi(maine_yht),
		" Naloksoni käytetty." if nalo else " Naloksonia ei ollut (Railin luukulta saa yhden)."])


func _haivy() -> void:
	tila = "haipyi"
	hylatty = true
	_seuraus.append("haipyi")
	game.maine = clampf(game.maine - MAINE_HAIPYI, 0.0, 100.0)
	game._rikos_event("hylkasi", {})  # epaluulo.gd: kylän epäluulo kasvaa (vain tämä tapahtuma, ei "epaluulo")
	game._show_message("Lähdit. Poika jäi nurmelle. Maine −%d." % roundi(MAINE_HAIPYI), 3.0)
	game._save_game()


## Lyhyt musta häivytys (ensiapu kerrotaan tekstinä).
func _hairio() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(r)
	game.add_child(cl)
	var tw := game.create_tween()
	tw.tween_property(r, "color:a", 0.85, 0.5)
	tw.tween_interval(0.8)
	tw.tween_property(r, "color:a", 0.0, 0.7)
	tw.tween_callback(cl.queue_free)


# --- Kaukalon tapaus ---------------------------------------------------------------------------------------------

func _ring() -> Node3D:
	return game.hs_teens


func _voi_alkaa() -> bool:
	var r := _ring()
	if r == null or not r.visible or game._in_vaala or game.state != "ulkona":
		return false
	if game.day != myynti_paiva + 1 or game.day - tapaus_paiva < VALI:
		return false
	var p: Vector3 = game._active_walker().global_position
	return Vector2(p.x - r.center().x, p.z - r.center().z).length() < LAUKAISU_R


func tick(_e: bool) -> void:
	if game._in_vaala:
		return
	if tila == "":
		if arvottu_paiva != game.day and _voi_alkaa():
			arvottu_paiva = game.day
			if randf() < P_TAPAUS:
				aloita()
		return
	if holder == null or not is_instance_valid(holder):
		return
	var p: Vector3 = game._active_walker().global_position
	var d := Vector2(p.x - teini.global_position.x, p.z - teini.global_position.z).length() if teini != null else 99.0
	if tila == "maassa" and d > POIS_R and not game._talk_box.is_open():
		_haivy()
	if tila in ["soitettu", "herasi"] and _nyt() >= ambu_t:
		_ambulanssi_tulee()
	if tila == "hoito":
		_vilkku()
		if Time.get_ticks_msec() - _hoito_ms > int(AMBU_HOITO * 1000.0):
			_ambulanssi_lahtee()
	if tila == "haipyi" and d > POIS_R:
		poista()
		return
	if teini == null or game._talk_box.is_open() or game._hint.text != "" or tila in ["", "haipyi"]:
		return
	if d < PUHE_R:
		game._talk_hint("kaukalo_poika", teini, game.player != game.bike)


## Tapaus alkaa: teini maahan ringin viereen, kaverit kuplassa.
func aloita() -> void:
	tapaus_paiva = game.day
	tila = "maassa"
	_seuraus.clear()
	var r := _ring()
	var lp := PAIKKA.rotated(Vector3.UP, r.rotation.y)
	var wp: Vector3 = r.center() + lp
	holder = Node3D.new()
	holder.name = "YliannosTeini"
	game.world.add_child(holder)
	holder.global_position = Vector3(wp.x, T.h(wp.x, wp.z), wp.z)
	holder.rotation.y = r.rotation.y + 0.9  # pää vinottain kaukalosta poispäin
	teini = build_teen(holder)
	# Törmäys, jotta pelaaja ei kävele makaavan päälle (kuten kaukalon teinien kapselit).
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.7, 0.3, 1.8)
	cs.shape = bs
	body.add_child(cs)
	body.position = Vector3(0, 0.15, 0)
	holder.add_child(body)
	game.get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if teini != null and is_instance_valid(teini):
			print("YLIANNOS teini maassa: %s" % [lay_down(holder, teini)]))
	r.say("Se ei herää! Joku tehkää jotain!", 4.0)
	game._show_message("Kaukalon laidalla joku teini on lyyhistynyt maahan.", 3.5)


## Asettaa Death01-asennossa olevan hahmon (ch, holderin lapsi) selälleen maahan: pää holderin +Z:aan, lantio ja rintakehä
## samalle korkeudelle ja alin ihopiste (paistettu verkko) maan + 0,005 m yläpuolelle maaston Terrain.h:n mukaan.
## Palauttaa mittaukset {"alin", "ylin_selka"} (rako maahan metreinä).
static func lay_down(holder: Node3D, ch: Node3D, ground := Callable()) -> Dictionary:
	if not ground.is_valid():
		ground = func(x: float, z: float) -> float: return T.h(x, z)
	ch.refresh_pose()
	var h0: Vector3 = ch.bone_position("Head")
	var f0: Vector3 = (ch.bone_position("foot_l") + ch.bone_position("foot_r")) / 2.0
	var a := atan2(h0.x - f0.x, h0.z - f0.z)
	ch.rotation.y = -a
	var mid: Vector3 = Basis(Vector3.UP, ch.rotation.y) * ((h0 + f0) / 2.0)
	ch.position = Vector3(-mid.x, 0.0, -mid.z)
	# Selkä suoraksi: lantio ja rintakehä samalle korkeudelle (kierto sivuakselin ympäri, kuten aurinko_sinikka.gd).
	for k in 3:
		ch.refresh_pose()
		var pel := _low(ch, holder, ["pelvis"])
		var chest := _low(ch, holder, ["spine_03"])
		if pel == INF or chest == INF:
			break
		var bz: float = (ch.transform * ch.bone_position("spine_03") - ch.transform * ch.bone_position("pelvis")).z
		ch.transform = Transform3D(Basis(Vector3.RIGHT, atan2(chest - pel, bz)), Vector3.ZERO) * ch.transform
	# Rinne: hahmo kallistetaan maaston normaalin mukaan (normaali holderin avaruudessa, 0,8 m:n erotuksista).
	var c := holder.global_position
	var e := 0.8
	var n_w := Vector3(ground.call(c.x - e, c.z) - ground.call(c.x + e, c.z), 2.0 * e,
		ground.call(c.x, c.z - e) - ground.call(c.x, c.z + e)).normalized()
	var n_l := holder.global_basis.inverse() * n_w
	ch.transform = Transform3D(Basis(Quaternion(Vector3.UP, n_l)), Vector3.ZERO) * ch.transform
	ch.refresh_pose()
	# Death01:n kädet roikkuvat selän tason alapuolella (käsi n. 15 cm lantiota alempana): ilman korjausta selkä
	# leijuisi. Raajan juurta (olkavarsi, reisi) kierretään yhden akselin ympäri, kunnes raajan alin ihopiste on
	# selän alimman pisteen tasolla. Akselit hahmon avaruudessa: kädet pituusakselin (holderin +Z), jalat sivuakselin
	# (holderin +X) ympäri. Kierron suunta ja suuruus mitataan (koekierto 0,05 rad), ei arvata etumerkkiä.
	var along_ch := (ch.basis.inverse() * Vector3(0, 0, 1)).normalized()
	var side_ch := (ch.basis.inverse() * Vector3(1, 0, 0)).normalized()
	var torso_b := ["pelvis", "spine_01", "spine_02", "spine_03"]
	for limb in [["upperarm_l", _limb_bones(ch, ["arm", "hand", "thumb", "index", "middle", "ring", "pinky"], "_l"), along_ch],
			["upperarm_r", _limb_bones(ch, ["arm", "hand", "thumb", "index", "middle", "ring", "pinky"], "_r"), along_ch],
			["thigh_l", _limb_bones(ch, ["thigh", "calf", "foot", "ball", "toe"], "_l"), side_ch],
			["thigh_r", _limb_bones(ch, ["thigh", "calf", "foot", "ball", "toe"], "_r"), side_ch]]:
		var ang := 0.0
		for it in 5:
			var t_low := _ground_gap(ch, holder, torso_b, ground)
			var lo := _ground_gap(ch, holder, limb[1], ground)
			var drop := t_low - lo
			if absf(drop) < 0.008 or lo == INF:
				break
			ch.set_override(limb[0], limb[2], ang + 0.05)
			ch.refresh_pose()
			var slope := (_ground_gap(ch, holder, limb[1], ground) - lo) / 0.05
			if absf(slope) < 0.02:
				ch.set_override(limb[0], limb[2], ang)
				ch.refresh_pose()
				break
			ang += clampf(drop / slope, -0.5, 0.5)
			ch.set_override(limb[0], limb[2], ang)
			ch.refresh_pose()
	var bones := []
	for i in ch.skeleton.get_bone_count():
		bones.append(ch.skeleton.get_bone_name(i))
	var pts := Pose.limb_points(ch, holder, bones, 0)
	if pts.is_empty():  # ilman näyttöä: luista ja varalla 0,1 m
		ch.position.y += 0.1 - _low_bones(ch, holder)
		return {"alin": -1.0}
	var lift := -INF
	for q in pts:
		var g := holder.to_global(q)
		lift = maxf(lift, ground.call(g.x, g.z) + 0.005 - g.y)
	ch.position.y += lift
	ch.refresh_pose()
	var alin := INF
	var selka := -INF
	var torso := Pose.limb_points(ch, holder, ["pelvis", "spine_01", "spine_02", "spine_03"], 1)
	for q in Pose.limb_points(ch, holder, bones, 0):
		var g := holder.to_global(q)
		alin = minf(alin, g.y - ground.call(g.x, g.z))
	var low_t := INF
	for q in torso:
		low_t = minf(low_t, holder.to_global(q).y - ground.call(holder.to_global(q).x, holder.to_global(q).z))
	selka = low_t
	var raajat := {}
	for nm in ["_l", "_r"]:
		raajat["kasi" + nm] = snappedf(_ground_gap(ch, holder, _limb_bones(ch, ["arm", "hand", "thumb", "index", "middle", "ring", "pinky"], nm), ground), 0.001)
		raajat["jalka" + nm] = snappedf(_ground_gap(ch, holder, _limb_bones(ch, ["thigh", "calf", "foot", "ball", "toe"], nm), ground), 0.001)
	raajat["paa"] = snappedf(_ground_gap(ch, holder, ["Head", "neck_01"], ground), 0.001)
	return {"alin": snappedf(alin, 0.001), "selka_alin": snappedf(selka, 0.001), "raajat": raajat}


## Raajan luut: nimessä jokin osista ja loppu suffix ("_l"/"_r"). Solisluu (clavicle) ei kuulu käteen.
static func _limb_bones(ch: Node3D, parts: Array, suffix: String) -> Array:
	var out := []
	for i in ch.skeleton.get_bone_count():
		var bn: String = ch.skeleton.get_bone_name(i)
		if bn.ends_with(suffix) and not bn.begins_with("clavicle") and parts.any(func(p: String) -> bool: return bn.contains(p)):
			out.append(bn)
	return out


## Luiden paistetun verkon (vartalo ja vaatteet) pienin rako maahan (globaali y − ground); INF ilman näyttöä.
static func _ground_gap(ch: Node3D, space: Node3D, bones: Array, ground: Callable) -> float:
	var low := INF
	for q in Pose.limb_points(ch, space, bones, 1):
		var g := space.to_global(q)
		low = minf(low, g.y - ground.call(g.x, g.z))
	return low


static func _low(ch: Node3D, space: Node3D, bones: Array) -> float:
	var low := INF
	for q in Pose.limb_points(ch, space, bones, 1):
		low = minf(low, q.y)
	return low


static func _low_bones(ch: Node3D, space: Node3D) -> float:
	var low := INF
	for i in ch.skeleton.get_bone_count():
		low = minf(low, space.to_local(ch.global_transform * ch.bone_position(ch.skeleton.get_bone_name(i))).y)
	return low


func _spray_maahan() -> void:
	if holder == null:
		return
	var s := build_spray(holder)
	s.rotation = Vector3(PI / 2.0, 0.6, 0)  # kyljellään nurmella
	var lp := Vector3(0.45, 0, 0.75)
	var g := holder.to_global(lp)
	s.global_position = Vector3(g.x, ground_y(holder, g.x, g.z) + SUIHKE_R, g.z)


func _ambulanssi_tulee() -> void:
	tila = "hoito"
	_hoito_ms = Time.get_ticks_msec()
	var p := _ambu_paikka()
	ambu = Node3D.new()
	ambu.name = "Ambulanssi"
	game.world.add_child(ambu)
	ambu.global_position = Vector3(p.x, T.h(p.x, p.z), p.z)
	var to := teini.global_position - ambu.global_position
	ambu.rotation.y = B.yaw_to(-to) if to.length() > 0.1 else 0.0  # takaovet (+Z) poikaa kohti
	tilt_to_ground(ambu)
	_valot = build_ambulance(ambu)
	print("YLIANNOS ensihoitajat: %s" % [place_medics(holder, teini)])
	game._show_message("Ambulanssi kaartaa kaukalon viereen. Ensihoitajat ottavat pojan hoitoonsa.", 4.0)


## Ambulanssille paikka 8–16 m pojasta, 3 m vapaata (fysiikkakysely), mieluiten kaukalosta poispäin.
func _ambu_paikka() -> Vector3:
	var c: Vector3 = teini.global_position
	var space: PhysicsDirectSpaceState3D = holder.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 3.0
	q.shape = sh
	var out := Vector3(1, 0, 0).rotated(Vector3.UP, _ring().rotation.y)
	for dist in [9.0, 12.0, 15.0]:
		for k in 12:
			var dir := out.rotated(Vector3.UP, floori(k / 2.0) * 0.5 * (1.0 if k % 2 == 0 else -1.0))
			var p: Vector3 = c + dir * dist
			p.y = T.h(p.x, p.z)
			q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 3.4, 0))
			if space.intersect_shape(q, 1).is_empty():
				return p
	return c + out * 10.0


func _vilkku() -> void:
	var on := int(Time.get_ticks_msec() / 250.0) % 2 == 0
	for i in _valot.size():
		_valot[i].visible = on == (i % 2 == 0)


func _ambulanssi_lahtee() -> void:
	tila = ""
	var herasi := "naloksoni" in _seuraus
	game._show_message("Ambulanssi lähti. %s" % ("Poika istui jo itse paareilla." if herasi else
		"Ensihoitajat sanoi, että soitto tuli ajoissa."), 4.0)
	poista()


func poista() -> void:
	if holder != null and is_instance_valid(holder):
		holder.queue_free()
	if ambu != null and is_instance_valid(ambu):
		ambu.queue_free()
	holder = null
	teini = null
	ambu = null
	_valot.clear()
	if tila != "":
		tila = ""


func aamu(_at_m: bool) -> String:
	kuorma = 0.0
	_kuorma_t = -1.0
	varoitettu = false
	if tila == "maassa":
		hylatty = true  # jäi ilman apua
	poista()
	if hylatty:
		hylatty = false
		return "Kylällä puhutaan: eilen illalla joku soitti kaukalolta 112. Lyyhistynyt poika selvisi. Se joku et ollut sinä."
	return ""


func riskit() -> Dictionary:
	var k := kuorma_nyt()
	if k <= 0.0 and not naloksoni and not naloksoni_saatu and auttanut == 0 and tapaus_paiva < 0:
		return {}
	var rivit := ["Olo: kuorma %d/%d%s. Laskee ajan myötä." % [roundi(k), roundi(RAJA),
		" (VAROITUS: ei enää mitään)" if k >= VAROITUS else ""],
		"Viina ja lääkkeet yhdessä: kuorma kaksinkertainen."]
	rivit.append("Naloksonisuihke repussa. Jos joku ei herää: soita 112 ja käytä tätä." if naloksoni else
		("Naloksoni käytetty." if naloksoni_saatu else "Naloksonisuihkeen saa kerran Railin luukulta."))
	if auttanut > 0:
		rivit.append("Autoit lyyhistynyttä %d %s." % [auttanut, "kerran" if auttanut == 1 else "kertaa"])
	return {"otsikko": "Olo ja ensiapu", "mittari": clampf(k / RAJA, 0.0, 1.0), "rivit": rivit}


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("rikos_yliannos", "tila", {"naloksoni": 1 if naloksoni else 0, "saatu": 1 if naloksoni_saatu else 0,
		"myynti": myynti_paiva, "tapaus": tapaus_paiva, "hylatty": 1 if hylatty else 0, "auttanut": auttanut,
		"kuorma": roundi(kuorma_nyt())})


func load_from(cfg: ConfigFile) -> void:
	var d := _ints(cfg.get_value("rikos_yliannos", "tila", {}))
	naloksoni = d.get("naloksoni", 0) == 1
	naloksoni_saatu = d.get("saatu", 0) == 1
	myynti_paiva = d.get("myynti", -99)
	tapaus_paiva = d.get("tapaus", -99)
	hylatty = d.get("hylatty", 0) == 1
	auttanut = d.get("auttanut", 0)
	kuorma = float(d.get("kuorma", 0))
	_kuorma_t = _nyt() if kuorma > 0.0 else -1.0
	varoitettu = kuorma >= VAROITUS
	poista()


# --- Mallit (myös tools/testit/yliannos_kuvat.gd) ----------------------------------------------------------------

## Ambulanssi -Z-suuntaan: Vehicles.van keltavihreänä, kyljissä kaksi riviä oransseja ruutuja, takaovissa oranssit
## nuolikuviot, katolla valopaneeli sinisin valoin ja AMBULANSSI-kyltit (B.sign_plate) kyljissä ja takana.
## Palauttaa vilkkuvat valot (parilliset ja parittomat vuorotellen).
static func build_ambulance(parent: Node3D) -> Array:
	Vehicles.van(parent, AMBU_KELTA, "EHO-112", true)  # korotettu katto
	var orange := Vehicles.paint(AMBU_ORANSSI)
	var back: float = Vehicles.HIACE_PERA
	var roof: float = Vehicles.HIACE_KATTO_KORKEA
	# Kylkien ruudutus ohjaamon takaa (B-pilari z -0,76) perään: ruutu 0,3 m, kaksi riviä lomittain. Alarivi on
	# pyöränkaarten (yläreuna 0,71) yllä; ylärivi ulottuu vyölinjan (1,20) yli 7 cm, missä kylki kallistuu vähän:
	# ruutu kallistetaan kyljen mukaan ja nostetaan kyljen pinnalle.
	var tilt: float = atan((Vehicles.HIACE_KYLKI - Vehicles.HIACE_OLKA_X) / (Vehicles.HIACE_OLKA - Vehicles.HIACE_VYO))
	for sx in [-1.0, 1.0]:
		for row in 2:
			var n := 0
			var z := -0.72
			var y := 0.86 + row * 0.29
			while z + 0.3 <= back - 0.06:  # viimeinen ruutu ennen takavalojen kylkiosaa
				if (n + row) % 2 == 0:
					var rz: float = 0.0 if row == 0 else sx * tilt * 0.5
					Vehicles.part(parent, B.boxm(Vector3(0.012, 0.28, 0.28)), Vector3(sx * (Vehicles.hiace_kylki(y) + 0.008), y, z + 0.15),
						orange, Vector3(0, 0, rz))
				z += 0.3
				n += 1
	# Takaluukun nuolikuvio: kolme oranssia ^-kaistaa (kaksi kallistettua liuskaa kukin) luukun pinnalla.
	for k in 3:
		var y := 0.85 + k * 0.32
		for sx in [-1.0, 1.0]:
			Vehicles.part(parent, B.boxm(Vector3(0.6, 0.11, 0.012)), Vector3(sx * 0.36, y, back + 0.012), orange, Vector3(0, 0, -sx * 0.42))
	# Valopaneelit korotetulla katolla: edessä katon tasaisella osalla (kaltevan etuosan takana), takana luukun yllä.
	var dark := Vehicles.plastic()
	Vehicles.part(parent, B.boxm(Vector3(1.0, 0.1, 0.32)), Vector3(0, roof + 0.05, -0.7), dark)
	Vehicles.part(parent, B.boxm(Vector3(0.9, 0.08, 0.2)), Vector3(0, roof + 0.04, 1.9), dark)
	var valot: Array = []
	var blue: StandardMaterial3D = Vehicles.lamp(Color(0.2, 0.45, 1.0)).duplicate()
	blue.emission_energy_multiplier = 2.5
	for p in [Vector3(-0.3, roof + 0.13, -0.7), Vector3(0.3, roof + 0.13, -0.7), Vector3(-0.25, roof + 0.11, 1.9), Vector3(0.25, roof + 0.11, 1.9)]:
		valot.append(Vehicles.part(parent, B.boxm(Vector3(0.36, 0.1, 0.26)), p, blue))
	# AMBULANSSI-kyltit: kylkiin ruudutuksen yläpuolelle kyljen kallistuksen mukaan ja takaluukkuun ikkunan yläpuolelle.
	for sx in [-1.0, 1.0]:
		var s := B.sign_plate(parent, "AMBULANSSI", AMBU_KELTA, Color(0.05, 0.1, 0.3), 0.26, 60, AMBU_ORANSSI)
		s.position = Vector3(sx * (Vehicles.hiace_kylki(1.55) + 0.02), 1.55, 0.75)
		s.basis = Basis(Vector3(0, 0, 1), sx * tilt) * Basis(Vector3.UP, sx * PI / 2.0)
	var r := B.sign_plate(parent, "AMBULANSSI", AMBU_KELTA, Color(0.05, 0.1, 0.3), 0.1, 28, AMBU_ORANSSI)  # kapea: luukun levyinen
	r.position = Vector3(0, 1.87, back + 0.015)
	return valot


## Maan pinta (maaston törmäysverkko, säteellä alas); varalla Terrain.h. Pieni esine asetetaan näkyvän verkon päälle,
## koska Terrain.h ja verkon kolmiot eroavat sentin verran.
static func ground_y(n: Node3D, x: float, z: float) -> float:
	var ss := n.get_world_3d().direct_space_state
	var hit := ss.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, T.h(x, z) + 2.0, z), Vector3(x, T.h(x, z) - 2.0, z),
		T.COLLISION_LAYER))
	return (hit["position"] as Vector3).y if not hit.is_empty() else T.h(x, z)


## Ajoneuvo rinteeseen: kallistus maaston normaalin mukaan (yaw säilyy), pyörät samalle tasolle.
static func tilt_to_ground(n: Node3D) -> void:
	var c := n.global_position
	var e := 1.5
	var nw := Vector3(T.h(c.x - e, c.z) - T.h(c.x + e, c.z), 2.0 * e, T.h(c.x, c.z - e) - T.h(c.x, c.z + e)).normalized()
	n.global_basis = Basis(Quaternion(Vector3.UP, nw)) * Basis(Vector3.UP, n.rotation.y)


## Naloksoni-nenäsuihke (kerta-annos, mittakaava 1 = oikea koko, n. 4,5 cm): painin alhaalla, runko, kaksi sormisiivekettä
## ja kapeneva suutin. Esikuva: kertakäyttöiset naloksoninenäsuihkeet (EMA Nyxoid -sivu), vain muoto.
static func build_spray(parent: Node3D) -> Node3D:
	var s := Node3D.new()
	s.name = "Naloksonisuihke"
	parent.add_child(s)
	var white := Color(0.95, 0.95, 0.93)
	B.mesh(s, B.cyl(0.0125, 0.0125, 0.009, 20), Vector3(0, 0.0045, 0), Color(0.55, 0.57, 0.6))  # painin
	B.mesh(s, B.cyl(0.0122, 0.0122, 0.0015, 20), Vector3(0, 0.0098, 0), Color(0.75, 0.15, 0.12))  # painimen reunarengas
	B.mesh(s, B.cyl(0.0085, 0.0095, 0.014, 18), Vector3(0, 0.0175, 0), white)  # runko
	B.mesh(s, B.boxm(Vector3(0.036, 0.003, 0.011)), Vector3(0, 0.0255, 0), white)  # sormisiivekkeet
	for sx in [-1.0, 1.0]:
		B.mesh(s, B.cyl(0.0055, 0.0055, 0.003, 12), Vector3(sx * 0.018, 0.0255, 0), white)  # pyöristetyt päät
	B.mesh(s, B.cyl(0.0035, 0.006, 0.017, 16), Vector3(0, 0.0355, 0), white)  # suutin
	B.mesh(s, B.cyl(0.0022, 0.0034, 0.003, 12), Vector3(0, 0.0455, 0), Color(0.85, 0.85, 0.83))  # suuttimen kärki
	return s


## Lyyhistynyt teini (Death01) holderiin; asettelu lay_down:lla, kun asento on laskettu (odota ruutu).
static func build_teen(holder: Node3D) -> Node3D:
	var ch := Looks.make(holder, TEINI_LOOK)
	ch.play("Death01", 0.0)
	ch.anim.seek(ch.anim_length("Death01"), true)
	ch.anim.speed_scale = 0.0
	return ch


static func build_medic(parent: Node3D, i: int) -> Node3D:
	var m := Looks.make(parent, ENSIHOITAJA_LOOKS[i])
	m.play("Idle", 0.0)
	return m


## Kaksi ensihoitajaa makaavan teinin (holderin +Z = pää) molemmille puolille: lantion ja rintakehän kohdalle, MEDIC_RAKO
## päähän teinin leveimmästä ihopisteestä sillä kohtaa (paistettu verkko), kasvot teiniin. Maaston korkeudella.
## Palauttaa {"rako": [metriä ihosta hahmon kapselin reunaan]}.
static func place_medics(holder: Node3D, teen: Node3D) -> Dictionary:
	var bones := []
	for i in teen.skeleton.get_bone_count():
		bones.append(teen.skeleton.get_bone_name(i))
	var pts := Pose.limb_points(teen, holder, bones, 0)
	var raot: Array = []
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var z := 0.05 - i * 0.5  # oikealla rintakehän, vasemmalla lantion kohdalla
		var reuna := 0.35
		for q in pts:
			if absf(q.z - z) < MEDIC_R + MEDIC_RAKO:
				reuna = maxf(reuna, q.x * side)
		var m := build_medic(holder, i)
		m.position = Vector3(side * (reuna + MEDIC_RAKO + MEDIC_R), 0, z)
		var g := holder.to_global(m.position)
		m.position.y = T.h(g.x, g.z) - holder.global_position.y
		m.rotation.y = B.yaw_to(Vector3(-side, 0, 0))
		# Rinteessä alamäen jalkaterä painuisi maahan: nosto alimman jalkapohjan pisteen mukaan (paistettu verkko).
		m.refresh_pose()
		var nosto := -INF
		for q in Pose.limb_points(m, holder, ["foot_l", "foot_r", "ball_l", "ball_r"], 1):
			var gq := holder.to_global(q)
			nosto = maxf(nosto, T.h(gq.x, gq.z) + 0.003 - gq.y)
		if nosto > -INF:
			m.position.y += nosto
		raot.append(snappedf(side * m.position.x - MEDIC_R - reuna, 0.01))
	return {"rako": raot}


# --- Testi: aja.sh scene riskit --riski=yliannos ----------------------------------------------------------------

var _vikoja := 0


func _vika(t: String) -> void:
	_vikoja += 1
	print("TESTI VIKA yliannos: " + t)


func _frames(n: int) -> void:
	for i in n:
		await game.get_tree().process_frame


## Odotus sekunteina (ajastimet ovat reaaliaikaisia, ruudut hitaalla koneella harvassa).
func _sek(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await game.get_tree().process_frame


func _kuva(suffix: String) -> void:
	var path := "user://riskit_yliannos%s.png" % suffix
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7).replace(".png", "_yliannos%s.png" % suffix)
	await _frames(3)
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
	print("YLIANNOS kuva " + path)


func _ids(who: String) -> Array:
	game._talk_who = who
	return game._talk_options(who).map(func(o: Dictionary) -> String: return o.id)


func _tila(t: String) -> void:
	print("YLIANNOS %s: tila '%s' maine %.0f naloksoni %s kuorma %.0f seuraus %s ambu %s" % [t, tila, game.maine, naloksoni,
		kuorma_nyt(), _seuraus, ambu != null and is_instance_valid(ambu)])


## Pelaaja jalan pisteeseen p (maan päälle), kasvot kohti look.
func _siirra(p: Vector3, look: Vector3) -> void:
	var w: Node3D = game.player
	w.global_position = Vector3(p.x, T.h(p.x, p.z) + 0.3, p.z)
	var d := look - p
	d.y = 0.0
	if d.length() > 0.1:
		w.rotation.y = B.yaw_to(d)
	await _frames(6)


## Uusi tapaus suoraan (arvonta ohitetaan) ja pelaaja PUHE_R:n sisään.
func _tapaus() -> void:
	poista()
	tapaus_paiva = -99
	aloita()
	await _sek(0.6)
	var f := (holder.global_basis.x * 1.9 - holder.global_basis.z * 0.6)
	await _siirra(teini.global_position + f, teini.global_position)


func testi(_arg: String) -> void:
	if game.player != game.walker_out:
		game._toggle_mount()
	game.maine = 50.0
	game.laake = {}
	naloksoni = false
	naloksoni_saatu = false
	kuorma = 0.0
	_kuorma_t = -1.0
	varoitettu = false
	poista()
	var epa: Object = game.rikos_osa("epaluulo")
	# S2.3 naloksoni Railin luukulta kerran.
	var ids := _ids("apteekki_hoitaja")
	print("YLIANNOS Railin valinnat %s" % [ids])
	if not "yliannos_naloksoni" in ids:
		_vika("naloksonivalinta puuttuu Railin luukulta")
	game._talk_choose("yliannos_naloksoni")
	if not naloksoni or "yliannos_naloksoni" in _ids("apteekki_hoitaja"):
		_vika("naloksoni: repussa %s, valinta yhä tarjolla" % naloksoni)
	game._talk_box.close()
	# Oma olo: kaksi ottoa -> varoitus, aika laskee kuormaa.
	game.tilat.values["humala"] = 0.0
	game.laake = {"opiaatti": 2}
	game._take_laake("opiaatti")
	var k1 := kuorma_nyt()
	game._take_laake("opiaatti")
	var k2 := kuorma_nyt()
	var tv := Time.get_ticks_msec()
	# Ajastin kulkee pelin ajassa: hitaalla xvfb-koneella ruudun delta rajautuu, joten 3,2 s voi kestää kymmeniä sekunteja.
	while not "Olo on outo" in game._msg.text and Time.get_ticks_msec() - tv < 60000:
		await game.get_tree().process_frame
	print("YLIANNOS varoitus %.1f s otosta, puu pysäytetty %s, tila %s" % [(Time.get_ticks_msec() - tv) / 1000.0, game.get_tree().paused, game.state])
	print("YLIANNOS otot: %.0f -> %.0f, varoitettu %s, viesti '%s'" % [k1, k2, varoitettu, game._msg.text])
	if k1 != KUORMA.opiaatti or k2 != 2.0 * KUORMA.opiaatti or not varoitettu or not "Olo on outo" in game._msg.text:
		_vika("kuorma %.0f/%.0f tai varoitus puuttuu" % [k1, k2])
	if game.state == "cutscene":
		_vika("lyyhistyi jo varoitusrajalla")
	game.clock_min += 60.0
	print("YLIANNOS tunnin päästä kuorma %.0f (odotus %.0f)" % [kuorma_nyt(), k2 - 60.0 * LASKU])
	if absf(kuorma_nyt() - (k2 - 60.0 * LASKU)) > 0.5:
		_vika("kuorma ei laske ajan myötä")
	# Humala tuplaa: jatkettu annos (teho 0,5) viinan päälle = 2 × 0,5 × 45.
	game.clock_min -= 60.0
	kuorma = 0.0
	game.tilat.values["humala"] = 0.5 + 0.4  # lääkkeen oma osuus (0,5) + muu humala 0,4
	_otto("opiaatti~1", 0.5)
	print("YLIANNOS humalassa jatkettu: kuorma %.0f (odotus %.0f)" % [kuorma, KUORMA.opiaatti])
	if absf(kuorma - KUORMA.opiaatti) > 0.5:
		_vika("humalakerroin: %.0f" % kuorma)
	game.tilat.values["humala"] = 0.0
	kuorma = 30.0
	_kuorma_t = _nyt()
	var rs: Array = game.journal_data().get("riskit", [])
	print("YLIANNOS riskit %s" % [rs.filter(func(d: Dictionary) -> bool: return d.otsikko == "Olo ja ensiapu")])
	if rs.filter(func(d: Dictionary) -> bool: return d.otsikko == "Olo ja ensiapu").is_empty():
		_vika("Olo ja ensiapu ei näy Riskit-sivulla")
	# Tallennus ja lataus.
	myynti_paiva = game.day
	auttanut = 1
	var ennen := [naloksoni, naloksoni_saatu, myynti_paiva, auttanut, roundi(kuorma_nyt())]
	game._save_game()
	naloksoni = false
	myynti_paiva = -99
	auttanut = 0
	kuorma = 0.0
	game._load_game()
	var jalk := [naloksoni, naloksoni_saatu, myynti_paiva, auttanut, roundi(kuorma_nyt())]
	print("YLIANNOS tallennus %s -> %s" % [ennen, jalk])
	if ennen != jalk:
		_vika("tallennus %s -> %s" % [ennen, jalk])
	auttanut = 0
	kuorma = 0.0
	_kuorma_t = -1.0
	# S2.1 laukaisu: vain myyntiä seuraavana iltana, kaukalon lähellä, enintään kerran VALI päivässä.
	game.clock_min = 21.0 * 60.0
	var r := _ring()
	await _siirra(r.center() + Vector3(1, 0, 0).rotated(Vector3.UP, r.rotation.y) * 12.0, r.center())
	await _frames(10)
	game._talk_who = "kaukalo_teinit"
	game._rikos_event("myynti", {"key": "opiaatti", "paikka": "saloinen"})
	print("YLIANNOS myynti kaukalolla -> myynti_paiva %d (päivä %d), teinit näkyy %s" % [myynti_paiva, game.day, r.visible])
	if myynti_paiva != game.day:
		_vika("kaukalomyyntiä ei kirjattu")
	var sama := _voi_alkaa()
	myynti_paiva = game.day - 1
	tapaus_paiva = game.day - 1
	var liian_pian := _voi_alkaa()
	tapaus_paiva = -99
	var ok := _voi_alkaa()
	print("YLIANNOS laukaisu: samana iltana %s, päivä edellisestä %s, seuraavana iltana %s" % [sama, liian_pian, ok])
	if sama or liian_pian or not ok:
		_vika("laukaisuehto: %s %s %s" % [sama, liian_pian, ok])
	# S2.2 valinta 1: jää auttamaan naloksonilla.
	await _tapaus()
	var tp: Control = game._talk_prompt
	print("YLIANNOS puhevihje näkyy %s, vihjerivi '%s', teinistä %.1f m" % [tp.visible, game._hint.text,
		game.player.global_position.distance_to(teini.global_position)])
	if game._hint.text == "":
		_vika("puhevihje ei tule teinin vieressä")
	await _kuva("_pelikamera")
	game._talk_open("kaukalo_poika", teini)
	await _frames(4)
	ids = _ids("kaukalo_poika")
	print("YLIANNOS valinnat %s, tervehdys '%s'" % [ids, hello("kaukalo_poika").get_slice("\n", 0)])
	if not "yliannos_soita" in ids or not "yliannos_auta" in ids or not "yliannos_haivy" in ids or "juttu" in ids:
		_vika("valinnat %s" % [ids])
	await _kuva("_valinnat")
	var m0: float = game.maine
	game._talk_choose("yliannos_auta")
	_tila("naloksoni")
	if tila != "herasi" or naloksoni or game.maine != m0 + MAINE_NALOKSONI:
		_vika("naloksoni: tila %s maine %+.0f" % [tila, game.maine - m0])
	await _sek(1.8)
	await _kuva("_naloksoni")
	game._talk_box.close()
	game.clock_min += AMBU_MIN + 1.0
	await _sek(0.8)
	_tila("ambulanssi")
	if tila != "hoito" or ambu == null:
		_vika("ambulanssi ei tullut %d minuutissa" % roundi(AMBU_MIN))
	else:
		var to := ambu.global_position - teini.global_position
		print("YLIANNOS ambulanssi %.1f m pojasta" % Vector2(to.x, to.z).length())
		var cam := Camera3D.new()
		game.add_child(cam)
		var c := teini.global_position
		cam.look_at_from_position(c - to.normalized() * 6.0 + Vector3(0, 3.5, 0) + to.cross(Vector3.UP).normalized() * 3.0,
			c + to * 0.5 + Vector3(0, 0.8, 0))
		cam.current = true
		await _kuva("_ambulanssi")
		cam.queue_free()
		if game.player.has_method("activate_camera"):
			game.player.activate_camera()
	_hoito_ms -= int(AMBU_HOITO * 1000.0) + 100
	await _frames(4)
	_tila("lähti")
	if tila != "" or holder != null:
		_vika("ambulanssi ei lähtenyt")
	# Valinta 2: soita 112.
	await _tapaus()
	m0 = game.maine
	game._talk_who = "kaukalo_poika"
	game._talk_choose("yliannos_soita")
	_tila("soitto")
	if tila != "soitettu" or game.maine != m0 + MAINE_SOITTO or absf(ambu_t - _nyt() - AMBU_MIN) > 0.1:
		_vika("soitto: tila %s maine %+.0f" % [tila, game.maine - m0])
	game._talk_box.close()
	# Valinta 2b: jää auttamaan ilman naloksonia (soitto + apu).
	await _tapaus()
	m0 = game.maine
	game._talk_choose("yliannos_auta")
	_tila("auttoi ilman naloksonia")
	if tila != "soitettu" or game.maine != m0 + MAINE_SOITTO + MAINE_AUTTOI or not "auttoi" in _seuraus:
		_vika("apu ilman naloksonia: tila %s maine %+.0f" % [tila, game.maine - m0])
	game._talk_box.close()
	# Valinta 3: häivy -> maine −, epäluulo +30 (epaluulo.gd "hylkasi"), aamulla tieto.
	await _tapaus()
	m0 = game.maine
	var e0: float = epa.epaluulo if epa != null else 0.0
	game._talk_choose("yliannos_haivy")
	var e1: float = epa.epaluulo if epa != null else 0.0
	_tila("häivy")
	print("YLIANNOS epäluulo %.0f -> %.0f" % [e0, e1])
	if tila != "haipyi" or game.maine != m0 - MAINE_HAIPYI or (epa != null and absf(e1 - e0 - 30.0) > 0.1 and e1 < 100.0):
		_vika("häivy: tila %s maine %+.0f epäluulo %+.0f" % [tila, game.maine - m0, e1 - e0])
	var at := aamu(false)
	print("YLIANNOS aamu '%s'" % at)
	if not "selvisi" in at or holder != null:
		_vika("aamu häipymisen jälkeen: '%s'" % at)
	# Kävely pois ilman valintaa = häipyi.
	await _tapaus()
	await _siirra(teini.global_position + Vector3(POIS_R + 10.0, 0, 0), teini.global_position)
	await _frames(4)
	_tila("käveli pois")
	if not "haipyi" in _seuraus or not hylatty or holder != null:
		_vika("pois kävely ei laskenut häipymiseksi (tai teini jäi paikalle)")
	aamu(false)
	if epa != null:
		epa.epaluulo = 0.0
	# Oma yliannos: kuorma rajan yli -> ELVYTETTY.
	game.clock_min = 12.0 * 60.0
	kuorma = 70.0
	_kuorma_t = _nyt()
	varoitettu = true
	game.laake = {"opiaatti": 1}
	game._take_laake("opiaatti")
	_tila("rajan yli")
	var t0 := Time.get_ticks_msec()
	while game.cutscene._title.text == "" and Time.get_ticks_msec() - t0 < 20000:
		await game.get_tree().process_frame
	var seen: String = game.cutscene._title.text
	print("YLIANNOS otsikko '%s' %.1f s, tila %s, kuorma %.0f" % [seen, (Time.get_ticks_msec() - t0) / 1000.0, game.state, kuorma])
	if seen != "ELVYTETTY":
		_vika("oma yliannos: otsikko '%s'" % seen)
	await _kuva("_elvytetty")
	print("YLIANNOS testi valmis, %d vikaa" % _vikoja)
