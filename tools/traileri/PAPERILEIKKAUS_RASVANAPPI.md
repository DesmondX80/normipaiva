# Paperileikkaus: uusien ominaisuuksien traileri Saloisten Saapasjalkojen "Rasvanappi"-biisin tahtiin (2:53)

Luonnos hyväksyttäväksi ennen koodia ([OHJEET.md](OHJEET.md) Työtapa, kohta 2). Pohjana ensimmäinen traileri
([PAPERILEIKKAUS.md](PAPERILEIKKAUS.md)), mutta sisältö on **uudet ominaisuudet**: huumekauppa ja sen riskit,
auton varastus ja tähtijahti, Päivin motkotukset, kolmiomittaus lahjoineen sekä uusi Vaala.

**Minipeliä ei näytetä suoraan.** Rasvanapin pelitilanne (kontaten tökkiminen pimeässä, kermavaahto) ei ole kuvassa.
Sen ympärys näytetään selkeästi: portsari ja luukku, treffiseura, lahjat ja flirtti. Illasta kerrotaan vihjailemalla
(sammuva valo, ovi, kortti). Biisin sanat soivat taustalla sellaisenaan ilman sensuuria, eikä niitä näytetä tekstinä.

## Biisi (`assets/music/tanssit/rasvanappi.mp3`)

173,3 s, 129,2 bpm (1 isku = 0,465 s, 1 tahti = 1,86 s, ensimmäinen isku 0,21 s). Iskut mitattu `tools/tanssibiisi.py`:llä
(librosa) koko biisille; tempo heittelee hieman, joten leikkaukset otetaan mitatuista iskuista (kuten `tanssibiisit.gd`).
Rakenne (ajat laulusta, whisper-kohdistus):

| Aika | Osa | Sanat (aihe) |
|---|---|---|
| 0:00–0:27 | Säkeistö 1 | makasiini, punainen lamppu, koputus kolmesti (0:16), luukku aukeaa, salasana |
| 0:27–0:45 | Kertosäe 1 | "vapos ja kontataan…" |
| 0:45–1:00 | Säkeistö 2 | nimiluettelo: Pekka (0:45), Arto, Sinikka (0:49), Helena, Raimo (0:52) |
| 1:00–1:14 | Kertosäe 2 | |
| 1:14–1:33 | Silta | hiljaa kontaten, "Raimo!" (1:25), Raimo nukkuu nurkassa (1:27) |
| 1:33–1:55 | Pitkä välisoitto | aamu, sukka hukassa |
| 1:55–2:11 | Loppusäkeistö | "ei puhutakaan marketissa, ei päiville, ei kellekään" (1:59), "ensi lauantaina taas lamppu palaa" (2:04) |
| 2:11–2:40 | Kertosäe 3 ja 4 | huipennus |
| 2:40–2:53 | Loppu | Häpp! 2:40, 2:44, 2:47 |

Ehdotus kuvan ja sanan osumiin: koputus kolmesti = apteekin takaoven koputus; nimiluettelo = hahmoesittelyt tavallisissa
paikoissa; "ei päiville" = Päivin motkotukset; "ensi lauantaina lamppu palaa" = apteekin takaoven vihreä lamppu; kolme
Häppiä = kolme tehosteiskua (PIDÄTETTY, WASTED, ELVYTETTY) ja logo.

Ei ennakkomusiikkia: peli alkaa heti, koukku ensimmäisestä iskusta. Kesto 173 s + logo 5 s = noin 2:58.

## Otokset

Kesto tahteina (t = 1,86 s) ja sekunteina. **UUSI** = lavastus tehtävä `otokset.gd`:hen, muut käyttävät olemassa olevaa
lavastusta. In = kohta pitkästä otosta.

### 0:00–0:16 Koukku: auton varastus (8 tahtia)

| # | Otos | Kuva | Kesto |
|---|---|---|---|
| 1 | **UUSI** `a_kaappaus` | Liikenneauto pysähtyy suojatielle, pelaaja kuljettajan oven vieressä, kuski hyppää ulos "HEI! MUN AUTO!" | 2 t |
| 2 | **UUSI** `a_viisi_tahtea` | Oikean yläkulman viisi tähteä syttyy, kamera auton sisältä rattiin ja kaasuun | 1 t |
| 3 | **UUSI** `a_pako_saloinen` | Varastettu auto Valtatiellä, taustalla Päivin Hyundai kääntyy perään | 2 t |
| 4 | `p_hyundai_lahtee` (KORJAA) | Päivi ratissa, kasvot, "Mun auto on tuolla!" | 1 t |
| 5 | **UUSI** `a_poliisi_ilmestyy` | Poliisiauto valot päällä ohittaa kameran | 1 t |
| 6 | `i_koti` | Kotipiha aamuauringossa, **otsikko NORMIPÄIVÄ** (kontrasti: rauhallinen) | 1 t |

