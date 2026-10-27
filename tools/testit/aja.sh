#!/usr/bin/env bash
# Yksi komento kaikille testiajoille, jotta kukaan ei rakenna Godot-komentoa käsin (unohtunut --shot jätti pelin
# päävalikkoon, unohtunut quit() jumitti ajon). Hoitaa: eristetyn HOME:n, jonon (godot_jono.sh), aikarajan, oikeat
# argumentit, lokin talteen ja tarkistuksen. Lopussa yksi rivi: OK tai VIKA. OK vaatii, että
#   - Godot päättyi itse koodilla 0 ja ilman aikarajaa,
#   - lokissa ei ole skriptivirheitä,
#   - testi itse ei löytänyt vikoja (ks. LOYDOT alla; uudet testit: tulosta vikarivi muodossa "TESTI VIKA <selitys>"),
#   - kuvia syntyi (paitsi --ei-kuvia tai --headless).
# Rivit, joissa lukee "ei tarkistettu", raportoidaan varoituksina (testi ei voinut mitata, esim. headless).
#
# Käyttö:
#   tools/testit/aja.sh kaantyy                                  # kääntyykö peli ilman editoria (kaantyyko.sh)
#   tools/testit/aja.sh [valinnat] scene <nimi> [lisä...]        # main.gd:n testikohtaus, esim. scene asennot --asento=a
#   tools/testit/aja.sh [valinnat] tscn <polku.tscn> [lisä...]   # erillinen kohtaus; saa tulostekansion 1. argumenttina
# Valinnat: --headless (ei ikkunaa, ei kuvia), --ei-kuvia (logiikkatesti ikkunalla),
#   --video (vain tscn: ajaa Movie Maker -tilassa, 30 fps, <nimi>.avi ajokansioon ja tarkistaa sen; aikaraja oletus 900 s)
# Ympäristö: AJO_KANSIO (oletus ${TMPDIR:-/tmp}/normipaiva_ajot), GODOT_AIKARAJA (oletus 600 s).
set -uo pipefail

LOYDOT='TESTI VIKA|RAKO LÄPI|KONTAKTI JÄÄ|LÄPI .* -> |[^A-ZÄÖ]VIRHE|RISTISSÄ|EI YHTÄÄN ISTUJAA|\[[0-9]+ vikaa\]|[1-9][0-9]* vikaa'

dir="$(cd "$(dirname "$0")" && pwd)"
cd "$dir/../.."
juuri="${AJO_KANSIO:-${TMPDIR:-${TMP:-/tmp}}/normipaiva_ajot}"
mkdir -p "$juuri/home"
export HOME="$juuri/home"  # testi ei koske pelaajan omaan tallennukseen
leima="$(date +%Y%m%d_%H%M%S)"

headless=0
kuvat=1
video=0
while [[ "${1:-}" == --* ]]; do
	case "$1" in
		--headless) headless=1; kuvat=0 ;;
		--ei-kuvia) kuvat=0 ;;
		--video) video=1 ;;
		*) echo "aja: tuntematon valinta $1"; exit 2 ;;
	esac
	shift
done
alku=()
[[ $headless == 1 ]] && alku=(--headless)

laji="${1:-}"
shift || true
case "$laji" in
	kaantyy)
		bash "$dir/kaantyyko.sh"
		exit $?
		;;
	scene)
		nimi="${1:?scene vaatii nimen}"
		shift
		ulos="$juuri/${nimi}_$leima"
		mkdir -p "$ulos"
		args=("${alku[@]}" --path . --resolution 1280x720 -- "--shot=$ulos/kuva.png" "--scene=$nimi" --nohud "$@")
		;;
	tscn)
		polku="${1:?tscn vaatii polun}"
		shift
		ulos="$juuri/$(basename "$polku" .tscn)_$leima"
		mkdir -p "$ulos"
		if [[ $video == 1 ]]; then
			# Movie Maker: kiinteä 30 ruudun aika, .avi ajokansioon (kohtauksen tulee päättyä itse quit():iin)
			avi="$ulos/$(basename "$polku" .tscn).avi"
			export GODOT_AIKARAJA="${GODOT_AIKARAJA:-900}"
			args=("${alku[@]}" --path . --resolution 1280x720 --fixed-fps 30 --write-movie "$avi" "$polku" -- "$ulos" "$@")
		else
			args=("${alku[@]}" --path . --resolution 1280x720 "$polku" -- "$ulos" "$@")
		fi
		;;
	*)
		sed -n '2,21p' "$0"
		exit 2
		;;
esac

loki="$ulos/loki.txt"
echo "aja: $laji ${nimi:-${polku:-}} -> $ulos (loki $loki)"
bash "$dir/godot_jono.sh" "${args[@]}" > "$loki" 2>&1
rc=$?

virheet=$(grep -cE "SCRIPT ERROR|Failed to load script|Parse Error" "$loki" || true)
aikaraja=$(grep -c "AIKARAJA" "$loki" || true)
loydot=$(grep -cE "$LOYDOT" "$loki" || true)
varoitukset=$(grep -c "ei tarkistettu" "$loki" || true)
# Kuvat: --shot-kansio tai tscn-tulostekansio, muuten lokin "kuvat: <kansio>"-rivi (user://-kansio).
kuvia=$(find "$ulos" -name "*.png" | wc -l)
if [[ $kuvia -eq 0 ]]; then
	ukansio=$(grep -oE "kuvat: [^ ]+" "$loki" | tail -1 | cut -d' ' -f2)
	if [[ -n "$ukansio" && -d "$ukansio" ]]; then
		kuvia=$(find "$ukansio" -name "*.png" -newer "$loki" | wc -l)
		[[ $kuvia -eq 0 ]] && kuvia=$(find "$ukansio" -name "*.png" -mmin -30 | wc -l)
		ulos="$ukansio"
	fi
fi
puuttuu_video=0
if [[ $video == 1 ]]; then
	# .avi on syntynyt ja järkevän kokoinen (yli 1 Mt)
	koko=$(stat -c %s "$avi" 2>/dev/null || echo 0)
	echo "aja: video $avi $((koko / 1024)) kt"
	[[ $koko -lt 1048576 ]] && puuttuu_video=1
fi
puuttuu_kuvat=0
[[ $kuvat == 1 && $kuvia -eq 0 ]] && puuttuu_kuvat=1

yht="rc=$rc skriptivirheitä=$virheet aikaraja=$aikaraja testin_löydöt=$loydot ei_tarkistettu=$varoitukset kuvia=$kuvia"
if [[ $rc -ne 0 || $virheet -gt 0 || $aikaraja -gt 0 || $loydot -gt 0 || $puuttuu_kuvat == 1 || $puuttuu_video == 1 ]]; then
	echo "aja: VIKA $yht kuvat $ulos (loki $loki)"
	grep -E "SCRIPT ERROR|Failed to load script|Parse Error" -A1 "$loki" | head -6
	grep -E "$LOYDOT" "$loki" | head -10
	exit 1
fi
echo "aja: OK $yht kuvat $ulos (loki $loki)"
[[ $varoitukset -gt 0 ]] && grep "ei tarkistettu" "$loki" | head -5
exit 0
