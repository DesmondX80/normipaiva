#!/usr/bin/env bash
# Puheäänten keräys: ajaa puhetta sisältävät testikohtaukset `--aanisynteesi`-lipulla, jolloin jokainen vastaan tuleva
# repliikki syntetisoidaan (assets/aanet/, hakemisto.json), ja tuo lopuksi uudet äänet Godotiin. Vain macOS.
# Käyttö: tools/aanet/keraa.sh [kohtaus ...]   (ilman argumentteja: oletuslista alla)
# Jokaiselle kohtaukselle aikaraja GODOT_AIKARAJA (oletus 150 s): ääniä syntyy ajon aikana, joten aikarajan
# umpeutuminen ei haittaa. Kohtaus, joka ei puhu mitään, ei tuota mitään.
set -uo pipefail
cd "$(dirname "$0")/../.."
KOHTAUKSET=("$@")
if [ ${#KOHTAUKSET[@]} -eq 0 ]; then
  KOHTAUKSET=(paivipartio paivihyvitys paivihalytys paivikoti raahepaivi wasted chocotest keskustelu keskustelut
    pekkakyyti taxitest taxistand taxipaapeli lappupekka lappupekka2 tarina tarinamyynti mummot mummotesti mummokeppi
    vaino wife hedgeclose pensasaita karaokeaito kirppismyynti kauppalista kauppapalautus kauppaovi maksamatta
    junttikierto juntti seppo mirkku mirkku_loppu sinikka sinikkatehtava poliisi tractor mokkiratsia mokkihotelli
    siitarihotelli mokkisiitari mokkisiitaritappelu mokkikaatuminen mokkijuhannus junamatka asema satama vanhaherra
    hanhikivi pakkahuone peruskivi kuvakirkko tietokonemuseo karhut hiidenportti kajaani kalajoki raate pyhakoski
    wanharaahe manamansalo kalalampi ronttonen valentinvaala uutiset rasvanappi pekka kuutonen yo kello)
fi
export GODOT_AIKARAJA="${GODOT_AIKARAJA:-150}"
for k in "${KOHTAUKSET[@]}"; do
  n0=$(find assets/aanet -name '*.mp3' | wc -l)
  tools/testit/aja.sh --headless scene "$k" --aanisynteesi > /dev/null 2>&1
  n1=$(find assets/aanet -name '*.mp3' | wc -l)
  echo "$k: +$((n1 - n0)) ääntä (yhteensä $n1)"
done
HOME="${TMPDIR:-/tmp}/aanet_tuonti_home" godot --headless --path . --import > /dev/null 2>&1
echo "tuonti valmis: $(find assets/aanet -name '*.mp3' | wc -l) äänitiedostoa"
