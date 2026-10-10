extends RefCounted
## Tokolan vanha varasto ja kauppiaan aarteen legenda (#120). Tokolanperällä oli kyläkauppa, joka lopetti
## 1950–60-luvulla; sen varasto on yhä pystyssä Tokolantien varressa. Avain on vanhalla Aarolla (lihapiirakkaa
## vastaan). Varastosta löytyy sähköpyörän ohjain ja kaasukahva, rautalankaa ja kauppiaan tilikirja.
## Legenda (keksitty, pelissä totta): kauppias ei vienyt rahojaan pankkiin ja myi tiskin alta "sokeria".
## Tilikirjan piirros vie narisevan lattialankun alle, jonka peltirasiassa on lappu: "Heinimäen kuusen juurella".
## Latvattoman kuusen juurelta kaivetaan rahalipas (markkoja ja kauppiaan sormus). Todistus Aarolle (maine) tai
## tilikirja Pannu-Sulolle pulloa vastaan (Sulon isän nimikirjaimet ovat kirjassa).

var key := false
var tilikirja := false  # löydetty hyllyltä
var lankku := false  # lattialankun peltirasia avattu (lappu)
var lipas := false  # rahalipas kaivettu Heinimäeltä
var markat := false  # markat yhä tallessa (myydään kirppiksellä keräilijälle)
var rautalanka := false  # varaston rautalankakelat otettu
var legend := ""  # "" / "kyla" (näytetty Aarolle) / "sulo" (tilikirja Sulolle)


func proven() -> bool:
	return legend == "kyla"


func save_to(cfg: ConfigFile) -> void:
	for k in ["key", "tilikirja", "lankku", "lipas", "markat", "rautalanka", "legend"]:
		cfg.set_value("tokola", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["key", "tilikirja", "lankku", "lipas", "markat", "rautalanka"]:
		set(k, cfg.get_value("tokola", k, false))
	legend = cfg.get_value("tokola", "legend", "")
