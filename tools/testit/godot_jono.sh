#!/usr/bin/env bash
# Ajaa Godot-komennon jonossa: vain yksi ajo kerrallaan, koska kaikki ajot käyttävät samaa pelaajan tallennusta ja
# user://-kansiota (rinnakkaiset ajot sotkevat toistensa tallennukset ja kuvat). Lukko on hakemisto (mkdir on atominen
# kaikilla alustoilla); jos lukon haltija on kuollut, vanha lukko vapautetaan.
# Käyttö: tools/testit/godot_jono.sh [godot-argumentit...]   (Godot-komento: tools/testit/godot.sh)
#   esim. HOME=<scratchpad>/home tools/testit/godot_jono.sh --path . -- --scene=asennot --asento=a --nohud
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
lukko="${TMPDIR:-${TMP:-/tmp}}/normipaiva_godot.lukko"
godot="$("$dir/godot.sh")"

while ! mkdir "$lukko" 2>/dev/null; do
	pid=$(cat "$lukko/pid" 2>/dev/null || echo "")
	if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
		echo "godot_jono: vapautetaan kuolleen ajon ($pid) lukko" >&2
		rm -rf "$lukko"
		continue
	fi
	echo "godot_jono: odotetaan edellistä Godot-ajoa (${pid:-?})..." >&2
	sleep 10
done
echo $$ > "$lukko/pid"
trap 'rm -rf "$lukko"' EXIT

"$godot" "$@"