### 0:16–0:27 Säkeistö 1b: huumekauppa alkaa (6 tahtia)

| # | Otos | Kuva | Kesto |
|---|---|---|---|
| 7 | **UUSI** `h_takaovi_koputus` | Vaalan apteekin takaovi, käsi koputtaa kolme kertaa iskulla (0:16 ja kaksi seuraavaa) | 1 t |
| 8 | **UUSI** `h_luukku` | Kurkistusluukku aukeaa, Raili, vihreä lamppu, hinnat; samalla leikkaus **portsariin** (viikset, sotilaspuku, "Sano sana") makasiinin luukussa: sama koputus, sama gagi | 2 t |
| 9 | **UUSI** `h_klaffipoyta` | Klaffipöytä torilla, 3×3-askartelu: Oksikodoni + Burana, reseptikirjan sivu aukeaa | 2 t |
| 10 | **UUSI** `h_teinit_kaukalo` | Kaukalon iltateinit, myynti, rahat vaihtuvat | 1 t |

### 0:27–0:45 Kertosäe 1: tähtijahti (10 tahtia)

| # | Otos | Kuva | Kesto |
|---|---|---|---|
| 11 | **UUSI** `a_jahti_paivi` | Päivin Hyundai ajaa varastetun auton kannoilla, 5 tähteä vilkkuu, minikartalla jahtaaja | 2 t |
| 12 | `f_poliisi` + **UUSI** `a_jahti_poliisi` | Poliisiauto liittyy, valot ja sireeni, tutka sinisenä pylpyränä | 2 t |
| 13 | `f_traktori` | Traktori tiellä, auto väistää kiskojen yli | 1 t |
| 14 | **UUSI** `a_jahti_roivainen` | Vaalassa Roivaisen poliisi-Saab ajaa Satamantien alikulusta | 2 t |
| 15 | **UUSI** `a_pako_onnistuu` | Auto piilossa ladossa, tähdet putoavat yksi kerrallaan 5 → 0 | 2 t |
| 16 | `f_wasted` (HEP 0:44) | Päivi 6 metrin päässä, WASTED iskulle | 1 t |

### 0:45–1:00 Säkeistö 2: nimiluettelo (8 tahtia)

Jokainen nimi omana otoksenaan lauletun nimen kohdalla (0:45 Pekka, 0:47 Arto, 0:49 Sinikka, 0:51 Helena, 0:52 Raimo).
Nimikortti (`teksti: nimi + rooli`), tavallisessa pelin paikassa.

| # | Otos | Kuva | Kesto |
|---|---|---|---|
| 17 | `h_pekka` | Pekka aidalla "Mun avaimet!" | 1 t |
| 18 | `h_arto` | Arto ruohonleikkurilla hyräillen | 1 t |
| 19 | `s_sinikka` | Sinikka kuistilla, ovilappu ja mustikkakori (UUSI kuisti) | 1 t |
| 20 | `m_juna` | Helena junassa (huokailee), kädet hänen sylissään | 1 t |
| 21 | **UUSI** `h_raimo` | Verotoimiston Raimo nukkuu kirjoituspöydän ääressä | 1 t |
| 22 | `h_paivi` | Päivi: "Vaimo. Näkee kaiken." | 1 t |
| 23 | **UUSI** `h_irma` | Kinnapotin Irma apteekin takakulmalla, nostaa kännykän korvalle (epäluulo täyteen) | 2 t |

### 1:00–1:14 Kertosäe 2: kolmiomittaus (7 tahtia)

| # | Otos | Kuva | Kesto |
|---|---|---|---|
| 24 | **UUSI** `m_joni_esa` | Kaupan piha: Joni päkkirinkka selässä (golfpallot, termos), Esa harppi taskussa | 2 t |
| 25 | **UUSI** `m_sytkari` | Puhelimen Sytkäri-mätsi: Minttu (punaiset kiharat), liekkilogo, "Match!" | 1 t |
| 26 | **UUSI** `m_kartta_harppi` | Paperikartta (M): harpilla piirretyt ympyrät leikkaavat, naisen talo | 2 t |
| 27 | **UUSI** `m_siviikki` | Timon punainen Siviikki, VTEC kytkeytyy, nurmikon yli Vaalantielle | 2 t |

### 1:14–1:33 Silta: lahjat ja ilta (10 tahtia). Ei Rasvanappia

