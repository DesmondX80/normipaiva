extends RefCounted
## Legenda: Olavinmarkkinoiden hopea (#124). Oikea tausta (Visit Raahe, Stories of Old Town Raahe): Saloinen sai 1616
## vapaat markkinat Olavinpäivästä alkaen kahdeksi viikoksi, kauppiaita tuli monesta kaupungista ja talonpojat myivät
## mm. tervaa ja voita; kun Raahe perustettiin, markkinat siirtyivät Raahen Rantatorille. Legenda (keksitty, pelissä
## totta): saloislainen kauppias kätki markkinarahansa (hopeataalerit) kylään ja vannoi, että markkinat palaavat, kun
## hopea löytyy. Ketju: kirppiksen Hilkka kertoo (heard) -> Saloisten Pirtin kauppiaan kirje ja "kirkon rannan luoto"
## (kirje) -> hautausmaan kauppiaan kivi ja tuoreet kukat (kivi) -> Olavi-pappa (pappa) -> palvelus (kalja) ja lupa
## kaivaa (lupa) -> lapio autotallista (lapio) -> lipas kuopasta (found) -> museo tai hämäräkeräilijä. Museovalinnan
## jälkeen Olavinmarkkinat järjestetään joka Olavinpäivä (pelissä joka 7. päivä) seuraintalolla. Olavi-pappa kävelee
## lyhdyn kanssa kätköpaikalle Olavinpäivän yönä; muina öinä lyhty on Pannu-Sulon toimitusreitillä (sulo).

const OLAVINPAIVA_VALI := 7
const NIGHT := Vector2(22 * 60, 4 * 60)
const MUSEO_PALKKIO := 60.0
const MUSEO_MAINE := 12.0
const KERAILIJA_HINTA := 240.0
const KERAILIJA_MAINE := 8.0
const SUKUNIMI := "Skyttä"

var heard := false
var kirje := false
var kivi := false
var pappa := false  # Olavi-pappa tavattu hautausmaalla
var lupa := false  # palvelus tehty, lupa kaivaa
var lapio := false
var found := false
var choice := ""  # "" / "museo" / "kerailija"
var poliisi := false
var sulo := false  # Sulon vaitiolopullo saatu
var lyhty := false  # Olavinpäivän yön lyhty nähty


func olavinpaiva(day: int) -> bool:
	return day % OLAVINPAIVA_VALI == 0


func proven() -> bool:
	return choice == "museo"


func save_to(cfg: ConfigFile) -> void:
	for k in ["heard", "kirje", "kivi", "pappa", "lupa", "lapio", "found", "choice", "poliisi", "sulo", "lyhty"]:
		cfg.set_value("olavi", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["heard", "kirje", "kivi", "pappa", "lupa", "lapio", "found", "poliisi", "sulo", "lyhty"]:
		set(k, cfg.get_value("olavi", k, false))
	choice = cfg.get_value("olavi", "choice", "")
