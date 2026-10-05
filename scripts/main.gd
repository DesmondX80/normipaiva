extends Node3D
## Normipäivä Saloisissa: rakentaa maailman, pyörittää pelin tilaa ja HUDin.
## Tilat: to_shop -> in_shop -> to_home -> won, tai lost missä vaiheessa tahansa.

const B := preload("res://scripts/build.gd")
const PlayerBike := preload("res://scripts/player_bike.gd")
const WifeCar := preload("res://scripts/wife_car.gd")
const Juntti := preload("res://scripts/juntti.gd")
const ShopInterior := preload("res://scripts/shop_interior.gd")

const World := preload("res://scripts/world.gd")
const Minimap := preload("res://scripts/minimap.gd")
const Inventory := preload("res://scripts/inventory.gd")
const Compass := preload("res://scripts/compass.gd")
const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")
const Kota := preload("res://scripts/kota.gd")
const Mokki := preload("res://scripts/mokki.gd")
const Fight := preload("res://scripts/fight.gd")
const ChopGame := preload("res://scripts/chop_game.gd")
const SawGame := preload("res://scripts/saw_game.gd")
const BarGame := preload("res://scripts/bar_game.gd")
const LavaGame := preload("res://scripts/lava_game.gd")
const PingisGame := preload("res://scripts/pingis_game.gd")
const PaGame := preload("res://scripts/pa_game.gd")
## Santun hommat mökillä (santun_hommat.gd) ja niiden minipelit.
const Hommat := preload("res://scripts/santun_hommat.gd")
const LaituriGame := preload("res://scripts/laituri_game.gd")
const RanniGame := preload("res://scripts/ranni_game.gd")
const AmpiaisGame := preload("res://scripts/ampiais_game.gd")
const TiskiGame := preload("res://scripts/tiski_game.gd")
## Siitarin baari sisältä (siitari_interior.gd) ja karaoke (karaoke_game.gd).
const SiitariInterior := preload("res://scripts/siitari_interior.gd")
## Raahen baari: Kapteenin Kulma ja Kellari (raahe_interior.gd), taksilla kotoa.
const RaaheInterior := preload("res://scripts/raahe_interior.gd")
const RAAHE_INT_POS := Vector3(-16000, 0, 0)
const RAAHE_MENU := {
	"tuoppi": ["Tuoppi hanasta 0,5 l", 7.5, 0.14, 0.1, 0.05],
	"lonkero": ["Lonkero", 7.9, 0.14, 0.1, 0.05],
	"kossu": ["Kossupaukku 4 cl (\"ruukin lääke\")", 6.9, 0.12, 0.08, 0.03],
	"kahvi": ["Kaffet ja korvapuusti", 3.9, 0.0, 0.05, 0.05],
}
const RAAHE_LINES := ["Ruukin porukka nostaa lasit: \"Skooli!\"", "Kapteeni nyökkää ikkunapöydästä.",
	"Baarimikko: \"Ko lasi on tyhjä, tiiät mistä saa lisää.\"", "Kävelykadulla kulkee iltaväkeä kohti Pekkatoria.",
	"Joku räknää tiskillä kolikoita tuopin hintaan.", "Kellarista kuuluu karaokea portaita ylös."]
## Tiistain pubivisa: kysymys, oikea vastaus ensin, sitten väärät (järjestys sekoitetaan).
const RAAHE_QUIZ := [
	["Kuka perusti Raahen vuonna 1649?", ["Pietari Brahe", "Kustaa Vaasa", "J. L. Runeberg"]],
	["Mikä on Raahen vanhan torin nimi?", ["Pekkatori", "Kauppatori", "Rantatori"]],
	["Mitä raahelainen tekee, kun hän \"räknää\"?", ["Laskee", "Ruokkii lehmät", "Nukkuu päiväunet"]],
	["Mitä terästehtaan masuunissa tehdään?", ["Raakarautaa", "Paperia", "Sahatavaraa"]],
	["Mitä raahelainen sanoo nostaessaan lasin?", ["Skooli!", "Kippis ja kulaus!", "Hölökyn kölökyn!"]],
	["Mikä oli \"retari\" vanhassa Raahessa?", ["Laivanisäntä", "Kalastaja", "Lukkari"]],
	["Kuka veisti Pekkatorin Brahen patsaan (1888)?", ["Walter Runeberg", "Wäinö Aaltonen", "Emil Wikström"]],
	["Mitä raahelainen tarkoittaa sanalla \"kööki\"?", ["Keittiö", "Kuisti", "Kellari"]],
]
const RAAHE_KARAOKE_PRICE := 2.0
const KaraokeGame := preload("res://scripts/karaoke_game.gd")
const SIITARI_INT_POS := Vector3(16000, 0, 0)
const KARAOKE_PRICE := 2.0
const PAJATSO_PRICE := 1.0
## Sinikka Siitarissa (flirttailevaa kuten kotikadulla) ja Päivin puhelu, kun joku on nähnyt.
const SINIKKA_BAR_LINES := [
	"No mutta, naapuri! Täällähän sää iltasi vietät.", "Mää tuun tänne aina torstaisin. Musiikki vie mennessään.",
	"Tanssitaanko? Mää vien, jos sää et osaa.", "Päivi ei varmaan tiedä, että sää oot täällä?",
	"Mulla on ruusut kotona ihan yksin tänä iltana.", "Karaokessa sää olisit varmaan ihan Kari Tapio."]
const PAIVI_SINIKKA_CALLS := [
	"\"Pirjo soitti just, että sää TANSSIT Siitarissa Sinikan kanssa! Kotiin, NYT!\"",
	"\"Mitä sää siellä Vaalassa Sinikan kanssa peuhaat?! Koko kylä puhuu jo!\"",
	"\"Taas se Sinikka! Luuletko, ettei tänne kuulu mitään? Vaalan Facebook-ryhmässä on kuva!\"",
	"\"Sää tarjoot Sinikalle drinkkejä, ja meillä on nurmikko leikkaamatta!\""]
const PAIVI_MORNING_SINIKKA := ["Siitä Sinikasta puhutaan vielä. Tänään mää pidän sua silmällä.",
	"Kahvi on pöydällä. Kylmänä. Tiedät kyllä miksi. (Sinikka.)"]
const DroneGame := preload("res://scripts/drone_game.gd")
## Mopomatka Paapelista Vaalan Hotelli-Ravintola Siitariin (mopo_trip.gd, vaala.gd): erillinen tasku.
const MopoTrip := preload("res://scripts/mopo_trip.gd")
const TrafficCar := preload("res://scripts/traffic_car.gd")
const Atm := preload("res://scripts/atm.gd")
const TRAFFIC := 14  # autoja kylän tieverkossa (pidetään pelaajan ympärillä, ks. _traffic_tick)
const TRAFFIC_FAR := 450.0  # tätä kauempana oleva auto siirretään pelaajan lähelle
const TRAFFIC_RESPAWN := Vector2(180.0, 380.0)  # uusi paikka tältä etäisyydeltä (mieluiten näkökentän ulkopuolelta)
const VAALA_POS := Vector3(13000, 0, 6000)
## Siitarin baarin tuotteet: id -> [nimi, hinta, humala, stressi, moraali].
const SIITARI_MENU := {
	"karhu": ["Tuoppi Karhua 0,5 l", 6.9, 0.14, 0.1, 0.05],
	"lonkero": ["Hartwallin Lonkero", 7.2, 0.14, 0.1, 0.05],
	"jallu": ["Jallupaukku 4 cl", 6.5, 0.12, 0.08, 0.03],
	"kahvi": ["Kahvi ja munkki", 3.5, 0.0, 0.05, 0.03],
}
const SIITARI_LINES := ["Baarimikko: \"Mopolla Paapelista? Sieltä se Santtukin aina tulee.\"",
	"Jukeboksista soi Eppu Normaali.", "Pöydässä ikkunan vieressä pelataan korttia.",
	"Terassilta näkyy Vaalantie ja Oulujoen silta.", "Baarimikko: \"Karaokelava on tuolla. Uskallatko?\""]
const HuntGame := preload("res://scripts/hunt_game.gd")
const DartsGame := preload("res://scripts/darts_game.gd")
const FishGame := preload("res://scripts/fish_game.gd")
const LaavuGuard := preload("res://scripts/laavu_guard.gd")
const PaperMap := preload("res://scripts/paper_map.gd")
const Villager := preload("res://scripts/villager.gd")
const Looks := preload("res://scripts/looks.gd")
const Tractor := preload("res://scripts/tractor.gd")
const OnFoot := preload("res://scripts/on_foot.gd")
const Ambience := preload("res://scripts/ambience.gd")
const Cutscene := preload("res://scripts/cutscene.gd")
const Note := preload("res://scripts/note.gd")
const Menu := preload("res://scripts/menu.gd")
const Lawn := preload("res://scripts/lawn.gd")
const PoliceCar := preload("res://scripts/police_car.gd")
const PICK_TIME := 2.5  # sienet: pelkkä odotus
## Marjojen poiminta (puolukka, mustikka): kyykky-ylös-näpyttely.
const BERRIES := ["puolukka", "mustikka"]
const PICK_GAIN := 0.075  # oikea painallus oikeaan tahtiin
const PICK_FUMBLE := 0.06  # väärä nappi tai räpellys: marjoja tippuu
const PICK_TOO_FAST := 0.14  # s: nopeampi näpyttely on räpellystä
const PICK_IDLE := 0.8  # s: tauon jälkeen mittari alkaa valua
const PICK_DECAY := 0.12  # mittarin valuminen tauolla (/s)
const GRUNT_GAP_MS := 450  # ähkäisyjen väli vähintään
const BEND_DRAIN := 27.0  # kyykkiminen kuluttaa kuntoa (/s, kumoaa seisomisen palautumisen ja vähän päälle)
const BUCKET_MAX := 8
## Metsän antimet: hinta €/l, ostaja ja nimi.
const GOODS := {
	"puolukka": {"price": 4.0, "buyer": "arto", "name": "puolukoita"},
	"mustikka": {"price": 5.0, "buyer": "arto", "name": "mustikoita"},
	"kantarelli": {"price": 10.0, "buyer": "pekka", "name": "kantarelleja"},
	"herkkutatti": {"price": 8.0, "buyer": "pekka", "name": "herkkutatteja"},
}
const ARTO_LINES := ["Lähekkö puolukkaan?", "Antinsuonkankaalla on puolukkaa ku mettä!", "Mustikkaa löytyy kuusikosta.",
	"Tuu myymään marjat mulle, maksan hyvin!", "Lähekkö huomenna puolukkaan?"]
const PEKKA_LINES := [
	"Perkele, ammuin toissapäivänä neljätoista saatanan kyyhkyä!",
	"Yks oli vittu ihan kalkkunan kokonen, usko pois perkele.",
	"Haulikko lauloi koko helvetin aamun, saatana!",
	"Kyyhkyt ja kantarellikastike, se on perkeleen herkkua.",
	"Tuoppa niitä vitun sieniä, mää ostan kaikki, saatana!",
	"Sanoinko jo perkele että ammuin neljätoista kyyhkyä?",
	"Talvella mää ammun kolmesataa saatanan jänistä!",
	"Kolmesataa jänistä perkele, joka talvi. Pakkaseen ei enää mahdu vittu.",
	"Jäniksiä on niin helvetisti, että ne tulee jo pihalle, saatana!",
	"Tänä talvena voi mennä jo kolmesataaviiskymmentä, perkele."]
## Sinikan tehtävä: kaksi litraa mustikoita piirakkaan, palkaksi uunituore mustikkapiirakka (kerran päivässä).
## Jos Päivi näkee sinut Sinikan pihalla, stressi nousee.
const SINIKKA_BERRIES := 2
const SINIKKA_ASK := ["Voi kulta, mää leipoisin sulle piirakan... mutta mun täyte on ihan lopussa. Toisitko kaks litraa mustikoita? Mää teen sen vaivan arvoiseksi.",
	"Mun uuni on jo kuumana, puuttuu vaan täyte. Tuo kaks litraa mustikoita, niin pääset maistamaan.",
	"Mää tarviin miehen, joka osaa poimia. Kaks litraa mustikoita... ja pehmeällä kädellä, ettei ne litisty."]
const SINIKKA_WAIT := ["Mustikoita, kulta. Kaks litraa. Mää en jaksa odottaa... tai no, sua mää jaksan.",
	"Uuni on kuuma ja minä odotan. Älä anna kummankaan jäähtyä.",
	"Tyhjin käsin? No, katella saa... mutta piirakkaa ei heru ilman mustikoita."]
const SINIKKA_THANKS := ["Voi, kuinka isoja ja mehukkaita! Tässä, piirakka on vielä lämmin... niinku minäkin.",
	"Sää kyllä tiedät, miten nainen ilahdutetaan. Ota piirakka ja tuu huomenna uudestaan... hakemaan lisää.",
	"Näin täyteläisiä marjoja! Ota piirakka. Päivin ei tarvii tietää, kuka sulle leipoo."]
## Sinikka hoitaa puutarhaansa ja puhuu siitä hyvin flirttailevasti.
const SINIKKA_LINES := [
	"Tuu kattomaan mun ruusuja... ne kaipaa hellää kättä. Ja vähän piikittelyä.",
	"Mää kastelen aina illalla. Hitaasti, huolella... ja perusteellisesti joka kolosta.",
	"Kurkut on tänä vuonna tavallista pitempiä. Haluatko nähdä? Saat koskeakin.",
	"Multa pitää kuohkeuttaa perusteellisesti, muuten mikään ei nouse. Sää näytät mieheltä, joka osaa.",
	"Tomaatit kypsyy parhaiten, kun niitä vähän hyväilee. Mää hyväilen joka aamu.",
	"Päivin ei tarvitse tietää, että kävit auttamassa mua kitkemisessä... polvillaan.",
	"Mun kasvimaalla on aina tilaa yhdelle ahkeralle lapiomiehelle. Onko sulla iso lapio?",
	"Voisitko joskus tulla leikkaamaan mun pensasaidan? Se on päässyt vähän villiksi.",
	"Kuumina päivinä kastelen itsenikin puutarhaletkulla. Tuu kattomaan, jos uskallat.",
	"Porkkanat pitää nostaa käsin. Varovasti, mutta päättäväisesti. Mää pidän paksuista.",
	"Mulla on niin vehreää, että vähän hengästyttää. Tuutko istumaan? Aurinkotuolissa on tilaa kahdelle.",
	"Kaikki kasvaa paremmin, kun niille kuiskaa hiljaa ja lämpimästi. Sääkin kasvaisit.",
	"Mun ruusupensas kaipais vähän lannoitetta... ja miehen otetta.",
	"Kurkkuja, kesäkurpitsaa, porkkanaa... mulla on aina jotain pitkää ja kovaa kasvamassa.",
	"Mää en käytä hanskoja. Tykkään tuntea mullan paljain käsin.",
	"Kitkeminen on niin hikistä hommaa. Siksi mää teen sitä näin vähissä vaatteissa."]
const GRILL_TIME := 5.0
const SAVE_PATH := "user://normipaiva.cfg"

const INTERIOR_POS := Vector3(3000, 0, 0)
const MOKKI_POS := Vector3(6000, 0, 0)  # erillinen tasku, tavoitettavissa vain taksilla kotoa
## Mökki on Vaalan Neittävän kylällä (Kaisuantie 62, 64,5055 N 26,6672 E) ja koti Saloisissa (Järvikuja 1, 64,6431 N
## 24,4766 E). Pelissä mökki on erillinen tasku, joten välimatka niiden välillä on oikea linnuntie (n. 106 km itään).
## Mökillä pääpelin tehtävät (kauppareissu, jemmat, aika, vaarat) eivät etene eivätkä näy HUD:ssa.
const MOKKI_AREA_R := 700.0
const HOME_MOKKI_KM := 105.7
var _list_pending := false  # päivä alkoi mökiltä: Päivin värilista kerrotaan kotiin palatessa
## Mökin sisätila (mokki_interior.gd) omassa taskussaan; kuistin ovelta E vie sisään.
const MokkiInterior := preload("res://scripts/mokki_interior.gd")
const HomeInterior := preload("res://scripts/home_interior.gd")
## Autotallin sisätila (garage_interior.gd): nosturiovelta sisään. Auto SLN-73 ja karburaattorin säätö
## (carb_game.gd), työpöytä (pyörän huolto), radio, pakastearkku, työkalukaappi (jemma) ja pyörän paikka.
const GarageInterior := preload("res://scripts/garage_interior.gd")
const CarbGame := preload("res://scripts/carb_game.gd")
const GARAGE_INT_POS := Vector3(-9000, 0, 3000)
const BIKE_TUNE := 1.1  # työpöydällä huollettu pyörä: huippunopeus ja kiihtyvyys päivän ajan
## Sisätiloissa olevat jemmat (eteisen kaappi kodin eteisessä, työkalukaappi tallissa): _stash_ui sisältä.
const INDOOR_STASHES := ["koti", "autotalli"]
const WcGame := preload("res://scripts/wc_game.gd")
const ShopChaser := preload("res://scripts/shop_chaser.gd")
const Story := preload("res://scripts/story.gd")
const TAXI_MOKKI_FARE := 60.0  # kaupan taksilla Paapeliin, meno-paluu
## Pöntöllä kysytään Saloisten tapaan: ykkönen vai kakkonen.
const WC_ASK := ["No nii. Onko pikkunen vai isompi hätä?", "Mitäs sää, ykköstä vai kakkosta?",
	"Kumpi on, pissa vai kakka? Ei tartte hävetä.", "Pikkunen asia vai iso asia? Kerro nyt."]
const HOME_INT_POS := Vector3(-9000, 0, 0)  # kodin sisätila, erillinen tasku
const MOKKI_INT_POS := Vector3(9000, 0, 0)
const TV_SHOWS := ["Salkkarit: Kaikki riitelee taas.", "Kauniit ja rohkeat: Ridge on hämmentynyt.", "Uutiset: sadetta luvassa.",
	"Hirviketju: kolme hirveä, kaksi ohi.", "Ostoskanava: veitsiä, jotka leikkaa tomaatin ja kengän."]
var mokki_int: Node3D
var home_int: Node3D
var _home_prev := "to_shop"  # ulkotila ennen kotiin menoa (to_home = kuutonen haettu tänään)
var garage_int: Node3D
var _garage_prev := "to_shop"
var _garage_exit_frame := -1
var bike_in_garage := false  # pyörä tallissa: piilossa ja turvassa varkailta
var _bike_garage_saved := false
var _bike_tuned := false
var _freezer_bottle := false  # arkun pohjan Koskenkorva löydetty (kerran pelikerrassa)
var siitari_int: Node3D
var raahe_int: Node3D
var _raahe := {}  # illan tapahtumat Raahen baarissa (kädenvääntö, visa, karaoke)
var _quiz: Array = []  # visan kysymykset [kysymys, vaihtoehdot sekoitettuna, oikea]
var _quiz_i := 0
var _quiz_right := 0
var _paivi_call_t := -1.0  # Päivin motkotuspuhelu tulossa (s), kun Sinikan kanssa on peuhattu
var _sinikka_gossip := false  # aamulla vielä motkotusta ja Päivi nopeampi
var _paivi_mad := false
var _paivi_call_kind := "sinikka"  # Päivin puhelu Siitariin: "sinikka" tai "santtu" (Santtu kantelee hommista)
var _santtu_gossip := false  # Santtu soitti Päiville: kotona aamulla motkotusta ja Päivi nopeampi
var _mokki_prev := "to_shop"
var _slept_mokki := false
const ZONE_RADIUS := 6.0
var shop_door := Vector3.ZERO  # Saloisten K-Marketin oven edusta
var home_door := Vector3.ZERO  # kodin etuoven portaiden edusta (kotiin meno, eteisen kaappi, Päivin ostokset, haava)
var home_back_door := Vector3.ZERO  # takaovi takapihalle (etuovea vastapäätä)
const HOME_DOOR_ZONE := 3.0  # Päivin ostosten luovutus ja haavan hoito ovella
var _shop_exit_frame := -1  # ulos tullessa painettu E ei vie heti takaisin sisään
var _shop_prev := "to_shop"  # ulkotila ennen kauppaan menoa (to_home = kuutonen jo ostettu tänään)
const DOOR_RADIUS := 1.8  # kotiovi: tyhjin käsin tästä sisään (eteisen jemma on ovesta 4,8 m, ei päällekkäin)
const SHOP_DOOR_R := 2.4  # Saloisten K-Marketin ovi: tästä sisään (E)
## Päivi, kun kotiin tullaan ilman hänen ostoksiaan.
const PAIVI_NO_SHOPPING := [
	"Missä mun ostokset?!",
	"Ja kauppalista? Mää kirjotin sen ihan sulle, ja sää tuut tyhjin käsin!",
	"Missä ne mun tavarat on? Unohtuko taas?",
	"Ookko sää ees käyny kaupassa? Mun ostokset puuttuu kokonaan!",
]
## Kauppias ovella, kun yrittää kauppaan kalja kädessä (Saloisten tapaan).
const SHOP_NO_BEER := [
	"Ei kaljojen kanssa kauppaan! Viehän ne ensin pois, ennenko tuut tänne heilumaan.",
	"Ookko sää tosissas? Omia kaljoja ei tänne tuuva. Mää en kato sitä hyvällä.",
	"Ei käy! Kalijat jemmaan ja sitte tullaan uuesti, ookko ymmärtäny?",
	"Kato nyt ittiäs, kassi täynnä kaljaa! Ei tänne niitten kanssa, ei ees Saloisissa.",
	"Hoi hoi! Mää tunnen sut. Ensin ne kaljat pois, sitte vasta kauppaan.",
]
const START_MONEY := 20.0
## Taksi K-Marketin taksitolpalta Raahen baariin ja takaisin.
const TAXI_FARE := 14.0  # meno-paluu
const BAR_ROUND := 6.0  # kädenväännön häviäjä tarjoaa kierroksen
const TAXI_RADIUS := 3.5
const BAR_POS := Vector3(0, 0, -4200)  # baarin minipeli kaukana kartan ulkopuolella
const PINGIS_POS := Vector3(-3000, 0, 300)  # mökin pingisnäyttämö kaukana kartan ulkopuolella (tappelun vieressä)
const CHOCO_CHANCE := 0.5  # suklaa lepyttää Päivin
const CHOCO_MONEY := 5.0  # leppynyt Päivi antaa aamulla ylimääräistä
const BEER_PRICE := 12.90
const PEKKA_RIDE_PRICE := 10.0  # tai kalja: Pekan kyyti mökille
const SAUNA_TALK_RADIUS := 30.0  # etäisyys, jonka sisällä Santun ympäristöpuheet voivat laueta

var world: Node3D
var home_zone: Vector3
var shop_zone: Vector3
var player: CharacterBody3D
var wife: CharacterBody3D
var juntti: CharacterBody3D
var interior: Node3D
var state := "to_shop"
var money := START_MONEY
var beers := 0
var elapsed := 0.0
var wife_alerted := false

var _hazards: Node3D
var _stats: Label
var _status: Label
var _hint: Label
var _msg: Label
var _note: Control  # Päivin heippalappu (note.gd): päivän alun ohjeet
var _msg_time := 0.0
var _sus_box: Control
var _sus_bar: ProgressBar
var _bird_t := 2.0
var _minimap: Control
var _inventory: Control  # reppu (I / Tab), inventory.gd
## Drooni (drone_game.gd): alusta kotipihalla, akku latautuu maassa, törmäys rikkoo päiväksi. Ilmakuvat kerätään
## kokoelmaksi, ja Pannu-Sulon pontikkapannu merkitään karttaan, kun se on kuvattu ilmasta.
const DRONE_CHARGE_S := 240.0  # tyhjästä täyteen
const DRONE_POIS := {
	"koti": "Koti, Järvikuja 1", "kmarket": "K-Market", "laavu": "Laavu Antinsuonkankaalla",
	"grillikatos": "Kiilinlammen grillikatos", "pontikka": "Pannu-Sulon pontikkapannu!", "paivi": "Päivin Hyundai",
	"juntti": "Juntti", "jyvajemmari": "Jyväjemmarin traktori", "mummot": "Penkin mummot", "arto": "Naapurin Arto",
	"pekka": "Pekka", "sinikka": "Naapurin Sinikka", "vaino": "Väinö karkuteillä", "pojat": "Jalkapallopojat",
}
## Mökillä sama drooni lennetään pihan alustalta: omat ilmakuvat (id:t m_-alkuisia, samassa kokoelmassa).
## Järvet ja lammet lisätään karttadatasta (ks. _mokki_drone_names).
const MOKKI_DRONE_POIS := {
	"m_mokki": "Mökki, Kaisuantie 62", "m_savusauna": "Savusauna", "m_poreamme": "Palju", "m_keittio": "Kesäkeittiö",
	"m_laituri": "Laituri Likasella", "m_lava": "Metsästyslava", "m_santtu": "Santtu pihatuolilla",
}
const MOKKI_DRONE_R := 620.0  # lentoalueen säde mökiltä (maisema jatkuu vähän pidemmälle)
var drone_battery := 1.0
var drone_broken_day := -1
var _mokki_drone_cache := {}
var _mokki_lakes := {}  # id -> paikallinen piste järven pinnalla
var drone_photos: Array = []
var pontikka_found := false
## Mökin metsän viinakätköt (Mokki.VIINA): löydetyt id:t ja repussa olevat pullot. Säilyvät pelikerrasta toiseen.
var viina_found: Array = []
var viina_pullot := 0
const VIINA_OPEN_R := 2.0
var _drone: Node3D
var mopo_trip: Node3D
## Vaalassa (mopomatka, Siitari, Tervaportti, lava): sama pelitila kuin kylässä ja mökillä (to_shop/to_home),
## pelaajana mopo tai sen vierestä kävelevä. Kylän omat asiat odottavat Saloisissa kuten mökillä.
var _in_vaala := false
var _vaala_state := "to_shop"  # tila, johon Vaalan sisätiloista palataan
## Pankkiautomaatti: 20 € kerran päivässä (Saloisissa K-Marketin takana, Vaalassa K-Market Tervaportin seinällä Siitarin vieressä).
var atm_day := 0
var _atm_node: Node3D
var _mopo_label: Label
var _drone_parked: Node3D
var _compass: Control
var _hud: CanvasLayer
var fight: Node3D
var _fight_prev := ""
var _fight_dir := Vector3.ZERO
var _fight_source := "juntti"  # juntti | laavu
var guard: Node3D
var has_sausage := false
var has_matches := false
## Suklaalevy taskussa: saattaa lepyttää Päivin (salainen mekaniikka, ei vinkkejä pelissä).
var has_chocolate := false
var _choco_mercy := false  # Päivi leppyi WASTED-motkotuksessa: seuraavana aamuna ylimääräistä rahaa
## Raahen reissujen mittarit 0–100 (tallentuvat): mielihyvä ja maine kovana jätkänä.
var mielihyva := 0.0
var maine := 0.0
var _no_allowance := false  # Raahen reissun jälkeen Päivi ei anna aamulla rahaa kauppaan
var _jemma_choco := ""
var fire_lit := false
var sausage_done := false
var _grill_t := -1.0
var bucket := {}  # laji -> litrat
var _pick_t := -1.0
var _pick_spot: Dictionary = {}
var _pick_meter := 0.0  # marjojen poimintamittari 0–1
var _pick_down := false  # kyykyssä: seuraavaksi odotetaan ylös (D)
var _pick_idle := 0.0  # aika edellisestä painalluksesta
var _pick_locked := false  # poiminta otti ohjauksen pois
var _grunt_next := 0  # ms: seuraava ähkäisy aikaisintaan
var arto: CharacterBody3D
var pekka: CharacterBody3D
var sinikka: CharacterBody3D
var sinikka_task := 0  # 1 = Sinikka odottaa mustikoita
var tikka_ennatys := 0  # tikanheiton paras tulos (3 x 3 tikkaa)
var tractor: CharacterBody3D
## player = se jolla nyt liikutaan (pyörä tai jalan); bike ja walker_out ovat molemmat olemassa koko ajan.
var bike: CharacterBody3D
var walker_out: CharacterBody3D
var _paper: Control
var _stamina_box: Control
var _stamina_bar: ProgressBar
var _bike_away_t := 0.0
## Paikat, joihin teinit voivat viedä lukitsemattoman pyörän.
const BIKE_DUMPS := [Vector2(560, 1062), Vector2(300, 600), Vector2(640, 160), Vector2(400, 1480), Vector2(174, 640),
	Vector2(760, 1680)]
## Kaljajemmat: id -> kaljat. Säilyvät pelikerrasta toiseen (user://normipaiva.cfg).
## Kotijemmoja Päivi voi löytää (safe = montako mahtuu huomaamatta, find = löytymisherkkyys),
## ulkojemmoista teinit voivat pölliä (steal = todennäköisyys aamulla). cap = kapasiteetti.
const STASHES := {
	"koti": {"name": "eteisen kaappi", "short": "eteinen", "into": "eteisen kaappiin", "from": "eteisen kaapista",
		"home": true, "cap": 24, "safe": 4, "find": 1.5},
	"autotalli": {"name": "autotallin työkalukaappi", "short": "talli", "into": "autotallin työkalukaappiin",
		"from": "autotallin työkalukaapista", "home": true, "cap": 18, "safe": 8, "find": 0.8},
	"komposti": {"name": "kompostin taus", "short": "komposti", "into": "kompostin taakse", "from": "kompostin takaa",
		"home": true, "cap": 12, "safe": 8, "find": 0.4},
	"laavu": {"name": "laavun halkovaja", "short": "laavu", "into": "halkovajan jemmaan", "from": "halkovajan jemmasta",
		"home": false, "cap": 36, "steal": 0.35},
	"grilli": {"name": "grillikatos", "short": "grilli", "into": "grillikatoksen jemmaan", "from": "grillikatoksen jemmasta",
		"home": false, "cap": 24, "steal": 0.3},
	"torni": {"name": "lintutornin alus", "short": "torni", "into": "lintutornin alle", "from": "lintutornin alta",
		"home": false, "cap": 24, "steal": 0.15},
}
var stash := {}
var _stashed_today := 0  # tänään jemmoihin piilotetut (kotimatkan tappio vain, jos mitään ei ole piilossa)
## Jemmat, joita pelaaja on käyttänyt (näytetään paperikartalla).
var stash_used: Array = []
## Pyörä jää sinne, minne sen jättää (myös yön yli ja pelikerrasta toiseen): tallennettu paikka ja suunta.
var _bike_saved = null  # [Vector3, float] tai null
var _old_stash_lost := 0  # vanhan tallennuksen jemmat, jotka menetettiin päivityksessä
## Kotijemmojen summa (onnellinen loppu, kun JEMMA_GOAL täynnä). Asetus tyhjentää kotijemmat ja
## laittaa arvon eteisen kaappiin (testit ja loppukohtaus).
var jemma: int:
	get:
		var n := 0
		for id in STASHES:
			if STASHES[id].home:
				n += stash.get(id, 0)
		return n
	set(v):
		for id in STASHES:
			if STASHES[id].home:
				stash[id] = 0
		stash["koti"] = v
var laavu_conquered := false
var stash_laavu: int:
	get:
		return stash.get("laavu", 0)
	set(v):
		stash["laavu"] = v
var stash_grilli: int:
	get:
		return stash.get("grilli", 0)
	set(v):
		stash["grilli"] = v
var _jemma_found := 0
var jemma_endings := 0
var day := 1
var cutscene: Node3D
var menu: CanvasLayer
var _env: Environment
var _fps_label: Label
var _sun: DirectionalLight3D
static var skip_menu := false  # "Uusi peli" lataa kentän uudelleen ilman alkuvalikkoa
var jemma_best := 0
var jemma_wins := 0
## Nurmikon leikkuu (lawn.gd): kaksi siiliä -> poliisi, kaksi kiveä -> leikkuri rikki (varaosa Artolta + kalja).
const LAWN_DONE := 0.9  # tämä osuus leikattuna = valmis
const LAWN_PART_PRICE := 8.0
const LAWN_BONUS := 5.0  # leikatusta nurmikosta Päivi antaa aamulla ylimääräistä
const LAWN_NAG_PAIVI := ["Se nurmikko ei leikkaa itseään!", "Takapiha näyttää ihan heinäpellolta.",
	"Leikkaa nyt se nurmikko ennen kuin lähet mihinkään!"]
## Päivi kertoo lapussa, mitä Anna-Liisa sanoi aidan takaa.
const LAWN_NAG_ANNALIISA := ["Anna-Liisa sano aidan takaa, että meillä on kohta ihan heinäpelto!",
	"Anna-Liisan mukaan siilit on muuttanu meidän nurmikolle asumaan.",
	"Anna-Liisa muisti taas mainita, että niillä leikataan nurmikko joka lauantai."]
## Pannu-Sulon pontikkakanisteri metsästä: vastaa kotijemmassa 24 kaljaa. Yksi kanisteri päivässä.
const KANISTER_BEERS := 24
const KANISTER_PRICE := 20.0
const SULO_LINES := ["Ei kuulu kellekään, mitä täällä tehdään.", "Kakskymppiä kanisteri, ja suu suppuun.",
	"Sokeria, hiivaa ja kärsivällisyyttä. Siinä se resepti.", "Ootko sää poliisi? Et näytä poliisilta.",
	"Tää on vanhan ajan tavaraa, ei mitään Alkon litkua.", "Kuka sulle tästä paikasta kerto? Raimo, vai?"]
## Sivutehtävä: Pekan koira Väinö karkaa (dog.gd). Palautus Pekalle: vitonen ja kalja.
const Dog := preload("res://scripts/dog.gd")
const VAINO_CHANCE := 0.2  # osuus päivistä, joina Väinö karkaa
const VAINO_MONEY := 5.0
## Vieras koira metsänreunassa puree (stray_dog.gd). Haava hoidetaan kotikonstein: Pekka (kalja tai
## PEKKA_CARE €) tai Päivi kotona (ilmainen, mutta motkottaa). Hoitamaton haitta kestää päivän loppuun.
const StrayDog := preload("res://scripts/stray_dog.gd")
## Metsän pedot (beast.gd): jalan metsässä kertyy aikaa, ja kun _beast_next täyttyy, karhu tai susi ilmestyy
## puiden sekaan. Saloisissa kerran päivässä; mökillä metsää on enemmän ja pedot yleisempiä (aika kertyy
## nopeammin, kaksi päivässä). Karhun haava on isompi kuin suden: enemmän kipua, ontuu pahemmin ja kipu
## pahenee hoitamatta. Haavan hoitavat Pekka, Päivi tai mökillä Santtu omin konstein.
const Beast := preload("res://scripts/beast.gd")
const BEAST_FOREST_S := [50.0, 110.0]
const BEAST_MAX := {"koti": 1, "mokki": 2}
const BEAST_MEAT := ["piirakka", "savukala", "savuriista", "karrella"]
const BEAR_HURT_SPEED := 0.45
const SANTTU_CARE := [
	["Santtu kaatoi haavaan kätköviinaa, otti itse huikan ja sitoi päälle jesarilla. Pitää!", "Jesari pitää vaikka mitä."],
	["Santtu levitti haavaan koivutervaa ja painoi päälle sammalta. Haisee savusaunalta.",
		"Vaari paransi tällä karhunkin raapaisut."],
	["Santtu pesi haavan järvivedellä, liimasi sen pikaliimalla ja kehui omaa kättään.", "Pikaliima on armeijan keksintö, tiesitkö?"],
	["Santtu kääri haavaan vanhan saunapyyhkeen ja käski purra kalikkaa.", "Ei tunnu missään, eihän?"],
]
var _beast: Node3D = null
var _beast_forest_t := 0.0
var _beast_next := 80.0
var _beasts_today := 0
var wound_big := false  # karhun raatelema
const Mummot := preload("res://scripts/mummot.gd")
var mummot: Node3D
const PEKKA_CARE := 3.0
const WOUND_PAIVI := ["Taas sää oot ollu vieraitten koirien kans!", "Istu siihen. Ja älä vingu.",
	"Ei ne koirat ite purase, jos niitä ei mene rapsuttelemaan."]
## Jalkapallopojat (#29, boys.gd): joka toinen päivä kolme poikaa jossain tien varressa, pallo hukassa 100–300 m päässä.
## Palautus esinevalikosta: pallo = 1 € ja moraali/kokemus, kalja = pojat juoksevat nauraen pois, muu = kivisade.
const Boys := preload("res://scripts/boys.gd")
const ItemMenu := preload("res://scripts/item_menu.gd")
const BALL_REWARD := 1.0
var boys: Node3D
var ball: Node3D
var has_ball := false
var _ball_quest := ""  # "" = ei annettu, "search" = etsitään, "done" = hoidettu
var _item_menu: PanelContainer
var _menu_mode := "give"  # esinevalikon käyttö: "give" (pojat) tai "eat" (T: syö)
## Eväät kaupan leipähyllystä: avain -> kpl (syödään T:llä, häviävät yöllä kuten kaljat).
var food := {}
## Syötävät: nimi valikossa, nälkä ja muut tilavaikutukset.
const FOODS := {
	"pulla": {"name": "Korvapuusti", "nalka": 0.25, "stressi": 0.05},
	"piirakka": {"name": "Lihapiirakka", "nalka": 0.4},
	"suklaa": {"name": "Suklaalevy (Päivin lepytys menee)", "nalka": 0.2, "stressi": 0.1, "moraali": 0.05},
	"puolukka": {"name": "Puolukoita ämpäristä (1 l)", "nalka": 0.15, "vireys": 0.05},
	"mustikka": {"name": "Mustikoita ämpäristä (1 l)", "nalka": 0.15, "vireys": 0.05},
	"savukala": {"name": "Savukala", "nalka": 0.5, "stressi": 0.05, "moraali": 0.05},
	"savuriista": {"name": "Savustettu riista", "nalka": 0.6, "stressi": 0.05, "moraali": 0.1},
	"karrella": {"name": "Karrelle savustunut saalis", "nalka": 0.25},
	"viina": {"name": "Kätköviina", "nalka": 0.0, "stressi": 0.15, "moraali": 0.05},
	"mustikkapiirakka": {"name": "Sinikan mustikkapiirakka", "nalka": 0.45, "stressi": 0.1, "moraali": 0.15},
}
## Päivittäiset tilat (#18, day_stats.gd): kolme arvottua tilaa HUD:ssa, toiminnot nostavat ja laskevat niitä.
## Jokaisella tilalla on palkinto ja haitta (_stat_effects). Eilinen ei vaikuta, paitsi humala (krapula).
const DayStats := preload("res://scripts/day_stats.gd")
const StatBars := preload("res://scripts/stat_bars.gd")
var tilat: RefCounted
var _wife_speed_base := 1.0  # päivän perusarvot, joihin tilojen vaikutukset lisätään (_apply_day_base)
var _anger_base := 5.0
var _stat_bars: Control
var _still_t := 0.0  # paikallaan oloaika (lepo, kokemuksen hiipuminen)
## Päivin kauppalista (muistipeli, #12): heippalapussa tuotteet värikynillä hetken, repun lista näyttää vain tuotteet.
## Tuotteet haetaan kaupan Päivin hyllystä (shop_interior.gd) ja tarkistetaan kotona.
const LIST_SIZE := 4
var shopping_list: Array = []  # [[tuote, väri], ...]
var paivi_bag := {}  # kaupasta tuodut: tuote -> väri
var _list_done := false
var _kaljarauha := false  # kaikki oikein: Päivi ei etsi jemmoja seuraavana aamuna
var _msg_queue: Array = []
var stray: CharacterBody3D
var bitten := false
var vaino: CharacterBody3D
var _vaino_at := -1.0  # päivän aika (elapsed), jolloin Väinö karkaa; -1 = ei tänään
var sulo: CharacterBody3D
var has_kanister := false
var _sulo_sold := false  # tämän päivän kanisteri on jo myyty
var lawn: Node3D
var police: CharacterBody3D
var mowing := false
var lawn_siilit := 0  # yliajetut siilit (toinen tuo poliisin)
var lawn_kivet := 0  # kivet terässä (toinen rikkoo leikkurin)
var mower_broken := false
var has_mower_part := false
var _lawn_praise := false  # nurmikko leikattu: aamulla ylimääräistä rahaa
var _lawn_done_today := false
var mokki: Node3D
var _santtu_chat_t := 6.0
## Santun hommat (santun_hommat.gd): päivän hommat, hermot ja arvostelut.
var hommat: RefCounted
var story: RefCounted  # tarina (story.gd): ohjaa naapurilta toiselle, Pekan kyyti Paapeliin aukeaa lopuksi
var sinikka_lawn: Node3D  # Sinikan takapihan nurmikko (tarinatehtävä)
var _keys_node: Node3D  # Pekan autonavaimet kodalla
var _taxi_mokki_return := false  # taksilla Paapeliin: paluu maksettu
## Mökin päädyn nurmikko (lawn.gd mökin maastossa) ja nurmikko, jota leikkuri parhaillaan leikkaa.
var mokki_lawn: Node3D
var _mow_lawn: Node3D
## Kädessä kannettava (huussin sanko, halkosyli, kahvikuppi) ja sen läikkymisvaara (0–1).
var _carry := ""
var _carry_slosh := 0.0
## Mökin puupaikka: sahatut pölkyt ja tänään halotut halot (saunapuut).
var _mokki_polkyt := 0
var _mokki_halot := 0
## Laiturin paikkalautojen ja rännien tila päivän aikana (laituri_game.gd, ranni_game.gd).
var _dock_state: Array = []
var _ranni_state: Array = []
## Santtu katsomassa hommaa: homman id, kommenttien ajastin ja poissaolo ilman hommaa.
var _watch_task := ""
var _watch_t := 0.0
var _watch_idle := 0.0
var _watch_arrived := false
var _watch_retarget := 0.0
var _palju_draining := false
var _palju_overflow := 0.0
## Raaka saalis (laiturin kalat, metsästyslavan riista) odottaa savustusta kesäkeittiössä:
## [{"type": "kala" | "riista", "nom": "hauki"}, ...]. Häviää yöllä kuten eväät.
var saalis: Array = []
## Offset-savustin (Mokki.KITCHEN_LOCAL): halot tulipesään (E), lämpö seuraa polttoainetta viiveellä.
## Savustus etenee 80–120 °C:ssa täysillä, viileämmässä hitaasti; yli 135 °C saalis karrelle.
const SMOKER_LOAD_MAX := 4
const SMOKER_TIME := 35.0  # s sopivassa lämmössä
const SMOKER_LOG := 0.22  # halon lisäys polttoaineeseen
const SMOKER_BURN := 0.045  # polttoaineen kulutus /s
var smoker_load: Array = []  # savustimessa olevat saaliit (kuten saalis)
var smoker_temp := 18.0
var smoker_fuel := 0.0
var smoker_progress := 0.0  # 0..1
var smoker_burnt := 0.0  # 1 = karrella


func _ready() -> void:
	randomize()
	_setup_input()
	_setup_environment()
	# Latausruutu: maailma rakennetaan vaiheittain, ja ruutu päivittyy vaiheiden välissä (selaimessa rakennus kestää).
	# Testiajot (--shot) rakentavat kaiken kerralla ilman ruudunpäivityksiä kuten ennenkin.
	var loading := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			loading = false
	if loading:
		set_process(false)
		_loading_show()
		await get_tree().process_frame
		await get_tree().process_frame
	world = World.new()
	world.deferred = loading
	add_child(world)
	if loading:
		await world.build(_loading_step)
		await _loading_step.call("Mökki, Siitari ja Raahen baari", 0.97)
	home_zone = world.home_zone
	shop_zone = world.shop_zone
	var sb := M.w2(M.SHOP_BUILDING)
	shop_door = Vector3(sb.x + 11.0, 0, sb.y + 10.2)  # oven edusta (world.gd _build_shop: ovi x +11, julkisivu z +9)
	shop_door.y = Terrain.h(shop_door.x, shop_door.z)
	# Kodin etuovi (world.gd _build_home: ovi paikallisessa x = 1,2, porras julkisivun edessä; julkisivu HOME_YAW_DIR).
	var hb := M.w2(M.HOME_BUILDING)
	var hf := M.HOME_YAW_DIR.normalized()
	var hd := hb + Vector2(-hf.y, hf.x) * 1.2 + hf * 6.4
	home_door = Vector3(hd.x, Terrain.h(hd.x, hd.y), hd.y)
	var hbd := hb + Vector2(-hf.y, hf.x) * 1.2 - hf * 6.4
	home_back_door = Vector3(hbd.x, Terrain.h(hbd.x, hbd.y), hbd.y)
	lawn = Lawn.new()
	lawn.rect = world.lawn_rect
	lawn.pivot = world.lawn_pivot
	lawn.angle = world.lawn_angle
	lawn.mower_park = M.w(M.MOWER_PARK)
	add_child(lawn)
	var sl: Dictionary = world.sinikka_lawn
	sinikka_lawn = Lawn.new()
	sinikka_lawn.rect = Rect2(-sl.size / 2.0, sl.size)
	sinikka_lawn.pivot = sl.pivot
	sinikka_lawn.angle = sl.angle
	sinikka_lawn.mower_park = Vector3(sl.mower.x, Terrain.h(sl.mower.x, sl.mower.z), sl.mower.z)
	sinikka_lawn.kinds = []  # Sinikan nurmikolla ei siilejä eikä kiviä
	add_child(sinikka_lawn)
	_build_stash_props()
	_spawn_player()
	world.follow = player
	player.world = world
	_spawn_hazards()
	_spawn_interior()
	mokki = Mokki.new()
	mokki.position = MOKKI_POS
	add_child(mokki)
	mokki_int = MokkiInterior.new()
	mokki_int.position = MOKKI_INT_POS
	add_child(mokki_int)
	mokki_int.exited.connect(_on_mokki_exited)
	mokki_int.slept.connect(_on_mokki_slept)
	mokki_int.acted.connect(_on_mokki_acted)
	home_int = HomeInterior.new()
	home_int.position = HOME_INT_POS
	add_child(home_int)
	home_int.exited.connect(_on_home_exited)
	home_int.slept.connect(_on_home_slept)
	home_int.acted.connect(_on_home_acted)
	garage_int = GarageInterior.new()
	garage_int.position = GARAGE_INT_POS
	add_child(garage_int)
	garage_int.exited.connect(func() -> void: _on_garage_exited(false))
	garage_int.acted.connect(_on_garage_acted)
	mokki.sauna_event.connect(_on_sauna_event)
	siitari_int = SiitariInterior.new()
	siitari_int.position = SIITARI_INT_POS
	add_child(siitari_int)
	siitari_int.exited.connect(_on_siitari_exited)
	siitari_int.acted.connect(_on_siitari_acted)
	raahe_int = RaaheInterior.new()
	raahe_int.position = RAAHE_INT_POS
	add_child(raahe_int)
	raahe_int.exited.connect(_on_raahe_exited)
	raahe_int.acted.connect(_on_raahe_acted)
	raahe_int.paivi_caught.connect(_on_raahe_paivi_caught)
	fight = Fight.new()
	fight.position = Vector3(-3000, 0, 0)
	add_child(fight)
	fight.finished.connect(_on_fight_finished)
	var map_layer := CanvasLayer.new()
	map_layer.layer = 10
	add_child(map_layer)
	var paper := PaperMap.new()
	paper.world = world
	paper.player = player
	paper.game = self
	paper.mokki = mokki
	map_layer.add_child(paper)
	_paper = paper
	_inventory = Inventory.new()
	_inventory.game = self
	map_layer.add_child(_inventory)
	_drone_parked = Node3D.new()
	add_child(_drone_parked)
	_drone_parked.position = _drone_pad(false) + Vector3(0, 0.16, 0)
	DroneGame.make_model(_drone_parked)
	var amb := Ambience.new()
	amb.world = world
	amb.player_ref = func() -> Node3D: return player if state in ["to_shop", "to_home"] and not _in_vaala else null  # Vaalalla omat äänet
	add_child(amb)
	paper.bike = bike
	_build_hud()
	cutscene = Cutscene.new()
	cutscene.env = _env
	cutscene.sun = _sun
	cutscene.hide_nodes = [bike, walker_out]
	add_child(cutscene)
	tilat = DayStats.new()
	hommat = Hommat.new()
	story = Story.new()
	_load_game()
	if story.step == "avaimet":
		_place_keys()
	_stat_bars.stats = tilat
	_apply_day_base()
	_spawn_boys()
	lawn.spawn_objects()
	_roll_vaino()
	if laavu_conquered:
		guard.vanish()
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	menu = Menu.new()
	menu.game = self
	add_child(menu)
	var debug_shot := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot=") and not arg.ends_with("menu.png"):
			debug_shot = true
	Sfx.music_stop(0.8)  # esim. "Uusi peli" latasi kentän valikosta: musiikki pois, ellei valikko aukea
	# Ennen valikkoa: pelaajan kamera aktivoituu tässä, ja valikon kiertävän kameran pitää jäädä voimaan.
	var bike_note := "" if debug_shot else _apply_saved_bike()  # testikuvat alkavat aina pyörän selästä kotoa
	if not skip_menu and not debug_shot:
		menu.open_main()
	skip_menu = false
	if jemma > 0:
		_morning_info.append("Kotijemmoissa %d kaljaa." % jemma)
	if not _risky_stashes().is_empty():
		_morning_info.append("Varoitus: Päivi voi löytää täyden kotijemman!")
	var jemma_note := ""
	if _old_stash_lost > 0:
		jemma_note += "\nLöysin sun vanhat jemmat ja kaadoin %d kaljaa viemäriin!" % _old_stash_lost
		_morning_info.append("Nyt jemmoja on enemmän – jaa kaljat fiksusti.")
		_old_stash_lost = 0
		_save_game()
	if Settings.renderer_auto_saved:
		_morning_info.append("Yhteensopiva grafiikka on nyt käytössä myös tavallisella käynnistyksellä (vaihda Asetuksista).")
	jemma_note = bike_note + jemma_note + _lawn_nag()
	_roll_list()
	_day_note(MORNING_HEAD.koti.pick_random(), jemma_note)
	_flush_morning_info()
	if loading:
		_loading_hide()
		set_process(true)
	_maybe_screenshot()


var _loading_layer: CanvasLayer
var _loading_bar: ProgressBar
var _loading_text: Label


## Latausruutu: tumma tausta, pelin nimi, vaiheen nimi ja edistymispalkki.
func _loading_show() -> void:
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 100
	add_child(_loading_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_layer.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.offset_left = -280
	box.offset_right = 280
	box.offset_top = -110
	box.offset_bottom = 110
	box.add_theme_constant_override("separation", 14)
	_loading_layer.add_child(box)
	var title := Label.new()
	title.text = "NORMIPÄIVÄ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "S A L O I S I S S A"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	box.add_child(sub)
	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(560, 22)
	_loading_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.8, 0.2)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.18, 0.19, 0.22)
	_loading_bar.add_theme_stylebox_override("fill", fill)
	_loading_bar.add_theme_stylebox_override("background", back)
	box.add_child(_loading_bar)
	_loading_text = Label.new()
	_loading_text.text = "Ladataan..."
	_loading_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_text.add_theme_font_size_override("font_size", 20)
	box.add_child(_loading_text)


## Rakennusvaihe: teksti ja palkki päivittyvät, ja odotetaan kaksi ruutua, jotta ne ehtivät näkyä.
var _loading_step := func(text: String, frac: float) -> void:
	_loading_text.text = text + "..."
	_loading_bar.value = frac * 100.0
	await get_tree().process_frame
	await get_tree().process_frame


func _loading_hide() -> void:
	if _loading_layer != null:
		_loading_layer.queue_free()
		_loading_layer = null


func _process(delta: float) -> void:
	var at_mokki := _at_mokki()
	var away := at_mokki or _in_vaala  # poissa kylästä: Saloisten vaarat, liikenne ja kello odottavat
	if state in ["to_shop", "in_shop", "to_home", "fight"] and not away:
		elapsed += delta
	if _drone == null:
		drone_battery = minf(drone_battery + delta / DRONE_CHARGE_S, 1.0)  # latautuu alustalla
	if away and _hazards.process_mode != Node.PROCESS_MODE_DISABLED:
		_hazards.process_mode = Node.PROCESS_MODE_DISABLED  # Päivi ja muut vaarat jäävät Saloisiin
	if mokki != null and mokki.built:
		_puuhat_tick(at_mokki)

	_hint.text = ""
	if not away:
		_traffic_tick(delta)
	_indoor_eat()
	match state:
		"to_shop", "to_home":
			_outside_logic()
			if not _in_vaala:
				_mount_logic()  # Vaalassa mopon selkään ja pois: _vaala_logic
			if not away:
				_bike_theft(delta)
				_thief_tick(delta)
			_stats_tick(delta)
		"in_shop":
			_hint.text = interior.hint
		"in_siitari":
			if not _item_menu.is_open():
				_hint.text = siitari_int.hint
			tilat.add("humala", -0.002 * delta)
			tilat.add("stressi", 0.004 * delta)
			if _paivi_call_t > 0.0 and _hud.visible:  # karaoken aikana puhelin ei kuulu
				_paivi_call_t -= delta
				if _paivi_call_t <= 0.0:
					_paivi_calls()
		"in_raahe":
			if not _item_menu.is_open():
				_hint.text = raahe_int.hint
			# Päivi saattaa tulla etsimään (ei kesken minipelin tai valikon).
			if _raahe.get("paivi_t", -1.0) > 0.0 and not raahe_int.busy and not _item_menu.is_open():
				_raahe.paivi_t -= delta
				if _raahe.paivi_t <= 0.0:
					_raahe.paivi_came = true
					raahe_int.paivi_arrive()
					Sfx.play("alert", -2.0, 0.9)
					tilat.add("stressi", -0.1)
					_show_message("PÄIVI TULI BAARIIN ETSIMÄÄN SINUA! Pakoon: Kellariin portaita, ympäri pöytiä tai ulos taksiin.", 4.5)
			tilat.add("humala", -0.002 * delta)
			tilat.add("stressi", 0.004 * delta)
		"in_home":
			_hint.text = home_int.hint
			home_int.carrying = beers > 0 or has_kanister
			if home_int.spot == "kaappi":
				_stash_ui("koti")
			# Kotona on rauhallista kuten mökillä: stressi hellittää, nälkä kasvaa hiljaa.
			tilat.add("stressi", 0.005 * delta)
			tilat.add("nalka", -0.002 * delta)
			tilat.add("humala", -0.002 * delta)
		"in_garage":
			_hint.text = garage_int.hint
			if garage_int.spot == "kaappi":
				_stash_ui("autotalli")
			if garage_int.radio_on:
				tilat.add("stressi", 0.006 * delta)  # iskelmä rauhoittaa
				tilat.add("moraali", 0.002 * delta)
			tilat.add("nalka", -0.002 * delta)
		"in_mokki":
			_hint.text = mokki_int.hint
			_hommat_tick(delta)
			# Sisällä on rauhallista: stressi hellittää ja vireys nousee, nälkä kasvaa hiljaa.
			tilat.add("stressi", 0.005 * delta)
			tilat.add("vireys", 0.002 * delta)
			tilat.add("nalka", -0.002 * delta)
			tilat.add("humala", -0.002 * delta)
			if mokki_int.pa_on:
				tilat.add("moraali", 0.003 * delta)  # tunnari soi
	_update_hud()

	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			_msg.text = ""
	elif not _msg_queue.is_empty() and _hud.visible:
		var m: Array = _msg_queue.pop_front()
		_show_message(m[0], m[1])


## Lukitsematon pyörä: jos se on pitkään kaukana (ei kotipihassa), teinit vievät sen muualle.
func _bike_theft(delta: float) -> void:
	if player != walker_out or bike_in_garage:
		_bike_away_t = 0.0
		return
	var d := walker_out.global_position.distance_to(bike.global_position)
	var at_home := bike.global_position.distance_to(home_zone) < 25.0
	if d > 150.0 and not at_home:
		_bike_away_t += delta
	else:
		_bike_away_t = maxf(0.0, _bike_away_t - delta)
	if _bike_away_t > 60.0 and _thief.is_empty():
		_bike_away_t = 0.0
		if randf() < 0.6:
			_thief_start()


## Pyörävaras: teini ajaa pyörällä teitä ja polkuja pitkin (world.ride). Ensin kohti pelaajaa, 100 m:n päästä
## sinne tänne enintään 100 m:n päässä pelaajasta, kunnes hylkää pyörän (sieltä sen voi taas pölliä).
## Kiinni (3,5 m): teini hyppää selästä ja juoksee karkuun. Kartta (M) näyttää pyörän paikan koko ajan.
const THIEF_NEAR := 100.0
const THIEF_CATCH := 3.5
var _thief := {}  # vaihe, reitti, ajastimet; tyhjä = ei varkautta


func _thief_start() -> void:
	_thief = {"phase": "approach", "route": PackedVector3Array(), "replan": 0.0, "roam": randf_range(60.0, 120.0),
		"stuck": 0.0, "jam": 0.0, "hops": 0}
	bike.set_thief(Looks.TEENS.pick_random())
	bike.controls_enabled = false
	bike.autopilot = true
	tilat.add("stressi", -0.2)
	_show_message("Teini pölli lukitsemattoman pyöräsi ja ajelee sillä kylällä!\nKatso kartasta (M), ja ota kiinni.", 4.0)
	Sfx.play("alert", -4.0, 0.7)


func _thief_stop() -> void:
	if _thief.is_empty():
		return
	_thief.clear()
	bike.autopilot = false
	bike.set_thief({})
	bike.speed = 0.0


func _thief_tick(delta: float) -> void:
	if _thief.is_empty():
		return
	var bp := bike.global_position
	var pp := walker_out.global_position if player == walker_out else player.global_position
	var flat := func(a: Vector3, b: Vector3) -> float: return Vector2(a.x - b.x, a.z - b.z).length()
	var d: float = flat.call(bp, pp)
	if player == walker_out and d < THIEF_CATCH:
		_thief_stop()
		tilat.add("moraali", 0.15)
		tilat.first("pyoravaras", 0.3)
		Sfx.play("grunt", -4.0, 1.4)
		_show_message("Sait teinin kiinni! Teini hyppäsi pyörän selästä ja juoksi karkuun.", 3.5)
		return
	# Jumissa (aita, portti, jyrkänne): ensin ohitetaan reittipiste (stuck), pitkään jumissa (jam) teini nostaa
	# pyörän esteen yli seuraavaan pisteeseen; kolmannen kerran jälkeen kyllästyy ja hylkää pyörän.
	var slow: bool = absf(bike.speed) < 0.6
	_thief.stuck = _thief.stuck + delta if slow else 0.0
	_thief.jam = _thief.jam + delta if slow else 0.0
	var route: PackedVector3Array = _thief.route
	if _thief.jam > 6.0:
		_thief.jam = 0.0
		_thief.hops += 1
		if _thief.hops > 3 or route.is_empty():
			_thief_abandon()
			return
		var hop: Vector3 = route[0]
		bike.global_position = Vector3(hop.x, Terrain.h(hop.x, hop.z) + 0.4, hop.z)
		bike.velocity = Vector3.ZERO
		route.remove_at(0)
	if _thief.phase == "approach":
		_thief.replan -= delta
		if _thief.replan <= 0.0:
			_thief.replan = 4.0
			route = world.ride_route(bp, pp)
		if d < THIEF_NEAR:
			_thief.phase = "roam"
			route = PackedVector3Array()
	else:
		_thief.roam -= delta
		if _thief.roam <= 0.0:
			_thief_abandon()
			return
		if route.is_empty():
			# Seuraava risteys tai taite: satunnainen naapuri, joka pysyy 100 m:n sisällä pelaajasta (tai lähestyy).
			var id: int = world.ride.get_closest_point(Vector3(bp.x, 0, bp.z))
			var near: Array = []
			var best := -1
			var best_d := INF
			for n in world.ride.get_point_connections(id):
				var np: Vector3 = world.ride.get_point_position(n)
				var nd: float = flat.call(np, pp)
				if nd < THIEF_NEAR:
					near.append(n)
				if nd < best_d:
					best_d = nd
					best = n
			var pick: int = near.pick_random() if not near.is_empty() else best
			if pick >= 0:
				route = PackedVector3Array([world.ride.get_point_position(id), world.ride.get_point_position(pick)])
	# Reittipisteiden seuranta: saavutetut ja jo ohitetut pisteet pois (seuraava piste on lähempänä kuin
	# pisteiden väli), autopilotti kohti seuraavaa. Kääntösäde on vauhdissa ~4 m, joten säde on väljä.
	while route.size() > 0:
		var reached: bool = flat.call(route[0], bp) < 6.0
		var passed: bool = route.size() > 1 and flat.call(route[1], bp) < flat.call(route[0], route[1])
		if not (reached or passed or (_thief.stuck > 3.0 and route.size() > 1)):
			break
		route.remove_at(0)
		_thief.stuck = 0.0
	_thief.route = route
	if route.size() > 0:
		bike.auto_target = route[0]
	else:
		bike.auto_target = pp


func _thief_abandon() -> void:
	var where := _dist_text(walker_out.global_position, bike.global_position)
	_thief_stop()
	_show_message("Teini hylkäsi pyöräsi %s päähän. Katso kartasta (M)." % where, 3.5)


func _mount_logic() -> void:
	var e: bool = Input.is_action_just_pressed("mount") and not player.is_stunned()
	if bike_in_garage:
		if e and player == walker_out:
			_show_message("Pyörä on autotallissa. Hae se tallista.", 2.0)
		return
	if player == walker_out:
		var d: float = walker_out.global_position.distance_to(bike.global_position)
		if d < 2.6:
			if _hint.text == "":
				_hint.text = "[F] Nouse pyörän selkään" if beers <= CARRY_BIKE else \
					"Pyörän kyytiin mahtuu vain %d kaljaa (sinulla %d). Jemmaa tai juo loput." % [CARRY_BIKE, beers]
			if e:
				if beers > CARRY_BIKE:
					_show_message("Liikaa kaljaa pyörän kyytiin! Max %d, sinulla %d." % [CARRY_BIKE, beers], 2.5)
				else:
					_toggle_mount()
		elif e:
			if _at_mokki_pos(walker_out.global_position) != _at_mokki_pos(bike.global_position):
				_show_message("Pyörä jäi Saloisiin, %s päähän." % _dist_text(walker_out.global_position, bike.global_position), 2.5)
			else:
				_show_message("Pyörä on %s päässä." % _dist_text(walker_out.global_position, bike.global_position), 1.5)
	elif e:
		_toggle_mount()


func _outside_logic() -> void:
	if _item_menu.is_open():
		return  # esinevalikko ottaa E:n, W/S:n ja Q:n
	if _beast_tick():
		return  # huuto sudelle vei E:n
	if Input.is_action_just_pressed("eat") and not player.is_stunned():
		if _in_vaala and player == mopo_trip.mopo and absf(player.speed) > 3.0:
			_show_message("Hidasta ensin!", 1.2)
		else:
			_open_eat_menu()
			return
	if _in_vaala:
		_vaala_logic()
		return
	# Mökillä vain mökin omat toiminnot: kauppareissu, jemmat ja kylän tapahtumat odottavat Saloisissa.
	if _at_mokki():
		_drone_logic()
		_mokki_ride_logic()
		_viina_logic()
		_mokki_logic()
		return
	_compass.has_cache = false
	var ppos := player.global_position
	# Kompassin kohde poistuu, kun sinne päästään.
	if _paper.has_target and Vector2(ppos.x, ppos.z).distance_to(_paper.target) < 10.0:
		_paper.clear_target()
		Sfx.play("pickup", -10.0, 1.3)

	_lawn_logic()
	_atm_logic()
	_drone_logic()
	if player == bike and Input.is_action_just_pressed("bell") and mummot.distance_to_target() < 10.0:
		mummot.anger()  # kellon soitto mummojen vieressä suututtaa varmasti
	_edge_logic()
	_kota_logic()
	_laavu_logic()
	_stash_logic()
	_forage_logic()
	_boys_logic()
	_wound_logic()
	_errand_logic()
	_vaino_logic()
	_neighbor_logic()
	_story_logic()
	_pontikka_logic()
	_taxi_logic()
	_mokki_logic()
	if _hint.text != "":
		return  # jemma, Päivin ostokset, haava tai muu toiminto ovella menee edelle
	var p2 := Vector2(ppos.x, ppos.z)
	if p2.distance_to(Vector2(shop_door.x, shop_door.z)) < SHOP_DOOR_R:
		_shop_door_logic()
	elif world.garage_door != Vector3.ZERO and p2.distance_to(Vector2(world.garage_door.x, world.garage_door.z)) < DOOR_RADIUS:
		_garage_door_logic()
	elif p2.distance_to(Vector2(home_door.x, home_door.z)) < DOOR_RADIUS:
		_home_door_logic("ovi")
	elif p2.distance_to(Vector2(home_back_door.x, home_back_door.z)) < DOOR_RADIUS:
		_home_door_logic("takaovi")


## K-Marketin ovi: kauppaan milloin vain, kuten mihin tahansa hommaan, paitsi kalja kädessä (kauppias kieltää).
func _shop_door_logic() -> void:
	if player == bike:
		_hint.text = "Nouse pyörän selästä (F) ja kävele kauppaan"
		return
	_hint.text = "[E] Mene kauppaan"
	if not Input.is_action_just_pressed("interact") or player.is_stunned() or Engine.get_process_frames() == _shop_exit_frame:
		return
	if beers > 0 or has_kanister:
		Sfx.play("alert", -10.0, 1.3)
		_show_message("Kauppias ovella: \"%s\"" % SHOP_NO_BEER.pick_random(), 3.5)
		return
	_enter_shop()


## Kotiovi (etu- tai takaovi): sisälle milloin vain tyhjin käsin. Kaljat ja kanisteri ensin jemmaan, Päivi näkee.
## Päivä päättyy vasta, kun mennään nukkumaan parisänkyyn (home_interior.gd, _on_home_slept).
func _home_door_logic(door: String) -> void:
	if player == bike:
		_hint.text = "Nouse pyörän selästä (F) ja kävele ovelle"
		return
	var loaded := beers > 0 or has_kanister
	if loaded and door == "takaovi":
		_hint.text = "Takaovesta suoraan keittiöön – Päivi näkee %s! Mene etuovesta eteisen kaapille." % (
			"kanisterin" if beers <= 0 else "kaljat")
		return
	_hint.text = "[E] Mene sisälle kotiin" + (" takaovesta" if door == "takaovi" else "") + \
		(" (%s eteisen kaappiin, Päivi ei saa nähdä)" % ("kanisteri" if beers <= 0 else "kaljat") if loaded else "")
	if Input.is_action_just_pressed("interact") and not player.is_stunned() and Engine.get_process_frames() != _home_exit_frame:
		_enter_home(door)


var _home_exit_frame := -1  # ulos tullessa painettu E ei vie heti takaisin sisään


## Testit: kotiin tai talliin ja sisäjemman kaapin eteen.
func _test_goto_stash(id: String) -> void:
	walker_out.global_position = (home_door if id == "koti" else world.garage_door) + Vector3(0, 0.3, 0)
	walker_out.velocity = Vector3.ZERO
	for i in 3:
		await get_tree().physics_frame
	if id == "koti":
		_enter_home("ovi")
		home_int.walker.position = HomeInterior.SPOTS.kaappi[0]
	else:
		_enter_garage()
		garage_int.walker.position = GarageInterior.SPOTS.kaappi[0]
	for i in 5:
		await get_tree().physics_frame
	for i in 3:
		await get_tree().process_frame


## Autotallin nosturiovi: jalan sisään (kaljat saa kantaa, työkalukaappi on sisällä), pyörällä pyörä talliin.
func _garage_door_logic() -> void:
	var e: bool = Input.is_action_just_pressed("interact") and not player.is_stunned() \
		and Engine.get_process_frames() != _garage_exit_frame
	if player == bike:
		_hint.text = "[E] Vie pyörä talliin"
		if e:
			if absf(bike.speed) > 3.0:
				_show_message("Hidasta ensin!", 1.2)
				return
			_toggle_mount()
			_store_bike(true)
			_enter_garage()
		return
	_hint.text = "[E] Mene autotalliin" + (" (pyörä on tallissa)" if bike_in_garage else "")
	if e:
		_enter_garage()


## Pyörä talliin (piiloon, ei varkaita) tai pois.
func _store_bike(on: bool) -> void:
	bike_in_garage = on
	bike.visible = not on
	bike.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if on:
		bike.global_position = world.garage_door - world.garage_out * 3.0 + Vector3(0, 0.3, 0)


func _enter_garage() -> void:
	_garage_prev = state
	state = "in_garage"
	player.controls_enabled = false
	player.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	tilat.first("autotalli_sisalla", 0.1)
	garage_int.enter(bike_in_garage)
	garage_int.walker.set_carrying(beers > 0 or has_kanister)
	Sfx.play("door", -3.0, 0.7)


func _on_garage_exited(with_bike: bool) -> void:
	if state != "in_garage":
		return
	garage_int.leave()
	Sfx.play("door_close", -3.0, 0.7)
	state = _garage_prev
	_garage_exit_frame = Engine.get_process_frames()
	var out: Vector3 = world.garage_out
	walker_out.global_position = world.garage_door + out * 0.6 + Vector3(0, 0.3, 0)
	walker_out.look_at(walker_out.global_position + out, Vector3.UP)
	walker_out.velocity = Vector3.ZERO
	walker_out.controls_enabled = true
	walker_out.activate_camera()
	walker_out.set_carrying(beers > 0)
	_hazards.process_mode = Node.PROCESS_MODE_INHERIT
	if with_bike:
		_store_bike(false)
		bike.global_position = world.garage_door + out * 1.6 + Vector3(0, 0.4, 0)
		bike.look_at(bike.global_position + out, Vector3.UP)
		if beers > CARRY_BIKE:
			_show_message("Pyörä ulkona, mutta kyytiin mahtuu vain %d kaljaa." % CARRY_BIKE, 2.5)
		else:
			_toggle_mount()


func _on_garage_acted(kind: String) -> void:
	match kind:
		"auto":
			_start_carb()
		"tyopoyta":
			if not bike_in_garage:
				_show_message("Työpöydällä ruuvipenkki, jakoavaimia ja tyhjiä tölkkejä. Tuo pyörä talliin, niin sen voi huoltaa.", 3.5)
			elif _bike_tuned:
				_show_message("Pyörä on jo huollettu tänään. Ketju kiiltää.", 2.0)
			else:
				_bike_tuned = true
				bike.tune = BIKE_TUNE
				Sfx.play("rattle", -6.0, 1.2)
				tilat.first("pyora_huolto", 0.3)
				_show_message("Ketju öljytty, renkaat pumpattu ja jarrut säädetty. Pyörä kulkee tänään kevyemmin!", 3.5)
		"arkku":
			if not _freezer_bottle:
				_freezer_bottle = true
				viina_pullot += 1
				Sfx.play("glass", -6.0, 0.8)
				_show_message("Arkun pohjalta, makkaroiden alta löytyi jäinen Koskenkorva! (kätköviina, T)", 3.5)
			elif _once_today("arkku"):
				_eat(0.15)
				tilat.add("stressi", 0.08)
				Sfx.play("pickup", -6.0, 0.7)
				_show_message("Pakastearkusta löytyi mehujää. Virkistää!", 2.5)
			else:
				_show_message("Pakastearkussa on vain Päivin marjoja ja vuoden 2019 makkaroita.", 2.5)
		"radio":
			_show_message("Radio Iskelmä soi. Stressi hellittää." if garage_int.radio_on else "Radio hiljeni.", 2.0)
		"pyora":
			_on_garage_exited(true)


## Karburaattorin säätö autotallissa (carb_game.gd).
func _start_carb() -> void:
	garage_int.busy = true
	garage_int.walker.controls_enabled = false
	_hud.visible = false
	var g := CarbGame.new()
	g.drunk = _hand_shake()
	g.finished.connect(func(ok: bool) -> void:
		garage_int.busy = false
		garage_int.walker.controls_enabled = true
		_hud.visible = true
		if ok:
			if _once_today("karburaattori"):
				tilat.add("moraali", 0.15)
				tilat.add("stressi", 0.1)
			tilat.first("karburaattori", 0.4)
			Sfx.play("win_small", -4.0)
			_show_message(["SLN-73 hurisee kuin kissa! Ei sillä mihinkään ajeta, mutta kuitenkin.",
				"Tasainen tyhjäkäynti. Tätä ei Päivi ymmärrä."].pick_random(), 3.5)
		else:
			_show_message("Karburaattori jäi vielä vähän sinne päin. Huomenna uusiks.", 2.5))
	add_child(g)


func _enter_home(door: String) -> void:
	_home_prev = state
	state = "in_home"
	player.controls_enabled = false
	player.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	tilat.first("koti_sisalla", 0.1)
	home_int.carrying = beers > 0 or has_kanister
	home_int.enter(door)
	home_int.walker.set_carrying(beers > 0 or has_kanister)
	Sfx.play("door", -3.0)


func _on_home_exited() -> void:
	home_int.leave()
	Sfx.play("door_close", -3.0)
	state = _home_prev
	_home_exit_frame = Engine.get_process_frames()
	var back: bool = home_int.exit_door == "takaovi"
	var hf := M.HOME_YAW_DIR.normalized()
	var out := Vector3(-hf.x, 0, -hf.y) if back else Vector3(hf.x, 0, hf.y)
	walker_out.global_position = (home_back_door if back else home_door) + out * 1.0 + Vector3(0, 0.3, 0)
	walker_out.look_at(walker_out.global_position + out, Vector3.UP)
	walker_out.velocity = Vector3.ZERO
	walker_out.controls_enabled = true
	walker_out.activate_camera()
	walker_out.set_carrying(beers > 0)
	_hazards.process_mode = Node.PROCESS_MODE_INHERIT


## Parisänkyyn nukkumaan: päivä päättyy kuten ennen kotiovella (Päivin ostokset, palkinto, jemmat, uusi päivä).
func _on_home_slept() -> void:
	home_int.leave()
	state = _home_prev
	_win()


## Vessanpönttö (koti, mökin pesuhuone, mökin huussi): ensin kysytään ykkönen vai kakkonen (esinevalikko), sitten
## minipeli (wc_game.gd) ja lopuksi tulos (_wc_result).
var _wc_where := ""
## Juoksukaljat: kauppias perässä (shop_chaser.gd). Saloisissa taksiin ehtii juuri ja juuri, Vaalassa ei taksia.
var _shop_chaser: Node3D = null
var _chase_viina := 0  # Vaalassa juostut Koskenkorvat (kauppias ottaa takaisin, jos voittaa)
var _wc_game: CanvasLayer  # käynnissä oleva minipeli (testit)


func _wc_walker() -> CharacterBody3D:
	match _wc_where:
		"koti":
			return home_int.walker
		"mokki":
			return mokki_int.walker
	return walker_out


func _wc_busy(on: bool) -> void:
	if _wc_where == "koti":
		home_int.busy = on
		if not on:
			home_int._enter_frame = Engine.get_process_frames()  # valinnan E ei käynnistä pistettä uudelleen
	elif _wc_where == "mokki":
		mokki_int.busy = on
		if not on:
			mokki_int._enter_frame = Engine.get_process_frames()


func _open_wc_menu(where: String) -> void:
	_wc_where = where
	_wc_busy(true)
	var w := _wc_walker()
	w.controls_enabled = false
	if "speed" in w:
		w.speed = 0.0
	_menu_mode = "wc"
	_item_menu.open([["ykkonen", "Ykkönen – pikkunen hätä"], ["kakkonen", "Kakkonen – isompi asia"]], WC_ASK.pick_random())


func _wc_release() -> void:
	_wc_busy(false)
	_wc_walker().controls_enabled = true
	_hud.visible = true


func _start_wc(mode: String) -> void:
	_menu_mode = "give"
	_hud.visible = false
	var g := WcGame.new()
	g.mode = mode
	g.drunk = _hand_shake()
	g.flush = _wc_where != "huussi"
	g.finished.connect(_wc_result)
	add_child(g)
	_wc_game = g


## Minipelin tulos: helpotus (kerran päivässä), ja sotku tai tukos saa kotona Päivin tai nörtin, mökillä Santun
## huomauttamaan.
func _wc_result(mode: String, r: Dictionary) -> void:
	var where := _wc_where
	_wc_release()
	tilat.first(mode, 0.1)
	var who := "Päivi" if where == "koti" else "Santtu"
	if mode == "ykkonen":
		if not r.done:
			_show_message("Jäi kesken. Hätä palaa kyllä.", 2.0)
			return
		var acc: float = r.accuracy
		if _once_today("wc_ykkonen"):
			tilat.add("stressi", 0.05)
		if acc >= 0.85:
			_show_message("Napakymppi! Ei tippaakaan ohi.", 2.5)
		elif acc >= 0.6:
			_show_message("Melkein kaikki pönttöön. Pari tippaa reunalle.", 2.5)
		else:
			tilat.add("moraali", -0.05)
			if where == "koti":
				_show_message("Lattia lainehtii! %s huutaa: \"Kuka on taas pissiny lattialle?! Istualtaan jatkossa!\"" % who, 4.0)
			else:
				_show_message("Lattia lainehtii! %s: \"Superhost huomaa kaiken. Lattia pyyhitään!\"" % who, 4.0)
				if hommat.active:
					hommat.add_hermo(3.0)
		return
	if not r.done:
		_show_message("Jäi kesken. Tuntuu vielä.", 2.0)
		return
	var lines: Array[String] = []
	if _once_today("wc_kakkonen"):
		tilat.add("stressi", 0.15)
		tilat.add("vireys", 0.05)
	if r.hard > 0:
		tilat.add("kipu", -0.05 * r.hard)
		lines.append("Liian kovaa ponnistettu, peräpukamat muistuttaa.")
	if r.clog:
		tilat.add("moraali", -0.1)
		if where == "koti":
			lines.append("Pönttö tukossa! Nörtti huutaa: \"Kuka tukki taas pöntön? Mää en ainakaan!\"")
		else:
			lines.append("Pönttö tukossa! %s: \"Mökin viemäri ei vedä noin paljoa paperia!\"" % who)
			if hommat.active:
				hommat.add_hermo(5.0)
	elif r.sheets < WcGame.PAPER_OK.x:
		tilat.add("moraali", -0.05)
		lines.append("Säästeliäs paperinkäyttö. Toivottavasti riitti.")
	else:
		lines.append("Siistiä työtä." + (" Vettä perään." if where != "huussi" else " Huussin luukku kiinni."))
	_show_message("\n".join(lines), 3.5)


## Kodin sisätoiminnot: tilavaikutukset (kerran päivässä) ja viestit.
func _on_home_acted(kind: String) -> void:
	match kind:
		"kahvi":
			if _once_today("kahvi"):
				tilat.add("vireys", 0.2)
				tilat.add("stressi", 0.1)
			_show_message("Kahvit keitetty. Päivin Juhla Mokkaa, ei mitään suodatinhienouksia.", 2.5)
		"jaakaappi":
			if _once_today("koti_jaakaappi"):
				food["pulla"] = food.get("pulla", 0) + 1
				_show_message("Jääkaapissa oli Päivin pullaa. Otit yhden evääksi (T syö).", 3.0)
			else:
				_show_message("Jääkaapissa on vain nörtin energiajuomia ja sinappia.", 2.5)
		"tv":
			if _once_today("tv"):
				tilat.add("stressi", 0.05)
				tilat.add("kokemus", -0.02)
			_show_message("\"%s\"" % TV_SHOWS.pick_random(), 3.0)
		"sohva":
			if _once_today("sohva"):
				tilat.add("vasymys", 0.2)
				tilat.add("stressi", 0.1)
				_show_message("Nokoset sohvalla. Väsymys hellittää.", 2.5)
			else:
				_show_message("Ei enää nukuta. Sohva on Päivin mielestä muutenkin liikaa käytössä.", 2.5)
		"suihku":
			if _once_today("suihku"):
				tilat.add("vireys", 0.1)
				tilat.add("kipu", 0.05)
			Sfx.play("water", -6.0, 1.1, 3.0)  # suihku
			_show_message("Suihku virkistää.", 2.0)
		"wc":
			_open_wc_menu("koti")
		"peili":
			_show_message(["Peilistä katsoo normimies. Tuulipuku istuu.", "Vähän väsyneen näkönen. Normipäivä.",
				"Parta kasvaa, kalja ei."].pick_random(), 2.5)
		"sauna":
			tilat.first("kotisauna", 0.2)
			walker_out.stamina = 100.0
			walker_out.exhausted = false
			if _once_today("kotisauna"):
				tilat.add("stressi", 0.2)
				tilat.add("vasymys", 0.2)
				tilat.add("kipu", 0.1)
			Sfx.play("water", -6.0, 0.8, 2.5)  # löyly
			_show_message("Kotisaunan löylyt! Kunto palautui.", 2.5)
		"nortti":
			tilat.first("nortti", 0.1)


## Jemmat: jalan E piilottaa yhden kaljan (Shift+E kaikki), Q ottaa yhden (Shift+Q niin monta kuin jaksaa kantaa,
## jalan enintään 12). Pontikkakanisteri piilotetaan E:llä kotijemmaan (= KANISTER_BEERS kaljaa, kattoa ei
## katsota). Kotiinpaluussa kaikki piilotetaan itse: ovi aukeaa vasta tyhjin käsin.
func _stash_logic() -> void:
	if _hint.text != "" or player != walker_out or player.is_stunned():
		return
	var p := player.global_position
	for id in STASHES:
		if id in INDOOR_STASHES:
			continue  # eteisen kaappi ja tallin työkalukaappi ovat sisällä (_stash_ui sisätiloista)
		var at := _stash_pos(id)
		if Vector2(p.x - at.x, p.z - at.z).length() > 2.6:
			continue
		if id == "laavu" and not laavu_conquered:
			return
		_stash_ui(id)
		return


## Jemman vihje ja näppäimet: ulkona _stash_logic, sisällä eteisen kaappi (koti) ja tallin työkalukaappi.
func _stash_ui(id: String) -> void:
	var st: Dictionary = STASHES[id]
	var have: int = stash.get(id, 0)
	var room: int = maxi(0, st.cap - have)
	var can_take := mini(CARRY_FOOT - beers, have)
	var all := Input.is_key_pressed(KEY_SHIFT)
	var opts: Array[String] = []
	var kanister: bool = has_kanister and st.home
	# Kotipiiloissa 24 kaljaa: tyhjin käsin kotipiilolla E aloittaa juhlat (onnellinen loppu, _win(true)).
	var party: bool = st.home and jemma >= JEMMA_GOAL and beers <= 0 and not has_kanister
	if party:
		opts.append("[E] Aloita juhlat autotallissa (kotipiiloissa %d kaljaa)" % jemma)
	elif kanister:
		opts.append("[E] Piilota kanisteri (= %d kaljaa)" % KANISTER_BEERS)
	elif beers > 0 and room > 0:
		opts.append("[E] Piilota 1 · Shift+E %d" % mini(beers, room))
	if can_take > 0:
		opts.append("[Q] Ota 1 · Shift+Q %d" % can_take)
	var head := "%s: %d/%d kaljaa" % [st.name.left(1).to_upper() + st.name.substr(1), have, st.cap]
	if opts.is_empty():
		_hint.text = head + (" – täynnä." if room == 0 and beers > 0 else (" – kädet täynnä." if have > 0 else " – tänne voi piilottaa kaljoja."))
		return
	_hint.text = head + "   " + "   ".join(opts)
	if Input.is_action_just_pressed("interact") and party:
		_leave_interior_quiet()
		_win(true)
		return
	if Input.is_action_just_pressed("interact") and kanister:
		_stash_add(id, KANISTER_BEERS)
		has_kanister = false
		walker_out.set_kanister(false)
		_set_beer_carry()
		_stashed_today += KANISTER_BEERS
		Sfx.play("pickup", -2.0, 0.6)
		_show_message("Kanisteri piiloon %s (= %d kaljaa, siellä nyt %d).%s" % [st.into, KANISTER_BEERS, stash[id],
			_stash_warning(id)], 3.0)
	elif Input.is_action_just_pressed("interact") and beers > 0 and room > 0:
		var n := mini(beers, room) if all else 1
		_stash_add(id, n)
		beers -= n
		_stashed_today += n
		_set_beer_carry()
		Sfx.play("pickup", -2.0, 0.8)
		if all or beers == 0:
			_show_message("Piilotit %d kaljaa %s (siellä %d).%s%s" % [n, st.into, stash[id], _stash_warning(id),
				("\nKotipiiloissa %d kaljaa: juhlat voi aloittaa kotipiilolta (E)!" % jemma) if st.home and jemma >= JEMMA_GOAL and beers == 0 else ""], 3.0)
	elif Input.is_action_just_pressed("bell") and can_take > 0:
		var n := can_take if all else 1
		_stash_add(id, -n)
		_stashed_today = maxi(0, _stashed_today - n)
		beers += n
		_set_beer_carry()
		Sfx.play("pickup")
		if all:
			_show_message("Otit %d kaljaa %s.%s" % [n, st.from,
				("\nPyörän kyytiin mahtuu vain %d." % CARRY_BIKE) if beers > CARRY_BIKE else ""], 3.0)
	return


## Kantaminen näkyy ulkokävelijällä ja sisätilan kävelijällä.
func _set_beer_carry() -> void:
	walker_out.set_carrying(beers > 0)
	var w := _active_walker()
	if w != walker_out and w.has_method("set_carrying"):
		w.set_carrying(beers > 0 or has_kanister)
	if state == "in_home":
		home_int.carrying = beers > 0 or has_kanister


## Sisätilasta suoraan tapahtumaan (juhlat): sisätila suljetaan ja palataan ulkotilaan ilman ovianimaatiota.
func _leave_interior_quiet() -> void:
	if state == "in_home":
		home_int.leave()
		state = _home_prev
	elif state == "in_garage":
		garage_int.leave()
		state = _garage_prev
	_hazards.process_mode = Node.PROCESS_MODE_INHERIT


## Jemman paikka maailmassa.
func _stash_pos(id: String) -> Vector3:
	match id:
		"koti":
			return home_door  # eteisen kaappi (sisällä)
		"autotalli":
			return world.garage_door if world.garage_door != Vector3.ZERO else M.w(M.GARAGE)  # työkalukaappi (sisällä)
		"komposti":
			return M.w(M.COMPOST)
		"laavu":
			return M.w(M.LAAVU) + Vector3(4.6, 0, 2.8)
		"grilli":
			return M.w(M.GRILLIKATOS)
		"torni":
			return world.kota.to_global(Kota.TOWER_LOCAL) if world.kota != null else M.w(M.KOTA)
	return Vector3.ZERO


func _stash_add(id: String, n: int) -> void:
	if n > 0 and STASHES[id].home and story.step == "kaljat":
		_story_step("pekka_kutsuu")
	stash[id] = maxi(0, stash.get(id, 0) + n)
	if n > 0 and not id in stash_used:
		stash_used.append(id)
	jemma_best = maxi(jemma_best, jemma)
	_save_game()


## Päivin löytämisriski yhdelle kotijemmalle (0, jos jemmassa on vain huomaamaton määrä).
func _find_chance(id: String) -> float:
	var st: Dictionary = STASHES[id]
	var over: int = stash.get(id, 0) - st.safe
	return clampf(over * 0.04 * st.find, 0.0, 0.5) if over > 0 else 0.0


## Kotijemmat, joissa on jo riskialtis määrä kaljaa.
func _risky_stashes() -> Array[String]:
	var out: Array[String] = []
	for id in STASHES:
		if STASHES[id].home and _find_chance(id) > 0.0:
			out.append(id)
	return out


func _stash_warning(id: String) -> String:
	if STASHES[id].home:
		if _find_chance(id) > 0.0:
			return "\nVAROITUS: %s on jo niin täynnä, että Päivi voi löytää sen! Jaa kaljat muihin jemmoihin." % STASHES[id].name
		return ""
	return "\nMuista: teinit voivat pölliä täältä."


## Paperikartan jemmamerkit: [maailman x/z, lyhyt nimi, kaljat, kotijemma].
func stash_markers() -> Array:
	var out := []
	for id in stash_used:
		if STASHES.has(id):
			var at := _stash_pos(id)
			out.append([Vector2(at.x, at.z), STASHES[id].short, stash.get(id, 0), STASHES[id].home])
	return out


## Kompostilaatikko kotipihalle (jemma).
func _build_stash_props() -> void:
	var cp := M.w(M.COMPOST)
	var wood := Color(0.42, 0.3, 0.18)
	var comp := B.box(self, Vector3(1.4, 0.9, 1.4), cp + Vector3(0, 0.45, 0), wood)
	for k in 4:
		B.mesh(comp, B.boxm(Vector3(1.46, 0.06, 1.46)), Vector3(0, -0.35 + k * 0.22, 0), wood.darkened(0.25))
	B.mesh(comp, B.boxm(Vector3(1.3, 0.05, 1.3)), Vector3(0, 0.44, 0), Color(0.25, 0.2, 0.12))


func _bucket_total() -> int:
	var t := 0
	for k in bucket:
		t += bucket[k]
	return t


## Marja- ja sienipaikat: pysähdy mättään viereen ja poimi E:llä.
func _forage_logic() -> void:
	var p := player.global_position
	if _pick_t >= 0.0:
		var dt := get_process_delta_time()
		_pick_t += dt
		var sd := Vector2(_pick_spot.pos.x - p.x, _pick_spot.pos.z - p.z).length()
		if sd > 4.5 or player != walker_out:
			_stop_picking()
			return
		if _pick_spot.kind in BERRIES:
			_pick_berries(dt)
			return
		_hint.text = "Poimitaan %s... %d" % [GOODS[_pick_spot.kind].name, ceili(PICK_TIME - _pick_t)]
		if _pick_t >= PICK_TIME:
			_pick_done()
		return
	if _hint.text != "":
		return
	var near: Array = world.nearest_forage(p)
	if near[0].is_empty() or near[1] > 3.2:
		return
	var f: Dictionary = near[0]
	if player == bike:
		_hint.text = "Täällä on %s! Nouse pyörän selästä poimimaan (F)." % GOODS[f.kind].name
		return
	if _bucket_total() >= BUCKET_MAX:
		_hint.text = "Ämpäri täynnä (%d l). Myy naapureille!" % BUCKET_MAX
	else:
		_hint.text = "[E] Poimi %s" % GOODS[f.kind].name
		if Input.is_action_just_pressed("interact") and not player.is_stunned():
			_pick_t = 0.0
			_pick_spot = f
			player.speed = 0.0
			if f.kind in BERRIES:
				# A/D ovat poimiessa kyykky ja ylös, joten hahmo ei käänny niistä.
				_pick_meter = 0.0
				_pick_down = false
				_pick_idle = PICK_IDLE
				_pick_locked = true
				walker_out.controls_enabled = false
			else:
				_grunt()  # kumartuu sienen luo


## Ähkäisy kumartuessa tai noustessa (chance = todennäköisyys); lyhyt tauko ettei ähinä mene päällekkäin.
func _grunt(chance := 1.0) -> void:
	if Time.get_ticks_msec() < _grunt_next or randf() > chance:
		return
	_grunt_next = Time.get_ticks_msec() + GRUNT_GAP_MS
	Sfx.play("grunt", -6.0, randf_range(0.92, 1.08))


## Marjat: kyykkyyn (A) ja ylös (D) vuorotellen oikeaan tahtiin täyttää poimintamittarin. Väärä nappi tai
## hätäinen räpellys pudottaa marjoja, tauolla mittari valuu. Kyykkiminen kuluttaa kuntoa, ja tyhjällä
## kunnolla selkä pakottaa tauolle. W/S lopettaa.
func _pick_berries(dt: float) -> void:
	if Input.is_action_just_pressed("forward") or Input.is_action_just_pressed("back"):
		_stop_picking()
		return
	var goods: String = GOODS[_pick_spot.kind].name
	_pick_idle += dt
	if walker_out.exhausted:
		walker_out.pose = ""
		_hint.text = "Selkä! Suorista hetki ennen kuin jatkat %s poimintaa. (W/S lopettaa)" % goods
		return
	walker_out.stamina = maxf(0.0, walker_out.stamina - BEND_DRAIN * dt)
	if walker_out.stamina <= 0.0:
		walker_out.exhausted = true
		walker_out.pose = ""
		_show_message("Oho, selkä! Pakko pitää tauko.", 1.5)
		Sfx.play("groan", -2.0)
		return
	var want := "right" if _pick_down else "left"
	var other := "left" if _pick_down else "right"
	if Input.is_action_just_pressed(want):
		if _pick_idle < PICK_TOO_FAST:
			_pick_meter -= PICK_FUMBLE
		else:
			_pick_meter += PICK_GAIN
		_grunt(lerpf(0.25, 0.8, 1.0 - walker_out.stamina / 100.0))  # väsyneenä ähistään tiheämmin
		_pick_down = not _pick_down
		walker_out.pose = "Crouch_Idle" if _pick_down else ""
		_pick_idle = 0.0
	elif Input.is_action_just_pressed(other):
		_pick_meter -= PICK_FUMBLE
		_pick_idle = 0.0
		Sfx.play("rattle", -12.0, 1.4)
	elif _pick_idle > PICK_IDLE:
		_pick_meter -= PICK_DECAY * dt
	_pick_meter = clampf(_pick_meter, 0.0, 1.0)
	var bar := "▮".repeat(roundi(_pick_meter * 10.0)) + "▯".repeat(10 - roundi(_pick_meter * 10.0))
	_hint.text = "Poimitaan %s %s   %s   (W/S lopettaa)" % [goods, bar, "[D] ylös" if _pick_down else "[A] kyykkyyn"]
	if _pick_meter >= 1.0:
		_pick_done()


func _pick_done() -> void:
	var liters: int = mini(world.FORAGE_KINDS[_pick_spot.kind].liters, BUCKET_MAX - _bucket_total())
	bucket[_pick_spot.kind] = bucket.get(_pick_spot.kind, 0) + liters
	_pick_spot.taken = true
	tilat.first("poiminta_" + _pick_spot.kind)
	# Kyykkiminen väsyttää, mutta metsässä olo virkistää.
	tilat.add("vasymys", -0.05)
	tilat.add("stamina", -0.05)
	tilat.add("vireys", 0.1)
	_pick_spot.node.visible = false
	_show_message("+%d l %s ämpäriin" % [liters, GOODS[_pick_spot.kind].name], 2.0)
	Sfx.play("pickup", -4.0, 1.2)
	if not (_pick_spot.kind in BERRIES):
		_grunt()  # nousee ylös sienen kanssa
	_stop_picking()


## Poiminta loppuu. restore = palauta ohjaus (ei, jos tappelu tai uusi päivä hoitaa sen).
func _stop_picking(restore := true) -> void:
	_pick_t = -1.0
	walker_out.pose = ""
	if _pick_locked and restore:
		walker_out.controls_enabled = true
	_pick_locked = false


## Nurmikon leikkuu: leikkurin luona E käynnistää ja E sammuttaa. Siili tai kivi terään on ikävä juttu.
func _lawn_logic() -> void:
	if mowing:
		_mow()
		return
	if _hint.text != "" or player != walker_out or player.is_stunned():
		return
	var p := player.global_position
	var mp: Vector3 = lawn.mower.global_position
	if Vector2(p.x - mp.x, p.z - mp.z).length() > 1.6:
		return
	var e := Input.is_action_just_pressed("interact")
	if mower_broken:
		if not has_mower_part:
			_hint.text = "Leikkuri on rikki. Varaosa Artolta ja kalja, niin korjataan."
		elif beers <= 0:
			_hint.text = "Varaosa on, mutta ilman kaljaa ei korjata. Kalja kaupasta tai jemmasta."
		else:
			_hint.text = "[E] Korjaa leikkuri (kalja samalla)"
			if e:
				mower_broken = false
				has_mower_part = false
				lawn_kivet = 0
				beers -= 1
				player.set_carrying(beers > 0)
				Sfx.play("rattle_hard", -4.0, 1.2)
				_drink(1)
				_show_message("Uusi terä paikalleen ja kalja naamaan. Leikkuri toimii!", 3.0)
				_save_game()
		return
	var ratio: float = lawn.cut_ratio()
	var cm := roundi(lawn.avg_len() * 100.0)
	if ratio >= LAWN_DONE:
		_hint.text = "Nurmikko on leikattu. Huomenna se on taas pidempi."
		return
	_hint.text = "[E] Leikkaa nurmikko (%d cm, leikattu %d %%)" % [cm, roundi(ratio * 100.0)]
	if e:
		_start_mowing(lawn)


func _start_mowing(which: Node3D) -> void:
	mowing = true
	_mow_lawn = which
	walker_out.no_run = true
	walker_out.rotation.y = which.mower.rotation.y
	walker_out.global_position = which.mower.global_position + which.mower.global_transform.basis.z * Lawn.HEAD + Vector3(0, 0.3, 0)
	walker_out.velocity = Vector3.ZERO
	which.set_running(true)
	Sfx.play("pedal_creak", -4.0, 0.6)
	if which == mokki_lawn:
		_show_message("Santun vanha leikkuri yskähti käyntiin! Varo kiviä.", 3.0)
	else:
		_show_message("Leikkuri käy! Katso tarkkaan: pitkässä ruohossa on siilejä ja kiviä.", 3.0)


## Leikkuri sammuu ja jää siihen, missä se on.
func _stop_mowing() -> void:
	if not mowing:
		return
	mowing = false
	walker_out.no_run = false
	_mow_lawn.set_running(false)


func _mow() -> void:
	var dt := get_process_delta_time()
	var ml: Node3D = _mow_lawn
	tilat.add("vasymys", -0.004 * dt)  # leikkurin työntäminen väsyttää
	tilat.add("nalka", -0.003 * dt)
	ml.push_mower(walker_out)
	if not ml.has_point(walker_out.global_position, 3.0):
		_stop_mowing()
		_show_message("Leikkuri jäi pihan reunalle.", 2.0)
		return
	var head: Vector2 = ml.head_pos()
	var hit: Dictionary = ml.hit_test(head)
	if not hit.is_empty():
		if ml == mokki_lawn:
			_mokki_lawn_hit(hit)
		else:
			_lawn_hit(hit)
		if not mowing:
			return
	ml.cut(head, Lawn.BLADE_R)
	var ratio: float = ml.cut_ratio()
	if ml == sinikka_lawn:
		if ratio >= LAWN_DONE:
			_stop_mowing()
			story.done.nurmikko = true
			sinikka.say("Voi kuinka siisti! Tuu joskus muulloinkin... leikkaamaan.")
			Sfx.play("win_small")
			_show_message("Sinikan nurmikko leikattu!", 3.0)
			_story_check_tasks()
			return
		_hint.text = "Leikataan Sinikan nurmikkoa... %d %%   W/S/A/D ohjaa · [E] sammuta" % roundi(ratio * 100.0)
		if Input.is_action_just_pressed("interact"):
			_stop_mowing()
		return
	if ml == mokki_lawn:
		if ratio >= LAWN_DONE:
			_stop_mowing()
			_hommat_complete("nurmi")
			return
		_hint.text = "Leikataan... %d %%   W/S/A/D ohjaa · [E] sammuta" % roundi(ratio * 100.0)
		if Input.is_action_just_pressed("interact"):
			_stop_mowing()
		return
	if ratio >= LAWN_DONE and not _lawn_done_today:
		_lawn_done_today = true
		_lawn_praise = true
		_task_done(true)
		tilat.first("nurmikko", 0.4)
		_stop_mowing()
		Sfx.play("win_small")
		_show_message("Nurmikko leikattu! Päivi on tyytyväinen.\nHuomenna tulee %s € ylimääräistä kauppaan." % _eur(LAWN_BONUS), 4.0)
		_save_game()
		return
	_hint.text = "Leikataan... %d %%   W/S/A/D ohjaa · [E] sammuta" % roundi(ratio * 100.0)
	if Input.is_action_just_pressed("interact"):
		_stop_mowing()


## Droonin alusta kotipihalla tai mökin pihalla: jalan E lähettää droonin ilmaan. Drooni kulkee mukana, joten
## se odottaa sen paikan alustalla, jossa pelaaja on.
func _drone_logic() -> void:
	var at_m := _at_mokki()
	var parked := _drone_pad(at_m) + Vector3(0, 0.16, 0)
	if _drone_parked.position.distance_to(parked) > 0.5:
		_drone_parked.position = parked
	if _hint.text != "" or player != walker_out or player.is_stunned():
		return
	var pad := _drone_pad(at_m)
	var p := player.global_position
	if Vector2(p.x - pad.x, p.z - pad.z).length() > 1.8:
		return
	if drone_broken_day == day:
		_hint.text = "Drooni on rikki. Uudet potkurit tulevat huomenna postissa."
		return
	if drone_battery < 0.25:
		_hint.text = "Droonin akku latautuu (%d %%)." % roundi(drone_battery * 100.0)
		return
	var names := _drone_names(at_m)
	_hint.text = "[E] Lennätä droonia (akku %d %%, ilmakuvia %d/%d)" % [roundi(drone_battery * 100.0),
		_drone_photo_count(names), names.size()]
	if Input.is_action_just_pressed("interact"):
		_start_drone()


## Alustan keskipiste maanpinnalla (maailmassa): kotipiha tai mökin piha.
func _drone_pad(at_m: bool) -> Vector3:
	if at_m and mokki.built:
		return mokki.gpos(Mokki.DRONE_LOCAL)
	var pad: Vector3 = world.drone_pad_pos
	return pad + Vector3(0, Terrain.h(pad.x, pad.z), 0)


## Kuvattavien kohteiden nimet (id -> nimi) paikan mukaan.
func _drone_names(at_m: bool) -> Dictionary:
	return _mokki_drone_names() if at_m else DRONE_POIS


func _drone_photo_count(names: Dictionary) -> int:
	return drone_photos.filter(func(id: String) -> bool: return names.has(id)).size()


## Mökin kohteet ja lentoalueen nimetyt järvet (id "m_järvi:<nimi>" -> nimi). Lasketaan kerran; järvien
## pisteet (bbox:n keskipiste, jos se on vedessä) jäävät _mokki_lakes-sanakirjaan.
func _mokki_drone_names() -> Dictionary:
	if _mokki_drone_cache.is_empty():
		var out := MOKKI_DRONE_POIS.duplicate()
		var data := Mokki.map_data()
		for i in data.water.size():
			var nm: String = data.water_names[i]
			var id := "m_järvi:" + nm
			if nm == "" or out.has(id):
				continue
			var c: Vector2 = data.water_bbox[i].get_center()
			if c.length() < MOKKI_DRONE_R - 80.0 and Geometry2D.is_point_in_polygon(c, data.water[i]):
				out[id] = nm
				_mokki_lakes[id] = Vector3(c.x, Mokki.water_level(i), c.y)
		_mokki_drone_cache = out
	return _mokki_drone_cache


func _start_drone() -> void:
	_mokki_prev = state
	state = "minigame"
	walker_out.controls_enabled = false
	walker_out.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	var at_m := _at_mokki()
	var pad := _drone_pad(at_m)
	walker_out.rotation.y = B.yaw_to(pad - walker_out.global_position)
	_drone_parked.visible = false
	var d := DroneGame.new()
	d.position = pad
	d.battery = drone_battery
	var names := _drone_names(at_m)
	d.pois = _mokki_drone_pois() if at_m else _drone_pois()
	d.photo_total = names.size()
	d.photo_count = _drone_photo_count(names)
	if at_m:
		# Mökin maasto: järvien kohdalla pinta on vesi (sinne pudonnut drooni on mennyttä).
		var surface := func(x: float, z: float) -> Vector2:
			var l: Vector3 = mokki.to_local(Vector3(x, 0, z))
			var wi := Mokki.water_at(l.x, l.z)
			return Vector2(wi, Mokki.water_level(wi) if wi >= 0 else Mokki.h(l.x, l.z))
		d.ground = func(x: float, z: float) -> float: return mokki.global_position.y + surface.call(x, z).y
		d.is_water = func(x: float, z: float) -> bool: return surface.call(x, z).x >= 0.0
		d.in_bounds = func(q: Vector2) -> bool: return q.distance_to(Vector2(MOKKI_POS.x, MOKKI_POS.z)) < MOKKI_DRONE_R
	d.photographed.connect(_on_drone_photo)
	d.hud = _hud
	d.finished.connect(_on_drone_finished)
	_drone = d
	add_child(d)
	# Tutka, kompassi, kartta ja ruoho seuraavat droonia lennon ajan.
	# Lennon ajaksi HUD:sta näkyvät vain tutka, kompassi ja viestit.
	for c in _hud.get_children():
		if c is CanvasItem and c not in [_minimap, _compass, _msg]:
			c.set_meta("drone_hidden", c.visible)
			c.visible = false
	_minimap.player = d.body
	_compass.player = d.body
	_paper.player = d.body
	world.follow = d.body
	tilat.first("drooni", 0.3)


## Ilmakuvattavat kohteet: kiinteät paikat ja liikkuvat hahmot (jos ne ovat olemassa).
func _drone_pois() -> Array:
	var out: Array = []
	var fixed := {"koti": M.HOME_BUILDING, "kmarket": M.SHOP_BUILDING, "laavu": M.LAAVU, "grillikatos": M.GRILLIKATOS,
		"pontikka": M.PONTIKKA}
	for id in fixed:
		var at: Vector3 = M.w(fixed[id])
		out.append({"id": id, "name": DRONE_POIS[id], "pos": func() -> Vector3: return at + Vector3(0, 1.0, 0)})
	var movers := {"paivi": wife, "juntti": juntti, "jyvajemmari": tractor, "mummot": mummot, "arto": arto, "pekka": pekka,
		"sinikka": sinikka,
		"vaino": vaino, "pojat": boys}
	for id in movers:
		var n: Node3D = movers[id]
		if not is_instance_valid(n):
			continue
		out.append({"id": id, "name": DRONE_POIS[id], "pos": func() -> Vector3:
			return n.global_position + Vector3(0, 1.0, 0) if is_instance_valid(n) and n.is_inside_tree() else Vector3(0, -9999, 0)})
	return out


## Mökin ilmakuvakohteet: pihan rakennukset, laituri, metsästyslava, Santtu ja järvet.
func _mokki_drone_pois() -> Array:
	var names := _mokki_drone_names()
	var fixed := {"m_mokki": Vector3(Mokki.COTTAGE_LOCAL.x, 1.5, Mokki.COTTAGE_LOCAL.y), "m_savusauna": Mokki.SAUNA_LOCAL,
		"m_poreamme": Mokki.TUB_LOCAL, "m_keittio": Mokki.KITCHEN_LOCAL, "m_laituri": Mokki.DOCK_LOCAL, "m_lava": Mokki.HUNT_LOCAL}
	var out: Array = []
	for id in fixed:
		var at: Vector3 = mokki.gpos(fixed[id] + Vector3(0, 1.0, 0))
		out.append({"id": id, "name": names[id], "pos": func() -> Vector3: return at})
	var santtu: Node3D = mokki.santtu
	out.append({"id": "m_santtu", "name": names.m_santtu, "pos": func() -> Vector3:
		return santtu.global_position + Vector3(0, 1.0, 0) if is_instance_valid(santtu) and santtu.is_visible_in_tree() \
			else Vector3(0, -9999, 0)})
	for id in _mokki_lakes:
		var at: Vector3 = mokki.to_global(_mokki_lakes[id])
		out.append({"id": id, "name": names[id], "pos": func() -> Vector3: return at})
	return out


func _on_drone_photo(id: String) -> void:
	if id in drone_photos:
		return
	drone_photos.append(id)
	var names := _drone_names(id.begins_with("m_"))
	var n := _drone_photo_count(names)
	_drone.photo_count = n
	tilat.add("kokemus", 0.05)
	Sfx.play("win_small", -8.0, 1.2)
	if id == "pontikka" and not pontikka_found:
		pontikka_found = true
		_queue_message("Kuusikosta nousee savua... Pannu-Sulon pontikkapannu! Paikka merkittiin karttaan (M).", 4.0)
	if n == names.size():
		if id.begins_with("m_"):
			_queue_message("Kaikki mökin ilmakuvat otettu! Santtu saa uudet kuvat Airbnb-ilmoitukseen.", 4.0)
			tilat.add("moraali", 0.1)
		else:
			_queue_message("Kaikki ilmakuvat otettu! Saloinen on nyt kartoitettu ilmasta.", 4.0)
			maine = clampf(maine + 10.0, 0.0, 100.0)
	_save_game()


func _on_drone_finished(result: String) -> void:
	drone_battery = _drone.battery
	_drone.queue_free()
	_drone = null
	_drone_parked.visible = true
	for c in _hud.get_children():
		if c.has_meta("drone_hidden"):
			c.visible = c.get_meta("drone_hidden")
			c.remove_meta("drone_hidden")
	state = _mokki_prev
	_minimap.player = player
	_compass.player = player
	_paper.player = player
	world.follow = player
	walker_out.controls_enabled = true
	walker_out.activate_camera()
	_hazards.process_mode = Node.PROCESS_MODE_INHERIT
	if _once_today("drooni"):
		tilat.add("stressi", 0.1)
		tilat.add("keskittyminen", 0.1)
	if result == "crashed":
		drone_broken_day = day
		drone_battery = 0.0
		tilat.add("moraali", -0.1)
		_show_message("Drooni hajosi. Romut kerätty, uudet potkurit huomenna.", 3.5)
	else:
		var names := _drone_names(_at_mokki())
		_show_message("Drooni laskeutui. Ilmakuvia %d/%d." % [_drone_photo_count(names), names.size()], 3.0)


## Terä osui siiliin tai kiveen. Toinen siili tuo poliisin, toinen kivi rikkoo leikkurin.
func _lawn_hit(o: Dictionary) -> void:
	lawn.remove_object(o)
	if o.kind == "kivi":
		lawn_kivet += 1
		Sfx.play("rattle_hard", 0.0, 0.8)
		if lawn_kivet >= 2:
			mower_broken = true
			_stop_mowing()
			tilat.add("stressi", -0.2)
			_show_message("KRÄKS! Terä vääntyi ja leikkuri hajosi.\nHae varaosa Artolta ja kaljaa, niin korjataan.", 4.5)
		else:
			lawn.cough()
			_show_message("KOLAHDUS! Kivi terään, leikkuri yskii.", 2.5)
	else:
		lawn_siilit += 1
		Sfx.play("pedal_squeak", 0.0, 1.8)
		tilat.add("moraali", -0.3)
		tilat.add("stressi", -0.2)
		if lawn_siilit >= 2:
			lawn_siilit = 0
			_stop_mowing()
			_call_police()
		else:
			_show_message("Voi ei, siili jäi leikkurin alle...\nHuono omatunto. Katso tarkemmin, mihin ajat.", 3.5)
	_save_game()


## Eläinsuojelurikos: poliisiauto lähtee tieverkolta noin 150 metrin päästä, jotta ehtii karkuun.
func _call_police() -> void:
	if police != null and is_instance_valid(police):
		return
	var p := player.global_position
	var start := 0
	var best := INF
	for i in world.graph_nodes.size():
		var d := absf(world.graph_nodes[i].distance_to(p) - 150.0)
		if d < best:
			best = d
			start = i
	police = PoliceCar.new()
	_hazards.add_child(police)
	police.setup(world.graph_nodes, world.graph_adj, start, player)
	police.world = world
	police.caught.connect(func() -> void:
		if state in ["to_shop", "to_home"]:
			_lose("Poliisi pidätti: eläinsuojelurikos!", "police"))
	police.escaped.connect(func() -> void:
		tilat.first("poliisipako", 0.5)
		tilat.add("stressi", 0.2)
		_show_message("Pääsit karkuun! Poliisi luovutti... tällä kertaa.", 3.5))
	police.start_chase()
	Sfx.play("alert", 0.0, 0.8)
	_show_message("TOINEN SIILI! Anna-Liisa soitti poliisit.\nPOLIISI TULEE – KARKUUN!", 4.0)


## Aamun motkotus pitkästä nurmikosta (Päivi, pidemmästä myös naapurin Anna-Liisa).
func _lawn_nag() -> String:
	var avg: float = lawn.avg_len()
	var s := ""
	if avg >= 0.35:
		s += "\n" + LAWN_NAG_PAIVI.pick_random()
	if avg >= 0.5:
		s += "\n" + LAWN_NAG_ANNALIISA.pick_random()
	return s


## Joka toinen päivä pojat johonkin tien varteen. Palauttaa true, jos pojat ovat tänään kylillä.
func _spawn_boys() -> bool:
	boys = null
	ball = null
	has_ball = false
	_ball_quest = ""
	if day % 2 != 0:
		return false
	for attempt in 40:
		var n: Vector3 = world.graph_nodes.pick_random()
		var a := randf() * TAU
		var p := n + Vector3(cos(a), 0, sin(a)) * randf_range(7.0, 11.0)
		if not world._in_bounds(Vector2(p.x, p.z), 25.0) or world.surface_at(p) == "water" \
				or world._near_house(Vector2(p.x, p.z), 9.0) or p.distance_to(home_zone) < 40.0:
			continue
		boys = Boys.new()
		boys.position = Vector3(p.x, Terrain.h(p.x, p.z), p.z)
		boys.target = player
		boys.hit.connect(func(dir: Vector3) -> void:
			if state in ["to_shop", "to_home"] and not player.is_stunned():
				player.stagger(dir)
				tilat.add("kipu", -0.05)
				_show_message("Kivi osui! Pojilla on hyvä käsi.", 2.0))
		_hazards.add_child(boys)
		return true
	return false


## Pojat: tehtävän anto, pallon poiminta ja esineen antaminen valikosta.
func _boys_logic() -> void:
	if not is_instance_valid(boys):
		return
	var e := Input.is_action_just_pressed("interact")
	var p := player.global_position
	if _ball_quest == "search" and not has_ball and is_instance_valid(ball) and _hint.text == "" \
			and Vector2(p.x - ball.global_position.x, p.z - ball.global_position.z).length() < 1.6:
		if player == bike:
			_hint.text = "Nouse pyörän selästä (F), niin saat pallon."
			return
		_hint.text = "[E] Ota jalkapallo"
		if e:
			has_ball = true
			ball.queue_free()
			Sfx.play("pickup", -2.0, 1.1)
			_show_message("Jalkapallo löytyi! Vie se pojille.", 2.5)
		return
	if _hint.text != "" or boys.mode != "idle" or boys.distance_to_target() > 4.0 or player.is_stunned():
		return
	if player == bike:
		_hint.text = "Nouse pyörän selästä (F), niin voit jutella poikien kanssa."
		return
	match _ball_quest:
		"":
			_hint.text = "[E] Juttele poikien kanssa"
			if e:
				_give_ball_quest()
		"search":
			_hint.text = "[E] Anna pojille jotain"
			if e:
				_open_give_menu()
		"done":
			_hint.text = "Pojat pelaa palloa."


## Pallo arvotaan 100–300 m päähän pelialueelle (ei veteen); pojat kertovat suunnan.
func _give_ball_quest() -> void:
	var c: Vector3 = boys.global_position
	for attempt in 60:
		var a := randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var q := c + dir * randf_range(100.0, 300.0)
		if not world._in_bounds(Vector2(q.x, q.z), 10.0) or world.surface_at(q) == "water":
			continue
		ball = Boys.make_ball()
		_hazards.add_child(ball)
		ball.global_position = Vector3(q.x, Terrain.h(q.x, q.z) + 0.11, q.z)
		_ball_quest = "search"
		var names := ["itään", "kaakkoon", "etelään", "lounaaseen", "länteen", "luoteeseen", "pohjoiseen", "koilliseen"]
		var way: String = names[posmod(roundi(a / (TAU / 8.0)), 8)]
		boys.say("Meiän pallo on hukassa! Se lensi tosi kauas %s." % way, 0, 4.0)
		_show_message("Pojat: \"Meiän jalkapallo on hukassa! Se lensi tosi kauas %s.\"\nEtsi pallo ja tuo se pojille." % way, 4.5)
		tilat.first("pojat")
		return


func _open_give_menu() -> void:
	var items: Array = []
	if has_ball:
		items.append(["pallo", "Jalkapallo"])
	if beers > 0:
		items.append(["kalja", "Kalja (%d)" % beers])
	if has_sausage:
		items.append(["makkara", "Grillimakkara"])
	if has_matches:
		items.append(["tikut", "Tulitikut"])
	if has_chocolate:
		items.append(["suklaa", "Suklaalevy"])
	if has_mower_part:
		items.append(["varaosa", "Leikkurin varaosa"])
	if has_kanister:
		items.append(["kanisteri", "Pontikkakanisteri"])
	if not bucket.is_empty():
		items.append(["ampari", "Ämpäri (marjat ja sienet)"])
	if not paivi_bag.is_empty():
		items.append(["ostokset", "Päivin ostokset"])
	if kota_halot > 0:
		items.append(["halko", "Halko"])
	if items.is_empty():
		_show_message("Sinulla ei ole mitään annettavaa. Pallo pitää ensin löytää.", 2.5)
		return
	player.controls_enabled = false
	player.speed = 0.0
	_msg.text = ""
	_msg_time = 0.0
	_menu_mode = "give"
	_item_menu.open(items, "Mitä annat pojille?")


## T: syömävalikko mukana olevista eväistä.
## Vaalan matkalla valikon E ei saa avata ovia: auki ollessa estetty, ja sulkeutumisruudulla myös.
func _mopo_menu(open: bool) -> void:
	if mopo_trip == null:
		return
	mopo_trip.menu_open = open
	if not open:
		mopo_trip._resume_frame = Engine.get_process_frames()


## Ohjattava hahmo: sisätiloissa sisätilan oma kävelijä, muuten pelaaja (ulkona odottava kävelijä ei liiku).
func _active_walker() -> CharacterBody3D:
	match state:
		"in_shop":
			return interior.walker
		"in_siitari":
			return siitari_int.walker
		"in_raahe":
			return raahe_int.walker
		"in_home":
			return home_int.walker
		"in_mokki":
			return mokki_int.walker
		"in_garage":
			return garage_int.walker
	return player


## T sisätiloissa: sama syö/juo-valikko kuin ulkona, kun hahmo on vapaana (ei minipeliä, keskustelua tai valikkoa).
func _indoor_eat() -> void:
	if not state in ["in_shop", "in_siitari", "in_raahe", "in_home", "in_mokki", "in_garage"] or _item_menu.is_open():
		return
	if Input.is_action_just_pressed("eat") and _active_walker().controls_enabled:
		_open_eat_menu()


func _open_eat_menu() -> void:
	var items: Array = []
	for k in ["pulla", "piirakka", "mustikkapiirakka", "savukala", "savuriista", "karrella"]:
		if food.get(k, 0) > 0:
			items.append([k, "%s (%d)" % [FOODS[k].name, food[k]]])
	if has_chocolate:
		items.append(["suklaa", FOODS.suklaa.name])
	if beers > 0:
		items.append(["kalja", "Kalja (kannossa %d)" % beers])
	if viina_pullot > 0:
		items.append(["viina", "Huikka kätköviinaa (%d pulloa)" % viina_pullot])
	for k in ["puolukka", "mustikka"]:
		if bucket.get(k, 0) > 0:
			items.append([k, "%s – ämpärissä %d l" % [FOODS[k].name, bucket[k]]])
	if items.is_empty():
		_show_message("Ei mitään syötävää eikä juotavaa. Kaupan leipähyllystä saa korvapuusteja ja piirakoita, metsästä marjoja, mökin savustimesta kalaa ja riistaa.", 3.0)
		return
	var w := _active_walker()
	w.controls_enabled = false
	if "speed" in w:
		w.speed = 0.0
	_mopo_menu(true)
	_msg.text = ""
	_msg_time = 0.0
	_menu_mode = "eat"
	_item_menu.open(items, "Mitä syöt tai juot?")


## Omat juomat baarissa: baarimikko huomaa joka toisen kerran (OWN_DRINK_SEEN); ensin varoitus, toisella ulos.
const OWN_DRINK_SEEN := 0.5
const OWN_DRINK_WARN := ["Hei! Omia juomia ei täällä juoda.", "Pullo pois, tää on anniskeluravintola!",
	"Nähtiin kyllä. Vielä kerran niin lähdet."]
var _own_drink_warned := false  # nollataan baariin tullessa


func _own_drink_in_bar() -> void:
	if not state in ["in_raahe", "in_siitari"] or randf() >= OWN_DRINK_SEEN:
		return
	var bar = raahe_int if state == "in_raahe" else siitari_int
	if not _own_drink_warned:
		_own_drink_warned = true
		bar.bartender_say(OWN_DRINK_WARN.pick_random())
		tilat.add("stressi", -0.05)
		_show_message("Baarimikko huomasi omat juomat. Seuraavasta lentää ulos.", 2.5)
		return
	bar.bartender_say("Nyt riitti! Ulos, ja heti!")
	bar.walker.controls_enabled = false
	maine = clampf(maine - 5.0, 0.0, 100.0)
	tilat.add("moraali", -0.1)
	Sfx.play("lose", -4.0)
	_show_message("Baarimikko heitti sinut ulos omien juomien takia!", 3.0)
	tilat.first("baarista_ulos", 0.3)
	var where := state
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if state != where:
			return
		if where == "in_raahe":
			_raahe.kicked = true
			_on_raahe_exited()
		else:
			_on_siitari("lahde")
			_show_message("Siitarista heitettiin ulos omien juomien takia. Mopo odottaa pihassa.", 3.5))


func _on_eat(id: String) -> void:
	_active_walker().controls_enabled = true
	_mopo_menu(false)
	match id:
		"pulla", "piirakka", "savukala", "savuriista", "karrella", "mustikkapiirakka":
			food[id] -= 1
			if food[id] <= 0:
				food.erase(id)
		"suklaa":
			has_chocolate = false
		"kalja":
			beers -= 1
			player.set_carrying(beers > 0)
			_drink(1)
			tilat.first("syo_kalja", 0.1)
			Sfx.play("glass", -6.0, 1.2)
			_show_message(["Tsihh. Ah.", "Kylmää ja hyvää.", "Yks ei oo yhtään.", "Päivin ei tarvi tietää."].pick_random(), 1.8)
			_own_drink_in_bar()
			return
		"viina":
			viina_pullot -= 1
			tilat.add("humala", 0.25)
			tilat.add("kipu", 0.1)
			tilat.add("stressi", FOODS.viina.stressi)
			tilat.add("moraali", FOODS.viina.moraali)
			tilat.first("syo_viina", 0.1)
			Sfx.play("glass", -6.0, 0.9)
			_show_message(["Kurkkua polttaa.", "Metsän makua.", "Lämmittää mukavasti.", "Tätä ei Päivi näe."].pick_random(), 1.8)
			_own_drink_in_bar()
			return
		"puolukka", "mustikka":
			bucket[id] -= 1
			if bucket[id] <= 0:
				bucket.erase(id)
	var f: Dictionary = FOODS[id]
	_eat(f.nalka)
	for k in ["stressi", "moraali", "vireys"]:
		if f.has(k):
			tilat.add(k, f[k])
	tilat.first("syo_" + id, 0.1)
	Sfx.play("pickup", -6.0, 0.6)
	_show_message(["Nam.", "Maistuu!", "Ei paha.", "Hyvää eväsleipää parempi."].pick_random(), 1.5)


## Esine pojille: pallo = palkkio, kalja = pojat juoksevat nauraen pois, muu = heittävät takaisin ja kivisade.
func _on_give(id: String) -> void:
	player.controls_enabled = true
	match id:
		"pallo":
			has_ball = false
			_ball_quest = "done"
			money += BALL_REWARD
			var first: bool = not ("jalkapallo" in tilat.firsts)
			if first:
				tilat.firsts.append("jalkapallo")
			tilat.add("moraali", randf_range(0.1, 0.5))
			tilat.add("kokemus", randf_range(0.4, 0.6) if first else randf_range(0.1, 0.3))
			boys.play_ball()
			boys.say("Kiitti setä! Tässä euro.", 1, 3.0)
			Sfx.play("win_small")
			_show_message("Pallo palautettu! Pojat antoi %s €." % _eur(BALL_REWARD), 3.0)
		"kalja":
			beers -= 1
			player.set_carrying(beers > 0)
			tilat.add("moraali", -0.2)
			boys.flee()
			_show_message("Pojat nappasi kaljan ja juoksi nauraen pois!", 3.0)
		_:
			boys.stone()
			_show_message("Pojat heitti sen takaisin ja alkoi heitellä kivillä!", 3.0)


## Jatkuvat tilavaikutukset ulkona (sekunnissa). Arvot ovat -1..+1, joten 0,01/s = minuutissa 0,6.
func _stats_tick(delta: float) -> void:
	var t := tilat
	var moving := absf(player.speed) > 0.3
	var sprint: bool = (player == walker_out and absf(player.speed) > 3.0) or (player == bike and bike.sprinting)
	_still_t = 0.0 if moving else _still_t + delta
	var resting := _still_t > 3.0
	# Nälkä: aika ja liike kuluttavat.
	t.add("nalka", -(0.002 + (0.002 if moving else 0.0)) * delta)
	if wound_big:
		t.add("kipu", -0.004 * delta)  # karhun raapaisut kirveltävät pahemmin, kunnes hoidetaan
	# Väsymys ja stamina: sprintti kuluttaa, tauko palauttaa.
	if sprint:
		t.add("vasymys", -0.01 * delta)
		t.add("stamina", -0.01 * delta)
	elif resting:
		t.add("vasymys", 0.01 * delta)
		t.add("stamina", 0.01 * delta)
	if "nalka" in t.chosen and "vasymys" in t.chosen and t.value("nalka") < -0.5 and t.value("vasymys") < -0.5:
		t.add("stamina", -0.003 * delta)  # nälkä ja väsymys samana päivänä vievät voimat
	# Kipu hellittää ajan myötä.
	t.add("kipu", 0.003 * delta)
	# Stressi: jahti on aikapainetta, paikallaan olo mukavassa paikassa rauhoittaa.
	if wife.mode == "chase" or juntti.mode == "chase" or (is_instance_valid(police) and not police.is_leaving()):
		t.add("stressi", -0.012 * delta)
	if resting and _pleasant_spot():
		t.add("stressi", 0.02 * delta)
		t.add("vireys", 0.006 * delta)
	# Vireys: rauha luonnossa ja selvin päin nostaa, humala, nälkä ja väsymys laskevat.
	if resting and player.surface in ["forest", "meadow", "bog"]:
		t.add("vireys", 0.004 * delta)
	if t.value("humala") <= 0.0:
		t.add("vireys", 0.001 * delta)
	elif t.value("humala") > 0.5:
		t.add("vireys", -0.005 * delta)
	if t.value("nalka") < -0.5 or t.value("vasymys") < -0.5:
		t.add("vireys", -0.002 * delta)
	# Keskittyminen kärsii stressistä.
	if t.value("stressi") < -0.5:
		t.add("keskittyminen", -0.002 * delta)
	# Kokemus: pitkä paikallaan olo laskee, kova humala "opettaa".
	if _still_t > 10.0:
		t.add("kokemus", -0.002 * delta)
	if t.value("humala") > 0.7:
		t.add("kokemus", 0.003 * delta)
	# Humala haihtuu hitaasti.
	t.add("humala", -0.002 * delta)
	_stat_effects()


## Päivän kolmen tilan palkinnot ja haitat (day_stats.gd effect): päällä heti, kun palkki ylittää rajan
## (+0,5 / -0,5; humalatila 0,3–0,6 / yli 0,8). Muut tilat kuin päivän kolme eivät vaikuta. Ks. README.
func _stat_effects() -> void:
	var t := tilat
	# Stressi: rauhallisena mummot suuttuvat hitaammin, kireänä Päivi ajaa lujempaa.
	var e: int = t.effect("stressi")
	mummot.anger_speed = _anger_base * (1.3 if e > 0 else 1.0)
	wife.speed_mult = _wife_speed_base + (0.1 if e < 0 else 0.0)
	# Nälkä: kylläisenä kulkee kevyemmin, nälkäisenä raskaammin (jalan ja pyörällä).
	e = t.effect("nalka")
	walker_out.speed_mult = 1.0 + 0.1 * e
	# Väsymys: virkeänä juoksu ja spurtti kuluttavat vähemmän, väsyneenä kunto palautuu hitaammin.
	e = t.effect("vasymys")
	walker_out.drain_mult = 0.7 if e > 0 else 1.0
	walker_out.recover_mult = 0.5 if e < 0 else 1.0
	# Kipu: kipeänä ontuu (juoksu ja hyppy). Palkinto (lisäkesto) tulee tappelun alussa (_start_fight).
	e = t.effect("kipu")
	walker_out.run_mult = 0.85 if e < 0 else 1.0
	walker_out.jump_mult = 0.75 if e < 0 else 1.0
	# Stamina: hyvissä voimissa spurtti on rajumpi, voimattomana ei juosta eikä spurtata.
	e = t.effect("stamina")
	bike.sprint_mult = 1.6 if e > 0 else PlayerBike.SPRINT
	walker_out.no_sprint = e < 0
	# Vireys: virkeänä tutka näkee kauemmas, tokkuraisena usva tihenee.
	e = t.effect("vireys")
	_minimap.range_m = Minimap.FAR_RANGE if e > 0 else Minimap.RANGE
	var far: float = Settings.view_far() * (0.5 if e < 0 else 1.0)
	_env.fog_depth_begin = 90.0 * far / 900.0
	_env.fog_depth_end = 700.0 * far / 900.0
	# Kovassa humalassa pyörän ja kävelyn ohjaus heittelee (drunk_wobble.gd), kuten mopolla: aina, vaikka humala
	# ei olisi päivän tila. Humalan palkinto (tappelun iskut) vaatii, että humala on päivän tiloissa.
	var drunk: float = t.value("humala")
	bike.drunk = drunk
	walker_out.drunk = drunk
	# Moraali (kaupan hinnat), keskittyminen (repun kauppalista), kokemus (minipelien käsi, _hand_shake) ja
	# humalan palkinto (tappelun iskut) luetaan siellä, missä niitä käytetään.


## Minipelien käden huojunta (game.drunk): humala, ja kokemus-tila vakauttaa (-0,15) tai horjuttaa (+0,15).
func _hand_shake() -> float:
	return clampf(tilat.value("humala") - 0.15 * tilat.effect("kokemus"), 0.0, 1.0)


var _today: Array = []  # tänään jo saadut kertabonukset (ettei E:n hakkaaminen kasvata tiloja loputtomiin)


## Kertabonus päivässä: palauttaa true vain ensimmäisellä kerralla tänään.
func _once_today(id: String) -> bool:
	if id in _today:
		return false
	_today.append(id)
	return true


## Mukava paikka: syttynyt nuotio laavulla, tuli kodassa, Kiilinlammen grillikatos tai mökin piha.
func _pleasant_spot() -> bool:
	var p := player.global_position
	if p.distance_to(mokki.global_position) < 35.0:
		return true
	if fire_lit and p.distance_to(M.w(M.LAAVU)) < 8.0:
		return true
	if world.kota != null and world.kota.fire_on and p.distance_to(world.kota.global_position) < 8.0:
		return true
	return p.distance_to(M.w(M.GRILLIKATOS)) < 7.0


## Kalja (tai useampi): humala nousee, kipu hellittää, mutta moraali ja keskittyminen kärsivät.
func _drink(n: int) -> void:
	tilat.add("humala", 0.12 * n)
	tilat.add("kipu", 0.05 * n)
	tilat.add("stamina", 0.05 * n)
	tilat.add("nalka", 0.04 * n)
	tilat.add("moraali", -0.04 * n)
	tilat.add("keskittyminen", -0.05 * n)


func _eat(amount: float) -> void:
	tilat.add("nalka", amount)
	tilat.add("stamina", amount * 0.5)


## Tehtävä onnistui / sivutehtävässä autettiin jotakuta.
func _task_done(side_quest := false) -> void:
	tilat.add("moraali", 0.25)
	tilat.add("stressi", 0.2)
	if side_quest:
		tilat.add("keskittyminen", 0.3)


func _task_failed() -> void:
	tilat.add("moraali", -0.3)
	tilat.add("stressi", -0.3)


## Päivän perusarvot vaaroille (tilojen vaikutukset lisätään näihin, _stat_effects). Edellinen päivä ei vaikuta,
## paitsi Sinikan juorut (Päivi vauhdissa) ja krapula (_end_day_stats).
func _apply_day_base() -> void:
	wife.speed_mult = 1.0
	if _paivi_mad:
		_paivi_mad = false
		wife.speed_mult += 0.1  # Sinikka-juorut: Päivi on tänään vauhdissa
	_wife_speed_base = wife.speed_mult
	_anger_base = 5.0
	mummot.anger_speed = _anger_base
	stray.bite_dist = 2.3


## Päivän päätös: tilat nollautuvat eikä eilinen vaikuta tähän päivään, paitsi humala: illalla yli
## DayStats.HANGOVER_LIMIT -> krapula-aamu (vireys ja keskittyminen alkavat -0,3). Palauttaa aamun viestin rivin.
func _end_day_stats(at_mokki := false) -> String:
	var note := ""
	var who := "santtu" if at_mokki else "paivi"
	var hangover: bool = tilat.value("humala") > DayStats.HANGOVER_LIMIT
	tilat.reset()
	if hangover:
		tilat.add("vireys", -0.3)
		tilat.add("keskittyminen", -0.3)
		note = "\n" + HANGOVER_NOTE[who]
	if at_mokki:
		tilat.ensure("humala")  # mökillä humalatila on aina yksi päivän kolmesta tilasta
	_today.clear()
	for k in tilat.chosen:
		note += "\n" + STAT_TIPS[who][k].pick_random()
	return note


## Aamun lapun muistutukset päivän kolmesta tilasta: kotona Päivi, mökillä Santtu kirjoittaa lappuun omin sanoin
## (ei tilojen nimiä), ja rivi vihjaa, mitä tilalle kannattaa tehdä.
const STAT_TIPS := {
	"paivi": {
		"stressi": ["Ota tänään vähän rauhallisemmin, kulta.", "Älä hermostu heti kaikesta."],
		"nalka": ["Syö jotain, oot muuten taas ihan kiukkunen.", "Älä lähe tyhjällä mahalla."],
		"vasymys": ["Lepää välillä, näytit eilen ihan kuolleelta.", "Älä juokse koko päivää, istu välillä."],
		"kipu": ["Älä hae turpaan tänään.", "Varo niitä koiria."],
		"stamina": ["Säästä vähän voimia, illalla on vielä hommia.", "Syö ja lepää, niin jaksat."],
		"vireys": ["Käy vaikka metsässä haukkaamassa happea.", "Selvin päin tänään, kiitos."],
		"moraali": ["Tee jotain kivaa, oot ollu ihan maassa.", "Hymyile välillä, ei se tapa."],
		"keskittyminen": ["Keskity nyt ja muista mitä pyysin!", "Älä haahuile."],
		"kokemus": ["Tee tänään jotain uutta, äläkä vaan makaa.", "Älä seiso tumput suorina."],
		"humala": ["Ei kaljaa ennen iltaa!", "Kohtuudella sen kaljan kanssa."],
	},
	"santtu": {
		"stressi": ["Täällä ei oo kiire mihinkään.", "Rauhotu, ollaan mökillä."],
		"nalka": ["Ruokaa riittää, syö kunnolla.", "Laita savustimeen jotain, nälkä tulee."],
		"vasymys": ["Ota välillä rennosti laiturilla.", "Älä riehu koko päivää."],
		"kipu": ["Varo itteäs, lähin lääkäri on kaukana.", "Ei mitään tyhmiä tänään."],
		"stamina": ["Tänään tarvitaan voimia, syö hyvin.", "Säästele vähän, hommia riittää."],
		"vireys": ["Käy metsässä, raitis ilma tekee hyvää.", "Kirkas pää on tänään plussaa."],
		"moraali": ["Tehään tästä hyvä päivä.", "Kala laiturilta piristää aina."],
		"keskittyminen": ["Pää kasassa, niin hommat sujuu.", "Älä haahuile."],
		"kokemus": ["Kokeile jotain, mitä et oo ennen tehny.", "Mökillä riittää uutta tekemistä."],
		"humala": ["Saunakaljat illalla, ei aamusta.", "Kohtuudella, ettei mene överiks."],
	},
}
## Krapula-aamun rivi (vireys ja keskittyminen -0,3): kotona Päivi, mökillä Santtu.
const HANGOVER_NOTE := {
	"paivi": "Haisit yöllä ihan viinalta. Toivottavasti päätä särkee.",
	"santtu": "Eilinen ilta venyi. Juo vettä, kyllä se krapula siitä hellittää.",
}


## Uusi kauppalista: neljä eri tuotetta, kullekin väri.
func _roll_list() -> void:
	var prods: Array = ShopInterior.PRODUCTS.keys()
	prods.shuffle()
	shopping_list.clear()
	for i in LIST_SIZE:
		shopping_list.append([prods[i], ShopInterior.COLORS.keys().pick_random()])
	paivi_bag = {}
	_list_done = false


## Päivin heippalappu päivän alkuun: otsikko, tehtävä ja kauppalista värikynillä (kukin tuote oman värisellä
## kynällä: lappu näkyy hetken, ja HUD:n kauppalistassa on vain tuotteet, joten värit pitää muistaa)
## sekä päivän muut muistutukset (extra: rivit \n-erotettuina).
func _day_note(head: String, extra: String, with_list := true) -> void:
	var lines: Array = [head]
	if with_list and not shopping_list.is_empty():
		lines.append("Käy K-Marketissa ja tuo:")
		for it in shopping_list:
			# Keltainen kynä keltaisella post-it-lapulla: vähän tummempi, jotta erottuu.
			var ink: Color = ShopInterior.COLORS[it[1]] if it[1] != "keltainen" else Color(0.95, 0.68, 0.0)
			lines.append(["  • %s" % it[0], ink])
	var more := extra.strip_edges()
	if more != "":
		lines.append("")
		lines.append_array(more.split("\n"))
	_note.show_note(lines, "– Päivi ♥", 12.0 if more == "" else 16.0)



## Ostosten tarkistus: palauttaa Päivin repliikit. Kaikki oikein -> kaljarauha.
func _check_list() -> Array[String]:
	_list_done = true
	var lines: Array[String] = []
	var big := false
	var wanted := {}
	for it in shopping_list:
		wanted[it[0]] = it[1]
		if not paivi_bag.has(it[0]):
			lines.append("%s puuttuu kokonaan!" % it[0].capitalize())
			big = true
		elif paivi_bag[it[0]] != it[1]:
			lines.append("Mä sanoin %s %s, ei %s!" % [it[1].to_upper(), it[0], paivi_bag[it[0]]])
	for prod in paivi_bag:
		if not wanted.has(prod):
			lines.append("Ei ollu listalla: %s %s! Mitä mää tuolla teen?" % [paivi_bag[prod], prod])
			big = true
	paivi_bag = {}
	if lines.is_empty():
		_task_done(true)
		tilat.first("kauppalista", 0.4)
	else:
		tilat.add("stressi", -0.2)
		tilat.add("moraali", -0.1)
	if lines.is_empty():
		_kaljarauha = true
		Sfx.play("win_small")
		return ["Päivi: \"Kaikki oikein! No niin, kyllä sää osaat.\"\nKaljarauha: Päivi ei etsi jemmoja huomenna."]
	if big:
		lines.push_front("Eihän tässä oo mitään järkeä!")
	var out: Array[String] = []
	for l in lines:
		out.append("Päivi: \"%s\"" % l)
	return out


## Ostokset Päiville kotiovella (ilman kuutosta; kotiinpaluu kuutosen kanssa tarkistaa ne _win():ssä).
func _errand_logic() -> void:
	if _list_done or paivi_bag.is_empty() or _hint.text != "" or state != "to_shop" or player != walker_out:
		return
	var p := player.global_position
	if Vector2(p.x - home_door.x, p.z - home_door.z).length() > HOME_DOOR_ZONE:
		return
	_hint.text = "[E] Anna ostokset Päiville"
	if Input.is_action_just_pressed("interact"):
		for l in _check_list():
			_queue_message(l, 3.0)
		player.set_carrying(beers > 0)


## Vieras koira puri: kaatuu, ja jalka ontuu, kunnes haava hoidetaan.
func _on_bitten(direction: Vector3) -> void:
	if not (state in ["to_shop", "to_home"]):
		return
	_stop_picking()
	_stop_mowing()
	player.stun(direction)
	Sfx.play("groan", 0.0)
	if bitten:
		_show_message("AI! Sama koira puri uudestaan!", 2.5)
		return
	bitten = true
	walker_out.hurt = true
	tilat.add("kipu", -0.3)
	tilat.add("stressi", -0.1)
	_show_message("AI PERKELE! Vieras koira puri pohkeeseen!\nHaava pitää hoitaa: Pekka osaa, tai Päivi kotona.", 4.0)


## Onko piste metsässä (Saloisissa alustan mukaan, mökillä kaikki mikä ei ole pihaa, tietä, peltoa tai vettä).
func _in_forest(p: Vector3) -> bool:
	if _at_mokki_pos(p):
		if mokki == null:
			return false
		var l: Vector3 = mokki.to_local(p)
		var q := Vector2(l.x, l.z)
		return mokki._mask(q) == 0 and not Mokki.in_water(q.x, q.y) and not Mokki.in_field(q) and not mokki._is_yard(q)
	return world.surface_at(p) == "forest"


## Metsän peto: aika kertyy jalan metsässä; kohtaamisen aikana suden edessä E huutaa. Palauttaa true, kun
## E käytettiin huutoon (muut E-toiminnot odottavat).
func _beast_tick() -> bool:
	if _beast != null and is_instance_valid(_beast):
		if _beast.phase == "standoff" and player == walker_out:
			if _beast.kind == "susi":
				_hint.text = "[E] Huuda sudelle ja näytä isolta"
				if Input.is_action_just_pressed("interact"):
					if not _beast.shout():
						_show_message("Susi ei välitä huudosta selän takaa. Käänny sitä kohti!", 2.0)
					return true
			else:
				_hint.text = "Karhu tuijottaa... Älä juokse."
		return false
	_beast = null
	if player != walker_out or player.is_stunned() or _in_vaala:
		return false
	var where := "mokki" if _at_mokki() else "koti"
	if _beasts_today >= BEAST_MAX[where] or not _in_forest(player.global_position):
		return false
	_beast_forest_t += get_process_delta_time() * (1.7 if where == "mokki" else 1.0)
	if _beast_forest_t >= _beast_next:
		_beast_forest_t = 0.0
		_beast_next = randf_range(BEAST_FOREST_S[0], BEAST_FOREST_S[1])
		_spawn_beast("karhu" if randf() < 0.5 else "susi")
	return false


## Peto ilmestyy n. 30 m päähän puiden sekaan, mieluiten pelaajan taakse tai sivulle.
func _spawn_beast(kind: String) -> bool:
	var p := player.global_position
	var back := player.global_transform.basis.z
	back.y = 0.0
	for a in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, PI]:
		var q := p + back.normalized().rotated(Vector3.UP, a) * 30.0
		if not _in_forest(q):
			continue
		var b := Beast.new()
		b.kind = kind
		b.target = walker_out
		add_child(b)
		b.place(q)
		b.warned.connect(func() -> void:
			if kind == "karhu":
				_show_message("KARHU! Iso kontio murisee puiden välissä.\nÄlä juokse – seiso paikallasi tai peräänny hitaasti.", 4.5)
			else:
				_show_message("SUSI! Harmaa susi tuijottaa puiden välistä.\nÄlä käännä selkääsi: katso sitä kohti ja huuda [%s]." %
					Settings.action_key("interact"), 4.5)
			Sfx.play("alert", -6.0, 0.7)
			tilat.add("stressi", -0.1))
		b.gave_up.connect(func(scared: bool) -> void:
			if not state in ["to_shop", "to_home"]:
				return
			if kind == "karhu":
				_show_message("Karhu tuhahti ja lönkytteli metsään. Huh, sydän hakkaa.", 3.0)
				tilat.first("karhu_selvisi", 0.4)
				tilat.add("moraali", 0.1)
			elif scared:
				_show_message("Susi säikähti huutoa ja katosi metsään!", 3.0)
				tilat.first("susi_karkotettu", 0.4)
				tilat.add("moraali", 0.1)
			else:
				_show_message("Susi menetti kiinnostuksensa ja hölkkäsi pois.", 2.5))
		b.attacked.connect(func(dir: Vector3) -> void: _on_beast_attack(kind, dir))
		_beast = b
		_beasts_today += 1
		return true
	return false


## Pedon hyökkäys: kaatuminen, haava (karhulla isompi) ja eväät: karhu vie kaiken syötävän, susi lihat.
func _on_beast_attack(kind: String, dir: Vector3) -> void:
	if not state in ["to_shop", "to_home"] or player != walker_out:
		return
	_stop_picking()
	_stop_mowing()
	player.stun(dir)
	Sfx.play("groan", 2.0)
	var big := kind == "karhu"
	var lost := PackedStringArray()
	for k in food.keys():
		if big or k in BEAST_MEAT:
			lost.append(FOODS[k].name.to_lower())
			food.erase(k)
	if has_sausage:
		has_sausage = false
		lost.append("makkarat")
	if big:
		for k in bucket.keys():
			lost.append("%s (%d l)" % ["puolukat" if k == "puolukka" else "mustikat", bucket[k]])
		bucket.clear()
	tilat.add("kipu", -0.5 if big else -0.3)
	tilat.add("stressi", -0.25 if big else -0.15)
	bitten = true
	walker_out.hurt = true
	if big:
		wound_big = true
		walker_out.hurt_speed = BEAR_HURT_SPEED
	var msg := "KARHU RAATELI! Kynnet repivät kylkeen, ja kontio jäi penkomaan reppua." if big else \
		"SUSI PURI! Hampaat upposivat reiteen, ja susi nappasi eväät mennessään."
	if not lost.is_empty():
		msg += "\nMeni: %s." % ", ".join(lost)
	msg += "\nIso haava, kipu pahenee: hoidata pian (Pekka, Päivi tai mökillä Santtu)." if big else \
		"\nHaava pitää hoitaa: Pekka, Päivi tai mökillä Santtu."
	_show_message(msg, 5.0)


## Haavan hoito kotona: Päivi puhdistaa ja laittaa laastarin, mutta motkottaa (kotiovella, kun ei olla tulossa
## kaupasta; kotiinpaluu kuutosen kanssa aloittaa uuden päivän, joka hoitaa haavan joka tapauksessa).
func _wound_logic() -> void:
	if not bitten or _hint.text != "" or state != "to_shop" or player != walker_out or player.is_stunned():
		return
	var p := player.global_position
	if Vector2(p.x - home_door.x, p.z - home_door.z).length() > HOME_DOOR_ZONE:
		return
	_hint.text = "[E] Mene sisälle, Päivi hoitaa haavan"
	if Input.is_action_just_pressed("interact"):
		_heal()
		Sfx.play("door", -3.0)
		_show_message("Päivi: \"%s\"\nPäivi puhdisti haavan ja laittoi laastarin." % WOUND_PAIVI.pick_random(), 4.0)


func _heal() -> void:
	tilat.add("kipu", 0.5)  # ensiapu
	bitten = false
	wound_big = false
	walker_out.hurt = false
	walker_out.hurt_speed = walker_out.HURT_SPEED


## Arvotaan, karkaako Väinö tänään ja milloin.
func _roll_vaino() -> void:
	_vaino_at = randf_range(40.0, 180.0) if randf() < VAINO_CHANCE else -1.0


## Väinö karkuteillä: Pekan huuto, kiinniotto jalan (nuuhkiessa tai makkaralla houkuteltuna) ja palautus.
func _vaino_logic() -> void:
	if _vaino_at >= 0.0 and elapsed >= _vaino_at:
		_vaino_at = -1.0
		_vaino_escape()
	if not is_instance_valid(vaino):
		return
	vaino.lure = has_sausage and player == walker_out
	if _hint.text != "" or player.is_stunned():
		return
	var e := Input.is_action_just_pressed("interact")
	if vaino.mode == "follow":
		if pekka.distance_to_player() > 4.2:
			return
		if player == bike:
			_hint.text = "Nouse pyörän selästä (F), niin voit palauttaa Väinön Pekalle."
			return
		if vaino.distance_to_target() > 6.0:
			_hint.text = "Väinö jäi jälkeen. Odota, että se ehtii perään."
			return
		_hint.text = "[E] Palauta Väinö Pekalle"
		if e:
			vaino.queue_free()
			vaino = null
			money += VAINO_MONEY
			var beer := beers < CARRY_FOOT
			if beer:
				beers += 1
				player.set_carrying(true)
			pekka.say("Hyvä poika! Siis Väinö. Tässä vitonen%s." % (" ja kalja" if beer else ""))
			Sfx.play("win_small")
			_task_done(true)
			tilat.first("vaino", 0.5)
			_show_message("Väinö kotona! Pekka antoi %s €%s." % [_eur(VAINO_MONEY), " ja kaljan" if beer else ""], 3.5)
		return
	if vaino.distance_to_target() > 2.4:
		return
	if player == bike:
		_hint.text = "Nouse pyörän selästä (F), niin saat Väinön kiinni."
	elif vaino.is_catchable():
		_hint.text = "[E] Ota Väinö kiinni"
		if e:
			vaino.catch()
			var ate: bool = has_sausage and vaino.lure  # houkuteltu makkaralla
			if ate:
				has_sausage = false
				sausage_done = false
			_show_message("Sait Väinön kiinni!%s Vie se Pekalle." % (" Se söi makkaran." if ate else ""), 3.0)


## Väinö pääsee karkuun Pekan pihalta. Huuto kuuluu Pattijoelle asti.
func _vaino_escape() -> void:
	vaino = Dog.new()
	var start: Vector3 = world.neighbor_yards["pekka"][0]  # Pekan ulko-ovelta
	vaino.position = start
	vaino.target = player
	vaino.world = world
	vaino.home = start
	_hazards.add_child(vaino)
	var a := randf() * TAU
	vaino.bolt(Vector3(cos(a), 0, sin(a)), randf_range(15.0, 25.0))
	pekka.say("VÄINÖ PERKELE!")
	Sfx.play("dog", 0.0, 0.95)
	Sfx.play("alert", -6.0, 0.6)
	_show_message("Pekka: \"VÄINÖ PERKELE!\" (Kuului Pattijoelle asti.)\nPekan koira Väinö karkasi! Ota se kiinni jalan.", 4.5)


## Pannu-Sulo myy metsässä pontikkakanisterin (vastaa 24 kaljaa). Kanisterin kanssa suunta on kotiin.
func _pontikka_logic() -> void:
	if _hint.text != "" or sulo.distance_to_player() > 4.2:
		return
	if player == bike:
		_hint.text = "Nouse pyörän selästä (F), niin voit jutella Sulon kanssa."
		return
	if has_kanister or _sulo_sold:
		_hint.text = "Sulo: \"Tänään ei oo enempää. Tuu huomenna.\""
		return
	if money < KANISTER_PRICE:
		_hint.text = "Sulo myy pontikkakanisterin %s eurolla. Rahat ei riitä." % _eur(KANISTER_PRICE)
		return
	_hint.text = "[E] Osta Pannu-Sulolta kanisteri (%s €, = %d kaljaa)" % [_eur(KANISTER_PRICE), KANISTER_BEERS]
	if Input.is_action_just_pressed("interact") and not player.is_stunned():
		money -= KANISTER_PRICE
		has_kanister = true
		tilat.first("pontikka", 0.5)
		_sulo_sold = true
		walker_out.set_kanister(true)
		state = "to_home"
		sulo.say("Kakskymppiä ja suu suppuun. Ja kanisteri takasin, kun on tyhjä.")
		Sfx.play("coin", -4.0)
		_show_message("Pontikkakanisteri mukana, vastaa %d kaljaa!\nVie se kotiin jemmaan." % KANISTER_BEERS, 3.5)


## K-Marketin taksitolpan taksi: jalan E vie Raahen baariin, jos rahaa on taksiin.
func _taxi_logic() -> void:
	if _hint.text != "":
		return
	var p := player.global_position
	if Vector2(p.x - world.taxi_pos.x, p.z - world.taxi_pos.z).length() > TAXI_RADIUS:
		return
	if _chasing():
		# Juoksukaljat: kuski ottaa kyytiin rahatta, kunhan ehtii ennen kauppiasta.
		_hint.text = "[E] HYPPÄÄ TAKSIIN! Kauppias tulee!" if player != bike else "Pyörältä pois (F) ja taksiin!"
		if player != bike and Input.is_action_just_pressed("interact") and not player.is_stunned():
			_shop_chaser.give_up()
			_shop_chaser = null
			_show_message("Kuski: \"Hyppää kyytiin! Maksat sitte.\"", 2.5)
			_taxi_trip(true)
		return
	if player == bike:
		_hint.text = "Taksi: nouse pyörän selästä (F)."
	elif money < TAXI_FARE:
		_hint.text = "Taksi Raahen baariin maksaa %s €, Paapeliin %s €. Rahat ei riitä." % [_eur(TAXI_FARE), _eur(TAXI_MOKKI_FARE)]
	else:
		_hint.text = "[E] Taksi: Raahen baariin tai Paapelin mökille"
		if Input.is_action_just_pressed("interact") and not player.is_stunned():
			player.controls_enabled = false
			player.speed = 0.0
			_menu_mode = "taksi"
			_item_menu.open([["raahe", "Raahen baariin – %s € (meno-paluu)" % _eur(TAXI_FARE)],
				["paapeli", "Paapelin mökille – %s € (meno-paluu)" % _eur(TAXI_MOKKI_FARE)]],
				"Kuski: \"No mihinkäs lähetään?\"")


## Taksireissu: menomatka, kädenvääntö Raahen baarissa, paluu kotipihaan Päivin eteen ja uusi päivä kotoa.
## Pyörä jää kaupan pihaan.
func _on_taxi_choice(id: String) -> void:
	_menu_mode = "give"
	player.controls_enabled = true
	if id == "paapeli":
		if money < TAXI_MOKKI_FARE:
			_show_message("Kuski: \"Paapeliin on pitkä matka. %s € tai ei mitään.\"" % _eur(TAXI_MOKKI_FARE), 3.0)
			return
		_taxi_mokki()
	elif id == "raahe":
		_taxi_trip()


## Kaupan taksilla Paapelin mökille (meno-paluu): paluu tilataan mökin pihatien päästä.
func _taxi_mokki() -> void:
	money -= TAXI_MOKKI_FARE
	_taxi_mokki_return = true
	tilat.first("mokki", 0.4)
	_hud.visible = false
	walker_out.controls_enabled = false
	walker_out.speed = 0.0
	Sfx.play("door_close", -3.0)
	_save_game()
	cutscene.taxi_ride("PAAPELIIN", "Taksi kaahaa Vaalaan Kaisuantielle. Mittari raksuttaa.", Cutscene.TAXI_MOKKI_LINES,
		_arrive_by_car.bind(mokki.gpos(Mokki.RIDE_LOCAL + Vector3(0, 0.3, 2.2))))


func _taxi_trip(escape := false) -> void:
	state = "cutscene"
	player.controls_enabled = false
	player.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_hud.visible = false
	money = maxf(0.0, money - TAXI_FARE) if escape else money - TAXI_FARE  # paossa kuski ottaa mitä on
	Sfx.play("door_close", -3.0)
	cutscene.taxi_to_raahe(_enter_raahe)


## Raahessa: Kapteenin Kulma ja Kellari (raahe_interior.gd). Ulko-ovelta taksi kotiin ja uusi päivä.
func _enter_raahe() -> void:
	state = "in_raahe"
	_hud.visible = true
	# Päivi tulee etsimään joka toinen kerta, kun pelaaja on viihtynyt hetken (aika s, < 0 = ei tule).
	_raahe = {"won": -1, "paid": 0.0, "quiz": -1, "karaoke": -1.0, "caught": false,
		"paivi_t": randf_range(40.0, 90.0) if randf() < 0.5 else -1.0}
	tilat.first("raahe", 0.5)
	_own_drink_warned = false
	raahe_int.enter()
	_show_message("Kapteenin Kulma, Kirkkokatu 32, Raahe. Kellarissa karaoke, tiistaisin visa ja Tero odottaa kädenvääntöä.", 4.0)


func _on_raahe_exited() -> void:
	if state != "in_raahe":
		return  # jo lähdössä (Päivi löysi ja ovi samaan aikaan)
	raahe_int.leave()
	Sfx.play("door_close", -3.0)
	state = "cutscene"
	_hud.visible = false
	var won: int = _raahe.won
	mielihyva = clampf(mielihyva + (35.0 if won == 1 else 20.0) - (15.0 if _raahe.caught else 0.0), 0.0, 100.0)
	_no_allowance = true
	var parts := PackedStringArray()
	if won == 1:
		parts.append("Voitit kädenväännön, Tero tarjosi.")
	elif won == 0:
		parts.append("Hävisit kädenväännön ja tarjosit kierroksen (%s €)." % _eur(_raahe.paid))
	if _raahe.quiz >= 0:
		parts.append("Visassa %d/3 oikein." % _raahe.quiz)
	if _raahe.karaoke >= 0.0:
		parts.append("Karaoke Kellarissa %d %%." % roundi(_raahe.karaoke * 100.0))
	if _raahe.get("kicked", false):
		parts.append("Baarimikko heitti sinut ulos omien juomien takia.")
	if _raahe.caught:
		parts.append("Päivi löysi sinut baarista ja raahasi kotiin.")
	elif _raahe.get("paivi_came", false):
		parts.append("Päivi tuli etsimään, mutta livahdit taksiin.")
	if parts.is_empty():
		parts.append("Ilta Kapteenin Kulmassa.")
	var stats := "%s Taksi %s €.\nMielihyvä %d · Maine %d" % [" ".join(parts), _eur(TAXI_FARE), roundi(mielihyva), roundi(maine)]
	cutscene.taxi_home(home_zone, stats, func() -> void:
		_new_day(home_zone + Vector3(0, 0, 4), false, "Pää on kipeä Raahen reissusta.\n"))


## Päivi löysi: ilta loppuu, stressi ja moraali kärsivät, kotimatkalla kuunnellaan saarnaa.
func _on_raahe_paivi_caught() -> void:
	_raahe.caught = true
	tilat.add("stressi", -0.3)
	tilat.add("moraali", -0.2)
	maine = clampf(maine - 10.0, 0.0, 100.0)
	Sfx.play("lose", -4.0)
	raahe_int.walker.controls_enabled = false
	_show_message("Päivi löysi sinut! \"Täällähän sää oot! Kotiin, heti!\" Ruukin porukka nauraa.", 3.0)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if state == "in_raahe":
			_on_raahe_exited())


func _on_raahe_acted(kind: String) -> void:
	match kind:
		"tiski":
			raahe_int.bartender_say("Mitäs laitetaan?")
			var items: Array = []
			for id in RAAHE_MENU:
				var m: Array = RAAHE_MENU[id]
				items.append([id, "%s – %s €" % [m[0], _eur(m[1])]])
			items.append(["takaisin", "Takaisin"])
			_menu_mode = "raahe"
			raahe_int.walker.controls_enabled = false
			_item_menu.open(items, "Kapteenin Kulma · rahaa %s €" % _eur(money))
		"tero":
			_raahe_wrestle()
		"visa":
			if _raahe.quiz >= 0:
				raahe_int.quizmaster_say("Tämän illan visa on jo räknätty. Tuu ensi tiistaina uudestaan!")
				return
			_quiz.clear()
			var pool := RAAHE_QUIZ.duplicate()
			pool.shuffle()
			for q in pool.slice(0, 3):
				var opts: Array = (q[1] as Array).duplicate()
				opts.shuffle()
				_quiz.append([q[0], opts, q[1][0]])
			_quiz_i = 0
			_quiz_right = 0
			raahe_int.quizmaster_say("Tiistain visa! Kolme kysymystä Raahesta. Kaikki oikein, niin visajuoma on talon.")
			_ask_quiz()
		"karaoke":
			if money < RAAHE_KARAOKE_PRICE:
				_show_message("Karaoke maksaa %s €. Rahat ei riitä." % _eur(RAAHE_KARAOKE_PRICE), 2.5)
				return
			money -= RAAHE_KARAOKE_PRICE
			_raahe_karaoke()


## Kädenvääntö Teron kanssa (bar_game.gd) ruukin porukan pöydässä; häviäjä tarjoaa kierroksen.
func _raahe_wrestle() -> void:
	raahe_int.busy = true
	raahe_int.walker.controls_enabled = false
	_hud.visible = false
	var bar := BarGame.new()
	bar.position = BAR_POS
	add_child(bar)
	bar.finished.connect(func(won: bool) -> void:
		bar.queue_free()
		_hud.visible = true
		raahe_int.busy = false
		raahe_int.walker.controls_enabled = true
		raahe_int.walker.activate()
		raahe_int.block_interact()
		if _raahe.won < 0:
			tilat.add("moraali", 0.2 if won else -0.1)
			maine = clampf(maine + (15.0 if won else -5.0), 0.0, 100.0)
		_raahe.won = 1 if won else 0
		if won:
			raahe_int.tero_say("Perkele, sää oot vahva! Skooli, mää tarjoan.")
			tilat.add("humala", 0.14)
			_show_message("Voitit Teron! Ruukin porukka hakkaa pöytää. Tero tarjoaa tuopin.", 3.5)
		else:
			var paid := minf(BAR_ROUND, money)
			money -= paid
			_raahe.paid += paid
			tilat.add("humala", 0.14)
			raahe_int.tero_say("Heh. Masuunilla nostellaan isompia. Sää tarjoot.")
			_show_message("Hävisit. Tarjosit ruukin porukalle kierroksen (%s €)." % _eur(paid), 3.5))


func _ask_quiz() -> void:
	var q: Array = _quiz[_quiz_i]
	var items: Array = []
	for k in (q[1] as Array).size():
		items.append(["visa_%d" % k, q[1][k]])
	_menu_mode = "raahe"
	raahe_int.walker.controls_enabled = false
	_item_menu.open(items, "Visa %d/3: %s" % [_quiz_i + 1, q[0]])


## Karaoke Kapteenin Kellarissa: "Ruukin valot".
func _raahe_karaoke() -> void:
	raahe_int.to_stage()
	_hud.visible = false
	var game := KaraokeGame.new()
	game.song = KaraokeGame.SONG_RAAHE
	game.drunk = _hand_shake()
	game.line.connect(raahe_int.set_screen)
	game.finished.connect(func(score: float) -> void:
		game.queue_free()
		_hud.visible = true
		raahe_int.from_stage(score >= 0.5)
		_raahe.karaoke = maxf(_raahe.karaoke, score)
		tilat.first("karaoke_raahe", 0.3)
		var pct := roundi(score * 100.0)
		if score >= 0.7:
			Sfx.play("win", -4.0)
			tilat.add("moraali", 0.25)
			mielihyva = clampf(mielihyva + 10.0, 0.0, 100.0)
			_show_message("Karaoke %d %%: Kellari raikuu! \"Skooli laulajalle!\"" % pct, 3.5)
		elif score >= 0.4:
			Sfx.play("win_small", -6.0)
			tilat.add("moraali", 0.1)
			_show_message("Karaoke %d %%: kelpo veto. Joku ruukkilainen taputti." % pct, 3.0)
		else:
			Sfx.play("lose", -6.0)
			tilat.add("moraali", -0.1)
			_show_message("Karaoke %d %%: nuotin vierestä. Kellarissa ei räknätä, mutta kuultiin kyllä." % pct, 3.5))
	add_child(game)


func _on_raahe(id: String) -> void:
	raahe_int.walker.controls_enabled = true
	raahe_int.block_interact()
	if id == "takaisin":
		return
	if id.begins_with("visa_"):
		var q: Array = _quiz[_quiz_i]
		var pick: String = q[1][int(id.trim_prefix("visa_"))]
		if pick == q[2]:
			_quiz_right += 1
			Sfx.play("win_small", -8.0)
			raahe_int.quizmaster_say("Oikein! %s." % q[2], 2.5)
		else:
			Sfx.play("lose", -10.0)
			raahe_int.quizmaster_say("Väärin! Oikea vastaus: %s." % q[2], 3.0)
		_quiz_i += 1
		if _quiz_i < _quiz.size():
			_ask_quiz()
			return
		_raahe.quiz = _quiz_right
		tilat.first("pubivisa", 0.3)
		tilat.add("keskittyminen", 0.05 * _quiz_right)
		if _quiz_right == 3:
			tilat.add("moraali", 0.2)
			tilat.add("humala", 0.14)
			_show_message("Visa 3/3! Voitit: visajuoma talon piikkiin. Ruukin porukka: \"Saloisista ja tietää Raahen!\"", 4.0)
		else:
			_show_message("Visa %d/3. Visamestari: \"Ensi tiistaina uudestaan!\"" % _quiz_right, 3.0)
		return
	var m: Array = RAAHE_MENU[id]
	if money < m[1]:
		_show_message("Rahat ei riitä (%s €)." % _eur(money), 2.0)
		return
	money -= m[1]
	tilat.add("humala", m[2])
	tilat.add("stressi", m[3])
	tilat.add("moraali", m[4])
	Sfx.play("glass" if m[2] > 0.0 else "pickup", -6.0, 0.9)
	tilat.first("raahe_" + id, 0.1)
	_show_message("%s. %s" % [m[0], RAAHE_LINES.pick_random()], 3.0)


## Pekan kyyti mökille: vihje ja E. Palauttaa false, jos kyytiä ei voi tarjota (pyörällä, rahaton, häädetty),
## jolloin Pekan kanssa jutellaan.
func _pekka_ride_hint(v: CharacterBody3D, e: bool) -> bool:
	if player == bike or cutscene.busy or hommat.banned_day == day or not story.ride_unlocked():
		return false  # tarinan aikana Pekka ei ehdi (kaupan taksilla Paapeliin pääsee)
	if beers <= 0 and money < PEKKA_RIDE_PRICE:
		return false
	_hint.text = "[E] Pyydä Pekalta kyyti mökille Vaalaan (%s bensarahoiksi)" % ("kalja" if beers > 0 else _eur(PEKKA_RIDE_PRICE) + " €")
	if e:
		v.say("Hyppää kyytiin perkele, lähetään!")
		_pekka_ride()
	return true


## Arto ostaa marjat ja kertoo paikat, Pekka ostaa sienet ja kehuu kyyhkysaaliitaan.
func _neighbor_logic() -> void:
	if _hint.text != "":
		return
	var e := Input.is_action_just_pressed("interact")
	if _story_neighbor(e):
		return
	if sinikka.distance_to_player() < 4.2:
		_sinikka_logic(e)
		return
	for v in [arto, pekka]:
		if v.distance_to_player() > 4.2:
			continue
		var who := "arto" if v == arto else "pekka"
		if who == "arto" and mower_broken and not has_mower_part:
			if player == bike:
				_hint.text = "Nouse pyörän selästä (F), niin voit kysyä Artolta leikkurin varaosaa."
			elif money < LAWN_PART_PRICE:
				_hint.text = "Arto myisi leikkurin varaosan %s eurolla, mutta rahat ei riitä." % _eur(LAWN_PART_PRICE)
			else:
				_hint.text = "[E] Osta Artolta leikkurin varaosa (%s €)" % _eur(LAWN_PART_PRICE)
				if e:
					money -= LAWN_PART_PRICE
					has_mower_part = true
					v.say("Vanhasta Husqvarnasta irtos. Kivikkoon ajoit, vai?")
					Sfx.play("register", -4.0)
					_show_message("Varaosa mukana. Vielä kalja, niin leikkuri korjataan.", 3.0)
					_save_game()
			return
		if who == "pekka" and bitten:
			if player == bike:
				_hint.text = "Nouse pyörän selästä (F), niin Pekka voi katsoa haavaa."
			elif beers <= 0 and money < PEKKA_CARE:
				_hint.text = "Pekka hoitaisi haavan kaljalla tai %s eurolla, mutta kumpaakaan ei ole." % _eur(PEKKA_CARE)
			else:
				_hint.text = "[E] Pyydä Pekkaa hoitamaan haava (%s)" % ("kalja" if beers > 0 else _eur(PEKKA_CARE) + " €")
				if e:
					if beers > 0:
						beers -= 1
						player.set_carrying(beers > 0)
					else:
						money -= PEKKA_CARE
					_heal()
					v.say("Karhu?! No nyt tarvitaan koko pullo." if wound_big else "Ei tää oo mitään, kyyhkyt purree pahemmin.")
					Sfx.play("groan", -4.0, 1.2)
					_show_message("Pekka sitoi haavan ja kaatoi päälle koskenkorvaa. Kirvelee!", 3.5)
			return
		var sale := 0.0
		for k in bucket:
			if GOODS[k].buyer == who:
				sale += bucket[k] * GOODS[k].price
		if who == "arto" and not world.forage_revealed:
			_hint.text = "[E] Juttele Arton kanssa"
			if e:
				world.forage_revealed = true
				v.say("Lähekkö puolukkaan? Merkkaan sulle karttaan parhaat paikat!")
				_show_message("Arto merkitsi marja- ja sienipaikat karttaan (M).", 3.0)
		elif sale > 0.0 and player == bike:
			_hint.text = "Nouse pyörän selästä (F), niin voit myydä %s." % ("marjat" if who == "arto" else "sienet")
		elif sale > 0.0:
			_hint.text = "[E] Myy %s %s €" % ["marjat Artolle" if who == "arto" else "sienet Pekalle", _eur(sale)]
			if e:
				money += sale
				tilat.add("moraali", 0.1)
				for k in bucket.keys():
					if GOODS[k].buyer == who:
						bucket.erase(k)
				v.say("Kiitti! Tästä tulee hyvää puuroa." if who == "arto" else "No perkele, hyviä sieniä! Näistä tulee saatanan hyvä kastike kyyhkyille.")
				Sfx.play("register", -4.0)
				_show_message("+%s €" % _eur(sale), 2.0)
		elif who == "pekka" and _pekka_ride_hint(v, e):
			pass
		else:
			_hint.text = "[E] Juttele %s" % ("Arton kanssa" if who == "arto" else "Pekan kanssa")
			if e:
				v.say((ARTO_LINES if who == "arto" else (Story.PEKKA_WAITING if story.step == "tehtavat" else PEKKA_LINES)).pick_random())
		return


## Sinikka: mustikkatehtävä (pyytää, odottaa, palkitsee piirakalla) ja muuten flirttailevaa puutarhajuttua.
## Päivi huomaa, jos hän on lähellä, kun juttelet Sinikan kanssa.
func _sinikka_logic(e: bool) -> void:
	if player == bike:
		_hint.text = "Nouse pyörän selästä (F), niin voit jutella Sinikan kanssa."
		return
	var berries: int = bucket.get("mustikka", 0)
	if sinikka_task == 1 and berries >= SINIKKA_BERRIES:
		_hint.text = "[E] Anna Sinikalle %d l mustikoita" % SINIKKA_BERRIES
	else:
		_hint.text = "[E] Juttele Sinikan kanssa"
	if not e:
		return
	if sinikka_task == 1 and berries >= SINIKKA_BERRIES:
		bucket["mustikka"] = berries - SINIKKA_BERRIES
		if bucket["mustikka"] <= 0:
			bucket.erase("mustikka")
		food["mustikkapiirakka"] = food.get("mustikkapiirakka", 0) + 1
		sinikka_task = 0
		_once_today("sinikka_piirakka")
		tilat.add("moraali", 0.2)
		tilat.first("sinikka_piirakka", 0.2)
		sinikka.say(SINIKKA_THANKS.pick_random())
		Sfx.play("pickup", -4.0, 0.8)
		_show_message("Sinikka antoi uunituoreen mustikkapiirakan (T syö).", 3.0)
		_save_game()
	elif sinikka_task == 1:
		sinikka.say(SINIKKA_WAIT.pick_random())
		_show_message("Sinikka odottaa %d l mustikoita (ämpärissä %d l)." % [SINIKKA_BERRIES, berries], 2.5)
	elif not ("sinikka_piirakka" in _today):
		sinikka_task = 1
		sinikka.say(SINIKKA_ASK.pick_random())
		_show_message("Tehtävä: poimi metsästä %d l mustikoita ja vie ne Sinikalle." % SINIKKA_BERRIES, 3.5)
		_save_game()
	else:
		sinikka.say(SINIKKA_LINES.pick_random())
	if is_instance_valid(wife) and wife.global_position.distance_to(player.global_position) < 30.0 \
			and _once_today("sinikka_paivi"):
		tilat.add("stressi", -0.2)
		_show_message("Päivi: \"Mitä sää siellä Sinikan pihalla notkut?!\"", 3.0)


## Laavulla: sytytä nuotio (tulitikut), paista makkara, juo kalja -> laavuloppu.
func _laavu_logic() -> void:
	var fire_pos := M.w(M.LAAVU)
	var p := player.global_position
	var d := Vector2(p.x - fire_pos.x, p.z - fire_pos.z).length()
	if _grill_t >= 0.0:
		_grill_t += get_process_delta_time()
		_hint.text = "Makkara paistuu... %d" % ceili(GRILL_TIME - _grill_t)
		if _grill_t >= GRILL_TIME or d > 6.0:
			if _grill_t >= GRILL_TIME:
				sausage_done = true
				_eat(0.5)
				tilat.first("makkaranpaisto")
				_show_message("Makkara valmis! Nam.", 2.5)
				Sfx.play("pickup", -2.0, 0.6)
			_grill_t = -1.0
		return
	if d > 2.8 or _hint.text != "":
		return
	if guard.is_blocking():
		_hint.text = "Laavu on vallattu!"
		return
	if player == bike:
		_hint.text = "Nouse pyörän selästä (F), niin pääset nuotiolle."
		return
	var e: bool = Input.is_action_just_pressed("interact") and not player.is_stunned()
	if not fire_lit and has_matches:
		_hint.text = "[E] Sytytä nuotio"
		if e:
			fire_lit = true
			tilat.add("stressi", 0.1)
			world.fire.visible = true
			Sfx.play("whoosh", 0.0, 0.5)
			_show_message("Nuotio palaa!", 2.0)
	elif fire_lit and has_sausage and not sausage_done:
		_hint.text = "[E] Paista makkaraa"
		if e:
			_grill_t = 0.0
			Sfx.play("whoosh", -6.0, 0.35)
	elif beers > 0:
		_hint.text = "[E] Avaa kalja laavulla"
		if e:
			beers -= 1
			Sfx.play("pickup")
			_win_laavu()
	elif not fire_lit and not has_matches:
		_hint.text = "Nuotiopaikka. Tulitikut ja makkarat saa K-Marketista."
	else:
		_hint.text = "Laavulla olis hyvä juoda kalja. Kaljat saa K-Marketista."


## Laavuloppu: makkaranpaisto auringonlaskussa, laavusta tulee turvapaikka.
## Pelialueen reunalla hahmo kommentoi (enintään kerran 25 sekunnissa).
func _edge_logic() -> void:
	_edge_cd -= get_process_delta_time()
	var p := player.global_position
	if _edge_cd > 0.0 or world._play_edge_dist(Vector2(p.x, p.z)) > 6.0:
		return
	_edge_cd = 25.0
	var px := M.to_px(p)
	var side := "any"
	if px.x < 25.0:
		side = "west"
	elif px.y < 25.0:
		side = "north"
	elif px.y > M.SIZE.y - 25.0:
		side = "south"
	elif px.x > 870.0:
		side = "east"
	if px.x > 950.0 and px.y > 1700.0 and px.y < 2560.0:
		# Laavulta kodalle kaakkoon oikaiseva: oikea reitti on polku laavulta etelään (reittiviitta "Kota").
		_show_message("Tästä ei pääse kodalle. Kodan polku lähtee laavun vierestä etelään – katso reittiviitta \"Kota\".", 4.5)
		return
	var lines: Array = EDGE_LINES[side] + EDGE_LINES["any"]
	_show_message("\"%s\"" % lines.pick_random(), 3.5)


## Pekan auto mökin pihatien päässä (Mokki.RIDE_LOCAL): Pekka palaa kyyhkyjahdista ja vie kotiin Saloisiin.
## Paluu on ilmainen (bensat maksettiin menomatkalla), ettei rahattomana voi jäädä mökille jumiin.
func _mokki_ride_logic() -> void:
	if _hint.text != "" or player.is_stunned() or cutscene.busy:
		return
	var p := player.global_position
	var stand: Vector3 = mokki.to_global(Mokki.RIDE_LOCAL)
	if Vector2(p.x - stand.x, p.z - stand.z).length() >= 3.0:
		return
	if _taxi_mokki_return:
		_hint.text = "[E] Taksilla kotiin Saloisiin (paluu maksettu)"
		if not Input.is_action_just_pressed("interact"):
			return
		_taxi_mokki_return = false
		_hommat_leave_mokki()
		_hud.visible = false
		walker_out.controls_enabled = false
		walker_out.speed = 0.0
		_save_game()
		cutscene.taxi_ride("SALOISIIN", "Taksi vie takaisin Saloisiin. Paluu oli jo maksettu.", Cutscene.TAXI_HOME_LINES,
			_arrive_by_car.bind(home_zone + Vector3(0, 0.3, 4)))
		return
	_hint.text = "[E] Pekan kyydillä kotiin Saloisiin (n. %d km, bensat jo maksettu)" % roundi(HOME_MOKKI_KM)
	if not Input.is_action_just_pressed("interact"):
		return
	var sub := "Pekka palasi kyyhkyjahdista. Matkalla kotiin Saloisiin..."
	if hommat.active:
		var st: int = hommat.stars_now()
		var rv: String = hommat.add_review(day, st)
		sub = "Santun arvostelu: %s\n\"%s\"\nMatkalla kotiin Saloisiin..." % [Hommat.stars(st), rv]
		mokki.say("Ai lähet jo? Hommat jäi kesken..." if st < 5 else "Kiitos käynnistä! Tervetuloa uudestaan!", 3.0)
	_hommat_leave_mokki()
	_ride_pekka_home(sub, "koti")


## Pekan kyydillä mökiltä kotipihaan (kind "koti" tai "haato", ks. cutscene.pekka_ride).
func _ride_pekka_home(sub: String, kind: String) -> void:
	_hud.visible = false
	walker_out.controls_enabled = false
	walker_out.speed = 0.0
	cutscene.pekka_ride(sub, _arrive_by_car.bind(home_zone + Vector3(0, 0.3, 4)), kind)


## Pekan kyydin perillä (ruutu vielä pimeänä): pelaaja määränpäähän, mökillä hommat alkavat.
func _arrive_by_car(dest: Vector3) -> void:
	mokki.ensure_built()  # mökkialue rakennetaan ensimmäisellä matkalla (ruutu on vielä pimeänä)
	walker_out.global_position = dest
	walker_out.rotation.y = 0.0
	walker_out.activate_camera()
	walker_out.controls_enabled = true
	_hud.visible = true  # kyydin ajaksi HUD piilossa
	if _at_mokki_pos(dest):
		_hommat_arrive()
	else:
		_hazards.process_mode = Node.PROCESS_MODE_INHERIT  # takaisin Saloisissa: vaarat heräävät
		if _list_pending:
			_list_pending = false
			_day_note("Tervetuloa kotiin! Tässä tämän päivän lista.", "")  # mökiltä palatessa: päivän lista värikynillä


## Naapurin Pekka lähtee Neittävälle kyyhkyjahtiin ja ottaa kyytiin mökille bensakaljalla tai kympillä.
## Ainoa tie mökille; paluu Pekan autolla mökin pihatien päästä (_mokki_ride_logic).
func _pekka_ride() -> void:
	var paid := "kalja"
	if beers > 0:
		beers -= 1
		player.set_carrying(beers > 0)
	else:
		money -= PEKKA_RIDE_PRICE
		paid = _eur(PEKKA_RIDE_PRICE) + " €"
	tilat.first("mokki", 0.4)
	_hud.visible = false
	walker_out.controls_enabled = false
	walker_out.speed = 0.0
	cutscene.pekka_ride("Naapurin Pekka on menossa Neittävälle kyyhkyjahtiin.\nBensarahat: %s" % paid,
		_arrive_by_car.bind(mokki.gpos(Mokki.RIDE_LOCAL + Vector3(0, 0.3, 2.2))))


## Mökillä: jutut Santun kanssa, Santun hommat, savusauna, palju, tikanheitto, laituri ja metsästyslava.
func _mokki_logic() -> void:
	var p := player.global_position
	var mc := mokki.global_position
	if Vector2(p.x - mc.x, p.z - mc.z).length() > 60.0:
		return
	var dt := get_process_delta_time()
	_smoker_tick(dt)
	_hommat_tick(dt)
	_santtu_chatter(dt)
	_santtu_watch(dt)
	if mowing:
		_mow()
		return
	if _hint.text != "" or player == bike or player.is_stunned():
		return
	var e := Input.is_action_just_pressed("interact")
	var near := func(local: Vector3, r: float) -> bool:
		var g: Vector3 = mokki.to_global(local)
		return Vector2(p.x - g.x, p.z - g.z).length() < r
	if _hommat_logic(e, near):
		return
	if near.call(Mokki.MOPO_LOCAL, 1.8):
		_hint.text = "[E] Aja mopolla Vaalaan Hotelli-Ravintola Siitariin (11,6 km)%s" % (
			"  · Santun hommat kesken!" if hommat.active and not hommat.all_done() else "")
		if e:
			if hommat.active and not hommat.all_done():
				_hommat_snitch()
			_start_mopo()
		return
	if near.call(Mokki.HUUSSI_LOCAL + Vector3(0, 0, 1.3), 1.0):
		_hint.text = "[E] Käy huussissa"
		if e:
			_open_wc_menu("huussi")
		return
	if near.call(Mokki.DOOR_LOCAL, 1.2):
		_hint.text = "[E] Mene sisälle mökkiin"
		if e:
			_enter_mokki()
		return
	if near.call(Mokki.DOOR2_LOCAL, 1.1):
		_hint.text = "[E] Mene sisälle pesuhuoneeseen"
		if e:
			_enter_mokki("ovi2")
		return
	if near.call(Mokki.KITCHEN_LOCAL, 1.6):
		_smoker_logic(e)
		return
	if near.call(Mokki.PINGIS_LOCAL, 1.8):
		_hint.text = "[E] Haasta Santtu pihapingikseen"
		if e:
			_start_pingis()
		return
	if near.call(Mokki.SAUNA_LOCAL, 2.2):
		_sauna_logic(e)
		return
	if near.call(Mokki.TUB_LOCAL, 1.7):
		_palju_logic(e)
		return
	if near.call(Mokki.DART_LOCAL, 1.8):
		_hint.text = "[E] Heitä tikkaa (3 kierrosta Santtua vastaan%s)" % ("" if tikka_ennatys <= 0 else ", ennätys %d" % tikka_ennatys)
		if e:
			_start_darts()
		return
	if near.call(Mokki.DOCK_LOCAL, 2.2):
		_hint.text = "[E] Soutuveneellä kalaan (virveli)"
		if e:
			_start_fishing()
		return
	if near.call(Mokki.HUNT_LOCAL, 2.4):
		_hunt_logic(e)
		return
	# Santtu viimeisenä: hommia katsomaan tullut Santtu ei saa peittää homman omaa toimintoa.
	if mokki.santtu.visible and near.call(mokki.santtu.position, 2.6):
		_hint.text = "[E] Jutskaa Santun kanssa"
		if e:
			_santtu_menu()
		return


## Savusauna: sylit halkopinosta pesään, lämpö täyteen, savut tuulettumaan ja sitten löylyihin. Liian aikaisin
## sisään mennessä häkä kirvelee.
func _sauna_logic(e: bool) -> void:
	var pct := roundi(mokki.sauna_heat * 100.0)
	if mokki.sauna_fire_on:
		if _carry == "halot":
			_hint.text = "[E] Lisää syli halkoja pesään (lämpö %d %%, tulta %d s)" % [pct, ceili(mokki.sauna_fuel)]
			if e:
				if mokki.sauna_add_wood():
					_set_carry("")
					Sfx.play("whoosh", -2.0, 0.6)
					_show_message("Halot pesään. Savua tupruaa ovesta ja räppänästä.", 2.0)
				else:
					_show_message("Pesä on vielä täynnä. Anna palaa hetki.", 2.0)
		else:
			_hint.text = "Savusauna lämpiää %d %% · tulta %d s%s" % [pct, ceili(mokki.sauna_fuel),
				" · hae lisää puita halkopinosta!" if mokki.sauna_fuel < 15.0 else ""]
	elif mokki.sauna_ready():
		_hint.text = "[E] Käy löylyssä"
		if e:
			_sauna_cutscene()
	elif mokki.sauna_heated and mokki.sauna_smoke > 0.05:
		_hint.text = "Savut tuulettuu... %d s · [E] Mene silti (häkää!)" % ceili(mokki.sauna_smoke * Mokki.SAUNA_CLEAR)
		if e:
			tilat.add("kipu", -0.2)
			tilat.add("vireys", -0.2)
			tilat.add("stressi", -0.1)
			Sfx.play("grunt", -2.0, 0.8)
			_show_message("Häkää! Silmiä kirvelee ja päätä särkee. Savujen pitää tuulettua ensin.", 3.0)
			_santtu_line("Älä mene sinne vielä, siellä on häkää! Savusaunassa on tarkkuutta.")
	elif _carry == "halot":
		_hint.text = "[E] Pane halot pesään ja sytytä%s" % (" (kiuas %d %%)" % pct if pct > 0 else "")
		if e:
			mokki.sauna_add_wood()
			_set_carry("")
			if _once_today("kiuas"):
				tilat.add("stressi", 0.1)  # tulen teko rauhoittaa kuten nuotiolla
			Sfx.play("whoosh", 0.0, 0.6)
			_show_message("Tuli syttyi savusaunan kiukaaseen. Pidä pesä täynnä, kunnes kiuas on kuuma.", 3.0)
	else:
		_hint.text = "Savusaunan kiuas on %s. Hae syli halkoja halkopinosta kesäkeittiön vierestä." % (
			"haalea (%d %%)" % pct if pct > 5 else "kylmä")


func _on_sauna_event(kind: String) -> void:
	match kind:
		"kuuma":
			_show_message("Savusaunan kiuas on kuuma! Pesä palaa loppuun: anna savujen tuulettua ennen löylyä.", 3.5)
			if hommat.pending("savusauna"):
				_santtu_line("Nyt on lämmintä! Ovi auki ja savut pihalle.")
		"sammui":
			_show_message("Savusaunan tuli sammui ennen kuin kiuas ehti kuumaksi! Hae lisää halkoja.", 3.0)
			if hommat.pending("savusauna"):
				hommat.add_hermo(3.0)
				_santtu_line("Tuli sammui! Lisää puuta, ettei kiuas jäähdy.")
		"valmis":
			_show_message("Savut tuulettuneet: savusauna on valmis löylyihin!", 3.0)
			_hommat_complete("savusauna")


## Palju: Santun hommana tyhjennys, pesu ja täyttö pumpulla järvestä, muuten kamiina ja kylpy.
func _palju_logic(e: bool) -> void:
	if hommat.pending("palju"):
		if mokki.palju_dirt > 0.0:
			if _palju_draining:
				_hint.text = "Vanha vesi valuu venttiilistä... %d %%" % roundi(mokki.palju_level * 100.0)
			elif mokki.palju_level > 0.02:
				_hint.text = "[E] Avaa tyhjennysventtiili (vanha vihreä vesi pois)"
				if e:
					_palju_draining = true
					Sfx.play("water", -2.0, 0.6)
					_show_message("Venttiili auki: vihreä vesi lorisee nurmelle.", 2.5)
			else:
				_hint.text = "Pidä E pohjassa: harjaa levät ja lehdet pois (%d %%)" % roundi((1.0 - mokki.palju_dirt) * 100.0)
				if Input.is_action_pressed("interact"):
					var dt := get_process_delta_time()
					mokki.palju_dirt = maxf(0.0, mokki.palju_dirt - dt / 6.0)
					if Engine.get_process_frames() % 20 == 0:
						Sfx.play("whoosh", -10.0, 1.6)
					if mokki.palju_dirt <= 0.0:
						mokki.set_hose(true)
						Sfx.play("pickup", -4.0)
						_show_message("Palju on puhdas! Käynnistä pumppu rannassa laiturin vieressä.", 3.0)
						_santtu_line("Kiiltää! Pumppu on rannassa, letku on jo vedetty.")
		elif mokki.pump_on:
			_hint.text = "Palju täyttyy... %d %%%s" % [roundi(minf(mokki.palju_level, 1.0) * 100.0),
				"  · SAMMUTA PUMPPU RANNASSA!" if mokki.palju_level >= 0.95 else ""]
		else:
			_hint.text = "Palju on puhdas mutta %s. Pumppu on rannassa laiturin vieressä." % (
				"tyhjä" if mokki.palju_level < 0.05 else "vajaa (%d %%)" % roundi(mokki.palju_level * 100.0))
		return
	if mokki.palju_level < 0.9:
		_hint.text = "Palju on tyhjä."
		return
	if not mokki.tub_fire_on:
		_hint.text = "[E] Sytytä paljun kamiina"
		if e:
			mokki.set_tub_fire(true)
			if _once_today("ammeen_tuli"):
				tilat.add("stressi", 0.1)
			Sfx.play("whoosh", 0.0, 0.5)
			_show_message("Kamiina palaa paljun kyljessä. Vesi lämpiää hitaasti.", 2.5)
	elif not mokki.tub_ready():
		_hint.text = "Palju lämpiää... %d s" % ceili(Mokki.TUB_HEAT - (Mokki.TUB_BURN - mokki.tub_fire_time))
	else:
		_hint.text = "[E] Mene paljuun"
		if e:
			walker_out.stamina = 100.0
			walker_out.exhausted = false
			Sfx.play("water", -4.0, 0.7)
			_show_message("Palju lämmittää. Kunto palautui.", 2.5)
			tilat.first("poreamme", 0.3)
			if _once_today("amme"):
				tilat.add("stressi", 0.3)
				tilat.add("kipu", 0.2)
				tilat.add("stamina", 0.2)


## Lähin löytämätön viinakätkö (indeksi Mokki.VIINA:ssa, -1 = kaikki löydetty) ja sen paikka maailmassa.
func _viina_nearest() -> Array:
	var p := player.global_position
	var best := -1
	var best_pos := Vector3.ZERO
	var best_d := INF
	var pos: Array[Vector2] = Mokki.viina_positions()
	for i in pos.size():
		if Mokki.VIINA[i].id in viina_found:
			continue
		var g: Vector3 = mokki.to_global(Vector3(pos[i].x, 0, pos[i].y))
		var d := Vector2(p.x - g.x, p.z - g.z).length()
		if d < best_d:
			best = i
			best_d = d
			best_pos = g
	return [best, best_pos, best_d]


## Viinakätköt geokätköjen tapaan: kompassi ja HUD näyttävät lähimmän kätkön suunnan ja matkan, E avaa kätkön.
func _viina_logic() -> void:
	var n: Array = _viina_nearest()
	_compass.has_cache = n[0] >= 0
	if n[0] < 0:
		return
	var at: Vector3 = n[1]
	_compass.cache = Vector2(at.x, at.z)
	if n[2] > VIINA_OPEN_R or _hint.text != "" or player == bike or player.is_stunned():
		return
	var c: Dictionary = Mokki.VIINA[n[0]]
	_hint.text = "[E] Avaa viinakätkö"
	if not Input.is_action_just_pressed("interact"):
		return
	viina_found.append(c.id)
	viina_pullot += 1
	tilat.first("viinakatko", 0.3)
	if viina_found.size() == Mokki.VIINA.size():
		tilat.add("moraali", 0.2)
		Sfx.play("win_small")
	else:
		Sfx.play("pickup", -4.0, 0.8)
	_show_message("Viinakätkö löytyi %s! Laatikossa %s. Kirjoitit nimesi lokikirjaan. (%d / %d)%s" % [c.spot, c.desc,
		viina_found.size(), Mokki.VIINA.size(), "\nKaikki kätköt löydetty!" if viina_found.size() == Mokki.VIINA.size() else ""], 4.0)
	_save_game()


# --- Santun hommat ---------------------------------------------------------------------------------------------
# Ensimmäisen mökkiyön jälkeen Santtu antaa aamulapussa päivän hommat (santun_hommat.gd). Tekemättömät hommat
# kiristävät hermoja, ja täysillä hermoilla tulee lähtö. Santtu tulee katsomaan ja kommentoimaan jokaista hommaa.

## Taksilla mökille: hommat alkavat vasta, kun mökillä on oltu yö.
func _hommat_arrive() -> void:
	tilat.ensure("humala")  # mökillä humalatila on aina yksi päivän kolmesta tilasta
	hommat.stop()
	hommat.nights = 0
	_hommat_prepare()


## Lähtö mökiltä (taksi kotiin tai häätö): kesken jääneet tavarat pois käsistä ja Santtu kannolle.
func _hommat_leave_mokki() -> void:
	_stop_mowing()
	_set_carry("")
	_palju_draining = false
	hommat.stop()
	hommat.nights = 0
	if mokki.built:
		mokki.set_pump(false)
		mokki.santtu_go_home()
	_watch_task = ""
	_save_game()


## Aamu mökillä: päivän hommat arvotaan ja ne kirjoitetaan Santun lappuun (ruskealla kynällä).
func _hommat_morning() -> Array:
	tilat.ensure("humala")
	hommat.start_day()
	_hommat_prepare()
	if not hommat.active:
		return []
	var rows: Array = ["Tämän päivän hommat:"]
	for r in hommat.lappu_rows():
		rows.append([r, Color(0.5, 0.26, 0.08)])
	if hommat.hermo > 1.0:
		rows.append("Eilisistä jäi vielä vähän hampaankoloon.")
	rows.append("Jos hommat jää tekemättä, mulla menee hermot. Kalja auttaa.")
	rows.append("")
	return rows


## Pihan esineet päivän hommien mukaan: ampiaispesä, huussin kärpäset, lahot laudat, pitkä nurmikko, likainen
## palju, tiskit ja PA:n sotkut. Hommattomana päivänä kaikki on siistiä.
func _hommat_prepare() -> void:
	if mokki == null or not mokki.built:
		return
	_ensure_mokki_lawn()
	var nest: Node3D = mokki.wasp_nest
	if not nest.has_meta("home"):
		nest.set_meta("home", nest.position)
	nest.position = nest.get_meta("home")
	nest.visible = hommat.pending("ampiaiset")
	mokki.huussi_flies.emitting = hommat.pending("huussi")
	_dock_state = LaituriGame.new_state() if hommat.pending("laituri") else []
	LaituriGame.build_patch(mokki.dock_patch, _dock_state, _dock_fix_z())
	_ranni_state = []
	mokki_lawn.lengths.fill(0.42 if hommat.pending("nurmi") else 0.05)
	mokki_lawn._dirty = true
	mokki_lawn.spawn_objects()
	mokki_lawn.park_mower()
	mokki.palju_level = 1.0
	mokki.palju_dirt = 1.0 if hommat.pending("palju") else 0.0
	mokki.set_pump(false)
	mokki.set_hose(false)
	_palju_draining = false
	_palju_overflow = 0.0
	mokki_int.set_dishes(TiskiGame.DISHES.size() if hommat.pending("kahvi") else 0)
	if hommat.pending("pa") and mokki_int.pa_on:
		mokki_int.set_pa(false)
		mokki.set_pa_level(0.0)
	_mokki_polkyt = 0
	_mokki_halot = 0
	_watch_task = ""


func _ensure_mokki_lawn() -> void:
	if mokki_lawn != null:
		return
	var r: Rect2 = Mokki.LAWN_RECT
	var c: Vector3 = mokki.to_global(Vector3(r.get_center().x, 0, r.get_center().y))
	mokki_lawn = Lawn.new()
	mokki_lawn.rect = Rect2(-r.size / 2.0, r.size)
	mokki_lawn.pivot = Vector2(c.x, c.z)
	mokki_lawn.angle = -mokki.global_rotation.y
	mokki_lawn.mower_park = mokki.gpos(Mokki.LAWN_MOWER_LOCAL)
	mokki_lawn.kinds = ["kivi"]
	var mk := mokki
	mokki_lawn.height_fn = func(x: float, z: float) -> float:
		var l: Vector3 = mk.to_local(Vector3(x, 0, z))
		return mk.global_position.y + Mokki.h(l.x, l.z)
	add_child(mokki_lawn)


## Kivi Santun leikkurin terään: yskii, ja joka toisella kerralla sammuu (naru uudestaan).
func _mokki_lawn_hit(o: Dictionary) -> void:
	mokki_lawn.remove_object(o)
	Sfx.play("rattle_hard", 0.0, 0.8)
	mokki_lawn.cough()
	var n: int = hommat.progress.get("kivet", 0) + 1
	hommat.progress["kivet"] = n
	if n % 2 == 0:
		_stop_mowing()
		_show_message("KOLAHDUS! Kivi terään ja vanha leikkuri sammui. Vedä naru uudestaan (E).", 3.0)
	else:
		_show_message("KOLAHDUS! Kivi terään, leikkuri yskii.", 2.5)
	_santtu_line(["Kivistä varo, terä on ainut!", "Mun leikkuri! Se on vanhempi ku sää.", "Ei sitä noin ajeta!"].pick_random())


## Kannettava käteen (tyhjä = kädet vapaiksi).
func _set_carry(kind: String) -> void:
	_carry = kind
	_carry_slosh = 0.0
	if walker_out != null:
		walker_out.set_held(Hommat.held_model(kind) if kind != "" else null)


## Hommien kello: kannettavan läikkyminen, paljun tyhjennys ja tulva, Santun hermot ja häätö.
func _hommat_tick(dt: float) -> void:
	if _carry in ["sanko", "kahvi"] and state in ["to_shop", "to_home"]:
		var running: bool = walker_out.speed > 3.2
		_carry_slosh = clampf(_carry_slosh + (0.9 if running else -0.35) * dt + tilat.value("humala") * 0.4 * dt * randf(), 0.0, 1.0)
		if walker_out.is_stunned():
			_carry_slosh = 1.0
		if _carry_slosh >= 1.0:
			_spill()
	if mokki.built:
		if _palju_draining:
			mokki.palju_level = maxf(0.0, mokki.palju_level - dt / Mokki.PALJU_DRAIN)
			if mokki.palju_level <= 0.0:
				_palju_draining = false
				_show_message("Palju on tyhjä. Nyt harjaa levät pois (pidä E pohjassa paljun vieressä).", 3.0)
		if mokki.pump_on and mokki.palju_level > 1.05:
			_palju_overflow += dt
			if _palju_overflow > 5.0 and not hommat.progress.has("tulva"):
				hommat.progress["tulva"] = true
				hommat.add_hermo(8.0)
				_santtu_line("Palju tulvii yli! Ei sitä järveä tarvi kokonaan siirtää!", true)
	if not hommat.active:
		return
	if state in ["to_shop", "to_home", "in_mokki"] and not cutscene.busy and not _item_menu.is_open():
		var lv: int = hommat.tick(dt)
		if lv >= 0:
			_santtu_line(Hommat.HERMO_LINES[lv].pick_random(), true)
		if hommat.furious():
			_hommat_evict()


## Liian kova vauhti: sanko tai kahvi läikkyy.
func _spill() -> void:
	match _carry:
		"sanko":
			Sfx.play("water", -2.0, 0.5)
			tilat.add("stressi", -0.15)
			tilat.add("moraali", -0.1)
			hommat.add_hermo(4.0)
			_show_message("Sanko läikkyi kengille! Hyi helvetti. Hae uusi sanko huussin takaluukusta.", 3.5)
			_santtu_line("Ei juosta sangon kanssa! Nyt haisee koko piha.", false)
		"kahvi":
			Sfx.play("glass", -4.0, 1.3)
			hommat.progress["kahvi_keitetty"] = false
			_show_message("Kahvit läikkyi! Keitä uudet kahvit tuvassa ja kävele rauhassa.", 3.0)
			_santtu_line("Mun kahvit! Kävele, älä juokse.", false)
	_set_carry("")


## Hommien toiminnot pihalla. Palauttaa true, jos jokin homma otti vihjeen.
func _hommat_logic(e: bool, near: Callable) -> bool:
	if near.call(Mokki.HALKO_LOCAL, 1.4):
		if _carry == "":
			_hint.text = "[E] Ota syli halkoja (savusaunan pesään)"
			if e:
				_set_carry("halot")
				Sfx.play("cloth", -4.0, 0.7)
		elif _carry == "halot":
			_hint.text = "[E] Laita halot takaisin pinoon"
			if e:
				_set_carry("")
		else:
			return false
		return true
	if near.call(Mokki.PUU_SAW_LOCAL, 1.6):
		_hint.text = "[E] Sahaa saunapuita pukilla (pölkkyjä %d)" % _mokki_polkyt
		if e:
			_start_mokki_saw()
		return true
	if near.call(Mokki.PUU_CHOP_LOCAL, 1.4):
		_hint.text = "[E] Halko pölkkyjä (pölkkyjä %d%s)" % [_mokki_polkyt,
			", halottu %d / 8" % _mokki_halot if hommat.pending("puut") else ""]
		if e:
			_start_mokki_chop()
		return true
	if mokki_lawn != null and near.call(mokki.to_local(mokki_lawn.mower.global_position), 1.6):
		if hommat.pending("nurmi"):
			_hint.text = "[E] Käynnistä Santun vanha leikkuri (leikattu %d %%)" % roundi(mokki_lawn.cut_ratio() * 100.0)
			if e:
				_start_mowing(mokki_lawn)
		else:
			_hint.text = "Santun vanha leikkuri. Päädyn nurmikko on leikattu."
		return true
	if hommat.pending("huussi"):
		var trips: int = hommat.progress.get("sangot", 0)
		if trips < 3 and near.call(Mokki.HUUSSI_HATCH_LOCAL, 1.3):
			if _carry == "":
				_hint.text = "[E] Ota täysi sanko huussin takaluukusta (%d / 3)" % trips
				if e:
					_set_carry("sanko")
					Sfx.play("rattle", -6.0, 0.7)
					_show_message("Sanko on täynnä ja haisee. Kanna se kompostiin: kävele rauhassa, ettei läiky.", 3.0)
			else:
				_hint.text = "Kädet täynnä. Vie ensin %s." % ("sanko kompostiin" if _carry == "sanko" else "tavarat pois")
			return true
		if near.call(Mokki.KOMPOSTI_LOCAL, 1.9):
			if _carry == "sanko":
				_hint.text = "[E] Kaada sanko kompostiin"
				if e:
					trips += 1
					hommat.progress["sangot"] = trips
					_set_carry("")
					Sfx.play("water", -6.0, 0.5)
					if trips >= 3:
						mokki.huussi_flies.emitting = false
						_show_message("Huussi on tyhjä! Nyt komposti talikolla ympäri.", 3.0)
					else:
						_show_message("Plörts. Sanko kompostiin (%d / 3)." % trips, 2.0)
			elif trips >= 3:
				var t: float = hommat.progress.get("komposti", 0.0)
				_hint.text = "[E] Käännä kompostia talikolla (%d %%) · hakkaa E:tä" % roundi(t * 100.0)
				if e:
					t += 0.1
					hommat.progress["komposti"] = t
					Sfx.play("rattle", -8.0, 0.6)
					mokki.komposti_soil.rotation.y = randf_range(-0.1, 0.1)
					mokki.komposti_soil.scale.y = 0.9 + randf() * 0.15
					tilat.add("stamina", -0.01)
					if t >= 1.0:
						_hommat_complete("huussi")
			else:
				_hint.text = "Komposti odottaa huussin sankoja (%d / 3)." % trips
			return true
	if hommat.pending("ranni") and near.call(Mokki.LADDER_LOCAL, 1.5):
		_hint.text = "[E] Kiipeä tikkaille putsaamaan rännit" + ("  (olet kännissä!)" if tilat.value("humala") > 0.3 else "")
		if e:
			_start_ranni()
		return true
	if hommat.pending("ampiaiset") and near.call(Mokki.WASP_STAND_LOCAL, 1.4):
		_hint.text = "[E] Hävitä ampiaispesä (myrkkypurkki saunan penkiltä)"
		if e:
			_start_ampiaiset()
		return true
	if hommat.pending("laituri") and mokki.dock_body != null and near.call(_dock_fix_local(), 1.4):
		_hint.text = "[E] Korjaa laiturin lahot laudat (sorkkarauta, vasara ja naulat)"
		if e:
			_start_laituri()
		return true
	if near.call(Mokki.pump_local(), 1.5):
		if hommat.pending("palju") and mokki.palju_dirt <= 0.0 and not _palju_draining:
			if mokki.pump_on:
				_hint.text = "[E] Sammuta pumppu (palju %d %%)" % roundi(minf(mokki.palju_level, 1.0) * 100.0)
				if e:
					mokki.set_pump(false)
					_palju_pump_off()
			else:
				_hint.text = "[E] Käynnistä pumppu: täytä palju järvivedellä (%d %%)" % roundi(mokki.palju_level * 100.0)
				if e:
					mokki.set_pump(true)
					Sfx.play("pedal_creak", -4.0, 0.5)
					_show_message("Pumppu pärähti käyntiin! Muista sammuttaa, kun palju on täynnä.", 3.0)
		else:
			_hint.text = "Bensapumppu paljun täyttöön."
		return true
	if _carry == "kahvi" and near.call(mokki.santtu.position, 2.2):
		_hint.text = "[E] Anna kahvit Santulle"
		if e:
			hommat.progress["kahvi_vietu"] = true
			_set_carry("")
			Sfx.play("glass", -8.0, 1.4)
			tilat.add("moraali", 0.05)
			if mokki_int.dishes <= 0:
				_hommat_complete("kahvi")
			else:
				mokki.say("Ahh. Musta ja kuuma, niinku pitää. Tiskit vielä, niin on homma tehty.", 4.0)
		return true
	return false


func _palju_pump_off() -> void:
	if mokki.palju_level >= 0.95:
		mokki.palju_level = minf(mokki.palju_level, 1.0)
		mokki.set_hose(false)
		_hommat_complete("palju")
	else:
		_show_message("Pumppu sammui. Palju on vasta %d %% täynnä." % roundi(mokki.palju_level * 100.0), 2.5)


## Laiturin paikkalautojen alku laiturin kehyksessä (lautojen jaossa) ja korjauskohdan paikka mökin kehyksessä.
func _dock_fix_z() -> float:
	if mokki.dock_body == null:
		return 0.0
	return roundf((Mokki.DOCK_FIX_LOCAL.z - mokki.dock_body.position.z) / LaituriGame.PITCH) * LaituriGame.PITCH


func _dock_fix_local() -> Vector3:
	return mokki.dock_body.position + Vector3(0, 0, _dock_fix_z() - 0.6)


## Homma tehty pelaajan toimesta.
func _hommat_complete(id: String) -> void:
	if not hommat.complete(id):
		return
	_hommat_finished(id, false)


## Homman jälkeen: piha näyttää tehdyltä, Santtu kommentoi, ja kaikki tehty = palkinto.
func _hommat_finished(id: String, by_santtu: bool) -> void:
	_hommat_visual_done(id)
	var nimi: String = Hommat.TASKS[id].nimi
	if not by_santtu:
		tilat.add("moraali", 0.1)
		tilat.add("stressi", 0.1)
		tilat.first("homma_" + id, 0.2)
		Sfx.play("win_small", -4.0)
		_santtu_line(hommat.line(id, "valmis"))
		_queue_message("Santun homma tehty: %s! (%d / %d)" % [nimi, hommat.done.size(), hommat.tasks.size()], 3.0)
	if hommat.all_done():
		_hommat_reward()
	_save_game()


func _hommat_visual_done(id: String) -> void:
	match id:
		"ampiaiset":
			mokki.wasp_nest.visible = false
		"huussi":
			mokki.huussi_flies.emitting = false
		"laituri":
			for sl in _dock_state:
				sl.s = "valmis"
				sl.nails = [1.0, 1.0]
				sl.bent = [false, false]
			LaituriGame.build_patch(mokki.dock_patch, _dock_state, _dock_fix_z())
		"nurmi":
			mokki_lawn.lengths.fill(0.05)
			mokki_lawn._dirty = true
		"palju":
			mokki.palju_dirt = 0.0
			mokki.palju_level = 1.0
			mokki.set_pump(false)
			mokki.set_hose(false)
			_palju_draining = false
		"kahvi":
			mokki_int.set_dishes(0)
			if _carry == "kahvi":
				_set_carry("")
		"savusauna":
			mokki.sauna_heated = true
			mokki.sauna_heat = maxf(mokki.sauna_heat, 0.9)
			mokki.sauna_smoke = 0.0


## Kaikki hommat tehty: Santtu maksaa kyytirahat takaisin, antaa savukalaa ja pullon pontikkaa.
func _hommat_reward() -> void:
	money += PEKKA_RIDE_PRICE
	food["savukala"] = food.get("savukala", 0) + 1
	viina_pullot += 1
	tilat.add("moraali", 0.3)
	tilat.add("stressi", 0.2)
	mielihyva = clampf(mielihyva + 15.0, 0.0, 100.0)
	Sfx.play("win", -4.0)
	_santtu_line("Kaikki hommat tehty! Viiden tähden vieras!", false)
	_queue_message("KAIKKI SANTUN HOMMAT TEHTY!\nSanttu maksoi kyytirahat takaisin (%s €), antoi savukalaa ja pullon pontikkaa." % _eur(PEKKA_RIDE_PRICE), 5.0)


## Mopolla Siitariin hommat kesken: Santtu huutaa perään ja soittaa Päiville.
func _hommat_snitch() -> void:
	mokki.say(Hommat.LEAVE_LINES.pick_random(), 4.0)
	if hommat.snitched:
		return
	hommat.snitched = true
	hommat.add_hermo(Hommat.HERMO_LEAVE)
	_santtu_gossip = true
	_paivi_call_kind = "santtu"
	_paivi_call_t = randf_range(9.0, 14.0)


## Hermot meni: yhden tähden arvostelu, Santtu soittaa Pekan hakemaan ja mökille ei pääse ennen huomista.
func _hommat_evict() -> void:
	if not hommat.active:
		return
	var rv: String = hommat.add_review(day, 1)
	hommat.banned_day = day
	if state == "in_mokki":
		mokki_int.leave()
		state = _mokki_prev
		walker_out.global_position = mokki.porch_pos(0.9)
		walker_out.activate_camera()
	if state == "in_mokki" or state == "cutscene":
		state = "to_shop"
	_hommat_leave_mokki()
	tilat.add("moraali", -0.3)
	tilat.add("stressi", -0.25)
	mokki.say("Nyt riitti! Mää soitin Pekalle. Kamat kassiin!", 4.0)
	Sfx.play("alert", -2.0, 0.8)
	_show_message("Santun hermot meni! \"Nyt riitti, Pekka tulee hakemaan!\"", 3.0)
	walker_out.controls_enabled = false
	walker_out.speed = 0.0
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		_ride_pekka_home("Santun hermot meni. Pekka haki kotiin Saloisiin...\nSantun arvostelu: %s\n\"%s\"" % [
			Hommat.stars(1), rv], "haato"))


## Santun repliikki: pihalla puhekupla Santun päällä, sisällä sisä-Santulle, msg = myös viestinä ruudulle.
func _santtu_line(text: String, msg := false) -> void:
	if state == "in_mokki":
		mokki_int.say(text)
	else:
		mokki.say(text, 3.8)
	if msg:
		_queue_message("Santtu: \"%s\"" % text, 3.0)


## Santun juttelu kannolta: hommapäivinä huutelua hommista ja hermojen mukaan, muuten mökkijuttuja.
func _santtu_chatter(dt: float) -> void:
	_santtu_chat_t -= dt
	if _santtu_chat_t > 0.0 or mokki.santtu_out():
		return
	_santtu_chat_t = randf_range(10.0, 18.0)
	var sc: Vector3 = mokki.santtu.global_position
	var d := Vector2(player.global_position.x - sc.x, player.global_position.z - sc.z).length()
	if hommat.active and not hommat.all_done():
		_santtu_chat_t = randf_range(16.0, 26.0)
		var lv: int = hommat.level()
		var line: String = Hommat.HERMO_LINES[lv].pick_random() if lv >= 0 and randf() < 0.5 else \
			hommat.line(hommat.undone().pick_random(), "huuto")
		mokki.say(line, 3.8)
		if d > 12.0 and _hint.text == "":
			_queue_message("Santtu huutaa kuistilta: \"%s\"" % line, 3.0)
	elif d < SAUNA_TALK_RADIUS:
		mokki.say(Mokki.SANTTU_AMBIENT.pick_random())


## Mikä homma on käynnissä pelaajan lähellä: [id, paikka mökin kehyksessä] tai []. Santtu tulee sinne katsomaan.
func _watch_context() -> Array:
	var lp: Vector3 = mokki.to_local(player.global_position)
	var near := func(local: Vector3, r: float) -> bool:
		return Vector2(lp.x - local.x, lp.z - local.z).length() < r
	if mowing and _mow_lawn == mokki_lawn:
		return ["nurmi", lp]
	if hommat.pending("huussi") and (_carry == "sanko" or near.call(Mokki.HUUSSI_HATCH_LOCAL, 3.0) or near.call(Mokki.KOMPOSTI_LOCAL, 3.0)):
		return ["huussi", lp]
	if hommat.pending("savusauna") and (_carry == "halot" or (near.call(Mokki.SAUNA_LOCAL, 4.0) and (mokki.sauna_fire_on or mokki.sauna_heated))):
		return ["savusauna", lp if _carry == "halot" else Mokki.SAUNA_LOCAL]
	if hommat.pending("palju") and (near.call(Mokki.TUB_LOCAL, 3.5) or near.call(Mokki.pump_local(), 3.0)):
		return ["palju", lp]
	if hommat.pending("savustus") and near.call(Mokki.KITCHEN_LOCAL, 3.5) and not smoker_load.is_empty():
		return ["savustus", Mokki.KITCHEN_LOCAL]
	if hommat.pending("puut") and (near.call(Mokki.PUU_SAW_LOCAL, 3.5) or near.call(Mokki.PUU_CHOP_LOCAL, 3.5)):
		return ["puut", Mokki.PUU_CHOP_LOCAL]
	if hommat.pending("ranni") and near.call(Mokki.LADDER_LOCAL, 3.5):
		return ["ranni", Mokki.LADDER_LOCAL]
	if hommat.pending("ampiaiset") and near.call(Mokki.WASP_STAND_LOCAL, 3.5):
		return ["ampiaiset", Mokki.WASP_STAND_LOCAL + Vector3(0.6, 0, -2.8)]
	if hommat.pending("laituri") and mokki.dock_body != null and near.call(_dock_fix_local(), 3.5):
		return ["laituri", _dock_fix_local()]
	if hommat.pending("metsastys") and near.call(Mokki.HUNT_LOCAL, 4.0):
		return ["metsastys", Mokki.HUNT_LOCAL]
	return []


## Santun puuhastelu (santtu_puuhat.gd): saa puuhata pihalla, kun hommia ei katsota eikä minipeli ole käynnissä.
## Pelaajan paikka kertoo, mistä Santtu väistää, ja tänään annettuja hommia Santtu ei tee itse.
func _puuhat_tick(at_mokki: bool) -> void:
	var pu: Node = mokki.puuhat
	pu.enabled = at_mokki and state in ["to_shop", "to_home", "in_mokki"] and _watch_task == "" and not cutscene.busy
	pu.player_local = mokki.to_local(player.global_position) if state != "in_mokki" else Vector3.INF
	pu.pending = hommat.undone() if hommat.active else []


## Santtu nousee kannolta ja kävelee katsomaan käynnissä olevaa hommaa, tulee perille, kommentoi ja palaa
## kannolle, kun hommaa ei hetkeen tehdä.
func _santtu_watch(dt: float) -> void:
	if not hommat.active or state not in ["to_shop", "to_home"]:
		return
	var ctx := _watch_context()
	if ctx.is_empty():
		if _watch_task != "":
			_watch_idle += dt
			if _watch_idle > 5.0:
				_watch_task = ""
				mokki.santtu_go_home()
		return
	_watch_idle = 0.0
	var id: String = ctx[0]
	var spot: Vector3 = ctx[1]
	var lp: Vector3 = mokki.to_local(player.global_position)
	_watch_retarget -= dt
	var sp: Vector3 = mokki.santtu.position
	var far := Vector2(sp.x - spot.x, sp.z - spot.z).length() > 4.5
	if id != _watch_task or (far and _watch_retarget <= 0.0 and mokki.santtu_arrived()):
		mokki.puuhat.enabled = false  # hommien katsominen ennen puuhia (sama ruutu)
		if id != _watch_task:
			_watch_arrived = false
		_watch_task = id
		_watch_retarget = 2.0
		mokki.santtu_visit(spot, lp)
	if not _watch_arrived and mokki.santtu_arrived():
		_watch_arrived = true
		_watch_t = randf_range(7.0, 11.0)
		mokki.say(hommat.line(id, "tulee"), 3.8)
	elif _watch_arrived:
		_watch_t -= dt
		if _watch_t <= 0.0:
			_watch_t = randf_range(8.0, 13.0)
			mokki.say(hommat.line(id, "kesken"), 3.8)


## Santun valikko kannolla: juttelu, päivän hommat ja kalja (Santtu tekee yhden homman).
func _santtu_menu() -> void:
	var items: Array = [["juttu", "Jutskaa Santun kanssa"]]
	if bitten:
		items.append(["haava", "Pyydä Santtua hoitamaan haava"])
	if hommat.active:
		items.append(["hommat", "Mitä hommia vielä on?"])
		if not hommat.beer_used and not hommat.all_done():
			if beers > 0:
				items.append(["kalja", "Tarjoa Santulle kalja (hän tekee yhden homman)"])
			elif viina_pullot > 0:
				items.append(["viina", "Tarjoa Santulle kätköviinaa (hän tekee yhden homman)"])
	if items.size() == 1:
		_on_santtu_menu("juttu")
		return
	items.append(["takaisin", "Takaisin"])
	player.controls_enabled = false
	player.speed = 0.0
	_menu_mode = "santtu"
	_item_menu.open(items, "Santtu, isäntä · hermot: %s" % hommat.mood())


func _on_santtu_menu(id: String) -> void:
	player.controls_enabled = true
	match id:
		"juttu":
			mokki.say(_santtu_chat_line())
			tilat.first("santtu")
		"haava":
			var care: Array = SANTTU_CARE.pick_random()
			var big := wound_big
			_heal()
			mokki.say(("Karhu? Ei hätää, mää oon nähny pahempaa. " if big else "") + care[1], 4.0)
			Sfx.play("groan", -4.0, 1.1)
			_show_message(care[0], 4.0)
			tilat.first("santtu_hoiti", 0.2)
		"hommat":
			var left: Array = hommat.undone()
			if left.is_empty():
				mokki.say("Kaikki tehty! Ota rennosti, kahvit on keittiössä.", 3.5)
			else:
				var id0: String = left[0]
				mokki.say(hommat.line(id0, "anna"), 5.0)
				_show_message("Santun hommat: " + ", ".join(left.map(func(t): return Hommat.TASKS[t].nimi)) +
					"\nHermot: %s %s" % [hommat.bar(), hommat.mood()], 4.5)
		"kalja", "viina":
			if id == "kalja":
				beers -= 1
				player.set_carrying(beers > 0)
			else:
				viina_pullot -= 1
			Sfx.play("glass", -6.0, 0.9)
			var t: String = hommat.beer_help()
			if t != "":
				mokki.say(Hommat.BEER_LINES.pick_random(), 4.5)
				_show_message("Santtu joi %s ja hoiti homman: %s. Puolittain, mutta ei kehtaa valittaa." % [
					"kaljan" if id == "kalja" else "huikan", Hommat.TASKS[t].nimi], 4.0)
				_hommat_finished(t, true)


## Santun juttu: ilmoituksen faktat, arvostelut päivitettyinä.
func _santtu_chat_line() -> String:
	if mokki.puuhat.working():
		return mokki.puuhat.chat_line()
	var line: String = Mokki.SANTTU_LINES.pick_random()
	if hommat.reviews.size() > 0 and "arvostelu" in line:
		line = "Arvosteluja on jo %d, keskiarvo %s tähteä. Kyllä tää vielä nousee." % [hommat.reviews.size(),
			("%.1f" % hommat.review_avg()).replace(".", ",")]
	return line


## Puupaikan sahaus ja halkominen mökillä (kodan minipelit, Santtu katsojana).
func _start_mokki_saw() -> void:
	var sg := SawGame.new()
	sg.lines = Hommat.SAW_LINES
	sg.watcher_spots = {"santtu": Vector3(1.6, 0, -0.55)}
	sg.sawn.connect(func() -> void:
		_mokki_polkyt += 1
		tilat.first("sahaus")
		_wood_work())
	var l := Mokki.PUU_SAW_LOCAL
	_start_kota_game(sg, Vector3(l.x, Mokki.h(l.x, l.z), l.z), 0.0, func() -> String:
		return "Sahattu %d pölkkyä! Pölkkyjä %d. Halko ne pilkkomispölkyllä." % [sg.polkyt_made, _mokki_polkyt] \
			if sg.polkyt_made > 0 else "", mokki)


func _start_mokki_chop() -> void:
	var cg := ChopGame.new()
	cg.lines = Hommat.CHOP_LINES
	cg.watcher_spots = {"santtu": Vector3(1.75, 0, 2.2)}
	cg.polkyt = _mokki_polkyt
	cg.split.connect(func(n: int) -> void:
		_mokki_polkyt -= 1
		_mokki_halot += n
		tilat.first("halkominen")
		_wood_work()
		if _mokki_halot >= 8:
			_hommat_complete("puut"))
	var l := Mokki.PUU_CHOP_LOCAL
	_start_kota_game(cg, Vector3(l.x, Mokki.h(l.x, l.z), l.z), 0.0, func() -> String:
		return "Halottu %d halkoa! Saunapuita tänään %d." % [cg.halot_made, _mokki_halot] if cg.halot_made > 0 else "", mokki)


## Laiturin korjaus (laituri_game.gd) polvillaan laiturilla.
func _start_laituri() -> void:
	var g := LaituriGame.new()
	if _dock_state.is_empty():
		_dock_state = LaituriGame.new_state()
	g.state = _dock_state
	g.patch = mokki.dock_patch
	g.patch_z = _dock_fix_z()
	g.drunk = _hand_shake()
	g.thumb.connect(func() -> void:
		tilat.add("kipu", -0.15)
		tilat.add("stressi", -0.05))
	g.fixed_plank.connect(func() -> void:
		if LaituriGame.is_done(_dock_state):
			_hommat_complete("laituri"))
	var pos: Vector3 = mokki.dock_body.position + Vector3(0, LaituriGame.DECK_Y, _dock_fix_z())
	_start_kota_game(g, pos, 0.0, func() -> String:
		if g.thumbs > 0 and not LaituriGame.is_done(_dock_state):
			return "Peukalo sykkii (%d osumaa). Laiturissa on vielä lahoja lautoja." % g.thumbs
		return "", mokki)


## Rännien putsaus tikkailta (ranni_game.gd). Putoaminen sattuu.
func _start_ranni() -> void:
	var g := RanniGame.new()
	var hy := Mokki.h(Mokki.LADDER_LOCAL.x, Mokki.LADDER_LOCAL.z)
	g.base_off = mokki.cottage_base - hy
	g.gutter_up = Mokki.GUTTER_UP
	if _ranni_state.is_empty():
		_ranni_state = RanniGame.new_state(g.base_off, g.gutter_up)
	g.state = _ranni_state
	g.drunk = _hand_shake()
	_start_kota_game(g, Vector3(0, hy, Mokki.LADDER_LOCAL.z), 0.0, func() -> String:
		if g.fell_off:
			tilat.add("kipu", -0.3)
			tilat.add("stressi", -0.15)
			tilat.add("moraali", -0.1)
			walker_out.stun(Vector3(0, 0, -1).rotated(Vector3.UP, mokki.global_rotation.y))
			mokki.say("Ei se mitään, nurmikko on pehmeä. Kiipeä uudestaan, ku pää selkenee.", 4.0)
			return "Tikkaat kaatui! Selkä maassa ja ylpeys kolhuilla."
		if RanniGame.is_done(_ranni_state):
			_hommat_complete("ranni")
		return "", mokki)


## Ampiaispesän hävitys (ampiais_game.gd). Kolmas pisto: paniikki ja juoksu järveen.
func _start_ampiaiset() -> void:
	var g := AmpiaisGame.new()
	var l := Mokki.WASP_STAND_LOCAL
	var pos := Vector3(l.x, mokki.sauna_base, l.z)  # terassin laudoilla saunan tasossa
	g.nest_local = mokki.to_local(mokki.wasp_nest.global_position) - pos
	g.drunk = _hand_shake()
	_start_kota_game(g, pos, 0.0, func() -> String:
		tilat.add("kipu", -0.08 * g.stings)
		match g.result:
			"ok":
				_hommat_complete("ampiaiset")
			"pako":
				walker_out.global_position = mokki.gpos(Mokki.pump_local() + Vector3(0.9, 0.3, 0.8))
				walker_out.velocity = Vector3.ZERO
				tilat.add("vireys", 0.2)
				tilat.add("stressi", -0.15)
				Sfx.play("water", 0.0, 0.8)
				mokki.say("Hah! Ampiaiset voitti tällä kertaa. Uusi purkki on penkillä.", 4.0)
				return "Juoksit paniikissa suoraan Likaseen! Pistoja %d. Kylmä vesi auttoi, mutta pesä jäi." % g.stings
			"tyhja":
				return "Myrkky loppui kesken! Uusi purkki on saunan penkillä (E pesän edessä)."
		return "", mokki)


## Tiskaus tuvassa (tiski_game.gd), sisä-Santtu kommentoi.
func _start_tiskit() -> void:
	if mokki_int.dishes <= 0:
		return
	mokki_int.busy = true
	mokki_int.walker.controls_enabled = false
	_hud.visible = false
	var g := TiskiGame.new()
	g.dishes_left = mokki_int.dishes
	g.drunk = _hand_shake()
	g.comment.connect(func(t: String) -> void: mokki_int.say(t))
	g.finished.connect(func(washed: int, broken: int) -> void:
		mokki_int.busy = false
		mokki_int.walker.controls_enabled = true
		_hud.visible = true
		mokki_int.set_dishes(g.dishes_left)
		if broken > 0:
			hommat.add_hermo(4.0 * broken)
			tilat.add("moraali", -0.05 * broken)
		tilat.first("tiskit", 0.1)
		if g.dishes_left > 0:
			_show_message("Tiskit jäi kesken (%d jäljellä)." % g.dishes_left, 2.5)
		elif hommat.pending("kahvi"):
			if hommat.progress.get("kahvi_vietu", false):
				_hommat_complete("kahvi")
			else:
				_show_message("Tiskit tehty%s! Santtu odottaa vielä kahveja pihalla." % (
					" (%d meni rikki)" % broken if broken > 0 else ""), 3.0))
	add_child(g)


# --- Pankkiautomaatti ------------------------------------------------------------------------------------------

## K-Marketin takaseinän automaatti (luodaan kerran, world.gd:n päälle).
func _build_atm() -> void:
	var p := M.w(M.SHOP_BUILDING) + Vector3(4.0, 0, -9.0)
	p.y = Terrain.h(p.x, p.z)
	_atm_node = Atm.build(world, p, 0.0)


func _atm_logic() -> void:
	if _atm_node == null:
		_build_atm()
	if _hint.text != "" or player.is_stunned():
		return
	var front := _atm_node.global_position + Vector3(0, 0, -1.0)
	var p := player.global_position
	if Vector2(p.x - front.x, p.z - front.z).length() < 1.6:
		_hint.text = "[E] Nosta rahaa pankkiautomaatista (20 € kerran päivässä)"
		if Input.is_action_just_pressed("interact"):
			_atm_use()


func _atm_use() -> void:
	if atm_day == day:
		_show_message("Päivän nostoraja on käytetty. Huomenna taas 20 €.", 2.5)
		Sfx.play("alert", -8.0)
		return
	atm_day = day
	money += Atm.DAILY
	Sfx.play("coin", -2.0)
	_show_message("Nostit %s €. Rahaa nyt %s €." % [_eur(Atm.DAILY), _eur(money)], 2.5)
	_save_game()


# --- Mopomatka Vaalaan -----------------------------------------------------------------------------------------

## Mopolla Paapelista Vaalan Siitariin: Vaalan tasku rakennetaan ensimmäisellä kerralla, HUD:sta näkyvät
## matkan aikana vain kompassi, viestit, vihje ja mopon mittari (nopeus, tie, todellinen matka).
func _start_mopo() -> void:
	_vaala_state = state
	_in_vaala = true
	walker_out.controls_enabled = false
	walker_out.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	if mopo_trip == null:
		mopo_trip = MopoTrip.new()
		mopo_trip.position = VAALA_POS
		add_child(mopo_trip)
		mopo_trip.arrived.connect(_on_mopo_arrived)
		mopo_trip.finished.connect(_on_mopo_finished)
		mopo_trip.killed.connect(_on_mopo_killed)
		mopo_trip.atm.connect(_atm_use)
		mopo_trip.shop.connect(_enter_vaala_shop)
		mopo_trip.lava.connect(_enter_lava)
		mopo_trip.crashed.connect(_on_mopo_crashed)
		_paper.mopo_trip = mopo_trip
	mokki.mopo_parked.visible = false
	walker_out.visible = false
	mopo_trip.start("siitari", tilat.value("humala"))
	_set_avatar(mopo_trip.mopo)
	_mopo_label.visible = true
	tilat.first("mopo", 0.3)
	_show_message("Mopo käynnistyi! Uutelanperäntie, Neittäväntie ja Vuolijoentie Vaalaan. Siitari on Vaalantiellä joen takana."
		+ (" Kännissä tanko vaeltaa: pidä mopo tiellä!" if tilat.value("humala") > 0.1 else ""), 4.5)


## Vaalan omat asiat (_outside_logicista): vihje, mopon mittari, kompassin kohde ja mopon selkään/pois.
func _vaala_logic() -> void:
	if not mopo_trip.active:
		return
	_hint.text = mopo_trip.hint
	_mopo_label.text = mopo_trip.status
	var tg: Vector3 = mopo_trip.target_global()
	_compass.has_cache = true
	_compass.cache = Vector2(tg.x, tg.z)
	var left: float = mopo_trip.real_left()
	_compass.cache_text = ("%s %s km" % ["Siitari" if mopo_trip.target == "siitari" else "Paapeli",
		("%.1f" % (left / 1000.0)).replace(".", ",")])
	_mopo_mount_logic()


var _mopo_dry := Vector3.ZERO  # jalan: viimeisin kuiva paikka


## F: moposta jalan ja takaisin selkään mopon vierestä, kuten pyörällä. Jalan kulkee sama kävelijä kuin kylällä
## ja mökillä; ovet (Siitari, Tervaportti, lava) ja pankkiautomaatti toimivat myös jalan (mopo_trip.gd).
func _mopo_mount_logic() -> void:
	var mp: CharacterBody3D = mopo_trip.mopo
	var e: bool = Input.is_action_just_pressed("mount")
	if mopo_trip.on_foot == null:
		if not e or mp.fallen or not mp.controls_enabled:
			return
		if absf(mp.speed) > 3.0:
			_show_message("Hidasta ensin!", 1.2)
			return
		walker_out.global_position = mp.global_position + mp.global_transform.basis.x * 1.1 + Vector3(0, 0.3, 0)
		walker_out.global_rotation.y = mp.global_rotation.y
		walker_out.velocity = Vector3.ZERO
		walker_out.speed = 0.0
		walker_out.visible = true
		walker_out.process_mode = Node.PROCESS_MODE_INHERIT
		walker_out.controls_enabled = true
		walker_out.set_carrying(beers > 0)
		mopo_trip.set_on_foot(walker_out)
		_mopo_follow(walker_out)
		_mopo_dry = walker_out.global_position
		return
	# Järveen tai jokeen ei kahlata: rantaviivalta takaisin kuivalle.
	var vl: Node3D = mopo_trip.vaala
	var lp: Vector3 = mopo_trip.to_local(walker_out.global_position)
	if vl.h(lp.x, lp.z) < vl.water_level - 0.3:
		walker_out.global_position = _mopo_dry
		walker_out.velocity = Vector3.ZERO
		if _hint.text == "":
			_hint.text = "Vesi on kylmää. Ei uimaan."
	else:
		_mopo_dry = walker_out.global_position
	var d := walker_out.global_position.distance_to(mp.global_position)
	if d < 2.6:
		if _hint.text == "":
			_hint.text = "[F] Nouse mopon selkään"
		if e:
			_mopo_remount()
	elif e:
		_show_message("Mopo on %s päässä." % _dist_text(walker_out.global_position, mp.global_position), 1.5)


func _mopo_remount() -> void:
	walker_out.controls_enabled = false
	walker_out.speed = 0.0
	walker_out.visible = false
	mopo_trip.set_on_foot(null)
	_mopo_follow(mopo_trip.mopo)


## Pelaajaksi mopo tai jalan kulkija (kamera, kompassi ja kaikki player-logiikka seuraavat).
func _mopo_follow(a: CharacterBody3D) -> void:
	_set_avatar(a)


## Sisältä (kauppa, lava) takaisin matkalle: jalan tultiin, jalan jatketaan; muuten mopon selkään.
func _mopo_resume() -> void:
	mopo_trip.resume()
	if mopo_trip.on_foot != null:
		walker_out.visible = true
		walker_out.controls_enabled = true
		_mopo_follow(walker_out)


## Sisälle (kauppa, lava): jalan kulkija odottaa ovella näkymättömänä.
func _mopo_foot_inside() -> void:
	if mopo_trip.on_foot != null:
		walker_out.controls_enabled = false
		walker_out.speed = 0.0
		walker_out.visible = false


## Siitarin ovella: mopo parkkiin ja sisälle baariin (siitari_interior.gd). Ulko-ovelta takaisin mopolle.
func _on_mopo_arrived() -> void:
	if mopo_trip.on_foot != null:
		_mopo_remount()  # mopo parkissa Siitarin pihassa, kotimatka alkaa sen selästä
	_hint.text = ""
	_show_message("Hotelli-Ravintola Siitari, Vaalantie 12. Baaritiski, karaoke ja tanssilattia!", 3.0)
	Sfx.play("door", -3.0)
	tilat.first("siitari", 0.4)
	state = "in_siitari"
	_own_drink_warned = false
	_mopo_label.visible = false
	_compass.visible = false
	siitari_int.enter()


func _on_siitari_exited() -> void:
	_on_siitari("lahde")


## Siitarin sisätoiminnot: tiski (valikko), karaoke, Sinikka (valikko) ja pajatso.
func _on_siitari_acted(kind: String) -> void:
	match kind:
		"tiski":
			siitari_int.bartender_say("Mitäs laitetaan?")
			_open_siitari_menu()
		"karaoke":
			if money < KARAOKE_PRICE:
				_show_message("Karaoke maksaa %s €. Rahat ei riitä." % _eur(KARAOKE_PRICE), 2.5)
				return
			money -= KARAOKE_PRICE
			_start_karaoke()
		"sinikka":
			siitari_int.sinikka_say(SINIKKA_BAR_LINES.pick_random())
			_menu_mode = "siitari"
			siitari_int.walker.controls_enabled = false
			_item_menu.open([["sinikka_juttu", "Jutskaa Sinikan kanssa"], ["sinikka_tanssi", "Tanssi Sinikan kanssa"],
				["sinikka_drinkki", "Tarjoa Sinikalle lonkero – %s €" % _eur(SIITARI_MENU.lonkero[1])],
				["takaisin", "Takaisin"]], "Sinikka baaritiskillä")
		"pajatso":
			if money < PAJATSO_PRICE:
				_show_message("Pajatso vie euron. Rahat ei riitä.", 2.0)
				return
			money -= PAJATSO_PRICE
			Sfx.play("coin", -4.0)
			var roll := randf()
			if roll < 0.08:
				money += 10.0
				Sfx.play("win", -4.0)
				tilat.add("moraali", 0.15)
				_show_message("PAJATSO! Kolikot kilisee: +10 €!", 3.0)
			elif roll < 0.3:
				money += 2.0
				Sfx.play("win_small", -6.0)
				_show_message("Pajatso antoi 2 €.", 2.0)
			else:
				_show_message("Kuula kolisi ohi. Euro meni.", 2.0)
		"tanssi_loppu":
			_show_message("Tanssi loppui. Sinikka: \"Sää viet hyvin. Toiste uudestaan?\"", 3.0)


func _open_siitari_menu() -> void:
	var items: Array = []
	for id in SIITARI_MENU:
		var m: Array = SIITARI_MENU[id]
		items.append([id, "%s – %s €" % [m[0], _eur(m[1])]])
	items.append(["takaisin", "Takaisin"])
	_menu_mode = "siitari"
	siitari_int.walker.controls_enabled = false
	_item_menu.open(items, "Siitarin baari · rahaa %s €" % _eur(money))


## Sinikan kanssa peuhaaminen kantautuu Päiville: puhelu hetken päästä ja aamulla vielä motkotusta.
func _sinikka_flirt() -> void:
	tilat.first("sinikka_siitari", 0.2)
	tilat.add("moraali", 0.1)
	tilat.add("stressi", 0.05)
	_sinikka_gossip = true
	if _paivi_call_t <= 0.0:
		_paivi_call_t = randf_range(7.0, 12.0)
		_paivi_call_kind = "sinikka"


func _paivi_calls() -> void:
	Sfx.play("alert", -2.0, 1.3)
	tilat.add("stressi", -0.2)
	tilat.add("moraali", -0.15)
	var lines: Array = Hommat.PAIVI_SANTTU_CALLS if _paivi_call_kind == "santtu" else PAIVI_SINIKKA_CALLS
	_paivi_call_kind = "sinikka"
	_show_message("📱 Päivi soittaa: " + lines.pick_random(), 5.0)


## Karaoke: lavalle, laulu (karaoke_game.gd), yleisön reaktio ja tilavaikutukset.
func _start_karaoke() -> void:
	siitari_int.to_stage()
	_hud.visible = false
	var game := KaraokeGame.new()
	game.drunk = _hand_shake()
	game.line.connect(siitari_int.set_screen)
	game.finished.connect(func(score: float) -> void:
		game.queue_free()
		_hud.visible = true
		siitari_int.from_stage(score >= 0.5)
		tilat.first("karaoke", 0.3)
		var pct := roundi(score * 100.0)
		if score >= 0.7:
			Sfx.play("win", -4.0)
			tilat.add("moraali", 0.25)
			tilat.add("stressi", 0.15)
			mielihyva = clampf(mielihyva + 10.0, 0.0, 100.0)
			_show_message("Karaoke %d %%: Siitari raikuu! Seurue taputtaa ja Sinikka huokaa." % pct, 3.5)
		elif score >= 0.4:
			Sfx.play("win_small", -6.0)
			tilat.add("moraali", 0.1)
			_show_message("Karaoke %d %%: ihan kelpo veto. Joku taputti." % pct, 3.0)
		else:
			Sfx.play("lose", -6.0)
			tilat.add("moraali", -0.1)
			_show_message("Karaoke %d %%: nuotin vierestä%s. Korttiporukka piti korviaan." % [pct,
				" (kännissä ääni huojuu)" if tilat.value("humala") > 0.2 else ""], 3.5))
	add_child(game)


func _on_siitari(id: String) -> void:
	if state == "in_siitari" and id != "lahde":
		siitari_int.walker.controls_enabled = true
		siitari_int.block_interact()
		match id:
			"takaisin":
				return
			"sinikka_juttu":
				siitari_int.sinikka_say(SINIKKA_BAR_LINES.pick_random())
				return
			"sinikka_tanssi":
				siitari_int.dance_with_sinikka(7.0)
				_show_message("Tanssit Sinikan kanssa. Tanssilattia on pieni ja Vaala vielä pienempi...", 3.5)
				_sinikka_flirt()
				return
			"sinikka_drinkki":
				var price: float = SIITARI_MENU.lonkero[1]
				if money < price:
					_show_message("Rahat ei riitä Sinikan lonkeroon (%s €)." % _eur(money), 2.0)
					return
				money -= price
				Sfx.play("glass", -6.0, 0.9)
				siitari_int.sinikka_say("Sää oot kyllä herrasmies. Kippis, naapuri!")
				_show_message("Tarjosit Sinikalle lonkeron. Baarimikko vilkaisi puhelintaan...", 3.0)
				_sinikka_flirt()
				return
	if id == "lahde":
		_menu_mode = "give"
		if state == "in_siitari":
			siitari_int.leave()
			Sfx.play("door_close", -3.0)
			state = _vaala_state
			_mopo_label.visible = true
			_compass.visible = true
		var drunk: float = tilat.value("humala")
		if drunk > 0.1:
			# Omalla kylällä saa ajaa kännissä, mutta helppoa se ei ole: tanko vaeltaa ja ojaan on lyhyt matka.
			_show_message("Omalla kylällä saa ajaa kännissä! Tanko vaeltaa ja käsi laahaa: pidä mopo tiellä ja vauhti maltillisena.", 4.5)
			tilat.first("mopo_kannissa", 0.3)
		else:
			_show_message("Takaisin Paapeliin: Vaalantie, Vuolijoentie ja Neittäväntie.", 3.0)
		mopo_trip.start("paapeli", drunk)
		return
	var m: Array = SIITARI_MENU[id]
	if money < m[1]:
		_show_message("Rahat ei riitä (%s €)." % _eur(money), 2.0)
	else:
		money -= m[1]
		tilat.add("humala", m[2])
		tilat.add("stressi", m[3])
		tilat.add("moraali", m[4])
		if m[2] > 0.0:
			Sfx.play("glass", -6.0, 0.9)
		else:
			Sfx.play("pickup", -8.0, 0.8)
		tilat.first("siitari_" + id, 0.1)
		_show_message("%s. %s" % [m[0], SIITARI_LINES.pick_random()], 3.0)


## Auto ajoi mopon päälle: WASTED Vaalan tiellä, Päivin motkotus ja uusi päivä kotoa Saloisista.
func _on_mopo_killed() -> void:
	var walking: bool = mopo_trip.on_foot != null
	var at: Vector3 = walker_out.global_position if walking else mopo_trip.mopo.global_position
	var road_name: String = mopo_trip.status.get_slice("\n", 1).get_slice(" · ", 0)
	if walking:
		walker_out.controls_enabled = false
		mopo_trip.on_foot = null
	_mopo_restore_hud()
	state = _vaala_state
	_lose("Jäit auton alle %s (%s)." % ["jalan" if walking else "mopolla", road_name], "car", at)
	mopo_trip.stop()


## Kännissä kumoon: kipua ja nolous, mopo nostetaan tielle ja matka jatkuu.
func _on_mopo_crashed(reason: String) -> void:
	tilat.add("kipu", -0.15)
	tilat.add("moraali", -0.05)
	_show_message(("Mopo ojassa! Kännissä ajo ei ole helppoa." if reason == "ditch"
		else "Pää edellä päin! Kännissä ajo on vaarallista.") + " Mopo pystyyn ja matka jatkuu.", 3.0)


func _mopo_restore_hud() -> void:
	_in_vaala = false
	mokki.mopo_parked.visible = true
	_mopo_label.visible = false
	_compass.cache_text = ""
	_compass.has_cache = false


func _on_mopo_finished(_result: String) -> void:
	_show_message("Mopo parkissa Paapelin pihassa.", 2.5)
	_mopo_end()


func _mopo_end() -> void:
	mopo_trip.stop()
	_mopo_restore_hud()
	state = _vaala_state
	walker_out.global_position = mokki.gpos(Mokki.MOPO_LOCAL + Vector3(1.2, 0.4, 0.3))
	walker_out.velocity = Vector3.ZERO
	walker_out.visible = true  # jalan Vaalassa käynyt kävelijä piilotettiin selkään noustessa
	walker_out.controls_enabled = true
	_set_avatar(walker_out)
	_save_game()


## Löylyssä käynti: lyhyt tunnelmapala terassilla, höyryä ja tilaisuuden tullen hörppy kaljaa.
func _sauna_cutscene() -> void:
	_mokki_prev = state
	state = "cutscene"
	player.controls_enabled = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_hud.visible = false
	var had_beer := beers > 0
	if had_beer:
		beers -= 1
	cutscene.sauna_relax(mokki.to_global(Mokki.SAUNA_LOCAL), had_beer, func() -> void:
		walker_out.stamina = 100.0
		walker_out.exhausted = false
		tilat.first("savusauna", 0.4)
		if _once_today("sauna"):
			tilat.add("stressi", 0.3)
			tilat.add("vasymys", 0.3)
			tilat.add("kipu", 0.2)
			tilat.add("vireys", 0.2)
		if had_beer:
			tilat.add("moraali", 0.1)
		state = _mokki_prev
		player.controls_enabled = true
		player.activate_camera()
		_hazards.process_mode = Node.PROCESS_MODE_INHERIT
		_hud.visible = true
		_show_message("Löyly virkistää! Kunto palautui.", 2.5))


## Mökin sisälle: oma tasku ja kävelijä kuten kaupassa; vaarat pysähtyvät sisällä oloajaksi.
func _enter_mokki(door := "ovi") -> void:
	_mokki_prev = state
	state = "in_mokki"
	player.controls_enabled = false
	player.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	tilat.first("mokki_sisalla", 0.2)
	mokki_int.enter(door)
	Sfx.play("door", -3.0)


func _on_mokki_exited() -> void:
	if hommat.progress.get("kahvi_keitetty", false) and not hommat.progress.get("kahvi_vietu", false) and _carry == "":
		_set_carry("kahvi")
	mokki_int.leave()
	Sfx.play("door_close", -3.0)
	state = _mokki_prev
	walker_out.global_position = mokki.porch2_pos(0.9) if mokki_int.exit_door == "ovi2" else mokki.porch_pos(0.9)
	walker_out.rotation.y = mokki.rotation.y + PI  # selkä ovelle, katse pihalle ja järvelle (+Z)
	walker_out.velocity = Vector3.ZERO
	walker_out.controls_enabled = true
	walker_out.activate_camera()
	_hazards.process_mode = Node.PROCESS_MODE_INHERIT


## Kerrossängyssä nukkuminen: päivä päättyy ja uusi alkaa mökin kuistilta (mökki on turvapaikka).
func _on_mokki_slept() -> void:
	if hommat.active and not hommat.all_done():
		hommat.add_hermo(Hommat.HERMO_SLEEP)
		if hommat.furious():
			mokki_int.say("Nukkumaan ja hommat kesken? Ei käy! Pekka tulee hakemaan.")
			_hommat_evict()
			return
		mokki_int.say("Hommat jäi kesken... No, nuku nyt. Huomenna parempi.")
	if hommat.active:
		var st: int = hommat.stars_now()
		hommat.add_review(day, st)
		hommat.carry = hommat.hermo * 0.5 if st < 5 else 0.0
	hommat.nights += 1
	mokki_int.leave()
	tilat.add("vasymys", 0.3)  # hyvät unet näkyvät vielä päivän tuloksessa
	_slept_mokki = true
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	_new_day(mokki.porch_pos(0.9) - Vector3(0, 0.3, 0), false, "Nukuit yön Santun mökillä kerrossängyssä.\n")


## Mökin sisätoiminnot: tilavaikutukset (kerran päivässä) ja viestit.
func _on_mokki_acted(kind: String) -> void:
	match kind:
		"kahvi":
			tilat.first("suodatinkahvi")
			if _once_today("kahvi"):
				tilat.add("vireys", 0.2)
				tilat.add("stressi", 0.1)
			if hommat.pending("kahvi") and not hommat.progress.get("kahvi_vietu", false):
				hommat.progress["kahvi_keitetty"] = true
				mokki_int.say("Musta, ei sokeria. Vie se mulle pihalle, mää istun kannolla.")
				_show_message("Suodatinkahvia! Kaadoit Santulle kupin mustaa: vie se pihalle (kävele, älä juokse).", 3.5)
			else:
				_show_message("Suodatinkahvia! Vireys nousee.", 2.5)
		"tiskit":
			_start_tiskit()
		"jaakaappi":
			if _once_today("jaakaappi"):
				food["piirakka"] = food.get("piirakka", 0) + 1
				_show_message("Santun jääkaapissa oli lihapiirakka. Otit sen evääksi (T syö).", 3.0)
			else:
				_show_message("Jääkaappi on tyhjä. Santtu: \"Kaupasta saa lisää!\"", 2.5)
		"takka":
			tilat.first("takka")
			if _once_today("takka"):
				tilat.add("stressi", 0.1)
			_show_message("Takka syttyi. Tupa lämpenee.", 2.5)
		"tv":
			if _once_today("tv"):
				tilat.add("stressi", 0.05)
				tilat.add("kokemus", -0.02)
			_show_message("\"%s\"" % TV_SHOWS.pick_random(), 3.0)
		"suihku":
			if _once_today("suihku"):
				tilat.add("vireys", 0.1)
				tilat.add("kipu", 0.05)
			Sfx.play("water", -6.0, 1.1, 3.0)  # suihku
			_show_message("Suihku virkistää.", 2.0)
		"wc":
			_open_wc_menu("mokki")
		"sauna":
			tilat.first("sisasauna", 0.2)
			walker_out.stamina = 100.0
			walker_out.exhausted = false
			if _once_today("sisasauna"):
				tilat.add("stressi", 0.2)
				tilat.add("vasymys", 0.2)
				tilat.add("kipu", 0.1)
			Sfx.play("water", -6.0, 0.8, 2.5)  # löyly
			_show_message("Sisäsaunan löylyt! Kunto palautui.", 2.5)
		"pa":
			if mokki_int.pa_on:
				_pa_off()
			else:
				_start_pa()


## PA-laitteiden kytkentä (pa_game.gd) tuvassa. Tunnusmusiikki soi kaiuttimista jo säätäessä, ja onnistuneen
## kytkennän jälkeen se jää soimaan tuvassa (ja vaimeana pihalle), kunnes PA sammutetaan.
func _start_pa() -> void:
	if hommat.pending("pa"):
		mokki_int.say(hommat.line("pa", "tulee"))
	mokki_int.busy = true
	mokki_int.walker.controls_enabled = false
	_hud.visible = false
	var game := PaGame.new()
	game.level.connect(func(v: float) -> void:
		mokki_int.set_pa_level(v)
		mokki.set_pa_level(v))
	game.finished.connect(func(won: bool) -> void:
		var v: float = game.out_level
		game.queue_free()
		mokki_int.busy = false
		mokki_int.walker.controls_enabled = true
		_hud.visible = true
		mokki_int.set_pa(won, v)
		mokki.set_pa_level(v if won else 0.0)
		if not won:
			if game.strikes > 0:
				_show_message("PA jäi kytkemättä. Santtu pakkasi kamat. Yritä uudestaan rauhassa.", 3.0)
			return
		tilat.first("pa", 0.3)
		_hommat_complete("pa")
		if _once_today("pa"):
			tilat.add("moraali", 0.2)
			tilat.add("stressi", 0.15)
		mielihyva = clampf(mielihyva + 10.0, 0.0, 100.0)
		mokki_int.say("Nyt soi! Tää on se Normipäivän tunnari!")
		_show_message("PA soi! Tunnari pauhaa tuvassa, kunnes PA sammutetaan (E laitteilla).", 3.5))
	add_child(game)


func _pa_off() -> void:
	mokki_int.set_pa(false)
	mokki.set_pa_level(0.0)
	Sfx.play("rattle", -8.0, 1.6)
	mokki_int.say("No niin, hiljaista. Pääte ensin pois, sitten mikseri.")
	_show_message("PA sammutettu.", 2.0)


## Kalastus soutuveneellä (fish_game.gd): soutu Likasella, heitto, tärppi ja väsytys. Saalis savustimeen.
func _start_fishing() -> void:
	_minigame_prev = state
	state = "minigame"
	player.controls_enabled = false
	player.speed = 0.0
	player.visible = false
	mokki.boat_parked.visible = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_hud.visible = false
	var game := FishGame.new()
	game.drunk = _hand_shake()
	game.finished.connect(func(got: Array) -> void:
		state = _minigame_prev
		player.visible = true
		player.activate_camera()
		player.controls_enabled = true
		mokki.boat_parked.visible = true
		_hazards.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		_hud.visible = true
		_after_fishing(got))
	mokki.add_child(game)


func _after_fishing(got: Array) -> void:
	tilat.first("kalastus", 0.3)
	tilat.add("stressi", 0.15)  # vesillä rauhoittuu
	if got.is_empty():
		_show_message("Ei saalista tällä kertaa. Järvi oli kaunis silti.", 2.5)
		return
	var names: Array = []
	for f in got:
		saalis.append({"type": "kala", "nom": f.nom})
		names.append("%s %s kg" % [f.nom, ("%.1f" % f.kg).replace(".", ",")])
	tilat.add("moraali", minf(0.06 * got.size(), 0.25))
	_show_message("Saalis: %s. Vie kesäkeittiön savustimeen." % ", ".join(names), 3.5)


## Metsästyslava riistapolulla: E nousee lavalle, ja metsästys on FPS-minipeli (hunt_game.gd).
func _hunt_logic(e: bool) -> void:
	_hint.text = "[E] Nouse metsästyslavalle (haulikko, %d patruunaa)" % HuntGame.SHELLS
	if e:
		_start_hunt()


func _start_hunt() -> void:
	if hommat.pending("metsastys"):
		mokki.santtu_teleport(Mokki.HUNT_LOCAL + Vector3(1.6, 0, 1.2), Vector3(Mokki.HUNT_GLADE.x, 0, Mokki.HUNT_GLADE.y))
		_show_message("Santtu tuli mukaan lavan juurelle: \"%s\"" % hommat.line("metsastys", "tulee"), 3.0)
	_minigame_prev = state
	state = "minigame"
	player.controls_enabled = false
	player.speed = 0.0
	player.visible = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_hud.visible = false
	var game := HuntGame.new()
	game.finished.connect(func(bag: Array, moose: bool) -> void:
		state = _minigame_prev
		player.visible = true
		player.activate_camera()
		player.controls_enabled = true
		_hazards.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		_hud.visible = true
		_after_hunt(bag, moose))
	mokki.add_child(game)


func _after_hunt(bag: Array, moose: bool) -> void:
	tilat.first("metsastys", 0.3)
	mokki.santtu_go_home()
	if moose:
		tilat.add("moraali", -0.3)
		tilat.add("stressi", -0.3)
		mokki.say("Ammuit HIRVEN? Ei meillä oo lupaa! Nyt tulee riistanvalvoja...", 4.0)
		if hommat.active:
			hommat.add_hermo(30.0)
	elif not bag.is_empty():
		_hommat_complete("metsastys")
	var names: Array = []
	for k in bag:
		var nom: String = HuntGame.SPECIES[k].nom
		saalis.append({"type": "riista", "nom": nom})
		names.append(nom)
	if not bag.is_empty():
		tilat.add("moraali", minf(0.05 * bag.size(), 0.2))
		tilat.add("stressi", 0.1)
		_show_message("Saalis: %s. Vie kesäkeittiön savustimeen." % ", ".join(names), 3.5)
	elif not moose:
		_show_message("Ei saalista tällä kertaa. Metsä oli hiljainen.", 2.5)


## Tikanheitto mökin pihalla (darts_game.gd): 3 x 3 tikkaa, verrataan Santun tulokseen. Humala heiluttaa kättä.
func _start_darts() -> void:
	_minigame_prev = state
	state = "minigame"
	player.controls_enabled = false
	player.speed = 0.0
	player.visible = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_hud.visible = false
	var game := DartsGame.new()
	game.board_center = Mokki.dart_board_center()
	game.drunk = _hand_shake()
	game.finished.connect(func(total: int, santtu: int) -> void:
		state = _minigame_prev
		player.visible = true
		player.activate_camera()
		player.controls_enabled = true
		_hazards.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		_hud.visible = true
		_after_darts(total, santtu))
	mokki.add_child(game)


func _after_darts(total: int, santtu: int) -> void:
	if total < 0:
		return
	tilat.first("tikka")
	var record := total > tikka_ennatys
	if record:
		tikka_ennatys = total
	if total > santtu:
		tilat.add("moraali", 0.15)
		tilat.add("keskittyminen", 0.1)
		mokki.say("No voi perkele, voitit mut tikassa!", 3.0)
	else:
		mokki.say("Heh, tikassa mää oon ollu aina parempi.", 3.0)
	_show_message("Tikkaa: %d pistettä (Santtu %d)%s" % [total, santtu, ", uusi ennätys!" if record else ""], 3.0)
	_save_game()


## Pihapingis Santtua vastaan (pingis_game.gd): Street Fighter -näyttämö kaukana kartan ulkopuolella.
func _start_pingis() -> void:
	_mokki_prev = state
	state = "cutscene"
	player.controls_enabled = false
	player.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_hud.visible = false
	Sfx.play("pickup", -6.0, 1.3)
	var game := PingisGame.new()
	game.position = PINGIS_POS
	game.finished.connect(func(won: bool, me: int, him: int) -> void:
		game.queue_free()
		state = _mokki_prev
		player.activate_camera()
		player.controls_enabled = true
		_hazards.process_mode = Node.PROCESS_MODE_INHERIT
		_hud.visible = true
		tilat.first("pingis", 0.3)
		tilat.add("stamina", -0.1)
		tilat.add("nalka", -0.05)
		if _once_today("pingis"):
			if won:
				tilat.add("moraali", 0.2)
				tilat.add("keskittyminen", 0.15)
				tilat.add("stressi", 0.1)
			else:
				tilat.add("stressi", 0.05)
				tilat.add("moraali", -0.05)
		mokki.say("Hyvä peli! Kahvit on keittiössä." if won else "Heh, pingismestari pitää pintansa!")
		_show_message("%s pihapingiksen eräin %d–%d." % ["Voitit" if won else "Hävisit", me, him], 3.0))
	add_child(game)


## Offset-savustin: raaka saalis sisään, halkoja tulipesään ja lämpö kohdalleen, lopuksi savustetut
## eväiksi (syödään T:llä). Makkaran paisto hoituu kerralla kuten ennenkin.
func _smoker_logic(e: bool) -> void:
	if smoker_load.is_empty():
		if has_sausage and not sausage_done:
			_hint.text = "[E] Paista makkara kesäkeittiön savustimessa"
			if e:
				sausage_done = true
				_eat(0.5)
				tilat.first("savustin", 0.3)
				tilat.add("stressi", 0.1)
				Sfx.play("whoosh", -6.0, 0.4)
				_show_message("Savustettu makkara! Nam.", 2.5)
		elif not saalis.is_empty():
			var n := mini(saalis.size(), SMOKER_LOAD_MAX)
			_hint.text = "[E] Laita savustimeen: %s" % ", ".join(saalis.slice(0, n).map(func(c): return c.nom))
			if e:
				smoker_load = saalis.slice(0, n)
				saalis = saalis.slice(n)
				smoker_progress = 0.0
				smoker_burnt = 0.0
				Sfx.play("door_close", -6.0, 1.3)
				_show_message("Saalis ritilällä. Lisää halkoja tulipesään (E) ja pidä lämpö 80–120 °C:ssa.", 3.5)
		else:
			_hint.text = "Kesäkeittiö ja offset-savustin. Makkaran saa K-Marketista, kalaa laiturilta ja riistaa metsästyslavalta."
		return
	if smoker_progress >= 1.0:
		_hint.text = "[E] Ota savustetut pois (%d kpl)" % smoker_load.size()
		if e:
			var key := ""
			for c in smoker_load:
				key = "karrella" if smoker_burnt >= 1.0 else ("savukala" if c.type == "kala" else "savuriista")
				food[key] = food.get(key, 0) + 1
			tilat.first("savustus", 0.3)
			tilat.add("stressi", 0.1)
			if smoker_burnt >= 1.0:
				if hommat.pending("savustus"):
					_santtu_line("Hiiltä! Tuota ei syö koirakaan. Uusiks.", true)
			else:
				_hommat_complete("savustus")
			Sfx.play("win_small", -6.0)
			_show_message("Karrelle meni, mutta syötävää se on. T syö." if smoker_burnt >= 1.0 else
				"Kullankeltaista savukalaa ja riistaa! Syö T:llä, kun nälkä yllättää.", 3.5)
			smoker_load.clear()
		return
	var status := "liian kylmä"
	if smoker_temp > 135.0:
		status = "LIIAN KUUMA!"
	elif smoker_temp > 120.0:
		status = "kuuma"
	elif smoker_temp >= 80.0:
		status = "sopiva"
	elif smoker_temp >= 60.0:
		status = "viileä"
	_hint.text = "Savustin %d °C (%s) · savustus %d %%%s · [E] lisää halko" % [roundi(smoker_temp), status,
		floori(smoker_progress * 100.0), " · karrelle %d %%" % floori(smoker_burnt * 100.0) if smoker_burnt > 0.0 else ""]
	if e:
		if smoker_fuel <= 0.01 and smoker_temp < 40.0:
			_show_message("Tuli syttyy tulipesään.", 1.5)
		smoker_fuel = minf(smoker_fuel + SMOKER_LOG, 1.2)
		Sfx.play("whoosh", -6.0, 0.5)


## Savustimen lämpö seuraa polttoainetta viiveellä (offset-tulipesä), ja savustus etenee lämmön mukaan.
func _smoker_tick(delta: float) -> void:
	if not mokki.built:
		return
	smoker_fuel = maxf(0.0, smoker_fuel - SMOKER_BURN * delta)
	var target := 18.0 + 200.0 * smoker_fuel
	smoker_temp += (target - smoker_temp) * (1.0 - exp(-delta / 4.0))
	mokki.set_smoker(smoker_temp)
	if smoker_load.is_empty() or smoker_progress >= 1.0:
		return
	var rate := 0.0
	if smoker_temp > 135.0:
		rate = 0.6
		smoker_burnt += delta * 0.15
	elif smoker_temp >= 80.0 and smoker_temp <= 120.0:
		rate = 1.0
	elif smoker_temp >= 60.0:
		rate = 0.5
	smoker_progress = minf(1.0, smoker_progress + rate * delta / SMOKER_TIME)
	if smoker_progress >= 1.0:
		Sfx.play("alert", -6.0, 1.2)
		mokki.say("Savustin on valmis! Tuoksuu jo tänne asti.")


## Kota: sahaa tukki pölkyiksi, pilko pölkyt haloiksi, sytytä tuli ja kuuntele tarinoita. Lintutornista lintuja.
func _kota_logic() -> void:
	var k: Node3D = world.kota
	if k == null:
		return
	var p := player.global_position
	var kc := k.global_position
	var dk := Vector2(p.x - kc.x, p.z - kc.z).length()
	if dk > 30.0:
		return
	_kota_chat_t -= get_process_delta_time()
	if _kota_chat_t <= 0.0 and dk < 9.0:
		_kota_chat_t = randf_range(9.0, 15.0)
		if k.fire_on:
			k.say(["raimo", "veikko"].pick_random(), ["Tule istumaan, kerrotaan tarina.", "Hyvin palaa.", "Kato ettei tipu makkara tuleen. Siitä on kyltti."].pick_random())
		else:
			k.say(["raimo", "veikko"].pick_random(), ["Hae puita, niin kerrotaan tarinoita.", "Kylmä kota ilman tulta.",
				"Saha on pukilla ja kirves pölkyssä.", "Kylttiä pitää lukea."].pick_random())
	if _hint.text != "":
		return
	if player == bike:
		if dk < 12.0:
			_hint.text = "Nouse pyörän selästä (F): kodalla touhutaan jalan."
		return
	if player.is_stunned():
		return
	var e := Input.is_action_just_pressed("interact")
	var near := func(local: Vector3, r: float) -> bool:
		var g: Vector3 = k.to_global(local)
		return Vector2(p.x - g.x, p.z - g.z).length() < r
	# Lintutorni: tasanteella.
	var top: Vector3 = k.to_global(Kota.TOWER_LOCAL)
	if Vector2(p.x - top.x, p.z - top.z).length() < 2.4 and p.y > Terrain.h(top.x, top.z) + Kota.TOWER_TOP_Y - 1.0:
		_hint.text = "[E] Katsele lintuja Haapajärven tekojärvellä"
		if e:
			Sfx.play("crow", -8.0, randf_range(1.1, 1.4))
			tilat.first("lintutorni")
			if _once_today("linnut"):
				tilat.add("vireys", 0.1)
				tilat.add("stressi", 0.1)
			_show_message("\"%s\"" % Kota.BIRD_LINES.pick_random(), 3.5)
		return
	if near.call(Kota.SAW_LOCAL, 1.7):
		_hint.text = "[E] Tartu pokasahaan ja sahaa tukista pölkkyjä"
		if e:
			_start_saw()
		return
	if near.call(Kota.CHOP_LOCAL, 1.7):
		if kota_polkyt <= 0:
			_hint.text = "Pilkkomispölkky. Sahaa ensin tukki pölkyiksi sahapukilla."
			return
		_hint.text = "[E] Tartu kirveeseen ja halko pölkyt (%d pölkkyä)" % kota_polkyt
		if e:
			_start_chop()
		return
	if dk < 2.7:
		if not k.fire_on:
			if kota_halot >= FIRE_HALOT:
				_hint.text = "[E] Sytytä tuli kotaan (%d halkoa)" % FIRE_HALOT
				if e:
					kota_halot -= FIRE_HALOT
					k.set_fire(true)
					tilat.add("stressi", 0.1)
					tilat.first("kodan_tuli")
					Sfx.play("whoosh", 0.0, 0.5)
					k.say("raimo", "No nyt! Tuli palaa. Istuhan alas.")
			else:
				_hint.text = "Kodan tulisija. Tarvitset %d halkoa (sinulla %d). Puut sahataan ja pilkotaan halkovajan luona." % [FIRE_HALOT, kota_halot]
			return
		if kota_halot > 0 and k.fire_time < 90.0:
			_hint.text = "[E] Lisää halko tuleen (tuli hiipuu)"
			if e:
				kota_halot -= 1
				k.fire_time = minf(k.fire_time + 70.0, 420.0)
				Sfx.play("whoosh", -6.0, 0.5)
			return
		_hint.text = "[E] Kuuntele tarina (kuultu %d/%d)" % [tarinat_kuultu.size(), Kota.STORIES.size()]
		if e:
			_tell_story()


## Sahaus FPS-minipelinä (saw_game.gd): jokainen katkaistu pölkky kasvattaa pölkkyvarastoa.
func _start_saw() -> void:
	var sg := SawGame.new()
	sg.sawn.connect(func() -> void:
		kota_polkyt += 1
		tilat.first("sahaus")
		_wood_work())
	_start_kota_game(sg, Kota.SAW_LOCAL, 0.3, func() -> String:
		return "Sahattu %d pölkkyä! Pölkkyjä %d. Halko ne pilkkomispölkyllä kirveellä." % [sg.polkyt_made, kota_polkyt] \
			if sg.polkyt_made > 0 else "")


## Puiden teko (pölkky sahattu tai halottu): voimat kuluvat, mutta mieli rauhoittuu.
func _wood_work() -> void:
	tilat.add("stamina", -0.05)
	tilat.add("vasymys", -0.03)
	tilat.add("stressi", 0.05)


## Halonhakkuu FPS-minipelinä (chop_game.gd).
func _start_chop() -> void:
	var cg := ChopGame.new()
	cg.polkyt = kota_polkyt
	cg.split.connect(func(n: int) -> void:
		kota_polkyt -= 1
		tilat.first("halkominen")
		_wood_work()
		kota_halot += n)
	_start_kota_game(cg, Kota.CHOP_LOCAL, 0.0, func() -> String:
		return "Halottu %d halkoa! Halkoja %d. Vie ne kodan tulisijaan." % [cg.halot_made, kota_halot] \
			if cg.halot_made > 0 else "")


## Kodan FPS-minipeli (kota_minigame.gd) paikallisessa kohdassa local ja kierrossa rot_y. Pelaaja seisoo
## piilossa minipelin silmien alla; message kertoo lopuksi saaliin.
func _start_kota_game(game: Node3D, local: Vector3, rot_y: float, message: Callable, host: Node3D = null) -> void:
	var k: Node3D = host if host != null else world.kota
	if k == mokki:
		mokki.santtu_stop()
	_minigame_prev = state
	state = "minigame"
	player.controls_enabled = false
	player.speed = 0.0
	game.kota = k
	game.position = local
	game.rotation.y = rot_y
	walker_out.global_position = k.to_global(game.transform * (game.eye * Vector3(1, 0, 1))) + Vector3(0, 0.3, 0)
	walker_out.rotation.y = k.global_rotation.y + rot_y + game.yaw_center + PI
	player.visible = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_hud.visible = false
	game.finished.connect(func() -> void:
		state = _minigame_prev
		player.visible = true
		player.activate_camera()
		player.controls_enabled = true
		_hazards.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		_hud.visible = true
		if k == mokki:
			mokki.santtu_go_home()
		var msg: String = message.call()
		if msg != "":
			_show_message(msg, 3.0))
	k.add_child(game)


## Tarinatuokio kodassa: kamera kertojiin, repliikit puhekuplina ja tekstityksenä. E ohittaa repliikin.
func _tell_story() -> void:
	var k: Node3D = world.kota
	var unheard := []
	for i in Kota.STORIES.size():
		if not tarinat_kuultu.has(i):
			unheard.append(i)
	var idx: int = unheard.pick_random() if not unheard.is_empty() else randi() % Kota.STORIES.size()
	var prev := state
	state = "cutscene"
	player.controls_enabled = false
	player.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	var cam := Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.global_position = k.to_global(Vector3(0.2, 1.55, -2.3))
	cam.look_at(k.to_global(Vector3(0, 0.9, 1.2)), Vector3.UP)
	cam.current = true
	player.visible = false
	k.say("raimo", "")
	k.say("veikko", "")
	for line in Kota.STORIES[idx]:
		var who: String = line[0]
		var dur := clampf(1.5 + line[1].length() * 0.055, 2.5, 7.0)
		(k.raimo if who == "raimo" else k.veikko).play("Sitting_Talking", 0.2)
		_show_message("%s: %s" % ["Raimo" if who == "raimo" else "Veikko", line[1]], dur)
		var t := 0.0
		while t < dur:
			await get_tree().process_frame
			t += get_process_delta_time()
			if t > 0.4 and Input.is_action_just_pressed("interact"):
				break
		(k.raimo if who == "raimo" else k.veikko).play("Sitting_Idle", 0.3)
	cam.queue_free()
	player.visible = true
	player.activate_camera()
	player.controls_enabled = true
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	state = prev
	var fresh := not tarinat_kuultu.has(idx)
	if fresh:
		tarinat_kuultu.append(idx)
		tilat.first("tarina_%d" % idx, 0.15)
		tilat.add("stressi", 0.15)
		_save_game()
	if tarinat_kuultu.size() >= Kota.STORIES.size() and fresh:
		_show_message("Olet kuullut kaikki kodan tarinat! Raimo: \"No sitten keksitään uusia.\"", 5.0)
	else:
		_show_message(("Uusi tarina kuultu! (%d/%d)" if fresh else "Tuttu tarina, mutta hyvä se on. (%d/%d)") % [
			tarinat_kuultu.size(), Kota.STORIES.size()], 3.0)


func _win_laavu() -> void:
	state = "cutscene"
	player.controls_enabled = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_hud.visible = false
	laavu_conquered = true
	if not Sfx.has_music():
		Sfx.play("win")  # biisi soi loppukohtauksessa, jingle vain ilman sitä
	var title := "LEGENDAARINEN NORMIPÄIVÄ!" if fire_lit and sausage_done else "LAAVULLA KALJOILLA!"
	# Onnellinen loppu juo laavun jemman tyhjäksi (ja mukana olleet kaljat).
	var drunk := beers + 1 + stash_laavu
	_task_done()
	tilat.first("laavu", 0.5)
	_drink(mini(drunk, 6))
	var stats := "Nuotio %s  ·  Makkara %s  ·  Kaljoja juotiin %d  ·  Aika %s" % [
		"✔" if fire_lit else "✘", "✔" if sausage_done else "✘", drunk, _time(elapsed)]
	beers = 0
	stash_laavu = 0
	player.set_carrying(false)
	_save_game()
	cutscene.laavu_sunset(M.w(M.LAAVU), world.fire, title, stats, func() -> void: _new_day(_nearest_safe(), false))


# --- Tapahtumat --------------------------------------------------------------

func _enter_shop() -> void:
	tilat.first("kauppa")
	_shop_prev = state
	state = "in_shop"
	player.controls_enabled = false
	player.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)  # vasta ruudun lopussa: signaali voi tulla kesken vaaran fysiikkapäivityksen
	if wife.mode == "chase" and not wife_alerted:
		wife.reset_to(wife.farthest_node_from(shop_zone))
	interior.money = money
	interior.price_mult = 1.0 - 0.1 * tilat.effect("moraali")
	interior.enter()
	Sfx.play("door", -3.0)


## Vaalan K-Market Tervaportti: sama kauppa kuin kylässä, lisäksi Alkon hylly. Mopo jää oven eteen.
var _shop_vaala := false


func _enter_vaala_shop() -> void:
	mopo_trip.stop()
	_mopo_foot_inside()
	_shop_vaala = true
	state = "in_shop"
	_mopo_label.visible = false
	_compass.visible = false
	interior.vaala = true
	interior.money = money
	interior.enter()
	Sfx.play("door", -3.0)
	tilat.first("kauppa_vaala", 0.2)
	_show_message("K-Market Tervaportti, Vaala. Alkon hylly vasemmalla seinällä.", 3.0)


func _on_vaala_shop_exited(bought: bool) -> void:
	interior.leave()
	interior.vaala = false
	_shop_vaala = false
	Sfx.play("door_close", -3.0)
	var got: Array[String] = []
	if interior.has_paid:
		has_sausage = has_sausage or interior.cart.has("makkara")
		has_matches = has_matches or interior.cart.has("tikut")
		has_chocolate = has_chocolate or interior.cart.has("suklaa")
		for k in ShopInterior.BAKERY:
			if interior.cart.has(k):
				food[k] = food.get(k, 0) + 1
		var bottles: int = interior.alko_count()
		_chase_viina = bottles if interior.stolen else 0
		if bottles > 0:
			viina_pullot += bottles
			got.append("pullo Koskenkorvaa" if bottles == 1 else "%d pulloa Koskenkorvaa" % bottles)
		for k in interior.bag:
			paivi_bag[k] = interior.bag[k]
	if bought:
		beers += 6
		got.push_front("kuutonen")
	var ran: bool = interior.stolen
	_reset_shop_visit()
	state = _vaala_state
	_mopo_label.visible = true
	_compass.visible = true
	_mopo_resume()
	if ran:
		_show_message("JUOKSUKALJAT! Kauppias juoksee perään – mopolla ei pääse karkuun!\nKassissa %s. Heitä kaljoja päin!" % [
			" ja ".join(got)], 4.0)
		_start_shop_chase(mopo_trip.vaala.to_global(mopo_trip.vaala.kmarket_door), false)
	elif mopo_trip.on_foot != null:
		_show_message(("Kassissa %s." % " ja ".join(got)) if not got.is_empty() else "Takaisin ulos.", 3.0)
	else:
		_show_message(("Kassissa %s. Mopon kyytiin!" % " ja ".join(got)) if not got.is_empty() else "Takaisin mopon kyytiin.", 3.0)


## Oulujärven lava: lavatanssit (lava_game.gd) lavan lattialla. Lippu maksetaan ovella; hyvä tanssi nostaa
## moraalia ja vähentää stressiä, kömpelökin ilta piristää. Mopo jää oven eteen.
var _lava_game: Node3D


func _enter_lava() -> void:
	if money < MopoTrip.LAVA_TICKET:
		_show_message("Lippu maksaa %s €. Rahat ei riitä – pankkiautomaatti on K-Market Tervaportin seinällä." %
			_eur(MopoTrip.LAVA_TICKET), 3.5)
		return
	money -= MopoTrip.LAVA_TICKET
	Sfx.play("coin", -4.0)
	mopo_trip.stop()
	_mopo_foot_inside()
	state = "lava"
	_mopo_label.visible = false
	_compass.visible = false
	_hint.text = ""
	tilat.first("lava", 0.3)
	_lava_game = LavaGame.new()
	mopo_trip.vaala.add_child(_lava_game)
	_lava_game.position = mopo_trip.vaala.lava_center
	_lava_game.finished.connect(_on_lava_finished)


func _on_lava_finished(score: float) -> void:
	_lava_game.queue_free()
	_lava_game = null
	tilat.add("moraali", 0.1 + score * 0.25)
	tilat.add("stressi", 0.1 + score * 0.15)
	mielihyva += 2.0 + score * 6.0
	state = _vaala_state
	_mopo_label.visible = true
	_compass.visible = true
	_mopo_resume()
	_show_message("Lavatanssit Oulujärven lavalla! %s" % ("Ilta jää mieleen." if score > 0.6 else "Varpaat muistavat illan."), 3.0)


## Kaupan sisätila uudeksi (kuten uutena päivänä): edellisen käynnin tila ei siirry seuraavaan käyntiin.
func _renew_shop_interior() -> void:
	var old := interior
	_spawn_interior()
	old.queue_free()


## Kaupan kori tyhjäksi seuraavaa käyntiä varten (sama sisätila kuin kylän K-Marketissa).
func _reset_shop_visit() -> void:
	interior.has_beer = false
	interior.has_paid = false
	interior.stolen = false
	interior.cart.clear()
	interior.bag.clear()
	interior.walker.set_carrying(false)


func _on_shop_exited(bought: bool) -> void:
	# Jokainen käynti alkaa puhtaalta pöydältä (kauppaan saa palata saman päivän aikana): kori, maksu, kalja kädessä,
	# Päivin kassi, kassajono ja juoksukaljat nollautuvat, kun sisätila rakennetaan uudelleen tämän käsittelyn jälkeen.
	_renew_shop_interior.call_deferred()
	if _shop_vaala:
		_on_vaala_shop_exited(bought)
		return
	interior.leave()
	Sfx.play("door_close", -3.0)
	_shop_exit_frame = Engine.get_process_frames()
	player.global_position = shop_door + Vector3(0, 0.3, 1.6)  # ovelta pari askelta pihalle
	player.rotation.y = PI
	player.controls_enabled = true
	player.activate_camera()
	_hazards.process_mode = Node.PROCESS_MODE_INHERIT
	if interior.has_paid:
		has_sausage = has_sausage or interior.cart.has("makkara")
		has_matches = has_matches or interior.cart.has("tikut")
		has_chocolate = has_chocolate or interior.cart.has("suklaa")
		for k in ShopInterior.BAKERY:
			if interior.cart.has(k):
				food[k] = food.get(k, 0) + 1
		for k in interior.bag:
			paivi_bag[k] = interior.bag[k]
		if not interior.bag.is_empty() and not bought:
			_show_message("Päivin ostokset kassissa. Vie ne kotiin.", 2.5)
	if not bought:
		state = _shop_prev  # aiemmin tänään ostettu kuutonen pysyy ostettuna
		return
	beers += 6
	state = "to_home"  # = kuutonen ostettu tänään (ei tehtävä: kotiin tai kauppaan voi mennä milloin vain)
	player.set_carrying(true)
	if wife_alerted:
		wife.alerted = true
		wife.reset_to(wife.farthest_node_from(shop_zone))
		_show_message("Anna-Liisa soitti Päiville.\nPÄIVI TIETÄÄ MISSÄ OLET!", 3.5)
	elif interior.stolen:
		_show_message("JUOKSUKALJAT! Kauppias juoksee perään – se on nopeampi kuin pyörä!\nTaksiin, tai heitä kaljoja päin!", 4.0)
	if interior.stolen:
		_start_shop_chase(shop_door, true)
	else:
		_show_message("Kuutonen kassissa!", 2.5)


func _on_paid(total: float) -> void:
	money -= total


func _on_busted() -> void:
	wife_alerted = true
	_show_message("Naapurin Anna-Liisa näki sinut!\nKohta Päivi tietää...", 3.0)


func _on_wife_spotted() -> void:
	if state in ["to_shop", "to_home"] and mowing and _mow_lawn == sinikka_lawn and _once_today("sinikka_nurmi_nahty"):
		# Tarina: Päivi näki leikkaamassa Sinikan nurmikkoa. Suuttuu ja lähtee jahtiin; leikkuuta voi jatkaa karkuun päästyä.
		tilat.add("moraali", -0.1)
		tilat.add("stressi", -0.1)
		_show_message("PÄIVI NÄKI SINUT! \"SINIKAN nurmikkoa sää leikkaat?!\"\nPakoon, ja jatka kun pääset karkuun!", 3.5)
		return
	if state in ["to_shop", "to_home"] and not wife.alerted:
		_show_message("PÄIVI NÄKI SINUT!\nPakoon!", 2.0)


func _on_wife_caught() -> void:
	if state in ["to_shop", "to_home"]:
		_lose("Päivi nappasi kiinni!", "wife")


## Juntti sai kiinni -> Street Fighter -kaksintaistelu.
func _on_kicked(direction: Vector3) -> void:
	_start_fight("juntti", "juntti", direction)


## Laavun akka tai teinijengi haastaa.
func _on_laavu_challenge(kind: String, direction: Vector3) -> void:
	_start_fight(kind, "laavu", direction)


func _start_fight(foe_key: String, source: String, direction: Vector3) -> void:
	if not (state in ["to_shop", "to_home"]):
		return
	_fight_source = source
	_grill_t = -1.0
	_stop_picking(false)
	_stop_mowing()
	# Tilojen vaikutus tappeluun ennen iskuja: terveenä enemmän kestoa, sopivassa nousuhumalassa kovemmat iskut.
	var hp := 120.0 if tilat.effect("kipu") > 0 else 100.0
	var dmg := 1.2 if tilat.effect("humala") > 0 else 1.0
	# Tappelu: stressi, kipu ja moraali kärsivät, voimat kuluvat.
	tilat.add("stressi", -0.15)
	tilat.add("kipu", -0.3)
	tilat.add("stamina", -0.2)
	tilat.add("moraali", -0.1)
	tilat.add("nalka", -0.05)
	tilat.first("tappelu_" + foe_key, 0.3)
	_fight_prev = state
	_fight_dir = direction
	state = "fight"
	player.controls_enabled = false
	player.speed = 0.0
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)  # vasta ruudun lopussa: signaali voi tulla kesken vaaran fysiikkapäivityksen
	_hud.visible = false
	fight.start(beers, foe_key, hp, dmg)


func _on_fight_finished(won: bool, bags_used: int, thrown := 0) -> void:
	state = _fight_prev
	_hud.visible = true
	player.activate_camera()
	player.controls_enabled = true
	_hazards.process_mode = Node.PROCESS_MODE_INHERIT
	beers = maxi(0, beers - bags_used - thrown)
	var note := "\nKassi-iskut rikkoi %d kaljaa." % bags_used if bags_used > 0 else ""
	if thrown > 0:
		note += "\nHeitit %d kaljaa vastustajaa päin." % thrown
	if _fight_source == "kauppias":
		_kauppias_fight_end(won, note)
		return
	var loser_node: Node3D = {"juntti": juntti, "laavu": guard, "tractor": tractor}[_fight_source]
	if won:
		loser_node.defeat()
		tilat.add("moraali", 0.1)  # voitto kumoaa tappelun moraalimenetyksen
		tilat.add("kokemus", 0.1)
		var who := "Juntti lähti itkien kotiin."
		if _fight_source == "tractor":
			who = "Jyväjemmari ajoi murjottamaan. Pelto on nyt vapaata riistaa!"
		elif _fight_source == "laavu":
			laavu_conquered = true
			_save_game()
			who = "Akka lähti nostamaan meteliä muualle. Laavu on vapaa!" if guard.kind == "akka" else "Teinit pakenivat. Laavu on vapaa!"
		_show_message("K.O.! %s%s" % [who, note], 3.0)
	else:
		loser_node.gloat()
		player.stun(_fight_dir)
		var foe := "Juntti"
		if _fight_source == "tractor":
			foe = "Jyväjemmari"
		elif _fight_source == "laavu":
			foe = "Akka" if guard.kind == "akka" else "Teinit"
		if beers > 0:
			beers = maxi(0, beers - 2)
			Sfx.play("glass", -3.0)
			_show_message("Hävisit! %s potkaisi kassia, 2 kaljaa rikki.%s" % [foe, note], 3.0)
		else:
			money -= 5.0
			_show_message("Hävisit! %s vei vitosen \"lainaksi\"." % foe, 3.0)
			if state == "to_shop" and money < BEER_PRICE:
				_lose("%s vei rahat. Kuutoseen ei enää riitä." % foe, _fight_source if _fight_source == "juntti" else "default")
				return
	player.set_carrying(beers > 0)
	if state == "to_home" and beers <= 0 and not has_kanister and _stashed_today <= 0:
		_lose("Kaikki kaljat rikki. Kotiin ei kannata mennä tyhjin käsin.", "juntti")


## Juoksukaljat: kauppias lähtee perään kaupan ovelta. Saloisissa (taxi = true) etumatka riittää juuri ja juuri
## taksille, kun juoksee suoraan; Vaalassa taksia ei ole, joten edessä on aina tappelu.
func _start_shop_chase(door: Vector3, taxi: bool) -> void:
	if is_instance_valid(_shop_chaser):
		_shop_chaser.queue_free()
	var c := ShopChaser.new()
	add_child(c)
	c.global_position = door
	c.target_fn = func() -> Node3D: return player
	if _in_vaala:
		var vl: Node3D = mopo_trip.vaala
		c.ground_fn = func(x: float, z: float) -> float:
			var lp: Vector3 = vl.to_local(Vector3(x, 0, z))
			return vl.to_global(Vector3(lp.x, vl.h(lp.x, lp.z), lp.z)).y
	if taxi:
		var d := Vector2(door.x - world.taxi_pos.x, door.z - world.taxi_pos.z).length() - TAXI_RADIUS
		c.delay = maxf(1.0, d / OnFoot.RUN - d / ShopChaser.SPEED + 0.6)
	else:
		c.delay = 2.0
	c.caught.connect(func(dir: Vector3) -> void:
		if state in ["to_shop", "to_home"]:
			_start_fight("kauppias", "kauppias", dir))
	_shop_chaser = c


func _chasing() -> bool:
	return is_instance_valid(_shop_chaser) and _shop_chaser.is_chasing()


## Tappelu kauppiaan kanssa ohi: voitolla kaljat jäävät (heitetyt menivät), tappiolla kauppias vie loput kaljat
## (Vaalassa myös juostut Koskenkorvat) takaisin hyllyyn, eikä kuutosta ole haettu.
func _kauppias_fight_end(won: bool, note: String) -> void:
	var c := _shop_chaser
	_shop_chaser = null
	if won:
		if is_instance_valid(c):
			c.defeat()
		tilat.add("moraali", 0.1)
		tilat.add("kokemus", 0.1)
		_show_message("K.O.! Kauppias laahusti kassalle. Kaljat jäi sulle!%s" % note, 3.5)
	else:
		if is_instance_valid(c):
			c.gloat()
		if player.has_method("stun"):
			player.stun(_fight_dir)
		var took := beers
		beers = 0
		viina_pullot = maxi(0, viina_pullot - _chase_viina)
		Sfx.play("glass", -6.0, 0.8)
		if not _in_vaala:
			state = "to_shop"  # kuutonen palautui hyllyyn: ei haettu tänään
		_show_message("Hävisit! Kauppias vei %s takaisin hyllyyn ja kung fu -potkaisi perään.%s" % [
			"%d kaljaa" % took if took > 0 else "kaljat", note], 3.5)
	_chase_viina = 0
	player.set_carrying(beers > 0)


# --- Tarina (story.gd) ---------------------------------------------------------------------------------

func _story_step(to: String) -> void:
	story.step = to
	match to:
		"pekka_kutsuu":
			_msg_queue.append([Story.PEKKA_CALL, 4.0])
		"pekka_avaimet":
			_msg_queue.append(["Pekka huikkaa pihalta: \"Kaikki tehty? Tuu käymään, lähetään... kohta!\"", 4.0])
		"avaimet":
			_place_keys()
		"valmis":
			_msg_queue.append(["Pekan kyyti Paapeliin on nyt auki! Pyydä Pekalta kyyti mökille.", 4.0])
	Sfx.play("win_small", -6.0)
	_save_game()


func _story_check_tasks() -> void:
	if story.step == "tehtavat" and story.all_tasks_done():
		_story_step("pekka_avaimet")
	else:
		_save_game()


## Pekan ja Arton tarinavuorosanat ja luovutukset; palauttaa true, jos hoiti vihjeen.
func _story_neighbor(e: bool) -> bool:
	if player == bike:
		return false
	if pekka.distance_to_player() < 4.2:
		match story.step:
			"pekka_kutsuu":
				_hint.text = "[E] Kuuntele, mitä Pekalla on asiaa"
				if e:
					pekka.say(Story.PEKKA_TASKS[0])
					for l in Story.PEKKA_TASKS.slice(1):
						_msg_queue.append(["Pekka: \"%s\"" % l, 4.0])
					_msg_queue.append(["Uudet tehtävät repussa (I): sienet Pekalle, puolukat Artolle ja Sinikan nurmikko.", 4.0])
					_story_step("tehtavat")
				return true
			"tehtavat":
				var l := _goods_l("pekka")
				if not story.done.sienet and l >= Story.SIENET_L:
					_hint.text = "[E] Anna Pekalle %d l sieniä" % Story.SIENET_L
					if e:
						money += _take_goods("pekka", Story.SIENET_L)
						story.done.sienet = true
						pekka.say("No perkele, hyviä sieniä! Näistä tulee saatanan hyvä kastike kyyhkyille.")
						Sfx.play("register", -4.0)
						_show_message("Pekan sienet hoidettu!", 2.5)
						_story_check_tasks()
					return true
			"pekka_avaimet":
				_hint.text = "[E] Juttele Pekan kanssa (lähdetäänkö?)"
				if e:
					pekka.say(Story.PEKKA_KEYS[0])
					for l in Story.PEKKA_KEYS.slice(1):
						_msg_queue.append(["Pekka: \"%s\"" % l, 4.5])
					_story_step("avaimet")
				return true
			"avaimet":
				_hint.text = "[E] Juttele Pekan kanssa"
				if e:
					pekka.say(["Avaimet on kodalla, lintutornin luona! Mää en pääse ilman autoa.",
						"Kodalla ne on, perkele. Laavulta polkua etelään."].pick_random())
				return true
			"avaimet_mukana":
				_hint.text = "[E] Anna autonavaimet Pekalle"
				if e:
					pekka.say(Story.PEKKA_THANKS)
					_story_step("valmis")
				return true
	if arto.distance_to_player() < 4.2 and story.step == "tehtavat" and not story.done.puolukat \
			and bucket.get("puolukka", 0) >= Story.PUOLUKAT_L:
		_hint.text = "[E] Anna Artolle %d l puolukoita" % Story.PUOLUKAT_L
		if e:
			bucket["puolukka"] -= Story.PUOLUKAT_L
			if bucket["puolukka"] <= 0:
				bucket.erase("puolukka")
			money += Story.PUOLUKAT_L * GOODS.puolukka.price
			story.done.puolukat = true
			arto.say("Kiitti! Tästä tulee hyvää hilloa. Pekka on kyllä koko kesän puhunu siitä Paapelista.")
			Sfx.play("register", -4.0)
			_show_message("Arton puolukat hoidettu! +%s €" % _eur(Story.PUOLUKAT_L * GOODS.puolukka.price), 2.5)
			_story_check_tasks()
		return true
	return false


## Ämpärin litrat, jotka annettu ostaja (arto / pekka) ostaa.
func _goods_l(buyer: String) -> int:
	var n := 0
	for k in bucket:
		if GOODS[k].buyer == buyer:
			n += bucket[k]
	return n


## Ottaa ämpäristä n litraa ostajan tavaraa (kalleimmasta alkaen) ja palauttaa hinnan.
func _take_goods(buyer: String, n: int) -> float:
	var pay := 0.0
	var keys: Array = bucket.keys().filter(func(k: String) -> bool: return GOODS[k].buyer == buyer)
	keys.sort_custom(func(a: String, b: String) -> bool: return GOODS[a].price > GOODS[b].price)
	for k in keys:
		var take: int = mini(n, bucket[k])
		bucket[k] -= take
		pay += take * GOODS[k].price
		n -= take
		if bucket[k] <= 0:
			bucket.erase(k)
		if n <= 0:
			break
	return pay


## Sinikan nurmikon leikkuri ja Pekan avaimet kodalla (_outside_logic).
func _story_logic() -> void:
	if _hint.text != "" or player != walker_out or player.is_stunned() or mowing:
		return
	var p := player.global_position
	var e := Input.is_action_just_pressed("interact")
	if story.step == "tehtavat" and not story.done.nurmikko:
		var mp: Vector3 = sinikka_lawn.mower.global_position
		if Vector2(p.x - mp.x, p.z - mp.z).length() < 1.6:
			_hint.text = "[E] Leikkaa Sinikan nurmikko, ettei Päivi nää (leikattu %d %%)" % roundi(sinikka_lawn.cut_ratio() * 100.0)
			if e:
				_start_mowing(sinikka_lawn)
				_show_message("Sinikan leikkuri käy. Pidä silmällä Päiviä ja Anna-Liisaa!", 3.0)
			return
	if story.step == "avaimet" and is_instance_valid(_keys_node):
		var kp := _keys_node.global_position
		if Vector2(p.x - kp.x, p.z - kp.z).length() < 1.6:
			_hint.text = "[E] Ota Pekan autonavaimet"
			if e:
				_keys_node.queue_free()
				_keys_node = null
				Sfx.play("pickup", -2.0, 1.4)
				_show_message("Pekan avaimet! Avaimenperänä kyyhkyn sulka. Vie ne Pekalle.", 3.5)
				_story_step("avaimet_mukana")


## Pekan autonavaimet kodan eteen maahan: rengas, kaksi avainta ja kyyhkyn sulka.
func _place_keys() -> void:
	if is_instance_valid(_keys_node) or world.kota == null:
		return
	var at: Vector3 = world.kota.to_global(Vector3(-1.6, 0, -8.0))
	at.y = Terrain.h(at.x, at.z)
	_keys_node = Node3D.new()
	add_child(_keys_node)
	_keys_node.global_position = at
	B.mesh(_keys_node, B.cyl(0.05, 0.05, 0.012, 14), Vector3(0, 0.02, 0), Color(0.75, 0.75, 0.78))
	for k in 2:
		B.mesh(_keys_node, B.boxm(Vector3(0.025, 0.008, 0.11)), Vector3(-0.03 + k * 0.06, 0.02, 0.09), Color(0.85, 0.75, 0.3))
	B.mesh(_keys_node, B.boxm(Vector3(0.04, 0.006, 0.16)), Vector3(0.08, 0.02, -0.06), Color(0.55, 0.55, 0.6), Vector3(0, 30, 0))
	B.mesh(_keys_node, B.boxm(Vector3(0.09, 0.012, 0.06)), Vector3(-0.09, 0.02, -0.02), Color(0.85, 0.12, 0.1))  # avaimenperä
	_keys_node.scale = Vector3.ONE * 2.2  # erottuu nurmikolta


const JEMMA_GOAL := 24

# Kota: sahaus ja pilkkominen, tuli ja tarinat.
const HALOT_PER_POLKKY := 4
const FIRE_HALOT := 4
var kota_polkyt := 0
var kota_halot := 0
var _minigame_prev := "to_shop"
var tarinat_kuultu: Array = []  # kuultujen tarinoiden indeksit (tallentuu)
var _kota_chat_t := 6.0
var _story_skip := false
var _edge_cd := 0.0

## Kartan reunalla: hahmon kommentit (alue, repliikit).
const EDGE_LINES := {
	"west": ["Valtatie 8 vie Ouluun. Ei tänään, kalja lämpenee.", "Tuolla on Pattijoki. Sinne ei kukaan mene vapaaehtoisesti.",
		"Länteen on vain meri ja Hailuoto. Pyörä ei kellu."],
	"north": ["Tuolla on Raahen keskusta ja Alko... ei, pysytään suunnitelmassa.", "Pohjoisessa on vain teollisuusalue ja anoppi Pirjo. Takaisin!",
		"Tästä eteenpäin navigaattori sanoisi: käänny ympäri."],
	"east": ["Idässä on pelkkää suota ja Pekan jäniksiä.", "Tuonne ei ole tietä. Eikä kauppaa. Eikä järkeä.",
		"Mettää ja mettää. Ei täällä ole kaljaa."],
	"south": ["Tekojärven takana on Pyhäjoki. Ei sinne pyörällä.", "Tästä alkaa Siikajoen kunta. Siellä on omat juntit.",
		"Etelään on liian pitkä matka kuutosen kanssa."],
	"any": ["Kartta loppuu tähän. Päivi sanoi, ettei pidemmälle.", "Maailman reuna. Saloisten raja. Sama asia.",
		"Ei jakseta. Kauppa on toiseen suuntaan.", "Tuolla ei ole mitään. Tai jos on, niin se ei kuulu mulle."],
}
const CARRY_FOOT := 12  # jalan jaksaa kantaa kaksi kuutosta
const CARRY_BIKE := 6  # pyörän tarakalle mahtuu kuutonen

## Kotiinpaluu: saalis jemmaan. Kun kotijemmassa on 24 olutta, tulee onnellinen loppu:
## karburaattorin säätöä autotallissa kalja kädessä (kotijemma juodaan tyhjäksi). party = juhlat aloitettiin
## kotipiilolta (_stash_logic, kotipiiloissa vähintään JEMMA_GOAL); nukkumaan mentäessä juhlia ei aloiteta itsestään.
func _win(party := false) -> void:
	var shopped := state == "to_home"  # kuutonen haettu tänään
	state = "cutscene"
	player.controls_enabled = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	if not _list_done and not paivi_bag.is_empty():
		# Päivin palaute ostoksista uuden päivän aloitusviestin jälkeen (ennen uutta listaa).
		for l in _check_list():
			_msg_queue.append([l, 3.0])
	elif not _list_done and not shopping_list.is_empty():
		# Kotiin tyhjin käsin: Päivin ostokset jäivät hakematta (sama vaikutus kuin väärillä ostoksilla, _check_list).
		_list_done = true
		tilat.add("stressi", -0.2)
		tilat.add("moraali", -0.1)
		_msg_queue.append(["Päivi: \"%s\"" % PAIVI_NO_SHOPPING.pick_random(), 3.0])
	if shopped:
		_task_done()
		jemma_wins += 1
	jemma_best = maxi(jemma_best, jemma)
	beers = 0
	_save_game()
	if party:
		_hud.visible = false
		if not Sfx.has_music():
			Sfx.play("win")  # biisi soi loppukohtauksessa, jingle vain ilman sitä
		var had := jemma
		_drink(6)  # juhlat autotallissa
		jemma = 0  # onnellinen loppu juo kotijemman tyhjäksi
		jemma_endings += 1
		_save_game()
		var stats := "Jemmassa oli %d olutta – juhlan paikka!  ·  Onnellisia loppuja: %d" % [had, jemma_endings]
		cutscene.garage("KARBURAATTORIA SÄÄTÄMÄSSÄ", stats, func() -> void: _new_day(home_zone + Vector3(0, 0, 4), false))
		return
	Sfx.play("win_small")
	_new_day(home_zone + Vector3(0, 0, 4), false,
		"Kotona! Kotijemmat %d/%d – kun niissä on %d, juhlat aloitetaan kotipiilolta.\n" % [jemma, JEMMA_GOAL, JEMMA_GOAL])


func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for id in STASHES:
		stash[id] = cfg.get_value("jemmat", id, 0)
	stash_used = cfg.get_value("jemmat", "kaytetyt", [])
	# Vanhan version jemmat (kaljat/laavu/grilli) eivät siirry: Päivi löysi ne.
	for k in ["kaljat", "laavu", "grilli"]:
		_old_stash_lost += int(cfg.get_value("jemma", k, 0))
	jemma_best = cfg.get_value("jemma", "ennatys", 0)
	jemma_wins = cfg.get_value("jemma", "kotiinpaluut", 0)
	laavu_conquered = cfg.get_value("peli", "laavu_vallattu", false)
	money = cfg.get_value("peli", "rahat", START_MONEY)
	day = cfg.get_value("peli", "paiva", 1)
	has_chocolate = cfg.get_value("peli", "suklaa", false)
	mielihyva = cfg.get_value("peli", "mielihyva", 0.0)
	drone_photos = cfg.get_value("drooni", "kuvat", [])
	pontikka_found = cfg.get_value("drooni", "pontikka", false)
	viina_found = cfg.get_value("mokki", "viinakatkot", [])
	viina_pullot = cfg.get_value("mokki", "viinapullot", 0)
	atm_day = cfg.get_value("peli", "otto_paiva", 0)
	maine = cfg.get_value("peli", "maine", 0.0)
	jemma_endings = cfg.get_value("jemma", "loput", 0)
	tarinat_kuultu = cfg.get_value("kota", "tarinat", [])
	lawn.load_state(cfg.get_value("nurmikko", "pituudet", PackedByteArray()))
	lawn_siilit = cfg.get_value("nurmikko", "siilit", 0)
	lawn_kivet = cfg.get_value("nurmikko", "kivet", 0)
	mower_broken = cfg.get_value("nurmikko", "rikki", false)
	has_mower_part = cfg.get_value("nurmikko", "varaosa", false)
	sinikka_task = cfg.get_value("sinikka", "tehtava", 0)
	tikka_ennatys = cfg.get_value("mokki", "tikka_ennatys", 0)
	hommat.reviews = cfg.get_value("mokki", "arvostelut", [])
	_lawn_praise = cfg.get_value("nurmikko", "kehu", false)
	tilat.load_from(cfg)
	story.load_from(cfg)
	_taxi_mokki_return = cfg.get_value("tarina", "taksi_paluu", false)
	if cfg.has_section_key("peli", "pyora"):
		_bike_saved = [cfg.get_value("peli", "pyora"), cfg.get_value("peli", "pyora_kulma", 0.0)]
		_bike_garage_saved = cfg.get_value("peli", "pyora_tallissa", false)


func _save_game() -> void:
	var cfg := ConfigFile.new()
	for id in STASHES:
		cfg.set_value("jemmat", id, stash.get(id, 0))
	cfg.set_value("jemmat", "kaytetyt", stash_used)
	cfg.set_value("jemma", "ennatys", jemma_best)
	cfg.set_value("jemma", "kotiinpaluut", jemma_wins)
	cfg.set_value("peli", "laavu_vallattu", laavu_conquered)
	cfg.set_value("peli", "rahat", money)
	cfg.set_value("peli", "paiva", day)
	cfg.set_value("peli", "suklaa", has_chocolate)
	cfg.set_value("peli", "mielihyva", mielihyva)
	cfg.set_value("drooni", "kuvat", drone_photos)
	cfg.set_value("drooni", "pontikka", pontikka_found)
	cfg.set_value("mokki", "viinakatkot", viina_found)
	cfg.set_value("mokki", "viinapullot", viina_pullot)
	cfg.set_value("peli", "otto_paiva", atm_day)
	cfg.set_value("peli", "maine", maine)
	cfg.set_value("jemma", "loput", jemma_endings)
	cfg.set_value("kota", "tarinat", tarinat_kuultu)
	if lawn != null:
		cfg.set_value("nurmikko", "pituudet", lawn.save_state())
	cfg.set_value("nurmikko", "siilit", lawn_siilit)
	cfg.set_value("nurmikko", "kivet", lawn_kivet)
	cfg.set_value("nurmikko", "rikki", mower_broken)
	cfg.set_value("nurmikko", "varaosa", has_mower_part)
	cfg.set_value("sinikka", "tehtava", sinikka_task)
	cfg.set_value("mokki", "tikka_ennatys", tikka_ennatys)
	if hommat != null:
		cfg.set_value("mokki", "arvostelut", hommat.reviews)
	cfg.set_value("nurmikko", "kehu", _lawn_praise)
	if tilat != null:
		tilat.save_to(cfg)
	if story != null:
		story.save_to(cfg)
		cfg.set_value("tarina", "taksi_paluu", _taxi_mokki_return)
	if bike != null:
		cfg.set_value("peli", "pyora", bike.global_position)
		cfg.set_value("peli", "pyora_kulma", bike.rotation.y)
		cfg.set_value("peli", "pyora_tallissa", bike_in_garage)
	cfg.save(SAVE_PATH)


## Kotijemmoihin kohdistuu riski jemmakohtaisesti: Päivi saattaa löytää täyden jemman ja kaataa puolet
## viemäriin (enintään yksi löytö aamussa). Ulkojemmoista teinit voivat pölliä. Tarkistetaan joka aamu.
func _jemma_check(allow_found := true) -> String:
	var note := ""
	if allow_found:
		var ids := _risky_stashes()
		ids.shuffle()
		for id in ids:
			if randf() < _find_chance(id):
				var lost: int = stash[id] / 2
				_jemma_choco = _offer_chocolate()
				if _jemma_choco == "ok":
					lost /= 2  # leppynyt Päivi kaataa viemäriin vain osan
				stash[id] -= lost
				_jemma_found = lost
				note += "\nLöysin sun kaljat %s ja kaadoin %d viemäriin!" % [STASHES[id].from, lost]
				tilat.add("stressi", -0.3)
				tilat.add("moraali", -0.2)
				break
	for id in STASHES:
		var st: Dictionary = STASHES[id]
		var n: int = stash.get(id, 0)
		if not st.home and n > 0 and randf() < st.steal:
			var stolen := clampi(randi_range(n / 2, n), 1, n)
			stash[id] = n - stolen
			_morning_info.append("Teinit pöllivät %s %d kaljaa!" % [st.from, stolen])
	var risky := _risky_stashes()
	if not risky.is_empty():
		var names: Array[String] = []
		for id in risky:
			names.append(STASHES[id].name)
		_morning_info.append("Varoitus: Päivi voi löytää jemman (%s)!" % ", ".join(names))
	_save_game()
	return note


## Häviö: WASTED-välianimaatio ja Päivin motkotus, sitten uusi päivä lähimmästä turvapaikasta.
## at = häviön paikka (oletus pelaaja); annettuna (mopomatka) uusi päivä alkaa kotoa.
func _lose(reason: String, cause := "default", at := Vector3.INF) -> void:
	if state == "cutscene":
		return
	state = "cutscene"
	_stop_mowing()
	_task_failed()
	player.controls_enabled = false
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)  # vasta ruudun lopussa: signaali voi tulla kesken vaaran fysiikkapäivityksen
	_hud.visible = false
	var spawn := _nearest_safe() if at == Vector3.INF else home_zone + Vector3(0, 0, 4)
	var choco := _offer_chocolate()
	_choco_mercy = choco == "ok"
	cutscene.wasted(player.global_position if at == Vector3.INF else at, reason, cause, home_zone,
		func() -> void: _new_day(spawn, true), choco)


## Suklaa annetaan Päiville automaattisesti motkotuksen hetkellä. Palauttaa "" (ei suklaata), "ok" tai "fail".
func _offer_chocolate() -> String:
	if not has_chocolate:
		return ""
	has_chocolate = false
	return "ok" if randf() < CHOCO_CHANCE else "fail"


## Grafiikan laatu (Settings): varjot, SSAO/SSIL, hehku, ruohon tiheys, lähipuiden etäisyys, FPS-näyttö.
## Erittäin matalalla ei ole auringon varjoja: ne piirtäisivät lähimaailman neljästi lisää joka ruudulla.
func _apply_settings() -> void:
	var q: int = Settings.get_v("quality")
	_env.ssao_enabled = q >= 2
	_env.ssil_enabled = q >= 3
	_env.glow_enabled = q >= 2
	_sun.shadow_enabled = q >= 1
	_sun.directional_shadow_max_distance = [70.0, 70.0, 120.0, 180.0][q]
	_sun.shadow_blur = [0.5, 0.5, 1.0, 1.5][q]
	world.set_quality(q)
	# Näkyvyysetäisyys: usva ja kameran kaukoraja (cam_ctl.gd) yhdessä; täydellä 900 m on entiset 90–700 m.
	var far: float = Settings.view_far()
	_env.fog_depth_begin = 90.0 * far / 900.0
	_env.fog_depth_end = 700.0 * far / 900.0
	_fps_label.visible = Settings.get_v("show_fps")
	get_tree().call_group(B.GUIDES, "set_visible", Settings.get_v("show_guides"))


## Lähin turvapaikka: koti tai laavu (kun se on vallattu).
func _nearest_safe() -> Vector3:
	var p := player.global_position
	var laavu := M.w(M.LAAVU) + Vector3(-3.0, 0, -6.0)
	if laavu_conquered and p.distance_to(laavu) < p.distance_to(home_zone):
		return laavu
	return home_zone + Vector3(0, 0, 4)


## Uusi päivä turvapaikasta: vaarat ja kauppa nollautuvat, jemma, rahat ja laavun valtaus säilyvät.
func _new_day(spawn: Vector3, lost: bool, intro := "") -> void:
	_thief_stop()  # yöllä teini jättää pyörän siihen, missä se on
	day += 1
	var at_m := _at_mokki_pos(spawn)  # mökillä herätessä pääpelin asiat odottavat kotiinpaluuta
	var stats_note := _end_day_stats(at_m)
	# Pyörä jää sinne, minne se jäi; päivä alkaa jalan turvapaikasta.
	beers = 0
	_stashed_today = 0
	food.clear()
	has_kanister = false
	_sulo_sold = false
	walker_out.set_kanister(false)
	bike.set_carrying(false)
	_place_on_foot(spawn + Vector3(0, 0.3, 0))
	walker_out.rotation.y = 0.0
	var bike_note := "" if at_m else _bike_note(spawn)
	has_sausage = false
	has_matches = false
	fire_lit = false
	sausage_done = false
	_grill_t = -1.0
	_stop_picking(false)
	world.fire.visible = false
	if world.kota != null:
		world.kota.set_fire(false)
	if mokki != null:
		mokki.reset_sauna()
		mokki.set_tub_fire(false)
	_set_carry("")
	saalis.clear()
	smoker_load.clear()
	smoker_fuel = 0.0
	smoker_temp = 18.0
	var bonus := ""
	if _no_allowance:
		_no_allowance = false
		bonus = "\nRaahen reissun jälkeen et saa multa rahaa kauppaan."
	elif money < START_MONEY:
		if lost:
			_morning_info.append("Takin taskusta löytyi vähän rahaa.")
		else:
			bonus = "\nLaitoin %s € kauppaa varten." % _eur(START_MONEY - money)
		money = START_MONEY
	if _choco_mercy:
		_choco_mercy = false
		money += CHOCO_MONEY
		bonus += "\nKiitos suklaasta. Tässä %s € ylimääräistä." % _eur(CHOCO_MONEY)
		tilat.add("stressi", 0.2)
	_beasts_today = 0
	_beast_forest_t = 0.0
	_bike_tuned = false
	bike.tune = 1.0
	if _beast != null and is_instance_valid(_beast):
		_beast.queue_free()
	_beast = null
	if bitten:
		bitten = false  # parani yöllä (ei ensiapua uuden päivän kipuun)
		wound_big = false
		walker_out.hurt = false
		walker_out.hurt_speed = walker_out.HURT_SPEED
		bonus += "\n" + WOUND_PAIVI.pick_random()
		_morning_info.append("Puremahaava parani yön aikana.")
	if not _list_done and not shopping_list.is_empty() and not at_m:
		bonus += "\nEilen ei tullu kaupasta mitään, vaikka oli lista!"
	bonus += stats_note
	if _sinikka_gossip:
		_sinikka_gossip = false
		_paivi_mad = true
		tilat.add("stressi", -0.1)
		bonus += "\n" + PAIVI_MORNING_SINIKKA.pick_random()
	if _santtu_gossip and not at_m:
		_santtu_gossip = false
		_paivi_mad = true
		tilat.add("stressi", -0.1)
		bonus += "\nSanttu soitti, että sää jätit mökillä hommat kesken. Kotonaki riittää hommia!"
	var mokki_note := ""
	if _slept_mokki:
		_slept_mokki = false
		tilat.add("stressi", -0.1)
		# Yö mökillä: aamun lapun kirjoittaa Santtu (mökillä herätessä).
		mokki_note = "\nPäivi soitti aamulla ja kyseli, missä sää oot ollu koko yön. Pekka heittää sut kotiin."
		bonus += mokki_note
	var rauha := _kaljarauha
	_kaljarauha = false
	_roll_list()
	# Nurmikko kasvaa yön aikana; siilit ja kivet uusiin paikkoihin, leikkuri takaisin paikalleen.
	_stop_mowing()
	if _lawn_praise:
		_lawn_praise = false
		money += LAWN_BONUS
		bonus += "\nNurmikko näyttää hienolta! Tässä %s € ylimääräistä." % _eur(LAWN_BONUS)
	_lawn_done_today = false
	lawn.grow()
	lawn.park_mower()
	lawn.spawn_objects()
	if not at_m:
		bonus += _lawn_nag()
	wife_alerted = false
	police = null
	vaino = null  # karkuri palaa yöksi itse kotiin
	_roll_vaino()
	for c in _hazards.get_children():
		c.queue_free()
	_spawn_threats()
	_apply_day_base()
	if _spawn_boys() and not at_m:
		_morning_info.append("Jossain päin kylää pojat pelaa jalkapalloa.")
	if laavu_conquered:
		guard.vanish()
	_minimap.wife = wife
	interior.queue_free()
	_spawn_interior()
	# Viiveellä: kotiinpaluu pysäyttää vaarat set_deferredillä samalla ruudulla, ja suora asetus
	# jäisi sen alle (vaarat jäätyisivät koko päiväksi). Viivästetyt kutsut suoritetaan järjestyksessä.
	_hazards.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	state = "to_shop"
	elapsed = 0.0
	_hud.visible = true
	_save_game()
	_jemma_found = 0
	_jemma_choco = ""
	var jnote := "" if at_m else _jemma_check(not rauha)
	if rauha and not at_m:
		jnote += "\nKauppareissu meni hienosti, joten en ees ettiny sun jemmoja."
	if _jemma_found > 0:
		# Päivi löysi jemman: välianimaatio ennen päivän alkua.
		state = "cutscene"
		_hud.visible = false
		player.controls_enabled = false
		_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		var lost_n := _jemma_found
		var msg := "%s%s%s" % [bonus, bike_note, jnote]
		cutscene.jemma_found(home_zone, lost_n, jemma, func() -> void:
			state = "to_shop"
			_hud.visible = true
			player.controls_enabled = true
			player.activate_camera()
			_hazards.process_mode = Node.PROCESS_MODE_INHERIT
			_day_note(MORNING_HEAD.koti.pick_random(), msg)
			_flush_morning_info(intro), _jemma_choco)
		return
	if at_m:
		# Mökillä vain mökin asiat: Päivin värilista kerrotaan, kun palataan kotiin (ks. _arrive_by_car).
		_hazards.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		_list_pending = true
		var rows: Array = _hommat_morning()
		_note.show_note([MORNING_HEAD.mokki.pick_random()]
			+ rows + Array(("%s%s" % [stats_note, mokki_note]).strip_edges().split("\n")), "– Santtu",
			10.0 if rows.is_empty() else 18.0)
		_flush_morning_info(intro)
		return
	hommat.stop()
	hommat.nights = 0
	_hommat_prepare()
	var where := "koti"
	if spawn.distance_to(mokki.global_position) < 80.0:
		where = "mokilta"
	elif spawn.distance_to(home_zone) > 50.0:
		where = "laavulta"
	_day_note(MORNING_HEAD[where].pick_random(), "%s%s%s" % [bonus, bike_note, jnote])
	_flush_morning_info(intro)


## Aamun lapun otsikko allekirjoittajan sanoin: kotona Päivi, laavulta ja mökiltä Päivi hämmästelee, mökillä Santtu.
const MORNING_HEAD := {
	"koti": ["Huomenta, kulta!", "Huomenta! Kahvia on pannussa.", "Huomenta! Mää lähin jo."],
	"laavulta": ["Missä sää taas yöllä olit?!", "Laavulla nukuit taas, vai?"],
	"mokilta": ["Tuu jo kotiin sieltä mökiltä!", "Huomenta, mökkiläinen."],
	"mokki": ["Huomenta! Kahvit on keitetty.", "Huomenta mökille!", "Aamu! Sauna lämpiää illalla."],
}
## Aamun pelitiedot (jemmat, varoitukset, teinit, pyörän paikka), joita lapun kirjoittaja ei tietäisi tai kirjoittaisi:
## näytetään ruudun viesteinä lapun rinnalla (_flush_morning_info).
var _morning_info: Array[String] = []


## Aamun pelitiedot ruudun viesteiksi. intro = päivän vaihdon oma viesti (kotiinpaluu, häviö, Raahe, mökki).
func _flush_morning_info(intro := "") -> void:
	var lines: Array[String] = []
	for l in intro.strip_edges().split("\n"):
		if l != "":
			lines.append(l)
	lines.append_array(_morning_info)
	_morning_info.clear()
	for l in lines:
		_queue_message(l, 3.0)


## Tallennettu pyörä paikalleen ja pelaaja jalan kotiin. Palauttaa aamumuistutuksen.
func _apply_saved_bike() -> String:
	if _bike_saved == null:
		return ""
	bike.global_position = _bike_saved[0]
	bike.rotation.y = _bike_saved[1]
	_place_on_foot(home_zone + Vector3(0, 0.3, 4))
	if _bike_garage_saved:
		_store_bike(true)
	return _bike_note(home_zone)


## Muistutus aamulla, jos pyörä jäi kauas.
func _bike_note(spawn: Vector3) -> String:
	if bike.global_position.distance_to(spawn) < 30.0:
		return ""
	_morning_info.append("Pyörä jäi eilen muualle – katso kartasta (M), minne.")
	return "\nPyörä ei oo pihassa. Mihin sää sen taas jätit?"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and bike != null:
		_save_game()  # pyörän paikka talteen, vaikka ikkuna suljettaisiin kesken päivän


func _at_mokki_pos(p: Vector3) -> bool:
	return Vector2(p.x - MOKKI_POS.x, p.z - MOKKI_POS.z).length() < MOKKI_AREA_R


## Ollaanko mökillä (pihalla, sisällä tai mökin minipeleissä)?
func _at_mokki() -> bool:
	return state == "in_mokki" or (player != null and _at_mokki_pos(player.global_position))


## Välimatka tekstinä: saman alueen sisällä metreinä, kodin ja mökin välillä oikea linnuntie.
func _dist_text(a: Vector3, b: Vector3) -> String:
	if _at_mokki_pos(a) != _at_mokki_pos(b):
		return "n. %d km" % roundi(HOME_MOKKI_KM)
	var d := Vector2(a.x - b.x, a.z - b.z).length()
	return "%d m" % int(d) if d < 2000.0 else "%.1f km" % (d / 1000.0)


# --- Syöte & ympäristö -------------------------------------------------------

## Toiminnot ja näppäimet tulevat asetuksista (Settings.KEY_ROWS, vaihdettavissa valikossa). Ohjerivin
## oletusnäppäimet ([E]) vaihdetaan valittuihin juuri ennen piirtoa.
func _setup_input() -> void:
	Settings.apply_keys()
	RenderingServer.frame_pre_draw.connect(_fix_hint_keys)


var _hint_shown := ""


func _fix_hint_keys() -> void:
	if _hint != null and _hint.text != _hint_shown:
		_hint_shown = Settings.key_hint(_hint.text)
		_hint.text = _hint_shown


func _setup_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = B.shader_mat("res://shaders/sky.gdshader")
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	# Syvyysvarjostus kulmiin ja epäsuora valo.
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.8
	env.ssil_enabled = true
	env.ssil_intensity = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	# Kaukaisuuden usva taivaan sävyssä, aurinko kajastaa.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.74, 0.8, 0.88)
	env.fog_sun_scatter = 0.25
	env.fog_depth_begin = 90.0
	env.fog_depth_end = 700.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	# Kesäiltapäivän matala, lämmin aurinko pitkine varjoineen.
	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-34, 145, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)


# --- Hahmot ------------------------------------------------------------------

func _spawn_player() -> void:
	player = PlayerBike.new()
	player.position = home_zone + Vector3(0, 0.3, 4)
	add_child(player)
	bike = player
	walker_out = OnFoot.new()
	walker_out.world = world
	add_child(walker_out)
	bike.legs = walker_out
	walker_out.visible = false
	walker_out.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)


## Vaihtaa ohjattavan hahmon (pyörä / jalan) ja päivittää kaikki, jotka seuraavat pelaajaa.
func _set_avatar(a: CharacterBody3D) -> void:
	player = a
	world.follow = a
	for h in [wife, juntti, guard, tractor, arto, pekka, sinikka, sulo, police, vaino, stray, mummot, boys]:
		if is_instance_valid(h):
			h.target = a
	_minimap.player = a
	_compass.player = a
	_paper.player = a
	a.activate_camera()


## Pelaaja jalan kohtaan pos; pyörä jää paikalleen ilman kuskia.
func _place_on_foot(pos: Vector3) -> void:
	bike.speed = 0.0
	bike.controls_enabled = false
	bike.set_rider_visible(false)
	walker_out.global_position = pos
	walker_out.velocity = Vector3.ZERO
	walker_out.visible = true
	walker_out.process_mode = Node.PROCESS_MODE_INHERIT
	# Myös viiveellä: käynnistyksessä _spawn_player poistaa jalan kulkijan käytöstä set_deferredillä,
	# joka muuten ajettaisiin tämän jälkeen ja jäädyttäisi hahmon ja kameran.
	walker_out.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	walker_out.controls_enabled = true
	walker_out.set_carrying(beers > 0)
	_set_avatar(walker_out)


## F: nouse pyörän selästä tai takaisin pyörälle (pyörän vieressä).
func _toggle_mount() -> void:
	_stop_mowing()
	if player == bike:
		if absf(bike.speed) > 3.0:
			_show_message("Hidasta ensin!", 1.2)
			return
		_place_on_foot(bike.global_position + bike.global_transform.basis.x * 1.1)
		walker_out.rotation.y = bike.rotation.y
		_save_game()  # pyörän paikka talteen
	else:
		if not _thief.is_empty():
			return  # varas ajaa vielä: ensin kiinni
		walker_out.visible = false
		walker_out.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		bike.set_rider_visible(true)
		bike.controls_enabled = true
		bike.set_carrying(beers > 0)
		_set_avatar(bike)


func _spawn_hazards() -> void:
	_hazards = Node3D.new()
	add_child(_hazards)
	_spawn_threats()
	# Naapurit omien talojensa ovilta, puuhailevat pihoillaan (world.neighbor_yards).
	arto = _neighbor("Naapurin Arto", Looks.ARTO, ARTO_LINES, "arto")
	pekka = _neighbor("Naapurin Pekka", Looks.PEKKA, PEKKA_LINES, "pekka")
	sinikka = _neighbor("Naapurin Sinikka", Looks.SINIKKA, SINIKKA_LINES, "sinikka")
	sinikka.chores.assign(["Fixing_Kneeling", "Crouch_Idle", "PickUp_Table", "Fixing_Kneeling"])  # kitkee, kastelee, istuttaa
	sulo = _villager("Pannu-Sulo", Looks.SULO, SULO_LINES, "sulo", M.PONTIKKA + Vector2(-2.2, -1.2))


var _traffic_t := 0.0


## Liikenne pysyy pelaajan ympärillä: kaukana (TRAFFIC_FAR) oleva auto siirretään tieverkon solmuun
## TRAFFIC_RESPAWN-etäisyydelle, mieluiten kameran taakse, ettei se ilmesty silmien eteen.
func _traffic_tick(delta: float) -> void:
	_traffic_t -= delta
	if _traffic_t > 0.0 or _hazards == null:
		return
	_traffic_t = 1.0
	var p := player.global_position
	var cam := get_viewport().get_camera_3d()
	var fwd := -cam.global_transform.basis.z if cam != null else Vector3.FORWARD
	for c in _hazards.get_children():
		if not (c is TrafficCar) or c.global_position.distance_to(p) < TRAFFIC_FAR:
			continue
		var cand: Array[int] = []
		var behind: Array[int] = []
		for i in world.graph_nodes.size():
			var to: Vector3 = world.graph_nodes[i] - p
			var d := to.length()
			if d < TRAFFIC_RESPAWN.x or d > TRAFFIC_RESPAWN.y or world.graph_adj[i].is_empty():
				continue
			cand.append(i)
			if to.normalized().dot(fwd) < 0.2:
				behind.append(i)
		var pick := behind if not behind.is_empty() else cand
		if not pick.is_empty():
			c.setup_graph(world.graph_nodes, world.graph_adj, pick.pick_random(), world.graph_fast)


## Päivi, juntti, laavun valtaajat ja jyväjemmari (luodaan uudelleen joka päivä).
func _spawn_threats() -> void:
	# Liikenne: autot ajavat tieverkkoa oikeaa kaistaa; alle jäänyt kuolee.
	var far_nodes: Array[int] = []
	for i in world.graph_nodes.size():
		var d: float = world.graph_nodes[i].distance_to(player.global_position)
		if d > 90.0 and d < TRAFFIC_FAR and world.graph_adj[i].size() > 0:
			far_nodes.append(i)
	for i in TRAFFIC:
		if far_nodes.is_empty():
			break
		var car := TrafficCar.new()
		car.van = randf() < 0.25
		car.cruise = randf_range(12.5, 16.0) * (0.9 if car.van else 1.0)
		car.target_fn = func() -> Node3D: return player
		car.hit.connect(func() -> void:
			if state in ["to_shop", "to_home"] and not _at_mokki():
				Sfx.play("punch_heavy", 2.0)
				_lose("Jäit auton alle.", "car"))
		_hazards.add_child(car)
		car.setup_graph(world.graph_nodes, world.graph_adj, far_nodes.pick_random(), world.graph_fast)
	wife = WifeCar.new()
	_hazards.add_child(wife)
	wife.setup(world.graph_nodes, world.graph_adj, world.nearest_node(M.w(M.J_T)), player)
	wife.world = world
	wife.spotted.connect(_on_wife_spotted)
	wife.caught.connect(_on_wife_caught)

	juntti = Juntti.new()
	juntti.position = M.w(M.JUNTTI_SPOTS.pick_random())
	juntti.target = player
	juntti.world = world
	juntti.kicked.connect(_on_kicked)
	_hazards.add_child(juntti)

	guard = LaavuGuard.new()
	guard.kind = ["akka", "teens"].pick_random()
	guard.center = M.w(M.LAAVU)
	guard.target = player
	guard.world = world
	guard.challenge.connect(_on_laavu_challenge)
	_hazards.add_child(guard)

	tractor = Tractor.new()
	tractor.position = M.w(M.TRACTOR_POS)
	tractor.rotation.y = -PI / 2.0
	tractor.target = player
	tractor.world = world
	tractor.challenge.connect(func(k: String, d: Vector3) -> void: _start_fight(k, "tractor", d))
	_hazards.add_child(tractor)

	# Kaupan penkin mummot (#14): kettukarkit, jos kurvaa läheltä lujaa tai soittaa kelloa.
	mummot = Mummot.new()
	mummot.position = M.w(M.SHOP_BUILDING) + Vector3(-6.0, 0, 10.2)
	mummot.target = player
	mummot.hit.connect(func(dir: Vector3) -> void:
		if state in ["to_shop", "to_home"] and not player.is_stunned():
			player.stagger(dir)
			tilat.add("kipu", -0.05)
			_show_message("Kettukarkki osui! Mummoilla on hyvä käsi.", 2.0))
	mummot.candy_picked.connect(func() -> void:
		walker_out.stamina = minf(100.0, walker_out.stamina + 15.0)
		_eat(0.1)
		_show_message("Kettukarkki maasta. Kunto +15", 1.5))
	mummot.angered.connect(func() -> void: tilat.add("moraali", -0.1))
	_hazards.add_child(mummot)

	stray = StrayDog.new()
	stray.spot = M.w(M.STRAY_SPOTS.pick_random())
	stray.position = stray.spot
	stray.target = player
	stray.world = world
	stray.growled.connect(func() -> void:
		if state in ["to_shop", "to_home"] and not bitten:
			_show_message("Vieras koira murisee. Tuohon ei kannata mennä rapsuttelemaan.", 2.5))
	stray.bit.connect(_on_bitten)
	_hazards.add_child(stray)
	wife.safe_zones = [[M.w(M.GRILLIKATOS), 7.5]]


## Kotipihan nurmikon kulma maailmassa (sx, sz = ±1 nurmikon omassa kehyksessä), paikkatarkistusta varten.
func _lawn_corner(sx: float, sz: float) -> Vector3:
	var l := Vector2(sx * world.lawn_rect.size.x, sz * world.lawn_rect.size.y) / 2.0
	var p: Vector2 = l.rotated(world.lawn_angle) + world.lawn_pivot
	return Vector3(p.x, 0, p.y)


func _villager(nimi: String, look: Dictionary, lines: Array, voice: String, px: Vector2) -> CharacterBody3D:
	var v := Villager.new()
	v.display_name = nimi
	v.look = look
	v.lines = lines
	v.voice = voice
	v.target = player
	v.position = M.w(px)
	add_child(v)
	return v


## Naapuri omalla pihallaan: aloittaa talonsa ulko-ovelta ja puuhailee pihan puuhapisteissä.
func _neighbor(nimi: String, look: Dictionary, lines: Array, key: String) -> CharacterBody3D:
	var v := Villager.new()
	v.display_name = nimi
	v.look = look
	v.lines = lines
	v.voice = key
	v.target = player
	v.yard.assign(world.neighbor_yards[key])
	v.faces.assign(world.neighbor_faces.get(key, []))
	var mid := Vector2(v.yard[0].x, v.yard[0].z)
	for o in world.blockers:
		if (o[0] as Vector2).distance_to(mid) < 40.0:
			v.obstacles.append(o)
	v.position = v.yard[0]
	v.rotation.y = B.yaw_to(v.yard[1] - v.yard[0])  # ovelta pihalle päin
	add_child(v)
	return v


func _spawn_interior() -> void:
	interior = ShopInterior.new()
	interior.position = INTERIOR_POS
	add_child(interior)
	interior.paid.connect(_on_paid)
	interior.busted.connect(_on_busted)
	interior.exited.connect(_on_shop_exited)


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	_hud = layer
	add_child(layer)
	_stats = _label(layer, 24)
	_stats.position = Vector2(20, 16)
	var help := _label(layer, 16)
	help.text = "W/S polje · A/D ohjaa · E toiminto · F jalan/pyörälle · T syö · I reppu · M kartta · V FPS · hiiri kamera · Esc valikko"
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 20
	help.offset_top = -36
	_status = _centered_label(layer, 30, 0.0, 66, 142)  # kompassin alle
	_status.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	_hint = _centered_label(layer, 30, 1.0, -130, -80)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # lapun vieressä tilaa on vähemmän (_avoid_note)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg = _centered_label(layer, 44, 0.3, -80, 120)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # pitkät viestit (tarinat) rivittyvät
	_msg.offset_left = 60
	_msg.offset_right = -60
	_note = Note.new()
	layer.add_child(_note)

	_sus_box = VBoxContainer.new()
	_sus_box.anchor_left = 1.0
	_sus_box.anchor_right = 1.0
	_sus_box.offset_left = -340
	_sus_box.offset_right = -20
	_sus_box.offset_top = 16
	layer.add_child(_sus_box)
	var sl := Label.new()
	sl.text = "Naapurin epäily"
	sl.add_theme_font_size_override("font_size", 20)
	sl.add_theme_color_override("font_outline_color", Color.BLACK)
	sl.add_theme_constant_override("outline_size", 6)
	_sus_box.add_child(sl)
	_sus_bar = ProgressBar.new()
	_sus_bar.max_value = 100.0
	_sus_bar.show_percentage = false
	_sus_bar.custom_minimum_size = Vector2(320, 22)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.2, 0.1)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_sus_bar.add_theme_stylebox_override("fill", fill)
	_sus_bar.add_theme_stylebox_override("background", bg)
	_sus_box.add_child(_sus_bar)
	_sus_box.visible = false
	_fps_label = _label(layer, 16)
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.offset_left = -120
	_fps_label.offset_top = 8

	_stamina_box = VBoxContainer.new()
	_stamina_box.anchor_left = 1.0
	_stamina_box.anchor_right = 1.0
	_stamina_box.anchor_top = 1.0
	_stamina_box.anchor_bottom = 1.0
	_stamina_box.offset_left = -226
	_stamina_box.offset_right = -16
	_stamina_box.offset_top = -16 - 210 - 44
	_stamina_box.offset_bottom = -16 - 214
	layer.add_child(_stamina_box)
	var st_l := Label.new()
	st_l.text = "Kunto"
	st_l.add_theme_font_size_override("font_size", 16)
	st_l.add_theme_color_override("font_outline_color", Color.BLACK)
	st_l.add_theme_constant_override("outline_size", 6)
	_stamina_box.add_child(st_l)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.max_value = 100.0
	_stamina_bar.show_percentage = false
	_stamina_bar.custom_minimum_size = Vector2(210, 12)
	var sfill := StyleBoxFlat.new()
	sfill.bg_color = Color(0.3, 0.8, 0.4)
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0, 0, 0, 0.5)
	_stamina_bar.add_theme_stylebox_override("fill", sfill)
	_stamina_bar.add_theme_stylebox_override("background", sbg)
	_stamina_box.add_child(_stamina_bar)
	_stamina_box.visible = false

	_minimap = Minimap.new()
	_minimap.anchor_left = 1.0
	_minimap.anchor_right = 1.0
	_minimap.anchor_top = 1.0
	_minimap.anchor_bottom = 1.0
	_minimap.offset_left = -16 - 210
	_minimap.offset_top = -16 - 210
	_minimap.player = player
	_minimap.wife = wife
	_minimap.world = world
	_minimap.bike = bike
	_minimap.mokki = mokki
	layer.add_child(_minimap)

	_item_menu = ItemMenu.new()
	layer.add_child(_item_menu)
	_item_menu.chosen.connect(func(id: String) -> void:
		if _menu_mode == "eat":
			_on_eat(id)
		elif _menu_mode == "siitari":
			_on_siitari(id)
		elif _menu_mode == "raahe":
			_on_raahe(id)
		elif _menu_mode == "santtu":
			_on_santtu_menu(id)
		elif _menu_mode == "wc":
			_start_wc(id)
		elif _menu_mode == "taksi":
			_on_taxi_choice(id)
		else:
			_on_give(id))
	_item_menu.cancelled.connect(func() -> void:
		if _menu_mode == "siitari":
			_on_siitari("takaisin")
		elif _menu_mode == "raahe":
			_on_raahe("takaisin")
		elif _menu_mode == "wc":
			_menu_mode = "give"
			_wc_release()
		else:
			_mopo_menu(false)
			player.controls_enabled = true)

	_mopo_label = _label(layer, 22)
	_mopo_label.position = Vector2(20, 12)
	_mopo_label.visible = false

	_stat_bars = StatBars.new()
	_stat_bars.anchor_left = 1.0
	_stat_bars.anchor_right = 1.0
	_stat_bars.offset_left = -300
	_stat_bars.offset_right = -20
	_stat_bars.offset_top = 36
	layer.add_child(_stat_bars)

	_compass = Compass.new()
	_compass.player = player
	_compass.paper = _paper
	layer.add_child(_compass)


## Päivin lappu on ruudun vasemmalla: sen näkyessä keskitetyt HUD-tekstit (viestit, vihje, tila) siirtyvät lapun
## oikealle puolelle, etteivät ne jää lapun alle. Pitkät viestit rivittyvät jäljelle jäävään tilaan.
func _avoid_note() -> void:
	var left := 0.0
	if _note != null and _note.is_showing():
		left = _note._paper.get_global_rect().end.x + 40.0  # lappu on vinossa: vähän väljyyttä
	_msg.offset_left = maxf(60.0, left)
	_hint.offset_left = left
	_status.offset_left = left


func _update_hud() -> void:
	_avoid_note()
	# Rahat, kauppalista, tavarat, jemmat ja mittarit ovat repussa (I): päänäkymässä vain matkan tiedot.
	# Mökillä pääpelin tehtävät eivät näy.
	var at_mokki := _at_mokki()
	var lines: Array[String] = []
	if at_mokki and _compass.visible and _compass.has_cache:
		var pp := Vector2(player.global_position.x, player.global_position.z)
		var deg := Compass.bearing_deg(pp, _compass.cache)
		lines.append("Viinakätkö %d / %d: %d m  %s %d°" % [viina_found.size() + 1, Mokki.VIINA.size(),
			roundi(pp.distance_to(_compass.cache)), Compass.dir_name(deg), roundi(deg)])
	if at_mokki and hommat.active and state in ["to_shop", "to_home", "in_mokki"]:
		lines.append("Santun hommat %d / %d · hermot %s" % [hommat.done.size(), hommat.tasks.size(), hommat.bar()])
		if _carry != "":
			lines.append("Kädessä: %s%s" % [{"sanko": "huussin sanko", "halot": "syli halkoja", "kahvi": "Santun kahvit"}[_carry],
				"  ⚠ läikkyy!" if _carry_slosh > 0.5 else ""])
	var away := at_mokki or _in_vaala
	if not away:
		lines.append("Aika: %s" % _time(elapsed))
		if not _risky_stashes().is_empty():
			lines.append("⚠ Kotijemma vaarassa (I)")
	if state in ["to_shop", "to_home"] and not away:
		lines.append("Alusta: %s" % world.TERRAIN[player.surface].name)
	_stamina_box.visible = state in ["to_shop", "to_home"]  # juoksu ja pyörän spurtti kuluttavat samaa kuntoa
	if _stamina_box.visible:
		_stamina_bar.value = walker_out.stamina
		(_stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.9, 0.3, 0.2) if walker_out.exhausted else Color(0.3, 0.8, 0.4)
	_stats.text = "\n".join(lines)
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_minimap.visible = not (state in ["in_shop", "in_mokki", "in_home", "in_garage", "in_siitari", "in_raahe", "lava"]) and not _in_vaala
	_minimap.target = shop_zone if state == "to_shop" else home_zone
	_minimap.show_target = false  # ei tehtäväkohdetta: kauppa ja koti näkyvät kartalla merkkeinä
	_compass.visible = state in ["to_shop", "to_home"]
	_compass.show_target = not away

	var status: Array[String] = []
	if state in ["to_shop", "to_home"] and not away:
		if wife.is_target_safe():
			status.append("TURVASSA – KIILINLAMMEN GRILLIKATOS")
		elif wife.alerted:
			status.append("PÄIVI TIETÄÄ MISSÄ OLET!")
		elif wife.mode == "chase":
			status.append("PÄIVI JAHTAA!")
		if juntti.mode == "chase":
			status.append("JUNTTI JAHTAA!")
		if tractor.mode == "chase":
			status.append("JYVÄJEMMARI JAHTAA!")
		if is_instance_valid(police) and not police.is_leaving():
			status.append("POLIISI JAHTAA!")
		if bitten:
			status.append("PURTU – HAAVA PITÄÄ HOITAA")
		if mummot.is_angry():
			status.append("MUMMOT HEITTELEE KETTUKARKKEJA!")
		if is_instance_valid(vaino):
			if vaino.mode == "follow":
				status.append("VÄINÖ MUKANA – VIE PEKALLE")
			else:
				var vd := roundi(vaino.distance_to_target() / 10.0) * 10
				status.append("VÄINÖ KARKUSSA" + (" (n. %d m)" % vd if vd >= 10 else ""))
	_status.text = "\n".join(status)

	var nb: CharacterBody3D = interior.neighbor
	_sus_box.visible = state == "in_shop" and nb != null
	_stat_bars.visible = state in ["to_shop", "to_home", "in_shop", "in_mokki", "in_home", "in_garage", "in_siitari", "in_raahe"]
	_stat_bars.offset_top = 90 if _sus_box.visible else 36
	if _sus_box.visible:
		_sus_bar.value = nb.suspicion


## Repun sisältö (inventory.gd): tavarat kuvakkeineen, eväät (food = true) alariville.
func inventory_items() -> Array:
	var out: Array = []
	var add := func(icon: String, name: String, count: int, desc := "", extra := {}) -> void:
		if count <= 0:
			return
		var it := {"icon": icon, "name": name, "count": count, "desc": desc}
		it.merge(extra)
		out.append(it)
	add.call("kalja", "Kalja", beers, "Jalan jaksaa kantaa %d, pyörän kyytiin mahtuu %d." % [CARRY_FOOT, CARRY_BIKE],
		{"use": "kalja", "use_label": "juo yksi"})
	if has_kanister:
		add.call("kanisteri", "Pontikkakanisteri", 1, "Vastaa kotijemmassa %d kaljaa." % KANISTER_BEERS)
	if has_sausage:
		add.call("makkara_valmis" if sausage_done else "makkara", "Grillimakkara" + (" (paistettu)" if sausage_done else ""), 1,
			"Paistetaan laavulla tai mökin savustimessa.")
	if has_matches:
		add.call("tulitikut", "Tulitikut", 1, "Nuotion sytytykseen.")
	if has_chocolate:
		add.call("suklaa", "Suklaalevy", 1, "Päivin lepytykseen.", {"use": "suklaa", "use_label": "syö"})
	if has_mower_part:
		add.call("varaosa", "Leikkurin varaosa", 1, "Kalja vielä, niin leikkuri korjataan.")
	if has_ball:
		add.call("jalkapallo", "Jalkapallo", 1, "Poikien hukattu pallo.")
	for k in ["kantarelli", "herkkutatti"]:
		add.call(k, k.capitalize(), bucket.get(k, 0), "litraa ämpärissä · Pekka ostaa sienet")
	var catch := {}
	for c in saalis:
		catch[c.nom] = catch.get(c.nom, 0) + 1
	const BIRDS := {"riekko": Color(0.92, 0.9, 0.85), "metso": Color(0.18, 0.18, 0.2), "kyyhky": Color(0.55, 0.58, 0.65)}
	for nom in catch:
		var icon := "kala"
		var tint := Color.WHITE
		if nom == "jänis":
			icon = "janis"
		elif BIRDS.has(nom):
			icon = "lintu"
			tint = BIRDS[nom]
		add.call(icon, str(nom).capitalize(), catch[nom], "Raaka saalis · savustin mökin kesäkeittiössä", {"tint": tint})
	add.call("polkky", "Pölkky", kota_polkyt, "Kodan halkotelineelle.")
	add.call("halko", "Halko", kota_halot, "Kodan pesään.")
	var bought: Dictionary = paivi_bag.duplicate()
	if state == "in_shop":
		bought.merge(interior.bag)
	for prod in bought:
		var col: String = bought[prod]
		add.call("tuote", "%s %s" % [col.capitalize(), prod], 1, "Päivin ostos", {"tint": ShopInterior.COLORS.get(col, Color.GRAY)})
	for k in food:
		var icon: String = {"karrella": "karrella", "suklaa": "suklaa", "mustikkapiirakka": "piirakka"}.get(k, k)
		add.call(icon, FOODS[k].name, food[k], "T syö", {"food": true, "use": k, "use_label": "syö"})
	add.call("viina", "Kätköviina", viina_pullot, "Pulloja mökin metsän kätköistä · T ottaa huikan",
		{"food": true, "use": "viina", "use_label": "ota huikka"})
	for k in ["puolukka", "mustikka"]:
		add.call(k, k.capitalize(), bucket.get(k, 0), "litraa ämpärissä · T syö litran",
			{"food": true, "use": k, "use_label": "syö litra"})
	return out


## Repusta klikattu tarvike (inventory.gd): syödään tai juodaan kuten T-valikosta. Ohjattavan hahmon tila
## (esim. sisätiloissa ulkona odottava kävelijä) palautetaan ennalleen, koska _on_eat vapauttaa ohjauksen.
func use_item(id: String) -> void:
	var w := _active_walker()
	var was: bool = w.controls_enabled
	_on_eat(id)
	w.controls_enabled = was


func inventory_info() -> Dictionary:
	var info := {"money": _eur(money), "lines": [], "list": [], "stashes": []}
	if _at_mokki():
		var mn := _mokki_drone_names()
		info.lines = ["Päivä %d · mökillä" % day, "Kaisuantie 62, Neittävä, Vaala",
			"Koti Saloisissa n. %d km länteen" % roundi(HOME_MOKKI_KM),
			"Droonin ilmakuvat %d / %d" % [_drone_photo_count(mn), mn.size()],
			"Viinakätköt %d / %d" % [viina_found.size(), Mokki.VIINA.size()]]
		if not hommat.reviews.is_empty():
			info.lines.append("Santun arvostelut: %s (%d)" % [Hommat.stars(roundi(hommat.review_avg())), hommat.reviews.size()])
		if hommat.active:
			info.lines.append("Santun hermot: %s %s" % [hommat.bar(), hommat.mood()])
			info.list_title = "Santun hommat"
			for t in hommat.tasks:
				info.list.append(Hommat.TASKS[t].nimi + ("  ✔" if t in hommat.done else ""))
		info.tasks = story.list()
		return info
	info.lines = ["Päivä %d · Järvikuja 1, Saloinen" % day, "Mielihyvä %d · Maine %d" % [roundi(mielihyva), roundi(maine)],
		"Aika: %s" % _time(elapsed), "Droonin ilmakuvat %d / %d" % [_drone_photo_count(DRONE_POIS), DRONE_POIS.size()]]
	if not _list_done:
		# Keskittyminen: palkintona ensimmäisen tuotteen väri näkyy, haittana viimeinen tuote unohtuu listasta.
		var focus: int = tilat.effect("keskittyminen")
		for i in shopping_list.size():
			var it: Array = shopping_list[i]
			var row: String = it[0]
			if focus > 0 and i == 0:
				row = "%s (%s)" % [it[0], it[1]]
			elif focus < 0 and i == shopping_list.size() - 1:
				row = "???"
			info.list.append(row + ("  ✔" if paivi_bag.has(it[0]) or interior.bag.has(it[0]) else ""))
	info.tasks = story.list()
	info.stashes.append("Kotijemma %d / %d%s" % [jemma, JEMMA_GOAL, "  ⚠" if not _risky_stashes().is_empty() else ""])
	for id in STASHES:
		if stash.get(id, 0) > 0:
			info.stashes.append("%s: %d" % [STASHES[id].name.capitalize(), stash[id]])
	return info


func _label(layer: CanvasLayer, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	layer.add_child(l)
	return l


func _centered_label(layer: CanvasLayer, size: int, anchor_y: float, top: float, bottom: float) -> Label:
	var l := _label(layer, size)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_top = top
	l.offset_bottom = bottom
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Viesti jonoon: näytetään, kun edellinen on ehtinyt näkyä loppuun.
func _queue_message(text: String, seconds: float) -> void:
	if _msg_time <= 0.0 and _hud.visible:
		_show_message(text, seconds)
	else:
		_msg_queue.append([text, seconds])


func _show_message(text: String, seconds: float) -> void:
	_msg.text = text
	_msg_time = seconds


func _eur(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")


func _time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


# --- Debug -------------------------------------------------------------------
# `godot --path . -- --shot=/polku/kuva.png [--scene=shop|juntti|wife]`
# ottaa kuvakaappauksen n. 1,5 s jälkeen ja sulkee pelin.

func _maybe_screenshot() -> void:
	var path := ""
	var scene := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			path = arg.substr(7)
		elif arg.begins_with("--scene="):
			scene = arg.substr(8)
	if path.is_empty():
		return
	await get_tree().process_frame
	if scene.begins_with("mokki") or scene == "kuisti":
		var tb := Time.get_ticks_msec()
		mokki.ensure_built()  # testikohtaukset menevät mökille ilman taksia
		print("MOKKI rakennettu %d ms" % (Time.get_ticks_msec() - tb))
	match scene:
		"shop":
			_enter_shop()
			interior.has_beer = true
			interior.walker.set_carrying(true)
			interior.walker.position = interior.QUEUE_FRONT + interior.QUEUE_STEP * 3
			interior._neighbor_t = 0.01
		"juntti":
			player.position = juntti.position + Vector3(0, 0.3, 10)
		"kick":
			player.position = juntti.position + Vector3(0, 0.3, 1.2)
		"wife":
			player.position = wife.position + Vector3(0, 0.3, 14)
			player.rotation.y = PI
		"taxistand":
			if player != walker_out:
				_toggle_mount()
			var shop_c := M.w(M.SHOP_BUILDING)
			print("STAND kauppa=", shop_c, " kauppavyöhyke=", shop_zone - shop_c, " taksi=", world.taxi_pos - shop_c)
			walker_out.global_position = world.taxi_pos + Vector3(8.0, 0.5, -6.0)
			walker_out.rotation.y = B.yaw_to(world.taxi_pos - walker_out.global_position)
		"taxitest":
			# Taksi Raaheen: vihje, menomatka, kädenvääntö (A/D-tahti), paluu ja uusi päivä. Kuvat --shot-kansioon,
			# tallennus palautetaan lopuksi.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var shot := func(name: String) -> void:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.get_base_dir().path_join("taxi_%s.png" % name))
			if player != walker_out:
				_toggle_mount()
			money = 30.0
			walker_out.global_position = world.taxi_pos + Vector3(2.2, 0.5, 1.0)
			walker_out.rotation.y = -PI * 0.5
			for i in 30:
				await get_tree().physics_frame
			await shot.call("parkki")
			print("TAXI hint=", _hint.text)
			await get_tree().process_frame  # kuvakaappauksen jälkeen: painallus seuraavan ruudun alkuun
			Input.action_press("interact")
			for w in 2:
				await get_tree().process_frame
			Input.action_release("interact")
			print("TAXI state=", state, " money=", money)
			await get_tree().create_timer(5.0, true, false, true).timeout
			await shot.call("meno")
			for i in 60:
				await get_tree().create_timer(0.5, true, false, true).timeout
				if state == "in_raahe":
					break
			print("TAXI perillä state=%s msg=%s" % [state, _msg.text])
			var press := func() -> void:
				await get_tree().process_frame
				Input.action_press("interact")
				for w in 2:
					await get_tree().process_frame
				Input.action_release("interact")
				for w in 3:
					await get_tree().process_frame
			raahe_int.walker.position = Vector3(0.0, 0, 1.5)
			await get_tree().create_timer(1.0, true, false, true).timeout
			await shot.call("kulma")
			# Visa: kolme kysymystä, vastataan aina ensimmäiseen vaihtoehtoon.
			raahe_int.walker.position = raahe_int.spots.visa[0]
			for w in 3:
				await get_tree().process_frame
			print("TAXI visa hint=", raahe_int.hint)
			await press.call()
			for qn in 3:
				print("TAXI visa kysymys: ", _quiz[_quiz_i][0], " ", _quiz[_quiz_i][1])
				_item_menu.visible = false  # kuten valikon E-valinta
				_item_menu.chosen.emit("visa_0")
				for w in 3:
					await get_tree().process_frame
			print("TAXI visa tulos=%d msg=%s" % [_raahe.quiz, _msg.text])
			# Tiskiltä tuoppi.
			_on_raahe("tuoppi")
			print("TAXI tuoppi: rahaa %.2f msg=%s" % [money, _msg.text])
			# Kädenvääntö Teron kanssa.
			raahe_int.walker.position = raahe_int.spots.tero[0]
			for w in 3:
				await get_tree().process_frame
			print("TAXI tero hint=", raahe_int.hint)
			await press.call()
			var bar: Node = null
			for c in get_children():
				if c is BarGame:
					bar = c
			if bar == null:
				print("TAXI baaria ei löytynyt")
				get_tree().quit()
				return
			await get_tree().create_timer(1.5, true, false, true).timeout
			await shot.call("baari")
			await get_tree().process_frame
			Input.action_press("interact")
			for w in 2:
				await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().create_timer(3.3, true, false, true).timeout
			var key := "left"
			var n := 0
			var pace := 0.07  # s painallusten välissä (lisäksi 3 ruutua); --pace=0.3 kokeilee hidasta tahtia
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--pace="):
					pace = float(arg.substr(7))
			while bar._phase == "wrestle":
				await get_tree().process_frame  # painallus ruudun alkuun, ei ajastimen jälkeen
				Input.action_press(key)
				for w in 2:
					await get_tree().process_frame
				Input.action_release(key)
				key = "right" if key == "left" else "left"
				await get_tree().create_timer(pace, true, false, true).timeout
				n += 1
				if n == 12:
					await shot.call("vaanto")
					await get_tree().process_frame
			print("TAXI vääntö: kulma=%.2f painalluksia=%d" % [bar._angle, n])
			await get_tree().create_timer(4.0, true, false, true).timeout
			print("TAXI väännön jälkeen: won=%s msg=%s" % [_raahe.won, _msg.text])
			# Kellariin portaita ja kuva karaokesta.
			raahe_int.walker.position = raahe_int.spots.alas[0]
			for w in 3:
				await get_tree().process_frame
			await press.call()
			print("TAXI kellarissa: %s" % raahe_int.in_cellar())
			raahe_int.walker.position = raahe_int.spots.karaoke[0] + Vector3(1.5, 0, -0.5)
			await get_tree().create_timer(1.0, true, false, true).timeout
			await shot.call("kellari")
			# Ylös ja ulos.
			raahe_int.walker.position = raahe_int.spots.ylos[0]
			for w in 3:
				await get_tree().process_frame
			await press.call()
			raahe_int.walker.position = raahe_int.spots.ovi[0]
			for w in 3:
				await get_tree().process_frame
			print("TAXI ovi hint=", raahe_int.hint)
			await press.call()
			await get_tree().create_timer(4.5, true, false, true).timeout
			await get_tree().create_timer(4.0, true, false, true).timeout
			await shot.call("paluu")
			for i in 80:
				await get_tree().create_timer(0.5, true, false, true).timeout
				if i == 6:
					await shot.call("koti")
				if state != "cutscene":
					break
			print("TAXI after state=%s money=%.2f mielihyva=%d maine=%d msg=%s" % [state, money, mielihyva, maine,
				_msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"overview":
			var cam := Camera3D.new()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 1600.0
			cam.far = 3000.0
			add_child(cam)
			cam.global_position = M.w(M.SIZE / 2.0) + Vector3(0, 1200, 0)
			cam.rotation_degrees = Vector3(-90, 0, 0)
			cam.current = true
			$WorldEnvironment.environment.fog_enabled = false
		"route":
			player.position = M.w(Vector2(440, 850)) + Vector3(0, 0.3, 0)
			player.rotation.y = B.yaw_to(M.w(M.J_K) - M.w(Vector2(440, 850)))
		"fight":
			beers = 6
			_on_kicked(Vector3.RIGHT)
			for i in 130:
				await get_tree().process_frame
		"field", "bog":
			var M2 := preload("res://scripts/map_data.gd")
			player.position = M2.w(Vector2(450, 730) if scene == "field" else Vector2(400, 1110)) + Vector3(0, 0.3, 0)
			player.speed = 9.0
		"laavu":
			player.position = M.w(M.LAAVU) + Vector3(0, 0.3, -18)
			player.rotation.y = PI
		"laavufire":
			player.position = M.w(M.LAAVU) + Vector3(-3.0, 0.3, -7.0)
			player.rotation.y = PI - 0.4
			world.fire.visible = true
			guard.mode = "gone"
			guard.visible = false
		"compass", "maptarget":
			# Kompassin kohde K-Marketille (ja lähelle toinen testi: kartta auki).
			_paper.target = M.w2(M.SHOP_ZONE)
			_paper.has_target = true
			if scene == "maptarget":
				_paper.toggle()
		"map":
			for n in find_children("*", "Control", true, false):
				if n.has_method("toggle"):
					n.toggle()
		"bikeside":
			var cam := Camera3D.new()
			cam.fov = 35.0
			player.add_child(cam)
			cam.position = Vector3(3.2, 1.1, 0.1)
			cam.look_at_from_position(player.global_position + Vector3(3.2, 1.1, 0.1), player.global_position + Vector3(0, 0.9, 0), Vector3.UP)
			cam.current = true
			player.speed = 3.0
		"signs":
			player.position = M.w(M.J_K) + Vector3(-1, 0.3, 12)
			player.rotation.y = -0.5
		"signs2":
			player.position = M.w(M.J_H2) + Vector3(-3, 0.3, -10)
			player.rotation.y = PI + 0.3
		"signclose":
			var a2 := M.w2(M.J_K)
			var d2 := (M.w2(Vector2(313, 791)) - a2).normalized()
			var at := a2 + d2 * 8.0 + d2.orthogonal() * 6.2
			var cam := Camera3D.new()
			cam.fov = 45.0
			add_child(cam)
			var eye := Vector3(at.x, 2.0, at.y) + Vector3(d2.orthogonal().x, 0, d2.orthogonal().y) * 2.6 + Vector3(d2.x, 0, d2.y) * 1.4
			cam.look_at_from_position(eye, Vector3(at.x, 2.35, at.y) + Vector3(d2.x, 0, d2.y) * 0.6, Vector3.UP)
			cam.current = true
		"tractor":
			player.position = M.w(Vector2(304, 735)) + Vector3(0, 0.3, 0)
			player.rotation.y = PI / 2.0
		"picktest":
			# Puolukan poiminta: rauhallinen A/D-tahti, sitten räpellys ja pelkkä A. Tallennus palautetaan lopuksi.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			if player != walker_out:
				_toggle_mount()
			var tries := [["tahti 0,25 s", 15], ["räpellys joka ruutu", 1], ["vain A", 15]]
			for tr in tries:
				var berry: Dictionary = {}
				for f in world.forage:
					if not f.taken and f.kind in BERRIES:
						berry = f
						break
				walker_out.global_position = berry.pos + Vector3(0.8, 0.5, 0)
				walker_out.stamina = 100.0
				walker_out.exhausted = false
				for i in 20:
					await get_tree().physics_frame
				Input.action_press("interact")
				for w in 2:
					await get_tree().process_frame
				Input.action_release("interact")
				var t0 := Time.get_ticks_msec()
				var key := "left"
				for n in 400:
					if _pick_t < 0.0:
						break
					Input.action_press(key)
					for w in 2:
						await get_tree().process_frame
					Input.action_release(key)
					if tr[0] != "vain A":
						key = "right" if key == "left" else "left"
					for w in tr[1]:
						await get_tree().process_frame
				print("PICK %s: valmis=%s aika=%.1f s mittari=%.2f kunto=%.0f ämpäri=%s ohjaus=%s" % [tr[0], _pick_t < 0.0,
					(Time.get_ticks_msec() - t0) / 1000.0, _pick_meter, walker_out.stamina, bucket, walker_out.controls_enabled])
				_stop_picking()
			# Sieni: pelkkä odotus, ähkäisy kumartuessa ja noustessa.
			for f in world.forage:
				if not f.taken and not (f.kind in BERRIES):
					walker_out.global_position = f.pos + Vector3(0.8, 0.5, 0)
					break
			for i in 20:
				await get_tree().physics_frame
			Input.action_press("interact")
			for w in 2:
				await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().create_timer(PICK_TIME + 0.5).timeout
			print("PICK sieni: valmis=%s ämpäri=%s" % [_pick_t < 0.0, bucket])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"shoptest":
			_toggle_mount()
			walker_out.global_position = shop_zone + Vector3(1.5, 0.5, 0)
			for i in 30:
				await get_tree().physics_frame
			print("SHOP hint=", _hint.text)
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("SHOP state=", state)
		"kotaview", "kotain", "tower":
			_toggle_mount()
			walker_out.global_position = world.kota.to_global(Vector3(-2.5, 0.4, -9.0))
			walker_out.rotation.y = world.kota.global_rotation.y
			for i in 40:
				await get_tree().process_frame
			var cam3 := Camera3D.new()
			add_child(cam3)
			cam3.fov = 60
			if scene == "kotaview":
				cam3.look_at_from_position(world.kota.to_global(Vector3(-8, 4.5, -13)), world.kota.to_global(Vector3(-1, 1.2, 1)), Vector3.UP)
			elif scene == "kotain":
				cam3.look_at_from_position(world.kota.to_global(Vector3(0.3, 1.5, -2.4)), world.kota.to_global(Vector3(0, 0.7, 1.5)), Vector3.UP)
			else:
				cam3.look_at_from_position(world.kota.to_global(Vector3(-4, 3.0, -8)), world.kota.to_global(Vector3(9, 4, 7)), Vector3.UP)
			cam3.current = true
			if scene == "kotain":
				world.kota.set_fire(true)
				world.kota.say("raimo", "Tässä kodassa on enemmän kieltokylttejä kuin halkoja.")
		"mokkisiitari":
			# Siitari sisältä: _1 yleiskuva, _2 tanssi Sinikan kanssa, _3 karaoke kesken, _4 Päivin puhelu.
			_start_mopo()
			var mp: CharacterBody3D = mopo_trip.mopo
			mp.position = mopo_trip.vaala.siitari_park + Vector3(0, 0.5, 0)
			for i in 10:
				await get_tree().physics_frame
			mopo_trip.stop()
			_on_mopo_arrived()
			money = 30.0
			tilat.add("humala", 0.3)
			var snap := func(name: String) -> void:
				for i in 30:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			siitari_int.walker.position = Vector3(0.5, 0, 1.0)
			await snap.call("_1.png")
			print("SIITARI tila %s hint '%s'" % [state, _hint.text])
			siitari_int.walker.position = siitari_int.spots.sinikka[0]
			for i in 5:
				await get_tree().process_frame
			print("SIITARI Sinikan luona hint '%s'" % _hint.text)
			_on_siitari_acted("sinikka")
			print("SIITARI valikko auki %s" % _item_menu.is_open())
			_item_menu.hide()
			_on_siitari("sinikka_tanssi")
			await snap.call("_2.png")
			await get_tree().create_timer(7.5).timeout
			print("SIITARI tanssi ohi: ohjaus %s, puhelu %.1f s" % [siitari_int.walker.controls_enabled, _paivi_call_t])
			siitari_int.walker.position = siitari_int.spots.karaoke[0]
			_on_siitari_acted("karaoke")
			Input.action_press("forward")
			await get_tree().create_timer(4.0).timeout
			Input.action_release("forward")
			await snap.call("_3.png")
			await get_tree().create_timer(26.0).timeout
			print("SIITARI karaoke ohi, viesti: %s | rahaa %.2f" % [_msg.text, money])
			await get_tree().create_timer(4.5).timeout
			await snap.call("_4.png")
			print("SIITARI viesti: %s" % _msg.text)
			siitari_int.walker.position = siitari_int.spots.ovi[0]
			for i in 5:
				await get_tree().process_frame
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			for i in 30:
				await get_tree().physics_frame
			print("SIITARI ulos: tila %s, mopo kohde %s aktiivinen %s" % [state, mopo_trip.target, mopo_trip.active])
			get_tree().quit()
		"mokkilava":
			# Oulujärven lava: mopo ovelle (vihje), ulkokuva, lavatanssit (kuva), lopetus ja takaisin mopolle.
			_start_mopo()
			var vl2: Node3D = mopo_trip.vaala
			var mpl: CharacterBody3D = mopo_trip.mopo
			mpl.position = vl2.lava_door + Vector3(0, 0.6, 0)
			mpl.speed = 0.0
			money = 40.0
			for i in 30:
				await get_tree().process_frame
			print("LAVA ovi ", vl2.lava_door, " keskus ", vl2.lava_center, " vihje: ", mopo_trip.hint)
			var lc := Camera3D.new()
			lc.far = 3000.0
			add_child(lc)
			lc.look_at_from_position(mopo_trip.to_global(vl2.lava_door + vl2.lava_out * 30.0 + Vector3(-25, 18, 30)),
				mopo_trip.to_global(vl2.lava_center))
			lc.current = true
			for i in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_ulko.png"))
			_enter_lava()
			for i in 20:
				await get_tree().process_frame
			_lava_game._phase = "dance"
			_lava_game._me.play("Dance", 0.2)
			_lava_game._partner.play("Dance", 0.2)
			_lava_game._hits = 20
			for i in 60:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_tanssi.png"))
			_lava_game._t = LavaGame.SONG
			for i in 5:
				await get_tree().process_frame
			var m0 := mielihyva
			_lava_game.finished.emit(_lava_game._score())
			for i in 10:
				await get_tree().process_frame
			print("LAVA ohi: tila %s, rahaa %.2f, mielihyvä %.1f -> %.1f, mopo aktiivinen %s" % [state, money, m0, mielihyva, mopo_trip.active])
		"mokkivaalajalan":
			# Moposta jalan (F) lavan pihassa, kävely ovelle (vihje), rantaan (ei veteen), takaisin mopolle ja selkään.
			_start_mopo()
			var vl: Node3D = mopo_trip.vaala
			var mp: CharacterBody3D = mopo_trip.mopo
			for car in mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
			var press := func(action: String) -> void:
				await get_tree().process_frame  # painallus ennen solmujen _processia (just_pressed samassa ruudussa)
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			mp.position = vl.lava_door + vl.lava_out * 12.0 + Vector3(0, 0.6, 0)
			mp.rotation.y = atan2(vl.lava_out.x, vl.lava_out.z)  # selkä ovelle päin
			for i in 20:
				await get_tree().physics_frame
			await press.call("mount")
			print("JALAN: kävelijä %s, näkyvissä %s, kuski mopolla %s, status '%s'" % [mopo_trip.on_foot != null, walker_out.visible,
				mp._rider.visible, mopo_trip.status.replace("\n", " | ")])
			var walk_to := func(goal_local: Vector3, secs: float) -> void:
				Input.action_press("forward")
				for i in int(60 * secs):
					await get_tree().physics_frame
					var g: Vector3 = mopo_trip.to_global(goal_local)
					var want := Vector3(g.x - walker_out.global_position.x, 0, g.z - walker_out.global_position.z)
					if want.length() < 1.2:
						break
					var err := (-walker_out.global_transform.basis.z).signed_angle_to(want, Vector3.UP)
					Input.action_press("left", clampf(err * 3.0, 0.0, 1.0))
					Input.action_press("right", clampf(-err * 3.0, 0.0, 1.0))
				for a in ["forward", "left", "right"]:
					Input.action_release(a)
				for i in 10:
					await get_tree().process_frame
			await walk_to.call(vl.lava_door, 12.0)
			print("JALAN ovella: %.1f m, vihje '%s'" % [mopo_trip.to_local(walker_out.global_position).distance_to(vl.lava_door), _hint.text])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_ovi.png"))
			money = 50.0
			await press.call("interact")
			print("JALAN lavalle: tila %s, kävelijä näkyvissä %s, viesti %s" % [state, walker_out.visible, _msg.text])
			if _lava_game != null:
				_lava_game.finished.emit(0.5)
				for i in 5:
					await get_tree().process_frame
			print("JALAN lavalta: tila %s, kävelijä näkyvissä %s, ohjaus %s, mopo ohjaus %s" % [state, walker_out.visible,
				walker_out.controls_enabled, mp.controls_enabled])
			# Rantaan: ensimmäinen vesi lavan etelänpuolella, kävelijä 4 m rannasta kohti vettä.
			var shore: Vector3 = vl.lava_center
			while vl.h(shore.x, shore.z) > vl.water_level - 0.3:
				shore.z += 1.0
			walker_out.global_position = mopo_trip.to_global(shore + Vector3(0, 0, -6))
			walker_out.global_position.y = mopo_trip.to_global(Vector3(0, vl.h(shore.x, shore.z - 6.0) + 0.4, 0)).y
			await walk_to.call(shore + Vector3(0, 0, 20), 6.0)
			var lp: Vector3 = mopo_trip.to_local(walker_out.global_position)
			print("JALAN rannassa: maa %.2f, vedenpinta %.2f, vihje '%s'" % [vl.h(lp.x, lp.z), vl.water_level, _hint.text])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_ranta.png"))
			walker_out.global_position = mp.global_position + Vector3(4, 0.3, 0)
			await walk_to.call(mp.position, 5.0)
			print("JALAN mopolla: %.1f m, vihje '%s'" % [walker_out.global_position.distance_to(mp.global_position), _hint.text])
			await press.call("mount")
			print("SELKÄÄN: kävelijä %s, ohjaus %s, näkyvissä %s, kuski mopolla %s" % [mopo_trip.on_foot != null, mp.controls_enabled,
				walker_out.visible, mp._rider.visible])
			get_tree().quit()
		"mokkivaalalava":
			# Oulujärven lava niemen kärjessä: _yla ylhäältä (joki ja järvi), _tie Vuolijoentieltä, _aita aita rannasta
			# rantaan, _ranta järveltä päin, _ovi ovelta.
			_start_mopo()
			var vl: Node3D = mopo_trip.vaala
			_msg.text = ""
			var oc := Camera3D.new()
			oc.far = 3000.0
			oc.fov = 62.0
			add_child(oc)
			var c: Vector3 = vl.lava_center
			var snap := func(name: String, from: Vector3, to: Vector3) -> void:
				oc.look_at_from_position(mopo_trip.to_global(from), mopo_trip.to_global(to))
				oc.current = true
				for i in 20:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			var lv: Dictionary = vl.data.lava
			var rp: Array = lv.road
			var junc := Vector3(rp[0][0], 0, rp[0][1])
			junc.y = vl.h(junc.x, junc.z)
			await snap.call("_yla.png", c + Vector3(-60, 260, 160), c + Vector3(30, 0, -60))
			await snap.call("_tie.png", junc + Vector3(-4, 3, 0), c + Vector3(0, 2, 0))
			await snap.call("_aita.png", c + Vector3(-70, 25, -70), c + Vector3(0, 0, -10))
			await snap.call("_ranta.png", c + Vector3(20, 6, 120), c)
			await snap.call("_ovi.png", vl.lava_door + vl.lava_out * 20.0 + Vector3(0, 3, 12), vl.lava_door + Vector3(0, 1.5, 0))
			var gt := Vector3(lv.gate[0], 0, lv.gate[1])
			gt.y = vl.h(gt.x, gt.z)
			await snap.call("_portti.png", gt + Vector3(-6, 2.5, -22), gt + Vector3(0, 1, 0))
			await snap.call("_pihat.png", c + Vector3(10, 120, 1), c + Vector3(10, 0, 0))
			var fw: Array = lv.fence[2]
			var fe: Array = lv.fence[0]
			await snap.call("_lansi.png", Vector3(fw[0] - 40, vl.water_level + 5, fw[1] - 25), Vector3(fw[0], vl.water_level, fw[1] - 10))
			await snap.call("_ita.png", Vector3(fe[0] + 30, vl.water_level + 4, fe[1] - 35), Vector3(fe[0] - 5, vl.water_level, fe[1]))
			await snap.call("_joki.png", c + Vector3(150, 40, -300), c + Vector3(80, 0, 100))
			# Mopolla Pahalahdentieltä portista lavan ovelle, sitten aitaa päin portin vierestä (aidan pitää pysäyttää).
			var mp: CharacterBody3D = mopo_trip.mopo
			for car in mopo_trip._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
			var drive := func(from: Vector3, goals: Array, secs: float) -> void:
				mp.position = from + Vector3(0, 0.6, 0)
				var d0: Vector3 = (goals[0] - from).normalized()
				mp.rotation.y = atan2(-d0.x, -d0.z)
				mp.speed = 4.0
				mp.activate_camera()
				var gi := 0
				Input.action_press("forward", 0.6)
				for i in int(60 * secs):
					await get_tree().physics_frame
					var goal: Vector3 = goals[gi]
					if gi < goals.size() - 1 and Vector2(mp.position.x - goal.x, mp.position.z - goal.z).length() < 4.0:
						gi += 1
					var want := Vector3(goal.x - mp.position.x, 0, goal.z - mp.position.z)
					var err := (-mp.global_transform.basis.z).signed_angle_to(want, Vector3.UP)
					Input.action_press("left", clampf(err * 3.0, 0.0, 1.0))
					Input.action_press("right", clampf(-err * 3.0, 0.0, 1.0))
				for a in ["forward", "left", "right"]:
					Input.action_release(a)
			# Pahalahdentie: 30 m ennen porttia, portin läpi, ajotien alkuun ja ovelle.
			var pr: Array = []
			for r in vl.data.side_roads:
				if r.get("name", "") == "Pahalahdentie":
					for q in r.pts:
						pr.append(Vector3(q[0], vl.h(q[0], q[1]), q[1]))
			var gk := 0
			for k in pr.size():
				if pr[k].distance_to(gt) < pr[gk].distance_to(gt):
					gk = k
			var rp0: Vector3 = Vector3(rp[0][0], 0, rp[0][1])
			await drive.call(pr[maxi(gk - 5, 0)], pr.slice(gk - 3) + [rp0, vl.lava_door + vl.lava_out * 5.0], 16.0)
			for i in 30:
				await get_tree().physics_frame
			print("LAVA portista: ovelta %.1f m, vihje '%s'" % [mp.position.distance_to(vl.lava_door), mopo_trip.hint])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_mopo.png"))
			# Aitaa päin 20 m portista länteen (pohjoisesta etelään).
			var beside := gt + Vector3(-20, 0, 0)
			beside.y = vl.h(beside.x, beside.z)
			await drive.call(beside + Vector3(0, 0, -6), [beside + Vector3(0, 0, 20)], 5.0)
			print("LAVA aitaa päin: aidan pohjoispuolella %.1f m (negatiivinen = läpi)" % (beside.z - mp.position.z))
			get_tree().quit()
		"mokkivaalakartta":
			# Neittävä–Vaala-kartta (M) mopolla lavan luona: koko alue, keskusta lähempää ja mökin piha.
			_start_mopo()
			mopo_trip.mopo.position = mopo_trip.vaala.lava_door + Vector3(0, 0.6, 0)
			for i in 10:
				await get_tree().process_frame
			_paper.toggle()
			var views := [["_koko.png", Vector2.ZERO, 0.0], ["_keskusta.png", Vector2(1100, -1150), 1.0],
				["_lava.png", Vector2(560, -500), 2.0], ["_mokki.png", Vector2(0, 0), 2.5]]
			for vw in views:
				if vw[2] > 0.0:
					_paper._vcenter = vw[1]
					_paper._vzoom = vw[2]
				_paper._view.queue_redraw()
				_paper.queue_redraw()
				for i in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", vw[0]))
			_paper.toggle()
		"mokkikauppa":
			# K-Market Tervaportti Vaalassa: mopo oven eteen (vihje), kauppaan, Alkon hylly, ulos ja takaisin mopolle.
			_start_mopo()
			var vk: Node3D = mopo_trip.vaala
			var mpk: CharacterBody3D = mopo_trip.mopo
			mpk.position = vk.kmarket_door + Vector3(0, 0.6, 0)
			mpk.speed = 0.0
			for i in 30:
				await get_tree().process_frame
			print("VAALAKAUPPA ovi ", vk.kmarket_door, " automaatti ", vk.atm_pos, " vihje: ", mopo_trip.hint)
			var occ := Camera3D.new()
			add_child(occ)
			occ.look_at_from_position(mopo_trip.to_global(vk.kmarket_door + vk.kmarket_out * 14.0 + Vector3(0, 5, 0)),
				mopo_trip.to_global(vk.kmarket_door))
			occ.current = true
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_ulko.png"))
			_enter_vaala_shop()
			interior.walker.position = ShopInterior.ALKO_SPOT
			interior.walker.rotation.y = PI / 2.0
			for i in 40:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_alko.png"))
			print("VAALAKAUPPA alkon vihje: ", interior.hint)
			interior.cart["viina0"] = ShopInterior.ALKO[1]
			interior.has_beer = true
			interior.has_paid = true
			var pullot0 := viina_pullot
			interior.exited.emit(true)
			for i in 10:
				await get_tree().process_frame
			print("VAALAKAUPPA ulos: tila %s, pulloja %d -> %d, kaljoja %d, mopo aktiivinen %s" % [state, pullot0, viina_pullot,
				beers, mopo_trip.active])
			# Juoksukaljat: rahat loppu, kuutonen ja pullo ovesta maksamatta.
			money = 1.0
			_enter_vaala_shop()
			interior.has_beer = true
			interior.cart["viina0"] = ShopInterior.ALKO[1]
			interior.cart["makkara"] = 3.0
			interior.walker.position = ShopInterior.DOOR
			Input.action_press("interact")
			for i in 3:
				await get_tree().process_frame
			Input.action_release("interact")
			for i in 10:
				await get_tree().process_frame
			print("VAALAKAUPPA juoksukaljat: tila %s, raha %.2f, pulloja %d, kaljoja %d, makkara %s, viesti '%s'" % [state, money,
				viina_pullot, beers, has_sausage, _msg.text.replace("\n", " | ")])
		"mokkivaalakesk":
			# Vaalan keskusta Siitarin ympäriltä: _y ylhäältä, _n/_e/_s/_w 45 m päästä viistosti, _tie Vaalantieltä,
			# _ovi Siitarin ovelta ja _kauppa K-Marketin edestä (automaatti).
			_start_mopo()
			var vl: Node3D = mopo_trip.vaala
			_msg.text = ""
			var oc := Camera3D.new()
			oc.far = 3000.0
			oc.fov = 62.0
			add_child(oc)
			var snap := func(name: String, from: Vector3, to: Vector3) -> void:
				oc.look_at_from_position(mopo_trip.to_global(from), mopo_trip.to_global(to))
				oc.current = true
				for i in 20:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			var sc := Vector3(vl.siitari.x, vl.siitari_door.y, vl.siitari.y)
			await snap.call("_y.png", sc + Vector3(0, 140, 60), sc)
			for d in [["_n", Vector3(0, 0, -1)], ["_e", Vector3(1, 0, 0)], ["_s", Vector3(0, 0, 1)], ["_w", Vector3(-1, 0, 0)]]:
				await snap.call(d[0] + ".png", sc + d[1] * 45.0 + Vector3(0, 18, 0), sc + Vector3(0, 2, 0))
			var ni: int = vl.nearest(sc)[0]
			await snap.call("_tie.png", vl.road_pos(ni - 15) + Vector3(0, 1.7, 0), vl.road_pos(ni + 5) + Vector3(0, 1.5, 0))
			await snap.call("_tie2.png", vl.road_pos(ni + 15) + Vector3(0, 1.7, 0), vl.road_pos(ni - 5) + Vector3(0, 1.5, 0))
			var so: Vector3 = Vector3(sin(vl.siitari_yaw), 0, cos(vl.siitari_yaw))
			await snap.call("_ovi.png", vl.siitari_door + so * 14.0 + Vector3(0, 2.5, 0), vl.siitari_door + Vector3(0, 1.5, 0))
			if vl.kmarket_door != Vector3.ZERO:
				await snap.call("_kauppa.png", vl.kmarket_door + vl.kmarket_out * 16.0 + Vector3(0, 4, 0), vl.kmarket_door)
				await snap.call("_otto.png", vl.atm_pos + vl.kmarket_face * 3.0 + Vector3(0, 1.6, 0), vl.atm_pos + Vector3(0, 1.3, 0) - vl.kmarket_face * 1.2)
				await snap.call("_otto_kaukaa.png", (vl.atm_pos + vl.kmarket_door) / 2.0 + vl.kmarket_face * 22.0 + Vector3(0, 4.0, 0), (vl.atm_pos + vl.kmarket_door) / 2.0 + Vector3(0, 1.0, 0))
				await snap.call("_valilla.png", vl.kmarket_door + Vector3(0, 30, 0) + (sc - vl.kmarket_door) * -0.3,
					(sc + vl.kmarket_door) / 2.0)
			print("VAALAKESK siitari %s kauppa %s automaatti %s, väli %.0f m" % [sc, vl.kmarket_door, vl.atm_pos,
				Vector2(sc.x - vl.kmarket_door.x, sc.z - vl.kmarket_door.z).length()])
			get_tree().quit()
		"mokkivaala":
			# Vaalan kohteet kuviksi (_ali1 alikulku lähestyttäessä, _ali2 sivulta, _ali3 mopo alikulussa, _ris
			# Vuolijoentien risteys, _kesk keskusta ylhäältä, _kirkko, _asema, _talot omakotitaloja läheltä).
			_start_mopo()
			var mp: CharacterBody3D = mopo_trip.mopo
			var vl: Node3D = mopo_trip.vaala
			_msg.text = ""
			var oc := Camera3D.new()
			oc.far = 3000.0
			oc.fov = 62.0
			add_child(oc)
			var g := func(v: Vector3) -> Vector3: return mopo_trip.to_global(v)
			var snap := func(name: String, from: Vector3, to: Vector3) -> void:
				oc.look_at_from_position(g.call(from), g.call(to))
				oc.current = true
				for i in 20:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			var ui: int = vl.underpass_i
			var up: Vector3 = vl.road_pos(ui)
			var ud: Vector3 = vl.road_dir(ui)
			var ur := ud.cross(Vector3.UP)
			await snap.call("_ali1.png", vl.road_pos(ui - 25) + Vector3(0, 2.2, 0) + ur * 1.6, up + Vector3(0, 2.5, 0))
			await snap.call("_ali2.png", up + ur * 40.0 - ud * 25.0 + Vector3(0, 14, 0), up + Vector3(0, 2, 0))
			await snap.call("_ali4.png", up + Vector3(0, 3.0, 0) - ud * 0.5, up + ud * 0.5)
			mp.position = vl.road_pos(ui - 4) + Vector3(0, 0.6, 0) + ur * 1.6
			mp.rotation.y = atan2(-ud.x, -ud.z)
			mp.speed = 8.0
			for i in 40:
				await get_tree().physics_frame
			print("VAALA alikulussa: y %.2f tie %.2f, nopeus %.1f, näyte %d (alikulku %d)" % [mp.position.y, vl.h(mp.position.x, mp.position.z),
				mp.speed * 3.6, vl.nearest(mp.position)[0], ui])
			mp.activate_camera()
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_ali3.png"))
			var js: int = vl.data.signs[2].i
			await snap.call("_ris.png", vl.road_pos(js - 30) + Vector3(0, 30, 0), vl.road_pos(js + 5))
			var sc := Vector3(vl.siitari.x, vl.siitari_door.y, vl.siitari.y)
			await snap.call("_kesk.png", sc + Vector3(-160, 120, 160), sc + Vector3(40, 0, -40))
			for bd in vl.data.buildings:
				var nm: String = bd.name
				if nm.contains("kirkko") or bd.type == "train_station":
					var c := Vector2.ZERO
					for q in bd.pts:
						c += Vector2(q[0], q[1])
					c /= bd.pts.size()
					var cy: float = vl.h(c.x, c.y)
					await snap.call("_kirkko.png" if nm.contains("kirkko") else "_asema.png", Vector3(c.x + 35, cy + 14, c.y + 35), Vector3(c.x, cy + 6, c.y))
			var shots_done := {}
			for bd in vl.data.buildings:
				var key: String = bd.kind if bd.kind != "big" else "big%d" % (absi(int(bd.id)) % 3)
				if shots_done.has(key) or key == "shed" or bd.name != "":
					continue
				shots_done[key] = true
				var c := Vector2.ZERO
				for q in bd.pts:
					c += Vector2(q[0], q[1])
				c /= bd.pts.size()
				var cy: float = vl.h(c.x, c.y)
				await snap.call("_lahi_%s.png" % key, Vector3(c.x + 9, cy + 4, c.y + 9), Vector3(c.x, cy + 2.5, c.y))
			var hi: int = vl.nearest(sc)[0] - 60
			await snap.call("_talot.png", vl.road_pos(hi) + Vector3(0, 3, 0), vl.road_pos(hi + 20) + Vector3(0, 2, 0))
			get_tree().quit()
		"mokkimopo_silta", "mokkimopo_kanni":
			# mokkimopo_silta: oikealla kaistalla täysillä Oulujoen sillan yli (ei porrasta sillan päissä), kuva kannelta.
			# mokkimopo_kanni: humala 0,8, kaasu pohjassa ilman ohjausta: kuinka pian mopo on ojassa.
			var kanni := scene == "mokkimopo_kanni"
			tilat.add("humala", -1.0)
			if kanni:
				tilat.add("humala", 0.8)
			_start_mopo()
			var mp: CharacterBody3D = mopo_trip.mopo
			var vl: Node3D = mopo_trip.vaala
			var crashes := [0]
			print("MOPO humala %.2f" % mp.drunk)
			mopo_trip.crashed.connect(func(r: String) -> void:
				crashes[0] += 1
				print("MOPO kumoon (%s) näyte %d" % [r, vl.nearest(mp.position)[0]]))
			var b0 := int(vl.data.bridges[0][0])
			var si := b0 - 30 if not kanni else 480
			for car in mopo_trip._cars:  # ilman liikennettä: mitataan pelkkää ajamista
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var d: Vector3 = vl.road_dir(si)
			mp.position = vl.road_pos(si) + Vector3(0, 0.6, 0) + d.cross(Vector3.UP) * 1.6
			mp.rotation.y = atan2(-d.x, -d.z)
			mp.speed = 12.0
			Input.action_press("forward")
			for i in 60 * 12:
				await get_tree().physics_frame
				if not kanni:
					# Pidä oikea kaista: ohjaa kohti kaistan keskiviivaa.
					var ni: Array = vl.nearest(mp.position)
					var lane: Vector3 = vl.road_pos(ni[0] + 3) + vl.road_dir(ni[0] + 3).cross(Vector3.UP) * 1.6
					var want := Vector3(lane.x - mp.position.x, 0, lane.z - mp.position.z)
					var err := (-mp.global_transform.basis.z).signed_angle_to(want, Vector3.UP)
					Input.action_press("left", clampf(err * 3.0, 0.0, 1.0))
					Input.action_press("right", clampf(-err * 3.0, 0.0, 1.0))
				if i % 60 == 0:
					print("MOPO %2d s: näyte %d, %.1f km/h, y %.2f, tiestä %.1f m, pinta %d, seinä %s, ohjaus %s, kaatunut %s" % [i / 60, vl.nearest(mp.position)[0], mp.speed * 3.6, mp.position.y,
						vl.nearest(mp.position)[1], vl.code_at(mp.position.x, mp.position.z), mp.is_on_wall(), mp.controls_enabled, mp.fallen])
				if not kanni and vl.nearest(mp.position)[0] == b0 + 10:
					Input.action_release("forward")
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(path)
			Input.action_release("forward")
			print("MOPO loppu: näyte %d (silta %s), kaatumisia %d" % [vl.nearest(mp.position)[0], vl.data.bridges[0], crashes[0]])
			if kanni:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()
		"mokkilahto":
			# Mopomatkan lähtö: _1 mökin mopopaikalta (pelaaja jalan, mopo parkissa), _2 heti kartan vaihduttua
			# mopon kameralla, _3 ylhäältä Vaalan lähtöpaikasta, _4 mökin piha ylhäältä vertailuun.
			_toggle_mount()
			walker_out.global_position = mokki.gpos(Mokki.MOPO_LOCAL + Vector3(1.0, 0.5, 0.0))
			walker_out.rotation.y = mokki.rotation.y + PI * 0.9
			var shot := func(name: String) -> void:
				for i in 40:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			_msg.text = ""
			_note.visible = false
			await shot.call("_1.png")
			var top := Camera3D.new()
			top.far = 2000.0
			add_child(top)
			top.look_at_from_position(mokki.gpos(Mokki.MOPO_LOCAL) + Vector3(0, 45, 35), mokki.gpos(Mokki.MOPO_LOCAL))
			top.current = true
			await shot.call("_4.png")
			_start_mopo()
			_msg.text = ""
			_note.visible = false
			await shot.call("_2.png")
			var mp: CharacterBody3D = mopo_trip.mopo
			top.look_at_from_position(mp.global_position + Vector3(0, 45, 35), mp.global_position)
			top.current = true
			await shot.call("_3.png")
			print("LAHTO mopo vaalassa ", mopo_trip.to_local(mp.global_position), " näyte ", mopo_trip._sample, " ", mopo_trip.status.replace("\n", " | "))
		"mokkiviina":
			# Viinakätköjen etäisyys lähimpään rakennukseen (negatiivinen = sisällä) ja korkeus maasta.
			var data: Dictionary = Mokki.map_data()
			var vp: Array[Vector2] = Mokki.viina_positions()
			for i in vp.size():
				var p: Vector2 = vp[i]
				var best := INF
				for bd in data.buildings:
					var poly: PackedVector2Array = bd.poly
					if poly.size() < 3:
						continue
					var d := INF
					for k in poly.size():
						var c := Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()])
						d = minf(d, p.distance_to(c))
					if Geometry2D.is_point_in_polygon(p, poly):
						d = -d
					best = minf(best, d)
				var e := 1.5
				var sl := rad_to_deg(atan(Vector2(Mokki.h(p.x + e, p.y) - Mokki.h(p.x - e, p.y), Mokki.h(p.x, p.y + e) - Mokki.h(p.x, p.y - e)).length() / (2.0 * e)))
				print("VIINA %d %s: lähin rakennus %.1f m, rinne %.0f°" % [i, p, best, sl])
		"kieltokyltti":
			# Kodan polun keltainen kieltokyltti: lähikuva edestä ja polulta tulijan silmin.
			print("KYLTTI ", world.waste_sign != null, " paikka ", world.waste_sign.global_position if world.waste_sign else Vector3.ZERO,
				" kodalle %.0f m" % (world.waste_sign.global_position.distance_to(world.kota.global_position) if world.waste_sign else -1.0))
			if world.waste_sign == null:
				return
			_note.visible = false
			_hud.visible = false
			var ws: Node3D = world.waste_sign
			var cam := Camera3D.new()
			add_child(cam)
			cam.current = true
			cam.fov = 60.0
			for v in [["lahi", Vector3(0.3, 1.4, 3.0), Vector3(0, 1.25, 0)], ["polku", Vector3(-1.5, 1.7, 9.0), Vector3(0, 1.0, 0)]]:
				cam.global_position = ws.to_global(v[1])
				cam.look_at(ws.to_global(v[2]), Vector3.UP)
				for i in 20:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % v[0]))
		"autotalli":
			# Autotalli: sisään kaljat kädessä, työkalukaappiin, radio, arkku, karburaattori (kuva + pakotettu
			# onnistuminen), ulos; pyörä talliin, huolto ja ulos pyörällä; eteisen kaappi kodin sisällä.
			if player == bike:
				_toggle_mount()
			var press := func(action: String) -> void:
				await get_tree().process_frame
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			var frames := func(n: int) -> void:
				for i in n:
					await get_tree().physics_frame
			var gstash: int = stash.get("autotalli", 0)
			beers = 3
			walker_out.global_position = world.garage_door + world.garage_out * 0.4 + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("TALLI ovella: hint '%s'" % _hint.text)
			await press.call("interact")
			print("TALLI sisään: tila %s" % state)
			garage_int.walker.position = GarageInterior.SPOTS.kaappi[0]
			await frames.call(5)
			print("TALLI kaappi: hint '%s'" % _hint.text)
			await press.call("interact")
			await press.call("interact")
			print("TALLI kaappiin: jemma %d -> %d, kaljat %d" % [gstash, stash.get("autotalli", 0), beers])
			garage_int.walker.position = GarageInterior.SPOTS.radio[0]
			await frames.call(5)
			await press.call("interact")
			print("TALLI radio: päällä %s, viesti '%s'" % [garage_int.radio_on, _msg.text])
			garage_int.walker.position = GarageInterior.SPOTS.arkku[0]
			await frames.call(5)
			var v0 := viina_pullot
			await press.call("interact")
			print("TALLI arkku: viina %d -> %d, viesti '%s'" % [v0, viina_pullot, _msg.text])
			garage_int.walker.position = Vector3(0.6, 0, 3.0)
			await frames.call(10)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_talli.png"))
			garage_int.walker.position = GarageInterior.SPOTS.auto[0]
			await frames.call(5)
			await press.call("interact")
			var cg: Node = get_children().filter(func(c): return c is CarbGame).front()
			print("TALLI karburaattori auki: %s" % [cg != null])
			await get_tree().create_timer(1.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_karbu.png"))
			if cg != null:
				cg._mix_ok = cg._mix
				cg._idle_ok = cg._idle
				await get_tree().create_timer(4.0).timeout
			print("TALLI karburaattori: peli ohi %s, viesti '%s'" % [not is_instance_valid(cg), _msg.text])
			garage_int.walker.position = GarageInterior.SPOTS.ovi[0]
			await frames.call(5)
			await press.call("interact")
			print("TALLI ulos: tila %s, etäisyys ovesta %.1f m" % [state, walker_out.global_position.distance_to(world.garage_door)])
			# Pyörä talliin ja ulos.
			bike.global_position = world.garage_door + world.garage_out * 2.5 + Vector3(0, 0.4, 0)
			walker_out.global_position = bike.global_position + Vector3(1.0, 0, 0)
			beers = 0
			await frames.call(5)
			_toggle_mount()
			bike.global_position = world.garage_door + world.garage_out * 0.5 + Vector3(0, 0.4, 0)
			await frames.call(10)
			print("TALLI pyörällä ovella: hint '%s'" % _hint.text)
			await press.call("interact")
			print("TALLI pyörä talliin: tila %s, tallissa %s, näkyy %s" % [state, bike_in_garage, bike.visible])
			garage_int.walker.position = GarageInterior.SPOTS.tyopoyta[0]
			await frames.call(5)
			await press.call("interact")
			print("TALLI huolto: tune %.2f viesti '%s'" % [bike.tune, _msg.text])
			garage_int.walker.position = GarageInterior.SPOTS.pyora[0]
			await frames.call(5)
			print("TALLI pyörän luona: hint '%s'" % _hint.text)
			await press.call("interact")
			print("TALLI ulos pyörällä: tila %s, pyörän selässä %s, tallissa %s" % [state, player == bike, bike_in_garage])
			# Eteisen kaappi sisällä.
			_toggle_mount()
			beers = 2
			var hstash: int = stash.get("koti", 0)
			walker_out.global_position = home_door + Vector3(0, 0.3, 0)
			await frames.call(10)
			print("ETEINEN ovella: hint '%s'" % _hint.text)
			await press.call("interact")
			print("ETEINEN sisään: tila %s, kantaa %s" % [state, home_int.carrying])
			home_int.walker.position = Vector3(1.5, 0, -2.5)
			await frames.call(5)
			print("ETEINEN keittiöön kaljoineen: paikka %s hint '%s'" % [home_int.walker.position, _hint.text])
			home_int.walker.position = HomeInterior.SPOTS.kaappi[0]
			await frames.call(5)
			print("ETEINEN kaapilla: hint '%s'" % _hint.text)
			await press.call("interact")
			await press.call("interact")
			home_int.walker.position = Vector3(1.5, 0, -2.5)
			await frames.call(5)
			print("ETEINEN kaappiin: jemma %d -> %d, kaljat %d, keittiöön pääsi %s" % [hstash, stash.get("koti", 0), beers,
				home_int.walker.position.distance_to(Vector3(1.5, 0, -2.5)) < 0.5])
		"karhukuva":
			# Karhun lähikuvat: kävely sivulta, pystyyn nousu ja karjaisu edestä, laukka sivulta.
			if player == bike:
				_toggle_mount()
			_note.visible = false
			_hud.visible = false
			var c0 := walker_out.global_position + Vector3(6, 0, 6)
			var b := Beast.new()
			b.kind = "karhu"
			b.target = walker_out
			add_child(b)
			b.place(c0)
			b.set_physics_process(false)
			b.rotation.y = 0.0
			var cam := Camera3D.new()
			add_child(cam)
			cam.current = true
			var shoot := func(name: String, phase: String, speed: float, t: float, secs: float, from: Vector3) -> void:
				b.phase = phase
				b._speed = speed
				b._t = t
				var n := int(secs * 60.0)
				for i in n:
					b._t += 1.0 / 60.0
					b._animate(1.0 / 60.0)
					await get_tree().process_frame
				cam.look_at_from_position(b.global_position + from, b.global_position + Vector3(0, 0.9, 0), Vector3.UP)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % name))
			await shoot.call("kavely", "approach", 2.2, 0.0, 0.6, Vector3(-4.2, 1.2, -0.8))
			b._roar()
			await shoot.call("pysty", "standoff", 0.0, 0.0, 1.4, Vector3(-1.5, 1.5, -4.0))
			b._roar()
			await shoot.call("karjaisu", "standoff", 0.0, 5.0, 0.6, Vector3(-0.8, 1.1, -2.6))
			await shoot.call("laukka", "charge", 9.0, 0.0, 0.37, Vector3(-4.5, 1.0, -0.5))
		"pedot":
			# Metsän pedot: karhu ja paikallaan seisominen (luopuu), karhu ja juoksu (raatelee, iso haava, eväät),
			# susi ja huuto kasvokkain (pakenee), Santun hoito, mökin metsän tunnistus. Kuva karhusta.
			if player == bike:
				_toggle_mount()
			var spot := Vector3.INF
			var p0 := walker_out.global_position
			for r in range(40, 900, 20):
				for k in 24:
					var q := p0 + Vector3(cos(k * TAU / 24.0), 0, sin(k * TAU / 24.0)) * r
					if _in_forest(q) and _in_forest(q + Vector3(30, 0, 0)) and _in_forest(q + Vector3(-30, 0, 0)) \
							and _in_forest(q + Vector3(0, 0, 30)) and _in_forest(q + Vector3(0, 0, -30)):
						spot = q
						break
				if spot != Vector3.INF:
					break
			print("PEDOT metsäpiste ", spot, " alusta ", world.surface_at(spot))
			walker_out.global_position = Vector3(spot.x, Terrain.h(spot.x, spot.z) + 0.3, spot.z)
			for i in 10:
				await get_tree().physics_frame
			var wait_phase := func(ph: String, limit: float) -> void:
				var t0 := Time.get_ticks_msec()
				while is_instance_valid(_beast) and _beast.phase != ph and Time.get_ticks_msec() - t0 < limit * 1000.0:
					await get_tree().physics_frame
			# 1) Karhu, seisotaan paikallaan.
			_spawn_beast("karhu")
			await wait_phase.call("standoff", 20.0)
			print("PEDOT karhu kohtaus: etäisyys %.1f m viesti '%s'" % [_beast.global_position.distance_to(walker_out.global_position), _msg.text.replace("\n", " | ")])
			var oc := Camera3D.new()
			add_child(oc)
			oc.look_at_from_position(walker_out.global_position + Vector3(0, 2.2, 0) + (walker_out.global_position - _beast.global_position).normalized() * 3.0,
				_beast.global_position + Vector3(0, 1.0, 0), Vector3.UP)
			oc.current = true
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_karhu.png"))
			oc.queue_free()
			walker_out.activate_camera()
			await wait_phase.call("leave", 15.0)
			print("PEDOT karhu paikallaan: vaihe %s viesti '%s' haava %s" % [_beast.phase if is_instance_valid(_beast) else "-", _msg.text, bitten])
			if is_instance_valid(_beast):
				_beast.queue_free()
			_beast = null
			# 2) Karhu, juostaan karkuun.
			food["pulla"] = 2
			food["savukala"] = 1
			has_sausage = true
			bucket["mustikka"] = 3
			var k0: float = tilat.value("kipu")
			_spawn_beast("karhu")
			await wait_phase.call("standoff", 20.0)
			Input.action_press("forward")
			Input.action_press("sprint")
			await wait_phase.call("leave", 10.0)
			Input.action_release("forward")
			Input.action_release("sprint")
			print("PEDOT karhu juoksu: haava %s iso %s kipu %.2f -> %.2f ontuu %.2f ruoat %s makkara %s ämpäri %s" % [bitten, wound_big,
				k0, tilat.value("kipu"), walker_out.hurt_speed, food, has_sausage, bucket])
			print("PEDOT viesti: ", _msg.text.replace("\n", " | "))
			if is_instance_valid(_beast):
				_beast.queue_free()
			_beast = null
			_heal()
			for i in 120:
				await get_tree().physics_frame
			# 3) Susi, käännytään kohti ja huudetaan.
			food["savukala"] = 1
			_spawn_beast("susi")
			await wait_phase.call("standoff", 20.0)
			print("PEDOT susi kohtaus: viesti '%s' hint '%s'" % [_msg.text.replace("\n", " | "), _hint.text])
			var wp: Vector3 = _beast.global_position
			walker_out.look_at(Vector3(wp.x, walker_out.global_position.y, wp.z), Vector3.UP)
			await get_tree().process_frame
			Input.action_press("interact")
			await get_tree().process_frame
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("PEDOT susi huuto: vaihe %s viesti '%s' haava %s" % [_beast.phase if is_instance_valid(_beast) else "-", _msg.text, bitten])
			# 4) Santun hoito karhun haavaan.
			bitten = true
			wound_big = true
			walker_out.hurt = true
			walker_out.hurt_speed = BEAR_HURT_SPEED
			if mokki != null:
				mokki.ensure_built()
				_on_santtu_menu("haava")
			print("PEDOT Santtu: haava %s iso %s ontuu %.2f viesti '%s'" % [bitten, wound_big, walker_out.hurt_speed, _msg.text])
			# 5) Mökin metsä: osuus metsää mökin ympärillä.
			var n_forest := 0
			for k in 40:
				var q := MOKKI_POS + Vector3(cos(k * 0.7) * (60 + k * 8), 0, sin(k * 0.7) * (60 + k * 8))
				if _in_forest(q):
					n_forest += 1
			print("PEDOT mökin ympäristöstä metsää %d / 40, mökin piha metsää? %s" % [n_forest, _in_forest(MOKKI_POS)])
		"kauppapalautus":
			# Rahat ei riitä: kalja ja makkara palautetaan hyllyyn, sitten kassalla Q jättää ostokset tiskille.
			if player == bike:
				_toggle_mount()
			money = 3.0
			_enter_shop()
			for g in interior._queue:
				g.queue_free()
			interior._queue.clear()
			var press := func(action: String) -> void:
				await get_tree().process_frame
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			var go := func(at: Vector3) -> void:
				interior.walker.position = at
				for i in 5:
					await get_tree().physics_frame
			await go.call(interior.COOLER_SPOT)
			await press.call("interact")
			print("PALAUTUS kylmiö: kalja=%s hint '%s'" % [interior.has_beer, _hint.text])
			await go.call(interior.GRILL_SPOT)
			await press.call("interact")
			print("PALAUTUS grilli: kori=%s hint '%s'" % [interior.cart, _hint.text])
			await go.call(interior.QUEUE_FRONT)
			print("PALAUTUS kassalla: hint '%s' kauppias '%s'" % [_hint.text.replace("
", " | "), interior._cashier_bubble.text])
			await press.call("interact")
			print("PALAUTUS maksuyritys: maksettu=%s kauppias '%s'" % [interior.has_paid, interior._cashier_bubble.text])
			await go.call(interior.GRILL_SPOT)
			await press.call("bell")
			print("PALAUTUS grilliin Q: kori=%s" % [interior.cart])
			await go.call(interior.COOLER_SPOT)
			print("PALAUTUS kylmiöllä: hint '%s'" % _hint.text)
			await press.call("interact")
			print("PALAUTUS kylmiöön E: kalja=%s" % interior.has_beer)
			await press.call("interact")
			await go.call(interior.QUEUE_FRONT)
			await press.call("bell")
			print("PALAUTUS kassalle Q: kalja=%s kori=%s kauppias '%s' hint '%s'" % [interior.has_beer, interior.cart,
				interior._cashier_bubble.text, _hint.text])
			await go.call(interior.DOOR)
			print("PALAUTUS ovella: hint '%s'" % _hint.text)
		"kauppaovi":
			# Kauppa hommana: ovelta sisään, ulos kuutosen kanssa, kalja kädessä kielto, tyhjin käsin uudestaan
			# sisään (ostamatta ulos: kuutonen pysyy ostettuna), lopuksi kotiovelta sisään (E).
			_toggle_mount()
			var press := func(action: String) -> void:
				await get_tree().process_frame
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			walker_out.global_position = shop_zone + Vector3(0, 0.3, 0)
			for i in 10:
				await get_tree().physics_frame
			print("KAUPPAOVI parkkipaikalla: hint '%s'" % _hint.text)
			walker_out.global_position = shop_door + Vector3(0, 0.3, 0.5)
			for i in 10:
				await get_tree().physics_frame
			print("KAUPPAOVI ovella: hint '%s'" % _hint.text)
			await press.call("interact")
			print("KAUPPAOVI sisään: tila %s" % state)
			_on_shop_exited(true)
			for i in 10:
				await get_tree().physics_frame
			print("KAUPPAOVI ulos: tila %s, kaljat %d, viesti '%s', hint '%s'" % [state, beers, _msg.text.replace("\n", " "), _hint.text])
			walker_out.global_position = shop_door + Vector3(0, 0.3, 0.5)
			for i in 10:
				await get_tree().physics_frame
			await press.call("interact")
			print("KAUPPAOVI kalja kädessä: tila %s, viesti '%s'" % [state, _msg.text])
			beers = 0
			walker_out.set_carrying(false)
			await press.call("interact")
			print("KAUPPAOVI tyhjin käsin: tila %s" % state)
			print("KAUPPAOVI toinen käynti: kalja kädessä %s, maksettu %s, kori %s, kassi %s" % [interior.has_beer,
				interior.has_paid, interior.cart, interior.bag])
			var b0 := beers
			interior.exited.emit(interior.has_paid and interior.has_beer)  # ulos kassan ohi ostamatta mitään
			await get_tree().process_frame
			print("KAUPPAOVI ulos ostamatta: kaljat %d -> %d, tila %s" % [b0, beers, state])
			_enter_shop()
			_on_shop_exited(false)
			print("KAUPPAOVI ostamatta ulos: tila %s" % state)
			walker_out.global_position = home_door + Vector3(0, 0.3, 0)
			for i in 10:
				await get_tree().physics_frame
			print("KAUPPAOVI kotiovella: hint '%s'" % _hint.text)
			var dc := Camera3D.new()
			add_child(dc)
			var hf := M.HOME_YAW_DIR.normalized()
			dc.look_at_from_position(home_door + Vector3(hf.x, 0, hf.y) * 7.0 + Vector3(0, 2.5, 0), home_door + Vector3(0, 1.0, 0))
			dc.current = true
			_msg.text = ""
			_note.visible = false
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_kotiovi.png"))
			dc.queue_free()
			walker_out.activate_camera()
			var d0 := day
			print("KAUPPAOVI ennen: lista tehty %s, ostokset %s, listalla %d" % [_list_done, paivi_bag, shopping_list.size()])
			await press.call("interact")
			home_int.walker.position = home_int.SPOTS.sanky[0]
			for i in 5:
				await get_tree().physics_frame
			await press.call("interact")
			print("KAUPPAOVI Päivi: %s" % str(_msg_queue))
			for i in 30:
				await get_tree().process_frame
			print("KAUPPAOVI kotiin: päivä %d -> %d, tila %s" % [d0, day, state])
		"kotisisa":
			# Kodin sisätila: etuovesta sisään, kuva ylhäältä, jokainen toimintopiste, takaovesta ulos ja sisään,
			# lopuksi nukkumaan parisänkyyn.
			_toggle_mount()
			var press := func(action: String) -> void:
				await get_tree().process_frame
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			var shot := func(name: String) -> void:
				_msg.text = ""
				_note.visible = false
				for i in 20:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			walker_out.global_position = home_door + Vector3(0, 0.3, 0)
			for i in 10:
				await get_tree().physics_frame
			print("KOTI ovella: hint '%s'" % _hint.text)
			await press.call("interact")
			print("KOTI sisällä: tila %s, vihje '%s'" % [state, home_int.hint])
			await shot.call("_eteinen.png")
			var top := Camera3D.new()
			add_child(top)
			top.look_at_from_position(HOME_INT_POS + Vector3(0, 24, 9), HOME_INT_POS + Vector3(0, 0, -0.5))
			top.current = true
			await shot.call("_pohja.png")
			top.queue_free()
			home_int.walker.activate()
			var wk: CharacterBody3D = home_int.walker
			for id in ["kerrossanky", "suihku", "peili", "sauna", "kahvi", "jaakaappi", "tv", "sohva", "nortti"]:  # WC: vessa-testi
				wk.position = home_int.SPOTS[id][0]
				for i in 5:
					await get_tree().physics_frame
				var h: String = home_int.hint
				await press.call("interact")
				print("KOTI %s: '%s' -> '%s'" % [id, h, _msg.text.replace("\n", " ")])
				if id == "nortti":
					await shot.call("_nortti.png")
			var count_water := func() -> int:
				var n := 0
				for c in Sfx.get_children():
					if c is AudioStreamPlayer and c.playing and c.stream == Sfx.stream("water"):
						n += 1
				return n
			print("KOTI vesiääniä soi heti: %d" % count_water.call())
			await get_tree().create_timer(4.0).timeout  # oikeaa aikaa (testiajo voi pyöriä yli 60 FPS)
			print("KOTI vesiääniä soi 4 s päästä: %d" % count_water.call())
			for c in Sfx.get_children():
				if c is AudioStreamPlayer and c.playing:
					print("KOTI soi: %s db %.1f pitch %.2f pos %.1f/%.1f bus %s" % [c.stream.resource_path, c.volume_db, c.pitch_scale,
						c.get_playback_position(), c.stream.get_length(), c.bus])
			wk.position = home_int.SPOTS.takaovi[0]
			for i in 5:
				await get_tree().physics_frame
			await press.call("interact")
			var hb2 := walker_out.global_position
			print("KOTI takaovesta: tila %s, takaovelta %.1f m, etuovelta %.1f m" % [state,
				Vector2(hb2.x - home_back_door.x, hb2.z - home_back_door.z).length(), Vector2(hb2.x - home_door.x, hb2.z - home_door.z).length()])
			await shot.call("_takapiha.png")
			var bc := Camera3D.new()
			add_child(bc)
			var hf2 := M.HOME_YAW_DIR.normalized()
			bc.look_at_from_position(home_back_door - Vector3(hf2.x, 0, hf2.y) * 7.0 + Vector3(0, 2.5, 0), home_back_door + Vector3(0, 1.0, 0))
			bc.current = true
			await shot.call("_takaovi_ulkoa.png")
			bc.queue_free()
			walker_out.activate_camera()
			walker_out.global_position = home_back_door + Vector3(0, 0.3, 0)
			for i in 10:
				await get_tree().physics_frame
			print("KOTI takaovella: hint '%s'" % _hint.text)
			await press.call("interact")
			print("KOTI takaovesta sisään: tila %s" % state)
			wk.position = home_int.SPOTS.sanky[0]
			for i in 5:
				await get_tree().physics_frame
			var d0 := day
			print("KOTI sängyllä: '%s'" % home_int.hint)
			await press.call("interact")
			for i in 30:
				await get_tree().process_frame
			print("KOTI nukuttu: päivä %d -> %d, tila %s" % [d0, day, state])
		"juhlat":
			# Onnellinen loppu kotipiilolta: 24 kaljaa kotipiiloissa, nukkuminen ei aloita juhlia, kotipiilolla E aloittaa.
			_toggle_mount()
			var press := func(action: String) -> void:
				await get_tree().process_frame
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			stash["koti"] = 12
			stash["autotalli"] = 8
			stash["komposti"] = 4
			beers = 0
			_kaljarauha = true  # Päivi ei etsi jemmoja yöllä (muuten jemma paljastuu ja välikohtaus alkaa)
			walker_out.global_position = home_door + Vector3(0, 0.3, 0)
			for i in 10:
				await get_tree().physics_frame
			await press.call("interact")
			home_int.walker.position = home_int.SPOTS.sanky[0]
			for i in 5:
				await get_tree().physics_frame
			var e0 := jemma_endings
			await press.call("interact")
			for i in 30:
				await get_tree().process_frame
			print("JUHLAT nukuttu: jemma %d, loppuja %d -> %d, tila %s" % [jemma, e0, jemma_endings, state])
			await _test_goto_stash("autotalli")
			print("JUHLAT kotipiilolla: hint '%s'" % _hint.text)
			await press.call("interact")
			for i in 10:
				await get_tree().process_frame
			print("JUHLAT E: jemma %d, loppuja %d -> %d, tila %s" % [jemma, e0, jemma_endings, state])
		"vessa":
			# Kodin WC: ykkönen ja kakkonen (ponnistus vihreällä, 5 arkkia).
			_toggle_mount()
			var press := func(action: String) -> void:
				await get_tree().process_frame
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			# Pöntöllä: valikko auki, valinta (ykkönen = 1. rivi, kakkonen = 2.), minipeli pelataan läpi.
			var play := func(choice: int, sheets: int) -> void:
				print("VESSA valikko auki %s, kysymys '%s'" % [_item_menu.is_open(), _item_menu._title.text])
				if choice == 2:
					await press.call("back")
				await press.call("interact")
				var g: CanvasLayer = _wc_game
				if g.mode == "ykkonen":
					while is_instance_valid(g):
						var aim: Vector2 = g._aim
						Input.action_release("left")
						Input.action_release("right")
						Input.action_release("forward")
						Input.action_release("back")
						if aim.x > 8.0:
							Input.action_press("left", clampf(aim.x / 60.0, 0.2, 1.0))
						elif aim.x < -8.0:
							Input.action_press("right", clampf(-aim.x / 60.0, 0.2, 1.0))
						if aim.y > 8.0:
							Input.action_press("forward", clampf(aim.y / 60.0, 0.2, 1.0))
						elif aim.y < -8.0:
							Input.action_press("back", clampf(-aim.y / 60.0, 0.2, 1.0))
						await get_tree().process_frame
					for a2 in ["left", "right", "forward", "back"]:
						Input.action_release(a2)
				else:
					while is_instance_valid(g) and g._phase == "push":
						await get_tree().process_frame
						if g._needle >= WcGame.GREEN.x + 0.04 and g._needle <= WcGame.GREEN.y - 0.04:
							await press.call("interact")
					for k in sheets:
						await press.call("interact")
					await press.call("brake")
				for i in 5:
					await get_tree().process_frame
				print("VESSA tulos: '%s'" % _msg.text.replace("\n", " | "))
			walker_out.global_position = home_door + Vector3(0, 0.3, 0)
			for i in 10:
				await get_tree().physics_frame
			await press.call("interact")
			home_int.walker.position = home_int.SPOTS.wc[0]
			for i in 5:
				await get_tree().physics_frame
			print("VESSA koti: '%s'" % home_int.hint)
			await press.call("interact")
			await play.call(1, 0)
			await press.call("interact")
			await play.call(2, 5)
			print("VESSA kävelijä liikkuu %s, kiireinen %s" % [home_int.walker.controls_enabled, home_int.busy])
		"mokkivessa":
			# Mökin pesuhuoneen pönttö (kakkonen, 12 arkkia = tukos) ja pihan huussi (kakkonen, 12 arkkia: ei tukosta).
			_toggle_mount()
			var press := func(action: String) -> void:
				await get_tree().process_frame
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			# Pöntöllä: valikko auki, valinta (ykkönen = 1. rivi, kakkonen = 2.), minipeli pelataan läpi.
			var play := func(choice: int, sheets: int) -> void:
				print("VESSA valikko auki %s, kysymys '%s'" % [_item_menu.is_open(), _item_menu._title.text])
				if choice == 2:
					await press.call("back")
				await press.call("interact")
				var g: CanvasLayer = _wc_game
				if g.mode == "ykkonen":
					while is_instance_valid(g):
						var aim: Vector2 = g._aim
						Input.action_release("left")
						Input.action_release("right")
						Input.action_release("forward")
						Input.action_release("back")
						if aim.x > 8.0:
							Input.action_press("left", clampf(aim.x / 60.0, 0.2, 1.0))
						elif aim.x < -8.0:
							Input.action_press("right", clampf(-aim.x / 60.0, 0.2, 1.0))
						if aim.y > 8.0:
							Input.action_press("forward", clampf(aim.y / 60.0, 0.2, 1.0))
						elif aim.y < -8.0:
							Input.action_press("back", clampf(-aim.y / 60.0, 0.2, 1.0))
						await get_tree().process_frame
					for a2 in ["left", "right", "forward", "back"]:
						Input.action_release(a2)
				else:
					while is_instance_valid(g) and g._phase == "push":
						await get_tree().process_frame
						if g._needle >= WcGame.GREEN.x + 0.04 and g._needle <= WcGame.GREEN.y - 0.04:
							await press.call("interact")
					for k in sheets:
						await press.call("interact")
					await press.call("brake")
				for i in 5:
					await get_tree().process_frame
				print("VESSA tulos: '%s'" % _msg.text.replace("\n", " | "))
			walker_out.global_position = mokki.porch_pos(0.9)
			for i in 10:
				await get_tree().physics_frame
			_enter_mokki()
			mokki_int.walker.position = mokki_int.SPOTS.wc[0]
			for i in 5:
				await get_tree().physics_frame
			print("VESSA mökki: '%s'" % mokki_int.hint)
			await press.call("interact")
			await play.call(2, 12)
			_on_mokki_exited()
			walker_out.global_position = mokki.to_global(Mokki.HUUSSI_LOCAL + Vector3(0, 0.3, 1.3))
			for i in 10:
				await get_tree().physics_frame
			print("VESSA huussi: '%s'" % _hint.text)
			await press.call("interact")
			await play.call(2, 12)
		"lappu":
			# Aamulappu ja samaan aikaan pitkä viesti ja vihje: tekstit lapun oikealla puolella, eivät sen alla.
			_day_note("Huomenta! Mää lähin jo.", "Se nurmikko ei leikkaa itseään!\nAnna-Liisa sano aidan takaa, että meillä on kohta ihan heinäpelto!")
			for i in 30:
				await get_tree().process_frame
			_show_message("Päivä 5 alkaa kotoa.\nPyörä jäi eilen muualle – katso kartasta (M), minne.\nJossain päin kylää pojat pelaa jalkapalloa.", 6.0)
			for i in 3:
				await get_tree().process_frame
			_hint.text = "Ovi ei aukea kaljat kädessä – Päivi näkee! Piilota kaljat ensin jemmaan (E)."
			print("LAPPU näkyy %s, lapun oikea reuna %.0f, viestin vasen reuna %.0f" % [_note.is_showing(),
				_note._paper.get_global_rect().end.x, _msg.get_global_rect().position.x])
		"mummotesti":
			# Pyörällä lujaa mummojen ohi: suuttuvatko ja heittävätkö kettukarkkeja? Sitten kello.
			var mp0 := mummot.global_position
			bike.global_position = mp0 + Vector3(-20, 0.4, 3.0)
			bike.look_at(bike.global_position + Vector3(1, 0, 0), Vector3.UP)
			bike.speed = 9.0
			Input.action_press("forward")
			var angry_seen := false
			for i in 180:
				await get_tree().physics_frame
				angry_seen = angry_seen or mummot.is_angry()
			Input.action_release("forward")
			print("MUMMOT paikka %s, kaupan ovi %s, väli %.1f m, parkkipaikka %.1f m" % [mummot.global_position, shop_door,
				Vector2(mummot.global_position.x - shop_door.x, mummot.global_position.z - shop_door.z).length(),
				Vector2(mummot.global_position.x - shop_zone.x, mummot.global_position.z - shop_zone.z).length()])
			var oc := Camera3D.new()
			add_child(oc)
			oc.look_at_from_position(shop_door + Vector3(-4, 9, 22), (shop_door + mummot.global_position) / 2.0)
			oc.current = true
			_msg.text = ""
			_note.visible = false
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_kauppa.png"))
			print("MUMMOT ohi: vaarat %s, in_vaala %s, suuttui %s, lentäviä %d, maassa %d, vauhti %.1f" % [_hazards.process_mode,
				_in_vaala, angry_seen, mummot._flying.size(), mummot._ground.size(), bike.speed])
		"koillinen":
			# Pelialueen koillisnurkka (x > 1000, y < 2500): onko maastoa, puita ja teitä? Kuvat Patotien varrelta.
			var oc := Camera3D.new()
			oc.far = 3000.0
			add_child(oc)
			_msg.text = ""
			_note.visible = false
			for spot in [["_patotie", Vector2(1470, 2300), Vector2(1470, 2700)], ["_ylhaalta", Vector2(1300, 2200), Vector2(1300, 2201)]]:
				var a3 := M.w(spot[1])
				var b3 := M.w(spot[2])
				if spot[0] == "_ylhaalta":
					oc.look_at_from_position(a3 + Vector3(0, 450, 300), a3)
				else:
					oc.look_at_from_position(a3 + Vector3(0, 3, 0), b3 + Vector3(0, 2, 0))
				oc.current = true
				for i in 40:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", spot[0] + ".png"))
			print("KOILLINEN maaston korkeus %.1f, pinta %s" % [Terrain.h(M.w(Vector2(1300, 2200)).x, M.w(Vector2(1300, 2200)).z),
				world.surface_at(M.w(Vector2(1300, 2200)))])
		"kotaopaste":
			# Laavun reittiviitta kodalle ja koillisen reunan reittiohje.
			var kpts: PackedVector2Array = world._kota_path()
			print("KOTAOPASTE polku %d pistettä, päättyy %.0f m kodasta" % [kpts.size(),
				kpts[-1].distance_to(M.w2(M.KOTA)) if kpts.size() > 0 else -1.0])
			var oc := Camera3D.new()
			add_child(oc)
			var k0: Vector2 = kpts[0]
			var kd: Vector2 = (kpts[2] - kpts[0]).normalized()
			var sp := k0 + kd * 4.0
			var sp3 := Vector3(sp.x, Terrain.h(sp.x, sp.y), sp.y)
			oc.look_at_from_position(sp3 + Vector3(kd.y, 0, -kd.x) * 7.0 + Vector3(0, 2.0, 0), sp3 + Vector3(0, 1.5, 0))
			oc.current = true
			_msg.text = ""
			_note.visible = false
			for i in 40:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_viitta.png"))
			oc.queue_free()
			_toggle_mount()
			walker_out.global_position = M.w(Vector2(996, 2300)) + Vector3(0, 0.4, 0)
			_edge_cd = 0.0
			for i in 20:
				await get_tree().physics_frame
			print("KOTAOPASTE reunalla: '%s'" % _msg.text)
		"juoksutaksi", "juoksutappelu":
			# Juoksukaljat Saloisissa: kauppias perään. Taksi: juokse suoraan taksille (5,4 m/s). Tappelu: jää
			# paikalleen, kung fu -torjunta ja vastaisku, tölkki tehoaa, ja voitto ja tappio.
			_toggle_mount()
			walker_out.global_position = shop_door + Vector3(0, 0.3, 0.5)
			for i in 5:
				await get_tree().physics_frame
			_enter_shop()
			interior.has_beer = true
			interior.has_paid = true
			interior.stolen = true
			_on_shop_exited(true)
			await get_tree().process_frame
			print("JUOKSU alku: kaljat %d, kauppias %s, etumatka %.1f s, viesti '%s'" % [beers, _chasing(),
				_shop_chaser.delay, _msg.text.replace("\n", " ")])
			if scene == "juoksutaksi":
				var t0 := Time.get_ticks_msec()
				walker_out.controls_enabled = false
				while _chasing():
					var tp: Vector3 = world.taxi_pos
					var to := Vector3(tp.x - walker_out.global_position.x, 0, tp.z - walker_out.global_position.z)
					if to.length() < TAXI_RADIUS - 0.5:
						break
					walker_out.global_position += to.normalized() * OnFoot.RUN / 60.0
					await get_tree().physics_frame
				walker_out.controls_enabled = true
				var cd: float = walker_out.global_position.distance_to(_shop_chaser.global_position) if _chasing() else -1.0
				print("JUOKSU taksilla: kauppias jahtaa %s, välimatka %.1f m, hint '%s'" % [_chasing(), cd, _hint.text])
				for i in 2:
					await get_tree().process_frame
				Input.action_press("interact")
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
				print("JUOKSU taksiin: tila %s, rahat %.2f" % [state, money])
			else:
				for i in 400:
					await get_tree().physics_frame
					if state == "fight":
						break
				print("JUOKSU kiinni: tila %s, vastustaja %s" % [state, fight.foe.get("short", "")])
				while fight._phase != "fight":
					await get_tree().process_frame
				var j: Node3D = fight._j
				var hp0: float = j.hp
				var bl: bool = j.take_hit(12.0, -1.0, 2.0)
				await get_tree().process_frame
				print("JUOKSU lyönti: torjuttu %s, hp %.0f -> %.0f, asento %s, torjunta %.2f s, vastaisku tulossa %s" % [bl,
					hp0, j.hp, j.state, j.parry_t, j.counter_pending])
				var seen := ""
				for i in 90:
					await get_tree().process_frame
					if j.state == "attack" and seen == "":
						seen = j._attack
				print("JUOKSU vastaisku: %s, huuto '%s'" % [seen, fight._bubble_j.text])
				bl = j.take_hit(26.0, -1.0, 5.5, 6.0, 0.9, true)
				print("JUOKSU tölkki: torjuttu %s, hp -> %.0f" % [bl, j.hp])
				j.take_hit(999.0, -1.0, 5.5, 6.0, 0.9, true)
				while state == "fight":
					await get_tree().process_frame
				print("JUOKSU voitto: tila %s, kaljat %d, viesti '%s'" % [state, beers, _msg.text.replace("\n", " ")])
		"mokkijuoksu":
			# Juoksukaljat Vaalan Tervaportissa: ei taksia, kauppias saa mopon kiinni, tappio vie kaljat ja Koskenkorvat.
			_toggle_mount()
			walker_out.global_position = mokki.gpos(Mokki.MOPO_LOCAL + Vector3(1.0, 0.5, 0.0))
			for i in 10:
				await get_tree().physics_frame
			_start_mopo()
			var vl: Node3D = mopo_trip.vaala
			var mp: CharacterBody3D = mopo_trip.mopo
			mp.position = vl.kmarket_door + Vector3(0, 0.6, 0)
			for i in 10:
				await get_tree().physics_frame
			_enter_vaala_shop()
			interior.has_beer = true
			interior.has_paid = true
			interior.stolen = true
			var pv0 := viina_pullot
			_on_shop_exited(true)
			await get_tree().process_frame
			print("VJUOKSU alku: kaljat %d, kauppias %s, viesti '%s'" % [beers, _chasing(), _msg.text.replace("\n", " ")])
			for i in 600:
				await get_tree().physics_frame
				if state == "fight":
					break
			print("VJUOKSU kiinni: tila %s, kauppias korkeus %.1f, mopo %.1f" % [state, _shop_chaser.global_position.y if is_instance_valid(_shop_chaser) else -1.0, mp.global_position.y])
			while fight._phase != "fight":
				await get_tree().process_frame
			for i in 40:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_tappelu.png"))
			fight._p.take_hit(999.0, 1.0, 5.0)
			while state == "fight":
				await get_tree().process_frame
			print("VJUOKSU tappio: tila %s, kaljat %d, pullot %d -> %d, vaala %s, viesti '%s'" % [state, beers, pv0, viina_pullot,
				_in_vaala, _msg.text.replace("\n", " ")])
		"tarina":
			# Koko tarina läpi: kaljat jemmaan, Pekan tehtävät, sienet, puolukat, Sinikan nurmikko, avaimet kodalta.
			story = Story.new()
			_toggle_mount()
			var press := func(action: String) -> void:
				await get_tree().process_frame
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			var goto := func(pos: Vector3) -> void:
				walker_out.global_position = pos + Vector3(0, 0.4, 0)
				walker_out.velocity = Vector3.ZERO
				for i in 8:
					await get_tree().physics_frame
			var shot := func(name: String) -> void:
				_msg.text = ""
				_msg_queue.clear()
				_note.visible = false
				for i in 20:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			print("TARINA alku: %s, Pekan kyyti auki %s" % [story.step, story.ride_unlocked()])
			beers = 6
			walker_out.set_carrying(true)
			await _test_goto_stash("koti")
			var shift := InputEventKey.new()
			shift.keycode = KEY_SHIFT
			shift.physical_keycode = KEY_SHIFT
			shift.pressed = true
			Input.parse_input_event(shift)
			await press.call("interact")
			shift = shift.duplicate()
			shift.pressed = false
			Input.parse_input_event(shift)
			print("TARINA jemma: kaljat %d, vaihe %s, viesti '%s'" % [beers, story.step, str(_msg_queue)])
			_on_home_exited()
			await goto.call(pekka.global_position + Vector3(1.5, 0, 0))
			print("TARINA Pekka: '%s'" % _hint.text)
			await press.call("interact")
			print("TARINA tehtävät: %s, lista %s" % [story.step, str(story.list())])
			bucket = {"kantarelli": 2, "herkkutatti": 2, "puolukka": 6}
			await goto.call(pekka.global_position + Vector3(1.5, 0, 0))
			print("TARINA Pekka sienet: '%s'" % _hint.text)
			var m0 := money
			await press.call("interact")
			print("TARINA sienet: %s, ämpäri %s, rahaa %.2f -> %.2f" % [story.done.sienet, bucket, m0, money])
			await goto.call(arto.global_position + Vector3(1.5, 0, 0))
			print("TARINA Arto: '%s'" % _hint.text)
			await press.call("interact")
			print("TARINA puolukat: %s, ämpäri %s" % [story.done.puolukat, bucket])
			await goto.call(sinikka_lawn.mower.global_position + Vector3(0.8, 0, 0))
			print("TARINA leikkuri: '%s'" % _hint.text)
			await shot.call("_nurmikko.png")
			await press.call("interact")
			print("TARINA leikkuu käy %s" % mowing)
			sinikka_lawn.lengths.fill(0.0)
			for i in 10:
				await get_tree().process_frame
			print("TARINA nurmikko: %s, vaihe %s" % [story.done.nurmikko, story.step])
			_inventory.toggle()
			for i in 5:
				await get_tree().process_frame
			await shot.call("_reppu.png")
			_inventory.toggle()
			await goto.call(pekka.global_position + Vector3(1.5, 0, 0))
			print("TARINA Pekka avaimet: '%s'" % _hint.text)
			await press.call("interact")
			print("TARINA avaimet: vaihe %s, avaimet kodalla %s" % [story.step, is_instance_valid(_keys_node)])
			await goto.call(_keys_node.global_position + Vector3(1.0, 0, 0))
			print("TARINA kodalla: '%s'" % _hint.text)
			var kc := Camera3D.new()
			add_child(kc)
			kc.look_at_from_position(_keys_node.global_position + Vector3(1.2, 1.2, 1.2), _keys_node.global_position)
			kc.current = true
			await shot.call("_avaimet.png")
			kc.queue_free()
			walker_out.activate_camera()
			await press.call("interact")
			print("TARINA avaimet mukana: %s" % story.step)
			await goto.call(pekka.global_position + Vector3(1.5, 0, 0))
			await press.call("interact")
			print("TARINA valmis: %s, kyyti auki %s" % [story.step, story.ride_unlocked()])
			for i in 3:
				await get_tree().process_frame
			print("TARINA Pekka nyt: '%s'" % _hint.text)
		"taksipaapeli":
			# Kaupan taksilla Paapeliin (60 €, meno-paluu) ja mökiltä taksilla takaisin; Pekan kyyti lukossa.
			story = Story.new()
			_toggle_mount()
			var press := func(action: String) -> void:
				await get_tree().process_frame
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			money = 100.0
			walker_out.global_position = world.taxi_pos + Vector3(2.0, 0.4, 0)
			for i in 10:
				await get_tree().physics_frame
			print("TAKSI hint: '%s'" % _hint.text)
			await press.call("interact")
			print("TAKSI valikko: %s '%s'" % [_item_menu.is_open(), _item_menu._title.text])
			await press.call("back")
			await press.call("interact")
			while not cutscene.busy:
				await get_tree().process_frame
			while cutscene.busy:
				await get_tree().process_frame
			for i in 20:
				await get_tree().physics_frame
			print("TAKSI mökillä: %s, rahaa %.2f, paluu maksettu %s" % [_at_mokki(), money, _taxi_mokki_return])
			walker_out.global_position = mokki.to_global(Mokki.RIDE_LOCAL) + Vector3(0, 0.4, 0)
			for i in 10:
				await get_tree().physics_frame
			print("TAKSI paluu: '%s'" % _hint.text)
			await press.call("interact")
			while not cutscene.busy:
				await get_tree().process_frame
			while cutscene.busy:
				await get_tree().process_frame
			for i in 20:
				await get_tree().physics_frame
			print("TAKSI kotona: mökillä %s, rahaa %.2f, paluu %s, tila %s" % [_at_mokki(), money, _taxi_mokki_return, state])
			walker_out.global_position = pekka.global_position + Vector3(1.5, 0.4, 0)
			bucket = {}
			for i in 10:
				await get_tree().physics_frame
			print("TAKSI Pekka (lukossa): '%s'" % _hint.text)
		"karttaveto":
			# Paperikartta kosketuksella: veto vierittää (ei aseta kohdetta), napautus asettaa kohteen;
			# mökillä kahden sormen nipistys zoomaa.
			if player == bike:
				_toggle_mount()
			_paper.toggle()
			for i in 3:
				await get_tree().process_frame
			var c: Vector2 = _paper._view.position + _paper._view.size / 2.0
			var mb := func(pos: Vector2, down: bool) -> void:
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = down
				e.position = pos
				_paper._gui_input(e)
			var s0: float = _paper._scroll
			mb.call(c, true)
			for k in 12:
				var mm := InputEventMouseMotion.new()
				mm.position = c + Vector2(0, -20.0 * (k + 1))
				mm.relative = Vector2(0, -20)
				mm.button_mask = MOUSE_BUTTON_MASK_LEFT
				_paper._gui_input(mm)
			mb.call(c + Vector2(0, -240), false)
			print("KARTTAVETO veto ylös: vieritys %.0f -> %.0f (max %.0f), kohde '%s'" % [s0, _paper._scroll, _paper._max_scroll(),
				str(_paper.target)])
			mb.call(c, true)
			mb.call(c, false)
			print("KARTTAVETO napautus: kohde '%s'" % [str(_paper.target)])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_kartta.png"))
			_paper.toggle()
			mokki.ensure_built()
			walker_out.global_position = MOKKI_POS + Vector3(5, 2, 5)
			for i in 10:
				await get_tree().physics_frame
			_paper.toggle()
			for i in 3:
				await get_tree().process_frame
			var z0: float = _paper._vzoom
			var vc: Vector2 = _paper._view.global_position + _paper._view.size / 2.0
			var touch := func(i: int, pos: Vector2, down: bool) -> void:
				var e := InputEventScreenTouch.new()
				e.index = i
				e.position = pos
				e.pressed = down
				_paper._input(e)
			var drag := func(i: int, pos: Vector2) -> void:
				var e := InputEventScreenDrag.new()
				e.index = i
				e.position = pos
				_paper._input(e)
			touch.call(0, vc - Vector2(50, 0), true)
			touch.call(1, vc + Vector2(50, 0), true)
			for k in 10:
				drag.call(0, vc - Vector2(50 + 10 * (k + 1), 0))
				drag.call(1, vc + Vector2(50 + 10 * (k + 1), 0))
			touch.call(0, vc, false)
			touch.call(1, vc, false)
			print("KARTTAVETO mökki vaala=%s nipistys: zoom %.3f -> %.3f" % [_paper._vaala, z0, _paper._vzoom])
			_paper.toggle()
		"karttanaapurit":
			# Paperikartta: naapurien merkit kodin ympärillä.
			_note.visible = false
			_msg.text = ""
			_paper.toggle()
			for i in 10:
				await get_tree().process_frame
			# Hiiri Järvikujan päälle: tien nimi näkyy.
			for r in M.ROADS:
				if r.name == "Järvikuja":
					var mp: Vector2 = _paper._px(r.pts[int(r.pts.size() / 2)])
					var ev := InputEventMouseMotion.new()
					ev.position = mp + _paper._view.position
					_paper._gui_input(ev)
					print("KARTTA hiiren alla: '%s'" % _paper._hover_name)
					break
			for i in 20:
				await get_tree().process_frame
		"sisasyonti":
			# T sisätiloissa: kotona valikko aukeaa, kävelijä pysähtyy, pulla syödään ja ohjaus palaa.
			if player == bike:
				_toggle_mount()
			food["pulla"] = 2
			walker_out.global_position = home_door + Vector3(0, 0.3, 0)
			for i in 5:
				await get_tree().physics_frame
			_enter_home("ovi")
			for i in 30:
				await get_tree().physics_frame
			var n0: float = tilat.get_v("nalka") if tilat.has_method("get_v") else 0.0
			await get_tree().process_frame
			Input.action_press("eat")
			await get_tree().process_frame
			await get_tree().process_frame
			Input.action_release("eat")
			print("SISASYO tila=%s valikko=%s kotikävelijän ohjaus=%s ulkokävelijän=%s" % [state, _item_menu.is_open(),
				home_int.walker.controls_enabled, walker_out.controls_enabled])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_sisasyonti.png"))
			_item_menu.visible = false
			_item_menu.chosen.emit("pulla")
			await get_tree().process_frame
			print("SISASYO jälkeen: pullia %d, viesti '%s', kotikävelijän ohjaus=%s ulkokävelijän=%s" % [food.get("pulla", 0), _msg.text,
				home_int.walker.controls_enabled, walker_out.controls_enabled])
		"reppukaytto":
			# Repusta klikkaus: pulla syödään, kalja juodaan, tooltip kertoo toiminnon. Sisällä kävelijä ei herää.
			_toggle_mount()
			food["pulla"] = 2
			beers = 3
			_inventory.toggle()
			for i in 5:
				await get_tree().process_frame
			var click := func(icon: String) -> void:
				for i in _inventory._slots.size():
					var it = _inventory._slot_item(i)
					if it != null and it.icon == icon:
						var ev := InputEventMouseMotion.new()
						_inventory._hover = i
						var cl := InputEventMouseButton.new()
						cl.button_index = MOUSE_BUTTON_LEFT
						cl.pressed = true
						cl.position = _inventory._slots[i].get_center()
						_inventory._gui_input(cl)
						return
			await click.call("pulla")
			print("REPPUK pulla: %d, viesti '%s'" % [food.get("pulla", 0), _msg.text])
			await click.call("kalja")
			print("REPPUK kalja: %d, viesti '%s', tauko %s, reppu auki %s" % [beers, _msg.text, get_tree().paused, _inventory.visible])
			for i in _inventory._slots.size():
				var it = _inventory._slot_item(i)
				if it != null and it.icon == "pulla":
					_inventory._hover = i
			_inventory.queue_redraw()
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_tooltip.png"))
			_inventory.toggle()
			walker_out.global_position = home_door + Vector3(0, 0.3, 0)
			for i in 5:
				await get_tree().physics_frame
			_enter_home("ovi")
			_inventory.toggle()
			for i in 3:
				await get_tree().process_frame
			await click.call("pulla")
			_inventory.toggle()
			print("REPPUK sisällä: ulkokävelijän ohjaus %s, tila %s" % [walker_out.controls_enabled, state])
		"mokkieat":
			# Vaalan matkalla T: pulla mopon selässä, vauhdissa ei, viina jalan.
			_toggle_mount()
			walker_out.global_position = mokki.gpos(Mokki.MOPO_LOCAL + Vector3(1.0, 0.5, 0.0))
			for i in 10:
				await get_tree().physics_frame
			_start_mopo()
			food["pulla"] = 1
			viina_pullot = 1
			var mp: CharacterBody3D = mopo_trip.mopo
			var press := func(action: String) -> void:
				await get_tree().process_frame
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			for i in 30:
				await get_tree().physics_frame
			await press.call("eat")
			print("MOPOEAT open=", _item_menu.is_open(), " mopo_ctrl=", mp.controls_enabled, " door_block=", mopo_trip.menu_open)
			await press.call("interact")
			print("MOPOEAT pulla=", food.get("pulla", 0), " open=", _item_menu.is_open(), " mopo_ctrl=", mp.controls_enabled, " state=", state)
			Input.action_press("forward")
			for i in 120:
				await get_tree().physics_frame
			await press.call("eat")
			Input.action_release("forward")
			print("MOPOEAT fast speed=%.1f open=" % mp.speed, _item_menu.is_open(), " msg=", _msg.text)
			Input.action_press("brake")
			for i in 180:
				await get_tree().physics_frame
				if absf(mp.speed) < 0.5:
					break
			Input.action_release("brake")
			await press.call("mount")
			for i in 10:
				await get_tree().physics_frame
			await press.call("eat")
			print("MOPOEAT foot=", mopo_trip.on_foot != null, " open=", _item_menu.is_open(), " walker_ctrl=", walker_out.controls_enabled)
			await press.call("interact")
			print("MOPOEAT viina=", viina_pullot, " walker_ctrl=", walker_out.controls_enabled, " state=", state)
		"mokkimopo":
			# Mopomatka: lähtö Paapelista, ajo alusta, kuvat reitin varrelta (_1 lähtö, _2 Neittäväntie, _3 silta,
			# _4 Siitari) ja saapuminen baariin.
			_toggle_mount()
			walker_out.global_position = mokki.gpos(Mokki.MOPO_LOCAL + Vector3(1.0, 0.5, 0.0))
			for i in 10:
				await get_tree().physics_frame
			var tb := Time.get_ticks_msec()
			_start_mopo()
			print("MOPO käynnistys %d ms" % (Time.get_ticks_msec() - tb))
			var mp: CharacterBody3D = mopo_trip.mopo
			var vl: Node3D = mopo_trip.vaala
			var snap := func(name: String) -> void:
				for i in 30:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			Input.action_press("forward")
			for i in 240:
				await get_tree().physics_frame
			Input.action_release("forward")
			print("MOPO 4 s: %.1f km/h, y %.2f tie %.2f, %s" % [mp.speed * 3.6, mp.position.y, vl.h(mp.position.x, mp.position.z), mopo_trip.status])
			await snap.call("_1.png")
			for spot in [["_2.png", 0.3], ["_3.png", -1.0], ["_4.png", -2.0]]:
				var si: int
				if spot[1] == -1.0:
					si = int(vl.data.bridges[0][0]) - 25
				elif spot[1] == -2.0:
					si = vl.nearest(vl.siitari_park)[0] - 30
				else:
					si = int(vl.road.size() * spot[1])
				var d: Vector3 = vl.road_dir(si)
				mp.position = vl.road_pos(si) + Vector3(0, 0.6, 0) + d.cross(Vector3.UP) * 1.8
				mp.rotation.y = atan2(-d.x, -d.z)
				mp.speed = 8.0
				mp.activate_camera()
				await snap.call(spot[0])
				print("MOPO %s: %s | hint '%s'" % [spot[0], mopo_trip.status, _hint.text.replace("\n", " / ")])
			# Yleiskuvat: Oulujoen silta sivulta ja Siitari Vaalantieltä (_5, _6).
			_msg.text = ""
			var oc := Camera3D.new()
			oc.far = 2000.0
			add_child(oc)
			var bm: Vector3 = mopo_trip.to_global(vl.road_pos(int((vl.data.bridges[0][0] + vl.data.bridges[0][1]) / 2)))
			var bdir: Vector3 = vl.road_dir(int(vl.data.bridges[0][0]))
			oc.look_at_from_position(bm + bdir.cross(Vector3.UP) * 70.0 + Vector3(0, 12, 0), bm)
			oc.current = true
			await snap.call("_5.png")
			var sd: Vector3 = mopo_trip.to_global(vl.siitari_door)
			var sc3 := Vector3(vl.siitari.x, sd.y - VAALA_POS.y, vl.siitari.y)
			var ni3: Array = vl.nearest(sc3)
			var rp3: Vector3 = mopo_trip.to_global(vl.road_pos(ni3[0]))
			var sgc: Vector3 = mopo_trip.to_global(sc3)
			oc.look_at_from_position(rp3 + (rp3 - sgc).normalized() * 12.0 + Vector3(0, 6, 0), sgc + Vector3(0, 3, 0))
			await snap.call("_6.png")
			mp.activate_camera()
			mp.position = vl.siitari_park + Vector3(0, 0.5, 0)
			mp.speed = 0.0
			for i in 20:
				await get_tree().physics_frame
			print("MOPO Siitarilla: hint '%s', ovi %s parkki %s" % [_hint.text, vl.siitari_door, vl.siitari_park])
			Input.action_press("interact")
			await get_tree().process_frame
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("MOPO baari: tila %s, valikko auki %s, viesti: %s" % [state, _item_menu.is_open(), _msg.text])
			_item_menu.hide()
			_on_siitari("lahde")
			print("MOPO paluu: kohde %s, aktiivinen %s, %s" % [mopo_trip.target, mopo_trip.active, mopo_trip.status.replace("\n", " / ")])
			mp.position = vl.road_pos(30) + Vector3(0, 0.6, 0)
			for i in 20:
				await get_tree().physics_frame
			print("MOPO Paapelin tiellä: matka jatkuu %s, hint '%s'" % [mopo_trip.active, _hint.text])
			# Pihaan ajettaessa kartta vaihtuu mökille itsestään (ei E:tä).
			mp.position = vl.mokki_mopo + (vl.road_pos(3) - vl.mokki_mopo).normalized() * 6.0 + Vector3(0, 0.6, 0)
			for i in 20:
				await get_tree().physics_frame
			var wl2: Vector3 = mokki.to_local(walker_out.global_position)
			print("MOPO kotona: tila %s, kävelijä mökillä %.1f %.1f, mopo pihassa %s" % [state, wl2.x, wl2.z, mokki.mopo_parked.visible])
			# Toinen kerta: kalja Siitarissa -> Santtu hakee.
			_start_mopo()
			mp.position = vl.siitari_park + Vector3(0, 0.5, 0)
			for i in 10:
				await get_tree().physics_frame
			mopo_trip.stop()
			_on_mopo_arrived()
			var m0 := money
			_item_menu.hide()
			_on_siitari("karhu")
			await get_tree().process_frame
			_item_menu.hide()
			_on_siitari("lahde")
			print("MOPO kalja: rahaa %.2f -> %.2f, humala %.2f, tila %s, viesti: %s" % [m0, money, tilat.value("humala"), state, _msg.text])
			# Vaalan pankkiautomaatti ja auton alle jääminen: auto takaa täydellä vauhdilla, mopo seisoo kaistalla.
			_start_mopo()
			mp.position = vl.atm_pos + Vector3(0, 0.5, 0)
			mp.speed = 0.0
			for i in 10:
				await get_tree().physics_frame
			var m1 := money
			print("MOPO otto: hint '%s'" % _hint.text)
			Input.action_press("interact")
			await get_tree().process_frame
			await get_tree().process_frame
			Input.action_release("interact")
			print("MOPO otto: rahaa %.2f -> %.2f, viesti: %s" % [m1, money, _msg.text])
			var si2 := 300
			var d2: Vector3 = vl.road_dir(si2)
			mp.position = vl.road_pos(si2) + d2.cross(Vector3.UP) * 1.6 + Vector3(0, 0.5, 0)
			mp.rotation.y = atan2(-d2.x, -d2.z)
			mp.speed = 0.0
			var car0: Node3D = mopo_trip._cars[0]
			car0.set_line_t(float(si2 - 5), 1)
			for i in 90:
				await get_tree().physics_frame
				if state == "cutscene":
					break
			await snap.call("_kuolema.png")
			print("MOPO kolari: tila %s, alaotsikko: %s" % [state, cutscene._sub.text])
			for i in 900:
				await get_tree().process_frame
				if state != "cutscene":
					break
			print("MOPO kolarin jälkeen: tila %s, kotona %s, päivä %d" % [state, player.global_position.distance_to(home_zone) < 12.0, day])
		"liikenne":
			# Kylän liikenne: autojen määrä ja liike, K-Marketin automaatti kahdesti ja auton alle jääminen.
			var cars: Array = _hazards.get_children().filter(func(c): return c is TrafficCar)
			var p0: Array = cars.map(func(c): return c.global_position)
			for i in 180:
				await get_tree().physics_frame
			var moved: Array = []
			for i in cars.size():
				moved.append(roundi(cars[i].global_position.distance_to(p0[i])))
			print("LIIKENNE autoja %d, liikkuneet 3 s: %s" % [cars.size(), moved])
			_toggle_mount()
			_build_atm()
			walker_out.global_position = _atm_node.global_position + Vector3(0, 0.5, -1.0)
			for i in 10:
				await get_tree().physics_frame
			var mm := money
			for k in 2:
				Input.action_press("interact")
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
				print("LIIKENNE otto %d: rahaa %.2f -> %.2f, viesti: %s" % [k + 1, mm, money, _msg.text])
			var ac2 := Camera3D.new()
			add_child(ac2)
			ac2.look_at_from_position(_atm_node.global_position + Vector3(2.5, 2.0, -4.5), _atm_node.global_position + Vector3(0, 1.2, 0))
			ac2.current = true
			for i in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_otto.png"))
			walker_out.activate_camera()
			ac2.queue_free()
			# Pelaaja auton eteen.
			var c0: Node3D = cars[0]
			var fw: Vector3 = -c0.global_transform.basis.z
			walker_out.global_position = c0.global_position + fw * 3.0 + Vector3(0, 0.3, 0)
			for i in 60:
				await get_tree().physics_frame
				if state == "cutscene":
					break
			print("LIIKENNE kolari: tila %s" % state)
		"mokkiviina":
			# Viinakätköt: paikat, HUD:n suunta ja matka kätkön vieressä (kuva _hud), kävely kätkölle ja avaus E:llä.
			viina_found = []
			_toggle_mount()
			var vp: Array[Vector2] = Mokki.viina_positions()
			print("VIINA paikat ", vp, " mökistä ", vp.map(func(q: Vector2) -> int: return roundi(q.distance_to(Mokki.COTTAGE_LOCAL))))
			var q0: Vector2 = vp[0]
			var toward := (Mokki.COTTAGE_LOCAL - q0).normalized()
			walker_out.global_position = mokki.gpos(Vector3(q0.x + toward.x * 7.0, 0.6, q0.y + toward.y * 7.0))
			walker_out.look_at(mokki.gpos(Vector3(q0.x, 0.6, q0.y)))
			for i in 60:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_hud.png"))
			print("VIINA HUD ", _stats.text.replace("\n", " | "))
			var vc := Camera3D.new()
			add_child(vc)
			vc.look_at_from_position(mokki.gpos(Vector3(q0.x + 1.6, 1.1, q0.y + 1.2)), mokki.gpos(Vector3(q0.x, 0.1, q0.y)))
			vc.current = true
			_hud.visible = false
			for i in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_katko.png"))
			_hud.visible = true
			vc.queue_free()
			walker_out.activate_camera()
			Input.action_press("forward")
			for i in 300:
				await get_tree().physics_frame
				if _viina_nearest()[2] < 1.2:
					break
			Input.action_release("forward")
			print("VIINA matka %.2f vihje '%s'" % [_viina_nearest()[2], _hint.text])
			Input.action_press("interact")
			await get_tree().process_frame
			await get_tree().process_frame
			Input.action_release("interact")
			print("VIINA löydetyt ", viina_found, " pullot ", viina_pullot, " viesti: ", _msg.text)
		"mokkiview", "mokkisauna", "mokkiyard", "mokkilake":
			_toggle_mount()
			walker_out.global_position = mokki.to_global(Vector3(-2, 0.4, -14))
			for i in 40:
				await get_tree().process_frame
			var cam4 := Camera3D.new()
			add_child(cam4)
			cam4.fov = 60
			if scene == "mokkiview":
				cam4.look_at_from_position(mokki.to_global(Vector3(-16, 9, -22)), mokki.to_global(Vector3(2, 1.5, -1)), Vector3.UP)
			elif scene == "mokkisauna":
				cam4.look_at_from_position(mokki.to_global(Vector3(0, 3.5, 12)), mokki.to_global(Vector3(9, 1.2, 6.5)), Vector3.UP)
				mokki.set_sauna_fire(true)
				mokki.set_tub_fire(true)
			elif scene == "mokkiyard":
				cam4.look_at_from_position(mokki.to_global(Vector3(9, 5, -6)), mokki.to_global(Vector3(2, 1.0, -6)), Vector3.UP)
			else:
				cam4.look_at_from_position(mokki.to_global(Vector3(-4, 4, 20)), mokki.to_global(Vector3(7, 1.2, 24)), Vector3.UP)
			cam4.current = true
		"mokkifish":
			# Soutuvenekalastus: laiturilla E, soutu järvelle (_1), heitto parven kohdalle, tärppi ja väsytys (_2),
			# lopetus F:llä. Tulostaa tilat ja saaliin.
			_toggle_mount()
			var press2 := func() -> void:
				Input.action_press("interact")
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
				await get_tree().process_frame
			var shot2 := func(name: String) -> void:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", name))
			walker_out.global_position = mokki.to_global(Vector3(Mokki.DOCK_LOCAL.x, Mokki.h(Mokki.DOCK_LOCAL.x, Mokki.DOCK_LOCAL.z - 11.6) + 0.7, Mokki.DOCK_LOCAL.z))
			for i in 10:
				await get_tree().physics_frame
			await shot2.call("_0.png")
			print("FISH hint: ", _hint.text)
			_start_fishing()
			await get_tree().process_frame
			var fg: Node = null
			for c in mokki.get_children():
				if c is FishGame:
					fg = c
			print("FISH peli käynnissä: %s, tila %s" % [fg != null, state])
			Input.action_press("forward")
			await get_tree().create_timer(3.0).timeout
			Input.action_release("forward")
			await get_tree().create_timer(2.5).timeout
			await shot2.call("_1.png")
			print("FISH soudettu: paikka %s nopeus %.2f, parvia %d" % [fg._pos, fg._speed, fg._shoals.size()])
			# Vene parven viereen ja heitto sitä kohti.
			var sh: Vector3 = fg._shoals[0]
			var dir: Vector3 = (sh - fg._pos).normalized()
			fg._pos = sh - dir * 8.0
			fg._yaw = atan2(-dir.x, -dir.z)
			fg._speed = 0.0
			Input.action_press("interact")
			await get_tree().create_timer(0.5).timeout
			Input.action_release("interact")
			for i in 4:
				await get_tree().process_frame
			print("FISH heitto: tila %s, koho %s, kala %s" % [fg._state, fg._bob, fg._fish])
			fg._bite_at = fg._t
			for i in 4:
				await get_tree().process_frame
			print("FISH koho sukelsi: tila %s" % fg._state)
			await press2.call()
			print("FISH tärppi: tila %s" % fg._state)
			# Väsytys: pidä E, kun kireys on alle 0,6, muuten päästä.
			var guard := 0
			while fg._state == "reel" and guard < 60 * 40:
				guard += 1
				if fg._tension < 0.6:
					Input.action_press("interact")
				else:
					Input.action_release("interact")
				if guard == 60:
					await shot2.call("_2.png")
				await get_tree().process_frame
			Input.action_release("interact")
			print("FISH väsytys ohi: tila %s, saalis %s, viesti %s" % [fg._state, fg.catch, fg._msg.text])
			Input.action_press("ui_accept")
			var fk := InputEventKey.new()
			fk.keycode = KEY_F
			fk.pressed = true
			Input.parse_input_event(fk)
			await get_tree().create_timer(2.0).timeout
			fk.pressed = false
			Input.parse_input_event(fk)
			Input.action_release("ui_accept")
			await get_tree().process_frame
			print("FISH lopussa: tila %s, saalis %s, viesti %s" % [state, saalis, _msg.text])
			get_tree().quit()
		"mokkipingis":
			# Pingis Santun kanssa: pelaaja lyö automaattisesti, kun pallo on ulottuvilla. Tulostaa pisteet.
			_toggle_mount()
			walker_out.global_position = mokki.to_global(Vector3(Mokki.PINGIS_LOCAL.x, Mokki.h(Mokki.PINGIS_LOCAL.x, Mokki.PINGIS_LOCAL.z) + 0.4, Mokki.PINGIS_LOCAL.z + 1.6))
			for i in 10:
				await get_tree().physics_frame
			print("PINGIS hint: ", _hint.text)
			_start_pingis()
			var pg: Node3D = get_children().filter(func(c): return c is PingisGame)[0]
			var shot_taken := false
			for i in 60 * 40:
				await get_tree().process_frame
				if not is_instance_valid(pg) or pg._phase == "done":
					break
				if pg._phase == "serve" and pg._server == 0:
					pg._serve(0)
				elif pg._phase == "rally" and pg._last == 1 and pg._pl[0].swing_t < 0.0:
					pg._pl[0].x = move_toward(pg._pl[0].x, clampf(pg._land_x(PingisGame.HIT_Y) - 0.45, -PingisGame.X_MAX, -PingisGame.X_MIN), 0.06)
					if pg._ball.distance_to(pg._paddle(0)) < 0.6 and randf() < 0.93:
						pg._swing(0, "smash" if pg._ball.y > 1.8 else "normal", 0.0)
				if not shot_taken and pg._rally >= 3:
					shot_taken = true
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(path.replace(".png", "_rally.png"))
				if i % 300 == 0:
					print("PINGIS t=%d phase=%s rounds=%s rally=%d" % [i / 60, pg._phase, pg._rounds, pg._rally])
			print("PINGIS end state=", state, " msg=", _msg.text)
		"mokkielukat", "mokkielukat2":
			# Metsästyksen eläinmallit rivissä aukealla metsästyslavan edessä.
			_toggle_mount()
			var gl: Vector2 = Mokki.HUNT_GLADE
			var kinds := ["hirvi", "metso", "riekko", "kyyhky", "janis"]
			for i in kinds.size():
				var hgm := HuntGame.new()
				var node: Node3D = hgm._model(kinds[i])
				hgm.free()
				node.scale = Vector3.ONE * HuntGame.SIZE
				var px := gl.x + 2.0
				var pz := gl.y - 6.0 + i * 3.0
				node.position = Vector3(px, Mokki.h(px, pz), pz)
				node.rotation.y = PI / 2.0
				mokki.add_child(node)
			var ec := Camera3D.new()
			add_child(ec)
			ec.look_at_from_position(mokki.to_global(Vector3(gl.x + 9.0, Mokki.h(gl.x + 9.0, gl.y) + 1.6, gl.y)),
				mokki.to_global(Vector3(gl.x + 2.0, Mokki.h(gl.x + 2.0, gl.y) + 0.8, gl.y)))
			if scene == "mokkielukat2":  # hirvi läheltä
				var hz := gl.y - 6.0
				ec.look_at_from_position(mokki.to_global(Vector3(gl.x + 6.5, Mokki.h(gl.x + 6.5, hz + 2.0) + 3.0, hz + 2.5)),
					mokki.to_global(Vector3(gl.x + 2.0, Mokki.h(gl.x + 2.0, hz) + 2.4, hz)))
			ec.current = true
			walker_out.visible = false
		"mokkitikka":
			# Tikanheitto: pisteytyksen tarkistus, 9 heittoa (tähtäys triplakahteenkymppiin) ja kuva taulusta.
			for pt in [Vector2.ZERO, Vector2(0, 0.012), Vector2(0, 0.103), Vector2(0, 0.166), Vector2(0.103, 0), Vector2(0, 0.2)]:
				print("TIKKA piste %s -> %s" % [pt, DartsGame.score(pt)])
			_toggle_mount()
			walker_out.global_position = mokki.to_global(Vector3(Mokki.DART_LOCAL.x, Mokki.h(Mokki.DART_LOCAL.x, Mokki.DART_LOCAL.z) + 0.4, Mokki.DART_LOCAL.z))
			for i in 10:
				await get_tree().physics_frame
			print("TIKKA vihje: ", _hint.text)
			_start_darts()
			var dg: Node3D = mokki.get_children().filter(func(c): return c is DartsGame)[0]
			for i in 30:
				await get_tree().process_frame
			for n in 9:
				dg._aim = Vector2(0, 0.103)
				while dg._phase != "aim":
					await get_tree().process_frame
				dg._aim = Vector2(randf_range(-0.03, 0.03), 0.103 + randf_range(-0.03, 0.03))
				dg._throw()
				while dg._phase == "fly":
					await get_tree().process_frame
				print("TIKKA heitto %d: %s" % [n + 1, dg._sub.text])
				if n == 2:
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(path.replace(".png", "_taulu.png"))
			while is_instance_valid(dg):
				await get_tree().process_frame
			print("TIKKA loppu: ennätys=%d msg=%s" % [tikka_ennatys, _msg.text])
		"mokkijahti":
			# Metsästys: nousee lavalle, odottaa eläimen, tähtää ja ampuu. Tulostaa saaliin.
			_toggle_mount()
			walker_out.global_position = mokki.to_global(Vector3(Mokki.HUNT_LOCAL.x + 1.5, Mokki.h(Mokki.HUNT_LOCAL.x + 1.5, Mokki.HUNT_LOCAL.z) + 0.4, Mokki.HUNT_LOCAL.z))
			for i in 10:
				await get_tree().physics_frame
			print("JAHTI hint: ", _hint.text)
			_start_hunt()
			var hg: Node3D = mokki.get_children().filter(func(c): return c is HuntGame)[0]
			hg._spawn_t = 0.0
			for i in 60 * 3:
				await get_tree().process_frame
			var shots := 0
			for i in 60 * 20:
				await get_tree().process_frame
				var alive: Array = hg._animals.filter(func(a): return a.state in ["walk", "pause"] and a.kind != "hirvi")
				if alive.is_empty() or hg._reload_t > 0.0:
					continue
				var a: Dictionary = alive[0]
				var c: Vector3 = a.pos + Vector3(0, HuntGame.SPECIES[a.kind].cy * HuntGame.SIZE, 0) - hg._eye
				hg._yaw = atan2(c.x, c.z)
				hg._pitch = atan2(c.y, Vector2(c.x, c.z).length())
				await get_tree().process_frame
				if shots == 0:
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(path.replace(".png", "_aim.png"))
				hg._shoot()
				shots += 1
				print("JAHTI shot %d at %s d=%.1f bag=%s" % [shots, a.kind, c.length(), hg.bag])
				if shots >= 3:
					break
			hg._finish("testi")
			while is_instance_valid(hg):
				await get_tree().process_frame
			await get_tree().process_frame
			print("JAHTI end state=", state, " saalis=", saalis, " msg=", _msg.text)
		"mokkisavustus":
			# Savustus: saalis savustimeen, halkoja, valmis, eväiksi ja syönti.
			_toggle_mount()
			saalis = [{"type": "kala", "nom": "hauki"}, {"type": "riista", "nom": "jänis"}]
			var kp := Mokki.KITCHEN_LOCAL
			walker_out.global_position = mokki.to_global(Vector3(kp.x, Mokki.h(kp.x, kp.z) + 0.4, kp.z))
			var press3 := func() -> void:
				Input.action_press("interact")
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
			for i in 10:
				await get_tree().physics_frame
			print("SAVU hint: ", _hint.text)
			await press3.call()
			print("SAVU loaded=", smoker_load, " msg=", _msg.text)
			for k in 3:
				await press3.call()
			var t_end := Time.get_ticks_msec() + 120000
			var n := 0
			while Time.get_ticks_msec() < t_end:
				n += 1
				await get_tree().process_frame
				if smoker_temp < 95.0 and smoker_fuel < 0.35 and n % 20 == 0:
					await press3.call()
				if n % 600 == 0:
					print("SAVU t=%d temp=%.0f fuel=%.2f progress=%.2f burnt=%.2f hint=%s" % [n / 60, smoker_temp, smoker_fuel, smoker_progress, smoker_burnt, _hint.text])
				if smoker_progress >= 1.0:
					break
			var cam5 := Camera3D.new()
			add_child(cam5)
			cam5.look_at_from_position(mokki.to_global(kp + Vector3(3.0, 2.2, -2.5)), mokki.to_global(kp + Vector3(0, 1.0, 1.0)), Vector3.UP)
			cam5.current = true
			for i in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_smoke.png"))
			player.activate_camera()
			await get_tree().process_frame
			print("SAVU done progress=%.2f hint=%s state=%s" % [smoker_progress, _hint.text, state])
			await press3.call()
			print("SAVU out food=", food, " msg=", _msg.text)
			var n0: float = tilat.value("nalka")
			_on_eat("savuriista")
			print("SAVU ate nalka %+.2f food=%s" % [tilat.value("nalka") - n0, food])
		"edgetest":
			for spot in [Vector2(3, 1500), Vector2(450, 3), Vector2(1000, 3957), Vector2(1617, 3000), Vector2(893, 1500)]:
				_edge_cd = 0.0
				player.global_position = M.w(spot) + Vector3(0, 0.5, 0)
				for i in 8:
					await get_tree().physics_frame
				print("EDGE ", spot, " -> ", _msg.text)
		"kotapath":
			# Kodalle vievä polku: se tie tai polku, jonka jokin piste on lähimpänä kotaa.
			var pts: Array = []
			var bestd := INF
			for r in M.ROADS:
				for q: Vector2 in r.pts:
					if r.pts.size() > 7 and q.distance_to(M.KOTA) < bestd:
						bestd = q.distance_to(M.KOTA)
						pts = r.pts
			player.global_position = M.w(pts[5]) + Vector3(0, 0.5, 0)
			player.rotation.y = B.yaw_to(M.w(pts[6]) - M.w(pts[5]))
		"kotagrid":
			var rows := []
			for zi in range(-8, 9):
				var row := ""
				for xi in range(-8, 13):
					var g: Vector3 = world.kota.to_global(Vector3(xi * 2.0, 0, zi * 2.0))
					var sf: String = world.surface_at(g)
					row += "~" if sf == "water" else ("o" if xi == 0 and zi == 0 else ("b" if sf == "bog" else "."))
				rows.append(row)
			print("KGRID local x -16..24 (step 2), z -16..16 (top = -z = door side)")
			for r in rows:
				print("KGRID ", r)
		"minimouse":
			# Oikeat hiiritapahtumat minipeleille: liike kääntää tähtäystä, vasen nappi toimii, sahan veto.
			_toggle_mount()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			var send := func(ev: InputEvent) -> void:
				Input.parse_input_event(ev)
				await get_tree().process_frame
				await get_tree().process_frame
			kota_polkyt = 1
			_start_chop()
			await get_tree().process_frame
			var cg: Node3D = world.kota.get_children().filter(func(c): return c is ChopGame)[0]
			cg._gust_next = 999.0
			var y0: float = cg._yaw
			var mm := InputEventMouseMotion.new()
			mm.relative = Vector2(-120, 0)
			mm.position = get_viewport().get_visible_rect().size / 2.0
			await send.call(mm)
			print("MOUSE chop yaw ", y0, " -> ", cg._yaw, " mouse_mode=", Input.mouse_mode)
			var want: Vector2 = cg._aim_to(ChopGame.PILE + Vector3(0, 0.18, 0))
			cg._yaw = want.x
			cg._pitch = want.y
			await get_tree().process_frame
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = mm.position
			await send.call(click)
			var up := click.duplicate()
			up.pressed = false
			await send.call(up)
			print("MOUSE chop after click phase=", cg._phase)
			# Aseta oikein päin keskelle ja iske vähän sivuun: kirves jää kiinni, peli ei saa jumittua.
			if not cg._flat_down:
				cg._alt_action()
			want = cg._aim_to(Vector3(0, ChopGame.BLOCK_TOP, 0))
			cg._yaw = want.x
			cg._pitch = want.y
			for i in 3:
				await get_tree().process_frame
			await send.call(click)
			await send.call(up)
			for i in 60:
				await get_tree().process_frame
				if cg._phase == "chop":
					break
			want = cg._aim_to(cg._log_pos + Vector3(0.08, ChopGame.LOG_L, 0))
			cg._yaw = want.x
			cg._pitch = want.y
			await get_tree().process_frame
			await send.call(click)
			await send.call(up)
			for i in 400:
				await get_tree().process_frame
				if cg._phase == "chop" and cg._swing_t < 0.0:
					break
			print("MOUSE chop stuck hit -> phase=", cg._phase, " swing_t=", cg._swing_t, " cracks=", cg._cracks, " sub=", cg._sub.text)
			cg._quit()
			await get_tree().process_frame
			_start_saw()
			await get_tree().process_frame
			var sg: Node3D = world.kota.get_children().filter(func(c): return c is SawGame)[0]
			sg._gust_next = 999.0
			var a3: Vector2 = sg._aim_to(Vector3(0, SawGame.LOG_Y + SawGame.R, SawGame.END_Z - 0.36))
			sg._yaw = a3.x
			sg._pitch = a3.y
			await get_tree().process_frame
			await send.call(click)
			await send.call(up)
			print("MOUSE saw after click phase=", sg._phase)
			var s0: float = sg._s
			var mv := InputEventMouseMotion.new()
			mv.relative = Vector2(0, -40)
			mv.position = mm.position
			await send.call(mv)
			print("MOUSE saw stroke s ", s0, " -> ", sg._s, " depth=", sg._depth)
			sg._quit()
			await get_tree().process_frame
		"nappaimet":
			# Näppäinasetukset: E -> R toiminnolle, sitten R pyörälle (poistuu toiminnolta), ohjeteksti ja kuva.
			menu.open_main()
			menu._settings("sub_main")
			for i in 5:
				await get_tree().process_frame
			var tabs: TabContainer = menu.find_children("*", "TabContainer", true, false)[0]
			tabs.current_tab = tabs.get_tab_count() - 1
			var key := func(code: int) -> void:
				var ev := InputEventKey.new()
				ev.physical_keycode = code as Key
				ev.pressed = true
				Input.parse_input_event(ev)
				await get_tree().process_frame
				ev = ev.duplicate()
				ev.pressed = false
				Input.parse_input_event(ev)
				await get_tree().process_frame
			var row_of := func(a: String) -> int:
				for r in Settings.KEY_ROWS.size():
					if a in Settings.KEY_ROWS[r][0]:
						return r
				return -1
			var btn := func(row: int, slot: int) -> Button:
				for kb in menu._key_buttons:
					if kb[0] == row and kb[1] == slot:
						return kb[2]
				return null
			(btn.call(row_of.call("interact"), 0) as Button).pressed.emit()
			await key.call(KEY_R)
			print("NAPP toiminto=%s E-painallus->interact=%s R->interact=%s" % [Settings.keys_of(row_of.call("interact")),
				InputMap.action_has_event("interact", (func() -> InputEventKey:
					var e := InputEventKey.new(); e.physical_keycode = KEY_E; return e).call()),
				InputMap.action_has_event("interact", (func() -> InputEventKey:
					var e := InputEventKey.new(); e.physical_keycode = KEY_R; return e).call())])
			(btn.call(row_of.call("mount"), 0) as Button).pressed.emit()
			await key.call(KEY_R)
			print("NAPP pyörä=%s toiminto=%s viesti=%s" % [Settings.keys_of(row_of.call("mount")), Settings.keys_of(row_of.call("interact")), menu._key_note.text])
			(btn.call(row_of.call("interact"), 0) as Button).pressed.emit()
			await key.call(KEY_G)
			(btn.call(row_of.call("forward"), 1) as Button).pressed.emit()
			await key.call(KEY_ESCAPE)
			print("NAPP esc: eteen=%s viesti=%s valikko auki=%s" % [Settings.keys_of(0), menu._key_note.text, menu.visible])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_nappaimet.png"))
			menu.close()
			await get_tree().process_frame
			print("NAPP vihje: ", Settings.key_hint("[E] Avaa ovi   [F] Pyörälle   [Q] kello   [A] ei vaihdu"))
			for i in 20:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			print("NAPP pelin vihje: ", _hint.text)
			Settings.reset_keys()
			print("NAPP palautus: toiminto=%s pyörä=%s" % [Settings.keys_of(row_of.call("interact")), Settings.keys_of(row_of.call("mount"))])
		"settingsmenu":
			menu.open_main()
			menu._settings("sub_main")
			for i in 10:
				await get_tree().process_frame
			var wk: Button = null
			for b in menu.find_children("*", "Button", true, false):
				if (b as Button).text.begins_with("Heikko kone"):
					wk = b
			print("ASETUKSET ennen: laatu=%d skaala=%.1f etäisyys=%d" % [Settings.get_v("quality"), Settings.get_v("render_scale"), Settings.get_v("view_distance")])
			if wk != null:
				wk.pressed.emit()
			for i in 10:
				await get_tree().process_frame
			print("ASETUKSET jälkeen: laatu=%d skaala=%.1f etäisyys=%d usva_loppu=%.0f kaukoraja=%.0f" % [Settings.get_v("quality"),
				Settings.get_v("render_scale"), Settings.get_v("view_distance"), _env.fog_depth_end, Settings.view_far()])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_asetukset.png"))
		"kotaplay":
			# Koko ketju: sahaa, pilko, sytytä, kuuntele tarina. Tulostaa tilat.
			_toggle_mount()
			var press := func() -> void:
				Input.action_press("interact")
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
				await get_tree().process_frame
			# Sahaus: merkkaa 36 cm, vedä sahaa suorassa, kunnes pölkky katkeaa. Kaksi pölkkyä.
			walker_out.global_position = world.kota.to_global(Kota.SAW_LOCAL + Vector3(-0.8, 0, 0.3)) + Vector3(0, 0.4, 0)
			for i in 10:
				await get_tree().physics_frame
			print("KOTA hint: ", _hint.text)
			await press.call()
			var sg: Node3D = world.kota.get_children().filter(func(c): return c is SawGame)[0] if state == "minigame" else null
			print("SAW state=", state, " sg=", sg != null)
			sg._gust_next = 999.0
			for n in 2:
				var a2: Vector2 = sg._aim_to(Vector3(0, SawGame.LOG_Y + SawGame.R, SawGame.END_Z - 0.36))
				sg._yaw = a2.x
				sg._pitch = a2.y
				for i in 5:
					await get_tree().process_frame
				if n == 0:
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(path.replace(".png", "_mark.png"))
					await get_tree().process_frame
				await press.call()
				print("SAW phase=", sg._phase, " cut_z=", sg._cut_z, " task=", sg._task.text)
				var dir := 1.0
				for i in 900:
					if sg._phase != "saw":
						break
					sg._tilt_hand = -(sg._tilt - sg._tilt_hand)  # pidä suorassa
					sg._stroke(dir * 0.02)
					if absf(sg._s) >= SawGame.STROKE - 0.001:
						dir = -dir
					await get_tree().process_frame
					if n == 0 and i == 120:
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png(path.replace(".png", "_saw.png"))
				print("SAW cut done phase=", sg._phase, " made=", sg.polkyt_made, " polkyt=", kota_polkyt, " sub=", sg._sub.text)
				for i in 30:
					await get_tree().process_frame
				if n == 0:
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(path.replace(".png", "_cut.png"))
				for i in 600:
					if sg._phase == "mark":
						break
					await get_tree().process_frame
			sg._quit()
			await get_tree().process_frame
			print("SAW after state=", state, " msg=", _msg.text)
			# Halonhakkuu: väärin päin asetettu pyörähtää pois, oikein päin keskelle ja isku keskelle.
			walker_out.global_position = world.kota.to_global(Kota.CHOP_LOCAL + Vector3(0.8, 0, 0)) + Vector3(0, 0.4, 0)
			for i in 10:
				await get_tree().physics_frame
			print("KOTA hint: ", _hint.text)
			await press.call()
			var cg: Node3D = world.kota.get_children().filter(func(c): return c is ChopGame)[0] if state == "minigame" else null
			print("CHOP state=", state, " cg=", cg != null)
			cg._gust_next = 999.0
			var aim := func(target: Vector3) -> void:
				var dv: Vector3 = target - ChopGame.EYE
				cg._yaw = atan2(dv.x, dv.z)
				cg._pitch = -atan2(-dv.y, Vector2(dv.x, dv.z).length())
			aim.call(ChopGame.PILE + Vector3(0, 0.18, 0))
			for i in 5:
				await get_tree().process_frame
			await press.call()
			print("CHOP phase=", cg._phase, " flat=", cg._flat_down)
			if cg._flat_down:
				cg._alt_action()
			aim.call(Vector3(0, ChopGame.BLOCK_TOP, 0))
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_hold.png"))
			await get_tree().process_frame
			await press.call()
			print("CHOP after wrong place phase=", cg._phase, " sub=", cg._sub.text)
			for i in 30:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_roll.png"))
			for i in 60:
				await get_tree().process_frame
			aim.call(ChopGame.PILE + Vector3(0, 0.18, 0))
			await get_tree().process_frame
			await press.call()
			if not cg._flat_down:
				cg._alt_action()
			aim.call(Vector3(0, ChopGame.BLOCK_TOP, 0))
			for i in 20:
				await get_tree().process_frame
			await press.call()
			print("CHOP after good place phase=", cg._phase, " sub=", cg._sub.text)
			for i in 40:
				await get_tree().process_frame
			aim.call(Vector3(cg._log_pos.x, ChopGame.BLOCK_TOP + ChopGame.LOG_L, cg._log_pos.z))
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_aim.png"))
			await get_tree().process_frame
			await press.call()
			for i in 24:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_split.png"))
			for i in 50:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_split2.png"))
			print("CHOP after hit phase=", cg._phase, " sub=", cg._sub.text, " polkyt=", kota_polkyt, " halot=", kota_halot)
			for i in 90:
				await get_tree().process_frame
			cg._quit()
			await get_tree().process_frame
			print("KOTA polkyt=", kota_polkyt, " halot=", kota_halot, " state=", state, " msg=", _msg.text)
			walker_out.global_position = world.kota.to_global(Vector3(0.9, 0.4, -1.4))
			for i in 10:
				await get_tree().physics_frame
			print("KOTA hint: ", _hint.text)
			await press.call()
			print("KOTA fire=", world.kota.fire_on, " halot=", kota_halot)
			for i in 5:
				await get_tree().physics_frame
			print("KOTA hint: ", _hint.text)
			await press.call()
			for i in 60:
				await get_tree().process_frame
			print("KOTA story state=", state, " msg=", _msg.text)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_story.png"))
			for i in 2400:
				await get_tree().process_frame
				if state != "cutscene":
					break
			print("KOTA after state=", state, " kuultu=", tarinat_kuultu, " msg=", _msg.text)
			# Torni: portaita ylös kävellen.
			var base: Vector3 = world.kota.to_global(Kota.TOWER_LOCAL)
			print("TOWER base ground ", Terrain.h(base.x, base.z))
			var run := Kota.TOWER_TOP_Y / tan(deg_to_rad(33.0))
			var tb := Basis(Vector3.UP, world.kota.global_rotation.y - 0.5)
			var foot: Vector3 = base + tb * Vector3(0, 0, -1.75 - run - 1.2)
			walker_out.global_position = foot + Vector3(0, 0.5, 0)
			walker_out.rotation.y = world.kota.global_rotation.y - 0.5 + PI  # kohti tornia (+Z)
			for i in 20:
				await get_tree().physics_frame
			Input.action_press("forward")
			for i in 900:
				await get_tree().physics_frame
				if i % 120 == 0 or (i > 500 and _hint.text != "" and i % 30 == 0):
					print("TOWER t=", i, " spd=", walker_out.speed, " y=%.2f ground=%.2f hint=%s" % [walker_out.global_position.y, Terrain.h(walker_out.global_position.x, walker_out.global_position.z), _hint.text])
			Input.action_release("forward")
		"chocotest":
			# Suklaa karkkitelineestä, maksu, ulos ja WASTED: lepyttääkö Päivin? Tallennus palautetaan lopuksi.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var ok := 0
			for i in 1000:
				has_chocolate = true
				ok += int(_offer_chocolate() == "ok")
			print("CHOCO ok-osuus %.2f" % (ok / 1000.0))
			_enter_shop()
			for i in 10:
				await get_tree().physics_frame
			interior.walker.position = interior.CANDY_SPOT
			for i in 5:
				await get_tree().physics_frame
			print("CHOCO hint=", interior.hint)
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("CHOCO cart=", interior.cart, " total=", interior._total())
			interior.has_paid = true
			_on_shop_exited(false)
			print("CHOCO has_chocolate=", has_chocolate, " money=", money)
			_lose("Testi", "wife")
			print("CHOCO mercy=", _choco_mercy, " has_chocolate=", has_chocolate)
			for i in 60:
				await get_tree().create_timer(0.5, true, false, true).timeout
				if state != "cutscene":
					break
			print("CHOCO after state=", state, " money=", money, " msg=", _msg.text.replace("\n", " | "))
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"kosketus":
			# Kosketusohjaimet (--touch): tatti eteen ajaa pyörällä, Pyörä-nappi nousee selästä, veto kääntää kameraa.
			var touch := func(i: int, p: Vector2, down: bool) -> void:
				var ev := InputEventScreenTouch.new()
				ev.index = i
				ev.position = p
				ev.pressed = down
				Input.parse_input_event(ev)
			var drag := func(i: int, p: Vector2, rel: Vector2) -> void:
				var ev := InputEventScreenDrag.new()
				ev.index = i
				ev.position = p
				ev.relative = rel
				Input.parse_input_event(ev)
			for i in 30:
				await get_tree().physics_frame
			var vs := get_viewport().get_visible_rect().size
			var p0 := player.global_position
			touch.call(0, Vector2(200, vs.y - 200), true)
			drag.call(0, Vector2(200, vs.y - 290), Vector2(0, -90))
			for i in 120:
				await get_tree().physics_frame
			print("KOSKETUS tatti: matka %.1f m, forward=%s shift=%s" % [player.global_position.distance_to(p0),
				Input.is_action_pressed("forward"), Input.is_key_pressed(KEY_SHIFT)])
			touch.call(0, Vector2(200, vs.y - 290), false)
			for i in 60:
				await get_tree().physics_frame
			var yaw0 := CamCtl.yaw
			touch.call(1, Vector2(vs.x * 0.6, vs.y * 0.3), true)
			await get_tree().process_frame
			drag.call(1, Vector2(vs.x * 0.6 + 80, vs.y * 0.3), Vector2(80, 0))
			await get_tree().process_frame
			await get_tree().process_frame
			touch.call(1, Vector2(vs.x * 0.6 + 80, vs.y * 0.3), false)
			print("KOSKETUS veto: yaw %.3f -> %.3f" % [yaw0, CamCtl.yaw])
			var on_bike := player == bike
			for i in 90:
				await get_tree().physics_frame
			print("KOSKETUS ennen nappia: vauhti %.2f vihje '%s'" % [bike.velocity.length(), _hint.text])
			touch.call(2, Vector2(vs.x - 330, vs.y - 250), true)
			for i in 6:
				await get_tree().process_frame
			touch.call(2, Vector2(vs.x - 330, vs.y - 250), false)
			for i in 10:
				await get_tree().physics_frame
			print("KOSKETUS Pyörä-nappi: pyörällä %s -> %s" % [on_bike, player == bike])
		"placecheck":
			# Hahmojen, ajoneuvojen ja pelipaikkojen paikat: tien reunan etäisyys (negatiivinen = tiellä) ja
			# osuuko kohta talon, auton tai muun esteen sisään (fysiikkakysely 1 m maan yläpuolella).
			for i in 3:
				await get_tree().physics_frame
			var space := get_world_3d().direct_space_state
			var checks := [["koti_aloitus", home_zone + Vector3(0, 0, 4), null],
				["kauppa_taksi", world.taxi_pos, null], ["kauppa_vyohyke", shop_zone, null], ["mummot", mummot.global_position, mummot],
				["arto", arto.global_position, arto], ["pekka", pekka.global_position, pekka],
				["sulo", sulo.global_position, sulo], ["sinikka", sinikka.global_position, sinikka], ["vaino_alku", world.neighbor_yards["pekka"][0], null],
				["paivi_alku", world.graph_nodes[world.nearest_node(M.w(M.J_T))], null], ["laavu", M.w(M.LAAVU), null],
				["kota_raimo", world.kota.raimo.global_position, world.kota.raimo],
				["kota_veikko", world.kota.veikko.global_position, world.kota.veikko],
				["traktori", tractor.global_position, tractor], ["grilli", M.w(M.GRILLIKATOS), null],
				["kompostijemma", M.w(M.COMPOST), null], ["autotallijemma", M.w(M.GARAGE) + Vector3(-3.8, 0, 3.6), null],
				["leikkuri", M.w(M.MOWER_PARK), null],
				["nurmikko_1", _lawn_corner(-1, -1), null], ["nurmikko_2", _lawn_corner(1, -1), null],
				["nurmikko_3", _lawn_corner(1, 1), null],
				["nurmikko_4", _lawn_corner(-1, 1), null], ["agility", M.w((M.AGILITY[0] + M.AGILITY[2]) / 2.0), null]]
			for k in M.JUNTTI_SPOTS.size():
				checks.append(["juntti%d" % k, M.w(M.JUNTTI_SPOTS[k]), null])
			for k in M.STRAY_SPOTS.size():
				checks.append(["koira%d" % k, M.w(M.STRAY_SPOTS[k]), null])
			for k in M.BALES.size():
				checks.append(["paali%d" % k, M.w(M.BALES[k]), null])
			for nv in [arto, pekka, sinikka]:  # reitit puuhapisteiden välillä esteiden ohi
				for i in nv.yard.size():
					if nv._inside(Vector2(nv.yard[i].x, nv.yard[i].z)):
						print("REITTI %s piste %d esteen sisällä" % [nv.display_name, i])
					for j in nv.yard.size():
						var a: Vector3 = nv.yard[i]
						var r: Array[Vector3] = nv._plan(a, nv.yard[j])
						var pts: Array[Vector2] = [Vector2(a.x, a.z)]
						for q in r:
							pts.append(Vector2(q.x, q.z))
						pts.append(Vector2(nv.yard[j].x, nv.yard[j].z))
						for k in pts.size() - 1:
							if i != j and nv._blocked(pts[k], pts[k + 1]):
								print("REITTI %s %d->%d menee esteen läpi" % [nv.display_name, i, j])
								break
			for key: String in world.neighbor_yards:  # naapurien pihan puuhapisteet
				var yd: Array = world.neighbor_yards[key]
				for k in range(1, yd.size()):
					checks.append(["%s_piha%d" % [key, k], yd[k], null])
			for k in BIKE_DUMPS.size():
				checks.append(["pyora%d" % k, M.w(BIKE_DUMPS[k]), null])
			for c in checks:
				var p: Vector3 = c[1]
				var q := PhysicsPointQueryParameters3D.new()
				q.position = Vector3(p.x, Terrain.h(p.x, p.z) + 1.0, p.z)
				q.collision_mask = 0xFFFFFFFF & ~Terrain.COLLISION_LAYER
				var hits := []
				for h in space.intersect_point(q, 8):
					var col: Node = h.collider
					if c[2] != null and (col == c[2] or (c[2] as Node).is_ancestor_of(col)):
						continue
					hits.append("%s@%s" % [col.name, M.to_px((col as Node3D).global_position).round()])
				print("PLACE %s px=%s tie=%.1f talo=%s pinta=%s osumat=%s" % [c[0], M.to_px(p).round(),
					world._road_clearance(Vector2(p.x, p.z)), world._near_house(Vector2(p.x, p.z), 6.0), world.surface_at(p), hits])
			var outside := 0
			for h: Vector2 in world._houses:
				if not world._in_bounds(h, -1.0):
					outside += 1
			print("PLACE talot yhteensä %d, pelialueen ulkopuolella %d" % [world._houses.size(), outside])
			print("PLACE kota %s (OSM %s), torni %s (OSM %s), grillikatos %s, laavu %s" % [
				M.to_px(world.kota.global_position).round(), M.KOTA, M.to_px(world.kota.to_global(Kota.TOWER_LOCAL)).round(),
				M.LINTUTORNI, M.GRILLIKATOS, M.LAAVU])
		"hilltest":
			# Jyrkin rinne tien varrella: aja ylös ja alas, pysyykö pyörä maan pinnalla.
			var best := Vector3.ZERO
			var slope := 0.0
			for r in M.ROADS:
				for q in r.pts:
					var wq := M.w(q)
					var n := Terrain.normal(wq.x, wq.z)
					if 1.0 - n.y > slope:
						slope = 1.0 - n.y
						best = wq
			var n2 := Terrain.normal(best.x, best.z)
			player.global_position = best + Vector3(0, 0.4, 0)
			player.rotation.y = atan2(n2.x, n2.z)  # kohti ylämäkeä
			print("HILL at ", best, " slope %.1f %%" % (Vector2(n2.x, n2.z).length() / n2.y * 100.0))
			Input.action_press("forward")
			for i in 360:
				await get_tree().physics_frame
				if i % 60 == 0:
					var p := player.global_position
					print("HILL t=", i, " y=%.2f ground=%.2f speed=%.1f" % [p.y, Terrain.h(p.x, p.z), player.speed])
			Input.action_release("forward")
		"sprinttest":
			# Pisin suora tie: ensin tavallinen poljenta, sitten spurtti (Shift), kunnes kunto loppuu.
			var a := Vector3.ZERO
			var b := Vector3.ZERO
			for r in M.ROADS:
				for j in r.pts.size() - 1:
					var p0 := M.w(r.pts[j])
					var p1 := M.w(r.pts[j + 1])
					if p0.distance_to(p1) > a.distance_to(b):
						a = p0
						b = p1
			if player != bike:
				_toggle_mount()
			var d := (b - a).normalized()
			bike.global_position = Vector3(a.x, Terrain.h(a.x, a.z) + 0.4, a.z)
			bike.rotation.y = atan2(-d.x, -d.z)
			print("SPRINT road %.0f m" % a.distance_to(b))
			var shift := InputEventKey.new()
			shift.keycode = KEY_SHIFT
			Input.action_press("forward")
			for i in 600:
				if i == 180:
					shift.pressed = true
					Input.parse_input_event(shift)
				await get_tree().physics_frame
				if i % 60 == 59:
					print("SPRINT t=%d speed=%.1f stamina=%.0f sprinting=%s exhausted=%s fov=%.1f" % [i, bike.speed,
						walker_out.stamina, bike.sprinting, walker_out.exhausted, bike._cam.fov])
			shift.pressed = false
			Input.parse_input_event(shift)
			Input.action_release("forward")
			# Jalan: juoksu kuluttaa kuntoa, eikä parkissa oleva pyörä saa palauttaa sitä samalla.
			for i in 120:
				await get_tree().physics_frame
			_toggle_mount()
			walker_out.stamina = 100.0
			walker_out.exhausted = false
			shift.pressed = true
			Input.parse_input_event(shift)
			Input.action_press("forward")
			for i in 120:
				await get_tree().physics_frame
			print("SPRINT jalan 2 s juoksua: stamina=%.0f (odotus ~64)" % walker_out.stamina)
			shift.pressed = false
			Input.parse_input_event(shift)
			Input.action_release("forward")
		"tractortest":
			# Onnistunut kotiinpaluu ja sen jälkeen pellolle: jemmarin pitää hyökätä.
			state = "to_home"
			beers = 0
			jemma = 6
			_win()
			for i in 5:
				await get_tree().physics_frame
			print("AFTER WIN hazards process_mode=", _hazards.process_mode, " state=", state)
			player.position = M.w(Vector2(304, 735)) + Vector3(0, 0.3, 0)
			var hit := -1
			for i in 600:
				await get_tree().physics_frame
				if state == "fight":
					hit = i
					break
			print("TRACTOR after win: fight at frame ", hit, " mode=", tractor.mode)
		"fightfx":
			beers = 6
			_on_kicked(Vector3.RIGHT)
			for i in 130:
				await get_tree().process_frame
			fight._j.position.x = fight._p.position.x + 1.2
			fight._p._start_attack("spin")
			for i in 14:
				await get_tree().process_frame
			fight._j.take_hit(12.0, 1.0, 3.2)
			fight.on_hit(fight._p, fight._j, false, "kick")
			fight.on_hit(fight._p, fight._j, false, "punch")
			for i in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()
			return
		"trailsign":
			var a3 := M.w2(M.J_H2)
			var d3 := (M.w2(Vector2(846, 1300)) - a3).normalized()
			var at3 := a3 + d3 * 5.0 + d3.orthogonal() * 3.0
			var cam := Camera3D.new()
			cam.fov = 40.0
			add_child(cam)
			var n3 := Vector3(-d3.y, 0, d3.x)
			var sp := Vector3(at3.x, 1.55, at3.y) + Vector3(d3.x, 0, d3.y) * 0.8
			cam.look_at_from_position(sp + n3 * 2.4 + Vector3(0, 0.2, 0), sp, Vector3.UP)
			cam.current = true
		"infoboard":
			var cam := Camera3D.new()
			cam.fov = 40.0
			add_child(cam)
			var ib := M.w(M.LAAVU) + Vector3(3.6, 0, -3.2)
			var nrm := Vector3(-sin(0.45), 0, -cos(0.45))
			cam.look_at_from_position(ib + Vector3(0, 1.5, 0) - nrm * -2.6, ib + Vector3(0, 1.4, 0), Vector3.UP)
			cam.current = true
			guard.visible = false
		"guardleave":
			player.position = M.w(M.LAAVU) + Vector3(0, 0.3, -20)
			guard.defeat()
			for i in 520:
				await get_tree().process_frame
		"overlap":
			# Polku ja tie päällekkäin: Järvikujan pää, josta laavupolku lähtee.
			player.position = M.w(M.J_H2) + Vector3(-4, 0.3, -9)
			player.rotation.y = PI + 0.2
		"walk":
			_toggle_mount()
			walker_out.rotation.y += 0.6
			walker_out.stamina = 30.0
			walker_out.exhausted = true
		"walkmap":
			_toggle_mount()
			walker_out.global_position += Vector3(40, 0, -60)
			for n in find_children("*", "Control", true, false):
				if n.has_method("toggle"):
					n.toggle()
		"hedgeclose":
			var cam := Camera3D.new()
			cam.fov = 50.0
			add_child(cam)
			var hb2 := M.w(M.HOME_BUILDING)
			cam.look_at_from_position(hb2 + Vector3(-19, 1.6, 6), hb2 + Vector3(-14, 0.8, -2), Vector3.UP)
			cam.current = true
			_msg.text = ""
		"cars":
			var cam := Camera3D.new()
			cam.fov = 45.0
			add_child(cam)
			var hb3 := M.w(M.HOME_BUILDING)
			cam.look_at_from_position(hb3 + Vector3(-20, 1.6, -7), hb3 + Vector3(-14, 0.8, 0), Vector3.UP)
			cam.current = true
			_msg.text = ""
		"tractorside", "tractorfront", "tractortop":
			player.position = M.w(Vector2(304, 735)) + Vector3(0, 0.3, 0)
			var cam3 := Camera3D.new()
			cam3.fov = 40.0
			add_child(cam3)
			tractor.set_physics_process(false)
			var tb := tractor.global_transform.basis
			var tp3 := tractor.global_position + tb * Vector3(0, 1.9, 0.75)
			var off: Vector3 = {"tractorside": tb * Vector3(6.0, 0.2, 0), "tractorfront": tb * Vector3(0, 0.4, -6.5),
				"tractortop": tb * Vector3(0.01, 6.0, 0.3)}[scene]
			cam3.look_at_from_position(tp3 + off, tp3, Vector3.UP if scene != "tractortop" else -tb.z)
			cam3.current = true
			_msg.text = ""
		"tractorclose":
			player.position = M.w(Vector2(304, 735)) + Vector3(0, 0.3, 0)
			player.rotation.y = PI / 2.0
			var cam2 := Camera3D.new()
			cam2.fov = 45.0
			add_child(cam2)
			var tp2 := tractor.global_position
			cam2.look_at_from_position(tp2 + Vector3(-5.5, 2.0, -4.0), tp2 + Vector3(0, 1.3, 0), Vector3.UP)
			cam2.current = true
			tractor.set_physics_process(false)
			_msg.text = ""
		"sinikkatehtava":
			# Sinikan mustikkatehtävä: pyyntö, odotus ilman marjoja, luovutus 2 l:lla ja piirakka reppuun.
			_toggle_mount()
			var press := func() -> void:
				Input.action_press("interact")
				await get_tree().process_frame
				Input.action_release("interact")
				for i in 5:
					await get_tree().process_frame
			sinikka.set_physics_process(false)
			var sp2: Vector3 = sinikka.yard[0]
			sinikka.global_position = sp2
			walker_out.global_position = sp2 + Vector3(1.5, 0.4, 0)
			for i in 20:
				await get_tree().physics_frame
			print("SINIKKA vihje: ", _hint.text)
			await press.call()
			print("SINIKKA pyyntö: tehtävä=%d msg=%s" % [sinikka_task, _msg.text])
			await press.call()
			print("SINIKKA odotus: msg=%s" % _msg.text)
			bucket["mustikka"] = 3
			for i in 3:
				await get_tree().process_frame
			print("SINIKKA vihje marjoilla: ", _hint.text)
			await press.call()
			print("SINIKKA luovutus: tehtävä=%d ämpäri=%s piirakka=%d msg=%s" % [sinikka_task, bucket, food.get("mustikkapiirakka", 0), _msg.text])
			await press.call()
			print("SINIKKA sama päivä uudestaan: tehtävä=%d" % sinikka_task)
			var n0: float = tilat.value("nalka")
			_open_eat_menu()
			print("SINIKKA syömävalikko: ", _item_menu._items)
			_item_menu.visible = false
			_item_menu.chosen.emit("mustikkapiirakka")
			print("SINIKKA söi piirakan: nälkä %+.2f, piirakoita %d, msg=%s" % [tilat.value("nalka") - n0, food.get("mustikkapiirakka", 0), _msg.text])
		"sinikka":
			# Sinikka läheltä edestä vinosti (ulkonäkö ja asusteet).
			for i in 30:
				await get_tree().process_frame
			sinikka.set_physics_process(false)
			var sp: Vector3 = sinikka.yard[0]
			var hc := M.w(M.NEIGHBOR_SINIKKA)
			var fwd := Vector3(sp.x - hc.x, 0, sp.z - hc.z).normalized()
			sinikka.global_position = sp
			sinikka.rotation.y = B.yaw_to(fwd)
			var sc := Camera3D.new()
			sc.fov = 40.0
			add_child(sc)
			sc.look_at_from_position(sp + fwd * 3.2 + fwd.cross(Vector3.UP) * 1.2 + Vector3(0, 1.4, 0), sp + Vector3(0, 1.05, 0), Vector3.UP)
			sc.current = true
			_msg.text = ""
		"naapurit", "naapurit2", "naapurit3":  # naapurin talo ja piha kadulta päin (arto / pekka / sinikka)
			var key: String = {"naapurit": "arto", "naapurit2": "pekka", "naapurit3": "sinikka"}[scene]
			var yd: Array = world.neighbor_yards[key]
			var door: Vector3 = yd[0]
			var hc := M.w({"arto": M.NEIGHBOR_ARTO, "pekka": M.NEIGHBOR_PEKKA, "sinikka": M.NEIGHBOR_SINIKKA}[key])
			var out := Vector3(door.x - hc.x, 0, door.z - hc.z).normalized()
			var cam := Camera3D.new()
			cam.fov = 65.0
			add_child(cam)
			cam.look_at_from_position(door + out * 13.0 + out.rotated(Vector3.UP, 1.2) * 5.0 + Vector3(0, 4.0, 0),
				door + Vector3(0, 1.0, 0), Vector3.UP)
			cam.current = true
			_msg.text = ""
		"kupla":
			# Puhekupla läheltä ja kaukaa: Pekka sanoo pitkän repliikin, kamera 1,6 m / 4 m / 9 m päästä.
			pekka.set_physics_process(false)
			var pp: Vector3 = pekka.yard[0]
			pekka.global_position = pp
			var fwd := Vector3(0, 0, 1)
			pekka.rotation.y = B.yaw_to(fwd)
			pekka.say(PEKKA_LINES[3] + " " + PEKKA_LINES[1])
			var kc := Camera3D.new()
			add_child(kc)
			kc.current = true
			for dist in [1.6, 4.0, 9.0]:
				kc.look_at_from_position(pp + fwd * dist + Vector3(0, 1.5, 0), pp + Vector3(0, 1.8, 0), Vector3.UP)
				await get_tree().create_timer(0.4).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%d.png" % int(dist * 10)))
				pekka.say(PEKKA_LINES[3] + " " + PEKKA_LINES[1])
		"fpsmitta":
			# Kuvataajuus eri asetuksilla (kodin edessä, katse Järvikujaa pitkin). Tallennetut asetukset palautetaan.
			var keep := {}
			for k in ["quality", "render_scale", "view_distance"]:
				keep[k] = Settings.get_v(k)
			_note.hide()
			await get_tree().create_timer(2.0).timeout
			var cfgs := [["täysi laatu, 100 %, täysi etäisyys", 3, 1.0, 3], ["erittäin matala, 50 %, täysi etäisyys", 0, 0.5, 3],
				["erittäin matala, 50 %, keski 350 m", 0, 0.5, 1], ["erittäin matala, 50 %, lyhyt 200 m", 0, 0.5, 0],
				["erittäin matala, 100 %, lyhyt 200 m", 0, 1.0, 0], ["täysi laatu, 100 %, lyhyt 200 m", 3, 1.0, 0]]
			for c in cfgs:
				Settings.set_v("quality", c[1])
				Settings.set_v("render_scale", c[2])
				Settings.set_v("view_distance", c[3])
				await get_tree().create_timer(1.5).timeout
				var f0 := Engine.get_process_frames()
				var t0 := Time.get_ticks_msec()
				await get_tree().create_timer(4.0).timeout
				var fps := float(Engine.get_process_frames() - f0) / ((Time.get_ticks_msec() - t0) / 1000.0)
				var vp: RID = get_viewport().get_viewport_rid()
				print("FPS %5.1f  %s | kutsuja %d, kolmioita %d, kohteita %d | prosessi %.1f ms, fysiikka %.1f ms" % [fps, c[0],
					RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
					RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
					RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
			for k in keep:
				Settings.set_v(k, keep[k])
		"fpsosat":
			# Mikä kuluttaa aikaa: laatu 0 / 50 % / 200 m, sitten kutakin pääsolmua vuorotellen pois päältä (prosessi + fysiikka).
			Settings.set_v("quality", 0)
			Settings.set_v("render_scale", 0.5)
			Settings.set_v("view_distance", 0)
			_note.hide()
			var measure := func(label: String) -> void:
				await get_tree().create_timer(0.8).timeout
				var f0 := Engine.get_process_frames()
				var t0 := Time.get_ticks_msec()
				await get_tree().create_timer(2.5).timeout
				print("FPS %5.1f  %s" % [float(Engine.get_process_frames() - f0) / ((Time.get_ticks_msec() - t0) / 1000.0), label])
			await measure.call("perus (minikartta näkyvissä)")
			print("marja- ja sienipaikkoja: %d (näkyvät kartalla: %s)" % [world.forage.size(), world.forage_revealed])
			_minimap.visible = false
			await measure.call("minikartta piilossa")
			_minimap.visible = true
			await measure.call("minikartta taas näkyvissä")
			_minimap.visible = false
			await measure.call("minikartta piilossa (toisto)")
			_minimap.visible = true

		"minikartta":
			# Minikartan liikkuvat osat: pelaajan nuoli, Päivi, pyörä (kun jalan), tavoite, marja- ja sienipaikat, merkit.
			_toggle_mount()
			world.forage_revealed = true
			var fp: Vector3 = world.forage[0].pos
			walker_out.global_position = Vector3(fp.x + 6.0, Terrain.h(fp.x + 6.0, fp.z), fp.z)
			bike.global_position = walker_out.global_position + Vector3(-55, 0, 40)
			wife.global_position = walker_out.global_position + Vector3(70, 0, -45)
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_a.png"))
			# Liike: kävellään eteenpäin, kartan pitää seurata ja nuolen kääntyä.
			var o0: Vector2 = _minimap._origin
			Input.action_press("forward")
			for i in 90:
				await get_tree().physics_frame
			Input.action_release("forward")
			for i in 3:
				await get_tree().process_frame
			print("MINIKARTTA keskipiste siirtyi %.1f m, marjapaikkoja %d, Päivi näkyvissä=%s pyörä=%s" % [
				(_minimap._origin - o0).length(), world.forage.size(), wife.is_inside_tree(), bike != player])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_b.png"))
		"kotivessa":
			# Kodin WC: sisään etuovesta, kävely tupakeittiöstä WC:hen pöntön eteen, E -> valikko -> ykkönen -> minipeli.
			_toggle_mount()
			state = "to_shop"
			_enter_home("ovi")
			for i in 5:
				await get_tree().process_frame
			var w: CharacterBody3D = home_int.walker
			# Kävellen: etuovelta suoraan eteenpäin tupakeittiöön, vasemmalle WC:n ovelle ja sisään pöntön luo.
			var kylpy := OS.get_cmdline_user_args().has("--kylpy")
			var route: Array = [Vector3(-2.5, 0, 0.5), Vector3(-2.5, 0, 4.0), Vector3(1.2, 0, 4.0), Vector3(1.2, 0, 2.75)] if kylpy \
				else [Vector3(-2.5, 0, 0.5), Vector3(-5.0, 0, 0.5), Vector3(-8.6, 0, 0.5)]
			for tgt in route:
				for i in 240:
					var to: Vector3 = tgt - w.position
					to.y = 0.0
					if to.length() < 0.25:
						break
					w.position += to.normalized() * minf(0.06, to.length())
					w.velocity = Vector3.ZERO
					await get_tree().physics_frame
			for i in 3:
				await get_tree().process_frame
			print("KOTIVESSA paikka=%s vihje=%s" % [w.position, home_int.hint])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_wc.png"))
			await get_tree().process_frame  # kuvakaappauksen jälkeen: painallus ruudun alkuun
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			for i in 3:
				await get_tree().process_frame
			print("KOTIVESSA valikko auki=%s tila=%s" % [_item_menu.is_open(), _menu_mode])
			if _item_menu.is_open():
				_item_menu.visible = false
				_item_menu.chosen.emit("ykkonen")
				for i in 5:
					await get_tree().process_frame
				print("KOTIVESSA minipeli käynnissä=%s" % [is_instance_valid(_wc_game) and _wc_game.is_inside_tree()])
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_peli.png"))
		"minipelikuvat":
			# Kuvat WC- ja tiskausminipeleistä: ykkönen (lätäköitä), kakkonen (paperivaihe), huussi ja tiskaus.
			_hud.visible = false
			var shot := func(name: String) -> void:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s.png" % name))
			for cfg in [["ykkonen", true], ["kakkonen", true], ["kakkonen", false]]:
				var g := WcGame.new()
				g.mode = cfg[0]
				g.flush = cfg[1]
				add_child(g)
				for i in 30:
					await get_tree().process_frame
				if g.mode == "ykkonen":
					g._aim = Vector2(40, -20)
					for k in 6:
						g._puddles.append(Vector2(200 + k * 12, 60 + (k % 3) * 10))
					g._inside = 3.0
					g._total = 4.0
				else:
					g._pushes = 3
					g._phase = "paper"
					g._sheets = 5
				for i in 5:
					await get_tree().process_frame
				await shot.call("%s_%s" % [cfg[0], "vesi" if cfg[1] else "huussi"])
				g._done = true
				g.queue_free()
			var tg := TiskiGame.new()
			add_child(tg)
			for i in 10:
				await get_tree().process_frame
			tg.washed = 2
			tg.dishes_left = TiskiGame.DISHES.size() - 5  # mummon kukkalautanen esille
			tg._dirt = 0.45
			tg._wobble = 0.6
			tg._last_dir = 1
			for i in 5:
				await get_tree().process_frame
			await shot.call("tiski")
			tg.dishes_left = TiskiGame.DISHES.size() - 1  # muki
			tg._dirt = 0.8
			for i in 5:
				await get_tree().process_frame
			await shot.call("tiski_muki")
		"pitkalappu":
			# Pitkä lappu: kaikki päivän muistutukset kerralla; lapun pitää mahtua kokonaan ruudulle.
			var many := ["Laitoin 12,00 € kauppaa varten.", "Eilen ei tullu kaupasta mitään, vaikka oli lista!",
				PAIVI_MORNING_SINIKKA[0], "Löysin sun kaljat eteisen kaapista ja kaadoin 6 viemäriin!",
				LAWN_NAG_PAIVI[2], LAWN_NAG_ANNALIISA[0], "Pyörä ei oo pihassa. Mihin sää sen taas jätit?",
				HANGOVER_NOTE.paivi, STAT_TIPS.paivi.vireys[0],
				STAT_TIPS.paivi.stressi[1], STAT_TIPS.paivi.keskittyminen[0]]
			_day_note(MORNING_HEAD.mokilta[0], "
".join(many))
			await get_tree().create_timer(1.2).timeout
			var rect: Rect2 = _note._paper.get_global_rect()
			print("PITKALAPPU ruutu=%s lappu=%s asteikko=%s" % [get_viewport().get_visible_rect().size, rect, _note._holder.scale])
		"homeview", "homeview2":
			var cam := Camera3D.new()
			cam.fov = 55.0
			add_child(cam)
			var hb := M.w(M.HOME_BUILDING)
			var eye := M.w(Vector2(826, 1186)) + Vector3(0, 1.7, 0) if scene == "homeview" else M.w(Vector2(822, 1150)) + Vector3(0, 1.7, 0)
			cam.look_at_from_position(eye, hb + Vector3(0, 1.8, 0), Vector3.UP)
			cam.current = true
			_msg.text = ""
		"mkey":
			for i in 30:
				await get_tree().process_frame
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_M
			ev.keycode = KEY_M
			ev.pressed = true
			Input.parse_input_event(ev)
			for i in 3:
				await get_tree().process_frame
			ev = ev.duplicate()
			ev.pressed = false
			Input.parse_input_event(ev)
			print("PAPER visible=", _paper.visible, " paused=", get_tree().paused)
			var sc0: float = _paper._scroll
			Input.action_press("back")
			for i in 30:
				await get_tree().process_frame
			Input.action_release("back")
			print("PAPER scroll ", sc0, " -> ", _paper._scroll, " max ", _paper._max_scroll())
			ev = ev.duplicate()
			ev.pressed = true
			Input.parse_input_event(ev)
			for i in 3:
				await get_tree().process_frame
			ev = ev.duplicate()
			ev.pressed = false
			Input.parse_input_event(ev)
			for i in 3:
				await get_tree().process_frame
			print("PAPER after 2nd M visible=", _paper.visible, " paused=", get_tree().paused)
		"fpsview":
			CamCtl.fps = true
			CamCtl.pitch = -0.1
		"orbit":
			CamCtl.yaw = 2.3
			CamCtl.pitch = -0.3
			CamCtl._idle = 0.0
		"fpswalk":
			_toggle_mount()
			CamCtl.fps = true
			CamCtl.pitch = -0.25
			CamCtl.yaw = 0.8
		"wasted":
			for i in 20:
				await get_tree().process_frame
			_lose("Päivi nappasi kiinni!", "wife")
			for i in 60:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_1.png"))
			for i in 210:
				await get_tree().process_frame
		"garage":
			beers = 0
			jemma = 26
			_win(true)
			print("GARAGE jemma=", jemma)
			for i in 200:
				await get_tree().process_frame
		"sunset":
			beers = 5
			fire_lit = true
			sausage_done = true
			stash_laavu = 7
			_win_laavu()
			print("SUNSET laavu=", stash_laavu, " jemma=", jemma, " beers=", beers)
			for i in 300:
				await get_tree().process_frame
		"grilli":
			player.position = M.w(M.GRILLIKATOS) + Vector3(-3, 0.3, 8)
			player.rotation.y = 0.3
		"stash":
			laavu_conquered = true
			guard.vanish()
			_toggle_mount()
			walker_out.global_position = M.w(M.LAAVU) + Vector3(3.8, 0.3, 1.4)
			walker_out.rotation.y = -0.6
			beers = 6
			jemma = 10
			for i in 20:
				await get_tree().process_frame
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("STASH laavu=", stash_laavu, " beers=", beers)
		"carbump":
			# Hiljaa tuleva auto tönäisee (ei hit-signaalia), lujaa tuleva tappaa (hit-signaali).
			_toggle_mount()
			for i in 10:
				await get_tree().physics_frame
			for c in [[5.0, 3.5], [16.0, 4.0]]:
				var hits := [0]
				var stunned := false
				var car := TrafficCar.new()
				car.cruise = c[0]
				car.lane = 0.0
				car.target_fn = func() -> Node3D: return walker_out
				car.hit.connect(func() -> void: hits[0] += 1)
				add_child(car)
				var wp := walker_out.global_position
				var pts := []
				for k in 41:
					var x := wp.x - 40.0 + k * 2.0
					pts.append(Vector3(x, Terrain.h(x, wp.z), wp.z))
				car.setup_line(pts, (40.0 - c[1]) / 2.0, 1)
				for i in 90:
					await get_tree().physics_frame
					stunned = stunned or walker_out.is_stunned()
				print("CARBUMP cruise=", c[0], " hits=", hits[0], " stunned=", stunned)
				car.queue_free()
				for i in 120:
					await get_tree().physics_frame
				walker_out.global_position = wp
		"startcheck":
			# Oikea käynnistys (kuvan nimi *menu.png ohittaa testitilan): tallennettu pyörä, valikosta jatkoon, kävely.
			menu.close()
			await get_tree().process_frame
			var p0 := player.global_position
			var c0 := get_viewport().get_camera_3d().global_position
			Input.action_press("forward")
			for i in 60:
				await get_tree().physics_frame
			Input.action_release("forward")
			print("STARTCHECK on_foot=", player == walker_out, " mode=", walker_out.process_mode,
				" moved=%.1f cam_moved=%.1f" % [player.global_position.distance_to(p0),
				get_viewport().get_camera_3d().global_position.distance_to(c0)])
		"bikestay":
			# Pyörä kaupalle, uusi päivä kotoa: pyörän pitää jäädä, pelaaja jalan. Sitten tallennus.
			var left := shop_zone + Vector3(6, 0.3, 6)
			bike.global_position = left
			_new_day(home_zone + Vector3(0, 0, 4), false)
			for i in 30:
				await get_tree().physics_frame
			print("BIKESTAY on_foot=", player == walker_out, " bike_moved=%.2f" % bike.global_position.distance_to(left),
				" walker_home=%.1f" % walker_out.global_position.distance_to(home_zone), " msg=", _msg.text.replace("\n", " | "))
			_save_game()
		"bikeload":
			print("BIKELOAD saved=", _bike_saved, " note=", _apply_saved_bike().strip_edges(), " on_foot=", player == walker_out,
				" bike_at_shop=%.1f" % bike.global_position.distance_to(shop_zone))
		"stashtour":
			# Jokainen jemma: E piilottaa yhden, Q ottaa yhden, kuva paikasta.
			laavu_conquered = true
			guard.vanish()
			_toggle_mount()
			_hud.visible = true
			for id in STASHES:
				var at := _stash_pos(id)
				walker_out.global_position = at + Vector3(1.6, 0.6, 1.6)
				walker_out.look_at(Vector3(at.x, walker_out.global_position.y, at.z))
				walker_out.velocity = Vector3.ZERO
				beers = 3
				walker_out.set_carrying(true)
				for i in 40:
					await get_tree().process_frame
				print("STASH ", id, " at ", at, " hint=", _hint.text)
				var before: int = stash.get(id, 0)
				Input.action_press("interact")
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
				print("  E: ", before, " -> ", stash.get(id, 0), " beers=", beers)
				Input.action_press("bell")
				await get_tree().process_frame
				Input.action_release("bell")
				await get_tree().process_frame
				print("  Q: -> ", stash.get(id, 0), " beers=", beers)
				_msg.text = ""
				var tc := Camera3D.new()
				add_child(tc)
				tc.global_position = at + Vector3(5.0, 3.5, 5.0)
				tc.look_at(at, Vector3.UP)
				tc.current = true
				for i in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_" + id + ".png"))
				tc.queue_free()
				walker_out.activate_camera()
		"carry":
			laavu_conquered = true
			guard.vanish()
			_toggle_mount()
			walker_out.global_position = M.w(M.LAAVU) + Vector3(3.8, 0.3, 1.4)
			bike.global_position = walker_out.global_position + Vector3(1.0, 0, 0)
			stash_laavu = 15
			for i in 20:
				await get_tree().process_frame
			Input.action_press("bell")
			await get_tree().process_frame
			Input.action_release("bell")
			await get_tree().process_frame
			print("CARRY took beers=", beers, " laavu=", stash_laavu)
			Input.action_press("mount")
			await get_tree().process_frame
			Input.action_release("mount")
			await get_tree().process_frame
			print("CARRY on_bike=", player == bike, " hint=", _hint.text, " msg=", _msg.text)
		"found":
			_hud.visible = false
			cutscene.jemma_found(home_zone, 8, 12, func() -> void: pass)
			for i in 330:
				await get_tree().process_frame
		"shopfront":
			player.position = shop_zone + Vector3(0, 0.3, 14)
		"shopsigns":
			# Kaupan kyltit (KASSA, OLUET, GRILLI, ULOS) yleiskuvana ilman leijuvia opasteita.
			_enter_shop()
			var sc := Camera3D.new()
			add_child(sc)
			sc.global_position = INTERIOR_POS + Vector3(2.0, 9.0, 14.0)
			sc.look_at(INTERIOR_POS + Vector3(0, 1.0, 0), Vector3.UP)
			sc.current = true
		"mokkipesuovi":
			# Pesuhuoneen ovi: kuistilta sisään pesuhuoneeseen, pesuhuoneen ovesta ulos saman oven eteen, kuva ovesta.
			var press2 := func() -> void:
				Input.action_press("interact")
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
			_toggle_mount()
			walker_out.global_position = mokki.porch2_pos(0.4)
			for i in 10:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("PESUOVI kuistilla hint=", _hint.text)
			await press2.call()
			print("PESUOVI sisällä state=%s walker=%s" % [state, mokki_int.walker.position])
			for i in 5:
				await get_tree().process_frame
			print("PESUOVI sisävihje=", mokki_int.hint)
			await press2.call()
			for i in 5:
				await get_tree().physics_frame
			var lp := mokki.to_local(walker_out.global_position)
			print("PESUOVI ulkona state=%s paikka=%s (ovi %s)" % [state, lp, Mokki.DOOR2_LOCAL])
			var oc := Camera3D.new()
			add_child(oc)
			oc.look_at_from_position(mokki.porch2_pos(4.5) + Vector3(1.5, 0.6, 0), mokki.porch2_pos(-0.6) + Vector3(0, 0.3, 0), Vector3.UP)
			oc.current = true
		"mokkisisalla":
			# Mökin sisätila: ovelta sisään, toiminnot, kuva, ulos ja nukkumaan (päivä vaihtuu). Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var press := func(action: String) -> void:
				await get_tree().process_frame  # painallus ennen solmujen _processia (just_pressed samassa ruudussa)
				Input.action_press(action)
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			_toggle_mount()
			walker_out.global_position = mokki.porch_pos(0.4)
			for i in 10:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("SISA ovella hint=", _hint.text)
			await press.call("interact")
			print("SISA state=", state, " hint=", _hint.text)
			for id in ["kahvi", "jaakaappi", "takka", "tv", "suihku", "wc", "sauna"]:
				mokki_int.walker.position = mokki_int.SPOTS[id][0]
				await get_tree().process_frame
				await get_tree().process_frame
				var h: String = mokki_int.hint
				await press.call("interact")
				print("SISA %s: hint=%s -> msg=%s" % [id, h, _msg.text])
			print("SISA tilat: ", tilat.summary(), " food=", food)
			mokki_int.walker.position = Vector3(-1.0, 0, 1.0)
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_tupa.png"))
			await get_tree().process_frame
			mokki_int.walker.position = Vector3(3.0, 0, -3.8)
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_pesu.png"))
			mokki_int.walker.position = mokki_int.SPOTS.ovi2[0]
			await get_tree().process_frame
			await get_tree().process_frame
			print("SISA ovi2 hint=", mokki_int.hint)
			mokki_int.walker.position = mokki_int.SPOTS.ovi[0]
			await get_tree().process_frame
			await press.call("interact")
			for i in 5:
				await get_tree().physics_frame
			print("SISA ulos state=%s porch_y=%.2f" % [state, mokki.to_local(walker_out.global_position).y])
			walker_out.global_position = mokki.porch_pos(0.4)
			for i in 5:
				await get_tree().physics_frame
			await get_tree().process_frame
			await press.call("interact")
			mokki_int.walker.position = mokki_int.SPOTS.sanky[0]
			await get_tree().process_frame
			await get_tree().process_frame
			var d0 := day
			await press.call("interact")
			for i in 10:
				await get_tree().process_frame
			print("SISA nukuttu day %d -> %d state=%s near_mokki=%.1f msg=%s" % [d0, day, state,
				walker_out.global_position.distance_to(mokki.global_position), _msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"drooni":
			# Drooni: alustan vihje, nousu, lento, kuvat kotitalosta ja K-Marketista, paluu kotiin (H) ja laskeutuminen.
			# Kuvat _pad, _fpv, _chase. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var snap := func(suffix: String) -> void:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", suffix))
			var key := func(k: Key) -> void:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				ev.pressed = true
				Input.parse_input_event(ev)
				await get_tree().process_frame
				ev = ev.duplicate()
				ev.pressed = false
				Input.parse_input_event(ev)
				await get_tree().process_frame
			drone_photos.clear()
			_toggle_mount()
			var pad: Vector3 = world.drone_pad_pos
			print("DROONI pad->home_zone %.1f m" % Vector2(pad.x - home_zone.x, pad.z - home_zone.z).length())
			walker_out.global_position = pad + Vector3(1.2, Terrain.h(pad.x, pad.z) + 0.3, 0.6)
			walker_out.rotation.y = B.yaw_to(pad - walker_out.global_position)
			for i in 20:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("DROONI hint=", _hint.text)
			await snap.call("_pad.png")
			var top := Camera3D.new()
			add_child(top)
			top.global_position = pad + Vector3(0, 28, 0.01)
			top.look_at(pad, Vector3.UP)
			top.current = true
			for i in 3:
				await get_tree().process_frame
			await snap.call("_padtop.png")
			top.queue_free()
			walker_out.activate_camera()
			await get_tree().process_frame  # kuvakaappauksen jälkeen: painallus seuraavan ruudun alkuun
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("DROONI state=", state, " drone=", _drone != null)
			var dg: Node3D = _drone
			Input.action_press("jump")
			for i in 150:
				await get_tree().physics_frame
			Input.action_release("jump")
			print("DROONI nousu: kork %.1f m landed=%s" % [dg.body.global_position.y - dg._home_ground, dg._landed])
			Input.action_press("forward")
			for i in 180:
				await get_tree().physics_frame
			Input.action_release("forward")
			print("DROONI eteen: kotiin %.1f m nopeus %.1f" % [dg._home_dist(), dg._vel.length()])
			await snap.call("_fpv.png")
			# Kuva kotitalosta: käännytään taloa kohti ja kamera alas.
			var hb := M.w(M.HOME_BUILDING)
			var to: Vector3 = hb - dg.body.global_position
			dg._yaw = atan2(-to.x, -to.z)
			dg._gimbal = -atan2(dg.body.global_position.y - hb.y, Vector2(to.x, to.z).length())
			for i in 5:
				await get_tree().physics_frame
			await dg.take_photo()
			print("DROONI kuva koti: photos=", drone_photos, " msg=", dg._warn.text)
			# Pontikkapannun yläpuolelle (siirretään suoraan) ja kuva alas.
			var pk := M.w(M.PONTIKKA)
			dg.body.global_position = pk + Vector3(0, 60, 30)
			dg._yaw = 0.0
			dg._gimbal = -atan2(60.0, 30.0)
			for i in 30:
				await get_tree().physics_frame
			await dg.take_photo()
			print("DROONI kuva pontikka: photos=", drone_photos, " found=", pontikka_found)
			await snap.call("_pontikka.png")
			CamCtl.fps = false
			dg.body.global_position = world.drone_pad_pos + Vector3(40, 30, 20)
			for i in 40:
				await get_tree().physics_frame
			await snap.call("_chase.png")
			await key.call(KEY_H)
			print("DROONI H mode=", dg._mode)
			for i in 60 * 25:
				await get_tree().physics_frame
				if _drone == null:
					break
			print("DROONI loppu: state=%s drone=%s akku=%.2f msg=%s" % [state, _drone != null, drone_battery, _msg.text])
			# Törmäys: uusi lento ja isku seinään.
			drone_battery = 1.0
			walker_out.global_position = pad + Vector3(1.2, Terrain.h(pad.x, pad.z) + 0.3, 0.6)
			for i in 5:
				await get_tree().physics_frame
			_start_drone()
			await get_tree().process_frame
			dg = _drone
			dg._landed = false
			dg.body.global_position = hb + Vector3(-20, 3, 0)
			dg._vel = Vector3(18, 0, 0)
			dg._yaw = -PI / 2.0
			Input.action_press("forward")
			for i in 60 * 5:
				await get_tree().physics_frame
				if _drone == null:
					break
			Input.action_release("forward")
			print("DROONI törmäys: broken=%s msg=%s" % [drone_broken_day == day, _msg.text])
			await get_tree().process_frame
			print("DROONI hint rikki=", _hint.text)
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"mokkidrooni":
			# Drooni mökillä: alustan vihje, nousu, kuva mökistä ja järvestä, laskeutuminen (H) ja järveen putoaminen.
			# Kuvat _pad, _fpv, _chase. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var snap := func(suffix: String) -> void:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", suffix))
			drone_photos.clear()
			drone_battery = 1.0
			_toggle_mount()
			var pad := _drone_pad(true)
			walker_out.global_position = pad + Vector3(1.2, 0.3, 0.6)
			for i in 20:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("MDROONI at_mokki=%s pad=%s parked=%s hint=%s" % [_at_mokki(), pad, _drone_parked.position, _hint.text])
			print("MDROONI kohteet: ", _mokki_drone_names().values())
			await snap.call("_pad.png")
			await get_tree().process_frame  # kuvakaappauksen jälkeen: painallus seuraavan ruudun alkuun
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			var dg: Node3D = _drone
			print("MDROONI state=%s drone=%s total=%d" % [state, dg != null, dg.photo_total])
			Input.action_press("jump")
			for i in 200:
				await get_tree().physics_frame
			Input.action_release("jump")
			print("MDROONI nousu: kork %.1f m" % (dg.body.global_position.y - dg._home_ground))
			var mc: Vector3 = mokki.gpos(Vector3(0, 1, -1))
			var to: Vector3 = mc - dg.body.global_position
			dg._yaw = atan2(-to.x, -to.z)
			dg._gimbal = -atan2(-to.y, Vector2(to.x, to.z).length())
			for i in 5:
				await get_tree().physics_frame
			await dg.take_photo()
			print("MDROONI kuva: ", drone_photos, " ", dg._warn.text)
			# Järven yläpuolelle ja kuva alas.
			for id in _mokki_lakes:
				var lk: Vector3 = mokki.to_global(_mokki_lakes[id])
				dg.body.global_position = lk + Vector3(0, 50, 25)
				dg._yaw = 0.0
				dg._gimbal = -atan2(50.0, 25.0)
				for i in 10:
					await get_tree().physics_frame
				await dg.take_photo()
				print("MDROONI järvi %s: %s" % [id, dg._warn.text])
				break
			await snap.call("_fpv.png")
			CamCtl.fps = false
			dg.body.global_position = pad + Vector3(30, 25, 20)
			for i in 40:
				await get_tree().physics_frame
			await snap.call("_chase.png")
			Input.action_press("forward")  # alueen raja: kaukana mökistä käännytään takaisin
			dg.body.global_position = MOKKI_POS + Vector3(MOKKI_DRONE_R + 5.0, 0, 0)
			dg.body.global_position.y = dg.ground.call(dg.body.global_position.x, dg.body.global_position.z) + 60.0
			for i in 5:
				await get_tree().physics_frame
			Input.action_release("forward")
			print("MDROONI raja: vel=%s msg=%s" % [dg._vel, dg._warn.text])
			dg.body.global_position = pad + Vector3(10, 20, 10)
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_H
			ev.pressed = true
			Input.parse_input_event(ev)
			for i in 60 * 20:
				await get_tree().physics_frame
				if _drone == null:
					break
			print("MDROONI loppu: state=%s drone=%s msg=%s" % [state, _drone != null, _msg.text])
			# Järveen pudotus: uusi lento ja lasku veden päälle.
			await get_tree().process_frame
			_start_drone()
			await get_tree().process_frame
			dg = _drone
			var lake: Vector3 = mokki.gpos(Mokki.DOCK_LOCAL + Vector3(0, 0, 15))
			dg._landed = false
			dg.body.global_position = lake + Vector3(0, 1.05, 0)  # h() on järven pohja, pinta metrin ylempänä
			print("MDROONI vesi=%s" % dg.is_water.call(lake.x, lake.z))
			for i in 60 * 5:
				await get_tree().physics_frame
				if _drone == null:
					break
			print("MDROONI järveen: broken=%s msg=%s" % [drone_broken_day == day, _msg.text])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"reppu":
			# Reppu täynnä tavaraa Saloisissa (kuva _reppu), sitten mökille: HUD ilman pääpelin tehtäviä, pyörän
			# välimatka ja repun mökkinäkymä (kuva _reppu_mokki). Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var snap := func(suffix: String) -> void:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", suffix))
			beers = 9
			has_sausage = true
			has_matches = true
			has_chocolate = true
			has_ball = true
			has_kanister = true
			has_mower_part = true
			bucket = {"puolukka": 3, "kantarelli": 2, "herkkutatti": 1, "mustikka": 2}
			food = {"pulla": 2, "piirakka": 1, "savukala": 3, "savuriista": 1, "karrella": 1}
			saalis = [{"type": "kala", "nom": "hauki"}, {"type": "kala", "nom": "ahven"}, {"type": "kala", "nom": "ahven"},
				{"type": "riista", "nom": "jänis"}, {"type": "riista", "nom": "metso"}, {"type": "riista", "nom": "riekko"},
				{"type": "riista", "nom": "kyyhky"}]
			kota_polkyt = 2
			kota_halot = 5
			paivi_bag = {shopping_list[0][0]: "vihreä", shopping_list[1][0]: "punainen"}
			await get_tree().process_frame
			print("REPPU HUD saloinen: ", _stats.text.replace("\n", " | "))
			_inventory.toggle()
			for i in 5:
				await get_tree().process_frame
			_inventory._hover = 0
			_inventory.queue_redraw()
			await snap.call("_reppu.png")
			_inventory.toggle()
			await get_tree().process_frame
			_toggle_mount()
			walker_out.global_position = mokki.porch_pos(3.0)
			for i in 10:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("REPPU HUD mökki: ", _stats.text.replace("\n", " | "), " status=", _status.text,
				" hazards=", _hazards.process_mode)
			Input.action_press("mount")
			await get_tree().process_frame
			Input.action_release("mount")
			await get_tree().process_frame
			print("REPPU pyörä: ", _msg.text)
			var e0 := elapsed
			for i in 30:
				await get_tree().process_frame
			print("REPPU aika mökillä %.2f -> %.2f" % [e0, elapsed])
			_inventory.toggle()
			for i in 5:
				await get_tree().process_frame
			await snap.call("_reppu_mokki.png")
			_inventory.toggle()
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"mokkipa":
			# PA-kytkentä: väärä järjestys (pääte ensin = paukku), oikeat johdot, virrat, kierto mikistä, tasot
			# vihreälle ja voitto. Kuvat: _pa_board (kesken), _pa_tupa (soi) ja _pa_ulkona. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var snap := func(suffix: String) -> void:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", suffix))
			_toggle_mount()
			walker_out.global_position = mokki.porch_pos(0.4)
			for i in 10:
				await get_tree().physics_frame
			_enter_mokki()
			mokki_int.walker.position = mokki_int.SPOTS.pa[0]
			for i in 3:
				await get_tree().process_frame
			print("PA hint=", mokki_int.hint)
			_on_mokki_acted("pa")
			var pg: Node = get_children().filter(func(c): return c is PaGame)[0]
			print("PA virhe tyyppi: ", pg.connect_ports("puh_out", "mix_ch1"), " -> ", pg._sub.text)
			for pr in [["puh_out", "mix_ch2"], ["mic_out", "mix_ch1"], ["mix_main_l", "amp_in_a"], ["mix_main_r", "amp_in_b"],
					["amp_out_a", "spk_l_in"], ["amp_out_b", "spk_r_in"], ["jj_1", "mix_pow"], ["amp_pow", "jj_2"]]:
				if not pg.connect_ports(pr[0], pr[1]):
					print("PA kytkentä epäonnistui ", pr, " ", pg._sub.text)
			print("PA path_ok=", pg.path_ok(), " task=", pg._task.text)
			pg.amp_sw = true
			for i in 3:
				await get_tree().process_frame
			print("PA pääte ensin: strikes=", pg.strikes, " sub=", pg._sub.text)
			pg.amp_sw = false
			await get_tree().process_frame
			pg.mix_sw = true
			await get_tree().process_frame
			pg.amp_sw = true
			await get_tree().process_frame
			print("PA oikea järjestys: strikes=", pg.strikes, " task=", pg._task.text)
			pg.faders.ch1 = 0.8
			pg.faders.master = 0.8
			for i in 60:
				await get_tree().process_frame
			print("PA kierto fb=%.2f sub=%s" % [pg._fb, pg._sub.text])
			pg.faders.ch1 = 0.0
			pg.faders.ch2 = 0.8
			for i in 10:
				await get_tree().process_frame
			print("PA taso=%.2f soi=%s task=%s" % [pg.out_level, mokki_int._pa_players[0].playing, pg._task.text])
			await snap.call("_pa_board.png")
			var t0 := Time.get_ticks_msec()
			while is_instance_valid(pg) and Time.get_ticks_msec() - t0 < 8000:
				await get_tree().process_frame
			print("PA valmis: pa_on=%s strikes? msg=%s soi=%s db=%.1f" % [mokki_int.pa_on, _msg.text,
				mokki_int._pa_players[0].playing, mokki_int._pa_players[0].volume_db])
			mokki_int.walker.position = Vector3(-2.0, 0, 0.5)
			for i in 20:
				await get_tree().process_frame
			await snap.call("_pa_tupa.png")
			mokki_int.walker.position = mokki_int.SPOTS.ovi[0]
			await get_tree().process_frame
			_on_mokki_exited()
			for i in 20:
				await get_tree().process_frame
			print("PA ulkona: soi=%s" % mokki._pa_out.playing)
			await snap.call("_pa_ulkona.png")
			_enter_mokki()
			mokki_int.walker.position = mokki_int.SPOTS.pa[0]
			for i in 3:
				await get_tree().process_frame
			print("PA hint päällä=", mokki_int.hint)
			_on_mokki_acted("pa")
			print("PA sammutus: pa_on=%s soi=%s ulkona=%s" % [mokki_int.pa_on, mokki_int._pa_players[0].playing,
				mokki._pa_out.playing])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"aidat":
			# Pensasaidat tien kohdalta katkaistuina: kuvat kolmesta leikkauskohdasta (_aita_N.png).
			print("AIDAT leikattu %.1f m, kohtia %d" % [world.hedges_cut * 0.25, world.hedge_cut_at.size()])
			var ac := Camera3D.new()
			add_child(ac)
			for i in mini(3, world.hedge_cut_at.size()):
				var c: Vector2 = world.hedge_cut_at[i]
				var gy := Terrain.h(c.x, c.y)
				ac.look_at_from_position(Vector3(c.x + 7.0, gy + 6.0, c.y + 7.0), Vector3(c.x, gy + 0.5, c.y), Vector3.UP)
				ac.current = true
				for k in 30:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_aita_%d.png" % i))
		"mokkipuuhat":
			# Santun puuhastelu: jokainen puuhapaikka vuorollaan (kuva _p_<id>.png), sitten vapaa puuhastelu
			# minuutin ajan (Santun tila tulostetaan) ja väistö, kun pelaaja tulee puuhapaikalle.
			_toggle_mount()
			walker_out.global_position = mokki.gpos(Vector3(-2.0, 0.4, -14.0))
			for i in 20:
				await get_tree().process_frame
			var pu: Node = mokki.puuhat
			var pc := Camera3D.new()
			add_child(pc)
			for id in pu.spot_ids():
				pu.debug_start(id)
				var at: Vector3 = pu.spot_at(id)
				var sp: Vector3 = mokki.santtu.position
				for k in 150:
					await get_tree().process_frame
					if k == 100:
						sp = mokki.santtu.position
						var away := Vector3(3.2, 2.0, -3.2) if id != "onki" and id != "naputus" else Vector3(-3.0, 1.8, -3.0)
						pc.look_at_from_position(mokki.to_global(sp + away), mokki.to_global(sp + Vector3(0, 1.0, 0)), Vector3.UP)
						pc.current = true
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_p_%s.png" % id))
				print("PUUHA %s working=%s anim=%s visible=%s bubble=%s" % [id, pu.working(), mokki.santtu.current(),
					mokki.santtu.visible, mokki._bubble.text])
			pc.current = false
			# Reitit kannolta jokaiselle puuhapaikalle: ei rakennusten, pihan esineiden, puiden eikä veden läpi.
			for id in pu.spot_ids():
				var at: Vector3 = pu.spot_at(id)
				var t0 := Time.get_ticks_usec()
				var route: Array = mokki._route(Vector2(Mokki.SANTTU_LOCAL.x, Mokki.SANTTU_LOCAL.z + 0.6), Vector2(at.x, at.z))
				var us := Time.get_ticks_usec() - t0
				var hits := 0
				var from := Vector2(Mokki.SANTTU_LOCAL.x, Mokki.SANTTU_LOCAL.z + 0.6)
				var length := 0.0
				for k in route.size():
					var q: Vector2 = route[k]
					var n := maxi(1, ceili(from.distance_to(q) / 0.2))
					for m in range(1, n):
						var c: Vector2 = from.lerp(q, float(m) / n)
						if not mokki._free(mokki._cell(c)) and c.distance_to(Vector2(at.x, at.z)) > 1.0 and m > 2:
							hits += 1
					length += from.distance_to(q)
					from = q
				print("REITTI %s: %d pistettä, %.0f m, %.1f ms, esteissä %d" % [id, route.size(), length, us / 1000.0, hits])
			walker_out.activate_camera()
			pu._abort()
			mokki.santtu_go_home()
			pu._t = 1.0
			var seen := {}
			for k in 60 * 90:
				await get_tree().process_frame
				var cid: String = pu.current_id()
				if cid != "" and not seen.has(cid):
					seen[cid] = true
					print("PUUHA vapaa t=%d -> %s (%s)" % [k / 60, cid, pu._state])
			print("PUUHA vapaa paikat=%s" % [seen.keys()])
			# Väistö: pelaaja tikkataululle, kun Santtu heittää.
			pu.debug_start("tikka")
			await get_tree().process_frame
			walker_out.global_position = mokki.gpos(Mokki.DART_LOCAL + Vector3(0.5, 0.4, 0.3))
			for k in 30:
				await get_tree().process_frame
			print("PUUHA väistö state=%s bubble=%s" % [pu._state, mokki._bubble.text])
		"mokkihommat":
			# Santun hommat: yö mökillä, aamulappu, kaikki 12 hommaa pihalla, Santun kävely, minipelit (laituri,
			# ränni, ampiaiset, sahaus, halkominen, tiskit), huussin sangot, savusauna, palju, kalja Santulle,
			# hermot ja häätö. Kuvat _h_*.png. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var snap := func(suffix: String) -> void:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_h_%s.png" % suffix))
			var wait := func(n: int) -> void:
				for i in n:
					await get_tree().process_frame
			var cam := Camera3D.new()
			add_child(cam)
			var look := func(from: Vector3, at: Vector3) -> void:
				cam.look_at_from_position(mokki.to_global(Vector3(from.x, Mokki.h(from.x, from.z) + from.y, from.z)),
					mokki.to_global(Vector3(at.x, Mokki.h(at.x, at.z) + at.y, at.z)), Vector3.UP)
				cam.current = true
			_toggle_mount()
			walker_out.global_position = mokki.porch_pos(0.9)
			_hommat_arrive()
			print("HOMMAT saapuminen active=%s nights=%d" % [hommat.active, hommat.nights])
			hommat.nights = 1
			var rows: Array = _hommat_morning()
			print("HOMMAT aamu active=%s tasks=%s rows=%d" % [hommat.active, hommat.tasks, rows.size()])
			hommat.tasks = Hommat.TASKS.keys()
			_hommat_prepare()
			_note.show_note(["Huomenta mökille!"] + rows, "– Santtu", 5.0)
			await wait.call(30)
			await snap.call("lappu")
			_note.visible = false
			await look.call(Vector3(-11, 3.5, 6), Vector3(-16, 0.8, 15))
			await wait.call(10)
			await snap.call("puupaikka")
			await look.call(Vector3(-8, 3.0, 4), Vector3(-15, 0.8, 1.5))
			await wait.call(10)
			await snap.call("huussi")
			await look.call(Vector3(14, 4.0, -9), Vector3(6, 1.5, 0))
			await wait.call(10)
			await snap.call("nurmi_tikkaat")
			await look.call(Vector3(9.7, 9.0, -8.0), Vector3(9.7, 0.0, 1.0))
			await wait.call(10)
			await snap.call("nurmi_ylhaalta")
			await look.call(Vector3(-1.5, 2.0, 15.5), Vector3(2.7, 2.0, 18.5))
			mokki.wasp_nest.visible = true
			await wait.call(10)
			await snap.call("ampiaispesa")
			var dz: float = mokki.dock_body.position.z + _dock_fix_z()
			await look.call(Vector3(6.5, 2.5, dz - 2.5), Vector3(8.9, 0.0, dz + 0.6))
			await wait.call(10)
			await snap.call("laituri")
			# Huussi: kolme sankoa kompostiin (kävellen) ja yksi läikkyy juostessa, sitten talikko.
			var near := func(local: Vector3, r: float) -> bool:
				var g: Vector3 = mokki.to_global(local)
				var pp := player.global_position
				return Vector2(pp.x - g.x, pp.z - g.z).length() < r
			var go := func(local: Vector3) -> void:
				walker_out.global_position = mokki.gpos(local + Vector3(0, 0.4, 0))
				walker_out.velocity = Vector3.ZERO
				for i in 4:
					await get_tree().physics_frame
			for trip in 3:
				await go.call(Mokki.HUUSSI_HATCH_LOCAL)
				_hommat_logic(true, near)
				await go.call(Mokki.KOMPOSTI_LOCAL + Vector3(1.2, 0, 0))
				_hommat_logic(true, near)
			print("HUUSSI sangot=%s carry=%s" % [hommat.progress.get("sangot"), _carry])
			cam.current = false
			walker_out.activate_camera()
			for i in 12:
				_hommat_logic(true, near)
			print("HUUSSI tehty=%s msg=%s" % ["huussi" in hommat.done, _msg.text.replace("\n", " | ")])
			await go.call(Mokki.HUUSSI_HATCH_LOCAL)
			_set_carry("sanko")
			walker_out.speed = 5.0
			_hommat_tick(2.0)
			print("LAIKKYI carry=%s msg=%s" % [_carry, _msg.text.replace("\n", " | ")])
			# Santtu kävelee katsomaan (palju) ja palaa kannolle.
			await go.call(Mokki.TUB_LOCAL + Vector3(1.4, 0, 0))
			for i in 60 * 8:
				_santtu_watch(get_process_delta_time())
				await get_tree().process_frame
				if mokki.santtu_arrived():
					break
			print("SANTTU paljulla arrived=%s pos=%s bubble=%s" % [mokki.santtu_arrived(), mokki.santtu.position, mokki._bubble.text])
			await snap.call("santtu_palju")
			# Palju: tyhjennys, pesu ja täyttö pumpulla.
			_palju_logic(true)
			for i in 60 * 9:
				_hommat_tick(get_process_delta_time())
				await get_tree().process_frame
				if not _palju_draining:
					break
			mokki.palju_dirt = 0.01
			Input.action_press("interact")
			for i in 10:
				_palju_logic(false)
				await get_tree().process_frame
			Input.action_release("interact")
			print("PALJU taso=%.2f lika=%.2f letku=%s" % [mokki.palju_level, mokki.palju_dirt, mokki._hose.visible])
			await go.call(Mokki.pump_local() + Vector3(0.8, 0, 0))
			_hommat_logic(true, near)
			mokki.palju_level = 0.97
			await wait.call(5)
			_hommat_logic(true, near)
			print("PALJU tehty=%s pumppu=%s" % ["palju" in hommat.done, mokki.pump_on])
			# Savusauna: syli pesään, kiuas kuumaksi ja savut tuulettumaan (ajat lyhennetään).
			await go.call(Mokki.HALKO_LOCAL)
			_hommat_logic(true, near)
			print("HALOT carry=%s" % _carry)
			await go.call(Mokki.SAUNA_LOCAL + Vector3(-1.5, 0, 0))
			_sauna_logic(true)
			await look.call(Vector3(-1, 3.0, 14), Vector3(5, 1.5, 19))
			await wait.call(90)
			await snap.call("savusauna")
			mokki.sauna_heat = 0.99
			for i in 60 * 8:
				await get_tree().process_frame
				if not mokki.sauna_fire_on:
					break
			mokki.sauna_smoke = 0.02
			await wait.call(60)
			print("SAUNA heated=%s ready=%s tehty=%s" % [mokki.sauna_heated, mokki.sauna_ready(), "savusauna" in hommat.done])
			cam.current = false
			# Minipelit: käynnistys, kuva Santtu katsojana ja lopetus.
			var mg := func(starter: Callable, name: String, frames: int) -> void:
				starter.call()
				await wait.call(frames)
				await snap.call(name)
				var g: Node = null
				for c in mokki.get_children():
					if c.has_method("_quit"):
						g = c
				if g != null:
					g._quit()
				await wait.call(5)
				print("PELI %s state=%s msg=%s" % [name, state, _msg.text.replace("\n", " | ")])
			await mg.call(_start_laituri, "peli_laituri", 40)
			await mg.call(_start_ranni, "peli_ranni", 40)
			await mg.call(_start_ampiaiset, "peli_ampiaiset", 40)
			await mg.call(_start_mokki_saw, "peli_saha", 40)
			_mokki_polkyt = 2
			await mg.call(_start_mokki_chop, "peli_halko", 40)
			# Laituri ratkaistuna: kaikki naulat kantaan.
			var lg := LaituriGame.new()
			print("LAITURI valmis ennen=%s" % LaituriGame.is_done(_dock_state))
			lg.free()
			# Leikkuri: nurmikko leikataan suoraan.
			_ensure_mokki_lawn()
			_start_mowing(mokki_lawn)
			mokki_lawn.lengths.fill(0.04)
			_mow()
			print("NURMI tehty=%s mowing=%s" % ["nurmi" in hommat.done, mowing])
			# Kahvit sisällä, vienti Santulle ja tiskit.
			_enter_mokki()
			await wait.call(5)
			_on_mokki_acted("kahvi")
			_start_tiskit()
			await wait.call(20)
			await snap.call("tiskit")
			var tg: Node = get_children().filter(func(c): return c is TiskiGame)[0]
			for k in 400:
				tg._scrub(1 if k % 2 == 0 else -1)
				if tg._dirt <= 0.0:
					tg.drunk = 0.0
					tg._lift()
				if not is_instance_valid(tg) or tg._done:
					break
			await wait.call(5)
			print("TISKIT dishes=%d" % mokki_int.dishes)
			_on_mokki_exited()
			print("KAHVI carry=%s" % _carry)
			await go.call(mokki.santtu.position + Vector3(1.2, 0, 0))
			_hommat_logic(true, near)
			print("KAHVI tehty=%s" % ("kahvi" in hommat.done))
			# Kalja Santulle: yksi homma pois.
			beers = 1
			_on_santtu_menu("kalja")
			print("KALJA beer_used=%s done=%s" % [hommat.beer_used, hommat.done])
			print("HUD: ", _stats.text.replace("\n", " | "))
			print("REPPU: ", inventory_info())
			# Hermot: täysi mittari = häätö ja yhden tähden arvostelu.
			hommat.done = hommat.done.slice(0, 2)
			hommat.hermo = 99.9
			state = "to_shop"
			print("HAATO ennen: busy=%s menu=%s (%s) note=%s" % [cutscene.busy, _item_menu.is_open(), _item_menu._title.text, _note.visible])
			_item_menu.visible = false
			player.controls_enabled = true
			_hommat_tick(1.0)
			await wait.call(10)
			print("HAATO active=%s banned=%s reviews=%s" % [hommat.active, hommat.banned_day == day, hommat.reviews])
			await wait.call(200)
			print("HAATO state=%s at_mokki=%s" % [state, _at_mokki()])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"omatjuomat":
			# Omat juomat Raahen baarissa: T-valikosta kaljaa, kunnes baarimikko varoittaa ja heittää ulos.
			_toggle_mount()
			state = "cutscene"
			_enter_raahe()
			_raahe.paivi_t = -1.0
			raahe_int.walker.position = raahe_int.spots.tiski[0]
			beers = 12
			await get_tree().create_timer(0.8).timeout
			for k in 12:
				if state != "in_raahe" or not raahe_int.walker.controls_enabled:
					break
				await get_tree().process_frame
				Input.action_press("eat")
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release("eat")
				var open: bool = _item_menu.is_open()
				_item_menu.visible = false
				_item_menu.chosen.emit("kalja")
				await get_tree().process_frame
				print("OMAT %d: valikko=%s kaljaa=%d varoitettu=%s viesti='%s'" % [k, open, beers, _own_drink_warned, _msg.text])
			await get_tree().create_timer(3.0).timeout
			print("OMAT loppu: tila=%s potkittu=%s" % [state, _raahe.get("kicked", false)])
		"raahepaivi":
			# Päivi Raahen baarissa: 1) pelaaja jää tiskille -> kiinni ja taksi kotiin; --pako: pelaaja Kellariin,
			# Päivi seuraa portaiden kautta, pelaaja ylös ja ulos ennen kiinnijäämistä.
			_toggle_mount()
			state = "cutscene"
			_enter_raahe()
			_raahe.paivi_t = 0.5
			var pako := OS.get_cmdline_user_args().has("--pako")
			raahe_int.walker.position = raahe_int.spots.tiski[0]
			await get_tree().create_timer(1.2).timeout
			print("PAIVI tuli=%s paikalla=%s tila=%s" % [_raahe.get("paivi_came", false), raahe_int.paivi_here, raahe_int._paivi_mode])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_kulma.png"))
			if pako:
				raahe_int.walker.position = raahe_int.spots.ylos[0] + Vector3(-3.0, 0, -2.0)
				await get_tree().create_timer(6.0).timeout
				print("PAIVI 6 s: tila=%s kellarissa=%s" % [raahe_int._paivi_mode, raahe_int._cellar_of(raahe_int._paivi.position)])
				print("PAIVI kellarissa: päivi kellarissa=%s näkyy=%s" % [raahe_int._cellar_of(raahe_int._paivi.position), raahe_int._paivi.visible])
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_kellari.png"))
				raahe_int.walker.position = raahe_int.spots.ovi[0]
				for w in 3:
					await get_tree().process_frame
				raahe_int._on_test_exit()
			for i in 40:
				await get_tree().create_timer(0.5).timeout
				if state != "in_raahe":
					break
			print("PAIVI loppu: state=%s kiinni=%s tila=%s msg=%s" % [state, _raahe.caught, raahe_int._paivi_mode, _msg.text])
		"hiiriohjaus":
			# Hiiriohjaus (FPS-tyyli): jalan hiiren käännös kääntää hahmon suoraan ja A sivuttain; pyörä ohjautuu
			# kameran suuntaan ja kamera pysyy maailmassa paikallaan.
			Settings.set_v("mouse_steer", true)
			if player == bike:
				_toggle_mount()
			for i in 10:
				await get_tree().physics_frame
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			await get_tree().process_frame
			var h0 := walker_out.rotation.y
			CamCtl.yaw = 0.6
			for i in 3:
				await get_tree().physics_frame
			print("HIIRI ohjaa=%s jalan käännös %.2f (odotus 0.60) yaw jäljellä %.2f" % [CamCtl.steering(), wrapf(walker_out.rotation.y - h0, -PI, PI), CamCtl.yaw])
			var p0 := walker_out.global_position
			var side0 := walker_out.global_transform.basis.x
			Input.action_press("left")
			for i in 60:
				await get_tree().physics_frame
			Input.action_release("left")
			var mv := walker_out.global_position - p0
			print("HIIRI A-sivuaskel: sivulle %.2f m, eteen %.2f m" % [mv.dot(side0), mv.dot(-walker_out.global_transform.basis.z)])
			var far := walker_out.global_position + Vector3(300, 0, 250)
			var np: Vector3 = world.ride.get_point_position(world.ride.get_closest_point(Vector3(far.x, 0, far.z)))
			bike.global_position = Vector3(np.x, Terrain.h(np.x, np.z) + 0.4, np.z)
			_toggle_mount()
			for i in 10:
				await get_tree().physics_frame
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			Input.action_press("forward")
			for i in 60:
				await get_tree().physics_frame
			var target := bike.rotation.y + 0.8
			CamCtl.yaw = 0.8
			for k in 4:
				for i in 30:
					await get_tree().physics_frame
				print("HIIRI pyörä %.1f s: keula-ero kohteeseen %.2f, kameran ero kohteeseen %.2f, vauhti %.1f" % [
					(k + 1) * 0.5, wrapf(target - bike.rotation.y, -PI, PI), wrapf(target - bike.rotation.y - CamCtl.yaw, -PI, PI), bike.speed])
			Input.action_release("forward")
			Settings.set_v("mouse_steer", false)
		"pyoravaras":
			# Pyörävaras: pyörä 400 m päähän, varkaus käyntiin; seurataan teinin lähestymistä ja ajelua 100 m:n
			# sisällä, kuva, sitten pelaaja kävelee pyörän luo (kiinni). --hylkaa: lyhyt ajelu ja hylkäys.
			_toggle_mount()
			var far := walker_out.global_position + Vector3(300, 0, 250)
			var nid: int = world.ride.get_closest_point(Vector3(far.x, 0, far.z))
			var np: Vector3 = world.ride.get_point_position(nid)
			bike.global_position = Vector3(np.x, Terrain.h(np.x, np.z) + 0.4, np.z)
			for i in 10:
				await get_tree().physics_frame
			_thief_start()
			if OS.get_cmdline_user_args().has("--hylkaa"):
				_thief.roam = 6.0
			var maxd := 0.0
			for k in 110:
				await get_tree().create_timer(1.0).timeout
				if _thief.is_empty():
					break
				var dd := Vector2(bike.global_position.x - walker_out.global_position.x, bike.global_position.z - walker_out.global_position.z).length()
				if _thief.phase == "roam":
					maxd = maxf(maxd, dd)
				if k % 6 == 0:
					print("VARAS %2d s: vaihe=%s etäisyys=%.0f m nopeus=%.1f reitti=%d" % [k, _thief.phase, dd, bike.speed, (_thief.route as PackedVector3Array).size()])
			print("VARAS ajelun suurin etäisyys %.0f m, käynnissä=%s msg=%s" % [maxd, not _thief.is_empty(), _msg.text])
			if not _thief.is_empty():
				var oc := Camera3D.new()
				add_child(oc)
				oc.look_at_from_position(bike.global_position + Vector3(5, 3, 5), bike.global_position + Vector3(0, 1, 0), Vector3.UP)
				oc.current = true
				await get_tree().create_timer(0.3).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_varas.png"))
				oc.queue_free()
				walker_out.global_position = bike.global_position + Vector3(2.0, 0.5, 0)
				await get_tree().create_timer(0.5).timeout
				print("VARAS kiinni? käynnissä=%s msg=%s" % [not _thief.is_empty(), _msg.text])
		"pekkakyyti":
			# Pekan kyyti mökille: vihje Pekan luona, välikuvan kolme kuvaa ja perillä mökin pysäkillä.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var shot := func(name: String) -> void:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path.get_base_dir().path_join("pekka_%s.png" % name))
			if player != walker_out:
				_toggle_mount()
			money = 30.0
			pekka.process_mode = Node.PROCESS_MODE_DISABLED  # ei karkaa puuhiinsa testin aikana
			_note.visible = false
			walker_out.global_position = pekka.global_position + Vector3(1.5, 0.5, 0)
			for i in 30:
				await get_tree().physics_frame
			print("PEKKA hint=", _hint.text)
			await get_tree().process_frame
			Input.action_press("interact")
			for w in 2:
				await get_tree().process_frame
			Input.action_release("interact")
			print("PEKKA busy=%s rahat=%s" % [cutscene.busy, _eur(money)])
			for sec in [2.5, 4.0, 3.5]:
				await get_tree().create_timer(sec, true, false, true).timeout
				await shot.call(str(sec))
			var t0 := Time.get_ticks_msec()
			while (cutscene.busy or not mokki.built) and Time.get_ticks_msec() - t0 < 20000:
				await get_tree().process_frame
			for i in 60:
				await get_tree().physics_frame
			var lp: Vector3 = mokki.to_local(walker_out.global_position)
			print("PEKKA perillä: rakennettu=%s paikka=(%.1f, %.1f) ohjaus=%s" % [mokki.built, lp.x, lp.z, walker_out.controls_enabled])
			await shot.call("perilla")
			# Paluu: Pekan autolla kotiin (mökin pihatien päästä).
			print("PEKKA mökillä hint=", _hint.text)
			await get_tree().process_frame  # kuvakaappauksen jälkeen: painallus seuraavan ruudun alkuun
			Input.action_press("interact")
			for w in 2:
				await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().create_timer(10.5, true, false, true).timeout
			await shot.call("koti_tie")
			t0 = Time.get_ticks_msec()
			while cutscene.busy and Time.get_ticks_msec() - t0 < 20000:
				await get_tree().process_frame
			for i in 60:
				await get_tree().physics_frame
			var hp := walker_out.global_position
			print("PEKKA kotona: etäisyys kotiin %.1f m mökillä=%s ohjaus=%s" % [Vector2(hp.x - home_zone.x, hp.z - home_zone.z).length(),
				_at_mokki(), walker_out.controls_enabled])
			await shot.call("kotona")
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"mokkikartta":
			# Paperikartta (M) ja tutka mökillä: oikean kartan järvet, tiet ja rakennukset.
			_toggle_mount()
			walker_out.global_position = mokki.porch_pos(1.5)
			for i in 10:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_tutka.png"))
			await get_tree().process_frame
			Input.action_press("map")
			await get_tree().process_frame
			Input.action_release("map")
		"mokkiilma":
			# Mökin 200 m alue ilmasta (vertaa drone-kuvaan ja karttaan) ja rakennusaika.
			var t0 := Time.get_ticks_msec()
			var test := Mokki.new()
			test.position = Vector3(0, 0, 20000)
			add_child(test)
			print("MOKKIILMA rakennus %d ms, lapsia %d, vesi_y %.2f, mökki->ranta h(8.9,44)=%.2f" % [Time.get_ticks_msec() - t0,
				test.get_child_count(), Mokki.water_y(), Mokki.h(8.9, 44.0)])
			test.queue_free()
			var ac := Camera3D.new()
			add_child(ac)
			ac.far = 2000.0
			ac.look_at_from_position(mokki.gpos(Vector3(-5, 90, -60)), mokki.gpos(Vector3(0, 0, 25)))
			ac.current = true
			for i in 10:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_piha.png"))
			# Mökki järven puolelta: rinteen sokkeli ja kuistin portaat.
			ac.look_at_from_position(mokki.gpos(Vector3(9, 2.0, 12)), mokki.gpos(Vector3(1, 0.5, 0)))
			for i in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_ranta.png"))
			ac.look_at_from_position(mokki.gpos(Vector3(0, 170, 30)), mokki.gpos(Vector3(0, 0, 0)))
		"mokkikaide":
			# Kuistin kaide järven puolelta läheltä vinosti.
			var kc := Camera3D.new()
			add_child(kc)
			kc.look_at_from_position(mokki.gpos(Vector3(6.5, 1.6, 8.5)), mokki.gpos(Vector3(0.5, 0.9, 1.5)), Vector3.UP)
			kc.current = true
			walker_out.visible = false
		"mokkilaituri":
			# Laituri: rantaprofiili, kävely rannalta laiturin päähän ja kuva sivusta.
			var dl: Vector3 = Mokki.DOCK_LOCAL
			var prof := []
			for k in 11:
				var z: float = dl.z - 16.0 + k * 2.0
				prof.append("%.0f:%.2f%s" % [z, Mokki.h(dl.x, z), "~" if Mokki.water_at(dl.x, z) >= 0 else ""])
			print("LAITURI profiili ", " ".join(prof), " vesi_y %.2f" % Mokki.water_y())
			_toggle_mount()
			walker_out.global_position = mokki.gpos(Vector3(dl.x, 0.5, dl.z - 16.0))
			walker_out.look_at(mokki.gpos(Vector3(dl.x, 0.5, dl.z + 5.0)))
			for i in 10:
				await get_tree().physics_frame
			Input.action_press("forward")
			for i in 420:
				await get_tree().physics_frame
			Input.action_release("forward")
			var wl: Vector3 = mokki.to_local(walker_out.global_position)
			print("LAITURI kävelijä x=%.2f y=%.2f z=%.2f (pää z %.1f)" % [wl.x, wl.y, wl.z, dl.z])
			var dc := Camera3D.new()
			add_child(dc)
			var sy: float = Mokki.h(dl.x, dl.z - 12.0)
			dc.look_at_from_position(mokki.to_global(dl + Vector3(4.5, sy + 1.2, -15.5)), mokki.to_global(dl + Vector3(0, sy, -10.5)))
			dc.current = true
			walker_out.visible = false
		"kuisti":
			# Mökin kuisti: luiskaa ylös kannelle (korkeus ~0,6 m), eikä kannen reunasta pääse sisään maata pitkin.
			_toggle_mount()
			var start: Vector3 = mokki.gpos(Vector3(6.6, 0.5, 2.2))
			walker_out.global_position = start
			walker_out.look_at(mokki.gpos(Vector3(0, 0.5, 2.2)))
			for i in 10:
				await get_tree().physics_frame
			Input.action_press("forward")
			for i in 150:
				await get_tree().physics_frame
			Input.action_release("forward")
			var lp: Vector3 = mokki.to_local(walker_out.global_position)
			print("KUISTI portaat: x=%.2f y=%.2f z=%.2f (kansi y %.2f, x -4.7..4.7)" % [lp.x, lp.y, lp.z, Mokki.h(0, -1) + 0.62])
			walker_out.global_position = mokki.gpos(Vector3(0, 0.5, 7.5))
			walker_out.look_at(mokki.gpos(Vector3(0, 0.5, 0)))
			for i in 10:
				await get_tree().physics_frame
			Input.action_press("forward")
			for i in 120:
				await get_tree().physics_frame
			Input.action_release("forward")
			lp = mokki.to_local(walker_out.global_position)
			print("KUISTI edestä: z=%.2f y=%.2f (kannen reuna z 3.9: pitäisi pysähtyä)" % [lp.z, lp.y])
			# Yleiskuva pihasta rannan suunnasta: kuisti, savusauna, palju ja kesäkeittiö kuten kuvissa.
			var kc := Camera3D.new()
			add_child(kc)
			kc.look_at_from_position(mokki.gpos(Vector3(4, 9, 36)), mokki.gpos(Vector3(2, 1, 8)))
			kc.current = true
		"syo":
			# Leipähyllystä korvapuusti ja piirakka, sitten T-valikosta syöminen. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var press := func(action: String) -> void:
				await get_tree().process_frame  # painallus ennen solmujen _processia (just_pressed samassa ruudussa)
				Input.action_press(action)
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			_enter_shop()
			interior.walker.position = ShopInterior.BAKERY_SPOT
			await get_tree().process_frame
			print("SYO shop hint=", interior.hint)
			await press.call("interact")
			await press.call("interact")
			print("SYO cart=", interior.cart, " hint=", interior.hint)
			interior.has_paid = true
			interior.exited.emit(false)
			await get_tree().process_frame
			print("SYO food=", food, " inv=", _stats.text.contains("korvapuusti"))
			bucket["puolukka"] = 2
			has_chocolate = true
			beers = 0  # kalja tarkistetaan erikseen lopussa
			_toggle_mount()
			for i in 5:
				await get_tree().physics_frame
			var n0: float = tilat.value("nalka")
			await press.call("eat")
			print("SYO menu=", _item_menu.is_open(), " items=", _item_menu._items)
			await press.call("interact")
			print("SYO ate first: nalka %+.2f food=%s msg=%s" % [tilat.value("nalka") - n0, food, _msg.text])
			await press.call("eat")
			await press.call("back")
			await press.call("back")
			await press.call("interact")
			print("SYO ate third: nalka total %+.2f bucket=%s choco=%s" % [tilat.value("nalka") - n0, bucket, has_chocolate])
			food.clear()
			bucket.clear()
			has_chocolate = false
			beers = 2
			var h0: float = tilat.value("humala")
			await press.call("eat")
			print("SYO kalja menu=", _item_menu._items)
			await press.call("interact")
			print("SYO joi kaljan: humala %+.2f beers=%d msg=%s" % [tilat.value("humala") - h0, beers, _msg.text])
			beers = 0
			await press.call("eat")
			print("SYO empty menu=%s msg=%s" % [_item_menu.is_open(), _msg.text])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"pojat":
			# Jalkapallopojat: tehtävä, pallon haku, palautus valikosta; sitten kalja ja väärä esine. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var press := func(action: String) -> void:
				await get_tree().process_frame  # painallus ennen solmujen _processia (just_pressed samassa ruudussa)
				Input.action_press(action)
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			_toggle_mount()
			for round in ["pallo", "kalja", "makkara"]:
				if is_instance_valid(boys):
					boys.queue_free()
				day = 2
				_spawn_boys()
				walker_out.global_position = boys.global_position + Vector3(2.5, 0.5, 0)
				for i in 10:
					await get_tree().physics_frame
				await get_tree().process_frame
				print("POJAT [%s] hint=%s" % [round, _hint.text])
				await press.call("interact")
				var bd: float = ball.global_position.distance_to(boys.global_position) if is_instance_valid(ball) else -1.0
				print("POJAT quest=%s ball_dist=%.0f msg=%s" % [_ball_quest, bd, _msg.text.replace("\n", " | ")])
				if round == "pallo":
					walker_out.global_position = ball.global_position + Vector3(0.8, 0.4, 0)
					for i in 10:
						await get_tree().physics_frame
					await get_tree().process_frame
					await press.call("interact")
					print("POJAT has_ball=%s hud_inv=%s" % [has_ball, "jalkapallo" in _stats.text])
				elif round == "kalja":
					beers = 2
				else:
					has_sausage = true
					beers = 0
				walker_out.global_position = boys.global_position + Vector3(2.5, 0.5, 0)
				for i in 10:
					await get_tree().physics_frame
				await get_tree().process_frame
				var m0 := money
				var mor: float = tilat.value("moraali")
				var xp: float = tilat.value("kokemus")
				await press.call("interact")
				print("POJAT menu open=%s items=%s" % [_item_menu.is_open(), _item_menu._items])
				if round == "pallo":
					for i in 5:
						await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(path.replace(".png", "_menu.png"))
					await get_tree().process_frame
				await press.call("interact")
				for i in 30:
					await get_tree().process_frame
				print("POJAT gave -> mode=%s money %s -> %s moraali %+.2f kokemus %+.2f beers=%d msg=%s" % [
					boys.mode if is_instance_valid(boys) else "gone", _eur(m0), _eur(money), tilat.value("moraali") - mor,
					tilat.value("kokemus") - xp, beers, _msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"tilat":
			# Päivän tilat: lepo grillikatoksella, kalja, tehtävä, uusi päivä ja hankaluus. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			tilat.chosen = ["stressi", "moraali", "humala"]
			print("TILAT alku ", tilat.summary())
			_toggle_mount()
			walker_out.global_position = M.w(M.GRILLIKATOS) + Vector3(1.0, 0.5, 1.0)
			for i in 300:
				await get_tree().physics_frame
			print("TILAT lepo grillikatoksella 5 s: ", tilat.summary())
			_drink(2)
			_task_done(true)
			print("TILAT 2 kaljaa + sivutehtävä: ", tilat.summary())
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_hud.png"))
			var sp0: float = wife.speed_mult
			_new_day(home_zone + Vector3(0, 0, 4), false)
			print("TILAT uusi päivä wife %.2f -> %.2f mummot=%.1f koira=%.1f humala=%.2f chosen=%s" % [sp0, wife.speed_mult,
				mummot.anger_speed, stray.bite_dist, tilat.value("humala"), tilat.chosen])
			print("TILAT viesti: ", _msg.text.replace("\n", " | "))
			# Krapula: illan humala yli rajan -> aamulla vireys ja keskittyminen -0,3.
			tilat.values["humala"] = 0.95
			_new_day(home_zone + Vector3(0, 0, 4), false)
			print("TILAT krapula humala=%.2f vireys=%.2f keskittyminen=%.2f viesti: %s" % [tilat.value("humala"),
				tilat.value("vireys"), tilat.value("keskittyminen"), _msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"tilat_vaikutukset":
			# Jokaisen tilan palkinto (+0,8) ja haitta (-0,8): mitä _stat_effects ja kulutuskohdat asettavat.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			for k in DayStats.STATS:
				for v in ([0.5, 0.9] if k == "humala" else [0.8, -0.8]):
					tilat.chosen = [k, "stressi" if k != "stressi" else "nalka", "moraali" if k != "moraali" else "nalka"]
					for o in DayStats.STATS:
						tilat.values[o] = 0.0
					tilat.values[k] = v
					_stat_effects()
					interior.price_mult = 1.0 - 0.1 * tilat.effect("moraali")
					var inv: Dictionary = inventory_info()
					print("VAIKUTUS %s %+.1f eff=%d | mummot %.1f wife %.2f nopeus %.2f kulutus %.1f palautus %.1f juoksu %.2f hyppy %.2f spurtti %.1f eispurttia %s tutka %.0f usva %.0f hinta %.2f käsi %.2f lista %s" % [
						k, v, tilat.effect(k), mummot.anger_speed, wife.speed_mult, walker_out.speed_mult, walker_out.drain_mult,
						walker_out.recover_mult, walker_out.run_mult, walker_out.jump_mult, bike.sprint_mult, walker_out.no_sprint,
						_minimap.range_m, _env.fog_depth_end, interior.price_mult, _hand_shake(), inv.list])
			# Muut kuin päivän kolme tilaa eivät vaikuta.
			tilat.chosen = ["stressi", "moraali", "kipu"]
			tilat.values["nalka"] = -0.9
			print("VAIKUTUS nälkä ei päivän tila: eff=%d" % tilat.effect("nalka"))
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"humala_ohjaus":
			# Humalan ohjaushaitta: kävellään ja ajetaan 6 s suoraan ilman ohjausta, selvänä ja humalassa 0,9. Suunnan
			# muutos. Humala ei ole päivän tiloissa: heittely on silti päällä (kuten mopolla).
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			tilat.chosen = ["stressi", "moraali", "kipu"]
			for mounted in [false, true]:
				if (player == bike) != mounted:
					_toggle_mount()
				for h in [0.0, 0.9]:
					tilat.values["humala"] = h
					player.global_position = M.w(M.GRILLIKATOS) + Vector3(1.0, 0.5, 1.0)
					player.rotation.y = 0.0
					Input.action_press("forward")
					var max_dev := 0.0
					for i in 360:
						await get_tree().physics_frame
						max_dev = maxf(max_dev, absf(wrapf(player.rotation.y, -PI, PI)))
					Input.action_release("forward")
					print("HUMALA %s humala=%.1f drunk=%.2f max suunnanmuutos %.0f°" % ["pyörä" if mounted else "jalan", h,
						player.drunk, rad_to_deg(max_dev)])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"heitto":
			# Tappelussa kolme kaljanheittoa (eteen + L), sitten K.O. ja kaljamäärän tarkistus.
			beers = 6
			state = "to_home"
			_start_fight("juntti", "juntti", Vector3.RIGHT)
			for i in 150:
				await get_tree().process_frame
			for k in 3:
				var hp0: float = fight._j.hp
				Input.action_press("right")
				await get_tree().process_frame
				Input.action_press("special")
				await get_tree().process_frame
				Input.action_release("special")
				Input.action_release("right")
				for i in 12:
					await get_tree().process_frame
				if k == 0:
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(path.replace(".png", "_fly.png"))
				for i in 50:
					await get_tree().process_frame
				print("HEITTO %d thrown=%d foe hp %.0f -> %.0f foe_state=%s cans=%d" % [k, fight._thrown, hp0, fight._j.hp,
					fight._j.state, fight._cans.size()])
			print("HEITTO help=", fight._help.text.right(40))
			fight._j.hp = 0.0
			fight._j.state = "ko"
			for i in 300:
				await get_tree().process_frame
				if state != "fight":
					break
			print("HEITTO after fight beers=%d state=%s msg=%s" % [beers, state, _msg.text.replace("\n", " | ")])
		"mummot":
			# Pyörällä lujaa penkin ohi: mummot suuttuvat ja heittävät kettukarkkeja. Sitten jalan poimimaan.
			var hits := [0]
			mummot.hit.connect(func(_d: Vector3) -> void: hits[0] += 1)
			var bp: Vector3 = mummot.global_position
			bike.global_position = bp + Vector3(-9.0, 0.3, 2.5)
			bike.rotation.y = B.yaw_to(Vector3(1, 0, 0))
			for i in 10:
				await get_tree().physics_frame
			var sc := Camera3D.new()
			add_child(sc)
			sc.global_position = bp + Vector3(3.0, 1.6, 4.5)
			sc.look_at(bp + Vector3(0, 0.8, 0), Vector3.UP)
			sc.current = true
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_bench.png"))
			sc.queue_free()
			bike.activate_camera()
			bike.speed = 8.0
			Input.action_press("forward")
			for i in 90:
				await get_tree().physics_frame
			Input.action_release("forward")
			print("MUMMOT angry=%s status=%s" % [mummot.is_angry(), _status.text])
			for i in 180:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_throw.png"))
			for i in 240:
				await get_tree().physics_frame
			print("MUMMOT hits=%d ground=%d angry=%s" % [hits[0], mummot._ground.size(), mummot.is_angry()])
			_toggle_mount()
			var s0: float = walker_out.stamina
			walker_out.stamina = 50.0
			if not mummot._ground.is_empty():
				walker_out.global_position = mummot._ground[0].node.global_position + Vector3(0, 0.4, 0)
			for i in 20:
				await get_tree().physics_frame
			print("MUMMOT picked stamina 50 -> %.0f ground=%d msg=%s" % [walker_out.stamina, mummot._ground.size(), _msg.text])
		"kauppalista":
			# Päivin lista: 3 oikein, 1 väärä väri ja 1 ylimääräinen; kotona palaute. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			shopping_list = [["tamponi", "vihreä"], ["maito", "punainen"], ["ristikkolehti", "sininen"], ["voi", "keltainen"]]
			print("LISTA reppu=", inventory_info().list)
			_enter_shop()
			var iw: CharacterBody3D = interior.walker
			var picks := [["tamponi", "vihreä"], ["maito", "punainen"], ["ristikkolehti", "sininen"], ["voi", "sininen"], ["kahvi", "punainen"]]
			for pk in picks:
				var idx: int = ShopInterior.PRODUCTS.keys().find(pk[0])
				iw.position = Vector3(10.4, 0, ShopInterior.SHELF_Z0 + idx + 0.5)
				await get_tree().process_frame
				var ci: int = ShopInterior.COLORS.keys().find(pk[1])
				for k in ci:
					Input.action_press("bell")
					await get_tree().process_frame
					Input.action_release("bell")
					await get_tree().process_frame
				print("  at %s hint=%s" % [pk[0], interior.hint])
				Input.action_press("interact")
				await get_tree().process_frame
				Input.action_release("interact")
				await get_tree().process_frame
			print("LISTA bag=", interior.bag, " reppu=", inventory_info().list)
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_shelf.png"))
			interior.has_paid = true
			interior.exited.emit(false)
			await get_tree().process_frame
			_toggle_mount()
			walker_out.global_position = home_zone + Vector3(0, 0.5, 2.0)
			for i in 20:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("LISTA home hint=", _hint.text, " bag=", paivi_bag)
			_msg_time = 0.0
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("LISTA feedback=", " || ".join(_msg_queue.map(func(m: Array) -> String: return m[0])), " shown=", _msg.text)
			_new_day(home_zone + Vector3(0, 0, 4), false)
			print("LISTA newday list=", shopping_list, " queue=", _msg_queue.size())
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"purema":
			# Vieras koira: murina, purema, ontuminen, hoito Pekalla ja Päivillä. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			_toggle_mount()
			var sp: Vector3 = stray.global_position
			walker_out.global_position = sp + Vector3(8.0, 0.5, 0)
			walker_out.look_at(Vector3(sp.x, walker_out.global_position.y, sp.z))
			for i in 30:
				await get_tree().physics_frame
			var sc := Camera3D.new()
			add_child(sc)
			sc.global_position = stray.global_position + Vector3(2.5, 1.4, 2.5)
			sc.look_at(stray.global_position + Vector3(0, 0.4, 0), Vector3.UP)
			sc.current = true
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_dog.png"))
			sc.queue_free()
			walker_out.activate_camera()
			print("PUREMA growl msg=", _msg.text.replace("\n", " | "))
			Input.action_press("forward")
			for i in 600:
				await get_tree().physics_frame
				if bitten:
					break
			Input.action_release("forward")
			print("PUREMA bitten=%s hurt=%s status=%s msg=%s" % [bitten, walker_out.hurt, _status.text, _msg.text.replace("\n", " | ")])
			for i in 120:
				await get_tree().physics_frame
			walker_out.global_position = pekka.global_position + Vector3(2.0, 0.5, 0)
			beers = 0
			for i in 20:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("PUREMA pekka hint=", _hint.text)
			var m0 := money
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("PUREMA pekka healed=%s money %s -> %s msg=%s" % [not bitten, _eur(m0), _eur(money), _msg.text.replace("\n", " | ")])
			_on_bitten(Vector3.FORWARD)
			for i in 120:
				await get_tree().physics_frame
			walker_out.global_position = home_zone + Vector3(0, 0.5, 2.0)
			for i in 20:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("PUREMA home hint=", _hint.text)
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("PUREMA paivi healed=%s hurt=%s msg=%s" % [not bitten, walker_out.hurt, _msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"vaino":
			# Väinö karkaa, pelaaja hiipii nuuhkivan koiran viereen, ottaa kiinni ja palauttaa Pekalle.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			_toggle_mount()
			_vaino_at = elapsed
			await get_tree().process_frame
			await get_tree().process_frame
			var mi: MeshInstance3D = vaino.find_children("*", "MeshInstance3D", true, false)[0]
			var ab := mi.global_transform * mi.get_aabb()
			print("VAINO escaped mode=%s aabb size=%s msg=%s" % [vaino.mode, ab.size, _msg.text.replace("\n", " | ")])
			for i in 1800:
				await get_tree().physics_frame
				if vaino.mode == "sniff":
					break
			print("VAINO after bolt mode=%s d_home=%.1f" % [vaino.mode, vaino.global_position.distance_to(vaino.home)])
			walker_out.global_position = vaino.global_position + vaino.global_transform.basis.x * 1.8 + Vector3(0, 0.5, 0)
			walker_out.look_at(Vector3(vaino.global_position.x, walker_out.global_position.y, vaino.global_position.z))
			for i in 5:
				await get_tree().physics_frame
			await get_tree().process_frame
			var vc := Camera3D.new()
			add_child(vc)
			vc.global_position = vaino.global_position + Vector3(2.2, 1.2, 2.2)
			vc.look_at(vaino.global_position + Vector3(0, 0.35, 0), Vector3.UP)
			vc.current = true
			_msg.text = ""
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_dog.png"))
			vc.queue_free()
			walker_out.activate_camera()
			await get_tree().process_frame
			print("VAINO near hint=%s mode=%s" % [_hint.text, vaino.mode])
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("VAINO caught mode=%s msg=%s" % [vaino.mode, _msg.text.replace("\n", " | ")])
			walker_out.global_position = pekka.global_position + Vector3(2.0, 0.5, 0)
			vaino.global_position = walker_out.global_position + Vector3(0, -0.5, 2.0)
			for i in 60:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("VAINO at pekka hint=%s dog_d=%.1f status=%s" % [_hint.text, vaino.distance_to_target(), _status.text])
			var m0 := money
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("VAINO returned valid=%s money %s -> %s beers=%d msg=%s" % [is_instance_valid(vaino), _eur(m0), _eur(money), beers,
				_msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"jemma_ovi":
			# Kotiinpaluu: kaljat kädessä ovi ei aukea, eteisen kaappiin piilotus E:llä, tyhjin käsin ovelle -> koti.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			var press := func(action: String) -> void:
				await get_tree().process_frame
				Input.action_press(action)
				await get_tree().process_frame
				Input.action_release(action)
				await get_tree().process_frame
			if player == bike:
				_toggle_mount()
			state = "to_home"
			jemma = 0
			beers = 3
			walker_out.global_position = home_zone + Vector3(0, 0.5, 0)
			for i in 3:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("OVI kaljat kädessä: state=%s hint=%s" % [state, _hint.text])
			await _test_goto_stash("koti")
			print("OVI jemman luona: hint=%s" % _hint.text)
			for i in 3:
				await press.call("interact")
			print("OVI piilotettu: beers=%d jemma=%d state=%s hint=%s" % [beers, jemma, state, _hint.text])
			_on_home_exited()
			walker_out.global_position = home_zone + Vector3(3.0, 0.5, 2.0)
			await get_tree().physics_frame
			await get_tree().process_frame
			print("OVI pihalla tyhjin käsin: hint=%s" % _hint.text)
			walker_out.global_position = home_zone + Vector3(0, 0.5, 0)
			for i in 3:
				await get_tree().physics_frame
				await get_tree().process_frame
			print("OVI ovella: state=%s jemma=%d" % [state, jemma])
			for i in 30:
				await get_tree().process_frame
			print("OVI aamu: day=%d msg=%s" % [day, _msg.text.replace("\n", " | ")])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"pontikka":
			# Pannu-Sulo: kuva paikasta, kanisterin osto ja kotiinpaluu. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			_toggle_mount()
			var sp := sulo.global_position
			walker_out.global_position = sp + Vector3(2.0, 0.5, 2.5)
			walker_out.look_at(Vector3(sp.x, walker_out.global_position.y, sp.z))
			for i in 30:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("PONTIKKA hint=", _hint.text, " money=", _eur(money))
			var tc := Camera3D.new()
			add_child(tc)
			var still := M.w(M.PONTIKKA)
			tc.global_position = still + Vector3(4.5, 2.6, 5.0)
			tc.look_at(still + Vector3(-0.6, 0.6, 0), Vector3.UP)
			tc.current = true
			_msg.text = ""
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_still.png"))
			tc.queue_free()
			walker_out.activate_camera()
			await get_tree().process_frame
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("BUY kanister=%s state=%s money=%s hint=%s" % [has_kanister, state, _eur(money), _hint.text])
			for i in 60:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_carry.png"))
			var cc := Camera3D.new()
			add_child(cc)
			var wp := walker_out.global_position
			cc.global_position = wp + walker_out.global_transform.basis * Vector3(-1.6, 0.9, -1.2)
			cc.look_at(wp + Vector3(0, 0.7, 0), Vector3.UP)
			cc.current = true
			_msg.text = ""
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_hand.png"))
			cc.queue_free()
			jemma = 3
			# Kanisteri piilotetaan itse eteisen kaappiin, sitten tyhjin käsin ovelle.
			await _test_goto_stash("koti")
			print("STASH hint=", _hint.text)
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("STASH kanister=%s jemma=%d msg=%s" % [has_kanister, jemma, _msg.text.replace("\n", " | ")])
			_on_home_exited()
			walker_out.global_position = home_zone + Vector3(0, 0.5, 0)
			for i in 3:
				await get_tree().physics_frame
				await get_tree().process_frame
			print("WIN kanister=%s jemma=%d endings=%d state=%s" % [has_kanister, jemma, jemma_endings, state])
			for i in 60:
				await get_tree().process_frame
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"lawnday":
			# Kasvu, kehu ja motkotus aamulla, varaosa Artolta ja korjaus kaljalla. Tallennus palautetaan.
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			_toggle_mount()
			lawn.lengths.fill(0.5)
			_lawn_praise = true
			_new_day(home_zone + Vector3(0, 0, 4), false)
			print("DAY avg=%.2f money=%s objs=%d msg=%s" % [lawn.avg_len(), _eur(money), lawn.objects.size(), _msg.text.replace("\n", " | ")])
			mower_broken = true
			walker_out.global_position = arto.global_position + Vector3(1.5, 0.3, 0)
			for i in 10:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("ARTO hint=", _hint.text)
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("ARTO part=%s money=%s" % [has_mower_part, _eur(money)])
			beers = 1
			walker_out.global_position = lawn.mower.global_position + Vector3(1.0, 0.3, 0)
			for i in 10:
				await get_tree().physics_frame
			await get_tree().process_frame
			print("FIX hint=", _hint.text)
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			print("FIX broken=%s part=%s beers=%d" % [mower_broken, has_mower_part, beers])
			_save_game()
			var cfg := ConfigFile.new()
			cfg.load(SAVE_PATH)
			var bytes: PackedByteArray = cfg.get_value("nurmikko", "pituudet", PackedByteArray())
			print("SAVE cells=%d first=%d" % [bytes.size(), bytes[0] if bytes.size() > 0 else -1])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
		"lawn", "police":
			# Nurmikko: kuva ylhäältä, sitten leikkuu eteenpäin (police: kaksi siiliä terän eteen).
			var saved := FileAccess.get_file_as_bytes(SAVE_PATH)
			_toggle_mount()
			walker_out.global_position = lawn.mower_park + Vector3(1.2, 0.5, 0.8)
			for i in 20:
				await get_tree().physics_frame
			print("LAWN avg=%.2f ratio=%.2f objs=%d hint=%s" % [lawn.avg_len(), lawn.cut_ratio(), lawn.objects.size(), _hint.text])
			_msg.text = ""
			var tc := Camera3D.new()
			add_child(tc)
			var c := Vector3(lawn.pivot.x, 0, lawn.pivot.y)
			c.y = Terrain.h(c.x, c.z)
			tc.global_position = c + Vector3(-9.0, 9.0, 12.0)
			tc.look_at(c, Vector3.UP)
			tc.current = true
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_top.png"))
			tc.queue_free()
			walker_out.activate_camera()
			if scene == "police":
				var sp: Vector3 = lawn.mower_park + Vector3(0, 0, -2.0)
				for o in lawn.objects.duplicate():
					if o.kind == "siili":
						lawn.remove_object(o)
				for k in 2:
					var n := Node3D.new()
					lawn.add_child(n)
					lawn.objects.append({"kind": "siili", "pos": Vector2(sp.x, sp.z - k * 1.5), "r": 0.16, "node": n})
			await get_tree().process_frame
			Input.action_press("interact")
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().process_frame
			print("MOW start mowing=", mowing, " msg=", _msg.text.replace("\n", " | "))
			Input.action_press("forward")
			for i in 300:
				await get_tree().physics_frame
				if not mowing:
					break
			Input.action_release("forward")
			print("MOW after ratio=%.2f mowing=%s siilit=%d kivet=%d broken=%s police=%s msg=%s" % [lawn.cut_ratio(), mowing,
				lawn_siilit, lawn_kivet, mower_broken, is_instance_valid(police), _msg.text.replace("\n", " | ")])
			_msg.text = ""
			var tc2 := Camera3D.new()
			add_child(tc2)
			tc2.global_position = c + Vector3(-7.0, 10.0, 9.0)
			tc2.look_at(c, Vector3.UP)
			tc2.current = true
			for i in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_cut.png"))
			tc2.queue_free()
			player.activate_camera()
			if scene == "police":
				for i in 1800:
					await get_tree().physics_frame
					if i % 120 == 0 and is_instance_valid(police):
						print("  police t=%d d=%.1f mode=%s alerted=%s" % [i / 60, police.global_position.distance_to(player.global_position),
							police.mode, police.alerted])
					if state != "to_shop":
						break
				print("POLICE d=%.1f status=%s state=%s" % [police.global_position.distance_to(player.global_position) if is_instance_valid(police) else -1.0,
					_status.text, state])
			if not saved.is_empty():
				FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
