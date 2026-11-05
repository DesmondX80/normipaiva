# Normipäivä: traileri

GTA-tyylinen traileri (n. 3 min 40 s) pelikuvasta, tahdistettuna tunnariin (`assets/music/normipaiva.mp3`).
Kaikki tehdään Godotilla: ei erillistä editointiohjelmaa. Kone ei vaikuta laatuun, vain kestoon:
Movie Maker -tila renderöi jokaisen ruudun täydellä laadulla kiinteällä 30 fps:llä.

## Tiedostot

Ennen leikkauksen muokkaamista lue [OHJEET.md](OHJEET.md): hyvän pelitrailerin periaatteet, rytmi ja otosten säännöt.

| Tiedosto | Mitä |
|---|---|
| `leikkaus.gd` | Otosten järjestys, kestot iskuina, tekstit, ryhmät. Leikkausta muokataan täällä. |
| `otokset.gd` | Jokaisen otoksen lavastus: kellonaika, hahmot, kamera-ajo, painallukset. |
| `ohjaaja.gd` | Kuvaa otokset pelissä (`--trailer=`): mustat palkit, värit, tekstit, erotinruudut. |
| `kortti.gd` | Mustat tekstikortit, Päivin lappu ja loppulogo ilman peliä. |
| `teksti.gd` | Tekstit: nimiesittelyt, Puskaradio-puhelinkehys. |
| `renderoi.gd` | Ajaa kaiken: ryhmä kerrallaan oma pelin käynnistys, sitten kokoaminen. |
| `kokoa.gd` | Liittää otokset ja miksaa tunnarin ja pelin äänet: `traileri.avi` + `traileri.wav`. |
| `karaoke.gd` | Karaokeversio valmiista trailerista: tunnarin sanat alempaan palkkiin (`traileri_karaoke.avi`). |
| `karaoke.json` | Sanat ja jokaisen sanan alku ja loppu tunnarissa (s). Tekee `karaoke_ajoitus.py`. |

## Renderöinti (tehokkaampi kone)

Tarvitaan Godot 4.7.2 (sama kuin projektissa). Projektikansiossa:

```
godot --path . --headless -s res://tools/traileri/renderoi.gd -- --out=C:/traileri --res=1920x1080
```

- `--res=3840x2160` 4K:lle (vie enemmän levyä; yli 1,9 Gt:n video kirjoitetaan JPEG-ruutuina `ruudut/`-kansioon).
- Laatu on aina pelin korkeinta asetusta parempi (varjot 8K, täysi LOD, SSAO/SSIL ultra, MSAA 8×) ja kuva
  ylinäytteistetään oletuksena 2× (`--ss=2.0`). Jos näytönohjaimen muisti loppuu, kokeile `--ss=1.5`.
- Valmiit ryhmät ohitetaan, joten keskeytyneen ajon voi jatkaa samalla komennolla. `--again` kuvaa uudelleen.
- `--groups=mokki,vaala` kuvaa vain osan; kokoaminen ajetaan aina lopuksi.
- Peli-ikkuna aukeaa jokaista ryhmää varten: älä sulje sitä. Pelin tallennus palautetaan jokaisen ryhmän jälkeen.

Lopuksi tulostuu ffmpeg-komento MP4:ää varten (YouTube), esim.

```
ffmpeg -i traileri.avi -i traileri.wav -map 0:v -map 1:a -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -c:a aac -b:a 320k -shortest traileri.mp4
```

## Esikatselu (nopea, pieni)

```
godot --path . --headless -s res://tools/traileri/renderoi.gd -- --preview --res=1280x720 --groups=ulko
```

Kuvat jokaisen otoksen alusta, keskeltä ja lopusta, ja ryhmittäin arkki `esikatselu/esikatselu_<ryhmä>.png`.
`--ids=i_ilma,i_koti` kuvaa vain annetut otokset.

## Karaokeversio

Valmiin trailerin (`traileri.avi` tai `ruudut/`) alempaan mustaan palkkiin piirretään tunnarin sanat: laulettava
rivi täyttyy kullankeltaiseksi sana sanalta, seuraava rivi näkyy himmeänä alla, ja pitkän tauon jälkeen kolme
pistettä laskee rivin sisään iskujen tahdissa. Peliä ei kuvata uudelleen, ja ääni kopioidaan sellaisenaan.
Tekstit piirretään näytönohjaimella, joten ajo ei voi olla `--headless` (n. 30 s 720p:llä, pidempään 1080p:llä):

```
godot --path . -s res://tools/traileri/karaoke.gd -- --in=C:/traileri
```

Lopuksi tulostuu ffmpeg-komento `traileri_karaoke.mp4`:lle. Valinnat (voi yhdistää):

- `--tyyli=kuva`: traileri pyörii taustalla ja sanat ovat isompina kuvan päällä sen alaosassa (pehmeä tumma
  liukuväri tekstin takana), seuraava rivi palkissa. Tulos `traileri_karaoke_kuva.avi`.
- `--soitto`: tunnari ilman laulua, joten katsoja laulaa itse. Aja ensin ääni (vain ääni, video ei muutu):

  ```
  godot --path . --headless -s res://tools/traileri/kokoa.gd -- --in=C:/traileri --soitto
  godot --path . -s res://tools/traileri/karaoke.gd -- --in=C:/traileri --tyyli=kuva --soitto
  ```

  `kokoa.gd --soitto` miksaa `traileri_soitto.wav`:n samoin kuin trailerin äänen, mutta tunnarin tilalla on
  `assets/music/normipaiva_soitto.mp3` (laulu erotettu Demucsin htdemucs_ft-mallilla, sama ajoitus). Pelin äänet
  pysyvät. Tulos `traileri_karaoke[_kuva]_soitto.avi`.
  Uuden musiikkitiedoston on oltava tuotu ennen kokoamista (`godot --headless --path . --import` tai editorin avaus),
  muuten kokoa.gd ilmoittaa, ettei musiikkia voi ladata.

