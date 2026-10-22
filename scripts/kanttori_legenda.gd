extends RefCounted
## Legenda: Kanttorilan yösävel (#144). Kanttorila on OSM-rakennus kylän länsiosassa (kanttorin vanha talo); sen historiaa
## ei löytynyt hausta (Saloisten seurakunta perustettiin 1912 ja nykyinen kirkko valmistui 1932), joten kaikki talosta
## kerrottu on keksittyä. Legenda (pelissä totta): vanha kanttori sävelsi Saloisille oman virren, mutta nuotit katosivat
## hänen kuollessaan; siitä asti talosta kuuluu öisin urkujen säveliä, vaikka talossa ei ole urkuja. Ketju: Hilkka tai
## Sinikka kertoo (heard) -> yöllä pihalla ensin teinien kaiutin ja sitten oikea sävel (teinit, savel) -> seuranmäen
## huutokaupan harmooni ja sen palkeesta nuottiarkki (harmooni) -> toinen puolikas Pirtin arkistosta (arkisto) -> nuotit
## Sinikan kuorolle (kuoro: virsi lauletaan, yösävel vaikenee) tai Veksille (kerailija: yösävel jatkuu, Sinikka ei anna
## anteeksi). Sävelet syntetisoidaan koodissa (urkuääni, kaiutin, kuoro).

const NIGHT := Vector2(22 * 60, 4 * 60)
const RATE := 22050
const KERAILIJA_HINTA := 150.0
const KERAILIJA_MAINE := 5.0
const KUORO_MAINE := 12.0
## Yösävel: [puolisävel A3:sta, kesto (s)].
const TUNE := [[0, 0.5], [3, 0.5], [7, 0.5], [5, 0.5], [3, 0.5], [2, 0.5], [0, 1.0],
	[7, 0.5], [10, 0.5], [8, 0.5], [7, 0.5], [5, 0.5], [3, 0.5], [2, 1.0],
	[0, 0.5], [3, 0.5], [7, 0.5], [12, 0.5], [10, 0.5], [7, 0.5], [3, 0.5],
	[5, 0.5], [2, 0.5], [3, 0.5], [0, 2.0]]

var heard := false
var teinit := false  # teinien kaiutin kuultu
var savel := false  # oikea yösävel kuultu
var harmooni := false  # nuottiarkin ensimmäinen puolikas (huutokauppa)
var arkisto := false  # toinen puolikas (Pirtti)
var choice := ""  # "" / "kuoro" / "kerailija"


func nuotit() -> bool:
	return harmooni and arkisto


func proven() -> bool:
	return choice == "kuoro"


func silent() -> bool:
	return choice == "kuoro"


func save_to(cfg: ConfigFile) -> void:
	for k in ["heard", "teinit", "savel", "harmooni", "arkisto", "choice"]:
		cfg.set_value("kanttori", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["heard", "teinit", "savel", "harmooni", "arkisto"]:
		set(k, cfg.get_value("kanttori", k, false))
	choice = cfg.get_value("kanttori", "choice", "")


## Sävel PCM-äänenä. kind: "urut" (lämmin, harmoniset 1–4 ja hidas vavahdus), "kaiutin" (kimeä neliöaalto, kapea kaista)
## tai "kuoro" (urut + yläkolmas ja oktaavi, leveämpi vibrato). Hitaasti sisään ja ulos soinnin vaihtuessa.
static func tune(kind: String) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	var phase := 0.0
	for n in TUNE:
		var hz: float = 220.0 * pow(2.0, float(n[0]) / 12.0)
		var len := int(float(n[1]) * RATE)
		for i in len:
			var t := float(i) / RATE
			var env := minf(1.0, t * 14.0) * minf(1.0, (float(n[1]) - t) * 9.0 + 0.2)
			var v := 0.0
			match kind:
				"kaiutin":
					phase += hz * 2.0 / RATE
					v = (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) * 0.22 * env
					v += sin(phase * TAU * 0.5) * 0.05 * env
				"kuoro":
					var vib := 1.0 + sin(t * 5.5) * 0.006
					phase += hz * vib / RATE
					v = (sin(phase * TAU) + 0.5 * sin(phase * TAU * 2.0) + 0.3 * sin(phase * TAU * 1.26) + 0.25 * sin(phase * TAU * 3.0)) * 0.18 * env
				_:
					var vib := 1.0 + sin(t * 4.0) * 0.002
					phase += hz * vib / RATE
					v = (sin(phase * TAU) + 0.6 * sin(phase * TAU * 2.0) + 0.35 * sin(phase * TAU * 3.0) + 0.2 * sin(phase * TAU * 4.0)) * 0.2 * env
			var s := int(clampf(v, -1.0, 1.0) * 30000.0)
			pcm.append(s & 0xFF)
			pcm.append((s >> 8) & 0xFF)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = pcm
	return st
