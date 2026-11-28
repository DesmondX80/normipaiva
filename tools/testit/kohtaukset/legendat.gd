extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "legendat": lavastetut legendaariset hetket, jotka eivät kuulu maatilalle
## (maatilan hetket: kaisua.gd *_sato, *_talkoot, *_kylvot). aja() palauttaa 0 = kohtaus ei kuulu ryhmään.
## Kohtaukset ottavat pelaajan tallennuksen talteen alussa ja palauttavat sen lopussa.
##
## mokki_paapeli: Pekan kyyti tarinan jälkeen (story valmis) -> saapuminen mökin pihaan (cutscene.gd paapeli_saapuu):
##   kuvat kyydistä, kaahauksesta, Santusta, autosta noususta ja noususta mökin ylle; hetki kirjataan vasta perillä
##   (päiväkirjarivi, ei vanhaa ilmoitusta) ja toinen kyyti ei toista saapumista, vaan Pekka muistelee.
## pentti_eka: Pentin ensimmäinen kyyti (rikos/pentti.gd _kyyti): keinunta, liukuovi aukeaa, mummo pudottaa kassin,
##   Pentti ovelta ja nousu parkkipaikan ylle; hetki kirjataan aamulla (päiväkirjarivi), toinen kyyti ilman huipennusta.
## mokki_savusauna_eka: korjatun savusaunan ensimmäiset löylyt (sauna_relax first) ja laiturilta Likaseen
##   (savusauna_jarvi): kuvat löylystä, juoksusta, hypystä, uijista ja noususta; toiset löylyt eivät toista kohtausta.
## tuppi_eka: räsytupin ensimmäinen voitto Saloisissa (tuppi_game.gd _leg_*): viimeinen jako pakotetaan kavereiden
##   tappioksi, kuvat ässän iskusta, kalsarikavereista, polaroidista (salama, kehitys) ja otsikosta; aamulla kuva
##   keittiön ikkunassa. Toinen ilta: nainen muistelee polaroidia, voitto ilman huipennusta lasketaan hiljaa.
## lettu_eka: lettukisan ensimmäinen voitto Saloisissa (lettu_game.gd _leg_*): kisa pakotetaan pelaajan voitoksi,
##   kuvat tyhjästä lautasesta, kruunauksesta, vatkaimesta, nuolaisusta ja otsikosta. Toinen ilta: kaveri muistelee,
##   voitto ilman huipennusta lasketaan hiljaa.
## loyly_eka: löylykisan ensimmäinen voitto Saloisissa (loyly_game.gd _leg_*): kaverit pakotetaan pakoon, kuvat
##   viimeisestä kauhasta ja höyrypilvestä, kavereista ovella pyyhkeet kourassa, pyyhkeen putoamisesta (polvista alas),
##   reaktiosta ja otsikosta. Toinen ilta: joku muistelee, voitto ilman huipennusta lasketaan hiljaa.
## disko_eka: Sivikki-diskon ensimmäinen voitto Vaalassa (disko_game.gd _leg_*): kisa pakotetaan pelaajan voitoksi,
##   kuvat bassodropista, Katjan ja pelaajan tanssiotteesta, akun hyytymisestä (Timo ja pimeät ajovalot), laulusta
##   ja otsikosta; tanssiotteen läpimenot mitataan. Toinen ilta: joku muistelee akkua, voitto lasketaan hiljaa.
## karaoke_eka: karaoke-illan ensimmäinen voitto Saloisissa (ilta_karaoke.gd _leg_*): vuorot ohitetaan pelaajan
##   voitoksi, kuvat kertosäkeestä (nainen jakkaralla), naapurin ikkunasta ja patterista, jähmettyneestä porukasta,
##   finaalista, ennätyksestä ja otsikosta; naisen jalat jakkaran kannella mitataan. Toinen ilta: joku muistelee
##   naapuria, voitto lasketaan hiljaa.
## kesaheila_eka: kesäheilan ensimmäinen ovi kotona (kolmio_kohtaus.gd _leg_*): kolme mittausta kotiin, kuvat
##   Sytkärin kartasta (ympyrät ja neula), koputuksesta, Päivistä lavakuvan hatussa, lavakuvasta ja sydämestä,
##   kavereista, kerman ojennuksesta ja otsikosta; nauraa -> hetki kirjataan (päiväkirjarivi). Toinen kerta: tavallinen
##   ovi, Päivi muistelee ja hattu on eteisen naulassa, tunnustaa -> laskettiin hiljaa ilman otsikkoa.
## lava_eka: Oulujärven lavan ensimmäinen hyvä humppa (lava_game.gd _leg_*): kappale pakotetaan hyväksi, kuvat
##   laulajasta mikillä, olan yli lattialle, piiriin kävelystä ja taputuksesta, rinta rinnan potkusta (kolmas potku),
##   ukon ja mummon repliikeistä ja otsikosta; kädet ja jalat mitataan (taputus, potku). Lavalta ulos -> päiväkirjarivi.
##   Toinen käynti: pari muistelee, hyvä humppa ilman huipennusta lasketaan hiljaa.
## karaoke_baari_eka: baarin karaoken ensimmäinen raikuva veto Siitarissa (karaoke_legenda.gd): kuvat viimeisestä
##   sävelestä, hiljaisuudesta, salin aplodeista ja kumarruksesta, kellosta, tuopin liu'usta ja kiinniotosta, taulusta
##   ja otsikosta; kädet mitataan (mikki, taputus, tuoppi). Taulu jää seinälle, hetki päiväkirjaan. Toinen käynti:
##   baarimikko muistelee, raikuva veto lasketaan hiljaa. Lopuksi sama kohtaus Kapteenin Kellarissa (kuvat).
## kiihdytys_eka: mopojen kiihdytyksen ensimmäinen voitto Vaalantiellä (kiihdytys_legenda.gd): kisan tulos pakotetaan
##   voitoksi, kuvat hidastetusta maalista (lähestyminen, salama viivalla, vastustaja perässä), vastustajan ilmeestä,
##   keulinnasta ja hurraavista mopopojista, työnnöstä Zabukille ja otsikosta; keulinta, lippu ja työntäjän kädet
##   mitataan. Hetki päiväkirjaan. Toinen käynti: pojat muistelevat, voitto ilman huipennusta lasketaan hiljaa.
## tanssit_eka: seuraintalon tanssien ensimmäinen hyvä tanssi Sinikan kanssa (tanssi_game.gd _leg_*): tanssi pakotetaan
##   hyväksi, kuvat viimeisestä valssista (valot himmenevät), taivutuksesta, valojen syttymisestä (Anna-Liisa lupaa
##   kertoa kylälle) ja otsikosta; parin koko kuvassa, taivutuksen kädet, jalat ja läpimenot mitataan. Hetki
##   päiväkirjaan ja sali palautuu. Toinen käynti: Anna-Liisa muistelee, hyvä tanssi ilman huipennusta lasketaan hiljaa.
## piirakka_eka: Reipparin lihapiirakkahaasteen ensimmäinen ennätys (piirakka_legenda.gd): haaste pakotetaan kahdeksaan
##   piirakkaan, kuvat viimeisestä palasta ja laskusta, Juntin paperilaskennasta, rullamitasta, Raijan tussiviivasta ja
##   lapusta, röyhtäyksestä ja otsikosta; kädet (paperi, mitta, nenä), kohteiden koko kuvassa ja asennot mitataan.
##   Hetki päiväkirjaan, taulussa uusi nimi. Toinen haaste: Juntti tai Raija muistelee, ennätys lasketaan hiljaa.
## sahkopyora_eka: sähköpyörän viimeinen liitos autotallissa (main.gd _start_ebike_game) -> ensimmäinen koeajo
##   (sahkopyora_legenda.gd): kuvat nosturiovesta ja naapureista, kaasukahvasta ja kipinästä, keulan noususta,
##   Järvikujan ajosta (Sinikka vilkuttaa), paluusta (Pekka ja Arto osoittavat osiaan) ja otsikosta; pyörän koko ja
##   paikka kuvassa, keula, osoitukset ja teipinpätkä mitataan. Lopuksi pelaaja pyörän selässä tallin edessä,
##   naapurit palaavat ja hetki päiväkirjaan. Pyörä kasataan vain kerran, joten toista kertaa ei ole: Pekka tai Arto
##   muistelee koeajoa jutellessa.
## porron_kyltti_eka: Pörrön muistolaudan maalaus valmis (muistokyltti_game.gd) -> lehdon hetki (porro_legenda.gd):
##   kuvat poikien tulosta, pikkuveljen voikukasta, kivien asettamisesta yksi kerrallaan, "Setä on ihan ok" -hetkestä
##   ja otsikosta; kyltin ja hahmojen paikka kuvassa, kädet kiven laskussa ja kivien paikat mitataan. Lopuksi kivet ja
##   kukka jäävät tolpan juurelle, oikeat pojat palaavat ja hetki päiväkirjaan. Tehtävä tehdään vain kerran: pojat
##   muistelevat ("Mitäs Pörrön kyltille kuuluu?").
## aarnivalkea_eka: Lapinraunion hopeat ensimmäistä kertaa Saloisten Pirttiin (main.gd _aarni_museum) -> Pirtin pihan
##   hetki (aarnivalkea_legenda.gd): kuvat kontista ja pöytäkirjasta, kannen nostosta ja viimeisestä sinisestä liekistä
##   (lehahtaa ja sammuu), hätkähdyksestä, hopeista liinalla ja taalerin välähdyksestä, Hilkasta ja epäilijöistä sekä
##   otsikosta; kontin, liekin, hopeiden ja hahmojen paikka kuvassa mitataan. Lopuksi oikea pelaaja palaa ja hetki
##   päiväkirjaan. Hopeat viedään vain kerran: Hilkka muistelee ("Muistatko, kun aarnivalkea sammui Pirtin pihalla?").
## kertun_rauta_eka: Kertunkankaan kirves Saloisten Pirttiin (ei vielä hetkeä, tehtävä "näytä lehtijuttu") -> lehti
##   kodalle Raimolle ja Veikolle (kertun_legenda.gd): kuvat sisääntulosta ja lehden ojennuksesta, Raimon lukemisesta ja
##   etusivusta ilmassa, Veikon "Perkele" ja kiroilukyltistä, kaljakassista ja kilistyksestä, leikkeestä seinällä ja
##   otsikosta; lehden koko kuvassa, kädet (ojennus, lehti, tölkit, kilistys, osoitus) ja hahmot mitataan. Lopuksi
##   Veikon kaljat, leike jää seinälle, oikeat Raimo ja Veikko palaavat ja hetki päiväkirjaan. Muistelu kodan jutuissa.
## tekojarven_ukko_eka: Tekojärven Ukko ensimmäistä kertaa Saloisten Pirttiin (main.gd _ukko_museum) -> Pirtin pihan
##   hetki (tekojarvi_legenda.gd): kuvat kolmijalasta ja heiluvasta Ukosta, puntarin taulusta (viisari asettuu 18,4:ään),
##   uistimista kyljessä, Taunon tulosta ja kosketuksesta isän lusikkaan, kyyneleestä, lehtikuvasta ja otsikosta; Ukon
##   pituus ja paikka kuvassa, taulun koko, Taunon käsi lusikalla, kyynel ja kädet hauen alla mitataan. Lopuksi
##   oikea pelaaja palaa, hetki päiväkirjaan ja Taunolle uusi kysymys punnituksesta.
## tokolan_aarre_eka: Heinimäen rahalipas ensimmäistä kertaa Aarolle (main.gd _talk_aaro "lipas") -> Aaron pihan hetki
##   (tokola_legenda.gd): kuvat lippaasta pölkyllä, puukolla väännöstä, kannen aukeamisesta, sormuksesta lähikuvassa ja
##   valoa vasten, Aaron huudosta tielle, Pekan ja Arton tulosta, leijailevasta setelistä, Pekan lukemisesta ja otsikosta;
##   puukon käsi kannella, sormuksen koko, nipun nosto pään yli, etusormi suorana ja setelin sieppaus mitataan. Lopuksi
##   oikea pelaaja ja Aaro palaavat, hetki päiväkirjaan ja Aarolle uusi kysymys setelistä.
## sulon_pannu_eka: Pilkkarinnevan kuparipannu ensimmäistä kertaa Pannu-Sulolle (main.gd _pannu_to_sulo) -> metsän hetki
##   pontikkapannun luona (sulo_legenda.gd): kuvat pannusta kivellä, leiman hankaamisesta ja kirkkaasta leimasta, Sulon
##   myönnöstä Pilkkarinnevalle päin, kuksasta, tippojen heitosta ja sinisestä leimahduksesta, Pekan ja Arton tulosta,
##   maistiaisista ja otsikosta; pannun ja leiman koko kuvassa, Sulon käsi leimalla, leimahdus ja maistaminen mitataan.
##   Lopuksi ilmainen kanisteri, isän pannu jää kivelle, oikea Sulo palaa, hetki päiväkirjaan ja Sululle muistelukysymys.
## palon_pyhimys_eka: Tokolan orren pyhimys ensimmäistä kertaa suntiolle (main.gd _talk_pyhimys "pyhimys_anna") -> kirkon
##   portaiden ja haudan hetki (pyhimys_kohtaus.gd): kuvat ojennuksesta, kääreen avauksesta ja pyhimyksestä lähikuvassa,
##   pöydästä, yliviivatusta rivistä ja "palautettu"-kirjoituksesta, suvun nimen salaamisesta ja nyökkäyksestä, ovien
##   aukeamisesta valoon ja sulkeutumisesta, kynttilästä haudalla, sen sammumisesta ja naisen lähdöstä sekä otsikosta;
##   pyhimyksen koko kuvassa, kädet kääreellä, sormi rivillä, kirjoitus, ovet ja kynttilän sammuminen mitataan. Lopuksi
##   oikeat hahmot palaavat, hetki päiväkirjaan ja suntiolle muistelukysymys.

## kuninkaan_tapuli_eka: Kustaa III:n piirustus ensimmäistä kertaa Pirtin oppaalle (main.gd _kuningas_pirtti) -> tapulin
##   juuren hetki (tapuli_legenda.gd): kuvat pöydästä ja lyijykotelosta, rullan nostosta, riippusinetistä suurennuslasin
##   takaa, kävelystä ja rullan avauksesta, piirustuksesta olan yli, nostosta tapulia vasten ja haalistuneesta paperista
##   (kuninkaan viivat oikean tapulin päällä), kellon heilahduksesta, Pekan ja Arton tulosta, tölkeistä ja nostosta sekä
##   otsikosta; tapulin ääriviivojen projektio paperille, kädet rullilla, sinetin koko ja kellon heilunta mitataan.
##   Lopuksi oikeat hahmot palaavat, hetki päiväkirjaan ja suntiolle muistelukysymys.
## pakkahuoneen_veistos_eka: Pakkahuoneen kellarin luukku ensimmäistä kertaa molempien vihjeiden jälkeen (main.gd
##   _pakkahuone_acted "luukku") -> museon hetki (veistos_kohtaus.gd): kuvat avaimesta, kannen aukeamisesta ja pölystä,
##   kuraattorin tulosta, laatikon nostosta, kannesta, pyhimyksen nostosta ja pyyhkimisestä, kannosta salin poikki
##   (kävijät väistävät), jalustalle nostosta ja säädöstä, kyltin käännöstä, auringosta ja taputuksesta sekä otsikosta;
##   avaimen käsi, pyhimyksen koko lähikuvassa, kädet pyhimyksellä kannossa ja pyhimys jalustalla mitataan. Lopuksi
##   oikea pelaaja ja kuraattori palaavat, pyhimys jää jalustalle, hetki päiväkirjaan ja kuraattori muistelee.
## hanhikiven_rajakivi_eka: Hanhikivi ensimmäistä kertaa molempien vihjeiden jälkeen (main.gd _hanhikivi_kivi) ->
##   Koskipuiston hetki (hanhikivi_kohtaus.gd): kuvat kämmenestä kiven kyljellä, painaumasta ja kalastajasta, auran
##   lennosta, laskeutumisesta, hanhesta kivellä ja huudosta, kuskin tulosta, lähdöstä ja sulasta sekä otsikosta;
##   kämmen kiven pinnalla, hanhen jalat kiven päällä ja koko kuvassa sekä sulka kivellä mitataan. Lopuksi oikeat
##   hahmot palaavat, sulka jää kivelle, hetki päiväkirjaan ja kalastaja muistelee.
## peruskiven_kapseli_eka: Rojuniemen laatta ensimmäistä kertaa molempien vihjeiden jälkeen (main.gd _peruskivi_acted
##   "laatta") -> kapselin hetki (kapseli_kohtaus.gd): kuvat vartijan huomaamisesta, laatan noususta ja pölystä,
##   kapselista kolossa, nostosta, kannen kierrosta, kolikosta ja rullasta, kirjeestä olan yli ja kasvoista, radiosta,
##   höyrypillistä ja kuskista sekä otsikosta; kädet laatan reunalla, kapselin koko, kirjeen teksti ja höyry mitataan.
##   Lopuksi oikeat hahmot palaavat, laatta auki ja kolo tyhjä, kapseli kopin ikkunalla, hetki päiväkirjaan ja vartija
##   muistelee.
## manamansalon_kirkko_eka: Manamansalon kivijalka ensimmäistä kertaa molempien vihjeiden jälkeen (main.gd
##   _manamansalo_acted "jaanteet") -> kivijalan hetki (manamansalo_kohtaus.gd): kuvat kynttilän laskusta ja sytytyksestä,
##   oppaan tulosta, lyhtykierroksesta, haamukirkon noususta ja haalistumisesta, nimikiistasta ja otsikosta; käsi kynttilällä
##   ja lyhtyjen kahvoilla, kynttilän ja kirkon koko kuvassa ja hahmot kuvassa mitataan. Lopuksi oikeat hahmot palaavat,
##   kynttilä ja lyhdyt palavat, hetki päiväkirjaan ja opas muistelee.
## kanttorin_virsi_eka: kanttorin nuotit ensimmäistä kertaa Sinikan kuorolle (main.gd _talk_kanttori "kanttori_kuoro")
##   -> seuraintalon konsertti (kanttori_virsi.gd): kuvat salista, Sinikan esittelystä, laulusta, Hilkan kyynelestä,
##   harmoonin kannen aukeamisesta ja itsestään painuvista koskettimista, Sinikan vilkaisusta ja yleisön kääntymisestä,
##   aamenesta ja katkaisusta, Kanttorilan ikkunan kajosta ja sen sammumisesta sekä otsikosta; kädet kansioilla ja
##   silmällä, kansi, painetut koskettimet, ikkunan kajo ja hahmot kuvassa mitataan. Lopuksi sali palaa ennalleen, hetki
##   päiväkirjaan ja Sinikalle muistelukysymys.
## ukko_vapaa_eka: Tekojärven Ukko päästetään ensimmäistä kertaa järveen Kaitasaaren kärjestä (main.gd _ukko_release)
##   -> rannan hetki (ukko_vapaa_legenda.gd): kuvat Ukosta vedessä käsien varassa ja Taunon tulosta, isän lusikan
##   irrotuksesta ja lähikuvasta, pyrstön roiskeesta ja vanavedestä raunioille, hypystä tolppien välissä ja vilkutuksesta,
##   kahvin kaadosta, mukin ojennuksesta ja juonnista sekä otsikosta; kädet hauen alla, Taunon käsi lusikalla, Ukon koko
##   ja paikka kuvassa, hypyn korkeus, muki kädessä ja hahmot kuvassa mitataan. Lopuksi hetki päiväkirjaan, rauniot jäävät
##   järveen ja Taunolle muistelukysymys.
## drakkar_eka: Drakkar Noir ostetaan ensimmäistä kertaa Railin pöydältä (main.gd _kirppis_give "drakkar") -> salin
##   hetki (drakkar_kohtaus.gd): kuvat pullon ojennuksesta, katsomisesta, suihkauksesta ja Railin haistamisesta, pilven
##   leviämisestä (Anna-Liisa leyhyttää, Hilkka aivastaa, Tauno sipaisee tukkaa), pilvestä Seurantiellä (Sinikka ja Pekka)
##   ja otsikosta; käsi pullolla, pullon koko, pilven reuna hahmojen kohdalla ja hahmot kuvassa mitataan. Lopuksi sali
##   palaa, hetki päiväkirjaan, pullossa suihkaukset ja Raili muistelee seuraavalla käynnillä.
## kinkku_eka: bingon ensimmäinen jättipotti (main.gd _start_bingo, bingo_jackpot pakotettu) -> salin hetki
##   (kinkku_kohtaus.gd): kuvat BINGO-huudosta ja mummojen mulkoilusta, Erkin tarkistuksesta ja lapun lähikuvasta, Elvin
##   katkeavasta kynästä, kinkun kannosta ja luovutuksesta, kinkusta sylissä, mummojen puuskista, selän käännöstä ja
##   otsikosta; lappu ja kinkku käsissä, kinkun koko kuvassa ja hahmot kuvassa mitataan. Lopuksi sali palaa, hetki
##   päiväkirjaan ja Hilkka muistelee seuraavassa bingossa.

const Main := preload("res://scripts/main.gd")
const Kuva := preload("res://tools/testit/kuva.gd")
const TanssiGame := preload("res://scripts/tanssi_game.gd")
const Contact := preload("res://scripts/contact.gd")
const PiirakkaGame := preload("res://scripts/piirakka_game.gd")
const PiirakkaLegenda := preload("res://scripts/piirakka_legenda.gd")
const SahkopyoraLegenda := preload("res://scripts/sahkopyora_legenda.gd")
const EBikeGame := preload("res://scripts/ebike_game.gd")
const PorroLegenda := preload("res://scripts/porro_legenda.gd")
const Terrain := preload("res://scripts/terrain.gd")
const MuistokylttiGame := preload("res://scripts/muistokyltti_game.gd")
const AarnivalkeaLegenda := preload("res://scripts/aarnivalkea_legenda.gd")
const KertunLegenda := preload("res://scripts/kertun_legenda.gd")
const TekojarviLegenda := preload("res://scripts/tekojarvi_legenda.gd")
const UkkoVapaa := preload("res://scripts/ukko_vapaa_legenda.gd")
const TokolaLegenda := preload("res://scripts/tokola_legenda.gd")
const SuloLegenda := preload("res://scripts/sulo_legenda.gd")
const SuloPannu := preload("res://scripts/sulo_pannu.gd")
const PyhimysKohtaus := preload("res://scripts/pyhimys_kohtaus.gd")
const OlaviMarkkinat := preload("res://scripts/olavi_markkinat.gd")
const TapuliLegenda := preload("res://scripts/tapuli_legenda.gd")
const VeistosKohtaus := preload("res://scripts/veistos_kohtaus.gd")
const PakkahuoneLegenda := preload("res://scripts/pakkahuone_legenda.gd")
const HanhikiviKohtaus := preload("res://scripts/hanhikivi_kohtaus.gd")
const HanhikiviLegenda := preload("res://scripts/hanhikivi_legenda.gd")
const KapseliKohtaus := preload("res://scripts/kapseli_kohtaus.gd")
const ManamansaloKohtaus := preload("res://scripts/manamansalo_kohtaus.gd")
const KanttoriVirsi := preload("res://scripts/kanttori_virsi.gd")
const DrakkarKohtaus := preload("res://scripts/drakkar_kohtaus.gd")
const KinkkuKohtaus := preload("res://scripts/kinkku_kohtaus.gd")
const BingoGame := preload("res://scripts/bingo_game.gd")
const ManamansaloLegenda := preload("res://scripts/manamansalo_legenda.gd")
const PeruskiviLegenda := preload("res://scripts/peruskivi_legenda.gd")
const M := preload("res://scripts/map_data.gd")

const KOHTAUKSET := ["mokki_paapeli", "mokki_savusauna_eka", "pentti_eka", "tuppi_eka", "lettu_eka", "loyly_eka", "disko_eka", "karaoke_eka",
	"kesaheila_eka", "lava_eka", "karaoke_baari_eka", "kiihdytys_eka", "tanssit_eka", "piirakka_eka", "sahkopyora_eka", "porron_kyltti_eka",
	"aarnivalkea_eka", "kertun_rauta_eka", "tekojarven_ukko_eka", "tokolan_aarre_eka", "sulon_pannu_eka",
	"palon_pyhimys_eka", "olavinmarkkinat_eka", "kuninkaan_tapuli_eka", "pakkahuoneen_veistos_eka",
	"hanhikiven_rajakivi_eka", "peruskiven_kapseli_eka", "manamansalon_kirkko_eka",
	"kanttorin_virsi_eka", "ukko_vapaa_eka", "drakkar_eka", "kinkku_eka"]

var main: Main
var _viat := 0


func aja(scene: String, path: String, _nohud: bool) -> int:
	if not scene in KOHTAUKSET:
		return 0
	var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
	match scene:
		"mokki_paapeli":
			await _paapeli(path)
		"mokki_savusauna_eka":
			await _savusauna(path)
		"pentti_eka":
			await _pentti(path)
		"tuppi_eka":
			await _tuppi(path)
		"lettu_eka":
			await _lettu(path)
		"loyly_eka":
			await _loyly(path)
		"disko_eka":
			await _disko(path)
		"karaoke_eka":
			await _karaoke(path)
		"kesaheila_eka":
			await _kesaheila(path)
		"lava_eka":
			await _lava(path)
		"karaoke_baari_eka":
			await _baari(path)
		"kiihdytys_eka":
			await _kiihdytys(path)
		"tanssit_eka":
			await _tanssit(path)
		"piirakka_eka":
			await _piirakka(path)
		"sahkopyora_eka":
			await _sahkopyora(path)
		"porron_kyltti_eka":
			await _porro(path)
		"aarnivalkea_eka":
			await _aarni(path)
		"kertun_rauta_eka":
			await _kerttu(path)
		"tekojarven_ukko_eka":
			await _ukko(path)
		"tokolan_aarre_eka":
			await _tokola(path)
		"sulon_pannu_eka":
			await _sulo(path)
		"palon_pyhimys_eka":
			await _pyhimys(path)
		"olavinmarkkinat_eka":
			await _olavi(path)
		"kuninkaan_tapuli_eka":
			await _tapuli(path)
		"pakkahuoneen_veistos_eka":
			await _pakka(path)
		"hanhikiven_rajakivi_eka":
			await _hanhi(path)
		"peruskiven_kapseli_eka":
			await _kapseli(path)
		"manamansalon_kirkko_eka":
			await _manamansalo(path)
		"kanttorin_virsi_eka":
			await _kanttori(path)
		"ukko_vapaa_eka":
			await _ukko_vapaa(path)
		"drakkar_eka":
			await _drakkar(path)
		"kinkku_eka":
			await _kinkku(path)
	FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
	return 1


func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame


func _shot(path: String, name: String) -> void:
	await Kuva.piirto()
	await Kuva.piirto()
	var p := path.replace(".png", "_%s.png" % name)
	Kuva.ruutu(main.get_viewport()).save_png(p)
	print("LEGENDA kuva ", p)


func _check(ok: bool, what: String) -> void:
	print("LEGENDA %s: %s" % [what, "OK" if ok else "EI"])
	if not ok:
		_viat += 1
		print("TESTI VIKA %s" % what)


## Kuvat ajallisesti (sekuntia alusta) ja odotus, kunnes välianimaatiot ovat ohi.
func _shots_until_done(path: String, shots: Array, max_s := 120.0) -> void:
	# Välianimaation oma kello (cutscene.gd _now_ms): testiajo voi kulkea hitaammin kuin seinäkello.
	var t0: float = main.cutscene._now_ms()
	for st in shots:
		# [nimi, s alusta] tai [nimi, vaihe, s vaiheen alusta] (cutscene.gd phase)
		if st.size() == 3:
			while main.cutscene.phase != st[1] and main.cutscene.busy:
				await _frames(1)
			var tp: float = main.cutscene._now_ms()
			while (main.cutscene._now_ms() - tp) / 1000.0 < float(st[2]) and main.cutscene.busy:
				await _frames(1)
		while st.size() == 2 and (main.cutscene._now_ms() - t0) / 1000.0 < float(st[1]) and main.cutscene.busy:
			await _frames(1)
		if not main.cutscene.busy:
			print("LEGENDA kuva %s jäi ottamatta: kohtaus loppui %.1f s" % [st[0], (main.cutscene._now_ms() - t0) / 1000.0])
			break
		await _shot(path, st[0])
	while main.cutscene.busy and (main.cutscene._now_ms() - t0) / 1000.0 < max_s:
		await _frames(1)
	await _frames(4)  # hidas ajo: päiväkirjarivi (3,5 s) ehtisi kadota pitkässä odotuksessa


func _paapeli(path: String) -> void:
	if main.player != main.walker_out:
		main._toggle_mount()
	main.money = 30.0
	main.story.step = "valmis"
	main.endings.counts.erase("paapeli")
	main.pekka.process_mode = Node.PROCESS_MODE_DISABLED
	main._note.visible = false
	main._pekka_ride()
	await _frames(2)
	_check(not main.endings.counts.has("paapeli"), "Paapeli: hetkeä ei kirjattu kyydin alussa")
	# Kyyti 12 s + häivytykset, sitten saapuminen: kaahaus 4,6 s, pölypilvi 3,6 s, autosta nousu 4,2 s, nousu 7,5 s.
	await _shots_until_done(path, [["kyyti", 3.0], ["kaahaus", 17.0], ["perilla", 19.6], ["santtu", 22.4], ["santtu2", 25.5], ["nousu", 32.5]], 240.0)
	var lp: Vector3 = main.mokki.to_local(main.walker_out.global_position)
	print("LEGENDA Paapeli jälkeen: kerrat %d, viesti '%s', paikka (%.1f, %.1f), ohjaus %s" % [int(main.endings.counts.get("paapeli", 0)),
		main._msg.text, lp.x, lp.z, main.walker_out.controls_enabled])
	_check(int(main.endings.counts.get("paapeli", 0)) == 1, "Paapeli: hetki kirjattiin perillä")
	_check(main._msg.text.contains("uusi tarina"), "Paapeli: päiväkirjarivi")
	_check(main.walker_out.controls_enabled and main.mokki.parked_volvo[0].visible, "Paapeli: ohjaus ja pysäköity Volvo takaisin")
	await _shot(path, "jalkeen")
	# Toinen kyyti: ei saapumiskohtausta, Pekka muistelee, kerta lasketaan hiljaa.
	main._pekka_ride()
	await _frames(2)
	_check(int(main.endings.counts.get("paapeli", 0)) == 2, "Paapeli: toinen kyyti laskettiin")
	await _shots_until_done(path, [["toinen_kyyti", 1.5]], 120.0)
	_check(not main._msg.text.contains("LEGENDAARINEN"), "Paapeli: toisella kyydillä ei ilmoitusta")


