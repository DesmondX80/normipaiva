extends RefCounted
## Uusien ominaisuuksien traileri "Rasvanappi"-biisin tahtiin (--set=rasvanappi). Suunnitelma: PAPERILEIKKAUS_RASVANAPPI.md.
## Musiikki: assets/music/tanssit/rasvanappi.mp3 (173,3 s, 129,2 bpm). Biisin tempo heittelee, joten jokaisen osan alku on
## ankkuroitu mitattuun iskuun (at, s) ja osan sisällä leikkaukset osuvat tasaiseen ruudukkoon (b = iskuja).
## Kenttien selitys: leikkaus.gd. Toinen käyttö samasta lavastuksesta saa tunnisteeseen jälkiliitteen "__2"
## (Otokset.setup poistaa sen).

const MUSIC := "res://assets/music/tanssit/rasvanappi.mp3"
const BEAT := 60.0 / 129.2
const BEAT0 := 0.21

const SHOTS := [
	# --- Prologi ilman musiikkia: pyörä auton eteen ja kaappaus ("HEI! MUN AUTO!" kuuluu vain kerran), sitten biisi alkaa -------
	{"id": "a_pyora_eteen", "g": "auto0", "s": 2.5},
	{"id": "a_kaappaus", "g": "auto", "s": 3.0},

	# --- 0:00 Intro: kaahaus, takana Päivi ja poliisi, sitten Päivin motkotus pidätyksestä (24 iskua) ---------------------------
	{"id": "a_viisi_tahtea", "g": "auto", "b": 6},
	{"id": "a_jahti_paivi", "g": "auto", "b": 5},
	{"id": "p_motkotus_pidatys", "g": "motkotus3", "b": 13, "in": 2.8, "sfx": 1.7},

	# --- 0:11 "Aseman takana makasiini, punainen lamppu palaa": Saloisten makasiini ja takaoven punainen lamppu --------------
	{"id": "h_makasiini", "g": "mak_ulko", "b": 6, "at": 11.15},
	{"id": "h_lamppu_makasiini", "g": "mak_ulko", "b": 4},

	# --- 0:16 "Mä koputan kolme kertaa" ja 0:19 "viikset kuin Chaplinilla": portsari luukussa --------------------------------
	{"id": "h_makasiini_koputus", "g": "mak_koputus", "b": 7, "at": 15.86, "sfx": 1.0},
	{"id": "h_portsari", "g": "makasiini", "b": 8, "at": 19.06},

	# --- 0:23 "sano sana": apteekin takaovi ---------------------------------------------------------------------------------------
	{"id": "h_takaovi_koputus", "g": "apteekki", "b": 4, "at": 22.78, "sfx": 1.0},
	{"id": "h_luukku", "g": "apteekki", "b": 5},

	# --- 0:27 Kertosäe 1: huumeiden laimennus, diilaus teineille, kuolema mummon keppiin ja Päivin motkotus ------------------
	{"id": "h_klaffipoyta", "g": "klaffi", "b": 6, "at": 26.89},
	{"id": "h_teinit_kaukalo", "g": "kaukalo", "b": 6},
	{"id": "p_mummo", "g": "mummo", "b": 26, "sfx": 1.7},

	# --- 0:44 Säkeistö 2: nimiluettelo (8 tahtia) -------------------------------------------------------------------
	{"id": "h_pekka", "g": "ulko", "b": 4, "at": 44.4, "nimi": "Pekka", "rooli": "Kiroilee."},
	{"id": "h_arto", "g": "ulko", "b": 4, "nimi": "Arto", "rooli": "Hyräilee."},
	{"id": "s_sinikka", "g": "ulko", "b": 4, "nimi": "Sinikka", "rooli": "Kikattaa."},
	{"id": "m_juna_vaalaan", "g": "juna2", "b": 6, "nimi": "Helena", "rooli": "Huokailee."},
	{"id": "t_kota", "g": "ulko", "b": 4, "nimi": "Raimo", "rooli": "Niiskuttaa."},
	{"id": "h_paivi", "g": "ulko", "b": 4, "nimi": "Päivi", "rooli": "Vaimo. Näkee kaiken."},
	{"id": "h_valeostaja", "g": "vaalatori", "b": 4},
	{"id": "h_lamppu_makasiini__2", "g": "mak_ulko", "b": 4},

	# --- 1:00 Kertosäe 2: kolmiomittaus (7 tahtia) -----------------------------------------------------------------
	{"id": "m_joni_esa", "g": "kolmio", "b": 8, "at": 60.02},
	{"id": "m_sytkari", "g": "kolmio_puh", "b": 4},
	{"id": "m_kartta_harppi", "g": "kolmio_kartta", "b": 8},
	{"id": "m_siviikki", "g": "kolmio_vaala", "b": 10},

	# --- 1:14 Silta: lahjat ja ilta (10 tahtia) -------------------------------------------------------------------
	{"id": "m_lahjat_ovella", "g": "kolmio_koti", "b": 8, "at": 73.79},
	{"id": "m_vaara_ovi", "g": "kolmio_koti", "b": 8},
	{"id": "m_ovi_aukeaa", "g": "kolmio_koti", "b": 4},
	{"id": "m_flirtti", "g": "kolmio_koti", "b": 8},
	{"id": "m_ilta_vihje", "g": "kolmio_koti", "b": 4},
	{"id": "m_kortti", "g": "kortit", "b": 4, "kortti": "Ihanaa iltapuuhaa."},
	{"id": "m_puhelu", "g": "kolmio_aamu", "b": 6},

	# --- 1:33 Välisoitto: aamu ja uusi Vaala (12 tahtia) ----------------------------------------------------------
	{"id": "m_aamu", "g": "kolmio_aamu", "b": 8, "at": 93.11},
	{"id": "f_mopo_silta", "g": "vaala", "b": 8, "in": 1.5, "teksti": "VAALA"},
	{"id": "v_ymparyra", "g": "vaala2", "b": 8},
	{"id": "v_satama", "g": "vaala3", "b": 8},
	{"id": "f_lava_tanssi", "g": "lavatanssi", "b": 6, "in": 4.0},
	{"id": "v_retki_rotko", "g": "retki1", "b": 4},
	{"id": "v_retki_karhu", "g": "retki2", "b": 4},

	# --- 1:55 Loppusäkeistö: ELVYTETTY ja Päivin motkotus puheineen (pelin oma välianimaatio) -----------------------------
	{"id": "p_motkotus_huume", "g": "motkotus2", "b": 28, "in": 0.9, "sfx": 1.7, "at": 114.78},
	{"id": "h_lamppu", "g": "apteekki", "b": 7},

	# --- 2:11 Kertosäe 3 ja 4: huipennus (16 tahtia) -----------------------------------------------------------------
	{"id": "a_jahti_roivainen__2", "g": "roivainen", "b": 8, "at": 131.05},
	{"id": "h_ambulanssi", "g": "kaukalo", "b": 12},
	{"id": "f_kiihdytys", "g": "kiihdytys", "b": 4, "in": 2.0},
	{"id": "a_jahti_maali", "g": "auto", "b": 8},
	{"id": "k_rossi", "g": "ulko", "b": 4, "in": 0.3},
	{"id": "k_karaoke", "g": "karaoke", "b": 4, "in": 1.5},
	{"id": "s_kyyti", "g": "kyyti", "b": 4, "in": 4.0},
	{"id": "m_siviikki__2", "g": "kolmio_vaala", "b": 4},
	{"id": "a_poliisi_ilmestyy__2", "g": "auto", "b": 4},
	{"id": "a_jahti_paivi__2", "g": "auto", "b": 4},
	{"id": "f_auringonlasku", "g": "laavu", "b": 6},

	# --- 2:40 Häpp! Häpp! Häpp!: PIDÄTETTY, WASTED, ELVYTETTY ja logo ---------------------------------------------------------
	{"id": "loppu_pidatetty", "g": "kortit", "b": 9, "at": 159.85, "kortti": "PIDÄTETTY", "fade": 0.05, "vari": Color(0.3, 0.5, 1.0)},
	{"id": "loppu_wasted", "g": "kortit", "b": 7, "at": 163.98, "kortti": "WASTED", "fade": 0.05, "vari": Color(0.85, 0.08, 0.08)},
	{"id": "loppu_elvytetty", "g": "kortit", "b": 7, "at": 167.18, "kortti": "ELVYTETTY", "fade": 0.05, "ala": "HUUMEET ON VAARALLISIA. OIKEASTI.",
		"vari": Color(0.95, 0.95, 0.98)},
	{"id": "loppu_logo", "g": "kortit", "at": 170.83, "s": 7.0, "logo": true},
]