| # | Otos | Kuva | Kesto |
|---|---|---|---|
| 28 | **UUSI** `m_lahjat_ovella` | Kolme tietäjää ovella: ruusut, mansikat, kermavaahto, ovikello | 2 t |
| 29 | **UUSI** `m_vaara_ovi` | Väärä ovi, mummo kepin kanssa avaa (kepin heilautus, "Raimo!" iskulle 1:25) | 2 t |
| 30 | **UUSI** `m_ovi_aukeaa` | Oikea ovi aukeaa, nainen (Minttu) hymyilee, kaverit seisovat jonossa lahjat kourassa | 1 t |
| 31 | **UUSI** `m_flirtti` | Treffiseura (Minttu tai Katja) ottaa lahjat vastaan ja flirttailee, Sytkäri-viesti puhelimessa: "Jäisitkö iltapuuhaan? 😉", pelaaja punastuu | 2 t |
| 32 | **UUSI** `m_ilta_vihje` | Ulkoa ikkuna: valo sammuu, kaverit hyppivät innoissaan sisään, ovi sulkeutuu, kuunvalo, portsarin viikset ovenraosta | 1 t |
| 32b | `kortti` | Musta kortti: **"Ihanaa iltapuuhaa."**, ei muuta | 1 t |
| 33 | **UUSI** `m_puhelu` | Päivin puhelu kesken kaiken: "Missä sää oot?" "Kolmiomittaamassa." "No tuo maitoa tullessas." | 3 t |

### 1:33–1:55 Välisoitto: aamu ja uusi Vaala (12 tahtia)

| # | Otos | Kuva | Kesto |
|---|---|---|---|
| 34 | **UUSI** `m_aamu` | Aamu: kahvit ja mansikkaletut naisen keittiössä (Kolmiomittaus Saloisissa) | 2 t |
| 35 | `f_mopo_silta` | Mopolla Vaalaan, teksti **VAALA** | 2 t |
| 36 | **UUSI** `v_ymparyra` | Uusi liikenneympyrä ja K-Market Tervaportti droonilla | 2 t |
| 37 | **UUSI** `v_satama` | Vaalan satama, muskelivene Oulujärvelle | 2 t |
| 38 | `f_lava_tanssi` | Lavatanssit, parit valssiotteessa | 2 t |
| 39 | **UUSI** `v_retki` | Retkien montaasi: Hiidenportin rotko, Kuhmon karhunkatselu, Kajaanin linna (3 pikaotosta) | 2 t |

### 1:55–2:11 Loppusäkeistö: Päivin motkotukset (8 tahtia)

Sanat "ei puhutakaan marketissa, ei päiville, ei kellekään": Päivin motkotukset. Päivin repliikit ja ääni pelistä.

| # | Otos | Kuva | Kesto |
|---|---|---|---|
| 40 | **UUSI** `p_motkotus_koti` | Kotipiha aamulla, pelaaja pää painuksissa, Päivi: "Ei päiville!" (`cutscene.wasted`) | 2 t |
| 41 | **UUSI** `p_motkotus_huume` | Päivin puhelu Vaalan hotellihuoneeseen: "Santtu soitti. Santun piti elvyttää sut!" "HUUMEET ON VAARALLISIA. OIKEASTI." (`wasted_phone` yliannos) | 3 t |
| 42 | **UUSI** `p_motkotus_pidatys` | "Vaalan poliisi soitti. Sut pidätettiin!", PIDÄTETTY-otsikko | 2 t |
| 43 | **UUSI** `h_lamppu` | Apteekin takaoven vihreä lamppu palaa iltahämärässä (2:04 "ensi lauantaina taas lamppu palaa") | 1 t |

### 2:11–2:40 Kertosäe 3 ja 4: huipennus (16 tahtia)

Tiivistyvä leikkaus (2 t, sitten 1 t), kaikki ominaisuudet vielä kerran vauhdilla.

| # | Otos | Kuva | Kesto |
|---|---|---|---|
| 44 | `a_jahti_roivainen` | Roivainen jahtaa Vaalassa | 2 t |
| 45 | **UUSI** `h_valeostaja` | Valeostaja torilla: "Sää oot kyttä!", virkamerkki | 1 t |
| 46 | **UUSI** `h_ambulanssi` | Kaukalo, ambulanssi sireeni, teini nurmella, ELVYTETTY-otsikko | 2 t |
| 47 | `f_kiihdytys` | Kiihdytys, ajan kiihdytys (G) | 1 t |
| 48 | **UUSI** `a_jahti_maali` | Pako pelloilla, tähdet 5 → 1, kamera auton yli | 2 t |
| 49 | `k_rossi` | Mopo hyppyrille | 1 t |
| 50 | `k_karaoke` | Karaoke Siitarissa | 1 t |
| 51 | `s_kyyti` | Kyyti yöllä | 1 t |
| 52 | **UUSI** `m_siviikki_paluu` | Siviikki ajaa takaisin asemalle, kaverit mukana | 1 t |
| 53 | `f_poliisi` | Poliisi ohi | 1 t |
| 54 | `f_wasted` | WASTED | 1 t |
| 55 | `f_auringonlasku` | Laavu, nuotio, ilta (rauhoittuu ennen loppua) | 2 t |

