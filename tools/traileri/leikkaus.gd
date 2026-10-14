extends RefCounted
## Trailerin leikkaus: otokset järjestyksessä, kestot tunnarin tahdissa ja päällystekstit.
## Musiikki: assets/music/normipaiva.mp3 (199,96 s, n. 147,5 bpm, iskut 111,65 s ja 151,96 s). Ennen musiikkia on
## kylmä avaus (pre-otokset sekunteina) ja musiikin jälkeen loppukortti.
##
## Otoksen kentät:
##   id      tunniste (otokset.gd lavastaa)
##   g       ryhmä: saman ryhmän otokset kuvataan yhdellä pelin käynnistyksellä ("kortit" = kortti.tscn, ei peliä)
##   b       kesto iskuina (musiikin aikana) tai s = kesto sekunteina (avaus ja loppu)
##   at      otos alkaa tarkalleen tästä musiikin kohdasta (s); edellinen otos venyy tai lyhenee
##   sfx     pelin äänten voimakkuus miksauksessa (1 = sellaisenaan, oletus 0.55 musiikin aikana, 1 avauksessa)
##   teksti  iso keskitetty teksti kuvan päällä; nimi + rooli = hahmoesittely; puhelin = Puskaradio-pystyvideo
##   kortti  musta kortti tekstillä (g = "kortit"); logo = loppulogo

const FPS := 30
const ASPECT := 2.2  # mustat palkit: kuva-ala 2.2:1
const MUSIC := "res://assets/music/normipaiva.mp3"
const BEAT := 60.0 / 147.5
const BEAT0 := 0.1995  # ensimmäinen isku (s)
const MUSIC_GAIN := 0.9
const SFX_MUSIC := 0.55  # pelin äänet musiikin alla
const SFX_PRE := 1.0