func _savusauna(path: String) -> void:
	var mk: Node3D = main.mokki
	mk.ensure_built()
	# Pelaaja jalan mökin pihalle saunan eteen (kuten pelissä: savusauna on mökillä).
	if main.player != main.walker_out:
		main._toggle_mount()
	main.walker_out.global_position = mk.gpos(Vector3(4.0, 0.3, 16.0))
	main.walker_out.activate_camera()
	await _frames(20)
	main.endings.counts.erase("savusauna")
	mk.sauna_fixed = true
	print("LEGENDA laituri %s -> %s, vesi %.2f" % [mk.dock_start(), mk.dock_end(), mk.dock_water_y()])
	main._sauna_cutscene()
	await _frames(2)
	_check(not main.endings.counts.has("savusauna"), "Savusauna: hetkeä ei kirjattu löylyjen alussa")
	await _shots_until_done(path, [["otsikko", 2.0], ["loyly", 6.2], ["santtu", 15.0], ["juoksu", "juoksu", 0.8],
		["hyppy", "hyppy", 0.5], ["roiske", "hyppy", 1.4], ["uijat", "uijat", 1.6], ["uijat2", "uijat", 3.6], ["nousu", "nousu", 4.5]], 180.0)
	print("LEGENDA savusauna jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("savusauna", 0)), main._msg.text])
	_check(int(main.endings.counts.get("savusauna", 0)) == 1, "Savusauna: hetki kirjattiin järven jälkeen")
	_check(main._msg.text.contains("uusi tarina"), "Savusauna: päiväkirjarivi")
	# Toiset löylyt: tavallinen kohtaus, Santtu muistelee, kerta lasketaan hiljaa.
	main._sauna_cutscene()
	await _frames(2)
	_check(int(main.endings.counts.get("savusauna", 0)) == 2, "Savusauna: toiset löylyt laskettiin")
	await _shots_until_done(path, [["toiset", 2.0]], 120.0)
	_check(not main._msg.text.contains("LEGENDAARINEN"), "Savusauna: toisilla löylyillä ei ilmoitusta")



func _pentti(path: String) -> void:
	if main.player != main.walker_out:
		main._toggle_mount()
	main._note.visible = false
	main.endings.counts.erase("pentin_kyyti")
	var pt: RefCounted = main.rikos_osa("pentti")
	pt.kyydit = 0
	pt.todistaja_pakko = 0
	var day0: int = main.day
	pt._kyyti()
	await _frames(2)
	_check(not main.endings.counts.has("pentin_kyyti"), "Pentti: ei kirjattu kyydin alussa")
	await _shots_until_done(path, [["keinunta", 4.0], ["hiljaisuus", "hiljaisuus", 1.2], ["ovi", "ovi", 1.0], ["kassi", "ovi", 2.8],
		["pentti", "pentti", 1.6], ["nousu", "nousu", 4.0]], 120.0)
	for i in 200:
		if main.day != day0:
			break
		await _frames(1)
	await _frames(4)
	print("LEGENDA Pentti aamu: päivä %d -> %d, kerrat %d, viesti '%s'" % [day0, main.day, int(main.endings.counts.get("pentin_kyyti", 0)), main._msg.text])
	_check(int(main.endings.counts.get("pentin_kyyti", 0)) == 1, "Pentti: hetki kirjattiin")
	_check(not main._msg.text.contains("LEGENDAARINEN"), "Pentti: ei vanhaa ilmoitusta")
	await _shot(path, "aamu")
	# Toinen kyyti: ei huipennusta.
	pt._kyyti()
	await _frames(2)
	var seen_phase := false
	while main.cutscene.busy:
		if main.cutscene.phase != "":
			seen_phase = true
		await _frames(1)
	_check(not seen_phase, "Pentti: toisella kyydillä ei huipennusta")
	await _frames(60)
	_check(int(main.endings.counts.get("pentin_kyyti", 0)) == 2, "Pentti: toinen kyyti laskettiin hiljaa")


## Räsytuppi kesken illan: kaverit kalsareissa ja viimeinen jako päättyy heidän tappioonsa (tuppi_game.gd "jako").
func _tuppi_win(g: CanvasLayer) -> void:
	g.game.rasy[1] = 3
	g._result = {"haviaja": 1, "voittaja": 0, "tuppeen": true, "ryosto": false, "pisteet": 2}
	g.auto = true
	g._phase = "jako"
	g._t = 0.0


func _tuppi_wait(g: CanvasLayer, phase: String, sec: float) -> bool:
	for i in 20000:
		if not is_instance_valid(g):
			return false
		if g._phase == phase and g._t >= sec:
			return true
		await _frames(1)
	return false


func _tuppi(path: String) -> void:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("rasytuppi")
	DirAccess.remove_absolute(main.TUPPI_KUVA % "saloinen")
	await _frames(10)
	var s: Dictionary = main.kolmio.st("saloinen")
	s.done_day = maxi(0, main.day - 1)
	s.illat = 1
	main._kolmio_kiva("saloinen", "tuppi")
	await _frames(20)
	var g: CanvasLayer = main._rasva_game
	_check(g != null and g.legend and not g.recall, "Tuppi: ensimmäinen ilta, legenda odottaa")
	_tuppi_win(g)
	var shots := [["isku", "isku", 0.3], ["lyonti", "isku", 0.75], ["nousu", "nousu", 1.4], ["nousu2", "nousu", 3.4],
		["kuva", "kuva", 1.2]]
	for st: Array in shots:
		if await _tuppi_wait(g, st[1], st[2]):
			await _shot(path, st[0])
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
	for i in 2000:
		if not is_instance_valid(g) or g._photo != null:
			break
		await _frames(1)
	_check(is_instance_valid(g) and g._photo != null, "Tuppi: polaroid otettiin")
	if is_instance_valid(g):
		var t0: float = g._t
		while is_instance_valid(g) and g._phase == "kuva" and g._t < t0 + 0.25:
			await _frames(1)
		await _shot(path, "salama")
		while is_instance_valid(g) and g._phase == "kuva" and g._t < t0 + 3.4:
			await _frames(1)
		await _shot(path, "kehitys")
		if await _tuppi_wait(g, "otsikko", 2.6):
			await _shot(path, "otsikko")
	for i in 3000:
		if main._kolmio_ui != null:
			break
		await _frames(1)
	await _frames(30)
	var ui: CanvasLayer = main._kolmio_ui
	print("LEGENDA tuppi aamu: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("rasytuppi", 0)), main._msg.text])
	_check(int(main.endings.counts.get("rasytuppi", 0)) == 1, "Tuppi: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Tuppi: päiväkirjarivi")
	_check(ui != null and ui.photo != null, "Tuppi: polaroid aamussa")
	if ui != null:
		ui.auto = false
		ui._line = 1
		ui._view.queue_redraw()
		await _frames(10)
		await _shot(path, "aamu")
		ui._finish()
	await _frames(60)
	# Toinen ilta: muisto, voitto ilman huipennusta.
	main.kolmio.st("saloinen").done_day = maxi(0, main.day - 1)
	main._kolmio_kiva("saloinen", "tuppi")
	await _frames(20)
	g = main._rasva_game
	_check(g != null and not g.legend and g.recall, "Tuppi: toinen ilta ilman legendaa")
	_check(g != null and (String(g._bubbles[2]).contains("polaroid") or String(g._bubbles[2]).contains("kuva")), "Tuppi: nainen muistelee polaroidia")
	await _shot(path, "muisto")
	_tuppi_win(g)
	var seen := false
	while is_instance_valid(g) and main._rasva_game == g:
		if g._phase in ["isku", "nousu", "kuva", "otsikko"]:
			seen = true
		await _frames(1)
	await _frames(30)
	_check(not seen, "Tuppi: toisella voitolla ei huipennusta")
	_check(main._kolmio_ui != null and main._kolmio_ui.photo != null and not main._kolmio_ui.photo_new, "Tuppi: polaroid yhä ikkunassa toisena aamuna")
	_check(int(main.endings.counts.get("rasytuppi", 0)) == 2, "Tuppi: toinen voitto laskettiin hiljaa")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(30)
	Settings.set_v("k18_pois", k18)


## Lettukisa loppusekunneilla pelaajan johdossa (lettu_game.gd "kisa").
func _lettu_win(g: CanvasLayer) -> void:
	g._phase = "kisa"
	g._t = 0.0
	g._story = ""
	g._eaters[0].bites = 34
	g._eaters[1].bites = 22
	g._eaters[2].bites = 19
	g._left = 0.05
	g.auto = true


func _lettu(path: String) -> void:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("lettukunkku")
	await _frames(10)
	var s: Dictionary = main.kolmio.st("saloinen")
	s.done_day = maxi(0, main.day - 1)
	s.illat = 2
	main._kolmio_kiva("saloinen", "lettu")
	await _frames(20)
	var g: CanvasLayer = main._rasva_game
	_check(g != null and g.legend and not g.recall, "Lettu: ensimmäinen ilta, legenda odottaa")
	_lettu_win(g)
	var shots := [["lasku", "lasku", 0.4], ["lautanen", "lasku", 2.3], ["kruunu", "kruunu", 1.0], ["kruunattu", "kruunu", 2.6],
		["vatkain", "vatkain", 1.0], ["nuolaisu", "vatkain", 3.15], ["viikset", "vatkain", 4.0], ["kommentti", "vatkain", 5.4],
		["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if await _tuppi_wait(g, st[1], st[2]):
			await _shot(path, st[0])
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
	for i in 3000:
		if main._kolmio_ui != null:
			break
		await _frames(1)
	await _frames(30)
	print("LEGENDA lettu aamu: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("lettukunkku", 0)), main._msg.text])
	_check(int(main.endings.counts.get("lettukunkku", 0)) == 1, "Lettu: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Lettu: päiväkirjarivi")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(60)
	# Toinen ilta: kaveri muistelee, voitto ilman huipennusta.
	main.kolmio.st("saloinen").done_day = maxi(0, main.day - 1)
	main._kolmio_kiva("saloinen", "lettu")
	await _frames(20)
	g = main._rasva_game
	_check(g != null and not g.legend and g.recall, "Lettu: toinen ilta ilman legendaa")
	var muisto := false
	if g != null:
		for b: String in g._bubbles:
			if b.contains("vatkai") or b.contains("kunkku"):
				muisto = true
	_check(muisto, "Lettu: kaveri muistelee vatkainta")
	await _shot(path, "muisto")
	_lettu_win(g)
	var seen := false
	while is_instance_valid(g) and main._rasva_game == g:
		if g._phase in g.LEG:
			seen = true
		await _frames(1)
	await _frames(30)
	_check(not seen, "Lettu: toisella voitolla ei huipennusta")
	_check(int(main.endings.counts.get("lettukunkku", 0)) == 2, "Lettu: toinen voitto laskettiin hiljaa")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(30)
	Settings.set_v("k18_pois", k18)


## Löylykisa: kaverit pakenevat heti, pelaaja jää viimeiseksi (loyly_game.gd _race -> _end).
func _loyly_win(g: CanvasLayer) -> void:
	g._phase = "kisa"
	g._t = 0.0
	g._story = ""
	g._heat = 6
	g.auto = true
	g._flee(1)
	g._flee(2)


func _loyly(path: String) -> void:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("loylykunkku")
	await _frames(10)
	var s: Dictionary = main.kolmio.st("saloinen")
	s.done_day = maxi(0, main.day - 1)
	s.illat = 2
	main._kolmio_kiva("saloinen", "loyly")
	await _frames(20)
	var g: CanvasLayer = main._rasva_game
	_check(g != null and g.legend and not g.recall, "Löyly: ensimmäinen ilta, legenda odottaa")
	_loyly_win(g)
	var shots := [["kauha", "kauha", 0.6], ["pilvi", "kauha", 2.7], ["kunkku", "kauha", 4.2], ["ovi", "ovi", 1.3],
		["ovi2", "ovi", 3.4], ["nousu", "pyyhe", 1.4], ["putoaa", "pyyhe", 2.72], ["kasa", "pyyhe", 3.4],
		["reaktio", "pyyhe", 4.6], ["ego", "pyyhe", 6.6], ["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if await _tuppi_wait(g, st[1], st[2]):
			await _shot(path, st[0])
			if st[0] == "ego":  # siveä rajaus: kunkun lantio kuvan alareunan alapuolella
				var c: Node3D = g._chars[0]
				var q: Vector2 = g._cam.unproject_position(c.to_global(c.bone_position("pelvis")) + Vector3(0, 0.12, 0))
				var vs: Vector2 = main.get_viewport().get_visible_rect().size
				print("LEGENDA löyly lantio ruudulla y %.0f / %.0f" % [q.y, vs.y])
				_check(q.y > vs.y, "Löyly: lantio rajattu pois kaksoiskuvasta")
			if st[0] == "kasa":
				var c2: Node3D = g._chars[0]
				var k: Vector2 = g._cam.unproject_position(c2.to_global(c2.bone_position("pelvis")))
				print("LEGENDA löyly jalkakuva lantio y %.0f" % k.y)
				_check(k.y < 0.0, "Löyly: jalkakuvassa lantio kuvan yläpuolella")
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
	for i in 3000:
		if main._kolmio_ui != null:
			break
		await _frames(1)
	await _frames(30)
	print("LEGENDA löyly aamu: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("loylykunkku", 0)), main._msg.text])
	_check(int(main.endings.counts.get("loylykunkku", 0)) == 1, "Löyly: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Löyly: päiväkirjarivi")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(60)
	# Toinen ilta: joku muistelee, voitto ilman huipennusta.
	main.kolmio.st("saloinen").done_day = maxi(0, main.day - 1)
	main._kolmio_kiva("saloinen", "loyly")
	await _frames(20)
	g = main._rasva_game
	_check(g != null and not g.legend and g.recall, "Löyly: toinen ilta ilman legendaa")
	var muisto := false
	if g != null:
		for b: String in g._bubbles:
			if b.contains("pyyhe") or b.contains("kunkku"):
				muisto = true
	_check(muisto, "Löyly: joku muistelee pyyhettä")
	await _shot(path, "muisto")
	_loyly_win(g)
	var seen := false
	while is_instance_valid(g) and main._rasva_game == g:
		if g._phase in g.LEG:
			seen = true
		await _frames(1)
	await _frames(30)
	_check(not seen, "Löyly: toisella voitolla ei huipennusta")
	_check(int(main.endings.counts.get("loylykunkku", 0)) == 2, "Löyly: toinen voitto laskettiin hiljaa")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(30)
	Settings.set_v("k18_pois", k18)


## Sivikki-disko: kaikki liikkeet osutuiksi ja pelaajalle ylivoimaiset pisteet (disko_game.gd _dance -> _end).
func _disko_win(g: CanvasLayer) -> void:
	g._phase = "kisa"
	g._t = 0.0
	g._story = ""
	g.auto = true
	for n: Dictionary in g._notes:
		n.hit = true
	g._score = [9600, 3100, 3400]


func _disko(path: String) -> void:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	const Contact := preload("res://scripts/contact.gd")
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("sivikkidisko")
	if main.player != main.walker_out:
		main._toggle_mount()
	main.mokki.ensure_built()
	main._start_mopo()
	await _frames(30)
	var s: Dictionary = main.kolmio.st("vaala")
	s.done_day = maxi(0, main.day - 1)
	s.illat = 2
	main._kolmio_kiva("vaala", "disko")
	await _frames(20)
	var g: CanvasLayer = main._rasva_game
	_check(g != null and g.legend and not g.recall, "Disko: ensimmäinen ilta, legenda odottaa")
	if g == null:
		Settings.set_v("k18_pois", k18)
		return
	await _frames(30)
	_disko_win(g)
	var shots := [["droppi", "droppi", 0.6], ["drop", "droppi", 2.4], ["pari", "pari", 1.6], ["ote", "pari", 4.0],
		["himmenee", "sammuu", 0.9], ["timo", "sammuu", 4.4], ["laulu", "laulu", 1.2], ["kuoro", "laulu", 5.6],
		["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if await _tuppi_wait(g, st[1], st[2]):
			await _shot(path, st[0])
			if st[0] == "ote" and not g._prof.is_empty():  # tanssiote: vartalot eivät mene toistensa sisään
				var deep := 0.0
				var what := ""
				for o: Array in Contact.overlap_pairs(g._chars[0], g._prof[0], g._chars[3], g._prof[3], 0.0):
					if float(o[2]) > deep:
						deep = float(o[2])
						what = "%s-%s" % [o[0], o[1]]
				print("LEGENDA disko ote syvin päällekkäisyys %.3f m (%s)" % [deep, what])
				_check(deep < 0.025, "Disko: tanssiotteessa ei läpimenoa")
				var hl: Vector3 = g._chars[0].to_global(g._chars[0].bone_position("hand_l"))
				var kw: Vector3 = g._chars[3].to_global(g._chars[3].bone_position("spine_01"))
				print("LEGENDA disko pelaajan käsi Katjan vyötäröltä %.2f m" % hl.distance_to(kw))
				_check(hl.distance_to(kw) < 0.3, "Disko: pelaajan käsi Katjan vyötäröllä")
			if st[0] == "timo":
				_check(not g._music.playing and g._lit == 0.0, "Disko: akku loppui, musiikki ja valot pois")
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
			_check(false, "Disko: vaihe %s/%s" % [st[1], st[0]])
	for i in 3000:
		if main._kolmio_ui != null:
			break
		await _frames(1)
	await _frames(30)
	print("LEGENDA disko aamu: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("sivikkidisko", 0)), main._msg.text])
	_check(int(main.endings.counts.get("sivikkidisko", 0)) == 1, "Disko: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Disko: päiväkirjarivi")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(60)
	# Toinen ilta: joku muistelee akkua, voitto ilman huipennusta.
	main.kolmio.st("vaala").done_day = maxi(0, main.day - 1)
	main._kolmio_kiva("vaala", "disko")
	await _frames(20)
	g = main._rasva_game
	_check(g != null and not g.legend and g.recall, "Disko: toinen ilta ilman legendaa")
	var muisto := false
	if g != null:
		for b: String in g._bubbles:
			if b.contains("akku"):
				muisto = true
	_check(muisto, "Disko: joku muistelee akkua")
	await _shot(path, "muisto")
	if g != null:
		_disko_win(g)
		var seen := false
		while is_instance_valid(g) and main._rasva_game == g:
			if g._phase in g.LEG:
				seen = true
			await _frames(1)
		await _frames(30)
		_check(not seen, "Disko: toisella voitolla ei huipennusta")
	_check(int(main.endings.counts.get("sivikkidisko", 0)) == 2, "Disko: toinen voitto laskettiin hiljaa")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(30)
	Settings.set_v("k18_pois", k18)


## Karaoke: laulamatta suoraan loppuun pelaajan voittona (ilta_karaoke.gd _end).
func _karaoke_win(g: CanvasLayer) -> void:
	if g._kg != null:
		g._kg.queue_free()
		g._kg = null
	g.auto = true
	g._scores = [0.94, 0.61, 0.72]
	g._turn = g._turns.size()
	g._end()


func _karaoke(path: String) -> void:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	main.kolmio = Kolmio.new()
	main.endings.counts.erase("karaokekunkku")
	await _frames(10)
	var s: Dictionary = main.kolmio.st("saloinen")
	s.done_day = maxi(0, main.day - 1)
	s.illat = 3
	main._kolmio_kiva("saloinen", "karaoke")
	await _frames(20)
	var g: CanvasLayer = main._rasva_game
	_check(g != null and g.legend and not g.recall, "Karaoke: ensimmäinen ilta, legenda odottaa")
	_karaoke_win(g)
	_check(g._phase == "kerto", "Karaoke: voitto aloitti kertosäkeen")
	var shots := [["kerto", "kerto", 1.4], ["kerto2", "kerto", 3.6], ["ikkuna", "naapuri", 0.9], ["kop", "naapuri", 1.5],
		["huuto", "naapuri", 3.0], ["jahmo", "naapuri", 5.6], ["finaali", "finaali", 1.2], ["pito", "finaali", 3.9],
		["laskuri", "ennatys", 1.2], ["ennatys", "ennatys", 2.2], ["porukka", "ennatys", 3.4], ["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if await _tuppi_wait(g, st[1], st[2]):
			await _shot(path, st[0])
			if st[0] == "kerto":  # nainen seisoo jakkaralla: jalkapohjat kannen tasolla ja kannen sisällä
				var w: Node3D = g._leg_chars[3]
				var stool: Vector3 = g.CENTER + g.AUDIENCE[1]
				for b in ["foot_l", "foot_r"]:
					var fp: Vector3 = g._hall.to_local(w.to_global(w.bone_position(b)))
					var d := Vector2(fp.x - stool.x, fp.z - stool.z).length()
					print("LEGENDA karaoke nainen %s: korkeus %.3f (kansi %.3f), etäisyys keskeltä %.3f" % [b, fp.y, g.STOOL_H, d])
					_check(fp.y > g.STOOL_H - 0.01 and d < 0.19, "Karaoke: %s jakkaran kannella" % b)
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
	for i in 3000:
		if main._kolmio_ui != null:
			break
		await _frames(1)
	await _frames(30)
	print("LEGENDA karaoke aamu: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("karaokekunkku", 0)), main._msg.text])
	_check(int(main.endings.counts.get("karaokekunkku", 0)) == 1, "Karaoke: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Karaoke: päiväkirjarivi")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(60)
	# Toinen ilta: joku muistelee naapuria, voitto ilman huipennusta.
	main.kolmio.st("saloinen").done_day = maxi(0, main.day - 1)
	main._kolmio_kiva("saloinen", "karaoke")
	await _frames(20)
	g = main._rasva_game
	_check(g != null and not g.legend and g.recall, "Karaoke: toinen ilta ilman legendaa")
	var muisto := false
	if g != null:
		for b: String in g._bubbles:
			if b.contains("naapuri") or b.contains("Raimo"):
				muisto = true
	_check(muisto, "Karaoke: joku muistelee naapuria")
	await _shot(path, "muisto")
	_karaoke_win(g)
	var seen := false
	while is_instance_valid(g) and main._rasva_game == g:
		if g._phase in g.LEG:
			seen = true
		await _frames(1)
	await _frames(30)
	_check(not seen, "Karaoke: toisella voitolla ei huipennusta")
	_check(int(main.endings.counts.get("karaokekunkku", 0)) == 2, "Karaoke: toinen voitto laskettiin hiljaa")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(30)
	Settings.set_v("k18_pois", k18)


## Kesäheilan ovi: kolme mittausta kotiin ja koputus (_kolmio_knock), kuten kolmiomittaus_koti mutta suoraan.
func _kesa_ovi() -> CanvasLayer:
	const Kolmio := preload("res://scripts/kolmiomittaus.gd")
	main.kolmio = Kolmio.new()
	var t: Vector2 = main._kolmio_target("koti")
	main.kolmio.start("koti", main._kolmio_start_point("koti"), t, "Joni")
	main.kolmio.measure("koti", t + Vector2(260, -140), t, "Esa")
	main.kolmio.measure("koti", t + Vector2(-70, 55), t, "Sinä")
	main._kolmio_knock("koti", -1)
	await _frames(10)
	return main._kolmio_ui


func _kesa_wait(ui: CanvasLayer, line: int, sec: float) -> bool:
	for i in 20000:
		if not is_instance_valid(ui):
			return false
		if (line < 0 and ui._title_t >= sec) or (line >= 0 and ui._title_t < 0.0 and ui._line == line and ui._line_t >= sec):
			return true
		await _frames(1)
	return false


func _kesaheila(path: String) -> void:
	var k18: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	for e in ["kesaheila", "kulissit", "avoin_pelikortti"]:
		main.endings.counts.erase(e)
	var p: Object = main.rikos_osa("paivi")
	if p != null:
		p.liput.clear()
		p.poissa_asti = -1
		p.epaluulo = 65.0
	await _frames(10)
	var ui := await _kesa_ovi()
	_check(ui != null and ui.site == "koti" and ui.legend and not ui.recall, "Kesäheila: ensimmäinen ovi lavastetaan")
	if ui == null:
		return
	print("LEGENDA kesäheila ympyrät %s" % [ui.rings.map(func(r: Dictionary) -> String: return "%s %.0f m" % [r.who, r.m])])
	var shots := [["kartta", 0, 2.4], ["neula", 1, 2.2], ["kop", 2, 0.5], ["ovi", 3, 2.4], ["sinikka", 4, 2.0], ["muisto", 5, 3.0],
		["kaverit", 6, 1.6], ["kerma", 8, 1.6], ["otsikko", -1, 3.0]]
	for st: Array in shots:
		if await _kesa_wait(ui, st[1], st[2]):
			await _shot(path, st[0])
			if st[0] == "ovi":
				_check(ui._hat != null and is_instance_valid(ui._hat), "Kesäheila: Päivillä lavakuvan hattu")
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
	for i in 2000:
		if not is_instance_valid(ui):
			break
		await _frames(1)
	await _frames(10)
	var ids: Array = main._talk_options().map(func(x: Dictionary) -> String: return x.id)
	print("LEGENDA kesäheila valinnat %s, kerrat %d" % [ids, int(main.endings.counts.get("kesaheila", 0))])
	_check("paivi_kesa_nauraa" in ids and int(main.endings.counts.get("kesaheila", 0)) == 0, "Kesäheila: otsikon jälkeen valinta, ei vielä kirjattu")
	main._talk_choose("paivi_kesa_nauraa")
	await _frames(10)
	main._talk_choose("paivi_kesa_jatka")
	await _frames(20)
	print("LEGENDA kesäheila nauraa: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("kesaheila", 0)), main._msg.text])
	_check(int(main.endings.counts.get("kesaheila", 0)) == 1, "Kesäheila: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Kesäheila: päiväkirjarivi")
	if main._kolmio_ui != null:
		main._kolmio_ui._finish()
	await _frames(60)
	# Toinen kerta: tavallinen ovi, Päivi muistelee ja hattu naulassa; tunnustaa lasketaan hiljaa.
	if p != null:
		p.liput.clear()
		p.poissa_asti = -1
	ui = await _kesa_ovi()
	_check(ui != null and not ui.legend and ui.recall, "Kesäheila: toinen kerta ilman legendaa")
	if ui == null:
		return
	ui.auto = false
	var muisto := false
	for l: Array in ui.lines:
		if String(l[1]).contains("naulassa"):
			muisto = true
	_check(muisto, "Kesäheila: Päivi muistelee hattua")
	ui._line = 2
	ui._door = 1.0
	ui._door_to = 1.0
	ui._line_t = 3.0
	await _frames(30)
	await _shot(path, "toinen")
	ui._finish()
	await _frames(10)
	main._talk_choose("paivi_kesa_tunnustaa")
	await _frames(20)
	_check(int(main.endings.counts.get("kesaheila", 0)) == 2, "Kesäheila: toinen kerta laskettiin hiljaa")
	main._talk_box.close()
	await _frames(10)
	Settings.set_v("k18_pois", k18)


## Lava: hyvä humppa pakotetaan (osumat), kappale loppuun (lava_game.gd _dance, _t >= SONG).
func _lava_dance(lg: Node3D) -> void:
	lg._start_dance("humppa")
	await _frames(10)
	lg._hits = 200
	lg._misses = 0
	lg._t = lg.SONG


func _lava_wait(lg: Node3D, phase: String, sec: float) -> bool:
	for i in 6000:
		if not is_instance_valid(lg):
			return false
		if lg._phase == phase and lg._leg_t >= sec:
			return true
		if lg._phase == "result" or (phase in lg.LEG and lg.LEG.find(lg._phase) > lg.LEG.find(phase)):
			return false
		await _frames(1)
	return false


func _lava(path: String) -> void:
	main.endings.counts.erase("lavatanssit")
	if main.player != main.walker_out:
		main._toggle_mount()
	main._start_mopo()
	await _frames(30)
	main._enter_lava(true)
	await _frames(40)
	var lg: Node3D = main._lava_game
	_check(lg != null and lg.legend and not lg.recall, "Lava: ensimmäinen käynti, legenda odottaa")
	if lg == null:
		return
	await _lava_dance(lg)
	var shots := [["laulaja", "kutsu", 1.6], ["olka", "kutsu", 4.2], ["kavely", "piiri", 1.0], ["piiri", "piiri", 4.4],
		["potku1", "potku", 0.9], ["potku3", "potku", 2.95], ["ukko", "potku", 4.4], ["mummo", "potku", 6.8], ["otsikko", "otsikko", 3.0],
		["otsikko2", "otsikko", 5.6]]
	for st: Array in shots:
		if await _lava_wait(lg, st[1], st[2]):
			await _shot(path, st[0])
			if st[0] == "olka":
				var vs: Vector2 = main.get_viewport().get_visible_rect().size
				var top: Vector2 = lg._cam.unproject_position(lg._me.to_global(lg._me.bone_position("Head")) + Vector3(0, 0.15, 0))
				var bot: Vector2 = lg._cam.unproject_position(lg._me.global_position)
				var sx := -1.0
				if lg._leg_singer != null:
					sx = lg._cam.unproject_position(lg._leg_singer.to_global(lg._leg_singer.bone_position("Head"))).x
				print("LEGENDA lava olka: pari %.0f px korkea, laulajan pää x %.0f / %.0f" % [bot.y - top.y, sx, vs.x])
				_check(bot.y - top.y >= 150.0 and sx > 0.0 and sx < vs.x * 0.3, "Lava: olan yli -kuvassa laulaja reunassa ja pari iso")
			if st[0] == "piiri":
				var n := 0
				for c: Node3D in lg._leg_ring:
					var hl: Vector3 = c.to_global(c.bone_position("hand_l"))
					var hr: Vector3 = c.to_global(c.bone_position("hand_r"))
					if hl.distance_to(hr) < 0.32:
						n += 1
				print("LEGENDA lava piirissä %d, kädet yhdessä %d" % [lg._leg_ring.size(), n])
				_check(lg._leg_walk.is_empty() and lg._leg_ring.size() >= 16 and n >= lg._leg_ring.size() - 2, "Lava: piiri taputtaa")
			if st[0] == "potku3":
				for c: Node3D in [lg._me, lg._partner]:
					var hip: Vector3 = c.to_global(c.bone_position("thigh_r"))
					var foot: Vector3 = c.to_global(c.bone_position("foot_r"))
					var stand: Vector3 = c.to_global(c.bone_position("foot_l"))
					print("LEGENDA lava potku: lonkka %.2f, jalka %.2f, tukijalka %.2f (lattia %.2f)" % [hip.y, foot.y, stand.y, lg.global_position.y])
					_check(foot.y > hip.y - 0.55 and stand.y - lg.global_position.y < 0.2, "Lava: jalka nousee, tukijalka lattialla")
		else:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
			_check(false, "Lava: vaihe %s/%s" % [st[1], st[0]])
	for i in 600:
		if lg._phase == "result":
			break
		await _frames(1)
	_check(lg._phase == "result", "Lava: legendan jälkeen tulos")
	lg._leave()
	await _frames(20)
	print("LEGENDA lava ulos: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("lavatanssit", 0)), main._msg.text])
	_check(int(main.endings.counts.get("lavatanssit", 0)) == 1, "Lava: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Lava: päiväkirjarivi")
	await _frames(60)
	# Toinen käynti: pari muistelee, hyvä humppa ilman huipennusta.
	main._enter_lava(true)
	await _frames(40)
	lg = main._lava_game
	_check(lg != null and not lg.legend and lg.recall, "Lava: toinen käynti ilman legendaa")
	if lg == null:
		return
	var muisto := false
	for c: Node3D in lg._leg_bub:
		if String(lg._leg_bub[c]).contains("jalka") or String(lg._leg_bub[c]).contains("piirin"):
			muisto = true
	_check(muisto, "Lava: pari muistelee")
	await _shot(path, "muisto")
	await _lava_dance(lg)
	var seen := false
	for i in 120:
		if lg._phase in lg.LEG:
			seen = true
		await _frames(1)
	_check(not seen and lg._phase == "result", "Lava: toisella hyvällä humpalla ei huipennusta")
	lg._leave()
	await _frames(20)
	_check(int(main.endings.counts.get("lavatanssit", 0)) == 2, "Lava: toinen kerta laskettiin hiljaa")


func _baari_sing(score: float, raahe: bool) -> void:
	main.money = 50.0
	if raahe:
		main._on_raahe_acted("karaoke")
	else:
		main._on_siitari_acted("karaoke")
	await _frames(5)
	var kg: CanvasLayer = main._karaoke_game()
	if kg == null:
		_check(false, "Baari: karaoke aukesi")
		return
	kg.finished.emit(score)
	await _frames(3)


func _baari_wait(phase: String, sec: float) -> bool:
	var g: CanvasLayer = main._karaoke_leg
	for i in 2000:
		if not is_instance_valid(g):
			return false
		if g.phase == phase and g._t >= sec:
			return true
		await _frames(1)
	return false


func _baari_scene(path: String, prefix: String, measure: bool) -> void:
	var g: CanvasLayer = main._karaoke_leg
	_check(g != null, "Baari %s: legenda alkoi" % prefix)
	if g == null:
		return
	var shots := [["savel", "savel", 1.0], ["savel2", "savel", 3.0], ["hiljaisuus", "hiljaisuus", 1.4], ["aplodit", "aplodit", 1.6],
		["aplodit2", "aplodit", 3.4], ["kello", "kello", 0.75], ["liuku", "tuoppi", 1.0], ["kiinni", "tuoppi", 2.3],
		["nosto", "tuoppi", 3.25], ["otsikko", "otsikko", 2.2], ["otsikko2", "otsikko", 5.0]]
	for st: Array in shots:
		if not await _baari_wait(st[1], st[2]):
			_check(false, "Baari %s: vaihe %s" % [prefix, st[0]])
			continue
		await _shot(path, prefix + st[0])
		if not measure:
			continue
		match st[0]:
			"savel2":
				var hd: Vector3 = g._player.to_global(g._player.bone_position("Head"))
				print("LEGENDA baari sävel: walker %s, pää %s -> ruudulla %s, kamera %s" % [g._walker.position, g.interior.to_local(hd),
					g._cam.unproject_position(hd), g.interior.to_local(g._cam.global_position)])
				var h: Vector3 = g._player.to_global(g._player.bone_position("hand_r"))
				var mic: Vector3 = g.interior.to_global(g.cast.mic)
				print("LEGENDA baari mikki: käsi %.3f m telineestä" % h.distance_to(mic))
				_check(h.distance_to(mic) < 0.12, "Baari: käsi mikkitelineessä")
			"aplodit":
				var n := 0
				for a: Array in g._aud:
					var c: Node3D = a[0]
					if c.to_global(c.bone_position("hand_l")).distance_to(c.to_global(c.bone_position("hand_r"))) < 0.32:
						n += 1
				print("LEGENDA baari aplodit: %d / %d taputtaa" % [n, g._aud.size()])
				_check(n == g._aud.size(), "Baari: koko sali taputtaa")
			"kello":
				var bt: Node3D = g.cast.bartender
				var bh: Vector3 = bt.to_global(bt.bone_position("hand_r"))
				var cord: Vector3 = g._bell.to_global(Vector3(0, 0.19, 0))
				print("LEGENDA baari kello: käsi %s, naru %s, ero %.3f" % [g.interior.to_local(bh), g.interior.to_local(cord), bh.distance_to(cord)])
				_check(bh.distance_to(cord) < 0.1, "Baari: baarimikon käsi kellon narussa")
			"aplodit2":
				var hd: Vector3 = g._player.to_global(g._player.bone_position("Head"))
				var pv: Vector3 = g._player.to_global(g._player.bone_position("pelvis"))
				var fw: Vector3 = g.interior.global_basis * (g.cast.face as Vector3)
				print("LEGENDA baari kumarrus: pää %.2f m lantion edessä" % (hd - pv).dot(fw))
				_check((hd - pv).dot(fw) > 0.15, "Baari: pelaaja kumartaa")
			"kiinni":
				var h: Vector3 = g._player.to_global(g._player.bone_position("hand_r"))
				var hw: Vector3 = g._pint.to_global(g._pint.get_meta("handle"))
				print("LEGENDA baari tuoppi: käsi %.3f m korvasta" % h.distance_to(hw))
				_check(h.distance_to(hw) < 0.12, "Baari: käsi tuopin korvassa")
	for i in 900:
		if not is_instance_valid(g):
			break
		await _frames(1)
	await _frames(5)


func _baari_enter_siitari() -> void:
	main._start_mopo()
	var mp: CharacterBody3D = main.mopo_trip.mopo
	mp.position = main.mopo_trip.vaala.siitari_park + Vector3(0, 0.5, 0)
	for i in 10:
		await main.get_tree().physics_frame
	main.mopo_trip.stop()
	main._on_mopo_arrived()
	main._note.visible = false
	await _frames(10)
	main.siitari_int.walker.position = main.siitari_int.spots.karaoke[0]


func _baari(path: String) -> void:
	main.endings.counts.erase("karaoke")
	for k in ["karaoke_taulu_siitari", "karaoke_taulu_raahe"]:
		main.tilat.firsts.erase(k)
	# Kapteenin Kellari ensin (Saloisista taksilla): sama kohtaus Raahessa.
	main._enter_raahe()
	await _frames(20)
	main.raahe_int.walker.position = main.raahe_int.spots.karaoke[0]
	await _frames(5)
	await _baari_sing(0.96, true)
	await _baari_scene(path, "raahe_", true)
	var rb: Node3D = main.raahe_int._board
	_check(rb != null and rb.visible and "karaoke_taulu_raahe" in main.tilat.firsts, "Baari: Kellarin taulu seinällä")
	_check(main.raahe_int._singer.current().begins_with("Sitting"), "Baari: vakiolaulaja istuu taas")
	main.raahe_int.leave()
	main.state = "ulkona"
	await _frames(10)
	# Siitari.
	main.endings.counts.erase("karaoke")
	await _baari_enter_siitari()
	_check(main.state == "in_siitari", "Baari: Siitarissa")
	await _baari_sing(0.96, false)
	await _baari_scene(path, "", true)
	print("LEGENDA baari: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("karaoke", 0)), main._msg.text])
	_check(int(main.endings.counts.get("karaoke", 0)) == 1, "Baari: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Baari: päiväkirjarivi")
	_check("karaoke_taulu_siitari" in main.tilat.firsts, "Baari: taulu muistetaan")
	var b: Node3D = main.siitari_int._board
	_check(b != null and b.visible, "Baari: taulu seinällä")
	var seated := true
	for c: Node3D in main.siitari_int._seurue + main.siitari_int._cardplayers:
		if not c.current().begins_with("Sitting"):
			seated = false
	_check(seated and main.siitari_int.walker.controls_enabled, "Baari: sali istuu taas, pelaaja liikkuu")
	await _shot(path, "jalkeen")
	# Toinen käynti: baarimikko muistelee, raikuva veto ilman kohtausta.
	main._on_siitari("lahde")
	await _frames(20)
	await _baari_enter_siitari()
	var bt_text: String = main.siitari_int._bubbles[main.siitari_int._bartender].text
	print("LEGENDA baari muisto: '%s'" % bt_text)
	_check(bt_text.to_lower().contains("taulu") or bt_text.to_lower().contains("kuningas"), "Baari: baarimikko muistelee")
	main.siitari_int.walker.position = Vector3(-5.2, 0, -1.6)
	main.siitari_int.walker.rotation.y = B_yaw(Vector3(-1, 0, -1.1))
	await _frames(20)
	await _shot(path, "muisto")
	await _baari_sing(0.96, false)
	_check(main._karaoke_leg == null, "Baari: toisella kerralla ei kohtausta")
	await _frames(10)
	_check(int(main.endings.counts.get("karaoke", 0)) == 2, "Baari: toinen kerta laskettiin hiljaa")


## Kiihdytys alkaa Zabukin pihassa: mopopoikien valikosta pieni kisa (Tunturi-Jani).
func _kiih_start() -> Node3D:
	var vl: Node3D = main.mopo_trip.vaala
	main.money = 60.0
	main.walker_out.global_position = main.mopo_trip.to_global(vl.race_spot + Vector3(0, 0.5, 0)
		+ vl.doors.filter(func(d): return d.id == "kiihdytys")[0].out * 3.0)
	await _frames(15)
	main._on_vaala_door("kiihdytys")
	await _frames(5)
	main._talk_choose("kisa")
	await _frames(30)
	return main._race


## Kisan tulos pakotetaan pelaajan voitoksi: molemmat maalissa, pelaaja ensin (mopo_race.gd _process "race").
func _kiih_win(rc: Node3D) -> void:
	rc._green_at = maxf(rc._t - 9.84, 0.001)
	rc._me.go = true
	rc._opp.go = true
	rc._me.s = rc.DIST + 1.0
	rc._opp.s = rc.DIST + 0.4
	rc._me.time = 9.84
	rc._opp.time = 10.06
	rc._phase = "race"


func _kiih_legend(rc: Node3D) -> CanvasLayer:
	for i in 300:
		if not is_instance_valid(rc):
			return null
		for c in rc.get_children():
			if c is CanvasLayer and "phase" in c and "race" in c:
				return c
		await _frames(1)
	return null


func _kiih_wait(lg: CanvasLayer, phase: String, sec: float) -> bool:
	for i in 6000:
		if not is_instance_valid(lg) or lg.phase == "":
			return false
		if lg.phase == phase and lg._t >= sec:
			return true
		if lg.ORDER.find(lg.phase) > lg.ORDER.find(phase):
			return false
		await _frames(1)
	return false


func _kiihdytys(path: String) -> void:
	main.endings.counts.erase("kiihdytys")
	main.tilat.firsts.erase("kiihdytys_muisto")
	if main.player != main.walker_out:
		main._toggle_mount()
	main._start_mopo()
	await _frames(30)
	main._mopo_dismount()
	await _frames(10)
	var rc: Node3D = await _kiih_start()
	_check(rc != null and rc.legend, "Kiihdytys: ensimmäinen kisa, legenda odottaa")
	if rc == null:
		return
	_kiih_win(rc)
	var lg: CanvasLayer = await _kiih_legend(rc)
	_check(lg != null, "Kiihdytys: voitosta alkoi lavastettu kohtaus")
	if lg == null:
		return
	var shots := [["lahestyy", "maali", 0.9], ["viiva", "maali", -1.0], ["perassa", "maali", 3.3], ["ilme", "ilme", 1.0],
		["ilme2", "ilme", 2.9], ["keulinta", "keulinta", 1.2], ["hurraus", "keulinta", 2.8], ["tyonto", "tyonto", 1.4],
		["tyonto2", "tyonto", 3.4], ["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		var ok := false
		if st[0] == "viiva":
			for i in 3000:
				if not is_instance_valid(lg) or lg.phase != "maali":
					break
				if lg._cross_t >= 0.0 and lg._t >= lg._cross_t + 0.25:
					ok = true
					break
				await _frames(1)
		else:
			ok = await _kiih_wait(lg, st[1], st[2])
		if not ok:
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
			_check(false, "Kiihdytys: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		if st[0] == "viiva":
			var me: Node3D = rc._my_model
			var opp: Node3D = rc._opp_model
			var lead: float = lg._s_me - lg._s_opp
			print("LEGENDA kiihdytys viivalla: pelaaja %.2f m, vastustaja %.2f m (viiva %.0f), ero %.2f m" % [lg._s_me, lg._s_opp, rc.DIST, lead])
			_check(lead > 0.5 and me.visible and opp.visible, "Kiihdytys: pelaaja viivalla ensin")
			var hand: Vector3 = lg._bone_l(lg._flagger, "hand_r")
			print("LEGENDA kiihdytys lippu: tanko %.3f m kädestä" % hand.distance_to(lg._flag.position))
			_check(hand.distance_to(lg._flag.position) < 0.1, "Kiihdytys: lippu lipputytön kädessä")
		if st[0] == "ilme":
			var r: Node3D = lg._opp_rider
			var m: Node3D = rc._opp_model
			var worst := 0.0
			for lr in ["_l", "_r"]:
				var h: Vector3 = r.to_global(r.bone_position("hand" + lr))
				var side := signf(m.to_local(h).x)
				worst = maxf(worst, h.distance_to(m.to_global(Vector3(0.3 * side, 1.08, -0.46))))
			print("LEGENDA kiihdytys ilme: ajajan kädet kahvoista enintään %.3f m" % worst)
			_check(worst < 0.1, "Kiihdytys: ajajan kädet tangossa")
		if st[0] == "keulinta" or st[0] == "hurraus":
			var m: Node3D = rc._my_model
			var rear: Vector3 = m.position + m.transform.basis * lg.REAR
			var front: Vector3 = m.position + m.transform.basis * Vector3(0, 0.3, -0.58)
			var s: float = rc.DIST + 13.0 - lg.KEUL_V * lg._t
			var ground: float = lg._P(s, 0.3).y
			print("LEGENDA kiihdytys keulinta: takapyörä %.2f, etupyörän napa %.2f (tie %.2f)" % [rear.y, front.y, ground])
			_check(absf(rear.y - ground) < 0.08 and front.y - ground > 0.55, "Kiihdytys: keula pystyssä, takapyörä tiessä")
			var r: Node3D = lg._me_rider
			var hl: Vector3 = r.to_global(r.bone_position("hand_l"))
			var hd: Vector3 = r.to_global(r.bone_position("Head"))
			_check(hl.y > hd.y + 0.05, "Kiihdytys: nyrkki ilmassa")
			var cam: Camera3D = lg._cam
			var top: Vector2 = cam.unproject_position(hl + Vector3(0, 0.08, 0))
			var bot: Vector2 = cam.unproject_position(rc.to_global(rear))  # rear ja front kisan kehyksessä
			var fr: Vector2 = cam.unproject_position(rc.to_global(front))
			var vs: Vector2 = main.get_viewport().get_visible_rect().size
			print("LEGENDA kiihdytys keulinta kuvassa: korkeus %.0f px, keskikohta x %.0f / %.0f" % [bot.y - top.y, (fr.x + bot.x) / 2.0, vs.x])
			_check(bot.y - top.y >= 300.0 and absf((fr.x + bot.x) / 2.0 - vs.x / 2.0) < vs.x * 0.2, "Kiihdytys: keulinta iso ja keskellä")
		if st[0] == "tyonto":
			var p: Node3D = lg._pusher
			var m: Node3D = rc._opp_model
			var gl: Vector3 = m.to_global(lg.push_grips["_l"])
			var gr: Vector3 = m.to_global(lg.push_grips["_r"])
			var dl: float = p.to_global(p.bone_position("hand_l")).distance_to(gl)
			var dr: float = p.to_global(p.bone_position("hand_r")).distance_to(gr)
			print("LEGENDA kiihdytys työntö: kädet tangosta %.3f / %.3f m" % [dl, dr])
			_check(dl < 0.1 and dr < 0.1, "Kiihdytys: työntäjän kädet tangossa")
	for i in 3000:
		if main.state != "mopokisa":
			break
		await _frames(1)
	await _frames(5)
	print("LEGENDA kiihdytys jälkeen: tila %s, kerrat %d, viesti '%s'" % [main.state, int(main.endings.counts.get("kiihdytys", 0)), main._msg.text])
	_check(int(main.endings.counts.get("kiihdytys", 0)) == 1, "Kiihdytys: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Kiihdytys: päiväkirjarivi")
	await _frames(60)
	# Toinen kisa: pojat muistelevat, voitto ilman huipennusta.
	var vl: Node3D = main.mopo_trip.vaala
	main.walker_out.global_position = main.mopo_trip.to_global(vl.race_spot + Vector3(0, 0.5, 0)
		+ vl.doors.filter(func(d): return d.id == "kiihdytys")[0].out * 3.0)
	await _frames(15)
	main._on_vaala_door("kiihdytys")
	await _frames(10)
	var hello: String = main._talk_box._line
	print("LEGENDA kiihdytys toinen käynti: '%s'" % hello)
	_check(hello in main.MopoRace.LEG_MUISTO, "Kiihdytys: mopopojat muistelevat")
	await _shot(path, "muisto")
	main._talk_choose("kisa")
	await _frames(30)
	rc = main._race
	_check(rc != null and not rc.legend, "Kiihdytys: toinen kisa ilman legendaa")
	if rc == null:
		return
	_kiih_win(rc)
	var seen := false
	for i in 600:
		if main.state != "mopokisa":
			break
		if is_instance_valid(rc):
			for c in rc.get_children():
				if c is CanvasLayer and "race" in c:
					seen = true
		await _frames(1)
	_check(not seen, "Kiihdytys: toisella voitolla ei huipennusta")
	_check(int(main.endings.counts.get("kiihdytys", 0)) == 2, "Kiihdytys: toinen voitto laskettiin hiljaa")


func B_yaw(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


## Tanssit: tanssi Sinikan kanssa seuraintalon salissa, osumat pakotetaan ja biisi loppuun (tanssi_game.gd _leg_good).
func _tanssi_start() -> Node3D:
	main._start_tanssi("sinikka_seura")
	await _frames(20)
	var tgs: Array = main.kirppis_int.get_children().filter(func(c): return c is TanssiGame)
	if tgs.is_empty():
		return null
	var tg: Node3D = tgs.front()
	tg.frame_clock = true
	await _frames(30)  # kontaktiprofiilit (tanssiote) valmiiksi
	tg._hits = 200
	tg._misses = 0
	tg.seek(float(tg._song.end) - 0.1)
	return tg


func _tanssi_wait(tg: Node3D, phase: String, sec: float) -> bool:
	for i in 6000:
		if not is_instance_valid(tg) or tg._done:
			return false
		if tg._phase == phase and tg._leg_t >= sec:
			return true
		if tg._phase in tg.LEG and tg.LEG.find(tg._phase) > tg.LEG.find(phase):
			return false
		await _frames(1)
	return false


## Pisteen paikka kuvassa (0..1) tanssin kamerasta.
func _tanssi_sp(tg: Node3D, p: Vector3) -> Vector2:
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	return tg._cam.unproject_position(p) / vs


func _tanssit(path: String) -> void:
	main.endings.counts.erase("tanssit")
	if main.player == main.bike:
		main._toggle_mount()
	main.day = 6
	main.clock_min = 21 * 60 + 30
	main._enter_kirppis("tanssit")
	await _frames(30)
	var ki: Node3D = main.kirppis_int
	var tg := await _tanssi_start()
	_check(tg != null and tg.legend, "Tanssit: ensimmäinen tanssi, legenda odottaa")
	if tg == null:
		return
	var e0: float = (ki._lamps[0][0] as OmniLight3D).light_energy
	var head0 := 9.0  # parin pää seisten (valssissa)
	var shots := [["valssi", "valssi", 1.4], ["valssi2", "valssi", 4.0], ["taivutus", "taivutus", 0.6], ["taivutus2", "taivutus", 2.6],
		["valot", "valot", 1.4], ["valot2", "valot", 4.2], ["otsikko", "otsikko", 3.2]]
	for st: Array in shots:
		if not await _tanssi_wait(tg, st[1], st[2]):
			print("LEGENDA kuva %s jäi ottamatta" % st[0])
			_check(false, "Tanssit: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var me: Node3D = tg._me
		var her: Node3D = tg._her
		if st[0] == "valssi2":
			var top := _tanssi_sp(tg, me.to_global(me.bone_position("Head")) + Vector3(0, 0.15, 0))
			var bot := _tanssi_sp(tg, me.global_position)
			var e: float = (ki._lamps[0][0] as OmniLight3D).light_energy
			head0 = her.to_global(her.bone_position("Head")).y - tg.global_position.y
			print("LEGENDA tanssit valssi: pari %.0f %% kuvan korkeudesta, lamppu %.2f / %.2f, kohdevalo %.1f" % [(bot.y - top.y) * 100.0, e, e0, tg._spot.light_energy])
			_check(bot.y - top.y > 0.5 and e < e0 * 0.3 and tg._spot.light_energy > 5.0, "Tanssit: valssissa pari iso ja valot himmeinä")
			_check(ki.hold_dancers, "Tanssit: taustaparit pysähtyivät")
		if st[0] == "taivutus2":
			var head: Vector3 = her.to_global(her.bone_position("Head"))
			var hand: Vector3 = me.to_global(me.bone_position("hand_r"))
			var blade: Vector3 = tg.dip_target()
			var hl: Vector3 = tg.dip_grip()
			var hr: Vector3 = her.to_global(her.bone_position("hand_r"))
			var floor_y: float = tg.global_position.y
			var feet := 9.0
			for c: Node3D in [me, her]:
				for f in ["foot_l", "foot_r", "ball_l", "ball_r"]:
					feet = minf(feet, c.to_global(c.bone_position(f)).y - floor_y)
			var deep := 0.0
			var worst := ""
			if not tg.prof.is_empty():
				for o: Array in Contact.overlap_pairs(me, tg.prof[me], her, tg.prof[her], 0.0):
					if float(o[2]) > deep:
						deep = float(o[2])
						worst = "%s/%s" % [o[0], o[1]]
			var axg: Vector3 = tg.global_basis * tg._dip_ax
			var sho: Vector3 = me.to_global(me.bone_position("upperarm_r"))
			var reach: float = sho.distance_to(me.to_global(me.bone_position("lowerarm_r"))) + me.to_global(me.bone_position("lowerarm_r")).distance_to(hand)
			print("LEGENDA tanssit taivutus: olka selästä %.2f m, käden ulottuma %.2f m" % [sho.distance_to(blade), reach])
			var sm := _tanssi_sp(tg, me.to_global(me.bone_position("Head")))
			var sh := _tanssi_sp(tg, head)
			print("LEGENDA tanssit taivutus: parin pää %.2f m, käsi selästä %.2f m, parin käsi olalta %.2f m, matalin jalka %.3f m, syvin päällekkäisyys %.3f m (%s), päät kuvassa %s %s" % [head.y - floor_y, hand.distance_to(blade), hl.distance_to(hr), feet, deep, worst, sm, sh])
			print("LEGENDA tanssit taivutus: parin pää seisten %.2f m" % head0)
			var arch: float = (head - her.to_global(her.bone_position("pelvis"))).dot(axg)
			print("LEGENDA tanssit taivutus: parin pää lantion takana %.2f m" % arch)
			_check(head.y - floor_y < head0 - 0.1 and arch > 0.2, "Tanssit: pari taipuu taakse")
			_check(hand.distance_to(blade) < 0.12, "Tanssit: pelaajan käsi parin vyötäröllä")
			_check(hl.distance_to(hr) < 0.12, "Tanssit: parin käsi pelaajan olalla")
			_check(feet > -0.02, "Tanssit: jalat eivät mene lattian läpi")
			_check(deep < 0.03 or tg.prof.is_empty(), "Tanssit: taivutuksessa ei läpimenoa")
			_check(sm.x > 0.05 and sm.x < 0.95 and sh.x > 0.05 and sh.x < 0.95 and sm.y > 0.12 and sh.y > 0.12, "Tanssit: kumpikin näkyy taivutuksessa")
		if st[0] == "valot2":
			var on := 0
			for l: Array in ki._lamps:
				if (l[0] as OmniLight3D).light_energy > e0 * 0.9:
					on += 1
			var j: Node3D = tg._juoru
			var js := _tanssi_sp(tg, j.to_global(j.bone_position("Head"))) if j != null else Vector2(-1, -1)
			print("LEGENDA tanssit valot: lamppuja päällä %d / %d, juoruaja %s kuvassa %s, repliikki '%s'" % [on, ki._lamps.size(), j.name if j != null else "-", js, tg._leg_bub.get(j, "")])
			_check(on == ki._lamps.size(), "Tanssit: kattolamput syttyivät")
			_check(j != null and js.x > 0.05 and js.x < 0.95 and js.y > 0.12 and js.y < 0.95 and String(tg._leg_bub.get(j, "")).contains("Anna-Liisa"), "Tanssit: Anna-Liisa näkyy ja puhuu")
	for i in 900:
		if not is_instance_valid(tg) or tg._done:
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA tanssit jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("tanssit", 0)), main._msg.text])
	_check(int(main.endings.counts.get("tanssit", 0)) == 1, "Tanssit: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Tanssit: päiväkirjarivi")
	_check(not ki.hold_dancers and absf((ki._lamps[0][0] as OmniLight3D).light_energy - e0) < 0.01, "Tanssit: sali palautui (parit ja valot)")
	await _frames(30)
	# Toinen käynti: Anna-Liisa muistelee, hyvä tanssi ilman huipennusta.
	main._on_kirppis_exited()
	await _frames(20)
	main._enter_kirppis("tanssit")
	await _frames(20)
	var al: int = ki.person_index("annaliisa")
	var said: String = (ki._bubbles[ki._people[al]] as Label3D).text
	print("LEGENDA tanssit toinen käynti: Anna-Liisa '%s'" % said)
	_check(said in TanssiGame.LEG_MUISTO, "Tanssit: Anna-Liisa muistelee")
	await _shot(path, "muisto")
	tg = await _tanssi_start()
	_check(tg != null and not tg.legend, "Tanssit: toinen tanssi ilman legendaa")
	if tg == null:
		return
	var seen := false
	for i in 300:
		if not is_instance_valid(tg) or tg._done:
			break
		if tg._phase in tg.LEG:
			seen = true
		await _frames(1)
	await _frames(10)
	_check(not seen, "Tanssit: toisella hyvällä tanssilla ei huipennusta")
	_check(int(main.endings.counts.get("tanssit", 0)) == 2, "Tanssit: toinen kerta laskettiin hiljaa")


## Haaste käyntiin Reipparin pihapöydässä; palauttaa piirakka_game.gd-solmun, kun alkulaskenta on ohi.
func _piir_start() -> Node3D:
	main._talk_who = "reippari"
	main._start_piirakka()
	await _frames(5)
	var gs: Array = main.world.get_children().filter(func(c): return c is PiirakkaGame)
	if gs.is_empty():
		return null
	var g: Node3D = gs.front()
	for i in 600:
		if g._t >= 0.2:
			break
		await _frames(1)
	return g


func _piir_legend(g: Node3D) -> CanvasLayer:
	for i in 400:
		if not is_instance_valid(g):
			return null
		for c in g.get_children():
			if c is PiirakkaLegenda:
				return c
		await _frames(1)
	return null


func _piir_wait(lg: CanvasLayer, phase: String, sec: float) -> bool:
	for i in 6000:
		if not is_instance_valid(lg) or lg.phase == "":
			return false
		if lg.phase == phase and lg._t >= sec:
			return true
		if lg.ORDER.find(lg.phase) > lg.ORDER.find(phase):
			return false
		await _frames(1)
	return false


## Kehyksen piste kuvan osuutena (0..1) legendan kamerasta.
func _piir_sp(lg: CanvasLayer, p_local: Vector3) -> Vector2:
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	return lg._cam.unproject_position(lg.game.to_global(p_local)) / vs


func _piir_in(v: Vector2) -> bool:
	return v.x > 0.04 and v.x < 0.96 and v.y > 0.1 and v.y < 0.96


func _piirakka(path: String) -> void:
	main.endings.counts.erase("piirakkakuningas")
	main._piirakka_record = 7
	main._piirakka_holder = "Juntti"
	if main.player == main.bike:
		main._toggle_mount()
	main.day = 3
	main.clock_min = 12 * 60
	main.money = 40.0
	main.walker_out.global_position = main.world.reippari_window + Vector3(0, 0.3, 0)
	await _frames(15)
	var g := await _piir_start()
	_check(g != null and g.legend and not g.recall, "Piirakka: ensimmäinen haaste, legenda odottaa")
	if g == null:
		return
	g._pies = 8
	g._finish("Aika loppu! 8 piirakkaa.")
	var lg := await _piir_legend(g)
	_check(lg != null, "Piirakka: legenda alkoi ennätyksestä")
	if lg == null:
		return
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["lasku", "lasku", 0.7], ["lasku2", "lasku", 2.8], ["paperit", "paperit", 0.5 + 2 * 0.42 + 0.21],
		["paperit2", "paperit", 0.5 + 8 * 0.42 + 0.9], ["mitta", "mitta", 2.2], ["mitta2", "mitta", 3.6], ["taulu", "taulu", 1.1],
		["taulu2", "taulu", 4.8], ["royhtays", "royhtays", 0.8], ["royhtays2", "royhtays", 2.4], ["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if not await _piir_wait(lg, st[1], st[2]):
			_check(false, "Piirakka: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var me: Node3D = lg._me
		var j: Node3D = lg.people.juntti
		var hand := func(c: Node3D, lr: String) -> Vector3: return lg.game.to_local(c.to_global(c.bone_position("hand" + lr)))
		var head := func(c: Node3D) -> Vector3: return lg.game.to_local(c.to_global(c.bone_position("Head")))
		match st[0]:
			"lasku2":
				var feet := 9.0
				for f in ["foot_l", "foot_r", "ball_l", "ball_r"]:
					feet = minf(feet, me.to_global(me.bone_position(f)).y - lg.game.global_position.y)
				var knee := maxf(lg.game.to_local(me.to_global(me.bone_position("calf_l"))).y, lg.game.to_local(me.to_global(me.bone_position("calf_r"))).y)
				var hb: Vector3 = hand.call(me, "_l")
				var belly: Vector3 = lg.game.to_local(me.to_global(me.bone_position("spine_01")))
				print("LEGENDA piirakka lasku: matalin jalka %.3f, polvi %.2f (pöytä %.2f), vasen käsi vatsasta %.2f m, kuningas kuvassa %s" % [feet, knee, lg.TABLE_Y, hb.distance_to(belly), _piir_sp(lg, head.call(me))])
				_check(feet > -0.02 and knee < lg.TABLE_Y - 0.06, "Piirakka: istuva kuningas ei mene lattian eikä pöydän läpi")
				_check(_piir_in(_piir_sp(lg, head.call(me))), "Piirakka: kuningas näkyy laskussa")
			"paperit":
				var i := 2
				var hr: Vector3 = hand.call(j, "_r")
				var span := (_piir_sp(lg, lg._paper_at(0)) - _piir_sp(lg, lg._paper_at(7))).length() * vs.x
				var shp: Vector3 = lg.game.to_local(j.to_global(j.bone_position("upperarm_r")))
				var elp: Vector3 = lg.game.to_local(j.to_global(j.bone_position("lowerarm_r")))
				print("LEGENDA piirakka paperit: olka %s, kyynärpää %s, käsi %s, kohde %s, käsivarsi %.2f+%.2f" % [shp, elp, hr, lg._paper_at(i) + Vector3(0, 0.035, 0), shp.distance_to(elp), elp.distance_to(hr)])
				print("LEGENDA piirakka paperit: käsi paperista %d %.2f m, paperirivistö %.0f px, Juntti kuvassa %s" % [i, hr.distance_to(lg._paper_at(i) + Vector3(0, 0.035, 0)), span, _piir_sp(lg, head.call(j))])
				var shw: Vector3 = lg.game.to_local(j.to_global(j.bone_position("upperarm_r")))
				var ang := rad_to_deg((hr - shw).angle_to(lg._paper_at(i) + Vector3(0, 0.03, 0) - shw))
				print("LEGENDA piirakka paperit: osoitus %.1f° paperista %d" % [ang, i])
				_check(ang < 10.0, "Piirakka: Juntti osoittaa laskettavaa paperia")
				_check(span > 180.0, "Piirakka: paperit isona keskellä")
				var jy: float = _piir_sp(lg, head.call(j)).y
				_check(_piir_in(_piir_sp(lg, head.call(j))) and jy > 0.25, "Piirakka: Juntti näkyy laskiessaan (kasvot kuplan alla)")
			"mitta", "mitta2":
				if st[0] == "mitta2":
					var js := _piir_sp(lg, head.call(j))
					var rs := _piir_sp(lg, head.call(lg.people.raija))
					print("LEGENDA piirakka mitta kahden kuva: Juntti %s, Raija %s" % [js, rs])
					_check(_piir_in(js) and _piir_in(rs), "Piirakka: Juntti ja Raija näkyvät mittauksessa")
					continue
				var pa: Vector2 = _piir_sp(lg, lg.PIE_AT + Vector3(0, 0.03, -0.114))
				var pb: Vector2 = _piir_sp(lg, lg.PIE_AT + Vector3(0, 0.03, 0.114))
				var pw := (pa - pb).length() * vs.x
				var cr: float = (hand.call(j, "_r") as Vector3).distance_to(lg._tape_case.position + Vector3(0, 0.035, 0))
				var hk: float = (hand.call(j, "_l") as Vector3).distance_to(lg._hook.position + Vector3(0, 0.04, 0))
				print("LEGENDA piirakka mitta: piirakka %.0f px, kotelo kädestä %.2f m, koukku sormesta %.2f m, Juntti %s, Raija %s" % [pw, cr, hk, _piir_sp(lg, head.call(j)), _piir_sp(lg, head.call(lg.people.raija))])
				_check(pw > 200.0 and _piir_in(pa) and _piir_in(pb), "Piirakka: vertailupiirakka isona kuvassa")
				_check(cr < 0.1 and hk < 0.1, "Piirakka: kädet mitassa")
			"taulu2":
				var bw := (_piir_sp(lg, lg.BOARD + Vector3(-0.53, 0, -0.03)) - _piir_sp(lg, lg.BOARD + Vector3(0.53, 0, -0.03))).length() * vs.x
				var tip: float = (hand.call(lg.people.raija, "_r") as Vector3).distance_to(lg._note.position)
				print("LEGENDA piirakka taulu: taulu %.0f px, lappu '%s', Raijan käsi lapusta %.2f m, Juntti %s" % [bw, lg._note_lab.text, tip, _piir_sp(lg, head.call(j))])
				_check(bw > 330.0 and _piir_in(_piir_sp(lg, lg.BOARD)), "Piirakka: ennätystaulu isona")
				_check(lg._note.visible and lg._note_lab.text.length() > 6 and tip < 0.45, "Piirakka: Raija kirjoittaa lappuun")
			"royhtays2":
				var d: float = (head.call(me) as Vector3).distance_to(head.call(j))
				var nose: float = (hand.call(j, "_l") as Vector3).distance_to(head.call(j))
				var chest: float = lg.game.to_local(me.to_global(me.bone_position("spine_03"))).distance_to(lg.game.to_local(j.to_global(j.bone_position("spine_03"))))
				print("LEGENDA piirakka röyhtäys: päät %.2f m, rinnat %.2f m, Juntin käsi päästä %.2f m, pilvi %d, kuvassa %s %s" % [d, chest, nose, lg._cloud.size(), _piir_sp(lg, head.call(me)), _piir_sp(lg, head.call(j))])
				_check(chest > 0.4 and lg._cloud.size() > 5, "Piirakka: röyhtäys ilman läpimenoa")
				_check(nose < 0.2, "Piirakka: Juntti peittää nenänsä")
				_check(_piir_in(_piir_sp(lg, head.call(me))) and _piir_in(_piir_sp(lg, head.call(j))), "Piirakka: kumpikin näkyy röyhtäyksessä")
			"otsikko":
				print("LEGENDA piirakka otsikko: kuningas %s, Juntti %s, taulu %s" % [_piir_sp(lg, head.call(me)), _piir_sp(lg, head.call(j)), _piir_sp(lg, lg.BOARD)])
				_check(_piir_in(_piir_sp(lg, head.call(me))) and _piir_in(_piir_sp(lg, lg.BOARD)), "Piirakka: kuningas ja taulu otsikossa")
	for i in 900:
		if not is_instance_valid(g):
			break
		await _frames(1)
	await _frames(10)
	var board: String = (main.world.reippari_record.find_children("*", "Label3D", true, false)[0] as Label3D).text
	print("LEGENDA piirakka jälkeen: kerrat %d, viesti '%s', taulu '%s'" % [int(main.endings.counts.get("piirakkakuningas", 0)), main._msg.text, board.replace("\n", " / ")])
	_check(int(main.endings.counts.get("piirakkakuningas", 0)) == 1, "Piirakka: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Piirakka: päiväkirjarivi")
	_check(board.contains("Järvikuja 1 8"), "Piirakka: taulussa uusi nimi")
	await _frames(30)
	# Toinen haaste: muisto alussa, ennätys ilman huipennusta.
	g = await _piir_start()
	_check(g != null and not g.legend and g.recall, "Piirakka: toinen haaste ilman legendaa")
	if g == null:
		return
	var said := ""
	for k in g._bubbles:
		said += (g._bubbles[k][0] as Label3D).text
	var muisto := PiirakkaLegenda.MUISTO.map(func(m): return m[1])
	print("LEGENDA piirakka toinen haaste: muisto '%s'" % said)
	_check(said in muisto, "Piirakka: Juntti tai Raija muistelee")
	await _shot(path, "muisto")
	g._pies = 9
	g._finish("Aika loppu! 9 piirakkaa.")
	var seen := false
	for i in 400:
		if not is_instance_valid(g):
			break
		for c in g.get_children():
			if c is PiirakkaLegenda:
				seen = true
		await _frames(1)
	await _frames(10)
	print("LEGENDA piirakka toinen ennätys: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("piirakkakuningas", 0)), main._msg.text])
	_check(not seen, "Piirakka: toisella ennätyksellä ei huipennusta")
	_check(int(main.endings.counts.get("piirakkakuningas", 0)) == 2 and main._msg.text.contains("UUSI ENNÄTYS"), "Piirakka: toinen ennätys laskettiin hiljaa")
	main._piirakka_record = 7
	main._piirakka_holder = "Juntti"
	main._reippari_update()



func _sp_wait(lg: CanvasLayer, phase: String, sec: float) -> bool:
	for i in 6000:
		if not is_instance_valid(lg) or lg.phase == "":
			return false
		if lg.phase == phase and lg._t >= sec:
			return true
		if lg.ORDER.find(lg.phase) > lg.ORDER.find(phase):
			return false
		await _frames(1)
	return false


func _sp_sp(lg: CanvasLayer, p: Vector3) -> Vector2:
	return lg._cam.unproject_position(p) / main.get_viewport().get_visible_rect().size


func _sahkopyora(path: String) -> void:
	main.endings.counts.erase("sahkopyora")
	if main.player == main.bike:
		main._toggle_mount()
	main.day = 3
	main.clock_min = 13 * 60
	var eb = main.ebike
	eb.started = true
	eb.board_taken = true
	for k in eb.PARTS:
		eb.parts[k] = true
	eb.joints = {"moottori": "ruuvi", "akku": "teippi", "ohjain": "nippu", "kaasu": "ruuvi"}
	eb.loose = {}
	eb.shorted = false
	eb.battery = 0.86
	eb.supplies.sahkoteippi = 2
	main.bike.set_ebike({"joints": eb.joints, "loose": eb.loose})
	main.walker_out.global_position = main.world.garage_door + main.world.garage_out * 1.0 + Vector3(0, 0.3, 0)
	await _frames(15)
	main._store_bike(true)
	main._enter_garage()
	await _frames(15)
	var vis_before := [main.pekka.visible, main.arto.visible, main.sinikka.visible]
	main._start_ebike_game(["johdot"])
	await _frames(5)
	var gs: Array = main.get_children().filter(func(c): return c is EBikeGame)
	_check(not gs.is_empty(), "Sähköpyörä: kasaus auki")
	if gs.is_empty():
		return
	var g: CanvasLayer = gs.front()
	g.finished.emit({"johdot": "sahkoteippi"})
	g.queue_free()
	await _frames(3)
	var ls: Array = main.get_children().filter(func(c): return c is SahkopyoraLegenda)
	_check(not ls.is_empty() and main.ebike.built(), "Sähköpyörä: koeajo alkoi viimeisestä liitoksesta")
	if ls.is_empty():
		return
	var lg: CanvasLayer = ls.front()
	_check(int(main.endings.counts.get("sahkopyora", 0)) == 0, "Sähköpyörä: hetki kirjataan vasta lopuksi")
	_check(not main.pekka.visible and not main.arto.visible and not main.walker_out.visible, "Sähköpyörä: oikeat naapurit ja jalan kulkija piilossa")
	var near: Array = []
	for c in main.find_children("*", "Node3D", true, false):
		if c.has_method("bone_position") and c.is_visible_in_tree() and (c as Node3D).global_position.distance_to(main.world.garage_door) < 40.0:
			near.append("%s %.0f m" % [c.get_parent().name + "/" + c.name, (c as Node3D).global_position.distance_to(main.world.garage_door)])
	print("LEGENDA sähköpyörä hahmot lähellä: ", near)
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var bk = main.bike
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var shots := [["ovi", "ovi", 1.0], ["ovi2", "ovi", 3.6], ["kaasu", "kaasu", 1.4], ["kaasu2", "kaasu", 2.45],
		["lahto", "lahto", 0.45], ["lahto2", "lahto", 1.6], ["ajo", "ajo", 1.2], ["ajo2", "ajo", 2.6],
		["paluu", "paluu", 2.5], ["paluu2", "paluu", 4.4], ["otsikko", "otsikko", 3.0]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Sähköpyörä: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var top: Vector2 = _sp_sp(lg, bk.to_global(Vector3(0, 1.85, 0)))
		var bot: Vector2 = _sp_sp(lg, bk.to_global(Vector3(0, 0.0, 0)))
		var fw: Vector2 = _sp_sp(lg, bk.to_global(Vector3(0, 0.35, -0.9)))
		var rw: Vector2 = _sp_sp(lg, bk.to_global(Vector3(0, 0.35, 0.9)))
		var size := maxf((top - bot).length() * vs.y, (fw - rw).length() * vs.x)
		var mid := (top + bot) / 2.0
		print("LEGENDA sähköpyörä %s: pyörä kuvassa %s, koko %.0f px, Pekka %s, Arto %s, Sinikka %s" % [st[0], mid, size,
			_sp_sp(lg, head.call(lg.pekka)), _sp_sp(lg, head.call(lg.arto)), _sp_sp(lg, head.call(lg.sinikka))])
		match st[0]:
			"ovi2":
				_check(inside.call(mid) and inside.call(_sp_sp(lg, head.call(lg.pekka))) and inside.call(_sp_sp(lg, head.call(lg.arto))),
					"Sähköpyörä: pyörä ja naapurit ovella kuvassa")
			"kaasu", "kaasu2":
				var gp: Vector2 = _sp_sp(lg, bk.to_global(lg.GRIP))
				var bat: Vector2 = _sp_sp(lg, bk.to_global(Vector3(0, 0.88, 0.5)))
				var ctl: Vector2 = _sp_sp(lg, bk.to_global(lg.CTRL))
				print("LEGENDA sähköpyörä kaasu: kahva %s, akku %s, ohjain %s, kuski %s" % [gp, bat, ctl, _sp_sp(lg, head.call(bk._rider))])
				_check(inside.call(gp) and inside.call(bat) and inside.call(ctl), "Sähköpyörä: kahva, akku ja ohjain lähikuvassa")
				var rr: Node3D = bk._rider
				var palm: Vector3 = (rr.to_global(rr.bone_position("hand_r")) + rr.to_global(rr.bone_position("index_01_r"))) / 2.0
				var gd: float = palm.distance_to(bk._visual.to_global(lg.GRIP))
				print("LEGENDA sähköpyörä kaasukäsi kahvasta %.3f m (käsi %s, sormi %s, kahva %s, korjaus %s, olka %s)" % [gd, rr.bone_position("hand_r"), rr.bone_position("index_01_r"),
					rr.to_local(bk._visual.to_global(lg.GRIP)), lg._grip_off, rr.bone_position("upperarm_r")])
				_check(gd < 0.05, "Sähköpyörä: kaasukäsi kahvassa")
				if st[0] == "kaasu2":
					_check(lg._once.has("spark"), "Sähköpyörä: kipinä")
			"lahto":
				print("LEGENDA sähköpyörä keula %.2f rad" % lg.pitch)
				_check(lg.pitch > 0.25 and inside.call(mid), "Sähköpyörä: keula nousee kuvassa")
			"ajo", "ajo2":
				_check(inside.call(mid) and size > 250.0, "Sähköpyörä: ajossa pyörä isona kuvassa")
				if not lg._tape.is_empty():
					var tz: float = lg._tape[5].position.z - lg._tape[0].position.z
					var ty: float = lg._tape[5].position.y - lg._tape[0].position.y
					print("LEGENDA sähköpyörä teippi: taakse %.2f, alas %.2f" % [tz, ty])
					_check(tz > 0.25 and ty > -0.15, "Sähköpyörä: teipinpätkä liehuu taaksepäin")
				if st[0] == "ajo2":
					_check(inside.call(_sp_sp(lg, head.call(lg.sinikka))) and lg._bub.has(lg.sinikka), "Sähköpyörä: Sinikka vilkuttaa kuvassa")
			"paluu2":
				var ang := func(c: Node3D, at: Vector3) -> float:
					var sh: Vector3 = c.to_global(c.bone_position("upperarm_r"))
					var hd: Vector3 = c.to_global(c.bone_position("hand_r"))
					return rad_to_deg((hd - sh).angle_to(at - sh))
				var pa: float = ang.call(lg.pekka, bk.to_global(Vector3(0, 0.88, 0.5)))
				var aa: float = ang.call(lg.arto, bk.to_global(lg.CTRL))
				var gap := minf(lg.pekka.global_position.distance_to(bk.global_position), lg.arto.global_position.distance_to(bk.global_position))
				print("LEGENDA sähköpyörä osoitus: Pekka %.1f°, Arto %.1f°, lähin naapuri pyörästä %.2f m" % [pa, aa, gap])
				_check(pa < 15.0 and aa < 15.0, "Sähköpyörä: Pekka osoittaa akkua, Arto johtoja")
				_check(gap > 0.7, "Sähköpyörä: naapurit eivät ole pyörän sisällä")
				_check(inside.call(mid) and inside.call(_sp_sp(lg, head.call(lg.pekka))) and inside.call(_sp_sp(lg, head.call(lg.arto))),
					"Sähköpyörä: paluussa kaikki kuvassa")
			"otsikko":
				_check(inside.call(mid) and size > 160.0, "Sähköpyörä: pyöräilijä otsikossa")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA sähköpyörä jälkeen: kerrat %d, viesti '%s', tila %s, pyörällä %s" % [int(main.endings.counts.get("sahkopyora", 0)),
		main._msg.text, main.state, main.player == main.bike])
	_check(int(main.endings.counts.get("sahkopyora", 0)) == 1, "Sähköpyörä: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Sähköpyörä: päiväkirjarivi")
	_check(main.state != "in_garage" and main.player == main.bike and main.bike.visible, "Sähköpyörä: pelaaja pyörän selässä tallin edessä")
	_check([main.pekka.visible, main.arto.visible, main.sinikka.visible] == vis_before and not main.walker_out.visible,
		"Sähköpyörä: naapurit palasivat ennalleen, jalan kulkija piilossa")
	await _frames(20)
	await _shot(path, "jalkeen")
	# Muisto: Pekka tai Arto muistelee jutellessa (30 %), kokeillaan kunnes osuu.
	var said := ""
	var muisto: Array = SahkopyoraLegenda.MUISTO.pekka + SahkopyoraLegenda.MUISTO.arto
	main.story.step = "valmis" if main.story.step == "tehtavat" else main.story.step
	for who in ["pekka", "arto"]:
		main._talk_who = who
		for i in 60:
			var l: String = main._talk_chat_line()
			if l in muisto:
				said = l
				break
		if said != "":
			break
	print("LEGENDA sähköpyörä muisto: '%s'" % said)
	_check(said != "", "Sähköpyörä: naapuri muistelee koeajoa")


func _porro(path: String) -> void:
	main.endings.counts.erase("porron_kyltti")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 4
	main.clock_min = 18 * 60 + 30
	main._spawn_boys()
	main._ball_quest = "done"
	main.lemmikki.stage = "kerrottu"
	main.walker_out.global_position = main.world.lehto_pos + Vector3(0, 0.3, 0)
	await _frames(15)
	var post: Node3D = main.world.lehto_plate
	var G: Node3D = post.get_parent()
	var hs := []
	for q in [Vector3(3.6, 0, -0.6), Vector3(3.6, 0, -2.0), Vector3(2.0, 0, -2.7), Vector3(0, 0, -3.2), Vector3(-3.6, 0, -0.6), Vector3(0, 0, 3.0)]:
		var w: Vector3 = G.to_global(q)
		hs.append("%.2f" % (Terrain.h(w.x, w.z) - post.global_position.y))
	print("LEGENDA Pörrö: tolppa y %.2f, maasto - tolppa: %s" % [post.global_position.y, hs])
	main._start_muistokyltti()
	await _frames(5)
	var gs: Array = main.get_children().filter(func(c): return c is MuistokylttiGame)
	_check(not gs.is_empty(), "Pörrö: minipeli auki")
	if gs.is_empty():
		return
	gs.front()._end(true)
	for i in 60:
		if not main.get_children().filter(func(c): return c is PorroLegenda).is_empty():
			break
		await _frames(1)
	var ls: Array = main.get_children().filter(func(c): return c is PorroLegenda)
	_check(not ls.is_empty(), "Pörrö: lehdon hetki alkoi laudan valmistuttua")
	if ls.is_empty():
		return
	var lg: CanvasLayer = ls.front()
	_check(int(main.endings.counts.get("porron_kyltti", 0)) == 0, "Pörrö: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible and (not is_instance_valid(main.boys) or not main.boys.visible), "Pörrö: oikeat pojat ja jalan kulkija piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var plate_at := func() -> Vector3: return post.to_global(Vector3(0, 0.92, 0))
	var shots := [["lehto", "lehto", 1.2], ["lehto2", "lehto", 4.2], ["kukka", "kukka", 1.6], ["kukka2", "kukka", 3.6],
		["kivet", "kivet", 1.6], ["kivet2", "kivet", 3.65], ["kivet3", "kivet", 5.7], ["seta", "seta", 1.6], ["seta2", "seta", 4.0],
		["otsikko", "otsikko", 3.2]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Pörrö: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var pl: Vector2 = _sp_sp(lg, plate_at.call())
		var pl2: Vector2 = _sp_sp(lg, post.to_global(Vector3(0.15, 0.92, 0)))
		var heads := [lg.me, lg.veli, lg.pojat[0], lg.pojat[1], lg.pojat[2]].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Pörrö %s: kyltti %s (leveys %.0f px), päät minä/veli/p0/p1/p2 %s" % [st[0], pl, (pl2 - pl).length() * vs.x * 2.0, heads])
		_check(inside.call(pl), "Pörrö: kyltti kuvassa (%s)" % st[0])
		match st[0]:
			"lehto2":
				_check(heads.all(func(h): return inside.call(h)), "Pörrö: pojat, pikkuveli ja pelaaja kuvassa")
			"kukka", "kukka2":
				_check(inside.call(heads[1]), "Pörrö: pikkuveljen kasvot kuvassa")
				_check(inside.call(_sp_sp(lg, lg.flower.global_position)), "Pörrö: voikukka kuvassa")
				if st[0] == "kukka":
					var d: float = lg._hand(lg.veli).distance_to(lg.flower.global_position)
					print("LEGENDA Pörrö kukka kädessä %.3f m" % d)
				else:
					var fl: Vector3 = post.to_global(Vector3(lg.FLOWER.x, 0, lg.FLOWER.y))
					_check(lg.flower.global_position.distance_to(fl) < 0.05, "Pörrö: voikukka kyltin juurella")
			"kivet", "kivet2", "kivet3":
				var who: int = ["kivet", "kivet2", "kivet3"].find(st[0])
				_check(inside.call(heads[2 + who]), "Pörrö: kivenlaskija %d kuvassa" % who)
			"seta":
				_check(inside.call(heads[0]) and inside.call(heads[2]), "Pörrö: pelaaja ja isoveli kuvassa")
				_check(lg._bub.has(lg.pojat[0]), "Pörrö: Setä on ihan ok")
			"seta2":
				_check(inside.call(heads[1]) and lg._bub.has(lg.veli), "Pörrö: pikkuveli kiittää kuvassa")
	# Kivet laskettiin kädestä ja ne ovat juurella.
	for i in 3:
		var d: float = lg.placed.get(lg.stones[i], 9.0)
		var at: Vector3 = post.to_global(Vector3(lg.STONES[i].x, 0, lg.STONES[i].y))
		print("LEGENDA Pörrö kivi %d: käsi laskiessa %.3f m, paikasta %.3f m" % [i, d, lg.stones[i].global_position.distance_to(at)])
		_check(d < 0.12, "Pörrö: kivi %d laskettiin kädestä" % i)
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	var muisto: Array = post.get_children().filter(func(c): return c.has_meta("porro_muisto") and c.visible)
	print("LEGENDA Pörrö jälkeen: kerrat %d, viesti '%s', kivet+kukka %d, pojat näkyvät %s, rauhallisia %s" % [int(main.endings.counts.get("porron_kyltti", 0)),
		main._msg.text, muisto.size(), is_instance_valid(main.boys) and main.boys.visible, main.boys.calm if is_instance_valid(main.boys) else false])
	_check(int(main.endings.counts.get("porron_kyltti", 0)) == 1, "Pörrö: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Pörrö: päiväkirjarivi")
	_check(muisto.size() == 4 and post.visible, "Pörrö: kivet ja voikukka jäivät tolpan juurelle")
	_check(main.walker_out.visible and main.player.controls_enabled, "Pörrö: pelaaja ohjaa taas")
	# Pysyvä juuri kuvaan.
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.current = true
	cam.fov = 40.0
	cam.look_at_from_position(post.to_global(Vector3(0.6, 0.9, -1.8)), post.to_global(Vector3(0, 0.45, -0.1)))
	await _frames(10)
	await _shot(path, "jalkeen")
	cam.look_at_from_position(post.to_global(Vector3(1.6, 0.15, -0.3)), post.to_global(Vector3(0, 0.1, -0.2)))
	await _frames(5)
	await _shot(path, "juuri_sivu")
	cam.queue_free()
	main.walker_out.activate_camera()
	# Muisto: pojat kertovat kyltistä.
	var o: Array = main._talk_options("pojat").map(func(x): return x.id)
	_check("lemmikki_porro" in o, "Pörrö: pojille uusi kysymys kyltistä")
	main._talk_who = "pojat"
	main._talk_lemmikki("lemmikki_porro")
	await _frames(3)
	print("LEGENDA Pörrö muisto: vaihtoehdot %s" % [o])


func _aarni(path: String) -> void:
	main.endings.counts.erase("aarnivalkea")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 5
	main.clock_min = 12 * 60
	var a = main.aarni
	a.heard = true
	a.sulo = true
	a.poytakirja = true
	a.liekki = true
	a.found = true
	a.choice = ""
	var m0: float = main.money
	main.walker_out.global_position = main.world.museum_door + Vector3(0, 0.3, 0)
	await _frames(15)
	print("LEGENDA Aarni: vihje '%s'" % main._hint.text)
	await main.get_tree().process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is AarnivalkeaLegenda)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Aarni: Pirtin pihan hetki alkoi hopeiden luovutuksesta")
	if lg == null:
		return
	_check(a.choice == "museo" and main.money > m0, "Aarni: hopeat museoon ja löytöpalkkio")
	_check(int(main.endings.counts.get("aarnivalkea", 0)) == 0, "Aarni: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible, "Aarni: oikea pelaaja piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["kontti", "kontti", 1.4], ["kontti2", "kontti", 4.0], ["kansi", "kansi", 1.3], ["liekki", "kansi", 1.8],
		["liekki2", "kansi", 3.0], ["sammui", "kansi", 4.6], ["hopeat", "hopeat", 1.6], ["valahdys", "hopeat", 2.85],
		["hopeat2", "hopeat", 4.2], ["hilkka", "hilkka", 1.6], ["hilkka2", "hilkka", 3.6], ["arto", "hilkka", 5.0], ["hilkka3", "hilkka", 6.0],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.2]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Aarni: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var kp: Vector2 = _sp_sp(lg, lg.kontti.global_position + Vector3(0, 0.13, 0))
		var kw: Vector2 = _sp_sp(lg, lg.kontti.to_global(Vector3(0.17, 0.13, 0)))
		var heads := [lg.me, lg.opas, lg.hilkka, lg.arto, lg.annaliisa, lg.pekka].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Aarni %s: kontti %s (puolileveys %.0f px), päät minä/opas/hilkka/arto/al/pekka %s, liekki %.2f" % [st[0], kp,
			(kw - kp).length() * vs.x, heads, lg.flame.scale.y if lg.flame.visible else 0.0])
		if not st[0] in ["hopeat", "valahdys", "hopeat2"]:  # liinan lähikuvassa ja taalerin puolilähikuvassa kontti saa jäädä pois
			_check(inside.call(kp), "Aarni: kontti kuvassa (%s)" % st[0])
		match st[0]:
			"kontti2":
				_check(inside.call(heads[0]) and inside.call(heads[1]), "Aarni: opas ja pelaaja kuvassa")
				_check(lg._bub.has(lg.opas), "Aarni: opas lukee pöytäkirjaa")
			"kansi":
				var lp: Vector3 = lg._top(lg.KONTTI_AT.x, lg.KONTTI_AT.y + 0.1, 0.27)
				var hd: float = lg._hand(lg.opas).distance_to(lp)
				print("LEGENDA Aarni kansi: käsi kannesta %.3f m" % hd)
				_check(hd < 0.12, "Aarni: oppaan käsi kannella")
			"liekki":
				_check(lg.flame.visible and lg.flame.scale.y > 0.6, "Aarni: liekki lehahti kontista")
				_check(inside.call(_sp_sp(lg, lg.flame.global_position + Vector3(0, 0.35, 0))), "Aarni: liekki kuvassa")
				_check(inside.call(heads[1]), "Aarni: oppaan kasvot kuvassa")
			"sammui":
				_check(not lg.flame.visible or lg.flame.scale.y < 0.05, "Aarni: liekki sammui")
			"valahdys":
				_check(lg.held_coin.visible and inside.call(_sp_sp(lg, lg.held_coin.global_position)), "Aarni: taaleri valoa vasten kuvassa")
			"hopeat":
				var cp: Vector2 = _sp_sp(lg, lg.coins[0].global_position)
				var cp2: Vector2 = _sp_sp(lg, lg.coins[0].global_position + lg._G.global_basis.x * 0.04)
				print("LEGENDA Aarni taaleri leveys %.0f px" % ((cp2 - cp).length() * vs.x))
				_check(inside.call(cp) and (cp2 - cp).length() * vs.x > 40.0, "Aarni: hopeat näkyvät isona")
			"hopeat2":
				_check(lg._bub.get(lg.opas, "") == "Juuri nämä!" and inside.call(heads[1]), "Aarni: Juuri nämä! (oppaan kasvot kuvassa)")
			"hilkka2":
				_check(inside.call(heads[0]) and inside.call(heads[1]) and inside.call(heads[2]), "Aarni: Hilkka, opas ja pelaaja kuvassa")
				_check(lg._bub.has(lg.hilkka), "Aarni: Hilkka: Mitäs minä sanoin")
			"hilkka3", "otsikko2":
				_check(heads.all(func(h): return inside.call(h)), "Aarni: kaikki hahmot kuvassa (%s)" % st[0])
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Aarni jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("aarnivalkea", 0)), main._msg.text])
	_check(int(main.endings.counts.get("aarnivalkea", 0)) == 1, "Aarni: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Aarni: päiväkirjarivi")
	_check(main.walker_out.visible and main.player.controls_enabled, "Aarni: pelaaja ohjaa taas")
	# Muisto: Hilkka kertoo (kirppiksellä).
	main.kirppis_int.mode = "kirppis"
	var o: Array = main._talk_options("hilkka").map(func(x): return x.id)
	_check("aarni_muisto" in o, "Aarni: Hilkalle kysymys Pirtin pihasta")
	main._talk_who = "hilkka"
	main._talk_kirppis("aarni_muisto")
	await _frames(3)
	print("LEGENDA Aarni muisto: vaihtoehdot %s" % [o])


func _kerttu(path: String) -> void:
	main.endings.counts.erase("kertun_rauta")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 6
	main.clock_min = 17 * 60
	var k = main.kertun
	k.heard = true
	k.taulu = true
	k.spotted = true
	k.malmi = true
	k.malmi_known = true
	k.kuona = true
	k.found = true
	k.choice = ""
	k.kiitetty = false
	main._kertun_sync()
	var kota: Node3D = main.world.kota
	_check(kota.clipping == null or not kota.clipping.visible, "Kerttu: ei leikettä seinällä ennen hetkeä")
	# Pirtti: kirves museoon, hetki ei vielä.
	var m0: float = main.money
	main.walker_out.global_position = main.world.museum_door + Vector3(0, 0.3, 0)
	await _frames(15)
	print("LEGENDA Kerttu: Pirtti '%s'" % main._hint.text)
	await main.get_tree().process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(3)
	_check(k.choice == "museo" and main.money > m0, "Kerttu: kirves museoon ja löytöpalkkio")
	_check(int(main.endings.counts.get("kertun_rauta", 0)) == 0, "Kerttu: hetki ei vielä Pirtissä")
	var tasks: Array = main._kertun_tasks()
	print("LEGENDA Kerttu: viesti '%s', tehtävät %s" % [main._msg.text.right(60), tasks])
	_check(not tasks.is_empty() and str(tasks[0][0]).contains("lehtijuttu"), "Kerttu: tehtävä näyttää lehti kodalla")
	# Kota: tuli ei pala, lehti silti näytettävissä.
	kota.set_fire(false)
	var b0: int = main.beers
	main.walker_out.global_position = kota.global_position + kota.global_basis * Vector3(0.0, 0.3, -1.6)
	await _frames(15)
	print("LEGENDA Kerttu: kota '%s'" % main._hint.text)
	_check(main._hint.text.contains("lehtijuttu"), "Kerttu: kodalla vihje lehtijutusta")
	await main.get_tree().process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is KertunLegenda)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Kerttu: kodan hetki alkoi lehdestä")
	if lg == null:
		return
	_check(not main.walker_out.visible and not kota.raimo.visible and not kota.veikko.visible, "Kerttu: oikeat hahmot piilossa")
	_check(kota.fire_on, "Kerttu: tuli palaa hetken ajan")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.03 and v.x < 0.97 and v.y > 0.06 and v.y < 0.97
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["sisaan", "lehti", 1.6], ["ojennus", "lehti", 4.05], ["otti", "lehti", 5.0], ["lukee", "raimo", 1.6], ["nousee", "raimo", 2.8],
		["etusivu", "raimo", 4.6], ["veikko", "veikko", 1.8], ["perkele", "veikko", 3.6], ["kyltti", "veikko", 5.8], ["kassi", "kaljat", 1.5],
		["kilistys0", "kaljat", 3.4], ["kilistys", "kaljat", 4.5], ["leike", "leike", 0.9], ["leike2", "leike", 3.2], ["leike3", "leike", 5.0],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.4]]
	var paper_px := func() -> float:
		var c0: Vector2 = _sp_sp(lg, lg.paper.to_global(Vector3(-0.18, 0, 0)))
		var c1: Vector2 = _sp_sp(lg, lg.paper.to_global(Vector3(0.18, 0, 0)))
		return (c1 - c0).length() * vs.x
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Kerttu: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var heads := [lg.me, lg.raimo, lg.veikko].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Kerttu %s: päät minä/raimo/veikko %s, lehti %.0f px %s" % [st[0], heads, paper_px.call(), _sp_sp(lg, lg.paper.global_position)])
		match st[0]:
			"sisaan":
				_check(inside.call(heads[1]) and inside.call(heads[2]), "Kerttu: Raimo ja Veikko kuvassa")
				_check(inside.call(_sp_sp(lg, kota.to_global(Vector3(0, 0.9, 0)))), "Kerttu: tuli kuvassa")
			"ojennus":
				var ho: Vector3 = lg._K(lerpf(lg.P_GIVE.x, lg.S_R.x, 0.5), 1.02, lerpf(lg.P_GIVE.y, lg.S_R.y, 0.5))
				var gap: float = lg._hand(lg.me, lg._near_side(lg.me, ho)).distance_to(lg._hand(lg.raimo, lg._near_side(lg.raimo, ho)))
				print("LEGENDA Kerttu ojennus: kädet %.3f m" % gap)
				_check(gap < 0.2, "Kerttu: lehti kädestä käteen")
			"lukee":
				_check(inside.call(heads[1]), "Kerttu: Raimon kasvot kuvassa")
				_check(inside.call(_sp_sp(lg, lg.paper.global_position)), "Kerttu: lehti kuvassa")
			"etusivu":
				var px: float = paper_px.call()
				var e0: Vector3 = lg.paper.to_global(Vector3(0.18, 0, 0))
				var e1: Vector3 = lg.paper.to_global(Vector3(-0.18, 0, 0))
				var hr: Vector3 = lg._hand(lg.raimo, "r")
				var hl: Vector3 = lg._hand(lg.raimo, "l")
				var dr: float = minf(hr.distance_to(e0), hr.distance_to(e1))
				var dl: float = minf(hl.distance_to(e0), hl.distance_to(e1))
				print("LEGENDA Kerttu etusivu: %.0f px, kädet reunoista %.3f / %.3f m" % [px, dr, dl])
				_check(px > 220.0 and inside.call(_sp_sp(lg, lg.paper.global_position)), "Kerttu: etusivu isona kuvassa")
				_check(minf(dr, dl) < 0.09 and maxf(dr, dl) < 0.12, "Kerttu: Raimo pitää lehteä reunoista")
				var toward: float = (lg._cam.global_position - lg.paper.global_position).dot(lg.paper.global_basis.z)
				_check(toward > 0.0, "Kerttu: etusivu kameraan päin")
				_check(inside.call(heads[1]), "Kerttu: Raimon kasvot kuvassa (etusivu)")
			"perkele":
				_check(lg._bub.get(lg.veikko, "").contains("Perkele") and inside.call(heads[2]), "Kerttu: Veikko: Perkele")
			"kyltti":
				var sg: Vector3 = kota.to_global(lg.KIROILU)
				var sh: Vector3 = lg.raimo.to_global(lg.raimo.bone_position("upperarm_l"))
				var hd: Vector3 = lg._hand(lg.raimo, "l")
				var cosang: float = (hd - sh).normalized().dot((sg - sh).normalized())
				print("LEGENDA Kerttu osoitus: kulma %.0f°" % rad_to_deg(acos(clampf(cosang, -1.0, 1.0))))
				_check(cosang > 0.85, "Kerttu: Raimo osoittaa kylttiä")
				_check(inside.call(_sp_sp(lg, sg)) and inside.call(heads[1]), "Kerttu: kyltti ja Raimo kuvassa")
			"kassi":
				_check(lg.cans[lg.veikko].visible and inside.call(heads[2]), "Kerttu: Veikko nostaa tölkin kassista")
			"kilistys":
				var cs: Array = [lg.raimo, lg.veikko, lg.me].map(func(c): return lg.cans[c].global_position)
				var far := 0.0
				for i in 3:
					far = maxf(far, (cs[i] as Vector3).distance_to(cs[(i + 1) % 3]))
				print("LEGENDA Kerttu kilistys: tölkit %.3f m toisistaan" % far)
				_check(far < 0.16, "Kerttu: kolme tölkkiä yhdessä")
				_check(heads.all(func(h): return inside.call(h)), "Kerttu: kaikki kolme kuvassa (kilistys)")
				_check(cs.all(func(c): return inside.call(_sp_sp(lg, c))), "Kerttu: tölkit kuvassa")
			"leike2":
				_check(lg.paper_on_wall and lg.paper.transform.is_equal_approx(kota.clip_transform()), "Kerttu: lehti seinällä")
				_check(paper_px.call() > 110.0 and inside.call(_sp_sp(lg, lg.paper.global_position)), "Kerttu: leike isona kuvassa")
				_check(inside.call(_sp_sp(lg, kota.to_global(lg.LIIOITTELU))), "Kerttu: liioittelukyltti kuvassa")
				_check(inside.call(heads[1]), "Kerttu: Raimo kuvassa (leike)")
			"otsikko2":
				_check(heads.all(func(h): return inside.call(h)), "Kerttu: kaikki kolme kuvassa (otsikko)")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Kerttu jälkeen: kerrat %d, kaljat %d -> %d, viesti '%s'" % [int(main.endings.counts.get("kertun_rauta", 0)), b0, main.beers, main._msg.text])
	_check(int(main.endings.counts.get("kertun_rauta", 0)) == 1, "Kerttu: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Kerttu: päiväkirjarivi")
	_check(k.kiitetty and main.beers == b0 + 3, "Kerttu: Veikon kolme kaljaa")
	_check(kota.clipping != null and kota.clipping.visible, "Kerttu: leike jäi kodan seinälle")
	_check(kota.raimo.visible and kota.veikko.visible and not kota.fire_on, "Kerttu: oikeat hahmot takaisin ja tuli kuten ennen")
	_check(main.walker_out.visible and main.player.controls_enabled, "Kerttu: pelaaja ohjaa taas")
	_check(main._kertun_tasks().is_empty(), "Kerttu: tehtävä valmis")
	# Leike seinällä pelissä.
	var cam := Camera3D.new()
	kota.add_child(cam)
	var cg: Vector3 = kota.to_global(kota.clip_transform().origin)
	cam.look_at_from_position(kota.to_global(Vector3(0.5, 1.5, -0.3)), cg)
	cam.fov = 45.0
	cam.make_current()
	await _frames(8)
	await _shot(path, "jalkeen")
	cam.queue_free()
	main.player.activate_camera()
	# Muisto kodan jutuissa.
	var lines := {}
	for i in 80:
		lines[str(main._kota_chat_line()[1])] = true
	_check(KertunLegenda.MUISTO.any(func(m): return lines.has(m[1])), "Kerttu: Raimo ja Veikko muistelevat")
	main._hint.text = ""
	await _frames(5)
	print("LEGENDA Kerttu kota jälkeen: '%s'" % main._hint.text)


func _ukko(path: String) -> void:
	main.endings.counts.erase("tekojarven_ukko")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 4
	main.clock_min = 20 * 60 + 40
	var u = main.ukko
	u.heard = true
	u.siimat = 2
	u.lusikka = true
	u.caught = true
	u.choice = ""
	var m0: float = main.money
	main.walker_out.global_position = main.world.museum_door + Vector3(0, 0.3, 0)
	await _frames(15)
	print("LEGENDA Ukko: vihje '%s'" % main._hint.text)
	await main.get_tree().process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is TekojarviLegenda)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Ukko: Pirtin pihan hetki alkoi Ukon luovutuksesta")
	if lg == null:
		return
	_check(u.choice == "museo" and main.money > m0, "Ukko: Ukko museoon ja palkkio")
	_check(int(main.endings.counts.get("tekojarven_ukko", 0)) == 0, "Ukko: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible, "Ukko: oikea pelaaja piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.03 and v.x < 0.97 and v.y > 0.06 and v.y < 0.97
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["punnitus", "punnitus", 0.5], ["punnitus2", "punnitus", 2.2], ["taulu", "punnitus", 3.6], ["taulu2", "punnitus", 5.6],
		["uistimet", "uistimet", 1.4], ["uistimet2", "uistimet", 4.4], ["tauno", "tauno", 2.0], ["lusikka", "tauno", 4.2],
		["kyynel", "tauno", 6.4], ["kyynel2", "tauno", 8.0], ["kuva", "kuva", 1.6], ["kuva2", "kuva", 4.0], ["kuva3", "kuva", 5.8],
		["salama", "kuva", 6.5], ["otsikko", "otsikko", 0.6], ["otsikko2", "otsikko", 3.2]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Ukko: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var snout: Vector2 = _sp_sp(lg, lg._pike_pt(1.0))
		var tail: Vector2 = _sp_sp(lg, lg._pike_pt(0.0))
		var heads := [lg.me, lg.opas, lg.tauno, lg.pekka, lg.arto, lg.annaliisa].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Ukko %s: kuono %s pyrstö %s (pituus %.0f px), päät minä/opas/tauno/pekka/arto/al %s, viisari %.1f" % [st[0],
			snout, tail, ((snout - tail) * vs).length(), heads, lg.needle_kg])
		match st[0]:
			"punnitus2":
				_check(inside.call(snout) and inside.call(tail), "Ukko: koko Ukko kuvassa")
				_check(((snout - tail) * vs).y < -vs.y * 0.35, "Ukko: Ukko roikkuu pystyssä ja isona")
				_check(inside.call(heads[0]) and inside.call(heads[1]), "Ukko: opas ja pelaaja kuvassa")
			"taulu", "taulu2":
				var dc: Vector2 = _sp_sp(lg, lg.scale_dial.global_position)
				var de: Vector2 = _sp_sp(lg, lg.scale_dial.to_global(Vector3(0.074, 0, 0)))
				var r := ((de - dc) * vs).length()
				print("LEGENDA Ukko taulun säde %.0f px" % r)
				_check(inside.call(dc) and r > 80.0, "Ukko: puntarin taulu isona keskellä (%s)" % st[0])
				if st[0] == "taulu2":
					_check(absf(lg.needle_kg - lg.KG) < 0.3, "Ukko: viisari asettui 18,4:ään")
					_check(lg._story.contains("pilkku neljä"), "Ukko: lukema kerrotaan")
			"uistimet2":
				for l: Node3D in lg.lures:
					_check(inside.call(_sp_sp(lg, l.global_position)), "Ukko: uistin kuvassa")
				var l0: Vector2 = _sp_sp(lg, lg.lure_isa.global_position)
				var l1: Vector2 = _sp_sp(lg, lg.lure_isa.global_position + lg._G.global_basis.y * 0.06)
				print("LEGENDA Ukko lusikka %.0f px" % ((l1 - l0) * vs).length())
				_check(((l1 - l0) * vs).length() > 40.0, "Ukko: isän lusikka näkyy isona")
			"tauno":
				_check(inside.call(heads[2]), "Ukko: Tauno kävelee pihalle (kuvassa)")
			"lusikka":
				var hd: float = lg._hand(lg.tauno).distance_to(lg.lure_isa.global_position)
				print("LEGENDA Ukko Taunon käsi lusikasta %.3f m" % hd)
				_check(hd < 0.1, "Ukko: Taunon käsi isän lusikalla")
				_check(inside.call(heads[2]) and inside.call(_sp_sp(lg, lg.lure_isa.global_position)), "Ukko: Tauno ja lusikka kuvassa")
			"kyynel":
				_check(inside.call(heads[2]), "Ukko: Taunon kasvot kuvassa")
				var hw: float = lg._hand(lg.tauno).distance_to(head.call(lg.tauno))
				print("LEGENDA Ukko pyyhintä: käsi päästä %.3f m" % hw)
				_check(hw < 0.2, "Ukko: Tauno pyyhkii silmää")
			"kyynel2":
				var tp: Vector2 = _sp_sp(lg, lg.tear.global_position)
				var tp2: Vector2 = _sp_sp(lg, lg.tear.global_position + Vector3(0, 0.02, 0))
				print("LEGENDA Ukko kyynel %s, korkeus %.0f px" % [tp, ((tp2 - tp) * vs).length()])
				_check(lg.tear.visible and inside.call(tp), "Ukko: kyynel Taunon poskella kuvassa")
				_check(((tp2 - tp) * vs).length() > 12.0, "Ukko: kyynel erottuu")
			"kuva3", "salama", "otsikko2":
				_check(inside.call(snout) and inside.call(tail), "Ukko: Ukko vaakatasossa kuvassa (%s)" % st[0])
				var hs: Array = heads.slice(0, 5) if st[0] == "otsikko2" else heads  # otsikossa kamera on Anna-Liisan puhelin
				_check(hs.all(func(h): return inside.call(h)), "Ukko: kaikki hahmot kuvassa (%s)" % st[0])
				var gaps: Array = []
				for pr in [[lg.tauno, lg.HOLD_U[0]], [lg.tauno, lg.HOLD_U[1]], [lg.me, lg.HOLD_U[2]], [lg.me, lg.HOLD_U[3]]]:
					var pt: Vector3 = lg._pike_pt(pr[1], -1.0)
					var c: Node3D = pr[0]
					gaps.append(minf(lg._hand(c).distance_to(pt), lg._hand_l(c).distance_to(pt)))
				print("LEGENDA Ukko kädet hauen alla %s" % [gaps])
				_check(gaps.all(func(g): return g < 0.09), "Ukko: kädet hauen alla (%s)" % st[0])
			"salama":
				_check(lg.flashed and lg.phone.visible, "Ukko: Anna-Liisa kuvaa (salama)")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Ukko jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("tekojarven_ukko", 0)), main._msg.text])
	_check(int(main.endings.counts.get("tekojarven_ukko", 0)) == 1, "Ukko: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Ukko: päiväkirjarivi")
	_check(main.walker_out.visible and main.player.controls_enabled, "Ukko: pelaaja ohjaa taas")
	main.kirppis_int.mode = "kirppis"
	var o: Array = main._talk_options("tauno").map(func(x): return x.id)
	_check("ukko_muisto" in o, "Ukko: Taunolle kysymys punnituksesta")
	main._talk_who = "tauno"
	main._talk_kirppis("ukko_muisto")
	await _frames(3)
	print("LEGENDA Ukko muisto: vaihtoehdot %s" % [o])


func _tokola(path: String) -> void:
	main.endings.counts.erase("tokolan_aarre")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 5
	main.clock_min = 12 * 60
	var tk = main.tokola
	tk.key = true
	tk.tilikirja = true
	tk.lankku = true
	tk.lipas = true
	tk.markat = true
	tk.legend = ""
	var m0: float = main.maine
	main.walker_out.global_position = main.world.aaro_pos + Vector3(1.5, 0.3, 0)
	await _frames(15)
	main._talk_open("aaro", main.aaro)
	main._talk_box._pages.clear()
	var o0: Array = main._talk_options("aaro").map(func(x): return x.id)
	_check("lipas" in o0, "Tokola: Aarolle lippaan näyttö")
	main._talk_choose("lipas")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is TokolaLegenda)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Tokola: Aaron pihan hetki alkoi lippaan näytöstä")
	if lg == null:
		return
	_check(tk.legend == "kyla" and main.maine > m0, "Tokola: legenda todistettu ja maine")
	_check(int(main.endings.counts.get("tokolan_aarre", 0)) == 0, "Tokola: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible and not main.aaro.visible, "Tokola: oikea pelaaja ja Aaro piilossa")
	_check(not main._talk_box.visible, "Tokola: keskustelu suljettiin")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["lipas", "lipas", 1.0], ["vaanto", "lipas", 2.6], ["auki", "lipas", 4.6], ["sormus", "sormus", 1.0],
		["nosto", "sormus", 2.2], ["valo", "sormus", 3.6], ["karamelli", "sormus", 5.4], ["kavely", "huuto", 1.6], ["huuto", "huuto", 3.8],
		["tulo", "pekka", 1.8], ["seteli", "pekka", 3.0], ["sieppaus", "pekka", 3.8], ["lukee", "pekka", 5.0], ["perkele", "pekka", 6.8],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.4]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Tokola: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var lp: Vector2 = _sp_sp(lg, lg.lipas.global_position + Vector3(0, 0.05, 0))
		var heads := [lg.me, lg.aaro, lg.pekka, lg.arto].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Tokola %s: lipas %s, päät minä/aaro/pekka/arto %s" % [st[0], lp, heads])
		match st[0]:
			"lipas", "auki":
				_check(inside.call(lp) and inside.call(heads[0]) and inside.call(heads[1]), "Tokola: lipas, Aaro ja pelaaja kuvassa (%s)" % st[0])
				if st[0] == "auki":
					_check(absf(lg.lid.rotation.z) > 1.5, "Tokola: kansi auki")
			"vaanto":
				var corner: Vector3 = lg.pry_point()
				var hd: float = lg._hand(lg.aaro).distance_to(corner)
				var tip: float = lg.knife.to_global(Vector3(0, 0, -0.1)).distance_to(corner)
				print("LEGENDA Tokola väännön käsi kulmasta %.3f m, puukon kärki %.3f m" % [hd, tip])
				_check(lg.knife.visible and hd < 0.15 and tip < 0.06, "Tokola: puukko kannen raossa")
				_check(inside.call(lp), "Tokola: lipas kuvassa väännössä")
			"sormus":
				var rp: Vector2 = _sp_sp(lg, lg.ring.global_position)
				var rp2: Vector2 = _sp_sp(lg, lg.ring.global_position + lg._G.global_basis.x * 0.023)
				var np: Vector2 = _sp_sp(lg, lg.nippu.global_position)
				print("LEGENDA Tokola sormus leveys %.0f px" % ((rp2 - rp).length() * vs.x))
				_check(inside.call(rp) and inside.call(np) and (rp2 - rp).length() * vs.x > 30.0, "Tokola: sormus ja nippu näkyvät isona")
			"nosto":
				var hd2: float = lg._hand(lg.aaro).distance_to(lg.lipas.to_global(Vector3(0.075, 0.05, 0.035)))
				print("LEGENDA Tokola sormuksen otto: käsi lippaasta %.3f m" % hd2)
				_check(hd2 < 0.12, "Tokola: Aaron käsi lippaassa sormuksen kohdalla")
			"valo":
				var rp: Vector2 = _sp_sp(lg, lg.ring.global_position)
				_check(lg.ring.visible and inside.call(rp) and inside.call(heads[1]), "Tokola: sormus valoa vasten ja Aaron kasvot kuvassa")
				_check(lg._bub.has(lg.aaro), "Tokola: Hilman sormus")
			"huuto":
				var ny: float = lg.nippu.global_position.y
				_check(ny > head.call(lg.aaro).y, "Tokola: nippu Aaron pään yllä")
				_check(inside.call(heads[1]) and inside.call(_sp_sp(lg, lg.nippu.global_position)), "Tokola: Aaro ja nippu kuvassa")
			"tulo":
				_check(inside.call(heads[1]) and inside.call(heads[2]), "Tokola: Aaro ja Pekka kuvassa")
				_check(lg._pointing.has(lg.aaro), "Tokola: Aaro osoittaa Pekkaa etusormella")
				var sk: Skeleton3D = lg.aaro.skeleton
				var i: int = sk.find_bone("index_02_l")
				var dev: float = sk.get_bone_pose_rotation(i).angle_to(sk.get_bone_rest(i).basis.get_rotation_quaternion())
				print("LEGENDA Tokola etusormen taivutus %.3f rad" % dev)
				_check(dev < 0.05, "Tokola: etusormi suorana")
			"seteli":
				_check(lg.note.visible and inside.call(_sp_sp(lg, lg.note.global_position)), "Tokola: seteli leijailee kuvassa")
			"sieppaus", "lukee":
				_check(lg.note_caught and inside.call(_sp_sp(lg, lg.note.global_position)) and inside.call(heads[2]), "Tokola: Pekka sieppasi setelin (%s)" % st[0])
			"perkele":
				_check(lg._bub.get(lg.pekka, "").contains("Aaro oli oikeassa"), "Tokola: Pekka myöntää")
				_check(heads.all(func(h): return inside.call(h)), "Tokola: kaikki hahmot kuvassa (perkele)")
			"otsikko2":
				_check(heads.all(func(h): return inside.call(h)), "Tokola: kaikki hahmot kuvassa (otsikko)")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Tokola jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("tokolan_aarre", 0)), main._msg.text])
	_check(int(main.endings.counts.get("tokolan_aarre", 0)) == 1, "Tokola: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Tokola: päiväkirjarivi")
	_check(main.walker_out.visible and main.aaro.visible and main.player.controls_enabled, "Tokola: pelaaja ja Aaro palasivat")
	var o: Array = main._talk_options("aaro").map(func(x): return x.id)
	_check("tokola_muisto" in o, "Tokola: Aarolle kysymys setelistä")
	main._talk_who = "aaro"
	main._talk_aaro("tokola_muisto")
	await _frames(3)
	main._talk_box.close()
	print("LEGENDA Tokola muisto: vaihtoehdot %s" % [o])


func _sulo(path: String) -> void:
	main.endings.counts.erase("sulon_pannu")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 4
	main.clock_min = 14 * 60
	main.pannu = SuloPannu.new()
	main.pannu.heard = true
	main.pannu.spotted = true
	main.pannu.found = true
	main.has_kanister = false
	main._sulo_sold = false
	main._pannu_update()
	main.walker_out.global_position = main.sulo.global_position + Vector3(1.2, 0.3, 0.6)
	await _frames(15)
	main._talk_open("sulo", main.sulo)
	main._talk_box._pages.clear()
	var o0: Array = main._talk_options("sulo").map(func(x): return x.id)
	_check("pannu" in o0, "Sulo: pannun anto Sululle")
	main._talk_choose("pannu")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is SuloLegenda)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Sulo: metsän hetki alkoi pannun annosta")
	if lg == null:
		return
	_check(main.pannu.choice == "sulo", "Sulo: valinta kirjattu")
	_check(int(main.endings.counts.get("sulon_pannu", 0)) == 0, "Sulo: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible and not main.sulo.visible, "Sulo: oikea pelaaja ja Sulo piilossa")
	_check(not main._talk_box.visible, "Sulo: keskustelu suljettiin")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["pannu", "pannu", 1.0], ["mista", "pannu", 3.0], ["hankaus", "leima", 2.0], ["leima", "leima", 4.5],
		["isan", "leima", 6.0], ["nousu", "myonto", 1.2], ["kielsi", "myonto", 3.4], ["myonto", "myonto", 5.6],
		["kuksa", "tipat", 0.8], ["heitto", "tipat", 1.4], ["leimahdus", "tipat", 2.1], ["tulo", "tipat", 4.2],
		["ojennus", "tipat", 5.3], ["maistaa", "tipat", 6.4], ["perkele", "tipat", 7.6], ["otsikko", "otsikko", 1.0],
		["otsikko2", "otsikko", 3.4]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Sulo: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var pp: Vector2 = _sp_sp(lg, lg.pan.global_position + Vector3(0, 0.2, 0))
		var heads := [lg.me, lg.sulo, lg.pekka, lg.arto].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Sulo %s: pannu %s, päät minä/sulo/pekka/arto %s, kamera %s, G.y %.2f, maa %.2f" % [st[0], pp, heads,
			lg._G.to_local(lg._cam.global_position), lg._G.global_position.y, lg._L(0, 0).y])
		match st[0]:
			"pannu", "mista":
				var p2: Vector2 = _sp_sp(lg, lg.pan.global_position + Vector3(0, 0.55, 0))
				print("LEGENDA Sulo pannun korkeus %.0f px" % ((pp - p2).length() * vs.y * 2.0))
				_check(inside.call(pp) and inside.call(heads[0]) and inside.call(heads[1]), "Sulo: pannu, Sulo ja pelaaja kuvassa (%s)" % st[0])
				_check((pp - p2).length() * vs.y * 2.0 > 60.0, "Sulo: pannu näkyy (%s)" % st[0])
			"hankaus":
				var sp: Vector3 = lg.stamp_point()
				var hd: float = lg._hand(lg.sulo).distance_to(sp)
				var s1: Vector2 = _sp_sp(lg, sp)
				print("LEGENDA Sulo hankaava käsi leimasta %.3f m, hangattu %.2f" % [hd, lg.rubbed])
				_check(hd < 0.12, "Sulo: käsi hankaa leimaa")
				_check(inside.call(s1), "Sulo: leima kuvassa hangatessa")
			"leima":
				var sp: Vector3 = lg.stamp_point()
				var s1: Vector2 = _sp_sp(lg, sp)
				var s2: Vector2 = _sp_sp(lg, sp + lg.pan.global_basis.z.normalized() * 0.07)
				print("LEGENDA Sulo leiman leveys %.0f px" % ((s2 - s1).length() * vs.x * 2.0))
				_check(lg.rubbed >= 0.99 and inside.call(s1) and (s2 - s1).length() * vs.x * 2.0 > 80.0, "Sulo: leima kirkas ja isona")
			"isan":
				_check(inside.call(heads[1]) and lg._bub.get(lg.sulo, "").contains("Isä löi"), "Sulo: Sulon kasvot ja leiman repliikki")
			"myonto":
				_check(inside.call(heads[1]) and lg._bub.get(lg.sulo, "").contains("Isä keitti"), "Sulo: Sulo myöntää")
				var bog: Vector3 = M.w(SuloPannu.SPOT)
				var fwd: Vector3 = -lg.sulo.global_basis.z
				var to_bog: Vector3 = (bog - lg.sulo.global_position)
				to_bog.y = 0.0
				print("LEGENDA Sulo katse Pilkkarinnevalle: kulma %.2f rad" % fwd.angle_to(to_bog))
				_check(fwd.angle_to(to_bog) < 0.4, "Sulo: Sulo katsoo Pilkkarinnevalle")
			"kuksa":
				var hk: float = lg._hand(lg.sulo).distance_to(lg.kuksa.global_position)
				print("LEGENDA Sulo kuksa kädestä %.3f m, kuvassa %s" % [hk, _sp_sp(lg, lg.kuksa.global_position)])
				_check(hk < 0.12 and inside.call(_sp_sp(lg, lg.kuksa.global_position)), "Sulo: kuksa Sulon kädessä ja kuvassa")
			"leimahdus":
				_check(lg.flared and lg._flare.emitting, "Sulo: liekki leimahtaa")
				_check(inside.call(_sp_sp(lg, lg._flare.global_position + Vector3(0, 0.4, 0))) and inside.call(heads[1]), "Sulo: leimahdus ja Sulo kuvassa")
			"tulo":
				_check(inside.call(heads[2]) and inside.call(heads[3]), "Sulo: Pekka ja Arto kuvassa")
			"maistaa":
				var hk2: float = lg._hand(lg.pekka).distance_to(lg.kuksa.global_position)
				print("LEGENDA Sulo kuksa Pekan kädestä %.3f m, maistettu %s" % [hk2, lg.tasted])
				_check(hk2 < 0.12 and lg.tasted, "Sulo: Pekka maistaa kuksasta")
				_check(inside.call(heads[2]) and inside.call(_sp_sp(lg, lg.kuksa.global_position)), "Sulo: Pekan kasvot ja kuksa kuvassa")
			"perkele":
				_check(lg._bub.get(lg.pekka, "").contains("Taas väärin"), "Sulo: Pekka myöntää")
				_check(inside.call(heads[1]) and inside.call(heads[2]) and inside.call(_sp_sp(lg, lg.kuksa.global_position)), "Sulo: Sulo, Pekka ja kuksa kuvassa (perkele)")
			"otsikko2":
				_check(heads.all(func(h): return inside.call(h)) and inside.call(pp), "Sulo: kaikki hahmot ja pannu kuvassa (otsikko)")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Sulo jälkeen: kerrat %d, viesti '%s', kanisteri %s" % [int(main.endings.counts.get("sulon_pannu", 0)), main._msg.text, main.has_kanister])
	_check(int(main.endings.counts.get("sulon_pannu", 0)) == 1, "Sulo: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Sulo: päiväkirjarivi")
	_check(main.has_kanister and main._kanister_beers() == SuloPannu.RESEPTI_BEERS, "Sulo: ilmainen kanisteri isän reseptillä")
	_check(main.walker_out.visible and main.sulo.visible and main.player.controls_enabled, "Sulo: pelaaja ja Sulo palasivat")
	_check(main._isan_pannu != null and is_instance_valid(main._isan_pannu), "Sulo: isän pannu jäi kivelle")
	# Pysyvä pannu kivellä: kuva pelikamerasta läheltä.
	var kc := Camera3D.new()
	main.add_child(kc)
	var kp: Vector3 = main._isan_pannu.get_node("IsanPannu").global_position
	kc.look_at_from_position(kp + Vector3(1.6, 1.1, -1.4).rotated(Vector3.UP, SuloLegenda.YAW), kp + Vector3(-0.5, 0.4, 0.5).rotated(Vector3.UP, SuloLegenda.YAW))
	kc.current = true
	await _frames(5)
	await _shot(path, "jalkeen")
	kc.queue_free()
	main.player.activate_camera()
	var o: Array = main._talk_options("sulo").map(func(x): return x.id)
	_check("pannu_muisto" in o, "Sulo: Sululle kysymys leimahduksesta")
	main._talk_open("sulo", main.sulo)
	main._talk_choose("pannu_muisto")
	await _frames(3)
	main._talk_box.close()
	print("LEGENDA Sulo muisto: vaihtoehdot %s" % [o])


func _pyhimys(path: String) -> void:
	main.endings.counts.erase("palon_pyhimys")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 5
	main.clock_min = 17 * 60 + 30
	var py = main.pyhimys
	for k in ["heard", "luettelo", "kynttila", "lupaus", "aitta", "found"]:
		py.set(k, true)
	py.returned = false
	var m0: float = main.maine
	main.walker_out.global_position = main.world.kirkko_pos + Vector3(0, 0.3, 0)
	await _frames(15)
	main._pyhimys_nodes()
	main._talk_open("suntio", main.suntio)
	main._talk_box._pages.clear()
	var o0: Array = main._talk_options("suntio").map(func(x): return x.id)
	_check("pyhimys_anna" in o0, "Pyhimys: suntiolle pyhimyksen anto")
	main._talk_choose("pyhimys_anna")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is PyhimysKohtaus)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Pyhimys: portaiden hetki alkoi annosta")
	if lg == null:
		return
	_check(py.returned and main.maine > m0, "Pyhimys: palautettu ja maine")
	_check(int(main.endings.counts.get("palon_pyhimys", 0)) == 0, "Pyhimys: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible and not main.suntio.visible, "Pyhimys: oikea pelaaja ja suntio piilossa")
	_check(not main._talk_box.visible, "Pyhimys: keskustelu suljettiin")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["kaare", "kaare", 0.6], ["ojennus", "kaare", 1.2], ["avaus", "kaare", 2.2], ["nosto0", "kaare", 3.4], ["pyhimys", "kaare", 5.0],
		["poyta", "luettelo", 1.6], ["rivi", "luettelo", 3.4], ["yli", "luettelo", 4.5], ["kirjoitus", "luettelo", 7.0],
		["kysymys", "nimi", 1.2], ["nimi", "nimi", 2.8], ["nyokkays", "nimi", 4.1], ["nosto", "nimi", 6.3],
		["kavely", "ovi", 1.0], ["auki", "ovi", 3.2], ["kynnys", "ovi", 4.6], ["hylly", "ovi", 6.9], ["kiinni", "ovi", 8.8],
		["kynttila", "kynttila", 1.8], ["vire", "kynttila", 3.9], ["sammui", "kynttila", 5.4], ["lahto", "kynttila", 8.2],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.6]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Pyhimys: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var heads := [lg.me, lg.suntio, lg.nainen, lg.hoitaja].map(func(c): return _sp_sp(lg, head.call(c)))
		var sp: Vector2 = _sp_sp(lg, lg.saint.global_position + Vector3(0, 0.15, 0))
		print("LEGENDA Pyhimys %s: pyhimys %s, päät minä/suntio/nainen/hoitaja %s" % [st[0], sp, heads])
		match st[0]:
			"ojennus":
				_check(inside.call(heads[0]) and inside.call(heads[1]), "Pyhimys: pelaaja ja suntio kuvassa ojennuksessa")
				_check(inside.call(_sp_sp(lg, lg.bundle.global_position)), "Pyhimys: kääre kuvassa")
				var hl: Vector3 = lg.me.to_global(lg.me.bone_position("hand_l"))
				var hr: Vector3 = lg.me.to_global(lg.me.bone_position("hand_r"))
				var bp: Vector3 = lg.bundle.global_position
				print("LEGENDA Pyhimys ojennus: pelaajan kädet kääreestä %.3f / %.3f m" % [hl.distance_to(bp), hr.distance_to(bp)])
				_check(hl.distance_to(bp) < 0.15 and hr.distance_to(bp) < 0.15, "Pyhimys: kääre pelaajan käsissä")
			"avaus":
				var hd: float = lg._hand_r(lg.suntio).distance_to(lg.bundle.global_position)
				print("LEGENDA Pyhimys avaus: suntion käsi kääreestä %.3f m" % hd)
				_check(hd < 0.35, "Pyhimys: suntio avaa kääreen läpät")
			"pyhimys":
				var top: Vector2 = _sp_sp(lg, lg.saint.to_global(Vector3(0, 0.3, 0)))
				var bot: Vector2 = _sp_sp(lg, lg.saint.to_global(Vector3.ZERO))
				var hpx: float = (top - bot).length() * vs.y
				print("LEGENDA Pyhimys lähikuva: pyhimyksen korkeus %.0f px" % hpx)
				_check(lg.saint.visible and inside.call(sp) and hpx > 150.0, "Pyhimys: pyhimys isona lähikuvassa")
			"rivi", "yli":
				var lp: Vector3 = lg._line_point(0.05)
				var fd: float = lg._hand_l(lg.suntio).distance_to(lp)
				print("LEGENDA Pyhimys sormi rivistä %.3f m" % fd)
				_check(inside.call(_sp_sp(lg, lp)) and fd < 0.14, "Pyhimys: sormi yliviivatulla rivillä (%s)" % st[0])
				_check(inside.call(_sp_sp(lg, lg.saint.global_position + Vector3(0, 0.15, 0))), "Pyhimys: pyhimys kirjan vieressä (%s)" % st[0])
			"kirjoitus":
				print("LEGENDA Pyhimys kirjoitus %d merkkiä" % lg.written_chars)
				_check(lg.pen.visible and lg.written_chars >= 6, "Pyhimys: suntio kirjoittaa palautettu")
				_check(inside.call(_sp_sp(lg, lg.written.global_position)), "Pyhimys: kirjoitus kuvassa")
			"nimi":
				_check(lg._bub.get(lg.me, "").contains("Suvun nimeä"), "Pyhimys: suvun nimeä ei mainita")
				_check(inside.call(heads[0]) and inside.call(heads[1]), "Pyhimys: molemmat kuvassa (nimi)")
			"nosto":
				_check(lg._saint_held_by == lg.suntio and inside.call(sp), "Pyhimys: suntio kantaa pyhimystä")
			"auki":
				_check(lg.door_open > 0.9, "Pyhimys: ovet auki")
				_check(inside.call(_sp_sp(lg, lg._D.to_global(Vector3(0, 1.8, 0)))) and inside.call(heads[1]), "Pyhimys: oviaukko ja suntio kuvassa")
			"kynnys":
				_check(inside.call(heads[1]) and inside.call(sp), "Pyhimys: suntio ja pyhimys asehuoneessa kuvassa")
			"kiinni":
				_check(lg.saint_in_niche and lg.door_open < 0.3, "Pyhimys: pyhimys syvennyksessä, ovet kiinni")
			"kynttila":
				var fp: Vector2 = _sp_sp(lg, lg.flame.global_position)
				_check(lg.flame.visible and inside.call(fp) and inside.call(heads[2]), "Pyhimys: kynttilä ja nainen kuvassa")
			"sammui":
				_check(lg.flame_out and lg._smoke.emitting, "Pyhimys: kynttilä sammui ja savu nousee")
				_check(lg._bub.get(lg.nainen, "").contains("kotona"), "Pyhimys: nyt se on kotona")
			"otsikko2":
				_check(inside.call(heads[2]), "Pyhimys: nainen kuvassa (otsikko)")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Pyhimys jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("palon_pyhimys", 0)), main._msg.text])
	_check(int(main.endings.counts.get("palon_pyhimys", 0)) == 1, "Pyhimys: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Pyhimys: päiväkirjarivi")
	_check(main.walker_out.visible and main.suntio.visible and main.player.controls_enabled, "Pyhimys: pelaaja ja suntio palasivat")
	var o: Array = main._talk_options("suntio").map(func(x): return x.id)
	_check("pyhimys_muisto" in o, "Pyhimys: suntiolle muistelukysymys")
	main._talk_who = "suntio"
	main._talk_pyhimys("pyhimys_muisto")
	await _frames(3)
	main._talk_box.close()
	print("LEGENDA Pyhimys muisto: vaihtoehdot %s" % [o])


