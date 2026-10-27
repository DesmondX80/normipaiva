#!/usr/bin/env bash
# Ajaa Godot-komennon jonossa: vain yksi ajo kerrallaan, koska kaikki ajot käyttävät samaa pelaajan tallennusta ja
# user://-kansiota (rinnakkaiset ajot sotkevat toistensa tallennukset ja kuvat). Lukko on hakemisto (mkdir on atominen
# kaikilla alustoilla); jos lukon haltija on kuollut, vanha lukko vapautetaan.
# Käyttö: tools/testit/godot_jono.sh [godot-argumentit...]   (Godot-komento: tools/testit/godot.sh)
#   esim. HOME=<scratchpad>/home tools/testit/godot_jono.sh --path . -- --shot=/tmp/x.png --scene=asennot --asento=a --nohud
# Aikaraja GODOT_AIKARAJA sekunteina (oletus 600): jumiutunut ajo lopetetaan, ettei jono pysähdy.
# --scene ilman --shot:ia ei käynnistä testiä (peli jää päävalikkoon), joten se hylätään heti.
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
lukko="${TMPDIR:-${TMP:-/tmp}}/normipaiva_godot.lukko"
godot="$("$dir/godot.sh")"
aikaraja="${GODOT_AIKARAJA:-600}"

scene=0
shot=0
for a in "$@"; do
	case "$a" in
		--scene=*) scene=1 ;;
		--shot=*) shot=1 ;;
	esac
done
if [[ $scene == 1 && $shot == 0 ]]; then
	echo "godot_jono: --scene vaatii --shot=<polku>.png, muuten peli jää päävalikkoon eikä testi käynnisty" >&2
	exit 2
fi

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

# Vahti taustalla (macOS:ssä ei ole timeoutia): lopettaa ajon aikarajan jälkeen.
"$godot" "$@" &
gpid=$!
( sleep "$aikaraja" && kill "$gpid" 2>/dev/null && echo "godot_jono: AIKARAJA $aikaraja s, ajo lopetettu" >&2 ) &
vahti=$!
rc=0
wait "$gpid" || rc=$?
kill "$vahti" 2>/dev/null || true
exit $rc
