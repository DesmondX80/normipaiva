extends RefCounted
## Iskelmät ja lavamusiikki vanhoilta 78 kierroksen levyiltä (Kansalliskirjaston Raita-kokoelma, Public Domain,
## https://www.doria.fi/handle/10024/66373): Päivin vanhan puhelimen soittolista (phone.gd) sekä lavabändin
## ohjelmisto ja toivekappaleet Oulujärven lavalla (humppa_band.gd, lava_game.gd). Tiedostot on uudelleenkoodattu
## (mono, MP3 80 kbps, hiljaiset alut pois). bpm on tanssin ja bändin tahti (iskua/min), arvioitu äänitteestä; nopeista
## valsseista ja jenkoista se on puolet iskuista, jotta tahtiin ehtii askeltaa.
## Kansioon voi pudottaa lisää biisejä (esim. Eräät Jormat Suno-soittolistalta): ne soivat puhelimessa.

const DIR := "res://assets/music/iskelma"
const SONGS := [
	{"file": "01_Sakkijarven_polkka", "title": "Säkkijärven polkka", "artist": "Willy Larsen", "year": 1928, "bpm": 128.0, "doria": 66409},
	{"file": "02_Orpopojan_valssi", "title": "Orpopojan valssi", "artist": "J. Alfred Tanner", "year": 1926, "bpm": 104.0, "doria": 66566},
	{"file": "03_Kulkurin_valssi", "title": "Kulkurin valssi", "artist": "J. Alfred Tanner", "year": 1926, "bpm": 107.0, "doria": 66483},
	{"file": "04_Juhannusvalssi", "title": "Juhannusvalssi", "artist": "Nils ja Wilhelm Ekman", "year": 1929, "bpm": 154.0, "doria": 66554},
	{"file": "05_Lappeenrannan_rakuuna", "title": "Lappeenrannan rakuuna", "artist": "Matti Söderlund", "year": 1928, "bpm": 132.0, "doria": 66429},
	{"file": "06_Tanssit_Tarvaisen_torpassa", "title": "Tanssit Tarvaisen torpassa", "artist": "Kuuno Sevander", "year": 1929, "bpm": 86.0, "doria": 66552},
	{"file": "07_Kylan_jenkka", "title": "Kylän jenkka", "artist": "Nils ja Wilhelm Ekman", "year": 1929, "bpm": 79.0, "doria": 66427},
	{"file": "08_Immu-polkka", "title": "Immu-polkka", "artist": "Nils ja Wilhelm Ekman", "year": 1929, "bpm": 125.0, "doria": 66572},
	{"file": "09_Paaskysvalssi", "title": "Pääskysvalssi", "artist": "Viola Turpeinen ja John Rosendahl", "year": 1928, "bpm": 148.0, "doria": 66490},
	{"file": "10_Muistoja_Karpaateilta", "title": "Muistoja Karpaateilta", "artist": "Willy Larsen trio", "year": 1930, "bpm": 91.0, "doria": 66563},
]


static func path(song: Dictionary) -> String:
	for ext in ["mp3", "ogg"]:
		var p := DIR.path_join("%s.%s" % [song.file, ext])
		if ResourceLoader.exists(p):
			return p
	return ""


## Iskelmät, joiden tiedosto löytyy (kopiot, joissa "path").
static func available() -> Array:
	var out := []
	for sg in SONGS:
		var p := path(sg)
		if p != "":
			var d: Dictionary = sg.duplicate()
			d.path = p
			out.append(d)
	return out


## Äänite kertasoittona (ei silmukkaa): bändi ja puhelin vaihtavat biisiä sen loputtua.
static func stream(p: String) -> AudioStream:
	var st: AudioStream = load(p).duplicate()
	if st is AudioStreamMP3 or st is AudioStreamOggVorbis:
		st.loop = false
	elif st is AudioStreamWAV:
		st.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return st


## Puhelimen soittolista: iskelmät ja kansioon lisätyt biisit (vientipaketissa .import/.remap-päätteisinä).
static func playlist() -> Array[String]:
	var out: Array[String] = []
	for sg in available():
		out.append(sg.path)
	var d := DirAccess.open(DIR)
	if d != null:
		for f in d.get_files():
			var name := f.trim_suffix(".import").trim_suffix(".remap")
			var p := DIR.path_join(name)
			if name.get_extension().to_lower() in ["ogg", "mp3", "wav"] and not p in out and ResourceLoader.exists(p):
				out.append(p)
	return out


## Näytettävä nimi: "Säkkijärven polkka – Willy Larsen (1928)", lisätyistä tiedostonimestä ilman alkunumeroa.
static func title(p: String) -> String:
	var base := p.get_file().get_basename()
	for sg in SONGS:
		if sg.file == base:
			return "%s – %s (%d)" % [sg.title, sg.artist, sg.year]
	return RegEx.create_from_string(r"^\d+\s*[-.]?\s*").sub(base.replace("_", " ").strip_edges(), "")