func _olavi(path: String) -> void:
	main.endings.counts.erase("olavinmarkkinat")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 8
	main.clock_min = 12 * 60
	var o = main.olavi
	for k in ["heard", "kirje", "kivi", "pappa", "lupa", "lapio", "found"]:
		o.set(k, true)
	o.choice = ""
	var m0: float = main.money
	main._olavi_nodes()
	main.walker_out.global_position = main.world.museum_door + Vector3(0, 0.3, 0)
	await _frames(15)
	print("LEGENDA Olavi: vihje '%s'" % main._hint.text)
	await main.get_tree().process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is OlaviMarkkinat)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Olavi: markkinoiden avaus alkoi taalereiden luovutuksesta")
	if lg == null:
		return
	_check(o.choice == "museo" and main.money > m0, "Olavi: taalerit museoon ja löytöpalkkio")
	_check(int(main.endings.counts.get("olavinmarkkinat", 0)) == 0, "Olavi: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible and not main.olavi_pappa.visible, "Olavi: oikea pelaaja ja pappa piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.03 and v.x < 0.97 and v.y > 0.06 and v.y < 0.97
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var px := func(a: Vector3, b: Vector3) -> float: return (_sp_sp(lg, a) - _sp_sp(lg, b)).length() * vs.x
	var shots := [["kojut", "kojut", 2.0], ["kojut2", "kojut", 4.5], ["lyhty", "lyhty", 1.8], ["puhallus", "lyhty", 2.9], ["sammui", "lyhty", 3.4],
		["ripustus", "lyhty", 4.6], ["koukussa", "lyhty", 6.2], ["naru", "avaus", 1.3], ["auki", "avaus", 2.5], ["hurraa", "avaus", 4.0],
		["raha", "tuoppi", 2.0], ["tuoppi", "tuoppi", 2.8], ["haistaa", "tuoppi", 4.0], ["anteeks", "tuoppi", 5.8], ["skytta", "tuoppi", 7.2],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.2]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Olavi: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var heads := [lg.me, lg.olavi, lg.hilkka, lg.arto, lg.annaliisa, lg.pekka].map(func(c): return _sp_sp(lg, head.call(c)))
		var lp: Vector2 = _sp_sp(lg, lg.lantern.global_position + Vector3(0, 0.15, 0))
		print("LEGENDA Olavi %s: päät minä/pappa/hilkka/arto/al/pekka %s, lyhty %s (%.0f px), banderolli %.2f" % [st[0], heads, lp,
			px.call(lg.lantern.global_position, lg.lantern.global_position + Vector3(0, 0.3, 0)), lg.banner_open])
		match st[0]:
			"kojut2":
				_check(heads.all(func(h): return inside.call(h)), "Olavi: väki ja pappa kuvassa")
				_check(inside.call(_sp_sp(lg, lg._L(lg.TERVA.x, lg.TERVA.y, 1.5))) and inside.call(_sp_sp(lg, lg._L(lg.VOI.x, lg.VOI.y, 1.5))), "Olavi: molemmat kojut kuvassa")
			"lyhty":
				var hp: Vector2 = heads[1]
				_check(inside.call(hp) and inside.call(lp), "Olavi: papan kasvot ja lyhty kuvassa")
				var lh: float = px.call(lg.lantern.global_position, lg.lantern.global_position + Vector3(0, 0.3, 0))
				_check(lh > 60.0, "Olavi: lyhty isona (%.0f px)" % lh)
				var fl: Node3D = lg.lantern.get_meta("flame")
				_check(fl.visible, "Olavi: lyhty palaa")
			"sammui":
				_check(lg.lantern_out, "Olavi: liekki sammui")
			"koukussa":
				var hk: Vector3 = lg._K(lg.HOOK.x, lg.HOOK.y, lg.HOOK.z)
				var top: Vector3 = lg.lantern.global_position + Vector3(0, 0.36, 0)
				_check(top.distance_to(hk) < 0.03 and inside.call(lp), "Olavi: lyhty koukussa ja kuvassa")
			"naru":
				var hd: float = lg._hand(lg.olavi, "r").distance_to(lg._cord.global_position + (lg._cord.global_basis.y * 0.5))
				print("LEGENDA Olavi naru: käsi narun päästä %.3f m" % hd)
				_check(hd < 0.08, "Olavi: käsi narussa")
			"auki", "hurraa":
				_check(lg.banner_open > 0.95 and inside.call(_sp_sp(lg, lg._K(0.0, lg.BANNER_TOP - 0.3, -1.78))), "Olavi: banderolli auki ja kuvassa (%s)" % st[0])
				_check(inside.call(heads[1]), "Olavi: papan kasvot kuvassa (%s)" % st[0])
			"tuoppi", "haistaa":
				var tw: float = px.call(lg.tuoppi.global_position, lg.tuoppi.global_position + lg._cam.global_basis.x * 0.11)
				print("LEGENDA Olavi tuoppi %.0f px, käsi tuopista %.3f m" % [tw, lg._hand(lg.pekka).distance_to(lg.tuoppi.global_position)])
				_check(inside.call(_sp_sp(lg, lg.tuoppi.global_position)) and tw > 40.0, "Olavi: tuoppi kuvassa isona (%s)" % st[0])
				_check(inside.call(heads[5]), "Olavi: Pekan kasvot kuvassa (%s)" % st[0])
			"anteeks", "skytta":
				_check(inside.call(heads[5]) and inside.call(heads[1]), "Olavi: Pekka ja pappa kuvassa (%s)" % st[0])
			"otsikko2":
				_check(heads.all(func(h): return inside.call(h)), "Olavi: kaikki hahmot kuvassa (otsikko)")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Olavi jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("olavinmarkkinat", 0)), main._msg.text])
	_check(int(main.endings.counts.get("olavinmarkkinat", 0)) == 1, "Olavi: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Olavi: päiväkirjarivi")
	_check(main.walker_out.visible and main.player.controls_enabled, "Olavi: pelaaja ohjaa taas")
	_check(main._olavi_lyhty != null and main._olavi_lyhty.is_inside_tree(), "Olavi: papan lyhty jäi kuistille")
	# Kuva pysyvästä lyhdystä.
	var k: Node3D = main.world.seura_kuisti
	var cam := Camera3D.new()
	main.world.add_child(cam)
	var hk2: Vector3 = k.to_global(OlaviMarkkinat.HOOK)
	cam.look_at_from_position(hk2 + k.global_basis * Vector3(-1.2, -0.3, -2.6), hk2 + Vector3(0, -0.3, 0))
	cam.fov = 40.0
	cam.make_current()
	await _shot(path, "jalkeen")
	cam.queue_free()
	main.player.activate_camera()
	var opts: Array = main._talk_options("olavi_pappa").map(func(x): return x.id)
	_check("olavi_muisto" in opts, "Olavi: papalle kysymys lyhdystä")
	main._talk_who = "olavi_pappa"
	main._talk_olavi("olavi_muisto")
	await _frames(3)
	print("LEGENDA Olavi muisto: vaihtoehdot %s" % [opts])


