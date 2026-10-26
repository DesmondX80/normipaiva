#!/usr/bin/env bash
# Tulostaa Godot-komennon polun: $GODOT, PATHin godot tai tavallinen asennuspaikka (Windowsilla mieluiten
# _console.exe, jolloin tuloste näkyy terminaalissa). Käyttö: "$(tools/testit/godot.sh)" --path . -- --scene=<nimi>
set -euo pipefail

if [[ -n "${GODOT:-}" ]]; then
	echo "$GODOT"; exit 0
fi
if command -v godot >/dev/null 2>&1; then
	command -v godot; exit 0
fi
# HOME voi olla eristetty testiajossa (HOME=<scratchpad>/home), joten katsotaan myös Windowsin käyttäjäkansio.
up="$HOME"
if [[ -n "${USERPROFILE:-}" ]] && command -v cygpath >/dev/null 2>&1; then
	up=$(cygpath -u "$USERPROFILE")
fi
for g in "$up"/Godot/Godot_v4*_console.exe "$HOME"/Godot/Godot_v4*_console.exe "$up"/Godot/Godot_v4*.exe \
		"/c/Program Files/Godot"/Godot_v4*_console.exe \
		/Applications/Godot.app/Contents/MacOS/Godot "$HOME"/Applications/Godot.app/Contents/MacOS/Godot \
		/usr/local/bin/godot4 /usr/bin/godot4 /opt/homebrew/bin/godot; do
	if [[ -x "$g" ]]; then
		echo "$g"; exit 0
	fi
done
echo "Godotia ei löydy: aseta GODOT=<polku> tai lisää godot PATHiin" >&2
exit 1
