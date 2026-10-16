#!/usr/bin/env bash
# Kääntyykö peli suoraan ajettuna ilman editoria (`godot ./`)?
# Web-export ja editori rakentavat luokkalistan (.godot/global_script_class_cache.cfg), joten ne eivät huomaa
# esim. class_name-nimeä, jota ajossa ei löydy. Tämä poistaa luokkalistan importin jälkeen ja ajaa main.tscn:ää
# headlessina muutaman sekunnin. --shot-kohtaukset eivät sovi: headlessissa ei renderöidä, joten kuvakaappaus
# kaatuu tai jää odottamaan.
#
# Käyttö: tools/testit/kaantyyko.sh [godot-komento]   (oletus: godot; AIKARAJA=sekunnit, oletus 180)
# Paikallisesti ajettuna poistaa myös oman luokkalistasi; editori rakentaa sen uudelleen avattaessa.
set -euo pipefail

godot=${1:-godot}
aikaraja=${AIKARAJA:-180}
cd "$(dirname "$0")/../.."
log=$(mktemp)
trap 'rm -f "$log"' EXIT

# Assetit tarvitaan, mutta import luo luokkalistan: poistetaan se, kuten tuoreella checkoutilla ilman editoria.
"$godot" --headless --path . --import >/dev/null 2>&1 || true
rm -f .godot/global_script_class_cache.cfg

# 300 ruutua (n. 5 s); aikaraja, jos peli jää jumiin. macOS:ssä ei ole timeoutia, joten vahti taustalla.
"$godot" --headless --path . --quit-after 300 >"$log" 2>&1 &
pid=$!
( sleep "$aikaraja" && kill -9 "$pid" 2>/dev/null && echo "AIKARAJA: peli ei sulkeutunut $aikaraja s:ssa" >>"$log" ) &
vahti=$!
status=0
wait "$pid" || status=$?
kill "$vahti" 2>/dev/null || true
wait "$vahti" 2>/dev/null || true

if grep -qiE "SCRIPT ERROR|Parse Error|Compile Error|AIKARAJA" "$log"; then
	grep -iE -A3 "SCRIPT ERROR|Parse Error|Compile Error|AIKARAJA" "$log" | head -60
	echo "Peli ei käänny ilman editoria (ks. yllä)." >&2
	exit 1
fi
if [ "$status" -ne 0 ]; then
	tail -40 "$log"
	echo "Godot päättyi koodiin $status." >&2
	exit 1
fi
echo "OK: peli kääntyy ja käynnistyy ilman luokkalistaa."