func _tapuli(path: String) -> void:
	main.endings.counts.erase("kuninkaan_tapuli")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 6
	main.clock_min = 12 * 60
	var k = main.kuningas
	for f in ["heard", "yokello", "teinit", "avain", "asiakirja", "found"]:
		k.set(f, true)
	k.choice = ""
	var m0: float = main.money
	main._pyhimys_nodes()
	main.walker_out.global_position = main.world.museum_door + Vector3(0, 0.3, 0)
	await _frames(15)
	print("LEGENDA Tapuli: vihje '%s'" % main._hint.text)
	await main.get_tree().process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is TapuliLegenda)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Tapuli: tapulin hetki alkoi piirustuksen näytöstä")
	if lg == null:
		return
	_check(k.choice == "museo" and main.money > m0, "Tapuli: piirustus museoon ja löytöpalkkio")
	_check(int(main.endings.counts.get("kuninkaan_tapuli", 0)) == 0, "Tapuli: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible and not main.suntio.visible, "Tapuli: oikea pelaaja ja suntio piilossa")
	_check(lg.ink_hits >= 60, "Tapuli: tapulin ääriviivat projisoituvat paperille (%d pistettä)" % lg.ink_hits)
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.03 and v.x < 0.97 and v.y > 0.06 and v.y < 0.97
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var px := func(a: Vector3, b: Vector3) -> float: return (_sp_sp(lg, a) - _sp_sp(lg, b)).length() * vs.x
	var shots := [["poyta", "sinetti", 1.0], ["rulla", "sinetti", 2.4], ["sinetti", "sinetti", 4.0], ["aito", "sinetti", 5.8],
		["kavely", "piirustus", 1.2], ["avaus", "piirustus", 3.0], ["piirros", "piirustus", 4.6], ["nostetaan", "piirustus", 6.2],
		["nosto", "torni", 1.0], ["piirustus", "torni", 1.8], ["viivat", "torni", 3.4], ["kello", "torni", 5.4], ["tuuli", "torni", 7.0],
		["tulo", "kierros", 1.6], ["arto", "kierros", 3.6], ["suntio", "kierros", 4.8], ["gustavus", "kierros", 6.4],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.2]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Tapuli: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var heads := [lg.me, lg.intendentti, lg.opas, lg.suntio, lg.pekka, lg.arto].map(func(c): return _sp_sp(lg, head.call(c)))
		var pc: Vector2 = _sp_sp(lg, lg.scroll.global_position)
		print("LEGENDA Tapuli %s: päät minä/int/opas/suntio/pekka/arto %s, paperi %s, avautuma %.2f, alfa %.2f" % [st[0], heads, pc, lg._paper_w, lg._paper_alpha])
		match st[0]:
			"poyta":
				_check(inside.call(heads[1]) and inside.call(_sp_sp(lg, lg.case_box.global_position)), "Tapuli: intendentti ja kotelo kuvassa")
			"sinetti", "aito":
				var sp: Vector3 = lg.seal.to_global(Vector3(0, -0.12, 0))
				var sw: float = px.call(sp - lg.scroll.global_basis.x * 0.042, sp + lg.scroll.global_basis.x * 0.042)
				_check(inside.call(_sp_sp(lg, sp)) and sw > 60.0, "Tapuli: sinetti lähikuvassa isona (%.0f px, %s)" % [sw, st[0]])
				_check(lg.lens.visible, "Tapuli: suurennuslasi sinetin edessä (%s)" % st[0])
			"piirros":
				_check(lg._paper_w > 0.95 and inside.call(pc), "Tapuli: piirustus auki ja kuvassa")
				for pair in [[lg.intendentti, lg.roll_l], [lg.opas, lg.roll_r]]:
					var c: Node3D = pair[0]
					var r: Node3D = pair[1]
					var dl: float = c.to_global(c.bone_position("hand_l")).distance_to(r.global_position)
					var dr: float = c.to_global(c.bone_position("hand_r")).distance_to(r.global_position)
					print("LEGENDA Tapuli kädet rullasta %.3f / %.3f m" % [dl, dr])
					_check(dl < 0.2 and dr < 0.2, "Tapuli: molemmat kädet rullalla")
			"viivat":
				_check(lg._paper_alpha < 0.3, "Tapuli: paperi haalistui")
				# Tapulin kulmat ruudulla (oikea tapuli) ja samat kulmat paperin viivoina: ristin kärki ja katon räystäät.
				var tr: Node3D = main.world.tapuli_root
				for q in [Vector3(0, 11.9, 0), Vector3(-2.87, 7.1, -2.87), Vector3(2.87, 7.1, -2.87), Vector3(-2.6, 3.9, -2.6), Vector3(0, 10.7, 0)]:
					var real: Vector2 = _sp_sp(lg, tr.to_global(q))
					var on_paper: Vector2 = lg._project(tr.to_global(q), lg._paper_at, 1.0)
					var paper_w: Vector3 = lg._paper_at + lg._paper_basis.x * on_paper.x + lg._paper_basis.y * on_paper.y
					var drawn: Vector2 = _sp_sp(lg, paper_w)
					var off := (real - drawn).length() * vs.x
					print("LEGENDA Tapuli viiva %s: tapuli %s, piirros %s, ero %.1f px" % [q, real, drawn, off])
					_check(off < 4.0 and inside.call(real), "Tapuli: kuninkaan viiva osuu tapuliin (%s)" % q)
			"kello":
				_check(lg.bell_swung, "Tapuli: kello heilahti")
				_check(inside.call(_sp_sp(lg, main.world.tapuli_bell.global_position)), "Tapuli: kello kuvassa")
			"tuuli":
				_check(lg._bub.get(lg.suntio, "").contains("Kuninkaan tuuli"), "Tapuli: kuninkaan tuuli")
			"gustavus":
				_check(lg._bub.get(lg.pekka, "").contains("GUSTAVUKSELLE"), "Tapuli: Pekka tarjoaa")
				_check(lg.cans.filter(func(c): return c.visible).size() >= 5, "Tapuli: tölkit käsissä")
				_check(inside.call(heads[4]) and inside.call(heads[5]) and inside.call(heads[3]), "Tapuli: Pekka, Arto ja suntio kuvassa")
			"otsikko2":
				_check(inside.call(_sp_sp(lg, main.world.tapuli_root.to_global(Vector3(0, 11.0, 0)))), "Tapuli: tapuli kokonaan otsikossa")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Tapuli jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("kuninkaan_tapuli", 0)), main._msg.text])
	_check(int(main.endings.counts.get("kuninkaan_tapuli", 0)) == 1, "Tapuli: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Tapuli: päiväkirjarivi")
	_check(main.walker_out.visible and main.suntio.visible and main.player.controls_enabled, "Tapuli: pelaaja ja suntio palasivat")
	_check(absf(main.world.tapuli_bell.rotation.x) < 0.001, "Tapuli: kello lepoon")
	var o: Array = main._talk_options("suntio").map(func(x): return x.id)
	_check("kuningas_muisto" in o, "Tapuli: suntiolle muistelukysymys")
	main._talk_who = "suntio"
	main._talk_kuningas("kuningas_muisto")
	await _frames(3)
	main._talk_box.close()


