extends RefCounted
## Pieneläintuhkaamo Lemmikki Enkelit (#148, OSM office=company px (227, 319)). Rauhallinen paikka: siisti piha, pieni
## muistolehto penkkeineen, kynttilälyhtyineen ja lemmikkien nimikylttineen. Sävy lämmin ja kunnioittava: huumori tulee
## ympäriltä, ei lemmikkien menetyksestä. Sivutehtävä: jalkapallopoikien pikkuveljen hamsteri Pörrö on kuollut; pojat
## kertovat (kerrottu), pelaaja maalaa muistokyltin lehtoon (valmis, muistokyltti_game.gd) ja pojat lopettavat kivien
## heittelyn pysyvästi. Pekan ja Väinön hetki: Pekka käy illalla portilla "vaan kattomassa" ja pelkää vanhan koiransa
## puolesta (pekka). Penkillä stressi laskee hiljaa (kerran päivässä); kaljaa ei avata.

const NAMES := ["Misu", "Rekku", "Nalle", "Pörrö"]
const PEKKA_AIKA := Vector2(16 * 60, 19 * 60)

var stage := ""  # "" / "kerrottu" / "valmis"
var pekka := false  # Pekan hetki nähty
var penkki_day := -1


func valmis() -> bool:
	return stage == "valmis"


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("lemmikki", "stage", stage)
	cfg.set_value("lemmikki", "pekka", pekka)
	cfg.set_value("lemmikki", "penkki_day", penkki_day)


func load_from(cfg: ConfigFile) -> void:
	stage = cfg.get_value("lemmikki", "stage", "")
	pekka = cfg.get_value("lemmikki", "pekka", false)
	penkki_day = cfg.get_value("lemmikki", "penkki_day", -1)
