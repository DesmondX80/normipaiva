extends RefCounted
## Legenda: Pakkahuoneen veistos (#250 P5). Oikea tausta (pyynnön mukaan, tarkistettava): Raahen Pakkahuone on museona,
## sanotaan Suomen vanhin paikallismuseo, ja siellä on laaja kokoelma 1600-luvun uskonnollisia veistoksia. Kadonnut veistos
## on keksitty: peli ei väitä, että mikään oikea veistos olisi kadonnut. Kaikki esitetään "sanotaan"-muodossa.
## Ketju (kuten kuningas_legenda.gd): taksikuski kertoo (heard) -> sen jälkeen puupyhimys on kadonnut jalustaltaan ->
## kuraattori kertoo, että vitriini on lukittu ja avain kellarissa (kuraattori) -> vierailijakirjassa kunnostaja kirjoittaa
## vieneensä "jotain pientä" kellariin (kirja) -> kellarin luukku, kun molemmat kuultu: veistos löytyy laatikosta (found)
## ja palaa jalustalle. Ei rahaa, vain maine ja mielihyvä (kerran).

const MAINE := 3.0

var heard := false
var kuraattori := false  # vihje 1
var kirja := false  # vihje 2: vierailijakirja
var found := false


## Veistos on jalustallaan ennen huhua ja löydön jälkeen, välillä se on kadonnut.
func on_display() -> bool:
	return not heard or found


func clues() -> bool:
	return kuraattori and kirja


func save_to(cfg: ConfigFile) -> void:
	for k in ["heard", "kuraattori", "kirja", "found"]:
		cfg.set_value("pakkahuone", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["heard", "kuraattori", "kirja", "found"]:
		set(k, cfg.get_value("pakkahuone", k, false))