func _pakka(path: String) -> void:
	main.endings.counts.erase("pakkahuoneen_veistos")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.clock_min = 15 * 60
	main.pakkahuone = PakkahuoneLegenda.new()
	main.pakkahuone.heard = true
	main.pakkahuone.kuraattori = true
	main.pakkahuone.kirja = true
	main._retki_from = main.player.global_position
	main._enter_retki("pakkahuone")
	await _frames(10)
	var r = main.retki_int
	_check(not r._special.visible and r._footprint.visible, "Pakkahuone: jalusta tyhjä ennen, pölyssä jälki")
	var m0: float = main.maine
	r.walker.position = r.spots.luukku[0]
	await _frames(3)
	main._on_retki_acted("luukku")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is VeistosKohtaus)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Pakkahuone: museon hetki alkoi luukulta")
	if lg == null:
		return
	_check(main.pakkahuone.found and main.maine > m0, "Pakkahuone: löytö ja maine heti")
	_check(int(main.endings.counts.get("pakkahuoneen_veistos", 0)) == 0, "Pakkahuone: hetki kirjataan vasta lopuksi")
	_check(not r.walker.visible and not r._curator.visible, "Pakkahuone: oikea pelaaja ja kuraattori piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["avain", "luukku", 1.7], ["kansi", "luukku", 3.0], ["tulo", "luukku", 5.4], ["nosto", "laatikko", 1.6],
		["lattialle", "laatikko", 2.7], ["kansi_pois", "laatikko", 3.6], ["pyhimys_ylos", "laatikko", 4.7], ["pyyhkii", "laatikko", 5.8],
		["sinaolet", "laatikko", 7.0], ["kanto", "kanto", 1.4], ["kavijat", "kanto", 3.2], ["jalustalle", "kanto", 5.7],
		["saato", "kanto", 7.6], ["kyltti", "valo", 1.3], ["aurinko", "valo", 3.1], ["taputus", "valo", 4.4], ["yo", "valo", 6.3],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.6]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Pakkahuone: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var sp: Vector2 = _sp_sp(lg, lg.saint.to_global(Vector3(0, 0.3, 0)))
		var hs := [lg.me, lg.curator, lg.vis1, lg.vis2].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Pakkahuone %s: pyhimys %s, päät minä/kuraattori/kävijät %s" % [st[0], sp, hs])
		match st[0]:
			"avain":
				var d: float = lg.hand(lg.me).distance_to(lg.key.global_position + Vector3(0, 0.056, 0))  # avaimen rengas
				print("LEGENDA Pakkahuone avainkäsi reiästä %.3f m" % d)
				_check(lg.key.visible and d < 0.14, "Pakkahuone: pelaajan käsi avaimella")
				_check(inside.call(hs[0]) and inside.call(_sp_sp(lg, r.to_global(lg.HATCH))), "Pakkahuone: pelaaja ja luukku kuvassa")
			"kansi":
				_check(absf(r._lid.rotation_degrees.x) > 40.0, "Pakkahuone: kansi aukeaa")
			"tulo":
				_check(inside.call(hs[1]) and lg._bub.has(lg.curator), "Pakkahuone: kuraattori tuli luukulle")
			"nosto", "lattialle":
				var cp: Vector2 = _sp_sp(lg, lg.crate.global_position + Vector3(0, 0.15, 0))
				var dh: float = lg.hand(lg.curator).distance_to(lg.crate.to_global(Vector3(lg.CRATE.x / 2.0, lg.CRATE.y - 0.06, 0)))
				var dl: float = lg.hand(lg.curator, "_l").distance_to(lg.crate.to_global(Vector3(-lg.CRATE.x / 2.0, lg.CRATE.y - 0.06, 0)))
				print("LEGENDA Pakkahuone laatikon kahvat: oikea %.3f, vasen %.3f m" % [dh, dl])
				_check(inside.call(cp) and inside.call(hs[1]), "Pakkahuone: laatikko ja kuraattori kuvassa (%s)" % st[0])
				_check(minf(dh, dl) < 0.15, "Pakkahuone: kädet laatikolla (%s)" % st[0])
			"pyyhkii", "sinaolet":
				var top: Vector2 = _sp_sp(lg, lg.saint.to_global(Vector3(0, lg.SAINT_H, 0)))
				var bot: Vector2 = _sp_sp(lg, lg.saint.to_global(Vector3.ZERO))
				var hpx: float = (top - bot).length() * vs.y
				print("LEGENDA Pakkahuone pyhimys lähikuvassa %.0f px" % hpx)
				_check(inside.call(sp) and inside.call(hs[1]) and hpx > 200.0, "Pakkahuone: pyhimys isona ja kuraattorin kasvot (%s)" % st[0])
				if st[0] == "sinaolet":
					_check(lg._bub.get(lg.curator, "") == "Siinähän sinä olet.", "Pakkahuone: Siinähän sinä olet")
			"kanto", "kavijat":
				var dl2: float = lg.hand(lg.curator, "_l").distance_to(lg.saint.global_position + Vector3(0, 0.13, 0))
				var dr2: float = lg.hand(lg.curator).distance_to(lg.saint.global_position + Vector3(0, 0.13, 0))
				print("LEGENDA Pakkahuone kanto: kädet pyhimyksestä %.3f / %.3f m" % [dl2, dr2])
				_check(dl2 < 0.16 and dr2 < 0.16, "Pakkahuone: kuraattori kantaa pyhimystä käsissään (%s)" % st[0])
				_check(inside.call(sp) and inside.call(hs[1]), "Pakkahuone: pyhimys ja kuraattori kuvassa (%s)" % st[0])
				if st[0] == "kavijat":
					_check(inside.call(hs[2]) or inside.call(hs[3]), "Pakkahuone: kävijät kuvassa")
			"saato":
				var on: float = lg.saint.position.distance_to(lg.PED_AT + Vector3(0, lg.PED_H, 0))
				_check(lg.saint_placed and on < 0.01 and inside.call(sp) and inside.call(hs[1]), "Pakkahuone: pyhimys jalustalla ja kuraattori säätää")
			"kyltti":
				_check(lg.plate_turned and absf(lg._plate_rig.rotation.y) > 2.5 and inside.call(_sp_sp(lg, r.to_global(lg.PLATE))), "Pakkahuone: POISSA-kyltti käännetty kuvassa")
			"aurinko", "taputus":
				_check(lg._sun.light_energy > 1.0 and inside.call(sp), "Pakkahuone: aurinko pyhimyksessä (%s)" % st[0])
			"otsikko2":
				_check(inside.call(sp) and inside.call(hs[0]) and inside.call(hs[1]), "Pakkahuone: pyhimys, pelaaja ja kuraattori otsikossa")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Pakkahuone jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("pakkahuoneen_veistos", 0)), main._msg.text])
	_check(int(main.endings.counts.get("pakkahuoneen_veistos", 0)) == 1, "Pakkahuone: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Pakkahuone: päiväkirjarivi")
	_check(r.walker.visible and r._curator.visible and r.walker.controls_enabled and not r.staged, "Pakkahuone: pelaaja ja kuraattori palasivat")
	_check(r._special.visible and not r._footprint.visible and r._plate_on.visible and absf(r._lid.rotation_degrees.x) > 90.0,
		"Pakkahuone: pyhimys jäi jalustalle, luukku auki")
	r.walker.position = r.spots.veistos[0] + Vector3(-1.0, 0, 0.6)
	await _frames(3)
	await _shot(path, "jalkeen")
	main._on_retki_acted("kuraattori")
	await _frames(2)
	print("LEGENDA Pakkahuone muisto: '%s'" % r._bubble.text)
	_check(r._bubble.text in VeistosKohtaus.MUISTO, "Pakkahuone: kuraattori muistelee kantamista")


