#!/usr/bin/env bash
# Yksi repliikki puheeksi Macin `say`:llä: syntetisoi.sh <ryhmä paivi|muu> "<teksti>" <ulos.mp3>
# Päivi: Satu, nalkutus (nopea tahti, korotettu sävelkorko). Muut hahmot: Eddy, rauhallinen tenori (hidas tahti,
# hieman korotettu miesääni). Asetukset valittu kuuntelemalla (22 050 Hz, mono). Vain kehityskäyttöön: ääntä ei
# syntetisoida pelin ajossa, vaan `--aanisynteesi`-lipulla (ks. audio.gd speak) ja tulos tallennetaan assets/aanet/.
set -euo pipefail
ryhma="$1"; teksti="$2"; ulos="$3"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if [ "$ryhma" = "paivi" ]; then
  aani="Satu"; suodatin="asetrate=22050*1.10,aresample=22050,atempo=1.18"
else
  aani="Eddy (Finnish (Finland))"; suodatin="asetrate=22050*1.06,aresample=22050,atempo=0.92"
fi
say -v "$aani" -o "$tmp/a.aiff" "$teksti"
ffmpeg -y -loglevel error -i "$tmp/a.aiff" -af "$suodatin" -ac 1 -c:a libmp3lame -b:a 48k "$ulos"
