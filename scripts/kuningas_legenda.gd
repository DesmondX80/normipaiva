extends RefCounted
## Legenda: Kuninkaan tapuli (#126). Oikea tausta (Visit Raahe): Saloisten kellotapuli on vuodelta 1783, ja sen
## "sanotaan" olevan Ruotsin kuninkaan Kustaa III:n suunnittelema (varmistamaton; OSM ja Wikipedia antavat 1783–1786).
## Legenda (keksitty, pelissä totta): kuningas piirsi tapulin ja sinetöidyn piirustuksen muurattiin rakenteisiin;
## siksi tapuli säästyi kirkon palossa 1930. Kello kumahtaa yöllä, kun vaara on tulossa: oikeasti kylän teinit pitävät
## tapulissa bileitä ja kumauttavat kelloa, kun poliisiauto ajaa ohi. Ketju: suntio kertoo (heard) -> yöllä kello kumahtaa
## (yokello) -> tapulin juurella teinit pakenevat ja pudottavat avaimen kopion (teinit, avain) tai suntion oma avain, kun
## kirkon palon legenda on selvitetty -> Pirtin rakennusasiakirja "G. R." (asiakirja) tai droonin ilmakuva räystään
## kruunusta (drooni) -> lyijykotelo ylimmän palkin kolosta (found) -> museo tai takaisin koloon (suntio antaa avaimen
## pysyvästi: tapuli on jemma ja kello varoittaa poliisista).

const NIGHT := Vector2(22 * 60, 4 * 60)
const MUSEO_PALKKIO := 70.0
const MUSEO_MAINE := 12.0
const KOLO_MAINE := 4.0

var heard := false
var yokello := false
var teinit := false  # teinit paenneet, avain maassa
var avain := false  # avain tapuliin (kopio tai suntion)
var asiakirja := false
var drooni := false
var found := false
var choice := ""  # "" / "museo" / "kolo"


func proven() -> bool:
	return choice == "museo"


func clue() -> bool:
	return asiakirja or drooni


func save_to(cfg: ConfigFile) -> void:
	for k in ["heard", "yokello", "teinit", "avain", "asiakirja", "drooni", "found", "choice"]:
		cfg.set_value("kuningas", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["heard", "yokello", "teinit", "avain", "asiakirja", "drooni", "found"]:
		set(k, cfg.get_value("kuningas", k, false))
	choice = cfg.get_value("kuningas", "choice", "")