const SHOTS := [
	# --- Kylmä avaus: ei musiikkia, vain pelin äänet -------------------------------------------------------------------
	{"id": "avaus_yo", "g": "ulko", "s": 4.0, "teksti": ""},
	{"id": "avaus_paivi", "g": "ulko", "s": 5.0},
	{"id": "avaus_lappu", "g": "kortit", "s": 5.0, "lappu": [["Huomenta! Mää lähin jo.", Color(0.1, 0.1, 0.25)],
		["Kauppaan:", Color(0.1, 0.1, 0.25)], ["vihreä tamponi", Color(0.1, 0.55, 0.2)], ["punainen maito", Color(0.8, 0.1, 0.1)],
		["sininen ristikkolehti", Color(0.1, 0.25, 0.75)], ["EI KALJAA!!!", Color(0.8, 0.1, 0.1)], ["– Päivi", Color(0.1, 0.1, 0.25)]]},
	{"id": "avaus_kortti", "g": "kortit", "s": 2.5, "kortti": "SALOINEN", "ala": "Raahen kupeessa. Joskus 2000-luvulla."},

	# --- Intro 0–32 s: rauhallinen nousu, paikat esittäytyvät ----------------------------------------------------------
	{"id": "i_ilma", "g": "ulko", "b": 8},
	{"id": "i_koti", "g": "ulko", "b": 8, "teksti": "Järvikuja 1."},
	{"id": "i_talli", "g": "ulko", "b": 8},
	{"id": "i_kylatie", "g": "ulko", "b": 8},
	{"id": "i_kmarket", "g": "ulko", "b": 8},
	{"id": "i_kassa", "g": "kauppa", "b": 8},
	{"id": "i_kuutonen", "g": "ulko", "b": 8},
	{"id": "i_hyundai", "g": "ulko", "b": 8, "teksti": "Jokainen päivä on normipäivä."},
	{"id": "i_pekka", "g": "ulko", "b": 8},

	# --- Säkeistö 32–78 s: tarina "Paapeliin pääsee, kunhan…" ----------------------------------------------------------
	{"id": "t_kortti", "g": "kortit", "b": 8, "kortti": "PAAPELIIN PÄÄSEE,", "ala": "kunhan…"},
	{"id": "t_jemma", "g": "ulko", "b": 8},
	{"id": "t_arto", "g": "ulko", "b": 8},
	{"id": "t_sienet", "g": "ulko", "b": 8},
	{"id": "t_puolukka", "g": "ulko", "b": 8},
	{"id": "t_nurmikko", "g": "ulko", "b": 8},
	{"id": "t_paivi_nakee", "g": "ulko", "b": 8},
	{"id": "t_kota", "g": "ulko", "b": 8},
	{"id": "t_lintutorni", "g": "ulko", "b": 8},
	{"id": "t_volvo", "g": "ulko", "b": 8},
	{"id": "t_avaimet", "g": "ulko", "b": 8},
	{"id": "t_kyyti", "g": "ulko", "b": 8, "teksti": "Paapeliin."},
	{"id": "t_mokki_saapuu", "g": "mokki", "b": 8},
	{"id": "t_taksi", "g": "ulko", "b": 8},
	{"id": "t_paapeli", "g": "mokki", "b": 8},

	# --- Nousu 78–98 s: sivutehtävät nopeassa tahdissa -----------------------------------------------------------------
	{"id": "v_pojat", "g": "ulko", "b": 4, "at": 78.04},
	{"id": "v_pallo", "g": "ulko", "b": 4},
	{"id": "v_mummot", "g": "ulko", "b": 4},
	{"id": "v_lista", "g": "kauppa", "b": 4},
	{"id": "v_vaino", "g": "ulko", "b": 4},
	{"id": "v_koira", "g": "ulko", "b": 4},
	{"id": "v_sulo", "g": "ulko", "b": 4},
	{"id": "v_sahkopyora", "g": "talli", "b": 4},
	{"id": "v_mopo_potku", "g": "potku", "b": 4},
	{"id": "v_seppo", "g": "ulko", "b": 4},
	{"id": "v_korjaamo", "g": "ulko", "b": 4},
	{"id": "v_miisu", "g": "ulko", "b": 4},

	# --- Tauko 98–111,6 s: hahmoesittelyt -------------------------------------------------------------------------------
	{"id": "h_paivi", "g": "ulko", "b": 6, "at": 98.0, "nimi": "Päivi", "rooli": "Vaimo. Näkee kaiken."},
	{"id": "h_pekka", "g": "ulko", "b": 6, "nimi": "Pekka", "rooli": "Naapuri. 14 kyyhkyä."},
	{"id": "h_arto", "g": "ulko", "b": 6, "nimi": "Arto", "rooli": "Lähekkö puolukkaan?"},
	{"id": "h_juntti", "g": "ulko", "b": 6, "nimi": "Juntti", "rooli": "Raahen karateklubin perustaja."},
	{"id": "h_annaliisa", "g": "ulko", "b": 5, "nimi": "Anna-Liisa", "rooli": "Kuulee kaiken aidan takaa."},
	{"id": "h_musta", "g": "kortit", "b": 3, "kortti": ""},

	# --- Kertosäe 111,6–140 s: iso montaasi -----------------------------------------------------------------------------
	{"id": "k_kulma", "g": "raahe", "b": 4, "at": 111.646},
	{"id": "k_vaanto", "g": "raahe", "b": 4},
	{"id": "k_karaoke", "g": "karaoke", "b": 4},
	{"id": "k_huutokauppa", "g": "kirppis", "b": 4},
	{"id": "k_nuija", "g": "kirppis", "b": 4},
	{"id": "k_piirakka", "g": "reippari", "b": 4},
	{"id": "k_piirakka2", "g": "reippari", "b": 4},
	{"id": "p_mummot", "g": "ulko", "b": 6, "puhelin": {"ryhma": "Saloisten Puskaradio", "nimi": "Raija K.",
		"teksti": "Taas yks pyöräilijä kaahas penkin ohi. Mummot hoiti homman 👏", "tyk": 214}},
	{"id": "k_keinu", "g": "leikki", "b": 4},
	{"id": "k_rossi", "g": "ulko", "b": 4},
	{"id": "k_laavu", "g": "ulko", "b": 4},
	{"id": "p_vaino", "g": "ulko", "b": 6, "puhelin": {"ryhma": "Saloisten Puskaradio", "nimi": "Sinikka H.",
		"teksti": "Onko kukaan nähny Pekan Väinöä?? Juoksi just Järvikujaa pitkin.", "tyk": 87}},
	{"id": "k_uimaranta", "g": "ulko", "b": 4},
	{"id": "k_juntti", "g": "tappelu", "b": 4},
	{"id": "p_siili", "g": "ulko", "b": 6, "puhelin": {"ryhma": "Saloisten Puskaradio", "nimi": "Anna-Liisa",
		"teksti": "POLIISI Järvikujalla. Siili ja ruohonleikkuri. En sano enempää.", "tyk": 403}},

	# --- Silta 140–152 s: Mökki ja Vaala --------------------------------------------------------------------------------
	{"id": "m_kortti", "g": "kortit", "b": 6, "at": 140.0, "kortti": "VAALA", "ala": "Mökki Neittävällä. Oulujärvi."},
	{"id": "m_juna", "g": "juna", "b": 6},
	{"id": "m_laituri", "g": "mokki", "b": 6},
	{"id": "m_kala", "g": "kala", "b": 6},
	{"id": "m_sauna", "g": "mokki", "b": 5},

	# --- Loppukertosäe 152–197,6 s: Vaala ja kliimaksi -----------------------------------------------------------------
	{"id": "f_lava", "g": "vaala", "b": 4, "at": 151.955},
	{"id": "f_siitari", "g": "siitari", "b": 4},
	{"id": "f_kiihdytys", "g": "kiihdytys", "b": 4},
	{"id": "f_mopo_silta", "g": "vaala", "b": 4},
	{"id": "f_uinti", "g": "uinti", "b": 4},
	{"id": "f_pingis", "g": "pingis", "b": 4},
	{"id": "f_jahti", "g": "jahti", "b": 4},
	{"id": "f_nuoret", "g": "vaala", "b": 4},
	{"id": "f_hyundai", "g": "ulko", "b": 4},
	{"id": "f_hyundai2", "g": "ulko", "b": 4},
	{"id": "f_poliisi", "g": "ulko", "b": 4},
	{"id": "f_traktori", "g": "ulko", "b": 4},
	{"id": "f_tappelu", "g": "tappelu", "b": 4},
	{"id": "f_sahkopyora_ajo", "g": "ulko", "b": 4},
	{"id": "f_mopo_ajo", "g": "ulko", "b": 4},
	{"id": "f_lava_tanssi", "g": "lavatanssi", "b": 4},
	{"id": "f_karaoke", "g": "karaoke", "b": 4},
	{"id": "f_drooni", "g": "ulko", "b": 4},
	{"id": "f_kaitasaari", "g": "ulko", "b": 4},
	{"id": "f_kaatuminen", "g": "ulko", "b": 4},
	{"id": "f_wasted", "g": "wasted", "b": 8},
	{"id": "f_auringonlasku", "g": "laavu", "b": 8},
	{"id": "f_nuotio", "g": "makkara", "b": 8},
	{"id": "f_kalja", "g": "makkara", "b": 6},

	# --- Loppu: logo ------------------------------------------------------------------------------------------------
	{"id": "loppu_logo", "g": "kortit", "at": 197.65, "s": 7.0, "logo": true},
]