func _hanhi(path: String) -> void:
	main.endings.counts.erase("hanhikiven_rajakivi")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.clock_min = 17 * 60
	main.hanhikivi = HanhikiviLegenda.new()
	main.hanhikivi.heard = true
	main.hanhikivi.kapteeni = true
	main.hanhikivi.kyltti = true
	main._retki_from = main.player.global_position
	main._enter_retki("hanhikivi")
	await _frames(10)
	var r = main.retki_int
	_check(not r.feather.visible, "Hanhikivi: ei sulkaa ennen")
	var bm: MeshInstance3D = r.boulder
	var lowest := 9.0
	for v in bm.mesh.get_faces():
		lowest = minf(lowest, (bm.transform * v).y)
	print("LEGENDA Hanhikivi kiven alin kohta y %.3f, huippu %s" % [lowest, HanhikiviKohtaus.stone_top(r)])
	_check(lowest < 0.02, "Hanhikivi: kivi maassa, ei ilmassa")
	var m0: float = main.maine
	r.walker.position = r.spots.kivi[0]
	await _frames(3)
	main._on_retki_acted("kivi")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is HanhikiviKohtaus)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Hanhikivi: hetki alkoi kiveltä")
	if lg == null:
		return
	_check(main.hanhikivi.found and main.maine > m0, "Hanhikivi: löytö ja maine heti")
	_check(int(main.endings.counts.get("hanhikiven_rajakivi", 0)) == 0, "Hanhikivi: hetki kirjataan vasta lopuksi")
	_check(not r.walker.visible and not r._fisher.visible and not r.kuski.visible, "Hanhikivi: oikeat hahmot piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["kammen", "kivi", 1.8], ["alas", "kivi", 3.6], ["nousu", "kivi", 5.4], ["rantaan", "kuoppa", 2.0],
		["painauma", "kuoppa", 3.8], ["isa", "kuoppa", 5.0], ["kuka", "kuoppa", 6.0], ["eikukaan", "kuoppa", 7.2],
		["aura", "hanhet", 1.0], ["irtoaa", "hanhet", 2.6], ["liuku", "hanhet", 3.8], ["jarru", "hanhet", 4.7],
		["kivella", "hanhet", 5.6], ["huuto", "hanhet", 6.35], ["huuto2", "hanhet", 7.55], ["kuski", "kuski", 2.8],
		["kasi", "kuski", 4.2], ["lahto", "kuski", 5.4], ["sulka", "kuski", 6.4], ["hyva", "kuski", 7.8],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.6]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Hanhikivi: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var gp: Vector2 = _sp_sp(lg, lg.goose.global_position)
		var hs := [lg.me, lg.fisher, lg.kuski].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Hanhikivi %s: hanhi %s, päät minä/kalastaja/kuski %s" % [st[0], gp, hs])
		match st[0]:
			"kammen", "alas":
				var hl: Vector3 = r.to_local(lg.hand(lg.me, "_l"))
				var away := Vector3(hl.x - lg.STONE.x, 0, hl.z - lg.STONE.z).normalized() * 0.5
				var surf: Vector3 = r.to_global(HanhikiviKohtaus.stone_side(r, hl + away))
				var d: float = lg.hand(lg.me, "_l").distance_to(surf)
				print("LEGENDA Hanhikivi kämmen kiven pinnasta %.3f m" % d)
				_check(d < 0.1, "Hanhikivi: kämmen kiven kyljellä (%s)" % st[0])
				_check(inside.call(hs[0]), "Hanhikivi: pelaaja kuvassa (%s)" % st[0])
			"painauma", "isa", "kuka", "eikukaan":
				_check(inside.call(_sp_sp(lg, r.to_global(lg.HOLLOW))) and inside.call(hs[0]) and inside.call(hs[1]),
					"Hanhikivi: painauma, pelaaja ja kalastaja kuvassa (%s)" % st[0])
				if st[0] == "isa":
					_check(lg._bub.get(lg.fisher, "").contains("isä"), "Hanhikivi: kalastajan isä")
			"aura", "irtoaa", "liuku":
				var n := 0
				for g in lg.flock:
					if inside.call(_sp_sp(lg, g.global_position)):
						n += 1
				print("LEGENDA Hanhikivi aurasta kuvassa %d" % n)
				_check(n >= 3 or inside.call(gp), "Hanhikivi: aura tai laskeutuja kuvassa (%s)" % st[0])
			"kivella", "huuto", "huuto2":
				var feet: Vector3 = lg.goose.global_position - Vector3(0, lg.LEG_H * lg.GOOSE_S, 0)
				var dtop: float = feet.distance_to(r.to_global(lg.top))
				var hgt: float = (_sp_sp(lg, lg.goose.to_global(Vector3(0, 0.35, -0.25))) - _sp_sp(lg, lg.goose.to_global(Vector3(0, -0.27, 0)))).length() * vs.y
				print("LEGENDA Hanhikivi hanhi kivellä: jalat huipusta %.3f m, korkeus kuvassa %.0f px" % [dtop, hgt])
				_check(lg.goose_landed and dtop < 0.02, "Hanhikivi: hanhi kiven päällä (%s)" % st[0])
				_check(inside.call(gp) and hgt > 110.0, "Hanhikivi: hanhi isona kuvassa (%s)" % st[0])
			"kuski", "kasi":
				_check(inside.call(gp) and inside.call(hs[2]) and inside.call(hs[1]), "Hanhikivi: hanhi, kuski ja kalastaja kuvassa (%s)" % st[0])
			"hyva":
				_check(lg.feather_on_stone and lg._bub.get(lg.kuski, "").contains("hyvä"), "Hanhikivi: sulka kivellä ja ja hyvä niin")
			"otsikko2":
				_check(inside.call(hs[0]) and inside.call(hs[1]) and inside.call(hs[2]), "Hanhikivi: kolme miestä otsikossa")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Hanhikivi jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("hanhikiven_rajakivi", 0)), main._msg.text])
	_check(int(main.endings.counts.get("hanhikiven_rajakivi", 0)) == 1, "Hanhikivi: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Hanhikivi: päiväkirjarivi")
	_check(r.walker.visible and r._fisher.visible and r.kuski.visible and r.walker.controls_enabled and not r.busy, "Hanhikivi: hahmot palasivat")
	_check(r.feather.visible, "Hanhikivi: sulka jäi kivelle")
	r.walker.position = r.spots.kivi[0] + Vector3(1.4, 0, 0.6)
	await _frames(3)
	await _shot(path, "jalkeen")
	var heard := false
	r.walker.position = r.spots.onkija[0]
	await _frames(3)
	for i in 20:
		Input.action_press("interact")
		await _frames(1)
		Input.action_release("interact")
		await _frames(2)
		if r._bubble.text in HanhikiviKohtaus.MUISTO:
			heard = true
			break
	print("LEGENDA Hanhikivi muisto: '%s'" % r._bubble.text)
	_check(heard, "Hanhikivi: kalastaja muistelee hanhea")