### Sanojen ajoitus (`karaoke.json`)

Sanat on kuunneltu tunnarin lauluraidasta ja tarkistettu käsin (`karaoke_ajoitus.py`, LINES/CHUNKS). Jokaisen sanan
aika on pakotetulla kohdistuksella: suomenkielinen wav2vec2-puhemalli kohdistaa tunnetut sanat kirjain kirjaimelta
lauluraitaan. Ajoitus on tarkistettu leikkaamalla lauluraidasta kunkin rivin aikaväli ja tunnistamalla se Whisperillä:
jokaisesta ikkunasta kuuluvat juuri sen rivin sanat. Jos sanoja tai tunnaria muutetaan, aja uudelleen:

```
python -m demucs --two-stems=vocals -n htdemucs tunnari44.wav        # laulu erilleen soittimista
ffmpeg -i separated/htdemucs/tunnari44/vocals.wav -ar 16000 -ac 1 vocals16k.wav
pip install torch torchaudio transformers
python tools/traileri/karaoke_ajoitus.py vocals16k.wav > tools/traileri/karaoke.json
```

Sanojen kuunteluun (uusi biisi): `whisper-cli -m ggml-large-v3-turbo.bin -l fi -f vocals16k.wav` (whisper.cpp).

## Rasvanappi-traileri: uudet ominaisuudet (3:03)

Toinen traileri esittelee uusia ominaisuuksia (auton varastus ja tähtijahti, huumekauppa ja sen riskit, Päivin
motkotukset, kolmiomittaus, uusi Vaala) Saloisten Saapasjalkojen Rasvanappi-biisin (`assets/music/tanssit/rasvanappi.mp3`,
129,2 bpm) tahtiin. Suunnitelma ja perustelut: [PAPERILEIKKAUS_RASVANAPPI.md](PAPERILEIKKAUS_RASVANAPPI.md).
Rasvanappi-minipeliä ei näytetä: kuvassa on portsari luukussa, treffiseura ja flirtti, ilta vain vihjeenä.

| Tiedosto | Mitä |
|---|---|
| `leikkaus_rasvanappi.gd` | Otosten järjestys ja kestot iskuina. Jokaisen osan alku on ankkuroitu mitattuun iskuun (`at`), koska Sunon tempo heittelee. Sama lavastus toista kertaa: tunnisteeseen `__2`. |
| `otokset_uusi.gd` | Uusien otosten lavastus (`a_` auto, `h_` huume, `m_` kolmiomittaus, `p_` motkotus, `v_` Vaala). Otokset.setup kutsuu tätä ensin. |

Setin valinta: `--set=rasvanappi` (renderoi.gd, kokoa.gd). Ilman sitä ajetaan ensimmäinen traileri.

```
godot --path . -s res://tools/traileri/renderoi.gd -- --set=rasvanappi --res=1920x1080 --out=C:/traileri_rn
godot --path . -s res://tools/traileri/renderoi.gd -- --set=rasvanappi --preview --res=1280x720 --groups=auto,apteekki
```

Opit lavastuksesta:

- Jahtikuvissa pidä jahtaajat vähintään 9 m päässä (`_chasers`): muuten Päivi nappaa auton kesken otoksen (WASTED).
- Autopilotin reitistä pudotetaan pisteet auton takaa (`_drive`), ja nopeus pidetään vähintään 12 m/s liikennekolarien varalta.
- Pelin omat välianimaatiot (WASTED, ELVYTETTY, PIDÄTETTY) ajetaan oikeilla funktioilla (`_lose`, `_rikos_loppu`) kukin omassa
  ryhmässään (muuten edellisen otoksen animaatio jatkuu seuraavan päälle) ja `in` ohittaa otsikon. `cs_bubbles` näyttää Päivin repliikit.
- Kolmiomittauksen kohtaukset (`kolmio_kohtaus.gd`) sovitetaan mustien palkkien väliin (`_kolmio_scene`), jotta tekstilaatikko näkyy.
- Rasvanapin luukkukohtauksesta kuvataan vain portsari ja "Salasana."-kupla: pelin oma aika pysäytetään ennen salasanavalikkoa.
- `loppu_*`-kortit: `vari` kytkee gradientin pois ja suurentaa tekstin.

Rakenne (v3): prologi ilman musiikkia (pyörä auton eteen, kaappaus: "HEI! MUN AUTO!" kuuluu vain kerran), sitten biisi alkaa:
kaahaus ja Päivin motkotus pidätyksestä, makasiini ja portsari laulun kohdilla, apteekin takaovi, huumeiden laimennus ja
diilaus teineille, kuolema mummon keppiin ja Päivin motkotus, nimiluettelo, kolmiomittaus, uusi Vaala, ELVYTETTY-motkotus
ja lopun WASTED / PIDÄTETTY / ELVYTETTY. Pyöräilykohtauksia ei ole (alun pyörä auton eteen poikkeus).
Kuski ja hänen huutonsa poistetaan kaikista muista kaappauskuvista (`_poista_kuski`, `Sfx.stop_speech`).