## Kuvauspaikkojen kierros (--set=kierros): visuaaliset setit pitkinä ottoina (s sekuntia), kuusi kuvaa kustakin.
## Ei kuulu traileriin: pohjaa uudelle paperileikkaukselle. Samat id:t kuin trailerissa käyttävät samaa lavastusta.
const KIERROS := [
	# Välianimaatiot
	{"id": "f_uinti", "g": "k_uinti", "s": 24.0},
	{"id": "s_sauna", "g": "k_sauna", "s": 16.0},
	{"id": "f_nuotio", "g": "k_makkara", "s": 18.0},
	{"id": "f_auringonlasku", "g": "k_laavu", "s": 10.0},
	{"id": "s_kyyti", "g": "k_kyyti", "s": 20.0},
	{"id": "m_juna", "g": "k_juna", "s": 30.0},
	{"id": "s_taksi", "g": "k_taksi", "s": 14.0},
	{"id": "s_mokkibileet", "g": "k_mokkibileet", "s": 16.0},
	{"id": "s_viinibileet", "g": "k_viinibileet", "s": 14.0},
	{"id": "s_paivi_tv", "g": "k_tv", "s": 12.0},
	{"id": "f_wasted", "g": "k_wasted", "s": 7.0},
	# Minipelit
	{"id": "f_pingis", "g": "k_pingis", "s": 10.0},
	{"id": "k_juntti", "g": "k_tappelu", "s": 10.0},
	{"id": "f_lava_tanssi", "g": "k_lavatanssi", "s": 10.0},
	{"id": "m_kala", "g": "k_kala", "s": 14.0},
	{"id": "f_jahti", "g": "k_jahti", "s": 10.0},
	{"id": "k_keinu", "g": "k_keinu", "s": 8.0},
	{"id": "k_piirakka", "g": "k_piirakka", "s": 8.0},
	{"id": "k_huutokauppa", "g": "k_huutokauppa", "s": 10.0},
	{"id": "k_vaanto", "g": "k_vaanto", "s": 8.0},
	{"id": "f_kiihdytys", "g": "k_kiihdytys", "s": 10.0},
	{"id": "s_halot", "g": "k_halot", "s": 10.0},
	{"id": "s_drooni", "g": "k_drooni", "s": 12.0},
	{"id": "v_mopo_potku", "g": "k_potku", "s": 9.0},
	# Pelimaailman hetket (samassa pelissä)
	{"id": "s_aarnivalkea", "g": "k_ulko", "s": 8.0},
	{"id": "k_rossi", "g": "k_ulko", "s": 8.0},
	{"id": "s_sinikka", "g": "k_ulko", "s": 8.0},
	{"id": "f_hyundai2", "g": "k_ulko", "s": 8.0},
	{"id": "f_poliisi", "g": "k_ulko", "s": 8.0},
	{"id": "v_mummot", "g": "k_ulko", "s": 8.0},
	{"id": "f_drooni", "g": "k_ulko", "s": 8.0},
	{"id": "f_mopo_silta", "g": "k_vaala", "s": 8.0},
]
const KIERROS_SNAPS := 6


