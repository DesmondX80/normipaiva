extends RefCounted
## Saloisten huumekauppa: Kinnapotin apteekin takaovi (apteekki_saloinen.gd, hoitaja), kaukalon iltateinit ja laavun
## teinijengi (saloinen_teinit.gd, laavu_guard.gd). Myynti, paljastuminen ja jatkaminen ovat Vaalan funktioita
## (main.gd _teini_myy, TEINI_KIINNI, _jatka_laake); tämä tiedosto on vain Saloisten tila.
##
## Hoitajan lääkelaukku (laakelaukku.gd): hoitaja jättää sen portaalle kolmannen luukkuoston jälkeen, kerran. Laukulla
## jatketut annokset ovat "puhtaita": niiden paljastumisporras on yhtä alempi kuin klaffipöydän (TEINI_KIINNI-indeksi
## tier - 1, alaraja 0). Avaimen muotoa "id~n" ei muuteta (reppu, tallennus ja reseptit lukevat sitä), vaan puhtaat
## lasketaan erikseen laukku_erat-sanakirjaan.

## Luukkuostoja ennen laukkua: kolmannen oston jälkeen hoitaja jättää laukun portaalle.
const LAUKKU_OSTOT := 3

var ostot := 0  # luukulta onnistuneet ostot (raha väheni)
var laukku := ""  # "" = ei annettu, "portaalla" = odottaa poimijaa, "repussa" = pelaajalla
var laukku_erat := {}  # laake-avain ("opiaatti~1") -> laukulla jatkettujen annosten määrä
var ei_osta := {}  # ryhmä ("kaukalo" / "laavu") -> päivä, jona tappelun voiton jälkeen ei enää osteta


## Kirjaa luukkuoston; palauttaa true, kun tämä osto jättää laukun portaalle.
func osto() -> bool:
	ostot += 1
	if laukku == "" and ostot >= LAUKKU_OSTOT:
		laukku = "portaalla"
		return true
	return false


## Puhtaita annoksia avaimella: ei koskaan enempää kuin repussa on (myyty, syöty tai jatkettu edelleen).
func puhtaat(key: String, n_laake: int) -> int:
	return mini(int(laukku_erat.get(key, 0)), n_laake)


## Paljastumisporras (TEINI_KIINNI-indeksi) myytävälle annokselle: puhdas erä on porrasta alempi, alaraja 0.
func porras(tier: int, key: String, n_laake: int) -> int:
	if puhtaat(key, n_laake) > 0:
		return maxi(0, tier - 1)
	return tier


## Laukulla jatkettiin n annosta avaimeen key.
func lisaa_puhdas(key: String, n: int) -> void:
	if n > 0:
		laukku_erat[key] = int(laukku_erat.get(key, 0)) + n


## Yksi annos myytiin: puhtaat myydään ensin (sama, jota porras() käytti).
func myyty(key: String) -> void:
	var n := int(laukku_erat.get(key, 0)) - 1
	if n > 0:
		laukku_erat[key] = n
	else:
		laukku_erat.erase(key)


## Pudottaa puhtaiden määrät repun määriin (kutsutaan esim. tallennettaessa); laake = main.gd laake.
func sovita(laake: Dictionary) -> void:
	for key in laukku_erat.keys():
		var n := puhtaat(key, int(laake.get(key, 0)))
		if n > 0:
			laukku_erat[key] = n
		else:
			laukku_erat.erase(key)


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("huume_saloinen", "ostot", ostot)
	cfg.set_value("huume_saloinen", "laukku", laukku)
	cfg.set_value("huume_saloinen", "laukku_erat", laukku_erat)
	cfg.set_value("huume_saloinen", "ei_osta", ei_osta)


func load_from(cfg: ConfigFile) -> void:
	ostot = int(cfg.get_value("huume_saloinen", "ostot", 0))
	laukku = String(cfg.get_value("huume_saloinen", "laukku", ""))
	if not laukku in ["", "portaalla", "repussa"]:
		laukku = ""
	laukku_erat = _ints(cfg.get_value("huume_saloinen", "laukku_erat", {}))
	ei_osta = _ints(cfg.get_value("huume_saloinen", "ei_osta", {}))


static func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = int(d[k])
	return out
