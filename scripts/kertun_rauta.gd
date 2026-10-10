extends RefCounted
## Legenda: Kertunkankaan rauta (#122). Kertunkankaan kehäröykkiöiden (oikea muinaisjäännös, mahdollinen
## rautakautinen kalmisto) väki osasi kodan Raimon mukaan tehdä rautaa suomalmista jo ennen kuin Raahessa oli mitään,
## ja viimeinen seppä kätki takomansa kirveen kankaalle "ettei kukaan muu saa". Kylällä juttua pidetään kodan miesten
## kalja-ajatteluna. Pelissä legenda on totta:
## Raimo ja Veikko kertovat (heard) -> opastaulun pohjakartassa merkitsemätön kivi (taulu) -> drooni näkee sammaleen
## alla suoran kivirivin (spotted, merkki karttaan) -> suon ruosteveden suomalmi (malmi) Aarolle, joka tunnistaa sen
## ja tietää kuonasta (malmi_known) -> kuona pajakiven juurelta (kuona) -> kirves rivin päässä isokiven alta (found)
## -> valinta: Saloisten Pirttiin (todistus, maine) tai kirppiksen takahuoneen Veksille (rahaa, poliisi, ei todistusta).
## Itse röykkiöihin ei kosketa. Pelin kirves ja legenda ovat keksittyjä; opastaulun tiedot ovat oikeita.

## Paikat karttapikseleinä (Kertunkangas M.KERTUNKANGAS, opastaulu M.KERTUN_TAULU).
const RIVI_A := Vector2(1329, -346)  # kivirivin alkupää röykkiöiden luoteispuolella
const RIVI_B := Vector2(1312, -365)  # rivin loppupää
const ISOKIVI := Vector2(1309.5, -368.5)  # isokivi rivin päässä, kirves sen alla
const PAJAKIVI := Vector2(1320, -340)  # litteä pajakivi, kuonaa juurella
const MALMI := Vector2(1330, -397)  # ruosteenpunainen vesi suolla (map_osm BOGS)
const KERAILIJA_HINTA := 150.0
const MUSEO_PALKKIO := 40.0
const MUSEO_MAINE := 12.0

var heard := false
var taulu := false  # opastaulun pohjakartan merkitsemätön kivi huomattu
var spotted := false
var malmi := false  # suomalmin pala mukana
var malmi_known := false  # Aaro tunnisti malmin
var kuona := false
var found := false
var choice := ""  # "" / "museo" / "kerailija"
var kiitetty := false  # Raimo ja Veikko juhlivat todistusta kodalla (Veikon kaljat)
var poliisi := false  # Veksin kaupoista poliisi lähtenyt perään
var cairn_tries := 0  # yritykset kaivaa röykkiötä (toinen tuo poliisin)


## Legenda todistettu kylälle: kirves museossa.
func proven() -> bool:
	return choice == "museo"


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("kertun_rauta", "kuultu", heard)
	cfg.set_value("kertun_rauta", "taulu", taulu)
	cfg.set_value("kertun_rauta", "nahty", spotted)
	cfg.set_value("kertun_rauta", "malmi", malmi)
	cfg.set_value("kertun_rauta", "malmi_tunnettu", malmi_known)
	cfg.set_value("kertun_rauta", "kuona", kuona)
	cfg.set_value("kertun_rauta", "loytynyt", found)
	cfg.set_value("kertun_rauta", "valinta", choice)
	cfg.set_value("kertun_rauta", "kiitetty", kiitetty)
	cfg.set_value("kertun_rauta", "poliisi", poliisi)


func load_from(cfg: ConfigFile) -> void:
	heard = cfg.get_value("kertun_rauta", "kuultu", false)
	taulu = cfg.get_value("kertun_rauta", "taulu", false)
	spotted = cfg.get_value("kertun_rauta", "nahty", false)
	malmi = cfg.get_value("kertun_rauta", "malmi", false)
	malmi_known = cfg.get_value("kertun_rauta", "malmi_tunnettu", false)
	kuona = cfg.get_value("kertun_rauta", "kuona", false)
	found = cfg.get_value("kertun_rauta", "loytynyt", false)
	choice = cfg.get_value("kertun_rauta", "valinta", "")
	kiitetty = cfg.get_value("kertun_rauta", "kiitetty", false)
	poliisi = cfg.get_value("kertun_rauta", "poliisi", false)