## Kierros (--set=kierros / --trailer-set=kierros komentorivillä)?
static func kierros() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "--set=kierros" or a == "--trailer-set=kierros":
			return true
	return false


static var _timeline: Array = []


## Koko aikajana: [{id, start (ruutu), frames, music_from (ruutu, josta musiikin kohta 0 alkaa)}...]
static func timeline() -> Array:
	if not _timeline.is_empty():
		return _timeline
	var pre := 0.0
	for s in SHOTS:
		if s.has("b") or s.has("at"):
			break
		pre += s.s
	var music_start := roundi(pre * FPS)
	var t := 0.0  # aika videossa (s)
	var bounds := []  # [alku, loppu] sekunteina
	for i in SHOTS.size():
		var s: Dictionary = SHOTS[i]
		if s.has("at"):
			t = pre + s.at
			if i > 0:
				bounds[i - 1][1] = t
		var length: float = s.b * BEAT if s.has("b") else s.s
		var end := t + length
		if s.has("b"):  # leikkaus osuu iskuun
			var song := end - pre
			end = pre + BEAT0 + roundf((song - BEAT0) / BEAT) * BEAT
		bounds.append([t, end])
		t = end
	for i in SHOTS.size():
		var a := roundi(bounds[i][0] * FPS)
		var e := roundi(bounds[i][1] * FPS)
		_timeline.append({"id": SHOTS[i].id, "start": a, "frames": e - a, "music_from": music_start})
	return _timeline


static func shot(id: String) -> Dictionary:
	for s in (KIERROS if kierros() else SHOTS):
		if s.id == id:
			return s
	return {}


static func frames_of(id: String) -> int:
	if kierros():
		return roundi(float(shot(id).get("s", 8.0)) * FPS)
	for e in timeline():
		if e.id == id:
			return e.frames
	return 0


static func groups() -> Dictionary:
	var g := {}
	for s in (KIERROS if kierros() else SHOTS):
		if not g.has(s.g):
			g[s.g] = []
		g[s.g].append(s.id)
	return g