func _kapseli(path: String) -> void:
	main.endings.counts.erase("peruskiven_kapseli")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.clock_min = 15 * 60
	main.peruskivi = PeruskiviLegenda.new()
	main.peruskivi.heard = true
	main.peruskivi.vartija = true
	main.peruskivi.kyltti = true
	main._retki_from = main.player.global_position
	main._enter_retki("rojuniemi")
	await _frames(10)
	var r = main.retki_int
	_check(not r.shelf_capsule.visible and not r._hole.visible, "Kapseli: laatta kiinni ennen")
	var m0: float = main.maine
	var raha0: float = main.money
	r.walker.position = r.spots.laatta[0]
	await _frames(3)
	main._on_retki_acted("laatta")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is KapseliKohtaus)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Kapseli: hetki alkoi laatalta")
	if lg == null:
		return
	_check(main.peruskivi.found and main.maine > m0 and main.money > raha0, "Kapseli: löytö, palkkio ja maine heti")
	_check(int(main.endings.counts.get("peruskiven_kapseli", 0)) == 0, "Kapseli: hetki kirjataan vasta lopuksi")
	_check(not r.walker.visible and not r._guard.visible and not r.kuski.visible, "Kapseli: oikeat hahmot piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["huomaa", "laatta", 1.6], ["nousee", "laatta", 3.4], ["poly", "laatta", 3.9], ["sivuun", "laatta", 5.0],
		["ai", "laatta", 6.6], ["tarttuu", "kapseli", 1.4], ["ylos", "kapseli", 1.9], ["kuusk", "kapseli", 3.6],
		["kierto", "kapseli", 4.6], ["kansi", "kapseli", 5.3], ["kolikko", "kapseli", 6.2], ["rulla", "kapseli", 7.3],
		["kirje", "kapseli", 8.4], ["lukee", "kirje", 1.2], ["lukee2", "kirje", 3.0], ["allekirjoitus", "kirje", 4.5],
		["kuka", "kirje", 5.6], ["tiesi", "kirje", 8.8], ["radio", "radio", 1.8], ["loyty", "radio", 3.0],
		["pilli", "radio", 4.6], ["kuski", "radio", 6.8], ["totta", "radio", 9.0], ["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.6]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Kapseli: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var cp: Vector2 = _sp_sp(lg, lg.capsule.global_position)
		var hs := [lg.me, lg.guard, lg.kuski].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Kapseli %s: kapseli %s, päät minä/vartija/kuski %s" % [st[0], cp, hs])
		match st[0]:
			"huomaa":
				_check(inside.call(hs[0]) and inside.call(hs[1]), "Kapseli: pelaaja ja vartija kuvassa (huomaa)")
			"nousee", "poly":
				var er: Vector3 = r.to_global(lg._slab_edge(0.24))
				var el: Vector3 = r.to_global(lg._slab_edge(-0.24))
				var dr: float = lg.hand(lg.me, "_r").distance_to(er)
				var dl: float = lg.hand(lg.me, "_l").distance_to(el)
				print("LEGENDA Kapseli kädet laatan reunasta o %.3f v %.3f m, kulma %.2f" % [dr, dl, lg._slab_a])
				_check(dr < 0.12 and dl < 0.12, "Kapseli: kädet laatan reunalla (%s)" % st[0])
				_check(lg._slab_a > 0.1, "Kapseli: laatta nousee (%s)" % st[0])
				_check(inside.call(hs[0]), "Kapseli: pelaaja kuvassa (%s)" % st[0])
			"ai":
				_check(inside.call(cp) and inside.call(hs[0]) and inside.call(hs[1]), "Kapseli: kapseli kolossa, pelaaja ja vartija kuvassa")
			"kuusk", "kierto", "kansi":
				var a: Vector2 = _sp_sp(lg, lg.capsule.global_position + lg._axis(lg.me) * 0.16)
				var b: Vector2 = _sp_sp(lg, lg.capsule.global_position - lg._axis(lg.me) * 0.16)
				var px: float = (a - b).length() * vs.y
				print("LEGENDA Kapseli kapselin pituus kuvassa %.0f px" % px)
				_check(px > 90.0 and inside.call(cp), "Kapseli: kapseli isona kuvassa (%s)" % st[0])
				_check(inside.call(hs[0]) and inside.call(hs[1]), "Kapseli: kasvot kuvassa (%s)" % st[0])
				if st[0] == "kansi":
					_check(lg.cap_off, "Kapseli: kansi irti")
			"kolikko":
				_check(lg.coin.visible, "Kapseli: kolikko näkyy")
			"rulla":
				_check(lg.roll.visible, "Kapseli: rulla esiin")
			"lukee", "lukee2":
				var lp: Vector2 = _sp_sp(lg, lg.letter.global_position)
				var top: Vector2 = _sp_sp(lg, lg.letter.to_global(Vector3(0, 0.115, 0)))
				var bot: Vector2 = _sp_sp(lg, lg.letter.to_global(Vector3(0, -0.115, 0)))
				var h: float = (top - bot).length() * vs.y
				print("LEGENDA Kapseli kirje kuvassa %.0f px" % h)
				_check(lg.letter.visible and inside.call(lp) and h > 250.0, "Kapseli: kirje luettavana (%s)" % st[0])
			"allekirjoitus", "kuka", "tiesi":
				_check(inside.call(hs[0]) and inside.call(hs[1]), "Kapseli: kasvot kuvassa (%s)" % st[0])
				if st[0] == "tiesi":
					_check(lg.letter_read and lg._bub.get(lg.guard, "").contains("tiesi"), "Kapseli: ne tiesi jo silloin")
			"radio", "loyty":
				_check(lg.radio.visible and inside.call(hs[1]), "Kapseli: vartija radiopuhelimen kanssa (%s)" % st[0])
				_check(lg._bub.get(lg.guard, "").contains("LÖYTY"), "Kapseli: kuulutus (%s)" % st[0])
			"pilli":
				_check(lg.whistled and lg._steam.emitting and inside.call(_sp_sp(lg, r.to_global(lg.WHISTLE))), "Kapseli: höyrypilli viheltää kuvassa")
			"kuski", "totta":
				_check(inside.call(hs[0]) and inside.call(hs[1]) and inside.call(hs[2]), "Kapseli: kolme kuvassa (%s)" % st[0])
				if st[0] == "totta":
					_check(lg._bub.get(lg.guard, "").contains("totta"), "Kapseli: ja nyt se on totta")
			"otsikko2":
				_check(inside.call(hs[0]) and inside.call(hs[1]) and inside.call(hs[2]) and inside.call(cp), "Kapseli: kolme ja kapseli otsikossa")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Kapseli jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("peruskiven_kapseli", 0)), main._msg.text])
	_check(int(main.endings.counts.get("peruskiven_kapseli", 0)) == 1, "Kapseli: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Kapseli: päiväkirjarivi")
	_check(r.walker.visible and r._guard.visible and r.kuski.visible and r.walker.controls_enabled and not r.busy, "Kapseli: hahmot palasivat")
	_check(r.shelf_capsule.visible and r._hole.visible and not r.staged, "Kapseli: kolo auki ja kapseli kopin ikkunalla")
	_check(r._slab.position.distance_to(r.SLAB_OPEN) < 0.01, "Kapseli: laatta sivussa")
	r.walker.position = r.spots.laatta[0] + Vector3(0.6, 0, 1.4)
	await _frames(3)
	await _shot(path, "jalkeen")
	var heard := false
	r.walker.position = r.spots.vartija[0]
	await _frames(3)
	for i in 20:
		Input.action_press("interact")
		await _frames(1)
		Input.action_release("interact")
		await _frames(2)
		if r._bubble.text in KapseliKohtaus.MUISTO:
			heard = true
			break
	print("LEGENDA Kapseli muisto: '%s'" % r._bubble.text)
	_check(heard, "Kapseli: vartija muistelee")


func _manamansalo(path: String) -> void:
	main.endings.counts.erase("manamansalon_kirkko")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.clock_min = 19 * 60 + 30
	main.manamansalo = ManamansaloLegenda.new()
	main.manamansalo.heard = true
	main.manamansalo.opas = true
	main.manamansalo.kyltti = true
	main._retki_from = main.player.global_position
	main._enter_retki("manamansalo")
	await _frames(10)
	var r = main.retki_int
	_check(not r._candle.visible and not r.lanterns[0].visible, "Manamansalo: kynttilä ja lyhdyt piilossa ennen")
	var m0: float = main.maine
	r.walker.position = r.spots.jaanteet[0]
	await _frames(3)
	main._on_retki_acted("jaanteet")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is ManamansaloKohtaus)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Manamansalo: hetki alkoi kivijalalta")
	if lg == null:
		return
	_check(main.manamansalo.found and main.maine > m0, "Manamansalo: löytö ja maine heti")
	_check(int(main.endings.counts.get("manamansalon_kirkko", 0)) == 0, "Manamansalo: hetki kirjataan vasta lopuksi")
	_check(not r.walker.visible and not r._guide.visible and not r.kuski.visible, "Manamansalo: oikeat hahmot piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.04 and v.x < 0.96 and v.y > 0.08 and v.y < 0.96
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var shots := [["kynttila", "kynttila", 1.2], ["kivella", "kynttila", 1.72], ["tikku", "kynttila", 3.0], ["sytyttaa", "kynttila", 3.9],
		["palaa", "kynttila", 5.0], ["opas", "kynttila", 8.6], ["alttari", "kulmat", 1.4], ["kierros", "kulmat", 3.9],
		["lasku", "kulmat", 5.45], ["kulmat", "kulmat", 10.2], ["nousee", "kirkko", 3.0], ["kirkko", "kirkko", 6.8],
		["haalistuu", "kirkko", 9.4], ["nakitte", "nimi", 1.8], ["kuolemansaari", "nimi", 5.0], ["tulkinta", "nimi", 8.4],
		["mummo", "nimi", 10.2], ["kiistella", "nimi", 11.8], ["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.6]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Manamansalo: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var cp: Vector2 = _sp_sp(lg, lg.candle.global_position)
		var hs := [lg.me, lg.opas, lg.kuski].map(func(c): return _sp_sp(lg, head.call(c)))
		print("LEGENDA Manamansalo %s: kynttilä %s, päät minä/opas/kuski %s" % [st[0], cp, hs])
		match st[0]:
			"kivella", "sytyttaa":
				var top: Vector2 = _sp_sp(lg, lg.candle.to_global(Vector3(0, 0.32, 0)))
				var bot: Vector2 = _sp_sp(lg, lg.candle.to_global(Vector3.ZERO))
				var px: float = (top - bot).length() * vs.y
				var d: float = lg.hand(lg.me, "_r").distance_to(r.to_global(r.CANDLE_AT + Vector3(0, 0.12, 0)))
				if st[0] == "sytyttaa":  # tikun liekki kynttilän sydämellä
					d = lg.match_stick.to_global(Vector3(0, 0.108, 0)).distance_to(r.to_global(r.CANDLE_AT + Vector3(0, 0.29, 0)))
				print("LEGENDA Manamansalo kynttilä kuvassa %.0f px, käsi/tikku kohteesta %.3f m" % [px, d])
				_check(px > 60.0 and inside.call(cp) and inside.call(hs[0]), "Manamansalo: kynttilä isona ja pelaaja kuvassa (%s)" % st[0])
				_check(d < (0.12 if st[0] == "kivella" else 0.06), "Manamansalo: käsi kynttilällä / tikku sydämellä (%s)" % st[0])
				if st[0] == "sytyttaa":
					_check(lg.match_stick.visible and (lg.match_stick.get_meta("flame") as Node3D).visible, "Manamansalo: tikku palaa")
			"palaa":
				_check(lg.lit and (lg.candle.get_meta("flame") as Node3D).visible, "Manamansalo: kynttilä palaa")
			"opas", "alttari":
				_check(inside.call(hs[0]) and inside.call(hs[1]) and inside.call(cp), "Manamansalo: pelaaja, opas ja kynttilä kuvassa (%s)" % st[0])
			"lasku":
				var hd: float = lg.hand(lg.opas, "_r").distance_to(lg.lanterns[1].global_position + Vector3(0, 0.36, 0))
				print("LEGENDA Manamansalo oppaan käsi lyhdyn kahvasta %.3f m" % hd)
				_check(hd < 0.1, "Manamansalo: opas pitää lyhtyä kahvasta")
			"kulmat":
				_check(lg.placed.count(true) == 4, "Manamansalo: neljä lyhtyä nurkissa")
				for i in 4:
					_check(inside.call(_sp_sp(lg, lg.lanterns[i].global_position)), "Manamansalo: lyhty %d kuvassa" % i)
			"nousee", "kirkko":
				_check(lg.ghost_alpha > 0.5 and lg.ghost > (0.3 if st[0] == "nousee" else 0.99), "Manamansalo: kirkko nousee (%s)" % st[0])
				var a: Vector2 = _sp_sp(lg, r.to_global(Vector3(lg.WALL.position.x, 0.3, -1.1)))
				var b: Vector2 = _sp_sp(lg, r.to_global(Vector3(lg.WALL.position.x + lg.WALL.size.x, 0.3, -1.1)))
				var px: float = ((a - b) * vs).length()
				print("LEGENDA Manamansalo kirkon leveys kuvassa %.0f px" % px)
				_check(px > 250.0 and inside.call(a) and inside.call(b), "Manamansalo: kirkko isona kuvassa (%s)" % st[0])
				if st[0] == "kirkko":
					var top: Vector2 = _sp_sp(lg, r.to_global(Vector3(lg.WALL.position.x - 0.05, 0.32 + lg.WALL_H + lg.ROOF_RISE + 0.76, -2.2)))
					_check(inside.call(top), "Manamansalo: risti kuvassa")
			"haalistuu":
				_check(lg.ghost_alpha < 0.8, "Manamansalo: kirkko haalistuu")
			"nakitte", "kuolemansaari", "tulkinta", "mummo", "kiistella":
				_check(inside.call(hs[0]) and inside.call(hs[1]) and inside.call(hs[2]), "Manamansalo: kolme kuvassa (%s)" % st[0])
				if st[0] == "kiistella":
					_check(lg._bub.get(lg.opas, "").contains("kiistellä"), "Manamansalo: siitä saa kiistellä")
				if st[0] == "nakitte":
					_check(lg.ghost_alpha < 0.01, "Manamansalo: kirkko poissa nimikiistassa")
			"otsikko2":
				_check(inside.call(hs[0]) and inside.call(hs[1]) and inside.call(hs[2]) and inside.call(cp), "Manamansalo: kolme ja kynttilä otsikossa")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Manamansalo jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("manamansalon_kirkko", 0)), main._msg.text])
	_check(int(main.endings.counts.get("manamansalon_kirkko", 0)) == 1, "Manamansalo: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Manamansalo: päiväkirjarivi")
	_check(r.walker.visible and r._guide.visible and r.kuski.visible and r.walker.controls_enabled and not r.busy, "Manamansalo: hahmot palasivat")
	_check(r._candle.visible and r.lanterns.all(func(l): return l.visible) and not r.staged, "Manamansalo: kynttilä ja lyhdyt jäivät palamaan")
	var cam := Camera3D.new()
	r.add_child(cam)
	cam.look_at_from_position(r.to_global(Vector3(9.0, 3.2, 4.2)), r.to_global(Vector3(9.0, 0.0, -2.2)))
	cam.fov = 45.0
	cam.make_current()
	main._hud.visible = false
	await _shot(path, "jalkeen")
	main._hud.visible = true
	cam.queue_free()
	var heard := false
	r.walker.position = r.spots.opas[0]
	await _frames(3)
	for i in 20:
		Input.action_press("interact")
		await _frames(1)
		Input.action_release("interact")
		await _frames(2)
		if r._bubble.text in ManamansaloKohtaus.MUISTO:
			heard = true
			break
	print("LEGENDA Manamansalo muisto: '%s'" % r._bubble.text)
	_check(heard, "Manamansalo: opas muistelee")