### 2:40–2:53 Loppu: Häpp! Häpp! Häpp! (7 tahtia)

| # | Otos | Kuva | Kesto |
|---|---|---|---|
| 56 | `loppu_pidatetty` | **Häpp 1 (2:40):** PIDÄTETTY, mustavalkoinen pysäytyskuva, isku | 1 t |
| 57 | `loppu_wasted` | **Häpp 2 (2:44):** WASTED, punainen otsikko | 1 t |
| 58 | `loppu_elvytetty` | **Häpp 3 (2:47):** ELVYTETTY / "HUUMEET ON VAARALLISIA. OIKEASTI." | 1 t |
| 59 | `loppu_logo` | Normipäivä-logo, "Tulossa", biisin sointu hiljenee | 3 t + 5 s |

## Huumeet humoristisena sekoiluna

Sävy on pelin oma: lämmin sarjakuvasekoilu, ei kuvaa vakavasti eikä houkuttelevasti, ja seuraukset ovat osa vitsiä
(PIDÄTETTY, ELVYTETTY, Päivin motkotus). Ei todellisia ohjeita: jatkaminen näytetään pelin omana askarteluna.

- **Hankinta:** koputus, luukku ja farmaseutti kuiskaten ("Sano sana"); Raili vilkuilee verhon takaa, hinnat tekstinä.
- **Leikkaaminen (jatkaminen):** klaffipöytä toimii kuin Minecraftin askarteluruudukko; sokeri ja turbohiiva menevät
  ruutuun, annokset moninkertaistuvat ja reseptikirjaan ilmestyy ???-rivi. Pikakelaus, kimmoisa ääni jokaisesta ruudusta.
- **Myynti:** teini maksaa, kaukalolla ringin vieressä; valeostajalla korvassa kierrejohto ja valkoiset lenkkarit
  ("Mä otan kaikki, paljonko sulla on?"), "Sää oot kyttä!" ja virkamerkki; huijari kuoressa väärät setelit.
- **Rikollinen toiminta:** Irma tuijottaa takaovea ja soittaa poliisille, mopopoikien velka kasvaa 15 % aamussa ja
  diilitappelu, auton kaappaus ("HEI! MUN AUTO!"), viisi tähteä ja Päivi poliisina perässä.
- **Seuraukset kevyesti:** Päivin puhelin, pää painuksissa, "Kyllä kulta...".

## Päätökset ja oletukset

- **Treffiseura** on Sytkäri-sovelluksen (pelin oma parodia) Minttu Saloisissa ja Katja Vaalassa. Lahjojen (ruusut,
  mansikat, kermavaahto) jälkeen hän ehdottaa flirttaillen iltapuuhaa. Kirjoitusasu "iltapuuhaa".
- **Portsari** on makasiinin luukun viiksekäs sotilaspukuinen mies; sisälle makasiiniin tai pimeään olohuoneeseen ei
  mennä.
- Vanhan trailerin lavastuksia (`f_`, `h_`, `i_`, `k_`, `s_`) käytetään sellaisenaan, 35 otosta 60:stä on uusia
  (merkitty UUSI). Autovarkauden ja kolmiomittauksen otokset tarvitsevat omat kameraliikkeet.
- Motkotuskohtaukset ovat pelin omia välianimaatioita (`cutscene.wasted`, `wasted_phone`): niistä otetaan pitkä otto ja
  leikataan paras kohta.

## Työ jatkossa

1. Sinä hyväksyt tämän (tai muutat otoksia).
2. Iskut koko biisille (`tools/tanssibiisi.py`) ja uusi `leikkaus_rasvanappi.gd` (sama rakenne kuin `leikkaus.gd`,
   musiikkina `rasvanappi.mp3`, `BEAT` 0,465 ja mitatut iskut).
3. Uudet lavastukset `otokset.gd`:hen ja esikatselu (`--preview`), kuvat kaikista uusista otoksista.
4. Esikatselu videona, korjaukset, lopullinen renderöinti (`renderoi.gd`, GPU-ikkuna, ei `--headless`).

## Toteutus (tilanne)

Kaikki otokset on lavastettu ja koko traileri renderöity (1280x720, 2:58). Poikkeukset suunnitelmaan: `t_kota` Raimon nimikortille
(Raimo on kodan vakiovieras), `v_retki` jaettu kahteen (`v_retki_rotko`, `v_retki_karhu`), `h_portsari` lisätty, `m_kortti` kortiksi
ja Päivin puhelu (`m_puhelu`) on aamukohtauksen viimeinen rivi ("MAITOA."). Ohjeet: [LUEMINUT.md](LUEMINUT.md).
