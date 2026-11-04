extends RefCounted
## Huumekaupan riskien osan pohja (scripts/rikos/*.gd: velka, valeostaja, epaluulo, yliannos, huijari, autovarkaus).
## main.gd lataa osat RIKOS_OSAT-listasta (_rikos_init) ja kysyy jokaiselta samoissa kohdissa: puhe, logiikka, tapahtumat,
## uusi päivä, tallennus, päiväkirja ja tappelun loppu. Osa perii tämän (extends "res://scripts/rikos/osa.gd", ei
## class_name) ja korvaa vain tarvitsemansa. Osa ei koske toisen osan tiedostoon: tieto kulkee game._rikos_event-kautta
## tai game.rikos_osa(nimi)-haulla. Luvut ovat pelin omia yksiköitä, eivät todellisia annoksia tai määriä.

var game: Node  # main.gd
var nimi := ""  # tiedoston nimi ilman .gd:tä (main.gd asettaa ennen setup()-kutsua)

## Puhujat, joiden puheen tämä osa hoitaa (hello, options, choose, juttu). Nimet ja värit ovat main.gd TALKERS-vakiossa.
## Osa asettaa listan _init():ssä (vakiota ei voi määritellä aliluokassa uudelleen).
var talkers: Array = []


## Kerran pelin alussa ennen tallennuksen latausta (maailma on jo rakennettu).
func setup() -> void:
	pass


## Joka ruutu ulkona: Saloisissa _huume_saloinen_logic, Vaalassa _vaala_logic (game._in_vaala kertoo kumpi). e = E painettu.
func tick(_e: bool) -> void:
	pass


## Tervehdys keskustelun alkuun; "" = ei omaa (seuraava osa tai pelin oma tervehdys).
func hello(_who: String) -> String:
	return ""


## Lisää keskusteluvalintoja listaan o (game._opt(id, teksti, ok, syy)). Valinnan id alkaa osan nimellä ("velka_maksa").
func options(_who: String, _o: Array) -> void:
	pass


## Valinta tehty: true = osa hoiti sen (keskustelu ei jatka pelin omiin valintoihin).
func choose(_id: String) -> bool:
	return false


## Tapahtuma game._rikos_event(ev, data): "luukkuosto" {}, "myynti" {key, paikka: "vaala"|"saloinen"},
## "otto" {key, pot} sekä osien omat ("hylkasi", "epaluulo" {n}).
func on_event(_ev: String, _data: Dictionary) -> void:
	pass


## Uuden päivän alku (_new_day): palauttaa Päivin aamulapun lisärivin ("" = ei mitään). at_m = herätys mökillä.
func aamu(_at_m: bool) -> String:
	return ""


## Päiväkirjan Riskit-sivun osio: {"otsikko": String, "rivit": Array[String]} tai {} (ei mitään näytettävää).
## Ei saa muuttaa tilaa (journal_data kutsuu tallennusta).
func riskit() -> Dictionary:
	return {}


## Saloisten apteekin luukku kiinni: palauttaa vihjetekstin ("" = luukku auki).
func luukku_kiinni() -> String:
	return ""


## Diilitappelu, jonka tämä osa aloitti (game._rikos_fight = self): palauttaa loppuviestin.
func fight_end(_won: bool) -> String:
	return ""


## Testikohtaus --scene=riskit --riski=<nimi> [--arg=...]: tulostaa tilasiirtymät ja "TESTI VIKA ...", jos kriteeri pettää.
func testi(_arg: String) -> void:
	pass


## Tallennus omaan ConfigFile-osioon "rikos_<nimi>"; latauksessa oletusarvot vanhoille tallennuksille.
func save_to(_cfg: ConfigFile) -> void:
	pass


func load_from(_cfg: ConfigFile) -> void:
	pass


## ConfigFile-sanakirjan arvot kokonaisluvuiksi (huume_saloinen.gd _ints).
static func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = int(d[k])
	return out
