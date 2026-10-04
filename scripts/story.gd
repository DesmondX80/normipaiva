extends RefCounted
## Tarina "Paapeliin pääsee, kunhan…" (main.gd _story_*): ohjaa Saloisissa naapurilta toiselle, mutta kaikki muu
## pysyy vapaana. Vaiheet (step):
##   kaljat        – kuutonen kotijemmaan (mikä tahansa kotipiilo)
##   pekka_kutsuu  – Pekka huikkaa pihalta; juttelu antaa kolme tehtävää
##   tehtavat      – vapaassa järjestyksessä: 3 l sieniä Pekalle, 5 l puolukoita Artolle, Sinikan nurmikko salaa
##   pekka_avaimet – kaikki tehty, Pekka huikkaa taas: autonavaimet hukassa
##   avaimet       – avaimet ovat kodalla lintutornin juurella (Pekka oli siellä kännissä "kyyhkyjahdissa")
##   avaimet_mukana – avaimet löytyneet, vie ne Pekalle
##   valmis        – Pekan kyyti Paapeliin auki (välietappi: tarina jatkuu myöhemmin)
## Tehtävälista näkyy repussa (I) sitä mukaa kuin tehtäviä löytyy. Tallentuu osioon [tarina].

const SIENET_L := 3
const PUOLUKAT_L := 5
const STEPS := ["kaljat", "pekka_kutsuu", "tehtavat", "pekka_avaimet", "avaimet", "avaimet_mukana", "valmis"]

const PEKKA_CALL := "Pekka huikkaa pihalta: \"Hei naapuri! Tuuppa käymään, mulla ois asiaa, perkele!\""
const PEKKA_TASKS := [
	"Perkele, mää lähtisin Paapeliin vaikka heti, mutta ei ehitä vielä.",
	"Ne saatanan sienet pitäs poimia ensin. Kolme litraa! Arto tietää paikat, kysy siltä.",
	"Ja Arto kyseli puolukoita hilloon, viis litraa. Ja Sinikan nurmikko pitäs leikata... niin ettei Päivi nää, ymmärräthän.",
]
const PEKKA_WAITING := [
	"Ei ehitä lähteä, ku sienet on poimimatta. Arto tietää paikat.",
	"Perkele, ensin hommat ja sitte Paapeliin.",
	"Kato listaa, mitä vielä puuttuu. Sitte lähetään.",
]
const PEKKA_KEYS := [
	"No niin, kaikki valmista! Lähetään... missä saatanan avaimet on?!",
	"Kävin eilen lintutornilla kaverin kyydillä. Olin niin kännissä, että ammuin kaikenlaisia lintuja, luvallisia ja luvattomia.",
	"En osunu yhtään, ku oli niin jutuissa. Avaimet jäi varmaan kodalle. Käyppä hakemassa, ite en pääse ilman autoa!",
]
const PEKKA_THANKS := "Avaimet! Perkele, kiitti! Nyt ku haluat Paapeliin, niin hyppää kyytiin."

var step := "kaljat"
var done := {"sienet": false, "puolukat": false, "nurmikko": false}


func at_least(s: String) -> bool:
	return STEPS.find(step) >= STEPS.find(s)


func ride_unlocked() -> bool:
	return step == "valmis"


func all_tasks_done() -> bool:
	return done.sienet and done.puolukat and done.nurmikko


## Repun tehtävälista: [teksti, valmis]. Näkyy vain sitä mukaa kuin tehtäviä löytyy.
func list() -> Array:
	var out := []
	out.append(["Kuutonen kotijemmaan", at_least("pekka_kutsuu")])
	if step == "pekka_kutsuu":
		out.append(["Käy Pekan luona", false])
	if at_least("tehtavat"):
		out.append(["%d l sieniä Pekalle (Arto tietää paikat)" % SIENET_L, done.sienet])
		out.append(["%d l puolukoita Artolle" % PUOLUKAT_L, done.puolukat])
		out.append(["Sinikan nurmikko, ettei Päivi nää", done.nurmikko])
	if step == "pekka_avaimet":
		out.append(["Käy Pekan luona", false])
	if at_least("avaimet"):
		out.append(["Pekan autonavaimet kodalta", at_least("avaimet_mukana")])
		out.append(["Avaimet Pekalle", at_least("valmis")])
	if step == "valmis":
		out.append(["Pekan kyydillä Paapeliin", false])
	return out


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("tarina", "vaihe", step)
	cfg.set_value("tarina", "tehty", done)


func load_from(cfg: ConfigFile) -> void:
	var s: String = cfg.get_value("tarina", "vaihe", "kaljat")
	step = s if s in STEPS else "kaljat"
	var d: Dictionary = cfg.get_value("tarina", "tehty", {})
	for k in done:
		done[k] = d.get(k, false)
