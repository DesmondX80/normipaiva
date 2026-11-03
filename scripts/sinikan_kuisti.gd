extends RefCounted
## Sinikan ovilappu ja kuistin mustikkakori: kun Sinikka on poissa (_sinikka_away: aamulla uimassa, iltapäivällä
## auringossa), ovessa on lappu ja portaalla kori. Mustikat voi jättää koriin; kun Sinikka on käynyt kotona ja pelaaja
## on kaukana, kori on tyhjä ja vadilla odottaa piirakka. Mallit: sinikan_kuisti_mallit.gd, kytkentä: main.gd
## _sinikka_kuisti_logic. Tämä tiedosto on vain tila ja tekstit.

## Lapun tekstit (≤ 140 merkkiä, vaihtoehto päivän mukaan): Oravajärvi, kori ja Sinikan kaksimielisyys.
const LAPPU_AAMU := [
	"Oon Oravajärvellä uimassa, kulta. Jos toit mustikat, jätä ne koriin. Mää tuun kotiin märkänä ja nälkäsenä.",
	"Aamu-uinnilla rannassa. Marjat koriin portaalle, niin mää täytän piirakan... kunhan ensin kuivattelen itteni.",
	"Pulikoimassa Oravajärvellä. Jätä mustikat koriin, mää otan ne vastaan märkänä ja kiitollisena.",
]
const LAPPU_ILTA := [
	"Ottamassa aurinkoa Oravajärven rannalla, joka paikkaa myöten. Mustikat koriin, niin piirakka on kuuma kuin minä.",
	"Rannalla ruskettumassa ilman rantsuja (älä kerro Päiville). Jätä marjat koriin, palkka odottaa portaalla.",
	"Oravajärvellä paistattelemassa. Toitko mustikat? Koriin vaan. Mää lämmitän uunin... ja muutakin.",
]
const KORI_TILAT := ["", "marjat", "piirakka"]

var lappu_luettu := false  # luettu kerran: Sinikka-merkki paperikartan Oravajärvelle (paper_map.gd)
var kori := ""  # "" = tyhjä, "marjat" = mustikat jätetty, "piirakka" = piirakka vadilla noudettavana


## Lapun teksti: aamu = uimassa, muuten auringossa; vaihtoehto päivän mukaan, ettei toistu sanasta sanaan.
static func teksti(aamu: bool, day: int) -> String:
	var t: Array = LAPPU_AAMU if aamu else LAPPU_ILTA
	return t[posmod(day, t.size())]


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("sinikan_kuisti", "luettu", lappu_luettu)
	cfg.set_value("sinikan_kuisti", "kori", kori)


func load_from(cfg: ConfigFile) -> void:
	lappu_luettu = bool(cfg.get_value("sinikan_kuisti", "luettu", false))
	kori = String(cfg.get_value("sinikan_kuisti", "kori", ""))
	if not kori in KORI_TILAT:
		kori = ""
