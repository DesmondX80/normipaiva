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

Lopuksi tulostuu ffmpeg-komento `traileri_karaoke.mp4`:lle.

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