func _kanttori(path: String) -> void:
	main.endings.counts.erase("kanttorin_virsi")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 5
	main.clock_min = 19 * 60
	var k = main.kanttori
	for f in ["heard", "teinit", "savel", "harmooni", "arkisto"]:
		k.set(f, true)
	k.choice = ""
	await _frames(10)
	var opts0: Array = main._talk_options("sinikka").map(func(o): return o.id)
	_check("kanttori_kuoro" in opts0, "Kanttori: Sinikalle voi antaa nuotit")
	main._talk_who = "sinikka"
	main._talk_kanttori("kanttori_kuoro")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is KanttoriVirsi)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Kanttori: konsertti alkoi nuottien annosta")
	if lg == null:
		return
	_check(k.choice == "kuoro", "Kanttori: nuotit kuorolle")
	_check(int(main.endings.counts.get("kanttorin_virsi", 0)) == 0, "Kanttori: hetki kirjataan vasta lopuksi")
	_check(not main.player.visible, "Kanttori: oikea pelaaja piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.02 and v.x < 0.98 and v.y > 0.05 and v.y < 0.97
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var px := func(a: Vector3, b: Vector3) -> float: return (_sp_sp(lg, a) - _sp_sp(lg, b)).length() * vs.x
	var shots := [["sali", "sali", 1.5], ["esittely", "sali", 4.0], ["laulu", "laulu", 2.0], ["hilkka", "laulu", 5.6],
		["kansi", "harmooni", 0.8], ["koskettimet", "harmooni", 2.4], ["vilkaisu", "harmooni", 4.2], ["kanttori", "harmooni", 5.4],
		["aamen", "aamen", 1.0], ["katkaisu", "aamen", 3.0], ["ikkuna", "aamen", 4.0], ["vaiennut", "aamen", 6.3],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.2]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Kanttori: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var choir_heads: Array = lg.choir.map(func(c): return _sp_sp(lg, head.call(c)))
		var aud_heads: Array = [lg.annaliisa, lg.hilkka, lg.me, lg.pekka, lg.arto, lg.tauno].map(func(c): return _sp_sp(lg, head.call(c)))
		var sh: Vector2 = _sp_sp(lg, head.call(lg.sinikka))
		var hp: Vector2 = _sp_sp(lg, lg.harmooni.global_position + Vector3(0, 0.8, 0))
		print("LEGENDA Kanttori %s: kuoro %s, yleisö %s, Sinikka %s, harmooni %s, kansi %.2f, painetut %s, kajo %.2f" % [st[0],
			choir_heads, aud_heads, sh, hp, lg.lid_open, lg.pressed, lg.window_glow])
		match st[0]:
			"sali":
				_check(choir_heads.all(func(h): return inside.call(h)) and inside.call(sh) and inside.call(hp), "Kanttori: kuoro, Sinikka ja harmooni kuvassa")
				var worst := 0.0
				for c: Node3D in lg.choir:
					worst = maxf(worst, lg.folder_gap(c))
				print("LEGENDA Kanttori kansiot: käsi kansion reunasta enintään %.3f m" % worst)
				_check(worst < 0.07, "Kanttori: kuorolaisten kädet kansioilla")
			"laulu":
				_check(choir_heads.all(func(h): return inside.call(h)), "Kanttori: kuoron kasvot kuvassa")
				var hand: Vector3 = lg._hand_of(lg.sinikka, "r")
				var shoulder: Vector3 = lg.sinikka.to_global(lg.sinikka.bone_position("upperarm_r"))
				print("LEGENDA Kanttori johto: käsi %.2f m olan yllä" % (hand.y - shoulder.y))
				_check(hand.y > shoulder.y - 0.2 and inside.call(_sp_sp(lg, hand)), "Kanttori: Sinikka johtaa kädet ylhäällä")
			"hilkka":
				var hd: float = lg._hand_of(lg.hilkka, "r").distance_to(head.call(lg.hilkka))
				print("LEGENDA Kanttori Hilkka: käsi päästä %.3f m" % hd)
				_check(inside.call(aud_heads[1]) and hd < 0.2, "Kanttori: Hilkka pyyhkii silmää")
			"kansi":
				_check(lg.lid_open > 0.5, "Kanttori: harmoonin kansi aukeaa")
				var hw: float = px.call(lg.harmooni.to_global(Vector3(-0.5, 0.75, -0.15)), lg.harmooni.to_global(Vector3(0.5, 0.75, -0.15)))
				print("LEGENDA Kanttori koskettimisto %.0f px" % hw)
				_check(hw > 500.0, "Kanttori: koskettimisto isona (%.0f px)" % hw)
			"koskettimet":
				_check(not lg.pressed.is_empty(), "Kanttori: koskettimet painuvat itsestään")
				var low := false
				for kk: Array in lg._keys:
					if int(kk[2]) in lg.pressed and (kk[0] as Node3D).position.y < float(kk[1]) - 0.005:
						low = true
				_check(low, "Kanttori: painettu kosketin alhaalla")
			"vilkaisu":
				_check(inside.call(aud_heads[1]) and inside.call(aud_heads[0]), "Kanttori: Hilkka ja Anna-Liisa kuvassa (kääntyvät)")
			"kanttori":
				var to_cam: Vector3 = lg._cam.global_position - lg.sinikka.global_position
				var facing: float = (-lg.sinikka.global_basis.z).normalized().dot(Vector3(to_cam.x, 0, to_cam.z).normalized())
				print("LEGENDA Kanttori Sinikka kameraan päin %.2f" % facing)
				_check(inside.call(sh) and facing > 0.3, "Kanttori: Sinikan kasvot harmooniin päin kuvassa")
			"katkaisu":
				_check(lg.cut_off and lg.lid_open < 1.0 and lg.pressed.is_empty(), "Kanttori: katkaisu, kansi laskeutuu")
			"ikkuna":
				var wp: Vector2 = _sp_sp(lg, lg.window_point())
				_check(lg.window_glow > 0.8 and inside.call(wp), "Kanttori: Kanttorilan ikkuna hehkuu kuvassa")
			"vaiennut":
				_check(lg.window_glow < 0.05, "Kanttori: ikkunan kajo sammui")
			"otsikko2":
				_check(choir_heads.all(func(h): return inside.call(h)) and inside.call(sh), "Kanttori: kuoro ja Sinikka kuvassa (otsikko)")
				_check(aud_heads.all(func(h): return inside.call(h)), "Kanttori: eturivi kuvassa (otsikko)")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Kanttori jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("kanttorin_virsi", 0)), main._msg.text])
	_check(int(main.endings.counts.get("kanttorin_virsi", 0)) == 1, "Kanttori: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Kanttori: päiväkirjarivi")
	_check(main.player.visible and main.player.controls_enabled, "Kanttori: pelaaja ohjaa taas")
	_check(main.kirppis_int.walker.visible and main.kirppis_int._groups[main.kirppis_int.mode].visible, "Kanttori: sali palasi ennalleen")
	_check(not main._kt_player.playing, "Kanttori: yösävel ei soi")
	var opts: Array = main._talk_options("sinikka").map(func(o): return o.id)
	_check("kanttori_muisto" in opts, "Kanttori: Sinikalle muistelukysymys")
	main._talk_who = "sinikka"
	main._talk_kanttori("kanttori_muisto")
	await _frames(3)


func _ukko_vapaa(path: String) -> void:
	main.endings.counts.erase("ukko_vapaa")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.day = 4
	main.clock_min = 20 * 60 + 30
	var u = main.ukko
	u.heard = true
	u.siimat = 2
	u.lusikka = true
	u.caught = true
	u.choice = ""
	main._ukko_day = main.day
	var sp: Array = main._kala_spot("tekojarvi")
	_check(not sp.is_empty(), "Ukko vapaa: kalapaikka löytyy")
	if sp.is_empty():
		return
	main.walker_out.global_position = sp[0] + Vector3(0, 0.3, 0)
	await _frames(20)
	print("LEGENDA Ukko vapaa: vihje '%s'" % main._hint.text)
	_check(main._hint.text.contains("takaisin järveen"), "Ukko vapaa: vapautusvihje rannalla")
	_check(main._ukko_rauniot != null, "Ukko vapaa: ladon rauniot järvessä")
	await main.get_tree().process_frame
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is UkkoVapaa)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Ukko vapaa: rannan hetki alkoi vapautuksesta")
	if lg == null:
		return
	_check(u.choice == "vapaa", "Ukko vapaa: valinta kirjattiin heti")
	_check(int(main.endings.counts.get("ukko_vapaa", 0)) == 0, "Ukko vapaa: hetki kirjataan vasta lopuksi")
	_check(not main.walker_out.visible, "Ukko vapaa: oikea pelaaja piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.03 and v.x < 0.97 and v.y > 0.06 and v.y < 0.97
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	print("LEGENDA Ukko vapaa: vesiraja %.1f m, rauniot %.1f m rannasta" % [lg.edge, (lg.ruins_c - lg.spot).length()])
	var shots := [["ranta", "ranta", 0.6], ["tauno", "ranta", 3.8], ["paastan", "ranta", 6.0], ["kurotus", "lusikka", 1.4],
		["lusikka", "lusikka", 3.6], ["loput", "lusikka", 5.4], ["laiskaus", "vapaa", 1.45], ["vana", "vapaa", 3.6],
		["vana2", "vapaa", 6.2], ["hyppy", "hyppy", 1.5], ["roiske", "hyppy", 2.25], ["vilkutus", "hyppy", 4.2],
		["kaato", "kahvit", 1.8], ["ojennus", "kahvit", 3.45], ["juonti", "kahvit", 6.6], ["otsikko", "otsikko", 0.5],
		["otsikko2", "otsikko", 3.0]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Ukko vapaa: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var snout: Vector2 = _sp_sp(lg, lg._pike_pt(1.0))
		var tail: Vector2 = _sp_sp(lg, lg._pike_pt(0.0))
		var hm: Vector2 = _sp_sp(lg, head.call(lg.me))
		var ht: Vector2 = _sp_sp(lg, head.call(lg.tauno))
		print("LEGENDA Ukko vapaa %s: kuono %s pyrstö %s (%.0f px), päät minä %s tauno %s, rauniot %s" % [st[0], snout, tail,
			((snout - tail) * vs).length(), hm, ht, _sp_sp(lg, lg.ruins_c)])
		match st[0]:
			"ranta", "paastan", "kurotus":
				_check(inside.call(snout) and inside.call(tail), "Ukko vapaa: Ukko vedessä kuvassa (%s)" % st[0])
				_check(((snout - tail) * vs).length() > 220.0, "Ukko vapaa: Ukko isona (%s)" % st[0])
				_check(inside.call(hm), "Ukko vapaa: pelaaja kuvassa (%s)" % st[0])
				var gaps: Array = []
				for uu in lg.HOLD_U:
					var pt: Vector3 = lg.grip_pt(uu)
					gaps.append(minf(lg._hand(lg.me, "_r").distance_to(pt), lg._hand(lg.me, "_l").distance_to(pt)))
				var shd: Array = []
				for sd in ["_r", "_l"]:
					var shg: Vector3 = lg.me.to_global(lg.me.bone_position("upperarm" + sd))
					var wr: Vector3 = lg.me.to_global(lg.me.bone_position("hand" + sd))
					shd.append([snappedf(shg.distance_to(lg.grip_pt(lg.HOLD_U[0])), 0.01), snappedf(shg.distance_to(lg.grip_pt(lg.HOLD_U[1])), 0.01), snappedf(shg.distance_to(wr), 0.01)])
				print("LEGENDA Ukko vapaa kädet kyljellä %s, olka->otteet/ranne %s" % [gaps, shd])
				_check(gaps.all(func(g): return g < 0.1), "Ukko vapaa: kädet Ukon kyljellä (%s)" % st[0])
				var wy: float = lg._water_y(lg.pike.global_position)
				print("LEGENDA Ukko vapaa selkä %.3f vatsa %.3f vedestä" % [lg._pike_pt(0.6, 1.0).y - wy, lg._pike_pt(0.6, -1.0).y - wy])
				_check(lg._pike_pt(0.6, 1.0).y > wy and lg._pike_pt(0.6, -1.0).y < wy, "Ukko vapaa: Ukko puoliksi vedessä")
			"tauno":
				_check(inside.call(ht), "Ukko vapaa: Tauno tulee rantaa pitkin (kuvassa)")
				var td: float = lg.thermos.global_position.distance_to(lg._hand(lg.tauno, "_l"))
				print("LEGENDA Ukko vapaa termari kädestä %.3f m" % td)
				_check(td < 0.2, "Ukko vapaa: termari Taunon kädessä")
		match st[0]:
			"kurotus":
				var hd: float = lg._hand(lg.tauno, "_r").distance_to(lg.lure_isa.global_position)
				print("LEGENDA Ukko vapaa Taunon käsi lusikasta %.3f m" % hd)
				_check(hd < 0.1, "Ukko vapaa: Taunon käsi isän lusikalla")
				_check(inside.call(ht), "Ukko vapaa: Tauno kuvassa kurottaessa")
			"lusikka", "loput":
				var l0: Vector2 = _sp_sp(lg, lg.lure_isa.global_position)
				var l1: Vector2 = _sp_sp(lg, lg.lure_isa.global_position + lg.lure_isa.global_basis.y * 0.06)
				print("LEGENDA Ukko vapaa lusikka %.0f px" % ((l1 - l0) * vs).length())
				_check(lg.spoon_taken and inside.call(l0) and ((l1 - l0) * vs).length() > 40.0, "Ukko vapaa: isän lusikka isona Taunon kädessä")
				_check(inside.call(ht), "Ukko vapaa: Taunon kasvot kuvassa")
			"laiskaus":
				_check(lg._drops.size() > 4, "Ukko vapaa: pyrstön roiske")
				_check(inside.call(tail), "Ukko vapaa: pyrstö kuvassa")
			"vana", "vana2":
				var pp: Vector2 = _sp_sp(lg, lg.pike.global_position)
				_check(inside.call(pp) and inside.call(_sp_sp(lg, lg.ruins_c)), "Ukko vapaa: Ukko ja rauniot kuvassa (%s)" % st[0])
				_check(lg._rings.size() > 2, "Ukko vapaa: vanavesi (%s)" % st[0])
				_check(inside.call(hm) and inside.call(ht), "Ukko vapaa: hahmot kuvassa (%s)" % st[0])
			"hyppy":
				var wy2: float = lg._water_y(lg.pike.global_position)
				print("LEGENDA Ukko vapaa hyppy: korkeus %.2f m, pituus %.0f px" % [lg.pike.global_position.y - wy2, ((snout - tail) * vs).length()])
				_check(lg.jumped and lg.pike.visible and lg.pike.global_position.y - wy2 > 0.6, "Ukko vapaa: Ukko ilmassa")
				_check(inside.call(snout) and inside.call(tail), "Ukko vapaa: hyppy kuvassa")
				_check(((snout - tail) * vs).length() > 90.0, "Ukko vapaa: hyppy erottuu")
			"roiske":
				_check(lg._drops.size() > 10 and lg._rings.size() > 0, "Ukko vapaa: roiske ja rengas raunioilla")
			"vilkutus":
				_check(inside.call(ht) and inside.call(_sp_sp(lg, lg._hand(lg.tauno, "_r"))), "Ukko vapaa: Tauno vilkuttaa kuvassa")
				_check(lg._hand(lg.tauno, "_r").y > head.call(lg.tauno).y, "Ukko vapaa: käsi ylhäällä")
			"kaato":
				_check(lg._stream.visible and lg.poured > 0.2, "Ukko vapaa: kahvia kaadetaan")
				_check(lg.mug.global_position.distance_to(lg._hand(lg.tauno, "_l")) < 0.12, "Ukko vapaa: muki Taunon kädessä")
				_check(inside.call(hm) and inside.call(ht) and inside.call(_sp_sp(lg, lg.mug.global_position)), "Ukko vapaa: kaato kuvassa")
			"ojennus", "juonti":
				var md: float = lg.mug.global_position.distance_to(lg._hand(lg.me, "_r"))
				print("LEGENDA Ukko vapaa muki pelaajan kädestä %.3f m (%s)" % [md, st[0]])
				_check(lg.mug_given and md < 0.12, "Ukko vapaa: muki pelaajan kädessä (%s)" % st[0])
				_check(inside.call(hm) and inside.call(ht), "Ukko vapaa: molemmat kuvassa (%s)" % st[0])
				if st[0] == "juonti":
					_check(lg._steam.size() > 2, "Ukko vapaa: kahvi höyryää")
			"otsikko2":
				_check(inside.call(hm) and inside.call(ht) and inside.call(_sp_sp(lg, lg.ruins_c)), "Ukko vapaa: hahmot ja rauniot otsikossa")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Ukko vapaa jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("ukko_vapaa", 0)), main._msg.text])
	_check(int(main.endings.counts.get("ukko_vapaa", 0)) == 1, "Ukko vapaa: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Ukko vapaa: päiväkirjarivi")
	_check(main.walker_out.visible and main.player.controls_enabled, "Ukko vapaa: pelaaja ohjaa taas")
	_check(is_instance_valid(main._ukko_rauniot), "Ukko vapaa: rauniot jäävät järveen")
	main.kirppis_int.mode = "kirppis"
	var o: Array = main._talk_options("tauno").map(func(x): return x.id)
	_check("ukko_vapaa_muisto" in o, "Ukko vapaa: Taunolle muistelukysymys")
	main._talk_who = "tauno"
	main._talk_kirppis("ukko_vapaa_muisto")
	await _frames(3)
	print("LEGENDA Ukko vapaa muisto: vaihtoehdot %s" % [o])


func _drakkar(path: String) -> void:
	main.endings.counts.erase("drakkar")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.drakkar_found = false
	main.drakkar = 0
	main.drakkar_day = -1
	main.money = 30.0
	main.day = 3
	main.clock_min = 12 * 60
	main._enter_kirppis("kirppis")
	await _frames(12)
	main._talk_who = "raili"
	main._talk_kirppis("osta_drakkar")
	var lg: CanvasLayer = null
	for i in 60:
		var ls: Array = main.get_children().filter(func(c): return c is DrakkarKohtaus)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	_check(lg != null, "Drakkar: hetki alkoi ostosta")
	if lg == null:
		return
	_check(main.drakkar == main.DRAKKAR_SPRAYS, "Drakkar: pullo taskussa heti")
	_check(int(main.endings.counts.get("drakkar", 0)) == 0, "Drakkar: hetki kirjataan vasta lopuksi")
	_check(not main.kirppis_int.walker.visible, "Drakkar: salin kävelijä piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.02 and v.x < 0.98 and v.y > 0.05 and v.y < 0.97
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var px := func(a: Vector3, b: Vector3) -> float: return (_sp_sp(lg, a) - _sp_sp(lg, b)).length() * vs.x
	var shots := [["pullo", "pullo", 1.9], ["ojennus", "pullo", 2.9], ["katsoo", "pullo", 5.2], ["kaulalle", "suihku", 1.0],
		["pssst", "suihku", 1.6], ["haistaa", "suihku", 3.6], ["pilvi", "pilvi", 1.2], ["leyhytys", "pilvi", 2.4],
		["aivastus", "pilvi", 4.4], ["tauno", "pilvi", 6.8], ["tie", "kyla", 1.0], ["sinikka", "kyla", 3.0], ["pekka", "kyla", 5.4],
		["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.4]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Drakkar: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var hs: Array = [lg.raili, lg.me, lg.annaliisa, lg.hilkka, lg.tauno].map(func(c): return _sp_sp(lg, head.call(c)))
		var bp: Vector2 = _sp_sp(lg, lg.bottle.global_position + Vector3(0, 0.1, 0))
		var puffs := 0
		for p in lg._hall_puffs + lg._out_puffs:
			if p.visible:
				puffs += 1
		print("LEGENDA Drakkar %s: päät %s, pullo %s, pilvi %.1f m (%d hiukkasta), reagoineet %d, Railin käsi pullosta %.3f, oma %.3f" % [st[0],
			hs, bp, lg.cloud_r, puffs, lg.reacted.size(), lg.bottle_gap(lg.raili), lg.bottle_gap(lg.me)])
		match st[0]:
			"pullo":
				_check(inside.call(hs[0]) and inside.call(hs[1]) and inside.call(bp), "Drakkar: Raili, pelaaja ja pullo kuvassa")
				_check(lg.bottle_gap(lg.raili) < 0.07, "Drakkar: Railin käsi pullolla")
				var bh: float = px.call(lg.bottle.global_position, lg.bottle.global_position + Vector3(0, 0.2, 0))
				print("LEGENDA Drakkar pullo %.0f px" % bh)
				_check(bh > 40.0, "Drakkar: pullo näkyy (%.0f px)" % bh)
			"ojennus":
				_check(lg.bottle_gap(lg.me) < 0.07, "Drakkar: pelaajan käsi pullolla")
			"katsoo":
				_check(lg.bottle_holder == "me" and lg.bottle_gap(lg.me) < 0.07 and inside.call(bp), "Drakkar: pullo pelaajan kädessä kuvassa")
			"pssst":
				_check(lg.sprayed and puffs >= 6, "Drakkar: suihkaus pöllähtää (%d hiukkasta)" % puffs)
			"haistaa":
				_check(inside.call(hs[0]) and lg._bub.has(lg.raili), "Drakkar: Raili haistaa ja muistaa")
			"pilvi":
				_check(hs.all(func(h): return inside.call(h)), "Drakkar: kaikki salissa kuvassa")
			"leyhytys":
				_check(lg.reacted.has(lg.annaliisa) and lg._bub.has(lg.annaliisa), "Drakkar: Anna-Liisa leyhyttää, kun pilvi tulee")
				var hd: float = lg._hand(lg.annaliisa, "r").distance_to(head.call(lg.annaliisa))
				print("LEGENDA Drakkar Anna-Liisan käsi päästä %.2f m" % hd)
				_check(hd < 0.3, "Drakkar: Anna-Liisan käsi kasvojen edessä")
			"aivastus":
				_check(lg.reacted.has(lg.hilkka) and lg.reacted.has(lg.tauno), "Drakkar: pilvi saavutti Hilkan ja Taunon")
				var dh: float = Vector2(lg.hilkka.position.x - lg.ME_AT.x, lg.hilkka.position.z - lg.ME_AT.z).length()
				_check(absf(float(lg.reacted[lg.hilkka]) - (dh - 0.6) / lg.CLOUD_SPEED) < 0.1, "Drakkar: Hilkka reagoi, kun reuna on kohdalla")
			"tauno":
				var th: Vector3 = head.call(lg.tauno)
				var hd: float = lg._hand(lg.tauno, "r").distance_to(th)
				print("LEGENDA Drakkar Taunon käsi päästä %.2f m" % hd)
				_check(inside.call(hs[4]) and hd < 0.22, "Drakkar: Tauno sipaisee tukkaa kuvassa")
			"sinikka":
				var sh: Vector2 = _sp_sp(lg, head.call(lg.sinikka))
				var door: Vector2 = _sp_sp(lg, main.world.seura_kuisti.global_position + Vector3(0, 1.4, 0))
				_check(inside.call(sh) and inside.call(door), "Drakkar: Sinikka ja seuraintalon ovi kuvassa")
				_check(puffs >= 15, "Drakkar: pilvi valuu ovesta (%d hiukkasta)" % puffs)
			"pekka":
				_check(inside.call(_sp_sp(lg, head.call(lg.pekka))) and lg._bub.has(lg.pekka), "Drakkar: Pekka kuvassa ja haistaa")
			"otsikko2":
				_check(hs.all(func(h): return inside.call(h)), "Drakkar: kaikki kuvassa (otsikko)")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Drakkar jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("drakkar", 0)), main._msg.text])
	_check(int(main.endings.counts.get("drakkar", 0)) == 1, "Drakkar: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Drakkar: päiväkirjarivi")
	_check(main.kirppis_int.walker.visible and main.kirppis_int.walker.controls_enabled, "Drakkar: kävelijä ohjaa taas")
	_check(main.kirppis_int._groups.kirppis.visible and not main.kirppis_int.drakkar.visible, "Drakkar: sali ennallaan, pullo pois pöydältä")
	var ri: int = main.kirppis_int.person_index("raili")
	_check(ri >= 0 and main.kirppis_int._holders[ri].visible, "Drakkar: oikea Raili palasi")
	main._on_kirppis_exited()
	await _frames(3)
	main._enter_kirppis("kirppis")
	await _frames(3)
	var rb: String = main.kirppis_int._bubbles[main.kirppis_int._people[ri]].text
	print("LEGENDA Drakkar muisto: '%s'" % rb)
	_check(rb in DrakkarKohtaus.MUISTO, "Drakkar: Raili muistelee")
	main._on_kirppis_exited()


func _kinkku(path: String) -> void:
	main.endings.counts.erase("kinkku")
	if main.player == main.bike:
		main._toggle_mount()
	main._note.visible = false
	main.money = 30.0
	main.day = 1
	main.clock_min = 18 * 60 + 30
	main._bingo_day = -1
	main.bingo_jackpot = 1.0
	main._enter_kirppis("bingo")
	await _frames(12)
	main._start_bingo()
	var bg: Node = null
	for i in 30:
		var ls: Array = main.kirppis_int.get_children().filter(func(c): return c is BingoGame)
		if not ls.is_empty():
			bg = ls.front()
			break
		await _frames(1)
	_check(bg != null, "Kinkku: bingo alkoi")
	if bg == null:
		return
	await _frames(5)
	bg._end(true)
	var lg: CanvasLayer = null
	for i in 400:
		var ls: Array = main.get_children().filter(func(c): return c is KinkkuKohtaus)
		if not ls.is_empty():
			lg = ls.front()
			break
		await _frames(1)
	main.bingo_jackpot = 0.15
	_check(lg != null, "Kinkku: jättipotti aloitti hetken")
	if lg == null:
		return
	_check(int(main.endings.counts.get("kinkku", 0)) == 0, "Kinkku: hetki kirjataan vasta lopuksi")
	_check(not main.kirppis_int.walker.visible, "Kinkku: salin kävelijä piilossa")
	var head := func(c: Node3D) -> Vector3: return c.to_global(c.bone_position("Head"))
	var inside := func(v: Vector2) -> bool: return v.x > 0.02 and v.x < 0.98 and v.y > 0.05 and v.y < 0.97
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var px := func(a: Vector3, b: Vector3) -> float: return (_sp_sp(lg, a) - _sp_sp(lg, b)).length() * vs.x
	var shots := [["istuu", "bingo", 0.2], ["bingo", "bingo", 1.6], ["tarkistetaan", "bingo", 3.4], ["tulee", "tarkistus", 1.2],
		["lappu", "tarkistus", 4.4], ["bingo_on", "tarkistus", 7.0], ["kyna", "tarkistus", 7.18], ["kanto", "kinkku", 2.0],
		["luovutus", "kinkku", 3.3], ["sylissa", "kinkku", 5.8], ["puuska", "mummot", 3.0], ["tauno", "mummot", 6.2],
		["hmph", "mummot", 7.9], ["otsikko", "otsikko", 1.0], ["otsikko2", "otsikko", 3.4]]
	for st: Array in shots:
		if not await _sp_wait(lg, st[1], st[2]):
			_check(false, "Kinkku: vaihe %s/%s" % [st[1], st[0]])
			continue
		await _shot(path, st[0])
		var rh: Array = lg.row.map(func(c): return _sp_sp(lg, head.call(c)))
		var mh: Vector2 = _sp_sp(lg, head.call(lg.me))
		var kp: Vector2 = _sp_sp(lg, lg.kinkku.global_position + Vector3(0, 0.1, 0))
		print("LEGENDA Kinkku %s: rivi %s, pelaaja %s, kinkku %s (%s), lappu %s, vati käsistä %.3f" % [st[0], rh, mh, kp, lg.kinkku_holder,
			lg.slip_holder, lg.tray_gap(lg.me) if lg.kinkku_holder == "me" else lg.tray_gap(lg.raili) if lg.kinkku_holder == "raili" else -1.0])
		match st[0]:
			"bingo":
				_check(rh.all(func(h): return inside.call(h)) and inside.call(mh), "Kinkku: mummot ja pelaaja kuvassa")
				var sp: Vector3 = lg.slip.global_position
				_check(sp.y > head.call(lg.me).y - 0.1 and inside.call(_sp_sp(lg, sp)), "Kinkku: lappu ylhäällä kuvassa")
			"lappu":
				var sw: float = px.call(lg.slip.to_global(Vector3(-0.1, 0, 0)), lg.slip.to_global(Vector3(0.1, 0, 0)))
				print("LEGENDA Kinkku lappu %.0f px, luetaan %d" % [sw, lg.reading])
				_check(sw > 400.0 and lg.reading >= 2, "Kinkku: lappu lähikuvassa (%.0f px)" % sw)
				var gap: float = lg._hand(lg.erkki, "r").distance_to(lg.slip.global_position)
				_check(gap < 0.16, "Kinkku: lappu Erkin käsissä (%.2f m)" % gap)
			"kyna":
				var pg: float = lg._hand(lg.elvi, "r").distance_to(lg.pencil_a.global_position)
				print("LEGENDA Kinkku kynä kädestä %.3f m" % pg)
				_check(lg.snapped and pg < 0.1 and inside.call(rh[2]) and inside.call(_sp_sp(lg, lg.pencil_a.global_position)), "Kinkku: Elvin kynä katkeaa käsissä kuvassa")
			"luovutus":
				_check(inside.call(kp) and inside.call(mh) and inside.call(_sp_sp(lg, head.call(lg.raili))), "Kinkku: Raili, kinkku ja pelaaja kuvassa")
			"sylissa":
				_check(lg.kinkku_holder == "me" and lg.tray_gap(lg.me) < 0.06, "Kinkku: kädet vadin alla")
				var kw: float = px.call(lg.kinkku.to_global(Vector3(-0.3, 0.1, 0)), lg.kinkku.to_global(Vector3(0.3, 0.1, 0)))
				print("LEGENDA Kinkku kinkku %.0f px" % kw)
				_check(kw > 250.0 and inside.call(kp) and inside.call(mh), "Kinkku: kinkku isona ja pelaajan kasvot kuvassa (%.0f px)" % kw)
			"puuska":
				_check(rh.all(func(h): return inside.call(h)), "Kinkku: mummot kuvassa")
				_check(lg._bub.size() >= 1, "Kinkku: mummot sanovat sanansa")
			"hmph":
				_check(lg.turned_away, "Kinkku: mummot kääntävät selkänsä")
			"otsikko2":
				_check(inside.call(mh) and inside.call(kp) and rh.all(func(h): return inside.call(h)), "Kinkku: pelaaja, kinkku ja mummot kuvassa (otsikko)")
	for i in 900:
		if not is_instance_valid(lg):
			break
		await _frames(1)
	await _frames(10)
	print("LEGENDA Kinkku jälkeen: kerrat %d, viesti '%s'" % [int(main.endings.counts.get("kinkku", 0)), main._msg.text])
	_check(int(main.endings.counts.get("kinkku", 0)) == 1, "Kinkku: hetki kirjattiin")
	_check(main._msg.text.contains("uusi tarina"), "Kinkku: päiväkirjarivi")
	_check(main.kirppis_int.walker.visible and main.kirppis_int.walker.controls_enabled, "Kinkku: kävelijä ohjaa taas")
	_check(main.kirppis_int._groups.bingo.visible, "Kinkku: sali ennallaan")
	main._on_kirppis_exited()
	await _frames(3)
	main._enter_kirppis("bingo")
	await _frames(3)
	var hi: int = main.kirppis_int.person_index("hilkka")
	var hb: String = main.kirppis_int._bubbles[main.kirppis_int._people[hi]].text
	print("LEGENDA Kinkku muisto: '%s'" % hb)
	_check(hb in KinkkuKohtaus.MUISTO, "Kinkku: Hilkka muistelee")
	main._on_kirppis_exited()
